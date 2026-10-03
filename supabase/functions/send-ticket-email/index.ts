// ============================================================================
// send-ticket-email -- Supabase Edge Function (Deno + TypeScript)
// ============================================================================
// PROPOSITO
//   Envia el correo con el ticket / codigo QR de un evento usando el proveedor
//   Resend, con adjunto opcional (PNG del ticket alojado en Supabase Storage).
//   Reemplaza la version no versionada que hoy existe solo en produccion.
//
// PAYLOAD DE ENTRADA (JSON)
//   { email, nombre, qrCode, eventoNombre, eventoFecha, eventoHora,
//     eventoLugar, tipo?, ticketUrl?, idempotencyKey? }
//   - qrCode: URL de entrada. En registro.html es origin + "/admin.html"
//     (caso onboarding de superadmin: se renderiza como boton, no como imagen).
//   - eventoFecha / eventoHora pueden llegar vacios.
//   - ticketUrl: PNG del ticket en Supabase Storage (opcional, TSK-088).
//   - idempotencyKey: evita reenvios duplicados (opcional, mejor esfuerzo).
//
// VARIABLES DE ENTORNO REQUERIDAS (dashboard > Edge Functions > Secrets)
//   RESEND_API_KEY        Obligatoria. API key de Resend.
//   SUPABASE_ANON_KEY     Obligatoria. Clave anon del proyecto: se usa como
//                         clave HMAC para verificar la FIRMA del JWT de sesion.
//                         NUNCA se acepta como autorizacion.
//   SERVICE_SHARED_TOKEN  Obligatoria para el canal de base de datos. Token
//                         compartido que manda pg_cron -> pg_net en el header
//                         X-Service-Token.
// OPCIONALES
//   MAIL_FROM              Remitente.
//                           Default: Taquilla Directa <no-reply@tickets.taquilladirecta.com>
//   ALLOWED_ORIGINS        CSV de origins CORS. Si no se define se responde "*".
//                           Si se define, jamas se responde "*".
//   TICKET_ALLOWED_HOSTS   CSV de hosts permitidos para ticketUrl (anti SSRF).
//                           Default: host de SUPABASE_URL + PROJECT_REF.supabase.co
//   SUPABASE_URL           Solo para derivar el host permitido del ticket.
//   MAX_TICKET_BYTES       Max bytes del adjunto. Default: 2097152 (2 MB).
//   TICKET_FETCH_TIMEOUT_MS Timeout del fetch del adjunto. Default: 8000.
//   El runtime necesita permisos Deno de red y de entorno.
//
// DUAL AUTENTICACION (lo mas importante de esta funcion)
//   Dos canales validos, resueltos en este orden:
//     1) Header X-Service-Token: comparacion en tiempo casi constante contra
//        SERVICE_SHARED_TOKEN. Es el canal de la base de datos
//        (pg_cron -> pg_net), que no tiene JWT de usuario.
//     2) Header Authorization: Bearer <JWT de sesion>. El JWT se verifica por
//        firma HMAC-SHA256 contra SUPABASE_ANON_KEY, exigiendo exp vigente,
//        sub no vacio y role distinto de "anon" y de "service_role".
//        Es el canal de los call sites que tienen sesion; deben migrar a
//        session.access_token (ver ESTADO REAL de los call sites abajo).
//   Sin ninguno de los dos: 401 y NO se envia nada.
//
//   ESTADO REAL DE LOS CALL SITES (verificado 2026-10-03, ADR-006)
//     Los 5 call sites SIGUEN mandando la anon key, cuyo rol es "anon" y que
//     por tanto esta bloqueada por BLOCKED_ROLES: admin.html:8153 (anon key
//     hardcodeada en el Bearer), registro.html:678, registroaforo.html:1010,
//     serie.html:994 y eventobackup.html:4449. Hay 0 ocurrencias de
//     access_token en esas rutas.
//     CONSECUENCIA: esta version NO es desplegable todavia. Desplegarla sin
//     migrar los call sites deja el correo en 401 en los 5 sitios, que es el
//     fallo que el Paso 1 de abajo anticipa de forma explicita.
//     El Paso 2 sigue pendiente. Ademas registroaforo.html es el formulario
//     publico y NO tiene sesion, asi que por el canal (2) no puede
//     autenticarse: ver el RPC enviar_email_registro de ADR-076 como salida
//     de ese caso, aun sin decidir.
//
//   AVISO DE DOBLE AUTENTICACION Y ORDEN DE DESPLIEGUE
//   La funcion aplica su propia autenticacion y ademas acepta verify_jwt en el
//   gateway. Son capas distintas: el gateway valida la FIRMA, esta funcion
//   valida el ROL y el CANAL. Por eso la capa de aqui no se puede omitir ni
//   con verify_jwt activo (la anon key tiene firma valida y pasa el gateway).
//     Paso 1: desplegar sin exigir JWT en el gateway, para poder migrar los
//             call sites sin que el gateway los rechace antes de tiempo.
//       supabase functions deploy send-ticket-email --no-verify-jwt
//             Durante la migracion los call sites que hoy mandan la anon key
//             recibiran 401 y no se enviara correo: es el comportamiento
//             esperado, es la deuda que esta fase cierra y no un fallo.
//     Paso 2: migrar los 5 call sites a mandar el JWT de sesion real
//             (session.access_token) o X-Service-Token desde pg_net.
//     Paso 3: solo entonces subir la exigencia de JWT en el gateway.
//       supabase functions deploy send-ticket-email
//
// CORS
//   Origenes desde ALLOWED_ORIGINS (CSV). Nunca "*" si la variable esta
//   definida. Sin origin (llamada servidor a servidor) no se manda header CORS.
//
// NOTAS DE RIGUR
//   - Control de injection: se rechaza \r \n \0 y todo control ASCII en los
//     campos de identidad (email, nombre, idempotencyKey, ticketUrl, qrCode).
//     En los campos de solo presentacion (evento*) se permite \n porque
//     registro.html los une con salto de linea, y se escapan al construir el
//     HTML; cualquier otro control se rechaza.
//   - El adjunto nunca rompe el envio: si algo falla se envia sin adjunto y se
//     registra el motivo (fail-open).
//   - No se devuelven stack traces, claves ni credenciales: solo { ok, id?, error? }.
//   - No se lee ni se escribe base de datos. No hay PII mas alla del payload.
// ============================================================================

const PROJECT_REF = "ctgyvydzshueemlelkzv";

const MAX_BODY_BYTES = 65536;
const MAX_EMAIL_LEN = 254;
const MAX_NOMBRE_LEN = 120;
const MAX_TIPO_LEN = 40;
const MAX_EVENTO_LEN = 300;
const MAX_URL_LEN = 2000;
const MAX_IDEM_LEN = 120;

const DEFAULT_MAX_TICKET_BYTES = 2097152;
const DEFAULT_TICKET_TIMEOUT_MS = 8000;

const RESEND_ENDPOINT = "https://api.resend.com/emails";

const EMAIL_RE = /^[A-Za-z0-9._%+-]{1,64}@[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$/;
const HTTPS_RE = /^https:\/\//i;

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
// Validacion estricta del payload
// ---------------------------------------------------------------------------
// Rechaza \r \n \0 y todo caracter de control ASCII (0-31 y 127), ademas de
// los controles C1 (128-159). allowNewline habilita unicamente el LF, que si
// es legitimo en los campos de presentacion.
function hasForbiddenControl(value: string, allowNewline: boolean): boolean {
  for (let i = 0; i < value.length; i++) {
    const c = value.charCodeAt(i);
    if (c === 10) {
      if (!allowNewline) return true;
      continue;
    }
    if (c < 32) return true;
    if (c === 127) return true;
    if (c >= 128 && c <= 159) return true;
  }
  return false;
}

// Los emojis y demas caracteres imprimibles de otros bloques (emoji, cirilico)
// se permiten: no son controles y llegan legitimos desde registro.html.
function isNonAsciiPrintable(value: string): boolean {
  for (let i = 0; i < value.length; i++) {
    const c = value.charCodeAt(i);
    if (c > 159) return false;
  }
  return true;
}

function normalizeNewlines(value: string): string {
  return value.replace(/\r\n/g, "\n").replace(/\r/g, "\n");
}

function cleanOptional(
  value: unknown,
  maxLen: number,
  label: string,
  allowNewline: boolean,
): string {
  if (value === undefined || value === null) return "";
  if (typeof value !== "string") throw new Error(label + " debe ser texto");
  const raw = allowNewline ? normalizeNewlines(value) : value;
  if (raw.length > maxLen) throw new Error(label + " excede la longitud maxima");
  if (hasForbiddenControl(raw, allowNewline)) {
    throw new Error(label + " contiene caracteres de control no permitidos");
  }
  if (!isNonAsciiPrintable(raw)) throw new Error(label + " contiene caracteres no admitidos");
  return raw.trim();
}

interface TicketData {
  email: string;
  nombre: string;
  qrCode: string;
  eventoNombre: string;
  eventoFecha: string;
  eventoHora: string;
  eventoLugar: string;
  tipo: string;
  ticketUrl: string;
  idempotencyKey: string;
}

function parsePayload(raw: string): TicketData {
  let body: unknown;
  try {
    body = JSON.parse(raw);
  } catch (_e) {
    throw new Error("json_invalido");
  }
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    throw new Error("payload_invalido");
  }
  const p = body as Record<string, unknown>;

  // Identidad: sin saltos de linea ni controles (van al To y al saludo).
  const email = cleanOptional(p.email, MAX_EMAIL_LEN, "email", false).toLowerCase();
  if (!email) throw new Error("email es obligatorio");
  if (email.length > MAX_EMAIL_LEN) throw new Error("email excede la longitud maxima");
  if (!EMAIL_RE.test(email)) throw new Error("email con formato invalido");

  const nombre = cleanOptional(p.nombre, MAX_NOMBRE_LEN, "nombre", false);
  if (!nombre) throw new Error("nombre es obligatorio");

  const qrCode = cleanOptional(p.qrCode, MAX_URL_LEN, "qrCode", false);
  if (!qrCode) throw new Error("qrCode es obligatorio");
  if (!HTTPS_RE.test(qrCode) && !/^https?:\/\//i.test(qrCode)) {
    throw new Error("qrCode debe ser una URL http o https");
  }

  // Presentacion: se permite LF porque registro.html une lineas con \n.
  const eventoNombre = cleanOptional(p.eventoNombre, MAX_EVENTO_LEN, "eventoNombre", true);
  const eventoFecha = cleanOptional(p.eventoFecha, MAX_EVENTO_LEN, "eventoFecha", true);
  const eventoHora = cleanOptional(p.eventoHora, MAX_EVENTO_LEN, "eventoHora", true);
  const eventoLugar = cleanOptional(p.eventoLugar, MAX_EVENTO_LEN * 3, "eventoLugar", true);
  const tipo = cleanOptional(p.tipo, MAX_TIPO_LEN, "tipo", true);

  const ticketUrl = cleanOptional(p.ticketUrl, MAX_URL_LEN, "ticketUrl", false);
  if (ticketUrl && !HTTPS_RE.test(ticketUrl)) {
    throw new Error("ticketUrl debe ser una URL https");
  }

  const idempotencyKey = cleanOptional(
    p.idempotencyKey,
    MAX_IDEM_LEN,
    "idempotencyKey",
    false,
  );

  return {
    email,
    nombre,
    qrCode,
    eventoNombre,
    eventoFecha,
    eventoHora,
    eventoLugar,
    tipo,
    ticketUrl,
    idempotencyKey,
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
// Idempotencia (mejor esfuerzo: memoria de la instancia, con TTL)
// ---------------------------------------------------------------------------
const IDEM_TTL_MS = 60 * 60 * 1000;
const idemSeen = new Map<string, number>();

function isDuplicate(key: string): boolean {
  const now = Date.now();
  for (const entry of idemSeen) {
    if (now - entry[1] > IDEM_TTL_MS) idemSeen.delete(entry[0]);
  }
  if (idemSeen.has(key)) return true;
  idemSeen.set(key, now);
  return false;
}

// ---------------------------------------------------------------------------
// Adjunto del ticket (TSK-088) -- fail-open, nunca rompe el envio
// ---------------------------------------------------------------------------
function ticketHostAllowlist(): string[] {
  const configured = envList("TICKET_ALLOWED_HOSTS").map((h) => h.toLowerCase());
  const hosts = new Set<string>(configured);
  const supabaseUrl = env("SUPABASE_URL");
  if (supabaseUrl) {
    try {
      hosts.add(new URL(supabaseUrl).hostname.toLowerCase());
    } catch (_e) {
      // URL de entorno invalida: se ignora y se sigue con la lista.
    }
  }
  hosts.add(PROJECT_REF + ".supabase.co");
  return Array.from(hosts);
}

interface Attachment {
  content: string;
  filename: string;
}

async function fetchTicketAttachment(ticketUrl: string): Promise<Attachment> {
  const maxBytes = envInt("MAX_TICKET_BYTES", DEFAULT_MAX_TICKET_BYTES);
  const timeoutMs = envInt("TICKET_FETCH_TIMEOUT_MS", DEFAULT_TICKET_TIMEOUT_MS);

  let parsed: URL;
  try {
    parsed = new URL(ticketUrl);
  } catch (_e) {
    throw new Error("ticketUrl no parseable");
  }
  if (parsed.protocol !== "https:") throw new Error("ticketUrl no https");
  if (parsed.username || parsed.password) throw new Error("ticketUrl con credenciales");

  // Anti SSRF: el host debe pertenecer a la lista blanca del proyecto.
  const allow = ticketHostAllowlist();
  if (!allow.includes(parsed.hostname.toLowerCase())) {
    throw new Error("host de ticketUrl no permitido");
  }

  const res = await fetch(parsed.toString(), {
    method: "GET",
    redirect: "follow",
    headers: { accept: "image/png" },
    signal: AbortSignal.timeout(timeoutMs),
  });
  if (!res.ok) throw new Error("ticketUrl no disponible");

  const contentType = (res.headers.get("content-type") || "").toLowerCase();
  if (!contentType.startsWith("image/png")) throw new Error("content-type no image/png");

  const declared = Number.parseInt(res.headers.get("content-length") || "", 10);
  if (Number.isFinite(declared) && declared > maxBytes) {
    throw new Error("ticketUrl excede el maximo permitido");
  }

  const bytes = await readCapped(res, maxBytes);
  if (bytes.byteLength === 0) throw new Error("ticketUrl vacio");
  if (bytes.byteLength > maxBytes) throw new Error("ticketUrl excede el maximo permitido");

  const name = parsed.pathname.split("/").pop() || "ticket.png";
  return {
    content: bytesToBase64(bytes),
    filename: name.toLowerCase().endsWith(".png") ? name : name + ".png",
  };
}

async function readCapped(res: Response, max: number): Promise<Uint8Array> {
  const reader = res.body ? res.body.getReader() : null;
  if (!reader) {
    const buf = new Uint8Array(await res.arrayBuffer());
    if (buf.byteLength > max) throw new Error("ticketUrl excede el maximo permitido");
    return buf;
  }
  const chunks: Uint8Array[] = [];
  let total = 0;
  for (;;) {
    const step = await reader.read();
    if (step.done) break;
    const chunk = step.value;
    total += chunk.byteLength;
    if (total > max) {
      try {
        await reader.cancel();
      } catch (_e) {
        // Cancelacion best effort: el limite ya esta aplicado.
      }
      throw new Error("ticketUrl excede el maximo permitido");
    }
    chunks.push(chunk);
  }
  const out = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    out.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return out;
}

// ---------------------------------------------------------------------------
// HTML del correo
// ---------------------------------------------------------------------------
function esc(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function escMultiline(value: string): string {
  return esc(value).replace(/\n/g, "<br>");
}

function looksLikeImage(url: string): boolean {
  return HTTPS_RE.test(url) && /\.(png|jpe?g|gif|webp)(\?|#|$)/i.test(url);
}

function buildSubject(data: TicketData): string {
  const base = data.eventoNombre || "Hostal Terraza";
  return "Tu entrada para " + base.slice(0, 120);
}

function buildHtml(data: TicketData): string {
  const rows: string[] = [];
  const addRow = (label: string, value: string) => {
    if (!value) return;
    rows.push(
      '<tr><td style="padding:10px 16px;border-bottom:1px solid #e8e8e8;color:#6b6b6b;' +
      'font-size:13px;width:140px;vertical-align:top;">' + esc(label) + "</td>" +
      '<td style="padding:10px 16px;border-bottom:1px solid #e8e8e8;color:#1a1a1a;' +
      'font-size:14px;">' + escMultiline(value) + "</td></tr>",
    );
  };

  addRow("Evento", data.eventoNombre);
  addRow("Fecha", data.eventoFecha);
  addRow("Hora", data.eventoHora);
  addRow("Lugar", data.eventoLugar);
  addRow("Tipo", data.tipo);

  const qrBlock = looksLikeImage(data.qrCode)
    ? '<img src="' + esc(data.qrCode) + '" alt="Codigo QR" width="300" ' +
      'style="display:block;border:0;border-radius:12px;" />'
    : '<a href="' + esc(data.qrCode) + '" style="display:inline-block;padding:14px 22px;' +
      'background:#2d6a4f;color:#ffffff;text-decoration:none;border-radius:10px;' +
      'font-weight:600;font-size:15px;">Abrir mi panel</a>';

  return '<!DOCTYPE html><html lang="es"><head><meta charset="utf-8" />' +
    '<meta name="viewport" content="width=device-width, initial-scale=1" />' +
    "<title>" + esc(buildSubject(data)) + "</title></head>" +
    '<body style="margin:0;padding:24px;background:#f6f5f2;font-family:Arial,Helvetica,' +
    'sans-serif;color:#1a1a1a;">' +
    '<div style="max-width:560px;margin:0 auto;background:#ffffff;border-radius:16px;' +
    'overflow:hidden;border:1px solid #e8e8e8;">' +
    '<div style="padding:24px 16px;background:#2d6a4f;color:#ffffff;">' +
    '<div style="font-size:12px;letter-spacing:1px;text-transform:uppercase;opacity:0.85;">' +
    "Hostal Terraza</div>" +
    '<div style="font-size:20px;font-weight:700;margin-top:6px;">' +
    escMultiline(data.eventoNombre || "Tu evento") + "</div></div>" +
    '<div style="padding:24px 16px;">' +
    '<p style="margin:0 0 16px;font-size:15px;">Hola <strong>' + esc(data.nombre) +
    "</strong>,</p>" +
    '<p style="margin:0 0 20px;font-size:15px;line-height:1.5;">Tu registro esta ' +
    "confirmado. Presenta este codigo en la entrada.</p>" +
    '<div style="text-align:center;margin:0 0 20px;">' + qrBlock + "</div>" +
    '<table style="width:100%;border-collapse:collapse;">' + rows.join("") + "</table>" +
    '<p style="margin:24px 0 0;font-size:12px;color:#8a8a8a;line-height:1.5;">' +
    "Si no hiciste esta reserva, ignora este mensaje.</p>" +
    "</div></div></body></html>";
}

// ---------------------------------------------------------------------------
// Envio via Resend (fetch nativo, sin dependencias npm)
// ---------------------------------------------------------------------------
interface ResendResult {
  ok: boolean;
  status: number;
  id: string;
}

async function sendViaResend(
  data: TicketData,
  attachment: Attachment | null,
): Promise<ResendResult> {
  const apiKey = env("RESEND_API_KEY");
  if (!apiKey) return { ok: false, status: 0, id: "" };

  const payload: Record<string, unknown> = {
    from: env("MAIL_FROM") || "Taquilla Directa <no-reply@tickets.taquilladirecta.com>",
    to: [data.email],
    subject: buildSubject(data),
    html: buildHtml(data),
  };
  if (attachment) {
    payload.attachments = [
      { filename: attachment.filename, content: attachment.content },
    ];
  }

  const res = await fetch(RESEND_ENDPOINT, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: "Bearer " + apiKey,
    },
    body: JSON.stringify(payload),
    signal: AbortSignal.timeout(15000),
  });

  let id = "";
  try {
    const body = (await res.json()) as Record<string, unknown>;
    if (typeof body.id === "string") id = body.id;
  } catch (_e) {
    // Cuerpo no JSON: se reporta solo el status de Resend.
  }
  return { ok: res.ok, status: res.status, id };
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
    // Sin autorizacion no se envia nada y no se filtran detalles internos.
    console.warn("send-ticket-email: peticion rechazada. canal=" + auth.channel);
    return jsonResponse(auth.status, { ok: false, error: auth.error }, origin);
  }

  let raw: string;
  try {
    raw = await req.text();
  } catch (_e) {
    return jsonResponse(400, { ok: false, error: "cuerpo_ilegible" }, origin);
  }
  if (raw.length > MAX_BODY_BYTES) {
    return jsonResponse(413, { ok: false, error: "payload_muy_grande" }, origin);
  }

  let data: TicketData;
  try {
    data = parsePayload(raw);
  } catch (e) {
    const message = e instanceof Error ? e.message : "payload_invalido";
    console.warn("send-ticket-email: payload rechazado (" + message + ")");
    return jsonResponse(400, { ok: false, error: message }, origin);
  }

  if (data.idempotencyKey && isDuplicate(data.idempotencyKey)) {
    console.log("send-ticket-email: envio omitido por idempotencia");
    return jsonResponse(200, { ok: true, id: "duplicado_omitido" }, origin);
  }

  // Adjunto best effort: cualquier fallo degrada a envio sin adjunto.
  let attachment: Attachment | null = null;
  if (data.ticketUrl) {
    try {
      attachment = await fetchTicketAttachment(data.ticketUrl);
    } catch (e) {
      const reason = e instanceof Error ? e.message : "adjunto_no_disponible";
      console.warn("send-ticket-email: adjunto omitido, fail-open (" + reason + ")");
      attachment = null;
    }
  }

  let result: ResendResult;
  try {
    result = await sendViaResend(data, attachment);
  } catch (e) {
    // Error de red: se registra la categoria, nunca el detalle interno.
    const reason = e instanceof Error ? e.name : "error_desconocido";
    console.error("send-ticket-email: fallo de envio (" + reason + ")");
    return jsonResponse(502, { ok: false, error: "envio_fallido" }, origin);
  }

  if (!result.ok) {
    console.error("send-ticket-email: Resend respondio status " + result.status);
    if (result.status === 401 || result.status === 403) {
      return jsonResponse(500, { ok: false, error: "servicio_misconfigurado" }, origin);
    }
    return jsonResponse(502, { ok: false, error: "envio_fallido" }, origin);
  }

  console.log(
    "send-ticket-email: enviado. canal=" + auth.channel +
    " adjunto=" + (attachment ? "si" : "no"),
  );
  const body: Record<string, unknown> = { ok: true };
  if (result.id) body.id = result.id;
  return jsonResponse(200, body, origin);
});
