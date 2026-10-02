---
doc: TEMPLATES.md — 9-bis
version: v1.7.0 (heredada)
fecha: 2026-10-01
origen: AMPLIACION/TEMPLATES.md L260-276 (AMPLIACION/_backups/TEMPLATES.md.2026-10-01.bak)
version_previa: TEMPLATES.md v1.7.0
relacionados: [../TEMPLATES.md, ../../INDEX.md]
estado: vigente
estructura: detalle-v1 (2026-10-01)
---

> Capítulo de [TEMPLATES.md](../TEMPLATES.md) (hub normativo de silos). Texto original íntegro (L260-276 del original).

## 9-bis. Brief Obligatorio Antes de Escribir CSS

> **Decisión de Dirección (zanjada):** NINGUNA línea de CSS se escribe sin responder antes estas preguntas. La IA documenta las respuestas en la cabecera del silo (`# ====` bloque de versión) y en el ADR de cierre.

| # | Pregunta | Debe responder |
|---|---|---|
| 1 | **Dirección estética en una frase** | ¿Qué sensación y lenguaje visual? (ej. "Cyberpunk fosforescente neón sobre negro", ADR-042) |
| 2 | **Módulos a encender** | Lista concreta de `#mod-*` del Anexo C que quedan visibles (núcleo mínimo del Cap. 6 + extras justificados) |
| 3 | **Módulos a apagar** | Lista concreta de `#mod-*` que quedan con `display:none !important` (IDs INTACTOS = Cero Borrado) |
| 4 | **Paleta derivada o fija** | Derivada de `--master-accent` (por defecto, vía puente cromático del Cap. 8) o fija (excepción justificada en cabecera) |
| 5 | **Tipografía** | Familia(s) y pesos (prohibido `@import` de fuentes; usar system stack o Geist 900 si aplica Mandato 8) |
| 6 | **¿Requiere subconmutación JS?** | Si la respuesta es SÍ → **escalar al Plan**: es cambio de kernel de `evento.html`, no se implementa en la entrega del silo (POLÍTICA del Cap. 8 punto 6) |
| 7 | **¿Existe ya un silo con esa dirección?** | Si existe → NO duplicar: se ajusta el silo existente o se justifica el nuevo (consulta el listado del Cap. 7) |
| 8 | **Categoría y template_id definitivos** | `categoria_slug` y `template_id` reales que se registrarán en admin (Cap. 9) |

---

