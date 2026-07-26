CLAUDE.md: Constitución Técnica del Sistema QR Hostal Terraza (v1.3.39)
Rol de este documento: Este archivo sirve como el Kernel de Referencia Rápida y Fuente Única de Verdad para cualquier agente Claude que colabore en el proyecto. Su objetivo es garantizar la consistencia técnica, el cumplimiento de las normas de arquitectura y la fidelidad visual de 1px sin necesidad de explicaciones redundantes en cada nueva sesión.

1. Misión Técnica y Stack
Arquitectura Core: Aplicación web modular basada en Vanilla JavaScript (ES6+), HTML5 semántico y CSS3 modular.

Ausencia de Frameworks de Compilación: Prohibido el uso de herramientas de empaquetado complejas (Webpack, Vite, etc.) para mantener un despliegue directo y liviano.

Infraestructura y Datos:

Base de datos y autenticación: Supabase.

Hosting y Despliegue continuo: Vercel.

Gestión de Conocimiento y PM Hub: NotebookLM integrado mediante carpetas espejo en Google Drive (copiahostalterraza).

2. Reglas de Oro (v1.3.37 - Resumen Ejecutivo)
Mandato Data-First (Fase I y II): Certificar la sincronía de datos y mapeo de IDs antes de aplicar cualquier estilización visual (Afterglow).

Protocolo de Cero Borrado: Queda terminantemente prohibido eliminar IDs de inyección lógicos o elementos estructurales esenciales (usar display: none si es necesario ocultarlos).

Salvaguarda de Activos y SVGs: Mantener los iconos SVG físicos intactos para preservar las transparencias y efectos de resplandor reales.

Tratamiento No-Plano: Las tarjetas técnicas (Dresscode, Aforo, etc.) exigen tipografía Geist (peso 900) y resplandor visual (drop-shadow).

Aislamiento Atómico (CSS Scoped): Todo el CSS externo debe estar encapsulado bajo un selector padre único (.tpl-{id}) para evitar colisiones con el orquestador maestro.

Bloque de Reseteo de Silo: Neutralizar márgenes y posiciones por defecto al inicio de cada archivo de estilos de plantilla.

Activación de Ámbito Dual: Inyección en el <body> tanto del ID normal como de su versión en minúsculas (tpl-F3 tpl-f3) para evitar errores de sensibilidad.

Contrato de Interactividad: Toda acción de usuario (FAQ, pestañas, modales) debe tener atributos onclick inyectados de forma física mediante JavaScript.

Escudo de Auditoría GOLD (6 Niveles): Emisión obligatoria en consola de los registros INFO, DEBUG, LINK, TRACE, TIME y ERROR antes de cerrar cualquier iteración.

Cláusula de Volumen (Masa Crítica): Respetar el baseline de volumen aproximado (~300-350 líneas) para evitar la simplificación accidental de lógica.

No-Regresión de Logs: Prohibido reducir el detalle o la cantidad de latidos en los reportes de consola respecto a las versiones anteriores.

Validación Dual de 1px: Comparación simultánea entre el Silo externo y el Master para garantizar cero desplazamientos visuales.

Círculo de Virtud (Flujo Agéntico): NotebookLM (Cerebro PM) → ChatGPT (Branding/UI) → Claude (Arquitectura y QA) → Gemini (Escritura y Sincronización Espejo).

3. Contrato de Datos v107 (IDs Protegidos Innegociables)
Los siguientes identificadores lógicos no deben ser eliminados ni modificados bajo ninguna circunstancia de refactorización:

#meta-fecha: Contenedor físico de la fecha del evento.

#meta-hora: Contenedor físico de la hora del evento.

#meta-lugar: Contenedor físico de la ubicación del venue.

#db-lineup: Nodo de inyección para artistas y avatares.

#db-poster-img: Etiqueta de imagen para el póster oficial.

#db-dress-val: Tarjeta técnica de código de vestimenta.

#db-aforo-val: Tarjeta técnica de capacidad/aforo.

#db-ticket-val: Nodo de estado de boletería.

#db-faq-list: Contenedor dinámico de preguntas frecuentes.

#db-sponsors-list: Contenedor dinámico de marcas aliadas.

4. Arquitectura de Inyección y Estilos
Ruta de Carga Dinámica: Los estilos se inyectan en tiempo de ejecución bajo la ruta normalizada: css/templates/[categoria]/[template_id].css.

Aislamiento de Clases: Las reglas CSS dentro del archivo de plantilla deben comenzar obligatoriamente con el selector de ámbito (ej. .tpl-f3 .elemento { ... }).

5. Comandos de Control de Referencia
/audit: Ejecuta la verificación completa del Escudo GOLD y reporta el log TRACE cuantitativo en consola.

/plan: Activa el modo de análisis de reflexión contra el Baseline del BLUEPRINT.md antes de proponer cambios estructurales.