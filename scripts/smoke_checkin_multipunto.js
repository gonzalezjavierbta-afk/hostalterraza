'use strict';

/*
 * smoke_checkin_multipunto.js - Smoke del check-in multi-punto con override
 * por ticket (ADR-079).
 *
 * Verificacion ESTATICA (analisis de texto) del cableado de la feature en los
 * archivos reales del repo. No usa red, no escribe nada y no modifica archivos.
 * Sigue el contrato de salida de scripts/smoke_qa_asserts.js:
 *   lineas "PASS [n] ..." / "FAIL [n] ..." y cierre "Resumen: PASS N, FAIL M".
 *
 * Cubre:
 *   1. scanner.html: precedencia override -> evento y rechazo por punto.
 *   2. scanner.html: logs insertan evento_id / inscrito_id (confirm + deny).
 *   3. scanner.html: cargarCache filtra logs por .eq('evento_id', eventoId).
 *   4. admin.html: persistencia del override y editor openPuntosInscrito.
 *   5. admin.html: logs con evento_id / inscrito_id (manual + confirm + deny).
 *   6. migrations/adr079_multi_punto_override.sql: columna jsonb, 2 FK con
 *      ON DELETE SET NULL y backfill por nombre unico.
 *   7. migracion 100% ASCII y terminacion LF.
 *
 * Uso:   node scripts/smoke_checkin_multipunto.js
 * Exit:  0 = todo PASS ; 1 = algun FAIL
 */

var fs = require('fs');
var path = require('path');

var ROOT = path.join(__dirname, '..');
var SCANNER = path.join(ROOT, 'scanner.html');
var ADMIN = path.join(ROOT, 'admin.html');
var MIGRACION = path.join(ROOT, 'migrations', 'adr079_multi_punto_override.sql');

var passCount = 0;
var failCount = 0;
var assertNum = 0;

function log(msg) {
  process.stdout.write(String(msg) + '\n');
}

/* Registra un assert. ok=true suma PASS, ok=false suma FAIL + motivo. */
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

/* Lee un archivo. Devuelve null si no existe o no se puede leer (no crashea). */
function readText(abs) {
  try {
    if (!fs.existsSync(abs)) return null;
    return fs.readFileSync(abs, 'utf8');
  } catch (err) {
    return null;
  }
}

function countNeedle(text, needle) {
  var n = 0;
  var i = 0;
  while ((i = text.indexOf(needle, i)) !== -1) {
    n += 1;
    i += needle.length;
  }
  return n;
}

function countRe(text, re) {
  var m = text.match(re);
  return m ? m.length : 0;
}

/* Region aproximada de una funcion: desde su cabecera, N caracteres. */
function regionDesde(text, marcador, largo) {
  var i = text.indexOf(marcador);
  if (i === -1) return null;
  return text.slice(i, i + largo);
}

/* (a) scanner.html: precedencia override -> evento. */
function checkPrecedencia(src) {
  if (src === null) {
    assert(false, 'scanner.html existe y es legible', 'archivo ausente');
    return;
  }
  assert(true, 'scanner.html existe y es legible');
  assert(src.indexOf('data.puntos_acceso') !== -1,
    'scanner: lee el override del ticket (data.puntos_acceso)',
    'no se hallo "data.puntos_acceso"');
  assert(src.indexOf('window._evData?.puntos_acceso') !== -1,
    'scanner: lee la lista base del evento (window._evData?.puntos_acceso)',
    'no se hallo "window._evData?.puntos_acceso"');
  assert(src.indexOf('allowed.includes(puntoAcceso)') !== -1,
    'scanner: el punto del token se valida con allowed.includes(puntoAcceso)',
    'no se hallo "allowed.includes(puntoAcceso)"');
  assert(/Array\.isArray\(data\.puntos_acceso\)/.test(src),
    'scanner: distingue el override explicito con Array.isArray(data.puntos_acceso)',
    'no se hallo "Array.isArray(data.puntos_acceso)"');
  assert(/hasOwn\s*=\s*Array\.isArray\(data\.puntos_acceso\)/.test(src),
    'scanner: semantica nueva via hasOwn (NULL/undefined hereda; [] = ninguno)',
    'no se hallo "hasOwn = Array.isArray(data.puntos_acceso)"');
  // A2: token GENERAL (punto_acceso null) en evento MULTI-punto con data.used=true
  // debe caer en la rama de USO UNICO. Antes ambas ramas exigian
  // "esMultiUso && puntoAcceso", asi que el token general se saltaba las dos
  // y dejaba pasar a cualquiera sin registrar dedup por punto (bug C6).
  var iA2 = src.indexOf('if (esPuntoEspecifico) {');
  var iB2 = src.indexOf('pendingVerify = data;');
  var regVal = (iA2 !== -1 && iB2 !== -1 && iB2 > iA2) ? src.slice(iA2, iB2) : '';
  assert(regVal !== '' && regVal.indexOf('} else if (data.used) {') !== -1
    && regVal.indexOf('esMultiUso && puntoAcceso') === -1,
    'scanner: token general cae en "else if (data.used)" (uso unico); no queda el gate "esMultiUso && puntoAcceso"',
    'la region de validacion no tiene el orden esPuntoEspecifico -> else if (data.used), o conserva el gate legacy');
}

/* (b) scanner.html: logs con evento_id / inscrito_id. */
function checkLogsScanner(src) {
  if (src === null) {
    assert(false, 'scanner: logs insertan evento_id/inscrito_id', 'archivo ausente');
    return;
  }
  var nEvento = countNeedle(src, 'evento_id: ins.evento_id || eventoId || null');
  var nInscrito = countNeedle(src, 'inscrito_id: ins.id || null');
  assert(nEvento >= 3,
    'scanner: 3+ inserts de logs con evento_id (2 confirmEntry + 1 denyEntry)',
    'ocurrencias=' + nEvento);
  assert(nInscrito >= 3,
    'scanner: 3+ inserts de logs con inscrito_id (2 confirmEntry + 1 denyEntry)',
    'ocurrencias=' + nInscrito);
  var deny = src.split(/\r?\n/).filter(function (l) { return l.indexOf('Denegado') !== -1; });
  var denyOk = deny.length > 0 && deny.some(function (l) {
    return l.indexOf('evento_id: ins.evento_id || eventoId || null') !== -1 &&
      l.indexOf('inscrito_id: ins.id || null') !== -1;
  });
  assert(denyOk,
    'scanner: el insert Denegado (denyEntry) lleva evento_id e inscrito_id',
    'linea Denegado sin ambas columnas');
}

/* (c) scanner.html: cargarCache filtra logs por evento_id. */
function checkCargarCache(src) {
  if (src === null) {
    assert(false, 'scanner: cargarCache filtra por evento_id', 'archivo ausente');
    return;
  }
  var region = regionDesde(src, 'function cargarCache', 1200);
  if (region === null) {
    assert(false, 'scanner: cargarCache existe', 'no se hallo function cargarCache');
    return;
  }
  assert(true, 'scanner: cargarCache existe');
  assert(region.indexOf(".eq('evento_id', eventoId)") !== -1,
    'scanner: la query de logs de cargarCache usa .eq(evento_id, eventoId)',
    'no se hallo .eq(evento_id, eventoId) en cargarCache');
  assert(region.indexOf(".eq('evento', eventoId)") === -1,
    'scanner: cargarCache NO usa .eq(evento, eventoId) (columna inexistente)',
    'se hallo .eq(evento, eventoId) en cargarCache');
  assert(region.indexOf('logsCache') !== -1,
    'scanner: cargarCache puebla logsCache con el resultado de logs',
    'no se hallo logsCache en cargarCache');
}

/* (d) admin.html: persistencia del override + editor openPuntosInscrito. */
function checkAdminOverride(src) {
  if (src === null) {
    assert(false, 'admin: override persistido en registro', 'archivo ausente');
    return;
  }
  assert(src.indexOf('puntos_acceso:_getAsPuntos()') !== -1,
    'admin: el registro persiste el override con puntos_acceso:_getAsPuntos()',
    'no se hallo "puntos_acceso:_getAsPuntos()"');
  assert(src.indexOf('function openPuntosInscrito') !== -1,
    'admin: existe la definicion openPuntosInscrito (editor por inscrito)',
    'no se hallo "function openPuntosInscrito"');
  assert(countNeedle(src, 'openPuntosInscrito(') >= 2,
    'admin: openPuntosInscrito se invoca desde un boton (def + call site)',
    'ocurrencias=' + countNeedle(src, 'openPuntosInscrito('));
  assert(/function\s+_getAsPuntos\s*\(/.test(src),
    'admin: existe _getAsPuntos() (lector de filas de puntos)',
    'no se hallo function _getAsPuntos');
}

/* (e) admin.html: logs con evento_id / inscrito_id (manual + confirm + deny). */
function checkLogsAdmin(src) {
  if (src === null) {
    assert(false, 'admin: logs insertan evento_id/inscrito_id', 'archivo ausente');
    return;
  }
  assert(countRe(src, /evento_id\s*:\s*ins\.evento_id\s*\|\|\s*null/g) >= 2,
    'admin: checkinManual/confirmar y rechazar escriben evento_id:ins.evento_id||null',
    'ocurrencias=' + countRe(src, /evento_id\s*:\s*ins\.evento_id\s*\|\|\s*null/g));
  assert(countRe(src, /inscrito_id\s*:\s*ins\.id\s*\|\|\s*null/g) >= 2,
    'admin: checkinManual/confirmar y rechazar escriben inscrito_id:ins.id||null',
    'ocurrencias=' + countRe(src, /inscrito_id\s*:\s*ins\.id\s*\|\|\s*null/g));
  assert(countRe(src, /evento_id\s*:\s*eventoId\s*\|\|\s*null/g) >= 1 &&
    countRe(src, /inscrito_id\s*:\s*id\s*\|\|\s*null/g) >= 1,
    'admin: el checkin manual escribe evento_id:eventoId||null e inscrito_id:id||null',
    'falta el par del ingreso manual');
}

/* (f) migracion: columna, 2 FK con ON DELETE SET NULL y backfill unico. */
function checkMigracion(src) {
  if (src === null) {
    assert(false, 'migracion adr079 existe y es legible', 'archivo ausente');
    return;
  }
  assert(true, 'migracion adr079 existe y es legible');
  assert(src.indexOf('ADD COLUMN IF NOT EXISTS puntos_acceso jsonb') !== -1,
    'migracion: ADD COLUMN IF NOT EXISTS puntos_acceso jsonb',
    'no se hallo la columna jsonb');
  assert(src.indexOf('logs_evento_id_fkey') !== -1,
    'migracion: FK logs_evento_id_fkey',
    'no se hallo logs_evento_id_fkey');
  assert(src.indexOf('logs_inscrito_id_fkey') !== -1,
    'migracion: FK logs_inscrito_id_fkey',
    'no se hallo logs_inscrito_id_fkey');
  assert(countNeedle(src, 'ON DELETE SET NULL') >= 2,
    'migracion: las 2 FK usan ON DELETE SET NULL',
    'ocurrencias=' + countNeedle(src, 'ON DELETE SET NULL'));
  assert(src.indexOf('count(*) FROM public.eventos e2 WHERE e2.nombre = e.nombre') !== -1 &&
    /e2\.nombre\s*=\s*e\.nombre\)\s*=\s*1/.test(src),
    'migracion: backfill por nombre unico (count(*) = 1, no ambiguo)',
    'no se hallo el subquery de unicidad por nombre');
}

/* (g) migracion 100% ASCII y terminacion LF. */
function checkMigracionAscii(src) {
  if (src === null) {
    assert(false, 'migracion es ASCII puro', 'archivo ausente');
    assert(false, 'migracion termina en newline LF', 'archivo ausente');
    return;
  }
  var high = 0;
  var firstLine = -1;
  var line = 1;
  for (var i = 0; i < src.length; i += 1) {
    var code = src.charCodeAt(i);
    if (code === 10) {
      line += 1;
    } else if (code > 127) {
      high += 1;
      if (firstLine === -1) firstLine = line;
    }
  }
  assert(high === 0,
    'migracion: 100% ASCII (0 bytes > 127)',
    'bytes>127=' + high + ' (primera linea ' + firstLine + ')');
  var terminaLf = src.length > 0 && src.charAt(src.length - 1) === '\n' &&
    src.charAt(src.length - 2) !== '\r';
  assert(terminaLf,
    'migracion: termina en newline LF (no CRLF)',
    'ultimos bytes no son LF');
}

/* (b) scanner.html: bypass DELIBERADO del ingreso manual por cedula.
 * Decision de negocio tomada el 2026-10-10: el portero de un token de PUNTO
 * PUEDE admitir manualmente a alguien que no tiene ese punto.
 * Motivo: salida de emergencia ante error de captura; alguien sin el punto
 * marcado no debe quedar trabado en la puerta. NO "arreglar" esto sin
 * decision de negocio explicita: es una excepcion, no un bug.
 */
function checkBypassManualIntencional(src) {
  if (src === null) {
    assert(false, 'scanner.html existe y es legible (bypass manual deliberado)', 'archivo ausente');
    return;
  }
  var iA3 = src.indexOf('async function checkinManual');
  var iB3 = src.indexOf('pendingVerify = data;');
  var reg = (iA3 !== -1 && iB3 !== -1 && iB3 > iA3) ? src.slice(iA3, iB3) : '';
  assert(reg !== '' && reg.indexOf('_autorizado') === -1,
    'scanner: bypass DELIBERADO - checkinManual/confirmarCheckinManual NO filtran por _autorizado (salida de emergencia)',
    'alguien metio un filtro por _autorizado en el ingreso manual: requiere decision de negocio explicita');
}


function main() {
  var scanner = readText(SCANNER);
  var admin = readText(ADMIN);
  var migracion = readText(MIGRACION);

  log('smoke_checkin_multipunto - check-in multi-punto con override (ADR-079)');
  log('Analisis estatico, data local, sin red.');
  log('');

  checkPrecedencia(scanner);
  checkBypassManualIntencional(scanner);
  checkLogsScanner(scanner);
  checkCargarCache(scanner);
  checkAdminOverride(admin);
  checkLogsAdmin(admin);
  checkMigracion(migracion);
  checkMigracionAscii(migracion);

  log('');
  log('Resumen: PASS ' + passCount + ', FAIL ' + failCount);
  process.exit(failCount === 0 ? 0 : 1);
}

main();
