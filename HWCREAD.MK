# 3CCFGCLI Hardware Compliance Read checks.
#
# 3CCFGCLI is read-only with respect to adapter hardware in this suite.
# Known hardware states are established by the original 3Com utility and read
# back through 3CCFGCLI LIST and SAVECONFIG.
#
# HWCTEST.BAT is the default entry point. It creates the hardware LIST output,
# detects the installed model, then passes the detected model as CARDTYPE and
# invokes the selected generic test target in this makefile.
#
# Usage:
#   HWCTEST.BAT READ
#
# Optional physical Boot ROM test:
#   HWCTEST.BAT READROM
#
# Optional physical Boot ROM test:
#   HWCTEST.BAT READMULTI
#
# If a run aborts after writes have started:
#   MAKE -fHWCREAD.MK -DCARDTYPE=CARD_<type> restore-config
#

# Utility definitions
RESTOREBAT = $(HWC_TAG)REST.BAT
HWC_MODE = Read

# Include the shared makefile for common definitions and targets.
!include "HWCLIB.MK"

# ###############################################################
# From here on is only specific overrides and targets for HWCREAD
# ###############################################################

# Tools for reference, write, and read operations.
REFERENCEAPP = $(3C5X9CFG)
WRITERAPP = $(3C5X9CFG)
READERAPP = $(3CCFGCLI)
WRITERNAME = 3C5X9CFG
READERNAME = 3CCFGCLI

# Suite composition remains local because READ and WRITE coverage differs.
HWCR_READ: hwc00xx hwc001 hwc002 hwc003 hwc004 hwc005 hwc006 hwc007 hwc008 hwc009 hwc051 hwcs001
hwcr: clean prep hwc00xx save-config set-default-$(CARDTYPE) hwc001-$(CARDTYPE) hwc002 hwc003 $(HWC004_TARGET) hwc005 $(HWC006_TARGET) hwc007 $(HWC008_TARGET) hwc009-$(CARDTYPE) $(HWC051_TARGET) complete

HWCR_MULTI: hwcm00xx hwcm001 hwcm002 hwcm003 hwcm004 hwcs001
hwcrm: clean prep hwcm00xx save-config hwcm001 hwcm002 hwcm003 hwcm004 complete
