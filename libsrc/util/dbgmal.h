/*
 *  dbgmal.h
 *
 *  $Id$
 *
 *  Debugging malloc package
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
 *  
*/

#ifndef _DBGMAL_H
#define _DBGMAL_H
#include <string.h>

/*
 *  Signal that causes memory trace to be written
 *  If not specified, then no handler will be installed
 */
#ifdef UNIX
# define DBGMAL_SIGNAL	SIGUSR2
#endif

#ifndef MALLOC_DEBUG
#ifdef MALLOC_STRESS
!!! Using MALLOC_STRESS has no sence if MALLOC_DEBUG is not set
#endif
#endif

#define MALMAGIC_OK	0xA110CA99
#define MALMAGIC_FREED	0xA110CA98
#define MALPMAGIC_OK	0xA110CA97
#define MALPMAGIC_FREED	0xA110CA96

#ifdef MALLOC_DEBUG
# define malloc(X)	dbg_malloc(__FILE__,__LINE__,X)
# define realloc(B,S)	dbg_realloc(__FILE__,__LINE__,B,S)
# define calloc(X,Y)	dbg_calloc(__FILE__,__LINE__,X,Y)
# define free(X)	dbg_free(__FILE__,__LINE__,X)
# define mallocp(X,P)	dbg_mallocp(__FILE__,__LINE__,X,P)
# define callocp(X,Y,P)	dbg_callocp(__FILE__,__LINE__,X,Y,P)
# define freep(X,P)	dbg_freep(__FILE__,__LINE__,X,P)
# ifndef __GNUC__
#  undef strdup
#  define strdup(s)	dbg_strdup (__FILE__, __LINE__, s)
# else
#  undef strdup
#  define strdup(s) \
    ({ char *tmp = s; \
       strcpy (malloc (strlen (tmp) + 1), tmp); \
     })
extern int dbg_allows_free_nulls;
# endif

#else
#define mallocp(X,P) malloc (X)
#define callocp(X,P) calloc (X)
#define freep(X,P) free (X)
#endif


BEGIN_CPLUSPLUS

void	dbg_malloc_enable(void);
void *	dbg_malloc (const char *file, u_int line, size_t size);
void *	dbg_realloc (const char *file, u_int line, void *old, size_t size);
void *	dbg_calloc (const char *file, u_int line, size_t num, size_t size);
void	dbg_free (const char *file, u_int line, void *data);
void	dbg_free_sized (const char *file, u_int line, void *data, size_t sz);
void *	dbg_mallocp (const char *file, u_int line, size_t size, void *pool);
void *	dbg_callocp (const char *file, u_int line, size_t num, size_t size, void *pool);
void	dbg_freep (const char *file, u_int line, void *data, void *pool);
char *	dbg_strdup (const char *file, u_int line, const char *str);
#define DBG_MALSTATS_ALL 0
#define DBG_MALSTATS_NEW 1
#define DBG_MALSTATS_LEAKS 2
void	dbg_malstats (FILE *, int mode);
int	dbg_mark (char *name);
int	dbg_unmark (char *name);
size_t  dbg_mal_count (const char *name, u_int line);

void	 dbg_dump_mem(void);

const char *dbg_find_allocation_error (void *data, void *expected_pool);

size_t dbg_malloc_get_current_total (void);
#ifdef MALLOC_STRESS
extern void dbg_malloc_set_hard_memlimit (size_t consumption);
#define dbg_malloc_hit(N) dbg_malloc_hit_impl(__FILE__, __LINE__, (N))
extern void dbg_malloc_hit_impl (const char *file, u_int line, const char *name);
extern void dbg_malloc_set_hit_memlimit (const char *name, size_t consumption);
#else
#define dbg_malloc_set_hard_memlimit(C) do { ; } while (0)
#define dbg_malloc_hit(N) do { ; } while (0)
#define dbg_malloc_set_hit_memlimit(N,C) do { ; } while (0)
#endif

END_CPLUSPLUS

#endif

