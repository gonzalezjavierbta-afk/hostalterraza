-- supabase: no-transaction
-- ============================================================================
-- ADR-090 | F1 | IDEMPOTENCIA DEL SCANNER OFFLINE EN public.logs
-- ----------------------------------------------------------------------------
-- OBJETIVO: columnas de idempotencia (op_id, offline), CHECK canonico de
--   resultado (D9/sec. 3.7) e indice UNIQUE parcial uv_logs_entrada_idem
--   (D6/D10/sec. 3.3).
--
-- ESTADO: ESCRITO, NO APLICADO. Nada de este archivo se ha ejecutado contra
--   Supabase/Neon. La aplicacion es de F2 (@data-migration) y exige gate
--   seccion 2 de AGENTS.md MAS el visto bueno del pre-chequeo D11 sin
--   duplicados (o con decision registrada de Direccion).
--
-- POR QUE no-transaction: CREATE INDEX CONCURRENTLY no puede ejecutarse dentro
--   de un bloque de transaccion (ni en una migracion estandar de Supabase CLI,
--   que envuelve el archivo en BEGIN/COMMIT). La directiva de la primera linea
--   hace que cada sentencia se confirme por separado. Consecuencia asumida: si
--   un paso falla, los anteriores YA quedaron aplicados; por eso cada paso es
--   idempotente y re-ejecutable, y el indice puede quedar INVALID (R11).
--
-- IDEMPOTENCIA: ADD COLUMN IF NOT EXISTS, COMMENT ON, bloque DO con guarda en
--   pg_constraint para el CHECK y CREATE INDEX ... IF NOT EXISTS. Re-ejecutar
--   el archivo no produce efecto adicional (salvo el caso INVALID documentado
--   en el PASO 5).
--
-- COALESCE EN EL INDICE: COALESCE no es una funcion de catalogo, es una
--   expresion CASE; sobre columnas text es INMUTABLE y esta permitida en una
--   expresion de indice. No hace falta envolverla ni declarar nada extra.
--
-- Caracteristicas: ASCII puro (cero bytes > 127), comentarios en espanol sin
--   tildes ni emojis, cero backticks, terminacion de linea LF.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- PASO 0 | PRECONDICION BLOQUEANTE (no ejecuta nada)
-- Correr migrations/adr090_precheck_duplicados.sql y adjuntar:
--   (a) valores reales de resultado,
--   (b) grupos duplicados (debe ser 0 o tener decision de Direccion),
--   (e) columnas y tipos reales de logs,
--   (f) policies de INSERT y grants anon.
-- Si (b) devuelve filas, NO EJECUTAR EL PASO 5 de este archivo.
-- ----------------------------------------------------------------------------


-- ----------------------------------------------------------------------------
-- PASO 1 | COLUMNA op_id (traza de la operacion del outbox)
--
-- Tipo text (CONTRATO ADR-090 sec. 3.3), no uuid: el cliente puede caer al
--   fallback de UUID v4 con crypto.getRandomValues (R8) y un texto malformado
--   en una columna uuid provocaria 22P02, es decir, perder el check-in en la
--   puerta. Con text la validacion de formato queda en el cliente y la base
--   nunca rechaza una operacion por formato. La unicidad NO depende de esta
--   columna (la impone el indice del PASO 5).
-- Alternativa registrada para Direccion: si se prefiere validacion estricta en
--   base, cambiar text -> uuid antes de aplicar. NO se puede cambiar en caliente
--   despues: exigiria USING op_id::uuid y fallaria con filas malformadas.
-- Nullable: las filas historicas no tienen op_id (Cero Borrado).
-- ----------------------------------------------------------------------------
ALTER TABLE public.logs
    ADD COLUMN IF NOT EXISTS op_id text;

COMMENT ON COLUMN public.logs.op_id IS
  'UUID v4 de la operacion de escaneo (ADR-090, D6). text nullable: las filas historicas no lo tienen. Permite deduplicar el drenaje del outbox; la unicidad real la impone uv_logs_entrada_idem.';


-- ----------------------------------------------------------------------------
-- PASO 2 | COLUMNA offline (procedencia del log)
--
-- boolean DEFAULT false: los INSERT actuales que no la mencionan quedan en
--   false sin backfill ni reescritura de historico. Las filas historicas
--   quedan false, que es el valor correcto (se escribieron con red).
-- ----------------------------------------------------------------------------
ALTER TABLE public.logs
    ADD COLUMN IF NOT EXISTS offline boolean DEFAULT false;

COMMENT ON COLUMN public.logs.offline IS
  'true si el log se valido contra el snapshot en IndexedDB y se dreno despues (ADR-090, D4). DEFAULT false: el historico y todo INSERT online quedan false.';


-- ----------------------------------------------------------------------------
-- PASO 3 | COMENTARIO DE CONTRATO SOBRE resultado (sin cambiar datos)
-- ----------------------------------------------------------------------------
COMMENT ON COLUMN public.logs.resultado IS
  'Resultado canonico (ADR-090 sec. 3.7): Ingreso | Ingreso + espacio + U+00B7 + espacio + punto | Denegado | duplicado. El match de ingreso es LIKE ''Ingreso%''. Los valores historicos NO se migran (Cero Borrado).';


-- ----------------------------------------------------------------------------
-- PASO 4 | CHECK DE VALORES CANONICOS, NOT VALID
--
-- NOT VALID: no reescribe ni valida filas historicas (Cero Borrado); a partir
--   de la creacion SI se aplica a todo INSERT/UPDATE nuevo. Por eso solo se
--   listan los valores que los writers pueden emitir desde hoy.
-- El separador U+00B7 (punto medio) se escribe como escape Unicode dentro de
--   una cadena E'', de modo que el archivo sigue siendo ASCII puro (BUG-026).
--   El patron admite cualquier nombre de punto despues de "Ingreso <punto medio> ".
-- resultado IS NULL se permite a proposito: no se conoce un NOT NULL previo y
--   este CHECK no debe endurecer una columna historica por la puerta trasera.
-- No usar LIKE 'Ingreso%' a secas en el CHECK: aceptaria basura como
--   'IngresoX'; el prefijo exacto con separador es el contrato.
-- ADD CONSTRAINT no admite IF NOT EXISTS: el bloque DO consulta pg_constraint.
-- ----------------------------------------------------------------------------
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


-- ----------------------------------------------------------------------------
-- PASO 5 | INDICE UNIQUE PARCIAL DE IDEMPOTENCIA (D6/D10)
--
-- Predicado LIKE 'Ingreso%': solo los ingresos compiten por la clave natural.
--   Denegado y duplicado quedan fuera, porque son auditoria y el segundo
--   intento del mismo QR DEBE poder registrarse.
-- COALESCE(punto_acceso,''): en un UNIQUE los NULL son distintos entre si; sin
--   COALESCE el mismo QR entraria dos veces por el punto general (punto NULL).
-- qr_code IS NOT NULL: excluye filas sin QR (Denegado legacy) del indice.
-- evento_id NULL: NO colisiona (NULL distinto). Hueco declarado: si F4 no envia
--   evento_id, esa fila no queda protegida por el indice.
--
-- CONCURRENTLY: no bloquea la escritura de la puerta. Requiere autocommit
--   (directiva de la primera linea del archivo).
-- IF NOT EXISTS: no recrea el indice si ya existe. ADVERTENCIA R11: si una
--   ejecucion anterior quedo INTERRUMPIDA, el indice existe pero es INVALID y
--   IF NOT EXISTS lo saltaria en silencio. Verificar SIEMPRE
--   pg_index.indisvalid (PASO 8) y, si es false:
--     DROP INDEX CONCURRENTLY IF EXISTS public.uv_logs_entrada_idem;
--   y reintentar este paso.
-- ----------------------------------------------------------------------------
CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS uv_logs_entrada_idem
    ON public.logs (evento_id, qr_code, COALESCE(punto_acceso, ''))
    WHERE resultado LIKE 'Ingreso%' AND qr_code IS NOT NULL;


-- ----------------------------------------------------------------------------
-- PASO 6 | RLS Y GRANTS: que hace falta para que anon siga insertando
--
-- RLS se evalua por FILA y por POLICY, nunca por columna: agregar op_id/offline
--   no altera ninguna policy existente ni exige CREATE POLICY nueva. El INSERT
--   anon del scanner ya funciona hoy y seguira funcionando con las columnas
--   nuevas, siempre que el privilegio de INSERT sea de TABLA (lo esperado:
--   GRANT INSERT ON public.logs TO anon).
-- UNICO CASO QUE EXIGE ACCION: si el INSERT de anon esta concedido por COLUMNA
--   (poco probable; el pre-chequeo bloque f lo revela), un INSERT que mencione
--   op_id/offline seria rechazado. En ese caso, sumar las columnas:
--
--   GRANT INSERT (op_id, offline) ON public.logs TO anon;
--
-- NO se agrega ninguna policy permisiva: ampliaria el aislamiento cross-tenant
--   que ADR-025/ADR-036 intentan cerrar. NO se toca el DELETE anon (el undo del
--   scanner ya lo usa y es un requisito operativo).
-- ----------------------------------------------------------------------------


-- ----------------------------------------------------------------------------
-- PASO 7 | RECARGA DEL CACHE DE ESQUEMA DE POSTGREST
-- Sin esto, PostgREST no ve op_id/offline hasta el siguiente reinicio.
-- ----------------------------------------------------------------------------
NOTIFY pgrst, 'reload schema';


-- ============================================================================
-- PASO 8 | VERIFICACION POST-APLICACION (comentado: no se ejecuta solo)
--
-- (1) Columnas nuevas:
--     SELECT column_name, data_type, is_nullable, column_default
--     FROM information_schema.columns
--     WHERE table_schema='public' AND table_name='logs'
--       AND column_name IN ('op_id','offline');
--     Esperado: op_id text YES NULL | offline boolean YES false
--
-- (2) CHECK creado y NO validado (convalidated = false es lo correcto):
--     SELECT conname, convalidated, pg_get_constraintdef(oid)
--     FROM pg_constraint
--     WHERE conrelid='public.logs'::regclass
--       AND conname='logs_resultado_canonico_chk';
--
-- (3) Indice valido y unico:
--     SELECT c.relname, i.indisunique, i.indisvalid, pg_get_indexdef(i.indexrelid)
--     FROM pg_index i JOIN pg_class c ON c.oid=i.indexrelid
--     WHERE i.indrelid='public.logs'::regclass
--       AND c.relname='uv_logs_entrada_idem';
--     Esperado: es_unico=true, es_valido=true
--
-- (4) Cero duplicados vivos (debe devolver 0 filas):
--     SELECT evento_id, qr_code, COALESCE(punto_acceso,''), count(*)
--     FROM public.logs
--     WHERE resultado LIKE 'Ingreso%' AND qr_code IS NOT NULL AND evento_id IS NOT NULL
--     GROUP BY 1,2,3 HAVING count(*) > 1;
--
-- (5) Ensayo de idempotencia (en un evento de prueba, luego rollback manual):
--     INSERT repetido con la misma clave natural debe devolver 23505, y el
--     codigo debe tratarlo como "ya aplicado" (no como error de negocio).
-- ============================================================================


-- ============================================================================
-- PASO 9 | ROLLBACK (comentado: no se ejecuta solo)
--
-- Orden obligatorio: indice, CHECK, columnas.
--
--   DROP INDEX CONCURRENTLY IF EXISTS public.uv_logs_entrada_idem;
--   ALTER TABLE public.logs DROP CONSTRAINT IF EXISTS logs_resultado_canonico_chk;
--   ALTER TABLE public.logs DROP COLUMN IF EXISTS offline;
--   ALTER TABLE public.logs DROP COLUMN IF EXISTS op_id;
--   NOTIFY pgrst, 'reload schema';
--
-- Notas:
--   * DROP INDEX CONCURRENTLY tampoco puede ir en transaccion: mantener la
--     directiva no-transaction tambien para el rollback.
--   * El rollback de las columnas descarta la traza op_id/offline de los logs
--     escritos mientras estuvieron activas (no hay forma de recuperarla). Es
--     rollback de ESQUEMA, no de datos de negocio: los logs siguen existiendo.
--   * El CHECK NOT VALID se elimina sin validar nada; no deja filas marcadas.
-- ============================================================================
-- FIN ADR-090 F1
-- ============================================================================
