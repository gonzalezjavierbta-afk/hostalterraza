# WORK_PLAN_ANALYTICS.md — Plan de Optimización Analítica (v1.0)

Fecha: 12 de agosto 2026
Estado: **FASE 1 EN EJECUCIÓN**

---

## FASE 1 — Quick Wins (Semanas 1-2)
**Objetivo**: Reducir latencia de dashboards 10-50x sin cambiar lógica de negocio.

| ID | Tarea | Archivo/Área | Criterio Done | Responsable |
|----|-------|--------------|---------------|-------------|
| 1.1 | Índices compuestos `inscritos(org_id, evento_id, used, created_at)` + `qr_scans(qr_link_id, created_at)` | `migrations/001_analytics_indexes.sql` | `EXPLAIN ANALYZE` muestra Index Scan, no Seq Scan | sql-migrations |
| 1.2 | Vista materializada `analytics_daily(org_id, evento_id, fecha, inscritos, asistieron, por_tipo_json, por_hora_json, por_pais_json, por_ref_json)` + `REFRESH MATERIALIZED VIEW CONCURRENTLY` nocturno | `migrations/002_analytics_daily.sql` + `migrations/003_pg_cron_refresh.sql` | Dashboard KPIs cargan <200ms (vs 2-5s actual) | sql-migrations |
| 1.3 | Caché 5 min en `renderPanel()` (clave `panel:${ORG_ID}:${vistaVal}:${_pnPeriod}`) + invalidación por `created_at` max | `admin.html` (`renderPanel`, `sbQuery`) | Recarga inmediata al cambiar tabs/filtros; datos frescos ≤5 min | js-silo-dev |
| 1.4 | Memoización Chart.js: reusar instancias, `chart.update()` en vez de `destroy()/new` | `admin.html` (`_pnChartEv`, `_pnChartTipo`, `_pnChartSemana`, `_pnChartRetencion`, `_pnChartInsDia`) | 0 parpadeo al cambiar período/vista; CPU <5% | js-silo-dev |
| 1.5 | Agregación Global Analytics en SQL: `cargarConteosOrgs()` con `GROUP BY org_id` en 1 query | `admin.html` (`cargarConteosOrgs`) | 3 queries → 1 query; tabla orgs render <300ms | js-silo-dev |

---

## FASE 2 — Core (Semanas 3-4)
**Objetivo**: Escalar a 100k+ registros y unificar fuentes de verdad.

| ID | Tarea | Archivo/Área | Criterio Done |
|----|-------|--------------|---------------|
| 2.1 | Paginación BD real en `_renderTablaPagina()`: `LIMIT _pnPageSize OFFSET start` + `count(*)` separado | `admin.html` (`_renderTablaPagina`, `renderPanel`) | 100k rows → página carga <500ms |
| 2.2 | Vista `analytics_eventos` (pre-aggregada por evento) para ranking/eventos/gráficas | `migrations/004_analytics_eventos.sql` | Gráficas por evento instantáneas |
| 2.3 | Unificar `logs` + `inscritos.used`: trigger `inscritos` → `logs` (single source) | `migrations/005_unify_logs.sql` | 0 duplicados; `logs` = source of truth |
| 2.4 | Cohort Retention query (SQL window functions): cohorte semanal, retención 1/2/3/4+ semanas | `migrations/006_cohort_retention.sql` + endpoint | Panel "Retención" muestra cohorts reales vs buckets estáticos |
| 2.5 | Funnel multi-canal: atribución `ref_codigo` / `qr_link` / orgánico + conversión por paso | `migrations/007_funnel_attribution.sql` | Insights muestran "Canal X: 45% conversión" |

---

## FASE 3 — Avanzado (Semanas 5-8)
**Objetivo**: Valor diferencial y automatización.

| ID | Tarea | Archivo/Área | Criterio Done |
|----|-------|--------------|---------------|
| 3.1 | Geo enriquecido: batch nocturno geocodificar `ciudad` → `lat/lng` (Nominatim/Mapbox) + mapa de calor Leaflet | `supabase/functions/geocode_ciudades` + `admin.html` | Mapa interactivo en Global Analytics |
| 3.2 | ML No-show prediction (Edge Function pg_cron): features → probabilidad → alerta WhatsApp 24h | `supabase/functions/predict_noshow` + `pg_cron` | No-show reduce >20% |
| 3.3 | Anomaly detection (z-score diario inscritos/asistencia) → alerta Slack/Email | `supabase/functions/anomaly_detect` | 0 sorpresas operativas |
| 3.4 | API Analytics REST/GraphQL (Supabase Edge Functions) | `supabase/functions/analytics_api` | Embeddable en Metabase/PowerBI |
| 3.5 | Self-serve BI builder (Metabase-lite embebido) para orgs premium | `admin.html` + `supabase/functions/bi_builder` | Orgs crean dashboards sin code |

---

## RUTA DE INICIO (Esta sesión)
1. **Ejecutar 1.1 + 1.2**: Crear migraciones SQL (índices + vista `analytics_daily` + pg_cron)
2. **Ejecutar 1.3 + 1.4**: Cache + memo Chart.js en `admin.html`
3. **Ejecutar 1.5**: Agregación Global Analytics en 1 query
3. **Validar**: `node --check` + prueba carga Panel (simular 50k rows)

---

## DEPENDENCIAS Y RIESGOS
- **pg_cron** requiere extensión habilitada en Supabase (verificar `CREATE EXTENSION IF NOT EXISTS pg_cron`)
- **Vistas materializadas** requieren `REFRESH CONCURRENTLY` (PG 9.4+) — confirmar versión
- **Caché frontend** invalida con `created_at` max — si hay inserts masivos sin `created_at`, sirve stale → fallback: TTL fijo 5 min
- **Chart.js memo** requiere mantener referencias `_pnChart*` globales (ya existen)

---

## MÉTRICAS DE ÉXITO (KPIs del Plan)
| Métrica | Baseline | Target F1 | Target F2 |
|---------|----------|-----------|-----------|
| Panel KPIs load | 2-5s | <200ms | <100ms |
| Asistentes tabla (10k rows) | 8-15s | <500ms | <300ms |
| Global Analytics (50 orgs) | 3-6s | <300ms | <150ms |
| QR Stats load | 1-2s | <200ms | <100ms |
| Transferencia BD/render | ~5-20 MB | <200 KB | <100 KB |

---

## COMANDOS DE VERIFICACIÓN
```bash
# Índices
psql -c "EXPLAIN ANALYZE SELECT * FROM inscritos WHERE org_id='...' AND used=true ORDER BY created_at DESC LIMIT 50;"

# Vista daily
psql -c "SELECT * FROM analytics_daily WHERE org_id='...' ORDER BY fecha DESC LIMIT 7;"

# pg_cron
psql -c "SELECT * FROM cron.job WHERE jobname LIKE 'analytics%';"

# Frontend
# Abrir Panel → Network → filtrar "inscritos" → ver tiempo y tamaño response
```