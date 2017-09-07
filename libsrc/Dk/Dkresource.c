/*
 *  Dkresource.c
 *
 *  $Id$
 *
 *  Resource management
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

#include "Dk.h"


#ifdef MALLOC_DEBUG
#define RC_DBG
dk_hash_t *res_to_thing = NULL;
dk_mutex_t *res_to_thing_mtx = NULL;

malhdr_t *
resource_find_malhdr (void *res)
{
  malhdr_t *thing;
  if (NULL == res_to_thing)
    {
      res_to_thing_mtx = mutex_allocate ();
      res_to_thing = hash_table_allocate (128047);
      return NULL;
    }
  mutex_enter (res_to_thing_mtx);
  thing = gethash (res, res_to_thing);
  mutex_leave (res_to_thing_mtx);
  return thing;
}

malhdr_t *
resource_find_or_make_malhdr (void *res)
{
  malhdr_t *thing;
  if (NULL == res_to_thing)
    {
      res_to_thing_mtx = mutex_allocate ();
      res_to_thing = hash_table_allocate (128047);
    }
  mutex_enter (res_to_thing_mtx);
  thing = gethash (res, res_to_thing);
  mutex_leave (res_to_thing_mtx);
  if (NULL == thing)
    {
      thing = (malhdr_t *)malloc (sizeof (malhdr_t));
      thing->magic = 0;
      mutex_enter (res_to_thing_mtx);
      sethash (res, res_to_thing, thing);
      mutex_leave (res_to_thing_mtx);
    }
  return thing;
}

#endif


/*##**********************************************************************
 *
 *              resource_allocate
 *
 * Allocates a resource of a given capacity. A resource is a stack-like
 * structure of fixed capacity. resource_get returns an element stored
 * in a resource if any. resource_store adds an element to the resource
 * if there is room.
 *
 * Input params :        - Capacity - how many items can be stored.
 *                       - The function for creating new entries for
 *                         the resource. if not null used by resource_get
 *                         when there are no items in the resource.
 *                       - destructor. Called on items that do not fit in the
 *                         resource in resource_store.
 *                       - clear_func. Called on stored items in
 *                         resource_store before placing on the resource pool.
 *                       - client_data - Argument to the constructor function
 *                         called in resource_get.
 *
 *
 * Output params:    - none
 *
 * Return value :    The resource object.
 *
 * Limitations  :
 *
 * Globals used :
 */
resource_t *
DBG_NAME(resource_allocate) (DBG_PARAMS  uint32 sz, rc_constr_t constructor, rc_destr_t destructor, rc_destr_t clear_func, void *client_data)
{
  resource_t *rc;
  rc = (resource_t *) DBG_NAME(malloc) (DBG_ARGS  sizeof (resource_t));
  /* use malloc so as to be usable inside the dk_alloc cache system */
  memset (rc, 0, sizeof (resource_t));
  rc->rc_items = (void **) DBG_NAME(malloc) (DBG_ARGS  sizeof (void *) * sz);
  rc->rc_fill = 0;
  rc->rc_size = sz;
  rc->rc_constructor = constructor;
  rc->rc_destructor = destructor;
  rc->rc_clear_func = clear_func;
  rc->rc_client_data = client_data;

  rc->rc_gets = 0;
  rc->rc_stores = 0;

  rc->rc_mtx = mutex_allocate ();
  return (rc);
}


resource_t *
DBG_NAME(resource_allocate_primitive) (DBG_PARAMS  uint32 sz, int max_sz)
{
  resource_t *rc;
  rc = (resource_t *) DBG_NAME(malloc) (DBG_ARGS  sizeof (resource_t));
  memset (rc, 0, sizeof (resource_t));
  rc->rc_items = (void **) DBG_NAME(malloc) (DBG_ARGS  sizeof (void *) * sz);
  rc->rc_fill = 0;
  rc->rc_size = sz;
  rc->rc_max_size = max_sz;
  return (rc);
}


void
resource_no_sem (resource_t * rc)
{
  if (rc->rc_mtx)
    {
      mutex_free (rc->rc_mtx);
      rc->rc_mtx = NULL;
    }
}


void
DBG_NAME(_resource_adjust) (DBG_PARAMS  resource_t * rc)
{
  /* if there are over 5% underflows and the resource overflows at least half as
   * frequently as it underflows and it's not over max size, expand */

  if (rc->rc_fill)
    GPF_T1 ("can only adjust empty rc's");
  if (rc->rc_size >= rc->rc_max_size || rc->rc_item_time)
    return;
  if (rc->rc_gets > 10000000 || rc->rc_n_empty > rc->rc_gets)
    {
      rc->rc_gets = 0;
      rc->rc_stores = 0;
      rc->rc_n_empty = 0;
      rc->rc_n_full = 0;
      return;
    }
  if (rc->rc_n_empty > rc->rc_gets / 20 && rc->rc_n_full > rc->rc_n_empty / 2)
    {
      int new_rc_size = rc->rc_size * 2;
      void **arr = (void **) DBG_NAME(malloc) (DBG_ARGS  new_rc_size * sizeof (void *));
      rc->rc_size = new_rc_size;
      DBG_NAME(free) (DBG_ARGS  (void *) rc->rc_items);
      rc->rc_items = arr;
      rc->rc_gets = 0;
      rc->rc_stores = 0;
      rc->rc_n_empty = 0;
      rc->rc_n_full = 0;
    }
}

/*##**********************************************************************
 *
 *              resource_get
 *
 * returns an item from a resource. If there are no items, and no constructor
 * is specified this returns NULL. If a constructor is specified and there are
 * no items the constructor is applied to the client data and the result
 * is returned.
 *
 *
 * Input params :        - The resource
 *
 * Output params:    - none
 *
 * Return value :    The item in the resource or NULL.
 *
 * Limitations  :
 *
 * Globals used :
 */
void *
DBG_NAME(resource_get_1) (DBG_PARAMS  resource_t * rc, int construct_new)
{
  dk_mutex_t *rc_mtx = rc->rc_mtx;
  void *res;
  if (rc_mtx)
    mutex_enter (rc_mtx);
  ++rc->rc_gets;
  if (rc->rc_fill)
    {
      res = (rc->rc_items[--(rc->rc_fill)]);
      if (rc_mtx)
        mutex_leave (rc_mtx);
    }
  else
    {
      if (++rc->rc_n_empty % 1000 == 0)
        _resource_adjust (rc);
      if (rc_mtx)
        mutex_leave (rc_mtx);
      if (!construct_new)
        return NULL;
      if (NULL == rc->rc_constructor)
        return NULL;
      res = (*rc->rc_constructor) (rc->rc_client_data);
    }
#ifdef MALLOC_DEBUG
  {
    malhdr_t *thing = resource_find_or_make_malhdr (res);
    if (DBGMAL_MAGIC_COUNT_FREED == thing->magic)
      thing->magic = 0;
    dbg_count_like_malloc (DBG_ARGS  thing, 1000);
  }
#endif
  return res;
}


void
DBG_NAME(resource_get_batch) (DBG_PARAMS  resource_t * rc, void **tgt_array, int batch_size, int construct_new)
{
  int res_count = 0;
  dk_mutex_t *rc_mtx = rc->rc_mtx;
  if (rc_mtx)
    mutex_enter (rc_mtx);
  while ((res_count < batch_size) && rc->rc_fill)
    {
      ++rc->rc_gets;
      tgt_array[res_count++] = rc->rc_items[--(rc->rc_fill)];
    }
  if (res_count == batch_size)
    {
      if (rc_mtx)
        mutex_leave (rc_mtx);
    }
  else
    {
      rc->rc_n_empty += (batch_size - res_count);
      if ((0 == rc->rc_fill) && ((rc->rc_n_empty % 1000) < (batch_size - res_count)))
        _resource_adjust (rc);
      if (rc_mtx)
        mutex_leave (rc_mtx);
      if (!construct_new || (NULL == rc->rc_constructor))
        memzero (tgt_array + res_count, (batch_size - res_count) * sizeof (void *));
      else
        {
          while (res_count < batch_size)
          tgt_array[res_count++] = (*rc->rc_constructor) (rc->rc_client_data);
        }
    }
#ifdef MALLOC_DEBUG
  {
    int res_ctr;
    for (res_ctr = res_count; res_ctr--; /* no step */)
      {
        malhdr_t *thing = resource_find_or_make_malhdr (tgt_array[res_ctr]);
        if (DBGMAL_MAGIC_COUNT_FREED == thing->magic)
          thing->magic = 0;
        dbg_count_like_malloc (DBG_ARGS  thing, 1000);
      }
  }
#endif
}


void *
DBG_NAME(resource_get) (DBG_PARAMS  resource_t * rc)
{
  return DBG_NAME(resource_get_1) (DBG_ARGS  rc, 1);
}


/*##**********************************************************************
 *
 *              resource_store
 *
 *
 * Adds an element to a resource. If the resource is full and a destructor
 * is specified this applies the destructor to the item being stored.
 * if there is room in the resource and a clear_func is specified the clear
 * function is called first.
 *
 * Input params :        - resource, element.
 *
 *
 * Output params:    - none
 *
 * Return value :    true if the element was added,
 *                   false if the resource was full.
 *
 * Limitations  :
 *
 * Globals used :
 */

int
DBG_NAME(resource_store) (DBG_PARAMS  resource_t * rc, void *item)
{
#ifdef MALLOC_DEBUG
  malhdr_t *thing = resource_find_malhdr (item);
#endif
  dk_mutex_t *rc_mtx = rc->rc_mtx;
  if (rc_mtx)
    mutex_enter (rc_mtx);

#ifdef RC_DBG
  {
    uint32 inx;
    for (inx = 0; inx < rc->rc_fill; inx++)
      if (item == rc->rc_items[inx])
	{
	  GPF_T1 ("Duplicate resource free.");
	}
  }
#endif /* RC_DBG */
#ifdef MALLOC_DEBUG
  if (NULL != thing)
    dbg_count_like_free (DBG_ARGS  thing);
#endif
  rc->rc_stores++;
  if (rc->rc_fill < rc->rc_size)
    {
      if (rc->rc_clear_func)
	(*rc->rc_clear_func) (item);

      rc->rc_items[(rc->rc_fill)++] = item;
      if (rc_mtx)
	mutex_leave (rc_mtx);
      return 1;
    }
  else
    {
#ifdef MALLOC_DEBUG
      mutex_enter (res_to_thing_mtx);
      remhash (item, res_to_thing);
      mutex_leave (res_to_thing_mtx);
      free (thing);
#endif
      rc->rc_n_full++;
      if (rc_mtx)
        mutex_leave (rc_mtx);
      if (rc->rc_destructor)
        (*rc->rc_destructor) (item);
      return 0;
    }
}


int
DBG_NAME(resource_store_fifo) (DBG_PARAMS  resource_t * rc, void *item, int n_fifo)
{
#ifdef MALLOC_DEBUG
  malhdr_t *thing = resource_find_malhdr (item);
#endif
  dk_mutex_t *rc_mtx = rc->rc_mtx;
  if (rc_mtx)
    mutex_enter (rc_mtx);

#ifdef RC_DBG
  {
    uint32 inx;
    for (inx = 0; inx < rc->rc_fill; inx++)
      if (item == rc->rc_items[inx])
	{
	  GPF_T1 ("Duplicate resource free.");
	}
  }
#endif /* RC_DBG */
#ifdef MALLOC_DEBUG
  if (NULL != thing)
    dbg_count_like_free (DBG_ARGS  thing);
#endif
  rc->rc_stores++;
  if (rc->rc_fill < rc->rc_size)
    {
      int place = MAX ((int)rc->rc_fill - n_fifo, 0);
      if (rc->rc_clear_func)
	(*rc->rc_clear_func) (item);
      memmove_16 (&rc->rc_items[place + 1], &rc->rc_items[place], sizeof (caddr_t) * (rc->rc_fill - place));
      rc->rc_items[place] = item;
      rc->rc_fill++;
      if (rc_mtx)
	mutex_leave (rc_mtx);
      return 1;
    }
  else
    {
#ifdef MALLOC_DEBUG
      mutex_enter (res_to_thing_mtx);
      remhash (item, res_to_thing);
      mutex_leave (res_to_thing_mtx);
      free (thing);
#endif
      rc->rc_n_full++;
      if (rc_mtx)
	mutex_leave (rc_mtx);
      if (rc->rc_destructor)
	(*rc->rc_destructor) (item);
      return 0;
    }
}


void
DBG_NAME(rc_resize) (DBG_PARAMS  resource_t * rc, int new_sz)
{
  void * new_items;
  void * new_time = NULL;
  new_items = DBG_NAME(malloc) (DBG_ARGS  sizeof (void*) * new_sz);
  if (rc->rc_item_time)
    {
      new_time = malloc (sizeof (int32) * new_sz);
      memzero (new_time, sizeof (int32) * new_sz);
    }
  memcpy (new_items, rc->rc_items, sizeof (void*) * rc->rc_fill);
  if (rc->rc_item_time)
    memcpy (new_time, rc->rc_item_time, sizeof (int32) * rc->rc_fill);
  DBG_NAME(free) (DBG_ARGS  rc->rc_items);
  if (rc->rc_item_time)
    free (rc->rc_item_time);
  rc->rc_items = (void**)new_items;
  rc->rc_item_time = (unsigned int*)new_time;
  rc->rc_size = new_sz;
}



int
DBG_NAME(resource_store_timed) (DBG_PARAMS  resource_t * rc, void *item)
{
#ifdef MALLOC_DEBUG
  malhdr_t *thing = resource_find_malhdr (item);
#endif
  dk_mutex_t *rc_mtx = rc->rc_mtx;
  uint32 time = approx_msec_real_time ();
  if (rc_mtx)
    mutex_enter (rc_mtx);
#ifdef RC_DBG
  {
    uint32 inx;
    for (inx = 0; inx < rc->rc_fill; inx++)
      if (item == rc->rc_items[inx])
        {
          GPF_T1 ("Duplicate resource free.");
        }
  }
#endif /* RC_DBG */
#ifdef MALLOC_DEBUG
  if (NULL != thing)
    dbg_count_like_free (DBG_ARGS  thing);
#endif
  rc->rc_stores++;
  if (rc->rc_fill < rc->rc_size)
    {
      if (rc->rc_clear_func)
	(*rc->rc_clear_func) (item);
      rc->rc_item_time[rc->rc_fill] = time;
      rc->rc_items[(rc->rc_fill)++] = item;
      if (rc_mtx)
	mutex_leave (rc_mtx);
      return 1;
    }
  else
    {
#ifdef MALLOC_DEBUG
      mutex_enter (res_to_thing_mtx);
      remhash (item, res_to_thing);
      mutex_leave (res_to_thing_mtx);
      free (thing);
#endif
      rc->rc_n_full++;
      if (rc->rc_item_time && rc->rc_size < rc->rc_max_size)
	{
	  rc_resize (rc, rc->rc_size * 2);
	  rc->rc_item_time[rc->rc_fill] = time;
	  rc->rc_items[rc->rc_fill++] = item;
	  if (rc->rc_mtx)
	    mutex_leave (rc->rc_mtx);
	  return 1;
	}
      if (rc_mtx)
	mutex_leave (rc_mtx);
      if (rc->rc_destructor)
	(*rc->rc_destructor) (item);
      return 0;
    }
}


unsigned long
DBG_NAME(resource_clear) (DBG_PARAMS  resource_t * rc, rc_destr_t destruct)
{
  unsigned long cnt = 0;
  void *item = NULL;
  if (!destruct && !rc->rc_destructor)
    GPF_T1 ("No destructor for a resource");
  if (!destruct)
    destruct = rc->rc_destructor;
  while (NULL != (item = DBG_NAME(resource_get_1) (DBG_ARGS  rc, 0)))
    {
#ifdef MALLOC_DEBUG
      malhdr_t *thing = resource_find_malhdr (item);
      if (NULL != thing)
        dbg_count_like_free (DBG_ARGS  thing);
      mutex_enter (res_to_thing_mtx);
      remhash (item, res_to_thing);
      mutex_leave (res_to_thing_mtx);
      free (thing);
#endif
      destruct (item);
      cnt++;
    }
  return cnt;
}
