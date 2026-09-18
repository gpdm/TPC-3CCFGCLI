#!/usr/bin/env bash
#
# HWC test data import and JUnit report utility
#
# Local HWC data layout:
#   ./LOGS/HWC/<CARD>/HWCREAD.LOG
#   ./LOGS/HWC/<CARD>/HWCWRITE.LOG
#   ./LOGS/HWC/<CARD>/ARTIFACT/
#

set -eo pipefail

LOG_ROOT="./LOGS"
HWC_ROOT="${LOG_ROOT}/HWC"

HWCREAD_MK="HWCREAD.MK"
HWCWRITE_MK="HWCWRITE.MK"
TEST_MK="TEST.MK"
TESTREPORT="testreport.py"
AUTOEXEC_TEST="autoexec-test"
DOSBOX_BIN=${DOSBOX_BIN:-/Applications/DOSBox-X.app/Contents/MacOS/dosbox-x}

CARD_TYPES=(BTP BCOAX BCOMBO BTPO BTPC TP COAX COMBO TPO TPC MULTI)
MEDIA_CARDS=()
FLOPPY_CANDIDATES=()
MEDIA_LISTING=""
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

    sudo mcopy -v -i "$dev" "$@"
}


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

}


check_prereqs()
{
    local tool

    for tool in diskutil mcopy mdir uv
    do
        command -v "$tool" >/dev/null 2>&1 ||
            die "Required tool not found: $tool"
    done

    [[ -x "$DOSBOX_BIN" ]] ||
        die "Required tool not found: $DOSBOX_BIN"

    for file in \
        "$HWCREAD_MK" \
        "$HWCWRITE_MK" \
        "$TEST_MK" \
        "$TESTREPORT" \
        "$AUTOEXEC_TEST"
    do
        [[ -f "$file" ]] || die "Required file not found: $file"
    done
}


###############################################################################
# 1. Check locally available HWC test data
###############################################################################

warn_if_no_local_hwc_data()
{
    local dir

    if [[ -d "$HWC_ROOT" ]]
    then
        for dir in "$HWC_ROOT"/*
        do
            # Intentionally return from the function as soon as any HWC subdirectory exists.
            [[ -d "$dir" ]] && return 0
        done
    fi

    echo
    echo "No HWC test data found below ${HWC_ROOT}."
    echo "The HWC tests must be executed on a system with real hardware."
    echo
    echo "Use ./build_hwc_disk.sh image to create the required HWC test floppy images"
    echo "and run the HWC tests there."
    echo
    echo "Then import the HWC results using this script (hwctest.sh)."
}


###############################################################################
# 2. Floppy import
###############################################################################

detect_macos_floppies()
{
    local dev
    local info
    local size

    while IFS= read -r dev
    do
        [[ -n "$dev" ]] || continue

        info="$(diskutil info "$dev" 2>/dev/null || true)"
        [[ -n "$info" ]] || continue

        if printf '%s\n' "$info" | grep -qi 'floppy'
        then
            FLOPPY_CANDIDATES+=("$dev")
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
            FLOPPY_CANDIDATES+=("$dev")
        fi
    done < <(
        diskutil list 2>/dev/null |
        sed -n 's|^\(/dev/disk[0-9][0-9]*\).*|\1|p'
    )
}


choose_floppy_device()
{
    local count
    local dev
    local answer
    local index

    SELECTED_DEVICE=""
    FLOPPY_CANDIDATES=()
    detect_macos_floppies
    count=${#FLOPPY_CANDIDATES[@]}

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

        printf 'Enter the correct device path: '
        IFS= read -r dev || true
        [[ -n "$dev" ]] || return 1
        SELECTED_DEVICE="$dev"
        return 0
    fi

    if [[ "$count" -gt 1 ]]
    then
        echo
        echo "Multiple possible floppy drives were detected:"

        for index in "${!FLOPPY_CANDIDATES[@]}"
        do
            dev="${FLOPPY_CANDIDATES[$index]}"
            echo "  $((index + 1))) $dev"
        done

        printf 'Select a drive number or enter a device path: '
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

    die "No floppy drive was detected. Aborting."
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

    echo "Checking DOS filesystem..."

    MEDIA_LISTING=""
    if ! MEDIA_LISTING="$(mdir_media "$IO_DEVICE" -/ -b :: 2>/dev/null)"
    then
        warn "No readable DOS FAT filesystem was found on $IO_DEVICE."
        return 1
    fi

    return 0
}



scan_floppy_hwc_data()
{
    local card

    MEDIA_CARDS=()

    for card in "${CARD_TYPES[@]}"
    do
        if grep -Fqx \
            -e "::/$card/HWCREAD.LOG" \
            -e "::/$card/HWCWRITE.LOG" <<< "$MEDIA_LISTING"
        then
            if grep -Fqx "::/$card/ARTIFACT/" <<< "$MEDIA_LISTING"
            then
                MEDIA_CARDS+=("$card")
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

    scan_floppy_hwc_data

    if [[ "${#MEDIA_CARDS[@]}" -eq 0 ]]
    then
        die "No card specific HWC test data was found on the floppy disk."
    fi

    echo
    printf 'HWC test data found on floppy: %s\n' "${MEDIA_CARDS[*]}"

    mkdir -p "$HWC_ROOT"

    for card in "${MEDIA_CARDS[@]}"
    do
        dest="$HWC_ROOT/$card"

        # Fresh imports must replace any local card data because post processing
        # adds derived files to these directories.
        [[ -e "$dest" ]] && rm -rf -- "$dest"

        echo "Importing $card from $dev ..."
        mcopy_media "$dev" -s "::/$card" "$HWC_ROOT/"

        echo "Restoring ownership for $dest ..."
        fix_import_ownership "$dest"
    done
}


run_import()
{
    echo
    echo "Importing HWC test data from floppy disk."

    [[ -t 0 ]] || die "Interactive input is required for floppy import."

    choose_floppy_device || die "No floppy drive selected."
    validate_floppy_for_import "$SELECTED_DEVICE" ||
        die "Floppy validation failed."

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


run_hwc_set_checks()
{
    local card
    local dir
    local logfile
    local setfile_1
    local setfile_2
    local verify_log
    local dos_setfile_1
    local dos_setfile_2
    local dos_hwc_log
    local dos_verify_log
    local conf
    local line
    local base

    echo "Verifying imported 3C5X9CFG SET dumps..."

    for card in "${MEDIA_CARDS[@]}"
    do
        dir="$HWC_ROOT/$card"

        for logfile in "$dir/HWCREAD.LOG" "$dir/HWCWRITE.LOG"
        do
            # A missing READ or WRITE log is valid, just skip it.
            [[ -f "$logfile" ]] || continue

            base="$(basename "$logfile" .LOG)"

            if [[ "$card" == "MULTI" ]]
            then
                base="$(printf '%s' "$base" | sed 's/READ$/RM/; s/WRITE$/WM/')"

                setfile_1="$dir/ARTIFACT/${base}_1.SET"
                setfile_2="$dir/ARTIFACT/${base}_2.SET"

                dos_setfile_1="$(dos_path "$setfile_1")"
                dos_setfile_2="$(dos_path "$setfile_2")"
            else
                base="$(printf '%s' "$base" | sed 's/READ$/R/; s/WRITE$/W/')"

                setfile_1="$dir/ARTIFACT/${base}.SET"
                dos_setfile_1="$(dos_path "$setfile_1")"

                setfile_2=""
                dos_setfile_2=""
            fi

            verify_log="${setfile_1%.SET}VFY.LOG"

            dos_hwc_log="$(dos_path "$logfile")"
            dos_verify_log="$(dos_path "$verify_log")"

            conf="$(mktemp "/tmp/autoexec-hwcset.XXXXXX")"

            rm -f "$verify_log"

            while IFS= read -r line || [[ -n "$line" ]]
            do
                case "$line" in
                    *"CALL TEST"*)
                        printf 'SET HWC_SET_FILE_1=%s\n' "$dos_setfile_1"
                        printf 'SET HWC_SET_FILE_2=%s\n' "$dos_setfile_2"
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

            if [[ "$card" == "MULTI" ]]
            then
                echo "Verifying $setfile_1 and $setfile_2 through TEST.MK ..."
            else
                echo "Verifying $setfile_1 through TEST.MK ..."
            fi

            if ! "$DOSBOX_BIN" -conf "$conf" > /dev/null 2>&1
            then
                warn "SET verification failed for $logfile"
            fi

            rm -f "$conf"
        done
    done
}


###############################################################################
# 4. Update JUnit reports
###############################################################################

update_junit_reports()
{
    local card
    local dir
    local logfile
    local makefile

    echo "Updating HWC JUnit reports..."

    for card in "${MEDIA_CARDS[@]}"
    do
        dir="$HWC_ROOT/$card"

        for logfile in "$dir/HWCREAD.LOG" "$dir/HWCWRITE.LOG"
        do
            # skip if logfile does not exist (which may be fine, btw)
            [[ -f "$logfile" ]] || continue

            # derive MK file from log, because it always maps 1:1
            makefile="$(basename "$logfile" .LOG).MK"

            echo "Generating report for $logfile"
            if ! uv run "$TESTREPORT" \
                -f "$logfile" \
                -m "$makefile" \
                -verbose
            then
                warn "JUnit report generation failed for $logfile"
            fi
        done
    done

    return 0
}


###############################################################################
# Main
###############################################################################

require_macos
check_prereqs
warn_if_no_local_hwc_data
run_import
run_hwc_set_checks
update_junit_reports