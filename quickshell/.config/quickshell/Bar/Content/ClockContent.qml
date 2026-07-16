import QtQuick
import Quickshell
import qs.Core
import qs.Core.Services as Services
import qs.Primitives

Item {
    id: root
    implicitWidth: clockText.implicitWidth
    implicitHeight: clockText.implicitHeight
    
    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }
    
    StyledText {
        id: clockText
       
        font.family: Services.ConfigService.configs.appearence.fontSans

        // Tu lógica de locale está bien, solo asegúrate de que el ID sea único (corregido a 'locale')

        color: Appearance.md3.on_surface
        font.pixelSize: Appearance.font.pixelSize.small


        // Corrección: Usar el objeto clock.date correctamente en ambas partes
        text: clock.date.toLocaleDateString(Services.I18nService.locale, "ddd") + " " + clock.date.toLocaleTimeString(Services.I18nService.locale, "hh:mm")
    }
}
