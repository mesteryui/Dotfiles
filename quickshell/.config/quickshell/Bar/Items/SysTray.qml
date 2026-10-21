import qs.Primitives
import qs.Core
import qs.Bar.SystemTray
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray

RowLayout {
    id: root

    // implicitWidth/Height ahora se calculan solos a partir de los hijos,
    // así que el RowLayout padre en MainBar.qml reserva el espacio real.
    spacing: Appearance.spacing.extraSmall
    Layout.alignment: Qt.AlignVCenter

    // Sin iconos en la bandeja no hay nada que desplegar: se oculta el
    // widget entero (la flecha incluida) y el RowLayout padre no reserva
    // espacio, igual que UpdateCounter sin actualizaciones.
    readonly property int trayCount: {
        const v = SystemTray.items ? SystemTray.items.values : null;
        return v ? v.length : 0;
    }
    visible: root.trayCount > 0

    // Si se retiran los iconos con el revealer abierto, se vuelve a cerrar
    // para no reaparecer desplegado cuando vuelvan a registrarse.
    onVisibleChanged: {
        if (!root.visible)
            revealer.reveal = false;
    }

    MaterialIcon {
        id: chevron
        Layout.alignment: Qt.AlignVCenter

        size: 20
        icon: "chevron_backward"
        rotation: revealer.reveal ? 180 : 0

        Behavior on rotation {
            NumberAnimation {
                duration: Appearance.motion.normal
                easing.type: Easing.OutQuad
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: revealer.reveal = !revealer.reveal
        }
    }

    Revealer {
        id: revealer

        reveal: false
        vertical: false
        Layout.alignment: Qt.AlignVCenter

        SysTray {
            id: sysTray
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
