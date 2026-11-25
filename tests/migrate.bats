#!/usr/bin/env bats
# auspex migrate and the migration runner in a temp HOME and a temp AUSPEX_STATE.

load test_helper
load fixtures/apply/helper

setup() {
    apply_test_setup
}

teardown() {
    auspex_test_teardown
}

add_migration() {
    printf '%s\n' "$2" >"$AUSPEX/migrations/$1"
}

@test "migrate --pending lists the migrations that have no marker, in name order" {
    add_migration 1700000002-b.sh 'true'
    add_migration 1700000001-a.sh 'true'
    run auspex migrate --pending
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = 1700000001-a.sh ]
    [ "${lines[1]}" = 1700000002-b.sh ]
}

@test "a migration runs once and writes a marker" {
    add_migration 1700000001-a.sh 'echo run >>"$HOME/runs"'
    run auspex migrate
    [ "$status" -eq 0 ]
    [ -f "$AUSPEX_STATE/migrations/1700000001-a.sh" ]
    run auspex migrate
    [ "$status" -eq 0 ]
    [ "$(wc -l <"$HOME/runs")" -eq 1 ]
    run auspex migrate --pending
    [ -z "$output" ]
}

@test "migrations run in name order" {
    add_migration 1700000002-b.sh 'echo b >>"$HOME/runs"'
    add_migration 1700000001-a.sh 'echo a >>"$HOME/runs"'
    auspex migrate
    [ "$(tr '\n' ' ' <"$HOME/runs")" = "a b " ]
}

@test "a failed migration writes no marker and stops the later migrations" {
    add_migration 1700000001-a.sh 'exit 3'
    add_migration 1700000002-b.sh 'echo b >>"$HOME/runs"'
    run auspex migrate
    [ "$status" -ne 0 ]
    [[ "$output" == *"1700000001-a.sh"* ]]
    [ ! -e "$AUSPEX_STATE/migrations/1700000001-a.sh" ]
    [ ! -e "$HOME/runs" ]
}

@test "apply runs pending migrations after it writes the targets" {
    add_migration 1700000001-a.sh 'cat "$HOME/.config/app/app.conf" >"$HOME/seen"'
    repo_commit "migration"
    run auspex apply
    [ "$status" -eq 0 ]
    [ "$(cat "$HOME/seen")" = "a=1" ]
    [ -f "$AUSPEX_STATE/migrations/1700000001-a.sh" ]
}

@test "a failed migration stops apply, marks the generation and skips the hooks" {
    add_migration 1700000001-a.sh 'exit 1'
    printf '#!/bin/sh\necho hook >>"$HOME/hooks"\n' >"$AUSPEX/hooks/post-apply.d/10-x"
    chmod +x "$AUSPEX/hooks/post-apply.d/10-x"
    repo_commit "failing migration"
    run auspex apply
    [ "$status" -ne 0 ]
    [[ "$output" == *"1700000001-a.sh"* ]]
    [ "$(meta 1 .status)" = migration-failed ]
    [ "$(cat "$HOME/.config/app/app.conf")" = "a=1" ]
    [ ! -e "$HOME/hooks" ]
}

@test "apply with no target change still runs a pending migration" {
    auspex apply
    add_migration 1700000001-a.sh 'echo run >>"$HOME/runs"'
    repo_commit "migration"
    run auspex apply
    [ "$status" -eq 0 ]
    [ "$(wc -l <"$HOME/runs")" -eq 1 ]
}

@test "the repo migrations pass and write their markers" {
    cp "$AUSPEX_REPO"/migrations/*.sh "$AUSPEX/migrations/"
    run auspex migrate
    [ "$status" -eq 0 ]
    run auspex migrate --pending
    [ -z "$output" ]
    [ -n "$(ls "$AUSPEX_STATE/migrations")" ]
}
