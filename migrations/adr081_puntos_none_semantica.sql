-- ============================================================================
-- ADR-081 | Semantica de puntos de escaneo: normalizar '[]' a NULL
-- ----------------------------------------------------------------------------
-- Archivo   : migrations/adr081_puntos_none_semantica.sql
-- Fecha     : 2026-10-07
-- Proposito : alinear los DATOS con la semantica NUEVA de
--             public.inscritos.puntos_acceso (jsonb) para que el scanner
--             (que ya aplica esa semantica) no bloquee entradas historicas.
--
-- MOTIVO (cambio de semantica de puntos de escaneo):
--   * Semantica VIEJA (ADR-079): NULL y '[]' significaban lo MISMO -> el ticket
--     HEREDA los puntos del evento (public.eventos.puntos_acceso).
--   * Semantica NUEVA: NULL = hereda; '[]' = NINGUN punto explicito (el ticket
--     no puede pasar por ningun punto). scanner.html ya la implementa:
--       const hasOwn  = Array.isArray(data.puntos_acceso);
--       const allowed = hasOwn ? data.puntos_acceso
--                              : (Array.isArray(base) ? base : []);
--     (si hasOwn es true usa el array TAL CUAL, incluido '[]').
--   * Consecuencia: toda fila historica con '[]' (que HOY debe heredar) pasaria a
--     bloquear el acceso en todos los puntos. Esta migracion la normaliza a NULL.
--
-- POR QUE ES SEGURA E IDEMPOTENTE:
--   * Bajo la semantica vieja NULL y '[]' eran equivalentes (ambos = heredar):
--     convertir '[]' -> NULL NO cambia el comportamiento efectivo; solo fija el
--     significado a "hereda" de forma explicita para la semantica nueva.
--   * UPDATE acotado a puntos_acceso = '[]'::jsonb: re-ejecutar no cambia nada
--     (la segunda pasada afecta 0 filas).
--   * NO toca RLS, NO crea tablas, NO cambia columnas, NO borra filas.
--
-- ADITIVA / CERO BORRADO (Oro #2):
--   * '[]' y NULL representaban el mismo estado; no se pierde informacion.
--   * No se sobrescribe ningun array CON contenido (solo el vacio canonico).
--
-- NOTA DE NUMERACION (ADR-006, prevalece el archivo): el brief original pedia
-- 'adr080', pero ADR-080 YA esta asignado a la paleta de color de evento
-- (decisiones/ADR-080-paleta-de-color-de-evento-config-landing-colors.md,
-- 2026-10-07). El siguiente numero libre es ADR-081; este archivo usa ese ID
-- y el ADR lo debe redactar @architect como ADR-081.
--
-- Caracteristicas: 100% ASCII (cero bytes > 127), cero tildes, cero emojis,
-- cero backticks, terminacion de linea LF. Solo SELECT informativos y un UPDATE.
-- No crea tablas, no toca RLS, no toca columnas.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- BLOQUE 0: CONTEO PREVIO (informativo)
-- Filas que HOY estan en '[]' y que la semantica nueva interpretaria como
-- "ningun punto explicito". Deben quedar en 0 tras el UPDATE del Bloque 1.
-- ----------------------------------------------------------------------------

SELECT count(*) AS filas_con_array_vacio_antes
FROM public.inscritos
WHERE puntos_acceso = '[]'::jsonb;


-- ----------------------------------------------------------------------------
-- BLOQUE 1: NORMALIZACION '[]' -> NULL
-- Solo el array vacio canonico. NULL permanece NULL. Un array con items se
-- conserva intacto (es un override real y la semantica nueva lo respeta igual).
-- ----------------------------------------------------------------------------

UPDATE public.inscritos
   SET puntos_acceso = NULL
 WHERE puntos_acceso = '[]'::jsonb;


-- ----------------------------------------------------------------------------
-- BLOQUE 2: CONTEO POSTERIOR (informativo)
-- Debe devolver 0. Confirma la normalizacion completa.
-- ----------------------------------------------------------------------------

SELECT count(*) AS filas_con_array_vacio_despues
FROM public.inscritos
WHERE puntos_acceso = '[]'::jsonb;


-- ----------------------------------------------------------------------------
-- BLOQUE 3: RECARGA DEL SCHEMA CACHE DE POSTGREST
-- Mismo patron que adr079 (y adr051/adr073). Aunque no cambia el esquema, se
-- recarga para que ningun lector quede con metadatos obsoletos.
-- ----------------------------------------------------------------------------

NOTIFY pgrst, 'reload schema';


-- ============================================================================
-- BLOQUE DE VERIFICACION (comentado; ejecutar DESPUES del UPDATE)
--
-- (1) Ya no debe existir ninguna fila con '[]':
-- SELECT count(*) FROM public.inscritos WHERE puntos_acceso = '[]'::jsonb;
--     -> esperado: 0
--
-- (2) Distribucion de estados tras la normalizacion:
-- SELECT
--   count(*) FILTER (WHERE puntos_acceso IS NULL)                       AS hereda_null,
--   count(*) FILTER (WHERE puntos_acceso = '[]'::jsonb)                AS ninguno_vacio,
--   count(*) FILTER (WHERE puntos_acceso IS NOT NULL
--                      AND puntos_acceso <> '[]'::jsonb)               AS override_con_items
-- FROM public.inscritos;
--     -> ninguno_vacio debe ser 0
-- ============================================================================
-- ROLLBACK (documentado, comentado; NO se ejecuta):
-- La conversion NO es reversible de forma fiel: no se puede distinguir un NULL
-- que fue '[]' de uno que siempre fue NULL. Pero tampoco es necesaria: bajo la
-- semantica vieja NULL y '[]' eran equivalentes, asi que revertir el dato no
-- aporta valor operativo. Se descarta a proposito (no determinista).
-- ============================================================================
