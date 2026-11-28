# shellcheck shell=bash
# shellcheck disable=SC2094
# Template renderer for manifest rows with mode render. Source it, do not run it.
#
#   auspex_render <palette> <template> <out>
#
# The palette has only these line forms (an empty line is also permitted):
#   # comment
#   key = "#RRGGBB"
#   key = "text"
# A template replaces each {{ key }} or {{ key | filter }} with the palette value.
# Filters (color values only): bare (RRGGBB), rgba:<2 hex digits> (RRGGBBaa),
# dec (R, G, B in decimal). Spaces inside {{ }} are optional.
#
# The function reads only the palette and the template. It reads no environment
# value, so the same inputs give the same bytes. It writes <out> atomically.
# On an error it prints "auspex: error: <file>:<line>: <reason>", writes
# nothing and returns 1.

_auspex_render_fail() {
    printf 'auspex: error: %s:%d: %s\n' "$1" "$2" "$3" >&2
    return 1
}

_auspex_render_value() {
    local v="$1" f="$2" hex
    _AUSPEX_RENDER_OUT=""
    if [[ -z "$f" ]]; then
        _AUSPEX_RENDER_OUT="$v"
        return 0
    fi
    [[ "$f" == bare || "$f" == dec || "$f" =~ ^rgba:[0-9A-Fa-f]{2}$ ]] || return 1
    [[ "$v" =~ ^#[0-9A-Fa-f]{6}$ ]] || return 2
    hex="${v#\#}"
    case "$f" in
        bare) _AUSPEX_RENDER_OUT="$hex" ;;
        rgba:*) _AUSPEX_RENDER_OUT="$hex${f#rgba:}" ;;
        dec) _AUSPEX_RENDER_OUT="$((16#${hex:0:2})), $((16#${hex:2:2})), $((16#${hex:4:2}))" ;;
    esac
}

auspex_render() {
    local palette="$1" tpl="$2" out="$3"
    local LC_ALL=C line rest expr key filter body n=0 rc dir tmp final_nl=true
    local -A pal=()
    local re_pal='^([a-z][a-z0-9_]*)[[:space:]]*=[[:space:]]*"([^"]*)"[[:space:]]*$'
    local re_expr='^[[:space:]]*([a-z][a-z0-9_]*)[[:space:]]*(\|[[:space:]]*([^[:space:]]*)[[:space:]]*)?$'

    [[ -f "$palette" && -r "$palette" ]] || _auspex_render_fail "$palette" 0 "cannot read the palette" || return 1
    [[ -f "$tpl" && -r "$tpl" ]] || _auspex_render_fail "$tpl" 0 "cannot read the template" || return 1

    while IFS= read -r line || [[ -n "$line" ]]; do
        n=$((n + 1))
        [[ "$line" =~ ^[[:space:]]*$ || "$line" == '#'* ]] && continue
        [[ "$line" =~ $re_pal ]] || _auspex_render_fail "$palette" "$n" "bad palette line" || return 1
        key="${BASH_REMATCH[1]}"
        [[ -z "${pal[$key]+x}" ]] || _auspex_render_fail "$palette" "$n" "key $key occurs 2 times" || return 1
        pal[$key]="${BASH_REMATCH[2]}"
    done <"$palette"

    if [[ -s "$tpl" && -n "$(tail -c 1 -- "$tpl")" ]]; then
        final_nl=false
    fi
    body=""
    n=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        n=$((n + 1))
        rest="$line"
        line=""
        while [[ "$rest" == *'{{'* ]]; do
            line+="${rest%%'{{'*}"
            rest="${rest#*'{{'}"
            [[ "$rest" == *'}}'* ]] || _auspex_render_fail "$tpl" "$n" "leftover {{ with no }}" || return 1
            expr="${rest%%'}}'*}"
            rest="${rest#*'}}'}"
            [[ "$expr" =~ $re_expr ]] || _auspex_render_fail "$tpl" "$n" "bad expression {{$expr}}" || return 1
            key="${BASH_REMATCH[1]}" filter="${BASH_REMATCH[3]}"
            if [[ -n "${BASH_REMATCH[2]}" && -z "$filter" ]]; then
                _auspex_render_fail "$tpl" "$n" "empty filter in {{$expr}}" || return 1
            fi
            [[ -n "${pal[$key]+x}" ]] || _auspex_render_fail "$tpl" "$n" "unknown key $key" || return 1
            rc=0
            _auspex_render_value "${pal[$key]}" "$filter" || rc=$?
            case "$rc" in
                1) _auspex_render_fail "$tpl" "$n" "unknown filter $filter" || return 1 ;;
                2) _auspex_render_fail "$tpl" "$n" "filter $filter needs a color, but $key is text" || return 1 ;;
            esac
            line+="$_AUSPEX_RENDER_OUT"
        done
        line+="$rest"
        [[ "$line" != *'{{'* ]] || _auspex_render_fail "$tpl" "$n" "leftover {{ after the render" || return 1
        body+="$line"$'\n'
    done <"$tpl"
    if [[ $final_nl == false ]]; then
        body="${body%$'\n'}"
    fi

    dir="$(dirname -- "$out")"
    mkdir -p -- "$dir" || return 1
    tmp="$(mktemp "$dir/.render.XXXXXX")" || return 1
    if printf '%s' "$body" >"$tmp" && chmod --reference="$tpl" -- "$tmp" && mv -f -T -- "$tmp" "$out"; then
        return 0
    fi
    rm -f -- "$tmp"
    return 1
}
