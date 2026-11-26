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

## Agent hotkey

`Meta+Alt+A` runs `auspex agent --window` from
`~/.local/share/applications/auspex-agent.desktop`. That shows the
`auspex agent` space in the herdr app (`herdr-app`). It makes the space when
there is none, and starts Claude Code there again when it has ended. Both
desktops use the same command. There is no dropdown key: it was removed on
2026-11-25 at the operator's request.

## Load a new [services] shortcut without a logout

kglobalaccel runs inside `kwin_wayland` on Plasma 6.8. There is no
separate service to restart, and no reload method. These do not load a new
`[services]` group: `kwriteconfig6` alone, `qdbus6 org.kde.KWin /KWin
reconfigure`, `kbuildsycoca6`, `kbuildsycoca6 --noincremental`.

This loads the shortcut at once, with no logout. The `.desktop` file must
be in `~/.local/share/applications/` first, or kglobalaccel ignores the call:

```
ID="['auspex-agent.desktop','_launch','auspex agent','Launch auspex agent']"
gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
  --method org.kde.KGlobalAccel.doRegister "$ID"
gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
  --method org.kde.KGlobalAccel.setForeignShortcutKeys "$ID" "[([402653249],)]"
```

- kglobalaccel then writes `[services][<file>] _launch=<key>` to
  `~/.config/kglobalshortcutsrc` itself, in the same form as `kwriteconfig6`.
  The `kwriteconfig6` write before it is still correct and keeps the
  earlier-value record simple.
- The key is a Qt key code: Meta `0x10000000`, Alt `0x08000000`, Shift
  `0x02000000`, plus the key. `Meta+Alt+A` is `402653249`. `Meta+Alt+\``
  is `402653280`. Both were free on 2026-11-25
  (`org.kde.KGlobalAccel.isGlobalShortcutAvailable <code> x` returned true).
- Check: `qdbus6 org.kde.kglobalaccel /kglobalaccel
  org.kde.KGlobalAccel.action <code>` prints the `.desktop` file and
  `_launch`.
- Launch test without a key press: `qdbus6 org.kde.kglobalaccel
  /component/<file with . and - as _> org.kde.kglobalaccel.Component.invokeShortcut
  _launch`.

Undo, live:

```
gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
  --method org.kde.KGlobalAccel.setForeignShortcutKeys "$ID" "@a(ai) []"
gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
  --method org.kde.KGlobalAccel.unregister auspex-agent.desktop _launch
```

kglobalaccel then removes the group from the file. In the test, the file
was byte-identical to the backup after undo. To restore an earlier value,
call `setForeignShortcutKeys` with that value instead of `unregister`.

Not tested: a real key press on the live shortcut. The operator presses each
key once in the ticket 08 operator step.
