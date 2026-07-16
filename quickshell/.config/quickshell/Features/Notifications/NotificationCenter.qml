pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Services
import qs.Primitives

PanelWindow {
    id: root

    required property ListModel historyModel

    anchors {
        top: true
        right: true
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
        radius: 12
        color: Appearance.md3.background

        ColumnLayout {
            id: centerCol
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            RowLayout {
                Layout.fillHeight: true
                Text {
                    Layout.fillWidth: true
                    text: I18nService.getTranslation("notifications.title", "")
                    color: Appearance.md3.on_background
                    font.family: Appearance.font.sans
                }
                MaterialIcon {
                    text: NotificationManager.dnd ? "do_not_disturb_on" : "do_not_disturb_off"
                    size: Appearance.font.pixelSize.large
                    color: NotificationManager.dnd ? Appearance.md3.error : Appearance.md3.primary
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NotificationManager.toggleDnd()
                    }
                }
                Text {
                    text: I18nService.getTranslation("notifications.clear_all", "")
                    visible: root.historyModel.count > 0
                    font.family: Appearance.font.sans
                    color: Appearance.md3.on_background
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.historyModel.clear()
                    }
                }
            }

            Repeater {
                model: root.historyModel

                delegate: NotificationHistoryCard {
                    Layout.fillWidth: true
                    onRemoveRequested: root.historyModel.remove(index)
                }
            }

            Text {
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
