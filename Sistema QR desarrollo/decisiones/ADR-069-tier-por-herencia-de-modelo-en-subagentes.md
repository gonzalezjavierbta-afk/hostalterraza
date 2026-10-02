---
doc: ADR-069
version: v1.16-GOLD (heredada de DECISIONS.md)
fecha: 2026-10-02
origen: sesion @architect 2026-10-02
version_previa: DECISIONS.md v1.16-GOLD
relacionados: [../DECISIONS.md, ../INDEX.md, ADR-067-consolidacion-del-roster-a-20-agentes-retiro.md]
estado: vigente (ver campo Estado dentro del ADR)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [DECISIONS.md](../DECISIONS.md) · [INDEX](../INDEX.md).

## ADR-069: Tier por herencia de modelo en subagentes

**Fecha:** 2026-10-02

**Autor:** @architect

**Estado:** Aceptado

**Problema:** Los 16 subagentes del roster declaraban `model:` fijo en su cabecera YAML, de modo que no existia un par FREE/PAGO sin duplicar archivos. Al mismo tiempo, los primarios FREE podian invocar por `task` a cualquier subagente del roster, incluidos los 9 dominios de riesgo.

**Contexto:** opencode resuelve el modelo de un subagente que omite `model:` heredandolo del primario que lo invoca. `permission.task` admite un objeto cuyos patrones se evaluan en orden: gana la ULTIMA regla que matchea, por lo que `"*": "deny"` debe ir PRIMERO y las excepciones despues; un patron que resuelve `deny` elimina al subagente de la descripcion del Task tool. ADR-067 (roster unico de 20 agentes) sigue vigente y esto no crea agentes gemelos. ADR-006: la verdad es el archivo real del repo.

**Opciones:**
- (A) Duplicar cada subagente en version FREE y PAGO: 32 archivos, viola ADR-067 (gemelos), descartada.
- (B) Mantener `model:` fijo en los 16 subagentes: impide el par FREE/PAGO sin duplicar, descartada.
- (C) Omitir `model:` en los 16 subagentes (herencia del primario) + allow-list en los primarios FREE + regla de escalado en su prompt: elegida.

**Decision:** Los 16 subagentes (admin-dev, architect, architect-review, backend-dev, content-loader, data-migration, docs-keeper, explore, frontend-tpl, js-silo-dev, media-reader, qa-auditor, renderer-dev, research-agent, seo-dev, sql-security) omiten `model:` y heredan del primario invocante: `@free-plan`/`@free-build` (opencode/big-pickle) obtienen el par FREE; `@plan`/`@build` (opencode-go/deepseek-v4.1-flash) el PAGO. Los 4 primarios conservan su `model:` explicito.

**Riesgo aceptado:** al quitar `model:`, los 9 dominios de riesgo (sql-security, data-migration, backend-dev, renderer-dev, admin-dev, architect, architect-review, seo-dev, research-agent) pueden correr en `opencode/big-pickle` si un humano los invoca con `@` desde una sesion FREE; opencode permite forzar por `@` aunque `permission.task` los niegue.

**Mitigacion (2 capas):**
1. `permission.task` como allow-list en `@free-plan` y `@free-build`: `"*": "deny"` seguido de `docs-keeper`, `explore`, `js-silo-dev`, `frontend-tpl`, `content-loader`, `media-reader` y `qa-auditor` en `allow`. Ademas adelgaza la descripcion del Task tool (menos contexto, ~1%).
2. Regla de escalado en el cuerpo del prompt de ambos primarios FREE: si la tarea toca uno de los 9 dominios de riesgo, el agente DETIENE y pide confirmacion explicita de escalar a PAGO.

**Nota:** `@seo-dev` pierde el modelo `opencode-go/qwen3.8-flash` y pasa a heredar (decision del usuario).

**Referencia:** ADR-067 (roster unico) se mantiene; esto no crea gemelos.

**Impacto:** Bajo en runtime (solo gobierno de agentes): 16 cabeceras YAML editadas, 2 permisos `task` convertidos a objeto, 2 bloques de prompt ampliados. Alto en control de costo y coherencia FREE/PAGO.
