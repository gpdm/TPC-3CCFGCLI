# 3CCFGCLI Hardware Compliance Write checks.
#
# 3CCFGCLI performs the hardware writes in this suite.
# Deterministic starting states are established by the original 3Com utility.
# Each 3CCFGCLI CONFIGURE invocation is followed by a fresh 3CCFGCLI LIST
# process which verifies the resulting physical adapter state.
#
# This proves the physical CONFIGURE write path together with persistent
# readback through a separate 3CCFGCLI process. After the write run,
# HWCTEST.BAT additionally drives the original 3Com utility interactively to
# save its own configuration dump, then invokes the matching verification
# target in this makefile for an independent vendor-tool cross-check.
#
# HWCTEST.BAT is the default entry point. It detects the installed model and
# invokes the matching card specific target in this makefile.
#
# Usage:
#   HWCTEST.BAT CONFIG
#
# Optional physical Boot ROM write test:
#   HWCTEST.BAT ROMCONFIG
#
# If a run aborts after writes have started:
#   MAKE -fHWCWRITE.MK restore-config
#

RESTOREBAT = HWCWREST.BAT
REFERENCEAPP = 3C5X9CFG.EXE
WRITERAPP = 3CCFGCLI.EXE
READERAPP = 3CCFGCLI.EXE
ARTIFACTS = ARTIFACT
ASSERTERS = ASSERTRS
LOGFILE = HWCWRITE.LOG
CFGDUMP = $(ARTIFACTS)\HWCW.SET
ROMDUMP = $(ARTIFACTS)\HWCW-ROM.SET

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
	@echo Do not start HWCWRITE.MK directly.

prep:
	@if not exist $(ARTIFACTS)\NUL mkdir $(ARTIFACTS)
	@echo Running 3CCFGCLI Hardware Compliance Write checks... >> $(LOGFILE)
	@echo Running 3CCFGCLI Hardware Compliance Write checks...

complete:
	@echo Hardware Compliance Write checks completed. >> $(LOGFILE)
	@echo Hardware Compliance Write checks completed.

clean:
	@if exist $(LOGFILE) del $(LOGFILE)
	@if exist $(ARTIFACTS)\HWCW*.LOG del $(ARTIFACTS)\HWCW*.LOG
	@if exist $(ARTIFACTS)\HWCW*.BAT del $(ARTIFACTS)\HWCW*.BAT

# Card specific run targets.
hwcw-btp: clean prep save-config set-default-btp HWCW_COMMON hwcw003 hwcw005 hwcw007-btp hwcw008 restore-config complete
hwcw-bcoax: clean prep save-config set-default-bcoax HWCW_COMMON hwcw003 hwcw007-bcoax hwcw008 restore-config complete
hwcw-bcombo: clean prep save-config set-default-bcombo HWCW_COMMON hwcw003 hwcw005 hwcw007-bcombo hwcw008 restore-config complete
hwcw-btpo: clean prep save-config set-default-btpo HWCW_COMMON hwcw003 hwcw005 hwcw008 restore-config complete
hwcw-btpc: clean prep save-config set-default-btpc HWCW_COMMON hwcw003 hwcw005 hwcw007-btpc hwcw008 restore-config complete
hwcw-tp: clean prep save-config set-default-tp HWCW_COMMON hwcw007-tp hwcw008 restore-config complete

# Optional physical Boot ROM write runs.
hwcw-rom-btp: clean prep save-config set-default-btp hwcw009 restore-config complete
hwcw-rom-bcoax: clean prep save-config set-default-bcoax hwcw009 restore-config complete
hwcw-rom-bcombo: clean prep save-config set-default-bcombo hwcw009 restore-config complete
hwcw-rom-btpc: clean prep save-config set-default-btpc hwcw009 restore-config complete

# Emit warning for NICs which explicitely don't
# have support for Network Boot ROM.
hwcw-rom-btpo:
	@echo Boot ROM is not supported on the 3C509B-TPO. >> $(LOGFILE)
	@echo Boot ROM is not supported on the 3C509B-TPO.

hwcw-rom-tpo:
	@echo Boot ROM is not supported on the 3C509-TPO. >> $(LOGFILE)
	@echo Boot ROM is not supported on the 3C509-TPO.

# Emit warning for currently non-implemented ROM targets.
hwcw-rom-not-implemented:
	@echo Boot ROM testing is currently not enabled for this device type. >> $(LOGFILE)
	@echo Boot ROM testing is currently not enabled for this device type.

hwcw-rom-tp: hwcw-rom-not-implemented
hwcw-rom-coax: hwcw-rom-not-implemented
hwcw-rom-combo: hwcw-rom-not-implemented
hwcw-rom-tpc: hwcw-rom-not-implemented


# Common property writes valid on all supported models.
HWCW_COMMON: hwcw001 hwcw002 hwcw004 hwcw006

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
	@echo $(ARTIFACTS)\$(RESTOREBAT) $(REFERENCEAPP) >> $(LOGFILE)
	@echo $(ARTIFACTS)\$(RESTOREBAT) $(REFERENCEAPP)

restore: restore-config

# Deterministic baselines written by the original utility.

set-default-btp:
	@echo Writing 3C509B-TP baseline via original utility... >> $(LOGFILE)
	@echo Writing 3C509B-TP baseline via original utility...
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:DISABLED > $(ARTIFACTS)\HWCWSET.LOG
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /TR:TP >> $(ARTIFACTS)\HWCWSET.LOG
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /INT:$(DEFAULT_IRQ) /IOBASE:$(DEFAULT_IOBASE) /PNP:ENABLED /FULLDUPLEX:ENABLED >> $(ARTIFACTS)\HWCWSET.LOG
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:$(DEFAULT_MODEM) /OPTIMIZE:$(DEFAULT_OPTIMIZE) /BSIZE:DISABLED >> $(ARTIFACTS)\HWCWSET.LOG

set-default-bcoax:
	@echo Writing 3C509B-COAX baseline via original utility... >> $(LOGFILE)
	@echo Writing 3C509B-COAX baseline via original utility...
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /TR:AUI > $(ARTIFACTS)\HWCWSET.LOG
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /INT:$(DEFAULT_IRQ) /IOBASE:$(DEFAULT_IOBASE) /PNP:ENABLED >> $(ARTIFACTS)\HWCWSET.LOG
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:$(DEFAULT_MODEM) /OPTIMIZE:$(DEFAULT_OPTIMIZE) /BSIZE:DISABLED >> $(ARTIFACTS)\HWCWSET.LOG

set-default-bcombo:
	@echo Writing 3C509B-Combo baseline via original utility... >> $(LOGFILE)
	@echo Writing 3C509B-Combo baseline via original utility...
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:DISABLED > $(ARTIFACTS)\HWCWSET.LOG
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /TR:TP >> $(ARTIFACTS)\HWCWSET.LOG
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /INT:$(DEFAULT_IRQ) /IOBASE:$(DEFAULT_IOBASE) /PNP:ENABLED /FULLDUPLEX:ENABLED >> $(ARTIFACTS)\HWCWSET.LOG
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:$(DEFAULT_MODEM) /OPTIMIZE:$(DEFAULT_OPTIMIZE) /BSIZE:DISABLED >> $(ARTIFACTS)\HWCWSET.LOG

set-default-btpo:
	@echo Writing 3C509B-TPO baseline via original utility... >> $(LOGFILE)
	@echo Writing 3C509B-TPO baseline via original utility...
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:DISABLED > $(ARTIFACTS)\HWCWSET.LOG
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /TR:TP >> $(ARTIFACTS)\HWCWSET.LOG
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /INT:$(DEFAULT_IRQ) /IOBASE:$(DEFAULT_IOBASE) /PNP:ENABLED /FULLDUPLEX:ENABLED >> $(ARTIFACTS)\HWCWSET.LOG
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:$(DEFAULT_MODEM) /OPTIMIZE:$(DEFAULT_OPTIMIZE) >> $(ARTIFACTS)\HWCWSET.LOG

set-default-btpc:
	@echo Writing 3C509B-TPCoax baseline via original utility... >> $(LOGFILE)
	@echo Writing 3C509B-TPCoax baseline via original utility...
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:DISABLED > $(ARTIFACTS)\HWCWSET.LOG
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /TR:TP >> $(ARTIFACTS)\HWCWSET.LOG
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /INT:$(DEFAULT_IRQ) /IOBASE:$(DEFAULT_IOBASE) /PNP:ENABLED /FULLDUPLEX:ENABLED >> $(ARTIFACTS)\HWCWSET.LOG
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:$(DEFAULT_MODEM) /OPTIMIZE:$(DEFAULT_OPTIMIZE) /BSIZE:DISABLED >> $(ARTIFACTS)\HWCWSET.LOG

set-default-tp:
	@echo Writing 3C509-TP baseline via original utility... >> $(LOGFILE)
	@echo Writing 3C509-TP baseline via original utility...
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /TR:TP > $(ARTIFACTS)\HWCWSET.LOG
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /INT:$(DEFAULT_IRQ) /IOBASE:$(DEFAULT_IOBASE) >> $(ARTIFACTS)\HWCWSET.LOG
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:$(DEFAULT_MODEM) /OPTIMIZE:$(DEFAULT_OPTIMIZE) >> $(ARTIFACTS)\HWCWSET.LOG

# Individual physical write checks.

hwcw001:
	@echo [hwcw001] 3CCFGCLI /INT writer, fresh LIST readback... >> $(LOGFILE)
	@echo [hwcw001] 3CCFGCLI /INT writer, fresh LIST readback...
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /INT:$(TEST_IRQ) > $(ARTIFACTS)\HWCW001.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCW001.LOG
	FIND "IRQ = $(TEST_IRQ)" $(ARTIFACTS)\HWCW001.LOG > NUL

hwcw002:
	@echo [hwcw002] 3CCFGCLI /IOBASE writer, fresh LIST readback... >> $(LOGFILE)
	@echo [hwcw002] 3CCFGCLI /IOBASE writer, fresh LIST readback...
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /IOBASE:$(TEST_IOBASE) > $(ARTIFACTS)\HWCW002.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCW002.LOG
	FIND "IOBASE = $(TEST_IOBASE)" $(ARTIFACTS)\HWCW002.LOG > NUL

hwcw003:
	@echo [hwcw003] 3CCFGCLI /PNP writer, fresh LIST readback... >> $(LOGFILE)
	@echo [hwcw003] 3CCFGCLI /PNP writer, fresh LIST readback...
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /PNP:$(TEST_PNP) > $(ARTIFACTS)\HWCW003.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCW003.LOG
	FIND "Plug and Play = disabled" $(ARTIFACTS)\HWCW003.LOG > NUL

hwcw004:
	@echo [hwcw004] 3CCFGCLI /MODEM writer, fresh LIST readback... >> $(LOGFILE)
	@echo [hwcw004] 3CCFGCLI /MODEM writer, fresh LIST readback...
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:$(TEST_MODEM) > $(ARTIFACTS)\HWCW004.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCW004.LOG
	FIND "MODEM Interrupt Disable Time = 1300 us (1200 bd)" $(ARTIFACTS)\HWCW004.LOG > NUL

hwcw005:
	@echo [hwcw005] 3CCFGCLI /FULLDUPLEX writer, fresh LIST readback... >> $(LOGFILE)
	@echo [hwcw005] 3CCFGCLI /FULLDUPLEX writer, fresh LIST readback...
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:DISABLED > $(ARTIFACTS)\HWCW005.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCW005.LOG
	FIND "Full Duplex = disabled" $(ARTIFACTS)\HWCW005.LOG > NUL

hwcw006:
	@echo [hwcw006] 3CCFGCLI /OPTIMIZE writer, fresh LIST readback... >> $(LOGFILE)
	@echo [hwcw006] 3CCFGCLI /OPTIMIZE writer, fresh LIST readback...
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /OPTIMIZE:$(TEST_OPTIMIZE) > $(ARTIFACTS)\HWCW006.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCW006.LOG
	FIND "Optimization = Server" $(ARTIFACTS)\HWCW006.LOG > NUL

# Card specific transceiver writes.

hwcw007-btp:
	@echo [hwcw007] 3CCFGCLI /TR:AUI writer, fresh LIST readback... >> $(LOGFILE)
	@echo [hwcw007] 3CCFGCLI /TR:AUI writer, fresh LIST readback...
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /TR:AUI > $(ARTIFACTS)\HWCW007.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCW007.LOG
	FIND "Transceiver = external" $(ARTIFACTS)\HWCW007.LOG > NUL

hwcw007-bcoax:
	@echo [hwcw007] 3CCFGCLI /TR:COAX writer, fresh LIST readback... >> $(LOGFILE)
	@echo [hwcw007] 3CCFGCLI /TR:COAX writer, fresh LIST readback...
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /TR:COAX > $(ARTIFACTS)\HWCW007.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCW007.LOG
	FIND "Transceiver = on-board coax" $(ARTIFACTS)\HWCW007.LOG > NUL

hwcw007-bcombo:
	@echo [hwcw007] 3CCFGCLI /TR:COAX writer, fresh LIST readback... >> $(LOGFILE)
	@echo [hwcw007] 3CCFGCLI /TR:COAX writer, fresh LIST readback...
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /TR:COAX > $(ARTIFACTS)\HWCW007.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCW007.LOG
	FIND "Transceiver = on-board coax" $(ARTIFACTS)\HWCW007.LOG > NUL

hwcw007-btpc:
	@echo [hwcw007] 3CCFGCLI /TR:COAX writer, fresh LIST readback... >> $(LOGFILE)
	@echo [hwcw007] 3CCFGCLI /TR:COAX writer, fresh LIST readback...
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /TR:COAX > $(ARTIFACTS)\HWCW007.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCW007.LOG
	FIND "Transceiver = on-board coax" $(ARTIFACTS)\HWCW007.LOG > NUL

hwcw007-tp:
	@echo [hwcw007] 3CCFGCLI /TR:AUI writer, fresh LIST readback... >> $(LOGFILE)
	@echo [hwcw007] 3CCFGCLI /TR:AUI writer, fresh LIST readback...
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /TR:AUI > $(ARTIFACTS)\HWCW007.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCW007.LOG
	FIND "Transceiver = external" $(ARTIFACTS)\HWCW007.LOG > NUL

# Multi property physical transaction.
#
# Re-establish the common defaults with the original utility, then write all
# four common TEST values in one 3CCFGCLI CONFIGURE transaction. This leaves
# the adapter in a clear, intentional final state for the independent vendor
# configuration dump performed by HWCTEST.BAT after this make run.

hwcw008:
	@echo [hwcw008] 3CCFGCLI multi-property CONFIGURE transaction... >> $(LOGFILE)
	@echo [hwcw008] 3CCFGCLI multi-property CONFIGURE transaction...
	$(REFERENCEAPP) CONFIGURE /ADAPTERNUM:1 /INT:$(DEFAULT_IRQ) /IOBASE:$(DEFAULT_IOBASE) /MODEM:$(DEFAULT_MODEM) /OPTIMIZE:$(DEFAULT_OPTIMIZE) > $(ARTIFACTS)\HWCW008.LOG
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /INT:$(TEST_IRQ) /IOBASE:$(TEST_IOBASE) /MODEM:$(TEST_MODEM) /OPTIMIZE:$(TEST_OPTIMIZE) >> $(ARTIFACTS)\HWCW008.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCW008.LOG
	FIND "IOBASE = $(TEST_IOBASE), IRQ = $(TEST_IRQ)" $(ARTIFACTS)\HWCW008.LOG > NUL
	FIND "MODEM Interrupt Disable Time = 1300 us (1200 bd)" $(ARTIFACTS)\HWCW008.LOG > NUL
	FIND "Optimization = Server" $(ARTIFACTS)\HWCW008.LOG > NUL

# Optional physical Boot ROM write test.

hwcw009:
	@echo [hwcw009] 3CCFGCLI Boot ROM writer, fresh LIST readback... >> $(LOGFILE)
	@echo [hwcw009] 3CCFGCLI Boot ROM writer, fresh LIST readback...
	$(WRITERAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:$(TEST_BADDRESS) /BSIZE:$(TEST_BSIZE) > $(ARTIFACTS)\HWCW009.LOG
	$(READERAPP) LIST >> $(ARTIFACTS)\HWCW009.LOG
	FIND "Boot ROM = $(TEST_BSIZE)K at $(TEST_BADDRESS)H" $(ARTIFACTS)\HWCW009.LOG > NUL





# Independent vendor configuration dump verification.
#
# HWCTEST.BAT creates these files interactively through 3C5X9CFG after the
# corresponding write run has completed:
#
#   CONFIG:    ARTIFACT\HWCW.SET
#   ROMCONFIG: ARTIFACT\HWCW-ROM.SET
#
# 3C5X9CFG configuration files use lines of the form:
#
#   @Variable name:value
#
# The normal CONFIG run intentionally finishes with the TEST values for the
# common properties. The ROMCONFIG run only changes the Boot PROM settings,
# so its dump is expected to retain the card-specific deterministic baseline.
#
# The Boot PROM checks below are extrapolated from 3C5X9CFG's documented
# configuration-file variable names. The prefix matches deliberately stop
# after "16" and "C8000" so they accept harmless formatting suffixes such as
# "16 K" or "C8000H" if the saved file uses them.

# Normal CONFIG vendor dump entry points.

hwcw-btp-vrfy: HWCW_VRFY_COMMON HWCW_VRFY_PNP HWCW_VRFY_FD HWCW_VRFY_TR_EXTERNAL
	@echo Vendor configuration dump verification completed for 3C509B-TP. >> $(LOGFILE)
	@echo Vendor configuration dump verification completed for 3C509B-TP.

hwcw-bcoax-vrfy: HWCW_VRFY_COMMON HWCW_VRFY_PNP HWCW_VRFY_TR_COAX
	@echo Vendor configuration dump verification completed for 3C509B-COAX. >> $(LOGFILE)
	@echo Vendor configuration dump verification completed for 3C509B-COAX.

hwcw-bcombo-vrfy: HWCW_VRFY_COMMON HWCW_VRFY_PNP HWCW_VRFY_FD HWCW_VRFY_TR_COAX
	@echo Vendor configuration dump verification completed for 3C509B-Combo. >> $(LOGFILE)
	@echo Vendor configuration dump verification completed for 3C509B-Combo.

hwcw-btpo-vrfy: HWCW_VRFY_COMMON HWCW_VRFY_PNP HWCW_VRFY_FD HWCW_VRFY_TR_TP
	@echo Vendor configuration dump verification completed for 3C509B-TPO. >> $(LOGFILE)
	@echo Vendor configuration dump verification completed for 3C509B-TPO.

hwcw-btpc-vrfy: HWCW_VRFY_COMMON HWCW_VRFY_PNP HWCW_VRFY_FD HWCW_VRFY_TR_COAX
	@echo Vendor configuration dump verification completed for 3C509B-TPCoax. >> $(LOGFILE)
	@echo Vendor configuration dump verification completed for 3C509B-TPCoax.

hwcw-tp-vrfy: HWCW_VRFY_COMMON HWCW_VRFY_TR_EXTERNAL
	@echo Vendor configuration dump verification completed for 3C509-TP. >> $(LOGFILE)
	@echo Vendor configuration dump verification completed for 3C509-TP.


# Common final state after the normal CONFIG run.

HWCW_VRFY_COMMON:
	@echo [vrfy] Verifying common CONFIG values in 3C5X9CFG dump... >> $(LOGFILE)
	@echo [vrfy] Verifying common CONFIG values in 3C5X9CFG dump...
	$(ASSERTERS)\LFIND.BAT $(CFGDUMP) "base address:" "280"
	$(ASSERTERS)\LFIND.BAT $(CFGDUMP) "Interrupt request level:" "3"
	$(ASSERTERS)\LFIND.BAT $(CFGDUMP) "Network driver optimization:" "server"
	$(ASSERTERS)\LFIND.BAT $(CFGDUMP) "Maximum interrupt disable time:" "1300 microseconds"

HWCW_VRFY_PNP:
	@echo [vrfy] Verifying Plug and Play state in 3C5X9CFG dump... >> $(LOGFILE)
	@echo [vrfy] Verifying Plug and Play state in 3C5X9CFG dump...
	$(ASSERTERS)\LFIND.BAT $(CFGDUMP) "Plug and Play Capability:" "disabled"

HWCW_VRFY_FD:
	@echo [vrfy] Verifying Full Duplex state in 3C5X9CFG dump... >> $(LOGFILE)
	@echo [vrfy] Verifying Full Duplex state in 3C5X9CFG dump...
	$(ASSERTERS)\LFIND.BAT $(CFGDUMP) "Full Duplex:" "disabled"

HWCW_VRFY_TR_TP:
	@echo [vrfy] Verifying TP transceiver state in 3C5X9CFG dump... >> $(LOGFILE)
	@echo [vrfy] Verifying TP transceiver state in 3C5X9CFG dump...
	$(ASSERTERS)\LFIND.BAT $(CFGDUMP) "Transceiver type:" "on-board TP"

HWCW_VRFY_TR_COAX:
	@echo [vrfy] Verifying coax transceiver state in 3C5X9CFG dump... >> $(LOGFILE)
	@echo [vrfy] Verifying coax transceiver state in 3C5X9CFG dump...
	$(ASSERTERS)\LFIND.BAT $(CFGDUMP) "Transceiver type:" "on-board coax"

HWCW_VRFY_TR_EXTERNAL:
	@echo [vrfy] Verifying external transceiver state in 3C5X9CFG dump... >> $(LOGFILE)
	@echo [vrfy] Verifying external transceiver state in 3C5X9CFG dump...
	$(ASSERTERS)\LFIND.BAT $(CFGDUMP) "Transceiver type:" "external"


# ROMCONFIG vendor dump entry points.
#
# The ROM write run changes only Boot PROM address and size. Therefore the
# vendor dump verification for ROMCONFIG checks only the resulting Boot PROM
# state.

hwcw-rom-btp-vrfy: HWCW_ROM_VRFY_BOOT
	@echo Vendor ROM configuration dump verification completed for 3C509B-TP. >> $(LOGFILE)
	@echo Vendor ROM configuration dump verification completed for 3C509B-TP.

hwcw-rom-bcoax-vrfy: HWCW_ROM_VRFY_BOOT
	@echo Vendor ROM configuration dump verification completed for 3C509B-COAX. >> $(LOGFILE)
	@echo Vendor ROM configuration dump verification completed for 3C509B-COAX.

hwcw-rom-bcombo-vrfy: HWCW_ROM_VRFY_BOOT
	@echo Vendor ROM configuration dump verification completed for 3C509B-Combo. >> $(LOGFILE)
	@echo Vendor ROM configuration dump verification completed for 3C509B-Combo.

hwcw-rom-btpc-vrfy: HWCW_ROM_VRFY_BOOT
	@echo Vendor ROM configuration dump verification completed for 3C509B-TPCoax. >> $(LOGFILE)
	@echo Vendor ROM configuration dump verification completed for 3C509B-TPCoax.

HWCW_ROM_VRFY_BOOT:
	@echo [vrfy] Verifying Boot PROM state in 3C5X9CFG dump... >> $(LOGFILE)
	@echo [vrfy] Verifying Boot PROM state in 3C5X9CFG dump...
	$(ASSERTERS)\LFIND.BAT $(ROMDUMP) "Boot PROM size:" "16"
	$(ASSERTERS)\LFIND.BAT $(ROMDUMP) "Boot PROM base address:" "C8000"

# Emit warnings for Boot ROM verification targets.
# map unsupported and non-implemented cards.
#
hwcw-rom-btpo-vrfy: hwcw-rom-not-supported

hwcw-rom-tp-vrfy: hwcw-rom-not-implemented
hwcw-rom-tpo-vrfy: hwcw-rom-not-supported
hwcw-rom-coax-vrfy: hwcw-rom-not-implemented
hwcw-rom-combo-vrfy: hwcw-rom-not-implemented
hwcw-rom-tpc-vrfy: hwcw-rom-not-implemented