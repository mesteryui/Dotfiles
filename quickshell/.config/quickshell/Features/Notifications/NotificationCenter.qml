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
    // (Declarada después de panelBg para evitar el warning "ShaderEffect:
    // 'source' does not have a matching property"; z:-1 la mantiene detrás.)
    Shortcut {
        sequence: "d"
        enabled: root.visible && (root.historyModel ? root.historyModel.count : 0) > 0
        onActivated: root.historyModel.clear()
    }

    // Alternar el modo No Molestar (DND) con la tecla 'N'
    Shortcut {
        sequence: "n"
        enabled: root.visible
        onActivated: NotificationData.toggleDnd()
    }

    // Borrar la notificación actualmente seleccionada con 'Delete' o 'Supr'
    Shortcut {
        sequence: "Delete"
        enabled: root.visible && (root.historyModel ? root.historyModel.count : 0) > 0
                 && historyList.currentIndex >= 0
        onActivated: root.historyModel.remove(historyList.currentIndex)
    }

    Rectangle {
        id: panelBg

        anchors.fill: parent
        radius: Appearance.shape.huge
        color: Appearance.md3.surface_container_low
        border.width: Appearance.border.width
        border.color: Appearance.border.subtleOn(Appearance.md3.surface_container_low)

        ColumnLayout {
            id: centerCol

            anchors.fill: parent
            anchors.margins: Appearance.spacing.large
            spacing: Appearance.spacing.medium

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    text: I18nService.getTranslation("notifications.title", "")
                    color: Appearance.md3.on_surface
                    font.family: Appearance.font.sans
                    font.variableAxes: Appearance.font.variableAxes.title
                    font.pixelSize: Appearance.font.pixelSize.larger
                }

                // --- Contador: badge M3 (error + on-error) en pastilla ---
                Rectangle {
                    visible: (root.historyModel ? root.historyModel.count : 0) > 0
                    implicitWidth: countLabel.implicitWidth + 16
                    implicitHeight: 26
                    radius: Appearance.shape.full
                    color: Appearance.md3.error

                    StyledText {
                        id: countLabel

                        anchors.centerIn: parent
                        text: root.historyModel ? root.historyModel.count : 0
                        color: Appearance.md3.on_error
                        font.family: Appearance.font.sans
                        font.variableAxes: Appearance.font.variableAxes.numbers
                        font.pixelSize: Appearance.typeScale.labelMedium
                        font.bold: true
                    }
                }

                // --- DND: botón de icono tonal M3 (siempre circular).
                // 40×40 es cuadrado, así que la silueta expresiva se ve completa.
                // El halo de foco usa la MISMA forma que el fondo para que el
                // anillo acompañe la morfología en vez de pelear con ella, y
                // nada cambia de tamaño con el foco (sin saltos de layout).
                Item {
                    id: dndToggle

                    implicitWidth: 40
                    implicitHeight: 40
                    activeFocusOnTab: true

                    readonly property int dndShape: MaterialShape.Circle

                    readonly property bool dndOn: NotificationData.dnd

                    Accessible.role: Accessible.Button
                    Accessible.checkable: true
                    Accessible.checked: dndToggle.dndOn
                    Accessible.name: I18nService.getTranslation("notifications.dnd", "No molestar")
                    Accessible.description: dndToggle.dndOn ? I18nService.getTranslation(
                                                                  "notifications.dnd_on",
                                                                  "No molestar activado") :
                                                              I18nService.getTranslation(
                                                                  "notifications.dnd_off",
                                                                  "No molestar desactivado")

                    Keys.onReturnPressed: NotificationData.toggleDnd()
                    Keys.onEnterPressed: NotificationData.toggleDnd()
                    Keys.onSpacePressed: NotificationData.toggleDnd()

                    // Halo de foco con la misma silueta expresiva, detrás del fondo
                    MaterialShape {
                        anchors.fill: parent
                        anchors.margins: -2
                        shape: dndToggle.dndShape
                        color: Appearance.md3.primary
                        animationDuration: Appearance.motion.slow
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
                        color: dndToggle.dndOn ? Appearance.md3.secondary_container :
                                                 Appearance.md3.surface_container_highest
                        animationDuration: Appearance.motion.slow

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.motion.fast
                            }
                        }
                    }

                    // Capa de estado: misma forma y misma duración para que
                    // morfe sincronizada con el fondo
                    MaterialShape {
                        anchors.fill: dndContainer
                        shape: dndToggle.dndShape
                        color: dndToggle.dndOn ? Appearance.md3.on_secondary_container :
                                                 Appearance.md3.on_surface
                        animationDuration: Appearance.motion.slow
                        opacity: dndMouse.pressed ? 0.12 : (dndMouse.containsMouse || dndToggle.activeFocus) ? 0.08 :
                                                                                                               0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Appearance.motion.veryFast
                            }
                        }
                    }

                    MaterialIcon {
                        id: dndIcon

                        anchors.centerIn: parent
                        icon: dndToggle.dndOn ? "do_not_disturb_on" : "do_not_disturb_off"
                        size: Appearance.font.pixelSize.large
                        color: dndToggle.dndOn ? Appearance.md3.on_secondary_container :
                                                 Appearance.md3.on_surface_variant

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.motion.fast
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
                        onClicked: NotificationData.toggleDnd()
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
                        color: clearAllButton.activeFocus ? Appearance.md3.primary_container :
                                                            Appearance.md3.secondary_container
                        border.width: clearAllButton.activeFocus ? Appearance.border.focusWidth : 0
                        border.color: Appearance.border.focus

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.motion.fast
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: Appearance.md3.on_secondary_container
                            opacity: clearAllMouse.pressed ? 0.12 : (clearAllMouse.containsMouse ? 0.08 : 0)

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Appearance.motion.veryFast
                                }
                            }
                        }

                        RowLayout {
                            id: clearAllRow

                            anchors.centerIn: parent
                            spacing: Appearance.spacing.small

                            MaterialIcon {
                                icon: "delete_sweep"
                                size: Appearance.typeScale.bodyLarge
                                color: clearAllButton.activeFocus ? Appearance.md3.on_primary_container :
                                                                    Appearance.md3.on_secondary_container
                            }

                            StyledText {
                                text: I18nService.getTranslation("notifications.clear_all", "Limpiar todo")
                                font.family: Appearance.font.sans
                                font.pixelSize: Appearance.typeScale.labelMedium
                                font.bold: true
                                color: clearAllButton.activeFocus ? Appearance.md3.on_primary_container :
                                                                    Appearance.md3.on_secondary_container
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

            // Separador fino bajo la cabecera (mismo trazo que el resto
            // de divisores de panel; outline_variant al 40%).
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Appearance.border.divider
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
                activeFocusOnTab: true
                spacing: Appearance.spacing.medium
                keyNavigationWraps: true
                highlightMoveDuration: 100
                boundsBehavior: Flickable.StopAtBounds
                model: root.historyModel

                // El foco de teclado debe recaer en la lista al abrir el panel.
                // `focus: true` por sí solo no siempre basta con el grab de
                // HyprlandFocusGrab, así que lo asegura de forma explícita.
                Component.onCompleted: forceActiveFocus()

                // Mueve el cursor entre notificaciones y trae la fila actual al
                // viewport. currentIndex parte de -1 (ninguna seleccionada).
                function moveCursor(delta) {
                    const total = root.historyModel ? root.historyModel.count : 0;
                    if (total === 0)
                        return;
                    let idx = currentIndex;
                    if (idx < 0)
                        idx = delta > 0 ? 0 : total - 1;
                    else
                        idx = (idx + delta + total) % total;
                    currentIndex = idx;
                    positionViewAtIndex(idx, ListView.Contain);
                }

                ScrollBar.vertical: StyledScrollBar {
                    id: historyScrollBar
                }
                Keys.onDownPressed: event => {
                    historyList.moveCursor(1);
                    event.accepted = true;
                }
                Keys.onUpPressed: event => {
                    historyList.moveCursor(-1);
                    event.accepted = true;
                }
                // Tab/Shift+Tab ciclan entre la lista y los botones de cabecera
                // (activeFocusOnTab) sin salir del panel.
                delegate: NotificationHistoryCard {
                    width: historyList.width
                    onRemoveRequested: root.historyModel.remove(index)
                }
            }

            // --- Empty state centrado, al estilo de las vistas vacías de GNOME ---
            // Primitivo unificado en modo expresivo (halo Sunny + respiración).
            EmptyState {
                Layout.fillWidth: true
                Layout.topMargin: Appearance.spacing.extraLarge
                Layout.bottomMargin: Appearance.spacing.extraLarge
                Layout.alignment: Qt.AlignHCenter
                visible: (root.historyModel ? root.historyModel.count : 0) === 0
                expressive: true
                icon: "notifications_none"
                title: I18nService.getTranslation("notifications.empty_title", "")
                titleSize: Appearance.font.pixelSize.large
                titleColor: Appearance.md3.on_surface
                titleEmphasis: true
                subtitle: I18nService.getTranslation("notifications.empty_subtitle",
                                                     "Las nuevas notificaciones aparecerán aquí")
            }

            // --- Pie sutil con atajos de teclado ---
            StyledText {
                Layout.fillWidth: true
                visible: (root.historyModel ? root.historyModel.count : 0) > 0
                text: I18nService.getTranslation("notifications.hint",
                                                 "N no molestar · D borrar todo · Supr eliminar")
                color: Appearance.md3.on_surface_variant
                opacity: Appearance.opacity.hint
                font.family: Appearance.font.sans
                font.pixelSize: Appearance.typeScale.labelSmall
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    // Sombra: source se asigna en onCompleted para evitar warning
/* Fixed: Component.onCompleted assigns source */
    MultiEffect {
        id: panelShadow

        anchors.fill: panelBg
        shadowEnabled: true
        shadowColor: Appearance.md3.shadow
        shadowOpacity: Appearance.elevation5.opacity
        shadowBlur: Appearance.elevation5.blur
        shadowVerticalOffset: Appearance.elevation5.offsetY
        shadowHorizontalOffset: 0
        z: -1
        Component.onCompleted: panelShadow.source = panelBg
    }
}
