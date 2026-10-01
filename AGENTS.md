# AGENTS.md — Sistema QR Hostal Terraza

Índice de enrutamiento (detalle en `.opencode/agent/` y `.opencode/skills/`). Normativa: `Sistema QR desarrollo/BLUEPRINT.md`, `Reglas de Oro QR.md` (v129-MASTER), `PROJECT.md` (v1.6.4-FIX). Actualizado 2026-10-01 (consolidación a roster único de 20 agentes; §0 selección de tier obligatoria; retiro de ruta híbrida, ADR-067).

## 0. Selección de tier obligatoria (primera regla de comportamiento)

Antes de cualquier exploración, edición o delegación, el orquestador DEBE preguntar al usuario, con la herramienta `question` y **UNA VEZ POR TAREA**, qué tier usar:

- **FREE** — `opencode/big-pickle` (costo `$0`). Ruta para trabajo mecánico, exploración, edición de bajo riesgo.
- **PAGO** — `opencode-go/deepseek-v4.1-flash` (o `opencode-go/qwen3.8-flash` en `@seo-dev`). Ruta para criterio, riesgo de runtime, seguridad y arquitectura.

La respuesta del usuario **fija la ruta de la sesión** y no se vuelve a preguntar durante esa tarea. **Sin respuesta no se ejecuta nada**: no hay default silencioso. Prohibido arrancar exploración, edición o `task` antes de resolver el tier.

## 1. Matriz de enrutamiento

Roster único de 20 agentes: 4 primarios (orquestación) + 16 subagentes especialistas, cada dominio con UN ÚNICO agente. **La tabla ES el flujo de delegación**: cada primario delega al único agente del dominio de su fila.

| Dominio | Agente Especialista Único |
|---|---|
| CSS de silo / templates | `@frontend-tpl` |
| `admin.html` / `scanner.html` | `@admin-dev` |
| endpoints / QR | `@backend-dev` |
| RLS / esquema | `@sql-security` |
| JS/TS rutinario | `@js-silo-dev` |
| seed + loader + smoke | `@content-loader` |
| migraciones | `@data-migration` |
| motor de render | `@renderer-dev` |
| SEO | `@seo-dev` |
| arquitectura / ADR | `@architect` |
| revisión de arquitectura / ADR | `@architect-review` |
| multimedia | `@media-reader` |
| research de destinos | `@research-agent` |
| exploración | `@explore` |
| cierre documental | `@docs-keeper` |
| certificación | `@qa-auditor` |

**Primarios** (`mode: primary`): `@plan`/`@build` (ruta PAGO) y `@free-plan`/`@free-build` (ruta FREE, default). No implementan: orquestan y delegan. **No existe ruta híbrida**: fue retirada en la consolidación (ADR-067).

Agentes: `ls .opencode/agent/` (ADR-006).

## 2. Regla de cambio de tier por riesgo y confirmación del usuario

- **free-first recomendado para trabajo mecánico; el tier se fija en §0:** la ruta FREE (`@free-plan`/`@free-build`, `opencode/big-pickle`) es la recomendada para trabajo mecánico, repetitivo o de exploración/lectura. `default_agent: build` en `opencode.json` es solo el punto de entrada del proceso, NO fija el tier: la compuerta §0 resuelve FREE/PAGO una vez por tarea con la herramienta `question`.
- **FREE opera aislado:** en ruta FREE el primario gratuito trabaja en su propio contexto y **NO invoca subagentes PAGO**; su cobertura de exploración es `@explore` y no delega dominios de implementación a especialistas de pago.
- **Gate de confirmación por riesgo (ruta PAGO):** los dominios de riesgo exigen **CONFIRMACIÓN EXPLÍCITA del usuario antes de ejecutar**, incluso si el tier elegido es PAGO:
  - RLS / esquema SQL y migraciones (`@sql-security`, `@data-migration`).
  - Motor de producción `evento-app.html` / `@renderer-dev`.
  - Decisiones de arquitectura / ADR (`@architect`, `@architect-review`).
- El cambio de tier solo ocurre por decisión del usuario o por confirmación explícita; nunca automáticamente ni por preferencia. Prohibido mezclar rutas o desdoblar PAGO+FREE en paralelo.

## 3. Reglas transversales

1. **Cero Borrado (Oro #2):** nunca eliminar IDs del Contrato v112, aunque el módulo esté oculto (`display: none`).
2. **Vanilla JS puro (ADR-001):** prohibido Node.js en runtime cliente, React o build tools.
3. **Aislamiento Atómico (Oro #9):** CSS de silo encapsulado bajo `.tpl-{template_id}`; nada suelto en `:root`.
4. **Silent Fallback (ADR-008):** todo `<img>` dinámico lleva `onerror="this.src='path/to/fallback.png';"`.
5. **Data-First (Oro #1):** Fase I (datos/IDs/Supabase, TRACE positivo) antes de Fase II (estética).
6. **Escudo GOLD:** antes de desplegar `api/*.js`, `admin.html`, `index.html` o el motor de render → skill `gold-shield`.
7. **Mandato documental (Oro #12):** toda actualización de `TASKS.md`/`NEXT.md`/`DECISIONS.md` se entrega completa, sin perder historial.
8. **Eficiencia (Oro #17-18):** costo = turnos × contexto; 1 exploración + 1 implementación por dominio + 1 verificación por script; cerrar con `node scripts/usage_report.js` → skill `eficiencia-recursos`.
9. **Lectura por rango:** prohibido leer completos archivos > 200 KB (`admin.html`, `DECISIONS.md`). Usar `grep` y `Read` con `offset`/`limit`: un read completo envenena el `cache_read` siguiente.
10. **Express (xpress):** "express", "xpress" o "rápido" → skill `express-mode`: cambia orden y profundidad de los controles, no los elimina; escala a normal en arquitectura, RLS/seguridad, migraciones o > 3 archivos críticos.
11. **Presupuesto (Oro #19-20):** antes de ejecutar, estima tokens y tiempo; al cierre concilia estimado vs real con `usage_report.js`; si la tarea es pesada (imágenes/video, research o > ~1.5M tokens), avisa el costo y recomienda IA externa (ficha/JSON + prompt).
12. **Contrato de retorno (skill `eficiencia-recursos`):** todo `task` exige retorno compacto (max ~600: STATUS, ARCHIVOS con rangos, VERIFICACION N/N, BLOQUEADORES, SIGUIENTE); prohibido volcar archivos o narrar lo leido. Orquestador: 25-30 turnos por sesion; si supera 20-25 llamadas directas, delega a `@explore`.
13. **Tier por riesgo, nunca por preferencia:** el tier se resuelve una vez por tarea (§0); la ruta FREE es la recomendada para trabajo mecánico o de bajo riesgo. El escalado a la ruta PAGO NO es automático: exige confirmación explícita del usuario. En ruta PAGO, los dominios de riesgo de runtime o seguridad (backend, renderer, admin, sql-security, data-migration, arquitectura) requieren además el gate de confirmación por riesgo (§2). Prohibido mezclar rutas o desdoblar PAGO+FREE en paralelo.
14. **Watchdog y cierre medido:** un subagente con >25 turnos o >50.000 tokens/turno se aborta y re-planifica. Toda sesion de implementacion CIERRA con balance de gasto (turnos, cache_read/turno, por agente), estimado vs real, 1-3 aprendizajes y mejoras, con `scripts/usage_report.js` y `scripts/session_close.js`.

## 4. Índice de skills

Skills REALES en `.opencode/skills` (9): `anti-absorcion`·`create-dynamic-page`·`eficiencia-recursos`·`express-mode`·`frontend-design`·`gold-shield`·`research-destination`·`templates`·`web-design-guidelines`.

**Pendientes de creación (NO existen todavía, no invocar):** `agentes-roster`·`modelos-verificados`·`gemini-research`·`ingest-eventos`·`batch-create`·`reglas-de-oro`. Declararlas como existentes es un error; hasta su creación, seguir la normativa directamente en `Reglas de Oro QR.md` y `BLUEPRINT.md`.
