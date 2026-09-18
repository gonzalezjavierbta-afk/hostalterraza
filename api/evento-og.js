'use strict';

// ============================================================
// api/evento-og.js
// Endpoint de Open Graph dinamico para el shell evento-app.html.
// Un rewrite de vercel.json enruta /evento.html?slug=<slug> aqui.
// CommonJS estricto. Sin dependencias externas (fetch global + fs/path).
// ASCII-safe: sin tildes, sin enes, sin backticks.
// ============================================================

var FALLBACK_IMG = 'https://ctgyvydzshueemlelkzv.supabase.co/storage/v1/object/public/assets/avatar-default.png';
var SB_URL = process.env.SUPABASE_URL || 'https://ctgyvydzshueemlelkzv.supabase.co';
var SB_KEY = process.env.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN0Z3l2eWR6c2h1ZWVtbGVsa3p2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM2NTc1NzAsImV4cCI6MjA4OTIzMzU3MH0.3pMA-VZLV2Kfyl6BD-x8v79P7UuXSfMgtIwnfoP_VuY';
var DEFAULT_DESC = 'Eventos, musica y cultura en Hostal Terraza.';
var MIN_HTML = '<html><head></head><body>Hostal Terraza</body></html>';

function esc(s) {
  return String(s == null ? '' : s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function withTimeout(url, options, ms) {
  var opts = options || {};
  var ctrl = null;
  if (typeof AbortController !== 'undefined') {
    ctrl = new AbortController();
    opts.signal = ctrl.signal;
  }
  var timer = setTimeout(function () {
    if (ctrl) { try { ctrl.abort(); } catch (e) {} }
  }, ms);
  return fetch(url, opts).then(function (r) {
    clearTimeout(timer);
    return r;
  }, function (e) {
    clearTimeout(timer);
    throw e;
  });
}

function cleanText(s) {
  return String(s == null ? '' : s)
    .replace(/<[^>]*>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function trimTo(s, max) {
  s = String(s == null ? '' : s);
  if (s.length <= max) return s;
  var cut = s.slice(0, max);
  var sp = cut.lastIndexOf(' ');
  if (sp > 0) cut = cut.slice(0, sp);
  return cut + '...';
}

function readShellFromDisk() {
  try {
    var fs = require('fs');
    var path = require('path');
    return fs.readFileSync(path.join(process.cwd(), 'evento-app.html'), 'utf8');
  } catch (e) {
    return '';
  }
}

function getHost(req) {
  return String((req.headers && (req.headers['x-forwarded-host'] || req.headers.host)) || '');
}

function getProto(req) {
  return String((req.headers && req.headers['x-forwarded-proto']) || 'https');
}

async function loadShell(req) {
  var host = getHost(req);
  var proto = getProto(req);
  if (host) {
    try {
      var r = await withTimeout(proto + '://' + host + '/evento-app.html', {}, 4000);
      if (r && r.ok) {
        var t = await r.text();
        if (t && t.length > 0) return t;
      }
    } catch (e) {
      // fail-open: se intenta el disco
    }
  }
  return readShellFromDisk();
}

function buildMeta(nombre, desc, imagen, host, slug) {
  var ogTitle = nombre + ' - Hostal Terraza';
  var url = 'https://' + host + '/evento.html?slug=' + slug;
  var lines = [
    '<meta name="description" content="' + esc(desc) + '">',
    '<meta property="og:type" content="website">',
    '<meta property="og:title" content="' + esc(ogTitle) + '">',
    '<meta property="og:description" content="' + esc(desc) + '">',
    '<meta property="og:image" content="' + esc(imagen) + '">',
    '<meta property="og:url" content="' + esc(url) + '">',
    '<meta property="og:site_name" content="Hostal Terraza">',
    '<meta name="twitter:card" content="summary_large_image">',
    '<meta name="twitter:title" content="' + esc(ogTitle) + '">',
    '<meta name="twitter:description" content="' + esc(desc) + '">',
    '<meta name="twitter:image" content="' + esc(imagen) + '">'
  ];
  return lines.join('\n');
}

function inject(html, nombre, desc, imagen, host, slug) {
  var h = String(html || '');
  var title = '<title>' + esc(nombre) + ' - Hostal Terraza</title>';
  h = h.replace(/<title>[\s\S]*?<\/title>/i, title);
  var meta = buildMeta(nombre, desc, imagen, host, slug);
  var idx = h.indexOf('</head>');
  if (idx !== -1) {
    h = h.slice(0, idx) + meta + '\n' + h.slice(idx);
  } else {
    h = h + meta;
  }
  return h;
}

function send(res, html) {
  res.status(200);
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.setHeader('Cache-Control', 'public, max-age=0, s-maxage=600, stale-while-revalidate=86400');
  if (typeof res.send === 'function') {
    res.send(html);
  } else {
    res.end(html);
  }
}

async function loadEvento(slug) {
  if (!slug) return null;
  try {
    var restUrl = SB_URL + '/rest/v1/eventos?select=nombre,descripcion,imagen_url,poster_url,config_landing,fecha,hora,ubicacion,categoria_slug&slug=eq.' + encodeURIComponent(slug) + '&limit=1';
    var headers = {
      'apikey': SB_KEY,
      'Authorization': 'Bearer ' + SB_KEY
    };
    var resp = await withTimeout(restUrl, { headers: headers }, 4000);
    if (resp && resp.ok) {
      var json = await resp.json();
      if (Array.isArray(json) && json[0]) return json[0];
    }
  } catch (e) {
    return null;
  }
  return null;
}

function resolveDesc(nombre, ev, content) {
  var raw = content.descripcion || ev.descripcion || '';
  var d = '';
  if (typeof raw === 'string') {
    d = raw;
  } else if (raw && typeof raw === 'object') {
    d = raw.texto || raw.titulo || '';
  }
  if (!d) {
    var alt = ev.lead || (typeof ev.descripcion === 'string' && ev.descripcion !== raw ? ev.descripcion : '');
    if (alt && typeof alt === 'object') alt = alt.texto || alt.titulo || '';
    d = alt || '';
  }
  if (!d) {
    var parts = [];
    if (nombre) parts.push(nombre);
    if (ev.fecha) parts.push(String(ev.fecha));
    if (ev.ubicacion) parts.push(String(ev.ubicacion));
    parts.push('Hostal Terraza');
    d = parts.join(' - ');
  }
  var clean = trimTo(cleanText(d), 200);
  return clean || DEFAULT_DESC;
}

async function resolveImagen(ev, host) {
  var imagen = ev.poster_url || ev.imagen_url || '';
  if (imagen && imagen.charAt(0) === '/') {
    imagen = (host ? 'https://' + host : SB_URL) + imagen;
  }
  if (!imagen) imagen = FALLBACK_IMG;
  // Verificacion best-effort: si el HEAD no responde 200 se deja igual.
  try {
    if (/^https?:\/\//i.test(imagen)) {
      var head = await withTimeout(imagen, { method: 'HEAD' }, 3000);
      if (!head || head.status !== 200) {
        // se deja la imagen tal cual
      }
    }
  } catch (e) {
    // se deja la imagen tal cual; nunca bloquea la respuesta
  }
  return imagen;
}

module.exports = async function handler(req, res) {
  try {
    req = req || {};
    res = res || {};

    var slug = String((req.query && req.query.slug) || '').trim();
    if (!/^[a-z0-9-]+$/i.test(slug) || slug.length > 120) slug = '';

    var host = getHost(req);
    var ev = await loadEvento(slug);

    var nombre = 'Hostal Terraza';
    var desc = DEFAULT_DESC;
    var imagen = FALLBACK_IMG;

    if (ev) {
      nombre = ev.nombre || 'Hostal Terraza';
      var content = (ev.config_landing && ev.config_landing.content) || {};
      desc = resolveDesc(nombre, ev, content);
      imagen = await resolveImagen(ev, host);
    }

    var shell = await loadShell(req);
    var out = shell ? inject(shell, nombre, desc, imagen, host, slug) : MIN_HTML;
    send(res, out);
  } catch (err) {
    try {
      var shell2 = readShellFromDisk();
      send(res, shell2 || MIN_HTML);
    } catch (e2) {
      try {
        res.status(200);
        res.setHeader('Content-Type', 'text/html; charset=utf-8');
        res.end(MIN_HTML);
      } catch (e3) {
        // ultimo recurso: nada mas que hacer
      }
    }
  }
};
