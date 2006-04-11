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
 *  Copyright (C) 1998-2006 OpenLink Software
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

#include "Dk.h"

#ifndef MALLOC_DEBUG

#ifdef dk_alloc
#undef dk_alloc
#endif

#ifdef dk_free
#undef dk_free
#endif

extern void dk_box_initialize(void);

/* Still have to clean this up - PmN */
#if !defined (NO_MALLOC_CACHE) && !defined (PURIFY) && !defined (VALGRIND)
# if defined (UNIX) || defined (WIN32)
#  define CACHE_MALLOC
# endif
#endif

#define NO_SIZE ((size_t) -1)

#ifdef CACHE_MALLOC

#ifdef MTX_DEBUG
#define MALLOC_CACHE_ENTRY_MTX(sz) \
  { char name[20]; snprintf (name, sizeof (name), "MEM %d", sz); \
  mutex_option (memblocks[sz]->rc_mtx, name, NULL, NULL); }
#else
#define MALLOC_CACHE_ENTRY_MTX(sz)
#endif

# define MALLOC_CACHE_ENTRY(sz,rcsz) \
if (NULL == memblocks[sz]) \
  { \
    memblocks[sz] = resource_allocate ((uint32)rcsz, (rc_constr_t) 0L, \
		    (rc_destr_t) free, (rc_destr_t) 0L, (void *) (ptrlong) sz); \
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
const int __delayed_free = 0;			/* no delay; was 2 */
const int __fast_free_max = 25;			/* was 13 */
const int __first_fit = 0;
const unsigned long __madvisor = 0;
const int __max_cache = 15;
const size_t __mingrow = 49152;
const double __mingrowfactor = 0.1;
const size_t __minshrink = 16384;
const double __minshrinkfactor = 0.001;
const unsigned long __noshrink = 1;		 /* do not shrink mem; was 0 */
const unsigned long __sbrk_override = 0;
const unsigned long __small_buff = 0;
const unsigned long __taso_mode = 0;
#endif


#ifdef CACHE_MALLOC
static resource_t * memblocks[MAX_CACHED_MALLOC_SIZE];

void
malloc_cache_clear (void)
{
  int inx;
  thread_t *thr = THREAD_CURRENT_THREAD;
  if (thr->thr_alloc_cache)
    {
      resource_t ** blocks = (resource_t **) thr->thr_alloc_cache;
      for (inx = 0; inx < MAX_CACHED_MALLOC_SIZE; inx++)
	if (blocks[inx])
	  resource_clear (blocks[inx], free);
    }
  for (inx = 0; inx < MAX_CACHED_MALLOC_SIZE; inx++)
    if (memblocks[inx])
      resource_clear (memblocks[inx], NULL);
}

resource_t **
thr_init_alloc_cache (thread_t * thr)
{
  resource_t ** res = (resource_t **) malloc (sizeof (caddr_t) * MAX_CACHED_MALLOC_SIZE);
  int inx;
  memset (res, 0, sizeof (caddr_t) * MAX_CACHED_MALLOC_SIZE);
  thr->thr_alloc_cache = res;
  for (inx = 0; inx < MAX_CACHED_MALLOC_SIZE; inx += 4)
    if (memblocks[inx])
      res[inx] = resource_allocate_primitive (memblocks[inx]->rc_size / 3, 20000 / inx);
  return res;
}


void
thr_free_alloc_cache (thread_t * thr)
{
  resource_t ** res = (resource_t **) thr->thr_alloc_cache;
  int inx;
  void * res1;
  if (!res)
    return;
  for (inx = 0; inx < MAX_CACHED_MALLOC_SIZE; inx += 4)
    if (res[inx])
      {
	while (NULL != (res1 = resource_get (res[inx])))
	  free (res1);
	free ((res[inx])->rc_items);
	free (res[inx]);
      }
  free (thr->thr_alloc_cache);
  thr->thr_alloc_cache = NULL;
}





#define THREAD_ALLOC_LOOKUP(thr, thing, align_sz) \
{ \
    thr = THREAD_CURRENT_THREAD; \
  if (thr) \
    { \
      resource_t ** blocks = (resource_t **) thr->thr_alloc_cache; \
      resource_t * rc; \
      if (!blocks) \
	blocks = thr_init_alloc_cache (thr); \
      if (! (rc = blocks[align_sz])) \
	rc = blocks[align_sz] = resource_allocate_primitive (memblocks[align_sz]->rc_size / 3, (int) (20000 / align_sz)); \
      ++rc->rc_gets; \
      if (rc->rc_fill) \
	{ \
	  thing = (rc->rc_items[--(rc->rc_fill)]); \
	thread_malloc_hits++; \
	} \
      else \
	{ \
	  if (++rc->rc_n_empty % 1000 == 0) \
	    _resource_adjust (rc); \
	  thread_malloc_misses++; \
	} \
    } \
}

#define THREAD_ALLOC_FREE(thr, thing, align_sz) \
{ \
  resource_t ** blocks; \
  resource_t * rc; \
    thr = THREAD_CURRENT_THREAD; \
  if (thr) \
    { \
      blocks = (resource_t **) thr->thr_alloc_cache; \
      if (blocks && (rc = blocks[align_sz])) \
	{ \
	  rc->rc_stores++; \
	  if (rc->rc_fill < rc->rc_size) \
	    { \
	      rc->rc_items[(rc->rc_fill)++] = thing; \
	return; \
    } \
	  else \
	    { \
	      rc->rc_n_full++; \
	    } \
	} \
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
  for (inx = 0; inx < MAX_CACHED_MALLOC_SIZE; inx++)
    if (cache[inx])
      {
	resource_t * c = cache[inx];
	if (c->rc_gets)
	  printf ("%-4d %-3ldK:  %-8ld alloc %8ld free %-8ld empty %-8ld full\n",
		  inx, (long)(c->rc_size) * inx / 1024,
		  (long)(c->rc_gets), (long)(c->rc_stores), (long)(c->rc_n_empty), (long)(c->rc_n_full));
      }
#endif
}


#ifdef MEMDBG
uint32		alloc_count;
uint32		free_count;
uint32		bytes_freed;
uint32		bytes_cum_allocated;
uint32		bytes_cum_freed;
dk_hash_t *	allocations;
dk_mutex_t *	mdbg_mtx;
#endif

#if defined (AIX) && defined (MEMDBG)
# include "calltrc.c"
#else
# define TRACE_ALLOC(stack, blk)
# define FREE_ALLOC_TRACE(blk)
#endif

uint32 malloc_hits;
uint32 malloc_misses;
uint32 thread_malloc_hits;
uint32 thread_malloc_misses;
#ifdef UNIX
long init_brk;
#endif


/*##**********************************************************************
 *
 *	      dk_memory_initialize
 *
 * This sets up a set of resources for blocks of different size.
 *
 *
 * Input params : do_malloc_cache : boolean : whether to enable malloc_cache
 *
 * Output params:    - none
 *
 * Return value :    none
 *
 * Limitations  :
 *
 * Globals used :    memblocks
 */

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
    { /* GK: it's not a good idea to cache things on a thread from a library */
      MALLOC_CACHE_ENTRY (8, 1000);
      MALLOC_CACHE_ENTRY (12, 500);
      MALLOC_CACHE_ENTRY (16, 200);
      MALLOC_CACHE_ENTRY (20, 100);
      MALLOC_CACHE_ENTRY (24, 100);
      MALLOC_CACHE_ENTRY (28, 100);
      MALLOC_CACHE_ENTRY (32, 100);
      MALLOC_CACHE_ENTRY (sizeof (future_request_t), 100);
      MALLOC_CACHE_ENTRY (sizeof (future_t), 100);
    }
#endif
  dk_box_initialize();
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
    out[max-1] = 0;
}


int
dk_is_alloc_cache (size_t sz)
{
#ifdef CACHE_MALLOC
  if (memblocks[sz])
    return 1;
#endif
  return 0;
}


void
dk_cache_allocs (size_t sz, size_t cache_sz)
{
#ifdef CACHE_MALLOC
  if (sz < MAX_CACHED_MALLOC_SIZE)
    {
      MALLOC_CACHE_ENTRY (sz, cache_sz);
    }
#endif
}

/*##**********************************************************************
 *
 *	      dk_alloc
 *
 * Allocate n bytes of memory. Check if there is a resource for
 * the given block size. If som get the blockfrom the resource.
 * If not, malloc the block.
 *
 * Input params :        - n byte count
 &
 *
 * Output params:    - none
 *
 * Return value :    the block allocated.
 *
 * Limitations  :
 *
 * Globals used :    memblocks
 */

void *
dk_alloc (size_t c)
{
  void *thing = NULL;
  size_t c_align;

  c_align = ALIGN_4 (c);

#ifndef CACHE_MALLOC
  thing = dk_alloc_reserve_malloc (ADD_END_MARK (c_align), 1);
#else
  if (c_align < MAX_CACHED_MALLOC_SIZE && memblocks[c_align])
    {
      thread_t * thr = NULL;
      THREAD_ALLOC_LOOKUP (thr, thing, c_align);

      if (!thing)
	thing = resource_get (memblocks[c_align]);
      if (thing)
	malloc_hits++;
      else
	{
	  thing = dk_alloc_reserve_malloc (ADD_END_MARK (c_align), 1);
	  malloc_misses++;
	}
    }
  else
    {
      thing = dk_alloc_reserve_malloc (ADD_END_MARK (c_align), 1);
    }
#endif

  SET_END_MARK (thing, c_align);

#ifdef DEBUG
  memset (thing, 0xaa, c_align);
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
  void *thing = NULL;
  size_t c_align;

  c_align = ALIGN_4 (c);

#ifndef CACHE_MALLOC
  if ((thing = dk_alloc_reserve_malloc (ADD_END_MARK (c_align), 0)) == NULL)
    return thing;
#else
  if (c_align < MAX_CACHED_MALLOC_SIZE && memblocks[c_align])
    {
      thread_t * thr = NULL;
      THREAD_ALLOC_LOOKUP (thr, thing, c_align);

      if (!thing)
	thing = resource_get (memblocks[c_align]);
      if (thing)
	malloc_hits++;
      else
	{
	  thing = dk_alloc_reserve_malloc (ADD_END_MARK (c_align), 0);
	  if (!thing)
	    return thing;
	  malloc_misses++;
	}
    }
  else
    {
      thing = dk_alloc_reserve_malloc (ADD_END_MARK (c_align), 0);
      if (!thing)
	return thing;
    }
#endif

  SET_END_MARK (thing, c_align);

#ifdef DEBUG
  memset (thing, 0xaa, c_align);
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


/*##**********************************************************************
 *
 *	      dk_free
 *
 * Free a block of memory. If there is a resource for the given block
 * size return the block to the resource. If not, call free.
 *
 *
 * Input params :	- The block to free
 &		       - The size of the block (used to
 *			  identify the resource)
 *
 * Output params:    - none
 *
 * Return value :    none
 *
 * Limitations  :
 *
 * Globals used :    memblocks
 */
void
dk_free (void *ptr, size_t sz)
{
#ifdef MEMDBG
  {
    size_t alloc_sz;
    mutex_enter (mdbg_mtx);
    free_count++;
    alloc_sz = (size_t) gethash (ptr, allocations);
    if (!alloc_sz || (sz != NO_SIZE && ALIGN_4 (sz) != ALIGN_4 (alloc_sz)))
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
      size_t align_sz = ALIGN_4 (sz);
      if (align_sz < MAX_CACHED_MALLOC_SIZE && memblocks[align_sz])
	{
	  thread_t * thr = NULL;
	  THREAD_ALLOC_FREE (thr, ptr, align_sz);
	  resource_store (memblocks[align_sz], ptr);
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

void dk_alloc_assert (void *ptr)
{
  const char *err = dbg_find_allocation_error (ptr, NULL);
  if (err)
    GPF_T1 (err);
}

void
dk_memory_initialize (int do_malloc_cache)
{
  dk_box_initialize();
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
void * dk_alloc (size_t c) { return dbg_malloc (__FILE__, __LINE__, c); }
void * dbg_dk_alloc (DBG_PARAMS size_t c) { return dbg_malloc (DBG_ARGS c); }
#undef dk_try_alloc
void * dk_try_alloc (size_t c) { return dbg_malloc (__FILE__, __LINE__, c); }
void * dbg_dk_try_alloc (DBG_PARAMS size_t c) { return dbg_malloc (DBG_ARGS c); }
#undef dk_free
void dk_free (void *ptr, size_t sz) {  dbg_free_sized (__FILE__, __LINE__, ptr, sz); }
#endif



