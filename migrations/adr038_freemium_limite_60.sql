-- ═══════════════════════════════════════════════════════════════════════════
-- ADR-038 · Modelo Comercial: ajuste limite freemium 100 -> 60 asistentes
-- Sistema QR Hostal Terraza · Septiembre 2026
--
-- Proposito: reducir el limite duro del plan freemium de 100 a 60 inscritos
-- por evento (decision de Direccion). Supersede el trigger creado en ADR-037
-- (trg_inscritos_freemium_limite) que usaba el umbral de 100.
--
-- Modelo vigente (ADR-037 + ADR-038):
--   freemium      ($0)         limite duro 60 inscritos/evento + marca de agua
--   pass_evento   ($40.000)    1 evento activo, inscritos ilimitados
--   pro_mensual   ($400.000)   eventos e inscritos ilimitados / mes
--   enterprise    (interno)    org maestra (ADR-025), sin restricciones
--
-- Idempotente: puede ejecutarse 2+ veces sin error. Correr DESPUES de adr037
-- en el Supabase SQL Editor (patron de ejecucion manual de la Direccion).
--
-- Riesgo conocido (pre-existente desde ADR-037): el patron count-then-insert
-- del trigger tiene una ventana TOCTOU bajo inserciones concurrentes; para un
-- limite duro estricto se requeriria SELECT ... FOR UPDATE sobre eventos o un
-- advisory lock. Aceptado para este alcance.
-- ═══════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- TRIGGER DE GARANTIA DURA: limite freemium (60 inscritos / evento)
--
-- CREATE OR REPLACE FUNCTION actualiza el umbral de 100 -> 60 sin necesidad de
-- alterar permisos ni dependencias. El DROP/CREATE del trigger mantiene la
-- misma politica (BEFORE INSERT FOR EACH ROW) del ADR-037.
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

  IF v_total >= 60 THEN
    RAISE EXCEPTION 'LIMITE_FREEMIUM: el evento alcanzo el limite de 60 inscritos del plan gratuito'
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

RAISE NOTICE '[INFO] ADR-038: trigger "trg_inscritos_freemium_limite" re-creado con limite de 60 inscritos.';

-- ─────────────────────────────────────────────────────────────────────────────
-- VERIFICACION (para Direccion)
-- ─────────────────────────────────────────────────────────────────────────────

SELECT tgname, tgrelid::regclass AS tabla, pg_get_triggerdef(oid) AS definicion
FROM pg_trigger
WHERE tgname = 'trg_inscritos_freemium_limite';