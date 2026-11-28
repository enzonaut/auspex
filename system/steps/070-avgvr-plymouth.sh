#!/usr/bin/env bash
# auspex:summary=Install plymouth and the AVGVR plymouth theme, and select it in /etc/plymouth/plymouthd.conf
# auspex:args=check | apply | undo
# auspex:level=3
# auspex:requires-sudo=true
# auspex:reads=packages/avgvr.list system/files/avgvr/SHA256SUMS

STEP_NAME=070-avgvr-plymouth
STEP_PKG=plymouth
if [[ -z "${AUSPEX_STEP_DIR:-}" ]]; then
    AUSPEX_STEP_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd -P)"
fi
AUSPEX_REPO="${AUSPEX_REPO:-$(cd "$AUSPEX_STEP_DIR/../.." && pwd -P)}"
STEP_LIST="${AUSPEX_READS_DIR:-$AUSPEX_REPO}/packages/avgvr.list"
STEP_SUMS_PATH=system/files/avgvr/SHA256SUMS
STEP_SUMS="${AUSPEX_READS_DIR:-$AUSPEX_REPO}/$STEP_SUMS_PATH"
STEP_THEME_ROOT="${AUSPEX_PLYMOUTH_THEME_DIR:-/usr/share/plymouth/themes}"
STEP_THEME_ROOT="${STEP_THEME_ROOT%/}"
STEP_THEME="$STEP_THEME_ROOT/avgvr"
STEP_CONF="${AUSPEX_PLYMOUTHD_CONF:-/etc/plymouth/plymouthd.conf}"
STEP_SPLASH_DROPIN="${AUSPEX_MKINITCPIO_DIR:-/etc/mkinitcpio.conf.d}"
STEP_SPLASH_DROPIN="${STEP_SPLASH_DROPIN%/}/auspex-plymouth.conf"
STEP_STATE="${AUSPEX_SYSTEM_STATE:-/var/lib/auspex}"
STEP_RECORD="$STEP_STATE/$STEP_NAME.installed"
STEP_BEFORE="$STEP_STATE/$STEP_NAME.plymouthd.conf.before"
STEP_ABSENT="$STEP_STATE/$STEP_NAME.plymouthd.conf.absent"

step_listed() {
    sed -e 's/#.*//' -e 's/[[:space:]]//g' -- "$STEP_LIST" | grep -qxF -- "$STEP_PKG"
}

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

step_save_conf() {
    [[ -e "$STEP_BEFORE" || -e "$STEP_ABSENT" ]] && return 0
    mkdir -p -- "$STEP_STATE" || return 1
    if [[ -f "$STEP_CONF" ]]; then
        cp -p -- "$STEP_CONF" "$STEP_BEFORE.tmp" && mv -T -- "$STEP_BEFORE.tmp" "$STEP_BEFORE"
    else
        : >"$STEP_ABSENT"
    fi
}

check() {
    local want path got
    local -a listed=() present=()
    pacman -Qq "$STEP_PKG" >/dev/null 2>&1 || return 1
    [[ -f "$STEP_SUMS" && -d "$STEP_THEME" && ! -L "$STEP_THEME" ]] || return 1
    while read -r want path; do
        [[ "$path" == plymouth/?* ]] || continue
        listed+=("${path#plymouth/}")
        [[ -f "$STEP_THEME/${path#plymouth/}" && ! -L "$STEP_THEME/${path#plymouth/}" ]] || return 1
        got="$(sha256sum -- "$STEP_THEME/${path#plymouth/}")" || return 1
        [[ "${got%% *}" == "$want" ]] || return 1
    done <"$STEP_SUMS"
    [[ ${#listed[@]} -gt 0 ]] || return 1
    mapfile -t present < <(cd -- "$STEP_THEME" && find . -mindepth 1 ! -type d -printf '%P\n' | LC_ALL=C sort)
    [[ "$(printf '%s\n' "${present[@]}")" == "$(printf '%s\n' "${listed[@]}" | LC_ALL=C sort)" ]] || return 1
    [[ "$(plymouth-set-default-theme 2>/dev/null)" == avgvr ]]
}

apply() {
    local had=1 new="$STEP_THEME.new"
    local -a files
    step_listed || {
        echo "$STEP_NAME: packages/avgvr.list does not list $STEP_PKG" >&2
        return 1
    }
    pacman -Qq "$STEP_PKG" >/dev/null 2>&1 || had=0
    pacman -S --needed --noconfirm "$STEP_PKG" || return 1
    if ((had == 0)); then
        step_record_add "$STEP_RECORD" "$STEP_PKG" || return 1
    fi
    rm -rf -- "$new" || return 1
    mapfile -t files < <(step_install_verified "$STEP_SUMS_PATH" system/files/avgvr/plymouth "$new"; echo "rc=$?")
    if [[ "${files[-1]}" != rc=0 ]]; then
        rm -rf -- "$new"
        return 1
    fi
    chmod 755 -- "$new" || return 1
    rm -rf -- "$STEP_THEME" || return 1
    mv -T -- "$new" "$STEP_THEME" || return 1
    step_save_conf || return 1
    plymouth-set-default-theme avgvr
}

undo() {
    local pkg
    local -a recorded present=()
    if [[ -e "$STEP_SPLASH_DROPIN" ]]; then
        echo "$STEP_NAME: $STEP_SPLASH_DROPIN exists. Its HOOKS need plymouth. Run auspex system undo 080 first." >&2
        return 1
    fi
    if [[ -f "$STEP_BEFORE" ]]; then
        cp -p -- "$STEP_BEFORE" "$STEP_CONF.auspex-tmp" || return 1
        mv -T -- "$STEP_CONF.auspex-tmp" "$STEP_CONF" || return 1
        rm -f -- "$STEP_BEFORE"
    elif [[ -e "$STEP_ABSENT" ]]; then
        rm -f -- "$STEP_CONF" || return 1
        rm -f -- "$STEP_ABSENT"
    fi
    rm -rf -- "$STEP_THEME" "$STEP_THEME.new" || return 1
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
    return 0
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
