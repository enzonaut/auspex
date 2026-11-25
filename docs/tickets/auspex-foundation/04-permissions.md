# 04 Permission files and the Claude settings merger

<!-- horch-ticket: 1 -->
**Persona:** primary `opus-hardening`
**Kind:** security
**Review:** full
**Check:** `bin/auspex check permissions`
**Own:** `claude/`, `lib/merge/claude-settings`, `bin/auspex-check-claude-settings`, `bin/auspex-check-permissions`, `manifest/user.tsv`, `tests/claude-settings.bats`, `tests/fixtures/claude/`
**Do not touch:** `~/.claude/settings.json`, `lib/merge/kglobalshortcuts`, `system/`, `~/.config/`

Spec: section 4, section 11 and 12 item 4. This is N2. OQ1 answer: no sandbox in this spec. The operator reviews the prompts after the 1-week tuning pass.

## Do

1. Write `claude/deny.json` with the level 3 deny rules of section 4.3.
2. Write `claude/agent-settings.json` with the level 1 and 2 allow rules. Write `claude/headless-settings.json` with read-only rules and no Edit or Write allow.
3. Add Edit and Write deny rules for each managed target. `bin/auspex check permissions --print` makes them from `manifest/user.tsv`.
4. Write `lib/merge/claude-settings` (section 4.2). It merges only deny rules into `~/.claude/settings.json`, records the rules it owns, keeps every other key, and removes a rule only if it owns it. A 2nd run changes nothing.
5. Add the 3 permission targets to `manifest/user.tsv`.
6. Write `auspex check claude-settings` and `auspex check permissions` with the checks of section 11. The merger test runs on a copy of the live settings file in a temp dir, and on fixtures. Never write the live file.

## Done when

- `bin/auspex check claude-settings` and `bin/auspex check permissions` pass.
- `git diff` shows no change to `~/.claude/settings.json`. The operator applies the merge with `auspex apply`.
