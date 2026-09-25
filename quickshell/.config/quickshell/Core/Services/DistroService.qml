// --- DistroService (Singleton) ---
// Detecta la distro una sola vez desde /etc/os-release y expone el
// icono de assets/ correspondiente.
//
// Al ser singleton el parseo ocurre una vez: la barra (una instancia
// por monitor) y cualquier otro componente solo hacen binding a
// `icon` sin coste adicional.
//
// Para cambiar el icono de una distro basta con sustituir el SVG en
// assets/ manteniendo el nombre que devuelve `iconFor()`.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ID de /etc/os-release en minúsculas ("shinro", "cachyos", "arch"...).
    property string distroId: ""
    // Nombre bonito ("Shinro Linux").
    property string distroName: ""
    // Tokens de ID_LIKE en minúsculas (p. ej. ["arch"]).
    property var distroLike: []
    property bool ready: false

    // Nombre del icono en assets/ (sin ".svg"), listo para FluentIcon.
    readonly property string icon: root.iconFor(root.distroId) ?? root._likeIcon() ?? "distro-linux"

    // Tabla ID (normalizado) -> asset. Añade aquí tu distro con su SVG.
    function iconFor(id) {
        switch ((id ?? "").toLowerCase()) {
        case "shinro":
            return "distro-shinro";
        case "cachyos":
        case "cachyos-linux":
            return "cachyos-symbolic";
        case "arch":
        case "archarm":
        case "archlinux":
            return "distro-arch";
        case "endeavouros":
        case "endeavour":
            return "distro-endeavouros";
        case "fedora":
        case "fedora-linux":
            return "distro-fedora";
        case "debian":
            return "distro-debian";
        case "ubuntu":
            return "distro-ubuntu";
        case "linuxmint":
        case "mint":
            return "distro-linuxmint";
        case "pop":
        case "popos":
        case "pop_os":
            return "distro-popos";
        case "manjaro":
        case "manjaro-arm":
            return "distro-manjaro";
        case "opensuse":
        case "opensuse-tumbleweed":
        case "opensuse-leap":
        case "opensuse-slowroll":
        case "suse":
            return "distro-opensuse";
        case "nixos":
            return "distro-nixos";
        default:
            return null;
        }
    }

    // Fallback: primer token de ID_LIKE con icono conocido.
    function _likeIcon() {
        for (let i = 0; i < root.distroLike.length; i++) {
            const hit = root.iconFor(root.distroLike[i]);
            if (hit !== null)
                return hit;
        }
        return null;
    }

    FileView {
        path: "/etc/os-release"
        blockLoading: true
        watchChanges: true
        onLoaded: {
            const out = {};
            const lines = this.text().split("\n");
            for (let i = 0; i < lines.length; i++) {
                const m = lines[i].match(/^([A-Z_]+)=(.*)$/);
                if (m)
                    out[m[1]] = m[2].trim().replace(/^"(.*)"$/, "$1").replace(/^'(.*)'$/, "$1");
            }
            root.distroId = (out["ID"] ?? "").toLowerCase();
            root.distroName = out["PRETTY_NAME"] ?? out["NAME"] ?? "";
            root.distroLike = (out["ID_LIKE"] ?? "").toLowerCase().split(/\s+/).filter(s => s !== "");
            root.ready = true;
        }
        onLoadFailed: {
            // Sin /etc/os-release: el binding de `icon` ya cae a distro-linux.
            root.ready = true;
        }
    }
}
