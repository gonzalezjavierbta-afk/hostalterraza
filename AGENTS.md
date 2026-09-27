# AGENTS.md — Sistema QR Hostal Terraza (HostalTerraza)

Enrutamiento de agentes para OpenCode. Sistema QR Hostal Terraza: plataforma de eventos con contrato de datos atómico, silos CSS por template y operación delegada a agentes especializados. Este archivo es el **índice operativo delgado**; el detalle vive en `.opencode/skills/` y se carga **bajo demanda** (ver índice final). Fuentes normativas: `Sistema QR desarrollo/BLUEPRINT.md`, `Sistema QR desarrollo/Reglas de Oro QR.md` (v128-MASTER) y `Sistema QR desarrollo/PROJECT.md` (v1.6.4-FIX). Última actualización: 2026-09-24 (`default_agent: free-build`, ADR-052).

## 1. Matriz de enrutamiento compacta (esquema TRIPARTITO)

Existen **tres rutas completas**: GRATUITA (default, agentes `*-free`, costo 0), HYBRID (mezcla PRO/FREE por riesgo) y de PAGO (agentes pro `opencode-go/*`). Los agentes gratuitos se identifican con el sufijo `-free`. **Antes de procesar código, el orquestador delega al dominio** (fuente de verdad operativa: ADR-006).

| Dominio | Agente pro | Agente free |
|---|---|---|
| CSS de silo / `evento.html` | `@frontend-tpl` | `@frontend-tpl-free` |
| `admin.html` / `scanner.html` | `@admin-dev` | `@admin-dev-free` |
| endpoints / lógica QR / tickets | `@backend-dev` | `@backend-dev-free` |
| RLS / seguridad de esquema | `@sql-security` | `@sql-security-free` |
| JS/TS rutinario | `@js-silo-dev` | `@js-silo-dev-free` |
| seed+loader+smoke (páginas dinámicas) | `@content-loader` | `@content-loader-free` |
| migraciones / seeds | `@data-migration` | `@data-migration-free` |
| motor de render (`pagina-destino.js`) | `@renderer-dev` | `@renderer-dev-free` |
| SEO | `@seo-dev` | `@seo-dev-free` |
| arquitectura / ADR | `@architect` (+ `@architect-review`) | `@architect-free` (+ `@architect-review-free`) |
| multimedia | `@media-reader` | `@media-reader-free` |
| investigación de destinos | `@research-agent` | `@research-agent-free` |
| exploración masiva del repo | `@explore` | `@explore-free` |
| cierre documental | `@docs-keeper` | `@docs-keeper-free` |
| certificación / auditoría | `@qa-auditor` | `@qa-auditor-free` |
| soporte mecánico (linter/smoke) | — | `@exp-pickle-free` |

**Orquestadores primarios** (`mode: primary`, 6; único punto de entrada): `@plan`/`@build` (pago), `@free-plan`/`@free-build` (gratuito, default), `@hybrid-plan`/`@hybrid-build` (hybrid). Los primarios delegan SIEMPRE por su ruta; prohibido mezclar rutas salvo escalar seguridad crítica (`sql-security-free` -> `sql-security`). `@plan`/`@free-plan`/`@hybrid-plan` NO implementan, solo orquestan. El par pro sustituye al `*-free` cuando la tarea exige calidad máxima o el modelo free no aplica (p.ej. `@seo-dev`, `@media-reader` con visión).

Detalle de los 39 agentes (dominios, permisos, modelos, rutas hybrid/pago, regla de `model:` explícito, decisiones de reconciliación v112, discrepancia conocida de `evento.html`, ADR-040, instalación y fuentes) -> cargar skill **`agentes-roster`**.

## 2. Reglas transversales (aplican a los 39 agentes)

1. **Cero Borrado (Reglas de Oro #2):** ningún agente elimina IDs del Contrato de Datos v112, aunque el módulo esté oculto (`display: none`).
2. **Vanilla JS puro (ADR-001):** prohibido Node.js en runtime cliente, React o build tools.
3. **Aislamiento Atómico (Reglas de Oro #9):** CSS de silo encapsulado bajo `.tpl-{template_id}`; nada suelto en `:root` global.
4. **Silent Fallback (ADR-008):** todo `<img>` dinámico lleva `onerror="this.src='path/to/fallback.png';"`.
5. **Prioridad Estructural — Data-First (Reglas de Oro #1):** Fase I (datos/IDs/Supabase, log TRACE positivo) certificada antes de Fase II (estética Afterglow/Geist 900).
6. **Mandato de Actualización Documental (Reglas de Oro #12):** toda actualización de `TASKS.md`/`NEXT.md`/`DECISIONS.md` (dominio de `@plan`/`@free-plan`) se entrega completa e íntegra, sin perder historial.
7. **Modo Express (xpress):** cuando el usuario pida "express", "xpress" o "rápido", aplica la sección 4 de este archivo y la skill `express-mode`.
8. **Eficiencia de recursos (Reglas de Oro #17-18):** consolidación de fases/agentes, regla anti-colgado y métrica `cache_read / turnos`; cierra toda sesión de implementación midiendo con `node scripts/usage_report.js`. Detalle en la sección 5.

## 3. Flujo de delegación

```
usuario → @free-plan (gratuito)  ·  @plan (pago, respaldo)  ·  @hybrid-plan (hybrid)
            │
            ├─ plan aprobado
            ↓
        @free-build (@build pro como respaldo)  ·  @hybrid-build (ruteo PRO/FREE por riesgo)
            │
            ├─ CSS de silo ──────────────────────→ @frontend-tpl-free
            ├─ admin.html / scanner.html ────────→ @admin-dev-free
            ├─ endpoints / QR / tickets ─────────→ @backend-dev-free
            ├─ RLS / seguridad de esquema ───────→ @sql-security-free
            ├─ JS/TS rutinario ──────────────────→ @js-silo-dev-free
            ├─ seed+loader+smoke ────────────────→ @content-loader-free
            ├─ migraciones / seeds ──────────────→ @data-migration-free
            ├─ motor de render ──────────────────→ @renderer-dev-free
            ├─ SEO ──────────────────────────────→ @seo-dev-free
            ├─ arquitectura / ADR ───────────────→ @architect-free (+ @architect-review-free)
            ├─ multimedia ───────────────────────→ @media-reader-free
            ├─ investigación de destinos ────────→ @research-agent-free
            ├─ exploración masiva ───────────────→ @explore-free
            ├─ cierre documental ────────────────→ @docs-keeper-free
            ├─ modo express (xpress) ────────────→ skill express-mode (transversal)
            └─ certificación de una entrega ─────→ @qa-auditor (solo lectura, reporta al build de la ruta)
```

## 4. Modo Express (xpress)

Cuando el usuario pida "**express**", "**xpress**" o "**rápido**", la skill `.opencode/skills/express-mode/SKILL.md` rige toda la sesión como skill **transversal** a cualquier dominio y ruta. Cambia el **orden** y la **profundidad** de los controles, no los elimina: briefs quirúrgicos por dominio, verificación local proporcional al riesgo y documentación diferida a un único cierre. Escalado obligatorio a modo normal en arquitectura, esquema/RLS/seguridad (siempre `@sql-security`, nunca `sql-security-free`), migraciones de datos, refactors compartidos o > 3 archivos críticos. Comando de verificación mínima: `node scripts/express_check.js`. Manual ampliado: `DOCUMENTOS/MODO_EXPRESS_ANALISIS.md`.

## 5. Eficiencia de recursos (v128)

Operativiza los Mandatos 17-18. La unidad de costo real es `turnos × contexto acumulado`, no el output: la métrica de control líder es **`cache_read / turnos`**. Una sesión usa máximo 1 agente de exploración + 1 de implementación por dominio + 1 de verificación; la verificación mecánica es script (`scripts/express_check.js`, `scripts/smoke_*.js`), no agente; prohibido releer archivos > 200 KB completos; y **toda sesión de implementación cierra con el informe obligatorio** (`node scripts/usage_report.js --summary` + `--tree --root <id>`). El detalle completo (contrato congelado de `usage_report.js`, tabla del informe de cierre, disciplina de grep y el diagnóstico del CSS inline del kernel) -> cargar skill **`eficiencia-recursos`**.

## Índice de skills

| Skill | Cuándo cargarla |
|---|---|
| `agentes-roster` | Detalle de un agente (dominio, permisos, modelo), rutas hybrid/pago, decisiones de reconciliación, discrepancia v112, instalación y fuentes. |
| `modelos-verificados` | Elegir/asignar modelo, depurar un `403`, crear un agente nuevo (gatekeeper del tier gratuito). |
| `eficiencia-recursos` | Sesiones largas u optimización de consumo: costo/turnos, grep, CSS inline, informe de cierre, `usage_report.js`. |
| `anti-absorcion` | Planificar una sesión con subagentes (ADR-031) y KPIs de delegación. |
| `reglas-de-oro` | Antes de una entrega formal o una auditoría: puente y resumen de los Mandatos 1-18 de `Reglas de Oro QR.md` (v128-MASTER). |
| `express-mode` | Cuando el usuario pida express/xpress/rápido (transversal). |
| `templates` | Crear/editar/auditar un silo CSS de `evento.html` (hub en `AMPLIACION/TEMPLATES.md`). |
| `gold-shield` | Verificación de `api/*.js`, `admin.html`, `pagina-destino.js`, `index.html` antes de desplegar. |
| `create-dynamic-page` / `batch-create` / `gemini-research` / `ingest-eventos` / `research-destination` | Pipelines de páginas dinámicas, eventos y destinos. |
