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
        sysFlick.contentY = 0;
        weatherFlick.contentY = 0;
        sliders.volumeSlider.forceActiveFocus();
    }

    function focusAboveToggles() {
        if (sliders.brightnessSlider.visible)
            sliders.brightnessSlider.forceActiveFocus();
        else
            sliders.volumeSlider.forceActiveFocus();
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

    // Flickable de la pestaña activa. Cada pestaña lleva su propio
    // scroll; la cabecera (avatar, sliders, toggles, tabs) queda fija y
    // la rueda/teclado solo mueven la pestaña visible.
    readonly property var activeFlick: root.currentTab === 0 ? sysFlick : weatherFlick

    // ¿El item vive dentro de la pestaña con scroll? Lo de la cabecera
    // fija siempre se ve: no hay nada que desplazar.
    function inStack(item) {
        let p = item;
        while (p) {
            if (p === stack)
                return true;
            p = p.parent;
        }
        return false;
    }

    onCurrentTabChanged: {
        sysFlick.contentY = 0;
        weatherFlick.contentY = 0;
    }

    // ── Helper ─────────────────────────────────────────────────────
    function withAlpha(hex, a) {
        const c = Qt.color(hex);
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    // ── Scroll por teclado ─────────────────────────────────────────
    // El foco mueve el scroll de la pestaña activa (ensureVisible) y
    // RePág/AvPág/Inicio/Fin desplazan su contenido. Los sliders consumen
    // esas teclas para ajustar el valor; el resto de controles las
    // propagan hasta mainColumn, que las gestiona aquí de forma
    // centralizada.
    function scrollBy(dy) {
        const f = root.activeFlick;
        if (!f || f.contentHeight <= f.height)
            return;
        f.contentY = Math.max(0, Math.min(f.contentHeight - f.height, f.contentY + dy));
    }

    function scrollTop() {
        const f = root.activeFlick;
        if (f)
            f.contentY = 0;
    }

    function scrollBottom() {
        const f = root.activeFlick;
        if (f && f.contentHeight > f.height)
            f.contentY = f.contentHeight - f.height;
    }

    function ensureVisible(item, margin) {
        const f = root.activeFlick;
        if (!item || !f || !root.inStack(item) || f.contentHeight <= f.height)
            return;
        const m = margin ?? 8;
        const p = item.mapToItem(f.contentItem, 0, 0);
        const y0 = p.y - m;
        const y1 = p.y + (item.height ?? 0) + m;
        if (y0 < f.contentY)
            f.contentY = Math.max(0, y0);
        else if (y1 > f.contentY + f.height)
            f.contentY = Math.min(f.contentHeight - f.height, y1 - f.height);
    }

    function focusTab(index) {
        tabBar.focusPill(index);
    }

    // ── UI Principal (cabecera fija + pestañas con scroll propio) ───
    ColumnLayout {
        id: mainColumn
        anchors {
            fill: parent
            topMargin: 16
            leftMargin: Appearance.spacing.l
            rightMargin: Appearance.spacing.l
            bottomMargin: 16
        }

        spacing: Appearance.spacing.m

            // RePág/AvPág/Inicio/Fin no tienen señal dedicada en Keys:
            // se gestionan con el manejador genérico onPressed.
            Keys.onPressed: event => {
                if (event.key === Qt.Key_PageDown) {
                    root.scrollBy(root.activeFlick.height * 0.8);
                    event.accepted = true;
                } else if (event.key === Qt.Key_PageUp) {
                    root.scrollBy(-root.activeFlick.height * 0.8);
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

            ControlsHeader {
                id: header
                Layout.fillWidth: true
                host: root
                focusBelow: sliders.volumeSlider
            }

            ControlsSliders {
                id: sliders
                Layout.fillWidth: true
                host: root
                focusAbove: header.powerButton
                focusBelow: toggles.wifiToggle
            }

            // ══ DIVISOR ════════════════════════════════════════════════
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: root.withAlpha(Appearance.md3.outline_variant, 0.4)
            }

            ControlsTogglesGrid {
                id: toggles
                Layout.fillWidth: true
                host: root
            }

            // ══ DIVISOR ════════════════════════════════════════════════
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: root.withAlpha(Appearance.md3.outline_variant, 0.4)
            }

            ControlsTabBar {
                id: tabBar
                Layout.fillWidth: true
                host: root
                focusAbove: toggles.gameToggle
            }

            // ══ CONTENIDO del Tab activo ════════════════════════════════
            // Cada pestaña tiene su propio scroll y ocupa todo el alto
            // libre bajo la cabecera fija: la rueda solo mueve la pestaña
            // visible, nunca la ventana.
            StackLayout {
                id: stack
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: root.currentTab

                Flickable {
                    id: sysFlick

                    contentWidth: width
                    contentHeight: sysTab.implicitHeight
                    clip: true
                    flickableDirection: Flickable.VerticalFlick
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: StyledScrollBar {}

                    SysInfoTab {
                        id: sysTab
                        width: parent.width
                    }
                }
                Flickable {
                    id: weatherFlick

                    contentWidth: width
                    contentHeight: weatherTab.implicitHeight
                    clip: true
                    flickableDirection: Flickable.VerticalFlick
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: StyledScrollBar {}

                    WeatherTab {
                        id: weatherTab
                        width: parent.width
                    }
                }
            }
    }
}
