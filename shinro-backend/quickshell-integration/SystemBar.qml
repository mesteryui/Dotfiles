// SystemBar.qml
// Ejemplo de barra de sistema que lee recursos desde el backend shinro.
// Filtra mensajes con module === "system".

import QtQuick 2.15
import QtQuick.Layouts 1.15

import "ShinroSocket.qml" as Shinro

Item {
    id: root

    width: 300
    height: 40

    Shinro.ShinroSocket {
        id: shinro
        locationMode: "manual"
        city: "Madrid"
        systemInterval: 5
        weatherInterval: 600

        onSystemData: (data) => {
            ramText.text = qsTr("RAM: %1%").arg(data.ram_percent.toFixed(1));
            cpuText.text = qsTr("CPU: %1%").arg(data.cpu_percent.toFixed(1));
            swapText.text = qsTr("Swap: %1%").arg(data.swap_percent.toFixed(1));
            tempText.text = qsTr("Temp: %1°C").arg(data.temperature_c.toFixed(1));
            upText.text = qsTr("Up: %1s").arg(data.uptime_seconds);
        }

        onWeatherData: (data) => {
            // SystemBar no usa clima, pero lo recibe igual si está suscrito
            console.log("system bar ignorando weather:", data);
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 8

        Text { id: ramText; text: "RAM: --%" }
        Text { id: cpuText; text: "CPU: --%" }
        Text { id: swapText; text: "Swap: --%" }
        Text { id: tempText; text: "Temp: --°C" }
        Text { id: upText; text: "Up: --s" }
    }
}
