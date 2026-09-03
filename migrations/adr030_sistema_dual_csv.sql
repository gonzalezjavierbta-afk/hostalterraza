-- ═══════════════════════════════════════════════════════════════════════
-- ADR-030 — Sistema Dual de Captura: Landing (comunidad) + Formulario Solo (aforo)
-- Sistema QR Hostal Terraza
--
-- Contexto: para cada evento se desea un sistema dual:
--   (A) Landing pública (evento.html?slug=...) cuyo formulario captura datos
--       del usuario y lo redirige a una comunidad de WhatsApp (link wa.me/chat
--       configurable por evento).
--   (B) Página separada "solo formulario" por evento, donde se registran
--       artistas, invitados y pagos — los registros de ESA página son los que
--       se CUENTAN para el aforo.
--
-- Decisiones de esquema (Data-First, mínima superficie):
--   • La configuración del sistema dual (link comunidad, toggle landing+form,
--     URL de la página solo-formulario) NO requiere columnas nuevas en
--     `eventos`: se persiste dentro del JSONB existente `config_landing.content`
--     (que admin.html ya escribe en `_crearEventoUnico` y `guardarEventoWizard`).
--     Claves propuestas:
--         content.comunidad_whatsapp  → text (link wa.me/chat o chat.whatsapp.com)
--         content.form_solo           → { "activo": bool, "url": string }
--   • Para distinguir en `inscritos` un registro de la landing (NO cuenta aforo)
--     de uno del formulario-solo (SÍ cuenta aforo), se añade UNA columna
--     booleana con DEFAULT false. El DEFAULT false protege todos los inserts
--     existentes (serie.html, admin.html, eventovenezuela.html, scanner.html):
--     ningún insert previo se rompe ni cambia de semántica.
--   • Aforo = COUNT(inscritos WHERE evento_id = :id AND cuenta_aforo = true)
--            sobre aforo_max.
--
-- Este script es IDEMPOTENTE (ADD COLUMN IF NOT EXISTS): seguro ejecutarlo
-- sin importar si la columna ya existe.
--
-- Ejecutar en: Supabase SQL Editor.
-- Reversible:  ver bloque ROLLBACK comentado al final.
-- ═══════════════════════════════════════════════════════════════════════

-- 1. cuenta_aforo — true = el inscrito proviene de la página solo-formulario
--    (artistas/invitados/pagos) y por tanto SÍ cuenta para el aforo del evento.
--    false = registro de la landing/comunidad (no cuenta aforo) o legacy.
ALTER TABLE inscritos
  ADD COLUMN IF NOT EXISTS cuenta_aforo boolean NOT NULL DEFAULT false;

-- 2. Índice de consulta: el conteo de aforo filtra frecuentemente por
--    evento_id + cuenta_aforo=true. Añade rendimiento sin afectar escritura.
CREATE INDEX IF NOT EXISTS idx_inscritos_evento_aforo
  ON inscritos (evento_id, cuenta_aforo);

-- 3. Verificación rápida post-migración (comentar/descomentar según se necesite):
-- SELECT column_name, data_type, column_default, is_nullable
-- FROM information_schema.columns
-- WHERE table_name = 'inscritos' AND column_name = 'cuenta_aforo';

-- ═══════════════════════════════════════════════════════════════════════
-- ROLLBACK (ejecutar manualmente solo si es necesario revertir):
--
-- DROP INDEX IF EXISTS idx_inscritos_evento_aforo;
-- ALTER TABLE inscritos DROP COLUMN IF EXISTS cuenta_aforo;
-- ═══════════════════════════════════════════════════════════════════════
