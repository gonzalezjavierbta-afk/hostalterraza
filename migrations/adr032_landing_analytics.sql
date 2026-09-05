-- ═══════════════════════════════════════════════════════════════════════
-- ADR-032 — Analítica del landing (tabla page_events)
-- Sistema QR Hostal Terraza
--
-- Contexto: el landing (evento.html) necesita mediciones accionables:
--   · Vistas del landing (pageview) con visitante/sesión únicos.
--   · Ingresos al formulario de comunidad (form_submit).
--   · Clics en botones y enlaces (click): WhatsApp, hero CTA, boletería
--     (individual/pareja), redes de artistas, FAQ, galería, sponsors…
--   · Profundidad de scroll (scroll_depth) y tiempo activo (active_visit).
--
-- Modelo: tabla de eventos inmutable, escrita por el cliente anónimo (anon
-- SOLO INSERT, patrón webhook/analytics) e INMUNE a lectura pública: SELECT
-- únicamente para authenticated (el panel admin). Sin UPDATE/DELETE para nadie,
-- garantiza Cero Borrado de la telemetría.
--
-- Ejecutar en: Supabase SQL Editor (idempotente: puede re-ejecutarse).
-- ═══════════════════════════════════════════════════════════════════════

-- 1. Tabla de eventos (idempotente).
CREATE TABLE IF NOT EXISTS public.page_events (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id         uuid,
    evento_id      uuid,
    evento_slug    text NOT NULL DEFAULT '',
    evento_nombre  text NOT NULL DEFAULT '',
    page_url       text NOT NULL DEFAULT '',
    page_ref       text NOT NULL DEFAULT '',
    event_type     text NOT NULL,
    event_action   text NOT NULL DEFAULT '',
    event_label    text NOT NULL DEFAULT '',
    event_value    numeric,
    session_id     text NOT NULL DEFAULT '',
    visitor_id     text NOT NULL DEFAULT '',
    user_meta      jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at     timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT page_events_event_type_check
        CHECK (event_type IN (
            'pageview',
            'form_submit',
            'click',
            'scroll_depth',
            'active_visit',
            'error'
        ))
);

-- 2. Índices de consulta (idempotentes).
CREATE INDEX IF NOT EXISTS idx_page_events_slug_created
    ON public.page_events (evento_slug, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_page_events_visitor
    ON public.page_events (visitor_id);
CREATE INDEX IF NOT EXISTS idx_page_events_type
    ON public.page_events (event_type);

-- 3. RLS: escritura anónima, lectura solo autenticada (sin borrado).
ALTER TABLE public.page_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "page_events_anon_insert" ON public.page_events;
CREATE POLICY "page_events_anon_insert"
    ON public.page_events
    FOR INSERT
    TO anon
    WITH CHECK (true);

DROP POLICY IF EXISTS "page_events_auth_read" ON public.page_events;
CREATE POLICY "page_events_auth_read"
    ON public.page_events
    FOR SELECT
    TO authenticated
    USING (true);

-- 4. Privilegios explícitos (mínimo necesario).
GRANT INSERT ON public.page_events TO anon;
GRANT INSERT, SELECT ON public.page_events TO authenticated;

-- 5. Vista resumen para el panel (por evento, últimos datos).
CREATE OR REPLACE VIEW public.v_landing_analytics AS
SELECT
    evento_slug,
    COALESCE(NULLIF(evento_nombre, ''), evento_slug) AS evento_nombre,
    count(*)     FILTER (WHERE event_type = 'pageview')     AS pageviews,
    count(DISTINCT visitor_id)
                 FILTER (WHERE event_type = 'pageview')     AS unique_visitors,
    count(*)     FILTER (WHERE event_type = 'form_submit')  AS form_submits,
    count(*)     FILTER (WHERE event_type = 'click')        AS clicks,
    round(avg(event_value) FILTER (WHERE event_type = 'active_visit')) AS avg_seconds_active,
    max(created_at) AS last_event
FROM public.page_events
GROUP BY evento_slug, COALESCE(NULLIF(evento_nombre, ''), evento_slug);

GRANT SELECT ON public.v_landing_analytics TO authenticated;

-- ═══════════════════════════════════════════════════════════════════════
-- Consultas útiles de ejemplo (ejecutar en el SQL Editor):

-- Resumen por evento del último mes:
-- SELECT * FROM v_landing_analytics WHERE last_event > now() - interval '30 days';

-- Desglose de clics de un evento específico:
-- SELECT event_action, count(*) AS veces
-- FROM page_events
-- WHERE evento_slug = '<SLUG>' AND event_type = 'click'
-- GROUP BY event_action ORDER BY veces DESC;

-- Ingresos al formulario por día:
-- SELECT date_trunc('day', created_at)::date AS dia,
--        count(*) FILTER (WHERE event_action = 'comunidad_ok') AS ok,
--        count(*) FILTER (WHERE event_action = 'comunidad_dup') AS duplicados
-- FROM page_events
-- WHERE event_type = 'form_submit'
-- GROUP BY dia ORDER BY dia DESC;

-- ROLLBACK (elimina tabla, vista y políticas):
-- DROP VIEW IF EXISTS public.v_landing_analytics;
-- DROP TABLE IF EXISTS public.page_events;
-- ═══════════════════════════════════════════════════════════════════════