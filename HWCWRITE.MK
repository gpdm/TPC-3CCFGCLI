# 3CCFGCLI Hardware Compliance Write checks.
#
# 3CCFGCLI performs the hardware writes in this suite.
# Deterministic starting states are established by the original 3Com utility.
# Each 3CCFGCLI CONFIGURE invocation is followed by a fresh 3CCFGCLI LIST
# process which verifies the resulting physical adapter state.
#
# This proves the physical CONFIGURE write path together with persistent
# readback through a separate 3CCFGCLI process. The final multi property test
# leaves the adapter in a deterministic test state for the independent vendor
# utility cross check performed by HWCTEST.BAT after the make run.
#
# HWCTEST.BAT is the default entry point. It creates the hardware LIST output,
# detects the installed model, then passes the detected model as CARDTYPE and
# invokes the selected generic test target in this makefile.
#
# Usage:
#   HWCTEST.BAT CONFIG
#
# Optional physical Boot ROM write test:
#   HWCTEST.BAT ROMCONFIG
#
# Optional physical Boot ROM test:
#   HWCTEST.BAT READMULTI
#
# If a run aborts after writes have started:
#   MAKE -fHWCWRITE.MK -DCARDTYPE=CARD_<type> restore-config
#

# Utility definitions
RESTOREBAT = $(HWC_TAG)REST.BAT
HWC_MODE = Write


# Include the shared makefile for common definitions and targets.
!include "HWCLIB.MK"

# ################################################################
# From here on is only specific overrides and targets for HWCWRITE
# ################################################################

# Tools for reference, write, and read operations.
REFERENCEAPP = $(3C5X9CFG)
WRITERAPP = $(3CCFGCLI)
READERAPP = $(3CCFGCLI)
WRITERNAME = 3CCFGCLI
READERNAME = 3CCFGCLI

# Suite composition remains local because READ and WRITE coverage differs.
HWCW_WRITE: hwc00xx hwc001 hwc002 hwc003 hwc004 hwc005 hwc006 hwc007 hwc008 hwc009 hwc010 hwc051 hwcs001
hwcw: clean prep hwc00xx save-config set-default-$(CARDTYPE) hwc001-$(CARDTYPE) hwc002 hwc003 $(HWC004_TARGET) hwc005 $(HWC006_TARGET) hwc007 $(HWC008_TARGET) hwc009-$(CARDTYPE) hwc010 $(HWC051_TARGET) complete

HWCW_MULTI: hwcm00xx hwcm001 hwcm002 hwcm003 hwcm004 hwcm005 hwcs001
hwcwm: clean prep hwcm00xx save-config hwcm001 hwcm002 hwcm003 hwcm004 hwcm005 complete
