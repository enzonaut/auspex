# Research: the herdr app as the AVGVR work surface

- Date: 2026-11-26
- Author: researcher-1 (fleet task T-2)
- Revision examined: `b65395a` (spec draft branch `fleet/solo-spef041270fc252cceaeb92a646a61529a`)
- Versions examined: `herdr-app 0.1.18`, `hc 0.1.22` (verified: `herdr-app --version`, `hc --version`)
- Use: input for the revision of `docs/specs/avgvr-theme.md`

## How to read this report

- Each fact has a label. "verified" names the file or the command that shows the fact. "not verified" means that no file or command showed it.
- "Guide" is `~/.config/herdr-app/AGENTS.md`. The herdr app writes this file again at each start.
- "Proposal" marks a recommendation. A proposal is not a fact.
- Limit: this session ran in KDE Plasma (verified: `XDG_CURRENT_DESKTOP=KDE`, `hyprctl clients` prints "HYPRLAND_INSTANCE_SIGNATURE not set"). No fact about the herdr app in a live Hyprland session is verified.
- No command in this research made, closed or moved a space, a tab or a pane. No file in `~/.config/herdr-app/` or `~/.config/herdr/` changed.

## Answer in short

- The herdr app draws its own terminals. The herdr app theme and the layout look set the terminal colors and the fonts. ghostty has no role.
- One theme file, `~/.config/herdr-app/themes/avgvr.json`, gives the AVGVR palette to the terminals, the panels and the agent state marks.
- The AVGVR shape rules (radius 0, no full-height left sidebar, a horizontal band, Marcellus SC labels, Roman numerals) need a personal layout and personal mods. The shipped layout and the shipped mods are read-only and have rounded corners in their code.
- A mod cannot change how terminal text draws.
- The spec draft has 16 places that name ghostty. Section 7 lists them.

## 1. Units and nesting (step 1)

### 1.1 Two programs

| ID | Fact | Label |
|---|---|---|
| U1 | `herdr-app` is the window. It holds spaces, tabs, layouts and panels. | verified: `herdr-app --help`, Guide |
| U2 | `hc` (herdr-core) runs each terminal and each agent. They continue when the window closes. | verified: `hc --help`, Guide |
| U3 | The herdr app does not read `~/.config/herdr/config.toml`. That file is for the herdr terminal UI. | verified: Guide:772 |
| U4 | `~/.config/herdr-core` does not exist on this machine. | verified: `ls ~/.config` |

### 1.2 Units

| Unit | Definition | Label |
|---|---|---|
| Space | A named group of tabs with a folder and a machine. | verified: `herdr-app ls` (fields `id, name, folder, machine, active, tabs`) |
| Tab | A page in a space. It holds 1 or more panes. A tab can be "settled". | verified: `herdr-app ls` (fields `id, name, active, settled, terminals`) |
| Pane | A rectangle in a tab. It shows 1 terminal. | verified: `herdr-app ls` (fields `terminal, pane`) |
| Terminal | A program that `hc` runs. It can exist without a pane. | verified: `hc --help` |
| Agent | A terminal whose program reports a status with OSC 7501. | verified: Guide:1199-1200 |
| Sub-agent | A terminal that an agent starts with `hc run`. The `agents` mod lists it below its parent. | verified: `mods/agents/main.js:53-60` |

Nesting: space > tab > pane > terminal. An agent is a terminal with a status.

### 1.3 Agent states

| State | Meaning | Ticket word | Label |
|---|---|---|---|
| `working` | The agent does work. | working | verified: Guide:1199-1200 |
| `blocked` | The agent needs the person. The UI text is "Needs you". | waiting, needs input | verified: `mods/pane/main.js:85` |
| `done` | The agent finished and no person looked at it. | done | verified: Guide:1199-1200 |
| `idle` | The agent has no work. `done` becomes `idle` when a person looks at the agent on a Herdr client. | none | verified: Guide:1199-1200 |
| `unknown` | The status is not known. | none | verified: Guide:1201-1207 (color name) |

The status of a tab or a space is the most urgent status of its agents. The order is `blocked`, `done`, `working`, `idle` (verified: `mods/agents/main.js:53`).

### 1.4 Live state during this research

- `herdr-app status` shows `layout "main"`, `zoom 1.1`, `font_size 15.4`, `ui_font_size 14.3`, no floats, no overlays, no errors (verified: `herdr-app status`).
- The window is not fullscreen. Its saved bounds are `[0, 0, 2373, 1857]` (verified: `~/.config/herdr-app/window.json`).
- The screenshot shows a left sidebar (spaces list, agents list, settings), a tab row, 2 pane cards with rounded corners, and a status row (verified: `herdr-app shot`, file in the scratch folder).

## 2. Config, theme format and mods (step 2)

### 2.1 Home folder `~/.config/herdr-app/`

| Path | Content | Who writes it | Label |
|---|---|---|---|
| `settings.json` | The look and behavior for all layouts. | the person | verified: Guide:84 |
| `keys.json` | Key bindings. | the person | verified: file |
| `themes/<name>.json` | Theme files. | the person | verified: 4 files present |
| `layouts/<name>.json` | Layout trees. | shipped and personal | verified: `main`, `terminals`, `warcraft`, `win98` |
| `mods/<name>/` | Mods (JavaScript). | shipped and personal | verified: `ls mods/` |
| `icons/` | Program icons (SVG). | shipped | verified: `ls icons/` |
| `frame/` | Built-in frames (`feedback`, `palette`, `settings`, `welcome`, `whatsnew`). Written again at each start. | the app | verified: `ls frame/`, Guide |
| `programs.json` | Name, icon and tile color for each program. | the person | verified: Guide:871 |
| `shared.json`, `window.json` | Active layout, space colors, window bounds. | the app | verified: files |
| `AGENTS.md`, `herdr.d.ts`, `gpui-kit.d.ts` | The guide and the type files. Written again at each start. | the app | verified: Guide |

Current `settings.json` (verified: file): `zoom 1.1`, `sounds.enabled true`, `font_ligatures false`, `minimum_contrast 1.0`, `appearance "dark"`, `theme "gruvbox"`.

### 2.2 Shipped files are read-only

- The app replaces the shipped layouts and the shipped mods at each start (verified: Guide:198).
- The app moves an edited shipped file to `<name>-edited` (verified: Guide:220).
- A change starts with `layout.clone` or `mod.clone`, or with a new personal file (verified: Guide:206-207, 704-705).

### 2.3 Theme file format

File: `themes/<name>.json` (verified: `themes/gruvbox.json`, `themes/warcraft.json`, Guide:1201-1207).

```json
{
  "background": "#rrggbb",
  "foreground": "#rrggbb",
  "selection":  "#rrggbb",
  "cursor":     "#rrggbb",
  "ansi": ["16 colors, ansi0 to ansi15"],
  "colors": { "chrome": "#rrggbb", "working": "#rrggbb" }
}
```

- `cursor` and `colors` are optional (verified: `themes/gruvbox.json` has no `colors`; `themes/warcraft.json` and `themes/win98.json` have `colors` with `working`, `blocked`, `done`, `idle`).
- Color names that a theme can set and that a mod reads with `theme()` (verified: Guide:1201-1207):

| Group | Names |
|---|---|
| Grounds | `background` (terminals, cards), `canvas` (behind cards), `chrome` (sidebars, bars), `surface`, `popover`, `raised`, `hover`, `selected` |
| Lines | `border`, `input` (stronger border) |
| Text | `foreground`, `muted`, `dim` |
| Accent | `accent`, `accent_foreground`, `solid`, `solid_foreground` (primary button), `selection` |
| Agent states | `working`, `blocked`, `done`, `idle`, `unknown` |
| Terminal | `ansi0` to `ansi15` |

### 2.4 Look cascade

1. The look in the layout file wins (verified: Guide:200, 365).
2. `settings.json` fills what the layout leaves unset: `theme`, `colors`, `font`, `font_size`, `font_weight`, `font_weight_bold`, `ui_font`, `terminal_line_height`, `terminal_cell_width` (verified: Guide:774-786).
3. The theme picker overrides the layout and stays on that layout (verified: Guide:783-784).
4. The shipped `main` layout sets no fonts and no theme (verified: Guide:779, `layouts/main.json`).
5. `app.theme {name}` sets a theme by command (verified: Guide:344, 709). This research did not run it.

### 2.5 Layout

- A layout is a tree of `row`, `column`, `stack` and `block` nodes (verified: Guide, `layouts/main.json`).
- A node can set size, background, border, radius, shadow, padding, gap, divider and `window_drag` (verified: Guide).
- The root can set `titlebar: "none"`, `window_blur` and `toast` (verified: Guide:270, 277, 293).
- The tab block sets the pane frame: gap, radius, background, border, focus border, veil, header mod and header height (verified: `layouts/main.json`).
- Shipped `main` (verified: `layouts/main.json`): `titlebar: "none"`, sidebar column 268 px with `chrome` background, tab row 42 px, pane gap 8, pane radius 10, pane border 1 px `border`, focus border 1 px `accent`, pane header 30 px (mod `pane`), status row 28 px (mod `workspace-status`).
- A layout can set radius 0 (verified: `layouts/win98.json:49`).

### 2.6 What a mod can change

| ID | Fact | Label |
|---|---|---|
| M1 | A mod is JavaScript that builds native GPUI elements with `gpui-kit`. | verified: `mods/toast/main.js:5-7` |
| M2 | A mod sets background, border, radius, text size, text color and weight on its own elements. | verified: `mods/toast/main.js:20-46` |
| M3 | A mod sets a font family on an element with `.font_family(name)`. | verified: `mods/warcraft/bar.js:49` |
| M4 | A mod folder can hold `.ttf` and `.otf` fonts in `fonts/`. The home folder can hold a `fonts/` folder too. | verified: Guide:372-375, `mods/warcraft/fonts/` |
| M5 | A mod reads spaces, tabs and agents, runs commands, calls `exec`, `hc` and `fetch`, and posts `notify()`. | verified: Guide:1225-1240 |
| M6 | A mod sets the OS window title with `setWindowTitle(title)`. | verified: Guide:1268-1270 |
| M7 | A mod draws SVG files and can spin them. | verified: `mods/pane/main.js:84` |
| M8 | A mod cannot change how terminal text draws. | verified: Guide |
| M9 | `gpui-kit.d.ts` has no letter-spacing builder. | verified: `grep -i letter_spacing gpui-kit.d.ts` gives 0 lines |
| M10 | A timed color transition of 200 ms in a mod. | not verified |
| M11 | `herdr-app check <mod folder>` checks a mod. | verified: `herdr-app --help` |

### 2.7 Keys

- `keys.json` uses `alt-1..9` (space), `ctrl-1..9` (tab), `alt-h/j/k/l` (pane), `alt-up/down` (agent), `ctrl-shift-*` and the prefix `ctrl-b` (verified: `keys.json`).
- The herdr app uses no SUPER key (verified: `keys.json`). Hyprland owns SUPER. The 2 sets do not collide.

## 3. Terminal colors, fonts and agent state display (step 3)

### 3.1 Terminal colors and fonts

| ID | Fact | Label |
|---|---|---|
| T1 | The terminal background, foreground, selection, cursor and 16 ANSI colors come from the herdr app theme. | verified: Guide:1201-1207, `themes/gruvbox.json` |
| T2 | The terminal font comes from the layout `font`, then `settings.json` `font`, then the default JetBrains Mono 14. | verified: Guide:365-368 |
| T3 | The UI font for mods comes from the layout `ui_font`, then `settings.json` `ui_font`, then the default Geist. | verified: Guide:365-368 |
| T4 | `terminal_line_height`, `terminal_cell_width`, `font_ligatures` and `minimum_contrast` are settings. | verified: Guide:774-786, `settings.json` |
| T5 | The layout root sets the terminal padding. Shipped `main` uses `[14, 12]`. | verified: `layouts/main.json` |
| T6 | herdr-core sets no color and no font. | verified: Guide (the look keys are all in the app) |
| T7 | ghostty config has no effect on the herdr app. | verified: Guide names no ghostty file as input; the app has its own terminal drawing (Guide:360-361) |

### 3.2 How agent states show

| Surface | `working` | `blocked` | `done` | `idle` | Label |
|---|---|---|---|---|---|
| Pane header (mod `pane`) | spinner 12 px, color `working` | pill "Needs you", color `blocked` | dot 7 px, color `done` | no mark | verified: `mods/pane/main.js:84-86` |
| Tab (mod `tabs`) | spinner 12 px | dot 6 px, color `blocked` | dot 6 px, color `done` | no mark | verified: `mods/tabs/main.js:122-123` |
| Agents list (mod `agents`) | spinner, section "Working" | pill "Needs you" or "!" | dot, section "Done" | ring 7 px | verified: `mods/agents/main.js:211-219`, screenshot |
| Spaces list (mod `spaces`) | "·" | "●" in state color | "●" in state color | "·" | verified: `mods/spaces/main.js:73-77` |
| Status row (mod `workspace-status`) | count of agents | text "N needs you" in `blocked` | no mark | no mark | verified: `mods/workspace-status/main.js:21-27` |
| Toast (mod `toast`) | dot for level `warning` | dot for level `error` | dot for level `success` | no mark | verified: `mods/toast/main.js:9, 34` |

- The app plays a sound when an agent becomes `blocked` or `done`. If the person does not look at the agent, the app posts a toast. A click on the toast goes to the agent (verified: Guide:756-761).
- `settings.json` `sounds` can turn the sounds off or replace the 2 files (verified: Guide:756).
- The layout root key `toast` selects the mod that draws all notifications (verified: Guide:293-295).
- All state colors come from `theme()`. All state shapes (spinner, pill, dot, ring) and their radius are in the mod code (verified: the lines above).

## 4. Look-only commands (step 4)

- Commands used: `herdr-app status`, `herdr-app ls`, `herdr-app shot`, `herdr-app commands`, `herdr-app --help`, `herdr-app --skill`, `hc --help` (verified: this session).
- The screenshot is in the scratch folder of this session, not in the repo.
- The screenshot confirms 5 conflicts between shipped `main` and the AVGVR rules:

| ID | Conflict | AVGVR rule | Label |
|---|---|---|---|
| C1 | Full-height left sidebar, 268 px. | Ban: "A full-height left sidebar or a floating rounded dock bar" (`DIRECTION.md:24`) | verified: screenshot, `layouts/main.json` |
| C2 | Pane cards with radius 10. Pills, dots and tiles with radius 3 to 5. | Radius 0 | verified: `layouts/main.json`, mod code |
| C3 | UI font Geist. Space names and tab names in mixed case. | Jost for UI, Marcellus SC capitals for labels | verified: screenshot, Guide:368 |
| C4 | Spaces show a colored letter tile. | Roman numerals for workspaces | verified: screenshot |
| C5 | Theme `gruvbox`. | AVGVR palette | verified: `settings.json` |

## 5. AVGVR mapped onto the herdr app (step 5)

Tokens are from `design/directions/c/DIRECTION.md` and `design/directions/c/colors.toml`. The "Fact" columns are verified in sections 2 and 3. The token choices are a proposal.

### 5.1 Method codes

- **TF** = theme file only (`themes/avgvr.json` plus `settings.json` keys).
- **LY** = personal layout file (`layouts/avgvr.json`).
- **MOD** = personal mod (a clone of a shipped mod, or a new mod).
- **HY** = Hyprland config, not the herdr app.
- **NO** = not possible in the herdr app.

### 5.2 Surfaces

| ID | Surface | AVGVR token (proposal) | herdr name | Method | Notes |
|---|---|---|---|---|---|
| S1 | Window frame | `border` 1 px, active `bronze`, radius 0, no shadow | none | HY | The layout has `titlebar: "none"`. Hyprland draws the window border (spec section 8.2). |
| S2 | Ground behind panes | `bg-darker #110F0D` | `canvas` | TF | |
| S3 | Bars and lists ground | `bg-dark #17140F` | `chrome` | TF | |
| S4 | Space list, colors | active space `porphyry #4E1C3E`, text `text`, other spaces `text-muted` | `selected`, `foreground`, `muted` | TF | |
| S5 | Space list, shape | horizontal list, Roman numerals I, II, III, Marcellus SC capitals, no letter tile | mod `spaces` | LY + MOD | The shipped mod is a vertical list with 12 `.rounded(` calls. |
| S6 | Tab bar, colors | ground `bg-dark`, active tab `surface #2A241E`, text `text` | `chrome`, `surface`, `foreground` | TF | |
| S7 | Tab bar, shape | radius 0, Jost labels, state mark square | mod `tabs` | MOD | The shipped mod has 4 `.rounded(` calls. |
| S8 | Pane border | `border #7A6E5F`, 1 px, radius 0 | `border`; layout `radius`, `border` | TF + LY | Radius 0 needs the layout. |
| S9 | Focused pane | `bronze #C9A05A`, 1 px | layout `focus.color` | LY | Shipped `main` uses `accent` for focus. See Q3. |
| S10 | Pane header | ground `bg-dark`, label in JetBrains Mono in `[ brackets ]` | mod `pane` | TF + MOD | The colors need only the theme. The bracket text and radius 0 need the mod. |
| S11 | Terminal palette | `bg #1D1915`, `text #E6DCCB`, `selection #3A2E3A`, cursor `accent #EB6A43`, the 16 ANSI colors of `colors.toml` | `background`, `foreground`, `selection`, `cursor`, `ansi` | TF | Full match. No mod. |
| S12 | Terminal font | JetBrains Mono 400 and 700 | `font`, `font_weight`, `font_weight_bold` | TF | JetBrains Mono is the app default. The default weight is 500, so the settings must set 400. |
| S13 | UI font | Jost | `ui_font` | TF | The font file must be `.ttf` or `.otf` in a `fonts/` folder (M4). |
| S14 | Display labels | Marcellus SC, capitals, V for U | `.font_family()` in a mod | MOD | Possible for each element (M3). |
| S15 | Label letter spacing +0.12em | Marcellus SC rule | none | NO | No letter-spacing builder (M9). A mod could put thin spaces between letters. That is not verified. |
| S16 | Agent state colors | `working` = `bronze`, `blocked` = `accent`, `done` = `verdigris #63A897`, `idle` = `text-faint #988D7B`, `unknown` = `border` | `working`, `blocked`, `done`, `idle`, `unknown` | TF | See Q2. |
| S17 | Agent state shapes | square marks, bracket text such as `[ NEEDS YOU ]`, no pill | mods `pane`, `tabs`, `agents` | MOD | The shapes are in the mod code. |
| S18 | Notifications in the app | ground `surface`, 1 px `border`, radius 0, title in Jost | `popover`; mod `toast`; overlay `frame: "none"` | TF + MOD | `frame: "none"` removes the Herdr border, corners and shadow from an overlay (Guide:1223-1224). If the app toast window honors it is not verified. |
| S19 | Notifications on the desktop | mako style of spec section 8.4 | `exec("notify-send", ...)` in a mod | MOD | A mod can call `exec` (M5). The toast mod with this call is not written and not tested. |
| S20 | Sounds for `blocked` and `done` | no token | `settings.sounds` | TF | Taste question Q6. |
| S21 | Motion 200 ms | motion token | none | not verified | M10. |
| S22 | Dentil rail on a band | band rule | SVG or small blocks in a mod | MOD | A mod draws SVG (M7). |
| S23 | Program tiles and icons | `bronze` tile, no rounded tile | `programs.json`, mods | TF + MOD | The tile color is data. The tile shape is mod code. |
| S24 | Scrollbars, text selection, links | `border`, `selection` | theme colors, `pane_scrollbars` | TF | |
| S25 | Built-in frames (settings, palette, welcome) | colors only | `frame/` | TF for colors, NO for shape | The app writes `frame/` again at each start. |

### 5.3 Three levels of work

| Level | Content | Result | Gaps that stay |
|---|---|---|---|
| L1 | `themes/avgvr.json` and 4 keys in `settings.json` (`theme`, `font_weight`, `ui_font`, `colors` if necessary) plus the Jost TTF in `~/.config/herdr-app/fonts/` | S2, S3, S4, S6, S8 color, S11, S12, S13, S16, S20, S24 | C1, C2, C4, capitals, numerals |
| L2 | L1 plus `layouts/avgvr.json` (a clone of `main` with radius 0, focus color, no sidebar column, band rows) | adds S8, S9, removes C1 | The mods keep their rounded marks and Geist-style labels. |
| L3 | L2 plus personal mods for the band, spaces, tabs, pane header, agents and toast | adds S5, S7, S10, S14, S17, S18, S19, S22 | S15, S21, S25 shape |

### 5.4 Facts that matter for the build

| ID | Fact | Label |
|---|---|---|
| B1 | The spec renderer (`render` mode, spec section 4.2) can write `themes/avgvr.json` from a template. The file is plain JSON with `#rrggbb` values. | verified: spec section 4.2, theme format in 2.3 |
| B2 | `settings.json` is the file of the person and holds other keys. A `copy` of the full file would remove `zoom` and `sounds`. The build needs a key merge or an operator step. | verified: `settings.json`; the merge tool is a proposal |
| B3 | Spec section 4.4 makes TTF files from the design woff2 files. The same files fit `~/.config/herdr-app/fonts/`. | verified: spec section 4.4, Guide:372 |
| B4 | The herdr app loads fonts at start and on the next look change. | verified: Guide:373 |
| B5 | If the herdr app also finds fonts in `/usr/local/share/fonts/avgvr/` (system fonts). | not verified |
| B6 | Personal mods and a personal layout are files below `~/.config/herdr-app/`. The auspex manifest can own them with `copy` rows. They are not KDE files. | verified: Guide:198-220 for the file rules; the manifest rows are a proposal |
| B7 | The herdr app theme applies in the KDE session and in the Hyprland session, because the app reads 1 home folder. | verified: 1 folder `~/.config/herdr-app/`; no session key in `settings.json` |
| B8 | A mod is trusted code with `exec`. The repo must review each mod as code. | verified: Guide:1240 |

## 6. The herdr app in the Hyprland desktop (step 6) - PROPOSAL

All of section 6 is a proposal, except the rows with a label.

### 6.1 Facts

| ID | Fact | Label |
|---|---|---|
| H1 | The monitor is `DP-2`, 5120x2160 at 165 Hz, scale 1. | verified: `config/hypr/hyprland.lua:6` |
| H2 | `SUPER + Return` starts ghostty. | verified: `config/hypr/hyprland.lua:33` |
| H3 | `SUPER + ALT + A` runs `auspex agent --window`. | verified: `config/hypr/agent-binds.lua` |
| H4 | `bin/auspex-agent` starts `herdr-app` if `herdr-app status` fails, selects or makes the space "auspex agent", and runs `herdr-app` again to raise the window. | verified: `bin/auspex-agent:97-132` |
| H5 | The Hyprland config has no autostart and no window rule for the herdr app. | verified: `config/hypr/hyprland.lua:22-31, 64-78` |
| H6 | The desktop file sets `StartupWMClass=herdr-app`. | verified: `~/.local/share/applications/herdr-app.desktop:9` |
| H7 | The class that Hyprland sees for the herdr app window. | not verified (no Hyprland session) |
| H8 | If the herdr app runs as a Wayland client or through XWayland. | not verified |
| H9 | Waybar has `hyprland/workspaces`, `clock`, `pulseaudio`, `network`, `tray`. It has no `style.css` in the repo. | verified: `config/waybar/config.jsonc` |
| H10 | `hc ls --json` gives each terminal with its status. A waybar `custom/legio` script can count `working` and `blocked` from it. | verified: `bin/auspex-agent` uses `hc ls --json`; the count script is a proposal |
| H11 | The herdr layout has `titlebar: "none"`. | verified: `layouts/main.json` |

### 6.2 Common parts of the 2 options

1. `SUPER + Return` starts or raises the herdr app, not ghostty. The command is `herdr-app`. `bin/auspex-agent:131` uses the same command to raise the window.
2. Autostart: add `herdr-app` to the Hyprland autostart, so that the work surface is ready after login.
3. Window rule: put class `herdr-app` on workspace I. Confirm the class with `hyprctl clients` in a Hyprland session first (H7).
4. `SUPER + ALT + A` stays as it is. It selects the "auspex agent" space in the same window.
5. Names: the waybar numerals I to X are Hyprland workspaces. The herdr spaces are a second set. The 2 sets must not look the same (see Q1).

### 6.3 Option O1: tiled below the waybar band

- The herdr app is the only tiled window on workspace I. It has the full width below the 40 px waybar band.
- Waybar is the only inscription band. It shows workspaces, the LEGIO counter (from `hc ls --json`), the clock and the system modules.
- The herdr layout has no band and no sidebar. It has 1 thin row: spaces and tabs in bracket text. Below it are the panes.
- The Hyprland border (1 px `bronze`) is the window frame.

| For | Against |
|---|---|
| 1 band for the full desktop. The same band is there on the game workspaces. | Waybar does not know the herdr spaces. The LEGIO counter needs a poll script. |
| The tray, the volume and the network stay in view. | 2 rows above the terminals: 40 px waybar and the herdr row. |
| Less mod work: no band mod. | A click on LEGIO cannot go to the blocked agent without an added script. |
| Other windows can tile next to the herdr app on the same workspace. | Hyprland gaps (6/12) take space around the window. |

### 6.4 Option O2: fullscreen with a band in the herdr app

- The herdr app is fullscreen on workspace I (`SUPER + F` or a window rule). Waybar is hidden below it on that workspace.
- A personal mod draws the inscription band in the herdr app: spaces as the session blocks, the LEGIO counts from live agent data, the clock, the dentil rail.
- Waybar shows on the other workspaces with the same style.

| For | Against |
|---|---|
| The band shows live agent states with no poll. A click on a count goes to the agent. | 2 builds of the same band: waybar CSS and a herdr mod. They can drift apart. |
| The most terminal space on the 5120x2160 monitor. No gaps. | The tray, the volume and the Hyprland workspaces are not in view on workspace I. |
| The big idea of DIRECTION.md ("shows you the 1 thing that needs you") is in the place where the agents are. | More mod code to own and to review (B8). |
| The band also works in the KDE session, because it is in the app. | Letter spacing is not possible in the mod (S15), so the 2 bands differ in the label spacing. |

### 6.5 Recommendation (proposal)

Start with O1 at level L2 (theme file, layout, no new band mod). It removes all ghostty work and gives the palette, radius 0 and no sidebar with the least code. O2 is a later step when the operator wants the live counts in the band.

Width note: on a 5120 px window, 4 panes side by side are each about 1270 px wide. The herdr layout decides the pane count, not Hyprland.

## 7. Changes to the spec draft (step 7)

The spec draft is `docs/specs/avgvr-theme.md` at `b65395a`. Line numbers are from that revision.

| ID | Spec section | Text now | Change |
|---|---|---|---|
| X1 | 1, requirement R5 | "ghostty and Claude Code use the palette." | Replace ghostty with the herdr app (theme, layout, mods). |
| X2 | 2, repo layout | `templates/ghostty/avgvr.tpl`, `config/ghostty/config.ghostty` | Remove. Add `templates/herdr-app/avgvr.json.tpl`, and if L2 or L3: `config/herdr-app/layouts/avgvr.json`, `config/herdr-app/mods/avgvr-*/`. |
| X3 | 3, machine facts | Rows "ghostty 1.4.0" and "ghostty config" | Replace with herdr app facts: `herdr-app 0.1.18`, `hc 0.1.22`, home folder, `settings.json` content, shipped files read-only. |
| X4 | 4.1, palette | Font tokens `font_display`, `font_body`, `font_data` | Keep. Add the map to herdr `ui_font` (Jost) and `font` (JetBrains Mono). Add the map of the 5 agent state colors (S16). |
| X5 | 4.2, renderer | Filters `bare`, `rgba:ff`, `dec` | The herdr theme needs plain `#rrggbb` only. No new filter. The JSON `ansi` array needs 16 values in order. |
| X6 | 4.3, `theme-set` hooks | Hook `30-ghostty` (SIGUSR2) | Remove. A herdr hook is optional: the app reads `settings.json` live (Guide:84). If a theme file change reloads live is not verified. |
| X7 | 4.4, theme build | TTF from woff2; JetBrains Mono from the package "because a terminal needs box glyphs" | Keep the TTF step. Add the copy of the Jost and Marcellus SC TTF files to `~/.config/herdr-app/fonts/`. The herdr app ships JetBrains Mono as its default; if the package font is still necessary for the herdr app is not verified. |
| X8 | 5.2, step 050 | "waybar, mako, fuzzel, hyprlock and ghostty all see the fonts" | Remove ghostty. State B5 as open. |
| X9 | 8.1, manifest | Rows for `templates/ghostty/avgvr.tpl`, `config/ghostty/config.ghostty` (`--adopt`), removal of `config/ghostty/.gitkeep` | Remove the 3 rows. Add a `render` row for `~/.config/herdr-app/themes/avgvr.json`. Add a merge rule for `settings.json` (B2). |
| X10 | 8.2, Hyprland | Border, gaps, rounding | Keep. Add the window rule and the autostart for the herdr app (section 6.2). |
| X11 | Hyprland binds (`config/hypr/hyprland.lua:33`) | `SUPER + Return` starts ghostty | Start or raise the herdr app. The spec does not name this bind outside OQ1; add it to section 8.2. |
| X12 | 8.3, waybar band | `custom/legio` static label | Keep for O1. Add the count source `hc ls --json` (H10). For O2, add the band mod. |
| X13 | 8.4, fuzzel | `terminal=ghostty -e` | Change or remove. A command that opens a program in a new herdr tab is a `herdr-app do tab.new` call (Guide:611). The exact fuzzel line is not verified. |
| X14 | 9.1, ghostty | Theme file, `config.ghostty`, font size 12, padding 12/8, `ghostty +validate-config` | Replace the full section with "the herdr app": theme file, settings keys, layout, mods, check with `herdr-app check`. |
| X15 | 11.1, shared by both sessions | "the ghostty theme (OQ1)" | Replace with "the herdr app theme" (B7). |
| X16 | 12.1, theme check | `ghostty +validate-config` | Replace with a JSON parse of the theme file and `herdr-app check <mod folder>` for each mod. |
| X17 | 12.2, operator checks | "a new ghostty window in both sessions" | Replace with "the herdr app window in both sessions". |
| X18 | 13, build order item 7 | "ghostty (after OQ1 is answered)" | Replace with "the herdr app (theme L1, then layout L2, then mods L3)". |
| X19 | Open question OQ1 | ghostty under KDE; `--config-file` for "the Hyprland `SUPER+Return` bind and the dropdown" | Remove. The dropdown is in OQ1 only. No dropdown is in `config/hypr/hyprland.lua` (verified). Section 8 has the new question Q7. |
| X20 | Open question OQ7 | "the `ttf-jetbrains-mono` package for the terminal font" | Revise with X7. |
| X21 | Open question OQ9 | Static `LEGIO [ – · – ]` label now | Revise: the counts can be real now, from `hc ls --json` (H10). |

Render templates in short: remove `templates/ghostty/avgvr.tpl` (X2, X9), add `templates/herdr-app/avgvr.json.tpl` (X2, X9), keep `templates/claude/avgvr.json.tpl` (section 8.1, no change).

## 8. Open questions for the operator (step 8)

- **Q1. How do herdr spaces show next to Hyprland workspaces?** Waybar uses Roman numerals for workspaces. Recommendation: workspaces keep the numerals; herdr spaces show their names in capitals with no numeral.
- **Q2. Which color means "needs you"?** DIRECTION.md permits 1 accent in a view. Recommendation: `blocked` is the only use of `accent #EB6A43` in the herdr app, apart from the cursor. `working` is `bronze`, `done` is `verdigris`, `idle` is `text-faint`.
- **Q3. Which color marks the focused pane?** Shipped herdr uses its accent. Recommendation: `bronze`, the same as the Hyprland active border, so that `accent` stays free for Q2.
- **Q4. Where do the spaces go when the left sidebar is removed?** Choices: a horizontal row above the tabs, a part of the band (O2), or only the palette and `alt-1..9`. Recommendation: a horizontal row.
- **Q5. Tiled below waybar (O1) or fullscreen with a band in the app (O2)?** Recommendation: O1 first.
- **Q6. Keep the sounds for `blocked` and `done`?** Recommendation: keep the `blocked` sound, turn the `done` sound off.
- **Q7. Is a dropdown terminal still wanted?** The draft named one for ghostty. Recommendation: no dropdown; `SUPER + Return` raises the herdr app.
- **Q8. Does the herdr app start at login in Hyprland?** Recommendation: yes, on workspace I.
- **Q9. How far does the first build go: L1, L2 or L3?** L1 is colors and fonts in 1 day of work. L3 is the full AVGVR shape with 6 mods to own. Recommendation: L2 first, then L3 mod by mod.
- **Q10. Do herdr toasts stay in the app, or go to mako?** Recommendation: in the app while the herdr window has focus; mako is a later step.
- **Q11. Does the AVGVR look apply to the herdr app in the KDE session too?** The app reads 1 config folder for both sessions. Recommendation: yes.

## Not verified (summary)

| ID | Item |
|---|---|
| N1 | The window class and the Wayland mode of the herdr app in Hyprland (H7, H8). |
| N2 | A live reload of a changed theme file (X6). |
| N3 | The use of system fonts by the herdr app (B5). |
| N4 | A 200 ms transition in a mod (M10, S21). |
| N5 | `frame: "none"` for the app toast window (S18). |
| N6 | A mako handoff from a toast mod (S19). |
| N7 | The fuzzel line that opens a program in a herdr tab (X13). |
| N8 | Letter spacing by thin spaces in a mod (S15). |
