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

    // ── Estado MPRIS (posición vía polling) ────────────────────────
    property real mprisPosition: 0

    Timer {
        interval: 250
        running: MprisService.activePlayer !== null
        repeat: true
        onTriggered: {
            const p = MprisService.activePlayer;
            if (!p) return;
            try {
                root.mprisPosition = p.position;
            } catch (e) {
                // evita que los warnings de DBus se repitan continuamente en el log
                console.warn("[Mpris] lockscreen position read failed:", e);
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
    }

    // ── 2. Capa de Contenido Frontal (Content) ─────────────────────
    LockScreenContent {
        id: content
        anchors.fill: parent
        authFailed: root.authFailed
        isAuthenticating: root.isAuthenticating
        promptText: root.promptText
        isPasswordVisible: root.isPasswordVisible
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
