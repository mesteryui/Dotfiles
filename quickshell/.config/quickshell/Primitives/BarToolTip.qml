pragma ComponentBehavior: Bound

import qs.Core
import qs.Core.Services
import QtQuick
import Quickshell

// BarToolTip — tooltip nativo de Quickshell para items de barra.
//
// No usa QtQuick.Controls.ToolTip: ese abre una ventana Qt que el
// compositor coloca por su cuenta y acababa apareciendo en medio de la
// pantalla. Este es un `PopupWindow` anclado al item, así que cae sobre
// la superficie de la barra y se pega al borde exterior: debajo si la
// barra está arriba, encima si está abajo. Nunca la solapa, por lo que
// tampoco roba el hover del item (lo que hacía parpadear al tooltip).
//
// Uso:
//   BarToolTip {
//       anchorItem: root
//       text: "..."
//       shown: root.hovered
//   }
PopupWindow {
    id: root

    // Item de barra al que se ancla (normalmente el propio BarItem).
    required property Item anchorItem

    property string text: ""

    // true mientras el item está en hover; el tooltip sale tras `delay`.
    property bool shown: false

    // ms antes de mostrarse y antes de auto-ocultarse.
    property int delay: 500
    property int timeout: 5000

    // Separación entre la barra y el tooltip.
    property int gap: 8

    readonly property bool barAtBottom: ConfigService.configs.bar.position === "bottom"

    readonly property int barHeight: ConfigService.configs.bar.height || 36

    // El item va centrado en la barra, que sobresale (barHeight -
    // itemHeight)/2 a cada lado. Sumado al `gap` da cuánto hay que
    // extender el rect de anclaje para no pisarla.
    readonly property int _itemHeight: root.anchorItem ? root.anchorItem.height : 0

    readonly property int _barOverhang: Math.round((root.barHeight - root._itemHeight) / 2)

    readonly property int _offset: root.gap + root._barOverhang

    // Ocultado por timeout: no vuelve a salir hasta el siguiente hover.
    property bool _timedOut: false

    color: "transparent"
    grabFocus: false
    visible: false

    implicitWidth: label.implicitWidth + 24
    implicitHeight: label.implicitHeight + 16

    onShownChanged: {
        if (root.shown) {
            if (!root._timedOut)
                showTimer.restart();
        } else {
            root._timedOut = false;
            showTimer.stop();
            hideTimer.stop();
            root.visible = false;
        }
    }

    Timer {
        id: showTimer

        interval: root.delay
        onTriggered: {
            root.visible = true;
            hideTimer.restart();
        }
    }

    Timer {
        id: hideTimer

        interval: root.timeout
        onTriggered: {
            root.visible = false;
            root._timedOut = true;
        }
    }

    // ── Anclaje ───────────────────────────────────────────────
    // `edges` marca el borde del item contra el que se pega y `gravity`
    // la dirección en la que crece el tooltip. El `rect` extiende ese
    // borde `gap` px para no pisar la barra.
    anchor {
        item: root.anchorItem

        rect {
            x: 0
            y: root.barAtBottom ? -root._offset : 0
            width: root.anchorItem ? root.anchorItem.width : 0
            height: root._itemHeight + root._offset
        }

        edges: root.barAtBottom ? Edges.Top : Edges.Bottom
        gravity: root.barAtBottom ? Edges.Top : Edges.Bottom
        adjustment: PopupAdjustment.SlideX
    }

    // ── Contenido ─────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: Appearance.shape.extraSmall
        color: Appearance.md3.surface
    }

    StyledText {
        id: label

        anchors.centerIn: parent
        text: root.text
        color: Appearance.md3.on_surface
        font.pixelSize: Appearance.typeScale.labelMedium
        wrapMode: Text.NoWrap
    }
}
