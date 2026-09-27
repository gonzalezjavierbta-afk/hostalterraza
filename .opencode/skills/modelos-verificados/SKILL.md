---
name: modelos-verificados
description: Catalogo de modelos (pro/free), estados y el gatekeeper del tier gratuito. Cargar al elegir modelo, depurar un 403 o asignar un agente nuevo.
---

# Modelos Verificados y Gatekeeper del Tier Gratuito

Catálogo de modelos vigentes del Sistema QR Hostal Terraza y la mecánica del tier gratuito de OpenCode Zen. Cargar esta skill al elegir/asignar un modelo a un agente, al depurar un `403` o al crear un agente nuevo.

## Modelos verificados (T8, 2026-09-14) — catálogo vigente

| Modelo | Estado | Uso |
|---|---|---|
| `opencode/big-pickle` | FREE por límite de tiempo; sin tool-calling oficial (stripped) pero empíricamente los subagentes sí editan con él; inestable | 14 agentes `*-free` + `@free-build` + `@free-plan` |
| `opencode/mimo-v2.5-free` | FREE, multimodal, estable | `@media-reader-free` (EXCEPCIÓN: único free con visión) |
| `opencode-go/qwen3.8-flash` | Catálogo Go oficial, $0.15/$0.47, límite $30/mes | `@seo-dev` (EXCEPCIÓN: se mantiene pro, no se unifica con `@seo-dev-free`) y `@plan` (antes `deepseek-v4-flash`, RETIRADO) |
| `opencode-go/deepseek-v4.1-flash` | Nuevo (10-sep-2026), multimodal, supera V4-Pro, $0.15/$0.60 | 14 agentes pro + `@qa-auditor` |
| `opencode-go/deepseek-v4-flash` | RETIRADO por DeepSeek (alias -> V4.1) | ya no se usa en ningún agente |
| `opencode-go/minimax-m3` | Válido en catálogo (citado en T8 como "frontend-tpl pro") | Sin uso real: el frontmatter de `frontend-tpl.md` vigente usa `deepseek-v4.1-flash` al 2026-09-14. Documentado como incidencia, no como asignación |

Proveedores: `opencode-go` = gateway suscripción low-cost (https://opencode.ai/zen/go/v1); `opencode` = gateway free Zen. El 2026-09-14 `opencode-go` NO conecta — por eso la operación diaria se ejecuta con subagentes `*-free` + `@free-build`.

## Modelos gratis: gatekeeper del tier gratuito (hallazgo 2026-09-21)

OpenCode Zen agregó un **gatekeeper** en el tier gratuito (aprox. 16–19 sep 2026) que exige, **simultáneamente**: (1) `stream=true`, (2) declarar las tools `bash`/`shell` y `read` en el body del request, (3) cabeceras de cliente OpenCode.

**CONSECUENCIA PRÁCTICA:** un agente que use un modelo gratis (`opencode/*`) NO debe poner `bash: deny` en su frontmatter, porque eso omite la tool `bash` del request y el servidor responde `403 "OpenCode's free tier can only be used from within OpenCode"`. Usar `bash: ask` o `bash: allow` en su lugar.

Evidencia (2026-09-21, verificada contra los archivos reales, ADR-006): `free-plan` con `bash: deny` fallaba; tras cambiarlo a `bash: ask` responde OK (`.opencode/agent/free-plan.md` vigente al 2026-09-24: `edit: deny` · `bash: ask`; su `edit` paso de `ask` a `deny` por ADR-052 pero `bash` se conserva en `ask` a proposito). `free-build` (`bash: allow`) siempre funcionó (`.opencode/agent/free-build.md` vigente: `edit: allow` · `bash: allow`). Modelos gratis válidos del catálogo Zen: `opencode/big-pickle`, `opencode/mimo-v2.5-free`, `opencode/mimo-v2.6-flash-free`, `opencode/nemotron-3.5-lightning-free`, entre otros del catálogo Zen.

**Nota (2026-09-24):** `free-plan` conserva `bash: ask` a proposito (NUNCA `bash: deny`) por el gatekeeper del tier gratuito, aunque su `edit` ya sea `deny` (ADR-052). Un planificador gratuito no necesita escribir archivos, pero SI debe declarar la tool `bash` en el request para no recibir el 403 del tier gratuito.

## Regla de asignación

Todo agente DEBE tener `model:` explícito en su `.md` (prohibido heredar el modelo principal). Los IDs usan el prefijo real del proveedor (`opencode-go/*` o `opencode/*`); cualquier ID fuera de `opencode models` se considera inválido y se corrige. Al crear un agente que use modelo gratis, recordar el punto del gatekeeper: nunca `bash: deny`.
