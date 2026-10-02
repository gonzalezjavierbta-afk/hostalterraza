---
doc: TEMPLATES.md — 10
version: v1.7.0 (heredada)
fecha: 2026-10-01
origen: AMPLIACION/TEMPLATES.md L307-337 (AMPLIACION/_backups/TEMPLATES.md.2026-10-01.bak)
version_previa: TEMPLATES.md v1.7.0
relacionados: [../TEMPLATES.md, ../../INDEX.md]
estado: vigente
estructura: detalle-v1 (2026-10-01)
---

> Capítulo de [TEMPLATES.md](../TEMPLATES.md) (hub normativo de silos). Texto original íntegro (L307-337 del original).

## 10. Verificación, Versionado y Cierre Documental (CHECKLIST de Aceptación)

> **Decisión de Dirección (zanjada):** un silo se declara "entregado" SOLO si aprueba el checklist completo de 10 puntos. El Escudo GOLD se ejecuta sobre el archivo REAL (ADR-006, Regla anti-absorción 4: ninguna entrega se da por completa sin verificación).

**CHECKLIST (10/10 obligatorios):**

| # | Punto | Verificación |
|---|---|---|
| (i) | **CSS válido + alcance** | Sintaxis CSS limpia (balance de llaves en 0) y TODO selector bajo `.tpl-fXX` / `.Tpl-FXX` (nada fuera del alcance del silo) |
| (ii) | **ASCII-safety** | **0 bytes > 127** en `css/templates/**/*.css` (escaneo de bytes). ⚠️ Alcance: aplica a `.css` y a `.js` de la entrega; los `.md` PUEDEN llevar acentos (los docs del Dossier no se incluyen en la verificación ASCII) |
| (iii) | **Doble notación completa** | Todo selector declarado en ambas variantes `.tpl-fXX, .Tpl-FXX` (casing mayúsculas y minúsculas — ver Cap. 8 punto 3) |
| (iv) | **Cero selectores fantasma** | Cada selector coincide con un nodo/clase REAL del DOM kernel de `evento.html` (grep previo; ERRORES §5/§8/§12) |
| (v) | **Cero Borrado verificado** | Diff de IDs: ningún `id=` del kernel fue removido del HTML (los módulos apagados se ocultan con `display:none !important`, no se borran) |
| (vi) | **Núcleo mínimo encendido** | Módulos del Cap. 6 visibles (hero, meta, ctas o justificado, descripción, form, footer) y **campaña apagada por defecto** (historia/objetivo/impacto con `display:none !important`, IDs intactos) |
| (vii) | **Accesibilidad** | Contraste WCAG AA ≥ 4.5:1 en texto; targets táctiles ≥ 48px; `@media (prefers-reduced-motion: reduce)` obligatorio; estados `:focus-visible` visibles |
| (viii) | **Smoke en producción** | `link` del silo responde 200 en producción; `body.className` contiene la doble clase (`.tpl-fXX .Tpl-FXX`); consola limpia sin errores del silo |
| (ix) | **Registro en admin + config_global intacto** | Tarjeta `.ld-theme-card` + `_THEME_TYPE` + `_THEME_TPL` registrados (Cap. 9) y `config_global` sin daños colaterales (ADR-040) |
| (x) | **Cero impacto colateral** | Sin endpoints nuevos, sin JS del kernel modificado, sin cambios en otros silos ni en `evento.html` |

Si algún punto falla, la entrega NO es completa: corregir y re-ejecutar el Escudo GOLD antes del cierre.

**Cierre documental (tras el checklist):**
1. **Log de versiones del silo:** fila nueva en el pie del propio CSS (ámbito documental del paquete).
2. **ADR de cierre:** ADR numerado en `DECISIONS.md` (ADR-041/042/043 como patrones) — incluye diagnóstico verificado contra el archivo real (ADR-006), Escudo GOLD PASS y deuda técnica aceptada.
3. **Registro en `ERRORES_HISTORICOS.md`:** si apareció una falla, BUG-XXX antes de cerrar.
4. **Ciclo documental (AI-DOS Cap. 9.9):** actualizar `TASKS.md` y `NEXT.md` (mandato maestro de actualización documental — Mandato 12 / Regla v126; nunca perder historial).

**ADRs citados:** ADR-031 (anti-absorción: verificación debe ejecutarse sobre el archivo real), ADR-006, ADR-029. **Reglas citadas:** Mandato 4, Mandato 12, Mandato 3 (segmentos si > 2000 líneas).

---

