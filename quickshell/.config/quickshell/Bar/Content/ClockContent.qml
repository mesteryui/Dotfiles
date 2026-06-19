import QtQuick
import Quickshell
import qs.Core
import qs.Features.Subwindows
import qs.Core.Services as Services

Item {
    id: root
    implicitWidth: clockText.implicitWidth
    implicitHeight: clockText.implicitHeight
    
    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }
    
    Text {
        id: clockText
        anchors.centerIn: parent
        font.family: Services.ConfigService.getConfig("fontSans") || "sans-serif"

        // Tu lógica de locale está bien, solo asegúrate de que el ID sea único (corregido a 'locale')

        color: Colors.md3.on_surface
        font.pixelSize: 14


        // Corrección: Usar el objeto clock.date correctamente en ambas partes
        text: clock.date.toLocaleDateString(Services.I18nService.locale, "ddd") + " " + clock.date.toLocaleTimeString(Services.I18nService.locale, "hh:mm")
    }
}
