# 07 Spike: ghostty quick terminal on KWin, kglobalaccel reload

<!-- horch-ticket: 1 -->
**Persona:** primary `researcher`
**Kind:** report
**Review:** light
**Check:** none
**Own:** `agent/skills/auspex/reference/kde.md`
**Do not touch:** `~/.config/ghostty/config.ghostty`, `~/.config/kglobalshortcutsrc`, `~/.config/kwinrulesrc`, `config/`, `bin/`

Check none: the spike needs a live KWin Wayland session and a person to press the keys.

Spec: sections 7.3, 7.4 and 12 item 7. Time limit: 30 min. OQ4 answer: test the ghostty quick terminal first. The fallback is a KWin window rule for a ghostty window with class `auspex.dropdown`. Do not use Yakuake.

## Do

1. Make a temp ghostty config with `quick-terminal-position = top`, `quick-terminal-size = 50%` and a `toggle_quick_terminal` keybind. Start ghostty with it. Do not change the operator's ghostty config.
2. Record: does the quick terminal show and hide on KWin Wayland? Does it take focus? Does a 2nd toggle work from outside ghostty?
3. If it fails, record how `qdbus6 org.kde.KWin` can show and hide a window with class `auspex.dropdown`, and the KWin rule values (top, 100% x 50%, keep above, skip taskbar).
4. Find the kglobalaccel reload command on Plasma 6.8 that loads a new `[services]` group without a logout. Test it only on a temp group, and remove that group after.
5. Write the results in `agent/skills/auspex/reference/kde.md`: the method that works, the exact commands, and the reload command or "logout needed".

## Done when

- `kde.md` names 1 dropdown method for ticket 08 and the reload command.
- The orchestrator gets a 1-line result with the tag `RESULT:`.
