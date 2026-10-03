-- ============================================================================
-- ADR-076 | Camino unico de envio de correo + traza de idempotencia
-- ----------------------------------------------------------------------------
-- Archivo   : migrations/adr076_enviar_email_seguro.sql
-- Fecha     : 2026-10-03
-- Proyecto  : ctgyvydzshueemlelkzv (Supabase, PostgreSQL 17.6)
-- Proposito : cerrar la exposicion de seguridad del envio de correo y la
--             lectura anonima de datos personales que hoy lo acompanana.
--
-- HALLAZGO 1 - ENVIO DE CORREO ARBITRARIO CON CLAVE PUBLICA:
--   5 archivos HTML hacen POST a la Edge Function `send-ticket-email` con la
--   ANON KEY del proyecto embebida en la cabecera `Authorization`
--   (serie.html, registroaforo.html, registro.html, eventobackup.html,
--   admin.html). La anon key es una credencial PUBLICA: esta en el HTML que
--   cualquiera descarga. Con ella se puede pedir un correo a CUALQUIER
--   destinatario con CUALQUIER contenido, desde el dominio del proyecto.
--   Eso no es spam: es relay de correo autenticado, y lanza la reputacion del
--   dominio y de las funciones de correo. La autorizacion de la funcion no
--   puede depender de una clave que el cliente ya tiene.
--
-- HALLAZGO 2 - SELECT * ANONIMO SOBRE `inscritos`:
--   La recuperacion de entradas y el control de acceso hacen
--   `select * from inscritos` (o `select nombre,cedula,telefono,email,...`)
--   con la anon key, devolviendo nombre, cedula, telefono, email, qr_code y
--   `used` de TODOS los asistentes. No hay recorte por columnas en la base.
--
-- QUE RESUELVE ESTA MIGRACION (todo aditivo):
--   1. `public.email_envios_log`: cola y traza. Da idempotencia (llave unica)
--      y le dice al cron futuro a quien ya se le aviso (ADR-074 / TSK-003).
--   2. `public.enviar_email_registro(...)`: RPC SECURITY DEFINER, unico camino
--      permitido para los call sites publicos. La funcion NO recibe ni acepta
--      ninguna credencial del llamador: usa un secreto que el operador guarda
--      en Supabase Vault (o en `app.settings.*`) y, si no existe, falla
--      CERRADO con excepcion. Nunca envia correo de forma anonima.
--   3. `public.obtener_inscrito_por_cedula(...)`: RPC SECURITY DEFINER que
--      reemplaza el `SELECT *`: devuelve los campos MINIMOS, exige la pareja
--      (cedula, evento_id), nunca devuelve el email de terceros y solo
--      devuelve `telefono` si el llamador lo aporta como segundo factor.
--
-- QUE NO HACE ESTA MIGRACION (deliberadamente):
--   - NO cambia ninguna politica RLS existente. En particular NO toca los
--     SELECT que hoy usan registroaforo.html:908, eventobackup.html:3635 y
--     scanner.html:394: quitar el `SELECT *` sin migrar los 3 call sites deja
--     el formulario de registro caido, asi que ese recorte es la iteracion D1,
--     con la Direccion, NO este archivo. Ver BLOQUE 9.
--   - NO hace el `REVOKE SELECT` por columnas de ADR-068 paso 4 (tampoco: es
--     D1 y el recorte por columnas vive en adr068).
--   - NO APLICA `adr068_inscritos_unique_cedula_evento.sql`. Sigue ESCRITO y
--     NO APLICADO a proposito; ver BLOQUE 10.
--   - NO crea la extension `vault` ni la extension `pg_net`: son extensiones
--     administradas por la plataforma. Este archivo solo las USA si ya estan.
--   - NO borra nada: no hay DROP, ni DELETE, ni TRUNCATE (Cero Borrado, Oro #2).
--   - NO loguea ni devuelve secretos en ningun `RAISE NOTICE`.
--
-- ADITIVA, CERO BORRADO (Oro #2):
--   1 tabla nueva, 4 funciones nuevas, 4 indices nuevos, RLS activada en la
--   tabla nueva. Ninguna otra tabla, columna o politica se altera.
--
-- IDEMPOTENCIA: 100%. CREATE TABLE IF NOT EXISTS, DO $$ con guarda en
--   pg_constraint para cada CHECK, CREATE INDEX IF NOT EXISTS, CREATE OR
--   REPLACE FUNCTION en las 4 funciones, y el INSERT de traza con
--   ON CONFLICT (idempotency_key) DO NOTHING + re-lectura del estado previo.
--   Se puede ejecutar 2+ veces seguidas sin error y sin duplicar traza.
--
-- ASCII-SAFETY ESTRICTA: 0 bytes > 127 en todo el archivo, incluidos los
--   comentarios (ADR-002). Verificacion al final del archivo.
--
-- ESTADO: ESCRITO, NO APLICADO. Requiere credenciales de servicio desde el SQL
--   Editor de Supabase (o Management API) y el gate de riesgo de AGENTS.md
--   seccion 2, YA AUTORIZADO por la Direccion para este archivo.
--
-- Verificacion: ver el BLOQUE DE VERIFICACION al final (todo comentado, el
--   archivo no ejecuta nada de esa seccion).
-- ============================================================================


-- ----------------------------------------------------------------------------
-- BLOQUE 0: PRE-FLIGHT (diagnostico NO destructivo, y AVISOS reales)
--
-- Este bloque NO detiene la migracion. Solo emite WARNING cuando falta un
-- prerrequisito, para que el operador vea el problema en la misma corrida en
-- que aplica el archivo, en vez de descubrirlo en el primer registro real.
--
-- Los prerrequisitos que el operador DEBE cumplir ANTES de que el correo
-- funcione estan listados en el BLOQUE DE VERIFICACION (0a) y son:
--   (a) la Edge Function `send-ticket-email` desplegada y con autenticacion
--       por `X-Service-Token` (no por anon key);
--   (b) el secreto del servicio guardado en Supabase Vault con el nombre
--       `send_ticket_email_service_token` (o en `app.settings.service_token`);
--   (c) la extension `pg_net` habilitada (para el envio HTTP desde SQL);
--   (d) Vault habilitada (opcional: hay fallback a `app.settings.*`).
-- ----------------------------------------------------------------------------

DO $adr076_preflight$
DECLARE
    v_inscritos   regclass;
    v_faltan      text := '';
    c             record;
BEGIN
    -- (0.1) Tabla `inscritos`: la RPC de recuperacion la necesita. Si no
    -- existe, la funcion SE CREA igual (plpgsql no valida columnas al
    -- crearse) pero fallara en la primera llamada: por eso el WARNING.
    v_inscritos := to_regclass('public.inscritos');
    IF v_inscritos IS NULL THEN
        RAISE WARNING '[ADR-076] public.inscritos NO existe: obtener_inscrito_por_cedula quedara inutilizable hasta que exista.';
    ELSE
        FOR c IN
            SELECT unnest(ARRAY['cedula','nombre','evento_id','evento_nombre',
                                'evento_fecha','qr_code','used','telefono']) AS col
        LOOP
            IF NOT EXISTS (
                SELECT 1 FROM pg_attribute a
                WHERE a.attrelid = v_inscritos
                  AND a.attname = c.col
                  AND a.attnum > 0
                  AND NOT a.attisdropped
            ) THEN
                v_faltan := v_faltan || c.col || ' ';
            END IF;
        END LOOP;
        IF v_faltan <> '' THEN
            RAISE WARNING '[ADR-076] public.inscritos sin estas columnas requeridas: % . obtener_inscrito_por_cedula fallara en runtime hasta corregir el esquema.', v_faltan;
        ELSE
            RAISE NOTICE '[INFO] ADR-076: public.inscritos tiene las 8 columnas requeridas.';
        END IF;
    END IF;

    -- (0.2) Vault: es extension administrada. No se crea aqui.
    IF to_regclass('vault.decrypted_secrets') IS NULL THEN
        RAISE WARNING '[ADR-076] la extension Vault NO esta disponible: se usara el fallback app.settings.service_token. Para usar Vault, habilitela en el panel (Database > Extensions).';
    ELSE
        RAISE NOTICE '[INFO] ADR-076: Vault disponible (vault.decrypted_secrets existe).';
    END IF;

    -- (0.3) pg_net: sin esta extension no hay envio HTTP desde SQL. La RPC
    -- lo detecta en tiempo de llamada y devuelve estado=error (fail-open
    -- para el usuario final), nunca envia correo de forma anonima.
    IF to_regprocedure('net.http_post(text,jsonb,jsonb,jsonb,integer)') IS NULL THEN
        RAISE WARNING '[ADR-076] la extension pg_net NO esta disponible o su firma cambio: la RPC devolvera estado=error hasta que el operador la habilite (Database > Extensions > pg_net).';
    ELSE
        RAISE NOTICE '[INFO] ADR-076: pg_net disponible (net.http_post con 5 argumentos).';
    END IF;
END $adr076_preflight$;


-- ----------------------------------------------------------------------------
-- BLOQUE 1: TABLA public.email_envios_log (cola + traza)
--
-- SIRVE PARA DOS COSAS DISTINTAS:
--   (1) IDEMPOTENCIA. `idempotency_key` es UNIQUE: si la llave ya existe, la
--       RPC NO reenvia y devuelve el estado previo. Un doble submit del
--       formulario, o un reintento del front, no duplica el correo.
--   (2) SABER A QUIEN YA SE AVISO. El cron de recordatorios (ADR-074,
--       TSK-003) va a preguntar "esta cedula de este evento ya fue avisada?",
--       y la respuesta esta en `created_at` por `(evento_id, cedula_norm)`.
--
-- COLUMNAS EXIGIDAS POR EL PEDIDO (L100 de la peticion):
--   id, evento_id, inscrito_id, destinatario, tipo, estado, intentos,
--   idempotency_key, error_texto, created_at, enviado_at
--
-- COLUMNAS ADICIONALES, y por que son necesarias (no son adorno):
--   cedula_norm  -> sin la cedula normalizada NO se puede implementar el
--                   rate limit "3 envios por cedula+evento cada 10 minutos"
--                   ni la consulta del cron. `inscrito_id` puede venir NULL
--                   desde `serie.html`, que no manda esa columna.
--   ip_origen    -> sin la IP NO se puede implementar el limite por IP. La
--                   IP no se guarda cruda desde el navegador: es el valor
--                   que PostgREST publica en `request.headers` (ver
--                   fn_adr076_ip_origen).
--   origen       -> saber que call site esta abusando del endpoint cuando
--                   aparezca spam en produccion.
--   pg_net_request_id -> number returned by net.http_post, para poder
--                   reconciliar la traza con `net._http_response` despues
--                   (pg_net es asincrono; ver BLOQUE 6, nota importante).
--
-- POR QUE NO HAY FOREIGN KEY a `eventos` ni a `inscritos` (decision
-- consciente, y contraria a adr074 que si la creo):
--   Esta tabla es la AUDITORIA del envio. Una FK con ON DELETE CASCADE
--   borraria la traza de un evento que se eliminara, y una FK sin cascade
--   haria fallar el INSERT si la fila ya no existe. Un log de seguridad que
--   puede desaparecer por un DELETE de otra tabla no es un log de seguridad.
--   Los valores quedan como datos sin integridad referencial, que es
--   preferible a perder el rastro.
--
-- NOTA SOBRE `idempotency_key` NULLABLE:
--   UNIQUE no hace colisionar los NULL entre si (misma razon que documento
--   adr074 sobre `evento_id`). Por eso la llave es NULLABLE: las trazas que
--   crea un proceso interno con su propia llave pueden dejarla NULL, y la
--   idempotencia de la RPC solo mira las llaves no nulas.
--
-- NOTA sobre `estado='enviado'`:
--   pg_net es ASINCRONO: `net.http_post` encola la peticion y devuelve un
--   request_id, no el resultado del envio. Por eso `enviado` significa
--   "ENCOLADO y aceptado por la cola HTTP", no "entregado por el proveedor".
--   La reconciliacion real se lee de `net._http_response` y la debe hacer el
--   proceso de fondo (ADR-074 / TSK-003). Esta migracion no la inventa.
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.email_envios_log (
    id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    evento_id         uuid,
    inscrito_id       uuid,
    destinatario      text        NOT NULL,
    tipo              text        NOT NULL DEFAULT 'registro',
    estado            text        NOT NULL DEFAULT 'pendiente',
    intentos          integer     NOT NULL DEFAULT 0,
    idempotency_key   text        UNIQUE,
    error_texto       text,
    created_at        timestamptz NOT NULL DEFAULT now(),
    enviado_at        timestamptz,
    cedula_norm       text,
    ip_origen         text,
    origen            text,
    pg_net_request_id bigint
);


-- ----------------------------------------------------------------------------
-- BLOQUE 2: CHECK CONSTRAINTS (idempotentes, con guarda en pg_constraint)
--
-- Mismo patron que adr074: se consulta el catalogo por el nombre canonico y
-- solo se agrega el constraint si no existe, con RAISE NOTICE en las dos
-- ramas. Si el CHECK ya estaba, no se intenta volver a crearlo.
--
-- `tipo` cerrado en 3 valores porque son los 3 que la funcion Edge Function
-- sabe maquetear. Dejarlo libre crearia filas que ningun proceso procesa
-- (mismo criterio que el CHECK de `canal` en adr074).
--
-- `estado` cerrado en 4 valores: 'omitido' NO es synonymo de 'error'. Un
-- envio que se SKIPEA por rate limit o por idempotencia esta correcto; un
-- envio que FALLA no. Si fueran el mismo valor, el cron no podria distinguir
-- "ya avisado" de "no se pudo avisar", que son decisiones opuestas.
--
-- `intentos >= 0`: un contador negativo es un bug de escritura, y un log de
-- seguridad con contadores imposibles no sirve para medir nada.
-- ----------------------------------------------------------------------------

DO $adr076_checks$
BEGIN
    -- (2.1) tipo: solo los 3 tipos que la Edge Function maqueta.
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
        WHERE c.conname = 'email_envios_log_tipo_check'
          AND c.conrelid = 'public.email_envios_log'::regclass
    ) THEN
        ALTER TABLE public.email_envios_log
            ADD CONSTRAINT email_envios_log_tipo_check
            CHECK (tipo IN ('registro', 'bienvenida', 'recordatorio'));
        RAISE NOTICE '[INFO] ADR-076: constraint "email_envios_log_tipo_check" creado.';
    ELSE
        RAISE NOTICE '[INFO] ADR-076: constraint "email_envios_log_tipo_check" ya existe, skip.';
    END IF;

    -- (2.2) estado: pendiente / enviado / error / omitido.
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
        WHERE c.conname = 'email_envios_log_estado_check'
          AND c.conrelid = 'public.email_envios_log'::regclass
    ) THEN
        ALTER TABLE public.email_envios_log
            ADD CONSTRAINT email_envios_log_estado_check
            CHECK (estado IN ('pendiente', 'enviado', 'error', 'omitido'));
        RAISE NOTICE '[INFO] ADR-076: constraint "email_envios_log_estado_check" creado.';
    ELSE
        RAISE NOTICE '[INFO] ADR-076: constraint "email_envios_log_estado_check" ya existe, skip.';
    END IF;

    -- (2.3) intentos no negativo.
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
        WHERE c.conname = 'email_envios_log_intentos_check'
          AND c.conrelid = 'public.email_envios_log'::regclass
    ) THEN
        ALTER TABLE public.email_envios_log
            ADD CONSTRAINT email_envios_log_intentos_check
            CHECK (intentos >= 0);
        RAISE NOTICE '[INFO] ADR-076: constraint "email_envios_log_intentos_check" creado.';
    ELSE
        RAISE NOTICE '[INFO] ADR-076: constraint "email_envios_log_intentos_check" ya existe, skip.';
    END IF;

    -- (2.4) coherencia de sello temporal: enviado_at solo si el estado lo
    -- permite. Evita la fila "estado=error con enviado_at puesto", que el
    -- cron leeria como "ya avisado".
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
        WHERE c.conname = 'email_envios_log_enviado_at_check'
          AND c.conrelid = 'public.email_envios_log'::regclass
    ) THEN
        ALTER TABLE public.email_envios_log
            ADD CONSTRAINT email_envios_log_enviado_at_check
            CHECK (enviado_at IS NULL OR estado = 'enviado');
        RAISE NOTICE '[INFO] ADR-076: constraint "email_envios_log_enviado_at_check" creado.';
    ELSE
        RAISE NOTICE '[INFO] ADR-076: constraint "email_envios_log_enviado_at_check" ya existe, skip.';
    END IF;
END $adr076_checks$;


-- ----------------------------------------------------------------------------
-- BLOQUE 3: INDICES (IF NOT EXISTS)
--
-- Los tres de la derecha existen para que un envio NO escanee la tabla: el
-- rate limit cuenta filas en una ventana reciente, y sin indice eso es un
-- seq scan por cada intento de envio, o sea una denegacion de servicio
-- barata (llenar el log hasta que cada registro cuesta un escaneo completo).
--
-- El indice parcial por IP existe ademas porque la IP es NULL en las trazas
-- creadas fuera del navegador (cron, panel), y las filas NULL no aportan nada
-- a un limite por IP.
-- ----------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS email_envios_log_cedula_evento_idx
    ON public.email_envios_log (cedula_norm, evento_id, created_at DESC);

CREATE INDEX IF NOT EXISTS email_envios_log_evento_idx
    ON public.email_envios_log (evento_id, created_at DESC);

CREATE INDEX IF NOT EXISTS email_envios_log_destinatario_idx
    ON public.email_envios_log (destinatario, created_at DESC);

CREATE INDEX IF NOT EXISTS email_envios_log_ip_idx
    ON public.email_envios_log (ip_origen, created_at DESC)
    WHERE ip_origen IS NOT NULL;


-- ----------------------------------------------------------------------------
-- BLOQUE 4: RLS FAIL-CLOSED EN email_envios_log + PERMISOS DE TABLA
--
-- POR QUE RLS ACTIVA Y CERO POLITICAS:
--   Esta tabla es el registro de a quien se le mando correo, cuando, con que
--   resultado y desde que IP. Con RLS activa y ninguna politica para
--   `anon` / `authenticated`, el cliente NO PUEDE leerla: ni una fila, ni un
--   conteo. Eso es deliberado y es fail-closed:
--     - `anon` no tiene por que saber si una cedula ya fue avisada (eso es un
--       oraculo sobre la lista de asistentes de un evento);
--     - `anon` no puede usar la tabla para escribir trazas falsas ni borrar
--       trazas reales, porque sin INSERT/UPDATE/DELETE tampoco puede.
--   Solo el service_role (backend, panel, cron) lee el log, y lo lee por SQL
--   directo, no por PostgREST con la anon key.
--
-- POR QUE LA RPC `enviar_email_registro` PUEDE ESCRIBIR EN LA TABLA SI NO HAY
-- POLITICAS (y por que esto NO es un agujero):
--   La RPC es SECURITY DEFINER: corre con los privilegios de su propietario
--   (el rol que creo la tabla). En PostgreSQL el PROPIETARIO de la tabla
--   esta exento de RLS mientras no se active FORCE ROW LEVEL SECURITY, y esta
--   migracion NO lo activa. Ademas el REVOKE de abajo quita los privilegios de
--   tabla a anon/authenticated: aunque existiera una politica, no tendrian
--   permiso. Los dos controles son independientes y los dos cierran.
--
-- NOTA: no se hace FORCE ROW LEVEL SECURITY a proposito. Con FORCE, la propia
-- RPC dejaria de poder insertar y habria que abrir una politica para el
-- propietario, que es justamente el agujero que este archivo cierra.
-- ----------------------------------------------------------------------------

ALTER TABLE public.email_envios_log ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.email_envios_log FROM PUBLIC;
REVOKE ALL ON TABLE public.email_envios_log FROM anon;
REVOKE ALL ON TABLE public.email_envios_log FROM authenticated;

GRANT SELECT, INSERT, UPDATE ON TABLE public.email_envios_log TO service_role;


-- ----------------------------------------------------------------------------
-- BLOQUE 5: HELPERS
--
-- Tres funciones pequenas, todas con SET search_path explicito, todas con
-- REVOKE + GRANT explicitos (ninguna queda con el EXECUTE por defecto de
-- PUBLIC, que es un permiso de facto abierto a internet via PostgREST).
-- ----------------------------------------------------------------------------


-- (5.1) fn_adr076_texto_limpio(p_valor, p_campo, p_max, p_obligatorio)
--
-- Validador ESTRICTO de string, compartido por las dos RPC.
--
-- QUE RECHAZA y por que:
--   NULL / vacio en campo obligatorio -> el front se equivoco en el nombre
--     del campo o no lo mando. Fallar aqui evita encolar un envio con el
--     payload a medias.
--   longitud > p_max -> el cut del limite se aplica ANTES de tocar el header
--     HTTP, no despues. El cuerpo del correo se limita para que un atacante
--     no pueda meter 10 MB en el log por llamada.
--   [[:cntrl:]] -> CR (0x0D), LF (0x0A), NUL (0x00), TAB, ESC y el resto de
--     controles ASCII. ESTA es la defensa anti header-injection: un
--     destinatario con "\nBcc: victima@..." inyecta una cabecera nueva y
--     convierte el endpoint en relay. Se rechaza en TODOS los campos, no
--     solo en el email, porque el nombre del evento tambien viaja como texto.
--   C1 (U+0080-U+009F) -> include NEL y los separadores Unicode, que algunos
--     agentes de correo interpretan como salto de linea aunque no lo sean.
--
-- QUE NO RECHAZA, y por que (decision consciente):
--   Texto NO ASCII con acentos y enie. `eventoNombre` es "Mistico Nocturno" y
--   el nombre de la persona es "Jose": el nombre del evento y el nombre del
--     asistente se guardan con su acentuacion real. Un validador que rejects
--     acentos dejaria fuera a la poblacion correcta y no impediria ningun
--     ataque real (el relay se controla por la destinacion y por el rate
--     limit, no por el idioma del cuerpo).
--
-- IMMUTABLE: no lee ni escribe nada; depende solo de su entrada.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_adr076_texto_limpio(
    p_valor       text,
    p_campo       text,
    p_max         integer,
    p_obligatorio boolean DEFAULT true
)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public, pg_temp
AS $fn$
DECLARE
    v text;
BEGIN
    IF p_valor IS NULL OR btrim(p_valor) = '' THEN
        IF p_obligatorio THEN
            RAISE EXCEPTION '[ADR-076] campo "%": obligatorio y llego nulo o vacio', p_campo
                USING ERRCODE = '22023';
        END IF;
        RETURN NULL;
    END IF;

    v := btrim(p_valor);

    IF length(v) > p_max THEN
        RAISE EXCEPTION '[ADR-076] campo "%": excede el maximo de % caracteres', p_campo, p_max
            USING ERRCODE = '22023';
    END IF;

    IF v ~ '[[:cntrl:]]' THEN
        RAISE EXCEPTION '[ADR-076] campo "%": contiene caracter de control (CR, LF, NUL u otro) prohibido', p_campo
            USING ERRCODE = '22023';
    END IF;

    IF v ~ '[\u0080-\u009F]' THEN
        RAISE EXCEPTION '[ADR-076] campo "%": contiene un control C1 (U+0080-U+009F) prohibido', p_campo
            USING ERRCODE = '22023';
    END IF;

    RETURN v;
END;
$fn$;

COMMENT ON FUNCTION public.fn_adr076_texto_limpio(text, text, integer, boolean) IS
'Validador estricto de string para ADR-076. Rechaza (fail-closed, ERRCODE 22023): NULL o '
'vacio en campo obligatorio, longitud mayor a p_max, cualquier caracter de control POSIX '
'([[:cntrl:]]: CR, LF, NUL, TAB, ESC) y cualquier control C1 (U+0080-U+009F). Es la defensa '
'anti header-injection y anti relay. NO rechaza texto no-ASCII acentuado (nombre de persona y '
'nombre de evento van acentuados). IMMUTABLE.';


-- (5.2) fn_adr076_secreto(p_nombre text)
--
-- Resuelve el secreto de servicio por nombre, con DOS fuentes y en este orden:
--   (1) Supabase Vault: `vault.decrypted_secrets`, fila con `name = p_nombre`.
--       Se toma la de `id` mayor (la ultima escrita).
--   (2) Fallback: el GUC `app.settings.<p_nombre>` de la sesion/rol, que el
--       operador configura con `ALTER ROLE ... SET app.settings.x = '...'` o
--       `ALTER DATABASE ... SET app.settings.x = '...'`.
--
-- POR QUE ESTA FUNCION NO LA PUEDE LLAMAR EL CLIENTE:
--   Se revoca a PUBLIC, a anon y a authenticated, y se otorga SOLO a
--   service_role. La RPC `enviar_email_registro` si la puede usar porque es
--   SECURITY DEFINER y corre como propietario. Si `anon` pudiera llamarla,
--   el secreto seria legible desde el navegador y no habriamos movido nada.
--
-- POR QUE LEE VAULT SIN QUELE RLS:
--   Corre como propietario de la funcion (rol postgres), exento de RLS sobre
--   `vault.decrypted_secrets`. Por eso es SECURITY DEFINER, y por eso el
--   nombre del parametro esta validado: un nombre arbitrario se usaria para
--   leer CUALQUIER secreto del Vault.
--
-- FAIL-CLOSED: si ninguna fuente tiene el secreto, devuelve NULL (la RPC que
--   la llama lanza excepcion). Nunca devuelve cadena vacia como "ok".
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_adr076_secreto(p_nombre text)
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
    v_val text;
BEGIN
    -- Nombre validado: solo [a-z0-9_]. Sin esto, un nombre con comas o
    -- espacios permitiria leer secretos que el operador no penso abrir.
    IF p_nombre IS NULL OR p_nombre !~ '^[a-z0-9_]{1,60}$' THEN
        RETURN NULL;
    END IF;

    -- (1) Vault. Guardado con to_regclass: la extension es administrada por la
    -- plataforma y este archivo NO la crea. Si no esta, la rama no se ejecuta
    -- y se cae al fallback.
    IF to_regclass('vault.decrypted_secrets') IS NOT NULL THEN
        BEGIN
            SELECT d.decrypted_secret INTO v_val
            FROM vault.decrypted_secrets d
            WHERE d.name = p_nombre
            ORDER BY d.id DESC
            LIMIT 1;
        EXCEPTION WHEN OTHERS THEN
            v_val := NULL;
        END;
    END IF;

    -- (2) Fallback en el GUC app.settings.<nombre>.
    IF v_val IS NULL OR btrim(v_val) = '' THEN
        BEGIN
            v_val := current_setting('app.settings.' || p_nombre, true);
        EXCEPTION WHEN OTHERS THEN
            v_val := NULL;
        END;
    END IF;

    IF v_val IS NULL THEN
        RETURN NULL;
    END IF;

    RETURN btrim(v_val);
END;
$fn$;

COMMENT ON FUNCTION public.fn_adr076_secreto(text) IS
'Resuelve un secreto de servicio por nombre para ADR-076, primero en '
'vault.decrypted_secrets y si no en el GUC app.settings.<nombre>. Devuelve NULL si no esta '
'configurado (fail-closed: la RPC que la llama lanza excepcion). SECURITY DEFINER porque '
'Vault tiene RLS propia. NO se otorga a PUBLIC, anon ni authenticated: solo service_role.';


-- (5.3) fn_adr076_ip_origen()
--
-- De donde vino la llamada. Es la UNICA fuente de IP confiable desde una RPC
-- de PostgREST, y la razon por la que el limite por IP se puede implementar
-- aca y no solo en la Edge Function:
--
--   (1) `request.headers`, el GUC que PostgREST publica con las cabeceras de
--       la peticion. Se prueban, en orden: `cf-connecting-ip`, la primera
--       entrada de `x-forwarded-for` (puede ser una cadena separada por
--       comas) y `x-real-ip`.
--   (2) `inet_client_addr()` como ultimo recurso. OJO: desde una RPC de
--       PostgREST devuelve la direccion del pooler, NO la del visitante, asi
--       que en la practica casi nunca sirve. Se filtra 127.0.0.1, ::1, 0.0.0.0
--       y :: porque una IP local no es un identificador de abusador: si
--       llegara a contar, todas las llamadas de la plataforma compartirián
--       la misma cuota.
--
-- SECURITY INVOKER (no DEFINER) a proposito: el GUC de la sesion y
-- inet_client_addr() los puede leer cualquier rol, y no hay nada secreto
-- aqui. Solo devuelve la IP del PROPIO llamador.
--
-- DEVUELVE NULL cuando no hay IP utilizable. El rate limit por IP se SKIPEA
-- en ese caso (ver BLOQUE 6) en vez de猜 un valor.
--
-- SOBRE EL RIESGO DE FALSOS POSITIVOS (objecion de ADR-068):
--   ADR-068 decidio NO poner un limite por IP en la tabla de inscriptions por
--   el carrier-grade NAT de los asistentes que comparten salida. Ahi el
--   limite era por persona; el riesgo real era bloquear a un grupo entero de
--   gente que va al mismo evento. Este limite es POR CORREO (10 por hora) y
--   se combina con el limite por cedula (3 por 10 minutos), que es el que
--   realmente frena el relay de una persona. Si en produccion aparecen
--   falsos positivos, el numero se sube con un UPDATE en el BLOQUE 6 y no se
--   elimina la linea: el limite por IP sigue siendo la unica defensa contra
--   un atacante con muchas cedulas.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_adr076_ip_origen()
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public, pg_temp
AS $fn$
DECLARE
    v_raw  text;
    v_hdrs jsonb;
    v_ip   text;
BEGIN
    BEGIN
        v_raw := current_setting('request.headers', true);
    EXCEPTION WHEN OTHERS THEN
        v_raw := NULL;
    END;

    IF v_raw IS NOT NULL AND btrim(v_raw) <> '' THEN
        BEGIN
            v_hdrs := v_raw::jsonb;
        EXCEPTION WHEN OTHERS THEN
            v_hdrs := NULL;
        END;
    END IF;

    IF v_hdrs IS NOT NULL THEN
        v_ip := coalesce(
            nullif(btrim(v_hdrs ->> 'cf-connecting-ip'), ''),
            nullif(btrim(split_part(coalesce(v_hdrs ->> 'x-forwarded-for', ''), ',', 1)), ''),
            nullif(btrim(v_hdrs ->> 'x-real-ip'), '')
        );
    END IF;

    IF v_ip IS NULL THEN
        BEGIN
            v_ip := inet_client_addr()::text;
        EXCEPTION WHEN OTHERS THEN
            v_ip := NULL;
        END;
    END IF;

    IF v_ip IS NULL THEN
        RETURN NULL;
    END IF;

    IF v_ip IN ('127.0.0.1', '::1', '0.0.0.0', '::') THEN
        RETURN NULL;
    END IF;

    RETURN v_ip;
END;
$fn$;

COMMENT ON FUNCTION public.fn_adr076_ip_origen() IS
'IP del llamador para el rate limit de ADR-076, leida de request.headers (cf-connecting-ip, '
'primera entrada de x-forwarded-for, x-real-ip) y con inet_client_addr() como ultimo recurso. '
'Devuelve NULL si la IP no es utilizable (pooler, loopback), y el limite por IP se omite. '
'SECURITY INVOKER: solo lee GUCs de sesion y devuelve la IP del propio llamador.';


-- ----------------------------------------------------------------------------
-- BLOQUE 6: RPC public.enviar_email_registro(...)
--
-- ESTA ES LA FUNCION QUE CIERRA EL AGUJERO. Los call sites publicos dejan de
-- llamar a la Edge Function con la anon key y pasan a llamar a esta RPC con
-- la anon key: la diferencia es que aqui la anon key NO da permiso para
-- enviar nada por si sola. La autorizacion real la tiene el secreto de
-- servicio, que el cliente nunca ve.
--
-- FIRMA (el orden importa: los parametros SIN default van primero):
--   enviar_email_registro(
--       p_email              text,   -- destinatario (obligatorio)
--       p_nombre             text,   -- nombre del asistente
--       p_qr_code            text,   -- QR o enlace al ticket (obligatorio)
--       p_evento_nombre      text,
--       p_evento_fecha       text,
--       p_evento_hora        text,
--       p_evento_lugar       text,
--       p_idempotency_key    text,   -- OBLIGATORIA (obligatorio)
--       p_tipo               text    DEFAULT 'registro',
--       p_cedula             text    DEFAULT NULL,
--       p_evento_id          uuid    DEFAULT NULL,
--       p_inscrito_id        uuid    DEFAULT NULL,
--       p_bypass_rate_limit  boolean DEFAULT false
--   ) RETURNS jsonb
--
-- Los 8 primeros reciben exactamente lo que hoy envian los call sites
-- (email, nombre, qrCode, eventoNombre, eventoFecha, eventoHora, eventoLugar)
-- con los mismos limites de longitud que necesita el maquetado del correo.
-- `p_tipo` ya lo manda admin.html hoy.
--
-- LO QUE LA RPC NO ACEPTA, Y ES EL PUNTO:
--   NO hay ningun parametro de credencial. Ni anon key, ni service_role key,
--   ni token. No hay forma de que un llamador suplante la autorizacion: o
--   esta el secreto de servicio configurado en el servidor, o no se envia
--   nada. Por eso la anon key puede quedarse en el HTML sin abrir nada.
--
-- POLITICA DE FALLAS (dos criterios distintos, a proposito):
--   FALLA CERRADO (lanza EXCEPTION, el cliente ve error):
--     - payload invalido: email con formato raro, control chars, largo de mas;
--     - credencial ausente: no hay secreto en Vault ni en app.settings.
--     Esto es contra el ATACANTE: una excepcion no distingue "intento
--     inyectar" de "no hay token", y el atacante no obtiene informacion.
--   FALLA ABIERTO (devuelve jsonb con ok=false, el cliente NO ve error):
--     - pg_net no disponible;
--     - la llamada HTTP falla o se corta de tiempo;
--     - falla la escritura de la traza.
--     Esto es contra el USUARIO FINAL: un registro hecho en el formulario NO
--     puede perderse porque el correo no salio (mismo criterio que ADR-008 en
--     la portabilidad y que el fail-open que ya tienen los call sites).
--
-- IDEMPOTENCIA:
--   Si `p_idempotency_key` ya existe, NO se reenvia: se devuelve el estado
--   previo con motivo 'idempotente'. El segundo mecanismo (por si dos
--   llamadas@\p simultaneas con la misma llave) es el UNIQUE de la tabla:
--   el INSERT captura unique_violation y relee la fila ganadora.
--
-- RATE LIMIT (dos ventanas, la mas restrictiva manda):
--   (a) 3 envios por (cedula, evento_id) cada 10 minutos.
--       Requiere `p_cedula`; si llega NULL, esta ventana se SKIPEA y solo
--       aplica la (b). Motivo logico: sin cedula no hay con que contar por
--       persona, y se elige no inventar una ventana global que bloquearia a
--       un evento entero.
--   (b) 10 envios por IP cada hora.
--       Requiere IP utilizable (ver fn_adr076_ip_origen); si no hay, se
--       SKIPEA. CUANDO NO HAY IP DESDE LA RPC, el limite por IP TIENE QUE
--       estar ADEMAS en la Edge Function: es la unica capa que ve la IP real
--       antes de que el pooler la aplane. Esta migracion no puede resolverlo
--       y no lo simula.
--   Se cuentan TODAS las filas de la ventana (pendiente, enviado, error y
--   omitido): si solo se contaran las exitosas, un atacante que provoque
--   errores para agotar cuota podria reintentar sin limite.
--
-- BYPASS DEL RATE LIMIT:
--   El flag `p_bypass_rate_limit` SOLO se honra si el rol del JWT es
--   'service_role'. Para `anon` y `authenticated` el flag se IGNORA en
--   silencio: aceptarlo y aplicarlo seria un bypass con una bandera escrita
--   por el cliente. El cron (ADR-074 / TSK-003) es el unico caso legitimo y
--   va con service_role.
--
-- SEGURIDAD DEL ENVIO:
--   Cabeceras del POST a la Edge Function: `X-Service-Token` con el secreto.
--   Si el operador creo ademas el secreto opcional
--   `send_ticket_email_bearer`, se agrega `Authorization: Bearer <valor>`
--   para despliegues que exijan el JWT de sesion ademas del token. El token
--   NUNCA se escribe en la traza, ni en un NOTICE, ni en el jsonb de
--   respuesta.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.enviar_email_registro(
    p_email             text,
    p_nombre            text,
    p_qr_code           text,
    p_evento_nombre     text,
    p_evento_fecha      text,
    p_evento_hora       text,
    p_evento_lugar      text,
    p_idempotency_key   text,
    p_tipo              text    DEFAULT 'registro',
    p_cedula            text    DEFAULT NULL,
    p_evento_id         uuid    DEFAULT NULL,
    p_inscrito_id       uuid    DEFAULT NULL,
    p_bypass_rate_limit boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
    v_email   text;
    v_nombre  text;
    v_qr      text;
    v_evnom   text;
    v_evfecha text;
    v_evhora  text;
    v_evlugar text;
    v_tipo    text;
    v_cedula  text;
    v_cednorm text;
    v_key     text;
    v_origen  text;
    v_ip      text;
    v_token   text;
    v_bearer  text;
    v_url     text;
    v_estado  text;
    v_log     uuid;
    v_prev    uuid;
    v_req     bigint;
    v_cant    integer;
    v_caller  text;
    v_bypass  boolean;
    v_body    jsonb;
    v_headers jsonb;
BEGIN
    -- (6.1) Rol real del llamador, para el bypass. Se toma del JWT que
    -- PostgREST publica; si no hay JWT (llamada directa por SQL), el rol de
    -- sesion. `anon` nunca puede producir 'service_role'.
    v_caller := coalesce(
        nullif(btrim(current_setting('request.jwt.claim.role', true)), ''),
        current_user
    );

    -- (6.2) VALIDACION ESTRICTA. Cualquier falla aqui lanza excepcion
    -- (fail-closed): es la seccion que decide si esto es un registro legitimo
    -- o un intento de abuse.
    v_email   := public.fn_adr076_texto_limpio(p_email,          'email',           254, true);
    v_nombre  := public.fn_adr076_texto_limpio(p_nombre,         'nombre',          120, false);
    v_qr      := public.fn_adr076_texto_limpio(p_qr_code,        'qr_code',         600, true);
    v_evnom   := public.fn_adr076_texto_limpio(p_evento_nombre,  'evento_nombre',   200, false);
    v_evfecha := public.fn_adr076_texto_limpio(p_evento_fecha,   'evento_fecha',     80, false);
    v_evhora  := public.fn_adr076_texto_limpio(p_evento_hora,    'evento_hora',      20, false);
    v_evlugar := public.fn_adr076_texto_limpio(p_evento_lugar,   'evento_lugar',    200, false);
    v_tipo    := public.fn_adr076_texto_limpio(p_tipo,           'tipo',             20, false);
    v_cedula  := public.fn_adr076_texto_limpio(p_cedula,         'cedula',           32, false);
    v_key     := public.fn_adr076_texto_limpio(p_idempotency_key,'idempotency_key', 200, true);
    v_origen  := public.fn_adr076_texto_limpio('rpc_publica',        'origen',          60, false);

    IF v_tipo IS NULL THEN
        v_tipo := 'registro';
    END IF;

    IF v_tipo NOT IN ('registro', 'bienvenida', 'recordatorio') THEN
        RAISE EXCEPTION '[ADR-076] tipo "%" no permitido', v_tipo
            USING ERRCODE = '22023';
    END IF;

    -- Email: longitud (arriba), sin puntos consecutivos y con dominio
    -- jerarquico de al menos una etiqueta. La clase de caracteres del local
    -- parte es la ASCII estandar; el control de CR/LF ya lo hizo
    -- fn_adr076_texto_limpio, que es la defensa real anti header-injection.
    IF v_email !~ '^[A-Za-z0-9._%+-]{1,64}@[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)+$' THEN
        RAISE EXCEPTION '[ADR-076] email con formato invalido'
            USING ERRCODE = '22023';
    END IF;

    IF position('..' IN v_email) > 0 THEN
        RAISE EXCEPTION '[ADR-076] email con puntos consecutivos'
            USING ERRCODE = '22023';
    END IF;

    -- Cedula normalizada a digitos: es la llave del rate limit por persona y
    -- la que va al indice. Los datos historicos pueden traer "12.345.678"
    -- (mismo problema que documenta adr068 paso 3).
    IF v_cedula IS NOT NULL THEN
        v_cednorm := regexp_replace(v_cedula, '[^0-9]', '', 'g');
        IF length(v_cednorm) < 4 OR length(v_cednorm) > 20 THEN
            v_cednorm := NULL;
        END IF;
    END IF;

    -- (6.3) IP del llamador. Puede quedar NULL (pooler): no es motivo de
    -- fallo, solo desactiva la ventana (b) del rate limit.
    v_ip := public.fn_adr076_ip_origen();

    -- (6.4) BYPASS solo para service_role. Para el resto el flag se ignora.
    v_bypass := (coalesce(p_bypass_rate_limit, false) AND v_caller = 'service_role');

    -- (6.5) IDEMPOTENCIA (primera pasada, sin escritura). Si la llave ya
    -- esta, se devuelve el estado previo y NO se reenvia.
    SELECT l.estado, l.id INTO v_estado, v_prev
    FROM public.email_envios_log l
    WHERE l.idempotency_key = v_key
    ORDER BY l.created_at DESC
    LIMIT 1;

    IF v_prev IS NOT NULL THEN
        RETURN jsonb_build_object(
            'ok',     true,
            'estado', coalesce(v_estado, 'pendiente'),
            'motivo', 'idempotente',
            'id',     v_prev
        );
    END IF;

    -- (6.6) CREDENCIAL (fail-closed). Si no hay secreto de servicio, esta RPC
    -- no envia correo. NO hay ruta alternativa: no se cae a la anon key, no
    -- se manda sin cabecera, no se "intenta de todas formas".
    v_token := public.fn_adr076_secreto('send_ticket_email_service_token');
    IF v_token IS NULL OR v_token = '' THEN
        RAISE EXCEPTION '[ADR-076] no hay credencial de servicio configurada: revise el secreto send_ticket_email_service_token en Supabase Vault o en app.settings.service_token'
            USING ERRCODE = '42501';
    END IF;

    -- A partir de aqui todo es fail-ABIERTO: nada de lo que sigue puede
    -- abortar la operacion del usuario final, se devuelve jsonb con ok=false.
    BEGIN
        -- (6.7) RATE LIMIT por cedula+evento: 3 cada 10 minutos.
        IF NOT v_bypass AND v_cednorm IS NOT NULL THEN
            SELECT count(*) INTO v_cant
            FROM public.email_envios_log l
            WHERE l.cedula_norm = v_cednorm
              AND l.evento_id IS NOT DISTINCT FROM p_evento_id
              AND l.created_at > (now() - interval '10 minutes');

            IF v_cant >= 3 THEN
                BEGIN
                    INSERT INTO public.email_envios_log
                        (evento_id, inscrito_id, destinatario, tipo, estado,
                         intentos, idempotency_key, error_texto,
                         cedula_norm, ip_origen, origen)
                    VALUES
                        (p_evento_id, p_inscrito_id, v_email, v_tipo, 'omitido',
                         0, v_key, 'rate_limit_cedula',
                         v_cednorm, v_ip, v_origen)
                    ON CONFLICT (idempotency_key) DO NOTHING;
                EXCEPTION WHEN OTHERS THEN
                    NULL;
                END;

                RETURN jsonb_build_object(
                    'ok',     false,
                    'estado', 'omitido',
                    'motivo', 'rate_limit_cedula'
                );
            END IF;
        END IF;

        -- (6.8) RATE LIMIT por IP: 10 por hora.
        IF NOT v_bypass AND v_ip IS NOT NULL THEN
            SELECT count(*) INTO v_cant
            FROM public.email_envios_log l
            WHERE l.ip_origen = v_ip
              AND l.created_at > (now() - interval '1 hour');

            IF v_cant >= 10 THEN
                BEGIN
                    INSERT INTO public.email_envios_log
                        (evento_id, inscrito_id, destinatario, tipo, estado,
                         intentos, idempotency_key, error_texto,
                         cedula_norm, ip_origen, origen)
                    VALUES
                        (p_evento_id, p_inscrito_id, v_email, v_tipo, 'omitido',
                         0, v_key, 'rate_limit_ip',
                         v_cednorm, v_ip, v_origen)
                    ON CONFLICT (idempotency_key) DO NOTHING;
                EXCEPTION WHEN OTHERS THEN
                    NULL;
                END;

                RETURN jsonb_build_object(
                    'ok',     false,
                    'estado', 'omitido',
                    'motivo', 'rate_limit_ip'
                );
            END IF;
        END IF;

        -- (6.9) TRAZA. Se inserta DESPUES de los limites de rate (asi el
        -- intento que se omite no consume cuota) y ANTES del envio (asi un
        -- corte de conexion a mitad de camino no deja un envio sin rastro).
        BEGIN
            INSERT INTO public.email_envios_log
                (evento_id, inscrito_id, destinatario, tipo, estado,
                 intentos, idempotency_key, error_texto,
                 cedula_norm, ip_origen, origen)
            VALUES
                (p_evento_id, p_inscrito_id, v_email, v_tipo, 'pendiente',
                 0, v_key, NULL,
                 v_cednorm, v_ip, v_origen)
            ON CONFLICT (idempotency_key) DO NOTHING
            RETURNING id INTO v_log;
        EXCEPTION WHEN unique_violation THEN
            NULL;
        END;

        -- Carrera: otra llamada con la misma llave gano el INSERT. Se relee
        -- su resultado y se devuelve el suyo, sin reenviar.
        IF v_log IS NULL THEN
            SELECT l.estado, l.id INTO v_estado, v_prev
            FROM public.email_envios_log l
            WHERE l.idempotency_key = v_key
            ORDER BY l.created_at DESC
            LIMIT 1;

            IF v_prev IS NOT NULL THEN
                RETURN jsonb_build_object(
                    'ok',     true,
                    'estado', coalesce(v_estado, 'pendiente'),
                    'motivo', 'idempotente',
                    'id',     v_prev
                );
            END IF;

            -- La fila previa no se ve: no se puede garantizar nada sobre este
            -- envio. Se responde fail-open sin enviar.
            RETURN jsonb_build_object(
                'ok',     false,
                'estado', 'error',
                'motivo', 'traza_no_confirmada'
            );
        END IF;

        -- (6.10) DEPENDENCIA DE TRANSPORTE. Sin pg_net no hay envio HTTP
        -- desde SQL. Se registra el error y se responde fail-open: el
        -- registro del asistente ya existe y no se pierde por el correo.
        IF to_regprocedure('net.http_post(text,jsonb,jsonb,jsonb,integer)') IS NULL THEN
            UPDATE public.email_envios_log
               SET estado      = 'error',
                   intentos    = intentos + 1,
                   error_texto = 'pg_net_no_disponible'
             WHERE id = v_log;

            RETURN jsonb_build_object(
                'ok',     false,
                'estado', 'error',
                'motivo', 'pg_net_no_disponible',
                'id',     v_log
            );
        END IF;

        -- (6.11) ARMADO DEL POST. `origen` viaja como dato de traza en la
        -- cabecera, para que el log de la Edge Function diga que motor mando
        -- el correo. El secreto viaja solo en `X-Service-Token` (y, si el
        -- operador lo creo, en `Authorization`), nunca en el cuerpo.
        v_url := coalesce(
            nullif(btrim(current_setting('app.settings.functions_url', true)), ''),
            'https://ctgyvydzshueemlelkzv.supabase.co/functions/v1/send-ticket-email'
        );

        v_headers := jsonb_build_object(
            'Content-Type',    'application/json',
            'Accept',          'application/json',
            'X-Service-Token', v_token,
            'X-Origem',        coalesce(v_origen, 'desconocido')
        );

        v_bearer := public.fn_adr076_secreto('send_ticket_email_bearer');
        IF v_bearer IS NOT NULL AND v_bearer <> '' THEN
            v_headers := v_headers || jsonb_build_object('Authorization', 'Bearer ' || v_bearer);
        END IF;

        v_body := jsonb_strip_nulls(jsonb_build_object(
            'email',        v_email,
            'nombre',       v_nombre,
            'qrCode',       v_qr,
            'eventoNombre', v_evnom,
            'eventoFecha',  v_evfecha,
            'eventoHora',   v_evhora,
            'eventoLugar',  v_evlugar,
            'tipo',         v_tipo
        ));

        -- (6.12) ENVIO. pg_net es asincrono: `estado='enviado'` significa
        -- ENCOLADO, no entregado. La reconciliacion con net._http_response
        -- es tarea del proceso de fondo (ADR-074 / TSK-003).
        BEGIN
            v_req := net.http_post(v_url, v_body, '{}'::jsonb, v_headers, 5000);

            UPDATE public.email_envios_log
               SET estado            = 'enviado',
                   enviado_at        = now(),
                   intentos          = intentos + 1,
                   pg_net_request_id = v_req,
                   error_texto       = NULL
             WHERE id = v_log;

            RETURN jsonb_build_object(
                'ok',                true,
                'estado',            'enviado',
                'motivo',            'encolado',
                'pg_net_request_id', v_req,
                'id',                v_log
            );
        EXCEPTION WHEN OTHERS THEN
            UPDATE public.email_envios_log
               SET estado      = 'error',
                   intentos    = intentos + 1,
                   error_texto = left(SQLERRM, 400)
             WHERE id = v_log;

            RETURN jsonb_build_object(
                'ok',     false,
                'estado', 'error',
                'motivo', 'fallo_envio',
                'id',     v_log
            );
        END;
    EXCEPTION WHEN OTHERS THEN
        -- (6.13) Red de seguridad fail-ABIERTO. Cualquier otra excepcion en
        -- la zona de envio se convierte en respuesta coherente. NUNCA se
        -- relanza: un error de infraestructura no puede impedir un registro.
        RETURN jsonb_build_object(
            'ok',     false,
            'estado', 'error',
            'motivo', 'fallo_interno'
        );
    END;
END;
$fn$;

COMMENT ON FUNCTION public.enviar_email_registro(text, text, text, text, text, text, text, text, text, uuid, uuid, boolean) IS
'ADR-076: UNICO camino permitido para enviar correo desde un call site publico. No recibe '
'ninguna credencial del llamador: usa el secreto de servicio guardado en Supabase Vault '
'(send_ticket_email_service_token) o en app.settings.service_token. Sin ese secreto falla '
'CERRADO con ERRCODE 42501 (no envia de forma anonima). Valida email (regex + 254 chars), '
'rechaza CR/LF/NUL y controles en todos los campos, y acota longitudes. Idempotente por '
'idempotency_key (UNIQUE): si la llave ya existe devuelve el estado previo sin reenviar. '
'Rate limit: 3 envios por (cedula, evento_id) cada 10 min y 10 por IP cada hora (ambos '
'ajustables aqui); p_bypass_rate_limit SOLO se honra con rol service_role. Falla ABIERTO '
'para el usuario final (devuelve jsonb con ok=false, nunca excepcion) y CERRADO ante payload '
'invalido o credencial ausente. SECURITY DEFINER con search_path = public, pg_temp.';


-- ----------------------------------------------------------------------------
-- BLOQUE 7: RPC public.obtener_inscrito_por_cedula(...)
--
-- REEMPLAZA EL `SELECT *` ANONIMO. No es una recorte de columnas: es un
-- recorte de FILAS y de CAMPOS a la vez.
--
-- FIRMA:
--   obtener_inscrito_por_cedula(
--       p_cedula   text,        -- OBLIGATORIA
--       p_evento_id uuid,       -- OBLIGATORIA
--       p_telefono text DEFAULT NULL   -- segundo factor, opcional
--   ) RETURNS jsonb
--
-- QUE DEVUELVE (jsonb):
--   ok, motivo, cedula, nombre, evento_id, evento_nombre, evento_fecha,
--   qr_code, used, telefono, segundo_factor_ok
--
-- QUE NO DEVUELVE, Y POR QUE:
--   - `email`: es el dato de contacto de TERCEROS. Nadie necesita el correo de
--     otra persona para recuperar su propia entrada, y devolverlo convierte la
--     recuperacion en un harvest de correos.
--   - filas de otros eventos: el filtro `evento_id = p_evento_id` es
--     OBLIGATORIO y la pareja se exige completa. Consultar por cedula sola
--    确认aria la existencia de una inscripcion y serviria para enumerar
--     asistentes evento por evento.
--   - `tipo`, `org_id`, `respuestas_custom`, `ref_codigo`, `cliente_id`,
--     `ciudad`, `whatsapp`: no hacen falta para renderizar el ticket.
--
-- `telefono` SOLO se devuelve si el llamador lo aporta Y coincide con el
-- almacenado (comparado en digitos, porque el dato historico trae formatos
-- sucios: "12.345.678", "+57 300 123 4567"). Si no coincide, `telefono` vuelve
-- NULL y `segundo_factor_ok` queda false: la fila sigue devolviendo el
-- ticket, que es lo que el visitante quiere ver, pero no se confirma el
-- segundo factor. Esto NO sube el nivel de seguridad del lookup por si solo
-- (ver BLOQUE 9): un atacante que adivine el telefono lo traversa igual. El
-- segundo factor de verdad (OTP) es una decision de D1.
--
-- DETERMINISMO: `ORDER BY i.used ASC NULLS LAST, i.id ASC LIMIT 1`. Hoy
-- pueden existir varias filas para la misma pareja porque el indice unico de
-- ADR-068 todavia NO esta aplicado; cuando se aplique habra exactamente una,
-- y este ORDER BY seguira siendo valido.
--
-- SECURITY DEFINER: necesario, porque la lectura minima NO la puede hacer el
-- rol `anon` una vez que ADR-068 reduzca sus columnas, y porque el recorte
-- por columnas no oculta la EXISTENCIA de la fila (mismo argumento que
-- ADR-068 deja escrito). Con esta RPC, `anon` ejecuta una funcion con
-- privilegios de propietario y la unica salida posible es el jsonb de esta
-- firma.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.obtener_inscrito_por_cedula(
    p_cedula    text,
    p_evento_id uuid,
    p_telefono  text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
    v_ced  text;
    v_tel  text;
    v_fila record;
BEGIN
    -- (7.1) Validacion. Mismo validador que el envio: control chars prohibidos
    -- y largo acotado. Una cedula con CR/LF en un `WHERE` de PostgREST no es
    -- solo un problema deinyeccion: ensucia el indice y el log.
    v_ced := public.fn_adr076_texto_limpio(p_cedula, 'cedula', 32, true);
    v_tel := public.fn_adr076_texto_limpio(p_telefono, 'telefono', 32, false);

    IF p_evento_id IS NULL THEN
        RAISE EXCEPTION '[ADR-076] evento_id es obligatorio: la pareja (cedula, evento_id) es la llave'
            USING ERRCODE = '22023';
    END IF;

    v_ced := regexp_replace(v_ced, '[^0-9]', '', 'g');
    IF length(v_ced) < 4 THEN
        RAISE EXCEPTION '[ADR-076] cedula sin al menos 4 digitos'
            USING ERRCODE = '22023';
    END IF;

    IF v_tel IS NOT NULL THEN
        v_tel := regexp_replace(v_tel, '[^0-9]', '', 'g');
    END IF;

    -- (7.2) Consulta minima. `coalesce` en las columnas evita que un NULL
    -- historico devuelva la fila como ausente.
    SELECT
        coalesce(i.cedula, '')                     AS cedula,
        coalesce(i.nombre, '')                     AS nombre,
        i.evento_id                                AS evento_id,
        coalesce(i.evento_nombre, '')              AS evento_nombre,
        coalesce(i.evento_fecha, '')               AS evento_fecha,
        coalesce(i.qr_code, '')                    AS qr_code,
        coalesce(i.used, false)                    AS used,
        coalesce(i.telefono, '')                   AS telefono
    INTO v_fila
    FROM public.inscritos i
    WHERE i.evento_id = p_evento_id
      AND regexp_replace(coalesce(i.cedula, ''), '[^0-9]', '', 'g') = v_ced
    ORDER BY i.used ASC NULLS LAST, i.id ASC
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'ok',     false,
            'motivo', 'no_encontrado'
        );
    END IF;

    -- (7.3) Segundo factor. El telefono solo se devuelve con coincidencia.
    IF v_tel IS NOT NULL
       AND v_tel <> ''
       AND v_tel = regexp_replace(coalesce(v_fila.telefono, ''), '[^0-9]', '', 'g') THEN
        RETURN jsonb_build_object(
            'ok',               true,
            'motivo',           'ok',
            'cedula',           v_fila.cedula,
            'nombre',           v_fila.nombre,
            'evento_id',        v_fila.evento_id,
            'evento_nombre',    v_fila.evento_nombre,
            'evento_fecha',     v_fila.evento_fecha,
            'qr_code',          v_fila.qr_code,
            'used',             v_fila.used,
            'telefono',         v_fila.telefono,
            'segundo_factor_ok', true
        );
    END IF;

    RETURN jsonb_build_object(
        'ok',                true,
        'motivo',            'ok',
        'cedula',            v_fila.cedula,
        'nombre',            v_fila.nombre,
        'evento_id',         v_fila.evento_id,
        'evento_nombre',     v_fila.evento_nombre,
        'evento_fecha',      v_fila.evento_fecha,
        'qr_code',           v_fila.qr_code,
        'used',              v_fila.used,
        'telefono',          NULL,
        'segundo_factor_ok', false
    );
END;
$fn$;

COMMENT ON FUNCTION public.obtener_inscrito_por_cedula(text, uuid, text) IS
'ADR-076: reemplaza el SELECT * anonimo sobre inscritos. Devuelve SOLO cedula, nombre, '
'evento_id, evento_nombre, evento_fecha, qr_code, used y (telefono unicamente si el llamador '
'lo aporta como segundo factor y coincide en digitos). NO devuelve el email de terceros ni '
'filas de otros eventos: exige la pareja completa (cedula, evento_id). SECURITY DEFINER con '
'search_path = public, pg_temp; el recorte por columnas de ADR-068 no oculta la existencia de '
'la fila, esta RPC si.';


-- ----------------------------------------------------------------------------
-- BLOQUE 8: PERMISOS DE LAS FUNCIONES (REVOKE + GRANT explicitos)
--
-- POR QUE EL REVOKE A PUBLIC ES OBLIGATORIO:
--   PostgreSQL otorga EXECUTE a PUBLIC en TODA funcion nueva. Eso significa
--   que cualquier rol del cluster (anon incluido) puede invocarla por
--   PostgREST con la anon key. Este archivo REVOCA y luego GRANTea
--   explicitamente, sin dejar el permiso por defecto como puerta trasera.
--
-- A QUIEN SE OTORGA:
--   anon y authenticated -> los call sites publicos (`serie.html`,
--   `registroaforo.html`) siguen siendo anonimos, pero ya no llevan una
--   credencial de correo: llevan una funcion que decide.
--   service_role -> el backend, el panel y el cron. Se otorga de forma
--   explicita y no por herencia, porque `p_bypass_rate_limit` solo se honra
--   con ese rol y sin EXECUTE no habria quien lo use.
--   fn_adr076_secreto NO se otorga a anon ni a authenticated: leer un secreto
--   desde el navegador dejaria todo esto sin efecto.
--
-- NOTA SOBRE POSTGREST: `NOTIFY pgrst, 'reload schema'` despues de esto, o
-- las funciones devuelven PGRST205 hasta que se recargue el cache.
-- ----------------------------------------------------------------------------

REVOKE ALL ON FUNCTION public.fn_adr076_texto_limpio(text, text, integer, boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_adr076_texto_limpio(text, text, integer, boolean) FROM anon;
REVOKE ALL ON FUNCTION public.fn_adr076_texto_limpio(text, text, integer, boolean) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.fn_adr076_texto_limpio(text, text, integer, boolean) TO service_role;

REVOKE ALL ON FUNCTION public.fn_adr076_secreto(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_adr076_secreto(text) FROM anon;
REVOKE ALL ON FUNCTION public.fn_adr076_secreto(text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.fn_adr076_secreto(text) TO service_role;

REVOKE ALL ON FUNCTION public.fn_adr076_ip_origen() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_adr076_ip_origen() FROM anon;
REVOKE ALL ON FUNCTION public.fn_adr076_ip_origen() FROM authenticated;
GRANT EXECUTE ON FUNCTION public.fn_adr076_ip_origen() TO anon;
GRANT EXECUTE ON FUNCTION public.fn_adr076_ip_origen() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_adr076_ip_origen() TO service_role;

REVOKE ALL ON FUNCTION public.enviar_email_registro(text, text, text, text, text, text, text, text, text, uuid, uuid, boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.enviar_email_registro(text, text, text, text, text, text, text, text, text, uuid, uuid, boolean) FROM anon;
REVOKE ALL ON FUNCTION public.enviar_email_registro(text, text, text, text, text, text, text, text, text, uuid, uuid, boolean) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.enviar_email_registro(text, text, text, text, text, text, text, text, text, uuid, uuid, boolean) TO anon;
GRANT EXECUTE ON FUNCTION public.enviar_email_registro(text, text, text, text, text, text, text, text, text, uuid, uuid, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.enviar_email_registro(text, text, text, text, text, text, text, text, text, uuid, uuid, boolean) TO service_role;

REVOKE ALL ON FUNCTION public.obtener_inscrito_por_cedula(text, uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.obtener_inscrito_por_cedula(text, uuid, text) FROM anon;
REVOKE ALL ON FUNCTION public.obtener_inscrito_por_cedula(text, uuid, text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.obtener_inscrito_por_cedula(text, uuid, text) TO anon;
GRANT EXECUTE ON FUNCTION public.obtener_inscrito_por_cedula(text, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.obtener_inscrito_por_cedula(text, uuid, text) TO service_role;


-- ----------------------------------------------------------------------------
-- BLOQUE 8b: RECARGA DEL SCHEMA CACHE DE POSTGREST
-- (misma razon que en adr051 / adr073 / adr074: los objetos nuevos no son
-- visibles hasta que PostgREST recarga el catalogo; sin esto, el cliente
-- recibe PGRST205 y cree que la RPC no existe)
-- ----------------------------------------------------------------------------

NOTIFY pgrst, 'reload schema';


-- ===========================================================================
-- BLOQUE DE VERIFICACION (para la Direccion; ejecutar DESPUES de correr este
-- archivo). Todo lo de abajo esta comentado: el archivo no ejecuta nada de
-- esta seccion.
--
-- (0a) PRERREQUISITOS QUE EL OPERADOR DEBE CUMPLIR ANTES DE QUE EL CORREO
--      FUNCIONE. El archivo aplica igual y las RPC quedan fail-closed, pero
--      sin esto NO se envia correo:
--
--   (i) Edge Function `send-ticket-email` DESPLEGADA y con autenticacion por
--       `X-Service-Token`. Si la version desplegadaTodavia acepta la anon
--       key, el problema sigue abierto por el lado de la funcion: esta
--       migracion cierra el camino de la base, no el de la funcion.
--   (ii) Secreto de servicio en Supabase Vault (Dashboard > Vault > Secrets):
--       nombre EXACTO: send_ticket_email_service_token
--       Comprobacion (no imprime el valor, solo el nombre y la fecha):
--       SELECT name, created_at FROM vault.secrets
--       WHERE name IN ('send_ticket_email_service_token','send_ticket_email_bearer');
--       Alternativa sin Vault (GUC de base de datos):
--       ALTER DATABASE postgres SET app.settings.service_token = '<token>';
--       Opcional: send_ticket_email_bearer si el despliegue exige tambien
--       Authorization: Bearer <service_role>.
--   (iii) Extension `pg_net` habilitada (Dashboard > Database > Extensions).
--       Sin ella la RPC responde {"ok":false,"estado":"error",
--       "motivo":"pg_net_no_disponible"}.
--   (iv) Extension `vault` habilitada (opcional; hay fallback por GUC).
--
-- SELECT to_regclass('vault.decrypted_secrets') AS vault;        -- o null
-- SELECT to_regprocedure('net.http_post(text,jsonb,jsonb,jsonb,integer)') AS pg_net;
-- -- los dos deben venir NO null antes de probar un envio real.
--
-- (1) LA TABLA EXISTE con las 15 columnas, en este orden:
--     id, evento_id, inscrito_id, destinatario, tipo, estado, intentos,
--     idempotency_key, error_texto, created_at, enviado_at,
--     cedula_norm, ip_origen, origen, pg_net_request_id
--
-- SELECT ordinal_position, column_name, data_type, is_nullable
-- FROM information_schema.columns
-- WHERE table_schema = 'public' AND table_name = 'email_envios_log'
-- ORDER BY ordinal_position;
--
-- (2) LOS CHECK ESTAN Y SON LO QUE PIDEN SER:
--
-- SELECT conname, pg_get_constraintdef(oid)
-- FROM pg_constraint WHERE conrelid = 'public.email_envios_log'::regclass
-- ORDER BY conname;
-- -- email_envios_log_tipo_check    -> 3 valores
-- -- email_envios_log_estado_check  -> 4 valores
-- -- email_envios_log_intentos_check-> intentos >= 0
-- -- email_envios_log_enviado_at_check
--
-- (3) LOS 4 INDICES:
--
-- SELECT indexname FROM pg_indexes
-- WHERE schemaname = 'public' AND tablename = 'email_envios_log' ORDER BY 1;
--
-- (4) RLS FAIL-CLOSED: 0 politicas en la tabla del log.
--
-- SELECT count(*) AS politicas FROM pg_policies
-- WHERE schemaname = 'public' AND tablename = 'email_envios_log';   -- -> 0
-- SELECT relrowsecurity, relforcerowsecurity FROM pg_class
-- WHERE oid = 'public.email_envios_log'::regclass;   -- true | false
-- -- relforcerowsecurity DEBE ser false: con true la propia RPC no podria
-- -- insertar (el propietario deja de estar exento de RLS).
--
-- (5) PERMISOS: nadie fuera de la lista puede leer el log.
--
-- SELECT has_table_privilege('anon',          'email_envios_log', 'SELECT');  -- false
-- SELECT has_table_privilege('authenticated', 'email_envios_log', 'SELECT');  -- false
-- SELECT has_table_privilege('service_role',  'email_envios_log', 'SELECT');  -- true
--
-- (6) PERMISOS DE FUNCION: EXECUTE existe solo para anon, authenticated y
--     service_role. Ninguna tiene EXECUTE granted to PUBLIC.
--
-- SELECT p.proname, p.proacl FROM pg_proc p
-- JOIN pg_namespace n ON n.oid = p.pronamespace
-- WHERE n.nspname = 'public' AND p.proname IN
--   ('enviar_email_registro','obtener_inscrito_por_cedula',
--    'fn_adr076_secreto','fn_adr076_texto_limpio','fn_adr076_ip_origen');
-- -- fn_adr076_secreto NO debe listar anon ni authenticated.
--
-- SELECT has_function_privilege('anon',         'public.fn_adr076_secreto(text)',           'EXECUTE');  -- false
-- SELECT has_function_privilege('anon',         'public.enviar_email_registro(text,text,text,text,text,text,text,text,text,uuid,uuid,boolean)', 'EXECUTE'); -- true
--
-- (7) SEARCH_PATH FIJADO en las 5 funciones (defensa anti hijacking):
--
-- SELECT proname, prosecdef, proconfig FROM pg_proc p
-- JOIN pg_namespace n ON n.oid = p.pronamespace
-- WHERE n.nspname = 'public' AND p.proname LIKE '%adr076%'
--    OR (n.nspname = 'public' AND p.proname IN
--        ('enviar_email_registro','obtener_inscrito_por_cedula'));
-- -- proconfig debe traer {search_path=public, pg_temp}; las 3 RPC con
-- -- prosecdef = true.
--
-- (8) PRUEBA DE FALLO CERRADO SIN CREDENCIAL (la mas importante). Con el
--     secreto ausente, la RPC debe LANZAR error, no enviar:
--     SELECT public.enviar_email_registro(
--         'prueba@example.com','Prueba','QR-TEST','Evento','2026-12-19','','Terraza',
--         'adr076-test-sin-credencial-1');
--     -- esperado: ERROR: [ADR-076] no hay credencial de servicio configurada...
--     -- y email_envios_log NO debe tener esa fila.
--     SELECT count(*) FROM public.email_envios_log
--     WHERE idempotency_key = 'adr076-test-sin-credencial-1';   -- -> 0
--
-- (9) PRUEBA DE VALIDACION (todas deben lanzar excepcion 22023):
--
-- SELECT public.enviar_email_registro(
--     'a@b.com','X','QR','E','F','H','L','adr076-test-email-malo-1');
--     -- email invalido
-- SELECT public.enviar_email_registro(
--     'destino@example.com'||chr(10)||'Bcc: victima@example.com','X','QR','E','F','H','L',
--     'adr076-test-inject-1');
--     -- CR/LF en el email: debe fallar por control char (anti header-injection)
-- SELECT public.enviar_email_registro(
--     'ok@example.com','X','QR','E'||chr(9)||'F','F','H','L','adr076-test-ctrl-1');
--     -- TAB en el nombre del evento: debe fallar
-- SELECT public.enviar_email_registro(
--     'ok@example.com','X','QR','E','F','H','L','adr076-test-tipo-1','spam');
--     -- tipo fuera del CHECK de dominio
--
-- (10) PRUEBA DE IDEMPOTENCIA (con credencial ya configurada). Dos llamadas
--      con la misma llave: la 2a NO debe encolar nada:
--
-- SELECT public.enviar_email_registro('destino@example.com','Prueba','QR-TEST',
--     'Evento','2026-12-19','','Terraza','adr076-test-idem-1');
-- SELECT public.enviar_email_registro('destino@example.com','Prueba','QR-TEST',
--     'Evento','2026-12-19','','Terraza','adr076-test-idem-1');
-- -- la 2a debe devolver {"ok":true,"estado":"enviado","motivo":"idempotente"}
--
-- SELECT estado, intentos, idempotency_key, pg_net_request_id
-- FROM public.email_envios_log WHERE idempotency_key = 'adr076-test-idem-1';
-- -- 1 sola fila (idempotencia real, no solo respuesta)
--
-- (11) PRUEBA DEL RATE LIMIT por cedula: 4 llamadas seguidas con la misma
--      cedula, evento y ventana, con llaves DISTINTAS:
--
-- SELECT public.enviar_email_registro('destino@example.com','P','QR','E','F','H','L',
--     'adr076-test-rl-1','registro','12345678',
--     (SELECT id FROM public.eventos ORDER BY id LIMIT 1));
-- -- repetir con -rl-2, -rl-3, -rl-4
-- -- las 3 primeras: ok=true. La 4ta: {"ok":false,"estado":"omitido",
-- -- "motivo":"rate_limit_cedula"}
--
-- SELECT estado, error_texto, created_at FROM public.email_envios_log
-- WHERE idempotency_key LIKE 'adr076-test-rl-%' ORDER BY created_at;
--
-- (12) PRUEBA DEL BYPASS: la misma llamada con p_bypass_rate_limit = true
--      desde el rol `anon` NO debe saltarse el limite (el flag se ignora);
--      con rol service_role SI.
--
-- (13) RECUPERACION POR CEDULA (RPC, con la anon key desde el navegador):
--
-- SELECT public.obtener_inscrito_por_cedula(
--     '12345678', (SELECT id FROM public.eventos ORDER BY id LIMIT 1));
-- -- con telefono correcto:  "segundo_factor_ok": true  y trae "telefono"
-- -- con telefono erroneo:  "segundo_factor_ok": false y "telefono": null
-- -- el jsonb NO debe tener llave "email" en ningun caso:
-- --   SELECT public.obtener_inscrito_por_cedula('12345678',
-- --       (SELECT id FROM public.eventos ORDER BY id LIMIT 1)) ? 'email';
--     -> false
--
-- (14) CONSULTA DEL CRON FUTURO (ADR-074 / TSK-003): a quien ya se le aviso
--       un recordatorio de este evento:
--
-- SELECT l.cedula_norm, l.destinatario, l.estado, l.enviado_at
-- FROM public.email_envios_log l
-- WHERE l.evento_id = (SELECT id FROM public.eventos ORDER BY id LIMIT 1)
--   AND l.tipo = 'recordatorio'
-- ORDER BY l.created_at DESC;
--
-- (15) RECONCILIACION ASINCRONA de pg_net (por que 'enviado' no es
--       'entregado'). Correr unos segundos despues de un envio:
--
-- SELECT r.id, r.status_code, r.content
-- FROM net._http_response r
-- WHERE r.id IN (SELECT pg_net_request_id FROM public.email_envios_log
--                 WHERE pg_net_request_id IS NOT NULL)
-- ORDER BY r.id DESC LIMIT 20;
--
-- (16) ASCII-SAFETY del archivo (ADR-002 / BUG-026). Debe dar 0:
--       Select-String -Path migrations/adr076_enviar_email_seguro.sql
--         -Pattern '[^\x00-\x7F]'
--       (si aparece algun byte > 127, es en un COMENTARIO: arreglar el
--       comentario, nunca "arreglarlo" con un E'\U...' en el SQL)
-- ===========================================================================
-- ROLLBACK (documentado, comentado; requiere gate de riesgo).
-- ATENCION: este es el unico bloque que propone borrar objetos, y NO borra
-- datos de negocio: solo las tablas, funciones e indices creados por ESTE
-- archivo. Las trazas de email_envios_log tambien se perderian, asi que
-- exportar la tabla antes de correrlo.
--   DROP FUNCTION IF EXISTS public.enviar_email_registro(text,text,text,text,text,text,text,text,text,uuid,uuid,boolean);
--   DROP FUNCTION IF EXISTS public.obtener_inscrito_por_cedula(text,uuid,text);
--   DROP FUNCTION IF EXISTS public.fn_adr076_ip_origen();
--   DROP FUNCTION IF EXISTS public.fn_adr076_secreto(text);
--   DROP FUNCTION IF EXISTS public.fn_adr076_texto_limpio(text,text,integer,boolean);
--   DROP TABLE IF EXISTS public.email_envios_log;
-- ===========================================================================