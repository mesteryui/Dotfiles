import QtQuick
import Quickshell
import qs.Core
import qs.Features.Subwindows
import qs.Core.Services as Services

BarItem {
    id: root
    clickable: true
    onClicked: {
        const w = popupLoader.item
        if (w) w.visible = !w.visible
    }
    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }
    LazyLoader {
        id: popupLoader
        loading: true
        CalendarPopupWindow {
            id: popup
            anchor.item: root
            anchor.margins.top: 20
            anchor.adjustment: PopupAdjustment.Flip | PopupAdjustment.Slide
            anchor.margins.bottom: 20
            anchor.edges: (Services.ConfigService.getConfig("bar.position") == "bottom" ? Edges.Top : Edges.Bottom)
            anchor.gravity: (Services.ConfigService.getConfig("bar.position") == "bottom" ? Edges.Top : Edges.Bottom)
        }
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
