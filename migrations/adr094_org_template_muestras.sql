-- ===========================================================================
-- ADR-094 - Evento de muestra real por silo en el preview de ADN Visual
-- Sistema QR Hostal Terraza - Noviembre 2026
--
-- Archivo   : migrations/adr094_org_template_muestras.sql
-- Proposito : crear public.org_template_muestras, la tabla que guarda el
--             evento REAL elegido por el operador como muestra del preview
--             de ADN (wizard de admin.html, paso 2). Clave natural por
--             silo: (org_id, template_id). 16 silos, NO 22 themes: los
--             themes que comparten silo comparten muestra (ADR-094 R1).
-- Fuente    : Sistema QR desarrollo/decisiones/
--             ADR-094-evento-de-muestra-real-por-silo-en-el-preview-de-adn.md
--             seccion 4 (contrato SQL auditado por @architect-review, v1.1).
--
-- ESTADO: ESCRITO, NO EJECUTADO. La aplicacion es MANUAL.
--
-- ---------------------------------------------------------------------------
-- RUNBOOK DE APLICACION (SQL Editor de Supabase, rol postgres)
-- ---------------------------------------------------------------------------
--   1. Dashboard > SQL Editor > New query.
--   2. Confirmar que la sesion corre como owner de las tablas y el tipo real
--      de las dos columnas referenciadas (ADR-006: validar antes de escribir):
--        SELECT current_user, session_user;   -- esperado: postgres
--        SELECT table_name, column_name, data_type
--          FROM information_schema.columns
--         WHERE table_schema = 'public'
--           AND table_name IN ('organizaciones','eventos')
--           AND column_name = 'id';           -- esperado: uuid y text
--   3. Pegar el archivo COMPLETO y ejecutar. El script abre con BEGIN y
--      cierra con COMMIT: si B0 falla, no queda DDL a medias.
--   4. FALLBACK si el editor parte el script (o el portapapeles lo trunca):
--      ejecutar bloque por bloque en el orden B0 -> B8. Cada bloque es
--      re-ejecutable por separado (IF NOT EXISTS / DROP ... IF EXISTS /
--      CREATE OR REPLACE); el BEGIN/COMMIT solo agrupa, no es requisito de
--      correccion. NO reordenar: B2, B3, B5 y B6 dependen de la tabla de B1.
--   5. Verificar (V2 del ADR): \d public.org_template_muestras (PK
--      (org_id, template_id), 2 CHECK, 2 FK), relrowsecurity = true,
--      2 policies, 1 trigger, indice org_template_muestras_evento_idx.
--   6. Re-ejecutar el archivo COMPLETO: debe terminar sin error y dejar la
--      MISMA definicion (idempotencia, ADR-008).
--   7. Si B0 aborta con 42883: get_org_id() / is_master_org_user() no viven
--      en public en esta instancia. NO aplicar a ciegas: descalificar (o
--      corregir) la llamada en las 3 referencias de B6 y volver a correr.
--
-- ---------------------------------------------------------------------------
-- ROLLBACK (solo si Direccion decide retirar la funcionalidad)
-- ---------------------------------------------------------------------------
--   DROP TABLE IF EXISTS public.org_template_muestras;
--   DROP FUNCTION IF EXISTS public.fn_org_template_muestras_guard();
--   NOTIFY pgrst, 'reload schema';
--
--   El DROP TABLE se lleva PK, los 2 CHECK, las 2 FK, el indice, el trigger,
--   las 2 policies y los grants: no queda objeto huerfano. El DROP FUNCTION
--   va DESPUES del DROP TABLE (el trigger depende de la funcion). No se
--   pierde dato de negocio: la tabla solo guarda punteros de UI (que evento
--   usar como muestra de cada silo). eventos y organizaciones no se tocan.
--
-- ---------------------------------------------------------------------------
-- ORDEN DE EJECUCION (si el editor parte el script)
-- ---------------------------------------------------------------------------
--   B0 pre-flight pg_proc | B1 tabla desnuda | B2 PK | B3 CHECKs
--   B4 indice             | B5 trigger       | B6 RLS + policies
--   B7 GRANT/REVOKE       | B8 reload schema
--
-- ---------------------------------------------------------------------------
-- REGLAS
-- ---------------------------------------------------------------------------
--   - 100% ASCII: cero bytes > 127 en todo el archivo (ADR-002, BUG-026).
--   - Idempotente (ADR-008): segunda corrida = no-op o misma definicion.
--   - Cero Borrado: no borra ni reescribe filas de eventos/organizaciones.
--   - 0 endpoints nuevos: el admin escribe con el cliente Supabase actual.
--   - RLS: solo authenticated de la MISMA org, o cuenta master. anon no
--     recibe privilegio (REVOKE explicito en B7) ni policy.
--   - La identidad del evento se valida en el servidor (B5), no en el
--     cliente: get_org_id() protege la fila de la muestra, no la del evento
--     apuntado.
--
-- NOTA DE ALCANCE (limitacion conocida, no cubierta por el ADR):
--   Las 2 FK se declaran inline en B1 (CREATE TABLE IF NOT EXISTS). Si una
--   corrida anterior dejo una FK con OTRO ON DELETE, este script no la
--   corrige: requiere DROP CONSTRAINT + ADD CONSTRAINT manual. En una tabla
--   nueva (caso esperado) no aplica.
-- ===========================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- B0. PRE-FLIGHT: las funciones de RLS deben vivir en public.
-- ---------------------------------------------------------------------------
-- Sin este chequeo el error aparece recien al crear la policy (B6), a mitad
-- del script y con DDL ya aplicado. Abortar temprano es mas limpio: el
-- COMMIT nunca llega y no queda nada a medias.
-- Si viven en otro esquema, NO se aplica a ciegas: se descalifica la llamada
-- en las policies (o se corrige el nombre) y se vuelve a correr.
DO $pre$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'get_org_id'
  ) THEN
    RAISE EXCEPTION 'adr094 pre-flight: no existe public.get_org_id(); revisa el esquema real y descalifica la llamada en las policies'
      USING ERRCODE = '42883';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'is_master_org_user'
  ) THEN
    RAISE EXCEPTION 'adr094 pre-flight: no existe public.is_master_org_user()'
      USING ERRCODE = '42883';
  END IF;
END
$pre$;

-- ---------------------------------------------------------------------------
-- B1. TABLA DESNUDA (sin PK ni CHECK inline)
-- ---------------------------------------------------------------------------
-- Los constraints se agregan en B2/B3 con DROP IF EXISTS + ADD (patron
-- adr088:109-115): asi la segunda corrida CORRIGE una definicion previa en
-- vez de no hacer nada. Un CREATE TABLE IF NOT EXISTS con constraints
-- inline dejaria intacta una definicion vieja.
--
-- evento_id es text porque eventos.id es text (misma convencion que
-- logs.evento_id, adr079). ON DELETE CASCADE: si se borra el evento, la
-- muestra se limpia y el preview vuelve al estado vacio; no queda puntero
-- roto. No es borrado de dato de negocio, es un puntero de UI.
-- updated_by uuid SIN FK a auth.users a proposito: es auditoria, no
-- integridad referencial (mismo criterio que adr040). El trigger de B5 lo
-- sella con auth.uid() e ignora lo que mande el cliente.
CREATE TABLE IF NOT EXISTS public.org_template_muestras (
  org_id         uuid        NOT NULL
                 REFERENCES public.organizaciones(id) ON DELETE CASCADE,
  template_id    text        NOT NULL,
  evento_id      text        NOT NULL
                 REFERENCES public.eventos(id) ON DELETE CASCADE,
  categoria_slug text        NOT NULL,
  updated_at     timestamptz NOT NULL DEFAULT now(),
  updated_by     uuid        DEFAULT auth.uid()
);

COMMENT ON TABLE public.org_template_muestras IS
  'ADR-094: evento real usado como muestra del preview de ADN en admin.html. Clave = (org_id, template_id); 16 silos, no themes.';

-- ---------------------------------------------------------------------------
-- B2. PK (org_id, template_id)
-- ---------------------------------------------------------------------------
-- DROP + ADD, no ADD suelto: la PK es la clave del upsert del admin
-- (onConflict: 'org_id,template_id').
ALTER TABLE public.org_template_muestras
  DROP CONSTRAINT IF EXISTS org_template_muestras_pkey;
ALTER TABLE public.org_template_muestras
  ADD CONSTRAINT org_template_muestras_pkey PRIMARY KEY (org_id, template_id);

-- ---------------------------------------------------------------------------
-- B3. CHECKs de normalizacion
-- ---------------------------------------------------------------------------
-- Sin whitelist de los 16 silos: el catalogo de silos es CODIGO
-- (css/templates/**, _TPL_CON_SILO en admin.html), no una tabla. Un CHECK
-- con lista obligaria a DDL por cada silo nuevo y contradiria ADR-006.
-- Solo se valida forma: no vacio y ya normalizado en minusculas sin espacios
-- en los bordes (el trigger de B5 normaliza antes de que el CHECK evalue).
ALTER TABLE public.org_template_muestras
  DROP CONSTRAINT IF EXISTS org_template_muestras_template_chk;
ALTER TABLE public.org_template_muestras
  ADD CONSTRAINT org_template_muestras_template_chk
  CHECK (template_id <> '' AND template_id = lower(btrim(template_id)));

ALTER TABLE public.org_template_muestras
  DROP CONSTRAINT IF EXISTS org_template_muestras_categoria_chk;
ALTER TABLE public.org_template_muestras
  ADD CONSTRAINT org_template_muestras_categoria_chk
  CHECK (categoria_slug <> '' AND categoria_slug = lower(btrim(categoria_slug)));

-- ---------------------------------------------------------------------------
-- B4. INDICE sobre evento_id
-- ---------------------------------------------------------------------------
-- Acelera el ON DELETE CASCADE y la busqueda "que silos usan este evento".
-- NO es UNIQUE a proposito: el mismo evento puede ser muestra de varios
-- silos (4 themes de cinematografia comparten c1, etc.).
CREATE INDEX IF NOT EXISTS org_template_muestras_evento_idx
  ON public.org_template_muestras (evento_id);

-- ---------------------------------------------------------------------------
-- B5. TRIGGER: valida pertenencia del evento y sella auditoria
-- ---------------------------------------------------------------------------
-- SECURITY DEFINER + search_path fijo, igual que is_master_org_user()
-- (migrations/adr040_config_global_templates.sql:105-118): sin esto la RLS
-- de eventos podria ocultar la fila y bloquear escrituras legitimas de la
-- propia org.
-- Un solo RAISE, ERRCODE 42501 (insufficient_privilege), sin eco de
-- NEW.evento_id: el mensaje no distingue "no existe" de "es de otra org",
-- asi la respuesta no sirve de oraculo para enumerar ids ajenos.
-- Tambien normaliza template_id / categoria_slug y sella updated_at /
-- updated_by en el servidor, en INSERT y en UPDATE.
CREATE OR REPLACE FUNCTION public.fn_org_template_muestras_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_org uuid;
BEGIN
  SELECT e.org_id INTO v_org FROM public.eventos e WHERE e.id = NEW.evento_id;
  -- Un solo RAISE, sin eco del evento recibido y con ERRCODE 42501
  -- (insufficient_privilege): no distingue "no existe" de "es de otra org",
  -- asi la respuesta no sirve de oraculo para enumerar ids ajenos.
  IF v_org IS NULL OR v_org IS DISTINCT FROM NEW.org_id THEN
    RAISE EXCEPTION 'org_template_muestras: la muestra debe apuntar a un evento de la misma organizacion'
      USING ERRCODE = '42501';
  END IF;
  NEW.template_id := lower(btrim(NEW.template_id));
  NEW.categoria_slug := lower(btrim(NEW.categoria_slug));
  NEW.updated_at := now();
  NEW.updated_by := auth.uid();
  RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS trg_org_template_muestras_guard ON public.org_template_muestras;
CREATE TRIGGER trg_org_template_muestras_guard
BEFORE INSERT OR UPDATE ON public.org_template_muestras
FOR EACH ROW EXECUTE FUNCTION public.fn_org_template_muestras_guard();

-- ---------------------------------------------------------------------------
-- B6. RLS + POLICIES
-- ---------------------------------------------------------------------------
-- 2 policies, ambas permissive (se suman por OR):
--   select_org -> SELECT de la propia org (o cuenta master).
--   write_org  -> INSERT/UPDATE/DELETE con USING y WITH CHECK, para que un
--                 upsert no pueda mover una fila a otra org ni escribir con
--                 org_id ajeno.
-- El catalogo de la muestra NO se lee desde el sitio publico: 0 policies
-- para anon, y el privilegio se revoca en B7.
ALTER TABLE public.org_template_muestras ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS org_template_muestras_select_org ON public.org_template_muestras;
CREATE POLICY org_template_muestras_select_org
  ON public.org_template_muestras FOR SELECT TO authenticated
  USING (org_id = public.get_org_id() OR public.is_master_org_user());

DROP POLICY IF EXISTS org_template_muestras_write_org ON public.org_template_muestras;
CREATE POLICY org_template_muestras_write_org
  ON public.org_template_muestras FOR ALL TO authenticated
  USING (org_id = public.get_org_id() OR public.is_master_org_user())
  WITH CHECK (org_id = public.get_org_id() OR public.is_master_org_user());

-- ---------------------------------------------------------------------------
-- B7. PRIVILEGIOS
-- ---------------------------------------------------------------------------
-- Supabase otorga ALL a anon/authenticated por default privileges del
-- esquema public: sin el REVOKE explicito la tabla quedaria expuesta al rol
-- anon aunque no exista policy para el (RLS niega filas, pero el privilegio
-- sigue concedido). El REVOKE es obligatorio, no cosmetico.
-- Una policy no concede privilegios por si sola: sin GRANT, el panel recibe
-- 42501 aunque la policy permita. Se conceden los 4 explicitos.
GRANT SELECT, INSERT, UPDATE, DELETE ON public.org_template_muestras TO authenticated;
REVOKE ALL ON public.org_template_muestras FROM anon;

-- ---------------------------------------------------------------------------
-- B8. Recarga el cache de schema de PostgREST
-- ---------------------------------------------------------------------------
-- Sin esto el cliente sigue viendo "relation does not exist" hasta el
-- siguiente reload. Dentro del BEGIN se entrega al COMMIT.
NOTIFY pgrst, 'reload schema';

COMMIT;
