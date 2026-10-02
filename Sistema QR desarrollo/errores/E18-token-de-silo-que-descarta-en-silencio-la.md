---
doc: E18 (ERRORES_HISTORICOS.md §18)
version: v1.8.0-STABLE (heredada)
fecha: 2026-10-01
origen: ERRORES_HISTORICOS.md L260-271 (AMPLIACION/_backups/ERRORES_HISTORICOS.md.2026-10-01.bak)
version_previa: ERRORES_HISTORICOS.md v1.8.0-STABLE
relacionados: [../ERRORES_HISTORICOS.md, ../INDEX.md]
estado: vigente
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [ERRORES_HISTORICOS.md](../ERRORES_HISTORICOS.md) §18 · [INDEX](../INDEX.md). Texto original íntegro debajo (L260-271 del original).

## 18. Token de Silo que Descarta en Silencio la Columna de Datos del Admin (`--f12-mapa-query` vs `eventos.ubicacion`) (2026-09-30 — fix CSS-only del silo F9B)

*Este bug pertenece a la familia "el dato llega bien y se muestra bien, pero **otra capa lo sobreescribe sin error**". No hubo excepcion, no hubo fallo de red, no hubo error en consola: solo un mapa abierto en el punto equivocado. Se registra porque **el patron es reutilizable** y porque la causa no es un descuido puntual sino una **convencion de los silos**.*

### 🚨 El MAPA de Google apuntaba a otro sitio mientras el texto de la direccion si era el correcto (silo `f9b`, evento `lanzamiento-mistico-64k6`)
* **Problema:** en el silo **f9b "Mistico Nocturno"** (`css/templates/fiesta/f9b.css`) el modulo `#mod-ubicacion` mostraba el **MAPA de Google en un punto que NO era el venue del evento**, mientras el **texto** de la direccion (la que el admin escribe en el input "Ubicacion", `#ev-ubic` -> columna `eventos.ubicacion`) **si salia correcto** — meta del hero (`evento-app.html:1441`) y footer (`:1812`). La persistencia nunca estuvo rota; el defecto era **exclusivamente del mapa**.
* **Causa raiz (verificada, ADR-006):** el silo declara un token **heredado por copia de otro silo**, `--f12-mapa-query`, cuyo nombre dice `f12` pero que lo lee **cualquier silo que lo declare** (repo-wide hoy: `f12.css:115` y `f9b.css:273`). El kernel lo consume en `evento-app.html:2181-2187`: **si el token trae valor**, arma `q=<lat>,<lng>&z=16` (o `ll=` si `--mapa-pin-nativo` != 1) y **`ev.ubicacion` se descarta por completo**; la rama `q=<ev.ubicacion>&z=15` **solo se ejecuta si el token esta vacio**. Es decir, **un token de silo es un override silencioso de una columna de la base de datos**. En `f9b` venia acompanado de `--mapa-pin-nativo: 1` (`:281`), de modo que el mapa se fijaba en la coordenada hardcodeada **con el pin nativo de Google encima** — el resultado visual mas convincente posible, y por eso nadie lo cuestiono. La coordenada era `4.634472590905041,-74.07471573777842`, una **copia de linea** que no correspondia al venue: Klandestino Bar (Cra 4 # 19-56, piso 4, Bogota) esta en `4.60393995301205,-74.06869074365889`, que es exactamente la que ya usaba `f12.css:115`.
* **Blindaje / leccion:** (1) **todo token que rigidice o descarte un campo de `eventos` debe estar cubierto por un smoke** que falle si el valor no es el esperado — aqui los checks existian, pero ninguno comparaba el **valor** contra el venue; (2) **al clonar un silo, los tokens con prefijo de otro silo deben auditarse**: no se heredan por compartir nombre, se heredan por copia de linea, y el prefijo `--f12-` conviviendo en `f9b` es la senal de alarma; (3) **"el texto sale bien" no prueba que el dato este bien ruteado** — cuando un dato se refleja en **mas de un consumidor** (meta, footer, mapa) hay que verificar **cada uno por separado**, porque pueden leer de fuentes distintas (columna vs. token de silo); (4) ningun token de silo debe poder **descartar en silencio** un campo persistido sin que exista una comprobacion mecanica que lo delate: el fallo es 100% invisible en consola y en red.
* **Verificacion (fix, 1 archivo, CSS-only):** `f9b.css` `--f12-mapa-query` corregido (`:273`), `--mapa-pin-nativo: 1` **conservado** (pin nativo exacto de Google), comentario del token actualizado con el venue y con los ejemplos de formato; `git diff --stat` = 1 archivo, 6 insertions(+), 3 deletions(-); llaves 376/376 (delta 0), `no_ascii=0`. Checks: `node scripts/smoke_f9b_mistico_nocturno.js` -> **PASS 103 / FAIL 0** (**H12** `--mapa-pin-nativo: 1` activo; **H14** formato `lat,long` sin espacios; **H15** armado `q=<coords>&z=16` del kernel); `express_check.js` -> **SKIP esperado** (extension `.css` no soportada; no es un fallo). Barrido de residuos de la coordenada vieja en `css/**/*.css`, `*.html` y `api/*.js` = **0**. `evento-app.html` y `admin.html` **NO se tocaron**; 0 migraciones, 0 endpoints, 0 IDs del Contrato de Datos v112 afectados (Cero Borrado intacto). **Sin decision de arquitectura nueva -> no se creo ADR** y `DECISIONS.md` no se toco. Registrado en `TASKS.md` TSK-077 y `NEXT.md` hito -26.

---

