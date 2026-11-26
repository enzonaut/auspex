#!/usr/bin/env bats

load test_helper

REAL_HOME="$HOME"

setup() {
    auspex_test_setup
    REAL_KW="$(PATH="${PATH#"$FAKES:"}" command -v kwriteconfig6 || true)"
    [ -n "$REAL_KW" ] && command -v kreadconfig6 >/dev/null || skip "kwriteconfig6 or kreadconfig6 is missing"
    make_fake kwriteconfig6 "prev=''
for a in \"\$@\"; do
    if [[ \"\$prev\" == --file && \"\$a\" != \"\$TEST_TMP\"/* ]]; then
        printf 'guard: refused %s\n' \"\$a\" >&2
        exit 9
    fi
    prev=\"\$a\"
done
exec '$REAL_KW' \"\$@\""
    M="$AUSPEX_REPO/lib/merge/kglobalshortcuts"
    SRC="$AUSPEX_REPO/config/kde/agent-shortcuts.ini"
    FIX="$AUSPEX_REPO/tests/fixtures/kde/kglobalshortcutsrc"
    W="$TEST_TMP/work"
    mkdir -p "$W"
    cp -- "$FIX" "$W/target"
}

teardown() {
    auspex_test_teardown
}

fake_gdbus() {
    make_fake gdbus "if [[ \"\$*\" == *NameHasOwner* ]]; then echo '($1,)'; fi"
}

@test "merge adds only the agent group and keeps the fixture lines" {
    run "$M" merge "$SRC" "$W/target" "$W/none.json" "$W/out" "$W/owned.json"
    [ "$status" -eq 0 ]
    [ "$(diff "$FIX" "$W/out" | grep -c '^<')" -eq 0 ]
    [ "$(diff "$FIX" "$W/out" | grep -c '^>')" -eq 3 ]
    [ "$(diff "$FIX" "$W/out" | grep -c '^> \[services\]\[auspex-agent')" -eq 1 ]
    grep -qxF '_launch=Meta+Alt+A' "$W/out"
    [ "$(jq -c . "$W/owned.json")" = '{"auspex-agent.desktop":{"earlier":null}}' ]
    cmp "$FIX" "$W/target"
    [ -z "$(fake_calls kwriteconfig6 | grep -v -- "--file $TEST_TMP/")" ]
}

@test "a 2nd merge changes nothing and writes nothing" {
    "$M" merge "$SRC" "$W/target" "$W/none.json" "$W/out1" "$W/own1.json"
    : >"$CALLS/kwriteconfig6"
    "$M" merge "$SRC" "$W/out1" "$W/own1.json" "$W/out2" "$W/own2.json"
    cmp "$W/out1" "$W/out2"
    cmp "$W/own1.json" "$W/own2.json"
    [ -z "$(fake_calls kwriteconfig6)" ]
}

@test "restore gives back the fixture byte for byte" {
    "$M" merge "$SRC" "$W/target" "$W/none.json" "$W/out" "$W/owned.json"
    "$M" restore "$W/target" "$W/out" "$W/owned.json" "$W/none.json" "$W/back"
    cmp "$FIX" "$W/back"
}

@test "an earlier key value is kept in the owned file and comes back" {
    kwriteconfig6 --file "$W/target" --group services --group auspex-agent.desktop --key _launch Meta+X
    cp -- "$W/target" "$W/before"
    "$M" merge "$SRC" "$W/target" "$W/none.json" "$W/out" "$W/owned.json"
    [ "$(jq -r '."auspex-agent.desktop".earlier' "$W/owned.json")" = Meta+X ]
    grep -qxF '_launch=Meta+Alt+A' "$W/out"
    printf '[services][auspex-agent-dropdown.desktop]\n_launch=Meta+Alt+`\n' >"$W/src2.ini"
    "$M" merge "$W/src2.ini" "$W/out" "$W/owned.json" "$W/out2" "$W/own2.json"
    [ "$(kreadconfig6 --file "$W/out2" --group services --group auspex-agent.desktop --key _launch)" = Meta+X ]
    [ "$(jq -r 'keys[]' "$W/own2.json")" = auspex-agent-dropdown.desktop ]
    "$M" restore "$W/before" "$W/out" "$W/owned.json" "$W/none.json" "$W/back"
    cmp "$W/before" "$W/back"
}

@test "merge with no target writes only the agent group and restore empties it" {
    "$M" merge "$SRC" "$W/absent" "$W/none.json" "$W/out" "$W/owned.json"
    [ "$(grep -c '^\[services\]' "$W/out")" -eq 1 ]
    [ "$(grep -c '^\[' "$W/out")" -eq 1 ]
    "$M" restore "$W/absent" "$W/out" "$W/owned.json" "$W/none.json" "$W/back"
    [ -e "$W/back" ] && [ ! -s "$W/back" ]
}

@test "digest lists each owned group with its value" {
    "$M" merge "$SRC" "$W/target" "$W/none.json" "$W/out" "$W/owned.json"
    run "$M" digest "$W/out" "$W/owned.json"
    [ "$output" = auspex-agent.desktop=Meta+Alt+A ]
    run "$M" digest "$W/target" "$W/owned.json"
    [ "$output" = 'auspex-agent.desktop=<absent>' ]
}

@test "merge refuses a bad source or owned file and writes nothing" {
    printf '[kwin]\nfoo=Meta+A\n' >"$W/bad.ini"
    run "$M" merge "$W/bad.ini" "$W/target" "$W/none.json" "$W/out" "$W/owned.json"
    [ "$status" -ne 0 ]
    [ ! -e "$W/out" ]
    printf '{"../x":{"earlier":null}}' >"$W/bad.json"
    run "$M" merge "$SRC" "$W/target" "$W/bad.json" "$W/out" "$W/owned.json"
    [ "$status" -ne 0 ]
    [ ! -e "$W/out" ]
    [ -z "$(fake_calls kwriteconfig6)" ]
}

@test "the guard refuses a write outside the temp folder" {
    run kwriteconfig6 --file "$REAL_HOME/.config/kglobalshortcutsrc" --group x --key y z
    [ "$status" -eq 9 ]
}

@test "reload loads the keys into kglobalaccel with the Qt key codes" {
    fake_gdbus true
    "$M" merge "$SRC" "$W/target" "$W/none.json" "$W/out" "$W/owned.json"
    run "$M" reload "$SRC" "$W/out" "$W/owned.json"
    [ "$status" -eq 0 ]
    calls="$(fake_calls gdbus)"
    [[ "$calls" == *"doRegister ['auspex-agent.desktop','_launch','auspex agent','Launch auspex agent']"* ]]
    [[ "$calls" == *"setForeignShortcutKeys ['auspex-agent.desktop','_launch','auspex agent','Launch auspex agent'] [([402653249],)]"* ]]
}

@test "reload after a restore clears the keys and unregisters" {
    fake_gdbus true
    "$M" merge "$SRC" "$W/target" "$W/none.json" "$W/out" "$W/owned.json"
    "$M" restore "$W/target" "$W/out" "$W/owned.json" "$W/none.json" "$W/back"
    run "$M" reload "$SRC" "$W/back" "$W/owned.json"
    [ "$status" -eq 0 ]
    calls="$(fake_calls gdbus)"
    [[ "$calls" == *"setForeignShortcutKeys ['auspex-agent.desktop','_launch','auspex agent','Launch auspex agent'] @a(ai) []"* ]]
    [[ "$calls" == *"unregister auspex-agent.desktop _launch"* ]]
    [[ "$calls" != *doRegister* ]]
}

@test "reload exits 0 with a note when kglobalaccel is not on the bus" {
    fake_gdbus false
    run "$M" reload "$SRC" "$W/target" "$W/none.json"
    [ "$status" -eq 0 ]
    [[ "$output" == *"not on the session bus"* ]]
    [ "$(fake_calls gdbus | grep -vc NameHasOwner)" -eq 0 ]
}

hook_meta() {
    export AUSPEX_GEN_DIR="$TEST_TMP/gen"
    mkdir -p "$AUSPEX_GEN_DIR"
    jq -n --arg p "$1" '{targets: [{path: $p}]}' >"$AUSPEX_GEN_DIR/meta.json"
}

@test "the 40-kglobalaccel hooks reload only when a shortcut target changed" {
    fake_gdbus true
    for h in post-apply.d post-undo.d; do
        : >"$CALLS/gdbus"
        hook_meta .config/mako/config
        run "$AUSPEX_REPO/hooks/$h/40-kglobalaccel" 1
        [ "$status" -eq 0 ]
        [ -z "$(fake_calls gdbus)" ]
        hook_meta .config/kglobalshortcutsrc
        run "$AUSPEX_REPO/hooks/$h/40-kglobalaccel" 1
        [ "$status" -eq 0 ]
        [[ "$(fake_calls gdbus)" == *NameHasOwner* ]]
    done
}

@test "the 40-kglobalaccel hooks exit 0 with no kglobalaccel on the bus" {
    fake_gdbus false
    hook_meta .config/kglobalshortcutsrc
    for h in post-apply.d post-undo.d; do
        run "$AUSPEX_REPO/hooks/$h/40-kglobalaccel" 1
        [ "$status" -eq 0 ]
        [[ "$output" == *"not on the session bus"* ]]
    done
}

@test "the agent keys are not bound to another action in the live file" {
    live="$REAL_HOME/.config/kglobalshortcutsrc"
    [ -f "$live" ] || skip "no live $live"
    mapfile -t ours < <(sed -n 's/^_launch=//p' "$SRC")
    conflicts="$(awk -v keys="$(printf '%s\n' "${ours[@]}")" '
        BEGIN { n = split(keys, k, "\n"); for (i = 1; i <= n; i++) want[k[i]] = 1 }
        /^\[/ { group = $0; skip = (group ~ /^\[services\]\[auspex-agent\.desktop\]$/ || group ~ /\$InverseAction/); next }
        skip || !/=/ { next }
        {
            name = substr($0, 1, index($0, "=") - 1)
            active = substr($0, index($0, "=") + 1)
            sub(/,.*/, "", active)
            m = split(active, a, /\\t/)
            for (i = 1; i <= m; i++) if (a[i] in want) print group " " name "=" a[i]
        }' "$live")"
    if [ -n "$conflicts" ]; then
        printf 'key already bound: %s\n' "$conflicts"
        false
    fi
}
