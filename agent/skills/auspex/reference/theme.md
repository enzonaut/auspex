# Theme: AVGVR

The AVGVR theme is the look of the boot splash, the login screen, the
Hyprland desktop, the herdr app and Claude Code. All stages use 1 palette:
`themes/avgvr/colors.toml`. KDE Plasma stays unchanged as the fallback
session. Do not change game configuration (Steam, Lutris, Heroic).

## Change a color

1. Edit `themes/avgvr/colors.toml`. Do not edit `design/directions/c/`.
2. Run `auspex theme build`. It makes the files in `themes/avgvr/generated/`,
   the SDDM theme and the plymouth theme. Add `--dry-run` to preview.
3. Run `auspex check theme`. It checks templates, generated files, contrast,
   fonts and game paths.
4. Commit. Run `auspex plan`, then `auspex apply --reason "<request>"`.
5. If an SDDM or plymouth file changed, the operator runs
   `auspex system apply 060 070`. You run `auspex system prepare <step>`.
   The operator runs step 080 only when the boot step changed.

Never run sudo. Never run `auspex system apply` yourself.

## Where each look lives

Each user-tier look is a `render` row in `manifest/user.tsv`. Find the
template and target in `reference/targets.md`. Examples:

| Look | Template or source |
|---|---|
| Hyprland colors, hyprpaper, hyprlock | `templates/hypr/` |
| waybar style, mako, fuzzel | `templates/waybar/`, `templates/mako/`, `templates/fuzzel/` |
| herdr app theme | `templates/herdr-app/avgvr.json.tpl` |
| Claude Code theme `custom:avgvr` | `templates/claude/avgvr.json.tpl` |

The `hyprpaper` wallpaper is the only new resident process. LEGIO is the
waybar fleet counter. `auspex legio` prints it from `hc ls --json`.

## System steps

| Step | Action |
|---|---|
| `050-avgvr-fonts` | Install ttf-jetbrains-mono, Jost and Marcellus SC |
| `060-avgvr-sddm` | Install the SDDM theme, select it in `/etc/sddm.conf.d/zz-auspex-avgvr.conf` |
| `070-avgvr-plymouth` | Install plymouth and the plymouth theme |
| `080-avgvr-boot-splash` | Add plymouth to the initramfs, `quiet splash` to the kernel command line, rebuild the UKI |

Apply order: 050, 060, 070, 080. Undo order: 080 before 070, then 060, then
050. Apply 060 before the first lock, because hyprlock reads the mark that
step 060 installs. The `zz-` name makes AVGVR win over the KDE login theme
dialog. Manage the login theme through auspex only.

Warning: the operator needs an Arch install USB before step 080. Limine has
no second boot entry.

## The herdr app

The herdr app is the only terminal. Do not use or describe ghostty.

- `SUPER+Return` starts or raises the herdr app. It autostarts on workspace I.
- Layout: `config/herdr-app/layouts/avgvr.json`. Select it with
  `layout.switch avgvr`.
- Mod: `config/herdr-app/mods/avgvr-spaces/` shows the spaces as a row.
- Settings: `config/herdr-app/settings.json` is merged. auspex owns only the
  keys it lists (theme, font, ui_font, sounds). Never edit shipped herdr files.
- Theme: `~/.config/herdr-app/themes/avgvr.json`.
- If the open app keeps old colors after `auspex apply`, restart the app.
  The acceptance checklist records the result.
- Claude Code: the theme is `custom:avgvr`, set in `claude/deny.json`.

## Light rule

The theme adds no resident process except `hyprpaper`. Add no package beyond
`plymouth`, `hyprpaper` and `ttf-jetbrains-mono` without operator OK.
If the work needs another package or a daemon, ask the operator first.

## Recovery

| Failure | Recovery |
|---|---|
| Bad user-tier look | `auspex undo` |
| Fonts wrong (050) | `auspex system undo 050` |
| SDDM theme error (060) | Ctrl+Alt+F3, log in, `auspex system undo 060`, `sudo systemctl restart sddm` |
| plymouth error (070) | `auspex system undo 070` |
| Boot splash late or black (080) | Esc shows the text log. `auspex system undo 080` |
| New UKI does not boot | Boot the Arch USB, chroot, `auspex system undo 080` |
| hyprlock crash | Ctrl+Alt+F3, log in, `hyprctl --instance 0 dispatch exec hyprlock` |
| Hyprland unusable | Choose the KDE Plasma session at the login screen |

Undo a boot change first: 080, then 070, then 060, then 050.
