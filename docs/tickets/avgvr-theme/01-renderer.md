# 01 Palette, renderer, render mode and the theme-set event

<!-- horch-ticket: 1 -->
**Persona:** primary `opus`
**Kind:** feature
**Review:** full
**Check:** `bats tests/render.bats tests/apply.bats tests/hooks.bats`
**Own:** `themes/README.md`, `themes/current`, `themes/avgvr/colors.toml`, `templates/README.md`, `lib/render.sh`, `lib/common.sh`, `bin/auspex-apply`, `bin/auspex-undo`, `bin/auspex-plan`, `bin/auspex-status`, `hooks/theme-set.d/`, `tests/render.bats`, `tests/apply.bats`, `tests/hooks.bats`, `tests/fixtures/apply/`, `tests/fixtures/render/`, `agent/skills/auspex/reference/apply-undo.md`
**Do not touch:** `manifest/user.tsv`, `config/`, `system/`, `claude/`, `design/directions/c/`, `config/kde/`, `/usr/share/plasma/`, `/etc/sddm.conf.d/`, `~/.config/kdeglobals`, `~/.local/share/Steam/`, `~/.config/lutris/`, `~/.config/heroic/`

## GOAL

The repo has the AVGVR palette, the renderer `auspex_render`, the manifest `render` mode and the `theme-set` hook event, and their bats tests pass.

## CONTEXT

- Spec: `docs/specs/avgvr-theme.md` sections 2, 4.1, 4.2, 4.3 and 12.1 (rows Renderer, Render mode, Theme hooks). Build order item 1 (section 13), first half. Ticket 02 does the second half (theme build, fonts, step 050).
- Decisions to apply (from `ai_docs/plans/avgvr-theme/decisions.md`):
  - Build the AVGVR theme (`design/directions/c/`) end to end. 1 palette for every stage: boot, login and desktop.
  - KDE Plasma stays unchanged. No change to game config (Steam, Lutris, Heroic, Proton, Wine).
  - The herdr app is the only terminal. ghostty is not used. There is no ghostty hook (spec section 4.3).
- `design/directions/c/colors.toml` is the frozen design record. Copy its values into `themes/avgvr/colors.toml` with the keys of section 4.1. Do not edit the design folder.
- No manifest row changes in this ticket. Later tickets add the `render` rows.

## PRIOR WORK

The foundation landed (PR #4). The manifest modes `copy` and `merge:<name>` exist in `lib/common.sh`. The orchestrator adds more notes here.

## STEPS

1. Write `themes/avgvr/colors.toml` (section 4.1), `themes/current` (1 line `avgvr`) and update `themes/README.md`. Check: the palette has every key that section 4.1 names, including the herdr map keys.
2. Write `lib/render.sh` with `auspex_render` (section 4.2): `{{key}}` and the filters `bare`, `rgba:ff`, `dec`. Unknown key, unknown filter, a color filter on a text value, a bad palette line and a leftover `{{` fail with the line number. No environment value goes into the output. Same input gives the same bytes. Update `templates/README.md` with the syntax. Check: `bats tests/render.bats` passes.
3. Add the `render` mode to `auspex_manifest_load` and to apply, plan, status, adopt, drift and undo (section 4.2). Copy → render on the same target with an unchanged file is not drift. Check: the new cases in `bats tests/apply.bats` pass, including "a palette edit changes all render targets in 1 generation".
4. Add the `theme-set` event (section 4.3): `hooks/theme-set.d/*` run after the `post-apply` or `post-undo` hooks, only when at least 1 `render` target changed, with the generation number as `$1`. A failed hook prints a warning. Write `10-waybar` (SIGUSR2 to `pidof waybar` when `style.css` changed) and `20-hyprpaper` (`hyprctl hyprpaper reload ,<path>` when the wallpaper or `hyprpaper.conf` changed). Check: the new cases in `bats tests/hooks.bats` pass with fake `pidof`, `kill` and `hyprctl` on `PATH`.
5. Update `agent/skills/auspex/reference/apply-undo.md` with the `render` mode and the `theme-set` event. Run `bin/auspex check skill --fix` and commit the generated files if it changes them.
6. Run `bin/auspex check --no-display`.

## CONSTRAINTS

- Light system (operator decision 2026-11-26): the theme adds no resident process except `hyprpaper`. No new package beyond `plymouth`, `hyprpaper` and `ttf-jetbrains-mono`. If a step seems to need another package or a daemon, send `QUESTION:` and end your turn.
- Warning: do not run `auspex apply`, `auspex undo`, `auspex system apply` or sudo. Tests use `AUSPEX`, `AUSPEX_STATE` and `HOME` in a temp folder (foundation section 11).
- Tests never send a real signal to a real process. Put fakes on `PATH` with `make_fake` from `tests/test_helper.bash`, as `tests/agent.bats` does.
- Keep all existing bats tests green. Keep `shellcheck` clean.
- Write docs in Simplified Technical English, as the other skill pages are.

## DONE WHEN

- `bats tests/render.bats tests/apply.bats tests/hooks.bats` passes.
- `bin/auspex check --no-display` passes.
- `git diff --name-only` of the branch shows only paths in **Own** (plus files that `auspex check skill --fix` generates).

## REPORT

- `horch ledger progress` after steps 2, 3 and 4.
- The `horch ledger done` summary names: the palette keys, the render filters, how plan and status show a `render` row, and each gotcha that ticket 02 needs.
