#!/usr/bin/env bash
# auspex:summary=Install the auspex tools: bats, shellcheck, jq, pacman-contrib
# auspex:args=check | apply | undo
# auspex:level=3
# auspex:requires-sudo=true
# auspex:reads=packages/auspex-tools.list
#
# check runs as the user. apply and undo run as root.
# apply records the packages that it installed in
# $AUSPEX_SYSTEM_STATE/030-auspex-tools.installed (default /var/lib/auspex).
# undo removes only those packages.

STEP_NAME=030-auspex-tools
if [[ -z "${AUSPEX_STEP_DIR:-}" ]]; then
    AUSPEX_STEP_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd -P)"
fi
AUSPEX_REPO="${AUSPEX_REPO:-$(cd "$AUSPEX_STEP_DIR/../.." && pwd -P)}"
STEP_LIST="${AUSPEX_READS_DIR:-$AUSPEX_REPO}/packages/auspex-tools.list"
STEP_RECORD="${AUSPEX_SYSTEM_STATE:-/var/lib/auspex}/$STEP_NAME.installed"

step_packages() {
    local line
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"
        line="${line//[[:space:]]/}"
        [[ -n "$line" ]] && printf '%s\n' "$line"
    done <"$STEP_LIST"
}

step_missing() {
    local pkg
    while IFS= read -r pkg; do
        pacman -Qq "$pkg" >/dev/null 2>&1 || printf '%s\n' "$pkg"
    done < <(step_packages)
}

check() {
    [[ -z "$(step_missing)" ]]
}

apply() {
    local -a pkgs missing
    mapfile -t pkgs < <(step_packages)
    mapfile -t missing < <(step_missing)
    pacman -S --needed --noconfirm "${pkgs[@]}" || return 1
    [[ ${#missing[@]} -gt 0 ]] || return 0
    mkdir -p "$(dirname "$STEP_RECORD")" || return 1
    {
        [[ -f "$STEP_RECORD" ]] && cat "$STEP_RECORD"
        printf '%s\n' "${missing[@]}"
    } | awk 'NF && !seen[$0]++' >"$STEP_RECORD.tmp" && mv "$STEP_RECORD.tmp" "$STEP_RECORD"
}

undo() {
    local -a recorded present=()
    local pkg
    [[ -f "$STEP_RECORD" ]] || return 0
    mapfile -t recorded <"$STEP_RECORD"
    for pkg in "${recorded[@]}"; do
        [[ -n "$pkg" ]] && pacman -Qq "$pkg" >/dev/null 2>&1 && present+=("$pkg")
    done
    if [[ ${#present[@]} -gt 0 ]]; then
        pacman -Rns --noconfirm "${present[@]}" || return 1
    fi
    rm -f "$STEP_RECORD"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    case "${1:-}" in
        check | apply | undo) "$1" ;;
        *)
            printf 'usage: %s check|apply|undo\n' "$0" >&2
            exit 2
            ;;
    esac
fi
