pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import qs.Core
import qs.Core.Services
import qs.Primitives

PanelWindow {
    id: root

    required property ListModel historyModel

    // Cap the notification list height; beyond this it scrolls instead of
    // pushing the panel taller than the screen.
    readonly property int maxListHeight: 420

    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    HyprlandFocusGrab {
        windows: [root]
        active: root.visible
        onCleared: Qt.callLater(() => {
            NotificationManager.centerOpen = false
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

    Rectangle {
        id: panelBg
        anchors.fill: parent
        radius: Appearance.shape.normal
        color: Appearance.md3.surface

        ColumnLayout {
            id: centerCol
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                StyledText {
                    Layout.fillWidth: true
                    text: I18nService.getTranslation("notifications.title", "")
                    color: Appearance.md3.on_background
                    font.family: Appearance.font.sans
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.bold: true
                }

                // --- DND toggle: botón circular tonal, acción de cabecera GNOME ---
                Item {
                    implicitWidth: 32
                    implicitHeight: 32

                    Rectangle {
                        id: dndContainer
                        anchors.fill: parent
                        radius: Appearance.shape.full
                        color: NotificationManager.dnd ? Appearance.md3.primary_container : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }

                    Rectangle {
                        id: dndStateLayer
                        anchors.fill: parent
                        radius: Appearance.shape.full
                        color: Appearance.md3.on_background
                        opacity: 0
                        Behavior on opacity { NumberAnimation { duration: 100 } }
                    }

                    MaterialIcon {
                        id: dndIcon
                        anchors.centerIn: parent
                        text: NotificationManager.dnd ? "do_not_disturb_on" : "do_not_disturb_off"
                        size: Appearance.font.pixelSize.large
                        color: NotificationManager.dnd ? Appearance.md3.error : Appearance.md3.primary
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: dndStateLayer.opacity = 0.08
                        onExited: dndStateLayer.opacity = 0
                        onPressed: dndStateLayer.opacity = 0.12
                        onReleased: dndStateLayer.opacity = containsMouse ? 0.08 : 0
                        onClicked: NotificationManager.toggleDnd()
                    }
                }

                // --- Clear all: enlace de texto discreto, tipo cabecera GNOME ---
                Item {
                    visible: root.historyModel.count > 0
                    implicitWidth: clearAllText.implicitWidth + 16
                    implicitHeight: 32

                    Rectangle {
                        id: clearAllStateLayer
                        anchors.fill: parent
                        radius: Appearance.shape.full
                        color: Appearance.md3.on_background
                        opacity: 0
                        Behavior on opacity { NumberAnimation { duration: 100 } }
                    }

                    StyledText {
                        id: clearAllText
                        anchors.centerIn: parent
                        text: I18nService.getTranslation("notifications.clear_all", "")
                        font.family: Appearance.font.sans
                        color: Appearance.md3.primary
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: clearAllStateLayer.opacity = 0.08
                        onExited: clearAllStateLayer.opacity = 0
                        onPressed: clearAllStateLayer.opacity = 0.12
                        onReleased: clearAllStateLayer.opacity = containsMouse ? 0.08 : 0
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
                visible: root.historyModel.count > 0
            }

            // --- Lista scrollable con altura acotada ---
            ListView {
                id: historyList
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, root.maxListHeight)
                visible: root.historyModel.count > 0
                clip: true
                spacing: 8
                boundsBehavior: Flickable.StopAtBounds
                model: root.historyModel

                ScrollBar.vertical: StyledScrollBar {
                    id: historyScrollBar
                
                }

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
                visible: root.historyModel.count === 0
                spacing: 8

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: "notifications_none"
                    size: 40
                    color: Appearance.md3.on_surface_variant
                    opacity: 0.6
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: I18nService.getTranslation("notifications.empty", "")
                    color: Appearance.md3.on_surface_variant
                    font.family: Appearance.font.sans
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
