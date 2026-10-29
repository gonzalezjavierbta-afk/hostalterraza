---
doc: E32 (ERRORES_HISTORICOS.md 32)
version: v1.8.0-STABLE (heredada)
fecha: 2026-10-29
origen: ERRORES_HISTORICOS.md seccion 32 (nueva, 2026-10-29). Incidente de nombre ocupado: `css/templates/fiesta/f14.css` existia como volcado de HTML+Tailwind y no como silo CSS.
relacionados: [../ERRORES_HISTORICOS.md, ../INDEX.md, ../DECISIONS.md, ../decisiones/ADR-082-silo-f14-vinilos-inversos-kernel-y-contrato-boletos-link.md]
estado: resuelto (2026-10-29)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [ERRORES_HISTORICOS.md](../ERRORES_HISTORICOS.md) seccion 32 - [INDEX](../INDEX.md).

## 32. Nombre de Silo Ocupado por un Volcado de HTML (2026-10-29 - ADR-082)

> Resuelto en el mismo ciclo que entrego ADR-082. Guard de regresion: `scripts/smoke_f14_vinilos.js` (33 asserts), que entre otras cosas rechaza un `f14.css` cuyo contenido inicial sea `<!DOCTYPE`/`<html>`/`tailwind`.

### A. Que paso

* **Problema:** `css/templates/fiesta/f14.css` contenia **38.082 bytes de HTML + Tailwind** (`<!DOCTYPE html>` en la linea 1, `<link>` a Google Fonts, `<script>` inline, 109 bytes > 127). El kernel inyecta ese archivo como hoja de estilos cuando un evento tiene `template_id='f14'` (`evento-app.html:761`), asi que el silo existia **de nombre** pero no renderizaba: cualquier evento apuntado a `f14` habria caido al estilo base sin error visible.
* **Impacto real:** **cero**, porque ningun evento usaba `template_id='f14'`. El defecto estaba latente, no activo.
* **Deteccion:** la exploracion previa a crear el silo (`@explore`) reporto el archivo como bloqueador; se verifico con `Select-String '<!DOCTYPE'` y conteo de `.tpl-` (0 ocurrencias).

### B. Como se resolvio

* Backup del volcado a `css/templates/fiesta/f14-volcado-tailwind.bak.css` (38.082 bytes, Cero Borrado) y escritura del silo real en `f14.css` (40.075 bytes, 0 bytes > 127, 143 reglas, 100% scopeado bajo `.tpl-f14`/`.Tpl-F14`).

### C. Lecciones

1. **Un nombre de archivo no certifica un silo: lo certifica su contenido scopeado.** Un `f14.css` valido debe tener selectores `.tpl-f14`/`.Tpl-F14`; si empieza con `<!DOCTYPE`, no es un silo aunque ocupe el nombre correcto.
2. **El guardian debe expresar el invariante, no la existencia del archivo.** Por eso el smoke de f14 no se limita a comprobar que el archivo exista: valida scope, tokens, ASCII y ausencia de `@import`/`@font-face` reales.
3. **Antes de crear un silo `fN`, se audita que `fN.css` sea realmente CSS.** Un id "libre" en el catalogo de admin no implica un archivo sano en disco.
4. **El respaldo se conserva.** El volcado era inservible como silo, pero podia contener decisiones de diseno del prototipo; se archiva en lugar de borrarse (Oro #2).
