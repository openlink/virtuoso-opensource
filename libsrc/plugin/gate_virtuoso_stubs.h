/*
 *  gate_virtuoso_stubs.h
 *
 *  $Id$
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
 *
 */

#include "Dk.h"
#include "exe_export.h"

/* These functions are here to avoid changing files in libsrc/util */
EXE_EXPORT (void	, dbg_malloc_enable, (void));
EXE_EXPORT (void *	, dbg_malloc, (const char *file, u_int line, size_t size));
EXE_EXPORT (void *	, dbg_calloc, (const char *file, u_int line, size_t num, size_t size));
EXE_EXPORT (void	, dbg_free, (const char *file, u_int line, void *data));
EXE_EXPORT (char *	, dbg_strdup, (const char *file, u_int line, const char *str));
EXE_EXPORT (void *	, dbg_realloc, (const char *file, u_int line, void *old, size_t size));
