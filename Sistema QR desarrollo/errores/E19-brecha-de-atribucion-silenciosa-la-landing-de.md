---
doc: E19 (ERRORES_HISTORICOS.md §19)
version: v1.8.0-STABLE (heredada)
fecha: 2026-10-01
origen: ERRORES_HISTORICOS.md L272-283 (AMPLIACION/_backups/ERRORES_HISTORICOS.md.2026-10-01.bak)
version_previa: ERRORES_HISTORICOS.md v1.8.0-STABLE
relacionados: [../ERRORES_HISTORICOS.md, ../INDEX.md]
estado: vigente
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [ERRORES_HISTORICOS.md](../ERRORES_HISTORICOS.md) §19 · [INDEX](../INDEX.md). Texto original íntegro debajo (L272-283 del original).

## 19. Brecha de Atribucion Silenciosa: la Landing de Evento No Persistia el Invitador `?ref` (mientras `serie.html` si lo hacia) (2026-09-30 — implementacion ADR-061)

*Esta falla pertenece a la familia "el dato se captura bien, pero una de las vias de entrada no lo rutea". No hubo excepcion ni error de red: la landing guardaba el registro de comunidad correctamente, pero **descartaba el `?ref`** del link de invitador, de modo que la captura quedaba huerfana de atribucion. Se registra porque el patron es reutilizable: **cuando el mismo tipo de registro se captura en dos motores, la atribucion debe existir en los dos, no en uno.***

### El registro de comunidad desde la landing no guardaba `ref_codigo`/`ref_nombre` (la serie si) (evento `lanzamiento-mistico-64k6`)
* **Problema:** la landing de evento (`evento-app.html`) captura personas que se unen al grupo de WhatsApp e inserta en `inscritos` (`tipo='interesado'`, `respuestas_custom.origen='landing-interesado'`, `cuenta_aforo=false`). Antes de ADR-061 **no leia `?ref` ni persistia `ref_codigo`/`ref_nombre`**, mientras `serie.html` **si** lo hacia (`:457` lectura; `:667-668` y `:755-756` persistencia). Consecuencia: un link de invitador que llevaba a la landing no podia atribuir sus capturas; el panel de invitadores las veia "sin invitador".
* **Causa raiz:** **dos motores de captura con contratos distintos** — `serie.html` resolvia el invitador por `?ref` y lo persistia; `evento-app.html` no habia implementado esa atribucion. No habia error de consola ni de red: la landing insertaba el registro igual, solo **sin** las columnas de atribucion. La brecha se hizo visible al habilitar el **invitador tipo `comunidad`** (ADR-061), cuyo link apunta a la landing.
* **Blindaje / leccion:** (1) **atribucion en el borde, no en el registro** — todo campo de atribucion (`ref_codigo`/`ref_nombre`) debe resolverse en el punto de entrada (landing y serie) y persistirse en el INSERT; (2) **dos motores = doble checklist** — al aceptar capturas por mas de una via, verificar **cada via por separado** contra el contrato; (3) **fail-open**, nunca bloquear la captura por la atribucion: en `__HT_PREVIEW` hay **cero red** (ADR-008) y si la consulta del invitador falla, la landing continua sin atribucion (se pierde el dato, no la captura); (4) al agregar un **tipo de invitador nuevo** (aqui `comunidad`), auditar que el destino del link soporte la captura de `?ref` (la landing no lo hacia hasta ADR-061).
* **Verificacion (fix, ADR-061):** `evento-app.html` lee `?ref` (`:959`), resuelve el invitador en `invitadores` por `codigo` (`:985-988`, `maybeSingle()`, fail-open) y persiste `ref_codigo`/`ref_nombre` en el INSERT (`:2442-2443`). `admin.html` expone el valor en el sub-tab "Comunidad WhatsApp" (columna "Inscriptor / ref", `admin.html:9054-9058`). Escudo GOLD PASS; `node scripts/express_check.js` -> **PASS 16 / FAIL 0**. **Sin migracion** (columnas preexistentes; usadas ya por `serie.html` y el panel). Registrado en `TASKS.md` TSK-078, `NEXT.md` hito -27 y `DECISIONS.md` ADR-061.

---

