import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.Core
import qs.Core.Services

FocusScope {
    id: root
    anchors.fill: parent
    focus: true
    Keys.forwardTo: [content.passwordField]

    // ── Contexto de Pantalla (Multi-monitor) ──────────────────────
    property ShellScreen screen: null
    property bool isPrimary: true
    property bool isPasswordVisible: false

    // ── Estado interno ────────────────────────────────────────────
    property bool authFailed: false
    property bool isAuthenticating: false
    property string promptText: ""

    // true mientras PAM está corriendo pero todavía no pide contraseña
    // (fprintd escaneando el dedo). Se usa para el icono de huella —
    // el campo de contraseña sigue habilitado, el usuario puede escribir
    // en cualquier momento como alternativa.
    readonly property bool isFingerprintActive: AuthService.active && !AuthService.awaitingResponse && !root.isAuthenticating

    // ── Estado MPRIS (posición vía polling) ────────────────────────
    property real mprisPosition: 0

    // ── Animación de entrada / salida ("look Caelestia") ────────────
    // WlSessionLockSurface nunca se oculta, solo se destruye — así que la
    // salida se anima ANTES de que LockScreen.qml pida el desbloqueo real.
    // isUnlocking lo controla el Scope padre (uno por pantalla, mismo valor).
    property bool isUnlocking: false
    readonly property int revealDuration: 420
    readonly property int hideDuration: 260
    signal unlockAnimationFinished

    opacity: 0
    scale: 0.94
    transformOrigin: Item.Center
    // Evita que el teclado/ratón sigan activos durante el fade de salida
    enabled: !root.isUnlocking

    OpacityAnimator {
        id: revealOpacityAnim
        target: root
        from: 0
        to: 1
        duration: root.revealDuration
        easing.type: Easing.OutExpo
    }
    ScaleAnimator {
        id: revealScaleAnim
        target: root
        from: 0.94
        to: 1
        duration: root.revealDuration
        easing.type: Easing.OutExpo
    }

    OpacityAnimator {
        id: hideOpacityAnim
        target: root
        from: 1
        to: 0
        duration: root.hideDuration
        easing.type: Easing.InCubic
        onRunningChanged: {
            if (!running && root.isUnlocking)
                root.unlockAnimationFinished();
        }
    }
    ScaleAnimator {
        id: hideScaleAnim
        target: root
        from: 1
        to: 1.04
        duration: root.hideDuration
        easing.type: Easing.InCubic
    }

    Component.onCompleted: {
        revealOpacityAnim.start();
        revealScaleAnim.start();
        // Arranca la sesión PAM ya, sin esperar a que el usuario toque el
        // teclado — así el lector de huella queda escuchando desde ya.
        // WlSessionLock crea un LockScreenWrapper por monitor; start() está
        // protegido internamente (no-op si ya hay una sesión activa), así
        // que llamarlo desde cada instancia es seguro.
        AuthService.start();
    }

    onIsUnlockingChanged: {
        if (root.isUnlocking) {
            hideOpacityAnim.start();
            hideScaleAnim.start();
        }
    }

    Timer {
        interval: 250
        running: MprisService.activePlayer !== null && MprisService.isPlaying
        repeat: true
        onTriggered: {
            const p = MprisService.activePlayer;
            if (!p || !p.isPlaying)
                return;
            if (p.canSeek || p.canControl) {
                try {
                    root.mprisPosition = p.position;
                } catch (e) {
                    console.warn("[Mpris] lockscreen position read failed:", e);
                }
            }
        }
    }

    // ── Conexiones con AuthService ────────────────────────────────
    Connections {
        target: AuthService
        function onSuccessUnlocking() {
            root.isAuthenticating = false;
            root.promptText = "";
        }
        function onFailedUnlocking() {
            root.isAuthenticating = false;
            root.authFailed = true;
            content.triggerShake();
            clearTimer.restart();
            // La transacción PAM ya terminó (completed(!Success)) — hay que
            // arrancar una nueva para poder reintentar, con huella o con
            // contraseña.
            AuthService.start();
        }
        function onPromptMessage(message) {
            root.promptText = message;
            promptClearTimer.restart();
        }
    }

    // Limpia el estado de error tras 2 segundos
    Timer {
        id: clearTimer
        interval: 2000
        onTriggered: root.authFailed = false
    }

    // Limpia el prompt informativo tras 4 segundos
    Timer {
        id: promptClearTimer
        interval: 4000
        onTriggered: root.promptText = ""
    }

    // ── 1. Capa de Fondo (Background) ─────────────────────────────
    LockScreenBackground {
        id: background
        anchors.fill: parent
        z: -1
        targetScreen: root.screen
    }

    // ── 2. Capa de Contenido Frontal (Content) ─────────────────────
    LockScreenContent {
        id: content
        anchors.fill: parent
        isPrimary: root.isPrimary
        authFailed: root.authFailed
        isAuthenticating: root.isAuthenticating
        promptText: root.promptText
        isPasswordVisible: root.isPasswordVisible
        isFingerprintActive: root.isFingerprintActive
        mprisPosition: root.mprisPosition

        onValidatePassword: password => {
            if (!root.isAuthenticating) {
                root.isAuthenticating = true;
                root.authFailed = false;
                AuthService.validate(password);
                content.passwordField.text = "";
            }
        }

        onTogglePasswordVisibility: {
            root.isPasswordVisible = !root.isPasswordVisible;
        }
    }
}
