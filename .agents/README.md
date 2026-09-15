# .agents/ — UNIVERSO LEGADO

UNIVERSO LEGADO — gestionado por agentes Claude/Gemini de esquemas externos. El universo VIGENTE para OpenCode es `.opencode/`. No usar estas skills como fuente para OpenCode.

Este directorio se preserva íntegro por su valor histórico y normativo (Cero Borrado). No eliminar, mover ni migrar su contenido sin una decisión explícita.

## Contenido preservado

| Ruta | Qué es |
|---|---|
| `rules/CLAUDE.md` | Constitución Técnica del Sistema QR para agentes Claude (v1.3.39) |
| `rules/memory.md` | Context Package de Memoria Permanente (v1.3.41) |
| `scripts/generar-log-uso.js` | Generador de reportes de uso de OpenCode (sin dependencias) |
| `skills/frontend-design/` | Duplicado histórico — vigente en `.opencode/skills/frontend-design/` |
| `skills/web-design-guidelines/` | Duplicado histórico — vigente en `.opencode/skills/web-design-guidelines/` |

## Relación con `.opencode/` (fuente de verdad vigente)

- `.opencode/skills/frontend-design/SKILL.md` — idéntico en contenido (difiere solo en fin de línea LF vs CRLF).
- `.opencode/skills/web-design-guidelines/SKILL.md` — byte-idéntico (mismo SHA-256).
- El runtime de OpenCode puede resolver skills desde `.agents/skills/*` si el nombre coincide; ante cualquier divergencia futura, el contenido que manda es el de `.opencode/skills/`.