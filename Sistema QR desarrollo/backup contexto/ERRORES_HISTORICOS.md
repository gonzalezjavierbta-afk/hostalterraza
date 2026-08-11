# 🛡️ ERRORES.md — Memoria de Blindaje y Lecciones Aprendidas (v1.8.0-STABLE)

Este documento registra el historial de fallos críticos detectados durante la evolución del Sistema QR Hostal Terraza. Su propósito es servir de base para el Escudo de Auditoría GOLD, evitando la regresión técnica en nuevos silos visuales[cite: 2].

---

## 1. Errores de Estructura y Cero Borrado (STRICT)

### 🚨 Violación del Contrato de Datos (v100-v104)
* **Problema:** Durante la simplificación del código para insertar patrocinadores, se eliminaron elementos físicos del HTML[cite: 2].
* **Impacto:** Se perdieron los SVGs de las tarjetas de datos y el indicador "+" del FAQ, degradando la interfaz premium[cite: 2].
* **Blindaje:** Prohibición absoluta de borrar IDs del Contrato v107. Si un módulo no se desea, se usa `display: none`[cite: 2].

### 🚨 Colapso de Contenedores Flex (v1.5.12)
* **Problema:** Al usar `display: flex` en el nodo raíz de módulos multimedia (#mod-video, #mod-lineup), los contenedores colapsaban visualmente a 0px tras la inyección dinámica de JS[cite: 2].
* **Causa:** El patrón `max-width + margin: auto` requiere que el div se comporte como bloque. Flex convertía el contenido en ítems que se encogían al estar inicialmente vacíos[cite: 2].
* **Blindaje (ADR-007):** Uso mandatorio de `display: block !important` en contenedores de inyección masiva[cite: 2].

---

## 2. Errores Visuales y de Activos (High-Fidelity)

### 🚨 Corrupción por Filtros CSS (v107-Legacy)
* **Problema:** El uso de `filter: brightness(0) invert(1)` sobre imágenes sin canal alfa real (como favicons) convirtió los logos en "recuadros blancos" sólidos[cite: 2].
* **Impacto:** Ruptura de la estética premium de $10,000[cite: 2].
* **Blindaje:** No aplicar filtros de inversión sin confirmar transparencia total. Usar colores originales en "Debug Mode" ante la duda[cite: 2].

### 🚨 Desconexión Visual Multimedia (v1.5.8)
* **Problema:** El video se percibía "lejos" de la fecha y el reloj (Countdown/Meta)[cite: 2].
* **Causa:** La regla global de secciones inyectaba un respiro superior de `5rem` por defecto[cite: 2].
* **Blindaje (ADR-010):** Forzar `padding-top: 0 !important` en `#mod-video` dentro de cada silo visual[cite: 2].

---

## 3. Errores de Lógica y Mapeo (Cerebro JS)

### 🚨 Omisión de Propiedades Globales (v110-v113)
* **Problema:** Se perdió el margen del título porque se asumió que el Master lo gestionaría, cuando el silo externo lo requería explícitamente[cite: 2].
* **Impacto:** Desalineación visual de 1px entre el entorno de pruebas (Silo) y producción (Master)[cite: 2].
* **Blindaje:** Protocolo de "Prueba de Carga Dual" obligatoria antes de cada entrega[cite: 2].

### 🚨 Pérdida de Interactividad (Eventos Inline)
* **Problema:** El FAQ y las pestañas del formulario dejaron de funcionar al copiar el código al Master[cite: 2].
* **Causa:** Se omitieron los atributos físicos `onclick` en los elementos inyectados[cite: 2].
* **Blindaje:** El JS del Master DEBE inyectar el atributo `onclick` físicamente en el `innerHTML` o el `map`[cite: 2].

### 🚨 Referencia Indefinida en Directorio (loadDirectorio)
* **Problema:** Error "q is not defined" en consola al buscar en el directorio[cite: 2].
* **Causa:** Una refactorización movió la variable de búsqueda fuera del scope de la función[cite: 2].
* **Blindaje:** Auditoría obligatoria de logs TRACE para asegurar que las variables de filtro se declaren dentro del ámbito de ejecución[cite: 2].

---

## 4. Errores Recientes de Interfaz y Pipeline (Sesión de Auditoría v1.6.0)

### 🚨 Hardcodeo Estructural y Neutralización del Orquestador (Incidencia 01)
* **Problema:** El texto descriptivo del sismo se encontraba hardcodeado directamente en el HTML de `eventovenezuela.html` (`#event-description`) y se neutralizó el orquestador JavaScript comentando la línea de inyección, provocando que el contenido no se visualizara correctamente en el navegador[cite: 2].
* **Hipótesis de Ingeniería (Colisión de Capas):** Se identificó un conflicto visual de texto blanco sobre fondo blanco debido a la carga diferida de la imagen Hero[cite: 2].

### 🚨 Bloqueo Total (White Screen) por Reconfiguración de Módulo (Incidencia 02)
* **Problema:** Al intentar reconfigurar el Módulo 04 para pasar de un diseño de pestañas (vertical) a una fila única horizontal (Estándar $10,000), la página sufrió un bloqueo total (White Screen), exigiendo una reversión inmediata a la versión estable[cite: 2].
* **Hipótesis de Ingeniería (Referencia Fantasma):** Invocación de funciones de pestañas (`switchForm`) previamente eliminadas del HTML que interrumpen abruptamente la ejecución del script maestro[cite: 2].
* **Hipótesis de Ingeniería (Falla de Parser):** Desbalance de llaves `{ }` en la sección Hero del archivo `b5.css` que invalida las reglas críticas de visibilidad[cite: 2].
* **Blindaje Atómico:** Toda modificación de diseño en módulos interactivos debe aislarse bajo el selector atómico correspondiente (`.tpl-b5`) y verificar la integridad de las funciones vinculadas antes del despliegue[cite: 2].

---

## 5. Errores Recientes de Selectores y Breakpoints (Sesión de Refactorización f1 — v1.7.0)

### 🚨 Referencia Fantasma en Selectores CSS (f1, v2.1.0–v2.3.0)
* **Problema:** Tres parches consecutivos de expansión edge-to-edge (`#modulo-lineup`, `#modulo-gallery`, `.media-grid`, `.poster-main-img`, `.spotify-container`) no tuvieron ningún efecto visual pese a estar correctamente escritos en CSS[cite: 2].
* **Causa:** Los selectores asumían una estructura HTML pre-split (una sección "gallery" unificada con video+playlist). El DOM real, desde v1.4.6, usa 3 `<section>` hermanas independientes (`#mod-video`, `#mod-lineup`, `#mod-playlist`) y el póster es `<img id="db-poster-img">`, no `.poster-main-img`[cite: 2].
* **Blindaje:** Antes de escribir un parche CSS de expansión estructural, verificar el HTML real de `evento3.html` (no solo `BLUEPRINT.md`) para confirmar IDs/clases vigentes, especialmente tras un split documentado en el changelog del propio `.css` del silo[cite: 2].

### 🚨 Regla Edge-to-Edge sin Alcance de Breakpoint Rompe Desktop (f1, v2.3.0)
* **Problema:** `.tpl-f1 #mod-lineup > div { max-width:100% !important }` se escribió para liberar el ancho en móvil, pero al no llevar `@media`, también anuló el tope inline de `1100px + margin:0 auto` en escritorio, descentrando visualmente el póster y estirando el grid a todo el ancho de la sección[cite: 2].
* **Causa:** Toda regla de expansión "edge-to-edge" debe declarar explícitamente su alcance de breakpoint. Una regla sin `@media` puede reparar un breakpoint y romper otro de forma silenciosa (sin error en consola, sin white screen, solo desalineación visual difícil de atribuir a simple vista)[cite: 2].
* **Blindaje:** Auditar cada `!important` de ancho/margen añadido a un módulo compartido entre breakpoints, confirmando explícitamente si el fix debe ser universal o exclusivo de un rango de pantalla, y documentarlo en el propio comentario CSS[cite: 2].

---

## 6. Errores de Layout y Asincronía Supabase (Sesión v1.2.5 — Contrato v111)

### 🚨 Colapso Estructural y Parpadeo Visual (CLS) por Carga Asíncrona I/O
* **Problema:** Al cargar datos asíncronos desde Supabase hacia contenedores multimedia (`#mod-video`, `#mod-galeria`), la falta de dimensiones fijas previas en el CSS provocaba un colapso visual momentáneo a `0px` o un salto brusco en la disposición de la página (Cumulative Layout Shift) cuando los datos terminaban de inyectarse.
* **Causa:** Uso de estructuras Flexbox o bloques sin reserva explícita de pistas antes del renderizado asíncrono. En Flexbox, los elementos hijos vacíos reducen su tamaño a cero hasta que el JS inserta el HTML recibido del backend.
* **Blindaje (ADR-014):** Obligatoriedad de implementar **CSS Grid con pistas explícitas (`grid-template-columns: 1fr 1fr`)** en contenedores multimedia e inyectados. El uso de pistas fijas en Grid obliga al navegador a reservar el espacio geométrico exacto desde la carga inicial del DOM, previniendo el colapso visual independientemente del tiempo de respuesta del servidor.

---

## 7. Errores de Coherencia de Breakpoints y Transcripción (Sesión de Auditoría Mobile v5.13.0 — b5)

### 🚨 Brecha entre el Breakpoint de Layout y el Breakpoint de Seguridad de un Mismo Átomo
* **Problema:** `#main-content-flow` colapsa a una columna en `max-width:991px` (ADR-018), pero la regla de seguridad de ancho/margen/box-sizing de `#mod-hero-meta` (la misma que corrigió el desborde en iPhone SE) se había quedado en `max-width:899px`. En la franja de 92px entre ambos valores, el layout ya está apilado a una columna pero `#mod-hero-meta` seguía recibiendo la regla íntegra de escritorio.
* **Causa:** Al subir el breakpoint del grid general en ADR-018, no se auditaron las reglas de seguridad puntuales de sus hijos que dependían implícitamente del mismo punto de quiebre.
* **Blindaje (ADR-019):** Al modificar el breakpoint de un contenedor de layout, listar explícitamente qué reglas de sus hijos asumen ese mismo punto de quiebre y moverlas en conjunto, no solo la regla del propio contenedor.

### 🚨 Comentario Documentando una Decisión que el Código No Implementaba
* **Problema:** `.historia-item--conimg` shippeaba `grid-template-columns: auto 50fr 50fr` (50/50) con un comentario inmediatamente arriba describiendo la proporción como "65% / 35%" — y `DECISIONS.md` (ADR-018) documentando textualmente la misma decisión de 65/35. El código nunca reflejó lo decidido.
* **Causa:** Bug de transcripción silencioso — sin error de consola, sin white screen, solo una proporción visual distinta a la ratificada, indistinguible a simple vista de un ajuste visual intencional posterior no documentado.
* **Blindaje (ADR-019):** Ante cualquier discrepancia entre un comentario/decisión documentada y el valor real shippeado, verificar cuál de los dos es el vigente contra `DECISIONS.md` antes de asumir que el código es la fuente de verdad — el código puede llevar una regresión silenciosa de un valor ya decidido.

---

## 8. Errores de Persistencia de Esquema y Anidación HTML en `admin.html` (Sesión Wizard Inteligente — ADR-021)

### 🚨 Columnas Documentadas en BLUEPRINT.md Nunca Escritas por el INSERT (`template_id`, `categoria_slug`)
* **Problema:** `BLUEPRINT.md` §3 documentaba `template_id` y `categoria_slug` como columnas de la tabla `eventos` desde antes de esta sesión, pero `crearEvento()` → `_crearEventoUnico()` en `admin.html` nunca las incluía en el payload del `INSERT`. El theme elegido en el formulario solo quedaba guardado dentro de `config_landing.theme` (JSON), nunca en columnas propias.
* **Causa:** Mismo patrón que el hallazgo de la Sección 7 (`.historia-item--conimg`, 50/50 vs 65/35 documentado) — un bug de transcripción silencioso, aquí entre `BLUEPRINT.md` y el código de `admin.html` en vez de entre `DECISIONS.md` y un `.css` de silo. Sin error de consola, sin white screen: los eventos se creaban con normalidad, solo que sin esas dos columnas pobladas.
* **Blindaje (ADR-021):** `_crearEventoUnico()` y `_crearSerie()` ahora escriben `template_id`, `categoria_slug` y `captura_pura` (nueva) en cada `INSERT` a `eventos`. Auditoría obligatoria: ante cualquier discrepancia entre lo que `BLUEPRINT.md` documenta como columna existente y lo que un `INSERT` de `admin.html` realmente popula, verificar el código fuente del `INSERT` directamente — no asumir que "está documentado" implica "está shippeado" (mismo principio que ADR-019 ya estableció para CSS, ahora extendido a payloads de Supabase).

### 🚨 `<div>` sin Apertura Antes de "Aforo Máximo" — Anidación Rota Detectable Solo por Parser
* **Problema:** Entre el constructor de campos personalizados y el campo "Aforo máximo" del formulario de creación de eventos, el marcado tenía un `</div>` de cierre (del constructor) seguido inmediatamente por `<label>Aforo máximo</label>` sin ningún `<div>` de apertura — y más abajo, tras el `<span>` de ayuda, un `</div>` adicional sin contraparte real en ese nivel.
* **Causa:** Omisión de un `<div class="fg">` de envoltura al mover o editar este campo en algún momento previo a esta sesión (no queda registro de en qué versión ocurrió). El error es **invisible a la inspección visual normal** del HTML — no genera error de consola ni white screen, solo un desbalance que un parser HTML5 real resuelve buscando el `<div>` abierto más cercano en toda la pila de elementos, potencialmente cerrando de forma prematura un contenedor ancestro no relacionado (en este caso, verificado con un parser real: el desbalance se propaga hasta manifestarse como un cierre sin apertura en ningún punto del árbol, más adelante en el mismo archivo).
* **Blindaje (ADR-021):** El campo "Aforo máximo" se envolvió correctamente en su propio `<div class="fg">`. Verificación aplicada (y recomendada para futuras sesiones sobre `admin.html`): correr un parser HTML5 con pila de elementos (ignorando void elements: `input`, `br`, `img`, etc.) sobre el archivo completo antes y después de cualquier cambio estructural grande — la inspección visual de un archivo de miles de líneas no es suficiente para detectar este tipo de desbalance, pero un parser lo confirma en segundos y con precisión de línea/columna.

---

## 9. Selector Posicional Roto por Reestructuración de Pestañas (Sesión ADR-022 — Reorganización de Admin)

### 🚨 `#pg-admin > .wrap > .card` Dejó de Coincidir Tras Envolver la Card en un Tab
* **Problema:** `aplicarRestriccionesAdminEvento()` ocultaba la card "Nuevo evento" para el rol `admin_evento` usando el selector posicional `#pg-admin > .wrap > .card` (primer hijo directo `.card` de `.wrap`). Al reorganizar Admin en pestañas (ADR-022), esa card se envolvió en `<div data-adm-tab="crear">` — pasó de ser **hija directa** de `.wrap` a **nieta**. El selector, al depender de la posición exacta en el árbol y no de un identificador propio, dejó de coincidir silenciosamente: sin error de consola, sin white screen, el Wizard de creación simplemente habría quedado visible/accesible para un rol que no debería poder crear eventos.
* **Causa:** Mismo patrón de raíz que ADR-007 (contenedores flex que colapsan por depender de comportamiento posicional/estructural implícito) y ADR-010 (padding dependiente de la posición del bloque anterior) — código que depende de "dónde vive" un elemento en el árbol en vez de "qué es" (un ID o atributo propio), frágil ante cualquier refactor estructural futuro, incluso uno que no toca esa card directamente.
* **Blindaje (ADR-022):** Se corrigió el selector para apuntar por atributo (`[data-adm-pill="crear"]` / `[data-adm-tab="crear"]`) en vez de por posición. Auditoría recomendada para futuras sesiones: antes de envolver o reordenar HTML existente (incluso con el patrón de envoltura in-situ ya establecido en ADR-021/022), buscar en todo el archivo selectores `querySelector`/`querySelectorAll` que referencien esa región por posición (`>`, `:nth-child`, `:first-child`) en vez de por ID/atributo — son los que se rompen silenciosamente ante una reestructuración, mientras que los selectores por ID sobreviven sin cambios.

---

## 10. Selector CSS de Atributo Incompleto al Reutilizar un Patrón con Namespace Distinto (Sesión ADR-023 — Reorganización de Panel)

### 🚨 `[data-adm-tab]{display:none}` No Cubría el Nuevo Atributo `data-pnl-tab`
* **Problema:** ADR-022 introdujo el patrón de pestañas ocultas-por-defecto vía CSS de atributo: `[data-adm-tab]{display:none}` + `.adm-visible{display:block}`. Al reutilizar el mismo patrón para Panel (ADR-023) con un namespace de atributo deliberadamente distinto (`data-pnl-tab`, para que Admin y Panel no interfirieran entre sí en el mismo DOM — ver ADR-023 punto 4), la regla CSS original no se amplió junto con el HTML/JS: seguía comprobando únicamente la presencia de `data-adm-tab`. Las 4 pestañas de Panel habrían quedado **todas visibles simultáneamente** — ninguna regla CSS las ocultaba — anulando visualmente el propósito completo de la reestructuración, pese a que el HTML (envoltura correcta) y el JS (`pnlGoTab()` alternando la clase `.adm-visible` correctamente) estaban ambos bien escritos.
* **Causa:** Reutilizar un nombre de clase de estado (`.adm-visible`) sin revisar que el selector de atributo que lo acompaña siga cubriendo el atributo nuevo. El bug es invisible en una revisión de HTML o de JS por separado — ambos están "correctos" en aislamiento; solo se manifiesta al verificar el comportamiento visual conjunto (o, como en este caso, al releer la regla CSS que los conecta antes de dar por cerrada la entrega).
* **Blindaje (ADR-023):** Corregido a `[data-adm-tab],[data-pnl-tab]{display:none}` con su contraparte `.adm-visible` ampliada igual. Auditoría recomendada para futuras sesiones: cuando un patrón de "namespace de atributo + clase de estado compartida" se reutiliza para una segunda página/módulo, grepear explícitamente el selector CSS que depende del nombre del atributo (no solo el nombre de la clase) para confirmar que cubre todos los namespaces en uso, no solo el original.

---

## 11. Métodos de String sin Blindar Sobre Campos de Supabase Potencialmente Nulos (Sesión ADR-024 — Fix "Null Pointer Regression")

### 🚨 `.replace()` sin Protección en `inscritos.nombre` / `inscritos.evento_nombre` — Bloqueo Total del Panel
* **Problema:** `_renderTablaPagina()` armaba los `onclick` de los botones de check-in/reversión/eliminación de cada fila con `i.nombre.replace(/'/g,...)` e `i.evento_nombre.replace(/'/g,...)`, sin verificar antes que esos campos no fueran `null`. Para la organización "Barrio R10" (con registros de `inscritos` incompletos), esto producía `TypeError: Cannot read properties of null (reading 'replace')` y **bloqueaba el panel completo** — no un módulo aislado: al tronar dentro de un `.map()` que construye el `innerHTML` de toda la tabla, ninguna fila llegaba a renderizarse, para ninguna organización con al menos un registro incompleto.
* **Causa:** Bug preexistente, no introducido por la reestructuración de pestañas de ADR-023 (que no tocó esta función). El principio de Silent Fallback (ADR-008) estaba definido en el proyecto para `<img onerror>` desde `Reglas_de_Oro_QR.md`, pero no se había extendido explícitamente a métodos de `String.prototype` (`.replace`, `.split`, `.trim`, `.toUpperCase`, `.localeCompare`, etc.) sobre campos que Supabase puede legítimamente devolver en `null` — y la tabla `inscritos` en particular tiene por diseño numerosas columnas nullable (ver `BLUEPRINT.md` §"Esquema `inscritos`": 15 columnas de Fase 2 de `b5`, solo 3 se completan según la categoría elegida).
* **Blindaje (ADR-024):** Patrón `(campo||'').metodo(...)` aplicado en `_renderTablaPagina()` y, preventivamente, en el bloque `evStats` de `renderPanel()` (`ev.fecha`/`ev.nombre`/`a.fecha.localeCompare(b.fecha)`, sin reporte previo de fallo pero con el mismo riesgo estructural). Auditoría recomendada para futuras sesiones sobre `admin.html`: cuando una función interpola un campo de Supabase dentro de una llamada a un método de string (no solo `.replace()` — también `.split()`, `.trim()`, `.toUpperCase()`, `.toLowerCase()`, `.localeCompare()`, `.substr()`, `.charAt()`, `.slice()` sobre el valor en sí, o `.length` sobre un valor que podría no ser string), verificar si ese campo puede ser `null` en el esquema real antes de asumir que la comprobación visual o el uso previo sin fallos garantiza que siempre vendrá poblado — un campo puede estar poblado en todas las organizaciones de prueba y ser `null` en una real, como ocurrió aquí.

## 12. Identidad de System Admin Acoplada a un Slug de Cliente Real y Desface Cosmético de Estado por Defecto (Sesión ADR-025 — Separación Master Admin / Barrio R10)

### 🚨 `slug === 'hostal-terraza'` como Único Criterio de Acceso a System Admin — Cliente Real Operando Como Operador del SaaS
* **Problema:** La organización "Barrio R10" (cliente real, con eventos e inscritos propios) operaba simultáneamente como identidad de System Admin global del SaaS, porque `_IS_SYSTEM_ADMIN()` y `applyRoleNav()` comparaban `_orgData.slug === 'hostal-terraza'` — el slug de Barrio R10 — como único criterio. Auditoría contra la exportación real de `pg_policies` (no contra suposición) confirmó que el mismo string estaba además hardcodeado en las políticas RLS `insert_organizaciones`/`delete_organizaciones` de Postgres, no solo en el frontend.
* **Causa:** Decisión de diseño temprana — probablemente la primera organización creada durante el desarrollo se usó también como cuenta de administración del SaaS, y esa conveniencia inicial nunca se separó a medida que el sistema pasó a producción con clientes reales.
* **Hallazgo colateral durante la misma auditoría (no corregido en esta sesión, ver TSK-026):** varias tablas (`eventos`, `clientes`, `perfiles`) conservan políticas RLS permisivas legacy (`auth.role()='authenticated'` o directamente `true`, sin chequeo de `org_id`) que **conviven** — se combinan con OR, no se reemplazan — con las políticas correctas `org_id = get_org_id()` añadidas después. El aislamiento multi-tenant no está garantizado en la práctica para esas tablas hasta que se retiren. Lección: cuando se migra un modelo de permisos a una nueva política más estricta, verificar explícitamente que las políticas anteriores fueron retiradas — Postgres RLS combina políticas permisivas con OR, así que una política vieja y abierta sigue activa aunque exista una nueva y correcta.
* **Blindaje (ADR-025):** columna `organizaciones.is_master_org boolean` reemplaza la comparación de slug como fuente de verdad, tanto en el frontend (`admin.html`) como en las 2 políticas RLS reales que dependían del string. Ver `DECISIONS.md` ADR-025 para el runbook completo y el detalle tabla-por-tabla de TSK-026.

### 🚨 Botón de Período del Panel Marcado "Activo" en el HTML no Coincidía con el Valor por Defecto Real de `_pnPeriod`
* **Problema:** El markup estático del selector de período del Panel tenía la clase `on` en el botón "7d", pero la variable `let _pnPeriod = '30d'` (línea ~5580) es la que realmente determina el filtro aplicado en la primera carga. No hay una regla CSS `.pn-period.on` — el estado visual "activo" solo se pinta vía estilos inline que aplica `setPanelPeriod()` al hacer clic — así que la inconsistencia no se veía como un bug visual, pero el atributo quedaba en un estado que no reflejaba la realidad del código, y un cambio futuro que sí agregue esa regla CSS haría visible el desface.
* **Causa:** Detectado durante el diagnóstico de un reporte de Dirección ("el panel no muestra los datos de Barrio R10") que en realidad era el comportamiento esperado del filtro de 30 días por defecto ocultando inscritos con más de un mes de antigüedad — no relacionado con ADR-025, pero encontrado en el mismo flujo de revisión de `renderPanel()`.
* **Blindaje:** el botón marcado `on` en el HTML estático se movió de "7d" a "30d" para que coincida con el valor real de `_pnPeriod`. Es una corrección de consistencia semántica, no un cambio de comportamiento — el filtro por defecto sigue siendo 30 días, ahora el markup no miente sobre cuál es.

---
*Este documento constituye la memoria técnica inamovible para asegurar la fidelidad de 1px en el Sistema QR Hostal Terraza (Actualizado v1.14.0-STABLE, ADR-025).*