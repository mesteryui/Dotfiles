import Quickshell
import qs.Shared.Background
import QtQuick
import qs.Primitives
import qs.Core

BarPopupWindow {
    id: root
    
    implicitWidth: content.implicitWidth + 20
    implicitHeight: content.implicitHeight + 10


    PopupBackground {
        anchors.fill: parent
    }
    
    WeatherPopupContent {
        id: content
        anchors.fill: parent
    }
}