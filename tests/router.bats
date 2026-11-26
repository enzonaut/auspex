#!/usr/bin/env bats

load test_helper

setup() {
    auspex_test_setup
    make_repo_copy
}

teardown() {
    auspex_test_teardown
}

@test "routes to the longest matching command and passes the rest" {
    add_command auspex-zz
    add_command auspex-zz-yy
    run auspex zz yy 010 --flag
    [ "$status" -eq 0 ]
    [ "$output" = "auspex-zz-yy 010 --flag" ]
}

@test "falls back to a shorter match when the longer one does not exist" {
    add_command auspex-zz
    run auspex zz yy 010
    [ "$status" -eq 0 ]
    [ "$output" = "auspex-zz yy 010" ]
}

@test "no words prints the command list" {
    add_command auspex-zz
    run auspex
    [ "$status" -eq 0 ]
    [[ "$output" == *"auspex zz"* ]]
    [[ "$output" == *"Test command auspex-zz"* ]]
}

@test "help prints the command list" {
    add_command auspex-zz
    run auspex help
    [ "$status" -eq 0 ]
    [[ "$output" == *"auspex zz"* ]]
}

@test "an unknown command exits 2 with a message" {
    run auspex nosuchcommand
    [ "$status" -eq 2 ]
    [[ "$output" == *"unknown command"* ]]
}

@test "a word with a path character does not route" {
    add_command auspex-zz
    run auspex ../bin/auspex-zz
    [ "$status" -eq 2 ]
}

@test "a command word with a hyphen routes: auspex check system-steps" {
    add_command auspex-check-system-steps
    run auspex check system-steps --static
    [ "$status" -eq 0 ]
    [ "$output" = "auspex-check-system-steps --static" ]
}

@test "words with '.', '/' or a leading '-' are not command words" {
    add_command auspex-zz
    add_command auspex-zz-yy
    for word in yy.x yy/x -yy ../yy; do
        run auspex zz "$word"
        [ "$status" -eq 0 ]
        [ "$output" = "auspex-zz $word" ]
    done
    run auspex -zz
    [ "$status" -eq 2 ]
    run auspex .zz
    [ "$status" -eq 2 ]
}

@test "AUSPEX defaults to the repo of the router, through a symlink" {
    add_command auspex-zz '1' 'echo "$AUSPEX"'
    mkdir -p "$HOME/.local/bin"
    ln -s "$AUSPEX/bin/auspex" "$HOME/.local/bin/auspex"
    run env -u AUSPEX "$HOME/.local/bin/auspex" zz
    [ "$status" -eq 0 ]
    [ "$output" = "$(cd "$AUSPEX" && pwd -P)" ]
}

@test "the AUSPEX variable overrides the default" {
    mkdir -p "$TEST_TMP/other/bin"
    cp -a "$AUSPEX/lib" "$TEST_TMP/other/"
    cat >"$TEST_TMP/other/bin/auspex-zz" <<'EOF'
#!/usr/bin/env bash
echo "other $AUSPEX"
EOF
    chmod +x "$TEST_TMP/other/bin/auspex-zz"
    AUSPEX="$TEST_TMP/other" run "$AUSPEX/bin/auspex" zz
    [ "$status" -eq 0 ]
    [ "$output" = "other $TEST_TMP/other" ]
}
