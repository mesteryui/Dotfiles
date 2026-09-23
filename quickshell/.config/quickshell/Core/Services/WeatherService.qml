pragma Singleton
pragma ComponentBehavior: Bound

import qs.Core.Modules
import QtQuick
import QtPositioning
import Quickshell

import "../Log.js" as Log

Singleton {
    id: root

    // --- Configuración y bindings ---
    readonly property int fetchInterval: (ConfigService.configs.weather.reloadTime ?? 10) * 60 * 1000
    readonly property string city: ConfigService.configs.weather.city ?? ""
    readonly property bool configGpsEnabled: ConfigService.configs.weather.autoLocation ?? false

    // --- Estados para la Interfaz de Usuario (UI) ---
    readonly property bool isLoading: root._geocodeXhr !== null || root._forecastXhr !== null || root._reverseXhr !== null
    property bool isError: false
    property string errorMessage: ""
    property double lastFetchTimestamp: 0

    // Override de sesión para GPS
    property bool _gpsSessionFallback: false
    readonly property bool gpsActive: root.configGpsEnabled && !root._gpsSessionFallback

    // Icono dinámico reactivo (Día / Noche)
    readonly property string icon: Icons.getWeatherIcon(data.wCode, data.isDay)

    // --- Ubicación y Caché ---
    property var location: ({
            valid: false,
            lat: 0,
            lon: 0,
            cachedCity: "",
            // Para avisos MeteoAlarm: slug del feed del país + tokens
            // de texto (ciudad, provincia, región) para emparejar zonas.
            countrySlug: "",
            matchTokens: []
        })

    // --- Estado de Datos ---
    property var data: ({
            uv: 0,
            humidity: "0%",
            sunrise: "--:--",
            sunset: "--:--",
            windDir: "N",
            wCode: 0,
            isDay: 1,
            city: "Cargando...",
            wind: "0 km/h",
            precip: "0 mm",
            precipProb: "0%",
            visib: "0 km",
            press: "0 hPa",
            temp: "--°C",
            tempFeelsLike: "--°C",
            tempMin: "--°C",
            tempMax: "--°C",
            lastRefresh: "--:--",
            forecast: [],
            hourlyByDay: [],
            // Avisos MeteoAlarm: 0 nada, 2 amarillo, 3 naranja, 4 rojo.
            alertLevel: 0,
            alertCount: 0,
            alerts: [],
            // Calidad del aire (European AQI): -1 desconocido.
            aqi: -1,
            // 0 desconocido, 1 buena … 6 pésima.
            aqiLevel: 0
        })

    // Peticiones en curso
    property var _geocodeXhr: null
    property var _forecastXhr: null
    property var _reverseXhr: null
    property var _alertsXhr: null
    property var _aqiXhr: null
    property double lastAlertsTimestamp: 0

    // Etiqueta de ciudad resuelta por geocodificación inversa (modo GPS).
    // Así se muestra "Madrid, Comunidad de Madrid" en vez de "Mi ubicación".
    property string _gpsLabel: ""
    // Evita arrancar el PositionSource (y loguear) dos veces al inicio:
    // onCompleted + onGpsActiveChanged tras cargar ConfigService.
    property bool _gpsRunning: false

    onConfigGpsEnabledChanged: {
        if (root.configGpsEnabled)
            root._gpsSessionFallback = false;
    }

    onGpsActiveChanged: root._syncPositionSource()

    onCityChanged: {
        root.location.valid = false;
        root.location.cachedCity = "";
        root.getData();
    }

    Connections {
        target: NetworkService

        function onCurrentNetworkChanged() {
            if (NetworkService?.currentNetwork !== null) {
                if (root.isError || root.data.lastRefresh === "--:--") {
                    root.getData();
                }
            }
        }
    }

    function _syncPositionSource() {
        if (root.gpsActive) {
            if (root._gpsRunning)
                return;
            root._gpsRunning = true;
            Log.info("[WeatherService] Iniciando servicio GPS.");
            positionSource.start();
        } else {
            // Parar a ciegas spamea "geoclue2: Already stopped" en el log.
            if (!root._gpsRunning)
                return;
            root._gpsRunning = false;
            positionSource.stop();
        }
    }

    // Limpia nombres del proveedor: quita sufijos tipo " [Galicia]" y
    // espacios sobrantes. Así "Vigo, Galicia [Galicia]" queda "Vigo, Galicia".
    function cleanPlaceName(s) {
        if (!s)
            return "";
        return String(s).replace(/\s*\[[^\]]*\]/g, "").replace(/\s+/g, " ").trim();
    }

    // Construye "Ciudad, Región" sin repetir el mismo nombre dos veces.
    function buildCityLabel(place, region, fallback) {
        place = root.cleanPlaceName(place);
        region = root.cleanPlaceName(region);
        if (place && region) {
            const p = place.toLowerCase();
            const r = region.toLowerCase();
            if (r === p || p.includes(r))
                return place;
            return `${place}, ${region}`;
        }
        return place || region || fallback;
    }

    // Idioma de 2 letras para las APIs de geocodificación, según el
    // idioma resuelto de la shell (no hardcodeado).
    function _geoLang() {
        const l = (I18nService.language || "en_US").toLowerCase();
        if (l.startsWith("es"))
            return "es";
        if (l.startsWith("en"))
            return "en";
        if (l.startsWith("eo"))
            return "en";
        return l.slice(0, 2);
    }

    function degreesToCompass(deg) {
        const points = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"];
        const idx = Math.round(((deg % 360) / 22.5)) % 16;
        return points[idx < 0 ? idx + 16 : idx];
    }

    function dayLabel(dateStr, index) {
        if (index === 0)
            return I18nService.getTranslation("weather.today", "Hoy");
        if (index === 1)
            return I18nService.getTranslation("weather.tomorrow", "Mañana");
        const d = new Date(dateStr);
        return d.toLocaleDateString(Qt.locale(), "ddd");
    }

    function refineData(json) {
        let temp = {};
        const current = json?.current || {};
        const hourly = json?.hourly || {};
        const daily = json?.daily || {};
        const unit = "°C";

        temp.wCode = current.weather_code ?? 0;
        temp.isDay = current.is_day ?? 1;
        temp.humidity = (current.relative_humidity_2m ?? 0) + "%";
        temp.windDir = root.degreesToCompass(current.wind_direction_10m ?? 0);
        temp.sunrise = (daily.sunrise && daily.sunrise[0]) ? daily.sunrise[0].split("T")[1]?.slice(0, 5) ?? daily.sunrise[0] : "--:--";
        temp.sunset = (daily.sunset && daily.sunset[0]) ? daily.sunset[0].split("T")[1]?.slice(0, 5) ?? daily.sunset[0] : "--:--";
        temp.uv = (daily.uv_index_max && daily.uv_index_max[0] != null) ? daily.uv_index_max[0] : 0;
        temp.city = json?._cityLabel || root.city;

        temp.temp = Math.round(current.temperature_2m ?? 0) + unit;
        temp.tempFeelsLike = Math.round(current.apparent_temperature ?? 0) + unit;
        temp.wind = Math.round(current.wind_speed_10m ?? 0) + " km/h";
        temp.precip = (current.precipitation ?? 0) + " mm";
        temp.press = Math.round(current.surface_pressure ?? 0) + " hPa";

        const visibTimes = hourly.time || [];
        const visibVals = hourly.visibility || [];
        let visibMeters = 0;
        if (visibTimes.length > 0 && visibVals.length > 0) {
            // Buscar la visibilidad de la hora actual (o la más cercana pasada)
            const nowIso = new Date().toISOString().slice(0, 13);
            let idx = visibTimes.findIndex(t => t.slice(0, 13) >= nowIso);
            if (idx < 0)
                idx = visibVals.length - 1;
            visibMeters = visibVals[idx] ?? 0;
        }
        temp.visib = (visibMeters / 1000).toFixed(1) + " km";

        const dates = daily.time || [];
        const codes = daily.weather_code || [];
        const maxTemps = daily.temperature_2m_max || [];
        const minTemps = daily.temperature_2m_min || [];
        const precipProbs = daily.precipitation_probability_max || [];
        const uvMaxs = daily.uv_index_max || [];
        const sunrises = daily.sunrise || [];
        const sunsets = daily.sunset || [];

        // Mínima / máxima de hoy (índice 0)
        temp.tempMin = Math.round(minTemps[0] ?? 0) + unit;
        temp.tempMax = Math.round(maxTemps[0] ?? 0) + unit;
        temp.precipProb = ((precipProbs[0] ?? 0)) + "%";
        temp.forecast = [];

        for (let i = 1; i < dates.length; i++) {
            temp.forecast.push({
                date: dates[i],
                dayLabel: root.dayLabel(dates[i], i),
                wCode: codes[i] ?? 0,
                maxTemp: Math.round(maxTemps[i] ?? 0),
                minTemp: Math.round(minTemps[i] ?? 0),
                precipProb: (precipProbs[i] ?? 0),
                unit: unit
            });
        }

        // --- Detalle por horas: hoy + 3 siguientes (máx. 4 días) ---
        const hTimes = hourly.time || [];
        const hTemps = hourly.temperature_2m || [];
        const hCodes = hourly.weather_code || [];
        const hProbs = hourly.precipitation_probability || [];
        const hIsDay = hourly.is_day || [];
        temp.hourlyByDay = [];

        const dayCount = Math.min(dates.length, 4);
        for (let d = 0; d < dayCount; d++) {
            const dayDate = (dates[d] || "").slice(0, 10);
            if (!dayDate)
                continue;
            let hours = [];
            for (let h = 0; h < hTimes.length; h++) {
                if ((hTimes[h] || "").slice(0, 10) !== dayDate)
                    continue;
                const timePart = (hTimes[h].split("T")[1] || "").slice(0, 5);
                hours.push({
                    time: hTimes[h],
                    hourLabel: timePart,
                    temp: Math.round(hTemps[h] ?? 0),
                    wCode: hCodes[h] ?? 0,
                    isDay: hIsDay[h] ?? 1,
                    precipProb: (hProbs[h] ?? 0)
                });
            }
            temp.hourlyByDay.push({
                date: dates[d],
                shortDate: dayDate.slice(8, 10) + "/" + dayDate.slice(5, 7),
                dayLabel: root.dayLabel(dates[d], d),
                wCode: codes[d] ?? 0,
                maxTemp: Math.round(maxTemps[d] ?? 0),
                minTemp: Math.round(minTemps[d] ?? 0),
                precipProb: (precipProbs[d] ?? 0),
                uvMax: (uvMaxs[d] ?? 0),
                sunrise: (sunrises[d] || "").split("T")[1]?.slice(0, 5) ?? "--:--",
                sunset: (sunsets[d] || "").split("T")[1]?.slice(0, 5) ?? "--:--",
                unit: unit,
                hours: hours
            });
        }

        const now = new Date();
        temp.lastRefresh = now.toLocaleTimeString(Qt.locale(), "hh:mm");

        root.data = temp;
        root.isError = false;
        root.errorMessage = "";
        root.lastFetchTimestamp = Date.now();
        // Los avisos cadencian aparte (30 min): no bloquean el parte.
        root.fetchAlerts(false);
        // El AQI cambia despacio pero pesa poco: con cada parte.
        root.fetchAqi();
    }

    function _request(xhrPropName, url, label, onSuccess, onFailure) {
        const prevXhr = root[xhrPropName];
        if (prevXhr) {
            root[xhrPropName] = null;
            prevXhr.abort();
        }

        const xhr = new XMLHttpRequest();
        root[xhrPropName] = xhr;
        xhr.timeout = 10000;

        // onFailure opcional: si se proporciona, el fallo no marca error
        // global sino que delega (p. ej. la geocodificación inversa usa
        // una etiqueta de respaldo en vez de romper el panel).
        // status 0 / "Error de red" = sin red al arrancar: aviso tenue
        // ("Sin conexión") en vez de Log.error con "Error HTTP 0".
        function handleError(msg) {
            const offline = msg === "Sin conexión" || msg === "Error de red";
            if (onFailure) {
                Log.warn(`[WeatherService] ${label}: ${msg} (respaldo)`);
                onFailure(msg);
            } else if (offline) {
                root.isError = true;
                root.errorMessage = "Sin conexión";
                Log.warn(`[WeatherService] ${label}: sin conexión (reintentando)`);
            } else {
                root.isError = true;
                root.errorMessage = msg;
                Log.error(`[WeatherService] ${label} falló: ${msg}`);
            }
        }

        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (xhr !== root[xhrPropName])
                return;
            root[xhrPropName] = null;

            if (xhr.status !== 200) {
                // status 0 = sin red/DNS al arrancar, no un HTTP real.
                if (xhr.status === 0)
                    handleError("Sin conexión");
                else
                    handleError(`Error HTTP ${xhr.status}`);
                return;
            }
            try {
                onSuccess(JSON.parse(xhr.responseText));
            } catch (e) {
                handleError("Error al procesar datos");
            }
        };

        xhr.onerror = () => {
            if (xhr !== root[xhrPropName])
                return;
            root[xhrPropName] = null;
            handleError("Error de red");
        };

        xhr.ontimeout = () => {
            if (xhr !== root[xhrPropName])
                return;
            root[xhrPropName] = null;
            handleError("Tiempo de espera agotado");
        };

        xhr.open("GET", url);
        xhr.send();
    }

    function fetchForecast(cityLabel) {
        const url = "https://api.open-meteo.com/v1/forecast" + `?latitude=${root.location.lat}&longitude=${root.location.lon}` + "&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m,wind_direction_10m,surface_pressure,is_day" + "&hourly=temperature_2m,weather_code,precipitation_probability,is_day,visibility" + "&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max,precipitation_probability_max" + "&forecast_days=4" + "&temperature_unit=celsius&wind_speed_unit=kmh&precipitation_unit=mm" + "&timezone=auto";

        root._request("_forecastXhr", url, "Forecast", json => {
            json._cityLabel = cityLabel;
            root.refineData(json);
        });
    }

    function geocodeCity() {
        if (!root.city || root.city.trim() === "") {
            root.isError = true;
            root.errorMessage = "Ciudad no configurada";
            return;
        }

        const parts = root.city.split(",").map(p => p.trim());
        const name = parts[0];
        const countryCode = parts.length > 1 ? parts[1].toUpperCase() : "";

        const url = "https://geocoding-api.open-meteo.com/v1/search" + `?name=${encodeURIComponent(name)}&count=5&language=${root._geoLang()}&format=json`;

        root._request("_geocodeXhr", url, "Geocoding", json => {
            const results = json?.results || [];
            if (results.length === 0) {
                root.isError = true;
                root.errorMessage = `Ciudad no encontrada`;
                Log.error(`[WeatherService] No se encontró "${root.city}"`);
                return;
            }

            const match = countryCode ? (results.find(r => r.country_code === countryCode) || results[0]) : results[0];

            root.location = {
                valid: true,
                lat: match.latitude,
                lon: match.longitude,
                cachedCity: root.city,
                countrySlug: root._alertsSlug(match.country_code),
                matchTokens: root._alertTokens([match.name, match.admin1, match.admin2, match.admin3, match.admin4])
            };

            const cityLabel = root.buildCityLabel(match.name, match.admin1, root.city);
            root.fetchForecast(cityLabel);
        });
    }

    // Geocodificación inversa: convierte las coordenadas GPS en nombre
    // de ciudad, en el idioma de la shell. Si falla, reutiliza la última
    // etiqueta conocida y solo como último recurso el genérico traducido.
    function reverseGeocode() {
        const fallback = root._gpsLabel !== "" ? root._gpsLabel : I18nService.getTranslation("weather.my_location", "Mi ubicación");
        const url = "https://api.bigdatacloud.net/data/reverse-geocode-client" + `?latitude=${root.location.lat}&longitude=${root.location.lon}&localityLanguage=${root._geoLang()}`;

        root._request("_reverseXhr", url, "ReverseGeocode", json => {
            const label = root.buildCityLabel(json?.city || json?.locality || "", json?.principalSubdivision || json?.countryName || "", fallback);
            root._gpsLabel = label;
            root.location = Object.assign({}, root.location, {
                countrySlug: root._alertsSlug(json?.countryCode),
                matchTokens: root._alertTokens([json?.city, json?.locality, json?.principalSubdivision, json?.countryName])
            });
            root.fetchForecast(label);
        }, () => {
            root.fetchForecast(fallback);
        });
    }

    // ---- Avisos MeteoAlarm (sin clave, feed JSON por país) ----
    // Slug verificado del feed: feeds-{slug}. Sin slug no hay avisos.
    function _alertsSlug(countryCode) {
        const map = {
            ES: "spain",
            PT: "portugal",
            FR: "france",
            DE: "germany",
            IT: "italy"
        };
        return map[(countryCode || "").toUpperCase()] ?? "";
    }

    // Tokens para emparejar zonas ("Miño de Pontevedra" casa con
    // "Pontevedra"). Sin geometrías en el feed, el texto manda.
    function _alertTokens(parts) {
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

    function _alertLevelOf(info) {
        const params = info?.parameter || [];
        for (let i = 0; i < params.length; i++) {
            if (params[i]?.valueName !== "awareness_level")
                continue;
            const color = String(params[i]?.value ?? "").split(";")[1]?.trim().toLowerCase() ?? "";
            if (color === "red")
                return 4;
            if (color === "orange")
                return 3;
            if (color === "yellow")
                return 2;
            return 0;
        }
        return 0;
    }

    // Info en el idioma de la shell (eo -> en), si existe.
    function _alertInfo(alert) {
        const infos = alert?.info || [];
        if (infos.length === 0)
            return null;
        const lang = (I18nService.language || "en_US").toLowerCase().slice(0, 2);
        const want = lang === "eo" ? "en" : lang;
        for (let i = 0; i < infos.length; i++)
            if (String(infos[i]?.language || "").toLowerCase().startsWith(want))
                return infos[i];
        for (let j = 0; j < infos.length; j++)
            if (String(infos[j]?.language || "").toLowerCase().startsWith("en"))
                return infos[j];
        return infos[0];
    }

    function parseAlerts(json) {
        const now = Date.now();
        const tokens = root.location.matchTokens || [];
        const out = [];
        const seen = {};
        const warnings = json?.warnings || [];
        for (let i = 0; i < warnings.length; i++) {
            const alert = warnings[i]?.alert;
            if (!alert || alert.status !== "Actual" || (alert.msgType !== "Alert" && alert.msgType !== "Update"))
                continue;
            const info = root._alertInfo(alert);
            if (!info)
                continue;
            const level = root._alertLevelOf(info);
            if (level < 2)
                continue;
            const onset = Date.parse(info.onset ?? info.effective ?? "");
            const expires = Date.parse(info.expires ?? "");
            if (isNaN(expires) || expires <= now || isNaN(onset) || onset > now + 24 * 3600 * 1000)
                continue;
            const areas = info.area || [];
            for (let a = 0; a < areas.length; a++) {
                const desc = String(areas[a]?.areaDesc ?? "");
                const norm = desc.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
                let hit = false;
                for (let t = 0; t < tokens.length; t++)
                    if (norm.includes(tokens[t])) {
                        hit = true;
                        break;
                    }
                if (!hit)
                    continue;
                const key = (alert.identifier ?? i) + "|" + desc;
                if (seen[key])
                    continue;
                seen[key] = true;
                out.push({
                    level: level,
                    event: info.event ?? "",
                    area: desc,
                    onset: info.onset ?? "",
                    expires: info.expires ?? "",
                    description: info.description ?? ""
                });
            }
        }
        out.sort((a, b) => (b.level - a.level) || (Date.parse(a.onset) - Date.parse(b.onset)));
        const d = Object.assign({}, root.data);
        d.alertLevel = out.length > 0 ? out[0].level : 0;
        d.alertCount = out.length;
        d.alerts = out;
        root.data = d;
        root.lastAlertsTimestamp = Date.now();
    }

    function fetchAlerts(force) {
        if (!root.location.valid || !root.location.countrySlug)
            return;
        if (!force && Date.now() - root.lastAlertsTimestamp < 30 * 60 * 1000)
            return;
        const url = "https://feeds.meteoalarm.org/api/v1/warnings/feeds-" + root.location.countrySlug;
        root._request("_alertsXhr", url, "Alerts", json => root.parseAlerts(json), msg => {
            Log.warn("[WeatherService] Alerts: " + msg + " (sin avisos)");
        });
    }

    // ---- Calidad del aire (Open-Meteo, sin clave) ----
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

    function fetchAqi() {
        if (!root.location.valid)
            return;
        const url = "https://air-quality-api.open-meteo.com/v1/air-quality" + `?latitude=${root.location.lat}&longitude=${root.location.lon}` + "&current=european_aqi&timezone=auto";
        root._request("_aqiXhr", url, "AirQuality", json => {
            const value = json?.current?.european_aqi ?? -1;
            const d = Object.assign({}, root.data);
            d.aqi = value;
            d.aqiLevel = root.aqiLevelOf(value);
            root.data = d;
        }, msg => {
            Log.warn("[WeatherService] AirQuality: " + msg + " (sin AQI)");
        });
    }

    function getData() {
        if (NetworkService?.currentNetwork === null) {
            root.isError = true;
            root.errorMessage = "Sin conexión";
            return;
        }

        if (root.gpsActive && root.location.valid) {
            // Etiqueta ya resuelta: directa; si no, geocodificación inversa.
            if (root._gpsLabel !== "")
                root.fetchForecast(root._gpsLabel);
            else
                root.reverseGeocode();
            return;
        }

        if (root.location.valid && root.location.cachedCity === root.city) {
            root.fetchForecast(root.city);
            return;
        }

        root.geocodeCity();
    }

    function forceRefresh() {
        if (Date.now() - root.lastFetchTimestamp < 3000)
            return;
        root.getData();
    }

    Component.onCompleted: {
        root._syncPositionSource();
        root.getData();
    }

    PositionSource {
        id: positionSource

        updateInterval: root.fetchInterval
        name: "geoclue2"

        PluginParameter {
            name: "desktopId"
            value: "com.shinro.shell"
        }

        onPositionChanged: {
            if (position.latitudeValid && position.longitudeValid) {
                const accuracy = position.horizontalAccuracyValid ? position.horizontalAccuracy : -1;
                if (accuracy >= 0 && accuracy > 5000)
                    return;

                const newLat = position.coordinate.latitude;
                const newLon = position.coordinate.longitude;
                // Si apenas nos hemos movido y ya hay etiqueta, no
                // repetimos la geocodificación inversa: directa al forecast.
                const sameSpot = root.location.valid && root._gpsLabel !== "" && Math.abs(root.location.lat - newLat) < 0.01 && Math.abs(root.location.lon - newLon) < 0.01;

                root.location = {
                    valid: true,
                    lat: newLat,
                    lon: newLon,
                    cachedCity: "",
                    countrySlug: root.location.countrySlug ?? "",
                    matchTokens: root.location.matchTokens ?? []
                };
                if (sameSpot)
                    root.fetchForecast(root._gpsLabel);
                else
                    root.reverseGeocode();
            } else {
                if (!root.location.valid)
                    root._gpsSessionFallback = true;
            }
        }

        onValidityChanged: {
            if (!positionSource.valid) {
                root.location = {
                    valid: false,
                    lat: 0,
                    lon: 0,
                    cachedCity: ""
                };
                root._gpsSessionFallback = true;
            }
        }
    }

    // Timer seguro y nativo para polling asíncrono
    Timer {
        running: !root.gpsActive
        repeat: true
        interval: root.fetchInterval
        triggeredOnStart: false
        onTriggered: root.getData()
    }
}
