import QtQuick
import QtQuick.Shapes

Shape {
    id: root

    property int cornerRadius: 32
    property color fillColor: "transparent"
    property bool mirrorX: false // true → esquinas del lado derecho
    property bool mirrorY: false // true → esquinas inferiores

    implicitWidth: cornerRadius
    implicitHeight: cornerRadius

    // 1. OBLIGAR A RE-CREAR LA CAPA TRAS PERDER CONTEXTO GRÁFICO
    // Usamos el renderizador predeterminado (triangulación GeometryRenderer)
    // que es 100% estable ante recargas dinámicas y reinicios de GPU.
    layer.enabled: true
    //preferredRendererType: Shape.CurveRenderer

    // 2. TRANSFORMACIÓN CON ORIGEN DINÁMICO PROTEGIDO
    transform: Scale {
        origin.x: (root.cornerRadius > 0 ? root.cornerRadius : 32) / 2
        origin.y: (root.cornerRadius > 0 ? root.cornerRadius : 32) / 2
        xScale: root.mirrorX ? -1 : 1
        yScale: root.mirrorY ? -1 : 1
    }

    ShapePath {
        id: shapePath

        fillColor: root.fillColor
        strokeColor: "transparent"
        strokeWidth: -1

        // Protección de re-evaluación al inicializar
        startX: 0
        startY: 0

        // Arista superior: (0,0) -> (radius,0)
        PathLine {
            x: root.cornerRadius
            y: 0
        }

        // 3. DIRECION DE ARCO INVARIABLE[cite: 2]
        // Se definen explícitamente los parámetros del arco para que
        // la triangulación no elija la elipse inversa al cambiar el motor.
        PathArc {
            x: 0
            y: root.cornerRadius
            radiusX: root.cornerRadius
            radiusY: root.cornerRadius
            useLargeArc: false
            direction: PathArc.Counterclockwise
        }

        // Cierra de vuelta al origen
        PathLine {
            x: 0
            y: 0
        }
    }
}
