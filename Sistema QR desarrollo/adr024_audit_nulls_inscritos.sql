-- ═══════════════════════════════════════════════════════════════════════
-- ADR-024 — Auditoría de campos NULL en `inscritos` (Fix "Null Pointer Regression")
-- Sistema QR Hostal Terraza
--
-- Contexto: el panel truena con TypeError cuando `inscritos.nombre` o
-- `inscritos.evento_nombre` son NULL (caso detectado: org "Barrio R10").
-- El fix de admin.html (ADR-024) ya blinda la UI para que esto no vuelva a
-- bloquear el panel — esta consulta es para que Dirección/Gemini ubiquen
-- QUÉ registros y QUÉ organizaciones tienen datos incompletos, de cara a
-- decidir si conviene además completarlos en el origen.
--
-- Es de SOLO LECTURA — no modifica nada. Segura de correr en cualquier
-- momento, incluida producción.
-- Ejecutar en: Supabase SQL Editor.
-- ═══════════════════════════════════════════════════════════════════════

-- 1. Registros con los DOS campos que causaron el crash reportado
--    (nombre / evento_nombre) — máxima prioridad.
SELECT
  i.id,
  i.evento_id,
  e.org_id,
  i.nombre,
  i.evento_nombre,
  i.cedula,
  i.tipo,
  i.created_at
FROM inscritos i
LEFT JOIN eventos e ON e.id = i.evento_id
WHERE i.nombre IS NULL OR i.evento_nombre IS NULL
ORDER BY i.created_at DESC;

-- 2. Resumen por organización — cuántos registros incompletos tiene cada una
--    (para confirmar si "Barrio R10" es la única afectada o hay más).
--    Ajustar `organizaciones.nombre` si la columna de nombre de la org se
--    llama distinto en tu esquema real.
--    FIX: PostgreSQL solo resuelve un alias del SELECT en ORDER BY cuando es
--    una referencia simple (ej. "ORDER BY nombre_null"); no lo hace cuando el
--    ORDER BY es una EXPRESIÓN que combina dos alias ("nombre_null +
--    evento_nombre_null") — en ese caso los trata como columnas reales
--    inexistentes y falla con "column does not exist". Se resuelve con un CTE:
--    dentro del CTE, `nombre_null`/`evento_nombre_null` son alias normales de
--    ESE SELECT; fuera de él, son columnas reales de la tabla derivada, así
--    que sí se pueden combinar en la ORDER BY del SELECT externo.
WITH conteo_por_org AS (
  SELECT
    org.nombre        AS organizacion,
    COUNT(*) FILTER (WHERE i.nombre IS NULL)        AS nombre_null,
    COUNT(*) FILTER (WHERE i.evento_nombre IS NULL) AS evento_nombre_null,
    COUNT(*) FILTER (WHERE i.cedula IS NULL)        AS cedula_null,
    COUNT(*) FILTER (WHERE i.tipo IS NULL)          AS tipo_null,
    COUNT(*)                                        AS total_inscritos
  FROM inscritos i
  LEFT JOIN eventos e ON e.id = i.evento_id
  LEFT JOIN organizaciones org ON org.id = e.org_id
  GROUP BY org.nombre
)
SELECT *
FROM conteo_por_org
WHERE nombre_null > 0 OR evento_nombre_null > 0
ORDER BY (nombre_null + evento_nombre_null) DESC;

-- 3. Barrido más amplio — nulabilidad de TODOS los campos de texto que la
--    UI interpola directamente (no solo los dos que ya truenan hoy), para
--    adelantarse a futuros casos similares antes de que bloqueen el panel.
SELECT
  COUNT(*)                                          AS total,
  COUNT(*) FILTER (WHERE nombre IS NULL)             AS nombre_null,
  COUNT(*) FILTER (WHERE evento_nombre IS NULL)      AS evento_nombre_null,
  COUNT(*) FILTER (WHERE cedula IS NULL)             AS cedula_null,
  COUNT(*) FILTER (WHERE tipo IS NULL)               AS tipo_null,
  COUNT(*) FILTER (WHERE ref_nombre IS NULL AND ref_codigo IS NULL) AS sin_referente,
  COUNT(*) FILTER (WHERE fecha_ingreso IS NULL AND used = true)     AS ingreso_sin_fecha_inconsistente
FROM inscritos;

-- ═══════════════════════════════════════════════════════════════════════
-- NOTA: esta consulta NO corrige nada — es diagnóstico. Si Dirección decide
-- completar los registros existentes en vez de (o además de) confiar en el
-- Silent Fallback de la UI, coordinar con Chief Architect antes de correr
-- cualquier UPDATE masivo — algunos NULL son legítimos por diseño (ver
-- BLUEPRINT.md §"Esquema inscritos": los 15 campos de Fase 2 de b5 quedan
-- NULL a propósito salvo los 3 de la categoría elegida).
-- ═══════════════════════════════════════════════════════════════════════
