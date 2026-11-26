# Hyprland

Hyprland is a 2nd SDDM session beside Plasma. SDDM keeps Plasma as the
default. `auspex facts` tells which session runs now.

Check `reference/targets.md` before you edit: if a file has no manifest row,
it is not installed.

## Where each setting goes

| Setting | Folder |
|---|---|
| Monitors, binds, gaps, window rules, env vars, autostart | `config/hypr/` |
| Idle and lock | `config/hypr/` (hypridle and hyprlock files) |
| Look: border, gaps, rounding, group bar, animation, background | `templates/hypr/theme.lua.tpl` (rendered from the palette) |
| Wallpaper | `templates/hypr/hyprpaper.conf.tpl`; the PNG is `themes/avgvr/generated/wallpaper.png` |
| Bar | `config/waybar/` |
| Notifications | `config/mako/` |
| Launcher | `config/fuzzel/` |
| Browser keyring flags | `config/browser-flags/` |

The config format follows Hyprland 0.57.

## Fixed values

- Monitor `DP-2`, `5120x2160@165`, position `0x0`, scale `1`. VRR off.
  Tearing off.
- NVIDIA env vars live only in the Hyprland config, so KDE does not see them.
- Idle: lock after 10 minutes, display off after 15 minutes. No suspend,
  because the machine runs fleet workers.

## Look and wallpaper

`hyprland.lua` loads the rendered `~/.config/hypr/theme.lua` and starts
`hyprpaper` with the other `hl.exec_cmd` lines. Change colors, border width,
radius and motion in `themes/avgvr/colors.toml`, not in the template. Border
1 px (bronze active, `border` inactive), rounding 0, no shadow, no blur,
gaps 6 in and 12 out. `hyprpaper` is the only resident process the theme
adds. Never edit `theme.lua`, `hyprpaper.conf` or the wallpaper in `~/`: they
are render or copy targets.

## Reload

The hook `hooks/post-apply.d/10-reload-hyprland` runs `hyprctl reload` after
an apply that changes a `hypr` target, if Hyprland runs. The hook
`hooks/post-apply.d/30-mako` reloads mako. Waybar reloads on its own when its
file changes.

## Read the live state

These commands are level 1:

- `hyprctl -j monitors`, `hyprctl -j clients`, `hyprctl -j workspaces`.
- `journalctl --user -b` for errors.

## Window rules

Find the class with `hyprctl -j clients` before you write a rule. Games keep
the defaults, except `idleinhibit fullscreen`. Launchers and dialogs float.

## Refresh rate questions

"Why is my game at 60 Hz" is often the monitor mode or the game's own
setting. Check `hyprctl -j monitors` (Hyprland) or `kscreen-doctor -o` (KDE),
then the game's display settings, before you change any file.

## Packages

The packages are in `packages/` and need a system step. See
`reference/system-steps.md`.
