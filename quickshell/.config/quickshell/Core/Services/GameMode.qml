pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.UPower

Singleton {
    id: root

    // 1. Guarda el estado de forma persistente tras recargar Quickshell
    PersistentProperties {
        id: settings

        reloadableId: "GameModeSettings"

        property bool enabled: false
    }

    property string previousBarLayout: ""

    readonly property alias enabled: settings.enabled

    // 2. Atajo global nativo registrado en Hyprland
    GlobalShortcut {
        name: "toggle_gamemode"
        description: "Alternar Modo Juego"
        onPressed: root.toggle()
    }

    property Process proc: Process {}

    // Función pública para cambiar de estado
    function toggle() {
        setGameMode(!settings.enabled);
    }
    Connections {
        target: ConfigService.configs.bar

        function onBarTypeChanged() {
            if (root.enabled) {
                root.previousBarLayout = ConfigService.configs.bar;
            }
        }
    }

    function setGameMode(active) {
        settings.enabled = active;

        if (active) {
            // --- ACTIVAR MODO JUEGO ---
            root.previousBarLayout = ConfigService.configs.bar.barType;

            // Enviar keywords directamente por el socket IPC nativo de Hyprland:
            let luaConfig = "hl.config({ " + "animations = { enabled = false }, " + "decoration = { rounding = 2, blur = { enabled = false }, shadow = { enabled = false } }, " + "general = { gaps_in = 0, gaps_out = 0, border_size = 1 } " + "})";

            // Enviar la estructura Lua mediante 'hyprctl eval'
            proc.command = ["hyprctl", "eval", luaConfig];
            proc.running = true;
            ConfigService.configs.bar.barType = "no_floating";
            console.log("[GameMode] Modo Juego ACTIVADO: Efectos desactivados y perfil de Alto Rendimiento.");
        } else {
            // --- DESACTIVAR MODO JUEGO ---

            // 'reload' vuelve a aplicar tu hyprland.conf predeterminado al instante
            proc.command = ["hyprctl", "reload"];
            proc.running = true;
            ConfigService.configs.bar.barType = root.previousBarLayout;

            console.log("[GameMode] Modo Juego DESACTIVADO: Configuración habitual restaurada.");
        }
    }
}
