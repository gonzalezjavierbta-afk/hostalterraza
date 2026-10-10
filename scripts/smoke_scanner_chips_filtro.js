'use strict';

/*
 * smoke_scanner_chips_filtro.js - Smoke del FILTRADO de los chips/texto de
 * puntos en la vista GENERAL del scanner (scanner.html).
 *
 * BUG que cubre: puntosTextoGeneral y puntosChipsGeneral usaban
 * puntosEfectivos(ins) SIN filtrar, asi que un invitado con puntos_acceso = NULL
 * (hereda) veia los chips de los puntos SOLO-SELECCIONADOS del evento, que
 * deberian quedarle negados. Fix (scanner.html L741 y L749):
 *   .filter(p => tieneAccesoPunto(ins || {}, p))
 *
 * Tecnica: NO se reimplementa la logica. Se EXTRAEN por texto los bloques
 * reales de scanner.html (puntosEfectivos, puntoEsGeneral,
 * puntoEsSoloSeleccionado, tieneAccesoPunto, _evTienePuntos,
 * _puntoNombreGeneral, puntosTextoGeneral, puntosChipsGeneral y el const
 * _CHIP_PUNTO_STYLE) y se evaluan en un sandbox node:vm con los globales de
 * contexto (esPuntoEspecifico, _puntosGenerales, _puntosSoloSeleccionados,
 * window._evData, puntoAcceso, qrCache). Se prueba el codigo REAL del repo.
 *
 * Ademas aserta el literal del fix sobre el fuente, para que una reversion del
 * filtro rompa el smoke aunque la logica evaluada pasara.
 *
 * Contrato de salida (igual que smoke_puntos_adr081.js):
 *   lineas "PASS [n] ..." / "FAIL [n] ..." y cierre "Resumen: PASS N, FAIL M".
 *
 * Uso:   node scripts/smoke_scanner_chips_filtro.js
 * Exit:  0 = todo PASS ; 1 = algun FAIL
 * Sin red, no escribe nada, no modifica archivos.
 */

var fs = require('fs');
var path = require('path');
var vm = require('vm');

var ROOT = path.join(__dirname, '..');
var SCANNER = path.join(ROOT, 'scanner.html');

var passCount = 0;
var failCount = 0;
var assertNum = 0;
var falloExtraccion = '';

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

function leerTexto(abs) {
  try {
    if (!fs.existsSync(abs)) return null;
    return fs.readFileSync(abs, 'utf8');
  } catch (err) {
    return null;
  }
}

var RE_FUNC = /^(?:async\s+)?function\s+[A-Za-z_$][\w$]*\s*\(/;
var RE_DECL = /^(?:const|let|var)\s+[A-Za-z_$][\w$]*\s*=/;

/*
 * Extrae el bloque de nivel superior (columna 0) que empieza en la declaracion
 * `nombre` y termina en la siguiente declaracion de nivel superior.
 */
function extraerBloque(src, nombre, esConst) {
  var lineas = src.split(/\r?\n/);
  var re = new RegExp('^(?:async\\s+)?' + (esConst ? 'const' : 'function') +
    '\\s+' + nombre + '\\s*(?:\\(|=)');
  var ini = -1;
  for (var i = 0; i < lineas.length; i++) {
    if (re.test(lineas[i])) { ini = i; break; }
  }
  if (ini === -1) return null;
  var fin = lineas.length;
  for (var j = ini + 1; j < lineas.length; j++) {
    if (RE_FUNC.test(lineas[j]) || RE_DECL.test(lineas[j])) { fin = j; break; }
  }
  return lineas.slice(ini, fin).join('\n');
}

var BLOQUES = [
  { n: '_CHIP_PUNTO_STYLE', c: true },
  { n: 'puntosEfectivos', c: false },
  { n: 'puntoEsGeneral', c: false },
  { n: 'puntoEsSoloSeleccionado', c: false },
  { n: 'tieneAccesoPunto', c: false },
  { n: '_evTienePuntos', c: false },
  { n: '_puntoNombreGeneral', c: false },
  { n: 'puntosTextoGeneral', c: false },
  { n: 'puntosChipsGeneral', c: false }
];

/* Arma el sandbox y evalua los bloques REALES extraidos de scanner.html. */
function construirContexto(src) {
  var ctx = {
    window: { _evData: null },
    esPuntoEspecifico: false,
    _puntosGenerales: [],
    _puntosSoloSeleccionados: [],
    puntoAcceso: null,
    qrCache: {},
    console: console
  };
  var codigo = [];
  var fuente = {};
  var faltan = [];
  for (var i = 0; i < BLOQUES.length; i++) {
    var b = BLOQUES[i];
    var bloque = extraerBloque(src, b.n, b.c);
    /* Un const puede no llevar llaves; una funcion siempre lleva su cuerpo. */
    var bueno = bloque !== null &&
      (b.c ? bloque.length > 10 : bloque.indexOf('{') !== -1);
    if (!bueno) {
      faltan.push(b.n);
      continue;
    }
    fuente[b.n] = bloque;
    codigo.push(bloque);
  }
  if (faltan.length > 0) {
    falloExtraccion = 'bloques no aislados: ' + faltan.join(', ');
    return null;
  }
  try {
    vm.createContext(ctx);
    vm.runInContext(codigo.join('\n\n'), ctx, { filename: 'scanner.html (extracto)' });
  } catch (err) {
    falloExtraccion = 'error al evaluar el extracto: ' + (err && err.message);
    return null;
  }
  ctx.__fuente = fuente;
  return ctx;
}

/* Fija el contexto de un escenario. */
function escena(ctx, evPuntos, generales, soloSel) {
  ctx.esPuntoEspecifico = false;
  ctx._puntosGenerales = generales;
  ctx._puntosSoloSeleccionados = soloSel;
  ctx.window._evData = { puntos_acceso: evPuntos };
}

function correr(ctx) {
  /* C1: NULL + punto SOLO-SELECCIONADO -> no lo ve, cae en el fallback. */
  escena(ctx, ['Ancestral'], [], ['Ancestral']);
  var chips1 = ctx.puntosChipsGeneral({ puntos_acceso: null });
  var txt1 = ctx.puntosTextoGeneral({ puntos_acceso: null });
  assert(chips1.indexOf('solo seleccionados') === -1,
    'C1 NULL: el chip "(solo seleccionados)" NO se pinta', 'chips=' + chips1);
  assert(chips1.indexOf('Ancestral') === -1,
    'C1 NULL: el punto Ancestral NO aparece', 'chips=' + chips1);
  assert(chips1.indexOf('Solo entrada general') !== -1 && txt1 === 'Solo entrada general',
    'C1 NULL: cae en el fallback "Solo entrada general"',
    'chips=' + chips1 + ' texto=' + txt1);
  var chips1u = ctx.puntosChipsGeneral(undefined);
  assert(chips1u.indexOf('Ancestral') === -1 &&
    chips1u.indexOf('Solo entrada general') !== -1,
    'C1 NULL: inscribed undefined (ins || {}) tampoco lo ve', 'chips=' + chips1u);

  /* C2: array explicito con el punto SOLO-SELECCIONADO -> si lo ve. */
  escena(ctx, ['Ancestral'], [], ['Ancestral']);
  var chips2 = ctx.puntosChipsGeneral({ puntos_acceso: ['Ancestral'] });
  var txt2 = ctx.puntosTextoGeneral({ puntos_acceso: ['Ancestral'] });
  assert(chips2.indexOf('Ancestral (solo seleccionados)') !== -1,
    'C2 explicito: el chip "(solo seleccionados)" SI aparece', 'chips=' + chips2);
  assert(txt2 === 'Ancestral (solo seleccionados)',
    'C2 explicito: el texto lleva el sufijo (solo seleccionados)', 'texto=' + txt2);

  /* C3: modo GENERAL intacto con NULL. */
  escena(ctx, ['Terraza', 'Ancestral'], ['Terraza'], ['Ancestral']);
  var chips3 = ctx.puntosChipsGeneral({ puntos_acceso: null });
  assert(chips3.indexOf('Terraza (general)') !== -1,
    'C3 general: con NULL el punto general SI se ve', 'chips=' + chips3);
  assert(chips3.indexOf('Ancestral') === -1,
    'C3 general: el solo-seleccionado sigue filtrado junto al general',
    'chips=' + chips3);

  /* C4: modo HEREDA (punto en ninguna lista) -> chip pelado, sin sufijo. */
  escena(ctx, ['Bar'], [], []);
  var chips4 = ctx.puntosChipsGeneral({ puntos_acceso: null });
  var txt4 = ctx.puntosTextoGeneral({ puntos_acceso: null });
  assert(txt4 === 'Bar' && chips4.indexOf('Bar') !== -1,
    'C4 hereda: con NULL se ve igual que antes (nombre pelado)', 'texto=' + txt4);
  assert(chips4.indexOf('(general)') === -1 &&
    chips4.indexOf('(solo seleccionados)') === -1,
    'C4 hereda: sin sufijo de modo', 'chips=' + chips4);

  /* C5: token de punto (esPuntoEspecifico) -> ambas funciones vacias. */
  escena(ctx, ['Ancestral'], [], ['Ancestral']);
  ctx.esPuntoEspecifico = true;
  assert(ctx.puntosChipsGeneral({ puntos_acceso: ['Ancestral'] }) === '' &&
    ctx.puntosTextoGeneral({ puntos_acceso: ['Ancestral'] }) === '',
    'C5 esPuntoEspecifico: ambas funciones devuelven ""', 'no devolvieron ""');
  ctx.esPuntoEspecifico = false;

  /* C6: evento sin puntos definidos -> sin ruido. */
  escena(ctx, [], [], []);
  assert(ctx.puntosChipsGeneral({ puntos_acceso: null }) === '' &&
    ctx.puntosTextoGeneral({ puntos_acceso: null }) === '',
    'C6 evento sin puntos: no inventa chips ni texto', 'no devolvieron ""');

  /* C7: guarda de fuente contra la reversion literal del fix. */
  var fTexto = ctx.__fuente.puntosTextoGeneral;
  var fChips = ctx.__fuente.puntosChipsGeneral;
  assert(fTexto.indexOf('.filter(p => tieneAccesoPunto(') !== -1,
    'C7 fuente: puntosTextoGeneral contiene el filtro tieneAccesoPunto',
    'el filtro se elimino del fuente');
  assert(fChips.indexOf('.filter(p => tieneAccesoPunto(') !== -1,
    'C7 fuente: puntosChipsGeneral contiene el filtro tieneAccesoPunto',
    'el filtro se elimino del fuente');
}

function main() {
  log('smoke_scanner_chips_filtro - chips/texto de puntos en vista GENERAL');
  log('Evalua las funciones REALES de scanner.html en un sandbox node:vm.');
  log('');

  var src = leerTexto(SCANNER);
  assert(src !== null, 'scanner.html existe y es legible', 'archivo ausente');
  if (src === null) {
    log('');
    log('Resumen: PASS ' + passCount + ', FAIL ' + failCount);
    process.exit(1);
    return;
  }

  var ctx = construirContexto(src);
  assert(ctx !== null,
    'se extrajeron y evaluaron los ' + BLOQUES.length + ' bloques de scanner.html',
    falloExtraccion || 'fallo desconocido del harness');

  if (ctx !== null) {
    var tieneApi = typeof ctx.puntosChipsGeneral === 'function' &&
      typeof ctx.puntosTextoGeneral === 'function' &&
      typeof ctx.tieneAccesoPunto === 'function';
    assert(tieneApi,
      'el sandbox expone puntosChipsGeneral, puntosTextoGeneral y tieneAccesoPunto',
      'las funciones no quedaron expuestas en el contexto');
    if (tieneApi) correr(ctx);
  }

  log('');
  log('Resumen: PASS ' + passCount + ', FAIL ' + failCount);
  process.exit(failCount === 0 ? 0 : 1);
}

main();
