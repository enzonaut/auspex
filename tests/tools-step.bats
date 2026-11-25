#!/usr/bin/env bats

load test_helper

STEP="$AUSPEX_REPO/system/steps/030-auspex-tools.sh"

setup() {
    auspex_test_setup
    export AUSPEX_SYSTEM_STATE="$TEST_TMP/system-state"
    export INSTALLED="$TEST_TMP/installed"
    printf '%s\n' jq >"$INSTALLED"
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

@test "a direct run finds the list from its own folder" {
    printf '%s\n' bats shellcheck jq pacman-contrib >"$INSTALLED"
    run bash "$STEP" check
    [ "$status" -eq 0 ]
}

@test "the header declares the list in auspex:reads" {
    grep -qx '# auspex:reads=packages/auspex-tools.list' "$STEP"
}

@test "apply reads the list from AUSPEX_READS_DIR when it is set" {
    export AUSPEX_READS_DIR="$TEST_TMP/reads"
    mkdir -p "$AUSPEX_READS_DIR/packages"
    printf 'approved\n' >"$AUSPEX_READS_DIR/packages/auspex-tools.list"
    run_step apply
    [ "$status" -eq 0 ]
    [ "$(grep -- '^-S' "$CALLS/pacman")" = "-S --needed --noconfirm approved" ]
}

@test "the step uses AUSPEX_REPO and AUSPEX_STEP_DIR when they are set" {
    export AUSPEX_REPO="$TEST_TMP/repo2" AUSPEX_STEP_DIR="$TEST_TMP/repo2/system/steps"
    mkdir -p "$AUSPEX_REPO/packages"
    printf 'other\n' >"$AUSPEX_REPO/packages/auspex-tools.list"
    run_step apply
    [ "$status" -eq 0 ]
    [ "$(grep -- '^-S' "$CALLS/pacman")" = "-S --needed --noconfirm other" ]
}
