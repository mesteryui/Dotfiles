import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell
import Quickshell.Hyprland
import "../../Core/Services" as Services
import "../../Core"
import "../../Components"

PopupWindow {
    id: root
    visible: false
    color: "transparent"
    grabFocus: true
    implicitWidth: 300
    implicitHeight: content.implicitHeight

    HyprlandFocusGrab {
        windows: [root]
        active: root.visible
        onCleared: {
            if (root.visible)
                Qt.callLater(() => root.visible = false);
        }
    }
    property real _lastKnownPosition: 0   // posición real de MPRIS
    property real _lastTimestamp: 0       // cuando la recibimos
    property real currentPosition: 0     // posición interpolada
    property real currentLength: 0

    // Calcula la posición actual en base al tiempo transcurrido
    // desde la última actualización real de MPRIS
    function _interpolatedPosition(): real {
        if (!Services.MprisService.isPlaying)
            return _lastKnownPosition;
        const elapsed = (Date.now() - _lastTimestamp) / 1000;
        return Math.min(_lastKnownPosition + elapsed, currentLength);
    }

    // Timer local a 250ms — suave sin ser costoso
    Timer {
        interval: 250
        repeat: true
        running: root.visible && Services.MprisService.isPlaying
        onTriggered: root.currentPosition = root._interpolatedPosition()
    }

    // Actualiza las propiedades locales cuando cambia la canción
    // o cuando el timer del servicio dispara positionChanged
    Connections {
        target: Services.MprisService.currentMprisPlayer
        enabled: Services.MprisService.currentMprisPlayer !== null
    }

    // Inicializa cuando el player cambia
    onVisibleChanged: {
        if (visible) {
            root._lastKnownPosition = Services.MprisService.currentMprisPlayer?.position ?? 0;
            root._lastTimestamp = Date.now();
            root.currentPosition = root._lastKnownPosition;
            root.currentLength = Services.MprisService.currentMprisPlayer?.length ?? 0;
        }
    }

    // Wrapper exterior para el borde — así clip no lo corta
    Rectangle {
        anchors.fill: parent
        radius: 20
        color: "transparent"
        border.color: Colors.md3.outline_variant
        border.width: 1
        z: 10  // siempre encima del contenido
    }

    Rectangle {
        id: content
        anchors.fill: parent
        radius: 20
        color: Colors.md3.surface
        clip: true  // ahora clip solo afecta al contenido, no al borde
        implicitHeight: header.implicitHeight + controls.implicitHeight

        // ── Cabecera ──────────────────────────────────────────
        Item {
            id: header
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            implicitHeight: 110

            // Fondo base con color primario
            Rectangle {
                anchors.fill: parent
                radius: content.radius
                color: Qt.alpha(Colors.md3.primary_container, 0.6)
            }

            ClippingRectangle {
                color: "transparent"
                anchors.fill: parent
                radius: content.radius
                Image {
                    anchors.fill: parent
                    source: Services.MprisService.lastTrackArtUrl
                    fillMode: Image.PreserveAspectCrop
                    opacity: 0.3
                    // ✅ encima del Rectangle de color
                    z: 1
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 300
                        }
                    }
                }
            }
            // Fade inferior hacia surface
            Rectangle {

                anchors {
                    bottom: parent.bottom
                    left: parent.left
                    right: parent.right
                }
                height: 60
                z: 2
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop {
                        position: 0.0
                        color: "transparent"
                    }
                    GradientStop {
                        position: 1.0
                        color: Qt.tint(Colors.md3.surface, Qt.alpha(Colors.md3.primary, 0.08))
                    }
                }
            }

            // Título y artista
            Column {
                anchors {
                    bottom: parent.bottom
                    left: parent.left
                    right: parent.right
                    margins: 16
                    bottomMargin: 10
                }
                spacing: 3
                z: 3

                Text {
                    width: parent.width
                    text: Services.MprisService.currentMprisPlayer?.trackTitle ?? Services.I18nService.getTranslation("media.no_media")
                    font.family: Services.ConfigService.getConfig("fontSans") || "sans-serif"
                    font.pixelSize: 15
                    font.weight: Font.Bold
                    color: Colors.md3.on_surface
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: Services.MprisService.currentMprisPlayer?.trackArtist || Services.MprisService.currentMprisPlayer?.trackAlbumArtist || ""
                    font.family: Services.ConfigService.getConfig("fontSans") || "sans-serif"
                    font.pixelSize: 12
                    color: Colors.md3.on_surface_variant
                    elide: Text.ElideRight
                    visible: text !== ""
                }
            }
        }

        // ── Controles ─────────────────────────────────────────
        Column {
            id: controls
            anchors {
                top: header.bottom
                left: parent.left
                right: parent.right
            }
            topPadding: 12
            bottomPadding: 16
            leftPadding: 16
            rightPadding: 16
            spacing: 14
            // ✅ implicitHeight en lugar de height
            height: albumRow.implicitHeight + progressCol.implicitHeight + buttonsRow.implicitHeight + spacing * 2 + topPadding + bottomPadding

            // Art pequeño + tiempos
            RowLayout {
                id: albumRow
                width: parent.width - 32
                spacing: 12

                // Tiempos a la derecha del art
                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        text: formatTime(root.currentPosition ?? 0)
                        font.pixelSize: 11
                        color: Colors.md3.on_surface_variant
                        font.family: Services.ConfigService.getConfig("fontMono") || "monospace"
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Text {
                        text: formatTime(root.currentLength ?? 0)
                        font.pixelSize: 11
                        color: Colors.md3.on_surface_variant
                        font.family: Services.ConfigService.getConfig("fontMono") || "monospace"
                    }
                }
            }

            // Barra de progreso
            Rectangle {
                id: progressCol
                width: parent.width - 32
                x: 0
                height: 4
                radius: 2
                color: Colors.md3.surface_variant
                implicitHeight: 4

                Rectangle {
                    width: parent.width * Math.min(1, root.currentPosition / Math.max(1, root.currentLength))
                    height: parent.height
                    radius: parent.radius
                    color: Colors.md3.primary
                    Behavior on width {
                        NumberAnimation {
                            duration: 1000
                            easing.type: Easing.Linear
                        }
                    }
                }
            }

            // Botones de control
            RowLayout {
                id: buttonsRow
                width: parent.width - 32
                spacing: 0
                implicitHeight: 44

                Item {
                    Layout.fillWidth: true
                }

                ButtonIcon {
                    iconSize: 20
                    iconName: "skip_previous"
                    enabled: Services.MprisService.hasPlayer
                    onClicked: Services.MprisService.previousTrack()
                }

                // Play/Pause con círculo primario
                Item {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8

                    Rectangle {
                        anchors.fill: parent
                        radius: 22
                        color: Colors.md3.primary_container
                    }

                    ButtonIcon {
                        anchors.centerIn: parent
                        iconSize: 22
                        // ✅ anchors.centerIn sobre Item funciona correctamente
                        iconName: Services.MprisService.isPlaying ? "pause" : "play_arrow"
                        enabled: Services.MprisService.hasPlayer
                        onClicked: Services.MprisService.togglePlaying()
                        iconColor: Colors.md3.on_primary_container
                    }
                }

                ButtonIcon {
                    iconSize: 20
                    iconName: "skip_next"
                    enabled: Services.MprisService.hasPlayer
                    onClicked: Services.MprisService.nextTrack()
                }

                Item {
                    Layout.fillWidth: true
                }
            }
        }
    }

    function formatTime(seconds: real): string {
        const h = Math.floor(seconds / 3600);
        const m = Math.floor((seconds % 60) / 60);
        const s = Math.floor(seconds % 60);
        if (h > 0) {
            return String(h).padStart(2, "0") + ":" + String(m).padStart(2, "0") + ":" + String(s).padStart(2, "0");
        }
        return m + ":" + String(s).padStart(2, "0");
    }
}
