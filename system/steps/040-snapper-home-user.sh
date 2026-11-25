#!/usr/bin/env bash
# auspex:summary=Let lordvader make snapper snapshots of the home config
# auspex:args=check | apply | undo
# auspex:level=3
# auspex:requires-sudo=true

STEP_NAME=040-snapper-home-user
STEP_USER=lordvader
STEP_CONFIG="${SNAPPER_CONFIG_DIR:-/etc/snapper/configs}/home"
STEP_RECORD="${AUSPEX_SYSTEM_STATE:-/var/lib/auspex}/$STEP_NAME.before"

step_allow_users() {
    local line
    [[ -r "$STEP_CONFIG" ]] || return 1
    line="$(grep -E '^ALLOW_USERS=' "$STEP_CONFIG" | tail -n 1)" || return 1
    line="${line#ALLOW_USERS=}"
    line="${line#\"}"
    printf '%s\n' "${line%\"}"
}

step_has_user() {
    local users="$1" u
    for u in $users; do
        [[ "$u" == "$STEP_USER" ]] && return 0
    done
    return 1
}

check() {
    local users
    users="$(step_allow_users)" || return 1
    step_has_user "$users"
}

apply() {
    local users
    users="$(step_allow_users)" || {
        echo "cannot read ALLOW_USERS in $STEP_CONFIG" >&2
        return 1
    }
    step_has_user "$users" && return 0
    mkdir -p "$(dirname "$STEP_RECORD")" || return 1
    if [[ ! -f "$STEP_RECORD" ]]; then
        printf '%s\n' "$users" >"$STEP_RECORD.tmp" && mv "$STEP_RECORD.tmp" "$STEP_RECORD" || return 1
    fi
    snapper -c home set-config "ALLOW_USERS=${users:+$users }$STEP_USER"
}

undo() {
    local before
    [[ -f "$STEP_RECORD" ]] || return 0
    before="$(head -n 1 "$STEP_RECORD")"
    [[ "$before" =~ ^[a-z0-9_.\ -]*$ ]] || {
        echo "bad value in $STEP_RECORD" >&2
        return 1
    }
    snapper -c home set-config "ALLOW_USERS=$before" || return 1
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
