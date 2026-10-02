---
doc: E11 (ERRORES_HISTORICOS.md §11)
version: v1.8.0-STABLE (heredada)
fecha: 2026-10-01
origen: ERRORES_HISTORICOS.md L137-147 (AMPLIACION/_backups/ERRORES_HISTORICOS.md.2026-10-01.bak)
version_previa: ERRORES_HISTORICOS.md v1.8.0-STABLE
relacionados: [../ERRORES_HISTORICOS.md, ../INDEX.md]
estado: vigente
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [ERRORES_HISTORICOS.md](../ERRORES_HISTORICOS.md) §11 · [INDEX](../INDEX.md). Texto original íntegro debajo (L137-147 del original).

## 11. Métodos de String sin Blindar Sobre Campos de Supabase Potencialmente Nulos (Sesión ADR-024 — Fix "Null Pointer Regression")

### 🚨 `.replace()` sin Protección en `inscritos.nombre` / `inscritos.evento_nombre` — Bloqueo Total del Panel
* **Problema:** `_renderTablaPagina()` armaba los `onclick` de los botones de check-in/reversión/eliminación de cada fila con `i.nombre.replace(/'/g,...)` e `i.evento_nombre.replace(/'/g,...)`, sin verificar antes que esos campos no fueran `null`. Para la organización "Barrio R10" (con registros de `inscritos` incompletos), esto producía `TypeError: Cannot read properties of null (reading 'replace')` y **bloqueaba el panel completo** — no un módulo aislado: al tronar dentro de un `.map()` que construye el `innerHTML` de toda la tabla, ninguna fila llegaba a renderizarse, para ninguna organización con al menos un registro incompleto.
* **Causa:** Bug preexistente, no introducido por la reestructuración de pestañas de ADR-023 (que no tocó esta función). El principio de Silent Fallback (ADR-008) estaba definido en el proyecto para `<img onerror>` desde `Reglas_de_Oro_QR.md`, pero no se había extendido explícitamente a métodos de `String.prototype` (`.replace`, `.split`, `.trim`, `.toUpperCase`, `.localeCompare`, etc.) sobre campos que Supabase puede legítimamente devolver en `null` — y la tabla `inscritos` en particular tiene por diseño numerosas columnas nullable (ver `BLUEPRINT.md` §"Esquema `inscritos`": 15 columnas de Fase 2 de `b5`, solo 3 se completan según la categoría elegida).
* **Blindaje (ADR-024):** Patrón `(campo||'').metodo(...)` aplicado en `_renderTablaPagina()` y, preventivamente, en el bloque `evStats` de `renderPanel()` (`ev.fecha`/`ev.nombre`/`a.fecha.localeCompare(b.fecha)`, sin reporte previo de fallo pero con el mismo riesgo estructural). Auditoría recomendada para futuras sesiones sobre `admin.html`: cuando una función interpola un campo de Supabase dentro de una llamada a un método de string (no solo `.replace()` — también `.split()`, `.trim()`, `.toUpperCase()`, `.toLowerCase()`, `.localeCompare()`, `.substr()`, `.charAt()`, `.slice()` sobre el valor en sí, o `.length` sobre un valor que podría no ser string), verificar si ese campo puede ser `null` en el esquema real antes de asumir que la comprobación visual o el uso previo sin fallos garantiza que siempre vendrá poblado — un campo puede estar poblado en todas las organizaciones de prueba y ser `null` en una real, como ocurrió aquí.

### ✅ Auditoría completa ejecutada (TSK-023 / ADR-029, 12-ago-2026)
* El barrido recomendado en la línea anterior se ejecutó sobre **todo** `admin.html`: **11 puntos de crash reales** corregidos con `(campo||'')` en `renderEventos()` (2), `renderInvitadoresPerfil()`/`abrirPerfilInvitador()` (3), `renderDirectorio()` (1), duplicados (2), `showVerify()` de Admin (1), `descargarInvitacion()` (1), export de eventos (1), gráficas globales (1) y búsqueda global (1), más blindaje de interpolaciones que mostraban `"null"` literal. Ninguno había sido reportado por usuario; todos eran disparables con registros incompletos (caso Barrio R10). Verificado con `node --check`, prueba funcional `null` (13/13) y balance `<div>` 0. Ver `DECISIONS.md` ADR-029. **Pendiente de decisión de Dirección:** extender el mismo barrido a `evento3.html` (~6K líneas) y demás archivos públicos (`index`, `qr`, `registro`, `serie`, `evento`).
---

