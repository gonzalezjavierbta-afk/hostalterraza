-- ============================================================================
-- ADR-073 | Columna canonica del instante del evento (evento_inicio timestamptz)
-- ----------------------------------------------------------------------------
-- Archivo   : migrations/adr073_eventos_evento_inicio.sql
-- Fecha     : 2026-10-03
-- Proposito : dar una columna CALCULABLE del instante en que arranca cada
--             evento, requisito del recordatorio automatico de correo que se
--             dispara N horas antes (56h por defecto, configurable por ADR-074).
--
-- HALLAZGO (por que no bastaba fecha + hora):
--   eventos.fecha y eventos.hora son TEXT, poblados desde inputs HTML de
--   admin.html (`<input type="date">` y `<input type="time">`). No hay zona
--   horaria ni timestamptz: "2026-12-19 22:00" no significa nada para un
--   calculo de ventana horaria sin una zona horaria declarada. `hora` ademas
--   es NULLABLE y puede venir duplicada, y config_landing.content puede traer
--   otra copia de fecha/hora. Con texto, la pregunta "el recordatorio sale a
--   las 56h antes" NO es respondible de forma fiable.
--
-- DECISION: agregar una columna ADITIVA y derivarla de los textos existentes.
--   NO se reescribe fecha ni hora (nadie lee de vuelta), NO se borra ninguna
--   fila y NO se toca ninguna politica RLS existente.
--
-- ADITIVA, CERO BORRADO (Oro #2):
--   * ADD COLUMN IF NOT EXISTS: no reescribe la tabla fisica ni las filas.
--   * El backfill SOLO escribe en evento_inicio, y SOLO en filas donde esa
--     columna sigue en NULL: re-ejecutar el archivo no cambia nada.
--   * ROLLBACK documentado al final (comentado, no se ejecuta).
--
-- FAIL-CLOSED (regla dura de esta migracion):
--   Un instante que no se puede leer con certeza NO se inventa. Si la fecha
--   no matchea ninguno de los dos formatos aceptados, o la hora falta, esta
--   vacia o es invalida, la fila queda con evento_inicio = NULL y se reporta
--   como DUDOSA para revision manual. Un NULL es un dato honesto; una fecha
--   inventada dispara correos a la gente equivocada.
--
-- FORMATOS ACEPTADOS (se detectan los dos con regex; no se asume ninguno):
--   CANONICO  AAAA-MM-DD -> '^[0-9]{4}-[0-9]{1,2}-[0-9]{1,2}$'
--     Es el formato que escribe el panel: `admin.html` compara el valor contra
--     el centinela '2099-12-31' (sentencia del input de fecha) y lo asigna tal
--     cual a `#ev-f`, o sea que sale del `<input type="date">`. Es el unico
--     formato que debe aparecer en eventos creados de aqui en adelante.
--   LEGADO    DD/MM/AAAA -> '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$'
--     NO se produce hoy: solo existe en filas historicas (carga vieja, CSV,
--     alta manual). Se acepta SOLO por compatibilidad con ese historico; si el
--     negocio normaliza esas filas a AAAA-MM-DD, esta rama se puede quitar sin
--     cambiar el resto del backfill.
--   cualquier otro -> NULL (dudosa, se revisa a mano)
--
-- QUE HAY QUE HACER CON LAS DUDOSAS (BLOQUE 3): las lista el RAISE NOTICE y
-- tambien la consulta (3) del BLOQUE DE VERIFICACION. Casos tipicos: `hora`
-- vacia (dato que falta, se corrige en el panel y se vuelve a correr este
-- archivo) o fecha en un tercer formato (hay que ampliar la regex con
-- decision editorial). Ninguna se corrige a mano en la columna: esta migracion
-- solo escribe valores que puede probar.
--
-- FORMATOS DE HORA ACEPTADOS:
--   HH:MM        -> segundos en 0
--   HH:MM:SS     -> se usan tal cual
--   HH:MM:AM/PM, 'T' intercalado, horas > 23, minutos > 59 -> NULL
--   hora NULL o cadena vacia -> NULL (sin hora no hay instante: fail-closed)
--
-- ZONA HORARIA: America/Bogota (UTC-5, sin horario de verano). La conversion
--   es (fecha || hora) interpretadas en hora de Bogota -> timestamptz, con
--   `AT TIME ZONE 'America/Bogota'`. Es la unica conversion de la migracion.
--
-- POR QUE UN BUCLE Y NO UN UPDATE SET-BASED: el parseo necesita validar y
-- capturar errores POR FILA (una fila con '25:00' no puede abortar el
-- backfill de las otras). El bucle envuelve cada calculo en un bloque con
-- EXCEPTION y deja la fila en NULL. Volumen esperado de eventos: bajo.
--
-- ESTADO: ESCRITO, NO APLICADO. Requiere credenciales `service_role` desde el
--   SQL Editor de Supabase. NO ejecutar sin el gate de riesgo de AGENTS.md
--   seccion 2 (esquema) confirmado por la Direccion.
--
-- Verificacion: ver el BLOQUE DE VERIFICACION al final (todo comentado, el
--   archivo no ejecuta nada de esa seccion).
-- ============================================================================


-- ----------------------------------------------------------------------------
-- BLOQUE 1: COLUMNA ADITIVA
--
-- timestamptz (NO timestamp): el instante es un hecho absoluto, y el calculo
-- "faltan 56 horas para el evento" debe ser immune a la zona horaria de quien
-- ejecuta la consulta o de donde corre el cron. NULL allowed a proposito: es
-- el estado honesto de "no se pudo calcular".
-- ----------------------------------------------------------------------------

ALTER TABLE public.eventos
    ADD COLUMN IF NOT EXISTS evento_inicio timestamptz;


-- ----------------------------------------------------------------------------
-- BLOQUE 2: BACKFILL ROBUSTO (fail-closed, una fila dudosa no puede abortar
-- las demas)
--
-- El SELECT de entrada filtra `evento_inicio IS NULL AND fecha IS NOT NULL`:
-- eso es lo que hace la migracion re-ejecutable (la 2a corrida solo vuelve a
-- intentar las dudosas y no escribe nada) y lo que evita pisar un valor ya
-- calculado a mano. El UPDATE repite el `evento_inicio IS NULL` como candado.
-- ----------------------------------------------------------------------------

DO $adr073_backfill$
DECLARE
    r          record;
    v_fecha    text;
    v_hora     text;
    v_anio     integer;
    v_mes      integer;
    v_dia      integer;
    v_hh       integer;
    v_mm       integer;
    v_ss       integer;
    v_fecha_ok boolean := false;
    v_hora_ok  boolean := false;
    v_calc_ok  boolean := false;
    v_ts       timestamp;
    v_val      timestamptz;
    v_set      integer := 0;
    v_null     integer := 0;
    v_exc      integer := 0;
BEGIN
    FOR r IN
        SELECT e.id, e.fecha, e.hora
        FROM public.eventos e
        WHERE e.evento_inicio IS NULL
          AND e.fecha IS NOT NULL
        ORDER BY e.id
    LOOP
        v_fecha    := btrim(r.fecha);
        v_hora     := btrim(coalesce(r.hora, ''));
        v_fecha_ok := false;
        v_hora_ok  := false;
        v_calc_ok  := false;
        v_ts       := NULL;
        v_val      := NULL;
        v_anio     := NULL;
        v_mes      := NULL;
        v_dia      := NULL;
        v_hh       := NULL;
        v_mm       := NULL;
        v_ss       := NULL;

        -- (a) FECHA: deteccion por regex, sin asumir formato. El orden de los
        --     dos ELSIF importa: se prueba primero el formato de type=date.
        IF v_fecha ~ '^[0-9]{4}-[0-9]{1,2}-[0-9]{1,2}$' THEN
            v_anio     := split_part(v_fecha, '-', 1)::integer;
            v_mes      := split_part(v_fecha, '-', 2)::integer;
            v_dia      := split_part(v_fecha, '-', 3)::integer;
            v_fecha_ok := true;
        ELSIF v_fecha ~ '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$' THEN
            v_dia      := split_part(v_fecha, '/', 1)::integer;
            v_mes      := split_part(v_fecha, '/', 2)::integer;
            v_anio     := split_part(v_fecha, '/', 3)::integer;
            v_fecha_ok := true;
        END IF;

        -- (b) RANGO de la fecha antes de construir nada (fail-closed).
        IF v_fecha_ok THEN
            IF v_mes < 1 OR v_mes > 12 OR v_dia < 1 OR v_dia > 31 THEN
                v_fecha_ok := false;
            END IF;
        END IF;

        -- (c) HORA: con segundos o sin segundos; fuera de rango -> descartada.
        --     Sin hora NO se inventa un momento del dia.
        IF v_hora ~ '^[0-9]{1,2}:[0-9]{2}$' THEN
            v_hh      := split_part(v_hora, ':', 1)::integer;
            v_mm      := split_part(v_hora, ':', 2)::integer;
            v_ss      := 0;
            v_hora_ok := true;
        ELSIF v_hora ~ '^[0-9]{1,2}:[0-9]{2}:[0-9]{2}$' THEN
            v_hh      := split_part(v_hora, ':', 1)::integer;
            v_mm      := split_part(v_hora, ':', 2)::integer;
            v_ss      := split_part(v_hora, ':', 3)::integer;
            v_hora_ok := true;
        END IF;

        IF v_hora_ok THEN
            IF v_hh < 0 OR v_hh > 23 OR v_mm < 0 OR v_mm > 59
               OR v_ss < 0 OR v_ss > 59 THEN
                v_hora_ok := false;
            END IF;
        END IF;

        -- (d) CALCULO. make_date() y make_time() son estrictos: '30/02/2026'
        --     o '2026-13-01' lanzan excepcion y la fila cae en NULL (esta es
        --     la red de seguridad que vuelve innecesario confiar en el
        --     rango del paso b para los dias imposibles).
        IF v_fecha_ok AND v_hora_ok THEN
            BEGIN
                v_ts     := make_date(v_anio, v_mes, v_dia)
                            + make_time(v_hh, v_mm, v_ss);
                v_val    := v_ts AT TIME ZONE 'America/Bogota';
                v_calc_ok := true;
            EXCEPTION WHEN others THEN
                v_val     := NULL;
                v_calc_ok := false;
                v_exc     := v_exc + 1;
            END;
        END IF;

        -- (e) ESCRITURA (solo si se pudo calcular con certeza).
        IF v_calc_ok THEN
            UPDATE public.eventos
               SET evento_inicio = v_val
             WHERE id = r.id
               AND evento_inicio IS NULL;
            v_set := v_set + 1;
        ELSE
            v_null := v_null + 1;
        END IF;
    END LOOP;

    RAISE NOTICE '[ADR-073] backfill: escritas=%  dudosas_sin_calculo=%  excepciones_capturadas=%',
        v_set, v_null, v_exc;
END $adr073_backfill$;


-- ----------------------------------------------------------------------------
-- BLOQUE 3: REPORTE DE DUDOSOS (RAISE NOTICE, log del SQL Editor)
--
-- Las que quedan con evento_inicio IS NULL y fecha IS NOT NULL son las que hay
-- que revisar A MANO: tienen fecha escrita pero no se pudo formar un instante.
-- La mayoria deberian ser `hora` vacia (hora es nullable) o formatos fuera de
-- los dos aceptados. Se listan hasta 10 para no inundar el log.
-- ----------------------------------------------------------------------------

DO $adr073_reporte$
DECLARE
    v_total    integer;
    v_con_ts   integer;
    v_sin_ts   integer;
    v_dudosas  integer;
    r_muestra  record;
BEGIN
    SELECT count(*) INTO v_total   FROM public.eventos;
    SELECT count(*) INTO v_con_ts  FROM public.eventos WHERE evento_inicio IS NOT NULL;
    SELECT count(*) INTO v_sin_ts  FROM public.eventos WHERE evento_inicio IS NULL;
    SELECT count(*) INTO v_dudosas FROM public.eventos
     WHERE evento_inicio IS NULL AND fecha IS NOT NULL;

    RAISE NOTICE '[ADR-073] eventos totales=%', v_total;
    RAISE NOTICE '[ADR-073] con evento_inicio=%', v_con_ts;
    RAISE NOTICE '[ADR-073] sin evento_inicio=%', v_sin_ts;
    RAISE NOTICE '[ADR-073] dudosos (sin evento_inicio pero con fecha)=%', v_dudosas;

    -- El objetivo del bucle es una fila completa (id, fecha, hora): la
    -- variable de iteracion es un record, no un integer.
    IF v_dudosas > 0 THEN
        FOR r_muestra IN
            SELECT id, fecha, hora
            FROM public.eventos
            WHERE evento_inicio IS NULL AND fecha IS NOT NULL
            ORDER BY id
            LIMIT 10
        LOOP
            RAISE NOTICE '[ADR-073] dudoso: id=% fecha=[%] hora=[%]',
                r_muestra.id, r_muestra.fecha, coalesce(r_muestra.hora, 'NULL');
        END LOOP;
        IF v_dudosas > 10 THEN
            RAISE NOTICE '[ADR-073] (se muestran solo 10 de % dudosos)', v_dudosas;
        END IF;
    END IF;
END $adr073_reporte$;


-- ----------------------------------------------------------------------------
-- BLOQUE 4: INDICE
--
-- Para la consulta del cron: "eventos con evento_inicio entre ahora+X y
-- ahora+X+ventana". El indice parcial excluye las dudosas (NULL): no se van
-- a consultar y asi el btree no carga con huecos.
-- ----------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_eventos_evento_inicio
    ON public.eventos (evento_inicio)
    WHERE evento_inicio IS NOT NULL;


-- ----------------------------------------------------------------------------
-- BLOQUE 5: DOCUMENTACION VIVA DE LA COLUMNA
-- ----------------------------------------------------------------------------

COMMENT ON COLUMN public.eventos.evento_inicio IS
  'Instante canonico de inicio del evento en timestamptz (ADR-073). Derivado de los textos eventos.fecha (AAAA-MM-DD o DD/MM/AAAA) y eventos.hora (HH:MM o HH:MM:SS) interpretados en America/Bogota. NULL = no se pudo calcular con certeza (fail-closed: no se inventa fecha); revisar esas filas a mano. NO se actualiza solo: si fecha/hora cambian, esta columna queda desfasada hasta que se dispare de nuevo el backfill o un trigger (pendiente, fuera de este ADR).';


-- ----------------------------------------------------------------------------
-- BLOQUE 6: RECARGA DEL SCHEMA CACHE DE POSTGREST
-- (misma razon que en adr051: una columna nueva no es visible para PostgREST
--  hasta que se recarga el cache)
-- ----------------------------------------------------------------------------

NOTIFY pgrst, 'reload schema';


-- ===========================================================================
-- BLOQUE DE VERIFICACION (para la Direccion; ejecutar DESPUES de correr este
-- archivo). Todo lo de abajo esta comentado: el archivo no ejecuta nada de
-- esta seccion.
--
-- (1) LA COLUMNA EXISTE (information_schema.columns): debe devolver 1 fila,
--     data_type = timestamp with time zone, is_nullable = YES.
--
-- SELECT column_name, data_type, is_nullable
-- FROM information_schema.columns
-- WHERE table_schema = 'public'
--   AND table_name   = 'eventos'
--   AND column_name  = 'evento_inicio';
--
-- (2) RECUENTO GLOBAL (la cifra que manda): con + sin = total.
--
-- SELECT count(*) AS eventos_total,
--        count(evento_inicio) AS con_evento_inicio,
--        count(*) FILTER (WHERE evento_inicio IS NULL) AS sin_evento_inicio
-- FROM public.eventos;
--
-- (3) DUDOSOS: filas con fecha escrita pero sin instante. Revisar una por
--     una: si el problema es `hora` vacia, se corrige el dato en el panel y
--     se vuelve a correr este archivo (el backfill es re-ejecutable).
--
-- SELECT id, slug, fecha, hora
-- FROM public.eventos
-- WHERE evento_inicio IS NULL
--   AND fecha IS NOT NULL
-- ORDER BY slug;
--
-- (3b) DISTRIBUCION DE LAS CAUSAS (orienta la revision manual):
--      sin hora      = falta el dato (se corrige en el panel)
--      con hora      = formato no reconocido (hay que ampliar la regex)
--
-- SELECT CASE WHEN hora IS NULL OR btrim(hora) = '' THEN 'sin_hora'
--             ELSE 'hora_con_formato_no_reconocido' END AS causa,
--        count(*) AS filas
-- FROM public.eventos
-- WHERE evento_inicio IS NULL AND fecha IS NOT NULL
-- GROUP BY 1 ORDER BY filas DESC;
--
-- (4) FORMATOS DE FECHA DETECTADOS (si aparece un grupo que no es
--     'AAAA-MM-DD' ni 'DD/MM/AAAA', la regex hay que ampliarla):
--
-- SELECT CASE
--          WHEN fecha ~ '^[0-9]{4}-[0-9]{1,2}-[0-9]{1,2}$' THEN 'AAAA-MM-DD'
--          WHEN fecha ~ '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$' THEN 'DD/MM/AAAA'
--          ELSE 'OTRO_FORMATO' END AS formato_fecha,
--        CASE
--          WHEN hora ~ '^[0-9]{1,2}:[0-9]{2}$'       THEN 'HH:MM'
--          WHEN hora ~ '^[0-9]{1,2}:[0-9]{2}:[0-9]{2}$' THEN 'HH:MM:SS'
--          WHEN hora IS NULL OR btrim(hora) = '' THEN 'sin_hora'
--          ELSE 'OTRO_FORMATO' END AS formato_hora,
--        count(*) AS filas
-- FROM public.eventos
-- GROUP BY 1, 2 ORDER BY filas DESC;
--
-- (5) EL INDICE PARCIAL EXISTE (pg_indexes): debe existir
--     idx_eventos_evento_inicio y su indexdef debe traer el
--     WHERE evento_inicio IS NOT NULL.
--
-- SELECT indexname, indexdef
-- FROM pg_indexes
-- WHERE schemaname = 'public'
--   AND tablename  = 'eventos'
--   AND indexname  = 'idx_eventos_evento_inicio';
--
-- (6) PRUEBA DE LA CONVERSION DE ZONA HORARIA: una fila ya calculada debe
--     leerse en hora de Bogota (UTC-5) y en UTC con 5h de diferencia. Si el
--     instante aparece corrido, la zona del paso (d) del backfill esta mal.
--
-- SELECT slug, fecha, hora, evento_inicio,
--        evento_inicio AT TIME ZONE 'America/Bogota' AS en_bogota,
--        evento_inicio AT TIME ZONE 'UTC'               AS en_utc
-- FROM public.eventos
-- WHERE evento_inicio IS NOT NULL
-- ORDER BY evento_inicio DESC
-- LIMIT 10;
--
-- (6b) COHERENCIA con los textos de origen: recalcula el instante con la
--      MISMA logica del backfill y compara. Debe devolver 0. Si devuelve
--      algo, el valor guardado no corresponde a lo que dice el panel.
--      Solo cubre el caso mas comun (AAAA-MM-DD + HH:MM); las otras
--      combinaciones ya se ven en el punto (4).
--
-- SELECT count(*) AS incoherentes
-- FROM public.eventos
-- WHERE evento_inicio IS NOT NULL
--   AND fecha ~ '^[0-9]{4}-[0-9]{1,2}-[0-9]{1,2}$'
--   AND hora   ~ '^[0-9]{1,2}:[0-9]{2}$'
--   AND evento_inicio IS DISTINCT FROM
--       (
--         make_date(split_part(fecha, '-', 1)::integer,
--                   split_part(fecha, '-', 2)::integer,
--                   split_part(fecha, '-', 3)::integer)
--         +
--         make_time(split_part(hora, ':', 1)::integer,
--                   split_part(hora, ':', 2)::integer, 0)
--       ) AT TIME ZONE 'America/Bogota';
--
-- (7) CONSULTA DEL CRON (la que disparara el recordatorio): ventana de
--     eventos que entran en el rango de aviso. hoy no hay cron; esto es la
--     consulta de referencia.
--
-- SELECT id, slug, evento_inicio
-- FROM public.eventos
-- WHERE evento_inicio BETWEEN now() + interval '54 hours'
--                       AND now() + interval '58 hours'
-- ORDER BY evento_inicio;
-- ===========================================================================
-- ROLLBACK (documentado, comentado; requiere gate de riesgo).
-- Cero Borrado: NO se borra ninguna fila ni se altera fecha/hora. El unico
-- efecto del rollback es perder la columna calculada (el dato de origen sigue
-- intacto, asi que el backfill se puede volver a correr).
--   DROP INDEX IF EXISTS public.idx_eventos_evento_inicio;
--   ALTER TABLE public.eventos DROP COLUMN IF EXISTS evento_inicio;
-- ===========================================================================