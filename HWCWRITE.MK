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

!include HWCLIB.MK

REFERENCEAPP = $(3C5X9CFG)
WRITERAPP = $(3CCFGCLI)
READERAPP = $(3CCFGCLI)
WRITERNAME = 3CCFGCLI
READERNAME = 3CCFGCLI

# CARDTYPE is supplied by HWCTEST.BAT, for example:
#   MAKE -fHWCWRITE.MK CARD_BTP=1 hwcw
#
# Map the detected card type to the human readable model name and to the
# optional tests supported by that model. Unknown card types are rejected
# while the makefile is parsed, before any hardware test is started.
#
!if $d(CARD_MULTI)

CARDTYPE = multi
CARDNAME = two EtherLink III adapters

!elif $d(CARD_BTP)

CARDTYPE = btp
CARDNAME = 3C509B-TP
HWC004_TARGET = hwc004
HWC006_TARGET = hwc006
HWC008_TARGET = hwc008-btp

!if $d(ROM_TEST)
HWC051_TARGET = hwc-rom-not-implemented
!else
HWC051_TARGET = hwc-rom-disabled
!endif

!elif $d(CARD_BCOAX)

CARDTYPE = bcoax
CARDNAME = 3C509B-COAX
DEFAULT_TRANSCEIVER = AUI
HWC004_TARGET = hwc004
HWC006_TARGET = hwc006-unsupported
HWC008_TARGET = hwc008-bcoax
!if $d(ROM_TEST)
HWC051_TARGET = hwc-rom-not-implemented
!else
HWC051_TARGET = hwc-rom-disabled
!endif

!elif $d(CARD_BCOMBO)

CARDTYPE = bcombo
CARDNAME = 3C509B-Combo
HWC004_TARGET = hwc004
HWC006_TARGET = hwc006
HWC008_TARGET = hwc008-bcombo
!if $d(ROM_TEST)
HWC051_TARGET = hwc-rom-not-implemented
!else
HWC051_TARGET = hwc-rom-disabled
!endif

!elif $d(CARD_BTPO)

CARDTYPE = btpo
CARDNAME = 3C509B-TPO
HWC004_TARGET = hwc004
HWC006_TARGET = hwc006
HWC008_TARGET = hwc008-btpo
!if $d(ROM_TEST)
# Boot ROM is anyway unsupported for 3C509B-TPO model.
HWC051_TARGET = hwc-rom-unsupported
!else
HWC051_TARGET = hwc-rom-disabled
!endif

!elif $d(CARD_BTPC)

CARDTYPE = btpc
CARDNAME = 3C509B-TPCoax
HWC004_TARGET = hwc004
HWC006_TARGET = hwc006
HWC008_TARGET = hwc008-btpc
!if $d(ROM_TEST)
HWC051_TARGET = hwc-rom-not-implemented
!else
HWC051_TARGET = hwc-rom-disabled
!endif

!elif $d(CARD_TP)

CARDTYPE = tp
CARDNAME = 3C509-TP
HWC004_TARGET = hwc004-unsupported
HWC006_TARGET = hwc006-unsupported
HWC008_TARGET = hwc008-tp
!if $d(ROM_TEST)
HWC051_TARGET = hwc-rom-not-implemented
!else
HWC051_TARGET = hwc-rom-disabled
!endif

!elif $d(CARD_COAX)

CARDTYPE = coax
CARDNAME = 3C509-COAX
DEFAULT_TRANSCEIVER = AUI
HWC004_TARGET = hwc004-unsupported
HWC006_TARGET = hwc006-unsupported
HWC008_TARGET = hwc008-coax
!if $d(ROM_TEST)
HWC051_TARGET = hwc-rom-not-implemented
!else
HWC051_TARGET = hwc-rom-disabled
!endif

!elif $d(CARD_COMBO)

CARDTYPE = combo
CARDNAME = 3C509-Combo
HWC004_TARGET = hwc004-unsupported
HWC006_TARGET = hwc006-unsupported
HWC008_TARGET = hwc008-combo
!if $d(ROM_TEST)
HWC051_TARGET = hwc-rom-not-implemented
!else
HWC051_TARGET = hwc-rom-disabled
!endif

!elif $d(CARD_TPO)

CARDTYPE = tpo
CARDNAME = 3C509-TPO
HWC004_TARGET = hwc004-unsupported
HWC006_TARGET = hwc006-unsupported
HWC008_TARGET = hwc008-tpo
!if $d(ROM_TEST)
# Boot ROM is anyway unsupported for 3C509-TPO model.
HWC051_TARGET = hwc-rom-unsupported
!else
HWC051_TARGET = hwc-rom-disabled
!endif

!elif $d(CARD_TPC)

CARDTYPE = tpc
CARDNAME = 3C509-TPCoax
HWC004_TARGET = hwc004-unsupported
HWC006_TARGET = hwc006-unsupported
HWC008_TARGET = hwc008-tpc
!if $d(ROM_TEST)
HWC051_TARGET = hwc-rom-not-implemented
!else
HWC051_TARGET = hwc-rom-disabled
!endif

!else

!error No valid card model selected

!endif


# Set output directories and log files are derived from selected card type.
#
OUTDIR = $(CARDTYPE)
ARTIFACTS = $(OUTDIR)\ARTIFACT
LOGFILE = $(OUTDIR)\$(HWC_TAG).LOG

# Suite composition remains local because READ and WRITE coverage differs.
HWCW_WRITE: hwc00xx hwc001 hwc002 hwc003 hwc004 hwc005 hwc006 hwc007 hwc008 hwc009 hwc010 hwc051 hwcs001
hwcw: clean prep hwc00xx save-config set-default-$(CARDTYPE) hwc001-$(CARDTYPE) hwc002 hwc003 $(HWC004_TARGET) hwc005 $(HWC006_TARGET) hwc007 $(HWC008_TARGET) hwc009-$(CARDTYPE) hwc010 $(HWC051_TARGET) complete

HWCW_MULTI: hwcm00xx hwcm001 hwcm002 hwcm003 hwcm004 hwcm005 hwcs001
hwcwm: clean prep hwcm00xx save-config hwcm001 hwcm002 hwcm003 hwcm004 hwcm005 complete
