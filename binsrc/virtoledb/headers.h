/*  headers.h 
 *
 *  $Id$
 *
 *  Include file for standard system include files, or 
 *  project specific include files that are used frequently,
 *  but are changed infrequently.
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2014 OpenLink Software
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
 *  
*/

#ifndef HEADERS_H
#define HEADERS_H

/* Don't include everything from windows.h, but always bring in OLE 2 support */
//#define WIN32_LEAN_AND_MEAN
#define INC_OLE2

#define STRICT			/* Strict type checking for Window APIs */

#include <windows.h>

#include <olectl.h>

#include <oledb.h>
#include <oledberr.h>

#include <msdadc.h>
#include <msdaguid.h>

#include <sql.h>
#include <sqlext.h>

#include <stdio.h>
#include <stdlib.h>
#include <tchar.h>

#ifdef _MSC_VER
#pragma warning(disable:4786)
#endif

#include <algorithm>
#include <list>
#include <map>
#include <memory>
#include <set>
#include <string>
#include <strstream>
#include <vector>

#include "os.h"
#include "virtoledb.h"

#endif
