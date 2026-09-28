---
name: agentes-roster
description: Esquema de rutas de agentes (libre/hybrid/pago), decisiones de reconciliacion y discrepancia real del contrato v112. Cargar para el detalle de un agente, la eleccion de ruta o el estado del contrato de datos.
---

# Roster de Agentes — Sistema QR Hostal Terraza

Esta skill **ya no duplica el roster**: la matriz `dominio -> pro | free` vive en `AGENTS.md` (sección 1) y el detalle de cada agente (dominio de archivos, permisos, modelo, temperatura) vive en el **frontmatter de `.opencode/agent/<nombre>.md`**. Para un dato de un agente concreto, `Read` su `.md`; no busques la tabla aquí. Es único de esta skill: la **decisión estratégica de esquema**, las **decisiones de reconciliación** y la **discrepancia conocida v112 vs. código real**.

## 1. Decisión estratégica del esquema de rutas

- **Ruta GRATUITA = default.** El día a día se ejecuta con `*-free` + `@free-build` (`opencode/big-pickle`), con planificación previa de `@free-plan`. Es lo que fija `default_agent: free-build` en `opencode.json` (ADR-052; antes `free-plan`).
- **Ruta HYBRID** = mezcla PRO/FREE en una misma sesión, con ruteo **por riesgo**: criterio, riesgo de runtime y seguridad → PRO; trabajo mecánico, repetitivo y de bajo riesgo → FREE. Nunca por preferencia.
- **Ruta de PAGO** = agentes pro `opencode-go/*`, respaldo de capacidad/calidad.
- **Regla transversal:** todo agente declara `model:` explícito (prohibido heredar el modelo principal); los IDs usan el prefijo real del proveedor (`opencode-go/*` u `opencode/*`).
- **Regla de ruteo:** los planificadores NO implementan; orquestan y delegan por su ruta. Prohibido mezclar rutas salvo escalar seguridad crítica (`sql-security-free` -> `sql-security`), que además **no gestiona RLS, autenticación, claves ni integridad de datos crítica**.

## 2. Decisiones de reconciliación (confirmadas 2026-09-14)

- **Contrato de Datos vigente: v112 / 21 Átomos Soberanos.** Las versiones citadas en otros documentos — v107 (Reglas de Oro, Mandato 1) y v110/20 átomos (`PROJECT.md` Secciones 5 y 7) — quedan supersedidas como línea base de validación. Los 4 átomos de campaña de v110 (`#meta-magnitud`, `#mod-mapa-crisis`, `#mod-como-ayudar`, `#mod-impacto-historico`) son **extensión específica del silo `b5` / `eventovenezuela.html`**, no parte del contrato core que certifica `@qa-auditor`.
- **Motor:** el contrato especificado en el Blueprint para `evento3.html` se traslada íntegro al motor público vigente como "Cerebro Único" inamovible. Esto cierra la reconciliación pendiente en TSK-016/017/018.
- **Plataforma: OpenCode**, con los modelos de `BLUEPRINT.md` Sección 5.
- **Baseline de conteo (ADR-006):** el número de agentes **se deriva de `ls .opencode/agent/`**, nunca de una cifra escrita aquí. Estructura verificada el 2026-09-28: **16 pares pro/free** (los que cumplen la regla del sufijo `-free`, incluido el par `qa-auditor`/`qa-auditor-free`) **+ 6 singulares** (`plan`, `build`, `free-plan`, `free-build`, `hybrid-plan`, `hybrid-build`) = **38 archivos**. El agente `exp-pickle-free` (soporte mecánico gratuito) fue **retirado** (ADR-031 Addendum A / ADR-059) y su cobertura la hereda `@js-silo-dev-free`, su superset funcional. Si otro agente se retira o se crea, el conteo cambia y esta línea se ajusta.
- **Identidad de archivo:** el nombre del archivo es la identidad del agente (`.opencode/agent/<nombre>.md` -> `@<nombre>`) y debe coincidir con el campo `name:` de su frontmatter; si el campo no está, la identidad se deriva del nombre del archivo. El universo operativo es `.opencode/`. **`.agents/` está RETIRADO el 2026-09-28 (ADR-059)** — antes se declaraba LEGADO (ADR-031 Addendum B): sus 7 archivos versionados se eliminaron con `git rm` (duplicaba 2 skills, `frontend-design` y `web-design-guidelines`). No volver a leerlo, citarlo como vigente ni esperar nada de él; el conteo y el overhead se derivan de `.opencode/` con `node scripts/usage_report.js --overhead`.

## 3. ⚠️ Discrepancia conocida: Contrato v112 vs. código real (detectada 2026-09-14)

Auditoría del motor real contra el Contrato v112: el código está muy por delante de la documentación fuente.

- El `<title>` real dice "Master Orchestrator v214 · Atomic Grid System" (comentarios internos hasta v222); el Blueprint describe v112.
- De los 21 Átomos Soberanos, solo **8 existen con su id exacto**: `event-title`, `meta-fecha`, `meta-hora`, `meta-lugar`, `mod-video`, `mod-lineup`, `mod-ubicacion`, `mod-form`. `event-description` no existe en ninguna forma. Los otros 12 no están: `mod-galeria`, `mod-patrocinadores`, `mod-entradas`, `mod-faqs`, `mod-contacto`, `mod-reglas`, `mod-itinerario`, `mod-redes`, `mod-comentarios`, `mod-encuesta`, `mod-descargas`, `mod-sponsors-vip`.
- El archivo real usa un esquema propio de ~81 IDs (`mod-hero`, `mod-historia`, `mod-impacto`, `mod-cartel`, `mod-cta-final`, `unified-frame`, ...) más un sistema de i18n (`js/i18n.js`) que ningún documento fuente menciona. Censo completo: Anexo C de `AMPLIACION/TEMPLATES.md`.
- Sí coincide con lo documentado: doble pestaña de registro (`tab-new`/`tab-old`, `form-nuevo`/`form-ya`) encaja con el patrón Dual-Phase (ADR-011); la ausencia de Wompi/HMAC/`qr-creator` es consistente con TSK-001/002 pendientes.

**Decisión (2026-09-14):** se deja v112 como el contrato que validan los agentes. Consecuencia práctica: `@qa-auditor` reportará como "faltantes" esos 12 átomos, que en realidad fueron renombrados o reestructurados en v214+ — son **falsos positivos conocidos, no regresiones**. No correr auditoría seria contra el motor hasta traer un Contrato de Datos actualizado (o instruir explícitamente a ignorar esos 12 IDs).

> **Baseline de nombres (2026-09-28):** el archivo que hoy implementa el contrato v112 es `evento-app.html`; no existe `evento.html` ni en disco ni en `git ls-files`. Verificar con `ls`/`git ls-files` antes de asumir nombres (ADR-006).

## 4. Estado real de ADR-040 (2026-09-16)

Catálogo de plantillas curado **IMPLEMENTADO** (ADR-045, QA APTO) en `admin.html` (sub-tab Plantillas, vía `config_global` + RPC `fn_config_global_merge`); silo `f11` registrado como theme `fosforescente` (ADR-044). La migración `migrations/adr040_config_global_templates.sql` está **pendiente de ejecución manual por Dirección** (TSK-035): hasta ejecutarla el front degrada a fail-open (todo visible) y no bloquea. Norma completa de silos: `AMPLIACION/TEMPLATES.md` (hub, ADR-046) + skill `templates`.

## 5. Instalación

1. `AGENTS.md` en la raíz (fuente de verdad del ruteo) y los archivos de agente en `.opencode/agent/` (identidad = nombre de archivo; sección 2).
2. Modelos a verificar en la cuenta de OpenCode: gateway `opencode` → `big-pickle` y `mimo-v2.6-flash-free`; gateway `opencode-go` → `qwen3.8-flash` y `deepseek-v4.1-flash`. `deepseek-v4-flash` está RETIRADO: no pedir verificación. `media-reader-free` es la única excepción de modelo (visión real): NO normalizar a `big-pickle`.
3. Antes de la primera tarea delegada, leer la sección 3 (para no tratar los 12 átomos como regresiones).

## Fuentes

Documentos normativos en `Sistema QR desarrollo/` (subcarpeta del repo):

- `BLUEPRINT.md` — especificación técnica, Contrato de Datos v112 y matriz de agentes (Secciones 4 y 5).
- `PROJECT.md` (v1.6.5-FIX) — fuente de verdad estratégica, gobernanza de roles y roadmap.
- `DECISIONS.md` — memoria de ingeniería inamovible (ADR-006 baseline; ADR-031 esquema dual pro/free y anti-absorción; ADR-046 hub de silos; ADR-052 `default_agent`).
- `AMPLIACION/TEMPLATES.md` (hub normativo de silos, ADR-046) + skill `templates` — norma para crear/editar/auditar un silo; leer ANTES de tocar CSS de silo.
- `Reglas de Oro QR.md` (v128-MASTER) — 18 mandatos, framework AI-DOS v1.2 (ver skill `reglas-de-oro`).
