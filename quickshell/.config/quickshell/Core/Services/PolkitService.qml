pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Polkit

Singleton {
    id: root

    property alias agent: polkitAgent
    property alias active: polkitAgent.isActive
    property alias flow: polkitAgent.flow
    property bool interactionAvailable: false
    // Contador de intentos fallidos: la UI lo observa para mostrar
    // feedback (shake + estado de error). Se reinicia con cada petición nueva.
    property int failedAttempts: 0
    property string cleanMessage: {
        if (!root.flow) return "";
        return root.flow.message.endsWith(".")
            ? root.flow.message.slice(0, -1)
            : root.flow.message
    }
    property string cleanPrompt: {
        const inputPrompt = root.flow?.inputPrompt.trim() ?? "";
        const cleanedInputPrompt = inputPrompt.endsWith(":") ? inputPrompt.slice(0, -1) : inputPrompt;
        const usePasswordChars = !(root.flow?.responseVisible ?? true);
        return cleanedInputPrompt || (usePasswordChars ? I18nService.getTranslation("polkit.password") : I18nService.getTranslation("polkit.input"));
    }

    function cancel() {
        // Sin petición activa no hay nada que cancelar: sin este guard,
        // un doble Esc / Enter tardío lanzaba excepción sobre flow nulo
        // y dejaba el agente inservible hasta reiniciar el shell.
        if (!root.flow)
            return;
        root.flow.cancelAuthenticationRequest();
    }

    function submit(string) {
        // Igual que cancel(): el texto puede llegar cuando el flow ya
        // terminó (reintento tardío). No se toca interactionAvailable si
        // no había flow, para no dejar la UI deshabilitada sin petición.
        if (!root.flow)
            return;
        root.flow.submit(string);
        root.interactionAvailable = false;
    }

    // Fin de petición (éxito o cancelación): no queda conteo viejo para
    // la siguiente. Durante la petición activa el contador solo crece en
    // onAuthenticationFailed, que es lo que observa la UI para el shake.
    onFlowChanged: {
        if (!root.flow) {
            root.failedAttempts = 0;
            root.interactionAvailable = false;
        }
    }

    Connections {
        target: root.flow

        function onAuthenticationFailed() {
            root.failedAttempts += 1;
            root.interactionAvailable = true;
        }
    }

    PolkitAgent {
        id: polkitAgent

        onAuthenticationRequestStarted: {
            root.failedAttempts = 0;
            root.interactionAvailable = true;
        }
    }
}