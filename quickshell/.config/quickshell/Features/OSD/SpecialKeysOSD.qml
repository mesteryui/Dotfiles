import Quickshell
import Quickshell.Widgets
import QtQuick
import Quickshell.Hyprland // Módulo para GlobalShortcut
import qs.Core
import qs.Core.Services as Services
import qs.Components

BaseOSD {
    id: keyOSD
    
    // Dimensiones dinámicas basadas en el tamaño del texto e icono + paddings
    implicitWidth: contentRow.implicitWidth + 40
    implicitHeight: contentRow.implicitHeight + 20

    property string osdIcon: "keyboard"
    property string osdText: ""
    property color activeColor: Colors.md3.on_surface

    // Variables internas para mantener un rastro del estado alternado (toggle)
    property bool capsActive: false
    property bool numActive: false

    // ── INTERFAZ GRÁFICA INTERNA ──────────────────────────
    Rectangle {
        color: Colors.md3.surface
        radius: 30
        anchors.fill: parent

        border.color: Colors.md3.outline
        border.width: 1

        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: 12
            

            MaterialIcon {
                icon: keyOSD.osdIcon
                size: 30
                color: Colors.md3.on_surface
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                font.family: Services.ConfigService.getConfig("fontSans") || "sans-serif"
                font.pixelSize: 22
                font.bold: true
                color: Colors.md3.on_surface
                text: keyOSD.osdText
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}