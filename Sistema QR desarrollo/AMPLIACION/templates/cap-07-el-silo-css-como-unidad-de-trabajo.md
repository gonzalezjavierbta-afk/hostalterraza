---
doc: TEMPLATES.md — 7
version: v1.7.0 (heredada)
fecha: 2026-10-01
origen: AMPLIACION/TEMPLATES.md L181-207 (AMPLIACION/_backups/TEMPLATES.md.2026-10-01.bak)
version_previa: TEMPLATES.md v1.7.0
relacionados: [../TEMPLATES.md, ../../INDEX.md]
estado: vigente
estructura: detalle-v1 (2026-10-01)
---

> Capítulo de [TEMPLATES.md](../TEMPLATES.md) (hub normativo de silos). Texto original íntegro (L181-207 del original).

## 7. El Silo CSS como Unidad de Trabajo

> **Decisión de Dirección (zanjada):** un "silo" es la unidad atómica de estilo. Definición operativa:

- **Qué es:** archivo CSS autocontenido por template en `css/templates/{categoria}/{id}.css`.
- **Qué hace:** estiliza los módulos del kernel de `evento.html` **sin tocarlo** (HTML inamovible — Mandato 10; Aislamiento Atómico — Mandato 9).
- **Nomenclatura:** `.tpl-{id}` / `.Tpl-{id}` (el hub documenta la doble notación como norma; ⚠️ **ver el AVISO NORMATIVO de arriba: hoy solo la mitad `.tpl-*` aplica en produccion — la mitad `.Tpl-*` es código muerto, ADR-057**). Ejemplos reales verificados: `.tpl-f8`/`.Tpl-F8` (TropiLove), `.tpl-f9`/`.Tpl-F9` (Místico), `.tpl-f9b`/`.Tpl-F9b` (**Místico Nocturno, ADR-054**), `.tpl-f10`/`.Tpl-F10` (Rico/Cyberpunk Fosforescente), `.tpl-f11`/`.Tpl-F11` (Cyberpunk Fosforescente, ADR-043), `.tpl-f12`/`.Tpl-F12` (**Kande, ADR-048**).
- **Silos en disco (verificado 2026-09-16 con glob sobre `css/templates/`; f12 agregado 2026-09-22 ADR-048; f9b agregado 2026-09-26 ADR-054):**
  - **fiesta:** f1, f3, f5, f6, f7, f8, f9, **f9b**, f10, f11, f12 → archivos `f1.css`, `f3.css`, `f5.css`, `f6.css`, `f7.css`, `f8.css` (TropiLove), `f9.css` (Místico, ADR-041), **`f9b.css` (Místico Nocturno, ADR-054, v1.0.0 — 2922 lineas, parallax premium, paleta dorada calida, profundidad suave; 17 modulos ON / 10 OFF; silo NUEVO e INDEPENDIENTE de f9, no una variante)**, `f10.css` (Rico, ADR-042 v2.0.0), `f11.css` (Cyberpunk Fosforescente, ADR-043/044, v3.3.3), `f12.css` (**Kande, ADR-048, v1.0.0 — Tropical Noir Brutalista**).
  - **campaña:** b2, b3, b4, b5 → `b2.css`, `b3.css`, `b4.css`, `b5.css` (silo campaña; contiene los átomos de campaña `#mod-impacto-historico`, `#mod-mapa-crisis`, `#mod-como-ayudar`).
  - **cine:** c1, c4 → `c1.css`, `c4opencode.css`.
  - ⚠️ **Documentados pero SIN archivo real en disco:** f2, c2, b1 — NO crear silos que los referencien; si un template_id los pide, escalar al Plan.
  - ⚠️ Discrepancia conocida adicional: `.tpl-f6` y `.tpl-f8` son silos activos en CSS pero no aparecen en la lista de PROJECT.md (documentado en AGENTS.md — no es bug).
- **Carpeta de silos:** cada template_id tiene su carpeta por categoría: `css/templates/fiesta/` (f9, f9b, f10, f11, f12), `css/templates/` por categoría (cine, campana, hosteleria…).

**Ficha del silo f9b "Mistico Nocturno" (ADR-054, v1.0.0, template_id `f9b`, categoria `fiesta`, theme `mistico-nocturno`):**
- **Identidad / direccion estetica:** dorado antiguo sobre negro, con **profundidad suave** en vez de plano (hero editorial de dos lineas de meta). **Es un silo NUEVO e INDEPENDIENTE de `f9` "Mistico", NO una variante ni un sustituto: `f9` y `f9b` son dos silos DISTINTOS y AMBOS VIVOS** (`f9` sostiene el evento `rico-5mw5` en produccion; `f9.css` NO se toco en ningun byte). Justificacion de la ruptura (pregunta 7 del Brief, Cap. 9-bis): `f9` es "PLANO y ELEGANTE, cero glow" (anula `text-shadow`/`box-shadow`/`filter`/`backdrop-filter: none !important`); **`f9b` rompe esa regla a proposito** admitiendo sombras suaves y profundidad. **El reset de "cero brillo" de `f9` NO se hereda en `f9b`** (se ELIMINO, no se renombro): el freno de brillo se traslada a tokens de opacidad baja (`--f9b-shadow-1/2/3`, `--f9b-elev-1/2/3`, `--f9b-glow`); **prohibido "repararlo" reintroduciendo un `none !important` global**. La paleta oro calida se hereda de `f9` con prefijo `--f9b-*` y los MISMOS valores.
- **Modulos ON (17):** `#mod-hero`, `#unified-frame`, `#mod-hero-meta`, `#mod-hero-ctas`, `#mod-descripcion`, `#mod-lineup`, `#mod-video`, `#mod-cartel`, `#mod-playlist`, `#mod-faq`, `#mod-ubicacion`, `#mod-boletos`, `#mod-experiencias`, `#mod-whatsapp`, `#mod-sponsors`, `#mod-form`, `#mod-footer`.
- **Modulos OFF (10):** `#mod-historia`, `#mod-objetivo`, `#mod-impacto`, `#mod-info-tecnica` (los 4 de campana/narrativa, con **TODO su CSS conservado** y apagados en la seccion 2.1 de `f9b.css`) + `#mod-equipo`, `#db-equipo-grid`, `#mod-cta-final`, `#db-cta-final-titulo`, `#db-cta-final-subtitulo`, `#cta-final-btn` (verificados OFF sin diseno). **IDs INTACTOS en el DOM (Cero Borrado, Mandato 2).** La lista ON **NO PUEDE CRECER sin un ADR nuevo** (frontera dura, Cap. 8 punto 6 / ADR-054 decision 5).
- **Canal de efectos (ADR-055):** el silo implementa las 5 clases de cuerpo (`fx-explicit`, `fx-grain`, `fx-glow`, `fx-vhs`, `fx-parallax`); **parallax ON por defecto** en `f9b` (el resto OFF). `admin.html` fija esos defaults al elegir el theme `mistico-nocturno` (`_aplicarPresetTheme`, ADR-055 R8).

**Entregables:** cabecera vX.Y.Z; log de versiones en el pie; diff de selectores usados vs DOM kernel; identificación de la categoría y el template_id real registrado en `admin.html` (Cap. 9).

**ADRs citados:** ADR-041, ADR-042, ADR-043, ADR-031, **ADR-054 / ADR-055 / ADR-056 / ADR-057 (silo f9b + canal de efectos + consolidacion + capital-T)**. **Errores históricos:** §5, §8, §12, **§14/§15 (f9b: clon muerto por scope; IDs duplicados de patrocinadores; efectos sin consumidor; ADR con valores desincronizados)**.

---

