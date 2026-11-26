# 11 SUPER+Return, autostart and window rule for herdr-app

<!-- horch-ticket: 1 -->
**Persona:** primary `sonnet-feature`
**Kind:** feature
**Review:** light
**Blocked by:** 10-herdr-spaces-mod
**Check:** `bats tests/hyprland.bats`
**Own:** `config/hypr/hyprland.lua`, `bin/auspex-check-hyprland-rules`, `tests/hyprland.bats`, `agent/skills/auspex/reference/hyprland.md`
**Do not touch:** `config/hypr/agent-binds.lua`, `manifest/user.tsv`, `design/directions/c/`, `config/kde/`, `/usr/share/plasma/`, `/etc/sddm.conf.d/`, `~/.config/kdeglobals`, `~/.local/share/Steam/`, `~/.config/lutris/`, `~/.config/heroic/`

## GOAL

In Hyprland, SUPER+Return starts or raises the herdr app, the herdr app starts on workspace I at login, and a window rule tiles it.

## CONTEXT

- Spec: `docs/specs/avgvr-theme.md` sections 8.2 and 9.1. Research report `docs/research/herdr-app-avgvr.md`.
- Decisions to apply (from `ai_docs/plans/avgvr-theme/decisions.md`):
  - The herdr app is the only terminal. ghostty is not used.
  - Q7: no dropdown. SUPER+Return starts the herdr app, or focuses it when it runs.
  - Q8: the herdr app starts at Hyprland login on workspace I.
  - Q5 option O1: the herdr app tiles below waybar on workspace I. No fullscreen.
  - OQ12: autostart uses the `[workspace 1 silent] herdr-app` exec rule (the Lua form of `exec-once = [workspace 1 silent] herdr-app`), so it needs no class. The window rule ships with class `herdr-app` (StartupWMClass). The checklist (ticket 16) confirms the class with `hyprctl clients -j`. A mismatch is a 1-line fix ticket. This decision replaces the spec 8.2 rule "do not add the rule before confirmation".
- Today `config/hypr/hyprland.lua:33` binds `SUPER + Return` to `ghostty`. The start block is `hl.on("hyprland.start", ...)` at line 22.
- Start or raise: if a `herdr-app` client exists (`hyprctl clients -j` and `jq`), focus it with `focuswindow class:herdr-app`; else run `herdr-app`. Keep it a single short command in the bind, or a small script under `bin/` only if the bind gets too long (then add the script to **Own** in your done summary and ask the orchestrator first with `QUESTION:`).

## PRIOR WORK

Ticket 10 added the spaces mod. Ticket 05 changed `hyprland.lua` (theme.lua, hyprpaper). The orchestrator adds the 10 summary here.

## STEPS

1. Change the `SUPER + Return` bind. Add the autostart line in the start block. Check: `bats tests/hyprland.bats` has a case that finds no `ghostty` in `hyprland.lua` and passes.
2. Add the window rule for class `herdr-app` (tile, workspace 1 at start). Update `auspex check hyprland-rules` so it knows the rule. Check: `bin/auspex check hyprland-rules` and `bin/auspex check keys` pass.
3. Update `hyprland.md` (the bind, the autostart, the class and how to fix it). Run `bin/auspex check skill --fix` and `bin/auspex check --no-display`.

## CONSTRAINTS

- Light system (operator decision 2026-11-26): the theme adds no resident process except `hyprpaper`. No new package beyond `plymouth`, `hyprpaper` and `ttf-jetbrains-mono`. If the work seems to need another package or a daemon, send `QUESTION:` and end your turn.
- Do not run `hyprctl dispatch` and do not start `herdr-app` from a test. Tests read the config text or use fakes.
- Warning: do not run `auspex apply`, `auspex undo`, `auspex system apply` or sudo. Tests use `AUSPEX`, `AUSPEX_STATE` and `HOME` in a temp folder.
- No test starts a real `herdr-app`, `hc`, `sddm-greeter` or `plymouthd`, or makes a herdr space. Tests use fakes on `PATH` with `make_fake`, as `tests/agent.bats` does.
- Do not send project code, secrets or environment values to any host.
- Keep all existing bats tests green. Keep `shellcheck` clean. Do not change any KDE row in `manifest/user.tsv` (`auspex check kde-untouched`).

## DONE WHEN

- `bats tests/hyprland.bats`, `bin/auspex check hyprland-rules`, `bin/auspex check keys` and `bin/auspex check --no-display` pass.
- `git grep -n ghostty -- config` prints nothing.
- `git diff --name-only` of the branch shows only paths in **Own** (plus files that `auspex check skill --fix` generates).

## REPORT

- `horch ledger progress` after step 1.
- The `horch ledger done` summary gives the bind line, the autostart line and the rule line.
