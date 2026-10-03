pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pam

// --- AuthService ---
// Singleton que envuelve PamContext para la pantalla de bloqueo.
// Usa DOS configuraciones PAM distintas según lo que se está intentando:
//   - fingerprintConfig: fprintd primero, contraseña como fallback dentro
//     de la MISMA transacción (para cuando arrancamos solo a escuchar huella).
//   - passwordConfig: solo contraseña, sin fprintd (para cuando el usuario
//     ya está escribiendo y queremos que se autentique al instante, sin
//     esperar a que el lector de huella se rinda).
//
// Expone la API que consume LockScreenContent.qml:
//   AuthService.start()               // arrancar la sesión (llamar al mostrar el lock screen,
//                                      // así el lector de huella queda escuchando ya)
//   AuthService.validate(password)    // enviar la contraseña — autentica normal de inmediato
//   AuthService.abort()
//   AuthService.awaitingResponse      // true cuando PAM quiere una respuesta (ej. password)
//   AuthService.responseVisible       // true si esa respuesta debería mostrarse en claro
//   AuthService.active                // true mientras hay una sesión PAM en curso
//   signal successUnlocking()
//   signal failedUnlocking()
//   signal promptMessage(message)     // prompts normales (huella, etc.), no errores
//
// Seguridad: la contraseña solo vive en pendingResponse entre validate() y
// el primer onPamMessage con responseRequired; se consume de un solo uso y
// se limpia en completed/error/abort/start. El bloqueo por intentos
// repetidos lo hace PAM (faillock en system-auth): este servicio no duplica
// esa lógica, solo evita reenvíos y no loguea nunca la contraseña.

Singleton {
    id: root

    signal successUnlocking
    signal failedUnlocking
    signal promptMessage(message: string)

    // Servicio PAM para la escucha de huella (con fallback a contraseña
    // dentro del mismo stack). Crear /etc/pam.d/quickshell-lock:
    //   auth       sufficient   pam_fprintd.so
    //   auth       include      system-auth
    //   account    include      system-auth
    property string fingerprintConfig: "quickshell-lock"

    // Servicio PAM solo-contraseña, SIN fprintd — para cuando el usuario ya
    // escribió y pulsó Enter, y queremos autenticar al instante sin esperar
    // a que el lector de huella termine su intento. Crear
    // /etc/pam.d/quickshell-lock-password:
    //   auth       include      system-auth
    //   account    include      system-auth
    property string passwordConfig: "quickshell-lock-password"

    // Reflejan el estado de PAM para que la UI sepa qué mostrar:
    // p.ej. "Coloca tu dedo en el lector" (responseRequired=false) vs.
    // el campo de contraseña (responseRequired=true).
    readonly property bool awaitingResponse: pam.responseRequired

    readonly property bool responseVisible: pam.responseVisible
    // true mientras hay una sesión PAM en curso (escaneo de huella incluido).
    // Útil para la UI: activo + !awaitingResponse == "esperando el dedo".

    readonly property bool active: pam.active

    // Guardamos la respuesta hasta que PAM realmente la pida.
    // pam.start() es asíncrono: responseRequired NO se vuelve true
    // en el mismo tick en que llamamos a start(). Se consume de un solo
    // uso en onPamMessage y se limpia en onCompleted/abort: nunca queda
    // reutilizable para un segundo prompt de la misma transacción.
    property string pendingResponse: ""

    PamContext {
        id: pam

        // Arranca con el config de huella; validate() lo cambia a
        // passwordConfig cuando hace falta (ver más abajo). start() siempre
        // lo vuelve a poner en fingerprintConfig antes de cada intento nuevo.
        config: root.fingerprintConfig

        onPamMessage: {
            // pamMessage() no trae argumentos — se leen las propiedades.
            // Mensajes de fprintd (p.ej. "Place your finger on the reader")
            // llegan aquí igual que los de pam_unix — no hay que distinguirlos,
            // solo mostrarlos. Nunca se loguea pendingResponse.
            if (pam.messageIsError) {
                root.promptMessage(pam.message);
            } else if (pam.message.length > 0) {
                root.promptMessage(pam.message);
            }

            // Solo respondemos si PAM lo pide Y ya tenemos algo que mandar
            // (ej. el usuario ya escribió la contraseña). Si es un intento
            // de huella, responseRequired queda en false y no hacemos nada:
            // seguimos esperando el escaneo. Consumo de un solo uso: tras
            // responder se limpia para que no pueda reutilizarse en otro
            // prompt inesperado de la misma transacción.
            if (pam.responseRequired && root.pendingResponse.length > 0) {
                const once = root.pendingResponse;
                root.pendingResponse = "";
                pam.respond(once);
            }
        }

        onCompleted: result => {
            // Limpieza primero: la credencial no sobrevive a la transacción.
            root.pendingResponse = "";
            if (result === PamResult.Success) {
                root.successUnlocking();
            } else {
                // El conteo/bloqueo por reintentos lo aplica PAM (faillock);
                // aquí solo se notifica para que la UI muestre shake/reintento.
                root.failedUnlocking();
            }
        }

        // Distinto de completed(PamResult.Error): fallo anormal de PAM
        // (config inexistente, módulo faltante, etc.)
        onError: pamError => {
            root.pendingResponse = "";
            root.promptMessage("Error de PAM: " + pamError);
            root.failedUnlocking();
        }
    }

    // Arranca la sesión PAM sin enviar ninguna respuesta todavía, escuchando
    // huella (con fallback a contraseña dentro del mismo stack). Llamar esto
    // en Component.onCompleted del lock screen para que el lector empiece a
    // escuchar de inmediato, antes de que el usuario toque el teclado.
    function start() {
        if (pam.active)
            return;
        root.pendingResponse = "";
        pam.config = root.fingerprintConfig;
        if (!pam.start()) {
            root.failedUnlocking();
        }
    }

    // El usuario escribió una contraseña y pulsó Enter: autenticar normal,
    // sin esperar al lector de huella. Se ignora en vacío.
    function validate(password) {
        const pw = String(password || "");
        if (pw.length === 0)
            return;
        root.pendingResponse = pw;

        if (pam.active) {
            if (pam.responseRequired) {
                // Ya está en fase de contraseña (p.ej. fprintd ya se rindió
                // dentro de la misma transacción) — responder directo con
                // consumo de un solo uso.
                const once = root.pendingResponse;
                root.pendingResponse = "";
                pam.respond(once);
                return;
            }

            // Sigue escuchando huella (bloqueante) — no queremos que el
            // usuario espere a que fprintd se rinda. Abortamos ese intento
            // (silencioso: no dispara failedUnlocking) y re-arrancamos con
            // el stack de solo-contraseña para autenticar ya mismo.
            pam.abort();
        }

        pam.config = root.passwordConfig;
        if (!pam.start()) {
            root.pendingResponse = "";
            root.failedUnlocking();
        }
        // La respuesta real se envía en onPamMessage en cuanto
        // responseRequired pasa a true — con passwordConfig eso es
        // prácticamente inmediato, no hay fprintd de por medio.
    }

    // Útil para el Escape en el TextField, o para cancelar auth en curso
    function abort() {
        if (pam.active) {
            pam.abort();
        }
        root.pendingResponse = "";
    }
}
