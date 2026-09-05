import qs.Shared.Background
import qs.Primitives
import QtQuick

BarPopupWindow {
    id: root

    implicitWidth: popupContent.implicitWidth + 24
    implicitHeight: popupContent.implicitHeight + 24

    PopupBackground {
        anchors.fill: parent
    }

    BatteryPopupContent {
        id: popupContent

        anchors.centerIn: parent
    }
}
