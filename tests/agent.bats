#!/usr/bin/env bats

load test_helper

setup() {
    auspex_test_setup
    unset HYPRLAND_INSTANCE_SIGNATURE
    W="$TEST_TMP/work"
    mkdir -p "$W"
    make_fake claude 'printf "actor=%s pwd=%s\n" "${AUSPEX_ACTOR:-}" "$PWD"'
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

@test "--window --dry-run shows the herdr app space and the agent command" {
    run auspex agent --window --cwd /srv --prompt hi --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"herdr app space: auspex agent"* ]]
    [[ "$output" == *"run: $AUSPEX/bin/auspex agent --here --cwd /srv --prompt hi"* ]]
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
        read -ra args <<<"$m"
        run auspex agent "${args[@]}" --dry-run
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

SPACE_JSON='{"spaces":[{"id":"sp1","name":"auspex agent","tabs":[{"id":"tb1","terminals":[{"terminal":"t7"}]}]}]}'

@test "--window makes the auspex agent space when there is none" {
    fake_herdr '{"spaces":[{"id":"sp0","name":"~","tabs":[]}]}' '{"terminals":[]}'
    run auspex agent --window --cwd "$W"
    [ "$status" -eq 0 ]
    calls="$(fake_calls herdr-app)"
    [[ "$calls" == *"do space.new --name auspex agent --folder $W --argv [\"$AUSPEX/bin/auspex\",\"agent\",\"--here\",\"--cwd\",\"$W\"]"* ]]
    [[ "$calls" != *tab.new* ]]
}

@test "--window shows the agent when Claude Code runs in the space" {
    fake_herdr "$SPACE_JSON" '{"terminals":[{"address":"t7","agent":"claude-code"},{"address":"t9","agent":"claude-code"}]}'
    run auspex agent --window --cwd "$W"
    [ "$status" -eq 0 ]
    calls="$(fake_calls herdr-app)"
    [[ "$calls" == *"do space.select --id sp1"* ]]
    [[ "$calls" == *"do agent.focus --terminal t7"* ]]
    [[ "$calls" != *space.new* && "$calls" != *tab.new* ]]
}

@test "--window starts the agent again in the space when Claude Code ended" {
    fake_herdr "$SPACE_JSON" '{"terminals":[{"address":"t7","agent":"bash"}]}'
    run auspex agent --window --cwd "$W"
    [ "$status" -eq 0 ]
    calls="$(fake_calls herdr-app)"
    [[ "$calls" == *"do tab.new --space sp1 --name agent --folder $W --argv"* ]]
    [[ "$calls" != *agent.focus* ]]
}

@test "--window with a prompt opens a new tab even when the agent runs" {
    fake_herdr "$SPACE_JSON" '{"terminals":[{"address":"t7","agent":"claude-code"}]}'
    run auspex agent --window --cwd "$W" --prompt hi
    [ "$status" -eq 0 ]
    [[ "$(fake_calls herdr-app)" == *"do tab.new --space sp1"*'"--prompt","hi"]'* ]]
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
    grep -v 'auspex-agent.desktop' "$AUSPEX_REPO/manifest/user.tsv" >"$AUSPEX/manifest/user.tsv"
    run auspex check kde-untouched
    [ "$status" -ne 0 ]
}
