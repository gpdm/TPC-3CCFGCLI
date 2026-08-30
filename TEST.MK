# Borland MAKE test orchestration for 3CCFG project
# Usage:
#   MAKE -f TEST.MK test
#   MAKE -f TEST.MK smoke
#   MAKE -f TEST.MK test-build
#   MAKE -f TEST.MK clean-test

MAKEEXE = \TASM\BIN\MAKE
ARTIFACTS = ARTIFACT
BINAPP = BIN\3CHWMOCK.EXE

# Aliases
all: smoke
test: smoke

# Run against HW Mock (default)
mock:
	$(MAKEEXE) -f TEST.MK BINAPP=BIN\3CHWMOCK.EXE smoke

# Run against real hardware
real:
	$(MAKEEXE) -f TEST.MK BINAPP=BIN\3CCFGCLI.EXE smoke

test-build: prep build smoke-core
	@echo Build and Smoke Test: run completed >> TEST.LOG
	@echo Build and Smoke Test: run completed

smoke: prep smoke-core
	@echo Smoke test: run completed >> TEST.LOG
	@echo Smoke test: run completed

smoke-core: LISTING IRQ_CHANGE DEFAULT_NIC_SELECTION IOBASE_CHANGE PNP_CHANGE MODEM_CHANGE FD_CHANGE CAPABILITY_GATES OPTIMIZE_CHANGE LINK_STATUS BOOTROM_CHANGE XCVR_CHANGE CLI_PARSER COMBINED_TRANSACTIONS MULTI_NIC SAVECONFIG_TEST cleanup

prep:
	@if not exist $(ARTIFACTS) mkdir $(ARTIFACTS)
	@if exist TEST.LOG del TEST.LOG
	@if exist $(ARTIFACTS)\*.LOG del $(ARTIFACTS)\*.LOG
	@echo Running smoke test against $(BINAPP)... >> TEST.LOG

build:
	@echo Building all targets via MAKEFILE... >> TEST.LOG
	$(MAKEEXE) -f MAKEFILE all >> TEST.LOG

cleanup:
	@echo Cleaning seed file... >> TEST.LOG
	BIN\3CSEED.EXE CLEAR >> TEST.LOG
	@echo Smoke test complete. >> TEST.LOG

clean-test:
	@if exist TEST.LOG del TEST.LOG
	@if exist $(ARTIFACTS)\*.LOG del $(ARTIFACTS)\*.LOG
	@if exist $(ARTIFACTS)\RESTORE.BAT del $(ARTIFACTS)\RESTORE.BAT


# Symbolic Test Groups
# ####################

LISTING: t001 t002
IRQ_CHANGE: t003 t004 t005 t006
DEFAULT_NIC_SELECTION: t007 t008
IOBASE_CHANGE: t009 t010 t011 t012 t013 t014 t015 t016 t017
PNP_CHANGE: t018 t019 t020 t021 t022
MODEM_CHANGE: t023 t024 t025 t026 t027 t077
FD_CHANGE: t028 t029 t030 t031 t032
CAPABILITY_GATES: t033 t034
OPTIMIZE_CHANGE: t035 t036 t037
LINK_STATUS: t038 t039
BOOTROM_CHANGE: t040 t041 t042 t043 t044 t045 t046 t047 t048 t049 t050
XCVR_CHANGE: t051 t052 t053 t054 t055 t056 t057 t058 t059 t060 t061
CLI_PARSER: t062 t063 t064 t065
COMBINED_TRANSACTIONS: t066 t067 t068 t069 t070 t071
MULTI_NIC: t072 t073 t074 t075 t076
SAVECONFIG_TEST: t078 t079 t080 t081


# Test Case Definitions
# #####################

t001:
	@echo [t001] Clearing seed and checking no-card case... >> TEST.LOG
	BIN\3CSEED.EXE CLEAR >> TEST.LOG
	$(BINAPP) LIST > $(ARTIFACTS)\T001.LOG
	FIND "No EtherLink III NICs are installed in this computer." $(ARTIFACTS)\T001.LOG > NUL

t002:
	@echo [t002] Seeding INIT profile and checking card listing... >> TEST.LOG
	BIN\3CSEED.EXE INIT >> TEST.LOG
	$(BINAPP) LIST > $(ARTIFACTS)\T002.LOG
	FIND "NIC                            NIC" $(ARTIFACTS)\T002.LOG > NUL
	FIND "Number                       Description" $(ARTIFACTS)\T002.LOG > NUL

t003:
	@echo [t003] Testing mock CONFIGURE /INT invalid out-of-range value... >> TEST.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /INT:21 > $(ARTIFACTS)\T003.LOG
	FIND "Invalid /INT parameter. Value must be 3, 5, 7, 9, 10, 11, 12, or 15." $(ARTIFACTS)\T003.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T003.LOG
	FIND "IRQ = 10" $(ARTIFACTS)\T003.LOG > NUL

t004:
	@echo [t004] Testing mock CONFIGURE /INT invalid input... >> TEST.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /INT:BADVALUE > $(ARTIFACTS)\T004.LOG
	FIND "Invalid /INT parameter. Value must be 3, 5, 7, 9, 10, 11, 12, or 15." $(ARTIFACTS)\T004.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T004.LOG
	FIND "IRQ = 10" $(ARTIFACTS)\T004.LOG > NUL

t005:
	@echo [t005] Testing mock CONFIGURE /INT transition to 5... >> TEST.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /INT:5 > $(ARTIFACTS)\T005.LOG
	FIND "INT parameter accepted. Requested IRQ: 5" $(ARTIFACTS)\T005.LOG > NUL
	FIND "IRQ configuration completed successfully." $(ARTIFACTS)\T005.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T005.LOG
	FIND "IRQ = 5" $(ARTIFACTS)\T005.LOG > NUL

t006:
	@echo [t006] Testing mock CONFIGURE /INT transition back to 9... >> TEST.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /INT:9 > $(ARTIFACTS)\T006.LOG
	FIND "INT parameter accepted. Requested IRQ: 9" $(ARTIFACTS)\T006.LOG > NUL
	FIND "IRQ configuration completed successfully." $(ARTIFACTS)\T006.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T006.LOG
	FIND "IRQ = 9" $(ARTIFACTS)\T006.LOG > NUL

t007:
	@echo [t007] Testing default NIC selection CONFIGURE /INT transition to 5... >> TEST.LOG
	$(BINAPP) CONFIGURE /INT:5 > $(ARTIFACTS)\T007.LOG
	FIND "INT parameter accepted. Requested IRQ: 5" $(ARTIFACTS)\T007.LOG > NUL
	FIND "IRQ configuration completed successfully." $(ARTIFACTS)\T007.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T007.LOG
	FIND "IRQ = 5" $(ARTIFACTS)\T007.LOG > NUL

t008:
	@echo [t008] Testing default NIC selection CONFIGURE /INT transition back to 9... >> TEST.LOG
	$(BINAPP) CONFIGURE /INT:9 > $(ARTIFACTS)\T008.LOG
	FIND "INT parameter accepted. Requested IRQ: 9" $(ARTIFACTS)\T008.LOG > NUL
	FIND "IRQ configuration completed successfully." $(ARTIFACTS)\T008.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T008.LOG
	FIND "IRQ = 9" $(ARTIFACTS)\T008.LOG > NUL

t009:
	@echo [t009] Testing mock CONFIGURE /IOBASE invalid out-of-range high value... >> TEST.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /IOBASE:03F0 > $(ARTIFACTS)\T009.LOG
	FIND "Invalid /IOBASE parameter. Use hexadecimal 0200 through 03E0 in 10h increments." $(ARTIFACTS)\T009.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T009.LOG
	FIND "I/O = 0300" $(ARTIFACTS)\T009.LOG > NUL

t010:
	@echo [t010] Testing mock CONFIGURE /IOBASE invalid out-of-range low value... >> TEST.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /IOBASE:01F0 > $(ARTIFACTS)\T010.LOG
	FIND "Invalid /IOBASE parameter. Use hexadecimal 0200 through 03E0 in 10h increments." $(ARTIFACTS)\T010.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T010.LOG
	FIND "I/O = 0300" $(ARTIFACTS)\T010.LOG > NUL

t011:
	@echo [t011] Testing mock CONFIGURE /IOBASE arbitrary invalid input... >> TEST.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /IOBASE:BADVALUE > $(ARTIFACTS)\T011.LOG
	FIND "Invalid /IOBASE parameter. Use hexadecimal 0200 through 03E0 in 10h increments." $(ARTIFACTS)\T011.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T011.LOG
	FIND "I/O = 0300" $(ARTIFACTS)\T011.LOG > NUL

t012:
	@echo [t012] Testing mock CONFIGURE /IOBASE transition to 0280 (long notation)... >> TEST.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /IOBASE:0280 > $(ARTIFACTS)\T012.LOG
	FIND "IOBASE parameter accepted. Requested I/O base: 0280" $(ARTIFACTS)\T012.LOG > NUL
	FIND "I/O base configuration completed successfully." $(ARTIFACTS)\T012.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T012.LOG
	FIND "I/O = 0280" $(ARTIFACTS)\T012.LOG > NUL

t013:
	@echo [t013] Testing mock CONFIGURE /IOBASE transition back to 0300 (long notation)... >> TEST.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /IOBASE:0300 > $(ARTIFACTS)\T013.LOG
	FIND "IOBASE parameter accepted. Requested I/O base: 0300" $(ARTIFACTS)\T013.LOG > NUL
	FIND "I/O base configuration completed successfully." $(ARTIFACTS)\T013.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T013.LOG
	FIND "I/O = 0300" $(ARTIFACTS)\T013.LOG > NUL

t014:
	@echo [t014] Testing mock CONFIGURE /IOBASE transition to 280 (short notation)... >> TEST.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /IOBASE:280 > $(ARTIFACTS)\T014.LOG
	FIND "IOBASE parameter accepted. Requested I/O base: 0280" $(ARTIFACTS)\T014.LOG > NUL
	FIND "I/O base configuration completed successfully." $(ARTIFACTS)\T014.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T014.LOG
	FIND "I/O = 0280" $(ARTIFACTS)\T014.LOG > NUL

t015:
	@echo [t015] Testing mock CONFIGURE /IOBASE transition back to 300 (short notation)... >> TEST.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /IOBASE:300 > $(ARTIFACTS)\T015.LOG
	FIND "IOBASE parameter accepted. Requested I/O base: 0300" $(ARTIFACTS)\T015.LOG > NUL
	FIND "I/O base configuration completed successfully." $(ARTIFACTS)\T015.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T015.LOG
	FIND "I/O = 0300" $(ARTIFACTS)\T015.LOG > NUL

t016:
	@echo [t016] Testing CONFIGURE /IOBASE minimum valid address 0200... >> TEST.LOG
	BIN\3CSEED.EXE INIT > $(ARTIFACTS)\T016.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /IOBASE:0200 >> $(ARTIFACTS)\T016.LOG
	FIND "IOBASE parameter accepted. Requested I/O base: 0200" $(ARTIFACTS)\T016.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T016.LOG
	FIND "I/O = 0200" $(ARTIFACTS)\T016.LOG > NUL
	BIN\3CSEED.EXE INIT >> $(ARTIFACTS)\T016.LOG


t017:
	@echo [t017] Testing CONFIGURE /IOBASE maximum valid address 03E0... >> TEST.LOG
	BIN\3CSEED.EXE INIT > $(ARTIFACTS)\T017.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /IOBASE:03E0 >> $(ARTIFACTS)\T017.LOG
	FIND "IOBASE parameter accepted. Requested I/O base: 03E0" $(ARTIFACTS)\T017.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T017.LOG
	FIND "I/O = 03E0" $(ARTIFACTS)\T017.LOG > NUL
	BIN\3CSEED.EXE INIT >> $(ARTIFACTS)\T017.LOG

t018:
	@echo [t018] Testing mock CONFIGURE /PNP transition to disabled... >> TEST.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /PNP:DISABLED > $(ARTIFACTS)\T018.LOG
	FIND "PNP parameter accepted. Requested Plug and Play mode: disabled" $(ARTIFACTS)\T018.LOG > NUL
	FIND "Plug and Play configuration completed successfully." $(ARTIFACTS)\T018.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T018.LOG
	FIND "Plug and Play Capability = disabled" $(ARTIFACTS)\T018.LOG > NUL

t019:
	@echo [t019] Testing mock CONFIGURE /PNP transition back to enabled... >> TEST.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /PNP:ENABLED > $(ARTIFACTS)\T019.LOG
	FIND "PNP parameter accepted. Requested Plug and Play mode: enabled" $(ARTIFACTS)\T019.LOG > NUL
	FIND "Plug and Play configuration completed successfully." $(ARTIFACTS)\T019.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T019.LOG
	FIND "Plug and Play Capability = enabled" $(ARTIFACTS)\T019.LOG > NUL

t020:
	@echo [t020] Testing mock CONFIGURE /PNP rejects legacy numeric value... >> TEST.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /PNP:1 > $(ARTIFACTS)\T020.LOG
	FIND "Invalid /PNP parameter. Use ENABLED or DISABLED." $(ARTIFACTS)\T020.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T020.LOG
	FIND "Plug and Play Capability = enabled" $(ARTIFACTS)\T020.LOG > NUL

t021:
	@echo [t021] Testing mock CONFIGURE /PNP symbolic false value... >> TEST.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /PNP:FALSE > $(ARTIFACTS)\T021.LOG
	FIND "Invalid /PNP parameter. Use ENABLED or DISABLED." $(ARTIFACTS)\T021.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T021.LOG
	FIND "Plug and Play Capability = enabled" $(ARTIFACTS)\T021.LOG > NUL

t022:
	@echo [t022] Testing mock CONFIGURE /PNP arbitrary invalid input... >> TEST.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /PNP:OTHERINVALIDINPUT > $(ARTIFACTS)\T022.LOG
	FIND "Invalid /PNP parameter. Use ENABLED or DISABLED." $(ARTIFACTS)\T022.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T022.LOG
	FIND "Plug and Play Capability = enabled" $(ARTIFACTS)\T022.LOG > NUL

t023:
	@echo [t023] Testing mock CONFIGURE /MODEM transition to 1200... >> TEST.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:1200 > $(ARTIFACTS)\T023.LOG
	FIND "MODEM parameter accepted. Requested setting: 1200" $(ARTIFACTS)\T023.LOG > NUL
	FIND "Modem speed configuration completed successfully." $(ARTIFACTS)\T023.LOG > NUL

t024:
	@echo [t024] Testing mock CONFIGURE /MODEM unchanged transition at 1200... >> TEST.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:1200 /VERBOSE > $(ARTIFACTS)\T024.LOG
	FIND "MODEM parameter accepted. Requested setting: 1200" $(ARTIFACTS)\T024.LOG > NUL
	FIND "Modem speed setting is already configured to the requested value." $(ARTIFACTS)\T024.LOG > NUL

t025:
	@echo [t025] Testing mock CONFIGURE /MODEM transition to NONE... >> TEST.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:NONE > $(ARTIFACTS)\T025.LOG
	FIND "MODEM parameter accepted. Requested setting: none" $(ARTIFACTS)\T025.LOG > NUL
	FIND "Modem speed configuration completed successfully." $(ARTIFACTS)\T025.LOG > NUL

t026:
	@echo [t026] Testing mock CONFIGURE /MODEM invalid symbolic input... >> TEST.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:FALSE > $(ARTIFACTS)\T026.LOG
	FIND "Invalid /MODEM parameter. Use NONE, 1200, 2400, 9600, 19200, 38400, or 25-1600 in 25 increments." $(ARTIFACTS)\T026.LOG > NUL
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:NONE /VERBOSE >> $(ARTIFACTS)\T026.LOG
	FIND "Modem speed setting is already configured to the requested value." $(ARTIFACTS)\T026.LOG > NUL

t027:
	@echo [t027] Testing mock CONFIGURE /MODEM invalid out-of-range step value... >> TEST.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:26 > $(ARTIFACTS)\T027.LOG
	FIND "Invalid /MODEM parameter. Use NONE, 1200, 2400, 9600, 19200, 38400, or 25-1600 in 25 increments." $(ARTIFACTS)\T027.LOG > NUL
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:NONE /VERBOSE >> $(ARTIFACTS)\T027.LOG
	FIND "Modem speed setting is already configured to the requested value." $(ARTIFACTS)\T027.LOG > NUL

t077:
	@echo [t077] Testing /MODEM preserves EEPROM Link Beat Disable policy... >> TEST.LOG
	BIN\3CSEED.EXE NOLINKBEAT > $(ARTIFACTS)\T077.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:1200 /VERBOSE >> $(ARTIFACTS)\T077.LOG
	FIND "Current EEPROM word 0Dh: 4000" $(ARTIFACTS)\T077.LOG > NUL
	FIND "New EEPROM word 0Dh: 44B0" $(ARTIFACTS)\T077.LOG > NUL
	FIND "Modem speed configuration completed successfully." $(ARTIFACTS)\T077.LOG > NUL
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:1200 /VERBOSE >> $(ARTIFACTS)\T077.LOG
	FIND "Current EEPROM word 0Dh: 44B0" $(ARTIFACTS)\T077.LOG > NUL
	FIND "Modem speed setting is already configured to the requested value." $(ARTIFACTS)\T077.LOG > NUL
	BIN\3CSEED.EXE INIT >> $(ARTIFACTS)\T077.LOG

t028:
	@echo [t028] Testing mock CONFIGURE /FULLDUPLEX transition to enabled... >> TEST.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:ENABLED > $(ARTIFACTS)\T028.LOG
	FIND "FULLDUPLEX parameter accepted. Requested mode: enabled" $(ARTIFACTS)\T028.LOG > NUL
	FIND "Full duplex configuration completed successfully." $(ARTIFACTS)\T028.LOG > NUL

t029:
	@echo [t029] Testing mock CONFIGURE /FULLDUPLEX unchanged transition at enabled... >> TEST.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:ENABLED /VERBOSE > $(ARTIFACTS)\T029.LOG
	FIND "FULLDUPLEX parameter accepted. Requested mode: enabled" $(ARTIFACTS)\T029.LOG > NUL
	FIND "Full duplex mode is already configured to the requested value." $(ARTIFACTS)\T029.LOG > NUL

t030:
	@echo [t030] Testing mock CONFIGURE /FULLDUPLEX transition to disabled... >> TEST.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:DISABLED > $(ARTIFACTS)\T030.LOG
	FIND "FULLDUPLEX parameter accepted. Requested mode: disabled" $(ARTIFACTS)\T030.LOG > NUL
	FIND "Full duplex configuration completed successfully." $(ARTIFACTS)\T030.LOG > NUL

t031:
	@echo [t031] Testing mock CONFIGURE /FULLDUPLEX rejects legacy numeric value... >> TEST.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:1 > $(ARTIFACTS)\T031.LOG
	FIND "Invalid /FULLDUPLEX parameter. Use ENABLED or DISABLED." $(ARTIFACTS)\T031.LOG > NUL
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:DISABLED /VERBOSE >> $(ARTIFACTS)\T031.LOG
	FIND "Full duplex mode is already configured to the requested value." $(ARTIFACTS)\T031.LOG > NUL

t032:
	@echo [t032] Testing mock CONFIGURE /FULLDUPLEX invalid symbolic input... >> TEST.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:TRUE > $(ARTIFACTS)\T032.LOG
	FIND "Invalid /FULLDUPLEX parameter. Use ENABLED or DISABLED." $(ARTIFACTS)\T032.LOG > NUL
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:DISABLED /VERBOSE >> $(ARTIFACTS)\T032.LOG
	FIND "Full duplex mode is already configured to the requested value." $(ARTIFACTS)\T032.LOG > NUL

t033:
	@echo [t033] Testing PNP capability gate: NOPNP seed rejects /PNP:ENABLED... >> TEST.LOG
	BIN\3CSEED.EXE NOPNP > $(ARTIFACTS)\T033.LOG
	FIND "Seed file created (NOPNP)." $(ARTIFACTS)\T033.LOG > NUL
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /PNP:ENABLED >> $(ARTIFACTS)\T033.LOG
	FIND "This adapter does not support Plug and Play configuration." $(ARTIFACTS)\T033.LOG > NUL
	BIN\3CSEED.EXE INIT >> $(ARTIFACTS)\T033.LOG

t034:
	@echo [t034] Testing FULLDUPLEX capability gate: NOFD seed rejects /FULLDUPLEX:ENABLED... >> TEST.LOG
	BIN\3CSEED.EXE NOFD > $(ARTIFACTS)\T034.LOG
	FIND "Seed file created (NOFD)." $(ARTIFACTS)\T034.LOG > NUL
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:ENABLED >> $(ARTIFACTS)\T034.LOG
	FIND "This adapter does not support full duplex configuration." $(ARTIFACTS)\T034.LOG > NUL
	BIN\3CSEED.EXE INIT >> $(ARTIFACTS)\T034.LOG

t035:
	@echo [t035] Testing mock CONFIGURE /OPTIMIZE transition to OS/2... >> TEST.LOG
	BIN\3CSEED.EXE INIT > $(ARTIFACTS)\T035.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /OPTIMIZE:OS/2 /VERBOSE >> $(ARTIFACTS)\T035.LOG
	FIND "New EEPROM word 0Fh: OS/2" $(ARTIFACTS)\T035.LOG > NUL
	FIND "Configuration completed successfully." $(ARTIFACTS)\T035.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T035.LOG
	FIND "Optimization = OS/2" $(ARTIFACTS)\T035.LOG > NUL

t036:
	@echo [t036] Testing mock CONFIGURE /OPTIMIZE invalid symbolic input... >> TEST.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /OPTIMIZE:TRUE > $(ARTIFACTS)\T036.LOG
	FIND "Invalid /OPTIMIZE parameter. Use DOS, WINDOWS, OS/2, or SERVER." $(ARTIFACTS)\T036.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T036.LOG
	FIND "Optimization = OS/2" $(ARTIFACTS)\T036.LOG > NUL

t037:
	@echo [t037] Testing mock CONFIGURE /OPTIMIZE transition to SERVER... >> TEST.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /OPTIMIZE:SERVER > $(ARTIFACTS)\T037.LOG
	FIND "Configuration completed successfully." $(ARTIFACTS)\T037.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T037.LOG
	FIND "Optimization = Server" $(ARTIFACTS)\T037.LOG > NUL

t038:
	@echo [t038] Testing LIST Link Status: LINKUP seed reports connected... >> TEST.LOG
	BIN\3CSEED.EXE LINKUP > $(ARTIFACTS)\T038.LOG
	FIND "Seed file created (LINKUP)." $(ARTIFACTS)\T038.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T038.LOG
	FIND "Link Status = connected" $(ARTIFACTS)\T038.LOG > NUL
	BIN\3CSEED.EXE INIT >> $(ARTIFACTS)\T038.LOG

t039:
	@echo [t039] Testing LIST Link Status: LINKDOWN seed reports not connected... >> TEST.LOG
	BIN\3CSEED.EXE LINKDOWN > $(ARTIFACTS)\T039.LOG
	FIND "Seed file created (LINKDOWN)." $(ARTIFACTS)\T039.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T039.LOG
	FIND "Link Status = not connected" $(ARTIFACTS)\T039.LOG > NUL
	BIN\3CSEED.EXE INIT >> $(ARTIFACTS)\T039.LOG

t040:
	@echo [t040] Testing mock CONFIGURE /BADDRESS minimum valid address with /BSIZE:16... >> TEST.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:C0000 /BSIZE:16 > $(ARTIFACTS)\T040.LOG
	FIND "Configuration completed successfully." $(ARTIFACTS)\T040.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T040.LOG
	FIND "Boot ROM = 16K at C0000H" $(ARTIFACTS)\T040.LOG > NUL


t041:
	@echo [t041] Testing mock CONFIGURE /BADDRESS+/BSIZE enable together... >> TEST.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:C8000 /BSIZE:16 /VERBOSE > $(ARTIFACTS)\T041.LOG
	FIND "Configuration completed successfully." $(ARTIFACTS)\T041.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T041.LOG
	FIND "Boot ROM = 16K at C8000H" $(ARTIFACTS)\T041.LOG > NUL


t042:
	@echo [t042] Testing mock CONFIGURE /BADDRESS+/BSIZE reconfigure to a new pair... >> TEST.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:D0000 /BSIZE:32 > $(ARTIFACTS)\T042.LOG
	FIND "Configuration completed successfully." $(ARTIFACTS)\T042.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T042.LOG
	FIND "Boot ROM = 32K at D0000H" $(ARTIFACTS)\T042.LOG > NUL


t043:
	@echo [t043] Testing mock CONFIGURE /BSIZE:DISABLED disables Boot ROM... >> TEST.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /BSIZE:DISABLED > $(ARTIFACTS)\T043.LOG
	FIND "Configuration completed successfully." $(ARTIFACTS)\T043.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T043.LOG
	FIND "Boot ROM = disabled" $(ARTIFACTS)\T043.LOG > NUL


t044:
	@echo [t044] Testing mock CONFIGURE /BADDRESS out-of-range address... >> TEST.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:E0000 /BSIZE:16 > $(ARTIFACTS)\T044.LOG
	FIND "Invalid /BADDRESS parameter. Use a hex address C0000-DE000 in 2000h steps." $(ARTIFACTS)\T044.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T044.LOG
	FIND "Boot ROM = disabled" $(ARTIFACTS)\T044.LOG > NUL


t045:
	@echo [t045] Testing mock CONFIGURE /BADDRESS non-aligned address... >> TEST.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:C1000 /BSIZE:16 > $(ARTIFACTS)\T045.LOG
	FIND "Invalid /BADDRESS parameter. Use a hex address C0000-DE000 in 2000h steps." $(ARTIFACTS)\T045.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T045.LOG
	FIND "Boot ROM = disabled" $(ARTIFACTS)\T045.LOG > NUL


t046:
	@echo [t046] Testing mock CONFIGURE /BSIZE invalid value... >> TEST.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:C8000 /BSIZE:64 > $(ARTIFACTS)\T046.LOG
	FIND "Invalid /BSIZE parameter. Use 8, 16, 32, or DISABLED." $(ARTIFACTS)\T046.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T046.LOG
	FIND "Boot ROM = disabled" $(ARTIFACTS)\T046.LOG > NUL


t047:
	@echo [t047] Testing mock CONFIGURE /BSIZE alone (real size) is rejected (pairing rule)... >> TEST.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /BSIZE:16 > $(ARTIFACTS)\T047.LOG
	FIND "BADDRESS and /BSIZE must be specified together" $(ARTIFACTS)\T047.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T047.LOG
	FIND "Boot ROM = disabled" $(ARTIFACTS)\T047.LOG > NUL


t048:
	@echo [t048] Testing mock CONFIGURE /BADDRESS alone is rejected (pairing rule)... >> TEST.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:C8000 > $(ARTIFACTS)\T048.LOG
	FIND "BADDRESS and /BSIZE must be specified together" $(ARTIFACTS)\T048.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T048.LOG
	FIND "Boot ROM = disabled" $(ARTIFACTS)\T048.LOG > NUL


t049:
	@echo [t049] Testing mock CONFIGURE /BADDRESS combined with /BSIZE:DISABLED is ignored... >> TEST.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:C8000 /BSIZE:DISABLED > $(ARTIFACTS)\T049.LOG
	FIND "Configuration completed successfully." $(ARTIFACTS)\T049.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T049.LOG
	FIND "Boot ROM = disabled" $(ARTIFACTS)\T049.LOG > NUL


t050:
	@echo [t050] Testing Boot ROM capability gate: 3C509B-TPO rejects /BADDRESS+/BSIZE... >> TEST.LOG
	BIN\3CSEED.EXE 3C509B-TPO > $(ARTIFACTS)\T050.LOG
	FIND "Seed file created (3C509B-TPO)." $(ARTIFACTS)\T050.LOG > NUL
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:C8000 /BSIZE:16 >> $(ARTIFACTS)\T050.LOG
	FIND "This adapter does not support Boot ROM configuration." $(ARTIFACTS)\T050.LOG > NUL
	BIN\3CSEED.EXE INIT >> $(ARTIFACTS)\T050.LOG


t051:
	@echo [t051] Testing CONFIGURE /TR:TP on 3C509B-TP (should succeed, TP only card)... >> TEST.LOG
	BIN\3CSEED.EXE INIT > $(ARTIFACTS)\T051.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:TP >> $(ARTIFACTS)\T051.LOG
	FIND "TR parameter accepted. Requested transceiver: TP" $(ARTIFACTS)\T051.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T051.LOG
	FIND "Transceiver = on-board TP" $(ARTIFACTS)\T051.LOG > NUL


t052:
	@echo [t052] Testing CONFIGURE /TR:AUI on 3C509B-TP is rejected (TP only card)... >> TEST.LOG
	BIN\3CSEED.EXE INIT > $(ARTIFACTS)\T052.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:AUI >> $(ARTIFACTS)\T052.LOG
	FIND "This adapter does not support the requested transceiver type." $(ARTIFACTS)\T052.LOG > NUL


t053:
	@echo [t053] Testing CONFIGURE /TR:COAX on 3C509B-TP is rejected (TP only card)... >> TEST.LOG
	BIN\3CSEED.EXE INIT > $(ARTIFACTS)\T053.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:COAX >> $(ARTIFACTS)\T053.LOG
	FIND "This adapter does not support the requested transceiver type." $(ARTIFACTS)\T053.LOG > NUL


t054:
	@echo [t054] Testing CONFIGURE /TR:AUTO on 3C509B-TP is rejected (TP only card)... >> TEST.LOG
	BIN\3CSEED.EXE INIT > $(ARTIFACTS)\T054.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:AUTO >> $(ARTIFACTS)\T054.LOG
	FIND "This adapter does not support the requested transceiver type." $(ARTIFACTS)\T054.LOG > NUL


t055:
	@echo [t055] Testing CONFIGURE /TR:AUI on 3C509B-Combo (should succeed)... >> TEST.LOG
	BIN\3CSEED.EXE 3C509B-COMBO > $(ARTIFACTS)\T055.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:AUI >> $(ARTIFACTS)\T055.LOG
	FIND "TR parameter accepted. Requested transceiver: AUI" $(ARTIFACTS)\T055.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T055.LOG
	FIND "Transceiver = external" $(ARTIFACTS)\T055.LOG > NUL
	BIN\3CSEED.EXE INIT >> $(ARTIFACTS)\T055.LOG


t056:
	@echo [t056] Testing CONFIGURE /TR:AUTO on 3C509B-Combo (should succeed)... >> TEST.LOG
	BIN\3CSEED.EXE 3C509B-COMBO > $(ARTIFACTS)\T056.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:AUTO >> $(ARTIFACTS)\T056.LOG
	FIND "TR parameter accepted. Requested transceiver: AUTO" $(ARTIFACTS)\T056.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T056.LOG
	FIND "Transceiver = auto select" $(ARTIFACTS)\T056.LOG > NUL
	BIN\3CSEED.EXE INIT >> $(ARTIFACTS)\T056.LOG


t057:
	@echo [t057] Testing CONFIGURE /TR:COAX on 3C509B-Combo is rejected (no coax port)... >> TEST.LOG
	BIN\3CSEED.EXE 3C509B-COMBO > $(ARTIFACTS)\T057.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:COAX >> $(ARTIFACTS)\T057.LOG
	FIND "This adapter does not support the requested transceiver type." $(ARTIFACTS)\T057.LOG > NUL
	BIN\3CSEED.EXE INIT >> $(ARTIFACTS)\T057.LOG


t058:
	@echo [t058] Testing CONFIGURE /TR:COAX on 3C509B-TPC (should succeed)... >> TEST.LOG
	BIN\3CSEED.EXE 3C509B-TPC > $(ARTIFACTS)\T058.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:COAX >> $(ARTIFACTS)\T058.LOG
	FIND "TR parameter accepted. Requested transceiver: COAX" $(ARTIFACTS)\T058.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T058.LOG
	FIND "Transceiver = on-board coax" $(ARTIFACTS)\T058.LOG > NUL
	BIN\3CSEED.EXE INIT >> $(ARTIFACTS)\T058.LOG


t059:
	@echo [t059] Testing CONFIGURE /TR:AUTO on 3C509B-TPC is rejected (no auto-select)... >> TEST.LOG
	BIN\3CSEED.EXE 3C509B-TPC > $(ARTIFACTS)\T059.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:AUTO >> $(ARTIFACTS)\T059.LOG
	FIND "This adapter does not support the requested transceiver type." $(ARTIFACTS)\T059.LOG > NUL
	BIN\3CSEED.EXE INIT >> $(ARTIFACTS)\T059.LOG


t060:
	@echo [t060] Testing CONFIGURE /TR:AUTO on 3C509B-TPO is rejected (TPO excluded from auto-select)... >> TEST.LOG
	BIN\3CSEED.EXE 3C509B-TPO > $(ARTIFACTS)\T060.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:AUTO >> $(ARTIFACTS)\T060.LOG
	FIND "This adapter does not support the requested transceiver type." $(ARTIFACTS)\T060.LOG > NUL
	BIN\3CSEED.EXE INIT >> $(ARTIFACTS)\T060.LOG


t061:
	@echo [t061] Testing /XCVR alias: behaves identically to /TR:TP... >> TEST.LOG
	BIN\3CSEED.EXE INIT > $(ARTIFACTS)\T061.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /XCVR:TP >> $(ARTIFACTS)\T061.LOG
	FIND "TR parameter accepted. Requested transceiver: TP" $(ARTIFACTS)\T061.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T061.LOG
	FIND "Transceiver = on-board TP" $(ARTIFACTS)\T061.LOG > NUL

t062:
	@echo [t062] Testing HELP command prints CLI help screen... >> TEST.LOG
	$(BINAPP) HELP > $(ARTIFACTS)\T062.LOG
	FIND "Usage: 3CCFGCLI [COMMAND]" $(ARTIFACTS)\T062.LOG > NUL
	FIND "    /VERBOSE                       Show verbose transaction details." $(ARTIFACTS)\T062.LOG > NUL

t063:
	@echo [t063] Testing CONFIGURE parser accepts '-' switch introducers... >> TEST.LOG
	BIN\3CSEED.EXE INIT > $(ARTIFACTS)\T063.LOG
	$(BINAPP) CONFIGURE -ADAPTERNUM:1 -INT:5 >> $(ARTIFACTS)\T063.LOG
	FIND "INT parameter accepted. Requested IRQ: 5" $(ARTIFACTS)\T063.LOG > NUL
	FIND "IRQ configuration completed successfully." $(ARTIFACTS)\T063.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T063.LOG
	FIND "IRQ = 5" $(ARTIFACTS)\T063.LOG > NUL

t064:
	@echo [t064] Testing CONFIGURE parser accepts '=' value separators... >> TEST.LOG
	BIN\3CSEED.EXE INIT > $(ARTIFACTS)\T064.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM=1 /INT=5 >> $(ARTIFACTS)\T064.LOG
	FIND "INT parameter accepted. Requested IRQ: 5" $(ARTIFACTS)\T064.LOG > NUL
	FIND "IRQ configuration completed successfully." $(ARTIFACTS)\T064.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T064.LOG
	FIND "IRQ = 5" $(ARTIFACTS)\T064.LOG > NUL

t065:
	@echo [t065] Testing CONFIGURE with no property is rejected... >> TEST.LOG
	BIN\3CSEED.EXE INIT > $(ARTIFACTS)\T065.LOG
	$(BINAPP) CONFIGURE >> $(ARTIFACTS)\T065.LOG
	FIND "No CONFIGURE property was specified." $(ARTIFACTS)\T065.LOG > NUL

t066:
	@echo [t066] Testing combined CONFIGURE /IOBASE+/INT transaction... >> TEST.LOG
	BIN\3CSEED.EXE INIT > $(ARTIFACTS)\T066.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /IOBASE:0280 /INT:5 /VERBOSE >> $(ARTIFACTS)\T066.LOG
	FIND "IOBASE parameter accepted. Requested I/O base: 0280" $(ARTIFACTS)\T066.LOG > NUL
	FIND "INT parameter accepted. Requested IRQ: 5" $(ARTIFACTS)\T066.LOG > NUL
	FIND "I/O base and IRQ configuration completed successfully." $(ARTIFACTS)\T066.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T066.LOG
	FIND "I/O = 0280" $(ARTIFACTS)\T066.LOG > NUL
	FIND "IRQ = 5" $(ARTIFACTS)\T066.LOG > NUL
	BIN\3CSEED.EXE INIT >> $(ARTIFACTS)\T066.LOG

t067:
	@echo [t067] Testing combined CONFIGURE /MODEM+/FULLDUPLEX transaction... >> TEST.LOG
	BIN\3CSEED.EXE INIT > $(ARTIFACTS)\T067.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:1200 /FULLDUPLEX:ENABLED /VERBOSE >> $(ARTIFACTS)\T067.LOG
	FIND "MODEM parameter accepted. Requested setting: 1200" $(ARTIFACTS)\T067.LOG > NUL
	FIND "FULLDUPLEX parameter accepted. Requested mode: enabled" $(ARTIFACTS)\T067.LOG > NUL
	FIND "New EEPROM word 0Dh: " $(ARTIFACTS)\T067.LOG > NUL
	FIND "Configuration completed successfully." $(ARTIFACTS)\T067.LOG > NUL
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:1200 /VERBOSE >> $(ARTIFACTS)\T067.LOG
	FIND "Modem speed setting is already configured to the requested value." $(ARTIFACTS)\T067.LOG > NUL
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:ENABLED /VERBOSE >> $(ARTIFACTS)\T067.LOG
	FIND "Full duplex mode is already configured to the requested value." $(ARTIFACTS)\T067.LOG > NUL
	BIN\3CSEED.EXE INIT >> $(ARTIFACTS)\T067.LOG

t068:
	@echo [t068] Testing combined CONFIGURE /IOBASE+/TR on 3C509B-Combo... >> TEST.LOG
	BIN\3CSEED.EXE 3C509B-COMBO > $(ARTIFACTS)\T068.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /IOBASE:0280 /TR:AUI /VERBOSE >> $(ARTIFACTS)\T068.LOG
	FIND "IOBASE parameter accepted. Requested I/O base: 0280" $(ARTIFACTS)\T068.LOG > NUL
	FIND "TR parameter accepted. Requested transceiver: AUI" $(ARTIFACTS)\T068.LOG > NUL
	FIND "Configuration completed successfully." $(ARTIFACTS)\T068.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T068.LOG
	FIND "I/O = 0280" $(ARTIFACTS)\T068.LOG > NUL
	FIND "Transceiver = external" $(ARTIFACTS)\T068.LOG > NUL
	BIN\3CSEED.EXE INIT >> $(ARTIFACTS)\T068.LOG

t069:
	@echo [t069] Testing combined CONFIGURE /IOBASE+/BADDRESS+/BSIZE transaction... >> TEST.LOG
	BIN\3CSEED.EXE INIT > $(ARTIFACTS)\T069.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /IOBASE:0280 /BADDRESS:C8000 /BSIZE:16 /VERBOSE >> $(ARTIFACTS)\T069.LOG
	FIND "IOBASE parameter accepted. Requested I/O base: 0280" $(ARTIFACTS)\T069.LOG > NUL
	FIND "Configuration completed successfully." $(ARTIFACTS)\T069.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T069.LOG
	FIND "I/O = 0280" $(ARTIFACTS)\T069.LOG > NUL
	FIND "Boot ROM = 16K at C8000H" $(ARTIFACTS)\T069.LOG > NUL
	BIN\3CSEED.EXE INIT >> $(ARTIFACTS)\T069.LOG

t070:
	@echo [t070] Testing combined CONFIGURE /OPTIMIZE+/MODEM transaction... >> TEST.LOG
	BIN\3CSEED.EXE INIT > $(ARTIFACTS)\T070.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /OPTIMIZE:SERVER /MODEM:1200 /VERBOSE >> $(ARTIFACTS)\T070.LOG
	FIND "MODEM parameter accepted. Requested setting: 1200" $(ARTIFACTS)\T070.LOG > NUL
	FIND "New EEPROM word 0Fh: Server" $(ARTIFACTS)\T070.LOG > NUL
	FIND "Configuration completed successfully." $(ARTIFACTS)\T070.LOG > NUL
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /OPTIMIZE:SERVER /VERBOSE >> $(ARTIFACTS)\T070.LOG
	FIND "No hardware changes required." $(ARTIFACTS)\T070.LOG > NUL
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:1200 /VERBOSE >> $(ARTIFACTS)\T070.LOG
	FIND "Modem speed setting is already configured to the requested value." $(ARTIFACTS)\T070.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T070.LOG
	FIND "Optimization = Server" $(ARTIFACTS)\T070.LOG > NUL
	BIN\3CSEED.EXE INIT >> $(ARTIFACTS)\T070.LOG

t071:
	@echo [t071] Testing combined CONFIGURE /TR:AUTO+/BADDRESS+/BSIZE on 3C509B-Combo... >> TEST.LOG
	BIN\3CSEED.EXE 3C509B-COMBO > $(ARTIFACTS)\T071.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:AUTO /BADDRESS:C8000 /BSIZE:16 /VERBOSE >> $(ARTIFACTS)\T071.LOG
	FIND "TR parameter accepted. Requested transceiver: AUTO" $(ARTIFACTS)\T071.LOG > NUL
	FIND "Configuration completed successfully." $(ARTIFACTS)\T071.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T071.LOG
	FIND "Transceiver = auto select" $(ARTIFACTS)\T071.LOG > NUL
	FIND "Boot ROM = 16K at C8000H" $(ARTIFACTS)\T071.LOG > NUL
	BIN\3CSEED.EXE INIT >> $(ARTIFACTS)\T071.LOG

t072:
	@echo [t072] Testing multi-NIC default ADD allocation yields distinct bases... >> TEST.LOG
	BIN\3CSEED.EXE CLEAR > $(ARTIFACTS)\T072.LOG
	BIN\3CSEED.EXE ADD 3C509B-TP >> $(ARTIFACTS)\T072.LOG
	BIN\3CSEED.EXE ADD 3C509B-COMBO >> $(ARTIFACTS)\T072.LOG
	$(BINAPP) LIST >> $(ARTIFACTS)\T072.LOG
	FIND "I/O = 0300, IRQ = 10" $(ARTIFACTS)\T072.LOG > NUL
	FIND "I/O = 0310, IRQ = 10" $(ARTIFACTS)\T072.LOG > NUL
	BIN\3CSEED.EXE CLEAR >> $(ARTIFACTS)\T072.LOG

t073:
	@echo [t073] Testing multi-NIC CONFIGURE requires /ADAPTERNUM... >> TEST.LOG
	BIN\3CSEED.EXE CLEAR > $(ARTIFACTS)\T073.LOG
	BIN\3CSEED.EXE ADD 3C509B-TP 0300 10 >> $(ARTIFACTS)\T073.LOG
	BIN\3CSEED.EXE ADD 3C509B-COMBO 0310 5 >> $(ARTIFACTS)\T073.LOG
	$(BINAPP) CONFIGURE /INT:7 >> $(ARTIFACTS)\T073.LOG
	FIND "ADAPTERNUM is required when more than one adapter is installed." $(ARTIFACTS)\T073.LOG > NUL
	BIN\3CSEED.EXE CLEAR >> $(ARTIFACTS)\T073.LOG

t074:
	@echo [t074] Testing multi-NIC adapter selection changes only the targeted NIC... >> TEST.LOG
	BIN\3CSEED.EXE CLEAR > $(ARTIFACTS)\T074.LOG
	BIN\3CSEED.EXE ADD 3C509B-TP 0300 10 >> $(ARTIFACTS)\T074.LOG
	BIN\3CSEED.EXE ADD 3C509B-COMBO 0310 5 >> $(ARTIFACTS)\T074.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:2 /INT:7 >> $(ARTIFACTS)\T074.LOG
	FIND "IRQ configuration completed successfully." $(ARTIFACTS)\T074.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T074.LOG
	FIND "I/O = 0300, IRQ = 10" $(ARTIFACTS)\T074.LOG > NUL
	FIND "I/O = 0310, IRQ = 7" $(ARTIFACTS)\T074.LOG > NUL
	BIN\3CSEED.EXE CLEAR >> $(ARTIFACTS)\T074.LOG

t075:
	@echo [t075] Testing multi-NIC /IOBASE conflict detection blocks duplicate base... >> TEST.LOG
	BIN\3CSEED.EXE CLEAR > $(ARTIFACTS)\T075.LOG
	BIN\3CSEED.EXE ADD 3C509B-TP 0300 10 >> $(ARTIFACTS)\T075.LOG
	BIN\3CSEED.EXE ADD 3C509B-COMBO 0310 5 >> $(ARTIFACTS)\T075.LOG
	$(BINAPP) CONFIGURE /ADAPTERNUM:2 /IOBASE:0300 >> $(ARTIFACTS)\T075.LOG
	FIND "Requested I/O base is already used by another discovered adapter." $(ARTIFACTS)\T075.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T075.LOG
	FIND "I/O = 0300, IRQ = 10" $(ARTIFACTS)\T075.LOG > NUL
	FIND "I/O = 0310, IRQ = 5" $(ARTIFACTS)\T075.LOG > NUL
	BIN\3CSEED.EXE CLEAR >> $(ARTIFACTS)\T075.LOG

t076:
	@echo [t076] Testing duplicate-base multi-NIC seed can migrate one adapter to a new I/O base... >> TEST.LOG
	BIN\3CSEED.EXE CLEAR > $(ARTIFACTS)\T076.LOG
	BIN\3CSEED.EXE ADD 3C509B-TP 0300 10 >> $(ARTIFACTS)\T076.LOG
	BIN\3CSEED.EXE ADD 3C509B-COMBO 0300 5 >> $(ARTIFACTS)\T076.LOG
	$(BINAPP) LIST >> $(ARTIFACTS)\T076.LOG
	FIND "I/O = 0300, IRQ = 10" $(ARTIFACTS)\T076.LOG > NUL
	FIND "I/O = 0300, IRQ = 5" $(ARTIFACTS)\T076.LOG > NUL
	$(BINAPP) CONFIGURE /ADAPTERNUM:2 /IOBASE:0310 >> $(ARTIFACTS)\T076.LOG
	FIND "I/O base configuration completed successfully." $(ARTIFACTS)\T076.LOG > NUL
	$(BINAPP) LIST >> $(ARTIFACTS)\T076.LOG
	FIND "I/O = 0300, IRQ = 10" $(ARTIFACTS)\T076.LOG > NUL
	FIND "I/O = 0310, IRQ = 5" $(ARTIFACTS)\T076.LOG > NUL
	BIN\3CSEED.EXE CLEAR >> $(ARTIFACTS)\T076.LOG

t078:
	@echo [t078] Testing SAVECONFIG exports the INIT restore command... >> TEST.LOG
	BIN\3CSEED.EXE INIT > $(ARTIFACTS)\T078.LOG
	$(BINAPP) SAVECONFIG $(ARTIFACTS)\RESTORE.BAT >> $(ARTIFACTS)\T078.LOG
	FIND "Configuration restore batch file created: $(ARTIFACTS)\RESTORE.BAT" $(ARTIFACTS)\T078.LOG > NUL
	FIND "3CCFGCLI.EXE CONFIGURE" $(ARTIFACTS)\RESTORE.BAT > NUL

t079:
	@echo [t079] Testing SAVECONFIG rejects a missing output filename... >> TEST.LOG
	BIN\3CSEED.EXE INIT > $(ARTIFACTS)\T079.LOG
	$(BINAPP) SAVECONFIG >> $(ARTIFACTS)\T079.LOG
	FIND "SAVECONFIG requires an output filename." $(ARTIFACTS)\T079.LOG > NUL

t080:
	@echo [t080] Testing SAVECONFIG exports one restore line per multi-NIC adapter... >> TEST.LOG
	BIN\3CSEED.EXE CLEAR > $(ARTIFACTS)\T080.LOG
	BIN\3CSEED.EXE ADD 3C509B-TP 0300 10 >> $(ARTIFACTS)\T080.LOG
	BIN\3CSEED.EXE ADD 3C509B-COMBO 0310 5 >> $(ARTIFACTS)\T080.LOG
	$(BINAPP) SAVECONFIG $(ARTIFACTS)\RESTORE.BAT >> $(ARTIFACTS)\T080.LOG
	FIND "Configuration restore batch file created: $(ARTIFACTS)\RESTORE.BAT" $(ARTIFACTS)\T080.LOG > NUL
	FIND "ADAPTERNUM:1 /INT:10" $(ARTIFACTS)\RESTORE.BAT > NUL
	FIND "ADAPTERNUM:2 /INT:5" $(ARTIFACTS)\RESTORE.BAT > NUL

t081:
	@echo [t081] Testing SAVECONFIG /EXECFILE overrides the embedded program name... >> TEST.LOG
	$(BINAPP) SAVECONFIG $(ARTIFACTS)\RESTORE.BAT /EXECFILE:%1 >> $(ARTIFACTS)\T081.LOG
	FIND "Configuration restore batch file created: $(ARTIFACTS)\RESTORE.BAT" $(ARTIFACTS)\T081.LOG > NUL
	FIND "%1 CONFIGURE" $(ARTIFACTS)\RESTORE.BAT > NUL
