#!/usr/bin/env node
'use strict';

/*
 * scripts/smoke_f14_grid.js
 * ---------------------------------------------------------------------------
 * TSK-139 (ADR-093) - Regresion del grid de f14 en NAVEGADOR REAL.
 *
 * Que mide: la seccion 29 de css/templates/fiesta/f14.css (lay-out por evento
 * boletos + guest list en la misma fila, gancho body[data-mod-row="boleto-guest"])
 * y su convivencia con las rejas base (seccion 18) y anti-hueco (seccion 28).
 *
 * 8 escenarios x 4 anchos exactos (1200/768/767/390) = 32 mediciones:
 *   0  sin gancho (control: eventos f14 normales)
 *   a  ambos visibles        b  guest list [data-hidden]
 *   c  guest list [data-empty]   d  form [data-hidden]
 *   e  d + c                 f  guest list + form + video ocultos
 *   g  boletos [data-hidden]
 *
 * Asserts por medicion: viewport exacto, 0 solapamientos con rects
 * fraccionarios, 0 huecos > 26px (el gutter real es 24px), geometria esperada
 * de cada estado y, en 767/390, reja de 1 columna con boletos antes que
 * guestlist. Incluye la regresion del piso 767px (antes: segunda columna
 * implicita por el anti-hueco de la seccion 28).
 *
 * Uso:  node scripts/smoke_f14_grid.js [--keep]
 *   CHROME_PATH  ruta al ejecutable de Chrome/Chromium (opcional).
 * Sin Chrome: imprime SKIP y sale 0 (no rompe CI sin navegador).
 *
 * Solo lee evento-app.html y f14.css; escribe el harness en el temp del SO.
 * No modifica el repo.
 * ---------------------------------------------------------------------------
 */

const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawn } = require('child_process');

const ROOT = path.resolve(__dirname, '..');
const WIDTHS = [1200, 768, 767, 390];
const CHROME_CANDIDATES = [
  process.env.CHROME_PATH,
  'C:/Program Files/Google/Chrome/Application/chrome.exe',
  'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe',
  'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/usr/bin/google-chrome',
  '/usr/bin/chromium',
  '/usr/bin/chromium-browser'
].filter(Boolean);

const chrome = CHROME_CANDIDATES.find(p => { try { return fs.statSync(p).isFile(); } catch (e) { return false; } });
if (!chrome) {
  console.log('SKIP smoke_f14_grid: no se encontro Chrome/Chromium (define CHROME_PATH).');
  process.exit(0);
}
if (typeof WebSocket !== 'function') {
  console.log('SKIP smoke_f14_grid: Node sin WebSocket global (requiere Node >= 22).');
  process.exit(0);
}

/* ------------------------------------------------------------------ harness */

function buildHarness(dir) {
  const src = fs.readFileSync(path.join(ROOT, 'evento-app.html'), 'utf8');
  const styles = [];
  const re = /<style[^>]*>([\s\S]*?)<\/style>/g;
  let m;
  while ((m = re.exec(src))) styles.push(m[1]);
  const open = src.indexOf('<main id="main-content-flow"');
  const close = src.indexOf('</main>', open);
  if (!styles.length || open < 0 || close < 0) {
    throw new Error('no se pudo extraer <style> o #main-content-flow de evento-app.html');
  }
  const main = src.slice(open, close + '</main>'.length);
  const probe = fs.readFileSync(path.join(__dirname, 'smoke_f14_grid_probe.js.txt'), 'utf8');
  const css = 'file:///' + path.join(ROOT, 'css/templates/fiesta/f14.css').replace(/\\/g, '/');
  const html = '<!doctype html><html lang="es"><head><meta charset="utf-8">'
    + '<meta name="viewport" content="width=device-width, initial-scale=1">'
    + '<link rel="stylesheet" href="' + css + '">'
    + '<style>' + styles.join('\n') + '</style></head>'
    + '<body class="tpl-f14 Tpl-F14" data-mod-row="boleto-guest">' + main + probe + '</body></html>';
  const file = path.join(dir, 'harness.html');
  fs.writeFileSync(file, html);
  return 'file:///' + file.replace(/\\/g, '/');
}

/* ----------------------------------------------------------------------- CDP */

const sleep = ms => new Promise(r => setTimeout(r, ms));

async function devtoolsPort(dir) {
  const f = path.join(dir, 'DevToolsActivePort');
  for (let i = 0; i < 120; i++) {
    if (fs.existsSync(f)) {
      const t = fs.readFileSync(f, 'utf8').trim().split(/\r?\n/);
      if (t[0]) return t[0];
    }
    await sleep(100);
  }
  throw new Error('Chrome no expuso DevToolsActivePort');
}

function connect(url) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(url);
    let id = 0;
    const pend = new Map();
    const events = [];
    ws.addEventListener('message', e => {
      const msg = JSON.parse(e.data);
      if (msg.id && pend.has(msg.id)) {
        const { res, rej } = pend.get(msg.id);
        pend.delete(msg.id);
        msg.error ? rej(new Error(JSON.stringify(msg.error))) : res(msg.result);
      } else if (msg.method) events.push(msg);
    });
    ws.addEventListener('open', () => resolve({
      send(method, params) {
        return new Promise((res, rej) => {
          const i = ++id;
          pend.set(i, { res, rej });
          ws.send(JSON.stringify({ id: i, method, params: params || {} }));
        });
      },
      events,
      close: () => ws.close()
    }));
    ws.addEventListener('error', () => reject(new Error('fallo el WebSocket de CDP')));
  });
}

/* ------------------------------------------------------------------ asserts */

const eq = (a, b, tol) => Math.abs(a - b) <= (tol == null ? 3 : tol);

function checkState(w, st, flowW, fails) {
  const at = s => `[${w}px ${st.s}] ${s}`;
  if (st.vw !== w) fails.push(at(`viewport ${st.vw} != ${w}`));
  if (st.overlaps.length) fails.push(at('solapamiento ' + st.overlaps.join(',')));
  const holes = st.bands.reduce((acc, b) => acc.concat(b.holes || []), []);
  holes.forEach(h => { if (parseInt(h, 10) > 26) fails.push(at('hueco ' + h)); });

  const b = st.rects['mod-boletos'].r;
  const g = st.rects['mod-guestlist'].r;
  const f = st.rects['mod-form'].r;
  const wide = w >= 768;
  const bVis = b[2] > 0;
  const gVis = g[2] > 0;

  if (!wide) {
    if (st.cols !== 1) fails.push(at(`cols=${st.cols} (se esperaba 1)`));
    if (bVis && gVis && !(b[1] < g[1])) fails.push(at('boletos no precede a guestlist'));
    return;
  }

  if (st.cols !== 2) fails.push(at(`cols=${st.cols} (se esperaba 2)`));
  const half = (flowW - 24) / 2;

  switch (st.s[0]) {
    case '0': // control: reja base, boletos+form en fila, guestlist a lo ancho
      if (!eq(b[2], half) || !eq(f[2], half) || !eq(b[1], f[1])) fails.push(at('control: boletos+form no comparten fila a media anchura'));
      if (!eq(g[2], flowW)) fails.push(at('control: guestlist no ocupa el ancho'));
      break;
    case 'a': // ambos: boletos|guestlist en fila, form a lo ancho
      if (!bVis || !gVis || !eq(b[1], g[1]) || !eq(b[2], half) || !eq(g[2], half)) fails.push(at('estado a: pareja mal medida'));
      if (!eq(f[2], flowW)) fails.push(at('estado a: form no ocupa el ancho'));
      break;
    case 'b': case 'c': // guestlist apagada / vacia: boletos a lo ancho
      if (!eq(b[2], flowW) || gVis) fails.push(at('estado b/c: boletos no ocupa el ancho'));
      break;
    case 'd': // form apagado: boletos|guestlist a media anchura
      if (f[2] !== 0 || !eq(b[1], g[1]) || !eq(b[2], half)) fails.push(at('estado d: pareja mal medida'));
      break;
    case 'e': case 'f': // boletos a lo ancho (29.4 gana a 29.3)
      if (!eq(b[2], flowW) || gVis) fails.push(at('estado e/f: boletos no ocupa el ancho'));
      break;
    case 'g': // boletos apagado: guestlist a lo ancho
      if (bVis || !eq(g[2], flowW)) fails.push(at('estado g: guestlist no ocupa el ancho'));
      break;
  }
}

/* --------------------------------------------------------------------- main */

(async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'smoke-f14-'));
  const harness = buildHarness(dir);
  const profile = path.join(dir, 'profile');
  const proc = spawn(chrome, [
    '--headless=new', '--disable-gpu', '--no-first-run', '--no-default-browser-check',
    '--disable-background-networking', '--disable-extensions', '--mute-audio',
    '--force-device-scale-factor=1', '--blink-settings=imagesEnabled=false',
    '--allow-file-access-from-files', '--remote-debugging-port=0',
    '--user-data-dir=' + profile, 'about:blank'
  ], { stdio: 'ignore' });

  let cdp;
  try {
    const port = await devtoolsPort(profile);
    const list = await (await fetch('http://127.0.0.1:' + port + '/json/list')).json();
    const page = list.find(t => t.type === 'page');
    cdp = await connect(page.webSocketDebuggerUrl);
    await cdp.send('Page.enable');
    await cdp.send('Runtime.enable');
    await cdp.send('Emulation.setDeviceMetricsOverride', { width: 1200, height: 900, deviceScaleFactor: 1, mobile: false });
    await cdp.send('Page.navigate', { url: harness });
    for (let i = 0; i < 100 && !cdp.events.some(e => e.method === 'Page.loadEventFired'); i++) await sleep(100);
    await sleep(250);

    const fails = [];
    let meas = 0;
    for (const w of WIDTHS) {
      await cdp.send('Emulation.setDeviceMetricsOverride', {
        width: w, height: w < 500 ? 844 : 900, deviceScaleFactor: 1, mobile: w < 500
      });
      await sleep(200);
      const r = await cdp.send('Runtime.evaluate', {
        expression: 'JSON.stringify({vw:innerWidth,bw:document.getElementById("main-content-flow").getBoundingClientRect().width,res:window.__probeAll()})',
        returnByValue: true
      });
      const out = JSON.parse(r.result.value);
      const flowW = Math.round(out.bw);
      for (const st of out.res) {
        meas++;
        if (st.vw !== w) fails.push(`[${w}px ${st.s}] viewport ${st.vw}`);
        checkState(w, st, flowW, fails);
      }
    }
    const total = meas;
    if (fails.length) {
      console.error(`FAIL smoke_f14_grid: ${total - fails.length}/${total} PASS`);
      fails.slice(0, 20).forEach(f => console.error('  - ' + f));
      process.exitCode = 1;
    } else {
      console.log(`PASS smoke_f14_grid: ${total}/${total} mediciones (${WIDTHS.length} anchos x 8 escenarios)`);
    }
  } catch (e) {
    console.error('FAIL smoke_f14_grid: ' + e.message);
    process.exitCode = 1;
  } finally {
    if (cdp) cdp.close();
    proc.kill();
    if (!process.argv.includes('--keep')) {
      try { fs.rmSync(dir, { recursive: true, force: true }); } catch (e) { /* noop */ }
    }
  }
})();
