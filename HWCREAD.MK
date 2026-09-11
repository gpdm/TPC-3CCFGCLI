# 3CCFGCLI Hardware Compliance Read checks.
#
# 3CCFGCLI is read-only with respect to adapter hardware in this suite.
# Known hardware states are established by the original 3Com utility and read
# back through 3CCFGCLI LIST and SAVECONFIG.
#
# HWCTEST.BAT is the default entry point. It creates the hardware LIST output,
# detects the installed model, then invokes the matching card-specific target
# in this makefile.
#
# Usage:
#   HWCTEST.BAT READ
#
# Optional physical Boot ROM test:
#   HWCTEST.BAT READROM
#
# If a run aborts after writes have started:
#   MAKE -fHWCREAD.MK restore-config
#

RESTOREBAT = HWCRREST.BAT
WRITERAPP = 3C5X9CFG.EXE
READERAPP = 3CCFGCLI.EXE
ARTIFACTS = ARTIFACT
LOGFILE = HWCREAD.LOG

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

all:
	@echo Start the hardware compliance checks with HWCTEST.BAT.
	@echo Do not start HWCREAD.MK directly.

prep:
	@if not exist $(ARTIFACTS)\NUL mkdir $(ARTIFACTS)
	@echo Running 3CCFGCLI Hardware Compliance Read checks... >> $(LOGFILE)
	@echo Running 3CCFGCLI Hardware Compliance Read checks...

complete:
	@echo Hardware Compliance Read checks completed. >> $(LOGFILE)
	@echo Hardware Compliance Read checks completed.

clean:
	@if exist $(LOGFILE) del $(LOGFILE)
	@if exist $(ARTIFACTS)\HWCR*.LOG del $(ARTIFACTS)\HWCR*.LOG
	@if exist $(ARTIFACTS)\HWCR*.BAT del $(ARTIFACTS)\HWCR*.BAT

# Card-specific run targets.
# HWCDET.BAT has already generated and consumed HWCRDET.LOG before these start.
hwcr-btp: clean prep save-config hwcr001-btp set-default-btp HWCR_COMMON hwcr004 hwcr006 hwcr008-btp hwcr009-btp restore-config complete
hwcr-bcoax: clean prep save-config hwcr001-bcoax set-default-bcoax HWCR_COMMON hwcr004 hwcr008-bcoax hwcr009-bcoax restore-config complete
hwcr-bcombo: clean prep save-config hwcr001-bcombo set-default-bcombo HWCR_COMMON hwcr004 hwcr006 hwcr008-bcombo hwcr009-bcombo restore-config complete
hwcr-btpo: clean prep save-config hwcr001-btpo set-default-btpo HWCR_COMMON hwcr004 hwcr006 hwcr009-btpo restore-config complete
hwcr-btpc: clean prep save-config hwcr001-btpc set-default-btpc HWCR_COMMON hwcr004 hwcr006 hwcr008-btpc hwcr009-btpc restore-config complete
hwcr-tp: clean prep save-config hwcr001-tp set-default-tp HWCR_COMMON hwcr008-tp hwcr009-tp restore-config complete

# Optional physical Boot ROM runs.
hwcr-rom-btp: clean prep save-config hwcr001-btp set-default-btp hwcr010 restore-config complete
hwcr-rom-bcoax: clean prep save-config hwcr001-bcoax set-default-bcoax hwcr010 restore-config complete
hwcr-rom-bcombo: clean prep save-config hwcr001-bcombo set-default-bcombo hwcr010 restore-config complete
hwcr-rom-btpc: clean prep save-config hwcr001-btpc set-default-btpc hwcr010 restore-config complete

# Emit warning for NICs which explicitely don't
# have support for Network Boot ROM.
hwcr-rom-btpo:
	@echo Boot ROM is not supported on the 3C509B-TPO. >> $(LOGFILE)
	@echo Boot ROM is not supported on the 3C509B-TPO.

hwcr-rom-tpo:
	@echo Boot ROM is not supported on the 3C509-TPO. >> $(LOGFILE)
	@echo Boot ROM is not supported on the 3C509-TPO.


# Emit warning for currently non-implemented ROM targets.
hwcr-rom-not-implemented:
	@echo Boot ROM testing is currently not enabled for this device type. >> $(LOGFILE)
	@echo Boot ROM testing is currently not enabled for this device type.

hwcr-rom-tp: hwcr-rom-not-implemented
hwcr-rom-coax: hwcr-rom-not-implemented
hwcr-rom-combo: hwcr-rom-not-implemented
hwcr-rom-tpc: hwcr-rom-not-implemented


# Common reader tests valid on all supported models.
HWCR_COMMON: hwcr002 hwcr003 hwcr005 hwcr007

save-config:
	@echo Saving original adapter configuration to $(RESTOREBAT)... >> $(LOGFILE)
	@echo Saving original adapter configuration to $(RESTOREBAT)...
	$(READERAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\$(RESTOREBAT) /EXECFILE:%1 > $(LOGFILE)
	FIND "Configuration restore batch file created:" $(LOGFILE) > NUL

restore-config:
	@echo Config restore via MAKE is broken on some earlier DOS versions. >> $(LOGFILE)
	@echo Config restore via MAKE is broken on some earlier DOS versions.
	@echo MAKE does not currently invoke the restore command itself for that reason. >> $(LOGFILE)
	@echo MAKE does not currently invoke the restore command itself for that reason.
	@echo Please run the following command manually once to restore the original configuration. >> $(LOGFILE)
	@echo Please run the following command manually once to restore the original configuration.
	@echo $(ARTIFACTS)\$(RESTOREBAT) $(WRITERAPP) >> $(LOGFILE)
	@echo $(ARTIFACTS)\$(RESTOREBAT) $(WRITERAPP)

restore: restore-config

# Deterministic baselines.
set-default-btp:
	@echo Writing 3C509B-TP baseline via original utility... >> $(LOGFILE)
	@echo Writing 3C509B-TP baseline via original utility...
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:DISABLED > $(ARTIFACTS)\HWCRSET.LOG
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /TR:TP >> $(ARTIFACTS)\HWCRSET.LOG
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /INT:$(DEFAULT_IRQ) /IOBASE:$(DEFAULT_IOBASE) /PNP:ENABLED /FULLDUPLEX:ENABLED >> $(ARTIFACTS)\HWCRSET.LOG
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:$(DEFAULT_MODEM) /OPTIMIZE:$(DEFAULT_OPTIMIZE) /BSIZE:DISABLED >> $(ARTIFACTS)\HWCRSET.LOG

set-default-bcoax:
	@echo Writing 3C509B-COAX baseline via original utility... >> $(LOGFILE)
	@echo Writing 3C509B-COAX baseline via original utility...
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /TR:AUI > $(ARTIFACTS)\HWCRSET.LOG
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /INT:$(DEFAULT_IRQ) /IOBASE:$(DEFAULT_IOBASE) /PNP:ENABLED >> $(ARTIFACTS)\HWCRSET.LOG
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:$(DEFAULT_MODEM) /OPTIMIZE:$(DEFAULT_OPTIMIZE) /BSIZE:DISABLED >> $(ARTIFACTS)\HWCRSET.LOG

set-default-bcombo:
	@echo Writing 3C509B-Combo baseline via original utility... >> $(LOGFILE)
	@echo Writing 3C509B-Combo baseline via original utility...
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:DISABLED > $(ARTIFACTS)\HWCRSET.LOG
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /TR:TP >> $(ARTIFACTS)\HWCRSET.LOG
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /INT:$(DEFAULT_IRQ) /IOBASE:$(DEFAULT_IOBASE) /PNP:ENABLED /FULLDUPLEX:ENABLED >> $(ARTIFACTS)\HWCRSET.LOG
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:$(DEFAULT_MODEM) /OPTIMIZE:$(DEFAULT_OPTIMIZE) /BSIZE:DISABLED >> $(ARTIFACTS)\HWCRSET.LOG

set-default-btpo:
	@echo Writing 3C509B-TPO baseline via original utility... >> $(LOGFILE)
	@echo Writing 3C509B-TPO baseline via original utility...
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:DISABLED > $(ARTIFACTS)\HWCRSET.LOG
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /TR:TP >> $(ARTIFACTS)\HWCRSET.LOG
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /INT:$(DEFAULT_IRQ) /IOBASE:$(DEFAULT_IOBASE) /PNP:ENABLED /FULLDUPLEX:ENABLED >> $(ARTIFACTS)\HWCRSET.LOG
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:$(DEFAULT_MODEM) /OPTIMIZE:$(DEFAULT_OPTIMIZE) >> $(ARTIFACTS)\HWCRSET.LOG

set-default-btpc:
	@echo Writing 3C509B-TPCoax baseline via original utility... >> $(LOGFILE)
	@echo Writing 3C509B-TPCoax baseline via original utility...
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:DISABLED > $(ARTIFACTS)\HWCRSET.LOG
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /TR:TP >> $(ARTIFACTS)\HWCRSET.LOG
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /INT:$(DEFAULT_IRQ) /IOBASE:$(DEFAULT_IOBASE) /PNP:ENABLED /FULLDUPLEX:ENABLED >> $(ARTIFACTS)\HWCRSET.LOG
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:$(DEFAULT_MODEM) /OPTIMIZE:$(DEFAULT_OPTIMIZE) /BSIZE:DISABLED >> $(ARTIFACTS)\HWCRSET.LOG

set-default-tp:
	@echo Writing 3C509-TP baseline via original utility... >> $(LOGFILE)
	@echo Writing 3C509-TP baseline via original utility...
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /TR:TP > $(ARTIFACTS)\HWCRSET.LOG
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /INT:$(DEFAULT_IRQ) /IOBASE:$(DEFAULT_IOBASE) >> $(ARTIFACTS)\HWCRSET.LOG
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:$(DEFAULT_MODEM) /OPTIMIZE:$(DEFAULT_OPTIMIZE) >> $(ARTIFACTS)\HWCRSET.LOG

# Identity / capability checks.
hwcr001-btp:
	@echo [hwcr001] Reading 3C509B-TP identity and capabilities... >> $(LOGFILE)
	@echo [hwcr001] Reading 3C509B-TP identity and capabilities...
	$(READERAPP) LIST > $(ARTIFACTS)\HWCR001.LOG
	FIND "3Com 3C509B-TP:" $(ARTIFACTS)\HWCR001.LOG > NUL
	FIND "(ASIC Revision 2)" $(ARTIFACTS)\HWCR001.LOG > NUL
	FIND "Connectors = TP, AUI" $(ARTIFACTS)\HWCR001.LOG > NUL
	FIND "Plug and Play Capability = yes" $(ARTIFACTS)\HWCR001.LOG > NUL
	FIND "Full Duplex Capability = yes" $(ARTIFACTS)\HWCR001.LOG > NUL

hwcr001-bcoax:
	@echo [hwcr001] Reading 3C509B-COAX identity and capabilities... >> $(LOGFILE)
	@echo [hwcr001] Reading 3C509B-COAX identity and capabilities...
	$(READERAPP) LIST > $(ARTIFACTS)\HWCR001.LOG
	FIND "3Com 3C509B:" $(ARTIFACTS)\HWCR001.LOG > NUL
	FIND "(ASIC Revision 2)" $(ARTIFACTS)\HWCR001.LOG > NUL
	FIND "Connectors = AUI, COAX" $(ARTIFACTS)\HWCR001.LOG > NUL
	FIND "Plug and Play Capability = yes" $(ARTIFACTS)\HWCR001.LOG > NUL
	FIND "Full Duplex Capability = no" $(ARTIFACTS)\HWCR001.LOG > NUL

hwcr001-bcombo:
	@echo [hwcr001] Reading 3C509B-Combo identity and capabilities... >> $(LOGFILE)
	@echo [hwcr001] Reading 3C509B-Combo identity and capabilities...
	$(READERAPP) LIST > $(ARTIFACTS)\HWCR001.LOG
	FIND "3Com 3C509B-Combo:" $(ARTIFACTS)\HWCR001.LOG > NUL
	FIND "(ASIC Revision 2)" $(ARTIFACTS)\HWCR001.LOG > NUL
	FIND "Connectors = TP, AUI, COAX" $(ARTIFACTS)\HWCR001.LOG > NUL
	FIND "Plug and Play Capability = yes" $(ARTIFACTS)\HWCR001.LOG > NUL
	FIND "Full Duplex Capability = yes" $(ARTIFACTS)\HWCR001.LOG > NUL

hwcr001-btpo:
	@echo [hwcr001] Reading 3C509B-TPO identity and capabilities... >> $(LOGFILE)
	@echo [hwcr001] Reading 3C509B-TPO identity and capabilities...
	$(READERAPP) LIST > $(ARTIFACTS)\HWCR001.LOG
	FIND "3Com 3C509B-TPO:" $(ARTIFACTS)\HWCR001.LOG > NUL
	FIND "(ASIC Revision 2)" $(ARTIFACTS)\HWCR001.LOG > NUL
	FIND "Connectors = TP" $(ARTIFACTS)\HWCR001.LOG > NUL
	FIND "Plug and Play Capability = yes" $(ARTIFACTS)\HWCR001.LOG > NUL
	FIND "Full Duplex Capability = yes" $(ARTIFACTS)\HWCR001.LOG > NUL

hwcr001-btpc:
	@echo [hwcr001] Reading 3C509B-TPCoax identity and capabilities... >> $(LOGFILE)
	@echo [hwcr001] Reading 3C509B-TPCoax identity and capabilities...
	$(READERAPP) LIST > $(ARTIFACTS)\HWCR001.LOG
	FIND "3Com 3C509B-TPCoax:" $(ARTIFACTS)\HWCR001.LOG > NUL
	FIND "(ASIC Revision 2)" $(ARTIFACTS)\HWCR001.LOG > NUL
	FIND "Connectors = TP, COAX" $(ARTIFACTS)\HWCR001.LOG > NUL
	FIND "Plug and Play Capability = yes" $(ARTIFACTS)\HWCR001.LOG > NUL
	FIND "Full Duplex Capability = yes" $(ARTIFACTS)\HWCR001.LOG > NUL

hwcr001-tp:
	@echo [hwcr001] Reading 3C509-TP identity and capabilities... >> $(LOGFILE)
	@echo [hwcr001] Reading 3C509-TP identity and capabilities...
	$(READERAPP) LIST > $(ARTIFACTS)\HWCR001.LOG
	FIND "3Com 3C509-TP:" $(ARTIFACTS)\HWCR001.LOG > NUL
	FIND "(ASIC Revision 1)" $(ARTIFACTS)\HWCR001.LOG > NUL
	FIND "Connectors = TP, AUI" $(ARTIFACTS)\HWCR001.LOG > NUL
	FIND "Plug and Play Capability = not supported" $(ARTIFACTS)\HWCR001.LOG > NUL
	FIND "Full Duplex Capability = not supported" $(ARTIFACTS)\HWCR001.LOG > NUL

# Common property readback tests.
hwcr002:
	@echo [hwcr002] Original /INT writer, 3CCFGCLI LIST reader... >> $(LOGFILE)
	@echo [hwcr002] Original /INT writer, 3CCFGCLI LIST reader...
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /INT:$(TEST_IRQ) > $(ARTIFACTS)\HWCR002.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCR002.LOG
	FIND "IRQ = $(TEST_IRQ)" $(ARTIFACTS)\HWCR002.LOG > NUL
	@echo [hwcr002] PASSED >> $(LOGFILE)
	@echo [hwcr002] PASSED

hwcr003:
	@echo [hwcr003] Original /IOBASE writer, 3CCFGCLI LIST reader... >> $(LOGFILE)
	@echo [hwcr003] Original /IOBASE writer, 3CCFGCLI LIST reader...
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /IOBASE:$(TEST_IOBASE) > $(ARTIFACTS)\HWCR003.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCR003.LOG
	FIND "IOBASE = $(TEST_IOBASE)" $(ARTIFACTS)\HWCR003.LOG > NUL
	@echo [hwcr003] PASSED >> $(LOGFILE)
	@echo [hwcr003] PASSED

hwcr004:
	@echo [hwcr004] Original /PNP writer, 3CCFGCLI LIST reader... >> $(LOGFILE)
	@echo [hwcr004] Original /PNP writer, 3CCFGCLI LIST reader...
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /PNP:$(TEST_PNP) > $(ARTIFACTS)\HWCR004.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCR004.LOG
	FIND "Plug and Play = disabled" $(ARTIFACTS)\HWCR004.LOG > NUL
	@echo [hwcr004] PASSED >> $(LOGFILE)
	@echo [hwcr004] PASSED

hwcr005:
	@echo [hwcr005] Original /MODEM writer, 3CCFGCLI LIST reader... >> $(LOGFILE)
	@echo [hwcr005] Original /MODEM writer, 3CCFGCLI LIST reader...
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:$(TEST_MODEM) > $(ARTIFACTS)\HWCR005.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCR005.LOG
	FIND "MODEM Interrupt Disable Time = 1300 us (1200 bd)" $(ARTIFACTS)\HWCR005.LOG > NUL
	@echo [hwcr005] PASSED >> $(LOGFILE)
	@echo [hwcr005] PASSED

hwcr006:
	@echo [hwcr006] Original /FULLDUPLEX writer, 3CCFGCLI LIST reader... >> $(LOGFILE)
	@echo [hwcr006] Original /FULLDUPLEX writer, 3CCFGCLI LIST reader...
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:DISABLED > $(ARTIFACTS)\HWCR006.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCR006.LOG
	FIND "Full Duplex = disabled" $(ARTIFACTS)\HWCR006.LOG > NUL
	@echo [hwcr006] PASSED >> $(LOGFILE)
	@echo [hwcr006] PASSED

hwcr007:
	@echo [hwcr007] Original /OPTIMIZE writer, 3CCFGCLI LIST reader... >> $(LOGFILE)
	@echo [hwcr007] Original /OPTIMIZE writer, 3CCFGCLI LIST reader...
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /OPTIMIZE:$(TEST_OPTIMIZE) > $(ARTIFACTS)\HWCR007.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCR007.LOG
	FIND "Optimization = Server" $(ARTIFACTS)\HWCR007.LOG > NUL
	@echo [hwcr007] PASSED >> $(LOGFILE)
	@echo [hwcr007] PASSED

# Card-specific transceiver tests.
hwcr008-btp:
	@echo [hwcr008] Original /TR:AUI writer, 3CCFGCLI LIST reader... >> $(LOGFILE)
	@echo [hwcr008] Original /TR:AUI writer, 3CCFGCLI LIST reader...
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /TR:AUI > $(ARTIFACTS)\HWCR008.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCR008.LOG
	FIND "Transceiver = external" $(ARTIFACTS)\HWCR008.LOG > NUL
	@echo [hwcr008] PASSED >> $(LOGFILE)
	@echo [hwcr008] PASSED

hwcr008-bcoax:
	@echo [hwcr008] Original /TR:COAX writer, 3CCFGCLI LIST reader... >> $(LOGFILE)
	@echo [hwcr008] Original /TR:COAX writer, 3CCFGCLI LIST reader...
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /TR:COAX > $(ARTIFACTS)\HWCR008.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCR008.LOG
	FIND "Transceiver = on-board coax" $(ARTIFACTS)\HWCR008.LOG > NUL
	@echo [hwcr008] PASSED >> $(LOGFILE)
	@echo [hwcr008] PASSED

hwcr008-bcombo:
	@echo [hwcr008] Original /TR:COAX writer, 3CCFGCLI LIST reader... >> $(LOGFILE)
	@echo [hwcr008] Original /TR:COAX writer, 3CCFGCLI LIST reader...
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /TR:COAX > $(ARTIFACTS)\HWCR008.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCR008.LOG
	FIND "Transceiver = on-board coax" $(ARTIFACTS)\HWCR008.LOG > NUL
	@echo [hwcr008] PASSED >> $(LOGFILE)
	@echo [hwcr008] PASSED

hwcr008-btpc:
	@echo [hwcr008] Original /TR:COAX writer, 3CCFGCLI LIST reader... >> $(LOGFILE)
	@echo [hwcr008] Original /TR:COAX writer, 3CCFGCLI LIST reader...
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /TR:COAX > $(ARTIFACTS)\HWCR008.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCR008.LOG
	FIND "Transceiver = on-board coax" $(ARTIFACTS)\HWCR008.LOG > NUL
	@echo [hwcr008] PASSED >> $(LOGFILE)
	@echo [hwcr008] PASSED

hwcr008-tp:
	@echo [hwcr008] Original /TR:AUI writer, 3CCFGCLI LIST reader... >> $(LOGFILE)
	@echo [hwcr008] Original /TR:AUI writer, 3CCFGCLI LIST reader...
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /TR:AUI > $(ARTIFACTS)\HWCR008.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCR008.LOG
	FIND "Transceiver = external" $(ARTIFACTS)\HWCR008.LOG > NUL
	@echo [hwcr008] PASSED >> $(LOGFILE)
	@echo [hwcr008] PASSED

# SAVECONFIG readback.
hwcr009-common:
	@echo [hwcr009] Reading combined hardware state through SAVECONFIG... >> $(LOGFILE)
	@echo [hwcr009] Reading combined hardware state through SAVECONFIG...
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
	@echo [hwcr009] PASSED >> $(LOGFILE)
	@echo [hwcr009] PASSED

hwcr009-bcoax: hwcr009-common
	FIND "PNP:DISABLED" $(ARTIFACTS)\HWCR009.BAT > NUL
	FIND "BSIZE:DISABLED" $(ARTIFACTS)\HWCR009.BAT > NUL
	FIND "TR:COAX" $(ARTIFACTS)\HWCR009.BAT > NUL
	@echo [hwcr009] PASSED >> $(LOGFILE)
	@echo [hwcr009] PASSED

hwcr009-bcombo: hwcr009-common
	FIND "PNP:DISABLED" $(ARTIFACTS)\HWCR009.BAT > NUL
	FIND "FULLDUPLEX:DISABLED" $(ARTIFACTS)\HWCR009.BAT > NUL
	FIND "BSIZE:DISABLED" $(ARTIFACTS)\HWCR009.BAT > NUL
	FIND "TR:COAX" $(ARTIFACTS)\HWCR009.BAT > NUL
	@echo [hwcr009] PASSED >> $(LOGFILE)
	@echo [hwcr009] PASSED

hwcr009-btpo: hwcr009-common
	FIND "PNP:DISABLED" $(ARTIFACTS)\HWCR009.BAT > NUL
	FIND "FULLDUPLEX:DISABLED" $(ARTIFACTS)\HWCR009.BAT > NUL
	FIND "TR:TP" $(ARTIFACTS)\HWCR009.BAT > NUL
	@echo [hwcr009] PASSED >> $(LOGFILE)
	@echo [hwcr009] PASSED

hwcr009-btpc: hwcr009-common
	FIND "PNP:DISABLED" $(ARTIFACTS)\HWCR009.BAT > NUL
	FIND "FULLDUPLEX:DISABLED" $(ARTIFACTS)\HWCR009.BAT > NUL
	FIND "BSIZE:DISABLED" $(ARTIFACTS)\HWCR009.BAT > NUL
	FIND "TR:COAX" $(ARTIFACTS)\HWCR009.BAT > NUL
	@echo [hwcr009] PASSED >> $(LOGFILE)
	@echo [hwcr009] PASSED

hwcr009-tp: hwcr009-common
	FIND "TR:AUI" $(ARTIFACTS)\HWCR009.BAT > NUL
	@echo [hwcr009] PASSED >> $(LOGFILE)
	@echo [hwcr009] PASSED

# Optional physical Boot ROM test.
hwcr010:
	@echo [hwcr010] Original Boot ROM writer, 3CCFGCLI LIST/SAVECONFIG reader... >> $(LOGFILE)
	@echo [hwcr010] Original Boot ROM writer, 3CCFGCLI LIST/SAVECONFIG reader...
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:$(TEST_BADDRESS) /BSIZE:$(TEST_BSIZE) > $(ARTIFACTS)\HWCR010.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCR010.LOG
	FIND "Boot ROM = $(TEST_BSIZE)K at $(TEST_BADDRESS)H" $(ARTIFACTS)\HWCR010.LOG > NUL
	$(READERAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\HWCR010.BAT >> $(ARTIFACTS)\HWCR010.LOG
	FIND "BADDRESS:$(TEST_BADDRESS)" $(ARTIFACTS)\HWCR010.BAT > NUL
	FIND "BSIZE:$(TEST_BSIZE)" $(ARTIFACTS)\HWCR010.BAT > NUL
	@echo [hwcr010] PASSED >> $(LOGFILE)
	@echo [hwcr010] PASSED
