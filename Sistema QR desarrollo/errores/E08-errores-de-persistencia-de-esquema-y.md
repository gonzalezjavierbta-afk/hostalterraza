---
doc: E08 (ERRORES_HISTORICOS.md §8)
version: v1.8.0-STABLE (heredada)
fecha: 2026-10-01
origen: ERRORES_HISTORICOS.md L105-118 (AMPLIACION/_backups/ERRORES_HISTORICOS.md.2026-10-01.bak)
version_previa: ERRORES_HISTORICOS.md v1.8.0-STABLE
relacionados: [../ERRORES_HISTORICOS.md, ../INDEX.md]
estado: vigente
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [ERRORES_HISTORICOS.md](../ERRORES_HISTORICOS.md) §8 · [INDEX](../INDEX.md). Texto original íntegro debajo (L105-118 del original).

## 8. Errores de Persistencia de Esquema y Anidación HTML en `admin.html` (Sesión Wizard Inteligente — ADR-021)

### 🚨 Columnas Documentadas en BLUEPRINT.md Nunca Escritas por el INSERT (`template_id`, `categoria_slug`)
* **Problema:** `BLUEPRINT.md` §3 documentaba `template_id` y `categoria_slug` como columnas de la tabla `eventos` desde antes de esta sesión, pero `crearEvento()` → `_crearEventoUnico()` en `admin.html` nunca las incluía en el payload del `INSERT`. El theme elegido en el formulario solo quedaba guardado dentro de `config_landing.theme` (JSON), nunca en columnas propias.
* **Causa:** Mismo patrón que el hallazgo de la Sección 7 (`.historia-item--conimg`, 50/50 vs 65/35 documentado) — un bug de transcripción silencioso, aquí entre `BLUEPRINT.md` y el código de `admin.html` en vez de entre `DECISIONS.md` y un `.css` de silo. Sin error de consola, sin white screen: los eventos se creaban con normalidad, solo que sin esas dos columnas pobladas.
* **Blindaje (ADR-021):** `_crearEventoUnico()` y `_crearSerie()` ahora escriben `template_id`, `categoria_slug` y `captura_pura` (nueva) en cada `INSERT` a `eventos`. Auditoría obligatoria: ante cualquier discrepancia entre lo que `BLUEPRINT.md` documenta como columna existente y lo que un `INSERT` de `admin.html` realmente popula, verificar el código fuente del `INSERT` directamente — no asumir que "está documentado" implica "está shippeado" (mismo principio que ADR-019 ya estableció para CSS, ahora extendido a payloads de Supabase).

### 🚨 `<div>` sin Apertura Antes de "Aforo Máximo" — Anidación Rota Detectable Solo por Parser
* **Problema:** Entre el constructor de campos personalizados y el campo "Aforo máximo" del formulario de creación de eventos, el marcado tenía un `</div>` de cierre (del constructor) seguido inmediatamente por `<label>Aforo máximo</label>` sin ningún `<div>` de apertura — y más abajo, tras el `<span>` de ayuda, un `</div>` adicional sin contraparte real en ese nivel.
* **Causa:** Omisión de un `<div class="fg">` de envoltura al mover o editar este campo en algún momento previo a esta sesión (no queda registro de en qué versión ocurrió). El error es **invisible a la inspección visual normal** del HTML — no genera error de consola ni white screen, solo un desbalance que un parser HTML5 real resuelve buscando el `<div>` abierto más cercano en toda la pila de elementos, potencialmente cerrando de forma prematura un contenedor ancestro no relacionado (en este caso, verificado con un parser real: el desbalance se propaga hasta manifestarse como un cierre sin apertura en ningún punto del árbol, más adelante en el mismo archivo).
* **Blindaje (ADR-021):** El campo "Aforo máximo" se envolvió correctamente en su propio `<div class="fg">`. Verificación aplicada (y recomendada para futuras sesiones sobre `admin.html`): correr un parser HTML5 con pila de elementos (ignorando void elements: `input`, `br`, `img`, etc.) sobre el archivo completo antes y después de cualquier cambio estructural grande — la inspección visual de un archivo de miles de líneas no es suficiente para detectar este tipo de desbalance, pero un parser lo confirma en segundos y con precisión de línea/columna.

---

