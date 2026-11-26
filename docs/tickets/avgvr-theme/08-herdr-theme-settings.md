# 08 herdr app theme, settings merger, fonts and silent done sound

<!-- horch-ticket: 1 -->
**Persona:** primary `sonnet-feature`
**Kind:** feature
**Review:** full
**Blocked by:** 07-mako-fuzzel-hyprlock
**Check:** `bats tests/merge-herdr-settings.bats tests/apply.bats`
**Own:** `templates/herdr-app/avgvr.json.tpl`, `lib/merge/herdr-settings`, `config/herdr-app/settings.json`, `config/herdr-app/sounds/silent.mp3`, `manifest/user.tsv`, `claude/deny.json`, `bin/auspex-check-theme`, `tests/merge-herdr-settings.bats`, `tests/fixtures/herdr/`, `agent/skills/auspex/reference/targets.md`
**Do not touch:** `lib/merge/claude-settings`, `~/.config/herdr-app/`, `design/directions/c/`, `config/kde/`, `/usr/share/plasma/`, `/etc/sddm.conf.d/`, `~/.config/kdeglobals`, `~/.local/share/Steam/`, `~/.config/lutris/`, `~/.config/heroic/`

## GOAL

The herdr app gets the AVGVR theme file, the owned settings keys through a merger that keeps all other keys, the 2 UI fonts and a silent done sound.

## CONTEXT

- Spec: `docs/specs/avgvr-theme.md` sections 9.1 (table rows theme, fonts, sound, settings; the merger contract) and 4.1 (herdr map keys). Research report `docs/research/herdr-app-avgvr.md`. Build order item 7, part 1.
- Decisions to apply (from `ai_docs/plans/avgvr-theme/decisions.md`):
  - The herdr app is the only terminal and agent surface. AVGVR is built around its spaces, tabs, panes and agents.
  - Q9 level L2 first: theme file, settings keys, fonts, layout. Other mods are L3 and come later.
  - Q11: the herdr app has the AVGVR look in both sessions (rows have session `any`). KDE desktop config stays unchanged.
  - Q2: accent `#EB6A43` only for blocked and the cursor; working `bronze`, done `verdigris`, idle `text_faint`.
  - Q6: keep the blocked sound, turn off the done sound (`sounds.done` points to a silent file; do not set `sounds.blocked`; `sounds.enabled` stays true).
  - Q10: toasts stay in the app.
- Theme file: `background`, `foreground`, `selection`, `cursor`, `ansi` (16 values) and `colors` (surfaces and agent states) from the palette. Target `~/.config/herdr-app/themes/avgvr.json`, render mode.
- Merger `lib/merge/herdr-settings` follows the contract in `lib/common.sh` (`merge`, `restore`, `digest`), as `lib/merge/claude-settings` does. Owned keys: `theme` "avgvr", `font` "JetBrains Mono", `font_weight` 400, `font_weight_bold` 700, `ui_font` "Jost", `sounds.done` "sounds/silent.mp3". It keeps every other key, records old values (or absent) for `restore`, digests owned keys only, and writes nothing when the target is not valid JSON.
- Font rows copy `system/files/avgvr/fonts/Jost.ttf` and `MarcellusSC-Regular.ttf` to `~/.config/herdr-app/fonts/`.
- Make `silent.mp3` locally (for example `ffmpeg -f lavfi -i anullsrc -t 0.2`). Keep it under 4 KB. Download nothing.

## PRIOR WORK

Ticket 07 added mako, fuzzel and hyprlock. The orchestrator adds the 07 summary here.

## STEPS

1. Write the theme template. Add to `auspex check theme`: the rendered theme parses with `jq` and has 16 `ansi` values. Check: `bin/auspex check theme` passes.
2. Write the merger and `tests/merge-herdr-settings.bats`: keeps unknown keys, sets only `sounds.done` in `sounds`, restore puts back old values and removes absent keys, digest ignores other keys, bad JSON writes nothing. Check: the test passes.
3. Make `silent.mp3`. Add the rows of CONTEXT (session `any`) and deny rules. Check: `bats tests/apply.bats`, `bin/auspex check permissions` and `bin/auspex check kde-untouched` pass.
4. Update `targets.md`. Run `bin/auspex check skill --fix` and `bin/auspex check --no-display`.

## CONSTRAINTS

- Light system (operator decision 2026-11-26): the theme adds no resident process except `hyprpaper`. No new package beyond `plymouth`, `hyprpaper` and `ttf-jetbrains-mono`. If the work seems to need another package or a daemon, send `QUESTION:` and end your turn.
- Never edit a shipped herdr layout, mod or `frame/` file. The app writes them again at each start.
- Do not read or write the live `~/.config/herdr-app/`. Use fixtures.
- Warning: do not run `auspex apply`, `auspex undo`, `auspex system apply` or sudo. Tests use `AUSPEX`, `AUSPEX_STATE` and `HOME` in a temp folder.
- No test starts a real `herdr-app`, `hc`, `sddm-greeter` or `plymouthd`, or makes a herdr space. Tests use fakes on `PATH` with `make_fake`, as `tests/agent.bats` does.
- Do not send project code, secrets or environment values to any host.
- Keep all existing bats tests green. Keep `shellcheck` clean. Do not change any KDE row in `manifest/user.tsv` (`auspex check kde-untouched`).

## DONE WHEN

- `bats tests/merge-herdr-settings.bats tests/apply.bats`, `bin/auspex check theme` and `bin/auspex check --no-display` pass.
- `git diff --name-only` of the branch shows only paths in **Own** (plus files that `auspex check skill --fix` generates).

## REPORT

- `horch ledger progress` after steps 2 and 3.
- The `horch ledger done` summary names the owned keys and the size of `silent.mp3`.
