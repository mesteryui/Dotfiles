-- configs/appearance.lua
hl.config({
	general = {
		gaps_in = 10,
		gaps_out = 12,
		gaps_workspaces = 50,
		border_size = 2,
		allow_tearing = false,
		no_focus_fallback = true,
		col = {
			active_border = { colors = { Colors.primary }, angle = 45 },
			inactive_border = { colors = { Colors.surface_container }, angle = 45 },
		},
		resize_on_border = true,
		resize_corner = 3,
		layout = "scrolling",
	},
	cursor = {
		zoom_factor = 1,
		zoom_rigid = false,
		hotspot_padding = 1,
		hide_on_key_press = true,
		no_hardware_cursors = true,
		enable_hyprcursor = true,
		no_warps = false,
		warp_on_monitor_change = 2,
		persistent_warps = false,
		warp_on_change_workspace = 1,
		inactive_timeout = 7,
	},
	render = {
		direct_scanout = 0,
	},
	xwayland = {
		force_zero_scaling = true,
		use_nearest_neighbor = true,
	},
})

hl.config({
	group = {
		col = {
			border_active = { colors = { Colors.primary, Colors.tertiary }, angle = 45 },
			border_inactive = { colors = { Colors.on_secondary, Colors.surface_container }, angle = 45 },
			--border_locked_active = 1,
			--border_locked_inactive = 1,
		},
		groupbar = {
			font_size = 12,
			font_family = "monospace",
			font_weight_active = "ultraheavy",
			font_weight_inactive = "normal",
			indicator_height = 0,
			indicator_gap = 5,
			height = 22,
			gaps_in = 5,
			gaps_out = 0,
			text_color = Colors.on_primary,
			text_color_inactive = Colors.surface,
			col = {
				active = Colors.primary,
				inactive = Colors.on_surface,
			},
			gradients = true,
			gradient_rounding = 0,
			gradient_round_only_edges = false,
		},
	},
})

local base_color_hex = Colors.surface -- Esto te devuelve "0xff1a1111"

-- 3. Función para cambiar o inyectar una opacidad (alfa) personalizada (0.0 a 1.0)
local function set_opacity(color_str, opacity)
	-- 1. Convertimos la cadena "0xff1a1111" a un número entero de 32 bits
	local hex_number = tonumber(color_str:gsub("^0x", ""), 16)
	if not hex_number then
		return color_str
	end

	-- 2. Extraemos la parte RGB (ignorando el byte más alto que es el alfa original)
	-- Operación AND para quedarnos solo con los últimos 24 bits (R, G, B)
	local rgb_part = hex_number % 0x1000000

	-- 3. Calculamos el nuevo valor alfa (0 a 255) a partir de tu decimal (ej. 0.25)
	local alpha_int = math.floor(opacity * 255 + 0.5)

	-- 4. Combinamos el nuevo alfa (desplazándolo 24 bits a la izquierda) con la parte RGB
	local new_color_number = (alpha_int * 0x1000000) + rgb_part

	-- 5. Devolvemos el formato hexadecimal exacto de 8 dígitos que exige Hyprland
	return string.format("0x%08x", new_color_number)
end

-- Probamos con un 25% de opacidad (0.25)
local acrylic_tint = set_opacity(base_color_hex, 0.80)

hl.config({
	decoration = {
		rounding = 20,
		rounding_power = 2,
		active_opacity = 1.0,
		inactive_opacity = 0.94,
		dim_inactive = true,
		dim_strength = 0.15,
		wobble = {
			enabled = true,
			mesh = 16,
			stiffness = 350,
			damping = 25,
			mass = 3,
			value_epsilon = 0.25,
			intensity = 0.4,
		},
		blur = {
			enabled = true,
			size = 10,
			passes = 2,
			noise = 0.0,
			contrast = 2.0,
			brightness = 0.8,
			vibrancy = 0.5,
			vibrancy_darkness = 0.35,
			special = false,
			new_optimizations = true,
			variant = "kawase",
			acrylic = {
				aberration = 0.038,
				bulb = 48.0,
				clarity = 0.84,
				refraction = 32.0,
				tint = acrylic_tint,
			},
		},
		shadow = {
			enabled = true,
			--offset = "0 1",
			range = 25,
			render_power = 4,
			offset = { 0, 2 },
			color = Colors.shadow,
		},
		glow = {
			enabled = true,
			range = 35,
			render_power = 3,
			color = { colors = { Colors.surface_container_highest, Colors.surface_container }, angle = 45 },
			color_inactive = Colors.surface_container_lowest, --"0x00000000",
		},
	},
})

hl.config({
	master = {
		new_status = "master",
	},
	dwindle = {
		-- pseudotile = true,
		smart_resizing = true,
		force_split = 2,
		preserve_split = true,
		--special_scale_factor = 0.8,
	},
	scrolling = {
		column_width = 0.5,
		direction = "right",
		fullscreen_on_one_column = true,
		focus_fit_method = 1,
		-- Hyprland limita cada valor a [0.05, 1.0]; 1.8 se recortaba a 1.0 sin
		-- avisar. Se deja el valor real para que W recorra lo que de verdad
		-- existe.
		explicit_column_widths = "0.333, 0.5, 0.667, 1.0",
		follow_focus = true,
		-- Igual que en dwindle/master, intercambiar en el borde no debe
		-- teletransportar la ventana al otro extremo: la experiencia de
		-- SUPER+ALT+H/L se mantiene consistente entre layouts.
		wrap_swapcol = false,
		-- El foco genérico no consulta esta opción y `no_focus_fallback` está
		-- activo, así que en el borde no se envuelve. Se deja en false para
		-- que la configuración refleje el comportamiento real.
		wrap_focus = false,
	},
})
