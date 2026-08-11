-- ============================================================================
-- ADR-025 · Separación de Identidad: Barrio R10 (cliente regular) vs.
--           SaaS Master Admin (cáscara de supervisión, sin eventos propios)
-- ============================================================================
-- NO es un script de una sola ejecución. Es un runbook guiado: correr por
-- partes, en orden, verificando el resultado de cada paso antes de seguir.
-- Los pasos 6 y 7 requieren el Supabase Dashboard (crear un usuario de Auth
-- no se puede hacer por SQL puro contra auth.users de forma soportada).
--
-- Precondición: ejecutar TODO esto desde el SQL Editor de Supabase (corre
-- como rol postgres/service, por lo tanto ignora RLS — no hace falta estar
-- logueado como ningún usuario de la app para estos pasos).
--
-- ⚠️ Desplegar el admin.html actualizado (ADR-025) y correr este script deben
-- ir JUNTOS. El código ya asume que existe `is_master_org`; si se despliega
-- el HTML sin correr al menos el PASO 1 primero, cualquier organización con
-- is_master_org=false (todas, por default) pierde acceso al Panel de Sistema
-- hasta que termines el runbook completo.
-- ============================================================================


-- ── PASO 1: columna nueva ──────────────────────────────────────────────────
ALTER TABLE organizaciones
  ADD COLUMN IF NOT EXISTS is_master_org boolean NOT NULL DEFAULT false;


-- ── PASO 1b (diagnóstico, opcional pero recomendado): ver TODOS los CHECK
-- constraints de organizaciones antes de insertar, para no repetir el error
-- del 'plan' con alguna otra columna que no cubrí en este script.
SELECT conname, pg_get_constraintdef(oid) AS definicion
FROM pg_constraint
WHERE conrelid = 'organizaciones'::regclass AND contype = 'c';


-- ── PASO 2: crear la organización maestra ──────────────────────────────────
-- Columnas basadas en el INSERT real que ya usa admin.html (línea ~3130:
-- SB.from('organizaciones').insert({nombre,slug,plan,activa,color_primario,nombre_app})).
-- 'plan' tiene un CHECK constraint — los valores válidos son los que usa la
-- propia app (admin.html:2859/2963, objeto planLabel): free | mensual | evento
-- | combinado. La org maestra no factura, así que usamos 'free'.
INSERT INTO organizaciones (nombre, slug, plan, activa, is_master_org, color_primario, nombre_app)
VALUES ('SaaS Master Admin', 'master-admin', 'free', true, true, '#C8A96E', 'SaaS Master Admin')
RETURNING id, nombre, slug, is_master_org;
-- 👉 copia el "id" devuelto. Lo vas a necesitar como {{MASTER_ORG_ID}} en el PASO 4.


-- ── PASO 3: identificar tu login actual (el que hoy opera hostal-terraza) ──
SELECT p.id AS user_id, p.nombre, p.rol, p.org_id, o.slug AS org_slug
FROM perfiles p
JOIN organizaciones o ON o.id = p.org_id
WHERE o.slug = 'hostal-terraza' AND p.rol = 'superadmin';
-- 👉 identifica tu fila (por nombre) y copia su "user_id" como {{JAVIER_USER_ID}}.
-- Si aparece más de una fila, identifica cuál es tu login real antes de seguir.


-- ── PASO 4: mover tu login actual a la org maestra ─────────────────────────
-- Reemplaza los dos placeholders antes de correr.
UPDATE perfiles
SET org_id = '{{MASTER_ORG_ID}}'
WHERE id = '{{JAVIER_USER_ID}}';


-- ── PASO 5: Barrio R10 deja de ser master y se renombra ────────────────────
-- Cero migración de datos: eventos/inscritos/clientes de Barrio R10 siguen
-- apuntando al mismo org_id de siempre — solo cambia el slug y el flag.
UPDATE organizaciones
SET is_master_org = false,
    slug = 'barrio-r10'
WHERE slug = 'hostal-terraza';


-- ── PASO 6 (Supabase Dashboard, NO por SQL): ────────────────────────────────
-- Authentication → Users → Add user → crea el login operativo NUEVO para
-- quien administre Barrio R10 día a día (email + contraseña reales de esa
-- persona, no un email temporal). Copia el UUID del usuario creado.
-- 👉 ese UUID es {{BARRIO_R10_NEW_USER_ID}} para el PASO 7.


-- ── PASO 7: dar de alta ese usuario como superadmin de Barrio R10 ──────────
INSERT INTO perfiles (id, nombre, rol, org_id, activo)
VALUES (
  '{{BARRIO_R10_NEW_USER_ID}}',
  'Barrio R10 — Admin',                                   -- ajusta el nombre real
  'superadmin',
  (SELECT id FROM organizaciones WHERE slug = 'barrio-r10'),
  true
);


-- ── PASO 8: reescribir las 2 políticas que dependían del slug hardcodeado ──
-- update_organizaciones NO se toca: ya usa "id = org_id propio", nunca dependió
-- del slug (confirmado en la auditoría de ADR-025).

DROP POLICY IF EXISTS "insert_organizaciones" ON organizaciones;
CREATE POLICY "insert_organizaciones" ON organizaciones
FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM perfiles p
    JOIN organizaciones o ON o.id = p.org_id
    WHERE p.id = auth.uid() AND p.rol = 'superadmin' AND o.is_master_org = true
  )
);

DROP POLICY IF EXISTS "delete_organizaciones" ON organizaciones;
CREATE POLICY "delete_organizaciones" ON organizaciones
FOR DELETE
USING (
  EXISTS (
    SELECT 1 FROM perfiles p
    JOIN organizaciones o ON o.id = p.org_id
    WHERE p.id = auth.uid() AND p.rol = 'superadmin' AND o.is_master_org = true
  )
);


-- ── PASO 9: verificación ────────────────────────────────────────────────────
SELECT o.nombre, o.slug, o.is_master_org, p.nombre AS usuario, p.rol
FROM organizaciones o
LEFT JOIN perfiles p ON p.org_id = o.id
WHERE o.slug IN ('master-admin', 'barrio-r10')
ORDER BY o.slug, p.nombre;
-- Esperado: 'barrio-r10' con is_master_org=false y el usuario nuevo del PASO 7;
-- 'master-admin' con is_master_org=true y tu usuario (movido en el PASO 4).


-- ============================================================================
-- NO INCLUIDO EN ESTE SCRIPT (ver DECISIONS.md ADR-025, TSK-026):
-- Las políticas legacy permisivas en eventos ("Admins escriben eventos"),
-- clientes ("Clientes acceso total autenticado") y perfiles (is_superadmin()
-- sin acotar por organización, org_perfiles_update sin WITH CHECK) siguen
-- activas y conviven con las políticas *_org correctas. No se tocan aquí
-- porque requieren su propio Context Package — retirarlas sin verificar cada
-- flujo público (registro, scanner, página de evento) puede romper algo que
-- hoy depende de ellas.
-- ============================================================================
