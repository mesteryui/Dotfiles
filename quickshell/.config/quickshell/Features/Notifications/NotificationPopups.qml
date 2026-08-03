pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
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
        spacing: 12

        Repeater {
            model: root.trackedNotifications

            delegate: Item {
                id: cardWrapper
                required property var modelData

                Layout.fillWidth: true
                implicitHeight: card.implicitHeight

                // Sombra difusa de elevación en vez de un borde duro — toast
                // plano y suave al estilo GNOME sobre una superficie tonal MD3
                MultiEffect {
                    source: card
                    anchors.fill: card
                    shadowEnabled: true
                    shadowColor: Appearance.md3.shadow
                    shadowOpacity: 0.22
                    shadowBlur: 0.8
                    shadowVerticalOffset: 2
                    shadowHorizontalOffset: 0
                }

                Rectangle {
                    id: card

                    width: cardWrapper.width
                    implicitHeight: popupContent.implicitHeight + 20
                    radius: Appearance.shape.normal
                    color: Appearance.md3.surface

                    Timer {
                        running: true
                        interval: ConfigService.configs.notifications.timeout * 1000
                        onTriggered: cardWrapper.modelData.expire()
                    }

                    // Acento fino de urgencia en lugar de un borde completo —
                    // indicador tipo "container" MD3, discreto como GNOME
                    Rectangle {
                        visible: cardWrapper.modelData.urgency === NotificationUrgency.Critical
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.margins: 6
                        width: 3
                        radius: Appearance.shape.full
                        color: Appearance.md3.error
                    }

                    ColumnLayout {
                        id: popupContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                        anchors.leftMargin: cardWrapper.modelData.urgency === NotificationUrgency.Critical ? 18 : 12
                        anchors.rightMargin: 28
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Item {
                                Layout.preferredHeight: 36
                                Layout.preferredWidth: 36
                                Layout.alignment: Qt.AlignTop
                                visible: popupIcon.source.toString() !== ""

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Appearance.shape.full
                                    color: Appearance.md3.surface_variant
                                }

                                Image {
                                    id: popupIcon
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    fillMode: Image.PreserveAspectFit
                                    source: {
                                        const img = cardWrapper.modelData.image
                                        if (img && img !== "") return img
                                        const appIcon = cardWrapper.modelData.appIcon
                                        if (!appIcon || appIcon === "") return ""
                                        return Quickshell.iconPath(appIcon, true)
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    Layout.fillWidth: true
                                    text: cardWrapper.modelData.summary
                                    visible: text !== ""
                                    color: Appearance.md3.on_surface
                                    font.family: Appearance.font.sans
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.bold: true
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: cardWrapper.modelData.body
                                    visible: text !== ""
                                    color: Appearance.md3.on_surface_variant
                                    font.family: Appearance.font.sans
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }

                        // Botones de acción — forma de píldora, MD3 filled-tonal
                        Flow {
                            Layout.fillWidth: true
                            spacing: 6
                            visible: cardWrapper.modelData.actions.length > 0

                            Repeater {
                                model: cardWrapper.modelData.actions

                                delegate: Rectangle {
                                    id: actionChip
                                    required property var modelData

                                    width: actionLabel.implicitWidth + 20
                                    height: actionLabel.implicitHeight + 10
                                    radius: Appearance.shape.full
                                    color: actionArea.pressed ? Appearance.md3.primary : Appearance.md3.primary_container
                                    Behavior on color { ColorAnimation { duration: 100 } }

                                    Text {
                                        id: actionLabel
                                        anchors.centerIn: parent
                                        text: actionChip.modelData.text
                                        color: actionArea.pressed ? Appearance.md3.on_primary : Appearance.md3.primary
                                        font.family: Appearance.font.sans
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                    }

                                    MouseArea {
                                        id: actionArea
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: actionChip.modelData.invoke()
                                    }
                                }
                            }
                        }
                    }

                    // Botón (×) para cerrar la notificación — botón circular tonal
                    Item {
                        width: 24
                        height: 24
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 8

                        Rectangle {
                            id: closeStateLayer
                            anchors.fill: parent
                            radius: Appearance.shape.full
                            color: Appearance.md3.on_surface
                            opacity: 0
                            Behavior on opacity { NumberAnimation { duration: 100 } }
                        }

                        MaterialIcon {
                            icon: "close"
                            anchors.centerIn: parent
                            color: Appearance.md3.on_surface_variant
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: closeStateLayer.opacity = 0.10
                            onExited: closeStateLayer.opacity = 0
                            onPressed: closeStateLayer.opacity = 0.16
                            onReleased: closeStateLayer.opacity = containsMouse ? 0.10 : 0
                            onClicked: cardWrapper.modelData.dismiss()
                        }
                    }
                }
            }
        }
    }
}