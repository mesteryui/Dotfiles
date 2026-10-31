import qs.Primitives
import qs.Core.Services
import qs.Core
import QtQuick

Item {
    implicitWidth: contentRow.width + 2

    Row {
        id: contentRow

        spacing: Appearance.spacing.small
        anchors.centerIn: parent

        MaterialIcon {
            id: weatherIcon

            anchors.verticalCenter: parent.verticalCenter
            size: Appearance.font.pixelSize.larger
            color: Appearance.md3.on_surface
            icon: WeatherService.icon
            fill: 0
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: WeatherService.temperature
        }
    }
}
