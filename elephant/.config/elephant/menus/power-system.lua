Name = "power-menu"
Icon = "⏻"
NamePretty = "Power Menu"
HideFromProviderList = true
Cache = False
FixedOrder = true
Description = "Menu de apagado y encendido"
function HandleSystemOp(op)
    os.execute("systemctl "..op)
end
function HandleLogOut()
    local uwsmIs = os.execute("which " .. "uwsm" .. " > /dev/null 2>&1")
    if uwsmIs then
	os.execute("uwsm stop")
    end
end
function GetEntries()
    return {
	{
	    Text = "Apagar",
	    Icon = "⏻",
	    Value = "poweroff",
	    Actions = { poweroff = "lua:HandleSystemOp" },
	},
	{
	    Text = "Reiniciar",
	    Icon = "",
	    Value = "reboot",
	    Actions = { reboot = "lua:HandleSystemOp"},
	},
	{
	    Text = "Suspender",
	    Icon = "󰤄",
	    Value = "suspend",
	    Actions = { suspend = "lua:HandleSystemOp"},
	},
	{
	    Text = "Bloquear",
	    Icon = "",
	    Actions = { lock = "hyprlock" }
	},
	{
	    Text = "Cerrar sesion",
	    Icon = "󰍃",
	    Actions = { logout = "lua:HandleLogOut"}
	},
    }
end
