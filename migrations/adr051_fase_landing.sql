-- ===========================================================================
-- ADR-051: Fase de landing por evento (completa / proximamente)
-- Sistema QR Hostal Terraza - Septiembre 2026
--
-- Archivo   : migrations/adr051_fase_landing.sql
-- Fecha     : 2026-09-22
-- Proposito : anadir la columna public.eventos.fase_landing, que define la
--             profundidad de presentacion del landing publico del evento.
--
-- Modelo:
--   completa      (DEFAULT) landing ampliada (todos los modulos del
--                           Contrato de Datos vigente).
--   proximamente            teaser: hero / titulo / subtitulo / contador /
--                           meta + boton WhatsApp.
--
-- Ortogonalidad (CRITICO):
--   * fase_landing es ORTOGONAL al gate comercial eventos.estado de ADR-037.
--     estado controla SI el evento puede publicarse (borrador /
--     pendiente_pago / publicado); fase_landing controla QUE TAN PROFUNDA
--     es su landing una vez publicada.
--   * Esta migracion NO toca eventos.estado ni el constraint
--     eventos_estado_check de ADR-037.
--   * El subtitulo del teaser NO vive en una columna: vive en el JSON
--     config_landing. Esta migracion NO crea columna de subtitulo.
--
-- Contenido:
--   1. ALTER TABLE: columna fase_landing text NOT NULL DEFAULT 'completa'.
--   2. DO $$: constraint eventos_fase_landing_check (idempotente).
--   3. COMMENT ON COLUMN: documentacion viva de la columna.
--   4. Verificacion (SELECTs informativos para Direccion).
--   5. NOTIFY pgrst: recarga del schema cache de PostgREST.
--
-- IDEMPOTENTE: puede ejecutarse 2+ veces sin error ni cambio de estado
-- (ADD COLUMN IF NOT EXISTS + guarda en pg_constraint).
--
-- Reversible: ver bloque ROLLBACK (comentado) al final.
--
-- Caracteristicas: 100% ASCII (cero bytes > 127), cero backticks, cero
-- comillas tipograficas. NO crea RPCs, NO crea triggers, NO crea tablas,
-- NO modifica datos existentes.
--
-- Ejecutar manualmente en Supabase SQL Editor (patron de ejecucion manual
-- de la Direccion; NO ejecutado por este agente). Correr DESPUES de adr037.
-- ===========================================================================


-- ---------------------------------------------------------------------------
-- 1. COLUMNA public.eventos.fase_landing
--
-- NOT NULL DEFAULT 'completa': los eventos existentes quedan en la landing
-- ampliada (sin cambio de comportamiento) y el default aplica a los nuevos.
-- ---------------------------------------------------------------------------

ALTER TABLE public.eventos
  ADD COLUMN IF NOT EXISTS fase_landing text NOT NULL DEFAULT 'completa';


-- ---------------------------------------------------------------------------
-- 2. CONSTRAINT eventos_fase_landing_check (idempotente)
--
-- Se crea SOLO si no existe, consultando pg_constraint por su nombre
-- canonico. RAISE NOTICE en ambas ramas (creado / ya existia) para dejar
-- traza en el log de ejecucion del SQL Editor.
-- ---------------------------------------------------------------------------

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    JOIN pg_namespace n ON n.oid = t.relnamespace
    WHERE n.nspname = 'public' AND t.relname = 'eventos'
      AND c.conname = 'eventos_fase_landing_check'
  ) THEN
    ALTER TABLE public.eventos
      ADD CONSTRAINT eventos_fase_landing_check
      CHECK (fase_landing IN ('completa','proximamente'));
    RAISE NOTICE '[INFO] ADR-051: constraint "eventos_fase_landing_check" creado.';
  ELSE
    RAISE NOTICE '[INFO] ADR-051: constraint "eventos_fase_landing_check" ya existe, skip.';
  END IF;
END $$;


-- ---------------------------------------------------------------------------
-- 3. COMMENT ON COLUMN: documentacion viva del esquema
-- ---------------------------------------------------------------------------

COMMENT ON COLUMN public.eventos.fase_landing IS
  'Fase de presentacion del landing del evento (ADR-051). Ortogonal al gate comercial eventos.estado (ADR-037): estado decide si el evento puede publicarse, fase_landing decide la profundidad de su landing. Valores: completa | proximamente. Default: completa. completa = landing ampliada (todos los modulos del Contrato de Datos vigente). proximamente = teaser (hero/titulo/subtitulo/contador/meta + boton WhatsApp). El subtitulo del teaser vive en config_landing (JSON), no en una columna.';


-- ---------------------------------------------------------------------------
-- 4. VERIFICACION (para Direccion)
-- ---------------------------------------------------------------------------

-- 4.1 La columna existe, es NOT NULL y su default es 'completa'.
SELECT column_name, data_type, column_default, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'eventos' AND column_name = 'fase_landing';

-- 4.2 El constraint existe y su definicion es la esperada.
SELECT c.conname, pg_get_constraintdef(c.oid) AS definicion
FROM pg_constraint c
JOIN pg_class t ON t.oid = c.conrelid
JOIN pg_namespace n ON n.oid = t.relnamespace
WHERE n.nspname = 'public' AND t.relname = 'eventos'
  AND c.conname = 'eventos_fase_landing_check';

-- 4.3 Distribucion actual (todos los eventos existentes deben caer en 'completa').
SELECT fase_landing, count(*) AS eventos
FROM public.eventos
GROUP BY fase_landing
ORDER BY fase_landing;


-- ---------------------------------------------------------------------------
-- 5. RECARGA DEL SCHEMA CACHE DE POSTGREST
-- ---------------------------------------------------------------------------

NOTIFY pgrst, 'reload schema';


-- ===========================================================================
-- ROLLBACK (ejecutar manualmente, sin comentar, solo si es necesario revertir)
--
-- ALTER TABLE public.eventos DROP CONSTRAINT IF EXISTS eventos_fase_landing_check;
-- ALTER TABLE public.eventos DROP COLUMN IF EXISTS fase_landing;
-- ===========================================================================
