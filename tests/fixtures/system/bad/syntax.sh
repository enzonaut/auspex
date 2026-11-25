#!/usr/bin/env bash
# auspex:summary=Bad step: syntax error
# auspex:args=check | apply | undo
# auspex:level=3
# auspex:requires-sudo=true

check() {
    if true; then
}

apply() {
    return 0
}

undo() {
    return 0
}
