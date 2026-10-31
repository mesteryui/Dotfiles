import qs.Bar
import qs.Core
import qs.Core.Services as Services
import qs.Shared.Background
import QtQuick
import Quickshell
import Quickshell.Wayland

Variants {
    model: Quickshell.screens
    delegate: Scope {
        id: delegateScope

        required property ShellScreen modelData
        // qmllint disable uncreatable-type

        PanelWindow {
            id: root
            // qmllint enable uncreatable-type

            screen: delegateScope.modelData

            // Fallbacks mientras ConfigService.ready==false (primeros
            // frames): sin esto height es 0/undefined y la barra nace
            // invisible hasta que carga config.json.
            readonly property var barType: Services.GameMode.enabled ? "no_floating" : (
                                                                           Services.ConfigService.ready ? (
                                                                                                              Services.ConfigService.configs.bar.barType
                                                                                                              || "floating") :
                                                                                                          "floating")

            // Contrato de 5 modos (compartido con Bar/ScreenRounding.qml):
            // "floating" = píldora flotante (márgenes + radio).
            // "notch" = barra con esquinas cóncavas propias en el borde de pantalla
            // (sin ScreenRounding).
            // "full_hug"/"partial_hug"/"no_floating" = barra adherida; el redondeo de
            // pantalla lo dibuja ScreenRounding.
            readonly property bool isFloating: barType === "floating"

            readonly property bool isFullHug: barType === "full_hug"

            readonly property bool isPartial: barType === "partial_hug"

            readonly property bool isNotch: barType === "notch"

            readonly property bool isTop: !Services.ConfigService.ready ? true : (
                                                                              Services.ConfigService.configs.bar.position
                                                                              == "top"
                                                                              || Services.ConfigService.configs.bar.position
                                                                              == "")

            property int barHeight: !Services.ConfigService.ready ? 36 : (
                                                                        Services.ConfigService.configs.bar.height
                                                                        || 36)

            // Radio de la esquina cóncava del notch (la que baja desde el
            // borde de la pantalla hasta el lateral de la barra). Se limita
            // para que nunca ocupe más de la altura de la barra. El guardia
            // de `Appearance.shape` evita NaN/undefined en el primer frame,
            // antes de que exista el singleton.
            readonly property int notchOuterRadius: {
                const height = root.barHeight || 36
                const fallback = Appearance.shape ? Appearance.shape.screenRounding : 16
                return Math.max(0, Math.min(fallback, Math.floor(height * 0.6)))
            }

            // Radio de las esquinas interiores del notch (las del cuerpo, en
            // el lado que mira al centro de la pantalla). Se acota a lo que
            // queda libre bajo la esquina cóncava para que ambos arcos no se
            // solapen en barras muy bajas.
            readonly property int notchInnerRadius: {
                const height = root.barHeight || 36
                const fallback = Appearance.shape ? Appearance.shape.medium : 12
                return Math.max(0, Math.min(fallback, height - root.notchOuterRadius))
            }

            // Margen exterior en modo flotante / laterales del contenido.
            readonly property int floatingMargin: 2

            // En notch el contenido se retira lo suficiente para no invadir
            // las esquinas (nada sobresale de la silueta del notch).
            readonly property int contentMargin: root.isNotch ? root.notchOuterRadius + 4 : 5

            WlrLayershell.layer: WlrLayer.Top
            // La zona exclusiva sigue siendo SOLO el alto de la barra (no molesta a otras apps)
            WlrLayershell.exclusiveZone: barHeight
            exclusionMode: ExclusionMode.Normal
            WlrLayershell.namespace: "quickshell:bar"

            anchors {
                top: root.isTop
                bottom: !root.isTop
                right: true
                left: true
            }
            margins {
                top: root.isFloating ? root.floatingMargin : 0
                bottom: root.isFloating ? root.floatingMargin : 0
                left: root.isFloating ? root.floatingMargin : 0
                right: root.isFloating ? root.floatingMargin : 0
            }

            // Sin implicitWidth: la ventana ya ocupa todo el ancho por los
            // anchors left/right (antes `content.width` cerraba un binding loop
            // con MainBar, anclado a su vez al padre).
            implicitHeight: barHeight

            color: "transparent"

            // En notch el fondo se recorta con la misma forma que la máscara
            // de clics, para que las esquinas transparentes no capturen input.
            mask: root.isNotch ? notchMask : null

            // 1. Fondo de la Barra
            SurfaceBackground {
                id: bg

                visible: !root.isNotch
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: root.isTop ? parent.top : undefined
                anchors.bottom: !root.isTop ? parent.bottom : undefined
                height: root.barHeight
                color: Appearance.md3.surface
                radius: root.isFloating ? Appearance.shape.full : 0
                // Hairline solo en la píldora flotante; en los modos hug la
                // barra es parte del marco de pantalla y no lleva trazo.
                bordered: root.isFloating
            }

            // Fondo propio del notch: esquinas cóncavas en el borde de la
            // pantalla, cuerpo retirado y esquinas interiores redondeadas
            // para que el contenido no las pise.
            NotchBackground {
                visible: root.isNotch
                anchors.fill: parent
                fillColor: Appearance.md3.surface
                cornerRadius: root.notchOuterRadius
                bodyRadius: root.notchInnerRadius
                atTop: root.isTop
            }

            // Máscara de clics con la misma silueta que el fondo: banda a
            // ancho completo en el borde de pantalla, cuerpo retirado y las
            // dos cuñas cóncavas restadas para que dejen pasar los clics.
            // Los hijos de un Region usan coordenadas absolutas (las mismas
            // de la ventana), no relativas a este item; por eso se mide con
            // `root.width`/`root.height` (geometría real de la ventana) y no
            // con `barHeight`, que es solo el alto configurado.
            Region {
                id: notchMask

                x: 0
                y: root.isTop ? 0 : root.height - root.notchOuterRadius
                width: root.width
                height: root.notchOuterRadius

                Region {
                    x: -root.notchOuterRadius
                    y: root.isTop ? 0 : root.height - 2 * root.notchOuterRadius
                    width: 2 * root.notchOuterRadius
                    height: 2 * root.notchOuterRadius
                    shape: RegionShape.Ellipse
                    intersection: Intersection.Subtract
                }

                Region {
                    x: root.width - root.notchOuterRadius
                    y: root.isTop ? 0 : root.height - 2 * root.notchOuterRadius
                    width: 2 * root.notchOuterRadius
                    height: 2 * root.notchOuterRadius
                    shape: RegionShape.Ellipse
                    intersection: Intersection.Subtract
                }

                // Cuerpo. Sus esquinas del lado de pantalla quedan rectas
                // (ahí empalma con la banda) y las interiores se redondean
                // igual que el fondo.
                Region {
                    x: root.notchOuterRadius
                    y: root.isTop ? root.notchOuterRadius : 0
                    width: Math.max(0, root.width - 2 * root.notchOuterRadius)
                    height: Math.max(0, root.height - root.notchOuterRadius)
                    topLeftRadius: root.isTop ? 0 : root.notchInnerRadius
                    topRightRadius: root.isTop ? 0 : root.notchInnerRadius
                    bottomLeftRadius: root.isTop ? root.notchInnerRadius : 0
                    bottomRightRadius: root.isTop ? root.notchInnerRadius : 0
                }
            }

            // 3. Contenido de la barra
            MainBar {
                id: content

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: root.contentMargin
                anchors.rightMargin: root.contentMargin
                anchors.top: root.isTop ? parent.top : undefined
                anchors.bottom: !root.isTop ? parent.bottom : undefined
                height: root.barHeight
            }
        }
    }
}
