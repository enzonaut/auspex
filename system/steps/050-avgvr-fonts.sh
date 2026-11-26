#!/usr/bin/env bash
# auspex:summary=Install the AVGVR fonts: ttf-jetbrains-mono, and Jost and Marcellus SC from system/files/avgvr
# auspex:args=check | apply | undo
# auspex:level=3
# auspex:requires-sudo=true
# auspex:reads=packages/avgvr.list system/files/avgvr/SHA256SUMS
#
# check runs as the user. apply and undo run as root.
# apply installs ttf-jetbrains-mono, then the fonts/* files of SHA256SUMS
# into $AUSPEX_FONT_DIR (default /usr/local/share/fonts/avgvr) with
# step_install_verified, then runs fc-cache. It records what it installed in
# $AUSPEX_SYSTEM_STATE/050-avgvr-fonts.installed (packages) and
# 050-avgvr-fonts.files (font files). AUSPEX_SYSTEM_STATE defaults to
# /var/lib/auspex. undo removes only those packages and files.
# apply uses step_install_verified from lib/system-steps.sh. The root shell
# defines it. A direct run of apply must source that file first.

STEP_NAME=050-avgvr-fonts
FONT_PKG=ttf-jetbrains-mono
if [[ -z "${AUSPEX_STEP_DIR:-}" ]]; then
    AUSPEX_STEP_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd -P)"
fi
AUSPEX_REPO="${AUSPEX_REPO:-$(cd "$AUSPEX_STEP_DIR/../.." && pwd -P)}"
STEP_LIST="${AUSPEX_READS_DIR:-$AUSPEX_REPO}/packages/avgvr.list"
STEP_SUMS_PATH=system/files/avgvr/SHA256SUMS
STEP_SUMS="${AUSPEX_READS_DIR:-$AUSPEX_REPO}/$STEP_SUMS_PATH"
STEP_FONT_DIR="${AUSPEX_FONT_DIR:-/usr/local/share/fonts/avgvr}"
STEP_FONT_DIR="${STEP_FONT_DIR%/}"
STEP_STATE="${AUSPEX_SYSTEM_STATE:-/var/lib/auspex}"
STEP_RECORD="$STEP_STATE/$STEP_NAME.installed"
STEP_FILES="$STEP_STATE/$STEP_NAME.files"

# packages/avgvr.list lists the package on its own line.
step_listed() {
    sed -e 's/#.*//' -e 's/[[:space:]]//g' -- "$STEP_LIST" | grep -qxF -- "$FONT_PKG"
}

# Add lines to a record file, keep the old lines and drop repeats.
step_record_add() {
    local file="$1"
    shift
    [[ $# -gt 0 ]] || return 0
    mkdir -p -- "$(dirname -- "$file")" || return 1
    {
        [[ -f "$file" ]] && cat -- "$file"
        printf '%s\n' "$@"
    } | awk 'NF && !seen[$0]++' >"$file.tmp" && mv -- "$file.tmp" "$file"
}

check() {
    local want path got
    pacman -Qq "$FONT_PKG" >/dev/null 2>&1 || return 1
    [[ -f "$STEP_SUMS" ]] || return 1
    while read -r want path; do
        [[ "$path" == fonts/?* ]] || continue
        [[ -f "$STEP_FONT_DIR/${path#fonts/}" ]] || return 1
        got="$(sha256sum -- "$STEP_FONT_DIR/${path#fonts/}")" || return 1
        [[ "${got%% *}" == "$want" ]] || return 1
    done <"$STEP_SUMS"
}

apply() {
    local had=1
    local -a files
    step_listed || {
        echo "$STEP_NAME: packages/avgvr.list does not list $FONT_PKG" >&2
        return 1
    }
    pacman -Qq "$FONT_PKG" >/dev/null 2>&1 || had=0
    pacman -S --needed --noconfirm "$FONT_PKG" || return 1
    if ((had == 0)); then
        step_record_add "$STEP_RECORD" "$FONT_PKG" || return 1
    fi
    mapfile -t files < <(step_install_verified "$STEP_SUMS_PATH" system/files/avgvr/fonts "$STEP_FONT_DIR"; echo "rc=$?")
    [[ "${files[-1]}" == rc=0 ]] || return 1
    unset 'files[-1]'
    step_record_add "$STEP_FILES" "${files[@]}" || return 1
    fc-cache -f "$STEP_FONT_DIR"
}

undo() {
    local f pkg
    local -a recorded present=()
    if [[ -f "$STEP_FILES" ]]; then
        while IFS= read -r f; do
            [[ "$f" == "$STEP_FONT_DIR"/?* && "/$f/" != */../* ]] || continue
            rm -f -- "$f" || return 1
        done <"$STEP_FILES"
        [[ -d "$STEP_FONT_DIR" ]] && rmdir --ignore-fail-on-non-empty -- "$STEP_FONT_DIR"
        rm -f -- "$STEP_FILES"
    fi
    if [[ -f "$STEP_RECORD" ]]; then
        mapfile -t recorded <"$STEP_RECORD"
        for pkg in "${recorded[@]}"; do
            [[ -n "$pkg" ]] && pacman -Qq "$pkg" >/dev/null 2>&1 && present+=("$pkg")
        done
        if [[ ${#present[@]} -gt 0 ]]; then
            pacman -Rns --noconfirm "${present[@]}" || return 1
        fi
        rm -f -- "$STEP_RECORD"
    fi
    fc-cache -f
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
