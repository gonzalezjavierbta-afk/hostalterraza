---
doc: ADR-072
version: v1.16-GOLD (heredada de DECISIONS.md)
fecha: 2026-10-02
origen: sesion express 2026-10-02 (@backend-dev, @sql-security, @admin-dev; gate de riesgo seccion 2 autorizado por Direccion)
version_previa: DECISIONS.md v1.16-GOLD
relacionados: [../DECISIONS.md, ../INDEX.md, ADR-050-analitica-del-landing-ampliada-check-de-event.md, ADR-062-multi-link-de-invitador-varios-links-por.md, ADR-068-unicidad-real-de-inscritura-por-even.md]
estado: vigente (ver campo Estado dentro del ADR)
estructura: detalle-v1 (2026-10-01)
---

> Detalle de [DECISIONS.md](../DECISIONS.md) - [INDEX](../INDEX.md).

## ADR-072: Atribucion del link de invitador en la telemetria del landing

**Fecha:** 2026-10-02

**Autor:** @backend-dev + @sql-security + @admin-dev (gate de riesgo seccion 2 autorizado por Direccion, 2026-10-02)

**Estado:** DECIDIDO - migracion ESCRITA y NO APLICADA; capa cliente implementada y sin desplegar

**Problema:** la telemetria del landing (`public.page_events`, creada en ADR-032 y ampliada en ADR-050) guardaba en `page_ref` el **HTTP Referer**: el dominio del que venia el visitante (WhatsApp, Facebook, buscadores, enlace directo). Ese valor es ruido de red y **NO identifica a ninguna persona de la organizacion**. El codigo del invitador (`invitadores.codigo`, que el cliente resuelve del parametro `?ref=CODE`) solo se persistia en `inscritos.ref_codigo`, es decir **solo cuando la persona completaba el registro**. Resultado: no existia forma de saber cuantas personas llegaban por cada link de invitador, ni cuantas se perdian antes de registrarse. El multi-link de ADR-062 multiplico los links por invitador sin crear la medicion que los distingue.

**Contexto:** la atribucion ya tiene un precedente simetrico en `inscritos.ref_codigo` (mismo nombre, mismo tipo), asi que `page_events` era la unica capa del embudo sin atributo de invitador. La tabla `page_events` tiene 15 columnas y 2 politicas (`page_events_auth_read` SELECT authenticated `USING true`, `page_events_anon_insert` INSERT anon). ADR-050 dejo 4 vistas del panel creadas con `WITH (security_invoker = true)` + `GRANT SELECT TO authenticated`, patron que se replica aqui. ADR-006: la verdad es el archivo real del repo.

**Opciones:**
- (A) Guardar el codigo dentro de `user_meta` o de una columna JSONB: no hay indice btree barato; cada lectura del panel seria un filtro por expression sobre JSONB, sin leverage del indice parcial, descartada.
- (B) Cruzar `inscritos` dentro de la vista para heredar su `ref_codigo`: doble superficie de RLS evaluada dentro de una vista `security_invoker` y acopla la telemetria (lectura anon, escritura anon) con el registro (lectura autenticada); el grano quedaria limitado a quien se inscribio, que es justo lo que se queria superar, descartada.
- (C) Columna propia `text` en `page_events`, simetrica con `inscritos.ref_codigo`, con indice parcial y vista agregada: elegida.

**Decision:** tres objetos, en este orden, en `migrations/adr072_page_events_ref_invitador.sql` (257 lineas, 100% ASCII, idempotente al 100% con `ADD COLUMN IF NOT EXISTS` / `CREATE INDEX IF NOT EXISTS` / `DROP VIEW IF EXISTS` + `CREATE VIEW` + `GRANT`):

1. **Columna** `ALTER TABLE public.page_events ADD COLUMN IF NOT EXISTS ref_codigo text NOT NULL DEFAULT '';` agregada al FINAL (sin `AFTER`), de modo que ningun lector con `select *` por posicion se altera: se pasa de 15 a 16 columnas. El `NOT NULL DEFAULT ''` es lo que permite que los emisores que aun no mandan `ref_codigo` sigan funcionando y que la vista filtre con `<> ''` sin `coalesce`. En PostgreSQL 17 el ADD COLUMN con default NO volatile es **metadata-only** (se registra en `pg_attribute.attmissingval`, no reescribe la tabla ni dispara triggers por fila): costo O(1) con independencia del volumen.
2. **Indice PARCIAL** `idx_page_events_org_ref_created ON public.page_events (org_id, ref_codigo, created_at DESC) WHERE ref_codigo <> '';` cubre el filtro canonico de la vista (org + ref, orden cronologico descendente, solo filas atribuidas) y deja fuera del btree todo el historico sin atribucion. `page_ref` NO se indexa: es ruido de red y no se consulta por codigo.
3. **Vista** `public.v_landing_invitadores` creada con `WITH (security_invoker = true)` + `GRANT SELECT ON public.v_landing_invitadores TO authenticated;` Agrupa por `org_id, evento_slug, ref_codigo` y expone, en este orden exacto: `pageviews` (`count(*) FILTER (WHERE event_type = 'pageview')`), `visitantes_unicos` (`count(DISTINCT visitor_id) FILTER (WHERE event_type = 'pageview')`), `eventos` (`count(*)`), `primera_visita` (`min(created_at)`) y `ultima_visita` (`max(created_at)`), filtrando `WHERE ref_codigo <> ''`.

**Por que `security_invoker = true` (critico):** sin el, la vista se ejecutaria como owner y **BYPASSARIA RLS**. Con el, la politica de `page_events` se evalua sobre el rol invocador (`authenticated`), igual que las 4 vistas de ADR-050.

**Lo que NO se toco (deliberado):**
- `page_ref` **no se renombra ni se borra** (Cero Borrado): sigue siendo el Referer; `ref_codigo` es una columna nueva al lado.
- Las **politicas RLS**: `page_events` sigue con EXACTAMENTE 2. No se creo ninguna RPC, ningun trigger, ninguna tabla y ninguna politica nueva; tampoco se toco ninguna de las 4 vistas de ADR-050.
- **No hay JOIN a `inscritos`**: la vista es pura sobre una sola tabla (opcion B descartada). Si el panel necesita el nombre del invitador, lo resuelve en el cliente contra `invitadores` por codigo.
- El panel no se toca en arquitectura: `admin.html` consulta la vista con `.eq('org_id', ORG_ID)` (verificado en `admin.html:9321`), la misma mitigacion a nivel de consulta que las 4 vistas de ADR-050.

**Consecuencias (registro obligatorio):**
- **El trafico historico por `ref` es IRRECUPERABLE.** Las filas ya escritas quedan en `ref_codigo = ''` y no se pueden atribuir: no se deduce del `page_ref` ni de la sesion del visitante, y reescribirlas seria inventar dato. Por eso la vista excluye las vacias y el indice es parcial sobre ese mismo predicado.
- **La vista arranca vacia** y acumula solo desde el despliegue del front que persista `ref_codigo` en el INSERT de `page_events`. Es el comportamiento fail-open previsto, no un fallo.
- **El `ADD COLUMN` fue barato pero el `DROP COLUMN` de un eventual rollback no lo es:** el rollback documentado al final de la migracion reescribe la tabla fisicamente y borra el dato de `ref_codigo` de las filas.
- **NO se tocaron las politicas RLS**, asi que la deuda de tenancy sigue abierta: `page_events_auth_read` conserva `USING true` (barrido TSK-026). La vista nueva **hereda esa exposicion** por `security_invoker`; cuando la politica se restrinja por `org_id` (patron `get_org_id()` + org master, ADR-025/036), la vista lo heredara sola sin recrearse. Hoy la unica mitigacion vigente es el `.eq('org_id', ORG_ID)` del cliente.

**Impacto:** una columna, un indice parcial y una vista: 3 objetos de esquema, 0 politicas, 0 RPC, 0 triggers. En el cliente, los 3 motores (`evento-app.html`, `eventovenezuela.html`, `registroaforo.html`) pasan a mandar `ref_codigo` en el INSERT de `page_events` y `admin.html` gana el bloque de ranking de invitadores. La migracion esta ESCRITA y **NO APLICADA**: la aplica Direccion en el SQL Editor. El orden de despliegue es obligatorio: **(1) aplicar la migracion, (2) desplegar el front**. Al reves, el INSERT sin la columna falla en silencio (fire-and-forget) y no se registra ninguna llegada.

**Nota de numeracion:** el ID `ADR-072` no reutiliza ni salta ningun ID (`ADR-071` es el ultimo ocupado).