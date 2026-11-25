# 05 Machine facts

<!-- horch-ticket: 1 -->
**Persona:** primary `sonnet-feature`
**Kind:** feature
**Review:** light
**Check:** `bin/auspex check facts`
**Own:** `bin/auspex-facts`, `bin/auspex-check-facts`, `tests/facts.bats`, `tests/fixtures/facts/`
**Do not touch:** `lib/common.sh`, `claude/`, `system/`, `~/.config/`

Spec: section 5, section 11 and 12 item 5. This is N3.

## Do

1. Write `auspex facts` with the sections host, session, gpu, display, auspex, packages, services, journal and disk.
2. Add `--json`, `--logs` and `--section <name>`.
3. Give each section a 3 s limit. The full run finishes in under 5 s.
4. With no display, the display sections print `unavailable` and the command exits 0.
5. Call each external program through `PATH`, so tests use fakes.
6. Write `auspex check facts` with the checks of section 11.

## Done when

- `bin/auspex check facts` passes in a shell with no `WAYLAND_DISPLAY` and no `DISPLAY`.
- `bin/auspex commands --check` and `bin/auspex check shell` pass.
