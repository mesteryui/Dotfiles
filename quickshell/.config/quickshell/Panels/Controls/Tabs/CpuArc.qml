// CpuArc — donut canvas de uso de CPU.
// Extraído de SysInfoTab para ser reutilizable.

import QtQuick
import qs.Core
import qs.Core.Services as Services

Item {
    id: root

    property real value: 0.0    // 0–1
    property int  size:  72

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
            const r     = (Math.min(width, height) / 2) - 6
            const start = -Math.PI / 2
            const end   = start + 2 * Math.PI * root.value

            // Track
            ctx.beginPath()
            ctx.arc(cx, cy, r, 0, 2 * Math.PI)
            ctx.strokeStyle = Appearance.md3.surface_container.toString()
            ctx.lineWidth   = 8
            ctx.lineCap     = "round"
            ctx.stroke()

            // Arco activo
            if (root.value > 0) {
                ctx.beginPath()
                ctx.arc(cx, cy, r, start, end)
                ctx.strokeStyle = Appearance.md3.primary.toString()
                ctx.lineWidth   = 8
                ctx.lineCap     = "round"
                ctx.stroke()
            }
        }

        Connections {
            target: Appearance.md3
            function onPrimaryChanged()           { canvas.requestPaint() }
            function onSurface_containerChanged() { canvas.requestPaint() }
        }
    }

    Text {
        anchors.centerIn: parent
        text: Math.round(root.value * 100) + "%"
        font {
            family: Services.ConfigService.configs.appearence.fontSans
            pixelSize: 13
            weight: Font.Bold
        }
        color: Appearance.md3.primary
    }

    Behavior on value {
        NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
    }
}
