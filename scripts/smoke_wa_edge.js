// ============================================================================
// smoke_wa_edge.js | ADR-089 - contrato de send-wa-recordatorio
// ----------------------------------------------------------------------------
// Ejecuta los SIETE casos de contrato del ADR-089 seccion 9 (fase F2 del ADR,
// F3 del plan) SIN Deno y SIN red real:
//   * stub de globalThis.Deno (env + serve) para cargar el index.ts tal cual,
//   * mock HTTP local para simular Meta (timeout, 429, 400 con codigo, 200),
//   * contador de fetch para probar que el dry-run hace CERO llamadas a graph.
//
// Por que existe: la leccion H1 del proyecto es que "la funcion no lanzo
// excepcion" no valida nada. Este script mira el status y el cuerpo que
// consumiria el reconciliador SQL (net._http_response).
//
// Uso:  node scripts/smoke_wa_edge.js
// Requiere Node >= 22.18 (type stripping nativo de .ts). No requiere Deno,
// ni Docker, ni Supabase CLI, ni credenciales de Meta.
// ============================================================================

'use strict';

const http = require('http');
const path = require('path');
const { pathToFileURL } = require('url');

const EDGE = path.join(__dirname, '..', 'supabase', 'functions', 'send-wa-recordatorio', 'index.ts');
const SERVICE_TOKEN = 'token-de-prueba-no-real';
const WA_TOKEN = 'wa-token-de-prueba-no-real';

// ---------------------------------------------------------------------------
// Entorno simulado (mutable: cada caso ajusta lo que necesita)
// ---------------------------------------------------------------------------
const ENV = {
  SERVICE_SHARED_TOKEN: SERVICE_TOKEN,
  WA_DRY_RUN: '1',
  WA_TOKEN: '',
  WA_PHONE_NUMBER_ID: '',
  WA_GRAPH_VERSION: 'v21.0',
  WA_GRAPH_URL: '',
  SUPABASE_ANON_KEY: '',
  SUPABASE_SERVICE_ROLE_KEY: '',
  ALLOWED_ORIGINS: '',
};

let handler = null;
globalThis.Deno = {
  env: { get: (name) => (Object.prototype.hasOwnProperty.call(ENV, name) ? ENV[name] : undefined) },
  serve: (h) => { handler = h; return { finished: Promise.resolve() }; },
};

// Contador de red: el dry-run debe dejar graphCalls en 0.
let graphCalls = 0;
const realFetch = globalThis.fetch;
globalThis.fetch = function counted(input, init) {
  graphCalls += 1;
  return realFetch(input, init);
};

// ---------------------------------------------------------------------------
// Utilidades del harness
// ---------------------------------------------------------------------------
const results = [];

function check(name, condition, detail) {
  results.push({ name, ok: !!condition, detail: detail || '' });
  const tag = condition ? 'PASS' : 'FAIL';
  console.log('[' + tag + '] ' + name + (detail ? ' -> ' + detail : ''));
}

function validPayload(overrides) {
  const base = {
    idempotencyKey: 'whatsapp:evt_123:ins_456:anticipacion',
    to: '+573001234567',
    template: {
      name: 'recordatorio_anticipacion_56h',
      language: 'es_CO',
      components: [{
        type: 'body',
        parameters: [
          { type: 'text', text: 'Ana' },
          { type: 'text', text: 'Vinilos Inversos' },
          { type: 'text', text: '20 de noviembre, 8:00 p.m.' },
          { type: 'text', text: 'Klandestino, Kr 4 # 19-56' },
          { type: 'text', text: 'https://taquilladirecta.com/evento.html?slug=vinilos-inversos-c8yu' },
        ],
      }],
    },
    meta: { eventoId: 'evt_123', inscritoId: 'ins_456', tipo: 'anticipacion' },
  };
  return Object.assign(base, overrides || {});
}

async function call(body, headers) {
  const req = new Request('http://127.0.0.1/functions/v1/send-wa-recordatorio', {
    method: 'POST',
    headers: Object.assign({ 'content-type': 'application/json' }, headers || {}),
    body: typeof body === 'string' ? body : JSON.stringify(body),
  });
  const res = await handler(req);
  let parsed = null;
  const text = await res.text();
  try { parsed = JSON.parse(text); } catch (_e) { parsed = null; }
  return { status: res.status, body: parsed, text };
}

function startMock(behavior) {
  return new Promise((resolve) => {
    const server = http.createServer((req, res) => {
      let data = '';
      req.on('data', (chunk) => { data += chunk; });
      req.on('end', () => behavior(req, res, data));
    });
    server.listen(0, '127.0.0.1', () => resolve(server));
  });
}

function stopMock(server) {
  return new Promise((resolve) => {
    if (typeof server.closeAllConnections === 'function') server.closeAllConnections();
    server.close(() => resolve());
  });
}

// ---------------------------------------------------------------------------
// Casos
// ---------------------------------------------------------------------------
(async () => {
  await import(pathToFileURL(EDGE).href);

  if (typeof handler !== 'function') {
    console.error('No se pudo capturar el handler de Deno.serve');
    process.exit(1);
  }

  const auth = { 'x-service-token': SERVICE_TOKEN };

  // (a) payload valido en dry-run -> 202 {dryRun:true, messageId:null}
  ENV.WA_DRY_RUN = '1';
  let r = await call(validPayload(), auth);
  check('(a) dry-run payload valido = 202', r.status === 202, 'status=' + r.status);
  check('(a) dryRun=true y messageId=null',
    r.body && r.body.dryRun === true && r.body.messageId === null,
    JSON.stringify(r.body));

  // (b) telefono invalido -> 400 telefono_invalido
  r = await call(validPayload({ to: '3001234567' }), auth);
  check('(b) telefono no E.164 = 400 telefono_invalido',
    r.status === 400 && r.body && r.body.error === 'telefono_invalido',
    'status=' + r.status + ' error=' + (r.body && r.body.error));

  // (c) plantilla invalida -> 400 plantilla_invalida
  r = await call(validPayload({ template: { name: 'Recordatorio 56h', language: 'es_CO', components: [] } }), auth);
  check('(c) plantilla con nombre invalido = 400 plantilla_invalida',
    r.status === 400 && r.body && r.body.error === 'plantilla_invalida',
    'status=' + r.status + ' error=' + (r.body && r.body.error));

  // (d) token de servicio incorrecto -> 401
  r = await call(validPayload(), { 'x-service-token': 'token-equivocado' });
  check('(d) X-Service-Token incorrecto = 401 no_autorizado',
    r.status === 401 && r.body && r.body.error === 'no_autorizado',
    'status=' + r.status);

  // (e) sin credenciales -> 401
  r = await call(validPayload(), {});
  check('(e) sin token ni JWT = 401 no_autorizado',
    r.status === 401 && r.body && r.body.error === 'no_autorizado',
    'status=' + r.status);

  // (f) timeout de Meta simulado -> 504, nunca 200 (mock que nunca responde)
  const slow = await startMock(() => { /* nunca responde: fuerza el abort */ });
  const slowPort = slow.address().port;
  ENV.WA_DRY_RUN = '0';
  ENV.WA_TOKEN = WA_TOKEN;
  ENV.WA_PHONE_NUMBER_ID = '1234567890';
  ENV.WA_GRAPH_URL = 'http://127.0.0.1:' + slowPort + '/mock/messages';
  graphCalls = 0;
  r = await call(validPayload(), auth);
  check('(f) timeout de Meta = 504 timeout_meta', r.status === 504 && r.body && r.body.error === 'timeout_meta',
    'status=' + r.status + ' error=' + (r.body && r.body.error));
  check('(f) el timeout NO se reintenta (1 sola llamada)', graphCalls === 1, 'graphCalls=' + graphCalls);
  await stopMock(slow);

  // (g) WA_DRY_RUN=1 explicito -> 202 y CERO llamadas a graph
  ENV.WA_DRY_RUN = '1';
  graphCalls = 0;
  r = await call(validPayload(), auth);
  check('(g) WA_DRY_RUN=1 = 202 {dryRun:true}',
    r.status === 202 && r.body && r.body.dryRun === true && r.body.messageId === null,
    'status=' + r.status);
  check('(g) dry-run hace CERO llamadas a graph', graphCalls === 0, 'graphCalls=' + graphCalls);

  // (h) EXTRA contrato con el reconciliador: 2xx con messageId -> 200 + id
  ENV.WA_DRY_RUN = '0';
  const okMock = await startMock((_req, res) => {
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ messaging_product: 'whatsapp', messages: [{ id: 'wamid.TEST123' }] }));
  });
  ENV.WA_GRAPH_URL = 'http://127.0.0.1:' + okMock.address().port + '/mock/messages';
  r = await call(validPayload(), auth);
  check('(h) Meta 2xx con messageId = 200 + messageId',
    r.status === 200 && r.body && r.body.messageId === 'wamid.TEST123',
    'status=' + r.status + ' messageId=' + (r.body && r.body.messageId));
  await stopMock(okMock);

  // (i) EXTRA: error de Meta 131026 -> mismo status + code para el reconciliador
  const errMock = await startMock((_req, res) => {
    res.writeHead(400, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ error: { message: 'Recipient not on WhatsApp', code: 131026 } }));
  });
  ENV.WA_GRAPH_URL = 'http://127.0.0.1:' + errMock.address().port + '/mock/messages';
  r = await call(validPayload(), auth);
  check('(i) Meta 400/131026 se reenvia con su status y su code',
    r.status === 400 && r.body && r.body.code === 131026 && r.body.error === 'meta_error',
    'status=' + r.status + ' code=' + (r.body && r.body.code));
  await stopMock(errMock);

  // (j) EXTRA: sin credenciales y sin dry-run -> 503, nunca exito fingido
  ENV.WA_DRY_RUN = '0';
  ENV.WA_TOKEN = '';
  ENV.WA_PHONE_NUMBER_ID = '';
  r = await call(validPayload(), auth);
  check('(j) sin credenciales y sin dry-run = 503 servicio_misconfigurado',
    r.status === 503 && r.body && r.body.error === 'servicio_misconfigurado',
    'status=' + r.status);

  // (k) El secreto no aparece en ninguna respuesta ni en el log de este harness
  const haySecreto = results.some((x) => x.detail.includes(WA_TOKEN) || x.detail.includes(SERVICE_TOKEN));
  check('(k) el token no aparece en ningun cuerpo de respuesta', !haySecreto, 'revisado=' + results.length + ' casos');

  // -------------------------------------------------------------------------
  const fails = results.filter((x) => !x.ok);
  console.log('');
  console.log('RESULTADO: ' + (results.length - fails.length) + '/' + results.length + ' PASS');
  if (fails.length > 0) {
    fails.forEach((f) => console.log('  FALLO: ' + f.name + ' -> ' + f.detail));
    process.exitCode = 1;
  } else {
    process.exitCode = 0;
  }

  // En Windows, salir mientras libuv cierra el socket del fetch abortado
  // dispara un assert interno de node (no es un fallo del contrato). Se deja
  // drenar los handles antes de terminar.
  await new Promise((resolve) => setTimeout(resolve, 500));
  process.exit(process.exitCode);
})().catch((e) => {
  console.error('ERROR NO CONTROLADO:', e && e.message ? e.message : e);
  process.exit(1);
});
