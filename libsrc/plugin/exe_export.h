/*
 *  exe_export.h
 *
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2016 OpenLink Software
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

#ifndef _EXE_EXPORT_H
#define _EXE_EXPORT_H

#define EXE_EXPORT_TYPED(rettype,name) \
extern rettype name

#ifdef _USRDLL

#define EXE_EXPORT(rettype,name,arglist) \
typedef rettype typeof__##name arglist; \
extern rettype name arglist

#else

#define EXE_EXPORT(rettype,name,arglist) \
typedef rettype typeof__##name arglist; \
extern rettype name arglist

#endif

#endif
