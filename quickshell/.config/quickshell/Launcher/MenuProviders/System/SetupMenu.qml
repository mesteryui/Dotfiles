// --- Builtin: setup (unified menu system) ---

import QtQuick

QtObject {
    property string sectionId: "setup"
    property string titleFallback: "Setup"
    property string titleKey: "sysmenu.sec_setup"
    property string iconName: "construction"
    property string parentId: "main"

    property var entries: [
        { entryId: "setup-docker", titleFallback: "Setup Docker", titleKey: "sysmenu.setup-docker_t", subtitleFallback: "docker-setup.sh", subtitleKey: "sysmenu.setup-docker_s", iconName: "deployed_code",
          action: { kind: "shell", shellCommand: "kitty --class=float_kitty -e docker-setup.sh" } },
        { entryId: "setup-python", titleFallback: "Setup Python", titleKey: "sysmenu.setup-python_t", subtitleFallback: "python-setup.sh", subtitleKey: "sysmenu.setup-python_s", iconName: "code",
          action: { kind: "shell", shellCommand: "kitty --class=float_kitty -e python-setup.sh" } }
    ]

    function refresh() {}
}
