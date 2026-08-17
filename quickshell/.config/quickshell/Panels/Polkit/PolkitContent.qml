import QtQuick
import QtQuick.Layouts
import qs.Primitives
import qs.Core
import qs.Core.Services

Item {
    id: overlay
    anchors.fill: parent
    focus: true

    required property bool usePasswordChars

    required property string cleanMessage

    required property bool interactionAvailable

    required property string cleanPrompt

    signal closed

    signal submit(text: string)

    function forceFocus() {
        inputField.forceActiveFocus();
    }

    function clearText() {
        inputField.text = "";
    }

    Keys.onPressed: event => { // Esc to close
        if (event.key === Qt.Key_Escape) {
            overlay.closed();
        }
    }

    Rectangle {
        id: dialogCard
        anchors.centerIn: parent
        width: 380
        radius: 28 // extraLarge shape token
        color: Appearance.md3.surface_container_high

        implicitHeight: contentColumn.implicitHeight + 48
        height: implicitHeight

        opacity: 0
        scale: 0.94
        Component.onCompleted: {
            opacity = 1;
            scale = 1;
        }
        Behavior on opacity {
            OpacityAnimator {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }
        Behavior on scale {
            ScaleAnimator {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }

        ColumnLayout {
            id: contentColumn
            anchors.centerIn: parent
            width: parent.width - 48
            spacing: 16

            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                size: 26
                icon: "security"
                color: Appearance.md3.secondary
            }

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: I18nService.getTranslation("polkit.authenticationRequired", "Authentication Required")
                font.pixelSize: 18
                font.bold: true
                color: Appearance.md3.on_surface
            }

            StyledText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignLeft
                text: overlay.cleanMessage
                font.pixelSize: 13
                color: Appearance.md3.on_surface_variant
            }

            MaterialTextField {
                id: inputField
                Layout.fillWidth: true
                Layout.fillHeight: true

                leftPadding: 16
                rightPadding: 16

                verticalAlignment: TextInput.AlignVCenter
                clip: true
                enabled: overlay.interactionAvailable
                font.pixelSize: 14
                placeholderText: overlay.cleanPrompt
                echoMode: overlay.usePasswordChars ? TextInput.Password : TextInput.Normal
                focus: true
                onAccepted: overlay.submit(inputField.text)
                Keys.onPressed: event => { // Esc to close
                    if (event.key === Qt.Key_Escape) {
                        overlay.closed();
                    }
                }
            }

            // Button row
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 8
                spacing: 8

                Item {
                    Layout.fillWidth: true
                }

                // Cancel button
                Rectangle {
                    id: cancelButton
                    implicitWidth: cancelLabel.implicitWidth + 32
                    implicitHeight: 36
                    radius: 9999 // full shape token
                    color: "transparent"

                    Rectangle {
                        id: cancelStateLayer
                        anchors.fill: parent
                        radius: parent.radius
                        color: Appearance.md3.on_surface
                        opacity: cancelMouseArea.pressed ? 0.12 : (cancelMouseArea.containsMouse ? 0.08 : 0)
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 100
                            }
                        }
                    }

                    StyledText {
                        id: cancelLabel
                        anchors.centerIn: parent
                        text: I18nService.getTranslation("polkit.cancel", "Cancel")
                        color: Appearance.md3.primary
                        font.pixelSize: 14
                    }

                    MouseArea {
                        id: cancelMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: overlay.closed()
                    }
                }

                // OK button
                Rectangle {
                    id: okButton
                    implicitWidth: okLabel.implicitWidth + 32
                    implicitHeight: 36
                    radius: 9999 // full shape token
                    enabled: overlay.interactionAvailable
                    opacity: enabled ? 1 : 0.5
                    color: Appearance.md3.primary

                    Rectangle {
                        id: okStateLayer
                        anchors.fill: parent
                        radius: parent.radius
                        color: Appearance.md3.on_primary
                        opacity: okMouseArea.pressed ? 0.12 : (okMouseArea.containsMouse ? 0.08 : 0)
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 100
                            }
                        }
                    }

                    StyledText {
                        id: okLabel
                        anchors.centerIn: parent
                        text: I18nService.getTranslation("polkit.ok", "OK")
                        color: Appearance.md3.on_primary
                        font.pixelSize: 14
                    }

                    MouseArea {
                        id: okMouseArea
                        anchors.fill: parent
                        enabled: parent.enabled
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: overlay.submit(inputField.text)
                    }
                }
            }
        }
    }
}
