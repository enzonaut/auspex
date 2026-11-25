# Shared setup for tests/apply.bats, tests/migrate.bats and tests/hooks.bats.
# Load it after test_helper with: load fixtures/apply/helper
#
# apply_test_setup gives each test a repo copy in $AUSPEX with the fixture
# manifest, sources and the kv merger, as 1 git commit. Every program that
# apply or a hook can call outside the repo is a fake on PATH.

export GIT_AUTHOR_NAME=auspex-test GIT_AUTHOR_EMAIL=test@example.invalid
export GIT_COMMITTER_NAME=auspex-test GIT_COMMITTER_EMAIL=test@example.invalid

apply_test_setup() {
    auspex_test_setup
    make_repo_copy
    cp -a "$AUSPEX_REPO/tests/fixtures/apply/repo/." "$AUSPEX/"
    mkdir -p "$AUSPEX/migrations" "$AUSPEX/hooks/post-apply.d" \
        "$AUSPEX/hooks/post-undo.d" "$AUSPEX/hooks/post-system-step.d"
    make_fake snapper 'exit 1'
    make_fake hyprctl
    make_fake systemctl
    make_fake makoctl
    make_fake pgrep 'exit 1'
    unset HYPRLAND_INSTANCE_SIGNATURE
    git -C "$AUSPEX" init -q -b main
    repo_commit "fixture"
}

# repo_commit <message>: commit every change in the repo copy.
repo_commit() {
    git -C "$AUSPEX" add -A
    git -C "$AUSPEX" commit -q -m "$1"
}

# gen <n>: the folder of generation <n>.
gen() {
    printf '%s/generations/%04d\n' "$AUSPEX_STATE" "$1"
}

# meta <n> <jq filter>: read a field of generation <n>.
meta() {
    local g
    g="$(gen "$1")"
    shift
    jq -r "$@" "$g/meta.json"
}
