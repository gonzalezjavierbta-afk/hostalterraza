/**
 * smoke_f14_vinilos.js
 * Certificacion del silo F14 "Vinilos Inversos" (theme `vinilos`, categoria fiesta).
 *
 * Valida:
 *  - existencia del silo y de su backup (el volcado Tailwind previo)
 *  - ASCII-safety: 0 bytes > 127
 *  - balance de llaves
 *  - aislamiento atomico: cero selectores de primer nivel fuera de .tpl-f14 / .Tpl-F14
 *  - tokens --f14-* y puente --tpl-accent
 *  - prohibidos: @import / @font-face reales (fuera de comentarios) y el selector fantasma .faq-q
 *  - wiring del kernel: data-ticket-url, #db-form-social, .mapa-link, aria-expanded
 *  - registro en admin: theme 'vinilos':'f14' y la card del wizard
 *
 * Uso: node scripts/smoke_f14_vinilos.js
 * Exit: 0 = todo PASS, 1 = al menos un FAIL
 * Solo ASCII: no introducir acentos ni simbolos unicode.
 */

'use strict';

const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const SILO = path.join(ROOT, 'css', 'templates', 'fiesta', 'f14.css');
const BACKUP = path.join(ROOT, 'css', 'templates', 'fiesta', 'f14-volcado-tailwind.bak.css');
const KERNEL = path.join(ROOT, 'evento-app.html');
const ADMIN = path.join(ROOT, 'admin.html');
const I18N = path.join(ROOT, 'js', 'i18n.js');

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

function stripComments(css) {
  return css.replace(/\/\*[\s\S]*?\*\//g, '');
}

/** Devuelve los selectores de primer nivel (los que estan fuera de bloques @media). */
function topLevelSelectors(css) {
  const src = stripComments(css);
  const out = [];
  let depth = 0;
  let buf = '';
  for (let i = 0; i < src.length; i++) {
    const ch = src[i];
    if (ch === '{') {
      if (depth === 0) {
        const sel = buf.trim();
        if (sel && !sel.startsWith('@')) out.push(sel);
        buf = '';
      }
      depth++;
    } else if (ch === '}') {
      depth--;
      buf = '';
    } else if (depth === 0) {
      buf += ch;
    }
  }
  return out;
}

console.log('== smoke F14 vinilos ==');

// 1) Archivos
const siloExists = fs.existsSync(SILO);
check('silo existe', siloExists, siloExists ? path.relative(ROOT, SILO) : 'falta f14.css');
check('backup del volcado previo', fs.existsSync(BACKUP), path.relative(ROOT, BACKUP));

if (!siloExists) {
  console.log('\nResumen: PASS ' + pass + ', FAIL ' + fail);
  process.exit(1);
}

const cssRaw = read(SILO);
const css = stripComments(cssRaw);

check('silo no es un volcado HTML', !/<!DOCTYPE|<html|tailwind/i.test(cssRaw.slice(0, 4000)));
check('tamano razonable', Buffer.byteLength(cssRaw, 'utf8') > 20000, Buffer.byteLength(cssRaw, 'utf8') + ' bytes');

// 2) ASCII-safety
let nonAscii = 0;
for (const b of Buffer.from(cssRaw, 'utf8')) if (b > 127) nonAscii++;
check('ASCII-safety 0 bytes > 127', nonAscii === 0, 'non-ascii=' + nonAscii);

// 3) Balance de llaves
const open = (cssRaw.match(/\{/g) || []).length;
const close = (cssRaw.match(/\}/g) || []).length;
check('llaves balanceadas', open === close, open + '/' + close);

// 4) Aislamiento atomico
const scoped = topLevelSelectors(cssRaw);
const stray = scoped.filter(function (sel) {
  return sel.split(',').some(function (part) {
    const s = part.trim();
    if (!s) return false;
    return !/^\.(tpl-f14|Tpl-F14)\b/.test(s);
  });
});
check('0 selectores fuera de scope', stray.length === 0, stray.length ? stray.slice(0, 3).join(' | ') : scoped.length + ' reglas');

// 5) Doble notacion de casing
check('doble notacion .tpl-f14', /\.tpl-f14\b/.test(cssRaw));
check('doble notacion .Tpl-F14', /\.Tpl-F14\b/.test(cssRaw));

// 6) Tokens y puente cromatico
['--f14-bg', '--f14-bg-2', '--f14-fuego', '--f14-kraft', '--f14-kraft-2', '--f14-ink', '--f14-mute', '--f14-line'].forEach(function (tok) {
  check('token ' + tok, cssRaw.indexOf(tok) !== -1);
});
check('puente --tpl-accent', /--tpl-accent\s*:/.test(cssRaw));

// 7) Prohibidos
check('sin @import real', !/@import\s/.test(css));
check('sin @font-face real', !/@font-face\s*\{/.test(css));
check('sin selector fantasma .faq-q', !/\.faq-q\b/.test(cssRaw));
check('con prefers-reduced-motion', /prefers-reduced-motion/.test(cssRaw));

// 8) Breakpoints
[640, 767, 992, 1279].forEach(function (bp) {
  check('breakpoint ' + bp, new RegExp('min-width\\s*:\\s*' + bp + 'px').test(cssRaw));
});

// 9) Wiring del kernel
const kernel = fs.existsSync(KERNEL) ? read(KERNEL) : '';
check('kernel: id="db-form-social"', /id="db-form-social"/.test(kernel));
check('kernel: class="mapa-link"', /class="mapa-link"/.test(kernel));
check('kernel: data-ticket-url', /data-ticket-url=/.test(kernel));
check('kernel: aria-expanded en faq-item', /class="faq-item"[^>]*aria-expanded/.test(kernel));
check('kernel: gate __esF14Silo', /__esF14Silo/.test(kernel));

// 10) Registro en admin
const admin = fs.existsSync(ADMIN) ? read(ADMIN) : '';
check('admin: theme vinilos -> f14', /'vinilos'\s*:\s*'f14'/.test(admin));
check('admin: card data-theme vinilos', /data-theme="vinilos"/.test(admin));

// 11) Registro del silo f13 "Noche Avalon" (deuda previa saldada) + captura del link de ticketera
check('admin: theme noche-avalon -> f13', /'noche-avalon'\s*:\s*'f13'/.test(admin));
check('admin: card data-theme noche-avalon', /data-theme="noche-avalon"/.test(admin));
check('admin: input ld-boletos-link', /id="ld-boletos-link"/.test(admin));
check('admin: read-back boletos.link', /set\('ld-boletos-link'/.test(admin));
check('admin: write boletos.link', /link:\s*_bLOk/.test(admin));

// 12) Modulo PLAYLIST encendido (v1.2 del silo): el kernel IoC apaga toda
//     section y el silo debe activarla. Sin estas reglas el embed de Spotify se
//     inyecta en el DOM y queda invisible.
check('silo: activa #mod-playlist', /\.tpl-f14 #mod-playlist,[\s\S]{0,900}?display:\s*block !important/.test(cssRaw));
check('silo: grid-area playlist', /\.tpl-f14 #mod-playlist,[\s\S]{0,90}?grid-area:\s*playlist/.test(cssRaw));
// Los conteos de rejilla se hacen sobre el CSS sin comentarios: el LOG DE
// VERSIONES menciona los nombres de las areas y producia falsos positivos.
const playlistAreas = (css.match(/"playlist"/g) || []).length;
check('silo: "playlist" en las rejillas (base + movil)', playlistAreas >= 2, playlistAreas + ' ocurrencias');
check('silo: "cartel playlist" en la fila del breakpoint 767', /"cartel playlist"/.test(css));
check('silo: sin fila "playlist playlist" suelta', !/"playlist playlist"/.test(css));
check('silo: playlist estirado al alto del cartel', /#db-spotify-embed iframe[\s\S]{0,200}?height:\s*100% !important/.test(css) && /min-height:\s*480px !important/.test(css));
check('silo: cartel a alto completo en 2 columnas', /#mod-cartel[\s\S]{0,80}?align-self:\s*stretch/.test(css));
check('silo: caja de video vacia oculta (Cero Borrado)', /#db-video-content:empty[\s\S]{0,120}?display:\s*none !important/.test(css));
check('silo: sin aire bajo la galeria sin video', /#mod-video:has\(#db-video-content:empty\) #db-gallery-grid/.test(css));

check('silo: iframe del embed con alto fijo', /#db-spotify-embed iframe[\s\S]{0,400}?height:\s*\d+px !important/.test(cssRaw));
check('silo: alto movil del iframe', /352px/.test(cssRaw));
check('silo: rotulo PLAYLIST en ::before', /content:\s*"PLAYLIST"/.test(cssRaw));
check('silo: rotulo PLAYLIST compacto en escritorio', /#mod-playlist::before[\s\S]{0,220}?font-size:\s*clamp\(1\.5rem,\s*2\.4vw,\s*2\.4rem\)/.test(css));
check('silo: embed ocupa el 100% de su columna', /#mod-playlist #db-spotify-embed[\s\S]{0,300}?max-width:\s*100% !important/.test(css));
check('silo: enlace Abrir en Spotify estilizado', /\.spotify-open-link[\s\S]{0,400}?\{/.test(cssRaw));

// 12c) Seccion de PATROCINADORES (v1.5 del silo): misma causa que el playlist,
//      el kernel apaga toda section y sin activacion la banda de logos nunca
//      aparece aunque content.sponsors traiga logos reales.
check('silo: activa #mod-sponsors', /\.tpl-f14 #mod-sponsors,[\s\S]{0,700}?display:\s*block !important/.test(cssRaw));
check('silo: grid-area sponsors', /\.tpl-f14 #mod-sponsors,[\s\S]{0,90}?grid-area:\s*sponsors/.test(cssRaw));
const sponsorAreas = (css.match(/"sponsors"/g) || []).length;
check('silo: "sponsors" en base y en el breakpoint 767', sponsorAreas >= 2, sponsorAreas + ' ocurrencias de "sponsors"');
check('silo: banda de patrocinadores de ancho completo', /"sponsors sponsors"/.test(css));
check('silo: logos de patrocinador a 42px', /\.sponsor-img[\s\S]{0,220}?height:\s*42px/.test(css));
check('silo: logos sin marco en la tarjeta', /\.sponsor-item[\s\S]{0,220}?border:\s*none/.test(css));
check('silo: seguro data-hidden de sponsors', /#mod-sponsors\[data-hidden="true"\]/.test(css));

// 12d) FOOTER (v1.6 del silo): el kernel trae <footer id="mod-footer"> pero su
//      IoC global apaga section/header/footer; sin activacion el cierre no
//      aparece. Ademas se verifica el orden nuevo de la rejilla.
check('silo: activa #mod-footer', /\.tpl-f14 #mod-footer,[\s\S]{0,400}?display:\s*block !important/.test(cssRaw));
check('silo: grid-area footer', /\.tpl-f14 #mod-footer,[\s\S]{0,90}?grid-area:\s*footer/.test(cssRaw));
const footerAreas = (css.match(/"footer"|"footer footer"/g) || []).length;
check('silo: footer en las 3 rejillas', footerAreas >= 3, footerAreas + ' ocurrencias');
check('silo: .footer-inner oculto, solo franja (Cero Borrado)', /\.footer-inner[\s\S]{0,120}?display:\s*none !important/.test(css));
check('silo: #footer-copy estilizado', /#footer-copy[\s\S]{0,200}?letter-spacing/.test(css));
const media767 = (css.match(/@media \(min-width: 767px\)[\s\S]*?\n\}/) || [''])[0];
const ordenEsperado = ['"hero hero"', '"ctas ctas"', '"lineup lineup"', '"cartel playlist"', '"boletos form"', '"video video"', '"faq ubicacion"', '"sponsors sponsors"', '"footer footer"'];
const posiciones = ordenEsperado.map((t) => media767.indexOf(t));
const ordenOk = posiciones.every((v, i, arr) => v > -1 && (i === 0 || v > arr[i - 1]));
check('silo: orden hero-lineup-cartel-playlist-boletos-form-galeria-faq-ubicacion-sponsors-footer', ordenOk, posiciones.join(','));

// 13) Kernel: regla general de boleteria de tarifa unica (v1.15.0).
//     Con UNA sola tarifa real se pinta una tarjeta "ENTRADA GENERAL" y el slot
//     de preventa queda vacio. Con 0 o >=2 tarifas se conserva lo anterior.
check('kernel: clave ENTRADA GENERAL (1 uso)', (kernel.match(/landing\.boletos_entrada_general/g) || []).length === 1);
const i18n = fs.existsSync(I18N) ? read(I18N) : '';
const i18nKeys = (i18n.match(/landing\.boletos_entrada_general/g) || []).length;
check('i18n: clave en los 3 idiomas', i18nKeys === 3, i18nKeys + ' definiciones');
check('kernel: conteo de tarifas reales', /__tarifasReales/.test(kernel));
check('kernel: rama de tarifa unica', /__tarifasReales === 1/.test(kernel));
check('kernel: slot preventa vacio en tarifa unica', /bwP\.innerHTML = ''/.test(kernel));
check('kernel: fuente legacy tickets_info cuenta', /__hasTicketsInfoReal/.test(kernel));
check('kernel: rama f9 intacta (1 sola)', (kernel.match(/if \(__esF9Boletos\) \{/g) || []).length === 1);
check('kernel: v307 centinela conservado', (kernel.match(/landing\.pendiente_def/g) || []).length >= 2);

console.log('\nResumen: PASS ' + pass + ', FAIL ' + fail);
if (fail > 0) {
  console.log('Fallos:');
  failures.forEach(function (f) { console.log(' - ' + f); });
  process.exit(1);
}
process.exit(0);
