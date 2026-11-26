#!/usr/bin/env bats

load test_helper

FIX="$AUSPEX_REPO/tests/fixtures/render"

setup() {
    auspex_test_setup
    # shellcheck source=../lib/render.sh
    source "$AUSPEX_REPO/lib/render.sh"
    PAL="$FIX/palette.toml"
}

teardown() {
    auspex_test_teardown
}

tpl() {
    printf '%s' "$1" >"$TEST_TMP/t.tpl"
}

@test "render replaces keys and applies the filters bare, rgba:ff and dec" {
    auspex_render "$PAL" "$FIX/all.tpl" "$TEST_TMP/out/all"
    cmp "$TEST_TMP/out/all" "$FIX/all.expected"
}

@test "render gives the same bytes for the same input and reads no environment value" {
    auspex_render "$PAL" "$FIX/all.tpl" "$TEST_TMP/a"
    HOME=/elsewhere LANG=tr_TR.UTF-8 bronze=nope auspex_render "$PAL" "$FIX/all.tpl" "$TEST_TMP/b"
    cmp "$TEST_TMP/a" "$TEST_TMP/b"
}

@test "render keeps a missing final newline and empty lines" {
    tpl $'a\n\n{{ radius }}'
    auspex_render "$PAL" "$TEST_TMP/t.tpl" "$TEST_TMP/o"
    [ "$(od -An -c "$TEST_TMP/o" | tr -d ' \n')" = 'a\n\n0' ]
}

@test "render keeps the mode of the template" {
    tpl '#!/bin/sh'
    chmod 755 "$TEST_TMP/t.tpl"
    auspex_render "$PAL" "$TEST_TMP/t.tpl" "$TEST_TMP/o"
    [ -x "$TEST_TMP/o" ]
}

@test "render stops on an unknown key with the path and line number" {
    tpl $'ok\n{{ nope }}\n'
    run auspex_render "$PAL" "$TEST_TMP/t.tpl" "$TEST_TMP/o"
    [ "$status" -eq 1 ]
    [[ "$output" == *"$TEST_TMP/t.tpl:2: unknown key nope"* ]]
    [ ! -e "$TEST_TMP/o" ]
}

@test "render stops on an unknown filter" {
    tpl '{{ bronze | upper }}'
    run auspex_render "$PAL" "$TEST_TMP/t.tpl" "$TEST_TMP/o"
    [ "$status" -eq 1 ]
    [[ "$output" == *"t.tpl:1: unknown filter upper"* ]]
}

@test "render stops on a color filter on a text value" {
    tpl $'\n\n{{ font_body | dec }}'
    run auspex_render "$PAL" "$TEST_TMP/t.tpl" "$TEST_TMP/o"
    [ "$status" -eq 1 ]
    [[ "$output" == *"t.tpl:3: filter dec needs a color, but font_body is text"* ]]
}

@test "render stops on a leftover {{" {
    tpl $'a\nb {{ bronze\n'
    run auspex_render "$PAL" "$TEST_TMP/t.tpl" "$TEST_TMP/o"
    [ "$status" -eq 1 ]
    [[ "$output" == *"t.tpl:2: leftover {{"* ]]
}

@test "render stops when a value puts {{ in the output" {
    printf 'x = "{{ y }}"\n' >"$TEST_TMP/p.toml"
    tpl '{{ x }}'
    run auspex_render "$TEST_TMP/p.toml" "$TEST_TMP/t.tpl" "$TEST_TMP/o"
    [ "$status" -eq 1 ]
    [[ "$output" == *"t.tpl:1: leftover {{"* ]]
}

@test "render stops on a bad palette line with the palette path and line number" {
    local bad
    for bad in 'Bronze = "#C9A05A"' 'bronze = #C9A05A' 'bronze: "#C9A05A"' '[table]' 'x = "a" # note'; do
        printf '# c\n%s\n' "$bad" >"$TEST_TMP/p.toml"
        tpl 'x'
        run auspex_render "$TEST_TMP/p.toml" "$TEST_TMP/t.tpl" "$TEST_TMP/o"
        [ "$status" -eq 1 ]
        [[ "$output" == *"p.toml:2: bad palette line"* ]]
    done
}

@test "render stops on a key that occurs 2 times" {
    printf 'a = "1"\na = "2"\n' >"$TEST_TMP/p.toml"
    tpl 'x'
    run auspex_render "$TEST_TMP/p.toml" "$TEST_TMP/t.tpl" "$TEST_TMP/o"
    [ "$status" -eq 1 ]
    [[ "$output" == *"p.toml:2: key a occurs 2 times"* ]]
}

@test "a failed render keeps the earlier output file" {
    printf 'old\n' >"$TEST_TMP/o"
    tpl '{{ nope }}'
    run auspex_render "$PAL" "$TEST_TMP/t.tpl" "$TEST_TMP/o"
    [ "$status" -eq 1 ]
    [ "$(cat "$TEST_TMP/o")" = old ]
    [ -z "$(find "$TEST_TMP" -name '.render.*')" ]
}

@test "the AVGVR palette parses and has every key of the design record and the herdr map" {
    local key
    : >"$TEST_TMP/t.tpl"
    while IFS= read -r key; do
        printf '{{ %s }}\n' "$key" >>"$TEST_TMP/t.tpl"
    done < <(sed -n 's/^\([a-z][a-z0-9_]*\) = .*/\1/p' "$AUSPEX_REPO/design/directions/c/colors.toml")
    for key in color0 color7 color8 color15 bg bg_dark bg_darker surface text text_muted text_faint text_bright \
        font_display font_body font_data border_width radius motion_ms; do
        printf '{{ %s }}\n' "$key" >>"$TEST_TMP/t.tpl"
    done
    auspex_render "$AUSPEX_REPO/themes/avgvr/colors.toml" "$TEST_TMP/t.tpl" "$TEST_TMP/o"
    # Each design key has the design value.
    while IFS= read -r line; do
        key="${line%% = *}"
        printf '{{ %s }}' "$key" >"$TEST_TMP/k.tpl"
        auspex_render "$AUSPEX_REPO/themes/avgvr/colors.toml" "$TEST_TMP/k.tpl" "$TEST_TMP/k"
        [ "\"$(cat "$TEST_TMP/k")\"" = "${line#* = }" ]
    done < <(grep '^[a-z]' "$AUSPEX_REPO/design/directions/c/colors.toml")
    [ "$(cat "$AUSPEX_REPO/themes/current")" = avgvr ]
}
