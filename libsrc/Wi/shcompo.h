/*
 *  $Id$
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
 */

#ifndef __SHCOMPO_H
#define __SHCOMPO_H
#include "Dk.h"
#include "sqlnode.h"

/* \file
'shcompo' stands for [SH]areable [Comp]iled [O]bject -- a thing that is compiled once and used many times.
The thing is identified by a key such as a vector of SQL query text, uid and gid.
Things are kept in a global cache.

When a thread tries to use a thing, it should lock it first and release after the use.
To compile a thing, the thread places it into cache then compiles then updates the cache.
When a thing is being compiled by other thread, a mutex gives a possibility to wait for the end of compilation.

Each shcompo has a reference counter. It's increased every time the shcompo is
locked for use in external procedures and every time it's registered in the cache.
It's decreased every time the shcompo is unlocked and every time it's removed from cache due to stale or
cache optimization. When reference count is zero, shcompo is being destroyed.
The shcompo may be declared staled and removed from global hashtable or caches
to prevent its use in future processing,
but it can remain in memory for a while if it's in use.
It can become stale without being explicitly declares as such (say, qr_needs_recompile can be set),
so a method should be used to check whether the shcompo is stale, not just an access to the field.
*/

struct shcompo_s;
struct shcompo_cache_s;

/* Description of type of a shcompo */

/*! Allocates memory and returns a pointer to new shcompo.
It should set \c shcompo_data field to either some actual data or to NULL, but
it should not try to fill other fields. */
typedef struct shcompo_s * (* shcompo_alloc_t) (void *env);
/*! Allocates memory and returns a pointer to new shcompo, using given one as a template.
It should set \c shcompo_data field to either some actual data or to NULL, but
it should not try to fill other fields. */
typedef struct shcompo_s * (* shcompo_alloc_copy_t) (struct shcompo_s *shc);
/*! Compiles a key of \c shc and fills in either its \c shcompo_data or \c shcompo_error */
typedef void (* shcompo_compile_t) (struct shcompo_s *shc, struct query_instance_s *qi, void *env);
/*! Returns whether a \c shc is stale (so \c shcompo_is_stale should be set) */
typedef int (* shcompo_check_if_stale_t) (struct shcompo_s *shc);
/*! Recompiles a key of \c shc and fills in either its \c shcompo_data or \c shcompo_error.
The key is supposed to be successfully compiled at least once before so shcompo_data is filled in. */
typedef void (* shcompo_recompile_t) (struct shcompo_s *old_shcompo, struct shcompo_s *new_shcompo);
/*! Destroys \c shcompo_data if needed and de-allocates \c shc by e.g. dk_free (shcompo, sizeof (shcompo_t));
Actual behaviour may vary because
a) \c shcompo_data and shcompo_key may or may not be owned by shcompo and
b) the shcompo itself can be one of fields of a structure that is available via \c shcompo_data
c) this function may assert that the shcompo is not in cache and that the refcounter is zero.
*/
typedef void (* shcompo_destroy_data_t) (struct shcompo_s *shc);

typedef struct shcompo_vtable_s
  {
    const char *		shcompo_type_title;
    id_hash_t *			shcompo_cache;
    dk_mutex_t *		shcompo_cache_mutex;
    dk_set_t			shcompo_spare_mutexes;
    shcompo_alloc_t		shcompo_alloc;
    shcompo_alloc_copy_t	shcompo_alloc_copy;	/*!< Can be NULL, but only if \c shcompo_recompile is also NULL */
    shcompo_compile_t		shcompo_compile;
    shcompo_check_if_stale_t    shcompo_check_if_stale;
    shcompo_recompile_t		shcompo_recompile;	/*!< Can be NULL if re-compilation is impossible (say, it requires environment that is not stored in the result of the compilation) */
    shcompo_destroy_data_t	shcompo_destroy_data;
    unsigned long		shcompo_cache_size_limit;	/*!< Maximum allowed number of cached objects in the cache, can not be less than two. Setting the value much smaller than number of buckets of \c shcompo_cache may cause inefficient searches for old item to remove when the limit is reached */
  } shcompo_vtable_t;

/* Shcompo and basic operations on shcompo instances. */

typedef struct shcompo_s
  {
    shcompo_vtable_t * _;		/*!< Pointer to virtual table */
    caddr_t	shcompo_key;		/*!< Key such as vector (query text, user, group) for query */
    int		shcompo_ref_count;	/*!< Reference count */
    int		shcompo_is_stale;	/*!< Flags that the shcompo should not be used in new processes */
    void *	shcompo_data;		/*!< Useful data. The shcompo itself can be part of that data but only if _->shcompo_recompile is NULL */
    caddr_t	shcompo_error;		/*!< NULL in case of successful (or not performed) compilation, compilation error otherwise */
    dk_mutex_t *shcompo_comp_mutex;	/*!< Compilation mutex, it is non-NULL while the compilation is in progress */
#ifdef DEBUG
    int		shcompo_watchdog;	/*!< Last moment when the shcompo is in shcompo_global_hashtable. */
#endif
#ifndef NDEBUG
    thread_t *  shcompo_owner;
#endif
  } shcompo_t;

#ifdef NDEBUG
#define SHC_ENTER(s) mutex_enter ((s)->shcompo_comp_mutex)
#define SHC_LEAVE(s) mutex_leave ((s)->shcompo_comp_mutex)
#define SHC_COMP_MTX_CHECK(s)
#else
#define SHC_ENTER(s) \
    do { \
      if (THREAD_CURRENT_THREAD == (s)->shcompo_owner) GPF_T1 ("entering mtx twice"); \
      mutex_enter ((s)->shcompo_comp_mutex); \
      (s)->shcompo_owner = THREAD_CURRENT_THREAD; \
    } while (0)
#define SHC_LEAVE(s) \
    do { \
      (s)->shcompo_owner = NULL; \
      mutex_leave ((s)->shcompo_comp_mutex); \
    } while (0)
#define SHC_COMP_MTX_CHECK(s) \
    if ((s)->shcompo_comp_mutex && (s)->shcompo_owner != NULL) GPF_T
#endif

/*! Tries to get a thing or create it by compiling a (copy of) key.
If \c key_is_const then \c key is not changed (cache will store a copy if needed, otherwise \c key can be freed or placed into cache).
\returns an old or a previously compiled shcompo, locked. */
extern shcompo_t *shcompo_get_or_compile (shcompo_vtable_t *vt, caddr_t key, int key_is_const, struct query_instance_s *qi, void *env, caddr_t *err_ret);

/*! Returns locked shcompo for given key if it exists, otherwise returns NULL.
There's no function to find if some shcompo exists, because it's useless:
other thread may stale shcompo before it is locked for actual use. */
extern shcompo_t *shcompo_get (shcompo_vtable_t *vt, caddr_t key);

/*! Adds a lock to given shcompo. It will do nothing if NULL is passed. */
extern void shcompo_lock (shcompo_t *shc);

/*! Releases given previously locked shcompo. It will do nothing if NULL is passed. */
extern void shcompo_release (shcompo_t *locked_shcompo);

/*! Stales shcompo if it exists. It will not erase the existing locked shcompo(s), but they
become unavailable via shcompo_get().
They still might be available via shcompo_get_or_compile().
It's not an error to pass NULL as an argument. */
extern void shcompo_stale (shcompo_t *locked_shcompo);

/*! Checks whether the shcompo should be staled, then acts like \c shcompo_stale() if needed */
extern void shcompo_stale_if_needed (shcompo_t *locked_shcompo);

/*! Stales shcompo if it exists, then tries to recompile.
It will not erase the existing locked shcompo(s), but they may become unavailable via shcompo_get() in case of recompilation error.
They still might be available via shcompo_get_or_compile().
It's not an error to pass pointer to NULL as an argument.
After successful recompilation, the locked_shcompo_ptr points to new shcompo.
 */
extern void shcompo_recompile (shcompo_t **locked_shcompo_ptr);

/*! Checks whether the shcompo should be staled, then call \c shcompo_recompile() if needed */
extern void shcompo_recompile_if_needed (shcompo_t **locked_shcompo_ptr);

/*! Checks if the given shcompo is obsolete. */
extern int shcompo_is_obsolete_1 (shcompo_t *shc);

#ifdef DEBUG
extern void shcompo_validate_refcounters (int strict);
#endif

extern void shcompo_init (void);
extern void shcompo_terminate_module (void);

extern shcompo_vtable_t shcompo_vtable__qr;

#endif /* #ifndef __SHCOMPO */
