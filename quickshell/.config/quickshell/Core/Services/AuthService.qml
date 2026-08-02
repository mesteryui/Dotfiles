pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pam

// --- AuthService ---
// Singleton que envuelve PamContext para la pantalla de bloqueo.
// Expone la API que consume LockScreenContent.qml:
//   AuthService.validate(password)
//   signal successUnlocking()
//   signal failedUnlocking()
//   signal promptMessage(message)   // prompts normales (huella, etc.), no errores

Singleton {
    id: root

    signal successUnlocking()
    signal failedUnlocking()
    signal promptMessage(message: string)

    // Guardamos la respuesta hasta que PAM realmente la pida.
    // pam.start() es asíncrono: responseRequired NO se vuelve true
    // en el mismo tick en que llamamos a start().
    property string pendingResponse: ""

    PamContext {
        id: pam

        onPamMessage: {
            // pamMessage() no trae argumentos — se leen las propiedades
            if (pam.messageIsError) {
                root.promptMessage(pam.message)
            } else if (pam.message.length > 0) {
                root.promptMessage(pam.message)
            }

            if (pam.responseRequired) {
                pam.respond(root.pendingResponse)
            }
        }

        onCompleted: result => {
            if (result === PamResult.Success) {
                root.successUnlocking()
            } else {
                root.failedUnlocking()
            }
            root.pendingResponse = ""
        }

        // Distinto de completed(PamResult.Error): fallo anormal de PAM
        // (config inexistente, módulo faltante, etc.)
        onError: pamError => {
            root.promptMessage("Error de PAM: " + pamError)
            root.failedUnlocking()
        }
    }

    function validate(password) {
        root.pendingResponse = password

        if (pam.active) {
            // Sesión ya en curso; si PAM está pidiendo respuesta ahora, mándala
            if (pam.responseRequired) {
                pam.respond(password)
            }
            return
        }

        if (!pam.start()) {
            root.failedUnlocking()
        }
        // La respuesta real se envía en onPamMessage cuando
        // responseRequired pasa a true.
    }

    // Útil para el Escape en el TextField, o para cancelar auth en curso
    function abort() {
        if (pam.active) {
            pam.abort()
        }
        root.pendingResponse = ""
    }
}
