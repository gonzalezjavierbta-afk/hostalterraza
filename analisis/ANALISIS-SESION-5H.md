# Análisis de Sesión — Últimas 5 Horas (2026-09-07, 11:02 AM – 4:02 PM)

> Fuente de datos: base local de opencode (`~/.local/share/opencode/opencode.db`, tablas `session` / `message` / `part`).
> Proyecto: Sistema QR Hostal Terraza. 12 sesiones activas, 868 tool calls, 99% completados (8 errores, 1 en curso).

---

## 1. Tipo de tareas y tiempo consumido

| Tarea | Tipo | Modelo | Duración | Costo |
|---|---|---|---|---|
| Unificar comunidad / viajeros / perfil + quitar admin | Refactor mayor | mimo-v2.5-pro | **155 min** | $0.07 |
| Sesión dev sin título (1:43–2:56 PM) | Desarrollo | deepseek-v4-pro | **73 min** | $0.39 |
| Extraer eventos de Instagram Bogotá | Scraping / extracción | deepseek-v4-pro | 46 min | **$1.56** |
| Plan Go: optimizar cuota con agentes | Plan / estrategia | mimo-v2.5-pro | 32 min | $0.12 |
| Ingreso directorio Sibundoy, Putumayo | Plan / investigación | mimo-v2.5-pro | 29 min | $0.14 |
| Optimizar carga `registroaforo.html` | Optimización de rendimiento | deepseek-v4-flash | 19 min | $0.12 |
| Opciones landing + formulario al crear evento | Desarrollo | deepseek-v4-pro | 15 min | $0.39 |
| 3× sub-agentes `explore` | Exploración | mimo-v2.5-pro | 5 min | $0.10 |
| 2× pruebas en modo plan | Plan | nemotron-free | 5 min | $0 |

**Lectura:** ~85% del tiempo fue desarrollo/refactor. La sesión "Unificar comunidad" consumió la mitad de la ventana de 5 horas.

---

## 2. Lo más repetitivo (herramientas)

| Herramienta | Llamadas | % del total |
|---|---|---|
| `read` | 307 | 35.4% |
| `bash` | 222 | 25.6% |
| `edit` | 93 | 10.7% |
| `grep` | 63 | 7.3% |
| `write` | 50 | 5.8% |
| `glob` | 48 | 5.5% |
| `todowrite` | 30 | 3.5% |
| `question` | 22 | 2.5% |
| `websearch` | 12 | 1.4% |
| `webfetch` | 9 | 1.0% |
| `task` (sub-agentes) | 7 | 0.8% |
| `skill` | 5 | 0.6% |

**Hallazgo clave:** la exploración manual (`read` + `glob` + `grep` + `websearch` + `webfetch`) suma **439 llamadas ≈ 50.6%**. La sesión "Unificar comunidad" hizo **108 reads + 134 bash** pese a haber invocado 4 sub-agentes. Patrón detectado: el agente principal absorbe la exploración en su contexto en lugar de delegarla.

---

## 3. IAs usadas, costo y porcentaje

| Modelo | Sesiones | Costo | % del costo | Tokens in |
|---|---|---|---|---|
| `deepseek-v4-pro` | 3 | $2.334 | **81.1%** | 2.07M |
| `mimo-v2.5-pro` | 6 | $0.426 | 14.8% | 2.84M |
| `deepseek-v4-flash` | 1 | $0.118 | 4.1% | 172K |
| `nemotron-3.5-lightning-free` | 2 | $0.000 | 0% | 50K |

**Total: $2.88 en 5 h, 5.13M tokens de entrada.**

`deepseek-v4-pro` (variante de razonamiento "high") concentra el gasto: la tarea "Extraer eventos de Instagram Bogotá" quemó **1.7M tokens in y $1.56** en 46 min.

---

## 4. Uso de agentes, sub-agentes y skills

- **Agentes principales:** `build` (7 sesiones), `plan` (3), `explore` (3).
- **Sub-agentes:** solo `explore` (7 llamadas `task`, 100% del total).
  - Costo de sub-agentes explore: $0.097 (mimo-v2.5-pro).
- **Ninguna** llamada a `js-silo-dev`, `frontend-tpl`, `qa-gold`, `sql-migrations`, `sql-security`, `architect-review` ni `exp-pickle`, pese a estar definidos en la matriz de `AGENTS.md`.
- **Skills usados:** `create-dynamic-page`, `research-destination`, `customize-opencode`, `brainstorming` (5 usos, todos en sesiones de plan).
- **Delegación subutilizada:** 7 de 868 tool calls (0.8%). El Protocolo de Delegación existe pero no se aplicó en el trabajo de desarrollo real.

---

## 5. Cómo optimizar el flujo de trabajo

1. **Enrutar por costo** — Usar `deepseek-v4-flash` (o modelos free) para desarrollo rutinario y reservar `deepseek-v4-pro` solo para razonamiento complejo. Tres sesiones "pro" representaron el 81% del gasto.
2. **Delegar la exploración** — Los `read`/`glob`/`grep` (~50%) deben ir al sub-agente `explore`: contexto compacto, fuera del modelo caro, y se puede reanudar con `task_id`.
3. **Controlar el bloat de contexto** — 1.7M tokens in en una sola tarea = inflación evitable. Acotar archivos leídos (offsets/limits) y reutilizar sesiones de sub-agente.
4. **Agrupar comandos `bash`** — 222 llamadas sueltas; los comandos independientes pueden emitirse en paralelo en una sola llamada.
5. **Aplicar la matriz de enrutamiento de `AGENTS.md`** — JS → `js-silo-dev`, CSS → `frontend-tpl`, QA → `qa-gold`, SQL → `sql-migrations`/`sql-security`. Hoy todo cayó en `build`.

---

## 6. ¿Modelos gratuitos (Big Pickle) en el workflow?

**Sí, y ya están configurados.** `.opencode/agent/exp-pickle.md` define el agente experimental con el modelo `opencode/big-pickle` ("stealth model gratuito por tiempo limitado", temperatura 0.3), como paralelo de `js-silo-dev`.

**Recomendaciones de uso:**

- **Sí usarlo** para tareas JS rutinarias y de validación de calidad, como paralelo de `js-silo-dev` (que ya apunta a `opencode/deepseek-v4-flash-free`).
- **Respetar sus límites documentados** (issue GitHub #28141): errores 400 intermitentes y rate limits severos. Algunos reportes indican que debajo corre MiMo-v2.5.
- **NO usar para seguridad crítica** (datos de inscritos, políticas RLS). El propio agente lo prohíbe en sus reglas.
- **Modelos free ya probados en el entorno:** `nemotron-3.5-lightning-free` (sesiones de plan, $0) y `deepseek-v4-flash-free` (asignado a `js-silo-dev`).

**Acción sugerida:** activar `exp-pickle` dentro del Protocolo de Delegación para tareas de bajo riesgo y comparar su estabilidad contra `deepseek-v4-flash-free` antes de escalarlo.

---

### Notas metodológicas

- Ventana: 5 horas previas al análisis (time_created o time_updated dentro de la ventana).
- `cost` y tokens provienen de la tabla `session` de opencode (acumulados por sesión, incluidas las sub-sesiones de sub-agentes).
- Los 8 errores de tool calls corresponden a comandos fallidos puntuales; 1 llamada quedó en estado `running`.
- La sesión "Unificar comunidad" inició ~8:57 AM (antes de la ventana) pero se actualizó dentro de ella; se incluye con su duración completa para contexto.