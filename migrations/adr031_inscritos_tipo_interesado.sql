-- ═══════════════════════════════════════════════════════════════════════
-- ADR-031 — Nueva categoría "interesado" en inscritos.tipo
-- Sistema QR Hostal Terraza
--
-- Contexto: el formulario del landing (evento.html) captura usuarios que se
-- quieren unir a la comunidad de WhatsApp del evento. Al insertar usaba el
-- valor `tipo -> 'comunidad'` (y luego `'interesado'`) que NO está en el
-- CHECK CONSTRAINT `inscritos_tipo_check`, provocando el error 400/23514:
--   "new row for relation 'inscritos' violates check constraint
--    'inscritos_tipo_check'".
--
-- Solución (Data-First, mínima superficie): ampliar el CHECK para aceptar la
-- nueva categoría 'interesado', PRESERVANDO todos los valores vigentes.
-- Postgres no permite "ADD VALUE" sobre un CHECK, así que se elimina y se
-- recrea con la lista completa (los 9 valores actuales + 'interesado').
--
-- Ejecutar en: Supabase SQL Editor.
-- Reversible: ver bloque ROLLBACK comentado al final.
-- ═══════════════════════════════════════════════════════════════════════

-- 1. Quitar el check actual (preserva el nombre sin errores si no existe).
ALTER TABLE inscritos DROP CONSTRAINT IF EXISTS inscritos_tipo_check;

-- 2. Recrear el check con la lista completa + la nueva categoría 'interesado'.
ALTER TABLE inscritos
  ADD CONSTRAINT inscritos_tipo_check
  CHECK (tipo IN (
    'invitado',
    'frecuente',
    'artista',
    'produccion',
    'pago',
    'espacio',
    'marca',
    'voluntario',
    'donacion',
    'interesado'
  ));

-- 3. Verificación rápida (comentar/descomentar según se necesite):
-- SELECT pg_get_constraintdef(oid) AS def
-- FROM pg_constraint
-- WHERE conname = 'inscritos_tipo_check';

-- ═══════════════════════════════════════════════════════════════════════
-- ROLLBACK (restaura el check original sin la categoría 'interesado'):
--
-- ALTER TABLE inscritos DROP CONSTRAINT IF EXISTS inscritos_tipo_check;
-- ALTER TABLE inscritos
--   ADD CONSTRAINT inscritos_tipo_check
--   CHECK (tipo IN (
--     'invitado','frecuente','artista','produccion','pago',
--     'espacio','marca','voluntario','donacion'
--   ));
-- ═══════════════════════════════════════════════════════════════════════
