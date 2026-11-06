'use strict';

/*
 * smoke_adn_muestra_preview.js
 * Verificacion sin navegador del "evento de muestra" del ADN Visual (crear evento):
 *   1. Extrae de admin.html el bloque de mapas + _SAMPLE_EVENTS + _muestraPayload
 *      y lo evalua en un sandbox vm con DOM stub.
 *   2. Cada plantilla con silo CSS resuelve un payload de muestra valido.
 *   3. Las 4 plantillas legacy de fiesta (sin silo) devuelven null de forma honesta.
 *   4. Formas de content que el renderer consume (objetos, no strings).
 *   5. Imagenes: solo el asset permitido de Supabase Storage.
 *   6. Wiring del panel lateral: ids, funciones de onclick, CSS y hooks.
 *
 * Uso: node scripts/smoke_adn_muestra_preview.js
 * Sin dependencias externas (fs, path, vm). ASCII-safe: cero bytes > 127.
 */

var fs = require('fs');
var path = require('path');
var vm = require('vm');

var ROOT = path.resolve(__dirname, '..');
var ADMIN = path.join(ROOT, 'admin.html');
var IMG = 'https://ctgyvydzshueemlelkzv.supabase.co/storage/v1/object/public/assets/avatar-default.png';

var pass = 0;
var fail = 0;
var out = [];

function ok(name, cond, detail) {
  if (cond) { pass++; out.push('  OK   ' + name); }
  else { fail++; out.push('  FAIL ' + name + (detail ? ' -> ' + detail : '')); }
}

function count(hay, needle) {
  var n = 0;
  var i = 0;
  while (true) {
    i = hay.indexOf(needle, i);
    if (i === -1) break;
    n++;
    i += needle.length;
  }
  return n;
}

var html = fs.readFileSync(ADMIN, 'utf8');

// === 1. Extraccion del bloque de datos/helpers ===
var START = 'const _THEME_TYPE = {';
var END = 'function abrirVistaPreviaDeMuestra';
var a = html.indexOf(START);
var b = html.indexOf(END);
ok('bloque ADN localizado en admin.html', a > -1 && b > a, 'start=' + a + ' end=' + b);

var block = html.slice(a, b);
block += '\n;({_THEME_TYPE,_THEME_TPL,_THEME_TPL_PREVIEW,_THEME_FICHA,_THEME_FX,_TPL_CON_SILO,_SAMPLE_EVENTS,_muestraPayload});';

var sandbox = {
  document: {
    getElementById: function () { return null; },
    querySelector: function () { return null; },
    querySelectorAll: function () { return []; },
    body: { className: '' }
  },
  window: {},
  sessionStorage: { getItem: function () { return null; }, setItem: function () {} },
  alert: function () {},
  console: console
};

var data = null;
try {
  data = vm.runInNewContext(block, sandbox, { filename: 'admin-adn-sample' });
} catch (e) {
  ok('bloque ADN evalua sin error', false, e.message);
}

if (data) {
  ok('bloque ADN evalua sin error', true);

  var themes = Object.keys(data._THEME_TYPE);
  ok('catalogo de plantillas = 22', themes.length === 22, String(themes.length));

  var LEGACY_F1 = ['tropical-hostel', 'rooftop-sunset', 'underground', 'elegant-cocktail'];
  var conPreview = 0;
  var malos = [];

  themes.forEach(function (theme) {
    var p = null;
    try { p = data._muestraPayload(theme); } catch (e) { malos.push(theme + ':throw'); return; }
    if (!p) { malos.push(theme + ':null'); return; }

    conPreview++;
    var cat = data._THEME_TYPE[theme];
    var tpl = String(p.template_id || '');
    if (data._TPL_CON_SILO.indexOf(tpl) === -1) malos.push(theme + ':tpl-fuera-de-silo=' + tpl);
    if (LEGACY_F1.indexOf(theme) !== -1 && tpl !== 'f1') malos.push(theme + ':legacy-no-f1=' + tpl);
    if (p.categoria_slug !== cat) malos.push(theme + ':categoria=' + p.categoria_slug);
    if (!p.content || !p.content.color_primario) malos.push(theme + ':sin-color-primario');
    if (!p.effects || typeof p.effects !== 'object') malos.push(theme + ':sin-effects');
    if (!p.ev || !p.ev.nombre || !p.ev.fecha || !p.ev.ubicacion) malos.push(theme + ':ev-incompleto');
  });

  ok('22 plantillas resuelven muestra (todas)', conPreview === 22, String(conPreview));
  ok('4 legacy de fiesta caen al silo base f1', malos.filter(function (m) { return m.indexOf(':legacy-no-f1') > -1; }).length === 0, malos.join(','));
  ok('_TPL_CON_SILO incluye f1', data._TPL_CON_SILO.indexOf('f1') > -1);
  ok('theme inexistente devuelve null', data._muestraPayload('no-existe') === null);
  ok('payloads sin defectos de contrato', malos.length === 0, malos.join(' | '));

  // === 2. Formas de content ===
  var fx = data._muestraPayload('mistico');
  ok('fiesta: dj_lineup array de objetos', Array.isArray(fx.content.dj_lineup) && fx.content.dj_lineup.length === 3 && !!fx.content.dj_lineup[0].nombre);
  ok('fiesta: boletos {preventa,taquilla}', typeof fx.content.boletos === 'object' && !!fx.content.boletos.preventa && !!fx.content.boletos.taquilla);
  ok('fiesta: faq {q,a}', Array.isArray(fx.content.faq) && !!fx.content.faq[0].q && !!fx.content.faq[0].a);
  ok('fiesta: gallery array', Array.isArray(fx.content.gallery) && fx.content.gallery.length > 0);
  ok('fiesta: sponsors con logo_url', Array.isArray(fx.content.sponsors) && fx.content.sponsors[0].logo_url === IMG);

  var ci = data._muestraPayload('arthouse');
  ok('cine: poster_url y banners', ci.content.poster_url === IMG && Array.isArray(ci.content.banners));
  ok('cine: tickets_info string', typeof ci.content.tickets_info === 'string' && ci.content.tickets_info.length > 0);

  var ca = data._muestraPayload('solidario-moderno');
  ok('campana: historia {titulo,texto,imagen}', ca.content.historia && !!ca.content.historia.titulo && !!ca.content.historia.texto && ca.content.historia.imagen === IMG);
  ok('campana: objetivo numerico', ca.content.objetivo && typeof ca.content.objetivo.meta === 'number' && typeof ca.content.objetivo.recaudado === 'number' && !!ca.content.objetivo.moneda);
  ok('campana: impacto [{etiqueta,valor,icono}]', Array.isArray(ca.content.impacto) && ca.content.impacto.length === 3 && !!ca.content.impacto[0].etiqueta && !!ca.content.impacto[0].valor);
  ok('campana: equipo usa rol (no cargo)', Array.isArray(ca.content.equipo) && !!ca.content.equipo[0].rol && ca.content.equipo[0].cargo === undefined);

  // cta_final y footer son OBJETOS para el renderer
  var cats = [fx, ci, ca];
  var ctaMalos = cats.filter(function (p) { return !p.content.cta_final || typeof p.content.cta_final !== 'object' || !p.content.cta_final.titulo; });
  var footMalos = cats.filter(function (p) { return !p.content.footer || typeof p.content.footer !== 'object' || !p.content.footer.tagline; });
  ok('cta_final objeto en las 3 categorias', ctaMalos.length === 0, String(ctaMalos.length));
  ok('footer objeto en las 3 categorias', footMalos.length === 0, String(footMalos.length));

  // === 3. Sin URLs externas fuera del asset permitido ===
  var allJson = JSON.stringify(data._SAMPLE_EVENTS);
  var urls = allJson.match(/https?:\/\/[^"']+/g) || [];
  var externas = urls.filter(function (u) { return u !== IMG; });
  ok('imagenes solo del asset permitido', externas.length === 0, externas.join(','));

  // === 4. _THEME_TPL intacto (crear eventos no cambia) ===
  ok('_THEME_TPL no mapea cine', data._THEME_TPL.arthouse === undefined);
  ok('_THEME_TPL no mapea campana', data._THEME_TPL['solidario-moderno'] === undefined);
  ok('_THEME_TPL conserva 10 silos fiesta', Object.keys(data._THEME_TPL).length === 10, String(Object.keys(data._THEME_TPL).length));
}

// === 5. Wiring del panel lateral (estatico) ===
ok('panel: id ld-adn-preview', html.indexOf('id="ld-adn-preview"') > -1);
ok('panel: iframe ld-adn-preview-frame', html.indexOf('id="ld-adn-preview-frame"') > -1);
ok('panel: contenedor ld-adn-layout', html.indexOf('class="ld-adn-layout"') > -1);
ok('panel: CSS grid 2 columnas >=1280px', html.indexOf('@media(min-width:1280px){.ld-adn-layout{grid-template-columns:1fr 380px') > -1);
// Estructura: panel solo en ADN Visual (paso 2).
ok('estructura: layout abre antes del paso 2', html.indexOf('<div class="ld-adn-layout">') > -1 && html.indexOf('<div class="ld-adn-layout">') < html.indexOf('data-wiz-step="2"'));
ok('estructura: aside despues del paso 3', html.indexOf('id="ld-adn-preview"') > html.indexOf('</div><!-- /wiz-step 3 -->'));
ok('estructura: layout cierra antes de ev-landing-config', html.indexOf('</div><!-- /ld-adn-layout -->') > html.indexOf('id="ld-adn-preview"') && html.indexOf('</div><!-- /ld-adn-layout -->') < html.indexOf('</div><!-- /ev-landing-config -->'));
ok('solo ADN: CSS oculta el panel fuera del paso 2', html.indexOf('.ld-adn-layout--off .ld-adn-aside') > -1 && html.indexOf('.ld-adn-layout--off .ld-adn-mobile') > -1);
ok('solo ADN: wizShow alterna ld-adn-layout--off', html.indexOf("classList.toggle('ld-adn-layout--off'") > -1);
ok('cards: 22 clic seleccionan plantilla', count(html, 'onclick="seleccionarTheme(') === 22, String(count(html, 'onclick="seleccionarTheme(')));
ok('cards: ninguna abre la ficha directamente', count(html, 'onclick="abrirFichaTheme(') === 0, String(count(html, 'onclick="abrirFichaTheme(')));
ok('descripcion: parrafo + boton Mas informacion', html.indexOf('id="ld-adn-desc"') > -1 && html.indexOf('id="ld-adn-more"') > -1);
ok('descripcion: ldAdnMasInfo abre la ficha', html.indexOf('function ldAdnMasInfo()') > -1 && html.indexOf('abrirFichaTheme(_ldThemeSeleccionado)') > -1);
ok('wiring: _ldAdnSyncPreview definida', html.indexOf('function _ldAdnSyncPreview(theme)') > -1);
ok('wiring: sync al confirmar plantilla', count(html, '_ldAdnSyncPreview(theme)') >= 1);
ok('wiring: sync al entrar al paso 2', html.indexOf('if (step === 2)') > -1 && html.indexOf('_ldAdnSyncPreview(_ldThemeSeleccionado)') > -1);
ok('wiring: ldAdnVerMuestra definida', html.indexOf('function ldAdnVerMuestra()') > -1);
ok('wiring: ldAdnAbrirPestana definida', html.indexOf('function ldAdnAbrirPestana()') > -1);
ok('wiring: un solo boton movil', count(html, 'onclick="ldAdnVerMuestra()"') === 1, String(count(html, 'onclick="ldAdnVerMuestra()"')));
ok('preview: abrirVistaPrevia acepta payload', html.indexOf('function abrirVistaPrevia(payload)') > -1);
ok('preview: no se reconstruye el borrador en la muestra', html.indexOf('abrirVistaPrevia(payload);') > -1);
ok('contrato: cero display:none sobre id del panel', html.indexOf("getElementById('ld-adn-preview').style.display") === -1);

console.log('=== smoke_adn_muestra_preview ===');
console.log(out.join('\n'));
console.log('RESULTADO: ' + pass + '/' + (pass + fail) + ' OK' + (fail ? ' - ' + fail + ' FALLOS' : ''));
process.exit(fail ? 1 : 0);
