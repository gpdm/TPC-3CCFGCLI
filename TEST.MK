# Borland MAKE test orchestration for 3CCFG project
# Usage:
#   MAKE -f TEST.MK test
#   MAKE -f TEST.MK smoke
#   MAKE -f TEST.MK test-build
#   MAKE -f TEST.MK clean-test

MAKEEXE = \TASM\BIN\MAKE
ARTIFACTS = ARTIFACT
BINAPP = BIN\3CHWMOCK.EXE
SEEDAPP = BIN\3CSEED.EXE

# Aliases
all: smoke
test: smoke

# Run against HW Mock (default)
mock:
   $(MAKEEXE) -f TEST.MK BINAPP=BIN\3CHWMOCK.EXE smoke

# Run against real hardware
real:
   $(MAKEEXE) -f TEST.MK BINAPP=BIN\3CCFGCLI.EXE smoke

test-build: prep build smoke-core
   @echo Build and Smoke Test: run completed >> TEST.LOG
   @echo Build and Smoke Test: run completed

smoke: prep smoke-core
   @echo Smoke test: run completed >> TEST.LOG
   @echo Smoke test: run completed

smoke-core: LISTING IRQ_CHANGE DEFAULT_NIC_SELECTION IOBASE_CHANGE PNP_CHANGE MODEM_CHANGE FD_CHANGE CAPABILITY_GATES OPTIMIZE_CHANGE LINK_STATUS BOOTROM_CHANGE XCVR_CHANGE CLI_PARSER COMBINED_TRANSACTIONS MULTI_NIC SAVECONFIG_TEST VERIFICATION_CONTROL_FLOW cleanup

prep:
   @if not exist $(ARTIFACTS) mkdir $(ARTIFACTS)
   @if exist TEST.LOG del TEST.LOG
   @if exist $(ARTIFACTS)\*.LOG del $(ARTIFACTS)\*.LOG

build:
   @echo Building all targets via MAKEFILE... >> TEST.LOG
   $(MAKEEXE) -f MAKEFILE all >> TEST.LOG

cleanup:
   @echo Cleaning seed file... >> TEST.LOG
   $(SEEDAPP) CLEAR >> TEST.LOG
   @echo Smoke test complete. >> TEST.LOG

clean-test:
   @if exist TEST.LOG del TEST.LOG
   @if exist $(ARTIFACTS)\*.LOG del $(ARTIFACTS)\*.LOG
   @if exist $(ARTIFACTS)\RESTORE.BAT del $(ARTIFACTS)\RESTORE.BAT

# Symbolic Test Groups
# ####################

# Base: 0100
LISTING: t0100 t0101 t0102

# Base: 0200
IRQ_CHANGE: t0200 t0201 t0202 t0203 t0204

# Base: 0300
DEFAULT_NIC_SELECTION: t0300 t0301 t0302

# Base: 0400
IOBASE_CHANGE: t0400 t0401 t0402 t0403 t0404 t0405 t0406 t0407 t0408 t0409

# Base: 0500
PNP_CHANGE: t0500 t0501 t0502 t0503 t0504 t0505

# Base: 0600
MODEM_CHANGE: t0600 t0601 t0602 t0603 t0604 t0605 t0606 t0607 t0608 t0609 t0610

# Base: 0700
FD_CHANGE: t0700 t0701 t0702 t0703 t0704 t0705 t0706 t0707 t0708 t0709 t0710 t0711 t0712 t0713

# Base: 0800
CAPABILITY_GATES: t0800 t0801 t0802 t0803

# Base: 0900
OPTIMIZE_CHANGE: t0900 t0901 t0902 t0903 t0904

# Base: 1000
LINK_STATUS: t1000 t1001 t1002

# Base: 1100
BOOTROM_CHANGE: t1100 t1101 t1102 t1103 t1104 t1105 t1106 t1107 t1108 t1109 t1110 t1111

# Base: 1200
XCVR_CHANGE: t1200 t1201 t1202 t1203 t1204 t1205 t1206 t1207 t1208 t1209 t1210 t1211 t1212 t1213

# Base: 1300
CLI_PARSER: t1300 t1301 t1302 t1303 t1304 t1305 t1306 t1307 t1308 t1309 t1310

# Base: 1400
COMBINED_TRANSACTIONS: t1400 t1401 t1402 t1403 t1404 t1405 t1406 t1407

# Base: 1500
MULTI_NIC: t1500 t1501 t1502 t1503 t1504 t1505

# Base: 1600
SAVECONFIG_TEST: t1600 t1601 t1602 t1603 t1604 t1605 t1606 t1607 t1608 t1609 t1610 t1611 t1612 t1613 t1614 t1615 t1616 t1617 t1618 t1619 t1620 t1621 t1622

# Base: 1700
VERIFICATION_CONTROL_FLOW: t1700 t1701 t1702 t1703 t1704 t1705 t1706 t1707 t1708 t1709 t1710 t1711 t1712 t1713 t1714



# Test Case Definitions
# #####################

t0100:
   @echo [t01xx] LISTING: Verify general card listing behaviour ... >> TEST.LOG

t0101:
   @echo [t0101] Clearing seed and checking no-card case... >> TEST.LOG
   $(SEEDAPP) CLEAR >> TEST.LOG
   $(BINAPP) LIST > $(ARTIFACTS)\T0101.LOG
   FIND "No EtherLink III NICs are installed in this computer." $(ARTIFACTS)\T0101.LOG > NUL

t0102:
   @echo [t0102] Seeding INIT profile and checking card listing... >> TEST.LOG
   $(SEEDAPP) INIT >> TEST.LOG
   $(BINAPP) LIST > $(ARTIFACTS)\T0102.LOG
   FIND "NIC                            NIC" $(ARTIFACTS)\T0102.LOG > NUL
   FIND "Number                       Description" $(ARTIFACTS)\T0102.LOG > NUL
   FIND "Connectors = TP" $(ARTIFACTS)\T0102.LOG > NUL
   FIND "Full Duplex Capability = yes" $(ARTIFACTS)\T0102.LOG > NUL
   FIND "Plug and Play Capability = yes" $(ARTIFACTS)\T0102.LOG > NUL
   FIND "Plug and Play = enabled" $(ARTIFACTS)\T0102.LOG > NUL

t0200:
   @echo [t02xx] IRQ_CHANGE: Verify IRQ change behaviour ... >> TEST.LOG

t0201:
   @echo [t0201] Testing mock CONFIGURE /INT invalid out-of-range value... >> TEST.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /INT:21 > $(ARTIFACTS)\T0201.LOG
   FIND "Invalid /INT parameter." $(ARTIFACTS)\T0201.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0201.LOG
   FIND "IRQ = 10" $(ARTIFACTS)\T0201.LOG > NUL

t0202:
   @echo [t0202] Testing mock CONFIGURE /INT invalid input... >> TEST.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /INT:BADVALUE > $(ARTIFACTS)\T0202.LOG
   FIND "Invalid /INT parameter." $(ARTIFACTS)\T0202.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0202.LOG
   FIND "IRQ = 10" $(ARTIFACTS)\T0202.LOG > NUL

t0203:
   @echo [t0203] Testing mock CONFIGURE /INT transition to 5... >> TEST.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /INT:5 > $(ARTIFACTS)\T0203.LOG
   FIND "INT parameter accepted. Requested IRQ: 5" $(ARTIFACTS)\T0203.LOG > NUL
   FIND "IRQ configuration completed successfully." $(ARTIFACTS)\T0203.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0203.LOG
   FIND "IRQ = 5" $(ARTIFACTS)\T0203.LOG > NUL

t0204:
   @echo [t0204] Testing mock CONFIGURE /INT transition back to 9... >> TEST.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /INT:9 > $(ARTIFACTS)\T0204.LOG
   FIND "INT parameter accepted. Requested IRQ: 9" $(ARTIFACTS)\T0204.LOG > NUL
   FIND "IRQ configuration completed successfully." $(ARTIFACTS)\T0204.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0204.LOG
   FIND "IRQ = 9" $(ARTIFACTS)\T0204.LOG > NUL

t0300:
   @echo [t03xx] DEFAULT_NIC_SELECTION: Verify default NIC selection behaviour ... >> TEST.LOG

t0301:
   @echo [t0301] Testing default NIC selection CONFIGURE /INT transition to 5... >> TEST.LOG
   $(BINAPP) CONFIGURE /INT:5 > $(ARTIFACTS)\T0301.LOG
   FIND "INT parameter accepted. Requested IRQ: 5" $(ARTIFACTS)\T0301.LOG > NUL
   FIND "IRQ configuration completed successfully." $(ARTIFACTS)\T0301.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0301.LOG
   FIND "IRQ = 5" $(ARTIFACTS)\T0301.LOG > NUL

t0302:
   @echo [t0302] Testing default NIC selection CONFIGURE /INT transition back to 9... >> TEST.LOG
   $(BINAPP) CONFIGURE /INT:9 > $(ARTIFACTS)\T0302.LOG
   FIND "INT parameter accepted. Requested IRQ: 9" $(ARTIFACTS)\T0302.LOG > NUL
   FIND "IRQ configuration completed successfully." $(ARTIFACTS)\T0302.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0302.LOG
   FIND "IRQ = 9" $(ARTIFACTS)\T0302.LOG > NUL

t0400:
   @echo [t04xx] IOBASE_CHANGE: Verify IO base change behaviour ... >> TEST.LOG

t0401:
   @echo [t0401] Testing mock CONFIGURE /IOBASE invalid out-of-range high value... >> TEST.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /IOBASE:03F0 > $(ARTIFACTS)\T0401.LOG
   FIND "Invalid /IOBASE parameter. Use hexadecimal 0200 through 03E0 in 10h increments." $(ARTIFACTS)\T0401.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0401.LOG
   FIND "IOBASE = 0300" $(ARTIFACTS)\T0401.LOG > NUL

t0402:
   @echo [t0402] Testing mock CONFIGURE /IOBASE invalid out-of-range low value... >> TEST.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /IOBASE:01F0 > $(ARTIFACTS)\T0402.LOG
   FIND "Invalid /IOBASE parameter. Use hexadecimal 0200 through 03E0 in 10h increments." $(ARTIFACTS)\T0402.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0402.LOG
   FIND "IOBASE = 0300" $(ARTIFACTS)\T0402.LOG > NUL

t0403:
   @echo [t0403] Testing mock CONFIGURE /IOBASE arbitrary invalid input... >> TEST.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /IOBASE:BADVALUE > $(ARTIFACTS)\T0403.LOG
   FIND "Invalid /IOBASE parameter. Use hexadecimal 0200 through 03E0 in 10h increments." $(ARTIFACTS)\T0403.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0403.LOG
   FIND "IOBASE = 0300" $(ARTIFACTS)\T0403.LOG > NUL

t0404:
   @echo [t0404] Testing mock CONFIGURE /IOBASE transition to 0280 (long notation)... >> TEST.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /IOBASE:0280 > $(ARTIFACTS)\T0404.LOG
   FIND "IOBASE parameter accepted. Requested IOBASE: 0280" $(ARTIFACTS)\T0404.LOG > NUL
   FIND "IOBASE configuration completed successfully." $(ARTIFACTS)\T0404.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0404.LOG
   FIND "IOBASE = 0280" $(ARTIFACTS)\T0404.LOG > NUL

t0405:
   @echo [t0405] Testing mock CONFIGURE /IOBASE transition back to 0300 (long notation)... >> TEST.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /IOBASE:0300 > $(ARTIFACTS)\T0405.LOG
   FIND "IOBASE parameter accepted. Requested IOBASE: 0300" $(ARTIFACTS)\T0405.LOG > NUL
   FIND "IOBASE configuration completed successfully." $(ARTIFACTS)\T0405.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0405.LOG
   FIND "IOBASE = 0300" $(ARTIFACTS)\T0405.LOG > NUL

t0406:
   @echo [t0406] Testing mock CONFIGURE /IOBASE transition to 280 (short notation)... >> TEST.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /IOBASE:280 > $(ARTIFACTS)\T0406.LOG
   FIND "IOBASE parameter accepted. Requested IOBASE: 0280" $(ARTIFACTS)\T0406.LOG > NUL
   FIND "IOBASE configuration completed successfully." $(ARTIFACTS)\T0406.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0406.LOG
   FIND "IOBASE = 0280" $(ARTIFACTS)\T0406.LOG > NUL

t0407:
   @echo [t0407] Testing mock CONFIGURE /IOBASE transition back to 300 (short notation)... >> TEST.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /IOBASE:300 > $(ARTIFACTS)\T0407.LOG
   FIND "IOBASE parameter accepted. Requested IOBASE: 0300" $(ARTIFACTS)\T0407.LOG > NUL
   FIND "IOBASE configuration completed successfully." $(ARTIFACTS)\T0407.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0407.LOG
   FIND "IOBASE = 0300" $(ARTIFACTS)\T0407.LOG > NUL

t0408:
   @echo [t0408] Testing CONFIGURE /IOBASE minimum valid address 0200... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T0408.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /IOBASE:0200 >> $(ARTIFACTS)\T0408.LOG
   FIND "IOBASE parameter accepted. Requested IOBASE: 0200" $(ARTIFACTS)\T0408.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0408.LOG
   FIND "IOBASE = 0200" $(ARTIFACTS)\T0408.LOG > NUL
   ${SEEDAPP} INIT >> $(ARTIFACTS)\T0408.LOG

t0409:
   @echo [t0409] Testing CONFIGURE /IOBASE maximum valid address 03E0... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T0409.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /IOBASE:03E0 >> $(ARTIFACTS)\T0409.LOG
   FIND "IOBASE parameter accepted. Requested IOBASE: 03E0" $(ARTIFACTS)\T0409.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0409.LOG
   FIND "IOBASE = 03E0" $(ARTIFACTS)\T0409.LOG > NUL
   ${SEEDAPP} INIT >> $(ARTIFACTS)\T0409.LOG

t0500:
   @echo [t05xx] PNP_CHANGE: Verify PNP property change behaviour ... >> TEST.LOG

t0501:
   @echo [t0501] Testing mock CONFIGURE /PNP transition to disabled... >> TEST.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /PNP:DISABLED /VERBOSE > $(ARTIFACTS)\T0501.LOG
   FIND "PNP parameter accepted. Requested Plug and Play mode: disabled" $(ARTIFACTS)\T0501.LOG > NUL
   FIND "Plug and Play configuration word written." $(ARTIFACTS)\T0501.LOG > NUL
   FIND "Updating EEPROM checksum..." $(ARTIFACTS)\T0501.LOG > NUL
   FIND "EEPROM checksum updated." $(ARTIFACTS)\T0501.LOG > NUL
   FIND "Plug and Play configuration completed successfully." $(ARTIFACTS)\T0501.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0501.LOG
   FIND "Plug and Play Capability = yes" $(ARTIFACTS)\T0501.LOG > NUL
   FIND "Plug and Play = disabled" $(ARTIFACTS)\T0501.LOG > NUL

t0502:
   @echo [t0502] Testing mock CONFIGURE /PNP transition back to enabled... >> TEST.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /PNP:ENABLED /VERBOSE > $(ARTIFACTS)\T0502.LOG
   FIND "PNP parameter accepted. Requested Plug and Play mode: enabled" $(ARTIFACTS)\T0502.LOG > NUL
   FIND "Plug and Play configuration completed successfully." $(ARTIFACTS)\T0502.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /PNP:ENABLED /VERBOSE >> $(ARTIFACTS)\T0502.LOG
   FIND "Plug and Play mode is already configured to the requested value." $(ARTIFACTS)\T0502.LOG > NUL
   FIND "No hardware changes required." $(ARTIFACTS)\T0502.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0502.LOG
   FIND "Plug and Play Capability = yes" $(ARTIFACTS)\T0502.LOG > NUL
   FIND "Plug and Play = enabled" $(ARTIFACTS)\T0502.LOG > NUL

t0503:
   @echo [t0503] Testing mock CONFIGURE /PNP rejects legacy numeric value... >> TEST.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /PNP:1 > $(ARTIFACTS)\T0503.LOG
   FIND "Invalid /PNP parameter. Use ENABLED or DISABLED." $(ARTIFACTS)\T0503.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0503.LOG
   FIND "Plug and Play Capability = yes" $(ARTIFACTS)\T0503.LOG > NUL

t0504:
   @echo [t0504] Testing mock CONFIGURE /PNP symbolic false value... >> TEST.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /PNP:FALSE > $(ARTIFACTS)\T0504.LOG
   FIND "Invalid /PNP parameter. Use ENABLED or DISABLED." $(ARTIFACTS)\T0504.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0504.LOG
   FIND "Plug and Play Capability = yes" $(ARTIFACTS)\T0504.LOG > NUL

t0505:
   @echo [t0505] Testing mock CONFIGURE /PNP arbitrary invalid input... >> TEST.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /PNP:OTHERINVALIDINPUT > $(ARTIFACTS)\T0505.LOG
   FIND "Invalid /PNP parameter. Use ENABLED or DISABLED." $(ARTIFACTS)\T0505.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0505.LOG
   FIND "Plug and Play Capability = yes" $(ARTIFACTS)\T0505.LOG > NUL

t0600:
   @echo [t06xx] MODEM_CHANGE: Verify MODEM property change behaviour ... >> TEST.LOG

t0601:
   @echo [t0601] Testing mock CONFIGURE /MODEM transition to 1200... >> TEST.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:1200 > $(ARTIFACTS)\T0601.LOG
   FIND "MODEM parameter accepted. Requested setting: 1200" $(ARTIFACTS)\T0601.LOG > NUL
   FIND "Modem speed configuration completed successfully." $(ARTIFACTS)\T0601.LOG > NUL

t0602:
   @echo [t0602] Testing mock CONFIGURE /MODEM unchanged transition at 1200... >> TEST.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:1200 /VERBOSE > $(ARTIFACTS)\T0602.LOG
   FIND "MODEM parameter accepted. Requested setting: 1200" $(ARTIFACTS)\T0602.LOG > NUL
   FIND "Modem speed setting is already configured to the requested value." $(ARTIFACTS)\T0602.LOG > NUL

t0603:
   @echo [t0603] Testing mock CONFIGURE /MODEM transition to NONE... >> TEST.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:NONE > $(ARTIFACTS)\T0603.LOG
   FIND "MODEM parameter accepted. Requested setting: none" $(ARTIFACTS)\T0603.LOG > NUL
   FIND "Modem speed configuration completed successfully." $(ARTIFACTS)\T0603.LOG > NUL

t0604:
   @echo [t0604] Testing mock CONFIGURE /MODEM invalid symbolic input... >> TEST.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:FALSE > $(ARTIFACTS)\T0604.LOG
   FIND "Invalid /MODEM parameter. Use NONE, 1200, 2400, 9600, 19200, 38400, or 25-1600 in 25 increments." $(ARTIFACTS)\T0604.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:NONE /VERBOSE >> $(ARTIFACTS)\T0604.LOG
   FIND "Modem speed setting is already configured to the requested value." $(ARTIFACTS)\T0604.LOG > NUL

t0605:
   @echo [t0605] Testing mock CONFIGURE /MODEM invalid out-of-range step value... >> TEST.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:26 > $(ARTIFACTS)\T0605.LOG
   FIND "Invalid /MODEM parameter. Use NONE, 1200, 2400, 9600, 19200, 38400, or 25-1600 in 25 increments." $(ARTIFACTS)\T0605.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:NONE /VERBOSE >> $(ARTIFACTS)\T0605.LOG
   FIND "Modem speed setting is already configured to the requested value." $(ARTIFACTS)\T0605.LOG > NUL

t0606:
   @echo [t0606] Testing /MODEM preserves EEPROM Link Beat Disable policy... >> TEST.LOG
   ${SEEDAPP} NOLINKBEAT > $(ARTIFACTS)\T0606.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:1200 /VERBOSE >> $(ARTIFACTS)\T0606.LOG
   FIND "Current EEPROM word 0Dh: 4010" $(ARTIFACTS)\T0606.LOG > NUL
   FIND "New EEPROM word 0Dh: 7310" $(ARTIFACTS)\T0606.LOG > NUL
   FIND "Modem speed configuration completed successfully." $(ARTIFACTS)\T0606.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:1200 /VERBOSE >> $(ARTIFACTS)\T0606.LOG
   FIND "Current EEPROM word 0Dh: 7310" $(ARTIFACTS)\T0606.LOG > NUL
   FIND "Modem speed setting is already configured to the requested value." $(ARTIFACTS)\T0606.LOG > NUL
   ${SEEDAPP} INIT >> $(ARTIFACTS)\T0606.LOG

t0607:
   @echo [t0607] Testing LIST MODEM interrupt-disable timing readout... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T0607.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:9600 >> $(ARTIFACTS)\T0607.LOG
   $(BINAPP) LIST >> $(ARTIFACTS)\T0607.LOG
   FIND "MODEM Interrupt Disable Time = 500 us (9600 bd)" $(ARTIFACTS)\T0607.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:NONE >> $(ARTIFACTS)\T0607.LOG
   $(BINAPP) LIST >> $(ARTIFACTS)\T0607.LOG
   FIND "MODEM Interrupt Disable Time = 1600 us (NONE)" $(ARTIFACTS)\T0607.LOG > NUL

t0608:
   @echo [t0608] Testing /MODEM:25 preserves all non-MODEM word 0Dh fields... >> TEST.LOG
   ${SEEDAPP} MODEMFIELDS > $(ARTIFACTS)\T0608.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:25 /VERBOSE >> $(ARTIFACTS)\T0608.LOG
   FIND "Current EEPROM word 0Dh: 73FF" $(ARTIFACTS)\T0608.LOG > NUL
   FIND "New EEPROM word 0Dh: 40FF" $(ARTIFACTS)\T0608.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0608.LOG
   FIND "Optimization = Server" $(ARTIFACTS)\T0608.LOG > NUL
   ${SEEDAPP} INIT >> $(ARTIFACTS)\T0608.LOG

t0609:
   @echo [t0609] Testing /MODEM:1600 upper-bound field encoding... >> TEST.LOG
   ${SEEDAPP} MODEMFIELDS > $(ARTIFACTS)\T0609.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:1600 /VERBOSE >> $(ARTIFACTS)\T0609.LOG
   FIND "Current EEPROM word 0Dh: 73FF" $(ARTIFACTS)\T0609.LOG > NUL
   FIND "New EEPROM word 0Dh: 7FFF" $(ARTIFACTS)\T0609.LOG > NUL
   ${SEEDAPP} INIT >> $(ARTIFACTS)\T0609.LOG

t0610:
   @echo [t0610] Testing MODEM timing INFO and canonical SAVECONFIG serialization... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T0610.LOG
   $(BINAPP) LIST >> $(ARTIFACTS)\T0610.LOG
   FIND "MODEM Interrupt Disable Time = 25 us" $(ARTIFACTS)\T0610.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:25 /VERBOSE >> $(ARTIFACTS)\T0610.LOG
   FIND "New EEPROM word 0Dh: 0010" $(ARTIFACTS)\T0610.LOG > NUL
   $(BINAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\M25.BAT /EXECFILE:BIN\3CHWMOCK.EXE >> $(ARTIFACTS)\T0610.LOG
   FIND "MODEM:25" $(ARTIFACTS)\M25.BAT > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:38400 /VERBOSE >> $(ARTIFACTS)\T0610.LOG
   FIND "New EEPROM word 0Dh: 0410" $(ARTIFACTS)\T0610.LOG > NUL
   $(BINAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\M384.BAT /EXECFILE:BIN\3CHWMOCK.EXE >> $(ARTIFACTS)\T0610.LOG
   FIND "MODEM:38400" $(ARTIFACTS)\M384.BAT > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0610.LOG
   FIND "MODEM Interrupt Disable Time = 125 us (38400 bd)" $(ARTIFACTS)\T0610.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:19200 /VERBOSE >> $(ARTIFACTS)\T0610.LOG
   FIND "New EEPROM word 0Dh: 0910" $(ARTIFACTS)\T0610.LOG > NUL
   $(BINAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\M192.BAT /EXECFILE:BIN\3CHWMOCK.EXE >> $(ARTIFACTS)\T0610.LOG
   FIND "MODEM:19200" $(ARTIFACTS)\M192.BAT > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0610.LOG
   FIND "MODEM Interrupt Disable Time = 250 us (19200 bd)" $(ARTIFACTS)\T0610.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:9600 /VERBOSE >> $(ARTIFACTS)\T0610.LOG
   FIND "New EEPROM word 0Dh: 1310" $(ARTIFACTS)\T0610.LOG > NUL
   $(BINAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\M96.BAT /EXECFILE:BIN\3CHWMOCK.EXE >> $(ARTIFACTS)\T0610.LOG
   FIND "MODEM:9600" $(ARTIFACTS)\M96.BAT > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0610.LOG
   FIND "MODEM Interrupt Disable Time = 500 us (9600 bd)" $(ARTIFACTS)\T0610.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:2400 /VERBOSE >> $(ARTIFACTS)\T0610.LOG
   FIND "New EEPROM word 0Dh: 2710" $(ARTIFACTS)\T0610.LOG > NUL
   $(BINAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\M24.BAT /EXECFILE:BIN\3CHWMOCK.EXE >> $(ARTIFACTS)\T0610.LOG
   FIND "MODEM:2400" $(ARTIFACTS)\M24.BAT > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0610.LOG
   FIND "MODEM Interrupt Disable Time = 1000 us (2400 bd)" $(ARTIFACTS)\T0610.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:1200 /VERBOSE >> $(ARTIFACTS)\T0610.LOG
   FIND "New EEPROM word 0Dh: 3310" $(ARTIFACTS)\T0610.LOG > NUL
   $(BINAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\M12.BAT /EXECFILE:BIN\3CHWMOCK.EXE >> $(ARTIFACTS)\T0610.LOG
   FIND "MODEM:1200" $(ARTIFACTS)\M12.BAT > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0610.LOG
   FIND "MODEM Interrupt Disable Time = 1300 us (1200 bd)" $(ARTIFACTS)\T0610.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:NONE /VERBOSE >> $(ARTIFACTS)\T0610.LOG
   FIND "New EEPROM word 0Dh: 3F10" $(ARTIFACTS)\T0610.LOG > NUL
   $(BINAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\MNONE.BAT /EXECFILE:BIN\3CHWMOCK.EXE >> $(ARTIFACTS)\T0610.LOG
   FIND "MODEM:NONE" $(ARTIFACTS)\MNONE.BAT > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0610.LOG
   FIND "MODEM Interrupt Disable Time = 1600 us (NONE)" $(ARTIFACTS)\T0610.LOG > NUL
   ${SEEDAPP} M1200US >> $(ARTIFACTS)\T0610.LOG
   $(BINAPP) LIST >> $(ARTIFACTS)\T0610.LOG
   FIND "MODEM Interrupt Disable Time = 1200 us (not representable by CLI)" $(ARTIFACTS)\T0610.LOG > NUL
   $(BINAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\M1200U.BAT >> $(ARTIFACTS)\T0610.LOG
   FIND "MODEM:NONE" $(ARTIFACTS)\M1200U.BAT > NUL
   ${SEEDAPP} INIT >> $(ARTIFACTS)\T0610.LOG

t0700:
   @echo [t07xx] FD_CHANGE: Verify FULLDUPLEX property behaviour ... >> TEST.LOG

t0701:
   @echo [t0701] Testing mock CONFIGURE /FULLDUPLEX transition to enabled... >> TEST.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:ENABLED /VERBOSE > $(ARTIFACTS)\T0701.LOG
   FIND "FULLDUPLEX parameter accepted. Requested mode: enabled" $(ARTIFACTS)\T0701.LOG > NUL
   FIND "Full duplex configuration completed successfully." $(ARTIFACTS)\T0701.LOG > NUL
   FIND "Live Network Diagnostic full duplex mode verified." $(ARTIFACTS)\T0701.LOG > NUL

t0702:
   @echo [t0702] Testing mock CONFIGURE /FULLDUPLEX unchanged transition at enabled... >> TEST.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:ENABLED /VERBOSE > $(ARTIFACTS)\T0702.LOG
   FIND "FULLDUPLEX parameter accepted. Requested mode: enabled" $(ARTIFACTS)\T0702.LOG > NUL
   FIND "Full duplex mode is already configured to the requested value." $(ARTIFACTS)\T0702.LOG > NUL
   FIND "Live Network Diagnostic full duplex mode verified." $(ARTIFACTS)\T0702.LOG > NUL

t0703:
   @echo [t0703] Testing mock CONFIGURE /FULLDUPLEX transition to disabled... >> TEST.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:DISABLED /VERBOSE > $(ARTIFACTS)\T0703.LOG
   FIND "FULLDUPLEX parameter accepted. Requested mode: disabled" $(ARTIFACTS)\T0703.LOG > NUL
   FIND "Full duplex configuration completed successfully." $(ARTIFACTS)\T0703.LOG > NUL
   FIND "Live Network Diagnostic full duplex mode verified." $(ARTIFACTS)\T0703.LOG > NUL

t0704:
   @echo [t0704] Testing mock CONFIGURE /FULLDUPLEX rejects legacy numeric value... >> TEST.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:1 > $(ARTIFACTS)\T0704.LOG
   FIND "Invalid /FULLDUPLEX parameter. Use ENABLED or DISABLED." $(ARTIFACTS)\T0704.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:DISABLED /VERBOSE >> $(ARTIFACTS)\T0704.LOG
   FIND "Full duplex mode is already configured to the requested value." $(ARTIFACTS)\T0704.LOG > NUL

t0705:
   @echo [t0705] Testing mock CONFIGURE /FULLDUPLEX invalid symbolic input... >> TEST.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:TRUE > $(ARTIFACTS)\T0705.LOG
   FIND "Invalid /FULLDUPLEX parameter. Use ENABLED or DISABLED." $(ARTIFACTS)\T0705.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:DISABLED /VERBOSE >> $(ARTIFACTS)\T0705.LOG
   FIND "Full duplex mode is already configured to the requested value." $(ARTIFACTS)\T0705.LOG > NUL

t0706:
   @echo [t0706] Testing LIST Full Duplex readout for enabled and disabled... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T0706.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:ENABLED >> $(ARTIFACTS)\T0706.LOG
   $(BINAPP) LIST >> $(ARTIFACTS)\T0706.LOG
   FIND "Full Duplex = enabled" $(ARTIFACTS)\T0706.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:DISABLED >> $(ARTIFACTS)\T0706.LOG
   $(BINAPP) LIST >> $(ARTIFACTS)\T0706.LOG
   FIND "Full Duplex = disabled" $(ARTIFACTS)\T0706.LOG > NUL

t0707:
   @echo [t0707] Testing LIST Full Duplex readout on a non-capable adapter... >> TEST.LOG
   ${SEEDAPP} NOFD > $(ARTIFACTS)\T0707.LOG
   $(BINAPP) LIST >> $(ARTIFACTS)\T0707.LOG
   FIND "Full Duplex Capability = no" $(ARTIFACTS)\T0707.LOG > NUL
   FIND "Full Duplex = not supported" $(ARTIFACTS)\T0707.LOG > NUL
   ${SEEDAPP} INIT >> $(ARTIFACTS)\T0707.LOG

t0708:
   @echo [t0708] Testing Full Duplex enable rejects effective AUI and permits disable... >> TEST.LOG
   ${SEEDAPP} TPAUI > $(ARTIFACTS)\T0708.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:AUI >> $(ARTIFACTS)\T0708.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:ENABLED >> $(ARTIFACTS)\T0708.LOG
   FIND "Full duplex can only be enabled with the TP transceiver." $(ARTIFACTS)\T0708.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:DISABLED >> $(ARTIFACTS)\T0708.LOG
   FIND "Full duplex configuration completed successfully." $(ARTIFACTS)\T0708.LOG > NUL
   ${SEEDAPP} INIT >> $(ARTIFACTS)\T0708.LOG

t0709:
   @echo [t0709] Testing Full Duplex enable rejects effective COAX... >> TEST.LOG
   ${SEEDAPP} TRI > $(ARTIFACTS)\T0709.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:COAX >> $(ARTIFACTS)\T0709.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:ENABLED >> $(ARTIFACTS)\T0709.LOG
   FIND "Full duplex can only be enabled with the TP transceiver." $(ARTIFACTS)\T0709.LOG > NUL
   ${SEEDAPP} INIT >> $(ARTIFACTS)\T0709.LOG

t0710:
   @echo [t0710] Testing Full Duplex enable rejects effective AUTO... >> TEST.LOG
   ${SEEDAPP} TPAUI > $(ARTIFACTS)\T0710.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:AUTO >> $(ARTIFACTS)\T0710.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:ENABLED >> $(ARTIFACTS)\T0710.LOG
   FIND "Full duplex can only be enabled with the TP transceiver." $(ARTIFACTS)\T0710.LOG > NUL
   ${SEEDAPP} INIT >> $(ARTIFACTS)\T0710.LOG

t0711:
   @echo [t0711] Testing combined prospective transceiver Full Duplex gate... >> TEST.LOG
   ${SEEDAPP} TRI > $(ARTIFACTS)\T0711.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:TP /FULLDUPLEX:ENABLED /VERBOSE >> $(ARTIFACTS)\T0711.LOG
   FIND "Configuration completed successfully." $(ARTIFACTS)\T0711.LOG > NUL
   FIND "Live Network Diagnostic full duplex mode verified." $(ARTIFACTS)\T0711.LOG > NUL
   ${SEEDAPP} TPAUI >> $(ARTIFACTS)\T0711.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:AUI /FULLDUPLEX:ENABLED >> $(ARTIFACTS)\T0711.LOG
   FIND "Full duplex can only be enabled with the TP transceiver." $(ARTIFACTS)\T0711.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0711.LOG
   FIND "Transceiver = on-board TP" $(ARTIFACTS)\T0711.LOG > NUL
   FIND "Full Duplex = disabled" $(ARTIFACTS)\T0711.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:AUTO /FULLDUPLEX:ENABLED >> $(ARTIFACTS)\T0711.LOG
   FIND "Full duplex can only be enabled with the TP transceiver." $(ARTIFACTS)\T0711.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0711.LOG
   FIND "Transceiver = on-board TP" $(ARTIFACTS)\T0711.LOG > NUL
   FIND "Full Duplex = disabled" $(ARTIFACTS)\T0711.LOG > NUL

t0712:
   @echo [t0712] Testing stale enabled Full Duplex policy synchronizes live state... >> TEST.LOG
   ${SEEDAPP} FDSTALEON > $(ARTIFACTS)\T0712.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:ENABLED /VERBOSE >> $(ARTIFACTS)\T0712.LOG
   FIND "Full duplex mode is already configured to the requested value." $(ARTIFACTS)\T0712.LOG > NUL
   FIND "Live Network Diagnostic full duplex mode verified." $(ARTIFACTS)\T0712.LOG > NUL
   ${SEEDAPP} INIT >> $(ARTIFACTS)\T0712.LOG

t0713:
   @echo [t0713] Testing stale disabled Full Duplex policy synchronizes live state... >> TEST.LOG
   ${SEEDAPP} FDSTALEOFF > $(ARTIFACTS)\T0713.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:DISABLED /VERBOSE >> $(ARTIFACTS)\T0713.LOG
   FIND "Full duplex mode is already configured to the requested value." $(ARTIFACTS)\T0713.LOG > NUL
   FIND "Live Network Diagnostic full duplex mode verified." $(ARTIFACTS)\T0713.LOG > NUL
   ${SEEDAPP} INIT >> $(ARTIFACTS)\T0713.LOG

t0800:
   @echo [t08xx] CAPABILITY_GATES: Verify capability gates behaviour ... >> TEST.LOG

t0801:
   @echo [t0801] Testing PNP absence does not disable Full Duplex capability... >> TEST.LOG
   ${SEEDAPP} NOPNP > $(ARTIFACTS)\T0801.LOG
   FIND "Seed file created (NOPNP)." $(ARTIFACTS)\T0801.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0801.LOG
   FIND "Plug and Play Capability = no" $(ARTIFACTS)\T0801.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /PNP:ENABLED >> $(ARTIFACTS)\T0801.LOG
   FIND "This adapter does not support Plug and Play configuration." $(ARTIFACTS)\T0801.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:ENABLED >> $(ARTIFACTS)\T0801.LOG
   FIND "Full duplex configuration completed successfully." $(ARTIFACTS)\T0801.LOG > NUL
   ${SEEDAPP} INIT >> $(ARTIFACTS)\T0801.LOG

t0802:
   @echo [t0802] Testing Full Duplex requires TP despite a supported product ID... >> TEST.LOG
   ${SEEDAPP} NOFD > $(ARTIFACTS)\T0802.LOG
   FIND "Seed file created (NOFD)." $(ARTIFACTS)\T0802.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:ENABLED >> $(ARTIFACTS)\T0802.LOG
   FIND "This adapter does not support full duplex configuration." $(ARTIFACTS)\T0802.LOG > NUL
   ${SEEDAPP} INIT >> $(ARTIFACTS)\T0802.LOG

t0803:
   @echo [t0803] Testing PNP is independent of revision while Full Duplex is not... >> TEST.LOG
   ${SEEDAPP} PNPREV0 > $(ARTIFACTS)\T0803.LOG
   FIND "Seed file created (PNPREV0)." $(ARTIFACTS)\T0803.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0803.LOG
   FIND "Plug and Play Capability = yes" $(ARTIFACTS)\T0803.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:ENABLED >> $(ARTIFACTS)\T0803.LOG
   FIND "This adapter does not support full duplex configuration." $(ARTIFACTS)\T0803.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /PNP:DISABLED >> $(ARTIFACTS)\T0803.LOG
   FIND "Plug and Play configuration completed successfully." $(ARTIFACTS)\T0803.LOG > NUL
   ${SEEDAPP} INIT >> $(ARTIFACTS)\T0803.LOG

t0900:
   @echo [t09xx] OPTIMIZE_CHANGE: Verify Workload Optimization change behaviour ... >> TEST.LOG

t0901:
   @echo [t0901] Testing mock CONFIGURE /OPTIMIZE transition to OS/2... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T0901.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /OPTIMIZE:OS/2 /VERBOSE >> $(ARTIFACTS)\T0901.LOG
   FIND "New EEPROM word 0Dh: Windows or OS/2" $(ARTIFACTS)\T0901.LOG > NUL
   FIND "Configuration completed successfully." $(ARTIFACTS)\T0901.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0901.LOG
   FIND "Optimization = Windows or OS/2" $(ARTIFACTS)\T0901.LOG > NUL

t0902:
   @echo [t0902] Testing mock CONFIGURE /OPTIMIZE invalid symbolic input... >> TEST.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /OPTIMIZE:TRUE > $(ARTIFACTS)\T0902.LOG
   FIND "Invalid /OPTIMIZE parameter. Use DOS, WINDOWS, OS/2, or SERVER." $(ARTIFACTS)\T0902.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0902.LOG
   FIND "Optimization = Windows or OS/2" $(ARTIFACTS)\T0902.LOG > NUL

t0903:
   @echo [t0903] Testing mock CONFIGURE /OPTIMIZE transition to SERVER... >> TEST.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /OPTIMIZE:SERVER > $(ARTIFACTS)\T0903.LOG
   FIND "Configuration completed successfully." $(ARTIFACTS)\T0903.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0903.LOG
   FIND "Optimization = Server" $(ARTIFACTS)\T0903.LOG > NUL

t0904:
   @echo [t0904] Testing mock CONFIGURE /OPTIMIZE transition to DOS... >> TEST.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /OPTIMIZE:DOS >> $(ARTIFACTS)\T0904.LOG
   FIND "Configuration completed successfully." $(ARTIFACTS)\T0904.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0904.LOG
   FIND "Optimization = DOS" $(ARTIFACTS)\T0904.LOG > NUL

t1000:
   @echo [t10xx] LINK_STATUS: Verify LINKBEAT reporting ... >> TEST.LOG

t1001:
   @echo [t1001] Testing LIST Link Status: LINKUP seed reports connected... >> TEST.LOG
   ${SEEDAPP} LINKUP > $(ARTIFACTS)\T1001.LOG
   FIND "Seed file created (LINKUP)." $(ARTIFACTS)\T1001.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1001.LOG
   FIND "Link Status = connected" $(ARTIFACTS)\T1001.LOG > NUL
   ${SEEDAPP} INIT >> $(ARTIFACTS)\T1001.LOG

t1002:
   @echo [t1002] Testing LIST Link Status: LINKDOWN seed reports not connected... >> TEST.LOG
   ${SEEDAPP} LINKDOWN > $(ARTIFACTS)\T1002.LOG
   FIND "Seed file created (LINKDOWN)." $(ARTIFACTS)\T1002.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1002.LOG
   FIND "Link Status = not connected" $(ARTIFACTS)\T1002.LOG > NUL
   ${SEEDAPP} INIT >> $(ARTIFACTS)\T1002.LOG

t1100:
   @echo [t11xx] BOOTROM_CHANGE: Verify boot ROM change behaviour ... >> TEST.LOG

t1101:
   @echo [t1101] Testing mock CONFIGURE /BADDRESS minimum valid address with /BSIZE:16... >> TEST.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:C0000 /BSIZE:16 > $(ARTIFACTS)\T1101.LOG
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1101.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1101.LOG
   FIND "Boot ROM = 16K at C0000H" $(ARTIFACTS)\T1101.LOG > NUL


t1102:
   @echo [t1102] Testing mock CONFIGURE /BADDRESS+/BSIZE enable together... >> TEST.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:C8000 /BSIZE:16 /VERBOSE > $(ARTIFACTS)\T1102.LOG
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1102.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1102.LOG
   FIND "Boot ROM = 16K at C8000H" $(ARTIFACTS)\T1102.LOG > NUL


t1103:
   @echo [t1103] Testing mock CONFIGURE /BADDRESS+/BSIZE reconfigure to a new pair... >> TEST.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:D0000 /BSIZE:32 > $(ARTIFACTS)\T1103.LOG
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1103.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1103.LOG
   FIND "Boot ROM = 32K at D0000H" $(ARTIFACTS)\T1103.LOG > NUL


t1104:
   @echo [t1104] Testing mock CONFIGURE /BSIZE:DISABLED disables Boot ROM... >> TEST.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /BSIZE:DISABLED > $(ARTIFACTS)\T1104.LOG
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1104.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1104.LOG
   FIND "Boot ROM = disabled" $(ARTIFACTS)\T1104.LOG > NUL


t1105:
   @echo [t1105] Testing mock CONFIGURE /BADDRESS out-of-range address... >> TEST.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:E0000 /BSIZE:16 > $(ARTIFACTS)\T1105.LOG
   FIND "Invalid /BADDRESS parameter. Use a hex address C0000-DE000 in 2000h steps." $(ARTIFACTS)\T1105.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1105.LOG
   FIND "Boot ROM = disabled" $(ARTIFACTS)\T1105.LOG > NUL


t1106:
   @echo [t1106] Testing mock CONFIGURE /BADDRESS non-aligned address... >> TEST.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:C1000 /BSIZE:16 > $(ARTIFACTS)\T1106.LOG
   FIND "Invalid /BADDRESS parameter. Use a hex address C0000-DE000 in 2000h steps." $(ARTIFACTS)\T1106.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1106.LOG
   FIND "Boot ROM = disabled" $(ARTIFACTS)\T1106.LOG > NUL


t1107:
   @echo [t1107] Testing mock CONFIGURE /BSIZE invalid value... >> TEST.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:C8000 /BSIZE:64 > $(ARTIFACTS)\T1107.LOG
   FIND "Invalid /BSIZE parameter. Use 8, 16, 32, or DISABLED." $(ARTIFACTS)\T1107.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1107.LOG
   FIND "Boot ROM = disabled" $(ARTIFACTS)\T1107.LOG > NUL


t1108:
   @echo [t1108] Testing mock CONFIGURE /BSIZE alone (real size) is rejected (pairing rule)... >> TEST.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /BSIZE:16 > $(ARTIFACTS)\T1108.LOG
   FIND "BADDRESS and /BSIZE must be specified together" $(ARTIFACTS)\T1108.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1108.LOG
   FIND "Boot ROM = disabled" $(ARTIFACTS)\T1108.LOG > NUL


t1109:
   @echo [t1109] Testing mock CONFIGURE /BADDRESS alone is rejected (pairing rule)... >> TEST.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:C8000 > $(ARTIFACTS)\T1109.LOG
   FIND "BADDRESS and /BSIZE must be specified together" $(ARTIFACTS)\T1109.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1109.LOG
   FIND "Boot ROM = disabled" $(ARTIFACTS)\T1109.LOG > NUL


t1110:
   @echo [t1110] Testing mock CONFIGURE /BADDRESS combined with /BSIZE:DISABLED is ignored... >> TEST.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:C8000 /BSIZE:DISABLED > $(ARTIFACTS)\T1110.LOG
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1110.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1110.LOG
   FIND "Boot ROM = disabled" $(ARTIFACTS)\T1110.LOG > NUL


t1111:
   @echo [t1111] Testing Boot ROM capability gate: 3C509B-TPO rejects /BADDRESS+/BSIZE... >> TEST.LOG
   ${SEEDAPP} 3C509B-TPO > $(ARTIFACTS)\T1111.LOG
   FIND "Seed file created (3C509B-TPO)." $(ARTIFACTS)\T1111.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:C8000 /BSIZE:16 >> $(ARTIFACTS)\T1111.LOG
   FIND "This adapter does not support Boot ROM configuration." $(ARTIFACTS)\T1111.LOG > NUL
   ${SEEDAPP} INIT >> $(ARTIFACTS)\T1111.LOG


t1200:
   @echo [t12xx] XCVR_CHANGE: Verify transceiver change behaviour ... >> TEST.LOG

t1201:
   @echo [t1201] Testing CONFIGURE /TR:TP on 3C509B-TP (should succeed, TP only card)... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1201.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:TP >> $(ARTIFACTS)\T1201.LOG
   FIND "TR parameter accepted. Requested transceiver: TP" $(ARTIFACTS)\T1201.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1201.LOG
   FIND "Transceiver = on-board TP" $(ARTIFACTS)\T1201.LOG > NUL


t1202:
   @echo [t1202] Testing CONFIGURE /TR:AUI on 3C509B-TP is rejected (TP only card)... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1202.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:AUI >> $(ARTIFACTS)\T1202.LOG
   FIND "This adapter does not support the requested transceiver type." $(ARTIFACTS)\T1202.LOG > NUL


t1203:
   @echo [t1203] Testing CONFIGURE /TR:COAX on 3C509B-TP is rejected (TP only card)... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1203.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:COAX >> $(ARTIFACTS)\T1203.LOG
   FIND "This adapter does not support the requested transceiver type." $(ARTIFACTS)\T1203.LOG > NUL


t1204:
   @echo [t1204] Testing CONFIGURE /TR:AUTO on 3C509B-TP is rejected (TP only card)... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1204.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:AUTO >> $(ARTIFACTS)\T1204.LOG
   FIND "This adapter does not support the requested transceiver type." $(ARTIFACTS)\T1204.LOG > NUL


t1205:
   @echo [t1205] Testing CONFIGURE /TR:AUI on 3C509B-Combo (should succeed)... >> TEST.LOG
   ${SEEDAPP} 3C509B-COMBO > $(ARTIFACTS)\T1205.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:AUI >> $(ARTIFACTS)\T1205.LOG
   FIND "TR parameter accepted. Requested transceiver: AUI" $(ARTIFACTS)\T1205.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1205.LOG
   FIND "Transceiver = external" $(ARTIFACTS)\T1205.LOG > NUL
   ${SEEDAPP} INIT >> $(ARTIFACTS)\T1205.LOG


t1206:
   @echo [t1206] Testing CONFIGURE /TR:AUTO on 3C509B-Combo (should succeed)... >> TEST.LOG
   ${SEEDAPP} 3C509B-COMBO > $(ARTIFACTS)\T1206.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:AUTO >> $(ARTIFACTS)\T1206.LOG
   FIND "TR parameter accepted. Requested transceiver: AUTO" $(ARTIFACTS)\T1206.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1206.LOG
   FIND "Transceiver = auto select" $(ARTIFACTS)\T1206.LOG > NUL
   ${SEEDAPP} INIT >> $(ARTIFACTS)\T1206.LOG


t1207:
   @echo [t1207] Testing CONFIGURE /TR:COAX on 3C509B-Combo is rejected (no coax port)... >> TEST.LOG
   ${SEEDAPP} 3C509B-COMBO > $(ARTIFACTS)\T1207.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:COAX >> $(ARTIFACTS)\T1207.LOG
   FIND "This adapter does not support the requested transceiver type." $(ARTIFACTS)\T1207.LOG > NUL
   ${SEEDAPP} INIT >> $(ARTIFACTS)\T1207.LOG


t1208:
   @echo [t1208] Testing CONFIGURE /TR:COAX on 3C509B-TPC (should succeed)... >> TEST.LOG
   ${SEEDAPP} 3C509B-TPC > $(ARTIFACTS)\T1208.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:COAX >> $(ARTIFACTS)\T1208.LOG
   FIND "TR parameter accepted. Requested transceiver: COAX" $(ARTIFACTS)\T1208.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1208.LOG
   FIND "Transceiver = on-board coax" $(ARTIFACTS)\T1208.LOG > NUL
   ${SEEDAPP} INIT >> $(ARTIFACTS)\T1208.LOG


t1209:
   @echo [t1209] Testing CONFIGURE /TR:AUTO on TP+BNC capabilities succeeds... >> TEST.LOG
   ${SEEDAPP} 3C509B-TPC > $(ARTIFACTS)\T1209.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:AUTO >> $(ARTIFACTS)\T1209.LOG
   FIND "TR parameter accepted. Requested transceiver: AUTO" $(ARTIFACTS)\T1209.LOG > NUL
   ${SEEDAPP} INIT >> $(ARTIFACTS)\T1209.LOG


t1210:
   @echo [t1210] Testing CONFIGURE /TR:AUTO on 3C509B-TPO is rejected (TPO excluded from auto-select)... >> TEST.LOG
   ${SEEDAPP} 3C509B-TPO > $(ARTIFACTS)\T1210.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:AUTO >> $(ARTIFACTS)\T1210.LOG
   FIND "This adapter does not support the requested transceiver type." $(ARTIFACTS)\T1210.LOG > NUL
   ${SEEDAPP} INIT >> $(ARTIFACTS)\T1210.LOG


t1211:
   @echo [t1211] Testing /XCVR alias: behaves identically to /TR:TP... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1211.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /XCVR:TP >> $(ARTIFACTS)\T1211.LOG
   FIND "TR parameter accepted. Requested transceiver: TP" $(ARTIFACTS)\T1211.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1211.LOG
   FIND "Transceiver = on-board TP" $(ARTIFACTS)\T1211.LOG > NUL

t1212:
   @echo [t1212] Testing live TP+AUI capabilities override TP product ID... >> TEST.LOG
   ${SEEDAPP} TPAUI > $(ARTIFACTS)\T1212.LOG
   $(BINAPP) LIST >> $(ARTIFACTS)\T1212.LOG
   FIND "Connectors = TP, AUI" $(ARTIFACTS)\T1212.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:AUI >> $(ARTIFACTS)\T1212.LOG
   FIND "TR parameter accepted. Requested transceiver: AUI" $(ARTIFACTS)\T1212.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:AUTO >> $(ARTIFACTS)\T1212.LOG
   FIND "TR parameter accepted. Requested transceiver: AUTO" $(ARTIFACTS)\T1212.LOG > NUL
   ${SEEDAPP} INIT >> $(ARTIFACTS)\T1212.LOG

t1213:
   @echo [t1213] Testing CONFIGURE /TR:AUTO on three live connectors succeeds... >> TEST.LOG
   ${SEEDAPP} TRI > $(ARTIFACTS)\T1213.LOG
   $(BINAPP) LIST >> $(ARTIFACTS)\T1213.LOG
   FIND "Connectors = TP, AUI, COAX" $(ARTIFACTS)\T1213.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:AUTO >> $(ARTIFACTS)\T1213.LOG
   FIND "TR parameter accepted. Requested transceiver: AUTO" $(ARTIFACTS)\T1213.LOG > NUL
   ${SEEDAPP} INIT >> $(ARTIFACTS)\T1213.LOG

t1300:
   @echo [t13xx] CLI_PARSER: Verify CLI parser behaviour ... >> TEST.LOG

t1301:
   @echo [t1301] Testing HELP command prints CLI help screen... >> TEST.LOG
   $(BINAPP) HELP > $(ARTIFACTS)\T1301.LOG
   FIND "Usage: 3CCFGCLI [COMMAND]" $(ARTIFACTS)\T1301.LOG > NUL
   FIND "Display this help screen" $(ARTIFACTS)\T1301.LOG > NUL

t1302:
   @echo [t1302] Testing CONFIGURE parser accepts '-' switch introducers... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1302.LOG
   $(BINAPP) CONFIGURE -ADAPTERNUM:1 -INT:5 >> $(ARTIFACTS)\T1302.LOG
   FIND "INT parameter accepted. Requested IRQ: 5" $(ARTIFACTS)\T1302.LOG > NUL
   FIND "IRQ configuration completed successfully." $(ARTIFACTS)\T1302.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1302.LOG
   FIND "IRQ = 5" $(ARTIFACTS)\T1302.LOG > NUL

t1303:
   @echo [t1303] Testing CONFIGURE parser accepts '=' value separators... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1303.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM=1 /INT=5 >> $(ARTIFACTS)\T1303.LOG
   FIND "INT parameter accepted. Requested IRQ: 5" $(ARTIFACTS)\T1303.LOG > NUL
   FIND "IRQ configuration completed successfully." $(ARTIFACTS)\T1303.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1303.LOG
   FIND "IRQ = 5" $(ARTIFACTS)\T1303.LOG > NUL

t1304:
   @echo [t1304] Testing CONFIGURE with no property is rejected... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1304.LOG
   $(BINAPP) CONFIGURE >> $(ARTIFACTS)\T1304.LOG
   FIND "No CONFIGURE property was specified." $(ARTIFACTS)\T1304.LOG > NUL

t1305:
   @echo [t1305] Testing empty command line and HELP token boundaries... >> TEST.LOG
   $(BINAPP) > $(ARTIFACTS)\T1305.LOG
   FIND "Usage: 3CCFGCLI [COMMAND]" $(ARTIFACTS)\T1305.LOG > NUL
   $(BINAPP) HELP >> $(ARTIFACTS)\T1305.LOG
   FIND "Display this help screen" $(ARTIFACTS)\T1305.LOG > NUL
   $(BINAPP) HELPXYZ >> $(ARTIFACTS)\T1305.LOG
   FIND "Usage: 3CCFGCLI [COMMAND]" $(ARTIFACTS)\T1305.LOG > NUL

t1306:
   @echo [t1306] Testing LIST token boundaries... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1306.LOG
   $(BINAPP) LIST >> $(ARTIFACTS)\T1306.LOG
   FIND "IOBASE = 0300" $(ARTIFACTS)\T1306.LOG > NUL
   $(BINAPP) LISTXYZ >> $(ARTIFACTS)\T1306.LOG
   FIND "Usage: 3CCFGCLI [COMMAND]" $(ARTIFACTS)\T1306.LOG > NUL

t1307:
   @echo [t1307] Testing SAVECONFIG token boundaries and arguments... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1307.LOG
   @if exist RESTORE.BAT del RESTORE.BAT
   $(BINAPP) SAVECONFIG >> $(ARTIFACTS)\T1307.LOG
   FIND "Configuration restore batch file created: RESTORE.BAT" $(ARTIFACTS)\T1307.LOG > NUL
   @if exist RESTORE.BAT del RESTORE.BAT
   $(BINAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\VERBSC.BAT >> $(ARTIFACTS)\T1307.LOG
   FIND "Configuration restore batch file created: $(ARTIFACTS)\VERBSC.BAT" $(ARTIFACTS)\T1307.LOG > NUL
   @if exist $(ARTIFACTS)\VERBSC.BAT del $(ARTIFACTS)\VERBSC.BAT
   $(BINAPP) SAVECONFIGXYZ >> $(ARTIFACTS)\T1307.LOG
   FIND "Usage: 3CCFGCLI [COMMAND]" $(ARTIFACTS)\T1307.LOG > NUL
   @if exist RESTORE.BAT FIND "THIS FILE SHOULD NOT EXIST" RESTORE.BAT > NUL

t1308:
   @echo [t1308] Testing CONFIGURE token boundaries and arguments... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1308.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /INT:5 >> $(ARTIFACTS)\T1308.LOG
   FIND "IRQ configuration completed successfully." $(ARTIFACTS)\T1308.LOG > NUL
   $(BINAPP) CONFIGUREXYZ >> $(ARTIFACTS)\T1308.LOG
   FIND "Usage: 3CCFGCLI [COMMAND]" $(ARTIFACTS)\T1308.LOG > NUL

t1309:
   @echo [t1309] Testing leading spaces and tabs before command verbs... >> TEST.LOG
   $(BINAPP)    HELP > $(ARTIFACTS)\T1309.LOG
   FIND "Usage: 3CCFGCLI [COMMAND]" $(ARTIFACTS)\T1309.LOG > NUL
   $(BINAPP)	LIST >> $(ARTIFACTS)\T1309.LOG
   FIND "IOBASE = 0300" $(ARTIFACTS)\T1309.LOG > NUL

t1310:
   @echo [t1310] Testing truncated command names... >> TEST.LOG
   $(BINAPP) HEL > $(ARTIFACTS)\T1310.LOG
   FIND "Usage: 3CCFGCLI [COMMAND]" $(ARTIFACTS)\T1310.LOG > NUL
   $(BINAPP) LIS >> $(ARTIFACTS)\T1310.LOG
   FIND "Usage: 3CCFGCLI [COMMAND]" $(ARTIFACTS)\T1310.LOG > NUL
   $(BINAPP) SAVECONFI >> $(ARTIFACTS)\T1310.LOG
   FIND "Usage: 3CCFGCLI [COMMAND]" $(ARTIFACTS)\T1310.LOG > NUL
   $(BINAPP) CONFIGUR >> $(ARTIFACTS)\T1310.LOG
   FIND "Usage: 3CCFGCLI [COMMAND]" $(ARTIFACTS)\T1310.LOG > NUL

t1400:
   @echo [t14xx] COMBINED_TRANSACTIONS: Verify combined transactions ... >> TEST.LOG

t1401:
   @echo [t1401] Testing combined CONFIGURE /IOBASE+/INT transaction... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1401.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /IOBASE:0280 /INT:5 /VERBOSE >> $(ARTIFACTS)\T1401.LOG
   FIND "IOBASE parameter accepted. Requested IOBASE: 0280" $(ARTIFACTS)\T1401.LOG > NUL
   FIND "INT parameter accepted. Requested IRQ: 5" $(ARTIFACTS)\T1401.LOG > NUL
   FIND "IOBASE and IRQ configuration completed successfully." $(ARTIFACTS)\T1401.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1401.LOG
   FIND "IOBASE = 0280" $(ARTIFACTS)\T1401.LOG > NUL
   FIND "IRQ = 5" $(ARTIFACTS)\T1401.LOG > NUL
   ${SEEDAPP} INIT >> $(ARTIFACTS)\T1401.LOG

t1402:
   @echo [t1402] Testing combined CONFIGURE /MODEM+/FULLDUPLEX transaction... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1402.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:1200 /FULLDUPLEX:ENABLED /VERBOSE >> $(ARTIFACTS)\T1402.LOG
   FIND "MODEM parameter accepted. Requested setting: 1200" $(ARTIFACTS)\T1402.LOG > NUL
   FIND "FULLDUPLEX parameter accepted. Requested mode: enabled" $(ARTIFACTS)\T1402.LOG > NUL
   FIND "New EEPROM word 0Dh: " $(ARTIFACTS)\T1402.LOG > NUL
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1402.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:1200 /VERBOSE >> $(ARTIFACTS)\T1402.LOG
   FIND "Modem speed setting is already configured to the requested value." $(ARTIFACTS)\T1402.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:ENABLED /VERBOSE >> $(ARTIFACTS)\T1402.LOG
   FIND "Full duplex mode is already configured to the requested value." $(ARTIFACTS)\T1402.LOG > NUL
   ${SEEDAPP} INIT >> $(ARTIFACTS)\T1402.LOG

t1403:
   @echo [t1403] Testing combined CONFIGURE /IOBASE+/TR on 3C509B-Combo... >> TEST.LOG
   ${SEEDAPP} 3C509B-COMBO > $(ARTIFACTS)\T1403.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /IOBASE:0280 /TR:AUI /VERBOSE >> $(ARTIFACTS)\T1403.LOG
   FIND "IOBASE parameter accepted. Requested IOBASE: 0280" $(ARTIFACTS)\T1403.LOG > NUL
   FIND "TR parameter accepted. Requested transceiver: AUI" $(ARTIFACTS)\T1403.LOG > NUL
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1403.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1403.LOG
   FIND "IOBASE = 0280" $(ARTIFACTS)\T1403.LOG > NUL
   FIND "Transceiver = external" $(ARTIFACTS)\T1403.LOG > NUL
   ${SEEDAPP} INIT >> $(ARTIFACTS)\T1403.LOG

t1404:
   @echo [t1404] Testing combined CONFIGURE /IOBASE+/BADDRESS+/BSIZE transaction... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1404.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /IOBASE:0280 /BADDRESS:C8000 /BSIZE:16 /VERBOSE >> $(ARTIFACTS)\T1404.LOG
   FIND "IOBASE parameter accepted. Requested IOBASE: 0280" $(ARTIFACTS)\T1404.LOG > NUL
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1404.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1404.LOG
   FIND "IOBASE = 0280" $(ARTIFACTS)\T1404.LOG > NUL
   FIND "Boot ROM = 16K at C8000H" $(ARTIFACTS)\T1404.LOG > NUL
   ${SEEDAPP} INIT >> $(ARTIFACTS)\T1404.LOG

t1405:
   @echo [t1405] Testing combined CONFIGURE /OPTIMIZE+/MODEM transaction... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1405.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /OPTIMIZE:SERVER /MODEM:1200 /VERBOSE >> $(ARTIFACTS)\T1405.LOG
   FIND "MODEM parameter accepted. Requested setting: 1200" $(ARTIFACTS)\T1405.LOG > NUL
   FIND "New EEPROM word 0Dh: Server" $(ARTIFACTS)\T1405.LOG > NUL
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1405.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /OPTIMIZE:SERVER /VERBOSE >> $(ARTIFACTS)\T1405.LOG
   FIND "No hardware changes required." $(ARTIFACTS)\T1405.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:1200 /VERBOSE >> $(ARTIFACTS)\T1405.LOG
   FIND "Modem speed setting is already configured to the requested value." $(ARTIFACTS)\T1405.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1405.LOG
   FIND "Optimization = Server" $(ARTIFACTS)\T1405.LOG > NUL
   ${SEEDAPP} INIT >> $(ARTIFACTS)\T1405.LOG

t1406:
   @echo [t1406] Testing combined CONFIGURE /TR:AUTO+/BADDRESS+/BSIZE on 3C509B-Combo... >> TEST.LOG
   ${SEEDAPP} 3C509B-COMBO > $(ARTIFACTS)\T1406.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:AUTO /BADDRESS:C8000 /BSIZE:16 /VERBOSE >> $(ARTIFACTS)\T1406.LOG
   FIND "TR parameter accepted. Requested transceiver: AUTO" $(ARTIFACTS)\T1406.LOG > NUL
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1406.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1406.LOG
   FIND "Transceiver = auto select" $(ARTIFACTS)\T1406.LOG > NUL
   FIND "Boot ROM = 16K at C8000H" $(ARTIFACTS)\T1406.LOG > NUL
   ${SEEDAPP} INIT >> $(ARTIFACTS)\T1406.LOG

t1407:
   @echo [t1407] Testing combined CONFIGURE /PNP+/INT checksum domains... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1407.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /PNP:DISABLED /INT:5 /VERBOSE >> $(ARTIFACTS)\T1407.LOG
   FIND "PNP parameter accepted. Requested Plug and Play mode: disabled" $(ARTIFACTS)\T1407.LOG > NUL
   FIND "INT parameter accepted. Requested IRQ: 5" $(ARTIFACTS)\T1407.LOG > NUL
   FIND "Plug and Play configuration word written." $(ARTIFACTS)\T1407.LOG > NUL
   FIND "IRQ configuration word written." $(ARTIFACTS)\T1407.LOG > NUL
   FIND "EEPROM checksum updated." $(ARTIFACTS)\T1407.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1407.LOG
   FIND "Plug and Play = disabled" $(ARTIFACTS)\T1407.LOG > NUL
   FIND "IRQ = 5" $(ARTIFACTS)\T1407.LOG > NUL
   ${SEEDAPP} INIT >> $(ARTIFACTS)\T1407.LOG

t1500:
   @echo [t15xx] MULTI_NIC: Verify multi-NIC behaviour ... >> TEST.LOG

t1501:
   @echo [t1501] Testing multi-NIC default ADD allocation yields distinct bases... >> TEST.LOG
   ${SEEDAPP} CLEAR > $(ARTIFACTS)\T1501.LOG
   ${SEEDAPP} ADD 3C509B-TP >> $(ARTIFACTS)\T1501.LOG
   ${SEEDAPP} ADD 3C509B-COMBO >> $(ARTIFACTS)\T1501.LOG
   $(BINAPP) LIST >> $(ARTIFACTS)\T1501.LOG
   FIND "IOBASE = 0300, IRQ = 10" $(ARTIFACTS)\T1501.LOG > NUL
   FIND "IOBASE = 0310, IRQ = 10" $(ARTIFACTS)\T1501.LOG > NUL
   ${SEEDAPP} CLEAR >> $(ARTIFACTS)\T1501.LOG

t1502:
   @echo [t1502] Testing multi-NIC CONFIGURE requires /ADAPTERNUM... >> TEST.LOG
   ${SEEDAPP} CLEAR > $(ARTIFACTS)\T1502.LOG
   ${SEEDAPP} ADD 3C509B-TP 0300 10 >> $(ARTIFACTS)\T1502.LOG
   ${SEEDAPP} ADD 3C509B-COMBO 0310 5 >> $(ARTIFACTS)\T1502.LOG
   $(BINAPP) CONFIGURE /INT:7 >> $(ARTIFACTS)\T1502.LOG
   FIND "ADAPTERNUM is required when more than one adapter is installed." $(ARTIFACTS)\T1502.LOG > NUL
   ${SEEDAPP} CLEAR >> $(ARTIFACTS)\T1502.LOG

t1503:
   @echo [t1503] Testing multi-NIC adapter selection changes only the targeted NIC... >> TEST.LOG
   ${SEEDAPP} CLEAR > $(ARTIFACTS)\T1503.LOG
   ${SEEDAPP} ADD 3C509B-TP 0300 10 >> $(ARTIFACTS)\T1503.LOG
   ${SEEDAPP} ADD 3C509B-COMBO 0310 5 >> $(ARTIFACTS)\T1503.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:2 /INT:7 >> $(ARTIFACTS)\T1503.LOG
   FIND "IRQ configuration completed successfully." $(ARTIFACTS)\T1503.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1503.LOG
   FIND "IOBASE = 0300, IRQ = 10" $(ARTIFACTS)\T1503.LOG > NUL
   FIND "IOBASE = 0310, IRQ = 7" $(ARTIFACTS)\T1503.LOG > NUL
   ${SEEDAPP} CLEAR >> $(ARTIFACTS)\T1503.LOG

t1504:
   @echo [t1504] Testing multi-NIC /IOBASE conflict detection blocks duplicate base... >> TEST.LOG
   ${SEEDAPP} CLEAR > $(ARTIFACTS)\T1504.LOG
   ${SEEDAPP} ADD 3C509B-TP 0300 10 >> $(ARTIFACTS)\T1504.LOG
   ${SEEDAPP} ADD 3C509B-COMBO 0310 5 >> $(ARTIFACTS)\T1504.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:2 /IOBASE:0300 >> $(ARTIFACTS)\T1504.LOG
   FIND "Requested IOBASE is already used by another discovered adapter." $(ARTIFACTS)\T1504.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1504.LOG
   FIND "IOBASE = 0300, IRQ = 10" $(ARTIFACTS)\T1504.LOG > NUL
   FIND "IOBASE = 0310, IRQ = 5" $(ARTIFACTS)\T1504.LOG > NUL
   ${SEEDAPP} CLEAR >> $(ARTIFACTS)\T1504.LOG

t1505:
   @echo [t1505] Testing duplicate active-IOBASE conflict rejects targeted migration... >> TEST.LOG
   ${SEEDAPP} CLEAR > $(ARTIFACTS)\T1505.LOG
   ${SEEDAPP} ADD 3C509B-TP 0300 10 >> $(ARTIFACTS)\T1505.LOG
   ${SEEDAPP} ADD 3C509B-COMBO 0300 5 >> $(ARTIFACTS)\T1505.LOG
   $(BINAPP) LIST >> $(ARTIFACTS)\T1505.LOG
   FIND "IOBASE = 0300, IRQ = 10" $(ARTIFACTS)\T1505.LOG > NUL
   FIND "IOBASE = 0300, IRQ = 5" $(ARTIFACTS)\T1505.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:2 /IOBASE:0310 >> $(ARTIFACTS)\T1505.LOG
   FIND "Selected adapter has no active IOBASE" $(ARTIFACTS)\T1505.LOG > NUL
   ${SEEDAPP} CLEAR >> $(ARTIFACTS)\T1505.LOG

t1600:
   @echo [t16xx] SAVECONFIG_TEST: Verify save configuration behaviour ... >> TEST.LOG

t1601:
   @echo [t1601] Testing SAVECONFIG exports the INIT restore command... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1601.LOG
   $(BINAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\RESTORE.BAT >> $(ARTIFACTS)\T1601.LOG
   FIND "Configuration restore batch file created: $(ARTIFACTS)\RESTORE.BAT" $(ARTIFACTS)\T1601.LOG > NUL
   FIND "3CCFGCLI.EXE CONFIGURE" $(ARTIFACTS)\RESTORE.BAT > NUL

t1602:
   @echo [t1602] Testing SAVECONFIG rejects an empty /OUTPUTFILE value... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1602.LOG
   $(BINAPP) SAVECONFIG /OUTPUTFILE: >> $(ARTIFACTS)\T1602.LOG
   FIND "SAVECONFIG /OUTPUTFILE requires a value." $(ARTIFACTS)\T1602.LOG > NUL

t1603:
   @echo [t1603] Testing SAVECONFIG exports one restore line per multi-NIC adapter... >> TEST.LOG
   ${SEEDAPP} CLEAR > $(ARTIFACTS)\T1603.LOG
   ${SEEDAPP} ADD 3C509B-TP 0300 10 >> $(ARTIFACTS)\T1603.LOG
   ${SEEDAPP} ADD 3C509B-COMBO 0310 5 >> $(ARTIFACTS)\T1603.LOG
   $(BINAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\RESTORE.BAT >> $(ARTIFACTS)\T1603.LOG
   FIND "Configuration restore batch file created: $(ARTIFACTS)\RESTORE.BAT" $(ARTIFACTS)\T1603.LOG > NUL
   FIND "ADAPTERNUM:1 /INT:10" $(ARTIFACTS)\RESTORE.BAT > NUL
   FIND "ADAPTERNUM:2 /INT:5" $(ARTIFACTS)\RESTORE.BAT > NUL

t1604:
   @echo [t1604] Testing SAVECONFIG /EXECFILE overrides the embedded program name... >> TEST.LOG
   $(BINAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\RESTORE.BAT /EXECFILE:%1 >> $(ARTIFACTS)\T1604.LOG
   FIND "Configuration restore batch file created: $(ARTIFACTS)\RESTORE.BAT" $(ARTIFACTS)\T1604.LOG > NUL
   FIND "%1 CONFIGURE" $(ARTIFACTS)\RESTORE.BAT > NUL

t1605:
   @echo [t1605] Testing SAVECONFIG exports a valid, re-parseable /MODEM value... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1605.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:9600 >> $(ARTIFACTS)\T1605.LOG
   $(BINAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\RESTORE.BAT >> $(ARTIFACTS)\T1605.LOG
   FIND "MODEM:9600" $(ARTIFACTS)\RESTORE.BAT > NUL
   ${SEEDAPP} INIT >> $(ARTIFACTS)\T1605.LOG

t1606:
   @echo [t1606] Testing SAVECONFIG keeps Boot ROM pair atomic in split restore commands... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1606.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /IOBASE:0280 /INT:5 /PNP:ENABLED /FULLDUPLEX:ENABLED >> $(ARTIFACTS)\T1606.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:1200 /OPTIMIZE:SERVER /BADDRESS:C8000 /BSIZE:16 /TR:TP >> $(ARTIFACTS)\T1606.LOG
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1606.LOG > NUL
   $(BINAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\RESTORE.BAT /EXECFILE:BIN\3CHWMOCK.EXE >> $(ARTIFACTS)\T1606.LOG
   FIND "BIN\3CHWMOCK.EXE CONFIGURE /ADAPTERNUM:1 /BADDRESS:C8000 /BSIZE:16 /TR:TP" $(ARTIFACTS)\RESTORE.BAT > NUL
   ${SEEDAPP} INIT >> $(ARTIFACTS)\T1606.LOG
   CALL $(ARTIFACTS)\RESTORE.BAT >> $(ARTIFACTS)\T1606.LOG
   $(BINAPP) LIST >> $(ARTIFACTS)\T1606.LOG
   FIND "IOBASE = 0280, IRQ = 5" $(ARTIFACTS)\T1606.LOG > NUL
   FIND "Optimization = Server" $(ARTIFACTS)\T1606.LOG > NUL
   FIND "Boot ROM = 16K at C8000H" $(ARTIFACTS)\T1606.LOG > NUL

t1607:
   @echo [t1607] Testing SAVECONFIG rejects unsupported percent EXECFILE forms... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1607.LOG
   $(BINAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\BADP2.BAT /EXECFILE:%2 > $(ARTIFACTS)\T1607.LOG
   FIND "Invalid SAVECONFIG /EXECFILE value." $(ARTIFACTS)\T1607.LOG > NUL
   $(BINAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\BADPATH.BAT /EXECFILE:%PATH% > $(ARTIFACTS)\T1607.LOG
   FIND "Invalid SAVECONFIG /EXECFILE value." $(ARTIFACTS)\T1607.LOG > NUL
   $(BINAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\BADMID.BAT /EXECFILE:C:\TOOLS\%1 > $(ARTIFACTS)\T1607.LOG
   FIND "Invalid SAVECONFIG /EXECFILE value." $(ARTIFACTS)\T1607.LOG > NUL
   $(BINAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\BADTAIL.BAT /EXECFILE:%1\3CCFGCLI.EXE > $(ARTIFACTS)\T1607.LOG
   FIND "Invalid SAVECONFIG /EXECFILE value." $(ARTIFACTS)\T1607.LOG > NUL
   @if exist $(ARTIFACTS)\BADP2.BAT FIND "THIS FILE SHOULD NOT EXIST" $(ARTIFACTS)\BADP2.BAT > NUL
   @if exist $(ARTIFACTS)\BADPATH.BAT FIND "THIS FILE SHOULD NOT EXIST" $(ARTIFACTS)\BADPATH.BAT > NUL
   @if exist $(ARTIFACTS)\BADMID.BAT FIND "THIS FILE SHOULD NOT EXIST" $(ARTIFACTS)\BADMID.BAT > NUL
   @if exist $(ARTIFACTS)\BADTAIL.BAT FIND "THIS FILE SHOULD NOT EXIST" $(ARTIFACTS)\BADTAIL.BAT > NUL

t1608:
   @echo [t1608] Testing SAVECONFIG rejects missing literal EXECFILE before creating output... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1608.LOG
   @if exist $(ARTIFACTS)\MISSING.BAT del $(ARTIFACTS)\MISSING.BAT
   $(BINAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\MISSING.BAT /EXECFILE:C:\DOESNOT\EXIST.EXE >> $(ARTIFACTS)\T1608.LOG
   FIND "SAVECONFIG /EXECFILE file not found." $(ARTIFACTS)\T1608.LOG > NUL
   @if exist $(ARTIFACTS)\MISSING.BAT FIND "THIS FILE SHOULD NOT EXIST" $(ARTIFACTS)\MISSING.BAT > NUL

t1609:
   @echo [t1609] Testing SAVECONFIG default EXECFILE dynamic splitting preserves options... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1609.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /INT:10 /IOBASE:0300 /PNP:ENABLED /FULLDUPLEX:ENABLED >> $(ARTIFACTS)\T1609.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:NONE /OPTIMIZE:DOS /BSIZE:DISABLED /TR:TP >> $(ARTIFACTS)\T1609.LOG
   $(BINAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\DEFREST.BAT >> $(ARTIFACTS)\T1609.LOG
   FIND "3CCFGCLI.EXE CONFIGURE /ADAPTERNUM:1 /INT:10 /IOBASE:0300 /PNP:ENABLED /FULLDUPLEX:ENABLED" $(ARTIFACTS)\DEFREST.BAT > NUL
   FIND "3CCFGCLI.EXE CONFIGURE /ADAPTERNUM:1 /BSIZE:DISABLED /TR:TP" $(ARTIFACTS)\DEFREST.BAT > NUL
   FIND "BSIZE:DISABLED" $(ARTIFACTS)\DEFREST.BAT > NUL

t1610:
   @echo [t1610] Testing SAVECONFIG %%1 conservative EXECFILE reservation... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1610.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /INT:10 /IOBASE:0300 /PNP:ENABLED /FULLDUPLEX:ENABLED >> $(ARTIFACTS)\T1610.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:NONE /OPTIMIZE:DOS /BSIZE:DISABLED /TR:TP >> $(ARTIFACTS)\T1610.LOG
   $(BINAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\PCTREST.BAT /EXECFILE:%1 >> $(ARTIFACTS)\T1610.LOG
   FIND "%1 CONFIGURE /ADAPTERNUM:1 /INT:10 /IOBASE:0300 /PNP:ENABLED" $(ARTIFACTS)\PCTREST.BAT > NUL
   FIND "%1 CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:ENABLED /MODEM:NONE" $(ARTIFACTS)\PCTREST.BAT > NUL
   FIND "%1 CONFIGURE /ADAPTERNUM:1 /OPTIMIZE:DOS /BSIZE:DISABLED /TR:TP" $(ARTIFACTS)\PCTREST.BAT > NUL

t1611:
   @echo [t1611] Testing SAVECONFIG literal EXECFILE restore execution with disabled Boot ROM... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1611.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /INT:10 /IOBASE:0300 /PNP:ENABLED /FULLDUPLEX:ENABLED >> $(ARTIFACTS)\T1611.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:NONE /OPTIMIZE:DOS /BSIZE:DISABLED /TR:TP >> $(ARTIFACTS)\T1611.LOG
   $(BINAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\LITREST.BAT /EXECFILE:BIN\3CHWMOCK.EXE >> $(ARTIFACTS)\T1611.LOG
   FIND "BIN\3CHWMOCK.EXE CONFIGURE" $(ARTIFACTS)\LITREST.BAT > NUL
   FIND "BSIZE:DISABLED" $(ARTIFACTS)\LITREST.BAT > NUL
   ${SEEDAPP} INIT >> $(ARTIFACTS)\T1611.LOG
   CALL $(ARTIFACTS)\LITREST.BAT >> $(ARTIFACTS)\T1611.LOG
   $(BINAPP) LIST >> $(ARTIFACTS)\T1611.LOG
   FIND "IOBASE = 0300, IRQ = 10" $(ARTIFACTS)\T1611.LOG > NUL
   FIND "Plug and Play = enabled" $(ARTIFACTS)\T1611.LOG > NUL
   FIND "Full Duplex = enabled" $(ARTIFACTS)\T1611.LOG > NUL
   FIND "Boot ROM = disabled" $(ARTIFACTS)\T1611.LOG > NUL


t1612:
   @echo [t1612] Testing SAVECONFIG without options writes the default RESTORE.BAT... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1612.LOG
   @if exist RESTORE.BAT del RESTORE.BAT
   $(BINAPP) SAVECONFIG >> $(ARTIFACTS)\T1612.LOG
   FIND "Configuration restore batch file created: RESTORE.BAT" $(ARTIFACTS)\T1612.LOG > NUL
   FIND "3CCFGCLI.EXE CONFIGURE" RESTORE.BAT > NUL
   @if exist RESTORE.BAT del RESTORE.BAT

t1613:
   @echo [t1613] Testing SAVECONFIG /EXECFILE alone uses the default output filename... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1613.LOG
   @if exist RESTORE.BAT del RESTORE.BAT
   $(BINAPP) SAVECONFIG /EXECFILE:BIN\3CHWMOCK.EXE >> $(ARTIFACTS)\T1613.LOG
   FIND "Configuration restore batch file created: RESTORE.BAT" $(ARTIFACTS)\T1613.LOG > NUL
   FIND "BIN\3CHWMOCK.EXE CONFIGURE" RESTORE.BAT > NUL
   @if exist RESTORE.BAT del RESTORE.BAT

t1614:
   @echo [t1614] Testing SAVECONFIG accepts OUTPUTFILE and EXECFILE in either order... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1614.LOG
   $(BINAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\ORDER1.BAT /EXECFILE:BIN\3CHWMOCK.EXE >> $(ARTIFACTS)\T1614.LOG
   FIND "Configuration restore batch file created: $(ARTIFACTS)\ORDER1.BAT" $(ARTIFACTS)\T1614.LOG > NUL
   FIND "BIN\3CHWMOCK.EXE CONFIGURE" $(ARTIFACTS)\ORDER1.BAT > NUL
   $(BINAPP) SAVECONFIG /EXECFILE:BIN\3CHWMOCK.EXE /OUTPUTFILE:$(ARTIFACTS)\ORDER2.BAT >> $(ARTIFACTS)\T1614.LOG
   FIND "Configuration restore batch file created: $(ARTIFACTS)\ORDER2.BAT" $(ARTIFACTS)\T1614.LOG > NUL
   FIND "BIN\3CHWMOCK.EXE CONFIGURE" $(ARTIFACTS)\ORDER2.BAT > NUL

t1615:
   @echo [t1615] Testing SAVECONFIG rejects duplicate options... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1615.LOG
   $(BINAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\DUPA.BAT /OUTPUTFILE:$(ARTIFACTS)\DUPB.BAT > $(ARTIFACTS)\T1615.LOG
   FIND "Duplicate SAVECONFIG option." $(ARTIFACTS)\T1615.LOG > NUL
   $(BINAPP) SAVECONFIG /EXECFILE:BIN\3CHWMOCK.EXE /EXECFILE:BIN\3CCFGCLI.EXE > $(ARTIFACTS)\T1615.LOG
   FIND "Duplicate SAVECONFIG option." $(ARTIFACTS)\T1615.LOG > NUL

t1616:
   @echo [t1616] Testing SAVECONFIG rejects unknown options and the old positional syntax... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1616.LOG
   $(BINAPP) SAVECONFIG /BIRCHERMUESLI:34333 > $(ARTIFACTS)\T1616.LOG
   FIND "Invalid SAVECONFIG option." $(ARTIFACTS)\T1616.LOG > NUL
   $(BINAPP) SAVECONFIG $(ARTIFACTS)\OLDPOS.BAT > $(ARTIFACTS)\T1616.LOG
   FIND "Invalid SAVECONFIG option." $(ARTIFACTS)\T1616.LOG > NUL
   @if exist $(ARTIFACTS)\OLDPOS.BAT FIND "THIS FILE SHOULD NOT EXIST" $(ARTIFACTS)\OLDPOS.BAT > NUL


t1617:
   @echo [t1617] Testing SAVECONFIG /OUTPUTFILE alone keeps the default executable... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1617.LOG
   $(BINAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\OUTONLY.BAT >> $(ARTIFACTS)\T1617.LOG
   FIND "Configuration restore batch file created: $(ARTIFACTS)\OUTONLY.BAT" $(ARTIFACTS)\T1617.LOG > NUL
   FIND "3CCFGCLI.EXE CONFIGURE /ADAPTERNUM:1" $(ARTIFACTS)\OUTONLY.BAT > NUL

t1618:
   @echo [t1618] Testing global /VERBOSE is accepted by LIST... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1618.LOG
   $(BINAPP) LIST /VERBOSE >> $(ARTIFACTS)\T1618.LOG
   FIND "IOBASE = 0300" $(ARTIFACTS)\T1618.LOG > NUL

t1619:
   @echo [t1619] Testing global /VERBOSE with bare SAVECONFIG uses RESTORE.BAT... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1619.LOG
   @if exist RESTORE.BAT del RESTORE.BAT
   $(BINAPP) SAVECONFIG /VERBOSE >> $(ARTIFACTS)\T1619.LOG
   FIND "Configuration restore batch file created: RESTORE.BAT" $(ARTIFACTS)\T1619.LOG > NUL
   FIND "3CCFGCLI.EXE CONFIGURE" RESTORE.BAT > NUL
   @if exist RESTORE.BAT del RESTORE.BAT

t1620:
   @echo [t1620] Testing global /VERBOSE position is not significant for SAVECONFIG... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1620.LOG
   $(BINAPP) SAVECONFIG /VERBOSE /OUTPUTFILE:$(ARTIFACTS)\VERB1.BAT >> $(ARTIFACTS)\T1620.LOG
   FIND "Configuration restore batch file created: $(ARTIFACTS)\VERB1.BAT" $(ARTIFACTS)\T1620.LOG > NUL
   FIND "3CCFGCLI.EXE CONFIGURE" $(ARTIFACTS)\VERB1.BAT > NUL
   $(BINAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\VERB2.BAT /VERBOSE >> $(ARTIFACTS)\T1620.LOG
   FIND "Configuration restore batch file created: $(ARTIFACTS)\VERB2.BAT" $(ARTIFACTS)\T1620.LOG > NUL
   $(BINAPP) SAVECONFIG /VERBOSE /OUTPUTFILE:$(ARTIFACTS)\VERB3.BAT /EXECFILE:BIN\3CHWMOCK.EXE >> $(ARTIFACTS)\T1620.LOG
   FIND "BIN\3CHWMOCK.EXE CONFIGURE" $(ARTIFACTS)\VERB3.BAT > NUL
   $(BINAPP) SAVECONFIG /EXECFILE:BIN\3CHWMOCK.EXE /VERBOSE /OUTPUTFILE:$(ARTIFACTS)\VERB4.BAT >> $(ARTIFACTS)\T1620.LOG
   FIND "BIN\3CHWMOCK.EXE CONFIGURE" $(ARTIFACTS)\VERB4.BAT > NUL

t1621:
   @echo [t1621] Testing duplicate global /VERBOSE is rejected for every verb... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1621.LOG
   $(BINAPP) LIST /VERBOSE /VERBOSE > $(ARTIFACTS)\T1621.LOG
   FIND "Duplicate /VERBOSE option." $(ARTIFACTS)\T1621.LOG > NUL
   $(BINAPP) SAVECONFIG /VERBOSE /OUTPUTFILE:$(ARTIFACTS)\DUPV.BAT /VERBOSE > $(ARTIFACTS)\T1621.LOG
   FIND "Duplicate /VERBOSE option." $(ARTIFACTS)\T1621.LOG > NUL
   $(BINAPP) CONFIGURE /VERBOSE /INT:5 /VERBOSE > $(ARTIFACTS)\T1621.LOG
   FIND "Duplicate /VERBOSE option." $(ARTIFACTS)\T1621.LOG > NUL
   @if exist $(ARTIFACTS)\DUPV.BAT FIND "THIS FILE SHOULD NOT EXIST" $(ARTIFACTS)\DUPV.BAT > NUL

t1622:
   @echo [t1622] Testing verb namespaces do not leak across CONFIGURE and SAVECONFIG... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1622.LOG
   $(BINAPP) SAVECONFIG /INT:5 > $(ARTIFACTS)\T1622.LOG
   FIND "Invalid SAVECONFIG option." $(ARTIFACTS)\T1622.LOG > NUL
   $(BINAPP) SAVECONFIG /ADAPTERNUM:1 > $(ARTIFACTS)\T1622.LOG
   FIND "Invalid SAVECONFIG option." $(ARTIFACTS)\T1622.LOG > NUL
   $(BINAPP) SAVECONFIG /VERBOSE /BIRCHERMUESLI:34333 > $(ARTIFACTS)\T1622.LOG
   FIND "Invalid SAVECONFIG option." $(ARTIFACTS)\T1622.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /OUTPUTFILE:A.BAT > $(ARTIFACTS)\T1622.LOG
   FIND "Invalid CONFIGURE option." $(ARTIFACTS)\T1622.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /EXECFILE:FOO.EXE > $(ARTIFACTS)\T1622.LOG
   FIND "Invalid CONFIGURE option." $(ARTIFACTS)\T1622.LOG > NUL

t1700:
   @echo [t17xx] VERIFICATION_CONTROL_FLOW: verify transaction chain behaviour ... >> TEST.LOG

t1701:
   @echo [t1701] Testing INT+PNP verification chain without /VERBOSE... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1701.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /INT:5 /PNP:DISABLED >> $(ARTIFACTS)\T1701.LOG
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1701.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1701.LOG
   FIND "IRQ = 5" $(ARTIFACTS)\T1701.LOG > NUL
   FIND "Plug and Play = disabled" $(ARTIFACTS)\T1701.LOG > NUL

t1702:
   @echo [t1702] Testing INT+PNP verification chain with /VERBOSE... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1702.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /INT:5 /PNP:DISABLED /VERBOSE >> $(ARTIFACTS)\T1702.LOG
   FIND "EEPROM IRQ verified: 5" $(ARTIFACTS)\T1702.LOG > NUL
   FIND "Live IRQ verified: 5" $(ARTIFACTS)\T1702.LOG > NUL
   FIND "EEPROM Plug and Play mode verified." $(ARTIFACTS)\T1702.LOG > NUL
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1702.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1702.LOG
   FIND "IRQ = 5" $(ARTIFACTS)\T1702.LOG > NUL
   FIND "Plug and Play = disabled" $(ARTIFACTS)\T1702.LOG > NUL

t1703:
   @echo [t1703] Testing unchanged INT+PNP verification chain without /VERBOSE... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1703.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /INT:10 /PNP:DISABLED >> $(ARTIFACTS)\T1703.LOG
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1703.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1703.LOG
   FIND "IRQ = 10" $(ARTIFACTS)\T1703.LOG > NUL
   FIND "Plug and Play = disabled" $(ARTIFACTS)\T1703.LOG > NUL

t1704:
   @echo [t1704] Testing unchanged INT+PNP verification chain with /VERBOSE... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1704.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /INT:10 /PNP:DISABLED /VERBOSE >> $(ARTIFACTS)\T1704.LOG
   FIND "IRQ is already configured to the requested value." $(ARTIFACTS)\T1704.LOG > NUL
   FIND "EEPROM Plug and Play mode verified." $(ARTIFACTS)\T1704.LOG > NUL
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1704.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1704.LOG
   FIND "IRQ = 10" $(ARTIFACTS)\T1704.LOG > NUL
   FIND "Plug and Play = disabled" $(ARTIFACTS)\T1704.LOG > NUL

t1705:
   @echo [t1705] Testing PNP+MODEM verification chain without /VERBOSE... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1705.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /PNP:DISABLED /MODEM:9600 >> $(ARTIFACTS)\T1705.LOG
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1705.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1705.LOG
   FIND "Plug and Play = disabled" $(ARTIFACTS)\T1705.LOG > NUL
   FIND "MODEM Interrupt Disable Time = 500 us (9600 bd)" $(ARTIFACTS)\T1705.LOG > NUL

t1706:
   @echo [t1706] Testing PNP+MODEM verification chain with /VERBOSE... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1706.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /PNP:DISABLED /MODEM:9600 /VERBOSE >> $(ARTIFACTS)\T1706.LOG
   FIND "EEPROM Plug and Play mode verified." $(ARTIFACTS)\T1706.LOG > NUL
   FIND "EEPROM modem speed setting verified." $(ARTIFACTS)\T1706.LOG > NUL
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1706.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1706.LOG
   FIND "Plug and Play = disabled" $(ARTIFACTS)\T1706.LOG > NUL
   FIND "MODEM Interrupt Disable Time = 500 us (9600 bd)" $(ARTIFACTS)\T1706.LOG > NUL

t1707:
   @echo [t1707] Testing FULLDUPLEX+OPTIMIZE verification chain without /VERBOSE... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1707.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:ENABLED /OPTIMIZE:SERVER >> $(ARTIFACTS)\T1707.LOG
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1707.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1707.LOG
   FIND "Full Duplex = enabled" $(ARTIFACTS)\T1707.LOG > NUL
   FIND "Optimization = Server" $(ARTIFACTS)\T1707.LOG > NUL

t1708:
   @echo [t1708] Testing FULLDUPLEX+OPTIMIZE verification chain with /VERBOSE... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1708.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:ENABLED /OPTIMIZE:SERVER /VERBOSE >> $(ARTIFACTS)\T1708.LOG
   FIND "EEPROM full duplex mode verified." $(ARTIFACTS)\T1708.LOG > NUL
   FIND "EEPROM optimize mode verified." $(ARTIFACTS)\T1708.LOG > NUL
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1708.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1708.LOG
   FIND "Full Duplex = enabled" $(ARTIFACTS)\T1708.LOG > NUL
   FIND "Optimization = Server" $(ARTIFACTS)\T1708.LOG > NUL

t1709:
   @echo [t1709] Testing long verification chain with all later properties changed, without /VERBOSE... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1709.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /INT:5 /PNP:DISABLED /MODEM:9600 /FULLDUPLEX:ENABLED >> $(ARTIFACTS)\T1709.LOG
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1709.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1  /OPTIMIZE:SERVER /BADDRESS:C8000 /BSIZE:8 >> $(ARTIFACTS)\T1709.LOG
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1709.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1709.LOG
   FIND "IRQ = 5" $(ARTIFACTS)\T1709.LOG > NUL
   FIND "Plug and Play = disabled" $(ARTIFACTS)\T1709.LOG > NUL
   FIND "MODEM Interrupt Disable Time = 500 us (9600 bd)" $(ARTIFACTS)\T1709.LOG > NUL
   FIND "Full Duplex = enabled" $(ARTIFACTS)\T1709.LOG > NUL
   FIND "Optimization = Server" $(ARTIFACTS)\T1709.LOG > NUL
   FIND "Boot ROM = 8K at C8000H" $(ARTIFACTS)\T1709.LOG > NUL

t1710:
   @echo [t1710] Testing long verification chain with all later properties changed, with /VERBOSE... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1710.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /INT:5 /PNP:DISABLED /MODEM:9600 /FULLDUPLEX:ENABLED /VERBOSE >> $(ARTIFACTS)\T1710.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /OPTIMIZE:SERVER /BADDRESS:C8000 /BSIZE:8 /VERBOSE >> $(ARTIFACTS)\T1710.LOG
   FIND "EEPROM IRQ verified: 5" $(ARTIFACTS)\T1710.LOG > NUL
   FIND "Live IRQ verified: 5" $(ARTIFACTS)\T1710.LOG > NUL
   FIND "EEPROM Plug and Play mode verified." $(ARTIFACTS)\T1710.LOG > NUL
   FIND "EEPROM modem speed setting verified." $(ARTIFACTS)\T1710.LOG > NUL
   FIND "EEPROM full duplex mode verified." $(ARTIFACTS)\T1710.LOG > NUL
   FIND "Live Network Diagnostic full duplex mode verified." $(ARTIFACTS)\T1710.LOG > NUL
   FIND "EEPROM optimize mode verified." $(ARTIFACTS)\T1710.LOG > NUL
   FIND "EEPROM Boot ROM base address verified." $(ARTIFACTS)\T1710.LOG > NUL
   FIND "EEPROM Boot ROM size verified." $(ARTIFACTS)\T1710.LOG > NUL
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1710.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1710.LOG
   FIND "IRQ = 5" $(ARTIFACTS)\T1710.LOG > NUL
   FIND "Plug and Play = disabled" $(ARTIFACTS)\T1710.LOG > NUL
   FIND "MODEM Interrupt Disable Time = 500 us (9600 bd)" $(ARTIFACTS)\T1710.LOG > NUL
   FIND "Full Duplex = enabled" $(ARTIFACTS)\T1710.LOG > NUL
   FIND "Optimization = Server" $(ARTIFACTS)\T1710.LOG > NUL
   FIND "Boot ROM = 8K at C8000H" $(ARTIFACTS)\T1710.LOG > NUL

t1711:
   @echo [t1711] Testing long verification chain with unchanged INT, without /VERBOSE... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1711.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /INT:10 /PNP:DISABLED /MODEM:9600 /FULLDUPLEX:ENABLED >> $(ARTIFACTS)\T1711.LOG
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1711.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /OPTIMIZE:SERVER /BADDRESS:C8000 /BSIZE:8 >> $(ARTIFACTS)\T1711.LOG
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1711.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1711.LOG
   FIND "IRQ = 10" $(ARTIFACTS)\T1711.LOG > NUL
   FIND "Plug and Play = disabled" $(ARTIFACTS)\T1711.LOG > NUL
   FIND "MODEM Interrupt Disable Time = 500 us (9600 bd)" $(ARTIFACTS)\T1711.LOG > NUL
   FIND "Full Duplex = enabled" $(ARTIFACTS)\T1711.LOG > NUL
   FIND "Optimization = Server" $(ARTIFACTS)\T1711.LOG > NUL
   FIND "Boot ROM = 8K at C8000H" $(ARTIFACTS)\T1711.LOG > NUL

t1712:
   @echo [t1712] Testing long verification chain with unchanged INT, with /VERBOSE... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1712.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /INT:10 /PNP:DISABLED /MODEM:9600 /FULLDUPLEX:ENABLED /VERBOSE >> $(ARTIFACTS)\T1712.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /OPTIMIZE:SERVER /BADDRESS:C8000 /BSIZE:8 /VERBOSE >> $(ARTIFACTS)\T1712.LOG
   FIND "IRQ is already configured to the requested value." $(ARTIFACTS)\T1712.LOG > NUL
   FIND "EEPROM Plug and Play mode verified." $(ARTIFACTS)\T1712.LOG > NUL
   FIND "EEPROM modem speed setting verified." $(ARTIFACTS)\T1712.LOG > NUL
   FIND "EEPROM full duplex mode verified." $(ARTIFACTS)\T1712.LOG > NUL
   FIND "Live Network Diagnostic full duplex mode verified." $(ARTIFACTS)\T1712.LOG > NUL
   FIND "EEPROM optimize mode verified." $(ARTIFACTS)\T1712.LOG > NUL
   FIND "EEPROM Boot ROM base address verified." $(ARTIFACTS)\T1712.LOG > NUL
   FIND "EEPROM Boot ROM size verified." $(ARTIFACTS)\T1712.LOG > NUL
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1712.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1712.LOG
   FIND "IRQ = 10" $(ARTIFACTS)\T1712.LOG > NUL
   FIND "Plug and Play = disabled" $(ARTIFACTS)\T1712.LOG > NUL
   FIND "MODEM Interrupt Disable Time = 500 us (9600 bd)" $(ARTIFACTS)\T1712.LOG > NUL
   FIND "Full Duplex = enabled" $(ARTIFACTS)\T1712.LOG > NUL
   FIND "Optimization = Server" $(ARTIFACTS)\T1712.LOG > NUL
   FIND "Boot ROM = 8K at C8000H" $(ARTIFACTS)\T1712.LOG > NUL

t1713:
   @echo [t1713] Testing /TR verification chain with /VERBOSE on 3C509B-Combo... >> TEST.LOG
   ${SEEDAPP} 3C509B-COMBO > $(ARTIFACTS)\T1713.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:TP /VERBOSE >> $(ARTIFACTS)\T1713.LOG
   FIND "EEPROM transceiver selection verified." $(ARTIFACTS)\T1713.LOG > NUL
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1713.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:AUI /VERBOSE >> $(ARTIFACTS)\T1713.LOG
   FIND "EEPROM transceiver selection verified." $(ARTIFACTS)\T1713.LOG > NUL
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1713.LOG > NUL
   ${SEEDAPP} INIT >> $(ARTIFACTS)\T1713.LOG

t1714:
   @echo [t1714] Testing unchanged /TR with /VERBOSE on 3C509B-TP... >> TEST.LOG
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1714.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:TP /VERBOSE >> $(ARTIFACTS)\T1714.LOG
   FIND "Transceiver type is already configured to the requested value." $(ARTIFACTS)\T1714.LOG > NUL
