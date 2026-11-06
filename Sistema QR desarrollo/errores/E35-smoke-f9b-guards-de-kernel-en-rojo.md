---
doc: E35 (ERRORES_HISTORICOS.md 35)
version: v1.8.0-STABLE (heredada)
fecha: 2026-11-05
origen: ERRORES_HISTORICOS.md seccion 35 (nueva, 2026-11-05). Detectado al correr la bateria de smokes despues del commit ab37cba (`feat(admin): evento de ejemplo por plantilla en el ADN visual`, solo `admin.html` + `scripts/smoke_adn_muestra_preview.js`).
relacionados: [../ERRORES_HISTORICOS.md, ../INDEX.md, ../NEXT.md, ../TASKS.md, ../evento-app.html, ../scripts/smoke_f9b_mistico_nocturno.js]
estado: ABIERTO (preexistente a ab37cba; causa raiz por diagnosticar)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [ERRORES_HISTORICOS.md](../ERRORES_HISTORICOS.md) seccion 35 - [INDEX](../INDEX.md).

## 35. Smoke f9b en rojo: 3 guards del kernel (`__esF9Meta`, H13 `map-own-pin`, H15 `q=`/`ll=`) (2026-11-05 - preexistente a ab37cba)

### A. Sintoma

`node scripts/smoke_f9b_mistico_nocturno.js` -> **PASS 100 / FAIL 3 / exit 1**. Los tres asserts que fallan:

1. `subconmutacion 1 (__esF9Meta / meta 2 lineas) usa __esFamiliaF9` (`scripts/smoke_f9b_mistico_nocturno.js:196` exige el literal `const __esF9Meta = __FamiliaF9();` en el kernel).
2. `H13: el kernel agrega map-own-pin solo con --f12-mapa-query y SIN --mapa-pin-nativo (y la retira si no) -> add=false remove=true` (`smoke L1121-1126`): el guard no encuentra el patron `if (__mapaQuerySilo && !__mapaPinNativo) { ... classList.add('map-own-pin') }`; si encuentra `classList.remove('map-own-pin')`.
3. `H15: el kernel usa q=<coords>&z=16 con --mapa-pin-nativo:1 (pin de Google) y mantiene ll= para el modo pin propio -> q=false ll=false` (`smoke L1139-1144`): no matchean `q=${encodeURIComponent(__mapaQuerySilo)}&t=&z=16` ni `ll=${encodeURIComponent(__mapaQuerySilo)}&z=16`.

Sintoma observable a verificar en producto (no medido en este registro): comportamiento del pin del mapa en las paginas publicas.

### B. Estado y alcance

* **ABIERTO. Preexistente al commit `ab37cba`.** Ese commit solo toca `admin.html` y `scripts/smoke_adn_muestra_preview.js`; `evento-app.html` (203.886 bytes) quedo intacto.
* Al momento del hallazgo: `git status --porcelain` vacio y `git diff --stat HEAD` vacio (arbol limpio en `ab37cba`), por lo que el rojo no se reproduce por el cambio de admin.
* El rojo de `smoke_f9b` ya estaba registrado como deuda en cierres previos: `NEXT.md` (hito del 2026-11-01) reporta **PASS 102 / FAIL 1** en `subconmutacion 1`, y los cierres del silo f14 lo citan como FAIL historico de `smoke_all`. Aqui el rojo se amplia a **3** asserts.

### C. Por diagnosticar (causa raiz NO establecida)

No se afirma regresion de producto ni se decide el fix. Verificado contra el archivo real (ADR-006) solo la diferencia de FORMA entre lo que el guard espera y lo que el kernel contiene hoy:

* `evento-app.html:1592`: `const __esF9Meta = __esMeta2Lineas();` (el guard espera `__esFamiliaF9()`).
* `evento-app.html:2460-2463`: `if (!__mapaPinNativo || !__mapaQuery) { add('map-own-pin') } else { remove('map-own-pin') }` (el guard espera `if (__mapaQuerySilo && !__mapaPinNativo)`); comentario del propio kernel: criterio v1.15.1 (ADR-088).
* `evento-app.html:2440-2441`: la URL se arma con `__mapaQuery` (token del silo o `eventos.lat`/`eventos.lng`), no con `__mapaQuerySilo`; `q=`, `ll=` y `z=16` siguen presentes en el texto.

Queda por determinar si el cambio de forma es **solo textual** (guards desactualizados con producto correcto) o si hay un **cambio de comportamiento** que exige fix. Verificacion sugerida: abrir el embed de `lanzamiento-mistico-64k6` (silo `f9b`, `--mapa-pin-nativo: 1`) y el de un silo sin token, y comparar pin/encuadre en runtime.

### D. Como reproducir

`node scripts/smoke_f9b_mistico_nocturno.js` -> PASS 100 / FAIL 3, exit 1. No requiere datos ni red: los tres asserts son estaticos (regex sobre el texto de `evento-app.html`).

### E. Impacto

* Riesgo en el **pin de mapa de las paginas publicas**: `map-own-pin` decide si el pin lo pinta el silo o Google, y `q=` / `ll=` deciden el encuadre; una deteccion equivocada del modo deja el pin en el punto equivocado, duplicado o sin marcador visible.
* **No bloquea el admin** ni el cambio de `ab37cba`; el rojo es de la bateria, no del codigo de admin.
* Mientras siga abierto, `smoke_all` no puede declararse en verde.

### F. Responsable y siguiente paso

* Dominio: **`@renderer-dev`** (motor de render `evento-app.html`). Cualquier ajuste al kernel exige el gate de confirmacion de PAGO (motor de render); el ajuste al guard es de `scripts/smoke_f9b_mistico_nocturno.js`.
* Este registro es **documental**: 0 cambios en `evento-app.html`, 0 cambios en el smoke, 0 migraciones, 0 commits. `evento-app.html` y el guard se dejan como estan (Cero Borrado).
