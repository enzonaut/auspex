#!/usr/bin/env bats

load test_helper

setup() {
    auspex_test_setup
    mkdir -p "$TEST_TMP/repo"
    local d
    while IFS= read -r d; do
        cp -a "$AUSPEX_REPO/$d" "$TEST_TMP/repo/"
    done < <(git -C "$AUSPEX_REPO" ls-files | sed -n 's|^\([^/.][^/]*\)/.*|\1|p' | sort -u)
    export AUSPEX="$TEST_TMP/repo"
    export PATH="$FAKES:$AUSPEX/bin:$PATH"
    SKILL="$AUSPEX/agent/skills/auspex"
}

teardown() {
    auspex_test_teardown
}

@test "the skill in the repo passes" {
    run auspex check skill
    [ "$status" -eq 0 ]
    [[ "$output" == *"auspex check skill: ok"* ]]
}

@test "--fix makes no change when the generated files are current" {
    run auspex check skill --fix
    [ "$status" -eq 0 ]
    [[ "$output" != *"wrote"* ]]
}

@test "an unknown argument prints usage and exits 2" {
    run auspex check skill --bogus
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage: auspex check skill"* ]]
}

@test "--print-targets prints 1 row per manifest line" {
    run auspex check skill --print-targets
    [ "$status" -eq 0 ]
    [[ "$output" == *'| `~/.claude/skills/auspex/` | `agent/skills/auspex/` | tree | any |'* ]]
}

@test "rule 1: an out-of-date commands.md fails, and --fix repairs it" {
    echo "stale" >>"$SKILL/reference/commands.md"
    run auspex check skill
    [ "$status" -eq 1 ]
    [[ "$output" == *"reference/commands.md: out of date"* ]]
    run auspex check skill --fix
    [ "$status" -eq 0 ]
    [[ "$output" == *"wrote reference/commands.md"* ]]
    run auspex check skill --fix
    [ "$status" -eq 0 ]
    [[ "$output" != *"wrote"* ]]
}

@test "rule 1: a new command makes commands.md out of date" {
    add_command auspex-zzz-test
    run auspex check skill
    [ "$status" -eq 1 ]
    [[ "$output" == *"reference/commands.md: out of date"* ]]
}

@test "rule 2: a missing targets.md fails" {
    rm "$SKILL/reference/targets.md"
    run auspex check skill
    [ "$status" -eq 1 ]
    [[ "$output" == *"reference/targets.md: missing"* ]]
}

@test "rule 2: a new manifest row makes targets.md out of date" {
    printf 'config/hypr/\t~/.config/hypr/\ttree\thyprland\n' >>"$AUSPEX/manifest/user.tsv"
    run auspex check skill
    [ "$status" -eq 1 ]
    [[ "$output" == *"reference/targets.md: out of date"* ]]
}

@test "rule 3: a top-level folder that layout.md does not name fails" {
    mkdir "$AUSPEX/newfolder"
    run auspex check skill
    [ "$status" -eq 1 ]
    [[ "$output" == *"does not name the folder newfolder/"* ]]
}

@test "rule 3: layout.md that names a folder that does not exist fails" {
    rm -rf "$AUSPEX/themes"
    run auspex check skill
    [ "$status" -eq 1 ]
    [[ "$output" == *"names themes/, which is not a top-level repo folder"* ]]
}

@test "rule 4: a repo path that does not exist fails" {
    echo 'See `config/hypr/nosuch.conf`.' >>"$SKILL/reference/hyprland.md"
    run auspex check skill
    [ "$status" -eq 1 ]
    [[ "$output" == *'reference/hyprland.md: `config/hypr/nosuch.conf` does not exist'* ]]
}

@test "rule 4: paths outside the repo folders and placeholders are skipped" {
    echo 'See `~/.config/x`, `/etc/x`, `reference/x.md` and `system/steps/<n>.sh`.' >>"$SKILL/reference/kde.md"
    run auspex check skill
    [ "$status" -eq 0 ]
}

@test "rule 5: a command that does not route fails" {
    echo 'Run `auspex nosuch thing`.' >>"$SKILL/SKILL.md"
    run auspex check skill
    [ "$status" -eq 1 ]
    [[ "$output" == *'SKILL.md: `auspex nosuch thing` does not route'* ]]
}

@test "rule 5: a command with arguments routes" {
    echo 'Run `auspex check skill --fix` and `auspex help`.' >>"$SKILL/SKILL.md"
    run auspex check skill
    [ "$status" -eq 0 ]
}

@test "rule 6: SKILL.md over 150 lines fails" {
    for _ in $(seq 1 160); do echo "line" >>"$SKILL/SKILL.md"; done
    run auspex check skill
    [ "$status" -eq 1 ]
    [[ "$output" == *"SKILL.md:"*"lines; the limit is 150"* ]]
}

@test "rule 6: front matter without description fails" {
    sed -i '/^description:/d' "$SKILL/SKILL.md"
    run auspex check skill
    [ "$status" -eq 1 ]
    [[ "$output" == *"SKILL.md: front matter lacks description"* ]]
}

@test "rule 6: SKILL.md without front matter fails" {
    sed -i '1d' "$SKILL/SKILL.md"
    run auspex check skill
    [ "$status" -eq 1 ]
    [[ "$output" == *"SKILL.md: no front matter"* ]]
}
