hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("NVD_BACKEND", "direct")
hl.env("GSK_RENDERER", "ngl")

hl.monitor({ output = "DP-2", mode = "5120x2160@165", position = "0x0", scale = 1 })

hl.config({
  general = { allow_tearing = false },
  input = {
    kb_layout = "us",
    kb_model = "pc105+inet",
    kb_options = "terminate:ctrl_alt_bksp",
  },
  misc = {
    vrr = 0,
    key_press_enables_dpms = true,
    mouse_move_enables_dpms = true,
  },
})

hl.on("hyprland.start", function()
  hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
  hl.exec_cmd("/usr/lib/pam_kwallet_init")
  hl.exec_cmd("hyprpaper")
  hl.exec_cmd("waybar")
  hl.exec_cmd("mako")
  hl.exec_cmd("hypridle")
  hl.exec_cmd("systemctl --user start hyprpolkitagent")
  hl.exec_cmd("nm-applet --indicator")
  hl.exec_cmd("blueman-applet")
  hl.exec_cmd("[workspace 1 silent] herdr-app")
end)

hl.bind("SUPER + Return", hl.dsp.exec_cmd("hyprctl clients -j | jq -e '.[] | select(.class == \"herdr-app\")' >/dev/null && hyprctl dispatch focuswindow class:herdr-app || herdr-app"))
hl.bind("SUPER + D", hl.dsp.exec_cmd("fuzzel"))
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind("SUPER + V", hl.dsp.window.float({ action = "toggle" }))
for i = 1, 9 do
  hl.bind("SUPER + " .. i, hl.dsp.focus({ workspace = tostring(i) }))
  hl.bind("SUPER + SHIFT + " .. i, hl.dsp.window.move({ workspace = tostring(i), follow = false }))
end
hl.bind("Print", hl.dsp.exec_cmd('grim -g "$(slurp)" - | satty -f -'))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd('grim -g "$(slurp)" - | wl-copy'))
hl.bind("SUPER + L", hl.dsp.exec_cmd("pidof hyprlock || hyprlock"))
hl.bind("SUPER + SHIFT + E", hl.dsp.exit())

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { locked = true, repeating = true })

local config_dir = (debug.getinfo(1, "S").source:match("^@(.*/)"))
  or ((os.getenv("HOME") or "") .. "/.config/hypr/")
dofile(config_dir .. "agent-binds.lua")

local load_theme = loadfile(config_dir .. "theme.lua")
local theme = load_theme and load_theme()
if theme then
  hl.config(theme.config)
  hl.curve(theme.curve.name, { type = "bezier", points = theme.curve.points })
  hl.animation({ leaf = "global", enabled = true, speed = theme.animation_speed, bezier = theme.curve.name })
end

-- Window rules (spec 9.5). The last matching rule wins, so each program
-- first floats all its windows, then tiles its main window.
hl.window_rule({ match = { class = "^herdr-app$" }, tile = true, workspace = "1" })
hl.window_rule({ match = { class = "^steam$" }, float = true, center = true })
hl.window_rule({ match = { class = "^steam$", title = "^Steam$" }, tile = true })
hl.window_rule({ match = { class = "^steam_app_.*" }, idle_inhibit = "fullscreen" })
hl.window_rule({ match = { class = "^battle\\.net\\.exe$" }, float = true, center = true, size = { 1400, 900 } })
hl.window_rule({ match = { title = "^(Battle\\.net Login|Blizzard Battle\\.net)$" }, float = true, center = true })
hl.window_rule({ match = { class = "^net\\.lutris\\.Lutris$" }, float = true })
hl.window_rule({ match = { class = "^net\\.lutris\\.Lutris$", title = "^Lutris$" }, tile = true })
hl.window_rule({ match = { class = "^heroic$" }, float = true })
hl.window_rule({ match = { class = "^heroic$", title = "^Heroic Games Launcher$" }, tile = true })
hl.window_rule({ match = { class = "^net\\.davidotek\\.pupgui2$" }, float = true })
hl.window_rule({ match = { class = "^gamescope$" }, fullscreen = true, idle_inhibit = "always" })
hl.window_rule({ match = { fullscreen = true }, idle_inhibit = "fullscreen" })
hl.window_rule({ match = { title = "^(Open File|Save File).*" }, float = true, center = true, size = { "monitor_w * 0.5", "monitor_h * 0.5" } })
hl.window_rule({ match = { class = "^xdg-desktop-portal-.*" }, float = true, center = true, size = { "monitor_w * 0.5", "monitor_h * 0.5" } })
hl.window_rule({ match = { class = "^(org\\.pulseaudio\\.pavucontrol|pavucontrol|blueman-manager|\\.blueman-manager-wrapped|nm-connection-editor)$" }, float = true })

