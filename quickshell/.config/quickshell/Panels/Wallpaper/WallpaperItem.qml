pragma ComponentBehavior: Bound

import qs.Panels.Wallpaper.Content
import qs.Core
import qs.Shared.Background
import QtQuick

Item {
    id: delegateRoot

    required property int index
    // Rol del FolderListModel: el ListView lo inyecta solo (como `index`).
    required property string filePath

    signal clicked

    property int surfaceRadius: Appearance.shape.windowRounding

    readonly property bool isSelected: ListView.isCurrentItem
    // Distancia al elemento seleccionado (0 = centro, 1 = vecino inmediato…)
    readonly property int distance: Math.abs(ListView.view.currentIndex - index)
    // Lado respecto al centro: -1 izquierda, 0 centro, 1 derecha
    readonly property real side: index < ListView.view.currentIndex ? -1 :
                                index > ListView.view.currentIndex ? 1 : 0

    implicitWidth: 300
    implicitHeight: 220

    // ── Transformación Coverflow ─────────────────────────────────────────
    // Escala y transparencia según selección; los no seleccionados se
    // ven un poco más pequeños y oscuros para que el centro resalte.
    scale: isSelected ? 1.08 : 0.86
    opacity: isSelected ? 1.0 : 0.60
    z: isSelected ? 10 : (100 - distance)

    // Desplazamiento parallax lateral: cuanto más lejos del centro, más se
    // desplaza. Al navegar se mueve con spring para un efecto de "cola"
    // más chulo y orgánico que un simple deslizamiento lineal.
    property real parallaxX: side * distance * 44

    transform: [
        Translate { x: parallaxX; y: 0 }
    ]

    Behavior on scale {
        SpringAnimation {
            spring: Appearance.motion.springSoft.spring
            damping: Appearance.motion.springSoft.damping
            mass: Appearance.motion.springSoft.mass
            epsilon: Appearance.motion.springSoft.epsilon
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: Appearance.motion.relaxed
            easing.type: Easing.OutCubic
        }
    }
    Behavior on parallaxX {
        SpringAnimation {
            spring: Appearance.motion.springSnappy.spring
            damping: Appearance.motion.springSnappy.damping
            mass: Appearance.motion.springSnappy.mass
            epsilon: Appearance.motion.springSnappy.epsilon
        }
    }

    // ── Fondo y Sombra Elevada ───────────────────────────────────────────
    SurfaceBackground {
        id: background

        anchors.fill: parent
        radius: delegateRoot.surfaceRadius
        color: delegateRoot.isSelected ? Appearance.md3.surface_container_highest :
                                         Appearance.md3.surface_container_low
    }

    // ── Contenido de la Tarjeta ──────────────────────────────────────────
    WallpaperItemContent {
        anchors.fill: parent
        isSelected: delegateRoot.isSelected
        hovered: mouse.containsMouse
        radius: delegateRoot.surfaceRadius
        filePath: delegateRoot.filePath
        // Ventana de cercanía para pedir frames de vídeo solo cerca del
        // viewport (ver WallpaperItemContent.isNear).
        delegateIndex: delegateRoot.index
        listCurrentIndex: ListView.view ? ListView.view.currentIndex : -1
    }

    // ── Captura de Interacción ──────────────────────────────────────────
    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: delegateRoot.clicked()
    }
}
