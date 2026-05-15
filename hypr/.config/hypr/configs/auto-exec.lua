-- configs/auto-exec.lua
hl.on("hyprland.start", function()
    local uwsm_prefix = "uwsm app -- "
    hl.exec_cmd(uwsm_prefix.."udiskie &")
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
    hl.exec_cmd("emacs --fg-daemon")
    hl.exec_cmd("snappy-switcher --daemon")
end)

hl.on("monitor.added", function ()
    hl.exec_cmd("awww img"..Colors.image)
    hl.exec_cmd("launch_waybar")
end)

