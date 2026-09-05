#!/bin/bash

set -u

BUILD_LOG="BUILD.LOG"
DOSBOX_BIN=${DOSBOX_BIN:-/Applications/DOSBox-X.app/Contents/MacOS/dosbox-x}

# clear BUILD.LOG
[ -f ${BUILD_LOG} ] && rm ${BUILD_LOG}
[ ! -f ${BUILD_LOG} ] && touch ${BUILD_LOG}

# Agent doesn't like if there's no output for prolonged time.
# Let's simply tail the log continuosly to the terminal
tail -f ${BUILD_LOG} &
TAIL_PID=$!

echo Dispatching Build to DOSBox-X ...
"${DOSBOX_BIN}" -conf autoexec-build > /dev/null 2>&1

# kill tail running in background
kill -INT $TAIL_PID 2>&1 >/dev/null


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


cat <<EOF | tee >> "$BUILD_LOG"

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
