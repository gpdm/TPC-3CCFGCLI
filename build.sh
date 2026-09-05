#!/bin/bash

set -u

BUILD_LOG="BUILD.LOG"
DOSBOX_BIN=${DOSBOX_BIN:-/Applications/DOSBox-X.app/Contents/MacOS/dosbox-x}

echo Dispatching Build to DOSBox-X ...
"${DOSBOX_BIN}" -conf autoexec-build > /dev/null 2>&1

echo ------------------
echo "${BUILD_LOG} follows:"
echo ------------------
cat "${BUILD_LOG}"
echo ------------------


# build summary
#
TASM_COUNT=$(grep -c 'TASM.EXE' "${BUILD_LOG}")
TLINK_COUNT=$(grep -c 'TLINK.EXE' "${BUILD_LOG}")

WARNINGS=$(awk '
    /Warning messages:/ {
        if ($NF != "None")
            total += $NF
    }
    END { print total + 0 }
' "$BUILD_LOG")

ERRORS=$(awk '
    /Error messages:/ {
        if ($NF != "None")
            total += $NF
    }
    END { print total + 0 }
' "$BUILD_LOG")


cat <<EOF | tee >(cat >> "$BUILD_LOG")

Build summary
=============
TASM calls    : ${TASM_COUNT}
TLINK calls   : ${TLINK_COUNT}
Warnings      : ${WARNINGS}
Errors        : ${ERRORS}

Overall result: $( (( WARNINGS + ERRORS > 0 )) && echo FAIL || echo PASS )

EOF


# emmit return code based on warnings and errors
#
exit $(( WARNINGS + ERRORS > 0 ))