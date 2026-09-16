// --- SystemMenuService (Singleton) ---
// Datos en vivo de las secciones dinámicas del menú de sistema.
// powerprofiles usa el servicio nativo PowerProfiles (D-Bus, reactivo).
// El resto replica elephant menus/dynamic/*.lua sin pasar por walker.
//
//   powerprofiles → PowerProfiles (nativo, ver applyPowerProfile)
//   fastfetch      → fastfetch/layouts/*         (dynamic/fastfetch-configs.lua)
//   animations     → hypr/configs/animations/*   (dynamic/animations-hypr.lua)
//
// Roles por entrada: title, sub, iconName, value, badge ("Actual" o "").
// shellFor(sección, value) devuelve el comando final (mismas operaciones
// que los .lua: symlinks, hyprctl reload, notify-send…).

pragma Singleton

import qs.Core.Services as Services
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

Singleton {
    id: root

    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string configHome: {
        const xdg = Quickshell.env("XDG_CONFIG_HOME");
        if (xdg && xdg !== "")
            return xdg;
        return root.homeDir + "/.config";
    }

    property ListModel fastfetchModel: ListModel {}
    property ListModel animModel: ListModel {}

    // Perfiles de energía vía servicio nativo PowerProfiles (power-profiles-daemon
    // por D-Bus, igual que Panels/Battery). Sin procesos ni parseo: reactivo.
    readonly property var ppMeta: [
        { value: PowerProfile.PowerSaver, icon: "battery_saver", label: "battery.powersave" },
        { value: PowerProfile.Balanced, icon: "balance", label: "battery.balanced" },
        { value: PowerProfile.Performance, icon: "bolt", label: "battery.performance" }
    ]
    readonly property int ppCurrent: PowerProfiles.profile
    // Al cambiar el idioma se reconstruye para retraducir subs/badges.
    readonly property string langWatch: Services.I18nService.language

    onLangWatchChanged: rebuildSnapshot()

    function tr(key, fallback) {
        return Services.I18nService.getTranslation(key || "", fallback || "");
    }

    onPpCurrentChanged: rebuildSnapshot()

    function applyPowerProfile(value) {
        PowerProfiles.profile = value;
    }

    function powerSnapshot() {
        const out = [];
        for (let i = 0; i < ppMeta.length; i++) {
            const m = ppMeta[i];
            if (m.value === PowerProfile.Performance && !PowerProfiles.hasPerformanceProfile)
                continue;
            const badge = PowerProfiles.profile === m.value ? tr("sysmenu.badge_current", "Actual") : "";
            out.push({
                section: "powerprofiles",
                title: Services.I18nService.getTranslation(m.label),
                sub: (badge ? "● " + badge + " · " : "") + tr("sysmenu.dyn_power", "Perfil de energía"),
                iconName: m.icon,
                value: m.value,
                badge: badge,
                preview: "",
                native: "power",
                nativeValue: m.value
            });
        }
        return out;
    }

    // Snapshot plano para bindings: los ListModel notifican por cada item
    // que llega del proceso y reevaluar `results` con cada append dispara
    // el detector de binding loops. El snapshot solo se reasigna al
    // COMPLETAR cada refresco (ver rebuildSnapshot).
    property var dynSnapshot: []

    function snapshotSection(section, model) {
        const out = [];
        for (let i = 0; i < model.count; i++) {
            const e = model.get(i);
            out.push({
                section: section,
                title: e.title,
                sub: (e.badge ? "● " + e.badge + " · " : "") + e.sub,
                iconName: e.iconName,
                value: e.value,
                preview: e.preview || ""
            });
        }
        return out;
    }

    function rebuildSnapshot() {
        dynSnapshot = powerSnapshot()
            .concat(snapshotSection("fastfetch", fastfetchModel))
            .concat(snapshotSection("animations", animModel));
    }

    property var pendingCmd: ["true"]

    function shEscape(s) {
        return String(s).replace(/'/g, "'\\''");
    }

    function pretty(name) {
        // "darkBlue" → "Dark Blue" (igual que los .lua dinámicos)
        let n = name.replace(/\.[^.]+$/, "").replace(/-/g, " ");
        n = n.charAt(0).toUpperCase() + n.slice(1);
        const idx = n.slice(1).search(/[A-Z]/);
        if (idx >= 0)
            n = n.slice(0, idx + 1) + " " + n.slice(idx + 1);
        return n;
    }

    function refreshSection(id) {
        if (id === "powerprofiles")
            rebuildSnapshot();
        else if (id === "fastfetch")
            refreshFastfetch();
        else if (id === "animations")
            refreshAnims();
    }

    function refreshAll() {
        rebuildSnapshot();
        refreshFastfetch();
        refreshAnims();
    }

    function refreshFastfetch() {
        fastfetchModel.clear();
        fastfetchProc.current = "";
        const cfg = shEscape(root.configHome);
        fastfetchProc.command = ["sh", "-c",
            "d='" + cfg + "/fastfetch/layouts'; " +
            "cur=$(readlink \"$d/../config.jsonc\" 2>/dev/null); cur=${cur##*/}; " +
            "echo \"CURRENT\t$cur\"; " +
            "for f in \"$d\"/*; do [ -f \"$f\" ] || continue; n=${f##*/}; b=${n%.*}; " +
            "p=\"$d/../previews/$b.png\"; [ -f \"$p\" ] || p=; " +
            "echo \"ENTRY\t$n\t$p\"; done | sort"];
        fastfetchProc.running = true;
    }

    function refreshAnims() {
        animModel.clear();
        animsProc.current = "";
        const cfg = shEscape(root.configHome);
        animsProc.command = ["sh", "-c",
            "f='" + cfg + "/hypr/configs/animations/../animation.lua'; " +
            "cur=$(grep 'require(' \"$f\" 2>/dev/null | sed 's/.*\\.//;s/\").*//' | tr -d '[:space:]'); " +
            "echo \"CURRENT\t$cur\"; " +
            "find '" + cfg + "/hypr/configs/animations' -maxdepth 1 -type f -printf '%f\\n' 2>/dev/null | sort"];
        animsProc.running = true;
    }

    // Comando final para aplicar un valor (mismas operaciones que los .lua).
    // NOTA: powerprofiles no pasa por aquí (applyPowerProfile nativo).
    function shellFor(section, value) {
        const v = shEscape(value);
        if (section === "fastfetch") {
            const cfg = shEscape(root.configHome);
            return "ln -sf '" + cfg + "/fastfetch/layouts/" + v + "' '" + cfg + "/fastfetch/layouts/../config.jsonc' && " +
                "notify-send 'Fastfetch Theme' 'Tema de fastfetch cambiado a: " + v + "'";
        }
        if (section === "animations") {
            const cfg = shEscape(root.configHome);
            return "sed -i 's|\\(require(\".*\\.\\)[^\".]*|\\1" + v + "|' '" + cfg + "/hypr/configs/animations/../animation.lua' && " +
                "hyprctl reload && notify-send 'Hyprland Animations' 'Animacion cambiada a " + v + "'";
        }
        return "true";
    }

    function runShell(cmd) {
        pendingCmd = ["sh", "-c", cmd];
        runProc.running = true;
    }

    Process {
        id: runProc

        command: root.pendingCmd

        onExited: (code, status) => {
            if (code !== 0)
                console.warn("SystemMenuService: falló", JSON.stringify(root.pendingCmd));
        }
    }

    // CURRENT\t<file> + ENTRY\t<file>\t<preview|vacío>
    Process {
        id: fastfetchProc

        property string current: ""

        stdout: SplitParser {
            onRead: data => {
                const line = data.trim();
                if (line === "")
                    return;
                if (line.startsWith("CURRENT\t")) {
                    fastfetchProc.current = line.slice(8).trim();
                    return;
                }
                if (!line.startsWith("ENTRY\t"))
                    return;
                const parts = line.slice(6).split("\t");
                const file = parts[0] || "";
                const prev = parts[1] || "";
                if (file === "")
                    return;
                root.fastfetchModel.append({
                    title: root.pretty(file),
                    sub: tr("sysmenu.dyn_fastfetch", "Tema de fastfetch"),
                    iconName: "terminal",
                    value: file,
                    badge: file === fastfetchProc.current ? tr("sysmenu.badge_current", "Actual") : "",
                    preview: prev
                });
            }
        }

        onExited: root.rebuildSnapshot()
    }

    // CURRENT\t<name-sin-ext> + ficheros *.lua
    Process {
        id: animsProc

        property string current: ""

        stdout: SplitParser {
            onRead: data => {
                const line = data.trim();
                if (line === "")
                    return;
                if (line.startsWith("CURRENT\t")) {
                    animsProc.current = line.slice(8).trim();
                    return;
                }
                const name = line.replace(/\.[^.]+$/, "");
                root.animModel.append({
                    title: root.pretty(name),
                    sub: tr("sysmenu.dyn_anims", "Animación de Hyprland"),
                    iconName: "animation",
                    value: name,
                    badge: name === animsProc.current ? "Actual" : ""
                });
            }
        }

        onExited: root.rebuildSnapshot()
    }
}
