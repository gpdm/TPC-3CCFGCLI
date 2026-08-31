#!/bin/bash
# implements "fail fast, fail early".
# any non-successful test step will lead to premature exit.
# this is by desgin.
#
set -u

DOSBOX_BIN=${DOSBOX_BIN:-/Applications/DOSBox-X.app/Contents/MacOS/dosbox-x}
TEST_LOG="TEST.LOG"

test_regressions() {
  echo Dispatching regression tests to DOSBox-X ...
  "$DOSBOX_BIN" -conf autoexec-test > /dev/null 2>&1

  grep -e "Smoke test: run completed" ${TEST_LOG} > /dev/null 2>&1 && return 0 || return 1
}


test_hwlimits() {
  local template="autoexec-testhwl"
  local artifact_dir="ARTIFACT"

  echo "Running Hardware Limit test ..." >> "$TEST_LOG"
  # clear old logs - if any ...
  find "${artifact_dir}" -maxdepth 1 -type f -name 'HWL*.LOG' -exec rm -f {} \;

  for memkb in 64 128 256; do
    local conf
    local log
    conf=$(mktemp "/tmp/autoexec-testhwl-${memkb}-XXXX.conf")
    log="${artifact_dir}/HWL${memkb}.LOG"

    echo "Dispatching resource test with ${memkb} KB memory limit to DOSBox-X ..."
    echo "[HWL${memkb}] Testing 8086/8088 with ${memkb} KB memory limit..." >> "$TEST_LOG"
    sed "s/__MEMKB__/${memkb}/g" "$template" > "$conf"
    "$DOSBOX_BIN" -conf "$conf" > /dev/null 2>&1
    rm -f "$conf"

    grep -q "HWLIMIT PASS memsizekb=${memkb}" "$log" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      echo "[HWL${memkb}] PASS" >> "$TEST_LOG"
      continue
    fi

    # implicit + silent fail if no PASS found.
    # mimic behaviour of TEST.MK/Borland MAKE;
    # which silently & prematurerly bails on non-zero exit code
    return 1
  done

  echo "Hardware Limit test: run completed" >> "$TEST_LOG"
}


# run tests in sequence
# chaining only on successful assertion of previous test series
#
test_regressions && test_hwlimits


# always print TEST.LOG on exit
#
echo ${TEST_LOG} follows:
echo -----------------
cat ${TEST_LOG}
