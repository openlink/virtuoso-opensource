rem
rem  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
rem  project.
rem
rem  Copyright (C) 1998-2019 OpenLink Software
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
rem
@echo off

midl -nologo -out gen maildrop.idl
if errorlevel 1 goto :fail

midl -nologo -out gen SmtpEvent.idl
if errorlevel 1 goto :fail

midl -nologo -out gen CDOSys.idl
if errorlevel 1 goto :fail

midl -nologo -out gen msado15.idl
if errorlevel 1 goto :fail

midl -nologo -out gen MailMsg.idl
if errorlevel 1 goto :fail

midl -nologo -out gen Seo.idl
if errorlevel 1 goto :fail

goto end

:fail
echo !! GENERATION FAILED
echo !! set your INCLUDE environment variable to include PLATFORM_SDK\Include

:end
