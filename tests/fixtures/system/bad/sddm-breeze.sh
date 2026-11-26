#!/usr/bin/env bash
# auspex:summary=Bad step: writes into the breeze SDDM theme
# auspex:args=check | apply | undo
# auspex:level=3
# auspex:requires-sudo=true

check() {
    [[ -e /usr/share/sddm/themes/breeze/x ]]
}

apply() {
    : >/usr/share/sddm/themes/breeze/x
}

undo() {
    rm -f /usr/share/sddm/themes/breeze/x
}
