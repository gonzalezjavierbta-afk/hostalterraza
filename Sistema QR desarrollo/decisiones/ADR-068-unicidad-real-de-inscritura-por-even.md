# ADR-068 — Unicidad real de inscritura por (evento_id, cédula) y endurecimiento del formulario de registro

**Fecha:** 2026-10-02
**Estado:** DECIDIDO (capa cliente IMPLEMENTADA y verificada; migración ESCRITA y **NO APLICADA**, pendiente del gate de riesgo)
**Ruta:** FREE (`opencode/big-pickle`, $0), modo express
**Dominio:** esquema/RLS → `@sql-security` para la aplicación;frontend → `@js-silo-dev` / `@frontend-tpl`

---

## Problema

Auditoría de `registroaforo.html` (el formulario público de captura) encontró que el guard de duplicados **no existía como garantía**, solo como cortesía de la interfaz:

```
SELECT id FROM inscritos WHERE cedula = ? AND evento_id = ?   <- pre-check, cliente
INSERT INTO inscritos ...                                     <- sin restricción
```

Cuatro consecuencias, todas verificadas contra el archivo real:

1. **Carrera de condición.** Dos pestañas abiertas pasan ambas el pre-check y las dos escriben. El botón se deshabilita, pero eso no cubre la pestaña hermana.
2. **Pre-check evadible por diseño.** La `anon key` está hardcodeada en el HTML público (`registroaforo.html:276-277`), así que el `POST` directo a PostgREST `/rest/v1/inscritos` salta el formulario completo.
3. **El formato era una vía de evasión.** `cedula` se guardaba tal cual el usuario la escribió, sin validar. `"12.345.678"` y `"12345678"` eran dos personas distintas para el `eq('cedula', ...)`, con lo que **el propio pre-check no veía el duplicado**.
4. **`maybeSingle()` amplificaba el fallo.** Devuelve error cuando hay **más de una** fila con la misma cédula, y el código solo desestructuraba `data`: con duplicados preexistentes, el flujo ignoraba el error y **insertaba una tercera copia**.

Además, la ausencia de validaciónPhone dejaba pasar cualquier texto en el código de país personalizado ("Otro"), que se concatenaba al teléfono sin comprobación.

---

## Decisiones

### D1 — Cédula: solo dígitos, sin algoritmo de control

`normalizeCedula()` deja **solo dígitos** (descarta puntos, guiones, espacios y letras) y `cedulaValida()` exige **5 a 12 dígitos**.

Se descarta deliberadamente el dígito de control colombiano: la cédula de disminuidor y la extranjera no lo siguen, y exigirlo rechazaría asistentes legítimos de un evento en Streaming/Hostal. El objetivo de este ADR es la **identidad canónica** (que dos escrituras de la misma persona converjan), no la validez documental.

`cedulaValida()` comprueba también que la cadena sea solo dígitos. Aunque el flujo normaliza antes de llamar, un validador que acepta `"1234567a"` no es un validador.

### D2 — WhatsApp: E.164 estricto, móvil colombiano obligatorio

`buildWhatsapp()` exige E.164 (`/^\+[1-9]\d{7,14}$/`). Para `+57` se exige **móvil de 10 dígitos que empiece en 3** (`/^3\d{9}$/`); el resto de países siguen el E.164 general.

Esto reemplaza la regla anterior (6 a 15 dígitos), que aceptaba secuencias que no son número de WhatsApp.

### D3 — Un único punto de canonicalización

Se crea una capa de normalización (`normalizeCedula`, `normalizePaisCode`, `normalizeNacional`, `buildWhatsapp`, `normalizeRol`) que se aplica **antes de validar, comparar y persistir**. El valor canónico es el que se guarda y el que se compara.

Esto cerró además un **bug funcional de consistencia**: el flujo "Ya estoy registrado" comparaba con `.eq('telefono', prefijo + telRaw.replace(/\D/g,''))` mientras el alta nueva guardaba el teléfono **sin limpiar**. Ese flujo **nunca encontraba** lo que el alta acababa de escribir. Ambos caminos usan hoy el mismo helper.

### D4 — Lista blanca del rol en la frontera

`?rol=` / `?tipo=` es texto libre de la URL y se persistía en `inscritos.tipo`. El `CHECK inscritos_tipo_check` (ADR-031) solo acepta 10 valores, así que un valor no listado provocaba un `400/23514` que el usuario veía como "problema al guardar".

El rol se depura **en `init()`**, en la frontera, contra `ROLES_INSCRITO` (los 10 valores del CHECK). Aguas abajo los consumidores siguen leyendo `window.__ctxRol`, que ya es un valor persistente: no se altera el contrato del ticket (guard S9 de `smoke_ticket_diseno.js`).

En la ruta "existente" el tipo de la fila sigue **mandando** sobre el rol (invariante del contrato), pero se depura en el mismo paso: una fila legacy con un tipo fuera de la lista colapsa al rol en vez de reventar el `INSERT`.

### D5 — Duplicados: pre-check honesto + UNIQUE en BD

- **Cliente:** el pre-check pasa de `maybeSingle()` a `.limit(1)` y **propaga su error** en vez de ignorarlo.
- **Servidor:** se escribe `migrations/adr068_inscritos_unique_cedula_evento.sql` con un índice **único parcial** sobre `(evento_id, cedula)` filtrado por `cuenta_aforo = true`.

El índice es **parcial a propósito**: existen filas auxiliares con `cuenta_aforo = false` (cortesías, lista negra, registros técnicos) que comparten cédula con leguria y no deben entrar en la restricción. Un UNIQUE total rompería los flujos que crean filas secundarias por persona y evento.

La migración queda **escrita y sin aplicar**: es dominio de riesgo y exige el gate de `AGENTS.md` §2.

### D6 — RLS y lectura anónima: `GRANT` por columna (decisión tomada sobre la opción 4)

El flujo "Ya estoy registrado" **necesita** leer una fila de `inscritos` por (cédula, teléfono). Cerrar el `SELECT` anónimo por completo obligaría a mover ese lookup a un RPC `SECURITY DEFINER`, que es un cambio de arquitectura con su propio ADR.

Decisión: **mantener el `SELECT` anónimo pero acotarlo por columnas.**

```sql
REVOKE SELECT ON inscritos FROM anon;
GRANT SELECT (id, evento_id, nombre, cedula, telefono, cliente_id, tipo) ON inscritos TO anon;
```

Con `SELECT` a nivel de columna, `select *` deja de devolver `qr_code`, `used`, `ref_codigo` ni `respuestas_custom`: el QR de entrada de todos los asistentes y el estado de canje dejan de ser públicos. El flujo de verificación sigue funcionando porque solo necesita las 7 columnas declaradas.

El paso previo es un `UPDATE` **no destructivo** que normaliza la cédula de las filas históricas a su forma canónica; si ese `UPDATE` genera colisiones, el índice del paso siguiente no debe crearse sin una decisión editorial de Dirección (Cero Borrado, Oro #2: la migración diagnostica y **no borra**).

Evolución pendiente, no bloqueante: RPC `SECURITY DEFINER` para el lookup.

### D7 — Rate limiting: sin límite por IP (decisión tomada sobre la opción 5)

Se decidió **no** añadir un contador por IP, por dos razones:

1. `migrations/adr038_freemium_limite_60.sql` ya acota el crecimiento por evento a 60 filas `cuenta_aforo`: el volumen bruto tiene techo.
2. Un límite por IP **castiga a los asistentes que comparten salida a evento** (celulares detrás de la misma carrier-grade NAT). En un evento de Streaming/Hostal es un falso positivo frecuente: se bloquea a la multitud y no al abusive.

Lo que sí se dominó con este ADR es el crecimiento **por colisión**, que era el agujero real. Además se añade un **honeypot** en el formulario (campo trampa fuera de pantalla; si viene relleno, se responde con la pantalla de éxito sin escribir nada, para no dar al bot una señal de reintento).

Si en producción aparece spam de volumen, el paso correcto es una **Edge Function de registro** con rate limit por IP y validación server-side. Eso es arquitectura y requiere su propio ADR (`@backend-dev`).

### D8 — CSS del campo telefónico: el silo no decide la geometría

El defecto visible (el `<select>` de código de país desalineado y desbordando) no era un error de espaciado sino de **cascada**: `injectAtomicCSS()` inyecta el silo **al final** de `<head>`, y los silos escriben sobre `select` con `padding: 1.2rem !important` y `width: 100%`, venciendo a la página.

Sin abandonar el silo (Aislamiento Atómico, Oro #9), la página fija ahora con `!important` lo que el silo pisa: `box-sizing: border-box`, `min-height`, `margin`, `padding`, tipografía heredada, y un `flex-basis`/`width`/`min-width`/`max-width` **cerrado** en el prefijo para que ningún padding pueda ensancharlo. `appearance: none` elimina la flecha nativa, que era la causa directa de la desalineación de altura contra el input vecino.

De paso se retira el **fondo morado `#14032C`** hardcodeado en `.wa-code option`, heredado de otra paleta: el color lo resuelve ahora el silo (o la variable de superficie del kernel), lo que además deja de obligar al silo f13 a mantener su override.

Se añade un breakpoint de 420 px donde el prefijo cede ancho antes que desbordar.

### D9 — Sin CDN externa para el QR

`qrcodejs` se servía desde `cdnjs.cloudflare.com`. Se **vendoriza** en `js/vendor/qrcode.min.js` (misma versión 1.0.0, API `QRCode` idéntica) y el `<script>` pasa a local.

Se evaluó migrar a `qr-creator` (deuda ADR-002) y se descartó **en esta pasada**: la librería está en uso en 15 archivos del repo y el cambio de API habría que replicarlo en todos, con el smoke de tickets assertando `new QRCode(qrBox`. Lo que la deuda信号 es —una dependencia de terceros desde una página pública— ya queda resuelto sin romper ningún call site.

### D10 — PII fuera de los logs del cliente

El log de éxito concatenaba **cédula y WhatsApp** en claro en la consola de quien se registraba. Se deja solo el `rol`, el flag de aforo y el id del evento.

---

## Red de verificación (lo que este archivo NO tenía)

`registroaforo.html` no estaba en `scripts/express_check.js` ni en ningún smoke, pese a ser el único archivo que **escribe** en `inscritos` con la clave anónima. Solo el balance de divs, que no detecta ni una regla de formato ni un color hardcodeado.

- `registroaforo.html` entra a `HTML_SET` de `express_check.js` (solo corre balance de divs sobre `.html`; no exige ASCII, y el archivo conserva sus banderas de país legítimas).
- Se crea `scripts/smoke_registroaforo_wa.js`: extrae la capa de normalización y la ejercita en `node:vm` como función pura (sin DOM ni red), más aserciones estáticas sobre el CSS, el pre-check, el manejo del `23505`, el honeypot, la ausencia de PII en logs y el balance de divs.

El smoke detectó **dos defectos reales durante la propia implementación**, ambos ya corregidos:

1. Una regresión en el invariante del ticket: blanquear el rol *aguas abajo* rompía la prioridad "tipo de la fila > rol" que el guard S9 verifica. Se movió el blanqueo a la frontera (`init()`), que es donde corresponde.
2. `cedulaValida()` solo miraba longitud y aceptaba `"1234567a"`.

---

## Deuda que queda

- Aplicar `migrations/adr068_inscritos_unique_cedula_evento.sql` (gate de riesgo).
- Decidir qué hacer con las colisiones históricas que reporte el paso 1 de la migración.
- Migrar el lookup de "Ya estoy registrado" a un RPC `SECURITY DEFINER`.
- Levantar el rate limit por IP si el honeypot resulta insuficiente.
- Migrar los 15 archivos que usan `qrcodejs` a `qr-creator` (ADR-002), fuera del alcance de este ADR.