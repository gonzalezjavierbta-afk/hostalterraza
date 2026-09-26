-- ============================================================================
-- SEMILLA DE PRUEBA - Silo F9B "MISTICO NOCTURNO" (ADR-054 / ADR-055 / ADR-056)
-- Sistema QR Hostal Terraza - Septiembre 2026
--
-- Archivo : migrations/seed_f9b_mistico_nocturno_prueba.sql
-- Tipo    : SEMILLA DE DATOS (NO es migracion de esquema; no crea/borra columnas)
-- Runbook : ejecutar POR BLOQUES en el SQL Editor de Supabase (patron adr039).
--           NO usar la clave anon para escritura (ver notas de seguridad abajo).
--
-- PROPOSITO
--   Crear UN evento de prueba para verificar end-to-end el silo f9b:
--     template_id    = 'f9b'
--     categoria_slug = 'fiesta'
--     slug           = 'test-f9b-mistico-nocturno'  (marcado como prueba)
--     theme          = 'mistico-nocturno'
--     effects        = {grain:false, glow:false, vhs:false, parallax:true}  (ADR-055 p.8)
--   Escribe las COLUMNAS canonicas (fecha/hora/ubicacion/descripcion/poster_url,
--   ADR-056) y NO las duplica en config_landing.content.
--
-- VISIBILIDAD / AGENDA PUBLICA (CRITICO)
--   La cartelera publica (index.html, cargarEventos()) consulta
--   from('eventos').select(...).order('fecha') SIN filtrar por estado ni por
--   modo_publico. En esta instancia NO existe la columna estado (adr037 no
--   aplicada) y fase_landing='proximamente' convertiria el landing en teaser
--   (ocultando los modulos que se quieren probar). Por lo tanto NO hay flag que
--   oculte el evento de la cartelera: un evento con fecha futura APARECE en
--   "Proximos". Decision: la semilla se deja lista pero NO se publica por la via
--   automatica; se ejecuta solo en ventana controlada y se borra con el BLOQUE 3.
--
-- IDEMPOTENTE
--   - INSERT ... WHERE NOT EXISTS (crea solo si el slug no existe)
--   - UPDATE ... WHERE slug = 'test-f9b-mistico-nocturno' (re-aplica el estado
--     canonico en cada corrida; no depende de un UNIQUE en slug)
--   - BLOQUE 3 (borrado) es DELETE por slug: seguro de re-ejecutar (0 filas = ok)
--
-- CARACTERISTICAS
--   100% ASCII (cero bytes > 127), sin comillas tipograficas, sin emojis.
--   No crea RPCs, triggers, tablas ni indices. Tolerante a la instancia:
--   resuelve org_id en runtime y no asume migraciones aplicadas mas alla de las
--   columnas que SI existen (ver BLOQUE 0).
-- ============================================================================


-- ============================================================================
-- BLOQUE 0 - VERIFICACION PREVIA (SELECT) - solo lectura.
-- ============================================================================

-- 0.1 El slug de prueba debe estar LIBRE. Si devuelve 1 fila, ya existe:
--     saltar el INSERT (el UPDATE del BLOQUE 1 la re-aplica) o borrarla (BLOQUE 3).
SELECT id, slug, template_id, categoria_slug, fecha, fase_landing
FROM public.eventos WHERE slug = 'test-f9b-mistico-nocturno';
-- Esperado: 0 filas en la primera corrida.

-- 0.2 Columnas reales usadas por la semilla (todas confirmadas en produccion).
SELECT column_name, is_nullable, data_type
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'eventos'
  AND column_name IN ('nombre','slug','fecha','hora','ubicacion','descripcion',
                      'poster_url','imagen_url','template_id','categoria_slug',
                      'config_landing','modo_publico','fase_landing','org_id',
                      'color_primario','captura_pura','aforo_max','video_url')
ORDER BY column_name;
-- Esperado: 18 filas. Nota: estado NO aparece (adr037 pendiente en esta instancia).

-- 0.3 Org destino (la misma del evento f9 hermano). Ver BLOQUE 1 (se resuelve en runtime).
SELECT id, slug, nombre, is_master_org, plan
FROM public.organizaciones
WHERE slug IN ('rastro-mc') OR is_master_org = true
ORDER BY is_master_org, slug;
-- Esperado: 'rastro-mc' (org del evento f9 'prelanzamiento-mistico-9t39').


-- ============================================================================
-- BLOQUE 1 - CREAR / RE-APLICAR LA SEMILLA (escritura)
--
-- Resuelve org_id en runtime por prioridad:
--   (1) org del evento f9 hermano 'prelanzamiento-mistico-9t39'
--   (2) organizaciones.slug = 'rastro-mc'
--   (3) ABORTA con RAISE EXCEPTION si ninguna resuelve (no inserta a ciegas).
-- ============================================================================

DO $seed$
DECLARE
  v_org_id   uuid;
  v_slug     text := 'test-f9b-mistico-nocturno';
  v_fecha    text := '2026-12-19';
  v_hora     text := '22:00';
  v_lugar    text := 'Recinto de prueba - Silo f9b Mistico Nocturno (Bogota)';
  v_desc     text := 'Evento de prueba tecnica del silo f9b Mistico Nocturno. Verifica el render del kernel evento-app.html, la carga del CSS scoped css/templates/fiesta/f9b.css y las 5 subconmutaciones de la familia f9. No es un evento real.';
  v_poster   text := 'https://ctgyvydzshueemlelkzv.supabase.co/storage/v1/object/public/assets/avatar-default.png';
  v_content  jsonb;
BEGIN
  -- (0) Resolver org_id (runtime).
  SELECT id INTO v_org_id FROM public.organizaciones WHERE slug = 'rastro-mc';
  IF v_org_id IS NULL THEN
    SELECT org_id INTO v_org_id FROM public.eventos
    WHERE slug = 'prelanzamiento-mistico-9t39' AND org_id IS NOT NULL LIMIT 1;
  END IF;
  IF v_org_id IS NULL THEN
    RAISE EXCEPTION '[seed f9b] No se pudo resolver org_id (ni rastro-mc ni el evento f9 hermano). Fijar org_id manualmente antes de ejecutar.';
  END IF;
  RAISE NOTICE '[seed f9b] org_id resuelto: %', v_org_id;

  -- (1) config_landing: theme + colors + effects + modules (paridad Wizard) + content.
  -- IMPORTANTE: fecha/hora/ubicacion/descripcion/poster NO se escriben en content
  -- (columnas canonicas, ADR-056). content solo lleva datos intrinsecamente JSONB.
  v_content := $j${
  "theme": "mistico-nocturno",
  "colors": { "accent": "#d4af37" },
  "effects": { "grain": false, "glow": false, "vhs": false, "parallax": true },
  "modules": {
    "dj_lineup": true, "playlist": true, "ubicacion": true, "boletos": true,
    "faq": true, "sponsors": true, "whatsapp": true, "gallery": true,
    "countdown": true, "experiencias": true
  },
  "content": {
    "titulo_display": "TEST F9B MISTICO NOCTURNO",
    "subtitulo": "Prueba tecnica del silo f9b (no es un evento real)",
    "dj_lineup": [
      { "nombre": "DJ Prueba Uno", "foto": "https://ctgyvydzshueemlelkzv.supabase.co/storage/v1/object/public/assets/avatar-default.png", "resena": "Headliner por POSICION indice 0 (subconmutacion f9b)", "hora": "22:00" },
      { "nombre": "DJ Prueba Dos", "foto": "https://ctgyvydzshueemlelkzv.supabase.co/storage/v1/object/public/assets/avatar-default.png", "resena": "Artista de prueba", "hora": "23:30" }
    ],
    "playlist_url": "https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M",
    "boletos": { "preventa": "50000", "taquilla": "70000" },
    "sponsors": [
      { "nombre": "Marca Prueba", "logo_url": "https://ctgyvydzshueemlelkzv.supabase.co/storage/v1/object/public/assets/avatar-default.png" }
    ],
    "faq": [
      { "q": "Este evento es una prueba?", "a": "Si. Es un evento de prueba del silo f9b Mistico Nocturno." },
      { "q": "Se puede borrar?", "a": "Si. El BLOQUE 3 de esta semilla lo elimina por slug de forma idempotente." }
    ],
    "experiencias": [
      { "titulo": "Experiencia de prueba", "tag": "f9b" }
    ],
    "whatsapp": "573102465591",
    "gallery": [
      "https://ctgyvydzshueemlelkzv.supabase.co/storage/v1/object/public/assets/avatar-default.png"
    ]
  }
}$j$::jsonb;

  -- (2) INSERT idempotente (solo si el slug no existe).
  INSERT INTO public.eventos (
    org_id, nombre, slug, fecha, hora, ubicacion, descripcion,
    color_primario, template_id, categoria_slug, poster_url, imagen_url,
    video_url, modo_publico, fase_landing, captura_pura, aforo_max, config_landing
  )
  SELECT
    v_org_id, 'TEST F9B MISTICO NOCTURNO', v_slug, v_fecha, v_hora, v_lugar, v_desc,
    '#d4af37', 'f9b', 'fiesta', v_poster, v_poster,
    NULL, 'landing', 'completa', false, 100, v_content
  WHERE NOT EXISTS (SELECT 1 FROM public.eventos WHERE slug = v_slug);

  IF FOUND THEN
    RAISE NOTICE '[seed f9b] INSERT creado: slug=%', v_slug;
  ELSE
    RAISE NOTICE '[seed f9b] slug ya existia; se salta el INSERT (UPDATE a continuacion).';
  END IF;

  -- (3) UPDATE idempotente: re-aplica el estado canonico de la semilla.
  UPDATE public.eventos SET
    org_id         = v_org_id,
    nombre         = 'TEST F9B MISTICO NOCTURNO',
    fecha          = v_fecha,
    hora           = v_hora,
    ubicacion      = v_lugar,
    descripcion    = v_desc,
    color_primario = '#d4af37',
    template_id    = 'f9b',
    categoria_slug = 'fiesta',
    poster_url     = v_poster,
    imagen_url     = v_poster,
    modo_publico   = 'landing',
    fase_landing   = 'completa',
    captura_pura   = false,
    aforo_max      = 100,
    config_landing = v_content
  WHERE slug = v_slug;

  RAISE NOTICE '[seed f9b] UPDATE aplicado (idempotente).';
END $seed$;


-- ============================================================================
-- BLOQUE 2 - VERIFICACION POSTERIOR (SELECT) - evidencia de exito
-- ============================================================================

-- 2.1 La fila quedo con identidad, columnas canonicas y efectos correctos.
SELECT
  id, slug, template_id, categoria_slug, fecha, hora, ubicacion,
  left(descripcion, 40) AS descripcion_40, poster_url, modo_publico, fase_landing,
  config_landing->>'theme'       AS theme,
  config_landing->'effects'      AS effects,
  (config_landing->'content' ? 'dj_lineup')     AS tiene_dj_lineup,
  (config_landing->'content' ? 'playlist_url')  AS tiene_playlist,
  (config_landing->'content' ? 'boletos')       AS tiene_boletos,
  (config_landing->'content' ? 'sponsors')      AS tiene_sponsors,
  (config_landing->'content' ? 'faq')           AS tiene_faq,
  (config_landing->'content' ? 'whatsapp')      AS tiene_whatsapp,
  (config_landing->'content' ? 'fecha')         AS content_fecha_duplicada,
  (config_landing->'content' ? 'poster_url')    AS content_poster_duplicado
FROM public.eventos
WHERE slug = 'test-f9b-mistico-nocturno';
-- Esperado: 1 fila. template_id='f9b', categoria_slug='fiesta',
-- effects = {"grain": false, "glow": false, "vhs": false, "parallax": true},
-- todos los tiene_* = true y content_*_duplicada = false (no duplica columnas).

-- 2.2 Confirmar que NO se duplicaron columnas canonicas dentro de content.
SELECT
  (config_landing->'content'->>'fecha')       AS content_fecha,
  (config_landing->'content'->>'hora')        AS content_hora,
  (config_landing->'content'->>'ubicacion')   AS content_ubicacion,
  (config_landing->'content'->>'descripcion') AS content_descripcion,
  (config_landing->'content'->>'poster_url')  AS content_poster_url
FROM public.eventos WHERE slug = 'test-f9b-mistico-nocturno';
-- Esperado: NULL en las 5 columnas (la semilla NO duplica en content, ADR-056).


-- ============================================================================
-- BLOQUE 3 - BORRADO IDEMPOTENTE DEL EVENTO DE PRUEBA
-- ----------------------------------------------------------------------------
-- NO CORRER JUNTO CON EL BLOQUE 1 EN LA MISMA PASADA. Este bloque es la
-- operacion de limpieza (ejecutar cuando la verificacion end-to-end termine).
-- Es idempotente: 0 filas = ya estaba borrado.
-- ============================================================================

DELETE FROM public.eventos WHERE slug = 'test-f9b-mistico-nocturno';
-- Esperado: DELETE 1 en la primera corrida; DELETE 0 si ya no existe.

-- Verificacion del borrado (esperado: 0 filas).
-- SELECT count(*) AS remanentes FROM public.eventos WHERE slug = 'test-f9b-mistico-nocturno';


-- ============================================================================
-- NOTAS DE SEGURIDAD (patron adr039)
-- ============================================================================
-- 1. NO usar la clave anon para escribir. Ejecutar con token service_role o
--    desde el SQL Editor de Supabase (rol postgres/service -> ignora RLS).
-- 2. La lectura REST anon esta abierta (hallazgo T0), pero eso NO habilita
--    escritura anon. Este archivo se ejecuta con privilegios elevados.
-- 3. El evento de prueba APARECERA en la cartelera publica (index.html no
--    filtra por estado/modo_publico). Ejecutar en ventana controlada y borrar
--    con el BLOQUE 3 cuanto antes.
-- 4. Este seed NO toca RLS, no crea politicas y no modifica esquema. Si se
--    requiere tocar RLS, escalar a @sql-security (agente pro).
-- ============================================================================
