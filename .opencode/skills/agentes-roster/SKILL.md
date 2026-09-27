---
name: agentes-roster
description: Roster completo de los 39 agentes (dominios, permisos, modelos), decisiones de reconciliacion y estado real del contrato. Cargar cuando haga falta el detalle de un agente, su modelo o un permiso.
---

# Roster de Agentes — Sistema QR Hostal Terraza

Detalle completo del enrutamiento de agentes para OpenCode. Generado a partir de `Sistema QR desarrollo/BLUEPRINT.md`, `Sistema QR desarrollo/Reglas de Oro QR.md` (v128-MASTER) y `Sistema QR desarrollo/PROJECT.md` (v1.6.4-FIX). Este archivo cierra el punto que la Sección 6 del Blueprint pedía guardar en la raíz pero no incluía, y se reescribió completo el 2026-09-14 para reflejar el estado real verificado del repositorio (34 agentes en `.opencode/agent/` entonces, esquema gratuito como dirección estratégica). Se actualizó el 2026-09-21 para adoptar el **esquema TRIPARTITO de rutas (Free / Hybrid / Pro)** con 39 agentes en `.opencode/agent/` — la ruta gratuita sigue siendo el default. Se actualizó el 2026-09-24: `permission.edit`/`permission.bash` globales en `allow`, `default_agent: free-build` y planificadores/auditores/lectores en `edit: deny` (ADR-052).

La matriz de enrutamiento **compacta** (dominio -> agente pro / agente free) vive en `AGENTS.md`; este archivo es el detalle completo.

## 1. Matriz de Enrutamiento de Agentes (esquema TRIPARTITO de rutas)

Antes de procesar cualquier codigo, los agentes principales deben delegar las tareas a los subagentes especializados configurados en la carpeta `.opencode/agent/` segun el dominio de la tarea. Esta matriz es la fuente de verdad operativa del enrutamiento (ADR-006).

Existen **tres rutas completas**: una GRATUITA (todos los agentes usan modelos `opencode/*` de costo cero), una HYBRID (mezcla deliberada PRO/FREE en una misma sesion, ruteo por riesgo) y una de PAGO (agentes pro `opencode-go/*`). Los agentes gratuitos se identifican con el sufijo `-free`. La ruta gratuita es el default de `opencode.json` (`default_agent: free-build`; hasta el 2026-09-23 era `free-plan`, cambiado por ADR-052).

### 1.1 Ruta GRATUITA (0 costo — default)

**Agentes primarios gratuitos:**

| Agente | Modelo | Uso |
|---|---|---|
| `free-plan` | `opencode/big-pickle` | Orquestador gratuito (mode primary, edit: deny · bash: ask por gatekeeper del tier gratuito) |
| `free-build` | `opencode/big-pickle` | Build gratuito (mode primary, edit/bash allow) |

**Subagentes gratuitos (sufijo `-free`; modelo por defecto `opencode/big-pickle`, salvo `@media-reader-free` = `opencode/mimo-v2.5-free`):**

| Agente | Uso |
|---|---|
| `exp-pickle-free` | Validaciones de bajo riesgo, linter, smoke tests simples (temperature 0.3; reporta y soporta, no corrige) |
| `qa-auditor-free` | Escudo GOLD y auditoria (solo reporta, no corrige) |
| `explore-free` | Exploracion masiva de codigo (solo lectura) |
| `docs-keeper-free` | Documentacion: TASKS/NEXT/BLUEPRINT/DECISIONS/ERRORES_HISTORICOS, ADRs, handoffs |
| `content-loader-free` | Creacion repetitiva de paginas dinamicas (seed+loader+smoke) |
| `research-agent-free` | Investigacion web de destinos y fichas verificadas |
| `js-silo-dev-free` | JS/TS rutinario y refactor menor (superset funcional de exp-pickle) |
| `frontend-tpl-free` | `evento.html` y CSS de silos (`css/templates/*/*.css`) |
| `admin-dev-free` | `admin.html`, `scanner.html` |
| `renderer-dev-free` | Motor de render `pagina-destino.js` |
| `data-migration-free` | Migraciones y seeds (SQL critico escala a `sql-security`) |
| `seo-dev-free` | Sitemap, meta tags, robots, redirects |
| `media-reader-free` | Multimedia (imagen/audio/video/PDF) — `opencode/mimo-v2.5-free` |
| `architect-free` | Arquitectura y ADRs |
| `architect-review-free` | Segunda opinion de arquitectura |
| `backend-dev-free` | Backend serverless `api/*.js` |
| `sql-security-free` | SQL de bajo riesgo; critico escala a `sql-security` (pro) |

**Limitacion de `sql-security-free`:** NO gestiona RLS, autenticacion, claves ni integridad de datos critica. Esas tareas SIEMPRE se escalan a `sql-security` (version pro).

### 1.2 Ruta HYBRID (mixta — ruteo por riesgo)

La ruta Hybrid mezcla en una misma sesion agentes PRO (`opencode-go/*`, criterio, esfuerzo y riesgo de runtime) y agentes FREE (`opencode/*`, trabajo rutinario, repetitivo y dispendioso de bajo riesgo), segun la tarea.

**Agentes primarios hybrid:**

| Agente | Modelo | Uso |
|---|---|---|
| `hybrid-plan` | `opencode-go/deepseek-v4.1-flash` | Planificador hibrido (mode primary, edit/bash deny) |
| `hybrid-build` | `opencode-go/deepseek-v4.1-flash` | Build hibrido (mode primary, edit/bash allow) |

**Regla de oro del ruteo hybrid:** el ruteo PRO/FREE se decide por riesgo y criterio (matriz del ADR del esquema tripartito en `Sistema QR desarrollo/DECISIONS.md`), **nunca por preferencia**. Nunca asignar un dominio PRO a un agente FREE (riesgo de runtime/seguridad); nunca gastar cuota PRO en trabajo mecanico que FREE resuelve igual (ahorro ~95% en tareas rutinarias).

### 1.3 Ruta de PAGO (`opencode-go/*` — opcional, mayor calidad)

**Agentes primarios de pago:**

| Agente | Modelo | Uso |
|---|---|---|
| `plan` | `opencode-go/deepseek-v4.1-flash` | Orquestador de pago (mode primary, edit/bash deny) |
| `build` (default legacy) | `opencode-go/deepseek-v4.1-flash` | Build de pago (mode primary, edit/bash allow) |

**Subagentes de pago:** los 15 pares pro del Roster (`frontend-tpl`, `admin-dev`, `backend-dev`, `sql-security`, `architect`, `architect-review`, `content-loader`, `data-migration`, `docs-keeper`, `explore`, `js-silo-dev`, `media-reader`, `renderer-dev`, `research-agent`, `seo-dev`) + el auditor `qa-auditor`.

**Regla de oro:** todo agente DEBE tener `model:` explicito en su `.md` (prohibido heredar el modelo principal). Los IDs usan el prefijo real del proveedor OpenCode Go (`opencode-go/*`) o los modelos gratis (`opencode/*`); cualquier ID fuera de `opencode models` se considera invalido y se corrige.

**Ruteo por ruta:** los primarios de pago (`plan`/`build`) delegan SIEMPRE a subagentes pro (`admin-dev`, `backend-dev`, ...). Los primarios gratuitos (`free-plan`/`free-build`) delegan SIEMPRE a subagentes `-free` (`admin-dev-free`, `backend-dev-free`, ...). Los primarios hybrid (`hybrid-plan`/`hybrid-build`) delegan por la matriz de riesgo: PRO para dominios de criterio/riesgo de runtime y FREE para trabajo rutinario. Prohibido mezclar rutas excepto para escalar seguridad critica (`sql-security-free` -> `sql-security`).

**Plan = orquestador:** el agente `plan` (`.opencode/agent/plan.md`) NO ejecuta trabajo operativo. Explora mediante `@explore`, investiga via `gemini-research`/`@research-agent`, y deriva toda implementacion al subagente por dominio. `free-plan` hace lo mismo con `@explore-free`/`@research-agent-free` y modelo `opencode/big-pickle`; `hybrid-plan` identico con la matriz de riesgo del esquema tripartito.

## Decisión estratégica 2026-09-14: esquema GRATUITO como dirección de operación

- **Toda la operación del día a día se ejecuta con subagentes `*-free` + `@free-build`** (modelo `opencode/big-pickle`), con planificación previa de `@free-plan`.
- Los agentes pro (`opencode-go/*`) quedan como **respaldo de capacidad/calidad** y para excepciones de modelo documentadas (`seo-dev` pro, `qa-auditor`, `media-reader-free` con visión).
- Detalle operativo: `frontend-tpl.md` pro usa `deepseek-v4.1-flash` (ver skill `modelos-verificados`).

## Decisiones de reconciliación (confirmadas 2026-09-14)

- **Motor público vigente: `evento.html`** (no `evento3.html`). El Contrato de Datos v112 (21 Átomos Soberanos), especificado originalmente en el Blueprint para `evento3.html`, se traslada íntegro a `evento.html` como el "Cerebro Único" que todos los agentes deben tratar como inamovible. Esto cierra la reconciliación pendiente en TSK-016/017/018 (Sistema QR desarrollo/PROJECT.md, Sección 9).
- **Contrato de Datos vigente: v112 / 21 Átomos Soberanos** (Blueprint, Sección 3). Las versiones citadas en otros documentos — v107 (Reglas de Oro, Mandato 1) y v110/20 átomos (Sistema QR desarrollo/PROJECT.md, Secciones 5 y 7) — quedan supersedidas como línea base de validación. Los 4 átomos de campaña de v110 (`#meta-magnitud`, `#mod-mapa-crisis`, `#mod-como-ayudar`, `#mod-impacto-historico`) se tratan como **extensión específica del silo `b5` / `eventovenezuela.html`**, no como parte del contrato core que certifica `@qa-auditor` en `evento.html`.
- **Plataforma: OpenCode**, con los modelos especificados en Sistema QR desarrollo/BLUEPRINT.md Sección 5.

## ⚠️ Discrepancia conocida: Contrato v112 vs. código real (detectada 2026-09-14)

Se auditó el `evento.html` real del repositorio (1630 líneas, 81 IDs) contra el Contrato de Datos v112. El código está muy por delante de la documentación fuente:

- El `<title>` del archivo dice "Master Orchestrator v214 · Atomic Grid System"; los comentarios internos de versión llegan hasta v222. El Blueprint describe v112.
- De los 21 Átomos Soberanos, solo 8 existen con ese id exacto: `event-title`, `meta-fecha`, `meta-hora`, `meta-lugar`, `mod-video`, `mod-lineup`, `mod-ubicacion`, `mod-form`. `event-description` no existe en ninguna forma (ni como id ni en ningún atributo). Los otros 12 (`mod-galeria`, `mod-patrocinadores`, `mod-entradas`, `mod-faqs`, `mod-contacto`, `mod-reglas`, `mod-itinerario`, `mod-redes`, `mod-comentarios`, `mod-encuesta`, `mod-descargas`, `mod-sponsors-vip`, `mod-actualizaciones`) no están.
- El archivo real usa en su lugar un esquema propio de 81 IDs — `mod-hero`, `mod-historia`, `mod-impacto`, `mod-objetivo`, `mod-equipo`, `mod-experiencias`, `mod-cartel`, `mod-playlist`, `mod-whatsapp`, `mod-cta-final`, `mod-info-tecnica`, `mod-footer`, `mod-boletos`, `mod-faq`, `mod-sponsors`, entre otros — más `unified-frame`, que sí coincide con la mención de Sistema QR desarrollo/Reglas de Oro QR.md (Mandato 2).
- Dos silos activos en el CSS no aparecen en la lista de "Silos Operativos Validados" de Sistema QR desarrollo/PROJECT.md: `.tpl-f6` y `.tpl-f8`.
- Hay un sistema de internacionalización (`js/i18n.js`, 46 referencias a `i18n` en el archivo) que ningún documento fuente menciona.
- Sí coincide con lo documentado: la doble pestaña de registro (`tab-new`/`tab-old`, `form-nuevo`/`form-ya`) encaja con el patrón Dual-Phase (ADR-011); la ausencia de Wompi/HMAC/`qr-creator` es consistente con TSK-001/002 aún pendientes en el roadmap.

**Decisión (2026-09-14):** se deja v112 como el contrato que validan los agentes por ahora — sin cambios en `qa-auditor.md`, `frontend-tpl.md` ni `plan.md`. Consecuencia práctica: tal como están configurados hoy, `@qa-auditor` va a reportar como "faltantes" los 12 átomos de arriba, que en realidad fueron renombrados o reestructurados en v214+ — son falsos positivos conocidos, no regresiones reales. No correr `@qa-auditor` contra `evento.html` en serio hasta traer un Contrato de Datos actualizado (o instruirlo explícitamente a ignorar esos 12 IDs).

**Estado real de ADR-040 (16-09-2026, actualización):** el catálogo de plantillas curado por la cuenta master ya está **IMPLEMENTADO** (ADR-045, QA APTO) — ya no es "solo diseño". `admin.html` incluye el sub-tab Plantillas en `pg-globaladmin` (MOSTRAR/OCULTAR/REORDENAR vía `config_global` + RPC `fn_config_global_merge`) y la migración `migrations/adr040_config_global_templates.sql` existe pero **está pendiente de ejecución manual por Dirección** (TSK-035): hasta ejecutarla, el front degrada a fail-open (todo visible), no bloquea. El registro del silo f11 como theme `fosforescente` ya está en `admin.html` (ADR-044). Para tareas de silo/template, la norma completa vive en `Sistema QR desarrollo/AMPLIACION/TEMPLATES.md` (hub, ADR-046) y la skill `.opencode/skills/templates/` — leer el hub antes de tocar CSS.

## Roster de agentes (39 archivos en `.opencode/agent/`)

Universo: 15 pares pro/free (30 agentes, mismo nombre con sufijo `-free`) + 9 singulares (`plan`, `build`, `free-plan`, `free-build`, `hybrid-plan`, `hybrid-build`, `qa-auditor`, `qa-auditor-free`, `exp-pickle-free`). El agente experimental `exp-pickle` fue **retirado físicamente** (fusión d2 avalada por `architect-review` con condiciones C1/C2/C3 — ver `Sistema QR desarrollo/DECISIONS.md` ADR-031, Addendum A): se eliminó su bloque inline de `opencode.json` (JSON validado correcto) y se borró `.opencode/agent/exp-pickle.md`. El 2026-09-21 reaparece como subagente **gratuito** `exp-pickle-free` (validaciones de bajo riesgo, linter, smoke simples; temperature 0.3; modelo `opencode/big-pickle`) — versión FREE del soporte mecánico, no primario. `@js-silo-dev-free` es su superset funcional (con `temperature: 0.3`, paridad C1).

`@plan`, `@build`, `@free-plan`, `@free-build`, `@hybrid-plan` y `@hybrid-build` son orquestadores primarios (`mode: primary`, 6 en total) y el único punto de entrada para asignar trabajo. Los demás son subagentes invocados por delegación explícita (o asignados por nombre en el plan para que el build de la ruta correspondiente los ejecute): ninguno edita código fuera de su dominio sin que el orquestador lo asigne.

### Pares PRO (15) — respaldo de capacidad/calidad (`opencode-go`)

| Agente | Dominio de archivos | Permisos | Modelo |
|---|---|---|---|
| `@frontend-tpl` | `evento.html`, `css/templates/*/*.css` | edit: allow · bash: allow · webfetch: allow | `opencode-go/deepseek-v4.1-flash` |
| `@admin-dev` | `admin.html`, `scanner.html` | edit: allow · bash: allow | `opencode-go/deepseek-v4.1-flash` |
| `@backend-dev` | `api/*.js`, `scripts/*.js` | edit: allow · bash: allow | `opencode-go/deepseek-v4.1-flash` |
| `@sql-security` | `db/migrations/*.sql`, políticas RLS | edit: allow · bash: allow | `opencode-go/deepseek-v4.1-flash` |
| `@architect` | Arquitectura / ADRs | edit: allow · bash: allow | `opencode-go/deepseek-v4.1-flash` |
| `@architect-review` | Segunda opinión de arquitectura / ADRs | edit: allow · bash: allow | `opencode-go/deepseek-v4.1-flash` |
| `@content-loader` | seed + loader + smoke de páginas dinámicas | edit: allow · bash: allow · webfetch: allow | `opencode-go/deepseek-v4.1-flash` |
| `@data-migration` | Migraciones / seeds | edit: allow · bash: allow | `opencode-go/deepseek-v4.1-flash` |
| `@docs-keeper` | PROJECT/NEXT/TASKS/BLUEPRINT/DECISIONS/ERRORES_HISTORICOS | edit: allow · bash: allow | `opencode-go/deepseek-v4.1-flash` |
| `@explore` | Exploración de codebase (solo lectura) | edit: deny (solo lectura, sin bash) | `opencode-go/deepseek-v4.1-flash` |
| `@js-silo-dev` | JS/TS rutinario | edit: allow · bash: allow | `opencode-go/deepseek-v4.1-flash` |
| `@media-reader` | Multimedia (imágenes/audio/video/PDF) | edit: deny · bash: allow · webfetch: allow | `opencode-go/deepseek-v4.1-flash` |
| `@renderer-dev` | `pagina-destino.js`, `vercel.json`, rewrites | edit: allow · bash: allow | `opencode-go/deepseek-v4.1-flash` |
| `@research-agent` | Investigación de destinos | edit: allow · bash: allow · webfetch: allow | `opencode-go/deepseek-v4.1-flash` |
| `@seo-dev` | SEO (sitemap, meta tags, robots, redirects) | edit: allow · bash: allow · webfetch: allow · websearch: allow | `opencode-go/qwen3.8-flash` |

### Pares FREE (15) — operación del día a día (`opencode`)

| Agente | Dominio de archivos | Permisos | Modelo |
|---|---|---|---|
| `@frontend-tpl-free` | `evento.html`, `css/templates/*/*.css` | edit: allow · bash: allow · webfetch: allow | `opencode/big-pickle` |
| `@admin-dev-free` | `admin.html`, `scanner.html` | edit: allow · bash: allow | `opencode/big-pickle` |
| `@backend-dev-free` | `api/*.js`, `scripts/*.js` | edit: allow · bash: allow | `opencode/big-pickle` |
| `@sql-security-free` | `db/migrations/*.sql`, políticas RLS | edit: allow · bash: allow | `opencode/big-pickle` |
| `@architect-free` | Arquitectura / ADRs | edit: allow · bash: allow | `opencode/big-pickle` |
| `@architect-review-free` | Segunda opinión de arquitectura / ADRs | edit: allow · bash: allow | `opencode/big-pickle` |
| `@content-loader-free` | seed + loader + smoke de páginas dinámicas | edit: allow · bash: allow · webfetch: allow | `opencode/big-pickle` |
| `@data-migration-free` | Migraciones / seeds | edit: allow · bash: allow | `opencode/big-pickle` |
| `@docs-keeper-free` | PROJECT/NEXT/TASKS/BLUEPRINT/DECISIONS/ERRORES_HISTORICOS | edit: allow · bash: allow | `opencode/big-pickle` |
| `@explore-free` | Exploración de codebase (solo lectura) | edit: deny (solo lectura, sin bash) | `opencode/big-pickle` |
| `@js-silo-dev-free` | JS/TS rutinario (superset funcional de exp-pickle) | edit: allow · bash: allow · temperature: 0.3 | `opencode/big-pickle` |
| `@media-reader-free` | Multimedia (imágenes/audio/video/PDF) | edit: deny · bash: allow · webfetch: allow | `opencode/mimo-v2.5-free` |
| `@renderer-dev-free` | `pagina-destino.js`, `vercel.json`, rewrites | edit: allow · bash: allow | `opencode/big-pickle` |
| `@research-agent-free` | Investigación de destinos | edit: allow · bash: allow · webfetch: allow | `opencode/big-pickle` |
| `@seo-dev-free` | SEO (sitemap, meta tags, robots, redirects) | edit: allow · bash: allow · webfetch: allow · websearch: allow | `opencode/big-pickle` |

**Excepción de modelo intencional:** `@media-reader-free` usa `opencode/mimo-v2.5-free` (único modelo free con visión real en el catálogo 2026-09-14; `big-pickle` no tiene visión) — NO normalizar a big-pickle.

### Singulares (9)

| Agente | Dominio de archivos | Permisos | Modelo |
|---|---|---|---|
| `@plan` | `TASKS.md`, `NEXT.md`, `DECISIONS.md` (orquestación pro, no implementa) | edit: deny · bash: deny · task: allow · webfetch: allow · websearch: allow | `opencode-go/deepseek-v4.1-flash` |
| `@build` | Implementación de pago (coordina subagentes pro; no usa agentes free) | edit: allow · bash: allow · task: allow · webfetch: allow · websearch: allow | `opencode-go/deepseek-v4.1-flash` |
| `@free-plan` | Plan escrito por dominio (nunca implementa ni invoca subagentes de edición) | edit: deny · bash: ask (requisito del gatekeeper del tier gratuito) · task: allow (solo `@explore-free`/`@research-agent-free`) · webfetch: allow · websearch: allow | `opencode/big-pickle` |
| `@free-build` | Implementación gratuita (coordina subagentes `*-free` y herramientas directas) | edit: allow · bash: allow · task: allow · webfetch: allow · websearch: allow | `opencode/big-pickle` |
| `@hybrid-plan` | Plan híbrido (ruteo PRO/FREE por matriz de riesgo del ADR del esquema tripartito; nunca implementa) | edit: deny · bash: deny · task: allow (solo `@explore-free`/`@research-agent-free`) · webfetch: allow · websearch: allow | `opencode-go/deepseek-v4.1-flash` |
| `@hybrid-build` | Implementación híbrida (delega PRO para riesgo de runtime/criterio y FREE para rutinario) | edit: allow · bash: allow · task: allow · webfetch: allow · websearch: allow | `opencode-go/deepseek-v4.1-flash` |
| `@qa-auditor` | Todo el repositorio (solo lectura, reporta hallazgos con evidencia) | edit: deny · bash: allow · webfetch: allow | `opencode-go/deepseek-v4.1-flash` |
| `@qa-auditor-free` | QA/auditoría gratuita: Escudo GOLD y validaciones (solo reporta, no corrige) | edit: deny · bash: allow · webfetch: allow | `opencode/big-pickle` |
| `@exp-pickle-free` | Soporte mecánico de bajo coste (validaciones, linter, smoke simples, conteos; reporta y soporta, no corrige) | edit: allow · bash: allow · temperature: 0.3 | `opencode/big-pickle` |

## Instalación

1. Colocar `AGENTS.md` en la raíz del repositorio.
2. Colocar los 39 archivos de `.opencode/agent/` en `.opencode/agent/` dentro del repo (mismo nombre de archivo que el campo `name` de cada frontmatter). El universo operativo es `.opencode/`; la carpeta `.agents/` del repo se declara LEGADO (ver ADR-031 Addendum B).
3. Verificar que los modelos referenciados estén habilitados en la cuenta de OpenCode: `big-pickle`, `mimo-v2.5-free` (gateway `opencode`) y `qwen3.8-flash`, `deepseek-v4.1-flash`, `minimax-m3` (gateway `opencode-go`). NOTA: `deepseek-v4-flash` está RETIRADO — no pedir verificación de ese modelo.
4. Antes de la primera tarea delegada, leer la sección "⚠️ Discrepancia conocida" de este archivo — el chequeo de los 21 Átomos contra `evento.html` va a fallar en 12 de 21 hasta que se traiga un Contrato de Datos actualizado.

## Fuentes

- `Sistema QR desarrollo/BLUEPRINT.md` — especificación técnica y matriz de agentes (Sección 4 y 5; ubicado en la subcarpeta `Sistema QR desarrollo/`)
- `Sistema QR desarrollo/Reglas de Oro QR.md` (v128-MASTER) — 18 mandatos incondicionales, framework AI-DOS v1.2 (ver skill `reglas-de-oro`)
- `Sistema QR desarrollo/PROJECT.md` (v1.6.4-FIX) — fuente de verdad estratégica, gobernanza de roles y roadmap (ubicado en la subcarpeta `Sistema QR desarrollo/`)
- `Sistema QR desarrollo/DECISIONS.md` — memoria de ingeniería inamovible (ADR-031: esquema dual pro/free, fusión d2, reglas anti-absorción)
- `Sistema QR desarrollo/ERRORES_HISTORICOS.md` — registro histórico de bugs (nombre real del archivo)
- **`Sistema QR desarrollo/AMPLIACION/TEMPLATES.md` (hub normativo de silos, ADR-046, v1.3.0)** — norma completa para crear/editar/auditar un template de `evento.html`: 10 capítulos + Brief obligatorio + Metodología en 8 pasos + Anexo C (inventario del DOM real ~81 IDs). Leer ANTES de tocar CSS de silo.
- **Skill `.opencode/skills/templates/SKILL.md`** — skill puente que remite al hub; cargar para toda tarea de template/silo (crear, modificar, registrar theme en `admin.html`, auditar cumplimiento normativo). NO usar para CSS de `admin.html`/`scanner.html` ni páginas dinámicas de destino.
