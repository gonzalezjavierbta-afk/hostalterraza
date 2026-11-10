---
doc: ADR-090
version: v1.1-ACEPTADO
revision: 2026-11-07 por @architect-review. Dictamen APROBADO CON CAMBIOS: 2 bloqueantes (predicado real de "logs.resultado" y snapshot incompleto) y 8 hallazgos mayores. Se aplicaron los 11 cambios y se agregaron las decisiones D9-D11. Nada se borro del diseno original.
fecha: 2026-11-07
origen: Validacion offline del scanner de puerta (scanner.html) mediante PWA acotada (manifest + Service Worker), snapshot del evento en IndexedDB y outbox idempotente. Diseno de arquitectura, sin implementacion. Gate de riesgo de AGENTS.md seccion 2 (arquitectura/ADR) AUTORIZADO explicitamente por el usuario el 2026-11-07; todas las decisiones D1-D8 aprobadas en bloque ("a todo si").
version_previa: ADR-089
relacionados: [../DECISIONS.md, ../INDEX.md, ../TASKS.md, ADR-079-checkin-multi-punto-con-override-por-ticket.md, ADR-081-semantica-null-vs-vacio-y-propagacion-de-puntos-de-escaneo.md, ADR-084-contador-en-zona-horaria-de-bogota-y-cleanup-del-intervalo.md, ADR-002-reemplazo-por-cumplimiento-de-csp-qrcodejs-qr.md, ADR-006-nomenclatura-atomica-por-categorias-silos.md]
estado: ACEPTADO CON CAMBIOS APLICADOS (2026-11-07, dictamen @architect-review) - pendiente de implementacion; nada de este ADR esta aplicado en scanner.html ni en la base
estructura: detalle-v1 (2026-10-01)
nota_numeracion: Verificado el 2026-11-07: 0 archivos ADR-090* en decisiones/ (busqueda recursiva en el repo). DECISIONS.md llega a ADR-088 (fila 103) y ADR-089 tiene ficha propia sin fila en el indice, por lo que 090 es el siguiente numero libre. Cero Borrado: no se sobrescribe ninguna ficha previa.
---

> Detalle de [DECISIONS.md](../DECISIONS.md) - [INDEX](../INDEX.md).

## ADR-090: Validacion offline del scanner PWA (snapshot IndexedDB + outbox idempotente)

**Fecha:** 2026-11-07

**Autor:** @architect (diseno). Implementacion prevista: @sql-security (esquema/RLS, F1), @data-migration (migracion, F2), @admin-dev + @frontend-tpl (manifest/SW y snapshot/outbox, F3-F4), @qa-auditor (Escudo GOLD y smoke offline, F5). Cierre documental a cargo de @docs-keeper.

**Estado:** ACEPTADO CON CAMBIOS (2026-11-07, dictamen de @architect-review; los 11 hallazgos ya estan incorporados en este texto). Este documento es el contrato de diseno; "scanner.html" no se ha tocado, no existe "manifest.json" ni "sw.js", y no hay migracion escrita. Las 11 decisiones D1-D11 fueron aprobadas por el usuario el 2026-11-07; las precisiones de implementacion (indice UNIQUE parcial, migracion no transaccional, tabla canonica de "logs.resultado", cota temporal de D9) son de este ADR y no reabren el alcance aprobado.

**Presupuesto de plataforma:** 0 endpoints serverless nuevos (8/8 funciones de Vercel Hobby intactas). Todo el trabajo es cliente (SW, IndexedDB) + base de datos (Supabase, no Vercel). 0 cambios en "evento-app.html" y "index.html". 0 IDs del Contrato v112 retirados (Cero Borrado).

---

## 1. Contexto

### 1.1 Estado real de "scanner.html" (verificado, ADR-006)

| Pieza | Ubicacion | Estado |
|---|---|---|
| Tamano del archivo | "scanner.html" 1.330 lineas / 64,7 KB (HTML + CSS + JS inline) | monolitico, sin build |
| Dependencias externas | "supabase-js@2" UMD por jsDelivr (L8), "jsQR@1.4.0" (L9), Google Fonts | 3 origenes de red obligatorios en carga |
| Clave anon | hardcodeada (L234) | correcta por diseno (clave publica), no es un secreto |
| Auth de staff | token opaco "?token=", validado contra tabla "scanner_tokens" con "expira_en" (L361-375); re-chequeo cada 60 s (L448-453) | 100% dependiente de red |
| Deteccion | "startDetection" L926-967: "BarcodeDetector" nativo o "jsQR", ciclo de 250 ms | requiere "jsQR" en el cliente |
| Flujo de validacion | "processScan" L975-1086 -> "showVerify" -> "confirmEntry" L1153-1252 | update de "inscritos" (L1216) + insert en "logs" (L1222) |
| Catalogo de inscritos | "qrCache" solo en memoria (L251), llenado por "select('*')" (L487); aborta si no hay red (L485) | no persiste nada |
| Estado local persistido | solo puntos de escaneo, en "localStorage" (L293-344) | no hay snapshot del evento |
| Cola offline | "offlineQueue" en memoria (L253-288) + "localStorage" por evento ("htz_offline_queue_{eventoId}"); drena en "online" (L530-565) | encola SOLO si "isOnline === false" (L1180, L1225, L1279); sin idempotencia ni dedup; "denyEntry" nunca encola (L1309); un fallo estando online NO encola (L1216-1221) |
| PWA | sin "manifest.json", sin Service Worker (TSK-006 pendiente, "TASKS.md:109") | no instalable y no cacheable |

### 1.2 Restricciones de plataforma que condicionan la solucion

1. **SEO y motor de render son intocables.** Un Service Worker con scope raiz interceptaria "index.html" y "evento-app.html", con riesgo directo de servir HTML obsoleto a rastreadores y de romper el motor de render (ADR-006, ADR-088 de plataforma). De ahi D1.
2. **Cero build tools (ADR-001).** No hay bundler, no hay inyeccion de hash de assets en build. El versionado de cache debe resolverse con constantes en el propio "sw.js".
3. **Cero Borrado (Regla de Oro 3).** No se elimina ningun ID del Contrato v112 ni se oculta nada. Esta regla aplica al DOM del scanner y tambien al "logs" historico: la limpieza de duplicados preexistentes NO se hace en silencio.
4. **"localStorage" es inadecuado como almacen de datos de negocio:** es sincrono, cuota ~5 MB, sin transacciones ni indices, y una escritura interrumpida puede corromper el JSON de la cola. De ahi D2.

---

## 2. Problema

Con red todo funciona. Sin red (o con red intermitente en la puerta) el scanner falla en 6 puntos verificables:

| ID | Bloqueador | Evidencia (archivo real) | Efecto en puerta |
|---|---|---|---|
| B1 | "init()" exige red para autenticar | validacion contra "scanner_tokens" (L361-375) y mensaje "Token no encontrado" (L367); re-chequeo cada 60 s (L448-453) | al perder red, la sesion muere en <= 60 s aunque el token sea valido |
| B2 | El catalogo de inscritos no se persiste | "qrCache" en memoria (L251), llenado por "select('*')" (L487), aborta sin red (L485) | cualquier QR escaneado offline responde "no encontrado": 100% de falsos negativos |
| B3 | No hay capa de cache ni instalacion | sin "manifest.json" ni Service Worker ("TASKS.md:109"); dependencias en 3 origenes (L8-L9) | recargar offline deja la pagina en blanco; "jsQR" no disponible = no hay lector |
| B4 | El replay no es idempotente | "offlineQueue" L253-288, drenaje L530-565; update "inscritos" L1216 + insert "logs" L1222; sin "op_id" ni dedup | reconexion a medias duplica el contador de ingreso y el log; un reintento del navegador duplica otra vez |
| B5 | La escritura online es fragil | si el update/insert falla estando "isOnline === true", no se encola (L1216-1221, L1225); "denyEntry" nunca encola (L1309) | un check-in se pierde en silencio ("guardado" en pantalla, nada en base) |
| B6 | El token caduca en la puerta | "expira_en" (L361-375) sin alternativa local | un evento de 4 h con token de 2 h se queda sin validacion a mitad de puerta, o con token caducado y sin snapshot |

**Consecuencia operativa:** hoy la unica defensa es "que no se caiga la red", lo cual es exactamente lo que no se puede garantizar en una puerta.

---

## 3. Decision

| ID | Decision | Justificacion | Alternativa descartada |
|---|---|---|---|
| **D1** | El Service Worker cubre SOLO "/scanner.html". "sw.js" vive en la raiz; se registra con scope "/scanner.html" y, ademas, el handler "fetch" ignora todo lo que no sea esa ruta o un estatico de la allow-list. "evento-app.html" e "index.html" quedan FUERA. | Aislamiento minimo necesario: el riesgo de servir HTML obsoleto a Googlebot o al motor de render es inaceptable y no aporta nada a la puerta. Doble cinturon (scope + guard en "fetch"). | SW de scope "/" con cache de todo el sitio: indexaria HTML viejo, rompe SEO y el motor de render, y multiplica la superficie de fallo por cero beneficio. |
| **D2** | El snapshot del evento se guarda en **IndexedDB** (no en "localStorage"), con "snapshot_version" (entero de contrato) y "snapshot_fecha" (ISO de generacion). | Transaccional, con indices, sin cuota de 5 MB y sin corromperse por escrituras concurrentes; el catalogo de un evento real (cientos de inscritos) no cabe comodo en "localStorage" junto con la cola. | "localStorage" con JSON: fragil, sincrono, sin indices, sin atomicidad y con el mismo origen que la cola actual (una cuota llena tumba ambas cosas). |
| **D3** | La descarga del snapshot ocurre en "init()" cuando hay red, y ademas existe un boton manual "Preparar offline" que la fuerza antes de abrir la puerta. | "init()" da cobertura automatica; el boton da control explicito al staff, permite verificar antes de abrir y no depende de que nadie recuerde la pantalla de carga. | Solo automatico en "init()": si el snapshot falla parcialmente o el evento se edita despues, el staff no tiene forma de refrescar sin recargar; solo bajo demanda: se olvida y la puerta abre sin snapshot. |
| **D4** | Con el token caducado y sin red, se PERMITE validar contra un snapshot vigente y se registra "offline = true" en "logs". | El objetivo del scanner es controlar el acceso, no renovar un token: bloquear la puerta por un "expira_en" vencido produce perdida economica y operativa, y el snapshot ya es una autorizacion local acotada en tiempo. | Fail-closed puro (rechazar todo offline): convierte una caida de red en una puerta detenida, que es el fallo que este ADR existe para evitar. |
| **D5** | Un QR ya usado se rechaza como segundo ingreso y se registra con "resultado = 'duplicado'". | Es la unica defensa real contra el reuso de una entrada compartida, y deja traza auditable del intento en vez de un simple "no pasa". | Permitir el segundo ingreso y "corregir despues": destruye el control de acceso; o rechazar sin registrar: pierde la evidencia del intento. |
| **D6** | Idempotencia por "op_id" (UUID v4 por operacion) + indice UNIQUE parcial "(evento_id, qr_code, punto_acceso)" en "logs" (forma ejecutable en sec. 3.3, D10); el outbox drena con dedupe (un 23505 se trata como exito ya aplicado). | Un reintento de red, un doble toque o un drenaje interrumpido no pueden producir doble contador ni doble fila: la base es el juez, no el cliente. | Dedupe solo en cliente (flag "enviado" en la cola): se pierde al recargar y no protege de dos dispositivos en el mismo punto. |
| **D7** | PII en reposo: el snapshot guarda SOLO identificacion (nombre, cedula, tipo, qr_code, used, punto(s)) y **nunca** "respuestas_custom"; purga automatica al cerrarse la ventana offline o al cerrar puerta, mas opcion de cifrado evaluada por @sql-security. | Minimizacion de datos: la puerta necesita identificar y marcar, no el formulario completo (que puede traer salud, menores o datos de contacto). | Snapshot con "select('*')" como hoy (L487): arrastra todo el formulario, incluidos datos sensibles, a un dispositivo que se queda en la puerta. |
| **D8** | Cobertura: queda fuera de este ADR la app nativa, las notificaciones push y cualquier validacion offline SIN snapshot. | Mantiene el alcance verificable en una sola sesion de trabajo y evita prometer un modo offline "generico" que el modelo de datos no soporta. | "PWA completa" (push, background sync, app nativa): alcance inabarcable, sin funcion nueva en la puerta y con coste de mantenimiento permanente. |
| **D9** | Autoridad temporal offline: "min(snapshot_fecha + 12 h, evento.fecha_fin + 2 h)"; las 12 h quedan configurables por evento en el futuro. Esquema de "logs.resultado": **se mantiene el formato actual** con match "LIKE 'Ingreso%'" (no se migran valores historicos: Cero Borrado) y se agrega CHECK **solo para valores nuevos**. | La ventana no puede sobrevivir al evento (validar una entrada dias despues es un agujero) ni depender de "expira_en", que es informativo. Mantener el texto actual evita reescribir historico de auditoria y reportes. | Ventana fija de 24 h sin cota de evento, o migrar "resultado" a un enum nuevo: la primera valida fuera de contexto, la segunda rompe Cero Borrado y reescribe la traza historica. |
| **D10** | El indice UNIQUE parcial se crea en una **migracion no transaccional propia**. | "CREATE INDEX CONCURRENTLY" no puede correr dentro de una transaccion, y la migracion estandar de Supabase CLI si lo hace. | Indice dentro de la migracion transaccional (via simple documentada): funciona, pero toma lock de escritura sobre "logs" y solo es viable con trafico cero en la puerta. |
| **D11** | Pre-chequeo **obligatorio** de duplicados historicos en "logs" ANTES de crear el indice: si existen repetidos se listan (evento, qr, punto, n) y Direccion decide caso por caso. Prohibido el borrado silencioso. Es **bloqueante de F1**. | Sin el pre-chequeo el indice puede fallar en produccion o, peor, alguien "limpia" filas para que pase. La decision sobre datos historicos no la toma un script. | Limpiar duplicados automaticamente o crear el indice tolerando conflictos: la primera viola Cero Borrado, la segunda destruye evidencia de auditoria. |

### 3.1 Precisiones de D7 y de la purga

- El snapshot NO incluye "respuestas_custom", correo, telefono ni whatsapp. **Columnas definitivas del snapshot** (las unicas que se descargan): "id, evento_id, evento_nombre, nombre, cedula, tipo, qr_code, used, hora_ingreso, fecha_ingreso, puntos_acceso". Se obtiene con esas columnas explicitas, nunca con "select('*')" (L487). El campo real de marca de ingreso es **"used"**, no "usado": todo el codigo nuevo usa "used". Esto reduce el peso de la descarga y cierra el bloqueante del dictamen.
- **Purga** se dispara por el primero de estos eventos: (a) cierre explicito de puerta desde la UI; (b) vencimiento de la cota offline de sec. 3.6 ("snapshot_fecha + VENTANA_OFFLINE_MAX", acotada ademas por "evento.fecha_fin + 2 h"); (c) inicio de sesion con otro evento (se purga el snapshot anterior); (d) "CACHE_VERSION" nuevo que invalide el contrato del snapshot. La purga borra "snapshots" y "meta.sesion"; **nunca** borra "outbox" con operaciones pendientes. Ancla unica de tiempo: "snapshot_fecha"; "expira_en" no dispara nada.
- **Conciliacion D4/D7 (ancla unica):** D4 autoriza validar con token caducado y D7 exige purgar. La autoridad es UNA sola: "snapshot_fecha + VENTANA_OFFLINE_MAX" con el techo de "evento.fecha_fin + 2 h" (sec. 3.6). "expira_en" es **solo informativo en la UI** y no participa ni en la decision ni en la purga (la version anterior de este bullet citaba "token.expira_en + ..." en un lado y "snapshot_fecha + ..." en otro: se corrige la contradiccion de ancla). Si "@sql-security" exige cifrado, la clave se deriva del token de la sesion (HKDF) para que el snapshot sea ilegible sin el, y el borrado sigue siendo por eliminacion del registro.
- **Limite declarado (D9):** la revocacion de un token (o de un punto de acceso) **NO se propaga offline**: un token revocado en base sigue validando en un dispositivo con snapshot vigente hasta que vence la cota o hasta que hay red. Se acepta y se avisa en la UI de "Preparar offline".

### 3.2 Modelo de almacenamiento (diseno, NO ejecutable)

Base IndexedDB: "htz-scanner-offline", version 1.

| Store | keyPath | Indices | Contenido |
|---|---|---|---|
| "snapshots" | "evento_id" | "por_fecha" ("snapshot_fecha") | "{ evento_id, snapshot_version, snapshot_fecha, evento_nombre, ventana_hasta (min(snapshot_fecha + 12 h, evento.fecha_fin + 2 h)), evento:{nombre,fecha,hora,lugar,fecha_fin,puntos_acceso}, token:{expira_en (solo informativo)}, inscritos:[{id,evento_id,evento_nombre,nombre,cedula,tipo,qr_code,used,hora_ingreso,fecha_ingreso,puntos_acceso}], totales:{inscritos,checkins}, checksum }" |
| "outbox" | "op_id" | "por_evento" ("evento_id","estado") | "{ op_id, evento_id, qr_code, punto_acceso, tipo:'entrada'|'rechazo', resultado, offline:true, ts_cliente, intentos, ultimo_error }" |
| "meta" | "k" | - | "{ k:'sesion', evento_id, autorizada_en, expira_en, ventana_offline_max }" |

"snapshot_version" es un entero de CONTRATO (formato del snapshot, arranca en 1), distinto de "CACHE_VERSION" del SW (version de deploy). Un snapshot con "snapshot_version" desconocida no se usa: se descarta y se pide red.

### 3.3 Idempotencia en base (contrato para F1/F2)

- "logs.op_id text" (nullable: las filas historicas no tienen op_id).
- "logs.offline boolean DEFAULT false".
- Indice de guarda, **UNIQUE parcial** (D6 + D10): si se creara UNIQUE sobre todas las filas, las propias filas de auditoria ("Denegado", "duplicado") violarian el indice entre si y harian imposible registrar el segundo intento. La forma ejecutable, con el predicado REAL de los valores canonicos de sec. 3.7:

    CREATE UNIQUE INDEX uv_logs_entrada_idem
      ON public.logs (evento_id, qr_code, COALESCE(punto_acceso, ''))
      WHERE resultado LIKE 'Ingreso%' AND qr_code IS NOT NULL;

- Se crea en una **migracion no transaccional propia** (D10): "CREATE INDEX CONCURRENTLY" no puede ejecutarse dentro de una transaccion y la migracion estandar de Supabase CLI corre dentro de una. Via simple aceptable: "CREATE INDEX" (sin CONCURRENTLY) dentro de la migracion transaccional, documentando que toma un lock de escritura sobre "logs" y solo es viable con trafico cero en la puerta.
- El "COALESCE" se justifica por el comportamiento **NULL-distinto** de un indice UNIQUE: dos filas con "punto_acceso" NULL no colisionan entre si, de modo que sin "COALESCE" el mismo QR podria entrar dos veces por el hueco del NULL. NO se apoya en ADR-081: ese ADR regula "inscritos.puntos_acceso" (jsonb) y la semantica "NULL" vs "[]", no "logs.punto_acceso".
- Un insert que devuelve 23505 significa "el log ya estaba aplicado": se drena **SOLO la operacion de log** del outbox. El "update" de "inscritos.used" se aplica igual (es idempotente: el valor ya debe ser true) y el contador no suma otra vez. "qrCache" se marca como usado **solo despues del exito de la escritura**, nunca antes, para que un fallo no deje el catalogo local mintiendo.
- **Orden write-ahead (invierte el actual L1216/L1222):** primero el insert del log, luego el update de "inscritos.used"/contador. Si el insert es 23505, el update de "used" igual procede, pero el contador no suma otra vez.

### 3.4 Estrategia de cache del Service Worker

| Recurso | Estrategia | Regla dura |
|---|---|---|
| "/scanner.html" (navegacion) | **network-first** con timeout 3 s y fallback a cache | un deploy nuevo se sirve fresco cuando hay red; sin red se usa la ultima copia buena |
| Estaticos locales del scanner (iconos, "manifest.webmanifest") | **cache-first** con revalidacion en segundo plano (stale-while-revalidate) | nunca bloquean el arranque |
| CDN "supabase-js", "jsQR" | **cache-first** con **version exacta pinneada** en "scanner.html" (no "@2" flotante) | una URL flotante deja el cache indeterminista entre deploys |
| Google Fonts | cache-first, no bloqueante | si no esta en cache, cae al stack del sistema; jamas bloquea el render |
| Cualquier POST / RPC de Supabase | **no se cachea nunca** | solo se interceptan GET de assets |

"CACHE_VERSION" es una constante en "sw.js", incrementada en cada deploy que cambie "scanner.html" o los assets: en "install" se precachea con nombre "htz-scanner-{CACHE_VERSION}", en "activate" se borran las caches "htz-scanner-*" con version anterior. Un cache obsoleto equivale a validar con reglas viejas (contadores, duplicados, puntos), que es el fallo mas caro de este diseno; por eso la navegacion es network-first y no cache-first.

### 3.5 Reglas de encolado (cierra B5)

1. Se encola cuando "isOnline === false" **y tambien** cuando la escritura falla por red estando "isOnline === true" (timeout, TypeError de fetch, 5xx). Solo se descarta la operacion si el error es de negocio (4xx deterministico) y se informa en pantalla.
2. "denyEntry" (L1309) tambien encola: el rechazo es evidencia de auditoria y hoy se pierde.
3. El drenaje mantiene el orden de "ts_cliente" por evento y es serializado (una operacion a la vez) para no saturar la RLS ni producir carreras de contador.
4. "updateCounter" no escribe el contador desde la red mientras haya outbox pendiente: usa el valor optimista local y reconcilia al drenar (el valor final lo impone el conteo real de "logs", no la suma ciega).
5. La cola nunca se vacia por completo: si quedan pendientes, se conserva y se muestra "N pendientes" en la UI.

### 3.6 Autoridad temporal offline (D9)

La validacion local solo es valida mientras se cumpla:

     ahora <= min( snapshot_fecha + VENTANA_OFFLINE_MAX , evento.fecha_fin + 2 h )

- "VENTANA_OFFLINE_MAX" = 12 h por defecto, constante del scanner; configurable por evento en una fase futura (no en este ADR).
- "evento.fecha_fin" se interpreta en hora de Bogota (ADR-084). Si el evento no declara hora de fin, se usa el fin del dia del evento + 2 h, y si tampoco hay fecha, la cota queda solo en las 12 h.
- Fuera de la cota el scanner **no valida offline**: exige red. El fail-closed esta en el limite, no al inicio de la sesion.
- "expira_en" del token es **solo informativo en la UI** ("token vence en X"): no autoriza, no bloquea y no dispara purga.
- **Limite declarado:** la revocacion de un token o de un punto **no se propaga offline**. Un token revocado sigue validando en un dispositivo con snapshot vigente hasta que vence la cota o hasta que hay red. Riesgo aceptado, visible en la UI de "Preparar offline".

### 3.7 Tabla canonica de "logs.resultado" (D9, cierra el bloqueante 1)

Valores reales hoy en "scanner.html": "Ingreso" (L1211), "Ingreso \u00B7 <punto>" (L1168), "Denegado" (L1309). Este ADR agrega "duplicado" (D5). Tabla canonica:

| Valor | Origen | Cuenta como ingreso | Indice UNIQUE parcial |
|---|---|---|---|
| "Ingreso" | scanner L1211 | si | aplica |
| "Ingreso \u00B7 <punto>" | scanner L1168 | si | aplica |
| "Denegado" | scanner L1309 | no | excluido |
| "duplicado" | offline/outbox (D5) | no (auditoria) | excluido |

Reglas:

1. El match de ingreso es **"LIKE 'Ingreso%'"** (prefijo), porque el punto de acceso viaja concatenado en el texto. Un "= 'Ingreso'" solo cubriria la mitad de las filas.
2. Casing exacto: "Ingreso" con mayuscula inicial y, cuando aplica, "Ingreso" + espacio + separador + espacio + nombre del punto. El separador es U+00B7 (punto medio, no ASCII): en JavaScript se escribe con su escape unicode y en SQL con una cadena "E" que lo contenga. No se cambia el formato existente: el codigo nuevo debe reproducir el texto byte a byte.
3. **NO se migran valores historicos** (Cero Borrado). El CHECK de valores nuevos se evalua como "NOT VALID" para no fallar por filas viejas.
4. **Filtro de reingreso (undo):** "cargarCache" (scanner.html L492-498) y el chequeo online (L1056-1057) deben filtrar ".like('resultado','Ingreso%')". Hoy un "duplicado" o un "Denegado" podria leerse como ingreso y bloquear un QR que fue liberado tras un undo.
5. **Borrado del drenaje:** scanner.html L547 borra con ".eq('resultado','Ingreso')". Ese filtro solo alcanza las filas exactas; un "duplicado" **no debe entrar en ese borrado sin decision explicita**: es auditoria, no cola. El filtro de entradas se amplia a "LIKE 'Ingreso%'" y el duplicado se conserva salvo decision de F1.

### 3.8 Pre-chequeo obligatorio de duplicados (D11, bloqueante de F1)

Query de solo lectura, sin borrar nada:

    SELECT evento_id, qr_code, COALESCE(punto_acceso,'') AS punto, count(*) AS n
      FROM public.logs
     WHERE resultado LIKE 'Ingreso%' AND qr_code IS NOT NULL
     GROUP BY 1, 2, 3
    HAVING count(*) > 1
     ORDER BY n DESC;

- 0 filas: F2 puede crear el indice.
- 1 o mas filas: se entrega la lista (evento, qr, punto, n) y **Direccion decide caso por caso**. Prohibido borrar, fusionar o "normalizar" en silencio; prohibido tocar el historico sin decision registrada.
- Sin este reporte **no se crea el indice**: es bloqueante de F1, y F2 no arranca sin el visto bueno.

---

## 4. Consecuencias

### 4.1 Positivas

- La puerta funciona con red intermitente o caida total, dentro de la ventana offline declarada.
- Un reintento, un doble toque o un drenaje partido no duplica ingresos ni filas de auditoria (garantia en base, no en cliente).
- El check-in ya no se pierde en silencio: todo fallo de red termina encolado y visible.
- Se abre la puerta a TSK-006a (instalable) sin tocar "index.html" ni "evento-app.html": SEO y motor de render quedan intactos.
- Menos datos sensibles en el dispositivo (sin "respuestas_custom").

### 4.2 Negativas / costes asumidos

- Se agrega estado local persistente en el dispositivo: aparece el deber de purgarlo y de asumir su robo/perdida (mitigado por D7 y la ventana de 12 h).
- "scanner.html" crece en responsabilidades (snapshot, outbox, UI de preparacion y de pendientes); el archivo ya es monolitico y este ADR lo hace mas grande. Se acepta para no introducir build tools (ADR-001).
- Dependencia de una migracion de base (columna + indice) para que la idempotencia sea real: hasta F2 aplicado, el cliente es solo "mejor esfuerzo".
- Un "CACHE_VERSION" mal incrementado sirve reglas viejas: se mitiga con network-first y con el chequeo de "snapshot_version".
- El icono instalado no puede llevar el token en la URL: requiere decision de UX (ver sec. 10).
- La revocacion de un token no se propaga offline (D9/R10): la ventana de 12 h es tambien ventana de gracia para un token revocado, aceptada como riesgo residual.

---

## 5. Plan por fases

| Fase | Agente | Tier / gate | Entregable | Criterio de salida |
|---|---|---|---|---|
| **F1** | @sql-security | PAGO; gate de riesgo sec. 2 (esquema/RLS) exigido | Verificacion de columnas reales de "logs" ("resultado", "punto_acceso", "qr_code"), **tabla canonica de "logs.resultado" + CHECK para valores nuevos** (D9/sec. 3.7), diseno DDL de "op_id"/"offline", **pre-chequeo de duplicados historicos (D11, bloqueante)**, auditoria de la policy de INSERT anon para replay offline, dictamen sobre cifrado del snapshot | DDL idempotente propuesto ("IF NOT EXISTS", bloques "DO"); tabla canonica fijada ("Ingreso", "Ingreso \u00B7 <punto>", "Denegado", "duplicado") con CHECK (evaluar "NOT VALID" por filas historicas); reporte de pre-chequeo con lista (evento, qr, punto, n); policy evaluada; 0 cambios aplicados aun |
| **F2** | @data-migration | PAGO; gate de riesgo sec. 2 (migraciones) exigido | "migrations/adr090_<slug>.sql" (columnas "op_id"/"offline") + **migracion no transaccional propia para el indice** (D10), aplicadas | columnas "op_id" y "offline" existen; indice "uv_logs_entrada_idem" con predicado "LIKE 'Ingreso%'" existe; pre-chequeo de D11 con 0 filas o decision de Direccion registrada; "NOTIFY pgrst, 'reload schema'" |
| **F3** | @admin-dev + @frontend-tpl | heredado (ADR-069); "admin-dev" es dominio de riesgo: gate sec. 2 | "manifest.webmanifest", "sw.js" en raiz, iconos, registro con scope "/scanner.html", boton "Preparar offline" (solo UI) | SW activo con scope exacto; "/index.html" y "/evento-app.html" sin controlador; caches "htz-scanner-{CACHE_VERSION}" creadas |
| **F4** | @admin-dev | heredado (ADR-069); gate sec. 2 | Reescritura de "init()" (token local + snapshot), "processScan"/"confirmEntry"/"denyEntry"/drenaje con "op_id", "updateCounter" con guard offline, purga | flujo offline completo, sin doble contador, sin perdida de rechazos |
| **F5** | @qa-auditor | FREE | Escudo GOLD (node --check de los bloques inline, ASCII-safety, balance de divs) + "scripts/smoke_offline_scanner.js" + regresion de los smoke existentes | ver sec. 7 y 0 regresiones |

**Dependencias:** F3 puede ejecutarse en paralelo con F1/F2 (no toca datos); F4 depende de F1 (contrato de columnas) y de F3 (SW para la recarga offline); F5 depende de F3 y F4.

---

## 6. Riesgos

| ID | Riesgo | Prob. | Impacto | Mitigacion |
|---|---|---|---|---|
| R1 | Duplicados historicos en "logs" (bajo "LIKE 'Ingreso%'") impiden crear el indice UNIQUE, y Cero Borrado prohibe borrarlos en silencio | media | alto (bloquea F1 y F2) | D11: pre-chequeo obligatorio en F1 con lista (evento, qr, punto, n); Direccion decide caso por caso. F2 no arranca sin ese reporte. No se borra nada automaticamente |
| R2 | Dos dispositivos en el mismo punto validan el mismo QR casi a la vez | media | medio | el indice UNIQUE decide; el segundo recibe 23505 y se muestra como duplicado |
| R3 | Snapshot obsoleto (evento editado despues de "Preparar offline") | media | medio | network-first en la navegacion, "snapshot_fecha" visible en la UI, boton manual, y aviso si el snapshot supera N horas |
| R4 | "CACHE_VERSION" sin incrementar sirve reglas viejas | media | alto | checklist de deploy que incluye subir "CACHE_VERSION"; network-first para el documento |
| R5 | Perdida o robo del dispositivo con snapshot | baja | alto | D7 (sin "respuestas_custom"), ventana de 12 h, purga al cerrar puerta, cifrado evaluado en F1 |
| R6 | El replay offline choca con RLS (token vencido, policy restrictiva) | media | alto | F1 audita la policy de INSERT; si RLS bloquea, la operacion queda en "outbox" con "ultimo_error" visible (nunca se descarta) |
| R7 | Cuota de IndexedDB/cache agotada por snapshot grande | baja | medio | columnas explicitas (no "select('*')"), purga, y limite declarado de inscritos por evento para el modo offline |
| R8 | "crypto.randomUUID()" no disponible en un WebView antiguo | baja | bajo | fallback a UUID v4 generado con "crypto.getRandomValues" |
| R9 | Prueba offline "de escritorio" no representa el movil real (Safari iOS) | media | medio | smoke en un movil real antes de desplegar; documentar limite conocido |
| R10 | Revocacion de token o de punto NO se propaga offline (limite de D9) | media | alto | cota temporal acotada (12 h y fin del evento + 2 h), aviso explicito en la UI de "Preparar offline", y revocacion efectiva en cuanto hay red. Riesgo residual aceptado |
| R11 | "CREATE INDEX CONCURRENTLY" interrumpido deja un indice INVALID | baja | medio | D10: migracion no transaccional propia, verificacion de "pg_index.indisvalid" tras la ejecucion y "DROP INDEX" del invalido antes de reintentar |

---

## 7. Criterios de aceptacion verificables

| ID | Criterio | Como se verifica |
|---|---|---|
| V1 | "sw.js" se registra con scope "/scanner.html" y queda "activated" | DevTools > Application > Service Workers: scope exacto "/scanner.html", estado activated |
| V2 | "index.html" y "evento-app.html" NO estan controlados | en esas rutas, "await navigator.serviceWorker.getRegistrations()" no devuelve ningun registro cuyo scope cubra la ruta y "navigator.serviceWorker.controller === null" en esa pestana |
| V3 | "/scanner.html" carga offline | cargar online, "Preparar offline", DevTools > Network > Offline, recargar: la pagina renderiza y "jsQR" esta disponible |
| V4 | El catalogo offline responde bien | con Offline activo, escanear un QR de un inscrito real: aprueba, y NO aparece "no encontrado" |
| V5 | Token caducado + offline valida y marca "offline" | forzar "expira_en" vencido en el snapshot (la sesion sigue dentro de la cota de D9), Offline activo, escanear: pasa y el log queda con "offline = true"; ademas, fuera de la cota de D9 el scanner exige red |
| V6 | QR duplicado se rechaza y se audita | escanear dos veces el mismo QR: segundo intento muestra "duplicado"; existe fila con "resultado='duplicado'" |
| V7 | Idempotencia real | confirmar una entrada, cortar la red a mitad del envio, reconectar: exactamente 1 fila con "resultado LIKE 'Ingreso%'" para ese (evento, qr, punto) y contador +1 (no +2); el juez es el indice parcial, no el cliente |
| V8 | Sin perdida de escritura online | simular fallo de red con "isOnline === true" (DevTools > Network > Offline justo al confirmar): la operacion queda en "outbox" y drena al volver la red |
| V9 | "denyEntry" offline encola | rechazar con Offline activo: aparece en "outbox" y drena con su "resultado" |
| V10 | Purga | "cerrar puerta": "snapshots" y "meta.sesion" vacios; "outbox" con pendientes intacto |
| V11 | Cache versionada | cambiar "CACHE_VERSION", recargar: aparece la cache nueva y se borra la anterior; la navegacion sirve el HTML nuevo con red |
| V12 | Escudo GOLD | script fijo "node scripts/gold_shield_offline.js": (1) extrae cada bloque "<script>" inline de "scanner.html" a .tmp y corre "node --check" sobre cada archivo extraido; (2) cuenta caracteres no-ASCII nuevos; (3) compara el balance de "<div>" contra "git show HEAD:scanner.html"; (4) corre los smoke existentes. Todo PASS o la fase no cierra |

**No-negociable:** V3, V4, V6 y V7 son la definicion de "offline funciona"; sin los cuatro, la fase no se cierra.

---

## 8. Alternativas descartadas (global)

1. **SW de scope raiz con precache del sitio completo:** beneficio nulo para la puerta, riesgo directo de SEO y de motor de render.
2. **"localStorage" como almacen del snapshot:** sin transacciones ni indices, cuota insuficiente y corrupcion posible; ademas comparte origen con la cola actual.
3. **Caching sin Service Worker** (por ejemplo "fetch" manual a un blob): no resuelve la recarga de la pagina offline; el documento seguiria sin estar disponible.
4. **Dedupe solo en cliente:** no sobrevive a recargas ni a dos dispositivos; la base debe ser el juez.
5. **Sincronizacion con CRDT / resolucion de conflictos generica:** complejidad desproporcionada para una operacion append-only con clave natural (evento, QR, punto).
6. **Persistir el token de staff para saltar la expiracion:** convierte un token caducable en una credencial permanente en el dispositivo; prohibido.
7. **Snapshot con "select('*')" (como hoy, L487):** arrastra PII innecesaria a la puerta y contradice D7.
8. **App nativa o push para avisar la sincronizacion:** fuera de alcance (D8) y sin beneficio en el flujo de puerta.

---

## 9. Tareas a abrir

Los numeros definitivos los asigna @docs-keeper al registrar este ADR; aqui van como placeholder.

| ID (asignado 2026-11-07) | Titulo | Agente | Estado |
|---|---|---|---|
| **TSK-006a** | PWA instalable del scanner: "manifest.webmanifest", iconos, "start_url" y UX del token en el icono instalado (hereda y acota TSK-006 de "TASKS.md:109") | @admin-dev + @frontend-tpl | ABIERTA |
| **TSK-133** | Validacion offline del scanner: snapshot en IndexedDB, outbox con "op_id", encolado por fallo de red, guard de "updateCounter", purga | @admin-dev | ABIERTA |
| **TSK-134** | Migracion "adr090": columnas "op_id"/"offline" en "logs" e indice unico parcial de idempotencia | @data-migration (diseno @sql-security) | ABIERTA |

**Nota:** @docs-keeper asigna el numero real de TSK-XXX/TSK-XXXb y decide si TSK-006a reemplaza o acota TSK-006; este ADR no renumera nada. (IDs asignados 2026-11-07: TSK-006a, TSK-133, TSK-134)

---

## 10. Preguntas abiertas residuales

1. **Duplicados historicos en "logs"** (D11/R1): si el pre-chequeo devuelve repetidos bajo "LIKE 'Ingreso%'", que decide Direccion sobre ellos? Se entregara la lista (evento, qr, punto, n); no se borra ni se fusiona nada sin decision registrada.
2. **Cifrado en reposo del snapshot:** WebCrypto (clave derivada del token, AES-GCM) frente a minimizacion + purga. @sql-security dictamina si el cifrado es obligatorio.
3. **Token en el icono instalado:** (a) guardar el enlace una sola vez por sesion, o (b) el icono abre sin token y muestra instrucciones.

---

## 11. Verificacion de este ADR contra el repo (ADR-006)

- Numeracion: 0 archivos "ADR-090*" en el repo; "DECISIONS.md" llega a ADR-088 (fila 103) y ADR-089 tiene ficha propia. Sin colision.
- TSK-006 vigente y pendiente en "TASKS.md:109" ("Configurar manifest.json y Service Worker para hacer el scanner instalable (PWA)").
- Los numeros de linea de "scanner.html" (L8-L9, L234, L251, L253-288, L293-344, L361-375, L448-453, L485, L487, L530-565, L926-967, L975-1086, L1153-1252, L1180, L1216-1225, L1279, L1309) y el tamano (1.330 lineas / 64,7 KB) provienen de la verificacion previa del archivo real; **@architect-review debe re-verificar al menos 3 anclas** antes de aprobar (recomendado: L251, L485-L487 y L1216-L1225).
- Formato documental copiado de "decisiones/ADR-089-*.md" y "decisiones/ADR-081-*.md" (frontmatter, cabecera de autor/estado, secciones numeradas).
- Revision 2026-11-07: dictamen de @architect-review incorporado (2 bloqueantes y 8 hallazgos mayores; D9-D11 agregadas). Ver el campo "revision" del frontmatter.
- Este documento es ASCII-safe: 0 caracteres no-ASCII, 0 backticks, sin emojis.

---

## 12. Adenda A1 (2026-11-07) - cierre de F1

- "op_id" es **columna de tipo "text"** que almacena UUID v4 (elegido sobre "uuid" para que un identificador malformado del fallback no aborte el check-in con 22P02).
- D11 en **dos tiempos**: se crea YA el indice unico por "op_id" ("WHERE op_id IS NOT NULL") para desbloquear F2; el indice natural "(evento_id, qr_code, COALESCE(punto_acceso,''))" se crea solo tras adjudicacion de duplicados historicos. Mientras falte, el riesgo "mismo QR validado en dos dispositivos del mismo punto" queda declarado y aceptado.
- La columna "offline" **no** entra en el predicado del indice (no es parte de la clave de idempotencia).
- "CHECK" de "logs.resultado" como **NOT VALID**: no reescribe filas historicas.
- D7 cifrado: se descarta AES-GCM con "CryptoKey" no extraible (mismo origen, no protege de XSS ni de navegador desbloqueado, y arriesga snapshot indescifrable en puerta). Se adopta **minimizacion (11 columnas, sin "respuestas_custom") + purga en 4 disparadores**: cerrar puerta, cambio de evento/token, vencimiento de la cota D9, revocacion 401/403 o "snapshot_version" desconocida. La purga nunca borra la "outbox" pendiente.
- Token del scanner en icono instalado: **sessionStorage por turno**, nunca "localStorage"; el icono abre sin token y pide el enlace una vez por turno.
