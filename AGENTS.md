# AGENTS.md — Sistema QR Hostal Terraza

Índice operativo delgado de enrutamiento; el detalle vive en `.opencode/agent/*.md` y `.opencode/skills/` y se carga **bajo demanda**. Normativa: `Sistema QR desarrollo/BLUEPRINT.md`, `Reglas de Oro QR.md` (v128-MASTER), `PROJECT.md` (v1.6.4-FIX). Actualizado 2026-09-28 (poda ADR-059; `default_agent: free-build`, ADR-052).

## 1. Matriz de enrutamiento (esquema TRIPARTITO)

Tres rutas: GRATUITA (default, `*-free`, costo 0), HYBRID (PRO/FREE) y de PAGO (`opencode-go/*`). **La tabla ES el flujo de delegación**: cada build delega al dominio de su fila (ADR-006).

| Dominio | pro | free |
|---|---|---|
| CSS de silo | `@frontend-tpl` | `@frontend-tpl-free` |
| `admin.html` / `scanner.html` | `@admin-dev` | `@admin-dev-free` |
| endpoints / QR / tickets | `@backend-dev` | `@backend-dev-free` |
| RLS / esquema | `@sql-security` | `@sql-security-free` |
| JS/TS rutinario y soporte mecánico | `@js-silo-dev` | `@js-silo-dev-free` |
| seed + loader + smoke | `@content-loader` | `@content-loader-free` |
| migraciones / seeds | `@data-migration` | `@data-migration-free` |
| motor de render | `@renderer-dev` | `@renderer-dev-free` |
| SEO | `@seo-dev` | `@seo-dev-free` |
| arquitectura / ADR | `@architect` + `@architect-review` | `@architect-free` + `@architect-review-free` |
| multimedia | `@media-reader` | `@media-reader-free` |
| investigación de destinos | `@research-agent` | `@research-agent-free` |
| exploración masiva | `@explore` | `@explore-free` |
| cierre documental | `@docs-keeper` | `@docs-keeper-free` |
| certificación / auditoría | `@qa-auditor` | `@qa-auditor-free` |

**Primarios** (`mode: primary`, único punto de entrada): `@plan`/`@build`, `@free-plan`/`@free-build` (default), `@hybrid-plan`/`@hybrid-build`. No implementan: orquestan y delegan. Prohibido mezclar rutas salvo escalar seguridad crítica (`sql-security-free` → `@sql-security`).

`exp-pickle-free` fue **retirado** (ADR-031 Addendum A / ADR-059); su cobertura mecánica la hereda `@js-silo-dev-free`. El conteo de agentes se deriva de `ls .opencode/agent/` (ADR-006); detalle por agente (dominio, permisos, modelo, v112, discrepancia, fuentes) → skill **`agentes-roster`**.

## 2. Regla de desambiguación PRO/FREE

Ante un par de agentes gemelos (`nombre` y `nombre-free`): la variante **sin sufijo** es la **ruta PRO** (criterio, riesgo de runtime, seguridad, arquitectura) y la variante `-free` es la **ruta gratuita** para trabajo mecánico, repetitivo y de bajo riesgo. **La elección se hace por riesgo, nunca por preferencia.** Esta regla es la fuente de verdad del ruteo PRO/FREE; ninguna `description:` de agente la reitera.

## 3. Reglas transversales (aplican a todos los agentes)

1. **Cero Borrado (Oro #2):** nunca eliminar IDs del Contrato de Datos v112, aunque el módulo esté oculto (`display: none`).
2. **Vanilla JS puro (ADR-001):** prohibido Node.js en runtime cliente, React o build tools.
3. **Aislamiento Atómico (Oro #9):** CSS de silo encapsulado bajo `.tpl-{template_id}`; nada suelto en `:root` global.
4. **Silent Fallback (ADR-008):** todo `<img>` dinámico lleva `onerror="this.src='path/to/fallback.png';"`.
5. **Data-First (Oro #1):** Fase I (datos/IDs/Supabase, TRACE positivo) certificada antes de Fase II (estética).
6. **Escudo GOLD:** antes de desplegar `api/*.js`, `admin.html`, `index.html` o el motor de render → skill `gold-shield`.
7. **Mandato documental (Oro #12):** toda actualización de `TASKS.md`/`NEXT.md`/`DECISIONS.md` se entrega completa e íntegra, sin perder historial.
8. **Eficiencia de recursos (Oro #17-18):** costo = turnos × contexto; 1 agente de exploración + 1 de implementación por dominio + 1 verificación (**por script, no por agente**); cerrar con `node scripts/usage_report.js` → skill `eficiencia-recursos`.
9. **Lectura por rango:** prohibido leer completos archivos > 200 KB (p. ej. `admin.html` ~628 KB, `DECISIONS.md` ~375 KB). Usar `grep` para localizar la línea y `Read` con `offset`/`limit`: un read completo envenena el `cache_read` de todos los turnos siguientes.
10. **Express (xpress):** ante "express", "xpress" o "rápido" rige la skill `express-mode` (transversal): cambia el orden y la profundidad de los controles, no los elimina; escala a modo normal en arquitectura, RLS/seguridad, migraciones o > 3 archivos críticos.

## 4. Índice de skills (bajo demanda)

`agentes-roster` (detalle de agente y v112) · `modelos-verificados` (modelo, `403`, crear agente) · `eficiencia-recursos` (costo/turnos, grep, CSS inline, `usage_report.js`) · `anti-absorcion` (sesión con subagentes, ADR-031) · `reglas-de-oro` (entrega formal o auditoría, Mandatos 1-18) · `express-mode` (express/xpress/rápido) · `templates` (silo CSS de `evento.html`; hub `AMPLIACION/TEMPLATES.md`) · `gold-shield` (verificación mecánica pre-despliegue) · `create-dynamic-page` · `batch-create` · `gemini-research` · `ingest-eventos` · `research-destination` (pipelines de páginas, eventos y destinos).
