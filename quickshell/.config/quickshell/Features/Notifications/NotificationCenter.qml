pragma ComponentBehavior: Bound

import qs.Core
import qs.Core.Services
import qs.Primitives
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import M3Shapes

// Formas expresivas (m3shapes): el toggle de DND (32×32) y el icono del
// estado vacío (100×100) usan MaterialShape porque son regiones cuadradas.
// El fondo del panel y el link "Clear all" siguen siendo Rectangle: MaterialShape
// normaliza su silueta a un cuadrado de lado min(width, height), así que en un
// contenedor ancho y no cuadrado la forma quedaría encogida en el centro con
// contenido sobresaliendo — mismo problema ya resuelto en los chips del MPRIS.
// qmllint disable uncreatable-type
PanelWindow {
    id: root
    // qmllint enable uncreatable-type

    required property ListModel historyModel

    // Cap the notification list height; beyond this it scrolls instead of
    // pushing the panel taller than the screen.
    readonly property int maxListHeight: 420

    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "quickshell:notification-center"

    HyprlandFocusGrab {
        windows: [root]
        active: root.visible
        onCleared: Qt.callLater(() => {
            NotificationService.centerOpen = false;
        })
    }

    margins {
        top: 12
        right: 12
    }
    implicitWidth: 380

    implicitHeight: centerCol.implicitHeight + 32

    color: "transparent"

    exclusionMode: ExclusionMode.Ignore

    // Sombra difusa detrás del panel en vez de un borde duro — elevación
    // suave al estilo GNOME/libadwaita sobre una superficie tonal MD3.
    MultiEffect {
        source: panelBg
        anchors.fill: panelBg
        shadowEnabled: true
        shadowColor: Appearance.md3.shadow
        shadowOpacity: 0.22
        shadowBlur: 0.9
        shadowVerticalOffset: 3
        shadowHorizontalOffset: 0
    }

    Shortcut {
        sequence: "d"
        enabled: root.visible && (root.historyModel ? root.historyModel.count : 0) > 0
        onActivated: root.historyModel.clear()
    }

    // Alternar el modo No Molestar (DND) con la tecla 'N'
    Shortcut {
        sequence: "n"
        enabled: root.visible
        onActivated: NotificationService.toggleDnd()
    }

    // Borrar la notificación actualmente seleccionada con 'Delete' o 'Supr'
    Shortcut {
        sequence: "Delete"
        enabled: root.visible && (root.historyModel ? root.historyModel.count : 0) > 0 && historyList.currentIndex >= 0
        onActivated: root.historyModel.remove(historyList.currentIndex)
    }

    Rectangle {
        id: panelBg

        anchors.fill: parent
        radius: Appearance.shape.verylarge
        color: Appearance.md3.surface_container_low
        border.width: 1
        border.color: Qt.alpha(Appearance.md3.outline_variant, 0.5)

        ColumnLayout {
            id: centerCol

            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                StyledText {
                    Layout.fillWidth: true
                    text: I18nService.getTranslation("notifications.title", "")
                    color: Appearance.md3.on_surface
                    font.family: Appearance.font.sans
                    font.variableAxes: Appearance.font.variableAxes.title
                    font.pixelSize: Appearance.font.pixelSize.larger
                }

                // --- Contador: insignia tonal en forma de píldora ---
                Rectangle {
                    visible: (root.historyModel ? root.historyModel.count : 0) > 0
                    implicitWidth: countLabel.implicitWidth + 16
                    implicitHeight: 26
                    radius: Appearance.shape.full
                    color: Appearance.md3.primary_container

                    StyledText {
                        id: countLabel

                        anchors.centerIn: parent
                        text: root.historyModel ? root.historyModel.count : 0
                        color: Appearance.md3.on_primary_container
                        font.family: Appearance.font.sans
                        font.variableAxes: Appearance.font.variableAxes.numbers
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.bold: true
                    }
                }

                // --- DND: botón de icono tonal M3 (Circle ↔ Cookie4Sided).
                // 40×40 es cuadrado, así que la silueta expresiva se ve completa.
                // El halo de foco usa la MISMA forma que el fondo para que el
                // anillo acompañe la morfología en vez de pelear con ella, y
                // nada cambia de tamaño con el foco (sin saltos de layout).
                Item {
                    id: dndToggle

                    implicitWidth: 40
                    implicitHeight: 40
                    activeFocusOnTab: true

                    readonly property int dndShape: NotificationService.dnd ? MaterialShape.Cookie4Sided : MaterialShape.Circle
                    readonly property bool dndOn: NotificationService.dnd

                    Accessible.role: Accessible.Button
                    Accessible.checkable: true
                    Accessible.checked: dndToggle.dndOn
                    Accessible.name: I18nService.getTranslation("notifications.dnd", "No molestar")
                    Accessible.description: dndToggle.dndOn ? I18nService.getTranslation("notifications.dnd_on", "No molestar activado") : I18nService.getTranslation("notifications.dnd_off", "No molestar desactivado")

                    Keys.onReturnPressed: NotificationService.toggleDnd()
                    Keys.onEnterPressed: NotificationService.toggleDnd()
                    Keys.onSpacePressed: NotificationService.toggleDnd()

                    // Halo de foco con la misma silueta expresiva, detrás del fondo
                    MaterialShape {
                        anchors.fill: parent
                        anchors.margins: -2
                        shape: dndToggle.dndShape
                        color: Appearance.md3.primary
                        animationDuration: 300
                        opacity: dndToggle.activeFocus ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 120
                            }
                        }
                    }

                    MaterialShape {
                        id: dndContainer

                        anchors.fill: parent
                        shape: dndToggle.dndShape
                        color: dndToggle.dndOn ? Appearance.md3.secondary_container : Appearance.md3.surface_container_highest
                        animationDuration: 300

                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }
                    }

                    // Capa de estado: misma forma y misma duración para que
                    // morfe sincronizada con el fondo
                    MaterialShape {
                        anchors.fill: dndContainer
                        shape: dndToggle.dndShape
                        color: dndToggle.dndOn ? Appearance.md3.on_secondary_container : Appearance.md3.on_surface
                        animationDuration: 300
                        opacity: dndMouse.pressed ? 0.12 : (dndMouse.containsMouse || dndToggle.activeFocus) ? 0.08 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 100
                            }
                        }
                    }

                    MaterialIcon {
                        id: dndIcon

                        anchors.centerIn: parent
                        text: dndToggle.dndOn ? "do_not_disturb_on" : "do_not_disturb_off"
                        size: Appearance.font.pixelSize.large
                        color: dndToggle.dndOn ? Appearance.md3.on_secondary_container : Appearance.md3.on_surface_variant

                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }
                    }

                    MouseArea {
                        id: dndMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: dndToggle.forceActiveFocus()
                        onPressed: dndToggle.forceActiveFocus()
                        onClicked: NotificationService.toggleDnd()
                    }
                }

                // --- Clear all: botón tonal relleno en forma de píldora ---
                Item {
                    id: clearAllButton

                    visible: (root.historyModel ? root.historyModel.count : 0) > 0
                    implicitWidth: clearAllRow.implicitWidth + 20
                    implicitHeight: 40
                    activeFocusOnTab: true

                    Accessible.role: Accessible.Button
                    Accessible.name: I18nService.getTranslation("notifications.clear_all", "Limpiar todo")

                    Keys.onReturnPressed: root.historyModel.clear()
                    Keys.onEnterPressed: root.historyModel.clear()
                    Keys.onSpacePressed: root.historyModel.clear()

                    Rectangle {
                        anchors.fill: parent
                        radius: Appearance.shape.full
                        color: clearAllButton.activeFocus ? Appearance.md3.primary_container : Appearance.md3.secondary_container
                        border.width: clearAllButton.activeFocus ? 2 : 0
                        border.color: Appearance.md3.primary

                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: Appearance.md3.on_secondary_container
                            opacity: clearAllMouse.pressed ? 0.12 : (clearAllMouse.containsMouse ? 0.08 : 0)

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 100
                                }
                            }
                        }

                        RowLayout {
                            id: clearAllRow

                            anchors.centerIn: parent
                            spacing: 6

                            MaterialIcon {
                                text: "delete_sweep"
                                size: Appearance.font.pixelSize.normal
                                color: clearAllButton.activeFocus ? Appearance.md3.on_primary_container : Appearance.md3.on_secondary_container
                            }

                            StyledText {
                                text: I18nService.getTranslation("notifications.clear_all", "Limpiar todo")
                                font.family: Appearance.font.sans
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.bold: true
                                color: clearAllButton.activeFocus ? Appearance.md3.on_primary_container : Appearance.md3.on_secondary_container
                            }
                        }
                    }

                    MouseArea {
                        id: clearAllMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: clearAllButton.forceActiveFocus()
                        onPressed: clearAllButton.forceActiveFocus()
                        onClicked: root.historyModel.clear()
                    }
                }
            }

            // Separador fino bajo la cabecera — división de secciones tipo GNOME
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Appearance.md3.outline_variant
                opacity: 0.5
                visible: (root.historyModel ? root.historyModel.count : 0) > 0
            }

            // --- Lista scrollable con altura acotada ---
            ListView {
                id: historyList
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, root.maxListHeight)

                visible: (root.historyModel ? root.historyModel.count : 0) > 0
                clip: true
                focus: true
                spacing: 12
                keyNavigationWraps: true
                highlightMoveDuration: 100
                boundsBehavior: Flickable.StopAtBounds
                model: root.historyModel

                ScrollBar.vertical: StyledScrollBar {
                    id: historyScrollBar
                }
                Keys.onDownPressed: incrementCurrentIndex()
                Keys.onUpPressed: decrementCurrentIndex()
                delegate: NotificationHistoryCard {
                    width: historyList.width
                    onRemoveRequested: root.historyModel.remove(index)
                }
            }

            // --- Empty state centrado, al estilo de las vistas vacías de GNOME ---
            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 24
                Layout.bottomMargin: 24
                Layout.alignment: Qt.AlignHCenter
                visible: (root.historyModel ? root.historyModel.count : 0) === 0
                spacing: 8

                // Icono del estado vacío: MaterialShape con sombra + respiración
                // lenta entre Sunny/VerySunny — región cuadrada (100×100), ideal
                // para m3shapes.
                Item {
                    id: emptyStateIconContainer
                    Layout.alignment: Qt.AlignHCenter

                    implicitWidth: 100
                    implicitHeight: 100

                    MultiEffect {
                        anchors.fill: emptyStateShape
                        source: emptyStateShape
                        shadowEnabled: true
                        shadowColor: Appearance.md3.shadow
                        shadowOpacity: 0.15
                        shadowBlur: 0.5
                        shadowVerticalOffset: 2
                    }

                    MaterialShape {
                        id: emptyStateShape

                        anchors.fill: parent
                        shape: MaterialShape.Sunny
                        color: Appearance.md3.primary_container
                        animationDuration: 1400
                        animationEasing.type: Easing.InOutSine

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "notifications_none"
                            size: 32
                            color: Appearance.md3.on_primary_container
                        }
                    }

                    // Ciclo de respiración — solo corre mientras el estado vacío
                    // está visible
                    Timer {
                        interval: 1600
                        running: (root.historyModel ? root.historyModel.count : 0) === 0
                        repeat: true
                        onTriggered: emptyStateShape.shape = emptyStateShape.shape === MaterialShape.Sunny ? MaterialShape.VerySunny : MaterialShape.Sunny
                    }
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: I18nService.getTranslation("notifications.empty", "")
                    color: Appearance.md3.on_surface
                    font.family: Appearance.font.sans
                    font.variableAxes: Appearance.font.variableAxes.title
                    font.pixelSize: Appearance.font.pixelSize.large
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: I18nService.getTranslation("notifications.empty_hint", "Las nuevas notificaciones aparecerán aquí")
                    color: Appearance.md3.on_surface_variant
                    font.family: Appearance.font.sans
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            // --- Pie sutil con atajos de teclado ---
            StyledText {
                Layout.fillWidth: true
                visible: (root.historyModel ? root.historyModel.count : 0) > 0
                text: I18nService.getTranslation("notifications.hint", "N no molestar · D borrar todo · Supr eliminar")
                color: Appearance.md3.on_surface_variant
                opacity: 0.7
                font.family: Appearance.font.sans
                font.pixelSize: Appearance.font.pixelSize.smallest
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
