import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs.Core
import qs.Core.Services
import qs.Primitives

Item {
    id: root
    anchors.fill: parent

    // ── Propiedades / Entradas de Estado ─────────────────────────────
    property bool authFailed: false
    property bool isAuthenticating: false
    property string promptText: ""
    property bool isPasswordVisible: false
    property real mprisPosition: 0

    property alias passwordField: passwordInput.passwordField

    signal validatePassword(string password)
    signal togglePasswordVisibility()

    function triggerShake() {
        passwordInput.triggerShake()
    }

    // ── Layout de Contenido Frontend ─────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 20

        // 1. Estado de Batería (Esquina superior derecha)
        ColumnLayout {
            Layout.alignment: Qt.AlignRight
            Item {
                Layout.preferredHeight: 2
            }
            RowLayout {
                MaterialIcon {
                    icon: BatteryService.materialIcon
                    font.pixelSize: Appearance.font.pixelSize.large
                }
                StyledText {
                    text: BatteryService.percentage + "%"
                    font.pixelSize: Appearance.font.pixelSize.large
                }
                Item {
                    Layout.preferredWidth: 2
                }
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
            implicitWidth: 96
            implicitHeight: 96

            Rectangle {
                id: avatarBg
                anchors.fill: parent
                radius: width / 2
                color: Appearance.md3.primary_container
                opacity: 0.9

                ClippingRectangle {
                    anchors.fill: parent
                    color: "transparent"
                    radius: parent.radius
                    border.color: Appearance.md3.primary
                    border.width: 2
                    Image {
                        anchors.fill: parent
                        source: Quickshell.env("HOME") + "/.face"
                        sourceSize.width: 48
                        sourceSize.height: 48
                        fillMode: Image.PreserveAspectFit
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
            authFailed: root.authFailed
            isAuthenticating: root.isAuthenticating
            promptText: root.promptText
            isPasswordVisible: root.isPasswordVisible

            onAccepted: password => root.validatePassword(password)
            onTogglePasswordVisibility: root.togglePasswordVisibility()
        }
        

        // 6. Tarjeta Multimedia MPRIS
        LockScreenMprisCard {
            id: mprisCard
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 8
            mprisPosition: root.mprisPosition
        }

        // 7. Mensajes de Estado / Errores
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: I18nService.getTranslation("lockscreen.no_correct", "Contraseña incorrecta")
            color: Appearance.md3.error
            font.pixelSize: Appearance.font.pixelSize.smaller
            opacity: root.authFailed ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: 150 }
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: I18nService.getTranslation("lockscreen.caps_lock", "Bloq Mayús activado")
            color: Appearance.md3.tertiary
            font.pixelSize: Appearance.font.pixelSize.smaller
            opacity: KeyboardThings.capsLockOn ? 1 : 0
            visible: opacity !== 0
            Behavior on opacity {
                NumberAnimation { duration: 150 }
            }
        }

        // 8. Indicación Enter
        StyledText {
            id: enterHint
            Layout.alignment: Qt.AlignHCenter
            text: I18nService.getTranslation("lockscreen.information", "Pulsa Enter para desbloquear")
            color: Appearance.md3.on_surface_variant
            font.pixelSize: Appearance.font.pixelSize.smallest
            opacity: passwordInput.passwordField.text.length > 0 ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: 200 }
            }
        }

        Item {
            Layout.fillHeight: true
        }

        // 9. Frase / Cita Aleatoria
        StyledText {
            id: quoteText
            text: RandomPhraseses.splashPhrase
            Layout.alignment: Qt.AlignHCenter
            color: Appearance.md3.on_surface_variant
            opacity: 0.7
            font.pixelSize: Appearance.font.pixelSize.smaller
        }

        Item {
            Layout.preferredHeight: 10
        }
    }
}
