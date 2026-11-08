// shell.qml - Ejemplo de integración completa en Quickshell (shinro)
// Muestra cómo usar dos componentes distintos sobre el mismo socket shinro.

import QtQuick 2.15
import QtQuick.Layouts 1.15

import "ShinroSocket.qml" as Shinro
import "SystemBar.qml"
import "WeatherWidget.qml"

Item {
    id: root
    width: 800
    height: 600

    ColumnLayout {
        anchors.fill: parent
        spacing: 20
        anchors.margins: 20

        // Componente 1: Barra de recursos del sistema
        // Filtra únicamente mensajes con module === "system"
        SystemBar {
            Layout.alignment: Qt.AlignHCenter
        }

        // Componente 2: Widget de clima
        // Filtra únicamente mensajes con module === "weather"
        WeatherWidget {
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
