// Réplica de elephant menus/setup.toml.
// NOTA: el icono era "container" (no existe en Material Symbols y se veía
// roto) → "deployed_code" (verificado en la fuente instalada).

.pragma library

function info() {
    return { id: "setup", title: "Setup", tk: "sysmenu.sec_setup", icon: "construction", parent: "main" };
}

function entries() {
    return [
        { id: "setup-docker", title: "Setup Docker", tk: "sysmenu.setup-docker_t", sub: "docker-setup.sh", sk: "sysmenu.setup-docker_s", icon: "deployed_code",
          act: { type: "shell", cmd: "kitty --class=float_kitty -e docker-setup.sh" } },
        { id: "setup-python", title: "Setup Python", tk: "sysmenu.setup-python_t", sub: "python-setup.sh", sk: "sysmenu.setup-python_s", icon: "code",
          act: { type: "shell", cmd: "kitty --class=float_kitty -e python-setup.sh" } }
    ];
}
