# Shared bats setup. Load it with: load test_helper
#
# auspex_test_setup gives each test:
#   TEST_TMP        a private temp folder
#   HOME            $TEST_TMP/home, so every target moves into the temp folder
#   AUSPEX_STATE    $TEST_TMP/state
#   AUSPEX          the repo under test
#   FAKES           $TEST_TMP/fakes, first on PATH
#   CALLS           $TEST_TMP/calls, where each fake logs its arguments

AUSPEX_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

auspex_test_setup() {
    TEST_TMP="$(mktemp -d "${BATS_TMPDIR:-/tmp}/auspex-test.XXXXXX")"
    export TEST_TMP
    export HOME="$TEST_TMP/home"
    export AUSPEX_STATE="$TEST_TMP/state"
    export AUSPEX="${AUSPEX_UNDER_TEST:-$AUSPEX_REPO}"
    export FAKES="$TEST_TMP/fakes"
    export CALLS="$TEST_TMP/calls"
    mkdir -p "$HOME" "$AUSPEX_STATE" "$FAKES" "$CALLS"
    export PATH="$FAKES:$AUSPEX/bin:$PATH"
    unset AUSPEX_ACTOR
    guard_herdr
}

auspex_test_teardown() {
    if [[ -n "${TEST_TMP:-}" && -d "$TEST_TMP" ]]; then
        rm -rf "$TEST_TMP"
    fi
}

# make_fake <name> [<bash body>]
# Puts an executable <name> in $FAKES. Each call appends its arguments,
# 1 line per call, to $CALLS/<name>, then runs <body> with "$@" set.
make_fake() {
    local name="$1" body="${2:-exit 0}"
    cat >"$FAKES/$name" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$CALLS/$name"
$body
EOF
    chmod +x "$FAKES/$name"
}

# guard_herdr: no test starts the real herdr app. These fakes stand in for
# herdr-app (down), hc and setsid until a test replaces them with fake_herdr.
guard_herdr() {
    make_fake herdr-app 'exit 1'
    make_fake hc 'exit 1'
    make_fake setsid 'exit 0'
}

# fake_herdr <ls json> <hc ls json>: a herdr app that is up, with these spaces.
fake_herdr() {
    printf '%s' "$1" >"$TEST_TMP/ls.json"
    printf '%s' "$2" >"$TEST_TMP/hc.json"
    make_fake herdr-app 'case "${1:-}" in
    status) echo "{}" ;;
    ls) cat "$TEST_TMP/ls.json" ;;
    do) echo "{}" ;;
esac'
    make_fake hc 'cat "$TEST_TMP/hc.json"'
    make_fake setsid '"$@"'
}

# fake_calls <name>: print the logged calls of a fake, or nothing.
fake_calls() {
    cat "$CALLS/$1" 2>/dev/null || true
}

# make_repo_copy: copy the repo under test to $TEST_TMP/repo and point
# AUSPEX at it, so a test can add or break commands.
make_repo_copy() {
    mkdir -p "$TEST_TMP/repo"
    cp -a "$AUSPEX_REPO/bin" "$AUSPEX_REPO/lib" "$TEST_TMP/repo/"
    export AUSPEX="$TEST_TMP/repo"
    export PATH="$FAKES:$AUSPEX/bin:$PATH"
}

# add_command <name> [<level>] [<body>]: add bin/<name> with all 4 headers.
add_command() {
    local name="$1" level="${2:-1}" body="${3:-echo \"$1 \$*\"}"
    cat >"$AUSPEX/bin/$name" <<EOF
#!/usr/bin/env bash
# auspex:summary=Test command $name
# auspex:args=[<x>]
# auspex:level=$level
# auspex:requires-sudo=false
$body
EOF
    chmod +x "$AUSPEX/bin/$name"
}
