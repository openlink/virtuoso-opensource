/*
 *  sqlver.c
 *
 *  $Id$
 *
 *  Build information
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2018 OpenLink Software
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

#include "sqlver.h"
#include "wi.h"

const char *build_date = __DATE__;		/* eg. Jul 16 1996 */

/* IvAn/VC6port/000725 VC6 has a bug: you can't use /D NAME="\"string\"" cmd-line arg sometimes */
#ifdef _MSC_VER
#ifdef _WIN64
const char *build_host_id = "x86_64-generic-win-64";
const char *build_opsys_id = "Win64";
#else
const char *build_host_id = "i686-generic-win-32";
const char *build_opsys_id = "Win32";
#endif
#else
const char *build_host_id = HOST;			/* eg. i586-pc-linux-gnu */
const char *build_opsys_id = OPSYS;			/* eg. Linux */
#endif

const char *build_special_server_model = " "
; /* eg. empty or integration binaries */

#if 0
const char *build_thread_model;			/* eg. Threads or Fibers */
#endif

void
build_set_special_server_model (const char *new_model)
{
  build_special_server_model = new_model;
}
