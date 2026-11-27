---
name: arch-update
description: Weekly Arch Linux update check for this machine. Use when the user runs /arch-update or asks what needs updating. Checks Arch news, pending pacman/AUR/Flatpak updates, herdr (cli, core, app), horch, Claude Code and its plugins, GE-Proton, .pacnew files, the boot chain (UKI, Limine), the auspex state, reboot need and cleanup, reports what applies this week, then on the user's go-ahead runs the update commands in a split pane to the right (herdr-app), tells the user when that pane needs their password, and checks the auspex desktop after the run. Never runs updates or sudo through its own Bash tool, never sees or types the password.
---

# Arch weekly update check

Gather facts read-only, report, then - after an explicit yes - run this week's
commands in a split pane to the right of this one (section 4). The user watches
them there and types their password there when sudo asks.

**Never run through your own Bash tool**: `yay` (without -P/-Q flags), `pacman -S*`,
`sudo`, `herdr update`, `flatpak update`, `claude update`, `hc update`,
`horch self-update`, `horch update`, `claude plugin update`, `auspex apply`,
`auspex system apply`, `snapper` writes, or anything else that modifies the system.
Those only ever run in the split pane, after the user said yes to the list. The one
Bash-tool exception is the user-owned cleanup in 1b after an explicit yes.

**Password**: never ask for it in chat, never type it into the pane, never try to
read it. The user types it in the split.

**Games**: never change a file under `~/.local/share/Steam`, `~/.config/lutris`,
`~/.config/heroic` or a Wine prefix.

**Modes**: `auspex update check` (weekly timer) starts this skill in 2 other ways.

- The prompt says "Do only part 1": do sections 1, 1b, 2 and 3. Do not ask a
  question. Do not do section 4. End the answer with 1 line that starts `SUMMARY:`
  (counts, reboot yes/no, news yes/no).
- The prompt names a report file: read it, rerun only `checkupdates` and
  `yay -Qua`, tell the user what changed since the report, then ask the question
  of section 3.

## 1. Gather (run these in parallel where possible)

| Check | Command |
|---|---|
| Arch news (last ~5) | `yay -Pw` |
| Pending repo updates | `checkupdates` (from pacman-contrib; exit 2 = none). If missing, say so and recommend `sudo pacman -S pacman-contrib` |
| Pending AUR updates | `yay -Qua` |
| Pending Flatpak updates | `flatpak remote-ls --updates --columns=application,version` (Heroic, ProtonUp-Qt, the NVIDIA GL runtimes; empty = none) |
| herdr version | `herdr --version`. `herdr update` has no check-only option: always recommend `herdr update` |
| herdr-core (`hc`) | `hc --version`. Separate binary with its own updater: recommend `hc update` (terminals keep running) |
| herdr-app | `herdr-app --version` (in `~/.local/share/herdr-app`). It has no update command; if `herdr update` doesn't bump it, tell the user and check the herdr docs |
| horch | `horch --version` and `horch self-update --check` (read-only; says if a newer release is out) |
| Claude Code | `claude --version`. `autoUpdates` is false in `~/.claude.json`, so it never self-updates: always recommend `claude update` (it says "up to date" if nothing to do) |
| Claude Code plugins | `claude plugin list` (names and versions). No check-only command: recommend the 2 plugin lines of the plan |
| GE-Proton | latest: `curl -s https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest \| jq -r .tag_name`; installed: `ls ~/.local/share/Steam/compatibilitytools.d ~/.local/share/lutris/runners/wine`. If newer, recommend updating in ProtonUp-Qt (GUI) |
| ExpressVPN | `/opt/expressvpn/bin/expressvpnctl --version`. Not a pacman package: report the version only. The user updates it with the vendor installer |
| Reboot already pending? | compare `uname -r` with `pacman -Q linux` (normalize `-arch` vs `.arch`) |
| Unmerged configs | `find /etc -name '*.pacnew' -o -name '*.pacsave' 2>/dev/null` |
| Snapshots on update | `pacman -Q snap-pac snapper` and `systemctl is-enabled snapper-cleanup.timer` (if one is missing, tell the user before the update) |
| Last update | `grep -E 'starting full system upgrade' /var/log/pacman.log \| tail -1` |
| Mirrorlist age | `stat -c %y /etc/pacman.d/mirrorlist` (only if older than 6 months: tell the user) |
| auspex state | `auspex status` (drift, pending system steps) and `auspex system plan` |
| Failed units | `systemctl --failed --no-legend` and `systemctl --user --failed --no-legend` |
| Cleanup | see section 1b |

## 1b. Cleanup scan (read-only)

| Item | Measure (dry run) | Clean command | Who runs it |
|---|---|---|---|
| Old pacman packages | `paccache -dk2` and `paccache -duk0` (uninstalled pkgs) | `sudo paccache -rk2 && sudo paccache -ruk0` | split pane |
| Orphans | `pacman -Qdtq` (list names, not just a count) | `sudo pacman -Rns <the names you listed>` | split pane, only after the user okays the names |
| AUR build cache | `du -sh ~/.cache/yay` | `rm -rf ~/.cache/yay/*` | Claude, after yes |
| Unused Flatpak runtimes | `echo n \| flatpak uninstall --unused` | `flatpak uninstall --unused -y` | split pane (polkit window may pop up) |
| Journal | `journalctl --disk-usage` (only if > 500M) | `sudo journalctl --vacuum-size=200M` | split pane |
| Trash | `du -sh ~/.local/share/Trash` (only if > 200M) | empty in Dolphin, or `rm -rf ~/.local/share/Trash/{files,info}/*` | Claude, after yes |
| Crash dumps | `du -sh /var/lib/systemd/coredump` | `sudo rm /var/lib/systemd/coredump/*` | split pane |
| Old Claude Code builds | `ls ~/.local/share/claude/versions` + `du -sh` (only if > 2 versions) | `rm` all but the current (`readlink ~/.local/bin/claude`) and the newest older one | Claude, after yes |

**Never clean**: `~/.cache/mesa_shader_cache`, `~/.cache/nvidia`, Steam `shadercache`
(rebuilding causes game stutter), browser caches, `/tmp` (tmpfs, cleared on reboot),
snapper snapshots, Lutris runtimes/runners (`~/.local/share/lutris`), `~/.local/share/umu`, Steam/ProtonUp-Qt compat tools,
`~/.claude/plugins`, `~/.config/herdr-app`, `~/.local/state/auspex`. Keep 2 pacman versions (not 0) so downgrades stay possible.

Skip the Cleanup section of the report if total reclaimable is under ~300 MB.

**Not checked (self-updating):** Lutris runtimes (dxvk, vkd3d, umu) and Heroic's own
wine/proton update themselves on launch. Games from launchers are out of scope.

**Not checked (the user's own repos):** `auspex`, `herdrterm` and `media-import` in
`~/.local/bin` are links to git repos. Firmware: `fwupd` is not installed.

## 2. Decide

- **News**: any post newer than the last full upgrade that mentions manual
  intervention, or names a package in the pending list, comes FIRST, with its
  required step quoted. Older news: ignore.
- **Reboot needed after updating** if pending updates include `linux`, `linux-firmware`,
  `intel-ucode`, `mkinitcpio`, `limine`, `plymouth`, `mesa`, `systemd`, `nvidia*`
  (incl. `nvidia-prime`), `glibc`, or core Plasma (`plasma-workspace`, `kwin`).
- **Log out and in after updating** (no reboot) if pending updates include `hyprland`,
  `xdg-desktop-portal-hyprland`, `sddm`, `qt6-base`, `qt6-declarative`, `pipewire` or
  `wireplumber`.
- **Boot chain**: this machine boots a UKI (`/boot/EFI/Linux/arch-linux.efi`) through
  Limine. `/boot` is not readable without sudo, so the pane log is the evidence. If
  `linux`, `mkinitcpio`, `systemd`, `plymouth`, `nvidia-open` or `intel-ucode` is
  pending, the run must show a UKI build without `==> ERROR` (section 4c). The
  auspex drop-ins in `/etc/mkinitcpio.conf.d/` (`auspex-nvidia.conf`,
  `auspex-plymouth.conf`) and `quiet splash` in `/etc/kernel/cmdline` must stay.
- **auspex**: if `auspex status` shows drift or a pending system step before the
  update, say so in the report. Do not repair it here; that is a job for the auspex
  skill.
- **NVIDIA**: `nvidia-open` must match the `linux` kernel and `lib32-nvidia-utils` must match
  `nvidia-utils`. If only some of these are pending (e.g. kernel bumped but not
  nvidia-open), warn and suggest waiting a day rather than a partial update.
  This is a hybrid-graphics laptop (`nvidia-prime`), so NVIDIA breakage can show up only
  in games launched with `prime-run`. The Flatpak runtimes
  `org.freedesktop.Platform.GL.nvidia-*` and `GL32.nvidia-*` must match `nvidia-utils`:
  if `nvidia-utils` is pending, put `flatpak update` in the plan, or Heroic loses
  the GPU.
- **Desktop**: if `sddm`, `qt6-*`, `plymouth`, `hyprland`, `hyprlock`, `hypridle`,
  `hyprpaper`, `waybar`, `mako` or `fuzzel` is pending, the auspex checks in "After
  the run" are mandatory. A major or minor bump of one of these can make an auspex
  template or the avgvr theme invalid.
- **Node.js**: if `nodejs` has a major-version bump, the complexity-sweep analyser
  (`~/.claude/plugins/cache/skill-marketplace/software/*/skills/complexity-sweep/code/`)
  can need a new `node_modules`. Say so in the report.
- **Discord**: if `discord` is pending or was just updated and Discord says "update
  available" and won't start, the fix is `"SKIP_HOST_UPDATE": true` in
  `~/.config/discord/settings.json` (Claude can add it after a yes).
- **Big jumps**: flag anything with a major-version bump (e.g. 6.x -> 7.x) and say
  what might change.
- If nothing is pending and no news, say "Nothing to do this week" and stop.

## 3. Report

Keep it short. Format:

```
## This week
<1-2 lines: N repo updates, M AUR, F Flatpak, herdr/hc/app/horch + Claude Code versions, GE-Proton status, reboot yes/no, any news>

## Notable
- <only packages worth knowing about: kernel, mkinitcpio, limine, plymouth, sddm, Hyprland and its tools (hyprlock, hypridle, hyprpaper, waybar, mako, fuzzel), KDE, Brave, Chrome, Discord, Bitwarden/electron, NVIDIA, Steam/wine-staging/gamescope/gamemode/mangohud, Lutris, github-cli, nodejs, big bumps>
- <auspex: drift or pending system steps, failed units, only if there are some>

## Cleanup (≈X GB reclaimable)
- <item: size, one line each; orphan names listed>

## Plan
In the split (I run these, you type the password):
1. yay
2. flatpak update      (only if Flatpak updates pending)
3. hc update
4. claude update
5. claude plugin marketplace update, then claude plugin update <each plugin>
6. horch self-update   (only if a newer release is out and no fleet run is active)
7. <sudo cleanup commands from 1b, only those with something to clean>
8. herdr update        (last: it can restart the herdr server)

Yours, afterwards:
- <manual news step, if any - this one comes BEFORE the split run>
- sudo pacdiff         (only if .pacnew found or expected)
- <ProtonUp-Qt: install GE-Proton X, only if newer>
- <auspex system prepare <step>, only if a system step is pending after the run>
- log out and in       (only if needed)
- reboot               (only if needed)
```

Only list steps that apply this week. If there are user-owned cleanups (yay cache,
Trash, old Claude builds), ask "Want me to clear <items> (≈X GB) now?" and on an explicit yes run only
those `rm` commands, then report the freed space with `du -sh`.

End the report with one question: "Run the plan in a split now?" Do nothing in
section 4 until the user says yes. If a news post needs a manual step first, or the
NVIDIA check says wait, say so and do not offer the run until that is settled.

## 4. Run in a split pane (only after yes)

This machine uses herdr-app with herdr-core (`hc`); the old `herdr pane ...` CLI has
no server running. If `$HC_TERMINAL_ID` is empty or `herdr-app ls` fails, you are not
in the app: give the user the list to run themselves and skip to "After the run".

**a. Write the runner** to `~/.cache/arch-update/run.sh` (mkdir -p; overwrite each
week), with only this week's steps, in plan order:

```bash
#!/usr/bin/env bash
step() {
  printf '\n=== STEP: %s ===\n' "$*"
  "$@" || { printf '\n=== ARCH-UPDATE FAILED: %s (rc=%s) ===\n' "$*" "$?"; exec bash; }
}
step sudo -v                       # asks for the password once, up front
step yay --sudoloop --answerclean None --answerdiff None
step flatpak update -y
step hc update
step claude update
step claude plugin marketplace update
step claude plugin update software@skill-marketplace   # 1 line per plugin of `claude plugin list`
step horch self-update             # only if `--check` found a newer release
step sudo paccache -rk2            # cleanup lines only when 1b found something
step herdr update                  # last
printf '\n=== ARCH-UPDATE DONE ===\n'
exec bash                          # leave a shell so the pane stays readable
```

No `--noconfirm` on yay or pacman: it answers conflict and replacement questions
blindly. No `reboot`, no `pacdiff` (interactive merge, the user's job), no `auspex`
write command in the runner.
A failed step stops the run, so nothing later runs on a half-updated system.

**b. Open the split** to the right of your own pane:

```bash
me=$(herdr-app ls | jq -r --arg t "$HC_TERMINAL_ID" \
  '.spaces[].tabs[].terminals[] | select(.terminal==$t) | .pane')
herdr-app do pane.split --direction right --pane "$me" \
  --argv "[\"bash\",\"$HOME/.cache/arch-update/run.sh\"]"
```

It prints `{"pane": "...", "terminal": "tNN"}`; keep both. Focus moves to the new
pane by itself, which is what you want: the first thing in it is the sudo prompt.
Tell the user right away, in one line: **"Type your password in the right pane."**

**c. Watch it.** hc does not flag a password prompt as `blocked`, so read the screen:

```bash
hc read tNN --lines 30 | grep -v '^\s*$' | tail -n 12
hc wait tNN --timeout 20        # the pause between reads; never a bare sleep
```

Keep each Bash call short (one read, one wait of at most ~20 s) and loop; do not sit
in one long blocking call. Act on the last non-empty lines:

| The pane shows | Do |
|---|---|
| `[sudo] password for` / `Password:` (again, later in the run) | `herdr-app do pane.focus --terminal tNN`, tell the user "the right pane needs your password", keep polling until it moves on |
| `:: Proceed with installation? [Y/n]` or `:: Proceed with upgrade? [Y/n]` | `hc keys tNN enter` |
| yay asking about packages to clean-build or diffs to show | `hc keys tNN enter` (None) |
| Anything else that waits for an answer: replace X with Y, remove a conflicting package, pick a provider, import a PGP key, `[y/N]` questions, a merge prompt | stop, quote the question to the user, answer only what they tell you with `hc send` / `hc keys` |
| A polkit window (flatpak) | nothing to do in the pane; tell the user to answer the popup |
| `==> ERROR:` from mkinitcpio, or `error: command failed to execute correctly` from a pacman hook | let the run finish, then tell the user: **do not reboot**. Quote the lines. The UKI can be broken |
| `=== ARCH-UPDATE FAILED: ... ===` | read more history (`--lines 200`), explain the error, do not retry on your own |
| `=== ARCH-UPDATE DONE ===` | go to "After the run" |

Output that keeps moving (downloads, builds, DKMS, mkinitcpio) needs no comment;
say something only when a step changes or it needs the user. Leave the pane open at
the end, the user closes it.

## After the run

Rerun `checkupdates`, the flatpak check, the herdr/hc/herdr-app/horch/claude version
checks, the `.pacnew` find and the `uname -r` vs `pacman -Q linux` check, scan the
pane history for `warning:` / `error:` lines, and confirm what's left. Then do these
checks. All of them are read-only.

| Check | Command | If it fails |
|---|---|---|
| UKI build (only if the run built one) | pane history (`--lines 400`): `==> Unified kernel image generation successful`, no `==> ERROR` | tell the user not to reboot; quote the error |
| Limine (only if `limine` updated) | pane history: `Deploying Limine after upgrade...` with no error after it | tell the user not to reboot |
| Boot config | `cat /etc/kernel/cmdline`; `ls /etc/mkinitcpio.conf.d/` | a missing drop-in or a changed cmdline: tell the user, point to `auspex system plan` |
| Boot `.pacnew` | a `.pacnew` for `/etc/mkinitcpio.conf`, `/etc/mkinitcpio.d/linux.preset`, `/etc/plymouth/plymouthd.conf`, `/etc/pacman.conf`, a file in `/etc/sddm.conf.d/` or `/etc/snapper/configs/` | name it first in the pacdiff step. Tell the user that a HOOKS change in `mkinitcpio.conf` makes `auspex-plymouth.conf` stale, and to merge before the next kernel update |
| auspex system tier | `auspex system plan` | a step that was applied and is now pending: an update reverted it. Offer `auspex system prepare <step>` |
| auspex user tier | `auspex status` (drift) | drift on a target: an update or an app rewrote it. Show `auspex plan`, do not apply |
| Hyprland config (only if a Hyprland package updated and the session is Hyprland) | `auspex check hyprland` and `hyprctl configerrors` | quote the error; the fix is an auspex change, not an edit of the target |
| herdr app (only if herdr, hc or herdr-app updated) | `herdr-app status`; `herdr-app check ~/.config/herdr-app/mods/<mod>` for each mod that auspex or the user made; `ls ~/.config/herdr-app/layouts ~/.config/herdr-app/themes` | quote the error; a lost avgvr layout or theme comes back with `auspex apply` (the user decides) |
| Analyser (only if `nodejs` or a plugin updated) | `ls -d ~/.claude/plugins/cache/skill-marketplace/software/*/skills/complexity-sweep/code/*/node_modules` | missing: tell the user that the complexity-sweep skill must install its dependencies again |
| Flatpak NVIDIA runtime (only if `nvidia-utils` updated) | `flatpak list --runtime \| grep -i nvidia` vs `pacman -Q nvidia-utils` | versions differ: run `flatpak update` in a new split |
| Failed units | `systemctl --failed --no-legend`, `systemctl --user --failed --no-legend` | name each unit that was not failed before the run |

Then list the user's own remaining steps (pacdiff, ProtonUp-Qt, a pending auspex
step, log out and in, reboot). After the reboot, the SDDM greeter, the boot splash
and `nvidia-power-limit.service` are things only the user can see: ask them to tell
you if one is wrong. Never reboot for them.

Reference doc: ~/docs/arch-docs/arch-update-routine.md
