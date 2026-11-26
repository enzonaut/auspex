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

| Ticket | Persona | Depends |
|---|---|---|
| [01 Palette, renderer, render mode, theme-set](01-renderer.md) | opus | none |
| [02 Theme build, fonts, step 050](02-theme-build-fonts.md) | opus | 01 |
| [03 SDDM login, step 060](03-sddm.md) | opus | 02 |
| [04 plymouth boot, steps 070 and 080](04-plymouth-boot.md) | opus | 03 |
| [05 Hyprland look and hyprpaper](05-hyprland.md) | sonnet-feature | 04 |
| [06 waybar band](06-waybar.md) | sonnet-feature | 05 |
| [07 mako, fuzzel, hyprlock; remove ghostty](07-mako-fuzzel-hyprlock.md) | sonnet-feature | 06 |
| [08 herdr theme, settings merger, fonts, silent sound](08-herdr-theme-settings.md) | sonnet-feature | 07 |
| [09 herdr layout avgvr](09-herdr-layout.md) | sonnet-feature | 08 |
| [10 herdr mod avgvr-spaces](10-herdr-spaces-mod.md) | sonnet-feature | 09 |
| [11 SUPER+Return, autostart, window rule](11-herdr-hyprland-bind.md) | sonnet-feature | 10 |
| [12 LEGIO counter](12-legio.md) | sonnet-feature | 11 |
| [13 Claude Code theme](13-claude-code-theme.md) | sonnet-feature | 12 |
| [14 Skill page theme.md](14-skill-page.md) | sonnet-sketch | 13 |
| [15 Apply the user tier](15-apply-user-tier.md) | opus | 14 |
| [16 Acceptance checklist](16-checklist.md) | sonnet-sketch | 14 |
