---
name: reglas-de-oro
description: Puente a las Reglas de Oro v128 (Mandatos 1-18) y resumen de una linea por mandato. Cargar antes de una entrega formal o una auditoria.
---

# Reglas de Oro — Puente y Resumen

**Fuente única de verdad:** `Sistema QR desarrollo/Reglas de Oro QR.md` (v128-MASTER). Este archivo solo orienta: la norma completa, con su redacción literal e innegociable, vive en ese documento. Leerlo íntegro antes de una entrega formal, una auditoría (`@qa-auditor`/`@qa-auditor-free`) o cualquier intervención que toque datos, IDs o estética del Sistema QR Hostal Terraza.

Cualquier intervención de una IA ejecutora debe validarse contra los **18 mandatos incondicionales** bajo el framework AI-DOS v1.2.

## Resumen de una línea por Mandato

### I. Protocolos de Desarrollo y Datos (Cimiento)

1. **Prioridad Estructural (Data-First):** Fase I (IDs/atributos/Supabase + log TRACE positivo) certificada antes de Fase II (estética Afterglow/Geist 900).
2. **Cero Borrado e Integridad:** prohibido eliminar IDs lógicos (`#event-title`, `#db-lineup`, `#unified-frame`, ...); un módulo no usado queda con `display: none`; no se borran `<svg>` de iconos ni `<div>` indicadores.
3. **Masa Crítica y Segmentos:** toda entrega incluye el conteo exacto de líneas (justificar si baja del baseline ~300 de `evento3.html`) y, si es extensa, se fracciona en segmentos delimitados `// === INICIO SEGMENTO: [nombre] ===` / `// === FIN SEGMENTO: [nombre] ===`.
4. **Escudo de Auditoría GOLD:** latidos obligatorios en consola: INFO (módulos visibles), DEBUG (clase de ámbito `.tpl-{id}`), LINK (reglas CSS + bypass de caché `?v=timestamp`), TRACE (certificación cuantitativa), TIME (Heartbeat + Geist 900).

### II. Estándares Visuales y Multimedia (Cara)

5. **Sincronización Multimedia 1:1:** la playlist de Spotify cubre siempre el 100% de la altura del video (16:9).
6. **Protocolo Video YouTube (ADR-005):** prohibido `<iframe>` de YouTube en páginas públicas; extraer el ID y usar miniatura HD con link externo (evita el "Error 153" móvil).
7. **Silent Fallback y Transparencia Real (ADR-008):** toda `<img>` dinámica con `onerror="this.src='path/to/fallback.png';"`; no aplicar `invert`/`brightness` en logos sin canal alfa confirmado.
8. **Tratamiento No-Plano y Geist 900:** tarjetas técnicas (Dresscode, Aforo) con tipografía Geist 900 y drop-shadow (estándar $10,000).

### III. Gobernanza y Gestión de Silos (Ley de AI-DOS)

9. **Aislamiento Atómico (Scoped CSS):** todo el CSS del template encapsulado bajo `.tpl-{id}`; prohibido `:root` sin prefijo específico del silo.
10. **Diagramación vía Grid (f1 Standard):** módulos organizados exclusivamente con `grid-template-areas`; el HTML de `evento3.html` permanece inamovible.
11. **Integración de Proximidad Multimedia (ADR-010):** el módulo de video se declara con `padding-top: 0 !important` para integrarse con Countdown/Meta.
12. **Mandato Maestro de Actualización Documental (v126):** al actualizar documentos, revisar la versión existente, verificar/comparar sin perder historial y entregar el texto completo e íntegro en `.md`.

### IV. Fidelidad Visual y Armonía Cromática (v2.9)

13. **Armonización Cromática AI-DOS:** cálculo HSL obligatorio (prohibido hardcodear HEX fuera de las 7 armonías), ley 60-30-10, WCAG AA 4.5:1 y bypass de saturación (fondo bajo, acción alto).
14. **Calidad Móvil 2026 ($10,000):** Geist 900 obligatorio, micro-interacciones "Afterglow" (Impeller 2.0 a 120 FPS) y diseño nativo Thumb-first (no "responsivo reducido").
15. **Lógica de Negocio / Captura Pura:** soportar eventos "formulario" sin QR; la pantalla final muestra agradecimiento en lugar de ticket.
16. **Orquestador de Intención Contextual y Centinela Temporal:** creación de eventos en wizard de 4 pasos (Cimiento -> ADN -> Átomos -> Blindaje); en Campaña sin fecha se inyecta el centinela `2099-12-31` para desactivar el countdown.

### V. Gobernanza de Recursos (v128)

17. **Eficiencia de Recursos y Contexto:** costo = `turnos × contexto`; regla "un archivo, un lector"; verificación mecánica por script; regla anti-colgado; mutation testing acotado (5-8); prohibido leer archivos > 200 KB; el orquestador no absorbe; medición obligatoria y formato de informe de cierre. Detalle en la skill `eficiencia-recursos`.
18. **Consolidación de Fases y Agentes:** máx 1 exploración + 1 implementación por dominio + 1 verificación por sesión; no re-despachar un perfil que falló; presupuesto placeholder ~15M tokens / ~3 h sin justificación escrita en `NEXT.md`. Detalle en la skill `eficiencia-recursos`.

> Este documento constituye la Única Fuente de Verdad técnica y normativa de AI-DOS v1.2 para el Sistema QR Hostal Terraza.
