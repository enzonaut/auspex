# Hyprland gaming acceptance checklist

The operator runs this list once, after the 1st login to Hyprland. Spec: sections 9.5 and 9.6.

Write `pass`, `fail`, or `skip` in the Result column. Write a note when the result is not `pass`.

The agent window key and the dropdown key are set in `config/agent-keys.conf`. This list does not repeat the key values.

| # | Item | Result | Notes |
|---|---|---|---|
| 1 | SDDM shows "Hyprland" and "Plasma (Wayland)". | | |
| 2 | Hyprland starts. `hyprctl monitors` shows `5120x2160@165`. | | |
| 3 | `auspex facts --section gpu` shows the 4 env vars and `nvidia-open` 620.70.06. | | |
| 4 | Steam opens. The library shows. Steam dialogs float. | | |
| 5 | 1 Proton game starts and runs at 165 Hz. MangoHud shows the frame rate and the refresh. | | |
| 6 | Lutris opens Battle.net. The Battle.net login window is usable and floats. | | |
| 7 | Heroic (flatpak) opens. | | |
| 8 | Discord screen share. See the steps below. | | |
| 9 | Chrome opens with existing logins. KWallet works. | | |
| 10 | Screenshot region works. Lock works. Volume keys work. Network and Bluetooth tray icons show. | | |
| 11 | The agent window key opens the agent. The dropdown key toggles the dropdown. | | |
| 12 | Log out. Log in to Plasma. Plasma works as before: panels, shortcuts, wallpaper, KWallet, Steam. The agent window key opens the agent. The dropdown key toggles the dropdown. | | |

## Item 8: Discord screen share

1. Test native Discord first. Share 1 window through the portal. The other side must see it.
2. If native Discord fails, test Discord web in Chrome. Share 1 window through the portal.
3. Write which client works in the Notes column.

A client change is a decision for the operator.

## Item 12: undo path

If item 12 fails, run these commands. Use a TTY if the session does not work.

1. `auspex undo` reverts the user tier.
2. `auspex system undo` reverts the system steps.

## Class names that differ from section 9.5

Run `hyprctl clients` while each program is open. Record each class name or title that differs from the spec table.

| Program | Spec class or title | Actual class | Actual title |
|---|---|---|---|
| Steam main window | `steam`, `Steam` | | |
| Steam dialogs | `steam` | | |
| Steam games | `steam_app_.*` | | |
| Battle.net | `battle.net.exe` | | |
| Battle.net login and updater | `Battle.net Login`, `Blizzard Battle.net` | | |
| Lutris | `net.lutris.Lutris` | | |
| Heroic | `heroic` | | |
| ProtonUp-Qt | `net.davidotek.pupgui2` | | |
| gamescope | `gamescope` | | |
| File pickers | `Open File`, `Save File`, portal class | | |
| pavucontrol | | | |
| blueman | | | |
| nm-connection-editor | | | |
