---
doc: TEMPLATES.md — 5
version: v1.7.0 (heredada)
fecha: 2026-10-01
origen: AMPLIACION/TEMPLATES.md L139-161 (AMPLIACION/_backups/TEMPLATES.md.2026-10-01.bak)
version_previa: TEMPLATES.md v1.7.0
relacionados: [../TEMPLATES.md, ../../INDEX.md]
estado: vigente
estructura: detalle-v1 (2026-10-01)
---

> Capítulo de [TEMPLATES.md](../TEMPLATES.md) (hub normativo de silos). Texto original íntegro (L139-161 del original).

## 5. Breakpoints y Rejilla (Ley de Cortes)

> **Decisión de Dirección (zanjada, normativa para TODOS los silos):**

| Breakpoint | Uso |
|---|---|
| **640px** | Corte de tarjetas/columnas menores (móvil → tablet compacta) |
| **767px** | Corte móvil (colapsar hero y módulos; la corrección f11 v3.2.0 opera aquí, ERRORES §12) |
| **768px** | SOLO para `:has()` — no para layout general |
| **992px** | Corte intermedio estándar |
| **1279px** | Corte de escritorio (y banda 992-1279 propia de escritorio compacto) |
| **480px** | Opcional (territorio móvil pequeño), no obligatorio |

- **Mobile-first:** se diseña el estado base móvil y se perfecciona hacia arriba con `min-width`. Prohibido concebir el móvil como "responsivo reducido" (Mandato 14).
- La banda **992px-1279px** debe recibir tratamiento explícito (f11 la mantiene intacta: `breakpoint 992-1279px intacto` en ADR-043).
- **Regla Edge-to-Edge:** todo cambio de layout en un breakpoint debe tener alcance definido; una regla sin media query que rompe desktop fue error histórico (ERRORES §5).
- El orden de hermanos en columnas flex se controla con `order` COMPLETO (renumerar todos los hermanos, no reordenar parcialmente — ERRORES §12, f11 v3.2.0).
- **Patron recomendado — salvaguarda por ALTURA en bandas anchas (silo f12 "Kande", v1.13.3, 2026-09-23):** cuando el titulo del hero escala por ANCHO (`24vw`) hasta su tope (`11.5rem`) en anchos de tablet/landscape (**481-767px**) y la cinta de subtitulo (`#mod-hero::before`, al `bottom:67%`) + el badge de ceja (`#org-name-badge`, `margin-top:5vh`) se acercan, titulo y cinta pueden solaparse. Mitigacion normativa: limitar el titulo por **ALTURA** con `min()` en una media query de banda ancha — `--f12-title-size: clamp(3rem, min(24vw, calc(20vh - 4rem)), 11.5rem)` — y recortar el badge (`margin-top:3vh !important`), todo dentro de `@media (min-width:481px) and (max-width:767px)`; los telefonos (`<=480px`) NO se afectan. **Regla general:** cuando un hero usa tamaño tipografico por ancho y toca su tope, validar el caso por ALTURA en la banda ancha (evita el solape titulo/cinta en tablets verticales y landscape extremo). Evidencia real: `css/templates/fiesta/f12.css` L2217-2231; contexto del ciclo express v1.13.0 -> v1.13.3 en `TASKS.md` (TSK-062) y `NEXT.md` (hito -19).

**ADRs citados:** ADR-043. **Errores históricos:** §5 (edge-to-edge), §7 (brecha entre breakpoint de layout y de seguridad), §12 (orden flexbox incompleto f11).

---

