// EmptyState — estado vacío unificado M3 (icono + título + subtítulo + acción).
// Cubre los tres usos de la shell sin cambiar su aspecto:
//   plano (launcher), en M3Card (cheatsheet, la card la pone el llamador) y
//   expresivo con halo Sunny + respiración (centro de notificaciones).
import qs.Core
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import M3Shapes

ColumnLayout {
    id: root

    spacing: Appearance.spacing.m

    // Icono: o bien fuente del sistema (launcher: "search-none-symbolic")...
    property url iconSource: ""
    // ...o bien símbolo Material.

    property string iconName: ""

    property int iconSize: 48

    property color iconColor: Appearance.md3.on_surface_variant

    property real iconOpacity: 1.0

    // Halo expresivo con respiración (solo notificaciones).
    property bool expressive: false

    property string title: ""

    property int titleSize: Appearance.typeScale.titleSmall

    property color titleColor: Appearance.md3.on_surface_variant
    // Títulos con énfasis M3 (ejes variables title en vez de main).

    property bool titleEmphasis: false

    property string subtitle: ""

    property int subtitleSize: Appearance.typeScale.labelMedium

    property color subtitleColor: Appearance.md3.on_surface_variant

    property string actionText: ""

    property bool actionVisible: false

    signal actionClicked

    // --- Icono plano / fuente del sistema ---
    MaterialIcon {
        Layout.alignment: Qt.AlignHCenter
        visible: !root.expressive && root.iconSource.toString() === "" && root.iconName !== ""
        iconName: root.iconName
        size: root.iconSize
        color: root.iconColor
        opacity: root.iconOpacity
    }

    IconImage {
        Layout.alignment: Qt.AlignHCenter
        visible: !root.expressive && root.iconSource.toString() !== ""
        implicitWidth: root.iconSize
        implicitHeight: root.iconSize
        source: root.iconSource
        opacity: root.iconOpacity
    }

    // --- Icono expresivo: halo Sunny 100×100 con respiración lenta ---
    Item {
        Layout.alignment: Qt.AlignHCenter
        visible: root.expressive
        implicitWidth: 100
        implicitHeight: 100

        MaterialShape {
            id: haloShape

            anchors.fill: parent
            shape: MaterialShape.Sunny
            color: Appearance.md3.primary_container
            animationDuration: 1400
            animationEasing.type: Easing.InOutSine

            MaterialIcon {
                anchors.centerIn: parent
                iconName: root.iconName !== "" ? root.iconName : "notifications_none"
                size: 32
                color: Appearance.md3.on_primary_container
            }
        }

        Timer {
            interval: 1600
            running: root.expressive && root.visible
            repeat: true
            onTriggered: haloShape.shape = haloShape.shape === MaterialShape.Sunny ? MaterialShape.VerySunny :
                                                                                     MaterialShape.Sunny
        }
    }

    StyledText {
        Layout.alignment: Qt.AlignHCenter
        visible: root.title !== ""
        text: root.title
        font.pixelSize: root.titleSize
        font.variableAxes: root.titleEmphasis ? Appearance.font.variableAxes.title :
                                                Appearance.font.variableAxes.main
        color: root.titleColor
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
    }

    StyledText {
        Layout.alignment: Qt.AlignHCenter
        visible: root.subtitle !== ""
        text: root.subtitle
        font.pixelSize: root.subtitleSize
        color: root.subtitleColor
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
    }

    AnimatedTextButton {
        Layout.alignment: Qt.AlignHCenter
        visible: root.actionVisible
        text: root.actionText
        isFilled: true
        onClicked: root.actionClicked()
    }
}
