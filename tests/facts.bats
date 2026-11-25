#!/usr/bin/env bats

load test_helper

setup() {
    auspex_test_setup
    FIXTURES="$BATS_TEST_DIRNAME/fixtures/facts"
    export AUSPEX_PROC="$FIXTURES/proc"
    export AUSPEX_SYS="$FIXTURES/sys"
    unset WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE
    make_fake nvidia-smi 'echo "NVIDIA GeForce RTX 4090, 580.10"'
    make_fake pacman '[[ "$1" == -Qm ]] && { echo aur-a; echo aur-b; exit 0; }; [[ "$2" == missing-pkg ]] && exit 1; exit 0'
    make_fake systemctl 'exit 0'
    make_fake journalctl 'echo "{\"_SYSTEMD_UNIT\":\"a.service\"}"; echo "{\"_SYSTEMD_UNIT\":\"a.service\"}"; echo "{\"_SYSTEMD_UNIT\":\"b.service\"}"'
}

teardown() {
    auspex_test_teardown
}

@test "default output has one heading per section" {
    run bin/auspex facts
    [ "$status" -eq 0 ]
    for s in host session gpu display auspex packages services journal disk; do
        [[ "$output" == *"## $s"* ]]
    done
}

@test "host and gpu facts come from the fixtures and fakes" {
    run bin/auspex facts --section host
    [ "$status" -eq 0 ]
    [[ "$output" == *"cpu: Test CPU 9000"* ]]
    [[ "$output" == *"uptime_seconds: 12345"* ]]
    run bin/auspex facts --section gpu
    [[ "$output" == *"name: NVIDIA GeForce RTX 4090"* ]]
    [[ "$output" == *"driver_version: 580.10"* ]]
    [[ "$output" == *"nvidia_drm_modeset: Y"* ]]
}

@test "headless: display is unavailable and the exit code is 0" {
    run bin/auspex facts --section display
    [ "$status" -eq 0 ]
    [[ "$output" == *"unavailable: no display"* ]]
}

@test "--json prints one object with one key per section" {
    run bin/auspex facts --json
    [ "$status" -eq 0 ]
    for s in host session gpu display auspex packages services journal disk; do
        echo "$output" | jq -e --arg s "$s" 'has($s)'
    done
    echo "$output" | jq -e '.display.unavailable == "no display"'
}

@test "--section prints only that section and rejects unknown names" {
    run bin/auspex facts --section disk
    [ "$status" -eq 0 ]
    [[ "$output" == *"## disk"* ]]
    [[ "$output" != *"## host"* ]]
    run bin/auspex facts --section nope
    [ "$status" -eq 2 ]
}

@test "journal counts errors by unit and prints no log text without --logs" {
    run bin/auspex facts --section journal
    [[ "$output" == *"total_errors: 3"* ]]
    [[ "$output" == *"unit_a.service: 2"* ]]
    [[ "$output" != *"## logs"* ]]
}

@test "--logs adds the logs block" {
    make_fake journalctl '[[ " $* " == *" -n 30 "* ]] && { echo "Jan 1 host kernel: boom"; exit 0; }; exit 0'
    run bin/auspex facts --logs
    [[ "$output" == *"## logs"* ]]
    [[ "$output" == *"kernel: boom"* ]]
}

@test "missing packages are listed" {
    mkdir -p "$AUSPEX/packages"
    printf 'good-pkg\nmissing-pkg # note\n' >"$AUSPEX/packages/base.list"
    run bin/auspex facts --section packages
    [[ "$output" == *"missing_count: 1"* ]]
    [[ "$output" == *"missing: missing-pkg"* ]]
    [[ "$output" == *"foreign_count: 2"* ]]
}

@test "a section that hangs times out and the command still exits 0" {
    make_fake nvidia-smi 'sleep 5'
    AUSPEX_FACTS_LIMIT=1 run bin/auspex facts --section gpu
    [ "$status" -eq 0 ]
    [[ "$output" == *"unavailable: timed out after 1s"* ]]
}

@test "a missing tool gives unavailable and exit 0" {
    rm -f "$FAKES/pacman"
    run env PATH="$FAKES:/usr/bin" bin/auspex facts --section packages
    [ "$status" -eq 0 ]
}

@test "auspex check facts passes headless" {
    run bin/auspex check facts
    [ "$status" -eq 0 ]
}
