---
doc: ADR-074
version: v1.17-GOLD (heredada de DECISIONS.md)
fecha: 2026-10-03
origen: sesion FREE 2026-10-03 (@sql-security + @data-migration; migracion escrita el 2026-10-03, cierre documental de hoy). Gate de riesgo AGENTS.md seccion 2: AUTORIZADO por Direccion 2026-10-03 para aplicar; NO se ejecuto en este cierre.
version_previa: DECISIONS.md v1.17-GOLD
relacionados: [../DECISIONS.md, ../INDEX.md, ADR-073-columna-canonica-del-instante-del-evento-evento-inicio.md, ADR-076-camino-unico-de-envio-de-correo-con-secreto.md, ADR-072-atribucion-del-link-de-invitador-en-la-telemetria-del.md]
estado: vigente (ver campo Estado dentro del ADR)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [DECISIONS.md](../DECISIONS.md) - [INDEX](../INDEX.md).

## ADR-074: Configuracion del recordatorio automatico (`config_recordatorios`)

**Fecha:** 2026-10-03

**Autor:** @sql-security + @data-migration (migracion escrita el 2026-10-03); cierre documental a cargo de @docs-keeper. Gate de riesgo de `AGENTS.md` seccion 2 (esquema) AUTORIZADO por Direccion el 2026-10-03; el alcance de la sesion fue SOLO documental, asi que **la migracion NO se ejecuto**.

**Estado:** DECIDIDO - migracion ESCRITA y **NO APLICADA** en base de datos. Requiere **ADR-073 aplicada** antes.

**Problema:** el recordatorio automatico (TSK-003) debe dispararse N horas antes del evento. Con N escrito a mano en el codigo del futuro cron, cambiarlo es un despliegue. El valor pedido hoy es 56 h, asi que la pregunta correcta no es "que constante uso" sino "donde vive el valor, y quien gana cuando hay dos valores".

**Contexto:** depende de `eventos.evento_inicio` de ADR-073 (`migrations/adr074_config_recordatorios.sql:11-12`): sin instante canonico no hay forma de calcular "faltan N horas". Esta migracion es **solo la capa de configuracion y su lectura**: no crea cron, ni trigger de envio, ni Edge Function (`:13-14`).

**Opciones:**
- (A) Constante `56` en el codigo del cron: cero_objects de esquema, pero el cambio de valor exige despliegue y no queda traza de "que valor se uso para este evento", descartada.
- (B) Una columna en `eventos` (`horas_recordatorio`): mezcla la configuracion global del operador con el dato de negocio del evento, y obliga a migrar `eventos` para un valor que hoy es global, descartada.
- (C) Tabla propia de configuracion con dos niveles (global / override por evento) y un resolver: elegida.

**Decision:** un solo objeto de esquema en `migrations/adr074_config_recordatorios.sql` (**452 lineas, 20.8 KB, 0 bytes > 127**, ADR-002), en 7 bloques + bloque de verificacion y ROLLBACK:

1. **Tabla** `BLOQUE 1` (`:72-95`): `CREATE TABLE IF NOT EXISTS public.config_recordatorios` con `evento_id uuid` **NULLABLE**, `horas_anticipacion integer NOT NULL DEFAULT 56` (`:88`), `canal text` y `activa boolean`.
2. **CHECK constraints** `BLOQUE 2` (`:97-141`): `horas_anticipacion > 0 AND <= 720` (30 dias; abajo de 0 no es recordatorio, es ruido o envio inmediato; mas de 720 h es un aviso que llega antes de que el evento exista en la agenda) y `canal IN ('email')` (`:41-43`: se amplia el CHECK cuando exista el canal, no se deja libre para no crear filas con un canal que nadie procesa).
3. **FK de `evento_id`** `BLOQUE 3` (`:143-192`), condicional y fail-safe: solo se crea si `eventos` existe.
4. **Una sola fila global, garantizada por el motor** `BLOQUE 3b` (`:194-221`): `CREATE UNIQUE INDEX IF NOT EXISTS idx_config_recordatorios_global` **parcial** sobre `evento_id IS NULL`. Esto es la pieza que resuelve la advertencia de PostgreSQL: **en un UNIQUE los NULL no chocan entre si**, asi que `UNIQUE (evento_id)` **NO impide** varias filas globales. Tres capas, no una: indice unico parcial + `INSERT` global con `WHERE NOT EXISTS` (`:238-241`) + resolucion determinista del caso multi-global (`:265-268`, BLOQUE 6). Si quedaran dos globales de un intento previo con error, el `CREATE UNIQUE INDEX` falla aqui y se ve en la misma corrida.
5. **Fila global por defecto** `BLOQUE 4` (`:223-249`): `INSERT ... SELECT NULL, true, 56, 'email' WHERE NOT EXISTS (...)`, con el **56 explicito** y no solo por default (`:233`), y **no reescribe** el 56 si la fila ya existe con otro valor.
6. **RLS fail-closed** `BLOQUE 5` (`:250-264`): se activa RLS en la tabla nueva y **NO se crea ninguna politica**. Con RLS activa y cero politicas, `anon` y `authenticated` no ven ni una fila. Es lo correcto para una tabla de configuracion que hoy no tiene consumidor; **cuando exista el backend del recordatorio habra que abrir lectura explicitamente** (politica SELECT para `authenticated`, o mover el resolver a `SECURITY DEFINER`). Las politicas de las demas tablas **no se tocan**.
7. **Resolver** `BLOQUE 6` (`:265-317`): `public.fn_horas_recordatorio(p_evento_id uuid)` con precedencia **override del evento -> fila global -> constante 56** (`:267`). El ultimo escalon es un ultimo recurso, no la norma: el `ORDER BY/LIMIT 1` es la red, no el diseño.
8. **Recarga del schema cache de PostgREST** `BLOQUE 7` (`:318-326`).

**El default global de 56 h es una DECISION DE NEGOCIO, no un valor tecnico** (`:16-20`): 56 h deja margen para un recordatorio de confirmacion y otro el dia previo sin que ambos caigan el mismo dia. Si Direccion quiere otro numero, se `UPDATE`a la fila global: no hace falta tocar codigo ni volver a correr la migracion.

**Lo que NO se toco (deliberado):**
- **No crea cron, ni trigger de envio, ni Edge Function** (`:13-14`). El disparador sigue siendo TSK-003.
- **No altera ninguna tabla existente**, no borra filas y **no modifica ninguna politica RLS existente**: solo activa RLS en la tabla nueva.
- **No inventa el override por evento**: no hay fila por evento, solo la global. Los overrides los crea el operador cuando los necesite.

**Idempotencia:** 100% (`:45-48`). `CREATE TABLE IF NOT EXISTS`, dos bloques `DO` con guarda en `pg_constraint` (uno por CHECK y otro por la FK), `CREATE UNIQUE INDEX IF NOT EXISTS` e `INSERT` global con `WHERE NOT EXISTS`. Se puede ejecutar 2+ veces seguidas sin error y sin duplicar la fila global.

**Consecuencias (registro obligatorio):**
- **Hoy la tabla es inerte y no se ve desde el cliente.** RLS activa sin politicas = nadie lee; el unico consumidor real seran el cron y la RPC futuras. Es fail-closed a proposito, no un olvido.
- **Si el backend del recordatorio se implementa como una Edge Function que consulta la tabla con `authenticated`, vera el 56 de la constante y no la fila global** (`:285`): ese es el fallo silencioso a vigilar cuando exista el backend. La salida es abrir lectura explicita o mover el resolver a `SECURITY DEFINER`, ambas cosas **fuera de este ADR**.
- **El caso multi-global no es imposible por construccion, es improbable:** las 3 capas lo hacen visible (falla el indice) y determinista al leer. Si aparece, hay que depurar datos, no cambiar el resolver.

**Impacto:** 1 tabla nueva, 2 CHECK, 1 FK condicional, 1 indice unico parcial, 1 fila global, RLS activada, 1 funcion resolver. 0 tablas alteradas, 0 filas borradas, 0 politicas existentes modificadas.

**Evidencia verificada contra el archivo real (ADR-006 — prevalece el archivo):**
- `migrations/adr074_config_recordatorios.sql`: existe, **452 lineas**, **21.256 bytes**, **0 bytes > 127** (verificado byte a byte).
- Anclas: `:84` `CREATE TABLE IF NOT EXISTS public.config_recordatorios`; `:88` `DEFAULT 56`; `:217` indice unico parcial global; `:238-241` `INSERT` global con `WHERE NOT EXISTS`; `:250` BLOQUE 5 RLS; `:289` `CREATE OR REPLACE FUNCTION public.fn_horas_recordatorio(p_evento_id uuid)`; `:312` constante 56; `:341` verificacion de "UNA SOLA FILA GLOBAL"; `:448` ROLLBACK comentado de la funcion.
- `:63-64` el propio archivo declara `ESTADO: ESCRITO, NO APLICADO` y exige `service_role` + gate de `AGENTS.md` seccion 2.
- La migracion sigue **sin aplicar**. **Y no puede aplicarse sola:** sin ADR-073 aplicada, `evento_inicio` no existe y el patron "ahora + N - ventana" del futuro cron no tendria de donde sacar el instante.

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