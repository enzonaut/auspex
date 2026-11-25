#!/usr/bin/env bats
# The hook runner and the default hooks in a temp HOME and a temp AUSPEX_STATE.

load test_helper
load fixtures/apply/helper

setup() {
    apply_test_setup
}

teardown() {
    auspex_test_teardown
}

add_hook() {
    printf '#!/bin/sh\n%s\n' "$3" >"$AUSPEX/hooks/$1/$2"
    chmod +x "$AUSPEX/hooks/$1/$2"
}

copy_repo_hooks() {
    cp "$AUSPEX_REPO"/hooks/post-apply.d/[0-9]* "$AUSPEX/hooks/post-apply.d/"
}

@test "post-apply hooks run in name order and get the generation number" {
    add_hook post-apply.d 20-b 'echo "b $1" >>"$HOME/hooks"'
    add_hook post-apply.d 10-a 'echo "a $1" >>"$HOME/hooks"'
    repo_commit "hooks"
    run auspex apply
    [ "$status" -eq 0 ]
    [ "$(tr '\n' ' ' <"$HOME/hooks")" = "a 1 b 1 " ]
}

@test "a failed hook is a warning and the later hooks still run" {
    add_hook post-apply.d 10-a 'exit 4'
    add_hook post-apply.d 20-b 'echo b >>"$HOME/hooks"'
    repo_commit "hooks"
    run auspex apply
    [ "$status" -eq 0 ]
    [[ "$output" == *"hook 10-a failed (exit 4)"* ]]
    [ "$(cat "$HOME/hooks")" = b ]
}

@test "a hook file that is not executable does not run" {
    printf '#!/bin/sh\necho x >>"$HOME/hooks"\n' >"$AUSPEX/hooks/post-apply.d/10-a"
    repo_commit "hooks"
    auspex apply
    [ ! -e "$HOME/hooks" ]
}

@test "post-undo hooks run after undo and get the new generation number" {
    add_hook post-undo.d 10-a 'echo "undo $1" >>"$HOME/hooks"'
    repo_commit "hooks"
    auspex apply
    run auspex undo
    [ "$status" -eq 0 ]
    [ "$(cat "$HOME/hooks")" = "undo 2" ]
}

@test "auspex_run_hooks runs post-system-step hooks with the step name" {
    add_hook post-system-step.d 10-a 'echo "step $1" >>"$HOME/hooks"'
    run bash -c 'source "$AUSPEX/lib/common.sh"; auspex_run_hooks post-system-step 030-auspex-tools'
    [ "$status" -eq 0 ]
    [ "$(cat "$HOME/hooks")" = "step 030-auspex-tools" ]
}

@test "the hyprland hook reloads only when a hypr file changed and Hyprland runs" {
    copy_repo_hooks
    mkdir -p "$AUSPEX/config/hypr"
    printf 'x\n' >"$AUSPEX/config/hypr/hyprland.conf"
    printf 'config/hypr/hyprland.conf\t~/.config/hypr/hyprland.conf\tcopy\tany\n' >>"$AUSPEX/manifest/user.tsv"
    repo_commit "hypr"
    auspex apply
    [ -z "$(fake_calls hyprctl)" ]
    printf 'y\n' >"$AUSPEX/config/hypr/hyprland.conf"
    repo_commit "hypr 2"
    HYPRLAND_INSTANCE_SIGNATURE=test auspex apply
    [ "$(fake_calls hyprctl)" = reload ]
}

@test "the hyprland hook does not reload when no hypr file changed" {
    copy_repo_hooks
    HYPRLAND_INSTANCE_SIGNATURE=test auspex apply
    [ -z "$(fake_calls hyprctl)" ]
}

@test "the systemd hook reloads the user units and enables the update timer" {
    copy_repo_hooks
    mkdir -p "$AUSPEX/config/systemd"
    printf '[Timer]\n' >"$AUSPEX/config/systemd/auspex-update-check.timer"
    printf 'config/systemd/auspex-update-check.timer\t~/.config/systemd/user/auspex-update-check.timer\tcopy\tany\n' >>"$AUSPEX/manifest/user.tsv"
    repo_commit "timer"
    auspex apply
    [[ "$(fake_calls systemctl)" == *"--user daemon-reload"* ]]
    [[ "$(fake_calls systemctl)" == *"--user enable --now auspex-update-check.timer"* ]]
}

@test "the systemd hook does nothing when no unit changed" {
    copy_repo_hooks
    auspex apply
    [ -z "$(fake_calls systemctl)" ]
}

@test "the mako hook reloads only when mako runs" {
    copy_repo_hooks
    mkdir -p "$AUSPEX/config/mako"
    printf 'x\n' >"$AUSPEX/config/mako/config"
    printf 'config/mako/config\t~/.config/mako/config\tcopy\tany\n' >>"$AUSPEX/manifest/user.tsv"
    repo_commit "mako"
    auspex apply
    [ -z "$(fake_calls makoctl)" ]
    make_fake pgrep 'exit 0'
    printf 'y\n' >"$AUSPEX/config/mako/config"
    repo_commit "mako 2"
    auspex apply
    [ "$(fake_calls makoctl)" = reload ]
}
