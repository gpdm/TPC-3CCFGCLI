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

RESTOREBAT = HWCWREST.BAT
REFERENCEAPP = 3C5X9CFG.EXE
WRITERAPP = 3CCFGCLI.EXE
READERAPP = 3CCFGCLI.EXE
ARTIFACTS = ARTIFACT
LOGFILE = HWCWRITE.LOG

DEFAULT_IRQ = 10
DEFAULT_IOBASE = 0300
DEFAULT_MODEM = NONE
DEFAULT_OPTIMIZE = DOS

TEST_IRQ = 3
TEST_IOBASE = 0280
TEST_PNP = DISABLED
TEST_MODEM = 1200
TEST_OPTIMIZE = SERVER
TEST_BADDRESS = C8000
TEST_BSIZE = 16

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
HWCW004_TARGET = hwcw004
HWCW006_TARGET = hwcw006
HWCW008_TARGET = hwcw008-btp
HWCW_ROM_DEPS = clean prep HWCW00xx save-config hwcw001-btp set-default-btp hwcw0101 complete

!elif $d(CARD_BCOAX)

CARDTYPE = bcoax
CARDNAME = 3C509B-COAX
HWCW004_TARGET = hwcw004
HWCW006_TARGET =
HWCW008_TARGET = hwcw008-bcoax
HWCW_ROM_DEPS = clean prep HWCW00xx save-config hwcw001-bcoax set-default-bcoax hwcw0101 complete

!elif $d(CARD_BCOMBO)

CARDTYPE = bcombo
CARDNAME = 3C509B-Combo
HWCW004_TARGET = hwcw004
HWCW006_TARGET = hwcw006
HWCW008_TARGET = hwcw008-bcombo
HWCW_ROM_DEPS = clean prep HWCW00xx save-config hwcw001-bcombo set-default-bcombo hwcw0101 complete

!elif $d(CARD_BTPO)

CARDTYPE = btpo
CARDNAME = 3C509B-TPO
HWCW004_TARGET = hwcw004
HWCW006_TARGET = hwcw006
HWCW008_TARGET =
HWCW_ROM_DEPS = hwcw-rom-unsupported

!elif $d(CARD_BTPC)

CARDTYPE = btpc
CARDNAME = 3C509B-TPCoax
HWCW004_TARGET = hwcw004
HWCW006_TARGET = hwcw006
HWCW008_TARGET = hwcw008-btpc
HWCW_ROM_DEPS = clean prep HWCW00xx save-config hwcw001-btpc set-default-btpc hwcw0101 complete

!elif $d(CARD_TP)

CARDTYPE = tp
CARDNAME = 3C509-TP
HWCW004_TARGET =
HWCW006_TARGET =
HWCW008_TARGET = hwcw008-tp
HWCW_ROM_DEPS = hwcw-rom-not-implemented

!else

!error No valid card model selected

!endif


all:
	@echo Start the hardware compliance checks with HWCTEST.BAT.
	@echo Do not start HWCWRITE.MK directly.

prep:
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
	@if exist $(LOGFILE) del $(LOGFILE)
	@echo Cleaning logs and test artifacts >> $(LOGFILE)
	@echo Cleaning logs and test artifacts
	@del $(ARTIFACTS)\*.*

# Full hardware compliance write run.
# Tests remain numerically ordered. Optional tests expand to an empty macro on
# models which do not support the corresponding capability.
HWCW_WRITE: HWCW00xx hwcw001 hwcw002 hwcw003 hwcw004 hwcw005 hwcw006 hwcw007 hwcw008 hwcw009 hwcw010
hwcw: clean prep HWCW00xx save-config hwcw001-$(CARDTYPE) set-default-$(CARDTYPE) hwcw002 hwcw003 $(HWCW004_TARGET) hwcw005 $(HWCW006_TARGET) hwcw007 $(HWCW008_TARGET) hwcw009-$(CARDTYPE) hwcw010 complete

# Optional physical Boot ROM run. The dependency list is selected above from
# CARDTYPE so the public entry point stays the same for every supported model.
HWCW_ROM: hwcw0101
hwcw-rom: $(HWCW_ROM_DEPS)


# Boot ROM handling for models without an enabled physical ROM test.
hwcw-rom-unsupported:
	@echo Boot ROM is not supported on $(CARDNAME). >> $(LOGFILE)
	@echo Boot ROM is not supported on $(CARDNAME).
	@echo [hwcw0101] NOT APPLICABLE >> $(LOGFILE)
	@echo [hwcw0101] NOT APPLICABLE


hwcw-rom-not-implemented:
	@echo Boot ROM testing is currently not enabled for $(CARDNAME). >> $(LOGFILE)
	@echo Boot ROM testing is currently not enabled for $(CARDNAME).
	@echo [hwcw0101] NOT APPLICABLE >> $(LOGFILE)
	@echo [hwcw0101] NOT APPLICABLE

save-config:
	@echo Saving original adapter configuration to $(RESTOREBAT) >> $(LOGFILE)
	@echo Saving original adapter configuration to $(RESTOREBAT)
	$(READERAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\$(RESTOREBAT) /EXECFILE:%1 > $(LOGFILE)
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

# Deterministic baselines written by the original utility.
set-default-btp:
	@echo Writing 3C509B-TP baseline via original utility >> $(LOGFILE)
	@echo Writing 3C509B-TP baseline via original utility
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:DISABLED > $(ARTIFACTS)\HWCWSET.LOG
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /TR:TP >> $(ARTIFACTS)\HWCWSET.LOG
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /INT:$(DEFAULT_IRQ) /IOBASE:$(DEFAULT_IOBASE) /PNP:ENABLED /FULLDUPLEX:ENABLED >> $(ARTIFACTS)\HWCWSET.LOG
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:$(DEFAULT_MODEM) /OPTIMIZE:$(DEFAULT_OPTIMIZE) /BSIZE:DISABLED >> $(ARTIFACTS)\HWCWSET.LOG

set-default-bcoax:
	@echo Writing 3C509B-COAX baseline via original utility >> $(LOGFILE)
	@echo Writing 3C509B-COAX baseline via original utility
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /TR:AUI > $(ARTIFACTS)\HWCWSET.LOG
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /INT:$(DEFAULT_IRQ) /IOBASE:$(DEFAULT_IOBASE) /PNP:ENABLED >> $(ARTIFACTS)\HWCWSET.LOG
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:$(DEFAULT_MODEM) /OPTIMIZE:$(DEFAULT_OPTIMIZE) /BSIZE:DISABLED >> $(ARTIFACTS)\HWCWSET.LOG

set-default-bcombo:
	@echo Writing 3C509B-Combo baseline via original utility >> $(LOGFILE)
	@echo Writing 3C509B-Combo baseline via original utility
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:DISABLED > $(ARTIFACTS)\HWCWSET.LOG
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /TR:TP >> $(ARTIFACTS)\HWCWSET.LOG
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /INT:$(DEFAULT_IRQ) /IOBASE:$(DEFAULT_IOBASE) /PNP:ENABLED /FULLDUPLEX:ENABLED >> $(ARTIFACTS)\HWCWSET.LOG
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:$(DEFAULT_MODEM) /OPTIMIZE:$(DEFAULT_OPTIMIZE) /BSIZE:DISABLED >> $(ARTIFACTS)\HWCWSET.LOG

set-default-btpo:
	@echo Writing 3C509B-TPO baseline via original utility >> $(LOGFILE)
	@echo Writing 3C509B-TPO baseline via original utility
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:DISABLED > $(ARTIFACTS)\HWCWSET.LOG
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /TR:TP >> $(ARTIFACTS)\HWCWSET.LOG
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /INT:$(DEFAULT_IRQ) /IOBASE:$(DEFAULT_IOBASE) /PNP:ENABLED /FULLDUPLEX:ENABLED >> $(ARTIFACTS)\HWCWSET.LOG
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:$(DEFAULT_MODEM) /OPTIMIZE:$(DEFAULT_OPTIMIZE) >> $(ARTIFACTS)\HWCWSET.LOG

set-default-btpc:
	@echo Writing 3C509B-TPCoax baseline via original utility >> $(LOGFILE)
	@echo Writing 3C509B-TPCoax baseline via original utility
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:DISABLED > $(ARTIFACTS)\HWCWSET.LOG
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /TR:TP >> $(ARTIFACTS)\HWCWSET.LOG
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /INT:$(DEFAULT_IRQ) /IOBASE:$(DEFAULT_IOBASE) /PNP:ENABLED /FULLDUPLEX:ENABLED >> $(ARTIFACTS)\HWCWSET.LOG
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:$(DEFAULT_MODEM) /OPTIMIZE:$(DEFAULT_OPTIMIZE) /BSIZE:DISABLED >> $(ARTIFACTS)\HWCWSET.LOG

set-default-tp:
	@echo Writing 3C509-TP baseline via original utility >> $(LOGFILE)
	@echo Writing 3C509-TP baseline via original utility
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /TR:TP > $(ARTIFACTS)\HWCWSET.LOG
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /INT:$(DEFAULT_IRQ) /IOBASE:$(DEFAULT_IOBASE) >> $(ARTIFACTS)\HWCWSET.LOG
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:$(DEFAULT_MODEM) /OPTIMIZE:$(DEFAULT_OPTIMIZE) >> $(ARTIFACTS)\HWCWSET.LOG


# #################################
# Identity / capability checks.
# #################################

# Canonical testcase stub for testreport.py.
#
# the hwcw001 target is never actually called, it's only here for structure.
# Runtime output is emitted by the card-specific further below.
hwcw001:
	@echo [hwcw001] Reading $(CARDNAME) identity and capabilities > NUL

hwcw001-btp:
	@echo [hwcw001].[btp] Reading 3C509B-TP identity and capabilities >> $(LOGFILE)
	@echo [hwcw001].[btp] Reading 3C509B-TP identity and capabilities
	$(READERAPP) LIST > $(ARTIFACTS)\HWCW001.LOG
	FIND "3Com 3C509B-TP:" $(ARTIFACTS)\HWCW001.LOG > NUL
	FIND "(ASIC Revision 2)" $(ARTIFACTS)\HWCW001.LOG > NUL
	FIND "Connectors = TP, AUI" $(ARTIFACTS)\HWCW001.LOG > NUL
	FIND "Plug and Play Capability = yes" $(ARTIFACTS)\HWCW001.LOG > NUL
	FIND "Full Duplex Capability = yes" $(ARTIFACTS)\HWCW001.LOG > NUL
	@echo [hwcw001].[btp] PASSED >> $(LOGFILE)
	@echo [hwcw001].[btp] PASSED
	
hwcw001-bcoax:
	@echo [hwcw001].[bcoax] Reading 3C509B-COAX identity and capabilities >> $(LOGFILE)
	@echo [hwcw001].[bcoax] Reading 3C509B-COAX identity and capabilities
	$(READERAPP) LIST > $(ARTIFACTS)\HWCW001.LOG
	FIND "3Com 3C509B:" $(ARTIFACTS)\HWCW001.LOG > NUL
	FIND "(ASIC Revision 2)" $(ARTIFACTS)\HWCW001.LOG > NUL
	FIND "Connectors = AUI, COAX" $(ARTIFACTS)\HWCW001.LOG > NUL
	FIND "Plug and Play Capability = yes" $(ARTIFACTS)\HWCW001.LOG > NUL
	FIND "Full Duplex Capability = no" $(ARTIFACTS)\HWCW001.LOG > NUL
	@echo [hwcw001].[bcoax] PASSED >> $(LOGFILE)
	@echo [hwcw001].[bcoax] PASSED

hwcw001-bcombo:
	@echo [hwcw001].[bcombo] Reading 3C509B-Combo identity and capabilities >> $(LOGFILE)
	@echo [hwcw001].[bcombo] Reading 3C509B-Combo identity and capabilities
	$(READERAPP) LIST > $(ARTIFACTS)\HWCW001.LOG
	FIND "3Com 3C509B-Combo:" $(ARTIFACTS)\HWCW001.LOG > NUL
	FIND "(ASIC Revision 2)" $(ARTIFACTS)\HWCW001.LOG > NUL
	FIND "Connectors = TP, AUI, COAX" $(ARTIFACTS)\HWCW001.LOG > NUL
	FIND "Plug and Play Capability = yes" $(ARTIFACTS)\HWCW001.LOG > NUL
	FIND "Full Duplex Capability = yes" $(ARTIFACTS)\HWCW001.LOG > NUL
	@echo [hwcw001].[bcombo] PASSED >> $(LOGFILE)
	@echo [hwcw001].[bcombo] PASSED

hwcw001-btpo:
	@echo [hwcw001].[btpo] Reading 3C509B-TPO identity and capabilities >> $(LOGFILE)
	@echo [hwcw001].[btpo] Reading 3C509B-TPO identity and capabilities
	$(READERAPP) LIST > $(ARTIFACTS)\HWCW001.LOG
	FIND "3Com 3C509B-TPO:" $(ARTIFACTS)\HWCW001.LOG > NUL
	FIND "(ASIC Revision 2)" $(ARTIFACTS)\HWCW001.LOG > NUL
	FIND "Connectors = TP" $(ARTIFACTS)\HWCW001.LOG > NUL
	FIND "Plug and Play Capability = yes" $(ARTIFACTS)\HWCW001.LOG > NUL
	FIND "Full Duplex Capability = yes" $(ARTIFACTS)\HWCW001.LOG > NUL
	@echo [hwcw001].[btpo] PASSED >> $(LOGFILE)
	@echo [hwcw001].[btpo] PASSED

hwcw001-btpc:
	@echo [hwcw001].[btpc] Reading 3C509B-TPCoax identity and capabilities >> $(LOGFILE)
	@echo [hwcw001].[btpc] Reading 3C509B-TPCoax identity and capabilities
	$(READERAPP) LIST > $(ARTIFACTS)\HWCW001.LOG
	FIND "3Com 3C509B-TPCoax:" $(ARTIFACTS)\HWCW001.LOG > NUL
	FIND "(ASIC Revision 2)" $(ARTIFACTS)\HWCW001.LOG > NUL
	FIND "Connectors = TP, COAX" $(ARTIFACTS)\HWCW001.LOG > NUL
	FIND "Plug and Play Capability = yes" $(ARTIFACTS)\HWCW001.LOG > NUL
	FIND "Full Duplex Capability = yes" $(ARTIFACTS)\HWCW001.LOG > NUL
	@echo [hwcw001].[btpc] PASSED >> $(LOGFILE)
	@echo [hwcw001].[btpc] PASSED

hwcw001-tp:
	@echo [hwcw001].[tp] Reading 3C509-TP identity and capabilities >> $(LOGFILE)
	@echo [hwcw001].[tp] Reading 3C509-TP identity and capabilities
	$(READERAPP) LIST > $(ARTIFACTS)\HWCW001.LOG
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
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:DISABLED > $(ARTIFACTS)\HWCW006.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCW006.LOG
	FIND "Full Duplex = disabled" $(ARTIFACTS)\HWCW006.LOG > NUL
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
# Optional physical Boot ROM test
# #################################

hwcw0101:
	@echo [hwcw0101] 3CCFGCLI Boot ROM writer, fresh LIST/SAVECONFIG readback >> $(LOGFILE)
	@echo [hwcw0101] 3CCFGCLI Boot ROM writer, fresh LIST/SAVECONFIG readback
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:$(TEST_BADDRESS) /BSIZE:$(TEST_BSIZE) > $(ARTIFACTS)\HWCW0101.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCW0101.LOG
	FIND "Boot ROM = $(TEST_BSIZE)K at $(TEST_BADDRESS)H" $(ARTIFACTS)\HWCW0101.LOG > NUL
	$(READERAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\HWCW0101.BAT >> $(ARTIFACTS)\HWCW0101.LOG
	FIND "BADDRESS:$(TEST_BADDRESS)" $(ARTIFACTS)\HWCW0101.BAT > NUL
	FIND "BSIZE:$(TEST_BSIZE)" $(ARTIFACTS)\HWCW0101.BAT > NUL
	@echo [hwcw0101] PASSED >> $(LOGFILE)
	@echo [hwcw0101] PASSED
