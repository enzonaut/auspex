#!/usr/bin/env bats
# fuzzel runs a terminal app as: <terminal=> <program> <args...>, with plain words.
# `herdr-app do tab.new --argv` takes 1 JSON array. So no terminal= value can run a
# program in a new tab, and the fuzzel template ships no terminal= line (OQ13).

load test_helper

setup() {
    auspex_test_setup
    source "$AUSPEX_REPO/lib/render.sh"
    make_fake herdr-app '
case "$1 $2 $3" in
    "do tab.new --argv") jq -e "type == \"array\"" <<<"$4" >/dev/null 2>&1 || exit 2 ;;
    *) exit 1 ;;
esac'
}

teardown() {
    auspex_test_teardown
}

render_fuzzel() {
    auspex_render "$AUSPEX_REPO/themes/avgvr/colors.toml" "$AUSPEX_REPO/templates/fuzzel/fuzzel.ini.tpl" "$TEST_TMP/fuzzel.ini"
}

@test "the rendered fuzzel.ini has no terminal= line and no ghostty" {
    render_fuzzel
    run grep -nE '^[[:space:]]*terminal[[:space:]]*=|ghostty' "$TEST_TMP/fuzzel.ini"
    [ "$status" -eq 1 ]
}

@test "the rendered fuzzel.ini has the palette colors and the border" {
    render_fuzzel
    grep -qx 'background=17140Fff' "$TEST_TMP/fuzzel.ini"
    grep -qx 'border=C9A05Aff' "$TEST_TMP/fuzzel.ini"
    grep -qx 'radius=0' "$TEST_TMP/fuzzel.ini"
}

@test "herdr-app tab.new accepts a JSON argv array and refuses the plain words that fuzzel appends" {
    run herdr-app do tab.new --argv '["btop"]'
    [ "$status" -eq 0 ]
    run herdr-app do tab.new --argv btop
    [ "$status" -eq 2 ]
}
