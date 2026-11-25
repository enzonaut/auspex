#!/usr/bin/env bash
# auspex:summary=Load the 4 NVIDIA modules early through a mkinitcpio drop-in
# auspex:args=check | apply | undo
# auspex:level=3
# auspex:requires-sudo=true
# auspex:installs=system/files/auspex-nvidia.conf /etc/mkinitcpio.conf.d/auspex-nvidia.conf
# auspex:reads=system/files/auspex-nvidia.conf
#
# Follows Omarchy install/hardware/nvidia.sh at commit 8807715: add
# nvidia nvidia_modeset nvidia_uvm nvidia_drm to MODULES in a drop-in.
# The kms hook stays in HOOKS (OQ2). The main mkinitcpio config does not
# change. nvidia_drm modeset and fbdev are already set, so no modprobe file.

if [[ -z "${AUSPEX_STEP_DIR:-}" ]]; then
    AUSPEX_STEP_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd -P)"
fi
AUSPEX_REPO="${AUSPEX_REPO:-$(cd "$AUSPEX_STEP_DIR/../.." && pwd -P)}"
STEP_SOURCE="${AUSPEX_READS_DIR:-$AUSPEX_REPO}/system/files/auspex-nvidia.conf"
STEP_TARGET="${AUSPEX_MKINITCPIO_DIR:-/etc/mkinitcpio.conf.d}/auspex-nvidia.conf"

check() {
    [[ -f "$STEP_TARGET" ]] && cmp -s "$STEP_SOURCE" "$STEP_TARGET"
}

apply() {
    check && return 0
    install -D -m 644 "$STEP_SOURCE" "$STEP_TARGET" || return 1
    mkinitcpio -P
}

undo() {
    [[ -e "$STEP_TARGET" ]] || return 0
    rm -f "$STEP_TARGET" || return 1
    mkinitcpio -P
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
