#!/usr/bin/env bats
# Tests for auspex agent, auspex agent dropdown and auspex check kde-untouched.
# claude, ghostty and gdbus are fakes. No test starts a real agent.

load test_helper

setup() {
    auspex_test_setup
    unset HYPRLAND_INSTANCE_SIGNATURE
    W="$TEST_TMP/work"
    mkdir -p "$W"
    make_fake claude 'printf "actor=%s pwd=%s\n" "${AUSPEX_ACTOR:-}" "$PWD"'
    make_fake ghostty 'touch "$TEST_TMP/up"'
}

teardown() {
    auspex_test_teardown
}

@test "--here --dry-run prints the interactive command" {
    run auspex agent --here --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"mode: here"* ]]
    [[ "$output" == *"cwd: $HOME/repos/auspex"* ]]
    [[ "$output" == *"env: AUSPEX_ACTOR=agent"* ]]
    [[ "$output" == *"run: claude --settings $HOME/.config/auspex/claude/agent-settings.json"* ]]
}

@test "--here --dry-run adds the prompt as the last argument" {
    run auspex agent --here --prompt 'check the disk' --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"agent-settings.json check\\ the\\ disk"* ]]
}

@test "--window --dry-run opens ghostty that runs auspex agent --here" {
    run auspex agent --window --cwd /srv --prompt hi --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"run: ghostty --class=auspex.agent -e $AUSPEX/bin/auspex agent --here --cwd /srv --prompt hi"* ]]
}

@test "--headless --dry-run prints the read-only command and the report file" {
    run auspex agent --headless --prompt 'list failed units' --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"run: claude -p --settings $HOME/.config/auspex/claude/headless-settings.json --disallowedTools Edit\\,Write\\,NotebookEdit list\\ failed\\ units"* ]]
    [[ "$output" == *"report: $AUSPEX_STATE/reports/agent-"*".md"* ]]
}

@test "with no TTY the default mode is window" {
    run auspex agent --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"mode: window"* ]]
}

@test "no mode passes --dangerously-skip-permissions" {
    for m in --here --window "--headless --prompt x"; do
        # shellcheck disable=SC2086
        run auspex agent $m --dry-run
        [ "$status" -eq 0 ]
        [[ "$output" != *dangerously* ]]
    done
}

@test "bad arguments are refused" {
    run auspex agent --headless --dry-run
    [ "$status" -ne 0 ]
    run auspex agent --here --report "$W/r.md" --dry-run
    [ "$status" -ne 0 ]
    run auspex agent --here --window --dry-run
    [ "$status" -ne 0 ]
    run auspex agent --yolo
    [ "$status" -ne 0 ]
    run auspex agent --cwd
    [ "$status" -ne 0 ]
}

@test "--here runs claude in the cwd with AUSPEX_ACTOR=agent" {
    run auspex agent --here --cwd "$W"
    [ "$status" -eq 0 ]
    [ "$output" = "actor=agent pwd=$W" ]
    [ "$(fake_calls claude)" = "--settings $HOME/.config/auspex/claude/agent-settings.json" ]
}

@test "--headless writes the claude output to the report file" {
    run auspex agent --headless --prompt 'p q' --cwd "$W" --report "$W/out/r.md"
    [ "$status" -eq 0 ]
    [ "$output" = "report: $W/out/r.md" ]
    [ "$(cat "$W/out/r.md")" = "actor=agent pwd=$W" ]
    [ "$(fake_calls claude)" = "-p --settings $HOME/.config/auspex/claude/headless-settings.json --disallowedTools Edit,Write,NotebookEdit p q" ]
}

@test "--window starts ghostty" {
    run auspex agent --window --cwd "$W"
    [ "$status" -eq 0 ]
    [ "$(fake_calls ghostty)" = "--class=auspex.agent -e $AUSPEX/bin/auspex agent --here --cwd $W" ]
}

# The gdbus fake owns auspex.dropdown when $TEST_TMP/up exists. The ghostty
# fake makes that file.
fake_gdbus() {
    make_fake gdbus 'if [[ "$*" == *NameHasOwner* ]]; then
    if [[ -e "$TEST_TMP/up" ]]; then echo "(true,)"; else echo "(false,)"; fi
fi'
}

@test "dropdown prints skip on Hyprland and outside KDE" {
    fake_gdbus
    HYPRLAND_INSTANCE_SIGNATURE=x XDG_CURRENT_DESKTOP=KDE run auspex agent dropdown
    [ "$status" -eq 0 ]
    [[ "$output" == skip:* ]]
    XDG_CURRENT_DESKTOP=GNOME run auspex agent dropdown
    [ "$status" -eq 0 ]
    [[ "$output" == skip:* ]]
    [ -z "$(fake_calls gdbus)" ]
    [ -z "$(fake_calls ghostty)" ]
}

@test "dropdown starts the ghostty instance once, then toggles it" {
    fake_gdbus
    XDG_CURRENT_DESKTOP=KDE run auspex agent dropdown
    [ "$status" -eq 0 ]
    [ "$(fake_calls ghostty)" = "--config-default-files=false --config-file=$AUSPEX/config/ghostty/auspex-dropdown.ghostty --class=auspex.dropdown --gtk-single-instance=true" ]
    [[ "$(fake_calls gdbus)" == *"--dest auspex.dropdown --object-path /auspex/dropdown --method org.gtk.Actions.Activate toggle-quick-terminal [] {}"* ]]
    : >"$CALLS/ghostty"
    : >"$CALLS/gdbus"
    XDG_CURRENT_DESKTOP=KDE run auspex agent dropdown
    [ "$status" -eq 0 ]
    [ -z "$(fake_calls ghostty)" ]
    [ "$(fake_calls gdbus | grep -c toggle-quick-terminal)" -eq 1 ]
}

@test "dropdown fails when ghostty does not take the bus name" {
    fake_gdbus
    make_fake ghostty 'exit 0'
    XDG_CURRENT_DESKTOP=KDE run auspex agent dropdown
    [ "$status" -ne 0 ]
    [[ "$output" == *"did not take the bus name"* ]]
    [[ "$(fake_calls gdbus)" != *toggle-quick-terminal* ]]
}

@test "the dropdown ghostty config has no keybind and runs the agent" {
    f="$AUSPEX_REPO/config/ghostty/auspex-dropdown.ghostty"
    ! grep -q '^keybind' "$f"
    grep -qxF 'command = auspex agent --here' "$f"
    grep -qxF 'quick-terminal-position = top' "$f"
}

@test "the .desktop files run auspex by an explicit path" {
    for f in "$AUSPEX_REPO"/config/applications/auspex-agent*.desktop; do
        grep -q '^Exec=sh -c "exec \\\\"\\\\$HOME/.local/bin/auspex\\\\" agent ' "$f"
        if command -v desktop-file-validate >/dev/null; then desktop-file-validate "$f"; fi
    done
}

kde_repo() {
    make_repo_copy
    mkdir -p "$AUSPEX/manifest"
    cp -- "$AUSPEX_REPO/manifest/user.tsv" "$AUSPEX/manifest/user.tsv"
}

@test "check kde-untouched passes on the repo manifest" {
    kde_repo
    run auspex check kde-untouched
    [ "$status" -eq 0 ]
}

@test "check kde-untouched fails on another KDE target" {
    for t in '~/.config/kwinrc' '~/.config/plasma-org.kde.plasma.desktop-appletsrc' '~/.config/kdeglobals' '~/.config/foo/bar.rc' '~/.config/kglobalshortcutsrc'; do
        kde_repo
        printf 'x\t%s\tcopy\tkde\n' "$t" >>"$AUSPEX/manifest/user.tsv"
        run auspex check kde-untouched
        [ "$status" -ne 0 ]
        [[ "$output" == *FAIL* ]]
    done
}

@test "check kde-untouched fails when an agent row is missing" {
    kde_repo
    grep -v 'auspex-agent-dropdown.desktop' "$AUSPEX_REPO/manifest/user.tsv" >"$AUSPEX/manifest/user.tsv"
    run auspex check kde-untouched
    [ "$status" -ne 0 ]
}
