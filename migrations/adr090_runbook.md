# ADR-090 F2 | RUNBOOK DE APLICACION MANUAL (Supabase SQL Editor)

Estado: ESCRITO, NO EJECUTADO. Ninguna sentencia de este runbook se ha corrido
contra Supabase/Neon.

Archivos que consume (NO se modifican en esta fase):

- `migrations/adr090_precheck_duplicados.sql` (264 lineas, solo lectura, sin DDL)
- `migrations/adr090_idempotencia_logs.sql` (231 lineas, DDL, `no-transaction`)

Gate exigido antes del Paso 2 (AGENTS.md seccion 2, dominios de riesgo):
aprobacion explicita del usuario para migracion de esquema + pre-chequeo D11
resuelto (0 duplicados o decision registrada de Direccion).

Caracteristicas de este documento: ASCII puro (cero bytes > 127), sin tildes,
terminacion de linea LF, sin tabulaciones.

---

## 1. Precondiciones

1. **Rol `service_role` / `postgres` en el SQL Editor.** El editor del dashboard
   ya corre como `postgres` (bypass de RLS). NO se usa la clave `anon` para DDL.
   Confirmar antes de tocar nada:

```sql
SELECT current_user, current_database(), current_setting('server_version'), current_setting('server_encoding');
```

   Esperado: `server_encoding = UTF8` (requisito del escape `\u00B7` del CHECK,
   ver Hallazgo H2). Si no es UTF8, DETENERSE.

2. **Ventana sin trafico de puerta.** `ADD COLUMN` (metadata-only) y
   `ADD CONSTRAINT ... NOT VALID` toman `ACCESS EXCLUSIVE` por milisegundos;
   `CREATE INDEX CONCURRENTLY` toma `SHARE UPDATE EXCLUSIVE` y dos barridos de
   tabla. Elegir un hueco sin escaneos (fuera de horario de check-in).

3. **Backup del esquema `public.logs` antes de cualquier DDL.** Sin backup no se
   ejecuta el Paso 2. Opcion A (pg_dump, recomendada, requiere cliente local):

```bash
pg_dump "postgresql://postgres.<PROJECT_REF>:<PASSWORD>@aws-0-<REGION>.pooler.supabase.com:5432/postgres" \
  --schema=public --table=public.logs -Fc -f adr090_logs_pre_f2.dump
```

   Opcion B (si no hay pg_dump en la maquina): exportar desde el SQL Editor a
   CSV y guardar el archivo como evidencia:

```sql
COPY (SELECT * FROM public.logs) TO STDOUT WITH (FORMAT csv, HEADER true);
```

   Opcion C: snapshot/PITR del proyecto en el dashboard (confirmar que el punto
   de recuperacion cubre la ventana de ejecucion).

Nota: la tabla base `logs` NO esta versionada en el repo (solo add-ons adr079),
por eso el backup es la unica red de seguridad estructural.

---

## 2. Paso 1 - Pre-chequeo (solo lectura)

Ejecutar el archivo completo `migrations/adr090_precheck_duplicados.sql` en el
SQL Editor (una sola pasada; es idempotente y no escribe). Exportar **6
resultados obligatorios**: A, B, C, E, F, D (en ese orden de reporte). Los bloques
A2, B2, E2 y E3 pueden adjuntarse como anexo, pero no son obligatorios (E3 si se
recomienda: detecta un `uv_logs_entrada_idem` INVALID de una corrida previa).

Formato de pegado de vuelta a TASKS.md / NEXT.md: **un bloque de codigo por
letra**, sin mezclar y sin recortar filas (si hay mas de 30 filas, paginar con
`OFFSET` y anotar "paginado").

````
A  -> bloque A  (L35-41)  valores reales de resultado + conteo + rango de hora
B  -> bloque B  (L71-82)  grupos duplicados que SI bloquean el indice (evento_id NOT NULL)
C  -> bloque C  (L114-143) detalle fila por fila de esos duplicados, LIMIT 200
E  -> bloque E  (L175-184) columnas, tipos, nulabilidad y defaults reales de logs
F  -> bloque F  (L232-257) policies de logs + grants de tabla + grants de columna
D  -> bloque D  (L155-164) nulos que afectan la cobertura del indice
````

Plantilla exacta de reporte (copiar y rellenar; cada letra va en su propio
bloque para que el orquestador pueda citarlas sin ambiguedad):

```text
A) RESULTADO (valores reales)
resultado | filas | primera_hora | ultima_hora
...
```

```text
B) DUPLICADOS QUE BLOQUEAN (debe ser 0 filas o decision de Direccion)
evento_id | qr_code | punto | n | ids_distintos
...
```

```text
C) DETALLE DE DUPLICADOS (LIMIT 200)
id | evento_id | evento | qr_code | punto_acceso | resultado | hora | fecha | nombre | inscrito_id | org_id
...
```

```text
E) ESQUEMA REAL DE logs
ordinal_position | column_name | data_type | udt_name | is_nullable | column_default
...
```

```text
F) RLS Y GRANTS
policies: policyname | permissive | roles | cmd | qual | with_check
grants tabla: grantee | privilege_type | is_grantable
grants columna INSERT: grantee | column_name | privilege_type | is_grantable
...
```

```text
D) NULOS
total_logs | qr_code_null | evento_id_null | punto_acceso_null | ingresos | ingresos_sin_qr | ingresos_sin_evento
...
```

Criterios de lectura del reporte (no sustituyen la decision del Paso 3):

- `E` debe mostrar `punto_acceso`, `qr_code`, `resultado`, `evento_id` e
  `inscrito_id` y todas las relevantes en tipo `text`. Si `punto_acceso` no
  existe o no es `text`, se DETIENE la fase y se rediseña (comentario L171-173).
- `F`: si el INSERT de `anon` es de TABLA, no hay accion. Si es por COLUMNA, hay
  que sumar `op_id, offline` al GRANT (Paso 4, bloque 4E).
- `D`: `evento_id_null` alto no bloquea el indice (los NULL no colisionan), pero
  si deja filas sin proteccion de idempotencia; se documenta como hueco.

---

## 3. Tabla de decision (obligatoria antes del DDL)

| Rama | Condicion observada | Accion |
|---|---|---|
| **1** | **B = 0 filas** (cero duplicados) | Aplicar el DDL **completo**: `op_id` + `offline` + `CHECK NOT VALID` + indice unico natural `uv_logs_entrada_idem` + indice por `op_id`. |
| **2** | **B > 0 filas** | Aplicar SOLO `ADD COLUMN op_id/offline` + `CHECK NOT VALID` + indice unico por `op_id` (`WHERE op_id IS NOT NULL`). **NO** crear `uv_logs_entrada_idem`. Abrir adjudicacion con Direccion usando el listado **C** (caso por caso, sin borrar nada: Cero Borrado, Oro #2). |
| **3** | **A muestra valores de `resultado` no contemplados** (distintos de `Ingreso`, `Ingreso . <punto>` con U+00B7, `Denegado`, `duplicado`) | **DETENERSE.** El `CHECK NOT VALID` no falla al crearse (no valida historico) pero SI rechaza cualquier INSERT futuro con ese valor: la puerta empezaria a perder check-ins con error `23514`. Corregir primero el writer; no reescribir historico. |

Reglas de combinacion:

- Rama 3 manda sobre todo: si aparece un valor fuera del contrato, no se aplica
  nada del Paso 2 hasta resolverlo.
- Rama 2 y rama 1 son excluyentes; la rama 2 deja la idempotencia por clave
  natural PENDIENTE (queda solo la proteccion por `op_id`).
- Ambas ramas exigen que `E` confirme los tipos (`text`) y que `server_encoding`
  sea UTF8.

---

## 4. Paso 2 - Aplicacion del DDL

Reglas de ejecucion (criticas):

- **NUNCA escribir `BEGIN`.** El archivo `adr090_idempotencia_logs.sql` declara
  `-- supabase: no-transaction` en su linea 1 (L1) precisamente porque
  `CREATE INDEX CONCURRENTLY` no puede correr dentro de un bloque de transaccion
  (`ERROR 25001`).
- En el SQL Editor, ejecutar **una sentencia a la vez** (seleccionar el bloque y
  Run), o pegar el bloque completo: el editor confirma cada sentencia por
  separado (autocommit). Si se corre via Supabase CLI, el archivo se envuelve en
  BEGIN/COMMIT y los indices fallaran; ver Hallazgo H5.
- Si un paso falla, los anteriores YA quedaron aplicados (`no-transaction`). Por
  eso el orden importa y cada paso es re-ejecutable.

### 4A. Bloque comun a las dos ramas (PASO 1 + PASO 2 + PASO 3, L60-85)

```sql
ALTER TABLE public.logs
    ADD COLUMN IF NOT EXISTS op_id text;

COMMENT ON COLUMN public.logs.op_id IS
  'UUID v4 de la operacion de escaneo (ADR-090, D6). text nullable: las filas historicas no lo tienen. Permite deduplicar el drenaje del outbox; la unicidad real la impone uv_logs_entrada_idem.';

ALTER TABLE public.logs
    ADD COLUMN IF NOT EXISTS offline boolean DEFAULT false;

COMMENT ON COLUMN public.logs.offline IS
  'true si el log se valido contra el snapshot en IndexedDB y se dreno despues (ADR-090, D4). DEFAULT false: el historico y todo INSERT online quedan false.';

COMMENT ON COLUMN public.logs.resultado IS
  'Resultado canonico (ADR-090 sec. 3.7): Ingreso | Ingreso + espacio + U+00B7 + espacio + punto | Denegado | duplicado. El match de ingreso es LIKE ''Ingreso%''. Los valores historicos NO se migran (Cero Borrado).';
```

### 4B. CHECK canonico NOT VALID (PASO 4, L103-120) - ambas ramas

```sql
DO $adr090_check_resultado$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname  = 'logs_resultado_canonico_chk'
          AND conrelid = 'public.logs'::regclass
    ) THEN
        ALTER TABLE public.logs
            ADD CONSTRAINT logs_resultado_canonico_chk
            CHECK (
                resultado IS NULL
                OR resultado = 'Ingreso'
                OR resultado LIKE E'Ingreso \u00B7 %'
                OR resultado IN ('Denegado', 'duplicado')
            ) NOT VALID;
    END IF;
END $adr090_check_resultado$;
```

`NOT VALID` significa: no valida ni reescribe el historico (Cero Borrado), pero
SI se aplica a todo INSERT/UPDATE desde ahora.

### 4C. Indice unico natural (PASO 5, L144-146) - **SOLO rama 1 (B = 0)**

```sql
CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS uv_logs_entrada_idem
    ON public.logs (evento_id, qr_code, COALESCE(punto_acceso, ''))
    WHERE resultado LIKE 'Ingreso%' AND qr_code IS NOT NULL;
```

Si en la rama 2: **no ejecutar este bloque.**

### 4D. Indice por `op_id` - ambas ramas

Este indice **no existe en `adr090_idempotencia_logs.sql`** (ver Hallazgo H1).
DDL propuesto por este runbook; el orquestador decide si se incorpora al .sql:

Rama 1 (B = 0), forma literal de la tabla de decision (indice simple):

```sql
CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_logs_op_id
    ON public.logs (op_id)
    WHERE op_id IS NOT NULL;
```

Rama 2 (B > 0), reemplaza la proteccion perdida al no crear el indice natural:

```sql
CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS uv_logs_op_id
    ON public.logs (op_id)
    WHERE op_id IS NOT NULL;
```

Nota: si el orquestador prefiere una sola forma para ambas ramas, la recomendada
es la UNIQUE parcial (`uv_logs_op_id`): `op_id` identifica una operacion y un
reintento de drenaje debe colisionar (`23505`), no duplicar el log.

### 4E. Grants (PASO 6) - solo si el bloque F mostro INSERT por COLUMNA

```sql
GRANT INSERT (op_id, offline) ON public.logs TO anon;
```

Si el INSERT de `anon` es de TABLA (caso esperado), no ejecutar nada aqui. No se
crean policies nuevas ni se toca el DELETE de `anon`.

### 4F. Recarga del cache de esquema (PASO 7, L173)

```sql
NOTIFY pgrst, 'reload schema';
```

Sin esto PostgREST no ve `op_id`/`offline` hasta el siguiente reinicio.

### 4G. Verificacion posterior (`\d public.logs` equivalente)

Columnas nuevas:

```sql
SELECT ordinal_position, column_name, data_type, udt_name, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'logs'
  AND column_name IN ('op_id', 'offline')
ORDER BY ordinal_position;
```

Esperado: `op_id | text | YES | NULL` y `offline | boolean | YES | false`.

CHECK creado y NO validado (`convalidated = false` es correcto):

```sql
SELECT conname, convalidated, pg_get_constraintdef(oid) AS definicion
FROM pg_constraint
WHERE conrelid = 'public.logs'::regclass
  AND conname  = 'logs_resultado_canonico_chk';
```

Indices: validez, unicidad y definicion (via `pg_index` + `pg_indexes`):

```sql
SELECT c.relname AS index_name, i.indisunique AS es_unico,
       i.indisvalid AS es_valido, pg_get_indexdef(i.indexrelid) AS definicion
FROM pg_index i
JOIN pg_class c ON c.oid = i.indexrelid
WHERE i.indrelid = 'public.logs'::regclass
ORDER BY c.relname;
```

```sql
SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public' AND tablename = 'logs'
ORDER BY indexname;
```

Esperado:

- `uv_logs_entrada_idem` presente, `es_unico = true`, `es_valido = true`
  (solo rama 1).
- `ix_logs_op_id` (rama 1) o `uv_logs_op_id` (rama 2) presente y
  `es_valido = true`.
- Ningun indice con `es_valido = false`. Si `uv_logs_entrada_idem` quedo
  INVALID (corrida interrumpida), el `IF NOT EXISTS` lo salta en silencio:
  ejecutar `DROP INDEX CONCURRENTLY IF EXISTS public.uv_logs_entrada_idem;` y
  repetir 4C.

Duplicados vivos (debe devolver 0 filas):

```sql
SELECT evento_id, qr_code, COALESCE(punto_acceso, ''), count(*)
FROM public.logs
WHERE resultado LIKE 'Ingreso%' AND qr_code IS NOT NULL AND evento_id IS NOT NULL
GROUP BY 1, 2, 3
HAVING count(*) > 1;
```

---

## 5. Paso 3 - Cierre y trazabilidad

1. Anotar en `Sistema QR desarrollo/TASKS.md` bajo **TSK-134**:
   - el **nombre exacto de los indices creados** (`uv_logs_entrada_idem` /
     `ix_logs_op_id` o `uv_logs_op_id`) y la rama elegida (1 o 2);
   - el `convalidated` observado del CHECK;
   - la hora de la ventana y el usuario de base con el que se aplico.
2. Adjuntar el resultado del prechequeo como evidencia: los **6 bloques A, B, C,
   E, F, D** pegados en el mismo TSK, uno por bloque de codigo, sin recortar.
3. Registrar el hallazgo de sintaxis o la desviacion aplicada (por ejemplo la
   rama 2) en `DECISIONS.md` si el orquestador lo pide al cerrar D11.
4. Actualizar `NEXT.md` con el estado de F2: aplicado, pendiente de F4 (writer /
   outbox) o bloqueado por adjudicacion.
5. Si se uso la rama 2, abrir la adjudicacion con Direccion citando el listado C
   (ids concretos) y dejar constancia de que **no se borro nada**.

---

## 6. Rollback (ejecutar en este orden exacto)

Sin transaccion (los `DROP INDEX CONCURRENTLY` no lo permiten):

```sql
DROP INDEX CONCURRENTLY IF EXISTS public.uv_logs_entrada_idem;
DROP INDEX CONCURRENTLY IF EXISTS public.uv_logs_op_id;
DROP INDEX CONCURRENTLY IF EXISTS public.ix_logs_op_id;
ALTER TABLE public.logs DROP CONSTRAINT IF EXISTS logs_resultado_canonico_chk;
ALTER TABLE public.logs DROP COLUMN IF EXISTS offline;
ALTER TABLE public.logs DROP COLUMN IF EXISTS op_id;
NOTIFY pgrst, 'reload schema';
```

Antes de borrar las columnas, comprobar si hay datos en uso:

```sql
SELECT count(*) FILTER (WHERE op_id IS NOT NULL) AS filas_con_op_id,
       count(*) FILTER (WHERE offline)           AS filas_offline_true
FROM public.logs;
```

Nota: las columnas **solo se borran si no hay datos en uso**. Si ya hay `op_id`
o `offline = true` de logs escritos durante la ventana, borrarlas descarta esa
traza sin recuperacion posible (el rollback es de ESQUEMA, no de datos de
negocio: los logs siguen existiendo). Si esos valores se necesitan, dejar las
columnas y revertir solo indices y CHECK.

El CHECK `NOT VALID` se elimina sin validar nada; no deja filas marcadas.

---

## 7. Riesgos del paso

- **Lock de tabla.** `ADD COLUMN` con default constante es metadata-only en
  PG11+, pero toma `ACCESS EXCLUSIVE` un instante: si hay una consulta larga
  abierta sobre `logs`, el DDL espera en cola y **bloquea a todos los que
  lleguen detras** (cola de locks). Verificar antes con
  `SELECT * FROM pg_stat_activity WHERE query ILIKE '%logs%';` y elegir la
  ventana sin trafico de puerta.
- **Duplicados que rompen el indice.** Si B > 0 (o si entra un duplicado
  mientras corre el build concurrente), `CREATE UNIQUE INDEX CONCURRENTLY`
  falla por `23505` y deja el indice **INVALID**, que ocupa el nombre y hace que
  `IF NOT EXISTS` lo salte para siempre. Deteccion obligatoria con
  `pg_index.indisvalid`; recuperacion con `DROP INDEX CONCURRENTLY` + reintento.
- **Filas con `evento_id` NULL.** Los NULL son distintos entre si en un UNIQUE:
  **no colisionan y no bloquean** la creacion del indice (bloque B las excluye a
  proposito), pero tampoco quedan protegidas por el. Es un hueco declarado, no
  un fallo: se cierra en F4 exigiendo `evento_id` en todo INSERT de ingreso.
- **`CHECK NOT VALID` no valida el historico.** Es lo correcto (Cero Borrado,
  Oro #2): el historico queda fuera del CHECK y solo las filas nuevas se
  validan. Consecuencia: un valor legacy fuera del contrato no rompe el pasado,
  pero si un writer sigue emitiendolo, la puerta fallara con `23514` en cada
  check-in hasta corregir el writer.

---

## 8. Que NO hace este runbook

- No cifra el snapshot offline (es de ADR-090 F4 / cliente).
- No implementa el Service Worker ni la cola del outbox.
- No toca `scanner.html` (ni L1167-1170, ni L1210-1213, ni L1309) ni ningun otro
  archivo de runtime.
- No modifica `migrations/adr090_precheck_duplicados.sql` ni
  `migrations/adr090_idempotencia_logs.sql`.
- No borra, fusiona ni normaliza historico (Cero Borrado).
- No crea policies nuevas de RLS ni toca el DELETE de `anon`.

---

## 9. Hallazgos de sintaxis y observaciones

Revisados los 264 + 231 lineas sin ejecutar. Resultado: **0 errores de sintaxis
bloqueantes**, 1 hueco funcional y 2 observaciones operativas.

### H1 (hueco funcional, no sintaxis) - no existe indice por `op_id`

En `adr090_idempotencia_logs.sql` solo hay un indice: `uv_logs_entrada_idem`
(L144-146). La tabla de decision exige ademas un indice por `op_id`, pero **no
esta escrito en el archivo** (entre L146 y L149 no hay sentencia de indice). Este
runbook lo aporta como bloque 4D. Correccion exacta si el orquestador decide
incorporarlo al .sql, justo despues del PASO 5:

```sql
CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS uv_logs_op_id
    ON public.logs (op_id)
    WHERE op_id IS NOT NULL;
```

No se edito el .sql: la decision es del orquestador.

### H2 (validez condicionada) - escape `\u00B7` en el CHECK, L116

`resultado LIKE E'Ingreso \u00B7 %'` es sintacticamente valido y la forma
correcta para mantener el archivo ASCII puro (BUG-026), **pero el escape Unicode
solo funciona si `server_encoding = UTF8`**. En un servidor con otra codificacion
el `ALTER TABLE` fallaria con un error del tipo
`unsupported Unicode escape sequence` (los escapes `\u` solo estan soportados en
UTF8). Supabase es UTF8 de fabrica: confirmar con la sentencia de la seccion 1. Si no fuera UTF8, la correccion exacta es usar el
escape de bytes en lugar de `\u`:

```sql
-- UTF8:  E'Ingreso \u00B7 %'      (actual, correcto en Supabase)
-- LATIN1: E'Ingreso \xB7 %'
```

Sin cambios recomendados para este proyecto.

### H3 (verificado, sin error) - predicado del indice, L146

`WHERE resultado LIKE 'Ingreso%' AND qr_code IS NOT NULL` es aceptable en un
indice parcial: `textlike` (`~~`) esta marcado IMMUTABLE en `pg_proc` y las
columnas son `text`. Se ve como error solo con collations no deterministas
(ICU, PG12+), donde PostgreSQL responde
`nondeterministic collations are not supported for LIKE`. Con la collation por
defecto del proyecto (`en_US.UTF-8` o `C`, determinista) no hay problema. No
requiere correccion.

Nota semantica (no sintaxis): el predicado `LIKE 'Ingreso%'` es **mas amplio**
que el contrato del CHECK (acepta `IngresoX` historico). Es intencional y no
rompe: el CHECK solo gobierna escrituras nuevas.

### H4 (verificado, sin error) - `ADD CONSTRAINT IF NOT EXISTS`

`ADD CONSTRAINT ... IF NOT EXISTS` **no existe en PostgreSQL**; el archivo NO lo
usa. La guarda correcta es la que ya esta en L103-120: bloque `DO` que consulta
`pg_constraint` por `conname` + `conrelid` antes del `ALTER TABLE`. Confirmado
ademas que `ADD CONSTRAINT ... CHECK (...) NOT VALID` es sintaxis valida en
`ALTER TABLE` (solo esta prohibido `NOT VALID` al agregar una columna con
constraint en linea).

### H5 (observacion operativa) - directiva `-- supabase: no-transaction`, L1

No es una directiva reconocida por el SQL Editor de Supabase: es inerte (el
editor ya hace autocommit sentencia por sentencia), de modo que el runbook
funciona igual. El problema aparece si el archivo se aplica con Supabase CLI
(`supabase db push` / migracion estandar), que envuelve el archivo en
BEGIN/COMMIT: ahi `CREATE INDEX CONCURRENTLY` fallaria con
`ERROR 25001: CREATE INDEX CONCURRENTLY cannot run inside a transaction block`.
Correccion operativa: aplicar por SQL Editor (como describe este runbook) o
dividir la migracion para que el indice se ejecute fuera de transaccion. Tambien
es la convencion de dbmate (`-- migrate: no-transaction`), no la de Supabase.
