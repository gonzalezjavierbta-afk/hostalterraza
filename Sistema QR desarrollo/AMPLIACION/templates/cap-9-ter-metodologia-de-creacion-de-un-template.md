---
doc: TEMPLATES.md — 9-ter
version: v1.7.0 (heredada)
fecha: 2026-10-01
origen: AMPLIACION/TEMPLATES.md L277-306 (AMPLIACION/_backups/TEMPLATES.md.2026-10-01.bak)
version_previa: TEMPLATES.md v1.7.0
relacionados: [../TEMPLATES.md, ../../INDEX.md]
estado: vigente
estructura: detalle-v1 (2026-10-01)
---

> Capítulo de [TEMPLATES.md](../TEMPLATES.md) (hub normativo de silos). Texto original íntegro (L277-306 del original).

## 9-ter. Metodología de Creación de un Template (8 Pasos)

> **Decisión de Dirección (zanjada):** este es el flujo OBLIGATORIO de creación. Cualquier IA puede seguirlo de principio a fin sin historial previo. Cada paso cierra antes de abrir el siguiente.

**Paso 1 — Diagnóstico del DOM real.**
Abrir `evento.html` y con `grep` listar: (a) los módulos `#mod-*` que el silo va a estilizar (IDs reales del **Anexo C**), y (b) las clases que el JS kernel genera (lineup, galería, boletos, form, etc. — misma fuente del Anexo C). Preparar la lista de trabajo: **encender / apagar / estilizar**. ⚠️ NUNCA usar el BLUEPRINT como mapa: el DOM real es v214+/v222 (~81 IDs), el BLUEPRINT describe v112 (21 átomos). Si un selector no se confirma con grep, se generaliza a `~Lxx` o se consulta al Plan.

**Paso 2 — Brief + tokens + paleta.**
Responder el **Brief Obligatorio** (Cap. 9-bis). Decidir paleta: derivada de `--master-accent` (por defecto) o fija (excepción justificada en cabecera). Nombrar tokens del silo `--fXX-*` (nunca `:root` global — Mandato 9). Verificar contraste WCAG AA **≥ 4.5:1** de cada color de texto sobre su fondo (Mandato 13).

**Paso 3 — Reset scoped + puente cromático.**
Bloque raíz `.tpl-fXX, .Tpl-FXX` con: `--tpl-accent: var(--master-accent, #fallback)`, token `--gold` si aplica, fondo/color/fuente base, y `box-sizing: border-box !important` a los descendientes (`*`, `*::before`, `*::after`). **Prohibido:** `@import` de fuentes y variables en `:root` global.

**Paso 4 — Activación atómica.**
Bloques `display: flex/block !important` para los módulos encendidos y `display: none !important` para los apagados. Los IDs permanecen **intactos** en el HTML (Cero Borrado — Mandato 2): el kernel IoC (`display:none` inicial en `section, header, footer`) se vence SOLO vía el CSS del silo.

**Paso 5 — Grid + secciones en orden DOM.**
`display: grid` en `#main-content-flow` + `grid-template-areas` (Mandato 10); asignar `grid-area` a cada módulo hermano (los `#mod-*` son hermanos planos del main). Estilizar sección por sección siguiendo el ORDEN del DOM real (Anexo C, bloque A → G). Agregar Reflow: `:has([data-hidden])` para los módulos que el kernel puede ocultar en runtime.

**Paso 6 — Breakpoints + reduced-motion.**
Mobile-first con los cortes normativos: **640 / 767 / 992 / 1279** (768 solo para `:has()`, 480 opcional — Cap. 5). Incluir **obligatoriamente** `@media (prefers-reduced-motion: reduce)` neutralizando animaciones.

**Paso 7 — Escudo GOLD del silo.**
Ejecutar el **checklist de aceptación (10/10)** del Cap. 10 sobre el archivo real. Si un punto falla: corregir y re-ejecutar; no continuar al paso 8 con fallos abiertos.

**Paso 8 — Registro del theme en admin (6 puntos, patrón `abrirFichaTheme`).**
Los **6 puntos reales** del registro (corrección mayor 2026-09-22, ADR-048; el patrón previo citado `seleccionarTheme` con 3 puntos era el de la versión 1.3.0 y quedó superado): (1) tarjeta `.ld-theme-card[data-theme="{slug}"]` con **`onclick="abrirFichaTheme('{slug}')"`** (`admin.html` L606 para `kande`); (2) alta en `_THEME_TYPE` (slug → categoria_slug, ≈L2830); (3) alta en `_THEME_TPL` (slug → template_id, ≈L2844; el derivado `_TPL_THEME` sale del `reduce`, NO se edita directo); (4) preset `_THEME_MODULES` `requeridos/recomendados/selectivos/metaDosLineas` (ADR-047, ≈L2858-2879) — ⚠️ respetar el namespacing por categoria de los checkboxes `ld-mod-*` (defecto MAYOR de ADR-048: `ld-mod-historia` solo existe en `#mods-campana` L684, jamás en un preset de Fiesta; `#mods-fiesta` L651-665); (5) ficha `_THEME_FICHA` (≈L3075+; `kande` L3103-3104); (6) etiqueta en `names` de `seleccionarTheme()` (≈L3235). Detalle completo en Cap. 9. La tarjeta **nace visible** (fail-open); el curado (ocultar/reordenar) es prerrogativa de la cuenta master vía `config_global` (ADR-040). Sin este paso el silo NO está entregado.

---

