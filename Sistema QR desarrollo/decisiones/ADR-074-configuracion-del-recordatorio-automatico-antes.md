---
doc: ADR-074
version: v1.17-GOLD (heredada de DECISIONS.md)
fecha: 2026-10-03
origen: sesion FREE 2026-10-03 (@sql-security + @data-migration; migracion escrita el 2026-10-03 y APLICADA en la Fase 2A del 2026-10-03, cierre documental posterior). Gate de riesgo AGENTS.md seccion 2: AUTORIZADO por Direccion 2026-10-03.
version_previa: DECISIONS.md v1.17-GOLD
relacionados: [../DECISIONS.md, ../INDEX.md, ADR-073-columna-canonica-del-instante-del-evento-evento-inicio.md, ADR-076-camino-unico-de-envio-de-correo-con-secreto.md, ADR-072-atribucion-del-link-de-invitador-en-la-telemetria-del.md]
estado: vigente (ver campo Estado dentro del ADR)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [DECISIONS.md](../DECISIONS.md) - [INDEX](../INDEX.md).

## ADR-074: Configuracion del recordatorio automatico (`config_recordatorios`)

**Fecha:** 2026-10-03

**Autor:** @sql-security + @data-migration (migracion escrita el 2026-10-03); cierre documental a cargo de @docs-keeper. Gate de riesgo de `AGENTS.md` seccion 2 (esquema) AUTORIZADO por Direccion el 2026-10-03; **la migracion se APLICO en la Fase 2A del 2026-10-03** (despues de ADR-073, como exige la dependencia).

**Estado:** APLICADA Y VERIFICADA (2026-10-03, TSK-104). La migracion **esta aplicada en base de datos** y su bloque de VERIFICACION comentado dio lo esperado. Requiere **ADR-073 aplicada** antes: esa dependencia se respeta, ADR-073 se aplico primero.

> **Nota de cierre (Fase 2A):** el **header del propio archivo (`:63-64`) sigue declarando `ESTADO: ESCRITO, NO APLICADO`**, frase que quedó **desactualizada** frente a la realidad de la base de datos. **NO se corrige** porque las migraciones aplicadas son intocables en este cierre documental (Cero Borrado de codigo). La verdad vigente es la de esta seccion: **APLICADA Y VERIFICADA (2026-10-03)**.

**Problema:** el recordatorio automatico (TSK-003) debe dispararse N horas antes del evento. Con N escrito a mano en el codigo del futuro cron, cambiarlo es un despliegue. El valor pedido hoy es 56 h, asi que la pregunta correcta no es "que constante uso" sino "donde vive el valor, y quien gana cuando hay dos valores".

**Contexto:** depende de `eventos.evento_inicio` de ADR-073 (`migrations/adr074_config_recordatorios.sql:11-12`): sin instante canonico no hay forma de calcular "faltan N horas". Esta migracion es **solo la capa de configuracion y su lectura**: no crea cron, ni trigger de envio, ni Edge Function (`:13-14`).

**Opciones:**
- (A) Constante `56` en el codigo del cron: cero_objects de esquema, pero el cambio de valor exige despliegue y no queda traza de "que valor se uso para este evento", descartada.
- (B) Una columna en `eventos` (`horas_recordatorio`): mezcla la configuracion global del operador con el dato de negocio del evento, y obliga a migrar `eventos` para un valor que hoy es global, descartada.
- (C) Tabla propia de configuracion con dos niveles (global / override por evento) y un resolver: elegida.

**Decision:** un solo objeto de esquema en `migrations/adr074_config_recordatorios.sql` (**515 lineas, 24.991 bytes, 0 bytes > 127**, ADR-002; antes de la Fase 2A eran 452 lineas / 21.256 bytes), en 7 bloques + bloque de verificacion y ROLLBACK:

1. **Tabla** `BLOQUE 1` (`:72-96`): `CREATE TABLE IF NOT EXISTS public.config_recordatorios` (`:84`) con `evento_id text` **NULLABLE y `UNIQUE`** (`:86`), `horas_anticipacion integer NOT NULL DEFAULT 56` (`:88`), `canal text` y `activa boolean`. **`evento_id` es `text`, NO `uuid`:** `eventos.id` es `text` en produccion, y una FK `text -> uuid` no se puede implementar.
2. **CHECK constraints** `BLOQUE 2` (`:97-142`): `horas_anticipacion > 0 AND <= 720` (30 dias; abajo de 0 no es recordatorio, es ruido o envio inmediato; mas de 720 h es un aviso que llega antes de que el evento exista en la agenda) (`:115`) y `canal IN ('email')` (`:129`; `:41-43`: se amplia el CHECK cuando exista el canal, no se deja libre para no crear filas con un canal que nadie procesa).
3. **FK de `evento_id`** `BLOQUE 3` (`:143-249`), condicional y fail-safe: solo se crea si `eventos` existe **y los dos tipos coinciden en el catalogo** (`v_tipo_config` / `v_tipo_eventos`, `:143-216`). Con `WARNING` explicito si no coinciden, y sin FK cuando `eventos` no tiene PK/UNIQUE sobre `id`.
4. **Una sola fila global, garantizada por el motor** `BLOQUE 3b` (`:250-278`): `CREATE UNIQUE INDEX IF NOT EXISTS idx_config_recordatorios_global` (`:273`) **parcial** sobre `evento_id IS NULL`. Esto es la pieza que resuelve la advertencia de PostgreSQL: **en un UNIQUE los NULL no chocan entre si**, asi que `UNIQUE (evento_id)` **NO impide** varias filas globales. Tres capas, no una: indice unico parcial + `INSERT` global con `WHERE NOT EXISTS` (`:294-302`) + resolucion determinista del caso multi-global (`BLOQUE 6`, `:327-330`, `:363` y `:371`). Si quedaran dos globales de un intento previo con error, el `CREATE UNIQUE INDEX` falla aqui y se ve en la misma corrida.
5. **Fila global por defecto** `BLOQUE 4` (`:279-305`): `INSERT ... SELECT NULL, true, 56, 'email' WHERE NOT EXISTS (...)` (`:294-302`), con el **56 explicito** y no solo por default (`:289`), y **no reescribe** el 56 si la fila ya existe con otro valor (`:281-287`).
6. **RLS fail-closed** `BLOQUE 5` (`:306-320`): se activa RLS en la tabla nueva (`:317`) y **NO se crea ninguna politica**. Con RLS activa y cero politicas, `anon` y `authenticated` no ven ni una fila. Es lo correcto para una tabla de configuracion que hoy no tiene consumidor; **cuando exista el backend del recordatorio habra que abrir lectura explicitamente** (politica SELECT para `authenticated`, o mover el resolver a `SECURITY DEFINER`). Las politicas de las demas tablas **no se tocan**.
7. **Resolver** `BLOQUE 6` (`:321-380`): `public.fn_horas_recordatorio(p_evento_id text)` (`:352`) con precedencia **override del evento -> fila global -> constante 56** (`:357-376`, constante en `:375`). **El parametro es `text`, no `uuid`, y no es cosmetico** (`:345-350`): con el parametro en `uuid`, `c.evento_id = p_evento_id` seria `text = uuid`, comparacion sin operador de igualdad en PostgreSQL, y el resolver fallaria en runtime. El ultimo escalon es un ultimo recurso, no la norma: el `ORDER BY/LIMIT 1` es la red, no el diseño.
8. **Recarga del schema cache de PostgREST** `BLOQUE 7` (`:381-389`).

**El default global de 56 h es una DECISION DE NEGOCIO, no un valor tecnico** (`:16-20`): 56 h deja margen para un recordatorio de confirmacion y otro el dia previo sin que ambos caigan el mismo dia. Si Direccion quiere otro numero, se `UPDATE`a la fila global: no hace falta tocar codigo ni volver a correr la migracion.

**Lo que NO se toco (deliberado):**
- **No crea cron, ni trigger de envio, ni Edge Function** (`:13-14`). El disparador sigue siendo TSK-003.
- **No altera ninguna tabla existente**, no borra filas y **no modifica ninguna politica RLS existente**: solo activa RLS en la tabla nueva.
- **No inventa el override por evento**: no hay fila por evento, solo la global. Los overrides los crea el operador cuando los necesite.

**Idempotencia:** 100% (`:45-48`). `CREATE TABLE IF NOT EXISTS`, dos bloques `DO` con guarda en `pg_constraint` (uno por CHECK y otro por la FK), `CREATE UNIQUE INDEX IF NOT EXISTS` e `INSERT` global con `WHERE NOT EXISTS`. Se puede ejecutar 2+ veces seguidas sin error y sin duplicar la fila global.

**Consecuencias (registro obligatorio):**
- **Hoy la tabla es inerte y no se ve desde el cliente.** RLS activa sin politicas = nadie lee; el unico consumidor real seran el cron y la RPC futuras. Es fail-closed a proposito, no un olvido.
- **Si el backend del recordatorio se implementa como una Edge Function que consulta la tabla con `authenticated`, vera el 56 de la constante y no la fila global** (`:339-342`, `:357-376`): ese es el fallo silencioso a vigilar cuando exista el backend. La salida es abrir lectura explicita o mover el resolver a `SECURITY DEFINER`, ambas cosas **fuera de este ADR**.
- **El caso multi-global no es imposible por construccion, es improbable:** las 3 capas lo hacen visible (falla el indice) y determinista al leer. Si aparece, hay que depurar datos, no cambiar el resolver.

**Impacto:** 1 tabla nueva, 2 CHECK, 1 FK condicional, 1 indice unico parcial, 1 fila global, RLS activada, 1 funcion resolver. 0 tablas alteradas, 0 filas borradas, 0 politicas existentes modificadas.

**Evidencia verificada contra el archivo real (ADR-006 — prevalece el archivo):**
- `migrations/adr074_config_recordatorios.sql`: existe, **515 lineas**, **24.991 bytes**, **0 bytes > 127** (verificado byte a byte en el cierre de la Fase 2A, 2026-10-03). Cifras previas: 452 lineas / 21.256 bytes.
- Anclas: `:84` `CREATE TABLE IF NOT EXISTS public.config_recordatorios`; `:86` `evento_id text UNIQUE`; `:88` `DEFAULT 56`; `:115` CHECK de horas `> 0 AND <= 720`; `:129` CHECK `canal IN ('email')`; `:273` indice unico parcial global; `:294-302` `INSERT` global con `WHERE NOT EXISTS`; `:317` BLOQUE 5 RLS; `:352` `CREATE OR REPLACE FUNCTION public.fn_horas_recordatorio(p_evento_id text)`; `:375` constante 56; `:404-425` verificacion de "UNA SOLA FILA GLOBAL"; `:511` ROLLBACK comentado de la funcion.
- `:63-64` el propio archivo declara `ESTADO: ESCRITO, NO APLICADO` y exige `service_role` + gate de `AGENTS.md` seccion 2. **Esa frase del header quedo desactualizada**: la migracion **si se aplico** el 2026-10-03. No se corrige (migraciones aplicadas intocables en un cierre documental).
- **La migracion esta APLICADA y verificada (2026-10-03)**, ejecutada con `service_role` desde el SQL Editor y en el orden ADR-073 -> ADR-074 -> ADR-076. El bloque de VERIFICACION comentado se ejecuto y dio lo esperado. Sin efectos colaterales: 0 filas borradas, 0 politicas RLS existentes modificadas, 0 tablas alteradas.
- **Fallo real encontrado y corregido en esa misma aplicacion (importante, no cosmetico):** el dry-run fallo con **`42804: foreign key constraint "config_recordatorios_evento_id_fkey" cannot be implemented`** porque la columna se declaro `uuid` y **`eventos.id` es `text`** en produccion. La causa no fue la coincidencia de nombres sino la **coincidencia de TIPOS**. Correccion ya incorporada al archivo (`:86` `text UNIQUE`, guard de tipos en `:143-216`, resolver en `:352`).

**Rollback:** documentado y comentado al final (`:448`): `DROP FUNCTION IF EXISTS public.fn_horas_recordatorio(uuid)`, mas el `DROP TABLE` de la tabla nueva. No afecta ninguna otra tabla; lo unico que se pierde es la configuracion escrita por el operador en esa tabla.

**Referencias cruzadas:** ADR-073 (`eventos.evento_inicio`: **dependencia dura**, se referencia en `:11-12`), ADR-072 (ultimo ADR cerrado, convencion de este archivo), ADR-076 (`email_envios_log` le dira al cron futuro a quien ya se le aviso), TSK-003 (pg_cron de recordatorios: este ADR le da el valor, **no** el disparador), TSK-081 (c) (deuda asociada al envio de correo), TSK-088 (adjuntar el ticket al correo).

**Estado real pieza por pieza:**

| Pieza | Estado | Nota |
|---|---|---|
| `migrations/adr074_config_recordatorios.sql` | ESCRITO, NO APLICADO | 452 lineas, 0 no-ASCII, validado por revision |
| Tabla `public.config_recordatorios` | NO EXISTE EN BD | se crea al aplicar |
| CHECK horas (0-720) y CHECK canal (`email`) | NO EXISTEN EN BD | bloque 2 |
| Indice unico parcial de la fila global | NO EXISTE EN BD | bloque 3b |
| Fila global 56 h / canal `email` | NO EXISTE EN BD | bloque 4 |
| `fn_horas_recordatorio(uuid)` | NO EXISTE EN BD | bloque 6 |
| Politica SELECT para `authenticated` | **NO EXISTE POR DECISION** | RLS activa sin politicas = fail-closed; abrirla es trabajo del backend futuro |
| pg_cron / trigger de envio | **NO EXISTE, fuera de alcance** | TSK-003 |

**Nota de numeracion:** el ID `ADR-074` no reutiliza ni salta ningun ID (`ADR-073` es el ultimo ocupado). El **hueco `ADR-075`** esta documentado en `DECISIONS.md`: **no existe** archivo `ADR-075*` en `decisiones/` ni migracion `adr075*` en `migrations/`; las migraciones de esta sesion lo saltan. Motivo: **no consta en el repo**; se registra como hueco de numeracion asumido, no como decision.