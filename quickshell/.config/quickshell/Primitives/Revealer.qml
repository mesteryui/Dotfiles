import qs.Core
import QtQuick

/**
 * Recreation of GTK revealer. Expects one single child.
 */
Item {
    id: root

    property bool reveal
    property bool vertical: false
    property int animationDuration: Appearance.motion.short4 // Duración por defecto para la animación

    clip: true

    implicitWidth: (reveal || vertical) ? childrenRect.width : 0
    implicitHeight: (reveal || !vertical) ? childrenRect.height : 0
    visible: reveal || (implicitWidth > 0 && !vertical) || (implicitHeight > 0 && vertical)

    Behavior on implicitWidth {
        enabled: !root.vertical && !Appearance.motion.reduced

        SpringAnimation {
            spring: Appearance.motion.springSize.spring
            damping: Appearance.motion.springSize.damping
            mass: Appearance.motion.springSize.mass
            epsilon: Appearance.motion.springSize.epsilon
        }
    }

    Behavior on implicitHeight {
        enabled: root.vertical && !Appearance.motion.reduced

        SpringAnimation {
            spring: Appearance.motion.springSize.spring
            damping: Appearance.motion.springSize.damping
            mass: Appearance.motion.springSize.mass
            epsilon: Appearance.motion.springSize.epsilon
        }
    }
}
