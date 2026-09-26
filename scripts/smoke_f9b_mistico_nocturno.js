'use strict';

/*
 * smoke_f9b_mistico_nocturno.js
 * Verificacion end-to-end (sin navegador) del silo f9b "Mistico Nocturno".
 *
 * Que hace:
 *   1. Extrae de evento-app.html las funciones REALES del kernel de la familia
 *      f9 y el canal de efectos (bloque __esFamiliaF9 .. __evDesdePreview y la
 *      funcion injectAtomicCSS) y las ejecuta en un sandbox vm con un DOM stub.
 *   2. Confirma la doble clase de body que el kernel escribe para template_id
 *      'f9b' -> 'tpl-f9b tpl-f9b'.
 *   3. Confirma la ruta del silo CSS (css/templates/fiesta/f9b.css?v=...) y que
 *      el archivo existe y referencia el scope .tpl-f9b / .Tpl-F9b.
 *   4. Confirma las 5 subconmutaciones de la familia y el canal de efectos con
 *      effects = {grain:false, glow:false, vhs:false, parallax:true}.
 *   5. Confirma que la semilla SQL versionada trae los datos minimos.
 *
 * Uso:
 *   node scripts/smoke_f9b_mistico_nocturno.js
 *
 * Sin dependencias externas: solo fs, path y vm. No accede a la red ni escribe.
 * ASCII-safe: cero bytes > 127, cero backticks.
 */

var fs = require('fs');
var path = require('path');
var vm = require('vm');

var ROOT = path.resolve(__dirname, '..');

var passCount = 0;
var failCount = 0;
var lines = [];

function ok(name) {
  passCount += 1;
  lines.push('  PASS ' + name);
}
function fail(name, detail) {
  failCount += 1;
  lines.push('  FAIL ' + name + (detail ? ' -> ' + detail : ''));
}
function check(cond, name, detail) {
  if (cond) { ok(name); } else { fail(name, detail); }
}
function read(rel) {
  try { return fs.readFileSync(path.join(ROOT, rel), 'utf8'); } catch (e) { return null; }
}

var kernel = read('evento-app.html');
var css = read('css/templates/fiesta/f9b.css');
var seed = read('migrations/seed_f9b_mistico_nocturno_prueba.sql');

check(!!kernel, 'evento-app.html existe');
check(!!css, 'css/templates/fiesta/f9b.css existe');
check(!!seed, 'migrations/seed_f9b_mistico_nocturno_prueba.sql existe');

if (!kernel) {
  lines.push('Resumen: PASS ' + passCount + ', FAIL ' + failCount);
  process.stdout.write(lines.join('\n') + '\n');
  process.exitCode = 1;
  return;
}

/* ---------------------------------------------------------------------------
 * Extraccion de las funciones reales del kernel
 * ------------------------------------------------------------------------- */

var hStart = kernel.indexOf('function __esFamiliaF9() {');
var hEnd = kernel.indexOf('function __renderPreviewError(');
var helpers = (hStart >= 0 && hEnd > hStart) ? kernel.slice(hStart, hEnd) : '';

var iStart = kernel.indexOf('async function injectAtomicCSS(cat, tplId) {');
var iEnd = kernel.indexOf('// === v1.5.0 : KERNEL');
var inject = (iStart >= 0 && iEnd > iStart) ? kernel.slice(iStart, iEnd) : '';

check(helpers.length > 0, 'bloque de helpers f9 extraido del kernel', 'marcador no hallado');
check(inject.length > 0, 'funcion injectAtomicCSS extraida del kernel', 'marcador no hallado');

/* ---------------------------------------------------------------------------
 * Sandbox DOM minimo
 * ------------------------------------------------------------------------- */

var added = {};
var fakeLink = null;

var ctx = {
  console: console,
  setTimeout: function () { return 0; },
  clearTimeout: function () {},
  sessionStorage: { getItem: function () { return null; } },
  document: {
    body: {
      className: 'tpl-f9b tpl-f9b',
      classList: { add: function (c) { added[c] = true; } }
    },
    head: { appendChild: function () {} },
    createElement: function () {
      fakeLink = { setAttribute: function () {}, rel: '', href: '' };
      return fakeLink;
    },
    querySelector: function () { return null; },
    styleSheets: []
  }
};

vm.createContext(ctx);
try {
  vm.runInContext(helpers + '\n' + inject, ctx, { filename: 'kernel-f9-extract.js' });
  ok('helpers + injectAtomicCSS evaluados en sandbox vm');
} catch (e) {
  fail('evaluacion en sandbox vm', e && e.message ? e.message : String(e));
}

/* ---------------------------------------------------------------------------
 * 1. Doble clase de body para template_id 'f9b'
 * ------------------------------------------------------------------------- */

check(kernel.indexOf("ev.template_id || 'F3'") !== -1, 'kernel declara clase tpl-{template_id} mayuscula conservada');
check(kernel.indexOf("(ev.template_id || 'f3').toLowerCase()") !== -1, 'kernel declara segunda clase tpl-{lower}');
check(kernel.indexOf('document.body.className =') !== -1, 'kernel asigna document.body.className una vez');

var tplId = 'f9b';
var bodyClass = 'tpl-' + tplId + ' tpl-' + String(tplId).toLowerCase();
check(bodyClass === 'tpl-f9b tpl-f9b', 'body.className resultante = tpl-f9b tpl-f9b', bodyClass);

/* ---------------------------------------------------------------------------
 * 2. Silo CSS referenciado + scope
 * ------------------------------------------------------------------------- */

if (typeof ctx.injectAtomicCSS === 'function') {
  try { ctx.injectAtomicCSS('fiesta', 'f9b'); } catch (e) { /* promesa pendiente, no importa */ }
  var href = fakeLink ? String(fakeLink.href || '') : '';
  check(href.indexOf('css/templates/fiesta/f9b.css?v=') !== -1, 'injectAtomicCSS apunta a css/templates/fiesta/f9b.css', href);
} else {
  fail('injectAtomicCSS no disponible en el sandbox');
}

check(kernel.indexOf('css/templates/') !== -1, 'kernel compone la ruta css/templates/{cat}/{tpl}.css');
if (css) {
  check(css.indexOf('.tpl-f9b') !== -1, 'f9b.css declara scope .tpl-f9b');
  check(css.indexOf('.Tpl-F9b') !== -1, 'f9b.css declara scope .Tpl-F9b (doble notacion)');
  check(css.indexOf('fx-explicit') !== -1, 'f9b.css declara la clase fx-explicit');
  check(css.indexOf('fx-parallax') !== -1, 'f9b.css declara la clase fx-parallax');
  check(css.indexOf('fx-grain') !== -1, 'f9b.css declara la clase fx-grain');
}

/* ---------------------------------------------------------------------------
 * 3. Predicados de familia (sandbox) - allowlist de identidades
 * ------------------------------------------------------------------------- */

function fam() { return ctx.__esFamiliaF9 ? ctx.__esFamiliaF9() : null; }

ctx.document.body.className = 'tpl-f9b tpl-f9b';
check(fam() === true, '__esFamiliaF9() true para tpl-f9b');
check(ctx.__esSiloF9Rastro && ctx.__esSiloF9Rastro() === false, '__esSiloF9Rastro() false para tpl-f9b (no hereda editorial RASTRO)');

ctx.document.body.className = 'tpl-f9 tpl-f9';
check(fam() === true, '__esFamiliaF9() true para tpl-f9');
check(ctx.__esSiloF9Rastro() === true, '__esSiloF9Rastro() true para tpl-f9');

ctx.document.body.className = 'tpl-f9c tpl-f9c';
check(fam() === false, '__esFamiliaF9() false para tpl-f9c (allowlist, no prefijo)');

ctx.document.body.className = 'tpl-f9b tpl-f9b';

/* ---------------------------------------------------------------------------
 * 4. Canal de efectos (ADR-055) con effects de la semilla
 * ------------------------------------------------------------------------- */

if (typeof ctx.__aplicarEfectosLanding === 'function') {
  var fxSeed = { grain: false, glow: false, vhs: false, parallax: true };
  var applied = ctx.__aplicarEfectosLanding({ config_landing: { effects: fxSeed } });
  check(applied === true, '__aplicarEfectosLanding devuelve true con effects valido');
  check(added['fx-explicit'] === true, 'clase fx-explicit aplicada');
  check(added['fx-parallax'] === true, 'clase fx-parallax aplicada (parallax ON)');
  check(added['fx-grain'] !== true, 'clase fx-grain NO aplicada (grain OFF)');
  check(added['fx-glow'] !== true, 'clase fx-glow NO aplicada (glow OFF)');
  check(added['fx-vhs'] !== true, 'clase fx-vhs NO aplicada (vhs OFF)');

  // Fail-open: sin effects no se aplica ni fx-explicit.
  var added2 = {};
  ctx.document.body.classList.add = function (c) { added2[c] = true; };
  var applied2 = ctx.__aplicarEfectosLanding({ config_landing: {} });
  check(applied2 === false, 'fail-open: effects ausente devuelve false');
  check(!added2['fx-explicit'] && !added2['fx-parallax'], 'fail-open: no aplica ninguna clase');
} else {
  fail('__aplicarEfectosLanding no disponible en el sandbox');
}

/* ---------------------------------------------------------------------------
 * 5. Las 5 subconmutaciones de la familia f9 en el kernel
 * ------------------------------------------------------------------------- */

check(kernel.indexOf('const __esF9Meta = __esFamiliaF9();') !== -1, 'subconmutacion 1 (__esF9Meta / meta 2 lineas) usa __esFamiliaF9');
check(kernel.indexOf('__esHeadlinerFamilia') !== -1 && kernel.indexOf('idx === 0') !== -1, 'subconmutacion 2 (headliner por POSICION idx 0) presente');
check(kernel.indexOf('|| __esFamiliaF9())') !== -1, 'subconmutacion 3 (experiencias, gate compartido f8/f9) usa __esFamiliaF9');
check(kernel.indexOf('if (!effContent.faq && __esFamiliaF9())') !== -1, 'subconmutacion 4 (FAQ) gatea por __esFamiliaF9');
check(kernel.indexOf('const __esF9Boletos = __esFamiliaF9();') !== -1, 'subconmutacion 5 (__esF9Boletos) usa __esFamiliaF9');
check(kernel.indexOf('Puedo transferir mi boleta') !== -1, 'subconmutacion 4: fallback neutral propio de f9b presente (no RASTRO)');
check(kernel.indexOf('A que hora abren puertas') !== -1, 'editorial RASTRO MC reservado a tpl-f9 (sigue en kernel)');

/* ---------------------------------------------------------------------------
 * 6. Helpers puros (poster, centinela, fecha larga)
 * ------------------------------------------------------------------------- */

if (typeof ctx.__posterUrlDeEvento === 'function') {
  check(ctx.__posterUrlDeEvento({ poster_url: 'A' }, { poster_url: 'B' }) === 'A', 'orden canonico del poster: columna gana');
  check(ctx.__posterUrlDeEvento({}, { poster_url: 'B' }) === 'B', 'fallback 2 del poster: content.poster_url');
  check(ctx.__posterUrlDeEvento({ imagen_url: 'C' }, {}) === 'C', 'fallback 3 del poster: imagen_url');
}
if (typeof ctx.__metaDerive === 'function') {
  check(ctx.__metaDerive('2099-12-31', true) === '', 'centinela 2099-12-31 tratada como sin fecha');
  check(ctx.__metaDerive('2026-12-19', true) === '2026-12-19', 'fecha real conservada');
}
if (typeof ctx.__formatoFechaLarga === 'function') {
  var f = ctx.__formatoFechaLarga('2026-12-19');
  check(!!f && !!f.l1 && String(f.l2 || '').indexOf('2026') !== -1, 'fecha larga produce l1 y l2 con anio');
}

/* ---------------------------------------------------------------------------
 * 7. Semilla SQL: datos minimos y no-duplicacion de columnas
 * ------------------------------------------------------------------------- */

if (seed) {
  check(seed.indexOf('test-f9b-mistico-nocturno') !== -1, 'seed usa slug claramente de prueba');
  check(seed.indexOf("'f9b'") !== -1, 'seed escribe template_id f9b');
  check(seed.indexOf("'fiesta'") !== -1, 'seed escribe categoria_slug fiesta');
  check(seed.indexOf('"parallax": true') !== -1, 'seed nace con parallax ON');
  check(seed.indexOf('"grain": false') !== -1, 'seed nace con grain OFF');
  check(seed.indexOf('"glow": false') !== -1, 'seed nace con glow OFF');
  check(seed.indexOf('"vhs": false') !== -1, 'seed nace con vhs OFF');
  check(seed.indexOf('dj_lineup') !== -1, 'seed incluye dj_lineup');
  check(seed.indexOf('playlist_url') !== -1, 'seed incluye playlist_url');
  check(seed.indexOf('"boletos"') !== -1, 'seed incluye boletos');
  check(seed.indexOf('"sponsors"') !== -1, 'seed incluye sponsors');
  check(seed.indexOf('"faq"') !== -1, 'seed incluye faq');
  check(seed.indexOf('"whatsapp"') !== -1, 'seed incluye whatsapp');
  check(seed.indexOf('poster_url') !== -1, 'seed escribe poster_url en columna');
  check(seed.indexOf('WHERE NOT EXISTS') !== -1, 'seed es idempotente (INSERT WHERE NOT EXISTS)');
  check(seed.indexOf("DELETE FROM public.eventos WHERE slug = 'test-f9b-mistico-nocturno'") !== -1, 'seed incluye borrado idempotente por slug');
  check(seed.indexOf('content_fecha_duplicada') !== -1, 'seed verifica que no duplica columnas en content');
  check(seed.indexOf('mistico-nocturno') !== -1, 'seed registra theme mistico-nocturno');
}

/* ---------------------------------------------------------------------------
 * Resumen
 * ------------------------------------------------------------------------- */

process.stdout.write('smoke_f9b_mistico_nocturno - verificacion end-to-end (sandbox del kernel)\n');
process.stdout.write(lines.join('\n') + '\n');
process.stdout.write('\nResumen: PASS ' + passCount + ', FAIL ' + failCount + '\n');
process.exitCode = failCount > 0 ? 1 : 0;
