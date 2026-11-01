---
doc: ADR-084
version: v1.16-GOLD (heredada de DECISIONS.md)
fecha: 2026-11-01
origen: DECISIONS.md (indice) - TSK-117, contador del landing del motor compartido evento-app.html
version_previa: DECISIONS.md v1.16-GOLD
relacionados: [../DECISIONS.md, ../INDEX.md, ../BLUEPRINT.md, ../NEXT.md, ../TASKS.md, ../ERRORES_HISTORICOS.md, ADR-083-encuadre-del-fondo-del-hero-y-celda-compartida-del-grid.md, ADR-082-silo-f14-vinilos-inversos-kernel-y-contrato-boletos-link.md, ADR-073-columna-canonica-del-instante-del-evento-evento-inicio.md]
estado: vigente
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [DECISIONS.md](../DECISIONS.md) - [INDEX](../INDEX.md). ADR nuevo (2026-11-01); el indice de `DECISIONS.md` lo lista bajo **ADR-084** (siguiente libre tras ADR-083).

#### ADR-084: Contador del Landing en Zona Horaria de Bogota (UTC-5 Fijo) y Cleanup del Intervalo

* **ID:** ADR-084 | **Fecha:** 2026-11-01 | **Estado:** Implementado y verificado. Working tree con **2 archivos tocados** (`evento-app.html`, `git diff --numstat` = **+86 / -19**; `scripts/smoke_countdown_tz.js` **NUEVO**, 11.142 bytes) y **0 cambios en CSS / JS de silos / `admin.html` / `api/*.js` / SQL**. Los docs de cierre (`TASKS.md`, `NEXT.md`, `DECISIONS.md` + esta ficha) son aditivos.
* **Autor:** Orquestador de implementacion (tier PAGO, gate `AGENTS.md` seccion 2 confirmado por el usuario) con `@renderer-dev` (motor) y `@qa-auditor` (Escudo GOLD). Cierre documental con `@docs-keeper`.

## 1. Contexto (problema)

1. **El contador se calculaba en la zona horaria del DISPOSITIVO, no en la de la sede.** `parseSpanishDate()` (`evento-app.html`) construia el instante con `new Date('YYYY-MM-DDTHH:mm')`, un formato **sin sufijo de zona**. La especificacion de ECMAScript trata esa cadena como **hora local del entorno de ejecucion**, asi que cada navegador resolvia un epoch distinto para el mismo evento. Medido contra la version previa (`v123`, `git show HEAD`): en **UTC** el contador iba **5 h adelantado** (la fecha objetivo quedaba 5 h antes), en **Asia/Tokyo iba 14 h antes** y en **Europe/Madrid 6 h antes**.
2. **Por que era invisible en Bogota.** En `America/Bogota` (UTC-5) la hora del dispositivo **coincide** con la hora de la sede, de modo que el defecto **no se reproduce en la maquina del desarrollador ni en las pruebas locales**. Solo aparece con visitantes fuera de Colombia, que es exactamente el trafico de un landing publico de turismo/eventos.
3. **El `setInterval` del contador nunca se limpiaba.** El loader del landing se re-ejecuta al cambiar de idioma (`#i18n-sw`), y cada pasada creaba un intervalo nuevo sobre el **mismo DOM** sin cancelar el anterior: **un intervalo por pasada**. Al vencer el tiempo, el ultimo intervalo seguia vivo pintando el **ultimo valor congelado** en lugar de detenerse en ceros.
4. **Impacto transversal.** El defecto vive en el **motor compartido** `evento-app.html`, es decir afecta a los **14 silos** (no es un problema de un template ni de un evento). De ahi que exigiera tier **PAGO** y el **gate de confirmacion** de `AGENTS.md` seccion 2.
5. **Restriccion de contrato.** `parseSpanishDate(dateStr, timeStr) -> Date` tiene **2 llamadores** (el contador y el gate de fase `proximamente` del centinela de campana). Cambiar la firma o el tipo de retorno habria tocado ambos caminos; y cualquier reescritura debia respetar **Cero Borrado** (Oro #2): 0 IDs, 0 modulos y 0 atomos del contrato v210.

## 2. Decision

### 2.1 Offset fijo de Colombia (UTC-5) y epoch absoluto

```js
var __CO_OFFSET_MIN = -300;   // Colombia: UTC-5 todo el ano, sin horario de verano

function __horaA24(timeStr) { /* 'HH:MM' | 'H:MM' -> { hh, mm } | null */ }

// dentro de parseSpanishDate(dateStr, timeStr):
return new Date(Date.UTC(y, mo - 1, d, t.hh, t.mm) - (__CO_OFFSET_MIN * 60000));
```

* **Por que `-300` fijo y no `Intl`/`toLocaleString`.** El producto tiene **una sola sede** (Colombia) y Colombia **no aplica horario de verano**: el offset es constante (`UTC-5 = -300 min`) y **verificable a mano**. Se evita toda dependencia del `Intl`/tzdata del navegador, que varia con la version del sistema operativo (un dispositivo con base de zonas desactualizada daria otro resultado).
* **Por que `Date.UTC(...) - offset` y no concatenar el sufijo en la cadena.** `Date.UTC(y, mo-1, d, hh, mm)` devuelve el epoch de esos campos **como si fueran UTC**; restar `offset * 60000` lo desplaza al instante real de Bogota. El resultado es un **epoch absoluto** (`1795222800000` en el caso de prueba), **identico en cualquier `TZ` del dispositivo**.

### 2.2 Cleanup del intervalo

```js
const __cdTarget = parseSpanishDate(ev.fecha, ev.hora).getTime();
if (window.__cdTimer) { clearInterval(window.__cdTimer); window.__cdTimer = null; }
if (isFinite(__cdTarget)) {
    const __cdPaint = (diff) => { /* unica escritura en #cd-days/hours/mins/secs */ };
    const __cdTick  = () => {
        const diff = __cdTarget - Date.now();
        if (diff <= 0) { __cdPaint(0); __cdDone = true; return; }
        __cdPaint(diff);
    };
    __cdTick();
    window.__cdTimer = setInterval(() => {
        __cdTick();
        if (__cdDone) { clearInterval(window.__cdTimer); window.__cdTimer = null; }
    }, 1000);
}
```

* `clearInterval(window.__cdTimer)` ocurre **antes** de crear el intervalo nuevo: **una sola pasada puede tener un intervalo vivo** (verificado con un harness de 3 pasadas del loader -> **1 intervalo**).
* Al vencer, el intervalo **se auto-detiene** (`__cdDone` -> `__cdTimer = null`) y pinta `00:00:00:00`, en lugar de quedar vivo con el valor congelado.
* `__cdPaint` concentra la **unica escritura** del contador (una sola escritura `innerText`), para que el cleanup y los ceros no dupliquen caminos de pintado.

### 2.3 Fallbacks (contrato tolerante a datos sucios)

* **Fecha invalida:** `parseSpanishDate()` devuelve `new Date(NaN)`; la guarda `isFinite(__cdTarget)` impide crear el intervalo y **no se escribe nada en el DOM** (antes el DOM recibia el literal `NaN`).
* **Sin hora:** se usa `00:00` de Bogota como hora del evento.
* **Hora embebida en la fecha (`YYYY-MM-DDTHH:mm`):** se usa como respaldo si `eventos.hora` viene vacia.
* **Hora no canonica (`H:MM`, separador `.`):** `__horaA24()` la normaliza; si no es una hora valida devuelve `null` y el llamador decide el fallback.

## 3. Alternativas descartadas

1. **`new Date('YYYY-MM-DDTHH:mm' + '-05:00')`, es decir concatenar el sufijo de zona en la cadena.** Descartada por **fragilidad del formato de entrada**: `eventos.fecha` puede llegar con otra forma (fecha legada `DD/MM/AAAA`, valor vacio, hora ya embebida), y una concatenacion ciega produce `Invalid Date` o un offset duplicado. El calculo con `Date.UTC` mas el offset explicito es independiente de como venga la cadena.
2. **`toLocaleString('es-CO', { timeZone: 'America/Bogota' })` / `Intl.DateTimeFormat` con `timeZone`.** Descartada porque el contador necesita el **epoch numerico** para restar `Date.now()`, y `toLocaleString` devuelve **texto ya formateado**: recuperar el instante exige un **parseo inverso** (formatear y volver a interpretar), que es una segunda fuente de verdad y depende del `Intl`/tzdata del dispositivo. Se usaria para **mostrar**, no para **calcular**.
3. **Libreria externa de zonas horarias (Luxon, date-fns-tz, moment-timezone).** Descartada por **ADR-001 (Vanilla JS puro)**: prohibido introducir dependencias o build tools en runtime cliente. Ademas, para una sede unica con offset constante, la libreria solo aporta peso y una superficie de actualizacion (tzdata) que nadie mantendria.
4. **"Dejarlo asi porque en Bogota funciona".** Descartada de forma expresa: el landing es publico y su trafico es **mayoritariamente no colombiano**; que el defecto no se vea en la maquina del desarrollador es precisamente el motivo por el que sobrevivio hasta este ciclo. El argumento "funciona aqui" no es una verificacion.
5. **Reescribir el contador con `requestAnimationFrame` o un cronometro basado en `setTimeout` recursivo.** Descartada: no ataca la causa (la zona horaria) y cambia el contrato del motor sin necesidad. El cleanup se resuelve con `clearInterval` en el punto de re-entrada.

## 4. Consecuencias

* **Epoch absoluto:** el contador es ahora **identico en cualquier dispositivo del mundo** (verificado con 4 `TZ` distintas en proceso hijo, mismo epoch `1795222800000`). El offset queda **explicito** en el codigo y no depende del entorno.
* **Deuda declarada - CODIGO (baja), `evento-app.html:2770`:** `new Date(__tFase).getFullYear()` sigue leyendo en la zona del **DISPOSITIVO** el ano del **centinela de campana** (2099). No se corrigio: solo alimenta la comparacion `__yearFase >= 2090`, y el otro brazo de la condicion (`__tFase <= Date.now()`) es **absoluto**, asi que la **decision de fase no cambia**. Es cosmetico.
* **Deuda declarada - CODIGO (legacy), `eventovenezuela.html:787` y `eventologs.html:304`:** conservan el **patron v123** (2 ocurrencias cada uno). Son paginas legacy, **no el motor de los 14 silos**; si se promueven a produccion heredan el defecto de zona horaria.
* **Deuda declarada - DATOS (aceptada):** una fecha imposible como `2026-02-30` **desborda a marzo** via `Date.UTC` (`2026-03-03T01:00Z`). Aceptado: `eventos.fecha` es ISO y la escribe el admin con **selector de fecha**, que no produce dias inexistentes. Validar el calendario completo seria una capa nueva sin consumidor real.
* **Reutilizacion abierta:** TSK-119 (`#meta-hora` hoy `20:00 HRS`, la maqueta pide `8:00 PM`) **puede reutilizar `__horaA24()`**; no se ejecuto en este ciclo.
* **Cero deuda nueva de contrato:** `parseSpanishDate(dateStr, timeStr) -> Date` se conserva con sus **2 llamadores** y sin tocar IDs, modulos ni atomos (Cero Borrado, Oro #2).
* **Riesgo asumido:** si el producto abre una sede fuera de Colombia, el offset `-300` deja de ser correcto y debe salir de **datos** (o de un contrato nuevo por evento/sede), no de una constante.

## 5. Verificacion

| Comprobacion | Resultado |
|---|---|
| `node scripts/smoke_countdown_tz.js` (extrae el motor REAL del HTML) | **PASS 36 / FAIL 0** |
| Sondas de `TZ` en proceso hijo: UTC / Asia-Tokyo / America-Bogota / Europe-Madrid | epoch identico **1795222800000** en las 4 |
| Assert duro contra el signo invertido del offset | OK |
| `node scripts/smoke_f14_vinilos.js` (sin regresion) | **PASS 38 / FAIL 0** |
| `node scripts/smoke_hero_contract.js` | **PASS 64 / FAIL 0** |
| `node scripts/smoke_qa_asserts.js` | **PASS 64 / FAIL 0** |
| Escudo GOLD: `node --check` de los 2 `<script>` inline (167.413 bytes) | exit **0** |
| Lineas agregadas con bytes > 127 | **0** |
| Nuevas `display: none` | **0** |
| Balance de `<div>` antes/despues (`git show HEAD`) | **102 / 101**, identico (preexistente) |
| Harness de timers: 3 pasadas del loader | **1 intervalo vivo** |
| Harness de timers: al vencer | **0 intervalos**, `window.__cdTimer = null`, pinta `00:00:00:00` |
| Harness de timers: fecha invalida | **0 intervalos**, **0 escrituras DOM** |
| Archivos modificados | `evento-app.html` (**+86 / -19**) + `scripts/smoke_countdown_tz.js` (NUEVO, 11.142 bytes) |

## 6. Aprendizaje reutilizable

1. **Todo `new Date('YYYY-MM-DDTHH:mm')` sin sufijo de zona es hora del DISPOSITIVO.** No es "la hora del proyecto" ni "la hora de la sede": es la del navegador que lo ejecuta. En un landing publico eso es un defecto latente.
2. **Con sede unica, el offset debe ser explicito en el codigo** (`-300` documentado), no delegado a `Intl`/tzdata ni a la configuracion del sistema. Construir el instante con `Date.UTC(...) - offset` produce un epoch **absoluto** y verificable a mano.
3. **El smoke debe correr con varias `TZ`.** En la maquina del desarrollador (Bogota) el bug **no se ve**: por eso el harness lanza un proceso hijo por zona (`UTC`, `Asia/Tokyo`, `America/Bogota`, `Europe/Madrid`) y compara que el epoch sea **identico**, con un assert que falla si el signo del offset se invierte.
4. **Todo `setInterval` dentro de un loader re-ejecutable necesita `clearInterval` en el punto de re-entrada.** Un loader que corre de nuevo (cambio de idioma, re-render) multiplica intervalos sobre el mismo DOM; el patron correcto es "cancelar antes de crear" mas auto-detencion al cumplir la condicion, y una unica funcion de pintado.
