# KDE Plasma

Plasma is the default session. It must stay as the operator set it.

## What you may change

Only the entries in `config/kde/`: the auspex global shortcuts. A merger
adds and removes only those entries in `~/.config/kglobalshortcutsrc`. KDE
keeps every other entry.

## What you may not change

Any other KDE file, such as `~/.config/kwinrc`, `~/.config/plasma*`, or any
`~/.config/k*` file. Do not add a manifest row for them. Do not write them
with a Bash command.

Reason: Plasma writes these files itself. A copy from the repo would
overwrite the operator's changes from System Settings, and Plasma would
overwrite the repo copy back. Neither side would win.

## For any other KDE setting

Tell the operator which System Settings page to open, and what to change
there. Examples:

| Request | Page |
|---|---|
| Display mode, refresh rate, scale | Display & Monitor |
| Other keyboard shortcuts | Keyboard > Shortcuts |
| Theme, colors, fonts | Appearance & Style |
| Panel and widgets | Right-click the panel > Enter Edit Mode |
| Night light | Display & Monitor > Night Light |
| Window behavior | Window Management |

## Read the live state

`kscreen-doctor -o` prints the outputs and modes. It is level 1.

## Changes that also affect KDE

- System steps that change the boot, such as the NVIDIA early module drop-in.
- The browser keyring flags in `config/browser-flags/`.

Tell the operator that these affect both sessions before you prepare them.
