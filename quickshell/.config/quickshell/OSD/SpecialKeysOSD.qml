import Quickshell
import Quickshell.Widgets
import QtQuick
import Quickshell.Hyprland // Módulo para GlobalShortcut
import ".." // O la ruta donde esté tu archivo de colores/BaseOSD
import "../Services" as Services
BaseOSD {
    id: keyOSD
    
    // Dimensiones dinámicas basadas en el tamaño del texto e icono + paddings
    implicitWidth: contentRow.implicitWidth + 40
    implicitHeight: contentRow.implicitHeight + 20

    property string osdIcon: ""
    property string osdText: ""
    property color activeColor: Colors.on_surface

    // Variables internas para mantener un rastro del estado alternado (toggle)
    property bool capsActive: false
    property bool numActive: false

    // ── CAPTURA INTERNA DE TECLAS ─────────────────────────
    

    // ── INTERFAZ GRÁFICA INTERNA ──────────────────────────
    Rectangle {
        color: Colors.surface
        radius: 30
        anchors.fill: parent

        border.color: Colors.outline
        border.width: 1

        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: 12
            

            IconImage {
                width: 30
                height: 30
                source: keyOSD.osdIcon ? Quickshell.iconPath(keyOSD.osdIcon) : ""
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                font.family: Services.ConfigService.getConfig("fontSans") || "sans-serif"
                font.pixelSize: 22
                font.bold: true
                color: Colors.on_surface
                text: keyOSD.osdText
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}