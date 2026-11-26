#!/usr/bin/env bats

load test_helper

setup() {
    auspex_test_setup
    make_repo_copy
    mkdir -p "$AUSPEX/design/directions" "$AUSPEX/themes/avgvr" "$AUSPEX/system/files"
    cp -a "$AUSPEX_REPO/design/directions/c" "$AUSPEX/design/directions/"
    # The fake resvg writes a PNG stand-in made from its arguments.
    make_fake resvg 'out="${*: -1}"; printf "PNG %s\n" "${*: -2:1}" >"$out"'
}

teardown() {
    auspex_test_teardown
}

@test "theme build makes the fonts, wallpaper and hash files" {
    run auspex theme build
    [ "$status" -eq 0 ]
    [[ "$output" == *"create system/files/avgvr/fonts/Jost.ttf"* ]]
    [[ "$output" == *"create system/files/avgvr/fonts/MarcellusSC-Regular.ttf"* ]]
    [[ "$output" == *"create system/files/avgvr/fonts/OFL-jost.txt"* ]]
    [[ "$output" == *"create themes/avgvr/generated/wallpaper.png"* ]]
    [[ "$output" == *"create system/files/avgvr/SHA256SUMS"* ]]
    [[ "$output" == *"create themes/avgvr/generated/INPUTS.sha256"* ]]
    [ -s "$AUSPEX/themes/avgvr/generated/wallpaper.png" ]
    (cd "$AUSPEX/system/files/avgvr" && sha256sum -c --quiet SHA256SUMS)
    (cd "$AUSPEX" && sha256sum -c --quiet themes/avgvr/generated/INPUTS.sha256)
    grep -q ' bin/auspex-theme-build$' "$AUSPEX/themes/avgvr/generated/INPUTS.sha256"
    grep -q ' design/directions/c/wallpaper.svg$' "$AUSPEX/themes/avgvr/generated/INPUTS.sha256"
    ! grep -q SHA256SUMS "$AUSPEX/system/files/avgvr/SHA256SUMS"
}

@test "theme build gives resvg both TTF files and the 5120x2160 size" {
    run auspex theme build
    [ "$status" -eq 0 ]
    local call
    call="$(fake_calls resvg)"
    [[ "$call" == *"--skip-system-fonts"* ]]
    [[ "$call" =~ --use-font-file\ [^\ ]*/fonts/Jost.ttf ]]
    [[ "$call" =~ --use-font-file\ [^\ ]*/fonts/MarcellusSC-Regular.ttf ]]
    [[ "$call" == *"-w 5120 -h 2160"* ]]
    [[ "$call" == *"design/directions/c/wallpaper.svg"* ]]
}

@test "a 2nd theme build changes no file" {
    auspex theme build >/dev/null
    local before after
    before="$(cd "$AUSPEX" && find system themes -type f -exec sha256sum {} + | sort)"
    run auspex theme build
    [ "$status" -eq 0 ]
    [[ "$output" != *create* && "$output" != *update* && "$output" != *remove* ]]
    [[ "$output" == *"unchanged themes/avgvr/generated/wallpaper.png"* ]]
    after="$(cd "$AUSPEX" && find system themes -type f -exec sha256sum {} + | sort)"
    [ "$before" = "$after" ]
}

@test "theme build --dry-run prints the outputs and changes nothing" {
    run auspex theme build --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"create themes/avgvr/generated/wallpaper.png"* ]]
    [ ! -e "$AUSPEX/themes/avgvr/generated" ]
    [ ! -e "$AUSPEX/system/files/avgvr" ]
}

@test "theme build reports an update when an input changes" {
    auspex theme build >/dev/null
    printf '\n' >>"$AUSPEX/design/directions/c/wallpaper.svg"
    run auspex theme build --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"update themes/avgvr/generated/INPUTS.sha256"* ]]
    [[ "$output" == *"unchanged system/files/avgvr/fonts/Jost.ttf"* ]]
}

@test "theme build removes a font that it no longer makes" {
    auspex theme build >/dev/null
    printf 'old\n' >"$AUSPEX/system/files/avgvr/fonts/Old.ttf"
    run auspex theme build
    [ "$status" -eq 0 ]
    [[ "$output" == *"remove system/files/avgvr/fonts/Old.ttf"* ]]
    [ ! -e "$AUSPEX/system/files/avgvr/fonts/Old.ttf" ]
    ! grep -q Old.ttf "$AUSPEX/system/files/avgvr/SHA256SUMS"
}

@test "theme build stops when a tool is missing" {
    local tooldir="$TEST_TMP/tools"
    mkdir -p "$tooldir"
    for t in bash env cat cp mv mkdir mktemp rm find sort sha256sum cmp install dirname readlink printf; do
        command -v "$t" >/dev/null && ln -sf "$(command -v "$t")" "$tooldir/$t"
    done
    PATH="$FAKES:$AUSPEX/bin:$tooldir" run auspex theme build
    [ "$status" -ne 0 ]
    [[ "$output" == *"woff2_decompress is not installed"* ]]
    [ ! -e "$AUSPEX/themes/avgvr/generated" ]
}

@test "theme build stops when an input is missing" {
    rm "$AUSPEX/design/directions/c/fonts/OFL-jost.txt"
    run auspex theme build
    [ "$status" -ne 0 ]
    [[ "$output" == *"missing input design/directions/c/fonts/OFL-jost.txt"* ]]
}

@test "theme build refuses an unknown argument" {
    run auspex theme build --bad
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage: auspex theme build"* ]]
}
