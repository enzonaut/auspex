# 06 The auspex skill and its staleness check

<!-- horch-ticket: 1 -->
**Persona:** primary `backend-developer`
**Kind:** docs
**Review:** light
**Check:** `bin/auspex check skill`
**Own:** `agent/skills/auspex/`, `bin/auspex-check-skill`, `manifest/user.tsv`, `tests/skill.bats`
**Do not touch:** `claude/`, `system/`, `~/.claude/skills/`

Spec: section 6, section 11 and 12 item 6. This is T1.

## Do

1. Write `agent/skills/auspex/SKILL.md` with `name` and `description` front matter, under 150 lines, with the content of section 6.2.
2. Write `reference/layout.md`, `apply-undo.md`, `permissions.md`, `hyprland.md`, `kde.md` and `system-steps.md`.
3. Generate `reference/commands.md` from `auspex commands --markdown` and `reference/targets.md` from `auspex check skill --print-targets`.
4. Write `auspex check skill` with rules 1 to 6 of section 6.3, plus `--fix` and `--print-targets`.
5. Add the skill folder as a target in `manifest/user.tsv`.

## Done when

- `bin/auspex check skill` passes.
- `bin/auspex check skill --fix` then `git diff --exit-code` shows no change.
