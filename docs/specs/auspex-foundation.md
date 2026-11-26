# Spec: auspex foundation

- Date: 2026-11-25.
- Status: draft for operator review. Nothing in this spec is built or installed.
- Inputs:
  - `ai_docs/plans/omarchy-research/decisions.md` (operator decisions, fixed);
  - `docs/research/omarchy-ai-first.md` (section 3, ideas I1 to I6);
  - `docs/design/ai-first.md` ("Recommended first slice", terms N1 to N4, T1, T2, T5).
- Scope: repo layout, install/apply/undo, permission levels, machine facts, the auspex skill, the agent command and hotkeys, the weekly update check, and Hyprland as a 2nd login session beside KDE Plasma.
- Out of scope: the Empire Legion theme, the SDDM theme, plymouth, wallpapers, colors, AI-first slice 2, voice input. Section 13 lists the follow-ups.

## 0. Terms

- **Repo**: this git repository, checked out at `~/repos/auspex`. `$AUSPEX` names this path in the spec.
- **Target**: a file outside the repo that auspex writes, for example `~/.config/hypr/hyprland.lua`.
- **Managed target**: a target that the manifest (section 2.2) lists. auspex writes, records and undoes only managed targets.
- **User tier**: targets under `$HOME`. They need no sudo.
- **System tier**: targets outside `$HOME` (`/etc`, `/usr`, `/boot`) and package changes. They need sudo.
- **Apply**: copy the repo state of user-tier targets onto the system and record the change.
- **Generation**: the record of 1 apply or 1 undo. It holds the earlier content of each target that it changed.
- **System step**: 1 script in the repo that makes 1 system-tier change. Only the operator runs it.
- **Agent**: Claude Code.
- **Level 1, 2, 3**: the permission levels of N2 (section 4).

## 1. Requirements summary

| Id | Requirement | Section |
|---|---|---|
| R1 | Commands are flat scripts `bin/auspex-<group>-<name>` with header lines, behind 1 router `auspex`. | 2.1 |
| R2 | Nothing on the system changes until the operator or a permitted agent runs `auspex apply` or a system step. | 3 |
| R3 | Each apply records a generation. `auspex undo` restores only managed targets. | 3.3, 3.4 |
| R4 | The agent never runs sudo. It prepares a system step. The operator runs it and types the password. | 3.6 |
| R5 | Level rules live in Claude Code permission settings. The 1 allow rule and 38 deny rules in `~/.claude/settings.json` stay. | 4 |
| R6 | `auspex facts` prints the machine state with no sudo. | 5 |
| R7 | The auspex skill covers both desktops. A check fails when the skill and the repo layout disagree. | 6 |
| R8 | `auspex agent` and a hotkey work on Hyprland and on KDE. | 7 |
| R9 | A weekly systemd user timer runs the arch-update check in read-and-report mode and sends a notification. | 8 |
| R10 | SDDM offers Hyprland beside Plasma. KDE config does not change, except the 2 agent hotkeys. | 9 |
| R11 | Each part has an automated check that runs without sudo and, where possible, without a display. | 11 |

## 2. Repo layout

### 2.1 Tree

```
auspex/
├── bin/                         # I1: commands. Every file is executable.
│   ├── auspex                   # router
│   ├── auspex-apply
│   ├── auspex-plan
│   ├── auspex-undo
│   ├── auspex-status
│   ├── auspex-facts
│   ├── auspex-agent
│   ├── auspex-commands
│   ├── auspex-check             # runs every check in section 11
│   ├── auspex-check-<name>      # 1 script per check
│   ├── auspex-system-plan
│   ├── auspex-system-prepare
│   ├── auspex-system-apply      # operator only (level 3)
│   ├── auspex-system-undo       # operator only (level 3)
│   ├── auspex-update-check      # the weekly job (section 8)
│   └── auspex-migrate
├── lib/
│   ├── common.sh                # paths, logging, locking, hash helpers
│   └── merge/                   # 1 merger per merge-mode target (section 3.2)
│       ├── claude-settings
│       └── kglobalshortcuts
├── manifest/
│   └── user.tsv                 # managed user-tier targets (section 2.2)
├── config/                      # repo copies of user-tier targets, by app
│   ├── hypr/                    # hyprland.lua (+ includes), hypridle, hyprlock
│   ├── waybar/
│   ├── mako/
│   ├── fuzzel/
│   ├── browser-flags/           # chrome-flags.conf, brave-flags.conf (section 9.4)
│   ├── kde/                     # shortcut entries only (section 7.4)
│   └── applications/            # .desktop files for the agent launchers
├── claude/
│   ├── deny.json                # level 3 rules, merged into ~/.claude/settings.json
│   ├── agent-settings.json      # level 1 and 2 rules, for `auspex agent` only
│   └── headless-settings.json   # read-only rules, for headless runs
├── agent/
│   └── skills/
│       └── auspex/              # T1 skill (section 6)
├── systemd/
│   └── user/                    # auspex-update-check.service, .timer
├── system/
│   ├── steps/                   # NNN-<name>.sh, 1 system-tier change each
│   └── files/                   # repo copies of /etc files that steps install
├── packages/
│   ├── hyprland.list            # 1 package name per line
│   └── auspex-tools.list
├── migrations/                  # I2: <unix-ts>-<slug>.sh, user tier, run once
├── hooks/                       # I4: <event>.d/ folders
│   ├── post-apply.d/
│   ├── post-undo.d/
│   └── post-system-step.d/
├── themes/                      # reserved for the theme spec. README.md only.
├── templates/                   # reserved for the theme spec (I3). README.md only.
├── tests/                       # bats tests and fixtures (section 11)
└── docs/
```

Rules:

- `themes/` and `templates/` hold only a `README.md` that says "reserved for the theme spec". The I3 palette (`themes/<name>/colors.toml`) and the `*.tpl` files come with the theme spec. The manifest reserves a `render` mode for them (section 2.2) but no target uses it now.
- The repo stays the source of truth. The agent edits files in the repo. It does not edit a target directly (section 4).
- `$AUSPEX` defaults to the directory 1 level above `bin/auspex`, resolved through symlinks. The environment variable `AUSPEX` overrides it, for tests.

### 2.2 Manifest

`manifest/user.tsv` lists each managed user-tier target, 1 per line, tab-separated:

```
# source                              target                                   mode   session
config/hypr/hyprland.lua              ~/.config/hypr/hyprland.lua              copy   hyprland
config/waybar/config.jsonc            ~/.config/waybar/config.jsonc            copy   hyprland
agent/skills/auspex/                  ~/.claude/skills/auspex/                 tree   any
claude/deny.json                      ~/.claude/settings.json                  merge  any
config/kde/agent-shortcuts.ini        ~/.config/kglobalshortcutsrc             merge  kde
systemd/user/auspex-update-check.timer ~/.config/systemd/user/auspex-update-check.timer copy any
```

Modes:

- `copy`: auspex writes the whole target. The target must not exist before the 1st apply, or `auspex apply` stops and asks the operator to run `auspex apply --adopt <target>` (section 3.3).
- `tree`: `copy` for each file in a folder. Files in the target folder that the source does not have are removed only if an earlier generation wrote them.
- `merge`: auspex owns only some keys or entries in a target that other programs also write. `lib/merge/<name>` does the work. It reads the target, adds or removes only the entries auspex owns, and writes the result. The merger records the owned entries in `~/.local/state/auspex/owned/<name>.json`.
- `render`: reserved for the theme spec. No target uses it in this spec.

The `session` column is `any`, `hyprland`, or `kde`. It is for the skill and for `auspex facts`. It does not limit apply.

Symlinks: auspex does not symlink targets into the repo. A symlink makes every repo edit live at once, and that breaks R2. The only symlink is `~/.local/bin/auspex` → `$AUSPEX/bin/auspex`, which the bootstrap (section 3.1) makes.

### 2.3 Command headers and router (I1)

Each `bin/auspex-*` script starts with header lines after the shebang:

```bash
#!/usr/bin/env bash
# auspex:summary=Apply the repo state of user-tier targets and record a generation
# auspex:args=[--dry-run] [--adopt <target>] [--force] [--reason <text>]
# auspex:level=2
# auspex:requires-sudo=false
```

- `auspex:level` is `1`, `2`, or `3`. It must agree with the permission rules (check `auspex check commands`, section 11).
- `auspex <words...>` routes to the longest existing `bin/auspex-<w1>-<w2>-...` and passes the rest as arguments. Example: `auspex system apply 010` runs `auspex-system-apply 010`.
- `auspex` with no words, or `auspex help`, prints the command list from the headers.
- `auspex commands [--markdown]` prints the command table. The skill uses the markdown form (section 6.3).
- `auspex commands --check` fails on a missing header, a name collision, or a non-executable script.

### 2.4 Migrations (I2)

- A migration is `migrations/<unix-ts>-<slug>.sh`. It runs once, as the user, and must be idempotent.
- A marker `~/.local/state/auspex/migrations/<file name>` records a completed migration.
- `auspex migrate --pending` lists pending migrations. `auspex apply` runs pending migrations after it writes the targets, in name order. A migration that fails stops the apply. The apply records the generation up to that point.
- Migrations are user tier only. A system-tier change is a system step (section 3.6).
- The 1st migration exists only to prove the mechanism (it writes the marker). Real migrations come when a later change needs one.

### 2.5 Hooks (I4)

- Events: `post-apply`, `post-undo`, `post-system-step`. The theme spec adds `theme-set`.
- auspex runs each executable file in `hooks/<event>.d/` in name order. It passes the generation number as `$1`.
- A failed hook prints a warning. It does not undo the apply.
- The default hooks in this spec:
  - `post-apply.d/10-reload-hyprland`: runs `hyprctl reload` if `HYPRLAND_INSTANCE_SIGNATURE` is set and a `hypr` target changed.
  - `post-apply.d/20-systemd-user`: runs `systemctl --user daemon-reload` if a unit target changed, then `systemctl --user enable --now auspex-update-check.timer`.
  - `post-apply.d/30-mako`: runs `makoctl reload` if mako runs and its target changed.

## 3. Install, apply, and undo (N1)

### 3.1 What "install step" means

The install step has 3 parts. Each part has a different actor.

| Part | Command | Actor | sudo |
|---|---|---|---|
| Bootstrap (once) | `$AUSPEX/bin/auspex bootstrap` | Operator | No |
| User tier | `auspex apply` | Operator, or the agent at level 2 | No |
| System tier | `auspex system apply <step>` | Operator only | Yes |

- Bootstrap makes `~/.local/bin/auspex`, makes `~/.local/state/auspex/`, and runs the 1st `auspex plan`. `~/.local/bin` is already on `PATH` on this machine.
- A fresh machine runs: bootstrap, then every system step in number order, then `auspex apply`. On this machine the order is the same.
- `auspex status` prints: the repo commit, the last generation, pending migrations, pending system steps, and targets with drift.

### 3.2 State on disk

```
~/.local/state/auspex/
├── lock                         # flock file. 1 apply or undo at a time.
├── generations/
│   └── 0007/
│       ├── meta.json            # number, time, kind (apply|undo), repo commit, reason, actor
│       ├── before/<target path> # earlier content, or <path>.absent if no file existed
│       └── after.sha256         # hash of each target as this generation wrote it
├── owned/<merger>.json          # entries a merger owns in a merge-mode target
├── migrations/<name>            # completed migration markers
├── system-steps/<step>.json     # applied system steps: time, script hash, result
└── reports/                     # output of headless runs (section 8)
```

- Generation numbers increase by 1. They are never reused.
- auspex keeps the last 50 generations. It deletes older ones at the end of an apply.
- `actor` in `meta.json` is `agent` if `AUSPEX_ACTOR=agent` is set (`auspex agent` sets it), else `operator`.

### 3.3 Apply

`auspex plan` is a dry run. It prints, for each managed target, one of: `unchanged`, `create`, `update` (with a unified diff), `drift` (the target changed outside auspex), or `remove`.

`auspex apply [--reason <text>]` does these steps in order:

1. Take the lock. Stop if another apply or undo holds it.
2. Stop if the repo has uncommitted changes in a source path that the manifest names. The generation records a commit, so an apply always maps to 1 commit. The agent commits in the repo first (level 1).
3. Build the plan.
4. Stop on `drift`. A target has drift when its hash differs from the `after.sha256` of the last generation that wrote it. Apply prints the diff and 2 ways forward: `auspex apply --adopt <target>` copies the live file into the repo source (the operator then commits it), and `auspex apply --force` overwrites the live file. A merge-mode target has drift only when an owned entry changed.
5. Stop if nothing changes.
6. Make the generation folder. Copy each target that changes into `before/`, or write `<path>.absent`.
7. Write each target with a temp file and `mv` in the same folder, so each write is atomic. Keep the file mode of an existing target.
8. Write `after.sha256` and `meta.json`.
9. Run pending migrations (section 2.4).
10. Run `post-apply` hooks.
11. Print the generation number and the list of changed targets.

If a step after step 6 fails, apply restores `before/` for the targets that it already wrote, marks the generation `failed` in `meta.json`, and exits non-zero.

### 3.4 Undo

- `auspex undo` undoes the last generation that is not already undone.
- `auspex undo --to <n>` undoes each generation after `n`, newest first.
- Undo restores `before/` for each target of that generation. For a `.absent` marker it removes the target.
- Undo stops if a target changed after that generation wrote it (hash differs from `after.sha256`). `--force` overrides.
- Undo is itself a generation of kind `undo`. `auspex undo` on an undo generation is a redo.
- Undo runs the `post-undo` hooks.
- Undo touches only managed targets. It does not touch any other file in `$HOME`.

### 3.5 The snapshot as last resort

- The design says to save a snapshot before an apply. On this machine `ALLOW_USERS=""` in both snapper configs, so a user cannot make a snapshot without sudo.
- Decision: the generation folder is the undo mechanism. It does not need a snapshot.
- If `snapper -c home create` works without sudo (see Open Question OQ3), apply also makes a `home` snapshot with description `auspex gen <n>` before step 7. If the command fails, apply prints 1 line and continues.
- snap-pac already makes `root` snapshots around each package change. A system step that runs pacman gets those snapshots with no extra work.

### 3.6 System steps (sudo separation)

A system step is `system/steps/NNN-<name>.sh`. It has the header lines of section 2.3 with `auspex:level=3` and `auspex:requires-sudo=true`, and 3 shell functions:

```bash
check()  # exit 0 if the change is already in place. No sudo. No writes.
apply()  # make the change. Runs as root.
undo()   # reverse the change. Runs as root.
```

The flow:

1. The agent edits or adds a step in the repo and commits it (level 1).
2. The agent runs `auspex system plan` (level 1). It runs `check` of each step as the user and lists the pending steps. For each step it prints the script, and a diff for each file under `system/files/` that the step installs.
3. The agent runs `auspex system prepare <step>` (level 1). In a herdr session this opens a split pane to the right, as the `arch-update` skill does, and starts `auspex system apply <step>` in it. Outside herdr it prints the exact command for the operator to run.
4. `auspex system apply <step>` (level 3) shows the script and the plan, and asks `Apply step NNN? [y/N]`. On `y` it runs `sudo bash -c` with the `apply` function of that step. sudo asks the operator for the password in that pane.
5. After the step, it runs `check` again, writes `~/.local/state/auspex/system-steps/<step>.json`, and runs the `post-system-step` hooks.

Rules:

- The agent never runs `auspex system apply`, `auspex system undo`, or `sudo`. Section 4 denies them.
- `auspex system apply` refuses to run without a TTY, and refuses if `AUSPEX_ACTOR=agent` is set. This is a 2nd guard behind the permission rules.
- `auspex system undo <step>` runs the `undo` function in the same way.
- A step that installs packages calls `pacman -S --needed` with a list from `packages/`. snap-pac makes the root snapshots.
- A step never edits a file under `~/.config/plasma*`, `~/.config/k*`, or `/etc/sddm.conf.d/` except where this spec says so.

System steps in this spec:

| Step | Change | Undo |
|---|---|---|
| `010-hyprland-packages` | `pacman -S --needed` the packages in `packages/hyprland.list`. | `pacman -Rns` the packages that this step installed. The step records them. |
| `020-nvidia-early-kms` | Writes `/etc/mkinitcpio.conf.d/auspex-nvidia.conf` with `MODULES+=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)`, then runs `mkinitcpio -P`. | Removes the file, runs `mkinitcpio -P`. |
| `030-auspex-tools` | `pacman -S --needed` the packages in `packages/auspex-tools.list` (`bats`, `shellcheck`, `jq`, `pacman-contrib`). | `pacman -Rns` the packages that this step installed. |

## 4. Permission levels (N2)

### 4.1 Where the rules live

Claude Code reads permission rules from several settings files. A deny rule in any of them wins over an allow rule in any other. auspex uses 3 files:

| File | Content | Loaded by | Effect |
|---|---|---|---|
| `~/.claude/settings.json` | Existing rules, plus the level 3 deny rules from `claude/deny.json` | Every Claude Code session, including fleet workers | Only adds deny rules. It never adds an allow rule. |
| `~/.config/auspex/claude/agent-settings.json` (from `claude/agent-settings.json`) | Level 1 and level 2 allow rules | `auspex agent`, through `claude --settings <file>` | The agent can edit the repo and run `auspex apply` with no prompt. |
| `~/.config/auspex/claude/headless-settings.json` (from `claude/headless-settings.json`) | Read-only allow rules | `auspex agent --headless` (section 8) | A headless run can only read. |

Reason for this split: an allow rule in `~/.claude/settings.json` applies to every fleet worker. Level 2 power (`auspex apply` with no prompt) belongs only to the desktop agent that the operator opens. Deny rules are safe to apply everywhere.

### 4.2 Merge into `~/.claude/settings.json`

`lib/merge/claude-settings` (merge mode, section 2.2):

1. Read `~/.claude/settings.json` with `jq`. Stop with an error if it is not valid JSON.
2. Read `~/.local/state/auspex/owned/claude-settings.json`: the rules that auspex added earlier.
3. New `permissions.deny` = (current deny − owned rules that are no longer in `claude/deny.json`) ∪ `claude/deny.json`. Keep the order of existing rules. Add new rules at the end. Do not add a duplicate.
4. Write the owned list: the rules from `claude/deny.json` that were not already present before auspex added them. A rule that the operator had already is never owned, so auspex never removes it.
5. Do not touch any other key: `allow`, `hooks`, `env`, `model`, `statusLine`, plugins, and the rest stay as they are.

The check `auspex check claude-settings` (section 11) runs the merger on a fixture copy of the current file and verifies: valid JSON, the 1 allow rule present, the 38 deny rules present, the herdr hook present, every rule of `claude/deny.json` present.

### 4.3 The levels

Level 1, no prompt (in `agent-settings.json` → `permissions.allow`):

- Read, Glob, Grep: all paths (default in Claude Code).
- `Edit(~/repos/auspex/**)`, `Write(~/repos/auspex/**)`.
- `Bash(auspex facts*)`, `Bash(auspex plan*)`, `Bash(auspex status*)`, `Bash(auspex commands*)`, `Bash(auspex check*)`, `Bash(auspex system plan*)`, `Bash(auspex system prepare*)`, `Bash(auspex migrate --pending*)`.
- `Bash(git -C ~/repos/auspex status*)`, `Bash(git -C ~/repos/auspex diff*)`, `Bash(git -C ~/repos/auspex log*)`, `Bash(git -C ~/repos/auspex add*)`, `Bash(git -C ~/repos/auspex commit*)`. The existing deny rules for `git reset --hard`, force push and `git clean -f` stay in force.
- Read-only system commands: `Bash(hyprctl -j *)`, `Bash(hyprctl monitors*)`, `Bash(kscreen-doctor -o*)`, `Bash(journalctl *)`, `Bash(systemctl --user status*)`, `Bash(systemctl --failed*)`, `Bash(pacman -Q*)`, `Bash(nvidia-smi*)`.

Level 2, applied with an automatic undo point (in `agent-settings.json` → `permissions.allow`):

- `Bash(auspex apply*)`, `Bash(auspex undo*)`.
- Q1 answer: the agent applies personal desktop settings without asking. The generation is the undo point.

Level 3, always the operator (in `claude/deny.json`, merged into `~/.claude/settings.json`):

- Already present and kept: `Bash(sudo *)`, the destructive commands, power commands.
- Added by auspex:
  - `Bash(pkexec *)`, `Bash(run0 *)`, `Bash(su *)`;
  - `Bash(pacman -S*)`, `Bash(pacman -R*)`, `Bash(pacman -U*)`, `Bash(pacman -D*)`, `Bash(yay -S*)`, `Bash(yay -R*)`, `Bash(yay -U*)`, `Bash(yay)`, `Bash(paru *)`, `Bash(flatpak install*)`, `Bash(flatpak uninstall*)`, `Bash(flatpak update*)`;
  - `Bash(auspex system apply*)`, `Bash(auspex system undo*)`, `Bash(auspex-system-apply*)`, `Bash(auspex-system-undo*)`, `Bash(auspex bootstrap*)`;
  - `Bash(snapper *)` except `snapper list` (the rule set denies `Bash(snapper -c * create*)`, `Bash(snapper -c * delete*)`, `Bash(snapper -c * undochange*)`, `Bash(snapper -c * rollback*)`, `Bash(snapper rollback*)`);
  - `Bash(mkinitcpio *)`, `Bash(bootctl *)`, `Bash(grub-*)`;
  - `Edit(//etc/**)`, `Write(//etc/**)`, `Edit(//usr/**)`, `Write(//usr/**)`, `Edit(//boot/**)`, `Write(//boot/**)`.
- Direct edits of managed targets: `Edit` and `Write` deny rules for each managed target path in `manifest/user.tsv` (generated by `auspex check permissions --print`). The agent changes a target through the repo and `auspex apply`, so every change gets a generation. The rule for `~/.claude/settings.json` also stops the agent from editing its own permission rules.

Known limit: permission rules match tool calls, not effects. A Bash command such as `cp x ~/.config/hypr/hyprland.lua` is not an `Edit` call, so the `Edit` deny rule does not stop it. Level 1 allows only the listed Bash commands, so such a command still prompts the operator. In a headless run it is denied (section 8). OQ1 asks whether to add the Claude Code sandbox for the agent session.

The design expects 1 tuning pass after 1 week of use. `claude/agent-settings.json` is in the repo, so a tuning change is a normal commit plus `auspex apply`.

## 5. Machine facts (N3)

`auspex facts [--json] [--logs] [--section <name>]`, level 1, no sudo, no network.

Default output is markdown, with 1 `##` heading per section:

| Section | Content | Source |
|---|---|---|
| `host` | hostname, kernel, uptime, CPU model | `uname`, `/proc/cpuinfo` |
| `session` | `XDG_CURRENT_DESKTOP`, `XDG_SESSION_TYPE`, `hyprland` or `kde` or `none` (headless) | environment |
| `gpu` | GPU name, driver version, `nvidia_drm` `modeset` and `fbdev`, the 4 Hyprland env vars as set in this process | `nvidia-smi --query-gpu`, `/sys/module/nvidia_drm/parameters/*` |
| `display` | outputs, mode, refresh, scale, VRR | `hyprctl -j monitors` on Hyprland, `kscreen-doctor -o` on KDE, skipped headless |
| `auspex` | repo path and commit, dirty files, last generation, pending migrations, pending system steps, targets with drift | `auspex status` |
| `packages` | packages in `packages/*.list` that are not installed; count of foreign (AUR) packages | `pacman -Q`, `pacman -Qm` |
| `services` | failed system units, failed user units, auspex timer state and next run | `systemctl --failed`, `systemctl --user list-timers` |
| `journal` | count of `err` and higher messages this boot, by unit (top 10) | `journalctl -b -p err -o json` (the user is in `wheel`, which reads the system journal) |
| `disk` | free space on `/` and `/home` | `df` |

- `--logs` adds the last 30 journal lines of priority `err` or higher. Without `--logs` no journal text is printed, only counts. This follows Q3: log text reaches Claude only when a task needs it.
- `--json` prints 1 object with 1 key per section.
- Each section has a 3 s time limit. A section that fails prints `unavailable: <reason>` and the command still exits 0.
- Target run time: under 5 s on this machine.

## 6. The auspex skill (T1)

### 6.1 Files

```
agent/skills/auspex/
├── SKILL.md                     # entry point, under 150 lines
└── reference/
    ├── layout.md                # repo tree and the role of each folder
    ├── commands.md              # GENERATED by `auspex commands --markdown`
    ├── targets.md               # GENERATED from manifest/user.tsv
    ├── apply-undo.md            # section 3 in agent terms
    ├── permissions.md           # the 3 levels and what to do at each
    ├── hyprland.md              # where each Hyprland setting is, reload, window rules
    ├── kde.md                   # what the agent may change on KDE (only the shortcuts) and why
    └── system-steps.md          # how to write and prepare a system step
```

`auspex apply` installs the folder to `~/.claude/skills/auspex/` (tree mode).

### 6.2 What `SKILL.md` tells the agent

1. Run `auspex facts` 1st. Add `--logs` only when the task is about an error.
2. Change files in `~/repos/auspex`, never the target. Find the source file in `reference/targets.md`.
3. Commit, then run `auspex plan`, then `auspex apply --reason "<request>"`. Tell the operator the generation number and how to undo it.
4. For a system-tier change, write or edit a system step, commit it, and run `auspex system prepare <step>`. Never run sudo.
5. On KDE, change only the entries in `config/kde/`. For any other KDE setting, tell the operator which System Settings page to use.
6. If `auspex check skill` fails after a change to the repo layout, update the skill in the same commit.

The skill `description` names both desktops, so it triggers on requests such as "make the gaps smaller", "add a hotkey", "change my bar", "why is my game at 60 Hz".

### 6.3 Staleness check

`auspex check skill` fails when any of these is true:

1. `reference/commands.md` differs from the output of `auspex commands --markdown`.
2. `reference/targets.md` differs from the table that `auspex check skill --print-targets` makes from `manifest/user.tsv`.
3. A top-level folder of the repo is not named in `reference/layout.md`, or `layout.md` names a folder that does not exist.
4. A backticked repo path in any skill file (pattern: starts with a top-level folder name, such as `config/` or `bin/`) does not exist.
5. A backticked `auspex <words>` in any skill file does not route to a command.
6. `SKILL.md` is over 150 lines or has no `name` and `description` front matter.

`auspex check skill --fix` regenerates items 1 and 2. Items 3 to 6 need a human or agent edit.

`auspex check` runs `auspex check skill`, so a stale skill fails the repo check (section 11) and blocks a merge.

## 7. Agent command and hotkey (T5, T2)

### 7.1 `auspex agent`

```
auspex agent [--prompt <text>] [--cwd <dir>] [--window | --here]
auspex agent --headless --prompt <text> [--report <file>]
```

- Interactive: runs `claude --settings ~/.config/auspex/claude/agent-settings.json [<prompt>]` with `AUSPEX_ACTOR=agent`.
- Default working folder: `~/repos/auspex`. `--cwd` changes it.
- `--here` (default when stdout is a TTY): runs in the current terminal.
- `--window` (default with no TTY, for hotkeys): shows the `auspex agent` space in the herdr app (`herdr-app`), and opens the app when it is closed. With no such space it makes one that runs `auspex agent --here ...`. When the space has a live Claude Code terminal, it focuses that terminal. When Claude Code has ended there, or `--prompt` is given, it opens a new tab in the space that runs the agent. horch and hc work in that space as in any herdr app terminal.
- `--headless`: runs `claude -p --settings ~/.config/auspex/claude/headless-settings.json --disallowedTools Edit,Write,NotebookEdit` and writes stdout to the report file. Section 8 uses it.
- The flags `--settings`, `-p`, and `--disallowedTools` must exist in the installed Claude Code. `auspex check agent` verifies them through `claude --help`.
- No `--dangerously-skip-permissions` in any mode. This is the Omarchy risk that the design rejects.

### 7.2 Hotkeys

| Action | Hyprland | KDE |
|---|---|---|
| Agent window | `SUPER+ALT+A` | `Meta+Alt+A` |

The same keys work on both desktops. OQ5 asks the operator to confirm them. On this machine (checked 2026-11-25 in `~/.config/kglobalshortcutsrc`), KDE already uses `Meta+A` (next activity), `Meta+Shift+A` (previous activity), `Meta+Ctrl+A` (window demanding attention), and `Meta+grave` (walk through windows of the current application). `Meta+Alt+A` and `Meta+Alt+grave` are free. auspex does not rebind a KDE default, because that would change KDE config. `auspex check kde-shortcuts` fails if a key is already bound to another action in `~/.config/kglobalshortcutsrc`.

### 7.3 Dropdown console (removed)

The operator removed the dropdown key on 2026-11-25. The agent lives in the herdr app (7.1), so a 2nd terminal for it is not needed. `auspex agent dropdown`, `auspex check dropdown`, `config/ghostty/auspex-dropdown.ghostty`, `auspex-agent-dropdown.desktop` and the `special:agent` window rule are gone.

### 7.4 KDE shortcut mechanism

- `config/applications/auspex-agent.desktop` goes to `~/.local/share/applications/` (copy mode). They are not KDE config.
- `config/kde/agent-shortcuts.ini` holds 1 entry: `[services][auspex-agent.desktop] _launch=Meta+Alt+A`.
- `lib/merge/kglobalshortcuts` writes only this group with `kwriteconfig6 --file kglobalshortcutsrc --group services --group <file> --key _launch <value>`, and records the earlier values. Undo writes the earlier values back, or deletes the group.
- After a write it asks kglobalaccel to reload. The exact reload command is not verified on Plasma 6.8. The build spike tests it. If no reload works, the operator logs out and in once.
- This group is the only KDE config change in this spec (R10).

## 8. Weekly update check (N4 part 1)

Units in `systemd/user/`:

```ini
# auspex-update-check.timer
[Timer]
OnCalendar=Sun *-*-* 10:00
Persistent=true
RandomizedDelaySec=15m
[Install]
WantedBy=timers.target

# auspex-update-check.service
[Service]
Type=oneshot
ExecStart=%h/.local/bin/auspex update check
TimeoutStartSec=15m
```

`auspex update check` does:

1. Run `checkupdates` and `yay -Qua` itself and count the updates. This part needs no agent. If Claude is down or the limit is used, the notification still shows the counts.
2. Run `auspex agent --headless --prompt "<prompt>" --report ~/.local/state/auspex/reports/arch-update/<date>.md`. The prompt tells the agent to use the `arch-update` skill, to do only part 1 (gather and report), and to end with 1 line that starts `SUMMARY:`.
3. Send `notify-send --app-name=auspex --action=open=Open --wait "Arch update check" "<SUMMARY line or counts>"`. The `--wait` keeps the service alive until the operator acts on or dismisses the notification, up to the service time limit.
4. If the operator clicks Open: start `auspex agent --window --prompt "/arch-update Read <report path>. Continue from the report."`. The interactive agent then follows the skill, with the split pane for sudo.

`claude/headless-settings.json` allows only the read commands from the skill's gather table: `yay -Pw`, `checkupdates`, `yay -Qua`, `flatpak remote-ls --updates*`, `herdr --version`, `hc --version`, `claude --version`, `pacman -Q*`, `find /etc -name '*.pacnew'`, `uname -r`, `auspex facts*`. In `-p` mode Claude Code denies a tool call that no allow rule matches, because no one can answer a prompt. That makes the run read-and-report only (Q2).

Cost: 1 headless run per week.

Session note: a user timer runs while the user has a session. It runs under both KDE and Hyprland. `notify-send` works with Plasma's notification server and with mako.

## 9. Hyprland as a 2nd SDDM session

### 9.1 Session entry

- The `hyprland` package installs `/usr/share/wayland-sessions/hyprland.desktop`. SDDM then lists "Hyprland" beside "Plasma (Wayland)". No SDDM config changes.
- Do not install `uwsm` in this spec. It adds a 2nd session entry and its own env files. The env vars stay in the Hyprland config, as Omarchy does.
- SDDM keeps Plasma as the default session. SDDM remembers the last session the operator chose.

### 9.2 NVIDIA

In the Hyprland config only (`config/hypr/`), so KDE does not see them:

```
LIBVA_DRIVER_NAME=nvidia
__GLX_VENDOR_LIBRARY_NAME=nvidia
NVD_BACKEND=direct
GSK_RENDERER=ngl
```

- Early module loading: system step `020-nvidia-early-kms` (section 3.6), as Omarchy `install/hardware/nvidia.sh` does. It uses a drop-in file in `/etc/mkinitcpio.conf.d/`, so `/etc/mkinitcpio.conf` itself does not change. This change affects every boot, including KDE. It is a boot-level change, not KDE config.
- `nvidia_drm modeset=Y` and `fbdev=Y` are already set. No change.
- The `kms` hook stays in `HOOKS`. OQ2.

### 9.3 Packages (`packages/hyprland.list`)

All are in `extra` (checked 2026-11-25 with `pacman -Si`):

| Role | Package | Installed now |
|---|---|---|
| Compositor | `hyprland` 0.57.2 | No |
| Launcher | `fuzzel` | No |
| Bar | `waybar` | No |
| Notifications | `mako` | No |
| Lock | `hyprlock` | No |
| Idle | `hypridle` | No |
| Screenshots | `grim`, `slurp`, `satty`; `wl-clipboard` | No; yes |
| Audio | `pavucontrol`; `wpctl` comes with `wireplumber` | No; yes |
| Network | `network-manager-applet` | Yes |
| Bluetooth | `blueman` | No |
| Portal | `xdg-desktop-portal-hyprland`; `xdg-desktop-portal-gtk` for file dialogs | No; yes |
| Polkit agent | `hyprpolkitagent` | No |
| Media keys | `playerctl`, `brightnessctl` | No |

- Keyring: no new package. `pam_kwallet` is already in `/etc/pam.d/sddm`, so SDDM unlocks KWallet at login for either session. The Hyprland config runs `/usr/lib/pam_kwallet_init` at start. `gnome-keyring` is not installed. OQ6.
- Terminal: ghostty (installed). File manager: Dolphin (installed with Plasma).
- The Hyprland config file format follows Hyprland 0.57. Omarchy uses `.lua` files. The build checks the format with `Hyprland --verify-config` (section 11) before the 1st login.

### 9.4 Minimal Hyprland config

`config/hypr/` holds:

- Monitor: `DP-2`, `5120x2160@165`, position `0x0`, scale `1`. VRR off. These values match the current KDE setup (`kscreen-doctor -o`, 2026-11-25).
- Autostart: waybar, mako, hypridle, `hyprpolkitagent`, `nm-applet --indicator`, `blueman-applet`, `pam_kwallet_init`, and `dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP` so that portals and user services see the session.
- Binds: terminal, launcher, close, fullscreen, float toggle, workspaces 1 to 9, move to workspace, screenshot region (`grim -g "$(slurp)" - | satty -f -`), screenshot to clipboard, lock (`hyprlock`), volume and media keys, the 2 agent keys (section 7.2), logout.
- Idle: lock after 10 min, display off after 15 min. No suspend: the machine runs fleet workers.
- Input: keyboard layout copied from the current KDE setting (the build reads `~/.config/kxkbrc` once and writes the value into the repo).
- No theme. Default colors, default fonts, default gaps. The theme spec replaces these.

Browser keyring flags in `config/browser-flags/`, installed to `~/.config/chrome-flags.conf` and `~/.config/brave-flags.conf`:

```
--password-store=kwallet6
```

Reason: Chrome and Brave choose a password store from the desktop name. Under Hyprland they would pick a different store and could not read the cookies and passwords that KWallet holds. These files are not KDE config, but they also apply under KDE. OQ6 asks the operator to confirm that KDE already uses `kwallet6`, so the flag changes nothing there.

### 9.5 Window rules

| Program | Match | Rule |
|---|---|---|
| Steam main window | class `steam`, title `Steam` | tile |
| Steam dialogs | class `steam`, title not `Steam` | float, center |
| Steam games | class `steam_app_.*` | no rule except `idleinhibit fullscreen` |
| Battle.net | class `battle.net.exe` | float, center, size 1400×900 |
| Battle.net login and updater | title `Battle.net Login` or `Blizzard Battle.net` | float, center |
| Lutris | class `net.lutris.Lutris` | tile; dialogs float |
| Heroic | class `heroic` | tile; dialogs float |
| ProtonUp-Qt | class `net.davidotek.pupgui2` | float |
| gamescope | class `gamescope` | fullscreen, `idleinhibit always` |
| Any fullscreen window | fullscreen | `idleinhibit fullscreen` |
| File pickers | title `Open File` or `Save File` or portal class | float, center, size 50% |
| pavucontrol, blueman, nm-connection-editor | class | float |

- The exact class names come from `hyprctl clients` during the gaming acceptance run. The build records any class name that differs from this table and fixes the rule.
- No tearing (`allow_tearing`) and no VRR in this spec. The monitor setup keeps both off.

### 9.6 Gaming acceptance checklist

The operator runs this list once after the 1st login to Hyprland. The build writes it to `docs/checklists/hyprland-gaming.md` with a result column.

1. SDDM shows "Hyprland" and "Plasma (Wayland)".
2. Hyprland starts. `hyprctl monitors` shows `5120x2160@165`.
3. `auspex facts --section gpu` shows the 4 env vars and `nvidia-open` 620.70.06.
4. Steam opens. The library shows. Steam dialogs float.
5. 1 Proton game starts and runs at 165 Hz (MangoHud shows the frame rate and the refresh).
6. Lutris opens Battle.net. The Battle.net login window is usable and floats.
7. Heroic (flatpak) opens.
8. Discord screen share: share 1 window through the portal. The other side sees it.
9. Chrome opens with existing logins (KWallet works).
10. Screenshot region works. Lock works. Volume keys work. Network and Bluetooth tray icons show.
11. `SUPER+ALT+A` shows the agent in the herdr app.
12. Log out. Log in to Plasma. Plasma works as before: panels, shortcuts, wallpaper, KWallet, Steam. `Meta+Alt+A` shows the agent in the herdr app.

If item 12 fails, the operator runs `auspex undo` for the user tier and `auspex system undo` for the steps, from a TTY if needed.

## 10. KDE invariants

- The manifest has exactly 2 KDE-scoped items: `config/kde/agent-shortcuts.ini` (merge) and the 2 `.desktop` files. `auspex check kde-untouched` fails if any manifest target is under `~/.config/` and matches `k*`, `plasma*`, `kwin*`, `kde*`, or `*rc` other than these.
- No system step writes under `/etc/sddm.conf.d/`, `/usr/share/sddm/`, or `/usr/share/plasma/`.
- The mkinitcpio drop-in and the browser flags apply to both sessions. They are listed here so that the operator knows.

## 11. Test seams

All checks run without sudo. A check that needs a display says so. `auspex check` runs all of them that can run in the current environment and prints `skip` for the rest. The repo check for CI and for `horch ledger finish` is `auspex check --no-display`.

| Part | Check command | What it verifies | Display |
|---|---|---|---|
| Layout, router | `auspex commands --check` | every `bin/auspex-*` has headers and is executable; no collisions | No |
| Shell quality | `auspex check shell` | `shellcheck` on `bin/`, `lib/`, `migrations/`, `system/steps/`, `hooks/` | No |
| Apply, undo | `auspex check apply` (runs `bats tests/apply.bats`) | in a temp `HOME` with `AUSPEX_STATE` in a temp dir: plan, apply, drift stop, adopt, undo, redo, failed apply rollback, 50-generation pruning, `.absent` restore | No |
| Migrations | `bats tests/migrate.bats` | runs once, marker written, idempotent re-run, failure stops apply | No |
| Hooks | `bats tests/hooks.bats` | order, `$1`, failure is a warning | No |
| System steps | `auspex check system-steps` | each step defines `check`, `apply`, `undo`; headers say level 3; `bash -n`; no step path under the KDE deny list; `auspex system apply` refuses with `AUSPEX_ACTOR=agent` and with no TTY | No |
| Permission merge | `auspex check claude-settings` | merger on a copy of the live `~/.claude/settings.json` and on fixtures: valid JSON; 1 allow and 38 deny rules kept; herdr hook kept; owned list correct; a 2nd run changes nothing; removing a rule from `claude/deny.json` removes it only if owned | No |
| Permission levels | `auspex check permissions` | each `auspex:level=3` command has a deny rule; each level 1 and 2 command has an allow rule in `agent-settings.json` and none in `~/.claude/settings.json`; each managed target has Edit and Write deny rules; `headless-settings.json` has no Edit or Write allow | No |
| Agent flags | `auspex check agent` | `claude --help` lists `--settings`, `-p`, `--disallowedTools`; `auspex agent --dry-run` prints the expected command line for each mode | No |
| Facts | `auspex check facts` | `auspex facts --json` is valid JSON with all section keys; exits 0 with display sections `unavailable` when headless; finishes in under 5 s | No |
| Skill | `auspex check skill` | section 6.3 | No |
| Timer | `auspex check timer` | `systemd-analyze --user verify` on both units; `systemd-analyze calendar` on `OnCalendar`; `auspex update check --dry-run` prints the steps; a fake `claude` and fake `notify-send` on `PATH` in `bats tests/update-check.bats` | No |
| Hyprland config | `auspex check hyprland` | `Hyprland --verify-config -c <repo config>` when `hyprland` is installed, else `skip`; the 4 env vars are present; monitor line matches section 9.4 | No (needs the package) |
| Window rules | `auspex check hyprland-rules` | each row of section 9.5 has a rule in the config | No |
| KDE shortcuts | `auspex check kde-shortcuts` | merger on a fixture `kglobalshortcutsrc`: writes only 2 groups; undo restores the fixture byte for byte; no key conflict in the live file | No |
| KDE invariants | `auspex check kde-untouched` | section 10 | No |
| Gaming | `docs/checklists/hyprland-gaming.md` | section 9.6, by the operator | Yes, manual |

Test seams in the code:

- `AUSPEX` overrides the repo path. `AUSPEX_STATE` overrides `~/.local/state/auspex`. `HOME` in a temp dir moves every target.
- Each command that calls an external program (`claude`, `notify-send`, `hyprctl`, `kwriteconfig6`, `sudo`) calls it through `PATH`, so a test puts a fake first on `PATH`.
- `--dry-run` on `apply`, `undo`, `agent`, `update check`, and `system apply` prints what the command would do and changes nothing.

## 12. Build order

Each item is 1 ticket. Each ends with its check from section 11.

1. Layout, router, headers, `auspex commands`, `tests/` harness, `030-auspex-tools` step (bats, shellcheck, jq, pacman-contrib). The operator runs that step once.
2. Apply, plan, undo, status, generations, migrations, hooks (N1 user tier).
3. System steps runner: `system plan`, `prepare`, `apply`, `undo`.
4. Permission files and the Claude settings merger (N2).
5. `auspex facts` (N3).
6. The auspex skill and `auspex check skill` (T1).
7. Spike: ghostty quick terminal on KWin, and kglobalaccel reload (30 min, results into `kde.md` and OQ4).
8. `auspex agent`, desktop files, KDE shortcuts (T5, T2 on KDE).
9. Weekly timer (N4 part 1).
10. Hyprland: packages step, NVIDIA step, config, window rules, Hyprland hotkeys and dropdown (T2 on Hyprland).
11. Operator runs the gaming checklist. The build fixes class names and rules.

Items 1 to 9 work before Hyprland is installed. This matches the design's slice order.

## 13. Follow-ups (not in this spec)

- Theme spec: Empire Legion palette (`themes/`, I3 templates in `templates/`, `render` mode), SDDM theme, plymouth, wallpapers, Claude Code colors (T4), Hyprland and waybar styling.
- AI-first slice 2, in the design's order: N6 fleet on the desktop, T3 crash handoff, N5 game doctor, N7 screen to agent (with T6 OCR), N8 drift check, T7 dictation.
- N4 part 2: a hotkey for `import-media`.
- `~/.claude/CLAUDE.md` in the repo (T8).

## Open Questions

- **OQ1. Add the Claude Code sandbox to the agent session?** Permission rules match tool calls, so a Bash `cp` into a target is not an `Edit` call. Level 1 allows only listed Bash commands, so such a command prompts the operator, but a prompt is easy to approve by habit. Recommendation: not in this spec. Keep the prompts, and review the tuning pass after 1 week. Add the sandbox in a later spec if the operator sees such prompts.
- **OQ2. Keep the `kms` hook in mkinitcpio?** The Arch wiki suggests removing `kms` from `HOOKS` with the NVIDIA driver, so that nouveau does not load early. Omarchy's `nvidia.sh` adds the 4 modules. Recommendation: keep `kms` and add only the modules. `nvidia-utils` already blacklists nouveau, the system boots now with `kms`, and a smaller change is safer for a boot-level step. Revisit only if the 1st boot shows nouveau in `lsmod`.
- **OQ3. Allow the user to make `home` snapshots?** `ALLOW_USERS=""` in both snapper configs, so `auspex apply` cannot make a snapshot without sudo. Recommendation: add a system step `040-snapper-home-user` that sets `ALLOW_USERS="lordvader"` in the `home` config only. The generation folder already gives undo, so this is a backup, not a requirement. The spec works without it.
- **OQ4. KDE dropdown: ghostty quick terminal or a KWin window rule?** Neither is verified on this machine. Recommendation: spike the ghostty quick terminal first (build item 7). If it fails, use the KWin window rule with a ghostty window. Do not use Yakuake, because it is a 2nd terminal program with its own config.
- **OQ5. Which keys?** Recommendation: `Meta+Alt+A` for the agent window and `Meta+Alt+grave` for the dropdown on both desktops. These are free in KDE today. `Meta+A` and `Meta+grave` are KDE defaults, and taking them would change KDE config. Omarchy uses `SUPER+SHIFT+CTRL+A`, which is hard to press inside a game. The operator may prefer other keys if a game uses these.
- **OQ6. Keyring under Hyprland: KWallet or gnome-keyring?** Chrome and Brave choose a password store from the desktop name. Recommendation: KWallet in both sessions, with `--password-store=kwallet6` in the browser flag files. KWallet already holds the browser secrets, and SDDM already unlocks it through `pam_kwallet`. The build must 1st confirm that KDE uses `kwallet6` today (Chrome `chrome://settings/passwords` shows saved passwords, and `kwallet-query -l kdewallet` lists a "Chrome Keys" folder). If KDE uses a different store, the flag must match that store.
- **OQ7. Discord screen share under Hyprland.** The native `discord` package has weak Wayland screen share. Recommendation: test it as checklist item 8. If it fails, try the Discord web app in Chrome (the portal works there) before any other client change. A client change is a separate decision.
- **OQ8. Omarchy commit.** The research report cites commit `8807715`, and the design cites `81f25a5`. Recommendation: the build reads Omarchy `install/hardware/nvidia.sh` at `8807715`, the commit of the research report, and notes in the step header which commit it follows.
