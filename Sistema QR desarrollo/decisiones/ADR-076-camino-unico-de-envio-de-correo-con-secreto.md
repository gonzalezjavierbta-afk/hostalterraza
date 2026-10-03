---
doc: ADR-076
version: v1.17-GOLD (heredada de DECISIONS.md)
fecha: 2026-10-03
origen: sesion FREE 2026-10-03 (@sql-security + @backend-dev; migracion escrita el 2026-10-03, cierre documental de hoy). Gate de riesgo AGENTS.md seccion 2: AUTORIZADO por Direccion 2026-10-03 para aplicar; NO se ejecuto en este cierre.
version_previa: DECISIONS.md v1.17-GOLD
relacionados: [../DECISIONS.md, ../INDEX.md, ADR-068-unicidad-real-de-inscritura-por-even.md, ADR-072-atribucion-del-link-de-invitador-en-la-telemetria-del.md, ADR-073-columna-canonica-del-instante-del-evento-evento-inicio.md, ADR-074-configuracion-del-recordatorio-automatico-antes.md]
estado: vigente (ver campo Estado dentro del ADR)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [DECISIONS.md](../DECISIONS.md) - [INDEX](../INDEX.md).

## ADR-076: Camino unico de envio de correo con secreto del operador + traza de idempotencia

**Fecha:** 2026-10-03

**Autor:** @sql-security + @backend-dev (migracion escrita el 2026-10-03); cierre documental a cargo de @docs-keeper. Gate de riesgo de `AGENTS.md` seccion 2 (esquema) AUTORIZADO por Direccion el 2026-10-03; el alcance de la sesion fue SOLO documental, asi que **la migracion NO se ejecuto**.

**Estado:** DECIDIDO - migracion ESCRITA y **NO APLICADA** en base de datos.

**Problema (dos hallazgos, ambos de seguridad, verificados contra los archivos reales):**

1. **Envio de correo arbitrario con clave publica.** **5 archivos HTML** hacen POST a la Edge Function `send-ticket-email` con la **anon key del proyecto embebida** en la cabecera `Authorization`. La anon key es una credencial **PUBLICA**: esta en el HTML que cualquiera descarga. Con ella se puede pedir un correo a **CUALQUIER** destinatario con **CUALQUIER** contenido, desde el dominio del proyecto. Eso no es spam: es **relay de correo autenticado**, y lanza la reputacion del dominio y la del proveedor de correo. La autorizacion de la funcion no puede depender de una clave que el cliente ya tiene. Registrado en `migrations/adr076_enviar_email_seguro.sql:10-19`.
2. **`select *` anonimo sobre `inscritos`.** La recuperacion de entradas y el control de acceso hacen `select *` (o un `select` de varias columnas) con la anon key, devolviendo **nombre, cedula, telefono, email, `qr_code` y `used` de TODOS los asistentes**. No hay recorte por columnas en la base. Registrado en `:21-25`.

**Contexto:** ADR-068 ya habia decidido dejar el `SELECT` anonimo pero **acotado por columnas** (7 columnas, sin `qr_code`/`used`/`ref_codigo`/`respuestas_custom`), y esa parte **sigue escrita y sin aplicar**. Este ADR no repite ese recorte: agrega un camino nuevo al lado y deja el recorte para la iteracion D1, porque quitar la columna sin migrar los 3 call sites deja el formulario caido.

**Opciones:**
- (A) Cambiar la politica RLS de `inscritos` de una vez (recorte por columnas o por rol): afecta hoy a `registroaforo.html:908`, `eventobackup.html:3635` y `scanner.html:394`, que leen `select *`; sin migrarlos, el formulario de registro se cae. Descartada **para este pase**.
- (B) Que la anon key deje de ser la credencial y se migren los call sites a JWT de sesion: es la direccion correcta, pero exige tocar 5 HTML y es un cambio de codigo, no de esquema. Es trabajo de `@admin-dev`/`@js-silo-dev`, queda como tarea abierta; **no** es el alcance de una migracion.
- (C) **Agregar al lado** un camino que no acepta credencial del llamador (RPC `SECURITY DEFINER` que resuelve el secreto del operador) **y** una traza con llave unica de idempotencia: aditivo, reversible y no rompe a nadie. Elegida.

**Decision:** en `migrations/adr076_enviar_email_seguro.sql` (**1.494 lineas, 70.428 bytes**, el artefacto mas grande de la sesion), 11 bloques + bloque de verificacion. Tres piezas:

**Pieza 1 - `public.email_envios_log` (cola + traza).** `BLOQUE 1` (`:147-218`, `CREATE TABLE IF NOT EXISTS` en `:199`): doble funcion.
- **Idempotencia** (`BLOQUE 2`, `:219-300`): `idempotency_key` UNIQUE. Si la llave ya existe, no se reenvia; se devuelve el estado previo. `BLOQUE 3` (`:301-327`) crea 4 indices (`cedula+evento`, `evento`, `destinatario`, `ip`).
- **Memoria del futuro cron:** la tabla le dice a quien ya se le aviso, que es exactamente lo que TSK-003 necesita para no duplicar (ADR-074 da la ventana; esta tabla da el estado).
- **RLS fail-closed** en la tabla nueva + permisos de tabla (`BLOQUE 4`, `:328-365`).

**Pieza 2 - RPC `public.enviar_email_registro(...)` (camino unico permitido).** `BLOQUE 6` (`:633-1077`, firma en `:721-735`, 13 parametros, `SECURITY DEFINER` con `SET search_path = public, pg_temp` en `:738-739`).
- **NO recibe ni acepta credencial del llamador.** El secreto lo resuelve el servidor: `BLOQUE 5` helper `fn_adr076_secreto(p_nombre text)` (`:480`) lee `send_ticket_email_service_token` de **Supabase Vault**, con fallback a `app.settings.service_token` (`:851`, `:130`, `:89`). El token **nunca** se escribe en la traza, ni en un `RAISE NOTICE`, ni en el jsonb de respuesta (`:717-718`).
- **Si el secreto no existe, falla CERRADO con excepcion** (`:853`): `RAISE EXCEPTION '[ADR-076] no hay credencial de servicio configurada...'`. **Nunca envia correo de forma anonima.** Esa es la diferencia central contra el estado previo.
- `BLOQUE 7` (`:1078-1126`) documenta que tambien acepta el bearer de sesion como optcion de despliegue (`:715-716`), y por que el token **no** se traza.

**Pieza 3 - RPC `public.obtener_inscrito_por_cedula(...)` (reemplaza el `select *`).** `BLOQUE 6b` (`:1078-1233`, firma en `:1127-1136`): `SECURITY DEFINER`, `STABLE`, mismos `search_path` acotado.
- Devuelve los **campos minimos**; exige la **pareja `(cedula, evento_id)`**, nunca devuelve el email de terceros, y **solo devuelve `telefono` si el llamador lo aporta** como segundo factor (parametro `p_telefono`). El argumento esta escrito en `:1120-1124`: el recorte por columnas no oculta la EXISTENCIA de la fila, y el RPC si, porque la unica salida posible es el jsonb de esa firma.

**Permisos (critico):** `BLOQUE 8` (`:1234-1288`): PostgreSQL otorga `EXECUTE` a `PUBLIC` en **toda** funcion nueva, asi que el archivo **REVOCA a `PUBLIC`** y luego **GRANTea explicitamente**: `anon` y `authenticated` para los call sites publicos (que dejan de llevar credencial de correo y llevan una funcion que decide, `:1243-1245`), `service_role` para backend/panel/cron (y porque `p_bypass_rate_limit` solo se honra con ese rol, `:1246-1248`). **`fn_adr076_secreto` NO se otorga a `anon` ni a `authenticated`**: leer un secreto desde el navegador dejaria todo esto sin efecto (`:1249-1250`). `BLOQUE 8b` (`:1289-1298`) recarga el schema cache de PostgREST.

**Lo que NO hace esta migracion, deliberadamente:**
- **NO cambia ninguna politica RLS existente.** En particular **NO toca** los `SELECT` que hoy usan `registroaforo.html:908`, `eventobackup.html:3635` y `scanner.html:394`. Quitar el `select *` sin migrar esos 3 call sites deja el formulario de registro caido, asi que ese recorte es la **iteracion D1, con Direccion, NO este archivo** (`:41-45`, BLOQUE 9).
- **NO hace el `REVOKE SELECT` por columnas de ADR-068 paso 4**: tambien es D1, y el recorte por columnas vive en `migrations/adr068_inscritos_unique_cedula_evento.sql` (`:46-47`).
- **NO APLICA `migrations/adr068_inscritos_unique_cedula_evento.sql`**: sigue **escrito y sin aplicar** a proposito (`:48-49`, BLOQUE 10).
- **NO crea la extension `vault` ni la extension `pg_net`**: son administradas por la plataforma; el archivo solo las **usa** si ya estan (`:50-51`).
- **NO borra nada**: sin `DROP`, sin `DELETE`, sin `TRUNCATE` (`:52`, Cero Borrado / Oro #2).
- **NO loguea ni devuelve secretos** en ningun `RAISE NOTICE` (`:53`).
- **NO crea cron, ni trigger de envio, ni Edge Function.** (Esos son ADR-074 y la funcion de `supabase/functions/`.)

**Idempotencia:** 100% (`:59-63`): `CREATE TABLE IF NOT EXISTS`, `DO $$` con guarda en `pg_constraint` por CHECK, `CREATE INDEX IF NOT EXISTS`, `CREATE OR REPLACE FUNCTION` en las 4 funciones, y el `INSERT` de traza con `ON CONFLICT (idempotency_key) DO NOTHING` + re-lectura del estado previo. Se puede ejecutar 2+ veces sin error y sin duplicar traza.

**Consecuencias (registro obligatorio):**
- **Aplicar esta migracion NO cierra los hallazgos 1 y 2 por si sola.** Cierra el camino de correo autenticado *nuevo*; el viejo sigue abierto mientras los 5 call sites mandaten la anon key. **La Exposicion sigue viva hasta que los call sites migren** (tarea abierta, ver `TASKS.md`).
- **El RPC nuevo es un camino, no una sustitucion:** hasta que los call sites lo usen, nadie lo invoca y no cambia nada observable.
- **Falta el secreto del operador = correo roto, no correo abierto.** Es el fallo que se eligió: preferible un registro que no recibe confirmacion a un relay abierto.
- **Sin `pg_net` o sin Vault, la RPC devuelve error** (`BLOQUE 0`, `:78-143`, `:138-142`): fail-open para el usuario final, nunca envio anonimo. Los `WARNING` son visibles **en la misma corrida** en que se aplica el archivo, que es el propósito del bloque.

**Evidencia verificada contra el archivo real (ADR-006 — prevalece el archivo):**
- `migrations/adr076_enviar_email_seguro.sql`: existe, **1.494 lineas**, **70.428 bytes** (el mas grande de la sesion). Anclas: `:94-143` pre-flight; `:199` `CREATE TABLE IF NOT EXISTS public.email_envios_log`; `:313-322` 4 indices; `:404` `fn_adr076_texto_limpio`; `:480` `fn_adr076_secreto`; `:571` `fn_adr076_ip_origen`; `:721` `enviar_email_registro`; `:851` lectura del secreto; `:853` `RAISE EXCEPTION` fail-closed; `:1127` `obtener_inscrito_por_cedula`; `:1234-1288` REVOKE/GRANT.
- `:68-70` el propio archivo declara `ESTADO: ESCRITO, NO APLICADO`.
- **DISCREPANCIA DETECTADA (ADR-006): el archivo declara en `:65-66` "ASCII-SAFETY ESTRICTA: 0 bytes > 127 en todo el archivo, incluidos los comentarios", y el archivo real tiene 11 bytes > 127 en 3 lineas de comentario** (`:549`, `:557`, `:1100`, texto corrupt tipo `compartiri\u025dn`). **Solo afecta a comentarios**, no a la ejecucion del SQL, y las 3 rutas siguen siendo ejecutables; pero la afirmacion de ASCII-safety del artefacto es **FALSA**. No se corrige en este cierre documental (prohibida toda edicion de codigo); queda como TSK-106. Las otras dos migraciones si son ASCII puras (verificadas: 0 bytes > 127).
- Los **5 call sites NO estan migrados** (verificado hoy con `Select-String` en los archivos reales): siguen mandando la anon key y hay **0 ocurrencias de `access_token`** en los 5. Detalle en la seccion siguiente.
- Las 3 rutas de migraciones de esta sesion siguen **sin aplicar**; no hay en el repo ninguna evidencia de ejecucion. `adr068_inscritos_unique_cedula_evento.sql` tampoco.

**HALLAZGO CRITICO DE ESTE CIERRE - los 5 call sites NO estan migrados y el header de la funcion afirma lo contrario:**

| Archivo | Linea del POST | Que manda | Donde esta la key |
|---|---|---|---|
| `admin.html` | **8153** (fetch) / 8158 (header) | `Bearer eyJhbGci...` **hardcodeado** dentro del `Bearer` en `enviarQREmail` (definida en `:8151`) | la misma linea 8158 |
| `registro.html` | **678** | `'Bearer ' + SUPABASE_KEY` | `registro.html:451` |
| `registroaforo.html` | **1010** | `'Bearer ' + SB_KEY` | `registroaforo.html:329` |
| `serie.html` | **994** | `'Bearer ' + SUPABASE_KEY` | `serie.html:344` |
| `eventobackup.html` | **4449** | `'Bearer ' + SUPABASE_KEY` | `eventobackup.html:3484` |

Los 5 JWT son el mismo token de rol `anon` del proyecto `ctgyvydzshueemlelkzv`. Conteo verificado de `access_token`: **0** en cada uno de los 5 archivos.

El header de `supabase/functions/send-ticket-email/index.ts` afirma en **`:46`** que el canal JWT "es el canal de `admin.html` y `registro.html`, **ya migrados a token real**". **Eso es FALSO contra los archivos** (ADR-006: prevalece el archivo). El comentario se esta corrigiendo aparte en la misma sesion y este ADR no lo toca (prohibida toda edicion de codigo).

**Consecuencia operativa, la mas importante de este ADR:** **desplegar la funcion sin migrar los call sites ROMPE el correo en los 5 sitios** (reciben 401 y no se envia nada). Ese 401 es el comportamiento previsto durante la transicion, **no un fallo** — pero significa que el orden de despliegue no es opcional.

**ORDEN DE DESPLIEGUE (3 pasos, taken del header de `index.ts:49-63`):**
1. `supabase functions deploy send-ticket-email --no-verify-jwt` — desplegar **sin** exigir JWT en el gateway, para poder migrar los call sites sin que el gateway los rechace antes de tiempo. Durante la transicion los call sites que hoy mandan la anon key reciben 401 y no se envia correo: es lo esperado.
2. **Migrar los 5 call sites** a mandar el JWT de sesion real (`session.access_token`) o `X-Service-Token` desde `pg_net`.
3. `supabase functions deploy send-ticket-email` — solo entonces exigir JWT en el gateway.

Y por separado, en base de datos: aplicar las 3 migraciones de esta sesion (ADR-073, luego ADR-074, luego ADR-076) **desde el SQL Editor con `service_role`**. Orden por dependencia: ADR-073 antes que ADR-074; ADR-076 es independiente de ambas pero su RPC llama a la Edge Function, que debe existir primero.

**Nota de arquitectura que DECIDIO Direccion hoy (2026-10-03) y que hay que leer con sus consecuencias:** la arquitectura del canal de envio es **"JWT de sesion donde exista"**. Consecuencia registrada como riesgo/deuda: `admin.html`, `registro.html` y `serie.html` tienen sesion y pueden mandar `session.access_token`; **`registroaforo.html` es el formulario PUBLICO y no tiene sesion**, asi que con esta decision su envio de correo **sigue sin poder autenticarse** y `enviarNotificacionesReg()` permanece el no-op de siempre (`emailAddr` siempre `null`, porque el formulario no tiene campo email: `registroaforo.html:726` y `:860` pasan `null`, y `:1006` hace `if (!emailAddr) return;`). Ese caso queda como **tarea abierta sin decidir**: la salida es la RPC `enviar_email_registro` de esta migracion (que no necesita credencial del llamador), pero **la adopcion no esta decidida**.

**Impacto:** 1 tabla nueva, 4 funciones nuevas, 4 indices nuevos, RLS activada en la tabla nueva, 1 `REVOKE PUBLIC` + `GRANT` explicitos. 0 politicas existentes modificadas, 0 tablas alteradas, 0 filas borradas. En el cliente: **0 archivos** (los call sites todavia no migran).

**Rollback:** no hay un unico `ROLLBACK` global al final del archivo; el rollback es **por pieza** y esta documentado en los bloques: quitar los `GRANT` y `REVOKE` (BLOQUE 8) y `DROP FUNCTION` de las 3 RPC y los 3 helpers (bloques 5-7) restituyen el estado de permisos; `DROP TABLE public.email_envios_log` (BLOQUE 1) borra la traza — **si** ya se registro traza real, ese `DROP` es destructivo y Cero Borrado choca con el. Todo ello requiere gate de riesgo.

**Referencias cruzadas:** ADR-063 (flujo de entrega y recuperacion de QR en `registroaforo.html`, origen del `enviarNotificacionesReg` y del `select *`), ADR-064 (diseno de ticket por tipo, fuente del adjunto `ticketUrl`), ADR-068 (unicidad `(evento_id, cedula)`: sigue escrita y sin aplicar; su recorte por columnas es D1), ADR-072 (ultimo ADR cerrado, convencion de este archivo), ADR-073 (`evento_inicio`, independiente), ADR-074 (`config_recordatorios`: el cron futuro leera aqui y escribira la traza en `email_envios_log`), TSK-003 (pg_cron de recordatorios), TSK-081 (c) (deuda asociada al envio de correo: **esta migracion la versiona pero no la cierra**), TSK-088 (adjuntar el ticket al correo: lo resuelve la Edge Function versionada, no esta migracion).

**Estado real pieza por pieza:**

| Pieza | Estado | Nota |
|---|---|---|
| `migrations/adr076_enviar_email_seguro.sql` | ESCRITO, NO APLICADO | 1.494 lineas; ver discrepancia ASCII en Evidencia |
| `public.email_envios_log` | NO EXISTE EN BD | bloque 1 |
| RPC `enviar_email_registro(...)` | NO EXISTE EN BD | bloque 6; fail-closed sin secreto |
| RPC `obtener_inscrito_por_cedula(...)` | NO EXISTE EN BD | bloque 6b |
| 3 helpers + 4 indices | NO EXISTEN EN BD | bloques 3 y 5 |
| `REVOKE PUBLIC` + `GRANT` por rol | NO EJECUTADOS | bloque 8; hoy `anon` puede invocar cualquier funcion nueva |
| Recorte del `select *` anonimo | **NO HECHO POR DECISION (D1)** | requiere migrar antes `registroaforo.html:908`, `eventobackup.html:3635`, `scanner.html:394` |
| `REVOKE SELECT` por columnas de ADR-068 | **NO HECHO POR DECISION (D1)** | vive en `adr068`, no aqui |
| `adr068_inscritos_unique_cedula_evento.sql` | **SIGUE ESCRITO Y SIN APLICAR** | bloque 10; no se aplica aqui |
| Secretos `send_ticket_email_service_token` (Vault) / `app.settings.service_token` | **NO CONFIGURADOS** | sin ellos la RPC falla cerrado |
| Migracion de los 5 call sites | **PENDIENTE** | codigo, no SQL; ninguna de las 2 rutas existe todavia |

**Nota de numeracion:** el ID `ADR-076` **salta el `ADR-075`**, que no existe (ni archivo en `decisiones/` ni migracion `adr075*` en `migrations/`). Motivo: **no consta en el repo**. Se registra como **numero no asignado / hueco de numeracion documentado**, no como decision tomada; ver la nota de numeracion en `DECISIONS.md`. `ADR-076` no reutiliza ni salta ningun otro ID (`ADR-074` es el ultimo ocupado).