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

## Agent dropdown on KDE

Method: the ghostty quick terminal. Tested on 2026-11-25 with Plasma 6.8.2,
KWin 6.8.2 Wayland, ghostty 1.4.0 (ticket 07). It shows at the top, 100% x
50%, takes keyboard focus, and hides again.

Dropdown config file (ticket 08 adds it as config/ghostty/auspex-dropdown.ghostty):

```
quick-terminal-position = top
quick-terminal-size = 50%
initial-window = false
quit-after-last-window-closed = false
command = auspex agent --here
```

Start 1 dropdown instance. It has no window until the 1st toggle:

```
ghostty --config-default-files=false \
  --config-file=<repo>/config/ghostty/auspex-dropdown.ghostty \
  --class=auspex.dropdown --gtk-single-instance=true
```

Toggle it from outside ghostty with the D-Bus action of that instance:

```
gdbus call --session --dest auspex.dropdown --object-path /auspex/dropdown \
  --method org.gtk.Actions.Activate toggle-quick-terminal [] {}
```

The dropdown command (auspex agent dropdown, added in ticket 08) does this:

1. Test the bus name: `gdbus call --session --dest org.freedesktop.DBus
   --object-path /org/freedesktop/DBus --method
   org.freedesktop.DBus.NameHasOwner auspex.dropdown`.
2. If the result is false, start the instance (command above), and poll the
   bus name every 0.1 s for at most 5 s. The test took 116 ms.
3. Send the toggle.

Rules from the test:

- `--gtk-single-instance=true` is necessary. Without it, ghostty does not
  take the bus name when it gets command-line arguments.
- `--config-default-files=false` keeps the operator's
  `~/.config/ghostty/config.ghostty` out of the dropdown.
- The bus name is not D-Bus activatable. A toggle without a running
  instance fails with `ServiceUnknown`.
- The quick terminal is a layer-shell surface. KWin reports its class as
  `ghostty`, not `auspex.dropdown`. A KWin window rule cannot match it, and
  none is necessary.
- The quick terminal uses the working directory of the ghostty process.
  Start the instance from `$HOME` or pass `--working-directory`.
- Do not set a ghostty `keybind` for the dropdown. KWin takes the global
  key before ghostty sees it. If a keybind is wanted, the key name is
  `backquote`. `grave` is invalid in ghostty and opens a
  "Configuration Errors" dialog.
- Do not use the `global:` keybind prefix. It registers through the
  desktop portal, and that writes `~/.config/kglobalshortcutsrc`.
- Not tested: a 2nd toggle after the agent process exits in the dropdown.

The KWin window rule is not necessary. Do not use Yakuake.

## Load a new [services] shortcut without a logout

kglobalaccel runs inside `kwin_wayland` on Plasma 6.8. There is no
separate service to restart, and no reload method. These do not load a new
`[services]` group: `kwriteconfig6` alone, `qdbus6 org.kde.KWin /KWin
reconfigure`, `kbuildsycoca6`, `kbuildsycoca6 --noincremental`.

This loads the shortcut at once, with no logout. The `.desktop` file must
be in `~/.local/share/applications/` first, or kglobalaccel ignores the call:

```
ID="['auspex-agent-dropdown.desktop','_launch','auspex dropdown','Launch auspex dropdown']"
gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
  --method org.kde.KGlobalAccel.doRegister "$ID"
gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
  --method org.kde.KGlobalAccel.setForeignShortcutKeys "$ID" "[([402653280],)]"
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
  --method org.kde.KGlobalAccel.unregister auspex-agent-dropdown.desktop _launch
```

kglobalaccel then removes the group from the file. In the test, the file
was byte-identical to the backup after undo. To restore an earlier value,
call `setForeignShortcutKeys` with that value instead of `unregister`.

Not tested: a real key press on the live shortcut. The operator presses each
key once in the ticket 08 operator step.
