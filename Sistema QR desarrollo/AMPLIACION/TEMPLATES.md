# 🎨 TEMPLATES.md — Hub Normativo de Silos Visuales (evento.html)

| Campo | Valor |
|---|---|
| **Versión** | v1.6.0 |
| **Propósito** | Hub normativo de silos CSS de `evento.html` (motor real: `evento-app.html`, ver banner de reconciliacion abajo): inventario real del DOM, metodologia de creacion en 8 pasos y brief obligatorio - para que cualquier IA cree, edite o audite un template de forma reproducible. |
| **Fecha** | 2026-09-16 (v1.3.0) · **2026-09-22 (v1.4.0)** · **2026-09-23 (v1.5.0, salvaguarda hero movil f12)** · **2026-09-26 (v1.6.0, silo f9b + aviso capital-T + contrato de preview — ver Anexo A)** |
| **Audiencia** | `@frontend-tpl-free`, `@frontend-tpl`, `@free-build`, `@admin-dev-free`, `@docs-keeper-free`, `@qa-auditor` |
| **Marco** | MOTHER, AI-DOS v1.2, 16 Mandatos de `Reglas de Oro QR.md` (v127-MASTER) |
| **Baseline de verdad** | Archivos REALES del repositorio (ADR-006). Ningún dato citado aquí se dio por supuesto; todo se verificó contra `evento-app.html` (motor real, reconciliado 2026-09-22), `css/templates/**`, `admin.html` y los docs del Dossier. |
| **Estado** | ACTIVE |

---

> ## ⚠️ RECONCILIACION ESTRUCTURAL (2026-09-22, ADR-006 / ADR-048) — `evento.html` NO existe como archivo
>
> El archivo **`evento.html` NO existe** en el repositorio (`Test-Path` = False). El **motor publico real es `evento-app.html`** (1724 lineas, titulo "Master Orchestrator v214"): `vercel.json` reescribe la ruta `/evento.html` hacia `/api/evento-og.js`, y ese endpoint sirve `evento-app.html`. Evidencia verificada en `evento-app.html` real: `injectAtomicCSS(cat, tplId)` **L598-638** construye `css/templates/{categoria}/{template_id}.css?v=${Date.now()}` (L600-601) y **L691-693** aplica la doble clase `tpl-{template_id}` + `tpl-{lowercase}` al `body`.
>
> **Otros hechos del kernel real verificados (ADR-006):**
> - `#db-gallery-grid` (L148) esta **DENTRO** de `#mod-video` (L147) — apagar `#mod-video` oculta tambien la galeria.
> - `#mod-hero-ctas` nace con `display:none !important` (L33) y exige encendido explicito via CSS del silo.
> - NO existe override `?tpl=`/`?cat=` en el kernel real (solo existe en `evento2.html`, legado).
> - El array `MODULE_IDS` **ya no existe** en el kernel v214 (0 ocurrencias case-sensitive; solo en legados).
>
> **Politica documental:** todas las citas a `evento.html` como archivo/unico motor que existen en este documento (y en `PROJECT.md`, `BLUEPRINT.md`, `AGENTS.md`, hitos de `NEXT.md`, TSK-016/017/018) se conservan **intactas (Cero Borrado)** y se interpretan desde aqui como el link publico `/evento.html` reescrito por Vercel hacia el motor real `evento-app.html`. Ver `DECISIONS.md` **ADR-048** (Seccion Hallazgo estructural) y `PROJECT.md` Seccion 6.

---

> ## ⚠️ AVISO NORMATIVO NUEVO (2026-09-26, `@docs-keeper` / ADR-057) — La mitad `.Tpl-*` es CODIGO MUERTO en produccion
>
> **Hecho verificado (ADR-006):** el kernel real **NUNCA emite `Tpl-`**. Escribe en `document.body` SIEMPRE `tpl-` + `template_id` tal cual + su version en minuscula (**`evento-app.html:998-1000`**: `const tplNormal = \`tpl-${ev.template_id || 'F3'}\`; const tplLower = \`tpl-${(ev.template_id || 'f3').toLowerCase()}\`; document.body.className = \`${tplNormal} ${tplLower}\``). Con `template_id='f9b'` el body queda **`tpl-f9b tpl-f9b`** (ambas clases identicas); con `template_id='Mistico'` quedaria `tpl-Mistico tpl-mistico`. La unica coincidencia case-sensitive de `Tpl-` en `evento-app.html` es **un comentario** (`:760`).
>
> **Consecuencia para TODOS los silos (no solo f9b):** la mitad `.Tpl-{id}` de cada silo **no aplica nunca** en produccion. La convencion de doble notacion `.tpl-{id}` + `.Tpl-{id}` (Cap. 8 punto 3) **se mantiene como norma por Cero Borrado** (no se retira texto), pero **se anexa este aviso**: los silos nuevos **NO deben duplicar la mitad `.Tpl-*` a ciegas** hasta que el ADR-057 se resuelva. Ejemplo medido: `f9b.css` (2922 lineas) tiene **369 `.tpl-f9b` (vivos) + 365 `.Tpl-F9b` (muertos)**; el silo se sostiene **solo** por la mitad minuscula.
>
> **Decision de Direccion (ADR-057, 2026-09-26):** (1) **el preview se alineo a produccion** (el adaptador `?preview=1` pasa el `template_id` sin capitalizar; `preview == produccion`); (2) la **correccion global** (eliminar la mitad muerta de los silos **o** cambiar el kernel a `Tpl-` canonico) **se difiere a una tarea propia con regresion de 7 silos** y queda **ABIERTA** con sus dos opciones y su riesgo. Ver `DECISIONS.md` **ADR-057** y `TASKS.md` (tarea de correccion global).
>
> **Regla para agentes:** al auditar o crear un silo, (a) NO reportar como "selector muerto" la mitad `.Tpl-*` (es una deuda conocida, no un defecto del silo); (b) NUNCA borrar la mitad `.tpl-*` (es la unica viva); (c) no confiar en que la doble notacion garantiza cobertura — verificar con `grep` que exista la mitad minuscula para cada selector.

---

---

## 0. Cómo usar este documento

Este documento es la **única puerta de entrada** para crear, modificar o documentar un silo visual de `evento.html`. Antes de tocar un CSS de silo, ejecuta los pasos del **workspace `silk`**: leer las Reglas de Oro, `ERRORES_HISTORICOS.md`, `DECISIONS.md`, revisar `evento.html` y `f10.css` (silo canónico v2.0.0) si la tarea es de Fase II, y confirmar que el mapeo de IDs del contrato (Cap. 2) esté certificado antes de abrir el silo.

**Estructura del documento:** 10 capítulos normativos + 2 secciones de flujo (9-bis Brief, 9-ter Metodología en 8 pasos), cada uno con su Decisión de Dirección (zanjada, innegociable), Entregables, Reglas de Oro citadas, ADRs citados y Errores históricos citados. El orden de lectura es lineal: los capítulos 1-4 construyen los fundamentos; los capítulos 5-7 detallan la mecánica del silo; 9-bis/9-ter dan el flujo de creación; los capítulos 8-10 cierran el ciclo (inyección, admin, verificación).

---

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

## 2. Contrato de Datos v112 y la Realidad del DOM (21 Átomos vs 81 IDs)

> **Decisión de Dirección (zanjada):** el Contrato de Datos vigente es **v112 / 21 Átomos Soberanos** (BLUEPRINT.md v1.6.2, Sección 4). Se tratan como inamovibles. PERO el archivo real `evento.html` es **"Master Orchestrator v214"** con comentarios internos hasta v222 y **~81 IDs** propios más `unified-frame` y `#mod-*`. Se deja v112 como línea base de validación y se documenta la brecha como **discrepancia conocida**, no como bug.

⚠️ **ADVERTENCIA CRÍTICA (ADR-006 / AGENTS.md):** solo **8 de los 21 Átomos** existen hoy con su id exacto vendido en BLUEPRINT (`event-title`, `meta-fecha`, `meta-hora`, `meta-lugar`, `mod-video`, `mod-lineup`, `mod-ubicacion`, `mod-form`). Los 12 "faltantes" (`mod-galeria`, `mod-patrocinadores`, `mod-entradas`, `mod-faqs`, `mod-contacto`, `mod-reglas`, `mod-itinerario`, `mod-redes`, `mod-comentarios`, `mod-encuesta`, `mod-descargas`, `mod-sponsors-vip`, `mod-actualizaciones`) fueron **renombrados o reestructurados** en v214+ — `#mod-hero`, `#mod-historia`, `#mod-objetivo`, `#mod-equipo`, `#mod-experiencias`, `#mod-cartel`, `#mod-playlist`, `#mod-whatsapp`, `#mod-cta-final`, `#mod-info-tecnica`, `#mod-footer`, `#mod-boletos`, `#mod-faq`, `#mod-sponsors`, entre otros. **`event-description` no existe en ninguna forma** (`#mod-descripcion` fue creado como átomo nuevo en ADR-041, silo f9).

**Regla práctica:** NO reportes como "faltante" ni "bug" ninguno de los 12 átomos clásicos ausentes. Antes de tocar un selector, verifica contra `evento.html` real con `grep` (ADR-006). Si un módulo fue renombrado, usa el nombre real del DOM.

> **NOTA de reconciliacion (ADR-048, 2026-09-22):** el archivo real descrito en este capitulo como `evento.html` es en el repositorio **`evento-app.html`** (1724 lineas, "Master Orchestrator v214" — ver banner al inicio del documento). La ruta publica `/evento.html` la reescribe `vercel.json` hacia `/api/evento-og`, que sirve `evento-app.html`. Ademas, verificado en `evento-app.html`: `#db-gallery-grid` (L148) vive **DENTRO** de `#mod-video` (L147) — apagar `#mod-video` oculta la galeria; `#mod-hero-ctas` (L84) nace con `display:none !important` (L33) y exige encendido explicito.

| Entregables | Evidencia |
|---|---|
| Lista de IDs kernel que el silo estiliza | grep de `id=` en `evento-app.html` |
| Átomos del contrato realmente presentes | Comparativa 21 vs ~81 (reporte) |
| Justificación si un átomo clásico no aplica | Anexo de ADR del silo |

**Reglas de Oro citadas:** Mandato 1 (Data-First), Mandato 2 (Cero Borrado). **ADRs:** ADR-006 (veracidad), ADR-011 (dual-phase; aplica a Cero Borrado de módulos). **Errores históricos:** §1 (violación v100-v104), §7 (comentario que no reflejaba el código).

---

## 3. Estructura del Silo (8 Pilares Técnicos)

> **Decisión de Dirección (zanjada):** un "silo" es un archivo `css/templates/{categoria}/{id}.css` autocontenido, montado por el kernel vía `<link data-template-css>` y `injectAtomicCSS`. El silo canónico de referencia es **`f10.css` v2.0.0 (ADR-042)**. Soft-limit: **~2000 líneas por silo** (si se excede, justificar por segmentos — Mandato 3).

Los 8 pilares que todo silo debe cumplir:

| # | Pilar | Requisito |
|---|---|---|
| 1 | Cabecera de versión | Bloque `# ====` con nombre del silo, vX.Y.Z, estado (p.ej. `v2.0.1 NEON TRIADA` en f10) |
| 2 | Log de versiones en el pie | Tabla `| vX.Y.Z | Fecha | Autor | Descripción |` actualizada en cada entrega (ámbito documental del paquete) |
| 3 | Alcance atómico | Todo selector con prefijo `.tpl-f{id}` o `.Tpl-F{id}` (kernel escribe AMBAS clases en `body.className`; mandato de Aislamiento Atómico) |
| 4 | Cero selectores muertos | Cada selector debe coincidir con un nodo real del DOM kernel de `evento.html` (ADR-006; ERRORES §5/§8/§12) |
| 5 | Grid por áreas | Layout de módulos con `grid-template-areas` sobre el HTML inamovible (Mandato 10) |
| 6 | Fallback de assets | `onerror="this.src='...'"` (Silent Fallback ADR-008) y prohibido `invert`/`brightness` en logos sin alfa |
| 7 | Paleta por armonía HSL | Colores nacen de armonía matemática HSL (60-30-10; contraste WCAG AA 4.5:1; Mandato 13 "Regla #9") — nunca hex hardcodeado fuera de armonía |
| 8 | Mobile nativo | Diseñado móvil-first con breakpoints normativos (Cap. 5); Afterglow/120 FPS (Mandato 14 "Regla #10") |

**Deuda técnica aceptada:** en ADR-041 se aceptaron hallazgos H-3/H-4 como deuda (TSK-031). Cualquier pilar incumplido nuevo debe registrarse en el ADR del silo, no silenciarse.

**ADRs citados:** ADR-041, ADR-042, ADR-043, ADR-008, ADR-010. **Errores históricos:** §5 (selectores fantasma f1 v2.1.0-v2.3.0; edge-to-edge sin breakpoint), §8 (columnas documentadas nunca escritas por el INSERT), §12 (f11 hero mobile v3.2.0).

---

## 4. Arquitectura Molecular (Átomos de UI del Silo)

> **Decisión de Dirección (zanjada):** el silo se compone de componentes moleculares estándar, definidos con variables prefijadas del silo (`--f10-*`, `--f9-*`, etc.), nunca en `:root` global (prohibido por Mandato 9).

Moléculas que cada silo puede declarar (y las clases kernel reales que estilizan):

| Molécula | Selectores kernel reales (verificados) | Notas |
|---|---|---|
| **Hero** | `#mod-hero`, `#mod-hero-meta` (meta en 2 líneas ok, ADR-041), `#mod-hero-ctas` | `#mod-hero-ctas` nace con `display:none` y solo lo enciende `tpl-f6` por contrato; en silos que lo usan debe liberarse |
| **Countdown** | `#unified-frame` + `#cd-days/#cd-hours/#cd-mins/#cd-secs` | Mismo frame que el video; Mandato 5 (sincronización 1:1) |
| **Video** | `#mod-video` (miniature HD, ADR-005, prohibido iframe) | `padding-top: 0 !important` si se integra con el bloque superior (ADR-010) |
| **Lineup** | `.artist-card`, `.artist-photo`, `.artist-overlay`, `.artist-name`, `.artist-hora`, `.artist-resena`, `.artist-social`, `.artist-social-icon`, `.artist-card.headliner` | Selectores kernel de f8/f9/f10 (ADR-042: f10 v1 estilizaba `.f10-lc-*` inexistentes → reescritura) |
| **Galería** | `#db-gallery-grid` + `.gallery-item` | N abierto de espacios (nth-child cíclico prohibido, ADR-042) |
| **Boletos** | `#mod-boletos` + `.boleto-card-row` (con `.boleto-icon`, `.boleto-tipo`, `.boleto-precio`, `.boleto-desc`, `.boleto-arrow`) | Clase real generada por el kernel JS (≈L1522-1542); prohibido pintar "POR DEFINIR" (ADR-041); tarifas reales |
| **Form / CTA** | `#mod-form`, `#unified-frame`, `#mod-whatsapp`, `#mod-cta-final` | Botón WhatsApp sin el número visible en el texto (ADR-041) |
| **Footer** | `#mod-footer`, `#mod-info-tecnica` | Datos técnicos con tipografía Geist 900 + drop-shadow (Mandato 8) |

> **Nota de salvaguarda (molecula Hero):** si el hero escala el titulo por ANCHO (`vw`) hasta su tope, validar el caso por **ALTURA** en bandas anchas (tablet/landscape) para evitar el solape titulo/cinta — ver la regla del **Cap. 5** (patron recomendado de salvaguarda por ALTURA, silo f12 v1.13.3) y la evidencia real `css/templates/fiesta/f12.css` L2217-2231. No duplicar aqui el texto completo.

**Entregables:** declaración de variables del silo; lista de moléculas usadas con sus clases kernel reales; vista previa del log TRACE de FASE I.

**Reglas de Oro citadas:** Mandato 5, 6, 7, 8, 10, 13 ("Regla #9"), 14 ("Regla #10"). **ADRs:** ADR-005, ADR-008, ADR-010, ADR-011, ADR-041, ADR-042.

---

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

## 6. Módulos Funcionales (Núcleo Mínimo Encendido)

> **Decisión de Dirección (zanjada):** todo silo debe dejar encendidos como mínimo estos módulos, salvo justificación explícita por línea de negocio (evento de captura pura, campaña, prelanzamiento):

1. `#mod-hero` (título)
2. `#mod-hero-meta` (metadata)
3. `#mod-hero-ctas` (llamados a la acción) **o apagado con justificación**
4. Descripción — `#mod-descripcion` (átomo nuevo ADR-041) o el módulo que aporte el texto descriptivo del evento
5. `#mod-form` (formulario de inscripción)
6. `#mod-footer` (cierre)

- La **campaña** (módulos de historia/objetivo/impacto) nace **apagada por defecto** (`display:none`); solo se enciende cuando el silo la declara explícitamente.
- En eventos de **captura pura** (Mandato 15 "Regla #11"), la pantalla final muestra mensaje de éxito/agradecimiento en lugar de ticket QR.
- **Fecha centinela** `2099-12-31` desactiva el countdown público en campañas (Mandato 16 "Regla #12").

**ADRs citados:** ADR-015 (contrato de campos), ADR-013 (átomo actualizaciones), ADR-041. **Reglas citadas:** Mandatos 15 y 16.

---

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

## 8. Inyección y Puente Cromático (Cómo se Monta el Silo)

> **Decisión de Dirección (zanjada):** el silo NO se monta por hoja `<link>` estática en el HTML; lo inyecta el kernel de `evento.html` en runtime. Documentado del código REAL (ADR-006):

> **NOTA de reconciliacion (ADR-048, 2026-09-22):** los numeros de linea de este capitulo (L598-638, L677-681, L692-694, L701-752) corresponden al archivo real **`evento-app.html`** (motor publico; `evento.html` no existe como archivo — ver banner del documento). El texto original se conserva intacto (Cero Borrado); desde este ADR todo `evento.html` kernel se lee como `evento-app.html`.

1. **Propósito:** `injectAtomicCSS(cat, tplId)` (≈`evento.html` L598-638) construye el path `css/templates/{categoria_slug}/{template_id}.css?v={Date.now()}` y lo inyecta en un `<link data-template-css>` (≈L601) — el bypass de caché `?v=timestamp` certifica con latido LINK del Escudo GOLD (Mandato 4).
2. **Timeout:** 5000 ms; ante fallo, el kernel muestra el texto de error del i18n (`landing.css_error`, ≈L687) — fallback de idioma incluido.
3. **Clase de ámbito — DOBLE NOTACIÓN DE CASING (⚠️ leer con el AVISO NORMATIVO de arriba + ADR-057):** el kernel escribe en `document.body` DOS clases (`evento-app.html:998-1000`): `tpl-{template_id}` (tal cual viene en `eventos.template_id` — p.ej. `tpl-Mistico` o `tpl-f9b`) y `tpl-{id}` (en minúsculas — p.ej. `tpl-mistico` o `tpl-f9b`). **Nunca capitaliza.** **Por qué existe la doble notación:** algunos eventos traen `template_id` en mayúsculas ("F10") y otros en minúsculas ("f10"); el JS del kernel usa `document.body.className.includes('tpl-f8')` / `.indexOf('tpl-f9')` con minúsculas para activar sus subconmutaciones. **Regla (norma del hub, Cero Borrado):** todo selector de silo declara la doble forma `.tpl-fXX, .Tpl-FXX`. **⚠️ REALIDAD MEDIDA (ADR-057, 2026-09-26):** la forma `.Tpl-{id}` **NUNCA matchea en produccion** (el kernel no emite `Tpl-`); es **código muerto** y se conserva por Cero Borrado hasta resolver el ADR-057. Un silo que solo tenga `.Tpl-*` estaria **apagado**; un silo que solo tenga `.tpl-*` funciona. En `f9b.css`: 369 `.tpl-f9b` (vivos) + 365 `.Tpl-F9b` (muertos).
4. **Acento maestro:** `--master-accent` se deriva de `ev.color_primario || content.color_primario || content.accent_color` (≈L677-681) y el silo la consume para CTAs/accentos.
5. **Puente cromático HSL:** las funciones `__hexToHsl`/`__hslToHex` (≈L701-752) permiten derivar variantes armónicas; f8 (TropiLove) y f9 (Místico) las usan para subconmutaciones de paleta derivada.
6. **Subconmutaciones JS del kernel (REALES, checks sobre `document.body.className` con `includes`/`indexOf`):**
   - **`tpl-f6`** (≈L793): título en 2 líneas físico (`hero-title-line1` / `hero-title-line2`).
   - **`tpl-f8`** (≈L731, L843, L1152, L1265, L1552): paleta neón derivada; tab del formulario; footer con marca "Chokoflow" en `#footer-copy`; boletos preventa "INDIVIDUAL" / taquilla "PAREJA"; lineup Maqueta B; experiencias (L1338 comparte con f9).
   - **`tpl-f9`** (≈L817, L1235, L1377, L1559): meta del hero en 2 líneas (`meta-line`/`meta-line--2`); headliner marcado por NOMBRE ("RASTRO MC"); FAQ fallback editorial cuando el evento no trae FAQ; boletería por tarifa real (sin "POR DEFINIR"); experiencias (L1338).
   - **POLÍTICA:** una subconmutación nueva NO se implementa en la entrega del silo — es cambio de kernel de `evento.html` y se escala al Plan (nuevo ADR/TSK). El silo solo estiliza las subconmutaciones que el kernel ya activa.
7. **Prohibido:** iframe de YouTube (ADR-005); `<img>` sin `onerror` fallback (ADR-008); `invert`/`brightness` en logos sin alfa.
8. **VISTA PREVIA (`?preview=1`) — CONTRATO (ADR-056, 2026-09-26).** El wizard de `admin.html` puede renderizar el silo elegido **sin publicar y sin tocar Supabase**: escribe el borrador en `sessionStorage['ht_preview_payload']` (`admin.html:5694`) y monta `evento-app.html?preview=1` en un iframe (`admin.html:5713`) o en una pestaña (`:5721`). El kernel lo lee con `__evDesdePreview()` (`evento-app.html:891-911`), una funcion **pura de lectura** que viste el JSON con la MISMA forma de una fila de `eventos` y reutiliza integro el render. **Contrato del payload (estable):** `{ ev, content, theme, template_id, categoria_slug, effects }`. **REGLA DE FIDELIDAD (ADR-057): `preview == produccion`.** El adaptador pasa el `template_id` **SIN capitalizar**; el body del preview lleva **exactamente** la misma clase que produccion (`tpl-f9b tpl-f9b`). Prohibido reintroducir un override de casing `Tpl-` en el preview: introduciria una divergencia preview≠produccion. El fallback de error (`__renderPreviewError`, `evento-app.html:917-930`) usa `createElement` (no `innerHTML`) para no tocar el balance de divs y evitar inyeccion.

**ADRs citados:** ADR-005, ADR-008, ADR-006, ADR-010, **ADR-056 (lectura con fallback + preview), ADR-057 (capital-T / preview == produccion)**. **Reglas citadas:** Mandato 4 (Escudo GOLD), Mandato 13 (armonía HSL).

---

## 9. Registro en Admin (Paso 8 OBLIGATORIO)

> **Decisión de Dirección (zanjada):** toda entrega de silo DEBE registrar su theme en `admin.html` como paso final (paso 8 del flujo de creación). Un silo sin registro NO se considera entregado.

Requisitos verificados contra `admin.html` real (ADR-006). **A partir del silo `kande`/f12 (ADR-048, 2026-09-22) el registro completo son 6 puntos** (corrige la version previa que enumeraba 3 y citaba `seleccionarTheme` — el patron vigente es `abrirFichaTheme`):

1. **Tarjeta del theme:** nueva card `.ld-theme-card` con `data-theme="{slug}"` y **`onclick="abrirFichaTheme('{slug}')"`** (patrón real en `admin.html`: `kande` en **L606**, grupo Fiesta tras `fosforescente`; gradiente inline, título y descripción corta). **Toda tarjeta nueva nace VISIBLE por defecto (fail-open)** — el curado (ocultar/reordenar) lo hace la cuenta master vía `config_global` (ADR-040); las tarjetas permanecen en el DOM (Cero Borrado).
2. **Mapa de tipos:** `_THEME_TYPE` (slug → categoria_slug, `admin.html` ≈L2830; `kande`→`fiesta`).
3. **Mapa de plantillas:** `_THEME_TPL` (slug → template_id, `admin.html` ≈L2844; `kande`→`f12`). El derivado `_TPL_THEME` (template_id → slug) sale del `reduce` sobre `_THEME_TPL` (≈L2848-2852) y NO se edita directo.
4. **Preset ADN Visual:** `_THEME_MODULES` (mapa de ADR-047 con `requeridos/recomendados/selectivos/metaDosLineas`, `admin.html` ≈L2858-2879; `kande` en **L2875**; **19 themes** al 2026-09-22). ⚠️ Cuidado de namespacing: los checkboxes `ld-mod-*` dependen de la categoria — `ld-mod-historia`/`ld-mod-objetivo`/`ld-mod-impacto` solo existen en `#mods-campana` (L684), NO en `#mods-fiesta` (L651-665); NO listar un checkbox de campaña en un preset de Fiesta (defecto MAYOR corregido en ADR-048; familia `ERRORES_HISTORICOS.md` §13).
5. **Ficha visual:** `_THEME_FICHA` (`admin.html` ≈L3075+; `kande` en **L3103-3104**: nombre, 5 colores de paleta y descripción corta).
6. **Etiqueta humana:** `names` de `seleccionarTheme()` (`admin.html` ≈L3235; `'kande':'Kande'`).
7. **Fuente de verdad:** `public.config_global` (fila id='default') — orden y visibilidad global (ADR-040).
8. **Validación del Wizard:** si `_evModoPublico !== 'formulario'` y no hay theme seleccionado, el Wizard bloquea el guardado (`alrt('ev-alert', 'Elige una plantilla visual.', 'err')`, ≈L3131).

**ADRs citados:** ADR-040 (catálogo curado por master, con su crítica de alcance: "0 cambios a _THEME_TYPE/_THEME_TPL" en su estado original), ADR-041 (registro de `mistico`, paso 8 de ese silo), ADR-042, ADR-043. **Errores históricos:** §8 (INSERT que no escribía `template_id`/`categoria_slug`), §9/§10 (selectores posicionales y de atributo rotos por reorganización de pestañas).

---

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

## 9-ter. Metodología de Creación de un Template (8 Pasos)

> **Decisión de Dirección (zanjada):** este es el flujo OBLIGATORIO de creación. Cualquier IA puede seguirlo de principio a fin sin historial previo. Cada paso cierra antes de abrir el siguiente.

**Paso 1 — Diagnóstico del DOM real.**
Abrir `evento.html` y con `grep` listar: (a) los módulos `#mod-*` que el silo va a estilizar (IDs reales del **Anexo C**), y (b) las clases que el JS kernel genera (lineup, galería, boletos, form, etc. — misma fuente del Anexo C). Preparar la lista de trabajo: **encender / apagar / estilizar**. ⚠️ NUNCA usar el BLUEPRINT como mapa: el DOM real es v214+/v222 (~81 IDs), el BLUEPRINT describe v112 (21 átomos). Si un selector no se confirma con grep, se generaliza a `~Lxx` o se consulta al Plan.

**Paso 2 — Brief + tokens + paleta.**
Responder el **Brief Obligatorio** (Cap. 9-bis). Decidir paleta: derivada de `--master-accent` (por defecto) o fija (excepción justificada en cabecera). Nombrar tokens del silo `--fXX-*` (nunca `:root` global — Mandato 9). Verificar contraste WCAG AA **≥ 4.5:1** de cada color de texto sobre su fondo (Mandato 13).

**Paso 3 — Reset scoped + puente cromático.**
Bloque raíz `.tpl-fXX, .Tpl-FXX` con: `--tpl-accent: var(--master-accent, #fallback)`, token `--gold` si aplica, fondo/color/fuente base, y `box-sizing: border-box !important` a los descendientes (`*`, `*::before`, `*::after`). **Prohibido:** `@import` de fuentes y variables en `:root` global.

**Paso 4 — Activación atómica.**
Bloques `display: flex/block !important` para los módulos encendidos y `display: none !important` para los apagados. Los IDs permanecen **intactos** en el HTML (Cero Borrado — Mandato 2): el kernel IoC (`display:none` inicial en `section, header, footer`) se vence SOLO vía el CSS del silo.

**Paso 5 — Grid + secciones en orden DOM.**
`display: grid` en `#main-content-flow` + `grid-template-areas` (Mandato 10); asignar `grid-area` a cada módulo hermano (los `#mod-*` son hermanos planos del main). Estilizar sección por sección siguiendo el ORDEN del DOM real (Anexo C, bloque A → G). Agregar Reflow: `:has([data-hidden])` para los módulos que el kernel puede ocultar en runtime.

**Paso 6 — Breakpoints + reduced-motion.**
Mobile-first con los cortes normativos: **640 / 767 / 992 / 1279** (768 solo para `:has()`, 480 opcional — Cap. 5). Incluir **obligatoriamente** `@media (prefers-reduced-motion: reduce)` neutralizando animaciones.

**Paso 7 — Escudo GOLD del silo.**
Ejecutar el **checklist de aceptación (10/10)** del Cap. 10 sobre el archivo real. Si un punto falla: corregir y re-ejecutar; no continuar al paso 8 con fallos abiertos.

**Paso 8 — Registro del theme en admin (6 puntos, patrón `abrirFichaTheme`).**
Los **6 puntos reales** del registro (corrección mayor 2026-09-22, ADR-048; el patrón previo citado `seleccionarTheme` con 3 puntos era el de la versión 1.3.0 y quedó superado): (1) tarjeta `.ld-theme-card[data-theme="{slug}"]` con **`onclick="abrirFichaTheme('{slug}')"`** (`admin.html` L606 para `kande`); (2) alta en `_THEME_TYPE` (slug → categoria_slug, ≈L2830); (3) alta en `_THEME_TPL` (slug → template_id, ≈L2844; el derivado `_TPL_THEME` sale del `reduce`, NO se edita directo); (4) preset `_THEME_MODULES` `requeridos/recomendados/selectivos/metaDosLineas` (ADR-047, ≈L2858-2879) — ⚠️ respetar el namespacing por categoria de los checkboxes `ld-mod-*` (defecto MAYOR de ADR-048: `ld-mod-historia` solo existe en `#mods-campana` L684, jamás en un preset de Fiesta; `#mods-fiesta` L651-665); (5) ficha `_THEME_FICHA` (≈L3075+; `kande` L3103-3104); (6) etiqueta en `names` de `seleccionarTheme()` (≈L3235). Detalle completo en Cap. 9. La tarjeta **nace visible** (fail-open); el curado (ocultar/reordenar) es prerrogativa de la cuenta master vía `config_global` (ADR-040). Sin este paso el silo NO está entregado.

---

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

## Anexo A. Registro de Versiones (del propio documento)

| vX.Y.Z | Fecha | Descripción |
|---|---|---|
| v1.0.0 | (previo) | Antecedente del hub (deuda de documentación detectada en TSK-016/017/018 y auditoría de silos) |
| v1.2.0 | 2026-09-16 | Creación del hub normativo TEMPLATES.md: 10 capítulos; baseline verificado contra código real (f10 v2.0.0, f11 v3.2.0, f9 ADR-041, kernel v222, admin cards, ADR-040/041/042/043) |
| v1.3.0 | 2026-09-16 | Correcciones de Dirección + Anexo C (inventario DOM real); nueva metodología de creación en 8 pasos (9-ter); brief obligatorio (9-bis); Cap. 10 como checklist de aceptación 10/10; doble notación de casing corregida; silos en disco reales; subconmutaciones JS reales del kernel |
| **v1.4.0** | **2026-09-22** | **Silo f12 "Kande" (ADR-048) + reconciliación estructural + corrección del registro.** Banner de reconciliación (al inicio): `evento.html` NO existe como archivo — el motor real es `evento-app.html` (1724 lineas, v214; `vercel.json` → `/api/evento-og`); `#db-gallery-grid` dentro de `#mod-video`; `#mod-hero-ctas` nace oculto; sin override `?tpl=`/`?cat=`; `MODULE_IDS` ausente en v214. Cap. 7: silo `f12.css` (Kande, v1.0.0) agregado a fiesta. Cap. 9 y Paso 8 (9-ter): registro corregido a los **6 puntos reales** con patrón `abrirFichaTheme` (cards, `_THEME_TYPE`, `_THEME_TPL`, `_THEME_MODULES` ADR-047 — 19 themes —, `_THEME_FICHA`, `names`) + advertencia de namespacing por categoria de `ld-mod-*` (defecto MAYOR ADR-048). Anexo B: filas de kernel real y f12; registro de themes actualizado. Anexo C: nota de la galería dentro de `#mod-video`. Nota de Cap. 2: `evento.html` se lee desde este ADR como `evento-app.html` (Cero Borrado: el texto previo se conserva intacto) |
| **v1.5.0** | **2026-09-23** | **Salvaguarda anti-solape del hero movil del silo f12 "Kande" (ciclo express v1.13.0 -> v1.13.3).** Cap. 5: nuevo bullet de patron recomendado — cuando el titulo del hero escala por ancho (`24vw`) hasta su tope (`11.5rem`) en la banda 481-767px, limitar el titulo por ALTURA (`clamp(3rem, min(24vw, calc(20vh - 4rem)), 11.5rem)`) y recortar el badge (`margin-top:3vh`) para evitar el solape titulo/cinta; no afecta telefonos (`<=480px`). **Cap. 4:** nota espejo en la molecula Hero que remite a esta regla del Cap. 5 (sin duplicar el texto). Evidencia real: `css/templates/fiesta/f12.css` L2217-2231; contexto en `TASKS.md` TSK-062/TSK-063 y `NEXT.md` hito -19 |
| **v1.6.0** | **2026-09-26** | **Silo f9b "Mistico Nocturno" (ADR-054/055/056) + AVISO NORMATIVO capital-T (ADR-057) + contrato de preview.** Banner nuevo tras la reconciliacion estructural: **la mitad `.Tpl-*` es codigo muerto en produccion** (el kernel solo emite `tpl-` minuscula; `f9b.css` = 369 vivos / 365 muertos). Cap. 7: ficha del silo `f9b` (2922 lineas, 17 modulos ON / 10 OFF, silo INDEPENDIENTE de f9 — ambos VIVOS, el reset de "cero brillo" de f9 NO se hereda) + nomenclatura con aviso. Cap. 8 punto 3: doble notacion corregida con la realidad medida; **punto 8 nuevo: contrato de vista previa `?preview=1` + `sessionStorage['ht_preview_payload']`, preview == produccion**. Anexo B: filas de f9b y preview. Evidencia real (ADR-006): `evento-app.html:998-1000`, `css/templates/fiesta/f9b.css`; contexto en `DECISIONS.md` ADR-054/055/056/057, `TASKS.md` (paquete f9b) y `NEXT.md` (hito -22) |

---

## Anexo B. Mapa de Referencia Rápida

| Concepto | Archivo real | Referencia |
|---|---|---|
| **Motor publico (reconciliado ADR-048, 2026-09-22)** | **`evento-app.html`** (1724 lineas, "Master Orchestrator v214"); `vercel.json` reescribe `/evento.html` → `/api/evento-og` | Inyección: `injectAtomicCSS` L598-638; doble clase L691-693; `#mod-hero-ctas` oculto L33 + HTML L84 |
| Kernel IoC (`display:none` inicial) | `evento.html` | ≈L30 (section/header/footer), ≈L32 (`#mod-hero-ctas`) |
| Inyección del silo | `evento.html` | `injectAtomicCSS` ≈L598-638; `<link data-template-css>` ≈L601 |
| Fallback de carga CSS | `evento.html` | `landing.css_error` ≈L687 |
| Clase de ámbito en body | `evento.html` | ≈L692-694 (doble CASING: `tpl-{template_id}` + `tpl-{id}` minúscula — ver Cap. 8 punto 3) |
| Acento maestro | `evento.html` | ≈L677-681 (`--master-accent`) |
| Puente cromático HSL | `evento.html` | ≈L701-752 (`__hexToHsl`/`__hslToHex`) |
| Silos canónicos | `css/templates/fiesta/f9.css`, `f10.css`, `f11.css` | f9 ADR-041; f10 v2.0.0 ADR-042; f11 v3.2.0 ADR-043 |
| **Silo f12 "Kande" (ADR-048)** | `css/templates/fiesta/f12.css` | v1.0.0, 1563 lineas, 50294 bytes, ASCII limpio, 193/193 llaves, 0 `@import` reales, 14 modulos ON / 9 OFF, 5 media queries, hero sin 100vh; assets `assets/templates/f12/` (pendientes, fallback ADR-008) |
| **Silo f9b "Mistico Nocturno" (ADR-054/055)** | `css/templates/fiesta/f9b.css` | v1.0.0, **2922 lineas**, **369 `.tpl-f9b` (vivos) + 365 `.Tpl-F9b` (muertos, ADR-057)**, 0 selectores fuera de scope, **17 modulos ON / 10 OFF**, canal `fx-*` (parallax ON por defecto), silo INDEPENDIENTE de `f9` (ambos VIVOS); silo sostenido solo por la mitad `.tpl-f9b` |
| **Vista previa del silo (ADR-056 / ADR-057)** | `evento-app.html?preview=1` + `sessionStorage['ht_preview_payload']` | `admin.html:5694` (escribe) / `:5713` (iframe) / `:5721` (pestana); kernel `__evDesdePreview()` `evento-app.html:891-911`; **preview == produccion** (sin override `Tpl-`) |
| Registro de themes (6 puntos, patrón `abrirFichaTheme`) | `admin.html` | `.ld-theme-card` L606 (kande) · `_THEME_TYPE` ≈L2830 · `_THEME_TPL` ≈L2844 · `_THEME_MODULES` ≈L2858-2879 (19 themes, ADR-047) · `_THEME_FICHA` ≈L3075+ (kande L3103-3104) · `names` ≈L3235 · `config_global` ≈L2920+ (ADR-040/045) |
| Contrato de Datos | `BLUEPRINT.md` | Sección 4, v112, 21 Átomos Soberanos |
| Reglas de oro | `Reglas de Oro QR.md` | 16 Mandatos v127-MASTER |
| Inventario del DOM real | `evento-app.html` | **Anexo C** (inventario completo por bloque; nota: `#db-gallery-grid` L148 dentro de `#mod-video` L147) |

---

## Anexo C. Inventario del DOM Real de evento.html (~81 IDs)

> ⚠️ **Líneas aproximadas a la fecha 2026-09-16** (ADR-006): el archivo puede moverse con cada entrega. Verificar SIEMPRE con `grep` antes de usar un selector; las líneas citadas son orientativas. El kernel real es v214+ (interno v222, ~81 IDs, 1630 líneas aprox.).
>
> **Reconciliado 2026-09-22 (ADR-048):** el archivo real de este inventario es **`evento-app.html`** en el repositorio (1724 lineas; `evento.html` es solo el link publico reescrito por Vercel hacia `/api/evento-og`). Hechos clave del kernel real: **`#db-gallery-grid` (L148) vive DENTRO de `#mod-video` (L147)** — un silo que apague `#mod-video` oculta la galeria; `#mod-hero-ctas` (L84, con ancla `--lineup` hacia `#mod-lineup` L86) nace con `display:none !important` (L33) y exige encendido explicito via CSS del silo.

### BLOQUE A — Hero / título / meta / countdown / ctas (~L55-87)

| ID | Función |
|---|---|
| `#main-content-flow` | `<main>` grid único: TODOS los módulos `#mod-*` son hermanos planos, reordenables vía `grid-area` |
| `#mod-hero` | Header del hero (sección principal) |
| `#org-name-badge` | Insignia del nombre de la organización (esquina superior) |
| `#event-title` | Título del evento (átomo del contrato) |
| `#unified-frame` | Frame unificado: countdown (y reutilizado por video en algunos silos) |
| `#cd-days` / `#cd-hours` / `#cd-mins` / `#cd-secs` | Dígitos del countdown (00 por defecto) |
| `#mod-hero-meta` | Meta del hero (fecha/hora/lugar) |
| `#meta-fecha` / `#meta-hora` / `#meta-lugar` | Valores de la meta (2 líneas soportadas: `.meta-line`, `.meta-line--2`) |
| `#mod-hero-ctas` | CTAs del hero — **nace oculto por el kernel** (solo lo enciende `tpl-f6` vía CSS) |
| `#f6-hero-wa` | CTA WhatsApp del hero ("COMPRA ENTRADAS AHORA", `hero-cta-btn--wa`) |

### BLOQUE B — Historia / Descripción / Objetivo / Impacto (~L90-138)

| ID | Función |
|---|---|
| `#mod-historia` | Módulo de historia (campaña) |
| `#db-historia-titulo` | Título de la historia |
| `#db-historia-img` | Imagen de la historia (fallback: `onerror` oculta) |
| `#db-historia-texto` | Texto de la historia |
| `#mod-descripcion` | Átomo NUEVO (ADR-041, silo f9): descripción del evento |
| `#db-descripcion-titulo` / `#db-descripcion-texto` | Título y texto de la descripción |
| `#mod-objetivo` | Módulo de objetivo/recaudo (campaña) |
| `#db-objetivo-recaudado` / `-meta` / `-donantes` | Stats del objetivo |
| `#db-objetivo-barra` / `#db-objetivo-pct` | Barra de progreso y porcentaje |
| `#mod-impacto` | Módulo de impacto (campaña) |
| `#db-impacto-grid` | Grid de tarjetas de impacto (`.impacto-card`, `.impacto-card--metrica`, `.impacto-card--donacion`) |

### BLOQUE C — Video / Galería / Cartel / Lineup / Playlist / Info-técnica (~L140-195)

| ID | Función |
|---|---|
| `#mod-video` | Módulo de video (miniature HD, ADR-005 — prohibido iframe) |
| `#db-gallery-grid` | Grid de galería (N abierto; `.gallery-item` + `.lightbox-trigger`) |
| `#db-video-content` | Contenedor del video 16:9 (min-height 400px en playlist) |
| `#mod-cartel` | Cartel/póster del evento |
| `#db-poster-img` | Imagen del póster (con `lightbox-trigger` agregado por JS) |
| `#mod-lineup` | Lineup de artistas |
| `#db-lineup` | Lista de artistas (`.artist-card`, `.artist-card.headliner`, `.artist-photo`, `.artist-overlay`, `.artist-name`, `.artist-hora`, `.artist-resena`, `.artist-social`, `.artist-social-icon`) |
| `#mod-playlist` | Playlist de Spotify |
| `#db-spotify-embed` | Contenedor del embed |
| `#mod-info-tecnica` | Datos técnicos (Dresscode, Guest, Aforo, Ticket) — Geist 900 + drop-shadow (Mandato 8) |
| `#db-dress-val` / `#db-guest-val` / `#db-aforo-val` / `#db-ticket-val` | Valores de la info técnica (`.card-item`, `.data-cards-container`) |

### BLOQUE D — FAQ / Ubicación (~L197-206)

| ID | Función |
|---|---|
| `#mod-faq` | Preguntas frecuentes |
| `#db-faq-list` | Lista de FAQs (`.faq-item`, `.faq-answer`, `.faq-icon-circle`; toggle `active` por click) |
| `#mod-ubicacion` | Ubicación del evento |
| `#db-mapa-container` | Contenedor del mapa (height 380px inline) |

### BLOQUE E — Boletos / Experiencias / WhatsApp / Sponsors (~L208-257)

| ID | Función |
|---|---|
| `#mod-boletos` | Boletería (preventa/taquilla, tabs) |
| `#db-boletos-preventa` | Tarjetas de preventa |
| `#db-boletos-taquilla` | Tarjetas de taquilla |
| `#mod-experiencias` | Experiencias del evento |
| `#db-experiencias-list` | Grid de experiencias (`.exp-card`, `.exp-titulo`, `.exp-tag`) |
| `#mod-whatsapp` | CTA WhatsApp |
| `#db-whatsapp-btn` / `#db-whatsapp-text` | Botón y texto de WhatsApp |
| `#mod-sponsors` | Patrocinadores |
| `#db-sponsors-list` | Lista de sponsors (`.sponsor-item`, `.sponsor-img`) |

### BLOQUE F — Formulario dual (~L259-279)

| ID | Función |
|---|---|
| `#mod-form` | Módulo del formulario (Dual-Phase, ADR-011) |
| `.form-master-box` | Caja maestra del formulario (max-width 550px inline) |
| `.form-tabs` / `.tab-btn` | Tabs "nuevo/ya" del formulario |
| `#tab-new` / `#tab-old` | Botones de pestaña (switchForm('nuevo'/'ya')) |
| `#form-nuevo` | Formulario de registro nuevo |
| `#master-reg-form` | Form maestro (inscripción comunidad) |
| `#reg-nombre` / `#reg-whatsapp` | Campos nombre + WhatsApp |
| `#reg-unir-comunidad-wrap` / `#reg-unir-comunidad` / `#reg-comunidad-msg` | Checkbox comunidad + mensaje |
| `#form-ya` | Formulario de recuperación |
| `#rec-cedula` | Campo cédula (verificación) |

### BLOQUE G — Equipo / CTA-final / Footer (~L281-325)

| ID | Función |
|---|---|
| `#mod-equipo` | Equipo organizador |
| `#db-equipo-grid` | Grid de equipo (`.equipo-item`, `.equipo-avatar`, `.equipo-nombre`, `.equipo-rol`) |
| `#mod-cta-final` | CTA final (donación) |
| `#db-cta-final-titulo` / `#db-cta-final-subtitulo` | Título y subtítulo del CTA |
| `#cta-final-btn` | Botón CTA final (scroll al form) |
| `#mod-footer` | Footer del evento |
| `#footer-org-name` / `#footer-tagline` | Nombre y tagline de la org |
| `#db-footer-links` | Links del footer |
| `#db-footer-social` | Redes sociales |
| `#db-footer-contacto` | Contacto |
| `#footer-copy` | Copy del footer (f8 lo sobrescribe con "Chokoflow") |
| `.htz-powered` | Badge "Powered by Hostal Terraza" (inyectado por JS, ≈L1167) |

### CLASES KERNEL generadas por JS (única fuente válida de selectores por clase)

| Familia | Clases |
|---|---|
| Lineup | `.artist-card`, `.artist-card.headliner`, `.artist-photo`, `.artist-overlay`, `.artist-name`, `.artist-hora`, `.artist-resena`, `.artist-social`, `.artist-social-icon` |
| Galería | `#db-gallery-grid .gallery-item`, `.lightbox-trigger` |
| Boletos | `.boleto-card-row`, `.boleto-icon`, `.boleto-tipo`, `.boleto-precio`, `.boleto-desc`, `.boleto-arrow` |
| Formulario | `.form-master-box`, `.form-tabs`, `.tab-btn`, `.btn-submit` |
| Impacto | `.impacto-card`, `.impacto-card--metrica`, `.impacto-card--donacion` |
| Sponsors | `.sponsor-item`, `.sponsor-img` |
| Equipo | `.equipo-item`, `.equipo-avatar`, `.equipo-nombre`, `.equipo-rol` |
| Experiencias | `.exp-card`, `.exp-titulo`, `.exp-tag` |
| FAQ | `.faq-item`, `.faq-answer`, `.faq-icon-circle` |
| Info-técnica | `.card-item`, `.data-cards-container` |

### MÓDULOS DE CAMPAÑA que un silo de fiesta debe APAGAR por defecto (IDs intactos)

`#mod-historia`, `#mod-objetivo`, `#mod-impacto`, `#mod-info-tecnica`, `#mod-whatsapp`, `#mod-sponsors` — se ocultan con `display:none !important`, NUNCA se borran (Cero Borrado). En el silo **b5** (campaña) además: `#mod-impacto-historico`, `#mod-mapa-crisis`, `#mod-como-ayudar` (átomos de campaña de v110, extensión del silo b5).

---

*Documento sellado bajo el estandar de calidad de $10,000. v1.6.0 - Template Hub Normativo (ADR-006: todos los datos verificados contra archivos reales del repositorio; ADR-048: reconciliacion del motor real `evento-app.html` y silo f12 "Kande" 2026-09-22; v1.5.0: patron recomendado de salvaguarda por ALTURA del hero movil f12, 2026-09-23; v1.6.0: silo f9b "Mistico Nocturno" (ADR-054/055/056) + AVISO NORMATIVO capital-T / mitad `.Tpl-*` muerta en produccion (ADR-057) + contrato de vista previa, 2026-09-26).*
