#!/usr/bin/env node
'use strict';

/*
 * scripts/session_close.js
 * ---------------------------------------------------------------------------
 * Genera el INFORME DE CIERRE obligatorio de una sesion de implementacion.
 *
 * Reutiliza scripts/usage_report.js (NO lo reimplementa ni lo modifica): lo
 * invoca con child_process.spawnSync usando el mismo ejecutable de Node.
 *
 * USO:
 *   node scripts/session_close.js [--root <sessionId>] [--since <ms|fecha>]
 *   node scripts/session_close.js [--budget [N]] [--umbral N]
 *       [--est-tokens N] [--est-turnos N] [--est-seg N]
 *   node scripts/session_close.js -h | --help
 *
 * ALCANCE:
 *   Sin --root ni --since mide el DIA LOCAL actual (lo resuelve usage_report).
 *   Con --root mide esa sesion + todos sus descendientes (parent_id).
 *   Con --since acota el inicio; puede combinarse con --root.
 *
 * ANADIDOS (2026-10-02, sin romper la interfaz previa):
 *   --budget [N]   Seccion "Presupuesto de turnos por subagente": por cada
 *                  subagente (sesion con es_raiz = false) turnos,
 *                  turnos/presupuesto contra el umbral (default 18) y
 *                  veredicto OK (<= umbral) o EXCEDIDO, con el mismo estilo
 *                  de alerta "[!] Agente X: N turnos (> 18)" de la seccion 3.
 *   --umbral N     Umbral de turnos por subagente (default 18).
 *   --est-* N      Estimacion explicita para rellenar "Estimado vs real".
 *                  Sin --est-*, con --budget se usa el presupuesto normativo
 *                  (umbral x subagentes); si no hay data, se declara.
 *   Ninguno de estos flags es obligatorio: sin ellos el informe es el de antes.
 *
 * FUENTES:
 *   1) node scripts/usage_report.js --json [filtros]  -> balance + por agente.
 *   2) node scripts/usage_report.js --tree [filtros]  -> arbol de subagentes
 *      (solo cuando hay --root; best-effort).
 *   Nota: en usage_report --tree y --json son modos MUTUAMENTE EXCLUYENTES,
 *   por eso el desglose por subagente se obtiene de sessions/by_agent del JSON
 *   (que ya trae parent_id y es_raiz) y el arbol se pide como salida aparte.
 *
 * SALIDA: Markdown por stdout.
 *
 * TOLERANCIA A FALLOS:
 *   Si usage_report.js no existe, falla o no hay node:sqlite, imprime el
 *   informe con los datos disponibles y SALE 0. Nunca lanza.
 *
 * ASCII-safe: solo bytes < 128, sin emojis, sin backticks. Sin dependencias.
 * ---------------------------------------------------------------------------
 */

var fs = require('node:fs');
var path = require('node:path');
var child_process = require('node:child_process');

var REPORT = path.join(__dirname, 'usage_report.js');

/* Umbrales del informe de cierre (Mandato 17-18). */
var TURN_ALERT = 25;          /* > 25 turnos por agente */
var TOKENS_PER_TURN_ALERT = 50000; /* > 50000 tokens/turno por agente */
var ORCH_CACHE_PER_TURN_OK = 50000; /* orquestador OK si cache_read/turno < 50000 */

/* Presupuesto de turnos por SUBAGENTE (--budget). Tope duro del agente = 25;
   el umbral de presupuesto por subagente es 18 (OK <= 18 / EXCEDIDO > 18). */
var SUBAGENT_TURN_BUDGET = 18;

/* ----------------------------- utilidades ------------------------------- */

function num(v) { var n = Number(v); return isFinite(n) ? n : 0; }

function fmtInt(v) {
  var n = Math.round(num(v));
  var neg = n < 0; n = Math.abs(n);
  var s = String(n); var out = '';
  while (s.length > 3) { out = ',' + s.slice(s.length - 3) + out; s = s.slice(0, s.length - 3); }
  return (neg ? '-' : '') + s + out;
}

function fmt1(v) { return String(Math.round(num(v) * 10) / 10); }

function fmtMs(ms) {
  if (!ms) return '';
  var d = new Date(num(ms));
  function z(n) { return n < 10 ? '0' + n : String(n); }
  return d.getFullYear() + '-' + z(d.getMonth() + 1) + '-' + z(d.getDate()) + ' ' +
    z(d.getHours()) + ':' + z(d.getMinutes());
}

function sum(arr, get) {
  var t = 0;
  for (var i = 0; i < arr.length; i++) t += num(get(arr[i]));
  return t;
}

function esc(v) { return String(v == null ? '' : v).replace(/\|/g, '/'); }

/* --------------------------- invocacion CLI ----------------------------- */

/*
 * Llama a usage_report.js con los argumentos dados. Devuelve:
 *   { ok: true, code: 0, stdout: '<texto>' }
 *   { ok: false, code: N, error: '<motivo>' }
 * Nunca lanza: cualquier fallo se traduce a ok:false.
 */
function runReport(args) {
  if (!fs.existsSync(REPORT)) {
    return { ok: false, code: -1, error: 'no existe ' + REPORT };
  }
  var res;
  try {
    res = child_process.spawnSync(process.execPath, [REPORT].concat(args), {
      encoding: 'utf8',
      maxBuffer: 64 * 1024 * 1024
    });
  } catch (e) {
    return { ok: false, code: -2, error: (e && e.message) ? e.message : String(e) };
  }
  if (res.error) {
    return { ok: false, code: -3, error: (res.error && res.error.message) ? res.error.message : String(res.error) };
  }
  var out = (res.stdout == null) ? '' : String(res.stdout);
  if (res.status !== 0) {
    var err = (res.stderr == null) ? '' : String(res.stderr).trim();
    return { ok: false, code: res.status, stdout: out, error: err || ('usage_report salio con codigo ' + res.status) };
  }
  return { ok: true, code: 0, stdout: out };
}

/* Llama a usage_report --json y parsea. Devuelve null si algo falla. */
function fetchJson(filterArgs) {
  var r = runReport(['--json'].concat(filterArgs));
  if (!r.ok) return { json: null, error: r.error || 'fallo --json' };
  var text = String(r.stdout || '').trim();
  if (!text) return { json: null, error: 'salida JSON vacia' };
  var from = text.indexOf('{');
  if (from > 0) text = text.slice(from);
  try {
    return { json: JSON.parse(text), error: null };
  } catch (e) {
    return { json: null, error: 'JSON invalido: ' + ((e && e.message) ? e.message : String(e)) };
  }
}

/* ------------------------------- agregados ------------------------------ */

function aggregateByAgent(sessions) {
  var map = {};
  for (var i = 0; i < sessions.length; i++) {
    var s = sessions[i];
    var a = s.agent || '(sin agente)';
    if (!map[a]) map[a] = { agent: a, sessions: 0, turns: 0, total: 0, cache_read: 0, seg: 0 };
    var o = map[a];
    o.sessions++;
    o.turns += num(s.turns);
    o.total += num(s.total);
    o.cache_read += num(s.tokens_cache_read);
    o.seg += num(s.seg);
  }
  var arr = Object.keys(map).map(function (k) {
    var o = map[k];
    o.tokens_por_turno = o.turns > 0 ? o.total / o.turns : 0;
    o.cache_por_turno = o.turns > 0 ? o.cache_read / o.turns : 0;
    return o;
  });
  arr.sort(function (a, b) { return b.total - a.total; });
  return arr;
}

function buildBalance(json) {
  var sessions = (json && json.sessions) ? json.sessions : [];
  var t = (json && json.totals) ? json.totals : {};
  var turnos = sum(sessions, function (s) { return s.turns; });
  var seg = sum(sessions, function (s) { return s.seg; });
  var total = (t.total != null) ? num(t.total) : sum(sessions, function (s) { return s.total; });
  var cacheRead = (t.tokens_cache_read != null)
    ? num(t.tokens_cache_read)
    : sum(sessions, function (s) { return s.tokens_cache_read; });
  return {
    sessions: sessions,
    total_tokens: total,
    turnos: turnos,
    segundos: seg,
    cache_read: cacheRead,
    cache_por_turno: turnos > 0 ? cacheRead / turnos : 0,
    cost: num(t.cost)
  };
}

/*
 * Presupuesto de turnos por subagente (--budget).
 * Un subagente = una sesion con es_raiz === false (parent_id != null).
 * Por cada subagente: turnos, turnos/presupuesto contra el umbral y veredicto
 * OK (turnos <= umbral) o EXCEDIDO (turnos > umbral).
 * Tambien devuelve el rollup por agente (peor subagente + total) que es el
 * patron de alertas ya usado en la seccion 3.
 */
function buildBudget(sessions, threshold) {
  var subs = sessions.filter(function (s) { return s.es_raiz === false; });
  var filas = subs.map(function (s) {
    var t = num(s.turns);
    return {
      agent: s.agent || '(sin agente)',
      id: s.id || '',
      title: s.title || '',
      turns: t,
      umbral: threshold,
      pct: threshold > 0 ? (t / threshold) * 100 : 0,
      excedido: t > threshold,
      total: num(s.total),
      cache_read: num(s.tokens_cache_read)
    };
  });
  filas.sort(function (a, b) { return b.turns - a.turns; });

  var map = {};
  var excedidos = 0;
  for (var i = 0; i < filas.length; i++) {
    var f = filas[i];
    if (!map[f.agent]) {
      map[f.agent] = { agent: f.agent, sesiones: 0, turnos: 0, max_turnos: 0, excedidas: 0, umbral: threshold };
    }
    var o = map[f.agent];
    o.sesiones++;
    o.turnos += f.turns;
    if (f.turns > o.max_turnos) o.max_turnos = f.turns;
    if (f.excedido) { o.excedidas++; excedidos++; }
  }
  var porAgente = Object.keys(map).map(function (k) { return map[k]; });
  porAgente.sort(function (a, b) { return b.max_turnos - a.max_turnos; });

  return {
    umbral: threshold,
    filas: filas,
    por_agente: porAgente,
    subagentes: filas.length,
    excedidos: excedidos,
    /* Tope duro: sesiones que ademas rompieron TURN_ALERT (25). */
    topes_duros: filas.filter(function (f) { return f.turns > TURN_ALERT; }).length
  };
}

function buildOrchestrator(balance) {
  var roots = balance.sessions.filter(function (s) { return s.es_raiz; });
  var cache = 0, turns = 0;
  if (roots.length) {
    cache = sum(roots, function (s) { return s.tokens_cache_read; });
    turns = sum(roots, function (s) { return s.turns; });
  } else {
    cache = balance.cache_read;
    turns = balance.turnos;
  }
  return {
    detected: roots.length > 0,
    cache_read: cache,
    turns: turns,
    cache_por_turno: turns > 0 ? cache / turns : 0
  };
}

/* ------------------------------- render --------------------------------- */

/*
 * Rellena la tabla "Estimado vs real" con la data DISPONIBLE en este mismo
 * informe (regla: si la data esta, se rellena; si no, se marca el flag).
 * Prioridad:
 *   1) Estimacion explicita del usuario: --est-tokens / --est-turnos / --est-seg.
 *   2) Presupuesto normativo derivado de --budget: umbral de turnos por
 *      subagente x numero de subagentes (x umbral de tokens/turno).
 *   3) Sin estimacion: se dice por que (no se inventa el numero).
 */
function estimateRow(opts, balance, budget) {
  var r = { tokens: '', turnos: '', seg: '', tokens_dev: '', turnos_dev: '', seg_dev: '', nota: '' };
  var src = [];

  function put(n, real, esInt) {
    if (n == null || !isFinite(num(n)) || real == null) return null;
    var e = num(n);
    var d = num(real) - e;
    var f = esInt ? fmtInt : fmt1;
    var pct = e !== 0 ? (d / Math.abs(e)) * 100 : 0;
    return f(e) + ' | ' + f(d) + ' (' + (d >= 0 ? '+' : '') + fmt1(pct) + '%)';
  }

  if (opts.estTokens != null) src.push('--est-tokens');
  if (opts.estTurnos != null) src.push('--est-turnos');
  if (opts.estSeg != null) src.push('--est-seg');

  var estT = put(opts.estTokens, balance ? balance.total_tokens : null, true);
  var estTu = put(opts.estTurnos, balance ? balance.turnos : null, true);
  var estS = put(opts.estSeg, balance ? balance.segundos : null, false);

  if (!estT || !estTu) {
    var nSubs = budget ? budget.subagentes : 0;
    var umbral = budget ? budget.umbral : SUBAGENT_TURN_BUDGET;
    if (nSubs > 0) {
      var planTurnos = umbral * nSubs;
      var planTokens = planTurnos * TOKENS_PER_TURN_ALERT;
      if (!estTu) estTu = put(planTurnos, balance ? balance.turnos : null, true);
      if (!estT) estT = put(planTokens, balance ? balance.total_tokens : null, true);
      if (!src.length) {
        src.push('presupuesto normativo: ' + umbral + ' turnos x ' + nSubs +
          ' subagentes = ' + fmtInt(planTurnos) + ' turnos; tokens = ' +
          fmtInt(planTurnos) + ' x ' + fmtInt(TOKENS_PER_TURN_ALERT) + ' tokens/turno');
      }
    }
  }

  if (estT) { r.tokens = estT.split(' | ')[0]; r.tokens_dev = estT.split(' | ')[1]; }
  else r.tokens = '(sin estimacion)';
  if (estTu) { r.turnos = estTu.split(' | ')[0]; r.turnos_dev = estTu.split(' | ')[1]; }
  else r.turnos = '(sin estimacion)';
  if (estS) { r.seg = estS.split(' | ')[0]; r.seg_dev = estS.split(' | ')[1]; }
  else r.seg = '(sin estimacion: no hay umbral de tiempo normativo; usar --est-seg)';

  r.tokens_dev = r.tokens_dev || '(sin estimacion)';
  r.turnos_dev = r.turnos_dev || '(sin estimacion)';
  r.seg_dev = r.seg_dev || '(sin estimacion)';

  r.nota = src.length
    ? src.join(' + ') + '. Para tokens y tiempo usa --est-tokens/--est-turnos/--est-seg.'
    : 'sin estimacion en el reporte: usa --budget (presupuesto normativo) o --est-tokens/--est-turnos/--est-seg. ' +
      'Aprendizajes y consejos siguen siendo humano (seccion 6-7).';
  return r;
}

function scopeLabel(opts) {
  var L = [];
  if (opts.root) L.push('root=' + opts.root + ' (+ descendientes)');
  if (opts.since) L.push('desde ' + opts.since);
  if (!L.length) L.push('dia local actual');
  return L.join('; ');
}

function renderReport(opts, fetched, treeText) {
  var json = fetched.json;
  var L = [];
  L.push('# Informe de cierre de sesion');
  L.push('');
  L.push('- Alcance: ' + esc(scopeLabel(opts)));
  L.push('- Generado: ' + fmtMs(Date.now()));
  if (json && json.db_path) L.push('- DB: ' + esc(json.db_path));
  L.push('');

  if (!json) {
    L.push('> DATOS NO DISPONIBLES: ' + esc(fetched.error || 'usage_report.js no respondio'));
    L.push('> El informe se emite igualmente con secciones para completar a mano.');
    L.push('');
  }

  var balance = json ? buildBalance(json) : null;
  var byAgent = json ? aggregateByAgent(balance.sessions) : [];
  var orch = json ? buildOrchestrator(balance) : null;
  var budgetForReport = (opts.budget && json)
    ? buildBudget(balance.sessions, num(opts.umbral) > 0 ? num(opts.umbral) : SUBAGENT_TURN_BUDGET)
    : null;

  /* 1. Balance de gasto */
  L.push('## 1. Balance de gasto');
  L.push('');
  if (balance) {
    L.push('| Metrica | Valor |');
    L.push('|---|---|');
    L.push('| total_tokens | ' + fmtInt(balance.total_tokens) + ' |');
    L.push('| turnos | ' + fmtInt(balance.turnos) + ' |');
    L.push('| segundos | ' + fmt1(balance.segundos) + ' |');
    L.push('| cache_read | ' + fmtInt(balance.cache_read) + ' |');
    L.push('| cache_read / turno | ' + fmtInt(balance.cache_por_turno) + ' |');
    L.push('| sesiones | ' + fmtInt(balance.sessions.length) + ' |');
    L.push('');
  } else {
    L.push('(sin datos; completar a mano)');
    L.push('');
  }

  /* 2. Desglose por agente */
  L.push('## 2. Desglose por agente');
  L.push('');
  if (byAgent.length) {
    L.push('| Agente | Turnos | Tokens | Tokens/turno | cache_read/turno |');
    L.push('|---|---|---|---|---|');
    for (var i = 0; i < byAgent.length; i++) {
      var a = byAgent[i];
      var flag = (a.turns > TURN_ALERT || a.tokens_por_turno > TOKENS_PER_TURN_ALERT) ? '[!] ' : '';
      L.push('| ' + flag + esc(a.agent) + ' | ' + fmtInt(a.turns) + ' | ' + fmtInt(a.total) +
        ' | ' + fmtInt(a.tokens_por_turno) + ' | ' + fmtInt(a.cache_por_turno) + ' |');
    }
    L.push('');
  } else {
    L.push('(sin datos de agentes; completar a mano)');
    L.push('');
  }

  /* 3. Alertas de umbral */
  L.push('## 3. Alertas de umbral');
  L.push('');
  var alerts = [];
  for (var j = 0; j < byAgent.length; j++) {
    var b = byAgent[j];
    if (b.turns > TURN_ALERT) {
      alerts.push('- [!] Agente "' + esc(b.agent) + '": ' + fmtInt(b.turns) +
        ' turnos (> ' + TURN_ALERT + '). Replanificar / dividir dominio.');
    }
    if (b.tokens_por_turno > TOKENS_PER_TURN_ALERT) {
      alerts.push('- [!] Agente "' + esc(b.agent) + '": ' + fmtInt(b.tokens_por_turno) +
        ' tokens/turno (> ' + fmtInt(TOKENS_PER_TURN_ALERT) + '). Contexto por turno excesivo.');
    }
  }
  if (alerts.length) {
    for (var k = 0; k < alerts.length; k++) L.push(alerts[k]);
  } else {
    L.push('- Sin agentes sobre umbral (turnos <= ' + TURN_ALERT +
      ' y tokens/turno <= ' + fmtInt(TOKENS_PER_TURN_ALERT) + ').');
  }
  if (orch) {
    if (orch.turns <= 0) {
      L.push('- Orquestador: sin turnos en el alcance (cache_read/turno no calculable).');
    } else {
      var ok = orch.cache_por_turno < ORCH_CACHE_PER_TURN_OK;
      L.push('- ' + (ok ? '' : '[!] ') + 'Orquestador cache_read/turno = ' + fmtInt(orch.cache_por_turno) +
        ' -> ' + (ok ? 'OK' : 'ATENCION') + ' (< ' + fmtInt(ORCH_CACHE_PER_TURN_OK) + ' = OK)' +
        (orch.detected ? '' : ' [sin sesion raiz; se uso el total]'));
    }
  }
  L.push('');

  if (treeText) {
    L.push('## Arbol de subagentes (usage_report --tree)');
    L.push('');
    L.push('    ' + String(treeText).replace(/\r?\n/g, '\n    ').replace(/\s+$/, ''));
    L.push('');
  }

  if (opts.budget && budgetForReport) {
    var b = budgetForReport;
    L.push('## 4. Presupuesto de turnos por subagente (umbral ' + b.umbral + ')');
    L.push('');
    L.push('- Subagentes en el alcance: ' + fmtInt(b.subagentes) +
      ' (sesiones con es_raiz = false del JSON de usage_report).');
    L.push('- Umbral: ' + b.umbral + ' turnos por subagente -> OK si <= ' + b.umbral +
      ', EXCEDIDO si > ' + b.umbral + '. Tope duro del agente: ' + TURN_ALERT + '.');
    L.push('- Resultado: ' + fmtInt(b.subagentes - b.excedidos) + ' OK, ' +
      fmtInt(b.excedidos) + ' EXCEDIDO' +
      (b.topes_duros ? ' (' + fmtInt(b.topes_duros) + ' sobre el tope duro ' + TURN_ALERT + ')' : '') + '.');
    L.push('');
    if (b.filas.length) {
      L.push('| Agente | Sesion | Turnos | Presupuesto | % | Veredicto |');
      L.push('|---|---|---|---|---|---|');
      for (var f = 0; f < b.filas.length; f++) {
        var r = b.filas[f];
        L.push('| ' + (r.excedido ? '[!] ' : '') + esc(r.agent) + ' | ' + esc(r.id) + ' | ' +
          fmtInt(r.turns) + ' | ' + fmtInt(r.umbral) + ' | ' + fmt1(r.pct) + '% | ' +
          (r.excedido ? 'EXCEDIDO' : 'OK') + ' |');
      }
      L.push('');
      L.push('| Agente | Subagentes | Turnos (suma) | Peor subagente | Turnos/presupuesto | Veredicto |');
      L.push('|---|---|---|---|---|---|');
      for (var g = 0; g < b.por_agente.length; g++) {
        var pa = b.por_agente[g];
        var excede = pa.max_turnos > pa.umbral;
        L.push('| ' + (excede ? '[!] ' : '') + esc(pa.agent) + ' | ' + fmtInt(pa.sesiones) + ' | ' +
          fmtInt(pa.turnos) + ' | ' + fmtInt(pa.max_turnos) + ' | ' + fmt1(pa.umbral > 0 ? (pa.max_turnos / pa.umbral) * 100 : 0) +
          '% | ' + (excede ? 'EXCEDIDO' : 'OK') + ' |');
      }
      L.push('');
    } else {
      L.push('- Sin subagentes en el alcance (usa --root <sessionId> o --since para acotar).');
      L.push('');
    }
    var bAlerts = [];
    for (var h = 0; h < b.filas.length; h++) {
      var w = b.filas[h];
      if (w.excedido) {
        bAlerts.push('- [!] Subagente "' + esc(w.agent) + '" [' + esc(w.id) + ']: ' +
          fmtInt(w.turns) + ' turnos (> ' + w.umbral + ') -> EXCEDIDO (' +
          fmt1(w.umbral > 0 ? w.turns / w.umbral : 0) + 'x presupuesto). Replanificar / acortar el brief.');
      }
    }
    for (var m = 0; m < bAlerts.length; m++) L.push(bAlerts[m]);
    if (!bAlerts.length) {
      L.push('- Sin subagentes sobre el umbral de presupuesto (' + b.umbral + ' turnos).');
    }
    L.push('');
  } else if (opts.budget) {
    L.push('## 4. Presupuesto de turnos por subagente (umbral ' + SUBAGENT_TURN_BUDGET + ')');
    L.push('');
    L.push('- (sin datos de usage_report.js; no se puede medir el presupuesto de subagentes)');
    L.push('');
  }

  /* 5-7. Plantillas obligatorias */
  L.push('## 5. Estimado vs real (Mandato 19)');
  L.push('');
  var est = estimateRow(opts, balance, budgetForReport);
  L.push('| Concepto | Estimado | Real | Desviacion |');
  L.push('|---|---|---|---|');
  L.push('| Tokens | ' + est.tokens + ' | ' + (balance ? fmtInt(balance.total_tokens) : '(completar)') + ' | ' + est.tokens_dev + ' |');
  L.push('| Turnos | ' + est.turnos + ' | ' + (balance ? fmtInt(balance.turnos) : '(completar)') + ' | ' + est.turnos_dev + ' |');
  L.push('| Tiempo (s) | ' + est.seg + ' | ' + (balance ? fmt1(balance.segundos) : '(completar)') + ' | ' + est.seg_dev + ' |');
  L.push('');
  L.push('- Base estimada: ' + est.nota);
  L.push('');
  L.push('## 6. Aprendizajes');
  L.push('');
  L.push('- (completar: que se releyo de mas, que agente fallo, que brief falto)');
  L.push('');
  L.push('## 7. Consejos de mejora');
  L.push('');
  L.push('- (completar: 1-3 acciones concretas para la siguiente sesion)');
  L.push('');

  return L.join('\n');
}

/* -------------------------------- CLI ----------------------------------- */

function parseArgs(argv) {
  var o = {
    root: null, since: null, help: false,
    budget: false, umbral: null,
    estTokens: null, estTurnos: null, estSeg: null
  };
  var i = 0;
  function needValue(flag) {
    if (i >= argv.length) return null;
    return argv[i++];
  }
  while (i < argv.length) {
    var a = argv[i++];
    var val = null;
    if (a.length > 2 && a.slice(0, 2) === '--' && a.indexOf('=') > 1) {
      var eq = a.indexOf('=');
      val = a.slice(eq + 1);
      a = a.slice(0, eq);
    }
    if (a === '--help' || a === '-h' || a === 'help') { o.help = true; }
    else if (a === '--root') { o.root = (val !== null ? val : needValue('--root')); }
    else if (a === '--since') { o.since = (val !== null ? val : needValue('--since')); }
    else if (a === '--budget') {
      o.budget = true;
      if (val !== null) o.umbral = val;
      else if (argv[i] !== undefined && /^[0-9]+$/.test(String(argv[i]))) o.umbral = needValue('--budget');
    }
    else if (a === '--umbral') { o.umbral = (val !== null ? val : needValue('--umbral')); }
    else if (a === '--est-tokens') { o.estTokens = (val !== null ? val : needValue('--est-tokens')); }
    else if (a === '--est-turnos') { o.estTurnos = (val !== null ? val : needValue('--est-turnos')); }
    else if (a === '--est-seg') { o.estSeg = (val !== null ? val : needValue('--est-seg')); }
    else { /* opcion desconocida: se ignora para no romper la sesion */ }
  }
  return o;
}

function helpText() {
  var L = [];
  L.push('session_close.js - Informe de cierre de sesion (Markdown).');
  L.push('');
  L.push('Uso:');
  L.push('  node scripts/session_close.js [--root <sessionId>] [--since <ms|fecha>]');
  L.push('  node scripts/session_close.js [--budget [N]] [--umbral N]');
  L.push('      [--est-tokens N] [--est-turnos N] [--est-seg N]');
  L.push('  node scripts/session_close.js -h | --help');
  L.push('');
  L.push('Opciones:');
  L.push('  --root <sessionId>   Mide esa sesion + sus descendientes (parent_id).');
  L.push('  --since <ms|fecha>   Acota el inicio (epoch ms o fecha ISO).');
  L.push('                       Sin filtros mide el DIA LOCAL actual.');
  L.push('  --budget [N]         Seccion de presupuesto por SUBAGENTE: turnos,');
  L.push('                       turnos/presupuesto y veredicto OK/EXCEDIDO.');
  L.push('                       Umbral por defecto: ' + SUBAGENT_TURN_BUDGET +
    ' turnos (OK <= ' + SUBAGENT_TURN_BUDGET + ').');
  L.push('  --umbral N           Umbral de turnos por subagente (default ' + SUBAGENT_TURN_BUDGET + ').');
  L.push('  --est-tokens N       Tokens estimados -> rellena "Estimado vs real".');
  L.push('  --est-turnos N       Turnos estimados -> rellena "Estimado vs real".');
  L.push('  --est-seg N          Segundos estimados -> rellena "Estimado vs real".');
  L.push('                       Sin --est-*, con --budget se usa el presupuesto');
  L.push('                       normativo; si no hay data, se dice (no se inventa).');
  L.push('  -h, --help           Esta ayuda.');
  L.push('');
  L.push('Delega en scripts/usage_report.js (--json y, con --root, --tree).');
  L.push('Salida: Markdown por stdout. Siempre sale 0 (tolerante a fallos).');
  return L.join('\n');
}

/* --------------------------------- main --------------------------------- */

function main() {
  var opts = parseArgs(process.argv.slice(2));
  if (opts.help) {
    process.stdout.write(helpText() + '\n');
    return;
  }

  var filterArgs = [];
  if (opts.root) filterArgs.push('--root', opts.root);
  if (opts.since) filterArgs.push('--since', opts.since);

  var fetched;
  try {
    fetched = fetchJson(filterArgs);
  } catch (e) {
    fetched = { json: null, error: (e && e.message) ? e.message : String(e) };
  }

  var treeText = '';
  if (opts.root) {
    try {
      var tr = runReport(['--tree'].concat(filterArgs));
      if (tr.ok && tr.stdout) treeText = String(tr.stdout).trim();
    } catch (e2) { treeText = ''; }
  }

  var md;
  try {
    md = renderReport(opts, fetched, treeText);
  } catch (e3) {
    md = '# Informe de cierre de sesion\n\n> Error al renderizar: ' +
      ((e3 && e3.message) ? e3.message : String(e3)) + '\n';
  }
  process.stdout.write(md + '\n');
}

try {
  main();
} catch (e) {
  process.stderr.write('AVISO session_close: ' + ((e && e.message) ? e.message : String(e)) + '\n');
}
process.exitCode = 0;
