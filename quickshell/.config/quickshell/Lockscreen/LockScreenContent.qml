import qs.Core
import qs.Core.Services
import qs.Primitives
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import M3Shapes

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

    // Reloj compartido para el saludo (precisión minutos: tick barato y
    // compartido por Qt; evita que el saludo quede rancio al cambiar de hora).
    SystemClock {
        id: greetingClock

        precision: SystemClock.Minutes
    }

    function triggerShake() {
        passwordInput.triggerShake();
    }

    // Respiración de la pastilla de despertar (Sunny↔VerySunny):
    // invita a tocarla. Solo corre dormido.
    property int wakeBreathShape: MaterialShape.Sunny

    Timer {
        interval: 1600
        running: !root.isAwake
        repeat: true
        onTriggered: root.wakeBreathShape = root.wakeBreathShape === MaterialShape.Sunny ? MaterialShape.VerySunny : MaterialShape.Sunny
    }

    // Al despertar, el wrapper ya relee el teclado (caps + layout): no se
    // duplica aquí para no lanzar hyprctl dos veces por etapa.

    // Al volver a dormir se resetea el progreso del gesto en el mismo
    // tick del cambio (antes del siguiente frame): la animación de salida
    // va directa de visible→reposo sin saltos intermedios.
    onIsAwakeChanged: {
        if (!isAwake)
            sleepArea.dragDy = 0;
    }

    // Ritmo compartido dormido→auth (Material motion: misma curva y
    // duración en opacidades y deslizamientos para una transición coherente).
    readonly property int stageDuration: 350

    // ── Zona de arrastre para despertar (swipe hacia arriba) ──────────
    // z:1 por debajo de la tarjeta MPRIS y la pastilla de despertar (z:2),
    // para que los controles multimedia sean clicables sin despertar.
    // Gesto coherente: el deslizamiento sigue al dedo (dragDy) y solo
    // despierta con swipe (>70px) o clic (soltar sin apenas moverse); un
    // arrastre corto vuelve a su sitio sin cambiar de etapa.
    MouseArea {
        id: sleepArea

        anchors.fill: parent
        z: root.isAwake ? -1 : 1
        enabled: !root.isAwake
        hoverEnabled: false

        property real dragStartY: 0
        property real dragDy: 0
        property bool dragging: false

        onPressed: mouse => {
            dragStartY = mouse.y;
            dragDy = 0;
            dragging = true;
        }
        onPositionChanged: mouse => {
            if (dragging)
                dragDy = Math.max(0, dragStartY - mouse.y);
        }
        onReleased: mouse => {
            if (!dragging)
                return;
            dragging = false;
            const dy = Math.max(0, dragStartY - mouse.y);
            const isClick = dy < 12;
            const isSwipe = dy > 70;
            if (isClick || isSwipe) {
                // No se resetea dragDy aquí: dormido→despierto los bindings
                // ya ignoran el gesto y el reseteo provocaba un pulso
                // (preview→reposo→despierto) que se veía como parpadeo.
                // Se limpia al volver a dormir (ver onIsAwakeChanged).
                root.wakeUp();
            } else {
                dragDy = 0;
            }
        }
        onCanceled: {
            dragging = false;
            dragDy = 0;
        }
    }

    // Scrim de foco: sigue al dedo durante el arrastre y se queda en 0.22
    // despierto, para que el fondo se atenúe A LA VEZ que asoma la
    // contraseña (antes iba con retardo y el fondo parecía parpadear).
    Rectangle {
        id: authScrim

        anchors.fill: parent
        z: 0
        color: "black"
        opacity: root.isAwake ? 0.22 : Math.min(0.22, sleepArea.dragDy / 130 * 0.22)

        Behavior on opacity {
            enabled: !sleepArea.dragging
            NumberAnimation { duration: root.stageDuration; easing.type: Easing.OutCubic }
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
        // Mientras se arrastra, la vista dormida se atenúa y el panel de
        // auth asoma siguiendo al dedo (misma dirección del swipe).
        opacity: root.isAwake ? 0 : Math.max(0, 1 - sleepArea.dragDy / 220)
        visible: opacity > 0

        Behavior on opacity {
            enabled: !sleepArea.dragging
            NumberAnimation { duration: root.stageDuration; easing.type: Easing.OutCubic }
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

            // Notificaciones pendientes (solo lectura: cualquier toque
            // en esta vista despierta vía sleepArea).
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                visible: NotificationService.history.count > 0
                implicitWidth: notifRow.implicitWidth + 28
                implicitHeight: 36
                radius: Appearance.shape.full
                color: root.withAlpha(Appearance.md3.surface_container_high, 0.72)
                border.width: 1
                border.color: root.withAlpha(Appearance.md3.outline_variant, 0.5)

                RowLayout {
                    id: notifRow
                    anchors.centerIn: parent
                    spacing: 6

                    MaterialIcon {
                        icon: "notifications"
                        size: 18
                        color: Appearance.md3.primary
                    }
                    StyledText {
                        text: NotificationService.history.count + " " + I18nService.getTranslation("lockscreen.notifications_unread", "sin leer")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                        color: Appearance.md3.on_surface_variant
                    }
                }
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

        // Pastilla inferior estilo Pixel: swipe / tecla para despertar.
        // Reacciona al arrastre: sube con el dedo y cambia el texto a
        // "suelta para desbloquear" al superar el umbral.
        Rectangle {
            id: wakePill

            z: 2
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: 40
            }
            implicitWidth: wakeRow.implicitWidth + 32
            implicitHeight: 48
            radius: Appearance.shape.full
            color: sleepArea.dragDy > 70 ? root.withAlpha(Appearance.md3.primary_container, 0.85) : root.withAlpha(Appearance.md3.surface_container_high, 0.72)
            border.width: 1
            border.color: sleepArea.dragDy > 70 ? Appearance.md3.primary : root.withAlpha(Appearance.md3.outline_variant, 0.5)

            transform: Translate {
                y: -Math.min(28, sleepArea.dragDy * 0.22)

                Behavior on y {
                    enabled: !sleepArea.dragging
                    NumberAnimation { duration: root.stageDuration; easing.type: Easing.OutCubic }
                }
            }

            Behavior on color {
                ColorAnimation { duration: 180 }
            }

            RowLayout {
                id: wakeRow
                anchors.centerIn: parent
                spacing: 8

                // Flecha en forma expresiva que respira: la invitación a
                // despertar. Región cuadrada, apta para morph.
                Item {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    Layout.alignment: Qt.AlignVCenter

                    MaterialShape {
                        anchors.fill: parent
                        shape: root.wakeBreathShape
                        animationDuration: 1400
                        color: Appearance.md3.primary_container

                        MaterialIcon {
                            id: swipeArrow
                            anchors.centerIn: parent
                            icon: "keyboard_arrow_up"
                            size: 20
                            color: Appearance.md3.on_primary_container
                        }
                    }

                    SequentialAnimation on y {
                        loops: Animation.Infinite
                        running: !root.isAwake && !sleepArea.dragging

                        NumberAnimation { from: 0; to: -4; duration: 700; easing.type: Easing.InOutSine }
                        NumberAnimation { from: -4; to: 0; duration: 700; easing.type: Easing.InOutSine }
                    }
                }

                StyledText {
                    text: sleepArea.dragDy > 70 ? I18nService.getTranslation("lockscreen.release_to_unlock", "Suelta para desbloquear") : I18nService.getTranslation("lockscreen.wake_hint", "Desliza hacia arriba o pulsa una tecla")
                    color: sleepArea.dragDy > 70 ? Appearance.md3.on_primary_container : Appearance.md3.on_surface_variant
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
    // Aparece deslizando desde abajo cuando isAwake = true, con el mismo
    // ritmo que el fundido dormido. Durante el arrastre asoma con el dedo.
    Item {
        id: authView

        anchors.fill: parent
        z: 1
        opacity: root.isAwake ? 1 : Math.min(1, sleepArea.dragDy / 130)
        visible: opacity > 0

        // Slide desde abajo: parte de +60px y sube a 0
        transform: Translate {
            id: authSlide
            y: root.isAwake ? 0 : 60 - Math.min(60, sleepArea.dragDy * 0.5)
            Behavior on y {
                enabled: !sleepArea.dragging
                NumberAnimation { duration: root.stageDuration; easing.type: Easing.OutCubic }
            }
        }

        Behavior on opacity {
            enabled: !sleepArea.dragging
            NumberAnimation { duration: root.stageDuration; easing.type: Easing.OutCubic }
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

                // Halo expresivo que "despierta" con la vista:
                // Circle dormido → Cookie9Sided despierto. Solo decoración;
                // la foto sigue con recorte circular (MaterialShape no recorta).
                MaterialShape {
                    anchors.centerIn: parent
                    width: 110
                    height: 110
                    shape: root.isAwake ? MaterialShape.Cookie9Sided : MaterialShape.Circle
                    animationDuration: 600
                    color: root.withAlpha(Appearance.md3.primary, root.isAwake ? 0.35 : 0.18)
                }

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
                            // Avatar pequeño: evita decodificar la foto entera.
                            sourceSize.width: 192
                            sourceSize.height: 192
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
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.md3.on_surface_variant
                opacity: 0.85
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
                // Solo la primaria anima la respiración (ver PasswordInput):
                // en multi-monitor ahorra N-1 timers + morphs concurrentes.
                isPrimary: root.isPrimary

                onAccepted: password => root.validatePassword(password)
                onTogglePasswordVisibility: root.togglePasswordVisibility()
                onRequestSleep: root.sleepRequested()
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
                    text: root.authFailed ? I18nService.getTranslation("lockscreen.incorrect_password", "Contraseña incorrecta") : I18nService.getTranslation("lockscreen.caps_lock", "Bloq Mayús activado")
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

            // Frase aleatoria en chip expresivo (decorativa, abajo del todo
            // para no competir con los avisos de huella / error / caps).
            // La forma Bun le da la personalidad; el texto sigue en pastilla
            // (MaterialShape normaliza a cuadrado y no sirve para texto ancho).
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: mprisCard.visible ? 6 : 0
                spacing: 8

                Item {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26

                    MaterialShape {
                        anchors.fill: parent
                        shape: MaterialShape.Bun
                        color: root.withAlpha(Appearance.md3.primary_container, 0.72)

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
                    opacity: 0.8
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.italic: true
                }
            }

            Item { Layout.preferredHeight: 14 }
        }

        // Acciones seguras sin desbloquear: esquina inferior derecha,
        // apiladas en vertical y discretas.
        Item {
            anchors.fill: parent

            Column {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 16
                spacing: 12

                Repeater {
                    model: [
                        { icon: "power_settings_new", cmd: ["systemctl", "poweroff"], name: "Apagar" },
                        { icon: "restart_alt", cmd: ["systemctl", "reboot"], name: "Reiniciar" }
                    ]

                    delegate: Rectangle {
                        required property var modelData

                        implicitWidth: 44
                        implicitHeight: 44
                        radius: 22
                        color: powerMouse.containsMouse ? root.withAlpha(Appearance.md3.error_container, 0.5) : root.withAlpha(Appearance.md3.surface_container_high, 0.72)
                        border.width: 1
                        border.color: root.withAlpha(Appearance.md3.outline_variant, 0.5)

                        Accessible.role: Accessible.Button
                        Accessible.name: modelData.name

                        MaterialIcon {
                            anchors.centerIn: parent
                            icon: modelData.icon
                            size: 22
                            color: powerMouse.containsMouse ? Appearance.md3.error : Appearance.md3.on_surface_variant
                        }

                        MouseArea {
                            id: powerMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: powerProc.start(modelData.cmd)
                        }

                        Process {
                            id: powerProc
                            function start(cmd) {
                                powerProc.command = cmd;
                                powerProc.running = true;
                            }
                        }
                    }
                }
            }
        }
    }
}
