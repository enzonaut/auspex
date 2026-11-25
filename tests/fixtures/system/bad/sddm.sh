#!/usr/bin/env bash
# auspex:summary=Bad step: writes under the KDE deny list
# auspex:args=check | apply | undo
# auspex:level=3
# auspex:requires-sudo=true

check() {
    [[ -e /etc/sddm.conf.d/auspex.conf ]]
}

apply() {
    : >/etc/sddm.conf.d/auspex.conf
}

undo() {
    rm -f /etc/sddm.conf.d/auspex.conf
}
