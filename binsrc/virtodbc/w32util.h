/*
 *  w32util.h
 *
 *  $Id$
 *
 *  Common includes for win32 utilties
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2015 OpenLink Software
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
 */

#ifndef _UNICODE
# define UNICODE
#endif
#ifndef _UNICODE
# define _UNICODE
#endif
#ifndef STRICT
# define STRICT
#endif

#ifndef _NO_PRAGMA_WARNINGS
#pragma warning(disable: 4100) // unreferenced formal parameter
#pragma warning(disable: 4214) // nonstandard extension used
#pragma warning(disable: 4201) // nameless unions are part of C++
#pragma warning(disable: 4514) // unreferenced inlines are common
#pragma warning(disable: 4710) // function ... not expanded
#pragma warning(disable: 4711) // function selected for inline expansion
#endif //!_NO_PRAGMA_WARNINGS

/* Microsoft has, in their infinite wisdom, decided to make swprintf
 * secure: it now requires a size parameter at pos 2. To avoid crashes, and
 * make the code portable with different SDKs, we add this macro to
 * disable this new behavior for now. */
#define _CRT_NON_CONFORMING_SWPRINTFS

#include <windows.h>
#include <commctrl.h>
#include <string.h>
#include <memory.h>
#include <malloc.h>
#include <tchar.h>
#include <odbcinst.h>
#include <stdio.h>
#include <sql.h>
#include <sqlext.h>

#define NUMCHARS(X)	(sizeof(X)/sizeof(TCHAR))

#define OPTION_TRUE(X)	((X) && (X) != 'N' && (X) != '0')

void trace (LPCTSTR fmt, ...);
