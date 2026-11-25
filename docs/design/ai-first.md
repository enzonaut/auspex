# Design: the AI-first layer of auspex

- Date: 2026-11-25.
- Inputs: `docs/research/omarchy-ai-first.md` (items AI-1 to AI-18), the Omarchy source at commit `81f25a5` (read only, nothing run), and read-only checks on this machine.
- This is a design. Nothing in it is built or installed yet.

## Terms used in this document

- **Agent**: an AI program that reads files and runs commands for you. On this machine the agent is Claude Code.
- **Skill**: a folder of written instructions that teaches the agent one job. `arch-update` and `import-media` are skills you already have.
- **Hyprland**: the new desktop that auspex adds beside KDE Plasma. You pick one of the two at login.
- **Bar**: the strip at the top of a Hyprland desktop that shows the clock, workspaces and status icons.
- **Hotkey**: a key combination that works anywhere on the desktop.
- **sudo**: the command that asks for your password before it changes system files.
- **Snapshot**: a saved copy of the disk state that the system can return to. This machine already takes them with a tool named snapper.
- **Headless run**: the agent runs once in the background with no window, prints a result, and exits.
- **Journal**: the system log of Linux.
- **Crash dump**: the file Linux saves when a program crashes.
- **Proton**: the Steam layer that runs Windows games on Linux.
- **OCR**: reading the text out of a picture.
- **Fleet**: your herdr and horch setup, which runs several Claude Code workers in panes.

## What Omarchy does

Omarchy treats the agent as a part of the desktop, in the same way as the terminal or the browser. A day of use looks like this:

1. **First login.** A notification asks you to pick a default agent. You sign in once.
2. **One key away.** A hotkey opens the agent in its own terminal. A second hotkey drops a console down over the top half of the screen and hides it again.
3. **"Change my desktop."** You tell the agent "make the window gaps smaller" or "add a hotkey for Discord". The agent can do it because Omarchy ships a skill that describes where every setting is.
4. **A glance at the bar.** An icon in the bar opens a panel that shows how much of your subscription limit is used.
5. **A crash.** A program crashes. A notification appears. You click it, and the agent opens with the crash dump and explains the cause.
6. **Screen and voice.** One hotkey copies the text from any region of the screen. Another lets you talk and types your words.
7. **A theme switch.** The agent's colors change with the rest of the desktop.
8. **Optional extras.** 22 agents to choose from, several subscriptions side by side, and AI models that run on your own machine.

Omarchy's weak points matter for auspex:

- **Safety is advice, not a mechanism.** The hotkey starts the agent in a mode that does not ask before it acts. The manual says to "be ready to rollback changes" or reinstall all configs if the agent "makes a mess". There is no automatic undo.
- **Nothing runs on a schedule.** The agent only acts when you open it.
- **No knowledge of your machine.** The skill describes Omarchy, not your hardware, your games or your logs.
- **No gaming help and no fleet view.** The panel shows usage limits, not what running agents are doing.

## What auspex should take

Cost: S is under 1 day, M is 1 to 3 days, L is more than 3 days. "Needs" states which desktop the feature depends on.

| Code | Feature (Omarchy item) | Verdict | User value | Cost | Risk | Needs |
|---|---|---|---|---|---|---|
| T1 | The auspex skill: instructions that tell the agent how this repo and this desktop are laid out (AI-6) | Take | You say "change X on my desktop" and the agent knows which file to edit. | M | Low. The skill goes stale when the repo layout changes, so it must be updated with the repo. | Neither. One skill covers both desktops. |
| T2 | Agent hotkey and dropdown console (AI-2, AI-3) | Take | The agent is one key away from anywhere, including from inside a game menu. | S on Hyprland. M on KDE. | Low. On KDE the dropdown uses a ghostty feature that is not tested on this machine. | Both. Each desktop needs its own setup. |
| T3 | Crash handoff: a crash shows a notification, and a click opens the agent on the crash dump (AI-10) | Take | A crash becomes an explanation with no work from you. | S | Low. Games crash often, so each program needs a mute option. | Neither. |
| T4 | Theme colors in Claude Code (AI-7) | Take, in the theme phase | Claude Code matches the Galactic Empire Legion theme. | S | Low. | Neither. |
| T5 | `auspex agent` command: one command that starts the agent, with or without a starting request (AI-1) | Take | Hotkeys, notifications and timers all open the agent in the same way. | S | Low. | Neither. |
| T6 | Screen text to clipboard (AI-13) | Take, as part of N7 below | You copy text from a game, a video or an error window. | S | Low. | Both. Each desktop uses a different capture tool. |
| T7 | Dictation: talk in place of typing (AI-12) | Take later | You speak a long request to the agent. | M | Medium. Typing the words into the active window is the hard part, and it is not tested on either desktop. | Both. |
| T8 | One instruction file for the agent, kept in the repo (AI-5) | Take, in a small form | Your standing rules for the agent survive a reinstall. | S | Low. The current file must be merged in, not replaced. | Neither. |
| - | Agent status in herdr (AI-17) | Already done | herdr already receives the state of each Claude Code session on this machine. | 0 | None. | Neither. |
| - | Hotkey agent that never asks permission (AI-1, AI-4) | Do not take | - | - | An agent with no prompts on the machine that also holds your games and passwords is the main risk Omarchy accepts. N2 below replaces it. | - |
| - | Usage panel in the bar (AI-8) | Do not take as built | - | L | Omarchy's panel needs its own desktop shell. N6 below gives the same information for less work. | - |
| - | Several subscriptions (AI-9) | Do not take | - | - | You have 1 subscription. | - |
| - | 22 agents and a default-agent picker (AI-1, AI-18) | Do not take | - | - | You use 1 agent. A picker adds upkeep and no value. | - |
| - | AI models on your own machine (AI-11) | Not now | - | M | The RTX 4090 can run one, but it would compete with games for the GPU and is weaker than Claude. It becomes useful only if you answer "no" to Q3. | - |
| - | AI web apps, desktop apps, browser extension (AI-14 to AI-16) | Do not take | - | - | These are app installs, not design. The Claude browser extension is already in use. | - |

## What auspex adds beyond Omarchy

| Code | Feature | User value | Cost | Risk | Needs |
|---|---|---|---|---|---|
| N1 | **Safe apply and undo.** The agent edits only this repo. One command shows what will change, saves a snapshot, applies the change, and records it. A second command returns to the state before. | You can let the agent change the desktop, because any change is undone with 1 command. | M | Medium. A full-disk snapshot restore would also undo unrelated files, so undo must restore only the files auspex manages. The snapshot is the last-resort backup. | Neither. |
| N2 | **Permission levels.** 3 fixed levels, enforced by Claude Code's own permission settings and not only by instructions. Level 1 (no prompt): read anything, edit the repo. Level 2 (applied with automatic undo point): your personal desktop settings. Level 3 (always you): anything that needs sudo, packages, the login screen, the boot process, the GPU driver. For level 3 the agent prepares the command in a visible pane and you run it and type the password. | You know exactly what the agent can do without you, and it never holds your password. | S | Low. Rules that are too strict cause many prompts, so the list needs 1 tuning pass after a week of use. | Neither. |
| N3 | **Machine facts for the agent.** One command prints hardware, which desktop is running, GPU driver version, packages that differ from the repo, failed services, and recent journal errors. The auspex skill tells the agent to run it first. | The agent's answers fit this machine, and you stop explaining your setup. | S | Low to medium. Journal text is sent to Claude's servers. It runs only when a task needs it (see Q3). | Neither. |
| N4 | **Scheduled and hotkey runs of your skills.** A weekly timer runs the `arch-update` check as a headless run and shows the result as a notification. A click opens the agent to do the update with you. A hotkey starts `import-media`. | The weekly check happens without you, and the routine jobs are 1 key away. | M | Medium. An agent that runs alone must be limited to level 1 (read and report). Each run uses some of your subscription limit. | Neither for the timer. Both for the hotkey. |
| N5 | **Game doctor skill.** When a game crashes or will not start, the agent reads the Proton log, the Steam, Lutris or Heroic log, and the GPU state. It names the likely cause and proposes a fix: a different Proton version or a launch option. It changes a per-game setting only after you confirm. | A broken game gets a diagnosis in 1 minute, not an evening of forum searches. | M | Medium. A diagnosis can be wrong. The skill must never edit game files, because anti-cheat systems can ban for that. | Neither. |
| N6 | **Fleet on the desktop.** The bar shows how many fleet workers are working, waiting on you, or done, and how much of the Claude limit is used. A notification fires when a worker needs you. A hotkey jumps to the fleet. | You can play or browse while the fleet works, and you see when it needs you. | M | Low. It depends on which bar the theme phase picks. On KDE it gives the notification and the hotkey only, because a KDE panel widget costs L. | Bar: Hyprland. Notification and hotkey: both. |
| N7 | **Show the agent a part of the screen.** A hotkey lets you draw a box on the screen. The picture opens in the agent with your question. It includes T6: a second key copies the text only. | You ask "what does this error mean?" about anything on screen, with no retyping. | S, after T2 and T5 | Low to medium. The picture is sent to Claude's servers, so it captures only the box you draw and never the full screen on its own. | Both. |
| N8 | **Drift check.** The agent compares the live system with the repo and lists what was changed by hand: a package you installed, a setting you changed in a settings window. It proposes to record each one in the repo. | The repo stays a true copy of your system, so a reinstall gives back the same machine. | M | Low. It only reports. KDE stores many settings in files that change on their own, which causes false alarms. | Neither. |

Features from the brief that are covered above: config access with safe apply and rollback (T1, N1), skills from a hotkey or schedule (N4), system context (N3), gaming (N5), voice, screen and dropdown console (T7, N7, T2), fleet on the desktop (N6), safety (N2).

## Recommended first slice

6 features, in build order. All 6 work before Hyprland is installed, except the hotkey part of step 5.

| Order | Feature | Reason for this position |
|---|---|---|
| 1 | N2 Permission levels | The rules come before the agent gets any new power. Every later feature relies on them. |
| 2 | N1 Safe apply and undo | The agent needs a way to change the system that can be undone before it is taught how to change it. This step also defines the "install step" that the repo does not have yet. |
| 3 | N3 Machine facts | It is small, and the skill in step 4 starts each task by calling it. |
| 4 | T1 The auspex skill | This is the main value Omarchy offers. It is safe to add now because steps 1 to 3 exist. |
| 5 | T5 + T2 `auspex agent` command, hotkey and dropdown console | The first thing you can see and press. It comes after step 4 so that the agent it opens already knows the system. |
| 6 | N4 Weekly `arch-update` check on a timer | The first job that runs without you. It uses a skill you already trust and exercises steps 1, 3 and 5 together. |

Second slice, in this order: N6 (fleet on the desktop, after the bar exists), T3 (crash handoff), N5 (game doctor), N7 (screen to agent), T4 (with the theme), N8, T7.

## Questions for the operator

- **Q1. How much may the agent apply on its own?** Recommended: it applies changes to your personal desktop settings without asking, with an automatic undo point, and it always stops for anything that needs sudo. The stricter option is that it asks before every apply.
- **Q2. May the agent run on a schedule when you are not watching?** Recommended: yes, but only to read and report (the weekly update check). Jobs that move or change files, such as `import-media`, start only from a hotkey.
- **Q3. May system logs, game logs and screen captures be sent to Claude?** N3, N5, N7 and T3 send this text or picture to Anthropic's servers. Recommended: yes, and only when you start the task. If the answer is no, those 4 features need a model that runs on this machine, which costs more and answers worse.
- **Q4. Do you want voice input?** It is the least certain feature (T7). Recommended: leave it out until the first 2 slices are in use.
- **Q5. How visible should the fleet be on the desktop?** Recommended: a small always-visible counter in the Hyprland bar plus a notification when a worker needs you. The quieter option is the notification only.

## Facts checked on this machine, and what is not checked

Checked (read only, 2026-11-25):

- Claude Code 2.1.332, ghostty 1.4.0 and herdr 0.9.5 are installed. Claude Code has a headless mode (`claude -p`).
- The disk uses btrfs. snapper has configs for `/` and `/home`, and `snap-pac` takes a snapshot around each package change. N1 builds on this.
- Claude Code already has permission rules in `~/.claude/settings.json` (1 allow rule, 38 deny rules) and a herdr status hook. N2 extends these rules.
- `horch quota` already prints the Claude limit use, and `herdr agent list` prints the worker states. N6 reads both.
- The crash dump service (`systemd-coredump`) is active. `tesseract` (OCR), `spectacle` (KDE screen capture), `wl-copy` and `notify-send` are installed.
- Hyprland, a bar, `grim`, `slurp`, a text-typing tool and a dictation program are not installed.
- This repo holds only `README.md` and the research report. There is no install step yet.

Not checked:

- The ghostty dropdown terminal under KDE (T2 on KDE).
- KDE hotkeys set from a file (T2, N4, N7 on KDE).
- How dictated text is typed into the active window on either desktop (T7).
- The list of existing snapshots, which needs sudo to read.
