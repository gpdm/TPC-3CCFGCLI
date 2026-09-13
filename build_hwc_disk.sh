#!/usr/bin/env bash
#
# Create HWC Floppy Utility
#
# Since the Hardware Compliance Checks can only run on native hardware,
# I need a way to create floppy images (or floppy disks for that sake)
# containing the regression check utilities.
#
# What currently works is the disk image creation.
# If I get the detection for real floppy disks properly set up,
# I'll also support writing to target floppy disks using MTOOLS.
#

set -euo pipefail


###############################################################################
# Helpers
###############################################################################

die()
{
    echo "ERROR: $*" >&2
    exit 1
}


usage()
{
    cat <<EOF
Usage:

  $0 image
  $0 DEVICE

Examples:

  $0 image
  $0 /dev/disk4

Modes:

  image
      Creates four FAT12 floppy images in ./BIN:

        HWCTEST_1440K.IMG
        HWCTEST_720K.IMG
        HWCTEST_1200K.IMG
        HWCTEST_360K.IMG

  DEVICE
      Copies the HWC test files to an existing DOS formatted floppy disk.

      macOS example:
        /dev/disk4
EOF
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




###############################################################################
# Check operating system
###############################################################################

HOST_OS="$(uname -s)"

if [[ "$HOST_OS" != "Darwin" ]]
then
    die "This script currently runs on macOS only. It has not been adapted or ported to Linux or other operating systems."
fi



###############################################################################
# Check MTOOLS
###############################################################################

for tool in mcopy mformat mdir mmd
do
    command -v "$tool" >/dev/null 2>&1 ||
        die "MTOOLS are not installed, missing command: $tool"
done

###############################################################################
# Locate TASM 2.0 MAKE
###############################################################################

if [ ! -f "./TASM2/MAKE.EXE" ]; then
    die "TASM 2.0 with MAKE.EXE was not found. Install it first to ./TASM2"
fi

###############################################################################
# Locate STUFFIT MAKE
###############################################################################

if [ ! -f "./STUFFIT/STUFFIT.COM" ]; then
    die "STUFFIT MAKE was not found. Install it first to ./STUFFIT"
fi

###############################################################################
# Locate 3CCFGCLI.EXE
###############################################################################

if [ ! -f "./BIN/3CCFGCLI.EXE" ]; then
    die "3CCFGCLI.EXE was not found. Run ./build.sh first."
fi


###############################################################################
# Check command line
###############################################################################

if [[ $# -ne 1 ]]
then
    usage
    exit 2
fi

TARGET="$1"


###############################################################################
# Copy HWC test payload
###############################################################################

copy_payload()
{
    local media="$1"

    echo "Copying HWC test files to: $media"

    sudo mcopy -v -s -o -i "$media" \
	"3C5X9CFG/3.2/3C5X9CFG.EXE" \
        "TASM2/MAKE.EXE" \
        "STUFFIT/STUFFIT.COM" \
        "BIN/3CCFGCLI.EXE" \
        "HWCREAD.MK" \
        "HWCTEST.BAT" \
        "HWCWRITE.MK" \
        ::
}


###############################################################################
# Validate macOS floppy device
###############################################################################

validate_macos_floppy()
{
    local dev="$1"
    local info
    local size=""

    [[ -e "$dev" ]] ||
        die "Device does not exist: $dev"

    info="$(
        diskutil info "$dev" 2>/dev/null
    )" ||
        die "diskutil cannot access device: $dev"

    #
    # Require whole disk, not a partition
    #
    if ! printf '%s\n' "$info" |
         grep -Eq 'Whole:[[:space:]]+Yes'
    then
        die "Device is not a whole disk device: $dev"
    fi

    #
    # Floppy drives should be removable or ejectable
    #
    if ! printf '%s\n' "$info" |
         grep -Eq \
         'Removable Media:[[:space:]]+Removable|Ejectable:[[:space:]]+Yes'
    then
        die "Device is not reported as removable or ejectable: $dev"
    fi

    #
    # Check reported media size if available
    #
    size="$(
        printf '%s\n' "$info" |
        sed -n \
            's/.*Disk Size:.*(\([0-9][0-9]*\) Bytes).*/\1/p' |
        head -n 1
    )"

    if [[ -n "$size" ]] &&
       ! is_standard_floppy_size "$size"
    then
        #
        # Some USB floppy bridges may explicitly identify themselves
        # as floppy devices even when diskutil reports unusual geometry.
        #
        if ! printf '%s\n' "$info" |
             grep -qi 'floppy'
        then
            die "Device does not appear to contain a standard floppy disk: $dev"
        fi
    fi

    #
    # Do not touch a mounted filesystem
    #
    if printf '%s\n' "$info" |
       grep -Eq 'Mounted:[[:space:]]+Yes'
    then
        die "Device is mounted. Unmount it before running this script."
    fi
}


###############################################################################
# Check floppy and inserted disk
###############################################################################

validate_floppy()
{
    local dev="$1"

    validate_macos_floppy "$dev"

    [[ -r "$dev" ]] ||
        die "Device is not readable: $dev"

    [[ -w "$dev" ]] ||
        die "Device is not writable: $dev"

    echo "Checking for inserted media..."

    if ! dd \
        if="$dev" \
        of=/dev/null \
        bs=512 \
        count=1 \
        >/dev/null 2>&1
    then
        die "Cannot read floppy disk. No disk may be inserted."
    fi

    echo "Checking DOS filesystem..."

    if ! mdir -i "$dev" :: >/dev/null 2>&1
    then
        die "Disk is present, but no readable DOS FAT filesystem was found."
    fi
}


###############################################################################
# 6. Create FAT12 floppy image
###############################################################################

create_image()
{
    local image="$1"
    local sectors="$2"
    local format_kb="$3"

    echo
    echo "Creating: $image"

    rm -f "$image"

    dd \
        if=/dev/zero \
        of="$image" \
        bs=512 \
        count="$sectors" \
        status=none

    mformat \
        -i "$image" \
        -f "$format_kb" \
        ::

    copy_payload "$image"

    echo "Created: $image"
}


###############################################################################
# Main
###############################################################################

if [[ "$TARGET" == "image" ]]
then
    mkdir -p "./BIN"

    create_image \
        "./BIN/HWCTEST_1440K.IMG" \
        2880 \
        1440

    create_image \
        "./BIN/HWCTEST_720K.IMG" \
        1440 \
        720

    create_image \
        "./BIN/HWCTEST_1200K.IMG" \
        2400 \
        1200

    create_image \
        "./BIN/HWCTEST_360K.IMG" \
        720 \
        360

    echo
    echo "All HWC test images created successfully."

else
    # not fully tested yet -- I'm bailing out right until I find more
    # time to effectively test this part. It's just quick and dirty for now.
    die "ERROR: Writing to vanilla floppies currently disabled for now."

    validate_floppy "$TARGET"

    echo
    echo "Floppy disk detected: $TARGET"

    copy_payload "$TARGET"

    sync

    echo
    echo "HWC test disk created successfully."
fi
