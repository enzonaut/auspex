# 02 Apply, plan, undo, status, generations, migrations, hooks

<!-- horch-ticket: 1 -->
**Persona:** primary `backend-developer`
**Kind:** feature
**Review:** full
**Check:** `bin/auspex check apply`
**Own:** `bin/auspex-apply`, `bin/auspex-plan`, `bin/auspex-undo`, `bin/auspex-status`, `bin/auspex-migrate`, `bin/auspex-check-apply`, `bin/auspex-check-shell`, `lib/common.sh`, `migrations/`, `hooks/`, `tests/apply.bats`, `tests/migrate.bats`, `tests/hooks.bats`, `tests/fixtures/apply/`
**Do not touch:** `bin/auspex`, `bin/auspex-commands`, `manifest/user.tsv`, `system/`, `claude/`, `~/.config/`, `/etc/`

Spec: sections 2.4, 2.5, 3.1 to 3.5, 11 and 12 item 2. This is the N1 user tier.

## Do

1. Write `auspex plan` and `auspex apply` with the 11 steps of section 3.3. Include drift stop, `--adopt`, `--force`, the atomic write, rollback on a failed apply, and `--dry-run`.
2. Write the generations of section 3.2: `generations/NNNN/{meta.json,before/,after.sha256}`, the `owned/` list, and `.absent` markers. Keep the last 50 generations.
3. Write `auspex undo` with `--to <n>` and `--force`. An undo of an undo is a redo.
4. Write `auspex status`.
5. Write `auspex migrate` and the migration runner of section 2.4. A migration runs once and writes a marker. A failed migration stops apply.
6. Write the hook runner of section 2.5: `post-apply.d/`, `post-undo.d/`, `post-system-step.d/`. Hooks run in name order and get `$1`. A failed hook is a warning.
7. Write `auspex check apply` (runs `bats tests/apply.bats`) and `auspex check shell` (shellcheck on `bin/`, `lib/`, `migrations/`, `system/steps/`, `hooks/`).
8. All tests use a temp `HOME` and a temp `AUSPEX_STATE`. No test writes under the real `~/.config` or `~/.local/state`.

## Done when

- `bin/auspex check apply`, `bats tests/migrate.bats` and `bats tests/hooks.bats` pass.
- `bin/auspex check shell` and `bin/auspex commands --check` pass.

If `bats` or `shellcheck` is missing, send `BLOCKED:` and name step `030-auspex-tools`. Do not install them.
