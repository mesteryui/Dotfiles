// ControlSlider — Material 3 Expressive Slider primitive.
import qs.Core
import QtQuick
import QtQuick.Layouts
import M3Shapes

RowLayout {
    id: root

    property string label: ""
    property string iconName: ""
    property real value: 0.0          // 0.0 – 1.0
    property color accentColor: Appearance.md3.primary
    property bool showValue: true
    property string valueText: Math.round(root.displayValue() * 100) + "%"
    property real stepSize: 0.05
    property string accessibleName: root.label !== "" ? root.label : root.iconName
    // Eco local opt-in para roundtrips lentos (ej. brillo: spawn + sysfs).
    // Con liveEcho el thumb/% siguen el dedo durante el arrastre y la verdad
    // (propiedad `value` del padre) manda al soltar o en reposo. Apagado por
    // defecto: comportamiento idéntico al de siempre.
    property bool liveEcho: false
    property real dragValue: 0.0
    readonly property alias dragging: trackArea.pressed

    // Valor mostrado: dedo mientras se arrastra con eco, verdad en reposo.
    function displayValue() {
        return (root.liveEcho && root.dragging) ? root.dragValue : root.value;
    }
    // Patrón focus-visible: el anillo de foco solo se muestra cuando el
    // foco viene del teclado. El panel dueño lo pone a false con el ratón
    // (vía mouseUsed) y a true con cualquier tecla (Keys.onPressed en la
    // instancia). Por defecto true para no cambiar paneles existentes.
    property bool keyboardMode: true

    signal moved(real val)
    signal iconClicked
    signal mouseUsed

    function adjust(delta) {
        const v = Math.max(0.0, Math.min(1.0, root.displayValue() + delta));
        if (root.liveEcho)
            root.dragValue = v;
        root.moved(v);
    }

    spacing: Appearance.spacing.m
    activeFocusOnTab: true

    // ── Teclado ────────────────────────────────────────────────
    // Izq/Der: ±step · Inicio/Fin: 0%/100% · RePág/AvPág: ±10%
    // +/-: ±step · M: acción del icono (mute).
    // Arriba/Abajo se reservan para navegar entre controles (KeyNavigation).
    Keys.onLeftPressed: root.adjust(-root.stepSize)
    Keys.onRightPressed: root.adjust(root.stepSize)
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Home) {
            root.moved(0.0);
            event.accepted = true;
        } else if (event.key === Qt.Key_End) {
            root.moved(1.0);
            event.accepted = true;
        } else if (event.key === Qt.Key_PageUp) {
            root.adjust(0.10);
            event.accepted = true;
        } else if (event.key === Qt.Key_PageDown) {
            root.adjust(-0.10);
            event.accepted = true;
        } else if (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal) {
            root.adjust(root.stepSize);
            event.accepted = true;
        } else if (event.key === Qt.Key_Minus || event.key === Qt.Key_Underscore) {
            root.adjust(-root.stepSize);
            event.accepted = true;
        } else if (event.key === Qt.Key_M) {
            root.iconClicked();
            event.accepted = true;
        }
    }

    Accessible.role: Accessible.Slider
    Accessible.name: root.accessibleName
    Accessible.description: root.valueText

    // Icono Material con feedback interactivo opcional
    MaterialIcon {
        id: iconItem

        visible: root.iconName !== ""
        icon: root.iconName
        size: Appearance.font.pixelSize.large
        color: (root.activeFocus && root.keyboardMode) ? Appearance.md3.primary : (iconArea.containsMouse ? Appearance.md3.primary : Appearance.md3.on_surface_variant)

        Behavior on color {
            ColorAnimation {
                duration: Appearance.motion.short3
            }
        }

        MouseArea {
            id: iconArea

            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: {
                root.forceActiveFocus();
                root.mouseUsed();
            }
            onPressed: {
                root.forceActiveFocus();
                root.mouseUsed();
            }
            onClicked: root.iconClicked()
        }
    }

    // Pista y Control del Slider estilo M3 Expressive
    Item {
        id: sliderTrackContainer
        Layout.fillWidth: true
        Layout.preferredHeight: 24

        // Pista base (spec M3 sliders: track 16dp, esquinas 50%,
        // active primary / inactive surface-container-highest).
        Rectangle {
            id: trackBg

            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 16
            radius: height / 2
            color: Appearance.md3.surface_container_highest
            border.width: (root.activeFocus && root.keyboardMode) ? 2 : 0
            border.color: (root.activeFocus && root.keyboardMode) ? Appearance.md3.primary : "transparent"

            // Pista activa (Fill)
            Rectangle {
                width: Math.max(height, trackBg.width * Math.max(0, Math.min(1, root.displayValue())))
                height: parent.height
                radius: parent.radius
                color: root.accentColor

                Behavior on width {
                    NumberAnimation {
                        duration: 80
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.motion.short3
                    }
                }
            }

            // Stop indicator M3 (4dp al final del track).
            Rectangle {
                width: 4
                height: 4
                radius: width / 2
                color: root.accentColor
                anchors.verticalCenter: parent.verticalCenter
                x: trackBg.width - width
            }
        }

        // Thumb / Manejador M3 Expressive con morph MANUAL atado al valor:
        // 0% = Circle, 100% = Cookie4Sided. Al arrastrar ves la forma
        // transformarse con el nivel (además de crecer con hover/press).
        // Región cuadrada obligatoria para que el morph no colapse.
        MaterialShape {
            id: thumb

            x: Math.max(0, Math.min(sliderTrackContainer.width - width, sliderTrackContainer.width * Math.max(0, Math.min(1, root.displayValue())) - width / 2))
            anchors.verticalCenter: parent.verticalCenter
            width: trackArea.pressed ? 22 : (trackArea.containsMouse || (root.activeFocus && root.keyboardMode) ? 20 : 16)
            height: width
            fromShape: MaterialShape.Circle
            toShape: MaterialShape.Cookie4Sided
            morphProgress: Math.max(0, Math.min(1, root.displayValue()))
            animationDuration: 200
            color: root.accentColor
            strokeColor: (root.activeFocus && root.keyboardMode) ? Appearance.md3.primary : Appearance.md3.surface_container_low
            strokeWidth: 2

            Behavior on x {
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
            Behavior on color {
                ColorAnimation {
                    duration: Appearance.motion.short3
                }
            }
        }

        // Etiqueta de valor M3 (value indicator): burbuja sobre el thumb
        // solo mientras se arrastra.
        Rectangle {
            id: valueBubble

            visible: trackArea.pressed
            width: bubbleLabel.implicitWidth + 20
            height: 26
            radius: Appearance.shape.full
            color: Appearance.md3.primary_container
            x: Math.max(0, Math.min(sliderTrackContainer.width - width, thumb.x + thumb.width / 2 - width / 2))
            y: -30

            StyledText {
                id: bubbleLabel

                anchors.centerIn: parent
                text: root.valueText
                font.pixelSize: Appearance.typeScale.labelSmall
                font.family: Appearance.font.mono
                color: Appearance.md3.on_primary_container
            }
        }

        MouseArea {
            id: trackArea

            function updateValue(mouseX) {
                const newVal = Math.max(0.0, Math.min(1.0, mouseX / width));
                if (root.liveEcho)
                    root.dragValue = newVal;
                root.moved(newVal);
            }

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: {
                root.forceActiveFocus();
                root.mouseUsed();
            }
            onPressed: mouse => {
                root.forceActiveFocus();
                root.mouseUsed();
                // El eco parte de la verdad al apoyar el dedo.
                if (root.liveEcho)
                    root.dragValue = root.value;
            }
            onPositionChanged: mouse => {
                if (pressed)
                    updateValue(mouse.x);
            }
            onClicked: mouse => {
                root.forceActiveFocus();
                updateValue(mouse.x);
            }
        }
    }

    // Texto de porcentaje / valor
    StyledText {
        visible: root.showValue
        text: root.valueText
        font.pixelSize: Appearance.typeScale.labelMedium
        font.family: Appearance.font.sans
        color: Appearance.md3.on_surface_variant
        horizontalAlignment: Text.AlignRight
        Layout.preferredWidth: 36
    }
}
