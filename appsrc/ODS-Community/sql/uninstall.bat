@echo off
rem ---------------------------------------------------
rem uninstall.bat
rem MS Windows script for deinstalling Photo modules
rem Copyright (C) 2004 OpenLink Software
rem ---------------------------------------------------

if "%1" EQU "" goto error
if "%2" EQU "" goto error

isql %1 dba %2 run_uninstall.sql -i > errors.out
goto end

:error
echo.
echo   Usage: %0 server dba_pwd
echo.
echo   Where:
echo     'server' is the address (host:port) of the target virtuoso server
echo     'dba_pwd' is the password for the 'dba' account
echo.

:end

