# Plan, apply and undo

## Plan

`auspex plan` is a dry run. For each managed target it prints 1 state:

| State | Meaning |
|---|---|
| `unchanged` | The target already matches the repo. |
| `create` | The target does not exist. Apply writes it. |
| `update` | The target differs from the repo. A diff follows. |
| `drift` | The target changed outside auspex since the last apply. A diff follows. |
| `remove` | The repo no longer has the target. Apply removes it. |

## Apply

`auspex apply --reason "<request>"` does these steps:

1. Takes a lock. Only 1 apply or undo runs at a time.
2. Stops if a manifest source path has uncommitted changes. Commit first.
3. Builds the plan. Stops on `drift`. Stops if nothing changes.
4. Saves the earlier content of each changed target in a new generation
   folder under `~/.local/state/auspex/generations/`.
5. Writes each target atomically.
6. Runs pending migrations, then the hooks in `hooks/post-apply.d/`. If a
   `render` target changed, it then runs the hooks in `hooks/theme-set.d/`.
7. Prints the generation number and the changed targets.

If a write fails, apply restores the earlier content and exits non-zero.

## Render targets

A manifest row with mode `render` has a template under `templates/` as its
source. Plan, apply and status render the template
with the palette `themes/<name>/colors.toml`. The file `themes/current`
contains `<name>`. The syntax is in `templates/README.md`. The palette keys are
in `themes/README.md`.

- To change a color on all render targets, edit the palette, commit it and run
  `auspex apply`. 1 generation changes all the render targets. 1 `auspex undo`
  restores all of them.
- A render error stops plan and apply before they write a target. The error
  gives the file and the line.
- A render row acts as a `copy` row for drift and undo. When a row changes from
  `copy` to `render` and the rendered file is the same, it is not drift.
- `auspex apply --adopt` refuses a render target. Edit the template or the
  palette, or run `auspex apply --force`.
- The `theme-set` hooks get the generation number as `$1`. `10-waybar` sends
  `SIGUSR2` to waybar when `style.css` changed. `20-hyprpaper` runs
  `hyprctl hyprpaper reload` when the wallpaper or `hyprpaper.conf` changed.

## Drift

Drift means someone changed a target outside auspex. Do not overwrite it on
your own. Show the operator the diff and offer 2 choices:

- `auspex apply --adopt <target>` copies the live file into the repo source.
  Then commit it. This does not work for a `merge` or a `render` target.
- `auspex apply --force` overwrites the live file with the repo version.

## Undo

- `auspex undo` reverses the last generation that is not already undone.
- `auspex undo --to <n>` reverses each generation after `n`, newest first.
- Undo stops if a target changed after the generation wrote it.
  `--force` overrides. Ask the operator first.
- Undo is a generation of kind `undo`. `auspex undo` on it is a redo.
- Undo touches only managed targets.
- Undo runs the `post-undo` hooks. If a `render` target changed, it then runs
  the `theme-set` hooks.

## Status

`auspex status` prints the repo commit, the last generation, pending
migrations, pending system steps and targets with drift.

## What to tell the operator

After an apply, say: the generation number, the targets that changed, and
"run `auspex undo` to reverse it". After an undo, say which generation it
reversed.
