import qs.Core.Services as Services
import QtQuick

IconTextOSD {
    id: root

    type: "gameMode"
    osdIcon: "gamepad"
    osdText: ""

    Connections {
        target: Services.GameMode

        function onEnabledChanged() {
            root.osdText = "Game Mode " + (Services.GameMode.enabled ? "Activado" : "Desactivado");
            root.show();
        }
    }
}
