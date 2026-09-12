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
# If a run aborts after writes have started:
#   MAKE -fHWCWRITE.MK CARDTYPE=<type> restore-config
#

# Utility definitions
RESTOREBAT = HWCWREST.BAT
REFERENCEAPP = 3C5X9CFG.EXE
WRITERAPP = 3CCFGCLI.EXE
READERAPP = 3CCFGCLI.EXE

# Output directories and log files are defined further below
# as they are defined based on the selected card type.
# Consequentally, the definition can only happend after
# processing the card type selection.
#
# ## OUTDIR = $(CARDTYPE)
# ## ARTIFACTS = $(OUTDIR)\ARTIFACT
# ## LOGFILE = $(OUTDIR)\HWCWRITE.LOG

# Preset Defaults
DEFAULT_IRQ = 10
DEFAULT_IOBASE = 0300
DEFAULT_MODEM = NONE
DEFAULT_OPTIMIZE = DOS
DEFAULT_TRANSCEIVER = TP
DEFAULT_FULLDUPLEX = DISABLED
DEFAULT_PNP = ENABLED

# Test Defaults
TEST_IRQ = 3
TEST_IOBASE = 0280
TEST_PNP = DISABLED
TEST_MODEM = 1200
TEST_OPTIMIZE = SERVER
TEST_BADDRESS = C8000
TEST_BSIZE = 16
TEST_FULLDUPLEX = ENABLED

# CARDTYPE is supplied by HWCTEST.BAT, for example:
#   MAKE -fHWCWRITE.MK CARD_BTP=1 hwcw
#
# Map the detected card type to the human readable model name and to the
# optional tests supported by that model. Unknown card types are rejected
# while the makefile is parsed, before any hardware test is started.
#
!if $d(CARD_BTP)

CARDTYPE = btp
CARDNAME = 3C509B-TP
HWCW004_TARGET = hwcw004
HWCW006_TARGET = hwcw006
HWCW008_TARGET = hwcw008-btp

!if $d(ROM_TEST)
HWCW051_TARGET = hwcw-rom-not-implemented
!else
HWCW051_TARGET = hwcw-rom-disabled
!endif

!elif $d(CARD_BCOAX)

CARDTYPE = bcoax
CARDNAME = 3C509B-COAX
DEFAULT_TRANSCEIVER = AUI
HWCW004_TARGET = hwcw004
HWCW006_TARGET =
HWCW008_TARGET = hwcw008-bcoax
!if $d(ROM_TEST)
HWCW051_TARGET = hwcw-rom-not-implemented
!else
HWCW051_TARGET = hwcw-rom-disabled
!endif

!elif $d(CARD_BCOMBO)

CARDTYPE = bcombo
CARDNAME = 3C509B-Combo
HWCW004_TARGET = hwcw004
HWCW006_TARGET = hwcw006
HWCW008_TARGET = hwcw008-bcombo
!if $d(ROM_TEST)
HWCW051_TARGET = hwcw-rom-not-implemented
!else
HWCW051_TARGET = hwcw-rom-disabled
!endif

!elif $d(CARD_BTPO)

CARDTYPE = btpo
CARDNAME = 3C509B-TPO
HWCW004_TARGET = hwcw004
HWCW006_TARGET = hwcw006
HWCW008_TARGET =
!if $d(ROM_TEST)
# Boot ROM is anyway unsupported for 3C509B-TPO model.
HWCW051_TARGET = hwcw-rom-unsupported
!else
HWCW051_TARGET = hwcw-rom-disabled
!endif

!elif $d(CARD_BTPC)

CARDTYPE = btpc
CARDNAME = 3C509B-TPCoax
HWCW004_TARGET = hwcw004
HWCW006_TARGET = hwcw006
HWCW008_TARGET = hwcw008-btpc
!if $d(ROM_TEST)
HWCW051_TARGET = hwcw-rom-not-implemented
!else
HWCW051_TARGET = hwcw-rom-disabled
!endif

!elif $d(CARD_TP)

CARDTYPE = tp
CARDNAME = 3C509-TP
HWCW004_TARGET =
HWCW006_TARGET =
HWCW008_TARGET = hwcw008-tp
!if $d(ROM_TEST)
HWCW051_TARGET = hwcw-rom-not-implemented
!else
HWCW051_TARGET = hwcw-rom-disabled
!endif

!else

!error No valid card model selected

!endif


# Set output directories and log files are derived from selected card type.
#
OUTDIR = $(CARDTYPE)
ARTIFACTS = $(OUTDIR)\ARTIFACT
LOGFILE = $(OUTDIR)\HWCWRITE.LOG


all:
	@echo Start the hardware compliance checks with HWCTEST.BAT.
	@echo Do not start HWCWRITE.MK directly.

prep:
	@if not exist $(OUTDIR)\NUL mkdir $(OUTDIR)
	@if not exist $(ARTIFACTS)\NUL mkdir $(ARTIFACTS)
	@echo Running 3CCFGCLI Hardware Compliance Write checks >> $(LOGFILE)
	@echo Running 3CCFGCLI Hardware Compliance Write checks

HWCW00xx:
	@echo [HWCW00xx] Hardware Compliance Write checks for $(CARDNAME) >> $(LOGFILE)
	@echo [HWCW00xx] Hardware Compliance Write checks for $(CARDNAME)

complete:
	@echo Hardware Compliance Write checks completed. >> $(LOGFILE)
	@echo Hardware Compliance Write checks completed.

clean:
	@echo Cleaning logs and test artifacts >> $(LOGFILE)
	@echo Cleaning logs and test artifacts
	@del $(ARTIFACTS)\*.*

# Full hardware compliance write run.
# Optional tests expand to an empty macro on
# models which do not support the corresponding capability.
HWCW_WRITE: HWCW00xx hwcw001 hwcw002 hwcw003 hwcw004 hwcw005 hwcw006 hwcw007 hwcw008 hwcw009 hwcw010 hwcw051
hwcw: clean prep HWCW00xx save-config set-default-$(CARDTYPE) hwcw001-$(CARDTYPE) hwcw002 hwcw003 $(HWCW004_TARGET) hwcw005 $(HWCW006_TARGET) hwcw007 $(HWCW008_TARGET) hwcw009-$(CARDTYPE) hwcw010 $(HWCW051_TARGET) complete

save-config:
	@echo Saving original adapter configuration to $(RESTOREBAT) >> $(LOGFILE)
	@echo Saving original adapter configuration to $(RESTOREBAT)
	$(READERAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\$(RESTOREBAT) /EXECFILE:%1 >> $(LOGFILE)
	FIND "Configuration restore batch file created:" $(LOGFILE) > NUL

restore-config:
	@echo Config restore via MAKE is broken on some earlier DOS versions. >> $(LOGFILE)
	@echo MAKE does not currently invoke the restore command itself for that reason. >> $(LOGFILE)
	@echo Please run the following command manually once to restore the original configuration. >> $(LOGFILE)
	@echo Config restore via MAKE is broken on some earlier DOS versions.
	@echo MAKE does not currently invoke the restore command itself for that reason.
	@echo Please run the following command manually once to restore the original configuration.
	@echo $(ARTIFACTS)\$(RESTOREBAT) $(REFERENCEAPP) >> $(LOGFILE)
	@echo $(ARTIFACTS)\$(RESTOREBAT) $(REFERENCEAPP)

restore: restore-config

# #################################
# Set default baselines for different adapter types.
# #################################

set-default-common:
	@echo [set-default].[common] Writing $(CARDNAME) baseline via original utility >> $(LOGFILE)
	@echo [set-default].[common] Writing $(CARDNAME) baseline via original utility
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /TR:$(DEFAULT_TRANSCEIVER) > $(ARTIFACTS)\HWCWSET.LOG
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /INT:$(DEFAULT_IRQ) /IOBASE:$(DEFAULT_IOBASE) >> $(ARTIFACTS)\HWCWSET.LOG
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:$(DEFAULT_MODEM) /OPTIMIZE:$(DEFAULT_OPTIMIZE) >> $(ARTIFACTS)\HWCWSET.LOG

set-default-btp: set-default-common
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /PNP:$(DEFAULT_PNP) >> $(ARTIFACTS)\HWCWSET.LOG
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:$(DEFAULT_FULLDUPLEX) >> $(ARTIFACTS)\HWCWSET.LOG
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /BSIZE:DISABLED >> $(ARTIFACTS)\HWCWSET.LOG
	@echo [set-default].[btp] PASSED >> $(LOGFILE)
	@echo [set-default].[btp] PASSED

# NOTE: does NOT include /FULLDUPLEX verb because 3C509B-COAX does not support it
set-default-bcoax: set-default-common
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /PNP:$(DEFAULT_PNP) >> $(ARTIFACTS)\HWCWSET.LOG
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /BSIZE:DISABLED >> $(ARTIFACTS)\HWCWSET.LOG
	@echo [set-default].[bcoax] PASSED >> $(LOGFILE)
	@echo [set-default].[bcoax] PASSED

set-default-bcombo: set-default-common
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /PNP:$(DEFAULT_PNP) >> $(ARTIFACTS)\HWCWSET.LOG
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:$(DEFAULT_FULLDUPLEX) >> $(ARTIFACTS)\HWCWSET.LOG
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /BSIZE:DISABLED >> $(ARTIFACTS)\HWCWSET.LOG
	@echo [set-default].[bcombo] PASSED >> $(LOGFILE)
	@echo [set-default].[bcombo] PASSED

# NOTE: does NOT inlcude /BSIZE:DISABLED verb because 3C509B-TPO does not support ROM
set-default-btpo: set-default-common
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /PNP:$(DEFAULT_PNP) >> $(ARTIFACTS)\HWCWSET.LOG
	@echo [set-default].[btpo] PASSED >> $(LOGFILE)
	@echo [set-default].[btpo] PASSED

set-default-btpc: set-default-common
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /PNP:$(DEFAULT_PNP) >> $(ARTIFACTS)\HWCWSET.LOG
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:$(DEFAULT_FULLDUPLEX) >> $(ARTIFACTS)\HWCWSET.LOG
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /BSIZE:DISABLED >> $(ARTIFACTS)\HWCWSET.LOG
	@echo [set-default].[btpc] PASSED >> $(LOGFILE)
	@echo [set-default].[btpc] PASSED

# NOTE: does NOT include /FULLDUPLEX and /PNP verbs because 3C509-TP does not support it
set-default-tp: set-default-common
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /BSIZE:DISABLED >> $(ARTIFACTS)\HWCWSET.LOG
	@echo [set-default].[tp] PASSED >> $(LOGFILE)
	@echo [set-default].[tp] PASSED

# #################################
# Identity / capability checks.
# #################################

# Canonical testcase stub for testreport.py.
#
# the hwcw001 target is never actually called, it's only here for structure.
# Runtime output is emitted by the card-specific targets further below.
hwcw001:
	@echo [hwcw001] Reading $(CARDNAME) identity and capabilities > NUL

hwcw001-common:
	@echo [hwcw001].[common] Reading $(CARDNAME) identity and capabilities >> $(LOGFILE)
	@echo [hwcw001].[common] Reading $(CARDNAME) identity and capabilities
	$(READERAPP) LIST > $(ARTIFACTS)\HWCW001.LOG

hwcw001-btp: hwcw001-common
	FIND "3Com 3C509B-TP:" $(ARTIFACTS)\HWCW001.LOG > NUL
	FIND "(ASIC Revision 2)" $(ARTIFACTS)\HWCW001.LOG > NUL
	FIND "Connectors = TP, AUI" $(ARTIFACTS)\HWCW001.LOG > NUL
	FIND "Plug and Play Capability = yes" $(ARTIFACTS)\HWCW001.LOG > NUL
	FIND "Full Duplex Capability = yes" $(ARTIFACTS)\HWCW001.LOG > NUL
	@echo [hwcw001].[btp] PASSED >> $(LOGFILE)
	@echo [hwcw001].[btp] PASSED

hwcw001-bcoax: hwcw001-common
	FIND "3Com 3C509B:" $(ARTIFACTS)\HWCW001.LOG > NUL
	FIND "(ASIC Revision 2)" $(ARTIFACTS)\HWCW001.LOG > NUL
	FIND "Connectors = AUI, COAX" $(ARTIFACTS)\HWCW001.LOG > NUL
	FIND "Plug and Play Capability = yes" $(ARTIFACTS)\HWCW001.LOG > NUL
	FIND "Full Duplex Capability = no" $(ARTIFACTS)\HWCW001.LOG > NUL
	@echo [hwcw001].[bcoax] PASSED >> $(LOGFILE)
	@echo [hwcw001].[bcoax] PASSED

hwcw001-bcombo: hwcw001-common
	FIND "3Com 3C509B-Combo:" $(ARTIFACTS)\HWCW001.LOG > NUL
	FIND "(ASIC Revision 2)" $(ARTIFACTS)\HWCW001.LOG > NUL
	FIND "Connectors = TP, AUI, COAX" $(ARTIFACTS)\HWCW001.LOG > NUL
	FIND "Plug and Play Capability = yes" $(ARTIFACTS)\HWCW001.LOG > NUL
	FIND "Full Duplex Capability = yes" $(ARTIFACTS)\HWCW001.LOG > NUL
	@echo [hwcw001].[bcombo] PASSED >> $(LOGFILE)
	@echo [hwcw001].[bcombo] PASSED

hwcw001-btpo: hwcw001-common
	FIND "3Com 3C509B-TPO:" $(ARTIFACTS)\HWCW001.LOG > NUL
	FIND "(ASIC Revision 2)" $(ARTIFACTS)\HWCW001.LOG > NUL
	FIND "Connectors = TP" $(ARTIFACTS)\HWCW001.LOG > NUL
	FIND "Plug and Play Capability = yes" $(ARTIFACTS)\HWCW001.LOG > NUL
	FIND "Full Duplex Capability = yes" $(ARTIFACTS)\HWCW001.LOG > NUL
	@echo [hwcw001].[btpo] PASSED >> $(LOGFILE)
	@echo [hwcw001].[btpo] PASSED

hwcw001-btpc: hwcw001-common
	FIND "3Com 3C509B-TPCoax:" $(ARTIFACTS)\HWCW001.LOG > NUL
	FIND "(ASIC Revision 2)" $(ARTIFACTS)\HWCW001.LOG > NUL
	FIND "Connectors = TP, COAX" $(ARTIFACTS)\HWCW001.LOG > NUL
	FIND "Plug and Play Capability = yes" $(ARTIFACTS)\HWCW001.LOG > NUL
	FIND "Full Duplex Capability = yes" $(ARTIFACTS)\HWCW001.LOG > NUL
	@echo [hwcw001].[btpc] PASSED >> $(LOGFILE)
	@echo [hwcw001].[btpc] PASSED

hwcw001-tp: hwcw001-common
	FIND "3Com 3C509-TP:" $(ARTIFACTS)\HWCW001.LOG > NUL
	FIND "(ASIC Revision 1)" $(ARTIFACTS)\HWCW001.LOG > NUL
	FIND "Connectors = TP, AUI" $(ARTIFACTS)\HWCW001.LOG > NUL
	FIND "Plug and Play Capability = not supported" $(ARTIFACTS)\HWCW001.LOG > NUL
	FIND "Full Duplex Capability = not supported" $(ARTIFACTS)\HWCW001.LOG > NUL
	@echo [hwcw001].[tp] PASSED >> $(LOGFILE)
	@echo [hwcw001].[tp] PASSED

# #################################
# Individual physical write checks.
# #################################

hwcw002:
	@echo [hwcw002] 3CCFGCLI /INT writer, fresh LIST readback >> $(LOGFILE)
	@echo [hwcw002] 3CCFGCLI /INT writer, fresh LIST readback
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /INT:$(TEST_IRQ) > $(ARTIFACTS)\HWCW002.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCW002.LOG
	FIND "IRQ = $(TEST_IRQ)" $(ARTIFACTS)\HWCW002.LOG > NUL
	@echo [hwcw002] PASSED >> $(LOGFILE)
	@echo [hwcw002] PASSED

hwcw003:
	@echo [hwcw003] 3CCFGCLI /IOBASE writer, fresh LIST readback >> $(LOGFILE)
	@echo [hwcw003] 3CCFGCLI /IOBASE writer, fresh LIST readback
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /IOBASE:$(TEST_IOBASE) > $(ARTIFACTS)\HWCW003.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCW003.LOG
	FIND "IOBASE = $(TEST_IOBASE)" $(ARTIFACTS)\HWCW003.LOG > NUL
	@echo [hwcw003] PASSED >> $(LOGFILE)
	@echo [hwcw003] PASSED

hwcw004:
	@echo [hwcw004] 3CCFGCLI /PNP writer, fresh LIST readback >> $(LOGFILE)
	@echo [hwcw004] 3CCFGCLI /PNP writer, fresh LIST readback
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /PNP:$(TEST_PNP) > $(ARTIFACTS)\HWCW004.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCW004.LOG
	FIND "Plug and Play = disabled" $(ARTIFACTS)\HWCW004.LOG > NUL
	@echo [hwcw004] PASSED >> $(LOGFILE)
	@echo [hwcw004] PASSED

hwcw005:
	@echo [hwcw005] 3CCFGCLI /MODEM writer, fresh LIST readback >> $(LOGFILE)
	@echo [hwcw005] 3CCFGCLI /MODEM writer, fresh LIST readback
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:$(TEST_MODEM) > $(ARTIFACTS)\HWCW005.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCW005.LOG
	FIND "MODEM Interrupt Disable Time = 1300 us (1200 bd)" $(ARTIFACTS)\HWCW005.LOG > NUL
	@echo [hwcw005] PASSED >> $(LOGFILE)
	@echo [hwcw005] PASSED

hwcw006:
	@echo [hwcw006] 3CCFGCLI /FULLDUPLEX writer, fresh LIST readback >> $(LOGFILE)
	@echo [hwcw006] 3CCFGCLI /FULLDUPLEX writer, fresh LIST readback
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:$(TEST_FULLDUPLEX) > $(ARTIFACTS)\HWCW006.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCW006.LOG
	FIND "Full Duplex = enabled" $(ARTIFACTS)\HWCW006.LOG > NUL
	@echo [hwcw006] PASSED >> $(LOGFILE)
	@echo [hwcw006] PASSED

hwcw007:
	@echo [hwcw007] 3CCFGCLI /OPTIMIZE writer, fresh LIST readback >> $(LOGFILE)
	@echo [hwcw007] 3CCFGCLI /OPTIMIZE writer, fresh LIST readback
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /OPTIMIZE:$(TEST_OPTIMIZE) > $(ARTIFACTS)\HWCW007.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCW007.LOG
	FIND "Optimization = Server" $(ARTIFACTS)\HWCW007.LOG > NUL
	@echo [hwcw007] PASSED >> $(LOGFILE)
	@echo [hwcw007] PASSED


# #################################
# Card-specific transceiver writes.
# #################################

# Canonical testcase stub for testreport.py.
#
# the hwcw008 target is never actually called, it's only here for structure.
# Runtime output is emitted by the card-specific further below.
hwcw008:
	@echo [hwcw008] card specific transceiver tests > NUL

hwcw008-btp:
	@echo [hwcw008].[btp] 3CCFGCLI /TR:AUI writer, fresh LIST readback >> $(LOGFILE)
	@echo [hwcw008].[btp] 3CCFGCLI /TR:AUI writer, fresh LIST readback
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /TR:AUI > $(ARTIFACTS)\HWCW008.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCW008.LOG
	FIND "Transceiver = external" $(ARTIFACTS)\HWCW008.LOG > NUL
	@echo [hwcw008].[btp] PASSED >> $(LOGFILE)
	@echo [hwcw008].[btp] PASSED

hwcw008-bcoax:
	@echo [hwcw008].[bcoax] 3CCFGCLI /TR:COAX writer, fresh LIST readback >> $(LOGFILE)
	@echo [hwcw008].[bcoax] 3CCFGCLI /TR:COAX writer, fresh LIST readback
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /TR:COAX > $(ARTIFACTS)\HWCW008.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCW008.LOG
	FIND "Transceiver = on-board coax" $(ARTIFACTS)\HWCW008.LOG > NUL
	@echo [hwcw008].[bcoax] PASSED >> $(LOGFILE)
	@echo [hwcw008].[bcoax] PASSED

hwcw008-bcombo:
	@echo [hwcw008].[bcombo] 3CCFGCLI /TR:COAX writer, fresh LIST readback >> $(LOGFILE)
	@echo [hwcw008].[bcombo] 3CCFGCLI /TR:COAX writer, fresh LIST readback
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /TR:COAX > $(ARTIFACTS)\HWCW008.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCW008.LOG
	FIND "Transceiver = on-board coax" $(ARTIFACTS)\HWCW008.LOG > NUL
	@echo [hwcw008].[bcombo] PASSED >> $(LOGFILE)
	@echo [hwcw008].[bcombo] PASSED

hwcw008-btpc:
	@echo [hwcw008].[btpc] 3CCFGCLI /TR:COAX writer, fresh LIST readback >> $(LOGFILE)
	@echo [hwcw008].[btpc] 3CCFGCLI /TR:COAX writer, fresh LIST readback
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /TR:COAX > $(ARTIFACTS)\HWCW008.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCW008.LOG
	FIND "Transceiver = on-board coax" $(ARTIFACTS)\HWCW008.LOG > NUL
	@echo [hwcw008].[btpc] PASSED >> $(LOGFILE)
	@echo [hwcw008].[btpc] PASSED

hwcw008-tp:
	@echo [hwcw008].[tp] 3CCFGCLI /TR:AUI writer, fresh LIST readback >> $(LOGFILE)
	@echo [hwcw008].[tp] 3CCFGCLI /TR:AUI writer, fresh LIST readback
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /TR:AUI > $(ARTIFACTS)\HWCW008.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCW008.LOG
	FIND "Transceiver = external" $(ARTIFACTS)\HWCW008.LOG > NUL
	@echo [hwcw008].[tp] PASSED >> $(LOGFILE)
	@echo [hwcw008].[tp] PASSED



# #################################
# SAVECONFIG readback.
# #################################

# Canonical testcase stub for testreport.py.
#
# the hwcw009 target is never actually called, it's only here for structure.
# Runtime output is emitted by the card-specific further below.
hwcw009:
	@echo [hwcw009] SAVECONFIG readback > NUL

hwcw009-common:
	@echo [hwcw009].[common] Reading combined hardware state through SAVECONFIG >> $(LOGFILE)
	@echo [hwcw009].[common] Reading combined hardware state through SAVECONFIG
	$(READERAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\HWCW009.BAT > $(ARTIFACTS)\HWCW009.LOG
	FIND "Configuration restore batch file created:" $(ARTIFACTS)\HWCW009.LOG > NUL
	FIND "INT:$(TEST_IRQ)" $(ARTIFACTS)\HWCW009.BAT > NUL
	FIND "IOBASE:$(TEST_IOBASE)" $(ARTIFACTS)\HWCW009.BAT > NUL
	FIND "MODEM:$(TEST_MODEM)" $(ARTIFACTS)\HWCW009.BAT > NUL
	FIND "OPTIMIZE:$(TEST_OPTIMIZE)" $(ARTIFACTS)\HWCW009.BAT > NUL

hwcw009-btp: hwcw009-common
	FIND "PNP:DISABLED" $(ARTIFACTS)\HWCW009.BAT > NUL
	FIND "FULLDUPLEX:DISABLED" $(ARTIFACTS)\HWCW009.BAT > NUL
	FIND "BSIZE:DISABLED" $(ARTIFACTS)\HWCW009.BAT > NUL
	FIND "TR:AUI" $(ARTIFACTS)\HWCW009.BAT > NUL
	@echo [hwcw009].[btp] PASSED >> $(LOGFILE)
	@echo [hwcw009].[btp] PASSED

hwcw009-bcoax: hwcw009-common
	FIND "PNP:DISABLED" $(ARTIFACTS)\HWCW009.BAT > NUL
	FIND "BSIZE:DISABLED" $(ARTIFACTS)\HWCW009.BAT > NUL
	FIND "TR:COAX" $(ARTIFACTS)\HWCW009.BAT > NUL
	@echo [hwcw009].[bcoax] PASSED >> $(LOGFILE)
	@echo [hwcw009].[bcoax] PASSED

hwcw009-bcombo: hwcw009-common
	FIND "PNP:DISABLED" $(ARTIFACTS)\HWCW009.BAT > NUL
	FIND "FULLDUPLEX:DISABLED" $(ARTIFACTS)\HWCW009.BAT > NUL
	FIND "BSIZE:DISABLED" $(ARTIFACTS)\HWCW009.BAT > NUL
	FIND "TR:COAX" $(ARTIFACTS)\HWCW009.BAT > NUL
	@echo [hwcw009].[bcombo] PASSED >> $(LOGFILE)
	@echo [hwcw009].[bcombo] PASSED

hwcw009-btpo: hwcw009-common
	FIND "PNP:DISABLED" $(ARTIFACTS)\HWCW009.BAT > NUL
	FIND "FULLDUPLEX:DISABLED" $(ARTIFACTS)\HWCW009.BAT > NUL
	FIND "TR:TP" $(ARTIFACTS)\HWCW009.BAT > NUL
	@echo [hwcw009].[btpo] PASSED >> $(LOGFILE)
	@echo [hwcw009].[btpo] PASSED

hwcw009-btpc: hwcw009-common
	FIND "PNP:DISABLED" $(ARTIFACTS)\HWCW009.BAT > NUL
	FIND "FULLDUPLEX:DISABLED" $(ARTIFACTS)\HWCW009.BAT > NUL
	FIND "BSIZE:DISABLED" $(ARTIFACTS)\HWCW009.BAT > NUL
	FIND "TR:COAX" $(ARTIFACTS)\HWCW009.BAT > NUL
	@echo [hwcw009].[btpc] PASSED >> $(LOGFILE)
	@echo [hwcw009].[btpc] PASSED

hwcw009-tp: hwcw009-common
	FIND "TR:AUI" $(ARTIFACTS)\HWCW009.BAT > NUL
	@echo [hwcw009].[tp] PASSED >> $(LOGFILE)
	@echo [hwcw009].[tp] PASSED

# #################################
# Multi property physical transaction.
# #################################
#
# Re-establish the common defaults with the original utility, then write all
# four common TEST values in one 3CCFGCLI CONFIGURE transaction. This leaves
# the adapter in a clear, intentional final state for the independent vendor
# configuration dump performed by HWCTEST.BAT after this make run.

hwcw010:
	@echo [hwcw010] 3CCFGCLI multi-property CONFIGURE transaction >> $(LOGFILE)
	@echo [hwcw010] 3CCFGCLI multi-property CONFIGURE transaction
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /INT:$(DEFAULT_IRQ) /IOBASE:$(DEFAULT_IOBASE) /MODEM:$(DEFAULT_MODEM) /OPTIMIZE:$(DEFAULT_OPTIMIZE) > $(ARTIFACTS)\HWCW010.LOG
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /INT:$(TEST_IRQ) /IOBASE:$(TEST_IOBASE) /MODEM:$(TEST_MODEM) /OPTIMIZE:$(TEST_OPTIMIZE) >> $(ARTIFACTS)\HWCW010.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCW010.LOG
	FIND "IOBASE = $(TEST_IOBASE), IRQ = $(TEST_IRQ)" $(ARTIFACTS)\HWCW010.LOG > NUL
	FIND "MODEM Interrupt Disable Time = 1300 us (1200 bd)" $(ARTIFACTS)\HWCW010.LOG > NUL
	FIND "Optimization = Server" $(ARTIFACTS)\HWCW010.LOG > NUL
	@echo [hwcw010] PASSED >> $(LOGFILE)
	@echo [hwcw010] PASSED


# #################################
# Optional physical Boot ROM test.
# #################################

hwcw-rom-unsupported:
	@echo [hwcw051] Boot ROM is not supported on $(CARDNAME). >> $(LOGFILE)
	@echo [hwcw051] Boot ROM is not supported on $(CARDNAME).
	@echo [hwcw051] NOT SUPPORTED >> $(LOGFILE)
	@echo [hwcw051] NOT SUPPORTED

hwcw-rom-not-implemented:
	@echo [hwcw051] Boot ROM testing is currently not implemented for $(CARDNAME). >> $(LOGFILE)
	@echo [hwcw051] Boot ROM testing is currently not implemented for $(CARDNAME).
	@echo [hwcw051] NOT IMPLEMENTED >> $(LOGFILE)
	@echo [hwcw051] NOT IMPLEMENTED

hwcw-rom-disabled:
	@echo [hwcw051] Boot ROM testing is currently disabled for $(CARDNAME). >> $(LOGFILE)
	@echo [hwcw051] Boot ROM testing is currently disabled for $(CARDNAME).
	@echo [hwcw051] DISABLED >> $(LOGFILE)
	@echo [hwcw051] DISABLED

hwcw051:
	@echo [hwcw051] 3CCFGCLI Boot ROM writer, fresh LIST/SAVECONFIG readback >> $(LOGFILE)
	@echo [hwcw051] 3CCFGCLI Boot ROM writer, fresh LIST/SAVECONFIG readback
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:$(TEST_BADDRESS) /BSIZE:$(TEST_BSIZE) > $(ARTIFACTS)\HWCW051.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCW051.LOG
	FIND "Boot ROM = $(TEST_BSIZE)K at $(TEST_BADDRESS)H" $(ARTIFACTS)\HWCW051.LOG > NUL
	$(READERAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\HWCW051.BAT >> $(ARTIFACTS)\HWCW051.LOG
	FIND "BADDRESS:$(TEST_BADDRESS)" $(ARTIFACTS)\HWCW051.BAT > NUL
	FIND "BSIZE:$(TEST_BSIZE)" $(ARTIFACTS)\HWCW051.BAT > NUL
	@echo [hwcw051] PASSED >> $(LOGFILE)
	@echo [hwcw051] PASSED
