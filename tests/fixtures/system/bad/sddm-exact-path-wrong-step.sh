#!/usr/bin/env bash
# auspex:summary=Bad step: writes the step 060 SDDM conf but is not step 060
# auspex:args=check | apply | undo
# auspex:level=3
# auspex:requires-sudo=true

check() {
    [[ -e /etc/sddm.conf.d/zz-auspex-avgvr.conf ]]
}

apply() {
    : >/etc/sddm.conf.d/zz-auspex-avgvr.conf
}

undo() {
    rm -f /etc/sddm.conf.d/zz-auspex-avgvr.conf
}
