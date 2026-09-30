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
import qs.Core.Services as Services
import qs.Core
import qs.Primitives
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import M3Shapes

Item {
    id: root

    property string artURL: ""

    // ── API con el Wrapper ────────────────────────────────────
    required property real currentPosition

    signal seekRequested(real newPosition)

    // El Wrapper lo consulta en sus Timers y Connections
    readonly property bool sliderDragging: seekBar.dragging

    readonly property var player: Services.MprisService.activePlayer

    readonly property bool hasPlayer: root.player !== null

    readonly property bool multiPlayer: Services.MprisService.players.length > 1

    readonly property bool hasArt: root.artURL !== ""

    implicitWidth: 360
    implicitHeight: mainColumn.implicitHeight + 32

    // ── Helpers ───────────────────────────────────────────────
    // (El formateo mm:ss del slider vive en Primitives/MprisSeekBar.)
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
            margins: Appearance.spacing.l
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
            spacing: Appearance.spacing.m
            Layout.alignment: Qt.AlignCenter

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 64
                Layout.preferredHeight: 64
                radius: Appearance.shape.full
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
                    text: Services.I18nService.getTranslation("media.empty", "Nada reproduciendo")
                    font.pixelSize: Appearance.typeScale.bodyLarge
                    font.weight: Font.DemiBold
                    font.family: Appearance.font.sans
                    color: Appearance.md3.on_surface
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Inicia la reproducción en cualquier aplicación"
                    font.pixelSize: Appearance.typeScale.labelMedium
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

                // Sombra tonal para dar profundidad Material You (sigue la silueta).
                // source se asigna en onCompleted para evitar warning
                // "ShaderEffect: 'source' does not have a matching property"
                MultiEffect {
                    id: artShadow
                    anchors.fill: artShapeBg
                    shadowEnabled: true
                    shadowColor: Appearance.md3.shadow
                    shadowOpacity: Appearance.elevation3.opacity
                    shadowBlur: Appearance.elevation3.blur
                    shadowVerticalOffset: Appearance.elevation3.offsetY
                    z: -1
                    Component.onCompleted: artShadow.source = artShapeBg
                }

                // Fuente de la máscara: misma silueta que artShapeBg, no se pinta directamente.
                // Declarada ANTES de artImage para que maskSource nunca apunte
                // a un item sin textura en el primer frame (warning
                // "ShaderEffect: 'source' does not have a matching property").
                // layer.enabled es obligatorio aquí: sin él, un item con visible:false
                // no genera textura y la máscara queda en blanco (imagen invisible).
                MaterialShape {
                    id: artMaskShape

                    anchors.fill: parent
                    shape: artContainer.artShape
                    color: "white"
                    animationDuration: 500
                    visible: false
                    layer.enabled: true
                }

                // Imagen recortada a la silueta expresiva vía máscara
                Image {
                    id: artImage

                    anchors.fill: parent
                    source: root.artURL
                    fillMode: Image.PreserveAspectCrop
                    // La URL cambia por pista (caché por URL, sin
                    // staleness) y se decodifica acotada a la caja 76px.
                    cache: true
                    asynchronous: true
                    sourceSize.width: 152
                    sourceSize.height: 152
                    visible: root.hasArt && status === Image.Ready
                    opacity: visible ? 1.0 : 0.0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.motion.short4
                        }
                    }

                    // No necesita MouseArea/hover → layer.enabled aquí es seguro
                    layer.enabled: true

                    // maskSource se asigna en onCompleted (mismo patrón que las
                    // sombras): evita el warning del primer frame.
                    layer.effect: MultiEffect {
                        id: artMaskEffect
                        maskEnabled: true
                        Component.onCompleted: artMaskEffect.maskSource = artMaskShape
                    }
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
                    text: root.player?.trackTitle ?? Services.I18nService.getTranslation("media.empty", "Nada reproduciendo")
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
                    font.pixelSize: Appearance.typeScale.bodyMedium
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
                    font.pixelSize: Appearance.typeScale.labelSmall
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
            spacing: Appearance.spacing.xs
            visible: root.hasPlayer

            // Seekbar unificado (Primitives/MprisSeekBar): mismo gesto y
            // estados que la tarjeta del lockscreen.
            MprisSeekBar {
                id: seekBar

                Layout.fillWidth: true
                position: root.currentPosition
                length: root.player?.length ?? 0
                canSeek: (root.player?.canSeek || root.player?.canControl) ?? false
                onSeekRequested: newPosition => root.seekRequested(newPosition)
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

                // Spec M3 FAB medium: 56dp.
                implicitWidth: 56
                implicitHeight: 56

                Accessible.role: Accessible.Button
                Accessible.name: playPauseHero.playing ? Services.I18nService.getTranslation("media.pause", "Pausar") : Services.I18nService.getTranslation("media.play", "Reproducir")

                readonly property bool playing: Services.MprisService.isPlaying

                readonly property int heroShape: playing ? MaterialShape.Cookie7Sided : MaterialShape.Circle

                MaterialShape {
                    id: heroBg

                    anchors.fill: parent
                    shape: playPauseHero.heroShape
                    color: heroMouse.enabled ? Appearance.md3.primary : Appearance.md3.surface_container_highest
                    animationDuration: 450
                }

                // Sombra: source se asigna en onCompleted para evitar warning
                // "ShaderEffect: 'source' does not have a matching property"
                MultiEffect {
                    id: heroShadow
                    anchors.fill: heroBg
                    shadowEnabled: true
                    shadowColor: Appearance.md3.shadow
                    shadowOpacity: Appearance.elevation3.opacity
                    shadowBlur: Appearance.elevation3.blur
                    shadowVerticalOffset: Appearance.elevation3.offsetY
                    z: -1
                    Component.onCompleted: heroShadow.source = heroBg
                }

                // Capa de estado (hover/press) — misma silueta que el fondo
                MaterialShape {
                    id: heroStateLayer

                    anchors.fill: parent
                    shape: playPauseHero.heroShape
                    color: Appearance.md3.on_primary
                    animationDuration: 450
                    opacity: heroMouse.pressed ? Appearance.state.pressed : (heroMouse.containsMouse ? Appearance.state.hovered : 0)

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.motion.short2
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

                    spacing: Appearance.spacing.s

                    Repeater {
                        model: Services.MprisService.players

                        delegate: Item {
                            id: chipItem

                            required property var modelData
                            property MprisPlayer playerObj: modelData

                            readonly property bool isActive: Services.MprisService.activePlayer === playerObj

                            Accessible.role: Accessible.RadioButton
                            Accessible.checked: chipItem.isActive
                            Accessible.name: chipItem.playerObj.identity ?? chipItem.playerObj.dbusName

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
                                        duration: Appearance.motion.short3
                                    }
                                }

                                M3StateLayer {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    tint: chipItem.isActive ? Appearance.md3.on_secondary_container : Appearance.md3.on_surface
                                    hovered: chipMouse.containsMouse
                                    pressed: chipMouse.pressed
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
                                        font.pixelSize: Appearance.typeScale.labelMedium
                                        font.weight: chipItem.isActive ? Font.Medium : Font.Normal
                                        color: chipItem.isActive ? Appearance.md3.on_secondary_container : Appearance.md3.on_surface_variant

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: Appearance.motion.short3
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
