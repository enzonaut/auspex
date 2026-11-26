#!/usr/bin/env bats

load test_helper

setup() {
    auspex_test_setup
    unset HYPRLAND_INSTANCE_SIGNATURE
    make_fake checkupdates 'printf "a 1 -> 2\nb 1 -> 2\n"'
    make_fake yay 'printf "c 1 -> 2\n"'
    make_fake claude 'printf "report body\nSUMMARY: 3 updates, no news\n"'
    make_fake notify-send 'echo ""'
    fake_herdr '{"spaces":[]}' '{"terminals":[]}'
    mkdir -p "$HOME/repos/auspex"
}

teardown() {
    auspex_test_teardown
}

@test "--dry-run prints 4 steps and runs nothing" {
    run auspex update check --dry-run
    [ "$status" -eq 0 ]
    for n in 1 2 3 4; do [[ "$output" == *"step $n:"* ]]; done
    [[ "$output" == *"--headless"* ]]
    [ -z "$(fake_calls claude)" ]
    [ -z "$(fake_calls notify-send)" ]
    [ -z "$(fake_calls yay)" ]
}

@test "a run writes the report and notifies with the SUMMARY line" {
    run auspex update check
    [ "$status" -eq 0 ]
    f="$(ls "$AUSPEX_STATE"/reports/arch-update/*.md)"
    grep -q 'SUMMARY: 3 updates' "$f"
    run fake_calls notify-send
    [[ "$output" == *"--app-name=auspex --action=open=Open --wait Arch update check 3 updates, no news"* ]]
}

@test "the headless run uses the read-only settings" {
    run auspex update check
    [ "$status" -eq 0 ]
    run fake_calls claude
    [[ "$output" == *"-p --settings $HOME/.config/auspex/claude/headless-settings.json --disallowedTools Edit,Write,NotebookEdit"* ]]
    [[ "$output" == *"arch-update skill"* ]]
}

@test "when claude fails the notification shows the counts" {
    make_fake claude 'exit 1'
    run auspex update check
    [ "$status" -eq 0 ]
    run fake_calls notify-send
    [[ "$output" == *"2 repo and 1 AUR updates"* ]]
}

@test "no update in checkupdates (exit 2) counts as 0" {
    make_fake checkupdates 'exit 2'
    make_fake yay 'exit 0'
    make_fake claude 'exit 1'
    run auspex update check
    [ "$status" -eq 0 ]
    run fake_calls notify-send
    [[ "$output" == *"0 repo and 0 AUR updates"* ]]
}

@test "clicking Open starts the agent in the herdr app with the report" {
    make_fake notify-send 'echo open'
    run auspex update check
    [ "$status" -eq 0 ]
    run fake_calls herdr-app
    [[ "$output" == *"do space.new --name auspex agent "*"--prompt"*"/arch-update Read $AUSPEX_STATE/reports/arch-update/"* ]]
}

@test "dismissing the notification starts no window" {
    run auspex update check
    [ "$status" -eq 0 ]
    [ -z "$(fake_calls herdr-app)" ]
    [ -z "$(fake_calls setsid)" ]
}

@test "no step runs a system update or sudo" {
    run auspex update check
    [ "$status" -eq 0 ]
    [ -z "$(fake_calls sudo)" ]
    run bash -c "grep -v '^# auspex:' '$AUSPEX/bin/auspex-update-check' | grep -E 'pacman -Syu|yay -Syu|sudo'"
    [ "$status" -eq 1 ]
}
