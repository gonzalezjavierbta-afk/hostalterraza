---
doc: ADR-042
version: v1.16-GOLD (heredada de DECISIONS.md)
fecha: 2026-10-01
origen: DECISIONS.md L627-651 (AMPLIACION/_backups/DECISIONS.md.2026-10-01.bak)
version_previa: DECISIONS.md v1.16-GOLD
relacionados: [../DECISIONS.md, ../INDEX.md]
estado: vigente (ver campo Estado dentro del ADR)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [DECISIONS.md](../DECISIONS.md) · [INDEX](../INDEX.md). Texto original íntegro debajo (L627-651 del original).

#### ADR-042: Silo F10 "Rico" (Cyberpunk Fosforescente) - Reescritura Total v2.0.0 Solo-CSS sobre Selectores Kernel Reales
* **ID:** ADR-042 | **Fecha:** 15 de septiembre de 2026 | **Estado:** Aprobado y entregado. Working tree con UN SOLO archivo modificado (`css/templates/fiesta/f10.css` v2.0.0); evento `rico-5mw5` en produccion (template f10, categoria fiesta - dato de Supabase, fuera del repo). Escudo GOLD PASS (ASCII-safety 0 bytes > 127 verificado por escaneo de bytes, cero selectores muertos, balance de llaves, Cero Borrado, Aislamiento Atomico bajo `.tpl-f10`/`.Tpl-F10`). Cierre documental ASCII-safe; la fila v2.0.0 del log de versiones del propio silo fue actualizada en este mismo cierre (ambito documental).
* **Autor:** Documentation Specialist / `@docs-keeper-free` (el silo v2.0.0 fue implementado por el equipo frontend `*-free`; este ADR es cierre documental: 0 cambios de codigo fuera del log de versiones del pie de `f10.css`).
* **Problema:** El evento `rico-5mw5` (theme "Rico", Cyberpunk Fosforescente, template f10, categoria fiesta) estaba en produccion con un silo v1.0.0 que estilizaba el lineup sobre selectores PROPIETARIOS (`.f10-lc-grid`, `.f10-artist*`, `.f10-lc-*`) que el kernel de `evento.html` JAMAS genera: el DOM real usa `.artist-card`, `.artist-photo`, `.artist-overlay`, `.artist-name`, `.artist-hora`, `.artist-resena`, `.artist-social`, `.artist-social-icon` y `.artist-card.headliner` (mismos selectores kernel que f8/f9). Resultado: lineup sin estilos reales (bug visual) y selectores muertos. Ademas, la galeria `#db-gallery-grid` estaba disenada para un numero fijo de bloques (nth-child ciclico) y no soportaba un N abierto de espacios.
* **Diagnostico verificado (contra el archivo real del repositorio, ADR-006 - no contra documentacion previa):**
   1. **`css/templates/fiesta/f10.css` real (1801 lineas de contenido, 0 bytes > 127):** cabecera v2.0.0 (2026-09-15) en el bloque de cabecera; todo el silo bajo `.tpl-f10`/`.Tpl-F10`; bloque IoC de activacion/off de modulos preservado intacto; lineup estilado sobre `.artist-card`, `.artist-photo`, `.artist-overlay`, `.artist-name`, `.artist-hora`, `.artist-resena` (line-clamp 2), `.artist-social`, `.artist-social-icon`, `.artist-social a`, `.artist-card.headliner`; galeria `#db-gallery-grid` con grid de N abierto `repeat(auto-fill, minmax(...))`; breakpoints reales 640/767/768/992/1279; log de versiones al final con v1.0.0 + v2.0.0 (este ADR expande la fila v2.0.0 a la descripcion canonica).
   2. **`evento.html` real:** linea 600 inyecta `css/templates/${categoria}/${template_id}.css` y las lineas 692-693 aplican `tpl-${template_id}` al body - el silo f10 no requiere registro en `admin.html` para renderizar; basta `template_id='f10'` en el evento de Supabase.
   3. **`admin.html` real:** `_THEME_TYPE` (linea 2779) y `_THEME_TPL` (linea 2792) NO registran todavia el theme `rico` -> `f10` (el mapa llega hasta `mistico` -> `f9`, linea 2797). El silo f10 es utilizable hoy via `template_id` directo; el registro del theme es pendiente opcional.
   4. **Repo:** `rico-5mw5` no aparece como string en el repositorio (dato de produccion/Supabase, no versionado); se toma como declarado por el usuario y no verificable en el working tree.
* **Decision (entregable real, verificado archivo por archivo):**
   1. **Unico archivo tocado:** `css/templates/fiesta/f10.css` -> v2.0.0 (reescritura total solo-CSS). Cualquier otro archivo del repositorio permanece intacto.
   2. **Lineup sobre selectores kernel reales:** `.artist-card*` (incluye `.artist-card.headliner`), `.artist-photo`, `.artist-overlay`, `.artist-name`, `.artist-hora`, `.artist-resena` (estilado minimo line-clamp 2, antes hidden), `.artist-social`, `.artist-social-icon`, `.artist-social a`.
   3. **Cero selectores muertos:** se retiran `.f10-artist*` / `.f10-lc-*` (Cero Borrado verificado: exclusivos de f10, el kernel JAMAS los genera).
   4. **Galeria maqueta de N abierto:** `#db-gallery-grid` como grid fluido `repeat(auto-fill, minmax(...))` con placeholders glow (celda `figure` con marco fosforescente + gradiente neon visible aunque falte la foto - Silent Fallback ADR-008) y tinte hover ciclico por celda.
   5. **ASCII-safety estricto:** 0 bytes > 127 en todo el archivo (verificado por escaneo de bytes).
   6. **IoC conservada:** bloque de activacion de modulos intacto; `prefers-reduced-motion` conservado; tipografia Geist 900 display (cargada por el kernel, sin `@import` bloqueante).
* **QA ejecutado (Escudo GOLD):** PASS - ASCII-safety (0 bytes > 127 sobre el archivo real), balance de llaves y comentarios en equilibrio, cero selectores muertos (todos apuntan a clases/ids reales del DOM de `evento.html`), Cero Borrado (ningun modulo/ID del kernel retirado), Aislamiento Atomico (todo bajo `.tpl-f10`/`.Tpl-F10`), breakpoints reales 640/767/768/992/1279, lineas 1801 verificadas al cierre documental. Los archivos de codigo NO fueron modificados por este cierre (solo el log de versiones del pie de `f10.css`, que es ambito documental de `@docs-keeper-free`).
* **Impacto:** **1 archivo de codigo tocado** en el working tree (`css/templates/fiesta/f10.css` v2.0.0), **0 migraciones SQL**, **0 cambios de esquema**, **0 endpoints**, **0 cambios a `evento.html`/`admin.html`**. En produccion el silo se carga y aplica por `template_id='f10'` (kernel de `evento.html`). El theme `rico` nace sin card en el Wizard hasta su registro opcional (mismo estado que tenia `mistico` antes de ADR-041).
* **Pendientes (no ejecutados):**
   1. Commit de la entrega por Direccion (working tree modificado, sin commit).
   2. Registro opcional del theme `rico` en `admin.html` (`_THEME_TYPE['rico']='fiesta'`, `_THEME_TPL['rico']='f10'`, card + label en el Wizard) si Direccion quiere crear/editar eventos f10 por el Wizard - paralelo al registro de `mistico` hecho en ADR-041.
   3. Verificacion visual (Prueba de Carga Dual) por Direccion sobre `https://hostalterraza.vercel.app/evento.html?slug=rico-5mw5`.
   4. Cargar fotos de artistas en `config_landing.content.dj_lineup` (pendiente heredado tambien de F9) para aprovechar `.artist-photo`.
* **Referencias:** `.opencode/plans/template-f10-rico.md` (plan del silo), ADR-041 (patron de cierre de silo y registro de theme `mistico`->`f9`), ADR-006 (baseline de verdad contra el archivo real y nomenclatura atomica por silos), ADR-008 (Silent Fallback en galeria sin foto), ADR-031 (reglas anti-absorcion; este cierre es documental puro), `ERRORES_HISTORICOS.md` Seccion 5 (leccion de selectores fantasma aplicada en v2.0.0), `AGENTS.md` (roster de agentes).

