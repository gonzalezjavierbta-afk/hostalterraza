#!/usr/bin/env node
/*
 * generar-log-uso.js — Genera el reporte de tareas y uso de opencode
 * (Regla General de Auditoría de Uso del Sistema QR Hostal Terraza).
 *
 * Fuente: base local de opencode (~/.local/share/opencode/opencode.db).
 * Sin dependencias externas (usa node:sqlite incluido en Node >= 22.5).
 *
 * Uso:
 *   node generar-log-uso.js --5h          → ventana de 5 horas
 *   node generar-log-uso.js --dia         → ventana de 24 horas
 *   node generar-log-uso.js --semana      → ventana de 7 días
 *   node generar-log-uso.js --mes         → ventana de 30 días
 *   node generar-log-uso.js --horas N     → ventana personalizada
 *   node generar-log-uso.js --all         → genera los 4 reportes
 *   node generar-log-uso.js --stdout      → imprime en consola (sin guardar)
 *   node generar-log-uso.js --db <path>   → ruta alternativa de la base
 *
 * Salida: logs/uso/YYYY-MM-DD_HHmm_<etiqueta>.md
 */
'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');

// Suprime el warning experimental de node:sqlite (Node < 24 imprime un aviso).
const emitWarning = process.emitWarning;
process.emitWarning = (warning, ...args) => {
  if (String(warning).includes('SQLite')) return;
  emitWarning.call(process, warning, ...args);
};

const { DatabaseSync } = require('node:sqlite');

const WINDOWS = {
  '5h': 5 * 3600 * 1000,
  'dia': 24 * 3600 * 1000,
  'semana': 7 * 24 * 3600 * 1000,
  'mes': 30 * 24 * 3600 * 1000,
};

const LABEL = { '5h': '5h', dia: 'dia', semana: 'semana', mes: 'mes' };

function parseArgs(argv) {
  const args = { windows: [], stdout: false, db: null, hours: null };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--stdout') args.stdout = true;
    else if (a === '--db') args.db = argv[++i];
    else if (a === '--all') args.windows = Object.keys(WINDOWS);
    else if (a === '--horas') args.hours = parseInt(argv[++i], 10);
    else if (WINDOWS[a]) args.windows.push(a);
    else if (a === '--5h') args.windows.push('5h');
    else if (a === '--dia') args.windows.push('dia');
    else if (a === '--semana') args.windows.push('semana');
    else if (a === '--mes') args.windows.push('mes');
    else if (a && !a.startsWith('-')) { /* ignorar posicional */ }
    else { console.error('Argumento desconocido: ' + a); process.exit(1); }
  }
  if (args.windows.length === 0 && args.hours != null) {
    args.windows.push('horas');
    WINDOWS.horas = args.hours * 3600 * 1000;
    LABEL.horas = 'horas' + args.hours;
  }
  if (args.windows.length === 0) args.windows = ['5h'];
  return args;
}

function defaultDbPath() {
  return path.join(os.homedir(), '.local', 'share', 'opencode', 'opencode.db');
}

function openDb(dbPath) {
  if (!fs.existsSync(dbPath)) {
    console.error('ERROR: No se encontró la base de opencode en: ' + dbPath);
    console.error('Verifica la ruta o usa --db <ruta>.');
    process.exit(1);
  }
  return new DatabaseSync(dbPath, { readOnly: true });
}

function parseModel(raw) {
  if (!raw) return 'desconocido';
  try {
    const o = typeof raw === 'string' ? JSON.parse(raw) : raw;
    return (o && o.id) || 'desconocido';
  } catch (e) {
    return typeof raw === 'string' ? raw : 'desconocido';
  }
}

function fmtCost(n) { return '$' + (n || 0).toFixed(4); }

function buildReport(db, windowMs, label, now) {
  const since = now - windowMs;
  const sessions = db.prepare(
    "SELECT id, parent_id, title, agent, model, cost, tokens_input, tokens_output, tokens_reasoning, time_created, time_updated FROM session WHERE (time_created >= ? OR time_updated >= ?) ORDER BY time_created"
  ).all(since, since);

  if (sessions.length === 0) {
    return { sessions: [], text: 'No hay sesiones en la ventana solicitada.\n' };
  }

  const ids = sessions.map(s => s.id);
  const ph = ids.map(() => '?').join(',');
  const parts = db.prepare("SELECT session_id, data FROM part WHERE session_id IN (" + ph + ")").all(...ids);
  const msgs = db.prepare("SELECT session_id, data FROM message WHERE session_id IN (" + ph + ")").all(...ids);

  const toolCount = {};
  const toolBySession = {};
  const subagents = {};
  const skills = [];
  const statusCount = {};
  const modelAgg = {};
  const userMsgs = {};
  const assistantMsgs = {};

  for (const s of sessions) {
    const m = parseModel(s.model);
    if (!modelAgg[m]) modelAgg[m] = { sessions: 0, cost: 0, in: 0, out: 0, re: 0 };
    modelAgg[m].sessions++;
    modelAgg[m].cost += s.cost || 0;
    modelAgg[m].in += s.tokens_input || 0;
    modelAgg[m].out += s.tokens_output || 0;
    modelAgg[m].re += s.tokens_reasoning || 0;
  }

  for (const p of parts) {
    let d;
    try { d = JSON.parse(p.data); } catch (e) { continue; }
    if (d && d.type === 'tool' && typeof d.tool === 'string') {
      const name = d.tool;
      toolCount[name] = (toolCount[name] || 0) + 1;
      if (!toolBySession[p.session_id]) toolBySession[p.session_id] = {};
      toolBySession[p.session_id][name] = (toolBySession[p.session_id][name] || 0) + 1;
      if (d.state && d.state.status) statusCount[d.state.status] = (statusCount[d.state.status] || 0) + 1;
      if (name === 'task' && d.state && d.state.input) {
        const sub = d.state.input.subagent_type || '(sin tipo)';
        subagents[sub] = (subagents[sub] || 0) + 1;
      }
      if (name === 'skill' && d.state && d.state.input && d.state.input.name) {
        skills.push(d.state.input.name);
      }
    }
  }

  for (const m of msgs) {
    let d;
    try { d = JSON.parse(m.data); } catch (e) { continue; }
    const role = d && (d.role || (d.info && d.info.role));
    if (role === 'user') userMsgs[m.session_id] = (userMsgs[m.session_id] || 0) + 1;
    if (role === 'assistant') assistantMsgs[m.session_id] = (assistantMsgs[m.session_id] || 0) + 1;
  }

  // ---- Secciones del reporte ----
  const L = [];
  const desde = new Date(since);
  const hasta = new Date(now);

  L.push('# Log de Tareas y Uso — ' + label);
  L.push('');
  L.push('> Generado: ' + new Date(now).toLocaleString() + '');
  L.push('> Ventana: **' + label + '** (' + desde.toLocaleString() + ' → ' + hasta.toLocaleString() + ')');
  L.push('> Proyecto: Sistema QR Hostal Terraza. Sesiones: ' + sessions.length + '.');
  L.push('');

  // 1) Modelos
  const totalCost = Object.values(modelAgg).reduce((a, v) => a + v.cost, 0);
  const totalIn = Object.values(modelAgg).reduce((a, v) => a + v.in, 0);
  const totalOut = Object.values(modelAgg).reduce((a, v) => a + v.out, 0);
  L.push('## 1. IAs usadas, costo y porcentaje');
  L.push('');
  L.push('| Modelo | Sesiones | Costo | % costo | Tokens in | Tokens out |');
  L.push('|---|---|---|---|---|---|');
  const mRows = Object.entries(modelAgg).sort((a, b) => b[1].cost - a[1].cost);
  for (const [m, v] of mRows) {
    const pct = totalCost > 0 ? (100 * v.cost / totalCost).toFixed(1) + '%' : '0%';
    L.push('| `' + m + '` | ' + v.sessions + ' | ' + fmtCost(v.cost) + ' | ' + pct + ' | ' + v.in.toLocaleString() + ' | ' + v.out.toLocaleString() + ' |');
  }
  L.push('| **Total** | **' + sessions.length + '** | **' + fmtCost(totalCost) + '** | 100% | **' + totalIn.toLocaleString() + '** | **' + totalOut.toLocaleString() + '** |');
  L.push('');

  // 2) Herramientas
  const toolRows = Object.entries(toolCount).sort((a, b) => b[1] - a[1]);
  const toolTotal = toolRows.reduce((a, [, c]) => a + c, 0);
  L.push('## 2. Uso de herramientas');
  L.push('');
  L.push('| Herramienta | Llamadas | % del total |');
  L.push('|---|---|---|');
  for (const [t, c] of toolRows) {
    L.push('| `' + t + '` | ' + c + ' | ' + (100 * c / toolTotal).toFixed(1) + '% |');
  }
  L.push('| **Total** | **' + toolTotal + '** | 100% |');
  const statusLine = Object.entries(statusCount).map(([s, c]) => s + ': ' + c).join(', ');
  if (statusLine) L.push('');
  if (statusLine) L.push('Estado de llamadas: ' + statusLine + '.');
  L.push('');

  // 3) Sub-agentes y skills
  L.push('## 3. Sub-agentes y skills');
  L.push('');
  const subRows = Object.entries(subagents).sort((a, b) => b[1] - a[1]);
  if (subRows.length) {
    L.push('| Sub-agente | Tareas |');
    L.push('|---|---|');
    for (const [s, c] of subRows) L.push('| `' + s + '` | ' + c + ' |');
  } else {
    L.push('No se invocaron sub-agentes en la ventana.');
  }
  L.push('');
  if (skills.length) {
    const skillCounts = {};
    skills.forEach(s => { skillCounts[s] = (skillCounts[s] || 0) + 1; });
    L.push('Skills usados: ' + Object.entries(skillCounts).map(([s, c]) => '`' + s + '`×' + c).join(', ') + '.');
  } else {
    L.push('No se usaron skills en la ventana.');
  }
  L.push('');

  // 4) Sesiones
  L.push('## 4. Sesiones por duración');
  L.push('');
  L.push('| Duración | Agente | Costo | Modelo | Título |');
  L.push('|---|---|---|---|---|');
  const sRows = sessions.slice().sort((a, b) => (b.time_updated - b.time_created) - (a.time_updated - a.time_created));
  for (const s of sRows) {
    const durMin = Math.round((s.time_updated - s.time_created) / 60000);
    const m = parseModel(s.model);
    L.push('| ' + durMin + ' min | `' + (s.agent || '?') + '` | ' + fmtCost(s.cost) + ' | ' + m + ' | ' + String(s.title || '(sin título)').slice(0, 60) + ' |');
  }
  L.push('');

  // 5) Detalle de tools por sesión
  L.push('## 5. Detalle de herramientas por sesión');
  L.push('');
  L.push('<details><summary>Ver detalle</summary>');
  L.push('');
  for (const s of sRows) {
    const tb = toolBySession[s.id] || {};
    const top = Object.entries(tb).sort((a, b) => b[1] - a[1]).map(([t, c]) => '`' + t + '`×' + c).join(', ');
    const um = userMsgs[s.id] || 0;
    const am = assistantMsgs[s.id] || 0;
    L.push('- **' + String(s.title || '(sin título)').slice(0, 60) + '** — msgs: ' + um + 'U/' + am + 'A — ' + (top || 'sin tools'));
  }
  L.push('');
  L.push('</details>');
  L.push('');

  // Notas
  L.push('---');
  L.push('### Notas metodológicas');
  L.push('- Ventana: time_created o time_updated dentro del rango solicitado.');
  L.push('- `cost` y tokens provienen de la tabla `session` de opencode (acumulados, incluidas sub-sesiones de sub-agentes).');
  L.push('- Las sesiones iniciadas antes de la ventana pero actualizadas dentro de ella se incluyen con su duración completa.');
  L.push('');
  L.push('_Generado por `.agents/scripts/generar-log-uso.js`._');
  L.push('');

  return { sessions, text: L.join('\n') };
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const dbPath = args.db || defaultDbPath();
  const db = openDb(dbPath);
  const now = Date.now();

  let wroteAny = false;
  for (const label of args.windows) {
    const win = WINDOWS[label];
    const { text } = buildReport(db, win, label, now);
    if (args.stdout) {
      console.log(text);
      continue;
    }
    const dir = path.join(path.resolve(__dirname, '..', '..'), 'logs', 'uso');
    fs.mkdirSync(dir, { recursive: true });
    const stamp = new Date(now);
    const pad = n => String(n).padStart(2, '0');
    const file = stamp.getFullYear() + '-' + pad(stamp.getMonth() + 1) + '-' + pad(stamp.getDate())
      + '_' + pad(stamp.getHours()) + pad(stamp.getMinutes()) + '_' + LABEL[label] + '.md';
    const out = path.join(dir, file);
    fs.writeFileSync(out, text, 'utf8');
    console.log('Reporte guardado: ' + out);
    wroteAny = true;
  }
  db.close();
  if (!wroteAny && !args.stdout) console.log('Nada que escribir.');
}

main();