#!/usr/bin/env bash
#
# HWC test data import and JUnit report utility
#
# Local HWC data layout:
#   ./LOGS/HWC/<CARD>/HWCREAD.LOG
#   ./LOGS/HWC/<CARD>/HWCWRITE.LOG
#   ./LOGS/HWC/<CARD>/ARTIFACT/
#

set -euo pipefail

LOG_ROOT="./LOGS"
HWC_ROOT="${LOG_ROOT}/HWC"

HWCREAD_MK="./HWCREAD.MK"
HWCWRITE_MK="./HWCWRITE.MK"
TEST_MK="./TEST.MK"
TESTREPORT="./testreport.py"
AUTOEXEC_TEST="./autoexec-test"
DOSBOX_BIN=${DOSBOX_BIN:-/Applications/DOSBox-X.app/Contents/MacOS/dosbox-x}

CARD_TYPES=(BTP BCOAX BCOMBO BTPO BTPC TP)
LOCAL_HWC_DIRS=()
LOCAL_HWC_DIR_COUNT=0
MEDIA_CARDS=()
MEDIA_CARD_COUNT=0
FLOPPY_CANDIDATES=()
FLOPPY_CANDIDATE_COUNT=0
SELECTED_DEVICE=""
IO_DEVICE=""


###############################################################################
# Helpers
###############################################################################

die()
{
    echo "ERROR: $*" >&2
    exit 1
}


warn()
{
    echo "WARNING: $*" >&2
}


confirm()
{
    local prompt="$1"
    local answer=""

    printf '%s [y/N] ' "$prompt"
    IFS= read -r answer || true

    case "$answer" in
        y|Y|yes|YES|Yes)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}


upper()
{
    printf '%s' "$1" | tr '[:lower:]' '[:upper:]'
}


is_card_type()
{
    case "$1" in
        BTP|BCOAX|BCOMBO|BTPO|BTPC|TP)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}


is_standard_floppy_size()
{
    case "$1" in
        368640|737280|1228800|1474560)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}


macos_block_device()
{
    case "$1" in
        /dev/rdisk*)
            printf '/dev/disk%s\n' "${1#/dev/rdisk}"
            ;;
        *)
            printf '%s\n' "$1"
            ;;
    esac
}


macos_raw_device()
{
    case "$1" in
        /dev/disk*)
            printf '/dev/rdisk%s\n' "${1#/dev/disk}"
            ;;
        *)
            printf '%s\n' "$1"
            ;;
    esac
}


mdir_media()
{
    local dev="$1"
    shift

    sudo mdir -i "$dev" "$@"
}


mcopy_media()
{
    local dev="$1"
    shift

    sudo mcopy -i "$dev" "$@"
}


probe_media()
{
    local dev="$1"

    sudo dd if="$dev" of=/dev/null bs=512 count=1 >/dev/null 2>&1
}


add_floppy_candidate()
{
    local dev="$1"
    local existing
    local index=0

    while [[ "$index" -lt "$FLOPPY_CANDIDATE_COUNT" ]]
    do
        existing="${FLOPPY_CANDIDATES[$index]}"

        if [[ "$existing" == "$dev" ]]
        then
            return 0
        fi

        index=$((index + 1))
    done

    FLOPPY_CANDIDATES[$FLOPPY_CANDIDATE_COUNT]="$dev"
    FLOPPY_CANDIDATE_COUNT=$((FLOPPY_CANDIDATE_COUNT + 1))
}


###############################################################################
# Require macOS
###############################################################################

require_macos()
{
    local host_os=""

    host_os="$(uname -s 2>/dev/null || true)"

    case "$host_os" in
        Darwin)
            ;;
        *)
            die "Unsupported operating system: ${host_os:-unknown}. This utility is currently implemented for macOS only. It has not been adapted or tested for Linux and is not portable to other operating systems."
            ;;
    esac

    command -v diskutil >/dev/null 2>&1 ||
        die "diskutil is not available."
}


###############################################################################
# 1. Check locally available HWC test data
###############################################################################

scan_local_hwc_data()
{
    local dir
    local base
    local card
    local has_log

    LOCAL_HWC_DIRS=()
    LOCAL_HWC_DIR_COUNT=0

    [[ -d "$HWC_ROOT" ]] || return 0

    for dir in "$HWC_ROOT"/*
    do
        [[ -d "$dir" ]] || continue

        base="$(basename "$dir")"
        card="$(upper "$base")"
        has_log=0

        if [[ -f "$dir/HWCREAD.LOG" || -f "$dir/HWCWRITE.LOG" ]]
        then
            has_log=1
        fi

        [[ "$has_log" -eq 1 ]] || continue

        if is_card_type "$card"
        then
            LOCAL_HWC_DIRS[$LOCAL_HWC_DIR_COUNT]="$dir"
            LOCAL_HWC_DIR_COUNT=$((LOCAL_HWC_DIR_COUNT + 1))
        else
            warn "Ignoring unrecognized HWC directory containing test logs: $dir"
        fi
    done
}


show_local_hwc_status()
{
    local dir
    local found_logs=0

    scan_local_hwc_data

    if [[ "$LOCAL_HWC_DIR_COUNT" -eq 0 ]]
    then
        echo
        echo "No HWC test data found below ${HWC_ROOT}."
        echo "The HWC tests must be executed on a system with real hardware."
        echo "Use ./build_hwc_disk.sh image to create the required HWC test floppy images."
        return 0
    fi

    echo
    echo "Local HWC test data found:"

    local index=0
    while [[ "$index" -lt "$LOCAL_HWC_DIR_COUNT" ]]
    do
        dir="${LOCAL_HWC_DIRS[$index]}"
        index=$((index + 1))
        printf '  %s' "$dir"

        if [[ -f "$dir/HWCREAD.LOG" ]]
        then
            printf '  HWCREAD.LOG'
            found_logs=$((found_logs + 1))
        fi

        if [[ -f "$dir/HWCWRITE.LOG" ]]
        then
            printf '  HWCWRITE.LOG'
            found_logs=$((found_logs + 1))
        fi

        if [[ -d "$dir/ARTIFACT" ]]
        then
            printf '  ARTIFACT'
        else
            printf '  ARTIFACT missing'
        fi

        printf '\n'
    done

    echo "Found ${found_logs} HWC log file(s)."
}


###############################################################################
# 2. Floppy import
###############################################################################

mtools_available()
{
    local tool

    for tool in mdir mcopy
    do
        if ! command -v "$tool" >/dev/null 2>&1
        then
            return 1
        fi
    done

    return 0
}


detect_macos_floppies()
{
    local dev
    local info
    local size

    command -v diskutil >/dev/null 2>&1 || return 0

    while IFS= read -r dev
    do
        [[ -n "$dev" ]] || continue

        info="$(diskutil info "$dev" 2>/dev/null || true)"
        [[ -n "$info" ]] || continue

        if printf '%s\n' "$info" | grep -qi 'floppy'
        then
            add_floppy_candidate "$dev"
            continue
        fi

        if ! printf '%s\n' "$info" |
             grep -Eq 'Removable Media:[[:space:]]+Removable|Ejectable:[[:space:]]+Yes'
        then
            continue
        fi

        size="$(
            printf '%s\n' "$info" |
            sed -n \
                's/.*Disk Size:.*(\([0-9][0-9]*\) Bytes).*/\1/p' |
            head -n 1
        )"

        if [[ -n "$size" ]] && is_standard_floppy_size "$size"
        then
            add_floppy_candidate "$dev"
        fi
    done < <(
        diskutil list 2>/dev/null |
        sed -n 's|^\(/dev/disk[0-9][0-9]*\).*|\1|p'
    )
}


detect_floppy_candidates()
{
    FLOPPY_CANDIDATES=()
    FLOPPY_CANDIDATE_COUNT=0

    detect_macos_floppies
}


choose_floppy_device()
{
    local count
    local dev
    local answer
    local index

    SELECTED_DEVICE=""
    detect_floppy_candidates
    count=$FLOPPY_CANDIDATE_COUNT

    if [[ "$count" -eq 1 ]]
    then
        dev="${FLOPPY_CANDIDATES[0]}"
        echo
        echo "Detected floppy drive: $dev"

        if confirm "Is this the drive containing the HWC test data?"
        then
            SELECTED_DEVICE="$dev"
            return 0
        fi

        printf 'Enter the correct device path, or press Enter to skip import: '
        IFS= read -r dev || true
        [[ -n "$dev" ]] || return 1
        SELECTED_DEVICE="$dev"
        return 0
    fi

    if [[ "$count" -gt 1 ]]
    then
        echo
        echo "Multiple possible floppy drives were detected:"

        index=0
        while [[ "$index" -lt "$FLOPPY_CANDIDATE_COUNT" ]]
        do
            dev="${FLOPPY_CANDIDATES[$index]}"
            echo "  $((index + 1))) $dev"
            index=$((index + 1))
        done

        printf 'Select a drive number, enter a device path, or press Enter to skip: '
        IFS= read -r answer || true
        [[ -n "$answer" ]] || return 1

        case "$answer" in
            *[!0-9]*)
                SELECTED_DEVICE="$answer"
                ;;
            *)
                if [[ "$answer" -ge 1 && "$answer" -le "$count" ]] 2>/dev/null
                then
                    SELECTED_DEVICE="${FLOPPY_CANDIDATES[$((answer - 1))]}"
                else
                    warn "Invalid drive selection."
                    return 1
                fi
                ;;
        esac

        echo "Selected floppy drive: $SELECTED_DEVICE"
        if ! confirm "Is this the drive containing the HWC test data?"
        then
            SELECTED_DEVICE=""
            return 1
        fi

        return 0
    fi

    echo
    echo "No floppy drive was detected automatically."
    printf 'Enter a floppy device path manually, or press Enter to skip import: '
    IFS= read -r dev || true
    [[ -n "$dev" ]] || return 1
    SELECTED_DEVICE="$dev"
    return 0
}


validate_macos_floppy_for_import()
{
    local dev="$1"
    local info
    local size=""

    [[ -e "$dev" ]] || {
        warn "Device does not exist: $dev"
        return 1
    }

    info="$(diskutil info "$dev" 2>/dev/null)" || {
        warn "diskutil cannot access device: $dev"
        return 1
    }

    if ! printf '%s\n' "$info" |
         grep -Eq 'Whole:[[:space:]]+Yes'
    then
        warn "Device is not a whole disk device: $dev"
        return 1
    fi

    if ! printf '%s\n' "$info" |
         grep -Eq 'Removable Media:[[:space:]]+Removable|Ejectable:[[:space:]]+Yes'
    then
        warn "Device is not reported as removable or ejectable: $dev"
        return 1
    fi

    size="$(
        printf '%s\n' "$info" |
        sed -n \
            's/.*Disk Size:.*(\([0-9][0-9]*\) Bytes).*/\1/p' |
        head -n 1
    )"

    if [[ -n "$size" ]] &&
       ! is_standard_floppy_size "$size"
    then
        if ! printf '%s\n' "$info" | grep -qi 'floppy'
        then
            warn "Device does not appear to contain a standard floppy disk: $dev"
            return 1
        fi
    fi

    return 0
}


validate_floppy_for_import()
{
    local dev="$1"
    local validation_device

    validation_device="$(macos_block_device "$dev")"
    IO_DEVICE="$(macos_raw_device "$validation_device")"

    validate_macos_floppy_for_import "$validation_device" || return 1

    [[ -e "$IO_DEVICE" ]] || {
        warn "Raw device does not exist: $IO_DEVICE"
        return 1
    }

    echo "Using raw device for media access: $IO_DEVICE"
    echo "Elevated access is required for raw floppy access on macOS."

    if ! sudo -v
    then
        warn "Unable to obtain elevated access for $IO_DEVICE"
        return 1
    fi

    echo "Checking for inserted media..."

    if ! probe_media "$IO_DEVICE"
    then
        warn "Cannot read floppy disk. No disk may be inserted."
        return 1
    fi

    echo "Checking DOS filesystem..."

    if ! mdir_media "$IO_DEVICE" :: >/dev/null 2>&1
    then
        warn "Disk is present, but no readable DOS FAT filesystem was found."
        return 1
    fi

    return 0
}



scan_floppy_hwc_data()
{
    local dev="$1"
    local card
    local has_read
    local has_write
    local has_artifact

    MEDIA_CARDS=()
    MEDIA_CARD_COUNT=0

    for card in "${CARD_TYPES[@]}"
    do
        has_read=0
        has_write=0
        has_artifact=0

        if mdir_media "$dev" "::/$card/HWCREAD.LOG" >/dev/null 2>&1
        then
            has_read=1
        fi

        if mdir_media "$dev" "::/$card/HWCWRITE.LOG" >/dev/null 2>&1
        then
            has_write=1
        fi

        if mdir_media "$dev" "::/$card/ARTIFACT" >/dev/null 2>&1
        then
            has_artifact=1
        fi

        if [[ "$has_read" -eq 1 || "$has_write" -eq 1 ]]
        then
            if [[ "$has_artifact" -eq 1 ]]
            then
                MEDIA_CARDS[$MEDIA_CARD_COUNT]="$card"
                MEDIA_CARD_COUNT=$((MEDIA_CARD_COUNT + 1))
            else
                warn "Ignoring incomplete HWC data on floppy for $card: ARTIFACT directory is missing."
            fi
        fi
    done
}


fix_import_ownership()
{
    local dest="$1"
    local uid
    local gid

    uid="$(id -u)"
    gid="$(id -g)"

    sudo chown -R "${uid}:${gid}" "$dest"
}


import_floppy_hwc_data()
{
    local dev="$1"
    local card
    local dest

    scan_floppy_hwc_data "$dev"

    if [[ "$MEDIA_CARD_COUNT" -eq 0 ]]
    then
        echo "No card specific HWC test data was found on the floppy disk."
        return 0
    fi

    echo
    printf 'HWC test data found on floppy:'
    local index=0
    while [[ "$index" -lt "$MEDIA_CARD_COUNT" ]]
    do
        printf ' %s' "${MEDIA_CARDS[$index]}"
        index=$((index + 1))
    done
    printf '\n'

    mkdir -p "$HWC_ROOT"

    index=0
    while [[ "$index" -lt "$MEDIA_CARD_COUNT" ]]
    do
        card="${MEDIA_CARDS[$index]}"
        index=$((index + 1))
        dest="$HWC_ROOT/$card"

        if [[ -e "$dest" ]]
        then
            if ! confirm "Destination $dest already exists. Overwrite it?"
            then
                echo "Skipping $card."
                continue
            fi

            sudo rm -rf -- "$dest"
        fi

        echo "Importing $card from $dev ..."
        mcopy_media "$dev" -s "::/$card" "$HWC_ROOT/"

        echo "Restoring ownership for $dest ..."
        fix_import_ownership "$dest"
    done
}


run_import_option()
{
    echo
    echo "If a floppy disk containing HWC test data is inserted, it can be imported now."

    if [[ ! -t 0 ]]
    then
        echo "No interactive input is available. Floppy import is skipped."
        return 0
    fi

    if ! mtools_available
    then
        echo "MTOOLS are not installed. Floppy import is unavailable."
        echo "Required commands: mdir, mcopy"
        return 0
    fi

    if ! choose_floppy_device
    then
        echo "Floppy import skipped."
        return 0
    fi

    if ! validate_floppy_for_import "$SELECTED_DEVICE"
    then
        echo "Floppy import skipped."
        return 0
    fi

    import_floppy_hwc_data "$IO_DEVICE"
}


###############################################################################
# 3. Post import test check
###############################################################################

dos_path()
{
    local path="${1#./}"
    printf '%s' "${path//\//\\}"
}


run_hwc_set_check()
{
    local card="$1"
    local setfile="$2"
    local hwc_log="$3"
    local basename
    local verify_log
    local dos_setfile
    local dos_hwc_log
    local dos_verify_log
    local conf

    basename="$(basename "$setfile" .SET)"
    verify_log="$(dirname "$setfile")/${basename}VFY.LOG"
    dos_setfile="$(dos_path "$setfile")"
    dos_verify_log="$(dos_path "$verify_log")"
    dos_hwc_log="$(dos_path "$hwc_log")"
    conf="$(mktemp "/tmp/autoexec-hwcset.XXXXXX")"

    rm -f "$verify_log"

    while IFS= read -r line || [[ -n "$line" ]]
    do
        case "$line" in
            *"CALL TEST"*)
                printf 'SET HWC_SET_FILE=%s\n' "$dos_setfile"
                printf 'SET HWC_CARD=%s\n' "$card"
                printf 'SET HWC_LOGFILE=%s\n' "$dos_hwc_log"
                printf 'SET HWC_VERIFY_LOGFILE=%s\n' "$dos_verify_log"
                printf 'CALL TEST hwc_set_verify\n'
                ;;
            *)
                printf '%s\n' "$line"
                ;;
        esac
    done < "$AUTOEXEC_TEST" > "$conf"

    echo "Verifying $setfile through TEST.MK ..."
    "$DOSBOX_BIN" -conf "$conf" > /dev/null 2>&1 || true
    rm -f "$conf"
}


post_import_test_check()
{
    local dir
    local card
    local setfile
    local logfile
    local check_count=0
    local failure_count=0
    local index=0

    scan_local_hwc_data

    if [[ "$LOCAL_HWC_DIR_COUNT" -eq 0 ]]
    then
        echo
        echo "No local HWC data is available for SET verification."
        return 0
    fi

    [[ -x "$DOSBOX_BIN" ]] ||
        die "DOSBox-X executable not found: $DOSBOX_BIN"

    [[ -f "$AUTOEXEC_TEST" ]] ||
        die "DOSBox-X test configuration not found: $AUTOEXEC_TEST"

    [[ -f "$TEST_MK" ]] ||
        die "TEST.MK not found: $TEST_MK"

    echo
    echo "Verifying imported 3C5X9CFG SET dumps..."

    while [[ "$index" -lt "$LOCAL_HWC_DIR_COUNT" ]]
    do
        dir="${LOCAL_HWC_DIRS[$index]}"
        index=$((index + 1))
        card="$(upper "$(basename "$dir")")"

        for logfile in "$dir/HWCREAD.LOG" "$dir/HWCWRITE.LOG"
        do
            [[ -f "$logfile" ]] || continue

            case "$(basename "$logfile")" in
                HWCREAD.LOG)
                    setfile="$dir/ARTIFACT/HWCR.SET"
                    ;;
                HWCWRITE.LOG)
                    setfile="$dir/ARTIFACT/HWCW.SET"
                    ;;
            esac

            check_count=$((check_count + 1))

            if [[ ! -f "$setfile" ]]
            then
                warn "$(basename "$setfile") is missing for imported $(basename "$logfile") data: $dir"
                failure_count=$((failure_count + 1))
                continue
            fi

            if ! run_hwc_set_check "$card" "$setfile" "$logfile"
            then
                failure_count=$((failure_count + 1))
            fi
        done
    done

    if [[ "$check_count" -eq 0 ]]
    then
        echo "No HWC read or write logs were found for SET verification."
        return 0
    fi

    echo "SET dumps verified: $((check_count - failure_count)) of $check_count"

    if [[ "$failure_count" -ne 0 ]]
    then
        warn "$failure_count SET verification check(s) failed."
        return 1
    fi

    return 0
}


###############################################################################
# 4. Update JUnit reports
###############################################################################

update_junit_reports()
{
    local dir
    local logfile
    local report_failures=0
    local report_count=0

    scan_local_hwc_data

    if [[ "$LOCAL_HWC_DIR_COUNT" -eq 0 ]]
    then
        echo
        echo "No local HWC logs are available for JUnit report generation."
        return 0
    fi

    command -v uv >/dev/null 2>&1 ||
        die "uv is not installed or not available in PATH."

    [[ -f "$TESTREPORT" ]] ||
        die "JUnit report generator not found: $TESTREPORT"

    echo
    echo "Updating HWC JUnit reports..."

    local index=0
    while [[ "$index" -lt "$LOCAL_HWC_DIR_COUNT" ]]
    do
        dir="${LOCAL_HWC_DIRS[$index]}"
        index=$((index + 1))
        if [[ ! -d "$dir/ARTIFACT" ]]
        then
            warn "Skipping $dir because ARTIFACT is missing."
            report_failures=$((report_failures + 1))
            continue
        fi

        logfile="$dir/HWCREAD.LOG"
        if [[ -f "$logfile" ]]
        then
            if [[ ! -f "$HWCREAD_MK" ]]
            then
                warn "Skipping $logfile because $HWCREAD_MK is missing."
                report_failures=$((report_failures + 1))
            else
                echo "Generating report for $logfile"
                if uv run "$TESTREPORT" \
                    -f "$logfile" \
                    -m "$HWCREAD_MK" \
                    -verbose
                then
                    report_count=$((report_count + 1))
                else
                    warn "JUnit report generation failed for $logfile"
                    report_failures=$((report_failures + 1))
                fi
            fi
        fi

        logfile="$dir/HWCWRITE.LOG"
        if [[ -f "$logfile" ]]
        then
            if [[ ! -f "$HWCWRITE_MK" ]]
            then
                warn "Skipping $logfile because $HWCWRITE_MK is missing."
                report_failures=$((report_failures + 1))
            else
                echo "Generating report for $logfile"
                if uv run "$TESTREPORT" \
                    -f "$logfile" \
                    -m "$HWCWRITE_MK" \
                    -verbose
                then
                    report_count=$((report_count + 1))
                else
                    warn "JUnit report generation failed for $logfile"
                    report_failures=$((report_failures + 1))
                fi
            fi
        fi
    done

    echo
    echo "JUnit reports updated: $report_count"

    if [[ "$report_failures" -ne 0 ]]
    then
        warn "$report_failures HWC report operation(s) failed or were skipped."
        return 1
    fi

    return 0
}


###############################################################################
# Main
###############################################################################

require_macos
show_local_hwc_status
run_import_option
post_import_test_check
update_junit_reports
