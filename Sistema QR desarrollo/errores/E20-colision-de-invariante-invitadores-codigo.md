---
doc: E20 (ERRORES_HISTORICOS.md §20)
version: v1.8.0-STABLE (heredada)
fecha: 2026-10-01
origen: ERRORES_HISTORICOS.md L284-295 (AMPLIACION/_backups/ERRORES_HISTORICOS.md.2026-10-01.bak)
version_previa: ERRORES_HISTORICOS.md v1.8.0-STABLE
relacionados: [../ERRORES_HISTORICOS.md, ../INDEX.md]
estado: vigente
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [ERRORES_HISTORICOS.md](../ERRORES_HISTORICOS.md) §20 · [INDEX](../INDEX.md). Texto original íntegro debajo (L284-295 del original).

## 20. Colision de Invariante: `invitadores.codigo` UNICO vs. el INSERT de un Link por Evento (`duplicate key "invitadores_codigo_key"`) (2026-09-30 — fix MODO EXPRESS)

*Esta falla pertenece a la familia "la UI asume una cardinalidad que la base no permite". No fue un bug de datos ni de red: era el **contrato de unicidad** de la tabla chocando con la logica de escritura. Se registra porque el patron es reutilizable: **antes de insertar una fila nueva con una clave natural que puede existir, verificar el constraint (o hacer upsert); no asumir que la clave es libre.***

### `generarLinkInvitador()` insertaba una fila nueva por link con el mismo `codigo`
* **Problema:** al generar un link de invitador (incluido el tipo nuevo `comunidad`), `admin.html` devolvia `duplicate key value violates unique constraint "invitadores_codigo_key"`; la fila no se creaba y el link no quedaba disponible.
* **Causa raiz:** `invitadores.codigo` es **UNICO** en la base (constraint `invitadores_codigo_key`), pero el modelo de escritura creaba **una fila "base" por invitador** (`crearInvitador()`, con `link_generado=''`) y luego, al generar cada link, `generarLinkInvitador()` **insertaba una fila adicional con el mismo `codigo`**. El chequeo previo `existe` solo miraba `codigo + evento_id`, por lo que la fila base (`evento_id` null) no hacia match -> se intentaba el INSERT -> violacion de unicidad.
* **Blindaje / leccion:** (1) **verificar el constraint antes de insertar** una clave natural (o usar `upsert`): una clave UNICA no se puede duplicar por conveniencia de UI; (2) **una cardinalidad, una fuente**: si la base es "un `codigo` = una fila", la UI no puede asumir "N links = N filas" sin una migracion que lo permita; (3) **los links siguen funcionando por `?ref`** aunque se conserve una sola fila vigente, porque la atribucion se resuelve por `codigo`, no por `id`.
* **Verificacion (fix, MODO EXPRESS):** `generarLinkInvitador()` (`admin.html`) ahora **resuelve la fila contra la base (no contra la cache `_invitadores`, filtrada por `org_id`)**: consulta `invitadores` por `codigo` y la **actualiza** por `id` si existe; solo inserta si el `codigo` es nuevo (fallback a UPDATE por `codigo` ante `23505`). Escudo GOLD PASS; `node scripts/express_check.js` -> **PASS 16 / FAIL 0**. **Sin migracion** (no se toco el esquema; se alineo el codigo al constraint). Registrado en `DECISIONS.md` ADR-061 (Ajustes finales), `TASKS.md` TSK-078 y `NEXT.md` hito -27.

---

