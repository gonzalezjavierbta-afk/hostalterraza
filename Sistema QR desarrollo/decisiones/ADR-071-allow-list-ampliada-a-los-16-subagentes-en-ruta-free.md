---
doc: ADR-071
version: v1.16-GOLD (heredada de DECISIONS.md)
fecha: 2026-10-02
origen: sesion @architect 2026-10-02 (decision de Direccion)
version_previa: DECISIONS.md v1.16-GOLD
relacionados: [../DECISIONS.md, ../INDEX.md, ADR-069-tier-por-herencia-de-modelo-en-subagentes.md, ADR-067-consolidacion-del-roster-a-20-agentes-retiro.md]
estado: vigente (ver campo Estado dentro del ADR)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [DECISIONS.md](../DECISIONS.md) - [INDEX](../INDEX.md).

## ADR-071: Allow-list ampliada de 7 a 16 subagentes en ruta FREE

**Fecha:** 2026-10-02

**Autor:** @architect (decision aprobada por Direccion, 2026-10-02)

**Estado:** Aceptado y aplicado

**Problema:** ADR-069 resolvio el par FREE/PAGO con herencia de modelo (los 16 subagentes omiten `model:`) y, como mitigacion del riesgo asumido, cerro la puerta tecnica a los 9 dominios de riesgo: en `.opencode/agent/free-build.md` y `.opencode/agent/free-plan.md` el bloque `permission.task` quedo con `"*": deny` mas 7 excepciones (`docs-keeper`, `explore`, `js-silo-dev`, `frontend-tpl`, `content-loader`, `media-reader`, `qa-auditor`). Consecuencia: los 9 subagentes de riesgo (admin-dev, architect, architect-review, backend-dev, data-migration, renderer-dev, research-agent, seo-dev, sql-security) quedaban en `deny` y NO podian delegarse desde la ruta FREE. La delegacion se partia en dos: lo mecanico en FREE, todo lo de criterio en PAGO, sin importar el riesgo real de la tarea.

**Contexto:** `permission.task` evalua sus patrones en orden y gana la ULTIMA regla que matchea, por lo que `"*": deny` debe ir PRIMERO y las excepciones despues (mecanismo ya fijado en ADR-069). El roster unico de 20 agentes (ADR-067) sigue vigente: ampliar la allow-list no crea agentes gemelos ni reactiva la ruta hibrida. ADR-069 (herencia de modelo) permanece INTACTO: este ADR no toca `model:` de ningun subagente. ADR-006: la verdad es el archivo real del repo.

**Opciones:**
- (A) Mantener 7 excepciones y depender de que el usuario fuerce los 9 de riesgo por `@` desde FREE: el permiso queda mintiendo (niega lo que en la practica se usa) y el deny limpio se pierde, descartada.
- (B) Sustituir el objeto por un `"*": allow` sin excepciones: se pierde la red de seguridad; un subagente anadido manana correria en silencio, descartada.
- (C) Allow-list explicita de los 16 subagentes conservando `"*": deny` como red, con el gate de confirmacion de AGENTS.md §2 intacto sobre los 9 de riesgo: elegida.

**Decision:** La allow-list de `permission.task` en `@free-plan` y `@free-build` pasa de 7 a los 16 subagentes del roster. `"*": deny` se CONSERVA como red de seguridad: si manana se anade un subagente y no se autoriza explicitamente aqui, el runtime lo negaria en silencio en lugar de dejarlo pasar. Los 9 dominios de riesgo siguen exigiendo el gate de confirmacion explicita del usuario de AGENTS.md §2 antes de ejecutar: permitido por config NO significa autorizado a ejecutar.

**Lo que NO se toco (deliberado):**
- `model:` de los 16 subagentes (la herencia de ADR-069 queda intacta).
- El `"*": deny` como primera regla.
- El gate de confirmacion de AGENTS.md §2.
- `subagent_depth`.

**Hallazgo operativo:** un cambio en `permission.task` NO surte efecto hasta reiniciar opencode: el runtime carga la allow-list al inicio de la sesion. Verificado en la practica el 2026-10-02: tras aplicar el cambio en disco, un `task` a `@architect` siguio siendo rechazado hasta reiniciar la sesion. Documentar esto evita diagnosticar como "config roto" lo que es solo cache de inicio de sesion.

**Riesgo aceptado (registro obligatorio):** Direccion autorizo ejecutar los dominios de riesgo en ruta FREE. Consecuencia asumida: una revision de arquitectura, un diseno de RLS o un plan de migracion hechos en `opencode/big-pickle` tienen MENOS valor de criterio que los mismos en `opencode-go/deepseek-v4.1-flash`. No es un problema de costo, es de fondo: el modelo FREE puede producir una entrega plausible y valida en forma, pero mas debil en criterio arquitectonico.

**Mitigacion:** el gate de AGENTS.md §2 exige confirmacion explicita del usuario ANTES de cada dominio de riesgo, lo que convierte el permiso en capacidad tecnica y la confirmacion en la regla. El prompt de `@free-build` lo enuncia en esos terminos. La allow-list amplia el alcance; no relaja el gate.

**Ruta de salida:** escalar a PAGO (`@plan`/`@build`) en cuanto el criterio lo exija. Ampliar la allow-list a PAGO no fue necesario porque los primarios PAGO ya invocan los 16 subagentes con modelo pagador via herencia.

**Estado aplicado (verificado en archivo real):**
- `free-build.md` y `free-plan.md`: bloque `task` con 16 lineas `allow`, verificado 16/16 en ambos.
- `AGENTS.md` §1 (herencia) y §2 (allow-list): texto corregido a "los 16 son invocables desde los primarios FREE; los 9 de riesgo conservan el gate de §2", citando ADR-071.
- Config (`.opencode/agent/free-build.md`, `free-plan.md`, `AGENTS.md`) commiteada en `5cd53a0` (base `b4b4beb`); verificado con `git show --stat 5cd53a0`. Al momento de redactarse este ADR, el propio archivo ADR-071 (untracked) y su fila de indice en `DECISIONS.md` (modificado) estaban pendientes de commit.
- `node scripts/express_check.js` -> PASS 27 / FAIL 0.

**Impacto:** Bajo en runtime (solo gobierno de agentes): 2 bloques `permission.task` ampliados y 2 parrafos de `AGENTS.md` corregidos. Sin cambios en codigo de aplicacion, sin cambios de esquema, sin coste de tokens. Efecto de gobierno: la ruta FREE deja de estar partida en dos y puede atender tareas de riesgo completo; el techo de calidad lo baja el gate de confirmacion, que es la garantia que este ADR deja explícita.

**Nota de numeracion:** el ID `ADR-070` esta ocupado por `ADR-070-titulo-del-hero-en-dos-lineas-con-subtitulo.md`; `ADR-071` no reutiliza ni salta ningun ID.
