# 04 Plymouth boot splash: steps 070 and 080

<!-- horch-ticket: 1 -->
**Persona:** primary `opus`
**Kind:** feature
**Review:** full
**Check:** `bats tests/system-steps.bats`
**Own:** `templates/plymouth/avgvr.script.tpl`, `themes/avgvr/plymouth/`, `system/files/avgvr/plymouth/`, `system/files/avgvr/SHA256SUMS`, `themes/avgvr/INPUTS.sha256`, `system/steps/070-avgvr-plymouth.sh`, `system/steps/080-avgvr-boot-splash.sh`, `bin/auspex-theme-build`, `bin/auspex-check-theme`, `tests/system-steps.bats`, `tests/fixtures/system/steps/`, `agent/skills/auspex/reference/system-steps.md`
**Do not touch:** `manifest/user.tsv`, `config/`, `design/directions/c/`, `system/steps/020-nvidia-early-kms.sh`, `config/kde/`, `/usr/share/plasma/`, `/etc/sddm.conf.d/`, `~/.config/kdeglobals`, `~/.local/share/Steam/`, `~/.config/lutris/`, `~/.config/heroic/`

## GOAL

The repo has the AVGVR plymouth theme, step 070 that installs and selects it, and step 080 that adds plymouth to the initramfs and `quiet splash` to the kernel command line, with guards and a restore.

## CONTEXT

- Spec: `docs/specs/avgvr-theme.md` sections 7.1 to 7.6 and 10. Build order item 3.
- Decisions to apply (from `ai_docs/plans/avgvr-theme/decisions.md`):
  - OQ3 decided: step 080 guards the Limine cmdline. It refuses when a Limine conf sets a cmdline for `arch-linux.efi`.
  - OQ4 decided: the build reads the mkinitcpio cmdline order. Write the order into the 080 header.
  - OQ10 decided: stepped boot fill (40 blocks, no smooth bar).
- Light boot (operator decision): the plymouth theme is a static image plus a stepped fill. It has no per-frame image sequence (no animation frames).
- Theme (section 7.2): images mark, wordmark, dentil on and off, numerals I to X on and off, entry and bullet PNGs; 40 blocks with stepped fill; a password band; messages; scale by `height / 2160`. Colors come from the palette through the template.
- Step 070 (section 7.3): `pacman -S --needed plymouth`; install the theme to `AUSPEX_PLYMOUTH_THEME_DIR` with `.new` then rename; back up `plymouthd.conf` to `/var/lib/auspex/070-avgvr-plymouth.plymouthd.conf.before`; run `plymouth-set-default-theme avgvr` with no `-R`.
- Step 080 (section 7.4): drop-in `AUSPEX_MKINITCPIO_DIR/auspex-plymouth.conf` with `HOOKS=(base udev plymouth autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)`. Guards, in order: (1) steps 020 and 070 are applied; (2) the current HOOKS line matches the expected one; (3) no `/etc/cmdline.d/`; (4) no Limine conf in `AUSPEX_LIMINE_CONFS` sets a cmdline for `arch-linux.efi`. Back up `AUSPEX_KERNEL_CMDLINE` to `/var/lib/auspex/080-avgvr-boot-splash.cmdline.before`, add `quiet splash`, run `mkinitcpio -P`. If `mkinitcpio` fails, restore the backup and rebuild.
- Env vars for tests: `AUSPEX_PLYMOUTH_THEME_DIR`, `AUSPEX_MKINITCPIO_DIR`, `AUSPEX_KERNEL_CMDLINE`, `AUSPEX_LIMINE_CONFS`, `AUSPEX_SYSTEM_STATE`.

## PRIOR WORK

Ticket 03 added the SDDM theme and step 060. The orchestrator adds the 03 summary here.

## STEPS

1. Write the plymouth theme and template. Extend `auspex theme build` to write `system/files/avgvr/plymouth/*` and update `SHA256SUMS`. Add plymouth checks to `auspex check theme` (every image the script names exists, no hex outside the rendered script). Check: `bin/auspex theme build` twice gives no change; `bin/auspex check theme` passes.
2. Write step 070. Check: the 070 cases in `bats tests/system-steps.bats` pass with fake `pacman` and `plymouth-set-default-theme`: apply, apply twice, undo restores `plymouthd.conf`.
3. Write step 080. Check: the 080 cases pass with a fake `mkinitcpio`: 1 case per guard, the happy path, the `mkinitcpio` failure that restores and rebuilds, and undo.
4. Update `system-steps.md` with the recovery path of spec section 10 (undo 070 and 080; Arch USB and chroot for a bad UKI). Run `bin/auspex check skill --fix`, `bin/auspex check system-steps` and `bin/auspex check --no-display`.

## Operator steps

Do not run `plymouthd`, `auspex system prepare` or `auspex system apply`. Ticket 16 puts the preview commands (section 7.6), the post-080 checks (`lsinitcpio`, `objcopy`) and "Arch USB at hand" into the checklist. Send `NOTE:` with both step names and their `auspex system plan` output.

## CONSTRAINTS

- Light system (operator decision 2026-11-26): the theme adds no resident process except `hyprpaper`. No new package beyond `plymouth`, `hyprpaper` and `ttf-jetbrains-mono`. If a step seems to need another package or a daemon, send `QUESTION:` and end your turn.
- Warning: do not run `auspex apply`, `auspex system apply`, sudo, `mkinitcpio` or `plymouthd`. No test starts `plymouthd`.
- Do not edit step 020.
- Keep all existing bats tests green. Keep `shellcheck` clean.

## DONE WHEN

- `bats tests/system-steps.bats`, `bin/auspex check theme`, `bin/auspex check system-steps` and `bin/auspex check --no-display` pass.
- `git diff --name-only` of the branch shows only paths in **Own** (plus files that `auspex check skill --fix` generates).

## REPORT

- `horch ledger progress` after steps 1, 2 and 3.
- The `horch ledger done` summary names the 080 guards in order and the mkinitcpio order written in the header.
