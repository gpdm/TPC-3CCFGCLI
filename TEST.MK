# Borland MAKE test orchestration for 3CCFG project
# Usage:
#   MAKE -f TEST.MK test
#   MAKE -f TEST.MK smoke
#
# NOTE:
# Test IDs are stable. Gaps are intentional where obsolete or redundant
# regression cases have been removed; do not renumber remaining tests.

LOGS = LOGS\TEST
ARTIFACTS = $(LOGS)\ARTIFACT
TESTLOG = $(LOGS)\TEST.LOG
BINAPP = BIN\3CHWMOCK.EXE
SEEDAPP = BIN\3CSEED.EXE
ASSERTERS = ASSERTRS

# Aliases
all: smoke
test: smoke

smoke: prep smoke-core
   @echo Smoke test: run completed  >> $(TESTLOG)
   @echo Smoke test: run completed

smoke-core: LISTING IRQ_CHANGE IOBASE_CHANGE PNP_CHANGE MODEM_CHANGE FD_CHANGE OPTIMIZE_CHANGE BOOTROM_CHANGE XCVR_CHANGE CLI_PARSER COMBINED_TRANSACTIONS MULTI_NIC SAVECONFIG_TEST VERIFICATION_CONTROL_FLOW 3C509_REV1 cleanup

prep:
   # TEST.MK deliberately does not clear $(TESTLOG) - this is handled by test.sh
   @if not exist $(LOGS)\NUL mkdir $(LOGS)
   @if not exist $(ARTIFACTS)\NUL mkdir $(ARTIFACTS)
   @if exist $(ARTIFACTS)\*.LOG del $(ARTIFACTS)\*.LOG
   @if exist $(ARTIFACTS)\*.BAT del $(ARTIFACTS)\*.BAT

cleanup:
   @echo Cleaning seed file  >> $(TESTLOG)
   $(SEEDAPP) CLEAR  >> $(TESTLOG)
   @echo Smoke test complete.  >> $(TESTLOG)

clean-test:
   # TEST.MK deliberately does not clear $(TESTLOG) - this is handled by test.sh
   @if exist $(ARTIFACTS)\*.LOG del $(ARTIFACTS)\*.LOG
   @if exist $(ARTIFACTS)\*.BAT del $(ARTIFACTS)\*.BAT

# Symbolic Test Groups
# ####################

# Base: 0100
LISTING: t01xx t0101 t0102

# Base: 0200
IRQ_CHANGE: t02xx t0201 t0202 t0203 t0204 t0205

# Base: 0400
IOBASE_CHANGE: t04xx t0401 t0402 t0403 t0404 t0406 t0408 t0409

# Base: 0500
PNP_CHANGE: t05xx t0501 t0502 t0505

# Base: 0600
MODEM_CHANGE: t06xx t0601 t0602 t0603 t0604 t0605 t0607 t0608 t0609 t0610

# Base: 0700
FD_CHANGE: t07xx t0701 t0702 t0703 t0705 t0706 t0707 t0708 t0710 t0711 t0714

# Base: 0900
OPTIMIZE_CHANGE: t09xx t0901 t0902 t0903 t0904 t0905

# Base: 1100
BOOTROM_CHANGE: t11xx t1101 t1102 t1103 t1104 t1105 t1106 t1107 t1108 t1109 t1110 t1111 t1112 t1113 t1114 t1115 t1116 t1117 t1118 t1119 t1120 t1122 t1126 t1127 t1128 t1129 t1130 t1131 t1132 t1133 t1134 t1135 t1136

# Base: 1200
XCVR_CHANGE: t12xx t1201 t1202 t1203 t1204 t1205 t1207 t1208 t1209 t1210 t1211

# Base: 1300
CLI_PARSER: t13xx t1301 t1302 t1303 t1304 t1305 t1306 t1307 t1308 t1309 t1310 t1311

# Base: 1400
COMBINED_TRANSACTIONS: t14xx t1401 t1402 t1403 t1405 t1406 t1407

# Base: 1500
MULTI_NIC: t15xx t1502 t1503 t1504 t1505

# Base: 1600
SAVECONFIG_TEST: t16xx t1602 t1603 t1606 t1607 t1608 t1609 t1610 t1611 t1612 t1613 t1614 t1615 t1616 t1617 t1618 t1619 t1620 t1621 t1622 t1623 t1624 t1625 t1626

# Base: 1700
VERIFICATION_CONTROL_FLOW: t17xx t1701 t1702 t1703 t1704 t1705 t1706 t1707 t1708 t1710 t1713 t1714

# Base: 1800
3C509_REV1: t18xx t1801 t1802 t1803 t1804 t1805 t1806 t1807 t1808


# Test Case Definitions
# #####################

t01xx:
   @echo [t01xx] LISTING: Verify general card listing behaviour  >> $(TESTLOG)

t0101:
   @echo [t0101] Clearing seed and checking no-card case  >> $(TESTLOG)
   $(SEEDAPP) CLEAR  >> $(TESTLOG)
   $(BINAPP) LIST > $(ARTIFACTS)\T0101.LOG
   FIND "No EtherLink III NICs are installed in this computer." $(ARTIFACTS)\T0101.LOG > NUL
   @echo [t0101] PASSED  >> $(TESTLOG)

t0102:
   @echo [t0102] Seeding INIT profile and checking card listing  >> $(TESTLOG)
   $(SEEDAPP) INIT  >> $(TESTLOG)
   $(BINAPP) LIST > $(ARTIFACTS)\T0102.LOG
   FIND "NIC                            NIC" $(ARTIFACTS)\T0102.LOG > NUL
   FIND "Number                       Description" $(ARTIFACTS)\T0102.LOG > NUL
   FIND "(ASIC Revision 2)" $(ARTIFACTS)\T0102.LOG > NUL
   FIND "Connectors = TP, AUI" $(ARTIFACTS)\T0102.LOG > NUL
   FIND "Full Duplex Capability = yes" $(ARTIFACTS)\T0102.LOG > NUL
   FIND "Plug and Play Capability = yes" $(ARTIFACTS)\T0102.LOG > NUL
   FIND "Plug and Play = enabled" $(ARTIFACTS)\T0102.LOG > NUL
   @echo [t0102] PASSED  >> $(TESTLOG)

t02xx:
   @echo [t02xx] IRQ_CHANGE: Verify IRQ change behaviour  >> $(TESTLOG)

t0201:
   @echo [t0201] CONFIGURE /INT invalid out-of-range value  >> $(TESTLOG)
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /INT:21 > $(ARTIFACTS)\T0201.LOG
   FIND "Invalid /INT parameter." $(ARTIFACTS)\T0201.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0201.LOG
   FIND "IRQ = 10" $(ARTIFACTS)\T0201.LOG > NUL
   @echo [t0201] PASSED  >> $(TESTLOG)

t0202:
   @echo [t0202] CONFIGURE /INT invalid input  >> $(TESTLOG)
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /INT:BADVALUE > $(ARTIFACTS)\T0202.LOG
   FIND "Invalid /INT parameter." $(ARTIFACTS)\T0202.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0202.LOG
   FIND "IRQ = 10" $(ARTIFACTS)\T0202.LOG > NUL
   @echo [t0202] PASSED  >> $(TESTLOG)

t0203:
   @echo [t0203] CONFIGURE /INT transition to 5  >> $(TESTLOG)
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /INT:5 > $(ARTIFACTS)\T0203.LOG
   FIND "INT parameter accepted. Requested IRQ: 5" $(ARTIFACTS)\T0203.LOG > NUL
   FIND "IRQ configuration completed successfully." $(ARTIFACTS)\T0203.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0203.LOG
   FIND "IRQ = 5" $(ARTIFACTS)\T0203.LOG > NUL
   @echo [t0203] PASSED  >> $(TESTLOG)

t0204:
   @echo [t0204] CONFIGURE /INT transition back to 9  >> $(TESTLOG)
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /INT:9 > $(ARTIFACTS)\T0204.LOG
   FIND "INT parameter accepted. Requested IRQ: 9" $(ARTIFACTS)\T0204.LOG > NUL
   FIND "IRQ configuration completed successfully." $(ARTIFACTS)\T0204.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0204.LOG
   FIND "IRQ = 9" $(ARTIFACTS)\T0204.LOG > NUL
   @echo [t0204] PASSED  >> $(TESTLOG)

t0205:
   @echo [t0205] CONFIGURE single adapter fallback when /ADAPTERNUM is omitted  >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T0205.LOG
   $(BINAPP) CONFIGURE /INT:5 >> $(ARTIFACTS)\T0205.LOG
   FIND "INT parameter accepted. Requested IRQ: 5" $(ARTIFACTS)\T0205.LOG > NUL
   FIND "IRQ configuration completed successfully." $(ARTIFACTS)\T0205.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0205.LOG
   FIND "IRQ = 5" $(ARTIFACTS)\T0205.LOG > NUL
   @echo [t0205] PASSED  >> $(TESTLOG)

t04xx:
   @echo [t04xx] IOBASE_CHANGE: Verify IO base change behaviour  >> $(TESTLOG)

t0401:
   @echo [t0401] CONFIGURE /IOBASE invalid out-of-range high value  >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T0401.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /IOBASE:03F0 >> $(ARTIFACTS)\T0401.LOG
   FIND "Invalid /IOBASE parameter. Use hexadecimal 0200 through 03E0 in 10h increments." $(ARTIFACTS)\T0401.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0401.LOG
   FIND "IOBASE = 0300" $(ARTIFACTS)\T0401.LOG > NUL
   @echo [t0401] PASSED  >> $(TESTLOG)

t0402:
   @echo [t0402] CONFIGURE /IOBASE invalid out-of-range low value  >> $(TESTLOG)
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /IOBASE:01F0 > $(ARTIFACTS)\T0402.LOG
   FIND "Invalid /IOBASE parameter. Use hexadecimal 0200 through 03E0 in 10h increments." $(ARTIFACTS)\T0402.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0402.LOG
   FIND "IOBASE = 0300" $(ARTIFACTS)\T0402.LOG > NUL
   @echo [t0402] PASSED  >> $(TESTLOG)

t0403:
   @echo [t0403] CONFIGURE /IOBASE arbitrary invalid input  >> $(TESTLOG)
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /IOBASE:BADVALUE > $(ARTIFACTS)\T0403.LOG
   FIND "Invalid /IOBASE parameter. Use hexadecimal 0200 through 03E0 in 10h increments." $(ARTIFACTS)\T0403.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0403.LOG
   FIND "IOBASE = 0300" $(ARTIFACTS)\T0403.LOG > NUL
   @echo [t0403] PASSED  >> $(TESTLOG)

t0404:
   @echo [t0404] CONFIGURE /IOBASE transition to 0280 (long notation)  >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T0404.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /IOBASE:0280 >> $(ARTIFACTS)\T0404.LOG
   FIND "IOBASE parameter accepted. Requested IOBASE: 0280" $(ARTIFACTS)\T0404.LOG > NUL
   FIND "IOBASE configuration completed successfully." $(ARTIFACTS)\T0404.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0404.LOG
   FIND "IOBASE = 0280" $(ARTIFACTS)\T0404.LOG > NUL
   @echo [t0404] PASSED  >> $(TESTLOG)

t0406:
   @echo [t0406] CONFIGURE /IOBASE transition to 280 (short notation)  >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T0406.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /IOBASE:280 >> $(ARTIFACTS)\T0406.LOG
   FIND "IOBASE parameter accepted. Requested IOBASE: 0280" $(ARTIFACTS)\T0406.LOG > NUL
   FIND "IOBASE configuration completed successfully." $(ARTIFACTS)\T0406.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0406.LOG
   FIND "IOBASE = 0280" $(ARTIFACTS)\T0406.LOG > NUL
   @echo [t0406] PASSED  >> $(TESTLOG)

t0408:
   @echo [t0408] CONFIGURE /IOBASE minimum valid address 0200  >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T0408.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /IOBASE:0200 >> $(ARTIFACTS)\T0408.LOG
   FIND "IOBASE parameter accepted. Requested IOBASE: 0200" $(ARTIFACTS)\T0408.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0408.LOG
   FIND "IOBASE = 0200" $(ARTIFACTS)\T0408.LOG > NUL
   @echo [t0408] PASSED  >> $(TESTLOG)

t0409:
   @echo [t0409] CONFIGURE /IOBASE maximum valid address 03E0  >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T0409.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /IOBASE:03E0 >> $(ARTIFACTS)\T0409.LOG
   FIND "IOBASE parameter accepted. Requested IOBASE: 03E0" $(ARTIFACTS)\T0409.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0409.LOG
   FIND "IOBASE = 03E0" $(ARTIFACTS)\T0409.LOG > NUL
   @echo [t0409] PASSED  >> $(TESTLOG)

t05xx:
   @echo [t05xx] PNP_CHANGE: Verify PNP property change behaviour  >> $(TESTLOG)

t0501:
   @echo [t0501] CONFIGURE /PNP transition to disabled  >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T0501.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /PNP:DISABLED /VERBOSE >> $(ARTIFACTS)\T0501.LOG
   FIND "PNP parameter accepted. Requested Plug and Play mode: disabled" $(ARTIFACTS)\T0501.LOG > NUL
   FIND "Plug and Play configuration word written." $(ARTIFACTS)\T0501.LOG > NUL
   FIND "Updating EEPROM checksum" $(ARTIFACTS)\T0501.LOG > NUL
   FIND "EEPROM checksum updated." $(ARTIFACTS)\T0501.LOG > NUL
   FIND "Plug and Play configuration completed successfully." $(ARTIFACTS)\T0501.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0501.LOG
   FIND "Plug and Play Capability = yes" $(ARTIFACTS)\T0501.LOG > NUL
   FIND "Plug and Play = disabled" $(ARTIFACTS)\T0501.LOG > NUL
   @echo [t0501] PASSED  >> $(TESTLOG)

t0502:
   @echo [t0502] CONFIGURE /PNP transition back to enabled  >> $(TESTLOG)
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /PNP:ENABLED /VERBOSE > $(ARTIFACTS)\T0502.LOG
   FIND "PNP parameter accepted. Requested Plug and Play mode: enabled" $(ARTIFACTS)\T0502.LOG > NUL
   FIND "Plug and Play configuration completed successfully." $(ARTIFACTS)\T0502.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /PNP:ENABLED /VERBOSE >> $(ARTIFACTS)\T0502.LOG
   FIND "Plug and Play mode is already configured to the requested value." $(ARTIFACTS)\T0502.LOG > NUL
   FIND "No hardware changes required." $(ARTIFACTS)\T0502.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0502.LOG
   FIND "Plug and Play Capability = yes" $(ARTIFACTS)\T0502.LOG > NUL
   FIND "Plug and Play = enabled" $(ARTIFACTS)\T0502.LOG > NUL
   @echo [t0502] PASSED  >> $(TESTLOG)

t0505:
   @echo [t0505] CONFIGURE /PNP arbitrary invalid input  >> $(TESTLOG)
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /PNP:OTHERINVALIDINPUT > $(ARTIFACTS)\T0505.LOG
   FIND "Invalid /PNP parameter. Use ENABLED or DISABLED." $(ARTIFACTS)\T0505.LOG > NUL
   @echo [t0505] PASSED  >> $(TESTLOG)

t06xx:
   @echo [t06xx] MODEM_CHANGE: Verify MODEM property change behaviour  >> $(TESTLOG)

t0601:
   @echo [t0601] CONFIGURE /MODEM transition to 1200  >> $(TESTLOG)
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:1200 > $(ARTIFACTS)\T0601.LOG
   FIND "MODEM parameter accepted. Requested setting: 1200" $(ARTIFACTS)\T0601.LOG > NUL
   FIND "Modem speed configuration completed successfully." $(ARTIFACTS)\T0601.LOG > NUL
   @echo [t0601] PASSED  >> $(TESTLOG)

t0602:
   @echo [t0602] CONFIGURE /MODEM unchanged transition at 1200  >> $(TESTLOG)
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:1200 /VERBOSE > $(ARTIFACTS)\T0602.LOG
   FIND "MODEM parameter accepted. Requested setting: 1200" $(ARTIFACTS)\T0602.LOG > NUL
   FIND "Modem speed setting is already configured to the requested value." $(ARTIFACTS)\T0602.LOG > NUL
   @echo [t0602] PASSED  >> $(TESTLOG)

t0603:
   @echo [t0603] CONFIGURE /MODEM transition to NONE  >> $(TESTLOG)
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:NONE > $(ARTIFACTS)\T0603.LOG
   FIND "MODEM parameter accepted. Requested setting: none" $(ARTIFACTS)\T0603.LOG > NUL
   FIND "Modem speed configuration completed successfully." $(ARTIFACTS)\T0603.LOG > NUL
   @echo [t0603] PASSED  >> $(TESTLOG)

t0604:
   @echo [t0604] CONFIGURE /MODEM invalid symbolic input  >> $(TESTLOG)
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:FALSE > $(ARTIFACTS)\T0604.LOG
   FIND "Invalid /MODEM parameter." $(ARTIFACTS)\T0604.LOG > NUL
   @echo [t0604] PASSED  >> $(TESTLOG)

t0605:
   @echo [t0605] CONFIGURE /MODEM invalid out-of-range step value  >> $(TESTLOG)
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:26 > $(ARTIFACTS)\T0605.LOG
   FIND "Invalid /MODEM parameter." $(ARTIFACTS)\T0605.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:NONE /VERBOSE >> $(ARTIFACTS)\T0605.LOG
   FIND "Modem speed setting is already configured to the requested value." $(ARTIFACTS)\T0605.LOG > NUL
   @echo [t0605] PASSED  >> $(TESTLOG)

t0607:
   @echo [t0607] LIST MODEM interrupt-disable timing readout  >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T0607.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:9600 >> $(ARTIFACTS)\T0607.LOG
   $(BINAPP) LIST >> $(ARTIFACTS)\T0607.LOG
   FIND "MODEM Interrupt Disable Time = 500 us (9600 bd)" $(ARTIFACTS)\T0607.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:NONE >> $(ARTIFACTS)\T0607.LOG
   $(BINAPP) LIST >> $(ARTIFACTS)\T0607.LOG
   FIND "MODEM Interrupt Disable Time = 1600 us (NONE)" $(ARTIFACTS)\T0607.LOG > NUL
   @echo [t0607] PASSED  >> $(TESTLOG)

t0608:
   @echo [t0608] /MODEM:25 preserves all non-MODEM word 0Dh fields  >> $(TESTLOG)
   ${SEEDAPP} INIT /MODEMPRESERVE > $(ARTIFACTS)\T0608.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:25 /VERBOSE >> $(ARTIFACTS)\T0608.LOG
   FIND "Current EEPROM word 0Dh: 73FF" $(ARTIFACTS)\T0608.LOG > NUL
   FIND "New EEPROM word 0Dh: 40FF" $(ARTIFACTS)\T0608.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0608.LOG
   FIND "Optimization = Server" $(ARTIFACTS)\T0608.LOG > NUL
   @echo [t0608] PASSED  >> $(TESTLOG)

t0609:
   @echo [t0609] /MODEM:1600 upper-bound field encoding  >> $(TESTLOG)
   ${SEEDAPP} INIT /MODEMPRESERVE > $(ARTIFACTS)\T0609.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:1600 /VERBOSE >> $(ARTIFACTS)\T0609.LOG
   FIND "Current EEPROM word 0Dh: 73FF" $(ARTIFACTS)\T0609.LOG > NUL
   FIND "New EEPROM word 0Dh: 7FFF" $(ARTIFACTS)\T0609.LOG > NUL
   @echo [t0609] PASSED  >> $(TESTLOG)


# All five named baud values are retained intentionally: CONFIGURE encoding and
# SAVECONFIG/LIST alias decoding use explicit per-value mappings. Raw 1200 us is
# a separate valid EEPROM value that cannot be represented directly by the CLI.
t0610:
   @echo [t0610] MODEM Interrupt Disable Time and SAVECONFIG serialization  >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T0610.LOG
   $(BINAPP) LIST >> $(ARTIFACTS)\T0610.LOG
   FIND "MODEM Interrupt Disable Time = 25 us" $(ARTIFACTS)\T0610.LOG > NUL
   $(BINAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\M25.BAT /EXECFILE:$(BINAPP) >> $(ARTIFACTS)\T0610.LOG
   FIND "MODEM:25" $(ARTIFACTS)\M25.BAT > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:38400 /VERBOSE >> $(ARTIFACTS)\T0610.LOG
   FIND "New EEPROM word 0Dh: 0410" $(ARTIFACTS)\T0610.LOG > NUL
   $(BINAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\M384.BAT /EXECFILE:$(BINAPP) >> $(ARTIFACTS)\T0610.LOG
   FIND "MODEM:38400" $(ARTIFACTS)\M384.BAT > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0610.LOG
   FIND "MODEM Interrupt Disable Time = 125 us (38400 bd)" $(ARTIFACTS)\T0610.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:19200 /VERBOSE >> $(ARTIFACTS)\T0610.LOG
   FIND "New EEPROM word 0Dh: 0910" $(ARTIFACTS)\T0610.LOG > NUL
   $(BINAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\M192.BAT /EXECFILE:$(BINAPP) >> $(ARTIFACTS)\T0610.LOG
   FIND "MODEM:19200" $(ARTIFACTS)\M192.BAT > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0610.LOG
   FIND "MODEM Interrupt Disable Time = 250 us (19200 bd)" $(ARTIFACTS)\T0610.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:9600 /VERBOSE >> $(ARTIFACTS)\T0610.LOG
   FIND "New EEPROM word 0Dh: 1310" $(ARTIFACTS)\T0610.LOG > NUL
   $(BINAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\M96.BAT /EXECFILE:$(BINAPP) >> $(ARTIFACTS)\T0610.LOG
   FIND "MODEM:9600" $(ARTIFACTS)\M96.BAT > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:2400 /VERBOSE >> $(ARTIFACTS)\T0610.LOG
   FIND "New EEPROM word 0Dh: 2710" $(ARTIFACTS)\T0610.LOG > NUL
   $(BINAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\M24.BAT /EXECFILE:$(BINAPP) >> $(ARTIFACTS)\T0610.LOG
   FIND "MODEM:2400" $(ARTIFACTS)\M24.BAT > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0610.LOG
   FIND "MODEM Interrupt Disable Time = 1000 us (2400 bd)" $(ARTIFACTS)\T0610.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:1200 /VERBOSE >> $(ARTIFACTS)\T0610.LOG
   FIND "New EEPROM word 0Dh: 3310" $(ARTIFACTS)\T0610.LOG > NUL
   $(BINAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\M12.BAT /EXECFILE:$(BINAPP) >> $(ARTIFACTS)\T0610.LOG
   FIND "MODEM:1200" $(ARTIFACTS)\M12.BAT > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0610.LOG
   FIND "MODEM Interrupt Disable Time = 1300 us (1200 bd)" $(ARTIFACTS)\T0610.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:NONE /VERBOSE >> $(ARTIFACTS)\T0610.LOG
   FIND "New EEPROM word 0Dh: 3F10" $(ARTIFACTS)\T0610.LOG > NUL
   $(BINAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\MNONE.BAT /EXECFILE:$(BINAPP) >> $(ARTIFACTS)\T0610.LOG
   FIND "MODEM:NONE" $(ARTIFACTS)\MNONE.BAT > NUL
   ${SEEDAPP} INIT /M1200US >> $(ARTIFACTS)\T0610.LOG
   $(BINAPP) LIST >> $(ARTIFACTS)\T0610.LOG
   FIND "MODEM Interrupt Disable Time = 1200 us (not representable by CLI)" $(ARTIFACTS)\T0610.LOG > NUL
   $(BINAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\M1200U.BAT >> $(ARTIFACTS)\T0610.LOG
   FIND "MODEM:NONE" $(ARTIFACTS)\M1200U.BAT > NUL
   @echo [t0610] PASSED  >> $(TESTLOG)

t07xx:
   @echo [t07xx] FD_CHANGE: Verify FULLDUPLEX property behaviour  >> $(TESTLOG)

t0701:
   @echo [t0701] CONFIGURE /FULLDUPLEX transition to enabled  >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T0701.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:ENABLED /VERBOSE >> $(ARTIFACTS)\T0701.LOG
   FIND "FULLDUPLEX parameter accepted. Requested mode: enabled" $(ARTIFACTS)\T0701.LOG > NUL
   FIND "Full duplex configuration completed successfully." $(ARTIFACTS)\T0701.LOG > NUL
   FIND "Live Network Diagnostic full duplex mode verified." $(ARTIFACTS)\T0701.LOG > NUL
   @echo [t0701] PASSED  >> $(TESTLOG)

t0702:
   @echo [t0702] CONFIGURE /FULLDUPLEX unchanged transition at enabled  >> $(TESTLOG)
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:ENABLED /VERBOSE > $(ARTIFACTS)\T0702.LOG
   FIND "FULLDUPLEX parameter accepted. Requested mode: enabled" $(ARTIFACTS)\T0702.LOG > NUL
   FIND "Full duplex mode is already configured to the requested value." $(ARTIFACTS)\T0702.LOG > NUL
   FIND "Live Network Diagnostic full duplex mode verified." $(ARTIFACTS)\T0702.LOG > NUL
   @echo [t0702] PASSED  >> $(TESTLOG)

t0703:
   @echo [t0703] CONFIGURE /FULLDUPLEX transition to disabled  >> $(TESTLOG)
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:DISABLED /VERBOSE > $(ARTIFACTS)\T0703.LOG
   FIND "FULLDUPLEX parameter accepted. Requested mode: disabled" $(ARTIFACTS)\T0703.LOG > NUL
   FIND "Full duplex configuration completed successfully." $(ARTIFACTS)\T0703.LOG > NUL
   FIND "Live Network Diagnostic full duplex mode verified." $(ARTIFACTS)\T0703.LOG > NUL
   @echo [t0703] PASSED  >> $(TESTLOG)

t0705:
   @echo [t0705] CONFIGURE /FULLDUPLEX invalid symbolic input  >> $(TESTLOG)
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:TRUE > $(ARTIFACTS)\T0705.LOG
   FIND "Invalid /FULLDUPLEX parameter. Use ENABLED or DISABLED." $(ARTIFACTS)\T0705.LOG > NUL
   @echo [t0705] PASSED  >> $(TESTLOG)

t0706:
   @echo [t0706] LIST Full Duplex readout for enabled and disabled  >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T0706.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:ENABLED >> $(ARTIFACTS)\T0706.LOG
   $(BINAPP) LIST >> $(ARTIFACTS)\T0706.LOG
   FIND "Full Duplex = enabled" $(ARTIFACTS)\T0706.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:DISABLED >> $(ARTIFACTS)\T0706.LOG
   $(BINAPP) LIST >> $(ARTIFACTS)\T0706.LOG
   FIND "Full Duplex = disabled" $(ARTIFACTS)\T0706.LOG > NUL
   @echo [t0706] PASSED  >> $(TESTLOG)

t0707:
   @echo [t0707] Full Duplex capability and rejection on 3C509B-COAX  >> $(TESTLOG)
   ${SEEDAPP} 3C509B-COAX > $(ARTIFACTS)\T0707.LOG
   $(BINAPP) LIST >> $(ARTIFACTS)\T0707.LOG
   FIND "Connectors = AUI, COAX" $(ARTIFACTS)\T0707.LOG > NUL
   FIND "Full Duplex Capability = no" $(ARTIFACTS)\T0707.LOG > NUL
   FIND "Full Duplex = not supported" $(ARTIFACTS)\T0707.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:ENABLED >> $(ARTIFACTS)\T0707.LOG
   FIND "This adapter does not support full duplex configuration." $(ARTIFACTS)\T0707.LOG > NUL
   @echo [t0707] PASSED  >> $(TESTLOG)

t0708:
   @echo [t0708] Full Duplex enable rejects effective AUI and permits disable  >> $(TESTLOG)
   ${SEEDAPP} 3C509B-TP > $(ARTIFACTS)\T0708.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:AUI >> $(ARTIFACTS)\T0708.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:ENABLED >> $(ARTIFACTS)\T0708.LOG
   FIND "Full duplex can only be enabled with the TP transceiver." $(ARTIFACTS)\T0708.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:DISABLED >> $(ARTIFACTS)\T0708.LOG
   FIND "Full duplex configuration completed successfully." $(ARTIFACTS)\T0708.LOG > NUL
   @echo [t0708] PASSED  >> $(TESTLOG)

t0710:
   @echo [t0710] Full Duplex enable rejects effective AUTO >> $(TESTLOG)
   ${SEEDAPP} 3C509B-TP > $(ARTIFACTS)\T0710.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:AUTO >> $(ARTIFACTS)\T0710.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:ENABLED >> $(ARTIFACTS)\T0710.LOG
   FIND "Full duplex can only be enabled with the TP transceiver." $(ARTIFACTS)\T0710.LOG > NUL
   @echo [t0710] PASSED  >> $(TESTLOG)

t0711:
   @echo [t0711] atomicity of combined AUI and Full Duplex rejection >> $(TESTLOG)
   ${SEEDAPP} 3C509B-TP > $(ARTIFACTS)\T0711.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:AUI /FULLDUPLEX:ENABLED >> $(ARTIFACTS)\T0711.LOG
   FIND "Full duplex can only be enabled with the TP transceiver." $(ARTIFACTS)\T0711.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0711.LOG
   FIND "Transceiver = on-board TP" $(ARTIFACTS)\T0711.LOG > NUL
   FIND "Full Duplex = disabled" $(ARTIFACTS)\T0711.LOG > NUL
   @echo [t0711] PASSED  >> $(TESTLOG)

# Full Duplex requires effective TP. A standalone change to AUI must therefore
# fail without changing state; AUI+FULLDUPLEX:DISABLED is valid because the
# combined prospective final state no longer has Full Duplex enabled.
t0714:
   @echo [t0714] reverse Full Duplex dependency preserves TP state >> $(TESTLOG)
   ${SEEDAPP} 3C509B-TP > $(ARTIFACTS)\T0714.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:ENABLED >> $(ARTIFACTS)\T0714.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:AUI >> $(ARTIFACTS)\T0714.LOG
   FIND "Full duplex can only be enabled with the TP transceiver." $(ARTIFACTS)\T0714.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0714.LOG
   FIND "Transceiver = on-board TP" $(ARTIFACTS)\T0714.LOG > NUL
   FIND "Full Duplex = enabled" $(ARTIFACTS)\T0714.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:AUI /FULLDUPLEX:DISABLED >> $(ARTIFACTS)\T0714.LOG
   FIND "Configuration completed successfully." $(ARTIFACTS)\T0714.LOG > NUL
   @echo [t0714] PASSED  >> $(TESTLOG)

t09xx:
   @echo [t09xx] OPTIMIZE_CHANGE: Verify Workload Optimization change behaviour  >> $(TESTLOG)

t0901:
   @echo [t0901] CONFIGURE /OPTIMIZE transition to OS/2 >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T0901.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /OPTIMIZE:OS/2 /VERBOSE >> $(ARTIFACTS)\T0901.LOG
   FIND "New EEPROM word 0Dh: Windows or OS/2" $(ARTIFACTS)\T0901.LOG > NUL
   FIND "Configuration completed successfully." $(ARTIFACTS)\T0901.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0901.LOG
   FIND "Optimization = Windows or OS/2" $(ARTIFACTS)\T0901.LOG > NUL
   @echo [t0901] PASSED  >> $(TESTLOG)

t0902:
   @echo [t0902] CONFIGURE /OPTIMIZE invalid symbolic input >> $(TESTLOG)
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /OPTIMIZE:TRUE > $(ARTIFACTS)\T0902.LOG
   FIND "Invalid /OPTIMIZE parameter. Use DOS, WINDOWS, OS/2, or SERVER." $(ARTIFACTS)\T0902.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0902.LOG
   FIND "Optimization = Windows or OS/2" $(ARTIFACTS)\T0902.LOG > NUL
   @echo [t0902] PASSED  >> $(TESTLOG)

t0903:
   @echo [t0903] CONFIGURE /OPTIMIZE transition to SERVER >> $(TESTLOG)
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /OPTIMIZE:SERVER > $(ARTIFACTS)\T0903.LOG
   FIND "Configuration completed successfully." $(ARTIFACTS)\T0903.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0903.LOG
   FIND "Optimization = Server" $(ARTIFACTS)\T0903.LOG > NUL
   @echo [t0903] PASSED  >> $(TESTLOG)

t0904:
   @echo [t0904] CONFIGURE /OPTIMIZE transition to DOS >> $(TESTLOG)
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /OPTIMIZE:DOS >> $(ARTIFACTS)\T0904.LOG
   FIND "Configuration completed successfully." $(ARTIFACTS)\T0904.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T0904.LOG
   FIND "Optimization = DOS" $(ARTIFACTS)\T0904.LOG > NUL
   @echo [t0904] PASSED  >> $(TESTLOG)

t0905:
   @echo [t0905] unchanged CONFIGURE /OPTIMIZE:SERVER >> $(TESTLOG)
   ${SEEDAPP} INIT > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /OPTIMIZE:SERVER > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /OPTIMIZE:SERVER /VERBOSE > $(ARTIFACTS)\T0905.LOG
   FIND "Optimize mode is already configured to the requested value." $(ARTIFACTS)\T0905.LOG > NUL
   FIND "No hardware changes required." $(ARTIFACTS)\T0905.LOG > NUL
   @echo [t0905] PASSED  >> $(TESTLOG)

t11xx:
   @echo [t11xx] BOOTROM_CHANGE: Verify boot ROM change behaviour  >> $(TESTLOG)

t1101:
   @echo [t1101] CONFIGURE /BADDRESS minimum valid address with /BSIZE:16 >> $(TESTLOG)
   ${SEEDAPP} INIT /ROM16K > $(ARTIFACTS)\T1101.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:C0000 /BSIZE:16 > $(ARTIFACTS)\T1101.LOG
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1101.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1101.LOG
   FIND "Boot ROM = 16K at C0000H" $(ARTIFACTS)\T1101.LOG > NUL
   @echo [t1101] PASSED  >> $(TESTLOG)

t1102:
   @echo [t1102] CONFIGURE /BSIZE then /BADDRESS ordering >> $(TESTLOG)
   ${SEEDAPP} INIT /ROM16K > $(ARTIFACTS)\T1102.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /BSIZE:16 /BADDRESS:C0000 > $(ARTIFACTS)\T1102.LOG
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1102.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1102.LOG
   FIND "Boot ROM = 16K at C0000H" $(ARTIFACTS)\T1102.LOG > NUL
   @echo [t1102] PASSED  >> $(TESTLOG)

t1103:
   @echo [t1103] CONFIGURE /BADDRESS+/BSIZE reconfigure to a new pair >> $(TESTLOG)
   ${SEEDAPP} INIT /ROM32K > $(ARTIFACTS)\T1103.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:D0000 /BSIZE:32 > $(ARTIFACTS)\T1103.LOG
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1103.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1103.LOG
   FIND "Boot ROM = 32K at D0000H" $(ARTIFACTS)\T1103.LOG > NUL
   @echo [t1103] PASSED  >> $(TESTLOG)

t1104:
   @echo [t1104] /BSIZE:DISABLED succeeds without a detected Boot ROM >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1104.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /BSIZE:DISABLED > $(ARTIFACTS)\T1104.LOG
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1104.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1104.LOG
   FIND "Boot ROM = disabled" $(ARTIFACTS)\T1104.LOG > NUL
   @echo [t1104] PASSED  >> $(TESTLOG)

t1105:
   @echo [t1105] CONFIGURE /BADDRESS out-of-range address >> $(TESTLOG)
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:E0000 /BSIZE:16 > $(ARTIFACTS)\T1105.LOG
   FIND "Invalid /BADDRESS parameter. Use a hex address C0000-DE000 in 2000h steps." $(ARTIFACTS)\T1105.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1105.LOG
   FIND "Boot ROM = disabled" $(ARTIFACTS)\T1105.LOG > NUL
   @echo [t1105] PASSED  >> $(TESTLOG)

t1106:
   @echo [t1106] CONFIGURE /BADDRESS non-aligned address >> $(TESTLOG)
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:C1000 /BSIZE:16 > $(ARTIFACTS)\T1106.LOG
   FIND "Invalid /BADDRESS parameter. Use a hex address C0000-DE000 in 2000h steps." $(ARTIFACTS)\T1106.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1106.LOG
   FIND "Boot ROM = disabled" $(ARTIFACTS)\T1106.LOG > NUL
   @echo [t1106] PASSED  >> $(TESTLOG)

t1107:
   @echo [t1107] CONFIGURE /BSIZE invalid value >> $(TESTLOG)
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:C8000 /BSIZE:64 > $(ARTIFACTS)\T1107.LOG
   FIND "Invalid /BSIZE parameter. Use 8, 16, 32, or DISABLED." $(ARTIFACTS)\T1107.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1107.LOG
   FIND "Boot ROM = disabled" $(ARTIFACTS)\T1107.LOG > NUL
   @echo [t1107] PASSED  >> $(TESTLOG)

t1108:
   @echo [t1108] CONFIGURE /BSIZE alone (real size) is rejected (pairing rule) >> $(TESTLOG)
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /BSIZE:16 > $(ARTIFACTS)\T1108.LOG
   FIND "BADDRESS and /BSIZE must be specified together" $(ARTIFACTS)\T1108.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1108.LOG
   FIND "Boot ROM = disabled" $(ARTIFACTS)\T1108.LOG > NUL
   @echo [t1108] PASSED  >> $(TESTLOG)

t1109:
   @echo [t1109] CONFIGURE /BADDRESS alone is rejected (pairing rule) >> $(TESTLOG)
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:C8000 > $(ARTIFACTS)\T1109.LOG
   FIND "BADDRESS and /BSIZE must be specified together" $(ARTIFACTS)\T1109.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1109.LOG
   FIND "Boot ROM = disabled" $(ARTIFACTS)\T1109.LOG > NUL
   @echo [t1109] PASSED  >> $(TESTLOG)

t1110:
   @echo [t1110] /BADDRESS combined with /BSIZE:DISABLED is rejected >> $(TESTLOG)
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:C8000 /BSIZE:DISABLED > $(ARTIFACTS)\T1110.LOG
   FIND "BADDRESS and /BSIZE must be specified together" $(ARTIFACTS)\T1110.LOG > NUL
   @echo [t1110] PASSED  >> $(TESTLOG)

t1111:
   @echo [t1111] Boot ROM capability gate: 3C509B-TPO rejects /BADDRESS+/BSIZE >> $(TESTLOG)
   ${SEEDAPP} 3C509B-TPO > $(ARTIFACTS)\T1111.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:C8000 /BSIZE:16 >> $(ARTIFACTS)\T1111.LOG
   FIND "This adapter does not support Boot ROM configuration." $(ARTIFACTS)\T1111.LOG > NUL
   @echo [t1111] PASSED  >> $(TESTLOG)

t1112:
   @echo [t1112] CONFIGURE /BSIZE:8 alone is rejected >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1112.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /BSIZE:8 >> $(ARTIFACTS)\T1112.LOG
   FIND "BADDRESS and /BSIZE must be specified together" $(ARTIFACTS)\T1112.LOG > NUL
   @echo [t1112] PASSED  >> $(TESTLOG)

t1113:
   @echo [t1113] CONFIGURE /BSIZE:32 alone is rejected >> $(TESTLOG)
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /BSIZE:32 > $(ARTIFACTS)\T1113.LOG
   FIND "BADDRESS and /BSIZE must be specified together" $(ARTIFACTS)\T1113.LOG > NUL
   @echo [t1113] PASSED  >> $(TESTLOG)

t1114:
   @echo [t1114] CONFIGURE 8K at C0000 is rejected >> $(TESTLOG)
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:C0000 /BSIZE:8 > $(ARTIFACTS)\T1114.LOG
   FIND "Invalid /BADDRESS parameter. Use a hex address C0000-DE000 in 2000h steps." $(ARTIFACTS)\T1114.LOG > NUL
   @echo [t1114] PASSED  >> $(TESTLOG)

t1115:
   @echo [t1115] CONFIGURE 8K at C2000 >> $(TESTLOG)
   ${SEEDAPP} INIT /ROM8K > $(ARTIFACTS)\T1115.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:C2000 /BSIZE:8 > $(ARTIFACTS)\T1115.LOG
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1115.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1115.LOG
   FIND "Boot ROM = 8K at C2000H" $(ARTIFACTS)\T1115.LOG > NUL
   @echo [t1115] PASSED  >> $(TESTLOG)

t1116:
   @echo [t1116] CONFIGURE 16K at C2000 is rejected >> $(TESTLOG)
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:C2000 /BSIZE:16 > $(ARTIFACTS)\T1116.LOG
   FIND "Invalid /BADDRESS parameter. Use a hex address C0000-DE000 in 2000h steps." $(ARTIFACTS)\T1116.LOG > NUL
   @echo [t1116] PASSED  >> $(TESTLOG)

t1117:
   @echo [t1117] CONFIGURE 32K 3C509B at C4000 >> $(TESTLOG)
   ${SEEDAPP} INIT /ROM32K > $(ARTIFACTS)\T1117.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:C4000 /BSIZE:32 > $(ARTIFACTS)\T1117.LOG
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1117.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1117.LOG
   FIND "Boot ROM = 32K at C4000H" $(ARTIFACTS)\T1117.LOG > NUL
   @echo [t1117] PASSED  >> $(TESTLOG)

t1118:
   @echo [t1118] CONFIGURE 32K 3C509B at DC000 >> $(TESTLOG)
   ${SEEDAPP} INIT /ROM32K > $(ARTIFACTS)\T1118.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:DC000 /BSIZE:32 > $(ARTIFACTS)\T1118.LOG
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1118.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1118.LOG
   FIND "Boot ROM = 32K at DC000H" $(ARTIFACTS)\T1118.LOG > NUL
   @echo [t1118] PASSED  >> $(TESTLOG)

t1119:
   @echo [t1119] INT change not destroying Boot ROM Size Valid flag  >> $(TESTLOG)
   ${SEEDAPP} INIT /ROM16K > $(ARTIFACTS)\T1119.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /INT:5 >> $(ARTIFACTS)\T1119.LOG
   $(BINAPP) LIST /VERBOSE >> $(ARTIFACTS)\T1119.LOG
   FIND "Boot ROM Size Valid = no" $(ARTIFACTS)\T1119.LOG > NUL
   FIND "Secondary EEPROM checksum = valid" $(ARTIFACTS)\T1119.LOG > NUL
   @echo [t1119] PASSED  >> $(TESTLOG)

t1120:
   @echo [t1120] rejected Boot ROM config reports Size Valid = no >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1120.LOG
   $(BINAPP) CONFIGURE /VERBOSE /ADAPTERNUM:1 /BADDRESS:C8000 /BSIZE:16 >> $(ARTIFACTS)\T1120.LOG
   FIND "Boot ROM configuration was skipped." $(ARTIFACTS)\T1120.LOG > NUL
   CALL $(ASSERTERS)\NFIND.BAT "already configured to the requested value" $(ARTIFACTS)\T1120.LOG
   CALL $(ASSERTERS)\NFIND.BAT "Configuration completed successfully." $(ARTIFACTS)\T1120.LOG
   $(BINAPP) LIST /VERBOSE >> $(ARTIFACTS)\T1120.LOG
   FIND "Boot ROM Size Valid = no" $(ARTIFACTS)\T1120.LOG > NUL
   FIND "Secondary EEPROM checksum = valid" $(ARTIFACTS)\T1120.LOG > NUL
   @echo [t1120] PASSED  >> $(TESTLOG)

# A failed Boot ROM probe is non-fatal to unrelated properties in the same
# transaction. These cases cover preservation/commit across INT, IOBASE, and TR.
t1122:
   @echo [t1122] no-ROM seed rejects Boot ROM while preserving INT >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1122.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:C8000 /BSIZE:16 /INT:5 >> $(ARTIFACTS)\T1122.LOG
   FIND "Boot ROM configuration was skipped." $(ARTIFACTS)\T1122.LOG > NUL
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1122.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1122.LOG
   FIND "Boot ROM = disabled" $(ARTIFACTS)\T1122.LOG > NUL
   FIND "IRQ = 5" $(ARTIFACTS)\T1122.LOG > NUL
   @echo [t1122] PASSED  >> $(TESTLOG)

t1126:
   @echo [t1126] no-ROM seed rejects Boot ROM while preserving IOBASE >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1126.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:C8000 /BSIZE:16 /IOBASE:0280 >> $(ARTIFACTS)\T1126.LOG
   FIND "Boot ROM configuration was skipped." $(ARTIFACTS)\T1126.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1126.LOG
   FIND "Boot ROM = disabled" $(ARTIFACTS)\T1126.LOG > NUL
   FIND "IOBASE = 0280" $(ARTIFACTS)\T1126.LOG > NUL
   @echo [t1126] PASSED  >> $(TESTLOG)

t1127:
   @echo [t1127] no-ROM combo seed rejects Boot ROM while preserving TR >> $(TESTLOG)
   ${SEEDAPP} 3C509B-COMBO > $(ARTIFACTS)\T1127.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:C8000 /BSIZE:16 /TR:AUI >> $(ARTIFACTS)\T1127.LOG
   FIND "Boot ROM configuration was skipped." $(ARTIFACTS)\T1127.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1127.LOG
   FIND "Boot ROM = disabled" $(ARTIFACTS)\T1127.LOG > NUL
   FIND "Transceiver = external" $(ARTIFACTS)\T1127.LOG > NUL
   @echo [t1127] PASSED  >> $(TESTLOG)

t1128:
   @echo [t1128] final live Boot ROM verification after accepted 8K commit >> $(TESTLOG)
   ${SEEDAPP} INIT /ROM8K > $(ARTIFACTS)\T1128.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:C2000 /BSIZE:8 /VERBOSE >> $(ARTIFACTS)\T1128.LOG
   FIND "Live Boot ROM configuration verified." $(ARTIFACTS)\T1128.LOG > NUL
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1128.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1128.LOG
   FIND "Boot ROM = 8K at C2000H" $(ARTIFACTS)\T1128.LOG > NUL
   @echo [t1128] PASSED  >> $(TESTLOG)

t1129:
   @echo [t1129] final live Boot ROM verification after accepted 16K commit >> $(TESTLOG)
   ${SEEDAPP} INIT /ROM16K > $(ARTIFACTS)\T1129.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:C8000 /BSIZE:16 /VERBOSE >> $(ARTIFACTS)\T1129.LOG
   FIND "Live Boot ROM configuration verified." $(ARTIFACTS)\T1129.LOG > NUL
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1129.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1129.LOG
   FIND "Boot ROM = 16K at C8000H" $(ARTIFACTS)\T1129.LOG > NUL
   @echo [t1129] PASSED  >> $(TESTLOG)

t1130:
   @echo [t1130] final live Boot ROM verification after accepted 32K commit >> $(TESTLOG)
   ${SEEDAPP} INIT /ROM32K > $(ARTIFACTS)\T1130.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:C8000 /BSIZE:32 /VERBOSE >> $(ARTIFACTS)\T1130.LOG
   FIND "Live Boot ROM configuration verified." $(ARTIFACTS)\T1130.LOG > NUL
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1130.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1130.LOG
   FIND "Boot ROM = 32K at C8000H" $(ARTIFACTS)\T1130.LOG > NUL
   @echo [t1130] PASSED  >> $(TESTLOG)

t1131:
   @echo [t1131] live Boot ROM verification uses final IOBASE after migration >> $(TESTLOG)
   ${SEEDAPP} INIT /ROM16K > $(ARTIFACTS)\T1131.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:C8000 /BSIZE:16 /IOBASE:0280 /VERBOSE >> $(ARTIFACTS)\T1131.LOG
   FIND "IOBASE parameter accepted. Requested IOBASE: 0280" $(ARTIFACTS)\T1131.LOG > NUL
   FIND "Live Boot ROM configuration verified." $(ARTIFACTS)\T1131.LOG > NUL
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1131.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1131.LOG
   FIND "IOBASE = 0280" $(ARTIFACTS)\T1131.LOG > NUL
   FIND "Boot ROM = 16K at C8000H" $(ARTIFACTS)\T1131.LOG > NUL
   @echo [t1131] PASSED  >> $(TESTLOG)

t1132:
   @echo [t1132] accepted Boot ROM with /TR leaves transceiver state undisturbed >> $(TESTLOG)
   ${SEEDAPP} 3C509B-COMBO /ROM16K > $(ARTIFACTS)\T1132.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:C8000 /BSIZE:16 /TR:AUI /VERBOSE >> $(ARTIFACTS)\T1132.LOG
   FIND "TR parameter accepted. Requested transceiver: AUI" $(ARTIFACTS)\T1132.LOG > NUL
   FIND "EEPROM transceiver selection verified." $(ARTIFACTS)\T1132.LOG > NUL
   FIND "Live Boot ROM configuration verified." $(ARTIFACTS)\T1132.LOG > NUL
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1132.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1132.LOG
   FIND "Transceiver = external" $(ARTIFACTS)\T1132.LOG > NUL
   FIND "Boot ROM = 16K at C8000H" $(ARTIFACTS)\T1132.LOG > NUL
   @echo [t1132] PASSED  >> $(TESTLOG)

# Canonical enabled-to-disabled Boot ROM transition test covering persistent
# state, live state, diagnostics, and secondary EEPROM consistency.
t1133:
   @echo [t1133] enabled Boot ROM can be fully disabled and verified >> $(TESTLOG)
   ${SEEDAPP} INIT /ROM16K > $(ARTIFACTS)\T1133.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:C8000 /BSIZE:16 >> $(ARTIFACTS)\T1133.LOG
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1133.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /BSIZE:DISABLED /VERBOSE >> $(ARTIFACTS)\T1133.LOG
   FIND "Live Boot ROM configuration verified." $(ARTIFACTS)\T1133.LOG > NUL
   $(BINAPP) LIST /VERBOSE >> $(ARTIFACTS)\T1133.LOG
   FIND "Boot ROM = disabled" $(ARTIFACTS)\T1133.LOG > NUL
   FIND "Boot ROM Size Valid = no" $(ARTIFACTS)\T1133.LOG > NUL
   FIND "Secondary EEPROM checksum = valid" $(ARTIFACTS)\T1133.LOG > NUL
   @echo [t1133] PASSED  >> $(TESTLOG)

t1134:
   @echo [t1134] rejected Boot ROM skips final live verification >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1134.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:C8000 /BSIZE:16 /INT:5 /VERBOSE >> $(ARTIFACTS)\T1134.LOG
   FIND "Boot ROM configuration was skipped." $(ARTIFACTS)\T1134.LOG > NUL
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1134.LOG > NUL
   FIND "EEPROM IRQ verified: 5" $(ARTIFACTS)\T1134.LOG > NUL
   CALL $(ASSERTERS)\NFIND.BAT "Live Boot ROM configuration verified." $(ARTIFACTS)\T1134.LOG
   $(BINAPP) LIST >> $(ARTIFACTS)\T1134.LOG
   FIND "Boot ROM = disabled" $(ARTIFACTS)\T1134.LOG > NUL
   FIND "IRQ = 5" $(ARTIFACTS)\T1134.LOG > NUL
   @echo [t1134] PASSED  >> $(TESTLOG)

t1135:
   @echo [t1135] combined Boot ROM + /PNP transaction >> $(TESTLOG)
   ${SEEDAPP} INIT /ROM16K > $(ARTIFACTS)\T1135.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:C8000 /BSIZE:16 /PNP:DISABLED /VERBOSE >> $(ARTIFACTS)\T1135.LOG
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1135.LOG > NUL
   FIND "EEPROM Boot ROM base address verified." $(ARTIFACTS)\T1135.LOG > NUL
   FIND "EEPROM Boot ROM size verified." $(ARTIFACTS)\T1135.LOG > NUL
   FIND "Live Boot ROM configuration verified." $(ARTIFACTS)\T1135.LOG > NUL
   FIND "EEPROM Plug and Play mode verified." $(ARTIFACTS)\T1135.LOG > NUL
   FIND "EEPROM checksum updated." $(ARTIFACTS)\T1135.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1135.LOG
   FIND "Boot ROM = 16K at C8000H" $(ARTIFACTS)\T1135.LOG > NUL
   FIND "Plug and Play = disabled" $(ARTIFACTS)\T1135.LOG > NUL
   @echo [t1135] PASSED  >> $(TESTLOG)

t1136:
   @echo [t1136] idempotent Boot ROM re-request reports no changes >> $(TESTLOG)
   ${SEEDAPP} INIT /ROM16K > $(ARTIFACTS)\T1136.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:C8000 /BSIZE:16 >> $(ARTIFACTS)\T1136.LOG
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1136.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:C8000 /BSIZE:16 /VERBOSE >> $(ARTIFACTS)\T1136.LOG
   FIND "Boot ROM base address is already configured to the requested value." $(ARTIFACTS)\T1136.LOG > NUL
   FIND "Boot ROM size is already configured to the requested value." $(ARTIFACTS)\T1136.LOG > NUL
   FIND "No hardware changes required." $(ARTIFACTS)\T1136.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1136.LOG
   FIND "Boot ROM = 16K at C8000H" $(ARTIFACTS)\T1136.LOG > NUL
   @echo [t1136] PASSED  >> $(TESTLOG)

t12xx:
   @echo [t12xx] XCVR_CHANGE: Verify transceiver change behaviour  >> $(TESTLOG)

t1201:
   @echo [t1201] CONFIGURE /TR:TP on 3C509B-TP (should succeed) >> $(TESTLOG)
   ${SEEDAPP} 3C509B-TP > $(ARTIFACTS)\T1201.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:TP >> $(ARTIFACTS)\T1201.LOG
   FIND "TR parameter accepted. Requested transceiver: TP" $(ARTIFACTS)\T1201.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1201.LOG
   FIND "Transceiver = on-board TP" $(ARTIFACTS)\T1201.LOG > NUL
   @echo [t1201] PASSED  >> $(TESTLOG)

t1202:
   @echo [t1202] CONFIGURE /TR:AUI on 3C509B-TP (should succeed) >> $(TESTLOG)
   ${SEEDAPP} 3C509B-TP > $(ARTIFACTS)\T1202.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:AUI >> $(ARTIFACTS)\T1202.LOG
   FIND "TR parameter accepted. Requested transceiver: AUI" $(ARTIFACTS)\T1202.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1202.LOG
   FIND "Transceiver = external" $(ARTIFACTS)\T1202.LOG > NUL
   @echo [t1202] PASSED  >> $(TESTLOG)

t1203:
   @echo [t1203] CONFIGURE /TR:COAX on 3C509B-TP is rejected >> $(TESTLOG)
   ${SEEDAPP} 3C509B-TP > $(ARTIFACTS)\T1203.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:COAX >> $(ARTIFACTS)\T1203.LOG
   FIND "This adapter does not support the requested transceiver type." $(ARTIFACTS)\T1203.LOG > NUL
   @echo [t1203] PASSED  >> $(TESTLOG)

t1204:
   @echo [t1204] CONFIGURE /TR:AUTO on 3C509B-TP (should succeed) >> $(TESTLOG)
   ${SEEDAPP} 3C509B-TP > $(ARTIFACTS)\T1204.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:AUTO >> $(ARTIFACTS)\T1204.LOG
   FIND "TR parameter accepted. Requested transceiver: AUTO" $(ARTIFACTS)\T1204.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1204.LOG
   FIND "Transceiver = auto select" $(ARTIFACTS)\T1204.LOG > NUL
   @echo [t1204] PASSED  >> $(TESTLOG)

t1205:
   @echo [t1205] CONFIGURE /TR:AUI to /TR:TP transition on 3C509B-COMBO >> $(TESTLOG)
   ${SEEDAPP} 3C509B-COMBO > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:AUI /VERBOSE > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:TP /VERBOSE > $(ARTIFACTS)\T1205.LOG
   FIND "EEPROM transceiver selection verified." $(ARTIFACTS)\T1205.LOG > NUL
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1205.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1205.LOG
   FIND "Transceiver = on-board TP" $(ARTIFACTS)\T1205.LOG > NUL
   @echo [t1205] PASSED  >> $(TESTLOG)

t1207:
   @echo [t1207] CONFIGURE /TR:COAX on 3C509B-COMBO (should succeed) >> $(TESTLOG)
   ${SEEDAPP} 3C509B-COMBO > $(ARTIFACTS)\T1207.LOG
   $(BINAPP) LIST >> $(ARTIFACTS)\T1207.LOG
   FIND "Connectors = TP, AUI, COAX" $(ARTIFACTS)\T1207.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:COAX >> $(ARTIFACTS)\T1207.LOG
   FIND "TR parameter accepted. Requested transceiver: COAX" $(ARTIFACTS)\T1207.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1207.LOG
   FIND "Transceiver = on-board coax" $(ARTIFACTS)\T1207.LOG > NUL
   @echo [t1207] PASSED  >> $(TESTLOG)

t1208:
   @echo [t1208] CONFIGURE /TR:COAX on 3C509B-TPC (should succeed) >> $(TESTLOG)
   ${SEEDAPP} 3C509B-TPC > $(ARTIFACTS)\T1208.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:COAX >> $(ARTIFACTS)\T1208.LOG
   FIND "TR parameter accepted. Requested transceiver: COAX" $(ARTIFACTS)\T1208.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1208.LOG
   FIND "Transceiver = on-board coax" $(ARTIFACTS)\T1208.LOG > NUL
   @echo [t1208] PASSED  >> $(TESTLOG)

t1209:
   @echo [t1209] CONFIGURE /TR:AUTO on TP+BNC capabilities succeeds >> $(TESTLOG)
   ${SEEDAPP} 3C509B-TPC > $(ARTIFACTS)\T1209.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:AUTO >> $(ARTIFACTS)\T1209.LOG
   FIND "TR parameter accepted. Requested transceiver: AUTO" $(ARTIFACTS)\T1209.LOG > NUL
   @echo [t1209] PASSED  >> $(TESTLOG)

t1210:
   @echo [t1210] 3C509B-TPO /TR:AUTO rejected (TPO excluded from auto-select) >> $(TESTLOG)
   ${SEEDAPP} 3C509B-TPO > $(ARTIFACTS)\T1210.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:AUTO >> $(ARTIFACTS)\T1210.LOG
   FIND "This adapter does not support the requested transceiver type." $(ARTIFACTS)\T1210.LOG > NUL
   @echo [t1210] PASSED  >> $(TESTLOG)

t1211:
   @echo [t1211] /XCVR alias: behaves identically to /TR:TP >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1211.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /XCVR:TP >> $(ARTIFACTS)\T1211.LOG
   FIND "TR parameter accepted. Requested transceiver: TP" $(ARTIFACTS)\T1211.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1211.LOG
   FIND "Transceiver = on-board TP" $(ARTIFACTS)\T1211.LOG > NUL
   @echo [t1211] PASSED  >> $(TESTLOG)

t13xx:
   @echo [t13xx] CLI_PARSER: Verify CLI parser behaviour  >> $(TESTLOG)

t1301:
   @echo [t1301] HELP command prints CLI help screen >> $(TESTLOG)
   $(BINAPP) HELP >> $(ARTIFACTS)\T1301.LOG
   FIND "Usage: 3CCFGCLI [COMMAND]" $(ARTIFACTS)\T1301.LOG > NUL
   @echo [t1301] PASSED  >> $(TESTLOG)

t1311:
   @echo [t1311] empty command line prints help screen >> $(TESTLOG)
   $(BINAPP) > $(ARTIFACTS)\T1311.LOG
   FIND "Usage: 3CCFGCLI [COMMAND]" $(ARTIFACTS)\T1311.LOG > NUL
   @echo [t1311] PASSED  >> $(TESTLOG)

t1302:
   @echo [t1302] CONFIGURE parser accepts '-' switch introducers >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1302.LOG
   $(BINAPP) CONFIGURE -ADAPTERNUM:1 -INT:5 >> $(ARTIFACTS)\T1302.LOG
   FIND "INT parameter accepted. Requested IRQ: 5" $(ARTIFACTS)\T1302.LOG > NUL
   FIND "IRQ configuration completed successfully." $(ARTIFACTS)\T1302.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1302.LOG
   FIND "IRQ = 5" $(ARTIFACTS)\T1302.LOG > NUL
   @echo [t1302] PASSED  >> $(TESTLOG)

t1303:
   @echo [t1303] CONFIGURE parser accepts '=' value separators >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1303.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM=1 /INT=5 >> $(ARTIFACTS)\T1303.LOG
   FIND "INT parameter accepted. Requested IRQ: 5" $(ARTIFACTS)\T1303.LOG > NUL
   FIND "IRQ configuration completed successfully." $(ARTIFACTS)\T1303.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1303.LOG
   FIND "IRQ = 5" $(ARTIFACTS)\T1303.LOG > NUL
   @echo [t1303] PASSED  >> $(TESTLOG)

t1304:
   @echo [t1304] CONFIGURE with no property is rejected >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1304.LOG
   $(BINAPP) CONFIGURE >> $(ARTIFACTS)\T1304.LOG
   FIND "No CONFIGURE property was specified." $(ARTIFACTS)\T1304.LOG > NUL
   @echo [t1304] PASSED  >> $(TESTLOG)

t1305:
   @echo [t1305] invalid verb shows help screen >> $(TESTLOG)
   $(BINAPP) HELPXYZ >> $(ARTIFACTS)\T1305.LOG
   FIND "Usage: 3CCFGCLI [COMMAND]" $(ARTIFACTS)\T1305.LOG > NUL
   @echo [t1305] PASSED  >> $(TESTLOG)

t1306:
   @echo [t1306] LIST token boundaries >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1306.LOG
   $(BINAPP) LIST >> $(ARTIFACTS)\T1306.LOG
   FIND "IOBASE = 0300" $(ARTIFACTS)\T1306.LOG > NUL
   $(BINAPP) LISTXYZ >> $(ARTIFACTS)\T1306.LOG
   FIND "Usage: 3CCFGCLI [COMMAND]" $(ARTIFACTS)\T1306.LOG > NUL
   @echo [t1306] PASSED  >> $(TESTLOG)

t1307:
   @echo [t1307] SAVECONFIG token boundaries and arguments >> $(TESTLOG)
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
   @echo [t1307] PASSED  >> $(TESTLOG)

t1308:
   @echo [t1308] CONFIGURE token boundaries and arguments >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1308.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /INT:5 >> $(ARTIFACTS)\T1308.LOG
   FIND "IRQ configuration completed successfully." $(ARTIFACTS)\T1308.LOG > NUL
   $(BINAPP) CONFIGUREXYZ >> $(ARTIFACTS)\T1308.LOG
   FIND "Usage: 3CCFGCLI [COMMAND]" $(ARTIFACTS)\T1308.LOG > NUL
   @echo [t1308] PASSED  >> $(TESTLOG)

t1309:
   @echo [t1309] leading spaces and tabs before command verbs >> $(TESTLOG)
   $(BINAPP)    HELP > $(ARTIFACTS)\T1309.LOG
   FIND "Usage: 3CCFGCLI [COMMAND]" $(ARTIFACTS)\T1309.LOG > NUL
   $(BINAPP)	LIST >> $(ARTIFACTS)\T1309.LOG
   FIND "IOBASE = 0300" $(ARTIFACTS)\T1309.LOG > NUL
   @echo [t1309] PASSED  >> $(TESTLOG)

t1310:
   @echo [t1310] truncated verb shows help screen >> $(TESTLOG)
   $(BINAPP) SAVECONFI >> $(ARTIFACTS)\T1310.LOG
   FIND "Usage: 3CCFGCLI [COMMAND]" $(ARTIFACTS)\T1310.LOG > NUL
   @echo [t1310] PASSED  >> $(TESTLOG)

t14xx:
   @echo [t14xx] COMBINED_TRANSACTIONS: Verify combined transactions  >> $(TESTLOG)

t1401:
   @echo [t1401] combined CONFIGURE /IOBASE+/INT transaction >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1401.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /IOBASE:0280 /INT:5 /VERBOSE >> $(ARTIFACTS)\T1401.LOG
   FIND "IOBASE parameter accepted. Requested IOBASE: 0280" $(ARTIFACTS)\T1401.LOG > NUL
   FIND "INT parameter accepted. Requested IRQ: 5" $(ARTIFACTS)\T1401.LOG > NUL
   FIND "IOBASE and IRQ configuration completed successfully." $(ARTIFACTS)\T1401.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1401.LOG
   FIND "IOBASE = 0280" $(ARTIFACTS)\T1401.LOG > NUL
   FIND "IRQ = 5" $(ARTIFACTS)\T1401.LOG > NUL
   @echo [t1401] PASSED  >> $(TESTLOG)

# MODEM, FULLDUPLEX, and OPTIMIZE share EEPROM word 0Dh. These combinations
# verify that independently requested fields are merged without clobbering.
t1402:
   @echo [t1402] combined CONFIGURE /MODEM+/FULLDUPLEX transaction >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1402.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:1200 /FULLDUPLEX:ENABLED /VERBOSE >> $(ARTIFACTS)\T1402.LOG
   FIND "MODEM parameter accepted. Requested setting: 1200" $(ARTIFACTS)\T1402.LOG > NUL
   FIND "FULLDUPLEX parameter accepted. Requested mode: enabled" $(ARTIFACTS)\T1402.LOG > NUL
   FIND "New EEPROM word 0Dh: " $(ARTIFACTS)\T1402.LOG > NUL
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1402.LOG > NUL
   @echo [t1402] PASSED  >> $(TESTLOG)

t1403:
   @echo [t1403] combined CONFIGURE /IOBASE+/TR on 3C509B-Combo >> $(TESTLOG)
   ${SEEDAPP} 3C509B-COMBO > $(ARTIFACTS)\T1403.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /IOBASE:0280 /TR:AUI /VERBOSE >> $(ARTIFACTS)\T1403.LOG
   FIND "IOBASE parameter accepted. Requested IOBASE: 0280" $(ARTIFACTS)\T1403.LOG > NUL
   FIND "TR parameter accepted. Requested transceiver: AUI" $(ARTIFACTS)\T1403.LOG > NUL
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1403.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1403.LOG
   FIND "IOBASE = 0280" $(ARTIFACTS)\T1403.LOG > NUL
   FIND "Transceiver = external" $(ARTIFACTS)\T1403.LOG > NUL
   @echo [t1403] PASSED  >> $(TESTLOG)

t1405:
   @echo [t1405] combined CONFIGURE /OPTIMIZE+/MODEM transaction >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1405.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /OPTIMIZE:SERVER /MODEM:1200 /VERBOSE >> $(ARTIFACTS)\T1405.LOG
   FIND "MODEM parameter accepted. Requested setting: 1200" $(ARTIFACTS)\T1405.LOG > NUL
   FIND "New EEPROM word 0Dh: Server" $(ARTIFACTS)\T1405.LOG > NUL
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1405.LOG > NUL
   @echo [t1405] PASSED  >> $(TESTLOG)

t1406:
   @echo [t1406] combined CONFIGURE /TR:AUTO+/BADDRESS+/BSIZE on 3C509B-Combo >> $(TESTLOG)
   ${SEEDAPP} 3C509B-COMBO /ROM16K > $(ARTIFACTS)\T1406.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:AUTO /BADDRESS:C8000 /BSIZE:16 /VERBOSE >> $(ARTIFACTS)\T1406.LOG
   FIND "TR parameter accepted. Requested transceiver: AUTO" $(ARTIFACTS)\T1406.LOG > NUL
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1406.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1406.LOG
   FIND "Transceiver = auto select" $(ARTIFACTS)\T1406.LOG > NUL
   FIND "Boot ROM = 16K at C8000H" $(ARTIFACTS)\T1406.LOG > NUL
   @echo [t1406] PASSED  >> $(TESTLOG)

t1407:
   @echo [t1407] combined CONFIGURE /PNP+/INT checksum domains >> $(TESTLOG)
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
   @echo [t1407] PASSED  >> $(TESTLOG)

t15xx:
   @echo [t15xx] MULTI_NIC: Verify multi-NIC behaviour  >> $(TESTLOG)

t1502:
   @echo [t1502] multi-NIC CONFIGURE requires /ADAPTERNUM >> $(TESTLOG)
   ${SEEDAPP} CLEAR > $(ARTIFACTS)\T1502.LOG
   ${SEEDAPP} ADD 3C509B-TP /IOBASE:0300 /INT:10 >> $(ARTIFACTS)\T1502.LOG
   ${SEEDAPP} ADD 3C509B-COMBO /IOBASE:0310 /INT:5 >> $(ARTIFACTS)\T1502.LOG
   $(BINAPP) CONFIGURE /INT:7 >> $(ARTIFACTS)\T1502.LOG
   FIND "ADAPTERNUM is required when more than one adapter is installed." $(ARTIFACTS)\T1502.LOG > NUL
   @echo [t1502] PASSED  >> $(TESTLOG)

t1503:
   @echo [t1503] multi-NIC adapter selection changes only the targeted NIC >> $(TESTLOG)
   ${SEEDAPP} CLEAR > $(ARTIFACTS)\T1503.LOG
   ${SEEDAPP} ADD 3C509B-TP /IOBASE:0300 /INT:10 >> $(ARTIFACTS)\T1503.LOG
   ${SEEDAPP} ADD 3C509B-COMBO /IOBASE:0310 /INT:5 >> $(ARTIFACTS)\T1503.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:2 /INT:7 >> $(ARTIFACTS)\T1503.LOG
   FIND "IRQ configuration completed successfully." $(ARTIFACTS)\T1503.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1503.LOG
   FIND "IOBASE = 0300, IRQ = 10" $(ARTIFACTS)\T1503.LOG > NUL
   FIND "IOBASE = 0310, IRQ = 7" $(ARTIFACTS)\T1503.LOG > NUL
   @echo [t1503] PASSED  >> $(TESTLOG)

t1504:
   @echo [t1504] multi-NIC /IOBASE conflict detection blocks duplicate base >> $(TESTLOG)
   ${SEEDAPP} CLEAR > $(ARTIFACTS)\T1504.LOG
   ${SEEDAPP} ADD 3C509B-TP /IOBASE:0300 /INT:10 >> $(ARTIFACTS)\T1504.LOG
   ${SEEDAPP} ADD 3C509B-COMBO /IOBASE:0310 /INT:5 >> $(ARTIFACTS)\T1504.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:2 /IOBASE:0300 >> $(ARTIFACTS)\T1504.LOG
   FIND "Requested IOBASE is already used by another discovered adapter." $(ARTIFACTS)\T1504.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1504.LOG
   FIND "IOBASE = 0300, IRQ = 10" $(ARTIFACTS)\T1504.LOG > NUL
   FIND "IOBASE = 0310, IRQ = 5" $(ARTIFACTS)\T1504.LOG > NUL
   @echo [t1504] PASSED  >> $(TESTLOG)

# This deliberately creates an ambiguous hardware state with two adapters at
# the same active IOBASE. The target must not be treated as safely addressable.
t1505:
   @echo [t1505] duplicate active-IOBASE conflict rejects targeted migration >> $(TESTLOG)
   ${SEEDAPP} CLEAR > $(ARTIFACTS)\T1505.LOG
   ${SEEDAPP} ADD 3C509B-TP /IOBASE:0300 /INT:10 >> $(ARTIFACTS)\T1505.LOG
   ${SEEDAPP} ADD 3C509B-COMBO /IOBASE:0300 /INT:5 >> $(ARTIFACTS)\T1505.LOG
   $(BINAPP) LIST >> $(ARTIFACTS)\T1505.LOG
   FIND "IOBASE = 0300, IRQ = 10" $(ARTIFACTS)\T1505.LOG > NUL
   FIND "IOBASE = 0300, IRQ = 5" $(ARTIFACTS)\T1505.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:2 /IOBASE:0310 >> $(ARTIFACTS)\T1505.LOG
   FIND "Selected adapter has no active IOBASE" $(ARTIFACTS)\T1505.LOG > NUL
   @echo [t1505] PASSED  >> $(TESTLOG)

t16xx:
   @echo [t16xx] SAVECONFIG_TEST: Verify save configuration behaviour  >> $(TESTLOG)

t1602:
   @echo [t1602] SAVECONFIG rejects an empty /OUTPUTFILE value >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1602.LOG
   $(BINAPP) SAVECONFIG /OUTPUTFILE: >> $(ARTIFACTS)\T1602.LOG
   FIND "SAVECONFIG /OUTPUTFILE requires a value." $(ARTIFACTS)\T1602.LOG > NUL
   @echo [t1602] PASSED  >> $(TESTLOG)

t1603:
   @echo [t1603] SAVECONFIG exports one restore line per multi-NIC adapter >> $(TESTLOG)
   ${SEEDAPP} CLEAR > $(ARTIFACTS)\T1603.LOG
   ${SEEDAPP} ADD 3C509B-TP /IOBASE:0300 /INT:10 >> $(ARTIFACTS)\T1603.LOG
   ${SEEDAPP} ADD 3C509B-COMBO /IOBASE:0310 /INT:5 >> $(ARTIFACTS)\T1603.LOG
   $(BINAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\RESTORE.BAT >> $(ARTIFACTS)\T1603.LOG
   FIND "Configuration restore batch file created: $(ARTIFACTS)\RESTORE.BAT" $(ARTIFACTS)\T1603.LOG > NUL
   FIND "ADAPTERNUM:1 /INT:10" $(ARTIFACTS)\RESTORE.BAT > NUL
   FIND "ADAPTERNUM:2 /INT:5" $(ARTIFACTS)\RESTORE.BAT > NUL
   @echo [t1603] PASSED  >> $(TESTLOG)


# End-to-end SAVECONFIG restore test.
# Unlike the manual multi-step configuration test, this verifies that
# SAVECONFIG generates executable restore commands which, after a fresh seed,
# reconstruct the expected adapter configuration.
t1606:
   @echo [t1606] SAVECONFIG keeps Boot ROM pair atomic in split restore commands >> $(TESTLOG)
   ${SEEDAPP} INIT /ROM16K > $(ARTIFACTS)\T1606.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /IOBASE:0280 /INT:5 /PNP:ENABLED /FULLDUPLEX:ENABLED >> $(ARTIFACTS)\T1606.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:1200 /OPTIMIZE:SERVER /BADDRESS:C8000 /BSIZE:16 /TR:TP >> $(ARTIFACTS)\T1606.LOG
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1606.LOG > NUL
   $(BINAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\RESTORE.BAT /EXECFILE:$(BINAPP) >> $(ARTIFACTS)\T1606.LOG
   FIND "BIN\3CHWMOCK.EXE CONFIGURE /ADAPTERNUM:1 /BADDRESS:C8000 /BSIZE:16 /TR:TP" $(ARTIFACTS)\RESTORE.BAT > NUL
   ${SEEDAPP} INIT /ROM16K >> $(ARTIFACTS)\T1606.LOG
   CALL $(ARTIFACTS)\RESTORE.BAT >> $(ARTIFACTS)\T1606.LOG
   $(BINAPP) LIST >> $(ARTIFACTS)\T1606.LOG
   FIND "IOBASE = 0280, IRQ = 5" $(ARTIFACTS)\T1606.LOG > NUL
   FIND "Optimization = Server" $(ARTIFACTS)\T1606.LOG > NUL
   FIND "Boot ROM = 16K at C8000H" $(ARTIFACTS)\T1606.LOG > NUL
   @echo [t1606] PASSED  >> $(TESTLOG)

t1607:
   @echo [t1607] SAVECONFIG rejects unsupported percent EXECFILE forms >> $(TESTLOG)
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
   @echo [t1607] PASSED  >> $(TESTLOG)

t1608:
   @echo [t1608] SAVECONFIG rejects missing literal EXECFILE before creating output >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1608.LOG
   @if exist $(ARTIFACTS)\MISSING.BAT del $(ARTIFACTS)\MISSING.BAT
   $(BINAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\MISSING.BAT /EXECFILE:C:\DOESNOT\EXIST.EXE >> $(ARTIFACTS)\T1608.LOG
   FIND "SAVECONFIG /EXECFILE file not found." $(ARTIFACTS)\T1608.LOG > NUL
   @if exist $(ARTIFACTS)\MISSING.BAT FIND "THIS FILE SHOULD NOT EXIST" $(ARTIFACTS)\MISSING.BAT > NUL
   @echo [t1608] PASSED  >> $(TESTLOG)

t1609:
   @echo [t1609] SAVECONFIG default EXECFILE dynamic splitting preserves options >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1609.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /INT:10 /IOBASE:0300 /PNP:ENABLED /FULLDUPLEX:ENABLED >> $(ARTIFACTS)\T1609.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:NONE /OPTIMIZE:DOS /BSIZE:DISABLED /TR:TP >> $(ARTIFACTS)\T1609.LOG
   $(BINAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\DEFREST.BAT >> $(ARTIFACTS)\T1609.LOG
   FIND "ADAPTERNUM:1 /INT:10 /IOBASE:0300 /PNP:ENABLED /FULLDUPLEX:ENABLED" $(ARTIFACTS)\DEFREST.BAT > NUL
   FIND "ADAPTERNUM:1 /BSIZE:DISABLED /TR:TP" $(ARTIFACTS)\DEFREST.BAT > NUL
   FIND "BSIZE:DISABLED" $(ARTIFACTS)\DEFREST.BAT > NUL
   @echo [t1609] PASSED  >> $(TESTLOG)

# %1 has unknown expanded length when the restore file is generated, so line
# packing deliberately reserves space conservatively and may split earlier.
t1610:
   @echo [t1610] SAVECONFIG %%1 conservative EXECFILE reservation >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1610.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /INT:10 /IOBASE:0300 /PNP:ENABLED /FULLDUPLEX:ENABLED >> $(ARTIFACTS)\T1610.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:NONE /OPTIMIZE:DOS /BSIZE:DISABLED /TR:TP >> $(ARTIFACTS)\T1610.LOG
   $(BINAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\PCTREST.BAT /EXECFILE:%1 >> $(ARTIFACTS)\T1610.LOG
   FIND "%1 CONFIGURE /ADAPTERNUM:1 /INT:10 /IOBASE:0300 /PNP:ENABLED" $(ARTIFACTS)\PCTREST.BAT > NUL
   FIND "%1 CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:ENABLED /MODEM:NONE" $(ARTIFACTS)\PCTREST.BAT > NUL
   FIND "%1 CONFIGURE /ADAPTERNUM:1 /OPTIMIZE:DOS /BSIZE:DISABLED /TR:TP" $(ARTIFACTS)\PCTREST.BAT > NUL
   @echo [t1610] PASSED  >> $(TESTLOG)

t1611:
   @echo [t1611] SAVECONFIG literal EXECFILE restore execution with disabled Boot ROM >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1611.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /INT:10 /IOBASE:0300 /PNP:ENABLED /FULLDUPLEX:ENABLED >> $(ARTIFACTS)\T1611.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /MODEM:NONE /OPTIMIZE:DOS /BSIZE:DISABLED /TR:TP >> $(ARTIFACTS)\T1611.LOG
   $(BINAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\LITREST.BAT /EXECFILE:$(BINAPP) >> $(ARTIFACTS)\T1611.LOG
   FIND "BIN\3CHWMOCK.EXE CONFIGURE" $(ARTIFACTS)\LITREST.BAT > NUL
   FIND "BSIZE:DISABLED" $(ARTIFACTS)\LITREST.BAT > NUL
   ${SEEDAPP} INIT >> $(ARTIFACTS)\T1611.LOG
   CALL $(ARTIFACTS)\LITREST.BAT >> $(ARTIFACTS)\T1611.LOG
   $(BINAPP) LIST >> $(ARTIFACTS)\T1611.LOG
   FIND "IOBASE = 0300, IRQ = 10" $(ARTIFACTS)\T1611.LOG > NUL
   FIND "Plug and Play = enabled" $(ARTIFACTS)\T1611.LOG > NUL
   FIND "Full Duplex = enabled" $(ARTIFACTS)\T1611.LOG > NUL
   FIND "Boot ROM = disabled" $(ARTIFACTS)\T1611.LOG > NUL
   @echo [t1611] PASSED  >> $(TESTLOG)

t1612:
   @echo [t1612] SAVECONFIG without options writes the default RESTORE.BAT >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1612.LOG
   @if exist RESTORE.BAT del RESTORE.BAT
   $(BINAPP) SAVECONFIG >> $(ARTIFACTS)\T1612.LOG
   FIND "Configuration restore batch file created: RESTORE.BAT" $(ARTIFACTS)\T1612.LOG > NUL
   FIND "3CCFGCLI.EXE CONFIGURE" RESTORE.BAT > NUL
   @if exist RESTORE.BAT del RESTORE.BAT
   @echo [t1612] PASSED  >> $(TESTLOG)

t1613:
   @echo [t1613] SAVECONFIG /EXECFILE alone uses the default output filename >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1613.LOG
   @if exist RESTORE.BAT del RESTORE.BAT
   $(BINAPP) SAVECONFIG /EXECFILE:$(BINAPP) >> $(ARTIFACTS)\T1613.LOG
   FIND "Configuration restore batch file created: RESTORE.BAT" $(ARTIFACTS)\T1613.LOG > NUL
   FIND "BIN\3CHWMOCK.EXE CONFIGURE" RESTORE.BAT > NUL
   @if exist RESTORE.BAT del RESTORE.BAT
   @echo [t1613] PASSED  >> $(TESTLOG)

t1614:
   @echo [t1614] SAVECONFIG accepts OUTPUTFILE and EXECFILE in either order >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1614.LOG
   $(BINAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\ORDER1.BAT /EXECFILE:$(BINAPP) >> $(ARTIFACTS)\T1614.LOG
   FIND "Configuration restore batch file created: $(ARTIFACTS)\ORDER1.BAT" $(ARTIFACTS)\T1614.LOG > NUL
   FIND "BIN\3CHWMOCK.EXE CONFIGURE" $(ARTIFACTS)\ORDER1.BAT > NUL
   $(BINAPP) SAVECONFIG /EXECFILE:$(BINAPP) /OUTPUTFILE:$(ARTIFACTS)\ORDER2.BAT >> $(ARTIFACTS)\T1614.LOG
   FIND "Configuration restore batch file created: $(ARTIFACTS)\ORDER2.BAT" $(ARTIFACTS)\T1614.LOG > NUL
   FIND "BIN\3CHWMOCK.EXE CONFIGURE" $(ARTIFACTS)\ORDER2.BAT > NUL
   @echo [t1614] PASSED  >> $(TESTLOG)

t1615:
   @echo [t1615] SAVECONFIG rejects duplicate options >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1615.LOG
   $(BINAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\DUPA.BAT /OUTPUTFILE:$(ARTIFACTS)\DUPB.BAT > $(ARTIFACTS)\T1615.LOG
   FIND "Duplicate SAVECONFIG option." $(ARTIFACTS)\T1615.LOG > NUL
   $(BINAPP) SAVECONFIG /EXECFILE:$(BINAPP) /EXECFILE:BIN\3CCFGCLI.EXE > $(ARTIFACTS)\T1615.LOG
   FIND "Duplicate SAVECONFIG option." $(ARTIFACTS)\T1615.LOG > NUL
   @echo [t1615] PASSED  >> $(TESTLOG)

t1616:
   @echo [t1616] SAVECONFIG rejects unknown options and the old positional syntax >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1616.LOG
   $(BINAPP) SAVECONFIG /BIRCHERMUESLI:34333 > $(ARTIFACTS)\T1616.LOG
   FIND "Invalid SAVECONFIG option." $(ARTIFACTS)\T1616.LOG > NUL
   $(BINAPP) SAVECONFIG $(ARTIFACTS)\OLDPOS.BAT > $(ARTIFACTS)\T1616.LOG
   FIND "Invalid SAVECONFIG option." $(ARTIFACTS)\T1616.LOG > NUL
   @if exist $(ARTIFACTS)\OLDPOS.BAT FIND "THIS FILE SHOULD NOT EXIST" $(ARTIFACTS)\OLDPOS.BAT > NUL
   @echo [t1616] PASSED  >> $(TESTLOG)

t1617:
   @echo [t1617] SAVECONFIG /OUTPUTFILE alone keeps the default executable >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1617.LOG
   $(BINAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\OUTONLY.BAT >> $(ARTIFACTS)\T1617.LOG
   FIND "Configuration restore batch file created: $(ARTIFACTS)\OUTONLY.BAT" $(ARTIFACTS)\T1617.LOG > NUL
   FIND "3CCFGCLI.EXE CONFIGURE /ADAPTERNUM:1" $(ARTIFACTS)\OUTONLY.BAT > NUL
   @echo [t1617] PASSED  >> $(TESTLOG)

t1618:
   @echo [t1618] global /VERBOSE is accepted by LIST >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1618.LOG
   $(BINAPP) LIST /VERBOSE >> $(ARTIFACTS)\T1618.LOG
   FIND "IOBASE = 0300" $(ARTIFACTS)\T1618.LOG > NUL
   @echo [t1618] PASSED  >> $(TESTLOG)

t1619:
   @echo [t1619] global /VERBOSE with bare SAVECONFIG uses RESTORE.BAT >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1619.LOG
   @if exist RESTORE.BAT del RESTORE.BAT
   $(BINAPP) SAVECONFIG /VERBOSE >> $(ARTIFACTS)\T1619.LOG
   FIND "Configuration restore batch file created: RESTORE.BAT" $(ARTIFACTS)\T1619.LOG > NUL
   FIND "3CCFGCLI.EXE CONFIGURE" RESTORE.BAT > NUL
   @if exist RESTORE.BAT del RESTORE.BAT
   @echo [t1619] PASSED  >> $(TESTLOG)

# Two representative placements cover global /VERBOSE position handling because
# it is consumed by the common argument scanner before SAVECONFIG parsing.
t1620:
   @echo [t1620] global /VERBOSE position is not significant for SAVECONFIG >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1620.LOG
   $(BINAPP) SAVECONFIG /VERBOSE /OUTPUTFILE:$(ARTIFACTS)\VERBLEAD.BAT >> $(ARTIFACTS)\T1620.LOG
   FIND "Configuration restore batch file created: $(ARTIFACTS)\VERBLEAD.BAT" $(ARTIFACTS)\T1620.LOG > NUL
   FIND "3CCFGCLI.EXE CONFIGURE" $(ARTIFACTS)\VERBLEAD.BAT > NUL
   $(BINAPP) SAVECONFIG /EXECFILE:$(BINAPP) /VERBOSE /OUTPUTFILE:$(ARTIFACTS)\VERBMID.BAT >> $(ARTIFACTS)\T1620.LOG
   FIND "Configuration restore batch file created: $(ARTIFACTS)\VERBMID.BAT" $(ARTIFACTS)\T1620.LOG > NUL
   FIND "BIN\3CHWMOCK.EXE CONFIGURE" $(ARTIFACTS)\VERBMID.BAT > NUL
   @echo [t1620] PASSED  >> $(TESTLOG)

t1621:
   @echo [t1621] duplicate global /VERBOSE is rejected for LIST command >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1621.LOG
   $(BINAPP) LIST /VERBOSE /VERBOSE > $(ARTIFACTS)\T1621.LOG
   FIND "Duplicate /VERBOSE option." $(ARTIFACTS)\T1621.LOG > NUL
   @echo [t1621] PASSED  >> $(TESTLOG)

t1626:
   @echo [t1626] duplicate global /VERBOSE is rejected before SAVECONFIG output >> $(TESTLOG)
   ${SEEDAPP} INIT > NUL
   @if exist $(ARTIFACTS)\DUPV.BAT del $(ARTIFACTS)\DUPV.BAT
   $(BINAPP) SAVECONFIG /VERBOSE /OUTPUTFILE:$(ARTIFACTS)\DUPV.BAT /VERBOSE > $(ARTIFACTS)\T1626.LOG
   FIND "Duplicate /VERBOSE option." $(ARTIFACTS)\T1626.LOG > NUL
   @if exist $(ARTIFACTS)\DUPV.BAT FIND "THIS FILE SHOULD NOT EXIST" $(ARTIFACTS)\DUPV.BAT > NUL
   @echo [t1626] PASSED  >> $(TESTLOG)

t1622:
   @echo [t1622] verb namespaces do not leak across CONFIGURE and SAVECONFIG >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1622.LOG
   $(BINAPP) SAVECONFIG /INT:5 > $(ARTIFACTS)\T1622.LOG
   FIND "Invalid SAVECONFIG option." $(ARTIFACTS)\T1622.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /OUTPUTFILE:A.BAT >> $(ARTIFACTS)\T1622.LOG
   FIND "Invalid CONFIGURE option." $(ARTIFACTS)\T1622.LOG > NUL

# 16K/32K Boot ROM selectors have alignment aliasing that SAVECONFIG must
# canonicalize. The 8K case below is the unaliased counterexample.
   @echo [t1622] PASSED  >> $(TESTLOG)

t1623:
   @echo [t1623] SAVECONFIG normalizes a 16K Boot ROM at C0000 (selector alias) >> $(TESTLOG)
   ${SEEDAPP} INIT /ROM16K > $(ARTIFACTS)\T1623.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:C0000 /BSIZE:16 >> $(ARTIFACTS)\T1623.LOG
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1623.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1623.LOG
   FIND "Boot ROM = 16K at C0000H" $(ARTIFACTS)\T1623.LOG > NUL
   $(BINAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\T1623.BAT /EXECFILE:$(BINAPP) >> $(ARTIFACTS)\T1623.LOG
   FIND "BADDRESS:C0000 /BSIZE:16" $(ARTIFACTS)\T1623.BAT > NUL
   CALL $(ASSERTERS)\NFIND.BAT "BADDRESS:C2000" $(ARTIFACTS)\T1623.BAT
   @echo [t1623] PASSED  >> $(TESTLOG)

t1624:
   @echo [t1624] SAVECONFIG normalizes a 32K Boot ROM at C0000 (selector alias) >> $(TESTLOG)
   ${SEEDAPP} INIT /ROM32K > $(ARTIFACTS)\T1624.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:C0000 /BSIZE:32 >> $(ARTIFACTS)\T1624.LOG
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1624.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1624.LOG
   FIND "Boot ROM = 32K at C0000H" $(ARTIFACTS)\T1624.LOG > NUL
   $(BINAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\T1624.BAT /EXECFILE:$(BINAPP) >> $(ARTIFACTS)\T1624.LOG
   FIND "BADDRESS:C0000 /BSIZE:32" $(ARTIFACTS)\T1624.BAT > NUL
   @echo [t1624] PASSED  >> $(TESTLOG)

t1625:
   @echo [t1625] SAVECONFIG still exports an unaliased 8K Boot ROM at C2000 >> $(TESTLOG)
   ${SEEDAPP} INIT /ROM8K > $(ARTIFACTS)\T1625.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:C2000 /BSIZE:8 >> $(ARTIFACTS)\T1625.LOG
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1625.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1625.LOG
   FIND "Boot ROM = 8K at C2000H" $(ARTIFACTS)\T1625.LOG > NUL
   $(BINAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\T1625.BAT /EXECFILE:$(BINAPP) >> $(ARTIFACTS)\T1625.LOG
   FIND "BADDRESS:C2000 /BSIZE:8" $(ARTIFACTS)\T1625.BAT > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:C0000 /BSIZE:8 >> $(ARTIFACTS)\T1625.LOG
   FIND "Invalid /BADDRESS parameter. Use a hex address C0000-DE000 in 2000h steps." $(ARTIFACTS)\T1625.LOG > NUL
   @echo [t1625] PASSED  >> $(TESTLOG)

# Focused cases verify that transaction verification continues correctly from
# one requested property to the next. The final integration case verifies that
# a complete configuration split across multiple CONFIGURE invocations composes
# correctly.
t17xx:
   @echo [t17xx] VERIFICATION_CONTROL_FLOW: verify transaction chain behaviour  >> $(TESTLOG)

t1701:
   @echo [t1701] INT+PNP verification chain without /VERBOSE >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1701.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /INT:5 /PNP:DISABLED >> $(ARTIFACTS)\T1701.LOG
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1701.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1701.LOG
   FIND "IRQ = 5" $(ARTIFACTS)\T1701.LOG > NUL
   FIND "Plug and Play = disabled" $(ARTIFACTS)\T1701.LOG > NUL
   @echo [t1701] PASSED  >> $(TESTLOG)

t1702:
   @echo [t1702] INT+PNP verification chain with /VERBOSE >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1702.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /INT:5 /PNP:DISABLED /VERBOSE >> $(ARTIFACTS)\T1702.LOG
   FIND "EEPROM IRQ verified: 5" $(ARTIFACTS)\T1702.LOG > NUL
   FIND "Live IRQ verified: 5" $(ARTIFACTS)\T1702.LOG > NUL
   FIND "EEPROM Plug and Play mode verified." $(ARTIFACTS)\T1702.LOG > NUL
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1702.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1702.LOG
   FIND "IRQ = 5" $(ARTIFACTS)\T1702.LOG > NUL
   FIND "Plug and Play = disabled" $(ARTIFACTS)\T1702.LOG > NUL
   @echo [t1702] PASSED  >> $(TESTLOG)

t1703:
   @echo [t1703] unchanged INT+PNP verification chain without /VERBOSE >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1703.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /INT:10 /PNP:DISABLED >> $(ARTIFACTS)\T1703.LOG
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1703.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1703.LOG
   FIND "IRQ = 10" $(ARTIFACTS)\T1703.LOG > NUL
   FIND "Plug and Play = disabled" $(ARTIFACTS)\T1703.LOG > NUL
   @echo [t1703] PASSED  >> $(TESTLOG)

t1704:
   @echo [t1704] unchanged INT+PNP verification chain with /VERBOSE >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1704.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /INT:10 /PNP:DISABLED /VERBOSE >> $(ARTIFACTS)\T1704.LOG
   FIND "IRQ is already configured to the requested value." $(ARTIFACTS)\T1704.LOG > NUL
   FIND "EEPROM Plug and Play mode verified." $(ARTIFACTS)\T1704.LOG > NUL
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1704.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1704.LOG
   FIND "IRQ = 10" $(ARTIFACTS)\T1704.LOG > NUL
   FIND "Plug and Play = disabled" $(ARTIFACTS)\T1704.LOG > NUL
   @echo [t1704] PASSED  >> $(TESTLOG)

t1705:
   @echo [t1705] PNP+MODEM verification chain without /VERBOSE >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1705.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /PNP:DISABLED /MODEM:9600 >> $(ARTIFACTS)\T1705.LOG
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1705.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1705.LOG
   FIND "Plug and Play = disabled" $(ARTIFACTS)\T1705.LOG > NUL
   FIND "MODEM Interrupt Disable Time = 500 us (9600 bd)" $(ARTIFACTS)\T1705.LOG > NUL
   @echo [t1705] PASSED  >> $(TESTLOG)

t1706:
   @echo [t1706] PNP+MODEM verification chain with /VERBOSE >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1706.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /PNP:DISABLED /MODEM:9600 /VERBOSE >> $(ARTIFACTS)\T1706.LOG
   FIND "EEPROM Plug and Play mode verified." $(ARTIFACTS)\T1706.LOG > NUL
   FIND "EEPROM modem speed setting verified." $(ARTIFACTS)\T1706.LOG > NUL
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1706.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1706.LOG
   FIND "Plug and Play = disabled" $(ARTIFACTS)\T1706.LOG > NUL
   FIND "MODEM Interrupt Disable Time = 500 us (9600 bd)" $(ARTIFACTS)\T1706.LOG > NUL
   @echo [t1706] PASSED  >> $(TESTLOG)

t1707:
   @echo [t1707] FULLDUPLEX+OPTIMIZE verification chain without /VERBOSE >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1707.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:ENABLED /OPTIMIZE:SERVER >> $(ARTIFACTS)\T1707.LOG
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1707.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1707.LOG
   FIND "Full Duplex = enabled" $(ARTIFACTS)\T1707.LOG > NUL
   FIND "Optimization = Server" $(ARTIFACTS)\T1707.LOG > NUL
   @echo [t1707] PASSED  >> $(TESTLOG)

t1708:
   @echo [t1708] FULLDUPLEX+OPTIMIZE verification chain with /VERBOSE >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1708.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:ENABLED /OPTIMIZE:SERVER /VERBOSE >> $(ARTIFACTS)\T1708.LOG
   FIND "EEPROM full duplex mode verified." $(ARTIFACTS)\T1708.LOG > NUL
   FIND "EEPROM optimize mode verified." $(ARTIFACTS)\T1708.LOG > NUL
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1708.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1708.LOG
   FIND "Full Duplex = enabled" $(ARTIFACTS)\T1708.LOG > NUL
   FIND "Optimization = Server" $(ARTIFACTS)\T1708.LOG > NUL
   @echo [t1708] PASSED  >> $(TESTLOG)

# End-to-end verification of a manually entered full adapter configuration.
# The configuration is deliberately split across two CONFIGURE invocations
# because the complete option set exceeds the DOS PSP command-line limit.
# This verifies that consecutive configuration transactions compose correctly
# and that the resulting adapter state remains consistent.
t1710:
   @echo [t1710] manually split full configuration verification sequence with /VERBOSE >> $(TESTLOG)
   ${SEEDAPP} INIT /ROM8K > $(ARTIFACTS)\T1710.LOG
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
   @echo [t1710] PASSED  >> $(TESTLOG)

t1713:
   @echo [t1713] /TR:AUI verification chain with /VERBOSE on 3C509B-COMBO >> $(TESTLOG)
   ${SEEDAPP} 3C509B-COMBO > $(ARTIFACTS)\T1713.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:AUI /VERBOSE >> $(ARTIFACTS)\T1713.LOG
   FIND "EEPROM transceiver selection verified." $(ARTIFACTS)\T1713.LOG > NUL
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1713.LOG > NUL
   @echo [t1713] PASSED  >> $(TESTLOG)

t1714:
   @echo [t1714] unchanged /TR with /VERBOSE on 3C509B-TP >> $(TESTLOG)
   ${SEEDAPP} INIT > $(ARTIFACTS)\T1714.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:TP /VERBOSE >> $(ARTIFACTS)\T1714.LOG
   FIND "Transceiver type is already configured to the requested value." $(ARTIFACTS)\T1714.LOG > NUL
   @echo [t1714] PASSED  >> $(TESTLOG)

t18xx:
   @echo [t18xx] 3C509_REV1: Verify 3C509 (ASIC revision 1) generation gates  >> $(TESTLOG)

t1801:
   @echo [t1801] LIST on 3C509-TP (ASIC revision 1): model, capability, and AUTO-bit ignore >> $(TESTLOG)
   ${SEEDAPP} 3C509-TP > $(ARTIFACTS)\T1801.LOG
   $(BINAPP) LIST >> $(ARTIFACTS)\T1801.LOG
   FIND "3Com 3C509-TP:" $(ARTIFACTS)\T1801.LOG > NUL
   FIND "(ASIC Revision 1)" $(ARTIFACTS)\T1801.LOG > NUL
   FIND "Plug and Play Capability = not supported" $(ARTIFACTS)\T1801.LOG > NUL
   FIND "Plug and Play = not supported" $(ARTIFACTS)\T1801.LOG > NUL
   FIND "Full Duplex Capability = not supported" $(ARTIFACTS)\T1801.LOG > NUL
   FIND "Full Duplex = not supported" $(ARTIFACTS)\T1801.LOG > NUL
   FIND "Transceiver = on-board TP" $(ARTIFACTS)\T1801.LOG > NUL
   FIND "Connectors = TP, AUI" $(ARTIFACTS)\T1801.LOG > NUL
   CALL $(ASSERTERS)\NFIND.BAT "auto select" $(ARTIFACTS)\T1801.LOG
   @echo [t1801] PASSED  >> $(TESTLOG)

t1802:
   @echo [t1802] /PNP rejection on 3C509-TP (ASIC revision 1) >> $(TESTLOG)
   ${SEEDAPP} 3C509-TP > $(ARTIFACTS)\T1802.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /PNP:DISABLED >> $(ARTIFACTS)\T1802.LOG
   FIND "PNP is not supported for this card type." $(ARTIFACTS)\T1802.LOG > NUL
   CALL $(ASSERTERS)\NFIND.BAT "Configuration completed successfully." $(ARTIFACTS)\T1802.LOG
   @echo [t1802] PASSED  >> $(TESTLOG)

t1803:
   @echo [t1803] /FULLDUPLEX rejection on 3C509-TP (ASIC revision 1) >> $(TESTLOG)
   ${SEEDAPP} 3C509-TP > $(ARTIFACTS)\T1803.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /FULLDUPLEX:DISABLED >> $(ARTIFACTS)\T1803.LOG
   FIND "Full duplex is not supported for this card type." $(ARTIFACTS)\T1803.LOG > NUL
   CALL $(ASSERTERS)\NFIND.BAT "Configuration completed successfully." $(ARTIFACTS)\T1803.LOG
   @echo [t1803] PASSED  >> $(TESTLOG)

t1804:
   @echo [t1804] /TR:AUTO rejection on 3C509-TP (ASIC revision 1) >> $(TESTLOG)
   ${SEEDAPP} 3C509-TP > $(ARTIFACTS)\T1804.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /TR:AUTO >> $(ARTIFACTS)\T1804.LOG
   FIND "AUTO transceiver selection requires a 3C509B-generation adapter." $(ARTIFACTS)\T1804.LOG > NUL
   CALL $(ASSERTERS)\NFIND.BAT "Configuration completed successfully." $(ARTIFACTS)\T1804.LOG
   @echo [t1804] PASSED  >> $(TESTLOG)

t1805:
   @echo [t1805] Boot ROM rejection on 3C509-TP (ASIC revision 1) >> $(TESTLOG)
   ${SEEDAPP} 3C509-TP > $(ARTIFACTS)\T1805.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /BADDRESS:C0000 /BSIZE:8 >> $(ARTIFACTS)\T1805.LOG
   FIND "Boot ROM configuration requires a 3C509B-generation adapter." $(ARTIFACTS)\T1805.LOG > NUL
   CALL $(ASSERTERS)\NFIND.BAT "completed successfully." $(ARTIFACTS)\T1805.LOG
   @echo [t1805] PASSED  >> $(TESTLOG)

t1806:
   @echo [t1806] combined valid + reject options perform no partial write >> $(TESTLOG)
   ${SEEDAPP} 3C509-TP > $(ARTIFACTS)\T1806.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /INT:3 >> $(ARTIFACTS)\T1806.LOG
   FIND "IRQ configuration completed successfully." $(ARTIFACTS)\T1806.LOG > NUL
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /INT:5 /PNP:DISABLED >> $(ARTIFACTS)\T1806.LOG
   FIND "PNP is not supported for this card type." $(ARTIFACTS)\T1806.LOG > NUL
   CALL $(ASSERTERS)\NFIND.BAT "Configuration completed successfully." $(ARTIFACTS)\T1806.LOG
   $(BINAPP) LIST >> $(ARTIFACTS)\T1806.LOG
   FIND "IRQ = 3" $(ARTIFACTS)\T1806.LOG > NUL
   CALL $(ASSERTERS)\NFIND.BAT "IRQ = 5" $(ARTIFACTS)\T1806.LOG
   @echo [t1806] PASSED  >> $(TESTLOG)

t1807:
   @echo [t1807] common CONFIGURE properties on 3C509-TP (ASIC revision 1) >> $(TESTLOG)
   ${SEEDAPP} 3C509-TP > $(ARTIFACTS)\T1807.LOG
   $(BINAPP) CONFIGURE /ADAPTERNUM:1 /INT:5 /IOBASE:0210 /MODEM:9600 /OPTIMIZE:SERVER /TR:TP >> $(ARTIFACTS)\T1807.LOG
   FIND "Configuration completed successfully." $(ARTIFACTS)\T1807.LOG > NUL
   $(BINAPP) LIST >> $(ARTIFACTS)\T1807.LOG
   FIND "IOBASE = 0210, IRQ = 5" $(ARTIFACTS)\T1807.LOG > NUL
   FIND "MODEM Interrupt Disable Time = 500 us (9600 bd)" $(ARTIFACTS)\T1807.LOG > NUL
   FIND "Optimization = Server" $(ARTIFACTS)\T1807.LOG > NUL
   FIND "Transceiver = on-board TP" $(ARTIFACTS)\T1807.LOG > NUL
   @echo [t1807] PASSED  >> $(TESTLOG)

t1808:
   @echo [t1808] SAVECONFIG on 3C509-TP (ASIC rev. 1) emits only common properties >> $(TESTLOG)
   ${SEEDAPP} 3C509-TP > $(ARTIFACTS)\T1808.LOG
   $(BINAPP) SAVECONFIG /OUTPUTFILE:$(ARTIFACTS)\T1808.BAT /EXECFILE:$(BINAPP) >> $(ARTIFACTS)\T1808.LOG
   FIND "Configuration restore batch file created:" $(ARTIFACTS)\T1808.LOG > NUL
   FIND "INT:10" $(ARTIFACTS)\T1808.BAT > NUL
   FIND "IOBASE:0300" $(ARTIFACTS)\T1808.BAT > NUL
   FIND "MODEM:25" $(ARTIFACTS)\T1808.BAT > NUL
   FIND "OPTIMIZE:DOS" $(ARTIFACTS)\T1808.BAT > NUL
   FIND "TR:TP" $(ARTIFACTS)\T1808.BAT > NUL
   CALL $(ASSERTERS)\NFIND.BAT "PNP" $(ARTIFACTS)\T1808.BAT
   CALL $(ASSERTERS)\NFIND.BAT "FULLDUPLEX" $(ARTIFACTS)\T1808.BAT
   CALL $(ASSERTERS)\NFIND.BAT "TR:AUTO" $(ARTIFACTS)\T1808.BAT
   CALL $(ASSERTERS)\NFIND.BAT "BADDRESS" $(ARTIFACTS)\T1808.BAT
   CALL $(ASSERTERS)\NFIND.BAT "BSIZE" $(ARTIFACTS)\T1808.BAT
   @echo [t1808] PASSED  >> $(TESTLOG)




# ################################################################
# The following are dummy definitions which exist only for declarative purposes.
# These tests are actually run by test.sh itself and never actually
# invoked through the TEST.MK file.
#
# The declarations are only recorded here for testreporter.py,
# so it can parse TEST.MK as source of truth for any kind of test definitions.
#
# Do not run these test targets, as they delibaretly do not implement
# actual regression tests.
# check test_saveconfig_line_lengths() test_hwlimits() functions in test.sh instead.
# ################################################################
#
# SAVECONFIG assertions (DUMMY DECLARATION ONLY)
SAVECONFIG_ASSERTIONS: SC00xx SC0001
SC00xx:
   @echo [SC00xx] DOS PSP Command Line Length Safety
SC0001:
   @echo [SC0001] Max 128 byte line length for DOS PSP not exceeded
#
# Hardware Limit assertions (DUMMY DECLARATION ONLY)
HARDWARE_LIMIT: HWL00xx HWL64 HWL128 HWL256
HWL00xx:
   @echo [HWLxx] Verify 3CCFGCLI startup with RAM and CPU ARCH constraints
HWL64:
   @echo [HWL64] 8086/8088 with 64 KB memory limit
HWL128:
   @echo [HWL128] 8086/8088 with 128 KB memory limit
HWL256:
   @echo [HWL256] 8086/8088 with 256 KB memory limit
