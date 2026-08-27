pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtPositioning

Singleton {
    id: root

    // --- Configuración y bindings ---
    readonly property int fetchInterval: (ConfigService.configs.weather.reloadTime ?? 10) * 60 * 1000
    readonly property string city: ConfigService.configs.weather.city ?? ""
    readonly property bool configGpsEnabled: ConfigService.configs.weather.autoLocation ?? false

    // --- Estados para la Interfaz de Usuario (UI) ---
    readonly property bool isLoading: root._geocodeXhr !== null || root._forecastXhr !== null
    property bool isError: false
    property string errorMessage: ""
    property double lastFetchTimestamp: 0

    // Override de sesión para GPS
    property bool _gpsSessionFallback: false
    readonly property bool gpsActive: root.configGpsEnabled && !root._gpsSessionFallback

    // Icono dinámico reactivo (Día / Noche)
    readonly property string icon: root.iconForCode(data.wCode, data.isDay)

    // --- Ubicación y Caché ---
    property var location: ({
            valid: false,
            lat: 0,
            lon: 0,
            cachedCity: ""
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
            visib: "0 km",
            press: "0 hPa",
            temp: "--°C",
            tempFeelsLike: "--°C",
            lastRefresh: "--:--",
            forecast: []
        })

    // Peticiones en curso
    property var _geocodeXhr: null
    property var _forecastXhr: null

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
            console.info("[WeatherService] Iniciando servicio GPS.");
            positionSource.start();
        } else {
            positionSource.stop();
        }
    }

    function iconForCode(code, isDay) {
        const c = parseInt(code);
        const day = isDay !== undefined ? Boolean(isDay) : true;

        switch (c) {
        case 0:
            return day ? "wb_sunny" : "bedtime";
        case 1:
        case 2:
            return day ? "partly_cloudy_day" : "nights_stay";
        case 3:
            return "cloud";
        case 45:
        case 48:
            return "foggy";
        case 51:
        case 53:
        case 55:
        case 56:
        case 57:
        case 61:
        case 63:
        case 65:
        case 66:
        case 67:
        case 80:
        case 81:
        case 82:
            return "rainy";
        case 71:
        case 73:
        case 75:
        case 77:
        case 85:
        case 86:
            return "ac_unit";
        case 95:
        case 96:
        case 99:
            return "thunderstorm";
        default:
            return "device_thermostat";
        }
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
        const daily = json?.daily || {};

        temp.wCode = current.weather_code ?? 0;
        temp.isDay = current.is_day ?? 1;
        temp.humidity = (current.relative_humidity_2m ?? 0) + "%";
        temp.windDir = root.degreesToCompass(current.wind_direction_10m ?? 0);
        temp.sunrise = (daily.sunrise && daily.sunrise[0]) ? daily.sunrise[0].split("T")[1] ?? daily.sunrise[0] : "--:--";
        temp.sunset = (daily.sunset && daily.sunset[0]) ? daily.sunset[0].split("T")[1] ?? daily.sunset[0] : "--:--";
        temp.uv = (daily.uv_index_max && daily.uv_index_max[0]) ? daily.uv_index_max[0] : 0;
        temp.city = json?._cityLabel || root.city;

        const unit = "°C";
        temp.temp = Math.round(current.temperature_2m ?? 0) + unit;
        temp.tempFeelsLike = Math.round(current.apparent_temperature ?? 0) + unit;
        temp.wind = Math.round(current.wind_speed_10m ?? 0) + " km/h";
        temp.precip = (current.precipitation ?? 0) + " mm";
        temp.press = Math.round(current.surface_pressure ?? 0) + " hPa";

        const hourlyVisib = json?.hourly?.visibility;
        const visibMeters = (hourlyVisib && hourlyVisib.length > 0) ? hourlyVisib[0] : 0;
        temp.visib = (visibMeters / 1000).toFixed(1) + " km";

        const dates = daily.time || [];
        const codes = daily.weather_code || [];
        const maxTemps = daily.temperature_2m_max || [];
        const minTemps = daily.temperature_2m_min || [];
        temp.forecast = [];

        for (let i = 1; i < dates.length; i++) {
            temp.forecast.push({
                date: dates[i],
                dayLabel: root.dayLabel(dates[i], i),
                wCode: codes[i] ?? 0,
                maxTemp: Math.round(maxTemps[i] ?? 0),
                minTemp: Math.round(minTemps[i] ?? 0),
                unit: unit
            });
        }

        const now = new Date();
        temp.lastRefresh = now.toLocaleTimeString(Qt.locale(), "hh:mm");

        root.data = temp;
        root.isError = false;
        root.errorMessage = "";
        root.lastFetchTimestamp = Date.now();
    }

    function _request(xhrPropName, url, label, onSuccess) {
        const prevXhr = root[xhrPropName];
        if (prevXhr) {
            root[xhrPropName] = null;
            prevXhr.abort();
        }

        const xhr = new XMLHttpRequest();
        root[xhrPropName] = xhr;
        xhr.timeout = 10000;

        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (xhr !== root[xhrPropName])
                return;
            root[xhrPropName] = null;

            if (xhr.status !== 200) {
                root.isError = true;
                root.errorMessage = `Error HTTP ${xhr.status}`;
                console.error(`[WeatherService] ${label} falló: HTTP ${xhr.status}`);
                return;
            }
            try {
                onSuccess(JSON.parse(xhr.responseText));
            } catch (e) {
                root.isError = true;
                root.errorMessage = "Error al procesar datos";
                console.error(`[WeatherService] ${label} parse error: ${e.message}`);
            }
        };

        xhr.onerror = () => {
            if (xhr !== root[xhrPropName])
                return;
            root[xhrPropName] = null;
            root.isError = true;
            root.errorMessage = "Error de red";
            console.error(`[WeatherService] ${label} error de red`);
        };

        xhr.ontimeout = () => {
            if (xhr !== root[xhrPropName])
                return;
            root[xhrPropName] = null;
            root.isError = true;
            root.errorMessage = "Tiempo de espera agotado";
            console.error(`[WeatherService] ${label} timeout`);
        };

        xhr.open("GET", url);
        xhr.send();
    }

    function fetchForecast(cityLabel) {
        const url = "https://api.open-meteo.com/v1/forecast" + `?latitude=${root.location.lat}&longitude=${root.location.lon}` + "&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m,wind_direction_10m,surface_pressure,is_day" + "&hourly=visibility" + "&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max" + "&forecast_days=4" + "&temperature_unit=celsius&wind_speed_unit=kmh&precipitation_unit=mm" + "&timezone=auto";

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

        const url = "https://geocoding-api.open-meteo.com/v1/search" + `?name=${encodeURIComponent(name)}&count=5&language=es&format=json`;

        root._request("_geocodeXhr", url, "Geocoding", json => {
            const results = json?.results || [];
            if (results.length === 0) {
                root.isError = true;
                root.errorMessage = `Ciudad no encontrada`;
                console.error(`[WeatherService] No se encontró "${root.city}"`);
                return;
            }

            const match = countryCode ? (results.find(r => r.country_code === countryCode) || results[0]) : results[0];

            root.location = {
                valid: true,
                lat: match.latitude,
                lon: match.longitude,
                cachedCity: root.city
            };

            const cityLabel = match.name + (match.admin1 ? `, ${match.admin1}` : "");
            root.fetchForecast(cityLabel);
        });
    }

    function getData() {
        if (NetworkService?.currentNetwork === null) {
            root.isError = true;
            root.errorMessage = "Sin conexión";
            return;
        }

        if (root.gpsActive && root.location.valid) {
            root.fetchForecast(I18nService.getTranslation("weather.my_location", "Mi ubicación"));
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
            value: "com.oscar.Shell"
        }

        onPositionChanged: {
            if (position.latitudeValid && position.longitudeValid) {
                const accuracy = position.horizontalAccuracyValid ? position.horizontalAccuracy : -1;
                if (accuracy >= 0 && accuracy > 5000)
                    return;

                root.location = {
                    valid: true,
                    lat: position.coordinate.latitude,
                    lon: position.coordinate.longitude,
                    cachedCity: ""
                };
                root.fetchForecast(I18nService.getTranslation("weather.my_location", "Mi ubicación"));
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
