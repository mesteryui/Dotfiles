// PanelWithControlsContent — Content Material 3 Expressive
// Toda la UI del panel construida con qs.Primitives.
pragma ComponentBehavior: Bound
import qs.Core.Services as Services
import qs.Primitives
import qs.Core
import qs.Core.Modules
import qs.Panels.Controls.Tabs
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Networking

Item {
    id: root

    // ── Datos recibidos del Wrapper ────────────────────────────────
    required property string username
    required property string hostname
    required property var btAdapter
    required property var audioSink

    readonly property bool btEnabled: btAdapter ? btAdapter.enabled : false
    readonly property bool wifiEnabled: Networking.wifiEnabled

    // ── Focus-visible ────────────────────────────────────────────
    // keyboardMode=false → ningún anillo de foco aunque haya foco activo
    // (ratón o foco inicial silencioso). Cualquier tecla lo pone a true y
    // cualquier uso del ratón lo devuelve a false. Así el panel no "grita"
    // el foco hasta que se usa el teclado.
    property bool keyboardMode: false

    function focusDefault() {
        root.keyboardMode = false;
        flick.contentY = 0;
        volumeSlider.forceActiveFocus();
    }

    function focusAboveToggles() {
        if (brightnessSlider.visible)
            brightnessSlider.forceActiveFocus();
        else
            volumeSlider.forceActiveFocus();
    }

    readonly property var tabModel: [
        {
            label: Services.I18nService.getTranslation("panel.system", "Sistema"),
            icon: "memory"
        },
        {
            label: Services.I18nService.getTranslation("panel.weather", "Clima"),
            icon: "partly_cloudy_day"
        }
    ]
    property int currentTab: 0

    // Hueco real para la pestaña de clima: lo que queda de ventana bajo
    // la cabecera. Así el scroll interno llega a todo sin que el global
    // tenga que moverse.
    property int weatherMaxHeight: 420

    function updateWeatherCap() {
        const top = stack.mapToItem(flick.contentItem, 0, 0).y - flick.contentY;
        root.weatherMaxHeight = Math.max(220, flick.height - top - 16);
    }

    onCurrentTabChanged: {
        scrollToTabs();
        updateWeatherCap();
        weatherFlick.contentY = 0;
    }

    // Alto "natural" (sin recortar) que el Wrapper usa para decidir si
    // hace falta activar el scroll. El Item en sí se estira al alto que
    // le dé el Wrapper (posiblemente menor que este valor).
    readonly property int naturalHeight: mainColumn.implicitHeight + 16

    // ── Helper ─────────────────────────────────────────────────────
    function withAlpha(hex, a) {
        const c = Qt.color(hex);
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    // ── Scroll por teclado ─────────────────────────────────────────
    // El foco mueve el scroll (ensureVisible) y RePág/AvPág/Inicio/Fin
    // desplazan el contenido. Los sliders consumen esas teclas para
    // ajustar el valor; el resto de controles las propagan hasta
    // mainColumn, que las gestiona aquí de forma centralizada.
    function scrollBy(dy) {
        if (flick.contentHeight <= flick.height)
            return;
        flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, flick.contentY + dy));
    }

    function scrollTop() {
        flick.contentY = 0;
    }

    function scrollBottom() {
        if (flick.contentHeight > flick.height)
            flick.contentY = flick.contentHeight - flick.height;
    }

    function ensureVisible(item, margin) {
        if (!item || flick.contentHeight <= flick.height)
            return;
        const m = margin ?? 8;
        const p = item.mapToItem(flick.contentItem, 0, 0);
        const y0 = p.y - m;
        const y1 = p.y + (item.height ?? 0) + m;
        if (y0 < flick.contentY)
            flick.contentY = Math.max(0, y0);
        else if (y1 > flick.contentY + flick.height)
            flick.contentY = Math.min(flick.contentHeight - flick.height, y1 - flick.height);
    }

    function scrollToTabs() {
        if (!flick.height)
            return;
        if (flick.contentHeight <= flick.height) {
            flick.contentY = 0;
            return;
        }
        const y = tabBar.mapToItem(flick.contentItem, 0, -12).y;
        flick.contentY = Math.max(0, Math.min(y, flick.contentHeight - flick.height));
    }

    function focusTab(index) {
        const pill = tabRepeater.itemAt(index);
        if (pill)
            pill.forceActiveFocus();
    }

    // ── UI Principal (scrolleable) ───────────────────────────────────
    Flickable {
        id: flick

        anchors.fill: parent
        onHeightChanged: updateWeatherCap()
        // Área de scroll insetada por los cuatro lados: ni la scrollbar
        // (ancho 4px) ni el contenido pisan las esquinas redondeadas
        // de la ventana (radio 30). 16px arriba/abajo dejan la barra
        // dentro incluso en la zona de la curva.
        anchors.topMargin: 16
        anchors.rightMargin: 4
        anchors.bottomMargin: 16
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: width
        contentHeight: mainColumn.implicitHeight + 16

        // Scrollbar fina M3 del proyecto (se oculta si no hace falta).
        ScrollBar.vertical: StyledScrollBar {}

        ColumnLayout {
            id: mainColumn
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 16
                // El padding superior visual lo aporta el topMargin del
                // Flickable (16 + 0 = 16, igual que antes).
                topMargin: 0
            }

            spacing: 12

            // RePág/AvPág/Inicio/Fin no tienen señal dedicada en Keys:
            // se gestionan con el manejador genérico onPressed.
            Keys.onPressed: event => {
                if (event.key === Qt.Key_PageDown) {
                    root.scrollBy(flick.height * 0.8);
                    event.accepted = true;
                } else if (event.key === Qt.Key_PageUp) {
                    root.scrollBy(-flick.height * 0.8);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Home) {
                    root.scrollTop();
                    event.accepted = true;
                } else if (event.key === Qt.Key_End) {
                    root.scrollBottom();
                    event.accepted = true;
                } else {
                    root.keyboardMode = true;
                }
            }

            // ══ HEADER — Avatar + Usuario + Power button ═════════════════
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // Avatar circular (misma técnica que LockScreenContent):
                // StyledClippingRectangle con radius width/2 recorta
                // la foto a círculo. Sin borde.
                StyledClippingRectangle {
                    Layout.preferredWidth: 50
                    Layout.preferredHeight: 50
                    Layout.alignment: Qt.AlignVCenter
                    radius: Appearance.shape.full
                    border.width: 2
                    border.color: Appearance.md3.primary
                    Image {
                        id: faceImage

                        anchors.fill: parent
                        source: Qt.resolvedUrl(Directories.home + "/.face")
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 44
                        sourceSize.height: 44
                        asynchronous: true
                        cache: true
                        visible: status === Image.Ready
                    }
                }

                // Nombre + Hostname
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    StyledText {
                        text: root.username || "usuario"
                        color: Appearance.md3.on_surface
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Medium
                        font.family: Appearance.font.sans
                    }
                    StyledText {
                        text: root.hostname || "localhost"
                        color: Appearance.md3.on_surface_variant
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.family: Appearance.font.sans
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                // Botón apagar sesión (Power Button con micro-animación)
                Rectangle {
                    id: powerButton

                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    radius: 20
                    color: powerArea.pressed ? root.withAlpha(Appearance.md3.error_container, 0.9) : (powerArea.containsMouse ? root.withAlpha(Appearance.md3.error_container, 0.4) : Appearance.md3.surface_container_high)
                    border.width: (activeFocus && root.keyboardMode) ? 2 : 0
                    border.color: Appearance.md3.primary
                    activeFocusOnTab: true

                    Accessible.role: Accessible.Button
                    Accessible.name: "Apagar sesión"

                    Keys.onPressed: root.keyboardMode = true
                    Keys.onReturnPressed: buttonProc.running = true
                    Keys.onEnterPressed: buttonProc.running = true
                    Keys.onSpacePressed: buttonProc.running = true
                    Keys.onDownPressed: volumeSlider.forceActiveFocus()

                    onActiveFocusChanged: {
                        if (activeFocus)
                            root.ensureVisible(powerButton);
                    }

                    scale: powerArea.pressed ? 0.92 : (powerArea.containsMouse ? 1.06 : 1.0)

                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: 140
                            easing.type: Easing.OutCubic
                        }
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        icon: "power_settings_new"
                        size: Appearance.font.pixelSize.large
                        color: powerArea.containsMouse ? Appearance.md3.error : Appearance.md3.on_surface_variant

                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }
                    }

                    MouseArea {
                        id: powerArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.keyboardMode = false
                        onPressed: {
                            powerButton.forceActiveFocus();
                            root.keyboardMode = false;
                        }
                        onClicked: buttonProc.running = true

                        Process {
                            id: buttonProc

                            // Sin `bash -c` intermedio: argv directo al mismo
                            // endpoint que usa el atajo de hyprland.
                            command: ["qs", "ipc", "call", "ui.powermenu", "togglePowerMenu"]
                        }
                    }
                }
            }

            // ══ SLIDERS — Volumen + Brillo (usando Primitives.ControlSlider) ══
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                // Volumen
                ControlSlider {
                    id: volumeSlider
                    Layout.fillWidth: true
                    iconName: Services.AudioService.materialIcon
                    value: Services.AudioService.volume ?? 0
                    accentColor: Appearance.md3.primary
                    accessibleName: "Volumen"
                    keyboardMode: root.keyboardMode
                    onMoved: val => {
                        if (Services.AudioService.audio) {
                            Services.AudioService.audio.volume = val;
                        }
                    }
                    onIconClicked: {
                        if (Services.AudioService.audio) {
                            Services.AudioService.audio.muted = !Services.AudioService.audio.muted;
                        }
                    }
                    Keys.onPressed: root.keyboardMode = true
                    Keys.onUpPressed: powerButton.forceActiveFocus()
                    Keys.onDownPressed: {
                        if (brightnessSlider.visible)
                            brightnessSlider.forceActiveFocus();
                        else
                            wifiToggle.forceActiveFocus();
                    }
                    onActiveFocusChanged: {
                        if (activeFocus)
                            root.ensureVisible(volumeSlider);
                    }
                    onMouseUsed: root.keyboardMode = false
                }

                // Brillo
                ControlSlider {
                    id: brightnessSlider
                    Layout.fillWidth: true
                    visible: Services.BrightnessService.ready
                    // Roundtrip lento (spawn + sysfs): eco local al arrastrar.
                    liveEcho: true
                    iconName: {
                        const b = Services.BrightnessService.brightness;
                        if (b > 0.6)
                            return "brightness_high";
                        if (b > 0.3)
                            return "brightness_medium";
                        return "brightness_low";
                    }
                    value: Services.BrightnessService.brightness
                    accentColor: Appearance.md3.tertiary
                    accessibleName: "Brillo"
                    keyboardMode: root.keyboardMode
                    onMoved: val => Services.BrightnessService.setBrightness(val)
                    Keys.onPressed: root.keyboardMode = true
                    Keys.onUpPressed: volumeSlider.forceActiveFocus()
                    Keys.onDownPressed: wifiToggle.forceActiveFocus()
                    onActiveFocusChanged: {
                        if (activeFocus)
                            root.ensureVisible(brightnessSlider);
                    }
                    onMouseUsed: root.keyboardMode = false
                }
            }

            // ══ DIVISOR ════════════════════════════════════════════════
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: root.withAlpha(Appearance.md3.outline_variant, 0.4)
            }

            // ══ TOGGLES — Quick Settings (usando Primitives.ControlToggle) ══
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: 8
                columnSpacing: 8
                uniformCellWidths: true

                // WiFi
                ControlToggle {
                    id: wifiToggle
                    Layout.fillWidth: true
                    iconName: root.wifiEnabled ? "wifi" : "wifi_off"
                    label: Services.I18nService.getTranslation("panel.wifi", "WiFi")
                    stateText: root.wifiEnabled ? Services.I18nService.getTranslation("panel.connected", "Conectado") : Services.I18nService.getTranslation("panel.disconnected", "Desconectado")
                    active: root.wifiEnabled
                    enable: Networking.wifiHardwareEnabled
                    keyboardMode: root.keyboardMode
                    onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
                    KeyNavigation.right: btToggle
                    Keys.onPressed: root.keyboardMode = true
                    Keys.onUpPressed: root.focusAboveToggles()
                    Keys.onDownPressed: cafeToggle.forceActiveFocus()
                    onActiveFocusChanged: {
                        if (activeFocus)
                            root.ensureVisible(wifiToggle);
                    }
                    onMouseUsed: root.keyboardMode = false
                }

                // Bluetooth
                ControlToggle {
                    id: btToggle
                    Layout.fillWidth: true
                    iconName: root.btEnabled ? "bluetooth" : "bluetooth_disabled"
                    label: Services.I18nService.getTranslation("panel.bluetooth", "Bluetooth")
                    stateText: !root.btEnabled ? Services.I18nService.getTranslation("panel.off", "Desactivado") : (Services.BluetoothService.connectedBatteryPct >= 0 ? Services.I18nService.getTranslation("panel.on", "Activado") + " · " + Services.BluetoothService.connectedBatteryPct + "%" : Services.I18nService.getTranslation("panel.on", "Activado"))
                    active: root.btEnabled
                    enable: root.btAdapter !== null
                    keyboardMode: root.keyboardMode
                    onToggled: {
                        if (root.btAdapter)
                            root.btAdapter.enabled = !root.btAdapter.enabled;
                    }
                    KeyNavigation.left: wifiToggle
                    Keys.onPressed: root.keyboardMode = true
                    Keys.onUpPressed: root.focusAboveToggles()
                    Keys.onDownPressed: dndToggle.forceActiveFocus()
                    onActiveFocusChanged: {
                        if (activeFocus)
                            root.ensureVisible(btToggle);
                    }
                    onMouseUsed: root.keyboardMode = false
                }

                // Cafeína
                ControlToggle {
                    id: cafeToggle
                    Layout.fillWidth: true
                    iconName: "local_cafe"
                    label: Services.I18nService.getTranslation("panel.caffeine", "Cafeína")
                    stateText: Services.IdleInhibitedService.inhibited ? Services.I18nService.getTranslation("panel.caffeine_on", "Activada") : Services.I18nService.getTranslation("panel.caffeine_off", "Desactivada")
                    active: Services.IdleInhibitedService.inhibited
                    keyboardMode: root.keyboardMode
                    onToggled: Services.IdleInhibitedService.toggle()
                    KeyNavigation.right: dndToggle
                    Keys.onPressed: root.keyboardMode = true
                    Keys.onUpPressed: wifiToggle.forceActiveFocus()
                    Keys.onDownPressed: nightToggle.forceActiveFocus()
                    onActiveFocusChanged: {
                        if (activeFocus)
                            root.ensureVisible(cafeToggle);
                    }
                    onMouseUsed: root.keyboardMode = false
                }

                // No Molestar
                ControlToggle {
                    id: dndToggle
                    Layout.fillWidth: true
                    iconName: Services.NotificationService.dnd ? "bedtime" : "notifications"
                    label: Services.I18nService.getTranslation("panel.dnd", "No molestar")
                    stateText: Services.NotificationService.dnd ? Services.I18nService.getTranslation("panel.dnd_on", "Activado") : Services.I18nService.getTranslation("panel.dnd_off", "Desactivado")
                    active: Services.NotificationService.dnd
                    keyboardMode: root.keyboardMode
                    onToggled: Services.NotificationService.toggleDnd()
                    KeyNavigation.left: cafeToggle
                    Keys.onPressed: root.keyboardMode = true
                    Keys.onUpPressed: btToggle.forceActiveFocus()
                    Keys.onDownPressed: gameToggle.forceActiveFocus()
                    onActiveFocusChanged: {
                        if (activeFocus)
                            root.ensureVisible(dndToggle);
                    }
                    onMouseUsed: root.keyboardMode = false
                }
                ControlToggle {
                    id: nightToggle
                    Layout.fillWidth: true
                    iconName: Services.Hyprsunset.nightLightActive ? "bedtime" : "bedtime"
                    label: Services.I18nService.getTranslation("panel.night_light", "Luz nocturna")
                    stateText: Services.Hyprsunset.nightLightActive ? Services.I18nService.getTranslation("panel.on", "Activado") : Services.I18nService.getTranslation("panel.off", "Desactivado")
                    active: Services.Hyprsunset.nightLightActive
                    keyboardMode: root.keyboardMode
                    onToggled: Services.Hyprsunset.toggleNightLight()
                    KeyNavigation.right: gameToggle
                    Keys.onPressed: root.keyboardMode = true
                    Keys.onUpPressed: cafeToggle.forceActiveFocus()
                    Keys.onDownPressed: root.focusTab(root.currentTab)
                    onActiveFocusChanged: {
                        if (activeFocus)
                            root.ensureVisible(nightToggle);
                    }
                    onMouseUsed: root.keyboardMode = false
                }
                ControlToggle {
                    id: gameToggle
                    Layout.fillWidth: true
                    iconName: "gamepad"
                    label: Services.I18nService.getTranslation("panel.game_mode", "Modo de Juego")
                    stateText: Services.GameMode.enabled ? Services.I18nService.getTranslation("panel.on", "Activado") : Services.I18nService.getTranslation("panel.off", "Desactivado")
                    active: Services.GameMode.enabled
                    keyboardMode: root.keyboardMode
                    onToggled: Services.GameMode.toggle()
                    KeyNavigation.left: nightToggle
                    Keys.onPressed: root.keyboardMode = true
                    Keys.onUpPressed: dndToggle.forceActiveFocus()
                    Keys.onDownPressed: root.focusTab(root.currentTab)
                    onActiveFocusChanged: {
                        if (activeFocus)
                            root.ensureVisible(gameToggle);
                    }
                    onMouseUsed: root.keyboardMode = false
                }
            }

            // ══ DIVISOR ════════════════════════════════════════════════
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: root.withAlpha(Appearance.md3.outline_variant, 0.4)
            }

            // ══ TABS — Sistema / Clima (segmented buttons M3) ═════════
            RowLayout {
                id: tabBar
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    id: tabRepeater
                    model: root.tabModel

                    delegate: Rectangle {
                        id: pill

                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        radius: 20
                        color: root.currentTab === index ? Appearance.md3.primary_container : Appearance.md3.surface_container_high
                        border.width: (activeFocus && root.keyboardMode) ? 2 : 0
                        border.color: Appearance.md3.primary
                        activeFocusOnTab: true

                        Accessible.role: Accessible.PageTab
                        Accessible.name: modelData.label

                        Keys.onPressed: root.keyboardMode = true
                        Keys.onReturnPressed: root.currentTab = index
                        Keys.onEnterPressed: root.currentTab = index
                        Keys.onSpacePressed: root.currentTab = index
                        Keys.onUpPressed: gameToggle.forceActiveFocus()
                        Keys.onDownPressed: root.scrollBy(flick.height * 0.8)
                        Keys.onLeftPressed: {
                            if (index > 0) {
                                root.currentTab = index - 1;
                                root.focusTab(index - 1);
                            }
                        }
                        Keys.onRightPressed: {
                            if (index < root.tabModel.length - 1) {
                                root.currentTab = index + 1;
                                root.focusTab(index + 1);
                            }
                        }

                        onActiveFocusChanged: {
                            if (activeFocus)
                                root.ensureVisible(pill);
                        }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            MaterialIcon {
                                icon: modelData.icon
                                size: Appearance.font.pixelSize.normal
                                color: root.currentTab === index ? Appearance.md3.on_primary_container : Appearance.md3.on_surface_variant
                            }

                            StyledText {
                                text: modelData.label
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium
                                color: root.currentTab === index ? Appearance.md3.on_primary_container : Appearance.md3.on_surface_variant
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.keyboardMode = false
                            onPressed: {
                                pill.forceActiveFocus();
                                root.keyboardMode = false;
                            }
                            onClicked: root.currentTab = index
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }
                    }
                }
            }

            // ══ CONTENIDO del Tab activo ════════════════════════════════
            // Altura según la pestaña activa (no el máximo de ambas) para
            // que Sistema quepa sin apenas scroll aunque Clima sea largo.
            // Clima además topa a 420px con scroll propio: es lo único que
            // puede crecer (horas + avisos) y no debe estirar el panel.
            StackLayout {
                id: stack
                Layout.fillWidth: true
                Layout.preferredHeight: root.currentTab === 0 ? sysTab.implicitHeight : Math.min(weatherTab.implicitHeight, root.weatherMaxHeight)
                currentIndex: root.currentTab

                SysInfoTab {
                    id: sysTab
                }
                Flickable {
                    id: weatherFlick

                    contentWidth: width
                    contentHeight: weatherTab.implicitHeight
                    clip: true
                    flickableDirection: Flickable.VerticalFlick
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: StyledScrollBar {}

                    // Sin esto, la rueda mueve la pestaña Y el panel a
                    // la vez: sobre el clima solo manda la pestaña.
                    HoverHandler {
                        id: weatherHover

                        onHoveredChanged: flick.interactive = !weatherHover.hovered
                    }

                    WeatherTab {
                        id: weatherTab
                        width: parent.width
                    }
                }
            }
        }
    }
}
