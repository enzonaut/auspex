# 11 Hyprland gaming acceptance checklist

<!-- horch-ticket: 1 -->
**Persona:** primary `sonnet-feature`
**Kind:** docs
**Review:** light
**Check:** none
**Own:** `docs/checklists/hyprland-gaming.md`, `config/hypr/`
**Do not touch:** `config/agent-keys.conf`, `system/`, `claude/`, `~/.config/`

Check none: the operator runs the checklist by hand in a live Hyprland session with a display.

Spec: sections 9.5, 9.6 and 12 item 11. OQ7 answer: test native Discord screen share first. If it fails, test Discord web in Chrome. A change of Discord client is a separate decision for the operator.

## Do

1. Write `docs/checklists/hyprland-gaming.md` with the 12 items of section 9.6 and a result column.
2. Item 8: first native Discord, then Discord web in Chrome if native fails. Add a line: "A client change is a decision for the operator."
3. Items 11 and 12: name the keys as "the agent window key" and "the dropdown key" from `config/agent-keys.conf`. Do not write the key values in the checklist.
4. Item 12: the undo path. `auspex undo` for the user tier, `auspex system undo` for the steps, from a TTY if needed.
5. Add a section for the class names from `hyprctl clients` that differ from section 9.5.
6. Send `OPERATOR:` to the orchestrator: run the checklist after the 1st Hyprland login.
7. After the operator sends the results, fix the class names and rules in `config/hypr/`. Run `bin/auspex check hyprland-rules`.

## Done when

- The checklist file exists with 12 items.
- The operator results are in the file, and each class name fix passes `bin/auspex check hyprland-rules`.
