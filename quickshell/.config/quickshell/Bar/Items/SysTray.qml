import qs.Primitives
import qs.Core
import qs.Bar.SystemTray
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    // implicitWidth/Height ahora se calculan solos a partir de los hijos,
    // así que el RowLayout padre en MainBar.qml reserva el espacio real.
    spacing: Appearance.spacing.xs
    Layout.alignment: Qt.AlignVCenter

    MaterialIcon {
        id: chevron
        Layout.alignment: Qt.AlignVCenter

        size: 20
        icon: "chevron_backward"
        rotation: revealer.reveal ? 180 : 0

        Behavior on rotation {
            NumberAnimation {
                duration: Appearance.motion.short4
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
