// --- Builtin: setup (unified menu system) ---
// Usa el componente base (ver Launcher/CustomMenu.qml).

import qs.Launcher

CustomMenu {
    sectionId: "setup"
    titleFallback: "Setup"
    titleKey: "sysmenu.sec_setup"
    iconName: "construction"
    parentId: "main"

    entries: [
        shell("setup-docker", "Setup Docker", "docker-setup.sh", "deployed_code",
            "kitty --class=float_kitty -e docker-setup.sh",
            { titleKey: "sysmenu.setup-docker_t", subtitleKey: "sysmenu.setup-docker_s" }),
        shell("setup-python", "Setup Python", "python-setup.sh", "code",
            "kitty --class=float_kitty -e python-setup.sh",
            { titleKey: "sysmenu.setup-python_t", subtitleKey: "sysmenu.setup-python_s" })
    ]
}
