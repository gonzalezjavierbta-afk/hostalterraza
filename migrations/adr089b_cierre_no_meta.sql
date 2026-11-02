-- ===========================================================================
-- ADR-089b - CIERRE DE LO QUE NO DEPENDE DE META
--            (CHECK de formato, vista F6, retencion de dry-run, RPC de estados)
-- ---------------------------------------------------------------------------
-- Fecha:   2026-11-02
-- Autor:   @sql-security
-- Base:    migrations/adr089_recordatorios_multicanal.sql YA APLICADA en
--          produccion. Este archivo es ADITIVO sobre ese estado: no redefine
--          tablas, no reescribe filas y no toca config_recordatorios.
-- Estado:  PENDIENTE DE APLICAR. Lo aplica el usuario A MANO en el proyecto
--          Supabase ctgyvydzshueemlelkzv. Aqui NO se ejecuto nada.
-- ---------------------------------------------------------------------------
-- PROPOSITO: cerrar las piezas del canal WhatsApp que NO dependen de Meta ni
-- del Edge Function:
--   BLOQUE 1  CHECK de formato en public.wa_plantillas (nombre_logico, idioma).
--   BLOQUE 2  Vista public.v_wa_resumen_diario (observabilidad F6).
--   BLOQUE 3  public.fn_wa_limpiar_dry_run (retencion del dry-run persistido).
--   BLOQUE 4  public.fn_wa_estado_meta (RPC del webhook de estados, F6).
-- ---------------------------------------------------------------------------
-- NO INCLUYE (a proposito):
--   * El corte del canal email (F5): config_recordatorios sigue siendo la
--     fuente unica del correo. Aqui no se modifica.
--   * El provisioning de Meta (app, tokens, WABA, aprobacion de plantillas):
--     es operacion externa, no esquema.
--   * El Edge Function que invoca la RPC del bloque 4: aqui solo se expone.
-- ---------------------------------------------------------------------------
-- GARANTIAS:
--   * ADITIVO: el unico DELETE del archivo vive DENTRO de la funcion de
--     retencion (bloque 3) y solo alcanza filas de dry-run. El unico UPDATE
--     vive DENTRO de la RPC (bloque 4), se limita a entrega_estado,
--     entrega_at, error_code y updated_at, y solo toca la fila cuyo
--     wa_message_id coincide. Ni una sentencia suelta toca datos.
--   * IDEMPOTENTE: ejecutable dos veces seguidas sin error (CREATE OR REPLACE,
--     IF NOT EXISTS, guardas sobre pg_constraint).
--   * ASCII puro (ADR-002, BUG-026): cero bytes fuera de 0x20-0x7E.
--   * Cero DROP, cero TRUNCATE, cero ALTER COLUMN.
-- ---------------------------------------------------------------------------
-- ORDEN DE EJECUCION: 0 -> 1 -> 2 -> 3 -> 4 en una sola transaccion
-- (BEGIN/COMMIT). Si el bloque 1 aborta, nada se aplica: es deliberado.
-- ===========================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- BLOQUE 0: GUARDAS DE PRECONDICION
-- ---------------------------------------------------------------------------
-- Este archivo asume ADR-089 aplicada. Si falta una tabla base, se aborta con
-- un mensaje legible en lugar de fallar mas abajo con "relation does not exist".
DO $guarda$
BEGIN
    IF to_regclass('public.wa_plantillas') IS NULL
       OR to_regclass('public.wa_envios_log') IS NULL
       OR to_regclass('public.canal_flags') IS NULL THEN
        RAISE EXCEPTION '[ADR-089b] faltan tablas base de ADR-089 (wa_plantillas / wa_envios_log / canal_flags). Aplicar primero migrations/adr089_recordatorios_multicanal.sql.';
    END IF;

    -- security_invoker en vistas exige PG 15+. Sin esta guarda el error seria
    -- "unrecognized parameter security_invoker", que no dice nada util.
    IF current_setting('server_version_num')::integer < 150000 THEN
        RAISE EXCEPTION '[ADR-089b] se requiere PostgreSQL 15 o superior: la vista usa WITH (security_invoker = true). Version actual: %', current_setting('server_version');
    END IF;

    RAISE NOTICE '[INFO] ADR-089b: precondiciones OK (tablas base presentes, PG >= 15).';
END;
$guarda$;

-- ---------------------------------------------------------------------------
-- BLOQUE 1: CHECK DE FORMATO EN public.wa_plantillas
-- ---------------------------------------------------------------------------
-- Meta solo acepta [a-z0-9_] en el nombre de plantilla (minusculas, sin
-- espacios, sin acentos, sin guiones). Un nombre fuera de ese alfabeto se
-- aprueba en el panel y despues falla en el envio: el peor momento posible.
--
-- PROHIBIDO CORREGIR DATOS EN SILENCIO: nombre_logico es destino de una FK
-- TEXTUAL (recordatorio_reglas.plantilla) y llave de trazabilidad en
-- wa_envios_log. Un rename automatico rompe la regla operativa sin avisar y
-- deja historia huerfana. Si hay filas infractoras se aborta con el conteo y
-- hasta 5 nombres para que operaciones decida (fila nueva, vieja activo=false).
DO $guarda$
DECLARE
    v_total   integer;
    v_muestra text;
BEGIN
    SELECT count(*) INTO v_total
      FROM public.wa_plantillas
     WHERE nombre_logico !~ '^[a-z0-9_]{1,120}$';

    IF v_total > 0 THEN
        SELECT string_agg(s.nombre_logico, ', ' ORDER BY s.nombre_logico)
          INTO v_muestra
          FROM (SELECT p.nombre_logico
                  FROM public.wa_plantillas p
                 WHERE p.nombre_logico !~ '^[a-z0-9_]{1,120}$'
                 ORDER BY p.nombre_logico
                 LIMIT 5) s;

        RAISE EXCEPTION '[ADR-089b] wa_plantillas: % fila(s) violan ^[a-z0-9_]{1,120}$. NO se corrigen en silencio (romperian recordatorio_reglas.plantilla). Nombres (max 5): %', v_total, v_muestra;
    END IF;

    RAISE NOTICE '[INFO] ADR-089b: wa_plantillas.nombre_logico sin infracciones.';
END;
$guarda$;

DO $guarda$
BEGIN
    IF NOT EXISTS (
        SELECT 1
          FROM pg_constraint c
         WHERE c.conname = 'wa_plantillas_nombre_logico_chk'
           AND c.conrelid = 'public.wa_plantillas'::regclass
    ) THEN
        ALTER TABLE public.wa_plantillas
            ADD CONSTRAINT wa_plantillas_nombre_logico_chk
            CHECK (nombre_logico ~ '^[a-z0-9_]{1,120}$');
        RAISE NOTICE '[INFO] ADR-089b: constraint "wa_plantillas_nombre_logico_chk" creado.';
    ELSE
        RAISE NOTICE '[INFO] ADR-089b: constraint "wa_plantillas_nombre_logico_chk" ya existe, skip.';
    END IF;
END;
$guarda$;

COMMENT ON CONSTRAINT wa_plantillas_nombre_logico_chk ON public.wa_plantillas IS
    'ADR-089b: Meta exige [a-z0-9_] (1..120) en el nombre de plantilla. Renombrar NO se hace con UPDATE: se crea una fila nueva y la vieja queda activo=false, porque nombre_logico es contrato externo con Meta y destino de la FK recordatorio_reglas.plantilla.';

-- Idioma: BCP-47 corto, p.ej. es_CO, es, en_US. Meta rechaza variantes que no
-- sigan ese patron, y el default 'es_CO' de la tabla ya cumple.
DO $guarda$
DECLARE
    v_total   integer;
    v_muestra text;
BEGIN
    SELECT count(*) INTO v_total
      FROM public.wa_plantillas
     WHERE idioma !~ '^[a-z]{2,3}(_[A-Z]{2})?$';

    IF v_total > 0 THEN
        SELECT string_agg(s.idioma, ', ' ORDER BY s.idioma)
          INTO v_muestra
          FROM (SELECT p.idioma
                  FROM public.wa_plantillas p
                 WHERE p.idioma !~ '^[a-z]{2,3}(_[A-Z]{2})?$'
                 ORDER BY p.idioma
                 LIMIT 5) s;

        RAISE EXCEPTION '[ADR-089b] wa_plantillas: % fila(s) violan ^[a-z]{2,3}(_[A-Z]{2})?$. NO se corrigen en silencio (el idioma enviado a Meta debe ser el real). Idiomas (max 5): %', v_total, v_muestra;
    END IF;

    RAISE NOTICE '[INFO] ADR-089b: wa_plantillas.idioma sin infracciones.';
END;
$guarda$;

DO $guarda$
BEGIN
    IF NOT EXISTS (
        SELECT 1
          FROM pg_constraint c
         WHERE c.conname = 'wa_plantillas_idioma_chk'
           AND c.conrelid = 'public.wa_plantillas'::regclass
    ) THEN
        ALTER TABLE public.wa_plantillas
            ADD CONSTRAINT wa_plantillas_idioma_chk
            CHECK (idioma ~ '^[a-z]{2,3}(_[A-Z]{2})?$');
        RAISE NOTICE '[INFO] ADR-089b: constraint "wa_plantillas_idioma_chk" creado.';
    ELSE
        RAISE NOTICE '[INFO] ADR-089b: constraint "wa_plantillas_idioma_chk" ya existe, skip.';
    END IF;
END;
$guarda$;

COMMENT ON CONSTRAINT wa_plantillas_idioma_chk ON public.wa_plantillas IS
    'ADR-089b: idioma en formato BCP-47 corto (es_CO, es, en_US). Meta empareja plantilla + idioma: un idioma mal escrito hace que el envio falle con plantilla "no encontrada".';

-- ---------------------------------------------------------------------------
-- BLOQUE 2: VISTA public.v_wa_resumen_diario (OBSERVABILIDAD F6)
-- ---------------------------------------------------------------------------
-- Grano: un dia por tipo y plantilla. Sirve para responder "que paso ayer" sin
-- abrir la bitacora cruda.
--
-- security_invoker = true: la vista NO es un bypass de RLS, corre con los
-- privilegios y las politicas de quien consulta (wa_envios_log tiene RLS
-- fail-closed). Si se creara sin la opcion, correria como owner y anularia la
-- RLS: exactamente lo que no se quiere.
--
-- El dia se corta en hora de Colombia (America/Bogota), no en UTC: un envio de
-- las 21:00 en Bogota cae en el dia anterior si se corta en UTC, y la
-- operacion leeria dos dias distintos para la misma jornada.
--
-- COSTO: si canal_flags.costo_unitario_usd es NULL, la columna devuelve NULL.
-- NUNCA 0: 0 significaria "gratis" y seria una mentira contable. El CASE es
-- explicito (no se confia en que NULL * n = NULL) para que nadie lo rompa
-- metiendo un COALESCE mas adelante.
--
-- Un solo LEFT JOIN a canal_flags (PK = canal, una fila). Sin subconsulta por
-- fila. El join exige w.canal = 'whatsapp' para no cobrar tarifa de WhatsApp a
-- una fila de otro canal.
CREATE OR REPLACE VIEW public.v_wa_resumen_diario
WITH (security_invoker = true) AS
SELECT
    (w.created_at AT TIME ZONE 'America/Bogota')::date               AS dia,
    w.tipo,
    w.plantilla,
    count(*)                                                         AS total,
    count(*) FILTER (WHERE w.estado = 'pendiente')                    AS pendientes,
    count(*) FILTER (WHERE w.estado = 'enviado')                      AS enviados,
    count(*) FILTER (WHERE w.estado = 'error')                        AS errores,
    count(*) FILTER (WHERE w.estado = 'omitido')                      AS omitidos,
    count(*) FILTER (WHERE w.omitido_motivo = 'dry_run')              AS omitidos_dry_run,
    count(*) FILTER (WHERE w.omitido_motivo = 'telefono_invalido')    AS omitidos_telefono,
    count(*) FILTER (WHERE w.wa_message_id IS NOT NULL)               AS con_message_id,
    count(*) FILTER (WHERE w.entrega_estado IN ('delivered','read'))  AS entregados,
    count(*) FILTER (WHERE w.entrega_estado = 'read')                 AS leidos,
    count(*) FILTER (WHERE w.entrega_estado = 'failed')               AS fallidos_entrega,
    min(w.created_at)                                                 AS primer_envio,
    max(w.updated_at)                                                 AS ultimo_envio,
    CASE
        WHEN cf.costo_unitario_usd IS NULL THEN NULL
        ELSE (count(*) FILTER (WHERE w.estado = 'enviado'))::numeric
             * cf.costo_unitario_usd
             -- Cast explicito del agregado antes de multiplicar: numeric *
             -- numeric, sin promociones implicitas de bigint.
    END                                                               AS costo_estimado_usd
  FROM public.wa_envios_log w
  LEFT JOIN public.canal_flags cf
         ON cf.canal = 'whatsapp'
        AND w.canal = 'whatsapp'
 GROUP BY (w.created_at AT TIME ZONE 'America/Bogota')::date,
          w.tipo,
          w.plantilla,
          cf.costo_unitario_usd;

COMMENT ON VIEW public.v_wa_resumen_diario IS
    'ADR-089b: vista de observabilidad F6 del canal WhatsApp, grano dia/tipo/plantilla. security_invoker: aplica la RLS de wa_envios_log al que consulta. NULL en costo_estimado_usd = tarifa sin cargar en canal_flags (nunca 0: 0 significaria gratis).';

-- anon no tiene nada que ver en la operacion de recordatorios.
REVOKE ALL ON TABLE public.v_wa_resumen_diario FROM anon;

-- SELECT para authenticated: la RLS de la vista la aplican las politicas de
-- wa_envios_log y canal_flags (ambas ya tienen SELECT para authenticated).
GRANT SELECT ON TABLE public.v_wa_resumen_diario TO authenticated;

-- ---------------------------------------------------------------------------
-- BLOQUE 3: RETENCION DEL DRY-RUN PERSISTIDO
-- ---------------------------------------------------------------------------
-- El dry-run persistido es el UNICO dato que se purga de todo el dominio.
-- Razon: existe para observabilidad de corto plazo (ver que se habria enviado)
-- y crece una fila por candidato y por corrida; si no se poda, compite con la
-- historia real. wa_envios_log con envios reales NO se poda nunca (Cero
-- Borrado: es la evidencia de lo que se envio y a quien).
--
-- Guarda p_dias >= 7: evita que un error de tipeo (0, 1, 2) borre el dry-run
-- de la semana en curso. p_dias NULL se rechaza explicitamente porque
-- "NULL < 7" es NULL y el IF no dispararia.
CREATE OR REPLACE FUNCTION public.fn_wa_limpiar_dry_run(p_dias integer DEFAULT 30)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
    v_borradas integer := 0;
BEGIN
    IF p_dias IS NULL THEN
        RAISE EXCEPTION '[ADR-089b] fn_wa_limpiar_dry_run: p_dias no puede ser NULL (usar el default 30).';
    END IF;

    IF p_dias < 7 THEN
        RAISE EXCEPTION '[ADR-089b] fn_wa_limpiar_dry_run: p_dias=% por debajo del minimo 7. Retencion abortada para no borrar el dry-run reciente.', p_dias;
    END IF;

    -- Triple filtro obligatorio: solo omitidas, solo por dry_run, solo viejas.
    -- Cualquier otro estado o motivo (envios reales, omisiones por telefono
    -- invalido) queda intacto.
    DELETE FROM public.wa_envios_log
     WHERE estado = 'omitido'
       AND omitido_motivo = 'dry_run'
       AND created_at < now() - ((p_dias::text) || ' days')::interval;

    GET DIAGNOSTICS v_borradas = ROW_COUNT;
    RETURN v_borradas;
END;
$fn$;

COMMENT ON FUNCTION public.fn_wa_limpiar_dry_run(integer) IS
    'ADR-089b: purga filas de dry-run persistido (estado=omitido, omitido_motivo=dry_run) mas viejas que p_dias (minimo 7, default 30). Es el UNICO dato del dominio que se poda: el dry-run es observabilidad de corto plazo y crece por corrida; la historia de envios reales no se borra nunca. Devuelve el numero de filas eliminadas.';

REVOKE ALL ON FUNCTION public.fn_wa_limpiar_dry_run(integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_wa_limpiar_dry_run(integer) TO service_role;

-- ---------------------------------------------------------------------------
-- OPCIONAL (no se ejecuta): programacion diaria de la retencion.
-- ---------------------------------------------------------------------------
-- El job NO se crea en esta migracion. Activarlo es decision de operaciones y
-- debe hacerse despues de ver la primera corrida manual. Se deja la sentencia
-- lista para copiar, descomentada, en el editor SQL:
--
-- SELECT cron.schedule(
--     'recordatorios-wa-retencion',
--     '20 4 * * *',
--     'SELECT public.fn_wa_limpiar_dry_run(30);'
-- );
--
-- Para desactivarlo sin borrar nada de la tabla:
-- SELECT cron.unschedule('recordatorios-wa-retencion');
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- BLOQUE 4: RPC DEL WEBHOOK DE ESTADOS (F6)
-- ---------------------------------------------------------------------------
-- La invoca el Edge Function por PostgREST con la service role key. anon y
-- authenticated NO pueden ejecutarla: si pudieran, cualquiera marcaria
-- mensajes como "leido" o "entregado" y la reporteria seria ficcion.
--
-- Contrato de robustez: NUNCA lanza excepcion por datos del webhook (Meta
-- reintenta ante 5xx y un payload raro no debe tumbar la fila de eventos).
-- Toda validacion devuelve jsonb con ok=false y un reason.
--
-- IDEMPOTENCIA Y ORDEN: los estados solo AVANZAN (sent < delivered < read).
-- El WHERE lo hace explicito, no se confia en el orden de llegada:
--   * 'sent'      aplica solo si entrega_estado IS NULL.
--   * 'delivered' aplica sobre NULL o 'sent'.
--   * 'read'      aplica sobre NULL, 'sent' o 'delivered'.
--   * 'failed'    aplica sobre NULL, 'sent' o 'delivered' (nunca sobre 'read':
--                 un read ya implica entrega). 'failed' y 'read' son ambos
--                 terminales: ninguno pisa al otro.
-- Un estado repetido (mismo valor que el actual) es no-op: no reescribe
-- entrega_at. Asi el reenvio del mismo webhook no mueve la evidencia.
--
-- NO se tocan estado, intentos, wa_message_id ni idempotency_key: eso es
-- propiedad del emisor y del reconciliador. Aqui solo se escribe el tramo de
-- entrega (entrega_estado, entrega_at, error_code) y updated_at.
CREATE OR REPLACE FUNCTION public.fn_wa_estado_meta(
    p_message_id text,
    p_estado     text,
    p_at         timestamptz DEFAULT now(),
    p_error_code integer     DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
    v_msg_id   text;
    v_estado   text;
    v_at       timestamptz;
    v_filas    integer := 0;
    v_actual   text;
BEGIN
    v_msg_id := btrim(COALESCE(p_message_id, ''));

    IF v_msg_id = '' THEN
        RETURN jsonb_build_object('ok', false, 'reason', 'message_id_invalido');
    END IF;

    -- Normalizacion defensiva: Meta manda minusculas, pero un proxy o un
    -- reintento manual puede mandar 'READ' o ' read '.
    v_estado := lower(btrim(COALESCE(p_estado, '')));

    IF v_estado NOT IN ('sent', 'delivered', 'read', 'failed') THEN
        RETURN jsonb_build_object('ok', false, 'reason', 'estado_invalido');
    END IF;

    -- p_at viene de Meta y es la evidencia temporal del evento. Solo se cae a
    -- now() si llega NULL (dato ausente), nunca por comodidad.
    v_at := COALESCE(p_at, now());

    UPDATE public.wa_envios_log w
       SET entrega_estado = v_estado,
           entrega_at     = v_at,
           error_code     = CASE
                                WHEN v_estado = 'failed'
                                    THEN COALESCE(p_error_code, w.error_code)
                                ELSE w.error_code
                            END,
           updated_at     = now()
     WHERE w.wa_message_id = v_msg_id
       AND (
                (v_estado = 'sent'
                     AND w.entrega_estado IS NULL)
             OR (v_estado = 'delivered'
                     AND (w.entrega_estado IS NULL OR w.entrega_estado = 'sent'))
             OR (v_estado = 'read'
                     AND (w.entrega_estado IS NULL
                          OR w.entrega_estado IN ('sent', 'delivered')))
             OR (v_estado = 'failed'
                     AND (w.entrega_estado IS NULL
                          OR w.entrega_estado IN ('sent', 'delivered')))
           );

    GET DIAGNOSTICS v_filas = ROW_COUNT;

    -- Se reporta el estado que QUEDO, no el que llego: si un 'delivered'
    -- tardio se ignora porque ya habia 'read', la respuesta lo dice.
    SELECT w.entrega_estado
      INTO v_actual
      FROM public.wa_envios_log w
     WHERE w.wa_message_id = v_msg_id
     ORDER BY w.created_at DESC, w.id DESC
     LIMIT 1;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('ok', false, 'reason', 'no_encontrado');
    END IF;

    RETURN jsonb_build_object(
        'ok',      true,
        'updated', v_filas,
        'estado',  COALESCE(v_actual, v_estado)
    );
END;
$fn$;

COMMENT ON FUNCTION public.fn_wa_estado_meta(text, text, timestamptz, integer) IS
    'ADR-089b: RPC del webhook de estados de Meta (F6). Invocada por el Edge Function via PostgREST con service_role. Solo avanza entrega_estado (sent < delivered < read; failed no pisa read) y jamas lanza excepcion por datos del webhook. anon/authenticated no pueden ejecutarla: si pudieran, cualquiera marcaria mensajes como leidos.';

REVOKE ALL ON FUNCTION public.fn_wa_estado_meta(text, text, timestamptz, integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_wa_estado_meta(text, text, timestamptz, integer) TO service_role;

-- ---------------------------------------------------------------------------
-- RECARGA DEL SCHEMA CACHE DE POSTGREST
-- ---------------------------------------------------------------------------
-- La vista y las dos funciones son objetos nuevos: sin este NOTIFY, PostgREST
-- seguiria devolviendo 404 en la RPC hasta el proximo reinicio.
NOTIFY pgrst, 'reload schema';

COMMIT;

-- ===========================================================================
-- VERIFICACION (comentada; NO se ejecuta aqui)
-- ===========================================================================
-- (V1) Idempotencia: aplicar el archivo completo dos veces seguidas. La
--      segunda corrida no debe lanzar error ni cambiar el resultado.
--
-- (V2) Constraints presentes y validos:
-- SELECT conname, convalidated, pg_get_constraintdef(oid)
--   FROM pg_constraint
--  WHERE conrelid = 'public.wa_plantillas'::regclass
--    AND conname IN ('wa_plantillas_nombre_logico_chk','wa_plantillas_idioma_chk');
--
-- (V3) La vista NO es bypass de RLS:
-- SELECT relname, reloptions FROM pg_class
--  WHERE oid = 'public.v_wa_resumen_diario'::regclass;
-- -- esperado: {security_invoker=true}
--
-- (V4) Costo honesto (con canal_flags.costo_unitario_usd NULL):
-- SELECT dia, tipo, plantilla, enviados, costo_estimado_usd
--   FROM public.v_wa_resumen_diario LIMIT 20;
-- -- esperado: costo_estimado_usd IS NULL, nunca 0.
--
-- (V5) Guarda de retencion:
-- SELECT public.fn_wa_limpiar_dry_run(3);   -- debe fallar: minimo 7
-- SELECT public.fn_wa_limpiar_dry_run(NULL); -- debe fallar: NULL no vale
--
-- (V6) La RPC no lanza excepcion con payload raro:
-- SELECT public.fn_wa_estado_meta('', 'read');        -- message_id_invalido
-- SELECT public.fn_wa_estado_meta('wamid.X', 'zzz');  -- estado_invalido
-- SELECT public.fn_wa_estado_meta('wamid.inexistente', 'read'); -- no_encontrado
--
-- (V7) Permisos (todo debe ser false salvo service_role):
-- SELECT has_function_privilege('anon','public.fn_wa_estado_meta(text,text,timestamptz,integer)','EXECUTE');
-- SELECT has_function_privilege('authenticated','public.fn_wa_estado_meta(text,text,timestamptz,integer)','EXECUTE');
-- SELECT has_table_privilege('anon','public.v_wa_resumen_diario','SELECT');
--
-- (V8) anon no tiene privilegios en wa_envios_log (heredado de ADR-089):
-- SELECT has_table_privilege('anon','public.wa_envios_log','SELECT');
-- -- esperado: false
--
-- ===========================================================================
-- FIN ADR-089b
-- ===========================================================================
