-- configs/auto-exec.lua
hl.on("hyprland.start", function()
	hl.exec_cmd("udiskie &")
	hl.exec_cmd("dbus-update-activation-environment --systemd --all")
	-- Sin FONTCONFIG_FILE heredado: quickshell encadena su
	-- fonts-override.conf al valor heredado y si apunta a un run
	-- muerto/ciclado, fontconfig ve 0 fuentes (todo tofu). En
	-- arranque limpio nunca está seteado, pero se blinda igual.
	hl.exec_cmd("qs -d -n")
	hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
	--hl.exec_cmd("emacs --fg-daemon")
	hl.exec_cmd("trash-empty 30")
	--hl.exec_cmd("snappy-switcher --daemon")
	--hl.exec_cmd("walker --gapplication-service")
	hl.exec_cmd("xhost +SI:localuser:root")
	hl.exec_cmd("mpris-proxy")
	hl.exec_cmd("wl-clip-persist --clipboard both")
	hl.exec_cmd("wl-paste --type text --watch cliphist store")
	hl.exec_cmd("wl-paste --type image --watch cliphist store")
	--hl.exec_cmd("~/.local/bin/bezel")
	--hl.exec_cmd("awww-daemon &")
	--hl.exec_cmd("swayosd-server &")
	--hl.exec_cmd("hypridle &")
	--hl.exec_cmd("systemctl start --user elephant")
end)
hl.on("monitor.added", function()
	hl.exec_cmd("awww img" .. Colors.image)
end)
