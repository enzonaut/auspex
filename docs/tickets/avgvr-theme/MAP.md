# Map: avgvr-theme

Spec: `docs/specs/avgvr-theme.md`. Decisions: `ai_docs/plans/avgvr-theme/decisions.md` (each ticket copies the decisions it needs).

Rules for all tickets:

- No ticket runs `auspex apply`, `auspex undo`, `auspex system prepare`, `auspex system apply` or sudo. The 1 exception: ticket 15 runs `auspex apply` for the user tier. The operator applies the system steps from the checklist (ticket 16).
- No test starts a real `herdr-app`, `hc`, `sddm-greeter` or `plymouthd`, or makes a herdr space. Tests use fakes, as `tests/agent.bats` does.
- No change to KDE files or to game config. Every ticket has `~/.local/share/Steam/`, `~/.config/lutris/` and `~/.config/heroic/` in Do not touch.
- Light system (operator decision 2026-11-26):
  1. The theme adds no resident process except `hyprpaper`.
  2. No new package beyond `plymouth`, `hyprpaper` and `ttf-jetbrains-mono` without operator OK.
  3. The plymouth theme is a static image plus a stepped fill, with no per-frame image sequence (ticket 04).
  4. `bin/auspex-legio` runs 1 `hc` call and 1 `jq` call per run, at interval 5 s (ticket 12).
  5. The checklist records idle RAM and the top 10 processes by RSS in Hyprland and in KDE (ticket 16).
- The herdr app is the only terminal. ghostty is removed (ticket 07).
- Do not send project code, secrets or environment values to any host.
- The run check is `bin/auspex check --no-display`. A ticket has its own Check only when it needs a narrower one.

The tickets form 1 chain, because most of them share `manifest/user.tsv`, `claude/deny.json`, `bin/auspex-check-theme` and the generated skill files. Ticket 16 shares no file with 15 and can run beside it.

| Ticket | Depends |
|---|---|
| [01-renderer](01-renderer.md) | - |
| [02-theme-build-fonts](02-theme-build-fonts.md) | 01-renderer |
| [03-sddm](03-sddm.md) | 02-theme-build-fonts |
| [04-plymouth-boot](04-plymouth-boot.md) | 03-sddm |
| [05-hyprland](05-hyprland.md) | 04-plymouth-boot |
| [06-waybar](06-waybar.md) | 05-hyprland |
| [07-mako-fuzzel-hyprlock](07-mako-fuzzel-hyprlock.md) | 06-waybar |
| [08-herdr-theme-settings](08-herdr-theme-settings.md) | 07-mako-fuzzel-hyprlock |
| [09-herdr-layout](09-herdr-layout.md) | 08-herdr-theme-settings |
| [10-herdr-spaces-mod](10-herdr-spaces-mod.md) | 09-herdr-layout |
| [11-herdr-hyprland-bind](11-herdr-hyprland-bind.md) | 10-herdr-spaces-mod |
| [12-legio](12-legio.md) | 11-herdr-hyprland-bind |
| [13-claude-code-theme](13-claude-code-theme.md) | 12-legio |
| [14-skill-page](14-skill-page.md) | 13-claude-code-theme |
| [15-apply-user-tier](15-apply-user-tier.md) | 14-skill-page |
| [16-checklist](16-checklist.md) | 14-skill-page |
