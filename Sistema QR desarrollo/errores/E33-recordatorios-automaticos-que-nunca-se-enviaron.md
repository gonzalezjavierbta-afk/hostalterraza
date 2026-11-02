---
doc: E33 (ERRORES_HISTORICOS.md 33)
version: v1.8.0-STABLE (heredada)
fecha: 2026-11-01
origen: ERRORES_HISTORICOS.md seccion 33 (nueva, 2026-11-01). Runbook B9-smoke-email.md, hallazgos H1 / H6 / H9; hotfix migrations/adr078b_fix_cron_recordatorios.sql.
relacionados: [../ERRORES_HISTORICOS.md, ../INDEX.md, ../runbooks/B9-smoke-email.md, ../TASKS.md]
estado: resuelto en la base (2026-11-01); smoke end-to-end PENDIENTE (TSK-126)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [ERRORES_HISTORICOS.md](../ERRORES_HISTORICOS.md) seccion 33 - [INDEX](../INDEX.md).

## 33. Recordatorios Automaticos que Nunca se Enviaron (2026-11-01 - ADR-078b)

> Corregido y APLICADO en la base el 2026-11-01 con `migrations/adr078b_fix_cron_recordatorios.sql`. El smoke end-to-end (RPC -> Function -> Resend) sigue pendiente: TSK-126 / runbook `B9-smoke-email.md`.

### A. Sintoma

* Los recordatorios automaticos por correo **nunca se enviaron**. `public.fn_enviar_recordatorios_pendientes()` **abortaba entera**: el job `recordatorios-horarios` de `pg_cron` quedaba en `failed` y **no se escribia ninguna fila** en `email_envios_log`. No habia error visible para el usuario final: el fallo vivia solo en `cron.job_run_details`.

### B. Causa raiz

* `migrations/adr078_cron_recordatorios.sql:112` llamaba la RPC con `p_qr_code => ''`, y `migrations/adr076_enviar_email_seguro.sql:791` declara ese parametro **obligatorio**: `public.fn_adr076_texto_limpio(p_qr_code, 'qr_code', 600, true)`. Un string vacio lanza **SQLSTATE `22023`** (`adr076:430`) antes del `INSERT` de traza (`adr076:935`) y antes del bloque fail-open (que abre en `adr076:869` y cuyo handler `EXCEPTION WHEN OTHERS` esta en `adr076:1061`). La excepcion **no se capturaba**: propagaba hasta el job.
* **Agravante H9 (misma familia):** `admin.html` genera `qr_code = 'QR-' + UID()` (codigo corto) y `supabase/functions/send-ticket-email/index.ts:276-280` exige `/^https?:\/\//i` -> responde `400` "qrCode debe ser una URL http o https". Un fallback con `COALESCE` sobre vacio/NULL **no bastaba**: el `'QR-A1B2C3'` no esta vacio, solo no es URL. Hacia falta un `CASE` que detectara qr no-URL por **forma**.

### C. Como se resolvio

* `migrations/adr078b_fix_cron_recordatorios.sql` (`CREATE OR REPLACE` del cuerpo de la funcion; no re-agenda el cron ni crea extensiones): fallback de `p_nombre` a `'Asistente'` (H2b, para que `jsonb_strip_nulls` no borre la clave) y `CASE` para `p_qr_code` (se conserva el qr solo si ya es `http(s)`; si no, el enlace canonico por `slug`). **APLICADA en la base el 2026-11-01.**
* v1.1 del mismo archivo (blindaje de slug NULL: si `eventos.slug` es NULL/vacio cae a la raiz del dominio, en vez de dejar `...?slug=` sin evento) esta **escrita y pendiente de re-aplicar**.

### D. Lecciones

1. **Todo cambio en la firma u obligatoriedad de un parametro de RPC exige revisar los llamadores.** Aqui el llamador era el cron de ADR-078: paso a pasar `''` a un parametro que se volvio obligatorio.
2. **Un dry-run con 0 filas no valida nada.** El `0/0/0/0` de ADR-078 no ejercito ninguna fila y dejo el canal "verde" sin haber enviado nunca un correo: se verifica con al menos **1 fixture en ventana**.
3. **`COALESCE` no es un fallback de formato.** Cubre vacio/NULL, no un valor no vacio pero invalido por forma (`'QR-XXXX'`). El guard correcto es por forma (`CASE ... ~* '^https?://'`).
4. **La traza antes del envio es la que delata el fallo.** Como la validacion corta antes del `INSERT`, el silencio en `email_envios_log` era la unica pista: la ausencia de filas es un sintoma, no un "no habia nada que enviar".
