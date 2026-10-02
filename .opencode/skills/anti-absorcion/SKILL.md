---
name: anti-absorcion
description: Reglas anti-absorcion (ADR-031) y KPIs de delegacion del orquestador. Cargar al planificar una sesion con subagentes.
---

# Reglas anti-absorción (ADR-031)

Cierran el hueco detectado el 2026-09-14: la regla transversal "Participante" del `AGENTS.md` original y `free-build.md` NO prohíben al agente principal hacer él mismo el trabajo (read/grep/glob/edit directos), lo que causa sesiones de absorción (el principal hace el trabajo del subagente). Aplican al agente principal y a los orquestadores (`@free-build`, `@build`, `@plan`, `@free-plan` y cualquier agente que coordine subagentes):

1. **Delegación obligatoria antes de tocar:** toda implementación compleja se delega al especialista único del dominio; en ruta FREE el primario free asume el trabajo mecánico ANTES de que el principal toque el archivo. **PROHIBIDO** que el primario abra con `read`/`grep`/`glob` el archivo que acaba de delegar, ni durante el trabajo del subagente ni después: ni para "ver cómo está", ni para "confirmar", ni para "revisar rápido". La verificación es el **script o el smoke**, nunca la relectura. Ver "Blindaje de la raíz".
2. **Regla de No-Duplicidad (reforzada):** el principal no duplica trabajo ya delegado. Si una tarea fue asignada a un subagente, el principal no la reimplementa, no la "mejora" ni la rehace después. Si ya recibiste `STATUS: ok` o `STATUS: partial` de un subagente, **NO re-derives su resultado: consúmelo** (un `partial` se cierra con el paso siguiente que devuelve el subagente, no con una re-derivación en la raíz).
3. **Prohibido resolver lo delegado:** el principal tiene prohibido usar `read`/`grep`/`glob`/`webfetch`/`websearch` para resolver lo que ya delegó — su contexto es para orquestar, consolidar y decidir, no para operar.
4. **Verificación obligatoria antes de declarar completo:** ninguna tarea se da por "completa" sin el Escudo GOLD (`node --check`, ASCII-safety, balance de divs) o los smokes del proyecto (`npm run test` o smokes específicos) ejecutados sobre el archivo REAL (ADR-006).
5. **Respeto del Escudo GOLD:** en todo archivo de `api/*.js`, `admin.html`, `pagina-destino.js` o `index.html` entregado: sintaxis limpia (`node --check`), ASCII-safety (cero bytes > 127, cero dobles escapes, cero backticks en serverless) y balance de `<div>` en 0.
6. **Cierre con preguntas:** toda sesión de implementación cierra con las preguntas necesarias para completar la tarea de la mejor forma posible — nunca con afirmación de "todo listo" sin evidencia de verificación.
7. **KPIs de delegación medibles (target):** ratio de delegación ≥ 50% en sesiones de implementación; absorciones → 0. Baseline real del mes (2026-09-07): 12081 calls, 92 task (0.76%), 5931 exploración (49.1%), 2126 delegadas, ratio 35.8%, 20 sesiones de absorción de 151. Suma de 5 logs simples: 18784 calls, 158 task (0.84%), ratio 38.6%, 43 sesiones de absorción.
8. **Medidas anti-absorción cuando el principal supera el umbral:** si el contador de llamadas del principal supera **20-25 llamadas de herramienta directa** (read/grep/glob/edit/webfetch) en una sesión donde existan tareas delegables sin delegar, el principal DEBE detenerse, re-delegar las tareas pendientes y no continuar operando en su contexto.
9. **Auditoría periódica de KPIs:** `@explore` audita los KPIs de delegación con `scripts/usage_report.js` (`--summary`, `--sessions`, `--tree`, `--since`) y reporta a `@plan`/`@free-plan`; el resultado se registra en `NEXT.md` como parte del ciclo documental (AI-DOS Cap. 9.9). Los `.md` preexistentes de `logs/uso/` (último: 2026-09-07) son de un pipeline viejo que el script nuevo NO produce: quedan como LEGADO y dejan de ser la fuente de la auditoría.
10. **Handoff compacto:** el principal exige el contrato de retorno de cada subagente (máximo ~600 tokens: STATUS, ARCHIVOS con `ruta:rango`, VERIFICACION con comando y pass/fail N/N, BLOQUEADORES, SIGUIENTE) y **no reintroduce en su contexto el detalle del subagente** (no pide archivos completos ni narrativas). Ver `eficiencia-recursos`.
11. **Watchdog y free-first:** el subagente tiene presupuesto propio de **18 turnos con corte al 70% (~turno 12)** devolviendo `STATUS: partial`; si supera **18 turnos** o **50.000 tokens/turno** se aborta y se re-planifica (nunca se re-despacha el mismo perfil). Los **25 turnos son el tope DURO del ORQUESTADOR, no del subagente**: son dos números distintos y a propósito (ver "Blindaje de la raíz"). Para lo mecánico se intenta primero FREE y se escala a PRO solo con confirmación explícita si falla, devuelve `partial`/`blocked` o no pasa la verificación. Detalle en `eficiencia-recursos` (secciones "Watchdog de subagentes" y "Free-first con escalado con gate").
12. **Cierre forzado del primario en el turno 20:** al llegar al turno 20 el primario emite resumen de estado (STATUS, ARCHIVOS, VERIFICACION, BLOQUEADORES, SIGUIENTE) y la sesión se cierra; no se estira. El corte es anterior al tope duro de 25 para dejar margen al informe de cierre medido (`node scripts/usage_report.js` + `node scripts/session_close.js`), que también consume turnos.

## Blindaje de la raíz (reglas duras — medición 2026-10-02)

La sesión del 2026-10-02 dejó el dato: la raíz consumió **52% del gasto (8,87M tokens en 126 turnos, ~66k `cache_read`/turno)** y 2 de los 7 subagentes despachados fueron en parte **re-derivados después por la propia raíz**. No fue un problema de permisos: los subagentes se invocaron bien y devolvieron informe. Fue la raíz, no el subagente:

1. **Prohibido releer lo delegado.** El primario NO abre con `read`/`grep` el archivo que acaba de delegar: ni "para ver cómo está", ni "para confirmar", ni "para revisar un segundo". La confirmación se hace con el script o el smoke; leer no verifica nada (ADR-006: la verdad es el archivo, y el subagente ya lo editó).
2. **Prohibido re-derivar.** `STATUS: ok` o `STATUS: partial` recibido = resultado consumido. No se re-deriva, no se "mejora", no se re-despacha el mismo perfil (refuerza el punto 2 y la regla anti-colgado).
3. **Cierre forzado en el turno 20.** Resumen de estado y sesión nueva. No estirar la sesión ni "ya que voy a leer el archivo, aprovecho para...".

Presupuesto del subagente (**18 turnos, corte al 70% ~turno 12 → `partial`**) y su plantilla van en `eficiencia-recursos`: "Watchdog de subagentes" y "Plantilla de brief (contrato obligatorio de todo `task`)". Cada `task` despachado incluye ese bloque; un brief sin presupuesto ni anclas verificadas se devuelve al emisor.

## Plantilla de brief (bloque obligatorio de todo `task`)

Todo `task` que despacha el orquestador incluye este bloque, textual o equivalente. Sin las 4 piezas, el subagente se queda sin pasos y consume el presupuesto sin entregar (medido el 2026-10-02: los 3 subagentes más caros corrieron 21-31 turnos y no escribieron su entrega):

1. **Presupuesto de turnos:**

    > PRESUPUESTO: N turnos. Reserva los últimos 3 para escribir tu entrega. Si lo que falta no cabe en el presupuesto, devuelve STATUS: partial con lo verificado y el paso exacto siguiente; no sigas explorando ni releyendo.

    Valor por defecto: **N = 18**. Los 3 últimos turnos son de escritura obligatoria (verificación + entrega + archivo de salida), nunca de más lectura.
2. **Anclas ya verificadas:**

    > NO abras archivos fuera de esta lista. Las rutas y rangos que te doy son reales y verificados: `<ruta:rango>`.

    El orquestador entrega `ruta:rango` (y bloques `old`/`new` cuando aplica), nunca contenido. Si un rango está desactualizado, se avisa en BLOQUEADORES en vez de explorar.
3. **Alcance cerrado:**

    > Si la tarea no cabe en este encargo, devuelve partial; NO amplies el alcance por tu cuenta.

    Ampliar el alcance sin permiso es el modo de fallo medido: el subagente "mejora" algo no pedido y muere sin entregar.
4. **Contrato de retorno compacto:** el ya existente en `eficiencia-recursos` → "Contrato de retorno de subagentes" (STATUS · ARCHIVOS `ruta:rango` · VERIFICACION comando + pass/fail N/N · BLOQUEADORES · SIGUIENTE; máx ~600 tokens). No se reescribe ni se duplica aquí: el brief solo lo invoca.

## Plantilla de brief (mínima lista para el primario)

Para despachar sin dudar, el primario copia este esqueleto y rellena `<...>`:

    task <subagente>:
      ENCARGO: <una frase con el verbo y el resultado esperado>
      PRESUPUESTO: 18 turnos. Reserva los últimos 3 para escribir tu entrega. Si lo que falta no cabe en el presupuesto, devuelve STATUS: partial con lo verificado y el paso exacto siguiente; no sigas explorando ni releyendo.
      ALCANCE: Si la tarea no cabe en este encargo, devuelve partial; NO amplies el alcance por tu cuenta.
      ANCLAS: NO abras archivos fuera de esta lista. Las rutas y rangos que te doy son reales y verificados: <ruta:rango> [, <ruta:rango> ...]
      VERIFICACION ESPERADA: <comando exacto> -> <salida esperada, N/N>
      ESCRITURA: <qué archivo(s) entregar, ruta exacta>
      RETORNO: contrato compacto de ~600 tokens (STATUS, ARCHIVOS ruta:rango, VERIFICACION comando + N/N, BLOQUEADORES, SIGUIENTE). No vuelques archivos ni diffs.

Relacionado: la skill `eficiencia-recursos` detalla las reglas anti-colgado, el contrato de retorno de subagentes, el presupuesto por fase, el watchdog, el free-first y la consolidación de fases (Mandatos 17-18), que refuerzan los puntos 8, 10, 11 y 12.
