-- ===========================================================================
-- ADR-089 v1.2 - RECORDATORIOS MULTICANAL (WhatsApp Cloud API sobre pg_net)
-- ---------------------------------------------------------------------------
-- Fecha:   2026-11-01
-- Autor:   @sql-security
-- Estado:  PENDIENTE DE APLICAR - gate AGENTS.md seccion 2 autorizado por el
--          usuario el 2026-11-01. Este archivo NO se ha ejecutado contra la
--          base Supabase ctgyvydzshueemlelkzv.
-- ---------------------------------------------------------------------------
-- ESTADO INICIAL: fail-closed. El canal 'whatsapp' nace con activo=false y
-- dry_run=true. La ausencia de fila en canal_flags equivale a "sin
-- autorizacion": el emisor asume activo=false, dry_run=true. Nada se envia
-- hasta que operaciones haga el UPDATE de encendido (orden obligatorio:
-- F4 verde -> activo=true -> dry_run=false).
-- ---------------------------------------------------------------------------
-- BLOQUES (orden DDL obligatorio, criterio F1 #9):
--   0) guardas y extensiones
--   1) public.canal_flags            (interruptores por canal)
--   2) public.wa_plantillas          (catalogo de plantillas Meta)
--   3) public.recordatorio_reglas    (FK a wa_plantillas: por eso va despues)
--   4) public.wa_envios_log          (traza de auditoria, sin FKs)
--   4b) opt-in D5 en public.inscritos (aditivo: 4 columnas, sin tocar datos)
--   5) public.fn_wa_e164_co          (normalizacion de telefono CO)
--   6) public.fn_horas_recordatorio  (3 params + wrapper de 1 param)
--   7) public.fn_enviar_recordatorios_wa_pendientes
--   8) public.fn_wa_reconciliar_respuestas
--   9) backfill desde config_recordatorios (aditivo)
--  10) RLS fail-closed en las 4 tablas nuevas (+ GRANT explicito)
--  11) runner + job pg_cron 'recordatorios-wa'
--  12) NOTIFY pgrst + COMMIT
--  13) VERIFICACION comentada + ROLLBACK comentado
-- ---------------------------------------------------------------------------
-- GARANTIAS DE ESTE ARCHIVO:
--   * Idempotente: ejecutable dos veces seguidas sin error (IF NOT EXISTS,
--     CREATE OR REPLACE, ON CONFLICT DO NOTHING, guardas sobre pg_policies y
--     sobre cron.job).
--   * Cero Borrado: solo se agrega. config_recordatorios NO se modifica y sigue
--     siendo la fuente unica del canal email hasta F5. El unico cambio sobre
--     una tabla preexistente es ADITIVO: 4 columnas de opt-in en public.inscritos
--     (ADD COLUMN IF NOT EXISTS), sin reescribir ni borrar ninguna fila.
--   * ASCII puro: cero bytes fuera de 0x20-0x7E. Sin acentos, sin enie, sin
--     comillas tipograficas, sin guiones largos (ADR-002, BUG-026).
--   * NO contiene DROP, DELETE ni TRUNCATE de ningun tipo. Las politicas se
--     crean con DO + guarda sobre pg_policies en lugar de DROP POLICY.
-- ===========================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- BLOQUE 0: GUARDAS Y EXTENSIONES
-- ---------------------------------------------------------------------------
-- pg_cron lo necesita el job del bloque 11. pg_net no se crea aqui a proposito
-- (requiere privilegios que no corresponden a una migracion de datos); solo se
-- verifica su firma. Si no esta, el emisor registra 'pg_net_no_disponible' en
-- wa_envios_log en lugar de fallar en silencio.
CREATE EXTENSION IF NOT EXISTS pg_cron;

DO $guarda$
BEGIN
    IF to_regprocedure('net.http_post(text,jsonb,jsonb,jsonb,integer)') IS NULL THEN
        RAISE NOTICE '[INFO] ADR-089: pg_net NO disponible; el canal whatsapp registrara error pg_net_no_disponible hasta habilitarlo.';
    ELSE
        RAISE NOTICE '[INFO] ADR-089: pg_net disponible (net.http_post 5 args).';
    END IF;

    RAISE NOTICE '[INFO] ADR-089: el canal whatsapp nace fail-closed (activo=false, dry_run=true).';
END;
$guarda$;

-- ---------------------------------------------------------------------------
-- BLOQUE 1: public.canal_flags
-- ---------------------------------------------------------------------------
-- Un interruptor por canal. Fail-closed por diseno: si NO hay fila, el emisor
-- trata el canal como apagado y en dry-run. Por eso la semilla crea SOLO la
-- fila 'whatsapp' (criterio F1 #7): 'email' y 'sms' no tienen fila porque no
-- estan autorizados aun.
--
-- costo_unitario_usd queda NULL a proposito: la tarifa de Meta todavia no esta
-- cargada y NULL es la representacion honesta de "sin dato". No se usa para
-- bloquear envios; solo para reporteria cuando exista.
CREATE TABLE IF NOT EXISTS public.canal_flags (
    canal                   text PRIMARY KEY,
    activo                  boolean     NOT NULL DEFAULT false,
    dry_run                 boolean     NOT NULL DEFAULT true,
    requiere_optin          boolean     NOT NULL DEFAULT false,
    max_envios_por_corrida  integer     NOT NULL DEFAULT 50,
    max_envios_por_mes      integer     NOT NULL DEFAULT 500,
    alerta_porcentaje       integer     NOT NULL DEFAULT 80,
    costo_unitario_usd      numeric(10,5),
    motivo                  text,
    updated_at              timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT canal_flags_canal_chk CHECK (canal IN ('email','whatsapp','sms'))
);

COMMENT ON TABLE public.canal_flags IS
    'ADR-089: interruptores de envio por canal. Ausencia de fila = canal apagado y en dry_run (fail-closed).';

COMMENT ON COLUMN public.canal_flags.dry_run IS
    'true = renderiza y audita pero NUNCA llama a pg_net. El default es true.';

COMMENT ON COLUMN public.canal_flags.costo_unitario_usd IS
    'Tarifa unitaria informativa. NULL = tarifa sin cargar; no bloquea envios.';

-- Semilla idempotente. Sin filas para 'email' ni 'sms' (criterio F1 #7).
INSERT INTO public.canal_flags
    (canal, activo, dry_run, requiere_optin, max_envios_por_corrida, max_envios_por_mes, alerta_porcentaje)
VALUES
    ('whatsapp', false, true, false, 50, 500, 80)
ON CONFLICT (canal) DO NOTHING;

-- ---------------------------------------------------------------------------
-- BLOQUE 2: public.wa_plantillas
-- ---------------------------------------------------------------------------
-- Catalogo de plantillas aprobadas en Meta. Va ANTES de recordatorio_reglas
-- porque recordatorio_reglas.plantilla es FK a nombre_logico (criterio F1 #9).
--
-- variables es un array ORDENADO de jsonb porque Meta es POSICIONAL: el orden
-- del array es el orden de los parametros del body. Reordenarlo cambia el
-- mensaje que recibe el usuario.
CREATE TABLE IF NOT EXISTS public.wa_plantillas (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre_logico     text        NOT NULL UNIQUE,
    meta_template_id  text        UNIQUE,
    idioma            text        NOT NULL DEFAULT 'es_CO',
    categoria         text        NOT NULL DEFAULT 'UTILITY',
    variables         jsonb       NOT NULL DEFAULT '[]'::jsonb,
    preview           text,
    estado_meta       text        NOT NULL DEFAULT 'borrador',
    activo            boolean     NOT NULL DEFAULT true,
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT wa_plantillas_categoria_chk CHECK (categoria IN ('UTILITY','MARKETING','AUTHENTICATION')),
    CONSTRAINT wa_plantillas_estado_chk CHECK (estado_meta IN ('borrador','pendiente','aprobada','rechazada','pausada'))
);

COMMENT ON TABLE public.wa_plantillas IS
    'ADR-089: catalogo de plantillas de WhatsApp. estado_meta replica el estado en Meta, no lo decide la app.';

COMMENT ON COLUMN public.wa_plantillas.nombre_logico IS
    'CONTRATO EXTERNO con Meta: NO se renombra nunca. Si Meta exige otro nombre se crea una fila nueva y la vieja queda activo=false. Renombrar rompe recordatorio_reglas.plantilla y el historial de wa_envios_log.';

COMMENT ON COLUMN public.wa_plantillas.variables IS
    'Array jsonb ORDENADO: Meta es posicional, el orden ES el contrato del body.';

-- ---------------------------------------------------------------------------
-- BLOQUE 3: public.recordatorio_reglas
-- ---------------------------------------------------------------------------
-- Regla = "cuando" (horas_offset) + "con que" (plantilla) + "por que canal".
-- evento_id NULL = regla global (aplica a todo evento sin regla propia).
--
-- plantilla es TEXTO a proposito y con comportamiento referencial por defecto
-- (NO ACTION): prohibido ON UPDATE / ON DELETE CASCADE. Si se borrara una
-- plantilla en cascada se perderia la regla operativa sin rastro; y un rename
-- en cascada reescribiria historia. Se prefiere que la FK bloquee.
--
-- El muro NULL: un UNIQUE (evento_id, canal, tipo) NO impide duplicados
-- globales porque NULL nunca es igual a NULL. Por eso van DOS indices unicos
-- PARCIALES, uno por universo.
CREATE TABLE IF NOT EXISTS public.recordatorio_reglas (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    evento_id     text REFERENCES public.eventos(id) ON DELETE CASCADE,
    canal         text        NOT NULL,
    tipo          text        NOT NULL,
    horas_offset  integer     NOT NULL,
    plantilla     text REFERENCES public.wa_plantillas(nombre_logico),
    activo        boolean     NOT NULL DEFAULT true,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT recordatorio_reglas_canal_chk CHECK (canal IN ('email','whatsapp','sms')),
    CONSTRAINT recordatorio_reglas_tipo_chk CHECK (tipo IN ('anticipacion','dia_evento','post_evento')),
    CONSTRAINT recordatorio_reglas_offset_chk CHECK (
        (tipo = 'anticipacion' AND horas_offset > 0   AND horas_offset <= 720)
     OR (tipo = 'dia_evento'   AND horas_offset = 0)
     OR (tipo = 'post_evento'  AND horas_offset < 0   AND horas_offset >= -168)
    ),
    CONSTRAINT recordatorio_reglas_wa_plantilla_chk CHECK (canal <> 'whatsapp' OR plantilla IS NOT NULL)
);

COMMENT ON TABLE public.recordatorio_reglas IS
    'ADR-089: reglas de recordatorio por evento y por canal. evento_id NULL = regla global.';

COMMENT ON COLUMN public.recordatorio_reglas.plantilla IS
    'Nombre logico de wa_plantillas (texto, a proposito). NO se renombra: es contrato externo con Meta. FK por defecto (NO ACTION), nunca CASCADE.';

COMMENT ON COLUMN public.recordatorio_reglas.horas_offset IS
    'Horas relativas a eventos.evento_inicio. anticipacion: 1..720. dia_evento: 0. post_evento: -1..-168.';

-- Indices unicos PARCIALES: resuelven el muro NULL del UNIQUE compuesto.
CREATE UNIQUE INDEX IF NOT EXISTS recordatorio_reglas_ev_uq
    ON public.recordatorio_reglas (evento_id, canal, tipo)
    WHERE evento_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS recordatorio_reglas_global_uq
    ON public.recordatorio_reglas (canal, tipo)
    WHERE evento_id IS NULL;

CREATE INDEX IF NOT EXISTS recordatorio_reglas_canal_tipo_idx
    ON public.recordatorio_reglas (canal, tipo, activo);

-- ---------------------------------------------------------------------------
-- BLOQUE 4: public.wa_envios_log
-- ---------------------------------------------------------------------------
-- Traza de auditoria. SIN FKs a proposito:
--   * evento_id / inscrito_id: el log debe sobrevivir al borrado del evento o
--     del inscrito; la historia de un envio no se reescribe.
--   * plantilla: es la traza del nombre REALMENTE enviado. Si manana la
--     plantilla cambia de nombre, el log conserva el nombre viejo.
--
-- Unicidad SOLO por indice parcial: el dry-run persistido no debe bloquear la
-- reserva real de la misma clave (idempotency_key se repite entre el ensayo y
-- el envio real, y eso es correcto).
CREATE TABLE IF NOT EXISTS public.wa_envios_log (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    evento_id           text,
    inscrito_id         text,
    telefono_e164       text        NOT NULL,
    telefono_origen     text,
    entrega_estado      text,
    entrega_at          timestamptz,
    tipo                text        NOT NULL,
    canal               text        NOT NULL DEFAULT 'whatsapp',
    plantilla           text,
    estado              text        NOT NULL DEFAULT 'pendiente',
    intentos            integer     NOT NULL DEFAULT 0,
    idempotency_key     text        NOT NULL,
    wa_message_id       text,
    error_code          integer,
    error_texto         text,
    omitido_motivo      text,
    optin_observado     boolean,
    origen              text,
    pg_net_request_id   bigint,
    created_at          timestamptz NOT NULL DEFAULT now(),
    enviado_at          timestamptz,
    updated_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT wa_envios_log_estado_chk CHECK (estado IN ('pendiente','enviado','error','omitido'))
);

COMMENT ON TABLE public.wa_envios_log IS
    'ADR-089: bitacora de envios WhatsApp. Append-only para el cliente; la escriben las funciones SECURITY DEFINER.';

COMMENT ON COLUMN public.wa_envios_log.plantilla IS
    'Nombre de plantilla realmente enviado. Texto sin FK: es traza historica y no debe seguir renombres.';

COMMENT ON COLUMN public.wa_envios_log.omitido_motivo IS
    'Motivo de la omision (checkin_previo, sin_checkin, telefono_invalido, dry_run, ya_registrado). Toda omision se registra: nunca es invisible.';

COMMENT ON COLUMN public.wa_envios_log.pg_net_request_id IS
    'request_id devuelto por net.http_post. NULL en dry-run y tras un reintento (se limpia para permitir re-encolar).';

COMMENT ON COLUMN public.wa_envios_log.telefono_e164 IS
    'Telefono normalizado por fn_wa_e164_co. Cadena vacia solo en filas de omision sin numero valido (la columna es NOT NULL y la traza no se puede perder).';

-- Unicidad de idempotencia: SOLO por indice parcial (nunca UNIQUE de columna).
CREATE UNIQUE INDEX IF NOT EXISTS wa_envios_log_idem_uq
    ON public.wa_envios_log (idempotency_key)
    WHERE omitido_motivo IS DISTINCT FROM 'dry_run';

CREATE INDEX IF NOT EXISTS wa_envios_log_estado_idx
    ON public.wa_envios_log (estado);

CREATE INDEX IF NOT EXISTS wa_envios_log_req_idx
    ON public.wa_envios_log (pg_net_request_id);

CREATE INDEX IF NOT EXISTS wa_envios_log_ev_created_idx
    ON public.wa_envios_log (evento_id, created_at DESC);

-- ---------------------------------------------------------------------------
-- BLOQUE 4b: OPT-IN DIFERIDO (ADR-089 seccion 6, decision D5)
-- ---------------------------------------------------------------------------
-- El consentimiento se ata al acto de inscripcion, que es cuando se muestra el
-- checkbox, por eso vive en public.inscritos y no en una tabla aparte.
-- wa_optin_texto guarda la VERSION LITERAL mostrada, no una clave: si el texto
-- cambia, la evidencia vieja debe seguir siendo la que el titular acepto.
-- wa_optin_origen (landing | admin | import) distingue el consentimiento
-- capturado del importado: un opt-in cargado por un operador NO es
-- autorizacion del titular y no cuenta para la cobertura del 90 por ciento.
-- El bloqueo de envio por falta de opt-in sigue DIFERIDO: en F1-F5 el valor
-- solo se copia en wa_envios_log.optin_observado para medirlo.
-- Aditivo e idempotente: ADD COLUMN IF NOT EXISTS, sin tocar datos.
ALTER TABLE public.inscritos
    ADD COLUMN IF NOT EXISTS wa_optin        boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS wa_optin_at     timestamptz,
    ADD COLUMN IF NOT EXISTS wa_optin_origen text,
    ADD COLUMN IF NOT EXISTS wa_optin_texto  text;

COMMENT ON COLUMN public.inscritos.wa_optin IS
    'ADR-089 D5: consentimiento para notificaciones del evento por correo y WhatsApp. Nace false: un opt-in premarcado no es consentimiento.';
COMMENT ON COLUMN public.inscritos.wa_optin_texto IS
    'ADR-089: version literal del aviso aceptado. Si el texto cambia, este valor NO se reescribe: es la evidencia.';

-- ---------------------------------------------------------------------------
-- BLOQUE 5: public.fn_wa_e164_co
-- ---------------------------------------------------------------------------
-- Normaliza a E.164 colombiano. Devuelve NULL cuando no puede garantizar un
-- numero valido: NULL es "no enviar", nunca "enviar a lo que sea".
-- IMMUTABLE para poder usarla en expresiones e indices futuros.
CREATE OR REPLACE FUNCTION public.fn_wa_e164_co(p_raw text)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public, pg_temp
AS $fn$
DECLARE
    v_limpio  text;
    v_digitos text;
BEGIN
    IF p_raw IS NULL OR btrim(p_raw) = '' THEN
        RETURN NULL;
    END IF;

    -- 1) Fuera todo lo que no sea digito ni '+'.
    v_limpio := regexp_replace(p_raw, '[^0-9+]', '', 'g');

    IF v_limpio = '' THEN
        RETURN NULL;
    END IF;

    v_digitos := regexp_replace(v_limpio, '[^0-9]', '', 'g');

    -- 2) '+' explicito con 8..15 digitos: se devuelve canonico (un solo '+').
    IF left(v_limpio, 1) = '+' AND length(v_digitos) BETWEEN 8 AND 15 THEN
        RETURN '+' || v_digitos;
    END IF;

    -- 3) 12 digitos empezando en 57: ya trae el indicativo.
    IF length(v_digitos) = 12 AND left(v_digitos, 2) = '57' THEN
        RETURN '+' || v_digitos;
    END IF;

    -- 4) 10 digitos (celular 3xx o fijo): se antepone +57.
    IF length(v_digitos) = 10 THEN
        RETURN '+57' || v_digitos;
    END IF;

    -- 5) Cualquier otra forma: no se inventa un numero.
    RETURN NULL;
END;
$fn$;

COMMENT ON FUNCTION public.fn_wa_e164_co(text) IS
    'ADR-089: normaliza telefono colombiano a E.164. NULL = no convertible, por tanto no se envia.';

-- ---------------------------------------------------------------------------
-- BLOQUE 6: public.fn_horas_recordatorio
-- ---------------------------------------------------------------------------
-- (a) Version de 3 parametros: fuente nueva de verdad.
--     Prioridad: regla del evento -> regla global -> legado config_recordatorios
--     (solo para 'anticipacion'). Para tipos distintos de anticipacion, si no
--     hay regla devuelve NULL, y NULL significa "no enviar".
--     ORDER BY updated_at DESC, created_at ASC, id ASC = gana la ultima
--     decision del operador, con desempate estable.
-- (b) Wrapper de 1 parametro.
--     IMPORTANTE: agregar parametros con DEFAULT crea un OVERLOAD, no un
--     reemplazo. Si se dejara el body viejo (COALESCE directo sobre
--     config_recordatorios), el cron de adr078b seguiria llamando a la version
--     de 1 argumento y NUNCA veria recordatorio_reglas. Por eso la de 1
--     parametro se redefine como delegado explicito.
CREATE OR REPLACE FUNCTION public.fn_horas_recordatorio(
    p_evento_id text,
    p_canal     text DEFAULT 'email',
    p_tipo      text DEFAULT 'anticipacion'
)
RETURNS integer
LANGUAGE sql
STABLE
SET search_path = public, pg_temp
AS $fn$
    SELECT COALESCE(
        -- 1) regla del evento
        (SELECT r.horas_offset
           FROM public.recordatorio_reglas r
          WHERE r.activo
            AND r.canal = p_canal
            AND r.tipo  = p_tipo
            AND r.evento_id = p_evento_id
          ORDER BY r.updated_at DESC, r.created_at ASC, r.id ASC
          LIMIT 1),
        -- 2) regla global
        (SELECT r.horas_offset
           FROM public.recordatorio_reglas r
          WHERE r.activo
            AND r.canal = p_canal
            AND r.tipo  = p_tipo
            AND r.evento_id IS NULL
          ORDER BY r.updated_at DESC, r.created_at ASC, r.id ASC
          LIMIT 1),
        -- 3) legado: solo anticipacion cae a config_recordatorios.
        --    OJO: el resolver legado (adr074:352) NO filtra por activo, y este
        --    fallback debe devolver EXACTAMENTE lo mismo que antes de la
        --    migracion (criterio F1 #4). Filtrar por activo aqui seria una
        --    regresion silenciosa del cron de correo. El ORDER BY replica el
        --    total order del legado para que dos filas globales no devuelvan
        --    valores distintos en dos llamadas.
        CASE WHEN p_tipo = 'anticipacion' THEN
            COALESCE(
                (SELECT c.horas_anticipacion
                   FROM public.config_recordatorios c
                  WHERE c.evento_id = p_evento_id
                  ORDER BY c.updated_at DESC, c.created_at ASC, c.id ASC
                  LIMIT 1),
                (SELECT c.horas_anticipacion
                   FROM public.config_recordatorios c
                  WHERE c.evento_id IS NULL
                  ORDER BY c.updated_at DESC, c.created_at ASC, c.id ASC
                  LIMIT 1),
                56
            )
        ELSE NULL END
    );
$fn$;

COMMENT ON FUNCTION public.fn_horas_recordatorio(text, text, text) IS
    'ADR-089: horas de anticipacion por evento/canal/tipo. Regla del evento -> regla global -> legado email. NULL = no enviar.';

-- (b) Wrapper: misma firma que la version legada de adr074. Delega siempre.
CREATE OR REPLACE FUNCTION public.fn_horas_recordatorio(p_evento_id text)
RETURNS integer
LANGUAGE sql
STABLE
SET search_path = public, pg_temp
AS $fn$
    SELECT public.fn_horas_recordatorio($1, 'email', 'anticipacion');
$fn$;

COMMENT ON FUNCTION public.fn_horas_recordatorio(text) IS
    'ADR-089: wrapper legado. Delega en la version de 3 parametros (email/anticipacion). Prohibido devolverle el COALESCE directo: el cron de adr078b la sigue llamando.';

-- ---------------------------------------------------------------------------
-- BLOQUE 7: public.fn_enviar_recordatorios_wa_pendientes
-- ---------------------------------------------------------------------------
-- Emisor del canal WhatsApp. Contrato:
--   * Lock por canal (advisory) para que dos corridas no dupliquen envios.
--   * Fail-closed: sin fila en canal_flags = apagado y dry-run.
--   * dry-run NUNCA llama a pg_net.
--   * Toda omision se persiste (nunca invisible).
--   * Reserva recuperable: la clave de idempotencia se reserva antes de enviar
--     y solo se reintenta si quedo pendiente sin request_id y con intentos < 3.
--   * Esta funcion NO escribe wa_message_id: eso es del reconciliador.
CREATE OR REPLACE FUNCTION public.fn_enviar_recordatorios_wa_pendientes(
    p_dry_run            boolean DEFAULT NULL,
    p_max_envios         integer DEFAULT NULL,
    p_margen_minutos     integer DEFAULT 120,
    p_origen             text    DEFAULT 'cron',
    p_persistir_dry_run  boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
    v_cf          record;
    v_tpl         record;
    v_existente   record;
    c             record;
    v_activo      boolean := false;
    v_dry         boolean := true;
    v_max_corrida integer := 50;
    v_max_mes     integer := 500;
    v_alerta      integer := 80;
    v_mes         integer := 0;
    v_encolados   integer := 0;
    v_omitidos    integer := 0;
    v_errores     integer := 0;
    v_candidatos  integer := 0;
    v_reglas      integer := 0;
    v_motivos     jsonb   := '{}'::jsonb;
    v_muestra     jsonb   := '[]'::jsonb;
    v_persistido  boolean := false;
    v_skipped     text    := NULL;
    v_escribir    boolean := false;
    v_resultado   jsonb;
    v_token       text;
    v_url         text;
    v_headers     jsonb;
    v_body        jsonb;
    v_params      jsonb := '[]'::jsonb;
    v_map         jsonb;
    v_req         bigint;
    v_key         text;
    v_raw         text;
    v_tel         text;
    v_origen_dato text;
    v_motivo      text;
BEGIN
    -- Lock por canal: si otra corrida esta en curso, no se encola nada.
    IF NOT pg_try_advisory_lock(hashtext('canal:whatsapp')) THEN
        RETURN jsonb_build_object('skipped', 'en_curso');
    END IF;

    -- Todo el cuerpo va protegido para garantizar el unlock ante cualquier error.
    BEGIN
        <<cuerpo>>
        BEGIN
            -- (1) Flags del canal. Ausencia de fila = ausencia de autorizacion.
            SELECT * INTO v_cf FROM public.canal_flags WHERE canal = 'whatsapp';
            IF FOUND THEN
                v_activo      := COALESCE(v_cf.activo, false);
                v_dry         := COALESCE(v_cf.dry_run, true);
                v_max_corrida := COALESCE(v_cf.max_envios_por_corrida, 50);
                v_max_mes     := COALESCE(v_cf.max_envios_por_mes, 500);
                v_alerta      := COALESCE(v_cf.alerta_porcentaje, 80);
            ELSE
                v_activo      := false;
                v_dry         := true;
            END IF;

            -- Fail-safe duro (ADR-089 7.1): el flag de BD SOLO puede restringir,
            -- nunca ampliar. Por eso el dry-run efectivo es una OR, no un
            -- COALESCE: p_dry_run=true puede forzar dry-run aunque la tabla
            -- diga enviar, pero p_dry_run=false NUNCA puede convertir en envio
            -- real una fila con dry_run=true.
            v_dry := v_dry OR COALESCE(p_dry_run, false);

            -- Kill-switch. Con el canal apagado no se envia ni se escribe nada
            -- en una corrida normal (cron). Excepcion declarada: una peticion
            -- EXPLICITA de inspeccion (p_dry_run = true) si puede recorrer los
            -- candidatos, porque no toca la red ni escribe filas con
            -- p_persistir_dry_run=false. Sin esta excepcion, el criterio F3 del
            -- ADR (candidatos > 0 en dry-run) seria inejecutable, porque el
            -- canal nace con activo=false y 7.1.5 prohibe encenderlo antes de F4.
            IF NOT v_activo AND COALESCE(p_dry_run, false) = false THEN
                v_skipped := 'canal_apagado';
                EXIT cuerpo;
            END IF;

            -- (2) Techo mensual. Solo cuentan envios reales (dry_run no consume).
            SELECT count(*) INTO v_mes
              FROM public.wa_envios_log w
             WHERE w.canal = 'whatsapp'
               AND w.estado IN ('enviado','pendiente')
               AND w.omitido_motivo IS DISTINCT FROM 'dry_run'
               AND w.created_at >= date_trunc('month', now());

            IF v_max_mes > 0 AND v_mes >= (v_max_mes * v_alerta / 100) THEN
                RAISE WARNING '[INFO] ADR-089: consumo mensual whatsapp % de % (umbral alerta % por ciento).',
                    v_mes, v_max_mes, v_alerta;
            END IF;

            -- (3) Preparacion del envio real (solo si no es dry-run).
            IF NOT v_dry THEN
                v_token := public.fn_adr076_secreto('send_ticket_email_service_token');
                v_url := COALESCE(
                             nullif(btrim(current_setting('app.settings.functions_url', true)), ''),
                             'https://ctgyvydzshueemlelkzv.supabase.co/functions/v1/'
                         ) || 'send-wa-recordatorio';
                IF v_token IS NOT NULL THEN
                    v_headers := jsonb_build_object(
                        'Content-Type', 'application/json',
                        'X-Service-Token', v_token
                    );
                END IF;
            END IF;

            -- En dry-run sin persistencia no se escribe nada en el log.
            v_escribir := (NOT v_dry) OR p_persistir_dry_run;

            -- Universo de reglas activas del canal (solo reporteria).
            SELECT count(*) INTO v_reglas
              FROM public.recordatorio_reglas r
             WHERE r.canal = 'whatsapp' AND r.activo;

            -- (4) Candidatos. La regla del evento gana sobre la global
            -- (DISTINCT ON + ORDER BY sobre "es global").
            FOR c IN
                SELECT e.id                      AS evento_id,
                       e.nombre                  AS evento_nombre,
                       e.fecha                   AS evento_fecha,
                       e.hora                    AS evento_hora,
                       e.ubicacion               AS evento_ubicacion,
                       e.slug                    AS evento_slug,
                       i.id                      AS inscrito_id,
                       i.nombre                  AS inscrito_nombre,
                       i.cedula                  AS inscrito_cedula,
                       i.whatsapp                AS whatsapp,
                       i.telefono                AS telefono,
                       COALESCE(i.used, false)   AS usado,
                       COALESCE(i.wa_optin, false) AS optin,
                       ef.tipo                   AS tipo,
                       ef.horas_offset           AS horas_offset,
                       ef.plantilla              AS plantilla,
                       (e.evento_inicio - make_interval(hours => ef.horas_offset)) AS objetivo
                  FROM public.eventos e
                  JOIN (
                         SELECT DISTINCT ON (e2.id, r.tipo)
                                e2.id           AS evento_id,
                                r.tipo          AS tipo,
                                r.horas_offset  AS horas_offset,
                                r.plantilla     AS plantilla
                           FROM public.eventos e2
                           JOIN public.recordatorio_reglas r
                             ON r.canal = 'whatsapp'
                            AND r.activo
                            AND (r.evento_id = e2.id OR r.evento_id IS NULL)
                          ORDER BY e2.id, r.tipo, (r.evento_id IS NULL) ASC,
                                   r.updated_at DESC, r.created_at ASC, r.id ASC
                       ) ef ON ef.evento_id = e.id
                  JOIN public.inscritos i ON i.evento_id = e.id
                 WHERE e.evento_inicio IS NOT NULL
                   AND abs(now() - (e.evento_inicio - make_interval(hours => ef.horas_offset)))
                       <= p_margen_minutos * interval '1 minute'
                 ORDER BY objetivo ASC
                 LIMIT COALESCE(p_max_envios, v_max_corrida)
            LOOP
                v_candidatos := v_candidatos + 1;

                -- Techo mensual duro dentro de la corrida.
                IF v_max_mes > 0 AND (v_mes + v_encolados) >= v_max_mes THEN
                    v_skipped := 'techo_mensual';
                    EXIT cuerpo;
                END IF;

                -- (5) Normalizacion con DOS intentos: whatsapp y luego telefono.
                v_raw := public.fn_wa_e164_co(nullif(btrim(c.whatsapp), ''));
                v_origen_dato := 'whatsapp';
                IF v_raw IS NULL THEN
                    v_raw := public.fn_wa_e164_co(nullif(btrim(c.telefono), ''));
                    v_origen_dato := 'telefono';
                END IF;
                v_tel := v_raw;
                IF v_tel IS NULL THEN
                    v_origen_dato := 'invalido';
                END IF;

                -- (6) Reglas de negocio por tipo. Toda omision se registra.
                v_motivo := NULL;
                IF c.tipo = 'dia_evento' AND c.usado THEN
                    v_motivo := 'checkin_previo';
                ELSIF c.tipo = 'post_evento' AND NOT c.usado THEN
                    v_motivo := 'sin_checkin';
                ELSIF v_tel IS NULL THEN
                    v_motivo := 'telefono_invalido';
                END IF;

                IF v_motivo IS NOT NULL THEN
                    v_omitidos := v_omitidos + 1;
                    v_motivos := jsonb_set(
                        v_motivos,
                        ARRAY[v_motivo],
                        to_jsonb(COALESCE((v_motivos ->> v_motivo)::int, 0) + 1),
                        true
                    );

                    IF v_escribir THEN
                        INSERT INTO public.wa_envios_log
                            (evento_id, inscrito_id, telefono_e164, telefono_origen, tipo, canal,
                             plantilla, estado, intentos, idempotency_key, omitido_motivo,
                             optin_observado, origen)
                        VALUES
                            (c.evento_id, c.inscrito_id, COALESCE(v_tel, ''), v_origen_dato, c.tipo, 'whatsapp',
                             c.plantilla, 'omitido', 0,
                             'whatsapp:' || c.evento_id || ':' || c.inscrito_id || ':' || c.tipo,
                             CASE WHEN v_dry THEN 'dry_run' ELSE v_motivo END,
                             c.optin, p_origen)
                        ON CONFLICT (idempotency_key) WHERE omitido_motivo IS DISTINCT FROM 'dry_run'
                        DO NOTHING;
                    END IF;

                    CONTINUE;
                END IF;

                -- (7) Plantilla vigente.
                SELECT p.nombre_logico, p.idioma, p.variables
                  INTO v_tpl
                  FROM public.wa_plantillas p
                 WHERE p.nombre_logico = c.plantilla
                   AND p.activo
                 LIMIT 1;

                IF NOT FOUND THEN
                    v_errores := v_errores + 1;
                    v_motivos := jsonb_set(
                        v_motivos,
                        ARRAY['plantilla_ausente'],
                        to_jsonb(COALESCE((v_motivos ->> 'plantilla_ausente')::int, 0) + 1),
                        true
                    );
                    IF v_escribir THEN
                        INSERT INTO public.wa_envios_log
                            (evento_id, inscrito_id, telefono_e164, telefono_origen, tipo, canal,
                             plantilla, estado, intentos, idempotency_key, error_texto,
                             optin_observado, origen)
                        VALUES
                            (c.evento_id, c.inscrito_id, COALESCE(v_tel, ''), v_origen_dato, c.tipo, 'whatsapp',
                             c.plantilla, 'error', 0,
                             'whatsapp:' || c.evento_id || ':' || c.inscrito_id || ':' || c.tipo,
                             'plantilla_ausente', c.optin, p_origen)
                        ON CONFLICT (idempotency_key) WHERE omitido_motivo IS DISTINCT FROM 'dry_run'
                        DO NOTHING;
                    END IF;
                    CONTINUE;
                END IF;

                -- (8) Clave de idempotencia: un mensaje por evento/inscrito/tipo.
                v_key := 'whatsapp:' || c.evento_id || ':' || c.inscrito_id || ':' || c.tipo;

                -- (9) Parametros posicionales de la plantilla (Meta es posicional).
                IF jsonb_typeof(v_tpl.variables) <> 'array' THEN
                    v_params := '[]'::jsonb;
                ELSE
                    v_map := jsonb_build_object(
                        'nombre',     COALESCE(c.inscrito_nombre, ''),
                        'cedula',     COALESCE(c.inscrito_cedula, ''),
                        'evento',     COALESCE(c.evento_nombre, ''),
                        'fecha',      COALESCE(c.evento_fecha::text, ''),
                        'hora',       COALESCE(c.evento_hora::text, ''),
                        'fecha_hora', COALESCE(btrim(COALESCE(c.evento_fecha::text, '') || ' ' || COALESCE(c.evento_hora::text, '')), ''),
                        'ubicacion',  COALESCE(c.evento_ubicacion, ''),
                        'slug',       COALESCE(c.evento_slug, ''),
                        'link',       CASE WHEN COALESCE(c.evento_slug, '') <> ''
                                          THEN 'https://taquilladirecta.com/evento.html?slug=' || c.evento_slug
                                          ELSE '' END,
                        'codigo',     COALESCE(c.inscrito_id, '')
                    );
                    SELECT COALESCE(jsonb_agg(
                               jsonb_build_object(
                                   'type', 'text',
                                   'text', COALESCE(
                                       v_map ->> COALESCE(t.elem #>> '{name}', t.elem #>> '{}'),
                                       ''
                                   )
                               ) ORDER BY t.ord
                           ), '[]'::jsonb)
                      INTO v_params
                      FROM jsonb_array_elements(v_tpl.variables) WITH ORDINALITY AS t(elem, ord);
                END IF;

                -- (10) Body del POST. El token va SOLO en el header.
                v_body := jsonb_build_object(
                    'idempotencyKey', v_key,
                    'to', v_tel,
                    'template', jsonb_build_object(
                        'name', v_tpl.nombre_logico,
                        'language', jsonb_build_object('code', v_tpl.idioma),
                        'components', jsonb_build_array(
                            jsonb_build_object('type', 'body', 'parameters', v_params)
                        )
                    ),
                    'meta', jsonb_build_object(
                        'eventoId', c.evento_id,
                        'inscritoId', c.inscrito_id,
                        'tipo', c.tipo
                    )
                );

                -- (11) Dry-run: nunca se llama a pg_net y nunca se reserva.
                IF v_dry THEN
                    v_omitidos := v_omitidos + 1;
                    v_motivos := jsonb_set(
                        v_motivos,
                        ARRAY['dry_run'],
                        to_jsonb(COALESCE((v_motivos ->> 'dry_run')::int, 0) + 1),
                        true
                    );

                    IF p_persistir_dry_run THEN
                        INSERT INTO public.wa_envios_log
                            (evento_id, inscrito_id, telefono_e164, telefono_origen, tipo, canal,
                             plantilla, estado, intentos, idempotency_key, omitido_motivo,
                             optin_observado, origen, pg_net_request_id)
                        VALUES
                            (c.evento_id, c.inscrito_id, v_tel, v_origen_dato, c.tipo, 'whatsapp',
                             v_tpl.nombre_logico, 'omitido', 0, v_key, 'dry_run',
                             c.optin, p_origen, NULL)
                        ON CONFLICT (idempotency_key) WHERE omitido_motivo IS DISTINCT FROM 'dry_run'
                        DO NOTHING;
                        v_persistido := true;
                    ELSIF jsonb_array_length(v_muestra) < 5 THEN
                        v_muestra := v_muestra || jsonb_build_array(v_body);
                    END IF;

                    CONTINUE;
                END IF;

                -- (12) Reserva recuperable: se toma la clave antes de enviar.
                INSERT INTO public.wa_envios_log
                    (evento_id, inscrito_id, telefono_e164, telefono_origen, tipo, canal,
                     plantilla, estado, intentos, idempotency_key, optin_observado, origen)
                VALUES
                    (c.evento_id, c.inscrito_id, v_tel, v_origen_dato, c.tipo, 'whatsapp',
                     v_tpl.nombre_logico, 'pendiente', 0, v_key,
                     c.optin, p_origen)
                ON CONFLICT (idempotency_key) WHERE omitido_motivo IS DISTINCT FROM 'dry_run'
                DO NOTHING;

                IF NOT FOUND THEN
                    -- Ya existe: solo se reintenta si quedo pendiente sin request_id
                    -- y con menos de 3 intentos. Cualquier otro estado es definitivo.
                    SELECT w.estado, w.intentos, w.pg_net_request_id
                      INTO v_existente
                      FROM public.wa_envios_log w
                     WHERE w.idempotency_key = v_key
                       AND w.omitido_motivo IS DISTINCT FROM 'dry_run'
                     ORDER BY w.created_at DESC
                     LIMIT 1;

                    IF NOT (v_existente.estado = 'pendiente'
                            AND v_existente.pg_net_request_id IS NULL
                            AND COALESCE(v_existente.intentos, 0) < 3) THEN
                        v_omitidos := v_omitidos + 1;
                        v_motivos := jsonb_set(
                            v_motivos,
                            ARRAY['ya_registrado'],
                            to_jsonb(COALESCE((v_motivos ->> 'ya_registrado')::int, 0) + 1),
                            true
                        );
                        CONTINUE;
                    END IF;
                END IF;

                -- (13) Envio. Sin secreto o sin pg_net no se envia: se marca error.
                IF v_token IS NULL THEN
                    v_errores := v_errores + 1;
                    UPDATE public.wa_envios_log
                       SET estado = 'error',
                           error_texto = 'sin_secreto',
                           updated_at = now()
                     WHERE idempotency_key = v_key
                       AND omitido_motivo IS DISTINCT FROM 'dry_run';
                    CONTINUE;
                END IF;

                IF to_regprocedure('net.http_post(text,jsonb,jsonb,jsonb,integer)') IS NULL THEN
                    v_errores := v_errores + 1;
                    UPDATE public.wa_envios_log
                       SET estado = 'error',
                           error_texto = 'pg_net_no_disponible',
                           updated_at = now()
                     WHERE idempotency_key = v_key
                       AND omitido_motivo IS DISTINCT FROM 'dry_run';
                    CONTINUE;
                END IF;

                BEGIN
                    v_req := net.http_post(v_url, v_body, '{}'::jsonb, v_headers, 10000);

                    -- Nada mas: wa_message_id lo escribe el reconciliador.
                    UPDATE public.wa_envios_log
                       SET pg_net_request_id = v_req,
                           intentos = intentos + 1,
                           updated_at = now()
                     WHERE idempotency_key = v_key
                       AND omitido_motivo IS DISTINCT FROM 'dry_run';

                    v_encolados := v_encolados + 1;
                EXCEPTION WHEN OTHERS THEN
                    -- El token NUNCA se escribe en error_texto.
                    v_errores := v_errores + 1;
                    UPDATE public.wa_envios_log
                       SET estado = 'error',
                           error_texto = 'pg_net_encolado_fallo',
                           updated_at = now()
                     WHERE idempotency_key = v_key
                       AND omitido_motivo IS DISTINCT FROM 'dry_run';
                END;
            END LOOP;

            v_resultado := jsonb_build_object(
                'dry_run', v_dry,
                'persistido', v_persistido,
                'reglas', v_reglas,
                'candidatos', v_candidatos,
                'encolados', v_encolados,
                'omitidos', v_omitidos,
                'omitidos_por_motivo', v_motivos,
                'errores', v_errores,
                'muestra', CASE WHEN v_dry AND NOT p_persistir_dry_run THEN v_muestra ELSE NULL END,
                'skipped', v_skipped
            );
        END cuerpo;
    EXCEPTION WHEN OTHERS THEN
        PERFORM pg_advisory_unlock(hashtext('canal:whatsapp'));
        RAISE;
    END;

    PERFORM pg_advisory_unlock(hashtext('canal:whatsapp'));

    IF v_resultado IS NULL THEN
        v_resultado := jsonb_build_object(
            'dry_run', v_dry,
            'persistido', v_persistido,
            'reglas', v_reglas,
            'candidatos', v_candidatos,
            'encolados', v_encolados,
            'omitidos', v_omitidos,
            'omitidos_por_motivo', v_motivos,
            'errores', v_errores,
            'muestra', NULL,
            'skipped', v_skipped
        );
    END IF;

    RETURN v_resultado;
END;
$fn$;

COMMENT ON FUNCTION public.fn_enviar_recordatorios_wa_pendientes(boolean, integer, integer, text, boolean) IS
    'ADR-089: emisor WhatsApp. Fail-closed, dry-run sin pg_net, reserva recuperable y omisiones siempre auditadas.';

-- Solo el proceso programado (owner) la corre.
REVOKE ALL ON FUNCTION public.fn_enviar_recordatorios_wa_pendientes(boolean, integer, integer, text, boolean) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_enviar_recordatorios_wa_pendientes(boolean, integer, integer, text, boolean) TO service_role;

-- ---------------------------------------------------------------------------
-- BLOQUE 8: public.fn_wa_reconciliar_respuestas
-- ---------------------------------------------------------------------------
-- UNICO escritor de wa_message_id, error_code, error_texto, enviado_at y del
-- incremento de intentos por abandono. El emisor solo encola.
-- Corre ANTES del emisor en cada corrida porque net._http_response se purga:
-- si no se lee a tiempo, la respuesta se pierde y el envio queda huerfano.
CREATE OR REPLACE FUNCTION public.fn_wa_reconciliar_respuestas()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
    v_reconciliadas integer := 0;
    v_enviados      integer := 0;
    v_omitidos_dry  integer := 0;
    v_errores       integer := 0;
    v_sin_respuesta integer := 0;
    v_status        integer;
    v_code          integer;
    v_msg_id        text;
    v_dry_flag      boolean;
    w               record;
    a               record;
BEGIN
    -- Sin la tabla interna de pg_net no se puede reconciliar: fallar ruidosamente,
    -- nunca en silencio (un silencio aqui deja envios "pendiente" para siempre).
    IF to_regclass('net._http_response') IS NULL THEN
        RAISE EXCEPTION '[ADR-089] net._http_response no existe: pg_net no esta instalado o no expone su tabla interna. Reconciliacion imposible.';
    END IF;

    -- (1) Filas con respuesta disponible.
    FOR w IN
        SELECT w2.id,
               w2.estado,
               w2.intentos,
               w2.idempotency_key,
               r2.status_code,
               r2.content,
               r2.timed_out,
               r2.error_msg
          FROM public.wa_envios_log w2
          JOIN net._http_response r2 ON r2.id = w2.pg_net_request_id
         WHERE w2.canal = 'whatsapp'
           AND w2.estado IN ('pendiente','enviado')
           AND w2.pg_net_request_id IS NOT NULL
    LOOP
        v_reconciliadas := v_reconciliadas + 1;
        v_status := w.status_code;

        IF w.timed_out THEN
            -- Timeout: se trata como respuesta fallida reintentable.
            UPDATE public.wa_envios_log
               SET estado = CASE WHEN intentos + 1 >= 3 THEN 'error' ELSE 'pendiente' END,
                   intentos = intentos + 1,
                   pg_net_request_id = CASE WHEN intentos + 1 >= 3 THEN pg_net_request_id ELSE NULL END,
                   error_texto = CASE WHEN intentos + 1 >= 3 THEN 'timeout_pg_net' ELSE 'reintento_timeout' END,
                   updated_at = now()
             WHERE id = w.id;

            IF w.intentos + 1 >= 3 THEN
                v_errores := v_errores + 1;
            END IF;
            CONTINUE;
        END IF;

        IF v_status BETWEEN 200 AND 299 THEN
            v_dry_flag := NULL;
            v_msg_id := NULL;

            BEGIN
                IF w.content IS NOT NULL AND btrim(w.content) <> '' THEN
                    v_dry_flag := (w.content::jsonb ->> 'dryRun')::boolean;
                    v_msg_id := w.content::jsonb ->> 'messageId';
                END IF;
            EXCEPTION WHEN OTHERS THEN
                v_dry_flag := NULL;
                v_msg_id := NULL;
            END;

            IF v_dry_flag IS TRUE THEN
                UPDATE public.wa_envios_log
                   SET estado = 'omitido',
                       omitido_motivo = 'dry_run',
                       updated_at = now()
                 WHERE id = w.id;
                v_omitidos_dry := v_omitidos_dry + 1;
            ELSIF v_msg_id IS NOT NULL THEN
                UPDATE public.wa_envios_log
                   SET estado = 'enviado',
                       wa_message_id = v_msg_id,
                       enviado_at = now(),
                       error_code = NULL,
                       error_texto = NULL,
                       updated_at = now()
                 WHERE id = w.id;
                v_enviados := v_enviados + 1;
            ELSE
                -- 2xx sin messageId: no es exito verificable.
                UPDATE public.wa_envios_log
                   SET estado = 'error',
                       error_texto = 'respuesta_sin_message_id',
                       updated_at = now()
                 WHERE id = w.id;
                v_errores := v_errores + 1;
            END IF;

            CONTINUE;
        END IF;

        IF v_status BETWEEN 400 AND 599 THEN
            v_code := NULL;
            BEGIN
                IF w.content IS NOT NULL AND btrim(w.content) <> '' THEN
                    v_code := nullif(w.content::jsonb #>> '{error,code}', '')::int;
                END IF;
            EXCEPTION WHEN OTHERS THEN
                v_code := NULL;
            END;

            IF v_code = 131026 THEN
                -- Numero sin WhatsApp: terminal, no se reintenta.
                UPDATE public.wa_envios_log
                   SET estado = 'omitido',
                       omitido_motivo = 'numero_no_whatsapp',
                       error_code = v_code,
                       error_texto = 'numero_no_whatsapp',
                       updated_at = now()
                 WHERE id = w.id;
                v_errores := v_errores + 1;

            ELSIF v_code IN (132000, 132001, 131047) THEN
                -- Errores de plantilla/ventana: terminal, no se reintenta.
                UPDATE public.wa_envios_log
                   SET estado = 'error',
                       error_code = v_code,
                       error_texto = 'error_terminal_' || v_code::text,
                       updated_at = now()
                 WHERE id = w.id;
                v_errores := v_errores + 1;

            ELSIF v_code IN (429, 130429, 131056) THEN
                -- Rate limit: reintentable. Se limpia pg_net_request_id para que
                -- el emisor pueda re-encolar (net._http_response ya se consumio).
                UPDATE public.wa_envios_log
                   SET estado = CASE WHEN intentos + 1 >= 3 THEN 'error' ELSE 'pendiente' END,
                       intentos = intentos + 1,
                       pg_net_request_id = CASE WHEN intentos + 1 >= 3 THEN pg_net_request_id ELSE NULL END,
                       error_code = v_code,
                       error_texto = CASE WHEN intentos + 1 >= 3 THEN 'reintentos_agotados' ELSE 'reintento_rate_limit' END,
                       updated_at = now()
                 WHERE id = w.id;

                IF w.intentos + 1 >= 3 THEN
                    v_errores := v_errores + 1;
                END IF;

            ELSIF v_code = 190 THEN
                -- Token invalido: se apaga el canal en la MISMA transaccion.
                UPDATE public.wa_envios_log
                   SET estado = 'error',
                       error_code = v_code,
                       error_texto = 'error_190_token',
                       updated_at = now()
                 WHERE id = w.id;
                v_errores := v_errores + 1;

                UPDATE public.canal_flags
                   SET activo = false,
                       dry_run = true,
                       motivo = 'error 190 token',
                       updated_at = now()
                 WHERE canal = 'whatsapp';

                RAISE WARNING '[INFO] ADR-089: error 190 de Meta. Canal whatsapp apagado (activo=false, dry_run=true).';

            ELSIF v_status >= 500 THEN
                -- 5xx: reintentable.
                UPDATE public.wa_envios_log
                   SET estado = CASE WHEN intentos + 1 >= 3 THEN 'error' ELSE 'pendiente' END,
                       intentos = intentos + 1,
                       pg_net_request_id = CASE WHEN intentos + 1 >= 3 THEN pg_net_request_id ELSE NULL END,
                       error_code = v_code,
                       error_texto = CASE WHEN intentos + 1 >= 3 THEN 'reintentos_agotados' ELSE 'reintento_5xx' END,
                       updated_at = now()
                 WHERE id = w.id;

                IF w.intentos + 1 >= 3 THEN
                    v_errores := v_errores + 1;
                END IF;

            ELSE
                -- 4xx no clasificado: terminal.
                UPDATE public.wa_envios_log
                   SET estado = 'error',
                       error_code = v_code,
                       error_texto = 'error_4xx_' || v_status::text,
                       updated_at = now()
                 WHERE id = w.id;
                v_errores := v_errores + 1;
            END IF;

            CONTINUE;
        END IF;

        -- 1xx/3xx u otros: no se toca, se resuelve por la via de abandono.
        RAISE WARNING '[INFO] ADR-089: respuesta con status % no manejado para la clave % (fila %).',
            v_status, w.idempotency_key, w.id;
    END LOOP;

    -- (2) Abandono: pendientes sin respuesta y con 3 intentos.
    FOR a IN
        SELECT w2.id, w2.intentos
          FROM public.wa_envios_log w2
         WHERE w2.canal = 'whatsapp'
           AND w2.estado = 'pendiente'
           AND w2.intentos >= 3
           AND (w2.pg_net_request_id IS NULL
                OR NOT EXISTS (SELECT 1 FROM net._http_response r2 WHERE r2.id = w2.pg_net_request_id))
    LOOP
        UPDATE public.wa_envios_log
           SET estado = 'error',
               error_texto = 'sin_respuesta_pg_net',
               updated_at = now()
         WHERE id = a.id;

        v_sin_respuesta := v_sin_respuesta + 1;
    END LOOP;

    -- Nota: estado='error' NUNCA se reintenta automaticamente. Requiere
    -- intervencion humana y, si procede, un UPDATE manual de la clave.

    RETURN jsonb_build_object(
        'reconciliadas', v_reconciliadas,
        'enviados', v_enviados,
        'omitidos_dry_run', v_omitidos_dry,
        'errores', v_errores,
        'sin_respuesta', v_sin_respuesta
    );
END;
$fn$;

COMMENT ON FUNCTION public.fn_wa_reconciliar_respuestas() IS
    'ADR-089: unico escritor de wa_message_id/error/enviado_at. Traduce respuestas de pg_net a estados del log.';

REVOKE ALL ON FUNCTION public.fn_wa_reconciliar_respuestas() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_wa_reconciliar_respuestas() TO service_role;

-- ---------------------------------------------------------------------------
-- BLOQUE 9: BACKFILL DESDE config_recordatorios
-- ---------------------------------------------------------------------------
-- Aditivo (Cero Borrado). config_recordatorios NO se modifica: sigue siendo la
-- fuente unica del canal email hasta F5, y fn_horas_recordatorio la consulta
-- como ultimo recurso.
--
-- IS NOT DISTINCT FROM es OBLIGATORIO: con '=' la fila global (evento_id NULL)
-- nunca coincide con NULL y se duplicaria en cada corrida.
INSERT INTO public.recordatorio_reglas (evento_id, canal, tipo, horas_offset, activo)
SELECT c.evento_id,
       'email',
       'anticipacion',
       c.horas_anticipacion,
       c.activo
  FROM public.config_recordatorios c
 WHERE NOT EXISTS (
         SELECT 1
           FROM public.recordatorio_reglas r
          WHERE r.canal = 'email'
            AND r.tipo = 'anticipacion'
            AND r.evento_id IS NOT DISTINCT FROM c.evento_id
       );

DO $backfill$
DECLARE
    v_reglas integer;
    v_config integer;
BEGIN
    SELECT count(*) INTO v_reglas FROM public.recordatorio_reglas WHERE canal = 'email' AND tipo = 'anticipacion';
    SELECT count(*) INTO v_config FROM public.config_recordatorios;
    RAISE NOTICE '[INFO] ADR-089: backfill email/anticipacion reglas=% config=% (deben coincidir; segunda corrida no debe sumar).', v_reglas, v_config;
END;
$backfill$;

-- ---------------------------------------------------------------------------
-- BLOQUE 10: RLS FAIL-CLOSED EN LAS 4 TABLAS NUEVAS
-- ---------------------------------------------------------------------------
-- RLS habilitado SIN FORCE: el owner (postgres) y las funciones SECURITY
-- DEFINER siguen operando; el cliente queda sujeto a las politicas.
-- Politicas con DO + guarda sobre pg_policies: PROHIBIDO DROP POLICY.
ALTER TABLE public.canal_flags        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wa_plantillas      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recordatorio_reglas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wa_envios_log      ENABLE ROW LEVEL SECURITY;

DO $rls$
BEGIN
    -- canal_flags
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'canal_flags' AND policyname = 'canal_flags_select_auth') THEN
        EXECUTE 'CREATE POLICY canal_flags_select_auth ON public.canal_flags FOR SELECT TO authenticated USING (true)';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'canal_flags' AND policyname = 'canal_flags_write_master') THEN
        EXECUTE 'CREATE POLICY canal_flags_write_master ON public.canal_flags FOR ALL TO authenticated USING (public.is_master_org_user()) WITH CHECK (public.is_master_org_user())';
    END IF;

    -- wa_plantillas
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'wa_plantillas' AND policyname = 'wa_plantillas_select_auth') THEN
        EXECUTE 'CREATE POLICY wa_plantillas_select_auth ON public.wa_plantillas FOR SELECT TO authenticated USING (true)';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'wa_plantillas' AND policyname = 'wa_plantillas_write_master') THEN
        EXECUTE 'CREATE POLICY wa_plantillas_write_master ON public.wa_plantillas FOR ALL TO authenticated USING (public.is_master_org_user()) WITH CHECK (public.is_master_org_user())';
    END IF;

    -- recordatorio_reglas
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'recordatorio_reglas' AND policyname = 'recordatorio_reglas_select_auth') THEN
        EXECUTE 'CREATE POLICY recordatorio_reglas_select_auth ON public.recordatorio_reglas FOR SELECT TO authenticated USING (true)';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'recordatorio_reglas' AND policyname = 'recordatorio_reglas_write_master') THEN
        EXECUTE 'CREATE POLICY recordatorio_reglas_write_master ON public.recordatorio_reglas FOR ALL TO authenticated USING (public.is_master_org_user()) WITH CHECK (public.is_master_org_user())';
    END IF;

    -- wa_envios_log: append-only para el cliente (SELECT + INSERT, sin UPDATE ni DELETE).
    -- Las escrituras de estado las hacen las funciones SECURITY DEFINER.
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'wa_envios_log' AND policyname = 'wa_envios_log_select_auth') THEN
        EXECUTE 'CREATE POLICY wa_envios_log_select_auth ON public.wa_envios_log FOR SELECT TO authenticated USING (true)';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'wa_envios_log' AND policyname = 'wa_envios_log_insert_master') THEN
        EXECUTE 'CREATE POLICY wa_envios_log_insert_master ON public.wa_envios_log FOR INSERT TO authenticated WITH CHECK (public.is_master_org_user())';
    END IF;

    RAISE NOTICE '[INFO] ADR-089: RLS fail-closed aplicado en canal_flags, wa_plantillas, recordatorio_reglas y wa_envios_log.';
END;
$rls$;

-- anon no tiene nada que hacer en el dominio de recordatorios.
REVOKE ALL ON TABLE public.canal_flags         FROM anon;
REVOKE ALL ON TABLE public.wa_plantillas       FROM anon;
REVOKE ALL ON TABLE public.recordatorio_reglas FROM anon;
REVOKE ALL ON TABLE public.wa_envios_log       FROM anon;

-- Una politica RLS no concede privilegios por si sola: sin GRANT, el panel
-- recibe 42501 aunque la politica permita. Se conceden explicitamente los
-- minimos. wa_envios_log es APPEND-ONLY para el cliente: SELECT + INSERT, sin
-- UPDATE ni DELETE (los estados los escriben las funciones SECURITY DEFINER).
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.canal_flags         TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.wa_plantillas       TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.recordatorio_reglas TO authenticated;
GRANT SELECT, INSERT                 ON TABLE public.wa_envios_log       TO authenticated;

-- ---------------------------------------------------------------------------
-- BLOQUE 11: JOB DE CRON
-- ---------------------------------------------------------------------------
-- Reconciliador PRIMERO, emisor despues, cada hora a los 10 minutos.
-- El reconciliador corre siempre porque net._http_response se purga: la
-- respuesta hay que leerla antes de que desaparezca.
--
-- El canal nace APAGADO: el job existe pero no envia nada hasta que operaciones
-- haga el UPDATE de encendido (orden obligatorio: F4 verde -> activo=true ->
-- dry_run=false). Esto es deliberado: un job activo con canal apagado es mas
-- seguro que un canal encendido esperando un job.
--
-- Por que un runner y no dos sentencias en el comando del job: el comando de
-- pg_cron es una sola cadena y su fallo se ve en cron.job_run_details, no en la
-- respuesta. Con un runner, la corrida devuelve UN jsonb con las dos partes
-- (reconciliacion + envio) y el historial del job queda legible. Si el
-- reconciliador lanza excepcion (pg_net sin su tabla interna), la corrida
-- falla RUIDOSAMENTE, que es el comportamiento exigido en el ADR 3.8.
CREATE OR REPLACE FUNCTION public.fn_wa_corrida_programada()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
    v_rec jsonb;
    v_env jsonb;
BEGIN
    v_rec := public.fn_wa_reconciliar_respuestas();
    v_env := public.fn_enviar_recordatorios_wa_pendientes();

    RETURN jsonb_build_object(
        'reconciliacion', v_rec,
        'envio',          v_env,
        'run_at',         now()
    );
END;
$fn$;

COMMENT ON FUNCTION public.fn_wa_corrida_programada() IS
    'ADR-089: runner del job recordatorios-wa. Reconcilia lo viejo y despues encola lo nuevo, en una sola corrida auditable.';

REVOKE ALL ON FUNCTION public.fn_wa_corrida_programada() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_wa_corrida_programada() TO service_role;

DO $cron$
BEGIN
    IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'recordatorios-wa') THEN
        PERFORM cron.unschedule('recordatorios-wa');
        RAISE NOTICE '[INFO] ADR-089: job previo "recordatorios-wa" desprogramado para reprogramar.';
    END IF;

    PERFORM cron.schedule(
        'recordatorios-wa',
        '10 * * * *',
        $job$SELECT public.fn_wa_corrida_programada();$job$
    );

    RAISE NOTICE '[INFO] ADR-089: job "recordatorios-wa" programado (10 * * * *). Canal whatsapp sigue apagado por flags.';
END;
$cron$;

-- ---------------------------------------------------------------------------
-- BLOQUE 12: RECARGA DEL SCHEMA CACHE DE POSTGREST
-- ---------------------------------------------------------------------------
NOTIFY pgrst, 'reload schema';

COMMIT;

-- ===========================================================================
-- BLOQUE 13: VERIFICACION (todo comentado; NO se ejecuta aqui)
-- ===========================================================================
-- Criterios F1 del ADR-089 v1.2.
--
-- (F1 #1) Doble ejecucion sin error: aplicar el archivo completo dos veces
--         seguidas. La segunda corrida no debe lanzar ningun error.
--
-- (F1 #2) Backfill 0 en la segunda corrida (no duplica):
-- SELECT count(*) AS reglas_email
--   FROM public.recordatorio_reglas
--  WHERE canal = 'email' AND tipo = 'anticipacion';
-- -- debe ser igual a:
-- SELECT count(*) AS config FROM public.config_recordatorios;
-- -- y NO debe crecer tras la segunda ejecucion.
--
-- (F1 #3) Duplicado rechazado con 23505 (indices unicos parciales):
-- INSERT INTO public.recordatorio_reglas (evento_id, canal, tipo, horas_offset)
-- VALUES (NULL, 'email', 'anticipacion', 48);  -- si ya existe la global: 23505
--
-- (F1 #4) Regresion de la firma de 1 argumento (el cron de adr078b la llama asi):
-- SELECT public.fn_horas_recordatorio('cualquier-slug');
-- -- debe devolver un integer (o NULL), nunca error de funcion inexistente.
--
-- (F1 #5) El wrapper delega y NO contiene COALESCE:
-- SELECT pg_get_functiondef('public.fn_horas_recordatorio(text)'::regprocedure);
-- -- debe contener: SELECT public.fn_horas_recordatorio($1, 'email', 'anticipacion');
-- -- NO debe contener: COALESCE
--
-- (F1 #6) La version de 3 parametros existe:
-- SELECT to_regprocedure('public.fn_horas_recordatorio(text,text,text)');
-- -- no debe ser NULL
--
-- (F1 #7) Estado inicial fail-closed y ausencia de filas email/sms:
-- SELECT canal, activo, dry_run, requiere_optin, max_envios_por_corrida,
--        max_envios_por_mes, alerta_porcentaje, costo_unitario_usd
--   FROM public.canal_flags ORDER BY canal;
-- -- esperado: exactamente una fila, canal='whatsapp', activo=false, dry_run=true,
-- -- costo_unitario_usd IS NULL. Cero filas para 'email' y 'sms'.
--
-- (F1 #8) Unicidad por indice PARCIAL en el log (no UNIQUE de columna):
-- SELECT indexname, indexdef FROM pg_indexes
--  WHERE schemaname = 'public' AND tablename = 'wa_envios_log'
--  ORDER BY indexname;
-- -- debe aparecer: wa_envios_log_idem_uq ... UNIQUE ... (idempotency_key)
-- --                WHERE (omitido_motivo IS DISTINCT FROM 'dry_run'::text)
-- -- equivalente en psql: \d public.wa_envios_log
--
-- (F1 #9) Orden DDL: wa_plantillas debe existir antes de recordatorio_reglas.
-- SELECT to_regclass('public.wa_plantillas'), to_regclass('public.recordatorio_reglas');
-- -- ambas no NULL; y la FK debe apuntar a nombre_logico:
-- SELECT conname, pg_get_constraintdef(oid)
--   FROM pg_constraint
--  WHERE conrelid = 'public.recordatorio_reglas'::regclass AND contype = 'f';
-- -- la FK de plantilla debe decir: FOREIGN KEY (plantilla) REFERENCES wa_plantillas(nombre_logico)
-- -- sin ON UPDATE / ON DELETE CASCADE.
--
-- EXTRA - RLS efectivo (4 tablas, sin FORCE):
-- SELECT tablename, rowsecurity FROM pg_tables
--  WHERE schemaname = 'public'
--    AND tablename IN ('canal_flags','wa_plantillas','recordatorio_reglas','wa_envios_log');
-- SELECT tablename, policyname, cmd, roles FROM pg_policies
--  WHERE schemaname = 'public'
--    AND tablename IN ('canal_flags','wa_plantillas','recordatorio_reglas','wa_envios_log')
--  ORDER BY tablename, policyname;
--
-- EXTRA - job de cron:
-- SELECT jobid, schedule, jobname, active FROM cron.job WHERE jobname = 'recordatorios-wa';
--
-- EXTRA - dry-run manual de INSPECCION (p_dry_run=true). Con el canal apagado
--         la corrida normal devuelve skipped=canal_apagado; la peticion
--         explicita de dry-run si recorre candidatos y no escribe filas:
-- SELECT public.fn_enviar_recordatorios_wa_pendientes(true, 5, 120, 'manual', false);
-- -- esperado: dry_run=true, persistido=false, candidatos >= 0, encolados=0,
-- --           muestra con payloads (telefono en E.164 y link con slug), 0 filas
-- --           nuevas en wa_envios_log y 0 filas nuevas en net._http_response.
--
-- EXTRA - dry-run PERSISTIDO (observabilidad programada, ADR 3.7.11):
-- SELECT public.fn_enviar_recordatorios_wa_pendientes(true, 5, 120, 'manual', true);
-- -- esperado: filas estado='omitido', omitido_motivo='dry_run',
-- --           pg_net_request_id IS NULL. Y una reserva real con la MISMA
-- --           idempotency_key NO debe chocar (indice parcial): probar con un
-- --           INSERT ... estado='pendiente' de esa clave -> debe pasar.
--
-- EXTRA - corrida normal con el canal apagado (debe no hacer nada):
-- SELECT public.fn_enviar_recordatorios_wa_pendientes();
-- -- esperado: skipped='canal_apagado'.
--
-- EXTRA - runner del job (reconcilia y luego envia):
-- SELECT public.fn_wa_corrida_programada();
--
-- EXTRA - opt-in D5 presente en inscritos:
-- SELECT column_name, data_type, is_nullable, column_default
--   FROM information_schema.columns
--  WHERE table_schema='public' AND table_name='inscritos'
--    AND column_name LIKE 'wa_optin%'
--  ORDER BY column_name;
--
-- EXTRA - reconciliador (no debe fallar con pg_net instalado):
-- SELECT public.fn_wa_reconciliar_respuestas();
--
-- ---------------------------------------------------------------------------
-- ROLLBACK (comentado; NO ejecutar sin autorizacion explicita)
-- ---------------------------------------------------------------------------
-- Este archivo NO contiene DROP, DELETE ni TRUNCATE. La reversion operativa es
-- logica y por flags, en este orden:
--   1) UPDATE public.canal_flags SET activo = false, dry_run = true,
--          motivo = 'rollback ADR-089', updated_at = now() WHERE canal = 'whatsapp';
--   2) SELECT cron.unschedule('recordatorios-wa');   -- desactiva el job
--   3) Las 4 tablas nuevas y las funciones se DEJAN en su lugar: no hay datos
--      previos que restaurar (todo es aditivo) y el Cero Borrado prohibe
--      eliminar historia de auditoria (wa_envios_log).
-- Si en el futuro se decidiera retirar fisicamente el esquema, eso seria una
-- migracion nueva y autorizada, nunca una reversion en caliente de este archivo.
--
-- ===========================================================================
-- FIN ADR-089 v1.2
-- ===========================================================================
