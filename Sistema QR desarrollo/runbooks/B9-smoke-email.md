---
doc: B9-smoke-email.md
version: v1.0
fecha: 2026-11-01
autor: @qa-auditor (F0 - verificacion estatica + runbook)
estado: vigente
relacionados: [NEXT.md (hito -43, B9), TASKS.md (FASE 2B), ADR-076, ADR-077, ADR-078, ERRORES_HISTORICOS.md E30]
nota: Este runbook NO modifica codigo de producto ni migraciones. Todo el SQL es de datos de prueba.
---

# B9 - Smoke end-to-end RPC -> Edge Function -> Resend

Cierra el bloqueador B9 (NEXT.md:222 y :224; TASKS.md:358) demostrando, con evidencia, que un correo
sale por la ruta completa: RPC `public.enviar_email_registro` -> Edge Function `send-ticket-email` ->
API de Resend -> bandeja del destinatario.

Lo ejecuta una persona en el **SQL Editor de Supabase** del proyecto `ctgyvydzshueemlelkzv`
(rol `postgres`, equivalente a `service_role` para este proposito). La IA no tiene credenciales.

---

## 0. Advertencia critica antes de empezar

1. El cron `recordatorios-horarios` recorre **todos** los eventos cuya `evento_inicio` caiga en
   +/- 2 h de `fn_horas_recordatorio(evento_id)` y manda correo a **todos** sus inscritos con email.
   **NUNCA** muevas un evento real dentro de la ventana para probar: se le escribe a personas reales.
   El runbook crea un evento FICTICIO y aisla la ventana con su propia fila de `config_recordatorios`.
2. Usa un correo propio (no de un tercero). El remitente real hoy es
   `Taquilla Directa <no-reply@tickets.taquilladirecta.com>`.
3. Todos los identificadores de prueba empiezan por `b9-smoke`. La limpieza (paso 6) es **acotada a
   ese prefijo**; no hay DROP, no se toca ningun dato preexistente (Cero Borrado, Oro #2).
4. Si algo falla, **no** des `COMMIT` de fixtures a medias: el paso 1 es una sola transaccion.

---

## 1. Contrato real (auditado en el archivo, ADR-006)

### 1.1 Firma de `public.enviar_email_registro`
`migrations/adr076_enviar_email_seguro.sql:731-745` (SECURITY DEFINER, `search_path = public, pg_temp`):

| # | Parametro | Tipo | Default | Obligatorio de facto |
|---|---|---|---|---|
| 1 | `p_email` | text | - | si (regex `:814`, 254 chars) |
| 2 | `p_nombre` | text | - | no (`:790` con `false`) |
| 3 | `p_qr_code` | text | - | **si** (`:791` con `true`, 600 chars) |
| 4 | `p_evento_nombre` | text | - | no (200) |
| 5 | `p_evento_fecha` | text | - | no (80) |
| 6 | `p_evento_hora` | text | - | no (20) |
| 7 | `p_evento_lugar` | text | - | no (200) |
| 8 | `p_idempotency_key` | text | - | **si** (`:798` con `true`, 200) |
| 9 | `p_tipo` | text | `'registro'` | no; valores validos `registro`, `bienvenida`, `recordatorio` (`:805-808`, ERRCODE `22023`) |
| 10 | `p_cedula` | text | NULL | no (32; se normaliza a digitos, `:827-832`) |
| 11 | `p_evento_id` | text | NULL | no |
| 12 | `p_inscrito_id` | text | NULL | no |
| 13 | `p_bypass_rate_limit` | boolean | `false` | solo se honra si el rol es `service_role` (`:839`) |

Retorno `jsonb`: `ok`, `estado`, `motivo`, `id`, y `pg_net_request_id` en el camino feliz
(`:1040-1046`). Estados posibles en `email_envios_log.estado`: `pendiente`, `enviado`, `error`,
`omitido` (`:264-276`).

### 1.2 `public.email_envios_log` (columnas reales, `:209-225`)
`id` uuid PK, `evento_id` text, `inscrito_id` text, `destinatario` text NOT NULL, `tipo` text NOT NULL
default `'registro'`, `estado` text NOT NULL default `'pendiente'`, `intentos` integer NOT NULL default 0,
`idempotency_key` text **UNIQUE**, `error_texto` text, `created_at` timestamptz, `enviado_at` timestamptz,
`cedula_norm` text, `ip_origen` text, `origen` text, `pg_net_request_id` bigint.

Checks: `tipo IN ('registro','bienvenida','recordatorio')`, `estado IN (...)`,
`intentos >= 0`, `enviado_at IS NULL OR estado = 'enviado'` (`:248-307`).

### 1.3 Idempotencia (como se calcula y se compara)
- No la calcula la RPC: la **manda el llamador** en `p_idempotency_key` (text, UNIQUE, `:217`).
- Comparacion: `SELECT ... WHERE l.idempotency_key = v_key ORDER BY created_at DESC LIMIT 1`
  (`:843-847`), y si existe devuelve `{"ok":true,"estado":<el previo>,"motivo":"idempotente","id":<uuid>}`
  (`:849-856`). Carrera cubierta con `ON CONFLICT (idempotency_key) DO NOTHING` + re-lectura (`:943-974`).
- Formatos usados en produccion: `admin-qr:<qr>`, `eventobackup-registro:<qr>`, `aforo-registro:<qr>`,
  `bienvenida:<email>`, `serie-registro:<qr>`, `recordatorio:<evento_id>:<inscrito_id>`
  (`adr078_cron_recordatorios.sql:117`).
- Ojo: el duplicado devuelve `ok=true`, asi que **no** incrementa `omitidos` (ver H3).

### 1.4 Payload que la RPC envia a la Edge Function (`:1015-1024`)
`email`, `nombre`, `qrCode`, `eventoNombre`, `eventoFecha`, `eventoHora`, `eventoLugar`, `tipo`
(con `jsonb_strip_nulls`: las claves nulas se omiten).

La Edge Function (`supabase/functions/send-ticket-email/index.ts`) exige `:268-280`:
`email` valido, `nombre` **no vacio**, `qrCode` **no vacio y http(s)**. Acepta ademas `ticketUrl`
(opcional, solo https) e `idempotencyKey` (opcional, solo para su dedup en memoria, `:733-736`).

### 1.5 Auth y codigos HTTP de la Edge Function
- `x-service-token` contra `SERVICE_SHARED_TOKEN` (`:385-391`) o JWT de sesion (`:395-417`).
- `405` metodo no POST (`:704`), `401` sin autorizacion (`:711`), `413` cuerpo grande (`:721`),
  `400` payload invalido (`:730`), `200 {ok:true,id:"duplicado_omitido"}` (`:735`),
  `502` red caida (`:757`) o status de Resend no 2xx (`:765`), `500 servicio_misconfigurado`
  si Resend responde 401/403 (`:763`).
- Adjunto PNG: fail-open, se omite y el correo sale sin adjunto (`:738-748`); host en allow-list
  (`:470-507`).
- Remitente: `env("MAIL_FROM")` con fallback literal `Taquilla Directa <no-reply@tickets.taquilladirecta.com>`
  (`:660`). La Function **no** lee `FROM_EMAIL`.

### 1.6 Cron
`public.fn_enviar_recordatorios_pendientes()` (`adr078_cron_recordatorios.sql:59-142`), SECURITY DEFINER,
`REVOKE` a `PUBLIC, anon, authenticated` y `GRANT` a `service_role` (`:145-146`). Job
`recordatorios-horarios`, `5 * * * *` (`:157-161`). Ventana: `evento_inicio` entre
`now() + fn_horas_recordatorio(e.id) - 2h` y `now() + fn_horas_recordatorio(e.id) + 2h` (`:90-92`),
con `fn_horas_recordatorio` = override del evento -> fila global -> 56 h (`adr074:352-377`).

---

## 2. Hallazgos de la auditoria estatica (no se corrigieron)

| ID | Severidad | Ubicacion | Hallazgo |
|---|---|---|---|
| H1 | **BLOQUEANTE** | `adr078_cron_recordatorios.sql:112` vs `adr076_enviar_email_seguro.sql:791` | El cron pasa `p_qr_code => ''` y `p_qr_code` es obligatorio (`fn_adr076_texto_limpio(..., 600, true)`) -> excepcion `22023`. El bloque fail-open de `:869` abre DESPUES de la validacion (`:1061` cierra ese bloque, no la funcion), asi que la excepcion **no se captura**: `enviar_email_registro` aborta y `fn_enviar_recordatorios_pendientes()` **falla entero** (no devuelve jsonb; el job queda `failed` en `cron.job_run_details`). **No hay fila en `email_envios_log`** (el INSERT es `:935`; `:934` es el `BEGIN` del bloque) y **no se envia nada**. Consecuencia: los recordatorios automaticos nunca han enviado un correo (el dry-run `0/0/0/0` de ADR-078 no ejercito ninguna fila). |
| H2 | Alta | `send-ticket-email/index.ts:276-280` | Aunque H1 se arregle solo en la RPC, la Edge Function tambien rechaza `qrCode` vacio con `400`. El fix tiene que resolver las dos capas (o decidir que `tipo='recordatorio'` viaje sin QR). |
| H2b | Media | `adr078:111` vs `adr076:790` + `index.ts:273-274` | `p_nombre => COALESCE(r.inscrito_nombre,'')` -> la RPC lo devuelve NULL -> `jsonb_strip_nulls` lo borra -> la Edge Function responde `400 "nombre es obligatorio"`. Un inscrito sin nombre rompe su recordatorio. |
| H3 | Media | `adr076:849-856` vs `adr078:125-131` | El duplicado por idempotencia devuelve `ok=true`, y el cron cuenta `ok` como `enviados`. En la segunda corrida el dry-run reporta `enviados` otra vez y `omitidos=0`, aunque no se reenvio nada. Metrica enganosa para cerrar B9 (afecta los valores esperados del paso 5). |
| H4 | Media | `adr076:1015-1024` vs `index.ts:740` | La RPC **no** envia `ticketUrl`, asi que el adjunto PNG (`:468-509`) es inalcanzable desde los 5 call sites migrados. No es regresion de B9, pero B9 **no puede** validar el adjunto. |
| H5 | Baja | `adr076:1007` | El header se llama `X-Origem` (typo). Ni la Edge Function lo lee ni esta en `Access-Control-Allow-Headers` (`index.ts:434`): traza muerta. El dato `origen` si queda como `'rpc_publica'` en `email_envios_log`. |
| H6 | Baja (doc) | `TASKS.md:366` | Dice que la Function usa el remitente por defecto porque el secret se llama `FROM_EMAIL`. **Refutado por el codigo:** `index.ts` solo lee `MAIL_FROM` (`:27`, `:660`) y `FROM_EMAIL` no aparece en el archivo. Ademas `TASKS.md:430` y `NEXT.md:215-217` ya registran `MAIL_FROM` migrado y verificado (correo real id `01a103e4-b89e-73c8-b2f0-0d818f80d7c2`). Queda como deuda documental, no de codigo. |
| H7 | Baja | `adr076:1026-1038` | `estado='enviado'` significa **encolado en pg_net**, no entregado. Si la Edge Function responde 401/400, la fila igual queda `enviado`. La verificacion REAL exige leer `net._http_response` (paso 4-V3). |
| H8 | Baja | `adr078:122` vs `adr076:781-784, :839` | El cron manda `p_bypass_rate_limit => true`, pero el bypass solo se honra si el rol es `service_role`; dentro de la RPC `current_user` es el owner (`postgres`), asi que **el flag es inerte**. Sin impacto practico (1 recordatorio por persona/evento), pero el codigo sugiere una exencion que no existe. |

---

## 3. Pre-flight (solo lectura; pegar y ejecutar)

```sql
-- P1: piezas del canal
SELECT to_regclass('public.email_envios_log')                      AS tabla_log,
       to_regclass('public.config_recordatorios')                  AS tabla_config,
       to_regprocedure('net.http_post(text,jsonb,jsonb,jsonb,integer)') IS NOT NULL AS pg_net_ok,
       public.fn_adr076_secreto('send_ticket_email_service_token') IS NOT NULL      AS token_ok;
```
Esperado: `tabla_log` y `tabla_config` no nulos, `pg_net_ok = true`, `token_ok = true`.
Si `token_ok = false`, **BLOQUEADO**: falta el secreto en Vault (la RPC falla cerrado con `42501`).

```sql
-- P2: job y configuracion
SELECT jobid, jobname, schedule, active FROM cron.job WHERE jobname = 'recordatorios-horarios';
SELECT id, evento_id, activo, horas_anticipacion, canal FROM public.config_recordatorios ORDER BY created_at;
```
Esperado: 1 job `5 * * * *` `active = true`; y una fila global (`evento_id` NULL) con 56 h.
**Si NO existe la fila global**: no es bloqueante (la RPC y el cron caen al default 56 en codigo),
pero registralo. Si quieres crearla (opcional, decision de Direccion):
```sql
INSERT INTO public.config_recordatorios (evento_id, horas_anticipacion) VALUES (NULL, 56);
```

```sql
-- P3: secretos del gateway (esto NO se puede leer desde SQL; hacerlo en Dashboard)
-- Supabase Dashboard > Edge Functions > send-ticket-email > Secrets:
--   RESEND_API_KEY       = presente y valida
--   MAIL_FROM            = Taquilla Directa <no-reply@tickets.taquilladirecta.com>
--   SERVICE_SHARED_TOKEN = mismo valor que el Vault send_ticket_email_service_token
```
Si `MAIL_FROM` no existe, el correo igual sale con el fallback literal de `index.ts:660` (dominio
verificado en Resend); registralo como observacion, no como bloqueador.

---

## 4. PASO 1 - Fixtures de prueba (una sola transaccion)

Crea un evento ficticio, un inscrito y su fila de configuracion. Se copia una fila real como molde
para no depender de columnas `NOT NULL` desconocidas; despues se sobrescriben solo las claves que
importan (`jsonb_populate_record` respeta el tipo real de cada columna).

```sql
BEGIN;

-- 4.1 Evento ficticio con evento_inicio DENTRO de la ventana (+/-2h) de su propia config
INSERT INTO public.eventos
SELECT (q.r).*
FROM (
  SELECT jsonb_populate_record(
           NULL::public.eventos,
           jsonb_set(
             jsonb_set(
               jsonb_set(
                 jsonb_set(
                   jsonb_set(to_jsonb(s),
                     '{id}',            to_jsonb('b9-smoke-evt'::text)),
                   '{slug}',            to_jsonb('b9-smoke-evt'::text)),
                 '{nombre}',            to_jsonb('B9 SMOKE TEST - NO PUBLICAR'::text)),
               '{evento_inicio}',       to_jsonb(now() + interval '1 hour')),
             '{fecha}',              to_jsonb(to_char((now() + interval '1 day') AT TIME ZONE 'America/Bogota','YYYY-MM-DD')))
         ) AS r
  FROM (SELECT * FROM public.eventos ORDER BY ctid LIMIT 1) s
) q;

-- 4.2 Inscrito de prueba (dominio de correo real: reemplazar por uno propio)
-- Se sobrescriben id/evento_id/email/nombre/cedula/qr_code para no chocar con
-- ningun UNIQUE de la fila molde.
INSERT INTO public.inscritos
SELECT (q.r).*
FROM (
  SELECT jsonb_populate_record(
           NULL::public.inscritos,
           jsonb_set(
             jsonb_set(
               jsonb_set(
                 jsonb_set(
                   jsonb_set(
                     jsonb_set(to_jsonb(s),
                       '{id}',        to_jsonb(gen_random_uuid()::text)),
                     '{evento_id}',   to_jsonb('b9-smoke-evt'::text)),
                   '{email}',        to_jsonb('PON_AQUI_TU_CORREO@gmail.com'::text)),
                 '{nombre}',         to_jsonb('B9 Smoke QA'::text)),
               '{cedula}',          to_jsonb('999999002'::text)),
             '{qr_code}',          to_jsonb('https://taquilladirecta.com/b9-smoke-ins'::text))
         ) AS r
  FROM (SELECT * FROM public.inscritos ORDER BY ctid LIMIT 1) s
) q;

-- 4.3 Configuracion del evento: 1 h de anticipacion -> la ventana pasa a [now-1h, now+3h]
INSERT INTO public.config_recordatorios (evento_id, activo, horas_anticipacion, canal)
VALUES ('b9-smoke-evt', true, 1, 'email')
ON CONFLICT (evento_id) DO UPDATE
  SET activo = true, horas_anticipacion = 1, updated_at = now();

COMMIT;
```

Notas de robustez:
- Si `public.eventos` o `public.inscritos` tuvieran columnas **generadas**, el `INSERT ... (q.r).*`
  falla con "cannot insert into column". Alternativa: `INSERT` explicito con las columnas minimas
  (`eventos`: `id, slug, nombre, fecha, hora, ubicacion, evento_inicio`; `inscritos`: `evento_id,
  nombre, email, cedula, qr_code`) y completar las que reclame el error.
- El evento hereda `template_id`/`config_landing` del molde. Es un slug nuevo sin difusion: como
  mucho queda accesible por URL directa durante el smoke, y se borra en el paso 6.

```sql
-- 4.4 Confirmacion de fixtures (esperado: 1, 1, 1)
SELECT (SELECT count(*) FROM public.eventos             WHERE id = 'b9-smoke-evt')                  AS evento,
       (SELECT count(*) FROM public.inscritos           WHERE evento_id = 'b9-smoke-evt')           AS inscritos,
       (SELECT count(*) FROM public.config_recordatorios WHERE evento_id = 'b9-smoke-evt')          AS config;
-- 4.5 Aislamiento: este evento es el UNICO en ventana (esperado: exactamente 1 fila, la de prueba)
SELECT e.id, e.nombre, e.evento_inicio, public.fn_horas_recordatorio(e.id) AS horas
FROM public.eventos e
WHERE e.evento_inicio IS NOT NULL
  AND e.evento_inicio BETWEEN now() + make_interval(hours => public.fn_horas_recordatorio(e.id)) - interval '2 hours'
                          AND now() + make_interval(hours => public.fn_horas_recordatorio(e.id)) + interval '2 hours';
```

---

## 5. PASO 2 - Corrida forzada del cron (mide H1)

```sql
SELECT public.fn_enviar_recordatorios_pendientes() AS resultado;
```

- **Esperado HOY (H1 abierto):** NO devuelve jsonb; el SQL Editor muestra
  `ERROR: [ADR-076] campo "qr_code": obligatorio y llego nulo o vacio   (SQLSTATE 22023)`.
  Eso **reproduce H1** y se registra como bloqueador, no como fallo del smoke.
- **Si devuelve `{"eventos":1,"enviados":1,...}`:** H1 no se reproduce (o ya fue corregido en la
  funcion del cron). Guarda el jsonb y continua.

> **ACTUALIZADO 2026-11-01:** el "Esperado HOY (H1 abierto)" de arriba quedo **OBSOLETO**. Tras
> aplicar `migrations/adr078b_fix_cron_recordatorios.sql` (v1.0 en la base desde 2026-11-01), el
> esperado pasa a ser un **jsonb** con `enviados >= 1` (y `eventos >= 1` si el fixture del paso 1
> esta en ventana). El `SQLSTATE 22023` **solo** volveria a aparecer si el hotfix **no** esta en la
> base o si se re-ejecuta `adr078_cron_recordatorios.sql` completo (restaura el cuerpo con H1). Si
> sale `22023`, primero verifica `pg_get_functiondef('public.fn_enviar_recordatorios_pendientes'::regproc)`
> contra `adr078b` y **no** lo registres como comportamiento normal.

```sql
-- 0 filas esperadas hoy: la validacion corta ANTES del INSERT de traza (:935; :934 es el BEGIN del bloque)
SELECT id, tipo, estado, intentos, idempotency_key, pg_net_request_id, error_texto
FROM public.email_envios_log WHERE evento_id = 'b9-smoke-evt' ORDER BY created_at;

-- El job queda 'failed' en cada corrida mientras haya un evento en ventana
SELECT jobid, status, return_message, start_time
FROM cron.job_run_details
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'recordatorios-horarios')
ORDER BY start_time DESC LIMIT 3;
```

Nota 1: `eventos` cuenta **inscritos en ventana**, no eventos distintos (`adr078:107`).
Nota 2 (**riesgo de produccion**): mientras H1 siga abierto, cualquier evento real que entre en la
ventana de 56 h (+/-2 h) hace fallar el job completo y no manda nada. El fixture del paso 1 no debe
quedarse: el paso 6 lo borra.

---

## 6. PASO 3 - Camino real de los 5 call sites (cierre de B9)

Esta es la ruta que usan `admin.html`, `serie.html`, `registro.html`, `registroaforo.html` y
`eventobackup.html` (`p_tipo='registro'`/`'bienvenida'`, con `p_qr_code` que es una URL real).
Es la que cierra B9; el recordatorio queda pendiente de H1.

```sql
SELECT public.enviar_email_registro(
  p_email             => 'PON_AQUI_TU_CORREO@gmail.com',
  p_nombre            => 'B9 Smoke QA',
  p_qr_code           => 'https://taquilladirecta.com/b9-smoke',
  p_evento_nombre     => 'B9 SMOKE TEST',
  p_evento_fecha      => to_char(now() AT TIME ZONE 'America/Bogota','YYYY-MM-DD'),
  p_evento_hora       => '20:00',
  p_evento_lugar      => 'Bogota',
  p_idempotency_key   => 'b9-smoke:manual:1',
  p_tipo              => 'registro',
  p_cedula            => '999999001',
  p_evento_id         => 'b9-smoke-evt'
) AS resultado;
```

**Esperado:** `{"ok":true,"estado":"enviado","motivo":"encolado","pg_net_request_id":<bigint>,"id":"<uuid>"}`

Interpretacion de fallos:
- Excepcion `42501` -> falta el secreto de servicio (P1).
- Excepcion `22023` -> algun campo obligatorio vacio o email invalido; el mensaje dice cual.
- `{"ok":false,"estado":"error","motivo":"pg_net_no_disponible"}` -> falta la extension.
- `{"ok":false,"estado":"error","motivo":"fallo_interno"}` -> validacion o credencial; revisar el
  mensaje del primer intento.
- `{"ok":false,"estado":"omitido","motivo":"rate_limit_*"}` -> repetiste el smoke; cambia el `cedula`
  o espera 10 minutos (por IP: 10/hora).

---

## 7. PASO 4 - Las 3 consultas de verificacion

### V1 - Estado en `email_envios_log`
```sql
SELECT id, evento_id, destinatario, tipo, estado, intentos, idempotency_key,
       pg_net_request_id, created_at, enviado_at, error_texto, origen
FROM public.email_envios_log
WHERE idempotency_key = 'b9-smoke:manual:1';
```
Esperado: **exactamente 1 fila**, `estado='enviado'`, `intentos=1`, `error_texto` NULL,
`enviado_at` no nulo, `pg_net_request_id` no nulo, `origen='rpc_publica'`.

### V2 - Conteo de enviados / omitidos / errores
```sql
SELECT estado, count(*) AS total
FROM public.email_envios_log
WHERE evento_id = 'b9-smoke-evt'
GROUP BY estado ORDER BY estado;
```
Esperado: `enviado = 1`. (Si ademas corriste el paso 5, la fila no aumenta: la idempotencia la frena.)
Si apareciera `error` o `omitido`, el motivo esta en `error_texto`.

### V3 - Entrega REAL (lo unico que prueba Resend)
```sql
SELECT r.id AS pg_net_request_id, r.status_code, left(r.content::text, 600) AS respuesta, r.created
FROM net._http_response r
WHERE r.id = (SELECT pg_net_request_id FROM public.email_envios_log
              WHERE idempotency_key = 'b9-smoke:manual:1');
```
Esperado: `status_code = 200` y `respuesta` con `{"id":"<resend-id>"}`.
Si no aparece fila, espera unos segundos (pg_net es asincrono) y repite.
Diagnostico por codigo: `401` token distinto entre Vault y `SERVICE_SHARED_TOKEN`; `400` payload
rechazado (nombre/qrCode); `422` remitente o dominio no verificado en Resend; `500`
`servicio_misconfigurado` (API key invalida); `502` error de Resend.

Cierre de la evidencia (obligatorio para B9):
1. `resend-id` de V3.
2. En Resend Dashboard > Emails: el envio aparece con `Delivered` al destinatario usado.
3. Correo visible en la bandeja (revisar spam).

---

## 8. PASO 5 - Prueba de idempotencia (segunda corrida)

Vuelve a ejecutar **exactamente** el mismo `SELECT public.enviar_email_registro(...)` del paso 3
(misma `p_idempotency_key`).

**Esperado:** `{"ok":true,"estado":"enviado","motivo":"idempotente","id":"<el MISMO uuid de V1>"}`

```sql
-- I1: sigue habiendo 1 sola fila (esperado: 1)
SELECT count(*) AS filas FROM public.email_envios_log WHERE idempotency_key = 'b9-smoke:manual:1';

-- I2: no hubo un segundo envio real (esperado: 1 fila y created sin cambios; intentos sigue en 1)
SELECT id, intentos, created_at, enviado_at,
       (SELECT count(*) FROM net._http_response r WHERE r.id = l.pg_net_request_id) AS respuestas_pg_net
FROM public.email_envios_log l WHERE l.idempotency_key = 'b9-smoke:manual:1';
```
Esperado: `filas=1`, `intentos=1`, `respuestas_pg_net=1`.

Trampa documentada (H3): si repites el **paso 2** (cron), el conteo dira `enviados` otra vez y
`omitidos=0`, aunque no se haya reenviado nada. La prueba valida de no-reenvio es I1/I2, no el jsonb
del cron.

---

## 9. PASO 6 - Limpieza acotada (rollback)

Recomendado: **conservar** las filas de `email_envios_log` como evidencia (no molestan y no tienen
FK a `eventos`). Si Direccion pide limpieza total, ejecuta todo el bloque.

```sql
BEGIN;

-- Solo los registros de prueba. Nada de DROP, nada de TRUNCATE.
DELETE FROM public.email_envios_log
 WHERE idempotency_key LIKE 'b9-smoke%'
    OR idempotency_key LIKE 'recordatorio:b9-smoke-evt:%';

DELETE FROM public.config_recordatorios WHERE evento_id = 'b9-smoke-evt';
DELETE FROM public.inscritos           WHERE evento_id = 'b9-smoke-evt';
DELETE FROM public.eventos             WHERE id        = 'b9-smoke-evt';

COMMIT;
```

```sql
-- Verificacion de limpieza (esperado: 0, 0, 0, 0)
SELECT (SELECT count(*) FROM public.eventos             WHERE id = 'b9-smoke-evt')         AS evento,
       (SELECT count(*) FROM public.inscritos           WHERE evento_id = 'b9-smoke-evt')  AS inscritos,
       (SELECT count(*) FROM public.config_recordatorios WHERE evento_id = 'b9-smoke-evt') AS config,
       (SELECT count(*) FROM public.email_envios_log    WHERE evento_id = 'b9-smoke-evt')  AS log;
```

Si el `DELETE` de `eventos` fallara por una FK no prevista, el orden correcto es: log -> config ->
inscritos -> eventos (es el que ya trae el bloque).

---

## 10. Correcciones propuestas para H1/H2 (NO APLICADAS)

> **ESTADO 2026-11-01: APLICADO (v1.0).** Ver `migrations/adr078b_fix_cron_recordatorios.sql`.
> El titulo "NO APLICADAS" se conserva por trazabilidad historica (Cero Borrado), pero la v1.0
> (H1 + H2b + H9) **esta en la base desde 2026-11-01**. Existe ademas una **v1.1** del mismo archivo
> (blindaje de slug NULL: si `eventos.slug` es NULL/vacio cae a la raiz del dominio en vez de dejar
> `...?slug=` sin evento) **pendiente de re-aplicar**. Nota: la Opcion A de abajo se quedo corta — el
> `COALESCE` propuesto no cubre un `qr_code` **no vacio pero que no es URL** (`'QR-' + UID()`); la
> version aplicada usa un `CASE` por forma (`~* '^https?://'`).

Decision de `@architect` + gate de ?2 antes de tocar `migrations/` o la Edge Function.

Opcion A (minima, solo cron; 2 lineas en `migrations/adr078_cron_recordatorios.sql`):
```sql
-- :111  p_nombre => COALESCE(r.inscrito_nombre, '')            -- deja NULL y la Edge responde 400
--       p_nombre => COALESCE(NULLIF(btrim(r.inscrito_nombre), ''), 'Asistente')
-- :112  p_qr_code => ''                                        -- obligatorio en la RPC (22023)
--       p_qr_code => COALESCE(NULLIF(btrim(i.qr_code), ''),
--                             'https://taquilladirecta.com/evento.html?slug=' || COALESCE(e.slug, ''))
```
Requiere: re-crear la funcion (el archivo es idempotente con `CREATE OR REPLACE`), volver a correr
solo el BLOQUE 2/BLOQUE 3 del archivo (no el `CREATE EXTENSION`), y re-ejecutar el paso 2 del runbook.

Opcion B (contrato): permitir recordatorios sin QR tanto en la RPC (`p_qr_code` condicional a
`p_tipo`) como en la Edge Function (`qrCode` opcional cuando `tipo='recordatorio'`), y que la
plantilla muestre el enlace del evento en lugar del QR. Toca dos capas: exige ADR.

Adicionales, no bloqueantes: H5 (`X-Origem` -> `X-Origen`), H6 (corregir `TASKS.md:366`),
H3 (que el cron cuente `motivo='idempotente'` como `omitidos`).

---

## 11. Registro de evidencia (pegar en TASKS.md / NEXT.md al cerrar)

- Fecha/hora (America/Bogota) de la corrida:
- P1 `token_ok` / `pg_net_ok`:
- PASO 2 resultado jsonb (y confirmacion de 0 filas si H1 sigue abierto):
- PASO 3 resultado jsonb (`pg_net_request_id`):
- V1 estado / intentos:
- V2 conteo por estado:
- V3 `status_code` + `resend-id`:
- Resend Dashboard: estado del envio (Delivered / bounced):
- PASO 5 `motivo` y `id` (debe coincidir con V1):
- Limpieza ejecutada (si/no) y resultado 0/0/0/0:
- Hallazgos confirmados: H1 (si/no), H2b (si/no) ->
