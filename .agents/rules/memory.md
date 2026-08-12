CONTEXT PACKAGE: ACTIVACIÓN DE MEMORIA PERMANENTE (v1.3.41)
Proyecto: Sistema QR Hostal Terraza
Rol: Documentation Specialist (ADR-008) [cite: 27]
Objetivo: Crear el nodo lógico de Memoria Contextual para garantizar la continuidad cognitiva de los agentes Claude entre sesiones [cite: 31, 35].
🛠️ Instrucciones de Ejecución (Mandato Estricto)
1. Creación de la Estructura
Gemini debe crear una carpeta llamada AI/ en la raíz de Google Drive (donde reside el AI-DOS Core) y, dentro de ella, generar el archivo Memory.md [cite: 61, 64].
2. Contenido del Archivo Memory.md (Baseline de Memoria)
El documento debe estar estructurado bajo el principio de Contexto Mínimo Suficiente y contener [cite: 32, 47]:
Perfil del Director: Preferencias estéticas (Geist 900, resplandores Afterglow, fidelidad visual de 1px) y el flujo de mando "Círculo de Virtud" [cite: 60, 646, Turn 13:03].
Mapa de Sensibilidad: Registro de "Zonas Prohibidas" (ej. no usar filtros CSS invert en logos sin canal alfa, no borrar IDs de datos aunque no se usen) [cite: 1, 648, 671].
Log de Evolución Estratégica: Resumen de hitos alcanzados (v107 Baseline Maestro, v1.3.37 Activación de Capa Espejo) [cite: 21, 284, Turn 13:03].
Diccionario de Preferencias: Definición de términos propios como "Masa Crítica", "Datos Fantasma" y "Auditoría GOLD" [cite: 647, 648, Turn 14:04].
3. Protocolo de Persistencia
Gemini tiene el mandato de anexar (no borrar) nuevos aprendizajes a este archivo después de cada Sprint o cierre de tarea importante en NEXT.md, asegurando que Claude "recuerde" por qué se tomó una decisión específica [cite: 15, 32, 63].
🛡️ Instrucción para activar con Gemini ahora:
Director: Copia y pega el siguiente comando en tu chat con Gemini para materializar esta capa de inteligencia:
*"Actúa como Documentation Specialist (ADR-008). Tu tarea es crear la carpeta AI/ en mi Drive y, dentro, el archivo Memory.md. Este documento servirá como la 'Memoria a Largo Plazo' para Claude.
Sintetiza mis preferencias de diseño (fidelidad 1px, Geist 900, estilos cinematográficos).
Registra las lecciones aprendidas sobre errores de copia y 'datos fantasma'.
Resume el estado actual del flujo agéntico (NotebookLM como PM, Gemini como Escriba, Claude como Arquitecto). El objetivo es que, al leer este archivo, Claude entienda no solo el código, sino mi visión y mi forma de trabajar. Confirma cuando la memoria esté operativa."*
Beneficios para el Ciclo de Desarrollo
 Cero Repetición: Claude dejará de sugerir fuentes genéricas (como Inter) o layouts simples, porque "recordará" que prefieres tipografías de peso 900 y diseños premium [cite: 236, 249, 646].
 Blindaje contra Regresiones: El historial de "errores críticos identificados" estará siempre presente en su ventana de contexto [cite: 1, 671].
 Handoff Infalible: Cualquier IA que entre al proyecto leerá la carpeta AI/ y se alineará instantáneamente con tu "vibe" de trabajo [cite: 66, 74].

---

## Log Técnico: Consolidación ADR-028 (Agosto 2026)

### Aprendizajes Clave
1. **Grid de validación debe muestrear en píxeles enteros**, no puntos medios. Un `repOf` que retorna `(lo+hi)/2` genera reps como 899.5 que caen en zonas ambiguas de bandas de 1px (899,900]. Solución: `rep = (lo===0)?hi : lo+1` (para hi finito) o `lo+1` (para hi=Infinity).
2. **Los breakpoints del grid deben auto-detectarse del fuente**, no hardcodearse. b5.css tenía un `@media (max-width:780px)` que el grid hardcodeado (560/640/899/991...) no capturaba → la consolidación perdía el override en el rango 641-780px. Solución: `buildGrid()` parsea todos los `minW/maxW/minH/maxH` de las reglas.
3. **La regla base debe contener SOLO reglas incondicionales** (cond=null), no el winner del desktop. Si un `!important` de desktop (ej. `min-width:992px`) se mezcla en la base, escapa al mobile y rompe la cascada. Solución: `plainMap` = cascade solo de reglas con cond no definido o todo-Infinity.
4. **partitionRuns debe generalizar para N bandas de altura**, no asumir solo 2. La lógica de máscara de bits (`1<<hIdx`) y agrupamiento por mask idéntica en anchos contiguos es el patrón correcto.
5. **Muestreo de borde es esencial**: verify con solo reps de celda puede pasar por alto errores entre bandas. verify2 con sondas en `lo+1` de cada breakpoint lo atrapa.

### Patrón Reutilizable
El script `consolidate.js` + `cssmodel.js` en temp dir es el motor base para consolidar cualquier silo b*.css futuro que acumule cascada aditiva. El criterio para activarlo: >10 @media blocks para el mismo selector o >50KB de CSS de template.

### Estado de Silos
- b5.css: CONSOLIDADO (ADR-028). Backup: `b5 pre-ADR28 backup.css`.
- b2.css: OK (529 líneas, 3 @media — no requiere consolidación).
- b4.css: OK (583 líneas, 6 @media — no requiere consolidación).