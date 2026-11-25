# shellcheck shell=bash
# Shared helpers for bin/auspex-* commands. Source it, do not run it:
#   source "${AUSPEX:-$(dirname "$(readlink -f "$0")")/..}/lib/common.sh"

if [[ -n "${AUSPEX_COMMON_LOADED:-}" ]]; then
    return 0
fi
AUSPEX_COMMON_LOADED=1

# Paths. AUSPEX is the repo. It defaults to 1 level above this lib/ folder,
# resolved through symlinks. AUSPEX_STATE overrides ~/.local/state/auspex.
if [[ -z "${AUSPEX:-}" ]]; then
    AUSPEX="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd -P)"
fi
export AUSPEX
export AUSPEX_STATE="${AUSPEX_STATE:-$HOME/.local/state/auspex}"
AUSPEX_BIN="$AUSPEX/bin"
AUSPEX_MANIFEST="$AUSPEX/manifest/user.tsv"

# Logging. All log output goes to stderr, so stdout stays for data.
auspex_log() {
    printf 'auspex: %s\n' "$*" >&2
}

auspex_warn() {
    printf 'auspex: warning: %s\n' "$*" >&2
}

# auspex_die <message> [<exit code>]
auspex_die() {
    printf 'auspex: error: %s\n' "$1" >&2
    exit "${2:-1}"
}

# Lock. auspex_lock takes $AUSPEX_STATE/lock without waiting and holds it
# until the process exits. It stops the command if another process holds it.
auspex_lock() {
    mkdir -p "$AUSPEX_STATE" || auspex_die "cannot make $AUSPEX_STATE"
    exec {AUSPEX_LOCK_FD}>"$AUSPEX_STATE/lock" || auspex_die "cannot open $AUSPEX_STATE/lock"
    if ! flock -n "$AUSPEX_LOCK_FD"; then
        auspex_die "another apply or undo holds $AUSPEX_STATE/lock"
    fi
}

# Hashes. sha256 hex digest only.
auspex_hash_file() {
    local out
    out="$(sha256sum -- "$1")" || return 1
    printf '%s\n' "${out%% *}"
}

auspex_hash_string() {
    local out
    out="$(printf '%s' "$1" | sha256sum)" || return 1
    printf '%s\n' "${out%% *}"
}

# Command headers. auspex_header <file> <key> prints the value of
# "# auspex:<key>=<value>" from the comment block at the top of <file>.
# It returns 1 when the key is not there.
auspex_header() {
    local file="$1" key="$2" line n=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        n=$((n + 1))
        if [[ $n -eq 1 && "$line" == '#!'* ]]; then
            continue
        fi
        [[ "$line" == '#'* ]] || break
        if [[ "$line" == "# auspex:$key="* ]]; then
            printf '%s\n' "${line#"# auspex:$key="}"
            return 0
        fi
    done <"$file"
    return 1
}

# auspex_command_words <file name>: the words that route to a command.
# auspex-system-apply -> "system apply".
auspex_command_words() {
    local name="${1##*/}"
    name="${name#auspex-}"
    printf '%s\n' "${name//-/ }"
}
