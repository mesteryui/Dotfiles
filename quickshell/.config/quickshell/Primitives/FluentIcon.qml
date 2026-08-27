import QtQuick
import org.kde.kirigami as Kirigami
import Quickshell
import qs.Core

Kirigami.Icon {
    id: root
    required property string icon
    property bool filled: false
    property alias monochrome: root.isMask

    property int implicitSize: 20
    implicitWidth: implicitSize
    implicitHeight: implicitSize

    source: icon === "" ? "" : `${Quickshell.shellPath("assets")}/${root.icon}${filled ? "-filled" : ""}.svg`
    fallback: root.icon
    roundToIconSize: false
    color: Appearance.md3.on_surface
    isMask: true
    animated: true
}
