'use strict';
/* =====================================================================
   PROMO CUTOFF -- unico punto de verdad en cliente para decidir si la
   promocion de un evento debe mostrarse. Vanilla puro (ADR-001): sin
   dependencias, sin DOM, sin estado, sin build.

   Contrato:
     HT.getPromo(cfgLanding, nowMs) -> { sponsor, texto, fin } | null
     HT.promoVencida(promo, nowMs) -> boolean

   - cfgLanding: eventos.config_landing (objeto, string JSON o nulo).
   - nowMs: epoch en ms; inyectable para tests (default Date.now()).
   - promo.fin debe ser ISO con offset de Colombia, ej.
     '2026-11-18T23:59:00-05:00'. Date.parse lo resuelve a epoch absoluto
     identico en cualquier dispositivo (sin ambiguedad de zona).

   Regla fail-closed: ante cualquier dato dudoso devuelve null.
   Techo duro: aunque promo.fin sea lejano, despues de PROMO_CEILING_MS
   la promo no se muestra. El correo replica esta misma regla en servidor
   (PROMO_FIN_CEILING en send-ticket-email/index.ts).
   ===================================================================== */
(function () {
    var HT = window.HT = window.HT || {};

    // Techo duro absoluto compartido con el servidor. Solo puede cerrar
    // antes de promo.fin; nunca puede abrir una promo ya vencida.
    var PROMO_CEILING_MS = Date.parse('2026-11-20T12:00:00-05:00');

    // Normaliza la entrada: objeto tal cual, string JSON parseado o null.
    function __cfgObj(cfg) {
        if (cfg == null) return null;
        if (typeof cfg === 'string') {
            try {
                cfg = JSON.parse(cfg);
            } catch (e) {
                return null;
            }
        }
        if (!cfg || typeof cfg !== 'object') return null;
        return cfg;
    }

    // Extrae cfgLanding.content.promo cuidando cada salto con guarda.
    function __promoOf(cfgLanding) {
        var cfg = __cfgObj(cfgLanding);
        if (!cfg) return null;
        var content = cfg.content;
        if (!content || typeof content !== 'object') return null;
        var promo = content.promo;
        if (!promo || typeof promo !== 'object') return null;
        return promo;
    }

    // Epoch de promo.fin; NaN si el valor no es parseable.
    function __finMs(promo) {
        if (!promo || typeof promo !== 'object') return NaN;
        var t = Date.parse(promo.fin);
        return isFinite(t) ? t : NaN;
    }

    // nowMs inyectable: solo se acepta un number finito.
    function __now(nowMs) {
        return (typeof nowMs === 'number' && isFinite(nowMs)) ? nowMs : Date.now();
    }

    HT.getPromo = function (cfgLanding, nowMs) {
        var promo = __promoOf(cfgLanding);
        if (!promo) return null;
        // Estricto: solo el booleano true activa la promo (ni 'true' ni 1).
        if (promo.activa !== true) return null;
        if (typeof promo.texto !== 'string' || promo.texto.trim() === '') return null;
        var fin = __finMs(promo);
        if (!isFinite(fin)) return null;
        var now = __now(nowMs);
        // Estrictamente menor: en el instante exacto de fin ya no se muestra.
        if (now >= fin) return null;
        // Techo duro: ni con un fin lejano sobrevive al corte global.
        if (isFinite(PROMO_CEILING_MS) && now >= PROMO_CEILING_MS) return null;
        return {
            sponsor: String(promo.sponsor || ''),
            texto: promo.texto,
            fin: promo.fin
        };
    };

    // Aviso para el admin: no exige 'activa', solo responde si la fecha ya
    // paso o si el techo duro ya cerro. Fail-closed: una fecha corrupta se
    // reporta como vencida.
    HT.promoVencida = function (promo, nowMs) {
        var fin = __finMs(promo);
        if (!isFinite(fin)) return true;
        var now = __now(nowMs);
        if (isFinite(PROMO_CEILING_MS) && now >= PROMO_CEILING_MS) return true;
        return now >= fin;
    };
})();
