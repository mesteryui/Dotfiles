// --- Builtin: setup (unified menu system) ---
// Usa el componente base (ver Launcher/MenuDefinition.qml).

import qs.Launcher

MenuDefinition {
    sectionId: "setup"
    titleFallback: "Setup"
    titleKey: "sysmenu.section_setup"
    iconName: "construction"
    parentId: "main"

    entries: [
        shell("setup-docker", "Setup Docker", "docker-setup.sh", "deployed_code",
            "kitty --class=float_kitty -e docker-setup.sh",
            { titleKey: "sysmenu.setup_docker_title", subtitleKey: "sysmenu.setup_docker_subtitle" }),
        shell("setup-python", "Setup Python", "python-setup.sh", "code",
            "kitty --class=float_kitty -e python-setup.sh",
            { titleKey: "sysmenu.setup_python_title", subtitleKey: "sysmenu.setup_python_subtitle" })
    ]
}
