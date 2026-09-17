-- ===========================================================================
-- ADR-040 - Catalogo de Plantillas Curado por la Cuenta Master
-- Sistema QR Hostal Terraza - Septiembre 2026
--
-- Archivo   : migrations/adr040_config_global_templates.sql
-- Proposito : crear la tabla de fila unica public.config_global como fuente de
--             verdad de la curacion global del catalogo de plantillas (ADR-040).
--
-- Contrato JSONB de la columna templates (referencia documental, no DDL):
--   { "version": 2, "hidden": ["slug1"], "order": ["slugA","slugB"] }
--   - hidden : slugs de theme OCULTOS. Ausente o [] = catalogo completo visible.
--              Una plantilla nueva nace VISIBLE (fail-open, forward-compatible).
--   - order  : orden de presentacion de slugs de theme. Los no listados van
--              despues, en orden DOM.
--   - version: permite evolucionar el documento sin romper lectores viejos.
--
-- Regla de escritura (ADR-003 - Cero Borrado Logico en el documento):
--   El front NUNCA reemplaza el documento completo; hace merge JSONB:
--     SET templates = COALESCE(templates,'{}'::jsonb) || $1::jsonb
--
-- Seguridad:
--   - RLS habilitado en la tabla.
--   - SELECT: cualquier usuario authenticated (dato no sensible, sin PII).
--   - INSERT/UPDATE/DELETE: solo la cuenta master (rol 'superadmin' + org con
--     is_master_org = true), via public.is_master_org_user(), espejo SQL de
--     _IS_SYSTEM_ADMIN() (admin.html, ADR-025). Los numeros de linea NO son
--     contrato (ADR-006): no citar admin.html:NNNN en comentarios normativos.
--   - Escritura del front: se expone la RPC public.fn_config_global_merge(jsonb)
--     que valida la cuenta master, hace merge JSONB server-side y sella
--     updated_by = auth.uid(). Ver seccion 5.
--   - updated_by uuid SIN foreign key a auth.users a proposito: es auditoria,
--     no integridad referencial; evita acoplar la migracion al esquema auth.
--
-- Caracteristicas:
--   - Idempotente (IF NOT EXISTS / DROP POLICY IF EXISTS / CREATE OR REPLACE).
--   - Aditivo puro: NO altera ninguna tabla existente (Cero Borrado).
--   - 100% ASCII (cero bytes > 127).
--   - Ejecutable copiando/pegando en el SQL Editor de Supabase.
--
-- Dependencias (columnas verificadas contra el repo, ADR-006):
--   - public.perfiles(id, rol, org_id)          -> existe
--   - public.organizaciones(id, is_master_org)  -> existe (ADR-025)
--   - El owner de la funcion debe poder leer perfiles/organizaciones (en
--     Supabase, el rol postgres). is_superadmin()/get_org_id() viven en la
--     instancia (adr036 los asume); por eso este helper se define defensivo.
-- ===========================================================================


BEGIN;


-- ---------------------------------------------------------------------------
-- 1. TABLA DE FILA UNICA (id = 'default') + RLS
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.config_global (
  id         text PRIMARY KEY,
  templates  jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid
);

COMMENT ON TABLE public.config_global IS
'Configuracion global de plataforma (ADR-040). Fila unica id = ''default''. '
'Columna templates: { "version": 2, "hidden": [slugs ocultos], "order": [slugs ordenados] }. '
'Se guarda lo OCULTO (una plantilla nueva nace visible) y el ORDEN de presentacion. '
'Escritura solo para la cuenta master via public.is_master_org_user(); SELECT para authenticated.';

COMMENT ON COLUMN public.config_global.templates IS
'Contrato JSONB de visibilidad y orden del catalogo de plantillas. Merge obligatorio '
'(ADR-003): templates = COALESCE(templates,''{}''::jsonb) || $1::jsonb. Nunca reemplazo total.';

COMMENT ON COLUMN public.config_global.updated_by IS
'uid del autor del ultimo cambio (auth.uid()). Sin FK a auth.users a proposito: auditoria, no integridad referencial.';

ALTER TABLE public.config_global ENABLE ROW LEVEL SECURITY;


-- ---------------------------------------------------------------------------
-- 2. FILA UNICA POR DEFECTO
--
-- Documento vacio = catalogo completo visible (fail-open, ADR-040).
-- ON CONFLICT DO NOTHING: re-ejecutar NUNCA pisa la configuracion curada.
-- ---------------------------------------------------------------------------

INSERT INTO public.config_global (id, templates)
VALUES ('default', '{}'::jsonb)
ON CONFLICT (id) DO NOTHING;


-- ---------------------------------------------------------------------------
-- 3. HELPER ESPEJO DE _IS_SYSTEM_ADMIN() (admin.html, aprox.; sin numeros de
--    linea porque no son contrato - ADR-006)
--
--   _IS_SYSTEM_ADMIN() = currentPerfil.rol === 'superadmin'
--                        && _orgData.is_master_org === true     (ADR-025)
--
-- SECURITY DEFINER: permite leer perfiles/organizaciones sin depender de las
-- politicas RLS del invocante y evita recursion de RLS al evaluar la politica
-- de config_global (mismo recurso que adr037).
-- SET search_path = public, pg_temp: acota el search_path y evita hijacking.
-- LANGUAGE sql STABLE: sin efectos secundarios, resultado estable por consulta.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.is_master_org_user()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
  SELECT EXISTS (
    SELECT 1
    FROM public.perfiles p
    JOIN public.organizaciones o ON o.id = p.org_id
    WHERE p.id = auth.uid()
      AND p.rol = 'superadmin'
      AND o.is_master_org = true
  );
$fn$;

-- Defensivo: la politica RLS se evalua con privilegios del invocante, asi que
-- authenticated necesita EXECUTE. PostgreSQL lo otorga a PUBLIC por defecto;
-- este GRANT explicito lo asegura si ese default fue revocado.
GRANT EXECUTE ON FUNCTION public.is_master_org_user() TO authenticated;


-- ---------------------------------------------------------------------------
-- 4. POLITICAS RLS
--
--   config_global_select_auth : SELECT para authenticated (dato no sensible).
--   config_global_write_master: INSERT/UPDATE/DELETE solo cuenta master.
--
-- Nota: la lectura es authenticated, NO anon. El unico consumidor hoy es
-- admin.html (post-login). Si una pagina publica necesitara el catalogo, se
-- extiende a anon en un ADR explicito, no por defecto.
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS "config_global_select_auth" ON public.config_global;
CREATE POLICY "config_global_select_auth"
  ON public.config_global FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "config_global_write_master" ON public.config_global;
CREATE POLICY "config_global_write_master"
  ON public.config_global FOR ALL
  TO authenticated
  USING (public.is_master_org_user())
  WITH CHECK (public.is_master_org_user());


-- ---------------------------------------------------------------------------
-- 5. RPC DE MERGE JSONB SERVER-SIDE (contrato que consume el front)
--
-- Firma: public.fn_config_global_merge(p_templates jsonb)
--        RETURNS TABLE (templates jsonb, updated_at timestamptz)
--
-- Por que existe: el front NO debe hacer UPDATE directo con reemplazo total
-- (rompe el Cero Borrado Logico, ADR-003). Esta RPC hace el merge en el
-- servidor:  templates = COALESCE(templates,'{}'::jsonb) || p_templates
-- y sella la auditoria con updated_by = auth.uid() y updated_at = now().
--
-- Seguridad:
--   - SECURITY DEFINER + search_path acotado (mismo patron que is_master_org_user).
--   - Exige cuenta master: si is_master_org_user() es false, lanza
--     ERRCODE 42501 (insufficient_privilege). El candado NO depende del DOM.
--   - Devuelve la fila actualizada (templates, updated_at) para que el front
--     refresque su copia en memoria y su cache de localStorage sin un SELECT extra.
--   - auth.uid() sigue leyendo el JWT del invocante aunque la funcion sea
--     SECURITY DEFINER: es un ajuste de sesion, no un privilegio de rol.
--
-- Contrato de p_templates: documento PARCIAL, tipicamente
--   { "version": 2, "hidden": ["slug1"], "order": ["slugA","slugB"] }
-- El merge es superficial (operador || de jsonb): las claves de primer nivel
-- que llegan reemplazan a las del documento actual. Se guarda lo OCULTO y el
-- ORDEN; una plantilla nueva nace visible (ausente de hidden = visible).
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_config_global_merge(p_templates jsonb)
RETURNS TABLE (templates jsonb, updated_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
BEGIN
  IF NOT public.is_master_org_user() THEN
    RAISE EXCEPTION 'Solo la cuenta master puede modificar el catalogo de plantillas' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  UPDATE public.config_global
     SET templates  = COALESCE(config_global.templates, '{}'::jsonb) || COALESCE(p_templates, '{}'::jsonb),
         updated_at = now(),
         updated_by = auth.uid()
   WHERE config_global.id = 'default'
  RETURNING config_global.templates, config_global.updated_at;
END;
$fn$;

COMMENT ON FUNCTION public.fn_config_global_merge(jsonb) IS
'RPC de merge del catalogo de plantillas (ADR-040). Recibe un documento JSONB parcial '
'(p_templates), lo mezcla server-side sobre config_global.templates con el operador || '
'(nunca reemplazo total, ADR-003), sella updated_at = now() y updated_by = auth.uid(), y '
'devuelve RETURNS TABLE (templates jsonb, updated_at timestamptz) con la fila actualizada. '
'Exige cuenta master: public.is_master_org_user() debe ser true o lanza EXCEPTION '
'ERRCODE 42501 (insufficient_privilege). SECURITY DEFINER con search_path = public, pg_temp.';


-- ---------------------------------------------------------------------------
-- 6. GRANTS Y RECARGA DE CACHE DE POSTGREST
--
-- NOTIFY pgrst 'reload schema': una sola vez, al final y despues de todo el DDL,
-- para que PostgREST vea la tabla y la RPC nuevas. Sin esto la lectura de
-- config_global puede fallar silenciosamente (fail-open: todo visible).
-- ---------------------------------------------------------------------------

GRANT SELECT, INSERT, UPDATE, DELETE ON public.config_global TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_config_global_merge(jsonb) TO authenticated;

NOTIFY pgrst, 'reload schema';


COMMIT;


-- ===========================================================================
-- ROLLBACK (ejecutar manualmente solo si se necesita revertir; el orden importa)
--
-- BEGIN;
--   DROP POLICY IF EXISTS "config_global_select_auth" ON public.config_global;
--   DROP POLICY IF EXISTS "config_global_write_master" ON public.config_global;
--   DROP TABLE IF EXISTS public.config_global;
--   DROP FUNCTION IF EXISTS public.fn_config_global_merge(jsonb);
--   DROP FUNCTION IF EXISTS public.is_master_org_user();
--   NOTIFY pgrst, 'reload schema';
-- COMMIT;
--
-- NOTA: DROP FUNCTION solo si ninguna otra politica u objeto usa
--       public.is_master_org_user().
-- ===========================================================================
