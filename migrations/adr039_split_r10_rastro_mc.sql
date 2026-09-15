-- ============================================================================
-- ADR-039 · SPLIT DE CUENTA: Barrio R10 → Barrio R10 + Rastro MC
-- ============================================================================
-- Runbook SQL versionado · fecha: 2026-09-14
-- Instancia: https://ctgyvydzshueemlelkzv.supabase.co (ref: ctgyvydzshueemlelkzv)
--
-- Propósito: dividir la organización "Barrio R10" en dos. La org R10 se queda
-- como está y se crea una organización NUEVA "Rastro MC" (slug `rastro-mc`)
-- a la que se traslada el evento "RASTRO MC" y TODOS sus datos asociados
-- (inscritos, scanner_tokens, logs ligados por texto).
--
-- ⚠️ NO es un script de una sola ejecución: es un runbook guiado. Correr por
-- partes, en orden, verificando el resultado de cada paso antes de seguir.
-- ⚠️ Este archivo NO se ejecutó en producción al momento de escribirse (T3).
-- Su ejecución es la tarea T5, con token service_role o SQL Editor
-- (corre como rol postgres/service → ignora RLS).
-- ⚠️ NO usar la clave anon para escribir. Hallazgo T0: la lectura REST anon
-- funciona en todas las tablas (RLS de lectura abierta) — eso NO habilita
-- escritura anon, y no es el mecanismo de este runbook.

-- Constantes del runbook (verificadas por SELECT vía REST en la auditoría T0):
--   ORG R10          : 0b5db45b-6ee3-4e2a-aab3-4473fc7bc950  (slug 'barrio-r10', plan mensual, activa)
--   EVENTO RASTRO MC : 8203abc3-13cd-467d-a30e-734a17f2585f  (slug 'rastro-mc-ut4e', fecha 2026-03-21, serie_id null)
--   Volúmenes T0     : inscritos 39 · scanner_tokens 3 · logs por evento ILIKE '%rastro%' 32
--                      invitadores 0 · perfiles(evento) 0 · qr_links rastro 0 · qr_scans 0
--   Slugs NO se tocan: el evento conserva `rastro-mc-ut4e` (no romper QRs/landings existentes).


-- ============================================================================
-- PASO 0 · VERIFICACIÓN PREVIA (SELECT) — estado debe coincidir con T0
-- ============================================================================
-- El humano debe confirmar que cada bloque devuelve lo esperado ANTES de
-- arrancar el Paso 1. Si algún conteo difiere, DETENERSE y revisar.

-- 0.1 El slug 'rastro-mc' debe estar LIBRE (la org nueva no existe aún).
SELECT id, nombre, slug FROM organizaciones WHERE slug = 'rastro-mc';
-- Esperado: 0 filas. Si ya hay 1 fila, el runbook ya se ejecutó (o hay conflicto) → DETENERSE.

-- 0.2 La org R10 sigue viva con los valores de branding esperados.
SELECT id, nombre, slug, plan, activa, is_master_org, logo_url, color_primario, nombre_app
FROM organizaciones WHERE slug = 'barrio-r10';
-- Esperado: 1 fila — id 0b5db45b-6ee3-4e2a-aab3-4473fc7bc950, plan = valor actual de
-- R10 (mensual hoy; el moderno si adr037 ya corrió — el Paso 1 lo deriva en runtime),
-- activa true, is_master_org false.

-- 0.3 El evento RASTRO MC sigue localizado, con org_id = R10 y serie_id NULL.
SELECT id, nombre, slug, org_id, serie_id, fecha, template_id, modo_publico
FROM eventos WHERE nombre ILIKE '%rastro%' OR slug ILIKE '%rastro%';
-- Esperado: 1 fila — id 8203abc3-13cd-467d-a30e-734a17f2585f · org_id 0b5db45b-… · serie_id NULL.

-- 0.4 Volúmenes a migrar (conteos por tabla).
SELECT 'inscritos'       AS tabla, COUNT(*) FROM inscritos       WHERE evento_id = '8203abc3-13cd-467d-a30e-734a17f2585f';
-- Esperado: 39
SELECT 'scanner_tokens'  AS tabla, COUNT(*) FROM scanner_tokens  WHERE evento_id = '8203abc3-13cd-467d-a30e-734a17f2585f';
-- Esperado: 3
SELECT 'logs (criterio)' AS tabla, COUNT(*) FROM logs
WHERE org_id = '0b5db45b-6ee3-4e2a-aab3-4473fc7bc950' AND evento ILIKE '%rastro%';
-- Esperado: 32 (el único vínculo válido logs→evento es por la columna texto `evento`;
-- NA-DA por qr_code: verificado 0 coincidencias en T0 contra los 39 qr_code de inscritos).
SELECT 'invitadores'     AS tabla, COUNT(*) FROM invitadores     WHERE evento_id = '8203abc3-13cd-467d-a30e-734a17f2585f';
-- Esperado: 0
SELECT 'perfiles (evento)' AS tabla, COUNT(*) FROM perfiles      WHERE evento_id = '8203abc3-13cd-467d-a30e-734a17f2585f';
-- Esperado: 0
SELECT 'qr_links (rastro)' AS tabla, COUNT(*) FROM qr_links
WHERE url_destino ILIKE '%rastro-mc-ut4e%' OR nombre ILIKE '%rastro%';
-- Esperado: 0 (los 3 qr_links del proyecto pertenecen a la org R10 pero NO tocan el evento;
-- su org_id NO se migra).
SELECT 'qr_scans'        AS tabla, COUNT(*) FROM qr_scans;
-- Esperado: 0 en todo el proyecto — tabla sin uso.

-- 0.5 Nota documental page_events: la tabla NO EXISTE en esta instancia
-- (PGRST205 en T0). Si el SQL Editor la lista en information_schema, avisar al
-- orquestador — el runbook asume 0 filas / tabla ausente. Comando de chequeo:
-- SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_name='page_events';
-- Esperado: 0 filas (tabla ausente). Si existe → DETENERSE y avisar.

-- 0.6 Estado de landing del evento (tolerante a adr021 PENDIENTE — C4b).
-- (a) Chequear primero si la columna captura_pura existe en `eventos`: proviene
--     de adr021, cuya migración NO está presente en migrations/ de este repo al
--     2026-09-14 — puede que nunca se haya aplicado en esta instancia.
SELECT EXISTS (
  SELECT 1 FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'eventos' AND column_name = 'captura_pura'
) AS captura_pura_existe;
-- Esperado: true si adr021 ya se aplicó en la instancia; false si sigue pendiente.

-- (b1) Si captura_pura_existe = true → usar este SELECT (validación completa):
-- SELECT id, slug, template_id, modo_publico, captura_pura
-- FROM eventos WHERE id = '8203abc3-13cd-467d-a30e-734a17f2585f';
-- Esperado: template_id NULL, modo_publico NULL, captura_pura con el valor que T0 vio.

-- (b2) Si captura_pura_existe = false → usar este SELECT (adr021 NO aplica a la
--      instancia; la columna no existe y no debe consultarse):
SELECT id, slug, template_id, modo_publico
FROM eventos WHERE id = '8203abc3-13cd-467d-a30e-734a17f2585f';
-- Esperado: template_id NULL, modo_publico NULL → evento sin landing pública
-- (el movimiento a la org nueva no rompe nada externo).

-- ============================================================================
-- PASO 1 · CREAR LA ORG NUEVA "Rastro MC"
-- ============================================================================
-- Branding HEREDADO de R10 (valores reales leídos vía REST en T3):
--   logo_url      = https://r10colombia.com/assets/R10_Logo-bNcVmnoQ.png
--   color_primario= #517af5
--   nombre_app    = 'Rastro MC' (única diferencia de branding con R10)
-- ⚠️ ORDEN DE EJECUCIÓN (C3): este runbook debe ejecutarse ANTES de adr037
-- (migración de planes) en esta instancia — o el valor derivado de R10 ya sería
-- el moderno y funcionará igual. La derivación en runtime es robusta en ambos
-- escenarios: NUNCA se hardcodea el plan.
-- El plan de la org nueva se deriva de R10 en tiempo de ejecución (paridad,
-- decisión ejecutiva ADR-039) resolviendo el CHECK constraint de
-- organizaciones.plan (hoy: free|mensual|evento|combinado; tras adr037:
-- freemium|pass_evento|pro_mensual|enterprise).
-- El id se genera solo. El WHERE NOT EXISTS hace el paso re-ejecutable
-- (no rompe si alguien corre el archivo dos veces; la org solo se crea una vez).
-- El bloque DO es PostgreSQL estándar: funciona en el SQL Editor de Supabase.

DO $$
DECLARE
  plan_org     text;
  org_id_nueva uuid;
BEGIN
  -- Derivar el plan de la org R10 en runtime (single source of truth)
  SELECT plan INTO plan_org FROM organizaciones WHERE slug = 'barrio-r10';
  IF plan_org IS NULL THEN
    RAISE EXCEPTION 'Org barrio-r10 no encontrada - abortar runbook (revisar Paso 0.2)';
  END IF;

  -- Crear la org nueva SOLO si no existe aún (re-ejecutable)
  INSERT INTO organizaciones (nombre, slug, plan, activa, is_master_org, color_primario, nombre_app, logo_url)
  SELECT 'Rastro MC', 'rastro-mc', plan_org, true, false, '#517af5', 'Rastro MC',
         'https://r10colombia.com/assets/R10_Logo-bNcVmnoQ.png'
  WHERE NOT EXISTS (SELECT 1 FROM organizaciones WHERE slug = 'rastro-mc')
  RETURNING id INTO org_id_nueva;

  IF org_id_nueva IS NOT NULL THEN
    RAISE NOTICE 'Org nueva creada -> id: % | plan derivado de R10: %', org_id_nueva, plan_org;
  ELSE
    RAISE NOTICE 'Org rastro-mc YA EXISTIA - creacion omitida (re-ejecucion segura)';
  END IF;
END $$;
-- 👉 El id de la org nueva sale en el NOTICE del bloque DO (pestaña Messages/
--    Notify del SQL Editor). Los UPDATEs del Paso 2 la resuelven por slug, así
--    que no hace falta copiarlo manualmente.

-- Verificación del Paso 1: la org nueva existe con el branding correcto.
SELECT id, nombre, slug, plan, activa, is_master_org, nombre_app, color_primario
FROM organizaciones WHERE slug = 'rastro-mc';
-- Esperado: 1 fila — nombre 'Rastro MC', plan = mismo valor derivado de R10 en el
-- bloque DO anterior, activa true, is_master_org false.


-- ============================================================================
-- PASO 2 · MIGRACIÓN POR TABLA (ORG_ID SOLO — CERO BORRADOS)
-- ============================================================================
-- Patrón por tabla: (a) SELECT de confirmación de las filas exactas afectadas,
-- (b) UPDATE de org_id → org nueva, (c) SELECT de verificación.
-- NUNCA borrar filas: la migración es reasignación de org_id.

-- ── 2.1 eventos ─────────────────────────────────────────────────────────────
-- (a) Confirmación: 1 fila, org actual = barrio-r10.
SELECT e.id, e.nombre, e.slug, e.org_id, o.slug AS org_actual
FROM eventos e JOIN organizaciones o ON o.id = e.org_id
WHERE e.id = '8203abc3-13cd-467d-a30e-734a17f2585f';
-- Esperado: 1 fila, org_actual = 'barrio-r10'.

-- (b) UPDATE: reasigna la org del evento. Slug y resto de columnas INTACTOS.
UPDATE eventos
SET org_id = (SELECT id FROM organizaciones WHERE slug = 'rastro-mc')
WHERE id = '8203abc3-13cd-467d-a30e-734a17f2585f'
  AND org_id = '0b5db45b-6ee3-4e2a-aab3-4473fc7bc950';
-- Esperado: UPDATE 1. Si dice UPDATE 0, el evento ya estaba migrado (re-ejecución segura).

-- (c) Verificación: 1 fila, org_nueva = 'rastro-mc'.
SELECT e.id, e.nombre, e.slug, o.slug AS org_nueva
FROM eventos e JOIN organizaciones o ON o.id = e.org_id
WHERE e.id = '8203abc3-13cd-467d-a30e-734a17f2585f';
-- Esperado: 1 fila con org_nueva = 'rastro-mc'.

-- ── 2.2 inscritos ───────────────────────────────────────────────────────────
-- (a) Confirmación: 39 filas, todas con org_id = R10.
SELECT COUNT(*) AS total, org_id
FROM inscritos WHERE evento_id = '8203abc3-13cd-467d-a30e-734a17f2585f'
GROUP BY org_id;
-- Esperado: total 39, org_id 0b5db45b-6ee3-4e2a-aab3-4473fc7bc950.

-- (b) UPDATE: 39 filas esperadas (0 si ya migraron).
UPDATE inscritos
SET org_id = (SELECT id FROM organizaciones WHERE slug = 'rastro-mc')
WHERE evento_id = '8203abc3-13cd-467d-a30e-734a17f2585f'
  AND org_id = '0b5db45b-6ee3-4e2a-aab3-4473fc7bc950';
-- Esperado: UPDATE 39.

-- (c) Verificación: 39 filas en la org nueva.
SELECT COUNT(*) AS en_org_nueva, org_id
FROM inscritos WHERE evento_id = '8203abc3-13cd-467d-a30e-734a17f2585f'
GROUP BY org_id;
-- Esperado: 39 con org_id = id de 'rastro-mc'.

-- ── 2.3 scanner_tokens ──────────────────────────────────────────────────────
-- (a) Confirmación: 3 tokens (el runbook T0 los listó: Natalia, Maria, Maria,
--     todos usado=false, expira_en 2026-03-19/22).
SELECT id, token, nombre, usado, evento_id, org_id
FROM scanner_tokens WHERE evento_id = '8203abc3-13cd-467d-a30e-734a17f2585f'
ORDER BY nombre;
-- Esperado: 3 filas, org_id = R10.

-- (b) UPDATE: 3 filas esperadas.
UPDATE scanner_tokens
SET org_id = (SELECT id FROM organizaciones WHERE slug = 'rastro-mc')
WHERE evento_id = '8203abc3-13cd-467d-a30e-734a17f2585f'
  AND org_id = '0b5db45b-6ee3-4e2a-aab3-4473fc7bc950';
-- Esperado: UPDATE 3.

-- (c) Verificación: 3 tokens en la org nueva.
SELECT COUNT(*) AS en_org_nueva, org_id
FROM scanner_tokens WHERE evento_id = '8203abc3-13cd-467d-a30e-734a17f2585f'
GROUP BY org_id;
-- Esperado: 3.

-- ── 2.4 logs (criterio por TEXTO — el único vínculo válido) ─────────────────
-- (a) Confirmación: las 32 filas exactas que se migrarán, para validación
--     humana del criterio ILIKE. Revisar que TODAS correspondan a RASTRO MC.
SELECT l.id, l.fecha, l.hora, l.tipo, l.resultado, l.evento, l.org_id
FROM logs l
WHERE l.org_id = '0b5db45b-6ee3-4e2a-aab3-4473fc7bc950'
  AND l.evento ILIKE '%rastro%'
ORDER BY l.fecha, l.hora;
-- Esperado: 32 filas, todas con evento = 'RASTRO MC' (fechas 19–21/3/2026,
-- tipo 'invitado', resultado 'Ingreso' según muestra T0).

-- (b) UPDATE: 32 filas esperadas. Solo la columna org_id cambia; la columna
--     texto `evento` se conserva tal cual (es el nombre legado del evento).
UPDATE logs
SET org_id = (SELECT id FROM organizaciones WHERE slug = 'rastro-mc')
WHERE org_id = '0b5db45b-6ee3-4e2a-aab3-4473fc7bc950'
  AND evento ILIKE '%rastro%';
-- Esperado: UPDATE 32. Si el humano vio ≠32 en (a), NO correr — el criterio
-- ILIKE habría cambiado el universo de filas afectadas.

-- (c) Verificación: 32 filas en la org nueva, evento íntegro.
SELECT COUNT(*) AS en_org_nueva, org_id
FROM logs
WHERE org_id = (SELECT id FROM organizaciones WHERE slug = 'rastro-mc')
  AND evento ILIKE '%rastro%'
GROUP BY org_id;
-- Esperado: 32.


-- ============================================================================
-- PASO 3 · VERIFICACIÓN FINAL
-- ============================================================================

-- 3.1 Conteos cruzados por tabla: org nueva vs. org R10 (post-migración).
SELECT 'eventos'        AS tabla,
       (SELECT COUNT(*) FROM eventos        WHERE org_id = (SELECT id FROM organizaciones WHERE slug = 'rastro-mc'))  AS en_org_nueva,
       (SELECT COUNT(*) FROM eventos        WHERE org_id = '0b5db45b-6ee3-4e2a-aab3-4473fc7bc950')                    AS en_org_r10
UNION ALL SELECT 'inscritos',
       (SELECT COUNT(*) FROM inscritos      WHERE org_id = (SELECT id FROM organizaciones WHERE slug = 'rastro-mc')),
       (SELECT COUNT(*) FROM inscritos      WHERE org_id = '0b5db45b-6ee3-4e2a-aab3-4473fc7bc950')
UNION ALL SELECT 'scanner_tokens',
       (SELECT COUNT(*) FROM scanner_tokens WHERE org_id = (SELECT id FROM organizaciones WHERE slug = 'rastro-mc')),
       (SELECT COUNT(*) FROM scanner_tokens WHERE org_id = '0b5db45b-6ee3-4e2a-aab3-4473fc7bc950')
UNION ALL SELECT 'logs',
       (SELECT COUNT(*) FROM logs           WHERE org_id = (SELECT id FROM organizaciones WHERE slug = 'rastro-mc')),
       (SELECT COUNT(*) FROM logs           WHERE org_id = '0b5db45b-6ee3-4e2a-aab3-4473fc7bc950');
-- Esperado: en_org_nueva: eventos 1 · inscritos 39 · scanner_tokens 3 · logs 32.
-- en_org_r10: eventos 1 (queda NEGRO VALLE birthday bash) · inscritos 0 · scanner_tokens 0 · logs 21 (53-32).

-- 3.2 CERO filas del evento con org antigua (por tabla).
SELECT
  (SELECT COUNT(*) FROM eventos        WHERE id = '8203abc3-13cd-467d-a30e-734a17f2585f' AND org_id = '0b5db45b-6ee3-4e2a-aab3-4473fc7bc950') AS eventos_residuales,
  (SELECT COUNT(*) FROM inscritos      WHERE evento_id = '8203abc3-13cd-467d-a30e-734a17f2585f' AND org_id = '0b5db45b-6ee3-4e2a-aab3-4473fc7bc950') AS inscritos_residuales,
  (SELECT COUNT(*) FROM scanner_tokens WHERE evento_id = '8203abc3-13cd-467d-a30e-734a17f2585f' AND org_id = '0b5db45b-6ee3-4e2a-aab3-4473fc7bc950') AS tokens_residuales;
-- Esperado: 0 | 0 | 0.

-- 3.3 Unicidad global del slug de la org nueva (y del resto).
SELECT slug, COUNT(*) AS veces
FROM organizaciones
WHERE slug IN ('rastro-mc', 'barrio-r10')
GROUP BY slug;
-- Esperado: 'rastro-mc' → 1 · 'barrio-r10' → 1.

-- 3.4 Listado final de las dos orgs para el registro del ADR-039.
SELECT id, nombre, slug, plan, activa, is_master_org, nombre_app
FROM organizaciones WHERE slug IN ('barrio-r10', 'rastro-mc')
ORDER BY slug;

-- 3.5 Cápsula limpia (C4a): CERO filas orbitantes en las tablas que NO deben
-- migrar. La org nueva debe contener SOLO el evento RASTRO MC y sus datos
-- (1 evento / 39 inscritos / 3 tokens / 32 logs del bloque 3.1); cualquier fila
-- aquí es un dato orbitando la org nueva → DETENERSE y avisar al orquestador.
SELECT 'clientes'        AS tabla,
       (SELECT COUNT(*) FROM clientes        WHERE org_id = (SELECT id FROM organizaciones WHERE slug = 'rastro-mc')) AS en_org_nueva
UNION ALL SELECT 'perfiles',
       (SELECT COUNT(*) FROM perfiles        WHERE org_id = (SELECT id FROM organizaciones WHERE slug = 'rastro-mc'))
UNION ALL SELECT 'invitadores',
       (SELECT COUNT(*) FROM invitadores     WHERE org_id = (SELECT id FROM organizaciones WHERE slug = 'rastro-mc'))
UNION ALL SELECT 'qr_links',
       (SELECT COUNT(*) FROM qr_links        WHERE org_id = (SELECT id FROM organizaciones WHERE slug = 'rastro-mc'))
UNION ALL SELECT 'qr_scans',
       (SELECT COUNT(*) FROM qr_scans
        WHERE qr_link_id IN (SELECT id FROM qr_links
                             WHERE org_id = (SELECT id FROM organizaciones WHERE slug = 'rastro-mc')))
UNION ALL SELECT 'series',
       (SELECT COUNT(*) FROM series          WHERE org_id = (SELECT id FROM organizaciones WHERE slug = 'rastro-mc'));
-- Esperado: 0 en TODAS.
-- Nota de columnas (auditoría REST 2026-09-14, confirmada en producción):
--   clientes.org_id, perfiles.org_id, invitadores.org_id, qr_links.org_id y
--   series.org_id → EXISTEN (series tiene 1 fila 'salsa legion' en barrio-r10 y
--   0 en rastro-mc; series NO tiene evento_id, pero el runbook no lo usa).
--   qr_scans NO tiene org_id (error 42703 verificado en producción): se cuenta
--   por su FK qr_link_id → qr_links (tabla madre que SÍ tiene org_id). El
--   esperado sigue siendo 0: ningún qr_link del proyecto apunta al evento.
-- El único cliente de R10 (javier gonzalez) y los 3 qr_links del proyecto se
-- quedan en barrio-r10: no tocan el evento.


-- ============================================================================
-- ROLLBACK EXPLÍCITO · revertir la migración (org nueva → org R10)
-- ============================================================================
-- ⚠️ Ejecutar SOLO si se detecta un problema post-migración.
-- ⚠️ Debe ejecutarse ANTES de que la org nueva reciba datos nuevos (inscritos
--    nuevos, logs nuevos, etc.). Si la org nueva ya recibió datos, decidir con
--    el orquestador qué filas nuevas quedan en rastro-mc y cuáles se revierten
--    (no revertir a ciegas: se perdería el vínculo org_id de filas nuevas).

-- ── ROLLBACK 2.1 · eventos ──
-- (a) Confirmación: la fila a revertir.
SELECT e.id, e.nombre, o.slug AS org_actual
FROM eventos e JOIN organizaciones o ON o.id = e.org_id
WHERE e.id = '8203abc3-13cd-467d-a30e-734a17f2585f';
-- (b) UPDATE inverso: evento → org R10.
UPDATE eventos
SET org_id = '0b5db45b-6ee3-4e2a-aab3-4473fc7bc950'
WHERE id = '8203abc3-13cd-467d-a30e-734a17f2585f'
  AND org_id = (SELECT id FROM organizaciones WHERE slug = 'rastro-mc');
-- (c) Verificación: org_actual = 'barrio-r10'.

-- ── ROLLBACK 2.2 · inscritos ──
-- (a) Confirmación: las 39 filas en la org nueva.
SELECT COUNT(*) AS total, org_id
FROM inscritos WHERE evento_id = '8203abc3-13cd-467d-a30e-734a17f2585f'
GROUP BY org_id;
-- (b) UPDATE inverso.
UPDATE inscritos
SET org_id = '0b5db45b-6ee3-4e2a-aab3-4473fc7bc950'
WHERE evento_id = '8203abc3-13cd-467d-a30e-734a17f2585f'
  AND org_id = (SELECT id FROM organizaciones WHERE slug = 'rastro-mc');
-- Esperado: UPDATE 39.
-- (c) Verificación: 39 con org_id = R10.

-- ── ROLLBACK 2.3 · scanner_tokens ──
-- (a) Confirmación: 3 tokens en la org nueva.
SELECT COUNT(*) AS total, org_id
FROM scanner_tokens WHERE evento_id = '8203abc3-13cd-467d-a30e-734a17f2585f'
GROUP BY org_id;
-- (b) UPDATE inverso.
UPDATE scanner_tokens
SET org_id = '0b5db45b-6ee3-4e2a-aab3-4473fc7bc950'
WHERE evento_id = '8203abc3-13cd-467d-a30e-734a17f2585f'
  AND org_id = (SELECT id FROM organizaciones WHERE slug = 'rastro-mc');
-- Esperado: UPDATE 3.
-- (c) Verificación: 3 con org_id = R10.

-- ── ROLLBACK 2.4 · logs ──
-- (a) Confirmación: las 32 filas en la org nueva.
SELECT COUNT(*) AS total, org_id
FROM logs
WHERE org_id = (SELECT id FROM organizaciones WHERE slug = 'rastro-mc')
  AND evento ILIKE '%rastro%'
GROUP BY org_id;
-- (b) UPDATE inverso.
UPDATE logs
SET org_id = '0b5db45b-6ee3-4e2a-aab3-4473fc7bc950'
WHERE org_id = (SELECT id FROM organizaciones WHERE slug = 'rastro-mc')
  AND evento ILIKE '%rastro%';
-- Esperado: UPDATE 32.
-- (c) Verificación: 32 con org_id = R10.

-- ── ROLLBACK FINAL · la org nueva ─────────────────────────────────────────--
-- ⚠️ NO borrar la organización con DELETE por SQL: Supabase puede tener FKs
--    adicionales y la UI es más segura. Tras revertir TODOS los datos, la org
--    'rastro-mc' queda vacía → borrarla manualmente desde el Supabase Dashboard
--    (Table Editor → organizaciones → eliminar fila) SOLO si el orquestador lo
--    confirma. Antes de borrarla, verificar que quedó vacía:
-- SELECT
--   (SELECT COUNT(*) FROM eventos        WHERE org_id = (SELECT id FROM organizaciones WHERE slug='rastro-mc')) AS eventos,
--   (SELECT COUNT(*) FROM inscritos      WHERE org_id = (SELECT id FROM organizaciones WHERE slug='rastro-mc')) AS inscritos,
--   (SELECT COUNT(*) FROM scanner_tokens WHERE org_id = (SELECT id FROM organizaciones WHERE slug='rastro-mc')) AS tokens,
--   (SELECT COUNT(*) FROM logs           WHERE org_id = (SELECT id FROM organizaciones WHERE slug='rastro-mc')) AS logs;
-- Esperado: 0 | 0 | 0 | 0 → recién entonces eliminar la fila en Dashboard.

-- Si en cambio la migración fue correcta: la org 'rastro-mc' queda activa y vacía
-- de eventos propios salvo RASTRO MC (creación de eventos futuros es decisión del
-- orquestador en T5+).


-- ============================================================================
-- NOTAS DE SEGURIDAD (ADR-039 · confirmado en auditoría T0)
-- ============================================================================
-- 1. ⚠️ NO usar la clave anon para escritura. El runbook se ejecuta con token
--    service_role (Settings → API → service_role) o desde el SQL Editor.
-- 2. ⚠️ Hallazgo T0: la lectura REST con clave anon está ABIERTA en todas las
--    tablas (RLS de lectura permisiva). Esto es aceptable para páginas públicas
--    pero NO debe extenderse a escritura; revisar políticas de escritura antes
--    de cualquier automatización. Escalar a @sql-security si se tocan políticas.
-- 3. ✅ El evento conserva su slug `rastro-mc-ut4e`: no se tocan slugs ni
--    url_destino. Los QRs ya emitidos (qr_code de inscritos) siguen válidos.
-- 4. ✅ CERO borrados en todo el runbook: solo INSERT (org nueva) y UPDATE de
--    org_id. La integridad multi-tenant se preserva por reasignación.
-- 5. ⚠️ `page_events` es una tabla AUSENTE en esta instancia (PGRST205 en T0);
--    el split no la contempla. Si un chequeo por SQL Editor la encuentra, avisar
--    al orquestador antes de continuar (podría ser otra instancia — ver f7.html).
-- 6. ⚠️ `clientes` y `qr_links`/`qr_scans` NO se migran: los 39 inscritos del
--    evento no tienen cliente_id, y los 3 qr_links del proyecto no referencian
--    el evento. Verificado en T0.
-- 7. ⚠️ ORDEN DE EJECUCIÓN vs adr037 (C3): este runbook debe ejecutarse ANTES de
--    la migración de planes adr037 en esta instancia. Si adr037 ya corrió, el
--    bloque DO del Paso 1 deriva igual el plan moderno de R10 y el INSERT funciona;
--    si no corrió, deriva el plan legacy ('mensual'). Ambas rutas son válidas por
--    diseño — la derivación en runtime evita hardcodear un valor que el CHECK
--    constraint rechazaría.
-- ============================================================================


-- ============================================================================
-- ANEXO T4 · CREACIÓN DEL PERFIL SUPERADMIN DE "RASTRO MC" (opción A)
-- ============================================================================
-- Decisión de Dirección 2026-09-14: opción A = crear el usuario por Supabase
-- Dashboard y luego INSERT del perfil — patrón ADR-025 pasos 6/7.
--
-- ⚠️ ORDEN DE EJECUCIÓN: este anexo se corre DESPUÉS de completar los Pasos
-- 0 → 3 del runbook (la org 'rastro-mc' ya debe existir) y DESPUÉS de crear el
-- usuario en el Supabase Dashboard (paso T4.1). Es independiente del ROLLBACK:
-- si se revierte la migración de datos, este perfil debe evaluarse aparte con
-- el orquestador (¿se mueve a barrio-r10 o se elimina del Dashboard?).
-- Este anexo NO hace DELETE en ningún momento.

-- ── T4.1 Requisito previo (Supabase Dashboard — manual, por el dueño) ──────
-- Authentication → Users → Add user → crear el login del administrador de la
-- org nueva:
--   Email      : el que el dueño elija (reemplaza el placeholder más abajo)
--   Contraseña : la que el dueño elija (NO viaja en este runbook)
-- Alternativa: usar "Invite user" para que el propio usuario defina su
-- contraseña al aceptar la invitación.
-- 👉 El correo elegido se usa como constante en T4.3: '<EMAIL_SUPERADMIN_RASTRO_MC>'
-- (el dueño reemplaza el placeholder ANTES de ejecutar).

-- ── T4.2 Verificación previa (SELECT) ───────────────────────────────────────
-- (a) El usuario debe existir en auth.users (creado en T4.1).
SELECT id, email, created_at FROM auth.users WHERE email = '<EMAIL_SUPERADMIN_RASTRO_MC>';
-- Esperado: 1 fila. Si devuelve 0, el usuario NO se creó en el Dashboard →
-- NO continuar: el INSERT de T4.3 insertaría 0 filas (el SELECT cruza por email).

-- (b) El email no debe tener ya un perfil en la org 'rastro-mc'.
SELECT p.id, p.nombre, p.rol, p.org_id
FROM perfiles p
WHERE p.id = (SELECT id FROM auth.users WHERE email = '<EMAIL_SUPERADMIN_RASTRO_MC>')
  AND p.org_id = (SELECT id FROM organizaciones WHERE slug = 'rastro-mc');
-- Esperado: 0 filas. Si ya hay 1 fila, el perfil ya existe (re-ejecución del
-- anexo): verificar que rol='superadmin' y activo=true antes de continuar.

-- (c) Contexto: la org 'rastro-mc' debe existir (resultado del Paso 1) y no
-- debe tener todavía ningún perfil (cápsula limpia, ver Paso 3.5).
SELECT id, nombre, slug FROM organizaciones WHERE slug = 'rastro-mc';
SELECT id, nombre, rol, org_id FROM perfiles
WHERE org_id = (SELECT id FROM organizaciones WHERE slug = 'rastro-mc');
-- Esperado: 1 org + 0 perfiles (este anexo crea el primero).

-- ── T4.3 INSERT del perfil (idempotente, cero borrados) ─────────────────────
-- Cruza el id de auth.users por el email, asocia la org por slug y usa
-- ON CONFLICT (id) DO NOTHING: si el perfil ya existe, el INSERT no hace nada
-- (re-ejecución segura). Si el email no existe en auth.users, el SELECT devuelve
-- vacío → se insertan 0 filas (el aviso del T4.2a evita llegar aquí con dudas).
INSERT INTO perfiles (id, nombre, rol, org_id, activo)
SELECT au.id, 'Rastro MC', 'superadmin', o.id, true
FROM auth.users au
JOIN organizaciones o ON o.slug = 'rastro-mc'
WHERE au.email = '<EMAIL_SUPERADMIN_RASTRO_MC>'
ON CONFLICT (id) DO NOTHING;
-- Esperado: INSERT 0 1 (1 fila creada). INSERT 0 0 significa perfil ya existía
-- (DO NOTHING) o email inexistente — re-verificar T4.2a.

-- ── T4.4 Verificación posterior (SELECT): perfil creado + su org ───────────
SELECT p.id, p.nombre, p.rol, p.org_id, p.activo, o.slug AS org_slug, o.nombre AS org_nombre
FROM perfiles p
JOIN organizaciones o ON o.id = p.org_id
WHERE o.slug = 'rastro-mc';
-- Esperado: 1 fila — p.nombre 'Rastro MC', rol 'superadmin', activo true,
-- org_slug 'rastro-mc'. El dueño confirma que es el login deseado.

-- ── Notas documentales del anexo ────────────────────────────────────────────
-- (a) Este perfil es el ÚNICO de la org 'rastro-mc' (creado por este runbook;
--      la org nueva nace sin perfiles — verificado en T4.2c).
-- (b) Al hacer login, el usuario verá SOLO su org: el aislamiento multi-tenant
--      se da por org_id vía las políticas RLS *_org (patrón ADR-025). No verá
--      eventos, inscritos ni logs de barrio-r10.
-- (c) La contraseña NO viaja en el runbook: queda definida en el Dashboard
--      (Add user) o por Invite user; este anexo solo crea el perfil de app.
-- (d) Si el dueño prefiere un rol distinto a 'superadmin', cambiar el valor en
--      el INSERT de T4.3 (valores admitidos por la app: superadmin | admin_evento | portero).
-- ============================================================================