# AGENTS.md — Sistema QR Hostal Terraza

Detalle en `.opencode/agent/` y `.opencode/skills/`. Normativa: `Sistema QR desarrollo/BLUEPRINT.md`, `Reglas de Oro QR.md` (v129-MASTER), `PROJECT.md` (v1.6.4-FIX). Act. 2026-10-01 (roster de 20 agentes; §0 obligatoria; ADR-067). Act. 2026-10-02 (herencia de modelo, ADR-069).

## 0. Selección de tier obligatoria (por tarea)

- El orquestador DEBE preguntar con `question`, **UNA VEZ POR TAREA**, qué tier usar; la respuesta fija la ruta. **Sin respuesta no se ejecuta nada**: prohibido explorar, editar o `task` antes de resolver el tier.
- **FREE** — `opencode/big-pickle` (`$0`): trabajo mecánico/lectura. **PAGO** — `opencode-go/deepseek-v4.1-flash`: criterio, runtime, seguridad, arquitectura.
- **Herencia (ADR-069, 2026-10-02):** solo los 4 primarios declaran `model:`; los 16 subagentes lo omiten y heredan del primario invocante. `@seo-dev` ya no fija `qwen3.8-flash`. Detalle: skill `cascada-tier`.

## 1. Matriz de enrutamiento

Roster: 20 agentes = 4 primarios (orquestan) + 16 subagentes; un agente por dominio. **La tabla ES el flujo de delegación**.

| Dominio | Agente Especialista Único |
|---|---|
| CSS de silo / templates | @frontend-tpl |
| `admin.html` / `scanner.html` | @admin-dev |
| endpoints / QR | @backend-dev |
| RLS / esquema | @sql-security |
| JS/TS rutinario | @js-silo-dev |
| seed + loader + smoke | @content-loader |
| migraciones | @data-migration |
| motor de render | @renderer-dev |
| SEO | @seo-dev |
| arquitectura / ADR | @architect |
| revisión de arquitectura / ADR | @architect-review |
| multimedia | @media-reader |
| research de destinos | @research-agent |
| exploración | @explore |
| cierre documental | @docs-keeper |
| certificación | @qa-auditor |

- **Primarios** (`mode: primary`): `@plan`/`@build` (PAGO) y `@free-plan`/`@free-build` (FREE, default); orquestan y delegan, no implementan. Sin ruta híbrida (ADR-067).
- **Herencia (ADR-069):** los 16 subagentes no declaran `model:`; heredan del primario (`big-pickle` vía `@free-build`, `deepseek-v4.1-flash` vía `@build`). **Allow-list ampliada (ADR-071, 2026-10-02):** los 16 son invocables desde los primarios FREE; los 9 de riesgo conservan el gate de §2.
- Agentes: `ls .opencode/agent/` (ADR-006).

## 2. Tier por riesgo y confirmación

- **free-first** (FREE) para trabajo mecánico/lectura; `default_agent: build` es solo entrada, no fija tier (lo resuelve §0).
- **Allow-list FREE (ADR-069 + ADR-071):** los **16 subagentes son invocables** desde `@free-build`/`@free-plan` (`permission.task` con `"*": deny` primero y las 16 excepciones en `allow`). Los 9 de riesgo (**sql-security, data-migration, backend-dev, renderer-dev, admin-dev, architect, architect-review, seo-dev, research-agent**) exigen el **gate de confirmación** del punto siguiente: permitidos por config no significa autorizados a ejecutar. Detalle: skill `cascada-tier`.
- **Gate de confirmación por riesgo (PAGO):** confirmación explícita del usuario antes de RLS/esquema y migraciones (`@sql-security`, `@data-migration`), motor `evento-app.html` (`@renderer-dev`), arquitectura/ADR (`@architect`, `@architect-review`).
- El tier solo cambia por decisión/confirmación explícita; nunca automático. Prohibido desdoblar PAGO+FREE en paralelo.

## 3. Reglas transversales

1. **Cero Borrado (Oro #2):** nunca eliminar IDs del Contrato v112, ni ocultos (`display: none`).
2. **Vanilla JS puro (ADR-001):** prohibido Node.js en runtime cliente, React o build tools.
3. **Aislamiento Atómico (Oro #9):** CSS de silo bajo `.tpl-{template_id}`; nada suelto en `:root`.
4. **Silent Fallback (ADR-008):** todo `<img>` dinámico lleva `onerror="this.src='path/to/fallback.png';"`.
5. **Data-First (Oro #1):** Fase I (datos/IDs/Supabase, TRACE positivo) antes de Fase II (estética).
6. **Escudo GOLD:** antes de desplegar `api/*.js`, `admin.html`, `index.html` o el motor de render -> skill `gold-shield`.
7. **Mandato documental (Oro #12):** `TASKS.md`/`NEXT.md`/`DECISIONS.md` completos, sin perder historial.
8. **Eficiencia (Oro #17-18):** costo = turnos x contexto; 1 exploración + 1 implementación/dominio + 1 verificación/script (skill `eficiencia-recursos`).
9. **Lectura por rango:** > 200 KB (`admin.html`, `DECISIONS.md`) -> `grep`/`Read` con `offset`/`limit`, nunca completo (skill `eficiencia-recursos`).
10. **Express (xpress):** "express"/"xpress"/"rápido" -> skill `express-mode`; escala a normal en arquitectura, RLS/seguridad, migraciones o > 3 archivos críticos.
11. **Presupuesto (Oro #19-20):** estima tokens/tiempo y concilia con `usage_report.js`; tarea pesada (media, research, > ~1.5M tokens) -> avisar costo y recomendar IA externa (skill `eficiencia-recursos`).
12. **Contrato de retorno:** todo `task` devuelve compacto (STATUS, ARCHIVOS, VERIFICACION N/N, BLOQUEADORES, SIGUIENTE); orquestador 25-30 turnos/sesion (skill `eficiencia-recursos`).
13. **Tier por riesgo, nunca por preferencia:** escalar a PAGO NO es automático, exige confirmación explícita; en PAGO los dominios de riesgo (§2) exigen el gate §2; prohibido desdoblar PAGO+FREE (ADR-069).
14. **Watchdog y cierre medido:** subagente >25 turnos o >50.000 tokens/turno se aborta y re-planifica. Toda sesion CIERRA con balance (turnos, cache_read, por agente), estimado vs real, 1-3 aprendizajes, con `scripts/usage_report.js` y `scripts/session_close.js`. Los 25 turnos son tope DURO, no guia (2026-10-02: 160 turnos = 10,9M tokens, 93,7% `cache_read`). Editar solo con `edit` (PowerShell inline borro TSK-089). Detalle: skill `eficiencia-recursos`.

## 4. Índice de skills

Skills REALES en `.opencode/skills` (10): `anti-absorcion`·`cascada-tier`·`create-dynamic-page`·`eficiencia-recursos`·`express-mode`·`frontend-design`·`gold-shield`·`research-destination`·`templates`·`web-design-guidelines`.

**Pendientes (NO existen; no invocar):** `agentes-roster`·`modelos-verificados`·`gemini-research`·`ingest-eventos`·`batch-create`·`reglas-de-oro`. No declararlas existentes; seguir `Reglas de Oro QR.md` y `BLUEPRINT.md`.
