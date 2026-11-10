---
doc: ADR-091
titulo: El correo del ticket acepta codigo corto y genera el QR server-side (Resend inline)
fecha: 2026-11-10
autor: @backend-dev (Edge Function) + @js-silo-dev (registroaforo.html); cierre documental @docs-keeper
estado: ACEPTADO E IMPLEMENTADO (Edge Function v12 desplegada); prueba funcional real con buzon PENDIENTE
relacionados: [ADR-002, ADR-008, ADR-063, ADR-064, ADR-076, ADR-077, ADR-078b, TASKS TSK-135, ERRORES_HISTORICOS E33 (H9)]
---

# ADR-091 - Correo del ticket: codigo corto `QR-...` y QR generado server-side

## 1. Contexto

El ticket del asistente se identifica con un codigo corto generado en el cliente (`registroaforo.html:806` y `:970`: `const qrCode = 'QR-' + UID()`) que se persiste en `inscritos.qr_code` (`:824`, `:1008`) y es **la misma credencial que valida `scanner.html`** en la puerta. El correo del ticket se despacha por el camino unico de la RPC `enviar_email_registro` (telemetria en `email_envios_log`), que propaga `p_qr_code` tal cual a la Edge Function `send-ticket-email` (Resend).

Hasta este ciclo, la Edge Function validaba `qrCode` con `/^https?:\/\//i` y rechazaba con `400` cualquier otra forma. El efecto estaba documentado como **H9** en `ERRORES_HISTORICOS.md` (E33, agravante del cron ADR-078b): el correo del ticket **no se podia enviar** con el codigo real del asistente. `eventobackup.html:4129` y `:4574` ya generaban `'QR-' + UID()` y lo enviaban en `enviar_email_registro` (`:4450-4451`), de modo que el `400` era el comportamiento esperado con el contrato anterior. (`registro.html:678` es el caso distinto del onboarding: manda una URL `origin + "/admin.html"`, por eso nunca chocaba con la validacion.)

## 2. Problema

Un contrato que solo acepta URL obliga a mandar al correo un enlace y no el codigo. Un ticket por correo que muestre un boton **no se puede escanear en la puerta**: el portero necesita el PNG del QR del codigo corto, no una URL del evento. Ademas, generar el PNG en el cliente (canvas) y adjuntarlo como Data URI no es viable en el correo (bloqueo de imagenes, tamano del payload, CSP) y complica el reintento.

## 3. Opciones evaluadas

1. **(Elegida)** Aceptar el codigo corto en la Edge Function y generar el PNG del QR **en el servidor**, viajando inline en el HTML del correo (`content_id`).
2. Seguir exigiendo URL y usar la URL del evento como `qrCode` (lo que hacia el camino heredado).
3. Generar el QR en el cliente y mandarlo como adjunto base64 o como `<img>` con Data URI.

## 4. Decision

1. **Contrato de `qrCode` ampliado (retrocompatible).** `qrCode` sigue siendo obligatorio y acepta **dos formas**: (a) **URL** `http(s)` con el maximo historico `MAX_URL_LEN` (2000) - comportamiento intacto, incluido el caso de `registro.html` que se renderiza como boton; (b) **codigo corto** que empieza con `QR-`, con `MAX_QR_CODE_LEN = 600` y rechazo de caracteres de control. Cualquier otra forma responde `qrCode_invalido`. El flag `qrIsCode` es **derivado e interno**: no se acepta ni se valida como campo del payload.
2. **Generacion server-side del PNG.** Con `qrIsCode` la funcion genera el PNG del QR en el propio runtime de Deno e inyecta en el HTML `<img src="cid:ticket-qr">`; el adjunto inline viaja con `content_id: "ticket-qr"` y `filename: "ticket-qr.png"`. La dependencia queda **pinneada** en el `deno.json` de la funcion: `npm:qrcode@1.5.3` (con `@deno-types="npm:@types/qrcode@1.5.5"` en el import).
3. **Fallback sin romper el correo.** Si la generacion del PNG falla, el correo **NO** falla: se envia el codigo en texto (grande) para que el asistente lo pueda dictar o el staff lo pueda teclear. Es la aplicacion de Silent Fallback (ADR-008) al canal de correo.
4. **Credencial unica.** El codigo que viaja en el correo es **el mismo `inscritos.qr_code`** que valida `scanner.html`; no se crea un token nuevo ni un QR de correo distinto. El cliente manda `p_qr_code: qr` (el codigo real), **nunca la URL del evento** (`registroaforo.html:1245`).
5. **Email obligatorio cuando el evento entrega QR.** En `registroaforo.html`, `email` es obligatorio solo si `window.__ctxCapturaPura === false` (modo ticket QR), tanto en el flujo nuevo (`#f-email`, `:663-666`) como en "Ya estoy registrado" (`#ex-email`, `:671-672`); se valida con el mismo `EMAIL_RE_REG` del contrato de la Edge Function **antes** de insertar, se persiste en `inscritos.email` (`:819`) y es el destinatario del envio (`:846`, `:1031`). Con `captura_pura = true` no se pide correo y el envio no se despacha.
6. **Estado y reintento visibles.** El envio pinta tres estados (`pending` / `ok` / `error`) y el error ofrece un boton **Reenviar** que usa una clave de idempotencia distinta (`'aforo-registro:' + qr + ':retry:' + Date.now()`, `:1226`) para no chocar con la que ya consumio la RPC. Una respuesta **sin `ok:true`** de la RPC (`{ ok:false, motivo }`: rate limit, `pg_net` caido) se trata como **error**, no como exito: solo un `ok` explicito justifica el verde (`:1257-1261`).
7. **Sin cambios en auth, CORS ni limites.** La funcion conserva la **autenticacion dual** (JWT de sesion verificado por firma o header `X-Service-Token` para el canal de base), el manejo de CORS, `MAX_BODY_BYTES` 65536, los limites por campo y el adjunto `ticketUrl` (TSK-088). El deploy se hace con `--no-verify-jwt` porque la verificacion la hace la funcion (canal RPC `X-Service-Token`), no el gateway.

## 5. Justificacion

- Un ticket por correo **tiene que ser escaneable**: el QR inline con `cid:` se renderiza en todos los clientes que muestran imagenes y no depende de un canvas ni de JS del lado del cliente.
- Generar en servidor elimina el payload base64 del cuerpo (que ademas choca con los limites de la funcion) y hace el fallback trivial (texto).
- Mantener la rama URL preserva el onboarding de `registro.html` y no rompe el contrato de los 5 call sites RPC (ADR-076/ADR-077).
- La credencial no se duplica: el correo y el scanner validan **el mismo** `inscritos.qr_code`.

## 6. Impacto

- **Archivos:** `registroaforo.html` (+186 / -17 en el ciclo), `supabase/functions/send-ticket-email/index.ts` (+121 / -18) y `supabase/functions/send-ticket-email/deno.json` (nuevo).
- **Contratos de datos:** ninguno nuevo. `inscritos.qr_code` y `inscritos.email` ya existen; `email_envios_log` ya es la telemetria del gateway.
- **Cero Borrado:** 0 IDs del Contrato v112 retirados, 0 atomos eliminados, 0 cambios en `admin.html`, `api/*.js`, SQL/RLS y el motor de render.
- **Operacion:** el correo del ticket deja de depender de una URL y pasa a depender del codigo; el `400` por codigo corto desaparece.

## 7. Alternativa descartada

**Usar la URL del evento como `qrCode`.** Es lo que hacia el camino heredado y lo que la validacion `^https?://` forzaba: el correo terminaba con un **boton/enlace**, no con un QR escaneable, porque el PNG del QR solo se generaba en el cliente para la pantalla. Consecuencias: en la puerta el staff no puede escanear el correo, el codigo real (`QR-...`) no se entrega nunca por correo y el ticket por correo queda inservible como credencial. Tambien se descarto generar el QR en el cliente y mandarlo como base64/Data URI: infla el cuerpo, lo acerca al limite de bytes de la funcion y los clientes de correo bloquean o recortan imagenes embebidas.

## 8. Verificacion

- Escudo GOLD **8/8**: balance de `div` **54/54**, ASCII-safety **0/0** lineas nuevas no-ASCII, sintaxis de los bloques JS inline **OK**.
- Smoke `scripts/smoke_registroaforo_wa.js` -> **77/77**.
- `deno check` de la funcion: **solo** el `TS2345` **preexistente** de `verifySessionJwt` (no introduce errores nuevos).
- Deploy real (fuera del repo, no auditable por ADR-006 desde archivos): proyecto Supabase `ctgyvydzshueemlelkzv`, funcion `send-ticket-email` **version 12 ACTIVE**, `--no-verify-jwt`.

## 9. Pendiente (no cierra este ADR)

Prueba funcional real con un buzon: registro en la pagina -> fila en `email_envios_log` -> correo recibido con el QR **inline** -> escaneo del PNG con `scanner.html` y `logs` con `resultado = 'Ingreso'`. Hasta que esa cadena se ejecute, la implementacion esta **desplegada pero no certificada** end-to-end.

## 10. Referencias

- H9 (agravante) en `ERRORES_HISTORICOS.md` E33 / `errores/E33-recordatorios-automaticos-que-nunca-se-enviaron.md`.
- Camino unico de correo: ADR-076 (secreto compartido) y ADR-077 (gateway RPC).
- Ticket y recuperacion de QR: ADR-063 / ADR-064.
- Silent Fallback: ADR-008.
