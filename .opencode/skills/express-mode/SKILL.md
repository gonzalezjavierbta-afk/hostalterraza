---
name: express-mode
description: >
  Ejecuta cambios de HostalTerraza (Sistema QR) en "modo express/xpress":
  prioriza el cambio funcional, delega briefs quirurgicos por dominio, usa
  verificacion minima proporcional al riesgo y difiere la documentacion al
  cierre de sesion. Usalo cuando el usuario pida express/xpress/rapido.
---

# Express Mode (xpress)

Modo de trabajo **rapido, dirigido y proporcional al riesgo** para HostalTerraza: se prioriza el cambio funcional, se verifican solo los puntos que pueden romperse y se difiere todo lo no critico (documentacion, refactors, pruebas end-to-end, backfill de datos) al cierre de sesion.

> Skill **transversal**: rige toda la sesion por encima de cualquier dominio y de cualquier ruta (gratuita `*-free` o de pago). No sustituye al Escudo GOLD ni a las reglas anti-absorcion (ADR-031): cambia el **orden** y la **profundidad** de los controles, no los elimina.

## Cuando usar

- El usuario pide explicitamente "**express**", "**xpress**" o "**rapido**".
- Cambios acotados: 1 a 3 archivos criticos, sin tocar datos ni seguridad.
- Ajustes de UI/UX, textos, wiring de frontend, fixes puntuales de backend.

## Cuando NO usar (escalar a modo normal)

- Cambios de **arquitectura** (nuevos modulos, contratos entre capas).
- **Esquema / RLS / seguridad** (permisos, autenticacion, exposicion de datos) -> escalar SIEMPRE a `@sql-security` (prohibido `@sql-security-free`).
- **Migraciones de datos** o backfill destructivo.
- **Refactors compartidos** (helpers con varios consumidores: `js/i18n.js`, `api/evento-og.js`, el motor `CATEGORY_TAG_FIELDS`/`CATEGORY_TAG_LISTS` de `admin.html`).
- Alcance amplio: **> 3 archivos criticos** o **> 10 archivos en total**.

> Regla: si el cambio puede romper runtime de forma silenciosa o toca datos/seguridad, no es express.

### Archivos criticos del repo (gate de alcance)

| Archivo | Por que es critico |
|---|---|
| `admin.html` | Monolito de ~10.000 lineas; balance de divs ya desviado (+3). Motor generico `CATEGORY_TAG_FIELDS`/`CATEGORY_TAG_LISTS` |
| `scanner.html` | Flujo QR operativo (asistencia/validacion) |
| `index.html` | Entrada publica; carga `js/i18n.js` |
| `eventovenezuela.html` | Motor publico real de evento (silo `b5`) |
| `api/*.js` | Serverless Vercel Hobby (hoy: `api/evento-og.js`) |
| `js/i18n.js` | Internacionalizacion compartida (46+ consumidores) |
| `migrations/*.sql` | Esquema y RLS |
| `vercel.json` | Rewrites de slugs (`/evento.html` -> `/api/evento-og`) |

**Anidacion de contenedores dinamicos = riesgo silencioso.** Antes de anidar, preguntar: *quien reescribe el `innerHTML` de este contenedor y a quien se lleva por delante?* Si el cambio anida contenedores o altera runtime, el **QA runtime es obligatorio** aunque el resto este verde.

## Flujo express paso a paso

1. **Spec inline minima.** Una linea: que se cambia, en que archivo y criterio de exito.
2. **Lectura dirigida.** `grep` del ancla + `read` con `offset`/`limit`. `@explore-free` solo si es imprescindible (p. ej. contar consumidores de un ancla).
3. **Brief quirurgico de delegacion.** Un subagente por dominio con rutas + numeros de linea + bloque `old`/`new` exacto (ver plantilla).
4. **Ejecutar cambios minimos**, de bajo riesgo primero. Reusar componentes/helpers; extraer modulo compartido en vez de duplicar (Regla de No-Duplicidad, tripwire de 5 lineas).
5. **Paralelizar** solo tareas independientes (varios `task` en un mismo mensaje); respetar dependencias.
6. **Verificacion local minima** (checklist de 6 puntos). QA runtime obligatorio si se anidan contenedores dinamicos.
7. **Registrar deuda** con etiquetas en `NEXT.md` / items en `TASKS.md` (no arreglarla durante express).
8. **Cierre documental en un solo pase** al final.

## Ruteo de delegacion en express

| Dominio | Subagente FREE (operacion diaria) | Par PRO (respaldo) |
|---|---|---|
| `admin.html`, `scanner.html` | `@admin-dev-free` | `@admin-dev` |
| `api/*.js` | `@backend-dev-free` | `@backend-dev` |
| CSS de silo / `eventovenezuela.html` | `@frontend-tpl-free` | `@frontend-tpl` |
| `js/*.js` rutinario | `@js-silo-dev-free` | `@js-silo-dev` |
| SQL / RLS / migraciones | `@data-migration-free` | `@sql-security` (obligatorio en seguridad critica) |
| Exploracion puntual | `@explore-free` | `@explore` |
| Cierre documental | `@docs-keeper-free` | `@docs-keeper` |
| Certificacion (solo si rompe runtime) | - | `@qa-auditor` (solo lectura) |

## Plantilla de "brief express"

    ## Brief express - <dominio: backend|frontend|admin|renderer|sql|i18n>
    Archivo(s): <ruta exacta>
    Ancla exacta: <archivo>:L<inicio>-L<fin> (+ 3 lineas previas para ubicar)
    OLD (bloque exacto a reemplazar):
    <...>
    NEW (bloque exacto de reemplazo):
    <...>
    Restricciones: no duplicar bloques > 5 lineas (Regla de No-Duplicidad),
      no catch vacios, ASCII-safe en api/*.js (cero bytes > 127, cero backticks,
      cero doble escape \u), no eliminar IDs del Contrato de Datos (Cero Borrado).
    Verificacion esperada: node --check + ASCII-safety + balance de divs + grep de residuos.
    Dependencias: <ninguna | que otro cambio debe ir primero>.

## Checklist de verificacion minima (6 puntos)

1. **Sintaxis:** `node --check` sobre cada `.js` tocado (API, `js/` o script).
2. **ASCII-safety:** en `api/*.js`, 0 bytes > 127, 0 backticks, 0 doble-escape `\u`.
3. **Balance de divs:** de cada HTML clave modificado (diferencia 0 respecto al baseline; hoy `admin.html` +3 e `index.html` +1 son preexistentes).
4. **Residuos:** `grep` de ids/funciones/anclas eliminadas (0 fuera de alcance).
5. **Smoke puntual:** si existe un smoke del area, correrlo y distinguir fallo preexistente de regresion nueva.
6. **Runtime/QA:** obligatorio cuando se anidan contenedores dinamicos o se altera runtime; opcional si el resto esta verde.

> Escudo GOLD formal (`gold-shield`) y QA de subagente (`@qa-auditor`): solo cuando el cambio puede romper runtime.

**Comando unico:** `node scripts/express_check.js` (set por defecto) o `node scripts/express_check.js <archivos...>`.

## Que se difiere

- Documentacion (`TASKS.md`, `NEXT.md`, `DECISIONS.md`, ADR, `ERRORES_HISTORICOS.md`).
- Refactors de deuda colateral y limpieza de codigo muerto (JS muerto, backups con anclas como `admin bacup.html` o `evento backup para formulario.html`).
- Pruebas end-to-end reales contra Neon/produccion (las corre el operador; no hay `DATABASE_URL` local).
- Backfill/lectura de datos: se entrega un script read-only `scripts/diagnose_*.js` + un `migrations/*.sql` idempotente **para que lo corra Direccion**.

## Cierre documental (un solo pase)

Al terminar la ultima tarea:

1. `Sistema QR desarrollo/TASKS.md`: actualizar **Estado** + nota de cierre con el **alcance real ejecutado**.
2. `Sistema QR desarrollo/NEXT.md`: entrada de relevo ("Que se estaba haciendo" + "Que sigue" + "Riesgos activos").
3. `Sistema QR desarrollo/DECISIONS.md`: nuevo ADR solo si hubo una decision de arquitectura.
4. `Sistema QR desarrollo/ERRORES_HISTORICOS.md`: registrar la falla **antes** de cerrar, si aparecio una.
5. Dejar la deuda etiquetada en `NEXT.md` (por ejemplo `[DEUDA-EXPRESS]`).

Manual ampliado: `DOCUMENTOS/MODO_EXPRESS_ANALISIS.md` (copia de registro del skill en `DOCUMENTOS/SKILL_MODO_EXPRESS.md`).