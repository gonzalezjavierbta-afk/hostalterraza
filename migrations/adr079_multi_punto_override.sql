-- ============================================================================
-- ADR-079 | Multi-punto de check-in: override por ticket y trazabilidad de logs
-- ----------------------------------------------------------------------------
-- Archivo   : migrations/adr079_multi_punto_override.sql
-- Fecha     : 2026-10-07
-- Proposito : habilitar el check-in multi-punto por evento con override a nivel
--             de ticket (inscrito) y cerrar la trazabilidad de los registros de
--             escaneo (logs) con sus claves foraneas a eventos e inscritos.
--             Tres piezas, en este orden:
--   1. Columna nueva public.inscritos.puntos_acceso jsonb DEFAULT NULL:
--      la lista de puntos habilitados SOLO para ese ticket. NULL o [] = el
--      ticket HEREDA la lista base del evento (public.eventos.puntos_acceso,
--      jsonb, array de strings, ya existente).
--   2. Columnas nuevas public.logs.evento_id text y public.logs.inscrito_id text
--      mas sus dos claves foraneas ON DELETE SET NULL hacia eventos(id) e
--      inscritos(id). Hasta hoy logs solo podia guardar el NOMBRE del evento
--      (logs.evento, text) y no tenia relacion alguna con el inscrito.
--   3. Indice compuesto idx_logs_qr_punto sobre logs(qr_code, punto_acceso),
--      que es exactamente el predicado de la consulta caliente del scanner.
--
-- HALLAZGO (esquema real, Fase 0 por @sql-security):
--   * eventos.puntos_acceso = jsonb (array de strings). EXISTE.
--   * inscritos.puntos_acceso NO EXISTIA: es la columna que crea esta migracion.
--   * scanner_tokens.punto_acceso = text; logs.punto_acceso = text.
--   * IDs eventos.id, inscritos.id y logs.id son TEXT, NO uuid: por eso las
--     columnas FK y las referencias son text (un FK text->text). No se
--     convierte ningun id.
--   * logs NO tiene evento_id ni inscrito_id; su unica FK previa era a
--     organizaciones, y logs.evento guarda el NOMBRE del evento.
--   * Backfill logs.evento -> evento por NOMBRE: 44 de 66 registros matchean
--     de forma exacta y no ambigua. logs.qr_code -> inscritos.qr_code: 0 de 18
--     (no hay base para relacionar el log con un inscrito).
--
-- DECISION:
--   * El override es por ticket, no por evento: se anade la columna a inscritos.
--     No se reescribe eventos.puntos_acceso (nadie lo lee de vuelta aqui) y no
--     se borra ninguna fila.
--   * logs.evento_id / logs.inscrito_id son ADITIVAS y NULLABLE. El backfill de
--     evento_id SOLO escribe en filas donde la columna sigue en NULL y SOLO
--     cuando el match por nombre es exacto y NO ambiguo (un nombre que aparece
--     mas de una vez en eventos no se resuelve: no se inventa la relacion).
--   * NO se backfillea inscrito_id: 0 de 18 coincidencias. Forzarlo seria
--     inventar una relacion que los datos no prueban.
--   * ON DELETE SET NULL y no CASCADE: si un evento o un inscrito desapareciera,
--     el log de auditoria se PRESERVA (la referencia se anula, la fila queda).
--
-- ADITIVA, CERO BORRADO (Oro #2):
--   * ADD COLUMN IF NOT EXISTS: no reescribe la tabla fisica ni las filas. En
--     PostgreSQL un ADD COLUMN sin default no barre la tabla (metadata-only).
--   * Los UPDATE solo escriben en logs.evento_id NULL; re-ejecutar no cambia nada.
--   * No se elimina ninguna columna, ninguna fila y no se toca ninguna politica
--     RLS existente.
--   * ROLLBACK documentado al final (comentado, no se ejecuta).
--
-- Idempotencia: 100%. ADD COLUMN IF NOT EXISTS, guard IF NOT EXISTS sobre
-- pg_constraint para las 2 FK (ADD CONSTRAINT no soporta IF NOT EXISTS, por eso
-- va en un bloque DO), CREATE INDEX IF NOT EXISTS y backfill acotado a
-- evento_id IS NULL. El archivo puede ejecutarse 2+ veces sin error ni efecto
-- adicional.
--
-- Notas tecnicas:
--   * Las FK se validan contra id text de eventos e inscritos. logs.evento_id y
--     logs.inscrito_id quedan NULL en las filas historicas no resolubles.
--   * logs.evento (text, el NOMBRE) NO se renombra ni se borra: se conserva como
--     dato de origen y con el que se hizo el backfill.
--   * NOTIFY pgrst, 'reload schema': una columna nueva no es visible para
--     PostgREST hasta que se recarga el cache (mismo patron que adr051/adr073).
--
-- Caracteristicas: 100% ASCII (cero bytes > 127), cero tildes, cero emojis,
-- cero backticks, terminacion de linea LF. Solo ALTER TABLE ADD COLUMN,
-- ALTER TABLE ADD CONSTRAINT (en bloque DO), UPDATE de backfill, CREATE INDEX y
-- COMMENT. No crea tablas nuevas, no toca RLS.
--
-- Estado: APLICADA a produccion ctgyvydzshueemlelkzv por @data-migration con
-- el gate de riesgo de AGENTS.md seccion 2 autorizado (2026-10-07).
-- ============================================================================


-- ----------------------------------------------------------------------------
-- BLOQUE 1: COLUMNA DE OVERRIDE POR TICKET EN inscritos
--
-- jsonb (array de strings) y NO text[]: simetria de tipo con la columna base ya
-- existente eventos.puntos_acceso (jsonb), de modo que el front las trate igual.
-- DEFAULT NULL a proposito: NULL (y tambien []) significa "sin override, hereda
-- eventos.puntos_acceso". Se agrega al FINAL de la tabla; ningun lector por
-- posicion se altera.
-- ----------------------------------------------------------------------------

ALTER TABLE public.inscritos
    ADD COLUMN IF NOT EXISTS puntos_acceso jsonb DEFAULT NULL;

COMMENT ON COLUMN public.inscritos.puntos_acceso IS
  'Override por ticket de los puntos de check-in (ADR-079). jsonb con array de strings. NULL o [] = el ticket hereda eventos.puntos_acceso.';


-- ----------------------------------------------------------------------------
-- BLOQUE 2: COLUMNAS DE TRAZABILIDAD EN logs
--
-- text (no uuid) porque los id de eventos, inscritos y logs son text.
-- NULLABLE: no todo log historico se puede relacionar (ver Bloque 4).
-- ----------------------------------------------------------------------------

ALTER TABLE public.logs
    ADD COLUMN IF NOT EXISTS evento_id text;

ALTER TABLE public.logs
    ADD COLUMN IF NOT EXISTS inscrito_id text;

COMMENT ON COLUMN public.logs.evento_id IS
  'FK a eventos(id), text (ADR-079). Relacion canonica del log con el evento. Backfill por match exacto y no ambiguo de logs.evento (nombre); NULL si no se pudo resolver. ON DELETE SET NULL preserva la auditoria.';

COMMENT ON COLUMN public.logs.inscrito_id IS
  'FK a inscritos(id), text (ADR-079). Relacion del log con el inscrito. NO backfilleada: 0 de 18 logs.qr_code coinciden con inscritos.qr_code. NULL hasta que el emisor la escriba. ON DELETE SET NULL preserva la auditoria.';


-- ----------------------------------------------------------------------------
-- BLOQUE 3: CLAVES FORANEAS (ON DELETE SET NULL)
--
-- ADD CONSTRAINT no admite IF NOT EXISTS, por eso cada FK va en un bloque DO
-- que consulta pg_constraint por (conname, conrelid). Re-ejecutable.
-- ON DELETE SET NULL: si un evento/inscrito se borra, el log de auditoria no se
-- borra, solo se anula su referencia (Cero Borrado).
-- ----------------------------------------------------------------------------

DO $adr079_fk_evento$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname  = 'logs_evento_id_fkey'
          AND conrelid = 'public.logs'::regclass
    ) THEN
        ALTER TABLE public.logs
            ADD CONSTRAINT logs_evento_id_fkey
            FOREIGN KEY (evento_id) REFERENCES public.eventos(id)
            ON DELETE SET NULL;
    END IF;
END $adr079_fk_evento$;

DO $adr079_fk_inscrito$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname  = 'logs_inscrito_id_fkey'
          AND conrelid = 'public.logs'::regclass
    ) THEN
        ALTER TABLE public.logs
            ADD CONSTRAINT logs_inscrito_id_fkey
            FOREIGN KEY (inscrito_id) REFERENCES public.inscritos(id)
            ON DELETE SET NULL;
    END IF;
END $adr079_fk_inscrito$;


-- ----------------------------------------------------------------------------
-- BLOQUE 4: BACKFILL DE logs.evento_id (solo match exacto y NO ambiguo)
--
-- El WHERE repite evento_id IS NULL para que la migracion sea re-ejecutable y
-- para no pisar un valor ya escrito. El subquery exige que el nombre del evento
-- sea UNICO en eventos: si dos eventos comparten nombre, la fila queda NULL
-- (no se adivina cual de los dos es). logs.evento conserva el nombre original.
--
-- NO se backfillea logs.inscrito_id: la Fase 0 verifico 0 de 18 coincidencias
-- entre logs.qr_code e inscritos.qr_code. Se deja NULL de forma deliberada.
-- ----------------------------------------------------------------------------

UPDATE public.logs l
   SET evento_id = e.id
  FROM public.eventos e
 WHERE l.evento_id IS NULL
   AND l.evento = e.nombre
   AND (SELECT count(*) FROM public.eventos e2 WHERE e2.nombre = e.nombre) = 1;


-- ----------------------------------------------------------------------------
-- BLOQUE 5: INDICE PARA LA CONSULTA CALIENTE DEL SCANNER
--
-- La validacion/undo del scanner resuelve "existe un log de este qr_code en este
-- punto_acceso" con un predicado de igualdad exacto:
--   .eq('qr_code', code).eq('punto_acceso', puntoAcceso)   (scanner.html)
-- El btree compuesto (qr_code, punto_acceso) es el camino de acceso directo
-- para esa consulta y para el dedup en memoria que la alimenta. Se incluye.
-- ----------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_logs_qr_punto
    ON public.logs (qr_code, punto_acceso);


-- ----------------------------------------------------------------------------
-- BLOQUE 6: RECARGA DEL SCHEMA CACHE DE POSTGREST
-- ----------------------------------------------------------------------------

NOTIFY pgrst, 'reload schema';


-- ============================================================================
-- BLOQUE DE VERIFICACION (para la Direccion; ejecutar DESPUES de correr este
-- archivo). Todo lo de abajo esta comentado: el archivo no ejecuta nada de esta
-- seccion.
--
-- (1) TIPOS DE LAS 3 COLUMNAS NUEVAS (information_schema.columns):
--     puntos_acceso => jsonb | YES | NULL
--     evento_id     => text  | YES | NULL
--     inscrito_id   => text  | YES | NULL
--
-- SELECT table_name, column_name, data_type, is_nullable, column_default
-- FROM information_schema.columns
-- WHERE table_schema = 'public'
--   AND ((table_name = 'inscritos' AND column_name = 'puntos_acceso')
--     OR (table_name = 'logs' AND column_name IN ('evento_id','inscrito_id')))
-- ORDER BY table_name, column_name;
--
-- (2) LAS 2 FK EXISTEN (pg_constraint): debe devolver 2 filas. confdeltype = 'n'
--     significa ON DELETE SET NULL.
--
-- SELECT conname, conrelid::regclass AS tabla, confrelid::regclass AS referencia,
--        confdeltype
-- FROM pg_constraint
-- WHERE conname IN ('logs_evento_id_fkey','logs_inscrito_id_fkey');
--
-- (3) RECUENTO DEL BACKFILL: total / con_evento_id / con_inscrito_id.
--
-- SELECT count(*) AS total_logs,
--        count(evento_id)   AS con_evento_id,
--        count(inscrito_id) AS con_inscrito_id
-- FROM public.logs;
--
-- (4) PENDIENTES POR AMBIGUEDAD O SIN MATCH: filas que siguen sin evento_id y
--     cuyo nombre esta repetido en eventos (ambiguas) o no existe (sin match).
--
-- SELECT count(*) FILTER (WHERE e.repetidos > 1) AS ambiguas,
--        count(*) FILTER (WHERE e.repetidos IS NULL) AS sin_match
-- FROM public.logs l
-- LEFT JOIN (
--     SELECT nombre, count(*) AS repetidos
--     FROM public.eventos GROUP BY nombre
-- ) e ON e.nombre = l.evento
-- WHERE l.evento_id IS NULL;
--
-- (5) EL INDICE EXISTE (pg_indexes): debe existir idx_logs_qr_punto sobre
--     (qr_code, punto_acceso).
--
-- SELECT indexname, indexdef
-- FROM pg_indexes
-- WHERE schemaname = 'public'
--   AND tablename  = 'logs'
--   AND indexname  = 'idx_logs_qr_punto';
-- ============================================================================
-- ROLLBACK (documentado, comentado; requiere gate de riesgo).
-- Cero Borrado: NO se borra ninguna fila. Al revertir se pierden la columna de
-- override y las relaciones derivadas; logs.evento (el nombre de origen) sigue
-- intacto, asi que el backfill se puede volver a correr.
--   DROP INDEX IF EXISTS public.idx_logs_qr_punto;
--   ALTER TABLE public.logs DROP CONSTRAINT IF EXISTS logs_evento_id_fkey;
--   ALTER TABLE public.logs DROP CONSTRAINT IF EXISTS logs_inscrito_id_fkey;
--   ALTER TABLE public.logs DROP COLUMN IF EXISTS evento_id;
--   ALTER TABLE public.logs DROP COLUMN IF EXISTS inscrito_id;
--   ALTER TABLE public.inscritos DROP COLUMN IF EXISTS puntos_acceso;
-- ============================================================================
