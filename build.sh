#!/bin/bash

set -u

# ---------------------------------------------------------------------------
# Concurrency lock, shared between build.sh and test.sh.
#
# Rebuilding the sources while a test run is executing the previously built
# binaries produces bogus results. Both scripts therefore serialize on one
# common lock file. This implementation must stay identical in both scripts.
# ---------------------------------------------------------------------------
LOCK_FILE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/.3CCFG.LOCK"
LOCK_NOTIFY_INTERVAL=15
LOCK_HELD=0

release_lock() {
    if (( LOCK_HELD == 1 )); then
        LOCK_HELD=0
        rm -f "${LOCK_FILE}"
    fi
    return 0
}

acquire_lock() {
    local waited=0
    local owner

    while true; do
        # atomic create, fails if the lock file already exists
        if ( set -o noclobber; echo "$$ $( basename "$0" ) $( date )" > "${LOCK_FILE}" ) 2>/dev/null; then
            LOCK_HELD=1
            trap 'release_lock' EXIT
            trap 'release_lock; exit 130' INT TERM HUP
            return 0
        fi

        # drop a stale lock whose owning process no longer exists
        owner=$( awk 'NR==1 { print $1 }' "${LOCK_FILE}" 2>/dev/null )
        if [ -n "${owner}" ] && ! kill -0 "${owner}" 2>/dev/null; then
            echo "Removing stale lock of no longer running process ${owner} ..."
            rm -f "${LOCK_FILE}"
            continue
        fi

        if (( waited % LOCK_NOTIFY_INTERVAL == 0 )); then
            echo "A concurrent build/test process is still running, waiting for it to complete ..."
        fi

        sleep 1
        waited=$(( waited + 1 ))
    done
}

acquire_lock

LOGDIR="LOGS/BUILD"
BUILD_LOG="${LOGDIR}/BUILD.LOG"
ARTIFACT_DIR="${LOGDIR}/ARTIFACT"
BUILD_MK="MAKEFILE"
UV=$(command -v uv 2>/dev/null)

DOSBOX_BIN=${DOSBOX_BIN:-/Applications/DOSBox-X.app/Contents/MacOS/dosbox-x}

# clear BUILD.LOG
[ ! -d ${LOGDIR} ] && mkdir ${LOGDIR}
[ -f ${BUILD_LOG} ] && rm ${BUILD_LOG}
[ ! -f ${BUILD_LOG} ] && touch ${BUILD_LOG}

# Agent doesn't like if there's no output for prolonged time.
# Let's simply tail the log continuosly to the terminal
tail -f ${BUILD_LOG} &
TAIL_PID=$!

echo Dispatching Build to DOSBox-X ...
"${DOSBOX_BIN}" -conf "$( pwd )/autoexec-build" > /dev/null 2>&1

# render junit xml file if uv is available
#
if [ -n "$UV" ]; then
    echo "Rendering test results as JUnit XML ..." >> "${BUILD_LOG}"

    uv run testreport.py -f ${BUILD_LOG} -m ${BUILD_MK} -verbose >> "${BUILD_LOG}"
else
cat <<EOF | tee >> "${BUILD_LOG}"
NOTICE: uv is not currently installed, JUnit rendering not available.
        Please install uv to run the testreport.py script for JUnit rendering.
EOF
fi


# kill tail running in background
kill -INT ${TAIL_PID} 2>&1 >/dev/null


# build summary
#
# assume fail by default, and only clear the fail flag if the build completed.
BUILD_FAIL=1

grep -q '^BUILD: run completed' "${BUILD_LOG}" && BUILD_FAIL=0

# check defined vs. completed build steps
BUILDS_DEFINED=$(grep -Ec '^bld[0-9]{3}:' "$BUILD_MK")
BUILDS_PASSED=$(grep -Ec '\[bld[0-9]{3}\]\sPASSED' "$BUILD_LOG")
BUILDS_NA=$(grep -Ec '\[bld[0-9]{3}\]\sNOT APPLICABLE' "$BUILD_LOG")
BUILDS_COMPLETED=$(( BUILDS_PASSED + BUILDS_NA ))
BUILDS_FAILED=$(( BUILDS_DEFINED != BUILDS_COMPLETED ))

# compiler diagnostics are stored in the build artifacts
WARNINGS=$(grep -h 'Warning messages:' "${ARTIFACT_DIR}"/*.LOG 2>/dev/null | awk '{ if ($NF != "None") total += $NF } END { print total + 0 }')
ERRORS=$(grep -h 'Error messages:' "${ARTIFACT_DIR}"/*.LOG 2>/dev/null | awk '{ if ($NF != "None") total += $NF } END { print total + 0 }')

cat <<EOF | tee >> "${BUILD_LOG}"

Build summary
=============

Build                     : $( (( BUILD_FAIL + BUILDS_FAILED == 0 )) && echo SUCCESS || echo FAILED )
    Defined Build Steps   : ${BUILDS_DEFINED}
    Completed Build Steps : ${BUILDS_COMPLETED}
    Failed Build Steps    : $( (( BUILDS_FAILED == 0 )) && echo NONE || echo YES )
Warnings                  : ${WARNINGS}
Errors                    : ${ERRORS}

Overall result            : $( (( BUILD_FAIL + BUILDS_FAILED + WARNINGS + ERRORS > 0 )) && echo FAIL || echo PASS )

File Sizes
==========
$(ls -l BIN/3CCFGCLI.EXE BIN/3CHWMOCK.EXE BIN/3CSEED.EXE BIN/PKLITE/3CCFGCLI.EXE | awk '{ printf "%-30s %10s Bytes\n", $9, $5 }')

EOF

exit $(( BUILD_FAIL + BUILDS_FAILED + WARNINGS + ERRORS > 0 ))


# emmit return code based on warnings and errors
#
exit $(( WARNINGS + ERRORS > 0 ))
