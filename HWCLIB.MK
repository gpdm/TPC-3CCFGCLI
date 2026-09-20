# Shared 3CCFGCLI Hardware Compliance implementation.
# Suite files provide identity, application roles, card routing, and composition.

3C5X9CFG = 3C5X9CFG.EXE
3CCFGCLI = 3CCFGCLI.EXE
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

# Multi NIC defaults. These checks intentionally use only IOBASE and IRQ so
# they are valid for every supported 3C509 / 3C509B model. Exactly two cards
# are required.
MULTI_CARD1_IOBASE = 0300
MULTI_CARD1_IRQ = 5
MULTI_CARD2_IOBASE = 0280
MULTI_CARD2_IRQ = 3
MULTI_SHARED_IOBASE = 0300

all:
	@echo Start the normal hardware compliance checks with HWCTEST.BAT.


prep:
	@if not exist $(OUTDIR)\NUL mkdir $(OUTDIR)
	@if not exist $(ARTIFACTS)\NUL mkdir $(ARTIFACTS)
	@echo Running 3CCFGCLI Hardware Compliance $(HWC_MODE) checks >> $(LOGFILE)
	@echo Running 3CCFGCLI Hardware Compliance $(HWC_MODE) checks

hwc00xx:
	@echo [$(HWC_TAG)00xx] Hardware Compliance $(HWC_MODE) checks for $(CARDNAME) >> $(LOGFILE)
	@echo [$(HWC_TAG)00xx] Hardware Compliance $(HWC_MODE) checks for $(CARDNAME)

hwcm00xx:
	@echo [$(HWC_TAG)00xx] Multi NIC Hardware Compliance $(HWC_MODE) checks >> $(LOGFILE)
	@echo [$(HWC_TAG)00xx] Multi NIC Hardware Compliance $(HWC_MODE) checks

complete:
	@echo Hardware Compliance $(HWC_MODE) checks completed. >> $(LOGFILE)
	@echo Hardware Compliance $(HWC_MODE) checks completed.

clean:
	@echo Cleaning logs and test artifacts >> $(LOGFILE)
	@echo Cleaning logs and test artifacts
	@del $(ARTIFACTS)\$(HWC_TAG)*.*

save-config:
	@echo Saving original adapter configuration to $(RESTOREBAT) >> $(LOGFILE)
	@echo Saving original adapter configuration to $(RESTOREBAT)
	$(READERAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\$(RESTOREBAT) /EXECFILE:$(WRITERAPP) >> $(LOGFILE)
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
	$(3C5X9CFG) CONFIGURE /ADAPTERNUM:1 /TR:$(DEFAULT_TRANSCEIVER) > $(ARTIFACTS)\$(HWC_TAG)SET.LOG
	$(3C5X9CFG) CONFIGURE /ADAPTERNUM:1 /INT:$(DEFAULT_IRQ) /IOBASE:$(DEFAULT_IOBASE) >> $(ARTIFACTS)\$(HWC_TAG)SET.LOG
	$(3C5X9CFG) CONFIGURE /ADAPTERNUM:1 /MODEM:$(DEFAULT_MODEM) /OPTIMIZE:$(DEFAULT_OPTIMIZE) >> $(ARTIFACTS)\$(HWC_TAG)SET.LOG

set-default-btp: set-default-common
	$(3C5X9CFG) CONFIGURE /ADAPTERNUM:1 /PNP:$(DEFAULT_PNP) >> $(ARTIFACTS)\$(HWC_TAG)SET.LOG
	$(3C5X9CFG) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:$(DEFAULT_FULLDUPLEX) >> $(ARTIFACTS)\$(HWC_TAG)SET.LOG
	$(3C5X9CFG) CONFIGURE /ADAPTERNUM:1 /BSIZE:DISABLED >> $(ARTIFACTS)\$(HWC_TAG)SET.LOG
	@echo [set-default].[btp] PASSED >> $(LOGFILE)
	@echo [set-default].[btp] PASSED

# NOTE: does NOT include /FULLDUPLEX verb because 3C509B-COAX does not support it
set-default-bcoax: set-default-common
	$(3C5X9CFG) CONFIGURE /ADAPTERNUM:1 /PNP:$(DEFAULT_PNP) >> $(ARTIFACTS)\$(HWC_TAG)SET.LOG
	$(3C5X9CFG) CONFIGURE /ADAPTERNUM:1 /BSIZE:DISABLED >> $(ARTIFACTS)\$(HWC_TAG)SET.LOG
	@echo [set-default].[bcoax] PASSED >> $(LOGFILE)
	@echo [set-default].[bcoax] PASSED

set-default-bcombo: set-default-common
	$(3C5X9CFG) CONFIGURE /ADAPTERNUM:1 /PNP:$(DEFAULT_PNP) >> $(ARTIFACTS)\$(HWC_TAG)SET.LOG
	$(3C5X9CFG) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:$(DEFAULT_FULLDUPLEX) >> $(ARTIFACTS)\$(HWC_TAG)SET.LOG
	$(3C5X9CFG) CONFIGURE /ADAPTERNUM:1 /BSIZE:DISABLED >> $(ARTIFACTS)\$(HWC_TAG)SET.LOG
	@echo [set-default].[bcombo] PASSED >> $(LOGFILE)
	@echo [set-default].[bcombo] PASSED

# NOTE: does NOT inlcude /BSIZE:DISABLED verb because 3C509B-TPO does not support ROM
set-default-btpo: set-default-common
	$(3C5X9CFG) CONFIGURE /ADAPTERNUM:1 /PNP:$(DEFAULT_PNP) >> $(ARTIFACTS)\$(HWC_TAG)SET.LOG
	@echo [set-default].[btpo] PASSED >> $(LOGFILE)
	@echo [set-default].[btpo] PASSED

set-default-btpc: set-default-common
	$(3C5X9CFG) CONFIGURE /ADAPTERNUM:1 /PNP:$(DEFAULT_PNP) >> $(ARTIFACTS)\$(HWC_TAG)SET.LOG
	$(3C5X9CFG) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:$(DEFAULT_FULLDUPLEX) >> $(ARTIFACTS)\$(HWC_TAG)SET.LOG
	$(3C5X9CFG) CONFIGURE /ADAPTERNUM:1 /BSIZE:DISABLED >> $(ARTIFACTS)\$(HWC_TAG)SET.LOG
	@echo [set-default].[btpc] PASSED >> $(LOGFILE)
	@echo [set-default].[btpc] PASSED

# NOTE: does NOT include /FULLDUPLEX and /PNP verbs because 3C509-TP does not support it
set-default-tp: set-default-common
	$(3C5X9CFG) CONFIGURE /ADAPTERNUM:1 /BSIZE:DISABLED >> $(ARTIFACTS)\$(HWC_TAG)SET.LOG
	@echo [set-default].[tp] PASSED >> $(LOGFILE)
	@echo [set-default].[tp] PASSED

# NOTE: does NOT include /FULLDUPLEX and /PNP verbs because 3C509-COAX does not support them
set-default-coax: set-default-common
	$(3C5X9CFG) CONFIGURE /ADAPTERNUM:1 /BSIZE:DISABLED >> $(ARTIFACTS)\$(HWC_TAG)SET.LOG
	@echo [set-default].[coax] PASSED >> $(LOGFILE)
	@echo [set-default].[coax] PASSED

# NOTE: does NOT include /FULLDUPLEX and /PNP verbs because 3C509-Combo does not support them
set-default-combo: set-default-common
	$(3C5X9CFG) CONFIGURE /ADAPTERNUM:1 /BSIZE:DISABLED >> $(ARTIFACTS)\$(HWC_TAG)SET.LOG
	@echo [set-default].[combo] PASSED >> $(LOGFILE)
	@echo [set-default].[combo] PASSED

# NOTE: does NOT include /FULLDUPLEX, /PNP, or /BSIZE:DISABLED because 3C509-TPO does not support them
set-default-tpo: set-default-common
	@echo [set-default].[tpo] PASSED >> $(LOGFILE)
	@echo [set-default].[tpo] PASSED

# NOTE: does NOT include /FULLDUPLEX and /PNP verbs because 3C509-TPCoax does not support them
set-default-tpc: set-default-common
	$(3C5X9CFG) CONFIGURE /ADAPTERNUM:1 /BSIZE:DISABLED >> $(ARTIFACTS)\$(HWC_TAG)SET.LOG
	@echo [set-default].[tpc] PASSED >> $(LOGFILE)
	@echo [set-default].[tpc] PASSED


# #################################
# Identity / capability checks.
# #################################

# Canonical testcase stub for testreport.py.
#
# the hwc001 target is never actually called, it's only here for structure.
# Runtime output is emitted by the card-specific targets further below.
hwc001:
	@echo [$(HWC_TAG)001] Reading $(CARDNAME) identity and capabilities > NUL

hwc001-common:
	@echo [$(HWC_TAG)001].[common] Reading $(CARDNAME) identity and capabilities >> $(LOGFILE)
	@echo [$(HWC_TAG)001].[common] Reading $(CARDNAME) identity and capabilities
	$(READERAPP) LIST > $(ARTIFACTS)\$(HWC_TAG)001.LOG

hwc001-btp: hwc001-common
	FIND "3Com 3C509B-TP:" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	FIND "(ASIC Revision 2)" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	FIND "Connectors = TP, AUI" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	FIND "Plug and Play Capability = yes" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	FIND "Full Duplex Capability = yes" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	@echo [$(HWC_TAG)001].[btp] PASSED >> $(LOGFILE)
	@echo [$(HWC_TAG)001].[btp] PASSED

hwc001-bcoax: hwc001-common
	FIND "3Com 3C509B:" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	FIND "(ASIC Revision 2)" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	FIND "Connectors = AUI, COAX" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	FIND "Plug and Play Capability = yes" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	FIND "Full Duplex Capability = no" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	@echo [$(HWC_TAG)001].[bcoax] PASSED >> $(LOGFILE)
	@echo [$(HWC_TAG)001].[bcoax] PASSED

hwc001-bcombo: hwc001-common
	FIND "3Com 3C509B-Combo:" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	FIND "(ASIC Revision 2)" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	FIND "Connectors = TP, AUI, COAX" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	FIND "Plug and Play Capability = yes" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	FIND "Full Duplex Capability = yes" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	@echo [$(HWC_TAG)001].[bcombo] PASSED >> $(LOGFILE)
	@echo [$(HWC_TAG)001].[bcombo] PASSED

hwc001-btpo: hwc001-common
	FIND "3Com 3C509B-TPO:" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	FIND "(ASIC Revision 2)" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	FIND "Connectors = TP" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	FIND "Plug and Play Capability = yes" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	FIND "Full Duplex Capability = yes" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	@echo [$(HWC_TAG)001].[btpo] PASSED >> $(LOGFILE)
	@echo [$(HWC_TAG)001].[btpo] PASSED

hwc001-btpc: hwc001-common
	FIND "3Com 3C509B-TPCoax:" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	FIND "(ASIC Revision 2)" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	FIND "Connectors = TP, COAX" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	FIND "Plug and Play Capability = yes" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	FIND "Full Duplex Capability = yes" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	@echo [$(HWC_TAG)001].[btpc] PASSED >> $(LOGFILE)
	@echo [$(HWC_TAG)001].[btpc] PASSED

hwc001-tp: hwc001-common
	FIND "3Com 3C509-TP:" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	FIND "(ASIC Revision 1)" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	FIND "Connectors = TP, AUI" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	FIND "Plug and Play Capability = not supported" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	FIND "Full Duplex Capability = not supported" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	@echo [$(HWC_TAG)001].[tp] PASSED >> $(LOGFILE)
	@echo [$(HWC_TAG)001].[tp] PASSED

hwc001-coax: hwc001-common
	FIND "3Com 3C509:" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	FIND "(ASIC Revision 1)" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	FIND "Connectors = AUI, COAX" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	FIND "Plug and Play Capability = not supported" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	FIND "Full Duplex Capability = not supported" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	@echo [$(HWC_TAG)001].[coax] PASSED >> $(LOGFILE)
	@echo [$(HWC_TAG)001].[coax] PASSED

hwc001-combo: hwc001-common
	FIND "3Com 3C509-Combo:" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	FIND "(ASIC Revision 1)" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	FIND "Connectors = TP, AUI, COAX" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	FIND "Plug and Play Capability = not supported" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	FIND "Full Duplex Capability = not supported" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	@echo [$(HWC_TAG)001].[combo] PASSED >> $(LOGFILE)
	@echo [$(HWC_TAG)001].[combo] PASSED

hwc001-tpo: hwc001-common
	FIND "3Com 3C509-TPO:" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	FIND "(ASIC Revision 1)" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	FIND "Connectors = TP" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	FIND "Plug and Play Capability = not supported" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	FIND "Full Duplex Capability = not supported" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	@echo [$(HWC_TAG)001].[tpo] PASSED >> $(LOGFILE)
	@echo [$(HWC_TAG)001].[tpo] PASSED

hwc001-tpc: hwc001-common
	FIND "3Com 3C509-TPCoax:" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	FIND "(ASIC Revision 1)" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	FIND "Connectors = TP, COAX" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	FIND "Plug and Play Capability = not supported" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	FIND "Full Duplex Capability = not supported" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	@echo [$(HWC_TAG)001].[tpc] PASSED >> $(LOGFILE)
	@echo [$(HWC_TAG)001].[tpc] PASSED


# #################################
# Common property readback tests.
# #################################

hwc002:
	@echo [$(HWC_TAG)002] $(WRITERNAME) /INT writer, $(READERNAME) LIST reader >> $(LOGFILE)
	@echo [$(HWC_TAG)002] $(WRITERNAME) /INT writer, $(READERNAME) LIST reader
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /INT:$(TEST_IRQ) > $(ARTIFACTS)\$(HWC_TAG)002.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\$(HWC_TAG)002.LOG
	FIND "IRQ = $(TEST_IRQ)" $(ARTIFACTS)\$(HWC_TAG)002.LOG > NUL
	@echo [$(HWC_TAG)002] PASSED >> $(LOGFILE)
	@echo [$(HWC_TAG)002] PASSED

hwc003:
	@echo [$(HWC_TAG)003] $(WRITERNAME) /IOBASE writer, $(READERNAME) LIST reader >> $(LOGFILE)
	@echo [$(HWC_TAG)003] $(WRITERNAME) /IOBASE writer, $(READERNAME) LIST reader
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /IOBASE:$(TEST_IOBASE) > $(ARTIFACTS)\$(HWC_TAG)003.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\$(HWC_TAG)003.LOG
	FIND "IOBASE = $(TEST_IOBASE)" $(ARTIFACTS)\$(HWC_TAG)003.LOG > NUL
	@echo [$(HWC_TAG)003] PASSED >> $(LOGFILE)
	@echo [$(HWC_TAG)003] PASSED

hwc004:
	@echo [$(HWC_TAG)004] $(WRITERNAME) /PNP writer, $(READERNAME) LIST reader >> $(LOGFILE)
	@echo [$(HWC_TAG)004] $(WRITERNAME) /PNP writer, $(READERNAME) LIST reader
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /PNP:$(TEST_PNP) > $(ARTIFACTS)\$(HWC_TAG)004.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\$(HWC_TAG)004.LOG
	FIND "Plug and Play = disabled" $(ARTIFACTS)\$(HWC_TAG)004.LOG > NUL
	@echo [$(HWC_TAG)004] PASSED >> $(LOGFILE)
	@echo [$(HWC_TAG)004] PASSED

hwc004-unsupported:
	@echo [$(HWC_TAG)004].[unsupported] PNP support is not supported by $(CARDNAME). >> $(LOGFILE)
	@echo [$(HWC_TAG)004].[unsupported] PNP support is not supported by $(CARDNAME).
	@echo [$(HWC_TAG)004].[unsupported] NOT SUPPORTED >> $(LOGFILE)
	@echo [$(HWC_TAG)004].[unsupported] NOT SUPPORTED

hwc005:
	@echo [$(HWC_TAG)005] $(WRITERNAME) /MODEM writer, $(READERNAME) LIST reader >> $(LOGFILE)
	@echo [$(HWC_TAG)005] $(WRITERNAME) /MODEM writer, $(READERNAME) LIST reader
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:$(TEST_MODEM) > $(ARTIFACTS)\$(HWC_TAG)005.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\$(HWC_TAG)005.LOG
	FIND "MODEM Interrupt Disable Time = 1300 us (1200 bd)" $(ARTIFACTS)\$(HWC_TAG)005.LOG > NUL
	@echo [$(HWC_TAG)005] PASSED >> $(LOGFILE)
	@echo [$(HWC_TAG)005] PASSED

hwc006:
	@echo [$(HWC_TAG)006] $(WRITERNAME) /FULLDUPLEX writer, $(READERNAME) LIST reader >> $(LOGFILE)
	@echo [$(HWC_TAG)006] $(WRITERNAME) /FULLDUPLEX writer, $(READERNAME) LIST reader
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:$(TEST_FULLDUPLEX) > $(ARTIFACTS)\$(HWC_TAG)006.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\$(HWC_TAG)006.LOG
	FIND "Full Duplex = enabled" $(ARTIFACTS)\$(HWC_TAG)006.LOG > NUL
	@echo [$(HWC_TAG)006] PASSED >> $(LOGFILE)
	@echo [$(HWC_TAG)006] PASSED

hwc006-unsupported:
	@echo [$(HWC_TAG)006].[unsupported] Full Duplex is not supported by $(CARDNAME). >> $(LOGFILE)
	@echo [$(HWC_TAG)006].[unsupported] Full Duplex is not supported by $(CARDNAME).
	@echo [$(HWC_TAG)006].[unsupported] NOT SUPPORTED >> $(LOGFILE)
	@echo [$(HWC_TAG)006].[unsupported] NOT SUPPORTED

hwc007:
	@echo [$(HWC_TAG)007] $(WRITERNAME) /OPTIMIZE writer, $(READERNAME) LIST reader >> $(LOGFILE)
	@echo [$(HWC_TAG)007] $(WRITERNAME) /OPTIMIZE writer, $(READERNAME) LIST reader
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /OPTIMIZE:$(TEST_OPTIMIZE) > $(ARTIFACTS)\$(HWC_TAG)007.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\$(HWC_TAG)007.LOG
	FIND "Optimization = Server" $(ARTIFACTS)\$(HWC_TAG)007.LOG > NUL
	@echo [$(HWC_TAG)007] PASSED >> $(LOGFILE)
	@echo [$(HWC_TAG)007] PASSED


# #################################
# Card-specific transceiver tests.
# #################################

# Canonical testcase stub for testreport.py.
#
# the hwc008 target is never actually called, it's only here for structure.
# Runtime output is emitted by the card-specific further below.
hwc008:
	@echo [$(HWC_TAG)008] card specific transceiver tests > NUL

hwc008-btp:
	@echo [$(HWC_TAG)008].[btp] $(WRITERNAME) /TR:AUI writer, $(READERNAME) LIST reader >> $(LOGFILE)
	@echo [$(HWC_TAG)008].[btp] $(WRITERNAME) /TR:AUI writer, $(READERNAME) LIST reader
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /TR:AUI > $(ARTIFACTS)\$(HWC_TAG)008.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\$(HWC_TAG)008.LOG
	FIND "Transceiver = external" $(ARTIFACTS)\$(HWC_TAG)008.LOG > NUL
	FIND "Full Duplex = disabled" $(ARTIFACTS)\$(HWC_TAG)008.LOG > NUL
	@echo [$(HWC_TAG)008].[btp] PASSED >> $(LOGFILE)
	@echo [$(HWC_TAG)008].[btp] PASSED

hwc008-bcoax:
	@echo [$(HWC_TAG)008].[bcoax] $(WRITERNAME) /TR:COAX writer, $(READERNAME) LIST reader >> $(LOGFILE)
	@echo [$(HWC_TAG)008].[bcoax] $(WRITERNAME) /TR:COAX writer, $(READERNAME) LIST reader
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /TR:COAX > $(ARTIFACTS)\$(HWC_TAG)008.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\$(HWC_TAG)008.LOG
	FIND "Transceiver = on-board coax" $(ARTIFACTS)\$(HWC_TAG)008.LOG > NUL
	@echo [$(HWC_TAG)008].[bcoax] PASSED >> $(LOGFILE)
	@echo [$(HWC_TAG)008].[bcoax] PASSED

hwc008-bcombo:
	@echo [$(HWC_TAG)008].[bcombo] $(WRITERNAME) /TR:COAX writer, $(READERNAME) LIST reader >> $(LOGFILE)
	@echo [$(HWC_TAG)008].[bcombo] $(WRITERNAME) /TR:COAX writer, $(READERNAME) LIST reader
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /TR:COAX > $(ARTIFACTS)\$(HWC_TAG)008.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\$(HWC_TAG)008.LOG
	FIND "Transceiver = on-board coax" $(ARTIFACTS)\$(HWC_TAG)008.LOG > NUL
	FIND "Full Duplex = disabled" $(ARTIFACTS)\$(HWC_TAG)008.LOG > NUL
	@echo [$(HWC_TAG)008].[bcombo] PASSED >> $(LOGFILE)
	@echo [$(HWC_TAG)008].[bcombo] PASSED

hwc008-btpc:
	@echo [$(HWC_TAG)008].[btpc] $(WRITERNAME) /TR:COAX writer, $(READERNAME) LIST reader >> $(LOGFILE)
	@echo [$(HWC_TAG)008].[btpc] $(WRITERNAME) /TR:COAX writer, $(READERNAME) LIST reader
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /TR:COAX > $(ARTIFACTS)\$(HWC_TAG)008.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\$(HWC_TAG)008.LOG
	FIND "Transceiver = on-board coax" $(ARTIFACTS)\$(HWC_TAG)008.LOG > NUL
	FIND "Full Duplex = disabled" $(ARTIFACTS)\$(HWC_TAG)008.LOG > NUL
	@echo [$(HWC_TAG)008].[btpc] PASSED >> $(LOGFILE)
	@echo [$(HWC_TAG)008].[btpc] PASSED

hwc008-btpo:
	@echo [$(HWC_TAG)008].[btpo] /TR change is not supported by $(CARDNAME). >> $(LOGFILE)
	@echo [$(HWC_TAG)008].[btpo] /TR change is not supported by $(CARDNAME).
	@echo [$(HWC_TAG)008].[btpo] NOT SUPPORTED >> $(LOGFILE)
	@echo [$(HWC_TAG)008].[btpo] NOT SUPPORTED

hwc008-tp:
	@echo [$(HWC_TAG)008].[tp] $(WRITERNAME) /TR:AUI writer, $(READERNAME) LIST reader >> $(LOGFILE)
	@echo [$(HWC_TAG)008].[tp] $(WRITERNAME) /TR:AUI writer, $(READERNAME) LIST reader
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /TR:AUI > $(ARTIFACTS)\$(HWC_TAG)008.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\$(HWC_TAG)008.LOG
	FIND "Transceiver = external" $(ARTIFACTS)\$(HWC_TAG)008.LOG > NUL
	@echo [$(HWC_TAG)008].[tp] PASSED >> $(LOGFILE)
	@echo [$(HWC_TAG)008].[tp] PASSED

hwc008-tpo:
	@echo [$(HWC_TAG)008].[tpo] /TR change is not supported by $(CARDNAME). >> $(LOGFILE)
	@echo [$(HWC_TAG)008].[tpo] /TR change is not supported by $(CARDNAME).
	@echo [$(HWC_TAG)008].[tpo] NOT SUPPORTED >> $(LOGFILE)
	@echo [$(HWC_TAG)008].[tpo] NOT SUPPORTED

hwc008-coax:
	@echo [$(HWC_TAG)008].[coax] $(WRITERNAME) /TR:COAX writer, $(READERNAME) LIST reader >> $(LOGFILE)
	@echo [$(HWC_TAG)008].[coax] $(WRITERNAME) /TR:COAX writer, $(READERNAME) LIST reader
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /TR:COAX > $(ARTIFACTS)\$(HWC_TAG)008.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\$(HWC_TAG)008.LOG
	FIND "Transceiver = on-board coax" $(ARTIFACTS)\$(HWC_TAG)008.LOG > NUL
	@echo [$(HWC_TAG)008].[coax] PASSED >> $(LOGFILE)
	@echo [$(HWC_TAG)008].[coax] PASSED

hwc008-combo:
	@echo [$(HWC_TAG)008].[combo] $(WRITERNAME) /TR:COAX writer, $(READERNAME) LIST reader >> $(LOGFILE)
	@echo [$(HWC_TAG)008].[combo] $(WRITERNAME) /TR:COAX writer, $(READERNAME) LIST reader
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /TR:COAX > $(ARTIFACTS)\$(HWC_TAG)008.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\$(HWC_TAG)008.LOG
	FIND "Transceiver = on-board coax" $(ARTIFACTS)\$(HWC_TAG)008.LOG > NUL
	@echo [$(HWC_TAG)008].[combo] PASSED >> $(LOGFILE)
	@echo [$(HWC_TAG)008].[combo] PASSED

hwc008-tpc:
	@echo [$(HWC_TAG)008].[tpc] $(WRITERNAME) /TR:COAX writer, $(READERNAME) LIST reader >> $(LOGFILE)
	@echo [$(HWC_TAG)008].[tpc] $(WRITERNAME) /TR:COAX writer, $(READERNAME) LIST reader
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /TR:COAX > $(ARTIFACTS)\$(HWC_TAG)008.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\$(HWC_TAG)008.LOG
	FIND "Transceiver = on-board coax" $(ARTIFACTS)\$(HWC_TAG)008.LOG > NUL
	@echo [$(HWC_TAG)008].[tpc] PASSED >> $(LOGFILE)
	@echo [$(HWC_TAG)008].[tpc] PASSED



# #################################
# SAVECONFIG readback.
# #################################

# Canonical testcase stub for testreport.py.
#
# the hwc009 target is never actually called, it's only here for structure.
# Runtime output is emitted by the card-specific further below.
hwc009:
	@echo [$(HWC_TAG)009] SAVECONFIG readback > NUL

hwc009-common:
	@echo [$(HWC_TAG)009].[common] Reading combined hardware state through SAVECONFIG >> $(LOGFILE)
	@echo [$(HWC_TAG)009].[common] Reading combined hardware state through SAVECONFIG
	$(READERAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\$(HWC_TAG)009.BAT > $(ARTIFACTS)\$(HWC_TAG)009.LOG
	FIND "Configuration restore batch file created:" $(ARTIFACTS)\$(HWC_TAG)009.LOG > NUL
	FIND "INT:$(TEST_IRQ)" $(ARTIFACTS)\$(HWC_TAG)009.BAT > NUL
	FIND "IOBASE:$(TEST_IOBASE)" $(ARTIFACTS)\$(HWC_TAG)009.BAT > NUL
	FIND "MODEM:$(TEST_MODEM)" $(ARTIFACTS)\$(HWC_TAG)009.BAT > NUL
	FIND "OPTIMIZE:$(TEST_OPTIMIZE)" $(ARTIFACTS)\$(HWC_TAG)009.BAT > NUL

hwc009-btp: hwc009-common
	FIND "PNP:DISABLED" $(ARTIFACTS)\$(HWC_TAG)009.BAT > NUL
	FIND "FULLDUPLEX:DISABLED" $(ARTIFACTS)\$(HWC_TAG)009.BAT > NUL
	FIND "BSIZE:DISABLED" $(ARTIFACTS)\$(HWC_TAG)009.BAT > NUL
	FIND "TR:AUI" $(ARTIFACTS)\$(HWC_TAG)009.BAT > NUL
	@echo [$(HWC_TAG)009].[btp] PASSED >> $(LOGFILE)
	@echo [$(HWC_TAG)009].[btp] PASSED

hwc009-bcoax: hwc009-common
	FIND "PNP:DISABLED" $(ARTIFACTS)\$(HWC_TAG)009.BAT > NUL
	FIND "BSIZE:DISABLED" $(ARTIFACTS)\$(HWC_TAG)009.BAT > NUL
	FIND "TR:COAX" $(ARTIFACTS)\$(HWC_TAG)009.BAT > NUL
	@echo [$(HWC_TAG)009].[bcoax] PASSED >> $(LOGFILE)
	@echo [$(HWC_TAG)009].[bcoax] PASSED

hwc009-bcombo: hwc009-common
	FIND "PNP:DISABLED" $(ARTIFACTS)\$(HWC_TAG)009.BAT > NUL
	FIND "FULLDUPLEX:DISABLED" $(ARTIFACTS)\$(HWC_TAG)009.BAT > NUL
	FIND "BSIZE:DISABLED" $(ARTIFACTS)\$(HWC_TAG)009.BAT > NUL
	FIND "TR:COAX" $(ARTIFACTS)\$(HWC_TAG)009.BAT > NUL
	@echo [$(HWC_TAG)009].[bcombo] PASSED >> $(LOGFILE)
	@echo [$(HWC_TAG)009].[bcombo] PASSED

hwc009-btpo: hwc009-common
	FIND "PNP:DISABLED" $(ARTIFACTS)\$(HWC_TAG)009.BAT > NUL
	FIND "FULLDUPLEX:DISABLED" $(ARTIFACTS)\$(HWC_TAG)009.BAT > NUL
	FIND "TR:TP" $(ARTIFACTS)\$(HWC_TAG)009.BAT > NUL
	@echo [$(HWC_TAG)009].[btpo] PASSED >> $(LOGFILE)
	@echo [$(HWC_TAG)009].[btpo] PASSED

hwc009-btpc: hwc009-common
	FIND "PNP:DISABLED" $(ARTIFACTS)\$(HWC_TAG)009.BAT > NUL
	FIND "FULLDUPLEX:DISABLED" $(ARTIFACTS)\$(HWC_TAG)009.BAT > NUL
	FIND "BSIZE:DISABLED" $(ARTIFACTS)\$(HWC_TAG)009.BAT > NUL
	FIND "TR:COAX" $(ARTIFACTS)\$(HWC_TAG)009.BAT > NUL
	@echo [$(HWC_TAG)009].[btpc] PASSED >> $(LOGFILE)
	@echo [$(HWC_TAG)009].[btpc] PASSED

hwc009-tp: hwc009-common
	FIND "TR:AUI" $(ARTIFACTS)\$(HWC_TAG)009.BAT > NUL
	@echo [$(HWC_TAG)009].[tp] PASSED >> $(LOGFILE)
	@echo [$(HWC_TAG)009].[tp] PASSED

hwc009-coax: hwc009-common
	FIND "TR:COAX" $(ARTIFACTS)\$(HWC_TAG)009.BAT > NUL
	@echo [$(HWC_TAG)009].[coax] PASSED >> $(LOGFILE)
	@echo [$(HWC_TAG)009].[coax] PASSED

hwc009-combo: hwc009-common
	FIND "TR:COAX" $(ARTIFACTS)\$(HWC_TAG)009.BAT > NUL
	@echo [$(HWC_TAG)009].[combo] PASSED >> $(LOGFILE)
	@echo [$(HWC_TAG)009].[combo] PASSED

hwc009-tpo: hwc009-common
	FIND "TR:TP" $(ARTIFACTS)\$(HWC_TAG)009.BAT > NUL
	@echo [$(HWC_TAG)009].[tpo] PASSED >> $(LOGFILE)
	@echo [$(HWC_TAG)009].[tpo] PASSED

hwc009-tpc: hwc009-common
	FIND "TR:COAX" $(ARTIFACTS)\$(HWC_TAG)009.BAT > NUL
	@echo [$(HWC_TAG)009].[tpc] PASSED >> $(LOGFILE)
	@echo [$(HWC_TAG)009].[tpc] PASSED

hwc010:
	@echo [$(HWC_TAG)010] 3CCFGCLI multi-property CONFIGURE transaction >> $(LOGFILE)
	@echo [$(HWC_TAG)010] 3CCFGCLI multi-property CONFIGURE transaction
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /INT:$(DEFAULT_IRQ) /IOBASE:$(DEFAULT_IOBASE) /MODEM:$(DEFAULT_MODEM) /OPTIMIZE:$(DEFAULT_OPTIMIZE) > $(ARTIFACTS)\$(HWC_TAG)010.LOG
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /INT:$(TEST_IRQ) /IOBASE:$(TEST_IOBASE) /MODEM:$(TEST_MODEM) /OPTIMIZE:$(TEST_OPTIMIZE) >> $(ARTIFACTS)\$(HWC_TAG)010.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\$(HWC_TAG)010.LOG
	FIND "IOBASE = $(TEST_IOBASE), IRQ = $(TEST_IRQ)" $(ARTIFACTS)\$(HWC_TAG)010.LOG > NUL
	FIND "MODEM Interrupt Disable Time = 1300 us (1200 bd)" $(ARTIFACTS)\$(HWC_TAG)010.LOG > NUL
	FIND "Optimization = Server" $(ARTIFACTS)\$(HWC_TAG)010.LOG > NUL
	@echo [$(HWC_TAG)010] PASSED >> $(LOGFILE)
	@echo [$(HWC_TAG)010] PASSED



# #################################
# Multi NIC physical write check.
# #################################
#
# Exactly two adapters are required. The original utility establishes a
# deliberately ambiguous baseline in which both adapters use the same IOBASE
# and IRQ. A fresh 3CCFGCLI LIST reads that baseline, then 3CCFGCLI moves
# adapter 2 to a distinct IOBASE and IRQ. A second fresh LIST verifies that the
# selected adapter moved while its peer remained at the shared starting state.

hwcm001:
	@echo [$(HWC_TAG)001] LIST with two adapters set at distinct IOBASE values >> $(LOGFILE)
	@echo [$(HWC_TAG)001] LIST with two adapters set at distinct IOBASE values
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /IOBASE:$(MULTI_CARD1_IOBASE) /INT:$(MULTI_CARD1_IRQ) > $(ARTIFACTS)\$(HWC_TAG)001.LOG
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:2 /IOBASE:$(MULTI_CARD2_IOBASE) /INT:$(MULTI_CARD2_IRQ) >> $(ARTIFACTS)\$(HWC_TAG)001.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\$(HWC_TAG)001.LOG
	FIND "IOBASE = $(MULTI_CARD1_IOBASE), IRQ = $(MULTI_CARD1_IRQ)" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	FIND "IOBASE = $(MULTI_CARD2_IOBASE), IRQ = $(MULTI_CARD2_IRQ)" $(ARTIFACTS)\$(HWC_TAG)001.LOG > NUL
	@echo [$(HWC_TAG)001] PASSED >> $(LOGFILE)
	@echo [$(HWC_TAG)001] PASSED

hwcm002:
	@echo [$(HWC_TAG)002] SAVECONFIG with two adapters set at distinct IOBASE values >> $(LOGFILE)
	@echo [$(HWC_TAG)002] SAVECONFIG with two adapters set at distinct IOBASE values
	$(READERAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\$(HWC_TAG)002.BAT > $(ARTIFACTS)\$(HWC_TAG)002.LOG
	FIND "IOBASE:$(MULTI_CARD1_IOBASE)" $(ARTIFACTS)\$(HWC_TAG)002.BAT > NUL
	FIND "INT:$(MULTI_CARD1_IRQ)" $(ARTIFACTS)\$(HWC_TAG)002.BAT > NUL
	FIND "IOBASE:$(MULTI_CARD2_IOBASE)" $(ARTIFACTS)\$(HWC_TAG)002.BAT > NUL
	FIND "INT:$(MULTI_CARD2_IRQ)" $(ARTIFACTS)\$(HWC_TAG)002.BAT > NUL
	@echo [$(HWC_TAG)002] PASSED >> $(LOGFILE)
	@echo [$(HWC_TAG)002] PASSED

hwcm003:
	@echo [$(HWC_TAG)003] LIST with two adapters sharing one IOBASE >> $(LOGFILE)
	@echo [$(HWC_TAG)003] LIST with two adapters sharing one IOBASE
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /IOBASE:$(MULTI_SHARED_IOBASE) /INT:$(MULTI_CARD1_IRQ) > $(ARTIFACTS)\$(HWC_TAG)003.LOG
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:2 /IOBASE:$(MULTI_SHARED_IOBASE) /INT:$(MULTI_CARD2_IRQ) >> $(ARTIFACTS)\$(HWC_TAG)003.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\$(HWC_TAG)003.LOG
	FIND "IOBASE = $(MULTI_SHARED_IOBASE), IRQ = $(MULTI_CARD1_IRQ)" $(ARTIFACTS)\$(HWC_TAG)003.LOG > NUL
	FIND "IOBASE = $(MULTI_SHARED_IOBASE), IRQ = $(MULTI_CARD2_IRQ)" $(ARTIFACTS)\$(HWC_TAG)003.LOG > NUL
	@echo [$(HWC_TAG)003] PASSED >> $(LOGFILE)
	@echo [$(HWC_TAG)003] PASSED

hwcm004:
	@echo [$(HWC_TAG)004] SAVECONFIG with two adapters sharing one IOBASE >> $(LOGFILE)
	@echo [$(HWC_TAG)004] SAVECONFIG with two adapters sharing one IOBASE
	$(READERAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\$(HWC_TAG)004.BAT > $(ARTIFACTS)\$(HWC_TAG)004.LOG
	FIND "IOBASE:$(MULTI_SHARED_IOBASE)" $(ARTIFACTS)\$(HWC_TAG)004.BAT > NUL
	FIND "INT:$(MULTI_CARD1_IRQ)" $(ARTIFACTS)\$(HWC_TAG)004.BAT > NUL
	FIND "INT:$(MULTI_CARD2_IRQ)" $(ARTIFACTS)\$(HWC_TAG)004.BAT > NUL
	@echo [$(HWC_TAG)004] PASSED >> $(LOGFILE)
	@echo [$(HWC_TAG)004] PASSED


hwcm005:
	@echo [$(HWC_TAG)005] selected adapter migrates out of a duplicate IOBASE state >> $(LOGFILE)
	@echo [$(HWC_TAG)005] selected adapter migrates out of a duplicate IOBASE state
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /IOBASE:$(MULTI_SHARED_IOBASE) /INT:$(MULTI_CARD1_IRQ) > $(ARTIFACTS)\$(HWC_TAG)005.LOG
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:2 /IOBASE:$(MULTI_SHARED_IOBASE) /INT:$(MULTI_CARD2_IRQ) >> $(ARTIFACTS)\$(HWC_TAG)005.LOG
	$(READERAPP) LIST > $(ARTIFACTS)\$(HWC_TAG)005.PRE
	FIND "IOBASE = $(MULTI_SHARED_IOBASE)" $(ARTIFACTS)\$(HWC_TAG)005.PRE > NUL
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:2 /IOBASE:$(MULTI_CARD2_IOBASE) /INT:$(MULTI_CARD2_IRQ) > $(ARTIFACTS)\$(HWC_TAG)005.LOG
	FIND "Configuration completed" $(ARTIFACTS)\$(HWC_TAG)005.LOG > NUL
	$(READERAPP) LIST > $(ARTIFACTS)\$(HWC_TAG)005.LOG
	FIND "IOBASE = $(MULTI_SHARED_IOBASE), IRQ = $(MULTI_CARD1_IRQ)" $(ARTIFACTS)\$(HWC_TAG)005.LOG > NUL
	FIND "IOBASE = $(MULTI_CARD2_IOBASE), IRQ = $(MULTI_CARD2_IRQ)" $(ARTIFACTS)\$(HWC_TAG)005.LOG > NUL
	@echo [$(HWC_TAG)005] PASSED >> $(LOGFILE)
	@echo [$(HWC_TAG)005] PASSED


# #################################
# Optional physical Boot ROM test.
# #################################

# #################################
# Optional physical Boot ROM test.
# #################################

hwc-rom-unsupported:
	@echo [$(HWC_TAG)051] Boot ROM is not supported by $(CARDNAME). >> $(LOGFILE)
	@echo [$(HWC_TAG)051] Boot ROM is not supported by $(CARDNAME).
	@echo [$(HWC_TAG)051] NOT SUPPORTED >> $(LOGFILE)
	@echo [$(HWC_TAG)051] NOT SUPPORTED

hwc-rom-not-implemented:
	@echo [$(HWC_TAG)051] Boot ROM testing is currently not implemented for $(CARDNAME). >> $(LOGFILE)
	@echo [$(HWC_TAG)051] Boot ROM testing is currently not implemented for $(CARDNAME).
	@echo [$(HWC_TAG)051] NOT IMPLEMENTED >> $(LOGFILE)
	@echo [$(HWC_TAG)051] NOT IMPLEMENTED

hwc-rom-disabled:
	@echo [$(HWC_TAG)051] Boot ROM testing is currently disabled for $(CARDNAME). >> $(LOGFILE)
	@echo [$(HWC_TAG)051] Boot ROM testing is currently disabled for $(CARDNAME).
	@echo [$(HWC_TAG)051] DISABLED >> $(LOGFILE)
	@echo [$(HWC_TAG)051] DISABLED

hwc051:
	@echo [$(HWC_TAG)051] $(WRITERNAME) Boot ROM writer, $(READERNAME) LIST/SAVECONFIG reader >> $(LOGFILE)
	@echo [$(HWC_TAG)051] $(WRITERNAME) Boot ROM writer, $(READERNAME) LIST/SAVECONFIG reader
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:$(TEST_BADDRESS) /BSIZE:$(TEST_BSIZE) > $(ARTIFACTS)\$(HWC_TAG)051.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\$(HWC_TAG)051.LOG
	FIND "Boot ROM = $(TEST_BSIZE)K at $(TEST_BADDRESS)H" $(ARTIFACTS)\$(HWC_TAG)051.LOG > NUL
	$(READERAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\$(HWC_TAG)051.BAT >> $(ARTIFACTS)\$(HWC_TAG)051.LOG
	FIND "BADDRESS:$(TEST_BADDRESS)" $(ARTIFACTS)\$(HWC_TAG)051.BAT > NUL
	FIND "BSIZE:$(TEST_BSIZE)" $(ARTIFACTS)\$(HWC_TAG)051.BAT > NUL
	@echo [$(HWC_TAG)051] PASSED >> $(LOGFILE)
	@echo [$(HWC_TAG)051] PASSED


# dummy target forHardware compliance SET verification.
#
# this exists only to sastisty restreport.py dependencies.
# The actual post-dependency checks are post-processed via
# TEST.MK on the development system.
#
hwcs0xx:
   @echo HWC SET verification: Verify 3C5X9CFG post HWC configuration dump

hwcs001:
   @echo [hwcs001] HWC SET verification: Verify 3C5X9CFG post HWC configuration dump
