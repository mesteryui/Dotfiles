---@class helper
--- Helper functions to interact with Hyprland and manage plugins/settings.
local helper = {}

-- --- TIPOS Y ALIAS ---

---@alias NotificationLevel "info" | "warn" | "error" | "success"

-- --- UTILIDADES DE SISTEMA ---

--- Unified notification wrapper to standardize visual feedback and avoid duplication.
---@param text string The message to display.
---@param level? NotificationLevel The severity level (affects color).
---@param timeout? integer Duration in milliseconds (default 3000).
function helper.notify(text, level, timeout)
    local colors = {
        info = Colors.primary or "rgb(7dc4e4)",
        success = "rgb(40a02b)",
        warn = "rgb(df8e1d)",
        error = Colors.error or "rgb(d20f39)"
    }

    hl.notification.create({
        text = text,
        timeout = timeout or 3000,
        color = colors[level or "info"] or colors.info,
        icon = 1,
        font_size = 15
    })
end

---@class submap
helper.submap = {}

---Exit of submaps
---@param key string La tecla o combinacion de teclas para salir de un submapa
---@param options HL.BindOptions Las opciones para el atajo de salida
function helper.submap.exitSubmap(key, options)
    hl.bind(key, hl.dsp.submap("reset"), options)
end

-- --- UTILIDADES DE PLUGINS ---

--- Verifies if a plugin is available and active.
---@param name string The name of the plugin in the `hl.plugin` namespace.
---@param display_name? string Optional user-friendly name to show in the error notification.
---@param silent? boolean If true, no notification will be shown on failure (default: false).
---@return boolean True if the plugin exists, false otherwise.
function helper.check_plugin(name, display_name, silent)
    local is_loaded = hl.plugin and hl.plugin[name] ~= nil
    if not is_loaded and not silent then
        helper.notify("Error: el plugin " .. (display_name or name) .. " no está cargado", "error")
    end
    return is_loaded
end

--- Safely loads and executes a configuration function for a specific plugin.
---@param name string The name of the plugin.
---@param plugin_conf_func function A function that receives the plugin object as its first argument.
function helper.load_plugin_conf(name, plugin_conf_func)
    if helper.check_plugin(name, nil, true) then
        local success, err = pcall(plugin_conf_func, hl.plugin[name])
        if not success then
            helper.notify("Error configurando el plugin " .. name .. ": " .. tostring(err), "error", 5000)
        end
    end
end

return helper
