@ECHO OFF

\TASM\BIN\MAKE -f TEST.MK smoke

if "%1/" == "/" EXIT
