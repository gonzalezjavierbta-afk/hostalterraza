-- ============================================================================
-- ADR-083 | Puntos de solo seleccionados: rompe la herencia del ticket
-- ----------------------------------------------------------------------------
-- Archivo   : migrations/adr083_puntos_solo_seleccionados.sql
-- Fecha     : 2026-10-10
-- Proposito : agregar el TERCER modo de acceso por punto de escaneo. Los 3 modos
--             son EXCLUYENTES por punto:
--               1. HEREDA (default, el vigente) -> ADR-079/ADR-081
--               2. GENERAL -> eventos.puntos_generales (ADR-082)
--               3. SOLO SELECCIONADOS -> esta migracion (nueva columna)
--
-- RELACION CON ADR-082:
--   * migrations/adr082_puntos_generales.sql YA FUE APLICADA en la base de datos
--     (commit 7317b9d). Ese archivo NO se modifica y NO se re-ejecuta.
--   * Esta migracion es un archivo NUEVO e INDEPENDIENTE: no altera la 082, no
--     redefine puntos_generales y NO hace backfill de datos.
--   * La 082 solo puede leerse como precedente de estilo y como columna hermana
--     sobre la que se aplica la validacion (c).
--
-- HALLAZGO (esquema real):
--   * public.eventos.puntos_acceso = jsonb, array de strings con NOMBRES de
--     puntos (ej. ["Ancestral"]). PREEXISTENTE: su DDL original no esta en el
--     repo. Ver migrations/adr079_multi_punto_override.sql linea 22 y
--     BLUEPRINT.md linea 83. Por eso el guard filtra jsonb_typeof SIEMPRE.
--   * public.inscritos.puntos_acceso = jsonb (ADR-079). Override por ticket:
--     NULL = hereda la lista base del evento; [] = ninguno; con valor = solo esos.
--   * public.eventos.puntos_generales = jsonb (ADR-082, aplicada): si el punto
--     esta ahi, pasa CUALQUIER inscrito y se ignora inscritos.puntos_acceso.
--
-- SEMANTICA FIJADA (lectura de scanner / admin):
--   * eventos.puntos_solo_seleccionados es un jsonb array de strings (nombres de
--     puntos) y DEBE ser un subconjunto de eventos.puntos_acceso del mismo evento.
--   * NULL (y tambien []) = NINGUN punto es de solo seleccionados. Es el default
--     y preserva EXACTAMENTE el comportamiento actual (modo HEREDA).
--   * Un punto P es SOLO SELECCIONADOS si P pertenece a
--     eventos.puntos_solo_seleccionados.
--   * Si P es SOLO SELECCIONADOS ROMPE LA HERENCIA: solo pasa quien tenga P de
--     forma EXPLICITA en su inscritos.puntos_acceso. Quien tiene NULL (o [])
--     DEJA DE PASAR. Esto es lo unico que cambia frente a la regla vigente.
--   * Si P NO es solo seleccionados: si es general manda la 082; si no, manda
--     ADR-079/ADR-081 (NULL hereda, [] ninguno, con valor solo esos).
--
-- DECISION:
--   * Columna hermana en eventos, no tabla de permisos: el dato pertenece al
--     evento y se lee en la misma consulta que ya trae puntos_acceso y
--     puntos_generales.
--   * jsonb (no text[]) por simetria de tipo con puntos_acceso y
--     puntos_generales, para que el front lo trate con el mismo helper.
--   * DEFAULT NULL a proposito: cero backfill. Los eventos que ya existen quedan
--     en modo HEREDA, que es su comportamiento actual. No se hace ningun UPDATE.
--   * La columna es INERTE: no hay trigger, no hay vista, no se toca RLS, ni
--     politicas, ni permisos, ni grants. Cero impacto en seguridad.
--   * El ADR documental (DECISIONS.md) sigue DIFERIDO por modo express, igual que
--     en la 082. Este archivo deja fijada la semantica; el ADR solo la narrara.
--     NO se inventa aqui el texto del ADR.
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
--     PostgREST hasta que se recarga el cache (mismo patron que adr051/adr073/
--     adr079/adr082).
--   * El guard valida por evento (subconjunto dentro del MISMO evento), nunca
--     cruzando nombres entre eventos distintos.
--   * Si puntos_acceso del evento no es un array, el guard (b) no falla: no hay
--     lista base utilizable y no se inventa un fallo.
--
-- Caracteristicas: 100% ASCII (cero bytes > 127), cero tildes, cero emojis, cero
-- backticks, terminacion de linea LF. Solo ALTER TABLE ADD COLUMN, COMMENT y un
-- bloque DO de solo lectura. No crea tablas, indices, triggers ni vistas, no
-- hace UPDATE y no toca RLS.
--
-- Estado: ESCRITA, NO APLICADA. La aplicacion es MANUAL (ver BLOQUE 4).
-- ============================================================================


-- ----------------------------------------------------------------------------
-- BLOQUE 1: TERCERA COLUMNA HERMANA EN eventos
--
-- jsonb (array de strings) y NO text[]: mismo tipo que eventos.puntos_acceso y
-- eventos.puntos_generales, de modo que el front lo lee con el mismo helper.
-- DEFAULT NULL explicito: la columna nace inerte y ningun evento existente cambia
-- de comportamiento. Se agrega al FINAL de la tabla; ningun lector por posicion
-- se altera. UNA sola sentencia idempotente.
-- ----------------------------------------------------------------------------

ALTER TABLE public.eventos
    ADD COLUMN IF NOT EXISTS puntos_solo_seleccionados jsonb DEFAULT NULL;

COMMENT ON COLUMN public.eventos.puntos_solo_seleccionados IS
  'Puntos de check-in de SOLO SELECCIONADOS del evento (ADR-083). jsonb con array de strings (nombres de puntos), subconjunto de eventos.puntos_acceso del mismo evento. NULL o [] = ningun punto es solo seleccionados (todos siguen en modo HEREDA, mandan inscritos.puntos_acceso segun ADR-079/ADR-081). Si el punto pertenece a esta lista ROMPE LA HERENCIA: solo pasa quien tenga ese punto de forma EXPLICITA en su inscritos.puntos_acceso; el que tenga NULL o [] deja de pasar. Si NO pertenece, aplica la regla vigente: si es general manda ADR-082 y se ignora inscritos.puntos_acceso; si no, inscritos.puntos_acceso NULL = hereda la lista del evento, [] = ninguno.';


-- ----------------------------------------------------------------------------
-- BLOQUE 2: GUARD DE INTEGRIDAD (solo lectura)
--
-- Tres validaciones:
--   (a) el valor, si no es NULL, debe ser un array jsonb;
--   (b) cada nombre debe existir en eventos.puntos_acceso del MISMO evento,
--       con el filtro jsonb_typeof(ev.puntos_acceso) = 'array' OBLIGATORIO:
--       jsonb_array_elements_text() LANZA error sobre un objeto o un scalar, y
--       puntos_acceso es PREEXISTENTE sin DDL en el repo;
--   (c) un nombre NO puede estar a la vez en puntos_solo_seleccionados y en
--       puntos_generales del mismo evento: son modos excluyentes por punto.
-- El guard se apoya en una columna preexistente (puntos_generales, ya aplicada),
-- asi que tambien la protege: si alguien carga ahi un nombre que colisiona con
-- esta columna, el error salta aqui igual.
-- Idempotente: no escribe nada, no crea objetos y no toca RLS; si los datos son
-- validos el bloque termina sin error y las 2+ ejecuciones son identicas.
-- Al correr esta migracion todas las filas estan en NULL, asi que pasa trivial.
-- Sirve como puerta de entrada para las cargas futuras (loader, seeds, admin).
--
-- Excepcion deliberada (NO se "corrige" el dato): es preferible que la carga
-- falle de forma ruidosa a que queden puntos validos con un modo ambiguo.
-- ----------------------------------------------------------------------------

DO $adr083_guard$
DECLARE
    v_tipo_malo text;
    v_nombres   text;
    v_solape    text;
BEGIN
    -- (a) el valor, si no es NULL, debe ser un array jsonb.
    SELECT string_agg(ev.id || ' = ' || jsonb_typeof(ev.puntos_solo_seleccionados), ', ')
      INTO v_tipo_malo
      FROM public.eventos ev
     WHERE ev.puntos_solo_seleccionados IS NOT NULL
       AND jsonb_typeof(ev.puntos_solo_seleccionados) IS DISTINCT FROM 'array';

    IF v_tipo_malo IS NOT NULL THEN
        RAISE EXCEPTION
            'ADR-083: eventos.puntos_solo_seleccionados debe ser NULL o un array jsonb de strings. Valores invalidos: %',
            v_tipo_malo;
    END IF;

    -- (b) cada punto solo seleccionado debe existir en el puntos_acceso del MISMO
    --     evento. Si puntos_acceso NO es un array (NULL, objeto o scalar) no hay
    --     lista base utilizable: no se valida y no falla.
    --     El filtro jsonb_typeof es OBLIGATORIO y no un detalle: jsonb_array_elements_text()
    --     LANZA error ("cannot extract elements from a scalar object") sobre un objeto o un
    --     scalar. eventos.puntos_acceso es PREEXISTENTE y su DDL no esta en el repo, asi que
    --     no hay garantia de que todas las filas sean arrays. Sin este filtro el guard pasa en
    --     la 1a corrida (todo NULL, el WHERE no deja pasar filas) y revienta en la 2a, cuando
    --     el front ya haya escrito puntos_solo_seleccionados.
    --     jsonb_typeof(NULL) devuelve NULL, luego el filtro tambien excluye los NULL.
    SELECT string_agg(DISTINCT ev.id || ': ' || s.nombre, ', ')
      INTO v_nombres
      FROM public.eventos ev
      CROSS JOIN LATERAL jsonb_array_elements_text(ev.puntos_solo_seleccionados) AS s(nombre)
     WHERE ev.puntos_solo_seleccionados IS NOT NULL
       AND jsonb_typeof(ev.puntos_acceso) = 'array'
       AND NOT EXISTS (
               SELECT 1
                 FROM jsonb_array_elements_text(ev.puntos_acceso) AS pa(nombre)
                WHERE pa.nombre = s.nombre
           );

    IF v_nombres IS NOT NULL THEN
        RAISE EXCEPTION
            'ADR-083: puntos en eventos.puntos_solo_seleccionados que no existen en eventos.puntos_acceso del mismo evento (id: punto): %',
            v_nombres;
    END IF;

    -- (c) EXCLUSIVIDAD DE MODOS: un mismo nombre no puede estar simultaneamente en
    --     puntos_solo_seleccionados y en puntos_generales del MISMO evento, porque
    --     los modos son excluyentes por punto (rompe la herencia vs. pasa todos).
    --     Mismo aprendizaje que (b): puntos_generales es una columna contra la que
    --     se valida y por tanto tambien se protege; sin el filtro jsonb_typeof el
    --     guard pasaria en la 1a corrida y reventaria en la 2a si alguien guardo
    --     alli un objeto o un scalar.
    SELECT string_agg(DISTINCT ev.id || ': ' || s.nombre, ', ')
      INTO v_solape
      FROM public.eventos ev
      CROSS JOIN LATERAL jsonb_array_elements_text(ev.puntos_solo_seleccionados) AS s(nombre)
     WHERE ev.puntos_solo_seleccionados IS NOT NULL
       AND jsonb_typeof(ev.puntos_generales) = 'array'
       AND EXISTS (
               SELECT 1
                 FROM jsonb_array_elements_text(ev.puntos_generales) AS ge(nombre)
                WHERE ge.nombre = s.nombre
           );

    IF v_solape IS NOT NULL THEN
        RAISE EXCEPTION
            'ADR-083: puntos a la vez en eventos.puntos_solo_seleccionados y en eventos.puntos_generales del mismo evento; los modos son excluyentes (id: punto): %',
            v_solape;
    END IF;
END $adr083_guard$;


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
-- Ejecutar UNA sola vez, en UNA sola transaccion, para no partir el bloque DO en
-- varias transacciones. Es idempotente, pero conviene una sola invocacion.
--
-- Verificacion posterior (solo lectura, ejecutar aparte):
--   SELECT column_name, data_type, is_nullable, column_default
--     FROM information_schema.columns
--    WHERE table_schema = 'public' AND table_name = 'eventos'
--      AND column_name = 'puntos_solo_seleccionados';
--   -- esperado: puntos_solo_seleccionados | jsonb | YES | NULL
--
--   SELECT count(*) AS eventos_con_puntos_solo_seleccionados
--     FROM public.eventos
--    WHERE puntos_solo_seleccionados IS NOT NULL;
--   -- esperado: 0 (no hay backfill; la columna nace inerte)
-- ============================================================================
-- ROLLBACK (documentado, comentado; requiere gate de riesgo).
-- Cero Borrado: NO se borra ninguna fila. El UPDATE deja la columna inerte
-- (equivale al comportamiento previo) y el DROP es opcional.
--   UPDATE public.eventos SET puntos_solo_seleccionados = NULL;
--   ALTER TABLE public.eventos DROP COLUMN IF EXISTS puntos_solo_seleccionados;
-- ============================================================================