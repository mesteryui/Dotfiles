// CpuArc — Donut Canvas de uso de CPU estilo Material 3 Expressive.
import QtQuick
import qs.Primitives
import qs.Core

Item {
    id: root

    property real value: 0.0    // 0.0 – 1.0
    property int  size:  52

    implicitWidth:  size
    implicitHeight: size

    onValueChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            const cx    = width  / 2
            const cy    = height / 2
            const r     = (Math.min(width, height) / 2) - 5
            const start = -Math.PI / 2
            const end   = start + (2 * Math.PI * Math.max(0, Math.min(1, root.value)))

            // Track fondo
            ctx.beginPath()
            ctx.arc(cx, cy, r, 0, 2 * Math.PI)
            ctx.strokeStyle = Appearance.md3.surface_container_highest.toString()
            ctx.lineWidth   = 6
            ctx.lineCap     = "round"
            ctx.stroke()

            // Arco activo
            if (root.value > 0) {
                ctx.beginPath()
                ctx.arc(cx, cy, r, start, end)
                ctx.strokeStyle = Appearance.md3.primary.toString()
                ctx.lineWidth   = 6
                ctx.lineCap     = "round"
                ctx.stroke()
            }
        }

        Connections {
            target: Appearance.md3
            function onPrimaryChanged()                   { canvas.requestPaint() }
            function onSurface_container_highestChanged() { canvas.requestPaint() }
        }
    }

    StyledText {
        anchors.centerIn: parent
        text: Math.round(root.value * 100) + "%"
        font.pixelSize: Appearance.font.pixelSize.smallest
        font.weight: Font.Bold
        color: Appearance.md3.primary
    }

    Behavior on value {
        NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
    }
}

