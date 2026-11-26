#!/usr/bin/env bats

load test_helper

setup() {
    auspex_test_setup
    make_repo_copy
}

teardown() {
    auspex_test_teardown
}

@test "--check passes on the repo commands" {
    AUSPEX="$AUSPEX_REPO" run "$AUSPEX_REPO/bin/auspex" commands --check
    [ "$status" -eq 0 ]
}

@test "--check fails on a command that is not executable" {
    add_command auspex-zz
    chmod -x "$AUSPEX/bin/auspex-zz"
    run auspex commands --check
    [ "$status" -eq 1 ]
    [[ "$output" == *"auspex-zz"*"not executable"* ]]
}

@test "--check fails on each missing header" {
    local key
    for key in summary args level requires-sudo; do
        add_command auspex-zz
        sed -i "/^# auspex:$key=/d" "$AUSPEX/bin/auspex-zz"
        run auspex commands --check
        [ "$status" -eq 1 ]
        [[ "$output" == *"auspex-zz"*"auspex:$key"* ]]
    done
}

@test "--check fails on a bad level or sudo value" {
    add_command auspex-zz 4
    run auspex commands --check
    [ "$status" -eq 1 ]
    [[ "$output" == *"auspex:level"* ]]

    add_command auspex-zz 1
    sed -i 's/^# auspex:requires-sudo=false/# auspex:requires-sudo=maybe/' "$AUSPEX/bin/auspex-zz"
    run auspex commands --check
    [ "$status" -eq 1 ]
    [[ "$output" == *"auspex:requires-sudo"* ]]
}

@test "--check fails when 2 commands route to the same words" {
    add_command auspex-zz-yy
    add_command auspex-zz_yy
    run auspex commands --check
    [ "$status" -eq 1 ]
    [[ "$output" == *"collision"* ]]
}

@test "--check fails on a command that the router cannot reach" {
    add_command auspex-help
    run auspex commands --check
    [ "$status" -eq 1 ]
    [[ "$output" == *"auspex-help"* ]]
}

@test "--markdown lists every command in a table" {
    add_command auspex-zz-yy 2
    run auspex commands --markdown
    [ "$status" -eq 0 ]
    [[ "${lines[0]}" == "| Command | Args | Level | Sudo | Summary |" ]]
    [[ "$output" == *'| `auspex zz yy` | `[<x>]` | 2 | false | Test command auspex-zz-yy |'* ]]
    local f n
    for f in "$AUSPEX"/bin/auspex-*; do
        n="${f##*/auspex-}"
        [[ "$output" == *"\`auspex ${n//-/ }\`"* ]]
    done
}

@test "--markdown escapes a pipe in the args" {
    add_command auspex-zz
    sed -i 's/^# auspex:args=.*/# auspex:args=[--a | --b]/' "$AUSPEX/bin/auspex-zz"
    run auspex commands --markdown
    [[ "$output" == *'`[--a \| --b]`'* ]]
}

@test "an unknown option exits 2" {
    run auspex commands --nope
    [ "$status" -eq 2 ]
}
