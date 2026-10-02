---
doc: NOTA (sin ADR)
version: v1.16-GOLD (heredada de DECISIONS.md)
fecha: 2026-10-01
origen: DECISIONS.md L1605-1625 (AMPLIACION/_backups/DECISIONS.md.2026-10-01.bak)
version_previa: DECISIONS.md v1.16-GOLD
relacionados: [../DECISIONS.md, ../INDEX.md]
estado: vigente (ver campo Estado dentro del ADR)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [DECISIONS.md](../DECISIONS.md) · [INDEX](../INDEX.md). Texto original íntegro debajo (L1605-1625 del original).

## Nota de practica operativa (NO es un ADR): Modo Express (xpress) + skill `express-mode`

**ID:** (sin numeracion ADR, a proposito: este documento registra decisiones de arquitectura; esta es una decision de PROCESO)
**Fecha:** 2026-09-21
**Autor:** Documentation Specialist (AI-DOS)
**Estado:** VIGENTE (implementado en la sesion express 2026-09-21)

**Decision de proceso:** se adopta el **"modo express / xpress"** en HostalTerraza como practica operativa para cambios funcionales acotados, gobernada por la skill `.opencode/skills/express-mode/SKILL.md`, el comando unico de verificacion `scripts/express_check.js` y la seccion `## Modo Express (xpress)` de `AGENTS.md`. El modo se activa cuando el usuario pide trabajar "express", "xpress" o "rapido", y NO elimina controles: cambia su **orden** y su **profundidad**.

**Reglas clave del modo:** (1) brief quirurgico de delegacion por dominio (ruta + numeros de linea + bloque `old`/`new`); (2) verificacion local minima de 6 puntos (`node --check`, ASCII-safety, balance de divs, grep de residuos, smoke puntual y QA runtime obligatorio si se anidan contenedores dinamicos); (3) documentacion y deuda DIFERIDAS a un unico cierre de sesion (etiqueta `[DEUDA-EXPRESS]` en `NEXT.md`); (4) escalado obligatorio a modo normal en arquitectura, esquema/RLS/seguridad (siempre `@sql-security`, nunca `sql-security-free`), migraciones de datos, refactors compartidos o alcance > 3 archivos criticos o > 10 en total.

**Justificacion:** las sesiones de cambio de UI/UX y wiring no necesitan el plan formal ni el Escudo GOLD completo por cada micro-edicion; concentrar la verificacion en lo que puede romperse y documentar en un solo pase reduce turnos y costo sin aumentar el riesgo neto. Leccion incorporada del proyecto de origen: el unico bug no detectable por checks estaticos fue una regresion de anidacion de contenedores dinamicos; de ahi la regla de QA runtime obligatorio al anidar.

**Impacto:** NO toca esquema, endpoints ni runtime. Nueva evidencia: `scripts/express_check.js` (comando unico de verificaciones minimas), `.opencode/skills/express-mode/SKILL.md` (skill operativa) y `DOCUMENTOS/MODO_EXPRESS_ANALISIS.md` + `DOCUMENTOS/SKILL_MODO_EXPRESS.md` (manual interno y copia de registro, heredados del proyecto de origen y adaptados).

**NO es un ADR:** no se le asigna numero ADR porque no define arquitectura, contrato de datos ni seguridad; si en el futuro el modo express requiere una decision de arquitectura, se registrara como ADR numerado segun el formato de este documento.

**Nota de adaptacion:** la skill se adapto a la realidad verificada de este repositorio. Los sets de archivos heredados (`mi-perfil.html`, `comunidad.html`, `galeria.html`, `db/cleanups/`) se remapearon a los archivos criticos reales (`admin.html`, `scanner.html`, `index.html`, `eventovenezuela.html`, `api/*.js`, `js/i18n.js`, `migrations/*.sql`, `vercel.json`) y al registro historico `ERRORES_HISTORICOS.md`.

---

