// ShinroSocket.qml
// Componente reutilizable para conectar Quickshell al backend shinro
// a través del socket Unix "shinro".
//
// Uso:
//   ShinroSocket {
//       id: shinro
//       city: "Madrid"
//       locationMode: "manual"
//       onSystemData: (data) => { /* actualizar UI */ }
//       onWeatherData: (data) => { /* actualizar UI */ }
//   }

import QtQuick 2.15
import Quickshell.Io

Item {
    id: root

    /// Ciudad para modo manual de ubicación
    property string city: "Madrid"
    /// "auto" para Geoclue, "manual" para ciudad fija
    property string locationMode: "manual"
    /// Intervalo de actualización de recursos del sistema (segundos)
    property int systemInterval: 5
    /// Intervalo de actualización de clima (segundos)
    property int weatherInterval: 600

    /// Señal emitida cuando llegan datos de system
    signal systemData(var data)
    /// Señal emitida cuando llegan datos de weather
    signal weatherData(var data)
    /// Señal emitida cuando el socket se conecta
    signal connectedChanged(bool connected)

    // Ruta del socket Unix de shinro.
    // Usa XDG_RUNTIME_DIR para adaptarse al usuario actual.
    property string socketPath: Qt.format("/run/user/%1/shinro").arg(Qt.application.uid)

    Socket {
        id: shinroSocket
        path: root.socketPath
        connected: true

        onConnected: {
            // Enviar handshake inicial al backend
            var hello = JSON.stringify({
                type: "hello",
                location: {
                    mode: root.locationMode,
                    city: root.city
                },
                intervals: {
                    system: root.systemInterval,
                    weather: root.weatherInterval
                }
            });
            shinroSocket.write(hello);
            shinroSocket.flush();
            root.connectedChanged(true);
        }

        onDisconnected: {
            root.connectedChanged(false);
        }

        onMessage: (msg) => {
            try {
                var data = JSON.parse(msg);
                if (data.type === "update") {
                    if (data.module === "system") {
                        root.systemData(data.data);
                    } else if (data.module === "weather") {
                        root.weatherData(data.data);
                    }
                } else if (data.type === "hello") {
                    console.log("shinro: handshake aceptado", data.ok);
                } else if (data.type === "error") {
                    console.error("shinro backend error:", data.message);
                }
            } catch (e) {
                console.error("shinro: no se pudo parsear mensaje:", msg, e);
            }
        }

        onError: (err) => {
            console.error("shinro socket error:", err);
        }
    }

    /// Envía una consulta puntual (get) al backend para un módulo.
    function request(moduleName) {
        if (shinroSocket.connected) {
            var msg = JSON.stringify({ type: "get", module: moduleName });
            shinroSocket.write(msg);
            shinroSocket.flush();
        }
    }

    /// Cambia el modo de ubicación en tiempo de ejecución.
    function setLocationMode(mode, city) {
        root.locationMode = mode;
        root.city = city;
        if (shinroSocket.connected) {
            var msg = JSON.stringify({
                type: "hello",
                location: { mode: mode, city: city },
                intervals: { system: root.systemInterval, weather: root.weatherInterval }
            });
            shinroSocket.write(msg);
            shinroSocket.flush();
        }
    }
}
