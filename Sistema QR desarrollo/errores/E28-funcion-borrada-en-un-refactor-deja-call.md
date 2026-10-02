---
doc: E28 (ERRORES_HISTORICOS.md §28)
version: v1.8.0-STABLE (heredada)
fecha: 2026-10-01
origen: ERRORES_HISTORICOS.md L359-371 (AMPLIACION/_backups/ERRORES_HISTORICOS.md.2026-10-01.bak)
version_previa: ERRORES_HISTORICOS.md v1.8.0-STABLE
relacionados: [../ERRORES_HISTORICOS.md, ../INDEX.md]
estado: vigente
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [ERRORES_HISTORICOS.md](../ERRORES_HISTORICOS.md) §28 · [INDEX](../INDEX.md). Texto original íntegro debajo (L359-371 del original).

## 28. Funcion Borrada en un Refactor Deja Call Sites Huerfanos: `ReferenceError: openModInvitador is not defined` en `admin.html` (2026-10-01 - fix quirurgico de runtime)

### Una funcion eliminada en un refactor no avisa: los call sites siguen llamandola y el error solo aparece en runtime
* **Problema:** `admin.html` lanzaba en runtime `Uncaught (in promise) ReferenceError: openModInvitador is not defined at verQRLinkDirecto (admin.html:6985:3)`. La accion "Ver QR" del perfil de invitador (`verQRInvLink`) y el boton QR de cada link (`verQRLinkDirecto`) quedaban rotos: al pulsarlos, la promesa se rechazaba **sin abrir el modal** de QR de invitador. **No constaba** en este archivo (0 coincidencias de `openModInvitador`/`verQRLinkDirecto`/`verQRInvLink`): era un bug real y no documentado.
* **Causa raiz:** un refactor previo **elimino la definicion** de `openModInvitador` pero dejo **2 invocaciones huerfanas** (`verQRLinkDirecto` y `verQRInvLink`). El `ReferenceError` es la senal tardia de una **referencia muerta a una funcion borrada**: ni `node --check` ni el balance de divs ven un call site sin definicion, porque el parser valida sintaxis, no la resolucion de identificadores. Por eso el Escudo GOLD puede dar PASS con el bug de runtime vivo.
* **Fix (quirurgico, sin tocar `admin bacup.html`):** (1) **modal DOM nuevo `#mod-invitador`** (`admin.html:2550-2568`) con `#mod-inv-qr`, `#mod-inv-link` readonly y botones Copiar (`copyLink`, def L6685), Descargar (`descargarQRInvitador`) y Cerrar; (2) **funciones `openModInvitador`/`cerrarModInvitador`/`descargarQRInvitador`** (`admin.html:7801-7822`): el render usa `QrCreator.render` dentro de `try/catch` (fail-open a `textContent` del link, ADR-002/ADR-008) y la descarga reusa `_descargarQrAltaRes` (def L6425) -> PNG `qr-invitador-<codigo>.png`; (3) **guardas** `if (typeof openModInvitador !== 'function') return;` en `verQRLinkDirecto` (L7005) y `verQRInvLink` (L7010): si un futuro refactor vuelve a borrar la funcion, la accion **no se ejecuta** en vez de lanzar.
* **Blindaje / leccion:** (1) **toda funcion borrada en un refactor debe barrerse en busca de call sites**: los `onclick` inline y las llamadas por nombre son identificadores **no verificados por el parser**; el `ReferenceError` es su unica senal y llega en runtime (analogo a las secciones 18 y 26: los checks estaticos no ven la conexion/ausencia de un consumidor). (2) **El guard `typeof <fn> !== 'function'` es la red de seguridad recomendada** para call sites de funciones que pueden no estar cargadas; convierte un crash en un no-op (Silent Fallback, ADR-008). (3) **`node --check` NO cubre referencias muertas.** (4) **Un archivo de backup no hereda el fix.** Verificado: la definicion existia en `serie.html`/flujos equivalentes; en `admin.html` se perdio sin que ningun control lo detectara.
* **Verificacion (2026-10-01, ADR-006; working tree, SIN commit):** `git diff --stat admin.html` = **1 archivo, 45 insertions(+), 0 deletions(-)**; `admin.html` **11406 -> 11451** lineas. Balance de `<div>`: HEAD **1528/1525** -> working tree **1534/1531** = **+6/+6 balanceado** (el fix agrega 6 aperturas y 6 cierres; el desbalance baseline +3 se conserva, no es regresion). `node --check` 2/2 OK (los 2 bloques `<script>` inline). **0 bytes no-ASCII** en las regiones nuevas (modal L2550-2568, guardas L7005-7012, funciones L7801-7822). IDs nuevos unicos (`mod-invitador`, `mod-inv-qr`, `mod-inv-link`); `#mod-bg` intacto (Cero Borrado). Funcional: sin `ReferenceError` restante; API (`QrCreator`, `_descargarQrAltaRes`, `copyLink`) confirmada contra el archivo real.
* **Deuda registrada (no corregida por decision de alcance):** `admin bacup.html` conserva las mismas **2 llamadas huerfanas** (`verQRLinkDirecto` L4090 y `verQRInvLink` L4095) apuntando a `openModInvitador` **sin definicion** (0 definiciones en el archivo). Al ser un backup, el fix no se replico. Registrada como **TSK-095** en `TASKS.md` y en `NEXT.md` hito -34.
* **Estado de despliegue (2026-10-01):** el fix esta en el **working tree, SIN commit**.

---

