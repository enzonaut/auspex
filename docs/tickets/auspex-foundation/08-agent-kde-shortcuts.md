# 08 auspex agent, desktop files, the key file, KDE shortcuts

<!-- horch-ticket: 1 -->
**Persona:** primary `backend-developer`
**Kind:** feature
**Review:** full
**Check:** `bin/auspex check kde-shortcuts`
**Own:** `config/agent-keys.conf`, `bin/auspex-keys`, `bin/auspex-check-keys`, `bin/auspex-agent`, `bin/auspex-agent-dropdown`, `bin/auspex-check-agent`, `bin/auspex-check-kde-shortcuts`, `bin/auspex-check-kde-untouched`, `config/applications/`, `config/kde/agent-shortcuts.ini`, `config/ghostty/auspex-dropdown.ghostty`, `lib/merge/kglobalshortcuts`, `manifest/user.tsv`, `tests/agent.bats`, `tests/kde-shortcuts.bats`, `tests/fixtures/kde/`, `agent/skills/auspex/reference/commands.md`, `agent/skills/auspex/reference/targets.md`
**Do not touch:** `~/.config/kglobalshortcutsrc`, `~/.config/ghostty/config.ghostty`, `~/.config/plasma*`, `~/.config/kwinrc`, `claude/`, `config/hypr/`

Spec: sections 7.1, 7.2, 7.4, 10, 11 and 12 item 8. This is T5, and T2 on KDE. OQ5 answer: `Meta+Alt+A` for the agent window and `Meta+Alt+grave` for the dropdown, until the operator confirms them. OQ4 answer: use the dropdown method that ticket 07 wrote in `kde.md`.

## The key file

The agent keys are in 1 place: `config/agent-keys.conf`. A key change is 1 edit in this file.

```
# Agent hotkeys. Edit only this file. Then run: auspex keys render
AGENT_WINDOW=SUPER+ALT+A
AGENT_DROPDOWN=SUPER+ALT+grave
```

- `auspex keys render` makes `config/kde/agent-shortcuts.ini` from this file (`SUPER` becomes `Meta`, `grave` becomes `` ` ``). Ticket 10 adds the Hyprland output to the same command.
- Each made file starts with a comment that names `config/agent-keys.conf` as its source.
- `auspex check keys` fails when a made file differs from the output of `auspex keys render --print`.
- `auspex check kde-shortcuts` runs `auspex check keys` first.
- No other file holds a key value. Section 7.2 values go only into `config/agent-keys.conf`.

## Do

1. Write the key file, `bin/auspex-keys` (`render`, `render --print`) and `bin/auspex-check-keys`.
2. Write `auspex agent` with `--here`, `--window`, `--headless`, `--prompt`, `--cwd`, `--report` and `--dry-run` (section 7.1). Set `AUSPEX_ACTOR=agent`. Never pass `--dangerously-skip-permissions`.
3. Write `auspex agent dropdown` for KDE with the method from `kde.md`. If it is the quick terminal, write `config/ghostty/auspex-dropdown.ghostty`. If it is the KWin rule, toggle with `qdbus6`. On Hyprland it prints `skip` until ticket 10.
4. Write `config/applications/auspex-agent.desktop` and `auspex-agent-dropdown.desktop`.
5. Write `lib/merge/kglobalshortcuts` (section 7.4). It writes only the 2 `[services]` groups with `kwriteconfig6`, records the earlier values, and reloads with the command from `kde.md`. Undo writes the earlier values back or deletes the groups.
6. Add the targets to `manifest/user.tsv`.
7. Write `auspex check agent`, `auspex check kde-shortcuts` and `auspex check kde-untouched` (section 10). The merger tests use a fixture `kglobalshortcutsrc` in a temp `HOME` and a fake `kwriteconfig6`. They never write the live file. The conflict test reads the live file only.

## Operator step

The operator applies the targets with `auspex apply`, then presses each key once. If a game uses a key, the operator changes it in `config/agent-keys.conf`.

## Done when

- `bin/auspex check skill` passes. Run `bin/auspex check skill --fix` after you add a command or a target.

- `bin/auspex check keys`, `bin/auspex check agent`, `bin/auspex check kde-shortcuts` and `bin/auspex check kde-untouched` pass.
- `grep -rn 'Alt+A\|ALT+A' config/ bin/ lib/` finds the key only in `config/agent-keys.conf` and in the made files.
