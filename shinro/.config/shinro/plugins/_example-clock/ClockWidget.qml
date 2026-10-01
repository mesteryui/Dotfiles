// Widget de ejemplo (ver PLUGINS.md): reloj que demuestra la inyección
// de `plugin`, el tema heredado (Appearance) y tamaño implícito.

import qs.Core
import QtQuick

Item {
    id: root

    property var plugin

    implicitWidth: clockText.implicitWidth + 16
    implicitHeight: 36

    Text {
        id: clockText

        anchors.centerIn: parent
        color: Appearance.md3.on_surface
        font.pixelSize: Appearance.typeScale.bodyLarge
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const d = new Date();
            const p = n => (n < 10 ? "0" + n : "" + n);
            clockText.text = p(d.getHours()) + ":" + p(d.getMinutes());
        }
    }
}
