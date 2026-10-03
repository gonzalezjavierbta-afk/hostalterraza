---
doc: ADR-078
version: v1.18-GOLD (heredada de DECISIONS.md)
fecha: 2026-10-03
origen: Cron de recordatorios automaticos (cierre de TSK-003). Tier PAGO. Depende de ADR-073/074/076.
version_previa: ADR-077
relacionados: [../DECISIONS.md, ADR-073-columna-canonica-del-instante-del-evento-evento-inicio.md, ADR-074-configuracion-del-recordatorio-automatico-antes.md, ADR-076-camino-unico-de-envio-de-correo-con-secreto.md, ADR-077-gateway-de-correo-de-los-5-call-sites-rpc-como-camino-unico.md]
estado: aplicado (ver campo Estado dentro del ADR)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [DECISIONS.md](../DECISIONS.md) - [INDEX](../INDEX.md).

## ADR-078: Cron de recordatorios automaticos

**Fecha:** 2026-10-03

**Estado:** ACEPTADO / APLICADO. Migracion `migrations/adr078_cron_recordatorios.sql` APLICADA a la BD `ctgyvydzshueemlelkzv`. Job verificado en `cron.job`.

**Contexto:** ADR-073/074/076 dejaron listas las piezas: instante canonico (`eventos.evento_inicio`), ventana en datos (`config_recordatorios`, default 56 h) y el RPC `enviar_email_registro` como unico dueno del envio. Faltaba el disparador: ningun job llamaba al RPC. `pg_net` ya estaba en 0.20.0; `pg_cron` no estaba instalado.

**Decision:** (1) `CREATE EXTENSION pg_cron` (quedo version 1.6.4). (2) `public.fn_enviar_recordatorios_pendientes()` SECURITY DEFINER, ejecutable solo por `service_role`, busca eventos en la ventana +-2 h alrededor de `fn_horas_recordatorio(evento_id)` y, por cada inscrito con email, llama a `public.enviar_email_registro(... p_tipo='recordatorio', p_idempotency_key='recordatorio:<evento_id>:<inscrito_id>', p_bypass_rate_limit=true)`; respeta `config_recordatorios.activo` (override evento -> fila global -> true). (3) Job `recordatorios-horarios`, schedule `5 * * * *` (cada hora a los :05), activo.

**Consecuencias:** Correccion de baseline (ADR-006): la funcion toma el lugar desde `eventos.ubicacion` (no `eventos.lugar`, que no existe). Dry-run verificado: `{"eventos":0,"enviados":0,"omitidos":0,"errores":0}` (no habia eventos en ventana; no envia). No se crea un segundo camino de envio: el recordatorio hereda idempotencia, traza y rate limit del gateway RPC de ADR-077. Cierra TSK-003.

**Pendiente:** Probar con un evento real a ~56 h para confirmar envio e idempotencia.
