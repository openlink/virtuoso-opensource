/*
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

#ifndef __SHURIC_H
#define __SHURIC_H
#include "Dk.h"
#include "sqlnode.h"

/* \file
'shuric' stands for [SH]areable [URI] [C]ontent -- data that are retrieved
from some URIs, that are cached in memory, that refers each other.

Shuric may have non-NULL URI. There may not be two shurics with same non-NULL URI.
This URI is a key in the global hashtable of shared resources so it's easy
to retrieve shuric by its URI.

Shurics may have NULL URI, indicating that they are anonymous objects not cached
in the global hashtable of shared resources.

Anonymous shuric may be stored in some cache, solely for speed optimization.
it can be found in a cache by some key (that is a tree of boxes)
but there's no warranty that two retrievals from a cache by same key will return same result.
(e.g., cache can be of limited size and can wipe out least popular items).
It is an error to cache a shuric that has non-NULL URI.
It is an error to try to put a shuric in two different caches.

Shurics are of different types. Every type of shurics has its own table
of member functions. There may not be two shurics with same non-NULL URI and
different types.

Shurics can depend on other shuric. E.g., a shuric for XSLT stylesheet A
can 'include' a shuric for XSLT stylesheet B if A contains xsl:include directive for B.

Each shuric has a reference counter. It's increased every time the shuric is
locked for use in external procedures, every time it's imported/included
into another shuric and every time it's registered in the cache.
It's decreased every time the shuric is unlocked, every time somebody
destroys an 'importer' and every time it's removed from cache due to stale or
cache optimization. When reference count is zero, shuric is being destroyed.
The destroying of the shuric decreases reference counters of shurics that are
imported from or inserted into it, so they may, in turn, be destroyed.
The shuric may be declared staled and removed from global hashtable or caches
to prevent its use in future processing,
but it can remain in memory for a while if it's in use and/or is referenced by temporary shurics.

When the shuric stales, all shurics that includes it will stale too.
But if A imports B, not includes B, status of B is not affecting status of A;
that's the only difference between 'include' and 'import'.
*/

#define MAX_SHURIC_URI_LENGTH 600

struct shuric_s;
struct shuric_cache_s;

/* Description of type of a shuric */

/*! Allocates memory and returns a pointer to new shuric.
It should set \c shuric_data field to either some actual data or to NULL, but
it should not try to fill other fields. */
typedef struct shuric_s * (* shuric_alloc_t) (void *env);
/*! Gets a \c uri, returns a text content of the uri or fills \c err_ret */
typedef caddr_t (* shuric_uri_to_text_t) (caddr_t uri, struct query_instance_s *qi, void *env, caddr_t *err_ret);
/*! Parses the \c uri_text_content, probably changes \c shuric_data and/or fills \c err_ret */
typedef void (* shuric_parse_text_t) (struct shuric_s *shuric, caddr_t uri_text_content, struct query_instance_s *qi, void *env, caddr_t *err_ret);
/*! Destroys \c shuric_data if needed and de-allocates \c shuric by e.g. dk_free (shuric, sizeof (shuric_t));
Actual behaviour may vary because
a) \c shuric_data may or may not be owned by shuric and
b) the shuric itself can be one of fields of a structure that is available via \c shuric_data
c) this function should of course remove the shuric from all caches.
*/
typedef void (* shuric_destroy_data_t) (struct shuric_s *shuric);
/*! This is called when \c shuric become stale for whatever reason.
This is not called if shuric is released by its last user but not staled.
This is not called when someone tries to make stale a shuric that is already stale.
This function should probably remove the shuric from all caches to save memory
(if this will not in conflict with isolation of transactions). */
typedef void (* shuric_on_stale_t) (struct shuric_s *shuric);
/*! This is called by members of \c shuric_cache to get key from shuric. */
typedef caddr_t (* shuric_get_cache_key_t) (struct shuric_s *shuric);

/*! Do-noting implementations */
extern void shuric_on_stale__no_op (struct shuric_s *shuric);
extern void shuric_on_stale__cache_remove (struct shuric_s *shuric);
extern caddr_t shuric_get_cache_key__stub (struct shuric_s *shuric);

typedef struct shuric_vtable_s
  {
    const char *		shuric_type_title;
    shuric_alloc_t		shuric_alloc;
    shuric_uri_to_text_t	shuric_uri_to_text;
    shuric_parse_text_t		shuric_parse_text;
    shuric_destroy_data_t	shuric_destroy_data;
    shuric_on_stale_t		shuric_on_stale;
    shuric_get_cache_key_t	shuric_get_cache_key;
  } shuric_vtable_t;

/* Shuric and basic operations on shuric instances. */

typedef struct shuric_s
  {
    shuric_vtable_t * _;		/*!< Pointer to virtual table */
    caddr_t	shuric_uri;		/*!< URI of the resource, NULL if it's a temporary shuric */
    dk_set_t	shuric_imports;		/*!< Set of pointers to directly imported shurics */
    dk_set_t	shuric_includes;	/*!< Set of pointers to directly included shurics */
    dk_set_t	shuric_imported_by;	/*!< Set of pointers to shurics that directly import the given one. */
    dk_set_t	shuric_included_by;	/*!< Set of pointers to shurics that directly include the given one. */
    int		shuric_ref_count;	/*!< Reference count */
    caddr_t	shuric_loading_time;	/*!< Loading time (may be greater than or equal to the time of resource creation. */
    int		shuric_is_stale;	/*!< Flags that the shuric should not be used in new processes */
    struct shuric_cache_s *shuric_cache; /*!< Pointer to the cache where the shuric is cached or NULL */
    struct shuric_s *	shuric_prev_in_cache;	/*!< Previous in cache queue or NULL */
    struct shuric_s *	shuric_next_in_cache;	/*!< Next in cache queue or NULL */
    void *	shuric_data;		/*!< Useful data */
#ifdef DEBUG
    int		shuric_watchdog;	/*!< Last moment when the shuric is in shuric_global_hashtable. */
#endif
  } shuric_t;

/*! Tries to create shuric by loading given URI (if uri_text_content is NULL) or
by using ready content (if non-NULL) and applying appropriate 'parse text' member of vt.
Old shuric for this URI is staled, if exists.
If \c loaded_by is non-NULL then the new shuric is declared as included by \c loaded_by;
this helps to clean memory properly in case of errors during the parsing phase.
\returns a newly loaded shuric that is locked. */
extern shuric_t *shuric_load (shuric_vtable_t *vt, caddr_t uri, caddr_t loading_time,
  caddr_t uri_text_content, shuric_t *loaded_by, struct query_instance_s *qi, void *env, caddr_t *err_ret );

/*! Returns locked shuric for given URI, if it exists, otherwise returns NULL.
There's no function to find if some shuric exists, because it's useless:
other thread may stale shuric before it is locked for actual use. */
extern shuric_t *shuric_get (caddr_t uri);

/*! Returns locked shuric for given URI, if it exists, and of type vt otherwise returns NULL.
If it exists and err_ret is non-NULL, err_ret is filled with error diagnostics */
extern shuric_t *shuric_get_typed (caddr_t uri, shuric_vtable_t *vt, caddr_t *err_ret);

/*! Adds a lock to given shuric. It will do nothing if NULL is passed. */
extern void shuric_lock (shuric_t *shuric);

/*! Releases given previously locked shuric. It will do nothing if NULL is passed. */
extern void shuric_release (shuric_t *locked_shuric);

/*! Stales shuric if it exists. It will not erase the existing locked shuric(s), but they
become unavailable via shuric_get().
It's not an error to pass NULL as an argument. */
extern int shuric_stale_tree (shuric_t *locked_shuric);

/*! Returns some 'default' ts for URI (NULL for remote, file's MTime for local URI). */
extern caddr_t shuric_uri_ts (caddr_t uri);

/*! Checks if the given shuric is obsolete (e.g. files are outdated).
As a reference, it returns new ts of the URI in new_ts_ret, if it's not a NULL */
extern int shuric_is_obsolete_1 (shuric_t *shu, caddr_t *new_ts_ret);

/*! Checks if there are obsolete includes in shu, recursively (via shuric_is_obsolete_1). */
extern int shuric_includes_are_obsolete (shuric_t *shu);

/*! Reloads the shuric, returning a new locked shuric.
It signals an error via err_ret if the given shuric is not staled. */
extern shuric_t *shuric_reload (shuric_t *staled_shuric, void *env, caddr_t *err_ret);

/*! Imports \c subdocument into \c main shuric.
If such a relation was created earlier, zero is returned.
Otherwise, it locks \c subdocument, updates
main->shuric_imports and subdocument->shuric_imported_by and returns 1 */
extern int shuric_make_import (shuric_t *main, shuric_t *subdocument);

/*! Includes \c subdocument into \c main shuric.
If such a relation was created earlier, zero is returned.
Otherwise, it locks \c subdocument, updates
main->shuric_includes and subdocument->shuric_included_by and returns 1 */
extern int shuric_make_include (shuric_t *main, shuric_t *subdocument);

extern int shuric_rollback_import (shuric_t *main, shuric_t *sub);
extern int shuric_rollback_include (shuric_t *main, shuric_t *sub);

#define SHURIC_SCAN_IMPORTS 0x01
#define SHURIC_SCAN_INCLUDES 0x02
#define SHURIC_SCAN_IMPORTED_BY 0x10
#define SHURIC_SCAN_INCLUDED_BY 0x20
#define SHURIC_SCAN_DIRECTIONS_COUNT 4 /* Four different directions */

/*! Returns locked shuric for given URI if it can be recursively accessed from the given shuric
via specified sorts of relations */
extern shuric_t *shuric_scan_relations (shuric_t *haystack_base, caddr_t needle_uri, int scan_mask);

#ifdef DEBUG
extern void shuric_validate_refcounters (int strict);
#endif

/*! This shuric is to make other shurics persistent in memory by
<code>shuric_make_import (&shuric_anchor, myshuric);</code> */
extern shuric_t shuric_anchor;

extern void shuric_init (void);
extern void shuric_terminate_module (void);


/* Shuric caches */

typedef struct shuric_cache_s * (* shuric_cache_alloc_t) (int size_hint, void *env);
typedef void (* shuric_cache_free_t) (struct shuric_cache_s *cache);
typedef void (* shuric_cache_put_t) (struct shuric_cache_s *cache, shuric_t *value);
typedef shuric_t * (* shuric_cache_get_t) (struct shuric_cache_s *cache, caddr_t key);
typedef void (* shuric_cache_remove_t) (struct shuric_cache_s *cache, shuric_t *value);
typedef void (* shuric_cache_empty_t) (struct shuric_cache_s *cache);
typedef void (* shuric_cache_on_idle_t) (struct shuric_cache_s *cache);

typedef struct shuric_cache_vtable_s
  {
    const char *		shuric_cache_type_title;
    shuric_cache_alloc_t	shuric_cache_alloc;
    shuric_cache_free_t		shuric_cache_free;
    shuric_cache_put_t		shuric_cache_put;
    shuric_cache_get_t		shuric_cache_get;
    shuric_cache_remove_t	shuric_cache_remove;
    shuric_cache_empty_t	shuric_cache_empty;
    shuric_cache_on_idle_t	shuric_cache_on_idle;
  } shuric_cache_vtable_t;

typedef struct shuric_cache_s
  {
    shuric_cache_vtable_t * _;
    id_hash_t *sc_table;
    shuric_t *sc_worth;
    shuric_t *sc_useless;
    int sc_size_hint;
  } shuric_cache_t;

extern shuric_cache_vtable_t shuric_cache__LRU;

#endif /* #ifndef __SHURIC */
