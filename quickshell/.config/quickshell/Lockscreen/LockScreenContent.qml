// LockScreenContent — shell: estado, gesto y composición de vistas.
// Las vistas viven en LockSleepView / LockAuthView (+ LockPowerButtons
// dentro de auth) y el gesto en LockDragArea. El contrato hacia
// LockScreenWrapper no cambia (props, alias passwordField y señales).
import qs.Core
import QtQuick

Item {
    id: root

    anchors.fill: parent

    // ── Propiedades / Entradas de Estado ─────────────────────────────
    property bool isPrimary: true

    property bool authFailed: false

    property bool isAuthenticating: false

    property string promptText: ""

    property bool isPasswordVisible: false

    property bool isFingerprintActive: false

    property real mprisPosition: 0

    // Controlado desde LockScreenWrapper
    property bool isAwake: false

    property alias passwordField: authView.passwordField

    signal validatePassword(string password)
    signal togglePasswordVisibility
    signal wakeUp
    signal sleepRequested

    function triggerShake() {
        authView.shake();
    }

    // Al volver a dormir se resetea el progreso del gesto en el mismo
    // tick del cambio (antes del siguiente frame): la animación de salida
    // va directa de visible→reposo sin saltos intermedios.
    onIsAwakeChanged: {
        if (!isAwake)
            dragArea.reset();
    }

    // Ritmo compartido dormido→auth (Material motion: misma curva y
    // duración en opacidades y deslizamientos para una transición coherente).
    readonly property int stageDuration: 350

    // ── Zona de arrastre para despertar (swipe hacia arriba) ──────────
    // z:1 por debajo de la tarjeta MPRIS y la pastilla de despertar (z:2),
    // para que los controles multimedia sean clicables sin despertar.
    // Gesto coherente: el deslizamiento sigue al dedo (dragDy) y solo
    // despierta con swipe (>70px) o clic (soltar sin apenas moverse); un
    // arrastre corto vuelve a su sitio sin cambiar de etapa.
    LockDragArea {
        id: dragArea

        isAwake: root.isAwake
        onWakeUp: root.wakeUp()
    }

    // Scrim de foco: sigue al dedo durante el arrastre y se queda en 0.22
    // despierto, para que el fondo se atenúe A LA VEZ que asoma la
    // contraseña (antes iba con retardo y el fondo parecía parpadear).
    Rectangle {
        id: authScrim

        anchors.fill: parent
        z: 0
        color: "black"
        opacity: root.isAwake ? 0.22 : Math.min(0.22, dragArea.dragDy / 130 * 0.22)

        Behavior on opacity {
            enabled: !dragArea.dragging
            NumberAnimation { duration: root.stageDuration; easing.type: Easing.OutCubic }
        }
    }

    // ── 1. VISTA DORMIDA: Reloj centrado ─────────────────────────────
    // Visible cuando !isAwake. Al despertar sube y se hace más pequeño.
    LockSleepView {
        id: sleepView

        anchors.fill: parent
        isAwake: root.isAwake
        isPrimary: root.isPrimary
        mprisPosition: root.mprisPosition
        stageDuration: root.stageDuration
        dragDy: dragArea.dragDy
        dragging: dragArea.dragging
        onWakeUp: root.wakeUp()
    }

    // ── 2. VISTA DESPIERTA: Panel de autenticación Material You ───────
    // Aparece deslizando desde abajo cuando isAwake = true, con el mismo
    // ritmo que el fundido dormido. Durante el arrastre asoma con el dedo.
    LockAuthView {
        id: authView

        anchors.fill: parent
        isAwake: root.isAwake
        isPrimary: root.isPrimary
        authFailed: root.authFailed
        isAuthenticating: root.isAuthenticating
        promptText: root.promptText
        isPasswordVisible: root.isPasswordVisible
        isFingerprintActive: root.isFingerprintActive
        mprisPosition: root.mprisPosition
        stageDuration: root.stageDuration
        dragDy: dragArea.dragDy
        dragging: dragArea.dragging
        onValidatePassword: password => root.validatePassword(password)
        onTogglePasswordVisibility: root.togglePasswordVisibility()
        onSleepRequested: root.sleepRequested()
    }
}
