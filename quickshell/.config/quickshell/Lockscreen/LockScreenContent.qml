import qs.Core
import qs.Core.Services
import qs.Primitives
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell

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

    // Controlado desde LockScreenWrapper
    property bool isAwake: false

    property alias passwordField: passwordInput.passwordField

    signal validatePassword(string password)
    signal togglePasswordVisibility
    signal wakeUp
    signal sleepRequested

    function withAlpha(hexColor, alphaValue) {
        var c = Qt.color(hexColor);
        return Qt.rgba(c.r, c.g, c.b, alphaValue);
    }

    function triggerShake() {
        passwordInput.triggerShake();
    }

    // ── Zona de arrastre para despertar (swipe hacia arriba) ──────────
    // z:1 por debajo de la tarjeta MPRIS y la pastilla de despertar (z:2),
    // para que los controles multimedia sean clicables sin despertar.
    MouseArea {
        id: sleepArea

        anchors.fill: parent
        z: root.isAwake ? -1 : 1
        enabled: !root.isAwake
        hoverEnabled: false

        property real dragStartY: 0
        property bool dragging: false

        onPressed: mouse => {
            dragStartY = mouse.y;
            dragging = true;
        }
        onReleased: mouse => {
            if (dragging) {
                const dy = dragStartY - mouse.y;
                if (dy > 40)
                    root.wakeUp();
                else
                    root.wakeUp(); // cualquier clic también despierta
            }
            dragging = false;
        }
    }

    // ── 1. VISTA DORMIDA: Reloj centrado ─────────────────────────────
    // Visible cuando !isAwake. Al despertar sube y se hace más pequeño.
    Item {
        id: sleepView

        anchors.fill: parent
        // Por encima de sleepArea (z:1): los botones del MPRIS y la pastilla
        // reciben sus clics primero; el fondo transparente deja pasar el
        // resto a sleepArea para despertar. Si sleepView quedase por debajo,
        // ningún z interno del MPRIS podría rescatar los clics.
        z: 2
        opacity: root.isAwake ? 0 : 1
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: 320; easing.type: Easing.InOutQuad }
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 18

            // Chip de batería M3 (tonal, pill)
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: batteryRow.implicitWidth + 28
                implicitHeight: 36
                radius: Appearance.shape.full
                color: root.withAlpha(Appearance.md3.surface_container_high, 0.72)
                border.width: 1
                border.color: root.withAlpha(Appearance.md3.outline_variant, 0.5)

                RowLayout {
                    id: batteryRow
                    anchors.centerIn: parent
                    spacing: 6

                    MaterialIcon {
                        icon: BatteryService.materialIcon
                        size: 18
                        color: Appearance.md3.on_surface_variant
                    }
                    StyledText {
                        text: BatteryService.percentage + "%"
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.DemiBold
                        color: Appearance.md3.on_surface_variant
                    }
                }
            }

            // Reloj hero estilo Pixel
            LockScreenClock {
                Layout.alignment: Qt.AlignHCenter
                compact: false
            }

            // MPRIS en el estado dormido (si hay música).
            // Por encima de sleepArea para que play/pause/next sean usables
            // directamente sin despertar (estilo Pixel).
            LockScreenMprisCard {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 400
                z: 2
                visible: root.isPrimary && MprisService.activePlayer !== null
                mprisPosition: root.mprisPosition
            }
        }

        // Pastilla inferior estilo Pixel: swipe / tecla para despertar
        Rectangle {
            z: 2
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: 40
            }
            implicitWidth: wakeRow.implicitWidth + 32
            implicitHeight: 48
            radius: Appearance.shape.full
            color: root.withAlpha(Appearance.md3.surface_container_high, 0.72)
            border.width: 1
            border.color: root.withAlpha(Appearance.md3.outline_variant, 0.5)

            RowLayout {
                id: wakeRow
                anchors.centerIn: parent
                spacing: 8

                MaterialIcon {
                    id: swipeArrow
                    icon: "keyboard_arrow_up"
                    size: 22
                    color: Appearance.md3.primary

                    SequentialAnimation on y {
                        loops: Animation.Infinite
                        running: !root.isAwake

                        NumberAnimation { from: 0; to: -4; duration: 700; easing.type: Easing.InOutSine }
                        NumberAnimation { from: -4; to: 0; duration: 700; easing.type: Easing.InOutSine }
                    }
                }

                StyledText {
                    text: I18nService.getTranslation("lockscreen.wake_hint", "Desliza hacia arriba o pulsa una tecla")
                    color: Appearance.md3.on_surface_variant
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.Medium
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.wakeUp()
            }
        }
    }

    // ── 2. VISTA DESPIERTA: Panel de autenticación Material You ───────
    // Aparece deslizando desde abajo cuando isAwake = true.
    Item {
        id: authView

        anchors.fill: parent
        opacity: root.isAwake ? 1 : 0
        visible: opacity > 0

        // Slide desde abajo: parte de +60px y sube a 0
        transform: Translate {
            id: authSlide
            y: root.isAwake ? 0 : 60
            Behavior on y {
                NumberAnimation { duration: 380; easing.type: Easing.OutExpo }
            }
        }

        Behavior on opacity {
            NumberAnimation { duration: 320; easing.type: Easing.OutExpo }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 12

            // Barra superior M3: volver a dormir (GNOME) + chip batería
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 12
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                spacing: 8

                Rectangle {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    radius: width / 2
                    color: downMouse.containsMouse ? root.withAlpha(Appearance.md3.on_surface, 0.10) : root.withAlpha(Appearance.md3.surface_container_high, 0.72)
                    border.width: 1
                    border.color: root.withAlpha(Appearance.md3.outline_variant, 0.5)

                    MaterialIcon {
                        anchors.centerIn: parent
                        icon: "keyboard_arrow_down"
                        size: 22
                        color: Appearance.md3.on_surface_variant
                    }
                    MouseArea {
                        id: downMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.sleepRequested()
                    }
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    Layout.preferredHeight: 36
                    Layout.preferredWidth: authBatteryRow.implicitWidth + 28
                    radius: Appearance.shape.full
                    color: root.withAlpha(Appearance.md3.surface_container_high, 0.72)
                    border.width: 1
                    border.color: root.withAlpha(Appearance.md3.outline_variant, 0.5)

                    RowLayout {
                        id: authBatteryRow
                        anchors.centerIn: parent
                        spacing: 6
                        MaterialIcon {
                            icon: BatteryService.materialIcon
                            size: 18
                            color: Appearance.md3.on_surface_variant
                        }
                        StyledText {
                            text: BatteryService.percentage + "%"
                            font.pixelSize: Appearance.font.pixelSize.small
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

                Rectangle {
                    id: avatarBg

                    anchors.fill: parent
                    radius: width / 2
                    color: root.withAlpha(Appearance.md3.primary_container, 0.92)
                    border.color: Appearance.md3.primary
                    border.width: 2

                    MaterialIcon {
                        anchors.centerIn: parent
                        icon: "person"
                        size: 44
                        color: Appearance.md3.on_primary_container
                        visible: !faceImage.visible
                    }

                    StyledClippingRectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        border.width: 0

                        Image {
                            id: faceImage
                            anchors.fill: parent
                            source: Quickshell.env("HOME") + "/.face"
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            visible: status === Image.Ready
                        }
                    }
                }

                MultiEffect {
                    anchors.fill: avatarBg
                    source: avatarBg
                    shadowEnabled: true
                    shadowColor: Appearance.md3.shadow
                    shadowOpacity: 0.24
                    shadowBlur: 0.9
                    shadowVerticalOffset: 3
                    shadowHorizontalOffset: 0
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

            // Huella activa: pastilla tonal tipo Pixel (mantiene password como alternativa GNOME)
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 2
                visible: root.isFingerprintActive
                implicitWidth: fpRow.implicitWidth + 28
                implicitHeight: 32
                radius: Appearance.shape.full
                color: root.withAlpha(Appearance.md3.primary, 0.16)
                border.width: 1
                border.color: root.withAlpha(Appearance.md3.primary, 0.35)

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
                        font.pixelSize: Appearance.font.pixelSize.smaller
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

                authFailed: root.authFailed
                isAuthenticating: root.isAuthenticating
                promptText: root.promptText
                isPasswordVisible: root.isPasswordVisible
                isFingerprintActive: root.isFingerprintActive

                onAccepted: password => root.validatePassword(password)
                onTogglePasswordVisibility: root.togglePasswordVisibility()
            }

            // Mensaje de estado (error / Bloq Mayús) en pastilla M3
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 2
                implicitWidth: statusText.implicitWidth + 24
                implicitHeight: statusText.implicitHeight + 12
                radius: Appearance.shape.full
                visible: root.authFailed || KeyboardThings.capsLockOn
                color: root.authFailed ? root.withAlpha(Appearance.md3.error_container, 0.72) : root.withAlpha(Appearance.md3.tertiary_container, 0.55)
                border.width: 1
                border.color: root.authFailed ? Appearance.md3.error : root.withAlpha(Appearance.md3.tertiary, 0.5)

                StyledText {
                    id: statusText

                    anchors.centerIn: parent
                    text: root.authFailed ? I18nService.getTranslation("lockscreen.no_correct", "Contraseña incorrecta") : I18nService.getTranslation("lockscreen.caps_lock", "Bloq Mayús activado")
                    color: root.authFailed ? Appearance.md3.on_error_container : Appearance.md3.on_tertiary_container
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.Medium
                }
            }

            Item { Layout.fillHeight: true; Layout.preferredHeight: 8 }

            // MPRIS — solo pantalla primaria
            LockScreenMprisCard {
                id: mprisCard
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 400

                visible: root.isPrimary && MprisService.activePlayer !== null
                mprisPosition: root.mprisPosition
            }

            // Frase aleatoria (decorativa, abajo del todo para no competir
            // con los avisos de huella / error / caps)
            StyledText {
                text: RandomPhraseses.splashPhrase
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: mprisCard.visible ? 6 : 0
                color: Appearance.md3.on_surface_variant
                opacity: 0.7
                font.pixelSize: Appearance.font.pixelSize.smaller
            }

            Item { Layout.preferredHeight: 14 }
        }
    }
}
