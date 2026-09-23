// --- Dinámico unificado: powerprofiles (MenuDefinition) ---
// Toda la lógica de energía vive AQUÍ (la base MenuDefinition no sabe nada
// de perfiles): lee PowerProfiles para marcar el actual y genera
// entradas shell() genéricas con `powerprofilesctl`.
// Si tu PC no expone el perfil de rendimiento, se oculta solo.

import qs.Core.Services as Services
import qs.Launcher
import QtQuick
import Quickshell.Services.UPower

MenuDefinition {
    id: root

    sectionId: "powerprofiles"
    titleFallback: "Perfil de energía"
    titleKey: "sysmenu.section_powerprofiles"
    iconName: "battery_charging_full"
    parentId: "configure"

    readonly property var ppMeta: [
        { ctl: "power-saver", icon: "battery_saver", label: "battery.powersave", fallback: "Ahorro" },
        { ctl: "balanced", icon: "balance", label: "battery.balanced", fallback: "Equilibrado" },
        { ctl: "performance", icon: "bolt", label: "battery.performance", fallback: "Rendimiento" }
    ]
    readonly property string ppCurrentCtl: {
        switch (PowerProfiles.profile) {
        case PowerProfile.PowerSaver:
            return "power-saver";
        case PowerProfile.Performance:
            return "performance";
        default:
            return "balanced";
        }
    }
    readonly property string langWatch: Services.I18nService.language

    onLangWatchChanged: refresh()
    onPpCurrentCtlChanged: refresh()
    Component.onCompleted: refresh()

    function tr(key, fallback) {
        return Services.I18nService.getTranslation(key || "", fallback || "");
    }

    function refresh() {
        const out = [];
        for (let i = 0; i < ppMeta.length; i++) {
            const m = ppMeta[i];
            if (m.ctl === "performance" && !PowerProfiles.hasPerformanceProfile)
                continue;
            const isCur = root.ppCurrentCtl === m.ctl;
            const badge = isCur ? tr("sysmenu.badge_current", "Actual") : "";
            // El badge va en el fallback SIN subtitleKey: el Registry prefiere
            // la clave y la traduciría pelada, perdiendo el "● Actual".
            // El idioma se mantiene vía langWatch → refresh().
            const sub = (badge !== "" ? "● " + badge + " · " : "") + tr("sysmenu.dynamic_power", "Perfil de energía");
            out.push(root.shell("pp-" + m.ctl, tr(m.label, m.fallback), sub, m.icon,
                "powerprofilesctl set " + m.ctl,
                { titleKey: m.label }));
        }
        root.entries = out;
    }
}
