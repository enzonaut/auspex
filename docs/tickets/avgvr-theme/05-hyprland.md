# 05 Hyprland look and hyprpaper

<!-- horch-ticket: 1 -->
**Persona:** primary `sonnet-feature`
**Kind:** feature
**Review:** light
**Check:** `bats tests/hyprland.bats tests/apply.bats`
**Own:** `templates/hypr/theme.lua.tpl`, `templates/hypr/hyprpaper.conf.tpl`, `config/hypr/hyprland.lua`, `packages/hyprland.list`, `manifest/user.tsv`, `claude/deny.json`, `bin/auspex-check-theme`, `tests/hyprland.bats`, `agent/skills/auspex/reference/hyprland.md`, `agent/skills/auspex/reference/targets.md`
**Do not touch:** `config/hypr/agent-binds.lua`, `design/directions/c/`, `config/kde/`, `/usr/share/plasma/`, `/etc/sddm.conf.d/`, `~/.config/kdeglobals`, `~/.local/share/Steam/`, `~/.config/lutris/`, `~/.config/heroic/`

## GOAL

Hyprland loads a rendered `theme.lua` with the AVGVR look, and `hyprpaper` shows the AVGVR wallpaper.

## CONTEXT

- Spec: `docs/specs/avgvr-theme.md` sections 8.1 (rows theme.lua, hyprland.lua, hyprpaper.conf, wallpaper) and 8.2 (the look table, hyprpaper, no env vars). Build order item 4.
- Decisions to apply (from `ai_docs/plans/avgvr-theme/decisions.md`):
  - Q1: workspaces keep Roman numerals (waybar does this in ticket 06).
  - Q3: the focused window border is bronze.
  - Q5 option O1: the herdr app tiles below waybar on workspace I. Waybar is the only band.
  - Light system: `hyprpaper` is the only new resident process. It is the only new package in `packages/hyprland.list`.
- Look (section 8.2): border 1 px; active `bronze`, inactive `border`; rounding 0; no shadow, no blur; gaps 6 in, 12 out; group bar `surface` background with `gold` text; animation speed `motion_ms / 100`, 1 linear-out curve, no slide, no bounce; background `bg_darker`; `misc`: `disable_hyprland_logo = true`, `disable_splash_rendering = true`, `allow_session_lock_restore = true`.
- `hyprland.lua` loads `theme.lua` as it loads `agent-binds.lua`, and starts `hyprpaper` with the other `hl.exec_cmd` lines in `hl.on("hyprland.start", ...)`.
- `hyprpaper.conf` preloads and sets `~/.local/share/auspex/wallpaper/avgvr.png` for every monitor. Confirm from the hyprpaper docs or `man hyprpaper` that the installed version accepts `~`. If not, use the fixed render key `home` (the only non-palette key) and say so in the done summary.
- No cursor setting. No `XCURSOR_*`, `GTK_THEME` or `QT_*` variable. Games and KDE inherit nothing new.
- Leave the `SUPER + Return` bind at `hyprland.lua:33` as it is. Ticket 11 changes it.

## PRIOR WORK

Tickets 01 to 04 added the renderer, the theme build, SDDM and plymouth. The orchestrator adds their summaries here.

## STEPS

1. Write `templates/hypr/theme.lua.tpl` and edit `config/hypr/hyprland.lua` to load it. Check: `bats tests/hyprland.bats` passes; `bin/auspex check hyprland` passes or prints `skip`.
2. Write `templates/hypr/hyprpaper.conf.tpl`. Add `hyprpaper` to `packages/hyprland.list` and its `exec_cmd` line.
3. Add the 4 manifest rows of CONTEXT (session `hyprland`) and Edit and Write deny rules for each new target in `claude/deny.json`. Check: `bin/auspex check permissions` and `bin/auspex check kde-untouched` pass; `bin/auspex plan` (read only) lists the new rows.
4. Add to `auspex check theme`: `Hyprland --verify-config` on the rendered config in a temp `HOME` when `Hyprland` is installed, else `skip`. Check: `bin/auspex check theme` passes.
5. Update `hyprland.md` and `targets.md`. Run `bin/auspex check skill --fix` and `bin/auspex check --no-display`.

## Operator steps

Do not run `auspex system prepare` or `auspex system apply`. Step 010 must run again to install `hyprpaper`. Ticket 16 puts this into the checklist. Send `NOTE:` that step 010 changed.

## CONSTRAINTS

- Light system (operator decision 2026-11-26): the theme adds no resident process except `hyprpaper`. No new package beyond `plymouth`, `hyprpaper` and `ttf-jetbrains-mono`. If the work seems to need another package or a daemon, send `QUESTION:` and end your turn.
- Warning: do not run `auspex apply`, `auspex undo`, `auspex system apply` or sudo. Tests use `AUSPEX`, `AUSPEX_STATE` and `HOME` in a temp folder.
- No test starts a real `herdr-app`, `hc`, `sddm-greeter` or `plymouthd`, or makes a herdr space. Tests use fakes on `PATH` with `make_fake`, as `tests/agent.bats` does.
- Do not send project code, secrets or environment values to any host.
- Keep all existing bats tests green. Keep `shellcheck` clean. Do not change any KDE row in `manifest/user.tsv` (`auspex check kde-untouched`).

## DONE WHEN

- `bats tests/hyprland.bats tests/apply.bats`, `bin/auspex check theme` and `bin/auspex check --no-display` pass.
- `git diff --name-only` of the branch shows only paths in **Own** (plus files that `auspex check skill --fix` generates).

## REPORT

- `horch ledger progress` after steps 1 and 3.
- The `horch ledger done` summary says whether hyprpaper takes `~` or the `home` key is used.
