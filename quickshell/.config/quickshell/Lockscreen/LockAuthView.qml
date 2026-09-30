// LockAuthView — etapa despierta: top-bar, avatar, huella, password, estado, MPRIS.
// Extraído de LockScreenContent.qml. Los botones power viven en LockPowerButtons.
import qs.Core
import qs.Core.Services
import qs.Primitives
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import M3Shapes

Item {
    id: root

    property bool isAwake: false
    property bool isPrimary: true
    property bool authFailed: false
    property bool isAuthenticating: false
    property string promptText: ""
    property bool isPasswordVisible: false
    property bool isFingerprintActive: false
    property real mprisPosition: 0
    property int stageDuration: 350
    // Gesto en curso (lo aporta LockDragArea).
    property real dragDy: 0
    property bool dragging: false

    signal validatePassword(string password)
    signal togglePasswordVisibility
    signal sleepRequested

    // Expuesto para LockScreenWrapper (content.passwordField) y shake().
    property alias passwordField: passwordInput.passwordField

    function shake() {
        passwordInput.triggerShake();
    }

    // Copia local a propósito (ver FileMenu.js): los .js no ven Qt y
    // los componentes no comparten ámbito; misma semántica en todos.
    function withAlpha(hexColor, alphaValue) {
        var c = Qt.color(hexColor);
        return Qt.rgba(c.r, c.g, c.b, alphaValue);
    }

// Reloj compartido para el saludo (precisión minutos: tick barato y
// compartido por Qt; evita que el saludo quede rancio al cambiar de hora).
SystemClock {
    id: greetingClock

    precision: SystemClock.Minutes
}

    anchors.fill: parent
    z: 1
    opacity: isAwake ? 1 : Math.min(1, dragDy / 130)
    visible: opacity > 0

    // Slide desde abajo: parte de +60px y sube a 0
    transform: Translate {
        id: authSlide
        y: isAwake ? 0 : 60 - Math.min(60, dragDy * 0.5)
        Behavior on y {
            enabled: !dragging
            NumberAnimation { duration: stageDuration; easing.type: Easing.OutCubic }
        }
    }

    Behavior on opacity {
        enabled: !dragging
        NumberAnimation { duration: stageDuration; easing.type: Easing.OutCubic }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Appearance.spacing.m

        // Barra superior M3: volver a dormir (GNOME) + chip batería
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 12
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            spacing: Appearance.spacing.s

            MaterialShape {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                shape: MaterialShape.Circle
                color: downMouse.containsMouse ? withAlpha(Appearance.md3.on_surface, 0.10) : withAlpha(Appearance.md3.surface_container_high, 0.72)
                strokeWidth: 1
                strokeColor: withAlpha(Appearance.md3.outline_variant, 0.5)
                animationDuration: 150

                MaterialIcon {
                    anchors.centerIn: parent
                    icon: "keyboard_arrow_down"
                    size: 24
                    color: Appearance.md3.on_surface_variant
                }
                Accessible.role: Accessible.Button
                Accessible.name: I18nService.getTranslation("lockscreen.sleep", "Dormir")

                MouseArea {
                    id: downMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sleepRequested()
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                Layout.preferredHeight: 36
                Layout.preferredWidth: authBatteryRow.implicitWidth + 28
                radius: Appearance.shape.full
                color: withAlpha(Appearance.md3.surface_container_high, 0.72)
                border.width: 1
                border.color: withAlpha(Appearance.md3.outline_variant, 0.5)

                RowLayout {
                    id: authBatteryRow
                    anchors.centerIn: parent
                    spacing: 6
                    MaterialIcon {
                        icon: BatteryService.materialIcon
                        size: 20
                        color: Appearance.md3.on_surface_variant
                    }
                    StyledText {
                        text: BatteryService.percentage + "%"
                        font.pixelSize: Appearance.typeScale.titleSmall
                        font.weight: Font.DemiBold
                        color: Appearance.md3.on_surface_variant
                    }
                }
            }
        }

        Item { Layout.fillHeight: true; Layout.preferredHeight: 8 }

        // Reloj compacto estilo Pixel (encima del avatar)
        LockScreenClock {
            id: authClock
            Layout.alignment: Qt.AlignHCenter
            compact: true
        }

        // Avatar Pixel: anillo tonal + fallback
        Item {
            id: avatarWrapper
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 10

            implicitWidth: 96
            implicitHeight: 96

            // Halo expresivo que "despierta" con la vista:
            // Circle dormido → Cookie9Sided despierto. Solo decoración;
            // la foto sigue con recorte circular (MaterialShape no recorta).
            MaterialShape {
                anchors.centerIn: parent
                width: 110
                height: 110
                shape: isAwake ? MaterialShape.Cookie9Sided : MaterialShape.Circle
                animationDuration: 600
                color: withAlpha(Appearance.md3.primary, isAwake ? 0.35 : 0.18)
            }

            MaterialShape {
                id: avatarBg

                anchors.fill: parent
                shape: MaterialShape.Circle
                color: withAlpha(Appearance.md3.primary_container, 0.92)
                strokeColor: Appearance.md3.primary
                strokeWidth: 2
                animationDuration: 150

                MaterialIcon {
                    anchors.centerIn: parent
                    icon: "person"
                    size: 44
                    color: Appearance.md3.on_primary_container
                    visible: !faceImage.visible
                }

                StyledClippingRectangle {
                    anchors.fill: parent
                    radius: Appearance.shape.full
                    border.width: 0

                    Image {
                        id: faceImage
                        anchors.fill: parent
                        source: Quickshell.env("HOME") + "/.face"
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        // Avatar pequeño: evita decodificar la foto entera.
                        sourceSize.width: 192
                        sourceSize.height: 192
                        visible: status === Image.Ready
                    }
                }
            }

            // Sombra: source se asigna en onCompleted para evitar warning
            // "ShaderEffect: 'source' does not have a matching property"
            MultiEffect {
                id: avatarShadow
                anchors.fill: avatarBg
                shadowEnabled: true
                shadowColor: Appearance.md3.shadow
                shadowOpacity: Appearance.elevation5.opacity
                shadowBlur: Appearance.elevation5.blur
                shadowVerticalOffset: Appearance.elevation5.offsetY
                shadowHorizontalOffset: 0
                Component.onCompleted: avatarShadow.source = avatarBg
            }
        }

        // Nombre de usuario (M3 titleLarge)
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 4
            text: Quickshell.env("USER")
            font.pixelSize: Appearance.font.pixelSize.larger
            font.weight: Font.DemiBold
            font.variableAxes: Appearance.font.variableAxes.title
            color: Appearance.md3.on_surface
        }

        // Saludo según la hora (calidez sin coste).
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: {
                const h = greetingClock.date.getHours();
                if (h >= 6 && h < 12)
                    return I18nService.getTranslation("lockscreen.greeting_morning", "Buenos días");
                if (h >= 12 && h < 21)
                    return I18nService.getTranslation("lockscreen.greeting_afternoon", "Buenas tardes");
                return I18nService.getTranslation("lockscreen.greeting_night", "Buenas noches");
            }
            font.pixelSize: Appearance.typeScale.titleSmall
            color: Appearance.md3.on_surface_variant
        }

        // Huella activa: pastilla tonal tipo Pixel (mantiene password como alternativa GNOME)
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 2
            visible: isFingerprintActive
            implicitWidth: fpRow.implicitWidth + 28
            implicitHeight: 32
            radius: Appearance.shape.full
            color: withAlpha(Appearance.md3.primary, 0.16)
            border.width: 1
            border.color: withAlpha(Appearance.md3.primary, 0.35)

            RowLayout {
                id: fpRow
                anchors.centerIn: parent
                spacing: 6
                MaterialIcon {
                    icon: "fingerprint"
                    size: 16
                    color: Appearance.md3.primary
                }
                StyledText {
                    text: I18nService.getTranslation("lockscreen.fingerprint", "Coloca tu dedo en el lector")
                    font.pixelSize: Appearance.typeScale.labelMedium
                    font.weight: Font.Medium
                    color: Appearance.md3.primary
                }
            }
        }

        // Campo de contraseña pill M3
        LockScreenPasswordInput {
            id: passwordInput
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 6
            Layout.preferredWidth: 380

            authFailed: authFailed
            isAuthenticating: isAuthenticating
            promptText: promptText
            isPasswordVisible: isPasswordVisible
            isFingerprintActive: isFingerprintActive
            // Solo la primaria anima la respiración (ver PasswordInput):
            // en multi-monitor ahorra N-1 timers + morphs concurrentes.
            isPrimary: isPrimary

            onAccepted: password => validatePassword(password)
            onTogglePasswordVisibility: togglePasswordVisibility()
            onRequestSleep: sleepRequested()
        }

        // Mensaje de estado (error / Bloq Mayús) en pastilla M3
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 2
            implicitWidth: statusText.implicitWidth + 24
            implicitHeight: statusText.implicitHeight + 12
            radius: Appearance.shape.full
            visible: authFailed || KeyboardThings.capsLockOn
            color: authFailed ? withAlpha(Appearance.md3.error_container, 0.72) : withAlpha(Appearance.md3.tertiary_container, 0.55)
            border.width: 1
            border.color: authFailed ? Appearance.md3.error : withAlpha(Appearance.md3.tertiary, 0.5)

            StyledText {
                id: statusText

                anchors.centerIn: parent
                text: authFailed ? I18nService.getTranslation("lockscreen.incorrect_password", "Contraseña incorrecta") : I18nService.getTranslation("lockscreen.caps_lock", "Bloq Mayús activado")
                color: authFailed ? Appearance.md3.on_error_container : Appearance.md3.on_tertiary_container
                font.pixelSize: Appearance.typeScale.labelMedium
                font.weight: Font.Medium
            }
        }

        Item { Layout.fillHeight: true; Layout.preferredHeight: 8 }

        // MPRIS — solo pantalla primaria
        LockScreenMprisCard {
            id: mprisCard
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 400

            visible: isPrimary && MprisService.activePlayer !== null
            mprisPosition: mprisPosition
        }

        // Frase aleatoria en chip expresivo (decorativa, abajo del todo
        // para no competir con los avisos de huella / error / caps).
        // La forma Bun le da la personalidad; el texto sigue en pastilla
        // (MaterialShape normaliza a cuadrado y no sirve para texto ancho).
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: mprisCard.visible ? 6 : 0
            spacing: Appearance.spacing.s

            Item {
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26

                MaterialShape {
                    anchors.fill: parent
                    shape: MaterialShape.Bun
                    color: withAlpha(Appearance.md3.primary_container, 0.72)

                    MaterialIcon {
                        anchors.centerIn: parent
                        icon: "auto_awesome"
                        size: 14
                        color: Appearance.md3.on_primary_container
                    }
                }
            }

            StyledText {
                text: RandomPhraseses.splashPhrase
                color: Appearance.md3.on_surface_variant
                font.pixelSize: Appearance.typeScale.labelMedium
                font.italic: true
            }
        }

        Item { Layout.preferredHeight: 14 }
    }

    LockPowerButtons {
        anchors.fill: parent
    }

}
