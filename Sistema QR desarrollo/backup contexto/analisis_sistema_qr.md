# SISTEMA QR — Hostal Terraza

*Análisis Completo del Sistema · Estrategia de Crecimiento · Monetización*

Bogotá, Colombia · Mayo 2026 · **Actualizado: Agosto 2026 (ver Sección 10)**

---

## 1. Descripción General del Sistema

El Sistema QR de Hostal Terraza es una plataforma web completa que digitaliza todo el ciclo de vida de los eventos del hostal: desde la inscripción pública de los asistentes hasta el control de acceso en la puerta con verificación QR en tiempo real. El sistema funciona completamente en el navegador, sin aplicación nativa, y opera incluso sin conexión a internet.

Desarrollado con HTML, CSS y JavaScript puro — sin frameworks — conectado a Supabase como base de datos en la nube y desplegado en Vercel para distribución global. Esta elección tecnológica lo hace extremadamente portable: cualquier cambio se refleja instantáneamente en todos los dispositivos sin necesidad de instalar ni actualizar nada.

### 1.1 Propósito y Alcance

El sistema surge de una necesidad concreta: digitalizar la operación de eventos de un hostal boutique en Bogotá que históricamente dependía de listas en papel, Excel desactualizados y control de acceso manual. El resultado es un sistema que cubre:

- Registro público de asistentes con ticket QR personalizado
- Control de acceso en puerta con verificación en tiempo real
- Panel administrativo completo con análisis de datos
- Sistema de invitadores con tracking de efectividad
- Gestión multi-organización (arquitectura SaaS)
- Branding personalizable por organización

### 1.2 Datos del Sistema

| **Métrica** | **Valor** |
|---|---|
| Líneas de código totales | ~16.889 líneas *(actualizado agosto 2026 — ver nota)* |
| Archivos principales | 6 archivos HTML |
| Tablas en Supabase | 12 tablas |
| Funcionalidades implementadas | 35+ features |
| Organizaciones soportadas | Ilimitadas (multi-tenant) |
| Dispositivos compatibles | iOS, Android, Desktop |
| Modo offline | Scanner con cola de sincronización |
| Estado | Producción activa |

> *Nota (agosto 2026): la cifra de líneas de código se recalculó directamente sobre los 6 archivos principales (`admin.html` 7.973 · `evento.html` 6.072 · `serie.html` 1.021 · `scanner.html` 1.016 · `registro.html` 691 · `qr.html` 116). La cifra de mayo (~11.625) quedó desactualizada por el crecimiento de `admin.html` durante ADR-021 a ADR-025 (Wizard, navegación en pestañas, fixes).*

## 2. Arquitectura del Sistema

### 2.1 Stack Tecnológico

La decisión de usar HTML/CSS/JS puro fue deliberada y tiene ventajas concretas para este contexto:

- Sin dependencias de build tools — cualquier cambio se sube directamente
- Sin node_modules — el archivo es el producto, no un repositorio
- Depuración directa en DevTools sin sourcemaps
- Hosting gratuito en Vercel — sin costos de servidor
- Supabase como BaaS — autenticación, BD PostgreSQL, Edge Functions y Storage en un solo servicio

### 2.2 Componentes del Sistema

| **Archivo** | **Rol** | **Usuario** |
|---|---|---|
| admin.html | Panel administrativo + Panel Sistema multi-tenant | Administradores |
| evento.html | Formulario de registro público por evento | Asistentes (público) |
| serie.html | Formulario de registro por serie/sesiones | Asistentes (público) |
| scanner.html | Scanner QR con modo offline | Porteros |
| registro.html | Onboarding self-service nuevas organizaciones | Nuevos clientes SaaS |
| qr.html | Redirect tracker con captura de datos | Campañas de marketing |

### 2.3 Modelo Multi-tenant

El sistema soporta múltiples organizaciones sobre una misma instancia de Supabase usando Row Level Security (RLS). Cada tabla tiene una columna `org_id` que identifica a qué organización pertenece cada registro.

> **Actualizado (ADR-025, agosto 2026):** el operador del SaaS ya no se identifica por el slug de una organización cliente. La columna `organizaciones.is_master_org boolean` marca explícitamente a la organización maestra (una cáscara de supervisión sin eventos propios); esa organización obtiene acceso al Panel de Sistema y puede operar como cualquier cliente vía `entrarComoOrg()`. La organización que antes cumplía ambos roles a la vez ("Barrio R10", slug `hostal-terraza`) ahora es un cliente regular, indistinguible en el modelo de datos de cualquier otro. Ver Sección 10.
>
> **Precisión importante sobre el aislamiento RLS (agosto 2026):** la auditoría de ADR-025 confirmó, contra la exportación real de políticas de Postgres, que el aislamiento por `org_id` **no está garantizado en todas las tablas**. `eventos`, `clientes` y `perfiles` conservan políticas permisivas legacy (`auth.role()='authenticated'` o directamente `true`, sin chequeo de `org_id`) que conviven con las políticas correctas en vez de haberlas reemplazado — cualquier cliente autenticado puede hoy, en teoría, leer o escribir datos de otra organización en esas tablas. Ver Sección 10 y `DECISIONS.md` ADR-025 para el detalle.

### 2.4 Flujo de Autenticación

- Login con email/password via Supabase Auth
- Al autenticar: carga perfil → org_id → datos de la organización → branding
- onAuthStateChange ignora TOKEN_REFRESHED para evitar resets del estado
- Heartbeat cada 60 segundos verifica que la sesión siga activa
- Realtime de Supabase deshabilitado (causaba bloqueos en producción)

## 3. Análisis del Sistema

### 3.1 Fortalezas

**Operación sin papel**
El sistema elimina completamente las listas en papel y los Excel desactualizados. Todos los registros se almacenan en tiempo real en Supabase y son accesibles desde cualquier dispositivo. El portero tiene la lista completa en su celular con búsqueda inteligente.

**Modo offline robusto**
El scanner funciona sin internet. Los registros de ingreso se guardan en una cola local (localStorage) y se sincronizan automáticamente cuando vuelve la conexión. Esto es crítico para eventos en venues con señal débil.

**Datos reales y accionables**
A diferencia de soluciones basadas en papel, el sistema genera datos ricos: hora exacta de llegada de cada asistente, tasa de asistencia por evento, efectividad de cada invitador, distribución geográfica del público, y tendencias de crecimiento semana a semana.

**Control de aforo**
La verificación de aforo es doble: en el cliente (bloquea el formulario cuando se llena) y en el servidor (verifica antes del INSERT para evitar condiciones de carrera). Esto es especialmente valioso para eventos con capacidad limitada.

**Recuperación de entradas**
Si un asistente pierde su ticket, puede recuperarlo directamente desde la página pública ingresando su cédula. El sistema muestra el QR guardado sin necesidad de contactar al hostal. Esta funcionalidad reduce la carga operativa el día del evento.

**Invitadores medibles**
El sistema no solo genera links de invitación — mide la efectividad de cada invitador: cuántas personas trajo, cuántas asistieron realmente, y en qué eventos tiene más tracción. Esto permite tomar decisiones sobre a quién invitar a participar como promotor.

**Identidad de administración separada del dato de cliente ✅ *(nuevo, ADR-025)***
Desde agosto 2026, la cuenta que supervisa el SaaS completo es una organización dedicada sin eventos propios, separada de cualquier cliente real. Elimina el riesgo de mezclar métricas de un cliente con las de supervisión multi-tenant, y el de perder acceso administrativo si un cliente cambia su propio slug.

### 3.2 Debilidades

**Tamaño del admin.html**
El archivo admin.html tiene ahora ~458KB / 7.973 líneas de JavaScript, muy por encima del ideal para una aplicación web moderna. Esto se traduce en un tiempo de carga inicial más largo, especialmente en móviles con conexión 3G. La solución es extraer módulos bajo demanda (como ya se hizo con SheetJS).

**Sin cobro integrado**
El tipo "pago" existe en el sistema pero se asigna manualmente. No hay un flujo de cobro real: el organizador debe verificar el pago por fuera (efectivo, transferencia) y luego actualizar manualmente el tipo del inscrito. Esto genera fricción y riesgo de error humano.

**Sin recordatorios automáticos**
El panel de análisis muestra que el no-show promedio puede ser alto. Un recordatorio automático 24 horas antes del evento reduciría significativamente esta métrica. La infraestructura de email ya está desplegada — falta solo la programación automática.

**Sin PWA en el scanner**
El scanner funciona perfectamente como web app pero no se puede instalar en el home screen del portero como una aplicación nativa. Sin un manifest.json y Service Worker, no hay icono en la pantalla de inicio ni carga desde caché.

**~~Dependencia de un slug hardcodeado~~ ✅ Resuelto (ADR-025, agosto 2026)**
~~El slug "hostal-terraza" está hardcodeado en el código JavaScript como identificador del system admin. Si se cambia el slug de la organización, se pierde acceso al panel de sistema.~~ Reemplazado por la columna booleana `organizaciones.is_master_org`, tanto en el frontend como en las políticas RLS de Postgres que dependían del mismo string. Verificado funcionando en producción. Ver Sección 10.

**Aislamiento multi-tenant incompleto en algunas tablas ⚠️ *(nuevo hallazgo, agosto 2026 — reemplaza la debilidad anterior como el riesgo de seguridad más relevante hoy)***
La auditoría de ADR-025 encontró políticas RLS legacy permisivas en `eventos`, `clientes` y `perfiles` que no fueron retiradas al agregar las políticas correctas por `org_id`, y se combinan con ellas (OR, no reemplazo). En la práctica, esto significa que el aislamiento entre clientes no está garantizado al 100% en esas tablas hoy. Ver Sección 10.

### 3.3 Oportunidades

**SaaS para otros venues**
La arquitectura multi-tenant ya está implementada. El sistema puede venderse como servicio a otros bares, restaurantes, hostales y espacios culturales en Colombia. El costo marginal de agregar una nueva organización es prácticamente cero.

**Integración con pagos**
Wompi y Bold son las pasarelas de pago más usadas en Colombia. Integrar el cobro directamente en el formulario de registro convertiría el sistema en una solución completa de ticketing con ingresos directos para el organizador.

**Datos como activo**
Con el tiempo, el sistema acumula datos valiosos sobre el comportamiento del público: preferencias, frecuencia de asistencia, redes de contacto, distribución geográfica. Con consentimiento del usuario, estos datos pueden informar decisiones de programación y marketing.

**API para integraciones**
Supabase ya expone una API REST y GraphQL sobre todas las tablas. Conectar el sistema con herramientas de email marketing (Mailchimp, Brevo), CRM o redes sociales ampliaría considerablemente su valor sin desarrollar funcionalidades adicionales.

## 4. Panel de Análisis de Datos

El sistema incluye un panel de análisis completo con 12 módulos que calculan métricas en tiempo real a partir de los datos almacenados. A continuación se describe cada módulo y su utilidad práctica.

| **Módulo** | **Qué mide** | **Para qué sirve** |
|---|---|---|
| KPIs generales | Inscritos, asistencia %, no-show %, hora pico | Resumen ejecutivo del período |
| Inscritos vs asistencia | Barras comparativas por evento | Identificar eventos con alto no-show |
| Tipos de asistentes | Donut: frecuente, invitado, artista, etc. | Entender la composición del público |
| Heatmap de ingresos | Hora × día de la semana | Planear cuándo necesitar más personal |
| Retención | Personas que vuelven 2+, 3+, 4+ eventos | Medir lealtad del público |
| Ranking inscriptores | Invitadores por # de personas traídas | Identificar mejores promotores |
| Heatmap inscripciones | Cuándo se registran (no cuándo llegan) | Optimizar cuándo publicar flyers |
| Insights automáticos | Recomendaciones generadas por el sistema | Acción rápida sin análisis manual |
| Perfil del asistente | País, tipo, edad, email, hora llegada | Conocer al público objetivo |
| Origen geográfico | Distribución por país/ciudad | Decidir dónde hacer publicidad |
| Canales de llegada | Orgánico vs por invitador | Medir ROI de la red de promotores |
| Crecimiento base | Nuevos asistentes por semana | Ver si la audiencia está creciendo |

> *Insight clave: Si el 80% de las inscripciones ocurren el mismo día del evento (detectable en el heatmap de inscripciones), el flyer se está publicando demasiado tarde. El sistema detecta este patrón automáticamente.*
>
> *Nota operativa (agosto 2026): el panel filtra por defecto a los últimos 30 días (`_pnPeriod`). En organizaciones con historial largo, revisar el botón "Todo" antes de asumir que un módulo está vacío o roto — ver Sección 10.*

## 5. Estrategias de Monetización

El sistema tiene múltiples vías de monetización que van desde cobros por servicio hasta la venta del sistema como plataforma. A continuación se analizan las opciones ordenadas por viabilidad inmediata.

### 5.1 Entradas de Pago — Integración Wompi

Esta es la monetización más directa y de mayor impacto. El tipo "pago" ya existe en el sistema pero se asigna manualmente. La integración completa requiere:

- Cuenta en Wompi Colombia (wompi.com) — gratuita, sin mensualidad
- Widget de Wompi en el formulario de registro, antes de generar el QR
- Edge Function en Supabase que reciba el webhook de confirmación de pago
- El QR se genera automáticamente solo cuando el pago está confirmado

Wompi cobra aproximadamente 2.9% + $900 COP por transacción. Para eventos de $20.000-$80.000 COP, el costo es de $1.480-$3.220 COP por entrada — completamente razonable para el organizador.

> *Beneficio clave: elimina cobros en efectivo, reduce el riesgo de fraude (no hay QR sin pago confirmado), y permite cobrar con tarjeta de crédito, débito y PSE sin intermediarios físicos.*

### 5.2 SaaS — Vender el Sistema a Otros Venues

La arquitectura multi-tenant ya está implementada. El costo marginal de agregar una nueva organización es prácticamente cero (solo el espacio en la BD de Supabase). Esto lo convierte en un candidato ideal para un modelo SaaS.

Modelo de precios sugerido para Colombia:

| **Plan** | **Precio/mes** | **Incluye** | **Ideal para** |
|---|---|---|---|
| Free | Gratis | 1 evento, hasta 50 inscritos, sin análisis | Probar el sistema |
| Mensual | $200.000 COP | Eventos ilimitados, análisis completo, exportaciones | Bares y hostales activos |
| Por evento | Desde $30.000 | Pago solo cuando publicas un evento | Eventos ocasionales |
| Combinado | Base + excedentes | Base mensual + tarifa por evento grande | Venues con temporada alta |

Con 10 clientes en plan Mensual: $2.000.000 COP/mes. Con 25 clientes: $5.000.000 COP/mes. El costo de Supabase Pro es $25 USD/mes (~$100.000 COP).

> *El punto de quiebre financiero es aproximadamente 2 clientes pagando el plan Mensual — a partir de ahí el sistema genera utilidad neta.*

### 5.3 Comisiones por Referencias

El sistema ya trackea invitadores con sus códigos únicos. Si el evento es de pago, se puede calcular automáticamente una comisión para el invitador por cada persona que trajo y pagó. Esto crea un incentivo económico real para la red de promotores.

Implementación: campo `comision_pct` en la tabla invitadores, cálculo automático en el webhook de pago de Wompi, y resumen de comisiones ganadas en el perfil del invitador del admin.

### 5.4 Datos y Audiencias Segmentadas

Con suficiente volumen de datos y consentimiento explícito del usuario (Ley 1581 de Colombia), el sistema puede ofrecer campañas segmentadas a marcas:

- Turistas internacionales (campo ciudad/país de origen ya existe)
- Público de un género musical específico (campo tags en clientes)
- Asistentes frecuentes con más de N eventos (campo total_eventos)
- Personas que no han asistido en 60+ días (candidatos a reactivación)

**IMPORTANTE:** Cualquier uso comercial de datos personales requiere consentimiento explícito en el formulario de registro, conforme a la normativa colombiana de protección de datos.

### 5.5 Apple Wallet / Google Wallet

El ticket actualmente vive en una imagen PNG. Convertirlo a formato Wallet permite que aparezca en la pantalla de bloqueo del celular cuando el asistente llega al venue, mejorando considerablemente la experiencia.

Para Apple Wallet: requiere certificado de Apple Developer ($99 USD/año) y generación de archivos .pkpass desde una Edge Function. Para Google Wallet: requiere cuenta de Google Pay for Passes y generación de JWT firmados. Esta mejora es un diferenciador importante si el sistema se vende como SaaS premium.

## 6. Ruta de Trabajo — Hoja de Ruta Priorizada

### 6.1 Inmediato (próximas 2 semanas)

Estas mejoras tienen el mayor impacto con el menor esfuerzo. La infraestructura ya está lista.

**Recordatorio automático 24h antes del evento**
La Edge Function de email ya está desplegada. Solo falta una segunda función con pg_cron (disponible en Supabase Pro) que corra cada hora, busque eventos de mañana, y llame a send-ticket-email para cada inscrito. Reducción esperada del no-show: 20-40%.

**Botón Wompi en registro.html**
Agregar el widget de Wompi al paso 3 del registro para activar el plan al crear la cuenta. Sin esto, todas las organizaciones son gratuitas indefinidamente.

**Edge Function wompi-webhook**
Recibe el POST de Wompi, verifica la firma HMAC, y actualiza `organizaciones SET activa=true, plan='mensual'`. Habilita el modelo de negocio SaaS.

### 6.2 Corto Plazo (1 mes)

**Lista de espera cuando aforo lleno**
Tabla `lista_espera` en Supabase + formulario alternativo cuando el aforo está completo. Notificación automática cuando se libera un cupo. Requiere pg_cron para monitoreo.

**Dashboard contextual para porteros**
Cuando un portero hace login, ver solo: evento de hoy, contador de inscritos vs aforo, últimos 5 ingresos, y botón directo al scanner. Elimina confusión en el equipo el día del evento.

**PWA instalable — scanner**
Agregar manifest.json y Service Worker básico al scanner. Permite que el portero instale la app en su home screen como si fuera nativa. Carga desde caché, funciona sin señal desde el inicio.

### 6.3 Mediano Plazo (2-3 meses)

**Cobro online completo — Wompi en eventos**
Integrar el widget de Wompi directamente en evento.html para que los asistentes paguen al registrarse. El QR se genera solo cuando el webhook confirma el pago exitoso.

**NPS automático post-evento**
24 horas después de cada evento, pg_cron envía un email a los asistentes (used=true + tienen email) con una pregunta de satisfacción de 1 clic. La tabla `nps_respuestas` almacena las respuestas y se grafica en el panel de análisis.

**Reducir tamaño admin.html**
El JS del admin pesa ~458KB (7.973 líneas — creció desde ADR-021). Extraer los módulos de análisis, directorio y QR tracker como scripts cargados bajo demanda (como ya se hizo con SheetJS) reduciría el tiempo de carga inicial considerablemente.

**Auditoría y limpieza de políticas RLS legacy *(nuevo, agosto 2026 — TSK-026)***
Retirar las políticas permisivas heredadas en `eventos`, `clientes` y `perfiles` que hoy conviven con las políticas correctas de aislamiento por `org_id`. Requiere revisar primero qué flujos públicos (registro, scanner) dependen de alguna de ellas antes de retirarlas. Ver Sección 10.

### 6.4 Largo Plazo (3-6 meses)

**Apple Wallet / Google Wallet**
Generación de tickets digitales en formato Wallet desde una Edge Function. Diferenciador premium para el plan SaaS de mayor precio.

**API pública para integraciones**
Documentar y exponer una API REST sobre Supabase para que las organizaciones integren el sistema con sus herramientas existentes: CRM, email marketing, sistemas de membresías.

**Dashboard de métricas para clientes SaaS**
Un panel simplificado que los clientes del SaaS puedan compartir con sus patrocinadores o inversores: métricas clave, crecimiento, comparativas, todo con el branding de la organización.

## 7. Retroalimentación y Lecciones Aprendidas

### 7.1 Lo que funciona muy bien

**Canvas API para tickets**
La decisión de generar los tickets con Canvas API en lugar de html2canvas fue correcta. html2canvas fallaba consistentemente en iOS Safari, el navegador más usado por los asistentes. Canvas API funciona en todos los dispositivos sin dependencias externas.

**Modo offline en el scanner**
La implementación de cola offline (qrCache + offlineQueue) ha sido una de las funcionalidades más valoradas. Los porteros pueden trabajar con confianza incluso en venues con señal intermitente, sabiendo que todos los registros se sincronizarán.

**Sistema de invitadores**
El concepto de invitadores con códigos permanentes que pueden generar links para múltiples eventos ha funcionado mejor de lo esperado. Permite medir la efectividad real de cada promotor y da visibilidad sobre los canales de llegada al evento.

**Rate limiting con localStorage**
La solución simple de guardar el timestamp del último registro en localStorage (sin backend) ha sido efectiva para bloquear el spam básico. No es perfecta (se puede limpiar el storage), pero elimina el 95% de los casos de registro masivo accidental o automatizado.

### 7.2 Problemas encontrados y soluciones

**Bloqueo del sistema después de primera acción**
Causa: onAuthStateChange de Supabase llama al handler en cada refresco del JWT (cada ~1 hora), reseteando ORG_ID a null mientras el usuario trabaja. Solución: agregar una guarda que ignore el evento si ya hay un usuario activo (`if event === SIGNED_IN && !currentUser`).

**Múltiples instancias de GoTrueClient**
Causa: el cliente de Supabase se recreaba en ciertos flujos, generando advertencias en consola y comportamiento indefinido. Solución: verificar que SB sea null antes de crear el cliente, o usar un patrón singleton.

**CSP de Vercel bloquea eval()**
La librería qrcodejs usa new Function() internamente, lo que viola la Content Security Policy que Vercel aplica automáticamente. Solución: reemplazarla con qr-creator, que usa solo Canvas API y es completamente CSP-safe.

**YouTube Error 153 en iframes**
Incrustar videos de YouTube con `<iframe>` en páginas públicas genera el error 153 cuando el usuario llega desde ciertas fuentes (ads, redes sociales). Solución: mostrar el thumbnail del video con un botón que abre YouTube en una nueva pestaña.

**loadDirectorio: q is not defined**
Una refactorización introdujo una variable q en el scope incorrecto. La búsqueda del directorio usaba q como filtro de query a Supabase sin declararlo. Solución: asegurarse de que todas las variables de filtro se declaren dentro del scope de la función.

**Identidad de System Admin acoplada a un cliente real *(nuevo, agosto 2026 — ADR-025)***
Causa: la primera organización creada durante el desarrollo ("Barrio R10", slug `hostal-terraza`) se usó también como cuenta de administración del SaaS, y esa conveniencia inicial nunca se separó al pasar a producción con clientes reales — el frontend y 2 políticas RLS de Postgres identificaban al operador del SaaS comparando ese slug exacto. Solución: columna `organizaciones.is_master_org boolean` como fuente de verdad única, organización maestra nueva sin eventos propios, y el cliente real pasa a ser indistinguible de cualquier otro. Ver Sección 10 para el detalle completo, incluyendo un hallazgo colateral sobre políticas RLS legacy (TSK-026) que quedó documentado pero no corregido en la misma sesión.

### 7.3 Decisiones técnicas en retrospectiva

**HTML puro vs framework**
La decisión de no usar React, Vue o Angular fue correcta para este contexto. El sistema es mantenible por una sola persona, se despliega con un drag-and-drop a Vercel, y no requiere un entorno de desarrollo específico. La desventaja — un archivo admin.html que ya supera las 7.900 líneas — es manejable con buena organización de secciones y comentarios.

**Supabase como backend único**
Consolidar autenticación, base de datos, Edge Functions y almacenamiento en un solo servicio fue la decisión correcta. Reduce la superficie de mantenimiento y el número de servicios a monitorear. El costo es competitivo y la curva de aprendizaje es baja.

**Multi-tenant con RLS en lugar de proyectos separados**
Un proyecto Supabase por cliente hubiera sido más simple de aislar pero muy costoso de operar. RLS con org_id da, en el diseño, el mismo nivel de aislamiento con una fracción del costo operativo. La complejidad adicional en las queries (agregar `.eq(org_id, ORG_ID)` en todas partes) es manejable.

> **Actualización (agosto 2026):** la auditoría de ADR-025 mostró que ese diseño no se aplicó de forma consistente en la práctica — políticas RLS legacy permisivas siguen activas en algunas tablas junto a las correctas `org_id`-scoped. La decisión arquitectónica (RLS con org_id) sigue siendo la correcta; lo que falta es una limpieza de las políticas que quedaron de versiones anteriores del esquema. Ver Sección 10, TSK-026.

## 8. Métricas Objetivo y KPIs del Sistema

### 8.1 Métricas operacionales

| **Métrica** | **Estado actual** | **Objetivo 3 meses** | **Objetivo 6 meses** |
|---|---|---|---|
| No-show rate | Sin medir | < 30% | < 20% |
| Tiempo de check-in por persona | ~15 segundos | < 10 segundos | < 8 segundos |
| Tasa de recuperación de entradas | Funcional | > 80% self-service | > 95% self-service |
| Inscripciones con email | Variable | > 60% | > 75% |
| Inscripciones desde móvil | Mayoritaria | > 85% | > 90% |

### 8.2 Métricas de negocio SaaS

| **Métrica** | **Mes 1** | **Mes 3** | **Mes 6** |
|---|---|---|---|
| Organizaciones registradas | 1 (Hostal Terraza) | 5 | 15 |
| Organizaciones de pago | 0 | 3 | 10 |
| MRR (ingreso mensual recurrente) | $0 | $600k COP | $2M COP |
| Churn mensual | — | < 10% | < 5% |
| Costo operativo mensual | ~$100k COP | ~$150k COP | ~$200k COP |

> *Nota (agosto 2026): la fila "Mes 1" ya quedó desactualizada — a la fecha existen al menos 4 organizaciones activas (la org maestra de supervisión más 3 clientes: Barrio R10, Barrio Drum & Bass, y al menos una más), no la única "Hostal Terraza" original. No se actualizó la cifra exacta en la tabla porque requiere confirmarla contra Supabase directamente en vez de estimarla desde esta conversación.*

## 9. Resumen Ejecutivo

El Sistema QR de Hostal Terraza es una plataforma de gestión de eventos completamente funcional, construida en menos de 6 meses, que cubre todo el ciclo operacional desde el registro hasta el análisis post-evento. Con 35+ funcionalidades implementadas, modo offline, soporte para iOS y Android, arquitectura multi-tenant, y análisis de datos en tiempo real, el sistema supera en capacidades a soluciones comerciales que cuestan cientos de dólares mensuales.

El próximo paso crítico es activar el modelo de monetización: integrar Wompi para el cobro de suscripciones SaaS y entradas de eventos. Con 10 clientes en plan mensual, el sistema genera $2.000.000 COP/mes con costos operativos de ~$200.000 COP/mes — una utilidad neta del 90%.

El sistema ya tiene todo lo necesario para escalar: la arquitectura multi-tenant está implementada, el onboarding self-service funciona, el panel de sistema permite operar como cualquier organización cliente **desde una cuenta de supervisión dedicada, ya no desde la cuenta de un cliente real (ADR-025, agosto 2026)**, y las Edge Functions de email están desplegadas y activas. El único componente faltante para convertirlo en un negocio es la integración del cobro online — y, en seguridad, cerrar la auditoría de políticas RLS legacy iniciada en agosto 2026 (TSK-026).

| **Dimensión** | **Estado** |
|---|---|
| Código | ✅ ~16.889 líneas · 6 archivos · Sintaxis limpia · Sin errores |
| Multi-tenant | ✅ org_id en todas las tablas · RLS · Branding dinámico · ⚠️ ver nota de seguridad abajo |
| Identidad de administración | ✅ Separada de cualquier cliente real (ADR-025, agosto 2026) |
| Seguridad | ✅ XSS protection · Rate limiting · UUID v4 · Org activa check · CSP · ⚠️ políticas RLS legacy pendientes de retirar (TSK-026) |
| Análisis | ✅ 12 módulos · Geo · Crecimiento · Invitadores · Canales |
| UX móvil | ✅ iOS/Android · Canvas API · Web Share API · Modo offline |
| SaaS ready | ✅ Multi-tenant · Onboarding · Panel Sistema · Panel Mi org |
| Monetización | ⏳ Wompi pendiente (arquitectura lista) |
| Recordatorios | ⏳ pg_cron pendiente (email ya funciona) |
| PWA | ⏳ manifest.json pendiente |

---

## 10. Actualización — Separación de Identidad SaaS y Auditoría de Seguridad Multi-tenant (Agosto 2026)

Esta sección documenta el trabajo realizado después de la versión de mayo 2026 de este análisis. Corresponde a `DECISIONS.md` **ADR-025** — ver ese documento para el runbook SQL completo y el detalle exhaustivo.

### 10.1 El problema

La organización "Barrio R10" (cliente real, con eventos e inscritos propios) operaba simultáneamente como identidad de System Admin global del SaaS. El frontend (`admin.html`) y dos políticas RLS de Postgres (`insert_organizaciones`, `delete_organizaciones`) concedían ese acceso comparando el slug de la organización contra el string literal `'hostal-terraza'` — el slug de Barrio R10. Esto se había señalado ya en la versión de mayo de este documento como una debilidad del sistema (Sección 3.2).

### 10.2 Auditoría (antes de tocar código o base de datos)

Se hizo un grep exhaustivo de los 8 archivos de frontend del sistema (`admin.html`, `index.html`, `qr.html`, `evento.html`, `evento3.html`, `registro.html`, `scanner.html`, `serie.html`): solo 3 referencias reales al slug hardcodeado, las 3 en `admin.html`. Se validó contra la exportación real de `pg_policies` de Supabase — no contra suposición — que solo las 2 políticas de `organizaciones` mencionadas arriba dependían del slug; `eventos`/`inscritos`/`perfiles` se aíslan por `org_id`, no por slug. También se confirmó que el slug de una organización no aparece en ningún link público (esos usan el slug del evento/serie), por lo que renombrarlo es seguro.

### 10.3 La solución

- Columna `organizaciones.is_master_org boolean` como única fuente de verdad de "es el operador del SaaS", reemplazando la comparación de slug tanto en el frontend como en las 2 políticas RLS reales.
- Nueva organización **"SaaS Master Admin"** (slug `master-admin`) creada como cáscara de supervisión, sin eventos, inscritos ni clientes propios.
- **Barrio R10 conserva su `org_id` original** (cero migración de datos) y pasa a ser un cliente regular, con su propio login operativo nuevo y separado del de administración del SaaS.
- Corte directo, sin período de transición con fallback — decisión explícita de Dirección.

**Estado: ✅ verificado en producción.** Las 4 cuentas resultantes resuelven correctamente su organización al loguear, y `entrarComoOrg()` (el mecanismo para operar los datos de un cliente desde la cuenta maestra) está confirmado funcionando.

### 10.4 Hallazgo colateral — políticas RLS legacy (TSK-026, no resuelto)

La misma auditoría de `pg_policies` reveló que varias tablas (`eventos`, `clientes`, `perfiles`) conservan políticas permisivas de versiones anteriores del esquema (`auth.role()='authenticated'` o directamente `true`, sin chequeo de `org_id`) que **conviven** con las políticas correctas — en Postgres, las políticas RLS permisivas se combinan con OR, no se reemplazan entre sí. En la práctica, esto significa que cualquier cliente autenticado del SaaS, no solo el operador, podría hoy leer o escribir datos de otra organización en esas tablas. Es un hallazgo más amplio que el problema original de Barrio R10 y queda **fuera del alcance de ADR-025** — requiere su propio análisis dedicado antes de retirar las políticas legacy, porque algunas de ellas (por ejemplo, la que permite al scanner de puerta actualizar `inscritos` sin sesión autenticada) parecen sostener flujos públicos legítimos.

### 10.5 Nota operativa — filtro de 30 días en el Panel

Durante la verificación en producción surgió un reporte de "el panel no muestra los datos de un cliente", que resultó no estar relacionado con ADR-025: el Panel filtra por defecto a los **últimos 30 días** (`_pnPeriod`), independiente del selector de evento/serie. En clientes con historial largo, esto puede mostrarse como si faltaran datos cuando en realidad están fuera de la ventana de tiempo activa — el botón **"Todo"** los muestra. Se corrigió de paso un desface menor de consistencia (el botón "7d" aparecía marcado como el período activo por defecto en el HTML mientras el código realmente arranca en "30d"), sin impacto visual pero sí de corrección de código.

---

*Hostal Terraza · Sistema QR · Bogotá, Colombia · Mayo 2026 — Sección 10 añadida en Agosto 2026*

hostalterraza.vercel.app
