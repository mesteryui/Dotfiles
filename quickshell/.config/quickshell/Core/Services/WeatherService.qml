pragma Singleton
import QtQuick
import Quickshell

// WeatherService.qml
// Fuente: Open-Meteo (sin API key). Coordenadas vienen de LocationService.
// Se re-consulta solo: al arrancar, cada REFRESH_INTERVAL, y cuando
// LocationService cambia de coordenadas — no hace falta llamar a nada
// manualmente desde fuera salvo refresh() para un botón de "actualizar".

Singleton {
    id: root

    readonly property int refreshInterval: 15 * 60 * 1000 // 15 min
    readonly property int requestTimeout: 10 * 1000        // 10 s

    property real temperature: NaN
    property int weatherCode: -1
    property real windSpeed: NaN
    property date lastUpdated

    property bool loading: false
    property bool error: false        // fallo de red / respuesta inválida
    readonly property bool hasLocation: !isNaN(LocationService.latitud) && !isNaN(LocationService.longitud)

    // Referencia al XHR en curso, para poder abortarlo si llega una
    // petición nueva o salta el timeout — evita condiciones de carrera
    // donde una respuesta vieja sobreescribe a una más reciente.
    property var _activeRequest: null

    // ── Disparo automático ──────────────────────────────────────────
    Timer {
        interval: root.refreshInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // Si LocationService resuelve o cambia la ubicación (ej. terminó la
    // geolocalización por IP, o el usuario editó el config), disparamos
    // una consulta nueva sin esperar a los 15 min.
    Connections {
        target: LocationService
        function onLatitudChanged() { root.refresh() }
        function onLongitudChanged() { root.refresh() }
    }

    // ── API pública ──────────────────────────────────────────────────
    function refresh() {
        if (!root.hasLocation) {
            // Todavía no hay coordenadas (LocationService sigue resolviendo,
            // o no hay config ni fallback). No es un error de red: no lo
            // marcamos como tal para no confundir "sin ubicación" con
            // "sin conexión" en la UI.
            return
        }
        root._fetch(LocationService.latitud, LocationService.longitud)
    }

    // ── Interno ─────────────────────────────────────────────────────
    function _fetch(lat, lon) {
        // Si ya hay una petición en vuelo, la cancelamos: la nueva manda.
        if (root._activeRequest) {
            root._activeRequest.abort()
            root._activeRequest = null
        }

        root.loading = true
        root.error = false

        const xhr = new XMLHttpRequest()
        root._activeRequest = xhr

        const timeoutTimer = Qt.createQmlObject(
            'import QtQuick; Timer { interval: ' + root.requestTimeout + '; running: true }',
            root, "weatherTimeoutTimer"
        )
        timeoutTimer.triggered.connect(() => {
            if (root._activeRequest === xhr) {
                xhr.abort()
                root.loading = false
                root.error = true
                root._activeRequest = null
            }
            timeoutTimer.destroy()
        })

        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return

            // Si ya no somos la petición activa (fuimos abortados o
            // reemplazados), ignoramos silenciosamente esta respuesta.
            if (root._activeRequest !== xhr) return

            root._activeRequest = null
            root.loading = false
            timeoutTimer.destroy()

            if (xhr.status !== 200) {
                root.error = true
                return
            }

            try {
                const data = JSON.parse(xhr.responseText)
                root.temperature = data.current.temperature_2m
                root.weatherCode = data.current.weather_code
                root.windSpeed = data.current.wind_speed_10m
                root.lastUpdated = new Date()
                root.error = false
            } catch (e) {
                console.warn("WeatherService: respuesta inesperada de Open-Meteo:", e)
                root.error = true
            }
        }

        const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current=temperature_2m,weather_code,wind_speed_10m`
        xhr.open("GET", url)
        xhr.send()
    }
}
