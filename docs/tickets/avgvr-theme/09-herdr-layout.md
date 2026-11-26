# 09 herdr layout avgvr

<!-- horch-ticket: 1 -->
**Persona:** primary `sonnet-feature`
**Kind:** feature
**Review:** light
**Blocked by:** 08-herdr-theme-settings
**Own:** `config/herdr-app/layouts/avgvr.json`, `manifest/user.tsv`, `claude/deny.json`, `bin/auspex-check-theme`, `agent/skills/auspex/reference/targets.md`
**Do not touch:** `lib/merge/`, `~/.config/herdr-app/`, `design/directions/c/`, `config/kde/`, `/usr/share/plasma/`, `/etc/sddm.conf.d/`, `~/.config/kdeglobals`, `~/.local/share/Steam/`, `~/.config/lutris/`, `~/.config/heroic/`

## GOAL

The repo has a herdr layout `avgvr`, a clone of `main` with the AVGVR frame, and a copy row puts it in `~/.config/herdr-app/layouts/`.

## CONTEXT

- Spec: `docs/specs/avgvr-theme.md` section 9.1 (row layout). Research report `docs/research/herdr-app-avgvr.md` (layout format, `layout.clone`, the frame API). Build order item 7, part 2.
- Decisions to apply (from `ai_docs/plans/avgvr-theme/decisions.md`):
  - The herdr app is the only terminal and agent surface. AVGVR is built around its spaces, tabs, panes and agents.
  - Q9 level L2 first, plus 1 personal mod: the horizontal spaces row (Q4 needs the `spaces` mod). Other mods are L3 and come later, 1 by 1.
  - Q11: the herdr app has the AVGVR look in both sessions (session `any`). KDE desktop config stays unchanged.
  - Q3: the focused pane border is `bronze`.
  - Q5 option O1: waybar is the only band. The layout has no top band and no title bar.
  - Q4: an `avgvr-spaces` row sits above the tabs. Ticket 10 writes the mod. This layout only places it.
- Make the clone the way `layout.clone` does (read the research report). Change: radius 0 everywhere, focused pane border 1 px `bronze`, no left sidebar, no band, title bar `none`, a row for mod `avgvr-spaces` above the tabs.
- The operator selects the layout with `layout.switch avgvr` (ctrl-shift-l). The checklist (ticket 16) has this step. auspex does not switch it.
- Read shipped files under `/usr/share/herdr-app/` or the research report only. Never edit a shipped layout. The app writes them again at each start.

## PRIOR WORK

Ticket 08 added the herdr theme, the settings merger, fonts and the silent sound. The orchestrator adds the 08 summary here.

## STEPS

1. Write `config/herdr-app/layouts/avgvr.json` from `main`. Check: `jq . config/herdr-app/layouts/avgvr.json` passes.
2. Add the copy row (session `any`) and Edit and Write deny rules. Check: `bin/auspex check permissions` and `bin/auspex check kde-untouched` pass.
3. Add to `auspex check theme`: the layout parses with `jq`, has no radius above 0, and names `avgvr-spaces`. Check: `bin/auspex check theme` passes.
4. Update `targets.md`. Run `bin/auspex check skill --fix` and `bin/auspex check --no-display`.

## CONSTRAINTS

- Light system (operator decision 2026-11-26): the theme adds no resident process except `hyprpaper`. No new package beyond `plymouth`, `hyprpaper` and `ttf-jetbrains-mono`. If the work seems to need another package or a daemon, send `QUESTION:` and end your turn.
- Do not start `herdr-app` and do not make a herdr space.
- Warning: do not run `auspex apply`, `auspex undo`, `auspex system apply` or sudo. Tests use `AUSPEX`, `AUSPEX_STATE` and `HOME` in a temp folder.
- No test starts a real `herdr-app`, `hc`, `sddm-greeter` or `plymouthd`, or makes a herdr space. Tests use fakes on `PATH` with `make_fake`, as `tests/agent.bats` does.
- Do not send project code, secrets or environment values to any host.
- Keep all existing bats tests green. Keep `shellcheck` clean. Do not change any KDE row in `manifest/user.tsv` (`auspex check kde-untouched`).

## DONE WHEN

- `bin/auspex check theme` and `bin/auspex check --no-display` pass.
- `git diff --name-only` of the branch shows only paths in **Own** (plus files that `auspex check skill --fix` generates).

## REPORT

- `horch ledger progress` after step 1.
- The `horch ledger done` summary lists each change from `main`.
