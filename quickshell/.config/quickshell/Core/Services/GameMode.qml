pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root

    // 1. Guarda el estado de forma persistente tras recargar Quickshell
    PersistentProperties {
        id: settings

        reloadableId: "GameModeSettings"

        property bool enabled: false
    }

    readonly property alias enabled: settings.enabled

    // 2. Atajo global nativo registrado en Hyprland
    GlobalShortcut {
        name: "toggle_gamemode"
        description: "Alternar Modo Juego"
        onPressed: root.toggle()
    }

    // Sin Process: las órdenes viajan por el socket IPC de Hyprland
    // ($XDG_RUNTIME_DIR/hypr/$HIS/.socket.sock) vía HyprlandIpc,
    // que replica lo que `hyprctl` hace por dentro (write → read → close)
    // pero sin fork/exec. En Hyprland ≥0.53 con parser Lua `keyword`
    // ya no existe ("Use eval"), por eso se usa `eval hl.config({...})`.
    Connections {
        target: HyprlandIpc
        ignoreUnknownSignals: true

        // HyprlandIpc.replyReceived es broadcast: todos los servicios
        // comparten el socket. Solo atender comandos propios
        // ("eval ..." y "reload"); el resto (j/devices, j/binds, ...)
        // pertenece a otros consumidores.
        function isOwnCommand(command) {
            return command === "reload" || command.startsWith("eval ");
        }

        function onReplyReceived(command, reply) {
            if (!isOwnCommand(command))
                return;
            const shortCmd = command.length > 60 ? (command.substring(0, 60) + "…") : command;
            if (reply !== "ok")
                console.warn("[GameMode] Hyprland respondió:", JSON.stringify(reply), "a:", shortCmd);
        }

        function onRequestFailed(command, reason) {
            if (!isOwnCommand(command))
                return;
            console.warn("[GameMode] IPC a Hyprland falló:", reason, "cmd:", command);
        }
    }

    // Función pública para cambiar de estado
    function toggle() {
        setGameMode(!settings.enabled);
    }

    function setGameMode(active) {
        settings.enabled = active;

        if (active) {
            // --- ACTIVAR MODO JUEGO ---

            // Enviar keywords directamente por el socket IPC nativo de Hyprland:
            let luaConfig = "hl.config({ " + "animations = { enabled = false }, "
                + "decoration = { rounding = 2, blur = { enabled = false }, shadow = { enabled = false } }, "
                + "general = { gaps_in = 0, gaps_out = 0, border_size = 1, allow_tearing = true } " + "})";

            // Misma petición que `hyprctl eval '<lua>'`, pero sin proceso:
            // HyprlandIpc escribe `eval ...` al socket y Hyprland responde `ok`.
            HyprlandIpc.evalLua(luaConfig);

            console.info("[GameMode] Modo Juego ACTIVADO: Efectos desactivados.");
        } else {
            // --- DESACTIVAR MODO JUEGO ---

            // 'reload' vuelve a aplicar tu hyprland.conf predeterminado al instante
            HyprlandIpc.send("reload");

            console.info("[GameMode] Modo Juego DESACTIVADO: Configuración habitual restaurada.");
        }
    }
}
