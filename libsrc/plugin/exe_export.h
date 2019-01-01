/*
 *  exe_export.h
 *
 *  $Id$
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

#ifndef _EXE_EXPORT_H
#define _EXE_EXPORT_H

#ifdef __cplusplus
#define EXE_EXPORT_LINKAGE "C"
#else
#define EXE_EXPORT_LINKAGE
#endif

#define EXE_EXPORT_TYPED(rettype,name) \
extern EXE_EXPORT_LINKAGE rettype name

#ifdef _USRDLL

#define EXE_EXPORT(rettype,name,arglist) \
typedef rettype typeof__##name arglist; \
extern EXE_EXPORT_LINKAGE rettype name arglist

#else

#define EXE_EXPORT(rettype,name,arglist) \
typedef rettype typeof__##name arglist; \
extern EXE_EXPORT_LINKAGE rettype name arglist

#endif

struct _gate_export_item_s { void *_ptr; const char *_name; };
typedef struct _gate_export_item_s _gate_export_item_t;

extern _gate_export_item_t _gate_export_data[];

extern EXE_EXPORT_LINKAGE int _gate_export (_gate_export_item_t *tgt);

#endif
