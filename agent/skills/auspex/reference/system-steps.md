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

A step that reads repo files adds 1 line that names each of them:
`# auspex:reads=packages/avgvr.list system/files/avgvr/SHA256SUMS`.
The step reads a declared file at `${AUSPEX_READS_DIR:-$AUSPEX_REPO}/<path>`.
`auspex check system steps` fails when a step names a `packages/`,
`system/files/` or `config/` path that is not in its reads line or under a
declared `SHA256SUMS` dir.

## Binary files

To install binary files, such as fonts, list them in a `SHA256SUMS` file,
declare that file in the reads line, and call `step_install_verified` in
`apply`:

```
step_install_verified system/files/avgvr/SHA256SUMS system/files/avgvr/fonts "$dest"
```

It copies each file of `<repo dir>` that `SHA256SUMS` lists to a temp dir and
checks its sha256. Only when all files match does it install them with mode
644, and print each target path, 1 per line. Record those paths, so `undo`
removes only them. On any bad hash or missing file it installs nothing and
returns 1. Look at `system/steps/050-avgvr-fonts.sh` as an example.

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
  `/usr/share/plasma/`. `auspex check system steps` fails on it. The one
  exception is step `060-avgvr-sddm`. It writes only
  `/etc/sddm.conf.d/zz-auspex-avgvr.conf` and the theme dir
  `/usr/share/sddm/themes/avgvr` (through `avgvr.new`). It never writes into
  the breeze theme, and it does not restart SDDM. To preview the theme, give
  the operator `sddm-greeter-qt6 --test-mode --theme <dir>`. Never run it
  yourself.
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

## Boot splash recovery

Steps `070-avgvr-plymouth` and `080-avgvr-boot-splash` change the boot.
Undo 080 before 070. The undo of 070 refuses while the 080 drop-in
`/etc/mkinitcpio.conf.d/auspex-plymouth.conf` exists.

| Failure | What the operator sees | Recovery |
|---|---|---|
| 070 theme error | plymouth shows its text splash | `auspex system undo 070` |
| 080 splash does not show, or shows late | a black screen until SDDM | Press Esc during boot to see the text log. The boot continues. `auspex system undo 080` |
| 080 `mkinitcpio -P` fails | the step reports an error | none needed. The step restores the drop-in and `/etc/kernel/cmdline`, then runs `mkinitcpio -P` again. |
| 080 the new UKI does not boot | Limine shows an error | There is no 2nd Limine entry and no fallback UKI. Tell the operator to have an Arch install USB before 080. From the USB, chroot into the system and run `auspex system undo 080`. Or remove the drop-in and the words `quiet splash` from `/etc/kernel/cmdline` by hand, then run `mkinitcpio -P`. |
