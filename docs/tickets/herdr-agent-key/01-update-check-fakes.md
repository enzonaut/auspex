# Handoff: agent hotkey in the herdr app, dropdown removed

Operator decision (2026-11-25): Super+Alt+A shows the agent in the herdr app
(option A: one reused space). The dropdown key (Super+Alt+`) is removed on
both desktops.

## State

Committed on fleet/foundation as d08663f:

- bin/auspex-agent: --window now drives herdr-app. Space "auspex agent":
  makes it (space.new) when absent, focuses a live claude-code terminal
  (agent.focus), or opens a new tab when Claude ended or --prompt is given.
- Dropdown removed: bin/auspex-agent-dropdown, bin/auspex-check-dropdown,
  config/applications/auspex-agent-dropdown.desktop,
  config/ghostty/auspex-dropdown.ghostty, AGENT_DROPDOWN in
  config/agent-keys.conf, the auspex-keys renderer, manifest row, deny rules,
  the special:agent window rule and its check row, kde-untouched count 3->2.
- Tests updated: tests/agent.bats, tests/hyprland.bats, tests/kde-shortcuts.bats.
- Skill refs (kde.md, hyprland.md, layout.md) and generated commands/targets
  updated; spec section 7 updated.
- shellcheck and agent/hyprland/kde-shortcuts bats pass.

## Your task

1. tests/update-check.bats still fakes `ghostty`. It now runs the REAL
   herdr-app (it made a stray space in the operator's app and hung the full
   check for about 1 h). Fake herdr-app, hc and setsid like `fake_herdr` in
   tests/agent.bats. Assert on the herdr-app call that carries
   `--prompt /arch-update Read ...`, and that a dismissed notification makes
   no herdr-app call. Grep every test and check for any other path that can
   reach a real herdr-app, hc or setsid, and fake it.
2. Make bin/auspex-agent safe in tests: no test may start a real herdr-app.
3. Branch fleet/foundation-T10-11 (gaming checklist, not merged) mentions the
   dropdown. Do not edit that branch; list the lines in your DONE summary.
4. Do not run `auspex apply` or touch the live desktop. The orchestrator
   applies after this lands.

**Check:** `bin/auspex check --no-display`. It must finish in under 15 min
and leave no new space in `herdr-app ls`.
