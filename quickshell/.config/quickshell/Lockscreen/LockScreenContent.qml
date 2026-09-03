import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import qs.Core
import qs.Core.Services
import qs.Primitives

Item {
    id: root
    anchors.fill: parent

    // ── Propiedades / Entradas de Estado ─────────────────────────────
    property bool isPrimary: true
    property bool authFailed: false
    property bool isAuthenticating: false
    property string promptText: ""
    property bool isPasswordVisible: false
    property bool isFingerprintActive: false
    property real mprisPosition: 0

    property alias passwordField: passwordInput.passwordField

    signal validatePassword(string password)
    signal togglePasswordVisibility

    function triggerShake() {
        passwordInput.triggerShake();
    }

    // ── Layout de Contenido Frontend ─────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 20

        // 1. Estado de Batería (Esquina superior derecha)
        RowLayout {
            Layout.alignment: Qt.AlignRight
            Layout.topMargin: 6
            Layout.rightMargin: 6
            spacing: 4

            MaterialIcon {
                icon: BatteryService.materialIcon
                font.pixelSize: Appearance.font.pixelSize.large
                color: Appearance.md3.on_surface_variant
            }
            StyledText {
                text: BatteryService.percentage + "%"
                font.pixelSize: Appearance.font.pixelSize.large
                color: Appearance.md3.on_surface_variant
            }
        }

        Item {
            Layout.fillHeight: true
        }

        // 2. Reloj y Fecha
        LockScreenClock {
            id: dateTime
            Layout.alignment: Qt.AlignHCenter
        }

        // 3. Avatar del usuario
        Item {
            id: avatarWrapper
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 8
            implicitWidth: 96
            implicitHeight: 96

            Rectangle {
                id: avatarBg
                anchors.fill: parent
                radius: width / 2
                color: Appearance.md3.primary_container
                opacity: 0.9

                StyledClippingRectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    border.color: Appearance.md3.primary
                    border.width: 2
                    Image {
                        anchors.fill: parent
                        source: Quickshell.env("HOME") + "/.face"
                        sourceSize.width: 48
                        sourceSize.height: 48
                        fillMode: Image.PreserveAspectCrop
                    }
                }
            }

            MultiEffect {
                anchors.fill: avatarBg
                source: avatarBg
                shadowEnabled: true
                shadowColor: Appearance.md3.shadow
                shadowOpacity: 0.22
                shadowBlur: 0.7
                shadowVerticalOffset: 2
                shadowHorizontalOffset: 0
            }
        }

        // 4. Nombre de usuario
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Quickshell.env("USER")
            font.pixelSize: Appearance.font.pixelSize.title
            font.variableAxes: Appearance.font.variableAxes.title
            color: Appearance.md3.on_surface
        }

        // 5. Campo de Contraseña
        LockScreenPasswordInput {
            id: passwordInput
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 4
            authFailed: root.authFailed
            isAuthenticating: root.isAuthenticating
            promptText: root.promptText
            isPasswordVisible: root.isPasswordVisible
            isFingerprintActive: root.isFingerprintActive

            onAccepted: password => root.validatePassword(password)
            onTogglePasswordVisibility: root.togglePasswordVisibility()
        }

        // 6. Mensaje de estado (error de contraseña / Bloq Mayús)
        // Comparten una única línea de altura fija para que aparecer/
        // desaparecer no desplace el resto del layout. Prioridad: error de
        // autenticación > aviso de Bloq Mayús.
        Item {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: statusText.implicitWidth
            implicitHeight: statusText.implicitHeight

            StyledText {
                id: statusText
                anchors.centerIn: parent
                text: root.authFailed ? I18nService.getTranslation("lockscreen.no_correct", "Contraseña incorrecta") : I18nService.getTranslation("lockscreen.caps_lock", "Bloq Mayús activado")
                color: root.authFailed ? Appearance.md3.error : Appearance.md3.tertiary
                font.pixelSize: Appearance.font.pixelSize.smaller
                opacity: (root.authFailed || KeyboardThings.capsLockOn) ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }
            }
        }

        // 7. Indicación Enter
        StyledText {
            id: enterHint
            Layout.alignment: Qt.AlignHCenter
            text: I18nService.getTranslation("lockscreen.information", "Pulsa Enter para desbloquear")
            color: Appearance.md3.on_surface_variant
            font.pixelSize: Appearance.font.pixelSize.smallest
            opacity: passwordInput.passwordField.text.length > 0 ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }

        // 8. Tarjeta Multimedia MPRIS — solo en la pantalla primaria, para no
        // duplicar los controles de reproducción en cada monitor.
        LockScreenMprisCard {
            id: mprisCard
            Layout.alignment: Qt.AlignHCenter
            visible: root.isPrimary
            mprisPosition: root.mprisPosition
        }

        // 9. Frase / Cita Aleatoria
        StyledText {
            id: quoteText
            text: RandomPhraseses.splashPhrase
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: mprisCard.visible ? 8 : 0
            color: Appearance.md3.on_surface_variant
            opacity: 0.7
            font.pixelSize: Appearance.font.pixelSize.smaller
        }

        Item {
            Layout.preferredHeight: 10
        }
    }
}
