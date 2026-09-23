import qs.Panels.Notifications
import qs.Shared.Background
import qs.Primitives
import QtQuick

// Popup de notificaciones anclado al item de la barra.
// Mismo patrón que BatteryPopupWindow / WeatherPopup.
BarPopupWindow {
    id: root

    implicitWidth: popupContent.implicitWidth + 32
    implicitHeight: popupContent.implicitHeight + 32

    PopupBackground {
        anchors.fill: parent
    }

    NotificationPopupContent {
        id: popupContent

        anchors.centerIn: parent
    }
}
