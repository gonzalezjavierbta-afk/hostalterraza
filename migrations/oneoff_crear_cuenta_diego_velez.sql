-- ============================================================================
-- ONEOFF - Crear cuenta completa: Diego Velez (superadmin, org propia)
-- Sistema QR Hostal Terraza / ExploraCO
-- ----------------------------------------------------------------------------
-- NO es una migracion de esquema. Es una operacion puntual de datos + Auth
-- para crear UNA cuenta:
--   1) usuario en auth.users
--   2) identidad de login por email en auth.identities
--   3) su organizacion en public.organizaciones
--   4) su perfil en public.perfiles
--
-- Cuenta objetivo:
--   Nombre    : Diego Velez
--   Email     : diego.velez.abogado@gmail.com  (lower aplicado en runtime)
--   Password  : 1234567890  (DEBIL - cambiar tras el primer login)
--   Plan      : pro_mensual (eventos e inscritos ilimitados, ADR-037/038)
--   Rol       : superadmin (dueno de su org; NO es la org maestra)
--   Org       : slug 'diego-velez', is_master_org = false
--
-- Idempotente y re-ejecutable: si la cuenta/org/perfil ya existen, no falla
-- ni duplica. Cada bloque numerado es autonomo y puede correrse por separado
-- (ver FALLBACK en el BLOQUE 7). Ejecutar completo en el SQL Editor de
-- Supabase (corre como postgres/service_role -> ignora RLS).
--
-- ASCII-SAFETY (ADR-002 / BUG-026): este archivo NO contiene bytes > 127.
-- ============================================================================


-- ============================================================================
-- BLOQUE 0 - VERIFICACION PREVIA (ejecutar y LEER el resultado)
-- ----------------------------------------------------------------------------
-- El operador debe confirmar las columnas reales ANTES de insertar. Este
-- bloque no escribe nada.
-- ============================================================================

-- 0.1 Columnas reales de auth.users en ESTA instancia/version.
--     Confirmar: existencia de instance_id y confirmed_at; si confirmed_at
--     sale con is_generated <> 'NEVER', es columna generada y NO debe escribirse.
SELECT column_name, data_type, is_nullable, column_default, is_generated
FROM information_schema.columns
WHERE table_schema = 'auth' AND table_name = 'users'
ORDER BY ordinal_position;

-- 0.2 Columnas reales de auth.identities.
--     Clave: si aparece provider_id -> esquema NUEVO (Supabase actual).
--     Si NO aparece provider_id -> esquema LEGACY (id text = id del proveedor).
SELECT column_name, data_type, is_nullable, column_default, is_generated
FROM information_schema.columns
WHERE table_schema = 'auth' AND table_name = 'identities'
ORDER BY ordinal_position;

-- 0.3 Esquema donde vive pgcrypto (crypt / gen_salt) en esta instancia.
--     Deberia ser 'extensions'. Si sale 0 filas, pgcrypto NO esta instalado:
--     ejecutar  create extension if not exists pgcrypto with schema extensions;
SELECT n.nspname AS schema_pgcrypto
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.proname = 'crypt'
ORDER BY (n.nspname = 'extensions') DESC, (n.nspname = 'public') DESC
LIMIT 1;

-- 0.4 Columnas de public.organizaciones y public.perfiles usadas por la app.
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'organizaciones'
  AND column_name IN ('id','nombre','slug','plan','activa','is_master_org',
                      'color_primario','nombre_app','logo_url')
ORDER BY column_name;

SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'perfiles'
  AND column_name IN ('id','nombre','rol','org_id','evento_id','activo')
ORDER BY column_name;

-- 0.5 Estado actual de la cuenta objetivo (1a ejecucion: 0 filas).
SELECT id, email, email_confirmed_at, created_at
FROM auth.users
WHERE lower(email) = lower('Diego.velez.abogado@gmail.com');

SELECT id, nombre, slug, plan, activa, is_master_org
FROM public.organizaciones WHERE slug = 'diego-velez';

-- 0.6 Constraints CHECK vigentes sobre organizaciones.plan.
--     Si aparece "organizaciones_plan_check" con free/mensual/evento/combinado,
--     el BLOQUE 1 lo retira y garantiza el CHECK nuevo (pro_mensual).
SELECT c.conname, pg_get_constraintdef(c.oid) AS definicion
FROM pg_constraint c
JOIN pg_class t ON t.oid = c.conrelid
JOIN pg_namespace n ON n.oid = t.relnamespace
JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = ANY (c.conkey)
WHERE n.nspname = 'public' AND t.relname = 'organizaciones'
  AND c.contype = 'c' AND a.attname = 'plan';


-- ============================================================================
-- BLOQUE 1 - PREAMBULO: que organizaciones.plan admita 'pro_mensual'
-- ----------------------------------------------------------------------------
-- Contexto verificado: la instancia puede conservar el CHECK legacy
-- "organizaciones_plan_check" (free|mensual|evento|combinado) que RECHAZA
-- 'pro_mensual'. ADR-037 define el CHECK nuevo
-- "organizaciones_plan_modelo_comercial_check" con
-- (freemium|pass_evento|pro_mensual|enterprise).
--
-- Idempotente:
--   1. Retira CUALQUIER CHECK sobre public.organizaciones.plan cuyo nombre NO
--      sea el canonico (cubre el legacy y variantes por instancia).
--   2. Crea el CHECK canonico si no existe (NOT VALID: no re-valida filas
--      viejas, pero SI aplica a INSERT/UPDATE nuevos, que es lo que importa).
--      NO se ejecuta VALIDATE aqui: la migracion global de valores legacy es
--      responsabilidad de adr037_planes_modelo_comercial.sql.
-- ============================================================================

DO $$
DECLARE
  v_conname text;
BEGIN
  FOR v_conname IN
    SELECT c.conname
    FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    JOIN pg_namespace n ON n.oid = t.relnamespace
    JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = ANY (c.conkey)
    WHERE n.nspname = 'public'
      AND t.relname = 'organizaciones'
      AND c.contype = 'c'
      AND a.attname = 'plan'
      AND c.conname <> 'organizaciones_plan_modelo_comercial_check'
  LOOP
    EXECUTE format('ALTER TABLE public.organizaciones DROP CONSTRAINT %I', v_conname);
    RAISE NOTICE '[BLOQUE 1] CHECK legacy "%" eliminado.', v_conname;
  END LOOP;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    JOIN pg_namespace n ON n.oid = t.relnamespace
    WHERE n.nspname = 'public' AND t.relname = 'organizaciones'
      AND c.conname = 'organizaciones_plan_modelo_comercial_check'
  ) THEN
    ALTER TABLE public.organizaciones
      ADD CONSTRAINT organizaciones_plan_modelo_comercial_check
      CHECK (plan IN ('freemium','pass_evento','pro_mensual','enterprise'))
      NOT VALID;
    RAISE NOTICE '[BLOQUE 1] CHECK "organizaciones_plan_modelo_comercial_check" creado (NOT VALID).';
  ELSE
    RAISE NOTICE '[BLOQUE 1] CHECK canonico ya existe, skip.';
  END IF;
END $$;


-- ============================================================================
-- BLOQUE 2 - ORGANIZACION de Diego Velez (idempotente por slug)
-- ----------------------------------------------------------------------------
-- Reutiliza la org si ya existe y fuerza el estado deseado (pro_mensual +
-- activa). Si prefiere OTRA org ya existente: cambie v_slug/v_nombre abajo,
-- o comente este bloque y ajuste el slug del BLOQUE 5 al de su org.
-- ============================================================================

DO $$
DECLARE
  v_slug   text := 'diego-velez';
  v_nombre text := 'Diego Velez';
  v_color  text := '#C8A96E';
  v_org_id uuid;
BEGIN
  SELECT id INTO v_org_id FROM public.organizaciones WHERE slug = v_slug;

  IF v_org_id IS NULL THEN
    INSERT INTO public.organizaciones
      (nombre, slug, plan, activa, is_master_org, color_primario, nombre_app)
    VALUES
      (v_nombre, v_slug, 'pro_mensual', true, false, v_color, v_nombre)
    RETURNING id INTO v_org_id;
    RAISE NOTICE '[BLOQUE 2] Org "%" creada -> id: %', v_slug, v_org_id;
  ELSE
    UPDATE public.organizaciones
    SET plan   = 'pro_mensual',
        activa = true
    WHERE id = v_org_id
      AND (plan IS DISTINCT FROM 'pro_mensual' OR activa IS DISTINCT FROM true);
    RAISE NOTICE '[BLOQUE 2] Org "%" ya existia -> id: % (estado asegurado).', v_slug, v_org_id;
  END IF;
END $$;


-- ============================================================================
-- BLOQUE 3 - USUARIO en auth.users (idempotente por email)
-- ----------------------------------------------------------------------------
-- No existe trigger handle_new_user en este proyecto (verificado): el usuario
-- de Auth se crea aqui y el perfil de app se crea en el BLOQUE 5.
--
-- Compatibilidad de versiones: el INSERT se construye en runtime leyendo
-- information_schema, para:
--   - escribir instance_id solo si la columna existe;
--   - escribir confirmed_at solo si existe y NO es columna generada;
--   - rellenar con '' cualquier columna NOT NULL sin default que no hayamos
--     fijado (tipicamente tokens de confirmacion/recovery).
-- Esto evita el error "cannot insert a non-DEFAULT value into column ..."
-- de las versiones nuevas de GoTrue.
-- ============================================================================

DO $$
DECLARE
  v_email        text := lower('Diego.velez.abogado@gmail.com');
  v_nombre       text := 'Diego Velez';
  v_rol          text := 'superadmin';
  v_pass         text := '1234567890';
  v_crypt_schema text;
  v_user_id      uuid;
  v_instance_col text := '';
  v_instance_val text := '';
  v_conf_col     text := '';
  v_conf_val     text := '';
  v_extra_cols   text := '';
  v_extra_vals   text := '';
  v_sql          text;
BEGIN
  -- 3.1 Resolver el esquema de pgcrypto (crypt / gen_salt).
  SELECT n.nspname INTO v_crypt_schema
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE p.proname = 'crypt'
  ORDER BY (n.nspname = 'extensions') DESC, (n.nspname = 'public') DESC
  LIMIT 1;

  IF v_crypt_schema IS NULL THEN
    RAISE EXCEPTION 'pgcrypto no instalado: ejecute  create extension if not exists pgcrypto with schema extensions;';
  END IF;

  -- 3.2 Idempotencia: si el usuario ya existe, no crear.
  SELECT id INTO v_user_id FROM auth.users WHERE email = v_email;

  IF v_user_id IS NULL THEN
    -- 3.3 instance_id (solo si la columna existe).
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema = 'auth' AND table_name = 'users'
                 AND column_name = 'instance_id') THEN
      v_instance_col := ', instance_id';
      v_instance_val := ', ''00000000-0000-0000-0000-000000000000''::uuid';
    END IF;

    -- 3.4 confirmed_at (solo si existe y NO es generada).
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema = 'auth' AND table_name = 'users'
                 AND column_name = 'confirmed_at' AND is_generated = 'NEVER') THEN
      v_conf_col := ', confirmed_at';
      v_conf_val := ', now()';
    END IF;

    -- 3.5 Columnas NOT NULL sin default que no fijamos -> valor '' (tokens).
    SELECT
      COALESCE(string_agg(format(', %I', column_name), ''), ''),
      COALESCE(string_agg(format(', %L', ''), ''), '')
    INTO v_extra_cols, v_extra_vals
    FROM information_schema.columns
    WHERE table_schema = 'auth' AND table_name = 'users'
      AND is_nullable = 'NO'
      AND column_default IS NULL
      AND is_generated = 'NEVER'
      AND column_name NOT IN (
        'id','instance_id','aud','role','email','encrypted_password',
        'email_confirmed_at','created_at','updated_at',
        'raw_app_meta_data','raw_user_meta_data','confirmed_at'
      );

    v_user_id := gen_random_uuid();

    v_sql :=
      'INSERT INTO auth.users ('
      || 'id, aud, role, email, encrypted_password, '
      || 'email_confirmed_at, created_at, updated_at, '
      || 'raw_app_meta_data, raw_user_meta_data'
      || v_instance_col || v_conf_col || v_extra_cols
      || ') VALUES ('
      || quote_literal(v_user_id::text) || '::uuid, '
      || quote_literal('authenticated') || ', '
      || quote_literal('authenticated') || ', '
      || quote_literal(v_email) || ', '
      || quote_ident(v_crypt_schema) || '.crypt(' || quote_literal(v_pass) || ', '
      || quote_ident(v_crypt_schema) || '.gen_salt(' || quote_literal('bf') || ', 10)), '
      || 'now(), now(), now(), '
      || quote_literal('{"provider":"email","providers":["email"]}') || '::jsonb, '
      || 'jsonb_build_object(' || quote_literal('nombre') || ', ' || quote_literal(v_nombre)
      || ', ' || quote_literal('rol') || ', ' || quote_literal(v_rol) || ')'
      || v_instance_val || v_conf_val || v_extra_vals
      || ')';

    EXECUTE v_sql;
    RAISE NOTICE '[BLOQUE 3] Usuario creado -> id: %, email: %', v_user_id, v_email;
  ELSE
    RAISE NOTICE '[BLOQUE 3] Usuario ya existia -> id: % (no se toca la password).', v_user_id;
  END IF;

  -- 3.6 Auto-confirmacion idempotente (cubre tambien el caso "ya existia").
  UPDATE auth.users
  SET email_confirmed_at = now(),
      updated_at         = now()
  WHERE id = v_user_id
    AND email_confirmed_at IS NULL;
END $$;


-- ============================================================================
-- BLOQUE 4 - IDENTIDAD de login por email (auth.identities, idempotente)
-- ----------------------------------------------------------------------------
-- Compatibilidad de versiones:
--   - Esquema NUEVO (Supabase actual): existe provider_id. Filas:
--     (id uuid default, user_id, identity_data, provider, provider_id, ...).
--   - Esquema LEGACY: NO existe provider_id; la PK era (provider, id) con
--     id text = id del proveedor (el user_id). El script lo detecta solo.
--   ON CONFLICT DO NOTHING sin target: funciona con cualquier unique/PK.
-- ============================================================================

DO $$
DECLARE
  v_email   text := lower('Diego.velez.abogado@gmail.com');
  v_user_id uuid;
  v_sql     text;
BEGIN
  SELECT id INTO v_user_id FROM auth.users WHERE email = v_email;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION '[BLOQUE 4] No existe usuario en auth.users para % - ejecute el BLOQUE 3 o cree el usuario en el Dashboard.', v_email;
  END IF;

  IF EXISTS (SELECT 1 FROM auth.identities
             WHERE user_id = v_user_id AND provider = 'email') THEN
    RAISE NOTICE '[BLOQUE 4] Identidad email ya existia, skip.';
    RETURN;
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.columns
             WHERE table_schema = 'auth' AND table_name = 'identities'
               AND column_name = 'provider_id') THEN
    -- Esquema nuevo.
    v_sql :=
      'INSERT INTO auth.identities '
      || '(user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at) '
      || 'VALUES ('
      || quote_literal(v_user_id::text) || '::uuid, '
      || 'jsonb_build_object(' || quote_literal('sub') || ', ' || quote_literal(v_user_id::text)
      || ', ' || quote_literal('email') || ', ' || quote_literal(v_email) || '), '
      || quote_literal('email') || ', '
      || quote_literal(v_user_id::text) || ', '
      || 'now(), now(), now()) '
      || 'ON CONFLICT DO NOTHING';
  ELSE
    -- Esquema legacy: id text = id del proveedor.
    v_sql :=
      'INSERT INTO auth.identities '
      || '(id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at) '
      || 'VALUES ('
      || quote_literal(v_user_id::text) || ', '
      || quote_literal(v_user_id::text) || '::uuid, '
      || 'jsonb_build_object(' || quote_literal('sub') || ', ' || quote_literal(v_user_id::text)
      || ', ' || quote_literal('email') || ', ' || quote_literal(v_email) || '), '
      || quote_literal('email') || ', '
      || 'now(), now(), now()) '
      || 'ON CONFLICT DO NOTHING';
  END IF;

  EXECUTE v_sql;
  RAISE NOTICE '[BLOQUE 4] Identidad email creada para user_id: %', v_user_id;
END $$;


-- ============================================================================
-- BLOQUE 5 - PERFIL de app (public.perfiles, idempotente por id)
-- ----------------------------------------------------------------------------
-- Patron documentado por la app (admin.html): resolver el user por email y
-- crear el perfil. Aqui con ON CONFLICT (id) DO UPDATE para re-ejecucion
-- segura y para forzar el estado deseado (superadmin / activo / org propia).
-- Valores de rol admitidos por la app: superadmin | admin_evento | portero.
-- evento_id = NULL: el superadmin no depende de un evento puntual.
-- ============================================================================

INSERT INTO public.perfiles (id, nombre, rol, org_id, evento_id, activo)
SELECT au.id,
       'Diego Velez',
       'superadmin',
       o.id,
       NULL,
       true
FROM auth.users au
JOIN public.organizaciones o ON o.slug = 'diego-velez'
WHERE au.email = lower('Diego.velez.abogado@gmail.com')
ON CONFLICT (id) DO UPDATE
  SET nombre    = EXCLUDED.nombre,
      rol       = EXCLUDED.rol,
      org_id    = EXCLUDED.org_id,
      evento_id = NULL,
      activo    = true;
-- Esperado: INSERT 0 1 (creado) o UPDATE 1 (actualizado).
-- 0 filas = el email no existe en auth.users o la org 'diego-velez' no existe:
-- revisar los resultados de BLOQUE 0.5 y BLOQUE 2.


-- ============================================================================
-- BLOQUE 6 - VERIFICACION FINAL
-- ============================================================================

-- 6.1 Usuario en auth.users.
SELECT id, email, email_confirmed_at, created_at, updated_at
FROM auth.users
WHERE lower(email) = lower('Diego.velez.abogado@gmail.com');

-- 6.2 Organizacion.
SELECT id, nombre, slug, plan, activa, is_master_org, color_primario, nombre_app
FROM public.organizaciones WHERE slug = 'diego-velez';

-- 6.3 Perfil.
SELECT p.id, p.nombre, p.rol, p.org_id, p.evento_id, p.activo
FROM public.perfiles p
JOIN auth.users au ON au.id = p.id
WHERE lower(au.email) = lower('Diego.velez.abogado@gmail.com');

-- 6.4 Identidad de login (no se selecciona provider_id: no existe en legacy).
SELECT i.id, i.user_id, i.provider, i.identity_data, i.last_sign_in_at
FROM auth.identities i
JOIN auth.users au ON au.id = i.user_id
WHERE lower(au.email) = lower('Diego.velez.abogado@gmail.com');

-- 6.5 JOIN consolidado por email: usuario + org + perfil en una sola fila.
SELECT au.id AS user_id,
       au.email,
       au.email_confirmed_at,
       p.nombre,
       p.rol,
       p.activo,
       o.id AS org_id,
       o.slug AS org_slug,
       o.plan,
       o.is_master_org
FROM auth.users au
LEFT JOIN public.perfiles p ON p.id = au.id
LEFT JOIN public.organizaciones o ON o.id = p.org_id
WHERE lower(au.email) = lower('Diego.velez.abogado@gmail.com');
-- Esperado: 1 fila - rol superadmin, activo true, org_slug 'diego-velez',
-- plan 'pro_mensual', is_master_org false, email_confirmed_at no nulo.


-- ============================================================================
-- BLOQUE 7 - FALLBACK si el INSERT directo en auth.users falla por version
-- ----------------------------------------------------------------------------
-- Sintoma tipico: error de columnas/constraints de GoTrue (por ejemplo
-- 'column "provider_id" does not exist', 'cannot insert a non-DEFAULT value
-- into column "confirmed_at"', o NOT NULL inesperado). Procedimiento:
--
--   1) Crear el usuario desde el Dashboard:
--        Authentication -> Users -> Add user
--        Email: diego.velez.abogado@gmail.com
--        Password: 1234567890
--        Marcar "Auto Confirm User" (equivale a email_confirmed_at = now()).
--      Alternativa: "Invite user" para que el propio usuario defina password.
--
--   2) Volver al SQL Editor y ejecutar SOLO:
--        BLOQUE 1 (preambulo de plan)
--        BLOQUE 2 (organizacion)
--        BLOQUE 5 (perfil)
--        BLOQUE 6 (verificacion)
--      El BLOQUE 2 y el BLOQUE 5 son autonomos: solo dependen de que exista
--      auth.users (creado en el Dashboard) y del slug 'diego-velez'.
--      El BLOQUE 4 (identidad) normalmente NO hace falta si el usuario se creo
--      desde el Dashboard: Auth crea la identidad 'email' automaticamente.
--      Si el login falla, ejecutar BLOQUE 4 igualmente (es idempotente).
-- ============================================================================


-- ============================================================================
-- BLOQUE 8 - NOTAS DE SEGURIDAD Y OPERACION
-- ----------------------------------------------------------------------------
-- 1) PASSWORD DEBIL: '1234567890' es trivialmente adivinable y queda escrita
--    en texto plano en este archivo. Cambiarla tras el primer login:
--    - Dashboard: Authentication -> Users -> (usuario) -> Reset password.
--    - O por SQL, descomentando el UPDATE de abajo.
--    NO commitear este archivo con la password si el repo es publico.
--
-- 2) RLS: este script se ejecuta en el SQL Editor como postgres/service_role,
--    que ignora RLS. No usar la clave anon para replicarlo.
--
-- 3) is_master_org = false: correcto, es una org de cliente, NO la org maestra
--    de la plataforma (esa se gestiona aparte, ADR-025).
--
-- 4) Si ya existe una org con slug 'diego-velez' pero NO es la deseada,
--    cambie v_slug en BLOQUE 2 y el slug del JOIN en BLOQUE 5.
--
-- 5) 'enterprise' es para la org maestra interna; no usar para clientes.
-- ============================================================================

-- OPCIONAL - forzar la password del usuario (idempotente). Descomentar para
-- ejecutar. Se asume pgcrypto en el esquema 'extensions' (ver BLOQUE 0.3).
-- UPDATE auth.users
-- SET encrypted_password = extensions.crypt('1234567890', extensions.gen_salt('bf', 10)),
--     updated_at         = now()
-- WHERE email = lower('Diego.velez.abogado@gmail.com');
