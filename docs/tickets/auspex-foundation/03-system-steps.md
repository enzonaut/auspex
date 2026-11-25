# 03 System steps runner and step 040-snapper-home-user

<!-- horch-ticket: 1 -->
**Persona:** primary `backend-developer`
**Kind:** security
**Review:** full
**Check:** `bin/auspex check system-steps`
**Own:** `bin/auspex-system-plan`, `bin/auspex-system-prepare`, `bin/auspex-system-apply`, `bin/auspex-system-undo`, `bin/auspex-check-system-steps`, `system/steps/040-snapper-home-user.sh`, `system/files/`, `tests/system-steps.bats`, `tests/fixtures/system/`
**Do not touch:** `system/steps/030-auspex-tools.sh`, `claude/`, `/etc/`, `/etc/sddm.conf.d/`, `~/.config/`

Spec: section 3.6, section 11 and 12 item 3. OQ3 answer: add step `040-snapper-home-user`. The operator runs it.

## Do

1. Write `auspex system plan`. It runs `check` of each step as the user, lists the pending steps, and prints each script and a diff for each file under `system/files/` that a step installs.
2. Write `auspex system prepare <step>`. In a herdr session it opens a split pane to the right and starts `auspex system apply <step>` in it. Outside herdr it prints the exact command.
3. Write `auspex system apply <step>` and `auspex system undo <step>`, both `auspex:level=3`. Each refuses with no TTY and refuses with `AUSPEX_ACTOR=agent`. Each shows the script and plan and asks `[y/N]`. On `y` it runs `sudo bash -c` with the step function. After the step it runs `check`, writes `system-steps/<step>.json`, and runs the `post-system-step` hooks. `--dry-run` prints and changes nothing.
4. Call `sudo` through `PATH`, so a test uses a fake `sudo`.
5. Write `system/steps/040-snapper-home-user.sh`. `apply` sets `ALLOW_USERS="lordvader"` in the snapper `home` config only. `check` reads the config with no sudo. `undo` restores the earlier value. Do not change the `root` config.
6. Write `auspex check system-steps` with the checks of the section 11 row.

## Operator step

Run `bin/auspex system prepare 040-snapper-home-user`. Send `OPERATOR:` to the orchestrator with the printed command. Do not run `auspex system apply`.

## Done when

- `bin/auspex check system-steps` passes. It covers steps 030 and 040.
- `bin/auspex check shell` passes.
