#!/usr/bin/env bats

load test_helper

REAL_HOME="$HOME"

setup() {
    auspex_test_setup
    M="$AUSPEX_REPO/lib/merge/claude-settings"
    SRC="$AUSPEX_REPO/claude/deny.json"
    FIX="$AUSPEX_REPO/tests/fixtures/claude/settings.json"
    W="$TEST_TMP/work"
    mkdir -p "$W"
}

teardown() {
    auspex_test_teardown
}

deny() {
    jq -r '.permissions.deny // [] | .[]' "$1"
}

check_merged() {
    jq -e . "$2" >/dev/null
    [ "$(jq -c 'del(.permissions.deny)' "$1")" = "$(jq -c 'del(.permissions.deny)' "$2")" ]
    local n
    n="$(deny "$1" | wc -l)"
    [ "$(deny "$2" | head -n "$n")" = "$(deny "$1")" ]
    [ "$(deny "$2" | tail -n +"$((n + 1))")" = "$(deny "$SRC")" ]
    [ "$(deny "$2" | sort | uniq -d)" = "" ]
    [ "$(jq -r '.[]' "$3")" = "$(deny "$SRC" | LC_ALL=C sort -u)" ]
}

src_with() {
    jq "$1" "$SRC" >"$W/src.json"
    printf '%s\n' "$W/src.json"
}

@test "merge keeps the fixture and adds each deny rule" {
    run "$M" merge "$SRC" "$FIX" "$W/none" "$W/out" "$W/owned"
    [ "$status" -eq 0 ]
    check_merged "$FIX" "$W/out" "$W/owned"
    [ "$(jq -c .permissions.allow "$W/out")" = '["Bash(git push:*)"]' ]
    [ "$(deny "$W/out" | wc -l)" -eq $(($(deny "$FIX" | wc -l) + $(deny "$SRC" | wc -l))) ]
    jq -e '.hooks.SessionStart[0].hooks[0].command | contains("herdr-agent-state.sh")' "$W/out"
}

@test "a 2nd merge changes nothing" {
    "$M" merge "$SRC" "$FIX" "$W/none" "$W/out1" "$W/owned1"
    "$M" merge "$SRC" "$W/out1" "$W/owned1" "$W/out2" "$W/owned2"
    cmp "$W/out1" "$W/out2"
    cmp "$W/owned1" "$W/owned2"
}

@test "a rule the operator had already is not owned and is never removed" {
    rule="$(deny "$SRC" | head -n 1)"
    jq --arg r "$rule" '.permissions.deny += [$r]' "$FIX" >"$W/target"
    "$M" merge "$SRC" "$W/target" "$W/none" "$W/out1" "$W/owned1"
    [ "$(deny "$W/out1" | grep -cFx -- "$rule")" -eq 1 ]
    ! jq -e --arg r "$rule" 'index($r)' "$W/owned1"
    src="$(src_with '.permissions.deny |= .[1:]')"
    "$M" merge "$src" "$W/out1" "$W/owned1" "$W/out2" "$W/owned2"
    deny "$W/out2" | grep -qFx -- "$rule"
}

@test "a rule dropped from the source is removed when auspex owns it" {
    rule="$(deny "$SRC" | head -n 1)"
    "$M" merge "$SRC" "$FIX" "$W/none" "$W/out1" "$W/owned1"
    src="$(src_with '.permissions.deny |= .[1:]')"
    "$M" merge "$src" "$W/out1" "$W/owned1" "$W/out2" "$W/owned2"
    ! deny "$W/out2" | grep -qFx -- "$rule"
    ! jq -e --arg r "$rule" 'index($r)' "$W/owned2"
    check_merged "$FIX" "$W/out1" "$W/owned1"
    [ "$(jq -c 'del(.permissions.deny)' "$FIX")" = "$(jq -c 'del(.permissions.deny)' "$W/out2")" ]
}

@test "merge with no target writes only the deny rules" {
    "$M" merge "$SRC" "$W/none" "$W/none" "$W/out" "$W/owned"
    [ "$(jq -c 'keys' "$W/out")" = '["permissions"]' ]
    [ "$(deny "$W/out")" = "$(deny "$SRC")" ]
}

@test "merge refuses a bad source or target and writes nothing" {
    for f in '.permissions.allow = ["Bash(x)"]' '.env = {}' '.permissions.deny = []' '.permissions.deny = [1]'; do
        src="$(src_with "$f")"
        run "$M" merge "$src" "$FIX" "$W/none" "$W/out" "$W/owned"
        [ "$status" -eq 1 ]
        [ ! -e "$W/out" ]
    done
    printf '{"permissions":{"deny":"Bash(x)"}}\n' >"$W/target"
    run "$M" merge "$SRC" "$W/target" "$W/none" "$W/out" "$W/owned"
    [ "$status" -eq 1 ]
    printf '{not json\n' >"$W/target"
    run "$M" merge "$SRC" "$W/target" "$W/none" "$W/out" "$W/owned"
    [ "$status" -eq 1 ]
    run "$M" merge "$SRC" "$FIX"
    [ "$status" -eq 1 ]
    run "$M" frob
    [ "$status" -eq 2 ]
}

@test "restore gives back the fixture byte for byte" {
    "$M" merge "$SRC" "$FIX" "$W/none" "$W/out" "$W/owned"
    "$M" restore "$FIX" "$W/out" "$W/owned" "$W/none" "$W/back"
    cmp "$FIX" "$W/back"
}

@test "restore keeps a rule and a key the operator added after the merge" {
    "$M" merge "$SRC" "$FIX" "$W/none" "$W/out" "$W/owned"
    jq '.permissions.deny += ["Bash(operator-rule)"] | .theme = "light"' "$W/out" >"$W/edited"
    "$M" restore "$FIX" "$W/edited" "$W/owned" "$W/none" "$W/back"
    [ "$(deny "$W/back")" = "$(deny "$FIX"; echo 'Bash(operator-rule)')" ]
    [ "$(jq -r .theme "$W/back")" = light ]
}

@test "restore with no earlier file gives an empty file" {
    "$M" merge "$SRC" "$W/none" "$W/none" "$W/out" "$W/owned"
    "$M" restore "$W/none" "$W/out" "$W/owned" "$W/none" "$W/back"
    [ -f "$W/back" ]
    [ ! -s "$W/back" ]
}

@test "digest lists the owned rules in the target" {
    "$M" merge "$SRC" "$FIX" "$W/none" "$W/out" "$W/owned"
    [ "$("$M" digest "$W/out" "$W/owned")" = "$(deny "$SRC" | LC_ALL=C sort -u)" ]
    rule="$(deny "$SRC" | head -n 1)"
    jq --arg r "$rule" '.permissions.deny -= [$r]' "$W/out" >"$W/edited"
    [ "$("$M" digest "$W/edited" "$W/owned")" = "$(deny "$SRC" | grep -vFx -- "$rule" | LC_ALL=C sort -u)" ]
    [ -z "$("$M" digest "$W/out" "$W/none")" ]
}

@test "merge and restore work on a temp copy of the live settings file" {
    live="$REAL_HOME/.claude/settings.json"
    [ -f "$live" ] || skip "no live settings file"
    sum="$(sha256sum <"$live")"
    jq --slurpfile src "$SRC" 'if .permissions.deny then .permissions.deny -= $src[0].permissions.deny else . end' "$live" >"$W/live.json"
    "$M" merge "$SRC" "$W/live.json" "$W/none" "$W/out" "$W/owned"
    check_merged "$W/live.json" "$W/out" "$W/owned"
    "$M" merge "$SRC" "$W/out" "$W/owned" "$W/out2" "$W/owned2"
    cmp "$W/out" "$W/out2"
    "$M" restore "$W/live.json" "$W/out" "$W/owned" "$W/none" "$W/back"
    cmp "$W/live.json" "$W/back"
    [ "$(sha256sum <"$live")" = "$sum" ]
}

perm_repo() {
    make_repo_copy
    cp -a "$AUSPEX_REPO/agent" "$AUSPEX_REPO/claude" "$AUSPEX_REPO/config" "$AUSPEX_REPO/manifest" "$AUSPEX_REPO/system" "$AUSPEX_REPO/systemd" "$AUSPEX_REPO/templates" "$AUSPEX_REPO/themes" "$AUSPEX/"
}

@test "apply merges the settings, plan shows unchanged, undo restores them" {
    perm_repo
    mkdir -p "$AUSPEX/migrations" "$AUSPEX/hooks/post-apply.d" \
        "$AUSPEX/hooks/post-undo.d" "$AUSPEX/hooks/post-system-step.d"
    make_fake snapper 'exit 1'
    make_fake hyprctl
    make_fake systemctl
    make_fake makoctl
    make_fake pgrep 'exit 1'
    unset HYPRLAND_INSTANCE_SIGNATURE
    git -C "$AUSPEX" init -q -b main
    git -C "$AUSPEX" add -A
    git -C "$AUSPEX" -c user.name=auspex-test -c user.email=test@example.invalid commit -q -m fixture
    mkdir -p "$HOME/.claude"
    cp -- "$FIX" "$HOME/.claude/settings.json"
    auspex apply
    check_merged "$FIX" "$HOME/.claude/settings.json" "$AUSPEX_STATE/owned/claude-settings.json"
    cmp "$AUSPEX/claude/agent-settings.json" "$HOME/.config/auspex/claude/agent-settings.json"
    run auspex plan
    [[ "$output" == *"unchanged ~/.claude/settings.json"* ]]
    auspex undo
    cmp "$FIX" "$HOME/.claude/settings.json"
    [ ! -e "$HOME/.config/auspex/claude/agent-settings.json" ]
}

@test "check permissions passes on the repo files" {
    perm_repo
    run "$AUSPEX/bin/auspex-check-permissions"
    [ "$status" -eq 0 ]
    [ "$output" = "permissions ok" ]
}

@test "check permissions --print writes a rule pair for each target" {
    perm_repo
    run "$AUSPEX/bin/auspex-check-permissions" --print
    [ "$status" -eq 0 ]
    [[ "$output" == *"Edit(~/.claude/settings.json)"* ]]
    [[ "$output" == *"Write(~/.config/auspex/claude/headless-settings.json)"* ]]
    [ "$(printf '%s\n' "$output" | wc -l)" -eq "$((2 * $(grep -cvE '^(#|$)' "$AUSPEX_REPO/manifest/user.tsv")))" ]
}

@test "check permissions fails for a level 3 command with no deny rule" {
    perm_repo
    add_command auspex-zap 3
    run "$AUSPEX/bin/auspex-check-permissions"
    [ "$status" -eq 1 ]
    [[ "$output" == *"level 3 command 'auspex zap' has no deny rule"* ]]
}

@test "check permissions fails for a level 1 command with no allow rule" {
    perm_repo
    add_command auspex-zap 1
    run "$AUSPEX/bin/auspex-check-permissions"
    [ "$status" -eq 1 ]
    [[ "$output" == *"level 1 command 'auspex zap' has no allow rule"* ]]
}

@test "check permissions fails when the live settings allow an auspex command" {
    perm_repo
    mkdir -p "$HOME/.claude"
    printf '{"permissions":{"allow":["Bash(auspex status*)"]}}\n' >"$HOME/.claude/settings.json"
    run "$AUSPEX/bin/auspex-check-permissions"
    [ "$status" -eq 1 ]
    [[ "$output" == *"'auspex status' has an allow rule in ~/.claude/settings.json"* ]]
}

@test "check permissions fails when a target rule is missing" {
    perm_repo
    jq --indent 2 '.permissions.deny -= ["Write(~/.claude/settings.json)"]' "$AUSPEX_REPO/claude/deny.json" >"$AUSPEX/claude/deny.json"
    run "$AUSPEX/bin/auspex-check-permissions"
    [ "$status" -eq 1 ]
    [[ "$output" == *"lacks Write(~/.claude/settings.json)"* ]]
}

@test "check permissions fails when headless settings allow Edit" {
    perm_repo
    jq --indent 2 '.permissions.allow += ["Edit(~/notes/**)"]' "$AUSPEX_REPO/claude/headless-settings.json" >"$AUSPEX/claude/headless-settings.json"
    run "$AUSPEX/bin/auspex-check-permissions"
    [ "$status" -eq 1 ]
    [[ "$output" == *"headless-settings.json allows Edit(~/notes/**)"* ]]
}

@test "check permissions fails when deny.json holds an allow rule" {
    perm_repo
    jq --indent 2 '.permissions.allow = ["Bash(x)"]' "$AUSPEX_REPO/claude/deny.json" >"$AUSPEX/claude/deny.json"
    run "$AUSPEX/bin/auspex-check-permissions"
    [ "$status" -eq 1 ]
    [[ "$output" == *"may hold only permissions.deny"* ]]
}
