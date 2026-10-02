---
doc: TEMPLATES.md — Anexo A
version: v1.7.0 (heredada)
fecha: 2026-10-01
origen: AMPLIACION/TEMPLATES.md L338-351 (AMPLIACION/_backups/TEMPLATES.md.2026-10-01.bak)
version_previa: TEMPLATES.md v1.7.0
relacionados: [../TEMPLATES.md, ../../INDEX.md]
estado: vigente
estructura: detalle-v1 (2026-10-01)
---

> Capítulo de [TEMPLATES.md](../TEMPLATES.md) (hub normativo de silos). Texto original íntegro (L338-351 del original).

## Anexo A. Registro de Versiones (del propio documento)

| vX.Y.Z | Fecha | Descripción |
|---|---|---|
| v1.0.0 | (previo) | Antecedente del hub (deuda de documentación detectada en TSK-016/017/018 y auditoría de silos) |
| v1.2.0 | 2026-09-16 | Creación del hub normativo TEMPLATES.md: 10 capítulos; baseline verificado contra código real (f10 v2.0.0, f11 v3.2.0, f9 ADR-041, kernel v222, admin cards, ADR-040/041/042/043) |
| v1.3.0 | 2026-09-16 | Correcciones de Dirección + Anexo C (inventario DOM real); nueva metodología de creación en 8 pasos (9-ter); brief obligatorio (9-bis); Cap. 10 como checklist de aceptación 10/10; doble notación de casing corregida; silos en disco reales; subconmutaciones JS reales del kernel |
| **v1.4.0** | **2026-09-22** | **Silo f12 "Kande" (ADR-048) + reconciliación estructural + corrección del registro.** Banner de reconciliación (al inicio): `evento.html` NO existe como archivo — el motor real es `evento-app.html` (1724 lineas, v214; `vercel.json` → `/api/evento-og`); `#db-gallery-grid` dentro de `#mod-video`; `#mod-hero-ctas` nace oculto; sin override `?tpl=`/`?cat=`; `MODULE_IDS` ausente en v214. Cap. 7: silo `f12.css` (Kande, v1.0.0) agregado a fiesta. Cap. 9 y Paso 8 (9-ter): registro corregido a los **6 puntos reales** con patrón `abrirFichaTheme` (cards, `_THEME_TYPE`, `_THEME_TPL`, `_THEME_MODULES` ADR-047 — 19 themes —, `_THEME_FICHA`, `names`) + advertencia de namespacing por categoria de `ld-mod-*` (defecto MAYOR ADR-048). Anexo B: filas de kernel real y f12; registro de themes actualizado. Anexo C: nota de la galería dentro de `#mod-video`. Nota de Cap. 2: `evento.html` se lee desde este ADR como `evento-app.html` (Cero Borrado: el texto previo se conserva intacto) |
| **v1.5.0** | **2026-09-23** | **Salvaguarda anti-solape del hero movil del silo f12 "Kande" (ciclo express v1.13.0 -> v1.13.3).** Cap. 5: nuevo bullet de patron recomendado — cuando el titulo del hero escala por ancho (`24vw`) hasta su tope (`11.5rem`) en la banda 481-767px, limitar el titulo por ALTURA (`clamp(3rem, min(24vw, calc(20vh - 4rem)), 11.5rem)`) y recortar el badge (`margin-top:3vh`) para evitar el solape titulo/cinta; no afecta telefonos (`<=480px`). **Cap. 4:** nota espejo en la molecula Hero que remite a esta regla del Cap. 5 (sin duplicar el texto). Evidencia real: `css/templates/fiesta/f12.css` L2217-2231; contexto en `TASKS.md` TSK-062/TSK-063 y `NEXT.md` hito -19 |
| **v1.6.0** | **2026-09-26** | **Silo f9b "Mistico Nocturno" (ADR-054/055/056) + AVISO NORMATIVO capital-T (ADR-057) + contrato de preview.** Banner nuevo tras la reconciliacion estructural: **la mitad `.Tpl-*` es codigo muerto en produccion** (el kernel solo emite `tpl-` minuscula; `f9b.css` = 369 vivos / 365 muertos). Cap. 7: ficha del silo `f9b` (2922 lineas, 17 modulos ON / 10 OFF, silo INDEPENDIENTE de f9 — ambos VIVOS, el reset de "cero brillo" de f9 NO se hereda) + nomenclatura con aviso. Cap. 8 punto 3: doble notacion corregida con la realidad medida; **punto 8 nuevo: contrato de vista previa `?preview=1` + `sessionStorage['ht_preview_payload']`, preview == produccion**. Anexo B: filas de f9b y preview. Evidencia real (ADR-006): `evento-app.html:998-1000`, `css/templates/fiesta/f9b.css`; contexto en `DECISIONS.md` ADR-054/055/056/057, `TASKS.md` (paquete f9b) y `NEXT.md` (hito -22) |
| **v1.7.0** | **2026-09-29** | **Excepción acotada ADR-060 (solo silo f9b) — salvedad de la norma "prohibido iframe" + registro del silo f9b v1.3.0.** Se **anexa** (sin reescribir la norma) la salvedad *"(excepto la excepción acotada ADR-060, solo silo f9b, click-to-play youtube-nocookie con fallback externo)"* en Cap. 4 (molecula Video), Cap. 8 punto 7 y Anexo C (`#mod-video`). Anexo B: fila del silo f9b actualizada a **v1.3.0** — video `#db-video-content` **full-bleed banner**, `#mod-hero-meta .meta-line` **centrada en todos los breakpoints**, y **click-to-play `youtube-nocookie` con fallback externo persistente** (excepción acotada ADR-060). Evidencia real (ADR-006): `css/templates/fiesta/f9b.css` v1.3.0 (`#mod-video > div:has(#db-video-content)` L1404-1405; banda full-bleed L1449; `.meta-line` L1099-1105), `evento-app.html:1440-1450` (`__ytInlinePlay`), `:1467` (gate token exacto), `:1474-1479` (placeholder f9b); contexto en `DECISIONS.md` ADR-060 (Nota de implementación R-060), `TASKS.md`/`NEXT.md` |

---

