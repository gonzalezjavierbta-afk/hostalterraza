-- ============================================================================
-- oneoff_modules_wire_baseline.sql                           (2026-11-10)
-- ADR-093 / TSK-139
--
-- PROBLEMA
--   Hasta hoy el kernel publico solo leia 5 claves de config_landing.modules:
--   gallery, whatsapp, guest_list, form y boletos_guestlist. Las 11 claves de
--   este archivo las escribia el admin desde hacia tiempo pero el motor NUNCA
--   las leyo (ADR-093 R1: un flag que el admin escribe y el kernel no lee es un
--   BUG, no una feature pendiente). Como no surtian efecto, cualquier false
--   almacenado NO fue una decision verificada: nadie pudo ver su consecuencia.
--   Al cablearlas (TSK-139), ese false apagaria secciones que hoy se ven
--   completas. Este one-off fija la LINEA BASE en true ANTES del despliegue.
--
-- QUE HACE
--   Un unico UPDATE sobre eventos. SOLO donde la clave EXISTE con el booleano
--   JSON false, la pasa a true:
--     playlist, boletos, ubicacion, banner_1, banner_2, historia, objetivo,
--     impacto, equipo, faq, sponsors
--   Tecnica: merge jsonb quirurgico (||) con una mascara construida por
--   jsonb_object_agg sobre las claves que estan en false. No crea claves
--   ausentes, no borra claves, no reescribe el objeto modules completo y no
--   reescribe config_landing (solo su rama modules via jsonb_set).
--
-- ALCANCE
--   1 tabla (eventos), 1 columna (config_landing jsonb). 0 DDL, 0 RLS, 0
--   indices, 0 cambios de esquema.
--   NO TOCA (sus false SI son decisiones reales, el motor ya los respetaba):
--   gallery, whatsapp, guest_list, form, boletos_guestlist.
--   NO TOCA el resto de config_landing: content, colors, effects, theme.
--
-- IDEMPOTENCIA
--   Segunda ejecucion = 0 filas: el WHERE exige al menos una clave en false y
--   el merge solo escribe true sobre false. Ninguna otra clave se reescribe.
--
-- SEMANTICA ESTRICTA
--   Solo se compara contra el booleano JSON false ('false'::jsonb). Un valor
--   texto ("false" / "0") NO se toca: modOn(k) = (M[k] !== false), asi que un
--   texto ya se comporta como visible y convertirlo no cambia el render. El
--   BLOQUE 1 lo cuenta aparte (filas_tipo_inesperado / texto_false) para que
--   quede evidencia, sin modificar nada.
--
-- ORDEN DE EJECUCION (una sola sesion)
--   BLOQUE 1 (antes, solo lectura) -> BLOQUE 2 (begin/update/commit) ->
--   BLOQUE 3 (despues, solo lectura). No expone datos personales: solo
--   conteos; nada de emails, telefonos ni nombres.
-- ============================================================================


-- ============================================================================
-- BLOQUE 1 -- VERIFICACION ANTES  (SOLO LECTURA)
-- Guarda la foto de referencia. Los tres numeros deben REAPARECER iguales en
-- el BLOQUE 3; claves_totales_en_modules igual => no se creo ni se borro
-- ninguna clave dentro de modules.
-- ============================================================================
SELECT
  (SELECT count(*) FROM eventos) AS eventos_total,

  (SELECT count(*)
     FROM eventos
    WHERE jsonb_typeof(config_landing->'modules') = 'object') AS filas_con_modules_objeto,

  (SELECT count(*)
     FROM (SELECT config_landing->'modules' AS m
             FROM eventos
            WHERE jsonb_typeof(config_landing->'modules') = 'object') s
     CROSS JOIN LATERAL jsonb_object_keys(s.m) AS k) AS claves_totales_en_modules,

  (SELECT count(*)
     FROM (SELECT config_landing->'modules' AS m
             FROM eventos
            WHERE jsonb_typeof(config_landing->'modules') = 'object') s
     CROSS JOIN LATERAL jsonb_each(s.m) AS kv
    WHERE jsonb_typeof(kv.value) = 'null') AS claves_con_json_null,

  (SELECT count(*)
     FROM eventos
    WHERE jsonb_typeof(config_landing->'modules') = 'object'
      AND (config_landing->'modules') ?| ARRAY['playlist','boletos','ubicacion',
            'banner_1','banner_2','historia','objetivo','impacto','equipo',
            'faq','sponsors']) AS filas_con_alguna_de_las_11;

-- Conteo de false por clave (las 11 que se cablean). En ANTES se esperan los
-- valores medidos por REST el 2026-11-10 sobre 13 eventos (ver TSK-138/139);
-- en DESPUES todas las filas deben quedar en 0 y filas_con_clave NO debe
-- cambiar (prueba de que no se crearon claves nuevas).
SELECT k.clave,
       count(*) FILTER (WHERE config_landing->'modules'->k.clave = 'false'::jsonb) AS filas_en_false,
       count(*) FILTER (WHERE config_landing->'modules' ? k.clave)                 AS filas_con_clave,
       count(*) FILTER (WHERE config_landing->'modules'->>k.clave IN ('false','0')) AS texto_false,
       count(*) FILTER (WHERE jsonb_typeof(config_landing->'modules'->k.clave)
                              NOT IN ('boolean','null'))                            AS tipo_inesperado
  FROM eventos,
       unnest(ARRAY['playlist','boletos','ubicacion','banner_1','banner_2',
                    'historia','objetivo','impacto','equipo','faq','sponsors']::text[]) AS k(clave)
 GROUP BY k.clave
 ORDER BY k.clave;

-- Control de no-colateral: las 5 claves ya cableadas deben conservar EXACTAMENTE
-- su numero de false antes y despues. Este one-off no las escribe.
SELECT k.clave,
       count(*) FILTER (WHERE config_landing->'modules'->k.clave = 'false'::jsonb) AS filas_en_false
  FROM eventos,
       unnest(ARRAY['gallery','whatsapp','guest_list','form','boletos_guestlist']::text[]) AS k(clave)
 GROUP BY k.clave
 ORDER BY k.clave;


-- ============================================================================
-- BLOQUE 2 -- UPDATE (idempotente)
--
-- La mascara del merge se construye con jsonb_object_agg sobre las claves que
-- EXISTEN con false estricto, de modo que:
--   * clave ausente  -> no entra en la mascara -> sigue ausente.
--   * clave true     -> no entra en la mascara -> sigue true, sin reescritura.
--   * clave false    -> entra 'true'::jsonb     -> pasa a true.
--   * cualquier otra clave de modules queda intacta (el || solo agrega/actualiza
--     las claves de la mascara).
--   * el resto de config_landing queda intacto (jsonb_set toca solo {modules}).
-- El cliente debe reportar la linea "UPDATE n" que imprima psql: n = filas
-- efectivamente corregidas (esperado <= 13; la suma de los false del BLOQUE 1
-- es el techo real, porque varias filas acumulan varias claves).
-- Nota: los dos ARRAY de claves deben permanecer identicos (WHERE EXISTS y
-- mascara). Son la unica fuente de verdad del alcance.
-- ============================================================================
BEGIN;

UPDATE eventos
   SET config_landing = jsonb_set(
         config_landing,
         '{modules}',
         (config_landing->'modules') || (
           SELECT COALESCE(jsonb_object_agg(k.clave, 'true'::jsonb), '{}'::jsonb)
             FROM unnest(ARRAY['playlist','boletos','ubicacion','banner_1',
                               'banner_2','historia','objetivo','impacto',
                               'equipo','faq','sponsors']::text[]) AS k(clave)
            WHERE config_landing->'modules'->k.clave = 'false'::jsonb
         ),
         false)                                    -- create_missing = false
 WHERE jsonb_typeof(config_landing->'modules') = 'object'
   AND (config_landing->'modules') IS NOT NULL
   AND jsonb_typeof(config_landing) = 'object'
   AND (config_landing->'modules') ?| ARRAY['playlist','boletos','ubicacion',
         'banner_1','banner_2','historia','objetivo','impacto','equipo',
         'faq','sponsors']
   AND EXISTS (
         SELECT 1
           FROM unnest(ARRAY['playlist','boletos','ubicacion','banner_1',
                             'banner_2','historia','objetivo','impacto',
                             'equipo','faq','sponsors']::text[]) AS k(clave)
          WHERE config_landing->'modules'->k.clave = 'false'::jsonb
       );

COMMIT;

-- Auditoria opcional de filas tocadas (slugs son publicos, no son datos
-- personales). Ejecutar SOLO si se necesita la lista; por eso va aparte y no
-- como RETURNING del UPDATE de arriba. Primero deshacer el comentario de la
-- linea UPDATE y anadir RETURNING, o usar esta consulta despues del COMMIT
-- con la lista de slugs anotada antes de ejecutar.
-- SELECT slug FROM eventos WHERE ... (misma condicion del WHERE);


-- ============================================================================
-- BLOQUE 3 -- VERIFICACION DESPUES  (SOLO LECTURA)
-- PASS si:
--   * las 11 claves del segundo SELECT quedan en filas_en_false = 0;
--   * filas_con_clave de cada clave es identica al BLOQUE 1;
--   * claves_totales_en_modules es identica al BLOQUE 1;
--   * claves_con_json_null es identica al BLOQUE 1 (no se insertaron nulos);
--   * las 5 claves ya cableadas conservan su numero de false.
-- Una segunda ejecucion del BLOQUE 2 debe imprimir "UPDATE 0".
-- ============================================================================
SELECT
  (SELECT count(*) FROM eventos) AS eventos_total,

  (SELECT count(*)
     FROM eventos
    WHERE jsonb_typeof(config_landing->'modules') = 'object') AS filas_con_modules_objeto,

  (SELECT count(*)
     FROM (SELECT config_landing->'modules' AS m
             FROM eventos
            WHERE jsonb_typeof(config_landing->'modules') = 'object') s
     CROSS JOIN LATERAL jsonb_object_keys(s.m) AS k) AS claves_totales_en_modules,

  (SELECT count(*)
     FROM (SELECT config_landing->'modules' AS m
             FROM eventos
            WHERE jsonb_typeof(config_landing->'modules') = 'object') s
     CROSS JOIN LATERAL jsonb_each(s.m) AS kv
    WHERE jsonb_typeof(kv.value) = 'null') AS claves_con_json_null,

  (SELECT count(*)
     FROM eventos
    WHERE jsonb_typeof(config_landing->'modules') = 'object'
      AND (config_landing->'modules') ?| ARRAY['playlist','boletos','ubicacion',
            'banner_1','banner_2','historia','objetivo','impacto','equipo',
            'faq','sponsors']) AS filas_con_alguna_de_las_11;

SELECT k.clave,
       count(*) FILTER (WHERE config_landing->'modules'->k.clave = 'false'::jsonb) AS filas_en_false,
       count(*) FILTER (WHERE config_landing->'modules' ? k.clave)                 AS filas_con_clave,
       count(*) FILTER (WHERE config_landing->'modules'->>k.clave IN ('false','0')) AS texto_false,
       count(*) FILTER (WHERE jsonb_typeof(config_landing->'modules'->k.clave)
                              NOT IN ('boolean','null'))                            AS tipo_inesperado
  FROM eventos,
       unnest(ARRAY['playlist','boletos','ubicacion','banner_1','banner_2',
                    'historia','objetivo','impacto','equipo','faq','sponsors']::text[]) AS k(clave)
 GROUP BY k.clave
 ORDER BY k.clave;

SELECT k.clave,
       count(*) FILTER (WHERE config_landing->'modules'->k.clave = 'false'::jsonb) AS filas_en_false
  FROM eventos,
       unnest(ARRAY['gallery','whatsapp','guest_list','form','boletos_guestlist']::text[]) AS k(clave)
 GROUP BY k.clave
 ORDER BY k.clave;

-- Fin. 0 DDL, 0 RLS, 1 tabla, 0 claves creadas, 0 claves borradas.
