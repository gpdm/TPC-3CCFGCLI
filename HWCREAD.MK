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
# If a run aborts after writes have started:
#   MAKE -fHWCREAD.MK CARDTYPE=<type> restore-config
#

# Utility definitions 
RESTOREBAT = HWCRREST.BAT
WRITERAPP = 3C5X9CFG.EXE
READERAPP = 3CCFGCLI.EXE

# Output directories and log files are defined further below
# as they are defined based on the selected card type.
# Consequentally, the definition can only happend after
# processing the card type selection.
#
# ## OUTDIR = $(CARDTYPE)
# ## ARTIFACTS = $(OUTDIR)\ARTIFACT
# ## LOGFILE = $(OUTDIR)\HWCREAD.LOG

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
#   MAKE -fHWCREAD.MK CARD_BTP=1 hwcr
#
# Map the detected card type to the human readable model name and to the
# optional tests supported by that model. Unknown card types are rejected
# while the makefile is parsed, before any hardware test is started.
#
!if $d(CARD_BTP)

CARDTYPE = btp
CARDNAME = 3C509B-TP
HWCR004_TARGET = hwcr004
HWCR006_TARGET = hwcr006
HWCR008_TARGET = hwcr008-btp

!if $d(ROM_TEST)
HWCR051_TARGET = hwcr-rom-not-implemented
!else
HWCR051_TARGET = hwcr-rom-disabled
!endif

!elif $d(CARD_BCOAX)

CARDTYPE = bcoax
CARDNAME = 3C509B-COAX
DEFAULT_TRANSCEIVER = AUI
HWCR004_TARGET = hwcr004
HWCR006_TARGET =
HWCR008_TARGET = hwcr008-bcoax
!if $d(ROM_TEST)
HWCR051_TARGET = hwcr-rom-not-implemented
!else
HWCR051_TARGET = hwcr-rom-disabled
!endif

!elif $d(CARD_BCOMBO)

CARDTYPE = bcombo
CARDNAME = 3C509B-Combo
HWCR004_TARGET = hwcr004
HWCR006_TARGET = hwcr006
HWCR008_TARGET = hwcr008-bcombo
!if $d(ROM_TEST)
HWCR051_TARGET = hwcr-rom-not-implemented
!else
HWCR051_TARGET = hwcr-rom-disabled
!endif

!elif $d(CARD_BTPO)

CARDTYPE = btpo
CARDNAME = 3C509B-TPO
HWCR004_TARGET = hwcr004
HWCR006_TARGET = hwcr006
HWCR008_TARGET =
!if $d(ROM_TEST)
# Boot ROM is anyway unsupported for 3C509B-TPO model.
HWCR051_TARGET = hwcr-rom-unsupported
!else
HWCR051_TARGET = hwcr-rom-disabled
!endif

!elif $d(CARD_BTPC)

CARDTYPE = btpc
CARDNAME = 3C509B-TPCoax
HWCR004_TARGET = hwcr004
HWCR006_TARGET = hwcr006
HWCR008_TARGET = hwcr008-btpc
!if $d(ROM_TEST)
HWCR051_TARGET = hwcr-rom-not-implemented
!else
HWCR051_TARGET = hwcr-rom-disabled
!endif

!elif $d(CARD_TP)

CARDTYPE = tp
CARDNAME = 3C509-TP
HWCR004_TARGET =
HWCR006_TARGET =
HWCR008_TARGET = hwcr008-tp
!if $d(ROM_TEST)
HWCR051_TARGET = hwcr-rom-not-implemented
!else
HWCR051_TARGET = hwcr-rom-disabled
!endif

!else

!error No valid card model selected

!endif


# Set output directories and log files are derived from selected card type.
#
OUTDIR = $(CARDTYPE)
ARTIFACTS = $(OUTDIR)\ARTIFACT
LOGFILE = $(OUTDIR)\HWCREAD.LOG


all:
	@echo Start the hardware compliance checks with HWCTEST.BAT.
	@echo Do not start HWCREAD.MK directly.

prep:
	@if not exist $(OUTDIR)\NUL mkdir $(OUTDIR)
	@if not exist $(ARTIFACTS)\NUL mkdir $(ARTIFACTS)
	@echo Running 3CCFGCLI Hardware Compliance Read checks >> $(LOGFILE)
	@echo Running 3CCFGCLI Hardware Compliance Read checks

HWCR00xx:
	@echo [HWCR00xx] Hardware Compliance Read checks for $(CARDNAME) >> $(LOGFILE)
	@echo [HWCR00xx] Hardware Compliance Read checks for $(CARDNAME)

complete:
	@echo Hardware Compliance Read checks completed. >> $(LOGFILE)
	@echo Hardware Compliance Read checks completed.

clean:
	@echo Cleaning logs and test artifacts >> $(LOGFILE)
	@echo Cleaning logs and test artifacts
	@del $(ARTIFACTS)\*.*

# Full hardware compliance read run.
# Optional tests expand to an empty macro on
# models which do not support the corresponding capability.
HWCR_READ: HWCR00xx hwcr001 hwcr002 hwcr003 hwcr004 hwcr005 hwcr006 hwcr007 hwcr008 hwcr009 $(HWCR051_TARGET)
hwcr: clean prep HWCR00xx save-config set-default-$(CARDTYPE) hwcr001-$(CARDTYPE) hwcr002 hwcr003 $(HWCR004_TARGET) hwcr005 $(HWCR006_TARGET) hwcr007 $(HWCR008_TARGET) hwcr009-$(CARDTYPE) $(HWCR051_TARGET) complete

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
	@echo $(ARTIFACTS)\$(RESTOREBAT) $(WRITERAPP) >> $(LOGFILE)
	@echo $(ARTIFACTS)\$(RESTOREBAT) $(WRITERAPP)

restore: restore-config

# #################################
# Set default baselines for different adapter types.
# #################################

set-default-common:
	@echo [set-default].[common] Writing $(CARDNAME) baseline via original utility >> $(LOGFILE)
	@echo [set-default].[common] Writing $(CARDNAME) baseline via original utility
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /TR:$(DEFAULT_TRANSCEIVER) > $(ARTIFACTS)\HWCRSET.LOG
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /INT:$(DEFAULT_IRQ) /IOBASE:$(DEFAULT_IOBASE) >> $(ARTIFACTS)\HWCRSET.LOG
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:$(DEFAULT_MODEM) /OPTIMIZE:$(DEFAULT_OPTIMIZE) >> $(ARTIFACTS)\HWCRSET.LOG

set-default-btp: set-default-common
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /PNP:$(DEFAULT_PNP) >> $(ARTIFACTS)\HWCRSET.LOG
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:$(DEFAULT_FULLDUPLEX) >> $(ARTIFACTS)\HWCRSET.LOG
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /BSIZE:DISABLED >> $(ARTIFACTS)\HWCRSET.LOG
	@echo [set-default].[btp] PASSED >> $(LOGFILE)
	@echo [set-default].[btp] PASSED

# NOTE: does NOT include /FULLDUPLEX verb because 3C509B-COAX does not support it
set-default-bcoax: set-default-common
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /PNP:$(DEFAULT_PNP) >> $(ARTIFACTS)\HWCRSET.LOG
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /BSIZE:DISABLED >> $(ARTIFACTS)\HWCRSET.LOG
	@echo [set-default].[bcoax] PASSED >> $(LOGFILE)
	@echo [set-default].[bcoax] PASSED

set-default-bcombo: set-default-common
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /PNP:$(DEFAULT_PNP) >> $(ARTIFACTS)\HWCRSET.LOG
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:$(DEFAULT_FULLDUPLEX) >> $(ARTIFACTS)\HWCRSET.LOG
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /BSIZE:DISABLED >> $(ARTIFACTS)\HWCRSET.LOG
	@echo [set-default].[bcombo] PASSED >> $(LOGFILE)
	@echo [set-default].[bcombo] PASSED

# NOTE: does NOT inlcude /BSIZE:DISABLED verb because 3C509B-TPO does not support ROM
set-default-btpo: set-default-common
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /PNP:$(DEFAULT_PNP) >> $(ARTIFACTS)\HWCRSET.LOG
	@echo [set-default].[btpo] PASSED >> $(LOGFILE)
	@echo [set-default].[btpo] PASSED

set-default-btpc: set-default-common
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /PNP:$(DEFAULT_PNP) >> $(ARTIFACTS)\HWCRSET.LOG
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:$(DEFAULT_FULLDUPLEX) >> $(ARTIFACTS)\HWCRSET.LOG
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /BSIZE:DISABLED >> $(ARTIFACTS)\HWCRSET.LOG
	@echo [set-default].[btpc] PASSED >> $(LOGFILE)
	@echo [set-default].[btpc] PASSED

# NOTE: does NOT include /FULLDUPLEX and /PNP verbs because 3C509-TP does not support it
set-default-tp: set-default-common
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /BSIZE:DISABLED >> $(ARTIFACTS)\HWCRSET.LOG
	@echo [set-default].[tp] PASSED >> $(LOGFILE)
	@echo [set-default].[tp] PASSED


# #################################
# Identity / capability checks.
# #################################

# Canonical testcase stub for testreport.py.
#
# the hwcr001 target is never actually called, it's only here for structure.
# Runtime output is emitted by the card-specific targets further below.
hwcr001:
	@echo [hwcr001] Reading $(CARDNAME) identity and capabilities > NUL

hwcr001-common:
	@echo [hwcr001].[common] Reading $(CARDNAME) identity and capabilities >> $(LOGFILE)
	@echo [hwcr001].[common] Reading $(CARDNAME) identity and capabilities
	$(READERAPP) LIST > $(ARTIFACTS)\HWCR001.LOG

hwcr001-btp: hwcr001-common
	FIND "3Com 3C509B-TP:" $(ARTIFACTS)\HWCR001.LOG > NUL
	FIND "(ASIC Revision 2)" $(ARTIFACTS)\HWCR001.LOG > NUL
	FIND "Connectors = TP, AUI" $(ARTIFACTS)\HWCR001.LOG > NUL
	FIND "Plug and Play Capability = yes" $(ARTIFACTS)\HWCR001.LOG > NUL
	FIND "Full Duplex Capability = yes" $(ARTIFACTS)\HWCR001.LOG > NUL
	@echo [hwcr001].[btp] PASSED >> $(LOGFILE)
	@echo [hwcr001].[btp] PASSED

hwcr001-bcoax: hwcr001-common
	FIND "3Com 3C509B:" $(ARTIFACTS)\HWCR001.LOG > NUL
	FIND "(ASIC Revision 2)" $(ARTIFACTS)\HWCR001.LOG > NUL
	FIND "Connectors = AUI, COAX" $(ARTIFACTS)\HWCR001.LOG > NUL
	FIND "Plug and Play Capability = yes" $(ARTIFACTS)\HWCR001.LOG > NUL
	FIND "Full Duplex Capability = no" $(ARTIFACTS)\HWCR001.LOG > NUL
	@echo [hwcr001].[bcoax] PASSED >> $(LOGFILE)
	@echo [hwcr001].[bcoax] PASSED

hwcr001-bcombo: hwcr001-common
	FIND "3Com 3C509B-Combo:" $(ARTIFACTS)\HWCR001.LOG > NUL
	FIND "(ASIC Revision 2)" $(ARTIFACTS)\HWCR001.LOG > NUL
	FIND "Connectors = TP, AUI, COAX" $(ARTIFACTS)\HWCR001.LOG > NUL
	FIND "Plug and Play Capability = yes" $(ARTIFACTS)\HWCR001.LOG > NUL
	FIND "Full Duplex Capability = yes" $(ARTIFACTS)\HWCR001.LOG > NUL
	@echo [hwcr001].[bcombo] PASSED >> $(LOGFILE)
	@echo [hwcr001].[bcombo] PASSED

hwcr001-btpo: hwcr001-common
	FIND "3Com 3C509B-TPO:" $(ARTIFACTS)\HWCR001.LOG > NUL
	FIND "(ASIC Revision 2)" $(ARTIFACTS)\HWCR001.LOG > NUL
	FIND "Connectors = TP" $(ARTIFACTS)\HWCR001.LOG > NUL
	FIND "Plug and Play Capability = yes" $(ARTIFACTS)\HWCR001.LOG > NUL
	FIND "Full Duplex Capability = yes" $(ARTIFACTS)\HWCR001.LOG > NUL
	@echo [hwcr001].[btpo] PASSED >> $(LOGFILE)
	@echo [hwcr001].[btpo] PASSED

hwcr001-btpc: hwcr001-common
	FIND "3Com 3C509B-TPCoax:" $(ARTIFACTS)\HWCR001.LOG > NUL
	FIND "(ASIC Revision 2)" $(ARTIFACTS)\HWCR001.LOG > NUL
	FIND "Connectors = TP, COAX" $(ARTIFACTS)\HWCR001.LOG > NUL
	FIND "Plug and Play Capability = yes" $(ARTIFACTS)\HWCR001.LOG > NUL
	FIND "Full Duplex Capability = yes" $(ARTIFACTS)\HWCR001.LOG > NUL
	@echo [hwcr001].[btpc] PASSED >> $(LOGFILE)
	@echo [hwcr001].[btpc] PASSED

hwcr001-tp: hwcr001-common
	@echo [hwcr001].[tp] Reading 3C509-TP identity and capabilities >> $(LOGFILE)
	@echo [hwcr001].[tp] Reading 3C509-TP identity and capabilities
	$(READERAPP) LIST > $(ARTIFACTS)\HWCR001.LOG
	FIND "3Com 3C509-TP:" $(ARTIFACTS)\HWCR001.LOG > NUL
	FIND "(ASIC Revision 1)" $(ARTIFACTS)\HWCR001.LOG > NUL
	FIND "Connectors = TP, AUI" $(ARTIFACTS)\HWCR001.LOG > NUL
	FIND "Plug and Play Capability = not supported" $(ARTIFACTS)\HWCR001.LOG > NUL
	FIND "Full Duplex Capability = not supported" $(ARTIFACTS)\HWCR001.LOG > NUL
	@echo [hwcr001].[tp] PASSED >> $(LOGFILE)
	@echo [hwcr001].[tp] PASSED


# #################################
# Common property readback tests.
# #################################

hwcr002:
	@echo [hwcr002] 9c5x9cfg /INT writer, 3CCFGCLI LIST reader >> $(LOGFILE)
	@echo [hwcr002] 9c5x9cfg /INT writer, 3CCFGCLI LIST reader
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /INT:$(TEST_IRQ) > $(ARTIFACTS)\HWCR002.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCR002.LOG
	FIND "IRQ = $(TEST_IRQ)" $(ARTIFACTS)\HWCR002.LOG > NUL
	@echo [hwcr002] PASSED >> $(LOGFILE)
	@echo [hwcr002] PASSED

hwcr003:
	@echo [hwcr003] 9c5x9cfg /IOBASE writer, 3CCFGCLI LIST reader >> $(LOGFILE)
	@echo [hwcr003] 9c5x9cfg /IOBASE writer, 3CCFGCLI LIST reader
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /IOBASE:$(TEST_IOBASE) > $(ARTIFACTS)\HWCR003.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCR003.LOG
	FIND "IOBASE = $(TEST_IOBASE)" $(ARTIFACTS)\HWCR003.LOG > NUL
	@echo [hwcr003] PASSED >> $(LOGFILE)
	@echo [hwcr003] PASSED

hwcr004:
	@echo [hwcr004] 9c5x9cfg /PNP writer, 3CCFGCLI LIST reader >> $(LOGFILE)
	@echo [hwcr004] 9c5x9cfg /PNP writer, 3CCFGCLI LIST reader
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /PNP:$(TEST_PNP) > $(ARTIFACTS)\HWCR004.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCR004.LOG
	FIND "Plug and Play = disabled" $(ARTIFACTS)\HWCR004.LOG > NUL
	@echo [hwcr004] PASSED >> $(LOGFILE)
	@echo [hwcr004] PASSED

hwcr005:
	@echo [hwcr005] 9c5x9cfg /MODEM writer, 3CCFGCLI LIST reader >> $(LOGFILE)
	@echo [hwcr005] 9c5x9cfg /MODEM writer, 3CCFGCLI LIST reader
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:$(TEST_MODEM) > $(ARTIFACTS)\HWCR005.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCR005.LOG
	FIND "MODEM Interrupt Disable Time = 1300 us (1200 bd)" $(ARTIFACTS)\HWCR005.LOG > NUL
	@echo [hwcr005] PASSED >> $(LOGFILE)
	@echo [hwcr005] PASSED

hwcr006:
	@echo [hwcr006] 9c5x9cfg /FULLDUPLEX writer, 3CCFGCLI LIST reader >> $(LOGFILE)
	@echo [hwcr006] 9c5x9cfg /FULLDUPLEX writer, 3CCFGCLI LIST reader
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:ENABLED > $(ARTIFACTS)\HWCR006.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCR006.LOG
	FIND "Full Duplex = enabled" $(ARTIFACTS)\HWCR006.LOG > NUL
	@echo [hwcr006] PASSED >> $(LOGFILE)
	@echo [hwcr006] PASSED

hwcr007:
	@echo [hwcr007] 9c5x9cfg /OPTIMIZE writer, 3CCFGCLI LIST reader >> $(LOGFILE)
	@echo [hwcr007] 9c5x9cfg /OPTIMIZE writer, 3CCFGCLI LIST reader
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /OPTIMIZE:$(TEST_OPTIMIZE) > $(ARTIFACTS)\HWCR007.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCR007.LOG
	FIND "Optimization = Server" $(ARTIFACTS)\HWCR007.LOG > NUL
	@echo [hwcr007] PASSED >> $(LOGFILE)
	@echo [hwcr007] PASSED


# #################################
# Card-specific transceiver tests.
# #################################

# Canonical testcase stub for testreport.py.
#
# the hwcr008 target is never actually called, it's only here for structure.
# Runtime output is emitted by the card-specific further below.
hwcr008:
	@echo [hwcr008] card specific transceiver tests > NUL

hwcr008-btp:
	@echo [hwcr008].[btp] 9c5x9cfg /TR:AUI writer, 3CCFGCLI LIST reader >> $(LOGFILE)
	@echo [hwcr008].[btp] 9c5x9cfg /TR:AUI writer, 3CCFGCLI LIST reader
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /TR:AUI > $(ARTIFACTS)\HWCR008.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCR008.LOG
	FIND "Transceiver = external" $(ARTIFACTS)\HWCR008.LOG > NUL
	@echo [hwcr008].[btp] PASSED >> $(LOGFILE)
	@echo [hwcr008].[btp] PASSED

hwcr008-bcoax:
	@echo [hwcr008].[bcoax] 9c5x9cfg /TR:COAX writer, 3CCFGCLI LIST reader >> $(LOGFILE)
	@echo [hwcr008].[bcoax] 9c5x9cfg /TR:COAX writer, 3CCFGCLI LIST reader
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /TR:COAX > $(ARTIFACTS)\HWCR008.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCR008.LOG
	FIND "Transceiver = on-board coax" $(ARTIFACTS)\HWCR008.LOG > NUL
	@echo [hwcr008].[bcoax] PASSED >> $(LOGFILE)
	@echo [hwcr008].[bcoax] PASSED

hwcr008-bcombo:
	@echo [hwcr008].[bcombo] 9c5x9cfg /TR:COAX writer, 3CCFGCLI LIST reader >> $(LOGFILE)
	@echo [hwcr008].[bcombo] 9c5x9cfg /TR:COAX writer, 3CCFGCLI LIST reader
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /TR:COAX > $(ARTIFACTS)\HWCR008.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCR008.LOG
	FIND "Transceiver = on-board coax" $(ARTIFACTS)\HWCR008.LOG > NUL
	@echo [hwcr008].[bcombo] PASSED >> $(LOGFILE)
	@echo [hwcr008].[bcombo] PASSED

hwcr008-btpc:
	@echo [hwcr008].[btpc] 9c5x9cfg /TR:COAX writer, 3CCFGCLI LIST reader >> $(LOGFILE)
	@echo [hwcr008].[btpc] 9c5x9cfg /TR:COAX writer, 3CCFGCLI LIST reader
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /TR:COAX > $(ARTIFACTS)\HWCR008.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCR008.LOG
	FIND "Transceiver = on-board coax" $(ARTIFACTS)\HWCR008.LOG > NUL
	@echo [hwcr008].[btpc] PASSED >> $(LOGFILE)
	@echo [hwcr008].[btpc] PASSED

hwcr008-tp:
	@echo [hwcr008].[tp] 9c5x9cfg /TR:AUI writer, 3CCFGCLI LIST reader >> $(LOGFILE)
	@echo [hwcr008].[tp] 9c5x9cfg /TR:AUI writer, 3CCFGCLI LIST reader
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /TR:AUI > $(ARTIFACTS)\HWCR008.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCR008.LOG
	FIND "Transceiver = external" $(ARTIFACTS)\HWCR008.LOG > NUL
	@echo [hwcr008].[tp] PASSED >> $(LOGFILE)
	@echo [hwcr008].[tp] PASSED



# #################################
# SAVECONFIG readback.
# #################################

# Canonical testcase stub for testreport.py.
#
# the hwcr009 target is never actually called, it's only here for structure.
# Runtime output is emitted by the card-specific further below.
hwcr009:
	@echo [hwcr009] SAVECONFIG readback > NUL

hwcr009-common:
	@echo [hwcr009].[common] Reading combined hardware state through SAVECONFIG >> $(LOGFILE)
	@echo [hwcr009].[common] Reading combined hardware state through SAVECONFIG
	$(READERAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\HWCR009.BAT > $(ARTIFACTS)\HWCR009.LOG
	FIND "Configuration restore batch file created:" $(ARTIFACTS)\HWCR009.LOG > NUL
	FIND "INT:$(TEST_IRQ)" $(ARTIFACTS)\HWCR009.BAT > NUL
	FIND "IOBASE:$(TEST_IOBASE)" $(ARTIFACTS)\HWCR009.BAT > NUL
	FIND "MODEM:$(TEST_MODEM)" $(ARTIFACTS)\HWCR009.BAT > NUL
	FIND "OPTIMIZE:$(TEST_OPTIMIZE)" $(ARTIFACTS)\HWCR009.BAT > NUL

hwcr009-btp: hwcr009-common
	FIND "PNP:DISABLED" $(ARTIFACTS)\HWCR009.BAT > NUL
	FIND "FULLDUPLEX:DISABLED" $(ARTIFACTS)\HWCR009.BAT > NUL
	FIND "BSIZE:DISABLED" $(ARTIFACTS)\HWCR009.BAT > NUL
	FIND "TR:AUI" $(ARTIFACTS)\HWCR009.BAT > NUL
	@echo [hwcr009].[btp] PASSED >> $(LOGFILE)
	@echo [hwcr009].[btp] PASSED

hwcr009-bcoax: hwcr009-common
	FIND "PNP:DISABLED" $(ARTIFACTS)\HWCR009.BAT > NUL
	FIND "BSIZE:DISABLED" $(ARTIFACTS)\HWCR009.BAT > NUL
	FIND "TR:COAX" $(ARTIFACTS)\HWCR009.BAT > NUL
	@echo [hwcr009].[bcoax] PASSED >> $(LOGFILE)
	@echo [hwcr009].[bcoax] PASSED

hwcr009-bcombo: hwcr009-common
	FIND "PNP:DISABLED" $(ARTIFACTS)\HWCR009.BAT > NUL
	FIND "FULLDUPLEX:DISABLED" $(ARTIFACTS)\HWCR009.BAT > NUL
	FIND "BSIZE:DISABLED" $(ARTIFACTS)\HWCR009.BAT > NUL
	FIND "TR:COAX" $(ARTIFACTS)\HWCR009.BAT > NUL
	@echo [hwcr009].[bcombo] PASSED >> $(LOGFILE)
	@echo [hwcr009].[bcombo] PASSED

hwcr009-btpo: hwcr009-common
	FIND "PNP:DISABLED" $(ARTIFACTS)\HWCR009.BAT > NUL
	FIND "FULLDUPLEX:DISABLED" $(ARTIFACTS)\HWCR009.BAT > NUL
	FIND "TR:TP" $(ARTIFACTS)\HWCR009.BAT > NUL
	@echo [hwcr009].[btpo] PASSED >> $(LOGFILE)
	@echo [hwcr009].[btpo] PASSED

hwcr009-btpc: hwcr009-common
	FIND "PNP:DISABLED" $(ARTIFACTS)\HWCR009.BAT > NUL
	FIND "FULLDUPLEX:DISABLED" $(ARTIFACTS)\HWCR009.BAT > NUL
	FIND "BSIZE:DISABLED" $(ARTIFACTS)\HWCR009.BAT > NUL
	FIND "TR:COAX" $(ARTIFACTS)\HWCR009.BAT > NUL
	@echo [hwcr009].[btpc] PASSED >> $(LOGFILE)
	@echo [hwcr009].[btpc] PASSED

hwcr009-tp: hwcr009-common
	FIND "TR:AUI" $(ARTIFACTS)\HWCR009.BAT > NUL
	@echo [hwcr009].[tp] PASSED >> $(LOGFILE)
	@echo [hwcr009].[tp] PASSED


# #################################
# Optional physical Boot ROM test.
# #################################

hwcr-rom-unsupported:
	@echo [hwcr051] Boot ROM is not supported on $(CARDNAME). >> $(LOGFILE)
	@echo [hwcr051] Boot ROM is not supported on $(CARDNAME).
	@echo [hwcr051] NOT SUPPORTED >> $(LOGFILE)
	@echo [hwcr051] NOT SUPPORTED

hwcr-rom-not-implemented:
	@echo [hwcr051] Boot ROM testing is currently not implemented for $(CARDNAME). >> $(LOGFILE)
	@echo [hwcr051] Boot ROM testing is currently not implemented for $(CARDNAME).
	@echo [hwcr051] NOT IMPLEMENTED >> $(LOGFILE)
	@echo [hwcr051] NOT IMPLEMENTED

hwcr-rom-disabled:
	@echo [hwcr051] Boot ROM testing is currently disabled for $(CARDNAME). >> $(LOGFILE)
	@echo [hwcr051] Boot ROM testing is currently disabled for $(CARDNAME).
	@echo [hwcr051] DISABLED >> $(LOGFILE)
	@echo [hwcr051] DISABLED

hwcr051:
	@echo [hwcr051] 9c5x9cfg Boot ROM writer, 3CCFGCLI LIST/SAVECONFIG reader >> $(LOGFILE)
	@echo [hwcr051] 9c5x9cfg Boot ROM writer, 3CCFGCLI LIST/SAVECONFIG reader
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:$(TEST_BADDRESS) /BSIZE:$(TEST_BSIZE) > $(ARTIFACTS)\HWCR010.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCR010.LOG
	FIND "Boot ROM = $(TEST_BSIZE)K at $(TEST_BADDRESS)H" $(ARTIFACTS)\HWCR010.LOG > NUL
	$(READERAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\HWCR010.BAT >> $(ARTIFACTS)\HWCR010.LOG
	FIND "BADDRESS:$(TEST_BADDRESS)" $(ARTIFACTS)\HWCR010.BAT > NUL
	FIND "BSIZE:$(TEST_BSIZE)" $(ARTIFACTS)\HWCR010.BAT > NUL
	@echo [hwcr051] PASSED >> $(LOGFILE)
	@echo [hwcr051] PASSED
