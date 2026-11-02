-- ============================================================================
-- ADR-078b | Hotfix del cron de recordatorios automaticos (H1 + H2b + H9)
-- Archivo   : migrations/adr078b_fix_cron_recordatorios.sql
-- Version   : v1.1
-- Fecha     : 2026-11-01
-- Autor     : @sql-security (ExploraCO)
-- Base      : migrations/adr078_cron_recordatorios.sql (version VIGENTE, sin
--             modificar). Esta migracion solo reemplaza el cuerpo de la funcion
--             public.fn_enviar_recordatorios_pendientes().
-- ============================================================================
-- HISTORIAL DE VERSIONES DE ESTE ARCHIVO
--   v1.1 (2026-11-01): blindaje slug NULL. v1.0 ya aplicada en la base;
--        re-ejecutar este archivo para tomar v1.1.
--        Si eventos.slug es NULL o vacio, el ELSE del CASE ya no produce
--        '.../evento.html?slug=' (URL valida pero sin evento): cae a la raiz
--        del dominio. v1.0: H1 + H2b + H9 (p_nombre, p_qr_code con CASE).
-- ============================================================================
-- PROPOSITO
--   Desbloquear el canal de correo de recordatorios. La definicion de ADR-078
--   aborta SIEMPRE antes de enviar y antes de registrar, por lo que los
--   recordatorios automaticos nunca han enviado un solo correo en produccion.
--
-- HALLAZGO QUE CORRIGE (auditoria del canal de correo)
--   H1 (BLOQUEANTE) - adr078 linea ~112:
--     p_qr_code => ''   y p_qr_code es OBLIGATORIO dentro de la RPC
--     public.enviar_email_registro (adr076, linea 791:
--     fn_adr076_texto_limpio(p_qr_code, 'qr_code', 600, true)). Un string vacio
--     lanza SQLSTATE 22023 ANTES del INSERT en email_envios_log y ANTES del
--     bloque fail-open: la excepcion propaga, fn_enviar_recordatorios_pendientes
--     aborta entera, el job de pg_cron queda en 'failed' y no se envia ni se
--     registra nada.
--   H2b - adr078 linea ~111:
--     p_nombre => COALESCE(r.inscrito_nombre, '') y p_nombre NO es obligatorio
--     (adr076, linea 790: fn_adr076_texto_limpio(..., false)). Un NULL o vacio
--     devuelve NULL, jsonb_strip_nulls elimina la clave y la Edge Function
--     responde 400 "nombre es obligatorio": el inscrito sin nombre nunca recibe
--     el recordatorio (queda como error, no como fallo visible del job).
--
-- DECISION APROBADA (Opcion A: "el recordatorio SI lleva QR")
--   - p_nombre  -> COALESCE(NULLIF(btrim(i.nombre), ''), 'Asistente')
--   - p_qr_code -> CASE: si el qr_code del inscrito ya es una URL http(s) se
--                  respeta tal cual; si no (vacio, NULL o codigo corto), se usa
--                  el enlace canonico del evento por slug. v1.1: si el slug es
--                  NULL o vacio, cae a la raiz 'https://taquilladirecta.com/'
--                  en vez de dejar '...?slug=' sin evento. Ningun correo sale
--                  sin QR ni sin nombre: el fallback es un valor REAL y estable.
--
-- HALLAZGO H9 (por que CASE y NO COALESCE) - verificado en disco 2026-11-01
--   El COALESCE(NULLIF(btrim(qr_code), ''), ...) solo cubria NULL/vacio. Pero el
--   qr_code mayoritario NO es una URL: admin.html genera 'QR-' + UID() (codigo
--   corto), y registroaforo.html:704 y registroaforo.html:840 hacen lo mismo.
--   La Edge Function (supabase/functions/send-ticket-email/index.ts:276-280)
--   exige /^https?:\/\//i y si no lanza 400 "qrCode debe ser una URL http o
--   https". Con COALESCE, un 'QR-A1B2C3' no vacio seguia produciendo 400 y el
--   recordatorio no salia: H1 quedaba abierto por otra puerta. El CASE decide
--   por FORMA (es URL o no), no por VACIO.
--
-- COLUMNAS USADAS (verificadas contra las migraciones versionadas, ADR-006)
--   - eventos.slug      -> existe; la usa adr074 (linea 497: SELECT e.slug) y
--                          los seeds (WHERE slug = ...). Es el slug canonico de
--                          la landing publica: /evento.html?slug=<slug>.
--   - inscritos.qr_code -> existe; la usa adr076 (linea 1182: coalesce(i.qr_code,
--                          '')), adr068 y el runbook B9 (fixture con
--                          https://taquilladirecta.com/b9-smoke-ins).
--   - eventos.nombre/fecha/hora/ubicacion, inscritos.nombre/cedula/email:
--     identicas al original. Los alias e/i y los nombres de columna del SELECT
--     se conservan textualmente.
--
-- QUE NO CAMBIA (paridad con adr078)
--   - Firma, RETURNS jsonb, LANGUAGE plpgsql, SECURITY DEFINER.
--   - SET search_path = public, pg_temp.
--   - CTE/joins, predicados de ventana (+-2h), interruptor
--     config_recordatorios.activo (override por evento -> fila global -> true).
--   - Calculo de contadores (eventos/enviados/omitidos/errores) y jsonb de
--     retorno con run_at.
--   - REVOKE ALL ... FROM PUBLIC, anon, authenticated.
--   - GRANT EXECUTE ... TO service_role.
--   - Frontera de idempotencia: idempotency_key =
--     'recordatorio:<evento_id>:<inscrito_id>' (UNIQUE en email_envios_log).
--
-- UNICA DIFERENCIA ESTRUCTURAL RESPECTO AL ORIGINAL
--   El SELECT del FOR agrega dos columnas al record: e.slug AS evento_slug y
--   i.qr_code AS inscrito_qr. Son aditivas (no alteran el FROM/WHERE) y son
--   imprescindibles para construir los dos fallbacks. Ningun alias existente se
--   renombra.
--
-- CRON: NO SE RE-AGENDA (decision explicita)
--   El job 'recordatorios-horarios' ya existe y esta active; adr078 lo deja
--   programado y su smoke lo verifica. Re-ejecutar cron.schedule aqui abriria
--   una ventana innecesaria de doble agenda (unschedule + schedule) y, si el
--   archivo se corriera en paralelo con una corrida del job, podria perder el
--   slot. Esta migracion NO crea extensiones y NO toca cron.job: solo
--   reemplaza la funcion que el job ya invoca. La instruccion de re-agenda
--   queda comentada al final, por si algun dia se reconstruye el job desde cero.
--
-- FUERA DE ALCANCE (pendientes, NO tocados aqui)
--   - H3: un envio idempotente (estado 'omitido' por llave repetida) se cuenta
--         en el contador 'omitidos' junto con los omitidos por rate limit; el
--         desglose no distingue motivo.
--   - H4: ticketUrl / enlace de boleteria del cuerpo del correo.
--   - H5: typo de cabecera X-Origem en la Edge Function.
--   - WhatsApp: fuera de este ADR.
--
-- IDEMPOTENCIA DE LA MIGRACION (ADR-008)
--   CREATE OR REPLACE FUNCTION + REVOKE/GRANT: re-ejecutar el archivo entero es
--   no-op logico (misma definicion, mismos permisos).
--
-- CERO BORRADO
--   No hay DROP, TRUNCATE ni DELETE ejecutables. No se borran filas ni objetos.
--
-- ROLLBACK (comentado; restaurar la version anterior de la funcion)
--   La version anterior vive integra en migrations/adr078_cron_recordatorios.sql
--   (BLOQUE 2). Para volver atras, pegar ese archivo completo en el SQL Editor:
--   su CREATE OR REPLACE FUNCTION restaura el cuerpo con el bug H1 y su DO/cron
--   vuelve a agendar el mismo jobname (idempotente: unschedule + schedule).
--   Alternativa SIN tocar el cron: copiar SOLO el CREATE OR REPLACE FUNCTION y
--   el par REVOKE/GRANT de adr078 (lineas 59-146) y ejecutarlos.
--   No se documenta un DROP FUNCTION como rollback: dejaria al job apuntando a
--   una funcion inexistente y romperia cada corrida horaria.
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- BLOQUE 1: FUNCION QUE DISPARA LOS RECORDATORIOS PENDIENTES (hotfix)
-- ---------------------------------------------------------------------------
-- SECURITY DEFINER: corre como owner para leer config_recordatorios (RLS sin
-- politicas) y ejecutar la RPC de ADR-076 por cada inscrito. search_path fijo.
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
               e.slug            AS evento_slug,
               e.nombre          AS evento_nombre,
               e.fecha           AS evento_fecha,
               e.hora            AS evento_hora,
               e.ubicacion       AS evento_lugar,
               i.id              AS inscrito_id,
               i.nombre          AS inscrito_nombre,
               i.cedula          AS inscrito_cedula,
               i.email           AS inscrito_email,
               i.qr_code         AS inscrito_qr
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

        -- H1: p_qr_code es OBLIGATORIO en la RPC (adr076 L791).
        -- H9: ademas debe ser http(s) para la Edge Function (index.ts L276-280),
        -- y el qr_code real de admin/registroaforo es 'QR-XXXX' (codigo corto,
        -- NO URL). Por eso CASE por forma y no COALESCE por vacio: solo se
        -- conserva el qr_code si ya es una URL; en cualquier otro caso se manda
        -- el enlace canonico del evento por slug, y si el slug falta, la raiz
        -- del dominio (v1.1: nunca una URL con '?slug=' vacio).
        -- H2b: p_nombre vacio/NULL se convierte en 'Asistente' para que la clave
        -- nunca desaparezca del jsonb (jsonb_strip_nulls) y la Edge Function no
        -- responda 400.
        v_resp := public.enviar_email_registro(
            p_email             => r.inscrito_email,
            p_nombre            => COALESCE(NULLIF(btrim(r.inscrito_nombre), ''), 'Asistente'),
            p_qr_code           => CASE
                                       WHEN btrim(COALESCE(r.inscrito_qr, '')) ~* '^https?://'
                                         THEN btrim(r.inscrito_qr)
                                       ELSE CASE
                                                WHEN COALESCE(btrim(r.evento_slug), '') <> ''
                                                  THEN 'https://taquilladirecta.com/evento.html?slug='
                                                       || btrim(r.evento_slug)
                                                ELSE 'https://taquilladirecta.com/'
                                            END
                                   END,
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

-- Solo el proceso programado (owner / service_role) la corre. Nada de anon.
-- Se repiten porque CREATE OR REPLACE conserva los permisos previos: el par es
-- la fuente de verdad auditable y re-ejecutarlo es no-op.
REVOKE ALL ON FUNCTION public.fn_enviar_recordatorios_pendientes() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_enviar_recordatorios_pendientes() TO service_role;

-- Recarga del schema cache de PostgREST (mismo cierre que adr078 BLOQUE 4).
NOTIFY pgrst, 'reload schema';

COMMIT;

-- ===========================================================================
-- VERIFICACION POST-APLICACION (comentada; la corre el humano en el SQL Editor)
-- Runbook de referencia: Sistema QR desarrollo/runbooks/B9-smoke-email.md
--   - Seccion 4: fixtures aislados (evento 'b9-smoke-evt' en ventana + inscrito
--     de prueba con correo real).
--   - Seccion 5 "PASO 2 - Corrida forzada del cron (mide H1)": es exactamente
--     (1) de aqui abajo. Antes del hotfix esa consulta devolvia SQLSTATE 22023;
--     despues debe devolver el jsonb.
--
-- (1) Corrida manual sobre el evento en ventana. Esperado: jsonb, NO error.
--     Si no hay eventos en ventana devuelve {"eventos":0,...} y NO prueba nada:
--     crear primero los fixtures del runbook B9 seccion 4.
--     SELECT public.fn_enviar_recordatorios_pendientes();
--
-- (2) Traza del envio del recordatorio (debe aparecer 1 fila por inscrito):
--     SELECT idempotency_key, evento_id, inscrito_id, destinatario, tipo,
--            estado, intentos, error_texto, pg_net_request_id,
--            created_at, enviado_at
--     FROM public.email_envios_log
--     WHERE tipo = 'recordatorio'
--     ORDER BY created_at DESC
--     LIMIT 20;
--
-- (3) Solo la corrida recien hecha (aisla el resultado del historico):
--     SELECT destinatario, estado, error_texto, enviado_at
--     FROM public.email_envios_log
--     WHERE tipo = 'recordatorio'
--       AND created_at > now() - interval '15 minutes'
--     ORDER BY created_at DESC;
--
-- (4) El job sigue existiendo, activo y sin duplicados:
--     SELECT jobid, jobname, schedule, active
--     FROM cron.job WHERE jobname = 'recordatorios-horarios';
--     -- Esperado: exactamente 1 fila, active = true.
--
-- (5) Ultima corrida del job (tras la siguiente hora en punto + 5 min):
--     SELECT jobid, status, return_message, start_time
--     FROM cron.job_run_details
--     WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'recordatorios-horarios')
--     ORDER BY start_time DESC LIMIT 5;
--     -- Esperado: status = 'succeeded' (antes: 'failed' con 22023).
--
-- (6) Reproduccion de H1/H2b/H9 ya cubierta: un inscrito con nombre NULL,
--     qr_code NULL y qr_code con codigo corto ('QR-XXXX', como los que genera
--     admin.html y registroaforo.html) debe enviar igual: el CASE lo sustituye
--     por el enlace del evento. El fixture B9 prueba el camino con datos
--     completos; para el camino degradado:
--     -- UPDATE ... NO usar en produccion; solo en el evento del smoke.
--     -- INSERT de un inscrito del evento 'b9-smoke-evt' con nombre y qr_code
--     -- en NULL (y otro con qr_code = 'QR-TEST01'), y volver a correr (1).
--     -- Esperado en los tres: estado 'enviado'.
--
-- (7) ASCII-safety del archivo (debe dar 0 coincidencias):
--     Select-String -Path migrations/adr078b_fix_cron_recordatorios.sql -Pattern '[^\x00-\x7F]'
-- ===========================================================================
-- RE-AGENDA DEL CRON (comentado a proposito; NO ejecutar en este hotfix)
--   El job ya existe y esta active. Solo si se reconstruye desde cero:
--   -- SELECT cron.unschedule('recordatorios-horarios');   -- si existiera
--   -- SELECT cron.schedule('recordatorios-horarios', '5 * * * *',
--   --        'SELECT public.fn_enviar_recordatorios_pendientes();');
--   -- Y solo entonces: CREATE EXTENSION IF NOT EXISTS pg_cron;
-- ===========================================================================
