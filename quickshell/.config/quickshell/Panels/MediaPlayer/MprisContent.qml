// MprisContent — Content Material 3 Expressive (Material You)
// UI completa del reproductor multimedia con tokens de diseño Material Design 3 (M3).
// Integra carátula destacada con elevación, insignias M3, seekbar de cápsula interactiva,
// controles de 5 acciones (Shuffle, Prev, Play/Pause FAB heroico, Next, Loop),
// control de volumen y selector de múltiples reproductores con chips M3.
//
// Formas expresivas (m3shapes, https://github.com/soramanew/m3shapes): la carátula,
// el FAB de Play/Pause, el thumb del seekbar y los chips de reproductor usan
// MaterialShape con morph automático entre siluetas al cambiar de estado
// (reproduciendo/pausado, presionado/activo).

pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs.Core.Services as Services
import qs.Core
import qs.Primitives
import Quickshell.Services.Mpris
import M3Shapes

Item {
    id: root

    property string artURL: ""

    // ── API con el Wrapper ────────────────────────────────────
    required property real currentPosition
    signal seekRequested(real newPosition)

    // El Wrapper lo consulta en sus Timers y Connections
    readonly property bool sliderDragging: progressArea.pressed

    readonly property var player: Services.MprisService.activePlayer
    readonly property bool hasPlayer: root.player !== null
    readonly property bool multiPlayer: Services.MprisService.players.length > 1
    readonly property bool hasArt: root.artURL !== ""

    implicitWidth: 360
    implicitHeight: mainColumn.implicitHeight + 32

    // ── Helpers ───────────────────────────────────────────────
    function formatTime(seconds: real): string {
        if (!seconds || seconds <= 0 || isNaN(seconds))
            return "0:00";
        const totalSec = Math.floor(seconds);
        const h = Math.floor(totalSec / 3600);
        const m = Math.floor((totalSec % 3600) / 60);
        const s = totalSec % 60;

        if (h > 0) {
            return String(h).padStart(2, "0") + ":" + String(m).padStart(2, "0") + ":" + String(s).padStart(2, "0");
        }
        return m + ":" + String(s).padStart(2, "0");
    }

    function toggleShuffle() {
        if (!Services.MprisService.shuffleSupported)
            return;
        Services.MprisService.setShuffle(!Services.MprisService.hasShuffle);
    }

    function cycleLoopState() {
        if (!Services.MprisService.loopSupported)
            return;
        const current = Services.MprisService.loopState;
        if (current === MprisLoopState.None) {
            Services.MprisService.setLoopState(MprisLoopState.Playlist);
        } else if (current === MprisLoopState.Playlist) {
            Services.MprisService.setLoopState(MprisLoopState.Track);
        } else {
            Services.MprisService.setLoopState(MprisLoopState.None);
        }
    }

    function volumeIcon(vol: real): string {
        if (vol <= 0.001)
            return "volume_off";
        if (vol < 0.33)
            return "volume_mute";
        if (vol < 0.66)
            return "volume_down";
        return "volume_up";
    }

    // ── Contenedor Principal ──────────────────────────────────
    ColumnLayout {
        id: mainColumn
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: 16
        }
        spacing: 14

        // ════════════════════════════════════════════════════════
        // ESTADO VACÍO (Sin reproductor)
        // ════════════════════════════════════════════════════════
        ColumnLayout {
            id: emptyState
            Layout.fillWidth: true
            Layout.preferredHeight: 160
            visible: !root.hasPlayer
            spacing: 12
            Layout.alignment: Qt.AlignCenter

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 64
                Layout.preferredHeight: 64
                radius: 32
                color: Appearance.md3.surface_container_highest

                MaterialIcon {
                    anchors.centerIn: parent
                    icon: "music_off"
                    size: 32
                    color: Appearance.md3.on_surface_variant
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Layout.alignment: Qt.AlignHCenter

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Services.I18nService.getTranslation("media.no_media", "Nada reproduciendo")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    font.family: Appearance.font.sans
                    color: Appearance.md3.on_surface
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Inicia la reproducción en cualquier aplicación"
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.family: Appearance.font.sans
                    color: Appearance.md3.on_surface_variant
                }
            }
        }

        // ════════════════════════════════════════════════════════
        // ESTADO ACTIVO: Info de Pista + Carátula
        // ════════════════════════════════════════════════════════
        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            visible: root.hasPlayer

            // ── Carátula M3 Expressive (m3shapes) ──
            // La silueta hace morph: cuadrado suave en pausa → "cookie" orgánico
            // reproduciendo, siguiendo el patrón Material You de "now playing".
            Item {
                id: artContainer
                Layout.preferredWidth: 76
                Layout.preferredHeight: 76

                readonly property int artShape: MaterialShape.Cookie12Sided

                // Sombra tonal para dar profundidad Material You (sigue la silueta)
                MultiEffect {
                    anchors.fill: artShapeBg
                    source: artShapeBg
                    shadowEnabled: true
                    shadowColor: Appearance.md3.shadow
                    shadowOpacity: 0.18
                    shadowBlur: 0.5
                    shadowVerticalOffset: 2
                }

                // Placeholder / Fondo — MaterialShape con morph automático
                MaterialShape {
                    id: artShapeBg
                    anchors.fill: parent
                    shape: artContainer.artShape
                    color: Appearance.md3.primary_container
                    animationDuration: 500

                    MaterialIcon {
                        anchors.centerIn: parent
                        icon: "music_note"
                        size: 36
                        fill: 1
                        color: Appearance.md3.on_primary_container
                        visible: !artImage.visible || artImage.status !== Image.Ready
                    }
                }

                // Imagen recortada a la silueta expresiva vía máscara
                Image {
                    id: artImage
                    anchors.fill: parent
                    source: root.artURL
                    fillMode: Image.PreserveAspectCrop
                    cache: false
                    asynchronous: true
                    visible: root.hasArt && status === Image.Ready
                    opacity: visible ? 1.0 : 0.0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 200
                        }
                    }

                    // No necesita MouseArea/hover → layer.enabled aquí es seguro
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: artMaskShape
                    }
                }

                // Fuente de la máscara: misma silueta que artShapeBg, no se pinta directamente.
                // layer.enabled es obligatorio aquí: sin él, un item con visible:false
                // no genera textura y la máscara queda en blanco (imagen invisible).
                MaterialShape {
                    id: artMaskShape
                    anchors.fill: artImage
                    shape: artContainer.artShape
                    color: "white"
                    animationDuration: 500
                    visible: false
                    layer.enabled: true
                }
            }

            // ── Metadatos de la Pista ──
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                // Badge con la fuente / aplicación
                Rectangle {
                    implicitHeight: 20
                    implicitWidth: Math.min(appBadgeContent.implicitWidth + 14, 200)
                    radius: Appearance.shape.full
                    color: Appearance.md3.surface_container_highest
                    visible: root.player != null

                    RowLayout {
                        id: appBadgeContent
                        anchors.centerIn: parent
                        spacing: 5

                        IconImage {
                            implicitWidth: 12
                            implicitHeight: 12
                            source: Quickshell.iconPath(root.player?.desktopEntry, true)
                        }

                        StyledText {
                            text: root.player?.identity ?? root.player?.dbusName ?? "Media"
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            font.family: Appearance.font.sans
                            color: Appearance.md3.on_surface_variant
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }
                }

                // Título de la pista
                StyledText {
                    Layout.fillWidth: true
                    text: root.player?.trackTitle ?? Services.I18nService.getTranslation("media.no_media", "Nada reproduciendo")
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.DemiBold
                    font.family: Appearance.font.sans
                    color: Appearance.md3.on_surface
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                // Artista
                StyledText {
                    Layout.fillWidth: true
                    text: root.player?.trackArtist || root.player?.trackAlbumArtist || ""
                    font.pixelSize: Appearance.font.pixelSize.smallie
                    font.family: Appearance.font.sans
                    color: Appearance.md3.on_surface_variant
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    visible: text !== ""
                }

                // Álbum (opcional si es distinto al título)
                StyledText {
                    Layout.fillWidth: true
                    text: root.player?.trackAlbum || ""
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.family: Appearance.font.sans
                    color: Qt.alpha(Appearance.md3.on_surface_variant, 0.75)
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    visible: text !== "" && text !== (root.player?.trackTitle ?? "") && text !== (root.player?.trackArtist ?? "")
                }
            }
        }

        // ════════════════════════════════════════════════════════
        // SLIDER DE PROGRESO M3 EXPRESSIVE
        // ════════════════════════════════════════════════════════
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            visible: root.hasPlayer

            // Pista interactiva de cápsula
            Item {
                id: progressContainer
                Layout.fillWidth: true
                implicitHeight: 20

                readonly property real totalLength: root.player?.length ?? 0
                readonly property real progressRatio: totalLength > 0 ? Math.min(1.0, Math.max(0.0, root.currentPosition / totalLength)) : 0.0

                // Pista base (Capsule track)
                Rectangle {
                    id: progressTrackBg
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: progressArea.pressed ? 10 : (progressArea.containsMouse ? 8 : 6)
                    radius: height / 2
                    color: Appearance.md3.surface_container_highest

                    Behavior on height {
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutCubic
                        }
                    }

                    // Pista activa (Fill)
                    Rectangle {
                        width: Math.max(parent.height, progressTrackBg.width * progressContainer.progressRatio)
                        height: parent.height
                        radius: parent.radius
                        color: Appearance.md3.primary

                        Behavior on width {
                            enabled: !progressArea.pressed
                            NumberAnimation {
                                duration: 80
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }
                    }
                }

                // Handle / Thumb M3 Expressive — morph a "cookie" al presionar
                MaterialShape {
                    id: progressThumb
                    x: Math.max(0, Math.min(progressContainer.width - width, progressContainer.width * progressContainer.progressRatio - width / 2))
                    anchors.verticalCenter: parent.verticalCenter
                    width: progressArea.pressed ? 8 : (progressArea.containsMouse ? 7 : 5)
                    height: progressArea.pressed ? 20 : (progressArea.containsMouse ? 16 : 12)
                    shape: progressArea.pressed ? MaterialShape.Cookie4Sided : MaterialShape.Circle
                    color: Appearance.md3.primary
                    strokeColor: Appearance.md3.surface_container_lowest
                    strokeWidth: 1.5
                    animationDuration: 250

                    Behavior on x {
                        enabled: !progressArea.pressed
                        NumberAnimation {
                            duration: 80
                        }
                    }
                    Behavior on width {
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on height {
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                MouseArea {
                    id: progressArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: (root.player?.canSeek || root.player?.canControl) ? Qt.PointingHandCursor : Qt.ArrowCursor

                    function updateSeek(mouseX: real) {
                        if (!(root.player?.canSeek || root.player?.canControl))
                            return;
                        const ratio = Math.max(0.0, Math.min(1.0, mouseX / width));
                        const targetPos = ratio * (root.player?.length ?? 0);
                        root.seekRequested(targetPos);
                    }

                    onPositionChanged: mouse => {
                        if (pressed)
                            updateSeek(mouse.x);
                    }
                    onClicked: mouse => updateSeek(mouse.x)
                }
            }

            // Tiempos
            RowLayout {
                Layout.fillWidth: true

                StyledText {
                    text: root.formatTime(root.currentPosition)
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.family: Appearance.font.mono
                    font.features: ({
                            "tnum": 1
                        })
                    color: Appearance.md3.on_surface_variant
                }

                Item {
                    Layout.fillWidth: true
                }

                StyledText {
                    text: root.formatTime(root.player?.length ?? 0)
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.family: Appearance.font.mono
                    font.features: ({
                            "tnum": 1
                        })
                    color: Appearance.md3.on_surface_variant
                }
            }
        }

        // ════════════════════════════════════════════════════════
        // CONTROLES DE REPRODUCCIÓN (5 ACCIONES MATERIAL YOU)
        // ════════════════════════════════════════════════════════
        RowLayout {
            Layout.fillWidth: true
            implicitHeight: 60
            spacing: 0
            visible: root.hasPlayer

            Item {
                Layout.fillWidth: true
            }

            // 1. Shuffle
            AnimatedIconButton {
                implicitWidth: 40
                implicitHeight: 40
                iconName: "shuffle"
                iconSize: 20
                enabled: Services.MprisService.shuffleSupported
                isActive: Services.MprisService.hasShuffle
                accentColor: Appearance.md3.tertiary_container
                activeIconColor: Appearance.md3.on_tertiary_container
                onClicked: root.toggleShuffle()
            }

            Item {
                Layout.fillWidth: true
            }

            // 2. Previous
            AnimatedIconButton {
                iconName: "skip_previous"
                enabled: root.player?.canGoPrevious ?? false
                onClicked: Services.MprisService.previous()
            }

            Item {
                Layout.fillWidth: true
            }

            // 3. Play / Pause Hero FAB — silueta m3shapes con morph al reproducir
            // Nota: se reconstruye con MaterialShape en vez de AnimatedIconButton
            // porque ese componente no expone una API de forma personalizada.
            Item {
                id: playPauseHero
                implicitWidth: 58
                implicitHeight: 58

                readonly property bool playing: Services.MprisService.isPlaying
                readonly property int heroShape: playing ? MaterialShape.Cookie7Sided : MaterialShape.Circle

                MultiEffect {
                    anchors.fill: heroBg
                    source: heroBg
                    shadowEnabled: true
                    shadowColor: Appearance.md3.shadow
                    shadowOpacity: 0.18
                    shadowBlur: 0.5
                    shadowVerticalOffset: 2
                }

                MaterialShape {
                    id: heroBg
                    anchors.fill: parent
                    shape: playPauseHero.heroShape
                    color: heroMouse.enabled ? Appearance.md3.primary : Appearance.md3.surface_container_highest
                    animationDuration: 450
                }

                // Capa de estado (hover/press) — misma silueta que el fondo
                MaterialShape {
                    id: heroStateLayer
                    anchors.fill: parent
                    shape: playPauseHero.heroShape
                    color: Appearance.md3.on_primary
                    animationDuration: 450
                    opacity: heroMouse.pressed ? 0.12 : (heroMouse.containsMouse ? 0.08 : 0)
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 100
                        }
                    }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    icon: playPauseHero.playing ? "pause" : "play_arrow"
                    size: 32
                    fill: 1
                    color: Appearance.md3.on_primary
                }

                MouseArea {
                    id: heroMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: root.player != null
                    onClicked: Services.MprisService.togglePlaying()
                }
            }

            Item {
                Layout.fillWidth: true
            }

            // 4. Next
            AnimatedIconButton {
                iconName: "skip_next"
                enabled: root.player?.canGoNext ?? false
                onClicked: Services.MprisService.next()
            }

            Item {
                Layout.fillWidth: true
            }

            // 5. Loop / Repeat
            AnimatedIconButton {
                readonly property bool isLooping: Services.MprisService.loopState !== MprisLoopState.None
                implicitWidth: 40
                implicitHeight: 40
                iconName: Services.MprisService.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
                iconSize: 20
                enabled: Services.MprisService.loopSupported
                isActive: isLooping
                accentColor: Appearance.md3.tertiary_container
                activeIconColor: Appearance.md3.on_tertiary_container
                onClicked: root.cycleLoopState()
            }

            Item {
                Layout.fillWidth: true
            }
        }

        // ════════════════════════════════════════════════════════
        // CONTROL DE VOLUMEN M3 (Si el reproductor lo soporta)
        // ════════════════════════════════════════════════════════

        // ════════════════════════════════════════════════════════
        // SELECTOR DE REPRODUCTOR (MATERIAL 3 FILTER CHIPS)
        // ════════════════════════════════════════════════════════
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10
            visible: root.multiPlayer

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Qt.alpha(Appearance.md3.outline_variant, 0.4)
            }

            Flickable {
                id: chipsFlickable
                Layout.fillWidth: true
                implicitHeight: 34
                contentWidth: chipsRow.implicitWidth
                contentHeight: 34
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.HorizontalFlick

                Row {
                    id: chipsRow
                    spacing: 8

                    Repeater {
                        model: Services.MprisService.players

                        delegate: Item {
                            id: chipItem
                            required property var modelData
                            property MprisPlayer playerObj: modelData

                            readonly property bool isActive: Services.MprisService.activePlayer === playerObj

                            implicitWidth: chipBg.implicitWidth
                            implicitHeight: 34

                            // Fondo del chip: Rectangle normal (píldora M3).
                            // MaterialShape normaliza su silueta a un cuadrado de lado
                            // min(width, height) — en un chip ancho eso deja la forma
                            // encogida en el centro y el texto sobresaliendo. Por eso
                            // el "cookie" vive en el indicador cuadrado de abajo, la
                            // única zona del chip donde la silueta se ve completa.
                            Rectangle {
                                id: chipBg
                                implicitWidth: chipContent.implicitWidth + 24
                                implicitHeight: 34
                                radius: Appearance.shape.full
                                color: chipItem.isActive ? Appearance.md3.secondary_container : Appearance.md3.surface_container_low
                                border.width: chipItem.isActive ? 0 : 1
                                border.color: Appearance.md3.outline_variant

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 150
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    color: chipItem.isActive ? Appearance.md3.on_secondary_container : Appearance.md3.on_surface
                                    opacity: chipMouse.pressed ? 0.12 : (chipMouse.containsMouse ? 0.08 : 0)
                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 100
                                        }
                                    }
                                }

                                RowLayout {
                                    id: chipContent
                                    anchors.centerIn: parent
                                    spacing: 6

                                    IconImage {
                                        implicitWidth: 16
                                        implicitHeight: 16
                                        source: Quickshell.iconPath(chipItem.playerObj.desktopEntry, true)
                                    }

                                    StyledText {
                                        text: chipItem.playerObj.identity ?? chipItem.playerObj.dbusName
                                        font.family: Appearance.font.sans
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        font.weight: chipItem.isActive ? Font.Medium : Font.Normal
                                        color: chipItem.isActive ? Appearance.md3.on_secondary_container : Appearance.md3.on_surface_variant
                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 150
                                            }
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: chipMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (Services.MprisService.activePlayer === chipItem.playerObj)
                                        Services.MprisService.setActivePlayer(null);
                                    else
                                        Services.MprisService.setActivePlayer(chipItem.playerObj);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
