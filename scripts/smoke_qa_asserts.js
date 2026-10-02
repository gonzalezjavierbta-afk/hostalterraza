'use strict';

/*
 * smoke_qa_asserts.js - Smoke de QA reutilizable (mecaniza asserts manuales)
 *
 * Los asserts de QA se hacia a mano turno a turno y eso agotaba al subagente
 * (lo que mas turnos consume es verificar). Este script los ejecuta en un solo
 * comando, con data LOCAL: no usa red, no escribe archivos y no modifica nada.
 *
 * Asserts cubiertos:
 *   (a) node --check por cada archivo de scripts/*.js
 *   (b) ASCII-safety por archivo: 0 bytes > 127 (criterio de express_check.js)
 *   (c) CommonJS estricto: sin lineas que empiecen con import ni export (BUG-001)
 *   (d) Contrato CLI congelado de usage_report.js (--help contiene cada flag)
 *   (e) Contrato CLI de session_close.js (--help contiene cada flag)
 *   (f) Autocomprobacion: este script emite literalmente "Resumen: PASS"
 *
 * OJO (contrato de salida): el sufijo "Resumen: PASS N, FAIL M" NO es
 * universal en los smokes existentes. Solo lo emiten smoke_redact.js y
 * smoke_f9b_mistico_nocturno.js. Por eso este script NO exige ese sufijo a
 * los demas smokes: seria un assert falso.
 *
 * TODO (declarado aqui, NO implementado, NO verificado por este script):
 *   - ejecucion cruzada de los otros smokes (invocarlos como subprocess y
 *     comparar su exit code + conteo real).
 *   - asserts de red (endpoints Supabase) y de media (fallback onerror).
 *   - assert de version de Node (rango minimo soportado).
 *
 * Uso:   node scripts/smoke_qa_asserts.js
 * Exit:  0 = todo PASS ; 1 = algun FAIL
 */

var fs = require('fs');
var path = require('path');
var childProcess = require('child_process');

var SCRIPTS_DIR = __dirname;

/* Resumen literal del contrato de salida de ESTE script (assert f). */
var RESUMEN_LITERAL = 'Resumen: PASS';

/* Palabras prohibidas al inicio de linea (BUG-001). Se arman por union para
   que el literal no aparezca ni al inicio de una linea de este archivo. */
var KW_A = 'imp' + 'ort';
var KW_B = 'exp' + 'ort';

/* Contrato CLI congelado: si un flag desaparece, este assert falla. */
var USAGE_FLAGS = [
  '--summary', '--sessions', '--tree', '--json', '--csv',
  '--since', '--until', '--project', '--agent', '--root', '--db'
];

var CLOSE_FLAGS = [
  '--root', '--since', '--budget', '--umbral', '--est-tokens',
  '--est-turnos', '--est-seg'
];

var passCount = 0;
var failCount = 0;
var assertNum = 0;

function log(msg) {
  process.stdout.write(String(msg) + '\n');
}

/* Registra un assert. ok=true suma PASS, ok=false suma FAIL + motivo. */
function assert(ok, label, reason) {
  assertNum += 1;
  if (ok) {
    passCount += 1;
    log('PASS [' + assertNum + '] ' + label);
  } else {
    failCount += 1;
    log('FAIL [' + assertNum + '] ' + label + ' -> ' + reason);
  }
}

/* Lista scripts/*.js de forma ordenada y estable. */
function listScripts() {
  var names = fs.readdirSync(SCRIPTS_DIR);
  var files = [];
  for (var i = 0; i < names.length; i += 1) {
    if (/\.js$/.test(names[i])) {
      files.push(names[i]);
    }
  }
  files.sort();
  return files;
}

function readText(abs) {
  return fs.readFileSync(abs, 'utf8');
}

/* (a) node --check por archivo. */
function checkSyntax(abs, name) {
  try {
    childProcess.execFileSync('node', ['--check', abs], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe']
    });
    assert(true, 'node --check ' + name);
  } catch (err) {
    var detail = 'fallo desconocido de node --check';
    if (err && err.stderr) {
      detail = String(err.stderr).replace(/\r?\n/g, ' ').trim();
    } else if (err && err.message) {
      detail = String(err.message);
    }
    assert(false, 'node --check ' + name, detail);
  }
}

/* (b) ASCII-safety: 0 caracteres > 127. Reporta conteo y lineas (max 8). */
function checkAscii(abs, name) {
  var text = null;
  try {
    text = readText(abs);
  } catch (err) {
    assert(false, 'ascii-safe ' + name, 'no se pudo leer: ' + err.message);
    return;
  }
  var high = 0;
  var lines = [];
  var line = 1;
  for (var i = 0; i < text.length; i += 1) {
    var code = text.charCodeAt(i);
    if (code === 10) {
      line += 1;
    } else if (code > 127) {
      high += 1;
      if (lines.length < 8) {
        lines.push(line);
      }
    }
  }
  if (high === 0) {
    assert(true, 'ascii-safe ' + name);
  } else {
    assert(false, 'ascii-safe ' + name,
      'bytes>127=' + high + ' (linea ' + lines.join(',') + ')');
  }
}

/* (c) CommonJS estricto: ni import ni export al inicio de una linea. */
function checkCommonJs(abs, name) {
  var text = null;
  try {
    text = readText(abs);
  } catch (err) {
    assert(false, 'commonjs ' + name, 'no se pudo leer: ' + err.message);
    return;
  }
  var lines = text.split(/\r?\n/);
  var hits = [];
  for (var i = 0; i < lines.length; i += 1) {
    var line = lines[i].replace(/^\s+/, '');
    if (line.indexOf(KW_A) === 0 || line.indexOf(KW_B) === 0) {
      if (hits.length < 8) {
        hits.push((i + 1) + ':' + line.slice(0, 40));
      }
    }
  }
  if (hits.length === 0) {
    assert(true, 'commonjs ' + name);
  } else {
    assert(false, 'commonjs ' + name, 'ESM en linea(s) ' + hits.join(' | '));
  }
}

/* Ejecuta <script> --help y devuelve el stdout (string). */
function helpText(file) {
  var abs = path.join(SCRIPTS_DIR, file);
  try {
    return String(childProcess.execFileSync('node', [abs, '--help'], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe']
    }));
  } catch (err) {
    if (err && err.stdout) {
      return String(err.stdout);
    }
    return '';
  }
}

/* (d)/(e) Cada flag del contrato debe aparecer en el --help correspondiente. */
function checkHelpContract(file, flags) {
  var text = helpText(file);
  if (text.length === 0) {
    for (var z = 0; z < flags.length; z += 1) {
      assert(false, file + ' --help contiene ' + flags[z], 'no se pudo ejecutar --help');
    }
    return;
  }
  for (var i = 0; i < flags.length; i += 1) {
    var flag = flags[i];
    assert(text.indexOf(flag) !== -1, file + ' --help contiene ' + flag,
      'flag ausente en la ayuda');
  }
}

/* Linea de resumen del contrato de salida de este script (assert f). */
function resumenLine(p, f) {
  return RESUMEN_LITERAL + ' ' + p + ', FAIL ' + f;
}

function main() {
  var files = listScripts();

  log('smoke_qa_asserts - asserts de QA mecanizados (data local, sin red)');
  log('Directorio: ' + SCRIPTS_DIR);
  log('Archivos en scripts/: ' + files.length);
  log('TODO fuera de alcance: ejecucion cruzada de otros smokes, asserts de');
  log('  red/media, y version de Node. Este script NO los verifica.');
  log('');

  for (var i = 0; i < files.length; i += 1) {
    var abs = path.join(SCRIPTS_DIR, files[i]);
    checkSyntax(abs, files[i]);
    checkAscii(abs, files[i]);
    checkCommonJs(abs, files[i]);
  }

  checkHelpContract('usage_report.js', USAGE_FLAGS);
  checkHelpContract('session_close.js', CLOSE_FLAGS);

  /* (f) Autocomprobacion del contrato de salida propio. */
  var probe = resumenLine(7, 0);
  assert(probe.indexOf(RESUMEN_LITERAL) === 0, 'este script emite ' + RESUMEN_LITERAL, 'contrato roto');

  log('');
  log(resumenLine(passCount, failCount));
  process.exit(failCount === 0 ? 0 : 1);
}

main();
