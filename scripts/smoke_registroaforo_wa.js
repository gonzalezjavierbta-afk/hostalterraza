/* ============================================================================
 * smoke_registroaforo_wa.js
 * ----------------------------------------------------------------------------
 * Red de seguridad del formulario de registro (registroaforo.html).
 *
 * MOTIVACION: registroaforo.html escribe en la tabla inscritos con la anon key y no
 * estaba en scripts/express_check.js ni en ningun smoke. Su unica red era el
 * balance de divs, que no detecta ni una regla de formato ni un color hardcodeado.
 *
 * QUE CUBRE:
 *   S1  Capa de normalizacion canonica (unidad): cedula, prefijo, telefono E.164
 *   S2  Formato de cedula (5-12 digitos, solo digitos)
 *   S3  Prefijo internacional (+1 a +4 digitos, sin cero inicial)
 *   S4  Movil colombiano estricto (10 digitos, empieza en 3) y E.164 en el resto
 *   S5  Lista blanca de rol contra inscritos_tipo_check (ADR-031)
 *   S6  El prefijo se neutraliza en la frontera (init), no aguas abajo
 *   S7  Pre-check de duplicado usa .limit(1) y NO maybeSingle()
 *   S8  La carrera 23505 cae en la pantalla de duplicado, no en error generico
 *   S9  Honeypot presente y descarta el envio antes de escribir
 *   S10 Sin PII (cedula/whatsapp) en los logs del cliente
 *   S11 CSS del campo telefonico: scopeado, con !important de geometria, sin
 *       fondo morado hardcodeado y sin CDN de qrcodejs
 *   S12 Balance de divs intacto
 *
 * USO: node scripts/smoke_registroaforo_wa.js   (salida 0 = VEREDICTO PASS)
 * ASCII-only a proposito: scripts/ pasa el control de ASCII de express_check.js.
 * ========================================================================= */

'use strict';

var fs = require('fs');
var path = require('path');
var vm = require('vm');

var ROOT = path.resolve(__dirname, '..');
var FILE = path.join(ROOT, 'registroaforo.html');

var pass = 0;
var fail = 0;
var fails = [];

function log(s) { process.stdout.write(s + '\n'); }

function ok(cond, label, detail) {
  if (cond) { pass += 1; log('  PASS  ' + label); }
  else {
    fail += 1;
    fails.push(label + (detail ? ' :: ' + detail : ''));
    log('  FAIL  ' + label + (detail ? ' -> ' + detail : ''));
  }
}

function eq(actual, expected, label) {
  ok(actual === expected, label,
    'got ' + JSON.stringify(actual) + ', want ' + JSON.stringify(expected));
}

function countIn(text, needle) {
  return text.split(needle).length - 1;
}

/* Extrae el cuerpo de una funcion por nombre, contando llaves y saltando los
   cuantificadores de regex tipo \d{9}, que de otro modo descuadran el conteo. */
function extractFn(src, name) {
  var re = new RegExp('function\\s+' + name + '\\s*\\(');
  var m = re.exec(src);
  if (!m) return null;
  var start = m.index;
  var i = src.indexOf('{', start);
  if (i === -1) return null;
  var depth = 0;
  var opened = false;
  for (; i < src.length; i += 1) {
    var quant = /^\{\d+(,\d*)?\}/.exec(src.slice(i, i + 8));
    if (quant) { i += quant[0].length - 1; continue; }
    var ch = src.charAt(i);
    if (ch === '{') { depth += 1; opened = true; }
    else if (ch === '}') {
      depth -= 1;
      if (opened && depth === 0) { i += 1; break; }
    }
  }
  return src.slice(start, i);
}

function inlineJs(src) {
  var blocks = [];
  var re = /<script[^>]*>([\s\S]*?)<\/script>/g;
  var m;
  while ((m = re.exec(src)) !== null) {
    if (m[1].trim().length > 50) blocks.push(m[1]);
  }
  return blocks.join('\n;\n');
}

function main() {
  if (!fs.existsSync(FILE)) {
    log('FATAL: no existe registroaforo.html');
    process.exitCode = 2;
    return;
  }

  var src = fs.readFileSync(FILE, 'utf8');
  var js = inlineJs(src);

  /* Monta un contexto con SOLO la capa de normalizacion, para poder ejercitarla
     como funcion pura sin DOM ni red. Si falta una funcion, se reporta aqui. */
  var NEEDED = [
    'normalizeCedula', 'cedulaValida', 'normalizePaisCode',
    'normalizeNacional', 'buildWhatsapp', 'normalizeRol', 'esTelefonoValido'
  ];
  /* Constantes de modulo: las funciones las leen del ambito, asi que el sandbox
     tambien necesita las declaraciones, no solo los cuerpos. */
  var CONSTS = ['ROLES_INSCRITO', 'CEDULA_MIN', 'CEDULA_MAX'];
  var sandbox = {};
  var faltan = [];
  var code = '';
  for (var c = 0; c < CONSTS.length; c += 1) {
    var cre = new RegExp('const\\s+' + CONSTS[c] + '\\s*=[^;]*;');
    var cm = cre.exec(js);
    if (cm) code += cm[0] + '\n';
  }
  for (var i = 0; i < NEEDED.length; i += 1) {
    var fn = extractFn(js, NEEDED[i]);
    if (!fn) { faltan.push(NEEDED[i]); continue; }
    code += fn + '\n';
  }
  code += 'this.__api = { normalizeCedula: normalizeCedula, cedulaValida: cedulaValida,' +
    ' normalizePaisCode: normalizePaisCode, normalizeNacional: normalizeNacional,' +
    ' buildWhatsapp: buildWhatsapp, normalizeRol: normalizeRol, esTelefonoValido: esTelefonoValido };';

  var sePudoCargar = false;
  try {
    vm.createContext(sandbox);
    vm.runInContext(code, sandbox, { timeout: 3000 });
    sePudoCargar = true;
  } catch (err) {
    log('  FAIL  la capa de normalizacion no compila en vm -> ' + err.message);
    fail += 1;
    fails.push('capa de normalizacion no compila');
  }

  ok(sePudoCargar, 'S1 la capa de normalizacion existe y compila',
    faltan.length ? 'funciones ausentes: ' + faltan.join(', ') : undefined);
  ok(faltan.length === 0, 'S1 las 7 funciones de normalizacion estan definidas',
    faltan.length ? 'ausentes: ' + faltan.join(', ') : undefined);

  if (sePudoCargar) {
    var A = sandbox.__api;

    /* S1 - cedula: canonico = solo digitos */
    eq(A.normalizeCedula('12.345.678'), '12345678', 'S1 cedula "12.345.678" -> "12345678"');
    eq(A.normalizeCedula(' 12 345 678 '), '12345678', 'S1 cedula con espacios -> solo digitos');
    eq(A.normalizeCedula('ab-12.34'), '1234', 'S1 cedula con letras -> descarta letras');
    eq(A.normalizeCedula(''), '', 'S1 cedula vacia -> vacia');
    eq(A.normalizeCedula(null), '', 'S1 cedula null -> vacia');

    /* S1/S2 - longitud de cedula */
    ok(A.cedulaValida('12345678') === true, 'S2 cedula de 8 digitos valida');
    ok(A.cedulaValida('12345') === true, 'S2 cedula de 5 digitos valida (borde inferior)');
    ok(A.cedulaValida('123456789012') === true, 'S2 cedula de 12 digitos valida (borde superior)');
    ok(A.cedulaValida('1234') === false, 'S2 cedula de 4 digitos rechazada');
    ok(A.cedulaValida('1234567890123') === false, 'S2 cedula de 13 digitos rechazada');
    ok(A.cedulaValida('') === false, 'S2 cedula vacia rechazada');
    ok(A.cedulaValida('1234567a') === false, 'S2 cedula con letra rechazada (no se auto-normaliza aqui)');

    /* S3 - prefijo internacional */
    eq(A.normalizePaisCode('57'), '+57', 'S3 prefijo "57" -> "+57"');
    eq(A.normalizePaisCode('+593'), '+593', 'S3 prefijo "+593" se mantiene');
    eq(A.normalizePaisCode('abc'), null, 'S3 prefijo "abc" rechazado');
    eq(A.normalizePaisCode('+'), null, 'S3 prefijo "+" solo rechazado');
    eq(A.normalizePaisCode('0'), null, 'S3 prefijo "0" rechazado (cero inicial)');
    eq(A.normalizePaisCode('12345'), null, 'S3 prefijo de 5 digitos rechazado');
    eq(A.normalizePaisCode('1234'), '+1234', 'S3 prefijo de 4 digitos aceptado (borde)');
    eq(A.normalizePaisCode(''), null, 'S3 prefijo vacio rechazado');

    /* S4 - movil colombiano estricto */
    var wa = A.buildWhatsapp('+57', '3001234567');
    ok(wa.ok === true, 'S4 movil colombiano valido aceptado');
    eq(wa.ok === true ? wa.valor : null, '+573001234567', 'S4 E.164 armado sin espacios');
    ok(A.buildWhatsapp('+57', '2001234567').ok === false, 'S4 movil que NO empieza en 3 rechazado');
    ok(A.buildWhatsapp('+57', '300123456').ok === false, 'S4 movil de 9 digitos rechazado');
    ok(A.buildWhatsapp('+57', '30012345678').ok === false, 'S4 movil de 11 digitos rechazado');
    ok(A.buildWhatsapp('+57', '300 123 4567').ok === true, 'S4 espacios en el movil se normalizan');
    var ec = A.buildWhatsapp('+593', '987654321');
    ok(ec.ok === true, 'S4 movil de Ecuador (no +57) aceptado');
    eq(ec.ok === true ? ec.valor : null, '+593987654321', 'S4 E.164 de Ecuador bien armado');
    ok(A.buildWhatsapp('+57', '').ok === false, 'S4 numero vacio rechazado');
    eq(A.buildWhatsapp('abc', '3001234567').ok, false, 'S4 prefijo invalido da motivo reg.pais_codigo_err');
    eq(A.buildWhatsapp('abc', '3001234567').motivo, 'reg.pais_codigo_err', 'S4 motivo del prefijo invalido');
    eq(A.buildWhatsapp('+57', '2001234567').motivo, 'reg.wa_movil_10', 'S4 motivo del movil colombiano invalido');
    eq(A.buildWhatsapp('+1', '5').motivo, 'reg.wa_invalido', 'S4 motivo de E.164 no valido');
    ok(A.esTelefonoValido('3001234567') === true, 'S4 esTelefonoValido acepta movil de 10');
    ok(A.esTelefonoValido('1234567') === false, 'S4 esTelefonoValido rechaza 7 digitos (regla vieja lo aceptaba)');

    /* S5 - lista blanca de rol (CHECK inscritos_tipo_check, ADR-031) */
    eq(A.normalizeRol('invitado', 'x'), 'invitado', 'S5 rol valido se conserva');
    eq(A.normalizeRol('INVITADO', 'x'), 'invitado', 'S5 rol en mayusculas se normaliza');
    eq(A.normalizeRol('  artista ', 'x'), 'artista', 'S5 rol con espacios se normaliza');
    eq(A.normalizeRol('basura', 'artista'), 'artista', 'S5 rol desconocido cae al fallback valido');
    eq(A.normalizeRol('basura', 'basura2'), 'invitado', 'S5 rol y fallback desconocidos caen a invitado');
    eq(A.normalizeRol(null, 'voluntario'), 'voluntario', 'S5 rol null cae al fallback');
    ok(countIn(js, "'interesado'") === 1, 'S5 la lista incluye el valor intereses de ADR-031');
    ok(js.indexOf('invitado') !== -1 && js.indexOf('donacion') !== -1, 'S5 la lista cubre los 10 valores del CHECK');
  }

  /* S6 - el rol se blanquea en la frontera (init), aguas abajo se lee igual */
  ok(js.indexOf("const rol = normalizeRol(params.get('rol')") !== -1,
    'S6 init blanquea el rol contra la lista blanca');
  ok(countIn(js, 'const rol = window.__ctxRol') === 2,
    'S6 los dos consumidores siguen leyendo window.__ctxRol (contrato del ticket)');
  ok(js.indexOf('window.__ctxRol = rol') !== -1, 'S6 window.__ctxRol se asigna ya depurado');

  /* S7 - pre-check de duplicado robusto.
   Se evalua sobre el codigo SIN comentarios: el comentario que explica el
   cambio menciona maybeSingle() a proposito, y matchearlo daria un falso PASS. */
  var jsLines = js.split('\n').filter(function (l) {
    return !/^\s*(\/\/|\*|\/\*)/.test(l);
  });
  var jsCode = jsLines.join('\n');
  /* El pre-check busca solo la columna 'id'; los otros dos maybeSingle() legos
     piden la fila completa o datos de invitadores. El patron del bug era
     justamente select('id') combinado con maybeSingle(). */
  ok(jsCode.indexOf(".from('inscritos').select('id').eq('cedula', cedula).eq('evento_id', ev.id).limit(1)") !== -1,
    'S7 el pre-check de duplicado usa .limit(1)');
  var precheckBuggy = jsLines.filter(function (l) {
    return /maybeSingle\(\)/.test(l) && /select\('id'\)/.test(l);
  });
  eq(precheckBuggy.length, 0,
    'S7 ningun pre-check combina select("id") con maybeSingle() (fallaba con >1 fila y seguia insertando)');
  ok(jsCode.indexOf('dupErr') !== -1, 'S7 el error del pre-check se propaga en vez de ignorarse');
  ok(jsCode.indexOf('dup && dup.length > 0') !== -1, 'S7 el pre-check evalua el arreglo, no solo truthiness');
  /* Quedan 2 maybeSingle() y ambos son legitimos: la atribucion del
     invitador (?ref=) y mostrarDuplicado, que lee la fila para pintarla. */
  eq(countIn(jsCode, 'maybeSingle()'), 2, 'S7 quedan 2 maybeSingle(), ambos intencionales');
  ok(jsCode.indexOf('if (error || !data)') !== -1,
    'S7 mostrarDuplicado maneja su error (degrada a "no encontrado", no queda en blanco)');

  /* S8 - la carrera de condicion cae en la pantalla de duplicado */
  eq(countIn(js, "err.code === '23505'"), 2, 'S8 ambos INSERT manejan el 23505 de la UNIQUE');
  ok(countIn(js, 'mostrarDuplicado(cedula)') >= 1, 'S8 el 23505 deriva a la pantalla de duplicado');

  /* S9 - honeypot */
  ok(js.indexOf("getElementById('reg-hp')") !== -1, 'S9 el honeypot se lee en el submit');
  ok(src.indexOf('id="reg-hp"') !== -1, 'S9 el campo trampa existe en el marcado');
  ok(js.indexOf('honeypot') !== -1, 'S9 la guarda del honeypot esta presente');
  ok(js.indexOf('name="tipo"') === -1, 'S9 el honeypot no introduce un atributo name');

  /* S10 - sin PII en logs del cliente */
  var logLines = js.split('\n').filter(function (l) { return /log\(/.test(l); });
  var conPII = logLines.filter(function (l) {
    return /log\(.*(cedula|whatsapp|telefono)\s*=/.test(l) && !/codigo_/.test(l);
  });
  eq(conPII.length, 0, 'S10 ningun log del cliente concatena cedula/whatsapp/telefono');
  ok(logLines.length > 0, 'S10 el archivo sigue usando log() (el control tiene teeth)');

  /* S11 - CSS del campo telefonico */
  ok(src.indexOf('body.page-registro .wa-code {') !== -1, 'S11 la regla del prefijo esta scopeada en body.page-registro');
  ok(src.indexOf('flex: 0 0 132px !important') !== -1, 'S11 el prefijo tiene ancho fijo con !important');
  ok(src.indexOf('appearance: none !important') !== -1, 'S11 el prefijo quita la flecha nativa (causa de la desalineacion)');
  ok(src.indexOf('font-family: inherit !important') !== -1, 'S11 el select hereda la tipografia del input vecino');
  ok(src.indexOf('box-sizing: border-box !important') !== -1, 'S11 box-sizing-border-box para que el padding no infle el ancho');
  ok(src.indexOf('max-width: 132px !important') !== -1, 'S11 el prefijo no puede crecer por el padding del silo');
  ok(src.indexOf('min-height: 52px !important') !== -1, 'S11 select e input comparten altura minima');
  ok(/wa-code option\s*\{[^}]*background:\s*var\(--p-bg-2/.test(src), 'S11 el fondo de las opciones lo resuelve el silo, no un morado fijo');
  ok(src.indexOf('background: #14032C') === -1 && src.indexOf('background: #14002C') === -1,
    'S11 desaparece el morado hardcodeado heredado de otra paleta');
  ok(src.indexOf('@media (max-width: 420px)') !== -1, 'S11 hay breakpoint para pantallas estrechas');
  ok(src.indexOf('body.page-registro .wa-row {') !== -1, 'S11 la fila del campo telefonico sigue presente');

  /* S11b - sin CDN externa para el QR (ADR-002) */
  ok(src.indexOf('cdnjs.cloudflare.com/ajax/libs/qrcodejs') === -1,
    'S11 registroaforo.html no carga qrcodejs desde CDN');
  ok(src.indexOf('js/vendor/qrcode.min.js') !== -1, 'S11 el QR se sirve desde el vendor local');
  ok(fs.existsSync(path.join(ROOT, 'js', 'vendor', 'qrcode.min.js')),
    'S11 el vendor js/vendor/qrcode.min.js existe en disco');

  /* S12 - balance de divs intacto */
  var opens = countIn(src, '<div');
  var closes = countIn(src, '</div>');
  eq(opens - closes, 0, 'S12 balance de divs (abre=' + opens + ' cierra=' + closes + ')');

  log('');
  log('================================================================');
  log('TOTAL asserts: ' + (pass + fail) + '   PASS: ' + pass + '   FAIL: ' + fail);
  if (fail > 0) {
    log('');
    log('FALLAS:');
    for (var f = 0; f < fails.length; f += 1) log('  ' + (f + 1) + ') ' + fails[f]);
    log('');
    log('VEREDICTO: FAIL');
    process.exitCode = 1;
  } else {
    log('VEREDICTO: PASS');
  }
}

main();