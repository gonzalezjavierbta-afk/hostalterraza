---
doc: E17 (ERRORES_HISTORICOS.md §17)
version: v1.8.0-STABLE (heredada)
fecha: 2026-10-01
origen: ERRORES_HISTORICOS.md L230-259 (AMPLIACION/_backups/ERRORES_HISTORICOS.md.2026-10-01.bak)
version_previa: ERRORES_HISTORICOS.md v1.8.0-STABLE
relacionados: [../ERRORES_HISTORICOS.md, ../INDEX.md]
estado: vigente
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [ERRORES_HISTORICOS.md](../ERRORES_HISTORICOS.md) §17 · [INDEX](../INDEX.md). Texto original íntegro debajo (L230-259 del original).

## 17. Bugs de Configuracion del Roster y del Andamiaje de Agentes (2026-09-28 — paquete ADR-059)

*Todos los hallazgos de esta sección fueron **corregidos** el 2026-09-28 y verificados contra el archivo real (ADR-006, comparación `git show HEAD:` vs. working tree). Se registran porque son **fallos de configuración que ningún test de runtime detecta**: no hubo ningunaincidencia de producción, pero todos ya estaban **inyectando contexto defectuoso o ruido en cada turno** del orquestador.*

### 🚨 `description:` con escapes Unicode literales `\u00XX` inyectados al catálogo del orquestador
* **Problema:** el campo `description:` de **4 agentes** (`architect-review`, `frontend-tpl`, `js-silo-dev`, `sql-security`) contenía **16 escapes `\u00XX` literales** (5+5+3+3). Son los ÚNICOS campos que entran al contexto del orquestador (tool `task`, `describeTask()` en `registry.ts`), de modo que el orquestador leía descripciones con texto roto tipo *"Agente de revisi\u00f3n de arquitectura y aprobaci\u00f3n de decisiones"* y *"valida planes t\u00e9cnicos"*, con la grave consecuencia de que la **descripción no servía para enrutar** (que es exactamente su función). *Corrección frente a lo escrito en ADR-059:* el ADR nombraba **5** descripciones y atribuía la quinta a `build.md`; el barrido real da **4 `description:` con escapes** (`build.md` tenía **0** y su bug era otro — ver el ítem siguiente). Los otros **12** archivos del roster sí tenían escapes, pero **en el cuerpo**, que NO entra al contexto del orquestador: mismo defecto, consecuencia distinta.
* **Causa raíz:** doble codificación UTF-8 en el momento de generar o copiar el frontmatter (el texto se escapó a ASCII una vez y el archivo se volvió a decodificar como UTF-8 sin resolver los escapes). No había ninguna verificación que lo detectara: YAML no da error con `\u00f3` dentro de un escalar plano, es simplemente texto.
* **Blindaje (ADR-059, convención v2 de `description:`):** escalar **plano de un renglón**, sin escapes, sin mención de modelo, ≤175 chars; y **`name:` explícito** en los 38. Cualquier escape `\u00XX` o carácter de control en un `description:` es motivo de rechazo del cambio.
* **Verificación:** barrido `git show HEAD:.opencode/agent/*.md` → **16 archivos** con escapes en total (18+19+13+13+10+4 en los de mayor peso y 1 en cada uno de 10 archivos), de los cuales solo **4 los tenían dentro de `description:`**. Hoy: `node scripts/usage_report.js --overhead` → **38 de 38 agentes con `description:` parseada, 0 escapes, max 152 chars**.

### 🚨 `description:` vacía en el catálogo por bloque YAML folded (`>`)
* **Problema:** **6 agentes** declaraban la descripción como escalar de bloque folded (`description: >` + renglones indentados): `content-loader`, `content-loader-free`, `data-migration`, `data-migration-free`, `research-agent`, `research-agent-free`. De ellos, ADR-059 reportó **2 que llegaban VACÍAS** al catálogo del orquestador (`content-loader` y `content-loader-free`): el agente aparecía en el `task` **sin descripción alguna**, es decir **no enrutable**. El resto de las folded se parseaban, pero con saltos de línea embebidos en un campo que se inyecta en una sola línea de contexto.
* **Causa raíz:** el formato folded es válido YAML pero frágil en el camino `archivo -> parseo -> describeTask()`: cualquier diferencia de indentación o un segundo bloque de texto convierte el escalar en vacío **sin error de parseo**, y el síntoma (un agente sin descripción) es indistinguible de "el agente no existe".
* **Blindaje (ADR-059, convención v2):** `description:` **siempre escalar plano de un renglón**; prohibido `>` folded y `|` literal en el roster. Señal de alarma: un `description:` que no aparece en el catálogo de `--overhead` ("N con description" < N archivos).
* **Verificación:** el barrido `description: >` sobre `HEAD` devuelve **6 archivos**; en el working tree **0**. `--overhead` reporta **38 archivos / 38 con `description:`** = 100%.

### 🚨 Placeholder de modelo sin resolver en `build.md` y `description:` que contradecía su propio `model:`
* **Problema (dos casos distintos, mismo síntoma de fondo: la `description:` como fuente de verdad que nadie coteja con los campos reales).** (a) `build.md` traía `description: "Agente de implementacion PAGO de HostalTerraza. Modelo  (deepseek-v4.1-flash)..."` — **doble espacio**: el nombre del modelo se había borrado del texto y quedaba un **placeholder sin resolver** ("Modelo ␣␣"). (b) `media-reader-free.md` anunciaba en su descripción *"Versión open-source (**mimo-v2.5-free**) de media-reader"* y *"Excepción intencional de modelo: **mimo-v2.5-free** es el único free con visión real"* mientras su campo real era `model: opencode/mimo-v2.6-flash-free` — la descripción **afirmaba un modelo que el agente no usa**, dos versiones atrasado, y esa contradicción ya se había reportado antes como el agente "roto" (TSK-048, que además citaba `mimo-v2.5-free` como modelo de catálogo inexistente).
* **Causa raíz:** la `description:` se editaba a mano como prosa y **nunca se contrastaba con el bloque `model:`/permisos del mismo archivo**. Un placeholder de texto y un nombre de modelo obsoleto son el mismo defecto: la descripción affirmaba un estado que el archivo no tenía.
* **Blindaje (ADR-059, convención v2):** **prohibido mencionar el modelo dentro de `description:`** (el campo `model:` es la única fuente de verdad del modelo; la excepción de visión de `media-reader-free` se documenta en la **skill `modelos-verified`**, no en el catálogo del orquestador). Toda `description:` debe ser un escalar plano de un renglón que describa **dominio + criterio de enrutado**, nunca metadatos de ejecución.
* **Verificación:** barrido de `\u00XX`/placeholders/`mimo-v2` sobre las 38 `description:` actuales → 0 coincidencias. La excepción de modelo de `media-reader-free` sigue viva, pero declarada **fuera** del catálogo (skill `agentes-roster` §5, punto 2).

### 🚨 `model:` global anulado en `opencode.json` y `subagent_depth: 2` sin caso de uso real
* **Problema:** `opencode.json` declaraba `"model": "opencode-go/deepseek-v4.1-flash"` a nivel raíz **mientras `default_agent: free-build`** → el modelo global estaba **anulado** por la precedencia real del runtime (el agente por defecto gana), dejando un campo que **prometía un modelo de pago y no se cumplía**: documentaba un costo que no era el real, y cualquier lectura del archivo para decidir modelo/presupuesto era **falsa**. En el mismo archivo, `subagent_depth: 2` autorizaba **un nivel de anidamiento de subagentes sin ningún caso de uso medido** (cada nivel multiplica turnos y, con ellos, `cache_read`; ADR-058: `cache_read` = 91,7% del gasto).
* **Causa raíz:** configuración por acumulación (tecla agregada para un momento y nunca retirada) + **ausencia de un mecanismo que diga qué clave manda** cuando hay dos fuentes de verdad del modelo en el mismo archivo.
* **Blindaje (ADR-059, decisiones 6 y 7):** una sola fuente de verdad del modelo por agente (`model:` en el frontmatter, explícito y **prohibido heredar el principal** — skill `agentes-roster` §1) y **ninguna clave global que la contradiga**; `subagent_depth: 1` porque la Dirección confirmó que no hay anidamiento real. La configuración ya no puede quedar "anulada pero presente": o se usa o no se escribe.
* **Verificación:** `opencode.json` real = sin clave `model:`, con `small_model`, `default_agent: free-build`, `subagent_depth: 1`, `permission`, `compaction`, `watcher`, `formatter`, `lsp`; **JSON válido** tras el cambio. Beneficio medido junto con el resto: el overhead fijo del system prompt bajó a **3.933 tokens/turno** (`AGENTS.md` 1.423 + 38 descripciones 1.478 + 17 descripciones de skills 1.031), y `usage_report.js --summary --since 0` pasó de **~6.500-11.000 ms a ~350-1.100 ms (10x-30x)**.

---

