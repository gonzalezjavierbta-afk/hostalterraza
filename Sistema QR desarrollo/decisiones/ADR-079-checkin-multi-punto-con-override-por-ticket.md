---
doc: ADR-079
version: v1.18-GOLD (heredada de DECISIONS.md)
fecha: 2026-10-07
origen: Check-in multi-punto con override por ticket y trazabilidad de logs. Migracion aplicada a produccion ctgyvydzshueemlelkzv (gate AGENTS.md seccion 2 autorizado, 2026-10-07).
version_previa: ADR-078
relacionados: [../DECISIONS.md, ../INDEX.md, ADR-073-columna-canonica-del-instante-del-evento-evento-inicio.md, ADR-078-cron-de-recordatorios-automaticos.md]
estado: aplicado (ver campo Estado dentro del ADR)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [DECISIONS.md](../DECISIONS.md) - [INDEX](../INDEX.md).

## ADR-079: Check-in multi-punto con override por ticket y trazabilidad de logs

**Fecha:** 2026-10-07

**Autor:** @backend-dev / @admin-dev / @js-silo-dev (implementacion); migracion `migrations/adr079_multi_punto_override.sql` escrita y aplicada por @data-migration. Cierre documental a cargo de @docs-keeper. Gate de riesgo de `AGENTS.md` seccion 2 (esquema/migraciones) AUTORIZADO por Direccion.

**Estado:** APLICADO Y VERIFICADO. Migracion APLICADA a la BD `ctgyvydzshueemlelkzv` (2026-10-07). Smoke de regresion `scripts/smoke_checkin_multipunto.js` -> **PASS 27 / FAIL 0**.

**Problema:** el check-in multi-punto basico ya existia: `eventos.puntos_acceso` (jsonb, array de strings) define los puntos de un evento, `scanner_tokens.punto_acceso` fija UN punto por link de portero y `logs.punto_acceso` guarda el punto del escaneo. El mismo QR era valido en cada punto distinto del evento porque la regla era puramente a nivel de evento. Faltaba (1) poder restringir los puntos de UN ticket concreto sin cambiar la regla del evento entero, y (2) que `logs` pudiera relacionar cada escaneo con el evento y con el inscrito de forma canonica, en vez de guardar solo el NOMBRE del evento (`logs.evento`, text).

**Contexto (esquema real, Fase 0 por @sql-security):**
- `eventos.puntos_acceso` = jsonb (array de strings). EXISTE.
- `inscritos.puntos_acceso` NO existia: es la columna que crea esta migracion.
- `scanner_tokens.punto_acceso` = text; `logs.punto_acceso` = text.
- `eventos.id`, `inscritos.id` y `logs.id` son TEXT, no uuid: por eso las columnas FK y las referencias son text (FK text -> text). No se convierte ningun id.
- `logs` NO tenia `evento_id` ni `inscrito_id`; su unica FK previa era a `organizaciones`, y `logs.evento` guarda el NOMBRE del evento.
- Backfill `logs.evento` -> evento por NOMBRE: 44 de 66 registros matchean de forma exacta y no ambigua. `logs.qr_code` -> `inscritos.qr_code`: 0 de 18 (no hay base para relacionar el log con un inscrito).

**Opciones:**
- (A) Mantener la regla solo a nivel de evento (`eventos.puntos_acceso`): no permite restringir un ticket puntual (p. ej. una entrada VIP valida solo en un punto) sin duplicar eventos; descartada.
- (B) Override por `scanner_tokens.punto_acceso` (un punto por link de portero): el token fija el punto del operador, no las restricciones del asistente, y obligaria a reemitir links; descartada.
- (C) Override por TICKET: columna aditiva `inscritos.puntos_acceso` (jsonb) que, si no esta vacia, gana sobre la lista base del evento. Elegida.

**Decision:** tres piezas en `migrations/adr079_multi_punto_override.sql` (**260 lineas, 12.700 bytes, 0 bytes > 127**, ADR-002), en 6 bloques + verificacion y ROLLBACK:

1. **Columna de override por ticket** (BLOQUE 1, `:89-93`): `ALTER TABLE public.inscritos ADD COLUMN IF NOT EXISTS puntos_acceso jsonb DEFAULT NULL;`. jsonb (no `text[]`) por simetria de tipo con `eventos.puntos_acceso`. `NULL` y `[]` significan "sin override, hereda el evento". Se agrega al FINAL de la tabla.
2. **Columnas de trazabilidad en logs** (BLOQUE 2, `:103-113`): `logs.evento_id text` y `logs.inscrito_id text`, aditivas y nullable, con `COMMENT ON COLUMN`.
3. **Claves foraneas** (BLOQUE 3, `:117-152`): `logs_evento_id_fkey` -> `eventos(id)` y `logs_inscrito_id_fkey` -> `inscritos(id)`, ambas **ON DELETE SET NULL**. ADD CONSTRAINT no admite IF NOT EXISTS, por eso cada FK va en un bloque DO con guard sobre `pg_constraint`. SET NULL y no CASCADE: si un evento o un inscrito desaparece, el log de auditoria se PRESERVA.
4. **Backfill de `logs.evento_id`** (BLOQUE 4, `:157-171`): escribe solo donde `evento_id IS NULL` y solo cuando el match por NOMBRE es exacto y NO ambiguo (`HAVING count(*) = 1`). `logs.evento` (el nombre) NO se renombra ni se borra: se conserva como dato de origen.
5. **Indice** (BLOQUE 5, `:186-189`): `idx_logs_qr_punto (qr_code, punto_acceso)`, exactamente el predicado de la consulta caliente del scanner.
6. **Recarga del schema cache de PostgREST** (BLOQUE 6): `NOTIFY pgrst, 'reload schema'`.

**Regla efectiva en el scanner** (`scanner.html:846-860`, verificada contra el archivo):

```
override = data.puntos_acceso;
base     = window._evData?.puntos_acceso;
allowed  = (Array.isArray(override) && override.length > 0) ? override : (Array.isArray(base) ? base : []);
if (!allowed.includes(puntoAcceso)) { ... "Punto no autorizado" ... }
```

Es decir, `allowed = override no vacio ? override : eventos.puntos_acceso`. Ninguna otra ruta cambia.

**Bugs corregidos en el mismo ciclo (implementacion):**
- `scanQR` seleccionaba una columna inexistente: el filtro de dedup offline usaba `logs.evento` (el NOMBRE) y daba 0; corregido a `.eq('evento_id', eventoId)`.
- El undo se hacia "por resultado" y no por punto: ahora borra por `qr_code` + `punto_acceso` (`scanner.html:1082`), con borrado diferido del log offline (`:1082-1092`).
- Backticks/esquema en la plantilla del boton de undo (`undo-btn`, `scanner.html:1005` / `:1048`).
- `logsCache` quedaba obsoleto entre escaneos; `cargarCache` ahora lo puebla desde `logs` (`scanner.html:399-404`).
- Dedup offline por `evento_id` (antes filtraba `logs.evento` = nombre), `denyEntry` ahora pobla `evento_id`/`inscrito_id` (`scanner.html:1119`) y `_crearSerie` propaga `puntos_acceso` (`admin.html:7852`).

**UI admin (aditiva):** editor rapido de puntos del evento post-creacion (`#mod-puntos-ev`, `admin.html:2607`; `cerrarPuntosEvento`), selector de puntos permitidos en el registro manual, editor por inscrito (`openPuntosInscrito`, `admin.html:6753`; boton "Puntos" en la tarjeta del asistente, `:9903`) y badge de puntos en la tarjeta. El editor por inscrito muestra la UNION base+override para no perder de vista puntos heredados.

**Lo que NO se toco (deliberado):**
- `eventos.puntos_acceso` NO se reescribe; `logs.evento` (nombre) NO se renombra ni se borra (Cero Borrado, Oro #2).
- No se borra ninguna fila y no hay DROP/DELETE/TRUNCATE en la migracion.
- No se backfillea `inscrito_id`: 0 de 18 coincidencias; forzarlo seria inventar una relacion que los datos no prueban.
- No se toca ninguna politica RLS existente.
- El override **NO se expone** en los registros publicos (`registroaforo.html`, `evento-app.html`) por diseno.

**Consecuencias / deuda residual registrada (hoy formalizada como TSK-108..TSK-111 en `TASKS.md`):**
1. La RLS anonima de `logs` con las columnas nuevas NO se verifico en vivo.
2. `logs.evento_id` no es backfilleable en 22 de 66 filas (sin match exacto por nombre); `inscrito_id` historico queda 100% NULL hasta que el emisor lo escriba.
3. El override no esta disponible en los registros publicos (`registroaforo.html`, `evento-app.html`); es diseno, no bug.
4. `openPuntosInscrito` muestra la union base+override (util, pero oculta cual punto es herencia y cual es propio).

**Impacto:** 1 columna nueva (`inscritos.puntos_acceso`), 2 columnas nuevas (`logs.evento_id`, `logs.inscrito_id`), 2 FK (SET NULL) y 1 indice; 44/66 logs historicos con `evento_id`; 0 filas borradas; 0 politicas RLS tocadas.

**Evidencia verificada contra el archivo real (ADR-006 - prevalece el archivo):**
- `migrations/adr079_multi_punto_override.sql`: existe, **260 lineas**, **12.700 bytes**, **0 bytes > 127**. Anclas: `:89` ADD COLUMN, `:134-136` FK evento, `:149-151` FK inscrito, `:169` UPDATE de backfill, `:186` CREATE INDEX, `:250` ROLLBACK.
- `scripts/smoke_checkin_multipunto.js` ejecutado: **PASS 27 / FAIL 0** (analisis estatico del cableado en `scanner.html`, `admin.html` y la migracion).
- Commits en `main`: **`a1a1fe1`** (multi-punto configurable y fixes de escaneo), **`e7be4ea`** (migracion adr079), **`13efe7c`** (override por ticket y trazabilidad), **`eee3fec`** (dedup offline por evento_id, denyEntry, union en editor), **`7468ed6`** (smoke de regresion + UX de herencia).

**Pendiente (formalizado como TSK-108..TSK-111 en `TASKS.md`):** verificar en vivo la RLS anonima de `logs` con las columnas nuevas (TSK-108); decidir si `inscrito_id` se backfillea en algun momento (hoy no hay base) y si el override se expone en registros publicos (TSK-109 / TSK-110).
