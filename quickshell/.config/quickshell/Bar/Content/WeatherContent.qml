import qs.Primitives
import qs.Core.Services
import qs.Core
import QtQuick
import QtQuick.Layouts

MaterialIcon {
    id: weatherIcon
    size: Appearance.font.pixelSize.larger
    color: Appearance.md3.on_surface
    icon: WeatherService.icon
    fill: 0
}
