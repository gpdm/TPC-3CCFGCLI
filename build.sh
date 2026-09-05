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

echo
echo "Build summary"
echo "============="
printf "TASM calls : %d\n" "${TASM_COUNT}"
printf "TLINK calls: %d\n" "${TLINK_COUNT}"
printf "Warnings   : %d\n" "${WARNINGS}"
printf "Errors     : %d\n" "${ERRORS}"

# emmit return code based on warnings and errors
#
exit $(( WARNINGS + ERRORS > 0 ))