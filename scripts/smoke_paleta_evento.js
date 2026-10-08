'use strict';
// smoke_paleta_evento.js - ADR-080 Fase 1 (validacion estatica + motor HSL).
// Sin dependencias. Solo lee admin.html. Node.
var fs = require('fs');
var path = require('path');
var vm = require('vm');

var ROOT = path.resolve(__dirname, '..');
var ADMIN = path.join(ROOT, 'admin.html');
var html = fs.readFileSync(ADMIN, 'utf8');

var pass = 0, fail = 0;
function ok(name, cond, extra) {
  if (cond) { pass++; console.log('PASS ' + name + (extra ? ' - ' + extra : '')); }
  else { fail++; console.log('FAIL ' + name + (extra ? ' - ' + extra : '')); }
}

// 1. Cada <script> inline compila (vm.Script)
var re = /<script\b([^>]*)>([\s\S]*?)<\/script>/gi;
var m, idx = 0, compiled = 0, compileFail = 0, skipped = 0;
while ((m = re.exec(html)) !== null) {
  var attrs = m[1] || '';
  if (/\bsrc\s*=/.test(attrs)) { continue; }
  var tm = attrs.match(/\btype\s*=\s*["']([^"']*)["']/i);
  if (tm && !/javascript/i.test(tm[1])) { skipped++; continue; }
  idx++;
  try { new vm.Script(m[2], { filename: 'admin-inline-' + idx + '.js' }); compiled++; }
  catch (e) { compileFail++; console.log('  inline#' + idx + ' ERROR: ' + e.message); }
}
ok('inline scripts compilan (' + compiled + ' ok, ' + compileFail + ' fail, ' + skipped + ' skip)', compileFail === 0);

// 2. Motor HSL ASCII / sin eval
function sliceBetween(a, b) {
  var s = html.indexOf(a); if (s < 0) return '';
  var e = html.indexOf(b, s); if (e < 0) return html.slice(s);
  return html.slice(s, e);
}
var motor = sliceBetween('function _evNormalizarHex', 'function _evRenderSugerencias');
var high = 0; for (var i = 0; i < motor.length; i++) { if (motor.charCodeAt(i) > 127) high++; }
ok('motor HSL ASCII (bytes>127=0)', high === 0, 'bytes>127=' + high);
ok('motor HSL sin eval', motor.indexOf('eval(') === -1);

// 3. Cero TinyColor
var tiny = (html.match(/tinycolor|TinyColor|renderColorHarmony/g) || []).length;
ok('cero TinyColor/renderColorHarmony', tiny === 0, 'refs=' + tiny);

// 4. UI slots
ok('slot 1 conserva #ev-color', /id="ev-color"/.test(html));
ok('slot 1 conserva #ev-color-hex', /id="ev-color-hex"/.test(html));
ok('slots 2-5 id nuevos', ['ev-color-2','ev-color-3','ev-color-4','ev-color-5'].every(function(id){ return new RegExp('id="' + id + '"').test(html); }));
ok('barra sugerencias #ev-color-harmony', /id="ev-color-harmony"/.test(html));
ok('boton Aplicar sugerencia completa', /aplicarSugerenciaCompleta\(\)/.test(html) && /Aplicar sugerencia completa/.test(html));

// 5. Persistencia: colors 5 claves en _buildConfigLanding
var bclStart = html.indexOf('function _buildConfigLanding');
var bclEnd = html.indexOf('Object.keys(cfg.content)', bclStart);
var bcl = html.slice(bclStart, bclEnd);
var colorsBlock = bcl.match(/colors\s*:\s*\{[\s\S]*?\}/);
var cb = colorsBlock ? colorsBlock[0] : '';
ok('_buildConfigLanding emite colors{5}', ['accent','secondary','tertiary','surface','background'].every(function(k){ return new RegExp('\\b' + k + '\\s*:').test(cb); }));
ok('colors default #c9a84c x5', (cb.match(/#c9a84c/g) || []).length >= 5, 'defaults=' + (cb.match(/#c9a84c/g) || []).length);
ok('sweep de nulls solo cfg.content', /Object\.keys\(cfg\.content\)\.forEach/.test(html));

// 6. Invariante en ambas rutas
ok('invariante guardarEventoWizard', /payload\.color_primario\s*=\s*cfgLanding\.colors\.accent/.test(html));
ok('invariante _crearEventoUnico', /payload\.color_primario\s*=\s*payload\.config_landing\.colors\.accent/.test(html));

// 7. Round-trip openEditMod
ok('round-trip openEditMod fallback', /_evColors\.accent\s*\|\|\s*ev\.color_primario\s*\|\|\s*'#c9a84c'/.test(html));

// 8. Resets en 3 circuitos
var resets = (html.match(/_evResetPaleta\('#c9a84c'\)/g) || []).length;
ok('resets _evResetPaleta (>=3)', resets >= 3, 'found=' + resets);

// 9. HSL sanity ejecutando el motor real
var sandbox = {};
vm.createContext(sandbox);
vm.runInContext(motor, sandbox, { filename: 'motor-hsl.js' });
function ch(h) { return [parseInt(h.substr(1,2),16), parseInt(h.substr(3,2),16), parseInt(h.substr(5,2),16)]; }
var accent = '#c9a84c';
var hsl = sandbox._evHexToHsl(accent);
var sug = sandbox._evGenerarSugerenciasHSL(accent);
var expComp = (((hsl.h + 180) % 360) + 360) % 360;
var compHsl = sandbox._evHexToHsl(sug[1].hex);
var diff = Math.abs(compHsl.h - expComp); if (diff > 180) diff = 360 - diff;
ok('HSL complementario (h+180)%360', diff <= 1.5, 'h=' + hsl.h.toFixed(2) + ' exp=' + expComp.toFixed(2) + ' got=' + compHsl.h.toFixed(2));
var rt = sandbox._evHslToHex(hsl.h, hsl.s, hsl.l).toLowerCase();
var a = ch(accent), b = ch(rt);
var maxd = Math.max(Math.abs(a[0]-b[0]), Math.abs(a[1]-b[1]), Math.abs(a[2]-b[2]));
ok('HSL round-trip identidad (tol 2)', maxd <= 2, rt + ' maxDelta=' + maxd);
ok('5 sugerencias derivadas', sug.length === 5);
ok('sugerencias son hex validos', sug.every(function(s){ return /^#[0-9a-f]{6}$/.test(s.hex); }));

console.log('');
console.log('Resumen: PASS ' + pass + ', FAIL ' + fail);
process.exitCode = fail > 0 ? 1 : 0;