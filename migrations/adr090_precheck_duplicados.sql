-- ============================================================================
-- ADR-090 | F1 | PRE-CHEQUEO DE DUPLICADOS E IDEMPOTENCIA DE public.logs
-- ----------------------------------------------------------------------------
-- OBJETIVO: decidir si el indice UNIQUE parcial uv_logs_entrada_idem puede
--   crearse (D11, bloqueante de F1/F2) y fijar la foto real del esquema y de la
--   RLS antes de escribir DDL.
--
-- ESTADO: SOLO LECTURA. Este archivo NO hace DDL ni DML: todos los bloques son
--   SELECT. Se puede ejecutar N veces sin efecto. Se ejecuta en Supabase SQL
--   Editor (o psql) ANTES de migrations/adr090_idempotencia_logs.sql.
--
-- REGLA DURA: si el bloque (b) devuelve 1 o mas filas, el indice NO se crea y
--   F2 NO arranca hasta que Direccion decida caso por caso. Prohibido borrar,
--   fusionar o normalizar historico en silencio (Cero Borrado, Oro #2).
--
-- NOTA ADR-006: la tabla base logs NO esta versionada en el repo (solo sus
--   add-ons: adr079). Por eso el bloque (e) es la verificacion AUTORITATIVA de
--   columnas, tipos y nulabilidad; los bloques (a)-(d) asumen las columnas que
--   hoy escriben scanner.html L1167-1170, L1210-1213 y L1309.
--
-- Caracteristicas: ASCII puro (cero bytes > 127), comentarios en espanol sin
--   tildes ni emojis.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- BLOQUE A | VALORES REALES DE resultado
-- Que significa: foto de los textos que hoy viven en logs.resultado.
-- Que decision dispara: confirma la tabla canonica del ADR-090 sec. 3.7
--   (Ingreso, Ingreso + separador U+00B7 + punto, Denegado) y si ya existe
--   duplicado. Cualquier OTRO valor queda fuera del CHECK nuevo por ser
--   historico (NOT VALID), pero un writer que lo siga emitiendo chocara con el
--   CHECK: hay que corregir el writer, no el historico.
-- ----------------------------------------------------------------------------
SELECT resultado,
       count(*)        AS filas,
       min(hora)       AS primera_hora,
       max(hora)       AS ultima_hora
FROM public.logs
GROUP BY resultado
ORDER BY filas DESC, resultado;


-- ----------------------------------------------------------------------------
-- BLOQUE A2 | VARIANTES DE CASING DEL PREFIJO
-- Que significa: el indice filtra con LIKE 'Ingreso%' (sensible a mayusculas).
--   Un 'ingreso' o 'INGRESO' historico o de un writer manual no entra al
--   indice ni a la deduplicacion.
-- Que decision dispara: si hay filas con casing distinto, se documenta como
--   hueco conocido y se corrige el writer; no se reescribe historico.
-- ----------------------------------------------------------------------------
SELECT resultado, count(*) AS filas
FROM public.logs
WHERE resultado ILIKE 'ingreso%'
  AND resultado NOT LIKE 'Ingreso%'
GROUP BY resultado
ORDER BY filas DESC;


-- ----------------------------------------------------------------------------
-- BLOQUE B | DUPLICADOS QUE SI BLOQUEAN EL INDICE (D11)
-- Que significa: grupos (evento_id, qr_code, punto normalizado) con mas de un
--   log de ingreso y evento_id NO NULL. Son exactamente las filas que harian
--   fallar CREATE UNIQUE INDEX.
-- Que decision dispara: 0 filas -> F2 puede crear el indice. 1+ filas ->
--   BLOQUEANTE: se entrega el listado del bloque (c) y decide Direccion.
-- Por que evento_id IS NOT NULL: en un UNIQUE los NULL son distintos entre si,
--   asi que las filas con evento_id NULL NUNCA colisionan y no bloquean la
--   creacion (se reportan aparte en el bloque B2).
-- ----------------------------------------------------------------------------
SELECT l.evento_id,
       l.qr_code,
       COALESCE(l.punto_acceso, '') AS punto,
       count(*)                     AS n,
       count(DISTINCT l.id)         AS ids_distintos
FROM public.logs l
WHERE l.resultado LIKE 'Ingreso%'
  AND l.qr_code    IS NOT NULL
  AND l.evento_id  IS NOT NULL
GROUP BY 1, 2, 3
HAVING count(*) > 1
ORDER BY n DESC, 1, 2, 3;


-- ----------------------------------------------------------------------------
-- BLOQUE B2 | DUPLICADOS CON evento_id NULL (NO bloquean, pero son hueco)
-- Que significa: mismo qr_code y punto repetidos en filas sin evento_id. El
--   indice UNIQUE no las ve (NULL distinto), de modo que no impiden crearlo,
--   pero TAMPOCO quedan protegidas por el.
-- Que decision dispara: si hay filas, F4 debe garantizar que todo INSERT nuevo
--   envie evento_id (hoy scanner.html L1170/L1213/L1309 ya lo hace); si no,
--   la idempotencia por clave natural no aplica a esa fila.
-- ----------------------------------------------------------------------------
SELECT l.qr_code,
       COALESCE(l.punto_acceso, '') AS punto,
       count(*)                     AS n
FROM public.logs l
WHERE l.resultado LIKE 'Ingreso%'
  AND l.qr_code   IS NOT NULL
  AND l.evento_id IS NULL
GROUP BY 1, 2
HAVING count(*) > 1
ORDER BY n DESC, 1, 2;


-- ----------------------------------------------------------------------------
-- BLOQUE C | DETALLE DE LOS DUPLICADOS (lista para la decision de Direccion)
-- Que significa: cada fila concreta de los grupos del bloque (b), con id y
--   hora/fecha, para decidir cual es el ingreso valido y cual el repetido.
-- Que decision dispara: Direccion marca caso por caso (no se borra nada). El
--   listado se corta en 200 filas: si el conteo total es mayor, se amplia el
--   LIMIT o se pagina por evento_id.
-- ----------------------------------------------------------------------------
WITH dup AS (
    SELECT evento_id,
           qr_code,
           COALESCE(punto_acceso, '') AS punto
    FROM public.logs
    WHERE resultado LIKE 'Ingreso%'
      AND qr_code   IS NOT NULL
      AND evento_id IS NOT NULL
    GROUP BY 1, 2, 3
    HAVING count(*) > 1
)
SELECT l.id,
       l.evento_id,
       l.evento,
       l.qr_code,
       l.punto_acceso,
       l.resultado,
       l.hora,
       l.fecha,
       l.nombre,
       l.inscrito_id,
       l.org_id
FROM public.logs l
JOIN dup d
  ON  l.evento_id = d.evento_id
  AND l.qr_code   = d.qr_code
  AND COALESCE(l.punto_acceso, '') = d.punto
WHERE l.resultado LIKE 'Ingreso%'
ORDER BY l.evento_id, l.qr_code, l.punto_acceso, l.hora, l.id
LIMIT 200;


-- ----------------------------------------------------------------------------
-- BLOQUE D | NULOS QUE AFECTAN LA COBERTURA DEL INDICE
-- Que significa: qr_code NULL queda excluido del indice por el predicado;
--   evento_id NULL no colisiona (NULL distinto); punto_acceso NULL se normaliza
--   con COALESCE y SI queda cubierto.
-- Que decision dispara: si qr_code NULL o evento_id NULL crecen, el indice no
--   protege esas filas; se documenta como limite y se exige en F4 que todo
--   INSERT de ingreso lleve ambas columnas.
-- ----------------------------------------------------------------------------
SELECT count(*)                                                AS total_logs,
       count(*) FILTER (WHERE qr_code      IS NULL)            AS qr_code_null,
       count(*) FILTER (WHERE evento_id    IS NULL)            AS evento_id_null,
       count(*) FILTER (WHERE punto_acceso IS NULL)            AS punto_acceso_null,
       count(*) FILTER (WHERE resultado LIKE 'Ingreso%')       AS ingresos,
       count(*) FILTER (WHERE resultado LIKE 'Ingreso%'
                          AND qr_code   IS NULL)               AS ingresos_sin_qr,
       count(*) FILTER (WHERE resultado LIKE 'Ingreso%'
                          AND evento_id IS NULL)               AS ingresos_sin_evento
FROM public.logs;


-- ----------------------------------------------------------------------------
-- BLOQUE E | ESQUEMA REAL DE logs (autoritativo, ADR-006)
-- Que significa: columnas, tipos, nulabilidad y defaults reales. Confirma si
--   punto_acceso, qr_code, resultado, evento_id e inscrito_id existen y con que
--   tipo (si punto_acceso no existe, el indice del ADR-090 no es aplicable).
-- Que decision dispara: si algun tipo no es text (p.ej. uuid o jsonb) o si
--   falta punto_acceso, se DETIENE la fase y se reescribe el diseno.
-- ----------------------------------------------------------------------------
SELECT ordinal_position,
       column_name,
       data_type,
       udt_name,
       is_nullable,
       column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name   = 'logs'
ORDER BY ordinal_position;


-- ----------------------------------------------------------------------------
-- BLOQUE E2 | COLUMNAS NUEVAS: op_id / offline ya existen?
-- Que significa: evita duplicar columnas o el indice si otra sesion ya aplico
--   parte del ADR-090.
-- Que decision dispara: si ambas existen con el tipo esperado, saltar su
--   ALTER; si op_id existe con otro tipo (p.ej. uuid), NO se altera en caliente
--   y se escala a Direccion.
-- ----------------------------------------------------------------------------
SELECT column_name, data_type, udt_name, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name   = 'logs'
  AND column_name IN ('op_id', 'offline')
ORDER BY column_name;


-- ----------------------------------------------------------------------------
-- BLOQUE E3 | INDICES EXISTENTES Y SU VALIDEZ
-- Que significa: lista de indices de logs con unicidad y validez. Un indice
--   INVALID (CONCURRENTLY interrumpido) ocupa el nombre: IF NOT EXISTS lo
--   saltaria y la idempotencia quedaria sin aplicar.
-- Que decision dispara: si uv_logs_entrada_idem ya existe y es valido, no se
--   recrea; si existe y es INVALID, hay que DROP INDEX CONCURRENTLY y reintentar.
-- ----------------------------------------------------------------------------
SELECT c.relname                                        AS index_name,
       i.indisunique                                    AS es_unico,
       i.indisvalid                                     AS es_valido,
       pg_get_indexdef(i.indexrelid)                    AS definicion
FROM pg_index i
JOIN pg_class c ON c.oid = i.indexrelid
WHERE i.indrelid = 'public.logs'::regclass
ORDER BY c.relname;


-- ----------------------------------------------------------------------------
-- BLOQUE F | RLS Y GRANTS SOBRE logs (auditoria del replay anon)
-- Que significa: policies vigentes y privilegios de tabla por rol. El scanner
--   escribe con la clave anon sin sesion: el INSERT anon ya funciona hoy y
--   agregar columnas no cambia una policy (la RLS se evalua por fila, no por
--   columna).
-- Que decision dispara: si el INSERT anon es de TABLA, no hay que tocar nada.
--   Si solo hay privilegios a nivel de COLUMNA, hay que agregar op_id/offline al
--   GRANT (ver PASO 6 del archivo de DDL). Si no hay INSERT anon, el replay
--   offline fallaria y se escala antes de F4.
-- ----------------------------------------------------------------------------
SELECT policyname,
       permissive,
       roles,
       cmd,
       qual,
       with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename  = 'logs'
ORDER BY policyname;


SELECT grantee, privilege_type, is_grantable
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
  AND table_name   = 'logs'
  AND privilege_type IN ('INSERT', 'UPDATE', 'DELETE', 'SELECT')
ORDER BY grantee, privilege_type;


SELECT grantee, column_name, privilege_type, is_grantable
FROM information_schema.column_privileges
WHERE table_schema = 'public'
  AND table_name   = 'logs'
  AND privilege_type = 'INSERT'
ORDER BY grantee, column_name;


-- ============================================================================
-- FIN DEL PRE-CHEQUEO. Registrar la salida de (a), (b), (c), (d), (e) y (f) en
-- TASKS.md/NEXT.md antes de pedir el gate de F2. Sin ese reporte F2 no arranca
-- (D11 / R1 del ADR-090).
-- ============================================================================
