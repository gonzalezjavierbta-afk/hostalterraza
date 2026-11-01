-- ============================================================================
-- ADR-088 | Coordenadas WGS84 del recinto por evento (eventos.lat / eventos.lng)
-- ----------------------------------------------------------------------------
-- Archivo   : migrations/adr088_eventos_coordenadas.sql
-- Fecha     : 2026-11-01
-- Proposito : dotar a public.eventos de dos columnas numericas opcionales con
--             la latitud y la longitud EXACTAS del recinto donde ocurre el
--             evento, para que el mapa del kernel apunte al punto correcto y no
--             dependa de adivinar la ciudad a partir de una direccion de calle.
--
-- HALLAZGO (estado real del esquema, verificado contra produccion via REST y
--          contra el codigo del kernel):
--   * public.eventos tiene 29 columnas. NO existe lat, NO existe lng y NO hay
--     ninguna columna de coordenadas de ningun tipo.
--   * public.eventos.ubicacion es texto libre y contiene SOLO direccion de
--     calle, sin ciudad y sin pais. Ejemplos reales en produccion:
--       "Klandestino, Kr 4 # 19-56"
--       "Cr 4 # 19-56 Piso 4"
--       "Calle 19 # 4-20"
--       "cra 19a # 61b-82"
--   * El kernel evento-app.html:2397 arma el embed de Google Maps asi:
--       https://maps.google.com/maps?q=<encodeURIComponent(ev.ubicacion)>
--       &t=&z=15&ie=UTF8&iwloc=&output=embed
--     Sin ciudad y sin coordenadas Google no acierta el punto: ese es el bug
--     reportado ("el mapa no muestra la ubicacion del evento").
--   * Los silos f12 y f9b sortean el problema con un token CSS hardcodeado:
--       --f12-mapa-query: 4.60393995301205,-74.06869074365889;
--     en css/templates/fiesta/f12.css:115 y css/templates/fiesta/f9b.css:273.
--     Ese par corresponde al recinto "Cr 4 # 19-56" (Klandestino) y YA esta
--     validado en produccion: es el unico valor que esta migracion reutiliza.
--
-- SEMANTICA FIJADA:
--   * lat y lng son double precision y son OPCIONALES (NULL permitido).
--   * Cuando AMBAS estan presentes son la verdad del mapa y MANDAN sobre
--     eventos.ubicacion: el embed se arma con las coordenadas y ubicacion queda
--     solo como texto para el usuario.
--   * Cuando faltan (NULL), el front conserva el comportamiento actual: usar
--     ubicacion como query de Google Maps.
--   * Rangos validados por CHECK: lat -90..90 y lng -180..180. NULL pasa.
--
-- DECISION SOBRE EL BACKFILL (deliberadamente minimo):
--   * Se cargan las coordenadas del recinto Klandestino SOLO en los 3 eventos
--     cuyo texto de ubicacion corresponde a esa direccion, y solo si ambas
--     columnas estan en NULL.
--   * NO se inventan coordenadas para las otras direcciones ("Calle 19 # 4-20",
--     "cra 19a # 61b-82", etc). Esas filas quedan en NULL a proposito hasta que
--     Direccion las cargue desde admin con el punto exacto en el mapa.
--   * Geocodificar por aproximacion seria peor que no tener el dato: un mapa
--     que apunta a la cuadra equivocada es un bug nuevo, no una mejora.
--
-- ALCANCE DE SEGURIDAD (explicito):
--   * NO se toca RLS, NI policies, NI roles, NI grants, NI triggers, NI vistas.
--     El cliente pide eventos a Supabase con la clave ANON y la lectura publica
--     ya vigente cubre las columnas nuevas: agregar columnas no cambia ninguna
--     politica. Cero impacto en el modelo de acceso.
--   * No hay datos sensibles: lat/lng del recinto son un dato publico por
--     definicion (el evento se anuncia con direccion).
--
-- ADITIVA, CERO BORRADO (Oro #2) Y REVERSIBLE:
--   * ADD COLUMN IF NOT EXISTS: cambio de metadata, no reescribe filas.
--   * No se elimina ninguna columna, fila, constraint ni politica existente.
--   * Reversible con DROP COLUMN (ver ROLLBACK al final, comentado).
--
-- Idempotencia (ADR-008): 100%. ADD COLUMN IF NOT EXISTS, COMMENT ON COLUMN
-- (reemplaza el texto anterior), constraints dentro de bloque DO con
-- EXCEPTION WHEN duplicate_object, y el UPDATE del backfill filtrado por
-- lat IS NULL AND lng IS NULL (no sobrescribe una coordenada ya cargada desde
-- admin). El archivo puede correrse 2+ veces sin error ni efecto adicional.
--
-- Notas tecnicas:
--   * Todo dentro de BEGIN/COMMIT: si algo falla no queda esquema a medias.
--   * NOTIFY pgrst, 'reload schema': una columna nueva no es visible para
--     PostgREST hasta recargar el cache (mismo patron que adr051/adr073/
--     adr079/adr082).
--   * 100% ASCII (cero bytes > 127): cero tildes, cero emojis, cero backticks.
--     Ver BUG-026 (emoji en SQL rompe la carga).
--
-- Estado: ESCRITA, NO APLICADA. La aplicacion es MANUAL y la ejecuta Direccion
--         en el SQL Editor de Supabase con service_role (ver final del archivo).
-- ============================================================================

BEGIN;


-- ----------------------------------------------------------------------------
-- BLOQUE 1: COLUMNAS lat / lng
--
-- double precision y no numeric(x,y): es el tipo nativo de PostGIS y de las
-- APIs de mapas, sin perdida practica para un punto de recinto. DEFAULT NULL
-- explicito: las 3+ filas existentes no cambian de comportamiento hasta que el
-- backfill del BLOQUE 4 las toque. Se agregan al FINAL: ningun lector por
-- posicion se altera.
-- ----------------------------------------------------------------------------

ALTER TABLE public.eventos
    ADD COLUMN IF NOT EXISTS lat double precision DEFAULT NULL;

ALTER TABLE public.eventos
    ADD COLUMN IF NOT EXISTS lng double precision DEFAULT NULL;

COMMENT ON COLUMN public.eventos.lat IS
  'Latitud WGS84 EXACTA del recinto del evento (ADR-088), en grados decimales. NULL = desconocida. Si lat y lng estan presentes MANDAN sobre eventos.ubicacion: el embed de Google Maps se arma con estas coordenadas y ubicacion queda solo como texto visible. Si son NULL el front conserva el comportamiento anterior (usar ubicacion como query). Rango validado por CHECK -90..90.';

COMMENT ON COLUMN public.eventos.lng IS
  'Longitud WGS84 EXACTA del recinto del evento (ADR-088), en grados decimales (valores negativos al oeste de Greenwich: Colombia queda negativa). NULL = desconocida. Si lat y lng estan presentes MANDAN sobre eventos.ubicacion: el embed de Google Maps se arma con estas coordenadas y ubicacion queda solo como texto visible. Si son NULL el front conserva el comportamiento anterior (usar ubicacion como query). Rango validado por CHECK -180..180.';


-- ----------------------------------------------------------------------------
-- BLOQUE 2: RANGO VALIDO (CHECK idempotente)
--
-- Un CHECK de SQL deja pasar NULL por definicion (el resultado es UNKNOWN, no
-- FALSE), pero se escribe explicito (IS NULL OR rango) para que la intencion no
-- dependa de esa regla. Bloque DO con EXCEPTION WHEN duplicate_object: en la
-- segunda corrida el ADD CONSTRAINT falla con 42710 y se absorbe sin error, de
-- modo que el archivo es re-ejecutable sin cambios.
--
-- Nombre estable de constraint: eventos_lat_rango_chk / eventos_lng_rango_chk.
-- ----------------------------------------------------------------------------

DO $adr088_lat$
BEGIN
    ALTER TABLE public.eventos
        ADD CONSTRAINT eventos_lat_rango_chk
        CHECK (lat IS NULL OR (lat BETWEEN -90 AND 90));
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $adr088_lat$;

DO $adr088_lng$
BEGIN
    ALTER TABLE public.eventos
        ADD CONSTRAINT eventos_lng_rango_chk
        CHECK (lng IS NULL OR (lng BETWEEN -180 AND 180));
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $adr088_lng$;


-- ----------------------------------------------------------------------------
-- BLOQUE 3: (reservado / sin cambios de datos masivos)
--
-- No hay normalizacion de ubicacion en esta migracion. ubicacion se queda tal
-- cual: es texto visible para el usuario y reescribirlo rompe el contrato de
-- lectura del kernel y de las paginas de destino.
-- ----------------------------------------------------------------------------


-- ----------------------------------------------------------------------------
-- BLOQUE 4: BACKFILL MINIMO - recinto Klandestino
--
-- 4.60393995301205, -74.06869074365889 son las MISMAS coordenadas ya probadas en
-- produccion para la direccion "Cr 4 # 19-56" (Klandestino): es el token
-- --f12-mapa-query de css/templates/fiesta/f12.css:115 y f9b.css:273. No se
-- geocodifica nada nuevo aqui.
--
-- Solo los 3 eventos cuyo texto de ubicacion cae en esa direccion. Filtro
-- lat IS NULL AND lng IS NULL: si Direccion ya cargo un punto desde admin, el
-- UPDATE no lo pisa (Cero Borrado tambien aplica a datos correctos).
--
-- El resto de eventos queda NULL A PROPOSITO (ver DECISION SOBRE EL BACKFILL en
-- la cabecera): las otras direcciones deben cargarse desde admin con el punto
-- exacto.
-- ----------------------------------------------------------------------------

UPDATE public.eventos
   SET lat = 4.60393995301205,
       lng = -74.06869074365889
 WHERE slug IN (
           'vinilos-inversos-c8yu',
           'lanzamiento-mistico-64k6',
           'kande-musica-tradicional-del-caribe-kk4c'
       )
   AND lat IS NULL
   AND lng IS NULL;


-- ----------------------------------------------------------------------------
-- BLOQUE 5: RECARGA DEL CACHE DE SCHEMA DE POSTGREST
-- ----------------------------------------------------------------------------

NOTIFY pgrst, 'reload schema';

COMMIT;


-- ============================================================================
-- VERIFICACION POSTERIOR (comentado, NO ejecutable desde este archivo).
-- Correr aparte en el SQL Editor, despues del COMMIT.
-- ============================================================================

-- [1/3] Columnas creadas (esperado: 2 filas, lat y lng, double precision, YES, NULL)
-- SELECT column_name, data_type, is_nullable, column_default
--   FROM information_schema.columns
--  WHERE table_schema = 'public'
--    AND table_name   = 'eventos'
--    AND column_name IN ('lat', 'lng')
--  ORDER BY column_name;

-- [2/3] Constraints de rango (esperado: eventos_lat_rango_chk y eventos_lng_rango_chk)
-- SELECT con.conname, pg_get_constraintdef(con.oid) AS definicion
--   FROM pg_constraint con
--   JOIN pg_class     rel ON rel.oid = con.conrelid
--   JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
--  WHERE nsp.nspname = 'public'
--    AND rel.relname = 'eventos'
--    AND con.conname IN ('eventos_lat_rango_chk', 'eventos_lng_rango_chk')
--  ORDER BY con.conname;

-- [3/3] Filas con coordenadas cargadas (esperado: 3 filas, todas 4.60393995301205 / -74.06869074365889)
-- SELECT slug, ubicacion, lat, lng
--   FROM public.eventos
--  WHERE lat IS NOT NULL AND lng IS NOT NULL
--  ORDER BY slug;
-- -- y el total, para confirmar que el resto queda NULL a proposito:
-- SELECT count(*) AS total,
--        count(lat) AS con_lat,
--        count(*) - count(lat) AS sin_coordenadas
--   FROM public.eventos;


-- ============================================================================
-- APLICACION MANUAL (NO hay script, NO hay entrada de package.json, NO hay
-- credenciales en el repo): la ejecuta Direccion.
--
--   1. Supabase Dashboard -> SQL Editor -> New query.
--   2. Pegar TODO este archivo (BEGIN ... COMMIT) y ejecutar UNA sola vez.
--      Es idempotente, pero una sola invocacion evita partir la transaccion.
--   3. Correr las 3 queries de verificacion de arriba.
--   4. Avisar al kernel/backend para que usen lat/lng cuando existan (fuera del
--      alcance de esta migracion; esta migracion solo habilita el dato).
-- ============================================================================
-- ROLLBACK (documentado, comentado, requiere gate de riesgo).
-- Cero Borrado: NO se borra ninguna fila. Solo se retiran las 2 columnas y sus
-- 2 constraints. Al revertir, el front vuelve al comportamiento anterior
-- (emplear ubicacion como query del mapa).
--   ALTER TABLE public.eventos DROP CONSTRAINT IF EXISTS eventos_lat_rango_chk;
--   ALTER TABLE public.eventos DROP CONSTRAINT IF EXISTS eventos_lng_rango_chk;
--   ALTER TABLE public.eventos DROP COLUMN IF EXISTS lat;
--   ALTER TABLE public.eventos DROP COLUMN IF EXISTS lng;
-- ============================================================================
