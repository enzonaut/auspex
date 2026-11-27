# Audit of the arch-update skill

Date: 2026-11-27. Ticket: `docs/tickets/arch-update-audit/01-audit.md`.

- Skill source: `/home/lordvader/repos/dotfiles/link/.claude/skills/arch-update/SKILL.md` (193 lines).
- Proposal: `ai_docs/plans/arch-update-audit/SKILL.proposed.md` (268 lines).
- All commands in this audit were read-only.
- Result: 24 gaps. 14 are update-impact gaps (U1 to U14). 10 are uncovered
  surfaces (S1, S2, S3, S8, S9, S10, S11, S12, S14, S15). The rows S4, S5, S6, S7
  and S13 give scan evidence for a U row and are not counted again.

## Current skill

### What it checks

| Area | Command in the skill |
|---|---|
| Arch news | `yay -Pw` |
| Repo updates | `checkupdates` |
| AUR updates | `yay -Qua` |
| Flatpak updates | `flatpak remote-ls --updates` |
| herdr, hc, herdr-app | version flags only |
| Claude Code | `claude --version` |
| GE-Proton | GitHub release tag against the installed folders |
| Reboot pending | `uname -r` against `pacman -Q linux` |
| Config merges | `find /etc -name '*.pacnew' -o -name '*.pacsave'` |
| Snapshots | `pacman -Q snap-pac` |
| Last update | `/var/log/pacman.log` |
| Cleanup (1b) | pacman cache, orphans, yay cache, Flatpak runtimes, journal, Trash, crash dumps, old Claude builds |

### What it runs

After the operator says yes, the skill writes `~/.cache/arch-update/run.sh` and
starts it in a split pane to the right. The runner has these steps: `sudo -v`,
`yay --sudoloop`, `flatpak update -y`, `herdr update`, `hc update`,
`claude update`, then the sudo cleanup commands. A failed step stops the run. The
skill reads the pane with `hc read` and `hc wait`, and answers only the usual
`[Y/n]` prompts. After the run it does the gather checks again and lists the steps
that stay with the operator (`pacdiff`, ProtonUp-Qt, reboot).

### Safety rules

1. The skill never runs `yay`, `pacman -S*`, `sudo`, an updater or a snapper write
   through its own Bash tool. These run only in the split pane, after a yes.
2. The skill never asks for the password, never types it and never reads it.
3. No `--noconfirm`. No `reboot`. No `pacdiff` in the runner.
4. A "Never clean" list protects the shader caches, the snapshots and the game
   runtimes.
5. The only Bash-tool write is the cleanup of files that the user owns, after an
   explicit yes.

### What it does not know

The skill has no knowledge of auspex, the UKI and Limine boot chain, Hyprland,
the avgvr theme, horch, Claude Code plugins or the Node.js analyser. It still
names Ghostty. It has no mode for the weekly timer.

## Update impact

State of the machine: system steps 010 to 040 are applied. Steps 050 to 080
(branch `fleet/avgvr-theme`, PR #6) are not applied. The rows U3, U4 and U6 apply
after those steps.

| Code | An update of | What changes | What breaks | What the skill must check or run after |
|---|---|---|---|---|
| U1 | `linux`, `mkinitcpio`, `systemd`, `nvidia-open`, `intel-ucode`, `linux-firmware` | The pacman hook builds the UKI `/boot/EFI/Linux/arch-linux.efi` again with the drop-ins in `/etc/mkinitcpio.conf.d/` | A build error gives a UKI that does not boot. `/boot` is not readable without sudo, so the skill cannot look at the file | Read the pane log: `==> Unified kernel image generation successful` and no `==> ERROR`. If there is an error, tell the operator not to reboot |
| U2 | `mkinitcpio` (a `.pacnew` for `/etc/mkinitcpio.conf` or `/etc/mkinitcpio.d/linux.preset`) | The default HOOKS line or the preset changes | Step 080 writes a full HOOKS line in `auspex-plymouth.conf`. It becomes stale and hides new default hooks. A new preset can move the UKI path away from the Limine entry | Rank these `.pacnew` files first in the pacdiff step. Also `/etc/plymouth/plymouthd.conf`, `/etc/pacman.conf`, `/etc/sddm.conf.d/`, `/etc/snapper/configs/` |
| U3 | `plymouth` (after step 070) | Package files in `/usr/share/plymouth` and the plymouth hook | The avgvr theme folder is not owned by pacman. A changed hook or a reset `plymouthd.conf` removes the splash | `auspex system plan`. A step that was applied and is pending again shows the damage |
| U4 | `systemd`, `mkinitcpio`, manual edits (after step 080) | `/etc/kernel/cmdline` | Without `quiet splash` the boot shows text and no splash | `cat /etc/kernel/cmdline`, `auspex system plan` |
| U5 | `limine` | `/etc/pacman.d/hooks/99-limine.hook` copies `BOOTX64.EFI` to `/boot/EFI/BOOT/` | A failed copy keeps an old or a partial boot loader | Read the pane log: `Deploying Limine after upgrade...` with no error |
| U6 | `sddm`, `qt6-*`, `plasma-*` (after step 060) | The greeter, its QML modules and the breeze theme | The avgvr SDDM theme (not owned by pacman) can fail to load. Its fallback is `breeze/Main.qml`. hyprlock reads its mark from the theme folder | `auspex system plan`. Tell the operator to look at the greeter after the reboot. The reverse is `auspex system undo 060-avgvr-sddm` |
| U7 | `hyprland`, `hyprlock`, `hypridle`, `hyprpaper`, `waybar`, `mako`, `fuzzel`, `xdg-desktop-portal-hyprland` | Config syntax and options | An auspex template becomes invalid: config errors, an empty bar, no lock screen | `auspex check hyprland`, `hyprctl configerrors`, `auspex status` for drift. A new login is necessary |
| U8 | Any update | Files that auspex manages | The skill never runs an auspex command, so drift and a step that an update reverted are not seen | `auspex status` and `auspex system plan`, before and after the run |
| U9 | `herdr`, `hc`, `herdr-app` | The app binary, `herdr.d.ts`, `gpui-kit.d.ts`, possibly `settings.json` | A mod API change breaks an auspex mod. A rewrite of `settings.json` drops the avgvr theme and layout | `herdr-app status`, `herdr-app check <mod folder>`, `auspex status`. The skill text is also wrong: `herdr update` has no check-only option and herdr-app has no update command |
| U10 | `nodejs` (major version) | The Node.js ABI | Native modules in the analyser `node_modules` can fail to load | Flag a major bump in the report. After the run, check that `node_modules` is there |
| U11 | Claude Code plugins and marketplaces | The skill does not check them or update them. A plugin update makes a new cache folder with the version in its path | Plugins stay old. After an update the analyser `node_modules` are not in the new folder | Add `claude plugin list`, `claude plugin marketplace update` and `claude plugin update <plugin>`. Then check the analyser folder |
| U12 | `nvidia-utils`, `nvidia-open` | The host driver version | The Flatpak runtimes `GL.nvidia-620-70-06` and `GL32.nvidia-620-70-06` must have the same version, or Heroic has no GPU. `nvidia-power-limit.service` runs `nvidia-smi -pl 400` at boot | Put `flatpak update` in the same run. Compare the versions after the run. `systemctl --failed` |
| U13 | The reboot rule of the skill | The list lacks `mkinitcpio`, `limine`, `plymouth`, `intel-ucode`. There is no rule for a new login | The operator gets no instruction after an `sddm`, `hyprland`, `qt6-base` or `pipewire` update. "Notable" names Ghostty and not the Hyprland set | Longer reboot list, a new log-out rule, a new "Notable" list |
| U14 | `bin/auspex-update-check` (weekly timer) | It starts the skill with "Do only part 1 ... End your answer with 1 line that starts SUMMARY:" and later with "/arch-update Read <report>. Continue from the report." | The skill has no "part 1", no `SUMMARY:` line and no start from a report. The headless run can ask a question that nobody answers | Add the 2 modes to the skill |

## Uncovered surfaces

| Code | Surface | Evidence command | Result | Gap |
|---|---|---|---|---|
| S1 | ExpressVPN, installed outside pacman | `/opt/expressvpn/bin/expressvpnctl --version`; `pacman -Qo /etc/systemd/system/expressvpn-service.service` | `14.3.1+15429`; no package owns the unit; the unit is enabled | No update path and no version report |
| S2 | horch | `ls -la ~/.local/bin`; `horch --version`; `horch self-update --help` | `horch 0.5.3`; `self-update --check` only reports | Not checked, not updated |
| S3 | `herdr-install`, `herdr-fleet`, `herdr-run` | `ls -la ~/.local/bin` | 3 files next to herdr, not from pacman | The skill does not say which updater owns them |
| S4 | Claude plugin marketplaces (evidence for U11) | `cat ~/.claude/plugins/installed_plugins.json`; `claude plugin marketplace list` | `code-foundations@rtd` 6.8.2, `software@skill-marketplace` 1.0.0; 3 marketplaces | See U11 |
| S5 | Analyser `node_modules` (evidence for U10, U11) | `find ~/.claude/plugins -name node_modules -prune` | 2 folders below `cache/skill-marketplace/software/1.0.0/skills/complexity-sweep/code/` | See U10, U11 |
| S6 | Flatpak NVIDIA runtimes (evidence for U12) | `flatpak list`; `pacman -Q nvidia-open` | Runtimes `nvidia-620-70-06`; host `620.70.06-2` | See U12 |
| S7 | `nvidia-power-limit.service` (evidence for U12) | `systemctl list-unit-files --state=enabled`; `systemctl cat nvidia-power-limit.service` | Enabled, not owned by a package, `ExecStart=/usr/bin/nvidia-smi -pl 400` | See U12 |
| S8 | Mirrorlist | `stat -c %y /etc/pacman.d/mirrorlist`; `pacman -Q reflector` | Dated 2026-11-14; reflector is not installed | No age check. The list is new now |
| S9 | Firmware | `pacman -Q fwupd` | Not installed | The skill does not say that firmware is out of scope |
| S10 | `/boot` | `ls /boot` | Permission denied | The skill cannot verify the UKI or the Limine files. The pane log is the only evidence |
| S11 | Snapper | `pacman -Q snap-pac snapper`; `systemctl list-unit-files --state=enabled` | snap-pac 3.0.1-3, snapper 0.13.2-2, `snapper-cleanup.timer` and `snapper-timeline.timer` enabled | The row says "if missing, recommend installing". It does not check snapper or the cleanup timer |
| S12 | Ghostty | `pacman -Qqe`; `ls ~/.config/ghostty ~/.config/herdr` | The `ghostty` package and 2 old config folders are there. The operator does not use them | The skill reports Ghostty as notable. Removal is an operator decision (Q4) |
| S13 | `auspex-update-check.timer` (evidence for U14) | `systemctl --user list-unit-files --state=enabled`; `systemctl --user list-timers` | Enabled; next run Sunday 2026-11-29; no report folder yet | See U14 |
| S14 | Routine doc `~/docs/arch-docs/arch-update-routine.md` | `cat ~/docs/arch-docs/arch-update-routine.md` | Dated 2026-11-07. It names Ghostty and says that snap-pac and pacman-contrib are not installed | The skill points to a stale doc. The doc is outside this ticket (Q8) |
| S15 | Local tools from git repos and `yay-bin-debug` | `ls -la ~/.local/bin`; `pacman -Qm` | `auspex`, `herdrterm`, `media-import` are links to repos. `yay-bin-debug 13.1.0-1` is a foreign package | The skill does not say that these repos are out of scope |

Surfaces with no gap:

| Surface | Evidence command | Result |
|---|---|---|
| Other installers | `npm ls -g --depth=0`; `command -v cargo rustup pipx uv bun pnpm deno go`; `find ~ -maxdepth 3 -iname '*.AppImage'` | Only npm modules that pacman owns. No other tool. No AppImage |
| Foreign packages | `pacman -Qm` | brave-bin, google-chrome, yay-bin, yay-bin-debug: `yay` updates them |
| Flatpak apps | `flatpak list` | Heroic and ProtonUp-Qt: `flatpak update` covers them |
| Orphans | `pacman -Qdtq` | None |
| Pacman cache | `ls /var/cache/pacman/pkg \| wc -l`; `du -sh /var/cache/pacman/pkg` | 2238 files, 2.8G. Section 1b covers it |
| Old config files | `find /etc -name '*.pacnew' -o -name '*.pacsave'` | None |
| Claude Code builds | `ls ~/.local/share/claude/versions` | 2.1.325 and 2.1.332. Section 1b covers it |

## Changes

Each line is 1 change in `SKILL.proposed.md`, in file order, with its reason.

| Code | Change | Reason |
|---|---|---|
| C1 | `description`: adds horch, plugins, the boot chain, the auspex state and the check after the run | The description must match the new scope (U1, U8, U11, S2) |
| C2 | Never-run list: adds `horch self-update`, `horch update`, `claude plugin update`, `auspex apply`, `auspex system apply` | These commands change the system. They are new in the skill (U8, U11, S2) |
| C3 | New rule "Games" | The game configuration must not change. The skill had this only in the "Never clean" list |
| C4 | New block "Modes": part 1 only with a `SUMMARY:` line, and a start from a report file | U14, S13 |
| C5 | Flatpak row: names the NVIDIA GL runtimes | U12, S6 |
| C6 | herdr row: states that there is no check-only option | U9. `herdr update --help` shows none |
| C7 | herdr-app row: "It has no update command" | U9. `herdr-app` usage shows none |
| C8 | New row horch: `horch self-update --check` | S2 |
| C9 | New row Claude Code plugins: `claude plugin list` | U11, S4 |
| C10 | New row ExpressVPN: report the version only | S1 |
| C11 | Snapshots row: checks snap-pac, snapper and the cleanup timer | S11 |
| C12 | New row mirrorlist age | S8 |
| C13 | New row auspex state: `auspex status`, `auspex system plan` | U8 |
| C14 | New row failed units | U12, S7. It gives a baseline for the check after the run |
| C15 | "Never clean": adds `~/.claude/plugins`, `~/.config/herdr-app`, `~/.local/state/auspex` | U9, U11. A cleanup there deletes the analyser, the avgvr files or the auspex generations |
| C16 | New "Not checked" line: the user's own repos and firmware | S9, S15, S3 |
| C17 | Reboot rule: adds `intel-ucode`, `mkinitcpio`, `limine`, `plymouth` | U13 |
| C18 | New rule "Log out and in" | U13 |
| C19 | New rule "Boot chain" | U1, U2, U4, S10 |
| C20 | New rule "auspex": report drift, do not repair | U8. Repair is a job for the auspex skill |
| C21 | NVIDIA rule: adds the Flatpak runtime match | U12 |
| C22 | New rule "Desktop": the checks after the run are mandatory for these packages | U3, U6, U7 |
| C23 | New rule "Node.js" | U10, S5 |
| C24 | Report format: horch in "This week"; new "Notable" list without Ghostty; a line for auspex and failed units | U13, S12, U8 |
| C25 | Plan: adds the plugin update and `horch self-update`; moves `herdr update` to the end; adds the auspex step and "log out and in" to the operator list | U11, S2, U13. `horch update herdr` says that a herdr update can stop the server and close every pane, so it must be last (Q5) |
| C26 | Runner: the same new steps, the same order; "no `auspex` write command in the runner" | The same as C25. An auspex write needs its own plan and prompt |
| C27 | Watch table: new row for `==> ERROR:` and a failed pacman hook | U1, U5 |
| C28 | "After the run": adds horch to the version checks | S2 |
| C29 | "After the run": new table with 11 read-only checks (UKI, Limine, boot config, boot `.pacnew`, auspex system tier, auspex user tier, Hyprland config, herdr app, analyser, Flatpak NVIDIA runtime, failed units) | U1 to U12 |
| C30 | "After the run": the last paragraph adds the auspex step, the new login and the 3 items that only the operator can see | U3, U6, U12 |

Not changed: the frontmatter format, the password rule, the split-pane run
(sections 4a to 4c), section 1b, the news rule, the Discord rule, and the last
line with the reference doc.

## Open questions

| Code | Question | Proposal in the draft |
|---|---|---|
| Q1 | Who owns the weekly run: `auspex-update-check.timer` (Sunday), the manual `/arch-update`, or the 2 together? | The draft supports the 2 together |
| Q2 | Do you want `fwupd` for firmware and `reflector` for the mirrorlist? | No. The draft only reports the mirrorlist age after 6 months |
| Q3 | How do you update ExpressVPN (14.3.1)? Must the skill do more than report the version? | Report only |
| Q4 | Do you want to remove the `ghostty` package and the old folders `~/.config/ghostty` and `~/.config/herdr`? | Not in the skill. This is a single manual job |
| Q5 | Is it correct that `herdr update` and `horch self-update` run in the split pane? `herdr update` can restart the server and close panes. `horch self-update` during a fleet run can break the run | `herdr update` is the last step. `horch self-update` runs only when no fleet run is active |
| Q6 | The draft runs `auspex status`, `auspex system plan` and `auspex check hyprland` (all level 1, read-only) through Bash. Is this permitted? | Yes |
| Q7 | Do plugin updates belong in the weekly run? What is the command that installs the analyser `node_modules` again after a plugin update? | Yes, they are in the run. The draft only reports a missing `node_modules` |
| Q8 | The routine doc `~/docs/arch-docs/arch-update-routine.md` is stale. Update it, or remove the reference line from the skill? | The line stays. The doc is not changed |
| Q9 | `agent/skills/auspex/reference/system-steps.md` on main says "Never write under `/etc/sddm.conf.d/`, `/usr/share/sddm/`". Step 060 writes there. Does PR #6 change this rule? | No change in this ticket |
