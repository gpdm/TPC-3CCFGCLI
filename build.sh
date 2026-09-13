#!/bin/bash

set -u

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

EOF

exit $(( BUILD_FAIL + BUILDS_FAILED + WARNINGS + ERRORS > 0 ))


# emmit return code based on warnings and errors
#
exit $(( WARNINGS + ERRORS > 0 ))
