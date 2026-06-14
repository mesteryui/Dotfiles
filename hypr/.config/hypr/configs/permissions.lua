-- configs/permissions.lua
-- Configuración de Permisos (Formato Tabla Completa)
-- Permisos de aplicaciones y plugins
hl.permission({ binary = "/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", type = "screencopy", mode = "allow" })
hl.permission({ binary = ".*hyprexpo\\.so$", type = "plugin", mode = "allow" })
hl.permission({ binary = ".*dynamic-cursors\\.so$", type = "plugin", mode = "allow" })
hl.permission({ binary = ".*hyprlock.*$", type = "screencopy", mode = "allow" })
hl.permission({ binary = "/usr/bin/hyprpicker", type = "screencopy", mode = "allow" })
hl.permission({ binary = ".*quickshell.*$", type = "screencopy", mode = "allow" })
hl.permission({ binary = "/usr/bin/hyprland-preview-share-picker", type = "screencopy", mode = "allow" })
hl.permission({ binary = ".*hyprbars\\.so$", type = "plugin", mode = "allow" })
hl.permission({ binary = "/usr/bin/grim", type = "plugin", mode = "allow"})

-- Dispositivos de Entrada / Teclado
hl.permission({ binary = "asus_numpad", type = "keyboard", mode = "allow" })
hl.permission({ binary = "asus-wmi-hotkeys", type = "keyboard", mode = "allow" })
hl.permission({ binary = "power-button", type = "keyboard", mode = "allow" })
hl.permission({ binary = "video-bus", type = "keyboard", mode = "allow" })
hl.permission({ binary = "at-translated-set-2-keyboard", type = "keyboard", mode = "allow" })

-- Teclado interno de ASUS (el identificador largo)
hl.permission({ binary = "asue140d:00-04f3:31b9-keyboard", type = "keyboard", mode = "allow" })
-- Regla Global (Seguridad)
hl.permission({ binary = ".*", type = "keyboard", mode = "ask" })
