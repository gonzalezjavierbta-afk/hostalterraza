---
doc: B9b
adr: ADR-089
estado: PENDIENTE DE EJECUCION
fecha: 2026-11-01
version: v1.0
autor: @docs-keeper
relacionados: [decisiones/ADR-089-recordatorios-multicanal-con-canal-whatsapp.md, migrations/adr089_recordatorios_multicanal.sql, supabase/functions/send-wa-recordatorio/index.ts, scripts/smoke_wa_edge.js, TASKS.md (TSK-127), NEXT.md (hito -56), runbooks/B9-smoke-email.md]
nota: Este runbook NO modifica codigo de producto ni la migracion. Todo el SQL es de aprovisionamiento y de datos (plantillas, reglas, flags y verificacion).
---

# B9b — Encendido del canal WhatsApp de recordatorios (ADR-089 F1/F3/F4)

Cierra la parte **no programable** de ADR-089: el codigo del canal ya existe, esta verificado y
nace **apagado**; lo que falta es aprovisionamiento externo (Meta), secretos, plantillas, reglas y un
smoke real. Este runbook se ejecuta **a mano**, en el SQL Editor de Supabase y en el panel de Meta,
por una persona con acceso. La IA no tiene credenciales ni cuenta de Meta.

Proyecto Supabase: `ctgyvydzshueemlelkzv`. CLI instalada: `supabase` v2.84.2.
Docker **no** esta instalado: `supabase functions serve` no corre en local; `supabase functions deploy`
si funciona (el deploy no necesita Docker).

---

## 1. Estado y alcance

**Ya esta hecho y verificado (no se vuelve a tocar):**

1. **ADR-089 v1.2 ACEPTADO** en `decisiones/ADR-089-recordatorios-multicanal-con-canal-whatsapp.md`.
2. **Migracion APLICADA** por Direccion el **2026-11-01**: `migrations/adr089_recordatorios_multicanal.sql`.
   Dejo 4 tablas nuevas (`canal_flags`, `wa_plantillas`, `recordatorio_reglas`, `wa_envios_log`),
   4 columnas de opt-in en `inscritos`, la normalizadora `fn_wa_e164_co`, `fn_horas_recordatorio` con
   3 parametros mas su envoltorio de 1 parametro, `fn_enviar_recordatorios_wa_pendientes`,
   `fn_wa_reconciliar_respuestas`, `fn_wa_corrida_programada` y el job pg_cron `recordatorios-wa`
   con schedule `10 * * * *`.
3. **Edge Function escrita y verificada**: `supabase/functions/send-wa-recordatorio/index.ts`, con
   arnes reproducible `node scripts/smoke_wa_edge.js` (**14/14 PASS**, no requiere Deno ni Docker).
4. **`.env.example`** creado con los nombres exactos de las variables.
5. **El canal nace APAGADO.** `canal_flags` tiene **una sola fila**:
   `canal='whatsapp', activo=false, dry_run=true, requiere_optin=false,
   max_envios_por_corrida=50, max_envios_por_mes=500, alerta_porcentaje=80, costo_unitario_usd=NULL`.

**Falta (todo externo, ninguno es desarrollo):** verificacion de negocio en Meta, WABA, numero emisor
verificado, token permanente, 3 plantillas aprobadas, secretos cargados, deploy de la Edge Function,
poblado de `wa_plantillas` y `recordatorio_reglas`, verificacion F1, dry-run de calibracion, smoke F4,
encendido y tarifa.

> **Hoy no sale ni un solo mensaje de WhatsApp, y eso es lo correcto.** El canal esta construido para
> no poder enviar mientras `activo=false` y `dry_run=true`. Cualquier intento de "probar rapido"
> encendiendo el flag sin completar el camino critico de la seccion 2 termina en error de red, no en
> un mensaje entregado, y deja traza sucia en `wa_envios_log`. El orden de este runbook **es** la
> garantia.

---

## 2. Camino critico Meta (5 pasos con criterio de salida)

Se hace en `business.facebook.com` / `developers.facebook.com`. **Cada paso puede tardar 24-48 h** y
varios dependen de revision humana de Meta. Una plantilla puede ser **RECHAZADA**: el codigo puede
estar listo y el canal simplemente no existir todavia. Ningun paso de este runbook sustituye a Meta.

| # | Paso | Criterio de salida verificable |
|---|---|---|
| 1 | **Verificacion de negocio** (Business Verification) en Meta Business Suite | La cuenta aparece como **Verified** en Business Settings; el estado ya no dice "In review" |
| 2 | **WABA + numero emisor verificado**. **Un solo numero** para tickets y recordatorios (decision **D4** del ADR-089: no se parte la reputacion del numero en dos canales) | En WhatsApp Manager el numero figura **Connected / Verified** y su calidad no esta marcada como restringida |
| 3 | **System User con token PERMANENTE**, con permisos `whatsapp_business_messaging` y `whatsapp_business_management` | El token se genera en Business Settings > System Users, **no caduca a las 24 h** (no es un token de usuario), y una llamada de lectura a Graph API responde `200` |
| 4 | **Obtener `phone_number_id`** (el **ID del numero**, no el numero telefonico) y **`WA_BUSINESS_ACCOUNT_ID`** | `GET /{phone_number_id}?fields=display_phone_number,verified_name` responde `200` con el numero correcto |
| 5 | **Lista de numeros de prueba** (2-3 numeros propios o del equipo) | Los numeros reciben un mensaje de prueba del WABA (aunque sea el "hello world" del panel) |

**Advertencias que no se pueden saltar:**

- El **token de prueba del panel de Meta caduca en 24 h**. Si se usa ese, el canal se cae solo al dia
  siguiente y el reconciliador apagara el flag por error 190 (ver seccion 11). Token **permanente** o
  no se enciende.
- El **numero emisor no es el `phone_number_id`**. Confundirlos es el error clasico: el `phone_number_id`
  es un identificador numerico largo que va en la URL de Graph, no en el cuerpo.
- Si Meta **rechaza** una plantilla, no se reescribe la plantilla en la base con otro texto: se corrige
  en Meta, se vuelve a enviar a revision y solo cuando este aprobada se actualiza `wa_plantillas`
  (seccion 6).

---

## 3. Plantillas a crear en Meta

Tres plantillas, categoria **UTILITY**, idioma **es_CO**. Los nombres van **en minusculas** porque la
Edge Function rechaza con `400` cualquier `template.name` que no cumpla `^[a-z0-9_]{1,120}$`.

| Nombre logico (exacto) | Categoria | Idioma | `variables` (el ORDEN es el contrato) |
|---|---|---|---|
| `recordatorio_anticipacion_56h` | UTILITY | es_CO | `["nombre","evento","fecha_hora","ubicacion","link"]` |
| `recordatorio_dia_evento` | UTILITY | es_CO | `["nombre","evento","fecha_hora","ubicacion","link"]` |
| `recordatorio_post_evento` | UTILITY | es_CO | `["nombre","evento","link"]` |

Los nombres de variable son **exactamente** las claves que el mapa de render expone a las plantillas:
`nombre`, `cedula`, `evento`, `fecha`, `hora`, `fecha_hora`, `ubicacion`, `slug`, `link`, `codigo`.
No se inventan claves nuevas y **no se reordena** el array: **Meta es posicional** (`{{1}}` es el primer
elemento, no el que se llame igual). Cambiar el orden en `wa_plantillas` sin cambiar la plantilla en
Meta manda datos cruzados sin ningun error visible.

**Textos sugeridos** (se pegan tal cual en el creador de plantillas de Meta; en Meta se escriben con
dobles llaves, en la base solo se guarda la lista de variables):

`recordatorio_anticipacion_56h`
```
Hola {{1}}, te recordamos que {{2}} es el {{3}} en {{4}}.
Tu entrada y el detalle del evento: {{5}}
```

`recordatorio_dia_evento`
```
Hola {{1}}, hoy es el dia de {{2}}. Inicio: {{3}}. Lugar: {{4}}.
Presenta tu codigo en la entrada: {{5}}
```

`recordatorio_post_evento`
```
Hola {{1}}, gracias por acompanarnos en {{2}}.
Cuentanos como te fue y mira lo que viene: {{3}}
```

**Nota sobre la categoria.** `UTILITY` es transaccional (el usuario se inscribio al evento: hay relacion
previa y el mensaje es informativo). Si Meta la **reclasifica a MARKETING**, cambian dos cosas a la vez:
sube el precio por mensaje y el **opt-in se vuelve exigible de facto**, no por decision nuestra. En ese
caso el canal no se enciende hasta que exista el checkbox `wa_optin` en el formulario (deuda (ii) de la
seccion 13) y el texto legal validado (deuda (i)).

---

## 4. Secretos en Supabase

Se cargan como secretos del proyecto (los lee la Edge Function en runtime, nunca el cliente).

| Variable | Obligatorio | Nota |
|---|---|---|
| `WA_TOKEN` | Si | Token **permanente** del System User (seccion 2, paso 3). Sin el, la Function responde error de configuracion y no llama a Graph |
| `WA_PHONE_NUMBER_ID` | Si | **ID del numero**, no el numero. Va en la ruta de Graph |
| `WA_GRAPH_VERSION` | Si | `v21.0` (valor de referencia; si Meta publica una version nueva se cambia aqui, no en el codigo) |
| `WA_DRY_RUN` | Si | `1` en la linea base. Con `1` la Function no llama a Graph y devuelve la simulacion. Poner `0` es el ultimo paso (seccion 10) |
| `SERVICE_SHARED_TOKEN` | Si | **REUTILIZAR el existente** del canal de correo. No se crea uno nuevo: la RPC y la Function ya lo comparten |
| `SUPABASE_ANON_KEY` | Si | Para el `Authorization` de las llamadas internas; es la clave publica, no la `service_role` |
| `ALLOWED_ORIGINS` | Si | Mismo criterio que la Function de correo; sin esto las invocaciones desde el navegador fallan por CORS |
| `WA_GRAPH_URL` | No | **Vacio en produccion**. Solo se usa para apuntar a un mock local en pruebas de la Function |
| `WA_VERIFY_TOKEN` | Si (webhook) | Lo eliges tu y se repite **identico** en Meta al suscribir el webhook (seccion 15). Si esta vacio, el endpoint de verificacion responde `403` siempre: un secreto vacio no es un secreto |
| `WA_APP_SECRET` | Si (webhook) | App Secret de la app de Meta. Valida la firma `X-Hub-Signature-256` de los estados de entrega. Sin el, `wa-webhook` responde `503` y no procesa nada |

**Comandos de ejemplo (CLI, no requieren Docker):**

```bash
supabase secrets set --project-ref ctgyvydzshueemlelkzv \
  WA_TOKEN="EAAG..." \
  WA_PHONE_NUMBER_ID="123456789012345" \
  WA_GRAPH_VERSION="v21.0" \
  WA_DRY_RUN="1" \
  ALLOWED_ORIGINS="https://taquilladirecta.com"
```

```bash
# SERVICE_SHARED_TOKEN y SUPABASE_ANON_KEY: reutilizar los ya existentes.
# Solo se confirma que estan, NO se reescriben a ciegas.
supabase secrets list --project-ref ctgyvydzshueemlelkzv
```

**Variante dashboard:** `Supabase Dashboard > Project Settings > Edge Functions > Secrets > Add new
secret`, una fila por variable, con el mismo nombre exacto. Al terminar, `secrets list` debe mostrar
`WA_TOKEN`, `WA_PHONE_NUMBER_ID`, `WA_GRAPH_VERSION`, `WA_DRY_RUN`, `SERVICE_SHARED_TOKEN`,
`SUPABASE_ANON_KEY`, `ALLOWED_ORIGINS`, `WA_VERIFY_TOKEN` y `WA_APP_SECRET`. `WA_GRAPH_URL` no
aparece si se deja vacia: es correcto.

---

## 5. Deploy de la Edge Function

```bash
supabase functions deploy send-wa-recordatorio --project-ref ctgyvydzshueemlelkzv --no-verify-jwt
```

> **`--no-verify-jwt` NO es opcional.** Sin ese flag, el gateway de Supabase exige un
> `Authorization: Bearer <JWT>` **antes** de ejecutar la Function, y `pg_net` manda unicamente
> `Content-Type` y `X-Service-Token` (`migrations/adr089_recordatorios_multicanal.sql:549-552`).
> Resultado sin el flag: **401 del gateway** en cada envio, con la Function intacta y sin un solo log
> suyo. El canal fallaria por configuracion, no por codigo, y el sintoma no apunta a la causa.
> La autenticacion real la hace `authorize()`: `X-Service-Token` en tiempo casi constante o JWT de
> sesion validado por la propia Function. `wa-webhook` tambien lo necesita, por otra razon: Meta no
> manda `Authorization` en ningun caso y se autentica con la firma `X-Hub-Signature-256`.

Verificacion del arnes (local, sin Deno ni Docker; el arnes levanta la Function en un entorno Node):

```bash
node scripts/smoke_wa_edge.js
```

Esperado: **14/14 PASS**. Si el arnes falla, el deploy no se hace: se corrige el archivo primero.

> **Docker solo hace falta para `supabase functions serve`** (ejecutar la Function en local con el
> runtime real). **No** hace falta para `functions deploy`, que empaqueta y sube. No instalar Docker
> para este runbook.

---

## 6. Datos en la base, en orden

**El orden no es negociable:** `recordatorio_reglas.plantilla` es FK textual a
`wa_plantillas.nombre_logico`. Si la regla va primero, falla por FK. Y `nombre_logico` **no se renombra
nunca**: es contrato externo con Meta (renombrar obliga a crear fila nueva y a reescribir las reglas).

### 6.1 Paso A — Poblar `wa_plantillas` (despues de que Meta las apruebe)

```sql
INSERT INTO public.wa_plantillas (nombre_logico, idioma, categoria, variables, preview, estado_meta, activo)
VALUES
  ('recordatorio_anticipacion_56h', 'es_CO', 'UTILITY',
   '["nombre","evento","fecha_hora","ubicacion","link"]'::jsonb,
   'Recordatorio 56 h antes del evento', 'aprobada', true),
  ('recordatorio_dia_evento', 'es_CO', 'UTILITY',
   '["nombre","evento","fecha_hora","ubicacion","link"]'::jsonb,
   'Recordatorio el dia del evento', 'aprobada', true),
  ('recordatorio_post_evento', 'es_CO', 'UTILITY',
   '["nombre","evento","link"]'::jsonb,
   'Agradecimiento posterior al evento', 'aprobada', true)
ON CONFLICT (nombre_logico) DO UPDATE
  SET idioma      = EXCLUDED.idioma,
      categoria   = EXCLUDED.categoria,
      variables   = EXCLUDED.variables,
      preview     = EXCLUDED.preview,
      estado_meta = EXCLUDED.estado_meta,
      activo      = EXCLUDED.activo;
```

`estado_meta='aprobada'` **solo** se escribe cuando Meta ya aprobo esa plantilla. Escribirlo antes
produce un `400` por plantilla inexistente en el mejor caso, y en el peor un mensaje con texto que no
existe en Meta.

### 6.2 Paso B — Cargar `recordatorio_reglas` (patron UPDATE-primero)

**NUNCA `INSERT` ciego.** El unique de reglas es **parcial** (`recordatorio_reglas_global_uq` sobre
`(canal, tipo) WHERE evento_id IS NULL`), asi que **no distingue `activo`**: un `INSERT` de reemplazo
choca con `23505` y aborta el lote entero. El patron correcto es **actualizar primero** y solo
insertar si el `UPDATE` afecto **0 filas**.

```sql
-- Globales (evento_id IS NULL): una regla por tipo, techo de 3 por canal.
DO $$
DECLARE
  v_filas integer;
BEGIN
  -- 1) anticipacion 56 h
  UPDATE public.recordatorio_reglas
     SET horas_offset = 56,
         plantilla    = 'recordatorio_anticipacion_56h',
         activo       = true
   WHERE canal = 'whatsapp' AND tipo = 'anticipacion' AND evento_id IS NULL;
  GET DIAGNOSTICS v_filas = ROW_COUNT;
  IF v_filas = 0 THEN
    INSERT INTO public.recordatorio_reglas (evento_id, canal, tipo, horas_offset, plantilla, activo)
    VALUES (NULL, 'whatsapp', 'anticipacion', 56, 'recordatorio_anticipacion_56h', true);
  END IF;

  -- 2) dia del evento (offset 0)
  UPDATE public.recordatorio_reglas
     SET horas_offset = 0,
         plantilla    = 'recordatorio_dia_evento',
         activo       = true
   WHERE canal = 'whatsapp' AND tipo = 'dia_evento' AND evento_id IS NULL;
  GET DIAGNOSTICS v_filas = ROW_COUNT;
  IF v_filas = 0 THEN
    INSERT INTO public.recordatorio_reglas (evento_id, canal, tipo, horas_offset, plantilla, activo)
    VALUES (NULL, 'whatsapp', 'dia_evento', 0, 'recordatorio_dia_evento', true);
  END IF;

  -- 3) post evento (offset -24)
  UPDATE public.recordatorio_reglas
     SET horas_offset = -24,
         plantilla    = 'recordatorio_post_evento',
         activo       = true
   WHERE canal = 'whatsapp' AND tipo = 'post_evento' AND evento_id IS NULL;
  GET DIAGNOSTICS v_filas = ROW_COUNT;
  IF v_filas = 0 THEN
    INSERT INTO public.recordatorio_reglas (evento_id, canal, tipo, horas_offset, plantilla, activo)
    VALUES (NULL, 'whatsapp', 'post_evento', -24, 'recordatorio_post_evento', true);
  END IF;
END $$;
```

**Regla por evento** (opcional, cuando un evento necesita otra plantilla o apagarse solo). Mismo patron,
con `evento_id = '<id del evento>'` en el `UPDATE` y el `INSERT`, y el unique que aplica es
`recordatorio_reglas_ev_uq` (`(evento_id, canal, tipo)`):

```sql
-- Ejemplo: apagar SOLO el post-evento de un evento, sin tocar la regla global.
UPDATE public.recordatorio_reglas
   SET activo = false
 WHERE canal = 'whatsapp' AND tipo = 'post_evento'
   AND evento_id = 'vinilos-inversos-c8yu';
```

**Techo de 3 reglas por canal:** por el unique parcial, `whatsapp` admite **una** regla global por
`tipo` (`anticipacion`, `dia_evento`, `post_evento`). Una cuarta fila con `evento_id IS NULL` **no
entra**: choca con `23505`. Para dos plantillas del mismo tipo hace falta una regla por evento, no dos
globales.

Verificacion inmediata:

```sql
SELECT evento_id, canal, tipo, horas_offset, plantilla, activo
  FROM public.recordatorio_reglas
 WHERE canal = 'whatsapp'
 ORDER BY evento_id NULLS FIRST, horas_offset DESC;
```

Esperado: **3 filas globales** (`evento_id` NULL) con `plantilla` no nula y `activo = true`.

---

## 7. Verificacion post-migracion (F1, puntos 1 a 9)

Se corre **antes** de tocar plantillas y reglas. Son los 9 criterios de F1; sin los 9 en verde no se
sigue. Todo es lectura: ninguna de estas consultas cambia datos.

```sql
-- F1 #1: la migracion es idempotente. Re-ejecutarla NO debe lanzar error
-- (se corre dos veces el archivo completo; aqui se resume la comprobacion de tablas).
SELECT table_name FROM information_schema.tables
 WHERE table_schema = 'public'
   AND table_name IN ('canal_flags','wa_plantillas','recordatorio_reglas','wa_envios_log')
 ORDER BY table_name;   -- esperado: 4 filas
```

```sql
-- F1 #2: backfill de reglas = filas de config_recordatorios (ninguna se perdio).
SELECT (SELECT count(*) FROM public.recordatorio_reglas) AS reglas_total,
       (SELECT count(*) FROM public.config_recordatorios) AS config_total;
```

```sql
-- F1 #3: la segunda corrida del backfill suma 0 (no duplica).
-- Se re-ejecuta el bloque de backfill del archivo y luego:
SELECT count(*) AS reglas_total FROM public.recordatorio_reglas;  -- igual que en F1 #2
```

```sql
-- F1 #4: duplicado explicito -> 23505 (se prueba dentro de un bloque que revierte).
DO $$
BEGIN
  INSERT INTO public.recordatorio_reglas (evento_id, canal, tipo, horas_offset, plantilla, activo)
  SELECT evento_id, canal, tipo, horas_offset, plantilla, activo
    FROM public.recordatorio_reglas WHERE canal = 'whatsapp' LIMIT 1;
  RAISE EXCEPTION 'F1 #4 FALLA: el duplicado entro';
EXCEPTION
  WHEN unique_violation THEN RAISE NOTICE 'F1 #4 OK: 23505 como se esperaba';
END $$;
```

```sql
-- F1 #5: el envoltorio de 1 argumento devuelve lo mismo que antes de la migracion.
SELECT id, public.fn_horas_recordatorio(id) AS horas_1_arg
  FROM public.eventos ORDER BY id LIMIT 5;
```

```sql
-- F1 #6: el envoltorio DELEGA y no reimplementa (no debe contener COALESCE).
SELECT pg_get_functiondef('public.fn_horas_recordatorio(text)'::regprocedure) AS definicion;
-- esperado: el cuerpo llama a la version de 3 parametros; 0 ocurrencias de COALESCE
```

```sql
-- F1 #7: la version de 3 parametros existe.
SELECT to_regprocedure('public.fn_horas_recordatorio(text,text,text)') AS firma_3_params;
-- esperado: NO nulo
```

```sql
-- F1 #8: el canal nace apagado y con UNA sola fila.
SELECT canal, activo, dry_run, requiere_optin, max_envios_por_corrida,
       max_envios_por_mes, alerta_porcentaje, costo_unitario_usd
  FROM public.canal_flags;   -- esperado: 1 fila, activo=false, dry_run=true, costo NULL
```

```sql
-- F1 #9: el indice parcial de idempotencia existe, y las plantillas van antes que las reglas.
SELECT indexname FROM pg_indexes
 WHERE schemaname = 'public' AND indexname = 'wa_envios_log_idem_uq';  -- 1 fila

SELECT count(*) AS reglas_wa_sin_plantilla
  FROM public.recordatorio_reglas r
 WHERE r.canal = 'whatsapp'
   AND NOT EXISTS (SELECT 1 FROM public.wa_plantillas p WHERE p.nombre_logico = r.plantilla);
-- esperado: 0 (si hay reglas, sus plantillas ya existian)
```

---

## 8. Dry-run de calibracion (F3)

Con `WA_DRY_RUN=1` y `canal_flags.dry_run=true`, la RPC recorre los pendientes **sin enviar** y devuelve
la muestra de payloads. Dos invocaciones distintas, con propositos distintos:

```sql
-- F3-A: inspeccion pura. NO escribe nada. Devuelve 'muestra' con hasta 5 payloads.
SELECT public.fn_enviar_recordatorios_wa_pendientes(true, 5, 120, 'manual', false);
```

```sql
-- F3-B: dry-run PERSISTIDO. Escribe filas con estado='omitido' y omitido_motivo='dry_run'.
SELECT public.fn_enviar_recordatorios_wa_pendientes(true, 5, 120, 'manual', true);
```

Que revisar en la `muestra` de F3-A: que `variables` llegue en el **orden** de la seccion 3, que
`nombre` y `evento` no vayan vacios, que `link` sea una URL real del evento y que `telefono_e164`
empiece por `57`.

**Criterio de calibracion (bloqueante):** medir el porcentaje de inscritos con telefono invalido.

```sql
SELECT count(*) FILTER (WHERE telefono_e164 = '') AS sin_telefono_valido,
       count(*)                                   AS total_inscritos,
       round(100.0 * count(*) FILTER (WHERE telefono_e164 = ''), 2) AS pct_invalido
  FROM public.inscritos;
```

> **Si el porcentaje de telefonos invalidos supera el 20 %, el canal NO esta listo aunque el codigo
> funcione.** El problema no es tecnico: es que una quinta parte de la audiencia no va a recibir nada y
> la cobertura del 90 % es inalcanzable. En ese caso se corrige la captura del telefono (formulario)
> antes de encender, no se sube el tope.

---

## 9. F4 — Smoke obligatorio (el criterio que vale)

**Leccion H1:** un dry-run con `0` filas no prueba nada, y un smoke que solo verifica "no lanzo
excepcion" tampoco. F4 exige **1 destinatario, 1 tipo, datos reales, resultado observado**.

Preparacion:

1. Un evento **real** con `evento_inicio` dentro de la ventana del tipo elegido (**56 h**).
2. Un inscrito real de ese evento cuyo telefono sea **uno de la lista de prueba** (seccion 2, paso 5).
   No se escribe a un tercero.
3. `canal_flags` con `activo=true, dry_run=true` para que la RPC recorra pero **no** llame a Graph.
   Este paso es el unico que exige encender `activo` antes de tiempo, y es seguro **porque `dry_run`
   sigue en `true`**.

Ejecucion (una sola corrida, tipo `anticipacion`):

```sql
SELECT public.fn_enviar_recordatorios_wa_pendientes(true, 1, 120, 'f4-smoke', true);
```

### Observacion 1 — inmediatamente despues de la corrida

```sql
SELECT id, estado, pg_net_request_id, wa_message_id, error_code, enviado_at, idempotency_key
  FROM public.wa_envios_log
 WHERE origen = 'f4-smoke'
 ORDER BY created_at DESC LIMIT 5;
```

Esperado: **`estado='enviado'`**, **`pg_net_request_id` NO nulo** y **`wa_message_id` todavia nulo**.
Eso significa que la peticion salio a Graph (`net.http_post` la encolo) y que la respuesta aun no se ha
reconciliado. Si `pg_net_request_id` es nulo, la peticion **no salio**: no se sigue.

### Observacion 2 — despues de reconciliar

```sql
SELECT public.fn_wa_reconciliar_respuestas();
```

```sql
SELECT id, estado, wa_message_id, error_code, error_texto, enviado_at
  FROM public.wa_envios_log
 WHERE origen = 'f4-smoke'
 ORDER BY created_at DESC LIMIT 5;
```

Esperado: **`wa_message_id` NO nulo**, **`error_code` nulo** y **`enviado_at` NO nulo**. Un
`wa_message_id` con formato `wamid.*` es la prueba de que Meta acepto el mensaje.

### Evidencia adicional obligatoria

- **Captura visual** del mensaje en el telefono de la lista de prueba (remitente, texto con las
  variables sustituidas y hora).
- **El link de la plantilla abre el evento correcto** (mismo slug, misma fecha, mismo lugar).

F4 esta verde solo con las **dos observaciones separadas** y la evidencia visual. Con una sola de las
dos, o con "no fallo", F4 **no** esta verde y no se enciende nada.

---

## 10. Encendido

**En este orden y nunca en el mismo `UPDATE`.** Dos escrituras separadas, cada una verificable:

```sql
-- PASO 1: habilitar el canal (todavia en dry_run).
UPDATE public.canal_flags
   SET activo = true,
       motivo = 'F4 verde 2026-11-01',
       updated_at = now()
 WHERE canal = 'whatsapp';
```

Verificar que el paso 1 quedo escrito y que `dry_run` **sigue en true**. Solo entonces:

```sql
-- PASO 2: salir de dry-run, con tope de arranque 10 (no 50).
UPDATE public.canal_flags
   SET dry_run = false,
       max_envios_por_corrida = 10,
       updated_at = now()
 WHERE canal = 'whatsapp';
```

```sql
-- Paso 3: sacar el dry-run tambien del secreto (requiere REDEPLOY de la Function).
-- supabase secrets set WA_DRY_RUN="0" --project-ref ctgyvydzshueemlelkzv
-- supabase functions deploy send-wa-recordatorio --project-ref ctgyvydzshueemlelkzv --no-verify-jwt
```

**Por que dos pasos y por que 10:** el flag de base de datos **solo puede restringir, nunca habilitar
por si solo**. Con `dry_run=true` la RPC **ni siquiera encola** la peticion a Graph: el paso 1 es
inocuo por construccion y permite comprobar que el `UPDATE` y el `updated_at` quedaron bien antes de
que exista riesgo real. El tope de **10** es el arranque: si algo viene mal, se equivocan 10 personas
y no 50. Se sube despues de una corrida real completa sin errores.

La primera corrida real se revisa en la hora en punto + 10 min (schedule `10 * * * *`), o forzada a mano:

```sql
SELECT public.fn_wa_corrida_programada();
```

---

## 11. Operacion y kill-switch

Tres niveles de apagado. **El mas restrictivo gana:** si cualquiera dice "no", no sale nada.

| Nivel | Como | Efecto | Coste |
|---|---|---|---|
| 1 | `canal_flags.activo = false` | Detiene el canal **entero**, inmediato | Ninguno: **no requiere redeploy** |
| 2 | `recordatorio_reglas.activo = false` por tipo o por evento | Detiene **un tipo** o **un evento**, el resto sigue | Ninguno: es dato |
| 3 | `WA_DRY_RUN=1` | La Function no llama a Graph aunque la base diga enviar | **Requiere redeploy** de la Function |

```sql
-- Nivel 1: apagon inmediato del canal.
UPDATE public.canal_flags
   SET activo = false, motivo = 'kill-switch manual', updated_at = now()
 WHERE canal = 'whatsapp';
```

```sql
-- Nivel 2: apagar solo el post-evento (global).
UPDATE public.recordatorio_reglas
   SET activo = false
 WHERE canal = 'whatsapp' AND tipo = 'post_evento' AND evento_id IS NULL;
```

**Apagado automatico por error 190:** si Graph responde `190` (token invalido o caducado), el
reconciliador `fn_wa_reconciliar_respuestas()` **apaga el canal solo** (`canal_flags.dry_run = true` y
`motivo = 'error 190 token'`). Es el comportamiento correcto: un token vencido no debe reintentar
contra un endpoint que va a fallar todas las horas. Se arregla cargando el token nuevo y repitiendo la
seccion 10.

**Rollback completo** (dejar el canal como estaba antes del encendido, sin perder traza):

```sql
UPDATE public.canal_flags
   SET activo = false, dry_run = true, motivo = 'rollback B9b', updated_at = now()
 WHERE canal = 'whatsapp';

SELECT cron.unschedule('recordatorios-wa');
```

> **Las tablas NO se borran.** `wa_envios_log`, `wa_plantillas` y `recordatorio_reglas` se quedan: la
> traza es auditoria (Cero Borrado, Oro #2/#3). `DROP TABLE` no es un rollback valido aqui; es
> destruccion de evidencia. Si se necesita re-agendar: `SELECT cron.schedule('recordatorios-wa',
> '10 * * * *', $$SELECT public.fn_wa_corrida_programada();$$);`

---

## 12. Observabilidad y techos

```sql
-- Salud del job: ultimas 10 corridas.
SELECT jobid, status, return_message, start_time, end_time
  FROM cron.job_run_details
 WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'recordatorios-wa')
 ORDER BY start_time DESC LIMIT 10;
```

```sql
-- Volumen del mes en curso contra el techo de 500.
SELECT count(*) FILTER (WHERE estado = 'enviado')  AS enviados,
       count(*) FILTER (WHERE estado = 'omitido')  AS omitidos,
       count(*) FILTER (WHERE estado = 'error')    AS errores
  FROM public.wa_envios_log
 WHERE created_at >= date_trunc('month', now());
```

- **Job:** `recordatorios-wa`, schedule `10 * * * *`. Un `status = 'failed'` repetido no es ruido: es el
  canal caido.
- **Vista `v_wa_resumen_diario`: PENDIENTE (F6).** Hoy no existe; el resumen se hace con las consultas
  de arriba. No se cita como si existiera.
- **Techo 500/mes** (`max_envios_por_mes`) con **aviso al 80 %** (`alerta_porcentaje`) emitido como
  `RAISE WARNING` en la corrida: el aviso queda en `cron.job_run_details.return_message`, no llega por
  correo. Alguien tiene que mirarlo.
- **`costo_unitario_usd`** debe cargarlo operaciones con la **tarifa utility de Colombia**. Mientras sea
  `NULL`, el panel muestra **"tarifa sin cargar"** — nunca `0`. Un `0` seria una mentira que hace
  parecer gratis el canal:

```sql
-- Se ejecuta cuando Operaciones confirme la tarifa vigente. NO inventar el valor.
UPDATE public.canal_flags
   SET costo_unitario_usd = NULL,   -- reemplazar NULL por la tarifa real confirmada
       updated_at = now()
 WHERE canal = 'whatsapp';
```

---

## 13. Deuda y bloqueos abiertos

1. **(i) Texto legal del opt-in sin validacion legal**, y sin definir el canal de atencion ni la URL de
   la politica de tratamiento de datos. **Bloquea F4 en la captura real del formulario**, no el codigo:
   el mensaje puede salir, pero no se puede demostrar el consentimiento.
2. **[CERRADO 2026-11-02] (ii) El checkbox `wa_optin` YA existe en el formulario de registro** (dos checkboxes: `#reg-wa-optin` y `#ex-wa-optin`, sin `checked` ni `required`; `node scripts/smoke_registroaforo_wa.js` **77/77 PASS**). Texto original del bloqueo: sin el,
   `wa_envios_log.optin_observado` queda en `false` en todas las filas y la **cobertura del 90 % nunca
   se alcanza**. Es el bloqueo mas grande despues de Meta.
3. **[CERRADO 2026-11-02] (iii) Webhook de estados `delivered` / `read` (F6): codigo y RPC listos** (`supabase/functions/wa-webhook/index.ts`, `fn_wa_estado_meta`, smoke **30/30 PASS**); falta solo suscribir el campo `messages` en Meta. Texto original del bloqueo: hoy el canal sabe que Meta **acepto** el
   mensaje (`wa_message_id`), no que el telefono lo **recibio**. `entrega_estado` queda nulo.
4. **[CERRADO 2026-11-02] (iv) Vista `v_wa_resumen_diario` (F6): creada** en `migrations/adr089b_cierre_no_meta.sql` (BLOQUE 2) con `security_invoker=true`, grano dia/tipo/plantilla y `costo_estimado_usd` en `NULL` si la tarifa es `NULL`; antes el resumen diario era manual.
5. **(v) Corte del email a `recordatorio_reglas` (F5):** el canal de correo sigue con su propia logica;
   unificarlo exige una **migracion atomica** (no se hace por partes).
6. **[CERRADO 2026-11-02] (vi) Retencion de las filas `omitido_motivo='dry_run'`: resuelta** con `public.fn_wa_limpiar_dry_run(p_dias int default 30)` (minimo 7 dias; solo `estado='omitido' AND omitido_motivo='dry_run'`; el cron queda **comentado a proposito**). Texto original del bloqueo: no se decide ahora. Un dry-run persistido
   deja filas de auditoria; si se limpian o se archivan, se define en F6.
7. **[CERRADO 2026-11-02] (vii) `wa_plantillas.nombre_logico` YA tiene `CHECK` de minusculas:** `wa_plantillas_nombre_logico_chk` (`^[a-z0-9_]{1,120}$`) e `wa_plantillas_idioma_chk`, con guarda previa que **aborta** listando hasta 5 infractores en vez de renombrar en silencio (renombrar romperia la FK textual `recordatorio_reglas.plantilla`). Texto original del bloqueo: la Edge Function rechaza
   mayusculas con `400`, pero la base las acepta: un nombre con mayusculas entra sin error y falla en
   runtime. Se corrige escribiendo en minusculas, siempre.

---

## 14. Checklist final

- [ ] Negocio verificado en Meta
- [ ] Numero emisor verificado (uno solo, decision D4)
- [ ] Token permanente de System User cargado en `WA_TOKEN`
- [ ] 3 plantillas aprobadas por Meta
- [ ] Secretos cargados (`secrets list` los muestra)
- [ ] Edge Function desplegada (`send-wa-recordatorio`)
- [ ] `wa_plantillas` poblada (3 filas, `estado_meta='aprobada'`)
- [ ] Reglas cargadas (3 globales de `whatsapp`, `activo=true`)
- [ ] F1 #1-#9 verdes
- [ ] Dry-run con muestra correcta (orden de variables y `link` real)
- [ ] Menos del 20 % de telefonos invalidos
- [ ] F4 verde con `wa_message_id` y captura visual
- [ ] `canal_flags.activo = true`
- [ ] `canal_flags.dry_run = false` (y `WA_DRY_RUN=0` con redeploy)
- [ ] Primera corrida real con tope 10, sin errores
- [ ] `costo_unitario_usd` cargado con la tarifa utility de Colombia
- [x] Migracion `migrations/adr089b_cierre_no_meta.sql` aplicada a mano en el SQL Editor (2026-11-02)
- [x] Verificaciones **V1-V8** del propio archivo adr089b en verde (18/18: 14 parte 1 + 4 parte 2, y V1 re-ejecutada sin error)
- [x] Edge Function `wa-webhook` desplegada el 2026-11-02 (`supabase functions deploy wa-webhook --project-ref ctgyvydzshueemlelkzv --no-verify-jwt`)
- [ ] Webhook suscrito en Meta con el campo `messages` y el verify token igual a `WA_VERIFY_TOKEN`

---

## 15. ADR-089b - cierre de lo que no depende de Meta (2026-11-02)

Cierra la parte del canal que **no** depende del aprovisionamiento de Meta. El codigo y la migracion
estan escritos y verificados; lo que falta es **aplicar la migracion a mano** y completar la
configuracion externa.

1. **`migrations/adr089b_cierre_no_meta.sql` (470 lineas, ASCII-safety 0 bytes > 127, cero `DROP`/`TRUNCATE`).**
   **NO se aplica solo:** se pega **A MANO** en `Supabase Dashboard > SQL Editor > New query` con
   `service_role`. Contiene 4 bloques:
   *   **BLOQUE 1 - CHECKs de plantillas:** `wa_plantillas_nombre_logico_chk` (`^[a-z0-9_]{1,120}$`) e
       `wa_plantillas_idioma_chk` (`^[a-z]{2,3}(_[A-Z]{2})?$`). Antes de crearlos, una **guarda** aborta
       listando hasta 5 infractores: **no renombra en silencio**, porque renombrar romperia la FK textual
       `recordatorio_reglas.plantilla`.
   *   **BLOQUE 2 - vista `public.v_wa_resumen_diario`:** `security_invoker=true`, grano dia/tipo/plantilla.
       `costo_estimado_usd` queda en **`NULL` si la tarifa es `NULL`** (nunca 0: 0 seria un costo falso).
   *   **BLOQUE 3 - `public.fn_wa_limpiar_dry_run(p_dias int default 30)`:** minimo **7 dias**; solo borra
       `estado='omitido' AND omitido_motivo='dry_run'`. El **cron queda COMENTADO a proposito**: activarlo
       es decision de operaciones, no del codigo.
   *   **BLOQUE 4 - `public.fn_wa_estado_meta(p_message_id, p_estado, p_at, p_error_code)`:** `SECURITY DEFINER`,
       `GRANT` solo a **`service_role`**; **nunca lanza excepcion** y los estados solo **avanzan**
       (`sent` < `delivered` < `read`; `failed` no pisa `read`).
2. **Verificaciones V1-V8 (comentadas al final del archivo):** se corren **despues** del `COMMIT`.
   Cubren: (V1) idempotencia, (V2) constraints, (V3) `security_invoker`, (V4) costo `NULL`,
   (V5) guardas de retencion, (V6) RPC con payload raro, (V7) permisos, (V8) `anon` sin privilegios.
3. **Despliegue del webhook:** `supabase functions deploy wa-webhook --project-ref ctgyvydzshueemlelkzv --no-verify-jwt`. **Hecho el 2026-11-02.** Verificado en produccion: `GET` con el token correcto devuelve el `hub.challenge` byte a byte (200), token incorrecto devuelve `403 verificacion_fallida`, y `POST` sin `WA_APP_SECRET` devuelve `503 servicio_misconfigurado` (fail-closed). El `503` desaparece cuando se cargue el App Secret de Meta.
   La funcion (`supabase/functions/wa-webhook/index.ts`, 535 lineas) valida el GET con `hub.challenge`
   (**403** si el token no coincide o esta vacio) y el POST con HMAC `X-Hub-Signature-256` contra
   `WA_APP_SECRET` (**401** sin firma valida y **cero** llamadas al RPC; **503** si falta el secreto),
   con techo de **20 estados por request** y concurrencia **5**. Responde **200 fijo** aunque el RPC diga
   `no_encontrado`: Meta reintenta ante non-200 y el reintento no arregla nada. Arnes:
   `node scripts/smoke_wa_webhook.js` -> **30/30 PASS**.
4. **Suscripcion en Meta (unica parte que queda fuera del repo):** en la app de Meta, suscribir el campo
   **`messages`** del WABA con Callback URL
   `https://<project-ref>.supabase.co/functions/v1/wa-webhook` y **verify token igual a `WA_VERIFY_TOKEN`**
   (los dos secretos nuevos del bloque WhatsApp en `.env.example`).
5. **Permisos:** el RPC de estados **solo acepta `service_role`**; ninguna clave publica puede mover
   `entrega_estado`.
6. **Sigue fuera de alcance (deliberado):** F5 (corte del email a `recordatorio_reglas`), texto legal del
   opt-in y URL de la politica de privacidad, opt-in del formulario del landing en `evento-app.html`
   (motor de render, exigiria redaccion de tipo MARKETING), `eventovenezuela.html` (checkbox legacy
   `reg-autorizacion`, sin tocar) y **todo** el aprovisionamiento de Meta.
