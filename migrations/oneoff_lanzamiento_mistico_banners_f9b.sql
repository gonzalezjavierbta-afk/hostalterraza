-- ============================================================================
-- Migracion: banners de frase del silo f9b para el evento lanzamiento MISTICO.
-- Archivo : migrations/oneoff_lanzamiento_mistico_banners_f9b.sql
-- Fecha   : 2026-09-27
-- Ejecutar: MANUALMENTE (Direccion). Es idempotente. NO se ejecuta por endpoint.
-- ============================================================================
--
-- QUE HACE
--   1) crea config_landing.content.banners con 2 objetos
--      (banners[0] -> #mod-banner-1, banners[1] -> #mod-banner-2)
--   2) corrige config_landing.theme de 'mistico' a 'mistico-nocturno'
--
-- QUE NO HACE (deliberadamente)
--   - NO toca ninguna otra llave de content: gallery (9 items, uno de ~30 KB
--     base64), dj_lineup (8 artistas), meta, sponsors, whatsapp, form_solo,
--     playlist_url y comunidad_whatsapp quedan intactos.
--   - NO inventa datos: deja imagen_url, video_url y alt VACIOS a proposito
--     (los carga Direccion despues). Sin imagen_url, alt puede ir vacio.
--   - NO escribe faq ni boletos: el evento no los tiene y sus modulos deben
--     quedar ocultos (f9 solo pinta boletos con tarifa real).
--
-- FRASES (fuente: prompt cambios mistico.txt, lineas 31 y 43)
--   Las 2 frases son las que escribio el usuario en el prompt. El archivo debe
--   quedar en ASCII puro (0 bytes > 127), asi que se transliteraron las
--   tildes/dieresis al equivalente sin tilde:
--     musica  <- musica       sueno  <- sueno
--     pasion  <- pasion       guiros <- guiros
--   El kernel arma <p class="banner-frase"> con textContent, asi que cuando
--   Direccion suba el asset real se pueden reponer las tildes sin tocar render.
--
-- ESTILO
--   Banner 1 (Indio Mestizo) -> 'dorado' (paleta ambar/dorado del prompt).
--   Banner 2 (Reliquias)     -> 'monocromo' (blanco y negro; el brief lo pide
--   explicito). Valores validos: 'dorado' | 'monocromo'; fail-open 'dorado'.
--
-- POR QUE jsonb_set Y NO jsonb_build_object
--   config_landing.content.gallery[2] es un base64 de ~30 KB. Reconstruir
--   `content` entero lo DESTRUYE. jsonb_set con ruta '{content,banners}' es
--   merge superficial: crea/sobrescribe SOLO esa llave y preserva las hermanas.
--   El `|| jsonb_build_object('theme', 'mistico-nocturno')` es merge del
--   TOP-LEVEL: reemplaza solo la clave `theme` y conserva `content` completo.
--
-- IDEMPOTENCIA
--   jsonb_set(..., true) con el mismo array literal deja el mismo estado en
--   cada corrida. El WHERE con `id` + `slug` acota a UNA sola fila.
-- ============================================================================


BEGIN;

-- ----------------------------------------------------------------------------
-- FASE 1 - VERIFICACION PREVIA (solo lectura). Dejar el resultado a la vista.
-- ----------------------------------------------------------------------------
SELECT
  id,
  slug,
  config_landing->>'theme'                                   AS theme_antes,
  config_landing->'content' ? 'banners'                      AS ya_tiene_banners,
  jsonb_array_length(COALESCE(config_landing->'content'->'gallery','[]'::jsonb))   AS gallery_items,
  jsonb_array_length(COALESCE(config_landing->'content'->'dj_lineup','[]'::jsonb)) AS lineup_items
FROM eventos
WHERE id = '319df5de-bf4d-481d-ad0b-ed97f90a58e1'
  AND slug = 'lanzamiento-mistico-64k6';
-- Esperado: 1 fila. theme_antes='mistico', ya_tiene_banners=false,
--           gallery_items=9, lineup_items=8.


-- ----------------------------------------------------------------------------
-- FASE 2 - ESCRITURA IDEMPOTENTE (merge superficial de 1 llave + theme).
-- ----------------------------------------------------------------------------
UPDATE eventos
   SET config_landing = jsonb_set(
           COALESCE(config_landing, '{}'::jsonb),
           '{content,banners}',
           '[
             {
               "frase": "Indio mestizo nacido finalizando 80s amante de la salsa, musica sueno que alienta, mi pasion por el tambor y el clamor que el alma alimenta... Indio mestizo.",
               "autor": "Indio mestizo",
               "etiqueta": "Mistico",
               "estilo": "dorado",
               "imagen_url": "",
               "video_url": "",
               "alt": ""
             },
             {
               "frase": "Que mano de vueltas que da la vida socio, yo sigo ringletiando esquivando guiros ficticios. Reliquias.",
               "autor": "",
               "etiqueta": "",
               "estilo": "monocromo",
               "imagen_url": "",
               "video_url": "",
               "alt": ""
             }
           ]'::jsonb,
           true)
       || jsonb_build_object('theme', 'mistico-nocturno')
 WHERE id = '319df5de-bf4d-481d-ad0b-ed97f90a58e1'
   AND slug = 'lanzamiento-mistico-64k6';


-- ----------------------------------------------------------------------------
-- FASE 3 - VERIFICACION POSTERIOR (solo lectura).
--   gallery DEBE seguir en 9 y lineup en 8. Si gallery baja de 9 o lineup de 8:
--   ejecutar el ROLLBACK de abajo INMEDIATAMENTE y detenerse.
-- ----------------------------------------------------------------------------
SELECT
  id,
  config_landing->>'theme'                                        AS theme_despues,
  jsonb_array_length(COALESCE(config_landing->'content'->'banners','[]'::jsonb))    AS banners,
  jsonb_array_length(COALESCE(config_landing->'content'->'gallery','[]'::jsonb))    AS gallery_items,
  jsonb_array_length(COALESCE(config_landing->'content'->'dj_lineup','[]'::jsonb))  AS lineup_items,
  config_landing->'content' ? 'meta'          AS conserva_meta,
  config_landing->'content' ? 'form_solo'     AS conserva_form,
  config_landing->'content' ? 'playlist_url'  AS conserva_playlist,
  config_landing->'content' ? 'whatsapp'      AS conserva_whatsapp,
  config_landing->'content'->'banners'->0->>'estilo' AS estilo_b1,
  config_landing->'content'->'banners'->1->>'estilo' AS estilo_b2,
  length(config_landing->'content'->'banners'->0->>'frase') AS len_frase_b1,
  length(config_landing->'content'->'banners'->1->>'frase') AS len_frase_b2
FROM eventos
WHERE id = '319df5de-bf4d-481d-ad0b-ed97f90a58e1'
  AND slug = 'lanzamiento-mistico-64k6';
-- Esperado: theme_despues='mistico-nocturno', banners=2, gallery_items=9,
--           lineup_items=8, conserva_*=true, estilo_b1='dorado',
--           estilo_b2='monocromo', len_frase_b1<320, len_frase_b2<320.

COMMIT;


-- ============================================================================
-- ROLLBACK (solo si FASE 3 sale mal; quita SOLO la llave banners y revierte theme)
-- ----------------------------------------------------------------------------
-- UPDATE eventos
--    SET config_landing = (config_landing #- '{content,banners}')
--                      || jsonb_build_object('theme','mistico')
--  WHERE id = '319df5de-bf4d-481d-ad0b-ed97f90a58e1'
--    AND slug = 'lanzamiento-mistico-64k6';
-- ============================================================================
