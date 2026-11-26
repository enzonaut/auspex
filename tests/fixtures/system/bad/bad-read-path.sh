#!/usr/bin/env bash
# auspex:summary=Bad step: bad read path
# auspex:args=check | apply | undo
# auspex:level=3
# auspex:requires-sudo=true
# auspex:reads=../outside.list

check() {
    return 1
}

apply() {
    return 0
}

undo() {
    return 0
}
