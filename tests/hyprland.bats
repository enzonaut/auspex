#!/usr/bin/env bats

load test_helper

PKG_STEP="$AUSPEX_REPO/system/steps/010-hyprland-packages.sh"
KMS_STEP="$AUSPEX_REPO/system/steps/020-nvidia-early-kms.sh"

setup() {
    auspex_test_setup
    unset HYPRLAND_INSTANCE_SIGNATURE
    export AUSPEX_SYSTEM_STATE="$TEST_TMP/system-state"
    export AUSPEX_MKINITCPIO_DIR="$TEST_TMP/mkinitcpio.conf.d"
    export INSTALLED="$TEST_TMP/installed"
    : >"$INSTALLED"
    make_fake pacman '
case "$1" in
  -Qq) shift; rc=0; for p in "$@"; do grep -qx "$p" "$INSTALLED" || rc=1; done; exit $rc ;;
  -S) shift; for p in "$@"; do [[ $p == -* ]] || grep -qx "$p" "$INSTALLED" || echo "$p" >>"$INSTALLED"; done ;;
  -Rns) shift; for p in "$@"; do [[ $p == -* ]] || sed -i "/^$p\$/d" "$INSTALLED"; done ;;
  *) exit 2 ;;
esac'
    make_fake mkinitcpio
}

teardown() {
    auspex_test_teardown
}

run_step() {
    run bash -c 'source "$1"; "$2"' _ "$1" "$2"
}

hypr_repo_copy() {
    make_repo_copy
    mkdir -p "$AUSPEX/config"
    cp -a "$AUSPEX_REPO/config/hypr" "$AUSPEX_REPO/config/agent-keys.conf" "$AUSPEX/config/"
}

@test "010 installs every package of packages/hyprland.list" {
    run_step "$PKG_STEP" check
    [ "$status" -ne 0 ]
    run_step "$PKG_STEP" apply
    [ "$status" -eq 0 ]
    for p in hyprland hypridle hyprlock xdg-desktop-portal-hyprland hyprpolkitagent waybar mako fuzzel; do
        grep -qx "$p" "$INSTALLED"
    done
    run_step "$PKG_STEP" check
    [ "$status" -eq 0 ]
    run_step "$PKG_STEP" undo
    [ "$status" -eq 0 ]
    [ ! -s "$INSTALLED" ]
}

@test "020 names Omarchy 8807715 and keeps the main mkinitcpio config" {
    grep -q '8807715' "$KMS_STEP"
    run grep -E '/etc/mkinitcpio\.conf([^.]|$)' "$KMS_STEP"
    [ "$status" -eq 1 ]
    [ "$(cat "$AUSPEX_REPO/system/files/auspex-nvidia.conf")" = 'MODULES+=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)' ]
}

@test "020 apply writes the drop-in and rebuilds, undo removes it" {
    run_step "$KMS_STEP" check
    [ "$status" -ne 0 ]
    run_step "$KMS_STEP" apply
    [ "$status" -eq 0 ]
    cmp "$AUSPEX_REPO/system/files/auspex-nvidia.conf" "$AUSPEX_MKINITCPIO_DIR/auspex-nvidia.conf"
    [ "$(fake_calls mkinitcpio)" = "-P" ]
    run_step "$KMS_STEP" check
    [ "$status" -eq 0 ]
    run_step "$KMS_STEP" apply
    [ "$(fake_calls mkinitcpio | wc -l)" -eq 1 ]
    run_step "$KMS_STEP" undo
    [ "$status" -eq 0 ]
    [ ! -e "$AUSPEX_MKINITCPIO_DIR/auspex-nvidia.conf" ]
    [ "$(fake_calls mkinitcpio | wc -l)" -eq 2 ]
}

@test "keys render makes the Hyprland binds from config/agent-keys.conf" {
    run auspex keys render --print
    [ "$status" -eq 0 ]
    [[ "$output" == *'==> config/hypr/agent-binds.lua <=='* ]]
    [[ "$output" == *'hl.bind("SUPER + ALT + A", hl.dsp.exec_cmd("auspex agent --window"))'* ]]
}

@test "the main config holds no agent key and loads agent-binds.lua" {
    run grep -E '^hl\.bind\(.*auspex agent' "$AUSPEX_REPO/config/hypr/hyprland.lua"
    [ "$status" -eq 1 ]
    grep -q 'dofile(config_dir .. "agent-binds.lua")' "$AUSPEX_REPO/config/hypr/hyprland.lua"
}

@test "hypridle locks at 10 min, turns the display off at 15 min, never suspends" {
    f="$AUSPEX_REPO/config/hypr/hypridle.conf"
    grep -qx '    timeout = 600' "$f"
    grep -qx '    timeout = 900' "$f"
    run grep 'systemctl suspend' "$f"
    [ "$status" -eq 1 ]
}

@test "check hyprland-rules passes, and fails when a rule is missing" {
    hypr_repo_copy
    run auspex check hyprland-rules
    [ "$status" -eq 0 ]
    sed -i '/\^gamescope\$/d' "$AUSPEX/config/hypr/hyprland.lua"
    run auspex check hyprland-rules
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL gamescope"* ]]
}

@test "check hyprland fails when an env var is missing" {
    hypr_repo_copy
    sed -i '/NVD_BACKEND/d' "$AUSPEX/config/hypr/hyprland.lua"
    run auspex check hyprland
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL NVD_BACKEND"* ]]
}

@test "check hyprland runs Hyprland --verify-config on the repo config" {
    make_fake Hyprland 'exit 0'
    run auspex check hyprland
    [ "$status" -eq 0 ]
    [ "$(fake_calls Hyprland)" = "--verify-config -c $AUSPEX/config/hypr/hyprland.lua" ]
}

@test "check hyprland prints skip when Hyprland is not installed" {
    if command -v Hyprland >/dev/null 2>&1; then
        skip "Hyprland is installed"
    fi
    run auspex check hyprland
    [ "$status" -eq 77 ]
    [[ "${lines[-1]}" == skip:* ]]
}

@test "the manifest installs the Hyprland and browser flag files, none to KDE config" {
    m="$AUSPEX_REPO/manifest/user.tsv"
    for f in hyprland.lua agent-binds.lua hypridle.conf; do
        grep -qP "^config/hypr/$f\t~/.config/hypr/$f\tcopy\thyprland$" "$m"
    done
    grep -qP '^config/browser-flags/chrome-flags.conf\t~/.config/chrome-flags.conf\tcopy\tany$' "$m"
    grep -qP '^config/browser-flags/brave-flags.conf\t~/.config/brave-flags.conf\tcopy\tany$' "$m"
    [ "$(cat "$AUSPEX_REPO/config/browser-flags/chrome-flags.conf")" = '--password-store=kwallet6' ]
    run auspex check kde-untouched
    [ "$status" -eq 0 ]
}

render_hypr() {
    source "$AUSPEX_REPO/lib/common.sh"
    AUSPEX="$AUSPEX_REPO" auspex_render "$AUSPEX_REPO/themes/avgvr/colors.toml" \
        "$AUSPEX_REPO/templates/hypr/$1" "$TEST_TMP/$2"
}

@test "theme.lua renders the AVGVR look with no unresolved key" {
    render_hypr theme.lua.tpl theme.lua
    out="$TEST_TMP/theme.lua"
    ! grep -q '{{' "$out"
    grep -q 'border_size = 1' "$out"
    grep -q 'rounding = 0' "$out"
    grep -q 'disable_hyprland_logo = true' "$out"
    grep -q 'allow_session_lock_restore = true' "$out"
    grep -q '/ 100' "$out"
}

@test "hyprpaper.conf sets the AVGVR wallpaper for every monitor" {
    cp "$AUSPEX_REPO/templates/hypr/hyprpaper.conf.tpl" "$TEST_TMP/h.conf"
    grep -q '^preload = ~/.local/share/auspex/wallpaper/avgvr.png$' "$TEST_TMP/h.conf"
    grep -q '^wallpaper = , ~/.local/share/auspex/wallpaper/avgvr.png$' "$TEST_TMP/h.conf"
}

@test "hyprpaper is the only new package and starts with Hyprland" {
    grep -qx hyprpaper "$AUSPEX_REPO/packages/hyprland.list"
    grep -q 'hl.exec_cmd("hyprpaper")' "$AUSPEX_REPO/config/hypr/hyprland.lua"
}

@test "the manifest has the 3 theme rows and the deny list covers each target" {
    for t in '.config/hypr/theme.lua	render' '.config/hypr/hyprpaper.conf	render' '.local/share/auspex/wallpaper/avgvr.png	copy'; do
        grep -qF "~/$t	hyprland" "$AUSPEX_REPO/manifest/user.tsv" ||
            grep -P "~/${t%%	*}\t${t##*	}\thyprland" "$AUSPEX_REPO/manifest/user.tsv"
        for tool in Edit Write; do
            grep -qF "$tool(~/${t%%	*})" "$AUSPEX_REPO/claude/deny.json"
        done
    done
}

@test "check theme runs Hyprland --verify-config on the rendered config" {
    make_fake Hyprland 'echo "$HOME $*" >>"$TEST_TMP/hypr.calls"; [ -f "$HOME/.config/hypr/theme.lua" ]'
    run "$AUSPEX_REPO/bin/auspex-check-theme"
    [[ "$output" == *"ok   Hyprland --verify-config passes"* ]]
    grep -q -- '--verify-config -c .*/hyprland.lua' "$TEST_TMP/hypr.calls"
}

@test "SUPER+Return starts or raises herdr-app, it autostarts, and no ghostty is left" {
    f="$AUSPEX_REPO/config/hypr/hyprland.lua"
    run grep -n ghostty "$f"
    [ "$status" -eq 1 ]
    grep -F 'hl.bind("SUPER + Return"' "$f" | grep -qF 'focuswindow class:herdr-app || herdr-app'
    grep -qF 'hl.exec_cmd("[workspace 1 silent] herdr-app")' "$f"
    grep -qF 'hl.window_rule({ match = { class = "^herdr-app$" }, tile = true, workspace = "1" })' "$f"
}

@test "check hyprland-rules fails when the herdr-app rule is missing" {
    hypr_repo_copy
    sed -i '/\^herdr-app\$/d' "$AUSPEX/config/hypr/hyprland.lua"
    run auspex check hyprland-rules
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL herdr app"* ]]
}
