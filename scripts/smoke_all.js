/* ==========================================================================
   smoke_all.js - Runner de smokes del proyecto (TSK-117, decision de pipeline)
   --------------------------------------------------------------------------
   Descubre `scripts/smoke_*.js`, ejecuta cada uno en un proceso hijo y agrega
   el resultado. Un solo punto de entrada para la verificacion previa al
   despliegue, sin acoplar los smokes entre si (smoke_qa_asserts NO se toca:
   sigue siendo un smoke autonomo mas).

   Uso:
     node scripts/smoke_all.js
     node scripts/smoke_all.js --only countdown,tz    (filtra por subcadena)
     node scripts/smoke_all.js --list

   Exit code: 0 si todos pasan, 1 si alguno falla. Sin dependencias, ASCII puro.
   ========================================================================== */
'use strict';

var fs = require('fs');
var path = require('path');
var childProcess = require('child_process');

var ROOT = path.resolve(__dirname, '..');
var SCRIPTS = path.join(ROOT, 'scripts');
var SELF = path.basename(__filename);
var TIMEOUT_MS = 120000;

function arg(name) {
    var i = process.argv.indexOf(name);
    return i === -1 ? null : (process.argv[i + 1] || '');
}

var only = arg('--only');
var filters = only ? only.split(',').map(function (s) { return s.trim().toLowerCase(); }).filter(Boolean) : null;

var files = fs.readdirSync(SCRIPTS)
    .filter(function (f) { return /^smoke_.*\.js$/i.test(f) && f !== SELF; })
    .sort();

if (filters) {
    files = files.filter(function (f) {
        var low = f.toLowerCase();
        return filters.some(function (k) { return low.indexOf(k) !== -1; });
    });
}

if (process.argv.indexOf('--list') !== -1) {
    files.forEach(function (f) { console.log(f); });
    process.exit(0);
}

if (!files.length) {
    console.log('smoke_all: no hay smokes que ejecutar' + (only ? ' con --only ' + only : ''));
    process.exit(1);
}

console.log('smoke_all - ' + files.length + ' smokes (node ' + process.version + ')');
console.log('');

var results = [];

files.forEach(function (f) {
    var started = Date.now();
    var out = '';
    var code = 0;
    try {
        out = childProcess.execSync('node "' + path.join('scripts', f) + '"', {
            cwd: ROOT,
            encoding: 'utf8',
            stdio: 'pipe',
            timeout: TIMEOUT_MS
        });
    } catch (e) {
        code = (e && typeof e.status === 'number') ? e.status : 1;
        out = String((e && e.stdout) || '') + String((e && e.stderr) || '');
    }
    var secs = ((Date.now() - started) / 1000).toFixed(1);

    // Ultima linea con un resumen reconocible (Resumen/VEREDICTO/FAIL).
    var lines = out.split(/\r?\n/).map(function (l) { return l.trim(); }).filter(Boolean);
    var summary = '';
    for (var i = lines.length - 1; i >= 0; i--) {
        if (/Resumen:|VEREDICTO:|FAIL|PASS/.test(lines[i])) { summary = lines[i]; break; }
    }
    if (!summary) summary = lines.length ? lines[lines.length - 1] : '(sin salida)';

    var ok = code === 0;
    results.push({ file: f, ok: ok, code: code, secs: secs, summary: summary });
    console.log((ok ? '  PASS  ' : '  FAIL  ') + f + '  [' + secs + 's]  ' + summary.slice(0, 110));
});

var failed = results.filter(function (r) { return !r.ok; });

console.log('');
console.log('------------------------------------------------------------');
console.log('TOTAL: ' + results.length + '  PASS: ' + (results.length - failed.length) + '  FAIL: ' + failed.length);
if (failed.length) {
    console.log('Fallidos:');
    failed.forEach(function (r) { console.log('  - ' + r.file + ' (exit ' + r.code + ')'); });
}
console.log(failed.length ? 'VEREDICTO: FAIL' : 'VEREDICTO: PASS');
process.exit(failed.length ? 1 : 0);
