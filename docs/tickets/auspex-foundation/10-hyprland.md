# 10 Hyprland: packages step, NVIDIA step, config, rules, hotkeys, dropdown

<!-- horch-ticket: 1 -->
**Persona:** primary `backend-developer`
**Kind:** feature
**Review:** full
**Check:** `bin/auspex check hyprland-rules`
**Own:** `packages/hyprland.list`, `system/steps/010-hyprland-packages.sh`, `system/steps/020-nvidia-early-kms.sh`, `system/files/`, `config/hypr/`, `config/waybar/`, `config/mako/`, `config/fuzzel/`, `config/browser-flags/`, `bin/auspex-keys`, `bin/auspex-agent-dropdown`, `bin/auspex-check-hyprland`, `bin/auspex-check-hyprland-rules`, `bin/auspex-check-dropdown`, `manifest/user.tsv`, `tests/hyprland.bats`, `agent/skills/auspex/reference/commands.md`, `agent/skills/auspex/reference/targets.md`
**Do not touch:** `config/agent-keys.conf`, `config/kde/`, `/etc/sddm.conf.d/`, `/usr/share/sddm/`, `/usr/share/plasma/`, `/etc/mkinitcpio.conf`, `~/.config/plasma*`, `~/.config/kxkbrc`

Spec: sections 3.6, 7.2, 7.3, 9.1 to 9.5, 10, 11 and 12 item 10. This is T2 on Hyprland.

Decisions to apply:

- OQ2: keep the `kms` hook. Step 020 adds only the 4 modules in `/etc/mkinitcpio.conf.d/auspex-nvidia.conf`. It does not edit `/etc/mkinitcpio.conf`.
- OQ8: read Omarchy `install/hardware/nvidia.sh` at commit `8807715`. Step 020 has a header line that names `8807715`.
- OQ6: KWallet in both sessions. Before you write `config/browser-flags/`, confirm that KDE uses `kwallet6`: `kwallet-query -l kdewallet` lists a "Chrome Keys" folder. If it does not, write no flag files and send `QUESTION:` to the orchestrator with the store that KDE uses.
- OQ5: the agent keys come only from `config/agent-keys.conf`. Do not edit it.

## Do

1. Write `packages/hyprland.list` (section 9.3) and step `010-hyprland-packages` (section 3.6).
2. Write step `020-nvidia-early-kms` with `system/files/auspex-nvidia.conf` (section 9.2).
3. Write `config/hypr/` (section 9.4): no uwsm, the 4 env vars, monitor `DP-2` `5120x2160@165`, autostart with `pam_kwallet_init`, idle lock at 10 min and display off at 15 min with no suspend, and the keyboard layout read once from `~/.config/kxkbrc`.
4. Write the window rules of section 9.5.
5. Add the Hyprland output to `auspex keys render`: an agent binds include file in `config/hypr/`, made from `config/agent-keys.conf`. The main config includes it and holds no agent key.
6. Write the Hyprland part of `auspex agent dropdown` (section 7.3): `special:agent`, class `auspex.dropdown`, and its window rule.
7. Write minimal `config/waybar/`, `config/mako/` and `config/fuzzel/`. No theme.
8. Add the targets to `manifest/user.tsv`. No target is KDE config (section 10).
9. Write `auspex check hyprland`, `auspex check hyprland-rules` and `auspex check dropdown` (section 11). `check hyprland` prints `skip` when `Hyprland` is not installed. `check dropdown` needs a live Hyprland session and prints `skip` otherwise.

## Operator steps

Run `bin/auspex system prepare 010-hyprland-packages` and `bin/auspex system prepare 020-nvidia-early-kms`. Send `OPERATOR:` to the orchestrator with the printed commands. The operator applies them, then runs `auspex apply`, then reboots. Do not run `auspex system apply`.

## Done when

- `bin/auspex check skill` passes. Run `bin/auspex check skill --fix` after you add a command or a target.

- `bin/auspex check hyprland-rules`, `bin/auspex check keys`, `bin/auspex check kde-untouched` and `bin/auspex check system-steps` pass.
- `bin/auspex check hyprland` passes, or prints `skip` before step 010 is applied.
- `bin/auspex check --no-display` passes.
