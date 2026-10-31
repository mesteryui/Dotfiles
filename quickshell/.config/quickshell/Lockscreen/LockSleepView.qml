// LockSleepView — vista dormida: batería, reloj, avisos, MPRIS y pastilla.
// Extraído de LockScreenContent.qml.
import qs.Core
import qs.Core.Services
import qs.Primitives
import QtQuick
import QtQuick.Layouts
import M3Shapes

Item {
    id: root

    property bool isAwake: false
    property bool isPrimary: true
    property real mprisPosition: 0
    property int stageDuration: 350
    // Gesto en curso (lo aporta LockDragArea).
    property real dragDy: 0
    property bool dragging: false

    signal wakeUp

    // Respiración de la pastilla de despertar (Sunny↔VerySunny):
    // invita a tocarla. Solo corre dormido.
    property int wakeBreathShape: MaterialShape.Sunny

    Timer {
        id: breathTimer

        interval: 1600
        running: !root.isAwake
        repeat: true
        onTriggered: root.wakeBreathShape = root.wakeBreathShape === MaterialShape.Sunny
                     ? MaterialShape.VerySunny : MaterialShape.Sunny
    }

    Component.onDestruction: {
        breathTimer.stop();
    }

    anchors.fill: parent
    // Por encima de LockDragArea (z:1): los botones del MPRIS y la pastilla
    // reciben sus clics primero; el fondo transparente deja pasar el
    // resto a LockDragArea para despertar. Si sleepView quedase por debajo,
    // ningún z interno del MPRIS podría rescatar los clics.

    z: 2
    // Mientras se arrastra, la vista dormida se atenúa y el panel de
    // auth asoma siguiendo al dedo (misma dirección del swipe).

    opacity: isAwake ? 0 : Math.max(0, 1 - dragDy / 220)

    visible: opacity > 0

    Behavior on opacity {
        enabled: !root.dragging

        NumberAnimation {
            duration: root.stageDuration
            easing.type: Easing.OutCubic
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Appearance.spacing.large

        // Chip de batería M3 (tonal, pill)
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: batteryRow.implicitWidth + 28
            implicitHeight: 36
            radius: Appearance.shape.full
            color: Qt.alpha(Appearance.md3.surface_container_high, 0.72)
            border.width: Appearance.border.width
            border.color: Appearance.border.subtleOn(color)

            RowLayout {
                id: batteryRow

                anchors.centerIn: parent
                spacing: Appearance.spacing.small

                MaterialIcon {
                    icon: BatteryService.materialIcon
                    size: 20
                    color: Appearance.md3.on_surface_variant
                }
                StyledText {
                    text: BatteryService.percentage + "%"
                    font.pixelSize: Appearance.typeScale.titleSmall
                    font.weight: Font.DemiBold
                    color: Appearance.md3.on_surface_variant
                }
            }
        }

        // Reloj hero estilo Pixel
        LockScreenClock {
            Layout.alignment: Qt.AlignHCenter
            compact: false
        }

        // Notificaciones pendientes (solo lectura: cualquier toque
        // en esta vista despierta vía LockDragArea).
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            visible: NotificationData.history.count > 0
            implicitWidth: notifRow.implicitWidth + 28
            implicitHeight: 36
            radius: Appearance.shape.full
            color: Qt.alpha(Appearance.md3.surface_container_high, 0.72)
            border.width: Appearance.border.width
            border.color: Appearance.border.subtleOn(color)

            RowLayout {
                id: notifRow

                anchors.centerIn: parent
                spacing: Appearance.spacing.small

                MaterialIcon {
                    icon: "notifications"
                    size: 20
                    color: Appearance.md3.primary
                }
                StyledText {
                    text: NotificationData.history.count + " " + I18nService.getTranslation(
                              "lockscreen.notifications_unread", "sin leer")
                    font.pixelSize: Appearance.typeScale.titleSmall
                    font.weight: Font.Medium
                    color: Appearance.md3.on_surface_variant
                }
            }
        }

        // MPRIS en el estado dormido (si hay música).
        // Por encima de LockDragArea para que play/pause/next sean usables
        // directamente sin despertar (estilo Pixel).
        LockScreenMprisCard {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 400
            z: 2
            visible: root.isPrimary && MprisService.activePlayer !== null
            mprisPosition: mprisPosition
        }
    }

    // Pastilla inferior estilo Pixel: swipe / tecla para despertar.
    // Reacciona al arrastre: sube con el dedo y cambia el texto a
    // "suelta para desbloquear" al superar el umbral.
    Rectangle {
        id: wakePill

        Accessible.role: Accessible.Button
        Accessible.name: I18nService.getTranslation("lockscreen.wake_hint",
                                                    "Desliza hacia arriba o pulsa una tecla")

        z: 2
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: 40
        }
        implicitWidth: wakeRow.implicitWidth + 32
        implicitHeight: 48
        radius: Appearance.shape.full
        color: root.dragDy > 70 ? Qt.alpha(Appearance.md3.primary_container, 0.85) : Qt.alpha(
                                      Appearance.md3.surface_container_high, 0.72)
        border.width: Appearance.border.width
        border.color: root.dragDy > 70 ? Appearance.border.focus : Appearance.border.subtleOn(color)

        transform: Translate {
            y: -Math.min(28, root.dragDy * 0.22)

            Behavior on y {
                enabled: !root.dragging

                NumberAnimation {
                    duration: root.stageDuration
                    easing.type: Easing.OutCubic
                }
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: 180
            }
        }

        RowLayout {
            id: wakeRow

            anchors.centerIn: parent
            spacing: Appearance.spacing.small

            // Flecha en forma expresiva que respira: la invitación a
            // despertar. Región cuadrada, apta para morph.
            Item {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                Layout.alignment: Qt.AlignVCenter

                MaterialShape {
                    anchors.fill: parent
                    shape: root.wakeBreathShape
                    animationDuration: 1400
                    color: Appearance.md3.primary_container

                    MaterialIcon {
                        id: swipeArrow

                        anchors.centerIn: parent
                        icon: "keyboard_arrow_up"
                        size: 20
                        color: Appearance.md3.on_primary_container
                    }
                }

                SequentialAnimation on y {
                    loops: Animation.Infinite
                    running: !root.isAwake && !root.dragging

                    NumberAnimation {
                        from: 0
                        to: -4
                        duration: 700
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        from: -4
                        to: 0
                        duration: 700
                        easing.type: Easing.InOutSine
                    }
                }
            }

            StyledText {
                text: root.dragDy > 70 ? I18nService.getTranslation("lockscreen.release_to_unlock",
                                                                    "Suelta para desbloquear") :
                                         I18nService.getTranslation("lockscreen.wake_hint",
                                                                    "Desliza hacia arriba o pulsa una tecla")
                color: root.dragDy > 70 ? Appearance.md3.on_primary_container :
                                          Appearance.md3.on_surface_variant
                font.pixelSize: Appearance.typeScale.labelMedium
                font.weight: Font.Medium
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.wakeUp()
        }
    }
}
