@ECHO OFF
REM Default starter for 3CCFGCLI Hardware Compliance Read checks.
REM
REM It detects the installed EtherLink III model and dispatches
REM the matching HWCREAD.MK or HWCWRITE.MK target.
REM The complete test sequence stays in MAKE.
REM ERRORLEVEL handling deliberately stays inside this batch file.



REM Vars Init
SET ARTIFACT=
SET LOGFILE=HWCINIT.LOG
SET DETECTED_NIC=UNKNOWN
SET TARGET=
SET MKFILE=
SET ROMTEST=

REM Sanitize 
IF EXIST %LOGFILE% DEL %LOGFILE% > NUL

REM IF NOT EXIST ARTIFACT\NUL MD ARTIFACT
REM IF EXIST ARTIFACT\HWCTEST.LOG DEL ARTIFACT\HWCTEST.LOG > NUL
REM IF EXIST ARTIFACT\*.SET DEL ARTIFACT\*.SET > NUL


REM Perform initial hardware scan
3CCFGCLI.EXE LIST > %LOGFILE%


REM CLI dispatch
REM I know, it's superugly, but this make arguments work case-insensitive.
REM Yes, an invalid argument will cause a LABEL NOT FOUND error.
REM But it's just a bloody batch for HWC regressions, so who cares?
GOTO O_%1

:O_
ECHO %0: Invalid command line argument.
GOTO HELP

:O_READ
SET MKFILE=HWCREAD.MK
SET TARGET=hwcr
GOTO HWDETECT

:O_READROM
SET MKFILE=HWCREAD.MK
SET TARGET=hwcr
SET ROMTEST=-DROM_TEST
GOTO HWDETECT

:O_CONFIG
SET MKFILE=HWCWRITE.MK
SET TARGET=hwcw
GOTO HWDETECT

:O_ROMCONFIG
SET MKFILE=HWCWRITE.MK
SET TARGET=hwcw
SET ROMTEST=-DROM_TEST
GOTO HWDETECT


:HELP
ECHO.
ECHO 3CCFGCLI Hardware Compliance Tests
ECHO.
ECHO Usage:
ECHO   %0 READ 
ECHO   %0 READROM
ECHO   %0 CONFIG
ECHO   %0 ROMCONFIG
ECHO.
ECHO Commands:
ECHO   READ       3CCFGCLI observes while original 3C5X9CFG runs config commands.
ECHO   READROM    same as READ, but include Boot ROM tests
ECHO   CONFIG     3CCFGCLI performs all configure commands and read-backs.
ECHO   ROMCONFIG  Same as CONFIG, but include Boot ROM tests
ECHO.
GOTO OK


:HWDETECT
ECHO 3Com EtherLink III card detection running ...

FIND "3Com 3C509B-TPCoax:" %LOGFILE% > NUL
IF NOT ERRORLEVEL 1 GOTO BTPC

FIND "3Com 3C509B-TPO:" %LOGFILE% > NUL
IF NOT ERRORLEVEL 1 GOTO BTPO

FIND "3Com 3C509B-Combo:" %LOGFILE% > NUL
IF NOT ERRORLEVEL 1 GOTO BCOMBO

FIND "3Com 3C509B-TP:" %LOGFILE% > NUL
IF NOT ERRORLEVEL 1 GOTO BTP

FIND "3Com 3C509B:" %LOGFILE% > NUL
IF NOT ERRORLEVEL 1 GOTO BCOAX

FIND "3Com 3C509-TP:" %LOGFILE% > NUL
IF NOT ERRORLEVEL 1 GOTO TP

ECHO Unsupported EtherLink III model.
GOTO FAIL


:BTP
ECHO Detected 3C509B-TP.
SET DETECTED_NIC=BTP
GOTO RUN

:BCOAX
ECHO Detected 3C509B-COAX.
SET DETECTED_NIC=BCOAX
GOTO RUN

:BCOMBO
ECHO Detected 3C509B-Combo.
SET DETECTED_NIC=BCOMBO
GOTO RUN

:BTPO
ECHO Detected 3C509B-TPO.
SET DETECTED_NIC=BTPO
GOTO RUN

:BTPC
ECHO Detected 3C509B-TPCoax.
SET DETECTED_NIC=BTPC
GOTO RUN

:TP
ECHO Detected 3C509-TP.
SET DETECTED_NIC=TP
GOTO RUN


:RUN
REM As NIC is now detected, reset LOGFILE and ARTIFACT paths
SET INITLOG=%LOGFILE%
SET ARTIFACT=%DETECTED_NIC%\ARTIFACT
SET LOGFILE=%DETECTED_NIC%\HWCREAD.LOG

REM Ensure output directories exist
IF NOT EXIST %DETECTED_NIC%\NUL MD %DETECTED_NIC%
IF NOT EXIST %ARTIFACT%\NUL MD %ARTIFACT%

REM Move INITLOG to the final LOGFILE and cleanup
COPY %INITLOG% %LOGFILE%
DEL %INITLOG%
SET INITLOG=

ECHO Running test target %TARGET% for detected NIC: %DETECTED_NIC% >> %LOGFILE%
ECHO Running test target %TARGET% for detected NIC: %DETECTED_NIC%

ECHO invoke: MAKE -f%MKFILE% -DCARD_%DETECTED_NIC% %ROMTEST% %TARGET% >> %LOGFILE%
ECHO invoke: MAKE -f%MKFILE% -DCARD_%DETECTED_NIC% %ROMTEST% %TARGET%

MAKE -f%MKFILE% -DCARD_%DETECTED_NIC% %ROMTEST% %TARGET%
IF ERRORLEVEL 1 GOTO FAIL

REM Create post-configurative config dump using original 3C5X0CFG binary
ECHO Taking post-configuration dump using 3CCFGCLI >> %LOGFILE%
ECHO Taking post-configuration dump using 3CCFGCLI
REM clear keyboard input buffer
stuffit 0
REM load key macro sequence to control 3C5X9CFG to export a config dump
stuffit +2 @62 +2 9 9 13 +2 9 13 +2 "%ARTIFACT%\%TARGET%.SET" +2 13 +2 27 27 13
3c5x9cfg
IF NOT EXIST %ARTIFACT%\%TARGET%.SET GOTO FAIL

GOTO OK


:FAIL
REM Deliberately return a nonzero DOS ERRORLEVEL.
ECHO Hardware Compliance Test FAILED. See %LOGFILE% for more details. >> %LOGFILE%
ECHO Hardware Compliance Test FAILED. See %LOGFILE% for more details.
FIND "HWC-FAILURE-SENTINEL" %LOGFILE% > NUL
GOTO END

:OK
ECHO Hardware Compliance Test PASSED. >> %LOGFILE%
ECHO Hardware Compliance Test PASSED.
REM Reset ERRORLEVEL to zero using text known to exist in a successful LIST.
FIND "3Com " %LOGFILE% > NUL

:END