#!/usr/bin/env bash
# auspex:summary=Add plymouth to the initramfs and quiet splash to the kernel command line, then rebuild the UKI
# auspex:args=check | apply | undo
# auspex:level=3
# auspex:requires-sudo=true
#
# check runs as the user. apply and undo run as root.
# apply writes the mkinitcpio drop-in /etc/mkinitcpio.conf.d/auspex-plymouth.conf
# (the main HOOKS plus plymouth after udev), adds quiet and splash to the 1
# line of /etc/kernel/cmdline and runs mkinitcpio -P. It saves the cmdline
# once to $AUSPEX_SYSTEM_STATE/080-avgvr-boot-splash.cmdline.before (default
# /var/lib/auspex). If mkinitcpio -P fails, apply restores the drop-in and the
# cmdline of before the run, runs mkinitcpio -P again and returns 1.
# undo removes the drop-in, restores the cmdline (or removes only the 2 words
# that apply added) and runs mkinitcpio -P.
#
# apply guards, in order. Each guard prints a message and changes nothing:
#   1. step 020 is applied (auspex-nvidia.conf is in the mkinitcpio dir) and
#      step 070 is applied (plymouth-set-default-theme prints avgvr).
#   2. the HOOKS line of /etc/mkinitcpio.conf equals STEP_MAIN_HOOKS. The
#      drop-in replaces HOOKS, so it would hide a change to the main file.
#   3. /etc/cmdline.d does not exist. The step never makes it.
#   4. no Limine conf has a cmdline: or kernel_cmdline: line in an entry for
#      arch-linux.efi. The confs are the ones that exist of /boot/limine.conf,
#      /boot/limine/limine.conf, /boot/EFI/limine/limine.conf and
#      /boot/EFI/BOOT/limine.conf, or the list in AUSPEX_LIMINE_CONFS.
# After the guards, apply also refuses a cmdline file that is missing or that
# does not have exactly 1 line.
#
# The UKI command line of mkinitcpio 42.2 (build_uki), in order:
#   1. --cmdline, from <preset>_cmdline or ALL_cmdline in the preset. A file is
#      used alone. A dir uses only its *.conf files. linux.preset has none.
#   2. else the first file that exists of /etc/kernel/cmdline and
#      /usr/lib/kernel/cmdline, then each /etc/cmdline.d/*.conf in sort -V
#      order, appended.
#   3. else /proc/cmdline.
# Lines that start with # are dropped, and newlines become spaces.
# --no-cmdline embeds no command line.
#
# Env seams for tests: AUSPEX_MKINITCPIO_DIR, AUSPEX_MKINITCPIO_CONF,
# AUSPEX_KERNEL_CMDLINE, AUSPEX_CMDLINE_D, AUSPEX_LIMINE_CONFS and
# AUSPEX_SYSTEM_STATE.

STEP_NAME=080-avgvr-boot-splash
STEP_MAIN_HOOKS='HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)'
STEP_DIR="${AUSPEX_MKINITCPIO_DIR:-/etc/mkinitcpio.conf.d}"
STEP_DIR="${STEP_DIR%/}"
STEP_DROPIN="$STEP_DIR/auspex-plymouth.conf"
STEP_NVIDIA="$STEP_DIR/auspex-nvidia.conf"
STEP_MAIN_CONF="${AUSPEX_MKINITCPIO_CONF:-/etc/mkinitcpio.conf}"
STEP_CMDLINE="${AUSPEX_KERNEL_CMDLINE:-/etc/kernel/cmdline}"
STEP_CMDLINE_D="${AUSPEX_CMDLINE_D:-/etc/cmdline.d}"
STEP_LIMINE_CONFS="${AUSPEX_LIMINE_CONFS:-/boot/limine.conf /boot/limine/limine.conf /boot/EFI/limine/limine.conf /boot/EFI/BOOT/limine.conf}"
STEP_STATE="${AUSPEX_SYSTEM_STATE:-/var/lib/auspex}"
STEP_BEFORE="$STEP_STATE/$STEP_NAME.cmdline.before"

step_dropin_text() {
    printf '%s\n' \
        '# Written by auspex step 080. Main HOOKS plus plymouth after udev.' \
        'HOOKS=(base udev plymouth autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)'
}

step_has_word() {
    [[ " $1 " == *" $2 "* ]]
}

# Print each cmdline: or kernel_cmdline: line of an entry whose lines name
# arch-linux.efi. A line that starts with / starts an entry.
step_limine_cmdlines() {
    awk '
        function flush() { if (efi) printf "%s", lines; efi = 0; lines = "" }
        /^[[:space:]]*\// { flush(); next }
        tolower($0) ~ /arch-linux\.efi/ { efi = 1 }
        tolower($0) ~ /^[[:space:]]*(kernel_)?cmdline[[:space:]]*:/ { lines = lines FILENAME ": " $0 "\n" }
        END { flush() }
    ' "$1"
}

step_guards() {
    local hooks conf found
    if [[ ! -f "$STEP_NVIDIA" ]]; then
        echo "$STEP_NAME: $STEP_NVIDIA is missing. Apply step 020 first." >&2
        return 1
    fi
    if [[ "$(plymouth-set-default-theme 2>/dev/null)" != avgvr ]]; then
        echo "$STEP_NAME: plymouth-set-default-theme does not print avgvr. Apply step 070 first." >&2
        return 1
    fi
    hooks="$(grep -E '^[[:space:]]*HOOKS=' -- "$STEP_MAIN_CONF" 2>/dev/null | tail -n 1)"
    if [[ "$hooks" != "$STEP_MAIN_HOOKS" ]]; then
        printf '%s: the HOOKS line of %s is not the expected line.\n  found:    %s\n  expected: %s\n' \
            "$STEP_NAME" "$STEP_MAIN_CONF" "${hooks:-(none)}" "$STEP_MAIN_HOOKS" >&2
        return 1
    fi
    if [[ -e "$STEP_CMDLINE_D" ]]; then
        echo "$STEP_NAME: $STEP_CMDLINE_D exists. mkinitcpio appends it to the UKI command line. Remove it or merge it into $STEP_CMDLINE first." >&2
        return 1
    fi
    for conf in $STEP_LIMINE_CONFS; do
        [[ -e "$conf" ]] || continue
        if [[ ! -r "$conf" ]]; then
            echo "$STEP_NAME: cannot read the Limine conf $conf." >&2
            return 1
        fi
        found="$(step_limine_cmdlines "$conf")"
        if [[ -n "$found" ]]; then
            printf '%s: a Limine entry for arch-linux.efi sets a command line. quiet splash in %s would have no effect.\n%s\n' \
                "$STEP_NAME" "$STEP_CMDLINE" "$found" >&2
            return 1
        fi
    done
    if [[ ! -f "$STEP_CMDLINE" || "$(wc -l <"$STEP_CMDLINE")" -ne 1 ]]; then
        echo "$STEP_NAME: $STEP_CMDLINE must exist and have exactly 1 line." >&2
        return 1
    fi
}

# Write $1 as the 1 line of the cmdline file, with its mode kept.
step_write_cmdline() {
    cp -p -- "$STEP_CMDLINE" "$STEP_CMDLINE.auspex-tmp" || return 1
    if printf '%s\n' "$1" >"$STEP_CMDLINE.auspex-tmp" && mv -T -- "$STEP_CMDLINE.auspex-tmp" "$STEP_CMDLINE"; then
        return 0
    fi
    rm -f -- "$STEP_CMDLINE.auspex-tmp"
    return 1
}

check() {
    local line
    [[ -f "$STEP_DROPIN" && -f "$STEP_CMDLINE" ]] || return 1
    [[ "$(cat -- "$STEP_DROPIN"; echo x)" == "$(step_dropin_text; echo x)" ]] || return 1
    line="$(cat -- "$STEP_CMDLINE")"
    step_has_word "$line" quiet && step_has_word "$line" splash
}

apply() {
    local line run_cmdline run_dropin
    step_guards || return 1
    check && return 0
    mkdir -p -- "$STEP_STATE" || return 1
    if [[ ! -e "$STEP_BEFORE" ]]; then
        cp -p -- "$STEP_CMDLINE" "$STEP_BEFORE.tmp" || return 1
        mv -T -- "$STEP_BEFORE.tmp" "$STEP_BEFORE" || return 1
    fi
    run_cmdline="$STEP_STATE/$STEP_NAME.cmdline.run"
    run_dropin="$STEP_STATE/$STEP_NAME.dropin.run"
    cp -p -- "$STEP_CMDLINE" "$run_cmdline" || return 1
    rm -f -- "$run_dropin"
    if [[ -f "$STEP_DROPIN" ]]; then
        cp -p -- "$STEP_DROPIN" "$run_dropin" || return 1
    fi

    line="$(cat -- "$STEP_CMDLINE")"
    step_has_word "$line" quiet || line="$line quiet"
    step_has_word "$line" splash || line="$line splash"
    if step_dropin_text >"$STEP_DROPIN.auspex-tmp" && chmod 644 -- "$STEP_DROPIN.auspex-tmp" &&
        mv -T -- "$STEP_DROPIN.auspex-tmp" "$STEP_DROPIN" && step_write_cmdline "$line" && mkinitcpio -P; then
        rm -f -- "$run_cmdline" "$run_dropin"
        return 0
    fi

    echo "$STEP_NAME: apply failed. Restoring the drop-in and $STEP_CMDLINE, then running mkinitcpio -P again." >&2
    rm -f -- "$STEP_DROPIN.auspex-tmp" "$STEP_CMDLINE.auspex-tmp"
    if [[ -f "$run_dropin" ]]; then
        mv -T -- "$run_dropin" "$STEP_DROPIN"
    else
        rm -f -- "$STEP_DROPIN"
    fi
    mv -T -- "$run_cmdline" "$STEP_CMDLINE"
    mkinitcpio -P || echo "$STEP_NAME: the 2nd mkinitcpio -P failed too. See the recovery path in system-steps.md." >&2
    return 1
}

undo() {
    local line before word changed=0
    local -a kept=() words=()
    if [[ -e "$STEP_DROPIN" ]]; then
        rm -f -- "$STEP_DROPIN" || return 1
        changed=1
    fi
    if [[ -f "$STEP_BEFORE" ]]; then
        if [[ -f "$STEP_CMDLINE" ]]; then
            line="$(cat -- "$STEP_CMDLINE")"
            before="$(cat -- "$STEP_BEFORE")"
            if [[ "$line" == "$before quiet splash" ]]; then
                cp -p -- "$STEP_BEFORE" "$STEP_CMDLINE.auspex-tmp" || return 1
                mv -T -- "$STEP_CMDLINE.auspex-tmp" "$STEP_CMDLINE" || return 1
                changed=1
            else
                read -r -a words <<<"$line"
                for word in "${words[@]}"; do
                    if [[ "$word" == quiet || "$word" == splash ]] && ! step_has_word "$before" "$word"; then
                        changed=1
                        continue
                    fi
                    kept+=("$word")
                done
                if [[ "${kept[*]}" != "$line" ]]; then
                    step_write_cmdline "${kept[*]}" || return 1
                fi
            fi
        fi
        rm -f -- "$STEP_BEFORE"
    fi
    ((changed)) || return 0
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
