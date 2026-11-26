# 06 waybar: the inscription band

<!-- horch-ticket: 1 -->
**Persona:** primary `sonnet-feature`
**Kind:** feature
**Review:** light
**Blocked by:** 05-hyprland
**Own:** `templates/waybar/style.css.tpl`, `config/waybar/config.jsonc`, `manifest/user.tsv`, `claude/deny.json`, `bin/auspex-check-theme`, `agent/skills/auspex/reference/targets.md`
**Do not touch:** `hooks/theme-set.d/`, `design/directions/c/`, `config/kde/`, `/usr/share/plasma/`, `/etc/sddm.conf.d/`, `~/.config/kdeglobals`, `~/.local/share/Steam/`, `~/.config/lutris/`, `~/.config/heroic/`

## GOAL

waybar is 1 band at the top with Roman numeral workspaces, a center clock, bracketed status modules and the AVGVR style.

## CONTEXT

- Spec: `docs/specs/avgvr-theme.md` section 8.3 and 8.1 (rows config.jsonc, style.css). Build order item 5.
- Decisions to apply (from `ai_docs/plans/avgvr-theme/decisions.md`):
  - Q1: workspaces keep Roman numerals I to X. Persistent workspaces I to V.
  - Q2: the accent `#EB6A43` shows only for blocked and the cursor. In the bar: only the urgent workspace button and `#custom-legio.blocked`.
  - Q5 option O1: waybar is the only band.
- `config.jsonc`: `position: top`, full width, height 40, `layer: top`, `exclusive: true`. `hyprland/workspaces` with `format: "{icon}"` and `format-icons` 1→I … 10→X. `clock` in the center with `{:%A %d %B   %H:%M}`. `pulseaudio`, `network`, `tray` at the right in `[ ]` brackets, for example `[ VOL 40 ]`, `[ ETH ]`.
- Do not add `custom/legio` to `config.jsonc`. Ticket 12 adds it. Put the `#custom-legio` and `#custom-legio.blocked` rules in `style.css` now (`font_data`, `text_muted`; blocked uses `accent`).
- `style.css`: `window#waybar` background `bg_dark`, 1 px `border` top and bottom, a dentil rail (`repeating-linear-gradient` of `bronze_dark` blocks on the bottom 3 px). Workspace buttons: `font_display`, letter spacing 0.12em, `text_muted`; active: background `porphyry`, text `text_bright`; urgent: `accent` text. Radius 0, no shadow, transition 200 ms on color only.
- The `10-waybar` theme-set hook (ticket 01) reloads the style. Do not edit it.

## PRIOR WORK

Ticket 05 added the Hyprland look and hyprpaper. The orchestrator adds the 05 summary here.

## STEPS

1. Edit `config/waybar/config.jsonc`. Write `templates/waybar/style.css.tpl`.
2. Add the `style.css` render row and deny rules. Check: `bin/auspex check permissions` and `bin/auspex check kde-untouched` pass.
3. Add to `auspex check theme`: `jq` parses `config.jsonc` after comments are removed; the accent appears in `style.css` only in the urgent and `.blocked` rules. Check: `bin/auspex check theme` passes.
4. Update `targets.md`. Run `bin/auspex check skill --fix` and `bin/auspex check --no-display`.

## CONSTRAINTS

- Light system (operator decision 2026-11-26): the theme adds no resident process except `hyprpaper`. No new package beyond `plymouth`, `hyprpaper` and `ttf-jetbrains-mono`. If the work seems to need another package or a daemon, send `QUESTION:` and end your turn.
- No new waybar module that runs a script, except `custom/legio` in ticket 12.
- Warning: do not run `auspex apply`, `auspex undo`, `auspex system apply` or sudo. Tests use `AUSPEX`, `AUSPEX_STATE` and `HOME` in a temp folder.
- No test starts a real `herdr-app`, `hc`, `sddm-greeter` or `plymouthd`, or makes a herdr space. Tests use fakes on `PATH` with `make_fake`, as `tests/agent.bats` does.
- Do not send project code, secrets or environment values to any host.
- Keep all existing bats tests green. Keep `shellcheck` clean. Do not change any KDE row in `manifest/user.tsv` (`auspex check kde-untouched`).

## DONE WHEN

- `bin/auspex check theme` and `bin/auspex check --no-display` pass.
- `git diff --name-only` of the branch shows only paths in **Own** (plus files that `auspex check skill --fix` generates).

## REPORT

- `horch ledger progress` after step 2.
- The `horch ledger done` summary names the selectors that use the accent.
