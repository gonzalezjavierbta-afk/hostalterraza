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

console.log('\nResumen: PASS ' + pass + ', FAIL ' + fail);
if (fail > 0) {
  console.log('Fallos:');
  failures.forEach(function (f) { console.log(' - ' + f); });
  process.exit(1);
}
process.exit(0);
