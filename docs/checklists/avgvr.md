# AVGVR acceptance checklist

This checklist is for the operator. Spec: `docs/specs/avgvr-theme.md`, sections 6.4, 7.6, 10 and 12.2.

Write `pass`, `fail`, or `skip` in the Result column. Write a note when the result is not `pass`.

Warning: run the sudo commands only at a TTY or in the pane that `auspex system prepare` opens. Do not run a step before the item that names it.

KDE Plasma does not change. It is the fallback session. Do not change game config to make an item pass.

The numbers of the Ctrl+Alt+F keys are for this machine: F3 is the text console. F1 or F2 returns to the session. Write the key that works in the Notes column of item 3.1.

## Part 1: Before you start

| # | Item | Result | Notes |
|---|---|---|---|
| 1.1 | An Arch install USB is at hand. It boots on this machine. Limine has no 2nd entry, so this USB is the recovery for step 080. | | |
| 1.2 | `bin/auspex check --no-display` passes. | | |
| 1.3 | The user tier is applied (ticket 15 generation). `auspex status` shows the last generation and no pending migration. | | |
| 1.4 | `auspex theme build` ran. `auspex check theme` passes. | | |

## Part 2: System steps

Run the steps in this order. For each step: run `auspex system plan`, then `auspex system prepare <step>`. Run the sudo command that the pane prints. The undo command is in the Notes column.

| # | Item | Result | Notes |
|---|---|---|---|
| 2.1 | Step `010-hyprland-packages` again. It installs `hyprpaper`. Command: `auspex system prepare 010-hyprland-packages`. `command -v hyprpaper` prints a path. | | Undo: `auspex system undo 010-hyprland-packages` |
| 2.2 | Step `050-avgvr-fonts`. Command: `auspex system prepare 050-avgvr-fonts`. `fc-list \| grep -i jost` and `fc-list \| grep -i jetbrains` print a line each. | | Undo: `auspex system undo 050-avgvr-fonts` |
| 2.3 | Step `060-avgvr-sddm`. Do it after item 3.1 and before item 3.2. Command: `auspex system prepare 060-avgvr-sddm`. SDDM does not restart. | | Undo: `auspex system undo 060-avgvr-sddm` |
| 2.4 | Step `070-avgvr-plymouth`. Command: `auspex system prepare 070-avgvr-plymouth`. `plymouth-set-default-theme` prints `avgvr`. | | Undo: `auspex system undo 070-avgvr-plymouth` |
| 2.5 | Step `080-avgvr-boot-splash`. Do it after item 4.2. Item 1.1 must be `pass`. Command: `auspex system prepare 080-avgvr-boot-splash`. The step does not stop at a guard. | | Undo: `auspex system undo 080-avgvr-boot-splash` |

## Part 3: Login

| # | Item | Result | Notes |
|---|---|---|---|
| 3.1 | Before step 060, in a running session: `sddm-greeter-qt6 --test-mode --theme system/files/avgvr/sddm`. The greeter opens in a window. The layout, the focus, the Tab order and the session list are correct. A login in test mode does not log in. | | |
| 3.2 | After step 060: `sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/avgvr`. The result is the same as item 3.1. | | |
| 3.3 | Log out. The real greeter is the AVGVR greeter. It shows "Hyprland" and "Plasma (Wayland)". | | |
| 3.4 | Log in to Hyprland. The session starts. | | |
| 3.5 | Log out of Hyprland. The greeter shows again. | | |
| 3.6 | Log in to Plasma. Plasma works as before. | | |
| 3.7 | The session default is unchanged. The greeter pre-selects the same session as before step 060. | | |

## Part 4: Boot

| # | Item | Result | Notes |
|---|---|---|---|
| 4.1 | Not verified before: the Limine conf format (`/boot` needs root). `/boot/limine.conf` (or the file that `auspex system plan` names for Limine) has no `cmdline:` or `kernel_cmdline:` line for `arch-linux.efi`. Command: `sudo grep -n cmdline /boot/limine.conf /boot/limine/limine.conf /boot/EFI/limine/limine.conf /boot/EFI/BOOT/limine.conf`. | | |
| 4.2 | After step 070, plymouth preview from the text console (Ctrl+Alt+F3, logged in): see the commands below. The splash shows the fill and the numerals, then the password band. | | |
| 4.3 | After step 080 and before the reboot: `sudo lsinitcpio /boot/EFI/Linux/arch-linux.efi \| grep plymouth` prints the plymouth files. | | |
| 4.4 | After step 080 and before the reboot: `sudo objcopy -O binary --only-section=.cmdline /boot/EFI/Linux/arch-linux.efi /dev/stdout` prints `quiet splash`. | | |
| 4.5 | Reboot 1 time. Limine shows, then the plymouth AVGVR splash, then the AVGVR greeter. A short delay before the splash is expected on NVIDIA. | | |

Item 4.2 commands:

```
sudo plymouthd
sudo plymouth show-splash
for p in 0 10 20 30 40 50 60 70 80 90 100; do sudo plymouth system-update --progress=$p; sleep 1; done
sudo plymouth ask-for-password --prompt=test
sudo plymouth quit
```

Ctrl+Alt+F1 or F2 returns to the session.

## Part 5: Desktop

Do these in the Hyprland session.

| # | Item | Result | Notes |
|---|---|---|---|
| 5.1 | The wallpaper shows (hyprpaper). Not verified before: the `~` paths in `hyprpaper.conf`. If the wallpaper does not show, write it in the Notes column. The fix is to use the `home` key. | | |
| 5.2 | The borders are 1 px bronze. | | |
| 5.3 | The gaps are as in the spec. | | |
| 5.4 | The waybar band shows. The text uses the AVGVR fonts. Not verified before: the repeating-linear-gradient in the live bar. | | |
| 5.5 | `notify-send test` shows a mako notification in the AVGVR style. | | |
| 5.6 | The launcher (fuzzel) opens. It is in the AVGVR style. | | |
| 5.7 | Step 060 must be applied first, because hyprlock reads `/usr/share/sddm/themes/avgvr/mark.png`. Lock with the lock key. The hyprlock band shows with the mark. | | |
| 5.8 | Unlock with the password. The session returns. | | |

## Part 6: herdr app and Claude Code

| # | Item | Result | Notes |
|---|---|---|---|
| 6.1 | Start the app. Run `hyprctl clients -j`. Write the `class` of the app window in the Notes column. It must be `herdr-app`. A mismatch is a 1-line fix ticket for the window rule. | | |
| 6.2 | Select the layout 1 time: `layout.switch avgvr` (ctrl-shift-l). | | |
| 6.3 | Hyprland session: the app shows the AVGVR theme, the fonts, the spaces row and the bronze focus outline. | | |
| 6.4 | Plasma session: the same as item 6.3. | | |
| 6.5 | SUPER+Return starts the app when it does not run. | | |
| 6.6 | SUPER+Return raises the app when it runs. | | |
| 6.7 | After login, the app is on workspace I. | | |
| 6.8 | The `done` sound is silent. The `blocked` sound plays. | | |
| 6.9 | No fuzzel `terminal=` line ships, because `tab.new --argv` needs a JSON array. Write `skip`. | | |
| 6.10 | Change 1 palette color. Run `auspex theme build`, then `auspex apply`. Write in the Notes column if the open app changes its colors (report N2). If it does not change, restart the app. | | |
| 6.11 | LEGIO in the bar shows the same counts as `hc ls --json`. | | |
| 6.12 | In Claude Code, `/theme` lists `custom:avgvr`. | | |

Undo for the user tier: `auspex undo`.

## Part 7: Idle load (light system)

Measure RAM and CPU in Hyprland first, then in Plasma. Put the output in the Notes column.

| # | Item | Result | Notes |
|---|---|---|---|
| 7.1 | Hyprland, after 2 min idle: `free -m`. Write the used RAM in MB. | | |
| 7.2 | Hyprland, same time: `ps -eo pid,rss,%cpu,comm --sort=-rss \| head -11`. Write the top 10 processes by RSS with the CPU %. | | |
| 7.3 | Log in to Plasma. After 2 min idle: `free -m`. Write the used RAM in MB. | | |
| 7.4 | Plasma, same time: `ps -eo pid,rss,%cpu,comm --sort=-rss \| head -11`. Write the top 10 processes. | | |
| 7.5 | Compare items 7.1 and 7.3. Hyprland uses less RAM than Plasma. Write the difference in MB. | | |

## Part 8: Recovery and fallback drill

| # | Item | Result | Notes |
|---|---|---|---|
| 8.1 | In the Hyprland session, press Ctrl+Alt+F3. The text console shows. Log in. Ctrl+Alt+F1 or F2 returns to the session. | | |
| 8.2 | Dead lock: from the text console, run `hyprctl --instance 0 dispatch exec hyprlock`. The lock screen returns on the session. | | |
| 8.3 | Run `auspex undo`. The user tier returns to the generation before. Run `auspex apply` after the item to get the theme back. | | |
| 8.4 | Log in to Plasma. Plasma works. It is the fallback session. | | |
| 8.5 | From the text console, run `auspex system undo 060-avgvr-sddm`, then `sudo systemctl restart sddm`. The old greeter shows. | | |
| 8.6 | Run step 060 again: `auspex system prepare 060-avgvr-sddm`. Log out. The AVGVR greeter shows. | | |

Undo order: undo 080 before 070. Step 070 undo refuses while the 080 drop-in exists.

Recovery notes:

1. If the AVGVR greeter shows an error or the built-in theme, use item 8.5.
2. To use breeze instead, write this in `/etc/sddm.conf.d/zz-auspex-avgvr.conf`: `Current=breeze`.
3. If the splash does not show, press Esc during boot to see the log. Boot continues. Run `auspex system undo 080-avgvr-boot-splash`.
4. If the new UKI does not boot, boot the Arch USB, chroot, and run `auspex system undo 080-avgvr-boot-splash`. Or remove `/etc/mkinitcpio.conf.d/auspex-plymouth.conf` and the words `quiet splash` from `/etc/kernel/cmdline`, then run `mkinitcpio -P`.

## Not verified live

No one tested these on a live display before. Check each one with care:

- hyprpaper `~` paths (item 5.1). Fix: use the `home` key.
- waybar gradient and bar (item 5.4).
- mako (notification item in part 5).
- fuzzel (launcher item in part 5).
- hyprlock (item 5.7). Apply step 060 first.
- Window class `herdr-app` (part 6). A mismatch is a 1-line fix ticket.
- LEGIO with a live herdr (part 6).
- Claude Code theme `custom:avgvr` (part 6).
- The Limine conf guard (item 4.1 and step 080). The guard refuses a missing cmdline file or one without exactly 1 line. It does not guard a preset `*_cmdline`.
