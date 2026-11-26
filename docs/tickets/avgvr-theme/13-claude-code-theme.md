# 13 Claude Code theme avgvr

<!-- horch-ticket: 1 -->
**Persona:** primary `sonnet-feature`
**Kind:** feature
**Review:** full
**Blocked by:** 12-legio
**Check:** `bats tests/claude-settings.bats tests/apply.bats`
**Own:** `templates/claude/avgvr.json.tpl`, `lib/merge/claude-settings`, `claude/deny.json`, `manifest/user.tsv`, `bin/auspex-check-theme`, `bin/auspex-check-claude-settings`, `tests/claude-settings.bats`, `tests/fixtures/claude/`, `agent/skills/auspex/reference/targets.md`, `agent/skills/auspex/reference/permissions.md`
**Do not touch:** `~/.claude/settings.json`, `~/.claude/themes/`, `claude/agent-settings.json`, `claude/headless-settings.json`, `design/directions/c/`, `config/kde/`, `/usr/share/plasma/`, `/etc/sddm.conf.d/`, `~/.config/kdeglobals`, `~/.local/share/Steam/`, `~/.config/lutris/`, `~/.config/heroic/`

## GOAL

Claude Code has a custom theme `avgvr` rendered from the palette, and the `claude-settings` merger selects it when the OQ2 gate passes.

## CONTEXT

- Spec: `docs/specs/avgvr-theme.md` section 9.2 and 8.1 (row avgvr.json). Build order item 8.
- Decisions to apply (from `ai_docs/plans/avgvr-theme/decisions.md`):
  - 1 palette for boot, login, desktop, terminal and Claude Code.
  - OQ2: the Claude Code theme is gated by a test. Claude Code 2.1.332 must list `custom:avgvr` in `/theme` once the file exists. If it does not, keep only the `avgvr.json` row and do not add the `theme` key.
  - Q2: the accent `#EB6A43` is for alerts only. Here only `error` uses it.
- Key map (Omarchy `default/themed/claude.json.tpl`, at the Omarchy commit named in the foundation research): `claude` → `bronze`, `text` → `text`, `permission` → `gold`, `success` → `verdigris`, `error` → `accent`, inactive and subtle keys → `text_muted` and `text_faint`. Read the key set from the Omarchy repo copy on disk if one exists; else from the research report. Do not fetch it with project data attached.
- Row: `templates/claude/avgvr.json.tpl` → `~/.claude/themes/avgvr.json`, `render`, session `any`.
- Merger: 1 new owned top-level key `theme`. `claude/deny.json` gets `"theme": "custom:avgvr"`. The merger records the old value (`"dark"` today) and undo restores it. Other keys do not change.

## PRIOR WORK

Ticket 12 added LEGIO. The orchestrator adds the 12 summary here.

## STEPS

1. Write the template and the render row. Add to `auspex check theme`: the rendered JSON parses with `jq` and has every mapped key. Check: `bin/auspex check theme` passes.
2. The OQ2 gate, without changing the live settings: do not start `claude` to test it (it may need a login and it reads live state). Read the Claude Code 2.1.332 docs or `claude --help` for custom theme files under `~/.claude/themes/` and the `custom:<name>` value. If the docs confirm it, go on. If you cannot confirm it offline, send `QUESTION:` with what you found and end your turn. The operator then runs `/theme` live.
3. If the gate passes: add the `theme` key to the merger, to `claude/deny.json` and to `auspex check claude-settings`. Add bats cases: merge sets `custom:avgvr` and records `dark`; restore puts back `dark`; restore removes the key when it was absent; other keys stay. Check: `bats tests/claude-settings.bats` passes.
4. Update `targets.md` and `permissions.md`. Run `bin/auspex check skill --fix` and `bin/auspex check --no-display`.

## CONSTRAINTS

- Light system (operator decision 2026-11-26): the theme adds no resident process except `hyprpaper`. No new package beyond `plymouth`, `hyprpaper` and `ttf-jetbrains-mono`. If the work seems to need another package or a daemon, send `QUESTION:` and end your turn.
- Do not edit the live `~/.claude/settings.json` or `~/.claude/themes/`. Use fixtures.
- Warning: do not run `auspex apply`, `auspex undo`, `auspex system apply` or sudo. Tests use `AUSPEX`, `AUSPEX_STATE` and `HOME` in a temp folder.
- No test starts a real `herdr-app`, `hc`, `sddm-greeter` or `plymouthd`, or makes a herdr space. Tests use fakes on `PATH` with `make_fake`, as `tests/agent.bats` does.
- Do not send project code, secrets or environment values to any host.
- Keep all existing bats tests green. Keep `shellcheck` clean. Do not change any KDE row in `manifest/user.tsv` (`auspex check kde-untouched`).

## DONE WHEN

- `bats tests/claude-settings.bats tests/apply.bats`, `bin/auspex check theme` and `bin/auspex check --no-display` pass.
- `git diff --name-only` of the branch shows only paths in **Own** (plus files that `auspex check skill --fix` generates).

## REPORT

- `horch ledger progress` after steps 1 and 2.
- The `horch ledger done` summary gives the OQ2 gate result and its source.
