---
doc: E25 (ERRORES_HISTORICOS.md §25)
version: v1.8.0-STABLE (heredada)
fecha: 2026-10-01
origen: ERRORES_HISTORICOS.md L331-338 (AMPLIACION/_backups/ERRORES_HISTORICOS.md.2026-10-01.bak)
version_previa: ERRORES_HISTORICOS.md v1.8.0-STABLE
relacionados: [../ERRORES_HISTORICOS.md, ../INDEX.md]
estado: vigente
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [ERRORES_HISTORICOS.md](../ERRORES_HISTORICOS.md) §25 · [INDEX](../INDEX.md). Texto original íntegro debajo (L331-338 del original).

## 25. Stall de Implementacion en un Subagente: el agente de render devolvio 3 preguntas y un plan sin editar un solo archivo (2026-09-30 - cierre documental ADR-064)

### Un brief que deja decisiones abiertas al subagente puede devolver 0 lineas
* **Problema:** el primer intento del agente de render devolvio **3 preguntas y un plan, sin editar un solo archivo**. El trabajo no avanzo hasta que el orquestador respondio con hechos verificados. El costo fue un turno completo de implementacion perdido (y el riesgo de que el siguiente relevo interpretara el "plan" como avance).
* **Causa raiz:** el brief dejaba **decisiones abiertas** al subagente (nombre exacto de la libreria de QR, si el formulario publico tenia o no campo `tipo`, la coordenada del string del codigo). Ante la ambiguedad, el subagente eligio preguntar en vez de actuar, y **el orquestador no habia verificado esos hechos antes de delegar**.
* **Blindaje / leccion:** (1) **verificar los hechos del brief ANTES de delegar**: un brief que afirma la existencia de un campo/archivo/lib debe llevar el `archivo:linea` ya confirmado por el orquestador. (2) **Cerrar las decisiones de implementacion en el brief** (nombre de lib, coordenadas, ausencia/presencia de campos); dejar "a criterio del subagente" lo que es dato verificable produce 0 lineas. (3) Un stall silencioso es tan costoso como un cambio erroneo: conviene detectar el "devolvio preguntas" como senal de brief incompleto, no como fallo del subagente.
* **Verificacion (2026-09-30):** el stall se desbloqueo **contestando con hechos verificados** (lib = `qrcodejs 1.0.0`, solo-DOM, sin `toCanvas`; el form publico **no** tiene campo `tipo`; coordenada `TICKET_QR_TEXT_Y = 1555`). La implementacion se ejecuto despues y quedo **commiteada en `586c606 "rastro qr"`**. Registrado en `DECISIONS.md` ADR-064 (ANEXO), `TASKS.md` TSK-082 y `NEXT.md` hito -30.

