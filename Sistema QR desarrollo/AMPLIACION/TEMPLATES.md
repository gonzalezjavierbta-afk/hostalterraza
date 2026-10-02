---
doc: TEMPLATES.md
version: v1.7.0 (preservada)
fecha: 2026-10-01
origen: AMPLIACION/TEMPLATES.md L1-503 (AMPLIACION/_backups/TEMPLATES.md.2026-10-01.bak)
version_previa: TEMPLATES.md v1.7.0 (503 líneas, 57 KB)
relacionados: [../INDEX.md, templates/, ../PROJECT.md]
estado: vigente
estructura: indice-v1 (2026-10-01)
---

# 🎨 TEMPLATES.md — Hub Normativo de Silos Visuales (evento.html)

| Campo | Valor |
|---|---|
| **Versión** | v1.7.0 |
| **Propósito** | Hub normativo de silos CSS de `evento.html` (motor real: `evento-app.html`, ver banner de reconciliacion abajo): inventario real del DOM, metodologia de creacion en 8 pasos y brief obligatorio - para que cualquier IA cree, edite o audite un template de forma reproducible. |
| **Fecha** | 2026-09-16 (v1.3.0) · **2026-09-22 (v1.4.0)** · **2026-09-23 (v1.5.0, salvaguarda hero movil f12)** · **2026-09-26 (v1.6.0, silo f9b + aviso capital-T + contrato de preview)** · **2026-09-29 (v1.7.0, excepción acotada ADR-060 + f9b v1.3.0 — ver Anexo A)** |
| **Audiencia** | `@frontend-tpl-free`, `@frontend-tpl`, `@free-build`, `@admin-dev-free`, `@docs-keeper-free`, `@qa-auditor` |
| **Marco** | MOTHER, AI-DOS v1.2, 16 Mandatos de `Reglas de Oro QR.md` (v127-MASTER) |
| **Baseline de verdad** | Archivos REALES del repositorio (ADR-006). Ningún dato citado aquí se dio por supuesto; todo se verificó contra `evento-app.html` (motor real, reconciliado 2026-09-22), `css/templates/**`, `admin.html` y los docs del Dossier. |
| **Estado** | ACTIVE |

---

> ## ⚠️ RECONCILIACION ESTRUCTURAL (2026-09-22, ADR-006 / ADR-048) — `evento.html` NO existe como archivo
>
> El archivo **`evento.html` NO existe** en el repositorio (`Test-Path` = False). El **motor publico real es `evento-app.html`** (1724 lineas, titulo "Master Orchestrator v214"): `vercel.json` reescribe la ruta `/evento.html` hacia `/api/evento-og.js`, y ese endpoint sirve `evento-app.html`. Evidencia verificada en `evento-app.html` real: `injectAtomicCSS(cat, tplId)` **L598-638** construye `css/templates/{categoria}/{template_id}.css?v=${Date.now()}` (L600-601) y **L691-693** aplica la doble clase `tpl-{template_id}` + `tpl-{lowercase}` al `body`.
>
> **Otros hechos del kernel real verificados (ADR-006):**
> - `#db-gallery-grid` (L148) esta **DENTRO** de `#mod-video` (L147) — apagar `#mod-video` oculta tambien la galeria.
> - `#mod-hero-ctas` nace con `display:none !important` (L33) y exige encendido explicito via CSS del silo.
> - NO existe override `?tpl=`/`?cat=` en el kernel real (solo existe en `evento2.html`, legado).
> - El array `MODULE_IDS` **ya no existe** en el kernel v214 (0 ocurrencias case-sensitive; solo en legados).
>
> **Politica documental:** todas las citas a `evento.html` como archivo/unico motor que existen en este documento (y en `PROJECT.md`, `BLUEPRINT.md`, `AGENTS.md`, hitos de `NEXT.md`, TSK-016/017/018) se conservan **intactas (Cero Borrado)** y se interpretan desde aqui como el link publico `/evento.html` reescrito por Vercel hacia el motor real `evento-app.html`. Ver `DECISIONS.md` **ADR-048** (Seccion Hallazgo estructural) y `PROJECT.md` Seccion 6.

---

> ## ⚠️ AVISO NORMATIVO NUEVO (2026-09-26, `@docs-keeper` / ADR-057) — La mitad `.Tpl-*` es CODIGO MUERTO en produccion
>
> **Hecho verificado (ADR-006):** el kernel real **NUNCA emite `Tpl-`**. Escribe en `document.body` SIEMPRE `tpl-` + `template_id` tal cual + su version en minuscula (**`evento-app.html:998-1000`**: `const tplNormal = \`tpl-${ev.template_id || 'F3'}\`; const tplLower = \`tpl-${(ev.template_id || 'f3').toLowerCase()}\`; document.body.className = \`${tplNormal} ${tplLower}\``). Con `template_id='f9b'` el body queda **`tpl-f9b tpl-f9b`** (ambas clases identicas); con `template_id='Mistico'` quedaria `tpl-Mistico tpl-mistico`. La unica coincidencia case-sensitive de `Tpl-` en `evento-app.html` es **un comentario** (`:760`).
>
> **Consecuencia para TODOS los silos (no solo f9b):** la mitad `.Tpl-{id}` de cada silo **no aplica nunca** en produccion. La convencion de doble notacion `.tpl-{id}` + `.Tpl-{id}` (Cap. 8 punto 3) **se mantiene como norma por Cero Borrado** (no se retira texto), pero **se anexa este aviso**: los silos nuevos **NO deben duplicar la mitad `.Tpl-*` a ciegas** hasta que el ADR-057 se resuelva. Ejemplo medido: `f9b.css` (2922 lineas) tiene **369 `.tpl-f9b` (vivos) + 365 `.Tpl-F9b` (muertos)**; el silo se sostiene **solo** por la mitad minuscula.
>
> **Decision de Direccion (ADR-057, 2026-09-26):** (1) **el preview se alineo a produccion** (el adaptador `?preview=1` pasa el `template_id` sin capitalizar; `preview == produccion`); (2) la **correccion global** (eliminar la mitad muerta de los silos **o** cambiar el kernel a `Tpl-` canonico) **se difiere a una tarea propia con regresion de 7 silos** y queda **ABIERTA** con sus dos opciones y su riesgo. Ver `DECISIONS.md` **ADR-057** y `TASKS.md` (tarea de correccion global).
>
> **Regla para agentes:** al auditar o crear un silo, (a) NO reportar como "selector muerto" la mitad `.Tpl-*` (es una deuda conocida, no un defecto del silo); (b) NUNCA borrar la mitad `.tpl-*` (es la unica viva); (c) no confiar en que la doble notacion garantiza cobertura — verificar con `grep` que exista la mitad minuscula para cada selector.

---

---


> **Este hub es ahora un ÍNDICE por capítulos** (mismo patrón que DECISIONS/ERRORES). Los números de capítulo se conservan: "Cap. 5" = `templates/cap-05-*.md`.

| Cap. | Título | Archivo | Líneas en el original |
|---|---|---|---|
| 0 | Cómo usar este documento | [cap-00-como-usar-este-documento.md](templates/cap-00-como-usar-este-documento.md) | L43-50 |
| 1 | Principios Innegociables (DATOS) | [cap-01-principios-innegociables-datos.md](templates/cap-01-principios-innegociables-datos.md) | L51-70 |
| 2 | Contrato de Datos v112 y la Realidad del DOM (21 Átomos vs 81 IDs) | [cap-02-contrato-de-datos-v112-y-la-realidad.md](templates/cap-02-contrato-de-datos-v112-y-la-realidad.md) | L71-90 |
| 3 | Estructura del Silo (8 Pilares Técnicos) | [cap-03-estructura-del-silo-8-pilares-tecnicos.md](templates/cap-03-estructura-del-silo-8-pilares-tecnicos.md) | L91-113 |
| 4 | Arquitectura Molecular (Átomos de UI del Silo) | [cap-04-arquitectura-molecular-atomos-de-ui-del.md](templates/cap-04-arquitectura-molecular-atomos-de-ui-del.md) | L114-138 |
| 5 | Breakpoints y Rejilla (Ley de Cortes) | [cap-05-breakpoints-y-rejilla-ley-de-cortes.md](templates/cap-05-breakpoints-y-rejilla-ley-de-cortes.md) | L139-161 |
| 6 | Módulos Funcionales (Núcleo Mínimo Encendido) | [cap-06-modulos-funcionales-nucleo-minimo.md](templates/cap-06-modulos-funcionales-nucleo-minimo.md) | L162-180 |
| 7 | El Silo CSS como Unidad de Trabajo | [cap-07-el-silo-css-como-unidad-de-trabajo.md](templates/cap-07-el-silo-css-como-unidad-de-trabajo.md) | L181-207 |
| 8 | Inyección y Puente Cromático (Cómo se Monta el Silo) | [cap-08-inyeccion-y-puente-cromatico-como-se.md](templates/cap-08-inyeccion-y-puente-cromatico-como-se.md) | L208-240 |
| 9 | Registro en Admin (Paso 8 OBLIGATORIO) | [cap-09-registro-en-admin-paso-8-obligatorio.md](templates/cap-09-registro-en-admin-paso-8-obligatorio.md) | L241-259 |
| 9-bis | Brief Obligatorio Antes de Escribir CSS | [cap-9-bis-brief-obligatorio-antes-de-escribir-css.md](templates/cap-9-bis-brief-obligatorio-antes-de-escribir-css.md) | L260-276 |
| 9-ter | Metodología de Creación de un Template (8 Pasos) | [cap-9-ter-metodologia-de-creacion-de-un-template.md](templates/cap-9-ter-metodologia-de-creacion-de-un-template.md) | L277-306 |
| 10 | Verificación, Versionado y Cierre Documental (CHECKLIST de Aceptación) | [cap-10-verificacion-versionado-y-cierre.md](templates/cap-10-verificacion-versionado-y-cierre.md) | L307-337 |
| Anexo A | Registro de Versiones (del propio documento) | [anexo-a-registro-de-versiones-del-propio.md](templates/anexo-a-registro-de-versiones-del-propio.md) | L338-351 |
| Anexo B | Mapa de Referencia Rápida | [anexo-b-mapa-de-referencia-rapida.md](templates/anexo-b-mapa-de-referencia-rapida.md) | L352-373 |
| Anexo C | Inventario del DOM Real de evento.html (~81 IDs) | [anexo-c-inventario-del-dom-real-de-evento-html.md](templates/anexo-c-inventario-del-dom-real-de-evento-html.md) | L374-503 |
