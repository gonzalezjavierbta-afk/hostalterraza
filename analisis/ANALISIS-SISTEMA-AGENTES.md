# Análisis del Sistema de Agentes y Subagentes — ExploraCO / Hostal Terraza

- **Fecha:** 14 de septiembre de 2026
- **Sesión:** Análisis completo del universo `.opencode/` + plan de corrección T1–T9 + aplicación y verificación
- **Estado:** Entregado y aplicado (ver `Sistema QR desarrollo/DECISIONS.md` ADR-031)
- **Herramientas:** lectura directa del repo, consultas a models.dev (T8), medición de logs de uso (T7-metrics)

---

## 1. Resumen ejecutivo

El sistema de agentes de OpenCode del proyecto es funcional pero arrastraba **dispersión documental y de configuración**:

- **35 definiciones de agente** en `.opencode/agent/` (15 pares pro/free + 4 singulares + 1 experimental) vivían con **2 agentes definidos dos veces** (`exp-pickle` en `opencode.json` inline Y `.md`).
- El **AGENTS.md de la raíz solo documentaba 6 agentes** (roster de 6 filas) cuando el repo tenía 35 — la documentación iba muy por detrás de la realidad.
- **Rutas fantasma** `exploraco desarrollo/` (carpeta que existe en el repo hermano `exploraco`, no en este) aparecían en 27 archivos; la carpeta real se llama `Sistema QR desarrollo/`.
- **Dos universos de agentes/skills**: `.opencode/` (operativo) y `.agents/` (duplicado parcial, sin README que lo explique).
- **Modelos desactualizados**: `plan.md` usaba `deepseek-v4-flash` (RETIRADO por DeepSeek el 10-sep-2026); `frontend-tpl.md` citaba `minimax-m3` que ningún frontmatter usa.
- **Ausencia de KPIs de delegación**: no había forma de medir si el agente principal absorbe el trabajo de los subagentes.

---

## 2. Metodología

1. Lectura de `opencode.json` (raíz), los 35 archivos `.opencode/agent/*.md`, los 10 skills de `.opencode/skills/*/SKILL.md`, `~/.config/opencode/opencode.jsonc` y `~/.local/share/opencode/auth.json`.
2. Verificación de modelos contra documentation oficial (T8, research-agent-free).
3. Medición de KPIs de delegación sobre 5 logs de uso `logs/uso/*.md` (T7-metrics, explore-free).
4. Auditoría arquitectónica de la fusión candidata `exp-pickle` → `js-silo-dev-free` (T3 architect-free + T3-review architect-review-free).
5. Aplicación del plan de corrección T1–T9 con subagentes `*-free` (esquema gratuito, proveedor `opencode-go` caído el 14-sep-2026).

---

## 3. Hallazgos

### 3.1 Fortalezas del sistema

- **Esquema dual pro/free bien pensado**: 15 pares con el mismo nombre y sufijo `-free`, dominios de archivos disjuntos, permisos explícitos.
- **Orquestación centralizada**: `@plan`/`@free-plan` como único punto de entrada; el resto son subagentes por delegación.
- **Singulares con roles claros**: `@free-build` (implementa), `@qa-auditor` (solo audita, edit: deny).
- **Reglas transversales sólidas**: Cero Borrado, Vanilla JS, Aislamiento Atómico, Silent Fallback, Data-First, Mandato Documental.
- **10 skills operativos** con SKILL.md propia (create-dynamic-page, batch-create, gold-shield, ingest-eventos, etc.).

### 3.2 Problemas Críticos (C1–C3)

| ID | Problema | Evidencia |
|---|---|---|
| C1 | **`@exp-pickle` definido dos veces** (inline `opencode.json` + `.opencode/agent/exp-pickle.md`) | `opencode.json` líneas 29–40 + archivo físico |
| C2 | **AGENTS.md documenta 6 agentes; repo tiene 35** | AGENTS.md raíz (tabla de 6 filas) vs. 35 `.md` |
| C3 | **Proveedor `opencode-go` no conecta** (14-sep-2026) | `~/.local/share/opencode/log/opencode.log`: `AI_APICallError: Cannot connect to API` providerID=opencode-go — la operación pro completa está bloqueada; solo opera el gateway free `opencode` |

### 3.3 Problemas Mayores (M1–M5)

| ID | Problema |
|---|---|
| M1 | Rutas fantasma `exploraco desarrollo/` en 27 archivos (148 ocurrencias) |
| M2 | Modelo `deepseek-v4-flash` RETIRADO pero aún referenciado en `plan.md` |
| M3 | `minimax-m3` citado como "frontend-tpl pro" — ningún frontmatter lo usa (el real usa `deepseek-v4.1-flash`) |
| M4 | Dos universos de agentes: `.opencode/` (operativo) y `.agents/` (duplicado sin README) |
| M5 | Nombre de agente legado `sql-migrations` citado en `WORK_PLAN_ANALYTICS.md` |

### 3.4 Problemas Menores (m1–m3)

| ID | Problema |
|---|---|
| m1 | AGENTS.md citaba `Reglas_de_Oro_QR.md`/`BUGS_HISTORICOS.md` — nombres reales: `Reglas de Oro QR.md`/`ERRORES_HISTORICOS.md` |
| m2 | 4 agentes (`qa-auditor`, `frontend-tpl`, `frontend-tpl-free`, `seo-dev`) citan en su Contexto obligatorio rutas inexistentes: `🛡️ Reglas de Oro ExploraCO — v5.md` y `BUGS_HISTORICOS.md` |
| m3 | `opencode.json` tenía coma final tras el bloque eliminado de `exp-pickle` (JSON invalidado) |

---

## 4. Métricas de delegación (baseline de KPIs)

| Medición | Calls | Task | %Task | Exploración | %Exploración | Delegada | Ratio deleg. | Sesiones absorción |
|---|---|---|---|---|---|---|---|---|
| Sesión 5H (`analisis/ANALISIS-SESION-5H.md`) | 868 | 7 | 0.81% | 439 | 50.6% | — | — | — |
| Mes (`logs/uso/2026-09-07_1629_mes.md`) | 12081 | 92 | 0.76% | 5931 | 49.1% | 2126 | 35.8% | 20 de 151 |
| Suma 5 logs simples | 18784 | 158 | 0.84% | 9600 | 51.1% | 3701 | 38.6% | 43 |

**Target:** ratio de delegación ≥ 50% en sesiones de implementación; absorciones → 0.

---

## 5. Plan de corrección aplicado (T1–T9)

| Tarea | Descripción | Ejecutor | Estado |
|---|---|---|---|
| T1 | 148 rutas `exploraco desarrollo/` → `Sistema QR desarrollo/` en 27 archivos | js-silo-dev-free | ✅ |
| T2 | Reescritura de `AGENTS.md` (34 agentes, esquema free, ADR-031) | docs-keeper-free | ✅ |
| T3 | Auditoría y veredicto de fusión d2 (`exp-pickle` → `js-silo-dev-free`) | architect-free | ✅ |
| T3-review | Segunda opinión de la fusión d2 (C1/C2/C3) | architect-review-free | ✅ |
| T4 | Corrección de modelos: `plan.md` → `qwen3.8-flash`; excepciones `media-reader-free`/`seo-dev` | architect-free | ✅ |
| T5 | Saneamiento `sql-migrations` → `sql-security-free` en WORK_PLAN_ANALYTICS.md | docs-keeper-free | ✅ |
| T6 | Declarar `.agents/` legado (README.md) | architect-free | ✅ |
| T7 | Reglas anti-absorción (ADR-031) + KPIs medibles | architect-free + explore-free | ✅ |
| T8 | Verificación de catálogo de modelos (14-sep-2026) | research-agent-free | ✅ |
| T9 | Registro de ADR-031 en `DECISIONS.md` | docs-keeper-free | ✅ |

### 5.1 Fusión d2 (condiciones avaladas por architect-review-free)

- **C1 — Paridad de temperatura:** `temperature: 0.3` añadido a `js-silo-dev-free.md` ✅
- **C2 — Verificación post-fusión:** `opencode.json` validado (JSON correcto), `exp-pickle.md` eliminado, referencias limpiadas en `free-build.md`/`free-plan.md`/`plan.md` ✅
- **C3 — Cierre documental:** reescritura de `AGENTS.md` + ADR-031 en `DECISIONS.md` ✅

---

## 6. Catálogo de modelos vigente (2026-09-14)

| Modelo | Estado | Uso |
|---|---|---|
| `opencode/big-pickle` | FREE por límite de tiempo; sin tool-calling oficial (stripped) pero funcional; inestable | 14 agentes `*-free` + `free-build` + `free-plan` |
| `opencode/mimo-v2.5-free` | FREE, multimodal, estable | `media-reader-free` (EXCEPCIÓN: único free con visión) |
| `opencode-go/qwen3.8-flash` | Catálogo Go, $0.15/$0.47, límite $30/mes | `seo-dev` (EXCEPCIÓN) y `plan` |
| `opencode-go/deepseek-v4.1-flash` | Nuevo 10-sep-2026, multimodal, supera V4-Pro | 14 agentes pro + `qa-auditor` |
| `opencode-go/deepseek-v4-flash` | RETIRADO por DeepSeek (alias → V4.1) | — |
| `opencode-go/minimax-m3` | Válido en catálogo | Inciencia: ningún frontmatter lo usa |

---

## 7. Decisiones estratégicas

1. **Esquema GRATUITO como dirección de operación** (2026-09-14): el proveedor `opencode-go` no conecta; la operación diaria delega en subagentes `*-free` + `free-build` (big-pickle). Los pro quedan como respaldo de calidad y excepciones (`seo-dev`, `qa-auditor`, `media-reader-free`).
2. **Fusión d2**: `exp-pickle` eliminado físicamente; su superset funcional es `js-silo-dev-free`.
3. **`.agents/` declarado legado**; universo operativo es `.opencode/`.
4. **Reglas anti-absorción** (ADR-031): 9 reglas que prohíben al principal resolver lo que delegó, con KPIs y umbral de 30 llamadas directas.

---

## 8. Archivos entregados/modificados

- `AGENTS.md` (166 líneas, reescrito completo)
- `Sistema QR desarrollo/DECISIONS.md` (ADR-031, 389 líneas)
- `opencode.json` (bloque `exp-pickle` eliminado, JSON válido)
- `.opencode/agent/exp-pickle.md` (borrado)
- `.opencode/agent/plan.md` (modelo → `qwen3.8-flash`)
- `.opencode/agent/media-reader-free.md` y `.opencode/agent/seo-dev.md` (excepciones en description)
- `.opencode/agent/js-silo-dev-free.md` (`temperature: 0.3`)
- `.opencode/agent/free-build.md`, `free-plan.md`, `plan.md` (rutas de enrutamiento sin `exp-pickle`)
- `.agents/README.md` (declaración de legado)
- `WORK_PLAN_ANALYTICS.md` (sanemiento `sql-migrations`)
- 27 archivos de `.opencode/` con rutas corregidas `Sistema QR desarrollo/`

---

## 9. Pendientes / preguntas abiertas

1. **Pasada T1-bis**: 4 agentes (`qa-auditor.md`, `frontend-tpl.md`, `frontend-tpl-free.md`, `seo-dev.md`) citan en su Contexto obligatorio `🛡️ Reglas de Oro ExploraCO — v5.md` y `BUGS_HISTORICOS.md` (rutas inexistentes; reales: `Reglas de Oro QR.md`/`ERRORES_HISTORICOS.md`).
2. **minimax-m3**: documentado como incidencia en AGENTS.md/ADR-031. Decidir si `frontend-tpl.md` debe cambiarse a `minimax-m3` o quedarse en `deepseek-v4.1-flash` (hoy usa el segundo; la tarea T8 no pedía cambiar).
3. **NEXT.md/TASKS.md**: registrar el cierre de la sesión en el ciclo documental (AI-DOS).
4. **Commit**: los cambios están sin commitear; decidir cuándo (y si) commitear.

---

*Documento de análisis elaborado en la sesión del 14-sep-2026. Cierre documental enlazado: `Sistema QR desarrollo/DECISIONS.md` ADR-031 y `AGENTS.md` (raíz).*