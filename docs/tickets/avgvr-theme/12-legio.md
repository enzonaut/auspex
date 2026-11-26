# 12 LEGIO fleet counter in waybar

<!-- horch-ticket: 1 -->
**Persona:** primary `sonnet-feature`
**Kind:** feature
**Review:** full
**Blocked by:** 11-herdr-hyprland-bind
**Check:** `bats tests/legio.bats`
**Own:** `bin/auspex-legio`, `config/waybar/config.jsonc`, `tests/legio.bats`, `tests/fixtures/legio/`, `agent/skills/auspex/reference/commands.md`
**Do not touch:** `templates/waybar/style.css.tpl`, `manifest/user.tsv`, `design/directions/c/`, `config/kde/`, `/usr/share/plasma/`, `/etc/sddm.conf.d/`, `~/.config/kdeglobals`, `~/.local/share/Steam/`, `~/.config/lutris/`, `~/.config/heroic/`

## GOAL

waybar shows `LEGIO [ N working · M blocked ]` from real herdr counts, and turns to the accent when M is above 0.

## CONTEXT

- Spec: `docs/specs/avgvr-theme.md` section 8.3 (custom/legio). Research report `docs/research/herdr-app-avgvr.md` item H10 (`hc ls --json` fields).
- Decisions to apply (from `ai_docs/plans/avgvr-theme/decisions.md`):
  - OQ9 revised: the counter shows real counts from `hc ls --json`.
  - Q2: the accent `#EB6A43` shows only for blocked. The `blocked` class gets the accent through the `#custom-legio.blocked` CSS rule from ticket 06.
  - Light system rule 4: `bin/auspex-legio` runs exactly 1 `hc` call and 1 `jq` call per run. waybar runs it at `interval` 5 s. No loop, no daemon, no cache file, no `sleep`.
- Module: `"custom/legio": { "exec": "auspex-legio", "return-type": "json", "interval": 5 }` in `modules-left` after the workspaces.
- Output: 1 JSON line `{"text": "LEGIO [ N working · M blocked ]", "class": "blocked"|"idle"}`. N = agents with state working. M = agents with state blocked. Class `blocked` when M > 0, else `idle`.
- Fallback: when `hc` is missing, fails, times out or gives bad JSON, print `{"text": "LEGIO [ – · – ]", "class": "idle"}` and exit 0. Put a short timeout on the `hc` call (`timeout 2`).
- Read only: the script never changes herdr state.

## PRIOR WORK

Ticket 11 added the herdr bind and autostart. Ticket 06 added waybar and the `#custom-legio` CSS. The orchestrator adds the 11 summary here.

## STEPS

1. Write `bin/auspex-legio` and `tests/legio.bats` with a fake `hc` that prints fixtures from `tests/fixtures/legio/` and counts its calls. Cases: 0 agents; working only; 1 blocked gives class `blocked`; missing `hc`; `hc` exit 1; bad JSON; exactly 1 `hc` call and 1 `jq` call per run (fake `jq` wrapper that counts and then runs the real `jq`). Check: `bats tests/legio.bats` passes.
2. Add the `custom/legio` module to `config/waybar/config.jsonc`. Check: `bin/auspex check theme` passes (the `jq` parse from ticket 06).
3. Update `commands.md` if `auspex-legio` is listed with the commands. Run `bin/auspex check skill --fix` and `bin/auspex check --no-display`.

## CONSTRAINTS

- Light system (operator decision 2026-11-26): the theme adds no resident process except `hyprpaper`. No new package beyond `plymouth`, `hyprpaper` and `ttf-jetbrains-mono`. If the work seems to need another package or a daemon, send `QUESTION:` and end your turn.
- Do not run the real `hc` from a test.
- Warning: do not run `auspex apply`, `auspex undo`, `auspex system apply` or sudo. Tests use `AUSPEX`, `AUSPEX_STATE` and `HOME` in a temp folder.
- No test starts a real `herdr-app`, `hc`, `sddm-greeter` or `plymouthd`, or makes a herdr space. Tests use fakes on `PATH` with `make_fake`, as `tests/agent.bats` does.
- Do not send project code, secrets or environment values to any host.
- Keep all existing bats tests green. Keep `shellcheck` clean. Do not change any KDE row in `manifest/user.tsv` (`auspex check kde-untouched`).

## DONE WHEN

- `bats tests/legio.bats` and `bin/auspex check --no-display` pass.
- `git diff --name-only` of the branch shows only paths in **Own** (plus files that `auspex check skill --fix` generates).

## REPORT

- `horch ledger progress` after step 1.
- The `horch ledger done` summary names the `hc ls --json` fields used for the state.
