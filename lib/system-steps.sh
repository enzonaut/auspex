# shellcheck shell=bash
# Shared helpers for the auspex-system-* commands. Source it after
# lib/common.sh, do not run it.
#
# A step is system/steps/NNN-<name>.sh with check, apply and undo functions.
# A step can declare files that it installs with header lines:
#   # auspex:installs=system/files/<path> /<absolute target>

AUSPEX_STEPS_DIR="$AUSPEX/system/steps"

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

# system_step_check <step>: run check as the user. 0 means applied.
system_step_check() {
    # shellcheck disable=SC1090
    (source "$(system_step_file "$1")" && check) >/dev/null 2>&1 </dev/null
}

# system_step_installs <step>: print "<source> <target>" for each installs line.
system_step_installs() {
    local file line val src tgt n=0
    file="$(system_step_file "$1")"
    while IFS= read -r line || [[ -n "$line" ]]; do
        n=$((n + 1))
        if [[ $n -eq 1 && "$line" == '#!'* ]]; then
            continue
        fi
        [[ "$line" == '#'* ]] || break
        [[ "$line" == '# auspex:installs='* ]] || continue
        val="${line#'# auspex:installs='}"
        read -r src tgt _ <<<"$val"
        [[ "$src" == system/files/* && "/$src/" != */../* ]] || auspex_die "$1: bad installs source '$src'"
        [[ "$tgt" == /* && "$tgt/" != */../* ]] || auspex_die "$1: bad installs target '$tgt'"
        printf '%s %s\n' "$src" "$tgt"
    done <"$file"
}

# system_step_show <step>: print the state, the script and a diff for each
# installed file.
system_step_show() {
    local step="$1" file state src tgt
    file="$(system_step_file "$step")"
    if system_step_check "$step"; then state=applied; else state=pending; fi
    printf '== step %s (%s)\n' "$step" "$state"
    printf -- '-- script system/steps/%s.sh (sha256 %s)\n' "$step" "$(auspex_hash_file "$file")"
    cat -- "$file"
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
}

system_step_guard() {
    if [[ "${AUSPEX_ACTOR:-}" == agent ]]; then
        auspex_die "system $1 refuses to run with AUSPEX_ACTOR=agent; run auspex system prepare" 3
    fi
    if [[ ! -t 0 || ! -t 1 ]]; then
        auspex_die "system $1 refuses to run without a TTY; run it in a terminal" 3
    fi
}

system_step_record() {
    local dir tmp
    dir="$AUSPEX_STATE/system-steps"
    mkdir -p -- "$dir" || return 1
    tmp="$(mktemp "$dir/.$1.XXXXXX")" || return 1
    if jq -n --arg step "$1" --arg action "$2" --arg time "$(date -Iseconds)" \
        --arg hash "$3" --arg result "$4" --arg check "$5" \
        '{step: $step, action: $action, time: $time, script_sha256: $hash,
          result: $result, check: $check, actor: "operator"}' >"$tmp"; then
        mv -f -T -- "$tmp" "$dir/$1.json"
        return
    fi
    rm -f -- "$tmp"
    return 1
}

# system_step_run <apply|undo> [--dry-run] <step>
system_step_run() {
    local action="$1" dry=0 arg="" step file hash answer rc check_state verb
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
    file="$(system_step_file "$step")"
    hash="$(auspex_hash_file "$file")" || auspex_die "cannot read $file"
    system_step_show "$step"
    printf -- '-- run: sudo bash -c <verify sha256, source the step, %s> %s\n' "$action" "$file"
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
    rc=0
    # shellcheck disable=SC2016
    sudo bash -c 'set -o pipefail
h="$(sha256sum <"$1")" || exit 98
[[ "${h%% *}" == "$2" ]] || { echo "auspex: error: the step changed after the prompt" >&2; exit 98; }
source "$1" || exit 97
"$3"' _ "$file" "$hash" "$action" || rc=$?
    if system_step_check "$step"; then check_state=pass; else check_state=fail; fi
    local result=ok
    ((rc == 0)) || result=failed
    system_step_record "$step" "$action" "$hash" "$result" "$check_state" ||
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
