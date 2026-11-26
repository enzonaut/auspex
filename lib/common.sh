# shellcheck shell=bash
# shellcheck disable=SC2088
# Shared helpers for bin/auspex-* commands. Source it, do not run it:
#   source "${AUSPEX:-$(dirname "$(readlink -f "$0")")/..}/lib/common.sh"

if [[ -n "${AUSPEX_COMMON_LOADED:-}" ]]; then
    return 0
fi
AUSPEX_COMMON_LOADED=1

if [[ -z "${AUSPEX:-}" ]]; then
    AUSPEX="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd -P)"
fi
export AUSPEX
export AUSPEX_STATE="${AUSPEX_STATE:-$HOME/.local/state/auspex}"
# shellcheck disable=SC2034
AUSPEX_BIN="$AUSPEX/bin"
# shellcheck disable=SC2034
AUSPEX_MANIFEST="$AUSPEX/manifest/user.tsv"
# shellcheck source-path=SCRIPTDIR source=render.sh
source "$AUSPEX/lib/render.sh"

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

auspex_rel_path() {
    local rel="$1"
    if [[ "$rel" == '~/'* ]]; then
        rel="${rel#\~/}"
    elif [[ "$rel" == "$HOME/"* ]]; then
        rel="${rel#"$HOME/"}"
    fi
    rel="${rel%/}"
    if [[ -z "$rel" || "$rel" == /* || "/$rel/" == */../* || "/$rel/" == */./* ]]; then
        return 1
    fi
    printf '%s\n' "$rel"
}

auspex_work_init() {
    AUSPEX_WORK="$(mktemp -d "${TMPDIR:-/tmp}/auspex.XXXXXX")" || auspex_die "cannot make a temp folder"
    # shellcheck disable=SC2064
    trap "rm -rf -- '$AUSPEX_WORK'" EXIT
}

auspex_atomic_write() {
    local src="$1" dst="$2" ref="${3:-}" dir tmp
    dir="$(dirname -- "$dst")"
    mkdir -p -- "$dir" || return 1
    tmp="$(mktemp "$dir/.auspex.XXXXXX")" || return 1
    if [[ -e "$dst" ]]; then
        ref="$dst"
    elif [[ -z "$ref" || ! -e "$ref" ]]; then
        ref="$src"
    fi
    if cp -- "$src" "$tmp" && chmod --reference="$ref" -- "$tmp" && mv -f -T -- "$tmp" "$dst"; then
        return 0
    fi
    rm -f -- "$tmp"
    return 1
}

# auspex_theme_palette prints the palette path of the theme in themes/current.
auspex_theme_palette() {
    local name
    [[ -f "$AUSPEX/themes/current" ]] || auspex_die "no themes/current"
    name="$(head -n 1 -- "$AUSPEX/themes/current")"
    [[ "$name" =~ ^[a-z0-9_-]+$ && -d "$AUSPEX/themes/$name" ]] ||
        auspex_die "themes/current names $name, which is not a folder in themes/"
    [[ -f "$AUSPEX/themes/$name/colors.toml" ]] || auspex_die "no palette themes/$name/colors.toml"
    printf '%s\n' "themes/$name/colors.toml"
}

# auspex_manifest_load fills M_SRC (the repo source), M_FILE (the file with the
# new content: the rendered file for a render row, else $AUSPEX/<source>),
# M_REL, M_MODE and M_PATHS (the repo paths that git_check covers).
auspex_manifest_load() {
    local src tgt mode rel f name n=0 palette=""
    local -A seen=() mergers=()
    M_SRC=() M_FILE=() M_REL=() M_MODE=() M_PATHS=()
    [[ -f "$AUSPEX_MANIFEST" ]] || auspex_die "no manifest at $AUSPEX_MANIFEST"
    while read -r src tgt mode _ || [[ -n "${src:-}" ]]; do
        n=$((n + 1))
        [[ -z "${src:-}" || "$src" == '#'* ]] && continue
        [[ -n "${tgt:-}" && -n "${mode:-}" ]] || auspex_die "manifest line $n: needs source, target and mode"
        [[ "$tgt" == '~/'* ]] || auspex_die "manifest line $n: target must start with ~/"
        rel="$(auspex_rel_path "$tgt")" || auspex_die "manifest line $n: bad target $tgt"
        [[ "/$src/" != */../* && "$src" != /* ]] || auspex_die "manifest line $n: bad source $src"
        src="${src%/}"
        M_PATHS+=("$src")
        case "$mode" in
            copy)
                [[ -f "$AUSPEX/$src" ]] || auspex_die "manifest line $n: no source file $src"
                M_SRC+=("$src") M_FILE+=("$AUSPEX/$src") M_REL+=("$rel") M_MODE+=(copy)
                ;;
            render)
                [[ -f "$AUSPEX/$src" ]] || auspex_die "manifest line $n: no source file $src"
                if [[ -z "$palette" ]]; then
                    palette="$(auspex_theme_palette)" || exit 1
                    M_PATHS+=(themes/current "$palette")
                fi
                f="$AUSPEX_STATE/rendered/$rel"
                auspex_render "$AUSPEX/$palette" "$AUSPEX/$src" "$f" ||
                    auspex_die "manifest line $n: cannot render $src"
                M_SRC+=("$src") M_FILE+=("$f") M_REL+=("$rel") M_MODE+=(render)
                ;;
            tree)
                [[ -d "$AUSPEX/$src" ]] || auspex_die "manifest line $n: no source folder $src"
                while IFS= read -r f; do
                    M_SRC+=("$src/$f") M_FILE+=("$AUSPEX/$src/$f") M_REL+=("$rel/$f") M_MODE+=(tree)
                done < <(find "$AUSPEX/$src" -type f -printf '%P\n' | LC_ALL=C sort)
                ;;
            merge:*)
                name="${mode#merge:}"
                [[ "$name" =~ ^[a-z0-9_-]+$ ]] || auspex_die "manifest line $n: bad merger name $name"
                [[ -x "$AUSPEX/lib/merge/$name" ]] || auspex_die "manifest line $n: no merger lib/merge/$name"
                [[ -z "${mergers[$name]:-}" ]] || auspex_die "manifest line $n: merger $name is on 2 rows"
                [[ -f "$AUSPEX/$src" ]] || auspex_die "manifest line $n: no source file $src"
                mergers[$name]=1
                M_SRC+=("$src") M_FILE+=("$AUSPEX/$src") M_REL+=("$rel") M_MODE+=("$mode")
                ;;
            *) auspex_die "manifest line $n: unknown mode $mode" ;;
        esac
    done <"$AUSPEX_MANIFEST"
    for rel in "${M_REL[@]}"; do
        [[ -z "${seen[$rel]:-}" ]] || auspex_die "manifest: target ~/$rel is on 2 rows"
        seen[$rel]=1
    done
}

declare -gA IDX_HASH=() IDX_MODE=()

auspex_index_file() {
    printf '%s\n' "$AUSPEX_STATE/targets.tsv"
}

auspex_index_load() {
    local h m r file
    file="$(auspex_index_file)"
    IDX_HASH=() IDX_MODE=()
    [[ -f "$file" ]] || return 0
    while IFS=$'\t' read -r h m r; do
        [[ -n "$r" ]] || continue
        IDX_HASH[$r]="$h"
        IDX_MODE[$r]="$m"
    done <"$file"
}

auspex_index_save() {
    local file tmp r
    file="$(auspex_index_file)"
    mkdir -p -- "$AUSPEX_STATE" || return 1
    tmp="$(mktemp "$AUSPEX_STATE/.targets.XXXXXX")" || return 1
    for r in "${!IDX_HASH[@]}"; do
        printf '%s\t%s\t%s\n' "${IDX_HASH[$r]}" "${IDX_MODE[$r]}" "$r"
    done | LC_ALL=C sort -t $'\t' -k3 >"$tmp" || {
        rm -f -- "$tmp"
        return 1
    }
    mv -f -T -- "$tmp" "$file"
}

# Mergers. A merge:<name> row runs lib/merge/<name> (the merger contract):
#   merge   <source> <target> <owned-in> <out> <owned-out>
#   restore <before> <target> <owned-now> <owned-before> <out>
#   digest  <target> <owned>
# A file argument that does not exist means "no file".

auspex_merger() {
    printf '%s\n' "$AUSPEX/lib/merge/${1#merge:}"
}

auspex_owned_file() {
    printf '%s\n' "$AUSPEX_STATE/owned/${1#merge:}.json"
}

auspex_merge_digest() {
    local out
    out="$("$(auspex_merger "$1")" digest "$2" "${3:-$(auspex_owned_file "$1")}")" || return 1
    auspex_hash_string "$out"
}

auspex_rows_reset() {
    T_REL=() T_MODE=() T_STATE=() T_ACTION=() T_NEW=() T_ONEW=() T_SRC=()
    CH=() STALE=()
}

auspex_row_add() {
    T_REL+=("$1") T_MODE+=("$2") T_STATE+=("$3") T_ACTION+=("$4") T_NEW+=("$5") T_ONEW+=("$6") T_SRC+=("$7")
}

auspex_plan_build() {
    local i rel mode src tgt new state owned out oout h r
    local -A want=()
    auspex_rows_reset
    auspex_index_load
    for i in "${!M_REL[@]}"; do
        rel="${M_REL[$i]}" mode="${M_MODE[$i]}" src="${M_SRC[$i]}"
        tgt="$HOME/$rel" new="${M_FILE[$i]}"
        want[$rel]=1
        if [[ "$mode" == merge:* ]]; then
            owned="$(auspex_owned_file "$mode")"
            out="$AUSPEX_WORK/merge-$i.out" oout="$AUSPEX_WORK/merge-$i.owned"
            "$(auspex_merger "$mode")" merge "$new" "$tgt" "$owned" "$out" "$oout" ||
                auspex_die "merger ${mode#merge:} failed on ~/$rel"
            if [[ -n "${IDX_HASH[$rel]:-}" ]] &&
                { [[ ! -e "$tgt" ]] || [[ "$(auspex_merge_digest "$mode" "$tgt")" != "${IDX_HASH[$rel]}" ]]; }; then
                state=drift
            elif [[ -e "$tgt" && -f "$owned" ]] && cmp -s "$out" "$tgt" && cmp -s "$oout" "$owned"; then
                state=unchanged
            elif [[ -e "$tgt" ]]; then
                state=update
            else
                state=create
            fi
            auspex_row_add "$rel" "$mode" "$state" write "$out" "$oout" "$src"
            continue
        fi
        if [[ ! -e "$tgt" ]]; then
            if [[ -n "${IDX_HASH[$rel]:-}" ]]; then state=drift; else state=create; fi
        elif cmp -s "$new" "$tgt"; then
            state=unchanged
        else
            h="$(auspex_hash_file "$tgt")" || auspex_die "cannot read ~/$rel"
            if [[ -n "${IDX_HASH[$rel]:-}" && "$h" == "${IDX_HASH[$rel]}" ]]; then
                state=update
            else
                state=drift
            fi
        fi
        auspex_row_add "$rel" "$mode" "$state" write "$new" "" "$src"
    done
    while IFS= read -r r; do
        [[ -n "$r" ]] || continue
        [[ -z "${want[$r]:-}" && "${IDX_MODE[$r]}" != merge:* ]] || continue
        tgt="$HOME/$r"
        if [[ ! -e "$tgt" ]]; then
            STALE+=("$r")
            continue
        fi
        h="$(auspex_hash_file "$tgt")" || auspex_die "cannot read ~/$r"
        if [[ "$h" == "${IDX_HASH[$r]}" ]]; then state=remove; else state=drift; fi
        auspex_row_add "$r" "${IDX_MODE[$r]}" "$state" remove "" "" ""
    done < <(printf '%s\n' "${!IDX_HASH[@]}" | LC_ALL=C sort)
    for i in "${!T_REL[@]}"; do
        [[ "${T_STATE[$i]}" == unchanged ]] || CH+=("$i")
    done
}

# auspex_index_mode_sync sets the index mode of each unchanged row whose mode
# changed in the manifest (for example copy to render). It returns 0 when it
# changed the index, so the caller saves it.
auspex_index_mode_sync() {
    local i rel rc=1
    for i in "${!T_REL[@]}"; do
        rel="${T_REL[$i]}"
        [[ "${T_STATE[$i]}" == unchanged && -n "${IDX_HASH[$rel]:-}" ]] || continue
        [[ "${T_MODE[$i]}" != merge:* && "${IDX_MODE[$rel]}" != merge:* ]] || continue
        [[ "${IDX_MODE[$rel]}" != "${T_MODE[$i]}" ]] || continue
        IDX_MODE[$rel]="${T_MODE[$i]}"
        rc=0
    done
    return "$rc"
}

# auspex_changed_render returns 0 when a changed row has mode render.
auspex_changed_render() {
    local i
    for i in "${CH[@]}"; do
        [[ "${T_MODE[$i]}" != render ]] || return 0
    done
    return 1
}

auspex_plan_has_drift() {
    local i
    for i in "${!T_REL[@]}"; do
        [[ "${T_STATE[$i]}" != drift ]] || return 0
    done
    return 1
}

auspex_row_diff() {
    local i="$1" tgt new
    tgt="$HOME/${T_REL[$i]}" new="${T_NEW[$i]:-/dev/null}"
    if [[ ! -e "$tgt" ]]; then
        printf '          the target is missing\n'
        return 0
    fi
    diff -u --label "~/${T_REL[$i]} (live)" --label "~/${T_REL[$i]} (new)" -- "$tgt" "$new" || true
}

auspex_plan_print() {
    local which="${1:-all}" i st
    for i in "${!T_REL[@]}"; do
        st="${T_STATE[$i]}"
        case "$which" in
            changed) [[ "$st" != unchanged ]] || continue ;;
            drift) [[ "$st" == drift ]] || continue ;;
        esac
        printf '%-9s ~/%s\n' "$st" "${T_REL[$i]}"
        if [[ "$st" == update || "$st" == drift ]]; then
            auspex_row_diff "$i"
        fi
    done
}

auspex_gen_root() {
    printf '%s\n' "$AUSPEX_STATE/generations"
}

auspex_gen_dir() {
    printf '%s/%04d\n' "$(auspex_gen_root)" "$((10#$1))"
}

auspex_gen_list() {
    local root
    root="$(auspex_gen_root)"
    [[ -d "$root" ]] || return 0
    find "$root" -mindepth 1 -maxdepth 1 -type d -regex '.*/[0-9]+' -printf '%f\n' |
        sed 's/^0*\([0-9]\)/\1/' | sort -n
}

auspex_gen_next() {
    local max=0 n root
    root="$(auspex_gen_root)"
    if [[ -f "$root/.last" ]]; then
        n="$(cat "$root/.last")"
        [[ "$n" =~ ^[0-9]+$ ]] && max=$((10#$n))
    fi
    n="$(auspex_gen_list | tail -n 1)"
    if [[ -n "$n" ]] && ((n > max)); then
        max=$n
    fi
    printf '%d\n' "$((max + 1))"
}

auspex_gen_status() {
    jq -r '.status // ""' "$(auspex_gen_dir "$1")/meta.json" 2>/dev/null || true
}

auspex_row_label() {
    if [[ "${T_ACTION[$1]}" == remove ]]; then
        printf 'remove\n'
    elif [[ -e "$HOME/${T_REL[$1]}" ]]; then
        printf 'update\n'
    else
        printf 'create\n'
    fi
}

auspex_meta_write() {
    local tmp actor=operator
    [[ "${AUSPEX_ACTOR:-}" == agent ]] && actor=agent
    tmp="$(mktemp "$GEN_DIR/.meta.XXXXXX")" || return 1
    if jq -n --argjson number "$GEN_N" --arg time "$GEN_TIME" --arg kind "$GEN_KIND" \
        --arg commit "$GEN_COMMIT" --arg reason "$GEN_REASON" --arg actor "$actor" \
        --arg status "$1" --rawfile targets "$AUSPEX_WORK/targets.tsv" \
        --argjson undoes "$GEN_UNDOES" --argjson to "$GEN_TO" \
        '{number: $number, time: $time, kind: $kind, commit: $commit, reason: $reason,
          actor: $actor, status: $status,
          targets: [$targets | split("\n")[] | select(length > 0) | split("\t")
                    | {path: .[0], mode: .[1], action: .[2]}],
          undoes: $undoes, to: $to}' >"$tmp"; then
        mv -f -T -- "$tmp" "$GEN_DIR/meta.json"
        return
    fi
    rm -f -- "$tmp"
    return 1
}

auspex_meta_status() {
    local tmp
    tmp="$(mktemp "$GEN_DIR/.meta.XXXXXX")" || return 1
    if jq --arg s "$1" '.status = $s' "$GEN_DIR/meta.json" >"$tmp"; then
        mv -f -T -- "$tmp" "$GEN_DIR/meta.json"
        return
    fi
    rm -f -- "$tmp"
    return 1
}

auspex_gen_begin() {
    local i rel b tgt owned
    GEN_KIND="$1"
    GEN_N="$(auspex_gen_next)"
    GEN_DIR="$(auspex_gen_dir "$GEN_N")"
    GEN_TIME="$(date -Iseconds)"
    GEN_COMMIT="$(git -C "$AUSPEX" rev-parse HEAD 2>/dev/null || true)"
    mkdir -p -- "$GEN_DIR/before" "$GEN_DIR/owned-before" || auspex_die "cannot make $GEN_DIR"
    printf '%d\n' "$GEN_N" >"$(auspex_gen_root)/.last" || auspex_die "cannot write $(auspex_gen_root)/.last"
    : >"$AUSPEX_WORK/targets.tsv"
    for i in "${CH[@]}"; do
        rel="${T_REL[$i]}" tgt="$HOME/${T_REL[$i]}" b="$GEN_DIR/before/${T_REL[$i]}"
        printf '%s\t%s\t%s\n' "$rel" "${T_MODE[$i]}" "$(auspex_row_label "$i")" >>"$AUSPEX_WORK/targets.tsv"
        mkdir -p -- "$(dirname -- "$b")" || auspex_die "cannot save ~/$rel"
        if [[ -e "$tgt" ]]; then
            cp -p -- "$tgt" "$b" || auspex_die "cannot save ~/$rel"
        else
            : >"$b.absent"
        fi
        if [[ "${T_MODE[$i]}" == merge:* ]]; then
            owned="$(auspex_owned_file "${T_MODE[$i]}")"
            b="$GEN_DIR/owned-before/${T_MODE[$i]#merge:}.json"
            if [[ -f "$owned" ]]; then
                cp -p -- "$owned" "$b" || auspex_die "cannot save $owned"
            else
                : >"$b.absent"
            fi
        fi
    done
    if [[ -f "$(auspex_index_file)" ]]; then
        cp -p -- "$(auspex_index_file)" "$GEN_DIR/targets-before.tsv" || auspex_die "cannot save the index"
    else
        : >"$GEN_DIR/targets-before.tsv"
    fi
    auspex_meta_write pending || auspex_die "cannot write $GEN_DIR/meta.json"
}

auspex_snapshot() {
    if ! snapper -c home create --description "auspex gen $GEN_N" </dev/null >/dev/null 2>&1; then
        auspex_log "snapper: no home snapshot; the generation folder is the undo"
    fi
}

auspex_rows_write() {
    local i rel tgt owned h
    W_DONE=0
    for i in "${CH[@]}"; do
        W_DONE=$((W_DONE + 1))
        rel="${T_REL[$i]}" tgt="$HOME/${T_REL[$i]}"
        if [[ "${T_ACTION[$i]}" == remove ]]; then
            rm -f -- "$tgt" || return 1
            if [[ "${T_MODE[$i]}" == merge:* ]]; then
                rm -f -- "$(auspex_owned_file "${T_MODE[$i]}")" || return 1
            fi
            unset "IDX_HASH[$rel]" "IDX_MODE[$rel]"
            continue
        fi
        auspex_atomic_write "${T_NEW[$i]}" "$tgt" || return 1
        if [[ "${T_MODE[$i]}" == merge:* ]]; then
            owned="$(auspex_owned_file "${T_MODE[$i]}")"
            if [[ -n "${T_ONEW[$i]}" && -e "${T_ONEW[$i]}" ]]; then
                auspex_atomic_write "${T_ONEW[$i]}" "$owned" || return 1
            else
                rm -f -- "$owned" || return 1
            fi
            h="$(auspex_merge_digest "${T_MODE[$i]}" "$tgt")" || return 1
        else
            h="$(auspex_hash_file "$tgt")" || return 1
        fi
        IDX_HASH[$rel]="$h"
        IDX_MODE[$rel]="${T_MODE[$i]}"
    done
}

auspex_rollback() {
    local k i rel tgt b owned
    for ((k = 0; k < W_DONE; k++)); do
        i="${CH[$k]}" rel="${T_REL[$i]}"
        tgt="$HOME/$rel" b="$GEN_DIR/before/$rel"
        if [[ -e "$b.absent" ]]; then
            rm -f -- "$tgt" || auspex_warn "rollback: cannot remove ~/$rel"
        elif [[ -e "$b" ]]; then
            auspex_atomic_write "$b" "$tgt" "$b" || auspex_warn "rollback: cannot restore ~/$rel"
        fi
        if [[ "${T_MODE[$i]}" == merge:* ]]; then
            owned="$(auspex_owned_file "${T_MODE[$i]}")"
            b="$GEN_DIR/owned-before/${T_MODE[$i]#merge:}.json"
            if [[ -e "$b.absent" ]]; then
                rm -f -- "$owned" || auspex_warn "rollback: cannot remove $owned"
            elif [[ -e "$b" ]]; then
                auspex_atomic_write "$b" "$owned" "$b" || auspex_warn "rollback: cannot restore $owned"
            fi
        fi
    done
    cp -f -- "$GEN_DIR/targets-before.tsv" "$(auspex_index_file)" || auspex_warn "rollback: cannot restore the index"
    auspex_meta_status failed || auspex_warn "cannot mark generation $GEN_N failed"
}

auspex_gen_commit() {
    local i rel
    if ! auspex_rows_write || ! auspex_index_save; then
        auspex_warn "a write failed; restoring the earlier content"
        auspex_rollback
        auspex_die "generation $GEN_N failed and was rolled back"
    fi
    : >"$GEN_DIR/after.sha256"
    for i in "${CH[@]}"; do
        rel="${T_REL[$i]}"
        [[ -e "$HOME/$rel" ]] || continue
        printf '%s  %s\n' "$(auspex_hash_file "$HOME/$rel")" "$rel" >>"$GEN_DIR/after.sha256"
    done
    auspex_meta_status ok || auspex_die "cannot write $GEN_DIR/meta.json"
}

auspex_gen_prune() {
    local n
    while IFS= read -r n; do
        rm -rf -- "$(auspex_gen_dir "$n")"
    done < <(auspex_gen_list | head -n -50)
}

auspex_migrations_pending() {
    local f
    [[ -d "$AUSPEX/migrations" ]] || return 0
    while IFS= read -r f; do
        [[ -e "$AUSPEX_STATE/migrations/$f" ]] || printf '%s\n' "$f"
    done < <(find "$AUSPEX/migrations" -mindepth 1 -maxdepth 1 -type f -name '*.sh' -printf '%f\n' | LC_ALL=C sort)
}

auspex_migrations_run() {
    local f rc
    local -a pending=()
    mapfile -t pending < <(auspex_migrations_pending)
    for f in "${pending[@]}"; do
        auspex_log "migration $f"
        rc=0
        bash "$AUSPEX/migrations/$f" </dev/null || rc=$?
        if ((rc != 0)); then
            auspex_warn "migration $f failed (exit $rc)"
            return 1
        fi
        mkdir -p -- "$AUSPEX_STATE/migrations" || return 1
        date -Iseconds >"$AUSPEX_STATE/migrations/$f" || return 1
    done
}

auspex_run_hooks() {
    local event="$1" arg="$2" d f rc
    local -a hooks=()
    d="$AUSPEX/hooks/$event.d"
    [[ -d "$d" ]] || return 0
    mapfile -t hooks < <(find "$d" -mindepth 1 -maxdepth 1 -type f -executable -printf '%f\n' | LC_ALL=C sort)
    for f in "${hooks[@]}"; do
        rc=0
        "$d/$f" "$arg" </dev/null || rc=$?
        if ((rc != 0)); then
            auspex_warn "hook $f failed (exit $rc)"
        fi
    done
    return 0
}

auspex_git_check() {
    local out
    out="$(git -C "$AUSPEX" status --porcelain -- manifest/user.tsv "${M_PATHS[@]}" 2>&1)" ||
        auspex_die "git status failed in $AUSPEX: $out"
    if [[ -n "$out" ]]; then
        printf '%s\n' "$out" >&2
        auspex_die "uncommitted changes in manifest source paths. Commit them, then run auspex apply"
    fi
}
