# 15 Apply the AVGVR user tier

<!-- horch-ticket: 1 -->
**Persona:** primary `opus`
**Kind:** feature
**Review:** none
**Check:** none
**Own:** `docs/apply-log.md`
**Do not touch:** `bin/`, `lib/`, `config/`, `system/`, `claude/`, `templates/`, `themes/`, `tests/`, `manifest/`, `design/directions/c/`, `config/kde/`, `/usr/share/plasma/`, `/etc/sddm.conf.d/`, `~/.config/kdeglobals`, `~/.local/share/Steam/`, `~/.config/lutris/`, `~/.config/heroic/`

Check none: this task changes the live user tier. The evidence is the auspex generation and the commands below.

## GOAL

The live user tier runs the AVGVR generation, and `docs/apply-log.md` records it.

## CONTEXT

- This is the only ticket that runs `auspex apply`. The operator approved this apply in the plan decisions ("Build the AVGVR theme and apply it").
- Decisions to apply (from `ai_docs/plans/avgvr-theme/decisions.md`):
  - KDE Plasma stays unchanged. No change to game config (Steam, Lutris, Heroic, Proton, Wine).
  - Q11: the herdr app rows (session `any`) apply in both sessions. KDE desktop rows do not change.
  - Light system: no new resident process except `hyprpaper`.
- The system tier (steps 010, 050, 060, 070, 080) is not part of this ticket. The operator applies it from the checklist (ticket 16).
- Model: `docs/tickets/foundation-finish/03-apply-kde.md`.

## PRIOR WORK

Tickets 01 to 14 built the theme. The orchestrator adds the 14 summary here.

## STEPS

1. Run `git -C /home/lordvader/repos/auspex status` and `git -C /home/lordvader/repos/auspex log --oneline -20`. The checkout must hold the landed commits of tickets 01 to 14. If not, send `BLOCKED:` and stop.
2. Run `auspex check --no-display` from the main checkout. It must pass. If not, send `BLOCKED:` with the output.
3. Run `auspex plan`. Expected targets only: the `render` and `copy` rows of tickets 05 to 13 (`~/.config/hypr/`, `~/.config/waybar/`, `~/.config/mako/`, `~/.config/fuzzel/`, `~/.local/share/auspex/wallpaper/`, `~/.config/herdr-app/`, `~/.claude/themes/avgvr.json`, `~/.claude/settings.json`), and the removed ghostty target if one is live.
4. Warning: if the plan shows drift, a target outside that list, a KDE file (section 11.1 of the spec) or any path under Steam, Lutris, Heroic, Wine, Proton or a game folder, do not apply. Send `BLOCKED:` with the plan output.
5. Run `auspex apply --reason "AVGVR user tier"`.
6. Run `auspex status`. Record the generation number. Confirm the `theme-set` hooks ran or printed a warning. Do not start or restart any app.
7. Add 1 row to `docs/apply-log.md`: date, generation, reason, commit. Commit it with the message "Record AVGVR user tier apply".

## CONSTRAINTS

- Do not run `auspex system apply`, `auspex system prepare` or sudo. Do not press keys. Do not switch the herdr layout.
- Do not run `auspex undo` unless apply fails half way. Then send `BLOCKED:` with the output first and wait.
- Do not send project code, secrets or environment values to any host.

## DONE WHEN

- `auspex status` shows a new generation with apply ok.
- `docs/apply-log.md` has the new row, committed.

## REPORT

- The `horch ledger done` summary names the generation number and the count of changed targets.
