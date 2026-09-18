// --- Dinámico unificado: animations (CustomMenu) ---
// Lista ~/.config/hypr/configs/animations/*.lua y detecta la actual con
// grep require(. La aplicación es sed + hyprctl reload + notify.
// Antes vivía en SystemMenuService; ahora es un provider como los demás.

import qs.Core.Services as Services
import qs.Launcher
import QtQuick
import Quickshell
import Quickshell.Io
import "../../ShellUtils.js" as ShellUtils

CustomMenu {
    id: root

    sectionId: "animations"
    titleFallback: "Animaciones Hyprland"
    titleKey: "sysmenu.sec_animations"
    iconName: "animation"
    parentId: "appearance"

    entries: []

    readonly property string configHome: {
        const xdg = Quickshell.env("XDG_CONFIG_HOME");
        return (xdg && xdg !== "") ? xdg : Quickshell.env("HOME") + "/.config";
    }
    readonly property string langWatch: Services.I18nService.language

    onLangWatchChanged: refresh()
    Component.onCompleted: refresh()

    function tr(key, fallback) {
        return Services.I18nService.getTranslation(key || "", fallback || "");
    }

    // Escape común (ver Launcher/ShellUtils.js, única implementación).

    function pretty(name) {
        let n = name.replace(/\.[^.]+$/, "").replace(/-/g, " ");
        n = n.charAt(0).toUpperCase() + n.slice(1);
        const idx = n.slice(1).search(/[A-Z]/);
        if (idx >= 0)
            n = n.slice(0, idx + 1) + " " + n.slice(idx + 1);
        return n;
    }

    function shellFor(value) {
        const v = ShellUtils.shellEscape(value);
        const cfg = ShellUtils.shellEscape(root.configHome);
        return "sed -i 's|\\(require(\".*\\.\\)[^\".]*|\\1" + v + "|' '" + cfg + "/hypr/configs/animations/../animation.lua' && "
            + "hyprctl reload && notify-send 'Hyprland Animations' 'Animacion cambiada a " + v + "'";
    }

    function refresh() {
        if (animProc.running)
            return;
        const cfg = ShellUtils.shellEscape(root.configHome);
        animProc.command = ["sh", "-c",
            "f='" + cfg + "/hypr/configs/animations/../animation.lua'; "
            + "cur=$(grep 'require(' \"$f\" 2>/dev/null | sed 's/.*\\.//;s/\").*//' | tr -d '[:space:]'); "
            + "echo \"CURRENT\t$cur\"; "
            + "find '" + cfg + "/hypr/configs/animations' -maxdepth 1 -type f -printf '%f\\n' 2>/dev/null | sort"];
        animProc.running = true;
    }

    property var _found: []
    property string _current: ""

    // Trabajadores en `helpers` (la raíz es QtObject y no admite
    // hijos declarativos). Acumulan en _found/_current y al terminar
    // reasignan `entries` entero.
    helpers: [ Process {
        id: animProc

        stdout: SplitParser {
            onRead: data => {
                const line = data.trim();
                if (line === "")
                    return;
                if (line.startsWith("CURRENT\t")) {
                    root._current = line.slice(8).trim();
                    return;
                }
                const name = line.replace(/\.[^.]+$/, "");
                if (name !== "")
                    root._found.push(name);
            }
        }
        onRunningChanged: {
            if (running) {
                root._found = [];
                root._current = "";
            }
        }
        onExited: {
            const out = [];
            const subBase = root.tr("sysmenu.dyn_anims", "Animación de Hyprland");
            const badgeCur = root.tr("sysmenu.badge_current", "Actual");
            for (let i = 0; i < root._found.length; i++) {
                const name = root._found[i];
                const isCur = name === root._current;
                // Sin subtitleKey (ver FastfetchMenu): el badge vive en el texto.
                const sub = (isCur ? "● " + badgeCur + " · " : "") + subBase;
                out.push(root.shell("anim-" + name, root.pretty(name), sub, "animation", root.shellFor(name), {}));
            }
            root.entries = out;
        }
    } ]
}
