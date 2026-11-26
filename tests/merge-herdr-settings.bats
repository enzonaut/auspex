#!/usr/bin/env bats

load test_helper

setup() {
    auspex_test_setup
    M="$AUSPEX_REPO/lib/merge/herdr-settings"
    SRC="$AUSPEX_REPO/config/herdr-app/settings.json"
    FIX="$AUSPEX_REPO/tests/fixtures/herdr/settings.json"
    W="$TEST_TMP/work"
    mkdir -p "$W"
}

teardown() {
    auspex_test_teardown
}

merge_fix() {
    "$M" merge "$SRC" "$FIX" "$W/none" "$W/out" "$W/owned"
}

@test "merge sets the owned keys and keeps every other key" {
    merge_fix
    [ "$(jq -r .theme "$W/out")" = avgvr ]
    [ "$(jq -r .font "$W/out")" = "JetBrains Mono" ]
    [ "$(jq -r .font_weight "$W/out")" = 400 ]
    [ "$(jq -r .font_weight_bold "$W/out")" = 700 ]
    [ "$(jq -r .ui_font "$W/out")" = Jost ]
    [ "$(jq -c 'del(.theme, .font, .font_weight, .font_weight_bold, .ui_font, .sounds.done)' "$W/out")" = \
        "$(jq -c 'del(.theme, .sounds.done)' "$FIX")" ]
    [ "$(jq -c .future_key "$W/out")" = '{"nested":[1,2]}' ]
}

@test "merge sets only sounds.done inside sounds" {
    merge_fix
    [ "$(jq -r .sounds.done "$W/out")" = sounds/silent.mp3 ]
    [ "$(jq -c '.sounds' "$W/out")" = '{"enabled":true,"blocked":"sounds/b.mp3","done":"sounds/silent.mp3"}' ]
    "$M" merge "$SRC" "$W/none" "$W/none" "$W/out2" "$W/owned2"
    [ "$(jq -c '.sounds | keys' "$W/out2")" = '["done"]' ]
}

@test "a second merge changes nothing" {
    merge_fix
    "$M" merge "$SRC" "$W/out" "$W/owned" "$W/out2" "$W/owned2"
    cmp "$W/out" "$W/out2"
    cmp "$W/owned" "$W/owned2"
}

@test "restore puts back old values and removes keys that were absent" {
    merge_fix
    "$M" restore "$FIX" "$W/out" "$W/owned" "$W/none" "$W/back"
    [ "$(jq -S -c . "$W/back")" = "$(jq -S -c . "$FIX")" ]
    [ "$(jq -r .theme "$W/back")" = gruvbox ]
    [ "$(jq -e 'has("font") or has("ui_font")' "$W/back" || true)" = false ]
    [ "$(jq -c .sounds "$W/back")" = '{"enabled":true,"blocked":"sounds/b.mp3"}' ]
}

@test "restore gives back the fixture byte for byte" {
    merge_fix
    "$M" restore "$FIX" "$W/out" "$W/owned" "$W/none" "$W/back"
    cmp "$FIX" "$W/back"
}

@test "restore keeps a key the operator added after the merge" {
    merge_fix
    jq '.zoom = 2 | .extra = true' "$W/out" >"$W/edited"
    "$M" restore "$FIX" "$W/edited" "$W/owned" "$W/none" "$W/back"
    [ "$(jq .zoom "$W/back")" = 2 ]
    [ "$(jq .extra "$W/back")" = true ]
    [ "$(jq -r .theme "$W/back")" = gruvbox ]
}

@test "restore with no earlier file removes the keys and the empty sounds object" {
    "$M" merge "$SRC" "$W/none" "$W/none" "$W/out" "$W/owned"
    "$M" restore "$W/none" "$W/out" "$W/owned" "$W/none" "$W/back"
    [ -f "$W/back" ]
    [ ! -s "$W/back" ]
}

@test "restore with no earlier file keeps an operator key" {
    "$M" merge "$SRC" "$W/none" "$W/none" "$W/out" "$W/owned"
    jq '.zoom = 2' "$W/out" >"$W/edited"
    "$M" restore "$W/none" "$W/edited" "$W/owned" "$W/none" "$W/back"
    [ "$(jq -c . "$W/back")" = '{"zoom":2}' ]
}

@test "digest lists the owned keys only" {
    merge_fix
    d="$("$M" digest "$W/out" "$W/owned")"
    [ "$(printf '%s\n' "$d" | wc -l)" -eq 6 ]
    printf '%s\n' "$d" | grep -qFx 'theme = "avgvr"'
    printf '%s\n' "$d" | grep -qFx 'sounds.done = "sounds/silent.mp3"'
    ! printf '%s\n' "$d" | grep -q 'zoom\|future_key\|blocked'
    jq '.zoom = 9 | .sounds.blocked = "x" | .future_key = 1' "$W/out" >"$W/edited"
    [ "$("$M" digest "$W/edited" "$W/owned")" = "$d" ]
    jq '.theme = "other"' "$W/out" >"$W/edited"
    [ "$("$M" digest "$W/edited" "$W/owned")" != "$d" ]
    [ -z "$("$M" digest "$W/out" "$W/none")" ]
}

@test "bad JSON writes nothing" {
    printf '{not json\n' >"$W/target"
    run "$M" merge "$SRC" "$W/target" "$W/none" "$W/out" "$W/owned"
    [ "$status" -eq 1 ]
    [ ! -e "$W/out" ]
    [ ! -e "$W/owned" ]
    printf '[1]\n' >"$W/target"
    run "$M" merge "$SRC" "$W/target" "$W/none" "$W/out" "$W/owned"
    [ "$status" -eq 1 ]
    [ ! -e "$W/out" ]
    printf '{"sounds":"loud"}\n' >"$W/target"
    run "$M" merge "$SRC" "$W/target" "$W/none" "$W/out" "$W/owned"
    [ "$status" -eq 1 ]
    [ ! -e "$W/out" ]
    printf '{not json\n' >"$W/src.json"
    run "$M" merge "$W/src.json" "$FIX" "$W/none" "$W/out" "$W/owned"
    [ "$status" -eq 1 ]
    [ ! -e "$W/out" ]
    run "$M" restore "$FIX" "$W/target" "$W/none" "$W/none" "$W/back"
    [ "$status" -eq 1 ]
    [ ! -e "$W/back" ]
    run "$M" merge "$SRC" "$FIX"
    [ "$status" -eq 1 ]
    run "$M" frob
    [ "$status" -eq 2 ]
}
