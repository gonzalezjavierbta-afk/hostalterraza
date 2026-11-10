-- ============================================================================
-- Migracion: bucket de Storage para el PNG del ticket - ADR-092.
-- Archivo : migrations/adr092_bucket_tickets.sql
-- Ejecutar: supabase db query --linked -f migrations/adr092_bucket_tickets.sql
-- Idempotente: re-ejecutarla es un no-op logico (ADR-008).
-- ============================================================================
--
-- QUE HACE
--   1) Crea el bucket `tickets` con:
--        public             = true      -> getPublicUrl() del frontend sirve el
--                                          PNG sin URL firmada.
--        file_size_limit    = 2097152   -> 2 MB, el mismo MAX_TICKET_BYTES que
--                                          valida la Edge Function
--                                          fetchTicketAttachment. El limite en
--                                          el bucket corta antes de gastar
--                                          invocacion.
--        allowed_mime_types = {image/png} -> la Edge Function exige
--                                          content-type image/png; cualquier
--                                          otro tipo se rechaza en Storage.
--   2) Crea la politica de INSERT "Subir tickets" sobre storage.objects.
--
-- QUE NO HACE (deliberadamente)
--   - NO crea politica de SELECT: el bucket es publico. La lectura ocurre por
--     objeto publico / getPublicUrl, que no pasa por RLS de SELECT.
--   - NO crea politicas de UPDATE ni DELETE: un ticket emitido no se
--     sobrescribe ni se borra (Cero Borrado, Regla de Oro #2).
--   - NO crea politica de listado: nadie debe poder enumerar el bucket.
--   - NO toca el bucket `eventos-imagenes` ni sus 3 politicas
--     ("Ver imagenes eventos", "Subir imagenes eventos",
--      "Actualizar imagenes eventos"): siguen exactamente igual.
--   - NO toca tablas, columnas, funciones ni la RPC enviar_email_registro.
--
-- IDEMPOTENCIA
--   - INSERT ... ON CONFLICT (id) DO UPDATE: la 2da corrida reescribe los
--     mismos valores, sin error y sin duplicar la fila.
--   - DROP POLICY IF EXISTS antes del CREATE POLICY: la 2da corrida no falla
--     con "policy already exists".
--
-- CONTENCION DEL with_check
--   - bucket_id = 'tickets'  -> la politica no autoriza escrituras en ningun
--     otro bucket (en particular, no abre eventos-imagenes).
--   - name LIKE 'QR-%'       -> el frontend sube QR-<UID>.png; el prefijo acota
--     el uso de la anon key a este patron de nombre y evita que el bucket se
--     use como almacenamiento generico.
--   - No se condiciona a auth.uid(): la subida ocurre antes del login del
--     invitado (flujo publico de registro). La contencion real es el prefijo
--     QR- mas el limite de 2 MB y el MIME unico. Riesgo residual documentado
--     en ADR-092.
--
-- ASCII-SAFETY: 0 bytes fuera de ASCII (sin tildes, sin emojis, sin backticks).
-- Verificacion: Select-String -Path <este archivo> -Pattern '[^\x00-\x7F]'
-- debe devolver 0 coincidencias.
-- ============================================================================


BEGIN;

-- ----------------------------------------------------------------------------
-- FASE 1 - BUCKET (idempotente por ON CONFLICT).
--   Se declaran las 4 columnas de politica del bucket, no solo el id: si el
--   bucket ya existiera con valores laxos (sin limite, sin MIME), esta corrida
--   los corrige al estado normativo.
-- ----------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('tickets', 'tickets', true, 2097152, array['image/png'])
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;


-- ----------------------------------------------------------------------------
-- FASE 2 - POLITICA DE SUBIDA (solo INSERT).
--   Nombre fijo y unico para que el DROP previo sea determinista.
-- ----------------------------------------------------------------------------
drop policy if exists "Subir tickets" on storage.objects;

create policy "Subir tickets"
  on storage.objects
  for insert
  to public
  with check (
    bucket_id = 'tickets'
    and name like 'QR-%'
  );


-- ----------------------------------------------------------------------------
-- FASE 3 - VERIFICACION (solo lectura, dentro de la misma transaccion).
--   Esperado: 1 fila con public=true, file_size_limit=2097152,
--   allowed_mime_types={image/png}; la politica con cmd=INSERT y
--   with_check que exige bucket_id='tickets' y name LIKE 'QR-%'.
-- ----------------------------------------------------------------------------
select id, name, public, file_size_limit, allowed_mime_types
  from storage.buckets
 where id = 'tickets';

select policyname, cmd, roles, with_check
  from pg_policies
 where schemaname = 'storage'
   and tablename  = 'objects'
   and policyname = 'Subir tickets';

-- Control de no regresion: eventos-imagenes y sus 3 politicas deben seguir
-- presentes y con los mismos predicados de bucket.
select policyname, cmd
  from pg_policies
 where schemaname = 'storage'
   and tablename  = 'objects'
   and (qual like '%eventos-imagenes%' or with_check like '%eventos-imagenes%')
 order by policyname;

COMMIT;


-- ============================================================================
-- ROLLBACK (solo si FASE 3 sale mal)
-- ----------------------------------------------------------------------------
-- Quita unicamente lo creado por esta migracion. No toca eventos-imagenes.
--
-- BEGIN;
-- drop policy if exists "Subir tickets" on storage.objects;
-- delete from storage.buckets where id = 'tickets';
-- COMMIT;
--
-- Nota: el DELETE del bucket falla si el bucket tiene objetos. En ese caso
-- vaciar primero con la API de Storage (nunca con SQL directo sobre
-- storage.objects) y repetir.
-- ============================================================================
