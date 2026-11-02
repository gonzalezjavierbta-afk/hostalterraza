-- ============================================================================
-- verify_adr089b_parte2.sql -- V9 y V10 como TABLA (sin pestana de Notices)
-- ============================================================================
--
-- NO ES UNA MIGRACION y no toca datos del negocio. Crea una tabla TEMPORAL
-- (_v089b) que vive solo en la sesion del SQL Editor y la borra al final.
--
-- Para que sirve: las guardas de retencion DEBEN abortar, y una excepcion no
-- se puede observar con un SELECT normal. El bloque `DO` las ejecuta dentro de
-- un manejador de excepcion y anota el veredicto en la tabla temporal; el
-- SELECT final lo devuelve con el mismo formato PASS/FAIL de la parte 1.
--
-- Seguridad: `fn_wa_limpiar_dry_run(3)` y `(NULL)` abortan ANTES del DELETE
-- (p_dias < 7 y p_dias NULL). Si la guarda estuviera rota, el peor caso es que
-- borre filas `omitido_motivo='dry_run'` de mas de 3 dias, que es exactamente
-- lo que la retencion existe para podar. Hoy no hay ninguna fila de dry-run.
-- ============================================================================

DROP TABLE IF EXISTS _v089b;
CREATE TEMP TABLE _v089b (
    ord      integer,
    prueba   text,
    esperado text,
    obtenido text
);

-- ---------------------------------------------------------------------------
-- V9: las dos guardas de la retencion deben abortar
-- ---------------------------------------------------------------------------
DO $v$
BEGIN
    BEGIN
        PERFORM public.fn_wa_limpiar_dry_run(3);
        INSERT INTO _v089b VALUES (1,
            'V9a fn_wa_limpiar_dry_run(3) aborta',
            'aborta',
            'NO ABORTO (borro filas de mas de 3 dias)');
    EXCEPTION WHEN OTHERS THEN
        INSERT INTO _v089b VALUES (1,
            'V9a fn_wa_limpiar_dry_run(3) aborta',
            'aborta',
            'aborta');
    END;

    BEGIN
        PERFORM public.fn_wa_limpiar_dry_run(NULL);
        INSERT INTO _v089b VALUES (2,
            'V9b fn_wa_limpiar_dry_run(NULL) aborta',
            'aborta',
            'NO ABORTO ("NULL < 7" es NULL y el IF no dispara)');
    EXCEPTION WHEN OTHERS THEN
        INSERT INTO _v089b VALUES (2,
            'V9b fn_wa_limpiar_dry_run(NULL) aborta',
            'aborta',
            'aborta');
    END;
END;
$v$;

-- ---------------------------------------------------------------------------
-- V10: los jobs de pg_cron (lectura defensiva: si cron.job no es legible,
-- se anota en lugar de abortar el script)
-- ---------------------------------------------------------------------------
DO $v$
DECLARE
    v_n integer;
BEGIN
    BEGIN
        EXECUTE 'SELECT count(*) FROM cron.job WHERE jobname = ''recordatorios-wa'''
           INTO v_n;
        INSERT INTO _v089b VALUES (3,
            'V10a job recordatorios-wa existe (canal apagado por flags)',
            '1', v_n::text);
    EXCEPTION WHEN OTHERS THEN
        INSERT INTO _v089b VALUES (3,
            'V10a job recordatorios-wa existe (canal apagado por flags)',
            '1', 'no legible: ' || left(SQLERRM, 40));
    END;

    BEGIN
        EXECUTE 'SELECT count(*) FROM cron.job WHERE jobname = ''recordatorios-wa-retencion'''
           INTO v_n;
        INSERT INTO _v089b VALUES (4,
            'V10b job recordatorios-wa-retencion NO existe (se activa a mano)',
            '0', v_n::text);
    EXCEPTION WHEN OTHERS THEN
        INSERT INTO _v089b VALUES (4,
            'V10b job recordatorios-wa-retencion NO existe (se activa a mano)',
            '0', 'no legible: ' || left(SQLERRM, 40));
    END;
END;
$v$;

-- ---------------------------------------------------------------------------
-- Resultado
-- ---------------------------------------------------------------------------
SELECT prueba, esperado, obtenido,
       CASE WHEN obtenido = esperado THEN 'PASS' ELSE 'FAIL' END AS veredicto
  FROM _v089b
 ORDER BY ord;

DROP TABLE _v089b;

-- ============================================================================
-- FIN. V1 (idempotencia) NO se puede automatizar aqui: se comprueba
-- re-ejecutando migrations/adr089b_cierre_no_meta.sql completo; debe terminar
-- sin error y decir "ya existe, skip" dos veces (un CHECK por bloque).
-- ============================================================================
