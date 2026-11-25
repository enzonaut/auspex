# 09 Weekly update check timer

<!-- horch-ticket: 1 -->
**Persona:** primary `sonnet-feature`
**Kind:** feature
**Review:** light
**Check:** `bin/auspex check timer`
**Own:** `systemd/user/`, `bin/auspex-update-check`, `bin/auspex-check-timer`, `manifest/user.tsv`, `tests/update-check.bats`, `tests/fixtures/update-check/`, `agent/skills/auspex/reference/commands.md`, `agent/skills/auspex/reference/targets.md`
**Do not touch:** `bin/auspex-agent`, `claude/`, `system/`, `~/.config/systemd/`

Spec: section 8, section 11 and 12 item 9. This is N4 part 1. Decision Q2: scheduled runs are read-only.

## Do

1. Write `systemd/user/auspex-update-check.service` and `.timer` with `OnCalendar=Sun 10:00`.
2. Write `auspex update check` with the flow of section 8. It uses `auspex agent --headless`, so it runs with `headless-settings.json` and cannot edit files. It writes the report under `reports/` and calls `notify-send --wait`.
3. Add `--dry-run`.
4. Add the 2 units to `manifest/user.tsv`.
5. Write `auspex check timer` with the checks of section 11. The bats test uses a fake `claude` and a fake `notify-send` on `PATH`.

## Done when

- `bin/auspex check skill` passes. Run `bin/auspex check skill --fix` after you add a command or a target.

- `bin/auspex check timer` passes.
- No step of the flow runs `pacman -Syu`, `yay`, or `sudo`.
