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

# check theme runs on a copy that has the committed theme files.
theme_repo_copy() {
    cp -a "$AUSPEX_REPO/themes" "$AUSPEX_REPO/system" "$AUSPEX_REPO/templates" \
        "$AUSPEX_REPO/manifest" "$AUSPEX/"
}

@test "check theme passes on the repo" {
    AUSPEX="$AUSPEX_REPO" run "$AUSPEX_REPO/bin/auspex" check theme
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok   themes/avgvr/generated/INPUTS.sha256 is current"* ]]
    [[ "$output" == *"contrast pairs meet their ratios"* ]]
    [[ "$output" != *FAIL* ]]
}

@test "check theme passes on a repo copy" {
    theme_repo_copy
    run auspex check theme
    [ "$status" -eq 0 ]
}

@test "check theme fails when an input changed after the build" {
    theme_repo_copy
    printf '\n' >>"$AUSPEX/design/directions/c/wallpaper.svg"
    run auspex check theme
    [ "$status" -eq 1 ]
    [[ "$output" == *"INPUTS.sha256 is not current: run auspex theme build"* ]]
}

@test "check theme fails on a wrong hash or an unlisted file in system/files/avgvr" {
    theme_repo_copy
    printf 'x' >>"$AUSPEX/system/files/avgvr/fonts/OFL-jost.txt"
    printf 'x\n' >"$AUSPEX/system/files/avgvr/fonts/Extra.ttf"
    run auspex check theme
    [ "$status" -eq 1 ]
    [[ "$output" == *"SHA256SUMS does not match"* ]]
    [[ "$output" == *"system/files/avgvr/fonts/Extra.ttf is not in SHA256SUMS"* ]]
}

@test "check theme fails on an SVG color that is not in the palette" {
    theme_repo_copy
    sed -i 's/#C9A05A/#123456/' "$AUSPEX/design/directions/c/mark.svg"
    run auspex check theme
    [ "$status" -eq 1 ]
    [[ "$output" == *"mark.svg uses #123456, which is not a palette value"* ]]
}

@test "check theme fails on an SVG font that is not a palette font or a TTF" {
    theme_repo_copy
    sed -i 's/font-family="Marcellus SC"/font-family="Comic Sans"/' "$AUSPEX/design/directions/c/wallpaper.svg"
    run auspex check theme
    [ "$status" -eq 1 ]
    [[ "$output" == *"wallpaper.svg uses font Comic Sans, which is not a palette font"* ]]
    [[ "$output" == *"wallpaper.svg uses font Comic Sans, which no TTF"* ]]
}

@test "check theme fails when a palette change breaks a contrast pair" {
    theme_repo_copy
    sed -i 's/^text_faint = .*/text_faint = "#3A332C"/' "$AUSPEX/themes/avgvr/colors.toml"
    run auspex check theme
    [ "$status" -eq 1 ]
    [[ "$output" == *"contrast --color-text-faint on --color-bg is"*"needs 5.35:1"* ]]
}

@test "check theme fails when a contrast hex differs from the palette" {
    theme_repo_copy
    sed -i 's/^red = .*/red = "#DE5A4D"/' "$AUSPEX/themes/avgvr/colors.toml"
    run auspex check theme
    [ "$status" -eq 1 ]
    [[ "$output" == *"contrast row red (#DE5A4C) on --color-bg: a color is not in the palette"* ]]
}

@test "check theme fails on a template that does not render" {
    theme_repo_copy
    mkdir -p "$AUSPEX/templates/zz"
    printf 'color: {{ no_such_key }}\n' >"$AUSPEX/templates/zz/a.css.tpl"
    run auspex check theme
    [ "$status" -eq 1 ]
    [[ "$output" == *"template templates/zz/a.css.tpl does not render"* ]]
}

@test "check theme fails on a game config path in a step or the manifest" {
    theme_repo_copy
    local p
    for p in '~/.local/share/Steam/x' '$HOME/.config/lutris' '/usr/share/steam/a' '~/Games/x' 'WINEPREFIX=/x'; do
        printf '# writes %s\n' "$p" >"$AUSPEX/system/steps/990-zz.sh"
        run auspex check theme
        [ "$status" -eq 1 ]
        [[ "$output" == *"names a game config path"* ]]
    done
    rm -f "$AUSPEX/system/steps/990-zz.sh"
    printf '~/.steam/steam.cfg\t~/.x\tcopy\tall\n' >>"$AUSPEX/manifest/user.tsv"
    run auspex check theme
    [ "$status" -eq 1 ]
    [[ "$output" == *"manifest/user.tsv"* ]]
}
