import qs.Core
import qs.Core.Services
import qs.Primitives
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import M3Shapes

// Campo M3 expresivo tipo Pixel: pill alta con estados tonales.
Item {
    id: root

    implicitWidth: 380
    implicitHeight: 56

    // ── Estado ────────────────────────────────────────────────────────
    property bool authFailed: false

    property bool isAuthenticating: false

    property string promptText: ""

    property bool isPasswordVisible: false

    property bool isFingerprintActive: false

    // Pantalla primaria de la sesión de bloqueo: solo ella anima la
    // respiración. Las secundarias muestran el mismo estado en estático.
    property bool isPrimary: true

    property alias passwordField: password

    signal accepted(string text)

    signal togglePasswordVisibility

    signal requestSleep

    // Respiración del contenedor mientras espera la huella
    // (Cookie4Sided↔Puffy), igual que el estado vacío de notificaciones.
    property int breathShape: MaterialShape.Cookie4Sided
    // Flash de éxito al validar la huella (Heart breve antes de desbloquear).
    property bool wasScanning: false
    property bool successFlash: false

    onIsFingerprintActiveChanged: {
        if (isFingerprintActive) {
            root.wasScanning = true;
            root.successFlash = false;
        } else if (root.wasScanning && !root.authFailed) {
            root.wasScanning = false;
            root.successFlash = true;
            flashTimer.restart();
        } else {
            root.wasScanning = false;
        }
    }

    Timer {
        id: flashTimer
        interval: 600
        onTriggered: root.successFlash = false
    }

    Timer {
        interval: 900
        running: root.isPrimary && root.isFingerprintActive && !root.authFailed && !Appearance.reduceMotion
        repeat: true
        onTriggered: root.breathShape = root.breathShape === MaterialShape.Cookie4Sided ? MaterialShape.Puffy : MaterialShape.Cookie4Sided
    }

    function triggerShake() {
        shakeAnim.restart();
    }

    function clearInput() {
        password.text = "";
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
        radius: Appearance.shape.full
        color: root.authFailed ? root.withAlpha(Appearance.md3.error_container, 0.55) : root.withAlpha(Appearance.md3.surface_container_high, 0.78)
        border.color: root.authFailed ? Appearance.md3.error : (password.activeFocus ? Appearance.md3.primary : root.withAlpha(Appearance.md3.outline_variant, 0.55))
        border.width: password.activeFocus || root.authFailed ? 2 : 1

        Behavior on color {
            ColorAnimation {
                duration: Appearance.motion.short4
            }
        }
        Behavior on border.color {
            ColorAnimation {
                duration: Appearance.motion.short4
            }
        }

        RowLayout {
            anchors {
                fill: parent
                leftMargin: 8
                rightMargin: 8
            }
            spacing: 6

            // Icono principal en contenedor expresivo estilo Pixel (huella / lock):
            // respira entre formas al escanear, Boom al fallar.
            MaterialShape {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                Layout.alignment: Qt.AlignVCenter
                shape: root.successFlash ? MaterialShape.Heart : root.authFailed ? MaterialShape.Boom : (root.isPrimary && root.isFingerprintActive) ? root.breathShape : MaterialShape.Circle
                animationDuration: 350
                color: root.authFailed ? root.withAlpha(Appearance.md3.error, 0.16) : root.withAlpha(Appearance.md3.primary, root.isFingerprintActive || password.activeFocus ? 0.18 : 0.10)

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.motion.short4
                    }
                }

                MaterialIcon {
                    id: statusIcon

                    anchors.centerIn: parent
                    icon: root.authFailed ? "lock" : (root.isAuthenticating ? "lock_clock" : (root.isFingerprintActive ? "fingerprint" : "lock_open"))
                    size: 24
                    color: root.authFailed ? Appearance.md3.error : (root.isFingerprintActive || password.activeFocus ? Appearance.md3.primary : Appearance.md3.on_surface_variant)

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.motion.short4
                        }
                    }
                }
            }

            TextField {
                id: password
                Layout.fillWidth: true
                Layout.fillHeight: true

                echoMode: root.isPasswordVisible === false ? TextInput.Password : TextInput.Normal
                // Un solo mensaje aquí: el prompt PAM o "Contraseña...".
                // El error va en la pastilla de estado y la huella en su
                // propia pastilla, para no duplicar textos.
                placeholderText: root.promptText.length > 0 ? root.promptText : I18nService.getTranslation("lockscreen.password", "Contraseña...")
                placeholderTextColor: root.authFailed ? root.withAlpha(Appearance.md3.error, 0.8) : root.withAlpha(Appearance.md3.on_surface_variant, 0.8)
                color: Appearance.md3.on_surface
                background: null
                verticalAlignment: TextInput.AlignVCenter
                focus: true
                enabled: !root.isAuthenticating
                font.family: Appearance.font.sans
                font.pixelSize: Appearance.typeScale.titleSmall ? Appearance.typeScale.titleSmall : 15

                onAccepted: {
                    if (text.length > 0 && !root.isAuthenticating) {
                        root.accepted(text);
                    }
                }

                Keys.onEscapePressed: {
                    if (text.length === 0) {
                        root.requestSleep();
                    } else {
                        text = "";
                        root.authFailed = false;
                    }
                }
            }

            // Spinner al autenticar
            MaterialIcon {
                visible: root.isAuthenticating
                icon: "progress_activity"
                size: Appearance.typeScale.bodyLarge
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
                size: Appearance.typeScale.bodyLarge
                color: Appearance.md3.tertiary
            }

            // Botón mostrar/ocultar contraseña en círculo tonal (MaterialShape).
            MaterialShape {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                Layout.alignment: Qt.AlignVCenter
                shape: MaterialShape.Circle
                color: passwordMouse.containsMouse ? root.withAlpha(Appearance.md3.primary, 0.16) : "transparent"
                animationDuration: 150

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.motion.short3
                    }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    icon: root.isPasswordVisible === false ? "visibility" : "visibility_off"
                    size: 20
                    color: Appearance.md3.on_surface_variant
                }

                MouseArea {
                    id: passwordMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.togglePasswordVisibility()
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }
    }

    // Elevación MD3: source se asigna en onCompleted para evitar warning
    // "ShaderEffect: 'source' does not have a matching property"
    MultiEffect {
        id: passwordShadow
        anchors.fill: passwordBg
        shadowEnabled: true
        shadowColor: Appearance.md3.shadow
        shadowOpacity: 0.18
        shadowBlur: 0.8
        shadowVerticalOffset: 2
        shadowHorizontalOffset: 0
        Component.onCompleted: passwordShadow.source = passwordBg
    }
}
