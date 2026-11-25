# Map: auspex-foundation

Spec: `docs/specs/auspex-foundation.md`. The OQ1-OQ8 answers are in `ai_docs/plans/omarchy-research/decisions.md`, entry "Spec docs/specs/auspex-foundation.md open questions". The tickets apply them. Do not reopen them.

Rules for all tickets:

- No ticket runs sudo. A worker writes each system step and runs `auspex system prepare <step>`. The operator runs `auspex system apply <step>`.
- Every check runs without sudo and without a display, or the ticket says **Check:** none with the reason.
- The agent hotkeys are in 1 file: `config/agent-keys.conf` (ticket 08). A key change is 1 edit in that file. All other key files are made from it.
- From ticket 08 on, a ticket that adds a command or a manifest target runs `auspex check skill --fix` and commits the 2 generated skill files.
- The repo check at finish is `auspex check --no-display`. From ticket 02 on, the bats checks need `bats` and `shellcheck`. The operator installs them with step `030-auspex-tools` (ticket 01) before ticket 02 starts.

| Ticket | Depends |
|---|---|
| [01-layout-router](01-layout-router.md) | - |
| [02-apply-undo](02-apply-undo.md) | 01-layout-router |
| [03-system-steps](03-system-steps.md) | 02-apply-undo |
| [04-permissions](04-permissions.md) | 02-apply-undo |
| [05-facts](05-facts.md) | 01-layout-router |
| [06-skill](06-skill.md) | 03-system-steps, 04-permissions, 05-facts |
| [07-spike-kde-dropdown](07-spike-kde-dropdown.md) | 06-skill |
| [08-agent-kde-shortcuts](08-agent-kde-shortcuts.md) | 04-permissions, 07-spike-kde-dropdown |
| [09-update-timer](09-update-timer.md) | 08-agent-kde-shortcuts |
| [10-hyprland](10-hyprland.md) | 03-system-steps, 08-agent-kde-shortcuts |
| [11-gaming-checklist](11-gaming-checklist.md) | 10-hyprland |
