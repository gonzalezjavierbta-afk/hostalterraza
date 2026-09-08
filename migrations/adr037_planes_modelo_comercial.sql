-- ═══════════════════════════════════════════════════════════════════════════
-- ADR-037 · Modelo Comercial: Freemium / PASS por Evento / Mensual B2B
-- Sistema QR Hostal Terraza · Septiembre 2026
--
-- Proposito: implementar el modelo de monetizacion sobre la tabla existente
-- `organizaciones.plan` (valores legacy: free/mensual/evento/combinado,
-- mas enterprise) y sobre `eventos` (nueva columna `estado`).
--
-- Modelo nuevo (decision de Direccion):
--   freemium      ($0)        limite duro 100 inscritos/evento + marca de agua
--   pass_evento   ($40.000)   1 evento activo, inscritos ilimitados
--   pro_mensual   ($400.000)   eventos e inscritos ilimitados / mes
--   enterprise    (interno)   org maestra (ADR-025), sin restricciones
--
-- Contenido:
--   1. Ampliar CHECK de organizaciones.plan (idempotente, DROP dinamico).
--   2. Migrar valores legacy -> modelo nuevo (idempotente).
--   3. Columna eventos.estado + CHECK.
--   4. Trigger de garantia dura del limite freemium en inscritos.
--   5. Verificaciones finales para Direccion.
--
-- Idempotente: puede ejecutarse 2+ veces sin error. Ejecutar en Supabase SQL
-- Editor (patron de ejecucion manual de la Direccion). Correr DESPUES de
-- adr036 (no depende de el, pero mantienen el mismo ciclo de despliegue).
-- ═══════════════════════════════════════════════════════════════════════════


-- ─────────────────────────────────────────────────────────────────────────────
-- 1. AMPLIAR CHECK de organizaciones.plan
--
-- El nombre del constraint existente puede variar entre instancias; se busca
-- dinamicamente en pg_constraint cualquier CHECK que referencie la columna
-- `plan` de organizaciones y se elimina por su nombre real. Luego se crea el
-- nuevo constraint con nombre canonico y se valida.
-- ─────────────────────────────────────────────────────────────────────────────

DO $$
DECLARE
  v_conname text;
BEGIN
  FOR v_conname IN
    SELECT c.conname
    FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    JOIN pg_namespace n ON n.oid = t.relnamespace
    JOIN pg_attribute a ON a.attrelid = t.oid
    WHERE n.nspname = 'public'
      AND t.relname = 'organizaciones'
      AND c.contype = 'c'
      AND a.attname = 'plan'
      AND a.attnum = ANY (c.conkey)
  LOOP
    EXECUTE format('ALTER TABLE public.organizaciones DROP CONSTRAINT %I', v_conname);
    RAISE NOTICE '[INFO] ADR-037: constraint CHECK legacy "organizaciones.%" eliminado.', v_conname;
  END LOOP;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    JOIN pg_namespace n ON n.oid = t.relnamespace
    WHERE n.nspname = 'public' AND t.relname = 'organizaciones'
      AND c.conname = 'organizaciones_plan_modelo_comercial_check'
  ) THEN
    ALTER TABLE public.organizaciones
      ADD CONSTRAINT organizaciones_plan_modelo_comercial_check
      CHECK (plan IN ('freemium','pass_evento','pro_mensual','enterprise'))
      NOT VALID;
    RAISE NOTICE '[INFO] ADR-037: constraint "organizaciones_plan_modelo_comercial_check" creado (NOT VALID).';
  ELSE
    RAISE NOTICE '[INFO] ADR-037: constraint "organizaciones_plan_modelo_comercial_check" ya existe, skip.';
  END IF;
END $$;


-- ─────────────────────────────────────────────────────────────────────────────
-- 2. MIGRAR valores legacy -> modelo nuevo
--
-- Idempotente: el WHERE filtra por valores legacy; tras la primera ejecucion
-- ya no existen, por lo que correr de nuevo no modifica nada.
--   free       -> freemium
--   evento     -> pass_evento
--   mensual    -> pro_mensual
--   combinado  -> pro_mensual
--   enterprise -> enterprise (intacto)
--
-- ORDEN CRITICO: la migracion DEBE ejecutarse ANTES de VALIDATE CONSTRAINT
-- (bloque 2.1), porque el constraint nuevo se crea NOT VALID y solo es
-- validable cuando todos los valores legacy ya fueron reasignados.
-- ─────────────────────────────────────────────────────────────────────────────

UPDATE public.organizaciones
SET plan = CASE plan
    WHEN 'free'       THEN 'freemium'
    WHEN 'evento'     THEN 'pass_evento'
    WHEN 'mensual'    THEN 'pro_mensual'
    WHEN 'combinado'  THEN 'pro_mensual'
    ELSE plan
  END
WHERE plan IN ('free','evento','mensual','combinado');

RAISE NOTICE '[INFO] ADR-037: migracion de planes legacy -> modelo nuevo completada.';


-- ─────────────────────────────────────────────────────────────────────────────
-- 2.1 VALIDAR el constraint NOT VALID (DESPUES de la migracion)
--
-- Recorre la tabla confirmando que los datos existentes cumplen el CHECK.
-- Como la migracion del bloque 2 ya reasigno todos los valores legacy, esta
-- validacion es segura y cierra el NOT VALID creado en el bloque 1.
-- ─────────────────────────────────────────────────────────────────────────────

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    JOIN pg_namespace n ON n.oid = t.relnamespace
    WHERE n.nspname = 'public' AND t.relname = 'organizaciones'
      AND c.conname = 'organizaciones_plan_modelo_comercial_check'
      AND c.convalidated = false
  ) THEN
    ALTER TABLE public.organizaciones
      VALIDATE CONSTRAINT organizaciones_plan_modelo_comercial_check;
    RAISE NOTICE '[INFO] ADR-037: constraint validado sobre datos existentes.';
  END IF;
END $$;


-- ─────────────────────────────────────────────────────────────────────────────
-- 3. COLUMNA eventos.estado + CHECK
--
-- Valores: 'borrador' (DEFAULT) | 'pendiente_pago' | 'publicado'
-- El frontend (admin.html ADR-037) asigna el estado al crear un evento segun
-- el plan de la organizacion. El modelo PASS exige estado 'publicado' previo
-- a considerar activo el pago.
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.eventos
  ADD COLUMN IF NOT EXISTS estado text NOT NULL DEFAULT 'borrador';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    JOIN pg_namespace n ON n.oid = t.relnamespace
    WHERE n.nspname = 'public' AND t.relname = 'eventos'
      AND c.conname = 'eventos_estado_check'
  ) THEN
    ALTER TABLE public.eventos
      ADD CONSTRAINT eventos_estado_check
      CHECK (estado IN ('borrador','pendiente_pago','publicado'));
    RAISE NOTICE '[INFO] ADR-037: constraint "eventos_estado_check" creado.';
  ELSE
    RAISE NOTICE '[INFO] ADR-037: constraint "eventos_estado_check" ya existe, skip.';
  END IF;
END $$;


-- ─────────────────────────────────────────────────────────────────────────────
-- 4. TRIGGER DE GARANTIA DURA: limite freemium (100 inscritos / evento)
--
-- Defensa en profundidad. El frontend de la landing (evento.html) tambien
-- bloquea, pero este trigger garantiza el limite incluso si alguien inserta
-- por API directamente con la clave anonima.
--
-- SECURITY DEFINER: la funcion se ejecuta con permisos del propietario para
-- poder leer `eventos`/`organizaciones` (RLS de anon no permite leer cualquier
-- fila); `search_path` acotado para evitar hijacking. El RAISE EXCEPTION
-- viaja como error de supabase-js y puede mostrarse al usuario final.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.fn_inscritos_freemium_limite()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_plan text;
  v_total int;
BEGIN
  SELECT o.plan INTO v_plan
  FROM public.eventos e
  JOIN public.organizaciones o ON o.id = e.org_id
  WHERE e.id = NEW.evento_id;

  -- Org inexistente o plan no freemium: sin restriccion.
  IF v_plan IS DISTINCT FROM 'freemium' THEN
    RETURN NEW;
  END IF;

  SELECT count(*) INTO v_total
  FROM public.inscritos
  WHERE evento_id = NEW.evento_id;

  IF v_total >= 100 THEN
    RAISE EXCEPTION 'LIMITE_FREEMIUM: el evento alcanzo el limite de 100 inscritos del plan gratuito'
      USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_inscritos_freemium_limite ON public.inscritos;
CREATE TRIGGER trg_inscritos_freemium_limite
  BEFORE INSERT ON public.inscritos
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_inscritos_freemium_limite();

RAISE NOTICE '[INFO] ADR-037: trigger "trg_inscritos_freemium_limite" activo.';


-- ─────────────────────────────────────────────────────────────────────────────
-- 5. VERIFICACION (para Direccion)
-- ─────────────────────────────────────────────────────────────────────────────

SELECT plan, count(*) AS organizaciones
FROM public.organizaciones
GROUP BY plan
ORDER BY plan;

SELECT column_name, data_type, column_default, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'eventos' AND column_name = 'estado';

SELECT tgname, tgrelid::regclass AS tabla, pg_get_triggerdef(oid) AS definicion
FROM pg_trigger
WHERE tgname = 'trg_inscritos_freemium_limite';