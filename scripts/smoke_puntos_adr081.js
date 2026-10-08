'use strict';

/*
 * smoke_puntos_adr081.js - Smoke de la semantica NULL-vs-vacio de puntos de
 * escaneo y la propagacion por interseccion (ADR-081).
 *
 * Verificacion ESTATICA (analisis de texto) sobre los archivos reales del repo.
 * No usa red, no escribe nada y no modifica archivos.
 * Contrato de salida (igual que smoke_checkin_multipunto.js):
 *   lineas "PASS [n] ..." / "FAIL [n] ..." y cierre "Resumen: PASS N, FAIL M".
 *
 * Cubre:
 *   1. migrations/adr081_puntos_none_semantica.sql: existe, 100% ASCII y
 *      normaliza '[]' -> NULL en public.inscritos (idempotente, sin DDL).
 *   2. admin.html: propagarPuntosEvento + _puntosEventoCambiaron; invocacion
 *      solo en guardarPuntosEvento y guardarEventoWizard (no en _crearEventoUnico
 *      ni _crearSerie).
 *   3. propagarPuntosEvento: interseccion por nombre, asigna [] (no null) e
 *      ignora NULL (Array.isArray).
 *   4. admin.html: tab data-pnl-pill="puntos", bloque data-pnl-tab="puntos",
 *      pnlPuntosBulk y seleccion propia .pp-row-sel (sin colision con .row-sel).
 *   5. admin.html: el CSV distingue Hereda / Ninguno / override.
 *   6. scanner.html: regla hasOwn = Array.isArray(...).
 *
 * Uso:   node scripts/smoke_puntos_adr081.js
 * Exit:  0 = todo PASS ; 1 = algun FAIL
 */

var fs = require('fs');
var path = require('path');

var ROOT = path.join(__dirname, '..');
var ADMIN = path.join(ROOT, 'admin.html');
var SCANNER = path.join(ROOT, 'scanner.html');
var MIGRACION = path.join(ROOT, 'migrations', 'adr081_puntos_none_semantica.sql');

var passCount = 0;
var failCount = 0;
var assertNum = 0;

function log(msg) {
  process.stdout.write(String(msg) + '\n');
}

function assert(ok, label, reason) {
  assertNum += 1;
  if (ok) {
    passCount += 1;
    log('PASS [' + assertNum + '] ' + label);
  } else {
    failCount += 1;
    log('FAIL [' + assertNum + '] ' + label + ' -> ' + (reason || 'no cumplido'));
  }
}

function readText(abs) {
  try {
    if (!fs.existsSync(abs)) return null;
    return fs.readFileSync(abs, 'utf8');
  } catch (err) {
    return null;
  }
}

function countRe(text, re) {
  var m = text.match(re);
  return m ? m.length : 0;
}

/* Quita las lineas de comentario (-- ...) para inspeccionar SOLO el SQL real. */
function stripComentariosSql(src) {
  return src.split(/\r?\n/).filter(function (l) {
    return l.replace(/^\s+/, '').indexOf('--') !== 0;
  }).join('\n');
}

/* Region de una funcion de nivel superior: desde su cabecera hasta la siguiente
   linea que empieza con "function " o "async function " (columna 0). */
function cuerpoFuncion(text, nombre) {
  var re = new RegExp('(?:^|\\n)(?:async\\s+)?function\\s+' + nombre + '\\s*\\(');
  var m = re.exec(text);
  if (!m) return null;
  var ini = m.index + (m[0].charAt(0) === '\n' ? 1 : 0);
  var resto = text.slice(ini + 1);
  var m2 = /\n(?:async\s+)?function\s+[A-Za-z_$]/.exec(resto);
  var fin = m2 ? (ini + 1 + m2.index) : text.length;
  return text.slice(ini, fin);
}

/* (a) migracion: existe, ASCII, UPDATE '[]' -> NULL, sin DDL destructivo. */
function checkMigracion(src) {
  if (src === null) {
    assert(false, 'migracion adr081 existe y es legible', 'archivo ausente');
    return;
  }
  assert(true, 'migracion adr081 existe y es legible');
  assert(src.indexOf('UPDATE public.inscritos') !== -1,
    'migracion: UPDATE public.inscritos',
    'no se hallo "UPDATE public.inscritos"');
  assert(src.indexOf('SET puntos_acceso = NULL') !== -1,
    'migracion: SET puntos_acceso = NULL',
    'no se hallo "SET puntos_acceso = NULL"');
  assert(src.indexOf("WHERE puntos_acceso = '[]'::jsonb") !== -1,
    "migracion: WHERE puntos_acceso = '[]'::jsonb (solo el array vacio canonico)",
    "no se hallo el filtro '[]'::jsonb");
  var codigo = stripComentariosSql(src);
  assert(!/DROP\s|DELETE\s|TRUNCATE\s/i.test(codigo),
    'migracion: sin DROP/DELETE/TRUNCATE en el SQL real (aditiva, Cero Borrado)',
    'se hallo DDL/DML destructivo fuera de comentarios');
  assert(!/\bCREATE\s+(TABLE|INDEX|VIEW)\b/i.test(codigo),
    'migracion: sin DDL CREATE (solo DML de normalizacion)',
    'se hallo CREATE en el SQL real');
  assert(codigo.indexOf('NOTIFY pgrst') !== -1,
    'migracion: recarga schema cache (NOTIFY pgrst)',
    'no se hallo NOTIFY pgrst');
}

/* (b) migracion 100% ASCII (0 bytes > 127). */
function checkMigracionAscii(src) {
  if (src === null) {
    assert(false, 'migracion adr081 es 100% ASCII', 'archivo ausente');
    return;
  }
  var high = 0;
  for (var i = 0; i < src.length; i += 1) {
    if (src.charCodeAt(i) > 127) high += 1;
  }
  assert(high === 0, 'migracion adr081: 100% ASCII (0 bytes > 127)', 'bytes>127=' + high);
}

/* (c) admin: invocacion acotada de propagarPuntosEvento. */
function checkInvocacion(src) {
  if (src === null) { assert(false, 'admin.html existe y es legible', 'archivo ausente'); return; }
  assert(src.indexOf('function _puntosEventoCambiaron') !== -1,
    'admin: existe _puntosEventoCambiaron (detector de cambio de la lista)',
    'no se hallo "_puntosEventoCambiaron"');
  assert(/async\s+function\s+propagarPuntosEvento\s*\(/.test(src),
    'admin: existe propagarPuntosEvento',
    'no se hallo "async function propagarPuntosEvento"');

  var defs = countRe(src, /function\s+propagarPuntosEvento\s*\(/g);
  var usos = countRe(src, /propagarPuntosEvento\s*\(/g);
  assert(defs === 1 && usos === 3,
    'admin: propagarPuntosEvento tiene 1 definicion y 2 call sites',
    'defs=' + defs + ' usos=' + usos);

  var wiz = cuerpoFuncion(src, 'guardarEventoWizard');
  assert(wiz !== null && wiz.indexOf('_puntosEventoCambiaron(') !== -1 &&
    wiz.indexOf('propagarPuntosEvento(') !== -1,
    'admin: guardarEventoWizard propaga condicionado por _puntosEventoCambiaron',
    'falta _puntosEventoCambiaron o propagarPuntosEvento en guardarEventoWizard');
  var wizGuard = wiz !== null &&
    /if\s*\(\s*_puntosEventoCambiaron\(/.test(wiz) &&
    wiz.indexOf('propagarPuntosEvento(') > wiz.indexOf('if (_puntosEventoCambiaron(')
      || /if\s*\(\s*_puntosEventoCambiaron\([^)]*\)\s*\)\s*\{[\s\S]*?propagarPuntosEvento\(/.test(wiz || '');
  assert(!!wizGuard,
    'admin: la propagacion del wizard va DENTRO del if (_puntosEventoCambiaron(...))',
    'propagarPuntosEvento no quedo bajo el if del cambio');

  var gpe = cuerpoFuncion(src, 'guardarPuntosEvento');
  assert(gpe !== null && gpe.indexOf('propagarPuntosEvento(') !== -1,
    'admin: guardarPuntosEvento invoca propagarPuntosEvento',
    'falta la invocacion en guardarPuntosEvento');

  var unico = cuerpoFuncion(src, '_crearEventoUnico');
  assert(unico !== null && unico.indexOf('propagarPuntosEvento') === -1,
    'admin: _crearEventoUnico NO invoca propagarPuntosEvento (crear no reconcilia)',
    'se hallo propagarPuntosEvento en _crearEventoUnico');

  var serie = cuerpoFuncion(src, '_crearSerie');
  assert(serie !== null && serie.indexOf('propagarPuntosEvento') === -1,
    'admin: _crearSerie NO invoca propagarPuntosEvento (crear no reconcilia)',
    'se hallo propagarPuntosEvento en _crearSerie');
}

/* (d) propagarPuntosEvento: interseccion por nombre, [] (no null), ignora NULL. */
function checkPropagacion(src) {
  if (src === null) { assert(false, 'admin: cuerpo de propagarPuntosEvento', 'archivo ausente'); return; }
  var cuerpo = cuerpoFuncion(src, 'propagarPuntosEvento');
  if (cuerpo === null) {
    assert(false, 'admin: cuerpo de propagarPuntosEvento', 'no se pudo aislar la funcion');
    return;
  }
  assert(/filter\(p\s*=>\s*nuevos\.has\(p\)\)/.test(cuerpo),
    'propagacion: interseccion por NOMBRE (puntos_acceso.filter(p => nuevos.has(p)))',
    'no se hallo la interseccion por nombre');
  assert(/Array\.isArray\(i\.puntos_acceso\)/.test(cuerpo),
    'propagacion: ignora NULL via Array.isArray (solo override real)',
    'no se hallo el filtro Array.isArray(i.puntos_acceso)');
  assert(/valor\s*:\s*i\.puntos_acceso\.filter\(p\s*=>\s*nuevos\.has\(p\)\)/.test(cuerpo),
    'propagacion: el nuevo valor es el array interseccion ([] si queda vacio, NUNCA null)',
    'el valor asignado no es el array filtrado');
  assert(cuerpo.indexOf(': null') === -1 && cuerpo.indexOf('? null') === -1,
    'propagacion: sin fallback a null (vacio se persiste como [])',
    'se hallo un fallback a null en la propagacion');
}

/* (e) UI: tab/bloque Puntos, bulk y seleccion propia. */
function checkUiPuntos(src) {
  if (src === null) { assert(false, 'admin: UI de la vista Puntos', 'archivo ausente'); return; }
  assert(src.indexOf('data-pnl-pill="puntos"') !== -1,
    'admin: existe el tab data-pnl-pill="puntos"',
    'no se hallo data-pnl-pill="puntos"');
  assert(src.indexOf('data-pnl-tab="puntos"') !== -1,
    'admin: existe el bloque data-pnl-tab="puntos"',
    'no se hallo data-pnl-tab="puntos"');
  assert(src.indexOf('function pnlPuntosBulk') !== -1 &&
    countRe(src, /pnlPuntosBulk\s*\(/g) >= 2,
    'admin: existe pnlPuntosBulk y esta cableado a los botones',
    'definicion o call sites ausentes');
  assert(src.indexOf('.pp-row-sel') !== -1,
    'admin: la vista Por punto usa la clase propia .pp-row-sel',
    'no se hallo .pp-row-sel');
  var ppSel = cuerpoFuncion(src, '_ppSelIds');
  assert(ppSel !== null && ppSel.indexOf('.pp-row-sel') !== -1 && ppSel.indexOf('.row-sel') === -1,
    'admin: _ppSelIds usa .pp-row-sel y NO colisiona con .row-sel (Asistentes)',
    'la seleccion por punto referencia la clase de Asistentes o ninguna');
}

/* (f) CSV: distingue Hereda / Ninguno / override. */
function checkCsv(src) {
  if (src === null) { assert(false, 'admin: CSV de puntos en 3 estados', 'archivo ausente'); return; }
  assert(/puntos_acceso\s*==\s*null\s*\?\s*'Hereda'/.test(src),
    "admin: CSV marca 'Hereda' cuando puntos_acceso == null",
    "no se hallo el estado 'Hereda'");
  assert(/:\s*'Ninguno'/.test(src),
    "admin: CSV marca 'Ninguno' cuando el override es []",
    "no se hallo el estado 'Ninguno'");
  assert(/puntos_acceso\.join\(/.test(src),
    'admin: CSV serializa el override con sus puntos (join)',
    'no se hallo puntos_acceso.join');
}

/* (g) scanner: regla hasOwn por presencia de clave. */
function checkScanner(src) {
  if (src === null) { assert(false, 'scanner.html existe y es legible', 'archivo ausente'); return; }
  assert(/hasOwn\s*=\s*Array\.isArray\(data\.puntos_acceso\)/.test(src),
    'scanner: hasOwn = Array.isArray(data.puntos_acceso) (NULL hereda; [] = ninguno)',
    'no se hallo la regla hasOwn');
  assert(src.indexOf('allowed.includes(puntoAcceso)') !== -1,
    'scanner: valida el punto con allowed.includes(puntoAcceso)',
    'no se hallo allowed.includes(puntoAcceso)');
}

function main() {
  var admin = readText(ADMIN);
  var scanner = readText(SCANNER);
  var migracion = readText(MIGRACION);

  log('smoke_puntos_adr081 - semantica NULL-vs-vacio + propagacion (ADR-081)');
  log('Analisis estatico, data local, sin red.');
  log('');

  checkMigracion(migracion);
  checkMigracionAscii(migracion);
  checkInvocacion(admin);
  checkPropagacion(admin);
  checkUiPuntos(admin);
  checkCsv(admin);
  checkScanner(scanner);

  log('');
  log('Resumen: PASS ' + passCount + ', FAIL ' + failCount);
  process.exit(failCount === 0 ? 0 : 1);
}

main();
