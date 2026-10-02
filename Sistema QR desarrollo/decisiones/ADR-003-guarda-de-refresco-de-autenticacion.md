---
doc: ADR-003
version: v1.16-GOLD (heredada de DECISIONS.md)
fecha: 2026-10-01
origen: DECISIONS.md L20-25 (AMPLIACION/_backups/DECISIONS.md.2026-10-01.bak)
version_previa: DECISIONS.md v1.16-GOLD
relacionados: [../DECISIONS.md, ../INDEX.md]
estado: vigente (ver campo Estado dentro del ADR)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [DECISIONS.md](../DECISIONS.md) · [INDEX](../INDEX.md). Texto original íntegro debajo (L20-25 del original).

#### ADR-003: Guarda de Refresco de Autenticación (onAuthStateChange)
* **ID:** ADR-003 | **Fecha:** Mayo 2026 | **Estado:** Aprobado y En Producción.
* **Problema:** Supabase refrescaba el JWT automáticamente, disparando el evento SIGNED_IN y reseteando el ORG_ID a null en medio de la sesión[cite: 1].
* **Decisión:** Implementar una guarda lógica para ignorar eventos TOKEN_REFRESHED si ya existe una sesión activa identificada (!currentUser).
* **Justificación:** Previene interrupciones en la interfaz administrativa y mantiene la continuidad operativa[cite: 1].

