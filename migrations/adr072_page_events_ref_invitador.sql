-- ===========================================================================
-- ADR-072: Atribucion del trafico del landing al INVITADOR (page_events
--           .ref_codigo + vista v_landing_invitadores)
-- Sistema QR Hostal Terraza - Octubre 2026
--
-- Archivo   : migrations/adr072_page_events_ref_invitador.sql
-- Proposito : atribuir el trafico del landing a la persona que lo trajo (el
--              INVITADOR que genera el link con ?ref=CODE), y no al sitio web
--              del que vino el visitante. Tres objetos, en este orden:
--   1. Columna nueva public.page_events.ref_codigo text NOT NULL DEFAULT ''
--      (simetrica con la columna inscritos.ref_codigo ya en uso por el panel).
--   2. Indice PARCIAL del filtro canonico de la vista:
--      idx_page_events_org_ref_created
--        ON public.page_events (org_id, ref_codigo, created_at DESC)
--        WHERE ref_codigo <> ''
--   3. Vista nueva public.v_landing_invitadores, creada con
--      WITH (security_invoker = true) y GRANT SELECT TO authenticated.
--
-- Dependencias: requiere adr032 aplicada (tabla public.page_events y sus 2
-- politicas) y adr050 aplicada (patron de cabecera, de vista security_invoker
-- y de bloque de verificacion que se replica aqui). La tabla inscritos solo se
-- cita como simetria de nombre y tipo: NO se consulta ni se une.
--
-- page_ref vs ref_codigo (page_ref NO se toca, NO se renombra, Cero Borrado):
--   page_ref    = HTTP Referer, el dominio del que venia el visitante. Es
--                 ruido de red (WhatsApp, Facebook, buscadores, enlaces
--                 directos) y NO identifica a ninguna persona de la org.
--   ref_codigo  = codigo del INVITADOR (invitadores.codigo) que el cliente
--                 resolvio del parametro ?ref=CODE al abrir el landing. Es la
--                 MISMA atribucion que ya persiste en inscritos.ref_codigo.
--                 Sin esta columna no hay forma de atribuir el trafico: la
--                 telemetria del landing solo sabe que alguien abrio la URL.
--
-- Seguridad (CRITICO):
--   * La vista se crea WITH (security_invoker = true): la politica RLS de
--     page_events (page_events_auth_read) se evalua sobre el rol INVOCADOR
--     (authenticated) y no sobre el owner. Sin security_invoker la vista
--     correria como owner y BYPASSARIA RLS.
--   * GRANT SELECT ON public.v_landing_invitadores TO authenticated (rol del
--     panel admin, patron identico a las 4 vistas de adr050).
--   * NO se hace JOIN a inscritos: es decision de arquitectura. Evita acoplar
--     la telemetria a una segunda superficie de RLS (doble evaluacion de
--     politicas dentro de una vista security_invoker) y deja la vista pura
--     sobre una sola tabla. Si el panel necesita el nombre del invitador, lo
--     resuelve en el cliente contra invitadores por codigo.
--   * NO se tocan las politicas. page_events_auth_read (SELECT authenticated,
--     USING true) y page_events_anon_insert (INSERT anon, WITH CHECK true)
--     quedan EXACTAMENTE como estan: EXACTAMENTE 2, ni una mas ni una menos.
--     La deuda de tenancy (ajustar page_events_auth_read por org_id, patron
--     get_org_id() + org master, ADR-025/036) sigue ABIERTA y se resuelve en
--     el barrido TSK-026, NO aqui. Impacto conhecido: cuando esa politica se
--     restrinja por org_id, v_landing_invitadores lo heredara solo por
--     security_invoker (no habra que recrearla).
--   * NO se crean RPC, NI disparadores (triggers), NI politicas nuevas, NI
--     tablas nuevas. NO se toca ninguna de las 4 vistas de adr050.
--
-- Idempotencia: 100%. ADD COLUMN IF NOT EXISTS, CREATE INDEX IF NOT EXISTS,
-- DROP VIEW IF EXISTS + CREATE VIEW y GRANT. Puede ejecutarse 2+ veces seguidas
-- sin error y sin efecto adicional. DROP VIEW + CREATE VIEW (y no CREATE OR
-- REPLACE) por el mismo motivo que en adr050: la vista es nueva, pero asi el
-- archivo sigue siendo re-ejecutable aunque cambie la definicion.
--
-- Nota tecnica: por que ADD COLUMN ... NOT NULL DEFAULT '' es barato:
--   En PostgreSQL 17, un ADD COLUMN con valor por omision NO volatile (una
--   cadena vacia lo es) es una operacion METADATA-ONLY: PostgreSQL registra el
--   default en pg_attribute.attmissingval y NO reescribe la tabla fisica, no
--   recorre las filas existentes, no dispara disparadores por fila y no copia
--   page_events. Costo O(1) con independencia del volumen, y el lock es breve
--   (ACCESS EXCLUSIVE solo mientras se actualiza el catalogo).
--   CONSECUENCIA IRREVERSIBLE (aceptada por decision): las filas ya escritas
--   quedan en ref_codigo = ''. El trafico historico por invitador NO es
--   recuperable: no se puede deducir de page_ref ni de la sesion del visitante,
--   y reescribir esas filas seria inventar dato (prohibido). Por eso la vista
--   excluye las filas vacias (WHERE ref_codigo <> '') y el indice es PARCIAL
--   sobre ese mismo predicado: arrancara con datos solo a partir del despliegue
--   del front que persista ref_codigo en el INSERT de page_events.
--
-- Caracteristicas: 100% ASCII (cero bytes > 127), cero tildes, cero emojis,
-- cero backticks, terminacion de linea normal. Solo ALTER TABLE ADD COLUMN,
-- CREATE INDEX y CREATE VIEW + GRANT.
--
-- Ejecutar en: Supabase SQL Editor (patron de ejecucion manual de la
-- Direccion; NO ejecutado por este agente, NO aplicado a produccion).
-- ===========================================================================


-- ---------------------------------------------------------------------------
-- BLOQUE 1: COLUMNA ref_codigo EN page_events
--
-- Simetrica con inscritos.ref_codigo (mismo nombre, mismo tipo, mismo
-- default). text con DEFAULT '' y NO NULL: la columna nunca admite NULL, asi
-- que los emisores que no mandatan ref_codigo siguen funcionando y la vista
-- puede filtrar con <> '' sin coalesce.
-- Orden de columnas: se agrega al FINAL (no hay ninguna instruccion AFTER),
-- de modo que ningun lector con select * por posicion se altera. Pasamos de
-- 15 a 16 columnas.
-- ---------------------------------------------------------------------------

ALTER TABLE public.page_events
    ADD COLUMN IF NOT EXISTS ref_codigo text NOT NULL DEFAULT '';


-- ---------------------------------------------------------------------------
-- BLOQUE 2: INDICE PARCIAL DEL FILTRO CANONICO DE LA VISTA
--
-- Cubre la consulta real del panel: org + ref_codigo, orden cronologico
-- descendente, solo filas atribuidas (WHERE ref_codigo <> ''). Es PARCIAL a
-- proposito: las filas sin atribucion (todo el historico previo) quedan fuera
-- del indice y no engordan el btree.
-- NO se indexa page_ref: es ruido de red, no se consulta por codigo de
-- invitador.
-- ---------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_page_events_org_ref_created
    ON public.page_events (org_id, ref_codigo, created_at DESC)
    WHERE ref_codigo <> '';


-- ---------------------------------------------------------------------------
-- BLOQUE 3: VISTA v_landing_invitadores
--
-- Trafico atribuido por invitador. Grano: (org_id, evento_slug, ref_codigo).
--   pageviews         = eventos de tipo pageview
--   visitantes_unicos = visitor_id distintos entre los pageview
--   eventos           = total de eventos del grupo (cualquier event_type)
--   primera_visita    = min(created_at)
--   ultima_visita     = max(created_at)
-- Se filtran las filas sin atribucion (ref_codigo <> ''): una fila vacia no
-- es un invitador y ensuciaria el ranking con una entrada falsa.
-- Columnas EXACTAS y en este orden (contrato del panel, no reordenar):
-- org_id, evento_slug, ref_codigo, pageviews, visitantes_unicos, eventos,
-- primera_visita, ultima_visita.
-- ---------------------------------------------------------------------------

DROP VIEW IF EXISTS public.v_landing_invitadores;

CREATE VIEW public.v_landing_invitadores
WITH (security_invoker = true) AS
SELECT
    org_id,
    evento_slug,
    ref_codigo,
    count(*)     FILTER (WHERE event_type = 'pageview')       AS pageviews,
    count(DISTINCT visitor_id)
                 FILTER (WHERE event_type = 'pageview')       AS visitantes_unicos,
    count(*)                                                  AS eventos,
    min(created_at)                                           AS primera_visita,
    max(created_at)                                           AS ultima_visita
FROM public.page_events
WHERE ref_codigo <> ''
GROUP BY org_id, evento_slug, ref_codigo;

GRANT SELECT ON public.v_landing_invitadores TO authenticated;


-- ===========================================================================
-- VERIFICACION PARA LA DIRECCION (ejecutar en el SQL Editor DESPUES de correr
-- este archivo). Todo lo de abajo esta comentado: el archivo no ejecuta nada
-- de esta seccion.
--
-- (1) COLUMNA NUEVA (information_schema.columns)
--     -> debe devolver 1 fila: ref_codigo | text | NO | ''::text
--
-- SELECT column_name, data_type, is_nullable, column_default
-- FROM information_schema.columns
-- WHERE table_schema = 'public'
--   AND table_name   = 'page_events'
--   AND column_name  = 'ref_codigo';
--
-- (1b) RECUENTO DE COLUMNAS: debe devolver 16 (15 de adr032 mas la nueva).
--
-- SELECT count(*) AS columnas_page_events
-- FROM information_schema.columns
-- WHERE table_schema = 'public' AND table_name = 'page_events';
--
-- (2) INDICE PARCIAL (pg_indexes): columna y predicado deben aparecer en
--     indexdef. Debe existir idx_page_events_org_ref_created y su indexdef
--     debe contener las 3 columnas y el WHERE ref_codigo <> ''
--
-- SELECT indexname, indexdef
-- FROM pg_indexes
-- WHERE schemaname = 'public'
--   AND tablename  = 'page_events'
--   AND indexname  = 'idx_page_events_org_ref_created';
--
-- (3) security_invoker DE LA VISTA (pg_class.reloptions)
--     -> debe devolver {security_invoker=true}
--
-- SELECT c.relname, c.reloptions
-- FROM pg_class c
-- JOIN pg_namespace n ON n.oid = c.relnamespace
-- WHERE n.nspname = 'public'
--   AND c.relname = 'v_landing_invitadores';
--
-- (3b) COLUMNAS DE LA VISTA, en orden (information_schema.columns): deben ser
--      8 y en este orden exacto:
--      org_id, evento_slug, ref_codigo, pageviews, visitantes_unicos,
--      eventos, primera_visita, ultima_visita
--
-- SELECT ordinal_position, column_name, data_type
-- FROM information_schema.columns
-- WHERE table_schema = 'public'
--   AND table_name   = 'v_landing_invitadores'
-- ORDER BY ordinal_position;
--
-- (3c) PRIVILEGIO (information_schema.role_table_grants): debe existir
--      SELECT para el rol authenticated.
--
-- SELECT grantee, privilege_type
-- FROM information_schema.role_table_grants
-- WHERE table_schema = 'public'
--   AND table_name   = 'v_landing_invitadores'
--   AND grantee      = 'authenticated';
--
-- (4) POLITICAS: page_events debe seguir con EXACTAMENTE 2 (esta migracion no
--     creo ninguna). El count DEBE devolver 2.
--
-- SELECT policyname, cmd, roles, qual, with_check
-- FROM pg_policies
-- WHERE schemaname = 'public' AND tablename = 'page_events';
--
-- SELECT count(*) AS politicas_page_events
-- FROM pg_policies
-- WHERE schemaname = 'public' AND tablename = 'page_events';   -- -> 2
--
-- (5) FILAS SIN ATRIBUCION (deben seguir existiendo y quedar fuera de la
--     vista: es el historico irrecuperable, no un error de la migracion).
--
-- SELECT count(*) AS filas_historicas_sin_ref
-- FROM public.page_events
-- WHERE ref_codigo = '';
--
-- (6) LECTURA DE EJEMPLO (la que consumira el admin, con la sesion
--     autenticada): ranking de invitadores por trafico.
--
-- SELECT * FROM public.v_landing_invitadores ORDER BY pageviews DESC;
--
-- (6b) LECTURA FILTRADA POR ORG Y EVENTO (como la hara admin.html):
--
-- SELECT * FROM public.v_landing_invitadores
-- WHERE org_id = '<ORG_ID>' AND evento_slug = '<SLUG>'
-- ORDER BY pageviews DESC;
--
-- ===========================================================================
-- ROLLBACK (deshace ADR-072 por completo; comentarlo y ejecutarlo SOLO si
-- se decide revertir antes de que exista trafico attributed util):
--   DROP VIEW    IF EXISTS public.v_landing_invitadores;
--   DROP INDEX   IF EXISTS public.idx_page_events_org_ref_created;
--   ALTER TABLE  public.page_events DROP COLUMN IF EXISTS ref_codigo;
-- Nota: el DROP COLUMN borra el dato de ref_codigo de las filas (Cero Borrado
-- aplica al historial de IDs, no a una columna experimental) y ademas reescribe
-- la tabla fisicamente (a diferencia del ADD, que fue metadata-only). Ademas,
-- al ser anon el unico INSERT permitted sobre page_events, las filas nuevas
-- que se escriban con ref_codigo NULL o ausente dejarian de insertar tras el
-- DROP COLUMN solo si se hubiera cambiado el NOT NULL; con esta migracion el
-- default sigue siendo '' y no hay tal dependencia.
-- ===========================================================================