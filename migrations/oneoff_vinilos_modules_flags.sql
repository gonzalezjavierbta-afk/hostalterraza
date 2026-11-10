-- oneoff_vinilos_modules_flags.sql (2026-11-10)
-- Fija los flags de visibilidad de modulos del evento vinilos-inversos-c8yu.
-- Contexto: el kernel ahora honra config_landing.modules (ADR-093); antes esos
-- flags se guardaban desde el admin pero el motor publico nunca los leia.
-- gallery=false oculta fotos + video; whatsapp=false oculta #mod-whatsapp;
-- form=false oculta "Unete a nuestra comunidad" (#mod-form);
-- guest_list=true + boletos_guestlist=true ponen boleteria y guest list en una fila.
-- Alcance: 1 fila, 1 columna (config_landing). Idempotente. ASCII puro.
BEGIN;
UPDATE eventos
   SET config_landing = jsonb_set(
         jsonb_set(
           jsonb_set(
             jsonb_set(
               jsonb_set(config_landing, '{modules,gallery}', 'false'::jsonb, true),
               '{modules,whatsapp}', 'false'::jsonb, true),
             '{modules,form}', 'false'::jsonb, true),
           '{modules,guest_list}', 'true'::jsonb, true),
         '{modules,boletos_guestlist}', 'true'::jsonb, true)
 WHERE slug = 'vinilos-inversos-c8yu'
   AND config_landing IS NOT NULL
RETURNING slug, config_landing->'modules' AS modules;
COMMIT;
