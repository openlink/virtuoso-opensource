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
resource_allocate (uint32 sz, rc_constr_t constructor, rc_destr_t destructor, rc_destr_t clear_func, void *client_data)
{
  resource_t *rc;

  rc = (resource_t *) malloc (sizeof (resource_t));
  /* use malloc so as to be usable inside the dk_alloc cache system */
  memset (rc, 0, sizeof (resource_t));
  rc->rc_items = (void **) malloc (sizeof (void *) * sz);
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
resource_allocate_primitive (uint32 sz, int max_sz)
{
  resource_t *rc;

  rc = (resource_t *) malloc (sizeof (resource_t));
  memset (rc, 0, sizeof (resource_t));
  rc->rc_items = (void **) malloc (sizeof (void *) * sz);
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
_resource_adjust (resource_t * rc)
{
  /* if there are over 5% underflows and the resource overflows at least half as
   * frequently as it underflows and it's not over max size, expand */

  if (rc->rc_fill)
    GPF_T1 ("can only adjust empty rc's");
  if (rc->rc_size >= rc->rc_max_size)
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
      void **arr = (void **) malloc (rc->rc_size * 2 * sizeof (void *));
      rc->rc_size = rc->rc_size * 2;
      free ((void *) rc->rc_items);
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
resource_get_1 (resource_t * rc, int construct_new)
{
  dk_mutex_t *rc_mtx = rc->rc_mtx;

  if (rc_mtx)
    {
      mutex_enter (rc_mtx);

      ++rc->rc_gets;
      if (rc->rc_fill)
	{
	  void *val;

	  val = (rc->rc_items[--(rc->rc_fill)]);

	  mutex_leave (rc_mtx);
	  return val;
	}
      else
	{
	  void *data;
	  if (++rc->rc_n_empty % 1000 == 0)
	    _resource_adjust (rc);
	  mutex_leave (rc_mtx);
	  if (rc->rc_constructor && construct_new)
	    data = (*rc->rc_constructor) (rc->rc_client_data);
	  else
	    data = NULL;
	  return data;
	}
    }
  else
    {
      ++rc->rc_gets;
      if (rc->rc_fill)
	{
	  void *val;

	  val = (rc->rc_items[--(rc->rc_fill)]);

	  return val;
	}
      else
	{
	  void *data;
	  if (++rc->rc_n_empty % 1000 == 0)
	    _resource_adjust (rc);
	  if (rc->rc_constructor && construct_new)
	    data = (*rc->rc_constructor) (rc->rc_client_data);
	  else
	    data = NULL;

	  return data;
	}
    }
}


void *
resource_get (resource_t * rc)
{
  return resource_get_1 (rc, 1);
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
resource_store (resource_t * rc, void *item)
{
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
      rc->rc_n_full++;
      if (rc_mtx)
	mutex_leave (rc_mtx);
      if (rc->rc_destructor)
	(*rc->rc_destructor) (item);
      return 0;
    }
}


unsigned long
resource_clear (resource_t * rc, rc_destr_t destruct)
{
  unsigned long cnt = 0;
  void *data = NULL;
  if (!destruct && !rc->rc_destructor)
    GPF_T1 ("No destructor for a resource");

  if (!destruct)
    destruct = rc->rc_destructor;
  while (NULL != (data = resource_get_1 (rc, 0)))
    {
      destruct (data);
      cnt++;
    }
  return cnt;
}
