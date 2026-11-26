# 16 AVGVR acceptance checklist

<!-- horch-ticket: 1 -->
**Persona:** primary `sonnet-sketch`
**Kind:** docs
**Review:** light
**Check:** none
**Own:** `docs/checklists/avgvr.md`
**Do not touch:** `bin/`, `lib/`, `config/`, `system/`, `claude/`, `templates/`, `themes/`, `tests/`, `manifest/`, `docs/checklists/hyprland-gaming.md`, `design/directions/c/`, `config/kde/`, `/usr/share/plasma/`, `/etc/sddm.conf.d/`, `~/.config/kdeglobals`, `~/.local/share/Steam/`, `~/.config/lutris/`, `~/.config/heroic/`

Check none: the file is an operator list. No command tests it. `bin/auspex check --no-display` still runs for the whole run.

## GOAL

`docs/checklists/avgvr.md` gives the operator every display, sudo and reboot step of the AVGVR theme, in order, with a Result column.

## CONTEXT

- Spec: `docs/specs/avgvr-theme.md` sections 6.4, 7.6, 10 and 12.2. The spec names the file `avgvr-acceptance.md`. Use `docs/checklists/avgvr.md`, as the operator named it.
- Format model: `docs/checklists/hyprland-gaming.md` (intro, `| # | Item | Result | Notes |` tables, `pass`, `fail` or `skip`, detail sections below).
- Decisions to apply (from `ai_docs/plans/avgvr-theme/decisions.md`):
  - KDE Plasma stays unchanged and is the fallback session. No change to game config.
  - OQ5: the SDDM greeter stays X11. OQ8: no SDDM fallback theme; recovery is test mode and the text console.
  - OQ12: the window rule ships with class `herdr-app`. The checklist confirms the class with `hyprctl clients -j` at the 1st Hyprland login. A mismatch is a 1-line fix ticket.
  - Q7: SUPER+Return starts or raises the herdr app. Q8: it starts on workspace I. Q6: the done sound is silent, the blocked sound plays.
  - OQ9: LEGIO shows the counts of `hc ls --json`.
  - OQ2: Claude Code `/theme` lists `custom:avgvr` (result of ticket 13).
  - Light system rule 5: the checklist measures idle RAM in the Hyprland session and compares it with KDE.
- Read the done summaries of tickets 02 to 13 in PRIOR WORK for the exact step names, operator commands and undo commands. Ticket 02, 03, 04 and 05 workers sent the step notes. Write only commands that exist.

## PRIOR WORK

Tickets 01 to 14 built the theme. The orchestrator adds the summaries and the operator notes of tickets 02 to 05 here.

## STEPS

1. Write the parts in this order:
   1. **Before you start**: an Arch install USB at hand (item 1 of the boot part, spec section 10); `auspex check --no-display` passes; the user tier is applied (ticket 15 generation).
   2. **System steps**, in order, each with its apply command (`auspex system plan <step>`, then `auspex system prepare <step>` and the sudo command it prints) and its undo command: 010 again (installs `hyprpaper`), 050 fonts, 060 SDDM, 070 plymouth, 080 boot splash.
   3. **Login**: SDDM test mode before 060 (`sddm-greeter-qt6 --test-mode --theme system/files/avgvr/sddm`) and after 060 (`--theme /usr/share/sddm/themes/avgvr`); log out; log in to Hyprland; log out; log in to Plasma; the session default is unchanged.
   4. **Boot**: `limine.conf` has no command line for the UKI; the plymouth preview after 070 (spec 7.6 item 2, with the console numbers of this machine); after 080: `sudo lsinitcpio /boot/EFI/Linux/arch-linux.efi | grep plymouth` and the `objcopy` command that shows `quiet splash`; 1 reboot.
   5. **Desktop**: wallpaper, borders, gaps, the band, `notify-send test`, the launcher, lock and unlock.
   6. **herdr app and Claude Code**: `hyprctl clients -j` class first (write it in Notes); `layout.switch avgvr` (ctrl-shift-l) 1 time; the theme, fonts, spaces row and bronze focus in both sessions; SUPER+Return starts and raises the app; after login the app is on workspace I; the done sound is silent and the blocked sound plays; the fuzzel terminal line (if ticket 07 shipped one); change 1 palette color, `auspex theme build`, `auspex apply`, and write whether the open app changes its colors (report N2); LEGIO shows the counts of `hc ls`; Claude Code `/theme` shows `custom:avgvr`.
   7. **Idle load (light system)**: after 2 min idle in Hyprland, record the total used RAM with `free -m` and the top 10 processes by RSS with `ps -eo pid,rss,comm --sort=-rss | head -11`. Then log in to Plasma, wait 2 min idle, and record the same. Put both in the Notes column. Also note the CPU % of the top processes from the same `ps` with `%cpu` added.
   8. **Recovery and fallback drill**: Ctrl+Alt+F3 text console; `hyprctl --instance 0 dispatch exec hyprlock` for a dead lock; `auspex undo`; the KDE session; undo 060 from the text console, `sudo systemctl restart sddm`, see the old greeter, then apply 060 again.
2. Check: every command in the file exists in `bin/auspex` help or in the spec; every step number exists under `system/steps/`.

## CONSTRAINTS

- Docs only. Write the commands. Do not run them.
- Warning: do not run `auspex apply`, `auspex system prepare`, `auspex system apply` or sudo.
- Write in Simplified Technical English.
- Do not send project code, secrets or environment values to any host.

## DONE WHEN

- `docs/checklists/avgvr.md` has the 8 parts in order, each item with an empty Result column.
- `git diff --name-only` of the branch shows only `docs/checklists/avgvr.md`.

## REPORT

- The `horch ledger done` summary gives the item count per part.
