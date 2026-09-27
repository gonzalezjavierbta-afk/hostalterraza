#!/usr/bin/env node
'use strict';

/*
 * scripts/usage_report.js
 * ---------------------------------------------------------------------------
 * Reporte y export de uso (tokens / costo / tiempo) de OpenCode.
 *
 * Lee opencode.db (SQLite) SIEMPRE en modo solo lectura, usando el modulo
 * built-in node:sqlite (DatabaseSync). Sin dependencias externas.
 *
 * ALCANCE POR DEFECTO:
 *   Sin filtros, el reporte cubre el DIA LOCAL actual (00:00 -> ahora).
 *   En cuanto se pasa --since/--until/--project/--agent/--root, ese filtro
 *   manda sobre TODO el historico. Usa --since 0 para todo el historico.
 *
 * SEGURIDAD (NO NEGOCIABLE):
 *   - La base se abre con { readOnly: true }.
 *   - NUNCA se leen, listan ni exportan las tablas:
 *       account, control_account, credential
 *     (contienen access_token, refresh_token, JWT). Este script solo consulta
 *     las tablas: session, message, part, project.
 *   - Con --with-content TODO texto pasa por redact() ANTES de truncar:
 *     enmascara tokens (sk-, sk-proj-, sk_live_/rk_live_/pk_live_, xoxb-,
 *     xapp-, ghp_, gho_, glpat-, npm_, AKIA, AIza), Bearer y Authorization,
 *     JWT, URLs de conexion (postgres/mysql/mongodb/redis), pares
 *     CLAVE=VALOR sensibles (*_KEY/_SECRET/_TOKEN/_PASSWORD), blobs
 *     data:...;base64, y rutas de usuario
 *     (C:\Users\<n>, C:/Users/<n>, ~).
 *
 * Uso: node scripts/usage_report.js [modo] [opciones]
 * Ver: node scripts/usage_report.js --help
 * ---------------------------------------------------------------------------
 */

var fs = require('node:fs');
var os = require('node:os');
var path = require('node:path');

var SQLITE = null;
try { SQLITE = require('node:sqlite'); } catch (e) { SQLITE = null; }

/* ----------------------------- utilidades ------------------------------- */

function num(v) { var n = Number(v); return isFinite(n) ? n : 0; }
function r1(x) { return Math.round(num(x) * 10) / 10; }
function r2(x) { return Math.round(num(x) * 100) / 100; }
function r8(x) { return Math.round(num(x) * 1e8) / 1e8; }

function fail(msg, code) {
  process.stderr.write('ERROR: ' + msg + '\n');
  process.exit(code || 2);
}

function fmtInt(v) {
  var n = Math.round(num(v));
  var neg = n < 0; n = Math.abs(n);
  var s = String(n); var out = '';
  while (s.length > 3) { out = ',' + s.slice(s.length - 3) + out; s = s.slice(0, s.length - 3); }
  return (neg ? '-' : '') + s + out;
}

function fmtCost(v) { return num(v).toFixed(6); }
function fmtNum1(v) { return String(r1(v)); }

function fmtDate(ms) {
  if (!ms) return '';
  var d = new Date(num(ms));
  function z(n) { return n < 10 ? '0' + n : String(n); }
  return d.getFullYear() + '-' + z(d.getMonth() + 1) + '-' + z(d.getDate()) + ' ' +
    z(d.getHours()) + ':' + z(d.getMinutes());
}

function todayStartMs() {
  var d = new Date();
  return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
}

function parseTime(v, flag) {
  var s = String(v).trim();
  if (/^-?[0-9]+$/.test(s)) return Number(s);
  var t = Date.parse(s);
  if (isNaN(t)) fail('Valor invalido para ' + flag + ': ' + s);
  return t;
}

function parseModel(m) {
  if (!m) return '';
  try {
    var o = JSON.parse(m);
    if (o && typeof o === 'object') {
      var prov = o.providerID || o.provider || '';
      var id = o.id || o.modelID || o.model || '';
      if (prov && id) return prov + '/' + id;
      if (id) return id;
      if (prov) return prov;
    }
  } catch (e) { /* noop */ }
  return String(m);
}

function chunk(arr, size) {
  var out = [];
  for (var i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size));
  return out;
}

function all(db, sql, params) {
  var stmt = db.prepare(sql);
  return stmt.all.apply(stmt, params || []);
}

function truncate(s, max) {
  s = (s == null) ? '' : String(s);
  if (max <= 0 || s.length <= max) return s;
  return s.slice(0, max) + '...[truncated]';
}

/* ------------------------------- redact --------------------------------- */

function redact(s) {
  if (s == null) return s;
  var t = String(s);

  /* PEM private keys */
  t = t.replace(/-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z ]*PRIVATE KEY-----/g,
    '<REDACTED-PRIVATE-KEY>');

  /* data URI base64 blobs */
  t = t.replace(/data:([A-Za-z0-9.+\/-]+);base64,[A-Za-z0-9+\/=]+/g,
    'data:$1;base64,<REDACTED>');

  /* Authorization header */
  t = t.replace(/(Authorization\s*:\s*)[^\r\n]+/gi, '$1<REDACTED>');

  /* Bearer tokens (incluye el caso "... Bearer <...>") */
  t = t.replace(/(Bearer\s+)[^\s\x60]*/gi, '$1<REDACTED>');

  /* URLs de conexion: conservar esquema y marcar ... */
  t = t.replace(/((?:postgres(?:ql)?|mysql|mongodb|redis)(?:\+[A-Za-z0-9]+)?:\/\/)[^\s'"\x60<>,;)\]}]*/gi,
    '$1...');

  /* pares CLAVE=VALOR sensibles (conserva clave, reemplaza valor) */
  t = t.replace(/(DATABASE_URL|PASSWORD|SECRET|API_KEY|TOKEN)(\s*[=:]\s*)([^\s'"]+)/gi,
    '$1$2<REDACTED>');

  /* JWT (3 segmentos base64url) */
  t = t.replace(/eyJ[A-Za-z0-9_\-]*\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+/g, '<REDACTED-JWT>');
  /* reste de blobs que empiezan como cabecera JWT (incluye la notacion eyJ....) */
  t = t.replace(/eyJ[A-Za-z0-9_\-.]{4,}/g, '<REDACTED-JWT>');

  /* tokens de proveedor */
  t = t.replace(/\bsk-proj-[A-Za-z0-9._\-]{3,}/g, '<REDACTED>');
  t = t.replace(/\bsk-[A-Za-z0-9._\-]{3,}/g, '<REDACTED>');
  t = t.replace(/\bxox[baprs]-[A-Za-z0-9_\-]{3,}/g, '<REDACTED>');
  t = t.replace(/\bghp_[A-Za-z0-9]{3,}/g, '<REDACTED>');
  t = t.replace(/\bgho_[A-Za-z0-9]{3,}/g, '<REDACTED>');
  t = t.replace(/\bghs_[A-Za-z0-9]{3,}/g, '<REDACTED>');
  t = t.replace(/\bghu_[A-Za-z0-9]{3,}/g, '<REDACTED>');
  t = t.replace(/\bgithub_pat_[A-Za-z0-9_]{3,}/g, '<REDACTED>');
  t = t.replace(/\bAIza[A-Za-z0-9_\-]{3,}/g, '<REDACTED>');
  t = t.replace(/\bAKIA[0-9A-Z]{16}\b/g, '<REDACTED>');
  t = t.replace(/\b(?:sk|rk|pk)_live_[A-Za-z0-9]{3,}/g, '<REDACTED>');
  t = t.replace(/\bxapp-[A-Za-z0-9_\-]{3,}/g, '<REDACTED>');
  t = t.replace(/\bglpat-[A-Za-z0-9_\-]{3,}/g, '<REDACTED>');
  t = t.replace(/\bnpm_[A-Za-z0-9]{3,}/g, '<REDACTED>');

  /* rutas de usuario */
  t = t.replace(/C:\\Users\\[^\\\/\s"';:]+/gi, 'C:\\Users\\<REDACTED>');
  t = t.replace(/C:\/Users\/[^\/\\\s"';:]+/gi, 'C:/Users/<REDACTED>');
  t = t.replace(/~/g, '<REDACTED>');

  /* pares CLAVE=VALOR genericos (*_KEY, *_SECRET, *_TOKEN, *_PASSWORD) al final
     para no pisar los tokens con prefijo. Conserva la clave, redacta el valor. */
  t = t.replace(/([A-Z0-9_]*(?:KEY|SECRET|TOKEN|PASSWORD))(\s*[=:]\s*)(\S+)/gi,
    '$1$2<REDACTED>');

  return t;
}

/* ------------------------------ consultas ------------------------------- */

function descendants(rows, rootId) {
  var children = {};
  var exists = false;
  for (var i = 0; i < rows.length; i++) {
    var r = rows[i];
    if (r.id === rootId) exists = true;
    var key = r.parent_id || '__root__';
    if (!children[key]) children[key] = [];
    children[key].push(r.id);
  }
  var seen = {}; var out = []; var stack = [rootId];
  while (stack.length) {
    var cur = stack.pop();
    if (seen[cur]) continue;
    seen[cur] = true; out.push(cur);
    var ch = children[cur] || [];
    for (var j = 0; j < ch.length; j++) { if (!seen[ch[j]]) stack.push(ch[j]); }
  }
  return { ids: out, exists: exists };
}

function loadSessions(db, opts) {
  var w = []; var p = [];
  if (opts.effSince != null) { w.push('time_created >= ?'); p.push(opts.effSince); }
  if (opts.effUntil != null) { w.push('time_created <= ?'); p.push(opts.effUntil); }
  if (opts.agent) { w.push('agent = ?'); p.push(opts.agent); }
  if (opts.project) {
    w.push('(project_id = ? OR project_id IN (SELECT id FROM project WHERE name = ? COLLATE NOCASE))');
    p.push(opts.project, opts.project);
  }
  var sql = 'SELECT id,parent_id,project_id,title,agent,model,cost,' +
    'tokens_input,tokens_output,tokens_reasoning,tokens_cache_read,tokens_cache_write,' +
    'time_created,time_updated FROM session';
  if (w.length) sql += ' WHERE ' + w.join(' AND ');
  var rows = all(db, sql, p);
  var rootInfo = null;
  if (opts.root) {
    var map = all(db, 'SELECT id,parent_id FROM session', []);
    rootInfo = descendants(map, opts.root);
    var set = {};
    rootInfo.ids.forEach(function (id) { set[id] = true; });
    rows = rows.filter(function (r) { return set[r.id]; });
  }
  return { rows: rows, rootInfo: rootInfo };
}

function countsBySession(db, table, ids, extra) {
  var map = {};
  if (!ids.length) return map;
  var batches = chunk(ids, 400);
  for (var b = 0; b < batches.length; b++) {
    var ph = batches[b].map(function () { return '?'; }).join(',');
    var sql = 'SELECT session_id AS sid, COUNT(*) AS n FROM ' + table +
      ' WHERE session_id IN (' + ph + ')' + (extra || '') + ' GROUP BY session_id';
    var rows = all(db, sql, batches[b]);
    for (var i = 0; i < rows.length; i++) map[rows[i].sid] = num(rows[i].n);
  }
  return map;
}

function extractPartContent(d, type) {
  if (!d) return '';
  if (type === 'tool') {
    var inp = null;
    if (d.state && d.state.input != null) inp = d.state.input;
    else if (d.input != null) inp = d.input;
    if (inp == null) return '';
    try { return JSON.stringify(inp); } catch (e) { return String(inp); }
  }
  if (d.text != null) return String(d.text);
  try { return JSON.stringify(d); } catch (e) { return ''; }
}

function loadDetail(db, ids, opts) {
  var out = [];
  if (!ids.length) return out;
  var batches = chunk(ids, 400);
  for (var b = 0; b < batches.length; b++) {
    var ph = batches[b].map(function () { return '?'; }).join(',');
    var sql = 'SELECT id, message_id, session_id, time_created, time_updated, data FROM part' +
      ' WHERE session_id IN (' + ph + ') ORDER BY session_id, time_created, id';
    var rows = all(db, sql, batches[b]);
    for (var i = 0; i < rows.length; i++) {
      var row = rows[i]; var d = null;
      try { d = JSON.parse(row.data); } catch (e) { d = null; }
      var type = (d && d.type) ? String(d.type) : 'unknown';
      var tool = (type === 'tool' && d && d.tool) ? String(d.tool) : null;
      var content = extractPartContent(d, type);
      var entry = {
        session_id: row.session_id,
        message_id: row.message_id,
        part_id: row.id,
        type: type,
        tool: tool,
        chars: content.length,
        dur: num(row.time_updated) - num(row.time_created),
        time_created: num(row.time_created)
      };
      if (opts.withContent) entry.content = truncate(redact(content), opts.maxChars);
      out.push(entry);
    }
  }
  return out;
}

/* ------------------------------- metricas ------------------------------- */

function buildMetrics(rows, turnsMap, toolsMap) {
  return rows.map(function (r) {
    var ti = num(r.tokens_input), to = num(r.tokens_output), tr = num(r.tokens_reasoning);
    var tcr = num(r.tokens_cache_read), tcw = num(r.tokens_cache_write);
    var total = ti + to + tr + tcr + tcw;
    var turns = turnsMap[r.id] || 0;
    var tools = toolsMap[r.id] || 0;
    var seg = (r.time_updated && r.time_created) ? r1((num(r.time_updated) - num(r.time_created)) / 1000) : 0;
    return {
      id: r.id,
      parent_id: (r.parent_id == null || r.parent_id === '') ? null : r.parent_id,
      project_id: r.project_id || null,
      title: r.title || '',
      agent: r.agent || '',
      model: parseModel(r.model),
      cost: num(r.cost),
      tokens_input: ti,
      tokens_output: to,
      tokens_reasoning: tr,
      tokens_cache_read: tcr,
      tokens_cache_write: tcw,
      total: total,
      turns: turns,
      tools: tools,
      seg: seg,
      cache_por_turno: turns > 0 ? r2(tcr / turns) : 0,
      pct_cache: total > 0 ? r2(tcr / total * 100) : 0,
      es_raiz: (r.parent_id == null || r.parent_id === ''),
      time_created: num(r.time_created),
      time_updated: num(r.time_updated)
    };
  });
}

function computeTotals(list) {
  var t = {
    sessions: list.length, tokens_input: 0, tokens_output: 0, tokens_reasoning: 0,
    tokens_cache_read: 0, tokens_cache_write: 0, total: 0, cost: 0
  };
  for (var i = 0; i < list.length; i++) {
    var s = list[i];
    t.tokens_input += s.tokens_input;
    t.tokens_output += s.tokens_output;
    t.tokens_reasoning += s.tokens_reasoning;
    t.tokens_cache_read += s.tokens_cache_read;
    t.tokens_cache_write += s.tokens_cache_write;
    t.total += s.total;
    t.cost += s.cost;
  }
  t.cost = r8(t.cost);
  t.pct = {
    input: t.total > 0 ? r2(t.tokens_input / t.total * 100) : 0,
    output: t.total > 0 ? r2(t.tokens_output / t.total * 100) : 0,
    reasoning: t.total > 0 ? r2(t.tokens_reasoning / t.total * 100) : 0,
    cache_read: t.total > 0 ? r2(t.tokens_cache_read / t.total * 100) : 0,
    cache_write: t.total > 0 ? r2(t.tokens_cache_write / t.total * 100) : 0
  };
  return t;
}

function byAgent(list) {
  var m = {};
  list.forEach(function (s) {
    var a = s.agent || '(sin agente)';
    if (!m[a]) m[a] = { agent: a, sessions: 0, total: 0, cost: 0, seg: 0, _turns: 0, _cache: 0 };
    var o = m[a];
    o.sessions++; o.total += s.total; o.cost += s.cost; o.seg += s.seg;
    o._turns += s.turns; o._cache += s.tokens_cache_read;
  });
  var arr = Object.keys(m).map(function (k) {
    var o = m[k];
    return {
      agent: o.agent,
      sessions: o.sessions,
      total: o.total,
      cost: r8(o.cost),
      seg: r1(o.seg),
      cache_por_turno: o._turns > 0 ? r2(o._cache / o._turns) : 0
    };
  });
  arr.sort(function (a, b) { return b.total - a.total; });
  return arr;
}

function warningFor(t) {
  if (t.total > 0 && (t.tokens_cache_read / t.total * 100) > 90) {
    return 'cache_read = ' + r2(t.tokens_cache_read / t.total * 100) +
      '% del total (>90%): el costo real es relectura de contexto, no trabajo nuevo.';
  }
  return null;
}

/* ------------------------------ render ---------------------------------- */

function renderGrid(cols, rows) {
  var widths = [];
  for (var i = 0; i < cols.length; i++) widths.push(String(cols[i].h).length);
  rows.forEach(function (r) {
    for (var i = 0; i < cols.length; i++) {
      var v = String(cols[i].get(r));
      if (v.length > widths[i]) widths[i] = v.length;
    }
  });
  function line(vals) {
    var parts = [];
    for (var i = 0; i < cols.length; i++) {
      var v = String(vals[i]);
      var sp = widths[i] - v.length; if (sp < 0) sp = 0;
      var padding = new Array(sp + 1).join(' ');
      parts.push(cols[i].right ? padding + v : v + padding);
    }
    return parts.join('  ');
  }
  var out = [line(cols.map(function (c) { return c.h; }))];
  out.push(line(widths.map(function (w) { return new Array(w + 1).join('-'); })));
  out.push.apply(out, rows.map(function (r) { return line(cols.map(function (c) { return c.get(r); })); }));
  return out.join('\n');
}

function renderTotals(t) {
  var L = [];
  L.push('TOTALES GLOBALES (' + t.sessions + ' sesiones)');
  L.push('  tokens_input        : ' + fmtInt(t.tokens_input) + '  (' + t.pct.input + '%)');
  L.push('  tokens_output       : ' + fmtInt(t.tokens_output) + '  (' + t.pct.output + '%)');
  L.push('  tokens_reasoning    : ' + fmtInt(t.tokens_reasoning) + '  (' + t.pct.reasoning + '%)');
  L.push('  tokens_cache_read   : ' + fmtInt(t.tokens_cache_read) + '  (' + t.pct.cache_read + '%)');
  L.push('  tokens_cache_write  : ' + fmtInt(t.tokens_cache_write) + '  (' + t.pct.cache_write + '%)');
  L.push('  TOTAL               : ' + fmtInt(t.total));
  L.push('  cost (USD)          : ' + fmtCost(t.cost));
  var w = warningFor(t);
  if (w) { L.push(''); L.push('  [ADVERTENCIA] ' + w); }
  return L.join('\n');
}

function summaryCols() {
  return [
    { h: 'SESSION', get: function (s) { return s.id.slice(0, 26); } },
    { h: 'AGENT', get: function (s) { return (s.agent || '-').slice(0, 20); } },
    { h: 'MODEL', get: function (s) { return (s.model || '-').slice(0, 24); } },
    { h: 'TURNS', right: true, get: function (s) { return fmtInt(s.turns); } },
    { h: 'TOOLS', right: true, get: function (s) { return fmtInt(s.tools); } },
    { h: 'INPUT', right: true, get: function (s) { return fmtInt(s.tokens_input); } },
    { h: 'OUTPUT', right: true, get: function (s) { return fmtInt(s.tokens_output); } },
    { h: 'REASON', right: true, get: function (s) { return fmtInt(s.tokens_reasoning); } },
    { h: 'CACHE_R', right: true, get: function (s) { return fmtInt(s.tokens_cache_read); } },
    { h: 'CACHE_W', right: true, get: function (s) { return fmtInt(s.tokens_cache_write); } },
    { h: 'TOTAL', right: true, get: function (s) { return fmtInt(s.total); } },
    { h: 'CACHE/TURN', right: true, get: function (s) { return fmtInt(s.cache_por_turno); } },
    { h: 'SEG', right: true, get: function (s) { return fmtNum1(s.seg); } },
    { h: 'COST', right: true, get: function (s) { return fmtCost(s.cost); } }
  ];
}

function renderSummary(list, totals, opts) {
  var rows = list.slice().sort(function (a, b) { return b.time_created - a.time_created; });
  var shown = (opts.top > 0) ? rows.slice(0, opts.top) : rows;
  var out = renderGrid(summaryCols(), shown);
  out += '\n\n' + renderTotals(totals);
  if (rows.length > shown.length) {
    out += '\n(mostrando ' + shown.length + ' de ' + rows.length + ' sesiones; usa --top N para ampliar)';
  }
  return out;
}

function renderSessions(list, opts) {
  var rows = list.slice().sort(function (a, b) { return b.time_created - a.time_created; });
  var shown = (opts.top > 0) ? rows.slice(0, opts.top) : rows;
  var cols = [
    { h: 'SESSION_ID', get: function (s) { return s.id; } },
    { h: 'TITLE', get: function (s) { return (s.title || '-').slice(0, 52); } },
    { h: 'AGENT', get: function (s) { return (s.agent || '-').slice(0, 22); } },
    { h: 'DATE', get: function (s) { return fmtDate(s.time_created); } },
    { h: 'COST', right: true, get: function (s) { return fmtCost(s.cost); } }
  ];
  var out = renderGrid(cols, shown);
  out += '\n(' + shown.length + ' de ' + rows.length + ' sesiones)';
  return out;
}

function renderTree(list, opts) {
  var byId = {};
  list.forEach(function (s) { byId[s.id] = s; });
  var children = {};
  list.forEach(function (s) {
    var p = (s.parent_id && byId[s.parent_id]) ? s.parent_id : '__root__';
    if (!children[p]) children[p] = [];
    children[p].push(s);
  });
  Object.keys(children).forEach(function (k) {
    children[k].sort(function (a, b) { return b.total - a.total; });
  });
  var roots = children['__root__'] || [];
  var top = (opts.top > 0) ? opts.top : 0;
  var printed = 0;
  var seen = {};
  var lines = [];

  function emit(s, prefix, last) {
    lines.push(prefix + (last ? '+-- ' : '|-- ') + s.id + '  [' + (s.agent || '?') + ']' +
      '  total=' + fmtInt(s.total) +
      '  cost=' + fmtCost(s.cost) +
      '  turns=' + fmtInt(s.turns) +
      '  tools=' + fmtInt(s.tools) +
      '  cache/turn=' + fmtInt(s.cache_por_turno) +
      '  seg=' + fmtNum1(s.seg) +
      (s.es_raiz ? '  (raiz)' : ''));
  }

  function walk(s, prefix, last) {
    if (top > 0 && printed >= top) return;
    if (seen[s.id]) return;
    seen[s.id] = true;
    printed++;
    emit(s, prefix, last);
    var ch = children[s.id] || [];
    for (var i = 0; i < ch.length; i++) {
      if (top > 0 && printed >= top) break;
      walk(ch[i], prefix + (last ? '    ' : '|   '), i === ch.length - 1);
    }
  }

  for (var i = 0; i < roots.length; i++) {
    if (top > 0 && printed >= top) break;
    walk(roots[i], '', i === roots.length - 1);
  }
  if (!lines.length) return '(sin sesiones para el filtro)';
  return lines.join('\n');
}

function csvCell(v) {
  var s = (v == null) ? '' : String(v);
  if (/[",\r\n]/.test(s)) return '"' + s.replace(/"/g, '""') + '"';
  return s;
}

function renderCsv(list, opts) {
  var rows = list.slice().sort(function (a, b) { return b.total - a.total; });
  var limit = opts.topExplicit ? (opts.top > 0 ? opts.top : 0) : 0;
  var shown = (limit > 0) ? rows.slice(0, limit) : rows;
  var head = 'session_id,parent_id,title,agent,model,tokens_input,tokens_output,tokens_reasoning,' +
    'tokens_cache_read,tokens_cache_write,total,cost,turns,tools,seg,cache_por_turno,pct_cache,es_raiz';
  var lines = [head];
  shown.forEach(function (s) {
    lines.push([
      csvCell(s.id),
      csvCell(s.parent_id || ''),
      csvCell(s.title),
      csvCell(s.agent),
      csvCell(s.model),
      s.tokens_input,
      s.tokens_output,
      s.tokens_reasoning,
      s.tokens_cache_read,
      s.tokens_cache_write,
      s.total,
      s.cost,
      s.turns,
      s.tools,
      s.seg,
      s.cache_por_turno,
      s.pct_cache,
      s.es_raiz ? 'true' : 'false'
    ].join(','));
  });
  return lines.join('\n');
}

function renderDetailText(entries, opts) {
  var shown = (opts.top > 0) ? entries.slice(0, opts.top) : entries;
  var cols = [
    { h: 'SESSION', get: function (e) { return (e.session_id || '').slice(0, 26); } },
    { h: 'MESSAGE', get: function (e) { return (e.message_id || '').slice(0, 26); } },
    { h: 'PART', get: function (e) { return (e.part_id || '').slice(0, 26); } },
    { h: 'TYPE', get: function (e) { return e.type || ''; } },
    { h: 'TOOL', get: function (e) { return e.tool || '-'; } },
    { h: 'CHARS', right: true, get: function (e) { return fmtInt(e.chars); } },
    { h: 'MS', right: true, get: function (e) { return fmtInt(e.dur); } },
    { h: 'TIME_CREATED', right: true, get: function (e) { return String(e.time_created); } }
  ];
  var out = 'DETALLE (' + shown.length + ' de ' + entries.length + ' partes)';
  if (opts.withContent) out += ' [contenido truncado a ' + opts.maxChars + ' chars y REDACTADO]';
  out += '\n' + renderGrid(cols, shown);
  if (opts.withContent) {
    var blocks = shown.map(function (e) {
      return e.part_id + ' | type=' + e.type + (e.tool ? ' tool=' + e.tool : '') + '\n' + (e.content || '');
    });
    out += '\n\nCONTENIDO (truncado/redactado):\n' + blocks.join('\n---\n');
  }
  return out;
}

function jsonSession(s) {
  return {
    id: s.id,
    parent_id: s.parent_id,
    title: s.title,
    agent: s.agent,
    model: s.model,
    tokens_input: s.tokens_input,
    tokens_output: s.tokens_output,
    tokens_reasoning: s.tokens_reasoning,
    tokens_cache_read: s.tokens_cache_read,
    tokens_cache_write: s.tokens_cache_write,
    total: s.total,
    cost: s.cost,
    turns: s.turns,
    tools: s.tools,
    seg: s.seg,
    cache_por_turno: s.cache_por_turno,
    pct_cache: s.pct_cache,
    es_raiz: s.es_raiz
  };
}

function makeJson(opts, dbPath, totals, list, byAg, detailEntries) {
  var sessions = list.slice().sort(function (a, b) { return b.total - a.total; }).map(jsonSession);
  return {
    schema_version: 1,
    generated_at: new Date().toISOString(),
    db_path: dbPath,
    scope: opts.implicitToday
      ? 'Dia local actual (' + new Date(opts.effSince).toISOString() + ' -> ahora). ' +
        'Pasa --since/--until/--project/--agent/--root para acotar; --since 0 = todo el historico.'
      : 'Filtros explicitos del usuario.',
    filters: {
      since: (opts.effSince != null) ? new Date(opts.effSince).toISOString() : null,
      until: (opts.effUntil != null) ? new Date(opts.effUntil).toISOString() : null,
      project: opts.project || null,
      agent: opts.agent || null,
      root: opts.root || null
    },
    field_docs: {
      tokens_input: 'tokens de entrada frescos (no cacheados)',
      tokens_output: 'tokens generados',
      tokens_reasoning: 'tokens de razonamiento (modelos que los exponen)',
      tokens_cache_read: 'tokens releidos desde cache: es el contexto acumulado re-leido en cada turno',
      tokens_cache_write: 'tokens escritos a cache',
      total: 'suma de los 5 tipos',
      turns: 'cantidad de mensajes de la sesion',
      tools: 'cantidad de llamadas a herramientas',
      seg: 'duracion en segundos (time_updated - time_created)',
      cache_por_turno: 'cache_read / turns; mide el tamano medio del contexto por turno. METRICA CLAVE: costo = turnos x contexto',
      cost: 'costo en USD reportado por la DB (0 para el tier gratuito)',
      parent_id: 'sesion padre; los subagentes tienen parent_id de la raiz'
    },
    totals: {
      sessions: totals.sessions,
      tokens_input: totals.tokens_input,
      tokens_output: totals.tokens_output,
      tokens_reasoning: totals.tokens_reasoning,
      tokens_cache_read: totals.tokens_cache_read,
      tokens_cache_write: totals.tokens_cache_write,
      total: totals.total,
      cost: totals.cost,
      pct: totals.pct
    },
    sessions: sessions,
    by_agent: byAg,
    messages: opts.detail ? detailEntries : null,
    warning: warningFor(totals)
  };
}

/* -------------------------------- CLI ----------------------------------- */

function parseArgs(argv) {
  var o = {
    modes: [], sinceRaw: null, untilRaw: null, project: null, agent: null, root: null,
    db: null, detail: false, withContent: false, maxChars: 2000, out: null,
    top: 50, topExplicit: false, help: false
  };
  var i = 0;
  function needValue(flag) {
    if (i >= argv.length) fail('Falta valor para ' + flag);
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
    switch (a) {
      case '--summary': case 'summary': o.modes.push('summary'); break;
      case '--sessions': case 'sessions': o.modes.push('sessions'); break;
      case '--tree': case 'tree': o.modes.push('tree'); break;
      case '--json': case 'json': o.modes.push('json'); break;
      case '--csv': case 'csv': o.modes.push('csv'); break;
      case '--detail': o.detail = true; break;
      case '--with-content': o.withContent = true; break;
      case '--help': case '-h': case 'help': o.help = true; break;
      case '--since': o.sinceRaw = (val !== null ? val : needValue('--since')); break;
      case '--until': o.untilRaw = (val !== null ? val : needValue('--until')); break;
      case '--project': o.project = (val !== null ? val : needValue('--project')); break;
      case '--agent': o.agent = (val !== null ? val : needValue('--agent')); break;
      case '--root': o.root = (val !== null ? val : needValue('--root')); break;
      case '--db': o.db = (val !== null ? val : needValue('--db')); break;
      case '--out': o.out = (val !== null ? val : needValue('--out')); break;
      case '--max-chars': o.maxChars = parseInt(val !== null ? val : needValue('--max-chars'), 10); break;
      case '--top': o.top = parseInt(val !== null ? val : needValue('--top'), 10); o.topExplicit = true; break;
      default: fail('Opcion desconocida: ' + a + ' (usa --help)');
    }
  }
  if (o.modes.length > 1) fail('Modos mutuamente excluyentes: ' + o.modes.join(', '));
  o.mode = o.modes.length ? o.modes[0] : 'summary';
  if (!isFinite(o.maxChars) || o.maxChars < 0) fail('--max-chars invalido');
  if (!isFinite(o.top)) fail('--top invalido');
  if (o.withContent && !o.detail) o.detail = true;

  o.since = (o.sinceRaw != null) ? parseTime(o.sinceRaw, '--since') : null;
  o.until = (o.untilRaw != null) ? parseTime(o.untilRaw, '--until') : null;

  var hasFilter = (o.since != null || o.until != null || !!o.project || !!o.agent || !!o.root);
  o.implicitToday = !hasFilter;
  o.effSince = o.since;
  o.effUntil = o.until;
  if (o.implicitToday) o.effSince = todayStartMs();
  return o;
}

function helpText() {
  var L = [];
  L.push('usage_report.js - Reporte y export de uso de OpenCode (tokens/costo/tiempo).');
  L.push('');
  L.push('Uso:');
  L.push('  node scripts/usage_report.js [modo] [opciones]');
  L.push('');
  L.push('MODOS (mutuamente excluyentes; default --summary):');
  L.push('  --summary        Tabla por sesion + totales globales.');
  L.push('  --sessions       Lista de sesiones (id, titulo, agente, fecha, costo).');
  L.push('  --tree           Arbol raiz -> subagentes usando parent_id.');
  L.push('  --json           Export JSON autodescriptivo.');
  L.push('  --csv            Export CSV (una fila por sesion).');
  L.push('');
  L.push('ALCANCE POR DEFECTO:');
  L.push('  Sin filtros se reporta el DIA LOCAL actual (00:00 -> ahora).');
  L.push('  Al pasar --since/--until/--project/--agent/--root manda ese filtro.');
  L.push('  Usa --since 0 para recorrer TODO el historico.');
  L.push('');
  L.push('FILTROS:');
  L.push('  --since <ISO|epoch_ms>   time_created >= valor.');
  L.push('  --until <ISO|epoch_ms>   time_created <= valor.');
  L.push('  --project <id|nombre>    project_id o nombre del proyecto.');
  L.push('  --agent <nombre>         match exacto del agente.');
  L.push('  --root <sessionId>       esa sesion + todos sus descendientes (parent_id).');
  L.push('  --db <ruta>              ruta alternativa de opencode.db.');
  L.push('');
  L.push('DETALLE (off por defecto):');
  L.push('  --detail                 Incluye partes: tipo, tool, tamano de args, duracion.');
  L.push('  --with-content           Incluye texto TRUNCADO y REDACTADO (implica --detail).');
  L.push('  --max-chars <N>          Truncado por campo de texto (default 2000).');
  L.push('');
  L.push('SALIDA:');
  L.push('  --out <ruta>             Escribe a archivo en vez de stdout.');
  L.push('  --top <N>                Limita filas en --summary/--tree/--sessions (default 50).');
  L.push('                           En --csv limita solo si se pasa explicitamente.');
  L.push('  -h, --help               Esta ayuda.');
  L.push('');
  L.push('SEGURIDAD:');
  L.push('  La DB se abre en SOLO LECTURA. NUNCA se leen ni exportan las tablas');
  L.push('  account, control_account ni credential (contienen access_token,');
  L.push('  refresh_token, JWT). Solo se consultan session, message, part, project.');
  L.push('  Con --with-content todo texto pasa por redact() antes de truncar.');
  L.push('');
  L.push('EJEMPLOS:');
  L.push('  node scripts/usage_report.js --summary');
  L.push('  node scripts/usage_report.js --sessions --top 20');
  L.push('  node scripts/usage_report.js --tree --root ses_f1e3b117affebsKvUxJHVKHuqK');
  L.push('  node scripts/usage_report.js --summary --since 2026-09-01 --until 2026-09-27');
  L.push('  node scripts/usage_report.js --json --out logs/uso/export/uso.json');
  L.push('  node scripts/usage_report.js --json --detail --with-content --max-chars 200');
  L.push('  node scripts/usage_report.js --csv --top 3');
  L.push('  node scripts/usage_report.js --summary --agent build --since 0');
  return L.join('\n');
}

/* --------------------------------- main --------------------------------- */

function main() {
  var opts = parseArgs(process.argv.slice(2));
  if (opts.help) {
    process.stdout.write(helpText() + '\n');
    return;
  }

  if (!SQLITE || !SQLITE.DatabaseSync) {
    fail('node:sqlite no disponible. Se requiere Node 22+ (recomendado Node 24) ' +
      'con el modulo built-in node:sqlite.', 1);
  }

  var dbPath = opts.db
    ? path.resolve(opts.db)
    : path.join(os.homedir(), '.local', 'share', 'opencode', 'opencode.db');

  if (!fs.existsSync(dbPath)) {
    fail('No existe la base de datos: ' + dbPath +
      ' (usa --db <ruta> para indicar otra ubicacion).', 1);
  }

  var db;
  try {
    db = new SQLITE.DatabaseSync(dbPath, { readOnly: true });
  } catch (e) {
    fail('No se pudo abrir la base en solo lectura: ' + (e && e.message ? e.message : e), 1);
  }

  try {
    var loaded = loadSessions(db, opts);
    if (opts.root && loaded.rootInfo && !loaded.rootInfo.exists) {
      process.stderr.write('AVISO: no existe la sesion raiz indicada: ' + opts.root + '\n');
    }

    var ids = loaded.rows.map(function (r) { return r.id; });
    var turnsMap = countsBySession(db, 'message', ids, '');
    var toolsMap = countsBySession(db, 'part', ids, " AND json_extract(data,'$.type')='tool'");
    var list = buildMetrics(loaded.rows, turnsMap, toolsMap);
    var totals = computeTotals(list);
    var byAg = byAgent(list);
    var detailEntries = opts.detail ? loadDetail(db, ids, opts) : null;

    var text;
    if (opts.mode === 'summary') {
      text = renderSummary(list, totals, opts);
      if (opts.detail) text += '\n\n' + renderDetailText(detailEntries, opts);
    } else if (opts.mode === 'sessions') {
      text = renderSessions(list, opts);
      if (opts.detail) text += '\n\n' + renderDetailText(detailEntries, opts);
    } else if (opts.mode === 'tree') {
      text = renderTree(list, opts);
      if (opts.detail) text += '\n\n' + renderDetailText(detailEntries, opts);
    } else if (opts.mode === 'csv') {
      text = renderCsv(list, opts);
    } else {
      text = JSON.stringify(makeJson(opts, dbPath, totals, list, byAg, detailEntries), null, 2);
    }

    if (opts.out) {
      var outPath = path.resolve(opts.out);
      try {
        fs.mkdirSync(path.dirname(outPath), { recursive: true });
        fs.writeFileSync(outPath, text + '\n', 'utf8');
      } catch (e) {
        fail('No se pudo escribir ' + outPath + ': ' + (e && e.message ? e.message : e), 1);
      }
      process.stderr.write('[ok] escrito: ' + outPath + '\n');
    } else {
      process.stdout.write(text + '\n');
    }
  } catch (e) {
    fail((e && e.message ? e.message : String(e)), 1);
  } finally {
    try { db.close(); } catch (e) { /* noop */ }
  }
}

main();
