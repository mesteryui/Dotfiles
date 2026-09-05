import qs.Primitives
import qs.Core
import qs.Core.Services
import QtQuick
import QtQuick.Layouts

Item {
    id: overlay

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

    anchors.fill: parent
    focus: true

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
                AnimatedTextButton {
                    text: I18nService.getTranslation("polkit.cancel", "Cancel")
                    isFilled: false
                    onClicked: overlay.closed()
                }

                // OK button
                AnimatedTextButton {
                    text: I18nService.getTranslation("polkit.ok", "OK")
                    isFilled: true
                    enabled: overlay.interactionAvailable
                    onClicked: overlay.submit(inputField.text)
                }
            }
        }
    }
}
