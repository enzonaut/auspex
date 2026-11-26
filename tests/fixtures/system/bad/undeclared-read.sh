#!/usr/bin/env bash
# auspex:summary=Bad step: undeclared read
# auspex:args=check | apply | undo
# auspex:level=3
# auspex:requires-sudo=true

check() {
    return 1
}

apply() {
    cat "$AUSPEX_REPO/packages/demo.list"
}

undo() {
    return 0
}
