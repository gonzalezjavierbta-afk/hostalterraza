---
doc: E30 (ERRORES_HISTORICOS.md §30)
version: v1.8.0-STABLE (heredada)
fecha: 2026-10-03
origen: ERRORES_HISTORICOS.md §30 (nueva, 2026-10-03)
relacionados: [../ERRORES_HISTORICOS.md, ../INDEX.md, ../DECISIONS.md]
estado: vigente
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [ERRORES_HISTORICOS.md](../ERRORES_HISTORICOS.md) §30 · [INDEX](../INDEX.md).

## 30. Diagnostico Falso por Digest de Secreto + Deriva de Remitente y Campo Inexistente (2026-10-03 — remitente verificado + cron ADR-078)

### A. `supabase secrets list --output json` devuelve el DIGEST SHA-256, NO el valor
* **Problema:** se diagnostico "`RESEND_API_KEY` invalida" a partir de la salida de `supabase secrets list --output json`, que muestra un **digest SHA-256** del secreto, no su valor. El digest no es comparable con la key real, asi que el diagnostico era un **falso negativo**.
* **Causa raiz:** confundir el hash expuesto por el CLI con el contenido del secreto. El CLI nunca devuelve el valor en claro.
* **Blindaje:** ningun digest debe leerse como "el secreto esta mal". Para validar un secreto se prueba el **efecto** (envio real / respuesta 2xx), nunca su hash. `supabase secrets list` sirve para verificar EXISTENCIA, no correccion.
* **Desenlace:** la key real si funcionaba; el correo se envio (id Resend `01a103e4-b89e-73c8-b2f0-0d818f80d7c2`).

### B. Mismatch `MAIL_FROM` (leido por index.ts) vs `FROM_EMAIL` (secret existente)
* **Problema:** `send-ticket-email/index.ts` lee `env("MAIL_FROM")`, pero el secret existente se llamaba **`FROM_EMAIL`** con un valor de **64 caracteres hex** que **no es un email**. Al no matchear el nombre, la Function caia al remitente por defecto.
* **Causa raiz:** el contrato env-var/codigo se desincronizo (`FROM_EMAIL` en el gateway vs `MAIL_FROM` en el codigo).
* **Blindaje:** el nombre de la variable de entorno es parte del contrato Function/secrets: todo secreto que alimente una `env()` debe coincidir exactamente en nombre y formato.
* **Estado:** `FROM_EMAIL` queda **obsoleto** (**no borrado**, Cero Borrado); su retiro es una **decision pendiente de Direccion**. El default real hoy es `Taquilla Directa <no-reply@tickets.taquilladirecta.com>` (verificado en Resend).

### C. `eventos.lugar` no existe; es `eventos.ubicacion` (ADR-006, el archivo manda)
* **Problema:** el cron de recordatorios (ADR-078) referencio `eventos.lugar`, que **NO existe** en la tabla; PostgreSQL devolvio **error `42703`** (`column does not exist`).
* **Causa raiz:** el nombre del campo se asumio desde la semantica ("el lugar del evento"), no desde el esquema real.
* **Blindaje:** prevalece el archivo/esquema (ADR-006): el campo correcto es **`eventos.ubicacion`**. Corregido en la migracion `migrations/adr078_cron_recordatorios.sql`.

### D. `supabase db query --linked` requiere `supabase link` previo
* **Problema:** las consultas contra la BD fallaban hasta ejecutar `supabase link` al proyecto correcto.
* **Causa raiz:** sin link, el CLI no resuelve la instancia `--linked`.
* **Estado:** ya enlazado al ref `ctgyvydzshueemlelkzv`.

### E. Seguridad: credenciales en claro fuera del repo + PAT a rotar
* **Problema:** `C:\Users\TEKNIKCOLOMBIA\Documents\supabase.txt` contiene **credenciales en claro fuera del repositorio**. Ademas, el **PAT de Supabase** usado en la sesion debe **rotarse**.
* **Blindaje:** nunca persistir secretos en texto plano fuera de un gestor de secretos; rotar toda credencial que se haya usado o podido exponer. **Rotacion del PAT: pendiente.**

---

*Registro agregado el 2026-10-03 (remitente verificado + cron ADR-078). Los E01-E29 no se alteran (Cero Borrado).*
