import org.kde.kirigami as Kirigami
import qs.Core
import QtQuick
import Quickshell

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
    // animated: false: los iconos de barra/panel son estáticos. Con
    // animated: true Kirigami mantiene maquinaria de animación SVG en cada
    // instancia (decodado + temporizador de frames) incluso sin frames que
    // animar. Con false se decodifica una vez y se reusa el caché.
    animated: false

    Component.onCompleted: {
        if (icon === "") {
            console.warn("[FluentIcon] Required property 'icon' is empty");
        }
    }
}
