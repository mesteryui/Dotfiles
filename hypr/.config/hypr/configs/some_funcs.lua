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
function helper.submap.exitSubmap(key,options)
    hl.bind(key, hl.dsp.submap("reset"), options)
end

-- --- API DE GAMEMODE ---

---@class gamemode
--- API for managing performance-oriented system states.
helper.gamemode = {}

--- Checks if Gamemode is currently active.
---@return boolean True if animations are disabled (indicating Gamemode is active).
function helper.gamemode.is_active()
    -- Note: Using the same key pattern as the original implementation
    return hl.get_config("animations.enabled") == false
end

--- Internal function to apply "Gamemode" settings.
--- This reduces visual overhead to prioritize CPU/GPU for games.
local function _apply_gamemode_settings()
    hl.config({
        ["animations.enabled"] = false,
        ["decoration.shadow.enabled"] = false,
        ["decoration.blur.enabled"] = false,
        ["general.gaps_in"] = 0,
        ["general.gaps_out"] = 0,
        ["general.border_size"] = 1,
        ["decoration.rounding"] = 0,
        ["decoration.active_opacity"] = 1.0,
        ["decoration.inactive_opacity"] = 1.0,
        ["decoration.fullscreen_opacity"] = 1.0,
    })
end

--- Explicitly enables or disables Gamemode.
---@param enable boolean Whether to enable (true) or disable (false) Gamemode.
function helper.gamemode.set(enable)
    if enable then
        _apply_gamemode_settings()
        helper.notify("Gamemode [ON]", "success", 1500)
    else
        hl.exec_cmd("hyprctl reload")
        helper.notify("Gamemode [OFF]", "error", 1500)
    end
end

--- Toggles "Gamemode" state.
--- Disables animations, shadows, blur and simplifies borders for performance.
function helper.gamemode.toggle()
    helper.gamemode.set(not helper.gamemode.is_active())
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
