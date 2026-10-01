'use strict';

/*
 * smoke_ticket_diseno.js - Smoke del kernel de disenos de ticket (ADR-064)
 *
 * Cierra E7/verificacion. NO es un snapshot de una copia: extrae el codigo REAL
 * de registroaforo.html del disco (balance de llaves con scanner que salta
 * strings, template literals, comentarios y regex) y lo ejecuta en un contexto
 * vm con DOM/canvas/Image/QRCode stubbeados. Si alguien toca el render, esto
 * falla.
 *
 * admin.html se lee SOLO como texto (no se ejecuta, no se edita).
 *
 * Uso:   node scripts/smoke_ticket_diseno.js
 * Exit:  0 = todo PASS ; 1 = algun FAIL ; 2 = no se pudo extraer el kernel.
 */

var fs = require('fs');
var path = require('path');
var vm = require('vm');

var REG = path.join(__dirname, '..', 'registroaforo.html');
var ADM = path.join(__dirname, '..', 'admin.html');

var BACKTICK = String.fromCharCode(96);
var CH_BS = String.fromCharCode(92);

/* ---------------------------------------------------------------- harness */

var passN = 0;
var failN = 0;
var fails = [];

function out(msg) { process.stdout.write(String(msg) + '\n'); }

function seccion(t) { out(''); out('== ' + t + ' ' + new Array(Math.max(4, 56 - t.length)).join('=')); }

function ok(cond, label, detail) {
  if (cond) {
    passN += 1;
    out('  PASS  ' + label);
  } else {
    failN += 1;
    fails.push(label + (detail ? (' :: ' + detail) : ''));
    out('  FAIL  ' + label + (detail ? ('  [' + detail + ']') : ''));
  }
  return !!cond;
}

function eq(actual, expected, label) {
  var a = JSON.stringify(actual);
  var e = JSON.stringify(expected);
  return ok(a === e, label, a === e ? '' : ('got ' + a + ' want ' + e));
}

function near(actual, expected, tol, label) {
  return ok(Math.abs(actual - expected) <= tol, label, 'got ' + actual + ' want ' + expected);
}

/* ------------------------------------------------------------- extractor */

function isRegexStart(ch) {
  if (ch === '') return true;
  return '(,=:[!&|?{};+-*%<>^~'.indexOf(ch) !== -1;
}

/* Extrae "function <name>(...) { ... }" por balance de llaves. */
function extractFunction(src, name) {
  var start = src.indexOf('function ' + name + '(');
  if (start === -1) return null;
  var open = src.indexOf('{', start);
  if (open === -1) return null;
  var depth = 0, inS = false, inD = false, inT = false, inLine = false, inBlock = false, prevSig = '';
  for (var i = open; i < src.length; i++) {
    var c = src.charAt(i), n = src.charAt(i + 1);
    if (inLine) { if (c === '\n') inLine = false; continue; }
    if (inBlock) { if (c === '*' && n === '/') { inBlock = false; i++; continue; } continue; }
    if (inS) { if (c === CH_BS) { i++; continue; } if (c === "'") inS = false; continue; }
    if (inD) { if (c === CH_BS) { i++; continue; } if (c === '"') inD = false; continue; }
    if (inT) { if (c === CH_BS) { i++; continue; } if (c === BACKTICK) inT = false; continue; }
    if (c === '/' && n === '/') { inLine = true; i++; continue; }
    if (c === '/' && n === '*') { inBlock = true; i++; continue; }
    if (c === "'") { inS = true; continue; }
    if (c === '"') { inD = true; continue; }
    if (c === BACKTICK) { inT = true; continue; }
    if (c === '/' && isRegexStart(prevSig)) {
      i++;
      var cls = false;
      while (i < src.length) {
        var r = src.charAt(i);
        if (r === CH_BS) { i += 2; continue; }
        if (r === '[') cls = true;
        else if (r === ']') cls = false;
        else if (r === '/' && !cls) { i++; break; }
        else if (r === '\n') break;
        i++;
      }
      prevSig = '/';
      continue;
    }
    if (c === '{') depth += 1;
    else if (c === '}') { depth -= 1; if (depth === 0) return src.slice(start, i + 1); }
    if (!/\s/.test(c)) prevSig = c;
  }
  return null;
}

/* Bloque de constantes TICKET_* (declaradas con var, una o varias por linea). */
function extractConstBlock(src) {
  var a = src.indexOf('var TICKET_W =');
  if (a === -1) return null;
  var b = src.indexOf('var TICKET_DISENO_BASE');
  if (b === -1) return null;
  var nl = src.indexOf('\n', b);
  return src.slice(a, nl === -1 ? src.length : nl);
}

/* Valor literal de una constante de ese bloque (soporta "var A = 1, B = 2;"). */
/* Literal de una constante del bloque (lexer: no corta comas dentro de strings). */
function constVal(block, name) {
  var re = new RegExp('(?:^|[,;]|(?:var|let|const)\\s+)\\s*' + name + '\\s*=\\s*');
  var m = re.exec(block);
  if (!m) return null;
  var i = m.index + m[0].length;
  var s = '', q = null;
  while (i < block.length) {
    var c = block.charAt(i);
    if (q) { s += c; if (c === q) q = null; i += 1; continue; }
    if (c === "'" || c === '"' || c === BACKTICK) { q = c; s += c; i += 1; continue; }
    if (c === ',' || c === ';') break;
    s += c; i += 1;
  }
  return s.trim();
}

/* Region de codigo de render del ticket (constantes + funciones). */
function renderRegion(src) {
  var a = src.indexOf('// --- Render del ticket');
  if (a === -1) a = src.indexOf('var TICKET_W =');
  var b = src.indexOf('function _descargarCanvasReg');
  if (a === -1 || b === -1 || b <= a) return null;
  return src.slice(a, b);
}

/* Solo el JS de la pagina (fuera de CSS): evita falsos positivos de @keyframes. */
function jsRegion(src) {
  var re = /<script\b[^>]*>([\s\S]*?)<\/script>/g;
  var parts = [], m;
  while ((m = re.exec(src)) !== null) parts.push(m[1]);
  return parts.join('\n');
}

function countIn(text, needle) {
  var n = 0, i = 0;
  while ((i = text.indexOf(needle, i)) !== -1) { n += 1; i += needle.length; }
  return n;
}

/* ---------- cableado del tipo: fuente real -> call sites de render --------- */

/* Nombre de la funcion que ENVUELVE una linea (la mas cercana hacia atras). */
function enclosingFn(lines, idx) {
  for (var k = idx; k >= 0; k--) {
    var m = lines[k].match(/function\s+([A-Za-z0-9_]+)\s*\(/);
    if (m) return m[1];
  }
  return '';
}

/*
 * Extrae, por cada llamada a _generarTicketCanvasReg, la declaracion
 * "const tipo = ..." que la alimenta. Devuelve {fn, decl, callLine, declLine}.
 * Solo mira los call sites (excluye la definicion de la funcion).
 */
function tipoCallSites(text) {
  var lines = text.split(/\r?\n/);
  var sites = [];
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].indexOf('_generarTicketCanvasReg(') === -1) continue;
    if (lines[i].indexOf('function _generarTicketCanvasReg(') !== -1) continue;
    var decl = null, declLine = -1;
    for (var j = i; j >= 0 && j >= i - 8; j--) {
      if (lines[j].indexOf('const tipo =') !== -1) { decl = lines[j].trim(); declLine = j + 1; break; }
    }
    sites.push({ fn: enclosingFn(lines, i), decl: decl, callLine: i + 1, declLine: declLine });
  }
  return sites;
}

/* Problemas de cableado del tipo en los call sites (vacio = sano). */
function tipoWiringProblemas(text) {
  var problemas = [];
  var sites = tipoCallSites(text);
  if (sites.length !== 3) {
    problemas.push('se esperaban 3 call sites de _generarTicketCanvasReg, hallados ' + sites.length);
  }
  sites.forEach(function (s) {
    var tag = (s.fn || '?') + ' L' + s.callLine;
    if (!s.decl) { problemas.push(tag + ': sin "const tipo =" cercano'); return; }
    if (s.decl.indexOf('name="tipo"') !== -1) {
      problemas.push(tag + ': resuelve tipo desde [name="tipo"] (DOM inexistente)');
    }
    if (/=\s*null\s*;?\s*$/.test(s.decl)) {
      problemas.push(tag + ': tipo queda null incondicional');
    }
    if (s.decl.indexOf('__ctxRol') === -1 && s.decl.indexOf('__dupData') === -1) {
      problemas.push(tag + ': no usa __ctxRol ni __dupData');
    }
  });
  return problemas;
}

/* Problemas de persistencia (window.__ctxRol -> inscritos.tipo). */
function tipPersistenciaProblemas(text) {
  var problemas = [];
  if (text.indexOf('window.__ctxRol = rol') === -1) {
    problemas.push('window.__ctxRol no se asigna desde el rol resuelto');
  }
  if (text.indexOf('const rol = window.__ctxRol') === -1) {
    problemas.push('el rol de registro no deriva de window.__ctxRol');
  }
  if (text.indexOf('tipo: rol') === -1) {
    problemas.push('el payload de registro no persiste "tipo: rol"');
  }
  if (text.indexOf('tipo: tipoPersona') === -1) {
    problemas.push('el payload de existente no persiste "tipo: tipoPersona"');
  }
  if (text.indexOf('const tipoPersona = _existenteReg.tipo || rol') === -1) {
    problemas.push('tipoPersona no prioriza la fila de inscritos y cae a rol');
  }
  return problemas;
}

/* ------------------------------------------------------- stubs de entorno */

function makeCtx(ops) {
  var ctx = {
    fillStyle: '', font: '', textAlign: '', textBaseline: '',
    shadowColor: '', shadowBlur: 0, imageSmoothingEnabled: true
  };
  function rec(m, snap, argv) {
    var o = { m: m, args: argv };
    if (snap) { for (var k in snap) { if (Object.prototype.hasOwnProperty.call(snap, k)) o[k] = snap[k]; } }
    ops.push(o);
  }
  var A = function (a) { return Array.prototype.slice.call(a); };
  ctx.fillRect = function () { rec('fillRect', { fillStyle: ctx.fillStyle }, A(arguments)); };
  ctx.drawImage = function () { rec('drawImage', null, A(arguments)); };
  ctx.fillText = function () {
    rec('fillText', { fillStyle: ctx.fillStyle, font: ctx.font, textAlign: ctx.textAlign, textBaseline: ctx.textBaseline }, A(arguments));
  };
  ['beginPath', 'moveTo', 'lineTo', 'arcTo', 'closePath', 'stroke', 'fill', 'save', 'restore',
    'translate', 'rotate', 'scale', 'setTransform', 'transform', 'clearRect', 'rect']
    .forEach(function (m) {
      ctx[m] = function () { rec(m, null, A(arguments)); };
    });
  return ctx;
}

function makeCanvas(w, h) {
  var ops = [];
  var cv = { tagName: 'CANVAS', width: w || 300, height: h || 150, ops: ops, children: [] };
  cv.getContext = function () { return makeCtx(ops); };
  cv.toDataURL = function () { return 'data:image/png;base64,STUB'; };
  cv.setAttribute = function () { };
  cv.querySelector = function () { return null; };
  return cv;
}

function makeNode(tag) {
  var n = {
    tagName: String(tag).toUpperCase(), children: [], style: {}, dataset: {},
    attrs: {}, parentNode: null, textContent: '', value: ''
  };
  n.setAttribute = function (k, v) { this.attrs[k] = v; };
  n.getAttribute = function (k) { return this.attrs[k]; };
  n.removeAttribute = function (k) { delete this.attrs[k]; };
  n.appendChild = function (c) { c.parentNode = this; this.children.push(c); return c; };
  n.removeChild = function (c) {
    var i = this.children.indexOf(c);
    if (i !== -1) { this.children.splice(i, 1); c.parentNode = null; }
    return c;
  };
  n.querySelector = function (sel) {
    var want = String(sel).toLowerCase();
    var stack = this.children.slice();
    while (stack.length) {
      var c = stack.shift();
      if (c.tagName.toLowerCase() === want) return c;
      stack = stack.concat(c.children);
    }
    return null;
  };
  return n;
}

/*
 * env = { urls: { <url>: {w,h} | 'ERROR' | 'NODIM' }, logs: [] }
 * 'ERROR' -> dispara onerror (fallo de carga / CORS manchado).
 * 'NODIM'  -> dispara onload pero naturalWidth/Height = 0.
 */
function makeEnv(env) {
  var e = env || {};
  var urls = e.urls || {};
  var logs = e.logs || [];
  var requested = [];
  var qrCalls = [];

  function ImageStub() {
    var self = this;
    this.width = 0; this.height = 0; this.naturalWidth = 0; this.naturalHeight = 0;
    this.crossOrigin = null; this.onload = null; this.onerror = null; this._src = '';
    Object.defineProperty(this, 'src', {
      get: function () { return self._src; },
      set: function (v) {
        self._src = v;
        requested.push(v);
        var def = urls[v];
        if (def === 'ERROR') { if (self.onerror) self.onerror(new Error('cors/load fail: ' + v)); return; }
        if (def === 'NODIM') { if (self.onload) self.onload(); return; }
        if (def) {
          self.width = def.w; self.height = def.h;
          self.naturalWidth = def.w; self.naturalHeight = def.h;
          if (self.onload) self.onload();
          return;
        }
        if (self.onerror) self.onerror(new Error('no stubeado: ' + v));
      }
    });
  }

  function QRCodeStub(host, opts) {
    var size = (opts && opts.width) || 0;
    host.appendChild(makeCanvas(size, size));
    host._qrOpts = opts;
    qrCalls.push({ opts: opts, host: host });
  }
  QRCodeStub.CorrectLevel = { L: 1, M: 0, Q: 3, H: 2 };

  var body = makeNode('body');
  var doc = {
    body: body,
    createElement: function (t) { return String(t).toLowerCase() === 'canvas' ? makeCanvas() : makeNode(t); },
    querySelector: function () { return null; },
    querySelectorAll: function () { return []; },
    getElementById: function () { return null; }
  };

  var origin = 'https://hostalterraza.vercel.app';
  var win = {
    location: { href: origin + '/registroaforo.html?slug=x', origin: origin },
    document: doc, navigator: { userAgent: 'node' }, open: function () { return null; }
  };

  var sandbox = {
    document: doc, window: win, navigator: win.navigator,
    Image: ImageStub, QRCode: QRCodeStub, URL: URL, Promise: Promise,
    console: console, setTimeout: setTimeout, clearTimeout: clearTimeout,
    log: function (msg, kind) { logs.push(String(kind || '') + '|' + String(msg)); },
    alert: function () { }
  };
  sandbox.globalThis = sandbox;
  vm.createContext(sandbox);
  return { sandbox: sandbox, logs: logs, requested: requested, body: body, qrCalls: qrCalls };
}

var KERNEL = null;

function loadKernel(src) {
  var consts = extractConstBlock(src);
  if (!consts) return null;
  var names = ['_truncarReg', '_qrSrcDeCajaReg', '_qrSrcReg', '_disenoTicketUrlReg',
    '_cargarImagenTicketReg', '_drawCoverReg', '_qrNativoReg', '_generarTicketCanvasReg'];
  var parts = [consts];
  for (var i = 0; i < names.length; i++) {
    var f = extractFunction(src, names[i]);
    if (!f) return null;
    parts.push(f);
  }
  return parts.join('\n\n');
}

/* Arranca un contexto con el kernel REAL ya evaluado. */
function ctxWith(src, env) {
  var e = makeEnv(env);
  vm.runInContext(KERNEL, e.sandbox);
  return { K: e.sandbox, env: e };
}

var BASE = '/imagenes/tiket-rastro.jpg';
var STORAGE = 'https://ctgyvydzshueemlelkzv.supabase.co/storage/v1/object/public/eventos-imagenes/disenos/x/pago_1.png';

/* Envoltoria minima del contrato config_landing.content.ticket_disenos. */
function LISTA(arr) { return { config_landing: { content: { ticket_disenos: arr } } }; }

function fillOps(ops, m) { return ops.filter(function (o) { return o.m === m; }); }
function fullRect(ops) {
  return fillOps(ops, 'fillRect').filter(function (o) {
    return o.args[0] === 0 && o.args[1] === 0 && o.args[2] === 1080 && o.args[3] === 1920;
  });
}

/*
 * Margenes que deja un rect INTERIOR dentro de uno EXTERNO: {l,r,t,b}.
 * Negativo = desbordamiento. Es la primitiva de los asserts de INVARIANTE:
 * el smoke chequea la RELACION (contencion + simetria), no el numero
 * absoluto de la coordenada, para que ajustar una Y medida por analisis de
 * pixeles no rompa el test mientras el defecto real siga cogido.
 */
function margins(inner, outer) {
  return {
    l: inner[0] - outer[0],
    r: (outer[0] + outer[2]) - (inner[0] + inner[2]),
    t: inner[1] - outer[1],
    b: (outer[1] + outer[3]) - (inner[1] + inner[3])
  };
}

/* Rectangulo cuadrado desde x, y y lado. */
function sq(x, y, size) { return [x, y, size, size]; }

/* ------------------------------------------------------------------ main */

function main() {
  if (!fs.existsSync(REG)) { out('FATAL: no existe registroaforo.html'); return 2; }
  if (!fs.existsSync(ADM)) { out('FATAL: no existe admin.html'); return 2; }
  var src = fs.readFileSync(REG, 'utf8');
  var adm = fs.readFileSync(ADM, 'utf8');

  KERNEL = loadKernel(src);
  if (!KERNEL) { out('FATAL: no se pudo extraer el kernel de render'); return 2; }
  var region = renderRegion(src);
  if (!region) { out('FATAL: no se pudo localizar la region de render'); return 2; }

  var cblock = extractConstBlock(src);
  var g = {};
  ['TICKET_W', 'TICKET_H', 'TICKET_FRAME_X', 'TICKET_FRAME_Y', 'TICKET_FRAME_SIZE',
    'TICKET_PLACA_X', 'TICKET_PLACA_Y', 'TICKET_PLACA_SIZE',
    'TICKET_QR_X', 'TICKET_QR_Y', 'TICKET_QR_SIZE', 'TICKET_QR_NATIVE',
    'TICKET_QR_TEXT_Y', 'TICKET_QR_TEXT_PX', 'TICKET_QR_TEXT_COLOR', 'TICKET_DISENO_BASE']
    .forEach(function (k) { g[k] = constVal(cblock, k); });
  var n = function (k) { return Number(g[k]); };

  /* ------------------------------------------------------------- S1 */
  seccion('S1 Geometria exacta (lienzo 1080x1920)');
  eq(g.TICKET_W, '1080', 'lienzo ancho = 1080');
  eq(g.TICKET_H, '1920', 'lienzo alto = 1920');
  eq(g.TICKET_QR_SIZE, '480', 'QR lado = 480 EXACTO (no 479 ni 481)');
  eq(g.TICKET_QR_NATIVE, '480', 'QR nativo = 480');
  eq(g.TICKET_QR_X, '300', 'QR X = 300');
  eq(g.TICKET_QR_Y, '760', 'QR Y = 760');
  eq(g.TICKET_FRAME_X, '260', 'marco X = 260');
  eq(g.TICKET_FRAME_Y, '720', 'marco Y = 720');
  eq(g.TICKET_FRAME_SIZE, '560', 'marco lado = 560');
  eq(g.TICKET_PLACA_X, '272', 'placa X = 272');
  eq(g.TICKET_PLACA_Y, '732', 'placa Y = 732 (ajuste intencional por evidencia visual)');
  eq(g.TICKET_PLACA_SIZE, '536', 'placa lado = 536');
  eq(g.TICKET_QR_TEXT_Y, '1555', 'string del codigo Y = 1555');
  eq(g.TICKET_QR_TEXT_PX, '28', 'string del codigo = 28 px (una sola linea)');
  eq(g.TICKET_QR_TEXT_COLOR, "'rgba(253, 246, 220, .78)'", 'color del string = crema del arte');
  eq(g.TICKET_DISENO_BASE, "'" + BASE + "'", 'semilla same-origin del fondo base');

  /* ------------------------------------------------------------------
   * INVARIANTES GEOMETRICOS (no numeros absolutos).
   * La placa y el QR se comprueban por CONTENCION y SIMETRIA. Asi, ajustar
   * una coordenada por analisis de pixiles (TICKET_PLACA_Y 748 -> 732) no
   * rompe el smoke, pero reintroducir el descentrado lo vuelve a cazar.
   * ------------------------------------------------------------------ */
  var R_FRAME = sq(n('TICKET_FRAME_X'), n('TICKET_FRAME_Y'), n('TICKET_FRAME_SIZE'));
  var R_PLACA = sq(n('TICKET_PLACA_X'), n('TICKET_PLACA_Y'), n('TICKET_PLACA_SIZE'));
  var R_QR = sq(n('TICKET_QR_X'), n('TICKET_QR_Y'), n('TICKET_QR_SIZE'));
  var mP = margins(R_PLACA, R_FRAME);
  var mQ = margins(R_QR, R_PLACA);

  ok(mP.t >= 0, 'placa: no se sale del marco por ARRIBA', 'margen sup=' + mP.t);
  ok(mP.b >= 0, 'placa: no se sale del marco por ABAJO', 'margen inf=' + mP.b);
  eq(mP.t, mP.b, 'placa: CENTRADA verticalmente en el marco (margen sup == margen inf)');
  eq(mP.l, mP.r, 'placa: CENTRADA horizontalmente en el marco (margen izq == der)');

  ok(mQ.t >= 0, 'QR: cabe dentro de la placa por ARRIBA (quiet zone)', 'sup=' + mQ.t);
  ok(mQ.b >= 0, 'QR: cabe dentro de la placa por ABAJO (quiet zone)', 'inf=' + mQ.b);
  eq(mQ.t, mQ.b, 'QR: quiet zone SIMETRICA en Y dentro de la placa');
  eq(mQ.l, mQ.r, 'QR: quiet zone SIMETRICA en X dentro de la placa');
  eq(mQ.l, (n('TICKET_PLACA_SIZE') - n('TICKET_QR_SIZE')) / 2,
    'QR: el quiet zone sale del contrato de tamanos ((536-480)/2)');

  /* El string del codigo no puede caer sobre la placa blanca. */
  ok(R_PLACA[1] + R_PLACA[3] <= n('TICKET_QR_TEXT_Y') - n('TICKET_QR_TEXT_PX'),
    'el string del codigo no se dibuja encima de la placa blanca',
    'placa termina en ' + (R_PLACA[1] + R_PLACA[3]) + ', el string arranca en ' + (n('TICKET_QR_TEXT_Y') - n('TICKET_QR_TEXT_PX')));

  /* La placa no puede invadir la banda de arte de la fecha: evidencia medida
     en el brief de E1-E6 (la fecha "SABADO 10 DE OCTUBRE 2026" ocupa el
     lienzo Y=1278..1316). Con la placa en 732 quedan 10 px de aire. */
  var ARTE_FECHA_Y = 1278;
  ok(R_PLACA[1] + R_PLACA[3] < ARTE_FECHA_Y,
    'la placa blanca no invade la banda de arte de la fecha (Y=' + ARTE_FECHA_Y + '..1316)',
    'la placa termina en ' + (R_PLACA[1] + R_PLACA[3]));

  ok(n('TICKET_QR_TEXT_Y') > R_QR[1] + R_QR[3], 'el string del codigo va POR DEBAJO del QR');
  ok(n('TICKET_QR_TEXT_Y') + n('TICKET_QR_TEXT_PX') < n('TICKET_H'), 'el string del codigo cabe en el lienzo');

  /* ------------------------------------------------------------- S2 */
  seccion('S2 Sin transformacion de lienzo');
  var js = jsRegion(src);
  ['rotate(', 'setTransform', 'skew', 'scale(', '.transform('].forEach(function (t) {
    eq(countIn(region, t), 0, '0 ocurrencias de "' + t + '" en el codigo de render');
  });
  ['rotate(', 'setTransform', '.transform('].forEach(function (t) {
    eq(countIn(js, t), 0, '0 "' + t + '" en TODO el JS de registroaforo.html');
  });
  eq(countIn(region, 'imageSmoothingEnabled = false'), 1, 'imageSmoothingEnabled=false (QR sin interpolacion)');
  ok(countIn(js, 'rotate(360deg)') === 0, 'el unico rotate() del repo es CSS @keyframes, no JS de canvas');

  /* ------------------------------------------------------------- S4 */
  seccion('S4 Cadena de resolucion del diseno (function REAL)');
  var c4 = ctxWith(src, { urls: {} });
  var F = c4.K._disenoTicketUrlReg;
  ok(typeof F === 'function', 'S4 _disenoTicketUrlReg se extrajo y evaluo');
  [
    ['config_landing = null', { config_landing: null }, 'invitado', ''],
    ['content ausente', { config_landing: {} }, 'invitado', ''],
    ['content.ticket_disenos ausente', { config_landing: { content: {} } }, 'invitado', ''],
    ['ticket_disenos no es array', LISTA({ a: 1 }), 'invitado', ''],
    ['ticket_disenos = null', LISTA(null), 'invitado', ''],
    ['ev = null', null, 'invitado', ''],
    ['ev = undefined', undefined, 'invitado', ''],
    ['tipo = null', LISTA([{ tipo: 'invitado', diseno_url: STORAGE, activo: true }]), null, ''],
    ['tipo = cadena vacia', LISTA([{ tipo: 'invitado', diseno_url: STORAGE, activo: true }]), '', ''],
    ['lista vacia', LISTA([]), 'invitado', ''],
    ['match con activo:false', LISTA([{ tipo: 'invitado', diseno_url: STORAGE, activo: false }]), 'invitado', ''],
    ['match con activo ausente', LISTA([{ tipo: 'invitado', diseno_url: STORAGE }]), 'invitado', ''],
    ['match con activo truthy no-booleano', LISTA([{ tipo: 'invitado', diseno_url: STORAGE, activo: 1 }]), 'invitado', STORAGE],
    ['match con diseno_url en blanco', LISTA([{ tipo: 'invitado', diseno_url: '   ', activo: true }]), 'invitado', ''],
    ['match con diseno_url ausente', LISTA([{ tipo: 'invitado', activo: true }]), 'invitado', ''],
    ['match con otro tipo', LISTA([{ tipo: 'artista', diseno_url: STORAGE, activo: true }]), 'invitado', ''],
    ['entradas no-objeto se saltan', LISTA([null, 'x', 42, { tipo: 'invitado', diseno_url: STORAGE, activo: true }]), 'invitado', STORAGE],
    ['match valido', LISTA([{ tipo: 'pago', diseno_url: STORAGE, activo: true }]), 'pago', STORAGE],
    ['doble match gana el PRIMERO', LISTA([
      { tipo: 'invitado', diseno_url: 'https://primero.png', activo: true },
      { tipo: 'invitado', diseno_url: 'https://segundo.png', activo: true }]), 'invitado', 'https://primero.png'],
    ['1ro inactivo + 2do activo -> 2do', LISTA([
      { tipo: 'invitado', diseno_url: 'https://inactivo.png', activo: false },
      { tipo: 'invitado', diseno_url: 'https://activo.png', activo: true }]), 'invitado', 'https://activo.png'],
    ['1ro sin url + 2do con url -> 2do', LISTA([
      { tipo: 'invitado', diseno_url: '', activo: true },
      { tipo: 'invitado', diseno_url: 'https://segundo.png', activo: true }]), 'invitado', 'https://segundo.png'],
    ['los 5 tipos congelados resuelven', LISTA(['invitado', 'frecuente', 'artista', 'produccion', 'pago'].map(function (t) {
      return { tipo: t, diseno_url: 'https://d/' + t + '.png', activo: true };
    })), 'produccion', 'https://d/produccion.png']
  ].forEach(function (c) {
    eq(F(c[1], c[2]), c[3], 'S4 ' + c[0]);
  });
  eq(F(LISTA([{ tipo: 'Invitado', diseno_url: STORAGE, activo: true }]), 'invitado'), '',
    'S4 el match de tipo es EXACTO (no normaliza mayusculas)');

  /* ------------------------------------------------------------- S6 */
  seccion('S6 Guard de proporcion: recorte centrado, nunca estirado');
  [[941, 1672, 'semilla REAL 941x1672'], [1080, 1920, 'exacto 1080x1920'],
    [1920, 1080, 'mas ancho 1920x1080'], [600, 2000, 'mas alto 600x2000'],
    [1200, 1200, 'cuadrado 1200x1200'], [300, 5000, 'vertical extrema 300x5000']]
    .forEach(function (c) {
      var ops = [];
      var img = { naturalWidth: c[0], naturalHeight: c[1] };
      var ret = c4.K._drawCoverReg(makeCtx(ops), img, 1080, 1920);
      ok(ret === true, 'S6 ' + c[2] + ': devuelve true');
      var d = fillOps(ops, 'drawImage');
      if (!ok(d.length === 1, 'S6 ' + c[2] + ': un solo drawImage', 'n=' + d.length)) return;
      var a = d[0].args; /* img, sx, sy, sw, sh, dx, dy, dw, dh */
      var sx = a[1], sy = a[2], sw = a[3], sh = a[4];
      ok(a[0] === img, 'S6 ' + c[2] + ': la fuente es la imagen');
      eq([a[5], a[6], a[7], a[8]], [0, 0, 1080, 1920], 'S6 ' + c[2] + ': destino SIEMPRE (0,0,1080,1920)');
      near(sw / sh, 1080 / 1920, 1e-9, 'S6 ' + c[2] + ': el recorte tiene aspecto exacto 9:16 (nada estirado)');
      ok(sw <= c[0] + 1e-9 && sh <= c[1] + 1e-9, 'S6 ' + c[2] + ': el recorte cabe en el origen (nunca amplia)',
        JSON.stringify([sw, sh]));
      near(sx + sw / 2, c[0] / 2, 1e-6, 'S6 ' + c[2] + ': recorte CENTRADO en X');
      near(sy + sh / 2, c[1] / 2, 1e-6, 'S6 ' + c[2] + ': recorte CENTRADO en Y');
    });
  var ops6 = [];
  c4.K._drawCoverReg(makeCtx(ops6), { naturalWidth: 941, naturalHeight: 1672 }, 1080, 1920);
  eq([ops6[0].args[3], ops6[0].args[4]], [940.5, 1672], 'S6 la semilla 941x1672 recorta sw=940.5 sh=1672');
  eq(ops6[0].args[1], 0.25, 'S6 la semilla 941x1672 recorta sx=0.25 (centrado exacto)');
  var ops6b = [];
  var r6b = c4.K._drawCoverReg(makeCtx(ops6b), { naturalWidth: 0, naturalHeight: 0 }, 1080, 1920);
  ok(r6b === false && ops6b.length === 0, 'S6 sin dimensiones NO dibuja nada (devuelve false)');

  /* ------------------------------------------------------------- S5 */
  seccion('S5 Sin match se conserva el fondo base');
  var c5 = ctxWith(src, { urls: (function () { var m = {}; m[BASE] = { w: 941, h: 1672 }; return m; })() });
  var evOtro = LISTA([{ tipo: 'pago', diseno_url: STORAGE, activo: true }]);
  return c5.K._generarTicketCanvasReg('QR-TEST01', 'Ana', evOtro, '#reg-qr', 'invitado').then(function (cv) {
    eq(c5.env.requested[0], BASE, 'S5 sin match carga la semilla /imagenes/tiket-rastro.jpg');
    ok(c5.env.requested.indexOf(STORAGE) === -1, 'S5 sin match NO pide el diseno de otro tipo');
    eq(fullRect(cv.ops).length, 0, 'S5 con fondo cargado NO se pinta el rect de respaldo');
    ok(fillOps(cv.ops, 'drawImage').some(function (o) {
      return o.args[5] === 0 && o.args[6] === 0 && o.args[7] === 1080 && o.args[8] === 1920;
    }), 'S5 el fondo base cubre 1080x1920');
    return s5b(src);
  })
    .then(function () { return s7(src); })
    .then(function () { return s3(src); })
    .then(function () { s8(adm); s9(src); return null; })
    .then(finish);
}

/* S5b: el diseno de Storage no carga (CORS) -> el fondo base sobrevive. */
function s5b(src) {
  seccion('S5b Diseno de Storage que no carga (CORS) -> fallback');
  var c = ctxWith(src, { urls: (function () { var m = {}; m[STORAGE] = 'ERROR'; return m; })() });
  var ev = LISTA([{ tipo: 'invitado', diseno_url: STORAGE, activo: true }]);
  return c.K._generarTicketCanvasReg('QR-TEST01', 'Ana', ev, '#reg-qr', 'invitado').then(function (cv) {
    ok(c.env.requested[0] === STORAGE, 'S5b intenta el diseno subido a Storage');
    ok(c.env.requested.indexOf(STORAGE) > -1 && c.env.requested[0] !== BASE, 'S5b NO se descarga la semilla cuando hay diseno');
    var full = fullRect(cv.ops);
    eq(full.length, 1, 'S5b fondo no cargado -> se repinta el fondo base 1080x1920');
    if (full.length === 1) eq(full[0].fillStyle, '#0F0F0F', 'S5b el fondo base es TICKET_FONDO');
    var rects = fillOps(cv.ops, 'fillRect');
    eq(rects.length, 3, 'S5b el ticket se completa: fondo + marco + placa (sigue siendo util)');
    ok(c.env.logs.some(function (l) { return l.indexOf('fondo base') !== -1; }),
      'S5b deja rastro en log del fallo de carga', JSON.stringify(c.env.logs));
    return c;
  });
}

/* S7: payload QR nativo a 480 px. */
function s7(src) {
  seccion('S7 Payload QR nativo (480 px, sin ampliar pixeles del DOM)');
  var c = ctxWith(src, { urls: (function () { var m = {}; m[BASE] = { w: 941, h: 1672 }; return m; })() });
  return c.K._generarTicketCanvasReg('QR-AB12CD', 'Ana', null, '#reg-qr', null).then(function (cv) {
    ok(cv.width === 1080 && cv.height === 1920, 'S7 el lienzo es 1080x1920', cv.width + 'x' + cv.height);
    var rects = fillOps(cv.ops, 'fillRect');
    eq(rects[0].args, [260, 720, 560, 560], 'S7 marco cyan 560@(260,720)');
    eq(rects[0].fillStyle, '#00E5FF', 'S7 color del marco = TICKET_CYAN');
    eq(rects[1].fillStyle, '#FFFFFF', 'S7 color de la placa = blanco (quiet zone del QR)');
    eq(rects[1].args[2], 536, 'S7 la placa mide 536 de lado (quiet zone del QR)');
    eq(rects[1].args[3], 536, 'S7 la placa es cuadrada');
    var q = fillOps(cv.ops, 'drawImage').filter(function (o) { return o.args[7] === 480 && o.args[8] === 480; });
    eq(q.length, 1, 'S7 el QR se dibuja 480x480 en el lienzo');

    /* Placa y QR sobre las ops REALES del lienzo: se chequean por INVARIANTE
       (contencion + simetria), no por la coordenada absoluta. Asi el smoke
       sigue catching un descentrado aunque la Y se ajuste a mano. */
    if (rects.length >= 2 && q.length === 1) {
      var Rf = rects[0].args;
      var Rp = rects[1].args;
      var Rq = [q[0].args[5], q[0].args[6], q[0].args[7], q[0].args[8]];
      var mp = margins(Rp, Rf);
      ok(mp.t >= 0 && mp.b >= 0, 'S7 la placa cabe dentro del marco (no desborda)',
        'sup=' + mp.t + ' inf=' + mp.b);
      eq(mp.t, mp.b, 'S7 la placa esta CENTRADA verticalmente en el marco (margen sup == inf)');
      eq(mp.l, mp.r, 'S7 la placa esta CENTRADA horizontalmente en el marco');
      var mq = margins(Rq, Rp);
      ok(mq.t >= 0 && mq.b >= 0, 'S7 el QR cabe dentro de la placa (no la invade)',
        'sup=' + mq.t + ' inf=' + mq.b);
      eq(mq.t, mq.b, 'S7 el QR tiene quiet zone SIMETRICA en Y dentro de la placa');
      eq(mq.l, mq.r, 'S7 el QR tiene quiet zone SIMETRICA en X dentro de la placa');
      eq(mq.l, (Rp[2] - Rq[2]) / 2, 'S7 el quiet zone sale del contrato de tamanos ((536-480)/2)');
    }
    if (q.length === 1) {
      eq([q[0].args[5], q[0].args[6]], [300, 760], 'S7 el QR se posiciona en (300,760) [contrato]');
      ok(q[0].args[3] >= 480 && q[0].args[4] >= 480, 'S7 la fuente del QR ya es >= 480 px (nada se amplia)',
        JSON.stringify([q[0].args[3], q[0].args[4]]));
    }
    return s7b(src);
  });
}

/* S7b: si la fuente nativa no llega a 480, se degrada (prohibido ampliar 150/180). */
function s7b(src) {
  seccion('S7b Prohibido ampliar pixeles del QR del DOM (150/180)');
  var c = ctxWith(src, { urls: (function () { var m = {}; m[BASE] = { w: 941, h: 1672 }; return m; })() });
  c.K.QRCode = undefined; /* fuerza la degradacion */
  return c.K._generarTicketCanvasReg('QR-AB12CD', 'Ana', null, '#no-existe', null).then(function (cv) {
    var q = fillOps(cv.ops, 'drawImage').filter(function (o) { return o.args[7] === 480; });
    eq(q.length, 0, 'S7b sin fuente >= 480 NO dibuja el QR (no amplia pixeles)');
    var fb = fillOps(cv.ops, 'fillText').filter(function (o) { return o.args[0] === 'QR-AB12CD' && o.args[2] === 1000; });
    eq(fb.length, 1, 'S7b degrada a texto con el codigo en el centro del QR',
      JSON.stringify(fillOps(cv.ops, 'fillText').map(function (o) { return [o.args[0], o.args[1], o.args[2]]; })));
    if (fb.length === 1) eq([fb[0].args[1], fb[0].args[2]], [540, 1000], 'S7b el texto de degradacion va al centro del QR');
    eq(fillOps(cv.ops, 'fillText').filter(function (o) { return o.args[2] === 1555; }).length, 1,
      'S7b el string del codigo en Y=1555 se dibuja igual');
    ok(c.env.logs.length > 0, 'S7b deja rastro en log de la degradacion', JSON.stringify(c.env.logs));
  });
}

/* S3: el string del codigo ES inscritos.qr_code. */
function s3(src) {
  seccion('S3 String del codigo = inscritos.qr_code (payload opaco)');
  var c = ctxWith(src, { urls: (function () { var m = {}; m[BASE] = { w: 941, h: 1672 }; return m; })() });
  var P = 'QR-9F3A7C';
  return c.K._generarTicketCanvasReg(P, 'Ana Perez', null, '#reg-qr', null).then(function (cv) {
    var t = fillOps(cv.ops, 'fillText');
    ok(t.length >= 1, 'S3 el render dibuja el string del codigo', 'n=' + t.length);
    var last = t.length ? t[t.length - 1] : null;
    eq(last ? last.args[0] : null, P, 'S3 el texto dibujado ES el qr_code recibido, sin transformar');
    eq(last ? last.args[1] : null, 540, 'S3 el string se centra en X=540');
    eq(last ? last.args[2] : null, 1555, 'S3 el string se dibuja en Y=1555');
    eq(last ? last.textBaseline : null, 'middle', 'S3 textBaseline=middle (Y es el centro de linea)');
    eq(last ? last.textAlign : null, 'center', 'S3 textAlign=center');
    eq(last ? last.font : null, '28px sans-serif', 'S3 28 px, una sola linea');
    eq(last ? last.fillStyle : null, 'rgba(253, 246, 220, .78)', 'S3 color crema del arte');
    ok(last && last.args[0].indexOf('%') === -1, 'S3 el payload NO va URL-encoded al lienzo');
    eq(fillOps(cv.ops, 'drawImage').filter(function (o) { return o.args[5] === 300 && o.args[6] === 760; }).length, 1,
      'S3 el QR se dibuja UNICAMENTE como imagen (el string va aparte, en Y=1555)');
    /* qrcodejs recibe el payload CRUDO, generado a 480. */
    ok(c.env.qrCalls.length >= 1, 'S3 qrcodejs recibio el texto del codigo', 'n=' + c.env.qrCalls.length);
    if (c.env.qrCalls.length) {
      var qo = c.env.qrCalls[c.env.qrCalls.length - 1].opts;
      eq(qo.text, P, 'S3 el QR encodes el qr_code crudo (sin hashear ni codificar)');
      eq([qo.width, qo.height], [480, 480], 'S3 el QR se genera a 480 NATIVO (no 150/180 del DOM)');
    }
    eq(c.env.body.children.length, 0, 'S3 el host temporal del QR sale del DOM (finally)');
    ok(c.env.qrCalls.every(function (x) { return !x.host.parentNode; }),
      'S3 el host del QR quedo desmontado (finally), drawImage funciona con nodos sueltos');
    /* Origen del payload en el codigo de registro. */
    ok(src.indexOf("'QR-' + UID()") !== -1, 'S3 el payload opaco se genera como "QR-" + UID() (= inscritos.qr_code)');
    eq(countIn(KERNEL, 'encodeURIComponent'), 0, 'S3 el kernel de render NO codifica el payload');
    eq(countIn(KERNEL, 'innerHTML'), 0, 'S3 el kernel de render NO inyecta HTML del dato');
    eq(countIn(KERNEL, 'btoa'), 0, 'S3 el kernel de render NO transforma el payload a base64');
    /* El nombre del asistente NO se dibuja en el lienzo (solo el codigo). */
    ok(fillOps(cv.ops, 'fillText').every(function (o) { return String(o.args[0]).indexOf('Ana') === -1; }),
      'S3 el nombre del asistente NO se dibuja en el ticket');
    /* Payload largo: se trunca a 40 con elipsis, el original NO se altera. */
    var largo = 'QR-' + new Array(60).join('X');
    return c.K._generarTicketCanvasReg(largo, 'Ana', null, '#reg-qr', null).then(function (cv2) {
      var t2 = fillOps(cv2.ops, 'fillText');
      var s2 = t2.length ? String(t2[t2.length - 1].args[0]) : '';
      ok(s2.length === 42 && s2.slice(0, 39) === largo.slice(0, 39) && s2.slice(39) === '...',
        'S3 payload largo se trunca a 39+3 con elipsis (el original NO se modifica)', 'len=' + s2.length + ' ' + s2);
    });
  });
}

/* S8: persistencia en admin (SOLO lectura). */
function s8(adm) {
  seccion('S8 Persistencia en admin (lectura, no edita)');
  var i = adm.indexOf('function _buildConfigLanding');
  ok(i !== -1, 'S8 existe _buildConfigLanding');
  var j = i === -1 ? -1 : adm.indexOf('\nfunction ', i + 10);
  var b = (i === -1) ? '' : adm.slice(i, j === -1 ? adm.length : j);
  ok(b.length > 500, 'S8 _buildConfigLanding se extrajo completa', 'len=' + b.length);
  ok(b.indexOf('ticket_disenos') !== -1, 'S8 ticket_disenos se serializa DENTRO de _buildConfigLanding');
  ok(/ticket_disenos\s*:\s*disenos\b/.test(b), 'S8 la clave escrita es "ticket_disenos: disenos"');
  ok(b.indexOf('ticket_disenos') < b.indexOf('...(hayForm'),
    'S8 ticket_disenos se escribe ANTES de los spreads finales (no se pisa)');
  var d = b.match(/const\s+disenos\s*=/);
  ok(!!d, 'S8 la lista se calcula en una variable "disenos"');
  var m = adm.match(/const\s+TICKET_DISENOS_TIPOS\s*=\s*\[([\s\S]*?)\n\];/);
  ok(m !== null, 'S8 existe la constante TICKET_DISENOS_TIPOS');
  var orden = m ? (m[1].match(/tipo:\s*'([^']*)'/g) || []).map(function (s) {
    return s.replace(/tipo:\s*'/, '').replace(/'$/, '');
  }) : [];
  eq(orden, ['invitado', 'frecuente', 'artista', 'produccion', 'pago'],
    'S8 la UI declara los 5 tipos en el ORDEN CONGELADO');
  ok(m && m[1].indexOf('default') === -1, 'S8 la UI NO declara un campo "default" (la ausencia ES el fallback)');
  ok(/_TICKET_DISENO_BUCKET\s*=\s*'eventos-imagenes'/.test(adm), 'S8 el bucket de los disenos es eventos-imagenes');
  ok(adm.indexOf("'disenos/' + _ticketDisenoSlug()") !== -1, 'S8 el path de Storage es disenos/{slug}/{tipo}_{ts}.{ext}');
  ok(adm.indexOf('id="ticket-disenos-rows"') !== -1, 'S8 el contenedor #ticket-disenos-rows existe');
  ok(adm.indexOf('window._ticketDisenosSetEntries') !== -1, 'S8 existe el read-back window._ticketDisenosSetEntries');
  ok(countIn(adm, 'ticket-diseno-row') >= 2, 'S8 la fila se identifica por .ticket-diseno-row[data-tipo]');
  /* Mismo contrato en el lector. */
  ok(/content\s*\.\s*ticket_disenos/.test(adm), 'S8 el lector consume content.ticket_disenos (mismo contrato)');
  var ab = countIn(adm, '<div'), ce = countIn(adm, '</div>');
  eq(ab - ce, 3, 'S8 balance de divs de admin.html = baseline preexistente (+3)');
}

/*
 * S9: cableado del tipo. La fuente real (window.__ctxRol, persistido como
 * inscritos.tipo) debe alimentar los 3 call sites de _generarTicketCanvasReg.
 * Caza el defecto de integracion: el render leia [name="tipo"] (DOM que no
 * existe) o __dupData (nulo en el flujo nuevo). Incluye prueba de mutacion.
 */
function s9(src) {
  seccion('S9 Cableado del tipo (window.__ctxRol -> render)');

  var sites = tipoCallSites(src);
  eq(sites.length, 3, 'S9 hay exactamente 3 call sites de _generarTicketCanvasReg');
  var fns = sites.map(function (s) { return s.fn; }).sort();
  eq(fns, ['descargarDupReg', 'descargarTicketReg', 'enviarTicketWAReg'],
    'S9 los 3 call sites son ticket nuevo, duplicado y WhatsApp');

  sites.forEach(function (s) {
    var tag = 'S9 ' + (s.fn || '?') + ': ';
    ok(!!s.decl, tag + 'declara "const tipo =" antes de renderizar',
      s.declLine > 0 ? ('L' + s.declLine) : 'sin declaracion');
    ok(!!s.decl && s.decl.indexOf('name="tipo"') === -1,
      tag + 'NO resuelve tipo desde [name="tipo"] (no existe en el DOM)', s.decl || '');
    ok(!!s.decl && !/=\s*null\s*;?\s*$/.test(s.decl),
      tag + 'tipo NO queda null incondicional', s.decl || '');
    ok(!!s.decl && (s.decl.indexOf('__ctxRol') !== -1 || s.decl.indexOf('__dupData') !== -1),
      tag + 'resuelve desde window.__ctxRol / window.__dupData', s.decl || '');
  });

  var byFn = {};
  sites.forEach(function (s) { byFn[s.fn] = s.decl || ''; });
  ok(byFn.descargarTicketReg.indexOf('__ctxRol') !== -1,
    'S9 el ticket NUEVO (descargarTicketReg) usa window.__ctxRol', byFn.descargarTicketReg);
  ok(byFn.descargarDupReg.indexOf('__ctxRol') !== -1 && byFn.descargarDupReg.indexOf('__dupData') !== -1,
    'S9 el duplicado prioriza la fila y cae a window.__ctxRol', byFn.descargarDupReg);
  ok(byFn.enviarTicketWAReg.indexOf('__ctxRol') !== -1 && byFn.enviarTicketWAReg.indexOf('__dupData') !== -1,
    'S9 el WhatsApp prioriza la fila y cae a window.__ctxRol', byFn.enviarTicketWAReg);
  eq(countIn(src, 'name="tipo"'), 0, 'S9 no queda ningun [name="tipo"] en registroaforo.html');

  var pp = tipPersistenciaProblemas(src);
  eq(pp, [], 'S9 window.__ctxRol ES lo que se persiste como inscritos.tipo', JSON.stringify(pp));

  /* Prueba de mutacion: el guard DEBE cazar la regresion. Original intacto. */
  var roto = src.replace(
    "const tipo = window.__ctxRol || 'invitado';",
    'const tipo = (document.querySelector(\'[name="tipo"]\') || {}).value || null;');
  ok(roto !== src, 'S9 el patron del ticket nuevo esta presente (mutacion aplicable)');
  var mut = tipoWiringProblemas(roto);
  ok(mut.length > 0, 'S9 el guard DETECTA la regresion a [name="tipo"] (mutacion falla)', JSON.stringify(mut));
  eq(tipoWiringProblemas(src), [], 'S9 el archivo real esta SANO (el guard no dispara)');
}

function finish() {
  out('');
  out('================================================================');
  out('TOTAL asserts: ' + (passN + failN) + '   PASS: ' + passN + '   FAIL: ' + failN);
  if (failN) {
    out('');
    out('FALLAS:');
    fails.forEach(function (f, i) { out('  ' + (i + 1) + ') ' + f); });
    out('');
    out('VEREDICTO: FAIL');
    process.exitCode = 1;
    return;
  }
  out('VEREDICTO: PASS');
  process.exitCode = 0;
}

var r = (function () {
  try { return main(); } catch (e) { out('FATAL: ' + (e && e.stack ? e.stack : e)); return 2; }
})();
if (r && typeof r.then === 'function') {
  r.catch(function (e) { out('FATAL: ' + (e && e.stack ? e.stack : e)); process.exitCode = 1; });
} else {
  process.exitCode = r;
}
