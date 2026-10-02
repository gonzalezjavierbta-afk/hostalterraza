# E29: BUG-016 - `content.ticket_disenos` se borraba al guardar sin landing

- **Estado:** CORREGIDO (2026-10-02, ramas a y b)
- **Severidad:** ALTA (perdida silenciosa de datos; sin error visible para el autor)
- **Relacionado:** ADR-064 (contrato del diseno de ticket), E26, E27, ADR-070
- **Archivos:** `admin.html` (`_buildConfigLanding`, `guardarEventoWizard`)

## Sintoma

Un evento con disenos de ticket cargados perdia los disenos al volver a guardarlo desde el admin. No habia error, ni aviso, ni entrada de consola: el JSONB del evento se reescribia con un `config_landing` vacio o `null`.

## Causa raiz

La firma de guardado hace una asignacion condicional:

```
payload.config_landing = cfgLanding || null;
```

`_buildConfigLanding()` tenia tres salidas y **dos** de ellas secarryaban `ticket_disenos` sin revisarlo:

- **Rama (a) sin landing y sin formulario.** Devolvia `null` de forma incondicional. Como el evento no tiene plantilla, esa es la salida correcta... pero el `|| null` de arriba convertia ese `null` en un `config_landing: null`, es decir, un **replace** de todo el JSONB, no un merge parcial. Los disenos iban dentro.
- **Rama (b) solo formulario.** Devolvia un `cfg` minimo con `content.form_solo` y `content.comunidad_whatsapp`. Tampoco copiaba `ticket_disenos`, con lo cual la misma Firma los perdia.

No era un problema de permisos ni de RLS: era **pérdida de datos por reconstruccion parcial**.

## Correccion

Se lee el estado de los disenos **antes** de decidir la salida y se propaga a las dos ramas:

- **Rama (a):** se mantiene `return null` **solo cuando no hay disenos** (fail-open: sin datos que preservar, el `null` es lo correcto y no expone una landing inexistente). Si hay disenos, se devuelve un cfg minimo que lleva solo `content.ticket_disenos`.
- **Rama (b):** el cfg de solo formulario ahora incluye tambien `content.ticket_disenos`.

## La "rama (c)" que no existia

El reporte original senalaba una tercera rama en `_crearEventoUnico()` (linea ~7083 al momento del hallazgo) como otro punto de perdida. **No lo era**: esa zona es codigo de estadisticas del perfil de invitador. Ademas, `_crearEventoUnico` solo hace un spread condicional sobre un `INSERT`, no un replace, asi que no puede borrar claves existentes. **No se modifico esa funcion.**

Regla que se aplico: antes de "arreglar" una rama reportada, se leyo el codigo. Un hallazgo heredado de una exploracion previa no es un hecho.

## Verificacion

- `scripts/smoke_ticket_diseno.js`: 265/265 PASS.
- `scripts/smoke_hero_contract.js`: seccion S7, con asserts sobre el guard `if (!_disenosPrevias.length) return null;` y sobre la propagacion en ambas ramas.

## Leccion

Un `cfg || null` en la firma de guardado es una **borrada logica**: convierte "no hay plantilla" en "borra todo el JSONB". Cualquier clave que viva en `content` y se lea de la UI es vulnerable mientras la reconstruccion sea parcial. La regla que se aplica desde ahora: **si un dato se captura en el admin, tiene que aparecer en todas las salidas de `_buildConfigLanding`, o la rama tiene que documentar por que se descarta.**
