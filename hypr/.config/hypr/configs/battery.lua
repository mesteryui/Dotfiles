-- configs/battery.lua
-- Monitoreo de batería nativo en Lua para Hyprland

local last_notified_level = 100
local battery_path = "/sys/class/power_supply/BATT/"

local function get_battery_info()
    local cap_file = io.open(battery_path .. "capacity", "r")
    local stat_file = io.open(battery_path .. "status", "r")

    if not cap_file or not stat_file then return nil, nil end

    local capacity = tonumber(cap_file:read("*all"))
    local status = stat_file:read("*all"):gsub("%s+", "") -- Limpiar espacios/saltos de línea

    cap_file:close()
    stat_file:close()

    return capacity, status
end

-- Timer que se ejecuta cada 60 segundos (60000 ms)
hl.timer(function()
    local capacity, status = get_battery_info()

    if not capacity then return end

    -- Si está cargando, reseteamos el rastreador de avisos
    if status == "Charging" or status == "Full" then
        if last_notified_level < 20 then
            hl.notification.create({
                text = "Cargador conectado: " .. capacity .. "%",
                icon = "󰂄",
                timeout = 3000
            })
        end
        last_notified_level = 100
        return
    end

    -- Lógica de avisos cuando descarga
    if status == "Discharging" then
        -- Aviso Crítico (10%)
        if capacity <= 10 and last_notified_level > 10 then
            hl.notification.create({
                text = "¡BATERÍA CRÍTICA! " .. capacity .. "%",
                icon = "󰂃",
                color = "rgba(255, 0, 0, 1)", -- Rojo
                timeout = 0 -- No desaparece hasta interactuar
            })
            last_notified_level = 10

        -- Aviso Bajo (20%)
        elseif capacity <= 20 and last_notified_level > 20 then
            hl.notification.create({
                text = "Batería baja: " .. capacity .. "%",
                icon = "󰈐",
                color = "rgba(255, 255, 0, 1)", -- Amarillo
                timeout = 5000
            })
            last_notified_level = 20
        end
    end
end, { timeout = 60000, type = "repeat" })
