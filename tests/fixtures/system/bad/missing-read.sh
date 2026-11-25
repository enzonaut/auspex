#!/usr/bin/env bash
# auspex:summary=Bad step: missing read
# auspex:args=check | apply | undo
# auspex:level=3
# auspex:requires-sudo=true
# auspex:reads=packages/none.list

check() {
    return 1
}

apply() {
    cat "$AUSPEX_READS_DIR/packages/none.list"
}

undo() {
    return 0
}
