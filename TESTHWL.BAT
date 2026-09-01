@ECHO OFF

ECHO [HWLIMIT] target memsizekb=%1

ECHO Running MEM command (will expectedly fail on 64K limit) ...
MEM

ECHO Running 3CCFGCLI command ...
BIN\3CCFGCLI.EXE HELP
IF ERRORLEVEL 1 GOTO FAIL

ECHO HWLIMIT PASS memsizekb=%1
GOTO END

:FAIL
ECHO HWLIMIT FAIL memsizekb=%1

:END
EXIT
