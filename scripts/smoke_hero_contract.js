// Smoke de CONTRATO DEL HERO + WIZARD DE 5 PASOS (agregado 2026-10-02).
// Cubre el cambio de contrato: el titulo en 2 lineas ya no se parte con
// Math.ceil; la linea 2 es el subtitulo capturado en Cimientos (paso 1).
// Complementa scripts/smoke_ticket_diseno.js (que cubre el contrato del ticket).
// Vanilla JS, sin dependencias, ASCII puro. Ejecutar: node scripts/smoke_hero_contract.js
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const read = (p) => fs.readFileSync(path.join(ROOT, p), 'utf8');
const ADMIN = read('admin.html');
const KERNEL = read('evento-app.html');

// Nota: se lee el HTML CRUDO, sin quitar comentarios. Un stripper de comentarios
// casino con admin.html (un '/*' desbalanceado dentro de un string borra 500 KB
// y hace que los asserts miren un archivo mutilado). Los patrones de este smoke son
// especificos de codigo, asi que no necesitan esa limpieza.
const KERNEL_CODE = KERNEL;
const ADMIN_CODE = ADMIN;

let pass = 0, fail = 0;
const fallos = [];
function ok(nombre, cond) {
  if (cond) { pass++; console.log('  PASS  ' + nombre); }
  else { fail++; fallos.push(nombre); console.log('  FAIL  ' + nombre); }
}
function count(re, src) { return (src.match(re) || []).length; }

// Extrae la allowlist de una funcion del kernel: function __x(){const allow=[...]}
function allowlistDe(src, nombre) {
  const re = new RegExp('function\\s+' + nombre + '\\s*\\(\\)\\s*\\{\\s*const\\s+allow\\s*=\\s*\\[([^\\]]*)\\]');
  const m = src.match(re);
  if (!m) return null;
  return m[1].split(',').map(s => s.trim().replace(/^['"]|['"]$/g, '')).filter(Boolean);
}

console.log('\n=== S1 KERNEL: contrato del titulo en 2 lineas ===');
ok('S1 el split Math.ceil desaparecio del codigo del kernel',
   !/Math\.ceil/.test(KERNEL_CODE));
ok('S1 existe __esTitulo2Lineas()', /function\s+__esTitulo2Lineas\s*\(/.test(KERNEL_CODE));
const aTitulo = allowlistDe(KERNEL_CODE, '__esTitulo2Lineas');
ok('S1 allowlist de titulo 2 lineas = f6,f9,f10,f13',
   JSON.stringify(aTitulo) === JSON.stringify(['tpl-f6', 'tpl-f9', 'tpl-f10', 'tpl-f13']));
ok('S1 f8 EXCLUIDO del titulo de 2 lineas (su #event-title es display:none)',
   aTitulo && aTitulo.indexOf('tpl-f8') === -1);
ok('S1 f9b EXCLUIDO del titulo de 2 lineas (ya tiene su propio #event-subtitle)',
   aTitulo && aTitulo.indexOf('tpl-f9b') === -1);
ok('S1 la linea 1 (.hero-title-line1) recibe el nombre del evento',
   /hero-title-line1/.test(KERNEL_CODE) && /__tituloRaw/.test(KERNEL_CODE));
ok('S1 la linea 2 (.hero-title-line2) recibe el SUBTITULO',
   /className\s*=\s*'hero-title-line2'[\s\S]{0,220}__subtituloRaw/.test(KERNEL_CODE));
ok('S1 la linea 2 solo se crea si hay texto de subtitulo (regla de vacio)',
   /__subtituloRaw\s*\)\s*\{\s*const __l2/.test(KERNEL_CODE));
ok('S1 #event-subtitle NO se enciende cuando el titulo ya lo pinto (sin duplicar)',
   /__subtituloRaw\s*&&\s*!__esTitulo2L/.test(KERNEL_CODE));

console.log('\n=== S2 KERNEL: capacidad de meta a 2 lineas ===');
ok('S2 existe __esMeta2Lineas()', /function\s+__esMeta2Lineas\s*\(/.test(KERNEL_CODE));
const aMeta = allowlistDe(KERNEL_CODE, '__esMeta2Lineas');
ok('S2 allowlist de meta 2 lineas = f9,f9b',
   JSON.stringify(aMeta) === JSON.stringify(['tpl-f9', 'tpl-f9b']));
ok('S2 el gate de la meta usa __esMeta2Lineas() y NO __esFamiliaF9()',
   /__esF9Meta\s*=\s*__esMeta2Lineas\s*\(\s*\)/.test(KERNEL_CODE));
ok('S2 .meta-line NO se habilita fuera de f9/f9b (no hay CSS alla: f12.css:735)',
   aMeta && aMeta.length === 2);

console.log('\n=== S3 ADMIN: captura unica del hero en Cimientos ===');
ok('S3 ev-hero-subtitulo existe como id exactamente UNA vez',
   count(/id="ev-hero-subtitulo"/g, ADMIN) === 1);
ok('S3 ev-d existe como id exactamente UNA vez',
   count(/id="ev-d"/g, ADMIN) === 1);
// El documento tiene DOS bloques data-wiz-step="1" y DOS "3" (estructura
// preexistente del wizard). Por eso el assert NO busca un rango fijo: toma el
// marcador data-wiz-step mas cercano ANTES del campo y el mas cercano DESPUES,
// y exige que el de antes sea el paso 1. Asi el assert sigue siendo valido si
// alguien reordena o duplica bloques.
function pasoEnvolvente(idxCampo) {
  const re = /data-wiz-step="(\d)"/g;
  let m, previo = null, siguiente = null;
  while ((m = re.exec(ADMIN))) {
    if (m.index < idxCampo) previo = Number(m[1]);
    else if (siguiente === null) { siguiente = Number(m[1]); break; }
  }
  return { previo: previo, siguiente: siguiente };
}
const _iSub = ADMIN.indexOf('id="ev-hero-subtitulo"');
const _iDesc = ADMIN.indexOf('id="ev-d"');
ok('S3 el subtitulo existe en el DOM', _iSub !== -1);
ok('S3 la descripcion existe en el DOM', _iDesc !== -1);
const _envSub = pasoEnvolvente(_iSub);
const _envDesc = pasoEnvolvente(_iDesc);
ok('S3 el subtitulo vive en el paso 1 (Cimientos)',
   _envSub.previo === 1 && _envSub.siguiente !== 1);
ok('S3 la descripcion ev-d vive en el paso 1 (Cimientos)',
   _envDesc.previo === 1 && _envDesc.siguiente !== 1);
ok('S3 los dos campos de hero quedaron en el MISMO bloque',
   _envSub.previo === _envDesc.previo && _envSub.siguiente === _envDesc.siguiente);
ok('S3 syncLineasSegunTemplate() existe y gobierna los campos L2',
   /function\s+syncLineasSegunTemplate/.test(ADMIN_CODE) &&
   /\[data-hero-meta-l2\]/.test(ADMIN_CODE));
ok('S3 la tabla de capacidad del admin declara f6 (afromango-editor) y f9 (mistico)',
   /_THEME_TITULO_2_LINEAS\s*=\s*\{\s*'afromango-editor':\s*true,\s*'mistico':\s*true\s*\}/.test(ADMIN_CODE));
ok('S3 la tabla del admin NO incluye f8 ni f9b (mismas exclusiones que el kernel)',
   !/_THEME_TITULO_2_LINEAS[^;]*(tropilove|mistico-nocturno)/.test(ADMIN_CODE));

console.log('\n=== S4 ADMIN: wizard de 5 pasos ===');
['1', '2', '3', '4', '5'].forEach((n) => {
  ok('S4 existe la pill data-pill="' + n + '"',
     new RegExp('data-pill="' + n + '"').test(ADMIN));
});
ok('S4 el paso 4 es "Registro + QR"', /data-pill="4"[^>]*>\s*<span[^>]*>4<\/span>\s*Registro \+ QR/.test(ADMIN));
ok('S4 el paso 5 es "Blindaje"', /data-pill="5"[^>]*>\s*<span[^>]*>5<\/span>\s*Blindaje/.test(ADMIN));
ok('S4 existe data-wiz-step="5" (el bloque Blindaje)', /data-wiz-step="5"/.test(ADMIN));
ok('S4 wizShow existe', /function\s+wizShow/.test(ADMIN_CODE));
ok('S4 los 5 pasos estan presentes y en orden (1..5 sin saltos)',
   ['1','2','3','4','5'].every(n => ADMIN.indexOf('data-wiz-step="' + n + '"') !== -1));
ok('S4 wizNext sigue el ordinal 5 (ya no 4)',
   /function\s+wizNext[\s\S]{0,700}?\b4\b\s*<\s*5|_wizStep\s*<\s*5/.test(ADMIN_CODE) ||
   /\b_wizStep\s*<\s*5/.test(ADMIN_CODE));
ok('S4 el boton Siguiente se oculta en el paso 5',
   /wiz-btn-next[\s\S]{0,400}?<\s*5/.test(ADMIN_CODE) || /_wizStep\s*<\s*5/.test(ADMIN_CODE));

console.log('\n=== S5 ADMIN: Registro + QR (formulario y segundo escaneo) ===');
ok('S5 existe el checkbox ev-form-qr-toggle', /id="ev-form-qr-toggle"/.test(ADMIN));
ok('S5 toggleFormQR() existe', /function\s+toggleFormQR/.test(ADMIN_CODE));
ok('S5 toggleFormQR delega en setEvSalida (mismo dato, no doble fuente)',
   /function\s+toggleFormQR[\s\S]{0,320}?setEvSalida\s*\(/.test(ADMIN_CODE));
ok('S5 setEvSalida espeja la casilla del paso 4 (sentido inverso)',
   /function\s+setEvSalida[\s\S]{0,2500}?ev-form-qr-toggle/.test(ADMIN_CODE));
ok('S5 ambos caminos escriben el MISMO _evCapturaPura',
   /function\s+toggleFormQR[\s\S]{0,320}?_evCapturaPura\s*=/.test(ADMIN_CODE) &&
   /function\s+setEvSalida[\s\S]{0,400}?_evCapturaPura\s*=/.test(ADMIN_CODE));
ok('S5 existe el checkbox ev-segundo-escaneo', /id="ev-segundo-escaneo"/.test(ADMIN));
ok('S5 el segundo escaneo se serializa en content.segundo_escaneo',
   /segundo_escaneo:\s*\(document\.getElementById\('ev-segundo-escaneo'\)\?\.checked\)/.test(ADMIN_CODE));
ok('S5 apagado emite null (clave podada por el sweep, no queda huerfana)',
   /segundo_escaneo:[\s\S]{0,200}?\?[\s\S]{0,200}?:\s*null/.test(ADMIN_CODE));
ok('S5 el segundo escaneo se REPOBLA al editar (read-back)',
   /content\.segundo_escaneo[\s\S]{0,400}?ev-segundo-escaneo-nombre/.test(ADMIN_CODE));
ok('S5 el toggle de QR del paso 4 tambien se repuebla al editar',
   /ev-form-qr-toggle[\s\S]{0,200}?_evCapturaPura/.test(ADMIN_CODE));

console.log('\n=== S6 ADMIN: diseno de ticket (medio archivo/url) ===');
ok('S6 existen las dos casillas de medio', /ticket-diseno-medio-chk/.test(ADMIN));
ok('S6 declara los medios archivo y url', /data-medio="archivo"/.test(ADMIN) && /data-medio="url"/.test(ADMIN));
ok('S6 el serializador emite la clave aditiva medio',
   /window\._ticketDisenosGetEntries[\s\S]{0,2000}?medio:/.test(ADMIN_CODE));
ok('S6 el preload lee la clave medio',
   /window\._ticketDisenosSetEntries[\s\S]{0,2000}?medio:/.test(ADMIN_CODE));
ok('S6 si no hay medio guardado se infiere por presencia de URL',
   /src\.medio\s*\|\|/.test(ADMIN_CODE));
ok('S6 el medio NO rompe el contrato congelado: tipo, diseno_url y activo siguen',
   /\{\s*tipo:\s*tipo,\s*diseno_url:\s*url,/.test(ADMIN_CODE));

console.log('\n=== S7 BUG-016: ticket_disenos no se borra al guardar ===');
ok('S7 rama (a) sin landing y sin formulario tiene el guard fail-open',
   /if\s*\(!_disenosPrevias\.length\)\s*return null;/.test(ADMIN_CODE));
ok('S7 rama (a) preserva ticket_disenos cuando si hay disenos',
   /cfgSinLanding\.content\.ticket_disenos\s*=\s*_disenosPrevias/.test(ADMIN_CODE));
ok('S7 rama (b) solo-formulario preserva ticket_disenos',
   /cfg\.content\.ticket_disenos\s*=\s*_disenosPrevias/.test(ADMIN_CODE));
ok('S7 la firma destructiva cfgLanding||null sigue existiendo (por eso hay guard)',
   /payload\.config_landing\s*=\s*cfgLanding\s*\|\|\s*null/.test(ADMIN_CODE));

console.log('\n=== S8 Cero Borrado: la pestana identidad sale de la barra, no del DOM ===');
const bloqueTabs = ADMIN_CODE.match(/var CONT_TABS = \[[\s\S]*?\];/);
ok('S8 CONT_TABS ya NO declara la pestana identidad',
   bloqueTabs && bloqueTabs[0].indexOf("id: 'identidad'") === -1);
ok('S8 el panel data-cont-tab="identidad" SIGUE en el DOM (Cero Borrado)',
   /data-cont-tab="identidad"/.test(ADMIN));
ok('S8 el panel identidad nace oculto para no ocupar espacio',
   /<div class="cont-tab-panel" data-cont-tab="identidad" style="display:none"><\/div>/.test(ADMIN));

console.log('\n=== S9 Estructura (balance de divs) ===');
const divDiff = (src) => count(/<div\b/gi, src) - count(/<\/div>/gi, src);
ok('S9 admin.html conserva el balance de divs del baseline (diff 3)', divDiff(ADMIN) === 3);
ok('S9 evento-app.html conserva el balance de divs del baseline (diff 1)', divDiff(KERNEL) === 1);

console.log('\n=== S10 GUARD: los asserts deben DETECTAR una regresion ===');
// Si un assert nunca puede fallar, no protege nada. Se muta una copia EN MEMORIA
// y se comprueba que el mismo chequeo ahora falla.
function contratoTituloRoto(src) {
  // regresion: vuelve el split automatico por palabras (con la llamada real)
  return /Math\.ceil\s*\(/.test(src);
}
ok('S10 el guard detecta el regreso del split automatico', contratoTituloRoto(
   KERNEL.replace('const __l1 = document.createElement',
     'const __mitad = Math.ceil(3); const __l1 = document.createElement')));
function allowlistRota(src) {
  const a = allowlistDe(src, '__esTitulo2Lineas');
  return JSON.stringify(a) === JSON.stringify(['tpl-f6', 'tpl-f9', 'tpl-f10', 'tpl-f13']);
}
ok('S10 el guard detecta que la allowlist del titulo se desalinea', !allowlistRota(
   KERNEL.replace("'tpl-f10', 'tpl-f13'", "'tpl-f10'")));
function idDuplicado(src) { return count(/id="ev-hero-subtitulo"/g, src) === 1; }
ok('S10 el guard detecta un id duplicado en el DOM', !idDuplicado(
   ADMIN.replace('id="ev-hero-subtitulo"', 'id="ev-hero-subtitulo" data-x="1"') +
   ' <input id="ev-hero-subtitulo">')); 
function panelBorrado(src) { return /data-cont-tab="identidad"/.test(src); }
ok('S10 el guard detecta la violacion de Cero Borrado (panel eliminado)', !panelBorrado(
   ADMIN.replace(/data-cont-tab="identidad"/g, 'data-cont-tab="__fuera__"')));

console.log('\n================================');
console.log('TOTAL asserts: ' + (pass + fail) + '   PASS: ' + pass + '   FAIL: ' + fail);
if (fail) { console.log('VEREDICTO: FAIL'); console.log('Fallaron: ' + fallos.join(' | ')); process.exit(1); }
console.log('VEREDICTO: PASS');
