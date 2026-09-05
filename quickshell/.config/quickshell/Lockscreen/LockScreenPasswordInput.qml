import qs.Core
import qs.Core.Services
import qs.Primitives
import qs.Components
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts

Item {
    id: root

    implicitWidth: 280
    implicitHeight: 48

    // ── Estado ────────────────────────────────────────────────────────
    property bool authFailed: false

    property bool isAuthenticating: false

    property string promptText: ""

    property bool isPasswordVisible: false

    property bool isFingerprintActive: false

    property alias passwordField: password

    signal accepted(string text)

    signal togglePasswordVisibility

    function triggerShake() {
        shakeAnim.restart();
    }

    function clearInput() {
        password.text = "";
    }

    onIsFingerprintActiveChanged: {
        // El SequentialAnimation deja el icono a medio pulso al desactivarse
        // (fprintd tuvo éxito, falló, o entró en modo password) — restaurar
        // opacidad plena para el icono de lock/lock_open normal.
        if (!isFingerprintActive)
            statusIcon.opacity = 1;
    }

    function withAlpha(hexColor, alphaValue) {
        var c = Qt.color(hexColor);
        return Qt.rgba(c.r, c.g, c.b, alphaValue);
    }

    // Contenedor que absorbe la animación shake
    Item {
        id: shakeWrapper

        anchors.fill: parent

        SequentialAnimation {
            id: shakeAnim

            loops: 1

            NumberAnimation {
                target: shakeWrapper
                property: "x"
                from: 0
                to: -10
                duration: 40
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: shakeWrapper
                property: "x"
                from: -10
                to: 10
                duration: 40
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                target: shakeWrapper
                property: "x"
                from: 10
                to: -8
                duration: 40
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                target: shakeWrapper
                property: "x"
                from: -8
                to: 6
                duration: 40
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                target: shakeWrapper
                property: "x"
                from: 6
                to: 0
                duration: 40
                easing.type: Easing.InQuad
            }
        }
    }

    Rectangle {
        id: passwordBg

        anchors.fill: parent
        radius: Appearance.shape.normal
        color: root.authFailed ? root.withAlpha(Appearance.md3.error_container, 0.35) : root.withAlpha(Appearance.md3.surface_container_high, 0.55)
        border.color: root.authFailed ? Appearance.md3.error : (password.activeFocus ? Appearance.md3.primary : root.withAlpha(Appearance.md3.outline_variant, 0.6))
        border.width: 1.5

        Behavior on color {
            ColorAnimation {
                duration: 200
            }
        }
        Behavior on border.color {
            ColorAnimation {
                duration: 200
            }
        }

        RowLayout {
            anchors {
                fill: parent
                leftMargin: 14
                rightMargin: 10
            }
            spacing: 8

            MaterialIcon {
                id: statusIcon

                icon: root.authFailed ? "lock" : (root.isAuthenticating ? "lock_clock" : (root.isFingerprintActive ? "fingerprint" : "lock_open"))
                size: Appearance.font.pixelSize.normal
                color: root.authFailed ? Appearance.md3.error : (root.isFingerprintActive ? Appearance.md3.primary : Appearance.md3.on_surface_variant)

                Behavior on color {
                    ColorAnimation {
                        duration: 200
                    }
                }

                // Pulso suave mientras espera la huella — distingue el estado
                // "escaneando" del icono estático de lock/lock_open.
                SequentialAnimation {
                    running: root.isFingerprintActive
                    loops: Animation.Infinite

                    NumberAnimation {
                        target: statusIcon
                        property: "opacity"
                        from: 1
                        to: 0.4
                        duration: 700
                        easing.type: Easing.InOutQuad
                    }
                    NumberAnimation {
                        target: statusIcon
                        property: "opacity"
                        from: 0.4
                        to: 1
                        duration: 700
                        easing.type: Easing.InOutQuad
                    }
                }
            }

            TextField {
                id: password
                Layout.fillWidth: true
                Layout.fillHeight: true

                echoMode: root.isPasswordVisible === false ? TextInput.Password : TextInput.Normal
                placeholderText: root.authFailed ? I18nService.getTranslation("lockscreen.no_correct", "Contraseña incorrecta") : (root.promptText.length > 0 ? root.promptText : (root.isFingerprintActive ? I18nService.getTranslation("lockscreen.fingerprint", "Coloca tu dedo en el lector") : I18nService.getTranslation("lockscreen.password", "Contraseña...")))
                placeholderTextColor: root.authFailed ? root.withAlpha(Appearance.md3.error, 0.8) : root.withAlpha(Appearance.md3.on_surface_variant, 0.8)
                color: Appearance.md3.on_surface
                background: null
                verticalAlignment: TextInput.AlignVCenter
                focus: true
                enabled: !root.isAuthenticating
                font.family: Appearance.font.sans
                font.pixelSize: Appearance.font.pixelSize.small ? Appearance.font.pixelSize.small : 15

                onAccepted: {
                    if (text.length > 0 && !root.isAuthenticating) {
                        root.accepted(text);
                    }
                }

                Keys.onEscapePressed: {
                    text = "";
                    root.authFailed = false;
                }
            }

            // Spinner al autenticar
            MaterialIcon {
                visible: root.isAuthenticating
                icon: "progress_activity"
                size: Appearance.font.pixelSize.normal
                color: Appearance.md3.primary

                RotationAnimator on rotation {
                    running: root.isAuthenticating
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                }
            }

            // Indicador de CapsLock
            MaterialIcon {
                visible: KeyboardThings.capsLockOn
                icon: "keyboard_capslock"
                size: Appearance.font.pixelSize.normal
                color: Appearance.md3.tertiary
            }

            // Botón mostrar/ocultar contraseña
            MaterialIcon {
                visible: true
                icon: root.isPasswordVisible === false ? "visibility" : "visibility_off"
                size: Appearance.font.pixelSize.normal
                color: Appearance.md3.on_surface

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.togglePasswordVisibility()
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }
    }

    // Elevación MD3
    MultiEffect {
        anchors.fill: passwordBg
        source: passwordBg
        shadowEnabled: true
        shadowColor: Appearance.md3.shadow
        shadowOpacity: 0.18
        shadowBlur: 0.8
        shadowVerticalOffset: 2
        shadowHorizontalOffset: 0
    }
}
