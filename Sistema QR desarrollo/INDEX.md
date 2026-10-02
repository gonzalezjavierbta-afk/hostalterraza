---
doc: INDEX.md
version: v1.0 (nuevo)
fecha: 2026-10-01
origen: creado en la migración documental 2026-10-01
version_previa: n/a (documento nuevo)
relacionados: [PROJECT.md, DECISIONS.md, NEXT.md, TASKS.md, ERRORES_HISTORICOS.md, BLUEPRINT.md, Reglas%20de%20Oro%20QR.md, AMPLIACION/TEMPLATES.md, MIGRACION-DOCS.md, NOTAS-MIGRACION.md]
estado: vigente
---

# 🗺️ INDEX.md — Mapa raíz de `Sistema QR desarrollo/`

> Punto de entrada de la documentación viva. Cada documento de entrada conserva **su nombre original** (los agentes lo leen por nombre) y quedó como índice o resumen; el texto íntegro de lo que salió de ellos está en carpetas de detalle y archivo. Nada se eliminó (ver [MIGRACION-DOCS.md](MIGRACION-DOCS.md) y [NOTAS-MIGRACION.md](NOTAS-MIGRACION.md)).

## 1. Documentos de entrada (no renombrar)

| Documento | Qué es | Cuándo consultarlo | Tamaño | Detalle / archivo |
|---|---|---|---|---|
| [PROJECT.md](PROJECT.md) | Visión, stack, roles, reglas irrenunciables (resumen), silos y roadmap | Para orientarse al empezar | 95 líneas · 7.1 KB | [anexos/PROJECT-CRONICA-ESTADO.md](anexos/PROJECT-CRONICA-ESTADO.md) |
| [BLUEPRINT.md](BLUEPRINT.md) | Arquitectura técnica y modelo de datos (Contrato v112) | Antes de tocar HTML o esquema Supabase | 168 líneas · 22.1 KB | íntegro en el propio archivo |
| [Reglas de Oro QR.md](Reglas%20de%20Oro%20QR.md) | 20 mandatos incondicionales AI-DOS v1.2 (v129-MASTER) | Antes de cualquier intervención | 165 líneas · 15.4 KB | íntegro en el propio archivo |
| [DECISIONS.md](DECISIONS.md) | Índice de ADR (`ID \| Título \| Fecha \| Estado \| resumen`) | Para saber qué se decidió y por qué | 99 líneas · 24.2 KB | [decisiones/](decisiones/) (60 archivos) |
| [NEXT.md](NEXT.md) | Estado de relevo: hitos más recientes + secciones vigentes 1-4 | Al retomar una sesión | 123 líneas · 28.1 KB | [HISTORIA-NEXT.md](HISTORIA-NEXT.md) |
| [TASKS.md](TASKS.md) | Tablero de tareas abiertas (una fila por tarea) | Para saber qué falta | 91 líneas · 14.8 KB | [TASKS-DETALLE.md](TASKS-DETALLE.md) · [TASKS-ARCHIVO.md](TASKS-ARCHIVO.md) |
| [ERRORES_HISTORICOS.md](ERRORES_HISTORICOS.md) | Índice de bugs y lecciones (por sección E01..E28) | Antes de editar algo parecido a un error ya visto | 66 líneas · 14.2 KB | [errores/](errores/) (28 secciones + bitácora TRACE) |
| [AMPLIACION/TEMPLATES.md](AMPLIACION/TEMPLATES.md) | Hub normativo de silos CSS (índice por capítulos) | Al crear o editar un silo | 74 líneas · 8.1 KB | [AMPLIACION/templates/](AMPLIACION/templates/) (16 capítulos y anexos) |

## 2. Documentos de detalle, archivo y control

| Ruta | Contenido | Tamaño |
|---|---|---|
| [HISTORIA-NEXT.md](HISTORIA-NEXT.md) | 33 hitos antiguos de NEXT.md, íntegros, con tabla de líneas | 457 líneas · 176.4 KB |
| [TASKS-DETALLE.md](TASKS-DETALLE.md) | Texto completo de las 51 tareas abiertas + Estado General original | 256 líneas · 51.8 KB |
| [TASKS-ARCHIVO.md](TASKS-ARCHIVO.md) | 50 tareas cerradas + bitácora TRACE | 268 líneas · 140.2 KB |
| [anexos/PROJECT-CRONICA-ESTADO.md](anexos/PROJECT-CRONICA-ESTADO.md) | Crónica de estado, silos de Fiesta y catálogo curado (de PROJECT.md) | 29 líneas · 8.7 KB |
| [errores/TRACE-bitacora.md](errores/TRACE-bitacora.md) | 17 entradas `*TRACE` de ERRORES_HISTORICOS.md | 31 líneas · 22.4 KB |
| [MIGRACION-DOCS.md](MIGRACION-DOCS.md) | Tabla `origen → destino → tipo` de cada movimiento | 285 líneas · 36.7 KB |
| [NOTAS-MIGRACION.md](NOTAS-MIGRACION.md) | Qué se hizo, decisiones, verificación, `[REVISAR]`, cómo aplicarlo | 163 líneas · 14.5 KB |
| `AMPLIACION/_backups/` | Los 8 originales completos como `<archivo>.2026-10-01.bak` (CRLF original intacto) + `verificar_migracion.py` | — |

## 3. Cómo encontrar un dato

| Busco | Voy a |
|---|---|
| `ADR-NNN` | [DECISIONS.md](DECISIONS.md) → columna ID → `decisiones/ADR-NNN-<slug>.md`. Sin sección propia: ADR-032…038 y ADR-065 (tabla al final de DECISIONS.md) |
| `TSK-NNN` abierta | [TASKS.md](TASKS.md) (columna Detalle = líneas) → `TASKS-DETALLE.md#tsk-nnn` |
| `TSK-NNN` cerrada | [TASKS-ARCHIVO.md](TASKS-ARCHIVO.md)`#tsk-nnn` (tabla de líneas al inicio) |
| Error / lección | [ERRORES_HISTORICOS.md](ERRORES_HISTORICOS.md) → `errores/E##-<slug>.md`; las etiquetas `BUG-xxx` informales están en su tabla de alias |
| Hito reciente / antiguo | [NEXT.md](NEXT.md) / [HISTORIA-NEXT.md](HISTORIA-NEXT.md)`#hito-m31` (la `m` es el signo menos: hito -31) |
| Capítulo de silos | [AMPLIACION/TEMPLATES.md](AMPLIACION/TEMPLATES.md) → `templates/cap-NN-*.md` ("Cap. 5" = `cap-05`) |
| Un mandato (1-20) | [Reglas de Oro QR.md](Reglas%20de%20Oro%20QR.md) → "Mapa de secciones" |
| El texto original sin tocar | `AMPLIACION/_backups/<archivo>.2026-10-01.bak` |

## 4. Tabla de reubicaciones (compatibilidad con `AGENTS.md` y `.opencode/agent/*.md`)

| Referencia que ya existe en el repo | ¿Sigue válida? | Dónde está ahora |
|---|---|---|
| `PROJECT.md` | Sí | Mismo nombre; crónicas largas → `anexos/PROJECT-CRONICA-ESTADO.md` |
| `BLUEPRINT.md` | Sí | Mismo nombre y mismo cuerpo (+ cabecera estándar y mapa) |
| `Reglas de Oro QR.md` | Sí | Mismo nombre y mismo cuerpo (+ cabecera estándar y mapa) |
| `DECISIONS.md` (leer un ADR) | Sí, como índice | Texto íntegro → `decisiones/ADR-NNN-*.md` |
| `NEXT.md` | Sí | Hitos recientes y secciones 1-4 siguen en `NEXT.md`; hitos antiguos → `HISTORIA-NEXT.md` |
| `TASKS.md` | Sí, como tablero | Abiertas → `TASKS-DETALLE.md`; cerradas y TRACE → `TASKS-ARCHIVO.md` |
| `ERRORES_HISTORICOS.md` | Sí, como índice | Secciones → `errores/E##-*.md`; `*TRACE` → `errores/TRACE-bitacora.md` |
| `AMPLIACION/TEMPLATES.md` (y skill `templates`) | Sí | Mismo nombre y numeración de capítulos → `AMPLIACION/templates/cap-NN-*.md` |
| Citas por número de línea (p. ej. "DECISIONS L1522") | **No** | Buscar por ID, o abrir el respaldo `.bak` (las líneas coinciden con el original) |

## 5. Convenciones

| Elemento | Convención |
|---|---|
| Detalle de ADR | `decisiones/ADR-NNN-<slug>.md` (slug ASCII ≤46). La nota no-ADR del modo express: `decisiones/NOTA-modo-express.md` |
| Detalle de error | `errores/E##-<slug>.md` (`E##` = número de sección; no existen IDs `BUG-xxx` propios) |
| Anclas | Tareas: `#tsk-nnn` (duplicados con sufijo `-2`; `(a)` → `-a`) · Hitos: `#hito-m31`, `#hito-0`, `#hito-0b` |
| Cabecera estándar | Bloque YAML: `doc`, `version` (la original se preserva), `fecha`, `origen` (documento + líneas + respaldo), `version_previa`, `relacionados`, `estado`, `estructura` |
| Topes | Documentos de entrada ≤200 líneas y ≤30 KB. Archivos de archivo (HISTORIA-NEXT, TASKS-ARCHIVO) sin tope pero <200 KB y con tabla de líneas |
| Resúmenes | Siempre extracto literal del original + enlace a su fuente; nunca reescritos |
| Mantenimiento | ADR nuevo → archivo en `decisiones/` + fila en el índice · Tarea cerrada → pasa de TASKS-DETALLE a TASKS-ARCHIVO · Hito nuevo → entra en NEXT y el más antiguo se archiva en HISTORIA-NEXT |

## 6. Verificación

`python3 AMPLIACION/_backups/verificar_migracion.py` — compara los `.bak` con el árbol nuevo (IDs pre/post, línea por línea, topes, enlaces y rangos). Resultado de la migración en [NOTAS-MIGRACION.md](NOTAS-MIGRACION.md).
