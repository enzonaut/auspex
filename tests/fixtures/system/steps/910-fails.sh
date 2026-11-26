#!/usr/bin/env bash
# auspex:summary=Test step: apply and undo fail
# auspex:args=check | apply | undo
# auspex:level=3
# auspex:requires-sudo=true

check() {
    return 1
}

apply() {
    return 4
}

undo() {
    return 4
}
