---
doc: ADR-029
version: v1.16-GOLD (heredada de DECISIONS.md)
fecha: 2026-10-01
origen: DECISIONS.md L340-358 (AMPLIACION/_backups/DECISIONS.md.2026-10-01.bak)
version_previa: DECISIONS.md v1.16-GOLD
relacionados: [../DECISIONS.md, ../INDEX.md]
estado: vigente (ver campo Estado dentro del ADR)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [DECISIONS.md](../DECISIONS.md) · [INDEX](../INDEX.md). Texto original íntegro debajo (L340-358 del original).

#### ADR-029: Auditoría Null Pointer Completa de admin.html (Extensión de ADR-024 a Todo el Archivo)
* **ID:** ADR-029 | **Fecha:** 12 de agosto de 2026 | **Estado:** Aprobado — 11 puntos de crash corregidos en `admin.html` con el patrón Silent Fallback `(campo||'')`.
* **Reporte:** TSK-023 (pendiente de priorización tras ADR-024): "el mismo patrón de riesgo (métodos de string sin blindar sobre campos de Supabase) podría existir en `renderEventos()`/`renderInvitadoresPerfil()` (Admin, ADR-022) y en el resto del archivo no auditado en la sesión de ADR-024".
* **Diagnóstico (barrido completo, no por suposición):** se grepearon todos los `.replace(`, `.split(`, `.toUpperCase()`, `.toLowerCase()`, `.localeCompare(`, `.substr(`, `.slice(`, `.length` e `.includes` sobre campos que provienen de Supabase en las ~7973 líneas de `admin.html`, y se leyeron los contextos de cada candidato para distinguir crash real vs. guardado previo (filtro `if(campo)` o `||''`). Los que ya estaban protegidos se dejaron intactos (p. ej. `list.filter(i=>i.used&&i.hora_ingreso)` antes de `.split(':')` en panel/scanner, `tokens()` con `norm(s||'')`, comparadores con `(fecha||'').localeCompare`). Resultado: **11 puntos de crash reales**, ninguno reportado aún por usuario pero todos disparables con un registro de la org "Barrio R10" (inscritos incompletos) o campos `null` del esquema:
  1. `renderEventos()` (Historial, ADR-022): L3516 (`s.nombre.replace` en `onclick` de `openMod` de sesiones) y L3539 (`e.nombre.replace` en `onclick` de `openMod` de eventos sueltos).
  2. `renderInvitadoresPerfil()` (Invitadores, ADR-022): L4281 (`g.nombre.split` para iniciales del avatar).
  3. `abrirPerfilInvitador()`: L4309 (`grupo.nombre.split`) y L4349 (`l.link_generado.split('slug=')`).
  4. `renderDirectorio()`: L5012 (`p.nombre.split`).
  5. Panel de duplicados: L4931/32 (`p.a.nombre.split(' ')[0]` / `p.b.nombre.split`).
  6. `showVerify()` de Admin (scanner embebido): L5497 (`ins.nombre.split`).
  7. `descargarInvitacion()`: L5359 (`ev.nombre.replace` en el nombre del archivo).
  8. Export de eventos (`_xlsxEventos`): L6467 (`ev.nombre.replace` en el nombre de hoja).
  9. Gráficas globales de System Admin: L2912 (`o.nombre.length`/`.slice` en labels del chart).
  10. Búsqueda global: L3205 (`inv.codigo.includes`).
* **Decisión:** aplicar el patrón de ADR-024 — precalcular donde haya usos múltiples, `(campo||'')`/`(campo||'—')` inline donde sea puntual — y blindar además las interpolaciones que renderizaban el texto literal `"null"` en las dos funciones del mandato (historial de eventos: `serie.nombre`/`e.nombre`/`e.fecha`/`s.fecha`; perfil de invitador: `g.nombre`/`grupo.nombre`/`l.tipo_invitado`/`ev.nombre`) y en los puntos de crash adyacentes (`pi-nombre`/`pi-codigo`/labels de duplicados). Los fallbacks de display usan `||'—'` (dato incorrecto visible) y los de lógica/crash `||''` (no altera la operación).
* **Justificación:** extensión natural de ADR-024 que su propio documento recomendaba explícitamente (punto "Alcance no cubierto"). No es regresión de ADR-022/023 (funciones no tocadas desde entonces, el bug es preexistente). Cero Borrado intacto — solo blindaje de interpolaciones, sin eliminar IDs ni elementos.
* **Verificación:** `node --check` sobre el JS inline (OK); prueba funcional aislada con los 13 patrones parcheados y entradas `null` (13/13 sin `TypeError`); balance de `<div>` 0 (760 opens / 760 closes). No se requirió cambio SQL.
* **⚠️ Alcance restante (señalado para Dirección):** `index.html`, `qr.html`, `evento.html`, `evento3.html`, `registro.html`, `serie.html` no fueron auditados con este patrón. `scanner.html` quedó blindado parcialmente en TSK-005. Siguiente candidato recomendado: `evento3.html` (motor público "El Cerebro", ~6K líneas).

