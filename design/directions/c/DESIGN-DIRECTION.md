# CVNEVS — direction contract (auspex direction C)

## Brief

- Subject: an OS theme for auspex (Arch Linux, Hyprland first, Plasma fallback, SDDM, plymouth, ghostty, Claude Code) on a 5120x2160 monitor.
- Audience: the operator, who runs a fleet of coding agents from this desktop.
- Feeling: a disciplined legion standing in airless space. Roman order, starship steel.
- Surfaces: login, boot splash, lock, desktop with bar and 2 tiled windows, wallpaper.
- Constraints: black, steel grey, blood red, gold eagles. No film logos, crests, characters, stills or trademarked names. No photo-copied Roman artifacts. Login text contrast 4.5:1 or more. Open-license fonts only.
- Assumption: the operator account name is not given, so the mockups show "operator".

## Direction

- Catalog direction: `cinematic-monumental`. Vast dark space, one decisive object per view, silence around it.
- Borrowed trait (1): monospace data framing from `tactical-terminal`, used only for live data in the bar, lock status and terminals.
- Big idea: the screen is a templum, the quartered sky an augur read. The agents fly in the cuneus, the Roman wedge, and the system reads their flight.
- Research: no film was used as a spec. The Roman references (aquila, cuneus, vexillum, transverse centurion crest, inscriptional capitals) are drawn from general knowledge and redrawn as original geometry.

## Shell-ban list

1. No centered card login on a blurred photo.
2. No rounded corners anywhere. Radius is 0.
3. No glow-everything neon. Red glows only on engines and the planet rim.
4. No gold text on red. No red body text on black (accent red is 3.28:1).
5. No trooper armor on a character, no faces, no film silhouettes. The helmet is a Roman galea read through steel.
6. No palette shown as a uniform card grid.

## Tokens

```css
:root {
  --bg: #0B0C0E;
  --bg-dark: #07080A;
  --bg-darker: #030405;
  --panel: #15171B;
  --input: #1E2126;
  --fg: #D8DBDF;
  --fg-2: #A3A9B1;
  --fg-3: #848B95;
  --marble: #F1EFE9;
  --accent: #C21F27;
  --accent-text: #EA4D55;
  --selection: #4A1216;
  --muted: #535A64;
  --gold: #C9A24A;
  --gold-hi: #E2C27A;
  --gold-lo: #7E6126;
  --c-black: #2A2E34;
  --c-red: #EA4D55;
  --c-green: #8FAE6B;
  --c-yellow: #D8B45A;
  --c-blue: #7C9CC0;
  --c-magenta: #B76A9A;
  --c-cyan: #6FB3A8;
  --c-white: #D8DBDF;
  --c-bright-black: #848B95;
  --c-bright-red: #FF6A6F;
  --c-bright-green: #A9C985;
  --c-bright-yellow: #E9CB7E;
  --c-bright-blue: #9DB9D9;
  --c-bright-magenta: #D08AB5;
  --c-bright-cyan: #8FCFC4;
  --c-bright-white: #F1EFE9;
  --font-display: "Noto Serif Display", "Noto Serif", serif;
  --font-ui: "Adwaita Sans", "Inter", sans-serif;
  --font-mono: "Adwaita Mono", "Iosevka", monospace;
  --track-display: 0.18em;
  --track-wide: 0.4em;
  --step--1: 13px;
  --step-0: 16px;
  --step-1: 20px;
  --step-2: 24px;
  --step-3: 32px;
  --step-4: 48px;
  --step-hero: clamp(56px, 13cqi, 220px);
  --sp-1: 4px;
  --sp-2: 8px;
  --sp-3: 12px;
  --sp-4: 16px;
  --sp-6: 24px;
  --sp-8: 32px;
  --sp-12: 48px;
  --sp-16: 64px;
  --sp-24: 96px;
  --page-max: 1600px;
  --radius: 0;
  --rule: 1px;
  --ease: cubic-bezier(0.2, 0, 0, 1);
  --dur-ui: 160ms;
  --dur-scene: 900ms;
  --dur-caret: 1060ms;
}
```

## Contrast pairs (WCAG ratio)

| Pair | Ratio | Use |
|---|---|---|
| --fg on --bg | 14.09 | body text |
| --fg on --panel | 12.92 | panel text |
| --fg-3 on --input | 4.70 | password placeholder |
| --fg-3 on --panel | 5.22 | captions |
| --marble on --bg | 17.02 | clocks, headings |
| --gold on --bg | 8.15 | insignia, display marks |
| --accent-text on --panel | 4.86 | login error text |
| --fg on --selection | 13.1 | selected session |
| --marble on --accent | 5.19 | rare red buttons |
| --accent on --bg | 3.28 | non-text only: borders, wedges |
| --muted on --bg | 2.81 | decoration only, never meaning alone |

## Per-surface storyboard

- Login: clock low on the left, a vexillum banner on the right third hanging from a gold crossbar under the eagle. The banner holds avatar, user, password and the session picker.
- Boot: black, small eagle, tracked name, 10 wedges in a tetractys that light red one by one.
- Lock: one centered monument. Eagle, clock, a single password line, fleet status.
- Desktop: bar with Roman-numeral workspaces and a fleet counter, ghostty left, Claude Code right, red active border.
- Wallpaper: a 10-ship cuneus flying left over a dark planet with a red rim. Templum cross lines at low contrast. Subject under 35% of the frame.

## Motion

- Boot wedges light in sequence at 900 ms per step. The login caret blinks. Nothing else moves.
- `prefers-reduced-motion: reduce`: wedges show a static partial state, the caret is solid.

## Change log

- 2026-11-25: contract written with the board.
- 2026-11-25: the board uses the ANSI `--c-*` set, `--track-wide`, `--dur-caret`, the `--step-*` type scale, the `--sp-*` spacing scale and `--page-max`. All are in the token block.
- 2026-11-25: recorded exception. eagle.svg and helmet.svg use the gradient stops #8E161C and #B48D3A, which are not tokens.
- 2026-11-25: type sizes inside the mockups are native 5120x2160 px, not board scale.
- 2026-11-25: login uses login-bg.svg, the wallpaper without the fleet, so the banner does not cut the ships.
