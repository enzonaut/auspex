# Design direction c: AVGVR

Status: draft - Revision 5 - 2026-11-25
Owner: design-director-4
Review board: index.html (this folder). Palette: colors.toml. Wallpaper: wallpaper.svg. Mark: mark.svg.

## Brief
- Subject: the auspex OS shell (SDDM login, plymouth boot, lock, Hyprland desktop, waybar, ghostty, Claude Code).
- Audience: 1 operator on 1 ultrawide monitor, 5120x2160 (64:27).
- Feeling: a Roman augur reads the sky for you. The shell is calm and stone-built. It shows you the 1 thing that needs you.
- Constraint: Roman only. No mecha, no science-fiction armor, no copied Roman artifacts.
- Constraint: not the rejected "Galactic Empire Legion" look (black, steel grey, blood red, gold raptor standards).
- Assumption: the colors.toml foreground ramp key names mirror the background ramp (dark_, darker_, lighter_).

## Direction
- Direction: cinematic-monumental. Borrowed trait from tactical-terminal: monospace data in bracket framing, used only in the bar and the terminals.
- Why: 1 horizontal inscription band across the 64:27 width carries every control, as the carved band on a Roman arch carries the words.
- Research: inferred, no film research. Sources: Roman augury (the augur marks a templum in the sky and reads the flight of birds), the crested Roman helmet, the laurel crown, dentil molding, aqueduct arcades, porphyry stone.
- Big idea: the auspex is an augur. It watches your agents from a still, carved band and shows you the 1 thing that needs you.

## Shell-ban list
- Black ground with blood red and gold raptor standards (the rejected Empire Legion look).
- A centered login card with a rounded box, an avatar circle and a blue button.
- A full-height left sidebar or a floating rounded dock bar.
- A round emblem disc behind the mark.
- Generic cyber-HUD neon cyan.

## Tokens
```css
:root {
  --color-bg: #1D1915;
  --color-bg-dark: #17140F;
  --color-bg-darker: #110F0D;
  --color-surface: #2A241E;
  --color-porphyry: #4E1C3E;   /* active workspace, session blocks */
  --color-selection: #3A2E3A;
  --color-text: #E6DCCB;
  --color-text-muted: #B8AC98;
  --color-text-faint: #988D7B;
  --color-text-bright: #F6F1E7;
  --color-border: #7A6E5F;
  --color-accent: #EB6A43;     /* the only UI accent: focus, the 1 action. The mark keeps its own red. */
  --color-bronze: #C9A05A;
  --color-bronze-dark: #8C6A30;
  --color-gold: #E0BD6C;
  --color-verdigris: #63A897;
  --font-display: "Marcellus SC", serif;
  --font-body: "Jost", sans-serif;
  --font-mono: "JetBrains Mono", monospace;
  --space-unit: 8px;
  --radius: 0;
  --border: 1px solid var(--color-border);
  --shadow: none;
  --dur-ui: 200ms;
  --ease-enter: cubic-bezier(0.22, 1, 0.36, 1);
  --ease-exit: cubic-bezier(0.4, 0, 1, 1);
}
```

Contrast pairs (WCAG 2.x, AA is 4.5:1 for text and 3:1 for non-text):
| Text | Background | Ratio | Use |
|---|---|---|---|
| --color-text | --color-bg | 12.86:1 | body, clock |
| --color-text-bright | --color-bg | 15.52:1 | display numerals |
| --color-text-muted | --color-bg | 7.81:1 | labels |
| --color-text-faint | --color-bg | 5.35:1 | captions, hints |
| --color-accent | --color-bg | 5.55:1 | the 1 action, active marks |
| --color-accent | --color-surface | 4.87:1 | accent text on raised surfaces |
| --color-bg-darker | --color-accent | 6.08:1 | text on an accent fill |
| --color-bronze | --color-bg | 7.20:1 | Latin capitals |
| --color-gold | --color-bg | 9.70:1 | clock, inscription |
| --color-text-bright | --color-porphyry | 11.96:1 | active workspace numeral |
| --color-gold | --color-porphyry | 7.48:1 | session block labels |
| --color-border | --color-bg | 3.51:1 | non-text rules, input edge |
| red (#DE5A4C) | --color-bg | 4.72:1 | terminal errors (was #C94A3C, 3.8:1) |
| bright_black (#6C6255) | --color-bg | 2.92:1 | dim terminal text only, never for content |

## Typography
- Display: Marcellus SC 400, uppercase, letter spacing +0.12em. Use V for U in Latin words (AVGVR, not AUGUR). Clock, Latin capitals, labels, workspaces.
- Body and UI: Jost variable (400, 500, 600 used). Line height 1.5 for body.
- Data: JetBrains Mono 400 and 700, in [ brackets ] in the bar and in the terminals.
- Numerals: Roman numerals for workspaces and section numbers.
- License: all 3 families are SIL OFL 1.1. The font files and an OFL text for each family are in `fonts/`.

## Imagery
- Original vector art only: the helmet and laurel mark, augur birds, dentil rails, aqueduct arcades, the faint lines and circles of the augur's templum.
- Mark: `mark.svg`, the operator-approved drawing: a crested Roman helmet in open laurel, seen from the front. Crest red #D23A2C with #8A2419 lines, helmet gold #D9A93E, gold shadow #A87A22, laurel bronze #C9A05A on #8C6A30 stems, #1D1915 outlines, transparent background. Do not redraw it. `mark.py` regenerates it. Use it at 32 px and larger. The board shows it large, at 64 px and at 32 px.
- Augur birds: 1 stroked glyph, a curved-wing "m" (`M0,0 q12,-14 24,-4 q8,4 12,8 q4,-4 12,-8 q12,-10 24,4`), laurel bronze #C9A05A, round caps and joins. Vary size and opacity in a flock. 1 gold (#D9A93E) bird can lead it.
- Materials: dark warm stone, bronze with a verdigris patina, gold leaf on the inscriptions, porphyry for the active state.
- Wallpaper: dusk over an aqueduct. The mark hangs in the sky at the right. A flock of augur birds flies up and right. A carved inscription sits low at the left. The subject fills less than a third of the frame.

## Motion character
- No bird moves in the UI. The augur birds appear only as a static flock in the wallpaper and the login backdrop.
- Boot: the splash shows the helmet mark, the word AVSPEX and a dentil progress bar. Bronze dentil blocks fill the band from left to right, and the numerals I to X light up as the row reaches them.
- Login: the inscription band holds user, password and session. Enter submits.
- Lock: the band is closed to a thin carved line. The lock is static.
- Bar: the fleet counter shows LEGIO and the working and waiting counts, with no bird.
- Reduced motion: the dentil row fills in steps, without the glide.

## Do
- Put the primary control of each screen inside the horizontal inscription band.
- Use dentil rails above and below the band.
- Use Roman numerals for workspaces.
- Use warm stone, bronze and gold for 90% of the area. Use the accent only for focus and the 1 thing that needs action. The mark colors stay in the mark and the birds. The accent stays #EB6A43: next to the #D23A2C crest the board does not look wrong.

## Do not
- No border-radius above 0.
- No pure black (#000000) grounds.
- No more than 1 element in accent color per view.
- No round emblem behind the mark.
- No bird inside the mark.

## Change log
| Rev | Date | Change | Reason | Approved by |
|---|---|---|---|---|
| 1 | 2026-11-25 | Initial direction | Zeon x Rome brief, designer c | design-director-2 |
| 2 | 2026-11-25 | Helmet mark replaced by laurel and eagle mark | operator choice | operator |
| 3 | 2026-11-25 | Roman only; helmet and laurel mark; Zeon elements removed | operator choice | operator |
| 4 | 2026-11-25 | Approved helmet mark (orchestrator drawing) and new augur birds | operator choice | operator |
| 5 | 2026-11-25 | Animated birds removed; dentil progress bar kept | operator choice | operator |
