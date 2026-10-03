---
doc: ADR-073
version: v1.17-GOLD (heredada de DECISIONS.md)
fecha: 2026-10-03
origen: sesion FREE 2026-10-03 (@docs-keeper; migracion escrita por la sesion anterior, cierre documental de hoy). Gate de riesgo AGENTS.md seccion 2: AUTORIZADO por Direccion 2026-10-03 para aplicar la migracion; NO se ejecuto en este cierre.
version_previa: DECISIONS.md v1.17-GOLD
relacionados: [../DECISIONS.md, ../INDEX.md, ADR-072-atribucion-del-link-de-invitador-en-la-telemetria-del.md, ADR-074-configuracion-del-recordatorio-automatico-antes.md, ADR-076-camino-unico-de-envio-de-correo-con-secreto.md, ADR-068-unicidad-real-de-inscritura-por-even.md]
estado: vigente (ver campo Estado dentro del ADR)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [DECISIONS.md](../DECISIONS.md) - [INDEX](../INDEX.md).

## ADR-073: Columna canonica del instante del evento (`eventos.evento_inicio`)

**Fecha:** 2026-10-03

**Autor:** @sql-security + @data-migration (migracion escrita el 2026-10-03); cierre documental a cargo de @docs-keeper. Gate de riesgo de `AGENTS.md` seccion 2 (esquema) AUTORIZADO por Direccion el 2026-10-03; el alcance de la sesion fue SOLO documental, asi que **la migracion NO se ejecuto**.

**Estado:** DECIDIDO - migracion ESCRITA y **NO APLICADA** en base de datos.

**Problema:** el recordatorio automatico de correo (TSK-003) necesita saber, para cada evento, el instante en que empieza y restar N horas. Ese dato no era respondible: `eventos.fecha` y `eventos.hora` son **TEXT**, poblados desde `<input type="date">` y `<input type="time">` de `admin.html`, sin zona horaria y sin `timestamptz`; `hora` ademas es NULLABLE y puede venir duplicada, y `config_landing.content` puede traer otra copia de fecha/hora. Con texto sin zona, "el recordatorio sale 56 h antes" no se puede calcular de forma fiable, y una fecha inventada dispara correos a la gente equivocada.

**Contexto:** el hallazgo esta escrito en el propio header de la migracion (`migrations/adr073_eventos_evento_inicio.sql:10-17`). La razon por la que `fecha`/`hora` quedaron como TEXT es el contrato de v110: son los valores que el panel lee y compara contra el centinela `2099-12-31` del input de fecha, y nadie los relee de vuelta como fecha. **Decision de alcance:** no se reescriben; se derivan (ADR-006: prevalece el archivo, la verdad es el SQL real).

**Opciones:**
- (A) Normalizar `eventos.fecha` y `eventos.hora` a `timestamptz` en su sitio: rompe el contrato del panel (`admin.html` las trata como texto y las compara como string) y obliga a migrar los lectores; además es una reescritura de columna existente, no aditiva, descartada.
- (B) Calcular la ventana en SQL con `make_interval` sobre los textos en cada consulta, sin columna: no hay indice posible, cada corrida reparsea todas las filas y el "56 h antes" sigue sin zona declarada, descartada.
- (C) Columna **calculable** `timestamptz` derivada por backfill desde los dos textos, con zona declarada y sin reescribir el origen: elegida.

**Decision:** un solo objeto de esquema en `migrations/adr073_eventos_evento_inicio.sql` (**415 lineas, 18.1 KB, 0 bytes > 127**, ADR-002), en 6 bloques + bloque de verificacion y ROLLBACK:

1. **Columna aditiva** `BLOQUE 1` (`:81-90`): `ALTER TABLE public.eventos ADD COLUMN IF NOT EXISTS evento_inicio timestamptz;` al FINAL de la tabla. Nullable a proposito: `NULL` significa "no se pudo calcular con certeza" y es un dato honesto (fail-closed).
2. **Backfill fail-closed** `BLOQUE 2` (`:94-219`): bucle con `EXCEPTION` por fila, para que una fila con hora invalida no aborte el backfill de las otras (`:66-69`). Escribe **solo donde `evento_inicio IS NULL`**, o sea que re-ejecutar el archivo no cambia nada. Acepta **2 formatos de fecha, detectados por regex**: canonico `AAAA-MM-DD` (`:37-41`, el que escribe el panel) y legado `DD/MM/AAAA` (`:42-46`, solo por historico). Hora: `HH:MM` (segundos 0) y `HH:MM:SS`; `T` intercalado, `AM/PM`, horas > 23 o minutos > 59 -> `NULL`. Unica conversion del archivo: `AT TIME ZONE 'America/Bogota'` (`:62-64`, `:194`). Cualquier otro formato -> `NULL` y la fila se reporta **DUDOSA** (`:47`, `:221-263`), sin correccion manual en la columna.
3. **Reporte de dudosas** `BLOQUE 3` (`:221-263`): `RAISE NOTICE` con el conteo y listado (muestra 10 si hay mas de 10, `:261-262`).
4. **Indice** `BLOQUE 4` (`:269-280`): indice parcial que sirve el patron canonico "eventos que empiezan en [ahora-X, ahora+X]"; excluye las dudosas (`NULL`).
5. **Documentacion viva de la columna** `BLOQUE 5` (`:282-288`): `COMMENT ON COLUMN` que declara el origen, la zona, y que **NO se actualiza sola** (queda desfasada si `fecha`/`hora` cambian; un trigger es fuera de este ADR).
6. **Recarga del schema cache de PostgREST** `BLOQUE 6` (`:290-297`).

**Por que un bucle y no un `UPDATE ... SET` (critico):** el parseo necesita validar y capturar el error **por fila**; en un `SET`-based una fila con `25:00` aborta el backfill completo. Volumen esperado de eventos: bajo. El volumen es un dato del negocio, no medido en el repo; queda como supuesto declarado, no verificado.

**Lo que NO se toco (deliberado):**
- `eventos.fecha` y `eventos.hora` **no se reescriben** ni se borran (Cero Borrado, Oro #2): siguen siendo TEXT y siguen siendo el contrato del panel.
- **No se borra ninguna fila** y no hay `DROP`/`DELETE`/`TRUNCATE` en el archivo.
- **No se toca ninguna politica RLS** de `eventos`: la migracion no altera el conteo de politicas.
- **No se inventa ninguna fecha.** Un instante dudoso queda en `NULL`, no "arreglado" con un default.

**Consecuencias (registro obligatorio):**
- **La columna queda desfasada si `fecha`/`hora` cambian** despues del backfill: no hay trigger de sincronizacion. Mientras el recordatorio no exista, es inocuo; el dia que exista, hay que decidir entre trigger, backfill periodico o recalculo en el consumidor.
- **El trafico historico con fecha en un tercer formato NO se recupera**: queda en `NULL` y se revisa a mano (`BLOQUE 3`). Convertir esas filas exigiria una decision editorial sobre cual es la fecha correcta; esta migracion no la toma.
- **La migracion NO habilita por si sola el recordatorio**: solo da el instante. La ventana (56 h) vive en `config_recordatorios` (ADR-074) y el envio, en la Edge Function `send-ticket-email` y el RPC de ADR-076.

**Impacto:** 1 columna, 1 indice, 1 `COMMENT ON`, 0 filas tocadas, 0 politicas, 0 RPC, 0 triggers, 0 vistas. Es la dependencia dura de ADR-074.

**Evidencia verificada contra el archivo real (ADR-006 — prevalece el archivo):**
- `migrations/adr073_eventos_evento_inicio.sql`: existe, **415 lineas**, **18.581 bytes**, **0 bytes > 127** (verificado byte a byte).
- Anclas: `:90` `ADD COLUMN IF NOT EXISTS evento_inicio timestamptz`; `:194` `AT TIME ZONE 'America/Bogota'`; `:221` y `:246` `RAISE NOTICE` de dudosas; `:261` tope de 10 listados; `:282-288` `COMMENT ON COLUMN`; `:409` ROLLBACK comentado.
- `:71-73` el propio archivo declara `ESTADO: ESCRITO, NO APLICADO` y exige credenciales `service_role` + gate de `AGENTS.md` seccion 2.
- Las 3 rutas de migraciones de esta sesion (`adr073`, `adr074`, `adr076`) siguen **sin aplicar**: no hay en el repo ninguna evidencia de ejecucion y el propio SQL lo declara. `migrations/adr068_inscritos_unique_cedula_evento.sql` **tampoco** esta aplicada (deuda preexistente, ADR-068).
- El hallazgo "`eventos.fecha`/`eventos.hora` son TEXT" esta documentado en el propio SQL (`:11-12`) y **no** se pudo re-verificar contra un dump de esquema del repo porque el repo no tiene el dump; queda como afirmacion del artefacto, coherente con el tipo de dato que usa el panel.

**Rollback:** documentado y **comentado** al final del archivo (`:409-415`): `DROP COLUMN` de `eventos.evento_inicio` y su indice. El `DROP COLUMN` **reescribe la tabla fisicamente** y borra el dato calculado; el dato de origen (`fecha`, `hora`) sobrevive, asi que se puede recalcular. Requiere gate de riesgo.

**Referencias cruzadas:** ADR-063 (flujo de entrega y recuperacion de QR, `registroaforo.html`), ADR-064 (diseno de ticket por tipo, fuente del adjunto del correo), ADR-068 (unicidad `(evento_id, cedula)`, sigue escrita y sin aplicar), ADR-072 (ultimo ADR cerrado, convencion de este archivo), ADR-074 (`config_recordatorios`, dependencia directa), ADR-076 (canal unico de envio), TSK-003 (pg_cron de recordatorios: sigue siendo la deuda madre, no se resuelve aqui), TSK-081 (c) (deuda asociada al envio de correo), TSK-088 (adjuntar el ticket al correo: esta migracion no lo cubre).

**Estado real pieza por pieza:**

| Pieza | Estado | Nota |
|---|---|---|
| `migrations/adr073_eventos_evento_inicio.sql` | ESCRITO, NO APLICADO | 415 lineas, 0 no-ASCII, validado por revision |
| Columna `eventos.evento_inicio` | NO EXISTE EN BD | se crea al aplicar la migracion |
| Backfill y reporte de dudosas | NO EJECUTADO | en el archivo, bloque 2 y 3 |
| Indice parcial | NO EXISTE EN BD | bloque 4 |
| Disparador del recordatorio | NO EXISTE | TSK-003 + ADR-074; **fuera de alcance de este ADR** |
| Trigger de resincronizacion de `evento_inicio` | NO EXISTE, declarado como pendiente | `BLOQUE 5`, ver Consecuencias |

**Nota de numeracion:** el ID `ADR-073` no reutiliza ni salta ningun ID (`ADR-072` es el ultimo ocupado). El **hueco `ADR-075`** si esta documentado en `DECISIONS.md`: las migraciones de esta sesion lo saltan y no existe archivo para el. Motivo: **no consta en el repo**; se registra como hueco de numeracion asumido, no como decision.