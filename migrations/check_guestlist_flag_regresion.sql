-- ============================================================================
-- check_guestlist_flag_regresion.sql  (SOLO LECTURA)
-- Pregunta: cuantos eventos tienen el flag de modulo apagado
--   config_landing.modules.guest_list = false
-- Y a la vez tienen la card cargada
--   config_landing.content ? 'guestlist'
-- Si el numero es alto, cablear el flag en el kernel apagaria cards que hoy se
-- pintan (el kernel actual NO lee modules: solo `hasLanding`, evento-app.html:1109).
--
-- NO modifica nada. Ejecutar y pegar el resultado.
-- ============================================================================

SELECT
  count(*) FILTER (
    WHERE config_landing->'modules'->>'guest_list' IN ('false','0')
      AND (config_landing->'content') ? 'guestlist'
  ) AS flag_false_con_guestlist,

  count(*) FILTER (
    WHERE config_landing->'modules'->>'guest_list' IN ('true','1')
      AND (config_landing->'content') ? 'guestlist'
  ) AS flag_true_con_guestlist,

  count(*) FILTER (
    WHERE (config_landing->'content') ? 'guestlist'
  ) AS total_con_guestlist,

  count(*) FILTER (
    WHERE config_landing->'modules' ? 'guest_list'
  ) AS total_con_flag_definido
FROM eventos;

-- Detalle de los casos que romperian si se cablea el flag (flag false + card):
SELECT slug, template_id,
       config_landing->'modules'->>'guest_list' AS flag,
       jsonb_typeof(config_landing->'content'->'guestlist') AS tipo_card,
       left(config_landing->'content'->'guestlist'->>'titulo', 60) AS titulo
FROM eventos
WHERE config_landing->'modules'->>'guest_list' IN ('false','0')
  AND (config_landing->'content') ? 'guestlist'
ORDER BY slug;
