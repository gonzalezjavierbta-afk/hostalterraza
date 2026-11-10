---
doc: ADR-093
version: v1.0-ACEPTADO
fecha: 2026-11-10
origen: Bug estructural detectado en el cierre de la jornada de "control de modulos" - el admin escribia `config_landing.modules.*` desde hacia tiempo, pero el kernel publico solo leia una de esas claves. Este ADR fija la regla para que el contrato no vuelva a partirse.
version_previa: ADR-092
relacionados: [../DECISIONS.md, ../INDEX.md, ../TASKS.md, ../NEXT.md, ../PROJECT.md, ../BLUEPRINT.md, ADR-006-nomenclatura-atomica-por-categorias-silos.md, ADR-008-protocolo-de-blindaje-de-assets-silent.md]
estado: ACEPTADO, IMPLEMENTADO Y DESPLEGADO (commit `9fd2081` en `main`, 2026-11-10)
estructura: detalle-v1 (2026-10-01)
nota_numeracion: Verificado el 2026-11-10 contra `decisiones/`: la ficha previa es `ADR-092` (no existe archivo `ADR-093*`). `ADR-075` sigue siendo hueco y NO se rellena. Cero Borrado: no se sobrescribe ninguna ficha previa.
---

> Detalle de [DECISIONS.md](../DECISIONS.md) - [INDEX](../INDEX.md).

## ADR-093: Todo flag del admin debe tener lectura en el kernel

**ID:** ADR-093

**Fecha:** 2026-11-10

**Autor:** diagnostico y fix ejecutados en la sesion de "control de modulos"; este ADR se deriva del codigo ya escrito, verificado y desplegado (ADR-006: baseline = archivo real).

**Estado:** ACEPTADO, IMPLEMENTADO Y DESPLEGADO (commit `9fd2081`, `main`).

### 1. Problema

`admin.html` escribia `config_landing.modules.*` desde hacia tiempo: el panel `#mods-fiesta` y `_buildConfigLanding` ya emitian `gallery`, `whatsapp`, `guest_list`, `boletos`, `banner-1`, `banner-2`, etc. Sin embargo, **el kernel publico no leia esa clave**: el unico uso previo de `cfg.modules` era `__esSoloFormulario` (`evento-app.html:1115`). Consecuencia medida:

*   Apagar "galeria" o "whatsapp" en el admin **no hacia nada** en la pagina publica: los modulos seguian visibles. El flag se guardaba en el JSONB y moria ahi.
*   `#mod-form` ("Unete a nuestra comunidad", `evento-app.html:322-342`) **no tenia control alguno** en el admin: el silo lo encendia siempre, sin forma de apagarlo por evento.
*   No habia forma de pedir que boleteria y guest list compartieran fila: es un layout por evento, no un flag booleano de visibilidad, y no existia gancho.

Un flag que el admin escribe y el kernel ignora es peor que no tener el flag: produce una **falsa sensacion de control** y el operador cree haber apagado algo que sigue publicado.

### 2. Opciones consideradas

*   **(A) Retirar los checkboxes del admin:** descartada. Borra funcionalidad visible y no resuelve el caso real (apagar modulos por evento).
*   **(B) Dejar el comportamiento actual y documentar "no hace nada":** descartada. Viola el Mandato documental en su espiritu: el panel miente.
*   **(C) Ensenar al kernel a leer la clave, con default visible y ocultamiento no destructivo:** **elegida**.

### 3. Decision (contrato)

**R1 - Un flag que el admin escribe y el kernel no lee es un BUG, no una feature pendiente.** No se documenta como "deuda"; se registra como tarea con sintoma, causa raiz y verificacion de apagado. Aplica a `config_landing.modules.*` y a cualquier clave de `config_landing` con control en el admin.

**R2 - Default VISIBLE para claves ausentes.** `modOn(k)` devuelve `M[k] !== false`: solo un `false` explicito apaga. Una clave ausente (eventos antiguos, categoria donde el panel no aplica) deja el modulo **como siempre estuvo**. Esto garantiza compatibilidad hacia atras sin migrar los 13 eventos ni las filas de otras categorias.

**R3 - Ocultar SIEMPRE con `data-hidden` + `display:none !important` inline. Nunca borrando nodos.** `__aplicaModulos` aplica `el.style.setProperty('display','none','important')` y `el.setAttribute('data-hidden','1')`; el CSS del silo selecciona por `[data-hidden]` (o `[data-empty]`) para refluir su grid. **Cero Borrado (Oro #2):** no se elimina ningun ID del Contrato v112, ningun nodo del DOM ni se usa `remove()`.

**R4 - Toda variante de LAYOUT por evento va bajo un atributo en `body` y aislada en el CSS del silo.** El kernel **no toca la rejilla**: solo publica el gancho (`body[data-mod-row="boleto-guest"]` cuando `modules.boletos_guestlist === true`) y el silo decide. Sin el atributo, la seccion CSS no aplica y **el resto de eventos del silo no cambia una linea**. Esta es la forma de que un layout especial de un solo evento no contamine a los demas.

**R5 - Cada flag necesita PRUEBA DE APAGADO en el harness.** No basta con que el render lo encienda: el harness debe ejercitar (a) la clave **ausente** -> modulo visible, (b) la clave en `false` -> modulo oculto, (c) la **doble aplicacion** idempotente y (d) que el poblado del render **no re-encienda** lo apagado.

**R6 - El render no puede revertir el toggle.** `__hideEmptyModule` (`evento-app.html:1391-1411`) consulta `__MOD_OFF`: si el modulo esta apagado, re-aplica `display:none !important` + `data-hidden` y **retorna `false`** aunque `hasContent` sea verdadero. Sin esta guarda, el poblado posterior al toggle volvia a mostrar el modulo y el apagado se perdia en silencio.

**R7 - El admin solo emite las claves nuevas en la categoria donde tienen panel.** `form` y `boletos_guestlist` se emiten con spread condicional **solo para `fiesta`** (`admin.html:5629-5632`): en cine/campana la clave queda **AUSENTE a proposito**, porque el render es fail-open y un `false` explicito apagaria el formulario de eventos que el admin nunca gobierno.

### 4. Implementacion (anclas verificadas contra el archivo real, 2026-11-10)

1.  `evento-app.html:1287-1327` - segmento **CONTROL DE MODULOS**: normaliza `cfg.modules`, define `modOn(k)` (`:1290`), el mapa `id del DOM -> clave` (`:1298-1303`: `mod-video`->`gallery`, `mod-whatsapp`->`whatsapp`, `mod-guestlist`->`guest_list`, `mod-form`->`form`), oculta inline `!important` + `data-hidden="1"` (`:1311`, `:1314`) y publica/retira `body[data-mod-row]` (`:1322-1326`).
2.  `evento-app.html:1391-1411` - `__hideEmptyModule` blindado: si `__modOff(id)`, re-aplica el estado y retorna `false`.
3.  `admin.html:691-692` - 2 checkboxes nuevos: `ld-mod-form` ("Comunidad / formulario") y `ld-mod-row-boletos` ("Boletos + guestlist en una fila").
4.  `admin.html:5629-5632` - `_buildConfigLanding` emite `form` y `boletos_guestlist` (spread condicional a `fiesta`); mapa inverso `_MOD_FIXED` en `:6664`; restauracion en `openEditMod` en `:6892-6896`; mapa de `hideForeignModulesByType` en `:7045`.
5.  `css/templates/fiesta/f14.css:2919-3007` - **seccion 29**, aplicable **solo** bajo `.tpl-f14[data-mod-row="boleto-guest"]`: areas `"boletos guestlist"` en `>=768px`; con guestlist `[data-hidden]` o `data-empty` boletos ocupa el ancho; `#mod-boletos` acotado a `1/2` cuando `#mod-form` esta oculto; sin la clave, ninguna regla aplica.
6.  `migrations/oneoff_vinilos_modules_flags.sql` - datos del evento `vinilos-inversos-c8yu`: `modules` = `{gallery:false, whatsapp:false, form:false, guest_list:true, boletos_guestlist:true}` (26 claves, las 24 previas intactas). Idempotente, 1 fila.

### 5. Justificacion

El costo del fix es acotado (un segmento nuevo en el kernel, una guarda en una funcion existente, 2 checkboxes y una seccion CSS de silo) y elimina una clase entera de fallos: **la UI del admin deja de mentir**. El default visible (R2) evita migrar datos y evita que un evento viejo pierda su formulario. El ocultamiento no destructivo (R3) respeta el Cero Borrado y permite que el CSS del silo refluya por `:has([data-hidden])` sin huecos. El gancho en `body` (R4) es lo que permite un layout especial de un evento sin tocar el resto del silo.

### 6. Impacto

*   **Datos:** **0 DDL**, **0 RLS**, 0 columnas nuevas. Solo se escriben claves dentro de `config_landing` (jsonb). La unica migracion es un `UPDATE` de contenido de **1 fila** (`vinilos-inversos-c8yu`), idempotente.
*   **Codigo:** `evento-app.html` (motor de los 14 silos), `admin.html` (panel y restauracion) y `css/templates/fiesta/f14.css` (seccion 29). **0 cambios** en `api/*.js`, `index.html`, `registroaforo.html`, `scanner.html`, SQL/RLS y en los otros 13 silos.
*   **Contrato v112:** **0 IDs retirados**. Los nodos apagados siguen en el DOM con `data-hidden`.
*   **Operacion:** el estado apagado se ve de inmediato en la pagina publica; el admin no cambia de flujo.

### 7. Verificacion declarada (2026-11-10)

`node --check` **11/11** bloques inline OK; renderer **27/27** con `vm` + DOM stub (clave `modules` ausente -> 4 modulos visibles, doble aplicacion idempotente, guard anti-re-encendido); admin **19/20** (el FAIL declarado era **falso positivo del test**, no del patch); CSS **7/7** matrices de areas sin celdas huerfanas y llaves **278/278** con delta 0; ASCII-safety **delta 0/-1**. Desplegado en `hostalterraza.vercel.app`: el `evento-app.html` servido ya contiene `data-mod-row`.

### 8. Riesgo residual y pendientes que este ADR NO cierra

1.  **La matriz del grid f14 se valido por analisis de reglas, no en navegador real.** No se ejecuto el harness headless de 7 estados x 4 anchos: los estados (boletos+guestlist, guestlist apagado, form apagado, sin boletos, sin guestlist, `data-empty`) estan razonados sobre el CSS, no medidos. Seguimiento en `NEXT.md` hito **-64**.
2.  **Quedan flags de `modules` sin auditar** (`historia`, `playlist`, `trailer`, `countdown`, ...): pueden estar en la misma situacion (escritos por el admin, sin lectura en el kernel). R1 obliga a revisarlos uno por uno.
