#!/usr/bin/env bats

load test_helper

setup() {
    auspex_test_setup
    FIX="$AUSPEX_REPO/tests/fixtures/legio"
    REAL_JQ="$(command -v jq)"
    export REAL_JQ
    # The jq filter has many lines, so count calls in a file, not in $CALLS.
    make_fake jq 'echo x >>"$CALLS/jq.count"; exec "$REAL_JQ" "$@"'
}

teardown() {
    auspex_test_teardown
}

use_fixture() {
    make_fake hc "cat '$FIX/$1'"
}

@test "0 agents prints 0 working and 0 blocked with class idle" {
    use_fixture empty.json
    run auspex-legio
    [ "$status" -eq 0 ]
    [ "$output" = '{"text":"LEGIO [ 0 working · 0 blocked ]","class":"idle"}' ]
}

@test "working agents are counted and the class stays idle" {
    use_fixture working.json
    run auspex-legio
    [ "$status" -eq 0 ]
    [ "$output" = '{"text":"LEGIO [ 2 working · 0 blocked ]","class":"idle"}' ]
}

@test "1 blocked agent gives class blocked" {
    use_fixture blocked.json
    run auspex-legio
    [ "$status" -eq 0 ]
    [ "$output" = '{"text":"LEGIO [ 1 working · 1 blocked ]","class":"blocked"}' ]
}

@test "missing hc prints the fallback and exits 0" {
    rm -f "$FAKES/hc"
    PATH="$FAKES:$AUSPEX/bin:/usr/bin:/bin" run auspex-legio
    [ "$status" -eq 0 ]
    [ "$output" = '{"text": "LEGIO [ – · – ]", "class": "idle"}' ]
}

@test "hc exit 1 prints the fallback and exits 0" {
    make_fake hc 'exit 1'
    run auspex-legio
    [ "$status" -eq 0 ]
    [ "$output" = '{"text": "LEGIO [ – · – ]", "class": "idle"}' ]
}

@test "bad JSON prints the fallback and exits 0" {
    use_fixture bad.json
    run auspex-legio
    [ "$status" -eq 0 ]
    [ "$output" = '{"text": "LEGIO [ – · – ]", "class": "idle"}' ]
}

@test "JSON without terminals prints the fallback" {
    make_fake hc 'echo "{}"'
    run auspex-legio
    [ "$status" -eq 0 ]
    [ "$output" = '{"text": "LEGIO [ – · – ]", "class": "idle"}' ]
}

@test "1 run makes exactly 1 hc call and 1 jq call" {
    use_fixture blocked.json
    run auspex-legio
    [ "$status" -eq 0 ]
    [ "$(fake_calls hc | wc -l)" -eq 1 ]
    [ "$(wc -l <"$CALLS/jq.count")" -eq 1 ]
    [ "$(fake_calls hc)" = "ls --json" ]
}
