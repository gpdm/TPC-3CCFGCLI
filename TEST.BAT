@ECHO OFF

REM *** Default to smoke tests ***
SET TARGET=smoke

REM *** Override MAKE target if argument %1 given ***
IF NOT "%1/" == "/" SET TARGET=%1

\TASM\BIN\MAKE -f TEST.MK %TARGET% 
