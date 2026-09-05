pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

/**
 * CheatsheetKeybinds
 * ------------------
 * Reads `hyprctl binds -j` and turns it into cheatsheet-ready data:
 *
 *   - keybinds          : raw array as returned by hyprctl
 *   - keybindCategories : ordered list of category names (derived from the
 *                          "Category: actual description" convention)
 *   - groupedKeybinds    : { categoryName: [ { mods, keyLabel, label, searchText }, ... ] }
 *
 * Only binds with `has_description: true` are surfaced — undocumented binds
 * (window rules, internal submap plumbing, etc.) are intentionally skipped,
 * matching hyprctl's own `has_description` flag rather than guessing from
 * an empty string.
 *
 * Re-parses automatically whenever Hyprland reloads its config.
 */
Singleton {
    id: root

    property var keybinds: []
    property var keybindCategories: []
    property var groupedKeybinds: ({})

    // Hyprland's internal MODS bitmask (independent of X11's numbering).
    // Ordered so the decoded label list reads naturally: Super Ctrl Alt Shift.
    readonly property var modBits: [
        { bit: 64,  label: "Super" },
        { bit: 4,   label: "Ctrl" },
        { bit: 8,   label: "Alt" },
        { bit: 1,   label: "Shift" },
        { bit: 2,   label: "Caps" },
        { bit: 16,  label: "Mod2" },
        { bit: 32,  label: "Mod3" },
        { bit: 128, label: "Mod5" }
    ]

    readonly property var specialKeyNames: ({
        "RETURN": "Enter",
        "KP_ENTER": "Enter",
        "ESCAPE": "Esc",
        "GRAVE": "`",
        "MINUS": "-",
        "EQUAL": "=",
        "BACKSPACE": "⌫",
        "TAB": "Tab",
        "SPACE": "Space",
        "LEFT": "←",
        "RIGHT": "→",
        "UP": "↑",
        "DOWN": "↓",
        "PRINT": "PrtSc",
        "DELETE": "Del",
        "PAGE_UP": "PgUp",
        "PAGE_DOWN": "PgDn",
        "HOME": "Home",
        "END": "End",
        "SUPER_L": "Super",
        "SUPER_R": "Super",
        "XF86AudioRaiseVolume": "Vol +",
        "XF86AudioLowerVolume": "Vol -",
        "XF86AudioMute": "Mute",
        "XF86AudioMicMute": "Mic Mute",
        "XF86AudioPlay": "Play",
        "XF86AudioNext": "Next",
        "XF86AudioPrev": "Prev",
        "XF86MonBrightnessUp": "Bright +",
        "XF86MonBrightnessDown": "Bright -"
    })

    function prettyModName(raw) {
        switch (raw) {
        case "SUPER": return "Super";
        case "SHIFT": return "Shift";
        case "CTRL":
        case "CONTROL": return "Ctrl";
        case "ALT": return "Alt";
        case "CAPS": return "Caps";
        default:
            return raw.length > 0
                ? raw.charAt(0) + raw.slice(1).toLowerCase()
                : raw;
        }
    }

    // Prefers the `modkeys` string (newer Hyprland, human-readable) and
    // falls back to decoding the bitmask (always present).
    function decodeMods(modmask, modkeys) {
        if (modkeys && modkeys.length > 0) {
            return modkeys.split(" ").filter(s => s.length > 0).map(prettyModName);
        }
        var out = [];
        for (var i = 0; i < root.modBits.length; i++) {
            var m = root.modBits[i];
            if ((modmask & m.bit) === m.bit)
                out.push(m.label);
        }
        return out;
    }

    function formatKeyLabel(bind) {
        if (bind.mouse) {
            var btn = bind.key && bind.key.length > 0 ? bind.key : bind.arg;
            return "Mouse " + (btn || "");
        }
        var key = bind.key || "";
        if (key.length === 0 && bind.keycode)
            return "Key " + bind.keycode;
        if (root.specialKeyNames[key])
            return root.specialKeyNames[key];
        if (key.length === 1)
            return key.toUpperCase();
        // XF86-style / long names: keep as-is if mixed case already looks intentional
        if (/^XF86/.test(key))
            return key.replace(/^XF86/, "");
        return key.charAt(0).toUpperCase() + key.slice(1).toLowerCase();
    }

    function rebuildGroups() {
        var cats = {};
        var order = [];

        for (var i = 0; i < root.keybinds.length; i++) {
            var b = root.keybinds[i];
            if (!b.has_description || !b.description || b.description.length === 0)
                continue;

            var sepIdx = b.description.indexOf(":");
            var category = sepIdx > 0 ? b.description.substring(0, sepIdx).trim() : "General";
            var label = sepIdx > 0 ? b.description.substring(sepIdx + 1).trim() : b.description.trim();
            if (label.length === 0)
                label = b.description.trim();

            if (!cats[category]) {
                cats[category] = [];
                order.push(category);
            }

            var mods = root.decodeMods(b.modmask, b.modkeys);
            var keyLabel = root.formatKeyLabel(b);

            cats[category].push({
                mods: mods,
                keyLabel: keyLabel,
                label: label,
                repeat: !!b.repeat,
                searchText: (category + " " + label + " " + mods.join(" ") + " " + keyLabel).toLowerCase()
            });
        }

        root.keybindCategories = order;
        root.groupedKeybinds = cats;
    }

    function refresh() {
        getKeybinds.running = true;
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "configreloaded")
                root.refresh();
        }
    }

    Process {
        id: getKeybinds

        running: true
        command: ["hyprctl", "binds", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.keybinds = JSON.parse(text);
                    root.rebuildGroups();
                } catch (e) {
                    console.error("[CheatsheetKeybinds] Error parsing keybinds:", e);
                }
            }
        }
    }
}
