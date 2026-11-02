// ============================================================================
// smoke_wa_webhook.js | ADR-089 F6 - contrato de wa-webhook
// ----------------------------------------------------------------------------
// Ejecuta los ONCE casos de contrato del webhook de estados de Meta SIN Deno,
// SIN Supabase y SIN Meta:
//   * stub de globalThis.Deno (env + serve) para cargar el index.ts tal cual,
//   * stub de PostgREST en 127.0.0.1:0 que captura los bodies del RPC,
//   * firma HMAC real con require('crypto'), no una firma de mentira.
//
// Por que existe: "no lanzo excepcion" no valida nada. Este arnes mira el
// status y el cuerpo que consumiria Meta, y sobre todo que un POST sin firma
// valida deje CERO llamadas al RPC (marcar mensajes como leidos es un privilegio).
//
// Uso:  node scripts/smoke_wa_webhook.js
// Requiere Node >= 22.18 (type stripping nativo de .ts). Sin dependencias.
// ============================================================================

'use strict';

const http = require('http');
const path = require('path');
const crypto = require('crypto');
const { pathToFileURL } = require('url');

const EDGE = path.join(__dirname, '..', 'supabase', 'functions', 'wa-webhook', 'index.ts');

const VERIFY_TOKEN = 'verify-token-de-prueba-no-real';
const APP_SECRET = 'app-secret-de-prueba-no-real';
const SERVICE_KEY = 'service-role-de-prueba-no-real';

// ---------------------------------------------------------------------------
// Entorno simulado (mutable: cada caso ajusta lo que necesita)
// ---------------------------------------------------------------------------
const ENV = {
  WA_VERIFY_TOKEN: VERIFY_TOKEN,
  WA_APP_SECRET: APP_SECRET,
  SUPABASE_URL: '',
  SUPABASE_SERVICE_ROLE_KEY: SERVICE_KEY,
  ALLOWED_ORIGINS: '',
};

let handler = null;
globalThis.Deno = {
  env: { get: (name) => (Object.prototype.hasOwnProperty.call(ENV, name) ? ENV[name] : undefined) },
  serve: (h) => { handler = h; return { finished: Promise.resolve() }; },
};

// ---------------------------------------------------------------------------
// Utilidades del harness
// ---------------------------------------------------------------------------
const results = [];
const responseTexts = [];

function check(name, condition, detail) {
  results.push({ name, ok: !!condition, detail: detail || '' });
  const tag = condition ? 'PASS' : 'FAIL';
  console.log('[' + tag + '] ' + name + (detail ? ' -> ' + detail : ''));
}

function sign(secret, bodyText) {
  return 'sha256=' + crypto.createHmac('sha256', secret).update(bodyText, 'utf8').digest('hex');
}

// ---------------------------------------------------------------------------
// Stub de PostgREST
// ---------------------------------------------------------------------------
const rpcBodies = [];
let rpcStatus = 200;
let rpcReply = { ok: true, updated: 1, estado: 'delivered' };

function startPostgrest() {
  return new Promise((resolve) => {
    const server = http.createServer((req, res) => {
      let data = '';
      req.on('data', (chunk) => { data += chunk; });
      req.on('end', () => {
        let parsed = null;
        try { parsed = JSON.parse(data); } catch (_e) { parsed = null; }
        rpcBodies.push({
          path: req.url,
          method: req.method,
          apikey: req.headers.apikey || '',
          authorization: req.headers.authorization || '',
          prefer: req.headers.prefer || '',
          body: parsed,
        });
        res.writeHead(rpcStatus, { 'content-type': 'application/json' });
        res.end(JSON.stringify(rpcReply));
      });
    });
    server.listen(0, '127.0.0.1', () => resolve(server));
  });
}

function stopServer(server) {
  return new Promise((resolve) => {
    if (typeof server.closeAllConnections === 'function') server.closeAllConnections();
    server.close(() => resolve());
  });
}

function statusPayload(statuses) {
  return {
    object: 'whatsapp_business_account',
    entry: [{
      id: '102290129340398',
      changes: [{
        field: 'messages',
        value: {
          messaging_product: 'whatsapp',
          metadata: { display_phone_number: '15550783881', phone_number_id: '106540352242922' },
          statuses: statuses,
        },
      }],
    }],
  };
}

function postRequest(bodyText, signature) {
  const headers = { 'content-type': 'application/json' };
  if (typeof signature === 'string') headers['x-hub-signature-256'] = signature;
  return new Request('http://127.0.0.1/functions/v1/wa-webhook', {
    method: 'POST',
    headers: headers,
    body: bodyText,
  });
}

async function send(req) {
  const res = await handler(req);
  const text = await res.text();
  responseTexts.push(text);
  let parsed = null;
  try { parsed = JSON.parse(text); } catch (_e) { parsed = null; }
  return { status: res.status, body: parsed, text: text, contentType: res.headers.get('content-type') || '' };
}

function getRequest(query) {
  return new Request('http://127.0.0.1/functions/v1/wa-webhook?' + query, { method: 'GET' });
}

// ---------------------------------------------------------------------------
// Casos
// ---------------------------------------------------------------------------
(async () => {
  const pg = await startPostgrest();
  ENV.SUPABASE_URL = 'http://127.0.0.1:' + pg.address().port;

  await import(pathToFileURL(EDGE).href);

  if (typeof handler !== 'function') {
    console.error('No se pudo capturar el handler de Deno.serve');
    process.exit(1);
  }

  // (a) GET con token correcto -> 200 y el challenge byte a byte
  const challenge = '1158201444';
  rpcBodies.length = 0;
  let r = await send(getRequest(
    'hub.mode=subscribe&hub.verify_token=' + encodeURIComponent(VERIFY_TOKEN) +
    '&hub.challenge=' + challenge,
  ));
  check('(a) GET token correcto = 200 text/plain', r.status === 200 && r.contentType.indexOf('text/plain') === 0,
    'status=' + r.status + ' ct=' + r.contentType);
  check('(a) el challenge vuelve byte a byte', r.text === challenge, 'text=' + JSON.stringify(r.text));
  check('(a) GET no llama al RPC', rpcBodies.length === 0, 'rpc=' + rpcBodies.length);

  // (b) GET con token incorrecto -> 403 y CERO llamadas al RPC
  rpcBodies.length = 0;
  r = await send(getRequest('hub.mode=subscribe&hub.verify_token=token-equivocado&hub.challenge=' + challenge));
  check('(b) GET token incorrecto = 403 verificacion_fallida',
    r.status === 403 && r.body && r.body.error === 'verificacion_fallida',
    'status=' + r.status + ' error=' + (r.body && r.body.error));
  check('(b) GET rechazado deja CERO llamadas al RPC', rpcBodies.length === 0, 'rpc=' + rpcBodies.length);

  // (c) POST firma valida, 1 status delivered -> 200, procesados=1, p_at exacto
  const delivered = statusPayload([{
    id: 'wamid.HBgMNTczMDAxMjM0NTY3FQIAERgS',
    status: 'delivered',
    timestamp: '1735689600',
    recipient_id: '573001234567',
  }]);
  const deliveredText = JSON.stringify(delivered);
  rpcBodies.length = 0;
  rpcStatus = 200;
  rpcReply = { ok: true, updated: 1, estado: 'delivered' };
  r = await send(postRequest(deliveredText, sign(APP_SECRET, deliveredText)));
  check('(c) POST firma valida = 200', r.status === 200, 'status=' + r.status);
  check('(c) procesados=1 y actualizados=1',
    r.body && r.body.procesados === 1 && r.body.actualizados === 1,
    JSON.stringify(r.body));
  check('(c) el RPC recibio 1 llamada', rpcBodies.length === 1, 'rpc=' + rpcBodies.length);
  const cBody = rpcBodies.length === 1 ? rpcBodies[0].body : null;
  check('(c) p_estado=delivered llega al RPC', !!cBody && cBody.p_estado === 'delivered',
    'p_estado=' + (cBody && cBody.p_estado));
  const expectedAt = new Date(1735689600 * 1000).toISOString();
  check('(c) p_at = timestamp convertido', !!cBody && cBody.p_at === expectedAt,
    'p_at=' + (cBody && cBody.p_at) + ' esperado=' + expectedAt);
  check('(c) el RPC va con apikey y Bearer de service_role',
    rpcBodies.length === 1 && rpcBodies[0].apikey === SERVICE_KEY &&
    rpcBodies[0].authorization === 'Bearer ' + SERVICE_KEY,
    'apikey_ok=' + (rpcBodies.length === 1 && rpcBodies[0].apikey === SERVICE_KEY));
  check('(c) el path es el RPC public.fn_wa_estado_meta',
    rpcBodies.length === 1 && rpcBodies[0].path === '/rest/v1/rpc/fn_wa_estado_meta',
    'path=' + (rpcBodies.length === 1 ? rpcBodies[0].path : 'n/a'));

  // (d) POST firma invalida -> 401 y CERO llamadas al RPC
  rpcBodies.length = 0;
  r = await send(postRequest(deliveredText, sign('otro-secreto-cualquiera', deliveredText)));
  check('(d) firma invalida = 401 firma_invalida',
    r.status === 401 && r.body && r.body.error === 'firma_invalida',
    'status=' + r.status + ' error=' + (r.body && r.body.error));
  check('(d) firma invalida deja CERO llamadas al RPC', rpcBodies.length === 0, 'rpc=' + rpcBodies.length);

  // (e) POST sin header de firma -> 401
  rpcBodies.length = 0;
  r = await send(postRequest(deliveredText, undefined));
  check('(e) POST sin firma = 401 firma_invalida',
    r.status === 401 && r.body && r.body.error === 'firma_invalida',
    'status=' + r.status + ' error=' + (r.body && r.body.error));
  check('(e) sin firma deja CERO llamadas al RPC', rpcBodies.length === 0, 'rpc=' + rpcBodies.length);

  // (f) POST failed con errors[0].code=131026 -> p_error_code llega al RPC
  const failed = statusPayload([{
    id: 'wamid.HBgMNTczMDAxMjM0NTY3FQIAERgT',
    status: 'failed',
    timestamp: '1735689700',
    errors: [{ code: 131026, title: 'Message undeliverable' }],
  }]);
  const failedText = JSON.stringify(failed);
  rpcBodies.length = 0;
  rpcReply = { ok: true, updated: 1, estado: 'failed' };
  r = await send(postRequest(failedText, sign(APP_SECRET, failedText)));
  const fBody = rpcBodies.length === 1 ? rpcBodies[0].body : null;
  check('(f) POST failed = 200', r.status === 200, 'status=' + r.status);
  check('(f) p_error_code=131026 llega al RPC', !!fBody && fBody.p_error_code === 131026,
    'p_error_code=' + (fBody && fBody.p_error_code));
  check('(f) p_estado=failed llega al RPC', !!fBody && fBody.p_estado === 'failed',
    'p_estado=' + (fBody && fBody.p_estado));

  // (g) POST status desconocido (deleted) -> 200, ignorados=1, CERO RPC
  const deleted = statusPayload([{
    id: 'wamid.HBgMNTczMDAxMjM0NTY3FQIAERgU',
    status: 'deleted',
    timestamp: '1735689800',
  }]);
  const deletedText = JSON.stringify(deleted);
  rpcBodies.length = 0;
  r = await send(postRequest(deletedText, sign(APP_SECRET, deletedText)));
  check('(g) status desconocido = 200 con ignorados=1',
    r.status === 200 && r.body && r.body.ignorados === 1 && r.body.procesados === 0,
    JSON.stringify(r.body));
  check('(g) status desconocido deja CERO llamadas al RPC', rpcBodies.length === 0, 'rpc=' + rpcBodies.length);

  // (h) POST con 3 statuses -> 3 llamadas y procesados=3
  const three = statusPayload([
    { id: 'wamid.AAA', status: 'sent', timestamp: '1735689900' },
    { id: 'wamid.BBB', status: 'delivered', timestamp: '1735689910' },
    { id: 'wamid.CCC', status: 'read', timestamp: '1735689920' },
  ]);
  const threeText = JSON.stringify(three);
  rpcBodies.length = 0;
  rpcReply = { ok: true, updated: 1, estado: 'read' };
  r = await send(postRequest(threeText, sign(APP_SECRET, threeText)));
  check('(h) 3 statuses = procesados=3', r.status === 200 && r.body && r.body.procesados === 3,
    JSON.stringify(r.body));
  check('(h) 3 statuses = 3 llamadas al RPC', rpcBodies.length === 3, 'rpc=' + rpcBodies.length);
  const estadosEnviados = rpcBodies.map((x) => x.body && x.body.p_estado).sort().join(',');
  check('(h) los 3 estados llegan al RPC', estadosEnviados === 'delivered,read,sent',
    'estados=' + estadosEnviados);

  // (i) RPC devolviendo no_encontrado -> el webhook sigue siendo 200
  rpcBodies.length = 0;
  rpcReply = { ok: false, reason: 'no_encontrado' };
  r = await send(postRequest(deliveredText, sign(APP_SECRET, deliveredText)));
  check('(i) no_encontrado del RPC no cambia el 200',
    r.status === 200 && r.body && r.body.ok === true,
    'status=' + r.status + ' body=' + JSON.stringify(r.body));
  check('(i) el no_encontrado se cuenta como fallo, no como actualizado',
    r.body && r.body.actualizados === 0, 'actualizados=' + (r.body && r.body.actualizados));

  // (j) WA_APP_SECRET vacio -> 503 servicio_misconfigurado
  rpcBodies.length = 0;
  ENV.WA_APP_SECRET = '';
  r = await send(postRequest(deliveredText, sign(APP_SECRET, deliveredText)));
  check('(j) WA_APP_SECRET vacio = 503 servicio_misconfigurado',
    r.status === 503 && r.body && r.body.error === 'servicio_misconfigurado',
    'status=' + r.status + ' error=' + (r.body && r.body.error));
  check('(j) sin app secret deja CERO llamadas al RPC', rpcBodies.length === 0, 'rpc=' + rpcBodies.length);
  ENV.WA_APP_SECRET = APP_SECRET;

  // (k) Ni el app secret ni el verify token aparecen en ningun cuerpo
  const leakSecret = responseTexts.some((t) => t.indexOf(APP_SECRET) !== -1);
  const leakToken = responseTexts.some((t) => t.indexOf(VERIFY_TOKEN) !== -1);
  check('(k) WA_APP_SECRET no aparece en ningun cuerpo de respuesta', !leakSecret,
    'revisados=' + responseTexts.length);
  check('(k) WA_VERIFY_TOKEN no aparece en ningun cuerpo de respuesta', !leakToken,
    'revisados=' + responseTexts.length);

  // -------------------------------------------------------------------------
  await stopServer(pg);

  const fails = results.filter((x) => !x.ok);
  console.log('');
  console.log('RESULTADO: ' + (results.length - fails.length) + '/' + results.length + ' PASS');
  if (fails.length > 0) {
    fails.forEach((f) => console.log('  FALLO: ' + f.name + ' -> ' + f.detail));
    process.exitCode = 1;
  } else {
    process.exitCode = 0;
  }

  // En Windows, salir mientras libuv cierra sockets dispara un assert interno
  // de node (no es un fallo del contrato). Se deja drenar los handles.
  await new Promise((resolve) => setTimeout(resolve, 500));
  process.exit(process.exitCode);
})().catch((e) => {
  console.error('ERROR NO CONTROLADO:', e && e.message ? e.message : e);
  process.exit(1);
});
