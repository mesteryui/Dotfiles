import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Core.Services as Services

PanelWindow {
    id: root

    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: WlrLayershell.Ignore
    WlrLayershell.namespace: "notifications_popups"

    // Posicionado en la parte superior derecha de la pantalla
    anchors.top: true
    anchors.right: true
    margins.top: 50
    margins.right: 15

    color: "transparent"

    // Dimensiones dinámicas basadas en las notificaciones activas
    implicitWidth: 340
    implicitHeight: Math.max(1, popupListView.contentHeight)

    visible: Services.NotificationService.notifications.length > 0

    ListView {
        id: popupListView
        anchors.fill: parent
        model: Services.NotificationService.notifications
        spacing: 10
        interactive: false // Las notificaciones no se deslizan, solo flotan

        delegate: NotificationPopupCard {
            notification: modelData
            width: popupListView.width
        }

        // Transición de entrada (slide desde la derecha y fade)
        add: Transition {
            NumberAnimation {
                property: "x"
                from: 150
                to: 0
                duration: 250
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: 200
            }
        }

        // Transición de salida (slide a la derecha y fade)
        remove: Transition {
            NumberAnimation {
                property: "x"
                to: 150
                duration: 200
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                property: "opacity"
                to: 0.0
                duration: 150
            }
        }

        // Transición de reordenamiento de los elementos restantes
        displaced: Transition {
            NumberAnimation {
                properties: "y"
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
    }
}
