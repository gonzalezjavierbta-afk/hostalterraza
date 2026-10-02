---
doc: TEMPLATES.md — 9
version: v1.7.0 (heredada)
fecha: 2026-10-01
origen: AMPLIACION/TEMPLATES.md L241-259 (AMPLIACION/_backups/TEMPLATES.md.2026-10-01.bak)
version_previa: TEMPLATES.md v1.7.0
relacionados: [../TEMPLATES.md, ../../INDEX.md]
estado: vigente
estructura: detalle-v1 (2026-10-01)
---

> Capítulo de [TEMPLATES.md](../TEMPLATES.md) (hub normativo de silos). Texto original íntegro (L241-259 del original).

## 9. Registro en Admin (Paso 8 OBLIGATORIO)

> **Decisión de Dirección (zanjada):** toda entrega de silo DEBE registrar su theme en `admin.html` como paso final (paso 8 del flujo de creación). Un silo sin registro NO se considera entregado.

Requisitos verificados contra `admin.html` real (ADR-006). **A partir del silo `kande`/f12 (ADR-048, 2026-09-22) el registro completo son 6 puntos** (corrige la version previa que enumeraba 3 y citaba `seleccionarTheme` — el patron vigente es `abrirFichaTheme`):

1. **Tarjeta del theme:** nueva card `.ld-theme-card` con `data-theme="{slug}"` y **`onclick="abrirFichaTheme('{slug}')"`** (patrón real en `admin.html`: `kande` en **L606**, grupo Fiesta tras `fosforescente`; gradiente inline, título y descripción corta). **Toda tarjeta nueva nace VISIBLE por defecto (fail-open)** — el curado (ocultar/reordenar) lo hace la cuenta master vía `config_global` (ADR-040); las tarjetas permanecen en el DOM (Cero Borrado).
2. **Mapa de tipos:** `_THEME_TYPE` (slug → categoria_slug, `admin.html` ≈L2830; `kande`→`fiesta`).
3. **Mapa de plantillas:** `_THEME_TPL` (slug → template_id, `admin.html` ≈L2844; `kande`→`f12`). El derivado `_TPL_THEME` (template_id → slug) sale del `reduce` sobre `_THEME_TPL` (≈L2848-2852) y NO se edita directo.
4. **Preset ADN Visual:** `_THEME_MODULES` (mapa de ADR-047 con `requeridos/recomendados/selectivos/metaDosLineas`, `admin.html` ≈L2858-2879; `kande` en **L2875**; **19 themes** al 2026-09-22). ⚠️ Cuidado de namespacing: los checkboxes `ld-mod-*` dependen de la categoria — `ld-mod-historia`/`ld-mod-objetivo`/`ld-mod-impacto` solo existen en `#mods-campana` (L684), NO en `#mods-fiesta` (L651-665); NO listar un checkbox de campaña en un preset de Fiesta (defecto MAYOR corregido en ADR-048; familia `ERRORES_HISTORICOS.md` §13).
5. **Ficha visual:** `_THEME_FICHA` (`admin.html` ≈L3075+; `kande` en **L3103-3104**: nombre, 5 colores de paleta y descripción corta).
6. **Etiqueta humana:** `names` de `seleccionarTheme()` (`admin.html` ≈L3235; `'kande':'Kande'`).
7. **Fuente de verdad:** `public.config_global` (fila id='default') — orden y visibilidad global (ADR-040).
8. **Validación del Wizard:** si `_evModoPublico !== 'formulario'` y no hay theme seleccionado, el Wizard bloquea el guardado (`alrt('ev-alert', 'Elige una plantilla visual.', 'err')`, ≈L3131).

**ADRs citados:** ADR-040 (catálogo curado por master, con su crítica de alcance: "0 cambios a _THEME_TYPE/_THEME_TPL" en su estado original), ADR-041 (registro de `mistico`, paso 8 de ese silo), ADR-042, ADR-043. **Errores históricos:** §8 (INSERT que no escribía `template_id`/`categoria_slug`), §9/§10 (selectores posicionales y de atributo rotos por reorganización de pestañas).

---

