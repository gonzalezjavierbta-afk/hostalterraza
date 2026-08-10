-- ═══════════════════════════════════════════════════════════════════════
-- ADR-021 — Wizard Inteligente de Creación de Eventos
-- Sistema QR Hostal Terraza
--
-- Contexto: BLUEPRINT.md (§3) documenta `template_id` y `categoria_slug`
-- como columnas de `eventos` desde antes de esta sesión, pero no había
-- forma de confirmar por auditoría de código si existen realmente en la
-- instancia de Supabase en producción — solo que `admin.html` no las
-- escribía. Este script es IDEMPOTENTE: es seguro ejecutarlo sin importar
-- si las columnas ya existen o no.
--
-- Ejecutar en: Supabase SQL Editor (o vía CLI: supabase db execute -f ...)
-- Reversible:  ver bloque ROLLBACK comentado al final.
-- ═══════════════════════════════════════════════════════════════════════

-- 1. template_id — slug de la plantilla visual elegida (ej. 'f1', 'b5', 'arthouse')
ALTER TABLE eventos
  ADD COLUMN IF NOT EXISTS template_id text;

-- 2. categoria_slug — categoría del evento: 'cinematografia' | 'fiesta' | 'campana'
ALTER TABLE eventos
  ADD COLUMN IF NOT EXISTS categoria_slug text;

-- 3. captura_pura — true = el orquestador público (evento.html / evento3.html,
--    ver TSK-017 pendiente de reconciliación) debe omitir la generación de QR
--    tras el registro exitoso y mostrar un mensaje de agradecimiento en su lugar.
ALTER TABLE eventos
  ADD COLUMN IF NOT EXISTS captura_pura boolean NOT NULL DEFAULT false;

-- 4. Índices de consulta — el admin filtra/lista eventos por categoría con frecuencia
--    (panel de eventos, selects de invitadores, etc.). No afecta escritura, solo lectura.
CREATE INDEX IF NOT EXISTS idx_eventos_categoria_slug ON eventos (categoria_slug);
CREATE INDEX IF NOT EXISTS idx_eventos_template_id     ON eventos (template_id);

-- 5. Verificación rápida post-migración (comentar/descomentar según se necesite):
-- SELECT column_name, data_type, column_default, is_nullable
-- FROM information_schema.columns
-- WHERE table_name = 'eventos' AND column_name IN ('template_id','categoria_slug','captura_pura');

-- ═══════════════════════════════════════════════════════════════════════
-- ROLLBACK (ejecutar manualmente solo si es necesario revertir):
--
-- ALTER TABLE eventos DROP COLUMN IF EXISTS template_id;
-- ALTER TABLE eventos DROP COLUMN IF EXISTS categoria_slug;
-- ALTER TABLE eventos DROP COLUMN IF EXISTS captura_pura;
-- DROP INDEX IF EXISTS idx_eventos_categoria_slug;
-- DROP INDEX IF EXISTS idx_eventos_template_id;
-- ═══════════════════════════════════════════════════════════════════════
