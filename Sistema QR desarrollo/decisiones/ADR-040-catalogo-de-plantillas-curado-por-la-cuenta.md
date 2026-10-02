---
doc: ADR-040
version: v1.16-GOLD (heredada de DECISIONS.md)
fecha: 2026-10-01
origen: DECISIONS.md L441-592 (AMPLIACION/_backups/DECISIONS.md.2026-10-01.bak)
version_previa: DECISIONS.md v1.16-GOLD
relacionados: [../DECISIONS.md, ../INDEX.md]
estado: vigente (ver campo Estado dentro del ADR)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [DECISIONS.md](../DECISIONS.md) · [INDEX](../INDEX.md). Texto original íntegro debajo (L441-592 del original).

#### ADR-040: Catálogo de Plantillas Curado por la Cuenta Master (Visibilidad Global de Themes) — Fuente de Verdad en `config_global`
* **ID:** ADR-040 | **Fecha:** 15 de septiembre de 2026 | **Estado:** Aprobado en diseño (original) → **IMPLEMENTADO (ver ADR-045)**. El diseño original de este ADR fue materializado íntegro por el equipo `*-free` (migración + `admin.html`) y validado por QA (Escudo GOLD PASS, QA APTO). Ver **Enmienda I** al final de este ADR para el estado real vigente y las correcciones al contrato; la especificación original se conserva íntegra debajo (Cero Borrado documental, Regla de Oro #3).
* **Autor:** Chief Architect.
* **Problema:** La cuenta master —definida en ADR-025 como `rol === 'superadmin'` **Y** `_orgData.is_master_org === true`, implementado en `_IS_SYSTEM_ADMIN()` (`admin.html:3595-3596`)— no tiene forma de curar el catálogo de plantillas que ven los administradores de todas las organizaciones. Hoy las 16 tarjetas `.ld-theme-card` (`admin.html:545-614`) están hardcodeadas en el HTML del Wizard y se ofrecen por igual a todo el mundo; los mapas `_THEME_TYPE` (`admin.html:2763-2772`) y `_THEME_TPL` (`admin.html:2776-2781`) tampoco admiten exclusión. Se pide que la cuenta master elija qué templates mostrar y cuáles ocultar, sin romper la edición de eventos que ya usan un template que después se oculte.
* **Diagnóstico (auditoría del archivo real, ADR-006 — nada de lo siguiente se dio por supuesto):**
   1. **Catálogo:** 16 cards agrupadas por categoría — 4 cinematografía (líneas 543-561), 8 fiesta (562-596), 4 campaña (597-615). Los grupos usan `data-cat` **tanto en el rótulo como en el grid** (6 nodos), y `seleccionarCategoria()` (`2858-2875`) los filtra con `el.style.display = (el.dataset.cat === tipo) ? '' : 'none'` (línea 2866).
   2. **`seleccionarTheme()` (`2799-2823`) resuelve por `document.querySelectorAll('.ld-theme-card')` y compara `b.dataset.theme`.** Ninguna línea de la función consulta visibilidad del nodo — **opera igual sobre una card oculta**. Este es el cimiento técnico de "ocultar sin borrar".
   3. **Auto-preselección ciega a visibilidad:** `seleccionarCategoria()` línea 2872 hace `Object.keys(_THEME_TYPE).find(k => _THEME_TYPE[k] === tipo)` — el primer theme del objeto por orden de inserción, sin ningún filtro.
   4. **Edición de evento existente:** la carga del Wizard resuelve `theme = _TPL_THEME[String(ev.template_id||'').toLowerCase()] || cfg.theme` (línea 4416) y ejecuta `seleccionarCategoria(tipo)` (4427) **y luego** `seleccionarTheme(theme)` (4428): el theme real del evento **gana** sobre la auto-preselección. Al guardar, `template_id: _THEME_TPL[_ldThemeSeleccionado] || _ldThemeSeleccionado || null` (líneas 4718, 5803, 5899), **sin validación contra catálogo**.
   5. **Precedente de "no ofrecer pero no borrar":** `_TEMAS_POR_DEFINIR` (línea 2856) + tag "Próximamente" inyectado en `DOMContentLoaded` (3022-3032) — las cards siguen siendo seleccionables (Cero Borrado). La feature de ocultado es ortogonal y componible con esto.
   6. **No existe tabla de configuración global.** En `migrations/` (adr030..adr039) no hay `settings` ni `configuracion`, y `getConfig()` (`admin.html:2404-2415`) es **credenciales de Supabase en localStorage** (`STORAGE_CFG='hostal_supa_cfg'`), no configuración de producto. El único patrón de configuración JSONB del proyecto es **por entidad**: `eventos.config_landing` (adr030/033/035).
   7. **`organizaciones` ya tiene `is_master_org` (ADR-025) y `plan='enterprise'` (ADR-037);** la org maestra es una **cáscara sin eventos propios por diseño** (addendum ADR-025: `loadEventos()`/`renderPanel()` devuelven vacío para ella, y eso es comportamiento esperado, no bug).
   8. **Ruta y gating ya existentes:** `#/sistema` → `pg-globaladmin` (línea 2628), ítem de sidebar `data-vis="system"` (línea 433), y `_canAccess()` ya devuelve `isSys` para `config`/`globaladmin` (línea 8825). El Panel de Sistema ya tiene sub-tabs con `gaTab()` (3599-3607) y `loadGlobalStats()` (3610). **No hace falta ruta nueva.**
   9. **Trabajo paralelo (f9 / mistico):** `css/templates/fiesta/f9.css` (silo "Místico / Rastro MC", confirmado en HEAD, commit `981a4e8`) existe, y `evento.html` ya lo referencia (`1180-1285`, v1.4.0, `.tpl-f9`); pero el theme `mistico` **aún no existe** como card ni en `_THEME_TYPE`/`_THEME_TPL` en `admin.html`. El diseño debe ser forward-compatible sin tocar esa otra tarea.
   10. **Instancia real:** las funciones RLS `get_org_id()` / `is_superadmin()` **no están en el repo** (viven en la BD; adr036 las asume y las usa). Toda política/helper nueva debe definirse defensivamente en la migración.
* **Opciones evaluadas:**
   * **Opción A — localStorage de la cuenta master.** `hidden` persistido en `localStorage` (patrón `STORAGE_CFG`/`getConfig()`, 2404-2415).
     * Pros: cero migración, cero RLS, cero recarga de caché PostgREST; lectura síncrona (pinta antes del prerender); usa un patrón ya existente; cero superficie de seguridad nueva.
     * Contras: **es por navegador + por origen**, no por cuenta — el master que lo cambie en su portátil no lo cambia en su móvil ni en el navegador del socio; **los administradores de las otras organizaciones jamás lo verán**, que es justo lo que la feature promete ("qué templates mostrar" a los clientes); se pierde al limpiar almacenamiento (o en modo incógnito); no hay `updated_by`/`updated_at` ni auditoría; contradice la dirección "Supabase-first" del producto (los datos de negocio viven en la BD, no en el dispositivo).
     * Veredicto: **insuficiente como fuente de verdad.** Solo es aceptable como caché de lectura (ver Decisión), nunca como almacén. Incumple "aplicable a todos los usuarios/dispositivos".
   * **Opción B — columna JSONB nueva en la fila de la organización maestra** (p. ej. `organizaciones.config_templates`).
     * Pros: una sola columna, sin tabla nueva; la fila maestra ya existe (ADR-025); `update_organizaciones` ya permite actualizar la fila propia (`id = get_org_id()`, verificado en ADR-025 diagnóstico punto 1: no depende de slug), así que el **camino de escritura** casi no requeriría RLS nueva; semánticamente cerca de `color_primario`/`nombre_app`/`plan`.
     * Contras — **hallazgo decisivo verificado contra `migrations/adr036_rls_legacy_cleanup.sql` (líneas 168-234):** adr036 reemplazó `public_organizaciones_select` por una versión **acotada a organizaciones dueñas de ≥1 evento público**. La org maestra tiene **cero eventos propios por diseño** (punto 7 del diagnóstico), por lo que **la fila maestra deja de ser legible para el resto de organizaciones** (y para el tráfico anónimo). Con adr036 ya enunciado en TSK-026 como intención, la config en esa fila **no llegaría a los administradores cliente** salvo agregando una excepción explícita a una política que se acaba de endurecer por seguridad. Además: (2) mezcla semánticamente configuración **de plataforma/producto** con datos **de un inquilino** (la org maestra), y futuras configuraciones globales (defaults, feature flags, categorías permitidas) se acumularían en una fila de organización; (3) auditoría incómoda (updates de fila completa que también tocan branding/plan); (4) un futuro split/reasignación estilo ADR-039 arrastraría la config.
     * Veredicto: **viable pero con deuda oculta.** Requiere tocar el mismo frente de seguridad que adr036 acaba de limpiar.
   * **Opción C — tabla nueva `config_global` (fila única + columna JSONB `templates`).**
     * Pros: frontera semántica limpia (config de plataforma ≠ datos de inquilino); el `SELECT` es explícito e independiente (dato **no sensible**: qué plantillas ofrece el producto), por lo que **no depende** de la política acotada de `organizaciones` de adr036; la escritura se restringe con un helper `SECURITY DEFINER` espejo exacto de `_IS_SYSTEM_ADMIN()` (evita recursión de RLS sobre `organizaciones`/`perfiles`, mismo recurso que adr037 usó con `fn_inscritos_freemium_limite`); auditabilidad nativa (`updated_at`/`updated_by`); lugar natural para la próxima config global (`version` interno permite evolucionar el documento); migración **aditiva e idempotente** — no altera ninguna tabla existente (Cero Borrado).
     * Contras: requiere migración + RLS + `NOTIFY pgrst 'reload schema'`; una tabla más; un helper nuevo cuyo owner debe ser correcto (postgres/service); el `SELECT` legible por todo `authenticated` es una decisión de privacidad que se documenta abajo (aceptable: no hay PII).
     * Veredicto: **RECOMENDADA.**
   * **(Descartada de entrada) `eventos.config_landing`:** es configuración **por evento**, no global; un evento no puede contener la curación del catálogo que aplica a los demás.
* **Decisión (arquitectura elegida):**
   1. **Fuente de verdad = Opción C: tabla nueva `public.config_global`** de **fila única** (`id = 'default'`), con columna `templates jsonb NOT NULL DEFAULT '{}'::jsonb`. Se guarda **lo oculto**, no lo visible (ver contrato abajo): así toda plantilla nueva (p. ej. el futuro `mistico`/`f9`) nace **visible por defecto** sin tocar la config — fail-open y forward-compatible.
   2. **Caché opcional = Opción A como read-through cache:** `localStorage` guarda una **copia** del documento (`htz_tpl_visibilidad`) para pintar sin parpadeo (evitar que una card aparezca y luego desaparezca). **Nunca es autoritativa**: en cada `loadAll()` se relee la BD y se sobrescribe la caché. Si la lectura falla, se usa la caché; si tampoco hay caché, **fail-open: todo visible** (ocultar es cosmético; no se puede bloquear la creación de eventos por un fallo de red).
   3. **Escritura: solo la cuenta master.** Doble candado: UI dentro de `pg-globaladmin` (ya gated por `_canAccess('globaladmin') === isSys`) **y** RLS `INSERT/UPDATE/DELETE` restringida por `public.is_master_org_user()` (espejo SQL de `_IS_SYSTEM_ADMIN()`). `@free-plan`/`@free-build` no deciden permisos: los heredan de ADR-025.
   4. **Ubicación UI:** nuevo sub-tab **"Plantillas"** en el `.subtabs` existente de `pg-globaladmin` (líneas 2035-2039), extendiendo el array de `gaTab()` (línea 3600) con `'plantillas'` y agregando `ga-panel-plantillas`. **No se crea ruta, endpoint ni función serverless** (consistente con el presupuesto y con que este repo usa Supabase directo).
   5. **Aplicación al render = ocultar sin borrar.** Se añade una clase CSS (no `inline style`) sobre los nodos existentes:
      ```css
      .ld-theme-oculto{display:none!important}
      .ld-theme-legacy-forzado{display:block!important}
      ```
      y una única función aplicadora `_aplicarTemplatesOcultos()` que, tras leer la config, recorre `document.querySelectorAll('.ld-theme-card')` y hace `card.classList.toggle('ld-theme-oculto', hiddenSet.has(card.dataset.theme))`. **Nunca `card.remove()`, nunca se edita el HTML hardcodeado, nunca se borra una card** (Cero Borrado, Regla de Oro #2/#3). Los 16 nodos siguen en el DOM.
   6. **Se llama en dos puntos:** (a) al final de `loadAll()` (4161-4172, que ya corre tras login en 8807 y tras `saveConfig()` en 2566) mediante un `await _cargarConfigGlobal()` previo; (b) inmediatamente al guardar en el sub-tab Plantillas, para feedback en vivo.
* **Contrato del JSONB (`config_global.templates`, versión 1):**
   ```json
   {
     "version": 1,
     "hidden": ["tech-futurista", "neon-cult-cine"]
   }
   ```
   * La clave de ocultado es el **slug del theme** (`card.dataset.theme`), que es el átomo que exponen las cards y también la clave de `_THEME_TYPE` y `_THEME_TPL`. Es agnóstico al silo: cubrirá `mistico` el día que se registre, sin migración.
   * `hidden` es un **array de slugs ocultos**; ausente o `[]` = catálogo completo visible. Slugs desconocidos quedan **inertes** (no rompen nada) — la UI solo ofrece checkboxes de cards existentes, por lo que no puede introducir un typo.
   * `version` permite evolucionar el documento (p. ej. `order`, `featured`, `por_categoria`) sin romper lectores viejos.
   * **Regla de merge (Cero Borrado aplicado al documento):** nunca se reemplaza el documento completo desde la UI; la actualización se hace leyendo el objeto actual, mutando la clave `hidden` y persistiendo con merge JSONB del lado SQL:
     ```sql
     UPDATE public.config_global
     SET templates  = COALESCE(templates,'{}'::jsonb) || $1::jsonb,
         updated_at = now(),
         updated_by = auth.uid()
     WHERE id = 'default';
     ```
   * **Concurrencia:** update optimista con `updated_at` (el cliente envía la versión leída; si `updated_at` cambió, se re-lee y se re-mezcla) para no perder el cambio de una segunda sesión master.
* **Caso borde — evento que ya tenía un template ahora oculto (resolución explícita, sin romper edición):**
   1. **El ocultado afecta al selector, jamás al resolvedor.** `seleccionarTheme()` (2799-2823) y `_TPL_THEME` (2784-2787) operan sobre los mapas en memoria, no sobre visibilidad ni sobre `hidden`. Un evento con `template_id` oculto se sigue cargando, editando y guardando con su `template_id` intacto.
   2. **Orden de la carga del editor (4416-4428) es favorable:** `seleccionarCategoria(tipo)` corre antes y `seleccionarTheme(theme)` después, así que el theme real del evento **siempre gana**. Único cuidado: al parchear la auto-preselección (punto 3 de abajo) debe quedar claro que el `seleccionarTheme(theme)` de la línea 4428 es el que manda.
   3. **Affordance visual obligatoria (revelación local, no persistente):** si el theme del evento editado está en `hidden`, se agrega temporalmente `ld-theme-legacy-forzado` a **esa** card (y solo a esa) junto a una nota informativa: "Esta plantilla ya no está en el catálogo; tu evento la conserva. Puedes mantenerla o cambiar a una disponible." No se persiste ningún cambio de la config por abrir un editor. Cero Borrado: no se elimina nada.
   4. **No hay allowlist en el guardado.** Se mantiene `template_id: _THEME_TPL[_ldThemeSeleccionado] || _ldThemeSeleccionado || null` (4718/5803/5899). Ocultar es **curación de catálogo / UX, NO control de seguridad, NO enforcement de licencia, NO validación server-side**. Si el negocio quisiera *prohibir* un template, sería otro ADR con enforcement en BD — explícitamente fuera de alcance aquí.
   5. **La página pública no consulta `hidden`.** `evento.html` / `f7.html` no leen `config_global` para elegir CSS: si un template se oculta por error, las páginas vivas siguen renderizando. Defensa en profundidad.
   6. **Auto-preselección arreglada:** se reemplaza la línea 2872 por un helper `_primerThemeVisible(tipo)` que itera `Object.keys(_THEME_TYPE)`, filtra por `tipo` **y** por `!hiddenSet.has(k)` (reusando el mismo criterio por si el día de mañana un theme nuevo vive solo en `_THEME_TYPE` sin card). Si no hay ninguno visible, no preselecciona.
   7. **Categoría con cero visibles:** si el master oculta todas las cards de una categoría, `[data-cat]` (rótulo + grid) se oculta con un flag `data-cat-empty="1"` y `seleccionarCategoria()` (línea 2866) respeta ese flag:
      ```js
      el.style.display = (el.dataset.cat === tipo && el.dataset.catEmpty !== '1') ? '' : 'none';
      ```
      y se muestra un mensaje de estado vacío ("No hay plantillas disponibles para esta categoría"). Es un cambio de **una línea** en el filtro existente, no un rediseño.
   8. **Guardas de la UI master (en el sub-tab):** (a) **bloqueo duro** de dejar el catálogo completo en cero templates visibles (sin catálogo, el Wizard no puede crear nada); (b) **aviso suave** (confirm) al dejar una categoría en cero visibles, permitido porque el negocio puede querer retirar temporalmente una categoría.
* **Especificación de migración (borrador para `@sql-security`; NO creada en esta sesión):** archivo propuesto `migrations/adr040_config_global_templates.sql`, idempotente, 100% ASCII, ejecutable en SQL Editor, con rollback comentado. Contenido normativo:
   1. **Tabla + RLS:**
      ```sql
      CREATE TABLE IF NOT EXISTS public.config_global (
        id         text PRIMARY KEY,
        templates  jsonb NOT NULL DEFAULT '{}'::jsonb,
        updated_at timestamptz NOT NULL DEFAULT now(),
        updated_by uuid
      );

      ALTER TABLE public.config_global ENABLE ROW LEVEL SECURITY;

      INSERT INTO public.config_global (id, templates)
      VALUES ('default', '{}'::jsonb)
      ON CONFLICT (id) DO NOTHING;
      ```
      (`updated_by` sin FK a `auth.users` a propósito: es auditoría, no integridad referencial, y evita acoplar la migración al esquema `auth`.)
   2. **Helper espejo de `_IS_SYSTEM_ADMIN()` (SECURITY DEFINER, evita recursión de RLS):**
      ```sql
      CREATE OR REPLACE FUNCTION public.is_master_org_user()
      RETURNS boolean
      LANGUAGE sql STABLE SECURITY DEFINER
      SET search_path = public, pg_temp
      AS $fn$
        SELECT EXISTS (
          SELECT 1
          FROM public.perfiles p
          JOIN public.organizaciones o ON o.id = p.org_id
          WHERE p.id = auth.uid()
            AND p.rol = 'superadmin'
            AND o.is_master_org = true
        );
      $fn$;
      ```
      **Condición de diseño:** el owner de la función debe ser un rol con lectura sobre `perfiles`/`organizaciones` (en Supabase, `postgres`). Se documenta porque `is_superadmin()`/`get_org_id()` no viven en el repo (diagnóstico punto 10).
   3. **Políticas:**
      ```sql
      DROP POLICY IF EXISTS "config_global_select_auth" ON public.config_global;
      CREATE POLICY "config_global_select_auth"
        ON public.config_global FOR SELECT
        TO authenticated
        USING (true);

      DROP POLICY IF EXISTS "config_global_write_master" ON public.config_global;
      CREATE POLICY "config_global_write_master"
        ON public.config_global FOR ALL
        TO authenticated
        USING (public.is_master_org_user())
        WITH CHECK (public.is_master_org_user());
      ```
      Lectura `authenticated` (no `anon`): el dato no es sensible, pero el único consumidor es `admin.html` (post-login). Si algún día una página pública necesitara el catálogo, se extiende a `anon` en un ADR explícito — no por defecto.
   4. **Grants y caché:** `GRANT SELECT, INSERT, UPDATE, DELETE ON public.config_global TO authenticated;` y `NOTIFY pgrst, 'reload schema';` (mismo requisito operativo que ADR-015/035).
   5. **Rollback comentado:** `DROP POLICY ... ; DROP TABLE IF EXISTS public.config_global;` y `DROP FUNCTION IF EXISTS public.is_master_org_user();` (solo si ninguna otra política la usa).
* **Cambios especificados en `admin.html` (para el Lead Developer; NO ejecutados aquí):** (1) CSS `.ld-theme-oculto`/`.ld-theme-legacy-forzado` junto a las reglas `.ld-theme-card` (líneas 128-130); (2) `_GLOBAL_CFG` + `hiddenSet` en memoria y `_cargarConfigGlobal()` / `_aplicarTemplatesOcultos()`; (3) `await _cargarConfigGlobal()` al inicio de `loadAll()` (4161) y llamada a `_aplicarTemplatesOcultos()` al final; (4) `_primerThemeVisible()` reemplazando la línea 2872; (5) el filtro `[data-cat]` de la línea 2866 con el guard `data-cat-empty`; (6) sub-tab "Plantillas" en `pg-globaladmin` + `'plantillas'` en el array de `gaTab()` (3600) + `ga-panel-plantillas` con los 16 checkboxes (leídos del DOM real, no de una lista duplicada); (7) revelación legacy en el editor (4416-4428) y mensaje de estado vacío por categoría. **Cero reescritura de `seleccionarTheme()`, cero cambios a `_THEME_TYPE`/`_THEME_TPL`, cero cambios a `evento.html`/`f7.html`/`f9.css`.**
* **Justificación:** (1) La feature es **curación de plataforma**, no dato de inquilino, y la evidencia del repo muestra que el candidato "natural" (columna en la org maestra) está contaminado por una decisión de seguridad ya tomada (adr036 acota `public_organizaciones_select` y la org maestra no tiene eventos propios) — se descarta por evidencia, no por gusto. (2) Se guarda **lo oculto** en vez de lo visible para que cada plantilla nueva (el caso `mistico`/`f9` ya en HEAD) nazca visible sin migración ni acción del master: fail-open es el modo correcto para un catálogo. (3) Se aplica "ocultar sin borrar" con una **clase CSS sobre nodos que permanecen en el DOM**, apoyándose en el hallazgo de que `seleccionarTheme()` ya funciona sobre nodos ocultos — es la ruta de mínimo riesgo y máximo respeto al Cero Borrado. (4) El caso "evento con template oculto" se resuelve manteniendo el resolvedor independiente del catálogo, sin allowlist en el guardado y con revelación local no persistente; así ninguna edición existente se rompe ni se normaliza silenciosamente. (5) El candado de escritura se replica en BD (`is_master_org_user()`) para que el permiso no dependa solo del DOM, siguiendo el patrón SECURITY DEFINER ya establecido en adr037.
* **Impacto:** Diseño sin cambios de código en esta sesión. Al implementarse: **1 migración nueva** (`migrations/adr040_config_global_templates.sql`, aditiva e idempotente), **0 tablas existentes alteradas**, **0 endpoints nuevos** (este repo no tiene `api/`; persiste Supabase directo), **0 cambios a `evento.html`/`f7.html`/`f9.css`**, **0 cambios a `_THEME_TYPE`/`_THEME_TPL`**, y cambio de **una línea** en el filtro `[data-cat]` más un helper de auto-preselección en `admin.html`. Dependencia operativa: recarga del caché de esquema de PostgREST antes de desplegar el front, o la lectura de `config_global` fallará silenciosamente (fail-open: todo visible) — no bloquea, pero la feature no se vería.
* **Pendientes (no ejecutados):**
   1. Materializar `migrations/adr040_config_global_templates.sql` con `@sql-security` y ejecutarla en la instancia (patrón manual de Dirección).
   2. Implementar el sub-tab "Plantillas", el helper de lectura/aplicación y los ajustes de auto-preselección/filtro con `@frontend-tpl` (o `@js-silo-dev`), con Escudo GOLD (`node --check`, balance de `<div>`, ASCII-safety).
   3. Verificación visual (Prueba de Carga Dual) por Dirección: catálogo completo por defecto; ocultar 1 card y confirmar que desaparece en otro dispositivo/otra org; editar un evento cuyo theme se ocultó y confirmar que conserva su `template_id` al guardar.
   4. Decisión de Dirección sobre la semántica de "categoría con cero visibles" (se especifica permitida con aviso + estado vacío; alternativa: bloquear).
   5. Registro del theme `mistico`/silo `f9` en el catálogo (card + `_THEME_TYPE` + `_THEME_TPL`) es tarea **paralela independiente**; este ADR no la bloquea ni la asume.
* **Referencias:** ADR-025 (identidad master/`is_master_org`, helper `_IS_SYSTEM_ADMIN()` y org maestra como cáscara), ADR-037 (`SECURITY DEFINER` + `plan='enterprise'`), ADR-021/022 (patrón de envoltura in-situ y sub-tabs), `migrations/adr036_rls_legacy_cleanup.sql` (evidencia del acotamiento de `public_organizaciones_select` que descarta la Opción B), `migrations/adr035_evento_i18n.sql` (patrón de migración JSONB + reload de PostgREST), ADR-039 (frontera de tenant y riesgo de reasignaciones). **NOTA (ADR-006):** este ADR documenta exclusivamente el estado real del repositorio verificado en esta sesión; las suposiciones del contexto recibido que no coincidían con el repo (existencia de `api/`, tabla `settings`, modelo `tags`/`CATEGORY_TAG_FIELDS`, ADR-006 como "baseline de verdad") se corrigieron contra el archivo real: este repo no tiene `api/`, no tiene tabla de configuración, y su ADR-006 es "Nomenclatura Atómica por Categorías (Silos)".

* **Enmienda I — IMPLEMENTADO (16 de septiembre de 2026, ver ADR-045):** este ADR pasó de "solo diseño" a IMPLEMENTADO con la Entrega 2 del ciclo documental. Registro de la enmienda (corrige y completa la especificación original sin borrarla):
   1. **Contrato JSONB vigente: `version: 2`.** El documento §482 especificaba `{ "version": 1, "hidden": [...] }` **sin** clave `order`. El contrato real implementado en `migrations/adr040_config_global_templates.sql` (cabecera del archivo) y consumido por `admin.html` es:
      ```json
      { "version": 2, "hidden": ["slug1"], "order": ["slugA","slugB"] }
      ```
      `order` = orden de presentación de slugs de theme (no listados van después, en orden DOM), incorporado por mandato de Dirección de **reordenar** el catálogo además de ocultar. `version` permite la evolución del documento sin romper lectores viejos.
   2. **Migración materializada (real):** `migrations/adr040_config_global_templates.sql` — idempotente (`IF NOT EXISTS`/`DROP POLICY IF EXISTS`/`CREATE OR REPLACE`), 100% ASCII (0 bytes > 127), aditiva pura (0 tablas existentes alteradas, Cero Borrado). Crea: tabla `public.config_global` de fila única (`id='default'`, `templates jsonb NOT NULL DEFAULT '{}'`, `updated_at timestamptz`, `updated_by uuid`); helper `public.is_master_org_user()` (SECURITY DEFINER, `search_path=public,pg_temp`, espejo SQL de `_IS_SYSTEM_ADMIN()`: `rol='superadmin'` + `o.is_master_org=true`); políticas RLS (`config_global_select_auth` SELECT para `authenticated` con `USING (true)`; `config_global_write_master` ALL solo con `is_master_org_user()` en USING y WITH CHECK); `GRANT SELECT, INSERT, UPDATE, DELETE ON public.config_global TO authenticated` + `GRANT EXECUTE` sobre el helper y la RPC; `NOTIFY pgrst, 'reload schema'`; rollback comentado al final.
   3. **RPC nueva (más allá de la especificación original):** `public.fn_config_global_merge(p_templates jsonb) RETURNS TABLE (templates jsonb, updated_at timestamptz)` — SECURITY DEFINER que valida la cuenta master (`RAISE EXCEPTION 'Solo la cuenta master puede modificar el catalogo de plantillas' USING ERRCODE = '42501'`), aplica **merge JSONB server-side** (`COALESCE(templates,'{}') || p_templates`), sella `updated_at = now()` y `updated_by = auth.uid()`, y devuelve la fila resultante. Es el único camino de escritura del front.
   4. **Funciones reales implementadas en `admin.html` (verificadas, ADR-006):** CSS `.ld-theme-oculto{display:none!important}`/`.ld-theme-legacy-forzado{display:block!important}` (L131-132); estado en memoria `_GLOBAL_CFG`/`hiddenSet`/`_orderArr`; `_cargarConfigGlobal()` (read-through cache `htz_tpl_visibilidad`, fail-open, con `console.warn` si `res.error`); `_guardarConfigGlobal(hidden, order)` vía la RPC `fn_config_global_merge` (**sin** comparación optimista de timestamps — ver la corrección A abajo); `_aplicarTemplatesOcultos()` (solo `classList.toggle` sobre `.ld-theme-card` — **jamás** `card.remove()` — más reorden por `appendChild` según `order`); `_primerThemeVisible(tipo)` reemplazando la auto-preselección ciega; guard `data-cat-empty` en el filtro `[data-cat]` de `seleccionarCategoria()`; sub-tab **"Plantillas"** en `pg-globaladmin` (extiende `gaTab()` con `'plantillas'` + `ga-panel-plantillas` + `_renderPanelPlantillas()`/`guardarPlantillasGlobal()`) con MOSTRAR/OCULTAR/REORDENAR, **bloqueo duro** de dejar el catálogo en cero templates visibles y **aviso suave** por categoría en cero; revelación legacy no persistente al editar un evento con template oculto (clase temporal + nota informativa, limpiada al cancelar/crear); el fallback de `toggleLandingConfig()` ahora usa `_primerThemeVisible('cinematografia')`.
   5. **Corrección a la afirmación "0 cambios a `_THEME_TYPE`/`_THEME_TPL`" (queda obsoleta):** la Entrega 1 del ciclo (ADR-044) **sí añadió entradas** a ambos mapas al registrar el silo `f11`: `_THEME_TYPE['fosforescente']='fiesta'` y `_THEME_TPL['fosforescente']='f11'` (más el derivado `_TPL_THEME['f11']='fosforescente'` y el label en `names`). La afirmación del Impacto y de la Decisión punto 5 del documento original era válida al momento del diseño (antes de ADR-041/044) pero ya no describe el estado real — se corrige aquí sin borrar el texto original.
   6. **Capacidad de REORDENAR añadida:** el ADR-040 original solo especificaba ocultar; la implementación vigente agrega `order` con persistencia vía la misma RPC (merge JSONB sin reemplazo de documento), cumpliendo el mandato de Dirección de pedir el reordenamiento del catálogo.
   7. **Defectos del QA corregidos antes del cierre (detalle en `ERRORES_HISTORICOS.md` §13 y ADR-045):** A) bloqueo optimista roto por formato `timestamptz` (Z vs +00:00) — eliminado en favor de la RPC; B) éxito silencioso si RLS negaba — ahora `return false` honesto ante RPC sin fila; C) `updated_by` nunca se escribía — sellado por la RPC; D) faltaba merge JSONB server-side — incorporado; E) lectura sin observabilidad — `console.warn` en fail-open; F) colisión de namespace `data-cat` entre el panel Plantillas y el Wizard — resuelto con atributo `data-tplcat` propio del panel; G) mensaje de categoría vacía no filtrado — corregido; H) revelación legacy no se limpiaba al cancelar/crear — limpieza en el ciclo del Wizard.
   8. **Caso borde confirmado vigente:** la página pública (`evento.html`/`f7.html`) **no consulta `hidden`**; ocultar es curación de catálogo/UX, NO seguridad, NO allowlist en el guardado (`template_id: _THEME_TPL[...] || ... || null` sin validación server-side contra `hidden`). Comportamiento idéntico al especificado en el documento original (puntos 4 y 5 del caso borde).
   9. **Pendiente de ejecución (Dirección/Lead Developer):** ejecutar `migrations/adr040_config_global_templates.sql` manualmente en la instancia real de Supabase. Sin la tabla, el front cae en fail-open (todo visible) — no bloquea, pero la feature no se ve (misma dependencia operativa de reload de PostgREST documentada en el Impacto original).

