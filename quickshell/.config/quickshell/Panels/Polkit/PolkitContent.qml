import qs.Primitives
import qs.Core
import qs.Core.Services
import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts

Item {
    id: overlay

    required property bool usePasswordChars

    required property string cleanMessage

    required property bool interactionAvailable

    required property string cleanPrompt

    // Estado de error: se activa con cada intento fallido y se limpia al
    // escribir o reenviar.
    property bool authError: false

    signal closed

    signal submit(text: string)

    function forceFocus() {
        inputField.forceActiveFocus();
    }

    function clearText() {
        inputField.text = "";
    }

    // Cada fallo de autenticación: marcar error + agitar la tarjeta.
    Connections {
        target: PolkitService

        function onFailedAttemptsChanged() {
            if (PolkitService.failedAttempts > 0) {
                overlay.authError = true;
                shakeAnim.restart();
            }
        }
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

        // Agitación lateral para el error: usa Translate para no pelear
        // con el anchors.centerIn.
        transform: Translate {
            id: shakeT
        }

        SequentialAnimation {
            id: shakeAnim

            NumberAnimation {
                target: shakeT
                property: "x"
                to: -10
                duration: 50
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: shakeT
                property: "x"
                to: 10
                duration: 75
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                target: shakeT
                property: "x"
                to: -6
                duration: 75
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                target: shakeT
                property: "x"
                to: 6
                duration: 60
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                target: shakeT
                property: "x"
                to: 0
                duration: 50
                easing.type: Easing.OutQuad
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
                icon: overlay.authError ? "error" : "security"
                color: overlay.authError ? Appearance.md3.error : Appearance.md3.secondary

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }
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
                placeholderTextColor: overlay.authError ? Appearance.md3.error : Appearance.md3.outline
                echoMode: overlay.usePasswordChars ? TextInput.Password : TextInput.Normal
                Material.accent: overlay.authError ? Appearance.md3.error : Appearance.md3.primary
                focus: true
                onTextEdited: overlay.authError = false
                onAccepted: {
                    overlay.authError = false;
                    overlay.submit(inputField.text);
                }
                Keys.onPressed: event => { // Esc to close
                    if (event.key === Qt.Key_Escape) {
                        overlay.closed();
                    }
                }
            }

            // Mensaje de error bajo el campo
            StyledText {
                Layout.fillWidth: true
                visible: overlay.authError
                text: I18nService.getTranslation("polkit.wrong_password", "Contraseña incorrecta, inténtalo de nuevo")
                font.pixelSize: 12
                color: Appearance.md3.error
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
                    onClicked: {
                        overlay.authError = false;
                        overlay.submit(inputField.text);
                    }
                }
            }
        }
    }
}
