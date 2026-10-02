---
name: cascada-tier
description: "Explica la cascada de tier de HostalTerraza (herencia de modelo en los 16 subagentes, allow-list FREE y los 9 dominios de riesgo). Úsala cuando se hable de tier, free, herencia o cascada."
---

# Cascada de tier (ADR-069)

Operativiza el ADR-069 "Tier por herencia de modelo en subagentes" y la compuerta §0/§2 de `AGENTS.md`. El tier se resuelve **una vez por tarea** con la herramienta `question`; la cascada decide **en qué modelo corre cada subagente** según el primario que lo invoca, sin duplicar archivos.

## 1. Cómo funciona la herencia de modelo

- Solo los **4 primarios** declaran `model:`: `@plan`/`@build` (PAGO, `opencode-go/deepseek-v4.1-flash`) y `@free-plan`/`@free-build` (FREE, `opencode/big-pickle`).
- Los **16 subagentes** (admin-dev, architect, architect-review, backend-dev, content-loader, data-migration, docs-keeper, explore, frontend-tpl, js-silo-dev, media-reader, qa-auditor, renderer-dev, research-agent, seo-dev, sql-security) **omiten `model:`** y heredan el del primario invocante: `big-pickle` si los llama un primario FREE, `deepseek-v4.1-flash` si los llama uno PAGO.
- Así existe el par FREE/PAGO **sin agentes gemelos** (ADR-067 sigue vigente).
- `@seo-dev` dejó de fijar `qwen3.8-flash`; en PAGO hereda `deepseek-v4.1-flash` como cualquier subagente.
- En `permission.task` los patrones se evalúan en orden: `"*": "deny"` **debe ir primero**; las excepciones van después. Un patrón que resuelve `deny` elimina al subagente de la descripción del Task tool (menos contexto).

## 2. Allow-list FREE y los 9 dominios de riesgo

En ruta FREE el primario solo puede invocar estos **7** (heredan `big-pickle`):

`@docs-keeper` · `@explore` · `@js-silo-dev` · `@frontend-tpl` · `@content-loader` · `@media-reader` · `@qa-auditor`

Los **9 dominios de riesgo** quedan fuera de la allow-list; exigen escalado a PAGO con confirmación explícita del usuario:

`@sql-security` · `@data-migration` · `@backend-dev` · `@renderer-dev` · `@admin-dev` · `@architect` · `@architect-review` · `@seo-dev` · `@research-agent`

**Riesgo aceptado:** opencode permite forzar por `@` a un dominio de riesgo desde una sesión FREE, y correría en `big-pickle`. **Mitigación (2 capas):** la allow-list de `permission.task` + la regla de escalado en el prompt de `@free-plan`/`@free-build`. La denegación por sí sola no basta.

## 3. Criterios de aceptación verificables por dominio

Un subagente no cierra por "terminé": cierra con evidencia contra el archivo real (ADR-006). Mínimos por dominio del allow-list:

| Dominio | Agente | Criterio de aceptación verificable |
|---|---|---|
| seed + loader + smoke | `@content-loader` | Seed aplicado + Escudo GOLD (`node --check`, ASCII-safety, balance de divs) + smoke **N/N** |
| exploración | `@explore` | Rutas y rangos de línea **reales** (verificados), **cero invenciones**; devuelve `archivo:línea`, no contenido |
| CSS de silo | `@frontend-tpl` | CSS encapsulado bajo `.tpl-{template_id}`, nada suelto en `:root`, balance de divs sin regresión |
| JS rutinario | `@js-silo-dev` | `node --check`, sin bloques duplicados > 5 líneas, `grep` de residuos = 0 fuera de alcance |
| multimedia | `@media-reader` | Ruta real del asset + `onerror` con fallback (Silent Fallback, ADR-008) |
| cierre documental | `@docs-keeper` | Entrega **completa** sin perder historial, ASCII-safe, fecha 2026-10-02, `edit` (no PowerShell inline) |
| certificación | `@qa-auditor` | Contraste contra el archivo real (ADR-006), comando + resultado N/N, bloqueadores explícitos |

Los 9 dominios de riesgo además exigen el **gate §2**: confirmación explícita del usuario antes de ejecutar (RLS/esquema/migraciones, motor `evento-app.html`/`pagina-destino.js`, arquitectura/ADR).

## 4. Presupuesto de pasos recomendado

- **Trabajo mecánico: 20 pasos.** Ajustes puntuales, seeds, CSS acotado, edición de docs.
- **Exploradores: 30 pasos.** `@explore` y reconocimiento amplio necesitan más turnos de lectura, pero devuelven solo `archivo:línea`.
- **Watchdog:** un subagente que supere **25 turnos** o **50.000 tokens/turno** se aborta y se re-planifica; nunca se re-despacha el mismo perfil. Los 25 turnos del orquestador son tope DURO: al agotarlos, resumen de estado y sesión nueva.

## 5. Al escalar, PAGO rehace la tarea; no solo la revisa

Si una tarea FREE falla o toca un dominio de riesgo, el primario PAGO **rehace la tarea desde el brief**, no se limita a revisar y parchear el artefacto FREE. Revisar un output dudoso y corregirlo consume más turnos y contexto que rehacerlo limpio (Oro #17-18: costo = turnos × contexto). Por eso: **una implementación por dominio**, no una implementación + una revisión + un fix. El escalado exige confirmación explícita del usuario; nunca es automático ni en paralelo (prohibido desdoblar FREE+PAGO).

## 6. Disciplina de brief: pasa rutas y rangos, no contenido

Todo `task` entrega y exige el **contrato de retorno compacto** (máx ~600 tokens): STATUS · ARCHIVOS `ruta:rango` · VERIFICACIÓN comando + N/N · BLOQUEADORES · SIGUIENTE.

- El brief pasa **ruta exacta + rango de líneas + bloques `old`/`new` + criterio de aceptación**. Nunca el contenido completo del archivo.
- Prohibido volcar archivos, diffs extensos o narrar lo leído.
- Si falta un dato, se pide dentro del mismo brief; el orquestador no pide "muéstrame el archivo".

## 7. Cierre documental

Al cerrar, actualiza `TASKS.md` (Estado + nota de cierre con el alcance real), `NEXT.md` (relevo + riesgos activos) y, si hubo decisión, un ADR en `DECISIONS.md` + `decisiones/`. Falla nueva → `ERRORES_HISTORICOS.md` antes de cerrar. Referencia: `.opencode/skills/eficiencia-recursos`.
