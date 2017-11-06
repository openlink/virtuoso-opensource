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
 *  Copyright (C) 1998-2017 OpenLink Software
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

#define DBGMAL_MAGIC_OK			0xA110CA99
#define DBGMAL_MAGIC_FREED		0xA110CA98
#define DBGMAL_MAGIC_POOL_OK		0xA110CA97
#define DBGMAL_MAGIC_POOL_FREED		0xA110CA96
#define DBGMAL_MAGIC_COUNT_OK		0xA110CA95
#define DBGMAL_MAGIC_COUNT_FREED	0xA110CA94

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

#define AAAL_BUCKETS_COUNT 43 /* should be a prime */

typedef struct malrec_s
{
  const char *	mr_fname;
  u_int		mr_linenum;
  long		mr_numalloc;
  long		mr_prevalloc;
  long		mr_numfree;
  long		mr_prevfree;
  size_t	mr_totalsize;
  size_t	mr_prevsize;
  void *	mr_aaal_malhdrs[AAAL_BUCKETS_COUNT];
  long		mr_aaal_count;
} malrec_t;

typedef struct malhdr_s
{
  uint32	magic;
  malrec_t *	origin;
  size_t	size;
  void *	pool;
  void *	next_malhdr;
} malhdr_t;

extern void * dbgmal_mtx;
#define	dbgmal_is_enabled() (NULL != dbgmal_mtx)

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
void	dbg_count_like_malloc (const char *file, u_int line, malhdr_t *thing, size_t size);
void	dbg_count_like_free (const char *file, u_int line, malhdr_t *thing);
#define DBG_MALSTATS_ALL 0
#define DBG_MALSTATS_NEW 1
#define DBG_MALSTATS_LEAKS 2
void	dbg_malstats (FILE *, int mode);
int	dbg_mark (const char *name);
int	dbg_unmark (const char *name);
size_t  dbg_mal_count (const char *name, u_int line);

void	 dbg_dump_mem(void);

extern uint32 dbg_malloc_magic_of_data (void *data);
extern void *dbg_mp_of_data (void *data);

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

