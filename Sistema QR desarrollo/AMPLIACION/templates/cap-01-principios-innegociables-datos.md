---
doc: TEMPLATES.md — 1
version: v1.7.0 (heredada)
fecha: 2026-10-01
origen: AMPLIACION/TEMPLATES.md L51-70 (AMPLIACION/_backups/TEMPLATES.md.2026-10-01.bak)
version_previa: TEMPLATES.md v1.7.0
relacionados: [../TEMPLATES.md, ../../INDEX.md]
estado: vigente
estructura: detalle-v1 (2026-10-01)
---

> Capítulo de [TEMPLATES.md](../TEMPLATES.md) (hub normativo de silos). Texto original íntegro (L51-70 del original).

## 1. Principios Innegociables (DATOS)

> **Decisión de Dirección (zanjada):** los cinco pilares de abajo son innegociables en toda entrega de silo. Ninguna tarea de silo se declara completa sin cumplirlos.

1. **Mandato de Prioridad Estructural (Data-First):** toda tarea se divide en FASE I (Cimiento: mapeo de IDs del Contrato v112, inyección física de atributos `onclick` y flujo Supabase) y FASE II (Estética/Afterglow/Geist 900). **FASE II solo tras un log TRACE positivo** de FASE I (Mandato 1 de Reglas de Oro QR.md).
2. **Protocolo de "Cero Borrado" (STRICT):** prohibido eliminar IDs lógicos del Contrato v112 (`#event-title`, `#unified-frame`, `#mod-form`, etc.). Si un módulo no se usa, permanece con `display: none`. Tampoco se eliminan `<svg>` de iconos técnicos ni `<div>` indicadores (Mandato 2; ERRORES §1).
3. **Espejo exacto del DOM kernel:** los selectores del silo deben apuntar SOLO a IDs/clases que el kernel de `evento.html` genera realmente. Prohibidos selectores propietarios inventados (ver Cap. 3 y ERRORES §5/§8/§12).
4. **ASCII-safety formal:** todo `css/templates/**/*.css` se entrega con **0 bytes > 127** (chequeo de bytes, no de charset). Todo código JS embebido: `node --check` limpio (Escudo GOLD).
5. **Aislamiento Atómico (Scoped CSS):** todo el CSS del silo encapsulado bajo `.tpl-{id}` (y su variante `.Tpl-{id}` que el kernel duplica en `body`). Prohibido escribir en `:root` global variables sin prefijo del silo. Prohibido estilar selectores fuera del alcance del silo (Mandato 9).

| Entregables | Evidencia |
|---|---|
| Mapeo de IDs usado (FASE I) | Log TRACE en consola del orquestador |
| Escudo GOLD (node --check + ASCII + balance divs) | Reporte de `gold-shield` |
| Cero regresiones al Contrato v112 | Diff sin borrado de IDs |

**Silos involucrados:** todos (f1-f12).

---

