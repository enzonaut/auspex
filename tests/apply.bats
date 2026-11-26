#!/usr/bin/env bats

load test_helper
load fixtures/apply/helper

setup() {
    apply_test_setup
}

teardown() {
    chmod -R u+w "$HOME" 2>/dev/null || true
    auspex_test_teardown
}

@test "plan lists create for each target and changes nothing" {
    run auspex plan
    [ "$status" -eq 0 ]
    [[ "$output" == *"create    ~/.config/app/app.conf"* ]]
    [[ "$output" == *"create    ~/.config/tree/one.txt"* ]]
    [[ "$output" == *"create    ~/.config/tree/sub/two.txt"* ]]
    [[ "$output" == *"create    ~/.config/kv.conf"* ]]
    [ ! -e "$HOME/.config" ]
    [ ! -e "$AUSPEX_STATE/generations" ]
}

@test "apply writes the targets and records generation 1" {
    run auspex apply --reason "first"
    [ "$status" -eq 0 ]
    [[ "$output" == *"generation 1"* ]]
    [ "$(cat "$HOME/.config/app/app.conf")" = "a=1" ]
    [ "$(cat "$HOME/.config/tree/sub/two.txt")" = "two" ]
    [ "$(cat "$HOME/.config/kv.conf")" = "x=1" ]
    [ -f "$(gen 1)/before/.config/app/app.conf.absent" ]
    [ -f "$(gen 1)/before/.config/tree/one.txt.absent" ]
    [ "$(meta 1 .kind)" = apply ]
    [ "$(meta 1 .status)" = ok ]
    [ "$(meta 1 .reason)" = first ]
    [ "$(meta 1 .actor)" = operator ]
    [ "$(meta 1 .commit)" = "$(git -C "$AUSPEX" rev-parse HEAD)" ]
    [ "$(meta 1 '.targets | length')" -eq 4 ]
    (cd "$HOME" && sha256sum -c --quiet "$(gen 1)/after.sha256")
    [ "$(jq -c . "$AUSPEX_STATE/owned/kv.json")" = '["x"]' ]
}

@test "a 2nd apply with no change writes no generation" {
    auspex apply
    run auspex apply
    [ "$status" -eq 0 ]
    [[ "$output" == *"nothing to apply"* ]]
    [ ! -e "$(gen 2)" ]
    run auspex plan
    [[ "$output" == *"unchanged ~/.config/app/app.conf"* ]]
    [[ "$output" == *"unchanged ~/.config/kv.conf"* ]]
}

@test "apply records actor agent when AUSPEX_ACTOR=agent" {
    AUSPEX_ACTOR=agent auspex apply
    [ "$(meta 1 .actor)" = agent ]
}

@test "apply stops on uncommitted changes in a source path" {
    printf 'a=2\n' >"$AUSPEX/config/app/app.conf"
    run auspex apply
    [ "$status" -ne 0 ]
    [[ "$output" == *"uncommitted"* ]]
    [ ! -e "$HOME/.config/app/app.conf" ]
}

@test "plan shows update with a diff, and apply saves the earlier content" {
    auspex apply
    printf 'a=2\n' >"$AUSPEX/config/app/app.conf"
    repo_commit "a=2"
    run auspex plan
    [[ "$output" == *"update    ~/.config/app/app.conf"* ]]
    [[ "$output" == *"-a=1"* ]]
    [[ "$output" == *"+a=2"* ]]
    run auspex apply
    [ "$status" -eq 0 ]
    [[ "$output" == *"generation 2"* ]]
    [ "$(cat "$HOME/.config/app/app.conf")" = "a=2" ]
    [ "$(cat "$(gen 2)/before/.config/app/app.conf")" = "a=1" ]
    [ "$(meta 2 '.targets | length')" -eq 1 ]
}

@test "apply keeps the file mode of an existing target" {
    auspex apply
    chmod 600 "$HOME/.config/app/app.conf"
    printf 'a=2\n' >"$AUSPEX/config/app/app.conf"
    repo_commit "a=2"
    auspex apply
    [ "$(stat -c %a "$HOME/.config/app/app.conf")" = 600 ]
}

@test "apply stops on drift and prints the diff and both ways forward" {
    auspex apply
    printf 'a=live\n' >"$HOME/.config/app/app.conf"
    run auspex apply
    [ "$status" -ne 0 ]
    [[ "$output" == *"drift     ~/.config/app/app.conf"* ]]
    [[ "$output" == *"-a=live"* ]]
    [[ "$output" == *"auspex apply --adopt"* ]]
    [[ "$output" == *"auspex apply --force"* ]]
    [ "$(cat "$HOME/.config/app/app.conf")" = "a=live" ]
    [ ! -e "$(gen 2)" ]
}

@test "a copy target that exists before the 1st apply is drift" {
    mkdir -p "$HOME/.config/app"
    printf 'mine\n' >"$HOME/.config/app/app.conf"
    run auspex apply
    [ "$status" -ne 0 ]
    [[ "$output" == *"drift     ~/.config/app/app.conf"* ]]
    [ "$(cat "$HOME/.config/app/app.conf")" = mine ]
}

@test "apply --force overwrites a drifted target" {
    auspex apply
    printf 'a=live\n' >"$HOME/.config/app/app.conf"
    run auspex apply --force
    [ "$status" -eq 0 ]
    [ "$(cat "$HOME/.config/app/app.conf")" = "a=1" ]
    [ "$(cat "$(gen 2)/before/.config/app/app.conf")" = "a=live" ]
}

@test "apply --adopt copies the live file into the repo source" {
    auspex apply
    printf 'a=live\n' >"$HOME/.config/app/app.conf"
    run auspex apply --adopt "~/.config/app/app.conf"
    [ "$status" -eq 0 ]
    [[ "$output" == *"config/app/app.conf"* ]]
    [ "$(cat "$AUSPEX/config/app/app.conf")" = "a=live" ]
    repo_commit "adopt"
    run auspex plan
    [[ "$output" == *"unchanged ~/.config/app/app.conf"* ]]
    run auspex apply
    [ "$status" -eq 0 ]
    [[ "$output" == *"nothing to apply"* ]]
}

@test "apply --adopt refuses a target that is not managed" {
    run auspex apply --adopt "$HOME/.bashrc"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not a managed target"* ]]
}

@test "apply --dry-run prints the plan and changes nothing" {
    run auspex apply --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"create    ~/.config/app/app.conf"* ]]
    [ ! -e "$HOME/.config" ]
    [ ! -e "$AUSPEX_STATE/generations" ]
}

@test "apply stops when another process holds the lock" {
    exec {fd}>"$AUSPEX_STATE/lock"
    flock -n "$fd"
    run auspex apply
    exec {fd}>&-
    [ "$status" -ne 0 ]
    [[ "$output" == *"lock"* ]]
    [ ! -e "$HOME/.config/app/app.conf" ]
}

@test "tree removes a file that an earlier generation wrote, and keeps other files" {
    auspex apply
    printf 'not managed\n' >"$HOME/.config/tree/extra.txt"
    git -C "$AUSPEX" rm -q config/tree/sub/two.txt
    repo_commit "drop two"
    run auspex plan
    [[ "$output" == *"remove    ~/.config/tree/sub/two.txt"* ]]
    [[ "$output" != *"extra.txt"* ]]
    auspex apply
    [ ! -e "$HOME/.config/tree/sub/two.txt" ]
    [ -f "$HOME/.config/tree/extra.txt" ]
    [ "$(cat "$(gen 2)/before/.config/tree/sub/two.txt")" = two ]
}

@test "undo removes targets of a .absent marker, and a 2nd undo is a redo" {
    auspex apply
    run auspex undo
    [ "$status" -eq 0 ]
    [[ "$output" == *"generation 2"* ]]
    [ ! -e "$HOME/.config/app/app.conf" ]
    [ ! -e "$HOME/.config/tree/one.txt" ]
    [ "$(meta 2 .kind)" = undo ]
    [ "$(meta 2 -c .undoes)" = "[1]" ]
    run auspex undo
    [ "$status" -eq 0 ]
    [ "$(cat "$HOME/.config/app/app.conf")" = "a=1" ]
    [ "$(cat "$HOME/.config/tree/one.txt")" = one ]
    [ "$(meta 3 -c .undoes)" = "[2]" ]
    run auspex plan
    [[ "$output" == *"unchanged ~/.config/app/app.conf"* ]]
}

@test "undo restores the earlier content of an updated target" {
    auspex apply
    printf 'a=2\n' >"$AUSPEX/config/app/app.conf"
    repo_commit "a=2"
    auspex apply
    run auspex undo
    [ "$status" -eq 0 ]
    [ "$(cat "$HOME/.config/app/app.conf")" = "a=1" ]
    [ "$(cat "$HOME/.config/tree/one.txt")" = one ]
}

@test "undo --to restores each target to its state at that generation" {
    auspex apply
    printf 'a=2\n' >"$AUSPEX/config/app/app.conf"
    repo_commit "a=2"
    auspex apply
    printf 'a=3\n' >"$AUSPEX/config/app/app.conf"
    printf 'one-3\n' >"$AUSPEX/config/tree/one.txt"
    repo_commit "a=3"
    auspex apply
    run auspex undo --to 1
    [ "$status" -eq 0 ]
    [ "$(cat "$HOME/.config/app/app.conf")" = "a=1" ]
    [ "$(cat "$HOME/.config/tree/one.txt")" = one ]
    [ "$(meta 4 -c .undoes)" = "[3,2]" ]
    run auspex undo --to 0
    [ "$status" -eq 0 ]
    [ ! -e "$HOME/.config/app/app.conf" ]
    [ ! -e "$HOME/.config/kv.conf" ]
}

@test "undo stops on drift and --force overrides" {
    auspex apply
    printf 'a=live\n' >"$HOME/.config/app/app.conf"
    run auspex undo
    [ "$status" -ne 0 ]
    [[ "$output" == *"drift"* ]]
    [[ "$output" == *"--force"* ]]
    [ "$(cat "$HOME/.config/app/app.conf")" = "a=live" ]
    run auspex undo --force
    [ "$status" -eq 0 ]
    [ ! -e "$HOME/.config/app/app.conf" ]
}

@test "undo --dry-run changes nothing" {
    auspex apply
    run auspex undo --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"~/.config/app/app.conf"* ]]
    [ -f "$HOME/.config/app/app.conf" ]
    [ ! -e "$(gen 2)" ]
}

@test "undo touches only managed targets" {
    auspex apply
    mkdir -p "$HOME/.config/other"
    printf 'keep\n' >"$HOME/.config/other/file"
    printf 'keep\n' >"$HOME/.config/tree/extra.txt"
    auspex undo
    [ "$(cat "$HOME/.config/other/file")" = keep ]
    [ "$(cat "$HOME/.config/tree/extra.txt")" = keep ]
}

@test "a failed write rolls back the written targets and marks the generation failed" {
    auspex apply
    printf 'a=2\n' >"$AUSPEX/config/app/app.conf"
    printf 'one-2\n' >"$AUSPEX/config/tree/one.txt"
    repo_commit "two changes"
    chmod 555 "$HOME/.config/tree"
    run auspex apply
    chmod 755 "$HOME/.config/tree"
    [ "$status" -ne 0 ]
    [ "$(cat "$HOME/.config/app/app.conf")" = "a=1" ]
    [ "$(cat "$HOME/.config/tree/one.txt")" = one ]
    [ "$(meta 2 .status)" = failed ]
    run auspex plan
    [[ "$output" == *"update    ~/.config/app/app.conf"* ]]
    [[ "$output" != *drift* ]]
}

@test "undo skips a failed generation" {
    auspex apply
    printf 'a=2\n' >"$AUSPEX/config/app/app.conf"
    printf 'one-2\n' >"$AUSPEX/config/tree/one.txt"
    repo_commit "two changes"
    chmod 555 "$HOME/.config/tree"
    run auspex apply
    chmod 755 "$HOME/.config/tree"
    run auspex undo
    [ "$status" -eq 0 ]
    [ "$(meta 3 -c .undoes)" = "[1]" ]
    [ ! -e "$HOME/.config/app/app.conf" ]
}

@test "apply keeps the last 50 generations and never reuses a number" {
    local n
    for n in $(seq 1 55); do
        mkdir -p "$(gen "$n")"
        jq -n --argjson n "$n" '{number: $n, kind: "apply", status: "ok", targets: []}' >"$(gen "$n")/meta.json"
    done
    run auspex apply
    [ "$status" -eq 0 ]
    [[ "$output" == *"generation 56"* ]]
    [ "$(find "$AUSPEX_STATE/generations" -mindepth 1 -maxdepth 1 -type d | wc -l)" -eq 50 ]
    [ ! -e "$(gen 6)" ]
    [ -d "$(gen 7)" ]
    rm -rf "$(gen 56)"
    printf 'a=2\n' >"$AUSPEX/config/app/app.conf"
    repo_commit "a=2"
    run auspex apply --force
    [ "$status" -eq 0 ]
    [[ "$output" == *"generation 57"* ]]
}

@test "undo --to stops when a generation it needs was pruned" {
    local n
    for n in $(seq 1 55); do
        mkdir -p "$(gen "$n")"
        jq -n --argjson n "$n" '{number: $n, kind: "apply", status: "ok", targets: []}' >"$(gen "$n")/meta.json"
    done
    auspex apply
    run auspex undo --to 3
    [ "$status" -ne 0 ]
    [[ "$output" == *"pruned"* ]]
}

@test "merge mode keeps entries that auspex does not own" {
    mkdir -p "$HOME/.config"
    printf 'y=other\n' >"$HOME/.config/kv.conf"
    run auspex apply
    [ "$status" -eq 0 ]
    [ "$(sort "$HOME/.config/kv.conf" | tr '\n' ' ')" = "x=1 y=other " ]
    printf 'x=1\ny=changed\n' >"$HOME/.config/kv.conf"
    run auspex plan
    [[ "$output" == *"unchanged ~/.config/kv.conf"* ]]
    printf 'x=9\ny=changed\n' >"$HOME/.config/kv.conf"
    run auspex plan
    [[ "$output" == *"drift     ~/.config/kv.conf"* ]]
}

@test "merge mode removes an owned entry that the source drops, and undo restores it" {
    auspex apply
    printf 'z=1\n' >"$AUSPEX/config/kv/owned.kv"
    repo_commit "x to z"
    auspex apply
    [ "$(cat "$HOME/.config/kv.conf")" = "z=1" ]
    [ "$(jq -c . "$AUSPEX_STATE/owned/kv.json")" = '["z"]' ]
    auspex undo
    [ "$(cat "$HOME/.config/kv.conf")" = "x=1" ]
    [ "$(jq -c . "$AUSPEX_STATE/owned/kv.json")" = '["x"]' ]
}

@test "apply --adopt refuses a merge-mode target" {
    auspex apply
    run auspex apply --adopt "~/.config/kv.conf"
    [ "$status" -ne 0 ]
    [[ "$output" == *"merge"* ]]
}

@test "apply tries a home snapshot before the write and continues when it fails" {
    run auspex apply
    [ "$status" -eq 0 ]
    [ "$(fake_calls snapper)" = "-c home create --description auspex gen 1" ]
    [[ "$output" == *"snapper"* ]]
    [ -f "$HOME/.config/app/app.conf" ]
}

@test "status prints the commit, the last generation, pending items and drift" {
    mkdir -p "$AUSPEX/system/steps" "$AUSPEX/migrations"
    printf 'check() { return 1; }\n' >"$AUSPEX/system/steps/900-fake.sh"
    printf 'check() { return 0; }\n' >"$AUSPEX/system/steps/910-done.sh"
    printf 'true\n' >"$AUSPEX/migrations/1700000000-later.sh"
    repo_commit "status fixtures"
    auspex migrate
    auspex apply
    printf 'true\n' >"$AUSPEX/migrations/1800000000-pending.sh"
    repo_commit "pending migration"
    printf 'a=live\n' >"$HOME/.config/app/app.conf"
    run auspex status
    [ "$status" -eq 0 ]
    [[ "$output" == *"$(git -C "$AUSPEX" rev-parse --short HEAD)"* ]]
    [[ "$output" == *"generation 1"* ]]
    [[ "$output" == *"1800000000-pending.sh"* ]]
    [[ "$output" != *"1700000000-later.sh"* ]]
    [[ "$output" == *"900-fake"* ]]
    [[ "$output" != *"910-done"* ]]
    [[ "$output" == *"~/.config/app/app.conf"* ]]
}

render_setup() {
    mkdir -p "$AUSPEX/themes/t1" "$AUSPEX/templates"
    printf 't1\n' >"$AUSPEX/themes/current"
    printf 'accent = "#EB6A43"\nfont = "Jost"\n' >"$AUSPEX/themes/t1/colors.toml"
    printf 'color={{ accent }}\nfont={{ font }}\n' >"$AUSPEX/templates/a.tpl"
    printf 'rgba({{ accent | dec }})\n' >"$AUSPEX/templates/b.tpl"
    printf 'templates/a.tpl\t~/.config/r/a.conf\trender\tany\n' >>"$AUSPEX/manifest/user.tsv"
    printf 'templates/b.tpl\t~/.config/r/b.css\trender\tany\n' >>"$AUSPEX/manifest/user.tsv"
    repo_commit "render rows"
}

@test "apply writes a render target with the palette values" {
    render_setup
    run auspex plan
    [ "$status" -eq 0 ]
    [[ "$output" == *"create    ~/.config/r/a.conf"* ]]
    run auspex apply
    [ "$status" -eq 0 ]
    [ "$(cat "$HOME/.config/r/a.conf")" = $'color=#EB6A43\nfont=Jost' ]
    [ "$(cat "$HOME/.config/r/b.css")" = "rgba(235, 106, 67)" ]
    [ "$(meta 1 '[.targets[] | select(.mode == "render")] | length')" -eq 2 ]
    run auspex status
    [ "$status" -eq 0 ]
    run auspex apply
    [[ "$output" == *"nothing to apply"* ]]
}

@test "a palette edit changes all render targets in 1 generation, and 1 undo restores them" {
    render_setup
    auspex apply
    printf 'accent = "#000000"\nfont = "Jost"\n' >"$AUSPEX/themes/t1/colors.toml"
    run auspex apply
    [ "$status" -ne 0 ]
    [[ "$output" == *"uncommitted"* ]]
    repo_commit "palette"
    run auspex apply
    [ "$status" -eq 0 ]
    [[ "$output" == *"generation 2"* ]]
    [ "$(cat "$HOME/.config/r/b.css")" = "rgba(0, 0, 0)" ]
    [[ "$(cat "$HOME/.config/r/a.conf")" == *"#000000"* ]]
    [ "$(meta 2 '.targets | length')" -eq 2 ]
    run auspex undo
    [ "$status" -eq 0 ]
    [ "$(cat "$HOME/.config/r/b.css")" = "rgba(235, 106, 67)" ]
    [[ "$(cat "$HOME/.config/r/a.conf")" == *"#EB6A43"* ]]
}

@test "copy to render with the same file is not drift and updates the index mode" {
    auspex apply
    mkdir -p "$AUSPEX/themes/t1"
    printf 't1\n' >"$AUSPEX/themes/current"
    printf 'a = "1"\n' >"$AUSPEX/themes/t1/colors.toml"
    printf 'a={{ a }}\n' >"$AUSPEX/config/app/app.conf"
    sed -i 's|^config/app/app.conf\t\(.*\)\tcopy\t|config/app/app.conf\t\1\trender\t|' "$AUSPEX/manifest/user.tsv"
    grep -q 'app.conf.*render' "$AUSPEX/manifest/user.tsv"
    repo_commit "copy to render"
    run auspex plan
    [ "$status" -eq 0 ]
    [[ "$output" == *"unchanged ~/.config/app/app.conf"* ]]
    run auspex apply
    [ "$status" -eq 0 ]
    [[ "$output" == *"nothing to apply"* ]]
    [ ! -e "$(gen 2)" ]
    grep -q $'\trender\t.config/app/app.conf$' "$AUSPEX_STATE/targets.tsv"
}

@test "apply --adopt refuses a render target" {
    render_setup
    auspex apply
    run auspex apply --adopt "~/.config/r/a.conf"
    [ "$status" -ne 0 ]
    [[ "$output" == *"render"* ]]
    [[ "$output" == *"--force"* ]]
    [ "$(cat "$AUSPEX/templates/a.tpl")" = $'color={{ accent }}\nfont={{ font }}' ]
}

@test "apply stops on a bad themes/current or a bad template and writes nothing" {
    render_setup
    printf 'nope\n' >"$AUSPEX/themes/current"
    repo_commit "bad theme"
    run auspex apply
    [ "$status" -ne 0 ]
    [[ "$output" == *"themes/current"* ]]
    [ ! -e "$HOME/.config/r" ]
    printf 't1\n' >"$AUSPEX/themes/current"
    printf 'x={{ missing }}\n' >"$AUSPEX/templates/b.tpl"
    repo_commit "bad template"
    run auspex apply
    [ "$status" -ne 0 ]
    [[ "$output" == *"templates/b.tpl:1: unknown key missing"* ]]
    [[ "$output" == *"cannot render templates/b.tpl"* ]]
    [ ! -e "$HOME/.config/r" ]
    [ ! -e "$(gen 1)" ]
}
