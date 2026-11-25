#!/usr/bin/env bash
# auspex:summary=Test step: makes the file $MARK
# auspex:args=check | apply | undo
# auspex:level=3
# auspex:requires-sudo=true

check() {
    [[ -e "$MARK" ]]
}

apply() {
    : >"$MARK"
}

undo() {
    rm -f "$MARK"
}
