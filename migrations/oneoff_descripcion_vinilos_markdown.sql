-- oneoff_descripcion_vinilos_markdown.sql  (2026-11-10)
-- Vinilos InVersos: corrige el typo 'muisic' -> 'music' y marca el cierre de la
-- descripcion en negrita + cursiva (markdown-lite interpretado por el motor
-- publico evento-app.html y por la toolbar de admin.html).
-- Alcance: 1 fila (slug fijo), 1 columna (eventos.descripcion). ASCII puro.
-- Idempotente: si el bloque ya fue reemplazado, el WHERE no matchea.
-- Ejecutar en el SQL Editor de Supabase (RLS bloquea el UPDATE con anon key).

BEGIN;

UPDATE eventos
   SET descripcion = replace(
         descripcion,
         'Vinilos InVersos ' || chr(10) || 'La muisicolog' || chr(237) || 'a como identidad y resistencia',
         'Vinilos InVersos' || chr(10) || '***La musicolog' || chr(237) || 'a como identidad y resistencia.***'
       )
 WHERE slug = 'vinilos-inversos-c8yu'
   AND position('muisicolog' in descripcion) > 0
RETURNING slug, length(descripcion) AS len_after;

COMMIT;

-- Verificacion posterior (esperado: len_after = 417, typo_pos = 0,
-- tail = "Vinilos InVersos\n***La musicologia...resistencia.***"):
-- SELECT length(descripcion) AS len_after,
--        position('muisicolog' in descripcion) AS typo_pos,
--        right(descripcion, 62) AS tail
--   FROM eventos WHERE slug = 'vinilos-inversos-c8yu';
