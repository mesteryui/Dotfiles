// NotificationToast.qml
// ── Toast overlay (top-right) ──────────────────────────────────────────────

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Services.Notifications
import qs.Core
import qs.Core.Services as Services
import qs.Components

PanelWindow {
    id: root

    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors { top: true; right: true }
    margins { top: 50; right: 20; bottom: 0; left: 0 }

    visible: toastColumn.count > 0

    implicitWidth: 360
    implicitHeight: Math.max(1, toastColumn.implicitHeight)

    // ── Columna de toasts ──────────────────────────────────────────────────
    Column {
        id: toastColumn

        // BUG FIX 1: Column no soporta Layout.* — usar width/height directos
        // 'count' es una propiedad auxiliar para visible arriba
        property int count: repeater.count

            width: parent.width
            spacing: 10

            Repeater {
                id: repeater
                // trackedNotifications es un ObjectModel<Notification>, funciona directo
                model: Services.NotificationService.notifications
                // Dentro de Repeater en NotificationToast.qml
                delegate: // Delegate del toast — reemplaza el Timer y el onHoveredChanged
                Item {
                    id: toastWrapper

                    required property var modelData

                    width: toastColumn.width
                    height: notifItem.implicitHeight

                    opacity: 0
                    x: 40

                    // ── Timeout manual sin pause/resume ───────────────────────────────────
                    readonly property int totalMs: 6000
                        property int remainingMs: totalMs
                            property real pausedAt: 0

                                function startDismissTimer()
                                {
                                    if (notifItem.isCritical) return
                                    pausedAt = Date.now()
                                    dismissTimer.interval = remainingMs
                                    dismissTimer.restart()
                                }

                                function pauseDismissTimer()
                                {
                                    if (!dismissTimer.running) return
                                    dismissTimer.stop()
                                    // Cuánto tiempo quedaba cuando pausamos
                                    remainingMs = Math.max(0, remainingMs - (Date.now() - pausedAt))
                                }

                                function resumeDismissTimer()
                                {
                                    if (notifItem.isCritical || remainingMs <= 0) return
                                    pausedAt = Date.now()
                                    dismissTimer.interval = remainingMs
                                    dismissTimer.start()
                                }

                                Timer {
                                    id: dismissTimer
                                    repeat: false
                                    onTriggered: exitAnim.start()
                                }

                                Component.onCompleted: {
                                    enterAnim.start()
                                    startDismissTimer()
                                }

                                // ── Animaciones ───────────────────────────────────────────────────────
                                ParallelAnimation {
                                    id: enterAnim
                                    NumberAnimation { target: toastWrapper; property: "opacity"; to: 1; duration: 220; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: toastWrapper; property: "x"; to: 0; duration: 220; easing.type: Easing.OutCubic }
                                }

                                SequentialAnimation {
                                    id: exitAnim
                                    ParallelAnimation {
                                        NumberAnimation { target: toastWrapper; property: "opacity"; to: 0; duration: 180; easing.type: Easing.InCubic }
                                        NumberAnimation { target: toastWrapper; property: "x"; to: 40; duration: 180; easing.type: Easing.InCubic }
                                    }
                                    ScriptAction {
                                        script: Qt.callLater(() => toastWrapper.modelData.expire())
                                    }
                                }

                                // ── NotificationItem ──────────────────────────────────────────────────
                                NotificationItem {
                                    id: notifItem
                                    width: parent.width
                                    notification: toastWrapper.modelData

                                    onHoveredChanged: {
                                        if (notifItem.hovered)
                                        {
                                            toastWrapper.pauseDismissTimer()
                                        } else {
                                        toastWrapper.resumeDismissTimer()
                                    }
                                }

                                onDismissed: exitAnim.start()
                                onActionInvoked: id => toastWrapper.modelData.invoke()
                            }
                        }
                    }
                }
            }