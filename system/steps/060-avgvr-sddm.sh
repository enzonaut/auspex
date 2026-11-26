#!/usr/bin/env bash
# auspex:summary=Install the AVGVR SDDM login theme and select it in /etc/sddm.conf.d/zz-auspex-avgvr.conf
# auspex:args=check | apply | undo
# auspex:level=3
# auspex:requires-sudo=true
# auspex:reads=system/files/avgvr/SHA256SUMS
#
# check runs as the user. apply and undo run as root.
# apply installs the sddm/* files of SHA256SUMS into a new dir with
# step_install_verified, then replaces the theme dir
# /usr/share/sddm/themes/avgvr with it. It writes the conf
# /etc/sddm.conf.d/zz-auspex-avgvr.conf atomically. It does not restart SDDM:
# the new theme shows at the next greeter start. The greeter stays X11.
# apply refuses when the breeze theme is missing, because breeze is the
# theme that SDDM uses after undo. The step never writes into breeze.
# When apply makes the conf dir, it records that in
# $AUSPEX_SYSTEM_STATE/060-avgvr-sddm.made-dir (default /var/lib/auspex).
# undo removes the conf and the theme dir. It removes the conf dir only when
# apply made it and it is empty.

STEP_NAME=060-avgvr-sddm
if [[ -z "${AUSPEX_STEP_DIR:-}" ]]; then
    AUSPEX_STEP_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd -P)"
fi
AUSPEX_REPO="${AUSPEX_REPO:-$(cd "$AUSPEX_STEP_DIR/../.." && pwd -P)}"
STEP_SUMS_PATH=system/files/avgvr/SHA256SUMS
STEP_SUMS="${AUSPEX_READS_DIR:-$AUSPEX_REPO}/$STEP_SUMS_PATH"
STEP_DEFAULT_THEME=/usr/share/sddm/themes/avgvr
STEP_THEME_ROOT="${AUSPEX_SDDM_THEME_DIR:-${STEP_DEFAULT_THEME%/avgvr}}"
STEP_THEME_ROOT="${STEP_THEME_ROOT%/}"
STEP_THEME="$STEP_THEME_ROOT/avgvr"
STEP_DEFAULT_CONF=/etc/sddm.conf.d/zz-auspex-avgvr.conf
STEP_CONF_DIR="${AUSPEX_SDDM_CONF_DIR:-${STEP_DEFAULT_CONF%/*}}"
STEP_CONF_DIR="${STEP_CONF_DIR%/}"
STEP_CONF="$STEP_CONF_DIR/${STEP_DEFAULT_CONF##*/}"
STEP_STATE="${AUSPEX_SYSTEM_STATE:-/var/lib/auspex}"
STEP_MADE_DIR="$STEP_STATE/$STEP_NAME.made-dir"

step_conf_text() {
    printf '%s\n' \
        "# $STEP_DEFAULT_CONF  (written by auspex step 060)" \
        '[Theme]' \
        'Current=avgvr' \
        'Font=Jost,11'
}

check() {
    local want path got
    local -a listed=() present=()
    [[ -f "$STEP_SUMS" && -d "$STEP_THEME" && ! -L "$STEP_THEME" ]] || return 1
    while read -r want path; do
        [[ "$path" == sddm/?* ]] || continue
        listed+=("${path#sddm/}")
        [[ -f "$STEP_THEME/${path#sddm/}" && ! -L "$STEP_THEME/${path#sddm/}" ]] || return 1
        got="$(sha256sum -- "$STEP_THEME/${path#sddm/}")" || return 1
        [[ "${got%% *}" == "$want" ]] || return 1
    done <"$STEP_SUMS"
    [[ ${#listed[@]} -gt 0 ]] || return 1
    mapfile -t present < <(cd -- "$STEP_THEME" && find . -mindepth 1 ! -type d -printf '%P\n' | LC_ALL=C sort)
    [[ "$(printf '%s\n' "${present[@]}")" == "$(printf '%s\n' "${listed[@]}" | LC_ALL=C sort)" ]] || return 1
    [[ -f "$STEP_CONF" ]] || return 1
    [[ "$(cat -- "$STEP_CONF"; echo x)" == "$(step_conf_text; echo x)" ]]
}

apply() {
    local new="$STEP_THEME.new" tmp
    local -a files
    [[ -f "$STEP_THEME_ROOT/breeze/Main.qml" ]] || {
        echo "$STEP_NAME: the breeze SDDM theme is missing. SDDM needs it after undo. Install sddm, then run apply again." >&2
        return 1
    }
    rm -rf -- "$new" || return 1
    mapfile -t files < <(step_install_verified "$STEP_SUMS_PATH" system/files/avgvr/sddm "$new"; echo "rc=$?")
    if [[ "${files[-1]}" != rc=0 ]]; then
        rm -rf -- "$new"
        return 1
    fi
    chmod 755 -- "$new" || return 1
    rm -rf -- "$STEP_THEME" || return 1
    mv -T -- "$new" "$STEP_THEME" || return 1
    if [[ ! -d "$STEP_CONF_DIR" ]]; then
        mkdir -p -- "$STEP_CONF_DIR" "$STEP_STATE" || return 1
        : >"$STEP_MADE_DIR" || return 1
    fi
    tmp="$(mktemp "$STEP_CONF_DIR/.zz-auspex-avgvr.XXXXXX")" || return 1
    if step_conf_text >"$tmp" && chmod 644 -- "$tmp" && mv -f -T -- "$tmp" "$STEP_CONF"; then
        return 0
    fi
    rm -f -- "$tmp"
    return 1
}

undo() {
    rm -f -- "$STEP_CONF" || return 1
    rm -rf -- "$STEP_THEME" "$STEP_THEME.new" || return 1
    if [[ -f "$STEP_MADE_DIR" ]]; then
        [[ -d "$STEP_CONF_DIR" ]] && rmdir --ignore-fail-on-non-empty -- "$STEP_CONF_DIR"
        rm -f -- "$STEP_MADE_DIR"
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
