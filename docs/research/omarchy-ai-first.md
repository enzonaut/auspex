# Omarchy AI-first features: research for auspex

## Scope

- Source examined: `github.com/omacom/omarchy` at commit `8807715c71210071487c92afca594ba569219709` (2026-11-25), cloned read-only. No script from the clone was run.
- Website: https://omarchy.org, fetched 2026-11-25. The manual pages on the site come from the `manual/` folder in the repo, so this report cites the repo files.
- All paths below are relative to the repo root unless they start with `~` or `/`.
- Target machine: Arch, KDE Plasma on Wayland, SDDM with the default theme, ghostty, Claude Code, herdr/horch, 1 ultrawide monitor.
- Out of scope: the Rome / Star Wars theme design (phase 2), and the KDE-vs-Hyprland decision.

## Short answer

Omarchy is Arch + Hyprland + a Quickshell desktop shell. It calls itself "The malleable OS for the age of agents" (https://omarchy.org) and "beautiful, fun & agentic" (`README.md`). The AI features fall into 3 layers:

1. **Shell-level plumbing.** This layer works on any desktop: one default-agent launcher, one shared `AGENTS.md` linked into every agent harness, shared agent skills linked into every harness, theme colors pushed into Claude Code and other agents, crash dumps handed to the agent, local models in Podman, and terminal aliases.
2. **Desktop entry points.** This layer depends on Hyprland and Quickshell: global keybinds, a Quake-style agent console, an agents panel in the top bar with usage meters, OCR and dictation keybinds.
3. **Content.** The skills teach an agent how to change Omarchy itself (`default/agents/skills/omarchy/`). This content is Hyprland-specific, but the pattern is portable.

Layer 1 transfers to KDE almost unchanged. Layer 2 needs KDE equivalents. Layer 3 must be rewritten for KDE.

## 1. Inventory of AI items

Each item gives what it is, the repo path, what it does, and its dependency on Hyprland or another Omarchy-only part.

### AI-1 Default agent launcher (`omarchy agent`)

- Path: `bin/omarchy-agent`, `bin/omarchy-default-agent`, `bin/omarchy-agent-prompt`, `manual/17-ai.md:40-48`.
- Function:
  - Starts the user's chosen coding agent and parses flags (`bin/omarchy-agent:1-57`).
  - When launched from `$HOME`, it changes to `~/Work` (`bin/omarchy-agent:61`).
  - It reads the default agent from `omarchy-default-agent` (`:68`) and installs a missing CLI (`:115-130`).
  - Each agent runs in its auto-approve mode. For Claude this is `claude --permission-mode auto` (`:155-156`).
  - `omarchy agent prompt "..."` starts the agent with a prompt (`bin/omarchy-agent-prompt`).
  - 22 agent CLIs are supported (`manual/17-ai.md:5-28`). They are packaged in Omarchy's own repo, and their own updaters are turned off (`manual/17-ai.md:34-36`).
- Dependency: the core is bash. `--pick` opens the Quickshell agents panel through `omarchy-shell omarchy.agents open` (`bin/omarchy-agent:98-111`), so it is Omarchy-only. The auto-install step uses Omarchy's package repo, which is also Omarchy-only.

### AI-2 Agent keybinds

- Path: `default/hypr/bindings/utilities.lua:118` binds `SUPER + SHIFT + CTRL + A` to `omarchy-agent --pick`. `:126` binds `SUPER + CTRL + X` to the agents panel.
- Function: a single global key starts the agent or opens the panel.
- Dependency: Hyprland (Lua bind config) and Quickshell (panel).

### AI-3 Quake-style agent console

- Path: `default/hypr/qconsole.lua:1-30` and `default/hypr/bindings/tiling.lua:35,37`.
- Function:
  - Creates a Hyprland special workspace `special:qconsole` that covers 50% of the screen.
  - On first creation it runs `omarchy-agent --pick`.
  - `SUPER + grave` toggles it, and `SUPER + SHIFT + grave` moves a window into it.
- Dependency: Hyprland special workspaces.

### AI-4 Terminal aliases

- Path: `default/bash/aliases:47-51`.
- Function: `a` runs `omarchy-agent --inline`, `c` runs `opencode --auto`, `cx` clears the screen and runs `claude --permission-mode auto`, `cy` runs `codex --approve-for-me`, and `ca` runs `agy --dangerously-skip-permissions`.
- Dependency: none except `a`, which needs AI-1.

### AI-5 Shared agent instructions (`~/.agents/AGENTS.md`)

- Path: `bin/omarchy-agent-instructions`, `manual/17-ai.md:52`.
- Function:
  - The canonical file is `~/.agents/AGENTS.md` (`:29`).
  - The script links it into each harness's own instruction file, for example `~/.claude/CLAUDE.md` and the files for codex, pi, opencode, agy, grok, qwen, mcode, kilo and freebuff (`:39-51`).
  - An existing file is kept as `.bak` (`:61-64`).
- Dependency: none. It is plain symlinks.

### AI-6 Shared agent skills

- Path: `bin/omarchy-agent-skills-link`, `default/agents/skills/`, `manual/17-ai.md:130-132`.
- Function:
  - Links seven skills into `~/.agents/skills`, `~/.claude/skills`, `~/.codex/skills`, `~/.pi/agent/skills`, `~/.gemini/config/skills` and `~/.hermes/skills` (`bin/omarchy-agent-skills-link:23`).
  - The seven skills are `omarchy`, `omarchy-contribute`, `omarchy-diagnose-crash`, `omarchy-make-app`, `omarchy-make-game`, `omarchy-make-plugin` and `omarchy-make-theme`.
  - A folder of the user's own with the same name wins (`:41-44`), and stale links are removed (`:30-36`).
  - The `omarchy` skill triggers on edits to `~/.config` (hypr, ghostty and others), keybindings, themes and the bar. It has sub-files for apps, capture, hooks, hyprland, shell, system and theming. It sets safety rules for `sudo` vs `pkexec` (`default/agents/skills/omarchy/SKILL.md`).
  - The manual calls the skills experimental and suggests plan mode first (`manual/17-ai.md:130-132`).
- Dependency: the linking mechanism has none. The skill content describes Hyprland, Quickshell and `omarchy-*` commands, so it is Omarchy-only.

### AI-7 Theme sync into agents

- Path: `default/themed/claude.json.tpl`, `bin/omarchy-theme-set-claude`, `bin/omarchy-restart-opencode`, `bin/omarchy-theme-set:552-579`. Other templates exist for other agents: `pi.json.tpl`, `hermes.yaml.tpl`, `t3code.*.tpl` and `herdr-app.json.tpl`.
- Function:
  - The template maps the palette onto Claude Code theme keys: `claude`, `text`, `permission`, `success`, `error` and others.
  - `omarchy-theme-set-claude` copies the result to `$CLAUDE_CONFIG_DIR/themes/omarchy.json`. With `--activate` it sets `settings.json .theme = "custom:omarchy"` through `jq`.
  - A comment in the script says Claude Code hot-reloads `~/.claude/themes`. This is not verified on this machine's Claude Code version.
  - A theme switch runs these commands in the `other_theme_commands` group (`bin/omarchy-theme-set:566-579`).
- Dependency: none for the Claude part. It needs a `colors.toml` palette and a template renderer, which is `omarchy-theme-set-templates` in Omarchy.

### AI-8 Agents panel with usage meters

- Path: `shell/plugins/agents/` (`Main.qml`, `Panel.qml`, `manifest.json`, `collectors.py`), about 25 `bin/omarchy-agent-usage-*` collectors, `docs/agent-usage-collectors.md`, `manual/17-ai.md:56-58`.
- Function:
  - The panel in the top bar shows 5-hour and weekly subscription limits for each agent and account.
  - It has "Make something cool" starter prompts for a theme, plugin, app or game.
  - The data refreshes every 15 minutes through `omarchy agent usage update`.
  - Each collector is Python that prints JSON records.
- Dependency: Quickshell for the panel. The collectors are CLI programs. Whether they run outside Omarchy is not verified, because they import `shell/plugins/agents/collectors.py`.

### AI-9 Multiple subscription accounts

- Path: `bin/omarchy-agent-account-*`, `manual/17-ai.md:62-74`, `bin/omarchy-agent:354`.
- Function:
  - Adds and switches between more than one Claude, Codex or Grok login with `omarchy agent account add|use|copy|threshold`.
  - For Claude, each account lives in its own `CLAUDE_CONFIG_DIR`.
  - A notification fires at 95% of a limit.
  - MCP servers added with `claude mcp add` reach every Claude account (`manual/17-ai.md:74`).
- Dependency: the mechanism is environment variables. The notification and the panel are Omarchy-only.

### AI-10 Crash diagnosis by agent

- Path: `bin/omarchy-crash-watch`, `default/systemd/user/omarchy-crash-watch.service`, `bin/omarchy-agent-crash`, `default/agents/skills/omarchy-diagnose-crash/`, `manual/17-ai.md:78-82`.
- Function:
  - A systemd user service follows `journalctl -f` for the systemd-coredump `MESSAGE_ID` (`bin/omarchy-crash-watch:49`).
  - It sends a critical notification with `--exec omarchy-agent-crash <pid> <comm> <exe> <signal>` (`:40-45`).
  - A click starts the agent with a prompt to examine the dump with the diagnose-crash skill (`bin/omarchy-agent-crash:52`).
  - Other commands: `omarchy agent crash <pid>`, `omarchy toggle crash-capture` and `omarchy crash mute`.
- Dependency: systemd-coredump and journalctl are generic. `omarchy-notification-send --exec` is an Omarchy notification helper. A code comment says the Quickshell notification server "never emits ActionInvoked" (`:35-39`). On KDE a standard libnotify action is the equivalent.

### AI-11 Local models

- Path: `bin/omarchy-models`, `bin/omarchy-models-launchers`, `bin/omarchy-models-warmup`, `shell/plugins/local-models/Models.qml`, `docs/local-models.md`, `manual/17-ai.md:98-126`, migration `migrations/1793563475.sh`.
- Function:
  - `omarchy models use best text` runs a model in a Podman container that has no network.
  - It serves an OpenAI-compatible endpoint at `http://127.0.0.1:11435/v1`, with the key in `~/.config/omarchy/agent-local/key`.
  - The "local" agent drives it through `pi` (`bin/omarchy-agent:80-93`).
  - The backend is a separate package, `omarchy-local-ai` (https://github.com/omacom/omarchy-local-ai).
  - The manual also recommends LM Studio (GUI) and Ollama (CLI) (`manual/17-ai.md:126`).
- Dependency: Podman and the `omarchy-local-ai` package. The panel UI needs Quickshell.

### AI-12 Dictation

- Path: `bin/omarchy-dictation*`, `bin/omarchy-install-dictation-*`, `bin/omarchy-voxtype-*`, `default/hypr/bindings/dictation.lua:29,46`, `default/hypr/dictation-backend.lua`, `manual/11-text-extraction-dictation.md`.
- Function:
  - Speech to text with 3 backends: Superwhisper (the default, cloud), Voxtype (a local model of about 150 MB) and Hex.
  - Hold Right Alt to talk, or toggle with `Alt + Space`.
  - `omarchy dictation start|stop|toggle`. The selection is kept in `~/.config/omarchy/defaults/dictation`.
  - The backend plugin contract is `omarchy-dictation-<backend>`.
- Dependency: the keybinds are Hyprland. How the text is typed into the focused window is not verified, because no `wtype`/`ydotool` call was found in the dictation scripts. The backends are separate programs.

### AI-13 OCR to clipboard

- Path: `bin/omarchy-capture-text`, `default/hypr/bindings/utilities.lua:52`.
- Function: `Super + Ctrl + PrtScr` selects an area with `slurp`, captures it with `grim`, runs `tesseract` and copies the text with `wl-copy` (`bin/omarchy-capture-text:14-25`).
- Dependency: `hyprpicker` freezes the screen (`:14`), which is Hyprland-oriented. `grim` needs the wlr-screencopy protocol, and KWin does not provide it (not verified on this machine).

### AI-14 AI web apps

- Path: `manual/25-web-apps.md:29-39`, `bin/omarchy-launch-webapp`, `bin/omarchy-webapp-install`.
- Function: ChatGPT (`Super + Shift + A`) and Grok (`Super + Shift + Alt + A`) open as Chromium app windows.
- Dependency: the keybinds are Hyprland. The app windows are a Chromium `--app=` window, which works anywhere (not verified that the launcher uses only `--app`).

### AI-15 AI desktop apps

- Path: `manual/17-ai.md:86-94`, `bin/omarchy-install-ai-{chatgpt,claude,herdr,hermes,openclaw,t3-code}`, `bin/omarchy-remove-ai-*`.
- Function: one-command installs for Amp, Antigravity, ChatGPT, Claude desktop, Grok Bot, Herdr Desktop, Hermes, OpenClaw, Perplexity and T3 Code.
- Dependency: the packages come from Omarchy's repo. Whether each is also in AUR is not verified.

### AI-16 Chromium Claude extension

- Path: `bin/omarchy-install-chromium-claude`, `manual/17-ai.md:40-48`.
- Function: choosing Claude as the default agent also installs the Claude browser extension.
- Dependency: Chromium browser policy. This is not desktop-specific.

### AI-17 herdr integration for agents

- Path: `bin/omarchy-agent-integrate-herdr`, `bin/omarchy-theme-set-herdr-app`, `docs/theming.md` ("Herdr desktop app").
- Function:
  - After an agent CLI is installed, the script runs `herdr integration install <target>` for status and session restore. Targets include claude, codex, opencode, pi, cursor and others.
  - Theme switches also write Herdr's palette, and they can push the theme to remote machines with `herdr machine list` targets. This sync is off by default.
- Dependency: herdr only. The operator already uses herdr.

### AI-18 First-boot agent setup

- Path: https://omarchy.org ("On first boot, Omarchy invites you to choose a default agent, sign in, and put it to work").
- Function: onboarding picks the default agent.
- Dependency: Omarchy installer and shell. The exact repo path was not traced (not verified).

### Search coverage

- `mcp`: there is no MCP server or MCP config shipped. The only reference is that `claude mcp add` servers reach all Claude accounts (`manual/17-ai.md:74`).
- `ollama`: it is recommended, not integrated (`manual/17-ai.md:126`). Ollama Cloud appears as a usage source in the agents panel (`manual/17-ai.md:56`).
- `gemini`: reached through Antigravity (`agy`) and its skills directory `~/.gemini/config/skills`.
- `cursor`: `cursor-agent` is in the agent table and has herdr integration.
- `copilot`: it is in the agent table and the usage panel.

## 2. Theming structure

### Theme folder layout

- First-party themes are in `themes/<name>/`. There are 23, for example `tokyo-night`, `gruvbox`, `nord`, `lumon`, `hackerman` and `retro-82`. User themes are in `~/.config/omarchy/themes/<name>/` (`docs/theming.md`).
- A minimal theme is `colors.toml`, plus optional hand-written overrides. One example theme folder holds `colors.toml`, `neovim.lua`, `vscode.json`, `preview.png`, `preview-unlock.png` and `unlock.png`.
- Optional parts (`docs/theming.md`):
  - `backgrounds/`, with optional `backgrounds/intros/*.mp4` that play at login or on a theme switch, and `backgrounds/loops/*.mp4` that play as live wallpaper;
  - `keyboard.rgb`;
  - a `light.mode` marker.
- Built-in backgrounds, intros and loops ship as separate packages: `omarchy-themes-backgrounds`, `-intros` and `-loops`.
- `colors.toml` is the single palette:
  - semantic keys `accent`, `selection` and `muted`;
  - a background ramp (`background`, `dark_background`, `darker_background`, `lighter_background`);
  - a foreground ramp;
  - named colors (`red`, `blue` and others) (`docs/theming.md`, section "colors.toml").

### Apps each theme covers

Templates in `default/themed/` render one file per app from `colors.toml`: alacritty, btop, chromium, claude (Claude Code), fcitx5, foot, ghostty, gum, helix, herdr-app, hermes, hyprland, the hyprland share picker CSS, keyboard RGB, kitty, neovim, obsidian, pi, Qt (`qtengine.colors`), the Quickshell shell (`shell.toml`), t3code and vscode. Other retint commands in `bin/omarchy-theme-set:552-579` add icons, tmux, opencode, hunk, GNOME/GTK, the browser policy and the keyboard backlight.

### How a theme switch is applied

From `docs/theming.md` ("Theme activation flow") and `bin/omarchy-theme-set`:

1. Stage into `~/.local/state/omarchy/current/next-theme`: copy `themes/<name>/`, then overlay the user's theme folder.
2. Render the `*.tpl` templates. User templates in `~/.config/omarchy/themed/` go first. A hand-written file in the theme is never overwritten.
3. Move the staged theme to `~/.local/state/omarchy/current/theme` and write `theme.name`.
4. Retint visible apps in parallel and wait for them (`visible_theme_commands`). Then retint other apps in the background (`other_theme_commands`) and log to `~/.local/state/omarchy/theme-set.log`.
5. Run the user's `theme-set` hooks in `~/.config/omarchy/hooks/theme-set.d/`.
6. Optionally mirror the theme to herdr machines.

App configs point at the `current/theme` path, so a switch changes one link target and then reloads the apps.

Security rule: a theme cloned from git with `omarchy theme install <url>` cannot ship `*.lua`, terminal configs, `vscode.json` or symlinks, because those can run code (`docs/theming.md`, "What an installed theme may not ship"; `INSTALLED_THEME_DENIED` in `bin/omarchy-theme-set`).

### SDDM / greeter

- Omarchy ships its own SDDM theme: `default/sddm/omarchy/` (`Main.qml`, `metadata.desktop`, `theme.conf`, PNG assets). It is installed to `/usr/share/sddm/themes/omarchy` (`bin/omarchy-plymouth-set:195`).
- The SDDM session itself runs on Hyprland (`default/sddm/hyprland.lua`).
- The background color in `Main.qml:8` is a fixed `#1a1b26`. `bin/omarchy-theme-set` has no reference to SDDM, so a theme switch does not retint the greeter.
- `install/login/sddm.sh` only removes the `pam_gnome_keyring` lines from `/etc/pam.d/sddm`. `omarchy-refresh-sddm` restores the default theme with sudo.

### Plymouth

- The theme is in `default/plymouth/` (`omarchy.plymouth`, `omarchy.script`, logo, lock, progress and entry PNGs).
- `omarchy-plymouth-set <bg-hex> <text-hex> <logo.png>` rebuilds it with sudo. It recolors the assets with `magick` (`bin/omarchy-plymouth-set:291`) and publishes the boot theme atomically.
- `omarchy-plymouth-set-by-theme <theme>` takes the colors from `colors.toml` and the theme's `unlock.png`.
- This is a separate, manual step from the menu (Appearance > Unlock, `default/omarchy/omarchy-menu.jsonc:130`). It is not part of a theme switch.

## 3. Install and update

### Install scripts

- `install/` is split by phase. Each phase has an `all.sh`:
  - `config/` (system: firewall, snapper, services, browser policy, system theme seed);
  - `login/` (SDDM);
  - `user/` (per-user: theme, chromium, keyring, input method, first-run units);
  - `post-install/`, `hardware/` and `provisioning/`.
- Package lists are plain files: `install/omarchy-base.packages` (182 lines) plus per-architecture lists.
- Omarchy is now package-backed. Its files live in `/usr/share/omarchy`, and user configs are copied from `/etc/skel` (`bin/omarchy-reinstall-configs`, `manual/31-dotfiles.md`).

### Updates and migrations

- `omarchy update` runs the package transaction, then migrations, post-update hooks and restart checks (`docs/update-process.md`).
- A pacman ALPM hook (`00-omarchy-update-guard.hook`) stops a raw `pacman -Syu` and points the user to `omarchy update`.
- Migrations:
  - Migrations are `migrations/<unix-timestamp>.sh`. There are 341 of them.
  - Each runs once per user as that user, and must be idempotent.
  - Completion markers are in `~/.local/state/omarchy/migrations/<name>`. `omarchy-migrate --pending` lists the pending ones (`docs/update-process.md`, "Migration layout").
- User hooks are in `~/.config/omarchy/hooks/<event>.d/`. The events are `post-boot`, `post-update`, `pre-refresh-pacman`, `theme-set`, `font-set` and `battery-low` (`manual/31-dotfiles.md`).
- `omarchy-reinstall-configs` replays `/etc/skel` over `$HOME`, which is destructive (`bin/omarchy-reinstall-configs`).

### The `omarchy-*` command set

- Every executable `bin/omarchy-<group>-<name>` is a command. `bin/omarchy` routes `omarchy theme set foo` to `omarchy-theme-set foo` by longest prefix (`docs/cli-router.md`).
- Header comments such as `# omarchy:summary=`, `# omarchy:args=` and `# omarchy:requires-sudo=true` give help text and listings without a registry. `omarchy commands --check` reports collisions.

### Ideas that suit a personal dotfiles repo

- **I1. Flat `bin/<prefix>-<group>-<name>` scripts with summary headers, plus a small router.** The commands can be found and need no registry.
- **I2. Timestamp-named idempotent migrations with per-user markers in `~/.local/state`.** One machine can be moved forward safely.
- **I3. Single palette file plus `*.tpl` templates, rendered into `~/.local/state/.../current/theme`.** App configs point at the current link, and hand-written files win over templates.
- **I4. Hook directories (`hooks/<event>.d/`) for user extensions.** Core scripts stay untouched.
- **I5. Two-tier retint (visible apps first, others in the background).** This keeps theme switches fast.
- **I6. The rule that cloned third-party themes cannot ship executable config.**
- Not suitable for auspex:
  - the package repo;
  - the pacman guard;
  - `/etc/skel` replay;
  - the custom shell.

  These need a distro, not a dotfiles repo.

## 4. Transfer to this machine

Classes: **As-is** means it works on KDE as-is. **KDE eq.** means it needs a KDE equivalent, which is named. **Hyprland** means it needs Hyprland, and the cost is named.

| Item | Class | Detail |
|---|---|---|
| AI-1 Default agent launcher | KDE eq. | Write a small bash launcher: default agent read from a file, `cd ~/Work` from `$HOME`, `--prompt`. Drop `--pick` (Quickshell) and the auto-install (Omarchy repo). |
| AI-2 Agent keybinds | KDE eq. | KDE custom global shortcut (System Settings > Keyboard > Shortcuts > Add Command, stored in `~/.config/kglobalshortcutsrc`). Not verified on this Plasma version. |
| AI-3 Quake agent console | KDE eq. | ghostty quick terminal (`quick-terminal-*` options and the `toggle_quick_terminal` action, https://ghostty.org/docs/config/reference), or Yakuake. Whether ghostty's quick terminal works under KWin Wayland is not verified. Yakuake is the native KDE dropdown terminal but is not ghostty. |
| AI-4 Aliases | As-is | Copy into the shell rc. They are plain shell. |
| AI-5 Shared `AGENTS.md` | As-is | Symlinks only. Existing `~/.claude/CLAUDE.md` content must be merged first, because the script moves it to `.bak`. |
| AI-6 Shared skills linking | As-is (mechanism) | The link script pattern works. The `omarchy` skill content is Hyprland-specific, so the system skill must be rewritten for KDE (kwriteconfig6, KWin, Plasma, SDDM). |
| AI-7 Theme sync into Claude Code | As-is | Needs a palette file and a renderer, and `custom:<name>` theme support in this Claude Code version (not verified). |
| AI-8 Agents usage panel | KDE eq. | A Plasma widget (plasmoid, QML) reading the same JSON records, or a CLI/status-line view. Collector portability is not verified. |
| AI-9 Multiple accounts | As-is (mechanism) | `CLAUDE_CONFIG_DIR` per account. The limit notification needs `notify-send`, which works on Plasma. |
| AI-10 Crash diagnosis | KDE eq. | Keep the `journalctl -f` coredump watcher as a systemd user unit. Use `notify-send --action` (libnotify actions work with Plasma's notification server) in place of `omarchy-notification-send --exec`. Plasma's own DrKonqi also handles crashes of KDE apps, so watch for duplicate notifications. |
| AI-11 Local models | As-is | Podman, Ollama or LM Studio are desktop-independent. The `omarchy-local-ai` package comes from Omarchy's repo, so use Ollama or LM Studio from Arch/AUR instead. |
| AI-12 Dictation | KDE eq. | A KDE global shortcut runs the backend CLI. Text entry on KWin Wayland needs a tool KWin accepts (for example `ydotool`, or KWin's fake-input path). Not verified. |
| AI-13 OCR | KDE eq. | `spectacle -b -n -r -o <file>` (region, background), then `tesseract`, then `wl-copy`. `grim`/`hyprpicker` do not work on KWin (not verified). |
| AI-14 AI web apps | As-is | Chromium `--app=URL` desktop files. The shortcut is a KDE custom shortcut. |
| AI-15 AI desktop apps | As-is | Install from upstream or AUR where packaged (not verified for each app). |
| AI-16 Chromium Claude extension | As-is | Install from the Chrome Web Store or by browser policy. |
| AI-17 herdr integration | As-is | Run `herdr integration install claude` once. It is not tied to the desktop. |
| AI-18 First-boot agent setup | Not applicable | The machine is already set up. |
| Agents panel "Make something cool" prompts | Hyprland | They are part of the Quickshell panel. Cost: Hyprland + Quickshell. On KDE, starter prompts can be shell functions or skills instead. |
| Full Omarchy agent experience (panel, Quake console, skills that edit the desktop) | Hyprland | Cost: replace KWin and Plasma with Hyprland and Quickshell, and lose Plasma settings, KDE Connect integration and the SDDM/Plasma polish now in use. This is the phase-2 decision. |

Theming on KDE: the `colors.toml` + templates model transfers. The KDE targets that replace `hyprland.lua.tpl` and `shell.toml.tpl` are a Plasma color scheme (`~/.local/share/color-schemes/*.colors`, applied with `plasma-apply-colorscheme`) and a KWin/Plasma wallpaper (`plasma-apply-wallpaperimage`). Both commands exist in Plasma 6 (not verified on this machine). The SDDM theme and plymouth stay a separate sudo step, as in Omarchy.

## 5. Recommended AI-first features for auspex

Ranked by value for the cost on this KDE machine:

1. **Shared `~/.agents/AGENTS.md` linked into every harness (AI-5).** One instruction file then reaches Claude Code and any other agent with no desktop dependency.
2. **An auspex system skill for KDE, linked into `~/.claude/skills` (AI-6 pattern).** Omarchy's main AI value is an agent that knows how this desktop is configured, and a KDE version gives Claude Code that knowledge.
3. **A global agent hotkey with a dropdown agent console (AI-2 + AI-3 via a KDE shortcut and the ghostty quick terminal).** It puts the agent one key away on the ultrawide monitor with no Hyprland.
4. **A crash-watch user unit that hands coredumps to Claude Code (AI-10).** It is about 60 lines of bash on systemd-coredump and turns crashes into diagnosed reports.
5. **A palette file plus templates that also theme Claude Code (AI-7 + I3).** This is the base phase 2 needs for Rome / Star Wars, and Claude Code follows the theme for free.
6. **A small `auspex agent` launcher with a `prompt` subcommand (AI-1).** Scripts, hotkeys and the crash watcher then share one entry point to the default agent.
7. **herdr integration for each agent CLI (AI-17).** herdr is already in use, and one command adds agent status and session restore.
8. **OCR to clipboard through Spectacle + tesseract (AI-13).** It is cheap and makes screen text easy to paste into an agent prompt.
9. **Local dictation with a KDE hotkey (AI-12, Voxtype or similar).** Voice prompts to agents are fast, but text entry on KWin Wayland needs a test first.
10. **Local models through Ollama or LM Studio (AI-11).** They are a private fallback for sensitive prompts, but they add little while Claude Code is the main agent.

Not recommended now:

- The usage panel (AI-8): a plasmoid costs much more than the other items.
- Multi-account switching (AI-9): there is only one subscription.
- Auto-approve aliases (AI-4): they skip permission prompts, which conflicts with a safety-first setup.

## Unknowns

- U1. The ghostty quick terminal under KWin Wayland is not verified.
- U2. Claude Code `custom:` theme hot-reload on the installed version is not verified.
- U3. How Omarchy dictation types text into the focused window is not traced.
- U4. The first-boot agent setup code path is not traced.
- U5. Whether the usage collectors run outside Omarchy is not verified.
