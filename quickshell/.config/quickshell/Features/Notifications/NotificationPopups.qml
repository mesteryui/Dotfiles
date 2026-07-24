pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Services
import qs.Primitives
PanelWindow {
    id: root

    required property var trackedNotifications

    anchors {
        top: true
        right: true
    }
    margins {
        top: 50
        right: 12
    }
    implicitWidth: 380
    implicitHeight: Math.max(1, column.implicitHeight)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    ColumnLayout {
        id: column
        width: parent.width
        spacing: 10

        Repeater {
            model: root.trackedNotifications

            delegate: Rectangle {
                id: card
                required property var modelData

                Layout.fillWidth: true
                implicitHeight: popupContent.implicitHeight + 20
                radius: Appearance.shape.normal
                color: Appearance.md3.background

                Timer {
                    running: true
                    interval: ConfigService.configs.notifications.timeout * 1000
                    onTriggered: card.modelData.expire()
                }

                border {
                    width: 2
                    color: card.modelData.urgency === NotificationUrgency.Critical ? Appearance.md3.error : Appearance.md3.outline
                }

                ColumnLayout {
                    id: popupContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10
                    anchors.rightMargin: 24
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Image {
                            Layout.preferredHeight: 36
                            Layout.preferredWidth: 36
                            Layout.alignment: Qt.AlignTop
                            fillMode: Image.PreserveAspectFit
                            visible: source.toString() !== ""
                            source: card.modelData.image || card.modelData.appIcon || ""
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: card.modelData.summary
                                visible: text !== ""
                                color: Appearance.md3.on_background
                                font.family: Appearance.font.sans
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.bold: true
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: card.modelData.body
                                visible: text !== ""
                                color: Appearance.md3.on_background
                                font.family: Appearance.font.sans
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    // Botones de acción
                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        visible: card.modelData.actions.length > 0

                        Repeater {
                            model: card.modelData.actions

                            delegate: Rectangle {
                                required property var modelData

                                width: actionLabel.implicitWidth + 16
                                height: actionLabel.implicitHeight + 8
                                radius: Appearance.shape.normal
                                color: Appearance.md3.primary

                                Text {
                                    id: actionLabel
                                    anchors.centerIn: parent
                                    text: parent.modelData.text
                                    color: Appearance.md3.on_primary
                                    font.family: Appearance.font.sans
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: parent.modelData.invoke()
                                }
                            }
                        }
                    }
                }

                // Botón (×) para cerrar la notificación
                MaterialIcon {
                    icon: "close"
                    color: Appearance.md3.on_background
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 6

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.modelData.dismiss()
                    }
                }
            }
        }
    }
}
