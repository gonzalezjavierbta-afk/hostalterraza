---
doc: E14 (ERRORES_HISTORICOS.md §14)
version: v1.8.0-STABLE (heredada)
fecha: 2026-10-01
origen: ERRORES_HISTORICOS.md L184-198 (AMPLIACION/_backups/ERRORES_HISTORICOS.md.2026-10-01.bak)
version_previa: ERRORES_HISTORICOS.md v1.8.0-STABLE
relacionados: [../ERRORES_HISTORICOS.md, ../INDEX.md]
estado: vigente
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [ERRORES_HISTORICOS.md](../ERRORES_HISTORICOS.md) §14 · [INDEX](../INDEX.md). Texto original íntegro debajo (L184-198 del original).

## 14. Diagnostico Falso y Deriva de Valores en el Silo F9B "Mistico Nocturno" (2026-09-26 — paquete ADR-054/055/056/057)

### El clon muerto por SCOPE, no por CASING (diagnostico inicial FALSO)
* **Problema:** `css/templates/fiesta/f9b.css` nacio como clon de `f9` y, en su estado original, **no aplicaba ninguna regla**: el evento se renderizaba sin estilo de silo (modulos ocultos por el IoC global de `evento-app.html:30`/`:33`). El diagnostico inicial (documentado en la primera redaccion de ADR-054) atribuyo la causa al **casing**: afirmaba que el kernel escribia `Tpl-F9b` y que por eso `.tpl-f9`/`.Tpl-F9` no matcheaban.
* **Causa raiz real (verificada, ADR-006):** el kernel escribe SIEMPRE `tpl-` + `template_id` tal cual + su minuscula (**`evento-app.html:998-1000`**), asi que con `template_id='f9b'` el body queda **`tpl-f9b tpl-f9b`** — **nunca `Tpl-F9b`** (grep case-sensitive `Tpl-` en `evento-app.html` = 1 coincidencia, y es un comentario en `:760`). **La causa era el SCOPE:** `.tpl-f9` **no matchea** `tpl-f9b` (no es sufijo convertible; son tokens distintos). El fallo era de cobertura de scope, no de casing.
* **Leccion:** cuando un silo "no aplica", **lo primero es grep del scope exacto contra la clase REAL del body**, no inferir el casing. Dos consecuencias duraderas: (a) el subproducto de esta verificacion es que **toda la mitad `.Tpl-*` de los silos es codigo muerto** (ver `ADR-057` y la seccion 15); (b) la redaccion original de ADR-054 se conservo y corrigio sin reescribir (patron ADR-006).

### Deriva de valores: el ADR citaba cifras y lineas que no coincidian con el archivo
* **Problema (patron transversal, ver §7/§8/§13):** los ADR de la triada citaban valores desincronizados con el archivo real. Casos verificados y corregidos el 2026-09-26: (1) ADR-054 citaba `f9b.css` como "**339 lineas / 642 ocurrencias de scope**"; **real: 2922 lineas / 369 `.tpl-f9b` + 365 `.Tpl-F9b` = 734**. (2) Citas de `className` `:836-838` -> **`:998-1000`**; efecto `:848` -> **`:1010`**; `__esF9Meta` `:914` -> **`:1149`**; `__esFamiliaF9` `:738-740` -> **`:766-773`**; `__esSiloF9Rastro` `:747-748` -> **`:780-782`**. (3) ADR-056 decia `openEditMod` "NO EXISTE" — **SI existe** (`admin.html:5203`); lo inexistente era `editarEvento()`. (4) ADR-056 `:5071` -> **`:5203`**, `L4051` -> **`:4153`**, `L5321` -> **`L5461`**, poster `:1383` -> **`:1599`**. (5) ADR-056 daba `2026-10-24` como viernes ("Viernes 24"): es **sabado**; el formateador real (`__formatoFechaLarga`, `evento-app.html:852-862`) devuelve `{"l1":"Sabado 24","l2":"octubre de 2026"}`. (6) Citas falsas tipo "425/425" inexistente y "Tpl-F9b" que el kernel nunca emite.
* **Causa raiz:** redactar el ADR durante/antes de la implementacion, mirando una version previa del archivo, sin re-verificar cada cita al cerrar. Es exactamente el patron que advierten §7 ("comentario que documenta una decision que el codigo no implementaba") y §8/§13 (valores documentados que el codigo real no reproduce).
* **Blindaje:** al cerrar cualquier ADR, **re-ejecutar un `grep` por cada linea citada** contra el archivo real (ADR-006) y corregir las citas en el mismo cierre. Un ADR es baseline solo si sus citas resuelven; si no, propaga la deriva a todo el equipo.
* **Verificacion:** corregido en `DECISIONS.md` (notas R-054-bis, R-055-bis, R-056-bis, y ADR-057 nuevo) el 2026-09-26; `TEMPLATES.md` v1.6.0 con el aviso capital-T.

---

