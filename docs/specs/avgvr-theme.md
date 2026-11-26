# AVGVR theme

- Status: draft for build.
- Ticket: `ai_docs/plans/avgvr-theme/brief.md`. Decisions: `ai_docs/plans/avgvr-theme/decisions.md`.
- Design: `design/directions/c/` (DIRECTION.md Rev 5, `colors.toml`, `mark.svg`, `wallpaper.svg`, `fonts/`, `index.html`).
- Base spec: `docs/specs/auspex-foundation.md` (here "foundation"). This spec fills foundation section 13 item "Theme spec".
- Machine facts in this spec were read on 2026-11-26 without sudo. Section 3 lists them.

## 0. Terms

- **Palette**: the file `themes/avgvr/colors.toml`. It is the only source of color and font tokens.
- **Template**: a file `templates/<app>/<name>.tpl`. The renderer fills it from the palette.
- **Render target**: a manifest row with mode `render`. `auspex apply` renders the template and then handles the result as a `copy` target.
- **Generated asset**: a file that `auspex theme build` makes from the palette and the design files, and that the repo commits. Examples: PNG files, TTF files, the SDDM `theme.conf`. Root-tier steps install only generated assets and repo files, never files that apply makes.
- **Stage**: 1 of the 4 places where the operator sees AVGVR: boot splash, login, desktop, lock.
- **Band**: the full-width "inscription band" between 2 dentil rails (DIRECTION.md "Layout").

## 1. Requirements summary

| ID | Requirement | Section |
|---|---|---|
| R1 | 1 palette drives every target. A color change is 1 edit, then `auspex theme build` and `auspex apply`. | 4 |
| R2 | The SDDM login is AVGVR for both sessions. The default session choice does not change. | 6 |
| R3 | The boot shows an AVGVR plymouth splash. The kernel command line gets `quiet splash`. | 7 |
| R4 | Hyprland, waybar, mako, fuzzel and hyprlock are AVGVR. | 8 |
| R5 | ghostty and Claude Code use the palette. | 9 |
| R6 | The 3 font families work for the `sddm` user and for the user session. | 5 |
| R7 | KDE config does not change. Game config does not change. | 11 |
| R8 | Each stage has a test that needs no reboot. Each root change has an undo. No stage can lock the operator out. | 10, 12 |

Out of scope: KDE theming, AI-first slice 2 (the bar has only a placeholder slot for the fleet counter), a change to the default SDDM session, a cursor change (DIRECTION.md names no cursor, so the cursor stays as it is).

## 2. Repo layout (new and changed)

```
themes/
├── README.md                       # changed: describes this layout
├── current                         # 1 line: "avgvr". The theme that apply renders.
└── avgvr/
    ├── colors.toml                 # the palette (section 4.1)
    ├── sddm/                       # SDDM theme sources: Main.qml, metadata.desktop, components
    ├── plymouth/                   # plymouth sources: avgvr.plymouth, avgvr.script
    └── generated/                  # user-tier generated assets (wallpaper PNG) + INPUTS.sha256
templates/
├── README.md                       # changed: template syntax (section 4.2)
├── hypr/theme.lua.tpl
├── hypr/hyprlock.conf.tpl          # replaces config/hypr/hyprlock.conf
├── hypr/hyprpaper.conf.tpl
├── waybar/style.css.tpl
├── mako/config.tpl                 # replaces config/mako/config
├── fuzzel/fuzzel.ini.tpl           # replaces config/fuzzel/fuzzel.ini
├── ghostty/avgvr.tpl
├── claude/avgvr.json.tpl
├── sddm/theme.conf.tpl             # rendered by theme build, not by apply
└── plymouth/avgvr.script.tpl       # rendered by theme build, not by apply
system/files/avgvr/                 # root-tier generated assets + SHA256SUMS
├── SHA256SUMS
├── fonts/                          # Jost, Marcellus SC TTF + OFL.txt files
├── sddm/                           # the full theme folder for /usr/share/sddm/themes/avgvr
└── plymouth/                       # the full theme folder for /usr/share/plymouth/themes/avgvr
system/steps/
├── 050-avgvr-fonts.sh
├── 060-avgvr-sddm.sh
├── 070-avgvr-plymouth.sh
└── 080-avgvr-boot-splash.sh
packages/
├── hyprland.list                   # changed: + hyprpaper
└── avgvr.list                      # new: plymouth, ttf-jetbrains-mono
lib/render.sh                       # the renderer (section 4.2)
bin/auspex-theme-build              # level 2 (section 4.4)
bin/auspex-check-theme              # level 1 (section 12)
hooks/theme-set.d/                  # new event (section 4.3)
config/ghostty/config.ghostty       # replaces .gitkeep
agent/skills/auspex/reference/theme.md   # skill page: how to change the theme
docs/checklists/avgvr-acceptance.md      # operator checklist (section 12.2)
```

`design/directions/c/` stays the frozen design record. The build reads it. The build does not edit it.

## 3. Machine facts

| Fact | Value | Effect on this spec |
|---|---|---|
| SDDM | 0.21.0, Qt 6 greeter `sddm-greeter-qt6`, no qt5-declarative | The theme is Qt 6 QML. `metadata.desktop` has `QtVersion=6`. |
| SDDM config | No `/etc/sddm.conf`, no `/etc/sddm.conf.d/`. `/usr/lib/sddm/sddm.conf.d/default.conf` has `[Theme] Current=` (empty) and `DisplayServer=x11`. | Today SDDM shows its built-in theme. This is the "ugly" login. |
| SDDM themes | breeze, elarun, maldives, maya in `/usr/share/sddm/themes` | breeze is a known good theme for the fallback. |
| Bootloader | Limine 12.9.6. `/boot` is the vfat ESP and only root can read it. | The spec cannot read `limine.conf`. Step 080 reads it as root (section 7.4). |
| Kernel image | mkinitcpio UKI. `/etc/mkinitcpio.d/linux.preset`: `PRESETS=('default')`, `default_uki="/boot/EFI/Linux/arch-linux.efi"`, `--splash` with the Arch BMP. | The UKI embeds the command line and the initramfs. 1 `mkinitcpio -P` rebuilds both. No fallback UKI is built. |
| Command line | `/etc/kernel/cmdline` equals `/proc/cmdline`: `root=PARTUUID=17d6692e-… zswap.enabled=0 rootflags=subvol=@ rw rootfstype=btrfs`. No package owns the file. | Step 080 adds `quiet splash` to this file. |
| mkinitcpio HOOKS | `base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck`. Drop-in `/etc/mkinitcpio.conf.d/auspex-nvidia.conf` exists (step 020). | A drop-in cannot insert into an array, so step 080 sets the full HOOKS array. |
| Kernel | 7.3.4-arch1-1, NVIDIA, early KMS from step 020 | plymouth can use the DRM device early. |
| Packages present | hyprland 0.57.2, hyprlock 0.9.7, waybar 0.16.0, mako 1.11.0, fuzzel 1.15.0, ghostty 1.4.0, resvg 0.49.0, librsvg 2.63.4, woff2 1.0.2 (`woff2_decompress`), python-fonttools | Theme build uses `resvg` and `woff2_decompress`. |
| Packages absent | plymouth, hyprpaper, swaybg, ttf-jetbrains-mono | Steps 010 and 070 install them. |
| Fonts | `fc-list` has no Jost, Marcellus SC or JetBrains Mono | Step 050 installs them. |
| Cursors | breeze_cursors, Adwaita, Oxygen themes | No change. |
| ghostty config | `~/.config/ghostty/config.ghostty` exists and has only comments | The render row needs `auspex apply --adopt` 1 time. |
| Claude Code | 2.1.332. `~/.claude/settings.json` has `"theme": "dark"`. No `~/.claude/themes/`. | Custom theme support is not verified (OQ2). |
| Monitor | 5120x2160 ultrawide | Every layout is drawn for a 2160 px height and scales by height. |

## 4. Palette, render mode and theme build

### 4.1 Palette

`themes/avgvr/colors.toml` has only lines of these 3 forms:

```
# comment
key = "#RRGGBB"
key = "text"
```

- `key` matches `^[a-z][a-z0-9_]*$`. A key occurs 1 time. Another line form is an error. This strict subset lets a bash parser read it safely, so the renderer needs no TOML library.
- The palette has every key of `design/directions/c/colors.toml` with the same values (accent, selection, muted, cursor, the background and foreground steps, `color0` to `color15`, porphyry, bronze, bronze_dark, gold, verdigris, border, crest, helmet_gold, gold_shadow, laurel_bronze). The build copies the key names exactly from that file.
- The palette also has the DIRECTION.md tokens that the design file does not have: `bg`, `bg_dark`, `bg_darker`, `surface`, `text`, `text_muted`, `text_faint`, `text_bright`.
- Font and shape tokens:

```
font_display = "Marcellus SC"
font_body = "Jost"
font_data = "JetBrains Mono"
border_width = "1"
radius = "0"
motion_ms = "200"
```

- `auspex check theme` fails when a hex color in `design/directions/c/mark.svg` or `wallpaper.svg` is not a palette value. So the SVGs keep their own colors, but they cannot drift from the palette without a failed check.

### 4.2 Renderer and template syntax

`lib/render.sh` defines `auspex_render <palette> <template> <out>`. It writes `<out>` atomically (temp file, then `mv`).

Syntax in a template:

| Form | Output for `bronze = "#C9A05A"` |
|---|---|
| `{{ bronze }}` | `#C9A05A` |
| `{{ bronze \| bare }}` | `C9A05A` |
| `{{ bronze \| rgba:ff }}` | `C9A05Aff` (fuzzel, hyprlock) |
| `{{ bronze \| dec }}` | `201, 160, 90` |
| `{{ font_body }}` | `Jost` |

Rules:

- An unknown key, an unknown filter, or a color filter on a text value stops the render with the template path and line number.
- Text that still has `{{` after the render is an error.
- The renderer reads no environment value and no file except the palette and the template. The same inputs give the same bytes.
- Spaces inside `{{ }}` are optional.

Manifest rows use mode `render`:

```
templates/waybar/style.css.tpl	~/.config/waybar/style.css	render	hyprland
```

- `auspex_manifest_load` renders each `render` row with the palette `themes/$(cat themes/current)/colors.toml` into `$AUSPEX_STATE/rendered/<target rel path>`. After that, the row is the same as a `copy` row whose source is the rendered file. Plan, drift check, adopt, undo and generations do not change.
- The index records mode `render`. When a row changes from `copy` to `render` for the same target, and the target hash equals the recorded hash, apply does not report drift. A test covers this (section 12).
- A palette edit changes all render targets in 1 generation. `auspex undo` restores all of them in 1 step.
- `themes/current` holds 1 theme name. The name must be a folder in `themes/`. Only `avgvr` exists now.

### 4.3 The `theme-set` event

- Foundation 2.5 reserves `theme-set`. auspex runs `hooks/theme-set.d/*` after the `post-apply` or `post-undo` hooks, only when at least 1 `render` target changed. It passes the generation number as `$1`. The hooks find the changed targets in the same way as the `post-apply` hooks.
- A failed hook prints a warning, as in foundation 2.5.
- Hooks in this spec:
  - `10-waybar`: if waybar runs and `style.css` changed, send `SIGUSR2` to the waybar PID from `pidof waybar`. waybar reloads its style on that signal.
  - `20-hyprpaper`: if hyprpaper runs and the wallpaper or `hyprpaper.conf` changed, run `hyprctl hyprpaper reload ,<path>`.
  - `30-ghostty`: if the ghostty theme changed, send `SIGUSR2` to each ghostty PID. The build must verify that ghostty 1.4.0 reloads its config on `SIGUSR2`. If it does not, the hook prints "open a new ghostty window to see the theme" and does nothing else.
- Hyprland and mako need no new hook. `post-apply.d/10-reload-hyprland` and `30-mako` already reload on a change to their targets.

### 4.4 Theme build (generated assets)

`auspex theme build` (`bin/auspex-theme-build`, level 2, no sudo) makes every generated asset:

| Output | Made from | Tool |
|---|---|---|
| `system/files/avgvr/fonts/Jost.ttf`, `MarcellusSC-Regular.ttf`, the OFL files | `design/directions/c/fonts/*.woff2` | `woff2_decompress` |
| `themes/avgvr/generated/wallpaper.png` (5120x2160) | `wallpaper.svg` | `resvg --use-font-file <the TTF files>` |
| `system/files/avgvr/sddm/*` | `themes/avgvr/sddm/*`, `templates/sddm/theme.conf.tpl`, `wallpaper.svg` (login backdrop), `mark.svg` | copy, `auspex_render`, `resvg` |
| `system/files/avgvr/plymouth/*` | `themes/avgvr/plymouth/*`, `templates/plymouth/avgvr.script.tpl`, `mark.svg`, wordmark and numeral SVGs that the build script writes | copy, `auspex_render`, `resvg` |
| `system/files/avgvr/SHA256SUMS` | every file above in `system/files/avgvr/` | `sha256sum` |
| `themes/avgvr/generated/INPUTS.sha256` | each input file and `bin/auspex-theme-build` itself | `sha256sum` |

Notes:

- `resvg` does not load the `@font-face` data URIs in `wallpaper.svg`. The build passes the decompressed TTF files with `--use-font-file`, so the text renders in the correct fonts. The family names in the SVG must equal the TTF family names. `auspex check theme` compares them.
- The woff2 files are Latin subsets. They are enough for the display and body text, which is English and Latin capitals. JetBrains Mono comes from the `ttf-jetbrains-mono` package, because a terminal needs the full set of box and symbol glyphs (OQ7).
- `auspex check theme` recomputes `INPUTS.sha256` and fails when it differs ("run auspex theme build"). It compares input hashes, not output bytes, so a new `resvg` version does not fail the check.
- The repo commits the generated assets. A root step installs only committed files with known hashes (section 5.1).

## 5. Fonts and root-tier binary files

### 5.1 Binary files in system steps (runner change)

Foundation `lib/system-steps.sh` reads each declared file into a bash variable. It refuses a file with a NUL byte or a file larger than 128 KiB. PNG and TTF files fail both limits. This spec adds 1 mechanism:

- A step declares the text file `system/files/avgvr/SHA256SUMS` in `# auspex:reads=`. The approved copy of this file, and so each hash in it, is part of the plan digest that the operator approves.
- The runner gives the root shell a function `step_install_verified <sums> <repo dir> <dest dir>`. For each line of the approved `SHA256SUMS` that is under `<repo dir>`, it copies the file into a root-owned `mktemp -d` folder, checks its sha256 against the line, and only then installs it with `install -D -m 644`. On a hash mismatch it installs nothing and returns 1.
- A file that `SHA256SUMS` does not list is never read as root.
- `auspex system plan` prints each `SHA256SUMS` line, so the operator sees the file list.
- `auspex check system-steps` fails when a step reads a repo path that is not in a `reads` line or in a declared `SHA256SUMS` file.

This keeps the foundation rule "as root, a step must not read other files through `AUSPEX_REPO`" true in effect: root reads only bytes whose hashes the operator approved.

### 5.2 Step 050-avgvr-fonts

| Part | Content |
|---|---|
| Headers | `auspex:level=3`, `requires-sudo=true`, `reads=packages/avgvr.list system/files/avgvr/SHA256SUMS` |
| check | `ttf-jetbrains-mono` is installed, and each `fonts/*` file in `SHA256SUMS` is in `/usr/local/share/fonts/avgvr/` with the correct hash. |
| apply | `pacman -S --needed ttf-jetbrains-mono` (record what it installed, as step 010 does). `step_install_verified` into `/usr/local/share/fonts/avgvr/`. `fc-cache -f /usr/local/share/fonts/avgvr`. |
| undo | Remove `/usr/local/share/fonts/avgvr/`. `pacman -Rns` the packages that this step installed. `fc-cache -f`. |

- `/usr/local/share/fonts` is in the default fontconfig path. The `sddm` user, the user session, waybar, mako, fuzzel, hyprlock and ghostty all see the fonts. 1 install serves the login and the desktop (R6).
- plymouth does not use these fonts. Its text is pre-rendered PNG (section 7.2).
- Only `packages/avgvr.list` names `ttf-jetbrains-mono`. Step 070 reads the same list for `plymouth`. Each step installs only its own line, by a fixed name in the step.

## 6. Stage 1: SDDM login

### 6.1 Theme

Sources in `themes/avgvr/sddm/`. Theme build copies them, with the rendered `theme.conf` and the PNG files, into `system/files/avgvr/sddm/`.

- `metadata.desktop`: `Name=AVGVR`, `MainScript=Main.qml`, `ConfigFile=theme.conf`, `Theme-API=2.0`, `QtVersion=6`.
- `theme.conf`: rendered from the palette. It holds every color and font name that `Main.qml` uses. `Main.qml` has no hex color.
- `backdrop.png`: 5120x2160, from `wallpaper.svg` (birds are allowed in the login backdrop, DIRECTION.md). `mark.png`: from `mark.svg`, 128 px or larger.

Layout (follow `design/directions/c/index.html`, the login view):

- The backdrop fills the screen. The band runs the full width of the screen in the lower third, with a dentil rail above and below it. There is no centered card, no rounded box, no avatar.
- Inside the band, from left to right: a user field, a password field, a session selector, and at the right end the clock in `font_display` and gold. Power actions (`[ REBOOT ]`, `[ POWEROFF ]`) are small `font_data` labels in muted text, at the right under the band.
- Labels are Marcellus SC, uppercase, letter spacing +0.12em, V for U in Latin words.
- Sizes use 1 unit `u = Screen.height / 2160`. Border 1 px. Radius 0. No shadow. Motion 200 ms.
- Accent rule: the only accent element is the login-failed message. Focus is a gold underline, not accent.

Behavior:

- The user field starts with `userModel.lastUser`. When that is set, the password field has focus at start.
- The session selector starts at `sessionModel.lastIndex`. The theme never changes the session default. SDDM keeps recording the last session as it does today (R2).
- Enter in the password field calls `sddm.login(user, password, sessionIndex)`. Tab moves user → password → session → power actions.
- `onLoginFailed`: clear the password, show the message in accent, keep focus on the password.
- `keyboard.capsLock` shows `[ CAPS ]` in muted text.
- Reduced motion: the band has no motion. The only motion is a 200 ms color change on focus.

### 6.2 Step 060-avgvr-sddm

| Part | Content |
|---|---|
| Headers | `reads=system/files/avgvr/SHA256SUMS` |
| check | `/usr/share/sddm/themes/avgvr/` matches every `sddm/*` line of `SHA256SUMS` and has no other file. `/etc/sddm.conf.d/zz-auspex-avgvr.conf` has the exact content below. |
| apply | Refuse if `/usr/share/sddm/themes/breeze/Main.qml` is missing (the fallback must exist). `step_install_verified` into a new folder `/usr/share/sddm/themes/avgvr.new`, then rename it to `avgvr` (replace the old folder). Write the conf file. Do not restart SDDM. |
| undo | Remove `/etc/sddm.conf.d/zz-auspex-avgvr.conf`. Remove `/usr/share/sddm/themes/avgvr/`. Remove `/etc/sddm.conf.d/` only if it is empty and the step made it (record this in `/var/lib/auspex/060-avgvr-sddm.made-dir`). |

```
# /etc/sddm.conf.d/zz-auspex-avgvr.conf  (written by auspex step 060)
[Theme]
Current=avgvr
Font=Jost,11
```

- The file sets only `[Theme] Current` and `Font`. It does not set `[General]`, `[Autologin]`, `[Users]` or a session key. The default session choice does not change.
- The name starts with `zz-` so that it sorts after `kde_settings.conf`. SDDM reads `sddm.conf.d` in name order and a later file wins. If the operator later changes the login screen in KDE System Settings, AVGVR still wins. OQ11 records this.
- The change takes effect at the next greeter start (log out, or reboot). The step does not restart SDDM, because that ends the running session.

### 6.3 Foundation amendment (KDE deny list)

Foundation section 10 says "No system step writes under `/etc/sddm.conf.d/`, `/usr/share/sddm/`". Step 060 must write there. The build changes these 3 places:

1. Foundation section 10, bullet 2, becomes: "No system step writes under `/etc/sddm.conf.d/`, `/usr/share/sddm/`, or `/usr/share/plasma/`, except step `060-avgvr-sddm`, which writes only `/etc/sddm.conf.d/zz-auspex-avgvr.conf` and `/usr/share/sddm/themes/avgvr/` (`docs/specs/avgvr-theme.md` section 6.3)."
2. Foundation section 3.6 rule "A step never edits a file under … `/etc/sddm.conf.d/` except where this spec says so" gets the same reference.
3. `bin/auspex-check-system-steps`: before it applies `deny_re` to a line, it removes the 2 exact strings `/etc/sddm.conf.d/zz-auspex-avgvr.conf` and `/usr/share/sddm/themes/avgvr` (and `avgvr.new`), but only when the file name is `060-avgvr-sddm.sh`. Any other SDDM path still fails, in any step.

New fixtures in `tests/fixtures/system/bad/`:

- `sddm-breeze.sh` writes `/usr/share/sddm/themes/breeze/x`. It must fail.
- `sddm-exact-path-wrong-step.sh` writes `/etc/sddm.conf.d/zz-auspex-avgvr.conf` but is not step 060. It must fail.
- The existing `sddm.sh` must still fail. The build checks which path it writes and keeps it outside the exception.

### 6.4 Test without a reboot

1. `auspex check theme` (no display): `metadata.desktop` has `QtVersion=6`; `Main.qml` has no `#` hex color; `/usr/lib/qt6/bin/qmllint` reports no syntax error in `Main.qml` (unknown-import warnings for `SddmComponents` are allowed).
2. Operator, in a running session, before step 060: `sddm-greeter-qt6 --test-mode --theme system/files/avgvr/sddm`. The greeter opens in a window. Check layout, focus, Tab order, session list. Login in test mode does not log in.
3. After step 060, run the same command with `--theme /usr/share/sddm/themes/avgvr` to test the installed copy.
4. Log out to see the real greeter. This is not a reboot.

## 7. Stage 2: plymouth boot splash

### 7.1 Approach (Omarchy)

Omarchy ships its own script theme in `default/plymouth/` (`omarchy.plymouth`, `omarchy.script`, PNG files) and rebuilds it with sudo in a separate step from the theme switch (`docs/research/omarchy-ai-first.md`, "Plymouth"). This spec does the same: theme build makes the PNG files, and steps 070 and 080 install them with sudo. A palette change needs `auspex theme build` and a new `auspex system apply 070`. The plan for 070 then shows changed hashes.

### 7.2 Theme

`/usr/share/plymouth/themes/avgvr/`:

- `avgvr.plymouth`: `ModuleName=script`, `ImageDir=` and `ScriptFile=` that point at this folder.
- `avgvr.script`: rendered from `templates/plymouth/avgvr.script.tpl`. It sets the window top and bottom color to `bg`.
- PNG files: `mark.png` (256 px, the helmet mark), `wordmark.png` (AVSPEX in Marcellus SC, `text_bright`), `dentil-off.png` (`surface`), `dentil-on.png` (`bronze`), `numeral-<I..X>-off.png` (`text_faint`), `numeral-<I..X>-on.png` (`gold`), `entry.png` and `bullet.png` for a password band.

Script behavior:

- Center column: the mark, then the wordmark, then a row of numerals I to X, then a dentil bar of 40 blocks. The bar is about 40 % of the screen width.
- `Plymouth.SetBootProgressFunction` and `Plymouth.SetSystemUpdateFunction` call the same function with the progress `p` from 0 to 1. It lights `floor(p * 40)` blocks from left to right, and numeral `k` when `p >= k / 10`.
- The fill moves in whole blocks only. plymouth has no reduced-motion signal and a boot is short, so this spec uses the reduced-motion form for all boots (DIRECTION.md "Reduced motion"). The glide is dropped.
- `SetDisplayPasswordFunction` shows the band with 1 bullet per character. This machine has no encrypted disk, but the callback keeps a future encrypted disk from a blind prompt.
- `SetMessageFunction` shows messages in `text_muted` under the bar.
- Scale: the script scales every image by `Window.GetHeight() / 2160`.

### 7.3 Step 070-avgvr-plymouth

| Part | Content |
|---|---|
| Headers | `reads=packages/avgvr.list system/files/avgvr/SHA256SUMS` |
| check | `plymouth` installed; `/usr/share/plymouth/themes/avgvr/` matches the `plymouth/*` lines; `plymouth-set-default-theme` prints `avgvr`. |
| apply | `pacman -S --needed plymouth` (record). Install the theme folder with `step_install_verified` (folder `.new`, then rename). Save `/etc/plymouth/plymouthd.conf` to `/var/lib/auspex/070-avgvr-plymouth.plymouthd.conf.before` if no copy exists yet. Run `plymouth-set-default-theme avgvr` without `-R`. |
| undo | Restore `plymouthd.conf` from the copy. Remove the theme folder. `pacman -Rns` the packages that this step installed. |

Step 070 does not change the initramfs or the command line. After 070 the operator can preview the splash (section 7.6) with no effect on the next boot.

### 7.4 Step 080-avgvr-boot-splash

This step changes the boot. It is a separate step so that its undo is small and clear.

Drop-in `/etc/mkinitcpio.conf.d/auspex-plymouth.conf`:

```
# Written by auspex step 080. Main HOOKS plus plymouth after udev.
HOOKS=(base udev plymouth autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)
```

| Part | Content |
|---|---|
| Headers | none beyond level and sudo; the drop-in text is in the step |
| check | The drop-in has the exact text. `/etc/kernel/cmdline` has the words `quiet` and `splash`. |
| apply | See the guarded list below. |
| undo | Remove the drop-in. Restore `/etc/kernel/cmdline` from the copy if the file equals the copy plus ` quiet splash`. Otherwise remove only the 2 words that the step added. `mkinitcpio -P`. |

apply, in order. Each guard stops the step with a clear message and changes nothing:

1. Guard: step 020 is applied (`/etc/mkinitcpio.conf.d/auspex-nvidia.conf` exists) and step 070 is applied (`plymouth-set-default-theme` prints `avgvr`).
2. Guard: the HOOKS line of `/etc/mkinitcpio.conf` equals the value the step expects (the list in section 3). If it differs, the step prints both and stops, because the drop-in would hide a change to the main file.
3. Guard: `/etc/cmdline.d/` does not exist. mkinitcpio can take the UKI command line from `/etc/cmdline.d/*.conf` instead of `/etc/kernel/cmdline`. A new `/etc/cmdline.d` could drop `root=` from the boot. The build must confirm the precedence in the installed mkinitcpio (OQ4). The step never makes `/etc/cmdline.d`.
4. Guard: read each of `/boot/limine.conf`, `/boot/limine/limine.conf`, `/boot/EFI/limine/limine.conf`, `/boot/EFI/BOOT/limine.conf` that exists. If an entry for `arch-linux.efi` has a `cmdline:` (or `kernel_cmdline:`) line, stop and print it. A command line from Limine can replace the UKI command line when Secure Boot is off, so `quiet splash` in `/etc/kernel/cmdline` would have no effect (OQ3). The step never writes in `/boot` except through `mkinitcpio -P`.
5. Copy `/etc/kernel/cmdline` to `/var/lib/auspex/080-avgvr-boot-splash.cmdline.before` if no copy exists yet.
6. Write the drop-in. Add `quiet` and `splash` to the end of the 1 line of `/etc/kernel/cmdline`, each only if it is not there.
7. `mkinitcpio -P`. If it fails: restore the drop-in state and the command line, run `mkinitcpio -P` again, and return 1.

The kernel options are only `quiet splash`, as the ticket says and as Omarchy uses. The Arch BMP `--splash` in `linux.preset` does not change. Limine does not show it, and plymouth draws over it.

### 7.5 What a boot then looks like

Limine menu, then the plymouth AVGVR splash with the dentil fill, then the SDDM AVGVR greeter. plymouth quits when SDDM starts. On NVIDIA the splash can start a short time after the kernel, when `nvidia_drm` loads. This is expected.

### 7.6 Test without a reboot

1. `auspex check theme`: `avgvr.plymouth` points at files that exist; the rendered script has no `{{`; each PNG named in the script exists in the folder.
2. Operator, after step 070, from a text console (Ctrl+Alt+F3, logged in):

   ```
   sudo plymouthd
   sudo plymouth show-splash
   for p in 0 10 20 30 40 50 60 70 80 90 100; do sudo plymouth system-update --progress=$p; sleep 1; done
   sudo plymouth ask-for-password --prompt=test
   sudo plymouth quit
   ```

   The splash shows the fill and the numerals, then the password band. Ctrl+Alt+F1 or F2 returns to the session. The build writes this into the acceptance checklist with the correct console numbers for this machine.
3. After step 080 and before a reboot: `lsinitcpio -a /boot/EFI/Linux/arch-linux.efi` is not readable by the user, so the operator runs `sudo lsinitcpio /boot/EFI/Linux/arch-linux.efi | grep plymouth` and checks that the plymouth files are in the image. `sudo objcopy -O binary --only-section=.cmdline /boot/EFI/Linux/arch-linux.efi /dev/stdout` shows `quiet splash`.
4. The 1st reboot after step 080 is the real test.

## 8. Stage 3 and 4: Hyprland desktop and lock

All rows below are user tier and go through `auspex apply`. None changes a KDE file.

### 8.1 Manifest changes

| Source | Target | Mode | Session | Change |
|---|---|---|---|---|
| `templates/hypr/theme.lua.tpl` | `~/.config/hypr/theme.lua` | render | hyprland | new |
| `config/hypr/hyprland.lua` | `~/.config/hypr/hyprland.lua` | copy | hyprland | edited: loads `theme.lua`, starts hyprpaper |
| `templates/hypr/hyprpaper.conf.tpl` | `~/.config/hypr/hyprpaper.conf` | render | hyprland | new |
| `themes/avgvr/generated/wallpaper.png` | `~/.local/share/auspex/wallpaper/avgvr.png` | copy | hyprland | new |
| `templates/hypr/hyprlock.conf.tpl` | `~/.config/hypr/hyprlock.conf` | render | hyprland | was copy |
| `config/waybar/config.jsonc` | `~/.config/waybar/config.jsonc` | copy | hyprland | edited |
| `templates/waybar/style.css.tpl` | `~/.config/waybar/style.css` | render | hyprland | new |
| `templates/mako/config.tpl` | `~/.config/mako/config` | render | hyprland | was copy |
| `templates/fuzzel/fuzzel.ini.tpl` | `~/.config/fuzzel/fuzzel.ini` | render | hyprland | was copy |
| `templates/ghostty/avgvr.tpl` | `~/.config/ghostty/themes/avgvr` | render | any | new |
| `config/ghostty/config.ghostty` | `~/.config/ghostty/config.ghostty` | copy | any | new, needs `--adopt` |
| `templates/claude/avgvr.json.tpl` | `~/.claude/themes/avgvr.json` | render | any | new (OQ2) |

The old sources `config/hypr/hyprlock.conf`, `config/mako/config`, `config/fuzzel/fuzzel.ini` and `config/ghostty/.gitkeep` are removed. Each new target gets Edit and Write deny rules in `claude/deny.json` (foundation `auspex check permissions`).

### 8.2 Hyprland

`theme.lua` returns the look settings. `hyprland.lua` loads it in the same way it loads `agent-binds.lua` and passes the values to the existing config calls. Values:

| Setting | Value |
|---|---|
| border size | `border_width` (1) |
| active border | `bronze` |
| inactive border | `border` |
| rounding | `radius` (0) |
| shadow, blur | off (DIRECTION.md: no shadow) |
| gaps in / out | 6 / 12 px. On 5120x2160 this keeps window edges clear of the band without waste. |
| group bar | `surface` background, `gold` text for the active group |
| animations | on; speed `motion_ms / 100` (Hyprland speed is in units of 100 ms), 1 linear-out curve; no slide, no bounce |
| background color | `bg_darker` (shows before hyprpaper loads) |
| `misc` | `disable_hyprland_logo = true`, `disable_splash_rendering = true`, `allow_session_lock_restore = true` |

- `allow_session_lock_restore = true` is a lock-out guard (section 10).
- `hyprland.lua` starts `hyprpaper` with the other `exec_cmd` lines. `packages/hyprland.list` gets `hyprpaper`. The operator runs `auspex system apply 010` again to install it.
- `hyprpaper.conf` preloads and sets `~/.local/share/auspex/wallpaper/avgvr.png` for every monitor. The build checks that hyprpaper 0.7+ accepts `~` in the path. If it does not, the template uses a `home` value that `auspex_render` takes from a fixed key `home` that apply adds (the only non-palette key).
- No cursor setting, no `XCURSOR_*` or `GTK_THEME` or `QT_*` variable. Games and KDE inherit nothing new.

### 8.3 waybar: the inscription band

- `config.jsonc`: `position: top`, full width (no margins), height `40`, `layer: top`, `exclusive: true`.
- Modules left to right:
  - `hyprland/workspaces` with `format: "{icon}"` and `format-icons` 1→I … 10→X. Persistent workspaces I to V.
  - `custom/legio`: the fleet counter slot. It shows the static text `LEGIO [ – · – ]` with `exec` set to a `printf` and no interval. AI-first slice 2 replaces it. No bird.
  - `clock` in the center: `font_display`, gold, `{:%A %d %B   %H:%M}`.
  - `pulseaudio`, `network`, `tray` at the right, each in `font_data` in `[ ]` brackets, for example `[ VOL 40 ]`, `[ ETH ]`.
- `style.css`:
  - `window#waybar` background `bg_dark`, 1 px `border` top and bottom, and a dentil rail: a `repeating-linear-gradient` of `bronze_dark` blocks on the bottom 3 px.
  - Workspace buttons: `font_display`, letter spacing 0.12em, `text_muted`; the active button has background `porphyry` and `text_bright` text; the urgent button has `accent` text. That is the only accent in the bar.
  - Radius 0, no shadow, transition 200 ms on color only.
- The bar is 1 band, not a dock and not a sidebar (DIRECTION.md shell bans).

### 8.4 mako, fuzzel

- mako: `font=Jost 11`, `background-color=bg_dark`, `text-color=text`, `border-color=border`, `border-size=1`, `border-radius=0`, `padding=12`, `default-timeout=8000` (kept). `[urgency=high]` sets `border-color=accent`. `[urgency=low]` sets `text-color=text_muted`.
- fuzzel: `font=Jost:size=12`, `[colors]` in `RRGGBBAA` with the `rgba:ff` filter: background `bg_dark`, text `text`, match `gold`, selection `selection`, selection-text `text_bright`, border `bronze`. `[border] width=1 radius=0`. `terminal=ghostty -e` is kept.

### 8.5 hyprlock: the closed band

The lock is static (DIRECTION.md "Lock").

- `background`: color `bg_darker`, no blur, no image.
- A `shape` 100 % wide and 1 px high, color `bronze`, at the vertical center: the band "closed to a thin carved line".
- `label` above the line: the time in `font_display`, `gold`, large. `label` below: the date in `font_body`, `text_muted`.
- `image`: the mark, 64 px, above the time.
- `input-field`: 1 px high outline that sits on the line, `outer_color` `bronze`, `inner_color` `bg_darker`, `font_color` `text_bright`, `rounding 0`, `fade_on_empty true`, `check_color` `gold`, `fail_color` `accent` (the only accent).
- Test without a lock-out: run `hyprlock` from a terminal in the session first. The operator types the password to unlock. Then use `SUPER+L`.

## 9. ghostty and Claude Code

### 9.1 ghostty

- `~/.config/ghostty/themes/avgvr` sets `background = bg`, `foreground = text`, `cursor-color = cursor`, `selection-background = selection`, `selection-foreground = text_bright`, and `palette = 0=…` to `palette = 15=…` from `color0` to `color15`.
- `config.ghostty` sets `theme = avgvr`, `font-family = JetBrains Mono`, `font-size = 12`, `window-padding-x = 12`, `window-padding-y = 8`, `cursor-style = block`. It keeps no other setting, because today the file has only comments.
- Session: `any`. ghostty reads the same file under KDE, so the terminal is AVGVR in both sessions. This is the recommendation of OQ1. ghostty is not a KDE file and `auspex check kde-untouched` does not flag it.
- Check: `ghostty +validate-config --config-file=<rendered file>` in `auspex check theme`.

### 9.2 Claude Code

- `~/.claude/themes/avgvr.json` follows the key set of Omarchy `default/themed/claude.json.tpl` (keys `claude`, `text`, `permission`, `success`, `error`, and the others). The build reads that template at the Omarchy commit of the research report (foundation OQ8) and maps the keys: `claude` → `bronze`, `text` → `text`, `permission` → `gold`, `success` → `verdigris`, `error` → `accent`, inactive and subtle keys → `text_muted` and `text_faint`.
- Activation: the `claude-settings` merger (`lib/merge/claude-settings`) gets 1 new owned key: top-level `theme`. `claude/deny.json` gets `"theme": "custom:avgvr"`. The merger records the previous value (`"dark"`) and undo restores it. A merger owns only keys that its source names, so other settings do not change.
- Gate (OQ2): before the build adds the `theme` key, it confirms that Claude Code 2.1.332 lists `custom:avgvr` in `/theme` after the file exists. If it does not, the build keeps the `avgvr.json` row, does not add the `theme` key, and records the result in OQ2.

## 10. Lock-out analysis and fallbacks

| Stage | Failure | What the operator sees | Recovery |
|---|---|---|---|
| Fonts (050) | a font is missing or bad | Qt and GTK use a fallback font | none needed; `auspex system undo 050` |
| SDDM (060) | QML error in the theme | SDDM 0.21 may show its built-in theme or an error screen (OQ8) | Ctrl+Alt+F3, log in on the text console, `auspex system undo 060`, `sudo systemctl restart sddm`. The greeter is then the built-in theme of today. To use breeze instead: write `Current=breeze` in the same conf file (the checklist gives the exact line). |
| SDDM (060) | session list wrong | login into the wrong session | the session selector; the default comes from SDDM state, which the theme does not write |
| plymouth (070) | theme error | plymouth falls back to its text splash | `auspex system undo 070` |
| boot (080) | splash does not show, or shows late | a black screen until SDDM | Esc during boot shows the text log. Boot continues; plymouth does not block the boot. `auspex system undo 080`. |
| boot (080) | `mkinitcpio -P` fails | the step reports an error | the step restores the old state and rebuilds (section 7.4 item 7) |
| boot (080) | the new UKI does not boot | Limine shows an error | Limine has no 2nd entry today and `linux.preset` builds no fallback UKI. The operator must have an Arch install USB before applying 080, chroot, and run `auspex system undo 080` or remove the drop-in and the 2 words by hand. The acceptance checklist makes "Arch USB at hand" item 1 of the boot stage. |
| hyprlock | config error or crash while locked | Hyprland shows the "lock dead" screen | Ctrl+Alt+F3, log in, `hyprctl --instance 0 dispatch exec hyprlock`. This works because `allow_session_lock_restore = true` (section 8.2). |
| Any user-tier target | bad look | — | `auspex undo` |

The KDE session is the fallback desktop. Nothing in this spec changes it (section 11).

## 11. Invariants

### 11.1 KDE files that must not change

User files (manifest must have no row for them; `auspex check kde-untouched` covers the `~/.config` ones):

- `~/.config/kdeglobals`, `kwinrc`, `kwinrulesrc`, `plasmarc`, `plasmashellrc`, `plasma-org.kde.plasma.desktop-appletsrc`, `kscreenlockerrc`, `ksplashrc`, `kcminputrc` (the cursor), `kxkbrc`, `kded6rc`, `breezerc`, `ksmserverrc`.
- `~/.config/kglobalshortcutsrc`, except the 2 groups that the foundation merger owns.
- `~/.config/gtk-3.0/settings.ini`, `~/.config/gtk-4.0/settings.ini`, `~/.config/Trolltech.conf`, `~/.config/fontconfig/` (Plasma writes them; this spec sets fonts system-wide, not per user).
- `~/.local/share/color-schemes/`, `~/.local/share/plasma/`, `~/.local/share/konsole/`, `~/.local/share/aurorae/`.

System files (no step writes them):

- `/usr/share/plasma/`, `/etc/xdg/kdeglobals`.
- `/usr/share/sddm/themes/breeze/` and the other packaged SDDM themes.
- `/usr/lib/sddm/sddm.conf.d/default.conf` (package file).
- `/etc/sddm.conf.d/kde_settings.conf` if it exists. Step 060 writes only its own file.

Shared by both sessions on purpose, so listed here for the operator: the SDDM theme, the plymouth splash, the 3 system font families, the `quiet splash` command line, and the ghostty theme (OQ1).

### 11.2 Game config that must not change

- No manifest row and no step writes under `~/.steam`, `~/.local/share/Steam`, `~/.config/lutris`, `~/.local/share/lutris`, `~/.config/heroic`, `~/Games`, any Wine or Proton prefix, or `/usr/share/steam`.
- No new environment variable in either session.
- The only shared effect is 3 new font families in fontconfig. Wine and Proton prefixes keep their own font settings.
- `auspex check theme` greps the manifest and the new steps for these paths and fails on a hit.

## 12. Test seams

### 12.1 Repo checks (no sudo, no display)

| Part | Check command | What it verifies |
|---|---|---|
| Renderer | `bats tests/render.bats` | each filter; unknown key, unknown filter, color filter on text, bad palette line, and leftover `{{` all fail with a line number; same input gives same bytes; no environment value leaks in |
| Render mode | `bats tests/apply.bats` (new cases) | a `render` row applies, drifts, adopts and undoes like `copy`; a palette edit changes all render targets in 1 generation; `copy` → `render` on the same target with an unchanged file is not drift; `theme-set` hooks run only when a render target changed |
| Theme hooks | `bats tests/hooks.bats` (new cases) | `theme-set.d` order and `$1`; fake `pidof`, `kill`, `hyprctl` on `PATH` |
| Theme | `auspex check theme` | every `templates/**/*.tpl` renders with the current palette; `INPUTS.sha256` is current; `SHA256SUMS` matches the files; SVG colors are palette values; SVG font names equal TTF names; DIRECTION.md contrast pairs meet their ratios when computed from the palette; SDDM and plymouth checks of sections 6.4 and 7.6; `Hyprland --verify-config` on `hyprland.lua` with the rendered `theme.lua` (skip if not installed); `jq` on the rendered Claude JSON and on `config.jsonc` after comment removal; `fuzzel --check-config` on the rendered ini; `ghostty +validate-config`; the game-path grep of section 11.2 |
| System steps | `auspex check system-steps` | the new steps have check, apply, undo and headers; the SDDM exception of section 6.3 and its 2 new bad fixtures; `step_install_verified` refuses a file with a wrong hash (fixture in `tests/fixtures/system/blobs/`); a step that reads an undeclared repo file fails |
| KDE | `auspex check kde-untouched` | unchanged rule; the new rows pass; still exactly 2 KDE rows |
| Permissions | `auspex check permissions` | new targets have deny rules; `auspex theme build` (level 2) has an allow rule; `auspex check theme` (level 1) has an allow rule |

Test seams in the code:

- `AUSPEX`, `AUSPEX_STATE` and `HOME` as in foundation section 11.
- Each step takes its target roots from variables, as step 020 does: `AUSPEX_SDDM_THEME_DIR`, `AUSPEX_SDDM_CONF_DIR`, `AUSPEX_PLYMOUTH_THEME_DIR`, `AUSPEX_FONT_DIR`, `AUSPEX_MKINITCPIO_DIR`, `AUSPEX_KERNEL_CMDLINE`, `AUSPEX_LIMINE_CONFS`, `AUSPEX_SYSTEM_STATE`. bats runs check, apply and undo in a temp root with fake `pacman`, `mkinitcpio`, `fc-cache` and `plymouth-set-default-theme` on `PATH`. A test for step 080 covers each guard of section 7.4 and the restore after a failed `mkinitcpio`.
- `auspex theme build --dry-run` prints the outputs and changes nothing.

### 12.2 Operator checks (display, sudo)

`docs/checklists/avgvr-acceptance.md`, 1 part per stage, in build order. Each item has a "result" column that the operator fills:

- Login: test mode before and after step 060; log out; log in to Hyprland; log out; log in to Plasma; session default unchanged.
- Boot: Arch USB at hand; `limine.conf` has no command line for the UKI (step 080 guard 4 also checks); preview after 070; checks after 080; 1 reboot.
- Desktop: wallpaper, borders, gaps, bar, notification (`notify-send test`), launcher, lock and unlock.
- Terminal and Claude Code: a new ghostty window in both sessions; Claude Code `/theme`.
- Fallback drill: undo 060 from a text console and see the old greeter, then apply again.

## 13. Build order

Each item is 1 ticket and ends with its checks from section 12. The ticket listed fonts last. They move to item 1 here, because the login (item 2) needs the fonts and the palette.

1. Palette, `lib/render.sh`, the `render` mode, the `theme-set` event, `auspex theme build`, `auspex check theme` (theme parts that exist so far), the binary-file mechanism (section 5.1), `packages/avgvr.list`, step 050. The operator applies 050.
2. SDDM: theme sources, generated `system/files/avgvr/sddm/`, step 060, the foundation amendment and check change (section 6.3). The operator runs test mode, applies 060, logs out.
3. plymouth: theme sources, generated `system/files/avgvr/plymouth/`, steps 070 and 080. The operator previews after 070, then applies 080 and reboots.
4. Hyprland: `theme.lua`, `hyprland.lua` edits, hyprpaper in `packages/hyprland.list`, wallpaper. The operator applies step 010 again and runs `auspex apply`.
5. waybar band.
6. mako, fuzzel, hyprlock.
7. ghostty (after OQ1 is answered).
8. Claude Code (with the OQ2 gate).
9. Skill page `agent/skills/auspex/reference/theme.md` (how to change a color: edit the palette, `auspex theme build`, `auspex apply`, and `auspex system apply 060 070` when a root asset changed) and the acceptance checklist.

Items 1 and 4 to 9 need no reboot. Item 3 needs 1 reboot. Item 2 needs 1 logout.

## Open Questions

- **OQ1. Apply the ghostty theme under KDE too?** ghostty reads 1 config file in both sessions. A Hyprland-only theme needs a 2nd launcher path with `--config-file`, and a ghostty started another way would not get it. Recommendation: apply it in both sessions (`any`). ghostty is not KDE config, and the operator asked for AVGVR "all the way". If the operator wants KDE ghostty unchanged, the build instead adds `--config-file=~/.config/ghostty/avgvr.ghostty` to the Hyprland `SUPER+Return` bind and the dropdown, and leaves `config.ghostty` alone.
- **OQ2. Does Claude Code 2.1.332 load `~/.claude/themes/*.json` as `custom:<name>`?** Omarchy relies on it, but the research report marks it as not verified (U2). Recommendation: the build tests it first (section 9.2 gate). If it is not supported, ship only the JSON file and keep `"theme": "dark"`.
- **OQ3. Does `limine.conf` set a command line for the UKI entry?** The user cannot read `/boot`. `/proc/cmdline` equals `/etc/kernel/cmdline`, so either the UKI command line is in use or Limine passes the same text. Recommendation: step 080 checks this as root (guard 4) and stops if Limine sets one. The operator can check first with `sudo grep -rn -i cmdline /boot --include=limine.conf`.
- **OQ4. Which command line source does the installed mkinitcpio prefer?** Recommendation: the build reads `/usr/lib/initcpio/functions` (or the mkinitcpio script) for the UKI command line order and writes the result in the step 080 header. Step 080 refuses when `/etc/cmdline.d/` exists, and never makes it.
- **OQ5. hyprpaper or swaybg?** Recommendation: hyprpaper. It is the Hyprland project tool, it has an IPC reload for the `theme-set` hook, and Omarchy uses the Hyprland stack. swaybg would need a process restart on each change.
- **OQ6. Keep the SDDM greeter on X11?** `default.conf` sets `DisplayServer=x11`. A Wayland greeter is a separate change with its own risk on NVIDIA. Recommendation: keep X11. The QML theme works on both, so a later change does not affect this spec.
- **OQ7. Fonts from the woff2 subsets or from packages?** Jost and Marcellus SC are not in the official repos, and steps do not use the AUR. Recommendation: decompress the design woff2 files (Latin subsets) for Jost and Marcellus SC, and use the `ttf-jetbrains-mono` package for the terminal font, because the Latin subset lacks box glyphs. Jost is a variable font; the build checks that waybar, mako and fuzzel select weights 400, 500 and 600 from it. If fcft (fuzzel) cannot, the build makes static instances with `fonttools varLib.instancer` in theme build.
- **OQ8. What does SDDM 0.21 do when a theme has a QML error?** Not verified. Recommendation: rely on test mode before apply and on the text-console recovery in section 10. Do not set a 2nd theme in config, because SDDM has no chained fallback.
- **OQ9. The fleet counter slot.** Recommendation: a static `LEGIO [ – · – ]` label now. AI-first slice 2 replaces its `exec` with the real counts. The style for the slot is final now.
- **OQ10. Glide in the boot fill.** DIRECTION.md asks for a glide with a stepped form for reduced motion. Recommendation: steps only (section 7.2), because plymouth cannot read a motion preference. The operator can ask for the glide later; it is a script change in 1 function.
- **OQ11. `zz-` name for the SDDM conf.** It makes AVGVR win over a later KDE System Settings change of the login theme. The KDE dialog then shows a theme that is not in use. Recommendation: keep `zz-`. The operator manages the login theme through auspex only. The skill page says so.
