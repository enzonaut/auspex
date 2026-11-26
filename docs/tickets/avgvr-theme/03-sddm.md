# 03 SDDM login theme and step 060

<!-- horch-ticket: 1 -->
**Persona:** primary `opus`
**Kind:** feature
**Review:** full
**Check:** `bats tests/system-steps.bats`
**Blocked by:** 02-theme-build-fonts
**Own:** `templates/sddm/theme.conf.tpl`, `themes/avgvr/sddm/`, `system/files/avgvr/sddm/`, `system/files/avgvr/SHA256SUMS`, `themes/avgvr/INPUTS.sha256`, `system/steps/060-avgvr-sddm.sh`, `bin/auspex-theme-build`, `bin/auspex-check-theme`, `bin/auspex-check-system-steps`, `docs/specs/auspex-foundation.md`, `tests/system-steps.bats`, `tests/fixtures/system/bad/sddm-breeze.sh`, `tests/fixtures/system/bad/sddm-exact-path-wrong-step.sh`, `agent/skills/auspex/reference/system-steps.md`
**Do not touch:** `manifest/user.tsv`, `config/`, `design/directions/c/`, `config/kde/`, `/usr/share/plasma/`, `/usr/share/sddm/themes/breeze/`, `~/.config/kdeglobals`, `~/.local/share/Steam/`, `~/.config/lutris/`, `~/.config/heroic/`

## GOAL

The repo has the AVGVR SDDM theme (Qt 6 QML) and step 060 that installs it and selects it, with the foundation deny rule changed to allow exactly these paths in step 060 only.

## CONTEXT

- Spec: `docs/specs/avgvr-theme.md` sections 6.1, 6.2, 6.3, 6.4 and 10. Build order item 2.
- Decisions to apply (from `ai_docs/plans/avgvr-theme/decisions.md`):
  - OQ5 decided: the SDDM greeter stays X11. Do not change the greeter display server.
  - OQ8 decided: no SDDM fallback theme. Recovery is test mode and the text console (spec section 10).
  - OQ11 decided: keep the conf name `/etc/sddm.conf.d/zz-auspex-avgvr.conf`.
  - KDE Plasma stays unchanged as the fallback session. Breeze stays installed and untouched.
- Theme (section 6.1): `metadata.desktop` with `QtVersion=6`; `theme.conf` rendered from `templates/sddm/theme.conf.tpl`; `Main.qml` has no hex color (it reads `theme.conf`); `backdrop.png` and `mark.png` from the theme build. The band is in the lower third. The accent shows only on login failed. Use `userModel.lastUser` and `lastIndex`. Keep a clear tab order. Show a CAPS label when Caps Lock is on.
- Step 060 (section 6.2): reads `system/files/avgvr/SHA256SUMS`; refuses when breeze `Main.qml` is missing; installs to `avgvr.new` under `AUSPEX_SDDM_THEME_DIR` (default `/usr/share/sddm/themes/`), then renames it to `avgvr`; writes `zz-auspex-avgvr.conf` under `AUSPEX_SDDM_CONF_DIR` with `[Theme]`, `Current=avgvr`, `Font=Jost,11`. Undo removes the conf and the theme, and the conf dir only if the step made it (marker `/var/lib/auspex/060-avgvr-sddm.made-dir` under `AUSPEX_SYSTEM_STATE`).
- Foundation amendment (section 6.3): edit `docs/specs/auspex-foundation.md` section 10 bullet 2 and section 3.6. `bin/auspex-check-system-steps` allows the exact paths `/usr/share/sddm/themes/avgvr`, `/usr/share/sddm/themes/avgvr.new` and `/etc/sddm.conf.d/zz-auspex-avgvr.conf` only in `060-avgvr-sddm.sh`. The existing fixture `sddm.sh` must still fail.

## PRIOR WORK

Ticket 02 added `step_install_verified`, `auspex theme build` and `auspex check theme`. The orchestrator adds the 02 summary here.

## STEPS

1. Make the foundation amendment and the 2 new bad fixtures. Check: `bin/auspex check system-steps` fails on `sddm-breeze.sh`, `sddm-exact-path-wrong-step.sh` and `sddm.sh`.
2. Write the theme in `themes/avgvr/sddm/` and the template. Extend `auspex theme build` to write `system/files/avgvr/sddm/*` and update `SHA256SUMS`. Check: `bin/auspex theme build` twice gives no change on the 2nd run.
3. Add the SDDM checks to `auspex check theme`: `qmllint` on `Main.qml` when it is installed (else `skip`), no hex in `Main.qml`, `QtVersion=6`, every file in `SHA256SUMS`. Check: `bin/auspex check theme` passes.
4. Write step 060. Check: the 060 cases in `bats tests/system-steps.bats` pass, with the env vars of CONTEXT set to temp folders: apply, apply twice, undo, undo with a pre-existing conf dir, refuse without breeze.
5. Update `system-steps.md`. Run `bin/auspex check skill --fix` and `bin/auspex check --no-display`.

## Operator steps

Do not run `sddm-greeter-qt6`, `auspex system prepare` or `auspex system apply`. Ticket 16 puts the test-mode commands in the checklist: `sddm-greeter-qt6 --test-mode --theme system/files/avgvr/sddm` before 060, and `--theme /usr/share/sddm/themes/avgvr` after 060. Send `NOTE:` with the step name and its `auspex system plan` output.

## CONSTRAINTS

- Light system (operator decision 2026-11-26): the theme adds no resident process except `hyprpaper`. No new package beyond `plymouth`, `hyprpaper` and `ttf-jetbrains-mono`. If a step seems to need another package or a daemon, send `QUESTION:` and end your turn.
- Warning: do not run `auspex apply`, `auspex system apply` or sudo. No test starts `sddm-greeter`.
- Never write to `/usr/share/sddm/themes/breeze/` or `/usr/share/plasma/`.
- Keep all existing bats tests green. Keep `shellcheck` clean.

## DONE WHEN

- `bats tests/system-steps.bats`, `bin/auspex check theme`, `bin/auspex check system-steps` and `bin/auspex check --no-display` pass.
- `git diff --name-only` of the branch shows only paths in **Own** (plus files that `auspex check skill --fix` generates).

## REPORT

- `horch ledger progress` after steps 1, 2 and 4.
- The `horch ledger done` summary names the installed paths and whether `qmllint` ran or printed skip.
