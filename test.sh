#!/bin/bash

set -u

DOSBOX_BIN=${DOSBOX_BIN:-/Applications/DOSBox-X.app/Contents/MacOS/dosbox-x}

test_hwlimits() {
  local template="autoexec-testhwl"
  local artifact_dir="ARTIFACT"
  local suite_log="TEST.LOG"

  echo "Running Hardware Limit test ..." >> "$suite_log"
  # clear old logs - if any ...
  find "${artifact_dir}" -maxdepth 1 -type f -name 'HWL*.LOG' -exec rm -f {} \;

  for memkb in 64 128 256; do
    local conf
    local log
    conf=$(mktemp "/tmp/autoexec-testhwl-${memkb}-XXXX.conf")
    log="${artifact_dir}/HWL${memkb}.LOG"

    echo "Dispatching resource test with ${memkb} KB memory limit to DOSBox-X ..."
    echo "[HWL${memkb}] Testing 8086/8088 with ${memkb} KB memory limit..." >> "$suite_log"
    sed "s/__MEMKB__/${memkb}/g" "$template" > "$conf"
    "$DOSBOX_BIN" -conf "$conf" > /dev/null 2>&1
    rm -f "$conf"

    grep -q "HWLIMIT PASS memsizekb=${memkb}" "$log" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      echo "[HWL${memkb}] PASS" >> "$suite_log"
      continue
    fi

    # implicit + silent fail if no PASS found.
    # mimic behaviour of TEST.MK/Borland MAKE;
    # which silently & prematurerly bails on non-zero exit code
    return 1
  done

  echo "Hardware Limit test: run completed" >> "$suite_log"
}

echo Dispatching regular tests to DOSBox-X ...
"$DOSBOX_BIN" -conf autoexec-test > /dev/null 2>&1

# Run the hardware limits tests
test_hwlimits || exit 1

echo TEST.LOG follows:
echo -----------------
cat TEST.LOG
