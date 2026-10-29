-- ============================================================================
-- oneoff_evento_vinilos_f14.sql
-- Pasa el evento `vinilos-inversos-c8yu` (VINILOS INVERSOS, 2026-11-20) al silo
-- f14 "Vinilos Inversos" (theme `vinilos`), registrado en admin.html bajo
-- ADR-082, y sincroniza la paleta con la del silo.
--
-- POR QUE UN UPDATE QUIRURGICO Y NO UN PATCH COMPLETO:
--   `config_landing` es OVERWRITE TOTAL (clase BUG-016 / ADR-080). Reenviar el
--   objeto completo desde un cliente lo expone a perder `content` si alguna
--   rama lo reconstruye mal. Aqui se usa `jsonb_set` sobre DOS claves
--   (`theme` y `colors`); `content`, `effects` y `modules` no se tocan.
--
-- INVARIANTE ADR-080: `eventos.color_primario` debe seguir siendo igual a
--   `config_landing.colors.accent`. Este script los mueve juntos.
--
-- Idempotente: re-ejecutarlo deja el mismo estado.
-- ============================================================================

BEGIN;

-- 0) ANTES (dejar constancia en la salida)
SELECT slug, template_id, color_primario,
       config_landing->>'theme' AS theme_actual,
       config_landing->'colors' AS colors_actual
FROM eventos
WHERE slug = 'vinilos-inversos-c8yu';

-- 1) CAMBIO
UPDATE eventos
SET template_id     = 'f14',
    color_primario  = '#E35925',
    color_fondo     = '#0E0E0E',
    config_landing  = jsonb_set(
                        jsonb_set(
                          COALESCE(config_landing, '{}'::jsonb),
                          '{theme}',
                          '"vinilos"'::jsonb,
                          true
                        ),
                        '{colors}',
                        '{"accent":"#E35925","secondary":"#EA580C","tertiary":"#DBC8A8","surface":"#131313","background":"#0E0E0E"}'::jsonb,
                        true
                      )
WHERE slug = 'vinilos-inversos-c8yu';

-- 2) DESPUES + guardas de integridad
SELECT slug, template_id, color_primario,
       config_landing->>'theme' AS theme_nuevo,
       config_landing->'colors'->>'accent' AS accent_nuevo,
       (config_landing->'content') IS NOT NULL AS content_presente,
       jsonb_typeof(config_landing->'modules') AS modules_tipo
FROM eventos
WHERE slug = 'vinilos-inversos-c8yu';

DO $$
DECLARE
  v_tpl    text;
  v_theme  text;
  v_accent text;
  v_color  text;
BEGIN
  SELECT template_id, config_landing->>'theme', config_landing->'colors'->>'accent', color_primario
    INTO v_tpl, v_theme, v_accent, v_color
  FROM eventos WHERE slug = 'vinilos-inversos-c8yu';

  IF v_tpl IS DISTINCT FROM 'f14' THEN
    RAISE EXCEPTION 'ABORT: template_id quedo en % (esperado f14)', v_tpl;
  END IF;
  IF v_theme IS DISTINCT FROM 'vinilos' THEN
    RAISE EXCEPTION 'ABORT: theme quedo en % (esperado vinilos)', v_theme;
  END IF;
  IF v_accent IS DISTINCT FROM v_color THEN
    RAISE EXCEPTION 'ABORT: color_primario (% ) no coincide con colors.accent (%) - invariante ADR-080', v_color, v_accent;
  END IF;

  RAISE NOTICE 'OK: evento vinilos-inversos-c8yu -> f14 / vinilos / %', v_accent;
END $$;

COMMIT;

-- ============================================================================
-- ROLLBACK (si hiciera falta volver al estado previo verificado el 2026-10-29):
--   UPDATE eventos SET template_id='f9', color_primario='#c9a84c', color_fondo='#000000',
--     config_landing = jsonb_set(jsonb_set(config_landing,'{theme}','"mistico"'::jsonb,true),
--       '{colors}','{"accent":"#c9a84c","surface":"#382e11","tertiary":"#8b6c18","secondary":"#e36935","background":"#000000"}'::jsonb,true)
--   WHERE slug='vinilos-inversos-c8yu';
-- ============================================================================
