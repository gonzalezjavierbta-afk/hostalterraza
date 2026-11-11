'use strict';

/*
 * smoke_template_muestra.js
 * Verificacion sin navegador del contrato ADR-094: evento de muestra REAL por
 * silo en el preview de ADN Visual (admin.html).
 *
 *   1. Extrae de admin.html el bloque de mapas + helpers ADR-094 y lo evalua en
 *      un sandbox vm con DOM y sessionStorage stub (sin red, sin navegador).
 *   2. (a) _payloadDesdeEvento emite EXACTAMENTE las 7 claves del contrato.
 *   3. (b) _tplSilo resuelve c1 / f1 para los themes sin entrada en _THEME_TPL.
 *   4. (c) sin muestra: iframe sin src, aviso visible, payload eliminado.
 *   5. (d) _muestraPayload / _SAMPLE_EVENTS ausentes del camino de ADN.
 *   6. (e) null para theme sin silo en _TPL_CON_SILO.
 *   7. Wiring estatico: ficha, upsert, DELETE, carga, limpieza y paso 5.
 *
 * Uso: node scripts/smoke_template_muestra.js
 * Sin dependencias externas (fs, path, vm). ASCII-safe: cero bytes > 127.
 */

var fs = require('fs');
var path = require('path');
var vm = require('vm');

var ROOT = path.resolve(__dirname, '..');
var ADMIN = path.join(ROOT, 'admin.html');
var html = fs.readFileSync(ADMIN, 'utf8');

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

function sliceBetween(hay, startMark, endMark) {
  var a = hay.indexOf(startMark);
  if (a === -1) return '';
  var b = hay.indexOf(endMark, a + 1);
  if (b === -1) return '';
  return hay.slice(a, b);
}

// === 0. Extraccion del bloque (mapas + helpers ADR-094) ===
var START = 'const _THEME_TYPE = {';
var END = 'function abrirFichaTheme(theme)';
var a = html.indexOf(START);
var b = html.indexOf(END);
ok('bloque ADR-094 localizado en admin.html', a > -1 && b > a, 'start=' + a + ' end=' + b);

var block = html.slice(a, b);
block += '\n;globalThis.__adr094 = {' +
  '_THEME_TYPE: _THEME_TYPE, _THEME_TPL: _THEME_TPL, _THEME_TPL_PREVIEW: _THEME_TPL_PREVIEW,' +
  '_THEME_FX: _THEME_FX, _TPL_CON_SILO: _TPL_CON_SILO, _SAMPLE_EVENTS: _SAMPLE_EVENTS,' +
  '_tplSilo: _tplSilo, _tplSiloThemes: _tplSiloThemes, _payloadDesdeEvento: _payloadDesdeEvento,' +
  '_payloadMuestraTheme: _payloadMuestraTheme, _ldAdnSyncPreview: _ldAdnSyncPreview,' +
  'setMuestras: function (m) { _templateMuestras = m; },' +
  'getMuestras: function () { return _templateMuestras; },' +
  'setOK: function (v) { _MUESTRAS_OK = v; },' +
  'getOK: function () { return _MUESTRAS_OK; }' +
  ' };';

// === 1. Sandbox: DOM, sessionStorage, timers, estado global del admin ===
function mkEl(id) {
  var el = {
    id: id,
    style: {},
    _attrs: {},
    textContent: '',
    innerHTML: '',
    setAttribute: function (k, v) { this._attrs[k] = String(v); },
    getAttribute: function (k) {
      return Object.prototype.hasOwnProperty.call(this._attrs, k) ? this._attrs[k] : null;
    },
    hasAttribute: function (k) { return Object.prototype.hasOwnProperty.call(this._attrs, k); },
    removeAttribute: function (k) { delete this._attrs[k]; },
    querySelector: function () { if (!this._p) this._p = mkEl(id + '-p'); return this._p; }
  };
  // src como atributo (removeAttribute('src') debe dejarlo sin src real).
  Object.defineProperty(el, 'src', {
    get: function () { return this.hasAttribute('src') ? this.getAttribute('src') : ''; },
    set: function (v) { this.setAttribute('src', v); },
    configurable: true
  });
  return el;
}

var els = {};
['ld-adn-preview-frame', 'ld-adn-empty', 'ld-adn-theme-name', 'ld-adn-desc', 'ld-adn-more']
  .forEach(function (id) { els[id] = mkEl(id); });

var store = {};
var timers = [];
var saved = [];

var sandbox = {
  document: {
    getElementById: function (id) { return Object.prototype.hasOwnProperty.call(els, id) ? els[id] : null; },
    querySelector: function () { return null; },
    querySelectorAll: function () { return []; },
    body: { className: '' }
  },
  window: {},
  sessionStorage: {
    getItem: function (k) { return Object.prototype.hasOwnProperty.call(store, k) ? store[k] : null; },
    setItem: function (k, v) { store[k] = String(v); },
    removeItem: function (k) { delete store[k]; }
  },
  setTimeout: function (fn) { timers.push(fn); return timers.length; },
  clearTimeout: function () { timers.length = 0; },
  alert: function () {},
  console: console,
  _ldThemeSeleccionado: null,
  _wizStep: 1,
  _eventos: [],
  _orgData: { nombre: 'Hostal Terraza', plan: 'pro' },
  SB: null,
  ORG_ID: null,
  _guardarPreviewPayload: function (p) {
    saved.push(p);
    store['ht_preview_payload'] = JSON.stringify(p);
    return true;
  }
};

var api = null;
try {
  api = vm.runInNewContext(block, sandbox, { filename: 'admin-adr094' });
} catch (e) {
  ok('bloque ADR-094 evalua sin error', false, e.message);
}
if (api && !api._payloadDesdeEvento) api = sandbox.__adr094;

// === 2. Datos de prueba (filas reales simuladas de public.eventos) ===
var evCine = {
  id: 101,
  nombre: 'Noche de Cine',
  slug: 'noche-de-cine',
  fecha: '2026-12-01',
  hora: '19:00',
  ubicacion: 'Bogota',
  descripcion: 'Funcion especial',
  poster_url: 'poster.png',
  imagen_url: 'imagen.png',
  aforo_max: 120,
  fase_landing: 'completa',
  lat: 4.65,
  lng: -74.05,
  config_landing: {
    content: { color_primario: '#c9a227' },
    effects: { grain: true, glow: false, vhs: false, parallax: true },
    i18n: { en: { hero: 'x' } }
  }
};
var evFiesta = {
  id: 102,
  nombre: 'Fiesta Tropical',
  slug: 'fiesta-tropical',
  fecha: '2026-12-02',
  hora: '21:00',
  ubicacion: 'Medellin',
  aforo_max: 0,
  config_landing: {}
};
if (sandbox) sandbox._eventos = [evCine, evFiesta];

var KEYS = 'categoria_slug,content,effects,ev,i18n,template_id,theme';

if (api && api._payloadDesdeEvento) {
  ok('bloque ADR-094 evalua sin error', true);
  var frame = els['ld-adn-preview-frame'];
  var empty = els['ld-adn-empty'];

  // === 3. (a) Contrato del payload: 7 claves exactas ===
  var p = api._payloadDesdeEvento(evCine, 'arthouse');
  ok('(a) payload de theme con silo no es null', !!p);
  if (p) {
    ok('(a) exactamente 7 claves del contrato', Object.keys(p).sort().join(',') === KEYS, Object.keys(p).sort().join(','));
    ok('(a) template_id = silo c1', p.template_id === 'c1', String(p.template_id));
    ok('(a) categoria_slug = categoria del theme', p.categoria_slug === String(api._THEME_TYPE['arthouse']).toLowerCase(), String(p.categoria_slug));
    ok('(a) theme intacto', p.theme === 'arthouse', String(p.theme));
    ok('(a) ev es whitelist (sin config_landing)', p.ev.config_landing === undefined && Object.keys(p.ev).length === 15, String(Object.keys(p.ev).length));
    ok('(a) ev conserva id/nombre/fecha', p.ev.id === 101 && p.ev.nombre === 'Noche de Cine' && p.ev.fecha === '2026-12-01');
    ok('(a) ev.org_nombre/plan desde _orgData', p.ev.org_nombre === 'Hostal Terraza' && p.ev.plan === 'pro');
    ok('(a) content/effects/i18n del config_landing', p.content.color_primario === '#c9a227' && p.effects.grain === true && !!p.i18n);
  }
  var p2 = api._payloadDesdeEvento(evFiesta, 'tropical-hostel');
  ok('(a) fallback de effects copia _THEME_FX', !!p2 && JSON.stringify(p2.effects) === JSON.stringify(api._THEME_FX['tropical-hostel'] || api._THEME_FX._default));
  ok('(a) fallback no muta _THEME_FX', !!p2 && (p2.effects.grain = 'mutado') && api._THEME_FX._default.grain === false);
  ok('(a) i18n null sin config_landing', !!p2 && p2.i18n === null);
  ok('(a) content {} sin config_landing', !!p2 && typeof p2.content === 'object' && Object.keys(p2.content).length === 0);
  ok('(a) aforo_max 0 se conserva', !!p2 && p2.ev.aforo_max === 0);
  ok('(a) sin lat/lng no agrega claves a ev', !!p2 && p2.ev.lat === undefined && Object.keys(p2.ev).length === 13);

  // === 4. (b) _tplSilo: la clave guardada es la que lee el preview (R1.1) ===
  var CINE = ['arthouse', 'premiere-gold', 'neon-cult-cine', 'interactive-cine'];
  var F1 = ['tropical-hostel', 'rooftop-sunset', 'underground', 'elegant-cocktail'];
  var malCine = CINE.filter(function (t) { return api._tplSilo(t) !== 'c1'; }).map(function (t) { return t + '=' + api._tplSilo(t); });
  var malF1 = F1.filter(function (t) { return api._tplSilo(t) !== 'f1'; }).map(function (t) { return t + '=' + api._tplSilo(t); });
  ok('(b) 4 themes de cinematografia -> c1', malCine.length === 0, malCine.join(','));
  ok('(b) 4 legacy de fiesta -> f1', malF1.length === 0, malF1.join(','));
  ok('(b) _tplSilo normaliza a minusculas', api._tplSilo('ARTHOUSE') === 'arthouse' && api._tplSilo('C1') === 'c1', api._tplSilo('ARTHOUSE') + '|' + api._tplSilo('C1'));
  var themes = Object.keys(api._THEME_TYPE);
  ok('(b) catalogo de 22 themes', themes.length === 22, String(themes.length));
  var fuera = themes.filter(function (t) { return api._TPL_CON_SILO.indexOf(api._tplSilo(t)) === -1; });
  ok('(b) los 22 themes caen en _TPL_CON_SILO', fuera.length === 0, fuera.join(','));
  var silos = {};
  themes.forEach(function (t) { silos[api._tplSilo(t)] = 1; });
  ok('(b) 16 silos distintos (no 22)', Object.keys(silos).length === 16, String(Object.keys(silos).length));
  ok('(b) c1 compartido por 4 plantillas', api._tplSiloThemes('c1') === 4, String(api._tplSiloThemes('c1')));
  ok('(b) f1 compartido por 4 plantillas', api._tplSiloThemes('f1') === 4, String(api._tplSiloThemes('f1')));

  // === 5. (c) Sin muestra: iframe sin src, aviso visible, payload eliminado ===
  api.setOK(true);
  api.setMuestras({});
  frame.setAttribute('src', 'evento-app.html?preview=1&_=viejo');
  empty.style.display = 'none';
  store['ht_preview_payload'] = '{"viejo":1}';
  saved.length = 0;
  timers.length = 0;
  api._ldAdnSyncPreview('arthouse');
  ok('(c) iframe sin src', frame.getAttribute('src') === null, String(frame.getAttribute('src')));
  ok('(c) src viejo eliminado de la propiedad', frame.src === '', String(frame.src));
  ok('(c) aviso visible', empty.style.display === 'block', String(empty.style.display));
  ok('(c) ht_preview_payload eliminado', store['ht_preview_payload'] === undefined);
  ok('(c) mensaje accionable de muestra', /evento de muestra/i.test(empty.querySelector('p').textContent), empty.querySelector('p').textContent);
  ok('(c) no escribe payload en el estado vacio', saved.length === 0 && timers.length === 0, 'saved=' + saved.length + ' timers=' + timers.length);

  // Degradacion sin migracion: avisa y NO cae al sample sintetico.
  api.setOK(false);
  api._ldAdnSyncPreview('arthouse');
  ok('(c) sin tabla: aviso de migracion adr094', /adr094/i.test(empty.querySelector('p').textContent), empty.querySelector('p').textContent);
  ok('(c) sin tabla: iframe sin src', frame.getAttribute('src') === null && frame.src === '');
  api.setOK(true);

  // === 6. (e) null para theme sin silo en _TPL_CON_SILO ===
  ok('(e) theme inventado -> null', api._payloadDesdeEvento(evCine, 'theme-inventado') === null);
  ok('(e) evento null -> null', api._payloadDesdeEvento(null, 'arthouse') === null);
  ok('(e) theme sin categoria -> null', api._payloadDesdeEvento(evCine, 'c1') === null);
  ok('(e) _payloadMuestraTheme sin muestra -> null', api._payloadMuestraTheme('arthouse') === null);

  // === 7. Camino con muestra: debounce, payload y src ===
  api.setMuestras({ c1: { evento_id: 101, categoria_slug: 'cinematografia' } });
  frame.removeAttribute('src');
  empty.style.display = 'none';
  saved.length = 0;
  timers.length = 0;
  api._ldAdnSyncPreview('premiere-gold');
  ok('muestra: iframe oculto el aviso', empty.style.display === 'none', String(empty.style.display));
  ok('muestra: title con el evento real', /Noche de Cine/.test(String(frame.getAttribute('title'))), String(frame.getAttribute('title')));
  ok('muestra: respeta el debounce de 250 ms', saved.length === 0 && frame.getAttribute('src') === null);
  var pending = timers.slice();
  timers.length = 0;
  pending.forEach(function (fn) { fn(); });
  ok('muestra: guarda el payload tras el debounce', saved.length === 1, String(saved.length));
  ok('muestra: payload guardado con las 7 claves', !!saved[0] && Object.keys(saved[0]).sort().join(',') === KEYS, saved[0] ? Object.keys(saved[0]).sort().join(',') : 'sin payload');
  ok('muestra: payload.template_id = c1 (theme premiere-gold)', !!saved[0] && saved[0].template_id === 'c1');
  ok('muestra: src del preview escrito', /^evento-app\.html\?preview=1&_=\d+$/.test(String(frame.getAttribute('src'))), String(frame.getAttribute('src')));
  ok('muestra: _payloadMuestraTheme devuelve el evento del silo', api._payloadMuestraTheme('arthouse') && api._payloadMuestraTheme('arthouse').ev.id === 101);
}

// === 8. (d) _SAMPLE_EVENTS / _muestraPayload fuera del camino de ADN ===
var adnPath = sliceBetween(html, '// === ADN Visual: panel lateral', 'function abrirFichaTheme(theme)');
var adnCode = adnPath.replace(/\/\/[^\n]*/g, '');
ok('(d) camino ADN localizado', adnPath.length > 0, String(adnPath.length));
ok('(d) _muestraPayload ausente del camino ADN', adnCode.indexOf('_muestraPayload') === -1);
ok('(d) _SAMPLE_EVENTS ausente del camino ADN (codigo, no comentarios)', adnCode.indexOf('_SAMPLE_EVENTS') === -1);
ok('(d) sync no reusa _muestraPayload', !api || String(api._ldAdnSyncPreview).indexOf('_muestraPayload') === -1);
ok('(d) ver muestra y pestana usan _payloadMuestraTheme', count(adnPath, '_payloadMuestraTheme') >= 2, String(count(adnPath, '_payloadMuestraTheme')));
ok('(d) estado vacio: removeAttribute src', adnPath.indexOf("frame.removeAttribute('src')") > -1);
ok('(d) estado vacio: removeItem del payload', adnPath.indexOf("removeItem('ht_preview_payload')") > -1);
ok('(d) panel: un solo mapa _templateMuestras', count(html, 'let _templateMuestras = {}') === 1, String(count(html, 'let _templateMuestras = {}')));

// === 9. Contrato estatico de la ficha (seccion 6.3 del ADR) ===
var ficha = sliceBetween(html, 'function _fichaMuestraHTML', 'function ldFichaMuestraSel');
var save = sliceBetween(html, 'async function ldFichaGuardarMuestra', 'function abrirEventoMuestra');
ok('ficha: select #ficha-tpl-muestra', ficha.indexOf('id="ficha-tpl-muestra"') > -1);
ok('ficha: select con aria-label', ficha.indexOf('aria-label="Evento de muestra"') > -1);
ok('ficha: opciones pintadas con esc()', ficha.indexOf('esc(String(e.id))') > -1 && ficha.indexOf('esc(e.nombre') > -1);
ok('ficha: optgroup de la categoria primero', ficha.indexOf('<optgroup label="') > -1 && ficha.indexOf('(otra categoria)') > -1);
ok('ficha: nota de silo compartido', ficha.indexOf('la muestra aplica a todas') > -1);
ok('ficha: boton Guardar muestra', ficha.indexOf('id="ficha-tpl-muestra-save"') > -1);
ok('ficha: clave por _tplSilo, no el tpl local', save.indexOf('_tplSilo(theme)') > -1 && save.indexOf('const tpl =') === -1);
ok('ficha: upsert con onConflict org_id,template_id', save.indexOf("onConflict: 'org_id,template_id'") > -1);
ok('ficha: value vacio = DELETE del puntero', save.indexOf(".delete().eq('org_id', ORG_ID).eq('template_id', tplSilo)") > -1);
ok('ficha: refresca _ldAdnSyncPreview tras guardar', save.indexOf('_ldAdnSyncPreview(theme)') > -1);

// === 10. Wiring de carga, sync y limpieza ===
var loadEv = sliceBetween(html, 'async function loadEventos', 'async function loadAforosEventos');
ok('carga: loadTemplateMuestras() no bloqueante dentro de loadEventos',
  loadEv.indexOf('loadTemplateMuestras()') > -1 &&
  loadEv.indexOf('await loadTemplateMuestras') === -1 &&
  loadEv.indexOf('renderEventos()') > -1 &&
  loadEv.indexOf('renderEventos()') < loadEv.indexOf('loadTemplateMuestras()'));
var sel = sliceBetween(html, 'function seleccionarTheme', 'function toggleHeroMetaOverride');
ok('sync: solo en el paso 2 del wizard', sel.indexOf('if (_wizStep === 2)') > -1 && sel.indexOf('_ldAdnSyncPreview(theme)') > -1);
var limpiar = sliceBetween(html, 'function _limpiarWizardCompleto', '// FIX v223.1');
ok('limpieza: cancela debounce en _limpiarWizardCompleto', limpiar.indexOf('clearTimeout(_ldAdnTimer)') > -1);
ok('limpieza: iframe sin src al cerrar el wizard', limpiar.indexOf("removeAttribute('src')") > -1);
ok('limpieza: payload eliminado al cerrar el wizard', limpiar.indexOf("removeItem('ht_preview_payload')") > -1);

// === 11. Paso 5: boton "Vista previa" retirado sin romper el resto ===
ok('paso 5: ya no hay onclick abrirVistaPrevia()', count(html, 'onclick="abrirVistaPrevia()"') === 0, String(count(html, 'onclick="abrirVistaPrevia()"')));
ok('paso 5: boton Crear evento intacto', html.indexOf('id="btn-crear-ev"') > -1);
ok('abrirVistaPrevia: definicion intacta', html.indexOf('function abrirVistaPrevia(payload)') > -1);
ok('abrirVistaPrevia: 2 call sites directos + definicion', count(html, 'abrirVistaPrevia(') === 3, String(count(html, 'abrirVistaPrevia(')));

// === 12. ASCII-safe del propio smoke y de la migracion ===
function gt127(src) {
  var buf = Buffer.from(String(src), 'utf8');
  var n = 0;
  for (var i = 0; i < buf.length; i++) if (buf[i] > 127) n++;
  return n;
}
function bytesGt127(file) { return gt127(fs.readFileSync(file, 'utf8')); }
ok('ASCII: codigo ADR-094 (panel+ficha+guardado) con 0 bytes > 127', gt127(adnPath) === 0 && gt127(ficha) === 0 && gt127(save) === 0, gt127(adnPath) + '/' + gt127(ficha) + '/' + gt127(save));
var MIG = path.join(ROOT, 'migrations', 'adr094_org_template_muestras.sql');
if (fs.existsSync(MIG)) ok('ASCII: migracion adr094 con 0 bytes > 127', bytesGt127(MIG) === 0, String(bytesGt127(MIG)));

console.log('=== smoke_template_muestra ===');
console.log(out.join('\n'));
console.log('RESULTADO: ' + pass + '/' + (pass + fail) + ' OK' + (fail ? ' - ' + fail + ' FALLOS' : ''));
process.exit(fail ? 1 : 0);
