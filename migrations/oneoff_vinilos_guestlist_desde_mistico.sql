-- ============================================================================
-- oneoff_vinilos_guestlist_desde_mistico.sql
-- Copia la info de Guest List del evento `lanzamiento-mistico-64k6` al evento
-- `vinilos-inversos-c8yu`, SIN tocar template_id, color_primario, theme ni el
-- resto de llaves de content.
--
-- Fecha: 2026-11-03
-- Ejecutar: MANUALMENTE (Direccion). Idempotente. NO se ejecuta por endpoint.
--
-- CONTRATO DEL KERNEL (evento-app.html) -- DOS CLAVES DISTINTAS, NO UNIFICAR:
--   content.guest_list  -> STRING -> chip de specs `#db-guest-val`
--                          (evento-app.html:2511, 2533, 2541-2542)
--   content.guestlist   -> OBJETO -> card `#mod-guestlist`
--                          (evento-app.html:261-287, 2677-2725)
--                          { badge, titulo, descripcion, imagen_url, alt,
--                            patrocina, cta_texto, cta_url }
--   modules.guest_list  -> flag de modulo escrito por admin.html:5138
--                          (el kernel ACTUAL no lo lee: solo usa cfg.modules en
--                           `hasLanding`, evento-app.html:1109)
--
-- POR QUE jsonb_set Y NO RECONSTRUIR content
--   config_landing.content de estos eventos pesa decenas de KB (gallery con
--   base64, dj_lineup, banners...). Reconstruir `content` lo destruye.
--   jsonb_set con ruta '{content,guest_list}' es merge superficial: sobrescribe
--   SOLO esa llave y conserva las hermanas (clase BUG-016 / ADR-080).
--   El jsonb_set interno de '{content}' garantiza que el paso previo de la ruta
--   exista (jsonb_set no crea pasos intermedios ausentes).
--
-- REGLAS DE SEGURIDAD
--   - Si el mistico NO tiene content.guest_list (string no vacio) -> ABORTA.
--   - Si el mistico NO tiene content.guestlist (objeto) -> NO se inventa:
--     se copia solo el chip y se emite AVISO.
--   - Si vinilos ya tuviera valores propios distintos -> ABORTA antes de pisar.
--   - Guarda final: mismo numero y mismo set de llaves en content, y
--     template_id / color_primario / theme intactos.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- FASE 0 - ANTES (solo lectura, queda en _gl_pre para comparar al final)
-- ----------------------------------------------------------------------------
CREATE TEMP TABLE _gl_pre ON COMMIT DROP AS
SELECT
  e.slug,
  e.template_id,
  e.color_primario,
  e.config_landing->>'theme'                                  AS theme,
  jsonb_typeof(e.config_landing->'content'->'guest_list')      AS tipo_guest_list,
  e.config_landing->'content'->'guest_list'                    AS guest_list,
  jsonb_typeof(e.config_landing->'content'->'guestlist')       AS tipo_guestlist,
  e.config_landing->'content'->'guestlist'                     AS guestlist,
  (SELECT count(*) FROM jsonb_object_keys(COALESCE(e.config_landing->'content','{}'::jsonb)) AS k(k))
                                                               AS content_keys,
  (SELECT string_agg(k, ',' ORDER BY k) FROM jsonb_object_keys(COALESCE(e.config_landing->'content','{}'::jsonb)) AS k(k))
                                                               AS content_key_list
FROM eventos e
WHERE e.slug IN ('lanzamiento-mistico-64k6','vinilos-inversos-c8yu');

SELECT * FROM _gl_pre ORDER BY slug;
-- Esperado: 2 filas.
--   lanzamiento-mistico-64k6 : tipo_guest_list='string', guest_list no vacio,
--                              tipo_guestlist='object' (si sale 'null' -> solo
--                              se copiara el chip).
--   vinilos-inversos-c8yu    : guest_list / guestlist NULL o iguales al
--                              mistico (si son distintos, la guarda aborta).

-- ----------------------------------------------------------------------------
-- FASE 1 - GUARDAS
-- ----------------------------------------------------------------------------
DO $$
DECLARE
  v_n          int;
  v_m_gl_tipo  text;  v_m_gl  jsonb;
  v_m_glt_tipo text;  v_m_glt jsonb;
  v_v_gl_tipo  text;  v_v_gl  jsonb;
  v_v_glt_tipo text;  v_v_glt jsonb;
BEGIN
  SELECT count(*) INTO v_n
  FROM eventos
  WHERE slug IN ('lanzamiento-mistico-64k6','vinilos-inversos-c8yu');

  IF v_n <> 2 THEN
    RAISE EXCEPTION 'ABORT: se esperaban 2 eventos (mistico + vinilos), encontrados %', v_n;
  END IF;

  SELECT jsonb_typeof(config_landing->'content'->'guest_list'),
         config_landing->'content'->'guest_list',
         jsonb_typeof(config_landing->'content'->'guestlist'),
         config_landing->'content'->'guestlist'
    INTO v_m_gl_tipo, v_m_gl, v_m_glt_tipo, v_m_glt
  FROM eventos WHERE slug = 'lanzamiento-mistico-64k6';

  SELECT jsonb_typeof(config_landing->'content'->'guest_list'),
         config_landing->'content'->'guest_list',
         jsonb_typeof(config_landing->'content'->'guestlist'),
         config_landing->'content'->'guestlist'
    INTO v_v_gl_tipo, v_v_gl, v_v_glt_tipo, v_v_glt
  FROM eventos WHERE slug = 'vinilos-inversos-c8yu';

  -- A) El chip de origen debe existir y no ser vacio.
  IF v_m_gl_tipo IS DISTINCT FROM 'string' OR btrim(v_m_gl #>> '{}') = '' THEN
    RAISE EXCEPTION 'ABORT: lanzamiento-mistico-64k6 no tiene content.guest_list (string no vacio). tipo=%', v_m_gl_tipo;
  END IF;

  -- B) Card de origen: si no existe, se avisa (NO se inventa).
  IF v_m_glt_tipo IS DISTINCT FROM 'object' THEN
    RAISE NOTICE 'AVISO: lanzamiento-mistico-64k6 NO tiene content.guestlist objeto (tipo=%). Se copiara SOLO el chip guest_list.', v_m_glt_tipo;
  ELSE
    -- B2) Solo con card de origen se valida colision en el destino.
    --     Un objeto vacio {} se considera "sin valor propio": no aborta.
    IF v_v_glt_tipo = 'object'
       AND v_v_glt <> '{}'::jsonb
       AND v_v_glt IS DISTINCT FROM v_m_glt THEN
      RAISE EXCEPTION 'ABORT: vinilos-inversos-c8yu ya tiene content.guestlist propio y distinto: %', v_v_glt;
    END IF;
  END IF;

  -- C) El chip de destino no debe tener un valor propio distinto.
  --    Cadena vacia se considera "sin valor propio": no aborta.
  IF v_v_gl_tipo = 'string'
     AND btrim(COALESCE(v_v_gl #>> '{}','')) <> ''
     AND v_v_gl IS DISTINCT FROM v_m_gl THEN
    RAISE EXCEPTION 'ABORT: vinilos-inversos-c8yu ya tiene content.guest_list propio y distinto: %', v_v_gl;
  END IF;

  RAISE NOTICE 'OK guardas: origen chip=% tipo_card=% destino chip=% tipo_card=%',
    v_m_gl, v_m_glt_tipo, v_v_gl, v_v_glt_tipo;
END $$;

-- ----------------------------------------------------------------------------
-- FASE 2 - ESCRITURA (2 llaves, cada una condicionada al origen)
-- ----------------------------------------------------------------------------
-- 2.1 chip STRING -> content.guest_list
UPDATE eventos v
   SET config_landing = jsonb_set(
         jsonb_set(
           COALESCE(v.config_landing, '{}'::jsonb),
           '{content}',
           COALESCE(v.config_landing->'content', '{}'::jsonb),
           true
         ),
         '{content,guest_list}',
         m.config_landing->'content'->'guest_list',
         true
       )
  FROM eventos m
 WHERE v.slug = 'vinilos-inversos-c8yu'
   AND m.slug = 'lanzamiento-mistico-64k6'
   AND jsonb_typeof(m.config_landing->'content'->'guest_list') = 'string';

-- 2.2 card OBJETO -> content.guestlist (solo si el origen la tiene)
UPDATE eventos v
   SET config_landing = jsonb_set(
         jsonb_set(
           COALESCE(v.config_landing, '{}'::jsonb),
           '{content}',
           COALESCE(v.config_landing->'content', '{}'::jsonb),
           true
         ),
         '{content,guestlist}',
         m.config_landing->'content'->'guestlist',
         true
       )
  FROM eventos m
 WHERE v.slug = 'vinilos-inversos-c8yu'
   AND m.slug = 'lanzamiento-mistico-64k6'
   AND jsonb_typeof(m.config_landing->'content'->'guestlist') = 'object';

-- ----------------------------------------------------------------------------
-- FASE 3 - DESPUES + verificacion de no-regresion
-- ----------------------------------------------------------------------------
SELECT
  v.slug,
  v.template_id,
  v.color_primario,
  v.config_landing->>'theme'                                            AS theme,
  p.content_keys                                                        AS content_keys_antes,
  (SELECT count(*) FROM jsonb_object_keys(COALESCE(v.config_landing->'content','{}'::jsonb)) AS k(k))
                                                                        AS content_keys_despues,
  p.content_key_list                                                    AS keys_antes,
  (SELECT string_agg(k, ',' ORDER BY k) FROM jsonb_object_keys(COALESCE(v.config_landing->'content','{}'::jsonb)) AS k(k))
                                                                        AS keys_despues,
  v.config_landing->'content'->'guest_list'                             AS guest_list_final,
  v.config_landing->'content'->'guestlist'                              AS guestlist_final,
  (v.config_landing->'content'->'guest_list')
    IS NOT DISTINCT FROM (SELECT config_landing->'content'->'guest_list' FROM eventos WHERE slug='lanzamiento-mistico-64k6')
                                                                        AS chip_igual_al_mistico,
  (v.config_landing->'content'->'guestlist')
    IS NOT DISTINCT FROM (SELECT config_landing->'content'->'guestlist' FROM eventos WHERE slug='lanzamiento-mistico-64k6')
                                                                        AS card_igual_al_mistico
FROM eventos v
JOIN _gl_pre p ON p.slug = v.slug
WHERE v.slug = 'vinilos-inversos-c8yu';

DO $$
DECLARE
  v_pre  _gl_pre;
  v_post record;
  v_faltan text;
BEGIN
  SELECT * INTO v_pre FROM _gl_pre WHERE slug = 'vinilos-inversos-c8yu';

  SELECT template_id, color_primario, config_landing->>'theme' AS theme,
         (SELECT count(*) FROM jsonb_object_keys(COALESCE(config_landing->'content','{}'::jsonb)) AS k(k)) AS content_keys,
         (SELECT string_agg(k, ',' ORDER BY k) FROM jsonb_object_keys(COALESCE(config_landing->'content','{}'::jsonb)) AS k(k)) AS key_list
    INTO v_post
  FROM eventos WHERE slug = 'vinilos-inversos-c8yu';

  IF v_post.template_id IS DISTINCT FROM v_pre.template_id THEN
    RAISE EXCEPTION 'ABORT: template_id cambio (% -> %)', v_pre.template_id, v_post.template_id;
  END IF;
  IF v_post.color_primario IS DISTINCT FROM v_pre.color_primario THEN
    RAISE EXCEPTION 'ABORT: color_primario cambio (% -> %)', v_pre.color_primario, v_post.color_primario;
  END IF;
  IF v_post.theme IS DISTINCT FROM v_pre.theme THEN
    RAISE EXCEPTION 'ABORT: theme cambio (% -> %)', v_pre.theme, v_post.theme;
  END IF;

  -- Ninguna llave de content puede desaparecer (se permiten 0, 1 o 2 nuevas:
  -- guest_list / guestlist).
  SELECT string_agg(k, ',') INTO v_faltan
  FROM (SELECT unnest(string_to_array(v_pre.content_key_list, ',')) AS k) s
  WHERE k <> '' AND NOT (k = ANY (string_to_array(COALESCE(v_post.key_list,''), ',')));

  IF v_faltan IS NOT NULL THEN
    RAISE EXCEPTION 'ABORT: se perdieron llaves de content: %', v_faltan;
  END IF;

  RAISE NOTICE 'OK: content_keys % -> % (agregadas netas: %). template/color/theme intactos.',
    v_pre.content_keys, v_post.content_keys, v_post.content_keys - v_pre.content_keys;
END $$;

COMMIT;

-- ============================================================================
-- ROLLBACK (referencia). OJO: `_gl_pre` es ON COMMIT DROP, asi que este bloque
-- SOLO funciona dentro de la MISMA transaccion y ANTES del COMMIT. Si ya
-- hiciste COMMIT el snapshot desaparecio: para revertir hay que re-snapshotear
-- los valores actuales y ejecutar el inverso en una transaccion nueva.
-- ----------------------------------------------------------------------------
-- BEGIN;
-- UPDATE eventos v
--    SET config_landing = jsonb_set(
--          jsonb_set(COALESCE(v.config_landing,'{}'::jsonb),'{content}',
--                    COALESCE(v.config_landing->'content','{}'::jsonb), true),
--          '{content,guest_list}', p.guest_list, true)
--   FROM _gl_pre p
--  WHERE v.slug='vinilos-inversos-c8yu' AND p.slug=v.slug
--    AND p.guest_list IS NOT NULL;
-- UPDATE eventos v
--    SET config_landing = jsonb_set(
--          jsonb_set(COALESCE(v.config_landing,'{}'::jsonb),'{content}',
--                    COALESCE(v.config_landing->'content','{}'::jsonb), true),
--          '{content,guestlist}', p.guestlist, true)
--   FROM _gl_pre p
--  WHERE v.slug='vinilos-inversos-c8yu' AND p.slug=v.slug
--    AND p.guestlist IS NOT NULL;
-- COMMIT;
-- ============================================================================
