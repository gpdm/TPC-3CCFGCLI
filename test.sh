#!/bin/bash
# implements "fail fast, fail early".
# any non-successful test step will lead to premature exit.
# this is by desgin.
#
set -u

DOSBOX_BIN=${DOSBOX_BIN:-/Applications/DOSBox-X.app/Contents/MacOS/dosbox-x}
TEST_LOG="TEST.LOG"
TEST_MK="TEST.MK"
ARTIFACT_DIR=${ARTIFACT:-ARTIFACT}
SAVE_MAX_BATCH_LINE=128


# clear TEST.LOG
[ -f ${TEST_LOG} ] && rm ${TEST_LOG}
[ ! -f ${TEST_LOG} ] && touch ${TEST_LOG}


# General Regression Tests
#
test_regressions() {
  echo Dispatching regression tests to DOSBox-X ...
  "$DOSBOX_BIN" -conf autoexec-test > /dev/null 2>&1

  grep -e "Smoke test: run completed" ${TEST_LOG} > /dev/null 2>&1 && return 0 || return 1
}


# Check that the generated RESTORE.BAT file does not exceed the maximum line length limit.
# This is easier to test with AWK than from plain DOS, as DOS has no built-in way to check line lengths.
#
test_saveconfig_line_lengths() {
  local result
  
  echo "SAVECONFIG: assertings line length limits ..." >> "${TEST_LOG}"
  result=$(awk '{ if (length > max) max = length } END { print max }' "${ARTIFACT_DIR}/RESTORE.BAT")

  if [ "$result" -gt "$SAVE_MAX_BATCH_LINE" ]; then
    echo "[SAVECONFIG] line length failure in RESTORE.BAT: max length exceed (${result} chars)" >> "${TEST_LOG}"
    return 1
  fi

  echo "SAVECONFIG: run completed" >> "${TEST_LOG}"
}


# This is an artificial test to verify that the 3CCFGCLI is capable of
# running with a limited amount of memory.
# It does no additional assertions than that.
#
test_hwlimits() {
  local template="autoexec-testhwl.template"

  echo "Running Hardware Limit test ..." >> "${TEST_LOG}"

  # clear old logs - if any ...
  find "${ARTIFACT_DIR}" -maxdepth 1 -type f -name 'HWL*.LOG' -exec rm -f {} \;

  for memkb in 64 128 256; do
    local conf
    local log
    conf=$(mktemp "/tmp/autoexec-testhwl-${memkb}.XXXXXX")
    log="${ARTIFACT_DIR}/HWL${memkb}.LOG"

    echo "Dispatching resource test with ${memkb} KB memory limit to DOSBox-X ..."
    echo "[HWL${memkb}] Testing 8086/8088 with ${memkb} KB memory limit..." >> "${TEST_LOG}"
    sed "s/__MEMKB__/${memkb}/g" "$template" > "$conf"
    "$DOSBOX_BIN" -conf "$conf" > /dev/null 2>&1
    rm -f "$conf"

    grep -q "HWLIMIT PASS memsizekb=${memkb}" "$log" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      echo "[HWL${memkb}] PASS" >> "${TEST_LOG}"
      continue
    fi

    # implicit + silent fail if no PASS found.
    # mimic behaviour of TEST.MK/Borland MAKE;
    # which silently & prematurerly bails on non-zero exit code
    return 1
  done

  echo "Hardware Limit test: run completed" >> "${TEST_LOG}"
}


# Agent doesn't like if there's no output for prolonged time.
# Let's simply tail the log continuosly to the terminal
tail -f ${TEST_LOG} &
TAIL_PID=$!


# run tests in sequence
# chaining only on successful assertion of previous tests
#
test_regressions && test_saveconfig_line_lengths && test_hwlimits


# kill tail running in background
kill -INT $TAIL_PID 2>&1 >/dev/null


# always print TEST.LOG on exit
#
#echo ${TEST_LOG} follows:
#echo -----------------
#cat ${TEST_LOG}
#echo -----------------


# test summary
#
# assume fail by default, and only clear the fail flags if the tests pass.
SMOKE_FAIL=1
SAVECONFIG_FAIL=1
HWLIMIT_FAIL=1

# run completed usually means success, but there may be exceptions
grep -q '^Smoke test: run completed' "$TEST_LOG" && SMOKE_FAIL=0
grep -q '^SAVECONFIG: run completed' "$TEST_LOG" && SAVECONFIG_FAIL=0
grep -q '^Hardware Limit test: run completed' "$TEST_LOG" && HWLIMIT_FAIL=0

# check defined vs. executed tests and see if we anyway
# had a delta, which would indicate a failure.
TESTS_DEFINED=$(grep -Ec '^t[0-9]{4}:' "$TEST_MK")
TESTS_EXECUTED=$(grep -Ec '\[t[0-9]{4}\]' "$TEST_LOG")
TESTS_FAILED=$(( TESTS_DEFINED != TESTS_EXECUTED ))


cat <<EOF | tee >> "$TEST_LOG"

Test summary
============
Smoke Test            : $( (( SMOKE_FAIL + TESTS_FAILED == 0 )) && echo SUCCESS || echo FAILED )
    Defined Tests     : ${TESTS_DEFINED}
    Executed Tests    : ${TESTS_EXECUTED}
    Failed Tests      : $( (( TESTS_FAILED == 0 )) && echo NONE || echo OBSERVED )
SAVECONFIG Test       : $( (( SAVECONFIG_FAIL == 0 )) && echo SUCCESS || echo FAILED )
Hardware Limit Test   : $( (( HWLIMIT_FAIL == 0 )) && echo SUCCESS || echo FAILED )

Overall result        : $( (( SMOKE_FAIL + SAVECONFIG_FAIL + HWLIMIT_FAIL + TESTS_FAILED > 0 )) && echo FAIL || echo PASS )

EOF


# emmit return code based on assertions of the individual tests.
#
exit $(( SMOKE_FAIL + SAVECONFIG_FAIL + HWLIMIT_FAIL + TESTS_FAILED > 0 ))