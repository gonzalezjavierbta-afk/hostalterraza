---
doc: ADR-094
version: v1.2-IMPLEMENTADO-EN-CODIGO
fecha: 2026-11-10
origen: Decision del usuario en la sesion de "preview de ADN Visual" - el preview del paso 2 del wizard mostraba un evento sintetico (`_SAMPLE_EVENTS`) en vez de un evento real, y el boton "Vista previa" del paso 5 quedaba fuera del flujo. Este ADR fija el contrato de persistencia, payload y UI antes de implementar.
version_previa: ADR-093
relacionados: [../DECISIONS.md, ../TASKS.md, ../NEXT.md, ../BLUEPRINT.md, ADR-006-nomenclatura-atomica-por-categorias-silos.md, ADR-008-protocolo-de-blindaje-de-assets-silent.md, ADR-021-wizard-inteligente-de-creacion-de-eventos-4.md, ADR-040-catalogo-de-plantillas-curado-por-la-cuenta.md, ADR-056-consolidacion-de-los-15-solapamientos-del.md]
estado: IMPLEMENTADO Y MIGRACION APLICADA (2026-11-10), V5 PENDIENTE
auditoria: "@architect-review, 2026-11-10: dictamen CAMBIOS. v1.1 aplica los 6 grupos de correccion (clave de silo unica, mapa `_templateMuestras`, estado vacio que limpia `ht_preview_payload` + `esc()` + refresco, 6 ajustes de SQL, limite de `modules` en preview, estado)."
implementacion: "2026-11-10: admin.html + migrations/adr094_org_template_muestras.sql + scripts/smoke_template_muestra.js. Smoke 74/74, GOLD 2/2, bytes>127 24086 (sin delta), divs 1628/1625 (desbalance 3 = baseline). Migracion APLICADA en hostal-terraza (ctgyvydzshueemlelkzv): tabla, PK, 2 CHECK, 2 FK, indice, trigger, 2 policies y RLS on; 2a corrida idempotente; smoke insert+rollback OK (0 filas). V5 manual pendiente. Ver TSK-140 y NEXT.md hito -65."
estructura: detalle-v1 (2026-10-01)
nota_numeracion: Verificado el 2026-11-10 contra `decisiones/`: la ficha previa es `ADR-093` y no existe `ADR-094*`. `ADR-075` sigue siendo hueco y NO se rellena. Cero Borrado: no se sobrescribe ninguna ficha previa.
---

> Detalle de [DECISIONS.md](../DECISIONS.md).

## ADR-094: Evento de muestra real por silo en el preview de ADN Visual

**ID:** ADR-094

**Fecha:** 2026-11-10

**Autor:** Chief Architect, a partir de la decision ya tomada por el usuario; anclas verificadas contra el archivo real (ADR-006).

**Estado:** IMPLEMENTADO Y MIGRACION APLICADA (2026-11-10), V5 PENDIENTE. Historial: la v1.1 declaro "ACEPTADO CON CAMBIOS - REVISADO, pendiente de implementar (0 lineas de codigo, 0 SQL escrito, 0 SQL ejecutado)"; la implementacion posterior vive en `admin.html`, `migrations/adr094_org_template_muestras.sql` y `scripts/smoke_template_muestra.js` (smoke 74/74, GOLD 2/2). La migracion esta APLICADA en hostal-terraza (`ctgyvydzshueemlelkzv`): 1 tabla, PK, 2 CHECK, 2 FK, indice, trigger, 2 policies y RLS; la 2a corrida fue idempotente y el smoke insert+rollback dejo 0 filas. Las pruebas V5 siguen manuales.

### 1. Problema

El wizard de creacion (`admin.html`, 5 pasos, ADR-021) tiene DOS caminos de preview y ninguno de los dos muestra el evento que el operador eligio:

1.  **Paso 2 "ADN Visual"** (`data-wiz-step="2"`, `admin.html:554`): el panel lateral `#ld-adn-preview` (`:887`) alimenta el iframe `#ld-adn-preview-frame` (`:896`) con `_ldAdnSyncPreview()` (`:4185-4210`), que llama a `_muestraPayload(theme)` (`:4148-4168`). Ese payload sale de `_SAMPLE_EVENTS` (`:4023-4144`): un evento **sintetico** con `slug 'muestra-fiesta-terraza'`, `poster_url` de un SVG inline (`_IMG_MUESTRA`, `:3994`), DJs ficticios y textos de relleno. El operador elige una plantilla y ve una landing de mentira, no lo que va a publicar.
2.  **Paso 5** (`data-wiz-step="5"`, `admin.html:1359-1386`): todavia existe un boton "Vista previa" (`:1383`) que llama a `abrirVistaPrevia()` (`:7329`), el cual serializa el **borrador del formulario** (`_buildPreviewPayload()`, `:7263-7313`). Duplica la funcion de preview en un segundo punto del flujo, lejos del selector de plantilla, y el borrador no tiene `template_id` resuelto ni datos persistidos.

Ademas, la ficha de la plantilla (`abrirFichaTheme()`, `:4245-4287`) resuelve el "evento de muestra" con una **heuristica implicita** (`_fichaThemeEvento()`, `:4234-4243`): el primer evento con `template_id` igual al silo, o el primero de la categoria del silo. Ese evento **no lo eligio nadie**, no queda registrado y cambia solo si aparece otro evento mas antiguo en `_eventos`. Cuando no hay ninguno, la ficha ofrece "Ver pagina de ejemplo" (`:4282`) y vuelve al sample sintetico.

**Trampa de clave (verificada, BLOQUEANTE):** la ficha tiene DOS resoluciones de `template_id` que **NO** sirven como clave de persistencia, porque solo consultan `_THEME_TPL` (10 themes) y **no** `_THEME_TPL_PREVIEW`: el `const tpl = _THEME_TPL[theme] || theme;` de `abrirFichaTheme()` (`:4250`) y el `const tpl = String(_THEME_TPL[theme] || theme || '').toLowerCase()` de `_fichaThemeEvento()` (`:4237`). Con cualquiera de las dos, **12 de los 22 themes** (los 4 de cinematografia, los 4 de campana y los 4 legados de fiesta: `arthouse`, `premiere-gold`, `neon-cult-cine`, `interactive-cine`, `solidario-moderno`, `urgente-impactante`, `tech-futurista`, `vintage-organico`, `tropical-hostel`, `rooftop-sunset`, `underground`, `elegant-cocktail`) guardarian su **slug de theme** en vez del silo (`c1`, `b2`..`b5`, `f1`), y `_ldAdnSyncPreview()` - que resuelve por la cadena completa - **nunca leeria esa fila**. El sintoma seria un preview permanentemente vacio en 12 de 22 plantillas, con la fila escrita en la base. Ver R1.1.

Consecuencia: la decision del usuario (ya tomada, no se re-litiga) es que el preview de ADN muestre **un evento REAL elegido por el operador**, persistido y compartido por organizacion, y que sin eleccion el estado sea **vacio y honesto**. Un preview que inventa datos es peor que no tener preview: el operador aprueba una plantilla mirando contenido que nunca existio.

### 2. Opciones consideradas

*   **(A) Guardar la muestra dentro de `eventos.config_landing` (jsonb) o en `organizaciones`:** descartada. `config_landing` es POR EVENTO, y el dato es POR SILO (16 silos, independiente de cuantos eventos haya). Meterlo en `organizaciones` obliga a un MERGE JSONB sobre una fila que el admin ya escribe para otros fines (nombre, plan, logo), mezcla dominios y no permite PK ni integridad referencial: nada impide guardar un `evento_id` de otra org o un `template_id` inexistente.
*   **(B) Reutilizar `config_global`:** descartada. `config_global` es **GLOBAL**, no por organizacion (single-row curada por la org maestra; ver `migrations/adr040_config_global_templates.sql:56` y `is_master_org_user()`, `:105-118`). Escribirla desde el admin de una org normal rompe el modelo de permisos y filtra la eleccion de una org a todas.
*   **(C) `localStorage` / `sessionStorage`:** descartada. No es compartida por org, no sobrevive al cambio de equipo ni al modo incognito, y el preview de ADN se abre desde dispositivos distintos (tablet en sitio, portatil en oficina). Ademas `sessionStorage` ya se usa para el payload efimero (`ht_preview_payload`, `:7315-7319`); usarlo como almacen de configuracion mezcla transporte con persistencia.
*   **(D) Tabla propia `public.org_template_muestras` con PK `(org_id, template_id)`:** **elegida**. Clave natural por silo, integridad referencial contra `eventos` y `organizaciones`, RLS por el patron existente y 0 endpoints nuevos (8/8 funciones de Vercel Hobby intactas).

### 3. Decision

**R1 - El preview de ADN muestra un evento REAL, elegido y persistido.** La clave de persistencia es `(org_id, template_id)`: **16 silos**, no 22 themes. `template_id` se resuelve con la MISMA cadena que ya usa el preview: `_THEME_TPL_PREVIEW[theme] || _THEME_TPL[theme] || theme`, en minusculas (`admin.html:4150`, `_THEME_TPL` `:3642-3662`, `_THEME_TPL_PREVIEW` `:4005-4009`). Consecuencia aceptada y visible: los themes que comparten silo comparten muestra (los 4 de cinematografia -> `c1`; `tropical-hostel`, `rooftop-sunset`, `underground`, `elegant-cocktail` -> `f1`).

**R1.1 - (BLOQUEANTE) La clave del silo se resuelve SIEMPRE con una sola expresion, y `_templateMuestras` se indexa con esa misma clave.** La unica forma permitida, en los tres puntos - carga del mapa, guardado desde la ficha y lectura en `_ldAdnSyncPreview()` - es:

```js
const tplSilo = String(_THEME_TPL_PREVIEW[theme] || _THEME_TPL[theme] || theme).toLowerCase();
```

**Prohibido** reusar el `const tpl = _THEME_TPL[theme] || theme;` local de `abrirFichaTheme()` (`admin.html:4250`) ni el `tpl` de `_fichaThemeEvento()` (`:4237`): ambos omiten `_THEME_TPL_PREVIEW` y escriben el slug del theme para **12 de 22 themes**, generando una fila que el preview nunca lee (ver la trampa de clave en la seccion 1). Si `@admin-dev` necesita el `tpl` local para el rotulo "Silo: ..." de la ficha, lo conserva como texto informativo, **nunca** como clave de escritura. Un unico helper (`_tplSilo(theme)`) es la forma recomendada de garantizar que no se duplique la cadena.

**R2 - Un solo punto de preview en el wizard: el paso 2.** Se retira el boton "Vista previa" del paso 5 (`admin.html:1383`). Ese nodo **no tiene `id`** (solo `onclick`), asi que retirarlo **no** toca el Contrato v112 ni exige ocultamiento por CSS. La funcion `abrirVistaPrevia()` (`:7329`) **NO se borra**: la siguen usando `abrirVistaPreviaDeMuestra()` (`:4170-4178`), `ldAdnAbrirPestana()` (`:4221-4228`) y la pestana nueva (`abrirVistaPreviaPestana`). Cero Borrado: se retira un punto de entrada, no una capacidad.

**R3 - La muestra se elige en la ficha de la plantilla.** En `abrirFichaTheme()` (`:4245-4287`) se reemplaza el bloque `#ficha-tpl-ev` por un desplegable `<select id="ficha-tpl-muestra">` con **TODOS** los eventos de `_eventos` (ya cargados con `select('*').eq('org_id', ORG_ID)`, `admin.html:6488`, e incluyen `config_landing`), agrupados por `categoria_slug` con `<optgroup>` y la categoria del silo primero. Boton "Guardar muestra" -> UPSERT. El texto "Evento de muestra: <nombre>" pasa a reflejar la eleccion persistida, no la heuristica.

**R4 - Sin muestra elegida, estado vacio honesto. Cero datos sinteticos en el preview.** `_ldAdnSyncPreview()` deja de llamar a `_muestraPayload()` y pasa a resolver la muestra persistida: si no hay fila para `(ORG_ID, template_id)`, toma la rama que YA existe (`:4199-4202`) - `frame.removeAttribute('src')` + `#ld-adn-empty` visible - y el texto del panel dice que no hay evento de muestra y donde elegirlo. **No** se cae a `_SAMPLE_EVENTS`.

**R5 - `_SAMPLE_EVENTS`, `_muestraPayload()` y `_THEME_TPL_PREVIEW` se conservan intactos.** Siguen siendo el fallback de la ficha (`:4282`) y de `abrirVistaPreviaDeMuestra()`. Quedan **fuera del camino del preview de ADN**. Su retiro, si se decide, es un ADR aparte: este ADR no borra codigo (Cero Borrado).

**R6 - Categoria del payload = categoria del SILO, no del evento.** El kernel resuelve el CSS por `css/templates/{categoria_slug}/{template_id}.css` (`injectAtomicCSS`, documentado en `evento-app.html:1061-1065`), asi que el payload debe llevar la categoria del silo (`_THEME_TYPE[theme]`, `admin.html:3622-3638`). Un evento de otra categoria se puede previsualizar, con aviso en la UI; **no se bloquea** (bloquearlo crea callejones sin salida en orgs sin eventos de esa categoria).

**R7 - El color y el contenido del EVENTO mandan.** `_muestraPayload()` inyectaba la paleta de la ficha en `content.color_primario` / `accent_color` (`:4161-4166`). Con evento real eso se elimina: se muestra el `config_landing.content` del evento tal cual. Solo los **efectos** caen al preset de la plantilla (`_THEME_FX[theme]`, `:4015-4018`) cuando el evento no declara `effects`: son presentacion, no contenido.

**R8 - La tabla es la unica fuente de verdad de la muestra; 0 endpoints nuevos.** El admin escribe directo con el cliente Supabase ya existente (`SB.from('org_template_muestras').upsert(...)`, `onConflict: 'org_id,template_id'`). No se crea `api/*.js` (presupuesto 8/8 agotado). La lectura publica **no** toca esta tabla: el preview vive en `admin.html`.

**R9 - Degradacion silenciosa si la migracion no esta aplicada (ADR-008).** La migracion es manual (SQL Editor). Si la tabla no existe, el admin captura el error, marca `_MUESTRAS_OK = false`, oculta el selector y muestra un aviso honesto ("funcion no disponible: falta la migracion adr094"). **Prohibido** caer al sample sintetico como consuelo.

**R10 - El kernel no cambia una linea.** `__evDesdePreview()` (`evento-app.html:1066-1086`) ya acepta exactamente `{ ev, content, theme, template_id, categoria_slug, effects, i18n }`. Todo el trabajo es de `admin.html` + 1 tabla. 0 cambios en `evento-app.html`, `index.html`, `scanner.html`, `registroaforo.html`, `css/templates/**` y `api/*.js`.

**R11 - La identidad del evento se valida en el servidor, no en el cliente.** Un trigger `BEFORE INSERT OR UPDATE` verifica que `evento_id` exista y que `eventos.org_id = NEW.org_id`. La RLS por si sola **no** lo cubre: `get_org_id()` protege la fila de la muestra, no la fila del evento apuntado.

### 4. Contrato SQL para @sql-security (NO ejecutado por este ADR)

Archivo a escribir: `migrations/adr094_org_template_muestras.sql`. Prefijo `adr094_` conforme a `migrations/` (`adr088_*`, `adr090_*`, `adr092_*`). Ejecucion **MANUAL** en el SQL Editor, idempotente, dentro de `BEGIN`/`COMMIT`. **Cabecera ASCII obligatoria** (0 bytes > 127 en todo el archivo). **Fallback si el SQL Editor parte el script:** ejecutar bloque por bloque en el orden numerado de la cabecera; cada bloque es re-ejecutable por separado (el `BEGIN`/`COMMIT` solo agrupa, no es requisito de correccion).

```sql
-- ===========================================================================
-- ADR-094 - Muestra real por silo para el preview de ADN (admin.html)
-- Archivo: migrations/adr094_org_template_muestras.sql
-- Ejecucion: MANUAL en el SQL Editor de Supabase. Idempotente.
-- Orden si el editor parte el script:
--   B1 tabla desnuda | B2 PK | B3 CHECKs | B4 indice | B5 trigger
--   B6 RLS + policies | B7 GRANT/REVOKE | B8 reload schema
-- Nota ASCII: este archivo no debe contener bytes > 127 (ADR-002).
-- ===========================================================================
BEGIN;

-- B0. PRE-FLIGHT: las funciones de RLS deben vivir en public. Si viven en otro
-- esquema, NO se aplica a ciegas: se descalifica la llamada en las policies
-- (o se corrige el nombre) y se vuelve a correr. Sin este chequeo, el error
-- aparece recien al crear la policy, a mitad del script.
DO $pre$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'get_org_id'
  ) THEN
    RAISE EXCEPTION 'adr094 pre-flight: no existe public.get_org_id(); revisa el esquema real y descalifica la llamada en las policies'
      USING ERRCODE = '42883';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'is_master_org_user'
  ) THEN
    RAISE EXCEPTION 'adr094 pre-flight: no existe public.is_master_org_user()'
      USING ERRCODE = '42883';
  END IF;
END
$pre$;

-- B1. TABLA DESNUDA (sin PK ni CHECK inline). Los constraints se agregan en
-- B2/B3 con DROP IF EXISTS + ADD (patron adr088:109-115): asi la segunda
-- corrida corrige una definicion previa en vez de no hacer nada.
CREATE TABLE IF NOT EXISTS public.org_template_muestras (
  org_id         uuid        NOT NULL
                 REFERENCES public.organizaciones(id) ON DELETE CASCADE,
  template_id    text        NOT NULL,
  evento_id      text        NOT NULL
                 REFERENCES public.eventos(id) ON DELETE CASCADE,
  categoria_slug text        NOT NULL,
  updated_at     timestamptz NOT NULL DEFAULT now(),
  updated_by     uuid        DEFAULT auth.uid()
);

COMMENT ON TABLE public.org_template_muestras IS
  'ADR-094: evento real usado como muestra del preview de ADN en admin.html. Clave = (org_id, template_id); 16 silos, no themes.';

-- B2. PK (org_id, template_id)
ALTER TABLE public.org_template_muestras
  DROP CONSTRAINT IF EXISTS org_template_muestras_pkey;
ALTER TABLE public.org_template_muestras
  ADD CONSTRAINT org_template_muestras_pkey PRIMARY KEY (org_id, template_id);

-- B3. CHECKs de normalizacion (sin whitelist de silos: el catalogo es codigo)
ALTER TABLE public.org_template_muestras
  DROP CONSTRAINT IF EXISTS org_template_muestras_template_chk;
ALTER TABLE public.org_template_muestras
  ADD CONSTRAINT org_template_muestras_template_chk
  CHECK (template_id <> '' AND template_id = lower(btrim(template_id)));

ALTER TABLE public.org_template_muestras
  DROP CONSTRAINT IF EXISTS org_template_muestras_categoria_chk;
ALTER TABLE public.org_template_muestras
  ADD CONSTRAINT org_template_muestras_categoria_chk
  CHECK (categoria_slug <> '' AND categoria_slug = lower(btrim(categoria_slug)));

-- B4. INDICE opcional sobre evento_id: acelera el ON DELETE CASCADE y la
-- busqueda "que silos usan este evento". No es UNIQUE a proposito: el mismo
-- evento puede ser muestra de varios silos.
CREATE INDEX IF NOT EXISTS org_template_muestras_evento_idx
  ON public.org_template_muestras (evento_id);

-- B5. TRIGGER: valida que el evento exista y pertenezca a la MISMA org, y sella
-- auditoria. SECURITY DEFINER + search_path fijo, igual que is_master_org_user()
-- (migrations/adr040_config_global_templates.sql:105-118): sin esto la RLS de
-- eventos podria ocultar la fila y bloquear escrituras legitimas.
CREATE OR REPLACE FUNCTION public.fn_org_template_muestras_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_org uuid;
BEGIN
  SELECT e.org_id INTO v_org FROM public.eventos e WHERE e.id = NEW.evento_id;
  -- Un solo RAISE, sin eco del evento recibido y con ERRCODE 42501
  -- (insufficient_privilege): no distingue "no existe" de "es de otra org",
  -- asi la respuesta no sirve de oraculo para enumerar ids ajenos.
  IF v_org IS NULL OR v_org IS DISTINCT FROM NEW.org_id THEN
    RAISE EXCEPTION 'org_template_muestras: la muestra debe apuntar a un evento de la misma organizacion'
      USING ERRCODE = '42501';
  END IF;
  NEW.template_id := lower(btrim(NEW.template_id));
  NEW.categoria_slug := lower(btrim(NEW.categoria_slug));
  NEW.updated_at := now();
  NEW.updated_by := auth.uid();
  RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS trg_org_template_muestras_guard ON public.org_template_muestras;
CREATE TRIGGER trg_org_template_muestras_guard
BEFORE INSERT OR UPDATE ON public.org_template_muestras
FOR EACH ROW EXECUTE FUNCTION public.fn_org_template_muestras_guard();

-- B6. RLS
ALTER TABLE public.org_template_muestras ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS org_template_muestras_select_org ON public.org_template_muestras;
CREATE POLICY org_template_muestras_select_org
  ON public.org_template_muestras FOR SELECT TO authenticated
  USING (org_id = public.get_org_id() OR public.is_master_org_user());

DROP POLICY IF EXISTS org_template_muestras_write_org ON public.org_template_muestras;
CREATE POLICY org_template_muestras_write_org
  ON public.org_template_muestras FOR ALL TO authenticated
  USING (org_id = public.get_org_id() OR public.is_master_org_user())
  WITH CHECK (org_id = public.get_org_id() OR public.is_master_org_user());

-- B7. PRIVILEGIOS. Supabase otorga ALL a anon/authenticated por default
-- privileges en el esquema public: sin el REVOKE explicito la tabla quedaria
-- expuesta al rol anon aunque no exista policy para el (RLS niega filas, pero
-- el privilegio sigue concedido). El REVOKE es obligatorio, no cosmetico.
GRANT SELECT, INSERT, UPDATE, DELETE ON public.org_template_muestras TO authenticated;
REVOKE ALL ON public.org_template_muestras FROM anon;

-- B8. Recarga el cache de PostgREST
NOTIFY pgrst, 'reload schema';

COMMIT;
```

Notas vinculantes para `@sql-security`:

1.  **NO crear `anon` policies y NO confiar en la ausencia de `GRANT`.** Supabase concede `ALL` a `anon`/`authenticated` por default privileges en `public`: el `REVOKE ALL ON public.org_template_muestras FROM anon;` del bloque B7 es **obligatorio** y se verifica en V3. El rol anon no debe tener ni privilegio ni policy.
2.  **NO agregar `CHECK` con la lista de 16 silos.** El catalogo de silos es **codigo** (`css/templates/**`, `_TPL_CON_SILO` en `admin.html:3998`), no una tabla; un `CHECK` con lista obligaria a DDL por cada silo nuevo y contradeciria ADR-006.
3.  **Pre-flight obligatorio (B0).** `get_org_id()` e `is_master_org_user()` deben existir en el esquema `public`. Si en esta instancia viven en otro esquema, **se descalifica la llamada** en las dos policies (o se corrige el nombre) antes de aplicar; no se deja que falle a mitad del script.
4.  **PK y CHECK fuera del `CREATE TABLE`.** La tabla se crea desnuda (B1) y los constraints se agregan con `DROP CONSTRAINT IF EXISTS` + `ADD CONSTRAINT` (B2/B3), patron de `migrations/adr088_eventos_coordenadas.sql:109-115`. Un `CREATE TABLE IF NOT EXISTS` con constraints inline no corrige una definicion previa: la segunda corrida no hace nada.
5.  **Un solo `RAISE EXCEPTION`, `ERRCODE = '42501'`, sin eco de `NEW.evento_id`.** El mensaje no distingue "no existe" de "es de otra org"; devolver el id recibido o dos mensajes distintos convierte el trigger en un oraculo de enumeracion. `42501` (insufficient_privilege) es el codigo correcto para el rechazo por pertenencia.
6.  **`SECURITY DEFINER` + `SET search_path = public, pg_temp`** en el trigger, igual que `is_master_org_user()` (`migrations/adr040_config_global_templates.sql:105-118`). Sin esto, la RLS de `eventos` podria ocultar la fila y bloquear escrituras legitimas.
7.  **`ON DELETE CASCADE`** en `evento_id`: si se borra el evento, la muestra se limpia y el preview vuelve al estado vacio (no hay puntero roto). No es borrado de dato de negocio: es un puntero de UI. El indice `org_template_muestras_evento_idx` (B4, **no UNIQUE**: un evento puede ser muestra de varios silos) mantiene barato ese cascade.
8.  **`updated_by`** se sella con `auth.uid()` en el trigger, ignorando lo que mande el cliente.
9.  **`GRANT EXECUTE`** del trigger no aplica (las funciones de trigger no lo necesitan). Si se llegara a exponer `get_org_id()` en policies, seguir el patron de `adr040:123`.
10. **Cabecera ASCII y ejecucion por bloques.** El archivo completo debe tener 0 bytes > 127 y cabecera con el orden B1-B8: si el SQL Editor parte el script, se corre bloque por bloque en ese orden y cada bloque es re-ejecutable.

### 5. Contrato del payload para @admin-dev: `_payloadDesdeEvento(ev, theme)`

Funcion pura, sin red, que sustituye el uso de `_muestraPayload()` en el camino de ADN. Devuelve el objeto que `_guardarPreviewPayload()` serializa y que `__evDesdePreview()` (`evento-app.html:1066-1086`) consume.

```js
// admin.html - NUEVA. Devuelve el payload del kernel o null si no hay render posible.
// Precondicion: ev = fila real de public.eventos (de _eventos, admin.html:6488).
function _payloadDesdeEvento(ev, theme) {
  if (!ev) return null;
  theme = String(theme || '');
  const tplSilo = _tplSilo(theme);                      // R1.1: unica resolucion de clave
  if (_TPL_CON_SILO.indexOf(tplSilo) === -1) return null;   // sin CSS no hay preview
  const cat = String(_THEME_TYPE[theme] || '').toLowerCase();
  if (!cat) return null;
  const cfg = (ev.config_landing && typeof ev.config_landing === 'object') ? ev.config_landing : {};
  return {
    ev: {
      id:          ev.id,
      nombre:      ev.nombre || '',
      slug:        ev.slug || '',
      fecha:       ev.fecha || '',
      hora:        ev.hora || '',
      ubicacion:   ev.ubicacion || '',
      ...(typeof ev.lat === 'number' && typeof ev.lng === 'number' ? { lat: ev.lat, lng: ev.lng } : {}),
      descripcion: ev.descripcion || '',
      poster_url:  ev.poster_url || '',
      imagen_url:  ev.imagen_url || '',
      aforo_max:   (ev.aforo_max === 0 || ev.aforo_max) ? ev.aforo_max : null,
      org_nombre:  (_orgData && _orgData.nombre) || '',
      plan:        (_orgData && _orgData.plan) || 'freemium',
      fase_landing: ev.fase_landing || 'completa'
    },
    content:        (cfg.content && typeof cfg.content === 'object') ? cfg.content : {},
    effects:        (cfg.effects && typeof cfg.effects === 'object') ? cfg.effects
                    : JSON.parse(JSON.stringify(_THEME_FX[theme] || _THEME_FX._default)),
    i18n:           (cfg.i18n && typeof cfg.i18n === 'object') ? cfg.i18n : null,
    theme:          theme,
    template_id:    tplSilo,
    categoria_slug: cat
  };
}
```

Claves exactas emitidas (contrato, no se agregan ni se renombran): `ev`, `content`, `effects`, `i18n`, `theme`, `template_id`, `categoria_slug`. `ev` es **whitelist** (no la fila cruda): evita volcar jsonb ajeno en `sessionStorage` (cuota ~5 MB) y deja el payload identico en forma al de `_buildPreviewPayload()` (`:7284-7312`).

Reglas de uso:

*   `_ldAdnSyncPreview(theme)` resuelve primero la muestra con la clave de R1.1: `const tplSilo = _tplSilo(theme); const m = _templateMuestras[tplSilo];`. Sin fila -> **rama de estado vacio** (ver seccion 6.4). Con fila -> `const ev = _eventos.find(e => String(e.id) === String(m.evento_id))`; si el evento ya no esta en `_eventos`, tratar como vacio (la FK deberia haberlo limpiado).
*   `abrirFichaTheme(theme)` usa la misma funcion para el boton "Ver evento de muestra", que ahora abre la landing publica del evento real (`landingUrl(ev)`) y no el sample. El `const tpl` local de `:4250` queda **solo** para el rotulo "Silo: ..." (R1.1).
*   `ldAdnVerMuestra()` (`:4212-4214`) y `ldAdnAbrirPestana()` (`:4221-4228`) pasan a usar `_payloadDesdeEvento()`; `null` -> aviso, nunca sample.
*   Estado en memoria: un **unico** mapa `let _templateMuestras = {}` (indexado por `template_id` = silo; valor `{ evento_id, categoria_slug, updated_at }`) y `let _MUESTRAS_OK = true`, cargados una vez al init junto a `_eventos`. **Prohibido** un segundo alias (`_muestrasPorTpl` u otro): un solo nombre en carga, guardado y lectura.

Lectura y escritura (sin endpoint nuevo):

```js
// helper unico de clave (R1.1) - usado en carga, guardado y lectura
function _tplSilo(theme) {
  return String(_THEME_TPL_PREVIEW[theme] || _THEME_TPL[theme] || theme).toLowerCase();
}

// carga (degradable)
const { data, error } = await SB.from('org_template_muestras')
  .select('template_id,evento_id,categoria_slug,updated_at')
  .eq('org_id', ORG_ID);
if (error) { _MUESTRAS_OK = false; _templateMuestras = {}; }
else {
  _MUESTRAS_OK = true;
  _templateMuestras = {};
  (data || []).forEach(function (r) { _templateMuestras[String(r.template_id)] = r; });
}

// guardar desde la ficha (tplSilo NUNCA es el tpl local de :4250)
await SB.from('org_template_muestras').upsert({
  org_id: ORG_ID,
  template_id: _tplSilo(theme),
  evento_id: ev.id,
  categoria_slug: _THEME_TYPE[theme]
}, { onConflict: 'org_id,template_id' });
_templateMuestras[_tplSilo(theme)] = { evento_id: ev.id, categoria_slug: _THEME_TYPE[theme] };
_ldAdnSyncPreview(theme);   // refresco obligatorio tras guardar
```

### 6. Contrato de UI (paso 2 y ficha)

1.  **Paso 2** (`:554`, aside `#ld-adn-preview` `:887`): unico preview del wizard. Se conserva el debounce de 250 ms (`:4206-4209`) y el `_ldAdnTimer` con `clearTimeout` antes de reprogramar (`:4198`).
2.  **Paso 5** (`:1359-1386`): se retira **solo** el `<button>` de `:1383`. `#btn-crear-ev` (`:1382`) y la navegacion `#wiz-bottom-nav` (`:1389-1396`) quedan intactos.
3.  **Ficha** (`:4245-4287`): `<select id="ficha-tpl-muestra">` + boton "Guardar muestra". **La clave de guardado es `_tplSilo(theme)` (R1.1), nunca el `const tpl` de `:4250`.** Etiqueta de cada opcion: `nombre` + `fecha` + `categoria_slug`; el `<optgroup>` de la categoria del silo va primero y las opciones de otra categoria llevan el sufijo `(otra categoria)`. **Toda opcion se pinta con `esc()`** (`nombre`, `fecha`, `categoria_slug` y el `value` con `esc(String(ev.id))`): es texto que viene de la base y se inyecta en `innerHTML`, misma regla que ya usa el bloque actual (`:4277`). Si el silo lo comparten N themes, nota fija: "Este silo lo comparten N plantillas: la muestra aplica a todas." (calculable contando `_THEME_TPL_PREVIEW`/`_THEME_TPL` por `_tplSilo(theme)`). Tras un upsert exitoso: actualizar `_templateMuestras`, cerrar/refrescar la ficha y llamar **`_ldAdnSyncPreview(theme)`** para que el panel del paso 2 muestre el evento recien elegido sin recargar la pagina.
4.  **Estado vacio:** `#ld-adn-empty` visible, iframe **sin `src`** y **`sessionStorage.removeItem('ht_preview_payload')`** (dentro de `try/catch`, mismo estilo que `_guardarPreviewPayload()` `:7315-7319`). Limpiar la clave es obligatorio: si queda el payload del evento anterior, un `evento-app.html?preview=1` abierto en otra pestana o un iframe que conserve el `src` viejo seguiria pintando datos que ya no corresponden a la muestra elegida. Texto accionable ("Elige una plantilla y luego su evento de muestra en Mas informacion"). Cero placeholders de contenido.
5.  **Accesibilidad:** el `<select>` lleva `aria-label`; el boton de guardar usa `btn btn-gold btn-sm` (misma familia que `:4278`); 0 colores nuevos, 0 fuentes nuevas.

### 7. Impacto

*   **Datos:** 1 tabla nueva (`public.org_template_muestras`), 1 PK, 2 `CHECK`, 1 trigger, 2 policies, 1 `GRANT`. **0 columnas nuevas** en tablas existentes, **0 cambios** en `eventos`/`organizaciones`/`config_global`. **0 borrados** de filas.
*   **Backend:** **0 endpoints nuevos** (8/8 funciones de Vercel Hobby agotadas), 0 cambios en `api/*.js`. La escritura va por el cliente Supabase del admin.
*   **Kernel:** **0 cambios** en `evento-app.html`; el contrato `{ ev, content, theme, template_id, categoria_slug, effects, i18n }` no se toca.
*   **Admin:** `admin.html` (retiro de 1 boton en `:1383`, helper `_tplSilo()` + `_payloadDesdeEvento()`, carga de `_templateMuestras`, cambio de fuente en `_ldAdnSyncPreview()`, selector en `abrirFichaTheme()`). Ningun ID del Contrato v112 se retira (el boton de `:1383` no tiene `id`).
*   **CSS:** **0 lineas**. No se requiere silo ni tema nuevo.
*   **SEO / publico:** 0 cambios; la tabla no se lee desde el sitio publico.

### 8. Riesgos

1.  **Evento de otra categoria (aceptado, con aviso).** El payload manda `categoria_slug` del **silo** (R6), no del evento; el CSS cargado es el del silo y los datos del evento pueden no encajar (p. ej. un evento de fiesta con silo de cine: sin `dj_lineup`, con `boletos` con otra semantica). Mitigacion: `optgroup` de la categoria del silo primero, sufijo `(otra categoria)` y badge de aviso. No se bloquea en servidor porque el operador puede querer exactamente eso.
2.  **Themes que comparten silo (aceptado por decision del usuario).** 4 themes de cinematografia -> `c1` y 4 de fiesta legacy -> `f1` comparten una sola muestra. Cambiar la muestra desde `arthouse` cambia el preview de `premiere-gold`, `neon-cult-cine` e `interactive-cine`. La UI lo declara; el modelo no lo puede evitar sin pasar la clave a theme (descartado por el usuario).
3.  **Evento borrado o despublicado.** `ON DELETE CASCADE` limpia el puntero; si queda `fase_landing` incompleta o `estado` en borrador, el preview muestra ese estado (correcto). Si el evento desaparece de `_eventos` sin que la fila se limpie (cache vieja del admin), el codigo trata el caso como estado vacio.
4.  **Migracion no aplicada.** El admin degrada (`_MUESTRAS_OK = false`) y avisa; **nunca** cae al sample sintetico (R9). Riesgo operativo real porque `migrations/` se ejecuta a mano.
5.  **Cuota de `sessionStorage`.** Un `content` con muchas imagenes base64 puede acercarse al limite; `_guardarPreviewPayload()` ya captura la excepcion y alerta (`:7315-7319`). La whitelist de `ev` reduce el payload.
6.  **`_SAMPLE_EVENTS` queda como codigo muerto parcial.** Tras este ADR solo lo usan la ficha (`:4282`) y `abrirVistaPreviaDeMuestra()`. No se borra (R5); su retiro exige ADR aparte para no romper el fallback de plantillas sin evento.
7.  **`config_landing.modules` (ADR-093) NO viaja en el preview (limitacion aceptada).** `__evDesdePreview()` (`evento-app.html:1077-1081`) reconstruye `config_landing` **solo** con `{content, effects, i18n}`: el preview no reproduce el apagado/encendido de modulos que el operador configuro en el evento real, y un evento con `modules.gallery = false` se vera en el preview con la galeria visible (default visible de ADR-093, R2). Reflejarlo exige que el kernel acepte `modules` en el payload: **fuera de R10**, no se hace en este ADR. Se declara para que no se lea como bug del preview.

### 9. Verificacion

*   **V1 (documental):** `grep -c "ADR-094" "Sistema QR desarrollo/DECISIONS.md"` -> 1 fila en el indice + 1 nota de numeracion; `grep -c "org_template_muestras" admin.html` -> 0 antes de implementar (este ADR no toca codigo).
*   **V2 (SQL, tras `@sql-security`):** aplicar `migrations/adr094_org_template_muestras.sql` en el SQL Editor; comprobar que el pre-flight (B0) pasa, `\d public.org_template_muestras` (PK `(org_id, template_id)`, 2 CHECK), `relrowsecurity = true`, 2 policies, 1 trigger y el indice `org_template_muestras_evento_idx`. Re-ejecutar el script completo -> **misma** definicion, sin error (PK/CHECK recreados por `DROP IF EXISTS` + `ADD`). INSERT con `evento_id` de otra org -> falla con **SQLSTATE 42501** y un unico mensaje, sin eco del id. Upsert repetido -> 1 fila (idempotente por PK).
*   **V3 (RLS y privilegios):** con JWT de org A, `select` devuelve solo sus filas; con JWT de org B, 0 filas de A; con la clave **anon**, permiso denegado (`REVOKE ALL ... FROM anon` verificado en `information_schema.role_table_grants`); upsert con `org_id` ajeno -> bloqueado por `WITH CHECK`.
*   **V4 (payload, @admin-dev):** smoke `scripts/smoke_template_muestra.js` (nuevo) con `vm` + stub: (a) `_payloadDesdeEvento` emite **exactamente** las 7 claves; (b) `_tplSilo(theme)` devuelve `c1`/`b2`..`b5`/`f1` para los 12 themes sin entrada en `_THEME_TPL` (contrato de R1.1: la clave guardada es la que lee el preview); (c) sin muestra -> `_ldAdnSyncPreview` deja el iframe **sin `src`**, `#ld-adn-empty` visible y `ht_preview_payload` **eliminado** de `sessionStorage`; (d) `_SAMPLE_EVENTS` no aparece en el camino de ADN; (e) `null` para theme sin silo en `_TPL_CON_SILO`; (f) guardar muestra refresca `_ldAdnSyncPreview(theme)`.
*   **V5 (UI manual):** paso 5 sin boton "Vista previa"; paso 2 muestra el evento elegido; cambiar de plantilla dentro del mismo silo mantiene la muestra; sin muestra -> estado vacio; error de tabla ausente -> aviso de migracion, sin sample.
*   **V6 (Escudo GOLD, antes de desplegar):** `node --check` de los bloques JS inline de `admin.html` y balance de `div` con delta 0 respecto al baseline; ASCII-safety delta 0 en `admin.html`.

### 10. Pendientes y preguntas abiertas

1.  `@sql-security`: escribir y **NO** ejecutar `migrations/adr094_org_template_muestras.sql` con el contrato de la seccion 4 (pre-flight B0, tabla desnuda + constraints B2/B3, indice B4, trigger con un unico `RAISE ... ERRCODE '42501'`, `REVOKE ALL ... FROM anon` en B7) y verificar en la instancia real que `get_org_id()` e `is_master_org_user()` viven en `public`; si no, descalificar la llamada en las policies antes de aplicar.
2.  `@admin-dev`: implementar secciones 5 y 6 en `admin.html`; retirar `:1383`; helper `_tplSilo()` como **unica** resolucion de clave (R1.1, prohibido el `tpl` de `:4250`/`:4237`); cargar `_templateMuestras` con degradacion; reemplazar la fuente de `_ldAdnSyncPreview()`; limpiar `ht_preview_payload` en el estado vacio; `esc()` en las opciones del select; refrescar el preview tras guardar.
3.  `@docs-keeper`: fila en `TASKS.md` y hito en `NEXT.md` (no incluidos en este ADR).
4.  Preguntas abiertas: (a) si un miembro con rol distinto de superadmin puede cambiar la muestra (hoy la RLS deja escribir a toda la org); (b) si conviene un `updated_by` visible en la ficha ("ultima eleccion por X"); (c) si el preview debe advertir cuando el evento elegido esta en `estado = borrador`.
