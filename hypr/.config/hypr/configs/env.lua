-- configs/env.lua

local function obtain_cursor()
    local home = os.getenv("HOME")
    local path = home .. "/.config/gtk-3.0/settings.ini"
    local f = io.open(path, "r")
    local cursor_theme = "Adwaita"

    if not f then return cursor_theme end

    for line in f:lines() do
        local name = line:match("gtk%-cursor%-theme%-name%s*=%s*(.*)")
        if name then
            cursor_theme = name:gsub('^["\']', ''):gsub('["\']$', ''):gsub('%s*$', '')
            break
        end
    end
    f:close()
    return cursor_theme
end

local function obtain_cursor_size()
    local home = os.getenv("HOME")
    local path = home .. "/.config/gtk-3.0/settings.ini"
    local f = io.open(path, "r")
    local cursor_size = "24"

    if not f then return cursor_size end

    for line in f:lines() do
        local size = line:match("gtk%-cursor%-theme%-size%s*=%s*(.*)")
        if size then
            cursor_size = size:gsub('^["\']', ''):gsub('["\']$', ''):gsub('%s*$', '')
            break
        end
    end
    f:close()
    return cursor_size
end

local cursor_theme = obtain_cursor()
local cursor_size = obtain_cursor_size()
hl.env("LIBINPUT_DEFAULT_POINTER_ACCEL",0)
hl.env("WLR_NO_HARDWARE_CURSORS",1)
hl.env("HYPRCURSOR_THEME", cursor_theme)
hl.env("HYPRCURSOR_SIZE", cursor_size)
hl.env("EDITOR","nvim")
hl.env("XCURSOR_THEME", cursor_theme)

hl.env("XCURSOR_SIZE", cursor_size)
--hl.env("QT_QUICK_CONTROLS_STYLE", "Fusion")
hl.env("QT_SCALE_FACTOR", "1")   -- ajustar según tu monitor scale
--hl.env("GDK_BACKEND", "wayland,x11,*")
--hl.env("QT_QPA_PLATFORM","wayland;xcb")
hl.env("GDK_SCALE",2)
hl.env("MOZ_ENABLE_WAYLAND",1)
hl.env("OZONE_PLATFORM","wayland")
hl.env("XDG_SESSION_TYPE","wayland")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
--hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("GSK_RENDERER", "gl")
hl.env("QT_QPA_PLATFORMTHEME", "qtengine")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
--hl.env("QT_SCALE_FACTOR",2)
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")

hl.env("GDK_BACKEND", "wayland,x11")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("SDL_VIDEODRIVER", "wayland,x11,windows")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

hl.env("_JAVA_AWT_WM_NONREPARENTING", "1")
