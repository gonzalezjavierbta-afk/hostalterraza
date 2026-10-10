-- ============================================================================
-- ADR-082 | Puntos de acceso generales vs restringidos por evento
-- ----------------------------------------------------------------------------
-- Archivo   : migrations/adr082_puntos_generales.sql
-- Fecha     : 2026-10-10
-- Proposito : distinguir, dentro de un mismo evento, que puntos de check-in son
--             GENERALES (pasa cualquier inscrito, sin filtro por ticket) y
--             cuales son RESTRINGIDOS (siguen la regla ADR-079/ADR-081).
--             Una sola pieza de esquema: una columna jsonb hermana de la ya
--             existente public.eventos.puntos_acceso.
--
-- HALLAZGO (esquema real, confirmado en Fase 0):
--   * public.eventos.puntos_acceso = jsonb, array de strings con NOMBRES de
--     puntos (ej. ["Ancestral"]). EXISTE y es preexistente: su DDL original no
--     esta en el repo. Ver migrations/adr079_multi_punto_override.sql linea 22 y
--     BLUEPRINT.md linea 83.
--   * public.inscritos.puntos_acceso = jsonb (ADR-079). Es el override por
--     ticket: NULL o [] = hereda la lista base del evento; con valor = solo esos.
--   * No habria forma de expresar "este punto es para todos" sin reescribir
--     puntos_acceso evento por evento o forzar el override en cada
--     inscripcion. Falta una tercera dimension.
--
-- SEMANTICA FIJADA (lectura de scanner / admin):
--   * eventos.puntos_generales es un jsonb array de strings (nombres de puntos)
--     y DEBE ser un subconjunto de eventos.puntos_acceso del mismo evento.
--   * NULL (y tambien []) = NINGUN punto es general. Es el default y por lo
--     tanto preserva EXACTAMENTE el comportamiento actual: todos los puntos son
--     restringidos y mandan inscritos.puntos_acceso (ADR-079/ADR-081).
--   * Un punto P es GENERAL si P pertenece a eventos.puntos_generales.
--   * Si P es GENERAL se IGNORA inscritos.puntos_acceso: cualquier inscrito del
--     evento pasa por P, tenga o no ese punto en su override.
--   * Si P NO es general manda la regla vigente: inscritos.puntos_acceso NULL = el
--     ticket hereda la lista del evento; [] = el ticket no puede pasar por
--     ninguno; con valor = solo los puntos listados.
--
-- DECISION:
--   * Columna hermana en eventos, no una tabla de permisos: el dato pertenece al
--     evento y se lee en la misma consulta que ya trae puntos_acceso.
--   * jsonb (no text[]) por simetria de tipo con puntos_acceso, para que el
--     front lo trate con el mismo helper. Molde de estilo:
--     migrations/adr079_multi_punto_override.sql lineas 89-93.
--   * DEFAULT NULL a proposito: cero backfill. Los eventos que ya existen quedan
--     con todos sus puntos RESTRINGIDOS, que es su comportamiento actual. No se
--     hace ningun UPDATE de datos.
--   * La columna es INERTE: no hay trigger, no hay vista, no se toca RLS, ni
--     politicas, ni permisos, ni grants. Cero impacto en seguridad.
--   * El ADR documental (DECISIONS.md) se difiere a una sesion posterior por
--     modo express. Este archivo deja fijada la semantica; el ADR solo la
--     narrara. NO se inventa aqui el texto del ADR.
--
-- ADITIVA, CERO BORRADO (Oro #2):
--   * ADD COLUMN IF NOT EXISTS: metadata-only, no reescribe filas ni la tabla.
--   * No se elimina ninguna columna, ninguna fila, ninguna politica.
--   * ROLLBACK documentado al final (comentado, no se ejecuta).
--
-- Idempotencia: 100%. ADD COLUMN IF NOT EXISTS, COMMENT ON COLUMN (reemplaza el
-- texto anterior si existiera) y el guard DO solo LEEN y solo lanzan excepcion
-- si el dato es invalido. El archivo puede ejecutarse 2+ veces sin error ni
-- efecto adicional: en la primera pasada y en las siguientes todas las filas
-- estan en NULL, por lo que el guard no encuentra nada que validar.
--
-- Notas tecnicas:
--   * NOTIFY pgrst, 'reload schema': una columna nueva no es visible para
--     PostgREST hasta que se recarga el cache (mismo patron que adr051/adr073/adr079).
--   * El guard valida por evento (subconjunto dentro del MISMO evento), nunca
--     cruzando nombres entre eventos distintos.
--   * Si puntos_acceso del evento es NULL, el guard no falla: no hay lista base
--     contra la cual validar y no se inventa un fallo.
--
-- Caracteristicas: 100% ASCII (cero bytes > 127), cero tildes, cero emojis, cero
-- backticks, terminacion de linea LF. Solo ALTER TABLE ADD COLUMN, COMMENT y un
-- bloque DO de solo lectura. No crea tablas, indices, triggers ni vistas, no
-- hace UPDATE y no toca RLS.
--
-- Estado: ESCRITA, NO APLICADA. La aplicacion es MANUAL (ver BLOQUE 4).
-- ============================================================================


-- ----------------------------------------------------------------------------
-- BLOQUE 1: COLUMNA HERMANA EN eventos
--
-- jsonb (array de strings) y NO text[]: mismo tipo que eventos.puntos_acceso,
-- de modo que el front lo lee con el mismo helper. DEFAULT NULL explicito: la
-- columna nace inerte y ningun evento existente cambia de comportamiento. Se
-- agrega al FINAL de la tabla; ningun lector por posicion se altera.
-- ----------------------------------------------------------------------------

ALTER TABLE public.eventos
    ADD COLUMN IF NOT EXISTS puntos_generales jsonb DEFAULT NULL;

COMMENT ON COLUMN public.eventos.puntos_generales IS
  'Puntos de check-in GENERALES del evento (ADR-082). jsonb con array de strings (nombres de puntos), subconjunto de eventos.puntos_acceso del mismo evento. NULL o [] = ningun punto es general (todos son restringidos; mandan inscritos.puntos_acceso segun ADR-079/ADR-081). Si el punto pertenece a esta lista se IGNORA inscritos.puntos_acceso: cualquier inscrito del evento pasa por el, tenga o no ese punto en su override. Si no pertenece, aplica la regla vigente: inscritos.puntos_acceso NULL = hereda la lista del evento, [] = ninguno.';


-- ----------------------------------------------------------------------------
-- BLOQUE 2: GUARD DE INTEGRIDAD (solo lectura)
--
-- Falla si alguna fila declara un punto general que no existe en el
-- puntos_acceso de ESE MISMO evento, o si el valor no es un array jsonb.
-- Idempotente: no escribe nada, no crea objetos y no toca RLS; si los datos son
-- validos el bloque termina sin error y las 2+ ejecuciones son identicas.
-- Al correr esta migracion todas las filas estan en NULL, asi que pasa trivial.
-- Sirve como puerta de entrada para las cargas futuras (loader, seeds, admin).
--
-- Excepcion deliberada (NO se "corrige" el dato): es preferible que la carga
-- falle de forma ruidosa a que un punto general sin punto base quede vigente.
-- ----------------------------------------------------------------------------

DO $adr082_guard$
DECLARE
    v_tipo_malo text;
    v_nombres   text;
BEGIN
    -- (a) el valor, si no es NULL, debe ser un array jsonb.
    SELECT string_agg(ev.id || ' = ' || jsonb_typeof(ev.puntos_generales), ', ')
      INTO v_tipo_malo
      FROM public.eventos ev
     WHERE ev.puntos_generales IS NOT NULL
       AND jsonb_typeof(ev.puntos_generales) IS DISTINCT FROM 'array';

    IF v_tipo_malo IS NOT NULL THEN
        RAISE EXCEPTION
            'ADR-082: eventos.puntos_generales debe ser NULL o un array jsonb de strings. Valores invalidos: %',
            v_tipo_malo;
    END IF;

    -- (b) cada punto general debe existir en el puntos_acceso del MISMO evento.
    --     Si puntos_acceso NO es un array (NULL, objeto o scalar) no hay lista base
    --     utilizable: no se valida y no falla.
    --     El filtro jsonb_typeof es OBLIGATORIO y no un detalle: jsonb_array_elements_text()
    --     LANZA error ("cannot extract elements from a scalar object") sobre un objeto o un
    --     scalar. eventos.puntos_acceso es PREEXISTENTE y su DDL no esta en el repo, asi que
    --     no hay garantia de que todas las filas sean arrays. Sin este filtro el guard pasa en
    --     la 1a corrida (todo NULL, el WHERE no deja pasar filas) y revienta en la 2a, cuando
    --     el front ya haya escrito puntos_generales.
    --     jsonb_typeof(NULL) devuelve NULL, luego el filtro tambien excluye los NULL.
    SELECT string_agg(DISTINCT ev.id || ': ' || g.nombre, ', ')
      INTO v_nombres
      FROM public.eventos ev
      CROSS JOIN LATERAL jsonb_array_elements_text(ev.puntos_generales) AS g(nombre)
     WHERE ev.puntos_generales IS NOT NULL
       AND jsonb_typeof(ev.puntos_acceso) = 'array'
       AND NOT EXISTS (
               SELECT 1
                 FROM jsonb_array_elements_text(ev.puntos_acceso) AS pa(nombre)
                WHERE pa.nombre = g.nombre
           );

    IF v_nombres IS NOT NULL THEN
        RAISE EXCEPTION
            'ADR-082: puntos en eventos.puntos_generales que no existen en eventos.puntos_acceso del mismo evento (id: punto): %',
            v_nombres;
    END IF;
END $adr082_guard$;


-- ----------------------------------------------------------------------------
-- BLOQUE 3: RECARGA DEL SCHEMA CACHE DE POSTGREST
-- ----------------------------------------------------------------------------

NOTIFY pgrst, 'reload schema';


-- ============================================================================
-- BLOQUE 4: APLICACION MANUAL (NO hay script ni entrada de package.json)
--
-- Supabase CLI v2.84.2 no resuelve este archivo por si solo (no esta en una
-- carpeta linkada de supabase/migrations ni tiene npm script asociado), asi que
-- la via vigente es la Management API, rol postgres:
--   POST https://api.supabase.com/v1/projects/{ref}/database/query
--   body: { "query": "<contenido de este archivo>" }
-- Ejecutar UNA sola vez. Es idempotente, pero conviene una sola invocacion para
-- no partir el bloque DO en varias transacciones.
--
-- Verificacion posterior (solo lectura, ejecutar aparte):
--   SELECT column_name, data_type, is_nullable, column_default
--     FROM information_schema.columns
--    WHERE table_schema = 'public' AND table_name = 'eventos'
--      AND column_name = 'puntos_generales';
--   -- esperado: puntos_generales | jsonb | YES | NULL
--
--   SELECT count(*) AS eventos_con_puntos_generales
--     FROM public.eventos
--    WHERE puntos_generales IS NOT NULL;
--   -- esperado: 0 (no hay backfill; la columna nace inerte)
-- ============================================================================
-- ROLLBACK (documentado, comentado; requiere gate de riesgo).
-- Cero Borrado: NO se borra ninguna fila. El UPDATE deja la columna inerte
-- (equivale al comportamiento previo) y el DROP es opcional.
--   UPDATE public.eventos SET puntos_generales = NULL;
--   ALTER TABLE public.eventos DROP COLUMN IF EXISTS puntos_generales;
-- ============================================================================
