import QtQuick
import QtQuick.Shapes

// Fondo del modo "notch". La barra se apoya en el borde de la pantalla
// (arriba o abajo) y se une a los laterales con esquinas cóncavas; el
// lado que mira al centro de la pantalla se redondea hacia dentro:
//
//   ──────────────────────────────────────   ← borde de pantalla
//    ╲                                    ╱
//     ╰──────────────────────────────────╯
//
// El borde de pantalla ocupa todo el ancho y el cuerpo se retira
// `cornerRadius` a cada lado; las esquinas de ese cuerpo llevan
// `bodyRadius` para que el notch no acabe en un corte recto. Ninguna
// otra parte de la shell dibuja esta forma: la ventana sigue siendo de
// ancho completo y transparente fuera del trazado.
Shape {
    id: root

    property color fillColor: "transparent"
    // Radio de las esquinas cóncavas (las que caen contra el borde de
    // la pantalla).
    property int cornerRadius: 16
    // Radio de las esquinas convexas del cuerpo (el lado interior).
    property int bodyRadius: 12
    property bool atTop: true

    // Se dibuja siempre con la muesca arriba y se refleja cuando la
    // barra está abajo.
    transform: Scale {
        origin.y: root.height / 2
        yScale: root.atTop ? 1 : -1
    }

    // Mismo motivo que en ScreenCorner: el renderer por defecto con capa
    // es estable ante recargas y da bordes suavizados.
    layer.enabled: true

    // Radios acotados a la geometría: nunca se solapan ni se salen del
    // item (una ventana de 0px de ancho en el primer frame, por ejemplo).
    readonly property real outerRadius: Math.max(0, Math.min(root.cornerRadius, Math.min(root.width / 2,
                                                                                         root.height)))
    readonly property real innerRadius: Math.max(0, Math.min(root.bodyRadius, root.height - root.outerRadius))

    ShapePath {
        fillColor: root.fillColor
        strokeColor: "transparent"
        strokeWidth: -1

        startX: 0
        startY: 0

        // Borde de pantalla: ancho completo.
        PathLine {
            x: root.width
            y: 0
        }

        // Esquina superior derecha (cóncava): (W, 0) → (W - r, r).
        PathArc {
            x: root.width - root.outerRadius
            y: root.outerRadius
            radiusX: root.outerRadius
            radiusY: root.outerRadius
            useLargeArc: false
            direction: PathArc.Counterclockwise
        }

        PathLine {
            x: root.width - root.outerRadius
            y: root.height - root.innerRadius
        }

        // Esquina inferior derecha (convexa).
        PathArc {
            x: root.width - root.outerRadius - root.innerRadius
            y: root.height
            radiusX: root.innerRadius
            radiusY: root.innerRadius
            useLargeArc: false
            direction: PathArc.Clockwise
        }

        PathLine {
            x: root.outerRadius + root.innerRadius
            y: root.height
        }

        // Esquina inferior izquierda (convexa).
        PathArc {
            x: root.outerRadius
            y: root.height - root.innerRadius
            radiusX: root.innerRadius
            radiusY: root.innerRadius
            useLargeArc: false
            direction: PathArc.Clockwise
        }

        PathLine {
            x: root.outerRadius
            y: root.outerRadius
        }

        // Esquina superior izquierda (cóncava): (r, r) → (0, 0).
        PathArc {
            x: 0
            y: 0
            radiusX: root.outerRadius
            radiusY: root.outerRadius
            useLargeArc: false
            direction: PathArc.Counterclockwise
        }
    }
}
