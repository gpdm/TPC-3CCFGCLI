#!/bin/bash

set -u

DOSBOX_BIN=${DOSBOX_BIN:-/Applications/DOSBox-X.app/Contents/MacOS/dosbox-x}

echo Dispatching Build to DOSBox-X ...
"$DOSBOX_BIN" -conf autoexec-build > /dev/null 2>&1

echo BUILD.LOG follows:
echo -----------------
cat BUILD.LOG
