# 🧬 BLUEPRINT.md — Arquitectura Técnica y Modelo de Datos (v1.6.2 — Contrato v112)

Este documento constituye la **Única Fuente de Verdad** técnica del Sistema QR Hostal Terraza. Ninguna modificación estructural ni de esquema puede realizarse sin el Decision Protocol y la validación del Chief Architect.

---

## Información de Estado
* **Versión:** v1.6.1 (Contrato v112 — sin cambios en los 21 Átomos Soberanos; ADR-021 corrige la persistencia de `template_id`/`categoria_slug` y añade `captura_pura` en `eventos` desde `admin.html`. Ver ADR-020 para la corrección de cascada en galería y blindaje del SVG de mapa en el silo `b5`)
* **Estado:** Producción
* **Silos Activos:** `f1` (Fiesta / General / Selina Style), `b5` (Venezuela / Emergencia Crítica)
* **⚠️ Verificación pendiente (ADR-021 / TSK-017):** Este documento declara `evento3.html` como "El Cerebro" (§1), pero el link público generado por `admin.html` tras crear un evento apunta a `evento.html`. No se pudo confirmar en esta sesión si `evento.html` es un alias/redirect de `evento3.html`, un remanente pre-migración, o un motor distinto — mientras no se confirme, no hay garantía de que `template_id`/`categoria_slug` (recién persistidos por el Wizard, ver ADR-021) tengan efecto visual en la página pública enlazada. Ver `ERRORES_HISTORICOS.md` §8.

---

## 1. Arquitectura Frontend: Cerebro Único y Múltiples Caras
El sistema opera bajo un modelo de orquestación centralizada en **Vanilla JS** (JavaScript puro) con capas de presentación (CSS) totalmente aisladas, garantizando carga instantánea y portabilidad absoluta.

### 📂 Estándar de Filesystem (Silos Atómicos y Convención de Rutas)
Para evitar colisiones de estilos y permitir escalabilidad masiva, los activos se organizan por categoría física bajo la convención de rutas estandarizada:
* **Ruta Maestra de Estilos:** `css/templates/{categoria_slug}/{template_id}.css`
* **Convención de Casing:** El `template_id` y el nombre del archivo deben estar estrictamente en **minúsculas** (ej: `f1.css`, `b5.css`) para compatibilidad con servidores Linux.
* **Referencias Certificadas:** `css/templates/fiesta/f1.css` (Selina Style) y `css/templates/campana/b5.css` (Emergencia Crítica).

### 🛠️ Componentes y Archivos Core
| Archivo | Rol Objetivo | Responsabilidad Operativa |
| :--- | :--- | :--- |
| `admin.html` | System Admin | Gestión multi-tenant, Panel SaaS, análisis de módulos y configuración de `video_url`. |
| `evento3.html` | Motor Público | **El Cerebro:** Orquestador JS que mapea los átomos soberanos y aplica el Scope CSS según el `template_id`. |
| `scanner.html` | Puerta / Staff | Escáner QR en tiempo real con cola de sincronización offline en `localStorage`. |
| `registro.html` | Onboarding | Flujo de registro SaaS de 3 pasos e integración de pasarela Wompi y lógica Dual-Phase. |
| `qr.html` | Marketing | Redirect tracker con captura de metadata (Geo, IP, Dispositivo). |

---

## 2. Estándar Layout & Grid v2.0
Para garantizar la estabilidad estructural antes de la desincronización I/O de la base de datos Supabase, se actualiza el estándar de maquetación del Kernel CSS (Refuerzo de ADR-007 y ADR-013):

* **Sustitución de Flexbox por CSS Grid:** Se elimina la dependencia de Flexbox en contenedores de medios inyectados (ej. `#mod-video`, `#mod-galeria`).
* **Pistas Fijas de Grid (`1fr 1fr`):** Todos los módulos de Grid inyectados deben implementarse con pistas explícitas para prevenir el colapso visual a `0px` de alto/ancho durante la fase de carga asíncrona de datos desde Supabase.

---

## 3. Modelo de Datos: Fuente de Verdad (Supabase)
Backend centralizado con **Row Level Security (RLS)** para garantizar que ninguna organización acceda a datos de otra mediante el filtro obligatorio `org_id`.
* **⚠️ Nota de auditoría (ADR-025):** confirmado contra la exportación real de `pg_policies` que esto es cierto para `eventos`, `series`, `inscritos`, `invitadores`, `clientes`, `logs`, `scanner_tokens`, `qr_links` vía las políticas `*_org` (`org_id = get_org_id()`). Sin embargo, varias de esas tablas conservan además políticas legacy permisivas (`auth.role()='authenticated'` o `true`, sin chequeo de `org_id`) que **no fueron retiradas** al migrar a las políticas `_org` y se combinan con ellas (OR, no reemplazo) — el aislamiento por `org_id` no está garantizado en la práctica hasta que se resuelva TSK-026. Ver `DECISIONS.md` ADR-025 para el detalle tabla por tabla.

### 🗄️ Esquema de Tabla `organizaciones`
* **Columna `is_master_org` (boolean, default `false`, ADR-025):** reemplaza la comparación de `slug === 'hostal-terraza'` como fuente de verdad de "es el operador del SaaS" (System Admin global). Solo la organización maestra (cáscara sin eventos propios, `slug: master-admin`) debe tener este flag en `true`. Gatea `_IS_SYSTEM_ADMIN()` y `applyRoleNav()` en `admin.html`, y las políticas RLS `insert_organizaciones`/`delete_organizaciones`.
* **`slug`:** identificador único de la organización, editable, sin efecto en URLs públicas de eventos — `evento.html`/`serie.html` enlazan por `eventos.slug`/`series.slug` (el slug del evento o la serie), no por `organizaciones.slug`. Renombrar el slug de una organización es seguro para links ya distribuidos a asistentes.

### 🗄️ Esquema de Tabla `eventos` e `inscritos` (Normalizada)
* **Tabla `eventos`:** Incluye `id`, `video_url` (fuente primaria plana), `template_id`, `categoria_slug`, `captura_pura` (boolean, ADR-021 — evento sin generación de QR tras el registro) y `config_landing` (jsonb para metadatos extendidos).
  * **Fix ADR-021:** Hasta v1.6.0, `template_id` y `categoria_slug` estaban documentados aquí pero el `INSERT` de `admin.html` (`crearEvento()`) nunca los escribía — el theme elegido solo quedaba dentro de `config_landing.theme` (JSON). El Wizard de creación (ADR-021) corrige esto y además persiste `captura_pura`. Requiere ejecutar `migrations/adr021_eventos_columns.sql` (idempotente, `ADD COLUMN IF NOT EXISTS`) contra Supabase antes de asumir que las columnas existen en todas las instancias.
* **Tabla `inscritos` (Actualizada b5, Contrato v112):** Contiene columnas críticas para operaciones de emergencia y campañas: `whatsapp` (text), `tipo_ayuda` (text — valores: `espacio`, `artista`, `marca`, `voluntario`, `donacion`), `cedula` (text), `email` (text), `autorizacion` (boolean/text). **15 columnas dedicadas nuevas** (una por pregunta especializada de Fase 2, ver `migracion_v112_inscritos.sql`): `espacio_direccion`, `espacio_aforo`, `espacio_tiene_sonido`; `artista_portafolio`, `artista_especialidad`, `artista_requerimiento_tecnico`; `marca_tipo_apoyo`, `marca_tiene_logo`, `marca_cargo`; `voluntario_profesion`, `voluntario_disponibilidad`, `voluntario_experiencia_rescate`; `donacion_monto_proyectado`, `donacion_canal_preferido`, `donacion_desea_certificado`. Solo se completan las 3 correspondientes a la categoría elegida por cada inscrito; el resto queda `NULL`.
* **Contenedor JSONB (`respuestas_custom`):** Utilizado como el repositorio aditivo y flexible para almacenar los datos dinámicos generados durante la **Fase 2 del registro**.

---

## 4. Contrato de Datos v111: Los 21 Átomos Soberanos Protegidos
Para garantizar la integridad del orquestador, ningún template puede eliminar estos IDs del DOM. Si no se desean mostrar, usar `display: none`.

1. `#event-title`: Título del evento (Tipografía Geist 900).
2. `#event-description`: Descripción extendida / narrativa general del evento.
3. `#meta-fecha`: Fecha formateada del evento.
4. `#meta-hora`: Hora de inicio / apertura del evento.
5. `#meta-lugar`: Ubicación / Recinto principal.
6. `#mod-video` (`#db-video-content`): Target de inyección para miniaturas HD de YouTube/Vimeo (ADR-005).
7. `#mod-galeria` (`#db-gallery-grid`): Grid dinámico de imágenes del evento.
8. `#mod-lineup` (`#db-lineup`): Grid dinámico de artistas/talentos invitados con fotos y metadatos.
9. `#mod-patrocinadores` (`#db-sponsors-list`): Grid de patrocinadores (con preservación de SVGs).
10. `#mod-entradas` (`#mod-form` / `#db-ticket-target`): Contenedor de pasarela, tickets o pase digital con QR dinámico.
11. `#mod-faqs` (`#db-faq-list`): Lista expandible de preguntas frecuentes (con atributo `onclick` inyectado).
12. `#mod-ubicacion`: Módulo de mapa estático/interactivo y geolocalización.
13. `#mod-contacto`: Canales directos de atención y soporte.
14. `#mod-reglas`: Normativa, términos y políticas del evento/recinto.
15. `#mod-itinerario`: Cronograma / agenda detallada del evento.
16. `#mod-redes`: Enlaces e íconos de perfiles sociales oficiales.
17. `#mod-comentarios`: Módulo/feed interactivo de comentarios de asistentes.
18. `#mod-encuesta`: Módulo de recolección de feedback / preguntas personalizadas.
19. `#mod-descargas`: Área de recursos y documentos descargables.
20. `#mod-sponsors-vip`: Bloque preferencial para patrocinadores primarios/VIP.
21. `#mod-actualizaciones` *(Nuevo en v111, ADR-013; contrato de campos actualizado en v112, ADR-015)*: Diario de impacto / carrusel dinámico de noticias e hitos, inyectado desde `config_landing.content.actualizaciones`. Contrato de cada entrada: `{categoria, fecha, titulo, resumen, imagen}` (`categoria` e `imagen` opcionales). Componente genérico y reutilizable por cualquier categoría. Target de inyección: `#db-actualizaciones-grid`.

### 4b. Extensiones Aditivas y Componentes Adicionales
Estructuras y componentes aditivos habilitados bajo la Flexibilización de Protocolos de Paridad Visual:
* `#org-name-badge`: Badge de identidad de la organización promotora.
* `#unified-frame`: Contenedor maestro del Countdown (Heartbeat activo).
* `#db-spotify-embed`: Playlist sincronizada (Sync 1:1 con altura del video).
* `#meta-magnitud`: Metadatos sísmicos / métricas numéricas de impacto.
* `#mod-mapa-crisis`: Visualización interactiva/animada de zonas y mapas operativos.
* `#mod-como-ayudar`: Módulo interactivo de segmentación de roles, tipos de ayuda y voluntariado. 5 categorías vigentes desde el Contrato v112 (ADR-015): `espacio`, `artista`, `marca`, `voluntario`, `donacion`.
* `#mod-impacto-historico`: Módulo de métricas institucionales, balance de ayuda y resultados.
* `#mod-countdown`: Nodo autónomo de tiempo restante.
* `#mod-audio-player`: Reproductor embebido de sintonía/manifiesto.
* `#mod-ticker-noticias`: Barra superior deslizante para alertas críticas en tiempo real.
* `#mod-footer-brand`: Bloque de cierre institucional, gobernanza y autoría.
* `#db-historia-lista` (dentro de `#mod-historia`): Lista de hitos narrativos numerados alimentada por `content.historia_items`.
* `#db-mapa-crisis-resumen` (dentro de `#mod-impacto-humanitario`, renombrado en ADR-016; antes `#mod-impacto`): Párrafo resumen del evento/sismo junto al enlace `#db-mapa-crisis-link`.
* `.gallery-lightbox` / `#gallery-lightbox-root` *(Nuevo en ADR-016)*: Modal de visualización ampliada para `#db-gallery-grid`, inyectado una sola vez en `<body>` por JS, reutilizando el mismo lenguaje visual que `.actualizacion-modal`.
* `.b5-num-eyebrow[data-num]`: Componente de insignia numerada (02…09) que unifica la cabecera de secciones numeradas.
* `content.contacto` *(consumido desde ADR-017)*: `{dir, tel, email}`. Campo del Contrato de Datos ya existente en el JSON de eventos pero sin consumidor en el código hasta ADR-017, que lo usa para poblar `.ubicacion-contacto` dentro de `#mod-ubicacion` (reemplazo del iframe de mapa, Opción B de Dirección). Silent Fallback: solo se renderizan las filas con dato no vacío; si `dir` viene vacío se usa `ev.ubicacion` como respaldo.

---

## 5. Protocolo de Conversión Dual-Phase (Estándar de Alta Conversión)
Implementado en plantillas de alta fricción o emergencia (ej. `eventovenezuela.html` / `b5`):
* **Fase 1 (INSERT):** Captura inicial de datos mínimos esenciales para generar el registro primario en Supabase de forma instantánea.
* **Fase 2 (UPDATE In-Place):** Perfilamiento dinámico sobre el mismo registro existente mediante actualizaciones asíncronas (`UPDATE`), eliminando por completo la necesidad de recargas de página y maximizando la tasa de conversión.
* **Ramificación de 5 rutas (Contrato v112, ADR-015):** Fase 2 revela un bloque de preguntas distinto según el `tipo_ayuda` elegido en Fase 1 (`espacio`, `artista`, `marca`, `voluntario`, `donacion`), controlado por `mostrarBloqueFase2()`. Cero Borrado: los 5 bloques residen siempre en el DOM; solo se alterna su `display`.

---

## 6. Reglas de Blindaje de Calidad (QA GOLD)

### 🏗️ Lógica de Diagramación y Layout
* **Grid Atómico v1.4.0:** Se prohíbe el uso de `position: fixed` para el orden de módulos. La ubicación se gestiona vía `grid-template-areas`.
* **Geometría Split-Screen:** En escritorio (>=1024px), el Hero/Form se anclan a la izquierda (38vw) y el contenido fluye a la derecha (62vw).
* **Grid sobre Flex (v2.0 / ADR-013):** Módulos multimedia inyectados (`#mod-video`, `#mod-galeria`) deben maquetarse con CSS Grid de pistas explícitas (`1fr 1fr`) para prevenir colapsos a 0px.
* **Aisleamiento CSS (Scoped):** Todo selector DEBE empezar con el prefijo `.tpl-{id}` (ej: `.tpl-f1 #mod-hero`, `.tpl-b5 #mod-mapa-crisis`).

### 🛡️ Salvaguarda de Activos y Media
* **YouTube Protocol (ADR-005):** Prohibido el uso de `<iframe>` para YouTube. Extraer ID y generar miniatura HD con link externo para evitar el **Error 153** en móviles.
* **Silent Fallback de Imágenes (ADR-008):** Todo `<img>` generado dinámicamente debe incluir el atributo `onerror="this.src='path/to/fallback.png';"` para conmutar al activo por defecto si falla Supabase.
* **Preservación de SVGs:** Prohibido usar fuentes de iconos externas; usar etiquetas `<svg>` íntegras para mantener transparencia real y efectos Afterglow.
* **Integración de Proximidad (ADR-010):** El módulo de video debe declararse con `padding-top: 0 !important` en el silo CSS para eliminar respiros visuales con el countdown.
* **Silent Fallback en `background-image` (ADR-016):** Dado que la propiedad CSS `background` no tiene equivalente al atributo `onerror` de `<img>`, todo uso de una URL externa como fondo debe declararse como la *primera capa* de un `background` multi-capa, conservando un patrón CSS generado (gradientes) como capa inferior. Si la imagen externa falla, esa capa simplemente no pinta y el patrón de respaldo queda visible, evitando un contenedor en blanco sin depender de JS.
* **Fuente Única por Selector (ADR-017):** Prohibido declarar la misma regla (mismo selector + `!important`) más de una vez en el mismo archivo. Dos reglas idénticas en especificidad se resuelven por orden de aparición de forma silenciosa (sin error en consola), lo que hizo que un intento de ajuste de `margin-top` en `#mod-hero-meta` no tuviera efecto real durante una sesión completa. Si una regla debe quedar obsoleta, se **comenta** con nota explicando por qué (Cero Borrado), nunca se deja una segunda declaración compitiendo en silencio.
* **Normalización de Esquemas Legados (ADR-016, ADR-017):** Todo campo `content.*` que alimente un render dinámico debe tolerar el esquema histórico más antiguo con el que se haya guardado un evento, no solo el esquema vigente documentado aquí. Patrón establecido: `normalizeImpactoLegacy()` (ADR-016, string `{label:"A | B | C"}` → objeto) y `normalizeActualizacionesLegacy()` (ADR-017, string pipe-delimited → objeto), ambas defensivas y sin requerir regrabar datos históricos desde `admin.html`.
* **Proporciones Independientes por Fila en Grid Compartido (ADR-018):** `#main-content-flow` es un único contenedor Grid; todas sus filas comparten literalmente las mismas pistas de `grid-template-columns`. Cuando distintas filas de dos átomos necesitan ratios visuales *distintos* entre sí (ej. mapa/datos a 60/40 pero historia/imagen a 65/35), **no puede lograrse cambiando `grid-template-columns` una sola vez** — eso aplicaría el mismo ratio a todas las filas por igual. Patrón establecido: subir la resolución del grid a un número de columnas igual al mínimo común múltiplo de las proporciones necesarias (ADR-018 usa 20, mcm de 60/40, 65/35 y 50/50) y expresar cada fila en `grid-template-areas` repitiendo el nombre del área tantas veces como columnas le correspondan. 100% CSS, cero cambios de HTML — respeta la Invariabilidad del Cerebro y la Regla de Oro #10 (diagramación exclusivamente vía `grid-template-areas`).
* **Cascada Duplicada en Media Queries (ADR-018):** Una regla `!important` fuera de un `@media` siempre le gana a una regla sin `!important` dentro de un `@media`, sin importar cuál aparezca después en el archivo — los media queries NO aumentan especificidad. Toda propiedad que un breakpoint necesite sobrescribir debe declarar su propio `!important` si la regla base también lo usa (hallazgo real: el `margin-top` mobile de `#mod-hero-meta` nunca se aplicó por esta razón hasta ADR-018).
* **Coherencia de Breakpoints entre Reglas del Mismo Átomo (ADR-019):** Cuando un átomo tiene tanto una regla de layout general (ej. el colapso de `#main-content-flow` a una columna en `max-width:991px`) como una regla de seguridad puntual sobre uno de sus hijos (ej. el ancho/margen seguro de `#mod-hero-meta`), ambas deben compartir el mismo breakpoint. Un desajuste entre ellas (hallazgo real: la regla de seguridad de `#mod-hero-meta` seguía en `899px` mientras el grid ya colapsaba en `991px`) deja una franja intermedia donde el hijo sigue recibiendo la regla de escritorio dentro de un layout que ya es mobile. Al modificar el breakpoint de una regla de layout general, auditar todas las reglas de seguridad puntuales que dependan del mismo punto de quiebre.
* **Capa Intermedia de Tablet, 992px-1279px (ADR-019):** El grid de escritorio de b5 (20 columnas, valores fijos como `width:60vw`/`margin:-10rem` en `#mod-hero-meta`) está pensado para viewports >=1400px. Sin una capa intermedia, cualquier ancho entre el colapso a una columna (`991px`) y el escritorio real recibe esos mismos valores fijos sin escalar — el caso real detectado son laptops pequeños e iPads en landscape (1024px-1366px). Patrón establecido: un `@media (min-width:992px) and (max-width:1279px)` dedicado que reduce (no elimina) los valores fijos de escritorio. Sin una referencia visual de tablet disponible, los valores de esta capa se documentan explícitamente como punto de partida sujeto a ajuste iterativo, igual que el `margin:-10rem` de escritorio en ADR-017/018 — no se presentan como definitivos sin Prueba de Carga Dual.
* **Blindaje de Caja — `box-sizing: border-box` a nivel de silo (ADR-019):** Ningún selector de `b5.css` fijaba `box-sizing`, y el kernel tampoco trae un reset global. Bajo `content-box` (default del navegador), un átomo con ancho fijo + padding propio suma el padding por encima de ese ancho — la misma causa raíz que motivó el parche puntual de `#mod-hero-meta` en ADR-018, y que un audit posterior encontró latente también en `.reg-phone-row select` (columna de 100px desbordada ~35px por su propio padding, oculta por el `overflow-x:hidden` del kernel). Patrón establecido: `.tpl-b5, .tpl-b5 *, .tpl-b5 *::before, .tpl-b5 *::after { box-sizing: border-box; }` de baja especificidad y sin `!important` al inicio del silo, para que cualquier override puntual explícito (como el de `#mod-hero-meta` en mobile) lo siga ganando sin conflicto. Efecto secundario esperado y documentado: el ancho total de átomos de escritorio ya certificados que combinan ancho fijo + padding (ej. `#mod-hero-meta`, `width:60vw`) se ajusta a coincidir exactamente con el ancho declarado en vez de superarlo — requiere una pasada de verificación visual (Prueba de Carga Dual) antes de considerarse cerrado.
* **Regla Universal Posterior Anula Media Query Anterior del Mismo Selector (ADR-020):** Un `@media` no aumenta especificidad — solo agrega una condición de coincidencia. Si una regla **sin** `@media` declara el mismo selector con igual especificidad (ej. mismo ID + `!important`) y aparece **después** en el archivo que un override de breakpoint ya existente, la regla universal gana en todos los anchos, incluidos los que el breakpoint pretendía cubrir — apagando el override responsivo en silencio, sin error de consola. Hallazgo real: `#db-gallery-grid` (bloque "Intervención Atómica", ADR-016) forzaba 4 columnas sin `@media` después del override mobile de 2 columnas de la Sección 16, anulándolo a cualquier ancho. Patrón establecido: todo parche añadido al final de un archivo de silo debe auditarse contra los overrides responsivos ya existentes del mismo selector antes de integrarse; si necesita aplicar solo a un rango de pantalla, debe declarar su propio `@media` en vez de depender del orden de aparición.

---
*Documento actualizado y sellado bajo el estándar de calidad de $10,000. v1.6.1 — Contrato v112 (ADR-021).*