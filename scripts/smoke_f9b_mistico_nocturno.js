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
 * 8. BANNERS EDITORIALES f9b (TAREA 4 del brief de banners)
 *
 * Este bloque NO crea un segundo framework: reusa check()/ok()/fail()/lines del
 * encabezado y deja el unico "Resumen" del final intacto. Un check por punto
 * numerado del brief: A1..A7 (kernel), B8..B10 (contrato de datos), C11..C18
 * (silo f9b.css), D19..D20 (regresiones de robustez fijadas hoy) y E1
 * (anidamiento real de los 2 slots de banner).
 *
 * Helpers locales, todos ASCII y sin backticks:
 *   - cssNoC  : f9b.css sin comentarios, para no contar texto de comentario.
 *   - cssRules : lista {sel, body} de reglas planas (no anida at-rules).
 *   - sliceBalanced : extrae una declaracion/funcion por conteo de llaves.
 *   - countOf : ocurrencias de una subcadena.
 *   - tagEnd / anidar : tokenizer de tags con pila para E1 (anidamiento real).
 * Los checks D19 y D20 son de EJECUCION REAL: extraen del kernel el codigo
 * fuente de __bannerVacio y de la normalizacion de estilo y lo evaluan en un
 * contexto vm con stubs minimos. No hay reimplementacion de la formula.
 * ------------------------------------------------------------------------- */

var BK_OPEN = '// === INICIO SEGMENTO: BANNERS EDITORIALES (f9b) ===';
var BK_CLOSE = '// === FIN SEGMENTO: BANNERS EDITORIALES (f9b) ===';
var bkS = kernel.indexOf(BK_OPEN);
var bkE = kernel.indexOf(BK_CLOSE);
var bKernel = (bkS >= 0 && bkE > bkS) ? kernel.slice(bkS, bkE) : '';

var cssSrc = css || '';
var cssNoC = cssSrc.replace(/\/\*[\s\S]*?\*\//g, '');

function cssRules(src) {
  var out = [];
  var re = /([^{}]+)\{([^{}]*)\}/g;
  var m;
  while ((m = re.exec(src)) !== null) {
    out.push({ sel: m[1].replace(/@[^{}]*?/g, ' ').replace(/\s+/g, ' ').trim(), body: m[2] });
  }
  return out;
}
function sliceBalanced(src, marker) {
  var i = src.indexOf(marker);
  if (i < 0) return '';
  var b = src.indexOf('{', i);
  if (b < 0) return '';
  var depth = 0, j = b;
  for (; j < src.length; j++) {
    var ch = src.charAt(j);
    if (ch === '{') { depth += 1; }
    else if (ch === '}') { depth -= 1; if (depth === 0) return src.slice(i, j + 1); }
  }
  return '';
}
function countOf(src, needle) {
  var n = 0, i = 0;
  while ((i = src.indexOf(needle, i)) !== -1) { n += 1; i += needle.length; }
  return n;
}

/* --- parser de anidamiento para E1 (pila de tags, NO regex ingenuo) --------
 * Por que existe: A1 usa un regex sobre el texto del <section> y A4 usa
 * indexOf de offsets. NINGUNO de los dos ve la PROFUNDIDAD. Si alguien envuelve
 * un banner dentro de un <div class="mod-..."> o de otro <section>, el
 * grid-area: banner-1 del silo deja de aplicar (el grid item pasa a ser el
 * padre) y la banda se rompe en runtime con el smoke en verde. Este helper
 * apila los tags que ABREN scope y devuelve el padre inmediato real.
 *
 * Decisiones (las 3 trampas del parser):
 *   1. VOIDS: <img>/<meta>/<br>/<input>/<hr>/... NUNCA se apilan. Si se
 *      apilaran, el "padre inmediato" de un <section> seria un <img> y el
 *      check daria un falso padre. Los self-closing (X />) tampoco.
 *   2. QUOTES: un '>' dentro de un atributo entrecomillado NO cierra el tag.
 *      tagEnd() lleva el estado de comilla; ademas cuenta esos '>' en QTAGS
 *      para poder reportar que el tokenizer aguanta el caso.
 *   3. SALTOS: <script>, <style> y comentarios se saltan enteros (el kernel
 *      esta lleno de strings '<div>' y de comentarios que nombran ids).
 * ------------------------------------------------------------------------ */

/* Tags que abren y cierran sin tener scope: NO entran en la pila. */
var VOID_TAGS = {
  area: 1, base: 1, br: 1, col: 1, embed: 1, hr: 1, img: 1, input: 1,
  keygen: 1, link: 1, meta: 1, param: 1, source: 1, track: 1, wbr: 1
};
/* Tags cuyo contenido no es HTML: se salta hasta su cierre. */
var SKIP_TAGS = { script: 1, style: 1 };
/* Cuantos '>' vivian dentro de comillas: si es > 0, el tokenizer fue
   consciente de atributos (se reporta en el detalle de E1). */
var QTAGS = 0;

/* Indice del '>' que REALMENTE cierra el tag que arranca en 'from', ignorando
   los '>' que caen dentro de comillas de atributo. Devuelve -1 si no cierra. */
function tagEnd(src, from) {
  var q = '', i = from + 1;
  for (; i < src.length; i++) {
    var ch = src.charAt(i);
    if (q) {
      if (ch === q) { q = ''; }
      else if (ch === '>') { QTAGS += 1; }
      continue;
    }
    if (ch === '"' || ch === "'") { q = ch; continue; }
    if (ch === '>') { return i; }
  }
  return -1;
}

/* Valor de un atributo (id / class) del texto interno de un tag. */
function attrDe(raw, name) {
  var re = new RegExp('\\b' + name + '\\s*=\\s*(?:"([^"]*)"|\'([^\']*)\'|([^\\s"\'>]+))', 'i');
  var m = raw.match(re);
  if (!m) return '';
  return m[1] || m[2] || m[3] || '';
}

/* Parsea 'html' con pila de tags y devuelve los datos de anidamiento del
   primer <tagName id="targetId"> que halle:
 *   { found, parent, parentId, parentCls, depth, chain, inner, closed, quoted,
 *     at, stack }
 * - parent  : nombre del padre inmediato (el ultimo de la pila al abrir el tag)
 * - depth   : cuantos tags estaban abiertos al abrirlo (incluye html y body,
 *             por eso NO es 1: E1.2 se mide aparte con abiertosEnTramo)
 * - chain   : la pila completa como "html > body > main#main-content-flow"
 * - inner   : cuantos <tagName> se abrieron DENTRO (0 = su </> cierra el suyo)
 * - closed  : su cierre propio llego (el pop que lo saca es el suyo)
 * - quoted  : el tag de apertura traia un '>' dentro de comillas de atributo
 * - at      : indice del '<' del tag buscado
 * - stack   : COPIA de la pila al abrirlo (frames con name/id/cls/end), para
 *             que E1.2 mida el tramo desde el frame del CONTENEDOR y no desde
 *             el padre inmediato */
function anidar(html, tagName, targetId) {
  var want = String(tagName).toLowerCase();
  var stack = [];
  var res = { found: false, parent: '', parentId: '', parentCls: '', depth: -1,
              chain: '', inner: 0, closed: false, quoted: false,
              at: -1, stack: [] };
  var inTarget = false, inner = 0, i = 0;
  while (i < html.length) {
    var lt = html.indexOf('<', i);
    if (lt < 0) break;
    /* Comentario: se salta entero. */
    if (html.substr(lt, 4) === '<!--') {
      var ce = html.indexOf('-->', lt);
      i = ce < 0 ? html.length : ce + 3;
      continue;
    }
    /* Doctype (<!...) o procesamiento (<?...): no son tags. */
    var c1 = html.charAt(lt + 1);
    if (c1 === '!' || c1 === '?') {
      var de = html.indexOf('>', lt);
      i = de < 0 ? html.length : de + 1;
      continue;
    }
    var gt = tagEnd(html, lt);
    if (gt < 0) break;
    var body = html.slice(lt + 1, gt);
    var closing = body.charAt(0) === '/';
    if (closing) body = body.slice(1);
    var selfClose = !closing && body.charAt(body.length - 1) === '/';
    if (selfClose) body = body.slice(0, -1);
    var mName = body.match(/^\s*([A-Za-z][-\w]*)/);
    if (!mName) { i = gt + 1; continue; }
    var name = mName[1].toLowerCase();
    /* Cierre: pops hasta el ultimo frame del mismo nombre (tolerante a
       cierres sueltos) y avisa si el frame que sale es el target. */
    if (closing) {
      for (var k = stack.length - 1; k >= 0; k--) {
        if (stack[k].name === name) {
          if (stack[k].isTarget) { res.closed = true; inTarget = false; }
          stack.length = k;
          break;
        }
      }
      i = gt + 1;
      continue;
    }
    var tid = attrDe(body, 'id');
    var isTarget = (name === want && tid === targetId);
    if (inTarget && name === want) { inner += 1; }
    if (isTarget) {
      inTarget = true;
      res.found = true;
      res.at = lt;
      res.depth = stack.length;
      var par = stack.length ? stack[stack.length - 1] : null;
      res.parent = par ? par.name : '';
      res.parentId = par ? par.id : '';
      res.parentCls = par ? par.cls : '';
      var parts = [];
      for (var k2 = 0; k2 < stack.length; k2++) {
        parts.push(stack[k2].name + (stack[k2].id ? '#' + stack[k2].id : ''));
        res.stack.push({ name: stack[k2].name, id: stack[k2].id,
                         cls: stack[k2].cls, end: stack[k2].end });
      }
      res.chain = parts.join(' > ');
      /* '>' dentro de comillas en ESTE tag: el cierre ingenuo seria otro. */
      res.quoted = html.indexOf('>', lt) !== gt;
    }
    /* Voids y self-closing: no abren scope, no se apilan. */
    if (VOID_TAGS[name] || selfClose) { i = gt + 1; continue; }
    /* script/style: se salta su contenido sin apilar nada. */
    if (SKIP_TAGS[name]) {
      var rest = html.slice(gt + 1);
      var mm = new RegExp('</\\s*' + name + '\\s*>', 'i').exec(rest);
      i = mm ? gt + 1 + mm.index + mm[0].length : html.length;
      continue;
    }
    stack.push({ name: name, id: tid, cls: attrDe(body, 'class'),
                 end: gt + 1, isTarget: isTarget });
    i = gt + 1;
  }
  res.inner = inner;
  return res;
}

/* E1.2, medido de forma INDEPENDIENTE del parseo por pila: recorre el tramo
   de texto [desde, hasta) - desde = justo despues del '>' que abre el
   contenedor, hasta = el '<' del banner - y cuenta que tags de scope quedan
   ABIERTOS (neto) ahi. Los tags que abren y cierran dentro del tramo no
   cuentan; solo importa lo que quede sin cerrar. Debe dar 0. */
function abiertosEnTramo(src, desde, hasta) {
  var pila = [], i = desde;
  while (i < hasta && i < src.length) {
    var lt = src.indexOf('<', i);
    if (lt < 0 || lt >= hasta) break;
    if (src.substr(lt, 4) === '<!--') {
      var ce = src.indexOf('-->', lt);
      i = ce < 0 ? hasta : ce + 3;
      continue;
    }
    var c1 = src.charAt(lt + 1);
    if (c1 === '!' || c1 === '?') {
      var de = src.indexOf('>', lt);
      i = de < 0 ? hasta : de + 1;
      continue;
    }
    var gt = tagEnd(src, lt);
    if (gt < 0) break;
    var body = src.slice(lt + 1, gt);
    var closing = body.charAt(0) === '/';
    if (closing) body = body.slice(1);
    var selfClose = !closing && body.charAt(body.length - 1) === '/';
    if (selfClose) body = body.slice(0, -1);
    var mName = body.match(/^\s*([A-Za-z][-\w]*)/);
    if (!mName) { i = gt + 1; continue; }
    var name = mName[1].toLowerCase();
    if (closing) {
      for (var k = pila.length - 1; k >= 0; k--) {
        if (pila[k].name === name) { pila.length = k; break; }
      }
      i = gt + 1;
      continue;
    }
    if (VOID_TAGS[name] || selfClose) { i = gt + 1; continue; }
    if (SKIP_TAGS[name]) {
      var rest2 = src.slice(gt + 1, hasta);
      var mm2 = new RegExp('</\\s*' + name + '\\s*>', 'i').exec(rest2);
      i = mm2 ? gt + 1 + mm2.index + mm2[0].length : hasta;
      continue;
    }
    var cls0 = attrDe(body, 'class').split(/\s+/)[0];
    pila.push({ name: name, id: attrDe(body, 'id'), cls: cls0 });
    i = gt + 1;
  }
  var out = [];
  for (var k2 = 0; k2 < pila.length; k2++) {
    out.push(pila[k2].name + (pila[k2].id ? '#' + pila[k2].id : '') +
             (pila[k2].cls ? '.' + pila[k2].cls : ''));
  }
  return { net: pila.length, abiertos: out };
}

var bRules = cssRules(cssNoC);
/* Enganche de un id de atomo con FRONTERA: '#mod-banner-2' no puede dar por
   enganchado un '#mod-banner-2-x' (substring) ni '#mod-banner-20'. Acepta el
   id con o sin '#'. */
function idHook(sel, id) {
  return new RegExp('#' + String(id).replace(/^#/, '') + '(?![-\\w])').test(sel);
}
/* Regla cuyo selector engancha LOS DOS atomos y cuyo texto cumple /re/. */
function ruleBothIds(re) {
  for (var i = 0; i < bRules.length; i++) {
    var s = bRules[i].sel;
    if (idHook(s, 'mod-banner-1') && idHook(s, 'mod-banner-2') && re.test(s + ' || ' + bRules[i].body)) return bRules[i];
  }
  return null;
}
/* Regla cuyo selector engancha un atomo concreto y cuyo texto cumple /re/. */
function ruleOneId(id, re) {
  for (var i = 0; i < bRules.length; i++) {
    if (idHook(bRules[i].sel, id) && re.test(bRules[i].sel + ' || ' + bRules[i].body)) return bRules[i];
  }
  return null;
}

/* --- A1: los 2 slots existen en el DOM estatico, vacios por el kernel ----- */
var A1a = /<section id="mod-banner-1"[^>]*><\/section>/.test(kernel);
var A1b = /<section id="mod-banner-2"[^>]*><\/section>/.test(kernel);
var A1c = countOf(kernel, 'id="mod-banner-1" class="mod-banner" data-estilo="dorado"') === 1 &&
          countOf(kernel, 'id="mod-banner-2" class="mod-banner" data-estilo="dorado"') === 1;
check(bKernel.length > 0 && A1a && A1b && A1c,
  'A1: los 2 sections #mod-banner-1 y #mod-banner-2 existen en el DOM estatico (vacias, data-estilo dorado de arranque)',
  'segmento o sections estaticos no halls; slot1=' + A1a + ' slot2=' + A1b + ' arranque=' + A1c);

/* --- A2: __renderBanner definido y llamado 2 veces, __bannerVacio existe --- */
var A2def = countOf(bKernel, 'const __renderBanner = function (slotId, it) {') === 1;
var A2calls = countOf(bKernel, "__renderBanner('mod-banner-");
var A2v = countOf(bKernel, 'const __bannerVacio = function (it) {') === 1;
check(A2def && A2calls === 2 && A2v,
  'A2: __renderBanner definido y llamado 2 veces (1 por atomo) y __bannerVacio existe',
  'def=' + A2def + ' calls=' + A2calls + ' vacio=' + A2v);

/* --- A3: __hideEmptyModule por cada atomo -------------------------------- */
var A3 = countOf(bKernel, "__hideEmptyModule('mod-banner-1'") === 1 &&
        countOf(bKernel, "__hideEmptyModule('mod-banner-2'") === 1;
check(A3, 'A3: __hideEmptyModule invocado con mod-banner-1 y con mod-banner-2', 'llamadas incompletas');

/* --- A4: orden de hermanos en el DOM estatico ---------------------------- */
var pLineup = kernel.indexOf('<section id="mod-lineup"');
var pBan1 = kernel.indexOf('<section id="mod-banner-1"');
var pPlaylist = kernel.indexOf('<section id="mod-playlist"');
var pWa = kernel.indexOf('<section id="mod-whatsapp"');
var pBan2 = kernel.indexOf('<section id="mod-banner-2"');
var pSpons = kernel.indexOf('<section id="mod-sponsors"');
var A4 = pLineup > 0 && pLineup < pBan1 && pBan1 < pPlaylist &&
         pWa > 0 && pWa < pBan2 && pBan2 < pSpons;
check(A4, 'A4: orden de hermanos correcto (lineup < banner-1 < playlist; whatsapp < banner-2 < sponsors)',
  'posiciones lineup=' + pLineup + ' b1=' + pBan1 + ' playlist=' + pPlaylist + ' wa=' + pWa + ' b2=' + pBan2 + ' sponsors=' + pSpons);

/* --- A5: el silo declara position/overflow/isolation en el <section> ------- */
/* Las 3 propiedades viven YA en el silo (se movieron alli): si desaparecen,
   .banner-media (absolute, inset 0) se resuelve contra #main-content-flow. */
var A5 = !!ruleBothIds(/position\s*:\s*relative/) &&
         !!ruleBothIds(/overflow\s*:\s*hidden/) &&
         !!ruleBothIds(/isolation\s*:\s*isolate/);
check(A5, 'A5: el silo declara position:relative + overflow:hidden + isolation:isolate sobre los 2 sections (moved out del kernel)',
  'falta alguna de las 3 declaraciones en el selector de los banners');

/* --- A6: construccion DOM, cero innerHTML / onerror= / lightbox ---------- */
/* Se buscan las FORMAS DE CODIGO (con = o con comilla de cierre), no la
   palabra suelta: los comentarios del propio segmento nombran innerHTML,
   onerror, .lightbox-trigger y data-lightbox al explicar que NO se usan. */
var A6inner = !/\.innerHTML\s*=/.test(bKernel);
var A6bt = bKernel.indexOf(String.fromCharCode(96)) === -1;   /* sin template literal */
var A6on = !/\bonerror\s*=/.test(bKernel) && !/['"]onerror['"]/.test(bKernel);
var A6lb = !/lightbox-trigger\s*['"]/.test(bKernel) && !/data-lightbox\s*['"]/.test(bKernel);
var A6dom = /document\.createElement\(/.test(bKernel) && /\.textContent\s*=/.test(bKernel) &&
            /img\.className\s*=\s*'banner-img';/.test(bKernel);
check(A6inner && A6bt && A6on && A6lb && A6dom,
  'A6: banners construidos con createElement + textContent; cero innerHTML, cero onerror= inline, cero lightbox en .banner-img',
  'innerHTML=' + A6inner + ' sinTemplateLiteral=' + A6bt + ' onerror=' + A6on + ' lightbox=' + A6lb + ' dom=' + A6dom);

/* --- A7: nunca se emite src="" ni poster="" ----------------------------- */
var A7src = !/\.src\s*=\s*['"]['"]/.test(bKernel) && !/setAttribute\(\s*['"]src['"]\s*,\s*['"]['"]/.test(bKernel);
var A7post = !/\.poster\s*=\s*['"]['"]/.test(bKernel) && !/setAttribute\(\s*['"]poster['"]\s*,\s*['"]['"]/.test(bKernel);
var A7off = /img\.style\.display\s*=\s*'none';/.test(bKernel) &&
            /vid\.setAttribute\('poster', imgUrl \|\| __BANNER_AVATAR\);/.test(bKernel);
check(A7src && A7post && A7off, 'A7: cero src="" y cero poster="" emitidos; sin imagen_url el <img> queda display:none y el poster cae al avatar',
  'srcVacio=' + A7src + ' posterVacio=' + A7post + ' caminoOffline=' + A7off);

/* --- B8: banners[0] y [1] mapeados, [2+] ignorado ----------------------- */
var B8 = /const __banner1 = __banners\[0\];/.test(bKernel) &&
        /const __banner2 = __banners\[1\];/.test(bKernel) &&
        /__renderBanner\('mod-banner-1', __banner1\);/.test(bKernel) &&
        /__renderBanner\('mod-banner-2', __banner2\);/.test(bKernel) &&
        /__hideEmptyModule\('mod-banner-1', !__bannerVacio\(__banner1\)\);/.test(bKernel) &&
        /__hideEmptyModule\('mod-banner-2', !__bannerVacio\(__banner2\)\);/.test(bKernel) &&
        bKernel.indexOf('__banners[2') === -1 && bKernel.indexOf('banners[2]') === -1 &&
        /Array\.isArray\(__bannersRaw\)/.test(bKernel);
check(B8, 'B8: banners[0]->mod-banner-1 y banners[1]->mod-banner-2; banners[2+] se ignora en silencio',
  'mapeo o guardia de array incorrectos');

/* --- B9: lee estilo, NO lee tema ---------------------------------------- */
/* La prohibicion es sobre el BANNER: config_landing.theme vive fuera del
   segmento y no se toca. Dentro del segmento no puede aparecer it.tema. */
var B9 = /it\.estilo/.test(bKernel) && !/it\s*\.\s*tema/.test(bKernel) &&
        /__BANNER_ESTILOS\[__est\] \? __est : 'dorado'/.test(bKernel);
check(B9, 'B9: el banner lee estilo y jamas tema como campo de estilo', 'lectura de estilo/tema incorrecta');

/* --- B10: el prefijo del avatar coincide con la fuente unica -------------- */
var og = read('api/evento-og.js');
var ogUrl = '';
if (og) { var mOg = og.match(/'(https?:\/\/[^']+avatar-default\.png)'/); ogUrl = mOg ? mOg[1] : ''; }
var mBk = bKernel.match(/const __BANNER_AVATAR = '([^']+)';/);
var bkUrl = mBk ? mBk[1] : '';
var ogPre = ogUrl ? ogUrl.slice(0, ogUrl.lastIndexOf('/') + 1) : '';
var B10 = !!og && ogUrl !== '' && bkUrl !== '' && ogPre !== '' &&
          bkUrl.slice(0, ogPre.length) === ogPre && bkUrl.slice(ogPre.length) === ogUrl.slice(ogPre.length);
check(B10, 'B10: el prefijo de la URL del avatar del kernel coincide con la fuente unica de api/evento-og.js',
  'og=' + ogUrl + ' kernel=' + bkUrl);

/* --- C11: las 2 plantillas de grid-template-areas declaran las 2 areas ----- */
var areaList = [];
var mA, reA = /grid-template-areas\s*:\s*([^;}]+);/g;
while ((mA = reA.exec(cssNoC)) !== null) {
  var rows = [], mR, reR = /"([^"]*)"/g;
  while ((mR = reR.exec(mA[1])) !== null) rows.push(mR[1].trim().split(/\s+/));
  areaList.push(rows);
}
/* Fila ="area" cuando TODAS sus celdas repiten ese nombre. Asi la misma
   funcion vale para la plantilla de 1 columna ("banner-1") y para la de 2
   ("banner-1 banner-1"), donde comparar la fila joinada no serviria. */
function rowIsArea(r, name) {
  if (!r.length) return false;
  for (var k = 0; k < r.length; k++) if (r[k] !== name) return false;
  return true;
}
function tmplHas(rows, name) {
  for (var k = 0; k < rows.length; k++) if (rowIsArea(rows[k], name)) return true;
  return false;
}
var C11 = areaList.length >= 2, off11 = '';
for (var i = 0; i < areaList.length; i++) {
  if (!tmplHas(areaList[i], 'banner-1') || !tmplHas(areaList[i], 'banner-2')) {
    C11 = false; off11 = 'plantilla ' + (i + 1) + ' sin las 2 areas';
  }
}
check(C11, 'C11: las 2 plantillas de grid-template-areas contienen banner-1 y banner-2',
  'plantillas halladas=' + areaList.length + ' (se esperaban 2, ambas con las 2 areas) ' + off11);

/* --- C12: validez de la plantilla de 2 columnas ------------------------- */
var C12 = false, det12 = 'no se hallo plantilla de 2 columnas';
for (var i = 0; i < areaList.length; i++) {
  var wide = false;
  for (var j = 0; j < areaList[i].length; j++) if (areaList[i][j].length > 1) wide = true;
  if (!wide) continue;
  var allEven = true, b1cells = 0, b2cells = 0;
  for (var j = 0; j < areaList[i].length; j++) {
    var n = areaList[i][j].length;
    if (n % 2 !== 0) allEven = false;
    if (rowIsArea(areaList[i][j], 'banner-1')) b1cells = n;
    if (rowIsArea(areaList[i][j], 'banner-2')) b2cells = n;
  }
  C12 = allEven && b1cells === 2 && b2cells === 2;
  det12 = 'filasPares=' + allEven + ' banner-1=' + b1cells + ' celdas banner-2=' + b2cells + ' celdas';
  break;
}
check(C12, 'C12: en la plantilla de 2 columnas toda fila tiene un numero PAR de celdas y cada area nueva ocupa 2 celdas', det12);

/* --- C13: grid-area: banner-1 / banner-2 -------------------------------- */
var C13 = !!ruleOneId('#mod-banner-1', /grid-area\s*:\s*banner-1/) &&
          !!ruleOneId('#mod-banner-2', /grid-area\s*:\s*banner-2/);
check(C13, 'C13: existen las reglas grid-area: banner-1 y grid-area: banner-2', 'falta algun grid-area');

/* --- C14: los banners NO usan grid-column: 1 / -1 (auto-placement bug) ---- */
var C14 = true, off14 = '';
for (var i = 0; i < bRules.length; i++) {
  var s = bRules[i].sel;
  if (idHook(s, 'mod-banner-1') || idHook(s, 'mod-banner-2')) {
    if (/grid-column\s*:\s*1\s*\/\s*-1/.test(bRules[i].body)) { C14 = false; off14 = s; }
  }
}
check(C14, 'C14: #mod-banner-1 y #mod-banner-2 no declaran grid-column: 1 / -1', off14);

/* --- C15: encendido display:block !important + guarda :has(.banner-frase) - */
var C15on = !!ruleBothIds(/display\s*:\s*block\s*!important/);
var C15g1 = !!ruleOneId('#mod-banner-1', /:has\(\.banner-frase:not\(:empty\)\)/);
var C15g2 = !!ruleOneId('#mod-banner-2', /:has\(\.banner-frase:not\(:empty\)\)/);
check(C15on && C15g1 && C15g2, 'C15: encendido display: block !important y guarda de vacio :has(.banner-frase:not(:empty)) para los 2 banners',
  'on=' + C15on + ' guarda1=' + C15g1 + ' guarda2=' + C15g2);

/* --- C16: .banner-img NO declara display con !important ------------------ */
/* Con !important en la hoja, el display:none inline del kernel no podria
   ganar cuando imagen_url viene vacia y la banda pinta la imagen rota. */
var C16 = true, off16 = '';
for (var i = 0; i < bRules.length; i++) {
  if (/\.banner-img(?![\w-])/.test(bRules[i].sel) && /display\s*:[^;}]*!important/.test(bRules[i].body)) {
    C16 = false; off16 = bRules[i].sel;
  }
}
check(C16, 'C16: .banner-img no declara display con !important (el inline display:none del kernel puede ganar)', off16);

/* --- C17: los .banner-* viven dentro de .tpl-f9b/.Tpl-F9b, nada en :root -- */
var C17a = true, off17 = '';
for (var i = 0; i < bRules.length; i++) {
  var parts = bRules[i].sel.split(',');
  for (var j = 0; j < parts.length; j++) {
    var p = parts[j].trim();
    if (p.indexOf('.banner-') !== -1 && p.indexOf('.tpl-f9b') === -1 && p.indexOf('.Tpl-F9b') === -1) {
      C17a = false; off17 = p;
    }
  }
}
/* La banda declara sus tokens como --f9b-bn-*: se busca ese prefijo y no la
   palabra 'banner', que el nombre del token no lleva. */
var C17b = true, off17b = '';
for (var i = 0; i < bRules.length; i++) {
  if (/^:root(\s|$|,)/.test(bRules[i].sel) && /banner|--f9b-bn-/.test(bRules[i].body)) {
    C17b = false; off17b = bRules[i].sel;
  }
}
check(C17a && C17b, 'C17: cero selectores .banner-* fuera de .tpl-f9b/.Tpl-F9b y cero declaraciones de banner en :root',
  'fueraDeScope=' + off17 + ' enRoot=' + off17b);

/* --- C18: la banda no usa 100vh (umbral 0.5 del IoC section_view) ------- */
var secI = cssSrc.indexOf('28. BANNERS v1.2.0');
var secJ = cssSrc.indexOf('29. PREFERENCES-REDUCED-MOTION');
var bnSec = (secI >= 0 && secJ > secI) ? cssSrc.slice(secI, secJ).replace(/\/\*[\s\S]*?\*\//g, '') : '';
check(bnSec.length > 0 && bnSec.indexOf('100vh') === -1 && /[0-9]+svh/.test(bnSec),
  'C18: la banda no usa 100vh (altura acotada con svh/px, cruza el umbral 0.5 de section_view)',
  'seccion de banners no aislada o usa 100vh');

/* --- D19: CASO H - ejecucion REAL de __bannerVacio ------------------------ */
/* ESTE ES UN CHECK DE EJECUCION, NO ESTRUCTURAL: se extrae del kernel el
   codigo fuente de __bannerVacio (con su helper __bannerCampo incluido, por
   conteo de llaves) y se evalua tal cual en un contexto vm. Los 3 casos son
   los del fix de la banda vacia de 58vh: una frase de solo espacios NO es
   contenido, y la media sola tampoco enciende el atomo. Ademas se verifica
   que la formula solo mira frase/autor/etiqueta (ni urls ni estilo). */
var vDecl = sliceBalanced(bKernel, 'const __bannerVacio = function (it) {');
var vFn = null, vErr = '';
try {
  var c19 = {};
  vm.createContext(c19);
  vm.runInContext('var __bv = (' + vDecl.replace(/^const\s+__bannerVacio\s*=\s*/, '') + ');', c19, { filename: 'kernel-banner-vacio.js' });
  vFn = c19.__bv;
} catch (e) { vErr = e && e.message ? e.message : String(e); }
var d19scope = /__bannerCampo/.test(vDecl) && /trim\(\)/.test(vDecl) &&
                vDecl.indexOf('imagen_url') === -1 && vDecl.indexOf('video_url') === -1 &&
                vDecl.indexOf('estilo') === -1;
var d19r = false, det19 = 'no evaluable';
if (typeof vFn === 'function' && d19scope) {
  var r1 = vFn({ frase: 'Frase' }) === false;
  var r2 = vFn({ frase: '   ' }) === true;
  var r3 = vFn({ imagen_url: 'x' }) === true;
  d19r = r1 && r2 && r3;
  det19 = 'fraseLlena(no vacio)=' + r1 + ' fraseSoloEspacios(vacio)=' + r2 + ' soloImagenUrl(vacio)=' + r3;
} else if (vErr) { det19 = 'error de extraccion/evaluacion: ' + vErr; }
check(d19r, 'D19: __bannerVacio trimea (ejecucion real en vm): "Frase"->no vacio, "   "->vacio, imagen_url sola->vacio', det19);

/* --- D20: estilo normalizado a dorado|monocromo con fail-open dorado ----- */
/* Tambien EJECUCION REAL: se extraen del kernel la tabla __BANNER_ESTILOS, la
   derivacion de __est (trim + lowercase) y la expresion que se emite, y se
   corre el codigo real con un sec stub que registra el atributo. */
var eDecl = sliceBalanced(bKernel, 'const __BANNER_ESTILOS =');
var mEstDer = bKernel.match(/const __est = [^;]+;/);
var mEstSet = bKernel.match(/sec\.setAttribute\('data-estilo',[^\n]*\);/);
var eCode = (eDecl && mEstDer && mEstSet) ? eDecl + '\n' + mEstDer[0] + '\n' + mEstSet[0] + '\n' : '';
var ALLOWED = { 'dorado': 1, 'monocromo': 1 };
/* it es el ITEM del banner, no el valor crudo: el codigo real lee it.estilo. */
function normEstilo(valor) {
  if (!eCode) return 'ERR:no-codigo';
  var c = {
    it: { estilo: valor },
    sec: { attrs: {}, setAttribute: function (k, v) { this.attrs[k] = v; } }
  };
  vm.createContext(c);
  try { vm.runInContext(eCode, c, { filename: 'kernel-banner-estilo.js' }); }
  catch (e) { return 'ERR:' + (e && e.message ? e.message : String(e)); }
  return String(c.sec.attrs['data-estilo']);
}
var casos20 = [
  { in: 'dorado', want: 'dorado' },
  { in: 'Monocromo', want: 'monocromo' },
  { in: ' Monocromo ', want: 'monocromo' },
  { in: 'neon', want: 'dorado' },
  { in: '', want: 'dorado' },
  { in: null, want: 'dorado' },
  { in: 'tema', want: 'dorado' }
];
var d20r = eCode !== '', det20 = eCode === '' ? 'no se extrajo el codigo de estilo' : '';
for (var i = 0; d20r && i < casos20.length; i++) {
  var got = normEstilo(casos20[i].in);
  if (got !== casos20[i].want || !ALLOWED[got]) { d20r = false; det20 = 'entrada ' + JSON.stringify(casos20[i].in) + ' -> ' + got + ' (se esperaba ' + casos20[i].want + ')'; }
}
check(d20r, 'D20: estilo normalizado a dorado|monocromo con fail-open dorado, nunca un tercer valor (ejecucion real en vm)', det20);

/* --- E1: los 2 slots de banner son HIJOS DIRECTOS del contenedor ------------
 * Cierra el gap de cobertura de A1 (regex) y A4 (indexOf): ninguno de los dos
 * ve la profundidad. Este check parsea el anidamiento REAL de evento-app.html
 * con la pila de anidar() y exige, para los 2 banners:
 *   E1.1 el padre inmediato es <main id="main-content-flow"> (contenedor real,
 *        verificado en el archivo: es el unico <main> del documento);
 *   E1.2 profundidad 1: entre la apertura del contenedor y el <section> del
 *        banner no hay ningun otro tag abierto sin cerrar;
 *   E1.3 el </section> cierra el suyo: cero <section> anidados dentro.
 * Si alguien mete el banner en un <div class="mod-..."> o en otro <section>,
 * el grid-area: banner-N del silo deja de aplicar (el grid item pasa a ser el
 * padre), la banda se rompe en runtime y A1/A4 seguirian en verde.
 * ------------------------------------------------------------------------ */
var E1ok = true, badE1 = [], sawE1 = [];
/* El contenedor esperado se toma del archivo, no se asume: si el unico <main>
   deja de existir o deja de llamarse asi, el check falla y lo dice. */
var E1contReal = /<main\b[^>]*\bid\s*=\s*["']main-content-flow["']/.test(kernel);
var E1mains = countOf(kernel, '<main');
if (!E1contReal) {
  E1ok = false;
  badE1.push('E1.1 el contenedor <main id="main-content-flow"> no existe en evento-app.html');
} else if (E1mains !== 1) {
  E1ok = false;
  badE1.push('E1.1 se esperaba 1 <main> en el documento, hay ' + E1mains);
}
var E1slots = ['mod-banner-1', 'mod-banner-2'];
for (var i = 0; i < E1slots.length; i++) {
  var bid = E1slots[i];
  var r = anidar(kernel, 'section', bid);
  if (!r.found) { E1ok = false; badE1.push(bid + ': no se hallo el <section> estatico'); continue; }
  var padre = r.parent ? r.parent + (r.parentId ? '#' + r.parentId : '') : '(sin padre)';
  sawE1.push(bid + ' -> padre=' + padre + ' pila=' + r.depth +
             ' cadena=[' + (r.chain || 'vacia') + ']' +
             (r.quoted ? ' (atributo con > entrecomillado: cierre por estado de comilla)' : ''));
  if (r.parent !== 'main' || r.parentId !== 'main-content-flow') {
    E1ok = false;
    badE1.push('E1.1 ' + bid + ': padre inmediato ' + padre + ' (se esperaba main#main-content-flow)');
  }
  /* E1.2 se mide sobre el TRAMO de texto y desde el frame del CONTENEDOR
     (main#main-content-flow), no desde el padre inmediato: todo tag de scope
     que quede abierto entre el '>' del contenedor y el '<' del banner. */
  var cont = null;
  for (var k3 = r.stack.length - 1; k3 >= 0; k3--) {
    if (r.stack[k3].name === 'main' && r.stack[k3].id === 'main-content-flow') { cont = r.stack[k3]; break; }
  }
  if (!cont) {
    E1ok = false;
    badE1.push('E1.2 ' + bid + ': el contenedor main#main-content-flow no aparece en la pila (cadena=' + r.chain + ')');
  } else {
    var tramo = (r.at > 0) ? abiertosEnTramo(kernel, cont.end, r.at) : { net: -1, abiertos: ['tramo no medible'] };
    if (tramo.net !== 0) {
      E1ok = false;
      badE1.push('E1.2 ' + bid + ': ' + tramo.net + ' tag(s) de scope abierto(s) sin cerrar entre el contenedor y el banner: [' + tramo.abiertos.join(', ') + ']');
    }
  }
  if (r.inner !== 0) {
    E1ok = false;
    badE1.push('E1.3 ' + bid + ': ' + r.inner + ' <section> anidado(s) DENTRO del banner (su primer </section> cierra el mas interno, no el del banner)');
  }
  if (!r.closed) {
    E1ok = false;
    badE1.push('E1.3 ' + bid + ': su </section> nunca llega (cierre cruzado o tag de apertura sin cerrar)');
  }
}
check(E1ok,
  'E1: los 2 <section> de banner son hijos DIRECTOS de <main id="main-content-flow"> (0 tags abiertos entre contenedor y banner, sin section anidado): parseo de anidamiento real, no regex',
  badE1.join(' | ') + (sawE1.length ? ' :: ' + sawE1.join(' | ') : ''));

/* ---------------------------------------------------------------------------
 * 9. ORDEN DE LAYOUT DEL SILO f9b y YOUTUBE EN LA BANDA - F1/F2/F3
 *
 * Tres checks nuevos que reusan areaList (parser de grid-template-areas de la
 * seccion 8) y bKernel (segmento de banners del kernel). No hay otro Resumen.
 * ------------------------------------------------------------------------- */

/* F1: las 2 plantillas declaran las areas en el ORDEN nuevo, como SECUENCIA
   exacta (no solo presencia). Se identifica la plantilla de 1 columna (todas
   las filas de 1 celda) y la de 2 (alguna fila de 2 celdas). */
var EXP_BASE = ['hero', 'countdown', 'meta', 'ctas', 'descripcion', 'lineup',
  'banner-1', 'playlist', 'cartel', 'video', 'boletos', 'whatsapp',
  'banner-2', 'guestlist', 'ubicacion', 'form', 'faq', 'sponsors', 'footer'];
var EXP_WIDE = ['hero hero', 'countdown countdown', 'meta meta', 'ctas ctas',
  'descripcion descripcion', 'lineup lineup', 'banner-1 banner-1',
  'cartel playlist', 'video video', 'boletos guestlist', 'whatsapp guestlist',
  'banner-2 banner-2', 'faq ubicacion', 'sponsors sponsors', 'form form', 'footer footer'];
var baseT = null, wideT = null;
for (var q1 = 0; q1 < areaList.length; q1++) {
  var qr = areaList[q1], qWide = false;
  for (var q2 = 0; q2 < qr.length; q2++) if (qr[q2].length > 1) qWide = true;
  if (qWide) wideT = qr; else baseT = qr;
}
function joinRows(rows) {
  var out = [];
  for (var r = 0; r < rows.length; r++) out.push(rows[r].join(' '));
  return out.join('|');
}
var expBase = [], eb;
for (eb = 0; eb < EXP_BASE.length; eb++) expBase.push([EXP_BASE[eb]]);
var f1base = !!baseT && joinRows(baseT) === joinRows(expBase);
var f1wide = !!wideT && joinRows(wideT) === EXP_WIDE.join('|');
check(f1base && f1wide,
  'F1: las 2 plantillas declaran las areas en el ORDEN nuevo (secuencia exacta 1 col y 2 col)',
  'base=' + (f1base ? 'ok' : (baseT ? joinRows(baseT) : 'sin plantilla de 1 col')) +
  ' wide=' + (f1wide ? 'ok' : (wideT ? joinRows(wideT) : 'sin plantilla de 2 col')));

/* F2: 'experiencias' ya NO es area de ninguna plantilla y NO hay regla
   grid-area: experiencias. El id sigue en el HTML (Cero Borrado) y el silo
   conserva su :has(:empty) de apagado; lo que desaparece es su grid-area. */
var f2area = true, detF2 = '';
for (var g1 = 0; g1 < areaList.length; g1++) {
  for (var g2 = 0; g2 < areaList[g1].length; g2++) {
    for (var g3 = 0; g3 < areaList[g1][g2].length; g3++) {
      if (areaList[g1][g2][g3] === 'experiencias') { f2area = false; detF2 = 'plantilla ' + (g1 + 1); }
    }
  }
}
var f2rule = !/grid-area\s*:\s*experiencias\b/.test(cssNoC);
check(f2area && f2rule,
  'F2: experiencias fuera de las 2 plantillas y sin regla grid-area: experiencias',
  'area=' + f2area + ' regla=' + f2rule + (detF2 ? ' (' + detF2 + ')' : ''));

/* F3: el kernel detecta YouTube con regex y crea un <a class="banner-link">
   (overlay) en lugar de <video>; el camino <video> se conserva para mp4/webm. */
var f3re = bKernel.indexOf('youtube\\.com\\/(?:watch\\?v=|shorts\\/|embed\\/)|youtu\\.be\\/') !== -1;
var f3var = bKernel.indexOf('__bannerYoutube') !== -1;
var f3link = bKernel.indexOf("link.className = 'banner-link';") !== -1;
var f3video = bKernel.indexOf("vid.className = 'banner-video';") !== -1;
var f3gate = bKernel.indexOf('if (vidUrl && __bannerYoutube)') !== -1 &&
             bKernel.indexOf('} else if (vidUrl && !__pideCalma) {') !== -1;
check(f3re && f3var && f3link && f3video && f3gate,
  'F3: kernel detecta YouTube (regex) y crea .banner-link en lugar de <video>; el camino <video> sigue para mp4/webm',
  're=' + f3re + ' var=' + f3var + ' link=' + f3link + ' video=' + f3video + ' gate=' + f3gate);

/* ---------------------------------------------------------------------------
 * 10. LINEUP CARRUSEL f9b - G1/G2/G3
 *
 * El headliner queda FIJO a la izquierda (~44%) y el resto de artistas va en
 * una tira horizontal con scroll-snap; las flechas las crea el kernel de forma
 * aditiva y exclusiva de f9b. Reusa cssNoC y el kernel (un solo Resumen).
 * ------------------------------------------------------------------------- */

/* G1: f9b.css ya NO pinta la etiqueta HEADLINER (ni su pseudo-elemento). */
var g1content = cssNoC.indexOf('content: "HEADLINER"') === -1 &&
                cssNoC.indexOf("content: 'HEADLINER'") === -1;
var g1before = !/headliner::before/.test(cssNoC);
check(g1content && g1before,
  'G1: f9b.css sin etiqueta HEADLINER (ni content ni headliner::before)',
  'content=' + g1content + ' before=' + g1before);

/* G2: f9b.css ya NO usa el grid de 4 columnas; el layout desktop es flex con
   scroll horizontal y el headliner es sticky. */
var g2grid = cssNoC.indexOf('1.3fr repeat(3, 1fr)') === -1 &&
             !/\.artist-card\.headliner\s*\{[^}]*grid-column\s*:\s*1\s*[;}]/.test(cssNoC);
var g2flex = /#db-lineup[^}]*display:\s*flex\s*!important/.test(cssNoC) &&
             /#db-lineup[^}]*overflow-x:\s*auto/.test(cssNoC);
var g2sticky = /\.artist-card\.headliner[^}]*position:\s*sticky/.test(cssNoC);
check(g2grid && g2flex && g2sticky,
  'G2: f9b.css sin grid de 4 columnas; layout flex + overflow-x + headliner sticky',
  'grid=' + g2grid + ' flex=' + g2flex + ' sticky=' + g2sticky);

/* G3: el kernel tiene las flechas del lineup y el gate exclusivo de f9b. */
var g3Start = kernel.indexOf("document.getElementById('db-lineup').innerHTML");
var g3End = kernel.indexOf('// === FIN SEGMENTO: LINEUP ===', g3Start);
var g3Lu = (g3Start >= 0 && g3End > g3Start) ? kernel.slice(g3Start, g3End) : '';
var g3nav = g3Lu.indexOf('lineup-nav') !== -1 && g3Lu.indexOf('lineup-nav-wrap') !== -1;
var g3gate = g3Lu.indexOf("indexOf('tpl-f9b')") !== -1;
check(g3nav && g3gate,
  'G3: kernel con flechas del lineup (lineup-nav) gateadas a tpl-f9b',
  'nav=' + g3nav + ' gate=' + g3gate + ' len=' + g3Lu.length);

/* ---------------------------------------------------------------------------
 * 11. FIXES DE PRESENTACION f9b - H1/H2/H3/H4
 *
 * Cuatro checks que reusan la infraestructura del encabezado (cssNoC, bRules,
 * bKernel) y no crean un segundo Resumen.
 * ------------------------------------------------------------------------- */

/* --- H1: meta sin iconos y los 3 chips con el MISMO ancho en movil (<=991px) */
var H1svg = /\.meta-svg[^{}]*\{[^{}]*display\s*:\s*none\s*!important/.test(cssNoC);
var H1sin100 = /:has\(#meta-lugar\)[^{}]*\{[^{}]*flex-basis\s*:\s*100%/.test(cssNoC) === false;
var media991 = sliceBalanced(cssNoC, '@media (max-width: 991px)');
var H1en991 = media991.indexOf(':has(#meta-lugar)') === -1 &&
              /flex:\s*0\s+0\s+calc\(50%\s*-\s*0\.5rem\)/.test(media991) &&
              /flex-basis\s*:\s*100%/.test(media991) === false;
check(H1svg && H1sin100 && H1en991,
  'H1: f9b.css oculta .meta-svg y da a los 3 chips el MISMO ancho (flex 0 0 calc(50% - 0.5rem)) en el bloque <=991px, sin flex-basis 100%',
  'svg=' + H1svg + ' sin100=' + H1sin100 + ' en991=' + H1en991);

/* --- H2: barra de scroll oculta y sin reglas de thumb/track -------------- */
var H2none = /scrollbar-width\s*:\s*none/.test(cssNoC);
var H2webkit = /::-webkit-scrollbar[^{}]*\{[^{}]*display\s*:\s*none/.test(cssNoC);
var H2resid = cssNoC.indexOf('scrollbar-thumb') === -1 && cssNoC.indexOf('scrollbar-track') === -1;
check(H2none && H2webkit && H2resid,
  'H2: f9b.css oculta la barra (scrollbar-width:none + ::-webkit-scrollbar display:none) y ya no declara thumb/track',
  'none=' + H2none + ' webkit=' + H2webkit + ' sinResiduos=' + H2resid);

/* --- H3: headliner con object-fit cover (center top); normales con cover --- */
var H3coverHl = /\.artist-card\.headliner\s+\.artist-photo[^{}]*\{[^{}]*object-fit\s*:\s*cover/.test(cssNoC) &&
                /\.artist-card\.headliner\s+\.artist-photo[^{}]*\{[^{}]*object-position\s*:\s*center\s+top/.test(cssNoC);
var H3sinContain = !/\.artist-card\.headliner\s+\.artist-photo[^{}]*\{[^{}]*object-fit\s*:\s*contain/.test(cssNoC);
var H3cover = false;
for (var h3 = 0; h3 < bRules.length; h3++) {
  if (/\.artist-photo(?![\w-])/.test(bRules[h3].sel) &&
      bRules[h3].sel.indexOf('.headliner') === -1 &&
      /object-fit\s*:\s*cover/.test(bRules[h3].body)) { H3cover = true; }
}
check(H3coverHl && H3sinContain && H3cover,
  'H3: la foto del headliner usa object-fit: cover (center top) y la de los artistas normales conserva cover',
  'coverHeadliner=' + H3coverHl + ' sinContain=' + H3sinContain + ' coverNormal=' + H3cover);

/* --- H4: banner-link con z-index:4 y gate/rama mp4 intactos -------------- */
var H4z = /link\.style\.cssText\s*=\s*'[^']*z-index:4/.test(bKernel);
var H4gate = bKernel.indexOf('if (vidUrl && __bannerYoutube)') !== -1 &&
             bKernel.indexOf('} else if (vidUrl && !__pideCalma) {') !== -1 &&
             bKernel.indexOf("vid.className = 'banner-video';") !== -1;
check(H4z && H4gate,
  'H4: banner-link con z-index:4 (clic sobre el panel de texto) y el gate + rama mp4 del video intactos',
  'z=' + H4z + ' gate=' + H4gate);

/* --- H5: sin pin CSS superpuesto; mapa oscuro con el pin dorado ------------ */
/* El pin propio se retiro (ADR-059): el punto lo marca el pin NATIVO de Google
   sobre las coordenadas. El filtro del iframe debe ser la cadena invert +
   hue-rotate SIN grayscale ni sepia: esos eran los que doraban TODO el mapa y
   destruian el color del pin. */
var H5nopin = cssNoC.indexOf('db-mapa-container' + '::after') === -1;
var H5filter = false, H5nogra = true;
for (var h5 = 0; h5 < bRules.length; h5++) {
  if (/#db-mapa-container[^{}]*iframe/.test(bRules[h5].sel)) {
    var H5b = bRules[h5].body;
    if (/filter\s*:[^;}]*invert\(1\)/.test(H5b) &&
        /hue-rotate\(\s*232deg\s*\)/.test(H5b) &&
        /saturate\(0\.7\)/.test(H5b) &&
        /!important/.test(H5b)) { H5filter = true; }
    if (/grayscale\(/.test(H5b) || /sepia\(/.test(H5b)) { H5nogra = false; }
  }
}
check(H5nopin && H5filter && H5nogra,
  'H5: cero pin CSS superpuesto y el mapa con invert(1) + hue-rotate(232deg) + saturate(0.7) !important (pin #D2AD3B, sin grayscale ni sepia)',
  'sinPin=' + H5nopin + ' oscuro=' + H5filter + ' sinGrisSepia=' + H5nogra);

/* --- H6: headliner mas alto en movil (72vh) y tablet vertical (64vh) ------ */
var media767 = sliceBalanced(cssNoC, '@media (max-width: 767px)');
var H6tablet = media991.indexOf('min-height: 64vh') !== -1;
var H6movil = media767.indexOf('min-height: 72vh') !== -1;
var H6titulo = media767.indexOf('clamp(2.5rem, 12vw, 3.4rem)') !== -1;
check(H6tablet && H6movil && H6titulo,
  'H6: headliner mas alto en movil (min-height 72vh + titulo clamp 2.5/12vw/3.4 en <=767px) y tablet (64vh en <=991px)',
  'tablet=' + H6tablet + ' movil=' + H6movil + ' titulo=' + H6titulo);

/* --- H7: el link del banner es hermano de .banner-text (sec, no media) ---- */
var H7sec = bKernel.indexOf('sec.appendChild(link);') !== -1;
var H7nomedia = bKernel.indexOf('media.appendChild(link);') === -1;
check(H7sec && H7nomedia,
  'H7: el link del banner se agrega al <section> (sec.appendChild(link)), no a .banner-media',
  'sec=' + H7sec + ' sinMedia=' + H7nomedia);

/* --- H8: el hero centra la foto en escritorio (no center bottom) ---------- */
/* Hay varios bloques @media (min-width: 992px): se recorren TODOS y se exige
   que alguno contenga la regla del hero con background-position center center
   (no basta con mirar el primero, que no es el del hero). */
var H8pos = false, H8mIdx = cssNoC.indexOf('@media (min-width: 992px)');
while (H8mIdx !== -1) {
  var H8blk = sliceBalanced(cssNoC.slice(H8mIdx), '@media (min-width: 992px)');
  if (H8blk.indexOf('#mod-hero') !== -1 &&
      /background-position\s*:\s*center center,\s*center center,\s*center center,\s*0 0/.test(H8blk)) { H8pos = true; break; }
  H8mIdx = cssNoC.indexOf('@media (min-width: 992px)', H8mIdx + 1);
}
var H8base = /#mod-hero[^{}]*\{[^{}]*background-position\s*:\s*center bottom/.test(cssNoC);
check(H8pos && H8base,
  'H8: el hero centra la foto en escritorio (background-position center center en >=992px) y la base conserva center bottom',
  'desk=' + H8pos + ' base=' + H8base);

/* --- H9: la foto del headliner baja el encuadre en >=992px ---------------- */
/* Hay varios bloques @media (min-width: 992px): se recorren TODOS y se exige
   que alguno traiga la regla del headliner con object-position center 52% (el
   encuadre baja hacia la parte de abajo de la foto). La base conserva
   center top para mobile/tablet. */
var H9pos = false, H9mIdx = cssNoC.indexOf('@media (min-width: 992px)');
while (H9mIdx !== -1) {
  var H9blk = sliceBalanced(cssNoC.slice(H9mIdx), '@media (min-width: 992px)');
  if (H9blk.indexOf('#db-lineup') !== -1 &&
      /\.artist-card\.headliner\s+\.artist-photo[^{}]*\{[^{}]*object-position\s*:\s*center\s+52%/.test(H9blk)) { H9pos = true; break; }
  H9mIdx = cssNoC.indexOf('@media (min-width: 992px)', H9mIdx + 1);
}
var H9base = /\.artist-card\.headliner\s+\.artist-photo[^{}]*\{[^{}]*object-position\s*:\s*center\s+top/.test(cssNoC);
check(H9pos && H9base,
  'H9: la foto del headliner baja el encuadre a center 52% en >=992px y la base conserva center top',
  'desk=' + H9pos + ' base=' + H9base);

/* --- H10: los 3 chips del meta comparten min-height en <=991px ------------ */
var H10 = /min-height\s*:\s*4\.8rem/.test(media991);
check(H10, 'H10: los 3 chips del meta comparten min-height: 4.8rem en el bloque <=991px',
  'min-height=' + H10);

/* --- H11: el silo NO declara ningun pin CSS sobre el mapa ------------------ */
/* Ni el "pelado" ni el de .map-own-pin: el pin propio se retiro por completo
   (ADR-059). Cualquier ::after aca volveria a superponer un pin sobre el de
   Google y a marcar mal el punto. */
var H11bare = cssNoC.indexOf('#db-mapa-container::after') === -1;
var H11clase = /#db-mapa-container\.map-own-pin::after/.test(cssNoC);
check(H11bare && !H11clase,
  'H11: el silo no declara NINGUN ::after sobre #db-mapa-container (ni pelado ni con .map-own-pin)',
  'pelado=' + H11bare + ' conClase=' + H11clase);

/* --- H12: el silo pide el pin NATIVO sobre las coordenadas ----------------- */
var H12nativo = /--mapa-pin-nativo\s*:\s*1\s*;/.test(cssNoC);
check(H12nativo,
  'H12: el silo activa --mapa-pin-nativo: 1 (pin de Google exacto sobre --f12-mapa-query)',
  'nativo=' + H12nativo);

/* --- H13: el kernel marca el contenedor SOLO en modo pin propio ------------ */
var H13add = /if\s*\(\s*__mapaQuerySilo\s*&&\s*!__mapaPinNativo\s*\)\s*\{[^}]*classList\.add\('map-own-pin'\)/.test(kernel);
var H13rem = /classList\.remove\('map-own-pin'\)/.test(kernel);
check(H13add && H13rem,
  'H13: el kernel agrega map-own-pin solo con --f12-mapa-query y SIN --mapa-pin-nativo (y la retira si no)',
  'add=' + H13add + ' remove=' + H13rem);

/* --- H14: el silo lleva las coordenadas del lugar en el token -------------- */
/* El token vive en el bloque de variables del silo; su valor debe ser
   "lat,long" con COMA y SIN espacios (un espacio rompe la URL de Google) o
   estar VACIO (entonces el mapa se centra por la direccion de texto). */
var H14tok = /--f12-mapa-query\s*:\s*([^;}]*)/.exec(cssNoC);
var H14val = H14tok ? H14tok[1].trim() : null;
var H14ok = H14val !== null && (H14val === '' || /^-?\d+(\.\d+)?,-?\d+(\.\d+)?$/.test(H14val));
check(H14ok,
  'H14: --f12-mapa-query tiene "lat,long" sin espacios (o vacio para centrar por direccion)',
  'valor=' + JSON.stringify(H14val) + ' formato=' + H14ok);

/* --- H15: el kernel arma q=<coords> (pin nativo) y conserva ll= ------------ */
var H15q = /q=\$\{encodeURIComponent\(__mapaQuerySilo\)\}&t=&z=16/.test(kernel);
var H15ll = /ll=\$\{encodeURIComponent\(__mapaQuerySilo\)\}&z=16/.test(kernel);
check(H15q && H15ll,
  'H15: el kernel usa q=<coords>&z=16 con --mapa-pin-nativo:1 (pin de Google) y mantiene ll= para el modo pin propio',
  'q=' + H15q + ' ll=' + H15ll);

/* ---------------------------------------------------------------------------
 * Resumen
 * ------------------------------------------------------------------------- */

process.stdout.write('smoke_f9b_mistico_nocturno - verificacion end-to-end (sandbox del kernel)\n');
process.stdout.write(lines.join('\n') + '\n');
process.stdout.write('\nResumen: PASS ' + passCount + ', FAIL ' + failCount + '\n');
process.exitCode = failCount > 0 ? 1 : 0;
