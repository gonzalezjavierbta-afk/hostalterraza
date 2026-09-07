-- ═══════════════════════════════════════════════════════════════════════
-- ADR-033 — Modo de página pública del evento (landing / formulario / ambos)
-- Sistema QR Hostal Terraza
--
-- Contexto: al crear un evento se debe poder elegir qué tendrá su presencia
-- pública:
--   • 'landing'            → solo landing page visual (evento.html?slug=...)
--   • 'formulario'         → solo página de registro/aforo (registroaforo.html?slug=...)
--   • 'landing_formulario' → ambas
--
-- Decisiones de esquema (Data-First, mínima superficie):
--   • Se añade UNA columna texto `modo_publico` en `eventos`. Los valores
--     legibles por el backend son los tres anteriores; `NULL` equivale a
--     'landing' y se usa para eventos legacy.
--   • La landing y el formulario siguen persistiéndose igual que en ADR-030
--     (config_landing / config_landing.content.form_solo): `modo_publico` es
--     la fuente de verdad explícita del selector, no reemplaza ese JSON.
--
-- Este script es IDEMPOTENTE (ADD COLUMN IF NOT EXISTS): seguro ejecutarlo
-- sin importar si la columna ya existe.
--
-- Ejecutar en: Supabase SQL Editor.
-- Reversible: ver bloque ROLLBACK comentado al final.
-- ═══════════════════════════════════════════════════════════════════════

ALTER TABLE eventos
  ADD COLUMN IF NOT EXISTS modo_publico text;

-- Índice opcional (se filtra pocas veces por modo; se incluye por completitud):
-- CREATE INDEX IF NOT EXISTS idx_eventos_modo_publico ON eventos (modo_publico);

-- ═══════════════════════════════════════════════════════════════════════
-- ROLLBACK (ejecutar manualmente solo si es necesario revertir):
--
-- ALTER TABLE eventos DROP COLUMN IF EXISTS modo_publico;
-- ═══════════════════════════════════════════════════════════════════════
