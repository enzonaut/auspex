#!/usr/bin/env bats

load test_helper

STEP="$AUSPEX_REPO/system/steps/030-auspex-tools.sh"

setup() {
    auspex_test_setup
    export AUSPEX_SYSTEM_STATE="$TEST_TMP/system-state"
    export INSTALLED="$TEST_TMP/installed"
    printf '%s\n' jq >"$INSTALLED"
    # A fake pacman that keeps the installed set in $INSTALLED.
    make_fake pacman '
case "$1" in
  -Qq) shift; rc=0; for p in "$@"; do grep -qx "$p" "$INSTALLED" || rc=1; done; exit $rc ;;
  -S) shift; for p in "$@"; do [[ $p == -* ]] || grep -qx "$p" "$INSTALLED" || echo "$p" >>"$INSTALLED"; done ;;
  -Rns) shift; for p in "$@"; do [[ $p == -* ]] || sed -i "/^$p\$/d" "$INSTALLED"; done ;;
  *) exit 2 ;;
esac'
}

teardown() {
    auspex_test_teardown
}

run_step() {
    run bash -c 'source "$1"; "$2"' _ "$STEP" "$1"
}

@test "headers say level 3 and requires sudo" {
    grep -qx '# auspex:level=3' "$STEP"
    grep -qx '# auspex:requires-sudo=true' "$STEP"
}

@test "check fails while a package is missing" {
    run_step check
    [ "$status" -ne 0 ]
}

@test "apply installs the list with --needed and records only new packages" {
    run_step apply
    [ "$status" -eq 0 ]
    [[ "$(fake_calls pacman)" == *"-S --needed --noconfirm bats shellcheck jq pacman-contrib"* ]]
    run cat "$AUSPEX_SYSTEM_STATE/030-auspex-tools.installed"
    [ "$output" = "$(printf '%s\n' bats shellcheck pacman-contrib)" ]
    run_step check
    [ "$status" -eq 0 ]
}

@test "undo removes only the packages that apply installed" {
    run_step apply
    run_step undo
    [ "$status" -eq 0 ]
    [[ "$(fake_calls pacman)" == *"-Rns --noconfirm bats shellcheck pacman-contrib"* ]]
    run cat "$INSTALLED"
    [ "$output" = "jq" ]
    [ ! -e "$AUSPEX_SYSTEM_STATE/030-auspex-tools.installed" ]
}

@test "undo with no record changes nothing" {
    run_step undo
    [ "$status" -eq 0 ]
    [[ "$(fake_calls pacman)" != *"-Rns"* ]]
}

@test "a 2nd apply keeps the 1st record" {
    run_step apply
    run_step apply
    run cat "$AUSPEX_SYSTEM_STATE/030-auspex-tools.installed"
    [ "$output" = "$(printf '%s\n' bats shellcheck pacman-contrib)" ]
}

@test "apply records nothing when pacman fails" {
    make_fake pacman 'case "$1" in -Qq) exit 1 ;; *) exit 1 ;; esac'
    run_step apply
    [ "$status" -ne 0 ]
    [ ! -e "$AUSPEX_SYSTEM_STATE/030-auspex-tools.installed" ]
}
