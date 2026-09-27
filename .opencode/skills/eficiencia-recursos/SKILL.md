---
name: eficiencia-recursos
description: Reglas de eficiencia: costo = turnos x contexto, disciplina de grep, diagnostico de CSS inline, informe de cierre obligatorio. Cargar en sesiones largas o al optimizar consumo.
---

# Eficiencia de Recursos (v128)

Operativiza los Mandatos 17 y 18 de `Sistema QR desarrollo/Reglas de Oro QR.md` (v128-MASTER). La unidad de costo real es `turnos × contexto acumulado`, no el output: en la sesión de banners del silo `f9b` el `cache_read` fue 29.5M de 32.2M tokens (91.7%), con input fresco 2.16M (6.7%), output 0.28M (0.9%) y razonamiento 0.22M (0.7%); `AGENTS.md` (8.123 tokens) se releyó en cada turno de cada agente (~6.5M tokens, ~20% del total). Métrica de control: `cache_read / turnos` (50.000 a 76.000 tokens por turno en esa sesión).

## Reglas de sesión

1. **Consolidación de agentes:** una sesión de implementación usa MAXIMO 1 agente de exploración + 1 de implementación por dominio + 1 de verificación. Todo lo demás se resuelve con script.
2. **Regla anti-colgado:** si un subagente devuelve vacío o excede el tiempo límite, NO se re-despacha el mismo perfil; se cambia de estrategia y se registra el incidente. (El `qa-auditor-free` devolvió vacío tras 2.9 h y 3.31M tokens; repetir la verificación costó +2.17M, ~17% de la sesión.)
3. **Un archivo, un lector:** prohibido que varios agentes de una misma sesión relean el mismo archivo grande cuando un brief dirigido (ruta + rango de líneas + bloque `old`/`new`) basta. Prohibido leer archivos completos de más de 200 KB (`admin.html` = 633 KB): usar rangos.
4. **Verificación mecánica = script, no agente:** `scripts/express_check.js` y los `scripts/smoke_*.js` cuestan 0 tokens de agente.
5. **Mutation testing acotado:** 5-8 mutaciones representativas, no decenas.
6. **Cierre medido:** toda sesión de implementación cierra midiendo con `node scripts/usage_report.js`. Presupuesto placeholder de un solo feature: no superar ~15M tokens ni ~3 h de reloj sin justificación escrita. Es un PLACEHOLDER hasta tener N >= 5 sesiones medidas (se recalibrará a ~1.5-2x la mediana); la métrica de control líder sigue siendo `cache_read / turnos`.

## `scripts/usage_report.js` — contrato CONGELADO

Reporte de uso de tokens y costo de la DB local de OpenCode. Interfaz congelada (no re-diseñar sin ADR):

* **Modos (MUTUAMENTE EXCLUYENTES):** `--summary` (default), `--sessions`, `--tree`, `--json`, `--csv`. Se pasa uno solo por invocación (combinarlos es error). Se aceptan los nombres de modo sin guiones (`summary`, `sessions`, `tree`, `json`, `csv`).
* **Filtros:** `--since`, `--until`, `--project`, `--agent`, `--root <sessionId>`, `--db`.
* **Detalle:** `--detail`, `--with-content`, `--max-chars N`. `--with-content` IMPLICA `--detail`.
* **Salida:** `--out <ruta>`, `--top N`, `-h` / `--help`. `--top N` limita la salida CSV SOLO si se pasa explícitamente.
* **Alcance por defecto:** sin `--since`, el script mide el **DIA LOCAL ACTUAL** (`00:00` -> ahora), NO "la sesión actual"; `--since 0` recorre **todo el histórico** de la DB.
* **Seguridad:** abre la DB en **readOnly** y NUNCA lee `account`, `control_account` ni `credential` (contienen tokens); `--with-content` redacta secretos.

Ejemplos reales:

```
node scripts/usage_report.js --summary                          # medir el día local actual (default)
node scripts/usage_report.js --summary --since 0                # todo el histórico de la DB
node scripts/usage_report.js --tree --root <sessionId>          # listar subagentes de una raíz
node scripts/usage_report.js --sessions --json --out uso.json   # exportar JSON para otra IA
```

## Informe de cierre de sesión (obligatorio)

Toda sesión de implementación cierra con un informe de gasto y aprendizaje. Se levanta con la herramienta existente, sin agente:

    node scripts/usage_report.js --summary          # dia local (default)
    node scripts/usage_report.js --tree --root <id> # desglose por subagente

El informe debe incluir, como mínimo:

| Campo | De donde sale |
|---|---|
| total_tokens | `totals.total` del reporte |
| turnos | suma de `turns` |
| cache_read / turnos | metrica de control (mide el contexto por turno) |
| segundos | suma de `seg` (reloj) |
| desglose por agente | `--tree` (quien gasto que) |
| 1-3 aprendizajes | accionables: que se releo de mas, que agente fallo, que brief falto |

Regla: el informe se entrega al cerrar, no se difiere. Si la sesión superó el presupuesto (Mandato 18), el informe debe explicar por qué.

## Disciplina de reconocimiento (grep y lectura)

La exploración del orquestador es el rubro más caro de una sesión: se midió un caso real donde 3 greps amplios costaron ~1.5M tokens frente a ~500K de un subagente de exploración enfocado.

1. `grep` SIEMPRE con la ruta del archivo concreto, nunca la raíz del repo.
2. Patrones ESPECÍFICOS. Prohibido alternar 5 términos en un solo patrón (devuelve 100 coincidencias truncadas y quema contexto).
3. Si no se conoce el archivo, la primera llamada es `glob`, no `grep`.
4. Reconocimiento amplio = subagente de exploración (modelo económico), no el orquestador.
5. Antes de abrir un archivo grande, un `grep` que devuelva la línea exacta.

## Diagnóstico: "mi CSS no se aplica" (orden obligatorio)

Ante un cambio de CSS que no surte efecto, NO se audita primero la cascada. El kernel `evento-app.html` emite nodos de inyección con `style="..."` INLINE (verificado: `#db-lineup` nace con `display:flex; flex-direction:column; gap:2.5rem`), y un inline SIN `!important` pierde contra una hoja CON `!important` pero GANA contra una hoja SIN el.

Orden obligatorio:

1. `grep -n 'id="<nodo>"' evento-app.html` para ver el `style=` inline.
2. Declarar en el silo con `!important` toda propiedad que el kernel fije inline.
3. Solo después, auditar cascada y orden de bloques.
