// --- Dinámico unificado: fastfetch (CustomMenu) ---
// Lista ~/.config/fastfetch/layouts/*, detecta el actual con readlink y
// expone previews/<nombre>.png en el panel lateral.
// Antes vivía en SystemMenuService; ahora es un provider como los demás.

import qs.Core.Services as Services
import qs.Launcher
import QtQuick
import Quickshell
import Quickshell.Io
import "../../ShellUtils.js" as ShellUtils

CustomMenu {
    id: root

    sectionId: "fastfetch"
    titleFallback: "Tema Fastfetch"
    titleKey: "sysmenu.sec_fastfetch"
    iconName: "terminal"
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
        return "ln -sf '" + cfg + "/fastfetch/layouts/" + v + "' '" + cfg + "/fastfetch/layouts/../config.jsonc' && "
            + "notify-send 'Fastfetch Theme' 'Tema de fastfetch cambiado a: " + v + "'";
    }

    function refresh() {
        if (ffProc.running)
            return;
        const cfg = ShellUtils.shellEscape(root.configHome);
        ffProc.command = ["sh", "-c",
            "d='" + cfg + "/fastfetch/layouts'; "
            + "cur=$(readlink \"$d/../config.jsonc\" 2>/dev/null); cur=${cur##*/}; "
            + "echo \"CURRENT\t$cur\"; "
            + "for f in \"$d\"/*; do [ -f \"$f\" ] || continue; n=${f##*/}; b=${n%.*}; "
            + "p=\"$d/../previews/$b.png\"; [ -f \"$p\" ] || p=; "
            + "echo \"ENTRY\t$n\t$p\"; done | sort"];
        ffProc.running = true;
    }

    property var _found: []
    property string _current: ""

    // Trabajadores en `helpers` (la raíz es QtObject y no admite
    // hijos declarativos). Acumulan en _found/_current y al terminar
    // reasignan `entries` entero.
    helpers: [ Process {
        id: ffProc

        stdout: SplitParser {
            onRead: data => {
                const line = data.trim();
                if (line === "")
                    return;
                if (line.startsWith("CURRENT\t")) {
                    root._current = line.slice(8).trim();
                    return;
                }
                if (!line.startsWith("ENTRY\t"))
                    return;
                const parts = line.slice(6).split("\t");
                const file = parts[0] || "";
                const prev = parts[1] || "";
                if (file !== "")
                    root._found.push({ file: file, preview: prev });
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
            const subBase = root.tr("sysmenu.dyn_fastfetch", "Tema de fastfetch");
            const badgeCur = root.tr("sysmenu.badge_current", "Actual");
            for (let i = 0; i < root._found.length; i++) {
                const f = root._found[i];
                const isCur = f.file === root._current;
                // Sin subtitleKey: el subtítulo lleva el badge vivo y el
                // Registry prefiere la clave (lo traduciría sin badge).
                const sub = (isCur ? "● " + badgeCur + " · " : "") + subBase;
                const opts = {};
                if (f.preview !== "")
                    opts.preview = f.preview;
                out.push(root.shell("ff-" + f.file, root.pretty(f.file), sub, "terminal", root.shellFor(f.file), opts));
            }
            root.entries = out;
        }
    } ]
}
