pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtPositioning

Singleton {
    id: root

    // Propiedades independientes (reemplazan a Config.options.bar.weather...)
    readonly property int fetchInterval: ConfigService.configs.weather.reloadTime * 60 * 1000 // 10 minutos por defecto
    readonly property string city: ConfigService.configs.weather.city
    readonly property bool gpsActive: ConfigService.configs.weather.autoLocation
    readonly property string icon: root.iconForCode(data.wCode)

    onCityChanged: root.getData()

    Connections {
        target: NetworkService
        function onCurrentNetworkChanged() {
            if (NetworkService.currentNetwork !== null) root.getData()
        }
    }


    property var location: ({
        valid: false,
        lat: 0,
        lon: 0,
    })

    property var data: ({
        uv: 0,
        humidity: 0,
        sunrise: 0,
        sunset: 0,
        windDir: 0,
        wCode: 0,
        city: 0,
        wind: 0,
        precip: 0,
        visib: 0,
        press: 0,
        temp: 0,
        tempFeelsLike: 0,
        lastRefresh: 0,
        forecast: [], // [{ date, dayLabel, wCode, maxTemp, minTemp }, ...]
    })

    // --- Peticiones en curso, para poder cancelarlas ---
    property var _geocodeXhr: null
    property var _forecastXhr: null

    // Etiqueta legible para cada día del forecast: Hoy / Mañana / nombre del día
    function dayLabel(dateStr, index) {
        if (index === 0)
            return I18nService.getTranslation("weather.today", "Hoy");
        if (index === 1)
            return I18nService.getTranslation("weather.tomorrow", "Mañana");
        const d = new Date(dateStr);
        return d.toLocaleDateString(Qt.locale(), "ddd");
    }

    // Convierte grados (0-360) a punto de la rosa de los vientos de 16 puntos
    function degreesToCompass(deg) {
        const points = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                         "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"];
        const idx = Math.round(((deg % 360) / 22.5)) % 16;
        return points[idx < 0 ? idx + 16 : idx];
    }

    // Mapeo de los códigos WMO que usa Open-Meteo (weather_code) a ligaduras
    // Material Symbols. A diferencia de wttr.in, aquí solo hay ~20 códigos,
    // documentados en https://open-meteo.com/en/docs -> WMO Weather codes.
    function iconForCode(code) {
        const c = parseInt(code);
        switch (c) {
        case 0: return "wb_sunny";                                     // Despejado
        case 1:
        case 2: return "partly_cloudy_day";                            // Poco/parcialmente nuboso
        case 3: return "cloud";                                        // Cubierto
        case 45:
        case 48: return "foggy";                                       // Niebla / escarcha
        case 51:
        case 53:
        case 55:
        case 56:
        case 57: return "rainy";                                       // Llovizna (incl. helada)
        case 61:
        case 63:
        case 65:
        case 66:
        case 67:
        case 80:
        case 81:
        case 82: return "rainy";                                       // Lluvia / chubascos
        case 71:
        case 73:
        case 75:
        case 77:
        case 85:
        case 86: return "ac_unit";                                     // Nieve
        case 95:
        case 96:
        case 99: return "thunderstorm";                                // Tormenta
        default: return "device_thermostat";
        }
    }

    function refineData(json) {
        let temp = {};
        const current = json?.current || {};
        const daily = json?.daily || {};

        temp.wCode = current.weather_code ?? 0;
        temp.humidity = (current.relative_humidity_2m ?? 0) + "%";
        temp.windDir = root.degreesToCompass(current.wind_direction_10m ?? 0);
        temp.sunrise = (daily.sunrise && daily.sunrise[0]) ? daily.sunrise[0] : "0.0";
        temp.sunset = (daily.sunset && daily.sunset[0]) ? daily.sunset[0] : "0.0";
        temp.uv = (daily.uv_index_max && daily.uv_index_max[0]) ? daily.uv_index_max[0] : 0;
        temp.city = json?._cityLabel || root.city;

        const unit = "°C";
        temp.temp = (current.temperature_2m ?? 0) + unit;
        temp.tempFeelsLike = (current.apparent_temperature ?? 0) + unit;
        temp.wind = (current.wind_speed_10m ?? 0) + " km/h";
        temp.precip = (current.precipitation ?? 0) + " mm";

        // Open-Meteo da la presión en hPa.
        const pressHpa = current.surface_pressure ?? 0;
        temp.press = pressHpa + " hPa";

        // La visibilidad solo viene en el bloque hourly; cogemos el primer
        // valor (la hora actual, ya que el forecast empieza en el presente)
        const hourlyVisib = json?.hourly?.visibility;
        const visibMeters = (hourlyVisib && hourlyVisib.length > 0) ? hourlyVisib[0] : 0;
        temp.visib = (visibMeters / 1000).toFixed(1) + " km";

        // Previsión de los próximos días (Open-Meteo trae 4 con forecast_days=4:
        // hoy + 3 siguientes)
        const dates = daily.time || [];
        const codes = daily.weather_code || [];
        const maxTemps = daily.temperature_2m_max || [];
        const minTemps = daily.temperature_2m_min || [];
        temp.forecast = []
        for (let i = 1; i < dates.length; i++) {
            temp.forecast.push({
                date: dates[i],
                dayLabel: root.dayLabel(dates[i], i),
                wCode: codes[i] ?? 0,
                maxTemp: Math.round(maxTemps[i] ?? 0),
                minTemp: Math.round(minTemps[i] ?? 0),
                unit: unit,
            });
        }

        let now = new Date();
        temp.lastRefresh = now.toLocaleTimeString(Qt.locale(), "hh:mm") + " • " + now.toLocaleDateString(Qt.locale(), "dd/MM/yyyy");

        root.data = temp;
    }

    // --- Helper genérico de petición GET cancelable ---------------------
    //
    // xhrPropName: nombre de la propiedad de `root` donde se guarda la
    //   petición en curso (p.ej. "_geocodeXhr"), para poder cancelarla si
    //   llega una petición más reciente antes de que termine.
    // label: texto usado en los logs ("Geocoding", "Forecast", ...).
    // onSuccess(json): callback invocado con la respuesta ya parseada.
    //
    // OJO con el orden aquí: si primero llamamos a abort() y DESPUÉS
    // soltamos la referencia vieja, Qt puede invocar onreadystatechange de
    // forma SÍNCRONA dentro de abort(). En ese instante `root[xhrPropName]`
    // todavía apunta a la petición vieja, así que el guard de "¿me
    // reemplazaron?" no la detecta a tiempo y se acaba logueando un
    // "HTTP 0" que en realidad es solo una cancelación normal. Por eso aquí
    // soltamos la referencia ANTES de abortar.
    function _request(xhrPropName, url, label, onSuccess) {
        const prevXhr = root[xhrPropName];
        if (prevXhr) {
            root[xhrPropName] = null;
            prevXhr.abort();
        }

        const xhr = new XMLHttpRequest();
        root[xhrPropName] = xhr;
        xhr.timeout = 10000; // 10s

        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (xhr !== root[xhrPropName])
                return; // cancelada/reemplazada por otra petición, ignorar en silencio
            root[xhrPropName] = null;

            if (xhr.status !== 200) {
                console.error(`[WeatherService] ${label} fetch failed: HTTP ${xhr.status}`);
                return;
            }
            try {
                onSuccess(JSON.parse(xhr.responseText));
            } catch (e) {
                console.error(`[WeatherService] ${e.message}`);
            }
        };
        // onerror cubre fallos de transporte (DNS, conexión rechazada, TLS...)
        // que en algunos backends de Qt no siempre pasan por status !== 200.
        xhr.onerror = () => {
            if (xhr !== root[xhrPropName])
                return;
            root[xhrPropName] = null;
            console.error(`[WeatherService] ${label} fetch network error`);
        };
        xhr.ontimeout = () => {
            if (xhr !== root[xhrPropName])
                return;
            root[xhrPropName] = null;
            console.error(`[WeatherService] ${label} fetch timed out`);
        };
        xhr.open("GET", url);
        xhr.send();
    }

    // Pide el forecast a Open-Meteo para root.location.lat/lon ya resuelto
    function fetchForecast(cityLabel) {
        const url = "https://api.open-meteo.com/v1/forecast"
            + `?latitude=${root.location.lat}&longitude=${root.location.lon}`
            + "&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m,wind_direction_10m,surface_pressure"
            + "&hourly=visibility"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max"
            + "&forecast_days=4"
            + "&temperature_unit=celsius&wind_speed_unit=kmh&precipitation_unit=mm"
            + "&timezone=auto";

        root._request("_forecastXhr", url, "Forecast", (json) => {
            json._cityLabel = cityLabel;
            root.refineData(json);
        });
    }

    // Geocodifica root.city ("Nombre" o "Nombre,CC") y, si tiene éxito,
    // actualiza root.location y encadena fetchForecast()
    function geocodeCity() {
        const parts = root.city.split(",").map(p => p.trim());
        const name = parts[0];
        const countryCode = parts.length > 1 ? parts[1].toUpperCase() : "";

        const url = "https://geocoding-api.open-meteo.com/v1/search"
            + `?name=${encodeURIComponent(name)}&count=10&language=es&format=json`;

        root._request("_geocodeXhr", url, "Geocoding", (json) => {
            const results = json?.results || [];
            if (results.length === 0) {
                console.error(`[WeatherService] No se encontró la ciudad "${root.city}"`);
                return;
            }
            // Si se especificó país, filtramos; si no hay match exacto, cae al primero
            const match = countryCode
                ? (results.find(r => r.country_code === countryCode) || results[0])
                : results[0];

            root.location = { valid: true, lat: match.latitude, lon: match.longitude };
            const cityLabel = match.name + (match.admin1 ? `, ${match.admin1}` : "");
            root.fetchForecast(cityLabel);
        });
    }

    function getData() {
        if (NetworkService.currentNetwork == null) {
            console.warn("[WeatherService]","Sin conexion")
            return;
        }
        if (root.gpsActive && root.location.valid) {
            root.fetchForecast(root.city);
        } else {
            root.geocodeCity();
        }
    }

    Component.onCompleted: {
        if (!root.gpsActive) return;
        console.info("[WeatherService] Starting the GPS service.");
        positionSource.start();
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
                // Filtro de precisión: si el backend reporta horizontalAccuracy
                // (metros), descartamos fixes demasiado imprecisos. No todos
                // los backends (GeoClue2 vía WiFi/IP en portátiles sin chip
                // GPS dedicado, como este Zenbook) lo exponen -- si no viene,
                // dejamos pasar el fix igualmente.
                const accuracy = position.horizontalAccuracyValid ? position.horizontalAccuracy : -1;
                if (accuracy >= 0 && accuracy > 5000) {
                    console.warn(`[WeatherService] Descartando fix GPS con baja precisión (${accuracy}m)`);
                    return;
                }

                // Reasignar el objeto ENTERO, no mutar sus campos
                // (location.lat = x no dispara el cambio de la propiedad var).
                root.location = {
                    valid: true,
                    lat: position.coordinate.latitude,
                    lon: position.coordinate.longitude,
                };
                root.fetchForecast(I18nService.getTranslation("weather.my_location", "Mi ubicación"));
            } else {
                root.gpsActive = root.location.valid ? true : false;
                console.error("[WeatherService] Failed to get the GPS location.");
            }
        }

        onValidityChanged: {
            if (!positionSource.valid) {
                positionSource.stop();
                root.location = { valid: false, lat: 0, lon: 0 };
                root.gpsActive = false;

                Quickshell.execDetached([
                    "notify-send",
                    "Weather Service",
                    "Cannot find a GPS service. Using the fallback method instead.",
                    "-a",
                    "Shell"
                ]);
                console.error("[WeatherService] Could not aquire a valid backend plugin.");
            }
        }
    }

    Timer {
        running: !root.gpsActive
        repeat: true
        interval: root.fetchInterval
        triggeredOnStart: !root.gpsActive
        onTriggered: root.getData()
    }
}