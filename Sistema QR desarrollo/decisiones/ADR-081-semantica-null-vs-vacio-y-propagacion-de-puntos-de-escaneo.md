---
doc: ADR-081
version: v1.19-GOLD (heredada de DECISIONS.md)
fecha: 2026-10-07
origen: Cambio de semantica de puntos de escaneo (NULL hereda / [] ninguno explicito), migracion de datos y propagacion por interseccion al editar los puntos del evento. Vacia el agujero que dejo ADR-079.
version_previa: ADR-080
relacionados: [../DECISIONS.md, ../INDEX.md, ADR-079-checkin-multi-punto-con-override-por-ticket.md, ADR-073-columna-canonica-del-instante-del-evento-evento-inicio.md, ADR-006-nomenclatura-atomica-por-categorias-silos.md, ADR-002-reemplazo-por-cumplimiento-de-csp-qrcodejs-qr.md]
estado: IMPLEMENTADO Y VERIFICADO (2026-10-07; migracion DML aplicada, scanner.html + admin.html en working tree)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [DECISIONS.md](../DECISIONS.md) - [INDEX](../INDEX.md).

## ADR-081: Semantica NULL-vs-vacio de puntos de escaneo y propagacion por interseccion

**Fecha:** 2026-10-07

**Autor:** Chief Architect (`@architect`). Decision cerrada por Direccion. Implementacion reservada a `@backend-dev` (semantica + migracion), `@admin-dev` (UI y propagacion) y `@data-migration` (migracion DML). Gate de riesgo de `AGENTS.md` seccion 2 (esquema/migraciones) aplica a la migracion y debe ser autorizado antes de aplicar. Cierre documental a cargo de `@docs-keeper`.

**Estado:** **IMPLEMENTADO Y VERIFICADO (2026-10-07).** Migracion DML `migrations/adr081_puntos_none_semantica.sql` aplicada a `ctgyvydzshueemlelkzv` (121 inscritos, 0 con `[]`, no-op). `scanner.html` y `admin.html` implementados en el working tree (`@admin-dev`); commit a cargo del orquestador. Escudo GOLD PASS; Cero Borrado PASS; `smoke_puntos_adr081.js` 30/30; `smoke_checkin_multipunto.js` 28/28; `express_check.js` 35/35. 0 DDL; 0 endpoints nuevos (presupuesto Vercel 8/8 intacto); 0 cambios de RLS; 0 IDs del Contrato v112 (Cero Borrado intacto).

**Problema:** ADR-079 introdujo `inscritos.puntos_acceso` (jsonb) como override por ticket, pero dejo **`NULL` y `[]` con el MISMO significado: "hereda los puntos del evento"**. La regla viva en `scanner.html:850` es:

```
allowed = (Array.isArray(override) && override.length > 0) ? override : (Array.isArray(base) ? base : []);
```

Esto produce dos fallas semanticas:

1. **No se puede expresar "ninguno explicito".** Un ticket que debe quedar inhabilitado en TODOS los puntos no tiene representacion: vaciar la seleccion lo colapsa a "hereda" (el guardado hace `sel.length > 0 ? sel : null`, `admin.html:6969`).
2. **Autoautorizacion silenciosa.** Cuando se AGREGA un punto nuevo al evento, todo invitado que hereda (`NULL` o `[]`) queda autorizado en el punto nuevo sin que nadie lo decida. El punto nuevo se "autoautoriza" a quien herede.

Ademas, al PODAR (quitar) puntos del evento los overrides por nombre quedan desincronizados sin ninguna propagacion: el override puede seguir conteniendo puntos que ya no existen (hoy se oculta mostrando la UNION base+override, `admin.html:6927`, lo que impide ver el desfase).

**Contexto (esquema y regla reales, verificados contra el archivo, ADR-006 - prevalece el archivo):**
- `eventos.puntos_acceso` = jsonb (array de strings), base del evento. EXISTE.
- `inscritos.puntos_acceso` = jsonb, override por ticket, `DEFAULT NULL`. Creada por `migrations/adr079_multi_punto_override.sql:89-93`; el `COMMENT` declara literalmente "NULL o [] = ... hereda".
- Regla del scanner: `scanner.html:846-860`. `override = data.puntos_acceso` (`:848`), `base = window._evData?.puntos_acceso` (`:849`), `allowed` (`:850`), y el texto del motivo "esta entrada"/"este evento" (`:852`).
- Guardado de puntos del EVENTO: `guardarPuntosEvento` (`admin.html:6860-6880`). Persiste `puntos.length > 0 ? puntos : null` (`:6867`).
- Guardado de puntos del TICKET: `guardarPuntosInscrito` (`admin.html:6961-6972`). Persiste `sel.length > 0 ? sel : null` (`:6969`). **No hay camino que escriba `[]`.**
- Editor por inscrito: `openPuntosInscrito` (`admin.html:6915-6953`); hoy `propios = Array.isArray(ins.puntos_acceso) ? ins.puntos_acceso : []` (`:6924`) trata `[]` y `NULL` igual, y `propios.length` decide "Override activo" vs "hereda" (`:6933-6936`).
- Selector de registro manual: `renderAsPuntos` (`admin.html:6891`), consumido por `_getAsPuntos()` (`:8493`).
- Export CSV: `i.puntos_acceso||''` (`admin.html:10280`).

**Opciones:**
- (A) **Mantener `NULL` y `[]` equivalentes (status quo de ADR-079)**: no expresa "ninguno explicito" y autoautoriza puntos nuevos a quien hereda. **RECHAZADA.**
- (B) **Introducir IDs de punto** (`eventos.puntos_acceso` como objetos con `id`, overrides/tokens/logs por id): resuelve el rename de forma nativa, pero obliga a migrar `eventos.puntos_acceso`, `scanner_tokens.punto_acceso`, `logs.punto_acceso` (todos por NOMBRE hoy) y a rehacer el match del check-in. DDL + migracion de datos + riesgo alto en el camino caliente. **RECHAZADA** (sobrediseno para el valor).
- (C) **Separar `NULL` (hereda todos) de `[]` (ninguno explicito) y propagar por NOMBRE por interseccion al editar el evento.** Cero DDL, cero endpoints. **ELEGIDA.**

**Decision:**

1. **Nueva semantica (fuente de verdad del modelo).** En `inscritos.puntos_acceso`:
   - `NULL` = **hereda TODOS** los puntos del evento (sigue al evento de forma dinamica).
   - `[]` (array vacio) = **ninguno explicito**: el ticket no es valido en ningun punto del evento.
   - Array no vacio = **override**: el ticket vale **solo** en esos nombres.
   La regla del scanner pasa a distinguir por **presencia de la clave** (no por longitud), en `scanner.html:847-860`:
   ```
   const override = data.puntos_acceso;
   const base     = window._evData?.puntos_acceso;
   const hasOwn   = Array.isArray(override);                  // NULL => false
   const allowed  = hasOwn ? override : (Array.isArray(base) ? base : []);
   const motivo   = hasOwn ? 'esta entrada' : 'este evento';
   ```
   `hasOwn` reemplaza la doble condicion `Array.isArray(override) && override.length > 0` en la decision y en el `motivo` (`:850`, `:852`).

2. **Migracion de datos (DML, idempotente, sin DDL).**
   ```sql
   UPDATE public.inscritos
      SET puntos_acceso = NULL
    WHERE puntos_acceso = '[]'::jsonb;
   ```
   Es **segura** porque bajo la semantica vieja `[]` ya significaba "hereda", luego normalizar `[]` -> `NULL` **no cambia el comportamiento efectivo** de ninguna fila. Es **idempotente**: al segundo pase no hay filas `= '[]'::jsonb`. Se ubica en una migracion nueva (`migrations/adr081_puntos_none_semantica.sql`), sin DROP/DELETE/TRUNCATE, y con su bloque de verificacion. **No se toca** `eventos.puntos_acceso`.

3. **Propagacion al modificar los puntos del EVENTO (solo el evento editado).** En `guardarPuntosEvento` (`admin.html:6860`), tras persistir `eventos.puntos_acceso = N` para el evento `E`:
   - Invitados de `E` con `puntos_acceso IS NULL`: **no se tocan** (heredan y reciben `N` automaticamente por la nueva semantica).
   - Invitados de `E` con override no vacio `O`: nuevo override = **`O INTERSECT N` por NOMBRE**. Si la interseccion queda vacia -> se persiste `[]` (ninguno explicito), **no** `NULL`.
   - Invitados con `[]`: **no se tocan** (siguen en "ninguno explicito").
   - **Rename de un punto = quitar + agregar.** El nombre viejo sale de todos los overrides (interseccion) y el nombre nuevo **no** se agrega a ningun override; solo lo reciben los herederos (`NULL`). Re-vincular por identidad exigiria IDs de punto (Opcion B, rechazada). **Limite aceptado y documentado**, no un bug.
   - Ejecucion: lectura de `inscritos` del evento + calculo de interseccion + updates por lote desde `admin.html` (cliente). **Sin endpoint nuevo** (presupuesto Vercel). Best-effort con aviso en el modal: si la propagacion falla, el guardado del evento no debe revertirse, pero se informa que hay overrides sin reconciliar.

4. **UI.** Nueva vista **"Por punto"** en el panel de invitados: seleccion masiva por punto (elegir un punto y marcar/desmarcar invitados). Reglas de UI obligatorias:
   - Debe poder distinguir tres estados por invitado: **Hereda** (`NULL`), **Ninguno** (`[]`) y **Override** (`O`). Un unico "todo desmarcado" ya no puede colapsar a `NULL`: debe ofrecerse el estado explicito "Ninguno".
   - `openPuntosInscrito` (`admin.html:6915`) debe ramificar por `Array.isArray(ins.puntos_acceso)`: `NULL` -> "hereda"; `[]` -> "Override activo: ninguno"; `O` no vacio -> "solo en los marcados". Se abandona la union base+override (`:6927`) como unica vista: se muestra base (herencia) separada del override propio para que un punto podado sea visible.
   - `guardarPuntosInscrito` (`:6969`) deja de mapear vacio->`NULL`; la eleccion "Ninguno" persiste `[]`. La herencia se guarda con una accion explicita ("Heredar del evento"), no como efecto colateral de no marcar.
   - `renderAsPuntos` / registro manual (`:6891`, `:8493`): el default al inscribir es **`NULL` (heredar)**, que sigue siendo el caso seguro.

**Justificacion:**
1. **Latente antes de romper nada.** La migracion normaliza un valor que hoy NO distingue comportamiento; aplicarla antes o despues del deploy del scanner es inocuo.
2. **Cero estructural.** Una condicion en `scanner.html` + un `UPDATE` + logica de reconciliacion en `admin.html`. 0 DDL, 0 RLS, 0 endpoints, 0 IDs del Contrato (Cero Borrado, Oro #2).
3. **Cierra el agujero de autoautorizacion.** Quien debe quedar fuera de un punto nuevo ya puede declararlo (`[]` o override acotado) y la propagacion impide overrides fantasma tras una poda.
4. **El rename es deuda declarada, no diseno oculto.** Se documenta el limite para no pagar el costo de IDs de punto sin consumidor que lo justifique.

**Consecuencias (impacto):**
1. **Archivos:** `scanner.html` (1 bloque, `:847-860`), `admin.html` (`guardarPuntosEvento`, `openPuntosInscrito`, `guardarPuntosInscrito`, nueva vista "Por punto", selector/render de registro manual) y **1 migracion DML** nueva. `evento-app.html`, `registroaforo.html`, `eventobackup.html`, `api/*.js` y `css/templates/*` **NO se tocan**.
2. **Backend/Supabase:** 0 endpoints, 0 RLS, 0 DDL. Solo 1 `UPDATE` de normalizacion y updates por lote sobre `inscritos` (permitidos por las politicas de owner vigentes) al guardar puntos del evento.
3. **Riesgo 1 (el que muerde): la propagacion es multi-fila y no transaccional.** Un corte a mitad deja overrides parcialmente reconciliados. Mitigacion: recalcular `O INTERSECT N` es idempotente (re-ejecutar converge) y el modal debe poder re-dispararse; registrar el conteo reconciliado en el mensaje de exito.
4. **Riesgo 2: la UI puede reintroducir el colapso.** Si "Ninguno" no se cablea de forma explicita y se sigue guardando `sel vacio -> NULL`, la semantica nueva queda sin efecto. Es criterio de aceptacion, no recomendacion.
5. **No duplica ningun campo.** `puntos_acceso` ya existe en `eventos` e `inscritos`; no se crea clave nueva en `tags` ni columna nueva. No aplica el motor generico `CATEGORY_TAG_FIELDS`/`CATEGORY_TAG_LISTS` (esto es config de EVENTO/ticket, patron ADR-064/079, no un tag de categoria).
6. **Export CSV** (`admin.html:10280`): conviene que "Ninguno" (`[]`) y "Hereda" (`NULL`) no se serialicen igual; ajuste menor, dentro del alcance de UI.
7. **Escudo GOLD (ADR-002):** el JS nuevo de `admin.html`/`scanner.html` debe ser ASCII-ONLY (0 bytes > 127; escapes `\uXXXX` si hiciera falta) antes del deploy.

**Rollback:**
1. **Codigo:** revertir `hasOwn` -> la condicion vieja por longitud devuelve el comportamiento ADR-079. Un solo bloque.
2. **Datos:** la migracion es normalizacion `[]`->`NULL`; no se pierde informacion. Revertir exigiria volver a escribir `[]` en las filas afectadas, que **es justo el dato que se decidio que no aporta** (bajo la semantica vieja ambas heredan). Riesgo de rollback: nulo a nivel funcional.
3. **Propagacion:** desactivar el bloque de reconciliacion deja los overrides como estan (comportamiento previo a este ADR).

**Referencias:** ADR-079 (creo la columna y la ambiguedad que este ADR resuelve), ADR-073 (patron de migracion aditiva documentada), ADR-064 (config de evento por JSONB), ADR-006 (baseline = archivo real), ADR-002 (ASCII-safe), Reglas de Oro #2/#3 (Cero Borrado / Cero Borrado Logico). Archivos: `migrations/adr079_multi_punto_override.sql:80-93`, `scanner.html:846-860`, `admin.html:6860-6880`, `:6891`, `:6915-6953`, `:6961-6979`, `:8493`, `:10280`.
