-- ═══════════════════════════════════════════════════════════════════════════
-- ADR-036 · TSK-026 · Limpieza de politicas RLS legacy permisivas (cross-tenant)
-- Sistema QR Hostal Terraza · Septiembre 2026
--
-- Proposito: retirar las politicas legacy que conviven (OR, no reemplazo) con
-- las politicas *_org correctas y anulan el aislamiento por org_id en la
-- practica. Diagnostico completo en DECISIONS.md ADR-025 (L260-266) y
-- TASKS.md TSK-026.
--
-- Alcance:
--   ELIMINAR   eventos      "Admins escriben eventos" (ALL authenticated sin org_id)
--   ELIMINAR   clientes     "Clientes acceso total autenticado" (ALL true/true)
--   ELIMINAR   perfiles     politicas "Superadmin ..." con is_superadmin() sin org
--   REEMPLAZAR perfiles     org_perfiles_update  -> + WITH CHECK (org_id=get_org_id())
--   ELIMINAR   organizaciones select_organizaciones (USING true)
--   REEMPLAZAR organizaciones public_organizaciones_select -> acotada a org con
--                           al menos un evento publico (preserva landing anon).
--
-- CONSERVAR INTACTAS (NO se mencionan en ningun DROP ni se modifican):
--   * inscritos  "Inscritos actualizacion libre" (true/true) - scanner.html opera
--                con clave anonima sin sesion; tocarla rompe el check-in.
--   * page_events TODAS sus politicas (USING/WITH CHECK true es INTENCIONAL,
--                analitica publica, ADR-032).
--
-- Defensivo e idempotente: 100% DO $$ con verificacion en pg_policies /
-- information_schema antes de DROP/CREATE. Puede ejecutarse 2+ veces sin error.
-- Ejecutar en: Supabase SQL Editor (patron de ejecucion manual de la Direccion).
-- ═══════════════════════════════════════════════════════════════════════════


-- ─────────────────────────────────────────────────────────────────────────────
-- BLOQUE 1 · Auditoria + retiro defensivo de politicas legacy.
--
-- Detecta por substring de nombre Y de definicion (pg_get_expr de qual y
-- with_check). JAMAS dropea politicas cuyo texto referencie org_id /
-- get_org_id / is_master_org (ahí viven las *_org y las maestras de ADR-025).
-- Cada hallazgo y cada drop se documenta con RAISE NOTICE para que la
-- Direccion audite el resultado antes de cerrar TSK-026.
-- ─────────────────────────────────────────────────────────────────────────────

DO $$
DECLARE
  r          record;
  v_oid      oid;
  v_using    text;
  v_check    text;
  v_txt      text;          -- using + check concatenados
  v_org_scope boolean;      -- true si la politica menciona org_id/get_org_id
  v_legacy   boolean;
  v_total    int := 0;
BEGIN
  RAISE NOTICE '[INFO] ADR-036 BLOQUE 1: auditoria de politicas legacy en eventos/clientes/perfiles/organizaciones';

  FOR r IN
    SELECT schemaname, tablename, policyname, cmd, permissive,
           qual, with_check, roles
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN ('eventos','clientes','perfiles','organizaciones')
    ORDER BY tablename, policyname
  LOOP
    v_oid := to_regclass(format('%I.%I', r.schemaname, r.tablename));
    v_using := pg_get_expr(r.qual, v_oid);
    v_check := pg_get_expr(r.with_check, v_oid);
    v_txt := COALESCE(v_using,'') || ' || ' || COALESCE(v_check,'');
    v_org_scope := (COALESCE(v_using,'') ILIKE '%org_id%')
                OR (COALESCE(v_using,'') ILIKE '%get_org_id%')
                OR (COALESCE(v_check,'')  ILIKE '%org_id%')
                OR (COALESCE(v_check,'')  ILIKE '%get_org_id%')
                OR (r.policyname ILIKE '%_org%');
    v_legacy := false;

    RAISE NOTICE '[TRACE] revisando %: "%" (cmd=%, permissive=%, org_scope=%)',
                 r.tablename, r.policyname, r.cmd, r.permissive, v_org_scope;

    -- ── eventos ──────────────────────────────────────────────────────────
    IF r.tablename = 'eventos' THEN
      -- Patron documentado: "Admins escriben eventos" (ALL auth.role()='authenticated'
      -- sin chequeo de org_id). Se cubre por nombre y por definicion, SOLO para
      -- comandos de escritura/ALL y SOLO si no hay filtro de org.
      v_legacy := (r.policyname ILIKE '%escriben%')
               OR (r.cmd IN ('ALL','INSERT','UPDATE','DELETE')
                   AND NOT v_org_scope
                   AND (v_txt ILIKE '%authenticated%'));

    -- ── clientes ─────────────────────────────────────────────────────────
    ELSIF r.tablename = 'clientes' THEN
      -- Patron documentado: "Clientes acceso total autenticado"
      -- (USING/WITH CHECK = true). Cualquier politica sin filtro de org cuyo
      -- USING y WITH CHECK sean efectivamente `true` es una fuga: se retira.
      v_legacy := (r.policyname ILIKE '%acceso%total%')
               OR (NOT v_org_scope
                   AND (v_using IS NULL OR btrim(v_using) = 'true')
                   AND (v_check IS NULL OR btrim(v_check) = 'true'));

    -- ── perfiles ─────────────────────────────────────────────────────────
    ELSIF r.tablename = 'perfiles' THEN
      -- Patron documentado: "Superadmin lee/escribe/actualiza/elimina perfiles"
      -- usa is_superadmin() SIN acotar por organizacion -> fuga cross-tenant.
      -- Se retira solo si NO menciona org_id/get_org_id (las *_org y maestras
      -- correctas quedan intactas).
      v_legacy := (NOT v_org_scope)
                  AND ( r.policyname ILIKE '%uperadmin%'
                     OR v_txt ILIKE '%is_superadmin%' );
      -- org_perfiles_update legacy (sin WITH CHECK) se retira aqui por nombre
      -- o por definicion (UPDATE sobre fila propia sin filtro de org) y se
      -- recrea con WITH CHECK en el BLOQUE 2.
      v_legacy := v_legacy
               OR (NOT v_org_scope
                   AND (r.policyname ILIKE '%org_perfiles%update%'
                        OR (r.cmd = 'UPDATE' AND v_txt ILIKE '%auth.uid()%')));

    -- ── organizaciones ───────────────────────────────────────────────────
    ELSIF r.tablename = 'organizaciones' THEN
      -- select_organizaciones y public_organizaciones_select (ambas USING true)
      -- se retiran. public_organizaciones_select se recrea acotada en BLOQUE 3.
      v_legacy := (r.cmd = 'SELECT')
                  AND NOT v_org_scope
                  AND (v_using IS NULL OR btrim(v_using) = 'true');
    END IF;

    IF v_legacy THEN
      EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I',
                     r.policyname, r.schemaname, r.tablename);
      v_total := v_total + 1;
      RAISE NOTICE '[INFO] ADR-036 DROP %: politica legacy "%" eliminada (using=%s | check=%s)',
                   r.tablename, r.policyname, COALESCE(v_using,'<null>'), COALESCE(v_check,'<null>');
    END IF;
  END LOOP;

  RAISE NOTICE '[TIME] ADR-036 BLOQUE 1 completado: % politica(s) legacy eliminada(s).', v_total;
END $$;


-- ─────────────────────────────────────────────────────────────────────────────
-- BLOQUE 2 · REEMPLAZO de org_perfiles_update (perfiles)
--
-- Version identica a la documentada (UPDATE sobre la fila propia,
-- id = auth.uid()) PERO ahora con WITH CHECK (org_id = get_org_id()) para
-- impedir que un usuario mueva su propia fila a otra organizacion.
-- Idempotente: DROP IF EXISTS + CREATE.
--
-- NOTA DE RIESGO (validar con Direccion): WITH CHECK sobre org_id bloquea el
-- cambio de org_id propio, pero RLS no puede comparar contra el valor previo
-- de la fila (recursion), por lo que tecnicamente no impide auto-asignarse
-- otro `rol` DENTRO de la misma org. El frontend nunca envia `rol` en
-- auto-ediciones; si se requiere blindarlo en BD, hace falta un trigger.
-- ─────────────────────────────────────────────────────────────────────────────

DO $$
BEGIN
  RAISE NOTICE '[LINK] ADR-036 BLOQUE 2: recreando "org_perfiles_update" con WITH CHECK (org_id = get_org_id())';

  DROP POLICY IF EXISTS "org_perfiles_update" ON public.perfiles;

  CREATE POLICY "org_perfiles_update"
    ON public.perfiles
    FOR UPDATE
    TO authenticated
    USING (id = auth.uid())
    WITH CHECK (id = auth.uid() AND org_id = get_org_id());

  RAISE NOTICE '[INFO] ADR-036 BLOQUE 2: "org_perfiles_update" recreada con WITH CHECK de org_id.';
END $$;


-- ─────────────────────────────────────────────────────────────────────────────
-- BLOQUE 3 · REEMPLAZO de public_organizaciones_select (organizaciones)
--
-- De USING (true) a una version acotada: solo se expone una organizacion
-- cuando es duena de al menos un evento publico. Preserva la lectura publica
-- de la landing (evento.html / registroaforo.html leen eventos con join a
-- organizaciones usando la clave anonima) y deja de exponer el listado
-- completo de organizaciones/planes/branding.
--
-- DEFENSIVO (data-first): adr033 define eventos.modo_publico como TEXT con
-- valores 'landing' | 'formulario' | 'landing_formulario' (NULL = legacy
-- 'landing'), y admin.html persiste esos strings. El mandato original usaba
-- `e.modo_publico = true` (predicado booleano): aqui se detecta el tipo REAL
-- de la columna en information_schema y se genera el predicado equivalente.
--   - boolean            -> e.modo_publico = true
--   - text/varchar       -> IS NULL OR IN ('landing','landing_formulario','formulario')
--   - columna inexistente-> EXISTS sin filtro (DB pre-ADR-033, todo evento era publico)
-- Idempotente: DROP IF EXISTS + CREATE.
-- ─────────────────────────────────────────────────────────────────────────────

DO $$
DECLARE
  v_col_type text;
  v_pred     text;
BEGIN
  RAISE NOTICE '[DEBUG] ADR-036 BLOQUE 3: detectando tipo real de eventos.modo_publico';

  SELECT data_type INTO v_col_type
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'eventos'
    AND column_name = 'modo_publico';

  IF v_col_type = 'boolean' THEN
    v_pred := $pred$EXISTS (SELECT 1 FROM public.eventos e
                             WHERE e.org_id = public.organizaciones.id
                               AND e.modo_publico = true)$pred$;
    RAISE NOTICE '[INFO] ADR-036 BLOQUE 3: eventos.modo_publico es BOOLEAN -> predicado "modo_publico = true".';
  ELSIF v_col_type IS NOT NULL THEN
    -- text / character varying / etc. (schema real segun adr033 + admin.html).
    -- Un evento es "publico" si tiene modo de pagina publica: legacy NULL
    -- (=landing), 'landing', 'landing_formulario' o 'formulario'.
    v_pred := $pred$EXISTS (SELECT 1 FROM public.eventos e
                             WHERE e.org_id = public.organizaciones.id
                               AND (e.modo_publico IS NULL
                                    OR e.modo_publico IN ('landing','landing_formulario','formulario')))$pred$;
    RAISE NOTICE '[INFO] ADR-036 BLOQUE 3: eventos.modo_publico es % -> predicado por modos de pagina publica (NULL/landing/landing_formulario/formulario).', v_col_type;
  ELSE
    -- Columna ausente (instancia pre-ADR-033): no hay forma de distinguir
    -- eventos publicos; todos los eventos legacy tienen landing publica.
    v_pred := $pred$EXISTS (SELECT 1 FROM public.eventos e
                             WHERE e.org_id = public.organizaciones.id)$pred$;
    RAISE NOTICE '[WARNING] ADR-036 BLOQUE 3: no existe eventos.modo_publico -> predicado minimo "EXISTS (evento de la org)". Si adr033 ya corrio, revisar nombre/columna.';
  END IF;

  DROP POLICY IF EXISTS "public_organizaciones_select" ON public.organizaciones;

  EXECUTE format(
    'CREATE POLICY "public_organizaciones_select"
       ON public.organizaciones
       FOR SELECT
       TO anon, authenticated
       USING (%s)',
    v_pred
  );

  RAISE NOTICE '[INFO] ADR-036 BLOQUE 3: "public_organizaciones_select" recreada acotada a orgs duenas de >=1 evento publico.';
END $$;


-- ─────────────────────────────────────────────────────────────────────────────
-- BLOQUE 4 · VERIFICACION (para Direccion)
--
-- Resultado esperado tras la migracion, en eventos/clientes/perfiles/
-- organizaciones: SOLO deben quedar las politicas *_org (org_id=get_org_id()),
-- las maestras de ADR-025 (insert/delete_organizaciones, update_organizaciones),
-- la org_perfiles_update recreada (BLOQUE 2) y la public_organizaciones_select
-- acotada (BLOQUE 3). Las politicas legacy permisivas no deben aparecer.
--
-- 👉 La Direccion debe revisar este listado y confirmar que ningun flujo
--    publico legitimo (registro, landing evento, registroaforo, scanner) se
--    rompio ANTES de cerrar TSK-026.
-- ─────────────────────────────────────────────────────────────────────────────

SELECT schemaname, tablename, policyname, cmd, permissive
FROM pg_policies
WHERE tablename IN ('eventos','clientes','perfiles','organizaciones')
ORDER BY tablename, policyname;

-- Verificacion extendida (diagnostico opcional): incluye roles y expresiones
-- para confirmar que ninguna politica restante queda abierta sin org_id.
-- SELECT schemaname, tablename, policyname, cmd, permissive,
--        array_to_string(roles, ',') AS roles,
--        pg_get_expr(qual, to_regclass(schemaname||'.'||tablename))      AS using_expr,
--        pg_get_expr(with_check, to_regclass(schemaname||'.'||tablename)) AS with_check_expr
-- FROM pg_policies
-- WHERE schemaname='public'
--   AND tablename IN ('eventos','clientes','perfiles','organizaciones')
-- ORDER BY tablename, policyname;