@ECHO OFF
REM ---------------------------------------------------------------------------
REM NFIND.BAT - negative FIND assertion helper
REM
REM Usage: CALL NFIND.BAT "text" file
REM
REM Passes when FIND does not find the requested text in the file.
REM Fails when the text is found, or when FIND itself fails.
REM
REM Inverts FIND's normal success semantics:
REM   FIND 0  = text found      -> assertion FAIL
REM   FIND 1  = text not found  -> assertion PASS
REM   FIND 2+ = FIND error      -> assertion FAIL
REM ---------------------------------------------------------------------------

FIND %1 %2 > NUL

IF ERRORLEVEL 2 GOTO FIND_ERROR
IF ERRORLEVEL 1 GOTO PASS

ECHO Assertion failed, unexpected text found: %1
GOTO FAIL

:FIND_ERROR
ECHO Assertion failed, FIND could not inspect: %2
GOTO FAIL

:PASS
REM Targeting basic DOS compatability. We can't use EXIT /B with a proper exit code, because it is not supported.
REM Instead, we use a dummy VER command to return a zero exit code to the caller
REM Silly trick, but makes it work in old DOS versions
VER > NUL
GOTO END

:FAIL
REM Targeting basic DOS compatability. We can't use EXIT /B with a proper exit code, because it is not supported.
REM Instead, we use a dummy FIND command to return a non-zero exit code to the caller
REM Silly trick, but makes it work in old DOS versions
FIND "__ASSERT_NEVER_MATCH__" NUL > NUL

:END
