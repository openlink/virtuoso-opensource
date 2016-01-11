rem
rem  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
rem  project.
rem
rem  Copyright (C) 1998-2016 OpenLink Software
rem
rem  This project is free software; you can redistribute it and/or modify it
rem  under the terms of the GNU General Public License as published by the
rem  Free Software Foundation; only version 2 of the License, dated June 1991.
rem
rem  This program is distributed in the hope that it will be useful, but
rem  WITHOUT ANY WARRANTY; without even the implied warranty of
rem  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
rem  General Public License for more details.
rem
rem  You should have received a copy of the GNU General Public License along
rem  with this program; if not, write to the Free Software Foundation, Inc.,
rem  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
rem

@echo off

rem
rem Sanity check
rem
if not exist %CD%\maildrop.dll (
    echo maildrop.dll not found in %CD%
    goto end
)
if not exist %CD%\odbc_mail.exe (
    echo odbc_mail.exe not found in %CD%
    goto end
)
if not exist %CD%\smtpreg.vbs (
    echo smtpreg.vbs not found in %CD%
    goto end
)

rem
rem /register
rem
if "%1" == "/register" (
    rem Need mail domain name for filter
    if "%2" == "" goto usage

    rem Self register DLL
    %windir%\system32\regsvr32 /s maildrop.dll

    rem Add OpenLink MailDrop Sink
    %windir%\system32\cscript /nologo smtpreg.vbs     /add 1 OnArrival "OpenLink MailDrop" OpenLink.MailDrop "rcpt to=*@%2"

    rem Set command to execute for incoming mail
    %windir%\system32\cscript /nologo smtpreg.vbs /setprop 1 OnArrival "OpenLink MailDrop" Sink Command %CD%\odbc_mail.exe

    rem Display
    rem %windir%\system32\cscript /nologo smtpreg.vbs /enum

rem
rem /unregister
rem
) else if "%1" == "/unregister" (
    %windir%\system32\cscript /nologo smtpreg.vbs /remove 1 OnArrival "OpenLink MailDrop"
    %windir%\system32\regsvr32 /s /u maildrop.dll

) else (
  :usage
    echo Usage: %0 /register your.domain.name
    echo Usage: %0 /unregister
)

:end
