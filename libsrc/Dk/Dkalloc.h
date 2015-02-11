/*
 *  Dkalloc.h
 *
 *  $Id$
 *
 *  Memory Allocation
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

#ifndef _DKALLOC_H
#define _DKALLOC_H

#define _RNDUP(SZ,AL)		((((SZ) + AL - 1) / AL) * AL)
#define _RNDUP_PWR2(SZ,AL)	(((SZ) + (AL - 1)) & ~(AL - 1))
#define ALIGN_2(x)		_RNDUP_PWR2((x), 2)
#define ALIGN_4(x)		_RNDUP_PWR2((x), 4)
#define ALIGN_8(x)		_RNDUP_PWR2((x), 8)
#define ALIGN_16(x)		_RNDUP_PWR2((x), 16)
#define ALIGN_32(x)		_RNDUP_PWR2((x), 32)

#define ALIGN_STR(len)		ALIGN_16(len)
#define ALIGN_VOIDP(len)	_RNDUP_PWR2((len), sizeof (void *))

#define AV_FREE_MARK 0x00deadbeeffeedba00LL	 /* in 2nd word of free of over 8 b */

#define NEW_VAR(type,var) \
	type *var = (type *) dk_alloc (sizeof (type))

#define B_NEW_VAR(type,var) \
	type *var = (type *) tlsf_base_alloc (sizeof (type))

#define DBG_NEW_VAR(file, line, type,var) \
	type *var = (type *) dbg_malloc (file, line, sizeof (type))

#define NEW_VARZ(type, var) \
	NEW_VAR(type,var); \
	memzero (var, sizeof (type))


#define B_NEW_VARZ(type, var) \
	B_NEW_VAR(type,var); \
	memzero (var, sizeof (type))

#define NEW_BOX_VAR(type,var) \
	type *var = (type *) dk_alloc_box (sizeof (type), DV_BIN)

#define NEW_BOX_VARZ(type, var) \
	NEW_BOX_VAR(type,var); \
	memset (var, 0, sizeof (type))


/* Dkalloc.c */
void dk_memory_initialize (int do_malloc_cache);
int dk_is_alloc_cache (size_t sz);
void dk_cache_allocs (size_t sz, size_t cache_sz);
EXE_EXPORT (void *, dk_alloc, (size_t c));
EXE_EXPORT (void *, dk_try_alloc, (size_t c));
EXE_EXPORT (void, dk_free, (void *ptr, size_t sz));
void dk_end_ck (char *ptr, ssize_t sz);
void dk_check_end_marks (void);
void dk_mem_stat (char *out, int max);
void thr_free_alloc_cache (thread_t * thr);
void malloc_cache_clear (void);

#ifdef MALLOC_DEBUG
# include <util/dbgmal.h>



#ifndef _USRDLL
#ifndef EXPORT_GATE
# define dk_alloc(sz)		dbg_malloc (__FILE__, __LINE__, (sz))
# define dk_try_alloc(sz)	dbg_malloc (__FILE__, __LINE__, (sz))
# define dk_free(ptr, sz)	dbg_free_sized (__FILE__, __LINE__, (ptr), (sz))

#endif
#endif
void dk_alloc_assert (void *ptr);
#else
# define dk_alloc_assert(ptr) ;
#endif

#ifdef MALLOC_DEBUG

#define DBG_NAME(nm) 		dbg_##nm
#define DBG_PARAMS 		const char *file, int line,
#define DBG_PARAMS_0 		const char *file, int line
#define DBG_ARGS 		file, line,
#define DBG_ARGS_0 		file, line

#define DK_ALLOC(SIZE) 		dbg_malloc(DBG_ARGS (SIZE))
#define DK_FREE(BOX,SIZE) 	dbg_free_sized(DBG_ARGS (BOX), (SIZE))

#else
#define DBG_NAME(nm) 		nm
#define DBG_PARAMS
#define DBG_PARAMS_0 		void
#define DBG_ARGS
#define DBG_ARGS_0
#define DK_ALLOC 		dk_alloc
#define DK_FREE 		dk_free
#endif

#ifdef MALLOC_DEBUG
void *dbg_dk_alloc (DBG_PARAMS size_t c);
void *dbg_dk_try_alloc (DBG_PARAMS size_t c);
#endif

void dk_set_initial_mem (size_t);

#define tlsf_base_alloc dk_alloc


#define WITH_TLSF(n) {


#define END_WITH_TLSF }



#endif
