pragma Singleton
pragma ComponentBehavior: Bound

import qs.Core.Modules
import "WeatherFormat.js" as WeatherFormat
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // --- Configuración y bindings ---
    readonly property int fetchInterval: (ConfigService.configs.weather.reloadTime ?? 10) * 60 * 1000
    readonly property string city: ConfigService.configs.weather.city ?? ""
    readonly property bool configGpsEnabled: ConfigService.configs.weather.autoLocation ?? false

    // --- Estados para la Interfaz de Usuario (UI) ---
    readonly property bool isLoading: root._socketPending
    property bool isError: false
    property string errorMessage: ""
    property double lastFetchTimestamp: 0
    property int _retryCount: 0

    property bool _socketPending: false
    property bool socketConnected: false

    // Icono dinámico reactivo (Día / Noche)
    readonly property string icon: Icons.getWeatherIcon(data.wCode, data.isDay)
    readonly property string temperature: data.temp

    // --- Ubicación (reflejada del backend vía socket) ---
    property var location: ({
                                valid: false,
                                city: "",
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
                            alertLevel: 0,
                            alertCount: 0,
                            alerts: [],
                            aqi: -1,
                            aqiLevel: 0
                        })

    property double lastAlertsTimestamp: 0

    property string _gpsLabel: ""
    property bool _bootFetchDone: false

    // ── Socket Unix del backend shinro (datos de clima) ──
    // Conexión persistente: el backend empuja tras el hello y nunca cierra.
    readonly property string socketPath: {
        const rt = Quickshell.env("XDG_RUNTIME_DIR");
        if (rt)
            return rt + "/shinro";
        const uid = Quickshell.env("UID");
        return uid ? "/run/user/" + uid + "/shinro" : "";
    }

    Socket {
        id: shinroSocket
        path: root.socketPath

        parser: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                try {
                    const msg = JSON.parse(data);
                    if (msg.type === "error") {
                        root._socketPending = false;
                        console.warn("[WeatherService] " + msg.message);
                        return;
                    }
                    if (msg.type !== "update" || msg.module !== "weather")
                        return;

                    root._socketPending = false;
                    const d = msg.data;
                    if (!d || !d.current || !d.daily || !d.hourly) {
                        console.warn("[WeatherService] payload de socket incompleto");
                        return;
                    }
                    // El backend entrega la misma forma que Open-Meteo más
                    // _cityLabel, _aqi y _alerts ya procesados.
                    root.refineData(d, true);
                } catch (e) {
                    console.warn("[WeatherService] mensaje inválido:", e);
                }
            }
        }

        onConnectionStateChanged: {
            if (!shinroSocket.connected)
                return;
            root._sendHello();
        }

        onError: error => {
            // No tocar `connected` aquí: reentrar en onSocketError de
            // Quickshell provoca un segfault. reconnectTimer se encarga de
            // reintentar cuando `connected` pase a false.
        }
    }

    Timer {
        id: reconnectTimer
        interval: 2000
        repeat: true
        running: root.socketPath !== "" && !shinroSocket.connected
        onTriggered: shinroSocket.connected = true
    }

    onConfigGpsEnabledChanged: {
        if (!ConfigService.ready || !root._bootFetchDone)
            return;
        // El modo (auto/manual) viaja en el hello: renegociar para que el
        // backend use la ubicación correcta.
        root._sendHello();
    }

    onCityChanged: {
        if (!ConfigService.ready || !root._bootFetchDone)
            return;
        root.location.valid = false;
        root.location.city = "";
        // El backend guarda la ciudad en el hello. Renegociar aquí evita que
        // siga empujando el clima de la ciudad anterior.
        root._sendHello();
    }

    onFetchIntervalChanged: {
        if (!ConfigService.ready || !root._bootFetchDone)
            return;
        // El intervalo viaja en el hello: el backend reconfigura el pump en
        // caliente, sin esperar al tick anterior ni reconectar.
        root._sendHello();
    }

    function degreesToCompass(deg) {
        return WeatherFormat.degreesToCompass(deg);
    }

    function dayLabel(dateStr, index) {
        if (index === 0)
            return I18nService.getTranslation("weather.today", "Hoy");
        if (index === 1)
            return I18nService.getTranslation("weather.tomorrow", "Mañana");
        const d = new Date(dateStr);
        return d.toLocaleDateString(Qt.locale(), "ddd");
    }

    function aqiLevelOf(value) {
        return WeatherFormat.aqiLevelOf(value);
    }

    function refineData(json, fromSocket = false) {
        const daily = json?.daily || {};
        const hourly = json?.hourly || {};
        if ((daily.time || []).length === 0 || (hourly.time || []).length === 0) {
            root.isError = true;
            root.errorMessage = "Datos incompletos";
            console.warn("[WeatherService] Forecast: respuesta sin daily/hourly");
            root._scheduleRetry();
            return;
        }
        let temp = {};
        // Valores por defecto completos: los paneles leen aqi/alerts aunque
        // el proveedor aún no los haya rellenado.
        temp.aqi = -1;
        temp.aqiLevel = 0;
        temp.alertLevel = 0;
        temp.alertCount = 0;
        temp.alerts = [];
        const current = json?.current || {};
        const unit = "°C";

        temp.wCode = current.weather_code ?? 0;
        temp.isDay = current.is_day ?? 1;
        temp.humidity = (current.relative_humidity_2m ?? 0) + "%";
        temp.windDir = root.degreesToCompass(current.wind_direction_10m ?? 0);
        temp.sunrise = (daily.sunrise && daily.sunrise[0]) ? daily.sunrise[0].split("T")[1]?.slice(0, 5)
                                                             ?? daily.sunrise[0] : "--:--";
        temp.sunset = (daily.sunset && daily.sunset[0]) ? daily.sunset[0].split("T")[1]?.slice(0, 5)
                                                          ?? daily.sunset[0] : "--:--";
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

        // AQI y avisos: vienen ya procesados del backend.
        if (json._aqi !== undefined && json._aqi !== null) {
            temp.aqi = json._aqi;
            temp.aqiLevel = root.aqiLevelOf(json._aqi);
        }
        if (Array.isArray(json._alerts)) {
            temp.alertLevel = json._alerts.length > 0 ? json._alerts[0].level : 0;
            temp.alertCount = json._alerts.length;
            temp.alerts = json._alerts;
        }

        // Refleja la ciudad resuelta por el backend.
        if (json?._cityLabel) {
            root.location.city = json._cityLabel;
            root.location.valid = true;
        }

        root.data = temp;
        root.isError = false;
        root.errorMessage = "";
        root.lastFetchTimestamp = Date.now();
        root._retryCount = 0;
        retryTimer.stop();
    }

    function _retryDelay() {
        const step = Math.max(0, Math.min(5, root._retryCount));
        return Math.min(300000, 15000 * Math.pow(2, step));
    }

    function _scheduleRetry() {
        if (retryTimer.running)
            return;
        retryTimer.interval = root._retryDelay();
        root._retryCount++;
        retryTimer.restart();
    }

    Timer {
        id: retryTimer
        repeat: false
        onTriggered: {
            if (root.isError || root.data.lastRefresh === "--:--")
                root.getData();
        }
    }

    // Suscribe este cliente al módulo weather. El backend responde con un
    // snapshot inmediato y luego empuja según el intervalo. Es idempotente:
    // reenviarlo actualiza ciudad/modo/idioma sin reiniciar los pumps.
    function _sendHello() {
        if (!shinroSocket.connected)
            return false;
        root._socketPending = true;
        shinroSocket.write(JSON.stringify({
            type: "hello",
            location: {
                mode: root.configGpsEnabled ? "auto" : "manual",
                city: root.city
            },
            intervals: {
                system: 0,
                weather: Math.max(1, Math.round(root.fetchInterval / 1000))
            },
            lang: (I18nService.language || "es").toLowerCase().slice(0, 2)
        }) + "\n");
        shinroSocket.flush();
        return true;
    }

    function getData() {
        // Solo hay una vía: el socket del backend. Si no está conectado,
        // reconnectTimer se encarga de reintentar y al conectar envía el
        // hello automáticamente (onConnectionStateChanged).
        root._sendHello();
    }

    function forceRefresh() {
        if (Date.now() - root.lastFetchTimestamp < 3000)
            return;
        root.getData();
    }

    Component.onCompleted: {
        shinroSocket.connected = true;
        if (ConfigService.ready) {
            root._bootFetchDone = true;
            root.getData();
        }
    }

    Connections {
        target: ConfigService

        function onReadyChanged() {
            if (ConfigService.ready && !root._bootFetchDone) {
                root._bootFetchDone = true;
                root.getData();
            }
        }
    }
}
