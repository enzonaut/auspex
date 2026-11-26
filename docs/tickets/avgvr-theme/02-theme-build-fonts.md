# 02 Theme build, check theme, verified installs and step 050 fonts

<!-- horch-ticket: 1 -->
**Persona:** primary `opus`
**Kind:** feature
**Review:** full
**Check:** `bats tests/system-steps.bats tests/commands.bats tests/router.bats`
**Own:** `bin/auspex`, `bin/auspex-theme-build`, `bin/auspex-check-theme`, `bin/auspex-check`, `bin/auspex-check-system-steps`, `bin/auspex-system-plan`, `lib/system-steps.sh`, `packages/avgvr.list`, `system/steps/050-avgvr-fonts.sh`, `system/files/avgvr/SHA256SUMS`, `system/files/avgvr/fonts/`, `themes/avgvr/generated/`, `themes/avgvr/INPUTS.sha256`, `claude/agent-settings.json`, `tests/system-steps.bats`, `tests/commands.bats`, `tests/router.bats`, `tests/theme-build.bats`, `tests/fixtures/system/blobs/`, `tests/fixtures/system/steps/`, `agent/skills/auspex/reference/commands.md`, `agent/skills/auspex/reference/system-steps.md`, `agent/skills/auspex/reference/permissions.md`
**Do not touch:** `manifest/user.tsv`, `config/`, `design/directions/c/`, `config/kde/`, `/usr/share/plasma/`, `/etc/sddm.conf.d/`, `~/.config/kdeglobals`, `~/.local/share/Steam/`, `~/.config/lutris/`, `~/.config/heroic/`

## GOAL

`auspex theme build` makes the fonts, the wallpaper PNG, `SHA256SUMS` and `INPUTS.sha256`; `auspex check theme` exists; the step runner installs hashed binary files; step 050 installs the fonts.

## CONTEXT

- Spec: `docs/specs/avgvr-theme.md` sections 4.4, 5.1, 5.2 and 12.1 (rows check theme, system-steps, permissions, `theme build --dry-run`). Build order item 1 (section 13), second half.
- Decisions to apply (from `ai_docs/plans/avgvr-theme/decisions.md`):
  - OQ6 decided: woff2 subsets for Jost and Marcellus SC from `design/directions/c/fonts/`, plus the package `ttf-jetbrains-mono`.
  - 1 palette for boot, login, desktop, terminal and Claude Code. Every generated asset takes its colors from `themes/avgvr/colors.toml`.
  - No change to game config (Steam, Lutris, Heroic, Proton, Wine).
- `auspex check theme` starts with the checks this ticket can do: templates render, `INPUTS.sha256` is current, `SHA256SUMS` matches, SVG colors and fonts come from the palette, contrast, and the game-path grep (spec section 11.2). Later tickets add their own checks to it (SDDM, plymouth, Hyprland, waybar, fuzzel, herdr).
- Game paths no row or step may write: `~/.steam`, `~/.local/share/Steam`, `~/.config/lutris`, `~/.local/share/lutris`, `~/.config/heroic`, `~/Games`, Wine and Proton prefixes, `/usr/share/steam`.
- Allow rules (spec 12.1): `auspex theme build` at level 2 and `auspex check theme` at level 1, in `claude/agent-settings.json`.

## PRIOR WORK

Ticket 01 added the palette, `lib/render.sh`, the `render` mode and the `theme-set` event. The orchestrator adds the 01 summary here.

## STEPS

1. Add `step_install_verified <sums> <repo dir> <dest dir>` to `lib/system-steps.sh` (section 5.1). It refuses a file whose hash does not match. `auspex system plan` prints the `SHA256SUMS` lines of a step. `auspex check system-steps` fails when a step reads a repo path that its header does not declare. Add a blob fixture in `tests/fixtures/system/blobs/`. Check: the new cases in `bats tests/system-steps.bats` pass.
2. Write `bin/auspex-theme-build` (section 4.4): fonts with `woff2_decompress`, `themes/avgvr/generated/wallpaper.png` at 5120x2160 with `resvg --use-font-file`, `system/files/avgvr/SHA256SUMS` and `INPUTS.sha256`. `--dry-run` prints the outputs and changes nothing. The build uses no network. Add `theme build` and `check theme` to the router. Check: `bats tests/theme-build.bats tests/router.bats tests/commands.bats` pass.
3. Run `bin/auspex theme build` and commit the outputs. Run it a 2nd time: `git status` must show no change.
4. Write `bin/auspex-check-theme` with the checks in CONTEXT. Check: `bin/auspex check theme` passes.
5. Write `packages/avgvr.list` (`plymouth`, `ttf-jetbrains-mono`) and `system/steps/050-avgvr-fonts.sh` (section 5.2): level 3, sudo, reads `packages/avgvr.list` and `system/files/avgvr/SHA256SUMS`, `pacman -S --needed ttf-jetbrains-mono`, install the fonts to `AUSPEX_FONT_DIR` (default `/usr/local/share/fonts/avgvr/`) with `step_install_verified`, then `fc-cache`. Undo removes only what the step installed. Check: the 050 cases in `bats tests/system-steps.bats` pass with fake `pacman` and `fc-cache`.
6. Add the 2 allow rules. Update `commands.md`, `system-steps.md` and `permissions.md`. Run `bin/auspex check skill --fix`, `bin/auspex check permissions` and `bin/auspex check --no-display`.

## Operator steps

Do not run `auspex system prepare` or `auspex system apply`. Ticket 16 writes the operator commands for step 050 into the checklist. Send `NOTE:` with the step name and its `auspex system plan` output.

## CONSTRAINTS

- Light system (operator decision 2026-11-26): the theme adds no resident process except `hyprpaper`. No new package beyond `plymouth`, `hyprpaper` and `ttf-jetbrains-mono`. If a step seems to need another package or a daemon, send `QUESTION:` and end your turn.
- Warning: do not run `auspex apply`, `auspex system apply` or sudo. Tests use fakes for `pacman` and `fc-cache` and set `AUSPEX_FONT_DIR` and `AUSPEX_SYSTEM_STATE` to temp folders.
- Do not edit `design/directions/c/`. Read it only.
- Do not send project code, secrets or environment values to any host.
- Keep all existing bats tests green. Keep `shellcheck` clean.

## DONE WHEN

- The bats files in **Check** pass. `bin/auspex check theme`, `bin/auspex check system-steps` and `bin/auspex check --no-display` pass.
- A 2nd `bin/auspex theme build` changes no file.
- `git diff --name-only` of the branch shows only paths in **Own** (plus files that `auspex check skill --fix` generates).

## REPORT

- `horch ledger progress` after steps 1, 3 and 5.
- The `horch ledger done` summary names: the `INPUTS.sha256` path, the `check theme` hook point for later checks, and the `step_install_verified` contract.
