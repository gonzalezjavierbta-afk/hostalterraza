#!/usr/bin/env node
/*
 * doc_patch.js - Aplicador de parches de documentacion (CommonJS, vanilla).
 *
 * Uso:
 *   node scripts/doc_patch.js <ruta/patch.json> [--dry-run]
 *
 * JSON de entrada:
 *   {
 *     "changes": [
 *       { "file": "...", "oldString": "...", "newString": "...", "replaceAll": false }
 *     ]
 *   }
 *
 * Comportamiento: valida TODO antes de escribir (todo o nada).
 * ASCII-safe: este archivo es 100% ASCII.
 */

'use strict';

const fs = require('fs');
const path = require('path');

function die(msg) {
  console.error('ERROR: ' + msg);
  process.exitCode = 1;
}

function parseArgs(argv) {
  const args = argv.slice(2);
  const out = { patchPath: null, dryRun: false };
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a === '--dry-run' || a === '-n') {
      out.dryRun = true;
    } else if (a === '-h' || a === '--help') {
      out.help = true;
    } else if (!a.startsWith('-') && out.patchPath === null) {
      out.patchPath = a;
    } else {
      throw new Error('argumento no reconocido: ' + a);
    }
  }
  return out;
}

function usage() {
  console.log('Uso: node scripts/doc_patch.js <ruta/patch.json> [--dry-run]');
}

function validateChanges(raw) {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    throw new Error('el JSON raiz debe ser un objeto con la clave "changes"');
  }
  if (!Array.isArray(raw.changes) || raw.changes.length === 0) {
    throw new Error('"changes" debe existir y ser un array no vacio');
  }
  return raw.changes.map(function (c, i) {
    const tag = 'changes[' + i + ']';
    if (!c || typeof c !== 'object' || Array.isArray(c)) {
      throw new Error(tag + ' debe ser un objeto');
    }
    if (typeof c.file !== 'string' || c.file.length === 0) {
      throw new Error(tag + '.file debe ser un string no vacio');
    }
    if (typeof c.oldString !== 'string' || c.oldString.length === 0) {
      throw new Error(tag + '.oldString debe ser un string no vacio');
    }
    if (typeof c.newString !== 'string') {
      throw new Error(tag + '.newString debe ser un string');
    }
    if (c.replaceAll !== undefined && typeof c.replaceAll !== 'boolean') {
      throw new Error(tag + '.replaceAll debe ser boolean si se especifica');
    }
    return {
      file: c.file,
      oldString: c.oldString,
      newString: c.newString,
      replaceAll: c.replaceAll === true
    };
  });
}

function countOccurrences(haystack, needle) {
  let count = 0;
  let idx = haystack.indexOf(needle);
  while (idx !== -1) {
    count++;
    idx = haystack.indexOf(needle, idx + needle.length);
  }
  return count;
}

function applyOne(text, oldString, newString, replaceAll) {
  if (!replaceAll) {
    return text.replace(oldString, newString);
  }
  return text.split(oldString).join(newString);
}

function main() {
  const opts = parseArgs(process.argv);
  if (opts.help) {
    usage();
    return;
  }
  if (!opts.patchPath) {
    usage();
    throw new Error('falta la ruta del patch.json');
  }

  const patchPath = path.resolve(process.cwd(), opts.patchPath);
  let rawText = fs.readFileSync(patchPath, 'utf8');
  // Strip a leading UTF-8 BOM (U+FEFF) if present; tolerant of leading whitespace.
  if (rawText.charCodeAt(0) === 0xFEFF) {
    rawText = rawText.slice(1);
  }
  rawText = rawText.replace(/^\s+/, '');
  let parsed;
  try {
    parsed = JSON.parse(rawText);
  } catch (e) {
    throw new Error('JSON invalido en ' + opts.patchPath + ': ' + e.message);
  }

  const changes = validateChanges(parsed);

  // Fase de validacion: solo lectura, sin escritura.
  const plan = [];
  const errors = [];
  for (let i = 0; i < changes.length; i++) {
    const c = changes[i];
    const abs = path.resolve(process.cwd(), c.file);
    if (!fs.existsSync(abs)) {
      errors.push(c.file + ': el archivo no existe');
      continue;
    }
    let content;
    try {
      content = fs.readFileSync(abs, 'utf8');
    } catch (e) {
      errors.push(c.file + ': no se pudo leer (' + e.message + ')');
      continue;
    }
    const n = countOccurrences(content, c.oldString);
    if (c.replaceAll) {
      if (n === 0) {
        errors.push(c.file + ': replaceAll=true pero hay 0 ocurrencias');
        continue;
      }
    } else if (n !== 1) {
      errors.push(c.file + ': se esperaba 1 ocurrencia, hay ' + n);
      continue;
    }
    plan.push({ change: c, abs: abs, content: content, count: n });
  }

  if (errors.length > 0) {
    for (let i = 0; i < errors.length; i++) {
      console.error('ERROR: ' + errors[i]);
    }
    console.error('doc_patch - validacion fallida, 0 archivos escritos');
    process.exitCode = 1;
    return;
  }

  if (opts.dryRun) {
    for (let i = 0; i < plan.length; i++) {
      console.log('DRY ' + plan[i].change.file + '  (' + plan[i].count + ' ocurrencia(s))');
    }
    console.log('doc_patch - dry-run: ' + plan.length + ' change(s) validado(s), 0 escritos');
    return;
  }

  const touched = {};
  for (let i = 0; i < plan.length; i++) {
    const p = plan[i];
    const c = p.change;
    const base = touched[p.abs] !== undefined ? touched[p.abs] : p.content;
    const updated = applyOne(base, c.oldString, c.newString, c.replaceAll);
    touched[p.abs] = updated;
    fs.writeFileSync(p.abs, updated, 'utf8');
    console.log('OK  ' + c.file + '  (' + p.count + ' ocurrencia(s))');
  }

  const nFiles = Object.keys(touched).length;
  console.log('doc_patch - ' + plan.length + ' change(s) aplicado(s) en ' + nFiles + ' archivo(s)');
}

try {
  main();
} catch (e) {
  die(e && e.message ? e.message : String(e));
}
