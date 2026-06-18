import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Core
import qs.Core.Services as Services
import qs.Components

// ── Toast overlay (top-right) ──────────────────────────────────────────────
PanelWindow {
    id: root

    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors { top: true; right: true }
    margins { top: 12; right: 12; bottom: 0; left: 0 }

    visible: toastModel.count > 0

    implicitWidth: 360
    implicitHeight: Math.max(1, toastColumn.implicitHeight)

    // ── Modelo local de toasts activos ────────────────────────────────────
    ListModel { id: toastModel }

    // ── Detectar notificaciones nuevas via señal del servicio ─────────────
    Connections {
        target: Services.NotificationService

        function onNotificationAdded(notif) {
            // 1. Ignorar si DND está activo
            if (Services.NotificationService.dnd) return;
            
            // 2. Ignorar notificaciones de la "generación anterior" (evita spam al recargar la config)
            if (notif.lastGeneration) return;

            console.log("[NotificationLister] Mostrando Toast para:", notif.summary);

            // Deduplicar por id
            let dup = false
            for (let j = 0; j < toastModel.count; j++) {
                if (toastModel.get(j).notifId === notif.id) { 
                    dup = true; 
                    break;
                }
            }
            
            if (!dup) {
                toastModel.append({ notifId: notif.id, notif: notif });
            }
        }
    }

    // ── Columna de toasts ─────────────────────────────────────────────────
    Column {
        id: toastColumn
        width: parent.width
        spacing: 10

        Repeater {
            model: toastModel

            delegate: Item {
                id: toastDelegate

                readonly property var notif: model.notif

                width: toastColumn.width
                height: notifItem.implicitHeight
                clip: true

                // ── Auto-dismiss ──────────────────────────────────────────
                Timer {
                    id: autoDismiss
                    interval: 6000
                    running: true
                    repeat: false
                    onTriggered: removeToast()
                }

                function removeToast() {
                    for (let i = 0; i < toastModel.count; i++) {
                        if (toastModel.get(i).notifId === model.notifId) {
                            toastModel.remove(i)
                            break
                        }
                    }
                }

                // ── Contenido ─────────────────────────────────────────────
                NotificationItem {
                    id: notifItem
                    modelData: toastDelegate.notif
                    width: parent.width
                }

                // ── Pausa el timer mientras el cursor está encima ─────────
                HoverHandler {
                    onHoveredChanged: hovered ? autoDismiss.stop() : autoDismiss.restart()
                }

                // ── Barra de progreso del timeout ─────────────────────────
                Rectangle {
                    anchors {
                        bottom: parent.bottom
                        left: parent.left; right: parent.right
                        bottomMargin: 3
                        leftMargin: 16; rightMargin: 16
                    }
                    height: 2
                    radius: 1
                    color: Colors.md3.primary
                    opacity: 0.45

                    NumberAnimation on width {
                        from: toastDelegate.width - 32
                        to: 0
                        duration: autoDismiss.interval
                        easing.type: Easing.Linear
                        running: autoDismiss.running
                    }
                }

                // ── Slide-in desde la derecha + fade ──────────────────────
                NumberAnimation on x {
                    from: 380; to: 0
                    duration: 320; easing.type: Easing.OutCubic
                    running: true
                }
                NumberAnimation on opacity {
                    from: 0; to: 1
                    duration: 260; easing.type: Easing.OutCubic
                    running: true
                }
            }
        }
    }
}
