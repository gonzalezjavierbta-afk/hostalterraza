'use strict';

/*
 * smoke_redact.js - Test de regresion PERMANENTE de redact() de usage_report.js
 *
 * redact() es la unica capa de defensa ante secretos cuando se exporta contenido
 * con --with-content (ese export se manda a una IA externa). Este smoke extrae la
 * funcion redact REAL del disco y la ejecuta, de modo que cualquier cambio futuro
 * que la debilite rompe el test.
 *
 * Tecnica: se lee scripts/usage_report.js del disco, se extrae el cuerpo de
 * "function redact" por balance de llaves con un scanner que salta strings,
 * comentarios y literales regex, y se evalua con vm.runInContext en un contexto
 * minimo. Los casos corren contra la funcion REAL extraida (no una copia).
 *
 * Uso:   node scripts/smoke_redact.js
 * Exit:  0 = todo PASS ; 1 = algun FAIL ; 2 = no se pudo extraer redact.
 */

var fs = require('fs');
var path = require('path');
var vm = require('vm');

var TARGET = path.join(__dirname, 'usage_report.js');

var BACKTICK = String.fromCharCode(96);
var CH_BS = String.fromCharCode(92);

/* Heuristica: un "/" inicia regex si el caracter significativo previo lo permite. */
function isRegexStart(ch) {
  if (ch === '') return true;
  return '(,=:[!&|?{};+-*%<>^~'.indexOf(ch) !== -1;
}

/* Extrae el texto de "function <name>(...) { ... }" por balance de llaves. */
function extractFunction(src, name) {
  var start = src.indexOf('function ' + name + '(');
  if (start === -1) return null;
  var open = src.indexOf('{', start);
  if (open === -1) return null;

  var depth = 0;
  var inS = false;      /* '...' */
  var inD = false;      /* "..." */
  var inT = false;      /* template literal */
  var inLine = false;   /* // ... */
  var inBlock = false;  /* /* ... * / */
  var prevSig = '';

  for (var i = open; i < src.length; i++) {
    var c = src.charAt(i);
    var n = src.charAt(i + 1);

    if (inLine) { if (c === '\n') inLine = false; continue; }
    if (inBlock) { if (c === '*' && n === '/') { inBlock = false; i++; } continue; }

    if (inS) {
      if (c === CH_BS) { i++; continue; }
      if (c === "'") inS = false;
      continue;
    }
    if (inD) {
      if (c === CH_BS) { i++; continue; }
      if (c === '"') inD = false;
      continue;
    }
    if (inT) {
      if (c === CH_BS) { i++; continue; }
      if (c === BACKTICK) inT = false;
      continue;
    }

    if (c === '/' && n === '/') { inLine = true; i++; continue; }
    if (c === '/' && n === '*') { inBlock = true; i++; continue; }

    if (c === '/' && isRegexStart(prevSig)) {
      i++;
      var inClass = false;
      for (; i < src.length; i++) {
        var rc = src.charAt(i);
        if (rc === CH_BS) { i++; continue; }
        if (rc === '[') { inClass = true; continue; }
        if (rc === ']') { inClass = false; continue; }
        if (rc === '/' && !inClass) break;
        if (rc === '\n') break;
      }
      while (i + 1 < src.length && /[a-z]/i.test(src.charAt(i + 1))) i++;
      prevSig = '/';
      continue;
    }

    if (c === "'") { inS = true; prevSig = c; continue; }
    if (c === '"') { inD = true; prevSig = c; continue; }
    if (c === BACKTICK) { inT = true; prevSig = c; continue; }

    if (c === '{') { depth++; prevSig = c; continue; }
    if (c === '}') {
      depth--;
      prevSig = c;
      if (depth === 0) return src.slice(start, i + 1);
      continue;
    }
    if (!/\s/.test(c)) prevSig = c;
  }
  return null;
}

/* Carga redact desde usage_report.js; null si no se puede extraer/evaluar. */
function loadRedact() {
  var src;
  try { src = fs.readFileSync(TARGET, 'utf8'); }
  catch (e) { return null; }
  var code = extractFunction(src, 'redact');
  if (!code) return null;
  try {
    var ctx = vm.createContext({});
    return vm.runInContext(code + '\n;redact;', ctx, { filename: 'usage_report.js#redact' });
  } catch (e) {
    return null;
  }
}

/* Casos obligatorios. mode 'redact' = los valores prohibidos NO deben aparecer.
   mode 'exact' = la salida debe ser IDENTICA a la entrada (no sobre-redaccion). */
var CASES = [
  { n: 1, mode: 'redact', input: 'AKIAIOSFODNN7EXAMPLE', forbidden: ['AKIAIOSFODNN7EXAMPLE'] },
  { n: 2, mode: 'redact', input: 'sk_live_51H8xYzAbCdEf', forbidden: ['sk_live_51H8xYzAbCdEf'] },
  { n: 3, mode: 'redact', input: 'xapp-1-A123-B456-abcdef', forbidden: ['xapp-1-A123-B456-abcdef'] },
  { n: 4, mode: 'redact', input: 'glpat-xxxxxxxxxxxx', forbidden: ['glpat-xxxxxxxxxxxx'] },
  { n: 5, mode: 'redact', input: 'npm_aBcDeFgHiJkLmNoP', forbidden: ['npm_aBcDeFgHiJkLmNoP'] },

  { n: 6, mode: 'redact',
    input: 'SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U',
    forbidden: ['eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U'] },

  { n: 7, mode: 'redact', input: 'SUPABASE_SERVICE_ROLE_KEY=abcdef123456', forbidden: ['abcdef123456'] },

  { n: 8, mode: 'redact', input: 'Authorization: Bearer abc.def.ghi', forbidden: ['abc.def.ghi'] },

  { n: 9, mode: 'redact', input: 'postgres://usuario:contrasena@host:5432/db',
    forbidden: ['usuario:contrasena@host:5432/db', 'contrasena'] },

  { n: 10, mode: 'redact', input: 'DATABASE_URL=postgres://u:p@h/db',
    forbidden: ['postgres://u:p@h/db', 'u:p@h/db'] },

  { n: 11, mode: 'redact', input: 'sk-proj-abc123XYZ', forbidden: ['sk-proj-abc123XYZ'] },
  { n: 12, mode: 'redact', input: 'ghp_aBcDeFgHiJkLmNoPqRsTuVwXyZ012345',
    forbidden: ['ghp_aBcDeFgHiJkLmNoPqRsTuVwXyZ012345'] },
  { n: 13, mode: 'redact', input: 'AIzaSyA1B2C3D4E5F6G7H8I9J0K',
    forbidden: ['AIzaSyA1B2C3D4E5F6G7H8I9J0K'] },
  { n: 14, mode: 'redact', input: 'password=SuperSecreta123', forbidden: ['SuperSecreta123'] },

  { n: 15, mode: 'redact', input: 'C:\\Users\\JuanPerez\\proyecto\\.env',
    forbidden: ['JuanPerez'] },

  { n: 16, mode: 'redact',
    input: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAAB',
    forbidden: ['iVBORw0KGgoAAAANSUhEUgAAAAEAAAAB'] },

  /* Caso guardia extra: un JWT desnudo (sin prefijo *_KEY=) SOLO puede ser
     redactado por el patron JWT, no por el generico *_KEY=. Sin este caso, la
     eliminacion del patron JWT queda enmascarada por el generico en el caso 6. */
  { n: 21, mode: 'redact',
    input: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIn0.abc123',
    forbidden: ['eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIn0.abc123'] },

  { n: 17, mode: 'exact', input: 'Hola, esto es una frase normal sin secretos.' },
  { n: 18, mode: 'exact', input: 'El evento se llama lanzamiento mistico y usa el silo f9b.' },
  { n: 19, mode: 'exact', input: 'Mira el archivo scripts/usage_report.js y corre node --check.' },
  { n: 20, mode: 'exact', input: 'cache_read / turnos = 61,814 tokens por turno.' }
];

function show(s) {
  return String(s)
    .replace(/\r/g, '\\r')
    .replace(/\n/g, '\\n');
}

function main() {
  var redact = loadRedact();
  if (typeof redact !== 'function') {
    console.error('ERROR: no se pudo extraer redact de usage_report.js');
    process.exit(2);
  }

  var pass = 0;
  var fail = 0;

  for (var i = 0; i < CASES.length; i++) {
    var tc = CASES[i];
    var out = redact(tc.input);
    var ok;

    if (tc.mode === 'exact') {
      ok = (out === tc.input);
    } else {
      ok = true;
      for (var k = 0; k < tc.forbidden.length; k++) {
        if (out.indexOf(tc.forbidden[k]) !== -1) { ok = false; break; }
      }
    }

    if (ok) pass++; else fail++;
    console.log((ok ? 'PASS' : 'FAIL') + ' [' + tc.n + '] ' + show(tc.input) + ' -> ' + show(out));
  }

  console.log('Resumen: PASS ' + pass + ', FAIL ' + fail);
  process.exit(fail === 0 ? 0 : 1);
}

main();
