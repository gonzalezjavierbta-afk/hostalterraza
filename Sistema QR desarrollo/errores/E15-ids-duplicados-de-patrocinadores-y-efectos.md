---
doc: E15 (ERRORES_HISTORICOS.md §15)
version: v1.8.0-STABLE (heredada)
fecha: 2026-10-01
origen: ERRORES_HISTORICOS.md L199-219 (AMPLIACION/_backups/ERRORES_HISTORICOS.md.2026-10-01.bak)
version_previa: ERRORES_HISTORICOS.md v1.8.0-STABLE
relacionados: [../ERRORES_HISTORICOS.md, ../INDEX.md]
estado: vigente
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [ERRORES_HISTORICOS.md](../ERRORES_HISTORICOS.md) §15 · [INDEX](../INDEX.md). Texto original íntegro debajo (L199-219 del original).

## 15. IDs Duplicados de Patrocinadores y Efectos sin Consumidor en `admin.html` (2026-09-26 — paquete ADR-055/056)

### IDs duplicados de patrocinadores y la premisa falsa de `getElementById`
* **Problema:** `admin.html` tenia DOS bloques de patrocinadores con los mismos ids (`#sponsors-entries` x2, `#sponsors-add` x2: `admin.html:767-768` y `:790-791`). La premisa documentada era "solo el segundo bloque es alcanzable por `getElementById`".
* **Causa raiz real (verificada, ADR-006):** es **FALSO que se use `getElementById`** para esos ids. La UI enlaza **ambos** botones con `querySelectorAll('#sponsors-add')` (`admin.html:3755`) y resuelve el contenedor por **consulta acotada al panel** (`addBtn.closest('[id^="ld-campo-sponsors"]')` -> `panel.querySelector('#sponsors-entries')`, `:3756-3757`). De modo que **ambos paneles son operables**; la ambiguedad real era de **seleccion por categoria** (`activeContainer(suf)`, `:3884-3893`). Tambien era FALSO que "L4159 sin sufijo pierde los datos": su valor es **sobrescrito por el spread** `...(sponsors.length ? {sponsors} : {})` (`:4195`).
* **Correccion/blindaje:** consolidar a un unico bloque y **re-apuntar las tres claves de `modMap`** (`:3623`/`:3633`/`:3642`) al mismo contenedor + simplificar `activeContainer` **en el mismo cambio**; de lo contrario el **P0 real** es que desaparece el panel de patrocinadores de un evento de fiesta. Leccion: **no asumir que un id duplicado es inalcanzable** — verificar SIEMPRE como lo obtiene el codigo (por id global, por panel o por `closest`).
* **Verificacion:** documentado en ADR-056 (filas 1-3 + Riesgo 1 + Justificacion 1, corregidos); `hideForeignModulesByType` re-apuntado (`admin.html:5490-5500`).

### Efectos sin consumidor: defaults invertidos y `fx-explicit` siempre presente
* **Problema:** los 4 checkboxes de efectos (`ld-fx-grain`/`glow`/`vhs`/`parallax`) se persistian pero **nadie los leia** (dato muerto). Ademas los defaults del HTML estaban **invertidos** respecto al contrato ADR-055 (glow ON / parallax OFF, cuando `f9b` exige parallax ON y el resto OFF) — hallazgo MEDIA-1 de la revision.
* **Causa raiz:** el canal de datos->presentacion estaba a medias (solo escritura). Al cablearlo (kernel lee `effects`), el default del formulario contradecia el default del silo.
* **Correccion/blindaje:** (a) el kernel ahora traduce `effects` a clases (`__aplicarEfectosLanding`, `evento-app.html:799-815`, aplicado en `:1010`); (b) `_aplicarPresetTheme('mistico-nocturno')` (`admin.html:3508-3515`) **fija** los 4 defaults correctos al elegir el theme (desviacion deliberada: el admin SI cambia en este punto, ver ADR-055 R8). **`_buildConfigLanding` emite siempre `effects`** (`admin.html:4230-4235`), por lo que **`fx-explicit` esta siempre presente** cuando el evento pasa por el Wizard: bajo la regla 4.1 de ADR-055, eso **anula los defaults del silo** y todo depende de las clases positivas emitidas. Leccion: al cablear un dato que estaba muerto, **auditar que el default del emisor coincida con el default esperado del consumidor**.
* **Verificacion:** `express_check` PASS 12 / FAIL 0; smoke f9b PASS 61 / FAIL 0 (comprueba `effects = {grain:false, glow:false, vhs:false, parallax:true}` -> `fx-explicit` + `fx-parallax`); grep repo-wide de `fx-*`: **0 consumidores fuera de `f9b.css`** (solo `eventobackup.html` —contraejemplo— y el smoke).

### Deuda documental detectada (comentarios inline con lineas viejas)
* **Problema:** algunos comentarios inline de codigo arrastran citas de lineas desincronizadas: en `evento-app.html`, el comentario de `:829` cita `evento-app.html:870` (real, `__posterUrlDeEvento`) y el de `:886` cita `:906` (real, dentro de `__evDesdePreview`). Igual en `admin.html` (comentarios ADR-056).
* **Naturaleza:** deuda **documental** (no funcional); no se edita aqui porque es codigo (dominio de `@renderer-dev`/`@admin-dev`). Registrada en `NEXT.md` para un pase de limpieza.
* **Verificacion:** confirmado por lectura directa de `evento-app.html` (2026-09-26).

---

