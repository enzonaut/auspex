# 10 herdr mod avgvr-spaces

<!-- horch-ticket: 1 -->
**Persona:** primary `sonnet-feature`
**Kind:** feature
**Review:** full
**Blocked by:** 09-herdr-layout
**Own:** `config/herdr-app/mods/avgvr-spaces/main.js`, `config/herdr-app/mods/avgvr-spaces/mod.json`, `manifest/user.tsv`, `claude/deny.json`, `bin/auspex-check-theme`, `agent/skills/auspex/reference/targets.md`
**Do not touch:** `config/herdr-app/layouts/`, `~/.config/herdr-app/`, `design/directions/c/`, `config/kde/`, `/usr/share/plasma/`, `/etc/sddm.conf.d/`, `~/.config/kdeglobals`, `~/.local/share/Steam/`, `~/.config/lutris/`, `~/.config/heroic/`

## GOAL

The repo has the personal herdr mod `avgvr-spaces`: a horizontal row of `[ NAME ]` space tabs, a clone of the shipped `spaces` mod.

## CONTEXT

- Spec: `docs/specs/avgvr-theme.md` section 9.1 (row mod). Research report `docs/research/herdr-app-avgvr.md` (mod API, `mod.clone`, report item S5). Build order item 7, part 3.
- Decisions to apply (from `ai_docs/plans/avgvr-theme/decisions.md`):
  - The herdr app is the only terminal and agent surface. AVGVR is built around its spaces, tabs, panes and agents.
  - Q9 level L2 first, plus 1 personal mod: the horizontal spaces row (Q4 needs the `spaces` mod). Other mods are L3 and come later, 1 by 1.
  - Q11: the herdr app has the AVGVR look in both sessions (session `any`). KDE desktop config stays unchanged.
  - Q1: herdr spaces show their names in capitals with no numeral, for example `[ AUSPEX ]`.
  - Q4: the spaces row is horizontal, above the tabs. Rejected: the left sidebar.
  - Q2: the accent `#EB6A43` shows only for blocked and the cursor. A space with a blocked agent may use the accent; working `bronze`, done `verdigris`, idle `text_faint`. The active space uses `gold` text.
- Clone `spaces` the way `mod.clone` does. Change it to a horizontal row, font Marcellus SC, no `.rounded(` call. `mod.json` is `{ "place": "none", "title": "AVGVR spaces" }`. The layout from ticket 09 places it.
- Colors come from the active herdr theme (`avgvr`) through the mod API. Do not hard-code hex values.
- Read the shipped `spaces` mod only. Never edit a shipped mod.

## PRIOR WORK

Ticket 09 added the layout `avgvr`. The orchestrator adds the 09 summary here.

## STEPS

1. Write `main.js` and `mod.json`. Check: `node --check main.js` passes when `node` is installed; `jq . mod.json` passes.
2. Add the 2 copy rows (session `any`) and deny rules. Check: `bin/auspex check permissions` and `bin/auspex check kde-untouched` pass.
3. Add to `auspex check theme`: no `.rounded(` in `main.js`; no hex color in `main.js`; `mod.json` parses. If `herdr-app` has an offline validator that starts no app window and makes no space (read `herdr-app --help`), run it; else print `skip`. Check: `bin/auspex check theme` passes.
4. Update `targets.md`. Run `bin/auspex check skill --fix` and `bin/auspex check --no-display`.

## CONSTRAINTS

- Light system (operator decision 2026-11-26): the theme adds no resident process except `hyprpaper`. No new package beyond `plymouth`, `hyprpaper` and `ttf-jetbrains-mono`. If the work seems to need another package or a daemon, send `QUESTION:` and end your turn.
- The mod runs only inside the herdr app. It starts no process and polls nothing outside the app.
- Do not start `herdr-app` and do not make a herdr space. The checklist (ticket 16) tests the row live.
- Warning: do not run `auspex apply`, `auspex undo`, `auspex system apply` or sudo. Tests use `AUSPEX`, `AUSPEX_STATE` and `HOME` in a temp folder.
- No test starts a real `herdr-app`, `hc`, `sddm-greeter` or `plymouthd`, or makes a herdr space. Tests use fakes on `PATH` with `make_fake`, as `tests/agent.bats` does.
- Do not send project code, secrets or environment values to any host.
- Keep all existing bats tests green. Keep `shellcheck` clean. Do not change any KDE row in `manifest/user.tsv` (`auspex check kde-untouched`).

## DONE WHEN

- `bin/auspex check theme` and `bin/auspex check --no-display` pass.
- `git diff --name-only` of the branch shows only paths in **Own** (plus files that `auspex check skill --fix` generates).

## REPORT

- `horch ledger progress` after step 1.
- The `horch ledger done` summary says whether an offline validator ran or the check prints `skip`.
