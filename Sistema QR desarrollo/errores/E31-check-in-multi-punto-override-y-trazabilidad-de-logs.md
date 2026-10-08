---
doc: E31 (ERRORES_HISTORICOS.md 31)
version: v1.8.0-STABLE (heredada)
fecha: 2026-10-07
origen: ERRORES_HISTORICOS.md seccion 31 (nueva, 2026-10-07). Bugs del ciclo ADR-079 (check-in multi-punto con override por ticket y trazabilidad de logs).
relacionados: [../ERRORES_HISTORICOS.md, ../INDEX.md, ../DECISIONS.md, ADR-079-checkin-multi-punto-con-override-por-ticket.md]
estado: vigente
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [ERRORES_HISTORICOS.md](../ERRORES_HISTORICOS.md) seccion 31 - [INDEX](../INDEX.md).

## 31. Bugs del Check-in Multi-punto con Override por Ticket y Trazabilidad de Logs (2026-10-07 - ADR-079)

> Los 7 bugs (a)-(g) se detectaron y corrigieron en el mismo ciclo que entrego ADR-079 (commits `a1a1fe1`, `13efe7c`, `eee3fec`). El smoke de regresion `scripts/smoke_checkin_multipunto.js` (27 asserts) queda como guard.

### A. `scanQR` seleccionaba una columna inexistente (`inscritos.puntos_acceso`)
* **Problema:** la consulta de escaneo incluia `inscritos.puntos_acceso` antes de que la migracion `adr079` creara esa columna; PostgreSQL devolvia error de columna inexistente y el flujo de check-in fallaba.
* **Causa raiz:** se escribio el lector del override antes que su fuente de datos (la migracion), invirtiendo el orden Data-First.
* **Blindaje:** Fase I (esquema/migracion aplicada) antes de Fase II (lectura/estetica). El smoke `smoke_checkin_multipunto.js` asserta que la columna se crea en la migracion.

### B. El undo borraba logs por `resultado='Ingreso'` y rompia el multi-punto
* **Problema:** `undoCheckinScanner` borraba por `qr_code` + `resultado='Ingreso'`, de modo que revertir un escaneo podia borrar el ingreso del mismo QR en OTROS puntos, no solo en el actual.
* **Causa raiz:** el criterio de borrado era "por resultado" en vez de "por punto".
* **Blindaje:** el undo se acota por `qr_code` + `punto_acceso` (`scanner.html:1082`), y el borrado offline se encola con `punto_acceso` (`:1082-1092`).

### C. Backtick roto en la plantilla de `undo-btn-${ins.id}`
* **Problema:** la plantilla HTML del boton de undo tenia un backtick mal cerrado (`undo-btn-${ins.id}`), rompiendo el template literal y el render del boton.
* **Causa raiz:** interpolacion anidada en el string del markup.
* **Blindaje:** plantilla corregida (`scanner.html:1005` / `:1048`).

### D. `logsCache` quedaba stale tras el undo
* **Problema:** al revertir un check-in no se invalidaba la entrada `qr|punto` de `logsCache`, asi que el siguiente escaneo del mismo punto se tomaba como duplicado aunque el log ya no existia.
* **Causa raiz:** la cache local se poblaba al escanear pero no se limpiaba al deshacer.
* **Blindaje:** invalidar la clave de cache en el mismo punto donde se escribe/borra (`scanner.html:1105`).

### E. Dedup offline filtraba `logs.evento` (el NOMBRE) en vez de `evento_id`
* **Problema:** la carga de la cache offline filtraba `logs.evento = nombre`, que no coincidia con ninguna fila (la columna guarda el NOMBRE del evento comparado contra un id); el conteo daba 0.
* **Causa raiz:** se uso la columna de nombre donde correspondia la FK canonica.
* **Blindaje:** el filtro es `.eq('evento_id', eventoId)` (`scanner.html:399-400`); el smoke asserta que `cargarCache` NO usa `.eq('evento', ...)`.

### F. `denyEntry` no poblaba `evento_id`/`inscrito_id`
* **Problema:** el log de entrada denegada se insertaba sin las nuevas columnas de trazabilidad, dejando los rechazos sin relacion canonica.
* **Causa raiz:** se migraron los inserts de confirmacion pero no el de rechazo.
* **Blindaje:** los 3 inserts de `logs` (confirm + deny) pueblan `evento_id`/`inscrito_id` (`scanner.html:1119`).

### G. `_crearSerie` no propagaba `puntos_acceso`
* **Problema:** al crear una serie de eventos, `_crearSerie` no copiaba `puntos_acceso`, asi que los eventos de la serie nacian sin configuracion de puntos.
* **Causa raiz:** el `INSERT` de la serie omitia el campo que el evento unico si escribia.
* **Blindaje:** `_crearSerie` incluye `puntos_acceso: getPuntosAcceso()` (`admin.html:7852`).

---

*Registro agregado el 2026-10-07 (ciclo ADR-079: check-in multi-punto con override por ticket y trazabilidad de logs). Los E01-E30 no se alteran (Cero Borrado).*
