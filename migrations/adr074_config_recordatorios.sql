-- ============================================================================
-- ADR-074 | Configuracion del recordatorio automatico (tabla + resolver)
-- ----------------------------------------------------------------------------
-- Archivo   : migrations/adr074_config_recordatorios.sql
-- Fecha     : 2026-10-03
-- Proposito : guardar de forma CONFIGURABLE cuando se avisa de un evento. Hoy
--             el valor pedido es 56 horas antes del evento, pero 56 escrito a
--             mano en el codigo del futuro cron no es configuracion. Esta
--             migracion deja el valor en datos, no en codigo.
--
-- DEPENDENCIA: requiere ADR-073 aplicada (eventos.evento_inicio), porque el
--   calculo "faltan N horas para el evento" necesita el instante canonico.
--   Aqui NO se crea ningun cron, ningun trigger de envio y ninguna Edge
--   Function: esto es solo la capa de configuracion y su lectura.
--
-- DEFAULT GLOBAL: 56 horas.
--   Es una DECISION DE NEGOCIO, no un valor tecnico: 56h deja margen para un
--   recordatorio deConfirmation y otro el dia previo sin que ambos caigan el
--   mismo dia. Si el negocio quiere otro numero, se UPDATEa la fila global
--   (no hace falta tocar codigo ni volver a correr esta migracion).
--
-- GRANULARIDAD POR EVENTO: dos niveles, con el especifico gana.
--   evento_id NULL  -> fila GLOBAL, aplica a todos los eventos sin override
--   evento_id = X   -> override SOLO de ese evento
--   ninguno         -> constante 56 (ultimo recurso, fail-safe)
--
-- POR QUE evento_id UNIQUE Y NULLABLE:
--   UNIQUE garantiza que un evento no tenga dos overrides contradictorios
--   (ORDER BY/LIMIT 1 en la funcion es la red, no la norma). NULLABLE es lo
--   que permite la fila global sin inventar un evento_id centinela. Nota de
--   PostgreSQL: en un UNIQUE los NULL NO chocan entre si, asi que ese UNIQUE
--   NO impide varias filas globales; por eso esta migracion ademas crea un
--   indice unico parcial (BLOQUE 3b) que si las limita a una, el INSERT global
--   esta guardado con WHERE NOT EXISTS, y la funcion resuelve el caso
--   multi-global de forma determinista (ver BLOQUE 6).
--
-- CHECK horas_anticipacion: > 0 y <= 720 (30 dias). Abajo de 0 o 0 no es un
--   recordatorio, es ruido o un envio inmediato; mas de 720h es un aviso que
--   llega antes de que el evento exista en la agenda de la gente.
--
-- CHECK canal: solo 'email' por ahora. Se agrega el valor al CHECK cuando
--   exista el canal (whatsapp, sms); no se deja libre para no crear filas con
--   un canal que nadie procesa.
--
-- Idempotencia: 100%. CREATE TABLE IF NOT EXISTS, dos bloques DO (uno por
--   cada CHECK y otro por la FK) con guarda en pg_constraint, e INSERT global
--   con WHERE NOT EXISTS. Se puede ejecutar 2+ veces seguidas sin error y sin
--   duplicar la fila global.
--
-- ADITIVA, CERO BORRADO (Oro #2): no se altera ninguna tabla existente, no se
--   borra ninguna fila, no se modifica ninguna politica RLS existente.
--
-- RLS DE ESTA TABLA (nuevo, no toca nada de los demas):
--   Se activa RLS en config_recordatorios y NO se crea ninguna politica. Eso
--   es fail-closed: con RLS activa y cero politicas, `anon` y `authenticated`
--   no ven ni una fila. Es lo correcto para una tabla de configuracion que hoy
--   no tiene consumidor. CUANDO exista el backend del recordatorio habra que
--   abrir lectura explicitamente (politica SELECT para `authenticated`, o
--   mover el resolver a SECURITY DEFINER); hasta entonces
--   fn_horas_recordatorio() devuelve 56 para cualquiera que no sea owner,
--   que es justo el default de negocio.
--
-- ESTADO: ESCRITO, NO APLICADO. Requiere credenciales `service_role` desde el
--   SQL Editor de Supabase y el gate de riesgo de AGENTS.md seccion 2.
--
-- Verificacion: ver el BLOQUE DE VERIFICACION al final (todo comentado, el
--   archivo no ejecuta nada de esa seccion).
-- ============================================================================


-- ----------------------------------------------------------------------------
-- BLOQUE 1: TABLA config_recordatorios
--
-- NOTA sobre gen_random_uuid(): es la funcion de pg_catalog, disponible en
-- PostgreSQL 13+ sin instalar nada (Supabase corre PG 17). No requiere que
-- pgcrypto este habilitada en el schema `public` ni califica el nombre, asi
-- que no depende de la ruta de busqueda de la sesion.
--
-- NOTA sobre plantilla: columna libre (text, sin CHECK) para las futuras
-- variantes de texto del recordatorio. hoy no la lee nadie; queda declarada
-- para no tener que alterar la tabla mas adelante.
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.config_recordatorios (
    id                 uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    evento_id          text        UNIQUE,
    activo             boolean     NOT NULL DEFAULT true,
    horas_anticipacion integer     NOT NULL DEFAULT 56,
    canal              text        NOT NULL DEFAULT 'email',
    plantilla          text,
    created_at         timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now()
);


-- ----------------------------------------------------------------------------
-- BLOQUE 2: CHECK CONSTRAINTS (idempotentes, con guarda en pg_constraint)
--
-- Mismo patron que adr051: se consulta el catalogo por el nombre canonico y
-- solo se agrega el constraint si no existe, con RAISE NOTICE en las dos
-- ramas. Si el CHECK ya estaba (p.ej. definido dentro del CREATE TABLE en una
-- version anterior de este archivo) no se intenta volver a crearlo.
-- ----------------------------------------------------------------------------

DO $adr074_checks$
BEGIN
    -- (2.1) Rango de anticipacion: 1..720 horas.
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
        WHERE c.conname = 'config_recordatorios_horas_check'
          AND c.conrelid = 'public.config_recordatorios'::regclass
    ) THEN
        ALTER TABLE public.config_recordatorios
            ADD CONSTRAINT config_recordatorios_horas_check
            CHECK (horas_anticipacion > 0 AND horas_anticipacion <= 720);
        RAISE NOTICE '[INFO] ADR-074: constraint "config_recordatorios_horas_check" creado.';
    ELSE
        RAISE NOTICE '[INFO] ADR-074: constraint "config_recordatorios_horas_check" ya existe, skip.';
    END IF;

    -- (2.2) Canal cerrado: por ahora solo 'email'.
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
        WHERE c.conname = 'config_recordatorios_canal_check'
          AND c.conrelid = 'public.config_recordatorios'::regclass
    ) THEN
        ALTER TABLE public.config_recordatorios
            ADD CONSTRAINT config_recordatorios_canal_check
            CHECK (canal IN ('email'));
        RAISE NOTICE '[INFO] ADR-074: constraint "config_recordatorios_canal_check" creado.';
    ELSE
        RAISE NOTICE '[INFO] ADR-074: constraint "config_recordatorios_canal_check" ya existe, skip.';
    END IF;

    -- (2.3) hora_inicio no aplica aqui (no existe columna de ese tipo); la
    --       franja horaria de envio es logica del cron futuro, no un dato de
    --       configuracion de este ADR. Se deja constancia para que no se
    --       agregue sin decision.
END $adr074_checks$;


-- ----------------------------------------------------------------------------
-- BLOQUE 3: FK de evento_id (condicional y fail-safe)
--
-- Una FK necesita DOS cosas: (1) que eventos.id tenga PRIMARY KEY o UNIQUE, y
-- (2) que ambos lados tengan el MISMO tipo. En PRODUCCION (introspeccion
-- read-only del 2026-10-03) public.eventos.id es TEXT, no uuid: los valores
-- PARECEN uuid (ej. '647803c9-bace-4d33-a175-8edeb0e6fc33') pero la columna
-- es data_type = text, udt_name = text. Por eso config_recordatorios.evento_id
-- se declara TEXT y NO uuid.
--
-- POR QUE NO se "arregla" migrando eventos.id a uuid: eso es una migracion de
-- DATOS (reescribir una tabla existente con miles de filas y todas sus FK
-- hijas), no una migracion aditiva de esquema. Queda FUERA del alcance de
-- esta migracion. La salida correcta es alinear la columna NUEVA con el tipo
-- REAL de eventos.id.
--
-- LECCION (dry-run fallido del 2026-10-03): con evento_id declarado uuid, el
-- bloque de abajo creaba los 2 CHECK y reventaba despues con
-- `42804: foreign key constraint "config_recordatorios_evento_id_fkey" cannot
-- be implemented`, porque el guard solo comprobaba la EXISTENCIA de la clave y
-- no la COINCIDENCIA de tipos. Por eso este bloque ahora compara los dos
-- tipos en el catalogo ANTES de tocar nada: si no coinciden (o si alguna
-- columna no existe), avisa con WARNING y OMITE la FK, en vez de dejar que
-- Postgres reviente la transaccion entera. El fallo sigue siendo fail-closed
-- en los dos casos: la tabla se crea igual, pero sin integridad referencial,
-- que es preferible a que la migracion entera falle.
--
-- ON DELETE CASCADE: define COMO se comportaria un DELETE futuro sobre
-- eventos. Esta migracion no borra nada (Cero Borrado). Se elige CASCADE y no
-- SET NULL a proposito: si un evento desapareciera, su override debe
-- desaparecer con el; un SET NULL convertiria ese override en una fila
-- GLOBAL y el 56h de un evento se aplicaria a todos los demas.
-- ----------------------------------------------------------------------------

DO $adr074_fk$
DECLARE
    v_eventos_tiene_clave integer;
    v_tipo_config        text;
    v_tipo_eventos       text;
BEGIN
    -- (3.1) TIPOS DE AMBOS LADOS, leidos una sola vez del catalogo. Se leen
    --   antes que nada porque los dos warnings de este bloque los nombran: si
    --   el diagnostico no dice los tipos, el problema reaparece como 42804 y
    --   hay que volver a mirar el catalogo a mano.
    --   attnum > 0 y NOT attisdropped descartan las columnas de sistema.
    SELECT format_type(a.atttypid, a.atttypmod)
      INTO v_tipo_config
      FROM pg_attribute a
     WHERE a.attrelid = 'public.config_recordatorios'::regclass
       AND a.attname  = 'evento_id'
       AND a.attnum   > 0
       AND NOT a.attisdropped;

    SELECT format_type(a.atttypid, a.atttypmod)
      INTO v_tipo_eventos
      FROM pg_attribute a
     WHERE a.attrelid = 'public.eventos'::regclass
       AND a.attname  = 'id'
       AND a.attnum   > 0
       AND NOT a.attisdropped;

    -- (3.2) CLAVE REFERENCIABLE: PRIMARY KEY o UNIQUE exactamente sobre
    --   eventos.id (conkey = solo esa columna). Fail-closed: sin clave no se
    --   intenta la FK, se avisa y se sale.
    SELECT count(*) INTO v_eventos_tiene_clave
    FROM pg_constraint c
    WHERE c.conrelid = 'public.eventos'::regclass
      AND c.contype IN ('p', 'u')
      AND c.conkey = ARRAY[
            (SELECT attnum FROM pg_attribute
              WHERE attrelid = 'public.eventos'::regclass
                AND attname = 'id')]::smallint[];

    IF v_eventos_tiene_clave = 0 THEN
        RAISE WARNING '[ADR-074] public.eventos no tiene PRIMARY KEY ni UNIQUE sobre id: NO se crea la FK config_recordatorios_evento_id_fkey. Tipos observados: config_recordatorios.evento_id = "%", public.eventos.id = "%". Revisar a mano.', COALESCE(v_tipo_config, '<columna ausente>'), COALESCE(v_tipo_eventos, '<columna ausente>');
        RETURN;
    END IF;

    -- (3.3) COMPATIBILIDAD DE TIPOS: la FK exige el MISMO tipo a los dos lados
    --   (mismo tipo base y misma familia de operadores de igualdad). Con
    --   evento_id uuid contra un eventos.id text, Postgres responde
    --   42804 "foreign key constraint ... cannot be implemented" y MUERE la
    --   transaccion, con lo cual se pierde TODO lo que el bloque ya habia
    --   aplicado en la misma corrida.
    --   IS DISTINCT FROM cubre tambien el caso "la columna no existe"
    --   (format_type devuelve NULL y NULL es distinto de cualquier texto).
    IF v_tipo_config IS DISTINCT FROM v_tipo_eventos THEN
        RAISE WARNING '[ADR-074] tipos INCOMPATIBLES: config_recordatorios.evento_id = "%" y public.eventos.id = "%": una FK exige el mismo tipo a los dos lados, asi que NO se crea la FK config_recordatorios_evento_id_fkey (se evita el error 42804). Revisar a mano.', COALESCE(v_tipo_config, '<columna ausente>'), COALESCE(v_tipo_eventos, '<columna ausente>');
        RETURN;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint c
        WHERE c.conname = 'config_recordatorios_evento_id_fkey'
          AND c.conrelid = 'public.config_recordatorios'::regclass
    ) THEN
        ALTER TABLE public.config_recordatorios
            ADD CONSTRAINT config_recordatorios_evento_id_fkey
            FOREIGN KEY (evento_id) REFERENCES public.eventos (id)
            ON DELETE CASCADE;
        RAISE NOTICE '[INFO] ADR-074: FK "config_recordatorios_evento_id_fkey" creada.';
    ELSE
        RAISE NOTICE '[INFO] ADR-074: FK "config_recordatorios_evento_id_fkey" ya existe, skip.';
    END IF;
END $adr074_fk$;


-- ----------------------------------------------------------------------------
-- BLOQUE 3b: UNA SOLA FILA GLOBAL, GARANTIZADO POR EL MOTOR
--
-- Por que hace falta: en PostgreSQL los NULL NO chocan entre si en un UNIQUE,
-- asi que `evento_id text UNIQUE` NO impide tener varias filas globales. El
-- UNIQUE de la columna solo protege el nivel de override por evento.
--
-- El indice es sobre la expresion constante (1) con predicado
-- `WHERE evento_id IS NULL`: solo indexa las filas globales, y como todas
-- producen la misma clave, el indice UNIQUE admite como mucho una. Es el
-- mecanismo estandar para "esta tabla tiene una fila global y solo una".
--
-- ADITIVO (Oro #2): no borra ni reescribe filas. Es una garantia de integridad
-- hacia adelante: si alguien mas adelante inserta una segunda global a mano,
-- el INSERT falla en vez de crear una ambiguedad silenciosa.
--
-- ORDEN a proposito: el indice se crea ANTES del INSERT global. Si por un
-- error previo quedaran dos globales, el CREATE UNIQUE INDEX falla aqui (se ve
-- el problema en vez de dejarlo pasar) y la migracion se detiene en este punto.
--
-- El predicado `IS NOT NULL` es implicito: las filas con evento_id NULL ya no
-- entran al indice por el WHERE.
-- ----------------------------------------------------------------------------

CREATE UNIQUE INDEX IF NOT EXISTS idx_config_recordatorios_global
    ON public.config_recordatorios ((1))
    WHERE evento_id IS NULL;


-- ----------------------------------------------------------------------------
-- BLOQUE 4: FILA GLOBAL POR DEFECTO (evento_id IS NULL, 56h, activa)
--
-- WHERE NOT EXISTS: la segunda corrida no inserta nada. El UNIQUE de evento_id
-- NO protege este INSERT (los NULL no chocan), asi que la idempotencia la da el
-- NOT EXISTS; y la unicidad de la fila global, de ahora en mas, la impone el
-- indice unico parcial del BLOQUE 3b. El 56 explicito de abajo no se rescribe
-- nunca: si la fila global ya existe, el INSERT no corre y su valor se
-- respeta (re-ejecutar esta migracion NO pisa una configuracion cambiada a
-- mano).
--
-- La fila se crea con horas_anticipacion = 56 explicito (no solo por default)
-- para que un lector del archivo vea el numero de negocio sin tener que
-- deducirlo del DEFAULT de la columna.
-- ----------------------------------------------------------------------------

INSERT INTO public.config_recordatorios
    (evento_id, activo, horas_anticipacion, canal)
SELECT
    NULL, true, 56, 'email'
WHERE NOT EXISTS (
    SELECT 1
    FROM public.config_recordatorios
    WHERE evento_id IS NULL
);


-- ----------------------------------------------------------------------------
-- BLOQUE 5: RLS fail-closed en la tabla nueva
--
-- NO se crean politicas (a proposito). Con RLS activa y sin politicas, ningun
-- rol sin BYPASSRLS lee la tabla. No se toca RLS de ninguna otra tabla ni
-- ninguna politica existente.
--
-- NOTA: si la sesion que ejecuta este archivo corre con un rol que no es
-- superusuario (por ejemplo postgres en Supabase sigue siendo superuser, asi
-- que esto es solo una advertencia de orden), el ROLLBACK lo deja explicito.
-- ----------------------------------------------------------------------------

ALTER TABLE public.config_recordatorios ENABLE ROW LEVEL SECURITY;


-- ----------------------------------------------------------------------------
-- BLOQUE 6: RESOLVER fn_horas_recordatorio(p_evento_id text)
--
-- Precedencia: override del evento -> fila global -> constante 56.
--
-- DETERMINISMO (importante): el UNIQUE de evento_id impide dos overrides del
-- mismo evento, pero NO impide varias filas globales (los NULL no chocan en
-- un UNIQUE). Si alguien inserta dos filas globales, ORDER BY + LIMIT 1 fija
-- cual manda: la de updated_at mas reciente; los desempates se rompen con
-- created_at ascendente y luego id, que es un total order (no hay empate
-- posible), asi que dos llamadas concurrentes devuelven lo mismo.
--
-- NOTA sobre `activo` (contrato explicito, para que no se malinterprete):
--   la funcion NO filtra por activo. `activo` es un interruptor INDEPENDIENTE
--   que debe leer el proceso que envia, no esta funcion: un resolver que
--   devolviera 0 o NULL para "desactivado" seria peor, porque 0 significa
--   "sin margen" y el rango valido empieza en 1. Verificacion (6) muestra las
--   dos columnas juntas para que la decision sea visible.
--
-- SECURITY: LANGUAGE sql STABLE, sin SECURITY DEFINER (esta migracion es de
--   esquema, no de acceso). Con RLS activa y sin politicas, un llamador
--   `authenticated` no ve filas y cae en el 56; un owner (service_role) si
--   ve la configuracion. Ese comportamiento es intencional.
-- ----------------------------------------------------------------------------

-- TIPO DEL PARAMETRO: text, NO uuid, y no es cosmetico. El parametro se
-- compara con c.evento_id (que es text, ver BLOQUE 1): con el parametro en
-- uuid, `c.evento_id = p_evento_id` seria text = uuid, una comparacion que no
-- tiene operador de igualdad en PostgreSQL, y el resolver fallaria en
-- runtime. El parametro sigue el tipo de la columna, igual que en
-- config_recordatorios.evento_id.
--
CREATE OR REPLACE FUNCTION public.fn_horas_recordatorio(p_evento_id text)
RETURNS integer
LANGUAGE sql
STABLE
AS $fn$
    SELECT COALESCE(
        -- (1) override especifico del evento
        (
            SELECT c.horas_anticipacion
            FROM public.config_recordatorios c
            WHERE c.evento_id = p_evento_id
            ORDER BY c.updated_at DESC, c.created_at ASC, c.id ASC
            LIMIT 1
        ),
        -- (2) fila global (evento_id IS NULL)
        (
            SELECT c.horas_anticipacion
            FROM public.config_recordatorios c
            WHERE c.evento_id IS NULL
            ORDER BY c.updated_at DESC, c.created_at ASC, c.id ASC
            LIMIT 1
        ),
        -- (3) ultimo recurso: el default de negocio escrito en el codigo
        56
    ) AS horas_anticipacion;
$fn$;


-- ----------------------------------------------------------------------------
-- BLOQUE 7: RECARGA DEL SCHEMA CACHE DE POSTGREST
-- (misma razon que en adr051/adr073: objetos nuevos no son visibles hasta
--  que se recarga el cache)
-- ----------------------------------------------------------------------------

NOTIFY pgrst, 'reload schema';


-- ===========================================================================
-- BLOQUE DE VERIFICACION (para la Direccion; ejecutar DESPUES de correr este
-- archivo). Todo lo de abajo esta comentado: el archivo no ejecuta nada de
-- esta seccion.
--
-- (1) LA TABLA EXISTE con las 8 columnas esperadas, en este orden:
--     id, evento_id, activo, horas_anticipacion, canal, plantilla,
--     created_at, updated_at
--
-- SELECT ordinal_position, column_name, data_type, is_nullable, column_default
-- FROM information_schema.columns
-- WHERE table_schema = 'public'
--   AND table_name   = 'config_recordatorios'
-- ORDER BY ordinal_position;
--
-- (2) UNA SOLA FILA GLOBAL con 56h (si devuelve mas de una fila, el
--     idempotencia del BLOQUE 4 esta roto):
--
-- SELECT count(*) AS filas_globales
-- FROM public.config_recordatorios
-- WHERE evento_id IS NULL;
--
-- SELECT * FROM public.config_recordatorios ORDER BY created_at;
--
-- (2b) EL INDICE UNICO PARCIAL EXISTE (pg_indexes): debe existir
--      idx_config_recordatorios_global y su indexdef debe traer
--      `UNIQUE INDEX ... USING btree (((1))) WHERE (evento_id IS NULL)`.
--
-- SELECT indexname, indexdef
-- FROM pg_indexes
-- WHERE schemaname = 'public'
--   AND tablename  = 'config_recordatorios'
--   AND indexname  = 'idx_config_recordatorios_global';
--
-- (2c) PRUEBA NEGATIVA de la fila global: este INSERT debe fallar con
--      `duplicate key value violates unique constraint
--      "idx_config_recordatorios_global"`. Si NO falla, el indice no esta
--      protegiendo la fila global.
--
-- INSERT INTO public.config_recordatorios (evento_id, horas_anticipacion)
-- VALUES (NULL, 99);
--
-- (3) LOS CHECK ESTAN Y SON LO QUE PIDEN SER (pg_get_constraintdef):
--     horas: CHECK ((horas_anticipacion > 0) AND (horas_anticipacion <= 720))
--     canal: CHECK ((canal = ANY (ARRAY['email'::text])))
--
-- SELECT c.conname, pg_get_constraintdef(c.oid) AS definicion
-- FROM pg_constraint c
-- WHERE c.conrelid = 'public.config_recordatorios'::regclass
-- ORDER BY c.conname;
--
-- (3b) PRUEBA NEGATIVA de los CHECK: las dos filas de abajo deben fallar con
--      error de constraint. Ejecutar una por una (la que falle es la correcta
--      si las dos fallan).
--
-- INSERT INTO public.config_recordatorios (horas_anticipacion) VALUES (0);
--       -- debe fallar: config_recordatorios_horas_check
-- INSERT INTO public.config_recordatorios (horas_anticipacion) VALUES (721);
--       -- debe fallar: config_recordatorios_horas_check
-- INSERT INTO public.config_recordatorios (canal) VALUES ('sms');
--       -- debe fallar: config_recordatorios_canal_check
--
-- (4) LA FUNCION RESUELVE:
--     (a) con NULL (no hay override de evento) -> debe devolver 56, el de la
--         fila global;
--     (b) con un evento real -> 56 si no tiene override;
--     (c) con un evento ficticio que NO existe en eventos -> 56 tambien
--         (la tabla de config no tiene ese evento, y el fallback es el
--         default, no un error);
--     (d) con un override de prueba en un evento real -> el valor del
--         override. Para (d): INSERTAR una fila con horas_anticipacion = 72
--         para un evento existente y luego DELETE de esa fila (esta es la
--         unica prueba que borra algo, y solo una fila de prueba creada en
--         este mismo paso).
--
-- SELECT public.fn_horas_recordatorio(NULL) AS sin_evento;         -- -> 56
--
-- SELECT public.fn_horas_recordatorio(
--          (SELECT id FROM public.eventos ORDER BY id LIMIT 1)
--      ) AS evento_real_sin_override;                              -- -> 56
--
-- SELECT public.fn_horas_recordatorio(
--          '00000000-0000-0000-0000-000000000000'::text
--      ) AS evento_ficticio;                                       -- -> 56
--
-- (5) RLS fail-closed: la tabla debe reportar 0 politicas. Si aparece alguna,
--    algo abrio la tabla sin pasar por esta migracion.
--
-- SELECT count(*) AS politicas
-- FROM pg_policies
-- WHERE schemaname = 'public' AND tablename = 'config_recordatorios';  -- -> 0
--
-- SELECT relrowsecurity, relforcerowsecurity
-- FROM pg_class
-- WHERE oid = 'public.config_recordatorios'::regclass;   -- -> true | false
--
-- (6) CONFIGURACION COMPLETA, override + global juntos (asi se ve que activo
--     NO filtra la precedencia, por diseno del BLOQUE 6):
--
-- SELECT evento_id, activo, horas_anticipacion, canal, plantilla,
--        updated_at
-- FROM public.config_recordatorios
-- ORDER BY evento_id NULLS FIRST;
--
-- (6b) EVENTOS LISTOS PARA EL RECORDATORIO (cruzamiento con ADR-073): la
--      consulta que hara el cron. Si un evento aparece aqui con
--      evento_inicio NULL, su backfill quedo pendiente (ver ADR-073 punto 3).
--
-- SELECT e.slug, e.evento_inicio,
--        public.fn_horas_recordatorio(e.id) AS horas,
--        e.evento_inicio
--          - make_interval(hours => public.fn_horas_recordatorio(e.id))
--        AS momento_de_aviso
-- FROM public.eventos e
-- WHERE e.evento_inicio IS NOT NULL
-- ORDER BY e.evento_inicio
-- LIMIT 20;
-- ===========================================================================
-- ROLLBACK (documentado, comentado; requiere gate de riesgo).
-- ATENCION: este es el unico bloque del proyecto que propose borrar filas, y
-- solo lo hace si la Direccion lo descomenta de forma expresa. Contiene el
-- DELETE de la fila global y de los overrides creados para pruebas.
--   DROP FUNCTION IF EXISTS public.fn_horas_recordatorio(text);
--   DELETE FROM public.config_recordatorios WHERE evento_id IS NULL;
--       -- (uncomment SOLO con decision editorial: borra la fila global)
--   DROP TABLE IF EXISTS public.config_recordatorios;
-- ===========================================================================