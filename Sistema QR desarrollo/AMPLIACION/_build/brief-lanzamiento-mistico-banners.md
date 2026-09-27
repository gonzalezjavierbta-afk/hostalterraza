# BRIEF DE BUILD — Lanzamiento Mistico · Atomos BANNER (1 y 2) en silo f9b

> Documento autoritativo de la sesion. Una sola fuente de verdad. Si algo no esta aqui, no se implementa.
> **Fecha:** 2026-09-27 · **Modo:** express (con gate de arquitectura, ver ADR-058) · **Ruta:** gratuita
> **Documentacion de cierre (TASKS/NEXT/DECISIONS/ADR/ERRORES): DIFERIDA** hasta peticion explicita del usuario.

---

## 0. Evento objetivo (verificado contra Supabase con la anon key publica)

| Campo | Valor |
|---|---|
| id | `319df5de-bf4d-481d-ad0b-ed97f90a58e1` |
| slug | `lanzamiento-mistico-64k6` |
| nombre | lanzamiento MISTICO |
| template_id | `f9b` |
| categoria_slug | `fiesta` |
| color_primario | `#f0bc00` |
| fecha / hora | 2026-10-10 / 20:00 |
| ubicacion | Calle 45 # 22 -55 (venue "La Hoguera") |
| poster_url | `null` (a sangre -> #mod-cartel se auto-oculta) |
| config_landing.theme | `mistico` (obsoleto; se corrige a `mistico-nocturno`) |
| content keys | meta, gallery(9), sponsors([]), whatsapp, dj_lineup(8), form_solo, playlist_url, comunidad_whatsapp |
| content keys AUSENTES | **banners (lo creamos)**, boletos, faq, experiencias, descripcion |

Motivos de diseno derivados de estos datos:
- `boletos` ausente -> `#mod-boletos` se oculta (f9 solo pinta con tarifa real). Se estiliza igual, queda oculto. Decision usuario (1): "dejar oculto si no hay informacion".
- `faq` ausente -> se deja el fallback existente. Decision usuario (3): "dejar las que estan" (no escribir FAQ).
- El dj_lineup real tiene 8 artistas (no los 3 del brief). La meta visible sale de `resena` (solo Rastro MC) y `instagram` (resto). Sin iconos. Decision usuario: solo banners y FAQ, no se toca el lineup.

## 1. Baseline verificado (NO romper)

| Metrica | Valor | Regla |
|---|---|---|
| `evento-app.html` divs | **92 / 92 = 0** | DEBE quedar en 0. Patron seguro: cada `<section>` es positioning-context y sus hijos van en `position:absolute` -> **cero divs nuevos**. Si hace falta wrapper: 1 `<div>`+`</div>` por seccion (94/94). Nunca partir un open/close entre hunks. |
| `admin.html` divs | 1480 / 1477 = **+3** | DEBE quedar en +3 (baseline de `express_check.js`). |
| `express_check.js` | PASS 12 / FAIL 0 | Debe seguir verde. |
| `smoke_f9b_mistico_nocturno.js` | PASS 61 / FAIL 0 | Debe seguir verde + checks nuevos. |
| `f9b.css` | 2921 lineas, 369 `.tpl-f9b`, 365 `.Tpl-F9b` | Preservar scope atomico. |
| `f9b.css` dos plantillas de areas | base **L673-690** (1 col), desktop **L729-743** (2 col) | **Ambas** se modifican (pregunta previa era FALSA). |

## 2. Contrato de datos (ASCII-safe) — `config_landing.content.banners[]`

Array de **2** objetos. `banners[0] -> #mod-banner-1`, `banners[1] -> #mod-banner-2`. `banners[2+]` se ignora (documentado, no es error).

| Campo | Tipo | Regla |
|---|---|---|
| `frase` | string | **Unico campo que enciende el atomo.** Tope de longitud en render (p.ej. 320). |
| `autor` | string | Opcional. |
| `etiqueta` | string | Opcional (kicker). |
| `estilo` | `'dorado' \| 'monocromo'` | fail-open `'dorado'`. **Renombrado desde `tema`** para no colisionar con `config_landing.theme` (que es slug de theme). El kernel lo refleja en `data-estilo` del `<section>`; el silo estila con `#mod-banner-1[data-estilo="monocromo"]`. |
| `imagen_url` | string | Reservado; `""` permitido. |
| `video_url` | string | Reservado; `""` permitido. Distinto de `ev.video_url`. |
| `alt` | string | **Obligatorio si hay `imagen_url`**; default = `frase` truncado a 120. |

**Item vacio** := `!frase && !autor && !etiqueta` (NUNCA "¿tiene media?"). En este evento la media esta reservada vacia, asi que el diseno predeterminado es **tipografico, sin media**.

## 3. Los 2 atomos (kernel generico, NO de familia f9)

- `<section id="mod-banner-1">` — DOM: entre el cierre de `#mod-lineup` (L168) y el comentario de `#mod-playlist` (L170).
- `<section id="mod-banner-2">` — DOM: entre el cierre de `#mod-whatsapp` (L255) y `#mod-sponsors` (L258). **NO** entre whatsapp y faq: faq esta en L199, antes de whatsapp.

- Ambos son **hermanos planos** de `#main-content-flow`, genericos (los renderiza cualquier silo que los encienda). **NO** se toca `__esFamiliaF9()` (L766-773) ni `__esSiloF9Rastro()`.
- Nacen **ocultos** por el IoC `section, header, footer { display: none; }` (L30). Un silo que no los encienda los deja inertes -> cero regresion en f1,f3,f5,f6,f7,f8,f9,f10,f11,f12,campana,cine.
- Fase `proximamente` (L2182-2196) los oculta (no whitelisted) — correcto por diseno, no tocar.

## 4. Mecanismo de visibilidad (Data-First, resuelto)

`__hideEmptyModule` (L1074-1085) escribe `display:none !important` **inline**, y el inline `!important` gana al `!important` de la hoja. Por eso:

- El **kernel** llama `__hideEmptyModule('mod-banner-1', hayFrase1)` y `__hideEmptyModule('mod-banner-2', hayFrase2)`. Cuando NO hay frase -> kernel pone inline `display:none !important` (nadie puede sobreescribirlo). Cuando SI hay -> solo quita `data-hidden` y **no** pone display.
- El **silo** enciende `#mod-banner-1`/`#mod-banner-2` con `display:block !important` en su seccion 2 (patron `f9b.css:474-483`) **y anade guarda de defensa `:has(:empty)`** (patron `f9b.css:493-499`).
- Net: sin frase -> oculto (inline). Con frase -> el silo lo enciende. Imposible dejar banda vacia.

## 5. Las 3 capas (creadas por condicion, no por atributo)

Dentro de cada `<section>` (que es `position:relative`, `overflow:hidden`, `isolation:isolate`):

- **Capa 0 — `.banner-media`** (el contenedor de medios, `position:absolute; inset:0; z-index:0`):
  - `.banner-img` (`<img>`) — **siempre en el DOM**. `src` = `imagen_url || AVATAR`. **NO** `.lightbox-trigger` (P1-5: abriria el lightbox a pantalla completa del avatar). Si no hay `imagen_url` real, el silo lo oculta y pinta gradiente (fallback).
  - `.banner-video` (`<video>`) — **solo si** `video_url` no vacio **Y** `prefers-reduced-motion` no activo (JS `matchMedia` antes de crear). Atributos: `autoplay muted loop playsinline` (obligatorios; sin `muted` no hay autoplay, sin `playsinline` iOS abre fullscreen), `poster` = `imagen_url || AVATAR`, `preload="none"` (decorativo), `aria-hidden="true"`, `tabindex="-1"`.
- **Capa 3 — `.banner-text`** (`z-index:3`): `.banner-kicker` (etiqueta), `.banner-frase` (frase), `.banner-autor` (autor).

Fallback de imagenes: pre-check `if (url) el.src=url; else el.style.display='none';` (patron kernel L1341-1343) en vez de confiar solo en `onerror`. Avatar: `https://ctgyvydzshueemlelkzv.supabase.co/storage/v1/object/public/assets/avatar-default.png` (fuente unica en `api/evento-og.js:10`).

## 6. Seguridad: construir con textContent / setAttribute (NO innerHTML crudo)

El kernel NO tiene `esc()`/`escapeHtml()` (0 ocurrencias) y 25 `innerHTML` interpolan sin sanear. Para el banner (modulo mas expuesto: `frase`, `autor`, `alt` y 2 URLs en atributos) construir con `createElement` + `textContent` + `setAttribute` (precedente: hero L1128-1137, `__renderPreviewError` L917-930). Evita ruptura de atributo por comillas y XSS almacenado, y no altera el balance de divs.

## 7. Orden vertical final (grid-template-areas, las DOS plantillas, fuente unica)

Sin `grid-column: 1/-1` para los banners (P0-3: sin `grid-area` nombrado caen por auto-placement despues del footer). Cada banner es un area nombrada FULL-WIDTH en ambas plantillas.

- **Base (f9b.css L673-690, 1 col):**
  `"hero" "countdown" "meta" "ctas" "descripcion" "lineup" "banner-1" "playlist" "cartel" "video" "boletos" "experiencias" "whatsapp" "sponsors" "banner-2" "faq" "ubicacion" "form" "footer"`
- **>=992px (f9b.css L729-743, 2 col):** cada area de 1 celda se repite 2 veces (obligatorio o invalida la declaracion entera):
  `"hero hero" "countdown countdown" "meta meta" "ctas cts" "descripcion descripcion" "lineup lineup" "banner-1 banner-1" "cartel playlist" "video video" "boletos boletos" "experiencias experiencias" "whatsapp sponsors" "banner-2 banner-2" "faq ubicacion" "form form" "footer footer"`

Prohibido escribir un area de una sola celda en la plantilla de 2 columnas. El REFLOW existente (L2581-2607, 5 reglas `:has([data-hidden])` con `grid-column:1/-1` sobre mod que NO son los banners) se conserva intacto.

- Bloques `grid-area` nuevos en el mapa 1:1 (L699-715): `#mod-banner-1 { grid-area: banner-1 }`, `#mod-banner-2 { grid-area: banner-2 }`.
- Alto de banda: `min(58svh, 620px)` (no 100vh) para que el umbral 0.5 del IntersectionObserver `section_view` se cumpla (si la banda > 2x viewport nunca dispara el evento; 100vh es seguro, 58svh es holgado). Usar `svh` (barra movil).

## 8. Clases internas del KERNEL (propiedad del kernel, no del silo)

`banner-media`, `banner-video`, `banner-img`, `banner-text`, `banner-kicker`, `banner-frase`, `banner-autor`. Se declaran aqui y en Anexo C de TEMPLATES.md. El silo solo estila estas clases + sus ids (TEMPLATES.md Cap. 1.3 prohibe selectores propietarios inventados).

## 9. Data: merge idempotente (ejecucion Direccion / @sql-security, 0 endpoints)

Un `UPDATE` sobre el evento. **CERO borrado logico; no tocar ninguna otra llave.**

Peligro: `content.gallery[2]` es un `data:image/jpeg;base64` de ~30 KB dentro del JSONB. Un `config_landing = jsonb_build_object(...)` o un `config_landing->'content' = ...` mayorista lo DESTRUYE. Usar **solo** `jsonb_set` (merge superficial) dos veces, en ese orden, y NO tocar `content` wholesale:

```sql
UPDATE eventos
   SET config_landing =
       jsonb_set(COALESCE(config_landing,'{}'::jsonb), '{content,banners}', <JSON_BANNERS>::jsonb, true)
       || jsonb_build_object('theme','mistico-nocturno')
 WHERE id='319df5de-bf4d-481d-ad0b-ed97f90a58e1' AND slug='lanzamiento-mistico-64k6';
```

`||` de jsonb = merge superficial: reemplaza solo la clave top-level `theme` y preserva `content` completo. Verificar con `SELECT config_landing->'content'->'banners', config_landing->'theme', jsonb_array_length(config_landing->'content'->'gallery')` antes y despues (si gallery baja de 9, PARAR). Rollback: `UPDATE eventos SET config_landing = config_landing #- '{content,banners}' WHERE id='319df5de-...';` (quitar solo `banners`, nunca todo `content`).

Nota sobre `theme` (decision usuario 2): es **higiene de dato**, no un fix de misroute. `admin.html:5274-5279` resuelve el theme por `template_id` primero, asi que el landing no cambia. Efecto colateral aceptado: al activar el preset `mistico-nocturno`, `_THEME_MODULES.requeridos` incluye `ld-mod-boletos` y `ld-mod-faq-fiesta` (admin.html:3073) que el evento no tiene en `content` -> el wizard quedara con esos checks marcados. Decision usuario: hacerlo de todos modos.

## 10. Wizard: NO tocar admin.html en esta entrega (P0-2)

`CATEGORY_TAG_FIELDS`/`CATEGORY_TAG_LISTS` **NO existen** en admin.html (0 ocurrencias; el nombre viene de las definiciones de agente, esta corregido en DECISIONS.md:576). El mecanismo real es `_buildConfigLanding()` (admin.html:4153-4340) con whitelist literal (L4236-4328) que RECONSTRUYE `cfg.content` y reemplaza el JSONB entero al guardar (L6879). Decision: **no se registra nada en admin.html**; Direccion carga los fondos por SQL. Consecuencia aceptada y a documentar (BUG-016): si el evento se re-guarda desde el Wizard, la clave `banners` (y hoy tambien `experiencias`, `cta_final`, `footer`, `whatsapp_msg`) se destruye en silencio. Mitigacion inmediata: no re-guardar este evento desde el Wizard hasta que exista el passthrough de claves foraneas.

## 11. Fuera de alcance (deuda, no se ejecuta)

- Edit de `f9.css:1633` (`content:" - rastro mc"`): f9 esta en PRODUCCION (`admin.html:3018`, evento `rico-5mw5`) y el sello es marca intencional documentada. **NO se toca.** Solo se edita `f9b.css:2244` si Direccion lo pide (marca de silo, decision de marca, no bug de arquitectura).
- `api/evento-og.js` / OG meta del motor: sin cambios (verificado: el kernel no lee `video_url` para OG en este alcance).
- `config_global` / curado de plantillas (TSK-035) sin cambios.
- Tracking `section_view` explicito de banners: el IntersectionObserver generico ya los cuenta como `sec:visible` (selector `section[id^="mod-"]`); no se anade entrada a CLICK_RULES.
- `fase_landing='proximamente'` para este evento = `completa`, asi que el gate de teaser no dispara.

## 12. Tareas y agentes

| # | Tarea | Agente | Archivo | Pre |
|---|---|---|---|---|
| 1 | 2 `<section>` + funcion de poblacion por indice + 2 llamadas a `__hideEmptyModule` + 3 capas con textContent/setAttribute + guarda `alt` + `preload=none` + reduced-motion JS | `@renderer-dev-free` (NOTA: ver pregunta de rol abajo) | `evento-app.html` | ADR |
| 2 | Areas en las 2 plantillas + mapa `grid-area` + seccion 2 encendido + guarda `:has(:empty)` + capas + reduced-motion + `svh` + cabecera v1.2.0 + log | `@frontend-tpl-free` | `css/templates/fiesta/f9b.css` | 1 |
| 3 | `UPDATE` de merge (2 `jsonb_set` superficial, sin tocar gallery) + `SELECT` verificacion antes/despues | Direccion / `@sql-security` (pro; es escritura en produccion) | SQL nuevo `migrations/` | 1,2 |
| 4 | Extender smoke: los 2 `<section>` existen, funciones `__poblarBanner`/render presentes, `__hideEmptyModule` llamado por ambos, los 2 nombres `banner` en AMBAS plantillas, balance divs 0, merge con `jsonb_set` (no wholesale), `theme` corregido, `banners[2+]` ignorado | `@js-silo-dev-free` | `scripts/smoke_f9b_mistico_nocturno.js` | 1,2,3 |
| 5 | `node scripts/express_check.js` + checks manuales CSS (2 plantillas coherentes, 2 `grid-area`, tokens `--gold`/`--tpl-accent`, cero selectores muertos, 0 `:root` global) + grep residuos | `@exp-pickle-free` | lectura | 1,2,4 |
| 6 | Escudo GOLD + QA runtime de 3 estados (con media, sin media, sin item) movil+escritorio | `@qa-auditor-free` | lectura | 5 |
| 7 | Cierre documental | `@docs-keeper-free` | `Sistema QR desarrollo/*` | **DIFERIDO** |

Cadena: `1 -> 2 -> 3 -> 4 -> 5 -> 6`. (3 en paralelo con 4 una vez 1,2 listos.)

## 13. Preguntas de rol que el build debe resolver antes de despachar

1. **@renderer-dev-free vs @frontend-tpl-free para `evento-app.html`:** `AGENTS.md` asigna `pagina-destino.js`/`vercel.json` a renderer-dev, y `evento.html`/css a frontend-tpl. `evento-app.html` es el motor publico de landings (no `pagina-destino.js`). El render de los banners va en el `<script>` inline de `evento-app.html`. **Decision sugerida:** `@frontend-tpl-free` (es el dominio del motor publico de evento segun AGENTS.md, y ya es el dueno de `evento-app.html` segun los planes previos del silo f9). `@frontend-tpl-free` es el unico que puede tocar a la vez el silo (tarea 2) y el kernel (tarea 1) sin cambiar de contexto. **A menos que el build decida lo contrario, la tarea 1 va a @frontend-tpl-free.**
2. **¿Se amplia la lista ON de f9b de 17 a 19?** ADR-054 d.5 lo marca como "frontera dura". Los 2 banners son ON en este silo. El build debe registrar la ampliacion explicitamente en el log del silo (v1.2.0) con la justificacion del ADR-058.
3. **Editor de `f9b.css:2244`:** el build NO lo edita salvo peticion de Direccion (decision de marca). Default: no tocar, documentar en la sesion.

## 14. Handoff

Sesion actual = orquestador de planificacion (solo lectura). **Para implementar, iniciar sesion con `@free-build`** y pegar este brief.
