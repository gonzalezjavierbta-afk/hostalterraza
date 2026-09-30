-- =====================================================================
-- ADR-062 - Varios links por invitador (uno por evento/serie)
-- Sistema QR Hostal Terraza
--
-- Contexto: `invitadores.codigo` tiene UNIQUE(`invitadores_codigo_key`),
-- lo que fuerza UNA sola fila por invitador. El admin, al generar un link
-- para un segundo evento desde el mismo invitador, hacia UPDATE de esa
-- unica fila y pisaba el link anterior (solo se mostraba uno).
--
-- Solucion (Data-First): reemplazar el UNIQUE simple de `codigo` por un
-- UNIQUE compuesto (codigo, link_generado), de modo que un mismo invitador
-- pueda acumular varios links (uno por evento/serie) sin colisionar y sin
-- perder la fila base (`link_generado = ''`) que crea `crearInvitador()`.
--
-- La atribucion por `?ref=<codigo>` NO cambia: sigue resolviendo por codigo.
--
-- Ejecutar en: Supabase SQL Editor. Idempotente.
-- =====================================================================

-- 1. Quitar el UNIQUE simple de codigo (si existe).
ALTER TABLE invitadores DROP CONSTRAINT IF EXISTS invitadores_codigo_key;

-- 2. Crear el UNIQUE compuesto (codigo, link_generado).
CREATE UNIQUE INDEX IF NOT EXISTS invitadores_codigo_link_key
  ON invitadores (codigo, link_generado);

-- 3. Verificacion rapida (opcional):
-- SELECT indexdef FROM pg_indexes WHERE tablename = 'invitadores';
