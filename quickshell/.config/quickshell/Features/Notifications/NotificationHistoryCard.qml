import qs.Core
import qs.Core.Services as Services
import qs.Primitives
import QtQuick
import QtQuick.Layouts
import M3Shapes

// Tarjeta de historial en estilo Material 3 Expressive: filled card tonal
// sin bordes duros, jerarquía app · hora / titular / cuerpo y contenedor
// de icono con forma expresiva. El elemento bajo el cursor de la lista
// se tiñe con secondary_container y anillo primary para que el foco de
// teclado sea visible.
Rectangle {
    id: root

    required property string summary
    required property string body
    required property string appName
    required property string time
    required property string icon
    required property int index
    // Id de historial para borrado via NotificationService.removeFromHistory.
    // Opcional para no romper usos existentes (NotificationCenter usa index).
    property int historyId: -1
    // Segundos Unix de llegada (para hora relativa; <=0 = usa `time`).
    property int historyEpoch: -1

    signal removeRequested

    Accessible.role: Accessible.ListItem
    Accessible.name: root.summary
    Accessible.description: root.body

    readonly property bool current: ListView.isCurrentItem ?? false

    // Reloj barato para refrescar el "hace X min".
    // (SystemClock no existe en el contexto de este módulo versionado;
    //  un Timer por minuto hace lo mismo y Qt lo comparte.)
    property int relTick: 0

    Timer {
        id: relTimer
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.relTick++
    }

    Component.onDestruction: {
        relTimer.stop()
    }

    implicitHeight: mainLayout.implicitHeight + 24
    color: "transparent"
    radius: Appearance.shape.large
    border.width: root.current ? 2 : 0
    border.color: Appearance.md3.primary

    M3SelectionFill {
        anchors.fill: parent
        radius: parent.radius
        selected: root.current
        unselectedFill: Appearance.md3.surface_container_high
    }

    // State layer de fila completa
    M3StateLayer {
        id: rowStateLayer
        anchors.fill: parent
        radius: parent.radius
        tint: root.current ? Appearance.md3.on_secondary_container : Appearance.md3.on_surface
        hovered: rowHover.hovered
    }

    HoverHandler {
        id: rowHover
    }

    RowLayout {
        id: mainLayout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Appearance.spacing.m
        anchors.rightMargin: 32
        spacing: 10

        // Contenedor expresivo para el icono de la app (región cuadrada)
        Item {
            Layout.preferredHeight: 40
            Layout.preferredWidth: 40
            Layout.alignment: Qt.AlignTop
            visible: notificationIcon.source.toString() !== ""

            MaterialShape {
                anchors.fill: parent
                shape: MaterialShape.Cookie4Sided
                color: root.current ? Appearance.md3.secondary : Appearance.md3.primary_container
                animationDuration: 0

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.motion.short3
                    }
                }
            }

            AppIcon {
                id: notificationIcon

                anchors.fill: parent
                anchors.margins: 5
                source: root.icon
            }
        }

        ColumnLayout {
            id: cardContent
            Layout.fillWidth: true

            spacing: 2

            // Fila superior: app · hora
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                visible: root.appName !== "" || root.time !== ""

                StyledText {
                    visible: root.appName !== ""
                    text: root.appName
                    color: root.current ? Appearance.md3.on_secondary_container : Appearance.md3.on_surface_variant
                    font.pixelSize: Appearance.typeScale.labelSmall
                    font.family: Appearance.font.sans
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                StyledText {
                    visible: root.time !== "" || root.historyEpoch > 0
                    // relTick invalida el binding cada minuto.
                    text: {
                        root.relTick;
                        if (root.historyEpoch > 0)
                            return Services.NotificationService.formatRelative(root.historyEpoch);
                        return root.time;
                    }
                    color: root.current ? Appearance.md3.on_secondary_container : Appearance.md3.on_surface_variant
                    font.pixelSize: Appearance.typeScale.labelSmall
                    font.family: Appearance.font.sans
                    opacity: 0.8
                }
            }

            // Titular
            StyledText {
                Layout.fillWidth: true
                text: root.summary
                color: root.current ? Appearance.md3.on_secondary_container : Appearance.md3.on_surface
                font.bold: true
                font.family: Appearance.font.sans
                font.variableAxes: Appearance.font.variableAxes.title
                font.pixelSize: Appearance.typeScale.bodyLarge
                elide: Text.ElideRight
            }
            // Cuerpo
            StyledText {
                text: root.body
                visible: text !== ""
                color: root.current ? Appearance.md3.on_secondary_container : Appearance.md3.on_surface_variant
                font.family: Appearance.font.sans
                font.pixelSize: Appearance.typeScale.bodyMedium
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }
    }

    // Botón (×) para borrar esta notificación individual.
    // Visible con hover o al ser la tarjeta actual (teclado/táctil).
    AnimatedIconButton {
        id: closeButton

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Appearance.spacing.s
        opacity: (rowHover.hovered || root.current) ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.motion.short2
            }
        }

        iconName: "close"

        iconSize: 16

        implicitWidth: 24

        implicitHeight: 24

        iconColor: root.current ? Appearance.md3.on_secondary_container : Appearance.md3.on_surface_variant

        baseColor: rowHover.hovered ? Appearance.md3.surface_container_highest : "transparent"

        onClicked: root.removeRequested()
    }
}
