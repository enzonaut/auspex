# Hyprland

Hyprland is a 2nd SDDM session beside Plasma. SDDM keeps Plasma as the
default. `auspex facts` tells which session runs now.

The Hyprland config is not built yet. `config/hypr/` and the other app
folders are empty until the Hyprland ticket adds them. Check
`reference/targets.md` before you edit: if a file has no manifest row, it is
not installed.

## Where each setting goes

| Setting | Folder |
|---|---|
| Monitors, binds, gaps, window rules, env vars, autostart | `config/hypr/` |
| Idle and lock | `config/hypr/` (hypridle and hyprlock files) |
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
