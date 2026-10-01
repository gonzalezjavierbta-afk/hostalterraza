-- ============================================================================
-- Migracion: diseno de ticket por tipo (content.ticket_disenos) - ADR-064.
-- Archivo : migrations/adr064_ticket_disenos.sql
-- Fecha   : 2026-09-30
-- Ejecutar: MANUALMENTE (Direccion). Es idempotente. NO se ejecuta por endpoint.
-- ============================================================================
--
-- QUE HACE
--   Agrega a eventos.config_landing.content el array `ticket_disenos` con una
--   entrada de tipo `pago` para el evento slug 'lanzamiento-mistico-64k6',
--   apuntando a la imagen /imagenes/tiket-rastro.jpg.
--
-- QUE NO HACE (deliberadamente)
--   - NO hay DDL. `eventos.config_landing` es una columna jsonb que YA existe;
--     esta migracion es PURO seed de datos. No crea columnas, indices, tipos,
--     triggers, vistas ni politicas.
--   - NO toca RLS ni llaves. No lee ni escribe claves privadas.
--   - NO toca ningun otro evento: el filtro es por
--     `slug = 'lanzamiento-mistico-64k6'` y el script ABORTA con NOTICE si el
--     evento no existe (0 filas) o avisa si la coincidencia no es unica (>1).
--   - NO borra ninguna llave existente (Regla de Oro #2 - Cero Borrado). Es una
--     adicion: no hay DELETE, ni `#-` sobre llaves preexistentes, ni replace
--     de `content`.
--   - NO reconstruye `content` entero (mismo riesgo documentado en
--     oneoff_lanzamiento_mistico_banners_f9b.sql: `content.gallery[2]` es un
--     base64 de ~30 KB y reconstruir `content` lo DESTRUYE).
--
-- ESTRUCTURA CONGELADA (no cambiar; la consume el kernel)
--   "ticket_disenos": [
--     { "tipo": "pago", "diseno_url": "/imagenes/tiket-rastro.jpg", "activo": true }
--   ]
--   Tipos validos del dominio: invitado | frecuente | artista | produccion | pago.
--
-- POR QUE jsonb_set Y NO un replace
--   `jsonb_set(config_landing, '{content,ticket_disenos}', ..., true)` es merge
--   superficial: crea o sobrescribe SOLO esa ruta y preserva TODAS las llaves
--   hermanas de `content` (gallery, dj_lineup, meta, sponsors, whatsapp,
--   form_solo, banners, playlist_url, comunidad_whatsapp, etc.) y las del
--   top-level de `config_landing` (theme, version, ...). El `create_missing`
--   en `true` tambien crea `content` si el evento aun no lo tuviera.
--
-- IDEMPOTENCIA (corre 2 veces sin romper, y sin escribir si nada cambio)
--   El merge se hace a nivel de ELEMENTO del array, no de la llave:
--     1) se filtran los elementos existentes cuyo `tipo = 'pago'`;
--     2) se conservan, en su orden original, los elementos de los demas tipos
--        (invitado, frecuente, artista, produccion);
--     3) se anexa al final la entrada canonica de tipo `pago`.
--   Resultado: 1era corrida sobre un evento sin la llave -> crea el array con
--   1 elemento. 2da corrida -> reconstruye el MISMO array -> el predicado
--   `IS DISTINCT FROM` hace que el UPDATE no escriba nada (0 filas) y se
--   conserva el resto de `config_landing` intacto.
--
-- ASCII-SAFETY
--   SQL 100% ASCII (0 bytes no-ASCII). No aplica el Escudo GOLD de
--   api/*.js / admin.html / index.html / pagina-destino.js: aqui no hay JS.
--   Verificacion: `Select-String -Path <este archivo> -Pattern '[^\x00-\x7F]'`
--   debe devolver 0 coincidencias.
-- ============================================================================


BEGIN;

-- ----------------------------------------------------------------------------
-- FASE 1 - VERIFICACION PREVIA (solo lectura). Dejar el resultado a la vista.
-- ----------------------------------------------------------------------------
SELECT
  id,
  slug,
  config_landing->>'theme'                                    AS theme_actual,
  jsonb_typeof(config_landing->'content')                      AS content_tipo,
  config_landing->'content' ? 'ticket_disenos'                 AS ya_tiene_ticket_disenos,
  COALESCE(jsonb_array_length(
    CASE WHEN jsonb_typeof(config_landing->'content'->'ticket_disenos') = 'array'
         THEN config_landing->'content'->'ticket_disenos'
         ELSE '[]'::jsonb END), 0)                             AS ticket_disenos_items,
  config_landing->'content'->'ticket_disenos'                  AS ticket_disenos_actual,
  COALESCE(jsonb_array_length(COALESCE(config_landing->'content'->'gallery','[]'::jsonb)), 0)
                                                               AS gallery_items,
  COALESCE(jsonb_array_length(COALESCE(config_landing->'content'->'dj_lineup','[]'::jsonb)), 0)
                                                               AS lineup_items
FROM eventos
WHERE slug = 'lanzamiento-mistico-64k6';
-- Esperado: 1 fila. Si ticket_disenos_actual es NULL -> el evento aun no tiene
--           la llave y se creara con 1 elemento. Si ya tiene la llave, se
--           conservaran los tipos distintos de 'pago'.
-- Si devuelve 0 filas: la migracion NO escribira nada (ver guard en FASE 2).


-- ----------------------------------------------------------------------------
-- FASE 2 - ESCRITURA IDEMPOTENTE CON GUARD POR SLUG.
--   - 0 filas del evento  -> NOTICE y aborted (no escribe nada).
--   - >1 filas del evento -> NOTICE de ambiguedad y aborted (no escribe nada).
--   - merge superficial de SOLO content.ticket_disenos; el resto se preserva.
-- ----------------------------------------------------------------------------
DO $mig$
DECLARE
  v_total  integer;
  v_cambia integer;
BEGIN
  -- GUARD 1: el evento debe existir (por slug, nunca por id hardcodeado).
  SELECT count(*) INTO v_total
    FROM eventos
   WHERE slug = 'lanzamiento-mistico-64k6';

  IF v_total = 0 THEN
    RAISE NOTICE 'adr064: ABORTADO. No existe ningun evento con slug=% -> no se escribio nada.',
                 'lanzamiento-mistico-64k6';
    RETURN;
  END IF;

  -- GUARD 2: la coincidencia debe ser unica (esta migracion es oneoff de 1 fila).
  IF v_total > 1 THEN
    RAISE NOTICE 'adr064: ABORTADO. El slug=% devuelve % filas (se esperaba 1) -> no se escribio nada. Resolver el duplicado antes de reintentar.',
                 'lanzamiento-mistico-64k6', v_total;
    RETURN;
  END IF;

  -- ESCRITURA: merge a nivel de elemento del array + jsonb_set superficial.
  WITH arr AS (
    SELECT COALESCE(config_landing, '{}'::jsonb) AS cl
      FROM eventos
     WHERE slug = 'lanzamiento-mistico-64k6'
  ),
  limpio AS (
    -- Conserva los elementos de los OTROS tipos, en su orden original.
    SELECT a.cl,
           COALESCE((
             SELECT jsonb_agg(x.val ORDER BY x.ord)
               FROM (
                 SELECT z.ord, z.val
                   FROM arr a2
                   CROSS JOIN LATERAL jsonb_array_elements(
                     CASE WHEN jsonb_typeof(a2.cl->'content'->'ticket_disenos') = 'array'
                          THEN a2.cl->'content'->'ticket_disenos'
                          ELSE '[]'::jsonb END
                   ) WITH ORDINALITY AS z(val, ord)
                  WHERE COALESCE(z.val->>'tipo','') <> 'pago'
               ) x
           ), '[]'::jsonb)
             || '[{"tipo":"pago","diseno_url":"/imagenes/tiket-rastro.jpg","activo":true}]'::jsonb
             AS arr_final
      FROM arr a
  )
  UPDATE eventos e
     SET config_landing = jsonb_set(c.cl, '{content,ticket_disenos}', c.arr_final, true)
    FROM limpio c
   WHERE e.slug = 'lanzamiento-mistico-64k6'
     AND e.config_landing IS DISTINCT FROM
         jsonb_set(c.cl, '{content,ticket_disenos}', c.arr_final, true);

  GET DIAGNOSTICS v_cambia = ROW_COUNT;

  IF v_cambia = 0 THEN
    RAISE NOTICE 'adr064: OK, sin escritura. content.ticket_disenos ya estaba en el estado esperado (idempotente).';
  ELSE
    RAISE NOTICE 'adr064: OK, % fila(s) actualizada(s) en el evento % (content.ticket_disenos). Resto de config_landing preservado.',
                 v_cambia, 'lanzamiento-mistico-64k6';
  END IF;
END
$mig$;


-- ----------------------------------------------------------------------------
-- FASE 3 - VERIFICACION POSTERIOR (solo lectura).
--   content.ticket_disenos DEBE tener 1 elemento de tipo 'pago' con
--   diseno_url='/imagenes/tiket-rastro.jpg' y activo=true.
--   gallery_items y lineup_items NO deben cambiar respecto de FASE 1, y todas
--   las conserva_* deben seguir en true. Si algo se pierde: ejecutar el
--   ROLLBACK de abajo INMEDIATAMENTE y detenerse.
-- ----------------------------------------------------------------------------
SELECT
  id,
  config_landing->>'theme'                                     AS theme_despues,
  config_landing->'content'->'ticket_disenos'                  AS ticket_disenos_despues,
  COALESCE(jsonb_array_length(
    CASE WHEN jsonb_typeof(config_landing->'content'->'ticket_disenos') = 'array'
         THEN config_landing->'content'->'ticket_disenos'
         ELSE '[]'::jsonb END), 0)                              AS ticket_disenos_items,
  config_landing->'content'->'ticket_disenos'->0->>'tipo'       AS td0_tipo,
  config_landing->'content'->'ticket_disenos'->0->>'diseno_url' AS td0_diseno_url,
  config_landing->'content'->'ticket_disenos'->0->>'activo'     AS td0_activo,
  COALESCE(jsonb_array_length(COALESCE(config_landing->'content'->'gallery','[]'::jsonb)), 0)
                                                               AS gallery_items,
  COALESCE(jsonb_array_length(COALESCE(config_landing->'content'->'dj_lineup','[]'::jsonb)), 0)
                                                               AS lineup_items,
  config_landing->'content' ? 'meta'            AS conserva_meta,
  config_landing->'content' ? 'banners'         AS conserva_banners,
  config_landing->'content' ? 'sponsors'         AS conserva_sponsors,
  config_landing->'content' ? 'whatsapp'         AS conserva_whatsapp,
  config_landing->'content' ? 'form_solo'        AS conserva_form,
  config_landing->'content' ? 'playlist_url'     AS conserva_playlist,
  config_landing->'content' ? 'comunidad_whatsapp'
                                                               AS conserva_comunidad_whatsapp
FROM eventos
WHERE slug = 'lanzamiento-mistico-64k6';
-- Esperado: 1 fila; ticket_disenos_items=1; td0_tipo='pago';
--           td0_diseno_url='/imagenes/tiket-rastro.jpg'; td0_activo='true';
--           gallery_items y lineup_items identicos a FASE 1; conserva_*=true.

COMMIT;


-- ============================================================================
-- ROLLBACK (solo si FASE 3 sale mal)
-- ----------------------------------------------------------------------------
-- OPCION A (preferida) - quita SOLO la entrada de tipo 'pago' y conserva
-- content.ticket_disenos con los tipos restantes. Si al filtrar el array
-- queda vacio, se quita la llave completa (dejandola como estaba antes de la
-- 1era corrida si no existia). Nunca toca el resto de `content`.
--
-- BEGIN;
-- DO $rb$
-- DECLARE
--   v_restante jsonb;
-- BEGIN
--   SELECT COALESCE((
--            SELECT jsonb_agg(x.val ORDER BY x.ord)
--              FROM (
--                SELECT z.ord, z.val
--                  FROM eventos e
--                  CROSS JOIN LATERAL jsonb_array_elements(
--                    CASE WHEN jsonb_typeof(e.config_landing->'content'->'ticket_disenos') = 'array'
--                         THEN e.config_landing->'content'->'ticket_disenos'
--                         ELSE '[]'::jsonb END
--                  ) WITH ORDINALITY AS z(val, ord)
--                 WHERE e.slug = 'lanzamiento-mistico-64k6'
--                   AND COALESCE(z.val->>'tipo','') <> 'pago'
--              ) x
--          ), '[]'::jsonb)
--     INTO v_restante;
--
--   UPDATE eventos
--      SET config_landing = CASE
--            WHEN jsonb_array_length(v_restante) = 0
--              THEN config_landing #- '{content,ticket_disenos}'
--            ELSE jsonb_set(config_landing, '{content,ticket_disenos}', v_restante, true)
--          END
--    WHERE slug = 'lanzamiento-mistico-64k6';
--   RAISE NOTICE 'adr064 ROLLBACK: retirada la entrada tipo=pago de content.ticket_disenos.';
-- END
-- $rb$;
-- COMMIT;
--
-- OPCION B (destructiva, solo emergency) - quita la llave completa
-- content.ticket_disenos, incluidos los tipos que otro agente haya agregado.
-- NO se ejecuta sin confirmacion de Direccion (Cero Borrado - Regla de Oro #2).
--
-- BEGIN;
-- UPDATE eventos
--    SET config_landing = config_landing #- '{content,ticket_disenos}'
--  WHERE slug = 'lanzamiento-mistico-64k6';
-- COMMIT;
-- ============================================================================
