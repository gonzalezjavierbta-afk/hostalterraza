---
doc: ADR-092
version: v1.0-ACEPTADO
fecha: 2026-11-10
origen: Feature "markdown-lite en descripciones de evento" ya implementada en el motor publico (`evento-app.html`), en el editor del admin (`admin.html`) y en el Open Graph (`api/evento-og.js`). Este ADR fija el contrato para que el siguiente agente no lo reinterprete ni lo amplie sin decision propia.
version_previa: ADR-091
relacionados: [../DECISIONS.md, ../INDEX.md, ../TASKS.md, ../NEXT.md, ../PROJECT.md, ../BLUEPRINT.md, ADR-001-seleccion-de-stack-frontend-estatico-puro.md, ADR-002-reemplazo-por-cumplimiento-de-csp-qrcodejs-qr.md, ADR-006-nomenclatura-atomica-por-categorias-silos.md, ADR-008-protocolo-de-blindaje-de-assets-silent.md]
estado: ACEPTADO E IMPLEMENTADO EN CODIGO (2026-11-10) - SIN DESPLEGAR (falta commit+push) y con 1 UPDATE de datos pendiente
estructura: detalle-v1 (2026-10-01)
nota_numeracion: Verificado el 2026-11-10: no existe archivo `ADR-092*` en `decisiones/` (81 fichas previas) y `DECISIONS.md` llega a ADR-091; `ADR-075` sigue siendo hueco y NO se rellena. 092 es el siguiente numero libre. Cero Borrado: no se sobrescribe ninguna ficha previa.
---

> Detalle de [DECISIONS.md](../DECISIONS.md) - [INDEX](../INDEX.md).

## ADR-092: Contrato markdown-lite de descripciones

**ID:** ADR-092

**Fecha:** 2026-11-10

**Autor:** implementacion y verificacion registradas por el agente de documentacion en el cierre del feature; el contrato se deriva del codigo ya escrito y verificado (ADR-006: baseline = archivo real).

**Estado:** ACEPTADO E IMPLEMENTADO EN CODIGO. **No desplegado**: el codigo no esta en produccion hasta el `commit` + `push`, y el `UPDATE` de datos no se aplico.

### 1. Problema

Las descripciones de evento (`config_landing.historia` / `descripcion`, admisibles como **string** o como objeto `{titulo,texto}`) se inyectaban con `textContent`, de modo que un parrafo largo quedaba como un **bloque de texto corrido**, sin forma de destacar un titulo, una frase o una lista de items (line up, que incluir, recomendaciones). Al mismo tiempo, `admin.html` ofrecia un textarea plano **sin preview**, asi que lo que Direccion escribia no se parecia a lo que se publicaba. La tentacion natural -meter una libreria de markdown o usar `innerHTML` con el texto del usuario- choca con ADR-001 (**Vanilla JS puro**, prohibido el build step) y con el riesgo de **XSS** en un campo que escribe el cliente.

### 2. Opciones consideradas

*   **(A) Libreria de markdown (marked, markdown-it, etc.):** descartada. Rompe ADR-001, suma peso al motor de 14 silos, introduce un contrato amplio (HTML crudo, tablas, enlaces, imagenes) que nadie pidio y obliga a sanear la salida de la libreria igualmente.
*   **(B) `innerHTML` directo del texto del usuario:** descartada. Es el vector de XSS clasico sobre un campo editable en el admin.
*   **(C) Set cerrado de marcadores propios ("markdown-lite") resuelto con 3 funciones locales y escapado previo:** **elegida**.

### 3. Decision (contrato)

**D1 - Allowlist cerrada.** Solo se interpretan: `***x***` (negrita + cursiva), `**x**` (negrita), `*x*` (cursiva), **listas** por linea con prefijo `- `, `* ` o el bullet **U+2022** (`\u2022`), y el salto de linea `\n` -> `<br>`. **Nada mas**: no hay enlaces, imagenes, tablas, bloques de codigo, encabezados ni HTML crudo. Cualquier otra sintaxis queda como texto literal.

**D2 - Orden obligatorio de transformacion:** **1)** escapar `&`, `<`, `>`; **2)** marcadores inline (`***` -> `**` -> `*`, en ese orden, para no romper el triple); **3)** **bloques** (listas + `\n` -> `<br>`). Escapar **primero** es lo que neutraliza el XSS: ningun caracter del usuario llega al DOM como etiqueta.

**D3 - Paridad obligatoria entre los 3 consumidores.** El mismo contrato vive en `evento-app.html:1128-1163` (`esc`, `_mdInline`, `richText`), en `admin.html:3299-3359` (`_mdEsc`, `_mdInline`, `richText`, `_mdApply`) y, en su version de **texto plano**, en `api/evento-og.js:45-59` (`cleanText`). Cambiar uno **obliga** a cambiar los otros dos y a repetir la prueba de **paridad 8/8** y de **XSS 48/48**.

**D4 - Prohibido `innerHTML` de texto de usuario sin escape previo.** el unico camino permitido es `innerHTML = richText(...)` (o `richText(...)` como unico argumento). Escribir `innerHTML` con un campo que venga de la base o del formulario **sin** pasar por `richText` es una regresion de seguridad, no un atajo.

**D5 - Markdown siempre activo, sin flag por evento.** No hay columna, clave de `config_landing` ni toggle en el admin: si el texto esta en la base, se interpreta. Se evita una matriz de estados (activado/desactivado por evento, por silo y por consumidor) que nadie puede auditar.

**D6 - El tag del contenedor debe admitir `li`.** `#db-historia-texto` y `#db-descripcion-texto` son `<div>` (antes `<p>`): un `<li>` dentro de `<p>` es HTML invalido y el parser cierra el parrafo antes de la lista. Al cambiar el tag se verifico que **ningun selector CSS** de `css/templates/**` dependiera de `p`.

**D7 - OG trabaja contra el texto limpio.** `cleanText` despoja los marcadores **antes** de construir `meta`/OG/twitter, para no filtrar `**` ni `***` a las previsualizaciones sociales. Los asteriscos **sueltos** y las expresiones aritmeticas (`2 * 3`) **se conservan**: el limpiador solo retira marcadores con pareja.

### 4. Justificacion

Se resuelve el 90% del valor editorial (destacar, enumerar) con **~45 lineas** de Vanilla JS y **cero dependencias**, sin tocar el esquema, sin endpoint nuevo y sin RLS. El escape primero permite razonar la seguridad en **una** linea de la funcion (`esc` antes de todo) en lugar de auditar la salida de una libreria. La paridad entre los 3 consumidores garantiza que el admin **previsualice exactamente** lo que el motor publica y que el OG no muestre basura de marcadores.

### 5. Impacto

*   **Datos:** 0 DDL, 0 columnas nuevas, 0 cambios de RLS. El campo sigue siendo texto; solo cambia **como se pinta**. `migrations/oneoff_descripcion_vinilos_markdown.sql` es un **UPDATE de contenido** de un solo slug (`vinilos-inversos-c8yu`), pendiente de ejecucion manual en el SQL Editor (RLS bloquea `anon`).
*   **Codigo:** `evento-app.html` (motor de los 14 silos), `admin.html` (toolbar de 5 botones + preview) y `api/evento-og.js` (1 funcion nueva). **0 cambios** en `index.html`, `registroaforo.html`, `scanner.html` y `css/templates/**`.
*   **Operacion:** la toolbar inserta por `selectionStart`/`selectionEnd`, asi que no reescribe el cursor ni el scroll del textarea; el preview se actualiza por `innerHTML = richText(...)`.
*   **Contrato v112:** **0 IDs retirados** (Cero Borrado, Oro #2).

### 6. Riesgo aceptado

**Un `*` literal en descripciones antiguas pasara a cursiva.** El markdown esta siempre activo (D5), asi que un texto que decia `2 * 3 * 4` o `*condiciones` puede cambiar de aspecto sin que nadie lo edite. Se acepta porque: (a) el cambio es **cosmetico**, no destructivo -el texto completo sigue en la base y el `*` solo desaparece del render-; (b) la alternativa (flag por evento) obliga a migrar 13 eventos y crea dos comportamientos que nadie recuerda; (c) el admin tiene el preview, de modo que cualquier correccion es **visible antes de guardar**.

### 7. Verificacion declarada (2026-11-10)

Paridad **8/8** entre los dos `richText`; **XSS 48/48** payloads neutralizados (escape primero); `node --check` OK en los **5 bloques** inline tocados y en `api/evento-og.js`; **ASCII-safety delta 0** en los 3 archivos; **balance de `div` delta 0**. **No re-ejecutada** en el pase documental (ADR-006: las cifras son referenciales; el baseline es el archivo).

### 8. Pendiente que este ADR NO cierra

1.  Ejecutar `migrations/oneoff_descripcion_vinilos_markdown.sql` en el SQL Editor de Supabase.
2.  `commit` + `push` y **smoke visual** en `hostalterraza.vercel.app/evento.html?slug=vinilos-inversos-c8yu`.
3.  **Decision abierta (no cubierta por D1-D7):** estilo `ul/li` en los silos **f9/f12** (hoy **sin regla** propia) y `columns: 2` de `css/templates/fiesta/f12.css:990` **fragmentando** las listas entre columnas. Requiere decision de diseno por silo antes de tocar CSS.
