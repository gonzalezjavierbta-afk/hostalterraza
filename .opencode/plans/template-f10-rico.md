# Plan: Template F10 "Rico" - Cyberpunk Fosforescente (v2.0.0)

**Fecha:** 2026-09-15
**Solicitante:** Usuario (evento rico-5mw5 en produccion, template f10, categoria fiesta)
**Estado:** COMPLETADO - reescritura total SOLO-CSS de `css/templates/fiesta/f10.css` (v2.0.0).
Unico archivo tocado del repo: `f10.css` (ningun otro archivo fue modificado).
Cierre documental: `Sistema QR desarrollo/DECISIONS.md` ADR-042, TASKS.md TSK-032, NEXT.md hito -8.

---

## Diagnostico (escritura original v1.0.0)

| Problema en v1.0.0 | Detalle verificado (ADR-006) |
|---|---|
| Lineup sin estilos reales | v1.0.0 estilizaba selectores propietarios `.f10-lc-grid` / `.f10-artist*` que el kernel de `evento.html` JAMAS genera: el DOM real usa `.artist-card`, `.artist-photo`, `.artist-overlay`, `.artist-name`, `.artist-hora`, `.artist-resena`, `.artist-social`, `.artist-social-icon` y `.artist-card.headliner` (mismos selectores kernel que f8/f9). Resultado: el lineup se renderizaba sin CSS del silo (bug visual). |
| Selectores muertos | `.f10-artist*` y `.f10-lc-*` no existen en el DOM; Cero Borrado verificado: son exclusivos de f10, retirarlos no afecta a ningun otro silo. |
| Galeria estatica | `#db-gallery-grid` fue disenada para un numero fijo de bloques (nth-child ciclico); no soporta un N abierto de espacios. |
| Breakpoints | La cabecera declaraba 640/767/992/1279; el archivo usa tambien 768 (galeria 2 col en mobile). Breakpoints reales: 640/767/768/992/1279. |

## Objetivo v2.0.0 (solo CSS)

1. Lineup estilado 100% sobre selectores kernel reales (lista en tabla superior) + `.artist-card.headliner`.
2. Galeria `#db-gallery-grid` como maqueta de espacios: grid de N abierto `repeat(auto-fill, minmax(...))` con placeholders glow (celda figure con marco fosforescente + gradiente neon visible aunque falte la foto - ADR-008) y tinte hover ciclico por celda.
3. Cero selectores muertos: retirar `.f10-artist*` / `.f10-lc-*`.
4. ASCII-safety estricto: 0 bytes > 127 en todo el archivo.
5. Tipografia Geist 900 display (cargada de forma asincrona por el kernel; sin @import bloqueante).
6. IoC conservada: bloque de activacion/off de modulos intacto.
7. `prefers-reduced-motion` conservado (accesibilidad).
8. Descripcion (`.artist-resena`) con estilado minimo line-clamp 2 (antes hidden).

## Decisiones del usuario

| Decision | Eleccion |
|---|---|
| Alcance | SOLO CSS: unico archivo tocado `css/templates/fiesta/f10.css` (v2.0.0); NINGUN otro archivo del repo se modifica |
| Evento | `rico-5mw5` en produccion, template f10, categoria fiesta (dato de Supabase, fuera del repo) |
| Lineup | Con foto desde admin: `config_landing.content.dj_lineup` con `{nombre, foto...}`; el silo estiliza `.artist-photo` (foto) y `.artist-resena` en line-clamp 2 |
| Galeria | Maqueta de espacios: grid de N abierto (auto-fill) con placeholders glow mientras no haya foto |
| Estetica | "Cyberpunk Fosforescente" - triada neon fucsia #ff2a85 / amarillo #ffe500 / turquesa #00f0ff sobre fondo purpura #0f021e |

## Lista de chequeo - Escudo GOLD

- [x] Sintaxis: N/A (solo CSS, sin JS) - sin @import bloqueante
- [x] ASCII-safety: 0 bytes > 127 (escaneo de bytes del archivo real)
- [x] Balance de llaves y comentarios en equilibrio
- [x] Cero Borrado: ningun modulo/ID del kernel retirado; solo selectores propietarios muertos de v1.0.0
- [x] Cero selectores muertos: todos los selectores apuntan a clases/ids reales del DOM de `evento.html`
- [x] Aislamiento atomico: todo bajo `.tpl-f10` / `.Tpl-F10`
- [x] Breakpoints reales verificados: 640 / 767 / 768 / 992 / 1279
- [x] Lineas totales verificadas al cierre documental: 1801 (cabecera declara 1802)
- [x] Log de versiones del pie actualizado (fila v2.0.0 canonica, 15/09/2026)

## Despliegue

El silo se carga dinamicamente por el kernel de `evento.html`: linea 600 inyecta
`css/templates/{categoria}/{template_id}.css` y las lineas 692-693 aplican
`tpl-{template_id}` al body. Para el evento `rico-5mw5`
(`categoria_slug='fiesta'`, `template_id='f10'` en Supabase) el motor carga
`css/templates/fiesta/f10.css` y aplica `tpl-f10`. Desplegar el archivo en
produccion (Vercel) es suficiente; no requiere migracion SQL ni cambios de
`admin.html`.

- [x] `css/templates/fiesta/f10.css` v2.0.0 en produccion
- [x] URL publica: `https://hostalterraza.vercel.app/evento.html?slug=rico-5mw5`

## Pendiente (no cubierto en este plan)

- Registrar el theme `rico` en `admin.html` (`_THEME_TYPE` / `_THEME_TPL` / card del
  Wizard) si Direccion quiere crear/editar eventos f10 por el Wizard: hoy el silo
  solo aplica por `template_id='f10'` directo en Supabase (mismo estado que tenia
  `mistico` antes de ADR-041).
- Verificacion visual (Prueba de Carga Dual) por Direccion sobre `rico-5mw5`.
- Cargar fotos de artistas en `config_landing.content.dj_lineup` para aprovechar
  `.artist-photo` (pendiente heredado tambien de F9).