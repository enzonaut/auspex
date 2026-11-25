# 01 Layout, router, headers, test harness, tools step

<!-- horch-ticket: 1 -->
**Persona:** primary `backend-developer`
**Kind:** feature
**Review:** full
**Check:** `bin/auspex commands --check`
**Own:** `bin/auspex`, `bin/auspex-commands`, `bin/auspex-check`, `lib/common.sh`, `manifest/`, `tests/`, `themes/README.md`, `templates/README.md`, `packages/auspex-tools.list`, `system/steps/030-auspex-tools.sh`, `README.md`
**Do not touch:** `docs/specs/`, `~/.config/`, `/etc/`

Spec: `docs/specs/auspex-foundation.md`, sections 2.1, 2.2, 2.3, 3.6 (step 030), 11 (test seams) and 12 item 1.

## Do

1. Make the tree of section 2.1. Make each folder that a later ticket fills. Put a `.gitkeep` in an empty folder.
2. Write `bin/auspex`, the router of section 2.3. It uses the longest match: `auspex system apply 010` runs `auspex-system-apply 010`. `$AUSPEX` defaults to 1 level above `bin/auspex`, through symlinks. The `AUSPEX` variable overrides it.
3. Write `lib/common.sh`: paths, `AUSPEX_STATE` (default `~/.local/state/auspex`), logging, the lock, and hash helpers.
4. Write `bin/auspex-commands` with `--markdown` and `--check`. `--check` fails when a `bin/auspex-*` file is not executable, has no `# auspex:summary`, `# auspex:args`, `# auspex:level` or `# auspex:requires-sudo` header, or 2 commands route to the same words.
5. Write `bin/auspex-check`. It runs each `bin/auspex-check-<name>` and prints `skip` for a check that cannot run here. `--no-display` skips the display checks.
6. Write `manifest/user.tsv` with the header of section 2.2 and no targets.
7. Write the `tests/` harness: a bats helper that sets a temp `HOME`, a temp `AUSPEX_STATE`, and a fakes folder first on `PATH`.
8. Write `packages/auspex-tools.list` (`bats`, `shellcheck`, `jq`, `pacman-contrib`) and `system/steps/030-auspex-tools.sh` with `check`, `apply` and `undo`, `auspex:level=3` and `auspex:requires-sudo=true`. `apply` calls `pacman -S --needed` and records the packages it installed. `undo` removes only those.
9. Write `themes/README.md` and `templates/README.md`: "reserved for the theme spec".

## Operator step

The runner of ticket 03 does not exist yet. Print the exact command to install `packages/auspex-tools.list` and send it to the orchestrator with the tag `OPERATOR:`. The operator runs it once. Do not run sudo. Ticket 02 needs `bats` and `shellcheck`.

## Done when

- `bin/auspex commands --check` exits 0.
- `bin/auspex commands --markdown` lists every command.
- `bash -n` passes on every file in `bin/`, `lib/` and `system/steps/`.
