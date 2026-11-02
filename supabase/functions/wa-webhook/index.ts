// ============================================================================
// wa-webhook -- Supabase Edge Function (Deno + TypeScript)
// ============================================================================
//
// PROPOSITO
//   F6 del ADR-089: recibir los estados de entrega de Meta (sent, delivered,
//   read, failed) y dejarlos en public.wa_envios_log. No envia mensajes, no
//   renderiza y no responde al usuario: es un receptor de evidencia.
//
// POR QUE UN RPC Y NO UN UPDATE DIRECTO
//   El orden de los estados (sent < delivered < read, y failed que nunca pisa
//   read) tiene UNA sola fuente de verdad: public.fn_wa_estado_meta. Si el
//   webhook hiciera el UPDATE aqui existirian DOS implementaciones del mismo
//   orden y divergirian (un delivered tardio borraria un read). El RPC es el
//   unico escritor de entrega_estado/entrega_at; el reconciliador horario no
//   los toca. Y no lanza excepcion: devuelve {ok:false, reason}.
//
// VARIABLES DE ENTORNO (dashboard > Edge Functions > Secrets)
//   WA_VERIFY_TOKEN           Token del alta del webhook (GET de verificacion).
//   WA_APP_SECRET             App secret de Meta. Firma X-Hub-Signature-256.
//   SUPABASE_URL              Base del proyecto, sin barra final.
//   SUPABASE_SERVICE_ROLE_KEY Unico rol con EXECUTE sobre el RPC.
//
// PAYLOAD DE META (recortado)
//   {"object":"whatsapp_business_account","entry":[{"id":"...","changes":[
//    {"field":"messages","value":{"messaging_product":"whatsapp",
//     "statuses":[{"id":"wamid.HBg...","status":"delivered",
//                  "timestamp":"1735689600","recipient_id":"57300..."}]}}]}]}
//
// ALTA EN META (WhatsApp > Configuration > Webhooks)
//   Callback URL = https://<project-ref>.supabase.co/functions/v1/wa-webhook
//   Verify token = el valor exacto de WA_VERIFY_TOKEN
//   Campo suscrito = messages (por ahi viajan statuses y mensajes entrantes).
//
// NOTA DE SEGURIDAD
//   Sin WA_APP_SECRET configurado el endpoint responde 503 a proposito: aceptar
//   payloads sin firma permitiria a cualquiera marcar mensajes como leidos. La
//   firma es el UNICO control de acceso real del POST (Meta no manda
//   X-Service-Token). WA_APP_SECRET y WA_VERIFY_TOKEN no se loguean jamas.
// ============================================================================

const MAX_BODY_BYTES = 1048576;
const MAX_STATUSES = 20;
const RPC_TIMEOUT_MS = 4000;
const RPC_CONCURRENCY = 5;

// Los unicos cuatro estados que entiende public.fn_wa_estado_meta.
const ESTADOS_VALIDOS = ["sent", "delivered", "read", "failed"];

// ---------------------------------------------------------------------------
// Utilidades de entorno
// ---------------------------------------------------------------------------
function env(name: string): string {
  try {
    const v = Deno.env.get(name);
    return typeof v === "string" ? v.trim() : "";
  } catch (_e) {
    return "";
  }
}

function envList(name: string): string[] {
  return env(name)
    .split(",")
    .map((s) => s.trim())
    .filter((s) => s.length > 0);
}

// ---------------------------------------------------------------------------
// Comparacion en tiempo casi constante
// ---------------------------------------------------------------------------
function timingSafeEqual(a: string, b: string): boolean {
  const enc = new TextEncoder();
  const ba = enc.encode(a);
  const bb = enc.encode(b);
  const la = ba.length;
  const lb = bb.length;
  const max = Math.max(la, lb);
  let diff = la ^ lb;
  for (let i = 0; i < max; i++) {
    const ca = i < la ? ba[i] : 0;
    const cb = i < lb ? bb[i] : 0;
    diff |= ca ^ cb;
  }
  return diff === 0;
}

// ---------------------------------------------------------------------------
// CORS
// ---------------------------------------------------------------------------
function applyCors(headers: Record<string, string>, origin: string | null): void {
  const allowed = envList("ALLOWED_ORIGINS");
  if (allowed.length > 0) {
    if (origin && allowed.some((o) => o.toLowerCase() === origin.toLowerCase())) {
      headers["Access-Control-Allow-Origin"] = origin;
      headers["Vary"] = "Origin";
    }
  } else {
    headers["Access-Control-Allow-Origin"] = "*";
  }
  headers["Access-Control-Allow-Methods"] = "POST, OPTIONS";
  headers["Access-Control-Allow-Headers"] = "authorization, content-type, x-service-token";
  headers["Access-Control-Max-Age"] = "86400";
}

function jsonResponse(
  status: number,
  body: Record<string, unknown>,
  origin: string | null,
): Response {
  const headers: Record<string, string> = {
    "content-type": "application/json; charset=utf-8",
    "cache-control": "no-store",
  };
  applyCors(headers, origin);
  return new Response(JSON.stringify(body), { status, headers });
}

function textResponse(
  status: number,
  body: string,
  origin: string | null,
): Response {
  const headers: Record<string, string> = {
    "content-type": "text/plain; charset=utf-8",
    "cache-control": "no-store",
  };
  applyCors(headers, origin);
  return new Response(body, { status, headers });
}

// ---------------------------------------------------------------------------
// Firma HMAC-SHA256 del cuerpo crudo (X-Hub-Signature-256)
// ---------------------------------------------------------------------------
function bytesToHex(bytes: Uint8Array): string {
  const DIGITS = "0123456789abcdef";
  let out = "";
  for (let i = 0; i < bytes.length; i++) {
    const b = bytes[i];
    out += DIGITS.charAt((b >> 4) & 0x0f) + DIGITS.charAt(b & 0x0f);
  }
  return out;
}

async function hmacSha256Hex(secret: string, message: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(message),
  );
  return bytesToHex(new Uint8Array(sig));
}

// Formato exigido por Meta: "sha256=<hex>". El hex se compara en minusculas y
// sin el prefijo. Cualquier otra forma es firma invalida, no "casi valida".
const SIGNATURE_RE = /^sha256=([0-9a-fA-F]{64})$/;

// ---------------------------------------------------------------------------
// Recorrido defensivo del payload de Meta
// ---------------------------------------------------------------------------
interface RpcBody {
  p_message_id: string;
  p_estado: string;
  p_at?: string;
  p_error_code?: number;
}

interface StatusItem {
  body: RpcBody;
}

interface Collected {
  items: StatusItem[];
  ignorados: number;
  mensajesEntrantes: number;
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

// timestamp de Meta: segundos unix en STRING. Si falta o no es numerico se
// OMITE p_at y el RPC usa su default now(): nunca se inventa una fecha.
function toIsoOrEmpty(raw: unknown): string {
  let seconds = 0;
  if (typeof raw === "number" && Number.isFinite(raw)) {
    seconds = raw;
  } else if (typeof raw === "string" && /^[0-9]{1,15}$/.test(raw.trim())) {
    seconds = Number.parseInt(raw.trim(), 10);
  } else {
    return "";
  }
  if (!Number.isFinite(seconds) || seconds <= 0) return "";
  const ms = seconds * 1000;
  if (!Number.isFinite(ms)) return "";
  try {
    const d = new Date(ms);
    const iso = d.toISOString();
    return typeof iso === "string" && iso.length === 24 ? iso : "";
  } catch (_e) {
    return "";
  }
}

// Solo se envia cuando existe y es entero. Un code basura no se "arregla".
function toErrorCode(raw: unknown): number | null {
  if (typeof raw === "number" && Number.isInteger(raw)) return raw;
  if (typeof raw === "string" && /^-?[0-9]{1,10}$/.test(raw.trim())) {
    const n = Number.parseInt(raw.trim(), 10);
    if (Number.isInteger(n)) return n;
  }
  return null;
}

function collectStatuses(root: Record<string, unknown>): Collected {
  const out: Collected = { items: [], ignorados: 0, mensajesEntrantes: 0 };

  const entries = root.entry;
  if (!Array.isArray(entries)) return out;

  for (const entry of entries) {
    if (!isPlainObject(entry)) continue;
    const changes = entry.changes;
    if (!Array.isArray(changes)) continue;

    for (const change of changes) {
      if (!isPlainObject(change)) continue;
      const value = change.value;
      if (!isPlainObject(value)) continue;

      // Mensajes entrantes del usuario: NO se procesan y NO se responden. Un
      // auto-reply sin flujo de consentimiento es un bug, no una feature.
      const messages = value.messages;
      if (Array.isArray(messages)) out.mensajesEntrantes += messages.length;

      const statuses = value.statuses;
      if (!Array.isArray(statuses)) continue;

      for (const rawStatus of statuses) {
        if (!isPlainObject(rawStatus)) {
          out.ignorados += 1;
          continue;
        }

        const idRaw = rawStatus.id;
        const messageId = typeof idRaw === "string" ? idRaw.trim() : "";
        if (!messageId) {
          out.ignorados += 1;
          continue;
        }

        const statusRaw = rawStatus.status;
        const estado = typeof statusRaw === "string" ? statusRaw.trim().toLowerCase() : "";
        // Estados fuera del contrato (deleted, warning, ...) no llegan al RPC.
        if (ESTADOS_VALIDOS.indexOf(estado) === -1) {
          out.ignorados += 1;
          continue;
        }

        // Techo de lote: el resto se cuenta como ignorado. Meta reenviaria el
        // lote si hiciera falta; aqui no se parte en varias requests.
        if (out.items.length >= MAX_STATUSES) {
          out.ignorados += 1;
          continue;
        }

        const body: RpcBody = { p_message_id: messageId, p_estado: estado };

        const at = toIsoOrEmpty(rawStatus.timestamp);
        if (at) body.p_at = at;

        if (estado === "failed") {
          const errors = rawStatus.errors;
          if (Array.isArray(errors) && errors.length > 0 && isPlainObject(errors[0])) {
            const code = toErrorCode(errors[0].code);
            if (code !== null) body.p_error_code = code;
          }
        }

        out.items.push({ body: body });
      }
    }
  }

  return out;
}

// ---------------------------------------------------------------------------
// RPC por PostgREST con service_role
// ---------------------------------------------------------------------------
interface RpcOutcome {
  ok: boolean;
  updated: number;
  reason: string;
}

async function callRpc(item: StatusItem, url: string, key: string): Promise<RpcOutcome> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), RPC_TIMEOUT_MS);
  try {
    const res = await fetch(url, {
      method: "POST",
      headers: {
        apikey: key,
        authorization: "Bearer " + key,
        "content-type": "application/json",
        prefer: "return=representation",
      },
      body: JSON.stringify(item.body),
      signal: controller.signal,
    });

    if (res.status < 200 || res.status >= 300) return { ok: false, updated: 0, reason: "rpc_no_2xx" };

    let parsed: Record<string, unknown> | null = null;
    try {
      const decoded: unknown = await res.json();
      if (isPlainObject(decoded)) parsed = decoded;
    } catch (_e) {
      parsed = null;
    }
    if (!parsed) return { ok: false, updated: 0, reason: "respuesta_ilegible" };

    if (parsed.ok === true) {
      const rawUpdated = parsed.updated;
      const updated =
        typeof rawUpdated === "number" && Number.isInteger(rawUpdated) && rawUpdated > 0
          ? rawUpdated
          : 0;
      return { ok: true, updated: updated, reason: "" };
    }

    const reason = typeof parsed.reason === "string" ? parsed.reason : "sin_reason";
    return { ok: false, updated: 0, reason: reason };
  } catch (_e) {
    // Timeout o red: se cuenta como fallo. Meta reintenta igual porque la
    // respuesta global sigue siendo 200.
    return { ok: false, updated: 0, reason: "error_red" };
  } finally {
    clearTimeout(timer);
  }
}

interface RpcSummary {
  actualizados: number;
  fallos: number;
  razones: Record<string, number>;
}

// Concurrencia acotada: tandas de 5 en paralelo. Un lote de 20 no debe abrir
// 20 conexiones ni agotar el pool de PostgREST.
async function runRpcAll(
  items: StatusItem[],
  url: string,
  key: string,
): Promise<RpcSummary> {
  const summary: RpcSummary = { actualizados: 0, fallos: 0, razones: {} };

  for (let i = 0; i < items.length; i += RPC_CONCURRENCY) {
    const tanda = items.slice(i, i + RPC_CONCURRENCY);
    const outcomes = await Promise.all(tanda.map((item) => callRpc(item, url, key)));
    for (const o of outcomes) {
      if (o.ok) {
        summary.actualizados += o.updated;
      } else {
        summary.fallos += 1;
        summary.razones[o.reason] = (summary.razones[o.reason] || 0) + 1;
      }
    }
  }

  return summary;
}

function formatRazones(razones: Record<string, number>): string {
  const keys = Object.keys(razones);
  if (keys.length === 0) return "ninguna";
  return keys.map((k) => k + "=" + String(razones[k])).join(",");
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------
Deno.serve(async (req: Request): Promise<Response> => {
  const origin = req.headers.get("origin");

  if (req.method === "OPTIONS") {
    const headers: Record<string, string> = {};
    applyCors(headers, origin);
    return new Response(null, { status: 204, headers });
  }

  // -------------------------------------------------------------------------
  // GET: verificacion del webhook en Meta
  // -------------------------------------------------------------------------
  if (req.method === "GET") {
    let mode = "";
    let token = "";
    let challenge = "";
    try {
      const params = new URL(req.url).searchParams;
      mode = params.get("hub.mode") || "";
      token = params.get("hub.verify_token") || "";
      challenge = params.get("hub.challenge") || "";
    } catch (_e) {
      console.warn("wa-webhook: query string ilegible");
      return jsonResponse(403, { ok: false, error: "verificacion_fallida" }, origin);
    }

    // Un secreto vacio no es un secreto: sin WA_VERIFY_TOKEN nunca se acepta.
    const expected = env("WA_VERIFY_TOKEN");
    if (!expected) {
      console.warn("wa-webhook: verify token ausente en el entorno, verificacion rechazada");
      return jsonResponse(403, { ok: false, error: "verificacion_fallida" }, origin);
    }

    if (mode !== "subscribe" || !challenge || !timingSafeEqual(token, expected)) {
      console.warn("wa-webhook: verificacion rechazada");
      return jsonResponse(403, { ok: false, error: "verificacion_fallida" }, origin);
    }

    // Meta exige el challenge devuelto tal cual, en texto plano, sin comillas.
    console.log("wa-webhook: verificacion aceptada");
    return textResponse(200, challenge, origin);
  }

  // -------------------------------------------------------------------------
  // POST: estados de entrega
  // -------------------------------------------------------------------------
  if (req.method !== "POST") {
    return jsonResponse(405, { ok: false, error: "metodo_no_permitido" }, origin);
  }

  // El cuerpo se lee como TEXTO crudo: el HMAC se calcula sobre los bytes
  // exactos, no sobre el JSON reserializado.
  let raw = "";
  try {
    raw = await req.text();
  } catch (_e) {
    return jsonResponse(400, { ok: false, error: "cuerpo_ilegible" }, origin);
  }
  if (new TextEncoder().encode(raw).byteLength > MAX_BODY_BYTES) {
    return jsonResponse(413, { ok: false, error: "payload_muy_grande" }, origin);
  }

  // Fail-closed: sin app secret no hay verificacion posible, y aceptar payloads
  // sin firma permitiria a cualquiera marcar mensajes como leidos.
  const appSecret = env("WA_APP_SECRET");
  if (!appSecret) {
    console.error("wa-webhook: app secret ausente en el entorno, POST rechazado");
    return jsonResponse(503, { ok: false, error: "servicio_misconfigurado" }, origin);
  }

  const signatureHeader = (req.headers.get("x-hub-signature-256") || "").trim();
  const match = SIGNATURE_RE.exec(signatureHeader);
  if (!match || !match[1]) {
    console.warn("wa-webhook: firma ausente o mal formada");
    return jsonResponse(401, { ok: false, error: "firma_invalida" }, origin);
  }

  let expectedHex = "";
  try {
    expectedHex = await hmacSha256Hex(appSecret, raw);
  } catch (_e) {
    console.error("wa-webhook: no se pudo calcular la firma");
    return jsonResponse(503, { ok: false, error: "servicio_misconfigurado" }, origin);
  }
  // Cero llamadas al RPC si la firma no cuadra: este es el unico control real.
  if (!timingSafeEqual(match[1].toLowerCase(), expectedHex)) {
    console.warn("wa-webhook: firma invalida");
    return jsonResponse(401, { ok: false, error: "firma_invalida" }, origin);
  }

  let decoded: unknown;
  try {
    decoded = JSON.parse(raw);
  } catch (_e) {
    // Un cuerpo malformado no se arregla reintentando.
    return jsonResponse(400, { ok: false, error: "cuerpo_ilegible" }, origin);
  }
  if (!isPlainObject(decoded)) {
    return jsonResponse(400, { ok: false, error: "cuerpo_ilegible" }, origin);
  }

  const supabaseUrl = env("SUPABASE_URL").replace(/\/+$/, "");
  const serviceKey = env("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) {
    console.error("wa-webhook: SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY ausentes");
    return jsonResponse(503, { ok: false, error: "servicio_misconfigurado" }, origin);
  }

  const collected = collectStatuses(decoded);
  const rpcUrl = supabaseUrl + "/rest/v1/rpc/fn_wa_estado_meta";

  const summary = await runRpcAll(collected.items, rpcUrl, serviceKey);

  // Logs: solo conteos, reason del RPC y status de Meta. Nunca telefonos,
  // nunca wamids, nunca la firma recibida, nunca secretos.
  console.log(
    "wa-webhook: lote. procesados=" + String(collected.items.length) +
    " actualizados=" + String(summary.actualizados) +
    " ignorados=" + String(collected.ignorados) +
    " fallos=" + String(summary.fallos) +
    " razones=" + formatRazones(summary.razones) +
    " mensajes_entrantes_ignorados=" + String(collected.mensajesEntrantes),
  );

  if (collected.mensajesEntrantes > 0) {
    console.log(
      "wa-webhook: mensajes entrantes ignorados (sin flujo de consentimiento): " +
      String(collected.mensajesEntrantes),
    );
  }

  // Con firma valida la respuesta es SIEMPRE 200: Meta reintenta ante non-200
  // y un reintento no arregla un no_encontrado (el reconciliador horario puede
  // no haber poblado wa_message_id todavia).
  return jsonResponse(
    200,
    {
      ok: true,
      procesados: collected.items.length,
      actualizados: summary.actualizados,
      ignorados: collected.ignorados,
    },
    origin,
  );
});
