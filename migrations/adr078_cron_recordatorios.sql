-- ============================================================================
-- ADR-078 | Cron de recordatorios automaticos
-- Archivo   : migrations/adr078_cron_recordatorios.sql
-- ============================================================================
-- PROPOSITO
--   Cerrar el circuito del recordatorio automatico (ADR-073/074/076): un job de
--   pg_cron corre cada hora, busca los eventos que entran en su ventana de aviso
--   y, por cada inscrito con email, invoca el RPC `enviar_email_registro` con
--   p_tipo='recordatorio'. El RPC ya sabe enviar (pg_net -> Edge Function ->
--   Resend) y ya deja traza idempotente en email_envios_log.
--
-- POR QUE ASI (economia de diseno)
--   NO se crea un segundo camino de envio: se reutiliza el RPC de ADR-076, que
--   es el unico dueno del envio y del log. Asi el recordatorio hereda gratis el
--   rate limit por bypass (service_role), la idempotencia y las trazas.
--
-- PIEZAS
--   (1) CREATE EXTENSION pg_cron (pg_net ya existe).
--   (2) public.fn_enviar_recordatorios_pendientes() -> cuenta y dispara.
--   (3) cron.schedule('recordatorios-horarios','5 * * * *', ...).
--
-- IDEMPOTENCIA (doble red)
--   (a) La ventana es acotada por evento_inicio, y la fila se re-confirma una
--       sola hora si el cron se reintenta dentro de la misma hora (cron no
--       re-ejecuta el mismo slot). La llave:
--   (b) idempotency_key = 'recordatorio:<evento_id>:<inscrito_id>' unica en
--       email_envios_log: si ya se logueo, el RPC responde omitido y no reenvia.
--
-- CONFIGURACION
--   - Horas de anticipacion: public.fn_horas_recordatorio(evento_id)
--     (override por evento -> fila global -> 56).
--   - Interruptor `config_recordatorios.activo`: lo lee ESTA funcion (el
--     resolver no lo filtra, por contrato ADR-074). Se aplica por evento si
--     existe override, y por la fila global si no.
--
-- ZONA / VENTANA
--   evento_inicio es timestamptz. El cron corre cada hora a los 5 minutos. Se
--   usa una ventana de +-2h alrededor del anticipo para que ninguna hora del
--   dia se salte un evento (el anticipo medio 56 no siempre cae en "en punto").
--   El solape lo absorbe la idempotencia de (b).
--
-- ALCANCE: solo esquema/cron. No envia nada al aplicar la migracion.
-- CERO BORRADO: no elimina datos ni objetos preexistentes; solo crea.
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- BLOQUE 1: EXTENSIONES
-- ---------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- ---------------------------------------------------------------------------
-- BLOQUE 2: FUNCION QUE DISPARA LOS RECORDATORIOS PENDIENTES
-- ---------------------------------------------------------------------------
-- SECURITY DEFINER: corre como owner para poder leer config_recordatorios
-- (RLS sin politicas) y ejecutar el RPC por cada inscrito. search_path fijo.
-- Devuelve un jsonb con el conteo para que el job quede auditable.
CREATE OR REPLACE FUNCTION public.fn_enviar_recordatorios_pendientes()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
    v_margen   interval := interval '2 hours';
    v_eventos  integer := 0;
    v_ok       integer := 0;
    v_omitidos integer := 0;
    v_errores  integer := 0;
    r          record;
    v_resp     jsonb;
BEGIN
    FOR r IN
        SELECT e.id              AS evento_id,
               e.nombre          AS evento_nombre,
               e.fecha           AS evento_fecha,
               e.hora            AS evento_hora,
               e.ubicacion       AS evento_lugar,
               i.id              AS inscrito_id,
               i.nombre          AS inscrito_nombre,
               i.cedula          AS inscrito_cedula,
               i.email           AS inscrito_email
        FROM public.eventos e
        JOIN public.inscritos i
          ON i.evento_id = e.id
        WHERE e.evento_inicio IS NOT NULL
          AND i.email IS NOT NULL
          AND btrim(i.email) <> ''
          AND e.evento_inicio BETWEEN
                now() + make_interval(hours => public.fn_horas_recordatorio(e.id)) - v_margen
            AND now() + make_interval(hours => public.fn_horas_recordatorio(e.id)) + v_margen
          AND COALESCE(
                (SELECT c.activo
                   FROM public.config_recordatorios c
                  WHERE c.evento_id = e.id
                  ORDER BY c.updated_at DESC, c.created_at ASC, c.id ASC
                  LIMIT 1),
                (SELECT c.activo
                   FROM public.config_recordatorios c
                  WHERE c.evento_id IS NULL
                  ORDER BY c.updated_at DESC, c.created_at ASC, c.id ASC
                  LIMIT 1),
                true
              ) = true
    LOOP
        v_eventos := v_eventos + 1;

        v_resp := public.enviar_email_registro(
            p_email             => r.inscrito_email,
            p_nombre            => COALESCE(r.inscrito_nombre, ''),
            p_qr_code           => '',
            p_evento_nombre     => COALESCE(r.evento_nombre, ''),
            p_evento_fecha      => COALESCE(r.evento_fecha::text, ''),
            p_evento_hora       => COALESCE(r.evento_hora::text, ''),
            p_evento_lugar      => COALESCE(r.evento_lugar, ''),
            p_idempotency_key   => 'recordatorio:' || r.evento_id || ':' || r.inscrito_id,
            p_tipo              => 'recordatorio',
            p_cedula            => r.inscrito_cedula,
            p_evento_id         => r.evento_id,
            p_inscrito_id       => r.inscrito_id,
            p_bypass_rate_limit => true
        );

        IF COALESCE((v_resp ->> 'ok')::boolean, false) THEN
            v_ok := v_ok + 1;
        ELSIF COALESCE(v_resp ->> 'estado', '') = 'omitido' THEN
            v_omitidos := v_omitidos + 1;
        ELSE
            v_errores := v_errores + 1;
        END IF;
    END LOOP;

    RETURN jsonb_build_object(
        'eventos',   v_eventos,
        'enviados',  v_ok,
        'omitidos',  v_omitidos,
        'errores',   v_errores,
        'run_at',    now()
    );
END;
$fn$;

-- Solo el proceso programado (owner) la corre. Nada de anon/authenticated.
REVOKE ALL ON FUNCTION public.fn_enviar_recordatorios_pendientes() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_enviar_recordatorios_pendientes() TO service_role;

-- ---------------------------------------------------------------------------
-- BLOQUE 3: JOB DE CRON (todos los dias, a los 5 minutos de cada hora)
-- ---------------------------------------------------------------------------
-- Idempotente: si el job ya existe con este nombre, no se duplica.
DO $do$
BEGIN
    IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'recordatorios-horarios') THEN
        PERFORM cron.unschedule('recordatorios-horarios');
    END IF;
    PERFORM cron.schedule(
        'recordatorios-horarios',
        '5 * * * *',
        $job$SELECT public.fn_enviar_recordatorios_pendientes();$job$
    );
    RAISE NOTICE '[INFO] ADR-078: job "recordatorios-horarios" programado (5 * * * *).';
END;
$do$;

-- ---------------------------------------------------------------------------
-- BLOQUE 4: RECARGA DEL SCHEMA CACHE DE POSTGREST
-- ---------------------------------------------------------------------------
NOTIFY pgrst, 'reload schema';

COMMIT;

-- ===========================================================================
-- VERIFICACION (comentada; ejecutar despues de aplicar)
--
-- (1) job existe:
-- SELECT jobid, schedule, jobname, active FROM cron.job WHERE jobname='recordatorios-horarios';
--
-- (2) extensiones:
-- SELECT extname, extversion FROM pg_extension WHERE extname IN ('pg_cron','pg_net');
--
-- (3) dry-run manual (no envia si no hay eventos en ventana; devuelve 0/0/0/0):
-- SELECT public.fn_enviar_recordatorios_pendientes();
--
-- (4) historial de corridas (tras una hora):
-- SELECT jobid, status, return_message, start_time
-- FROM cron.job_run_details WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname='recordatorios-horarios')
-- ORDER BY start_time DESC LIMIT 5;
--
-- (5) a quien ya se le aviso:
-- SELECT cedula_norm, destinatario, estado, enviado_at
-- FROM public.email_envios_log WHERE tipo='recordatorio' ORDER BY created_at DESC;
--
-- (6) ASCII-safety (debe dar 0):
-- Select-String -Path migrations/adr078_cron_recordatorios.sql -Pattern '[^\x00-\x7F]'
-- ===========================================================================
-- ROLLBACK (documentado, comentado):
--   SELECT cron.unschedule('recordatorios-horarios');
--   DROP FUNCTION IF EXISTS public.fn_enviar_recordatorios_pendientes();
--   -- pg_cron no se dropea (puede compartirse con otros jobs).
-- ===========================================================================
