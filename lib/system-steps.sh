# shellcheck shell=bash
# Shared helpers for the auspex-system-* commands. Source it after
# lib/common.sh, do not run it.
#
# A step is system/steps/NNN-<name>.sh with check, apply and undo functions.
# Header lines are the comment lines at the top of the step:
#   # auspex:installs=system/files/<path> /<absolute target>
#   # auspex:reads=<repo path>[ <repo path> ...]
# A reads line names each repo file that the step reads, relative to the
# repo, for example packages/auspex-tools.list. A step can have more than
# 1 reads line. The order of the paths is the header order.
#
# Variables that a step can use:
#   AUSPEX_REPO       the repo root.
#   AUSPEX_STEP_DIR   $AUSPEX_REPO/system/steps.
#   AUSPEX_READS_DIR  as root: the mktemp -d dir with the approved copy of
#                     each reads file. Unset in check and in a direct run.
# A step reads a declared file at "${AUSPEX_READS_DIR:-$AUSPEX_REPO}/<path>".
# A step sets AUSPEX_STEP_DIR and AUSPEX_REPO itself when they are empty,
# so that "bash NNN-<name>.sh check" works. As root, a step must not read
# other files through AUSPEX_REPO or AUSPEX_STEP_DIR.
#
# Limits: each part is smaller than 128 KiB (the argument size limit), and
# a part with a NUL byte is refused (a bash variable cannot hold NUL).

AUSPEX_STEPS_DIR="$AUSPEX/system/steps"
SYSTEM_STEP_MAX_BYTES=131000

SYSTEM_STEP_NAMES=()
SYSTEM_STEP_PARTS=()
SYSTEM_STEP_DIGEST=""

# system_step_resolve <name or NNN>: print the step name, or stop.
system_step_resolve() {
    local arg="${1:-}" f
    local -a found=()
    if [[ "$arg" =~ ^[0-9]{3}$ ]]; then
        for f in "$AUSPEX_STEPS_DIR/$arg"-*.sh; do
            [[ -f "$f" && ! -L "$f" ]] && found+=("$f")
        done
        [[ ${#found[@]} -eq 1 ]] || auspex_die "step $arg: expected 1 match in system/steps, found ${#found[@]}" 2
        f="${found[0]##*/}"
        printf '%s\n' "${f%.sh}"
        return 0
    fi
    [[ "$arg" =~ ^[0-9]{3}-[a-z0-9][a-z0-9-]*$ ]] || auspex_die "bad step name '$arg'; use NNN or NNN-<name>" 2
    [[ -f "$AUSPEX_STEPS_DIR/$arg.sh" && ! -L "$AUSPEX_STEPS_DIR/$arg.sh" ]] ||
        auspex_die "no step system/steps/$arg.sh" 2
    printf '%s\n' "$arg"
}

system_step_file() {
    printf '%s/%s.sh\n' "$AUSPEX_STEPS_DIR" "$1"
}

# system_step_list: print the name of each step, in number order.
system_step_list() {
    [[ -d "$AUSPEX_STEPS_DIR" ]] || return 0
    find "$AUSPEX_STEPS_DIR" -mindepth 1 -maxdepth 1 -type f -name '[0-9][0-9][0-9]-*.sh' -printf '%f\n' |
        LC_ALL=C sort | sed 's/\.sh$//'
}

# system_step_read <file>: read the file 1 time into REPLY, byte for byte.
# Fails on a symlink, a NUL byte or a file that is too large.
system_step_read() {
    local path="$1" size n
    REPLY=""
    [[ -f "$path" && ! -L "$path" ]] || return 1
    { IFS= read -r -d '' REPLY || true; } <"$path" || return 1
    size="$(stat -c %s -- "$path")" || return 1
    n="$(LC_ALL=C && printf '%s' "${#REPLY}")"
    [[ "$n" == "$size" ]] || return 1
    ((n <= SYSTEM_STEP_MAX_BYTES))
}

# system_step_headers <text> <key>: print the value of each header line
# "# auspex:<key>=" in the step text.
system_step_headers() {
    local text="$1" key="$2" line n=0
    while IFS= read -r line; do
        n=$((n + 1))
        if [[ $n -eq 1 && "$line" == '#!'* ]]; then
            continue
        fi
        [[ "$line" == '#'* ]] || break
        if [[ "$line" == "# auspex:$key="* ]]; then
            printf '%s\n' "${line#"# auspex:$key="}"
        fi
    done <<<"$text"
}

# system_step_reads <step> <text>: print each reads path, 1 per line.
system_step_reads() {
    local val p
    local -a paths
    while IFS= read -r val; do
        read -r -a paths <<<"$val"
        for p in "${paths[@]}"; do
            [[ "$p" =~ ^[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*$ && "/$p/" != */../* && "/$p/" != */./* ]] ||
                auspex_die "$1: bad reads path '$p'"
            printf '%s\n' "$p"
        done
    done < <(system_step_headers "$2" reads)
}

# system_step_digest <name> <bytes> [<name> <bytes> ...]: print the
# approval digest. The root shell runs a copy of this function.
system_step_digest() {
    local h m=""
    while (($# >= 2)); do
        h="$(printf '%s' "$2" | sha256sum)" || return 1
        m+="${h%% *}  $1"$'\n'
        shift 2
    done
    h="$(printf '%s' "$m" | sha256sum)" || return 1
    printf '%s\n' "${h%% *}"
}

# step_install_verified <sums> <repo dir> <dest dir>: install the binary
# files that a SHA256SUMS file lists. The root shell runs a copy of this
# function.
#   <sums>      the repo path of a SHA256SUMS file that the step declares in
#               a reads line, for example system/files/avgvr/SHA256SUMS. The
#               function reads the approved copy in AUSPEX_READS_DIR (as
#               root) or the repo copy (in a direct run).
#   <repo dir>  a repo dir at or under the dir of <sums>, for example
#               system/files/avgvr/fonts. Only the lines of <sums> under it
#               are installed.
#   <dest dir>  the target dir. <repo dir>/a/b goes to <dest dir>/a/b.
# Each line is "<sha256>  <path relative to the dir of <sums>>". The
# function copies each listed file into a new mktemp -d dir and checks its
# sha256. Only when every file matches does it run install -D -m 644 for
# each, and print each installed target path, 1 per line. On a bad line, a
# missing file, a symlink, a hash mismatch or no matching line it installs
# nothing and returns 1. It never reads a file that <sums> does not list.
step_install_verified() {
    local sums="$1" src="${2%/}" dest="${3%/}" top prefix list tmp line want path rel got rc=0
    local -a rels=()
    [[ -n "$sums" && -n "$src" && -n "$dest" ]] || return 1
    top="$(dirname -- "$sums")"
    case "$src" in
        "$top") prefix="" ;;
        "$top"/*) prefix="${src#"$top"/}/" ;;
        *)
            echo "step_install_verified: $src is not under $top" >&2
            return 1
            ;;
    esac
    list="${AUSPEX_READS_DIR:-${AUSPEX_REPO:?}}/$sums"
    [[ -f "$list" && ! -L "$list" ]] || {
        echo "step_install_verified: cannot read $sums" >&2
        return 1
    }
    tmp="$(mktemp -d)" || return 1
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -n "$line" ]] || continue
        if [[ ! "$line" =~ ^([0-9a-f]{64})\ \ ([A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*)$ ]]; then
            echo "step_install_verified: bad line in $sums: $line" >&2
            rc=1
            break
        fi
        want="${BASH_REMATCH[1]}" path="${BASH_REMATCH[2]}"
        if [[ "/$path/" == */../* || "/$path/" == */./* ]]; then
            echo "step_install_verified: bad path in $sums: $path" >&2
            rc=1
            break
        fi
        [[ "$path" == "$prefix"* ]] || continue
        rel="${path#"$prefix"}"
        if [[ ! -f "$AUSPEX_REPO/$top/$path" || -L "$AUSPEX_REPO/$top/$path" ]] ||
            ! mkdir -p -- "$tmp/$(dirname -- "$rel")" ||
            ! cp -- "$AUSPEX_REPO/$top/$path" "$tmp/$rel"; then
            echo "step_install_verified: cannot copy $top/$path" >&2
            rc=1
            break
        fi
        got="$(sha256sum -- "$tmp/$rel")" || got=""
        if [[ "${got%% *}" != "$want" ]]; then
            echo "step_install_verified: hash mismatch: $top/$path" >&2
            rc=1
            break
        fi
        rels+=("$rel")
    done <"$list"
    if ((rc == 0 && ${#rels[@]} == 0)); then
        echo "step_install_verified: $sums lists no file under $src" >&2
        rc=1
    fi
    if ((rc == 0)); then
        for rel in "${rels[@]}"; do
            install -D -m 644 -- "$tmp/$rel" "$dest/$rel" || {
                rc=1
                break
            }
            printf '%s\n' "$dest/$rel"
        done
    fi
    rm -rf -- "$tmp"
    return "$rc"
}

# system_step_load <step>: read the step and its reads files 1 time, and
# set SYSTEM_STEP_NAMES, SYSTEM_STEP_PARTS and SYSTEM_STEP_DIGEST.
system_step_load() {
    local step="$1" reads p i
    local -a args=()
    SYSTEM_STEP_NAMES=("system/steps/$step.sh")
    SYSTEM_STEP_PARTS=()
    system_step_read "$(system_step_file "$step")" ||
        auspex_die "cannot read system/steps/$step.sh (missing, a symlink, a NUL byte, changed or over $SYSTEM_STEP_MAX_BYTES bytes)"
    SYSTEM_STEP_PARTS+=("$REPLY")
    reads="$(system_step_reads "$step" "${SYSTEM_STEP_PARTS[0]}")" || exit
    while IFS= read -r p; do
        [[ -n "$p" ]] || continue
        system_step_read "$AUSPEX/$p" ||
            auspex_die "$step: cannot read $p (missing, a symlink, a NUL byte, changed or over $SYSTEM_STEP_MAX_BYTES bytes)"
        SYSTEM_STEP_NAMES+=("$p")
        SYSTEM_STEP_PARTS+=("$REPLY")
    done <<<"$reads"
    for i in "${!SYSTEM_STEP_NAMES[@]}"; do
        args+=("${SYSTEM_STEP_NAMES[i]}" "${SYSTEM_STEP_PARTS[i]}")
    done
    SYSTEM_STEP_DIGEST="$(system_step_digest "${args[@]}")" || auspex_die "cannot hash step $step"
}

# system_step_check: run check of the loaded step as the user. 0 means
# applied.
system_step_check() {
    # shellcheck disable=SC2034 # The step text reads AUSPEX_REPO and AUSPEX_STEP_DIR.
    (
        AUSPEX_REPO="$AUSPEX"
        AUSPEX_STEP_DIR="$AUSPEX_STEPS_DIR"
        unset AUSPEX_READS_DIR
        eval "${SYSTEM_STEP_PARTS[0]}" && check
    ) >/dev/null 2>&1 </dev/null
}

# system_step_installs <step>: print "<source> <target>" for each installs
# line of the loaded step.
system_step_installs() {
    local val src tgt
    while IFS= read -r val; do
        read -r src tgt _ <<<"$val"
        [[ "$src" == system/files/* && "/$src/" != */../* ]] || auspex_die "$1: bad installs source '$src'"
        [[ "$tgt" == /* && "$tgt/" != */../* ]] || auspex_die "$1: bad installs target '$tgt'"
        printf '%s %s\n' "$src" "$tgt"
    done < <(system_step_headers "${SYSTEM_STEP_PARTS[0]}" installs)
}

# system_step_show <step>: print the state, the script, each reads file, a
# diff for each installed file and the approval digest of the loaded step.
system_step_show() {
    local step="$1" state src tgt i kind part
    if system_step_check; then state=applied; else state=pending; fi
    printf '== step %s (%s)\n' "$step" "$state"
    for i in "${!SYSTEM_STEP_NAMES[@]}"; do
        kind=reads
        ((i == 0)) && kind=script
        part="${SYSTEM_STEP_PARTS[i]}"
        printf -- '-- %s %s (sha256 %s)\n' "$kind" "${SYSTEM_STEP_NAMES[i]}" "$(auspex_hash_string "$part")"
        printf '%s' "$part"
        [[ -z "$part" || "$part" == *$'\n' ]] || printf '\n'
    done
    while read -r src tgt; do
        [[ -n "$src" ]] || continue
        printf -- '-- file %s -> %s\n' "$src" "$tgt"
        if [[ ! -f "$AUSPEX/$src" ]]; then
            printf 'the source %s is missing\n' "$src"
        elif [[ ! -e "$tgt" ]]; then
            printf 'the target is missing; the step creates it\n'
            diff -u --label "$tgt (live)" --label "$tgt (new)" -- /dev/null "$AUSPEX/$src" || true
        else
            diff -u --label "$tgt (live)" --label "$tgt (new)" -- "$tgt" "$AUSPEX/$src" || true
        fi
    done < <(system_step_installs "$step")
    printf -- '-- approval sha256 %s\n' "$SYSTEM_STEP_DIGEST"
}

system_step_guard() {
    if [[ "${AUSPEX_ACTOR:-}" == agent ]]; then
        auspex_die "system $1 refuses to run with AUSPEX_ACTOR=agent; run auspex system prepare" 3
    fi
    if [[ ! -t 0 || ! -t 1 ]]; then
        auspex_die "system $1 refuses to run without a TTY; run it in a terminal" 3
    fi
}

# system_step_record <step> <action> <script sha256> <approval sha256>
# <result> <check>
system_step_record() {
    local dir tmp
    dir="$AUSPEX_STATE/system-steps"
    mkdir -p -- "$dir" || return 1
    tmp="$(mktemp "$dir/.$1.XXXXXX")" || return 1
    if jq -n --arg step "$1" --arg action "$2" --arg time "$(date -Iseconds)" \
        --arg hash "$3" --arg digest "$4" --arg result "$5" --arg check "$6" \
        '{step: $step, action: $action, time: $time, script_sha256: $hash,
          approval_sha256: $digest, result: $result, check: $check,
          actor: "operator"}' >"$tmp"; then
        mv -f -T -- "$tmp" "$dir/$1.json"
        return
    fi
    rm -f -- "$tmp"
    return 1
}

# The root shell. Arguments: <approval digest> <action> <repo> then
# <name> <bytes> for the step and for each reads file.
IFS= read -r -d '' SYSTEM_STEP_ROOT_SHELL <<'EOF' || true
set -o pipefail
_auspex_want=$1 _auspex_action=$2 _auspex_repo=$3
shift 3
[[ "$(system_step_digest "$@")" == "$_auspex_want" ]] || {
    echo "auspex: error: the step changed after the prompt" >&2
    exit 98
}
_auspex_text=$2
shift 2
_auspex_dir="$(mktemp -d)" || exit 97
trap 'rm -rf -- "$_auspex_dir"' EXIT
while (($# >= 2)); do
    [[ "$1" =~ ^[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*$ && "/$1/" != */../* ]] || exit 97
    mkdir -p -- "$_auspex_dir/$(dirname -- "$1")" || exit 97
    printf '%s' "$2" >"$_auspex_dir/$1" || exit 97
    shift 2
done
AUSPEX_REPO=$_auspex_repo
AUSPEX_STEP_DIR=$_auspex_repo/system/steps
AUSPEX_READS_DIR=$_auspex_dir
eval "$_auspex_text" || exit 97
"$_auspex_action"
EOF

# system_step_run <apply|undo> [--dry-run] <step>
system_step_run() {
    local action="$1" dry=0 arg="" step hash answer rc check_state verb i
    local -a args=()
    shift
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run) dry=1 ;;
            -*) auspex_die "unknown option $1" 2 ;;
            *)
                [[ -z "$arg" ]] || auspex_die "give 1 step" 2
                arg="$1"
                ;;
        esac
        shift
    done
    [[ -n "$arg" ]] || auspex_die "usage: auspex system $action [--dry-run] <step>" 2
    system_step_guard "$action"
    step="$(system_step_resolve "$arg")"
    system_step_load "$step"
    hash="$(auspex_hash_string "${SYSTEM_STEP_PARTS[0]}")" || auspex_die "cannot hash step $step"
    system_step_installs "$step" >/dev/null
    system_step_show "$step"
    printf -- '-- run: sudo bash -c <verify the approval sha256, eval the text above, %s>\n' "$action"
    if ((dry)); then
        printf 'dry run: nothing changed\n'
        return 0
    fi
    auspex_lock
    verb="${action^}"
    printf '%s step %s? [y/N] ' "$verb" "$step"
    read -r answer || answer=""
    if [[ "$answer" != y && "$answer" != Y ]]; then
        printf 'not changed\n'
        return 1
    fi
    for i in "${!SYSTEM_STEP_NAMES[@]}"; do
        args+=("${SYSTEM_STEP_NAMES[i]}" "${SYSTEM_STEP_PARTS[i]}")
    done
    rc=0
    sudo bash -c "$(declare -f system_step_digest step_install_verified)"$'\n'"$SYSTEM_STEP_ROOT_SHELL" \
        _ "$SYSTEM_STEP_DIGEST" "$action" "$AUSPEX" "${args[@]}" || rc=$?
    if system_step_check; then check_state=pass; else check_state=fail; fi
    local result=ok
    ((rc == 0)) || result=failed
    system_step_record "$step" "$action" "$hash" "$SYSTEM_STEP_DIGEST" "$result" "$check_state" ||
        auspex_warn "cannot write $AUSPEX_STATE/system-steps/$step.json"
    if ((rc != 0)); then
        auspex_die "step $step $action failed (exit $rc)"
    fi
    auspex_run_hooks post-system-step "$step"
    if [[ "$action" == apply && "$check_state" != pass ]]; then
        auspex_die "step $step applied, but its check still fails"
    fi
    printf 'step %s %s: ok, check %s\n' "$step" "$action" "$check_state"
}
