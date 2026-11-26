# System steps

A system step is 1 system-tier change: packages, files under `/etc`, or the
boot. Only the operator applies it, with sudo. You write it and prepare it.

## File

`system/steps/NNN-<name>.sh`. Look at `system/steps/030-auspex-tools.sh` as
an example. The file has these header lines after the shebang:

```
# auspex:summary=<what the step does>
# auspex:args=check | apply | undo
# auspex:level=3
# auspex:requires-sudo=true
```

A step that installs a repo file adds 1 line per file:
`# auspex:installs=system/files/<path> /<absolute target>`.

It defines 3 functions:

| Function | Runs as | Must |
|---|---|---|
| `check` | the user | Exit 0 if the change is already in place. No sudo, no writes. |
| `apply` | root | Make the change. Record what it needs for undo. |
| `undo` | root | Reverse the change. |

## Rules

- Make `apply` safe to run twice.
- Install packages with `pacman -S --needed` and a list from `packages/`.
  Record the packages the step installed, so `undo` removes only those.
- Put copies of `/etc` files in `system/files/`.
- Never write under `/etc/sddm.conf.d/`, `/usr/share/sddm/` or
  `/usr/share/plasma/`. `auspex check system steps` fails on it.
- Never run sudo yourself.

## Flow

1. Write or edit the step.
2. `auspex check system steps`, then `auspex check shell`.
3. Commit.
4. `auspex system plan` lists pending steps, with their scripts and file
   diffs.
5. `auspex system prepare <step>` opens a pane to the right that runs
   `auspex system apply <step>`. Outside herdr it prints the command for the
   operator.
6. The operator reads the plan, answers the prompt and types the password.
7. After the step, `auspex status` shows whether steps are still pending.

To reverse a step, give the operator `auspex system undo <step>`.
