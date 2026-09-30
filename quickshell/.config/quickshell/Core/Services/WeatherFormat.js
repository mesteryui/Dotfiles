// --- WeatherFormat: helpers puros del parte (sin singletons) ---
// Extraído de WeatherService.qml para partir sus ~740 líneas.
// Todo aquí es determinista y testeable: entra valor, sale valor.
// Lo que necesita I18n/Qt.locale (dayLabel, _geoLang) sigue en el QML.

function cleanPlaceName(s) {
    if (!s)
        return "";
    return String(s).replace(/\s*\[[^\]]*\]/g, "").replace(/\s+/g, " ").trim();
}

function buildCityLabel(place, region, fallback) {
    place = cleanPlaceName(place);
    region = cleanPlaceName(region);
    if (place && region) {
        const p = place.toLowerCase();
        const r = region.toLowerCase();
        if (r === p || p.includes(r))
            return place;
        return `${place}, ${region}`;
    }
    return place || region || fallback;
}

function degreesToCompass(deg) {
    const points = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"];
    const idx = Math.round(((deg % 360) / 22.5)) % 16;
    return points[idx < 0 ? idx + 16 : idx];
}

function alertsSlug(countryCode) {
    const map = {
        ES: "spain",
        PT: "portugal",
        FR: "france",
        DE: "germany",
        IT: "italy"
    };
    return map[(countryCode || "").toUpperCase()] ?? "";
}

function alertTokens(parts) {
    const stop = {
        de: 1,
        la: 1,
        el: 1,
        las: 1,
        los: 1,
        del: 1,
        les: 1,
        y: 1,
        en: 1,
        et: 1,
        the: 1,
        of: 1,
        provincia: 1,
        comunidad: 1,
        autonoma: 1,
        ciudad: 1,
        region: 1,
        departamento: 1
    };
    const out = [];
    for (let i = 0; i < parts.length; i++) {
        const words = String(parts[i] || "").toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "").split(/[^a-z0-9]+/);
        for (let j = 0; j < words.length; j++) {
            const w = words[j];
            if (w.length >= 4 && !stop[w] && out.indexOf(w) < 0)
                out.push(w);
        }
    }
    return out;
}

function aqiLevelOf(value) {
    if (value == null || value < 0)
        return 0;
    if (value < 20)
        return 1;
    if (value < 40)
        return 2;
    if (value < 60)
        return 3;
    if (value < 80)
        return 4;
    if (value < 100)
        return 5;
    return 6;
}
