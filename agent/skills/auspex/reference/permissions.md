# Permission levels

Each command has a level in its `auspex:level` header line.
`reference/commands.md` lists the level of each command.

| Level | Who | Examples |
|---|---|---|
| 1 | The agent, with no prompt | Read files, edit the repo, commit, `auspex facts`, `auspex plan`, `auspex status`, `auspex check`, `auspex check theme`, `auspex system plan`, `auspex system prepare` |
| 2 | The agent, with an undo point | `auspex apply`, `auspex undo`, `auspex theme build` |
| 3 | The operator only | `auspex system apply`, `auspex system undo`, sudo, package installs, edits under `/etc`, `/usr` and `/boot` |

## Where the rules live

- `claude/agent-settings.json` holds the level 1 and 2 allow rules. Only the
  desktop agent session loads it.
- `claude/deny.json` holds the level 3 deny rules. auspex merges them into
  `~/.claude/settings.json`, so every Claude Code session gets them. It also
  owns the `theme` key (`custom:avgvr`). auspex undo puts back the old theme.
- `claude/headless-settings.json` holds read-only rules for headless runs.

## What to do at each level

- Level 1: do it.
- Level 2: do it, then tell the operator the generation number and how to
  undo it. `auspex theme build` makes no generation. It writes only repo
  files, so the undo point is git: commit its outputs or reset them.
- Level 3: never do it. Prepare it. For a system step, run
  `auspex system prepare <step>`. For anything else, print the exact command
  and ask the operator to run it.

## Managed targets

`Edit` and `Write` on a managed target are denied. Change the source in the
repo and apply it, so every change gets a generation. `auspex check permissions`
fails if a manifest row lacks its deny rules.

A Bash command that writes a target, such as `cp`, is not an `Edit` call.
It is still wrong. Do not do it.

## Changing a rule

The permission files are in the repo. A change is a normal commit plus
`auspex apply`. Do not add an allow rule for a level 3 action.
