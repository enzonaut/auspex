#!/usr/bin/env bats

load test_helper

FIX="$AUSPEX_REPO/tests/fixtures/system"
STEP040="$AUSPEX_REPO/system/steps/040-snapper-home-user.sh"

setup() {
    auspex_test_setup
    make_repo_copy
    mkdir -p "$AUSPEX/system/steps" "$AUSPEX/system/files" "$AUSPEX/hooks/post-system-step.d"
    cp "$FIX/steps/"*.sh "$AUSPEX/system/steps/"
    export MARK="$TEST_TMP/mark"
    make_fake sudo 'exec "$@"'
    cat >"$AUSPEX/hooks/post-system-step.d/10-log" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$1" >>"$CALLS/hook"
EOF
    chmod +x "$AUSPEX/hooks/post-system-step.d/10-log"
    unset HC_TERMINAL_ID
}

teardown() {
    auspex_test_teardown
}

run_tty() {
    local input="$1" cmd
    shift
    printf -v cmd '%q ' "$@"
    run bash -c 'printf "%s" "$1" | SHELL=/bin/bash script -qec "$2" /dev/null' _ "$input" "$cmd"
}

@test "apply refuses with AUSPEX_ACTOR=agent, also at a TTY" {
    export AUSPEX_ACTOR=agent
    run_tty $'y\n' auspex-system-apply 900-fixture
    [ "$status" -eq 3 ]
    [[ "$output" == *"AUSPEX_ACTOR=agent"* ]]
    [ -z "$(fake_calls sudo)" ]
    [ ! -e "$MARK" ]
}

@test "apply refuses without a TTY" {
    run auspex-system-apply 900-fixture </dev/null
    [ "$status" -eq 3 ]
    [[ "$output" == *"without a TTY"* ]]
    [ -z "$(fake_calls sudo)" ]
}

@test "apply --dry-run refuses without a TTY" {
    run auspex-system-apply --dry-run 900-fixture </dev/null
    [ "$status" -eq 3 ]
}

@test "undo refuses with AUSPEX_ACTOR=agent and without a TTY" {
    : >"$MARK"
    AUSPEX_ACTOR=agent run_tty $'y\n' auspex-system-undo 900-fixture
    [ "$status" -eq 3 ]
    run auspex-system-undo 900-fixture </dev/null
    [ "$status" -eq 3 ]
    [ -z "$(fake_calls sudo)" ]
    [ -e "$MARK" ]
}

@test "the router reaches the guard: auspex system apply" {
    export AUSPEX_ACTOR=agent
    run auspex system apply 900-fixture </dev/null
    [ "$status" -eq 3 ]
    [ -z "$(fake_calls sudo)" ]
}

@test "apply on y runs the step through sudo, records it and runs the hooks" {
    run_tty $'y\n' auspex-system-apply 900-fixture
    [ "$status" -eq 0 ]
    [[ "$output" == *"Apply step 900-fixture? [y/N]"* ]]
    [[ "$output" == *"apply() {"* ]]
    [[ "$(fake_calls sudo)" == "bash -c "* ]]
    [ -e "$MARK" ]
    rec="$AUSPEX_STATE/system-steps/900-fixture.json"
    [ "$(jq -r .action "$rec")" = apply ]
    [ "$(jq -r .result "$rec")" = ok ]
    [ "$(jq -r .check "$rec")" = pass ]
    [ "$(jq -r .script_sha256 "$rec")" = "$(sha256sum "$AUSPEX/system/steps/900-fixture.sh" | cut -d' ' -f1)" ]
    [ -n "$(jq -r .time "$rec")" ]
    [ "$(fake_calls hook)" = 900-fixture ]
}

@test "apply accepts the step number" {
    run_tty $'y\n' auspex-system-apply 900
    [ "$status" -eq 0 ]
    [ -e "$MARK" ]
}

@test "apply on n or empty input changes nothing" {
    run_tty $'n\n' auspex-system-apply 900-fixture
    [ "$status" -ne 0 ]
    run_tty $'\n' auspex-system-apply 900-fixture
    [ "$status" -ne 0 ]
    [ -z "$(fake_calls sudo)" ]
    [ ! -e "$MARK" ]
    [ ! -e "$AUSPEX_STATE/system-steps/900-fixture.json" ]
    [ -z "$(fake_calls hook)" ]
}

@test "apply --dry-run prints the script and changes nothing" {
    run_tty '' auspex-system-apply --dry-run 900-fixture
    [ "$status" -eq 0 ]
    [[ "$output" == *"apply() {"* ]]
    [[ "$output" == *"dry run"* ]]
    [[ "$output" != *"[y/N]"* ]]
    [ -z "$(fake_calls sudo)" ]
    [ ! -e "$MARK" ]
    [ ! -e "$AUSPEX_STATE/system-steps" ]
}

@test "undo on y runs the undo function and records it" {
    : >"$MARK"
    run_tty $'y\n' auspex-system-undo 900-fixture
    [ "$status" -eq 0 ]
    [[ "$output" == *"Undo step 900-fixture? [y/N]"* ]]
    [ ! -e "$MARK" ]
    rec="$AUSPEX_STATE/system-steps/900-fixture.json"
    [ "$(jq -r .action "$rec")" = undo ]
    [ "$(jq -r .check "$rec")" = fail ]
    [ "$(fake_calls hook)" = 900-fixture ]
}

@test "a failed step exits non-zero, records failed and skips the hooks" {
    run_tty $'y\n' auspex-system-apply 910-fails
    [ "$status" -ne 0 ]
    [ "$(jq -r .result "$AUSPEX_STATE/system-steps/910-fails.json")" = failed ]
    [ -z "$(fake_calls hook)" ]
}

@test "the root shell refuses a step that changed after the prompt" {
    make_fake sudo "printf '%s\n' 'apply() { : >\"\$MARK.evil\"; }' >>\"$AUSPEX/system/steps/900-fixture.sh\"; exec \"\$@\""
    run_tty $'y\n' auspex-system-apply 900-fixture
    [ "$status" -ne 0 ]
    [[ "$output" == *"changed after the prompt"* ]]
    [ ! -e "$MARK" ]
    [ ! -e "$MARK.evil" ]
}

@test "apply refuses bad step names" {
    for bad in ../900-fixture 900-fixture.sh 900-Fixture 999 '9-x' ''; do
        run_tty $'y\n' auspex-system-apply "$bad"
        [ "$status" -eq 2 ]
    done
    [ -z "$(fake_calls sudo)" ]
}

@test "apply refuses a step that is a symlink, by name or by number" {
    ln -s "$AUSPEX/system/steps/900-fixture.sh" "$AUSPEX/system/steps/930-link.sh"
    for arg in 930 930-link; do
        run_tty $'y\n' auspex-system-apply "$arg"
        [ "$status" -eq 2 ]
    done
    [ -z "$(fake_calls sudo)" ]
    [ ! -e "$MARK" ]
}

@test "plan lists pending steps with the script and a diff of installed files" {
    target="$TEST_TMP/etc/demo.conf"
    mkdir -p "$(dirname "$target")"
    printf 'old=1\n' >"$target"
    printf 'new=1\n' >"$AUSPEX/system/files/demo.conf"
    sed "s|^# auspex:requires-sudo=true|&\n# auspex:installs=system/files/demo.conf $target|" \
        "$FIX/steps/900-fixture.sh" >"$AUSPEX/system/steps/920-files.sh"
    run auspex-system-plan </dev/null
    [ "$status" -eq 0 ]
    [[ "$output" == *"== step 900-fixture (pending)"* ]]
    [[ "$output" == *"== step 920-files (pending)"* ]]
    [[ "$output" == *"-old=1"* ]]
    [[ "$output" == *"+new=1"* ]]
    [ -z "$(fake_calls sudo)" ]
}

@test "plan lists applied steps without their script" {
    : >"$MARK"
    run auspex-system-plan </dev/null
    [ "$status" -eq 0 ]
    [[ "$output" == *"applied 900-fixture"* ]]
    [[ "$output" != *"== step 900-fixture"* ]]
}

@test "plan refuses an installs line outside system/files" {
    sed "s|^# auspex:requires-sudo=true|&\n# auspex:installs=lib/common.sh /etc/x|" \
        "$FIX/steps/900-fixture.sh" >"$AUSPEX/system/steps/930-bad.sh"
    run auspex-system-plan </dev/null
    [ "$status" -ne 0 ]
}

@test "prepare outside herdr prints the exact command" {
    make_fake herdr-app 'exit 1'
    run auspex-system-prepare 900
    [ "$status" -eq 0 ]
    [[ "$output" == *"$AUSPEX/bin/auspex system apply 900-fixture"* ]]
    [ -z "$(fake_calls herdr-app)" ]
}

@test "prepare in herdr opens a split pane to the right that runs apply" {
    export HC_TERMINAL_ID=t9
    make_fake herdr-app '
case "$1" in
  ls) echo "{\"spaces\":[{\"tabs\":[{\"terminals\":[{\"terminal\":\"t9\",\"pane\":\"p9\"}]}]}]}" ;;
  do) echo "{\"pane\":\"p10\",\"terminal\":\"t10\"}" ;;
esac'
    run auspex-system-prepare 900-fixture
    [ "$status" -eq 0 ]
    split="$(fake_calls herdr-app | grep '^do ')"
    [[ "$split" == "do pane.split --direction right --pane p9 --argv "* ]]
    argv="${split#*--argv }"
    [ "$(jq -r '.[0]' <<<"$argv")" = bash ]
    [[ "$(jq -r '.[2]' <<<"$argv")" == '"$1" system apply "$2";'* ]]
    [ "$(jq -r '.[4]' <<<"$argv")" = "$AUSPEX/bin/auspex" ]
    [ "$(jq -r '.[5]' <<<"$argv")" = 900-fixture ]
    [[ "$output" == *t10* ]]
    [[ "$output" == *"$AUSPEX/bin/auspex system apply 900-fixture"* ]]
    [ -z "$(fake_calls sudo)" ]
}

@test "prepare falls back to printing when herdr-app ls fails" {
    export HC_TERMINAL_ID=t9
    make_fake herdr-app 'exit 1'
    run auspex-system-prepare 900-fixture
    [ "$status" -eq 0 ]
    [[ "$output" == *"$AUSPEX/bin/auspex system apply 900-fixture"* ]]
    [ -z "$(fake_calls herdr-app | grep '^do ')" ]
}

@test "prepare refuses an unknown step" {
    run auspex-system-prepare 999-nothing
    [ "$status" -eq 2 ]
}

@test "the static check passes on good steps" {
    run auspex-check-system-steps --static
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok 900-fixture"* ]]
}

@test "the static check fails on each bad step" {
    for bad in no-undo level-1 sddm syntax; do
        rm -f "$AUSPEX/system/steps/"*.sh
        cp "$FIX/bad/$bad.sh" "$AUSPEX/system/steps/950-$bad.sh"
        run auspex-check-system-steps --static
        [ "$status" -eq 1 ]
    done
}

step040() {
    run bash -c 'source "$1"; "$2"' _ "$STEP040" "$1"
}

setup_snapper() {
    export SNAPPER_CONFIG_DIR="$TEST_TMP/snapper"
    export AUSPEX_SYSTEM_STATE="$TEST_TMP/system-state"
    mkdir -p "$SNAPPER_CONFIG_DIR"
    cp "$FIX/snapper/home" "$FIX/snapper/root" "$SNAPPER_CONFIG_DIR/"
    make_fake snapper '
[[ "$1" == -c && "$3" == set-config ]] || exit 2
key="${4%%=*}" val="${4#*=}"
sed -i "s|^$key=.*|$key=\"$val\"|" "$SNAPPER_CONFIG_DIR/$2"'
}

@test "040 headers say level 3 and requires sudo" {
    grep -qx '# auspex:level=3' "$STEP040"
    grep -qx '# auspex:requires-sudo=true' "$STEP040"
}

@test "040 check fails while ALLOW_USERS is empty" {
    setup_snapper
    step040 check
    [ "$status" -ne 0 ]
}

@test "040 apply sets ALLOW_USERS in home only, and check passes" {
    setup_snapper
    step040 apply
    [ "$status" -eq 0 ]
    grep -qx 'ALLOW_USERS="lordvader"' "$SNAPPER_CONFIG_DIR/home"
    cmp -s "$FIX/snapper/root" "$SNAPPER_CONFIG_DIR/root"
    [ "$(fake_calls snapper)" = '-c home set-config ALLOW_USERS=lordvader' ]
    step040 check
    [ "$status" -eq 0 ]
}

@test "040 undo restores the earlier value" {
    setup_snapper
    sed -i 's|^ALLOW_USERS=.*|ALLOW_USERS="backup"|' "$SNAPPER_CONFIG_DIR/home"
    step040 apply
    [ "$status" -eq 0 ]
    grep -qx 'ALLOW_USERS="backup lordvader"' "$SNAPPER_CONFIG_DIR/home"
    step040 undo
    [ "$status" -eq 0 ]
    grep -qx 'ALLOW_USERS="backup"' "$SNAPPER_CONFIG_DIR/home"
    cmp -s "$FIX/snapper/root" "$SNAPPER_CONFIG_DIR/root"
}

@test "040 apply twice keeps the first earlier value" {
    setup_snapper
    step040 apply
    step040 apply
    [ "$status" -eq 0 ]
    [ "$(fake_calls snapper | wc -l)" -eq 1 ]
    step040 undo
    grep -qx 'ALLOW_USERS=""' "$SNAPPER_CONFIG_DIR/home"
}

@test "040 undo with no record changes nothing" {
    setup_snapper
    step040 undo
    [ "$status" -eq 0 ]
    [ -z "$(fake_calls snapper)" ]
}

@test "040 check uses no sudo and no snapper" {
    setup_snapper
    step040 check
    [ -z "$(fake_calls sudo)" ]
    [ -z "$(fake_calls snapper)" ]
}
