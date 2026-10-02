---
doc: E24 (ERRORES_HISTORICOS.md §24)
version: v1.8.0-STABLE (heredada)
fecha: 2026-10-01
origen: ERRORES_HISTORICOS.md L324-330 (AMPLIACION/_backups/ERRORES_HISTORICOS.md.2026-10-01.bak)
version_previa: ERRORES_HISTORICOS.md v1.8.0-STABLE
relacionados: [../ERRORES_HISTORICOS.md, ../INDEX.md]
estado: vigente
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [ERRORES_HISTORICOS.md](../ERRORES_HISTORICOS.md) §24 · [INDEX](../INDEX.md). Texto original íntegro debajo (L324-330 del original).

## 24. Guardian que Falla por el Valor Correcto: el primer smoke anclo `TICKET_PLACA_Y = 748` como assert absoluto y quedo en rojo cuando la geometria se corrigio a 732 (2026-09-30 - cierre documental ADR-064)

### Un control armado contra el cambio correcto es peor que no tener control
* **Problema:** el primer `scripts/smoke_ticket_diseno.js` hardcodeo `TICKET_PLACA_Y = 748` como assert absoluto de posicion. Cuando la geometria se ajusto legitimamente (748 -> **732**, para que la placa dejara de salirse 4 px del marco y de morder la fecha), el smoke quedo **en rojo por el valor correcto**: el control reporto como fallo el cambio que precisamente venia a corregir un defecto visual. Un guardian armado contra el cambio correcto es **peor que no tener guardian**: bloquea la correccion valida y ensena a ignorar la senal.
* **Causa raiz:** el guard verificaba un **detalle de implementacion** (la coordenada) en vez del **invariante** de diseno (la placa centrada en el marco, el QR centrado en la placa, la placa sin invadir la banda de la fecha). Los numeros absolutos congelan la geometria actual y se vuelven obsoletos en cada ajuste legitimo.
* **Blindaje / leccion:** (1) **los guards deben expresar INVARIANTES, no coordenadas**: se introdujo la primitiva `margins(inner, outer)` (margenes por eje) y los asserts pasaron a "placa centrada en el marco", "QR centrado en la placa", "la placa no invade la banda de la fecha". (2) **Probar el guard con mutaciones**: un guard que nunca falla no prueba nada; se valido con casos de mutacion en sandbox (original intacto). (3) Separar los guards **por eje** (X e Y independientes) para que un error en un eje no enmascare al otro.
* **Verificacion (2026-09-30):** smoke reescrito a invariantes -> **182 asserts, 0 FAIL, exit 0**. Pruebas de mutacion (en sandbox, original intacto): placa a 748 -> **8 FAIL**; QR a 780 -> **6 FAIL**; placa X a 280 -> **7 FAIL**. Guards independientes por eje. Registrado en `DECISIONS.md` ADR-064 (ANEXO punto 6), `TASKS.md` TSK-082 y `NEXT.md` hito -30.
