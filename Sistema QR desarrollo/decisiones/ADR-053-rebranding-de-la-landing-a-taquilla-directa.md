---
doc: ADR-053
version: v1.16-GOLD (heredada de DECISIONS.md)
fecha: 2026-10-01
origen: DECISIONS.md L912-980 (AMPLIACION/_backups/DECISIONS.md.2026-10-01.bak)
version_previa: DECISIONS.md v1.16-GOLD
relacionados: [../DECISIONS.md, ../INDEX.md]
estado: vigente (ver campo Estado dentro del ADR)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [DECISIONS.md](../DECISIONS.md) · [INDEX](../INDEX.md). Texto original íntegro debajo (L912-980 del original).

#### ADR-053: Rebranding de la landing a Taquilla Directa + sistema de tokens

* **ID:** ADR-053 | **Fecha:** 2026-09-24 | **Estado:** IMPLEMENTADO (2026-09-24) - APROBADO por Direccion (2026-09-24) y luego IMPLEMENTADO en el working tree (SIN commit). Decision de marca y sistema de tokens cerrada y ejecutada. QA `@qa-auditor` (Escudo GOLD) **APTO, 0 bloqueantes**. Archivos cambiados (verificados contra el archivo real, patron ADR-006): `index.html` (Fase 1: tokens `.htz` + head/title/meta/favicon/OG + header con logo nuevo + nav Cartelera/Como Funciona/Silos Visuales/Planes B2B/Contacto + hero split-screen `id="hero"` con `assets/hero-concert.jpg` y buscador protagonista `#event-search-input`/`#btn-hero-search`/`#search-pills` + badge verde `#00FF66` "Acceso Directo Validado" + footer con logo); `planes-precios.html` (Fase 2: tokens `.ppz` + logo + favicon + OG + title con key `planes.title`); `js/i18n.js` (9 keys x 3 idiomas - `common.hostal`, `index.title`, `index.nav.*`, `index.footer.bottom2`, `serie.title`, `reg.title`, `serie.no_encontrado_dup` - + `index.login.acceso` = "Acceso Team"/"Acces equipe"/"Team Access" + key nueva `planes.title` + switcher de idiomas repaletizado sin dorado); `assets/` (carpeta NUEVA: `logo-taquilladirecta.png`, `logo-isotipo.png`, `favicon-64.png`, `favicon-128.png`, `og-taquilladirecta.png`, `hero-concert.jpg` con licencia Unsplash, `README-assets.txt`). Evidencia de verificacion (ADR-006): `node scripts/express_check.js` -> PASS 10 / FAIL 0; `node --check` OK; balance de divs sin regresion (diff `index.html` = 1 = baseline preexistente documentado en `express_check.js`); 34 IDs preservados + 4 IDs nuevos del hero; UTF-8 sin mojibake; 1 foto de banco gratuito (licencia Unsplash). DECISIONES DE DIRECCION aplicadas: paleta hibrida (turquesa #00E5D5 del manual de marca + verde #00FF66 semantico), hero con foto de concierto, logo PNG tal cual, alcance `index.html` + `planes-precios.html`, rebrand total del nombre y categorias reales del codigo conservadas. PENDIENTE: commit del working tree + deploy a Vercel (accion de Direccion). NOTA: la subseccion "Pendientes" mas abajo se conserva como historial del plan original (Cero Borrado); el estado real es IMPLEMENTADO.
* **Autor:** Chief Architect / `@architect` PRO (decision tomada con Direccion). Registro documental por el equipo de documentacion.
* **Problema:** la landing publica (`index.html`) nace con la identidad "Hostal Terraza": paleta dorada (`--gold:#E3B457`) sobre fondos calidos casi negros (`--hbg:#0B0A09`), comentario de cabecera "HOSTAL TERRAZA - PORTAL v1.0.0" (L13 real) y un wordmark que resaltaba un tramo con `--gold` (`.htz-logo-name b{color:var(--gold)}`, L40 real). Direccion aprobo un brand board nuevo para la marca **"Taquilla Directa"** (`taquilladirecta.com`) con un sistema cromatico hibrido (navy + turquesa de marca + verde semantico de verificacion QR) y un manual de marca formal (regla del wordmark, reglas de uso del logo, isotipo focus-frame, 8 variaciones cromaticas). Sin tokens documentados, cualquier agente podria "rebrandear" a mano, duplicar colores sueltos fuera del contenedor, tocar IDs del DOM o pisar los colores por evento que hoy vienen de Supabase.
* **Opciones evaluadas:**
    1. **Opcion A (RECHAZADA) - reescribir `index.html` desde cero con la marca nueva:** coste alto, alto riesgo de perder IDs/bindings del JS (contadores, filtros, formulario, chips de categoria) y contradice el principio de Cero Borrado; ademas abriria divergencia estructural con `planes-precios.html`.
    2. **Opcion B (ELEGIDA) - rebranding por TOKENS dentro de los contenedores existentes (`.htz` en `index.html`; `.ppz` en `planes-precios.html`), con mapeo 1:1 de las variables actuales y conservacion integra del DOM/IDs:** se reemplazan exclusivamente valores y nombres de tokens CSS; cero IDs retirados; cero cambios de estructura; 0 endpoints; 0 migraciones.
    3. **Opcion C (RECHAZADA) - tema alterno conmutables (selector de marca):** la marca es unica y definitiva; un conmutador introduce deuda, duplica el sistema de tokens y no aporta valor al usuario.
* **Decision:**
    1. **Marca y dominio:** marca "Taquilla Directa", dominio canonico `taquilladirecta.com`. Alcance del rebranding: **Fase 1 `index.html`**; **Fase 2 `planes-precios.html`**. Ningun otro archivo.
    2. **Sistema de diseno aprobado (tokens, definidos SIEMPRE dentro del contenedor padre; Aislamiento Atomico = Reglas de Oro #9 / PROJECT.md):**
        - `--bg-base: #050D10` (navy casi negro, fondo principal).
        - `--bg-navy: #001B1F` (navy estructural del manual).
        - `--bg-surface: #0A1C22` (superficie/tarjetas elevadas).
        - `--accent-cyan: #00E5D5` (acento de marca del manual; botones/foco).
        - `--accent-green: #00FF66` (color **SEMANTICO** de verificacion QR valida; del brief). **NO es una de las 8 variaciones cromaticas del manual.**
        - `--cream: #F9F7F2` (texto principal sobre oscuro).
        - `--border-glass: rgba(255,255,255,0.08)`.
        - `--font-display: 'Anton','Archivo Black',sans-serif` (wordmark/titulares).
        - `--font-main: 'Space Grotesk','Inter',system-ui,sans-serif` (cuerpo/UI).
    3. **Convenciones de mapeo (variables `.htz` REALES verificadas en `index.html` L14-17 -> tokens nuevos). Regla: no se retira ninguna variable sin reemplazar todos sus consumidores en el mismo cambio; el binding JS que las consume se conserva:**
        - `--hbg` (`#0B0A09`) -> **`--bg-base`** (`#050D10`). Fondo principal.
        - `--hbg2` (`#14110C`) -> **`--bg-navy`** (`#001B1F`). Fondo estructural secundario.
        - `--hpanel` (`#17130D`) -> **`--bg-surface`** (`#0A1C22`). Superficie/tarjetas elevadas.
        - `--hline` (`rgba(227,180,87,.18)`) -> **`--border-glass`** (`rgba(255,255,255,0.08)`). Bordes/divisores.
        - `--gold` (`#E3B457`) -> **`--accent-cyan`** (`#00E5D5`). Acento unico de marca (botones/foco/realces).
        - `--gold2` (`#C8903F`) -> **`--accent-cyan`** (`#00E5D5`). El acento de marca es UNO: `--gold2` se pliega (si en el futuro se necesita un tono apagado, se deriva de `--accent-cyan`, no se crea token nuevo sin ADR).
        - `--cream` (`#F5EFE2`) -> **`--cream`** (`#F9F7F2`). Mismo nombre, valor del brief.
        - `--mut` / `--mut2` / `--mut3` (alphas de cream) -> **derivados** de `--cream` (`rgba(249,247,242, ...)`). Sin token nuevo aprobado: se mantienen como derivados, pero DEBEN recalcularse al nuevo `--cream` para no arrastrar el alpha del color viejo.
        - `--cin` (`#7FA6E0`) -> **variacion 02 AZUL ELECTRICO** (acento de categoria cine).
        - `--camp` (`#E0816B`) -> **variacion 03 CORAL** (acento de categoria campana).
        - `--r` / `--rsm` (`20px` / `10px`) -> **sin cambio**.
        - `--acd` / `--med-bg` -> **sin cambio**: son data-driven (`color_primario` del evento). **Prohibido** pisarlos con el rebranding.
        - Tipografia: `'Anton'` -> **`--font-display`**; `'Space Grotesk'` -> **`--font-main`**. La carga adicional de `Archivo Black` / `Inter` es aditiva (webfont con fallback declarado) y no rompe las familias base.
    4. **Regla del wordmark (del manual):** SOLO la palabra **"DIRECTA"** lleva el color de acento (`--accent-cyan`); **"TAQUILLA"** y **".COM"** en color base (`--cream`). El markup actual ya resalta un tramo con `<b>` (`.htz-logo-name b{color:var(--gold)}`, L40; espejo `.ppz-logo-name b{color:var(--gold)}`, `planes-precios.html` L38). Se reutiliza ese `<b>` envolviendo UNICAMENTE "DIRECTA"; la regla pasa a `color:var(--accent-cyan)`. **Sin IDs nuevos, sin cambios de estructura del DOM.**
    5. **Reglas de uso del logo (del manual, obligatorias para todo agente):** no deformar, no recolorear, no alterar la proporcion, no quitar elementos; **zona de proteccion = altura del simbolo**; **minimo 20 mm** en la version con wordmark.
    6. **Isotipo:** focus-frame tipo visor QR (4 escuadras + cuadro central). Derivados aprobados: favicon del isotipo, imagen OG, variante invertida. El logo PNG se usa **tal cual** (no se regenera por CSS; Silent Fallback ADR-008 en los `<img>`).
    7. **8 variaciones cromaticas del manual y mapeo PROPUESTO a categorias de evento (las 3 categorias reales del landing son `fiesta`, `cine`/`cinematografia` y `campana` - verificadas en `CATS`, `index.html` L624-629, y en los chips `data-cat`, L381-384):**
        - **01 TURQUESA** (`#00E5D5`/`#001B1F`/`#F9F7F2`) -> **Sistema / marca** (default global de la landing; NO es categoria).
        - **02 AZUL ELECTRICO** -> categoria **cine / cinematografia** (hook: `CATS.cine.color` y `CATS.cinematografia.color`).
        - **03 CORAL** -> categoria **campana** (hook: `CATS.campana.color` y `--camp`).
        - **04 VIOLETA** -> categoria **fiesta** (hook: `CATS.fiesta.color`).
        - **05 VERDE LIMA** -> reservada (futura categoria; candidata: musica/sostenibilidad).
        - **06 AMARILLO** -> reservada (futura categoria; candidata: gastronomia/cultura).
        - **07 NARANJA** -> reservada (futura categoria; candidata: artes escenicas/teatro).
        - **08 ROJO** -> reservada (futura categoria; candidata: causa social/emergencia).
        - La asignacion de las 3 categorias reales es la unica parte VINCULANTE; 05-08 quedan como reserva documentada y requieren ratificacion de Direccion. `--accent-green` NO entra en esta tabla (es semantico de verificacion QR, no de categoria).
    8. **Consecuencias / reglas obligatorias:**
        - **Cero Borrado de IDs (Regla de Oro 3 / ADR-003):** no se elimina ni renombra ningun `id`, `data-*`, clase o atomo del DOM; el rebranding es de tokens, no de estructura. Los bindings JS (contadores `.htz-cd`/`.ppz-cd`, filtros `.htz-chip-cat[data-cat]`, formulario, `#count-pas`) siguen intactos.
        - **CSS aislado bajo el contenedor padre (Aislamiento Atomico = Reglas de Oro #9 / PROJECT.md):** todos los tokens y reglas nuevas viven bajo `.htz` (`index.html`) y `.ppz` (`planes-precios.html`); nada suelto en `:root` global. No se crea silo ni template nuevo.
        - **Hallazgo de baseline (ADR-006):** `planes-precios.html` NO comparte contenedor con `index.html`; usa `.ppz` con su PROPIA copia de los tokens (`--hbg`, `--hbg2`, `--hpanel`, `--hline`, `--gold`, `--gold2`, `--cream`, `--mut` en L13-14). El mapeo debe aplicarse DOS veces, una por contenedor, en dos pases controlados.
        - **`--acd` intocable:** el color por evento sigue fluyendo de `color_primario` (`normalizarEvento()`, `index.html` L655) aplicado como `style="--acd:..."` (L693). El rebranding NO pisa colores por evento.
        - **Distincion categorias-estaticas vs color por evento (aclaracion):** los acentos de CATEGORIA son estaticos del sistema de diseno (tokens `.htz` `--cin`/`--camp` y colores `CATS.*.color` en `index.html` L624-629) y **SI se actualizan** con el rebranding (mapeo 02-04 del punto 2.7); en cambio el color POR EVENTO llega de datos (`color_primario` de Supabase) via `--acd` y **NO se toca**. Son capas distintas: categoria = diseno del sistema; evento = dato del usuario.
        - **Presupuesto Vercel Hobby 8/8:** 0 endpoints nuevos; el rebranding es 100% estatico (HTML/CSS/assets).
        - **Silent Fallback (ADR-008):** toda imagen/derivado de logo dinamico lleva `onerror` a un fallback.
        - **ASCII-safe (ADR-002):** en cualquier archivo serverless tocado indirectamente, mantenerse ASCII-safe (no aplica directamente a `index.html`/`planes-precios.html`, que son estaticos).
* **Justificacion:** (1) La Opcion B preserva los tres principios que definen el proyecto: Cero Borrado (ningun ID/atomo se retira), Aislamiento Atomico (tokens dentro del contenedor, no en `:root`) y Data-First (el rebranding es estetica de Fase II sobre una Fase I ya certificada; no cambia datos). (2) El wordmark reutiliza el `<b>` ya existente en la estructura del logo: la regla "solo DIRECTA en acento" se cumple con 0 cambios de DOM. (3) Se separa `--accent-green` como token SEMANTICO de verificacion QR (no de categoria ni de marca) para que un futuro ajuste de marca no reinterprete el estado "QR valido"; por eso queda fuera de las 8 variaciones. (4) El mapeo de categorias usa el UNICO hook de color ya existente (`CATS` y `--acd`), sin crear logica nueva; 05-08 se reservan para no inventar categorias que no existen. (5) Fijar el mapeo `.htz`/`.ppz` evita que un agente aplique el rebranding a un solo contenedor y deje la landing y la pagina de precios con identidades divergentes.
* **Impacto:** **0 migraciones SQL**, **0 cambios de esquema**, **0 endpoints**, **0 archivos `api/*.js`**, **0 CSS de silo** (`css/templates/*` intacto). Archivos de codigo a impactar (implementacion futura): `index.html` (Fase 1: tokens `.htz` + wordmark + assets de logo) y `planes-precios.html` (Fase 2: tokens `.ppz` + wordmark). Assets nuevos: derivados de logo (favicon del isotipo, OG, variante invertida). Impacto documental: este ADR-053 + `TASKS.md`/`NEXT.md` (gestionados por su agente). **Cero Borrado intacto:** ningun ID/atomo del contrato se retira.
* **Riesgos:** (1) **Contraste/legibilidad:** `--accent-green #00FF66` sobre `--bg-base`/`--bg-surface` debe validarse (contenido de verificacion QR); el acento de marca es `--accent-cyan`, no el verde. (2) **Carga de webfonts:** `Archivo Black` e `Inter` son familias adicionales; declarar fallbacks y evitar layout shift. (3) **Divergencia `.htz` vs `.ppz`:** aplicar solo un contenedor deja dos identidades; el plan debe cubrir ambos. (4) **Cache EDGE ~10 min:** no confundir cache con bug en la verificacion visual. (5) **Alphas de `--mut*`:** si no se recalculan al nuevo `--cream`, quedan alphas del color viejo (amarillentos). (6) **Colores por evento:** pisar `--acd` romperia la identidad cromatica por evento proveniente de Supabase.
* **Rollback:** revertir `index.html` y/o `planes-precios.html` al commit previo. El cambio es puramente de tokens/assets: **no hay migracion ni endpoint que deshacer**.
* **Pendientes (no ejecutados - ver `TASKS.md`):**
    1. **Fase 1:** rebranding de tokens de `index.html` (`.htz`) + palabra "DIRECTA" en `<b>` con `--accent-cyan`.
    2. **Fase 2:** rebranding de tokens de `planes-precios.html` (`.ppz`) con el mismo sistema.
    3. **Direccion:** ratificar el mapeo 01-08 de variaciones a categorias (05-08 hoy reservadas).
    4. **Assets:** generar y enlazar derivados de logo (favicon del isotipo, imagen OG, variante invertida) respetando las reglas de uso (zona de proteccion = altura del simbolo; minimo 20 mm con wordmark).
    5. **Verificacion visual** mobile + desktop, contraste/accesibilidad y chequeo de que `--acd` por evento sigue vivo.
* **Referencias:** Reglas de Oro #9 / PROJECT.md (Aislamiento Atomico: tokens bajo `.htz`/`.ppz`, nada en `:root`), ADR-003 (Cero Borrado Logico: IDs/atoms intactos), ADR-002 (ASCII-safe), ADR-001 (Vanilla JS puro, edicion directa de HTML/CSS), ADR-006 (baseline de verdad contra el archivo real: `.htz` L14-17 y `.ppz` L13-14 verificados; `CATS` L624-629), ADR-008 (Silent Fallback en derivados de logo), ADR-050 (contrato de telemetria del landing: el rebranding no introduce tipos nuevos de `page_events`), ADR-051 (estilo de ADR reciente y fase de landing), `AGENTS.md` (presupuesto Vercel Hobby 8/8: prohibido endpoint nuevo), Reglas de Oro (Mandato 1 Data-First, Mandato 2 Cero Borrado, Mandato 9 Aislamiento Atomico), brand board / manual de marca "Taquilla Directa" (fuente externa aportada por Direccion).

