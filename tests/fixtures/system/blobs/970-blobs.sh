#!/usr/bin/env bash
# auspex:summary=Test step: installs the fonts of system/files/demo/SHA256SUMS to $BLOB_DEST
# auspex:args=check | apply | undo
# auspex:level=3
# auspex:requires-sudo=true
# auspex:reads=system/files/demo/SHA256SUMS

check() {
    [[ -e "$BLOB_DEST/a.ttf" ]]
}

apply() {
    step_install_verified system/files/demo/SHA256SUMS system/files/demo/fonts "$BLOB_DEST" >"$MARK"
}

undo() {
    rm -rf "$BLOB_DEST"
}
