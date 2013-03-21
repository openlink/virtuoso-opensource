/*
 *  Dkalloc.c
 *
 *  $Id$
 *
 *  Memory Allocation
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2013 OpenLink Software
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

#ifdef UNIX
long init_brk;
#endif

#ifndef MALLOC_DEBUG

#ifdef dk_alloc
#undef dk_alloc
#endif

#ifdef dk_free
#undef dk_free
#endif

extern void dk_box_initialize (void);

#if !defined (NO_MALLOC_CACHE) && !defined (PURIFY) && !defined (VALGRIND)
# if defined (UNIX) || defined (WIN32)
#  define CACHE_MALLOC
# endif
#endif

#define NO_SIZE ((size_t) -1)

#ifdef CACHE_MALLOC



#define AV_LIST_MEMBERS \
  caddr_t *	av_first;\
  int	av_gets;\
  unsigned short	av_fill;\
  unsigned short	av_max;\
  int			av_n_empty;\
  int			av_n_full


typedef struct av_list_s
{
  AV_LIST_MEMBERS;
} av_list_t;

typedef struct av_s_list_s
{
  AV_LIST_MEMBERS;
  dk_mutex_t av_mtx;
} av_s_list_t;


#define MEMBLOCKS_N_WAYS 16
#define MEMBLOCKS_MASK 15
av_s_list_t memblock_set[MAX_CACHED_MALLOC_SIZE / 8][MEMBLOCKS_N_WAYS];
int nth_memblock;
#define NTH_MEMB ((++nth_memblock) & MEMBLOCKS_MASK)



#define AV_NOT_IN_USE 0xffff			 /* in av_fill */

#define AV_FREE_MARK 0x00deadbeeffeedba00LL	 /* in 2nd word of free of over 8 b */
#define AV_ALLOC_MARK 0x00a110cfcacfe00LL

#define AV_CHECK_DOUBLE_FREE(av, thing, len)	\
  { \
    if (len > 8)							\
    {									\
    if (AV_FREE_MARK == ((int64*)thing)[1]) av_check_double_free ((av_list_t *)av, thing, len); \
    ((int64*)thing)[1] = AV_FREE_MARK; \
    }									\
  }


#define AV_MARK_ALLOC(thing, len) \
  if (len > 8) ((int64*)thing)[1] = AV_ALLOC_MARK;

#define AV_GET(p, av, hit, miss) \
{\
  if ((p = av->av_first)) \
    { \
      av->av_fill--; \
      av->av_gets++; \
      av->av_first = *(caddr_t**)p; \
      if ((av->av_fill && !av->av_first) || (!av->av_fill && av->av_first)) GPF_T1 ("av fill and list not in sync, likely double free"); \
      hit; \
    } \
  else  \
    {\
      av->av_n_empty++; \
      miss;\
    } \
}


#define AV_PUT(av, thing, fit, full) \
{ \
  if (av->av_fill >= av->av_max) \
    { \
      av->av_n_full++; \
    full; \
    } \
  else  \
    { \
      *(caddr_t**)thing = av->av_first; \
      av->av_first = (caddr_t*) thing; \
      av->av_fill++; \
      fit; \
    } \
}


void
av_check (av_list_t * av, void *thing)
{
  int ctr = 0;
  caddr_t *ptr;
  for (ptr = av->av_first; ptr; ptr = *(caddr_t **) ptr)
    {
      if (ptr == (caddr_t *) thing)
	GPF_T1 ("Double free confirmed in alloc cache");
      ctr++;
      if (ctr > av->av_max + 10)
	GPF_T1 ("av list longer than max, probably cycle");
    }
}


void
av_check_double_free (av_list_t * av1, void *thing, int len)
{
  /* look at the av list and all the av lists for the size.   */
  int way;
  av_check (av1, thing);
  for (way = 0; way < MEMBLOCKS_N_WAYS; way++)
    {
      av_s_list_t *av = &memblock_set[len / 8][way];
      if ((av_list_t *) av == av1)
	continue;
      av_check ((av_list_t *) av, thing);
    }
  log_error ("Looks like double free but the block is not twice in alloc cache, so proceeding");
}


void
av_clear (av_list_t * av)
{
  caddr_t *ptr, *next;
  for (ptr = av->av_first; ptr; ptr = next)
    {
      next = *(caddr_t **) ptr;;
      free (ptr);
    }
  av->av_first = NULL;
  av->av_fill = 0;
}


void
av_s_init (av_s_list_t * av, int sz)
{
  memset (av, 0, sizeof (av_s_list_t));
  av->av_max = sz;
  dk_mutex_init (&av->av_mtx, MUTEX_TYPE_SHORT);
}


void
av_adjust (av_list_t * av, int sz)
{
  /* if if often empty and empty at least half as often as full, increase size.  Do not increase past 40000
   * forget stats after 1000000 gets */
  if (av->av_n_empty > av->av_gets / 20 &&
      av->av_n_full > av->av_n_empty / 2 &&
      av->av_max < 160000 / sz)
    {
      av->av_n_empty = 0;
      av->av_n_full = 0;
      av->av_max = 1 + av->av_max * 2;
      av->av_gets = 1;
    }
  else if (av->av_gets > 1000000)
    {
      av->av_gets = 0;
      av->av_n_full = 0;
      av->av_n_empty = 0;
    }
}


#if defined (MTX_DEBUG) || defined (MTX_METER)
#define MALLOC_CACHE_ENTRY_MTX(sz) \
  { char name[20]; snprintf (name, sizeof (name), "MEM:%ld", (long)sz);	\
  mutex_option (&memblock_set[sz/8][way].av_mtx, name, NULL, NULL); }
#else
#define MALLOC_CACHE_ENTRY_MTX(sz)
#endif

# define MALLOC_CACHE_ENTRY(sz,rcsz) \
  if (!memblock_set[sz/8][way].av_max) \
  { \
    av_s_init (&memblock_set[sz/8][way], rcsz); \
    MALLOC_CACHE_ENTRY_MTX(sz); \
  }
#endif

#ifdef MEMDBG
# define ADD_END_MARK(sz)	((sz) + sizeof (int32))
# define SET_END_MARK(ptr, sz)	((int32*) (((char *) (ptr)) + (sz)))[0] = -3
# define SET_RIP_MARK(ptr, sz)	((int32*) (((char *) (ptr)) + (sz)))[0] = -4
# define CHECK_END_MARK(ptr, sz) \
  switch (((int32 *) (((char *) (ptr)) + (sz)))[0]) \
    { \
      case -4: GPF_T1 ("End mark replaced with RIP"); \
      case -3: break; \
      default: GPF_T1 ("End mark overwritten"); \
    }
# define CHECK_RIP_MARK(ptr, sz) \
  switch (((int32 *) (((char *) (ptr)) + (sz)))[0]) \
    { \
      case -3: GPF_T1 ("RIP mark replaced with end mark"); \
      case -4: break; \
      default: GPF_T1 ("RIP mark overwritten"); \
    }

#else
# define ADD_END_MARK(sz)	(sz)
# define SET_END_MARK(ptr, sz)
# define SET_RIP_MARK(ptr, sz)
# define CHECK_END_MARK(ptr, sz)
# define CHECK_RIP_MARK(ptr, sz)
#endif


/*
 * For TRUE64 unix malloc package tuning
 */
#if defined (__osf__)
const int __delayed_free = 0;	/* no delay; was 2 */
const int __fast_free_max = 25;	/* was 13 */
const int __first_fit = 0;
const unsigned long __madvisor = 0;
const int __max_cache = 15;
const size_t __mingrow = 49152;
const double __mingrowfactor = 0.1;
const size_t __minshrink = 16384;
const double __minshrinkfactor = 0.001;
const unsigned long __noshrink = 1;	/* do not shrink mem; was 0 */
const unsigned long __sbrk_override = 0;
const unsigned long __small_buff = 0;
const unsigned long __taso_mode = 0;
#endif


#ifdef CACHE_MALLOC

void
malloc_cache_clear (void)
{
  int inx, way;
  thread_t *thr = THREAD_CURRENT_THREAD;
  if (thr->thr_alloc_cache)
    {
      av_list_t *blocks = (av_list_t *) thr->thr_alloc_cache;
      for (inx = 0; inx < MAX_CACHED_MALLOC_SIZE / 8; inx++)
	av_clear (&blocks[inx]);
    }
  for (way = 0; way < MEMBLOCKS_N_WAYS; way++)
    {
      for (inx = 0; inx < MAX_CACHED_MALLOC_SIZE / 8; inx++)
	{
	  if (memblock_set[inx][way].av_max && AV_NOT_IN_USE != memblock_set[inx][way].av_max)
	    {
	      av_s_list_t *av = &memblock_set[inx][way];
	      mutex_enter (&av->av_mtx);
	      av_clear ((av_list_t *) av);
	      mutex_leave (&av->av_mtx);
	    }
	}
    }
}


av_list_t *
thr_init_alloc_cache (thread_t * thr)
{
  int inx;
  av_list_t *res = (av_list_t *) malloc (sizeof (av_list_t) * MAX_CACHED_MALLOC_SIZE / 8);
  memset (res, 0, sizeof (av_list_t) * MAX_CACHED_MALLOC_SIZE / 8);
  thr->thr_alloc_cache = res;
  for (inx = 0; inx < MAX_CACHED_MALLOC_SIZE / 8; inx++)
    {
      if (memblock_set[inx][0].av_max)
	res[inx].av_max = memblock_set[inx][0].av_max / 3;
    }
  return res;
}


void
thr_free_alloc_cache (thread_t * thr)
{
  av_list_t *res = (av_list_t *) thr->thr_alloc_cache;
  int inx;
  if (!res)
    return;
  for (inx = 0; inx < MAX_CACHED_MALLOC_SIZE / 8; inx++)
    av_clear (&res[inx]);
  free (thr->thr_alloc_cache);
  thr->thr_alloc_cache = NULL;
}


#define THREAD_ALLOC_MISS \
  { \
  HIT (thread_malloc_misses++); \
  if (0 == blocks->av_n_empty % 1000) \
    av_adjust  (blocks, align_sz); \
}


#define THREAD_ALLOC_LOOKUP(thr, thing, align_sz) \
{ \
  thr = THREAD_CURRENT_THREAD; \
  if (thr) \
    { \
      av_list_t * blocks = (av_list_t *) thr->thr_alloc_cache; \
      if (!blocks) \
	blocks = thr_init_alloc_cache (thr); \
      blocks += align_sz / 8; \
      AV_GET (thing, blocks, HIT (thread_malloc_hits++), THREAD_ALLOC_MISS); \
    }\
}


#define THREAD_ALLOC_FREE(thr, thing, align_sz) \
{ \
  av_list_t * blocks; \
  thr = THREAD_CURRENT_THREAD; \
  if (thr) \
    { \
      blocks = (av_list_t *) thr->thr_alloc_cache; \
      if (blocks) \
	{ \
	  blocks += align_sz / 8; \
	  AV_CHECK_DOUBLE_FREE (blocks,thing, align_sz); \
	  AV_PUT (blocks, thing, return, ;); \
	}\
    } \
}


#else
#define THREAD_ALLOC_LOOKUP(thr, thing, align_sz)
#define THREAD_ALLOC_FREE(thr, thing, align_sz)
void
malloc_cache_clear (void)
{
}


void
thr_free_alloc_cache (thread_t * thr)
{
}
#endif


void
dk_alloc_cache_status (resource_t ** cache)
{
  int inx;
  printf ("\n--------- dk_alloc cache\n");
#ifdef CACHE_MALLOC
  for (inx = 0; inx < MAX_CACHED_MALLOC_SIZE / 8; inx++)
    {
    }
#endif
}


#ifdef MEMDBG
uint32 alloc_count;
uint32 free_count;
uint32 bytes_freed;
uint32 bytes_cum_allocated;
uint32 bytes_cum_freed;
dk_hash_t *allocations;
dk_mutex_t *mdbg_mtx;
#endif

#if defined (AIX) && defined (MEMDBG)
# include "calltrc.c"
#else
# define TRACE_ALLOC(stack, blk)
# define FREE_ALLOC_TRACE(blk)
#endif

#ifdef MTX_METER				 /* count the alloc cache rates only in mtx meter mode */
#define HIT(x) x
#else
#define HIT(x)
#endif


uint32 malloc_hits;
uint32 malloc_misses;
uint32 thread_malloc_hits;
uint32 thread_malloc_misses;


void
dk_memory_initialize (int do_malloc_cache)
{
  /* This is a global flag. In a DLL all users get to
     share the same cached resources */
  static int is_mem_init = 0;

  if (is_mem_init)
    return;
  is_mem_init = 1;

#ifdef UNIX
  init_brk = (long) sbrk (0);
#endif

#ifdef MEMDBG
  allocations = hash_table_allocate (0x100000);
  mdbg_mtx = mutex_allocate ();
#endif

#ifdef CACHE_MALLOC
  if (do_malloc_cache)
    {						 /* GK: it's not a good idea to cache things on a thread from a library */
      int way;
      for (way = 0; way < MEMBLOCKS_N_WAYS; way++)
	{
	  if (4 == sizeof (caddr_t))
	    {
	      MALLOC_CACHE_ENTRY (8, 1000);
	      MALLOC_CACHE_ENTRY (16, 1000);
	      MALLOC_CACHE_ENTRY (24, 1000);
	      MALLOC_CACHE_ENTRY (32, 1000);
	    }
	  else
	    {
	      MALLOC_CACHE_ENTRY (8, 1000);
	      MALLOC_CACHE_ENTRY (16, 2000);
	      MALLOC_CACHE_ENTRY (24, 2000);
	      MALLOC_CACHE_ENTRY (32, 2000);
	      MALLOC_CACHE_ENTRY (40, 2000);
	      MALLOC_CACHE_ENTRY (48, 2000);
	      MALLOC_CACHE_ENTRY (56, 2000);
	      MALLOC_CACHE_ENTRY (64, 2000);
	    }
	  MALLOC_CACHE_ENTRY (sizeof (future_request_t), 100);
	  MALLOC_CACHE_ENTRY (sizeof (future_t), 100);
	}
    }
#endif
  dk_box_initialize ();
  strses_mem_initalize ();
}


void
dk_mem_stat (char *out, int max)
{
  char tmp[200];
  tmp[0] = 0;
#ifdef UNIX
  snprintf (tmp, sizeof (tmp), "brk=%ld", (long) sbrk (0) - init_brk);
#else
  strcpy_ck (tmp, "");
#endif
#ifdef MEMDBG
  snprintf (&tmp[strlen (tmp)], sizeof (tmp) - strlen (tmp), " %ld block, %ld cum bytes",
	(long) (alloc_count - free_count), (long) bytes_cum_allocated);
#endif
  strncpy (out, tmp, max);
  if (max > 0)
    out[max - 1] = 0;
}


int
dk_is_alloc_cache (size_t sz)
{
#ifdef CACHE_MALLOC
  if (memblock_set[sz][0].av_max)
    return 1;
#endif
  return 0;
}


void
dk_cache_allocs (size_t sz, size_t cache_sz)
{
#ifdef CACHE_MALLOC
  int way;
  if (sz < MAX_CACHED_MALLOC_SIZE)
    {
      for (way = 0; way < MEMBLOCKS_N_WAYS; way++)
	{
	  MALLOC_CACHE_ENTRY (sz, cache_sz);
	}
    }
#endif
}


#define MC_MISS \
  HIT (malloc_misses++); \
  if (0 == av->av_n_empty % 1000) \
    av_adjust ((av_list_t*) av, align_sz);

void *
dk_alloc (size_t c)
{
  void *thing = NULL;
  size_t align_sz;

  align_sz = ALIGN_8 (c);

#ifndef CACHE_MALLOC
  thing = dk_alloc_reserve_malloc (ADD_END_MARK (align_sz), 1);
#else
  if (align_sz < MAX_CACHED_MALLOC_SIZE)
    {
      thread_t *thr = NULL;
      THREAD_ALLOC_LOOKUP (thr, thing, align_sz);

      if (!thing)
	{
	  int way = NTH_MEMB;
	  av_s_list_t *av = &memblock_set[align_sz / 8][way];
	  if (av->av_fill)
	    {
	      mutex_enter (&av->av_mtx);
	      AV_GET (thing, av, HIT (malloc_hits++), MC_MISS);
	      mutex_leave (&av->av_mtx);
	    }
	  else
	    {
	      if (av->av_max)
		HIT (malloc_misses++);
	      if (av->av_max && 0 == ++av->av_n_empty % 1000)
		{
		  mutex_enter (&av->av_mtx);
		  av_adjust ((av_list_t *) av, align_sz);
		  mutex_leave (&av->av_mtx);
		}
	    }
	}
      if (!thing)
	{
	  thing = dk_alloc_reserve_malloc (ADD_END_MARK (align_sz), 1);
	}
      AV_MARK_ALLOC (thing, align_sz);
    }
  else
    {
      thing = dk_alloc_reserve_malloc (ADD_END_MARK (align_sz), 1);
    }
#endif

  SET_END_MARK (thing, align_sz);

#ifdef DEBUG
  memset (thing, 0xaa, align_sz);
#endif

#ifdef MEMDBG
  if (!allocations)
    {
#ifndef NDEBUG
      GPF_T;
#endif
      dk_memory_initialize (0);
    }
  if (mdbg_mtx)
    mutex_enter (mdbg_mtx);
  alloc_count++;
  bytes_cum_allocated += c;
  sethash (thing, allocations, (void *) c);
  TRACE_ALLOC (c, (void *) thing);
  if (mdbg_mtx)
    mutex_leave (mdbg_mtx);
#endif

  return thing;
}


void *
dk_try_alloc (size_t c)
{
  return dk_alloc (c);
}


#define FREE_FIT mutex_leave (&av->av_mtx); return;

void
dk_free (void *ptr, size_t sz)
{
#ifdef MEMDBG
  {
    size_t alloc_sz;
    mutex_enter (mdbg_mtx);
    free_count++;
    alloc_sz = (size_t) gethash (ptr, allocations);
    if (!alloc_sz || (sz != NO_SIZE && ALIGN_8 (sz) != ALIGN_8 (alloc_sz)))
      GPF_T;
    CHECK_END_MARK (ptr, ALIGN_4 (alloc_sz));
    SET_RIP_MARK (ptr, ALIGN_4 (alloc_sz));
    bytes_cum_freed += alloc_sz;
    remhash (ptr, allocations);
    FREE_ALLOC_TRACE ((void *) ptr);
    mutex_leave (mdbg_mtx);
  }
  if (ptr < (void *) 20000)
    GPF_T;
#endif

#ifdef DEBUG
  if (NO_SIZE != sz)
    memset (ptr, 0xdd, sz);
#endif
#ifdef CACHE_MALLOC
  if (sz != NO_SIZE)
    {
      size_t align_sz = ALIGN_8 (sz);
      if (align_sz < MAX_CACHED_MALLOC_SIZE)
	{
	  int way;
	  thread_t *thr = NULL;
	  av_s_list_t *av;
	  THREAD_ALLOC_FREE (thr, ptr, align_sz);
	  way = NTH_MEMB;
	  av = &memblock_set[align_sz / 8][way];
	  if (av->av_fill >= av->av_max)
	    {
	      av->av_n_full++;
	      goto full;
	    }
	  mutex_enter (&av->av_mtx);
	  AV_PUT (av, ptr, FREE_FIT, ;);
	  mutex_leave (&av->av_mtx);
	full:
	  free (ptr);
	  return;
	}
    }
#endif

  free (ptr);
}


#ifdef MEMDBG
void
dk_end_ck (char *ptr, ssize_t sz)
{
  CHECK_END_MARK (ptr, sz);
}


void
dk_check_end_marks (void)
{
  maphash_no_remhash ((maphash_func) dk_end_ck, allocations);
}
#endif

#else /* == if defined(MALLOC_DEBUG) */

void
dk_alloc_assert (void *ptr)
{
  const char *err = dbg_find_allocation_error (ptr, NULL);
  if (err)
    GPF_T1 (err);
}


void
dk_memory_initialize (int do_malloc_cache)
{
#ifdef UNIX
  init_brk = (long) sbrk (0);
#endif
  dk_box_initialize ();
  strses_mem_initalize ();
}


void
dk_cache_allocs (size_t sz, size_t cache_sz)
{
}


int
dk_is_alloc_cache (size_t sz)
{
  return 0;
}


void
malloc_cache_clear (void)
{
}


void
dk_alloc_cache_status (resource_t ** cache)
{
}


void
dk_mem_stat (char *out, int max)
{
  strcpy_size_ck (out, "", max);
}


void
thr_free_alloc_cache (thread_t * thr)
{
}
#endif /* MALLOC_DEBUG */


#ifdef MALLOC_DEBUG
#undef dk_alloc
void *
dk_alloc (size_t c)
{
  void *thing = dbg_malloc (__FILE__, __LINE__, c);
  if (NULL == thing)
    {
      dbg_dump_mem();
      GPF_T1 ("Out of memory");
    }
  return thing;
}


void *
dbg_dk_alloc (DBG_PARAMS size_t c)
{
  void *thing = dbg_malloc (DBG_ARGS c);
  if (NULL == thing)
    {
      dbg_dump_mem();
      GPF_T1 ("Out of memory");
    }
  return thing;
}


#undef dk_try_alloc
void *
dk_try_alloc (size_t c)
{
  return dbg_malloc (__FILE__, __LINE__, c);
}


void *
dbg_dk_try_alloc (DBG_PARAMS size_t c)
{
  return dbg_malloc (DBG_ARGS c);
}


#undef dk_free
void
dk_free (void *ptr, size_t sz)
{
  dbg_free_sized (__FILE__, __LINE__, ptr, sz);
}
#endif
