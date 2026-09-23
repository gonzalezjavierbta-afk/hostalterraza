-- ===========================================================================
-- ADR-050: Analitica del landing AMPLIADA (page_events + 4 vistas)
-- Sistema QR Hostal Terraza - Septiembre 2026
--
-- Archivo   : migrations/adr050_landing_analytics_ampliado.sql
-- Proposito : ampliar la telemetria del landing (ADR-032) en 6 bloques:
--   1. CHECK de event_type ampliado de 6 a 8 tipos (agrega 'section_view'
--      y 'lightbox', preparacion aditiva para el kernel evento-app.html).
--   2. Indice del filtro canonico del panel:
--      idx_page_events_org_slug_created (org_id, evento_slug, created_at DESC).
--      Sin pg_trgm: solo este indice, no se agregan otros.
--   3. Vista v_landing_analytics AMPLIADA: misma finalidad que la de ADR-032
--      (que queda reemplazada) pero con org_id en el GROUP BY y 11 metricas
--      nuevas (form_ok, form_dup, form_error, section_views,
--      lightbox_events, scroll_50pct, etc.).
--   4. Vista v_landing_clicks_rank: ranking de interacciones
--      (click / lightbox / section_view) por evento y etiqueta.
--   5. Vista v_landing_serie_diaria: serie de tendencia por dia con
--      umbrales de scroll 25/50/75/95 y tiempo activo acumulado.
--   6. Vista v_landing_funnel: embudo pageview -> scroll 50% -> form.
--
-- Dependencias: requiere adr032 aplicado (tabla public.page_events y
-- su constraint page_events_event_type_check original con 6 tipos).
--
-- Seguridad (CRITICO):
--   * Las 4 vistas se crean con WITH (security_invoker = true): la politica
--     RLS de page_events (page_events_auth_read, USING true, ADR-032) se
--     evalua sobre el rol INVOcador (authenticated) y no sobre el owner.
--     Sin security_invoker la vista correria como owner y bypassaria RLS.
--   * GRANT SELECT ... TO authenticated en cada vista (rol del panel admin).
--   * La politica page_events_auth_read NO se toca (queda USING true; el
--     ajuste por org_id se difiere a otro barrido).
--
-- Idempotencia: 100%. DROP CONSTRAINT IF EXISTS + ADD, CREATE INDEX IF
-- NOT EXISTS, DROP VIEW IF EXISTS + CREATE VIEW y GRANT. Puede
-- ejecutarse 2+ veces sin error. El DROP+ADD del constraint es destructivo
-- del constraint viejo, pero es exactamente lo que se quiere (reemplazo
-- por la lista de 8 tipos).
--
-- Nota tecnica sobre CREATE OR REPLACE: la vista v_landing_analytics de
-- ADR-032 ya existe con columnas en otro orden. PostgreSQL solo permite
-- CREATE OR REPLACE si el resultado genera las mismas columnas en el mismo
-- orden (adicionalmente puede anadir columnas al final). Como aqui la lista
-- cambia de orden (org_id primero) y se reestructura, CREATE OR REPLACE
-- FALLARIA. Por eso se usa DROP VIEW IF EXISTS + CREATE VIEW, que es
-- igualmente idempotente y coherente con "reemplaza la de adr032".
--
-- Caracteristicas: 100% ASCII (cero bytes > 127), cero backticks, cero
-- comillas tipograficas, terminacion de linea normal. NO crea RPCs, NO crea
-- disparadores, NO crea tablas nuevas (solo vistas + ALTER + CREATE INDEX).
--
-- Ejecutar en: Supabase SQL Editor (patron de ejecucion manual de la
-- Direccion; NO ejecutado por este agente).
-- ===========================================================================


-- ---------------------------------------------------------------------------
-- BLOQUE 1: AMPLIAR CHECK DE event_type (6 -> 8 tipos)
--
-- Aditivo: agrega 'section_view' y 'lightbox' a los 6 tipos de ADR-032.
-- Los tipos existentes ('pageview','form_submit','click','scroll_depth',
-- 'active_visit','error') se conservan intactos; las filas ya escritas no
-- se validan retroactivamente (CHECK no es NOT VALID pero el SQL editor
-- re-ejecutable no agrega filas invalidas).
-- ---------------------------------------------------------------------------

ALTER TABLE public.page_events
    DROP CONSTRAINT IF EXISTS page_events_event_type_check;

ALTER TABLE public.page_events
    ADD CONSTRAINT page_events_event_type_check
    CHECK (event_type IN (
        'pageview',
        'form_submit',
        'click',
        'scroll_depth',
        'active_visit',
        'error',
        'section_view',
        'lightbox'
    ));


-- ---------------------------------------------------------------------------
-- BLOQUE 2: INDICE DEL FILTRO CANONICO DEL PANEL
--
-- Cubre el filtro tipico: org + slug + orden cronologico descendente.
-- Sin pg_trgm, sin indices de expresion adicionales (solo este).
-- ---------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_page_events_org_slug_created
    ON public.page_events (org_id, evento_slug, created_at DESC);


-- ---------------------------------------------------------------------------
-- BLOQUE 3: VISTA v_landing_analytics AMPLIADA
--
-- Reemplaza la vista de ADR-032 (misma finalidad, metricas ampliadas).
-- Normalizacion del scroll 50%: el kernel real (evento-app.html) emite
-- event_action = 'scroll_50pct' con event_label vacio; por tolerancia con
-- emisores legacy se acepta tambien event_action 'scroll_50' y
-- event_label '50%' / '50'.
-- unique_visitors: total de visitantes unicos (sin filtro de tipo).
-- ---------------------------------------------------------------------------

DROP VIEW IF EXISTS public.v_landing_analytics;

CREATE VIEW public.v_landing_analytics
WITH (security_invoker = true) AS
SELECT
    org_id,
    evento_slug,
    COALESCE(NULLIF(max(evento_nombre), ''), evento_slug) AS evento_nombre,
    count(*)     FILTER (WHERE event_type = 'pageview')                  AS pageviews,
    count(DISTINCT visitor_id)                                           AS unique_visitors,
    count(*)     FILTER (WHERE event_type = 'form_submit')               AS form_submits,
    count(*)     FILTER (WHERE event_type = 'form_submit'
                            AND event_action = 'comunidad_ok')           AS form_ok,
    count(*)     FILTER (WHERE event_type = 'form_submit'
                            AND event_action = 'comunidad_dup')          AS form_dup,
    count(*)     FILTER (WHERE event_type = 'form_submit'
                            AND event_action LIKE 'form_error%')         AS form_error,
    count(*)     FILTER (WHERE event_type = 'click')                     AS clicks,
    count(*)     FILTER (WHERE event_type = 'section_view')              AS section_views,
    count(*)     FILTER (WHERE event_type = 'lightbox')                  AS lightbox_events,
    avg(event_value)
                 FILTER (WHERE event_type = 'active_visit')              AS avg_seconds_active,
    count(*)     FILTER (WHERE event_type = 'scroll_depth'
                            AND (event_action IN ('scroll_50pct','scroll_50')
                                 OR event_label IN ('50%','50')))        AS scroll_50pct,
    max(created_at)                                                      AS last_event
FROM public.page_events
GROUP BY org_id, evento_slug;

GRANT SELECT ON public.v_landing_analytics TO authenticated;


-- ---------------------------------------------------------------------------
-- BLOQUE 4: VISTA v_landing_clicks_rank
--
-- Ranking de interacciones por evento: top botones (click), fotos
-- (lightbox) y secciones vistas (section_view), con visitantes unicos.
-- ---------------------------------------------------------------------------

DROP VIEW IF EXISTS public.v_landing_clicks_rank;

CREATE VIEW public.v_landing_clicks_rank
WITH (security_invoker = true) AS
SELECT
    org_id,
    evento_slug,
    event_type,
    event_action,
    event_label,
    count(*) AS veces,
    count(DISTINCT visitor_id) AS visitantes_unicos,
    max(created_at) AS ultimo_evento
FROM public.page_events
WHERE event_type IN ('click', 'lightbox', 'section_view')
GROUP BY org_id, evento_slug, event_type, event_action, event_label;

GRANT SELECT ON public.v_landing_clicks_rank TO authenticated;


-- ---------------------------------------------------------------------------
-- BLOQUE 5: VISTA v_landing_serie_diaria
--
-- Serie de tendencia por dia para graficas. Normalizacion de scroll igual
-- que en v_landing_analytics pero para los 4 umbrales del kernel
-- (25/50/75/95): el kernel emite event_action 'scroll_Npct'; se aceptan
-- ademas 'scroll_N' en action y 'N%' / 'N' en label por tolerancia.
-- sesiones_activas: session_id distintos del dia (sin filtro de tipo).
-- ---------------------------------------------------------------------------

DROP VIEW IF EXISTS public.v_landing_serie_diaria;

CREATE VIEW public.v_landing_serie_diaria
WITH (security_invoker = true) AS
SELECT
    org_id,
    evento_slug,
    date_trunc('day', created_at)::date AS dia,
    count(*)     FILTER (WHERE event_type = 'pageview')                  AS pageviews,
    count(DISTINCT visitor_id)                                           AS unique_visitors,
    count(*)     FILTER (WHERE event_type = 'click')                     AS clicks,
    count(*)     FILTER (WHERE event_type = 'section_view')              AS section_views,
    count(*)     FILTER (WHERE event_type = 'lightbox')                  AS lightbox_events,
    count(*)     FILTER (WHERE event_type = 'form_submit')               AS form_submits,
    count(*)     FILTER (WHERE event_type = 'form_submit'
                            AND event_action = 'comunidad_ok')           AS form_ok,
    count(*)     FILTER (WHERE event_type = 'form_submit'
                            AND event_action = 'comunidad_dup')          AS form_dup,
    count(*)     FILTER (WHERE event_type = 'form_submit'
                            AND event_action LIKE 'form_error%')         AS form_error,
    count(*)     FILTER (WHERE event_type = 'scroll_depth'
                            AND (event_action IN ('scroll_25pct','scroll_25')
                                 OR event_label IN ('25%','25')))        AS scroll_25pct,
    count(*)     FILTER (WHERE event_type = 'scroll_depth'
                            AND (event_action IN ('scroll_50pct','scroll_50')
                                 OR event_label IN ('50%','50')))        AS scroll_50pct,
    count(*)     FILTER (WHERE event_type = 'scroll_depth'
                            AND (event_action IN ('scroll_75pct','scroll_75')
                                 OR event_label IN ('75%','75')))        AS scroll_75pct,
    count(*)     FILTER (WHERE event_type = 'scroll_depth'
                            AND (event_action IN ('scroll_95pct','scroll_95')
                                 OR event_label IN ('95%','95')))        AS scroll_95pct,
    sum(coalesce(event_value, 0))
                 FILTER (WHERE event_type = 'active_visit')              AS sum_active_seconds,
    count(DISTINCT session_id)                                           AS sesiones_activas
FROM public.page_events
GROUP BY org_id, evento_slug, date_trunc('day', created_at)::date;

GRANT SELECT ON public.v_landing_serie_diaria TO authenticated;


-- ---------------------------------------------------------------------------
-- BLOQUE 6: VISTA v_landing_funnel
--
-- Embudo de conversion: vistas de pagina -> unicos con pageview ->
-- scroll 50% -> envios de formulario -> ok de comunidad.
-- unicos_pageview SOLO cuenta visitantes con evento pageview (comprable
-- con los pageviews). last_event = actividad mas reciente del evento.
-- ---------------------------------------------------------------------------

DROP VIEW IF EXISTS public.v_landing_funnel;

CREATE VIEW public.v_landing_funnel
WITH (security_invoker = true) AS
SELECT
    org_id,
    evento_slug,
    count(*)     FILTER (WHERE event_type = 'pageview')                  AS pageviews,
    count(DISTINCT visitor_id)
                 FILTER (WHERE event_type = 'pageview')                  AS unicos_pageview,
    count(*)     FILTER (WHERE event_type = 'scroll_depth'
                            AND (event_action IN ('scroll_50pct','scroll_50')
                                 OR event_label IN ('50%','50')))        AS scroll_50pct,
    count(*)     FILTER (WHERE event_type = 'form_submit')               AS form_submits,
    count(*)     FILTER (WHERE event_type = 'form_submit'
                            AND event_action = 'comunidad_ok')           AS form_ok,
    max(created_at)                                                      AS last_event
FROM public.page_events
GROUP BY org_id, evento_slug;

GRANT SELECT ON public.v_landing_funnel TO authenticated;


-- ===========================================================================
-- VERIFICACION PARA LA DIRECCION (opcional, ejecutar en el SQL Editor):
--
-- SELECT event_type, count(*) FROM public.page_events GROUP BY event_type;
--   -> 8 tipos permitidos por el nuevo CHECK.
--
-- SELECT * FROM public.v_landing_analytics ORDER BY last_event DESC;
-- SELECT * FROM public.v_landing_clicks_rank  ORDER BY veces DESC LIMIT 20;
-- SELECT * FROM public.v_landing_serie_diaria ORDER BY dia DESC LIMIT 30;
-- SELECT * FROM public.v_landing_funnel       ORDER BY last_event DESC;
--
-- ROLLBACK (deshace ADR-050 completo; re-aplica adr032 para restaurar la
-- vista vieja y el CHECK de 6 tipos):
--   DROP VIEW    IF EXISTS public.v_landing_funnel;
--   DROP VIEW    IF EXISTS public.v_landing_serie_diaria;
--   DROP VIEW    IF EXISTS public.v_landing_clicks_rank;
--   DROP VIEW    IF EXISTS public.v_landing_analytics;
--   DROP INDEX   IF EXISTS public.idx_page_events_org_slug_created;
--   ALTER TABLE public.page_events
--       DROP CONSTRAINT IF EXISTS page_events_event_type_check;
--   ALTER TABLE public.page_events
--       ADD CONSTRAINT page_events_event_type_check
--       CHECK (event_type IN ('pageview','form_submit','click',
--                             'scroll_depth','active_visit','error'));
--   Luego re-ejecutar adr032 para recrear la vista v_landing_analytics
--   original (sin security_invoker) y sus grants.
-- ===========================================================================