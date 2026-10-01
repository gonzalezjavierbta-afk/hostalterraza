# AGENTS.md — Sistema QR Hostal Terraza

Índice de enrutamiento (detalle en `.opencode/agent/` y `.opencode/skills/`). Normativa: `Sistema QR desarrollo/BLUEPRINT.md`, `Reglas de Oro QR.md` (v129-MASTER), `PROJECT.md` (v1.6.4-FIX). Actualizado 2026-10-01 (Mandatos 19-20; poda ADR-059; `default_agent: free-build`, ADR-052).

## 1. Matriz de enrutamiento

Tres rutas: GRATUITA (default, `*-free`, costo 0), HYBRID (PRO/FREE) y PAGO (`opencode-go/*`). **La tabla ES el flujo de delegación**: cada build delega al dominio de su fila.

| Dominio | pro | free |
|---|---|---|
| CSS de silo | `@frontend-tpl` | `@frontend-tpl-free` |
| `admin.html` / `scanner.html` | `@admin-dev` | `@admin-dev-free` |
| endpoints / QR | `@backend-dev` | `@backend-dev-free` |
| RLS / esquema | `@sql-security` | `@sql-security-free` |
| JS/TS rutinario | `@js-silo-dev` | `@js-silo-dev-free` |
| seed + loader + smoke | `@content-loader` | `@content-loader-free` |
| migraciones | `@data-migration` | `@data-migration-free` |
| motor de render | `@renderer-dev` | `@renderer-dev-free` |
| SEO | `@seo-dev` | `@seo-dev-free` |
| arquitectura / ADR | `@architect` + `@architect-review` | `@architect-free` + `@architect-review-free` |
| multimedia | `@media-reader` | `@media-reader-free` |
| research de destinos | `@research-agent` | `@research-agent-free` |
| exploración | `@explore` | `@explore-free` |
| cierre documental | `@docs-keeper` | `@docs-keeper-free` |
| certificación | `@qa-auditor` | `@qa-auditor-free` |

**Primarios** (`mode: primary`): `@plan`/`@build`, `@free-plan`/`@free-build` (default), `@hybrid-plan`/`@hybrid-build`. No implementan: orquestan y delegan. Prohibido mezclar rutas salvo escalar seguridad crítica (`sql-security-free` → `@sql-security`).

`exp-pickle-free` fue **retirado** (ADR-031/ADR-059); su cobertura la hereda `@js-silo-dev-free`. Agentes: `ls .opencode/agent/` (ADR-006); skill **`agentes-roster`**.

## 2. Regla de desambiguación PRO/FREE

Ante gemelos (`nombre`/`nombre-free`): **sin sufijo** = **ruta PRO** (criterio, riesgo de runtime, seguridad, arquitectura); `-free` = **ruta gratuita** para trabajo mecánico y de bajo riesgo. **La elección es por riesgo, nunca por preferencia.** Fuente de verdad del ruteo; ninguna `description:` la reitera.

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
13. **Free-first con escalado automatico:** el trabajo mecanico o de bajo riesgo intenta SIEMPRE primero la ruta FREE; si falla o no pasa la verificacion, escala AUTOMATICAMENTE a PRO del dominio, sin pedir permiso. Los dominios de riesgo de runtime o seguridad (backend, renderer, admin, sql-security, arquitectura) van directo a PRO. Prohibido pro+free en paralelo.
14. **Watchdog y cierre medido:** un subagente con >25 turnos o >50.000 tokens/turno se aborta y re-planifica. Toda sesion de implementacion CIERRA con balance de gasto (turnos, cache_read/turno, por agente), estimado vs real, 1-3 aprendizajes y mejoras, con `scripts/usage_report.js` y `scripts/session_close.js`.

## 4. Índice de skills

`agentes-roster`·`modelos-verificados`·`eficiencia-recursos`·`anti-absorcion`·`reglas-de-oro`·`express-mode`·`templates`·`gold-shield`·`create-dynamic-page`·`batch-create`·`gemini-research`·`ingest-eventos`·`research-destination`.
