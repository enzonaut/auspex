# Repo layout

The repo is `~/repos/auspex`. `$AUSPEX` points to it. Edit files here, never
the live targets in `$HOME`.

| Folder | Role |
|---|---|
| `agent/` | This skill, in `agent/skills/auspex/`. `auspex apply` installs it to `~/.claude/skills/auspex/`. |
| `bin/` | The commands. `bin/auspex` is the router. Each `bin/auspex-<words>` file is 1 command with header lines (summary, args, level, requires-sudo). |
| `claude/` | Claude Code permission files. `claude/deny.json` holds level 3 deny rules. `claude/agent-settings.json` holds level 1 and 2 allow rules. |
| `config/` | Repo copies of user-tier targets, 1 folder per app: `config/hypr/`, `config/waybar/`, `config/browser-flags/`, `config/kde/`, `config/applications/`. |
| `design/` | Visual design work for the theme spec. Not installed anywhere. |
| `docs/` | Specs, tickets, research and design notes. Not installed anywhere. |
| `hooks/` | Scripts that run after an event, in `hooks/post-apply.d/`, `hooks/post-undo.d/` and `hooks/post-system-step.d/`. |
| `lib/` | Shared shell code. `lib/common.sh` has paths, logging, locking, the manifest reader and generations. `lib/merge/` has 1 merger per merge-mode target. |
| `manifest/` | `manifest/user.tsv` lists each managed user-tier target. |
| `migrations/` | One-time user-tier scripts, named `<unix-ts>-<slug>.sh`. `auspex apply` runs pending ones. |
| `packages/` | Package lists, 1 name per line, that system steps install. |
| `system/` | System-tier changes. `system/steps/` holds the steps. `system/files/` holds copies of `/etc` files that steps install. |
| `systemd/` | User units, in `systemd/user/`. |
| `templates/` | Reserved for the theme spec. |
| `tests/` | bats tests and fixtures. |
| `themes/` | Reserved for the theme spec. |

## Manifest rows

`manifest/user.tsv` has 4 tab-separated columns: source, target, mode,
session.

- `copy`: auspex writes the whole target file.
- `tree`: `copy` for each file in a source folder.
- `merge:<name>`: auspex owns only some entries in a target that other
  programs also write. `lib/merge/<name>` does the work.
- The session column is `any`, `hyprland` or `kde`. It does not limit apply.

To manage a new file: add the source under `config/<app>/`, add a row, commit,
then apply. A `copy` target that already exists makes apply stop. Ask the
operator, then use `auspex apply --adopt <target>`.

A new row also needs `Edit` and `Write` deny rules in `claude/deny.json`.
`auspex check permissions --print` prints them.
