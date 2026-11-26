# 14 Skill page: how to change the theme

<!-- horch-ticket: 1 -->
**Persona:** primary `sonnet-sketch`
**Kind:** docs
**Review:** light
**Blocked by:** 13-claude-code-theme
**Check:** `bats tests/skill.bats`
**Own:** `agent/skills/auspex/reference/theme.md`, `agent/skills/auspex/SKILL.md`
**Do not touch:** `bin/`, `lib/`, `manifest/`, `templates/`, `themes/`, `system/`, `design/directions/c/`, `config/kde/`, `/usr/share/plasma/`, `/etc/sddm.conf.d/`, `~/.config/kdeglobals`, `~/.local/share/Steam/`, `~/.config/lutris/`, `~/.config/heroic/`

## GOAL

The auspex skill has a page `theme.md` that tells an agent how to change the AVGVR look safely.

## CONTEXT

- Spec: `docs/specs/avgvr-theme.md` build order item 9, sections 4, 10 and 12.
- Decisions to apply (from `ai_docs/plans/avgvr-theme/decisions.md`):
  - 1 palette for every stage. KDE Plasma stays unchanged. No change to game config.
  - The herdr app is the only terminal. ghostty is not used.
  - Light system: no new resident process except `hyprpaper`; no new package beyond `plymouth`, `hyprpaper` and `ttf-jetbrains-mono` without operator OK.
- The page covers:
  - Change a color: edit `themes/avgvr/colors.toml`, `auspex theme build`, `auspex plan`, `auspex apply`. If a root asset changed (SDDM or plymouth), the operator runs `auspex system apply 060 070` (and 080 only when the boot step changed).
  - Where each look lives: the template and target table (link `targets.md`).
  - The herdr app: the layout `avgvr` (`layout.switch avgvr`), the mod `avgvr-spaces`, the owned settings keys, never edit shipped herdr files. If the open app does not change its colors after apply, restart it (the checklist records the result).
  - The light rule, as above.
  - Recovery: `auspex undo`, `auspex system undo <step>`, the text console (Ctrl+Alt+F3), the KDE session.
- Read the ticket 01 to 13 summaries in PRIOR WORK and the real files. Write only what exists.

## PRIOR WORK

Tickets 01 to 13 built the theme. The orchestrator adds the 13 summary here.

## STEPS

1. Write `reference/theme.md` in Simplified Technical English, as the other reference pages are.
2. Add a route to `theme.md` in `SKILL.md`. Run `bin/auspex check skill --fix`. Check: `bats tests/skill.bats` passes.
3. Run `bin/auspex check --no-display`.

## CONSTRAINTS

- Light system (operator decision 2026-11-26): the theme adds no resident process except `hyprpaper`. No new package beyond `plymouth`, `hyprpaper` and `ttf-jetbrains-mono`. If the work seems to need another package or a daemon, send `QUESTION:` and end your turn.
- Docs only. No code change.
- Warning: do not run `auspex apply`, `auspex system apply` or sudo.
- Do not send project code, secrets or environment values to any host.

## DONE WHEN

- `bats tests/skill.bats` and `bin/auspex check --no-display` pass.
- Each command in `theme.md` exists in `bin/auspex` help.
- `git diff --name-only` of the branch shows only paths in **Own** (plus files that `auspex check skill --fix` generates).

## REPORT

- The `horch ledger done` summary lists the page sections.
