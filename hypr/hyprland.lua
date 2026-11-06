hl.monitor({
	output = "",
	mode = "preferred",
	position = "auto",
	scale = "1",
})

pcall(function()
	local xdg = os.getenv("XDG_DATA_HOME")
	local base = (xdg ~= nil and xdg ~= "") and xdg or ((os.getenv("HOME") or "") .. "/.local/share")
	dofile(base .. "/quickshell/qs-monitors.lua")
end)

local terminal = "foot"
local fileManager = "nemo"
local browser = "helium-browser"

hl.on("hyprland.start", function()
	hl.exec_cmd("qs")
	hl.exec_cmd("hypridle")
	hl.exec_cmd("hyprsunset")
	hl.exec_cmd("wl-paste --watch cliphist store")
	hl.exec_cmd("wl-paste --type image --watch cliphist store")
	hl.exec_cmd("systemctl --user start hyprpolkitagent")
	hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
end)

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QS_ICON_THEME", "Adwaita")

hl.config({
	general = {
		gaps_in = 3,
		gaps_out = 5,
		border_size = 1,
		layout = "dwindle",
	},
	decoration = {
		rounding = 0,
		active_opacity = 0.96,
		inactive_opacity = 0.94,
		shadow = {
			enabled = true,
			range = 6,
			render_power = 2,
		},
		blur = {
			enabled = true,
			size = 6,
			passes = 2,
			vibrancy = 0.0,
		},
	},
	animations = {
		enabled = true,
	},
	dwindle = {
		preserve_split = true,
	},
	misc = {
		force_default_wallpaper = 0,
		disable_hyprland_logo = true,
	},
	input = {
		kb_layout = "us",
		kb_options = "caps:escape",
		repeat_rate = 25,
		repeat_delay = 300,
		follow_mouse = 1,
		sensitivity = 0,
		touchpad = {
			natural_scroll = true,
			disable_while_typing = true,
			scroll_factor = 0.8,
		},
	},
})

pcall(function()
	dofile((os.getenv("HOME") or "") .. "/.config/hypr/theme.lua")
end)

hl.curve("funk", { type = "bezier", points = { { 0.60, 0.01 }, { 0.40, 1.00 } } })
hl.animation({ leaf = "fade", enabled = false })
hl.animation({ leaf = "border", enabled = false })
hl.animation({ leaf = "layers", enabled = false })
hl.animation({ leaf = "windows", enabled = false })
hl.animation({ leaf = "specialWorkspace", enabled = false })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 2, bezier = "funk" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 2, bezier = "funk", style = "slide" })

hl.gesture({
	fingers = 3,
	direction = "horizontal",
	action = "workspace",
})

local mainMod = "SUPER"
local secondMod = "SUPER + SHIFT"

hl.bind(mainMod .. " + A", hl.dsp.global("qs-bar:control"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(secondMod .. " + Return", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + Space", hl.dsp.global("qs:launcher"))
hl.bind("ALT + Space", hl.dsp.global("qs:launcher"))
hl.bind(mainMod .. " + period", hl.dsp.global("qs:emoji"))
hl.bind(mainMod .. " + comma", hl.dsp.global("qs-bar:settings"))
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))

hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + D", hl.dsp.window.fullscreen({ mode = 1 }))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + Y", hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + CTRL + F", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + V", hl.dsp.global("qs:clipboard"))

hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "right" }))

hl.bind(secondMod .. " + H", hl.dsp.window.move({ direction = "left" }))
hl.bind(secondMod .. " + J", hl.dsp.window.move({ direction = "down" }))
hl.bind(secondMod .. " + K", hl.dsp.window.move({ direction = "up" }))
hl.bind(secondMod .. " + L", hl.dsp.window.move({ direction = "right" }))

hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("scratchpad"))
hl.bind(secondMod .. " + S", hl.dsp.window.move({ workspace = "special:scratchpad", follow = false }))

for i = 1, 10 do
	local key = i % 10
	hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
	hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind(secondMod .. " + Q", hl.dsp.global("qs-bar:power"))
hl.bind(secondMod .. " + C", hl.dsp.global("qs:caffeine"))
hl.bind(secondMod .. " + D", hl.dsp.global("qs:dnd"))
hl.bind(mainMod .. " + CTRL + L", hl.dsp.global("qs:lock"), { locked = true })

hl.bind("Print", hl.dsp.global("qs:screenshot-area"))
hl.bind("CTRL + Print", hl.dsp.global("qs:screenshot-full"))
hl.bind("SHIFT + Print", hl.dsp.global("qs:screenshot-window"))

hl.bind("XF86PowerOff", hl.dsp.global("qs:powerkey"), { locked = true })

hl.bind("XF86AudioRaiseVolume", hl.dsp.global("qs:volume-up"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.global("qs:volume-down"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.global("qs:volume-mute"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.global("qs:mic-mute"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.global("qs:brightness-up"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.global("qs:brightness-down"), { locked = true, repeating = true })

hl.bind("XF86AudioNext", hl.dsp.global("qs:media-next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.global("qs:media-toggle"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.global("qs:media-toggle"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.global("qs:media-prev"), { locked = true })

hl.window_rule({
	name = "fix-xwayland-drags",
	match = {
		class = "^$",
		title = "^$",
		xwayland = true,
		float = true,
		fullscreen = false,
		pin = false,
	},

	no_focus = true,
})

hl.window_rule({
	name = "float-transparency",
	match = { float = true },
	opacity = "0.9 override 0.9 override",
})

hl.window_rule({
	match = {
		class = "^Bitwarden$",
	},
	no_screen_share = true,
	float = true,
	center = true,
	size = { 1000, 800 },
	tag = "+floating-window",
})

hl.window_rule({
	name = "float-bitwarden-chromium",
	match = {
		class = ".*nngceckbapebfimnlniiiahkandclblb.*",
	},
	no_screen_share = true,
	float = true,
	center = true,
	tag = "+floating-window",
})

hl.layer_rule({
	name = "qs-bar-glass",
	match = { namespace = "qs-bar" },
	blur = true,
	ignore_alpha = 0.1,
})

hl.layer_rule({
	name = "qs-notifications-glass",
	match = { namespace = "qs-notifications" },
	ignore_alpha = 0.1,
	no_anim = true,
})

hl.layer_rule({
	name = "qs-popup-anchor-glass",
	match = { namespace = "qs-popup-anchor" },
	ignore_alpha = 0.1,
	no_anim = true,
})

hl.layer_rule({
	name = "qs-picker-order",
	match = { namespace = "qs-screenshot-picker" },
	order = 30,
})

hl.layer_rule({
	name = "qs-notifications-order",
	match = { namespace = "qs-notifications" },
	order = 20,
})

hl.layer_rule({
	name = "qs-popup-anchor-order",
	match = { namespace = "qs-popup-anchor" },
	order = 10,
})
