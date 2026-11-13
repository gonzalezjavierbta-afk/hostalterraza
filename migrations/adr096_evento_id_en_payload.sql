-- ============================================================================
-- ADR-096 - evento_id en el payload de enviar_email_registro
--
-- PROBLEMA
--   La RPC `public.enviar_email_registro` ya recibe `p_evento_id` (11o
--   parametro, text DEFAULT NULL) y 4 de los 5 llamadores del frontend ya lo
--   envian, pero el cuerpo NO lo incluia en `v_body`, el JSON que se postea a
--   la Edge Function `send-ticket-email`. Sin esa clave la funcion resuelve el
--   evento por `inscritos.email` (registro mas reciente), asi que un correo
--   registrado en varios eventos puede recibir la promocion del evento
--   equivocado.
--
-- SOLUCION
--   Insertar 'eventoId' en el jsonb_build_object que arma v_body.
--   `jsonb_strip_nulls` descarta la clave cuando llega NULL, por lo que los
--   llamadores que aun no la envian conservan el comportamiento anterior.
--
-- SEGURIDAD DEL PARCHE
--   Se parchea la definicion VIVA (pg_get_functiondef), no una copia:
--     - ancla unica: si el cuerpo no contiene el ancla, aborta sin tocar nada
--     - idempotente: si 'eventoId' ya esta, no hace nada
--     - atomico: CREATE OR REPLACE es transaccional en PostgreSQL
--   No cambia firma, permisos, SECURITY DEFINER ni search_path.
-- ============================================================================

do $mig$
declare
    v_def text;
    v_new text;
    v_oid oid;
begin
    select p.oid
      into v_oid
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.proname = 'enviar_email_registro'
     limit 1;

    if v_oid is null then
        raise exception '[ADR-096] no existe public.enviar_email_registro';
    end if;

    v_def := pg_get_functiondef(v_oid);

    if v_def is null or v_def = '' then
        raise exception '[ADR-096] pg_get_functiondef devolvio vacio';
    end if;

    -- Idempotencia: la clave ya viaja en el payload.
    if position('''eventoId''' in v_def) > 0 then
        raise notice '[ADR-096] ya aplicada: eventoId presente. Sin cambios.';
        return;
    end if;

    -- Ancla unica del payload. Si el cuerpo cambio, se aborta.
    if position('''eventoNombre'', v_evnom' in v_def) = 0 then
        raise exception '[ADR-096] ancla <<''eventoNombre'', v_evnom>> no encontrada: el cuerpo cambio, revisar a mano';
    end if;

    v_new := replace(
        v_def,
        '''eventoNombre'', v_evnom',
        '''eventoId'',     left(p_evento_id, 64), ''eventoNombre'', v_evnom'
    );

    if v_new = v_def then
        raise exception '[ADR-096] el replace no produjo cambios';
    end if;

    execute v_new;

    raise notice '[ADR-096] aplicada: eventoId agregado al payload.';
end
$mig$;

-- Verificacion posterior
select
    position('''eventoId'''     in p.prosrc) > 0 as evento_id_en_payload,
    position('''eventoNombre''' in p.prosrc) > 0 as evento_nombre_intacto,
    position('''qrCode'''       in p.prosrc) > 0 as qr_intacto
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'enviar_email_registro';
