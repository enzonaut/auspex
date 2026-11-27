---
name: auspex
description: Change this desktop through the auspex repo, on Hyprland or KDE Plasma. Use for any request about the look, keys or behavior of the desktop or its apps, such as "make the gaps smaller", "add a hotkey", "change my bar", "why is my game at 60 Hz", a monitor or refresh-rate question, a notification or launcher change, or a setting that must survive an update. Covers user-tier changes (auspex apply, with undo) and system-tier changes (a system step the operator applies with sudo).
---

# auspex

auspex manages this machine from the repo `~/repos/auspex`. The repo is the
source of truth. Every user-tier change is a numbered generation that
`auspex undo` can reverse. System-tier changes are system steps that only
the operator applies.

## Rules

1. Run `auspex facts` first. It prints the host, session, GPU, display,
   packages, services and disk as JSON. Add `--logs` only when the task is
   about an error.
2. Change files in `~/repos/auspex`, never the target. Find the source file
   of a target in `reference/targets.md`. A direct edit of a target is
   denied, and `auspex apply` reports it as drift.
3. Commit, then run `auspex plan`, then `auspex apply --reason "<request>"`.
   Tell the operator the generation number and that `auspex undo` reverses it.
4. For a system-tier change (packages, `/etc`, boot), write or edit a system
   step, commit it, and run `auspex system prepare <step>`. Never run sudo.
5. On KDE, change only the entries in `config/kde/`. For any other KDE
   setting, tell the operator which System Settings page to use.
6. If `auspex check skill` fails after a change to the repo layout, update the
   skill in the same commit.

## Workflow for a user-tier change

1. `auspex facts` to learn the session (`hyprland` or `kde`) and the state.
2. Find the source in `reference/targets.md`. If no row exists, add a source
   file under `config/` and a row to `manifest/user.tsv`.
3. Edit the source file in the repo.
4. `git -C ~/repos/auspex add <files>` and `git -C ~/repos/auspex commit`.
   Apply stops on uncommitted changes in a manifest source path.
5. `auspex plan`. Read the diff. If a target shows `drift`, stop and ask the
   operator. See `reference/apply-undo.md`.
6. `auspex apply --reason "<the request, in a few words>"`.
7. Report: the generation number, the changed targets, and the undo command.

## Workflow for a system-tier change

1. Write or edit `system/steps/NNN-<name>.sh` with `check`, `apply` and
   `undo` functions. See `reference/system-steps.md`.
2. Run `auspex check system steps` and commit.
3. `auspex system plan` shows the pending steps.
4. `auspex system prepare <step>` opens a pane for the operator. The operator
   reads the plan, answers the prompt and types the sudo password.

## When the request is unclear

- Ask which desktop the operator means if `auspex facts` shows a session
  other than the one the request names.
- Ask before a change that affects both desktops, such as a boot change.
- Do not guess a value the operator can see and you cannot, such as a color
  they like. Offer 2 or 3 choices.

## Undo

- `auspex undo` reverses the last generation that is not already undone.
- `auspex undo --to <n>` reverses each generation after `n`.
- An undo is itself a generation. `auspex undo` on an undo is a redo.
- `auspex status` prints the last generation and any drift.

## Checks

- `auspex check` runs every check. Run it before a commit that changes `bin/`,
  `lib/`, `manifest/` or the skill.
- `auspex check skill --fix` regenerates `reference/commands.md` and
  `reference/targets.md`. The other rules need an edit.

## Reference

| File | Content |
|---|---|
| `reference/layout.md` | The repo folders and the role of each |
| `reference/commands.md` | Every command, its arguments and level (generated) |
| `reference/targets.md` | Each managed target and its source (generated) |
| `reference/apply-undo.md` | Plan, apply, drift, undo and generations |
| `reference/permissions.md` | The 3 levels and what to do at each |
| `reference/hyprland.md` | Where Hyprland settings go, reload, window rules |
| `reference/kde.md` | What may change on KDE, and why so little |
| `reference/system-steps.md` | How to write and prepare a system step |
| `reference/theme.md` | The AVGVR theme: change a color, steps 050-080, the herdr app, recovery |
