#!/usr/bin/env bash
# auspex:summary=Test step: copies packages/demo.list to $MARK
# auspex:args=check | apply | undo
# auspex:level=3
# auspex:requires-sudo=true
# auspex:reads=packages/demo.list

check() {
    [[ -e "$MARK" ]]
}

apply() {
    cp "${AUSPEX_READS_DIR:-$AUSPEX_REPO}/packages/demo.list" "$MARK"
    printf '%s\n' "$AUSPEX_REPO" "$AUSPEX_STEP_DIR" "$AUSPEX_READS_DIR" >"$MARK.env"
}

undo() {
    rm -f "$MARK"
}
