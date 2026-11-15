import qs.Core
import qs.Shared.Background
import qs.Primitives
import QtQuick

BarPopupWindow {
    id: root

    implicitWidth: content.implicitWidth + 20
    implicitHeight: content.implicitHeight + 10

    PopupBackground {
        id: bg

        anchors.fill: parent
        surfaceRadius: Appearance.shape.card
        baseColor: Appearance.md3.surface
        showBorder: true
    }

    // El contenido llena bg (con clip y radius), no el padre directo, y no
    // renderiza bordes propios.
    WeatherPopupContent {
        id: content

        anchors.fill: bg
    }
}
