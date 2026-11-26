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

tamper_sudo() {
    make_fake sudo "args=(\"\$@\"); args[$1]+=\$'\\n$2'; exec \"\${args[@]}\""
}

add_reads_step() {
    mkdir -p "$AUSPEX/packages"
    printf 'alpha\nbeta\n' >"$AUSPEX/packages/demo.list"
    cp "$FIX/reads/960-reads.sh" "$AUSPEX/system/steps/"
}

@test "the root shell refuses a step text that changed after the prompt" {
    tamper_sudo 8 'apply() { : >"$MARK.evil"; }'
    run_tty $'y\n' auspex-system-apply 900-fixture
    [ "$status" -ne 0 ]
    [[ "$output" == *"changed after the prompt"* ]]
    [ ! -e "$MARK" ]
    [ ! -e "$MARK.evil" ]
}

@test "a step swapped on disk after the prompt: the root shell runs the approved text" {
    make_fake sudo "printf '%s\n' 'apply() { : >\"\$MARK.evil\"; }' >>\"$AUSPEX/system/steps/900-fixture.sh\"; exec \"\$@\""
    run_tty $'y\n' auspex-system-apply 900-fixture
    [ "$status" -eq 0 ]
    [ -e "$MARK" ]
    [ ! -e "$MARK.evil" ]
}

@test "the root shell refuses a reads file that changed after the prompt" {
    add_reads_step
    tamper_sudo 10 'evil'
    run_tty $'y\n' auspex-system-apply 960-reads
    [ "$status" -ne 0 ]
    [[ "$output" == *"changed after the prompt"* ]]
    [ ! -e "$MARK" ]
}

@test "a reads file swapped on disk after the prompt: the step gets the approved bytes" {
    add_reads_step
    make_fake sudo "printf 'evil\n' >\"$AUSPEX/packages/demo.list\"; exec \"\$@\""
    run_tty $'y\n' auspex-system-apply 960-reads
    [ "$status" -eq 0 ]
    [ "$(cat "$MARK")" = $'alpha\nbeta' ]
    mapfile -t env <"$MARK.env"
    [ "${env[0]}" = "$AUSPEX" ]
    [ "${env[1]}" = "$AUSPEX/system/steps" ]
    [[ "${env[2]}" != "$AUSPEX"* ]]
    [ ! -e "${env[2]}" ]
    digest="$(grep -o 'approval sha256 [0-9a-f]*' <<<"$output" | cut -d' ' -f3)"
    [ -n "$digest" ]
    [ "$(jq -r .approval_sha256 "$AUSPEX_STATE/system-steps/960-reads.json")" = "$digest" ]
}

@test "plan prints each declared reads file and the approval sha256" {
    add_reads_step
    run auspex-system-plan </dev/null
    [ "$status" -eq 0 ]
    [[ "$output" == *"-- reads packages/demo.list (sha256 $(sha256sum "$AUSPEX/packages/demo.list" | cut -d' ' -f1))"$'\n'"alpha"$'\n'"beta"$'\n'* ]]
    [[ "$output" == *"-- approval sha256 "* ]]
}

@test "plan and apply refuse a bad or missing reads file" {
    for p in ../x /etc/x a/../b ./x 'a b/../c'; do
        sed "s|^# auspex:requires-sudo=true|&\n# auspex:reads=$p|" \
            "$FIX/steps/900-fixture.sh" >"$AUSPEX/system/steps/930-bad.sh"
        run auspex-system-plan </dev/null
        [ "$status" -ne 0 ]
        [[ "$output" == *"bad reads path"* ]]
    done
    rm "$AUSPEX/system/steps/930-bad.sh"
    add_reads_step
    rm "$AUSPEX/packages/demo.list"
    run auspex-system-plan </dev/null
    [ "$status" -ne 0 ]
    [[ "$output" == *"cannot read packages/demo.list"* ]]
    ln -s "$FIX/reads/960-reads.sh" "$AUSPEX/packages/demo.list"
    run_tty $'y\n' auspex-system-apply 960-reads
    [ "$status" -ne 0 ]
    [[ "$output" == *"cannot read packages/demo.list"* ]]
    [ -z "$(fake_calls sudo)" ]
}

@test "030 through the root shell installs the approved list, not the list on disk" {
    export AUSPEX_SYSTEM_STATE="$TEST_TMP/system-state"
    export INSTALLED="$TEST_TMP/installed"
    printf '%s\n' jq >"$INSTALLED"
    make_fake pacman '
case "$1" in
  -Qq) shift; rc=0; for p in "$@"; do grep -qx "$p" "$INSTALLED" || rc=1; done; exit $rc ;;
  -S) shift; for p in "$@"; do [[ $p == -* ]] || grep -qx "$p" "$INSTALLED" || echo "$p" >>"$INSTALLED"; done ;;
  *) exit 2 ;;
esac'
    mkdir -p "$AUSPEX/packages"
    cp "$AUSPEX_REPO/packages/auspex-tools.list" "$AUSPEX/packages/"
    cp "$AUSPEX_REPO/system/steps/030-auspex-tools.sh" "$AUSPEX/system/steps/"
    make_fake sudo "printf 'jq\n' >\"$AUSPEX/packages/auspex-tools.list\"; exec \"\$@\""
    run_tty $'y\n' auspex-system-apply 030-auspex-tools
    [ "$status" -eq 0 ]
    [[ "$output" == *"-- reads packages/auspex-tools.list"* ]]
    [ "$(grep -- '^-S' "$CALLS/pacman")" = "-S --needed --noconfirm bats shellcheck jq pacman-contrib" ]
}

add_blobs_step() {
    mkdir -p "$AUSPEX/system/files"
    cp -r "$FIX/blobs/demo" "$AUSPEX/system/files/demo"
    : >"$AUSPEX/system/files/demo/fonts/unlisted.ttf"
    cp "$FIX/blobs/970-blobs.sh" "$AUSPEX/system/steps/"
    export BLOB_DEST="$TEST_TMP/dest/fonts"
}

@test "step_install_verified installs the listed files under the repo dir, through the root shell" {
    add_blobs_step
    run_tty $'y\n' auspex-system-apply 970-blobs
    [ "$status" -eq 0 ]
    cmp "$FIX/blobs/demo/fonts/a.ttf" "$BLOB_DEST/a.ttf"
    cmp "$FIX/blobs/demo/fonts/sub/b.ttf" "$BLOB_DEST/sub/b.ttf"
    [ "$(stat -c %a "$BLOB_DEST/a.ttf")" = 644 ]
    [ ! -e "$BLOB_DEST/unlisted.ttf" ]
    [ ! -e "$BLOB_DEST/other.bin" ]
    [ "$(cat "$MARK")" = "$BLOB_DEST/a.ttf"$'\n'"$BLOB_DEST/sub/b.ttf" ]
}

@test "step_install_verified refuses a file with a wrong hash and installs nothing" {
    add_blobs_step
    printf 'evil\0' >"$AUSPEX/system/files/demo/fonts/sub/b.ttf"
    run_tty $'y\n' auspex-system-apply 970-blobs
    [ "$status" -ne 0 ]
    [[ "$output" == *"hash mismatch: system/files/demo/fonts/sub/b.ttf"* ]]
    [ ! -e "$BLOB_DEST" ]
}

@test "step_install_verified uses the approved SHA256SUMS, not the file on disk" {
    add_blobs_step
    printf 'evil\0' >"$TEST_TMP/evil"
    make_fake sudo "printf 'evil\0' >\"$AUSPEX/system/files/demo/fonts/a.ttf\"; (cd \"$AUSPEX/system/files/demo\" && sha256sum fonts/a.ttf >SHA256SUMS); exec \"\$@\""
    run_tty $'y\n' auspex-system-apply 970-blobs
    [ "$status" -ne 0 ]
    [[ "$output" == *"hash mismatch: system/files/demo/fonts/a.ttf"* ]]
    [ ! -e "$BLOB_DEST" ]
}

@test "step_install_verified refuses a bad line, a path outside, a symlink and an empty match" {
    add_blobs_step
    sums="$AUSPEX/system/files/demo/SHA256SUMS"
    siv() {
        run bash -c 'source "$1/lib/common.sh"; source "$1/lib/system-steps.sh"; AUSPEX_REPO=$1; shift; step_install_verified "$@"' _ "$AUSPEX" "$@"
    }
    siv system/files/demo/SHA256SUMS system/files/other "$BLOB_DEST"
    [ "$status" -eq 1 ]
    [[ "$output" == *"is not under system/files/demo"* ]]
    siv system/files/demo/SHA256SUMS system/files/demo/none "$BLOB_DEST"
    [ "$status" -eq 1 ]
    [[ "$output" == *"lists no file under"* ]]
    cp "$sums" "$TEST_TMP/sums"
    for line in "$(printf '%064d  fonts/../../x' 0)" "$(printf '%064d  /etc/x' 0)" 'not a line'; do
        { cat "$TEST_TMP/sums"; printf '%s\n' "$line"; } >"$sums"
        siv system/files/demo/SHA256SUMS system/files/demo/fonts "$BLOB_DEST"
        [ "$status" -eq 1 ]
        [[ "$output" == *"bad "* ]]
    done
    [ ! -e "$BLOB_DEST" ]
    cp "$TEST_TMP/sums" "$sums"
    ln -sf "$FIX/blobs/demo/fonts/a.ttf" "$AUSPEX/system/files/demo/fonts/a.ttf"
    siv system/files/demo/SHA256SUMS system/files/demo/fonts "$BLOB_DEST"
    [ "$status" -eq 1 ]
    [[ "$output" == *"cannot copy system/files/demo/fonts/a.ttf"* ]]
    [ ! -e "$BLOB_DEST" ]
}

@test "plan prints each SHA256SUMS line of a step" {
    add_blobs_step
    run auspex-system-plan </dev/null
    [ "$status" -eq 0 ]
    [[ "$output" == *"-- reads system/files/demo/SHA256SUMS"* ]]
    while IFS= read -r line; do
        [[ "$output" == *"$line"* ]]
    done <"$FIX/blobs/demo/SHA256SUMS"
}

@test "the static check allows a file listed in a declared SHA256SUMS and names an unlisted one" {
    add_blobs_step
    run auspex-check-system-steps --static
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok 970-blobs"* ]]
    printf '%s\n' 'undo() { rm -f "$AUSPEX_REPO/system/files/demo/fonts/unlisted.ttf"; }' >>"$AUSPEX/system/steps/970-blobs.sh"
    run auspex-check-system-steps --static
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL 970-blobs: reads system/files/demo/fonts/unlisted.ttf but does not declare it"* ]]
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

@test "the static check passes on a step that declares its reads" {
    add_reads_step
    run auspex-check-system-steps --static
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok 960-reads"* ]]
}

@test "the static check names an undeclared read" {
    mkdir -p "$AUSPEX/packages"
    : >"$AUSPEX/packages/demo.list"
    cp "$FIX/bad/undeclared-read.sh" "$AUSPEX/system/steps/950-undeclared-read.sh"
    run auspex-check-system-steps --static
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAIL 950-undeclared-read: reads packages/demo.list but does not declare it in auspex:reads"* ]]
}

@test "the static check fails on each bad step" {
    for bad in no-undo level-1 sddm sddm-breeze sddm-exact-path-wrong-step syntax undeclared-read missing-read bad-read-path; do
        rm -f "$AUSPEX/system/steps/"*.sh
        cp "$FIX/bad/$bad.sh" "$AUSPEX/system/steps/950-$bad.sh"
        run auspex-check-system-steps --static
        [ "$status" -eq 1 ]
    done
}

write_sddm_step() {
    cat >"$AUSPEX/system/steps/$1.sh" <<EOF
#!/usr/bin/env bash
# auspex:summary=SDDM exception test step
# auspex:args=check | apply | undo
# auspex:level=3
# auspex:requires-sudo=true
check() { [[ -e $2 ]]; }
apply() { : >$2; }
undo() { rm -f $2; }
EOF
}

@test "the SDDM exception allows the exact paths in step 060 only" {
    rm -f "$AUSPEX/system/steps/"*.sh
    write_sddm_step 060-avgvr-sddm /etc/sddm.conf.d/zz-auspex-avgvr.conf
    run auspex-check-system-steps --static
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok 060-avgvr-sddm"* ]]
    write_sddm_step 060-avgvr-sddm '"/usr/share/sddm/themes/avgvr.new"'
    run auspex-check-system-steps --static
    [ "$status" -eq 0 ]
    for p in /usr/share/sddm/themes/avgvr/../breeze/x /usr/share/sddm/themes/breeze/x \
        /etc/sddm.conf.d/zz-auspex-avgvr.conf.bak /etc/sddm.conf.d/other.conf /usr/share/plasma/x; do
        write_sddm_step 060-avgvr-sddm "$p"
        run auspex-check-system-steps --static
        [ "$status" -eq 1 ]
        [[ "$output" == *"FAIL 060-avgvr-sddm: names a KDE deny-list path"* ]]
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

setup_050() {
    export AUSPEX_SYSTEM_STATE="$TEST_TMP/system-state"
    export AUSPEX_FONT_DIR="$TEST_TMP/fonts/avgvr"
    export INSTALLED="$TEST_TMP/installed"
    : >"$INSTALLED"
    make_fake pacman '
case "$1" in
  -Qq) shift; rc=0; for p in "$@"; do grep -qx "$p" "$INSTALLED" || rc=1; done; exit $rc ;;
  -S) shift; for p in "$@"; do [[ $p == -* ]] || grep -qx "$p" "$INSTALLED" || echo "$p" >>"$INSTALLED"; done ;;
  -Rns) shift; for p in "$@"; do [[ $p == -* ]] || sed -i "/^$p\$/d" "$INSTALLED"; done ;;
  *) exit 2 ;;
esac'
    make_fake fc-cache
    mkdir -p "$AUSPEX/packages" "$AUSPEX/system/files"
    cp "$AUSPEX_REPO/packages/avgvr.list" "$AUSPEX/packages/"
    cp -r "$AUSPEX_REPO/system/files/avgvr" "$AUSPEX/system/files/"
    cp "$AUSPEX_REPO/system/steps/050-avgvr-fonts.sh" "$AUSPEX/system/steps/"
}

step050() {
    run bash -c 'source "$1/lib/common.sh"; source "$1/lib/system-steps.sh"; AUSPEX_REPO=$1; source "$1/system/steps/050-avgvr-fonts.sh"; "$2"' _ "$AUSPEX" "$1"
}

font_files() {
    (cd "$AUSPEX_FONT_DIR" && find . -type f -printf '%P\n' | LC_ALL=C sort)
}

@test "050 headers say level 3, requires sudo and read the list and SHA256SUMS" {
    local f="$AUSPEX_REPO/system/steps/050-avgvr-fonts.sh"
    grep -qx '# auspex:level=3' "$f"
    grep -qx '# auspex:requires-sudo=true' "$f"
    grep -qx '# auspex:reads=packages/avgvr.list system/files/avgvr/SHA256SUMS' "$f"
    grep -qx 'ttf-jetbrains-mono' "$AUSPEX_REPO/packages/avgvr.list"
    grep -qx 'plymouth' "$AUSPEX_REPO/packages/avgvr.list"
}

@test "050 check fails before apply" {
    setup_050
    step050 check
    [ "$status" -ne 0 ]
}

@test "050 apply installs the package and the hashed fonts, runs fc-cache, and check passes" {
    setup_050
    step050 apply
    [ "$status" -eq 0 ]
    [ "$(grep -- '^-S' "$CALLS/pacman")" = "-S --needed --noconfirm ttf-jetbrains-mono" ]
    [ "$(font_files)" = "$(printf '%s\n' Jost.ttf MarcellusSC-Regular.ttf OFL-jost.txt OFL-marcellussc.txt)" ]
    cmp "$AUSPEX/system/files/avgvr/fonts/Jost.ttf" "$AUSPEX_FONT_DIR/Jost.ttf"
    [ "$(stat -c %a "$AUSPEX_FONT_DIR/Jost.ttf")" = 644 ]
    [ "$(fake_calls fc-cache)" = "-f $AUSPEX_FONT_DIR" ]
    [ "$(cat "$AUSPEX_SYSTEM_STATE/050-avgvr-fonts.installed")" = ttf-jetbrains-mono ]
    [ "$(wc -l <"$AUSPEX_SYSTEM_STATE/050-avgvr-fonts.files")" -eq 4 ]
    step050 check
    [ "$status" -eq 0 ]
}

@test "050 check fails on a font with a wrong hash or a missing package" {
    setup_050
    step050 apply
    printf 'x' >>"$AUSPEX_FONT_DIR/Jost.ttf"
    step050 check
    [ "$status" -ne 0 ]
    cp "$AUSPEX/system/files/avgvr/fonts/Jost.ttf" "$AUSPEX_FONT_DIR/Jost.ttf"
    step050 check
    [ "$status" -eq 0 ]
    : >"$INSTALLED"
    step050 check
    [ "$status" -ne 0 ]
}

@test "050 apply with a bad hash installs no font and runs no fc-cache" {
    setup_050
    printf 'x' >>"$AUSPEX/system/files/avgvr/fonts/Jost.ttf"
    step050 apply
    [ "$status" -ne 0 ]
    [[ "$output" == *"hash mismatch: system/files/avgvr/fonts/Jost.ttf"* ]]
    [ ! -e "$AUSPEX_FONT_DIR" ]
    [ -z "$(fake_calls fc-cache)" ]
}

@test "050 apply refuses when packages/avgvr.list does not list the package" {
    setup_050
    printf 'plymouth\n' >"$AUSPEX/packages/avgvr.list"
    step050 apply
    [ "$status" -ne 0 ]
    [[ "$output" == *"does not list ttf-jetbrains-mono"* ]]
    [ -z "$(fake_calls pacman)" ]
}

@test "050 undo removes only what apply installed" {
    setup_050
    printf 'ttf-jetbrains-mono\n' >"$INSTALLED"
    step050 apply
    [ "$status" -eq 0 ]
    [ ! -e "$AUSPEX_SYSTEM_STATE/050-avgvr-fonts.installed" ]
    printf 'mine\n' >"$AUSPEX_FONT_DIR/operator.ttf"
    step050 undo
    [ "$status" -eq 0 ]
    [ "$(font_files)" = operator.ttf ]
    [ "$(cat "$INSTALLED")" = ttf-jetbrains-mono ]
    [ -z "$(grep -- '^-Rns' "$CALLS/pacman")" ]
    [ "$(fake_calls fc-cache | tail -n 1)" = "-f" ]
    [ ! -e "$AUSPEX_SYSTEM_STATE/050-avgvr-fonts.files" ]
}

@test "050 undo removes the recorded package and the empty font dir" {
    setup_050
    step050 apply
    step050 undo
    [ "$status" -eq 0 ]
    [ ! -e "$AUSPEX_FONT_DIR" ]
    [ "$(grep -- '^-Rns' "$CALLS/pacman")" = "-Rns --noconfirm ttf-jetbrains-mono" ]
    [ ! -s "$INSTALLED" ]
}

@test "050 check uses no sudo, no pacman -S and no fc-cache" {
    setup_050
    step050 check
    [ -z "$(fake_calls sudo)" ]
    [ -z "$(fake_calls fc-cache)" ]
    [ -z "$(grep -v -- '^-Qq' "$CALLS/pacman" 2>/dev/null)" ]
}

@test "050 through the root shell installs the fonts of the approved SHA256SUMS" {
    setup_050
    run_tty $'y\n' auspex-system-apply 050-avgvr-fonts
    [ "$status" -eq 0 ]
    [[ "$output" == *"-- reads packages/avgvr.list"* ]]
    [[ "$output" == *"-- reads system/files/avgvr/SHA256SUMS"* ]]
    cmp "$AUSPEX/system/files/avgvr/fonts/MarcellusSC-Regular.ttf" "$AUSPEX_FONT_DIR/MarcellusSC-Regular.ttf"
    [ "$(fake_calls fc-cache)" = "-f $AUSPEX_FONT_DIR" ]
}
