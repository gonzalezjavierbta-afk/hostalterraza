-- ============================================================================
-- verify_adr089b.sql -- verificacion V1-V8 de migrations/adr089b_cierre_no_meta.sql
-- ============================================================================
--
-- NO ES UNA MIGRACION. Es un script de SOLO LECTURA: no crea, no altera y no
-- borra nada del esquema. Se pega completo en el SQL Editor de Supabase
-- (proyecto ctgyvydzshueemlelkzv) y se ejecuta una vez.
--
-- COMO LEER EL RESULTADO
--   PARTE 1 devuelve una tabla con una fila por prueba: prueba | esperado |
--   obtenido | veredicto. Si todas dicen PASS, el esquema quedo como dice la
--   migracion. Cualquier FAIL es un hallazgo, no un detalle cosmetico.
--   PARTE 2 devuelve mensajes NOTICE (pestana "Messages"/"Notices"): son las
--   dos guardas que DEBEN fallar y los dos jobs de pg_cron.
--
-- V1 (idempotencia) no se puede comprobar con un SELECT: se comprueba
-- re-ejecutando `migrations/adr089b_cierre_no_meta.sql` completo. Debe terminar
-- sin error y sus NOTICE deben decir "ya existe, skip". Es seguro: todas las
-- sentencias tienen guarda.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- PARTE 1: verificaciones que se responden con un SELECT
-- ---------------------------------------------------------------------------
SELECT prueba, esperado, obtenido,
       CASE WHEN obtenido = esperado THEN 'PASS' ELSE 'FAIL' END AS veredicto
FROM (
    -- V2a: los dos CHECK existen y estan validados (convalidated = true).
    -- Un CHECK NOT VALID existe pero NO protege las filas viejas.
    SELECT 1 AS ord,
           'V2a CHECK de wa_plantillas validados' AS prueba,
           '2' AS esperado,
           (SELECT count(*)::text
              FROM pg_constraint
             WHERE conrelid = 'public.wa_plantillas'::regclass
               AND conname IN ('wa_plantillas_nombre_logico_chk',
                               'wa_plantillas_idioma_chk')
               AND convalidated) AS obtenido

    -- V2b: el CHECK de nombre apunta al alfabeto de Meta y no a otra cosa.
    UNION ALL
    SELECT 2,
           'V2b CHECK de nombre usa [a-z0-9_]',
           'si',
           (SELECT CASE WHEN count(*) > 0 THEN 'si' ELSE 'no' END::text
              FROM pg_constraint
             WHERE conrelid = 'public.wa_plantillas'::regclass
               AND conname = 'wa_plantillas_nombre_logico_chk'
               AND pg_get_constraintdef(oid) LIKE '%[a-z0-9_]%')

    -- V3: la vista NO es un bypass de RLS. Si esto falla, cualquier
    -- authenticated leeria la bitacora completa saltandose las politicas.
    UNION ALL
    SELECT 3,
           'V3 vista con security_invoker=true',
           'si',
           (SELECT CASE WHEN coalesce(array_to_string(reloptions, ','), '')
                             LIKE '%security_invoker=true%'
                       THEN 'si' ELSE 'no' END::text
              FROM pg_class
             WHERE oid = 'public.v_wa_resumen_diario'::regclass)

    -- V4a: con la tarifa en NULL, NINGUNA fila puede reportar costo 0.
    -- 0 significaria "gratis" y seria una mentira contable.
    UNION ALL
    SELECT 4,
           'V4a costo_estimado_usd nunca es 0 con tarifa NULL',
           '0',
           (SELECT count(*)::text
              FROM public.v_wa_resumen_diario
             WHERE costo_estimado_usd = 0)

    -- V4b: si la tarifa es NULL, el costo debe ser NULL en todas las filas.
    UNION ALL
    SELECT 5,
           'V4b costo_estimado_usd es NULL con tarifa NULL',
           '0',
           (SELECT count(*)::text
              FROM public.v_wa_resumen_diario
             WHERE costo_estimado_usd IS NOT NULL
               AND (SELECT costo_unitario_usd
                      FROM public.canal_flags
                     WHERE canal = 'whatsapp') IS NULL)

    -- V5a/V5b: anon y authenticated NO pueden marcar mensajes como leidos.
    UNION ALL
    SELECT 6,
           'V5a anon sin EXECUTE en fn_wa_estado_meta',
           'false',
           has_function_privilege(
               'anon',
               'public.fn_wa_estado_meta(text,text,timestamptz,integer)',
               'EXECUTE')::text

    UNION ALL
    SELECT 7,
           'V5b authenticated sin EXECUTE en fn_wa_estado_meta',
           'false',
           has_function_privilege(
               'authenticated',
               'public.fn_wa_estado_meta(text,text,timestamptz,integer)',
               'EXECUTE')::text

    -- V5c: anon no lee la vista de observabilidad.
    UNION ALL
    SELECT 8,
           'V5c anon sin SELECT en v_wa_resumen_diario',
           'false',
           has_table_privilege('anon',
                               'public.v_wa_resumen_diario',
                               'SELECT')::text

    -- V5d: heredado de ADR-089, se confirma que no se abrio por accidente.
    UNION ALL
    SELECT 9,
           'V5d anon sin SELECT en wa_envios_log',
           'false',
           has_table_privilege('anon',
                               'public.wa_envios_log',
                               'SELECT')::text

    -- V6: el RPC del webhook responde, no lanza excepcion.
    -- Un webhook que devuelve 500 hace que Meta reintente en bucle.
    UNION ALL
    SELECT 10,
           'V6a message_id vacio -> message_id_invalido',
           'message_id_invalido',
           (public.fn_wa_estado_meta('', 'read') ->> 'reason')

    UNION ALL
    SELECT 11,
           'V6b estado desconocido -> estado_invalido',
           'estado_invalido',
           (public.fn_wa_estado_meta('wamid.NOEXISTE', 'zzz') ->> 'reason')

    UNION ALL
    SELECT 12,
           'V6c message_id desconocido -> no_encontrado',
           'no_encontrado',
           (public.fn_wa_estado_meta('wamid.NOEXISTE', 'read') ->> 'reason')

    -- V7: la funcion de retencion existe con su firma de un argumento.
    UNION ALL
    SELECT 13,
           'V7 fn_wa_limpiar_dry_run(integer) existe',
           'si',
           (SELECT CASE WHEN to_regprocedure(
                            'public.fn_wa_limpiar_dry_run(integer)') IS NOT NULL
                        THEN 'si' ELSE 'no' END::text)

    -- V8: el canal sigue APAGADO. Aplicar el esquema no puede encender nada.
    UNION ALL
    SELECT 14,
           'V8 canal_flags whatsapp sigue activo=false / dry_run=true',
           'false|true',
           (SELECT activo::text || '|' || dry_run::text
              FROM public.canal_flags
             WHERE canal = 'whatsapp')
) AS t
ORDER BY ord;

-- ---------------------------------------------------------------------------
-- PARTE 2: guardas que DEBEN fallar, y estado de los jobs
-- ---------------------------------------------------------------------------
-- Las dos llamadas de abajo abortan ANTES del DELETE (p_dias < 7 y p_dias NULL),
-- asi que no pueden borrar nada. Se ejecutan dentro de un bloque con manejo de
-- excepcion para que el script no se detenga: el NOTICE es el veredicto.
DO $v$
DECLARE
    v_n integer;
BEGIN
    BEGIN
        PERFORM public.fn_wa_limpiar_dry_run(3);
        RAISE NOTICE 'FAIL V9a: fn_wa_limpiar_dry_run(3) NO aborto. La guarda de 7 dias no existe o esta rota.';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'PASS V9a: fn_wa_limpiar_dry_run(3) aborto como debe -> %', SQLERRM;
    END;

    BEGIN
        PERFORM public.fn_wa_limpiar_dry_run(NULL);
        RAISE NOTICE 'FAIL V9b: fn_wa_limpiar_dry_run(NULL) NO aborto. "NULL < 7" es NULL y el IF no dispara.';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'PASS V9b: fn_wa_limpiar_dry_run(NULL) aborto como debe -> %', SQLERRM;
    END;

    -- El job del canal debe existir (creado por ADR-089, apagado por flags).
    BEGIN
        EXECUTE 'SELECT count(*) FROM cron.job WHERE jobname = ''recordatorios-wa'''
           INTO v_n;
        RAISE NOTICE 'INFO V10a: jobs "recordatorios-wa" = % (esperado 1)', v_n;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'INFO V10a: cron.job no legible desde esta sesion -> %', SQLERRM;
    END;

    -- El job de retencion NO debe existir: su cron esta comentado a proposito.
    BEGIN
        EXECUTE 'SELECT count(*) FROM cron.job WHERE jobname = ''recordatorios-wa-retencion'''
           INTO v_n;
        RAISE NOTICE 'INFO V10b: jobs "recordatorios-wa-retencion" = % (esperado 0: se activa a mano)', v_n;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'INFO V10b: cron.job no legible desde esta sesion -> %', SQLERRM;
    END;

    RAISE NOTICE 'INFO: recordar V1 a mano -> re-ejecutar adr089b_cierre_no_meta.sql completo; debe terminar sin error y decir "ya existe, skip".';
END;
$v$;

-- ============================================================================
-- FIN
-- ============================================================================
