---
doc: ADR-052
version: v1.16-GOLD (heredada de DECISIONS.md)
fecha: 2026-10-01
origen: DECISIONS.md L893-911 (AMPLIACION/_backups/DECISIONS.md.2026-10-01.bak)
version_previa: DECISIONS.md v1.16-GOLD
relacionados: [../DECISIONS.md, ../INDEX.md]
estado: vigente (ver campo Estado dentro del ADR)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [DECISIONS.md](../DECISIONS.md) · [INDEX](../INDEX.md). Texto original íntegro debajo (L893-911 del original).

#### ADR-052: Permisos automaticos de agentes (auto-approve) y `default_agent` = `free-build`

* **ID:** ADR-052 | **Fecha:** 2026-09-24 | **Estado:** IMPLEMENTADO y verificado (10/10 PASS por `@qa-auditor` PRO, 2026-09-24). Cambio de configuracion ya aplicado en 6 archivos: `opencode.json` (raiz), `DOCUMENTOS/opencode.json` y 4 agentes de `.opencode/agent/`. Este ADR es cierre documental: hace 0 cambios de codigo ni de configuracion; verifica contra el archivo real (patron ADR-006).
* **Autor:** Documentation Specialist / `@docs-keeper` (PRO). Implementacion de configuracion por Direccion; verificacion de baseline por `@qa-auditor` (PRO). Este cierre documental NO toca `opencode.json`, `DOCUMENTOS/opencode.json` ni `.opencode/agent/*.md`.
* **Problema:** el bloque `permission` global (`opencode.json`) y los permisos por-agente estaban en `ask`: cada edicion o comando de bash abria un prompt de aprobacion en la ruta de build (tanto en la ruta de PAGO como en la GRATUITA), interrumpiendo el flujo de trabajo repetidamente. Ademas `default_agent` apuntaba a un planificador (`free-plan`), de modo que la sesion arrancaba en modo plan y exigia un cambio manual de agente antes de poder construir. Se requeria: builders sin prompts, planificadores que sigan sin poder modificar archivos, y auditores/lectores estrictamente de solo lectura.
* **Opciones evaluadas:**
    1. **Opcion A (RECHAZADA) - mantener `permission` global en `ask` y poner `allow` solo por-agente en los builders:** el prompt seguiria apareciendo para cualquier agente o herramienta no enumerada, y `default_agent` seguiria siendo un planificador. No resuelve el problema de raiz.
    2. **Opcion B (ELEGIDA) - `permission` global en `allow` + `default_agent = free-build` + `edit: deny` explicito en planificadores/auditores/lectores:** los builders nunca piden permiso; el arranque cae directo en build gratuito; los agentes de criterio o de solo lectura compensan el `allow` global declarando su propio `edit: deny` en el frontmatter. `free-plan` conserva `bash: ask` (NO `deny`) por el gatekeeper del tier gratuito.
* **Decision:**
    1. **Config global:** `opencode.json` (raiz) y `DOCUMENTOS/opencode.json` -> `permission.edit: ask -> allow`, `permission.bash: ask -> allow`, `default_agent: free-plan -> free-build`.
    2. **`.opencode/agent/free-plan.md`:** `edit: ask -> deny` (mantiene `bash: ask` a proposito; el gatekeeper del tier gratuito exige declarar la tool `bash` en el request y prohibe `bash: deny` para modelos `opencode/*`, hallazgo 2026-09-21).
    3. **`.opencode/agent/qa-auditor-free.md`:** `edit: ask -> deny` (mantiene `bash: allow`).
    4. **`.opencode/agent/explore.md` y `.opencode/agent/explore-free.md`:** se anade `permission: { edit: deny }` explicito (antes sin bloque `permission`).
    5. **Sin cambios (verificados):** `plan.md`/`hybrid-plan.md` siguen `edit: deny` + `bash: deny` (Plan Mode; usan modelos de pago `opencode-go/*`, donde `bash: deny` no dispara el 403 del tier gratuito); `qa-auditor.md`/`media-reader.md`/`media-reader-free.md` siguen `edit: deny`.
    6. **Regla de diseno resultante:** planificadores = solo lectura (nunca modifican archivos); todo lo que construye/edita = `allow` (sin `ask`); auditores/lectores = solo lectura.
* **Justificacion:** los prompts constantes de `ask` rompian el flujo de build en ambas rutas sin aportar seguridad real (los subagentes de dominio ya tienen `allow`); arrancar en un planificador obligaba a un cambio de agente manual en cada sesion. La Opcion B preserva el principio de "planificador = solo lectura" endureciendo los planificadores a `edit: deny` (no basta con no darles `allow`: se declara la negacion explicita) y mantiene intactas las salvaguardas de Plan Mode en la ruta PRO (`plan`/`hybrid-plan` con `edit/bash deny`). El `bash: ask` de `free-plan` no es una excepcion de seguridad sino un requisito tecnico del gatekeeper del tier gratuito (un modelo gratis con `bash: deny` omite la tool del request y recibe 403, hallazgo 2026-09-21).
* **Impacto:** cero prompts de aprobacion en la ruta de build (paga y free); Plan Mode intacto en `plan`/`hybrid-plan`; auditores (`qa-auditor`, `qa-auditor-free`) y lectores (`explore`, `explore-free`, `media-reader`, `media-reader-free`) sin edicion; `explore*` con `edit: deny` explicito. Cambios documentales de este cierre: `AGENTS.md` (raiz) y `DOCUMENTOS/AGENTS.md` alineados al estado real; este ADR-052. **Riesgo:** con el `permission` global en `allow`, toda sesion inicia con escritura/ejecucion plenas por defecto; la mitigacion es que cada agente de criterio o de solo lectura declara su `edit: deny` en el frontmatter y los planificadores restringen `task` a subagentes de solo lectura.
* **Referencias:** ADR-031 (esquema dual pro/free y reglas anti-absorcion), ADR-006 (baseline de verdad contra el archivo real), hallazgo gatekeeper del tier gratuito (2026-09-21, seccion correspondiente de `AGENTS.md`), ADR-002 (ASCII-safe), `AGENTS.md`, `DOCUMENTOS/AGENTS.md`, `opencode.json`, `.opencode/agent/free-plan.md`, `.opencode/agent/qa-auditor-free.md`, `.opencode/agent/explore.md`, `.opencode/agent/explore-free.md`.

