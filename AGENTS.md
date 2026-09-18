# AGENTS.md — Sistema QR Hostal Terraza (HostalTerraza)

Enrutamiento de agentes para OpenCode. Generado a partir de `Sistema QR desarrollo/BLUEPRINT.md`, `Sistema QR desarrollo/Reglas de Oro QR.md` (v127-MASTER) y `Sistema QR desarrollo/PROJECT.md` (v1.6.4-FIX). Este archivo cierra el punto que la Sección 6 del Blueprint pedía guardar en la raíz pero no incluía, y se reescribe completo el 2026-09-14 para reflejar el estado real verificado del repositorio (34 agentes en `.opencode/agent/`, esquema gratuito como dirección estratégica).

## Decisión estratégica 2026-09-14: esquema GRATUITO como dirección de operación


- **Toda la operación del día a día se ejecuta con subagentes `*-free` + `@free-build`** (modelo `opencode/big-pickle`), con planificación previa de `@free-plan`.
- Los agentes pro (`opencode-go/*`) quedan como **respaldo de capacidad/calidad** y para excepciones de modelo documentadas (`seo-dev` pro, `qa-auditor`, `media-reader-free` con visión).
- Detalle operativo: `frontend-tpl.md` pro usa `deepseek-v4.1-flash` (ver sección "Modelos verificados").

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

## Roster de agentes (34 archivos en `.opencode/agent/`)

Universo: 15 pares pro/free (mismo nombre con sufijo `-free`) + 4 singulares (`plan`, `free-plan`, `free-build`, `qa-auditor`). El agente experimental `exp-pickle` fue **retirado físicamente** (fusión d2 avalada por `architect-review` con condiciones C1/C2/C3 — ver `Sistema QR desarrollo/DECISIONS.md` ADR-031, Addendum A): se eliminó su bloque inline de `opencode.json` (JSON validado correcto), se borró `.opencode/agent/exp-pickle.md` y sus rutas de enrutamiento en `free-build.md`, `free-plan.md` y `plan.md`. `@js-silo-dev-free` es su superset funcional (con `temperature: 0.3`, paridad C1).

`@plan` y `@free-plan` son orquestadores primarios (`mode: primary`) y el único punto de entrada para asignar trabajo. Los demás son subagentes invocados por delegación explícita (o asignados por nombre en el plan para que `@free-build`/subagentes los ejecuten): ninguno edita código fuera de su dominio sin que el orquestador lo asigne.

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
| `@explore` | Exploración de codebase (solo lectura) | solo lectura (sin bloque permission) | `opencode-go/deepseek-v4.1-flash` |
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
| `@explore-free` | Exploración de codebase (solo lectura) | solo lectura (sin bloque permission) | `opencode/big-pickle` |
| `@js-silo-dev-free` | JS/TS rutinario (superset funcional de exp-pickle) | edit: allow · bash: allow · temperature: 0.3 | `opencode/big-pickle` |
| `@media-reader-free` | Multimedia (imágenes/audio/video/PDF) | edit: deny · bash: allow · webfetch: allow | `opencode/mimo-v2.5-free` |
| `@renderer-dev-free` | `pagina-destino.js`, `vercel.json`, rewrites | edit: allow · bash: allow | `opencode/big-pickle` |
| `@research-agent-free` | Investigación de destinos | edit: allow · bash: allow · webfetch: allow | `opencode/big-pickle` |
| `@seo-dev-free` | SEO (sitemap, meta tags, robots, redirects) | edit: allow · bash: allow · webfetch: allow · websearch: allow | `opencode/big-pickle` |

**Excepción de modelo intencional:** `@media-reader-free` usa `opencode/mimo-v2.5-free` (único modelo free con visión real en el catálogo 2026-09-14; `big-pickle` no tiene visión) — NO normalizar a big-pickle.

### Singulares (4)

| Agente | Dominio de archivos | Permisos | Modelo |
|---|---|---|---|
| `@plan` | `TASKS.md`, `NEXT.md`, `DECISIONS.md` (orquestación pro, no implementa) | edit: deny · bash: deny · task: allow · webfetch: allow · websearch: allow | `opencode-go/qwen3.8-flash` |
| `@free-plan` | Plan escrito por dominio (nunca implementa ni invoca subagentes de edición) | edit: deny · bash: deny · task: allow (solo `@explore-free`/`@research-agent-free`) · webfetch: allow · websearch: allow | `opencode/big-pickle` |
| `@free-build` | Implementación gratuita (coordina subagentes `*-free` y herramientas directas) | edit: allow · bash: allow · task: allow · webfetch: allow · websearch: allow | `opencode/big-pickle` |
| `@qa-auditor` | Todo el repositorio (solo lectura, reporta hallazgos con evidencia) | edit: deny · bash: allow · webfetch: allow | `opencode-go/deepseek-v4.1-flash` |

## Reglas anti-absorción (ADR-031)

Cierran el hueco detectado el 2026-09-14: la regla transversal "Participante" del AGENTS.md original y `free-build.md` NO prohíben al agente principal hacer él mismo el trabajo (read/grep/glob/edit directos), lo que causa sesiones de absorción (el principal hace el trabajo del subagente). Aplican al agente principal y a los orquestadores (`@free-build`, `@plan`, `@free-plan` y cualquier agente que coordine subagentes):

1. **Delegación obligatoria antes de tocar:** toda implementación compleja se delega al subagente especializado (`*-free` en esquema gratuito; su par pro como respaldo) ANTES de que el principal toque el archivo. El principal no abre el archivo de la tarea delegada para "ver cómo está" mientras el subagente trabaja.
2. **Regla de No-Duplicidad:** el principal no duplica trabajo ya delegado. Si una tarea fue asignada a un subagente, el principal no la reimplementa, no la "mejora" ni la rehace después.
3. **Prohibido resolver lo delegado:** el principal tiene prohibido usar `read`/`grep`/`glob`/`webfetch`/`websearch` para resolver lo que ya delegó — su contexto es para orquestar, consolidar y decidir, no para operar.
4. **Verificación obligatoria antes de declarar completo:** ninguna tarea se da por "completa" sin el Escudo GOLD (`node --check`, ASCII-safety, balance de divs) o los smokes del proyecto (`npm run test` o smokes específicos) ejecutados sobre el archivo REAL (ADR-006).
5. **Respeto del Escudo GOLD:** en todo archivo de `api/*.js`, `admin.html`, `pagina-destino.js` o `index.html` entregado: sintaxis limpia (`node --check`), ASCII-safety (cero bytes > 127, cero dobles escapes, cero backticks en serverless) y balance de `<div>` en 0.
6. **Cierre con preguntas:** toda sesión de implementación cierra con las preguntas necesarias para completar la tarea de la mejor forma posible — nunca con afirmación de "todo listo" sin evidencia de verificación.
7. **KPIs de delegación medibles (target):** ratio de delegación ≥ 50% en sesiones de implementación; absorciones → 0. Baseline real del mes (2026-09-07): 12081 calls, 92 task (0.76%), 5931 exploración (49.1%), 2126 delegadas, ratio 35.8%, 20 sesiones de absorción de 151. Suma de 5 logs simples: 18784 calls, 158 task (0.84%), ratio 38.6%, 43 sesiones de absorción.
8. **Medidas anti-absorción cuando el principal supera el umbral:** si el contador de llamadas del principal supera **30 llamadas de herramienta directa** (read/grep/glob/edit/webfetch) en una sesión donde existan tareas delegables sin delegar, el principal DEBE detenerse, re-delegar las tareas pendientes y no continuar operando en su contexto.
9. **Auditoría periódica de KPIs:** `@explore-free` audita los KPIs de delegación sobre los logs de uso (`logs/uso/`) y reporta a `@plan`/`@free-plan`; el resultado se registra en `NEXT.md` como parte del ciclo documental (AI-DOS Cap. 9.9).

## Reglas transversales (aplican a los 34 agentes)

1. **Cero Borrado (Reglas de Oro #2):** ningún agente elimina IDs del Contrato de Datos v112, aunque el módulo esté oculto (`display: none`).
2. **Vanilla JS puro (ADR-001):** prohibido Node.js en runtime cliente, React o build tools.
3. **Aislamiento Atómico (Reglas de Oro #9):** CSS de silo encapsulado bajo `.tpl-{template_id}`; nada suelto en `:root` global.
4. **Silent Fallback (ADR-008):** todo `<img>` dinámico lleva `onerror="this.src='path/to/fallback.png';"`.
5. **Prioridad Estructural — Data-First (Reglas de Oro #1):** Fase I (datos/IDs/Supabase, log TRACE positivo) certificada antes de Fase II (estética Afterglow/Geist 900).
6. **Mandato de Actualización Documental (Reglas de Oro #12):** toda actualización de `TASKS.md`/`NEXT.md`/`DECISIONS.md` (dominio de `@plan`/`@free-plan`) se entrega completa e íntegra, sin perder historial.

## Flujo de delegación

```
usuario → @free-plan (esquema gratuito)  ·  @plan (esquema pro, respaldo)
            │
            ├─ plan aprobado
            ↓
        @free-build (@build pro como respaldo)
            │
            ├─ cambio visual/CSS de silo ──────────────→ @frontend-tpl-free
            ├─ admin.html / scanner.html ──────────────→ @admin-dev-free
            ├─ endpoints / lógica QR / tickets ────────→ @backend-dev-free
            ├─ RLS / seguridad de esquema ─────────────→ @sql-security-free
            ├─ JS/TS rutinario ────────────────────────→ @js-silo-dev-free
            ├─ seed+loader+smoke de páginas dinámicas ─→ @content-loader-free
            ├─ migraciones / seeds ────────────────────→ @data-migration-free
            ├─ motor de render (pagina-destino.js) ────→ @renderer-dev-free
            ├─ SEO ────────────────────────────────────→ @seo-dev-free
            ├─ arquitectura / ADR ─────────────────────→ @architect-free (+ @architect-review-free)
            ├─ multimedia ────────────────────────────→ @media-reader-free
            ├─ investigación de destinos ──────────────→ @research-agent-free
            ├─ exploración masiva del repo ────────────→ @explore-free
            ├─ cierre documental ──────────────────────→ @docs-keeper-free
            └─ certificación de una entrega ───────────→ @qa-auditor (solo lectura, reporta a @free-build)
```

El par pro de cada dominio sustituye a su gemelo `*-free` cuando la tarea exige calidad máxima o el modelo free no aplica (p.ej. `@seo-dev`, `@media-reader` con visión).

## Modelos verificados (T8, 2026-09-14) — catálogo vigente

| Modelo | Estado | Uso |
|---|---|---|
| `opencode/big-pickle` | FREE por límite de tiempo; sin tool-calling oficial (stripped) pero empíricamente los subagentes sí editan con él; inestable | 14 agentes `*-free` + `@free-build` + `@free-plan` |
| `opencode/mimo-v2.5-free` | FREE, multimodal, estable | `@media-reader-free` (EXCEPCIÓN: único free con visión) |
| `opencode-go/qwen3.8-flash` | Catálogo Go oficial, $0.15/$0.47, límite $30/mes | `@seo-dev` (EXCEPCIÓN: se mantiene pro, no se unifica con `@seo-dev-free`) y `@plan` (antes `deepseek-v4-flash`, RETIRADO) |
| `opencode-go/deepseek-v4.1-flash` | Nuevo (10-sep-2026), multimodal, supera V4-Pro, $0.15/$0.60 | 14 agentes pro + `@qa-auditor` |
| `opencode-go/deepseek-v4-flash` | RETIRADO por DeepSeek (alias → V4.1) | ya no se usa en ningún agente |
| `opencode-go/minimax-m3` | Válido en catálogo (citado en T8 como "frontend-tpl pro") | Sin uso real: el frontmatter de `frontend-tpl.md` vigente usa `deepseek-v4.1-flash` al 2026-09-14. Documentado como incidencia, no como asignación |

Proveedores: `opencode-go` = gateway suscripción low-cost (https://opencode.ai/zen/go/v1); `opencode` = gateway free Zen. El 2026-09-14 `opencode-go` NO conecta — por eso la operación diaria se ejecuta con subagentes `*-free` + `@free-build`.

## Instalación

1. Colocar este archivo (`AGENTS.md`) en la raíz del repositorio.
2. Colocar los 34 archivos de `.opencode/agent/` en `.opencode/agent/` dentro del repo (mismo nombre de archivo que el campo `name` de cada frontmatter). El universo operativo es `.opencode/`; la carpeta `.agents/` del repo se declara LEGADO (ver ADR-031 Addendum B).
3. Verificar que los modelos referenciados estén habilitados en la cuenta de OpenCode: `big-pickle`, `mimo-v2.5-free` (gateway `opencode`) y `qwen3.8-flash`, `deepseek-v4.1-flash`, `minimax-m3` (gateway `opencode-go`). NOTA: `deepseek-v4-flash` está RETIRADO — no pedir verificación de ese modelo.
4. Antes de la primera tarea delegada, leer la sección "⚠️ Discrepancia conocida" de arriba — el chequeo de los 21 Átomos contra `evento.html` va a fallar en 12 de 21 hasta que se traiga un Contrato de Datos actualizado.

## Fuentes

- `Sistema QR desarrollo/BLUEPRINT.md` — especificación técnica y matriz de agentes (Sección 4 y 5; ubicado en la subcarpeta `Sistema QR desarrollo/`)
- `Sistema QR desarrollo/Reglas de Oro QR.md` (v127-MASTER) — 16 mandatos incondicionales, framework AI-DOS v1.2 (ubicado en la subcarpeta `Sistema QR desarrollo/`)
- `Sistema QR desarrollo/PROJECT.md` (v1.6.4-FIX) — fuente de verdad estratégica, gobernanza de roles y roadmap (ubicado en la subcarpeta `Sistema QR desarrollo/`)
- `Sistema QR desarrollo/DECISIONS.md` — memoria de ingeniería inamovible (ADR-031: esquema dual pro/free, fusión d2, reglas anti-absorción)
- `Sistema QR desarrollo/ERRORES_HISTORICOS.md` — registro histórico de bugs (nombre real del archivo)
- **`Sistema QR desarrollo/AMPLIACION/TEMPLATES.md` (hub normativo de silos, ADR-046, v1.3.0)** — norma completa para crear/editar/auditar un template de `evento.html`: 10 capítulos + Brief obligatorio + Metodología en 8 pasos + Anexo C (inventario del DOM real ~81 IDs). Leer ANTES de tocar CSS de silo.
- **Skill `.opencode/skills/templates/SKILL.md`** — skill puente que remite al hub; cargar para toda tarea de template/silo (crear, modificar, registrar theme en `admin.html`, auditar cumplimiento normativo). NO usar para CSS de `admin.html`/`scanner.html` ni páginas dinámicas de destino.