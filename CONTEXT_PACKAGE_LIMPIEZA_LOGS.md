# Context Package: Limpieza de Logs y Optimización de eventovenezuela.html

## Objetivo
Optimizar `eventovenezuela.html` para el usuario final eliminando todo código de logging que ralentiza la página.

## Estado actual (parcialmente completado)

### ✅ Completado
1. **Título cambiado** (línea 6): `Master Orchestrator v214 · Atomic Grid System` → `Sonidos por el cambio`
2. **Noise overlay eliminado**: CSS `body::before` con SVG noise filter (antes líneas 22-26)
3. **Loader overlay eliminado**: CSS `.loading-overlay` y HTML `<div id="loader">` 
4. **Función `logStatus()` eliminada**: Definición completa removida (antes líneas 535-538)
5. **6 llamadas `logStatus()` eliminadas**: Las que estaban en el bloque del formulario (Fase 1/2) y en `injectAtomicCSS`

### ❌ Pendiente (36 llamadas logStatus + 2 console.log + 1 referencia rota)

#### A) Eliminar 36 llamadas `logStatus()` restantes
Cada línea es una llamada independiente que debe eliminarse completa (la línea entera):

| Línea | Contenido |
|-------|-----------|
| 726 | `logStatus(\`TRACE: Fase 2 completada...\`` |
| 728 | `logStatus(\`ERROR: Fallo UPDATE Fase 2...\`` |
| 757 | `logStatus(\`ERROR: Timeout de 5s al cargar CSS...\`` |
| 792 | `logStatus("Iniciando Orquestador v214...` |
| 816 | `logStatus("DEBUG: Prioridad de color...` |
| 830 | `logStatus(\`DEBUG: Ámbito Dual inyectado...\`` |
| 947 | `logStatus(\`TRACE: ${galStatus} inyectada...\`` |
| 985 | `logStatus("TRACE: Spotify Sync 1:1...\`` |
| 1008 | `logStatus(\`TRACE: Historia...\`` |
| 1044 | `logStatus(\`TRACE: ${hiStatus} inyectados...\`` |
| 1068 | `logStatus(\`TRACE: Objetivo...\`` |
| 1160 | `logStatus(\`TRACE: ${impactoStatus}...\`` |
| 1193 | `logStatus(\`TRACE: Mapa de crisis...\`` |
| 1216 | `logStatus("TRACE: Mapa de crisis COLOMBIA...\`` |
| 1257 | `logStatus(\`TRACE: ${caStatus}...\`` |
| 1284 | `logStatus(\`TRACE: ${casStatus}...\`` |
| 1308 | `logStatus(\`TRACE: ${ihStatus}...\`` |
| 1372 | `logStatus(\`TRACE: ${actStatus}...\`` |
| 1402 | `logStatus(\`TRACE: ${statusMsg}...\`` |
| 1429 | `logStatus(\`TRACE: ${equipoStatus}...\`` |
| 1440 | `logStatus(\`TRACE: CTA final...\`` |
| 1500 | `logStatus("TRACE: Footer inyectado...\`` |
| 1507 | `logStatus("LINK: Póster real...\`` |
| 1525 | `logStatus(\`TRACE: Lineup inyectado...\`` |
| 1568 | `logStatus(\`TRACE: ${faqStatus}...\`` |
| 1609 | `logStatus(\`TRACE: Contacto directo...\`` |
| 1648 | `logStatus(\`TRACE: ${techStatus}...\`` |
| 1675 | `logStatus(\`DEBUG: Módulo...\`` |
| 1682 | `logStatus(\`INFO: Módulo...\`` |
| 1684 | `logStatus(\`DEBUG: Módulo...\`` |
| 1688 | `logStatus(\`INFO: ${activeModulesCount}...\`` |
| 1694 | `logStatus(\`SEAL: Contrato...\`` |
| 1705 | `logStatus(\`TRACE: Structural Audit...\`` |
| 1708 | `logStatus("TIME: Heartbeat...\`` |
| 1709 | `logStatus("TRACE: Auditoría v1.4.8...\`` |
| 1711 | `logStatus(\`FALLO CRÍTICO...\`` (ver nota abajo) |

#### B) Eliminar 2 `console.log` directos
| Línea | Contenido |
|-------|-----------|
| 900 | `console.log("%c[TRACE] Vídeo YouTube detectado...` |
| 912 | `console.log("%c[TRACE] Vídeo Vimeo detectado...` |

#### C) Referencia rota a `loader` (línea 1711)
```js
} catch (err) { logStatus(`FALLO CRÍTICO: ${err.message}`, "ERROR"); } finally { document.getElementById('loader').style.display = 'none'; }
```
El `<div id="loader">` ya fue eliminado del HTML. Esta línea debe cambiarse a:
```js
} catch (err) { /* error silenciado para usuario final */ } finally { /* loader eliminado */ }
```
O simplemente:
```js
} catch (err) { console.error(err); }
```

## Archivos afectados
- `eventovenezuela.html` — único archivo a modificar

## Reglas importantes
- **NO tocar** la lógica de negocio (form, Supabase, inyección de datos, countdown, etc.)
- **NO tocar** la función `formatRichText` ni ninguna otra función utilitaria
- **NO tocar** el HTML de los módulos
- **SOLO eliminar** líneas `logStatus(...)`, `console.log(...)`, y arreglar la referencia rota a `loader`
- Cada `logStatus` es una línea independiente; eliminar la línea completa sin dejar saltos de línea innecesarios

## Verificación
Al terminar, verificar que:
1. No queden llamadas a `logStatus` en el archivo
2. No queden `console.log` (sí se puede dejar `console.error` para errores críticos)
3. No queden referencias a `getElementById('loader')`
4. El título siga siendo "Sonidos por el cambio"
5. La página cargue sin errores en consola
