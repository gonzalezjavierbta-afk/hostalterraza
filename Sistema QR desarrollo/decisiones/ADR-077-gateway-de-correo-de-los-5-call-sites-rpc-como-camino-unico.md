---
doc: ADR-077
version: v1.17-GOLD (heredada de DECISIONS.md)
fecha: 2026-10-03
origen: FASE 2B del canal de correos. Tier PAGO; gate de riesgo de AGENTS.md seccion 2 (arquitectura/ADR) AUTORIZADO por Direccion para FASE 2B. Revisor: @architect-review. Decision de arquitectura; NO se escribio codigo.
version_previa: ADR-076
relacionados: [../DECISIONS.md, ../INDEX.md, ADR-076-camino-unico-de-envio-de-correo-con-secreto.md, ADR-073-columna-canonica-del-instante-del-evento-evento-inicio.md, ADR-074-configuracion-del-recordatorio-automatico-antes.md]
estado: vigente (ver campo Estado dentro del ADR)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [DECISIONS.md](../DECISIONS.md) - [INDEX](../INDEX.md).

## ADR-077: Gateway de correo de los 5 call sites (RPC `enviar_email_registro` como camino unico)

**Fecha:** 2026-10-03

**Autor:** @architect-review (FASE 2B, tier PAGO). Gate de `AGENTS.md` seccion 2 AUTORIZADO por Direccion para FASE 2B.

**Estado:** DECIDIDO. **EJECUTADO Y VERIFICADO (FASE 2B, 2026-10-03, commit `5ca58d8`).** Los **5/5 call sites migrados** a `SB.rpc('enviar_email_registro', ...)`: piloto `serie.html` + lote en orden `eventobackup`->`admin`->`registro`->`registroaforo`. B5 (secreto Vault `send_ticket_email_service_token`) y B6 (Edge Function re-desplegada con `--no-verify-jwt`, ahora **VERSION 6 ACTIVE**; auth HTTP verificada: sin token->401, token correcto+body invalido->400, token incorrecto->401) quedaron **HECHOS** (ya **no** diferidos). Escudo GOLD PASS 6/6. **Pendientes residuales de 2B:** smoke de envio real (B9), gap `p_tipo` (`admin.html` no mapea la fila "Tipo"), `p_inscrito_id` NULL (los INSERT no hacen `.select('id')`), `MAIL_FROM` vs secret `FROM_EMAIL`, anon key en `admin bacup.html:4774`, rotacion del PAT de Supabase. `ADR-075` sigue hueco. Cierre documental: `TASKS.md` (seccion FASE 2B), `NEXT.md` hito -42.

> **Nota de actualizacion (2026-10-03):** esta Decision se escribio con el **piloto B3** implementado y el lote diferido (hito -41). El texto de Decision/Opciones/Mapeo/Consecuencias **se conserva intacto** (Cero Borrado); el estado REAL hoy es el descrito en este campo **Estado** y en el bloque de Hechos de `TASKS.md`/`NEXT.md`. La Decision de arquitectura (gateway A) **no cambio**.

### Problema

Los 5 call sites hacen `POST` a la Edge Function `send-ticket-email` con la **anon key embebida** (`admin.html:8158` la trae hardcodeada; `registro.html:678`, `registroaforo.html:1009`, `serie.html:993`, `eventobackup.html:4449` usan `SUPABASE_KEY`). Esa credencial es **publica**: el endpoint es un relay de correo autenticado desde el dominio del proyecto. Hay que elegir el gateway definitivo antes de migrar, sin romper el registro y sin reintroducir la anon key como credencial de envio.

### Contexto verificado (baseline = archivo real, ADR-006)

- ADR-076 **aplicada y verificada**. `migrations/adr076_enviar_email_seguro.sql` define:
  - `public.enviar_email_registro(p_email text, p_nombre text, p_qr_code text, p_evento_nombre text, p_evento_fecha text, p_evento_hora text, p_evento_lugar text, p_idempotency_key text, p_tipo text DEFAULT 'registro', p_cedula text DEFAULT NULL, p_evento_id text DEFAULT NULL, p_inscrito_id text DEFAULT NULL, p_bypass_rate_limit boolean DEFAULT false)` — **text x12 + boolean** (firma real, `:731-745`). `GRANT EXECUTE a anon/authenticated/service_role` (`:1286-1288`).
  - **No recibe credencial del llamador.** Resuelve el secreto de servicio (`send_ticket_email_service_token` en Vault o `app.settings.service_token`) y, si no existe, **falla CERRADO** con `42501` (`:861-865`). Idempotencia por `email_envios_log(idempotency_key UNIQUE)`; rate limit 3/cedula+evento/10 min y 10/IP/h; `pg_net.http_post` con cabecera `X-Service-Token`.
  - **Correccion al brief de FASE 2B:** los parametros `p_email_dest`, `p_apellidos`, `p_tipo_ticket`, `p_cantidad`, `p_fecha_evento`, `p_hora_evento`, `p_qr_url`, `p_origen_ip` **NO existen en el repo**. La firma vigente es la de `:731-745`. Usar los nombres del brief rompe la llamada por `function does not exist`.
  - `public.obtener_inscrito_por_cedula(p_cedula text, p_evento_id text, p_telefono text DEFAULT NULL)` (`:1137-1141`).
- Edge Function `supabase/functions/send-ticket-email/index.ts`: auth dual propia — `X-Service-Token` (comparacion en tiempo casi constante contra `SERVICE_SHARED_TOKEN`) **o** `Authorization: Bearer <JWT de sesion>`; **la anon key se rechaza con 401** (`:402-408`). NO desplegada. `vault.secrets = 0 filas`. CLI sin linkear (deploy bloqueado).
- Los cuerpos actuales de los 5 sitios ya son 1:1 con la firma de la RPC: `email, nombre, qrCode, eventoNombre, eventoFecha, eventoHora, eventoLugar, tipo`.

### Opciones

- **(A) RPC `enviar_email_registro` directo desde el navegador.** El cliente llama `SB.rpc(...)` con la anon key solo como `apikey` de PostgREST; la autorizacion de envio es el secreto del servidor. La Edge Function pasa a ser **transporte server-to-server** invocado por la RPC. Resuelve los 5 sitios por igual, incluido el publico.
- **(B) Edge Function como gateway con JWT de sesion / X-Service-Token.** Cambio minimo por sitio (swap de header), pero **no resuelve `registroaforo.html`** (publico, sin sesion) y duplica autorizacion sin idempotencia de servidor; deja la RPC de ADR-076 sin uso.
- **(C) Hibrido.** Dos modelos de auth y dos trazas; mas superficie. Descartada.

### Decision

**A.** Camino unico = RPC `public.enviar_email_registro`. La Edge Function **deja de ser gateway de cliente** y queda como **transporte interno** (la RPC la invoca con `X-Service-Token`). Razones: (1) es el "camino unico permitido" que ADR-076 ya diseno y aplico; (2) no introduce credencial publica de envio (restringe el mandato: la anon key es transporte PostgREST, no autorizacion de correo); (3) centraliza idempotencia, rate limit y validacion; (4) resuelve el formulario publico sin sesion; (5) no crea endpoint nuevo (presupuesto ADR-002 intacto); (6) fail-closed sin secreto.

### Mapeo por call site (ruta -> gateway + params)

Todos: `SB.rpc('enviar_email_registro', { p_email, p_nombre, p_qr_code, p_evento_nombre, p_evento_fecha, p_evento_hora, p_evento_lugar, p_idempotency_key, p_tipo, p_cedula?, p_evento_id?, p_inscrito_id? })`. `idempotency_key` es obligatorio.

1. `admin.html:8151` (`enviarQREmail`): 1:1. `p_tipo` NO puede ser el tipo de ticket (`frecuente/artista/...`): la RPC solo admite `registro|bienvenida|recordatorio` (`:805-808`) y reemplaza el `tipo` del cuerpo (`:1023`). Se pierde la fila "Tipo" del ticket -> aceptable; extension futura = `p_ticket_tipo` (nuevo ADR). `p_evento_id`/`p_cedula` si estan disponibles; clave de resend unica por accion.
2. `registro.html:678` (BIENVENIDA): **va por la RPC con `p_tipo='bienvenida'`**; el RPC acepta contenido libre (`eventoNombre='Bienvenido...'`, `qrCode=base/admin.html`). No es 1:1 con un ticket, pero la RPC es generica de contenido. No se descarta.
3. `registroaforo.html:1009`: RPC con `p_cedula` + `p_evento_id` (formulario publico, ver TSK-102). Hoy `emailAddr` es `null` (`:726`, `:860`) y `:1006` es no-op: la migracion debe ademas aportar el email capturado.
4. `serie.html:993`: 1:1; `p_evento_id` de la sesion/evento.
5. `eventobackup.html:4449`: 1:1.
6. `admin bacup.html:4774`: **backup, no migrar**; contiene la misma anon key hardcodeada -> limpiar o retirar del arbol (deuda de secreto, no de contrato).

### TSK-102 (`registroaforo.html`, publico sin sesion)

La RPC es la respuesta: **no recibe credencial del llamador**, la autorizacion de envio vive en el secreto del servidor. La anon key solo alcanza PostgREST; no es la credencial que envia. Los controles de abuso los pone el servidor: rate limit 3/cedula+evento/10 min + 10/IP/h, validacion estricta de email, idempotencia. Es **estrictamente mas fuerte** que el estado previo (anon key embebida permanente, sin rate limit ni idempotencia). **No** se usa token de servicio en el cliente ni JWT anon con RLS acotado como autorizacion de envio. Endurecimiento recomendado (no bloqueante, ADR propio): exigir que `(p_cedula, p_evento_id)` exista en `inscritos` y/o honeypot-captcha, para acotar el relay de destinatario arbitrario.

### Consecuencias / orden de rollout (Cero Borrado, no romper registro)

> **PASOS 1-3 EJECUTADOS (2026-10-03, commit `5ca58d8`):** el secreto Vault == Function env `SERVICE_SHARED_TOKEN` se creo; la funcion v6 esta ACTIVE (`--no-verify-jwt`); los 5 sitios migrados. El paso 4 (limpieza de la anon key hardcodeada) **sigue pendiente en `admin bacup.html:4774`**. El texto de los pasos se conserva como historial.

1. Operador: crear Vault `send_ticket_email_service_token` y Function env `SERVICE_SHARED_TOKEN` **con el mismo valor** (si difieren, `X-Service-Token` da 401 y la RPC marca `estado='error'; fail-open -> correo perdido en silencio`).
2. Desplegar `supabase functions deploy send-ticket-email --no-verify-jwt` (pg_net no manda JWT; la funcion se auto-autentica).
3. Migrar los 5 sitios (archivos estaticos, se pueden ir en un mismo commit) a `SB.rpc(...)`. Piloto sugerido: `serie.html` (con sesion, no critico) -> verificar un correo real -> lote. En la ventana entre el deploy (paso 2) y la migracion, los call sites viejos reciben 401: **correo roto, formulario sano** (todos tragan el error). Se acepta la ventana corta antes que reintroducir la anon key.
4. Limpiar la anon key hardcodeada (`admin.html:8158`) y el backup. No se borran IDs del Contrato v112 (Oro #2) ni elementos ocultos.

### Riesgos

1. **Firma del brief incorrecta** (ver Contexto): implementar con los nombres del brief falla. Prevalece el archivo.
2. **`p_tipo` colisiona** con el tipo de ticket de `admin.html` -> degradacion de la fila "Tipo".
3. **RPC invocable por `anon`** = relay de destinatario arbitrario acotado por rate limit, sin origin/captcha. Mejora neta, riesgo residual documentado.
4. **Acoplamiento de secreto** Vault == Function env; fallo silencioso si difieren.
5. **Ventana de correo roto** en la transicion (fail-closed asumido).
6. **`ticketUrl` (TSK-088) e `idempotencyKey` no viajan** en la RPC: el adjunto del ticket queda como gap futuro.
7. **Deploy bloqueado** por CLI sin linkear/credenciales: la migracion de HTML puede avanzar; el envio real no, hasta resolver el deploy.
8. `v_origen` hardcodeado `'rpc_publica'`: la RPC no distingue admin de publico en la traza.

### Referencias cruzadas

ADR-076 (camino unico y RPC reutilizada; **dependencia dura**), ADR-073/074 (canal de correo), ADR-002 (presupuesto de endpoints y ASCII-safe), ADR-001 (vanilla JS puro: `SB.rpc` sin build), ADR-006 (baseline = archivo real), ADR-068 (deuda D1 / `select *`), TSK-101 (migrar call sites), TSK-102 (`registroaforo.html`), TSK-103 (despliegue), TSK-088 (adjunto del ticket).
