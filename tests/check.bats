#!/usr/bin/env bats

load test_helper

setup() {
    auspex_test_setup
    make_repo_copy
    unset DISPLAY WAYLAND_DISPLAY
    rm -f "$AUSPEX"/bin/auspex-check-*
}

teardown() {
    auspex_test_teardown
}

@test "runs each check and passes when all pass" {
    add_command auspex-check-aa 1 'echo ran-aa'
    add_command auspex-check-bb 1 'echo ran-bb'
    run auspex check
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok   aa"* ]]
    [[ "$output" == *"ok   bb"* ]]
}

@test "fails when 1 check fails and still runs the others" {
    add_command auspex-check-aa 1 'exit 1'
    add_command auspex-check-bb 1 'exit 0'
    run auspex check
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL aa"* ]]
    [[ "$output" == *"ok   bb"* ]]
}

@test "prints skip for a check that exits 77" {
    add_command auspex-check-aa 1 'echo "hyprland not installed"; exit 77'
    run auspex check
    [ "$status" -eq 0 ]
    [[ "$output" == *"skip aa: hyprland not installed"* ]]
}

@test "--no-display skips a display check" {
    add_command auspex-check-aa 1 'echo ran-aa'
    sed -i '2i # auspex:display=true' "$AUSPEX/bin/auspex-check-aa"
    export WAYLAND_DISPLAY=wayland-1
    run auspex check --no-display
    [ "$status" -eq 0 ]
    [[ "$output" == *"skip aa: needs a display"* ]]
    [[ "$output" != *"ran-aa"* ]]
}

@test "a display check is skipped when no display exists" {
    add_command auspex-check-aa 1 'exit 1'
    sed -i '2i # auspex:display=true' "$AUSPEX/bin/auspex-check-aa"
    run auspex check
    [ "$status" -eq 0 ]
    [[ "$output" == *"skip aa"* ]]
}

@test "runs the command header check first" {
    add_command auspex-zz
    chmod -x "$AUSPEX/bin/auspex-zz"
    run auspex check
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL commands"* ]]
}
