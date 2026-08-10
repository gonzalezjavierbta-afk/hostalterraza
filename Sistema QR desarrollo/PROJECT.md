# 🛡️ PROJECT.md — Sistema QR Hostal Terraza (v1.6.3-FIX)

## 1. Información General
*   **Nombre del Proyecto:** Sistema QR Hostal Terraza.
*   **Tipo de Producto:** Plataforma Web de Gestión de Eventos, Ticketing y Control de Aforo (SaaS Multi-tenant).
*   **Ubicación de Referencia:** Bogotá, Colombia.
*   **Estado del Sistema:** **v1.6.3-FIX** — Piloto Oficial de AI-DOS v1.2 / Baseline f1 Certified. Wizard Inteligente de Creación (ADR-021), navegación en pestañas de Admin (ADR-022) y Panel (ADR-023), y fix "Null Pointer Regression" en el panel (ADR-024) entregados en `admin.html`.
*   **Framework de Coordinación:** **AI-DOS v1.2 (PM Hub Engine)**.
*   **Estándar de Calidad:** Calidad Percibida de **$10,000** (Fidelidad de 1px, Afterglow visual, Geist 900).
*   **URL Producción:** [https://hostalterraza.vercel.app](https://hostalterraza.vercel.app).
*   **Repositorio Oficial:** [GitHub - Hostal Terraza](https://github.com/gonzalezjavierbta-afk/hostalterraza).

## 2. Visión y Objetivos
### 2.1 Objetivo Funcional
Construir una infraestructura modular e independiente para la gestión digital de eventos, eliminando la dependencia de procesos manuales (listas de papel) y automatizando el control de acceso y monetización en tiempo real.

### 2.2 Objetivo Metodológico (Piloto Oficial AI-DOS v1.2)
Validar el framework **AI-DOS v1.2** en un entorno de producción real, certificando la eficiencia de la **Dirección Agéntica** y el uso de **Context Packages** para el desarrollo asistido por múltiples IAs.

## 3. Stack Tecnológico y de Mando
*   **Cerebro PM & Knowledge Layer:** **NotebookLM** (Vinculado dinámicamente a Google Drive).
*   **Frontend:** HTML5, CSS3, JavaScript puro (Vanilla JS) sin herramientas de compilación para portabilidad absoluta y carga instantánea.
*   **Backend / DB:** **Supabase** (PostgreSQL, Edge Functions, Auth, Storage, RLS).
*   **Email Engine:** **Resend**.
*   **Hosting:** **Vercel CDN**.

## 4. Gobernanza de Roles (Matrix v1.2)
| Rol | Implementación | Especialidad |
| :--- | :--- | :--- |
| **Project Manager Hub** | **NotebookLM** | Centralización de la verdad y generación de órdenes técnicas. |
| **Chief Architect** | **Claude** | Lógica estructural, ADRs y validación de fidelidad de 1px. |
| **Lead Developer** | **Gemini / Cursor** | JS, SQL, Integración de APIs (Wompi) y despliegue. |
| **Creative Director** | **Open Design** | UI/UX Premium y CSS Atómico Scoped. |
| **QA Specialist** | **Claude** | Auditoría de integridad y Escudo GOLD. |

## 5. Reglas de Oro Irrenunciables (v127-MASTER)
1.  **Prioridad Estructural (Data-First):** Certificar el flujo de datos (Logs TRACE) antes de aplicar cualquier estilo visual.
2.  **Protocolo de "Cero Borrado":** Prohibido eliminar IDs del **Contrato de Datos v110** (#event-title, #db-lineup), incluso si no son visibles.
3.  **Aislamiento Atómico (Scoped CSS):** Todo el CSS debe encapsularse bajo el selector `.tpl-{template_id}` para evitar colisiones entre silos.
4.  **Regla de Bloque sobre Flex:** Los contenedores de módulos masivos (video, lineup) deben usar `display: block !important` para garantizar el centrado y expansión total.
5.  **Silent Fallback de Activos:** Todo elemento `<img>` dinámico debe incluir `onerror` para evitar íconos de imagen rota si la URL de Supabase falla.
6.  **Eliminación de Respiros Multimedia:** El módulo de video debe usar `padding-top: 0 !important` para integrarse visualmente con el bloque superior (Countdown/Meta).

## 6. Arquitectura Modular y Biblioteca de Silos (v1.6.0-GOLD)
El sistema ha evolucionado de un modelo monolítico a un modelo de **Categorías y Templates Independientes (Silos Atómicos)**.

### 🎬 Silos Operativos Validados
*   **Cinematografía (`cine`):** c1 (Arthouse) y c2 (Premiere Gold).
*   **Fiesta (`fiesta`):** **f1 (Tropical Hostel)** ✅ Certificado v1.6.0 (Selina Style, verde selva y madera) y f2 (Rooftop Sunset).
*   **Campaña (`campana`):** b1 (Solidario Moderno), b4 (Vintage & Orgánico) y b5 (Emergencia Crítica).

## 7. Evolución del Contrato de Datos (v110) y Funcionalidad
*   **Expansión de Átomos (20 Átomos Soberanos):** Incorporación de componentes clave de campaña e impacto: `#meta-magnitud`, `#mod-mapa-crisis`, `#mod-como-ayudar` y `#mod-impacto-historico`.
*   **Innovación Funcional (Lógica Dual-Phase):** Implementada en `eventovenezuela.html` (Registro ➔ Perfilamiento in-place) como el estándar de alta conversión del sistema.

## 8. Gobernanza y Calidad ($10,000 Standard)
*   Uso mandatorio de tipografía **Geist 900** y efectos **Afterglow** como identidad visual técnica.
*   Obligatoriedad del **Escudo de Auditoría GOLD** (INFO, DEBUG, LINK, TRACE, TIME) para cada nueva "Cara" visual entregada.

## 9. Roadmap Inmediato
*   **TSK-016/017/018 (ADR-021, prioridad inmediata):** Cerrar el Wizard Inteligente de Creación — consumir `captura_pura` en `evento.html`, reconciliar `evento.html` vs. `evento3.html` como motor público vigente, y ejecutar la migración SQL de `template_id`/`categoria_slug`/`captura_pura`.
*   **TSK-SQL:** Migración masiva de nomenclatura en Supabase (P# -> c#/f#/b#).
*   **TSK-001:** Integración del widget de pagos **Wompi** en `registro.html`.
*   **TSK-002:** Edge Function `wompi-webhook` para activación automática de organizaciones.
*   **TSK-V03:** Despliegue de miniaturas YouTube (ADR-005) en los templates existentes.

---
*Este documento constituye la **Única Fuente de Verdad** estratégica del proyecto (Consolidado sin pérdida bajo Mandato v127).*