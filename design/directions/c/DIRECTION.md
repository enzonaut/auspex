# Design direction c: AVGVR

Status: draft - Revision 1 - 2026-11-25
Owner: design-director-2
Review board: index.html (this folder). Palette: colors.toml. Wallpaper: wallpaper.svg.

## Brief
- Subject: the auspex OS shell (SDDM login, plymouth boot, lock, Hyprland desktop, ghostty, Claude Code).
- Audience: 1 operator on 1 ultrawide monitor, 5120x2160 (64:27).
- Feeling: a vigilant war machine from a Roman legion watches over the machine for you.
- Constraint: no Zeon emblem, no real mobile-suit designs, no Gundam names, no copied Roman artifacts.
- Constraint: not the rejected "Galactic Empire Legion" look (black, steel grey, blood red, gold eagles).
- Assumption: the colors.toml foreground ramp key names mirror the background ramp (dark_, darker_, lighter_).

## Direction
- Direction: cinematic-monumental. Borrowed trait from tactical-terminal: monospace data in bracket framing, used only in the bar and the terminals.
- Why: 1 horizontal visor slit across a vast olive field uses the 64:27 width as the subject, and the slit carries every control.
- Research: inferred, no film research. Sources: Roman augury (the auspex reads the sky by the flight of birds), lorica segmentata (segmented plate armor), mono-eye war machines as a genre.
- Big idea: the auspex is an augur with 1 mechanical eye. The eye sweeps the horizon while agents work and stops on the thing that needs you.

## Shell-ban list
- Black ground with blood red and gold eagle (the rejected Empire Legion look).
- A centered login card with a rounded box, an avatar circle and a blue button.
- A full-height left sidebar or a floating rounded dock bar.
- A round Zeon-like emblem or a copied mobile-suit head silhouette.
- Generic cyber-HUD neon cyan.

## Tokens
```css
:root {
  --color-bg: #1A2016;
  --color-bg-dark: #141911;
  --color-bg-darker: #0E110C;
  --color-surface: #262E21;
  --color-plate: #323C2B;
  --color-selection: #3B4832;
  --color-text: #DDD7BE;
  --color-text-muted: #ADA88E;
  --color-text-faint: #8C8A72;
  --color-text-bright: #F2EDDA;
  --color-border: #7C7D66;
  --color-accent: #FF4D7E;      /* the eye */
  --color-accent-dim: #D46A8C;  /* eye at rest, shut visor line */
  --color-eye-core: #FFE3EA;    /* hot center of the eye, non-text */
  --color-command: #B8332A;     /* commander red, fills only */
  --color-bronze: #C9A04E;
  --color-verdigris: #5FA391;
  --font-display: "Marcellus SC", serif;
  --font-stencil: "Big Shoulders Stencil Display", sans-serif;
  --font-body: "Chakra Petch", sans-serif;
  --font-mono: "JetBrains Mono", monospace;
  --type-ratio: 1.618;
  --space-unit: 8px;
  --radius: 0;
  --border: 1px solid var(--color-border);
  --shadow: none;
  --dur-ui: 200ms;
  --dur-scene: 1200ms;
  --dur-sweep: 4800ms;
  --ease-enter: cubic-bezier(0.22, 1, 0.36, 1);
  --ease-exit: cubic-bezier(0.4, 0, 1, 1);
}
```

Contrast pairs:
| Text | Background | Ratio | Use |
|---|---|---|---|
| --color-text | --color-bg-darker | 13.2:1 | login body, clock |
| --color-text-bright | --color-bg | 14.2:1 | display numerals |
| --color-text-muted | --color-bg-darker | 7.9:1 | login labels |
| --color-text-faint | --color-bg | 4.7:1 | captions only |
| --color-accent | --color-bg-darker | 6.0:1 | eye, active marks |
| --color-bronze | --color-bg-darker | 7.8:1 | Latin capitals |
| --color-text-bright | --color-command | 5.0:1 | text on the red standard |
| --color-border | --color-bg | 3.9:1 | non-text rules, input edge |

## Typography
- Display: Marcellus SC, uppercase, letter spacing +0.12em. Use V for U in Latin words (AVGVR, not AUGUR).
- Stencil: Big Shoulders Stencil Display 700/900 for unit numbers and numerals only.
- Body and UI: Chakra Petch 400/500/600. Line height 1.5 for body.
- Data: JetBrains Mono, in [ brackets ] in the bar.

## Imagery
- Original vector art only: the plate eagle, the plate laurel, augur sky lines, bird omens, hazard stripes.
- Materials: olive armor plate with rivets, bronze trim with a verdigris patina.

## Motion character
- The eye sweep is the only ambient motion: 4800 ms per full pass, ease-in-out.
- The eye stops and brightens when it needs the operator (password field, waiting agent).
- Boot: the sweep leaves a filled trail that is the progress bar.
- Reduced motion: the eye holds still at center, the trail fills without the sweep.

## Do
- Put the primary control of each screen inside the horizontal visor slit.
- Use Roman numerals for workspaces and unit numbers.
- Use olive and khaki for 90% of the area. Use accent pink only for the eye and the 1 thing that needs action.

## Do not
- No border-radius above 0.
- No pure black (#000000) grounds.
- No more than 1 element in accent color per view, plus the eye.
- No round emblem behind the eagle.

## Change log
| Rev | Date | Change | Reason | Approved by |
|---|---|---|---|---|
| 1 | 2026-11-25 | Initial direction | Zeon x Rome brief, designer c | design-director-2 |
