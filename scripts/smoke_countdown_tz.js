/**
 * smoke_countdown_tz.js
 * Certificacion de TSK-117: motor de fechas v124 (epoch absoluto, Bogota UTC-5 fijo)
 * y contador con cleanup de intervalo, en evento-app.html (motor compartido de los silos).
 *
 * Valida:
 *  - extraccion y evaluacion del bloque REAL del motor (var __CO_OFFSET_MIN ... parseSpanishDate)
 *  - math del offset: 2026-11-20 20:00 Bogota -> 2026-11-21T01:00:00Z
 *  - guarda contra el signo invertido (5 h antes -> 2026-11-20T15:00:00Z)
 *  - independencia de la zona del dispositivo (procesos hijo con TZ distinto)
 *  - casos borde: legacy 'de', hora vacia/null, hora embebida, hora invalida, fecha invalida
 *  - cleanup estatico del intervalo (clearInterval(window.__cdTimer), isFinite(__cdTarget))
 *  - no-basura: el contador no escribe NaN ni innerText fuera de __cdPaint
 *
 * Uso: node scripts/smoke_countdown_tz.js
 * Exit: 0 = todo PASS, 1 = al menos un FAIL
 * Solo ASCII: no introducir acentos ni simbolos unicode.
 */

'use strict';

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const ROOT = path.resolve(__dirname, '..');
const KERNEL = path.join(ROOT, 'evento-app.html');

// 2026-11-20 20:00 en Bogota (UTC-5) = 2026-11-21T01:00:00Z
const TARGET_EPOCH = Date.UTC(2026, 10, 21, 1, 0, 0);
// Mismo evento con el signo del offset INVERTIDO: 5 h antes.
const WRONG_EPOCH = Date.UTC(2026, 10, 20, 15, 0, 0);
// 2026-11-20 00:00 en Bogota.
const MIDNIGHT_BOGOTA = Date.UTC(2026, 10, 20, 5, 0, 0);
// 2026-11-20T22:30 embebido + 5 h.
const EMBEDDED_EPOCH = Date.UTC(2026, 10, 21, 3, 30, 0);
// 2026-11-20 09:05 en Bogota.
const NINE_OH_FIVE = Date.UTC(2026, 10, 20, 14, 5, 0);

const ZONES = ['UTC', 'Asia/Tokyo', 'America/Bogota', 'Europe/Madrid'];

let pass = 0;
let fail = 0;
const failures = [];

function check(name, ok, detail) {
  if (ok) {
    pass++;
    console.log('  PASS ' + name + (detail ? ' (' + detail + ')' : ''));
  } else {
    fail++;
    failures.push(name + (detail ? ' :: ' + detail : ''));
    console.log('  FAIL ' + name + (detail ? ' (' + detail + ')' : ''));
  }
}

function read(p) {
  return fs.readFileSync(p, 'utf8');
}

/**
 * Bloque del motor: desde `var __CO_OFFSET_MIN` hasta la funcion siguiente.
 * Si el marcador no existe el motor fue movido/renombrado: FAIL, no silencio.
 */
function extractMotor(html) {
  const start = html.indexOf('var __CO_OFFSET_MIN');
  if (start === -1) return null;
  const end = html.indexOf('function switchForm', start);
  if (end === -1) return null;
  const block = html.slice(start, end).trim();
  return block.length > 100 ? block : null;
}

/** Bloque del contador: desde `const __cdTarget` hasta el mapeo de hero. */
function extractCounter(html) {
  const start = html.indexOf('const __cdTarget = parseSpanishDate');
  if (start === -1) return null;
  let end = html.indexOf('// MAPEO DE HERO', start);
  if (end === -1) end = html.indexOf('__tituloEl', start);
  if (end === -1) return null;
  return html.slice(start, end);
}

/** Evalua el bloque real del motor sin cargar el HTML completo. */
function buildParser(motor) {
  const factory = new Function(
    motor + '\nreturn { parse: parseSpanishDate, hora: __horaA24, offset: __CO_OFFSET_MIN };'
  );
  return factory();
}

function callParser(parse, a, b) {
  try {
    return { date: parse(a, b), threw: null };
  } catch (e) {
    return { date: null, threw: e };
  }
}

function expectEpoch(parse, name, a, b, expected) {
  const r = callParser(parse, a, b);
  if (r.threw) return check(name, false, 'lanzo: ' + r.threw.message);
  const got = r.date instanceof Date ? r.date.getTime() : NaN;
  check(name, got === expected, 'epoch=' + got + ' esperado=' + expected);
}

function expectNaN(parse, name, a, b) {
  const r = callParser(parse, a, b);
  if (r.threw) return check(name, false, 'lanzo: ' + r.threw.message);
  const isDate = r.date instanceof Date;
  const got = isDate ? r.date.getTime() : null;
  check(name, isDate && got !== got, 'Date=' + isDate + ' getTime()=' + got);
}

// ---------------------------------------------------------------------------
// Modo sonda: lo invoca este mismo script en un proceso hijo con otro TZ.
// ---------------------------------------------------------------------------
if (process.argv[2] === '--tz-probe') {
  const html = read(KERNEL);
  const motor = extractMotor(html);
  if (!motor) process.exit(2);
  const api = buildParser(motor);
  process.stdout.write(String(api.parse('2026-11-20', '20:00').getTime()));
  process.exit(0);
}

// ---------------------------------------------------------------------------
// Arranque
// ---------------------------------------------------------------------------
console.log('smoke_countdown_tz.js - TSK-117 (motor de fechas v124 + contador)');
console.log('Kernel: ' + KERNEL);

check('evento-app.html existe', fs.existsSync(KERNEL));

const html = read(KERNEL);
const motor = extractMotor(html);
const counter = extractCounter(html);

check('bloque del motor extraido', !!motor, motor ? motor.length + ' bytes' : 'marcador var __CO_OFFSET_MIN ausente');
check('bloque del contador extraido', !!counter, counter ? counter.length + ' bytes' : 'marcador const __cdTarget ausente');

let api = null;
try {
  api = motor ? buildParser(motor) : null;
  check('motor evaluable con new Function', !!api);
} catch (e) {
  check('motor evaluable con new Function', false, e.message);
}

if (api) {
  check('__CO_OFFSET_MIN === -300 (Bogota UTC-5 sin DST)', api.offset === -300, 'valor=' + api.offset);
  check('parseSpanishDate es funcion de 2 parametros', typeof api.parse === 'function' && api.parse.length === 2, 'arity=' + api.parse.length);
  check('__horaA24 es funcion', typeof api.hora === 'function');

  // --- A2: math del offset, el assert duro de TSK-117 ---
  const r = callParser(api.parse, '2026-11-20', '20:00');
  const got = r.threw ? NaN : r.date.getTime();
  check('2026-11-20 20:00 Bogota === Date.UTC(2026,10,21,1,0,0)', got === TARGET_EPOCH, 'epoch=' + got);
  check('NO cae en el valor del signo invertido (5 h antes)', got !== WRONG_EPOCH, 'epoch=' + got + ' != ' + WRONG_EPOCH);
  check('offset SUMA 5 h sobre el naive UTC', got - Date.UTC(2026, 10, 20, 20, 0, 0) === 5 * 3600000, 'delta_h=' + ((got - Date.UTC(2026, 10, 20, 20, 0, 0)) / 3600000));

  // --- A3: independencia de la zona del dispositivo ---
  const probes = [];
  for (const z of ZONES) {
    try {
      const out = execFileSync(process.execPath, [__filename, '--tz-probe'], {
        env: Object.assign({}, process.env, { TZ: z }),
        encoding: 'utf8'
      }).trim();
      probes.push({ z: z, e: Number(out) });
    } catch (e) {
      probes.push({ z: z, e: NaN });
    }
  }
  const detail = probes.map(function (p) { return p.z + '=' + p.e; }).join(' ');
  check('epoch identico en ' + ZONES.length + ' zonas horarias', probes.every(function (p) { return p.e === TARGET_EPOCH; }), detail);
  check('ninguna sonda devolvio NaN', probes.every(function (p) { return p.e === p.e; }), detail);

  // --- A4: casos borde ---
  expectEpoch(api.parse, 'ISO + HH:MM', '2026-11-20', '20:00', TARGET_EPOCH);
  expectEpoch(api.parse, 'legacy "20 de noviembre de 2026"', '20 de noviembre de 2026', '20:00', TARGET_EPOCH);
  expectEpoch(api.parse, 'ISO + hora vacia -> 00:00 Bogota', '2026-11-20', '', MIDNIGHT_BOGOTA);
  expectEpoch(api.parse, 'ISO + hora null -> 00:00 Bogota', '2026-11-20', null, MIDNIGHT_BOGOTA);
  expectEpoch(api.parse, 'ISO + hora embebida T22:30', '2026-11-20T22:30', '', EMBEDDED_EPOCH);
  expectEpoch(api.parse, 'hora de un digito H:MM', '2026-11-20', '9:05', NINE_OH_FIVE);
  expectEpoch(api.parse, 'hora invalida 25:00 -> fallback 00:00', '2026-11-20', '25:00', MIDNIGHT_BOGOTA);
  expectNaN(api.parse, 'rango "24 Jun - 10 Ago 2026" -> NaN', '24 Jun - 10 Ago 2026', '11:56 AM');
  expectNaN(api.parse, 'fecha null -> NaN', null, '20:00');
  expectNaN(api.parse, 'fecha y hora undefined -> NaN', undefined, undefined);
  expectNaN(api.parse, 'fecha basura -> NaN', 'no-es-fecha', '20:00');

  // Desborde conocido: Date.UTC(2026,1,30) rueda a marzo. NO se assertea el
  // valor (fragil por diseno); solo se exige que no lance y que sea finito.
  const ov = callParser(api.parse, '2026-02-30', '20:00');
  const ovT = ov.threw ? NaN : ov.date.getTime();
  check('2026-02-30 no lanza excepcion', !ov.threw, ov.threw ? ov.threw.message : 'getTime()=' + ovT);
  check('2026-02-30 devuelve epoch finito (desborde a marzo, documentado)', ovT === ovT, 'iso=' + (ovT === ovT ? new Date(ovT).toISOString() : 'NaN'));

  // Guarda anti-regresion: el motor no debe volver a parsear strings con new Date().
  check('motor sin new Date(\'...\') dependiente de zona', !/new\s+Date\s*\(\s*[\u0027\u0022\u0060]/.test(motor), 'patron v123 ausente');
  check('motor sin toLowerCase sobre dateStr sin guarda', /String\(dateStr == null/.test(motor), 'guarda de tipo presente');
}

// ---------------------------------------------------------------------------
// A5/A6: asserts estaticos sobre el contador
// ---------------------------------------------------------------------------
if (counter) {
  const clears = (counter.match(/clearInterval\(window\.__cdTimer\)/g) || []).length;
  const creates = (counter.match(/window\.__cdTimer = setInterval\(/g) || []).length;
  const clearIdx = counter.indexOf('clearInterval(window.__cdTimer)');
  const createIdx = counter.indexOf('window.__cdTimer = setInterval(');

  check('clearInterval(window.__cdTimer) presente >= 2 veces', clears >= 2, 'ocurrencias=' + clears);
  check('window.__cdTimer = setInterval( presente', creates >= 1, 'ocurrencias=' + creates);
  check('clearInterval ocurre ANTES de crear el intervalo', clearIdx !== -1 && createIdx !== -1 && clearIdx < createIdx, 'clearIdx=' + clearIdx + ' createIdx=' + createIdx);
  check('guarda isFinite(__cdTarget) presente', counter.indexOf('isFinite(__cdTarget)') !== -1);
  check('el intervalo se auto-detiene (__cdDone) al vencer', counter.indexOf('__cdDone') !== -1);

  // No-basura: una sola escritura de innerText y dentro de __cdPaint.
  const writes = (counter.match(/innerText/g) || []).length;
  const paintIdx = counter.indexOf('__cdPaint = ');
  const writeIdx = counter.indexOf('innerText');
  check('una sola escritura innerText en el contador', writes === 1, 'ocurrencias=' + writes);
  check('la escritura innerText vive dentro de __cdPaint', paintIdx !== -1 && writeIdx > paintIdx, 'paintIdx=' + paintIdx + ' writeIdx=' + writeIdx);
  check('el contador no escribe el literal NaN', !/[\u0027\u0022]NaN[\u0027\u0022]/.test(counter) && !/innerText\s*=\s*NaN/.test(counter));
  check('el contador no toca IDs fuera de cd-days/hours/mins/secs', !/cd-[a-z]+/.test(counter.replace(/cd-days|cd-hours|cd-mins|cd-secs/g, '')));
}

// ---------------------------------------------------------------------------
// Resumen
// ---------------------------------------------------------------------------
console.log('');
if (fail) {
  console.log('Fallos:');
  for (const f of failures) console.log('  - ' + f);
}
console.log('Resumen: PASS ' + pass + ', FAIL ' + fail);
process.exit(fail ? 1 : 0);