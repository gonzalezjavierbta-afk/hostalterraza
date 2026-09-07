-- ═══════════════════════════════════════════════════════════════════════
-- ADR-034 — Cabezote del formulario de registro (columna cabezote_formulario_url)
-- Sistema QR Hostal Terraza
--
-- Contexto: la página registroaforo.html muestra un cabezote (imagen superior)
-- en su formulario de registro/aforo. Hasta ahora reutilizaba
-- imagen_url/poster_url del evento. Se requiere que cada evento pueda definir
-- una imagen independiente para ese cabezote, administrable desde el panel
-- (campo "Cabezote de formulario").
--
-- Decisiones de esquema (Data-First, mínima superficie):
--   • Se añade UNA columna texto `cabezote_formulario_url` en `eventos`.
--     `NULL` equivale a comportamiento legacy (usar imagen_url/poster_url).
--   • No requiere políticas RLS nuevas: el panel admin actualiza `eventos` con
--     la clave anon y las políticas existentes cubren la nueva columna.
--   • Se asigna la imagen local del cabezote del formulario al evento
--     salsa-flow-nt65 (petición operativa): el archivo vive en
--     /imagenes/cabezote tropilove formulario.jpg.jpeg (desplegado en Vercel).
--
-- Este script es IDEMPOTENTE (ADD COLUMN IF NOT EXISTS / UPDATE condicionado):
-- seguro ejecutarlo sin importar si la columna ya existe o el valor fue editado.
--
-- Ejecutar en: Supabase SQL Editor.
-- Reversible: ver bloque ROLLBACK comentado al final.
-- ═══════════════════════════════════════════════════════════════════════

ALTER TABLE eventos
  ADD COLUMN IF NOT EXISTS cabezote_formulario_url text;

-- Asignación operativa del cabezote del formulario al evento solicitado.
-- Solo escribe si el campo está vacío (no pisa configuraciones hechas en admin).
UPDATE eventos
SET cabezote_formulario_url = '/imagenes/cabezote%20tropilove%20formulario.jpg.jpeg'
WHERE slug = 'salsa-flow-nt65'
  AND (cabezote_formulario_url IS NULL OR cabezote_formulario_url = '');

-- ═══════════════════════════════════════════════════════════════════════
-- ROLLBACK (ejecutar manualmente solo si es necesario revertir):
--
-- UPDATE eventos SET cabezote_formulario_url = NULL WHERE slug = 'salsa-flow-nt65';
-- ALTER TABLE eventos DROP COLUMN IF EXISTS cabezote_formulario_url;
-- ═══════════════════════════════════════════════════════════════════════