---
doc: ADR-080
version: v1.17-GOLD (heredada de DECISIONS.md)
fecha: 2026-10-07
origen: FASE 0 de la feature "paleta de color de evento". Contrato JSONB de config_landing.colors (5 slots) y regla de compatibilidad con eventos.color_primario.
version_previa: ADR-079
relacionados: [../DECISIONS.md, ../INDEX.md, ADR-064-diseno-de-ticket-por-tipo-de-asistente.md, ADR-021-wizard-inteligente-de-creacion-de-eventos-4.md, ADR-047-contratos-de-configuracion-del-wizard-y-el.md, ADR-006-nomenclatura-atomica-por-categorias-silos.md]
estado: IMPLEMENTADO (Fases 0-I-II, 2026-10-07; Fase 2 de consumo en silos = deuda tecnica opcional)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [DECISIONS.md](../DECISIONS.md) - [INDEX](../INDEX.md).

## ADR-080: Paleta de color de evento (`eventos.config_landing.colors` de 5 slots)

**Fecha:** 2026-10-07

**Autor:** Chief Architect (`@architect`). Direccion de producto fijo las decisiones cerradas (render minimo; motor HSL puro sin TinyColor). **Solo el Wizard migra; el modal `#mod-edit-ev` esta retirado (ADR-006).** Implementacion de Fase 1 reservada a `@admin-dev`.

**Estado:** **DECIDIDO -> IMPLEMENTADO (Fases 0-I-II, 2026-10-07).** Contrato de datos congelado y ejecutado en `admin.html` (Wizard, creacion + edicion): 5 slots nombrados, motor HSL puro, TinyColor2 retirado, invariante `color_primario === colors.accent` y smoke `scripts/smoke_paleta_evento.js` 20 PASS / 0 FAIL. 0 DDL, 0 endpoints, 0 RLS, 0 cambios en `api/*.js`. **Deuda tecnica declarada (Decision 5):** los 4 slots derivados se persisten pero NO se consumen aun (Fase 2, amendment futuro). 0 cambios en `evento-app.html` y `css/templates/*`. **Correccion ADR-006 (baseline = archivo real):** la implementacion NO retiro `syncColor` como planeaba el Anexo; conservo la funcion y la reescribio para 5 slots (`syncColor(hex, slot)`, `admin.html:11335`). Solo se retiro el CDN TinyColor2 y `renderColorHarmony` (0 referencias `tinycolor`/`TinyColor`).

**Problema / Contexto (verificado contra el archivo real, ADR-006):**
1. El color del evento es hoy UN solo valor. En `admin.html` se captura en el Paso 1b con `#ev-color` (type=color), `#ev-color-hex` y `#ev-color-harmony` (`admin.html:888-895`); las harmonias las genera TinyColor2 (`renderColorHarmony`, `admin.html:3900-3915`; `syncColor`, `admin.html:11170-11175`; CDN en `admin.html:2781-2783`).
2. El unico campo cromatico que se persiste es `config_landing.colors.accent` (`_buildConfigLanding`, `admin.html:4704`: `colors: { accent: val('ev-color-hex') || '#c8a96e' }`). El barrido de nulos (`admin.html:4868`) itera SOLO `Object.keys(cfg.content)` y borra los `=== null`; **NO toca `cfg.colors`** (ver Decision 1).
3. La columna canonica del evento es `eventos.color_primario` (`guardarEventoWizard` `:6438`; `_crearEventoUnico` `:7743`). El kernel publico la lee en `evento-app.html:1121` (`ev.color_primario || content.color_primario || content.accent_color`) e inyecta `--master-accent` (`:1123`); los silos la consumen por el puente `--tpl-accent: var(--master-accent, #fallback)`.
3b. **CORRECCION ADR-006 (el brief de Fase 0 traia una premisa vieja):** el "modal de edicion" `#mod-edit-ev` (`:2529`) esta **RETIRADO**: el comentario `:5730` dice "se conserva en el DOM por Cero Borrado pero **deja de abrirse**", y `guardarEdicionEvento` (`:6524`) solo es invocado por el boton interno de ese modal (`:2600`), que nunca se abre. En consecuencia, **el unico camino de edicion real es el Wizard** (`openEditMod`, `:5747` -> `#ev-color`/`#ev-color-hex` `:5758-5760` -> `guardarEventoWizard` `:6407`). La decision cerrada "wizard + modal a 5 slots" se reduce, contra el archivo real, a **migrar el Wizard**; tocar el modal muerto seria trabajo sin consumidor.
4. **No existe** en el repo ninguna variable `--color-secundario/terciario/cuarto/bg-dominante/primario`, ni bridge `--master-secondary`/`--master-surface`/`--master-background`. Hoy solo `accent` pinta.
5. **Riesgo estructural ya conocido (clase BUG-016, ADR-064 Decision 4):** `config_landing` se escribe por **OVERWRITE TOTAL** (`payload.config_landing = cfgLanding || null`, `admin.html:6463`; INSERT en `:7758`). `_buildConfigLanding` reconstruye `content` desde un literal de campos conocidos. Toda clave que no se agregue al literal se pierde en silencio al re-guardar. (Ver Contexto 3b: el modal `guardarEdicionEvento` es codigo huerfano, no un camino de escritura.)
6. **Consumidor LEGACY de `config_landing.colors.accent`:** `eventobackup.html:4691` (`if (cfg.colors?.accent) { root.style.setProperty('--gold', ...); root.style.setProperty('--ld-accent', ...); }`) y sus multiples usos de `--ld-accent` en `:5000-5769`. Consume **solo `colors.accent` como string**; **queda EXCLUIDO del alcance de Fase 1** y NO se toca. Como `accent` sigue siendo `string`, no se rompe.

**Opciones:**
- (A) Columnas nuevas en `eventos` (`color_secondary`, `color_tertiary`...): DDL + migracion + RLS. 8/8 funciones Vercel agotadas; no se justifica por 4 valores de render. **RECHAZADA.**
- (B) Tabla aparte `eventos_paletas`: normaliza, pero agrega DDL, RLS y joins por una config de 5 entradas. **RECHAZADA.**
- (C) Extender el JSONB `config_landing.colors` dentro del objeto **ya existente** (patron ADR-064). Cero DDL, cero RLS, cero endpoints, cero migracion. **ELEGIDA.**
- (D) Contrato propuesto inicial con `palette:[5]` **ademas** de las 5 claves nombradas: dos fuentes de verdad para el mismo dato (drift garantizado) sin ningun consumidor que itere por indice. **RECHAZADA** (ver Decision 1).

**Decision:**

1. **Forma EXACTA y congelada de `config_landing.colors`** (5 slots nombrados, NO array):
   ```json
   "colors": {
     "accent":     "#c9a84c",
     "secondary":  "#a8842f",
     "tertiary":   "#4c8ac9",
     "surface":    "#1a1712",
     "background": "#0f0d0a"
   }
   ```
   - Las 5 claves son `string` hex `#rrggbb`. **`accent` es la unica obligatoria** (default vigente `#c9a84c`). Las otras 4 son derivadas y opcionales.
   - **Se escribe la clave siempre, nunca `null`.** La razon es la **estabilidad de forma del JSONB y de sus consumidores**, NO el barrido: el sweep de `admin.html:4868` itera SOLO `Object.keys(cfg.content)` y **NO toca `cfg.colors`**, asi que nunca borraria un color. Se persisten siempre las 5 claves para que todo consumidor (hoy `accent`; en Fase 2 los 4 derivados) encuentre una forma estable y no un conjunto variable de claves.
   - **NO se agrega `palette:[5]`.** Ajuste sobre el contrato propuesto: las claves nombradas mapean 1:1 a los 5 slots de la UI y evitan un espejo redundante. Si en Fase 2 hace falta iterar por indice para emitir `--palette-0..4`, se emite en runtime (derivado de las 5 claves), no se persiste dos veces.
2. **Regla de compatibilidad con `eventos.color_primario` (no se toca la columna):** en TODO guardado real (hoy solo el Wizard: creacion `_crearEventoUnico` y edicion `guardarEventoWizard`) se cumple `eventos.color_primario = colors.accent`. La columna sigue siendo el dato canonico que lee `evento-app.html:1121`, de modo que **la Fase 1 NO modifica `evento-app.html`**: `--master-accent` se sigue pintando con 0 cambios en el kernel publico. (El modal muerto `#mod-edit-ev`/`guardarEdicionEvento` no participa; ver Contexto 3b.)
3. **Motor cromatico en HSL puro.** Se retira TinyColor2 y `renderColorHarmony` (supera el mecanismo de armonias de ADR-021). Los 4 slots derivados se calculan en Vanilla JS sobre el HSL de `accent`. Sin dependencias nuevas, sin `eval`/`new Function` (compatible con la CSP de Vercel).
4. **Render minimo (Fase 1).** Solo `accent` pinta (via `color_primario` -> `--master-accent`). `secondary`, `tertiary`, `surface`, `background` **se persisten pero NO se consumen aun** (deuda tecnica planificada, Decision 5).
5. **Deuda tecnica formalizada: los 4 slots no consumidos.** Quedan escritos y disponibles en el JSONB; ningun CSS los lee hoy. Cerrarla exige un ADR de amendment que defina los bridges `--master-secondary/tertiary/surface/background` y su `--tpl-*`, mas la inyeccion en `evento-app.html`. Hasta entonces consumirlos seria un puente sin fuente.

**Justificacion:**
1. **El dato ya vive en un JSONB gobernado por el Wizard** (patron ADR-064); extender `colors` es aditivo y no toca esquema ni presupuesto de Vercel (8/8 funciones agotadas).
2. **Compatibilidad por construccion:** atar `color_primario = accent` mantiene el unico consumidor real (`--master-accent`) intacto; el rollback es un solo campo.
3. **Sin fuente doble.** 5 claves nombradas y ningun array espejo: la UI de 5 slots llena las claves, el render futuro lee roles semanticos, y no existe un `palette` que pueda desincronizarse.

**Consecuencias (impacto):**
1. **1 archivo critico en Fase 1:** `admin.html` (Wizard: creacion + edicion). `evento-app.html` **NO se toca** en Fase 1. `registroaforo.html`, `scanner.html` y `api/*.js` no se tocan.
2. **0 migraciones, 0 endpoints, 0 cambios de RLS, 0 IDs del Contrato de Datos v112** (Cero Borrado intacto). Es una clave JSONB.
3. **Riesgo 1 (el que mata la feature): perdida silenciosa por el literal.** `_buildConfigLanding` debe emitir las 5 claves en el literal de `cfg.colors` (`admin.html:4704`); si falta una, se borra en cada guardado sin error. El circuito vivo es: **(a)** literal en `_buildConfigLanding` (escritura), **(b)** read-back en la precarga del Wizard (`openEditMod`, `:5758-5760`), **(c)** reset en `_limpiarWizardCompleto` (`:5992-6016`) y en los resets inline de `_crearEventoUnico` (`:7780-7781`) y `_crearSerie` (`:7881-7882`), **(d)** `payload.config_landing` replace total (`:6463`/`:7758`). Falta cualquiera -> dato perdido.
4. **El "modal" no es un camino vivo (correccion ADR-006):** `#mod-edit-ev` no se abre y `guardarEdicionEvento` (`:6524`; UPDATE de `color_primario`/`form_campos`/`imagen_url`/`aforo_max`) es codigo huerfano que, ademas, **no escribe `config_landing`**. Migrarlo a 5 slots es **prescindible**; el punto de edicion a migrar es el Wizard (`openEditMod`, `:5747`). Si Direccion insistiera en revivir el modal, exigiria merge de `colors` sobre `ev.config_landing` antes de su UPDATE; queda fuera de alcance de Fase 1 salvo instruccion explicita.
5. **No es el motor generico `tags`.** Este contrato es config de EVENTO (patron ADR-064), no un tag de CATEGORIA: `CATEGORY_TAG_FIELDS`/`CATEGORY_TAG_LISTS`, `collectPlace()`/`_placeToAPI()` NO se tocan.
6. **Inconsistencia preexistente a normalizar en Fase 1:** el default del builder es `#c8a96e` (`:4704`) mientras el default del input/columna es `#c9a84c` (`:891`, `:6438`, `:7743`). **Precision:** `admin.html:5224` (`const color = _orgData?.color_primario || '#c8a96e';`) es **branding de ORGANIZACION**, un concepto distinto y **FUERA del alcance** del default de evento; su `#c8a96e` NO es el default del color de evento. El **default canonico del evento unico es `#c9a84c`**.
7. **Consumidor LEGACY excluido (no se rompe):** `eventobackup.html:4691` (`cfg.colors?.accent`) y sus usos de `--ld-accent` (`:5000-5769`) siguen leyendo `colors.accent` como `string`; la Fase 1 NO los toca y la forma no cambia.
8. **Condicion de aprobacion de Fase 1 / Escudo GOLD (ADR-002):** el **nuevo JS de `admin.html` debe ser ASCII-ONLY** (cero bytes > 127; escapes `\uXXXX` si hiciera falta). Es criterio de aceptacion explicito, no recomendacion.

**Rollback:** es una clave JSONB. Retirar las 4 claves derivadas (o dejar solo `accent`) y `color_primario` sigue renderizando con el codigo actual; no hay migracion que deshacer ni DDL que revertir.

**Referencias:** ADR-064 (patron JSONB de config de evento; riesgo BUG-016), ADR-021 (mecanismo TinyColor que este ADR supera), ADR-047 (contratos de config del wizard/landing), ADR-006 (baseline contra el archivo real; prevalece el archivo), ADR-002 (ASCII-safe), Regla de Oro #2/#3 (Cero Borrado / Cero Borrado Logico), `admin.html:888-895`, `:3900-3915`, `:4704`, `:4868`, `:5224`, `:5758-5760`, `:5992-6016`, `:6438`, `:6463`, `:6524`, `:7743`, `:7758`, `:7780-7781`, `:7810`, `:7881-7882`, `:11170-11175`, `evento-app.html:1121-1123`, `eventobackup.html:4691,5000-5769`.

---

### ANEXO - Especificacion compacta de Fase 1 para `@admin-dev` (NO implementar en Fase 0)

Puntos de insercion (verificados, ADR-006):
- **UI wizard (Paso 1b), `admin.html:888-895`:** agregar los slots 2-5 (`secondary`, `tertiary`, `surface`, `background`). **DECISION RATIFICADA: `#ev-color` y `#ev-color-hex` SE CONSERVAN como alias del Slot 1 (`accent`); NO se renombran a `#ev-color-1..5`.** Motivo: no romper `_crearSerie:7882` (`document.getElementById('ev-color')`) ni `eventobackup.html`. Los slots 2-5 usan ids nuevos (`#ev-color-2..5` con sus `-hex`). El slot 1 es `accent`; slots 2-5 derivados. Previews de paleta en vivo.
- **Motor HSL:** retirar CDN TinyColor2 (`:2781-2783`), `renderColorHarmony` (`:3900-3915`) y `syncColor` (`:11170-11175`); sustituir por un generador HSL Vanilla puro (sin `eval`, CSP-safe).
- **Escritura, `_buildConfigLanding` (`:4704`):** `colors: { accent, secondary, tertiary, surface, background }` con las 5 claves siempre presentes (nunca `null`).
- **Read-back wizard (`:5758-5760`):** leer `ev.config_landing?.colors` con fallback a `color_primario` y al default `#c9a84c`.
- **Reset (3 puntos):** `_limpiarWizardCompleto` (`:5992-6016`) y los resets inline de `_crearEventoUnico` (`:7780-7781`) y `_crearSerie` (`:7881-7882`) deben repoblar los 5 slots al default `#c9a84c`.
- **Consumidor LEGACY excluido:** `eventobackup.html:4691,5000-5769` sigue leyendo `colors.accent`; NO tocar.
- **Modal (opcional, fuera de alcance salvo instruccion):** `#mod-edit-ev` (`:2529`) NO se abre (codigo muerto por Cero Borrado). NO migrarlo en Fase 1. Si algun dia se revive: 5 slots + merge de `colors` sobre `ev.config_landing` en `guardarEdicionEvento` (`:6524`).
- **Invariante de guardado:** `payload.color_primario === payload.config_landing.colors.accent` (hoy, en el Wizard: creacion y edicion).
- **Criterio de aceptacion (ADR-002):** el nuevo JS de `admin.html` es **ASCII-ONLY** (0 bytes > 127), verificado en el Escudo GOLD.
- **Fuera de alcance Fase 1:** `evento-app.html`, `eventobackup.html`, `api/*.js`, RLS, `css/templates/*`, `CATEGORY_TAG_FIELDS`.
