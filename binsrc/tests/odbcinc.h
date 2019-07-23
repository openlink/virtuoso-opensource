/*
 *  odbcinc.h
 *
 *  $Id$
 *
 *  Include the ODBC header, whichever appropriate
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2019 OpenLink Software
 *
 *  This project is free software; you can redistribute it and/or modify it
 *  under the terms of the GNU General Public License as published by the
 *  Free Software Foundation; only version 2 of the License, dated June 1991.
 *
 *  This program is distributed in the hope that it will be useful, but
 *  WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 *  General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 *
 */

#ifdef WIN32
# include <windows.h>
#endif
#include <sql.h>
#include <sqlext.h>
#include <sqlucode.h>

#ifndef SQL_WCHAR
#define SQL_WCHAR -8
#endif

#ifndef SQL_WVARCHAR
#define SQL_WVARCHAR -9
#endif

#ifndef SQL_WLONGVARCHAR
#define SQL_WLONGVARCHAR -10
#endif

#ifndef SQL_C_WCHAR
#define SQL_C_WCHAR	SQL_WCHAR
#endif

#ifndef WIN32
#ifndef SQLLEN
#define SQLLEN SDWORD
#endif
#ifndef SQLULEN
#define SQLULEN UDWORD
#endif
#ifndef SQLSETPOSIROW
#define SQLSETPOSIROW SQLUSMALLINT
#endif
#endif

#include <virtext.h>
/*#define SQL_ENCRYPT_CONNECTION 5004
#define SQL_SHUTDOWN_ON_CONNECT 5005*/
