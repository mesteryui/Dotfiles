import qs.Core.Services as Services
import QtQuick
import M3Shapes

IconTextOSD {
    id: root

    type: "gameMode"
    osdIcon: "gamepad"
    osdText: ""
    // Forma-identidad: Circle(inactivo) → Diamond(activo, como un mando).
    iconShape: Services.GameMode.enabled ? MaterialShape.Diamond : MaterialShape.Circle
    // Resaltado al activar.
    highlighted: Services.GameMode.enabled

    Connections {
        target: Services.GameMode

        function onEnabledChanged() {
            root.osdText = "Modo de Juego " + (Services.GameMode.enabled ? "Activado" : "Desactivado");
            root.show();
        }
    }
}
