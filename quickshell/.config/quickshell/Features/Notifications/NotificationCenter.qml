pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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
    implicitHeight: centerCol.implicitHeight + 24
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
        anchors.fill: parent
        radius: Appearance.shape.normal
        color: Appearance.md3.background

        ColumnLayout {
            id: centerCol
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                StyledText {
                    Layout.fillWidth: true
                    text: I18nService.getTranslation("notifications.title", "")
                    color: Appearance.md3.on_background
                    font.family: Appearance.font.sans
                }

                // --- DND toggle with MD3 state layer ---
                Item {
                    implicitWidth: dndIcon.size + 8
                    implicitHeight: dndIcon.size + 8

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

                // --- Clear all with MD3 state layer ---
                Item {
                    visible: root.historyModel.count > 0
                    implicitWidth: clearAllText.implicitWidth + 12
                    implicitHeight: clearAllText.implicitHeight + 8

                    Rectangle {
                        id: clearAllStateLayer
                        anchors.fill: parent
                        radius: Appearance.shape.large
                        color: Appearance.md3.on_background
                        opacity: 0
                        Behavior on opacity { NumberAnimation { duration: 100 } }
                    }

                    StyledText {
                        id: clearAllText
                        anchors.centerIn: parent
                        text: I18nService.getTranslation("notifications.clear_all", "")
                        font.family: Appearance.font.sans
                        color: Appearance.md3.on_background
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

            // --- Scrollable, height-bounded notification list ---
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

            StyledText {
                visible: root.historyModel.count === 0
                text: I18nService.getTranslation("notifications.empty", "")
                color: Appearance.md3.on_surface_variant
                font.family: Appearance.font.sans
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }
        }
    }
}
