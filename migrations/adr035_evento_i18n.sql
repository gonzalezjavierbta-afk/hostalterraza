-- ═══════════════════════════════════════════════════════════════════════
-- ADR-035 - Internacionalizacion por evento (config_landing.i18n)
-- Sistema QR Hostal Terraza
--
-- Contexto: las landing pages publicas (index.html, evento.html, qr.html,
-- serie.html, registroaforo.html) muestran el selector de idioma ES/FR/EN
-- (js/i18n.js). El idioma base (es) vive en config_landing.content; los
-- overrides FR/EN se persisten dentro del mismo JSONB config_landing.i18n,
-- editados desde la pestana "Idiomas" del panel admin.
--
-- Decisiones de esquema (Data-First, minima superficie):
--   * NO se agregan columnas nuevas: la tabla `eventos` ya tiene la columna
--     JSONB `config_landing` (desde ADR-030/033).
--   * Contrato de datos: config_landing.i18n[lang] = {
--       "nombre":      string|null,   -- override del nombre del evento
--       "org_nombre":  string|null,   -- override del nombre de la organizacion
--       "content":     { <overrides de texto> }
--     } con lang en { 'fr', 'en' }.
--   * Merge en evento.html (kernel): effContent = Object.assign({}, content,
--     i18n[lang].content); effNombre = i18n[lang].nombre || ev.nombre;
--     effOrgNombre = i18n[lang].org_nombre || organizaciones.nombre;
--     effUbicacion = i18n[lang].ubicacion || ev.ubicacion.
--   * No requiere politicas RLS nuevas: la clave anon actualiza `eventos`
--     con las politicas existentes y la nueva clave queda cubierta por ellas.
--
-- Este script es IDEMPOTENTE (guarda por information_schema + COMMENT
-- reeemplazable): seguro ejecutarlo multiples veces en el SQL Editor.
--
-- Ejecutar en: Supabase SQL Editor.
-- Reversible: ver bloque ROLLBACK comentado al final.
-- ═══════════════════════════════════════════════════════════════════════

-- Guarda idempotente: si en algun entorno legacy faltara la columna
-- JSONB config_landing, se crea. No pisa nada si ya existe.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'eventos'
      AND column_name = 'config_landing'
  ) THEN
    ALTER TABLE eventos ADD COLUMN config_landing jsonb;
  END IF;
END $$;

-- Documentacion del contrato JSONB completo (idempotente).
COMMENT ON COLUMN eventos.config_landing IS
'Landing config per event. Top-level keys: theme, colors, modules, effects, content. '
'content holds the base (Spanish) text/data overrides for the landing modules. '
'i18n[lang] = { nombre, org_nombre, content } holds optional French (fr) and English (en) '
'overrides; es is the base in content. Merge in evento.html: '
'effContent = Object.assign({}, content, i18n[lang].content); '
'effNombre = i18n[lang].nombre || ev.nombre; '
'effOrgNombre = i18n[lang].org_nombre || organizaciones.nombre; '
'effUbicacion = i18n[lang].ubicacion || ev.ubicacion. (ADR-035)';

-- ═══════════════════════════════════════════════════════════════════════
-- ROLLBACK (ejecutar manualmente solo si es necesario revertir):
--
-- COMMENT ON COLUMN eventos.config_landing IS NULL;
-- ALTER TABLE eventos DROP COLUMN IF EXISTS config_landing;
--   ^ solo si la guarda DO la hubiera creado (en entornos legacy).
-- ═══════════════════════════════════════════════════════════════════════