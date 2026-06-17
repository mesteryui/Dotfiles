import QtQuick
import Quickshell
import "../../Core"
import "../../Features/Subwindows"
import "../../Core/Services" as Services
import "."

BarItem {
    id: root
    clickable: true
    onClicked: popup.visible = !popup.visible
    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }
    CalendarPopupWindow {
        id: popup
        anchor.item: root
        anchor.margins.top: 20
        anchor.margins.bottom: 20
        anchor.edges: (Services.ConfigService.getConfig("bar.position") == "bottom" ? Edges.Top : Edges.Bottom) | Edges.Right
        anchor.gravity: (Services.ConfigService.getConfig("bar.position") == "bottom" ? Edges.Top : Edges.Bottom) | Edges.Left
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
