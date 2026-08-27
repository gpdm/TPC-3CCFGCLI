#!/bin/bash

set -u

DOSBOX_BIN=${DOSBOX_BIN:-/Applications/DOSBox-X.app/Contents/MacOS/dosbox-x}

echo Loading interactive DOSBox-X session ...
"$DOSBOX_BIN" -conf autoexec-interactive
