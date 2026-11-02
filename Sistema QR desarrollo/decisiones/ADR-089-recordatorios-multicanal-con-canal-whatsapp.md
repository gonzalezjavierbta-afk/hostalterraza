---
doc: ADR-089
version: v1.2-ACEPTADO
fecha: 2026-11-01
revision: 2026-11-01 por @architect-review. Dictamen final ACEPTADO (pendiente de implementacion). Se conserva el dictamen original APROBADO CON CONDICIONES: las condiciones B1-B2 y A1-A3 se incorporaron al documento. Nada se borro del diseno original: las piezas marcadas `[REV-089]` son adiciones o matices del revisor sobre el texto del autor.
origen: Recordatorios multicanal (email + WhatsApp via Meta Cloud API) con tabla de reglas por canal. Diseno de arquitectura, sin implementacion. Gate de riesgo de AGENTS.md seccion 2 (arquitectura/ADR) AUTORIZADO por el usuario.
version_previa: ADR-088
relacionados: [../DECISIONS.md, ADR-073-columna-canonica-del-instante-del-evento-evento-inicio.md, ADR-074-configuracion-del-recordatorio-automatico-antes.md, ADR-076-camino-unico-de-envio-de-correo-con-secreto.md, ADR-077-gateway-de-correo-de-los-5-call-sites-rpc-como-camino-unico.md, ADR-078-cron-de-recordatorios-automaticos.md]
estado: ACEPTADO (pendiente de implementacion) - aprobado por @architect-review el 2026-11-01; nada de este ADR esta aplicado en la base
estructura: detalle-v1 (2026-10-01)
nota_numeracion: El ID pedido era ADR-079, pero ese ID YA ESTA ASIGNADO (decisiones/ADR-079-checkin-multi-punto-con-override-por-ticket.md, aplicado 2026-10-07). ADR-087 y ADR-088 tambien estan asignados en el indice de DECISIONS (filas 102-103, 2026-11-01) aunque su ficha no exista. Siguiente numero libre verificado: 089 (0 archivos ADR-089*, 0 migraciones adr089*). Cero Borrado: no se sobrescribe ningun ADR previo.
---

> Detalle de [DECISIONS.md](../DECISIONS.md) - [INDEX](../INDEX.md).

## ADR-089: Recordatorios multicanal con canal WhatsApp via Meta Cloud API

**Fecha:** 2026-11-01

**Autor:** @architect (diseno). Implementacion prevista: @sql-security (esquema/RLS), @backend-dev (RPC + Edge Function), @admin-dev (sub-tab), @qa-auditor (smoke).

**Estado:** ACEPTADO (pendiente de implementacion) el 2026-11-01 por @architect-review. Sin migracion escrita, sin Edge Function, sin cambios en `admin.html`. Este documento es el contrato de diseno; nada de lo que figura aqui esta aplicado en la base `ctgyvydzshueemlelkzv`. El dictamen de revision con los 14 hallazgos y sus correcciones esta en §0.

---

## 0. Dictamen de revision (2026-11-01, @architect-review)

**Dictamen global: APROBADO CON CONDICIONES.** El diseno es correcto en lo estructural (modelo de reglas por canal, dos canales sin tocar el camino de correo, fail-closed, 0 endpoints Vercel, idempotencia y `omitido_motivo` como columnas de primer nivel). Las condiciones no reabren decisiones de Direccion (D1-D6): son correcciones de contrato de implementacion.

### 0.1 Hallazgos con severidad

| ID | Sev | Punto | Hallazgo (verificado contra archivo real) | Correccion aplicada |
|---|---|---|---|---|
| B1 | BLOQUEANTE | nuevo | `pg_net` es **asincrono**: `net.http_post` encola y devuelve un `request_id`, no la respuesta de Meta (`adr076:202-205` y `:1026-1030` lo documentan; `adr076` dejo la reconciliacion como deuda). El ADR original suponia un `202` sincrono y que el codigo de error de Meta llega al RPC: con eso, `wa_message_id` y `error_code` nunca se llenarian y §4.4 seria inejecutable. | §3.7.8 y nueva §3.8: el RPC solo **encola** (`estado='enviado'` = encolado, igual que el correo) y un reconciliador `fn_wa_reconciliar_respuestas()` lee `net._http_response` por `pg_net_request_id` y es el unico que escribe `wa_message_id`, `error_code` e `intentos`. §4.4 pasa a ser contrato del reconciliador. |
| B2 | BLOQUEANTE | g / h | Dos agujeros en el camino de escritura: (1) `INSERT ... ON CONFLICT DO NOTHING` **antes** de la red deja la fila `pendiente` envenenada si la corrida muere (el UNIQUE impide reintentarla para siempre); (2) si `WA_DRY_RUN=1` en el Edge pero `canal_flags.dry_run=false` en BD, el RPC encola, el Edge no envia y la fila queda `enviado` **sin wamid**, con lo que el envio real nunca ocurre: el flag de BD estaria *ampliando* el entorno, que es exactamente lo prohibido en §7.1. | §3.7.6: la fila `pendiente` con `pg_net_request_id IS NULL AND intentos < 3` **es reintentable** en la corrida siguiente. §3.7.2: el SQL nunca encola si `canal_flags.dry_run = true` (autoridad en BD, el Edge es solo cinturon). §3.3: indice unico parcial que excluye las filas de dry-run. El reconciliador degrada a `omitido/dry_run` si el Edge respondio `{dryRun:true}`. |
| A1 | ALTA | b | `CREATE OR REPLACE FUNCTION` **no reemplaza** al cambiar la lista de parametros: crea un **overload**. Con `fn_horas_recordatorio(text, text, text)` convivirian la vieja `(text)` con su body legado y la nueva, y el "corte" de §3.5 paso 3 no ocurriria aunque la migracion dijera lo contrario. Ademas el conteo de llamadores es impreciso: los reales son **2 invocaciones dentro de la funcion APLICADA** (`adr078b:163-164`); `adr078:91-92` es el archivo superado y `B9-smoke-email.md:236-240` son consultas de diagnostico, no runtime. Ningun llamador se rompe con `NULL`, porque ninguno pasa 2 ni 3 argumentos. | §3.6 reescrita: la migracion define la funcion de 3 parametros y **redefine la de 1 argumento como wrapper que delega**, en la misma transaccion; prohibido dejar dos bodies divergentes. Se documenta el conteo real. |
| A2 | ALTA | f | Contradiccion interna: §3.1 resuelve `reglas -> config -> default`, pero §3.5 pasos 1-3 dice que el cron sigue leyendo `config_recordatorios` hasta F5. Con las dos lecturas activas hay dos fuentes de verdad y la mitigacion "backfill despues de cada edicion" no esta garantizada (no hay trigger ni funcion obligatoria). | §3.5 reescrita: **hasta F5 el email vive solo en `config_recordatorios`** (la UI de email escribe alli; las reglas de email son espejo de solo lectura del backfill). Con eso no hay dos fuentes en ningun momento y el corte es una migracion atomica. |
| A3 | ALTA | h | Dry-run bajo `pg_cron`: el jsonb de retorno se pierde, asi que "0 filas" implica **cero observabilidad** de los omitidos en operacion programada, y el conteo de "omitidos" que el ADR promete no existe. | §3.7.10: `p_persistir_dry_run boolean DEFAULT false`. En F3 (manual) se mantiene "0 filas"; en corrida programada se puede persistir con `omitido_motivo='dry_run'`, fila que el indice unico parcial excluye y que por tanto **no envenena la idempotencia**. |
| M1 | MEDIA | c | La FK por TEXTO a `wa_plantillas.nombre_logico` es valida (la columna es UNIQUE), pero `ON UPDATE CASCADE` seria **contraproducente**: el nombre es el contrato con Meta y `wa_envios_log.plantilla` no tiene FK, de modo que un CASCADE reescribiria las reglas y dejaria el historico con el nombre viejo, en silencio. | §3.1/§3.2: FK con comportamiento por defecto (**NO ACTION**), `COMMENT ON COLUMN` que prohibe renombrar (renombrar = fila nueva), y **orden DDL corregido**: `wa_plantillas` se crea antes que `recordatorio_reglas`. |
| M2 | MEDIA | a | Los dos indices parciales resuelven el muro NULL de `adr074:27-30` y se aprueban. Falta el caso `activo=false`: el unique `(canal,tipo)` impide **crear** un reemplazo, la UI debe hacer UPDATE/upsert. Ademas el esquema fija **techo de 3 reglas por canal** (una por `tipo`): una segunda anticipacion exigiria tocar el CHECK y la clave de idempotencia, que no incluye `horas_offset`. | §3.1: nota de upsert y limite declarado del techo de 3 tipos. |
| M3 | MEDIA | nuevo | §3.7.5 normaliza `coalesce(nullif(btrim(i.whatsapp),''), i.telefono)`: si `whatsapp` trae basura (`"-"`, `"N/A"`) el helper devuelve `NULL` y **nunca se prueba `telefono`**, aunque sea valido. Es la misma clase de bug que H1 (un valor plausible que mata el envio). | §3.7.5: dos intentos en orden (`whatsapp`, luego `telefono`) y se registra cual se uso. |
| M4 | MEDIA | nuevo | Sin exclusion mutua: un reenvio manual concurrente con la corrida horaria puede encolar el mismo destinatario dos veces si ambas leen antes de insertar. | §3.7.6: `pg_try_advisory_lock` por canal; quien no toma el lock devuelve `skipped='en_curso'`. |
| M5 | MEDIA | e | `dia_evento` omitiendo a `used=true` es correcto **si y solo si** la omision se registra; si no, se repite H3 (`B9-smoke-email.md:115`, el contador que no distingue el motivo). Falta ademas la simetria de `post_evento`: agradecer a quien no asistio es peor que el ruido de `dia_evento`. | §3.7.4: se aprueba la omision **con** `omitido_motivo='checkin_previo'`, y se propone la regla espejo para `post_evento` (omitir `used=false`). Queda en §13 como decision de Direccion. |
| M6 | MEDIA | nuevo | `net._http_response` se purga: el reconciliador debe correr en **cada** corrida y no asumir retencion larga; si la respuesta ya no esta, la fila no se puede resolver por esa via. | §3.8: reconciliacion en cada corrida, con `intentos` como unico juez de abandono. |
| B3 | BAJA | d | Numeracion: **confirmada 089**. `DECISIONS.md:102-103` son ADR-087/088, ADR-086 esta en `:101`, `decisiones/` no tiene `ADR-089*` previo y `migrations/` no tiene `adr08*` mas alla de `081/082/083/088`. 0 colisiones. | Sin cambios; se deja la nota de numeracion del autor intacta. |
| B4 | BAJA | nuevo | `wa_envios_log.plantilla` deliberadamente **sin FK** es correcto: el log debe conservar el nombre enviado aunque la plantilla se borre o se renombre. Se explicita para que no se "arregle" por error. | §3.3: nota. |
| B5 | BAJA | i | El ADR ya exigia smoke con numero verificado (F4). Se refuerza: la leccion H1 dice que el dry-run con 0 filas no valida nada, asi que F4 debe ademas verificar la fila **despues de reconciliar** (`wa_message_id` no nulo), no el retorno sincrono. | §9 F4 ampliada con el criterio de reconciliacion. |

### 0.2 Lo que se aprueba sin condicion

- (a) Los dos indices unicos parciales (`WHERE evento_id IS NOT NULL` / `IS NULL`) son la solucion correcta al muro NULL documentado en `adr074:27-30` y replican el precedente `idx_config_recordatorios_global` (`adr074:273`).
- (d) El ID 089 no colisiona.
- Convivencia sin relajar el `CHECK (canal IN ('email'))` de `adr074:129`: se aprueba no tocar ese CHECK.
- 0 endpoints nuevos: coherente con el presupuesto 8/8 (ADR-002 plataforma).
- Reutilizar `SERVICE_SHARED_TOKEN` en vez de un secreto nuevo para el mismo backend.
- `variables` como array ordenado (Meta es posicional) y `categoria` como dato.

---

## 1. Contexto y problema

### 1.1 Lo que ya existe (verificado en archivo real, ADR-006)

| Pieza | Ubicacion verificada | Estado |
|---|---|---|
| RPC unica de correo | `migrations/adr076_enviar_email_seguro.sql:731-745` (`p_email, p_nombre, p_qr_code, p_evento_nombre, p_evento_fecha, p_evento_hora, p_evento_lugar, p_idempotency_key, p_tipo, p_cedula, p_evento_id, p_inscrito_id, p_bypass_rate_limit`) | implementada |
| Traza de correo | `adr076:209-225` (`email_envios_log`, `idempotency_key text UNIQUE`, `estado`, `intentos`, `error_texto`) | implementada |
| Transporte de correo | `supabase/functions/send-ticket-email/index.ts` (Resend, auth dual `X-Service-Token` / JWT, comparacion en tiempo casi constante en `:142`) | desplegada |
| Cron | `migrations/adr078_cron_recordatorios.sql` + job `recordatorios-horarios` `5 * * * *` | ACTIVE |
| Hotfix | `migrations/adr078b_fix_cron_recordatorios.sql` v1.1 (2026-11-01) | aplicado |
| Config | `public.config_recordatorios` (`adr074:84-92`) | vigente, un solo canal |

`config_recordatorios` declara literalmente en `adr074:41-43`: "CHECK canal: solo 'email' por ahora. Se agrega el valor al CHECK cuando exista el canal (whatsapp, sms)". Es decir, la ampliacion a WhatsApp estaba **prevista y diferida**, no prohibida.

### 1.2 El problema

1. **Un solo tipo de recordatorio.** Hoy existe un unico offset (`horas_anticipacion`, default 56 h) y un solo canal. No hay "dia del evento" ni "post-evento", y no hay WhatsApp.
2. **El canal de correo estuvo roto sin que nadie lo supiera.** La definicion de ADR-078 abortaba **siempre** antes de enviar: `p_qr_code => ''` contra un parametro obligatorio lanzaba `SQLSTATE 22023` y mataba la corrida completa (H1, `adr078b` cabecera). No lo detecto la revision de codigo ni el dry-run sin datos: se detecto con **fixtures reales**. **Leccion normativa de este ADR: ningun canal se declara listo sin un smoke contra datos reales de produccion, y la verificacion debe mirar el estado final de la traza (`estado='enviado'` + `wa_message_id`), no que "la funcion no lance excepcion".**
3. **Cero observabilidad por canal.** Sin `canal` en la traza, el panel no puede responder "cuantos correos fallaron esta semana" ni "cuantos WhatsApp rebotaron por numero invalido".
4. **Cero UI.** No existe panel de recordatorios: el envio manual es un deep link `wa.me` (27 coincidencias en el repo) y `admin.html:9309` para correo.
5. **Datos ya disponibles pero sin usar.** `inscritos` ya tiene `whatsapp`, `telefono`, `cedula`, `qr_code`, `used`, `evento_id` (uso verificado en `admin.html:10871`: `i.whatsapp`, `i.telefono`). El telefono esta, la tuberia no.

### 1.3 Restricciones de plataforma

- **Presupuesto Vercel Hobby 8/8 agotado:** no se crea ningun endpoint en `api/*.js`. El transporte de WhatsApp va por **Supabase Edge Functions**, que es un presupuesto distinto y hoy tiene una sola funcion (`send-ticket-email`). Esto **no** consume cupo de Vercel y **no** requiere plan de pago.
- `pg_net` ya esta instalado (0.20.0, ADR-078); es el unico puente SQL -> HTTP.
- Vanilla JS, sin build tools (ADR-001).

---

## 2. Decision

Se adopta un **modelo de reglas por canal** (no un campo `canal` en la config existente) y un canal WhatsApp con **plantillas de Meta**, envio por `pg_net` -> Edge Function -> Meta Cloud API.

### 2.1 Decisiones cerradas por Direccion (no se reabren en este ADR)

| # | Decision |
|---|---|
| D1 | Proveedor: **Meta Cloud API** directo (no Twilio, no BSP). |
| D2 | Offsets: **anticipacion 56 h**, **dia del evento 0 h**, **post-evento +24 h**. Editables por evento. |
| D3 | Modelo de datos: **tabla de reglas por canal** `recordatorio_reglas`, extensible a SMS. |
| D4 | **Un solo numero emisor** para tickets y recordatorios (mismo `phone_number_id` de la WABA). |
| D5 | Opt-in: se captura checkbox `wa_optin` en el registro; el **bloqueo** por falta de opt-in queda DIFERIDO. |
| D6 | La implementacion corre en `WA_DRY_RUN=1` hasta que existan WABA, plantilla aprobada y token permanente. |

### 2.2 Convencion de signo (clave del diseno)

`horas_offset` es **con signo** y se interpreta como "horas respecto a `eventos.evento_inicio`":

- anticipacion: `+56` -> 56 h antes del inicio.
- dia_evento: `0` -> a la hora de inicio.
- post_evento: `-24` -> 24 h despues del inicio.

Con esta convencion el calculo del objetivo es **una sola expresion** y no necesita ramas por tipo:

```
objetivo = eventos.evento_inicio - make_interval(hours => horas_offset)
```

`-24` produce `evento_inicio + 24 h` de forma aritmetica. Esto es exactamente lo que ya hace el cron de ADR-078 (`now()`, `make_interval(hours => fn_horas_recordatorio(e.id))`), asi que el motor de ventana **no cambia de forma**, solo cambia de donde lee el numero.

---

## 3. Modelo de datos (DDL de diseno, NO ejecutable tal cual)

> Estas estructuras son **diseno**. La migracion final la escribe @sql-security con el patron idempotente del repo (`CREATE TABLE IF NOT EXISTS`, `DO` con guarda en `pg_constraint`, `NOTIFY pgrst`), y no puede ejecutarse sin el gate de AGENTS.md seccion 2.

### 3.1 `public.recordatorio_reglas`

```sql
CREATE TABLE public.recordatorio_reglas (
    id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    evento_id       text        REFERENCES public.eventos(id) ON DELETE CASCADE,  -- NULL = global
    canal           text        NOT NULL,
    tipo            text        NOT NULL,
    horas_offset    integer     NOT NULL,
    plantilla       text        REFERENCES public.wa_plantillas(nombre_logico),  -- [REV-089] sin ON UPDATE CASCADE, ver 3.2
    activo          boolean     NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT recordatorio_reglas_canal_chk
        CHECK (canal IN ('email','whatsapp','sms')),
    CONSTRAINT recordatorio_reglas_tipo_chk
        CHECK (tipo IN ('anticipacion','dia_evento','post_evento')),
    CONSTRAINT recordatorio_reglas_offset_chk
        CHECK ( (tipo = 'anticipacion' AND horas_offset >  0 AND horas_offset <= 720)
             OR (tipo = 'dia_evento'   AND horas_offset =  0)
             OR (tipo = 'post_evento'  AND horas_offset <  0 AND horas_offset >= -168) ),
    CONSTRAINT recordatorio_reglas_plantilla_chk
        CHECK (canal <> 'whatsapp' OR plantilla IS NOT NULL)
);
```

**Unique que evita reglas duplicadas (el punto fino).** Un `UNIQUE (evento_id, canal, tipo)` **no sirve**: en Postgres los `NULL` no colisionan entre si, asi que permitiria N filas globales duplicadas. Es el mismo muro documentado en `adr074:27-30` y por eso ADR-074 tuvo que anadir un indice unico **parcial**. Aqui se resuelve igual, con dos indices:

```sql
CREATE UNIQUE INDEX recordatorio_reglas_ev_uq
    ON public.recordatorio_reglas (evento_id, canal, tipo)
    WHERE evento_id IS NOT NULL;

CREATE UNIQUE INDEX recordatorio_reglas_global_uq
    ON public.recordatorio_reglas (canal, tipo)
    WHERE evento_id IS NULL;
```

Resultado: **como maximo una regla por (evento, canal, tipo)** y **como maximo una global por (canal, tipo)**. Las dos escrituras (override y global) son independientes.

**[REV-089] Consecuencia que la UI no puede ignorar:** el unique no distingue `activo`. Un `INSERT` de reemplazo para un `(canal,tipo)` que ya tiene fila inactiva falla con `23505`. La UI de §8 escribe con **upsert por la clave natural** (`ON CONFLICT (evento_id, canal, tipo)` no nombra indices parciales, asi que se resuelve con `UPDATE` y, si `row_count = 0`, `INSERT`), nunca con `INSERT` ciego. `activo` es un estado de la fila, no una baja logica.

**[REV-089] Limite declarado (techo de 3 reglas por canal):** como `tipo` esta cerrado en 3 valores y el unique es `(evento_id, canal, tipo)`, no cabe una segunda anticipacion (p.ej. 56 h + 24 h) para el mismo canal y evento. Si Direccion la pide, la evolucion es cambiar el unique a `(evento_id, canal, tipo, horas_offset)` **y** meter el offset en `idempotency_key` (§3.3), porque hoy dos anticipaciones distintas colisionarian en la clave `whatsapp:<evento>:<inscrito>:anticipacion`. Se declara ahora para que no sea un descubrimiento en produccion.

**Semantica de resolucion** (una sola regla efectiva por evento/canal/tipo):

1. fila del evento (`evento_id = X`), si existe;
2. si no, fila global (`evento_id IS NULL`);
3. si no hay ninguna, el valor de `config_recordatorios` (compatibilidad);
4. si tampoco, default de negocio (56 h para anticipacion, sin envio para dia_evento/post_evento).

**Por que `plantilla` es `text` y no `uuid`:** la Edge Function necesita el **nombre exacto** que Meta conoce, no un UUID interno. Un FK por nombre logico hace el SELECT del admin y el payload del transporte legibles sin un JOIN extra, y el log guarda el nombre, no un UUID huerfano. `wa_plantillas.nombre_logico` es UNIQUE, que es lo que exige un FK.

### 3.2 `public.wa_plantillas`

```sql
CREATE TABLE public.wa_plantillas (
    id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre_logico     text        NOT NULL UNIQUE,          -- recordatorio_56h, recordatorio_dia, gracias_post
    meta_template_id  text        UNIQUE,                   -- nombre registrado en Meta (suele coincidir)
    idioma            text        NOT NULL DEFAULT 'es_CO', -- BCP-47; Meta exige el idioma exacto
    categoria         text        NOT NULL DEFAULT 'UTILITY',
    variables         jsonb       NOT NULL DEFAULT '[]'::jsonb, -- array ORDENADO: ["nombre","evento","fecha_hora","ubicacion","slug"]
    preview           text,                                 -- texto con {{1}}..{{5}} para el panel
    estado_meta       text        NOT NULL DEFAULT 'borrador',
    activo            boolean     NOT NULL DEFAULT true,
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT wa_plantillas_categoria_chk
        CHECK (categoria IN ('UTILITY','MARKETING','AUTHENTICATION')),
    CONSTRAINT wa_plantillas_estado_chk
        CHECK (estado_meta IN ('borrador','pendiente','aprobada','rechazada','pausada'))
);
```

**[REV-089] Orden DDL obligatorio:** `wa_plantillas` se crea **antes** que `recordatorio_reglas`, porque esta ultima la referencia. En este documento la tabla de reglas aparece primero por razones narrativas; la migracion invierte el orden. Un `CREATE TABLE` con FK a una tabla inexistente falla con `42P01` y aborta el `BEGIN`.

**[REV-089] La FK textual es fragil por diseno, y se acepta:** `wa_plantillas.nombre_logico` es UNIQUE, que es lo unico que un FK exige, y el nombre es el identificador que Meta conoce. La fragilidad real es el **renombrado**:

- `ON UPDATE CASCADE` **no se usa**. Un CASCADE reescribiria `recordatorio_reglas.plantilla` en silencio, mientras `wa_envios_log.plantilla` (sin FK, a proposito) conservaria el nombre viejo: el historico quedaria mintiendo sobre lo enviado. Con el comportamiento por defecto (`NO ACTION`) el renombrado queda **bloqueado** mientras haya reglas apuntando a esa fila, que es la proteccion deseada.
- `ON DELETE` por defecto (`NO ACTION`) por la misma razon: borrar una plantilla referenciada debe fallar, no arrastrar reglas.
- `COMMENT ON COLUMN public.wa_plantillas.nombre_logico` debe decir literalmente que **no se renombra**: si Meta exige otro nombre, se crea una **fila nueva** con `activo=false` en la vieja. El nombre es contrato externo, no una etiqueta interna.

`variables` es un **array**, no un objeto, porque en Meta las variables son **posicionales** (`{{1}}`, `{{2}}`, ...): el orden **es** el contrato. Guardarlo como objeto permitiria un reordenamiento silencioso que rompe el envio con `132000`.

**Categoria:** un recordatorio a un inscrito es **UTILITY** (transaccional). Si Meta reclasifica la plantilla a MARKETING, cambia el precio y la politica de opt-in se vuelve exigible de facto. Por eso `categoria` es un dato de la tabla y no un literal en el codigo.

### 3.3 `public.wa_envios_log` (espejo de `email_envios_log`)

```sql
CREATE TABLE public.wa_envios_log (
    id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    evento_id         text,
    inscrito_id       text,
    telefono_e164     text        NOT NULL,        -- normalizado, nunca el crudo del formulario
    telefono_origen   text,                        -- [REV-089] whatsapp | telefono: de que campo salio
    entrega_estado    text,                        -- [REV-089] F6 (webhook): delivered | read | failed
    entrega_at        timestamptz,                 -- [REV-089] F6 (webhook); NO sobrescribe estado
    tipo              text        NOT NULL,        -- anticipacion | dia_evento | post_evento
    canal             text        NOT NULL DEFAULT 'whatsapp',
    plantilla         text,
    estado            text        NOT NULL DEFAULT 'pendiente',
    intentos          integer     NOT NULL DEFAULT 0,
    idempotency_key   text        NOT NULL,         -- whatsapp:<evento_id>:<inscrito_id>:<tipo>; unicidad por indice parcial, ver abajo
    wa_message_id     text,                        -- wamid devuelto por Meta
    error_code        integer,                     -- 131026, 132000, 132001, 131047, 429...
    error_texto       text,
    omitido_motivo    text,                        -- telefono_invalido | sin_whatsapp | optin_off | dry_run
    optin_observado   boolean,                     -- valor de wa_optin al momento del envio (medicion D5)
    origen            text,                        -- cron | manual
    pg_net_request_id bigint,
    created_at        timestamptz NOT NULL DEFAULT now(),
    enviado_at        timestamptz,
    updated_at        timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT wa_envios_log_estado_chk
        CHECK (estado IN ('pendiente','enviado','error','omitido'))
);

-- [REV-089] Unicidad de idempotencia que NO se envenena con el dry-run.
CREATE UNIQUE INDEX wa_envios_log_idem_uq
    ON public.wa_envios_log (idempotency_key)
    WHERE omitido_motivo IS DISTINCT FROM 'dry_run';
```

**[REV-089] Por que el UNIQUE no va en la columna:** con `UNIQUE` en la columna, una fila de dry-run (ver §3.7.10) bloquearia para siempre el envio real del mismo `(evento, inscrito, tipo)`. El indice parcial deja fuera solo las filas `omitido_motivo='dry_run'`, que son **observacion**, no envio. Toda fila real (pendiente, enviado, error, omitido por otra causa) sigue siendo unica: la idempotencia no se relaja.

**[REV-089] `estado='enviado'` significa ENCOLADO, no entregado**, exactamente como en `email_envios_log` (`adr076:202-205`). `pg_net` es asincrono, asi que el RPC no puede saber si Meta acepto. La fila pasa a tener `wa_message_id` **despues** de la reconciliacion (§3.8). Este matiz es el que faltaba y es el hallazgo B1.

**[REV-089] `plantilla` sin FK es deliberado:** `wa_envios_log` debe conservar el nombre enviado aunque la plantilla se borre o se renombre; es traza de auditoria, no un puntero. No se le agrega FK.

Paridad con `email_envios_log` (`adr076:209-225`): `evento_id, inscrito_id, tipo, estado, intentos, idempotency_key UNIQUE, error_texto, created_at, enviado_at, pg_net_request_id`. Campos nuevos y por que:

- `telefono_e164` en lugar de `destinatario`: el dato enviado debe ser **el normalizado**, para que el log sirva para auditar la normalizacion (si guardaramos el crudo, no se podria distinguir un fallo de Meta de un fallo nuestro).
- `error_code` separado de `error_texto`: permite agrupar por codigo sin parsear texto.
- `omitido_motivo`: H3 del canal de correo fue exactamente "el contador no distingue el motivo" (`B9-smoke-email.md:115`). **No se repite ese error.**
- `optin_observado`: mide la cobertura de opt-in **antes** de activar el bloqueo (D5).

**Convencion de idempotencia:** `whatsapp:<evento_id>:<inscrito_id>:<tipo>`. El reenvio manual **no** reutiliza la clave (es UNIQUE): crea `...:anticipacion#r2`, `#r3`. Asi el reenvio queda trazado como evento nuevo y la idempotencia automatica sigue intacta.

### 3.4 `public.canal_flags` (kill-switch sin redesplegar)

```sql
CREATE TABLE public.canal_flags (
    canal                 text        PRIMARY KEY,
    activo                boolean     NOT NULL DEFAULT false,   -- fail-closed: nace apagado
    dry_run               boolean     NOT NULL DEFAULT true,
    requiere_optin        boolean     NOT NULL DEFAULT false,   -- D5: activacion diferida
    max_envios_por_corrida integer    NOT NULL DEFAULT 50,
    max_envios_por_mes    integer    NOT NULL DEFAULT 500,       -- [REV-089] techo aprobado 2026-11-01
    alerta_porcentaje     integer    NOT NULL DEFAULT 80,        -- [REV-089] aviso al 80% del techo
    costo_unitario_usd    numeric(10,5),                         -- lo carga operaciones, no se inventa
    motivo                text,
    updated_at            timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT canal_flags_canal_chk CHECK (canal IN ('email','whatsapp','sms'))
);
```

### 3.5 Convivencia con `config_recordatorios` (legado) sin romper el cron actual

**Estrategia en 3 pasos, sin tocar el cron vigente:**

1. **Fase de lectura doble (no destructiva).** `config_recordatorios` **no se modifica**: su `CHECK (canal IN ('email'))` (`adr074:129`) se queda como esta. No se relaja un CHECK existente para meter un canal nuevo; el canal nuevo tiene su propia tabla. Esto mantiene intacto el camino que hoy funciona.
2. **Backfill (idempotente, aditivo).** Por cada fila de `config_recordatorios` se crea, si no existe, su regla equivalente:

```sql
INSERT INTO public.recordatorio_reglas (evento_id, canal, tipo, horas_offset, activo)
SELECT c.evento_id, 'email', 'anticipacion', c.horas_anticipacion, c.activo
FROM public.config_recordatorios c
WHERE NOT EXISTS (
    SELECT 1 FROM public.recordatorio_reglas r
    WHERE r.canal = 'email' AND r.tipo = 'anticipacion'
      AND r.evento_id IS NOT DISTINCT FROM c.evento_id
);
```

El `IS NOT DISTINCT FROM` es obligatorio: con `=` la fila global (`evento_id NULL`) nunca coincide y el backfill se duplicaria en cada corrida.
3. **Corte (Fase 5).** Cuando las reglas de email lleven un ciclo completo en produccion con traza identica, `fn_enviar_recordatorios_pendientes()` se reapunta a `recordatorio_reglas` y `config_recordatorios` queda como historia (no se borra: Cero Borrado).

Mientras dure la convivencia, **hay dos fuentes de verdad** y eso es un riesgo declarado: la UI escribe en `recordatorio_reglas`, el cron viejo lee `config_recordatorios`. Mitigacion obligatoria: el backfill se ejecuta **despues** de cada edicion en la UI hasta el corte, y el panel muestra la regla efectiva (la resuelta), no la almacenada, para que el operador no vea una config que no se aplica.

**[REV-089] Correccion de A2: no se admite la etapa de "dos fuentes de verdad".** El parrafo anterior describe un estado que hay que **evitar**, no administrar: depende de que un humano vuelva a correr el backfill tras cada edicion (no hay trigger, no hay funcion obligatoria) y un olvido deja al operador viendo una regla que el cron no aplica. Regla sustituida, mas estricta y mas simple:

1. **Hasta F5 el canal email tiene UNA sola fuente: `config_recordatorios`.** El sub-tab de §8, mientras el evento/canal sea `email`, escribe con `POST`/`PATCH` en `config_recordatorios` (con el `CHECK (canal IN ('email'))` intacto y `canal` fijo en `'email'` en el cliente). Las filas `recordatorio_reglas` de canal `email` son **espejo de solo lectura**, poblado por el backfill; el panel las muestra, no las edita.
2. **El backfill corre una vez** en la migracion de F1 y **otra vez** dentro de la migracion de corte de F5 (es idempotente: el `IS NOT DISTINCT FROM` de arriba garantiza que la segunda corrida no duplica).
3. **El corte de F5 es una migracion atomica** en un solo `BEGIN`: backfill final -> `CREATE OR REPLACE` del cron para que lea `recordatorio_reglas` -> se documenta que desde ese commit la UI de email escribe reglas. Si el `COMMIT` falla, el sistema queda exactamente como estaba. No hay ventana con dos escritores.
4. **El canal WhatsApp no participa de esta convivencia en ningun momento:** sus reglas viven solo en `recordatorio_reglas` y su motor solo lee esa tabla. Lo unico que comparte con el email es la forma de la regla, no la fuente de verdad.

Con esto, la frase "backfill despues de cada edicion en la UI" queda retirada como obligacion operativa, y `config_recordatorios` puede seguir siendo la verdad del email durante toda la Fase 1 a F4 sin ambiguedad. Cero Borrado: la tabla legada no se toca ni se borra.

### 3.6 `fn_horas_recordatorio` con offsets negativos

Hoy: `public.fn_horas_recordatorio(p_evento_id text)` (`adr074:352`), devuelve **entero positivo** (override -> global -> 56). Cambiar su semantica romperia los 3 llamadores de ADR-078.

**[REV-089] Correccion de A1 (conteo y mecanismo).** Dos precisiones verificadas con `git grep` sobre el repo real:

1. **Llamadores reales en runtime: 2 invocaciones, no 3, y viven en la funcion APLICADA.** `adr078b_fix_cron_recordatorios.sql:163-164` (hotfix v1.1, APLICADO 2026-11-01) llama `public.fn_horas_recordatorio(e.id)` dos veces dentro de la misma funcion. `adr078_cron_recordatorios.sql:91-92` es el archivo **superado** por el hotfix y ya no corre. `runbooks/B9-smoke-email.md:236-240` son consultas de diagnostico manual, no runtime. Ninguno de los tres pasa 2 ni 3 argumentos, asi que **ninguno se rompe con `NULL`**: el riesgo real no es de firma, es de *overload*.
2. **`CREATE OR REPLACE FUNCTION` no reemplaza al cambiar la lista de parametros: crea un overload.** Si la migracion escribe `CREATE OR REPLACE FUNCTION public.fn_horas_recordatorio(p_evento_id text, p_canal text DEFAULT ..., p_tipo text DEFAULT ...)`, Postgres la crea como funcion nueva y **conserva** la vieja `(text)`. Consecuencia silenciosa: el cron de ADR-078 seguiria llamando a la vieja (match exacto de 1 argumento gana a la expansion de defaults), con el body legado, aunque este ADR diga que la resolucion ahora es rules-first. El "corte" de §3.5 paso 3 no ocurriria nunca y nadie lo notaria.

Mecanismo obligatorio para F1, en **un solo** cuerpo de transaccion:

```sql
-- (1) la funcion nueva, con nombre de parametros estable y search_path fijo
CREATE OR REPLACE FUNCTION public.fn_horas_recordatorio(
    p_evento_id text,
    p_canal     text DEFAULT 'email',
    p_tipo      text DEFAULT 'anticipacion'
) RETURNS integer
LANGUAGE sql STABLE
SET search_path = public, pg_temp
AS $fn$ ... $fn$;

-- (2) el entrypoint de 1 argumento se redefine como WRAPPER que delega.
--     Aqui SI es un CREATE OR REPLACE legitimo: misma firma (text) que la
--     existente, mismo tipo de retorno. Prohibido dejarla con el body viejo.
CREATE OR REPLACE FUNCTION public.fn_horas_recordatorio(p_evento_id text)
RETURNS integer
LANGUAGE sql STABLE
SET search_path = public, pg_temp
AS $fn$ SELECT public.fn_horas_recordatorio($1, 'email', 'anticipacion'); $fn$;
```

Con el wrapper, hay **una sola implementacion** y dos entrypoints; sin el wrapper hay dos implementaciones divergentes. Verificacion de aceptacion en F1: `SELECT pg_get_functiondef('public.fn_horas_recordatorio(text)'::regprocedure)` debe terminar en `$1::text, 'email'::text, 'anticipacion'::text` (o la delegacion equivalente), **no** en el `COALESCE` del legado.

Decision: **firma extendida con parametro opcional**, retrocompatible:

```sql
public.fn_horas_recordatorio(
    p_evento_id text,
    p_canal     text DEFAULT 'email',
    p_tipo      text DEFAULT 'anticipacion'
) RETURNS integer
```

Contrato:
- `p_tipo='anticipacion'`: **nunca devuelve NULL** (mantiene el fallback 56 del legado; los llamadores de 1 argumento no cambian y siguen recibiendo el mismo entero).
- `p_tipo='post_evento'`: devuelve **negativo** (`-24`) o `NULL` si no hay regla activa.
- `p_tipo='dia_evento'`: devuelve `0` o `NULL`.
- `NULL` **significa "no enviar"**: la funcion de envio hace `CONTINUE`, no asume default.

Regla de compatibilidad dura: **si `p_tipo='anticipacion'` y no hay regla, se lee `config_recordatorios` y luego 56**. Asi el cron de ADR-078 no cambia de comportamiento hasta el corte.

### 3.7 `fn_enviar_recordatorios_wa_pendientes()`

```sql
CREATE OR REPLACE FUNCTION public.fn_enviar_recordatorios_wa_pendientes(
    p_dry_run         boolean DEFAULT NULL,   -- NULL = resolver por canal_flags + env
    p_max_envios      integer DEFAULT NULL,   -- NULL = canal_flags.max_envios_por_corrida
    p_margen_minutos  integer DEFAULT 120,
    p_origen          text    DEFAULT 'cron'
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
```

Contrato:

1. **Permisos:** `REVOKE ALL ON FUNCTION ... FROM PUBLIC, anon, authenticated;` y `GRANT EXECUTE ... TO service_role;`. Mismo criterio que `adr076`/`adr078`: una funcion que gasta dinero no es invocable por `anon`.
2. **Fail-closed en 3 capas:** si `canal_flags.activo = false` -> devuelve `{"skipped":"canal_apagado"}` sin tocar nada. Si `dry_run` efectivo es true (por `canal_flags.dry_run` **o** por `WA_DRY_RUN=1`), no escribe red.
   **[REV-089] Quien decide el dry-run en SQL.** El SQL no puede leer `WA_DRY_RUN` (es un secret de la Edge Function), asi que la autoridad del lado base es **`canal_flags.dry_run`**: si es `true`, esta funcion **no llama a `pg_net`** y no existe forma de que una fila de BD lo amplie. `WA_DRY_RUN=1` opera despues, en la funcion, como segundo cinturon. Reglas duras: (i) **si `canal_flags` no tiene fila para el canal, se asume `activo=false, dry_run=true`** (fail-closed, no `coalesce(...,true)` a la ligera: la ausencia de configuracion es ausencia de autorizacion); (ii) si el Edge responde `{dryRun:true}` pese a que la BD dijo enviar, la fila se degrada a `estado='omitido', omitido_motivo='dry_run'` en el reconciliador (§3.8) y **no** se marca `enviado`; (iii) `estado='enviado'` sin `pg_net_request_id` es un estado **prohibido** por construccion.
3. **Ventana:** `abs(now() - (e.evento_inicio - make_interval(hours => r.horas_offset))) <= p_margen_minutos * interval '1 minute'`, con `e.evento_inicio IS NOT NULL` (ADR-073: la columna canonica).
4. **Universo de destinatarios:** `inscritos` del evento con `whatsapp` o `telefono` no vacio. `used` **no** filtra el envio, con una excepcion declarada: `tipo='dia_evento'` **omite** a quien ya tiene `used = true` (avisar "ya empieza" a alguien que ya entro es ruido y sube la tasa de bloqueo). Es la unica regla de negocio que este ADR agrega y debe validarse en revision.
   **[REV-089] Aprobada con dos condiciones (decision de Direccion 2026-11-01, M5).** (i) La omision **se registra**: fila en `wa_envios_log` con `estado='omitido'` y `omitido_motivo='checkin_previo'`. Una omision invisible repite H3 (`B9-smoke-email.md:115`: el contador que no distingue el motivo); (ii) **simetria en `post_evento`**: `tipo='post_evento'` omite a quien tiene `coalesce(used,false) = false`, con `omitido_motivo='sin_checkin'`. Agradecer la asistencia a quien no asistio es peor que el ruido de `dia_evento` y ademas es un dato falso. `anticipacion` no filtra por `used` en ningun caso.
   Margen de `dia_evento`: **120 minutos**, el mismo que el resto (decision de Direccion 2026-11-01). Se descarta el margen de 30 min que este ADR recomendaba en §10.2: con cron horario, 120 min garantiza 2 corridas de reintento dentro de la ventana y el `used` se evalua en el momento del envio, no al calcular la ventana.
5. **Normalizacion:** `telefono_e164 = public.fn_wa_e164_co(coalesce(nullif(btrim(i.whatsapp),''), i.telefono))`. Si es `NULL` -> `INSERT` en `wa_envios_log` con `estado='omitido'`, `omitido_motivo='telefono_invalido'` y `CONTINUE`. **Un numero invalido se registra una vez y nunca se reintenta** (la clave idempotente lo hace imposible por construccion).
   **[REV-089] Correccion M3: dos intentos, no un `coalesce`.** El `coalesce` original prueba `whatsapp` y, si es `NULL` o vacio, `telefono`; pero si `whatsapp` trae **basura** (`'-'`, `'N/A'`, `'pendiente'`) el helper devuelve `NULL` y **`telefono` nunca se intenta**, aunque sea un numero valido. Es la misma clase de bug que H1: un valor plausible que mata el envio en silencio. Orden obligatorio:

   ```
   v_raw  := public.fn_wa_e164_co(nullif(btrim(i.whatsapp), ''));
   v_origen_dato := 'whatsapp';
   IF v_raw IS NULL THEN
       v_raw := public.fn_wa_e164_co(nullif(btrim(i.telefono), ''));
       v_origen_dato := 'telefono';
   END IF;
   ```

   `v_origen_dato` se guarda en `wa_envios_log` (columna `telefono_origen`, ver §3.3) para que el panel sepa **de que campo** salio el numero: sin eso no se puede corregir el formulario, solo el sintoma.
6. **Idempotencia (reescrita por B2).** Se **reserva** la clave antes de la red y la reserva es **recuperable**:

   ```
   INSERT INTO public.wa_envios_log (..., idempotency_key, estado, intentos)
   VALUES (..., v_key, 'pendiente', 0)
   ON CONFLICT (idempotency_key) DO NOTHING;

   IF NOT FOUND THEN
       -- la clave ya existe: hay que mirar en que estado quedo, no basta ignorar
       SELECT estado, intentos, pg_net_request_id INTO ... FROM public.wa_envios_log
        WHERE idempotency_key = v_key;
       IF v_estado = 'pendiente' AND v_req IS NULL AND v_intentos < 3 THEN
           -- corrida anterior murio entre el INSERT y pg_net: SE REINTENTA
           NULL;
       ELSE
           v_omitidos := v_omitidos + 1;  -- ya enviado, en vuelo, agotado o descartado
           CONTINUE;
       END IF;
   END IF;
   ```

   **[REV-089] Por que reservar antes y no insertar despues de la red.** La instruccion de B2 admitia "INSERT despues de la red"; se descarta por un motivo concreto: si el proceso muere **entre** el `http_post` y el `INSERT`, el mensaje ya viajo y no hay traza, con lo que la corrida siguiente lo manda **otra vez** (duplicado real al usuario, que es peor que un reintento perdido). Reservar primero y tratar `pendiente + pg_net_request_id IS NULL + intentos < 3` como **reintentable** elimina el envenenamiento (era el defecto real de B2: una fila `pendiente` sin request_id quedaba bloqueada para siempre por el UNIQUE) sin abrir la ventana de duplicado. La muerte entre INSERT y `http_post` cuesta un reintento; la muerte despues de `http_post` no cuesta nada.
7. **Exclusion mutua (nuevo, M4).** Al entrar: `IF NOT pg_try_advisory_lock(<hashtext('canal:whatsapp')>) THEN RETURN '{"skipped":"en_curso"}'; END IF;` con `pg_advisory_unlock` al salir, en `BEGIN ... EXCEPTION` para no dejar el lock tomado si hay error. Sin esto, un reenvio manual concurrente con la corrida horaria puede pasar los dos el `SELECT` de candidatos y encolar el mismo destinatario dos veces (la clave idempotente lo cubre, pero el usuario recibe dos avisos si el Edge es idempotente solo por clave). El lock es por canal y no bloquea al canal de correo.
8. **Tope por corrida:** `ORDER BY objetivo ASC LIMIT coalesce(p_max_envios, 50)`. Protege el tier de mensajeria de Meta y el costo si un evento tiene 500 inscritos.
   **[REV-089] Tope mensual (decision de Direccion 2026-11-01).** Ademas del tope por corrida, `canal_flags.max_envios_por_mes` (nuevo, `integer NOT NULL DEFAULT 500`): antes de encolar se cuenta `SELECT count(*) FROM wa_envios_log WHERE canal='whatsapp' AND estado IN ('enviado','pendiente') AND created_at >= date_trunc('month', now())`; si `count + encolados_en_esta_corrida >= max_envios_por_mes`, la funcion **corta** y devuelve `skipped='techo_mensual'`. Al 80% del techo se emite `RAISE WARNING` con el conteo (visible en `cron.job_run_details`), y el panel lo pinta en ambar. Un techo que solo se descubre al agotarse es un incidente; al 80% es una notificacion.
9. **Llamada:** `pg_net.http_post(url := <EDGE_URL_WA>, headers := jsonb_build_object('Content-Type','application/json','X-Service-Token', <SERVICE_SHARED_TOKEN>), body := ..., timeout_milliseconds := 10000)`. El token se lee de Vault/`app.settings`, **nunca** de una tabla ni de un literal (patron ADR-076). Se ejecuta **solo** si `dry_run` efectivo es `false` y el techo mensual lo permite; tras el POST se hace `UPDATE ... SET pg_net_request_id = v_req, intentos = intentos + 1` y **nada mas**: `wa_message_id` no lo escribe esta funcion (§3.8).
10. **Retorno:** `{"dry_run":bool,"persistido":bool,"reglas":n,"candidatos":n,"encolados":n,"omitidos":n,"omitidos_por_motivo":{...},"errores":n,"skipped":null|motivo}`.
11. **`p_persistir_dry_run boolean DEFAULT false` (nuevo, A3).** Con `p_dry_run = true`:
    - `p_persistir_dry_run = false` (default, es el modo de **F3** manual): **0 filas**, y el jsonb de retorno trae `muestra` con los 5 primeros payloads renderizados y `omitidos_por_motivo` completo. Sirve para inspeccionar, no para operar.
    - `p_persistir_dry_run = true` (modo **programado**): escribe una fila por candidato con `estado='omitido'`, `omitido_motivo='dry_run'` y **no** llama a `pg_net`. Sin esto, el dry-run bajo `pg_cron` pierde el jsonb (nadie lo lee) y no queda ni un conteo de omitidos: el ADR prometeria observabilidad y no la tendria.
12. **Sin `SECURITY INVOKER` accidental:** la funcion es `SECURITY DEFINER` porque escribe en tablas con RLS sin politicas para `service_role`-only, pero **no** debe poder invocarse desde `anon` (punto 1). El `SET search_path = public, pg_temp` es obligatorio y va en la firma, no en el cuerpo.

**Dry-run escribe 0 filas.** No inserta en `wa_envios_log`: si lo hiciera, la traza dejaria de ser prueba de un envio real y ademas envenenaria la idempotencia (un dry-run impediria el envio real del mismo tipo). Devuelve en cambio `muestra` con los 5 primeros payloads renderizados para inspeccion.

**[REV-089] Matiz aprobado (decision de Direccion 2026-11-01, A3).** La regla anterior se mantiene como **default** (`p_persistir_dry_run = false`) y se admite la excepcion del punto 11: en operacion programada el dry-run **puede** persistir filas, porque un dry-run sin traza no se puede auditar. El riesgo de envenenamiento que la regla original queria evitar **se evita en el esquema, no en la funcion**: el indice unico `wa_envios_log_idem_uq` (§3.3) es **parcial** y excluye `omitido_motivo='dry_run'`, asi que una fila de dry-run no ocupa la clave y el envio real posterior del mismo `(evento, inscrito, tipo)` sigue siendo posible. Consecuencia a vigilar en el panel: `wa_envios_log` mezcla observacion y envio, por eso **toda consulta de costo o de tasa de error debe filtrar `omitido_motivo IS DISTINCT FROM 'dry_run'`**; se documenta en §7.2.

### 3.8 `fn_wa_reconciliar_respuestas()` (nuevo, cierra B1)

`pg_net` es **asincrono**: `net.http_post` encola y devuelve un `request_id`; la respuesta del Edge Function llega despues a `net._http_response`. Por eso el RPC de §3.7 **no puede** saber si Meta acepto el mensaje, y este ADR no puede prometer `wa_message_id` en la misma transaccion. Es el mismo limite que `adr076` declaro explicitamente (`adr076:202-205`, `:1026-1030`) y que aqui se resuelve en vez de heredarse.

```sql
CREATE OR REPLACE FUNCTION public.fn_wa_reconciliar_respuestas()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
```

Contrato:

1. **Unico escritor de la verdad del envio.** Solo esta funcion escribe `wa_message_id`, `error_code`, `error_texto`, `enviado_at` y el `intentos` de abandono. El RPC de §3.7 escribe `pg_net_request_id` y el `intentos` de encolado. Prohibido que dos sitios escriban las mismas columnas: es el patron que rompio el correo (dos renderizadores, uno sin fixtures) aplicado a la traza.
2. **Lectura:** por cada fila de `wa_envios_log` con `estado IN ('pendiente','enviado')` y `pg_net_request_id IS NOT NULL`, se hace `JOIN net._http_response r ON r.id = w.pg_net_request_id`. `net._http_response` **se purga**: la reconciliacion corre en **cada** corrida horaria y no asume retencion larga. Si la respuesta ya no esta y `intentos >= 3`, la fila pasa a `estado='error'`, `error_texto='sin_respuesta_pg_net'`.
3. **Mapeo:** `status 200/201/202` con `body.dryRun = true` -> `estado='omitido'`, `omitido_motivo='dry_run'` (cierra el hueco de B2: el cinturon del Edge degrada la fila, no la deja como enviada). `2xx` con `body.messageId` -> `estado='enviado'`, `wa_message_id = body.messageId`, `enviado_at = now()`. `4xx/5xx` -> se aplica la tabla de §4.4 por `body.error.code`.
4. **Abandono:** `intentos` se incrementa en cada intento de envio y en cada reconciliacion fallida; con `intentos >= 3` y sin exito, `estado='error'` permanente y alerta. `estado='error'` **no** se reintenta automaticamente: la clave idempotente ya existe y el reenvio es una accion manual explicita con sufijo `#rN` (§3.3).
5. **Entrega real no es su responsabilidad.** `estado='enviado'` significa **encolado y aceptado** (paridad con `email_envios_log`, `adr076:202-205`; se documenta aqui para que nadie lea "enviado" como "entregado"). `delivered`/`read`/`failed` llegan por el webhook de estados de Meta en F6 y se guardan en columnas aparte (`entrega_estado`, `entrega_at`), **sin sobrescribir** `estado`.
6. **Permisos:** `REVOKE ALL ... FROM PUBLIC, anon, authenticated`, `GRANT EXECUTE ... TO service_role`. La invoca el mismo job del cron de WhatsApp, en la misma corrida y **antes** de encolar nuevos (reconciliar lo viejo, luego enviar lo nuevo).
7. **Retorno:** `{"reconciliadas":n,"enviados":n,"omitidos_dry_run":n,"errores":n,"sin_respuesta":n}`.

---

## 4. Transporte: contrato de la Edge Function `send-wa-recordatorio`

Nueva funcion en `supabase/functions/send-wa-recordatorio/index.ts`. **No** es un endpoint de `api/*.js`: no consume el presupuesto 8/8 de Vercel.

### 4.1 Payload (RPC -> Edge Function)

```json
{
  "idempotencyKey": "whatsapp:evt_123:ins_456:anticipacion",
  "to": "+573001234567",
  "template": {
    "name": "recordatorio_anticipacion_56h",
    "language": "es_CO",
    "components": [
      { "type": "body",
        "parameters": [
          { "type": "text", "text": "Ana" },
          { "type": "text", "text": "Vinilos Inversos" },
          { "type": "text", "text": "20 de noviembre, 8:00 p.m." },
          { "type": "text", "text": "Klandestino, Kr 4 # 19-56" },
          { "type": "text", "text": "https://taquilladirecta.com/evento.html?slug=vinilos-inversos-c8yu" }
        ] }
    ]
  },
  "meta": { "eventoId": "evt_123", "inscritoId": "ins_456", "tipo": "anticipacion" }
}
```

Regla dura: **el body de la plantilla se arma en la Edge Function a partir de `wa_plantillas.variables`**, no en SQL ni en el admin. Un solo lugar renderiza; el admin solo **previsualiza** con la misma funcion de render expuesta como `preview` (si el preview se implementa aparte, se duplica la logica y se repite el patron que rompio el correo: dos renderizadores, uno de ellos sin fixtures).

### 4.2 Auth dual (reutiliza `SERVICE_SHARED_TOKEN`)

- Canal de base de datos: header `X-Service-Token`, comparacion **en tiempo casi constante** (mismo algoritmo que `send-ticket-email/index.ts:142`).
- Canal humano (pruebas / reenvio manual con sesion): `Authorization: Bearer <JWT>` validado contra Supabase Auth.
- **No se crea un secreto nuevo.** Se reutiliza `SERVICE_SHARED_TOKEN` porque el emisor es el mismo backend y rotar dos secretos duplica el riesgo operativo. El token nunca se escribe en la traza, ni en `error_texto`, ni en el jsonb de respuesta.

### 4.3 Tiempos y reintentos

| Parametro | Valor | Motivo |
|---|---|---|
| `fetch` a `graph.facebook.com` | `AbortController`, 8000 ms | Menor que el timeout de `pg_net` (10000 ms) para que el error llegue como respuesta y no como request huerfano |
| Reintento interno | 1 reintento, backoff 500 ms + jitter | Mas reintentos exceden `pg_net`; el reintento de verdad lo hace la **siguiente corrida horaria** via `intentos` |
| `pg_net.timeout_milliseconds` | 10000 | margen sobre el fetch |
| `intentos` maximo (RPC) | 3 | Despues pasa a `estado='error'` permanente y alerta |

### 4.4 Mapeo de errores de Meta

| Codigo | Significado | Accion | Reintento |
|---|---|---|---|
| 131026 | Numero no entregable / no es WhatsApp | `estado='omitido'`, `omitido_motivo='numero_no_whatsapp'` | **NO** (nunca) |
| 132000 | Cantidad de parametros no coincide con la plantilla | `estado='error'`, alerta de configuracion | NO |
| 132001 | Plantilla no existe / idioma no disponible | `estado='error'`, alerta de configuracion | NO |
| 131047 | Re-engagement requerido (ventana de 24 h) | `estado='error'`. **Con plantilla UTILITY aprobada esto NO aplica**: si aparece, se envio texto libre por error | NO (es bug de codigo) |
| 130429 / 429 | Throughput o rate limit | `estado='pendiente'`, `intentos+1`, backoff 5s/30s/120s | SI (<=3) |
| 131056 | Rate limit por par (numero, destinatario) | igual que 429 | SI (<=3) |
| 190 | Token invalido o expirado | `estado='error'` + **kill-switch de emergencia** (`canal_flags.activo=false`) | NO |
| 5xx / timeout de red | Fallo transitorio | `estado='pendiente'`, `intentos+1` | SI (<=3) |

Regla: **solo se reintenta lo transitorio.** Reintentar un numero invalido o una plantilla mal formada quema cuota, sube el error rate de la WABA y nunca va a funcionar.

**[REV-089] Quien aplica esta tabla (corrige B1).** Originalmente la tabla se leia como si el RPC de §3.7 la aplicara en caliente. **No puede**: `pg_net` es asincrono y la respuesta de Meta llega a `net._http_response` despues de que el RPC termino. La aplica **`fn_wa_reconciliar_respuestas()` (§3.8)**, que es el unico escritor de `error_code`, `intentos` de abandono y `wa_message_id`. El RPC solo encola y, como mucho, detecta el fallo **sincrono** de `net.http_post` (que es un fallo de encolado, no de Meta: `error_texto='pg_net_no_disponible'` o `'pg_net_encolado_fallo'`).

Dos precisiones de la tabla revisadas:

- **429/131056 no pueden esperar 5s/30s/120s dentro de un RPC.** El "backoff" real es la corrida siguiente (horaria) con `intentos+1`; el backoff corto vive **solo** dentro de la Edge Function (§4.3, 1 reintento). Se acepta que la espera efectiva sea de hasta 1 h: es un recordatorio de evento, no un OTP.
- **`190` (token invalido) es el unico codigo que no debe esperar a la reconciliacion** para apagar el canal: el reconciliador, al verlo, hace `UPDATE canal_flags SET activo=false, motivo='error 190 token'` en la misma transaccion. Un token vencido que sigue encolando mensajes es una fuga silenciosa de cuota.

---

## 5. Normalizacion E.164 (Colombia +57)

Helper SQL unico compartido:

```sql
public.fn_wa_e164_co(p_raw text) RETURNS text   -- IMMUTABLE
```

Reglas, en orden:

1. `NULL`/vacio -> `NULL`.
2. Quitar todo lo que no sea digito ni `+`.
3. Si empieza con `+` y tiene 8 a 15 digitos -> E.164 valido, se devuelve normalizado.
4. Si tiene 12 digitos y empieza con `57` -> `+57` + los 10 restantes.
5. Si tiene 10 digitos y empieza con `3` -> `+57` + los 10.
6. Si tiene 10 digitos y **no** empieza con `3` (fijo colombiano) -> `+57` + los 10 (los fijos no reciben WhatsApp; se dejan pasar y Meta los devolvera como `131026`, lo cual **es informacion util** para el panel).
7. Cualquier otra forma -> `NULL`.

**Por que un solo helper y no uno en JS y otro en SQL:** el canal de correo se rompio por tener el mismo dato validado en dos sitios con criterios distintos (`adr076:791` valida `qr_code` como texto y `index.ts:276-280` lo valida como URL http, con resultados opuestos). La normalizacion del telefono sufre del mismo riesgo: el admin previsualiza y la RPC envia; si difieren, el preview miente.

Numeros invalidos: `estado='omitido'`, `omitido_motivo='telefono_invalido'`, **sin reintento**. El panel los cuenta aparte y los ofrece para correccion manual. La tasa de omision se mide **antes** de la Fase 4: si mas del 20% de los inscritos tiene telefono invalido, el canal no esta listo aunque el codigo funcione.

---

## 6. Politica de opt-in diferido (D5)

**Donde se guarda:** en `inscritos` (el consentimiento se ata al acto de inscripcion, que es cuando se muestra el checkbox):

```sql
ALTER TABLE public.inscritos
    ADD COLUMN IF NOT EXISTS wa_optin         boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS wa_optin_at      timestamptz,
    ADD COLUMN IF NOT EXISTS wa_optin_origen  text,      -- landing | admin | import
    ADD COLUMN IF NOT EXISTS wa_optin_texto   text;      -- version literal del aviso mostrado
```

**Por que en `inscritos` y no en una tabla de consentimientos:** cada inscripcion es una evidencia separada (misma persona, 3 eventos -> 3 consentimientos con fecha propia). Una tabla aparte seria mas correcta a largo plazo, pero introduce una FK y un JOIN en el camino caliente del envio sin beneficio hoy. Queda como deuda declarada.

**Envio con bloqueo diferido:** en las fases 2-5 la RPC **no** filtra por `wa_optin`; solo copia el valor en `wa_envios_log.optin_observado`. El bloqueo se activa cuando se cumpla **todo** esto:

1. Al menos 2 eventos con envio real completado;
2. cobertura de opt-in >= 90% de los inscritos de esos eventos;
3. tasa de bloqueo/reporte observada < 2% (via webhook de estados, Fase 6);
4. `canal_flags.requiere_optin = true` (un solo UPDATE, sin redesplegar).

**Riesgos explicitos de enviar sin bloqueo:**

- **Calidad del numero:** Meta mide block/report por plantilla y por WABA. Un pico baja el `quality_rating` y con el caen los limites de mensajeria.
- **Restriccion de la WABA:** reincidencia puede derivar en `messaging_limit` reducido (de 1.000 a 100 destinatarios/dia) o en limitacion de la cuenta. Recuperar eso es un tramite con Meta, no un fix de codigo.
- **Legal:** en Colombia la Ley 1581 de 2012 exige autorizacion previa y expresa para comunicaciones por canales electronicos. Enviar sin opt-in es riesgo de sancion (SIC), no solo de deliverability. **Este ADR no sustituye la revision legal**: la captura del checkbox y su texto deben validarse con Direccion antes de la Fase 4.
- **Mitigacion temprana:** arrancar con `max_envios_por_corrida` bajo (10) y solo inscritos del evento mas reciente, para que cualquier incidente sea pequeno y reversible.

**[REV-089] Texto baseline del opt-in (decision de Direccion 2026-11-01).** Se adopta este texto como base para el checkbox de registro, con los cuatro elementos que la Ley 1581/2012 exige: autorizacion **previa**, **expresa**, **informada** y **revocable**. El checkbox nace **desmarcado** (un opt-in premarcado no es consentimiento) y su texto literal se guarda en `inscritos.wa_optin_texto`:

> Autorizo de manera previa, expresa e informada a Taquilla Directa para tratar mis datos personales (nombre, cedula, correo electronico y numero de telefono) con la finalidad **exclusiva** de enviarme notificaciones e informacion operativa del evento al que me inscribo, por correo electronico y por WhatsApp. Entiendo que esta autorizacion es **revocable** en cualquier momento escribiendo a [canal de atencion], y que su revocatoria no afecta los envios ya realizados. Conozco la Politica de Tratamiento de Datos Personales disponible en [URL].

Condiciones de implementacion, verificables:

1. **Un checkbox, un texto, dos canales:** el mismo texto ampara correo y WhatsApp (la finalidad es la misma). Si despues se quiere granularidad por canal, se necesitan dos columnas, no dos interpretaciones del mismo texto.
2. **`wa_optin_texto` guarda la version literal mostrada**, no una clave: si el texto cambia, la evidencia vieja debe seguir siendo la que el usuario acepto. Sin esto, la "autorizacion" no es demostrable.
3. **`wa_optin_origen`** (`landing` | `admin` | `import`) distingue el consentimiento capturado del consentimiento importado. Un opt-in cargado por un operador desde `admin.html` **no** es autorizacion del titular y no debe contar para la cobertura del 90% de §6.
4. **Sin bloqueo de envio por ahora** (D5 se mantiene diferido): el baseline legal se captura desde F1, se mide en `optin_observado` y el bloqueo se activa cuando se cumplan las 4 condiciones ya listadas. Capturar la evidencia antes de necesitarla es lo que permite activar el bloqueo sin una migracion de datos despues.
5. **El texto y la URL de la politica son datos, no codigo:** viven en el formulario y en la tabla, no hardcodeados en tres sitios. La validacion final con Direccion (y con asesoria legal si la hay) queda como riesgo abierto 7 de §10.2.

---

## 7. Kill-switch y observabilidad

### 7.1 Detener el canal sin redesplegar (3 niveles, el mas restrictivo gana)

| Nivel | Mecanismo | Efecto | Latencia |
|---|---|---|---|
| 1 | `UPDATE canal_flags SET activo=false WHERE canal='whatsapp'` | La RPC no hace nada, devuelve `skipped` | inmediata (siguiente corrida) |
| 2 | `UPDATE recordatorio_reglas SET activo=false` (por regla o por evento) | Se apaga un tipo o un evento puntual | inmediata |
| 3 | `WA_DRY_RUN=1` (secret de la Edge Function) | Aunque la BD diga enviar, no sale nada a Meta | requiere redeploy de la funcion (minutos) |

Nivel 1 es el interruptor de emergencia normal: es **datos**, no codigo, y no necesita ni migracion ni despliegue. Nivel 3 existe como **cinturon** de la fase de construccion, no como operacion diaria.

Fail-safe declarado: el flag de BD **solo puede restringir, nunca ampliar**. Si `WA_DRY_RUN=1` en el entorno, una fila con `dry_run=false` **no** habilita envio real.

**[REV-089] El fail-safe ahora es verificable, no declarativo (cierra el hueco de B2).** La version original de esta seccion era una intencion: el SQL no ve `WA_DRY_RUN`, de modo que una fila con `dry_run=false` **si** hacia llegar el payload al Edge y el cinturon actuaba *despues*, dejando la fila marcada como `enviado` sin `wa_message_id` y consumiendo la clave idempotente. La regla queda asi, con tres comprobaciones medibles:

1. **Restriccion efectiva en SQL:** `canal_flags.dry_run = true` -> la RPC **no** llama a `pg_net` (ni siquiera encola). Es lo unico que garantiza "el flag de BD no amplia el entorno".
2. **Restriccion efectiva en el Edge:** `WA_DRY_RUN=1` -> el Edge responde `202` con `{dryRun:true, messageId:null}` y **no** invoca `graph.facebook.com`.
3. **Ninguna combinacion produce un falso positivo:** la fila solo llega a `estado='enviado'` por el reconciliador (§3.8) y solo si trae `wa_message_id` no nulo. Con `dryRun:true` la fila queda `omitido/dry_run`.
4. **Kill-switch de emergencia automatico:** el codigo `190` apaga `canal_flags.activo` en la misma transaccion (§4.4). Un kill-switch que exige que un humano se entere no es un kill-switch.
5. **Orden de encendido obligatorio:** `activo=true` **solo** despues de F4 verde con numero real verificado; `dry_run=false` **solo** despues de F4 verde y con el techo mensual cargado. Nunca en el mismo `UPDATE` que la primera migracion.

### 7.2 Que se monitorea

| Metrica | Fuente | Umbral de alerta |
|---|---|---|
| Enviados / omitidos / error por dia | `wa_envios_log` agrupado por `estado`, `omitido_motivo` | error > 5% en 1 h -> apagar canal |
| Error por codigo | `wa_envios_log.error_code` | 131026 > 2% -> problema de datos; 132001 > 0 -> plantilla desalineada |
| Entregas reales | webhook de estados de Meta (`delivered`, `read`, `failed`) | Fase 6; hasta entonces solo `202` + `wa_message_id` |
| Costo estimado | `count(enviados) * canal_flags.costo_unitario_usd` | > presupuesto mensual acordado |
| Cobertura de opt-in | `avg(optin_observado::int)` | < 90% bloquea la activacion del bloqueo (D5) |
| Consumo del techo mensual | `count(*)` del mes / `canal_flags.max_envios_por_mes` | >= 80% -> aviso; 100% -> `skipped='techo_mensual'` |

Vista de apoyo: `public.v_wa_resumen_diario` (`dia`, `tipo`, `estado`, `n`, `costo_estimado`). El costo unitario lo carga operaciones en `canal_flags`: este ADR **no inventa** la tarifa de Meta, que cambia por pais y por categoria.

**[REV-089] Dos correcciones de medicion:**

1. **Toda consulta de §7.2 filtra `omitido_motivo IS DISTINCT FROM 'dry_run'`.** Si el dry-run programado persiste filas (§3.7.11), sin el filtro el panel reportaria "enviados" que nunca salieron y el costo estimado se inflaria, que es la forma mas rapida de que nadie vuelva a creerle al tablero. La vista `v_wa_resumen_diario` debe exponer `n_real` y `n_dry_run` por separado, no sumados.
2. **"Entregas reales" no puede depender del `202` sincrono:** `pg_net` es asincrono y el `202` llega a `net._http_response`. Hasta F6 la evidencia es `wa_message_id` **poblado por el reconciliador**, no el retorno del RPC. Un `wa_message_id` vacio con `estado='enviado'` es una inconsistencia que la vista debe delatar (y que el reconciliador impide).
3. **Tarifa utility de Colombia: dato pendiente de consulta antes de produccion** (decision de Direccion 2026-11-01). Mientras `costo_unitario_usd IS NULL`, el panel muestra `costo_estimado = NULL` con el rotulo "tarifa sin cargar"; **no** se usa 0 como sustituto, porque un costo cero silencioso es peor que un costo desconocido visible.

---

## 8. UI: sub-tab "Recordatorios" en `admin.html`

Se anade un sub-tab dentro del editor de evento (no un modulo nuevo de navegacion, ADR-022/023):

1. **Toggle por evento y por canal** (`email`, `whatsapp`), leyendo y escribiendo `recordatorio_reglas` (override) y mostrando la **regla efectiva** resuelta.
2. **Tres offsets editables:** anticipacion (default 56), dia_evento (default 0, fijo por CHECK), post-evento (default -24). Validacion en cliente **y** en el CHECK: el cliente nunca es la unica barrera.
3. **Selector de plantilla** con `preview`: el preview sustituye `{{1}}..{{n}}` con datos reales del evento y del primer inscrito, y avisa en rojo si `estado_meta <> 'aprobada'` o si el numero de `variables` no coincide con los parametros del body.
4. **Log unificado** (correo + WhatsApp) con columnas: fecha, destinatario, canal, tipo, estado, motivo, codigo de error, intentos. Filtros por evento y estado. Boton "reenviar" -> RPC con clave `#rN`.
5. **Interruptor global de canal** visible en la cabecera del sub-tab, con confirmacion: apaga `canal_flags.activo`.
6. **Cero Borrado:** el sub-tab es **aditivo**. No se elimina ningun ID, no se toca el contrato v112 y no se agrega `display:none` sobre elementos existentes (se usa el mecanismo de tabs ya existente).
7. **Seguridad:** RLS fail-closed en las 4 tablas nuevas (`recordatorio_reglas`, `wa_plantillas`, `wa_envios_log`, `canal_flags`): sin politicas para `anon`; `SELECT/INSERT/UPDATE` solo para `authenticated` con el patron de admin ya vigente; `wa_envios_log` es **append** para el admin (sin `DELETE`). La RPC de envio queda solo para `service_role`.
8. **Presupuesto:** 0 endpoints nuevos. El admin habla PostgREST directo, como el resto del panel.

---

## 9. Plan por fases con criterios de aceptacion verificables

| Fase | Entregable | Criterio de aceptacion (verificable, no opinable) |
|---|---|---|
| F0 | Este ADR | Aprobado por @architect-review con la nota de numeracion aceptada (089). **CERRADO 2026-11-01: ACEPTADO.** |
| F1 | `migrations/adr089_recordatorios_multicanal.sql` (DDL + backfill + `fn_wa_e164_co` + `fn_horas_recordatorio` extendida + `fn_wa_reconciliar_respuestas`) | (1) Ejecutable **2 veces seguidas** sin error ni `WARNING` de objeto preexistente inesperado; (2) backfill = filas de `config_recordatorios` (1 global + N) y la **segunda corrida inserta 0** (`IS NOT DISTINCT FROM`); (3) `INSERT` duplicado de regla -> `23505`; (4) `fn_horas_recordatorio(X)` con 1 argumento devuelve **exactamente** lo mismo que antes de la migracion (regresion 0, medido con `SELECT` antes/despues sobre los 13 eventos); (5) `pg_get_functiondef('public.fn_horas_recordatorio(text)'::regprocedure)` **delega** en la de 3 argumentos y no conserva el `COALESCE` legado (§3.6); (6) `to_regprocedure('public.fn_horas_recordatorio(text,text,text)')` no nulo; (7) `canal_flags` nace con `activo=false, dry_run=true, max_envios_por_mes=500` y **sin** fila para `sms` ni `email`; (8) `\d public.wa_envios_log` muestra el indice **parcial** `wa_envios_log_idem_uq` (no un `UNIQUE` de columna); (9) `wa_plantillas` se crea **antes** que `recordatorio_reglas` (orden del archivo, verificable por numero de linea). |
| F2 | `supabase/functions/send-wa-recordatorio` con `WA_DRY_RUN=1` | **7 casos de contrato PASS** (no 6, se anade el dry-run del cinturon): (a) payload valido en dry-run; (b) telefono invalido; (c) plantilla inexistente; (d) token incorrecto -> `401`; (e) sin `X-Service-Token` ni JWT -> `401`; (f) timeout de Meta simulado -> `504`/error controlado, no `200`; (g) `WA_DRY_RUN=1` explicito -> `202 {dryRun:true, messageId:null}`. En todos: **0 llamadas** a `graph.facebook.com` mientras `WA_DRY_RUN=1` (verificado con el log de salida de la funcion, no con "no lanzo excepcion"). Ademas: el token **no** aparece en el body, ni en el log, ni en `error_texto` (grep del string del secreto sobre la salida). |
| F3 | `fn_enviar_recordatorios_wa_pendientes()` en dry-run | **Dos modos, los dos medibles:** (1) `p_dry_run=true, p_persistir_dry_run=false` -> **0 filas** en `wa_envios_log`, **0 filas nuevas** en `net._http_response`, `candidatos > 0` con un evento real en ventana, `muestra` con 5 payloads y el telefono en E.164 y el slug resuelto; (2) `p_dry_run=true, p_persistir_dry_run=true` -> **N filas** `estado='omitido', omitido_motivo='dry_run'`, `pg_net_request_id` **NULL** en todas, y **0 filas** en `net._http_response`; (3) **prueba de no-envenenamiento:** despues del modo 2, un `INSERT` con la **misma** `idempotency_key` y `estado='pendiente'` **debe pasar** (no `23505`) -> el indice parcial excluye el dry-run; (4) **prueba de lock:** dos ejecuciones concurrentes -> la segunda devuelve `skipped='en_curso'` (§3.7.7); (5) **prueba de techo:** con `max_envios_por_mes=1` y 2 candidatos, la corrida corta en el segundo con `skipped='techo_mensual'`. |
| F4 | **Smoke obligatorio con 1 numero verificado en sandbox** | Envio real a un numero de la lista de prueba de Meta, con **datos reales de un evento real** (no fixtures sinteticos): `estado='enviado'`, `wa_message_id` no nulo, plantilla renderizada con las 5 variables correctas, link `.../<slug>` abre el evento, y la entrega se ve en la consola de Meta. **Sin este paso el canal no existe**, aunque F1-F3 esten verdes (leccion H1) |
| F5 | Cron `recordatorios-wa` (`10 * * * *`) + corte del email | Dos corridas seguidas no duplican envios (misma `idempotency_key` -> 1 sola fila y 1 solo `wa_message_id`); tras el corte, el correo sigue enviando por reglas con la misma traza que antes |
| F6 | Log unificado + webhook de estados (opcional) | El panel muestra correo y WhatsApp en una tabla; el webhook actualiza `entregado/leido` sin sobrescribir `estado='enviado'` |

**[REV-089] F4 no se cierra con el retorno del RPC (corrige B1 y refuerza la leccion de H1).** `pg_net` es asincrono: en el instante en que la RPC devuelve, `wa_message_id` **todavia no existe** y `estado` dice "encolado". El criterio de F4 se verifica en **dos observaciones separadas**, y las dos son obligatorias:

1. **Inmediatamente despues de la corrida:** `SELECT estado, pg_net_request_id FROM wa_envios_log WHERE idempotency_key = '<key>'` -> `estado='enviado'` y `pg_net_request_id` no nulo. Si aqui ya aparece `wa_message_id`, es sospechoso (nadie lo escribio todavia).
2. **Despues de `fn_wa_reconciliar_respuestas()`** (o de la siguiente corrida horaria): `wa_message_id` no nulo, `error_code` nulo, `enviado_at` no nulo. **Este es el criterio que vale.** Un smoke que solo mira que "la funcion no lanzo excepcion" es exactamente lo que dejo pasar el bug H1 durante un ciclo entero.
3. **Numero verificado obligatorio:** el destinatario debe estar en la lista de numeros de prueba de la WABA y ser accesible por una persona que confirme visualmente la recepcion (captura del mensaje). Un numero inventado en sandbox valida el codigo, no el canal.
4. **Un solo destinatario, un solo tipo (`anticipacion`)** en el smoke. Los otros dos tipos se validan despues, uno por corrida; un smoke con 3 tipos y 3 numeros no distingue que fallo.

Cada fase cierra con Escudo GOLD (`node --check`, ASCII, balance de divs) cuando toque `api/*.js`, `admin.html` o el motor, y con `scripts/usage_report.js` en el cierre de sesion.
| F5 | Cron `recordatorios-wa` (`10 * * * *`) + corte del email | Dos corridas seguidas no duplican envios (misma `idempotency_key` -> 1 sola fila y 1 solo `wa_message_id`); tras el corte, el correo sigue enviando por reglas con la misma traza que antes |
| F6 | Log unificado + webhook de estados (opcional) | El panel muestra correo y WhatsApp en una tabla; el webhook actualiza `entregado/leido` sin sobrescribir `estado='enviado'` |

Cada fase cierra con Escudo GOLD (`node --check`, ASCII, balance de divs) cuando toque `api/*.js`, `admin.html` o el motor, y con `scripts/usage_report.js` en el cierre de sesion.

---

## 10. Riesgos y alternativas descartadas

### 10.1 Alternativas descartadas

| Alternativa | Motivo del descarte |
|---|---|
| **Twilio (u otro BSP)** | Decision de Direccion: Meta Cloud API directo. Ademas anade un intermediario y un costo por mensaje sobre el de Meta, y un segundo contrato de plantillas que hay que mantener sincronizado con el de Meta. |
| **Solo deep links `wa.me`** (lo que hay hoy, 27 usos) | No es automatizable: exige que un humano pulse enviar, no hay traza, no hay idempotencia, no hay opt-in verificable y no escala a 3 tipos x N eventos. Sirve para el envio manual puntual y se conserva como fallback. |
| **Automatizacion de WhatsApp Web** (Puppeteer/Selenium) | Viola los terminos de uso, no tiene API estable, el numero se banea de forma irreversible y exige un runtime con navegador (imposible en Vercel Hobby y en Supabase Edge). Riesgo de perder el unico numero emisor (D4). |
| **Reutilizar `api/*.js` de Vercel** | 8/8 funciones agotadas. Ademas un endpoint Vercel no tiene el secreto ni el patron de auth dual ya resuelto en `send-ticket-email`. |
| **Un campo `canal` ampliado en `config_recordatorios`** | Un solo valor de `canal` no expresa 3 tipos x N eventos x 2 canales. Obligaria a una fila por combinacion en una tabla cuyo `evento_id` es UNIQUE: imposible sin romper el esquema vigente. |
| **Relajar el `CHECK (canal IN ('email'))` de `adr074:129`** | Toca el camino que hoy funciona y deja un canal declarado sin consumidor (el propio ADR-074 advirtio de no crear filas con un canal que nadie procesa). Se resuelve con tabla nueva. |
| **Texto libre en lugar de plantillas** | Fuera de la ventana de 24 h Meta lo rechaza (`131047`) y no hay aprobacion previa del contenido: mas riesgo de sancion y de calidad. |

### 10.2 Riesgos abiertos

1. **Aprovisionamiento de Meta es el camino critico:** verificacion de negocio, nombre visible, numero, token permanente de System User y aprobacion de plantilla (24-48 h, puede ser rechazada). El codigo puede estar listo y el canal no existir. Por eso `WA_DRY_RUN=1` es la linea base, no una fase opcional.
2. **Calidad del dato de telefono:** puede hundir la utilidad real del canal. Se mide antes de F4.
3. **Doble fuente de verdad** durante la convivencia (seccion 3.5).
4. **`dia_evento` con offset 0:** el aviso llega a la hora de inicio, con `p_margen_minutos=120` podria salir hasta 2 h antes o 2 h despues. Recomendacion del arquitecto: margen de 30 min para ese tipo. **Es calibracion, no reapertura de D2.**
5. **Costo por mensaje utility** definido por Meta por pais: no se puede presupuestar sin la tarifa vigente de Colombia.
6. **Webhook de estados:** sin el, la "entrega" solo se conoce por el `202` sincrono. La traza dira "enviado", no "entregado".

**[REV-089] Cierre de los riesgos 1-6 con las decisiones de Direccion del 2026-11-01.** Se conservan los seis enunciados originales (Cero Borrado: el riesgo documentado no se borra aunque se mitigue) y se agrega el estado de cada uno:

| # | Estado 2026-11-01 | Resolucion / residual |
|---|---|---|
| 1 | **ABIERTO (operativo, no tecnico)** | El aprovisionamiento de Meta no depende del repo. Mitigacion ya adoptada: `WA_DRY_RUN=1` como linea base y `activo=false` de nacimiento. Nada de F1-F3 lo desbloquea; F4 si. |
| 2 | **ABIERTO hasta medir** | Medible en F3 con datos reales: `%` de inscritos con `fn_wa_e164_co` no nulo. Umbral ya fijado: > 20% invalido -> el canal no esta listo aunque el codigo funcione (§5). |
| 3 | **CERRADO como riesgo de diseno** | §3.5 paso a fuente unica por canal hasta F5: ya no hay dos escritores en ningun momento. Residual: la migracion de corte de F5 debe ser atomica (§3.5 paso 3). |
| 4 | **CERRADO** | Margen de `dia_evento` = **120 minutos** (decision de Direccion 2026-11-01), igual que el resto. Se acepta explicitamente el efecto: el aviso puede salir hasta 2 h antes o 2 h despues del inicio. Descartado el margen de 30 min que este ADR recomendaba: con cron horario son 4 corridas dentro de la ventana en vez de 1, y el `used` se evalua al enviar. |
| 5 | **ABIERTO (dato externo)** | Tarifa utility de Colombia **a consultar antes de produccion** (decision de Direccion 2026-11-01). Mientras sea `NULL`, el panel muestra "tarifa sin cargar" y **no** asume 0. |
| 6 | **CERRADO parcialmente / diferido a F6** | La entrega real sigue siendo F6. Lo que si queda cerrado en este ADR es el estado intermedio: `estado='enviado'` = **encolado** (paridad con `email_envios_log`, `adr076:202-205`) y el reconciliador (§3.8) es quien puebla `wa_message_id`. Nadie debe leer "enviado" como "entregado". |

**Riesgos nuevos declarados por la revision (7-11):**

7. **Texto legal del opt-in:** el baseline de §6 esta redactado, pero **no** validado por asesoria legal. Bloquea F4 (no el codigo, la captura real). Requiere que Direccion confirme el canal de atencion y la URL de la politica.
8. **Techo mensual 500 no calibrado:** es un valor de arranque (decision de Direccion 2026-11-01), no un calculo de demanda. Con 13 eventos y `max_envios_por_mes=500` el canal puede cortar a mitad de mes en un pico; se vigila con la alerta del 80% (§7.2) y se ajusta con un `UPDATE`, sin migracion.
9. **`net._http_response` se purga:** si el reconciliador no corre (job caido) las respuestas se pierden y la traza queda con `estado='enviado'` sin `wa_message_id`. Mitigacion: el reconciliador corre en **cada** corrida y la vista delata `enviado` sin wamid (§7.2).
10. **Costo del dry-run persistido en la tabla:** si se deja `p_persistir_dry_run=true` de forma permanente, `wa_envios_log` crece con filas de observacion. Mitigacion: es un parametro por llamada, la consulta de costo filtra `omitido_motivo <> 'dry_run'`, y la retencion de esas filas se decide en F6.
11. **Dependencia de `pg_net` 0.20.0 para el reconciliador:** `net._http_response` es una tabla interna de la extension, no una API estable. Un cambio de version puede romper el `JOIN`. Mitigacion: el reconciliador se aisla en `fn_wa_reconciliar_respuestas()` y, si la tabla desaparece, la funcion **debe fallar ruidosamente** (no en silencio) para que el cron lo registre.

---

## 11. Consecuencias y deuda declarada

### 11.1 Consecuencias positivas

- WhatsApp y correo comparten **una** abstraccion (regla -> traza -> transporte) con idempotencia y tope por corrida.
- El canal nuevo nace **apagado** (`canal_flags.activo=false`, `dry_run=true`): fail-closed por defecto.
- 0 endpoints nuevos de Vercel; 1 Edge Function nueva en Supabase.
- `omitido_motivo` y `error_code` nacen como columnas: no se repite H3.
- La normalizacion E.164 vive en **un** helper, no en dos lenguajes.

### 11.2 Deuda que este ADR asume

| Deuda | Detalle |
|---|---|
| `WA_DRY_RUN` en `.env.example` | **No existe `.env.example` en el repo** (verificado: 0 archivos). Hay que crearlo con `WA_PHONE_NUMBER_ID`, `WA_BUSINESS_ACCOUNT_ID`, `WA_TOKEN` (placeholder, nunca valor real), `WA_DRY_RUN=1`, `SERVICE_SHARED_TOKEN`, y los de Resend. Sin secretos versionados. |
| `MAIL_FROM` vs `FROM_EMAIL` | Inconsistencia ya resuelta en docs; al escribir `.env.example` hay que usar **el nombre que lee el codigo** (`index.ts`), no el de la documentacion. Verificar antes de escribir el archivo. |
| H3 heredado del correo | El cron de correo cuenta el duplicado idempotente como `enviado` (`B9-smoke-email.md:115`). El canal WA **no** hereda el defecto (usa `ON CONFLICT DO NOTHING` y cuenta `omitidos`), pero el correo sigue con el. **[REV-089]** Tras el rediseno de §3.7.6 ya no es un `DO NOTHING` ciego: al chocar la clave se **lee el estado** y se decide (reintentar si `pendiente` sin `pg_net_request_id`, omitir en cualquier otro caso), de modo que "ya enviado", "en vuelo" y "murio antes de encolar" dejan de ser el mismo caso. El correo sigue con el defecto. |
| Reconciliacion asincrona | **[REV-089]** `wa_message_id`, `error_code` e `intentos` de abandono se pueblan en una pasada posterior (§3.8), no en la misma transaccion del envio. `estado='enviado'` significa **encolado**. Es la deuda que `adr076:202-205` declaro y no pago; aqui se paga para el canal nuevo y **no** para el correo (que sigue sin reconciliador). |
| H4 heredado | `ticketUrl` no se envia desde la RPC (`adr076:1015-1024`): el adjunto PNG es inalcanzable desde el cron. Aplica igual al recordatorio de WhatsApp (el QR va como link, no como imagen: las plantillas de Meta no adjuntan archivos en el body). |
| H5 heredado | Header `X-Origem` (typo) en `adr076:1007`, no leido por la Edge Function ni declarado en CORS. No se replica en `send-wa-recordatorio`. |
| Sin tabla de consentimientos | `wa_optin` vive en `inscritos` (seccion 6). |
| Webhook de estados | Fase 6, fuera de este ADR. |
| Corte del canal email | `fn_enviar_recordatorios_pendientes()` queda como compatibilidad; su retiro es un ADR posterior, no una consecuencia de este. |

---

## 12. Verificacion contra el archivo real (ADR-006)

| Comprobacion | Resultado |
|---|---|
| `recordatorio_reglas`, `wa_plantillas`, `wa_envios_log`, `canal_flags`, `WA_DRY_RUN`, `send-wa-recordatorio` en el repo | **0 coincidencias** (grep global). Nada colisiona, nada existe todavia |
| `config_recordatorios.evento_id` | `text UNIQUE` (`adr074:86`); `canal text NOT NULL DEFAULT 'email'` (`:89`); `CHECK (canal IN ('email'))` (`:129`) |
| Por que dos indices unicos parciales | Precedente identico documentado en `adr074:27-30` (NULL no colisiona en UNIQUE) |
| Columnas espejo del log | `email_envios_log` (`adr076:209-225`): `evento_id, inscrito_id, destinatario, tipo, estado, intentos, idempotency_key UNIQUE, error_texto, created_at, enviado_at, cedula_norm, ip_origen, origen, pg_net_request_id` |
| Firma de la RPC de correo | `adr076:731-745` (13 parametros, `p_bypass_rate_limit` ultimo) |
| `fn_horas_recordatorio` | `adr074:352`, entero positivo, override -> global -> 56 |
| Ventana del cron actual | `adr078`: `now()` comparado contra `evento_inicio - make_interval(hours => fn_horas_recordatorio(e.id))` con margen |
| Auth dual reutilizable | `send-ticket-email/index.ts:40-41` (contrato) y `:142` (comparacion en tiempo casi constante) |
| `inscritos` con telefono | `admin.html:10871` usa `i.whatsapp` y `i.telefono`; `adr030:19` documenta `content.comunidad_whatsapp` (otro campo, no confundir) |
| Presupuesto Vercel | 8/8 agotado: este ADR **no** crea `api/*.js` |
| Numeracion | ADR-079 ocupado (check-in multi-punto, 2026-10-07); ADR-087/088 asignados (`DECISIONS.md:102-103`); 089 libre |

---

## 13. Preguntas que Direccion debe resolver antes de F1

**Estado 2026-11-01: las seis preguntas originales estan RESUELTAS por Direccion.** Se conservan los enunciados (Cero Borrado) con la respuesta cerrada al lado.

1. **`dia_evento` con `used = true`:** se omite el aviso a quien ya hizo check-in (propuesta de este ADR) o se envia igual?
   -> **RESUELTA 2026-11-01: se omite**, y la omision **se registra** con `omitido_motivo='checkin_previo'` (§3.7.4). Ademas, por simetria decidida en la misma fecha: `post_evento` omite a `used=false` con `omitido_motivo='sin_checkin'`. La regla queda escrita en §3.7.4, no en una pregunta abierta.
2. **Margen de `dia_evento`:** 120 min como el resto, o 30 min por ser un aviso "en el momento"?
   -> **RESUELTA 2026-11-01: 120 minutos**, igual que el resto. Razones registradas en §10.2 riesgo 4: con cron horario da 2 corridas de reintento dentro de la ventana y el `used` se evalua al enviar. Se acepta el efecto de que el aviso pueda llegar hasta 2 h antes o 2 h despues del inicio.
3. **Texto del checkbox de opt-in:** quien lo redacta y quien lo valida legalmente (Ley 1581/2012)? Bloquea F4 aunque el bloqueo de envio este diferido.
   -> **RESUELTA parcialmente 2026-11-01: el texto baseline queda redactado en §6** (autorizacion previa, expresa e informada; finalidad = notificaciones del evento; revocable; checkbox desmarcado; literal guardado en `wa_optin_texto`). **Residual abierto:** validacion legal formal y los dos datos que el texto referencia (canal de atencion y URL de la politica). No bloquea F1-F3; **si** bloquea F4 (captura real en el formulario).
4. **Rate de costo utility para Colombia:** se carga en `canal_flags.costo_unitario_usd` o el costo se calcula fuera de la BD?
   -> **RESUELTA 2026-11-01: se carga en `canal_flags.costo_unitario_usd`.** La **tarifa** sigue como dato a consultar antes de produccion (no se inventa). Mientras sea `NULL`, el panel muestra "tarifa sin cargar" y no asume 0 (§7.2).
5. **Presupuesto y techo mensual** de mensajes, para fijar `max_envios_por_corrida` y el umbral de alerta.
   -> **RESUELTA 2026-11-01: techo inicial 500 mensajes/mes**, configurable en `canal_flags.max_envios_por_mes`, con **alerta al 80%** (`alerta_porcentaje`, `RAISE WARNING` + aviso ambar en el panel). `max_envios_por_corrida` se mantiene en 50 con arranque recomendado de 10 durante las primeras corridas reales. Valor de arranque, no calculo de demanda (riesgo 8 de §10.2).
6. **Orden de despliegue:** se apaga el canal de correo antes de encender WhatsApp, o conviven un ciclo completo?
   -> **RESUELTA 2026-11-01: conviven un ciclo completo.** El correo **no se apaga** al encender WhatsApp: §3.5 y la regla de fuente unica por canal lo permiten sin ambiguedad, y §7.1 punto 5 fija el orden de encendido (F4 verde -> `activo=true` -> despues `dry_run=false`). El corte del correo es F5 y su retiro definitivo es un ADR posterior (§11.2).

**Preguntas nuevas que la revision deja abiertas (no bloquean F1):**

7. **Retencion de las filas `omitido_motivo='dry_run'`:** se purgan a los N dias o se conservan como historico de calibracion? Se decide en F6; afecta solo el tamano de `wa_envios_log`.
8. **Canal de atencion y URL de la politica de tratamiento de datos** para el texto de §6 (dato que falta en el repo, verificado: no hay URL de politica en `evento-app.html` ni en `admin.html`).

*ADR-089 ACEPTADO (pendiente de implementacion) por @architect-review el 2026-11-01. Dictamen original: APROBADO CON CONDICIONES; las condiciones B1-B2 y A1-A3 quedaron incorporadas al documento en la revision v1.1. No se ha escrito migracion, Edge Function ni cambio de UI: la implementacion arranca en F1 bajo el gate de AGENTS.md seccion 2 (`@sql-security`).*
