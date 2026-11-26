# 07 mako, fuzzel and hyprlock; remove ghostty

<!-- horch-ticket: 1 -->
**Persona:** primary `sonnet-feature`
**Kind:** feature
**Review:** light
**Own:** `templates/mako/config.tpl`, `templates/fuzzel/fuzzel.ini.tpl`, `templates/hypr/hyprlock.conf.tpl`, `config/mako/config`, `config/fuzzel/fuzzel.ini`, `config/hypr/hyprlock.conf`, `config/ghostty/.gitkeep`, `manifest/user.tsv`, `claude/deny.json`, `bin/auspex-check-theme`, `tests/fuzzel-terminal.bats`, `agent/skills/auspex/reference/targets.md`
**Do not touch:** `config/hypr/hyprland.lua`, `design/directions/c/`, `config/kde/`, `/usr/share/plasma/`, `/etc/sddm.conf.d/`, `~/.config/kdeglobals`, `~/.local/share/Steam/`, `~/.config/lutris/`, `~/.config/heroic/`

## GOAL

mako, fuzzel and hyprlock are rendered from the palette, and ghostty is gone from the repo.

## CONTEXT

- Spec: `docs/specs/avgvr-theme.md` sections 8.1, 8.4 and 8.5, and section 10 (hyprlock recovery). Build order item 6.
- Decisions to apply (from `ai_docs/plans/avgvr-theme/decisions.md`):
  - The herdr app is the only terminal. ghostty is not used. Remove the ghostty manifest row and `config/ghostty/.gitkeep`.
  - Q2: the accent shows only for blocked and the cursor. mako high urgency and the hyprlock fail color are the alert uses.
  - OQ13: fuzzel `terminal=` uses `herdr-app do tab.new` with `--argv`. Confirm the exact form from `herdr-app commands` (read only; it does not start the app). Test it with a fake `herdr-app`. If no form runs a program in a new tab, ship no `terminal=` line.
- mako: `font=Jost 11`, `background-color=bg_dark`, `text-color=text`, `border-color=border`, `border-size=1`, `border-radius=0`, `padding=12`, `default-timeout=8000`. `[urgency=high]` `border-color=accent`. `[urgency=low]` `text-color=text_muted`.
- fuzzel: `font=Jost:size=12`, `[colors]` with the `rgba:ff` filter: background `bg_dark`, text `text`, match `gold`, selection `selection`, selection-text `text_bright`, border `bronze`. `[border] width=1 radius=0`. Remove `terminal=ghostty -e`.
- hyprlock: background `bg_darker`, no blur, no image; a `shape` 100 % wide, 1 px high, `bronze`, at the vertical center; time above in `font_display` `gold`; date below in `font_body` `text_muted`; the mark image 64 px above the time; `input-field` with `outer_color` `bronze`, `inner_color` `bg_darker`, `font_color` `text_bright`, `rounding 0`, `fade_on_empty true`, `check_color` `gold`, `fail_color` `accent`.
- The 3 rows change from `copy` to `render`. The old sources are removed.

## PRIOR WORK

Ticket 06 added waybar. The orchestrator adds the 06 summary here.

## STEPS

1. Write the 3 templates. Change the 3 rows to `render` and remove the old sources. Remove the ghostty row and `config/ghostty/.gitkeep`. Check: `bats tests/apply.bats` passes (copy to render with no drift).
2. Read `herdr-app commands` for the `tab.new` form. Write `tests/fuzzel-terminal.bats` with a fake `herdr-app` that records its argv. Check: the test passes, or you ship no `terminal=` line and say why.
3. Add to `auspex check theme`: `fuzzel --check-config` on the rendered file when `fuzzel` is installed, else `skip`. Check: `bin/auspex check theme` passes.
4. Update deny rules and `targets.md`. Run `bin/auspex check skill --fix`, `bin/auspex check permissions` and `bin/auspex check --no-display`.

## CONSTRAINTS

- Light system (operator decision 2026-11-26): the theme adds no resident process except `hyprpaper`. No new package beyond `plymouth`, `hyprpaper` and `ttf-jetbrains-mono`. If the work seems to need another package or a daemon, send `QUESTION:` and end your turn.
- Do not run `hyprlock`. The checklist (ticket 16) has the lock test.
- Warning: do not run `auspex apply`, `auspex undo`, `auspex system apply` or sudo. Tests use `AUSPEX`, `AUSPEX_STATE` and `HOME` in a temp folder.
- No test starts a real `herdr-app`, `hc`, `sddm-greeter` or `plymouthd`, or makes a herdr space. Tests use fakes on `PATH` with `make_fake`, as `tests/agent.bats` does.
- Do not send project code, secrets or environment values to any host.
- Keep all existing bats tests green. Keep `shellcheck` clean. Do not change any KDE row in `manifest/user.tsv` (`auspex check kde-untouched`).

## DONE WHEN

- `bats tests/fuzzel-terminal.bats tests/apply.bats`, `bin/auspex check theme` and `bin/auspex check --no-display` pass.
- `git grep -n ghostty -- config manifest templates` prints nothing.
- `git diff --name-only` of the branch shows only paths in **Own** (plus files that `auspex check skill --fix` generates).

## REPORT

- `horch ledger progress` after steps 1 and 2.
- The `horch ledger done` summary gives the fuzzel `terminal=` line, or says that none ships and why.
