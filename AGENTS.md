# AGENTS.md — Sistema QR Hostal Terraza

Rol de este documento: reglas universales de colaboración para cualquier agente que trabaje en este proyecto. Se carga automáticamente al inicio de cada sesión junto con `.agents/rules/CLAUDE.md` (ver `opencode.json`).

## Misión técnica

- Arquitectura: Vanilla JavaScript (ES6+), HTML5 semántico, CSS3 modular. Prohibido Webpack/Vite u otros bundlers.
- Infraestructura: Supabase (PostgreSQL, Auth, Storage, Edge Functions, RLS) + Vercel (hosting/CDN).
- Estilos: silos atómicos con CSS scoped bajo `.tpl-{id}`.
- Fuente de verdad técnica: `.agents/rules/CLAUDE.md` (Reglas de Oro v1.3.39) y `memory.md`.

## Protocolo de Delegación Universal (sugerido, no obligatorio)

Al recibir una indicación o prompt, evalúa si conviene delegar la tarea a un sub-agente especializado en lugar de resolverla tú directamente. La delegación optimiza el trabajo porque cada sub-agente usa un modelo y rol calibrado para su dominio.

### Matriz de enrutamiento recomendada

| Dominio de la tarea | Sub-agente recomendado |
|---|---|
| JavaScript vanilla, lógica de eventos, registro, scanner, integraciones Supabase/Wompi | `js-silo-dev` |
| CSS, silos `.tpl-{id}`, diseño visual, Geist 900, PWA (manifest/Service Worker) | `frontend-tpl` |
| Verificación QA: logs Escudo GOLD, parser HTML5, `node --check`, validación 1px | `qa-gold` |
| Migraciones SQL idempotentes, `pg_cron`, Edge Functions, integridad de esquemas | `sql-migrations` |
| Auditoría RLS y políticas Supabase, aislamiento por `org_id` | `sql-security` |
| Arquitectura, validación de ADRs, reconciliación de archivos, Reglas de Oro | `architect-review` |
| Exploración rápida del codebase (búsqueda de archivos, keywords, cómo funciona algo) | `explore` |
| Pruebas experimentales de modelo / comparación de calidad (NUNCA seguridad crítica) | `exp-pickle` |

### Cómo delegar

1. Clasifica la tarea por dominio usando la matriz.
2. Invoca la tool `task` con el sub-agente elegido y un prompt **autocontenido**:
   - Objetivo claro y resultado esperado.
   - Archivos/áreas afectadas.
   - Reglas de Oro relevantes (Data-First, Cero Borrado, Escudo GOLD, etc.).
   - Formato de retorno solicitado.
3. Consolida el resultado y repórtalo al usuario.
4. Si la tarea toca dominios distintos, delega en paralelo (varios `task` en una misma respuesta).

### Protocolo de Aprobación de Delegación (Mandatorio)

Antes de invocar la tool `task` con cualquier sub-agente, el agente principal DEBE:

1. **Presentar el Plan de Delegación Completo**, detallando:
   - Sub-agentes a invocar y su modelo asignado (ej. `js-silo-dev` → opencode/deepseek-v4-flash-free).
   - Tarea y responsabilidad específica de cada sub-agente.
   - Orden de ejecución (paralelo si son dominios independientes; secuencial si hay dependencias).
   - Formato de retorno esperado de cada uno.
2. **Pedir aprobación explícita del Director** usando la tool `question`, ofreciendo:
   - Aprobar el plan tal cual.
   - Ajustar agentes/modelos/distribución (con campo libre para correcciones).
   - No delegar (resolverlo el agente principal directamente).
3. **Ejecutar SOLO después de la aprobación** recibida.

Excepción: tareas triviales (≤1 edición, preguntas informativas, lecturas directas) quedan exentas del protocolo, según la regla "Cuándo NO delegar".

### Cuándo NO delegar

- Tareas triviales: ≤1 edición, preguntas informativas, lectura directa de un archivo.
- Cuando el usuario pida expresamente que la resuelvas tú.
- Nunca delegar recursivamente dentro de un sub-agente.

## Referencias

- `.agents/rules/CLAUDE.md` — Constitución Técnica / Reglas de Oro (Data-First, Cero Borrado, Escudo GOLD, fidelidad 1px).
- `.agents/rules/memory.md` — Memoria contextual de preferencias del Director.
- `.opencode/agent/*.md` — Definiciones de los sub-agentes.
