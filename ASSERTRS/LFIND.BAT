@ECHO OFF
REM LFIND.BAT
REM
REM Usage:
REM   LFIND file "label" "value"

FIND %2 %1 | FIND %3 > NUL
