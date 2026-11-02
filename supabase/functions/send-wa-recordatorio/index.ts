// ============================================================================
// send-wa-recordatorio -- Supabase Edge Function (Deno + TypeScript)
// ============================================================================
//
// PROPOSITO
//   Transporte del recordatorio de WhatsApp. No renderiza, no normaliza y no
//   decide politicas: recibe un payload ya resuelto, valida su FORMA y lo
//   reenvia a la WhatsApp Cloud API. Autocontenido: cero imports, cero npm.
//
// RELACION CON EL ADR
//   ADR-089 v1.2 (recordatorios multicanal con canal WhatsApp), fase F2 del
//   plan, seccion 4. La migracion migrations/adr089_recordatorios_multicanal.sql
//   encola en public.wa_envios_log y llama a esta funcion por pg_net con el header
//   X-Service-Token. El reconciliador public.fn_wa_reconciliar_respuestas()
//   lee net._http_response.status_code y content.error.code: por eso el status
//   HTTP de esta respuesta ES el contrato y no se puede inventar un 200.
//
// VARIABLES DE ENTORNO (dashboard > Edge Functions > Secrets)
//   WA_TOKEN                  Token de la WABA. Obligatorio solo sin dry-run.
//   WA_PHONE_NUMBER_ID        Phone number id de Meta. Obligatorio igual.
//   WA_DRY_RUN                1/true/yes/on -> linea base sin WABA, cero fetch.
//   WA_GRAPH_VERSION          Default v21.0.
//   WA_GRAPH_URL              Vacio en produccion. Solo para mock local.
//   SERVICE_SHARED_TOKEN      Canal 1 (pg_net), comparacion casi constante.
//   SUPABASE_ANON_KEY         Clave HMAC para la firma del JWT de sesion.
//                             NUNCA autoriza por si sola.
//   SUPABASE_SERVICE_ROLE_KEY Nunca autoriza: rol bloqueado.
//   ALLOWED_ORIGINS           CSV de origins CORS. Sin definir -> "*".
//
// PAYLOAD (JSON, maximo 16384 bytes)
//   {"idempotencyKey":"whatsapp:evt_123:ins_456:anticipacion",
//    "to":"+573001234567",
//    "template":{"name":"recordatorio_evento","language":"es_CO",
//                "components":[{"type":"body","parameters":[
//                  {"type":"text","text":"Ana"}]}]},
//    "meta":{"eventoId":"42","inscritoId":"123","tipo":"anticipacion"}}
//   meta es solo para logs: NUNCA se reenvia a Meta.
//
// CASOS DE CONTRATO (hoy sin WABA: dry-run es la linea base, no una fase)
//   (a) payload valido en dry-run -> 202 dryRun:true, messageId:null
//       curl -s -w "\n%{http_code}\n" -X POST "$FN" -H "X-Service-Token: $TOK" \
//         -H "content-type: application/json" \
//         -d '{"idempotencyKey":"whatsapp:evt_123:ins_456:anticipacion","to":"+573001234567","template":{"name":"recordatorio_evento","language":"es_CO"}}'
//   (b) telefono invalido -> 400 {"ok":false,"error":"telefono_invalido"}
//       curl -s -w "\n%{http_code}\n" -X POST "$FN" -H "X-Service-Token: $TOK" \
//         -H "content-type: application/json" \
//         -d '{"idempotencyKey":"whatsapp:evt_123:ins_456:anticipacion","to":"3001234567","template":{"name":"recordatorio_evento","language":"es_CO"}}'
//   (c) plantilla con name invalido -> 400 {"error":"plantilla_invalida"}
//       (la EXISTENCIA real la valida el SQL contra wa_plantillas)
//       curl -s -w "\n%{http_code}\n" -X POST "$FN" -H "X-Service-Token: $TOK" \
//         -H "content-type: application/json" \
//         -d '{"idempotencyKey":"whatsapp:evt_123:ins_456:anticipacion","to":"+573001234567","template":{"name":"Recordatorio Evento","language":"es_CO"}}'
//   (d) X-Service-Token incorrecto -> 401 {"error":"no_autorizado"}
//       curl -s -w "\n%{http_code}\n" -X POST "$FN" -H "X-Service-Token: malo" \
//         -H "content-type: application/json" -d '{}'
//   (e) sin token y sin JWT -> 401 {"error":"no_autorizado"}
//       curl -s -w "\n%{http_code}\n" -X POST "$FN" -H "content-type: application/json" -d '{}'
//   (f) timeout de Meta simulado -> 504 {"error":"timeout_meta"}, nunca 200
//       WA_GRAPH_URL=http://127.0.0.1:9099/messages (mock que no responde)
//       curl -s -w "\n%{http_code}\n" -X POST "$FN" -H "X-Service-Token: $TOK" \
//         -H "content-type: application/json" \
//         -d '{"idempotencyKey":"whatsapp:evt_123:ins_456:anticipacion","to":"+573001234567","template":{"name":"recordatorio_evento","language":"es_CO"}}'
//   (g) WA_DRY_RUN=1 explicito -> 202 dryRun:true, messageId:null y CERO
//       llamadas a graph.facebook.com (ni siquiera se construye la URL)
//
// NOTA (a) ESTADO EN SQL
//   estado='enviado' en public.wa_envios_log significa ENCOLADO, no entregado. El
//   messageId se puebla despues, en la reconciliacion. Esta funcion no escribe
//   base de datos y no conoce el id de la fila.
//
// NOTA (b) EL RENDER VIVE EN SQL
//   Los textos de las variables salen de wa_plantillas.variables (posicional)
//   resueltos por el helper SQL. Esta funcion NO lo duplica: si el admin
//   necesita un preview, debe llamar al MISMO render SQL, nunca reimplementar
//   aqui un segundo renderizador (dos renderizadores divergen, es BUG de datos).
//
// SEGURIDAD
//   WA_TOKEN no aparece en ningun console.*, ni en error, ni en el cuerpo de
//   ninguna respuesta. De la respuesta de Meta se loguea solo status y code.
//   El telefono se enmascara en los logs. No se devuelven stack traces.
// ============================================================================

const MAX_BODY_BYTES = 16384;
const MAX_IDEM_LEN = 120;
const MAX_COMPONENTS = 3;
const MAX_PARAMS = 10;
const MAX_PARAM_TEXT = 1024;
const MAX_META_LEN = 120;

const IDEM_PREFIX = "whatsapp:";

const DEFAULT_GRAPH_VERSION = "v21.0";
const GRAPH_BASE = "https://graph.facebook.com/";
const META_TIMEOUT_MS = 8000;
const RETRY_BACKOFF_MS = 500;
const RETRY_JITTER_MS = 250;

const E164_RE = /^\+[1-9][0-9]{7,14}$/;
const TEMPLATE_NAME_RE = /^[a-z0-9_]{1,120}$/;
const TEMPLATE_LANG_RE = /^[a-z]{2,3}(_[A-Z]{2})?$/;
const DRY_RUN_RE = /^(1|true|yes|on)$/i;

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

function envInt(name: string, fallback: number): number {
  const raw = env(name);
  if (!raw) return fallback;
  const n = Number.parseInt(raw, 10);
  if (!Number.isFinite(n) || n <= 0) return fallback;
  return n;
}

function envList(name: string): string[] {
  return env(name)
    .split(",")
    .map((s) => s.trim())
    .filter((s) => s.length > 0);
}

// ---------------------------------------------------------------------------
// Comparacion en tiempo casi constante (canal X-Service-Token)
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
// Base64url (Deno no expone Buffer)
// ---------------------------------------------------------------------------
function b64urlToBytes(input: string): Uint8Array {
  let s = input.replace(/-/g, "+").replace(/_/g, "/");
  const rem = s.length % 4;
  if (rem === 2) s += "==";
  else if (rem === 3) s += "=";
  else if (rem === 1) throw new Error("bad_base64url");
  const bin = atob(s);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

function b64urlToText(input: string): string {
  return new TextDecoder().decode(b64urlToBytes(input));
}

function bytesToBase64(bytes: Uint8Array): string {
  const CHUNK = 0x8000;
  let bin = "";
  for (let i = 0; i < bytes.length; i += CHUNK) {
    const end = Math.min(i + CHUNK, bytes.length);
    let part = "";
    for (let j = i; j < end; j++) part += String.fromCharCode(bytes[j]);
    bin += part;
  }
  return btoa(bin);
}

// ---------------------------------------------------------------------------
// Payload: forma del contrato con el SQL (transporte, no render)
// ---------------------------------------------------------------------------
interface TemplateParam {
  type: string;
  text: string;
}

interface TemplateComponent {
  type: string;
  parameters: TemplateParam[];
}

interface TemplateSpec {
  name: string;
  language: string;
  components: TemplateComponent[];
}

interface WaMeta {
  eventoId: string;
  inscritoId: string;
  tipo: string;
}

interface WaPayload {
  idempotencyKey: string;
  to: string;
  template: TemplateSpec;
  meta: WaMeta;
}

// Solo para logs: recorta y elimina controles (evita inyeccion de log).
function clipLog(value: unknown): string {
  if (typeof value !== "string") return "";
  let out = "";
  for (let i = 0; i < value.length && out.length < MAX_META_LEN; i++) {
    const c = value.charCodeAt(i);
    if (c < 32 || c === 127) continue;
    out += value.charAt(i);
  }
  return out;
}

// Enmascara el telefono en logs: +573001234567 -> +57******4567.
function maskPhone(value: string): string {
  if (value.length <= 7) return "***";
  return value.slice(0, 3) + "******" + value.slice(-4);
}

// Los components se reenvian TAL CUAL (mismo orden, mismos textos): aqui solo
// se valida la forma. La funcion es transporte, no un segundo renderizador.
function parseComponents(value: unknown): TemplateComponent[] {
  if (value === undefined || value === null) return [];
  if (!Array.isArray(value)) throw new Error("plantilla_invalida");
  if (value.length > MAX_COMPONENTS) throw new Error("plantilla_invalida");
  const out: TemplateComponent[] = [];
  for (const rawItem of value) {
    if (!rawItem || typeof rawItem !== "object" || Array.isArray(rawItem)) {
      throw new Error("plantilla_invalida");
    }
    const item = rawItem as Record<string, unknown>;
    if (item.type !== "body") throw new Error("plantilla_invalida");
    const rawParams = item.parameters;
    if (!Array.isArray(rawParams)) throw new Error("plantilla_invalida");
    if (rawParams.length > MAX_PARAMS) throw new Error("plantilla_invalida");
    const params: TemplateParam[] = [];
    for (const rawParam of rawParams) {
      if (!rawParam || typeof rawParam !== "object" || Array.isArray(rawParam)) {
        throw new Error("plantilla_invalida");
      }
      const param = rawParam as Record<string, unknown>;
      if (param.type !== "text") throw new Error("plantilla_invalida");
      if (typeof param.text !== "string") throw new Error("plantilla_invalida");
      if (param.text.length > MAX_PARAM_TEXT) throw new Error("plantilla_invalida");
      params.push({ type: "text", text: param.text });
    }
    out.push({ type: "body", parameters: params });
  }
  return out;
}

function parseWaPayload(p: Record<string, unknown>): WaPayload {
  // idempotencyKey: NO se re-genera, es la clave de idempotencia del SQL.
  const idemRaw = p.idempotencyKey;
  if (typeof idemRaw !== "string") throw new Error("idempotencyKey_invalida");
  const idempotencyKey = idemRaw.trim();
  if (idempotencyKey.length < 1 || idempotencyKey.length > MAX_IDEM_LEN) {
    throw new Error("idempotencyKey_invalida");
  }
  if (!idempotencyKey.startsWith(IDEM_PREFIX)) {
    throw new Error("idempotencyKey_invalida");
  }
  if (idempotencyKey.length <= IDEM_PREFIX.length) {
    throw new Error("idempotencyKey_invalida");
  }

  // to: NO se normaliza ni se "arregla". La normalizacion es exclusiva del
  // helper SQL public.fn_wa_e164_co. Aqui solo se recortan espacios de borde,
  // nunca digitos: un numero inventado en el borde es el bug H1 del proyecto.
  const toRaw = p.to;
  if (typeof toRaw !== "string") throw new Error("telefono_invalido");
  const to = toRaw.trim();
  if (!E164_RE.test(to)) throw new Error("telefono_invalido");

  const tplRaw = p.template;
  if (!tplRaw || typeof tplRaw !== "object" || Array.isArray(tplRaw)) {
    throw new Error("plantilla_invalida");
  }
  const tpl = tplRaw as Record<string, unknown>;
  const name = typeof tpl.name === "string" ? tpl.name.trim() : "";
  if (!TEMPLATE_NAME_RE.test(name)) throw new Error("plantilla_invalida");
  const language = typeof tpl.language === "string" ? tpl.language.trim() : "";
  if (!TEMPLATE_LANG_RE.test(language)) throw new Error("plantilla_invalida");
  const components = parseComponents(tpl.components);

  // meta: opcional y SOLO para logs. No produce errores de validacion.
  const meta: WaMeta = { eventoId: "", inscritoId: "", tipo: "" };
  const metaRaw = p.meta;
  if (metaRaw && typeof metaRaw === "object" && !Array.isArray(metaRaw)) {
    const m = metaRaw as Record<string, unknown>;
    meta.eventoId = clipLog(m.eventoId);
    meta.inscritoId = clipLog(m.inscritoId);
    meta.tipo = clipLog(m.tipo);
  }

  return {
    idempotencyKey: idempotencyKey,
    to: to,
    template: { name: name, language: language, components: components },
    meta: meta,
  };
}

// ---------------------------------------------------------------------------
// Autorizacion: canal de servicio y canal de JWT de sesion
// ---------------------------------------------------------------------------
const BLOCKED_ROLES = ["anon", "service_role"];

async function verifySessionJwt(token: string): Promise<{ ok: boolean; reason: string }> {
  const anonKey = env("SUPABASE_ANON_KEY");
  if (!anonKey) return { ok: false, reason: "config" };

  const parts = token.split(".");
  if (parts.length !== 3) return { ok: false, reason: "shape" };
  const head = parts[0];
  const body = parts[1];
  const sig = parts[2];
  if (!head || !body || !sig) return { ok: false, reason: "shape" };

  let header: Record<string, unknown> | null = null;
  let claims: Record<string, unknown> | null = null;
  try {
    header = JSON.parse(b64urlToText(head)) as Record<string, unknown>;
    claims = JSON.parse(b64urlToText(body)) as Record<string, unknown>;
  } catch (_e) {
    return { ok: false, reason: "decode" };
  }
  if (!header || !claims) return { ok: false, reason: "decode" };
  if (header.alg !== "HS256") return { ok: false, reason: "alg" };

  // Verificacion de firma HMAC-SHA256 con la anon key del proyecto.
  let valid = false;
  try {
    const key = await crypto.subtle.importKey(
      "raw",
      new TextEncoder().encode(anonKey),
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["verify"],
    );
    valid = await crypto.subtle.verify(
      "HMAC",
      key,
      b64urlToBytes(sig),
      new TextEncoder().encode(head + "." + body),
    );
  } catch (_e) {
    valid = false;
  }
  if (!valid) return { ok: false, reason: "firma" };

  const role = typeof claims.role === "string" ? claims.role : "";
  if (BLOCKED_ROLES.includes(role)) return { ok: false, reason: "rol" };

  const sub = typeof claims.sub === "string" ? claims.sub : "";
  if (!sub) return { ok: false, reason: "sub" };

  const exp = typeof claims.exp === "number" ? claims.exp : 0;
  const nowSeconds = Math.floor(Date.now() / 1000);
  if (!exp || exp <= nowSeconds - 60) return { ok: false, reason: "exp" };

  return { ok: true, reason: "ok" };
}

interface AuthResult {
  ok: boolean;
  channel: string;
  status: number;
  error: string;
}

async function authorize(req: Request): Promise<AuthResult> {
  // Canal 1: token de servicio compartido (pg_cron -> pg_net).
  const serviceToken = req.headers.get("x-service-token") || "";
  const expected = env("SERVICE_SHARED_TOKEN");
  if (serviceToken) {
    if (expected && timingSafeEqual(serviceToken, expected)) {
      return { ok: true, channel: "service", status: 200, error: "" };
    }
    return { ok: false, channel: "service", status: 401, error: "no_autorizado" };
  }

  // Canal 2: JWT de sesion del usuario.
  const authHeader = req.headers.get("authorization") || "";
  const match = /^Bearer\s+(.+)$/i.exec(authHeader.trim());
  if (!match || !match[1]) {
    return { ok: false, channel: "ninguno", status: 401, error: "no_autorizado" };
  }
  const token = match[1].trim();

  // La anon key es una credencial publica: nunca autoriza por si sola.
  const anonKey = env("SUPABASE_ANON_KEY");
  const serviceRoleKey = env("SUPABASE_SERVICE_ROLE_KEY");
  if ((anonKey && timingSafeEqual(token, anonKey)) ||
      (serviceRoleKey && timingSafeEqual(token, serviceRoleKey))) {
    return { ok: false, channel: "anon", status: 401, error: "no_autorizado" };
  }

  const verdict = await verifySessionJwt(token);
  if (!verdict.ok) {
    if (verdict.reason === "config") {
      return { ok: false, channel: "sesion", status: 500, error: "servicio_misconfigurado" };
    }
    return { ok: false, channel: "sesion", status: 401, error: "no_autorizado" };
  }
  return { ok: true, channel: "sesion", status: 200, error: "" };
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

// ---------------------------------------------------------------------------
// Envio a la WhatsApp Cloud API
// ---------------------------------------------------------------------------
// Se construye SOLO fuera del dry-run: en dry-run no debe existir ni la URL.
function graphEndpointUrl(phoneNumberId: string): string {
  const custom = env("WA_GRAPH_URL");
  if (custom) return custom;
  const version = env("WA_GRAPH_VERSION") || DEFAULT_GRAPH_VERSION;
  return GRAPH_BASE + version + "/" + phoneNumberId + "/messages";
}

function buildMetaBody(p: WaPayload): Record<string, unknown> {
  return {
    messaging_product: "whatsapp",
    recipient_type: "individual",
    to: p.to,
    type: "template",
    template: {
      name: p.template.name,
      language: { code: p.template.language },
      components: p.template.components,
    },
  };
}

interface MetaOutcome {
  kind: "ok" | "meta_error" | "timeout" | "network" | "sin_message_id";
  status: number;
  messageId: string;
  code: number | null;
}

function extractMessageId(body: Record<string, unknown> | null): string {
  if (!body) return "";
  const messages = body.messages;
  if (!Array.isArray(messages) || messages.length === 0) return "";
  const first = messages[0];
  if (!first || typeof first !== "object" || Array.isArray(first)) return "";
  const id = (first as Record<string, unknown>).id;
  return typeof id === "string" ? id : "";
}

function extractErrorCode(body: Record<string, unknown> | null): number | null {
  if (!body) return null;
  const err = body.error;
  if (!err || typeof err !== "object" || Array.isArray(err)) return null;
  const code = (err as Record<string, unknown>).code;
  if (typeof code === "number" && Number.isInteger(code)) return code;
  if (typeof code === "string" && /^-?[0-9]{1,10}$/.test(code)) {
    return Number.parseInt(code, 10);
  }
  return null;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// Un intento. El abort es de 8000 ms, menor que los 10000 ms de pg_net, para
// que el error llegue como respuesta y no como request huerfano.
async function attemptSend(
  url: string,
  token: string,
  bodyText: string,
): Promise<MetaOutcome> {
  const controller = new AbortController();
  let timedOut = false;
  const timer = setTimeout(() => {
    timedOut = true;
    controller.abort();
  }, META_TIMEOUT_MS);
  try {
    const res = await fetch(url, {
      method: "POST",
      headers: {
        authorization: "Bearer " + token,
        "content-type": "application/json",
      },
      body: bodyText,
      signal: controller.signal,
    });

    let parsed: Record<string, unknown> | null = null;
    try {
      const decoded: unknown = await res.json();
      if (decoded && typeof decoded === "object" && !Array.isArray(decoded)) {
        parsed = decoded as Record<string, unknown>;
      }
    } catch (_e) {
      parsed = null;
    }

    if (res.status >= 200 && res.status < 300) {
      const messageId = extractMessageId(parsed);
      if (!messageId) {
        return { kind: "sin_message_id", status: res.status, messageId: "", code: null };
      }
      return { kind: "ok", status: res.status, messageId: messageId, code: null };
    }

    return {
      kind: "meta_error",
      status: res.status,
      messageId: "",
      code: extractErrorCode(parsed),
    };
  } catch (e) {
    if (timedOut) return { kind: "timeout", status: 0, messageId: "", code: null };
    const name = e instanceof Error ? e.name : "";
    if (name === "AbortError") {
      return { kind: "timeout", status: 0, messageId: "", code: null };
    }
    return { kind: "network", status: 0, messageId: "", code: null };
  } finally {
    clearTimeout(timer);
  }
}

// Solo red, 429 y 5xx se reintentan, UNA vez. Nada mas.
// Un TIMEOUT no se reintenta: ya consumio los 8000 ms y un segundo intento
// llevaria la respuesta a ~16 s, muy por encima de los 10000 ms de pg_net. El
// reintento real de un timeout lo hace la siguiente corrida horaria via
// `intentos` (ADR-089 4.3).
function isRetryable(outcome: MetaOutcome): boolean {
  if (outcome.kind === "network") return true;
  if (outcome.kind === "meta_error") {
    return outcome.status === 429 || outcome.status >= 500;
  }
  return false;
}

async function sendToMeta(
  url: string,
  token: string,
  bodyText: string,
): Promise<MetaOutcome> {
  const first = await attemptSend(url, token, bodyText);
  if (!isRetryable(first)) return first;
  const jitter = Math.floor(Math.random() * (RETRY_JITTER_MS + 1));
  await sleep(RETRY_BACKOFF_MS + jitter);
  return await attemptSend(url, token, bodyText);
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

  if (req.method !== "POST") {
    return jsonResponse(405, { ok: false, error: "metodo_no_permitido" }, origin);
  }

  const auth = await authorize(req);
  if (!auth.ok) {
    // Nunca se loguea el token: solo el canal.
    console.warn("send-wa-recordatorio: peticion rechazada. canal=" + auth.channel);
    return jsonResponse(auth.status, { ok: false, error: auth.error }, origin);
  }

  let raw: string;
  try {
    raw = await req.text();
  } catch (_e) {
    return jsonResponse(400, { ok: false, error: "cuerpo_ilegible" }, origin);
  }
  if (new TextEncoder().encode(raw).byteLength > MAX_BODY_BYTES) {
    return jsonResponse(413, { ok: false, error: "payload_muy_grande" }, origin);
  }

  let decodedBody: unknown;
  try {
    decodedBody = JSON.parse(raw);
  } catch (_e) {
    return jsonResponse(400, { ok: false, error: "cuerpo_ilegible" }, origin);
  }
  if (!decodedBody || typeof decodedBody !== "object" || Array.isArray(decodedBody)) {
    return jsonResponse(400, { ok: false, error: "cuerpo_ilegible" }, origin);
  }

  let payload: WaPayload;
  try {
    payload = parseWaPayload(decodedBody as Record<string, unknown>);
  } catch (e) {
    const reason = e instanceof Error ? e.message : "cuerpo_ilegible";
    console.warn("send-wa-recordatorio: payload rechazado (" + reason + ")");
    return jsonResponse(400, { ok: false, error: reason }, origin);
  }

  const logRef =
    " evento=" + payload.meta.eventoId +
    " inscrito=" + payload.meta.inscritoId +
    " tipo=" + payload.meta.tipo +
    " to=" + maskPhone(payload.to);

  // Linea base: sin WABA, sin plantilla aprobada y sin token permanente. En
  // dry-run NO se construye la URL y NO se hace ninguna llamada a graph.
  const dryEnv = DRY_RUN_RE.test(env("WA_DRY_RUN"));
  if (dryEnv) {
    console.log("send-wa-recordatorio: dry-run. canal=" + auth.channel + logRef);
    return jsonResponse(
      202,
      {
        ok: true,
        dryRun: true,
        messageId: null,
        idempotencyKey: payload.idempotencyKey,
      },
      origin,
    );
  }

  // Fail-closed: sin credenciales no se finge exito.
  const token = env("WA_TOKEN");
  const phoneNumberId = env("WA_PHONE_NUMBER_ID");
  if (!token || !phoneNumberId) {
    console.error("send-wa-recordatorio: credenciales de WhatsApp ausentes");
    return jsonResponse(503, { ok: false, error: "servicio_misconfigurado" }, origin);
  }

  const url = graphEndpointUrl(phoneNumberId);
  const bodyText = JSON.stringify(buildMetaBody(payload));

  let outcome: MetaOutcome;
  try {
    outcome = await sendToMeta(url, token, bodyText);
  } catch (_e) {
    // Nunca se propaga el detalle interno ni el token.
    console.error("send-wa-recordatorio: fallo de transporte");
    return jsonResponse(502, { ok: false, error: "envio_fallido" }, origin);
  }

  // Del resultado de Meta solo se loguea status y code.
  console.log(
    "send-wa-recordatorio: respuesta de Meta. canal=" + auth.channel +
    " status=" + outcome.status +
    " code=" + (outcome.code === null ? "null" : String(outcome.code)) +
    logRef,
  );

  if (outcome.kind === "ok") {
    return jsonResponse(
      200,
      {
        ok: true,
        dryRun: false,
        messageId: outcome.messageId,
        idempotencyKey: payload.idempotencyKey,
      },
      origin,
    );
  }

  if (outcome.kind === "timeout") {
    return jsonResponse(504, { ok: false, error: "timeout_meta" }, origin);
  }

  if (outcome.kind === "network") {
    return jsonResponse(502, { ok: false, error: "envio_fallido" }, origin);
  }

  if (outcome.kind === "sin_message_id") {
    return jsonResponse(502, { ok: false, error: "respuesta_sin_message_id" }, origin);
  }

  // meta_error: se responde con el MISMO status de Meta. El status es lo que
  // clasifica el error en el reconciliador (190 apaga el canal, 131026 omite
  // para siempre, 429/131056/5xx reintentan). No se inventa un 200.
  const status = outcome.status >= 400 && outcome.status <= 599 ? outcome.status : 502;
  return jsonResponse(
    status,
    { ok: false, error: "meta_error", code: outcome.code, messageId: null },
    origin,
  );
});
