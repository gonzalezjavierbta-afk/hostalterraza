---
doc: NOTAS-MIGRACION.md
version: v1.0 (nuevo)
fecha: 2026-10-01
origen: redactado al cierre de la migración 2026-10-01
version_previa: n/a (documento nuevo)
relacionados: [INDEX.md, MIGRACION-DOCS.md]
estado: histórico (anotaciones de la migración)
---

# NOTAS-MIGRACION.md — Qué se hizo, por qué y cómo comprobarlo

> Anotaciones de la reestructuración documental del 2026-10-01. Complementa a [MIGRACION-DOCS.md](MIGRACION-DOCS.md) (tabla fila a fila) y a [INDEX.md](INDEX.md) (mapa).

## 1. Resumen

Se reorganizó la documentación viva de `Sistema QR desarrollo/` en un sistema indexado: los 8 documentos del alcance conservan su nombre (los agentes los leen por nombre) pero los de mayor consulta pasaron a ser **índices o tableros** de ≤200 líneas y ≤30 KB; el texto íntegro de lo que salió se movió a carpetas de detalle y archivo. **No se reescribió ni se "mejoró" ningún ADR, regla, tarea o error:** solo cambió su ubicación y el nivel de síntesis (los resúmenes son extractos literales con enlace a la fuente).

### Cambios por documento

| Documento | Antes | Después | Rol ahora |
|---|---|---|---|
| `DECISIONS.md` | 1666 líneas · 502 KB | 99 líneas · 24 KB | Índice de 59 ADR + 1 nota (+ tabla de huecos) |
| `ERRORES_HISTORICOS.md` | 389 líneas · 116 KB | 66 líneas · 14 KB | Índice por sección E01..E28 + alias BUG |
| `NEXT.md` | 483 líneas · 198 KB | 123 líneas · 28 KB | 4 hitos recientes + secciones vigentes 1-4 |
| `TASKS.md` | 261 líneas · 174 KB | 91 líneas · 15 KB | Tablero de 51 abiertas + lista de cerradas |
| `PROJECT.md` | 69 líneas · 13 KB | 95 líneas · 7 KB | Mismo contenido con 3 bullets-crónica resumidos + anexo |
| `BLUEPRINT.md` | 137 líneas · 21 KB | 168 líneas · 22 KB | Íntegro + cabecera estándar + mapa de secciones |
| `Reglas de Oro QR.md` | 123 líneas · 13 KB | 165 líneas · 15 KB | Íntegro + cabecera estándar + mapa de secciones |
| `TEMPLATES.md` | 503 líneas · 56 KB | 74 líneas · 8 KB | Índice por capítulos (16 archivos) |

### Archivos nuevos

| Archivo | Tipo | Tamaño |
|---|---|---|
| `HISTORIA-NEXT.md` | archivo | 457 líneas · 176.4 KB |
| `TASKS-DETALLE.md` | detalle | 256 líneas · 51.8 KB |
| `TASKS-ARCHIVO.md` | archivo | 268 líneas · 140.2 KB |
| `anexos/PROJECT-CRONICA-ESTADO.md` | anexo | 29 líneas · 8.7 KB |
| `errores/TRACE-bitacora.md` | archivo | 31 líneas · 22.4 KB |
| `INDEX.md` | nuevo | 82 líneas · 7.2 KB |
| `MIGRACION-DOCS.md` | nuevo | 285 líneas · 36.7 KB |
| `NOTAS-MIGRACION.md` | nuevo | 163 líneas · 14.5 KB |
| `decisiones/` | 60 archivos (59 ADR + 1 nota no-ADR del modo express) | detalle |
| `errores/` | 28 archivos `E##` (una por sección) | detalle |
| `AMPLIACION/templates/` | 16 capítulos y anexos de TEMPLATES | detalle |
| `AMPLIACION/_backups/` | 8 originales `.bak` + `verificar_migracion.py` | respaldo |

## 2. Por qué el tope se midió en líneas **y** bytes

El inventario original sugería "≤150-200 líneas", pero las líneas del corpus son larguísimas (hasta 2.500 caracteres): TASKS.md tenía solo 261 líneas y pesaba 178 KB. Con el tope aprobado (≤200 líneas **y** ≤30 KB por documento de entrada) el peso real cae de ≈1,05 MB a unas decenas de KB por consulta.

## 3. Decisiones aplicadas

| # | Decisión | Qué se hizo y por qué |
|---|---|---|
| 1 | Archivos faltantes | Se recibieron `Reglas de Oro QR.md` y `AMPLIACION/TEMPLATES.md`; ya forman parte de la migración. **No** se recibieron `AGENTS.md` ni `.opencode/agent/*.md`: la tabla de reubicaciones se apoya en los nombres citados en el encargo (ver §6). |
| 2 | Tope por documento | ≤200 líneas y ≤30 KB para todo documento de entrada. Cumplido por los 9 (ver verificación). |
| 3 | Errores sin ID `BUG-xxx` | Se indexó por **número de sección** (`E01`..`E28`) y **no se creó ningún ID**. Las etiquetas informales `BUG-006/016/018/019/022/XXX` quedaron como alias `[REVISAR]` en una tabla de ERRORES_HISTORICOS.md (con las líneas de origen). |
| 4 | Tareas | Tablero + `TASKS-DETALLE.md` (en lugar de ~100 archivos). Cada fila del tablero indica las líneas exactas del detalle. Las cerradas y los 17 `*TRACE` se archivaron en `TASKS-ARCHIVO.md`. |
| 5 | Saltos de línea | **Todo lo nuevo se escribe en LF** (un solo estándar, diffs limpios en git). Los originales **se respaldan byte a byte con su CRLF intacto** (`DECISIONS.md` y `ERRORES_HISTORICOS.md` venían en CRLF), así que no se pierde nada. El verificador normaliza saltos de línea antes de comparar. |
| 6 | NEXT.md | Se conservan los **4 hitos más recientes** (-36, -35, -34, -33) y las secciones vigentes 1-4; se archivaron 33 hitos (-32 … 0b) en `HISTORIA-NEXT.md`. Se probó con 5 hitos y superaba los 30 KB (los hitos recientes pesan unos 4 KB cada uno), por eso la regla del tope de bytes pesó más que "los últimos 5". Todo lo explicado queda en este documento. |

### Decisiones propias (dentro del margen "tomar la mejor decisión")

- **TEMPLATES.md sí recibió el mismo patrón** (57 KB, 16 capítulos): índice + un archivo por capítulo. La numeración se conserva ("Cap. 5" = `cap-05-*.md`), así que las citas de otros documentos siguen siendo localizables.
- **BLUEPRINT.md y Reglas de Oro QR.md solo reciben cabecera estándar y un "Mapa de secciones"**; ya cumplían el tope (22 KB y 15 KB) y partirlos habría roto su papel de documento normativo completo.
- **PROJECT.md** ya cumplía el tope; solo se movieron al anexo tres bullets que eran crónica de ADR (Estado del Sistema, silos de Fiesta, catálogo curado) y se dejó un resumen con enlace. La tabla de silos de PROJECT.md está compuesta únicamente con datos del propio texto del bullet.
- **Los 59 ADR van en un archivo cada uno** (no agrupados por área): el mayor pesa unos 40 KB y el resto mucho menos; un archivo por ID mantiene el enlace directo `ADR-NNN`.
- **Los resúmenes de índice son extractos literales** (primera frase de la Decisión, ≤150 caracteres; primer tramo del Estado, ≤70). No se parafrasea para no alterar el sentido.
- **`TASKS.md` conserva Proyecto, Sprint y Última actualización verbatim**; el "Checkpoint Actual" (2,7 KB en una línea) queda como extracto y completo en `TASKS-DETALLE.md`.

## 4. Qué NO se hizo

- No se modificó ningún ADR, regla, tarea ni error; no se renumeró ni reutilizó ningún ID; no se crearon decisiones, tareas ni errores nuevos.
- No se unificaron las versiones de cabecera ni se corrigieron las inconsistencias detectadas (todas quedan como `[REVISAR]`).
- No se tocó el repo real, `AGENTS.md`, `.opencode/agent/*.md` ni las skills: no estaban en el alcance entregado. El trabajo está en este árbol listo para copiar.

## 5. Verificación

Respaldos: los 8 `.bak` son idénticos byte a byte a los archivos recibidos (SHA-256 comparado): **OK**.

| Comprobación | Resultado | Detalle |
|---|---|---|
| Respaldos .bak presentes (8 originales) | ✅ OK | 8 encontrados: BLUEPRINT.md, DECISIONS.md, ERRORES_HISTORICOS.md, NEXT.md, PROJECT.md, Reglas de Oro QR.md, TASKS.md, TEMPLATES.md |
| IDs ADR-XXX: todos los del original existen y no hay IDs nuevos | ✅ OK | pre=66 post=67 (extras explicados: ['ADR-038']) |
| IDs TSK-XXX: todos los del original existen y no hay IDs nuevos | ✅ OK | pre=100 post=100 |
| IDs BUG-XXX: todos los del original existen y no hay IDs nuevos | ✅ OK | pre=4 post=6 (extras explicados: ['BUG-018', 'BUG-019']) |
| Ninguna aparición de ID se perdió (post ≥ pre por ID) | ✅ OK | 2282 apariciones pre → 2818 post (las extra son filas de índice/enlaces) |
| ADR: encabezados originales = archivos decisiones/ADR-*.md | ✅ OK | 59 = 59 |
| Nota no-ADR (modo express) en decisiones/ | ✅ OK |  |
| ERRORES: secciones originales = archivos errores/E##-*.md | ✅ OK | 28 = 28 |
| TASKS: ítems `- [ ]`/`- [x]` originales = DETALLE + ARCHIVO | ✅ OK | 101 = 101 |
| NEXT: hitos originales = NEXT + HISTORIA-NEXT | ✅ OK | 37 = 37 |
| TEMPLATES: capítulos `##` originales = archivos AMPLIACION/templates/ | ✅ OK | 16 = 16 |
| Cada línea no vacía de los 8 originales existe en el sistema nuevo (conteo estricto) | ✅ OK | 3012/3012 líneas presentes |
| Tope DECISIONS.md ≤200 líneas y ≤30 KB | ✅ OK | 99 líneas · 24.2 KB |
| Tope ERRORES_HISTORICOS.md ≤200 líneas y ≤30 KB | ✅ OK | 66 líneas · 14.2 KB |
| Tope NEXT.md ≤200 líneas y ≤30 KB | ✅ OK | 123 líneas · 28.1 KB |
| Tope TASKS.md ≤200 líneas y ≤30 KB | ✅ OK | 91 líneas · 14.8 KB |
| Tope PROJECT.md ≤200 líneas y ≤30 KB | ✅ OK | 95 líneas · 7.1 KB |
| Tope BLUEPRINT.md ≤200 líneas y ≤30 KB | ✅ OK | 168 líneas · 22.1 KB |
| Tope Reglas de Oro QR.md ≤200 líneas y ≤30 KB | ✅ OK | 165 líneas · 15.4 KB |
| Tope AMPLIACION/TEMPLATES.md ≤200 líneas y ≤30 KB | ✅ OK | 74 líneas · 8.1 KB |
| Tope INDEX.md ≤200 líneas y ≤30 KB | ✅ OK | 82 líneas · 7.2 KB |
| Todos los enlaces relativos y anclas resuelven | ✅ OK | 787 enlaces revisados |
| Rangos "Líneas" de tableros y mapas apuntan a la línea correcta | ✅ OK | 224 rangos revisados |


**Resultado global del verificador:** ✅ TODO OK

Interpretación: las "apariciones extra" de IDs son filas de índice y enlaces (los índices repiten el ID para enlazar a su detalle); `ADR-038` aparece solo en la tabla de huecos de numeración y `BUG-018`/`BUG-019` son la expansión de la cita compacta "BUG-006/018/019" del original: no son IDs nuevos.

Para repetirlo en cualquier momento: `python3 AMPLIACION/_backups/verificar_migracion.py`.

## 6. Puntos `[REVISAR]` (no se resolvieron: se conservan tal cual)

| Ref. | Nota |
|---|---|
| ADR-032 | Citado pero sin sección propia en DECISIONS.md (DECISIONS ×6, NEXT ×6, TASKS ×1). |
| ADR-033 | Citado pero sin sección propia en DECISIONS.md (DECISIONS ×8, ERRORES_HISTORICOS ×4, NEXT ×2, TASKS ×1). |
| ADR-034 | Citado pero sin sección propia en DECISIONS.md (DECISIONS ×2). |
| ADR-035 | Citado pero sin sección propia en DECISIONS.md (DECISIONS ×2, TASKS ×1). |
| ADR-036 | Citado pero sin sección propia en DECISIONS.md (DECISIONS ×1). |
| ADR-037 | Citado pero sin sección propia en DECISIONS.md (DECISIONS ×3). |
| ADR-038 | Citado pero sin sección propia en DECISIONS.md (no aparece en ningún documento). |
| ADR-065 | No existe como ADR: fue declinado de forma expresa (se anexó al ADR-064). |
| E12 | Sin línea Blindaje/Lección explícita; el índice muestra el Problema. |
| BUG-XXX | Etiqueta BUG sin sección propia en ERRORES_HISTORICOS.md (ID no creado; se conserva como alias). |
| BUG-022 | Etiqueta BUG sin sección propia en ERRORES_HISTORICOS.md (ID no creado; se conserva como alias). |
| BUG-006 | Etiqueta BUG sin sección propia en ERRORES_HISTORICOS.md (ID no creado; se conserva como alias). |
| BUG-018 | Etiqueta BUG sin sección propia en ERRORES_HISTORICOS.md (ID no creado; se conserva como alias). |
| BUG-019 | Etiqueta BUG sin sección propia en ERRORES_HISTORICOS.md (ID no creado; se conserva como alias). |
| BUG-016 | Etiqueta BUG sin sección propia en ERRORES_HISTORICOS.md (ID no creado; se conserva como alias). |
| TSK-073 | ID repetido en 2 entradas del tablero (se conservan todas; anclas con sufijo). |
| PROJECT §9 | Roadmap cita TSK-016/017/018 y `evento3.html`; el motor real es `evento-app.html` (ADR-048). Se conserva sin cambios. |
| TEMPLATES.md | Su cabecera cita "16 Mandatos de Reglas de Oro QR.md (v127-MASTER)"; el archivo actual es v129-MASTER con 20 mandatos. |
| Reglas de Oro QR.md | Cita Contrato de Datos v107 (§1) y `evento3.html` (§3, §10) como baseline; el resto del corpus usa v112 y `evento-app.html`. |
| Versiones de cabecera | PROJECT v1.6.8-FIX · TASKS/NEXT v1.20-FIX · DECISIONS v1.16-GOLD · BLUEPRINT v1.6.2 · ERRORES v1.8.0-STABLE (sus TRACE hablan de v1.25.0) · Reglas v129-MASTER · TEMPLATES v1.7.0. Se conservan sin unificar. |
| BLUEPRINT | Título dice Contrato v112; §4 dice v111 con 21 átomos; PROJECT dice v110 con 20 átomos; "Versión: v1.6.1" en Información de Estado vs título v1.6.2. |
| TASKS/NEXT | Subítems TSK-081 (a)/(b)/(c) mezclan estados bajo un mismo ID; TSK-SQL y TSK-V03 son IDs no numéricos; NEXT numera hitos con huecos (no existe -21). |
| Referencias por línea | Citas del tipo "L1522" del documento original ya no apuntan al mismo sitio; consultar el respaldo `.bak` o buscar por ID. |

**Pendientes que dependen de ti:**

- **`AGENTS.md` y `.opencode/agent/*.md` no se revisaron** (no se entregaron). Conviene comprobar que sus lecturas por nombre (`PROJECT.md`, `NEXT.md`, `TASKS.md`, `BLUEPRINT.md`, `DECISIONS.md`, `ERRORES_HISTORICOS.md`, `Reglas de Oro QR.md`) y la skill `.opencode/skills/templates/SKILL.md` siguen cumpliendo su propósito ahora que varias son índices.
- **Mandato 12 de las Reglas de Oro** ("entregar el texto completo e íntegro" al actualizar documentos) y la regla de TRACE/versión de cierre de los agentes fueron escritos para archivos monolíticos. Decide cómo se aplican al nuevo sistema (por ejemplo: "texto completo" = el archivo de detalle que se toca más su fila de índice). No se modificó ninguna regla.
- **ADR-032…038 y ADR-065** y las etiquetas `BUG-xxx`: decidir si se documentan retroactivamente o se oficializa que no existen.
- **Datos no ubicados:** ninguno; el verificador confirma que cada línea no vacía de los 8 originales existe en el sistema nuevo.

## 7. Cómo aplicarlo al repo

1. Copia el contenido de la carpeta `Sistema QR desarrollo/` (zip adjunto) sobre la del repo. Los originales quedan en `AMPLIACION/_backups/` como `.bak`.
2. Ejecuta `python3 AMPLIACION/_backups/verificar_migracion.py` y confirma `TODO OK`.
3. Revisa los `[REVISAR]` de §6 y la tabla de reubicaciones de [INDEX.md](INDEX.md) contra `AGENTS.md` y `.opencode/`.
4. Haz un único commit de la migración (así el diff queda aislado y se puede revertir con los `.bak`).

## 8. Límites y riesgos conocidos

- `HISTORIA-NEXT.md` (≈176 KB) y `TASKS-ARCHIVO.md` (≈140 KB) son archivos históricos grandes: quedan por debajo de los 200 KB del Mandato 17 y llevan tabla de líneas para leer solo el tramo necesario. Si crecen, conviene partirlos por año/trimestre.
- Los números de línea de los índices valen para esta versión de los archivos; si se edita un archivo de detalle, hay que refrescar la columna de líneas (los ADR y errores enlazan por archivo, así que no se ven afectados).
- Algunas filas de TASKS.md quedan con un Responsable largo cuando el original no separaba rol y título de forma limpia; el texto completo está siempre un clic más abajo.
- Se añadió un bloque YAML al inicio de cada archivo. Si algún lector de agentes trata el inicio de archivo de forma especial, es lo único que habría que ajustar.
