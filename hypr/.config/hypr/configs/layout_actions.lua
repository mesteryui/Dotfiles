-- configs/layout_actions.lua
--
-- Acciones de ventana cuya implementación depende del layout activo.
-- La tecla y la intención no cambian al cambiar de layout: solo cambia el
-- dispatcher que se ejecuta por debajo.
--
-- Reglas:
--   * `scrolling`, `dwindle`, `master` y `monocle` son las claves por layout.
--   * `default` se usa para layouts desconocidos o personalizados (`lua:*`),
--     pero solo cuando la acción tenga un equivalente universal real.
--   * Si un layout no tiene equivalente, se omite la clave (o se pone `false`
--     si existe un `default` que no debe aplicarse): el helper avisa una sola
--     vez y no ejecuta nada. Nunca se sustituye por una acción no relacionada.
--   * `floating` declara la variante para ventanas flotantes. `floating = false`
--     significa que la acción no se aplica a flotantes: avisa y no ejecuta la
--     acción del layout.
--
-- Notas por layout:
--   * El foco y el movimiento de ventanas no viven aquí: usan siempre el
--     dispatcher genérico (`hl.dsp.focus` y `hl.dsp.window.move`) en todos
--     los layouts, también en monocle.
--   * `scrolling` usa `swapcol l/r` para el intercambio por columnas y
--     `fit_into_view` para ajustar la columna activa a la vista.
--   * `monocle` no tiene intercambio por columnas ni rotación de división:
--     esas acciones caen al `default` genérico o avisan si no existe.
--   * El resize es la única acción que se especializa por unidad: fracción
--     de columna en `scrolling`, píxeles en el resto.

local M = {}

---@param text string
---@param level? "info"|"warn"|"error"|"success"
local function notify(text, level)
	if _G.helper and _G.helper.notify then
		_G.helper.notify(text, level)
	end
end

---Ejecuta un dispatcher o una función y deja el error en el log. Un fallo
---esperado (por ejemplo, "no adjacent column" en un borde) no debe convertirse
---en una notificación en cada pulsación.
---@param value HL.Dispatcher|fun()
---@param layout string
local function dispatch_value(value, layout)
	local ok, err
	if type(value) == "function" then
		ok, err = pcall(value)
	else
		ok, err = pcall(hl.dispatch, value)
	end

	if not ok then
		print("shinro: layout action failed (" .. layout .. "): " .. tostring(err))
	end
end

local notified = {}

---Notifica una sola vez por clave. El resize se repite mientras se mantiene la
---tecla y no queremos un aviso por pulsación.
---@param key string
---@param text string
---@param level? "info"|"warn"|"error"|"success"
local function notify_once(key, text, level)
	if notified[key] then
		return
	end
	notified[key] = true
	notify(text, level)
end

---En scrolling, ajusta las columnas a la vista. Si la ventana activa es
---flotante, la centra en su lugar.
local function fit_or_center()
	local win = hl.get_active_window()
	if win and win.floating then
		hl.dispatch(hl.dsp.window.center())
	else
		hl.dispatch(hl.dsp.layout("fit_into_view"))
	end
end

---Fuera de scrolling no existe un "fit" para ventanas tiled: la única
---intención equivalente es centrar flotantes. En tiled se avisa para que la
---tecla no parezca muerta.
local function center_or_notify()
	local win = hl.get_active_window()
	if win and win.floating then
		hl.dispatch(hl.dsp.window.center())
		return
	end

	notify_once(
		"fit-center-tiled",
		"Ajustar/centrar: en este layout solo se aplica a ventanas flotantes",
		"info"
	)
end

local function swap(direction)
	return hl.dsp.window.swap({ direction = direction })
end

-- ---------------------------------------------------------------------------
-- Resize
-- ---------------------------------------------------------------------------

---Resize genérico en píxeles. Es la unidad correcta cuando el layout reparte el
---espacio como un árbol (dwindle, master) y cuando la ventana flota: ahí el
---delta mueve el borde de la división.
---@param dx number
---@param dy number
local function px(dx, dy)
	return hl.dsp.window.resize({ x = dx, y = dy, relative = true })
end

---`at` y `size` llegan como tabla (`{ x, y }`) o como valor opaco según la
---versión. Si no hay coordenada legible devolvemos nil y el llamante decide,
---en vez de romper el resize por una limitación de la API.
---@param v any
---@return number|nil
local function x_of(v)
	if type(v) ~= "table" then
		return nil
	end
	return tonumber(v.x or v[1])
end

---@param win HL.Window
---@return boolean
local function is_fullscreen(win)
	local f = win.fullscreen
	return f == true or (type(f) == "number" and f ~= 0)
end

---¿La columna de `win` tiene más de una ventana? En `scrolling` la columna es
---la unidad: todas sus ventanas comparten `x` y ancho. Sin datos geométricos
---asumimos que sí hay pila para no desactivar el resize por error.
---@param win HL.Window
---@return boolean
local function column_has_stack(win)
	local ws = win.workspace
	local ax, aw = x_of(win.at), x_of(win.size)

	if not ws or not ax or not aw then
		return true
	end

	local count = 0
	for _, other in ipairs(hl.get_windows({ mapped = true })) do
		local ows = other.workspace
		if ows and ows.id == ws.id and not other.floating and not is_fullscreen(other) then
			local bx, bw = x_of(other.at), x_of(other.size)
			if not bx or not bw or (math.abs(ax - bx) <= 1 and math.abs(aw - bw) <= 1) then
				count = count + 1
			end
		end
	end

	return count > 1
end

---Alto de la pila dentro de la columna. Con una sola ventana la columna ocupa
---todo el alto y no hay nada que repartir: se avisa una vez en lugar de dejar
---la tecla muerta en silencio.
---@param delta number
local function column_height(delta)
	return function()
		local win = hl.get_active_window()
		if win and not column_has_stack(win) then
			notify_once(
				"resize-column-height",
				"Scrolling: la columna tiene una sola ventana; no hay altura que repartir",
				"info"
			)
			return
		end

		-- Al volver a haber pila se rearma el aviso para la próxima vez que
		-- la columna se quede con una sola ventana.
		notified["resize-column-height"] = nil
		hl.dispatch(px(0, delta))
	end
end

---Cuenta las columnas tiled distintas del workspace de `win`. En `scrolling`
---todas las ventanas de una columna comparten `x`. Si falta geometría se
---asume que hay más de una para no bloquear la acción por error.
---@param win HL.Window
---@return number
local function column_count(win)
	local ws = win.workspace
	if not ws then
		return 0
	end

	local seen, count = {}, 0
	for _, other in ipairs(hl.get_windows({ mapped = true })) do
		local ows = other.workspace
		if ows and ows.id == ws.id and not other.floating and not is_fullscreen(other) then
			local ox = x_of(other.at)
			if not ox then
				return math.huge
			end
			if not seen[ox] then
				seen[ox] = true
				count = count + 1
			end
		end
	end

	return count
end

---Las acciones de ancho mutan la columna, pero con
---`scrolling:fullscreen_on_one_column = true` una sola columna ocupa todo el
---ancho y el cambio no se ve. Se guarda para no mutar un estado invisible que
---aparecería después al abrir una segunda columna.
---@param value HL.Dispatcher|fun()
---@param name string
---@return fun()
local function width_action(value, name)
	return function()
		local win = hl.get_active_window()
		local fullscreen_on_one = hl.get_config("scrolling:fullscreen_on_one_column")
		if win and not win.floating and fullscreen_on_one ~= false then
			if column_count(win) <= 1 then
				notify_once(
					"width-one-column",
					name .. ": con una sola columna el ancho no se ve; abre otra para ajustarlo",
					"info"
				)
				return
			end
			-- Al volver a haber varias columnas se rearma el aviso.
			notified["width-one-column"] = nil
		end
		dispatch_value(value, "scrolling")
	end
end

---Resize por layout. La diferencia real está en `scrolling`: el ancho pertenece
---a la columna (fracción del área útil) y Hyprland la reencuadra tras el
---cambio, cosa que el resize en píxeles no hace.
---@param scrolling HL.Dispatcher|fun()
---@param dx number
---@param dy number
local function resize(scrolling, dx, dy)
	local generic = px(dx, dy)

	return {
		scrolling = scrolling,
		dwindle = generic,
		master = generic,
		monocle = false, -- monocle no expone geometría redimensionable
		default = generic,
		-- Un flotante no participa del layout: siempre píxeles.
		floating = generic,
	}
end

M.actions = {
	-- El foco y el movimiento se enlazan directamente con los dispatchers
	-- genéricos en configs/keybinds/window.lua: no cambian por layout.

	-- Intercambio de ventanas/columnas. En scrolling la unidad natural es la
	-- columna; en dwindle y master se intercambia la ventana activa. Monocle
	-- y los layouts `lua:*` caen al `default` genérico.
	swap_left = {
		scrolling = hl.dsp.layout("swapcol l"),
		dwindle = swap("left"),
		master = swap("left"),
		default = swap("left"),
		floating = false, -- un flotante no participa del layout
	},

	swap_right = {
		scrolling = hl.dsp.layout("swapcol r"),
		dwindle = swap("right"),
		master = swap("right"),
		default = swap("right"),
		floating = false,
	},

	rotate_split = {
		-- Conserva el comportamiento de SUPER+ALT+J en dwindle.
		dwindle = hl.dsp.layout("togglesplit"),
		master = hl.dsp.layout("orientationcycle"),
		-- scrolling, monocle y layouts `lua:*` no tienen una rotación de
		-- división equivalente.
		floating = false,
	},

	fit_center = {
		scrolling = fit_or_center,
		dwindle = center_or_notify,
		master = center_or_notify,
		monocle = center_or_notify,
		default = center_or_notify,
	},

	-- Resize. El ancho en `scrolling` es una propiedad de la columna, así que se
	-- ajusta en fracción del área útil; en el resto el delta mueve el borde de
	-- la división. El alto de una columna es un reparto entre sus ventanas.
	resize_wider = resize(width_action(hl.dsp.layout("colresize +0.02"), "Aumentar ancho"), 25, 0),
	resize_narrower = resize(width_action(hl.dsp.layout("colresize -0.02"), "Reducir ancho"), -25, 0),
	resize_taller = resize(column_height(25), 0, 25),
	resize_shorter = resize(column_height(-25), 0, -25),

	-- Presets de ancho. Solo tienen sentido cuando la unidad es la columna: fuera
	-- de `scrolling` se avisa una vez.
	width_cycle = {
		scrolling = width_action(hl.dsp.layout("colresize +conf"), "Siguiente ancho"),
		floating = false,
	},
	width_reset = {
		-- Vuelve al ancho por defecto configurado, sin duplicar el valor aquí.
		scrolling = width_action(function()
			local width = tonumber(hl.get_config("scrolling:column_width")) or 0.5
			hl.dispatch(hl.dsp.layout("colresize " .. tostring(width)))
		end, "Restablecer ancho"),
		floating = false,
	},
}

---Devuelve una función de keybind que resuelve la acción según el layout
---del workspace activo en el momento de pulsar la tecla.
---@param action table<string, HL.Dispatcher|fun()|false>|nil
---@param opts? { fallback?: string, name?: string }
---@return fun()
function M.bind(action, opts)
	opts = opts or {}

	if type(action) ~= "table" then
		notify("Layout actions: la acción no está definida", "error")
		return function() end
	end

	local warned = {}

	return function()
		local win = hl.get_active_window()
		-- El layout que importa es el de la ventana enfocada: así se cubren
		-- también los special workspaces, que `get_active_workspace()` no
		-- resuelve cuando el foco está dentro de uno.
		local ws = (win and win.workspace) or hl.get_active_special_workspace() or hl.get_active_workspace()
		if not ws then
			return
		end

		local layout = ws.tiled_layout or "dwindle"
		local value = action[layout]
		-- `false` significa "este layout no tiene equivalente", y evita que
		-- se use el `default` universal por accidente.
		local explicitly_unavailable = value == false

		-- Un flotante no pertenece a ninguna columna: los mensajes de layout lo
		-- ignoran. Si la acción declara variante flotante, esa manda; `false`
		-- significa que la acción no se aplica a flotantes.
		if win and win.floating and action.floating ~= nil then
			value = action.floating
			explicitly_unavailable = value == false
		elseif not explicitly_unavailable then
			if value == nil and opts.fallback then
				value = action[opts.fallback]
			end
			if value == nil then
				value = action.default
			end
		end

		if not value then
			local warn_key = layout .. ((win and win.floating) and ":floating" or ":tiled")
			if not warned[warn_key] then
				warned[warn_key] = true
				local prefix = opts.name and (opts.name .. ": ") or ""
				if win and win.floating and action.floating == false then
					notify(prefix .. "no se aplica a ventanas flotantes", "info")
				else
					notify(prefix .. "Layout " .. layout .. ": acción no disponible", "info")
				end
			end
			return
		end

		dispatch_value(value, layout)
	end
end

return M
