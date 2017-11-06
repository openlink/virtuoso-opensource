/*
 *  Dkresource.h
 *
 *  $Id$
 *
 *  Resource Management
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

#ifndef _DKRESOURCE_H
#define _DKRESOURCE_H

#ifdef MALLOC_DEBUG
#define RC_DBG
#endif

typedef void *(*rc_constr_t) (void *cdata);
typedef void (*rc_destr_t) (void *item);

typedef struct resource_s
{
  uint32 		rc_fill;
  uint32 		rc_size;
  void **		rc_items;
  uint32 *		rc_item_time;
  void *		rc_client_data;
  rc_constr_t 		rc_constructor;
  rc_destr_t 		rc_destructor;
  rc_destr_t 		rc_clear_func;
  dk_mutex_t *		rc_mtx;
  /* Monitoring */
  uint32 		rc_gets;
  uint32 		rc_stores;
  uint32 		rc_n_empty;
  uint32 		rc_n_full;
  uint32 		rc_max_size;
#ifdef RC_DBG
  struct resource_s **rc_family;
  int                 rc_family_size;
#endif
} resource_t;


/* Dkresource.c */
extern resource_t *DBG_NAME(resource_allocate) (DBG_PARAMS  uint32 sz, rc_constr_t constructor, rc_destr_t destructor, rc_destr_t clear_func, void *client_data);
extern resource_t *DBG_NAME(resource_allocate_primitive) (DBG_PARAMS  uint32 sz, int max_sz);
extern void resource_no_sem (resource_t * rc);
extern void DBG_NAME(resource_track_new) (DBG_PARAMS  void *item);
extern void DBG_NAME(resource_track_delete) (DBG_PARAMS  void *item);
extern void * DBG_NAME(resource_get) (DBG_PARAMS  resource_t * rc);
extern void * DBG_NAME(resource_get_1) (DBG_PARAMS  resource_t * rc, int make_new);
extern void DBG_NAME(resource_get_batch) (DBG_PARAMS  resource_t * rc, void **tgt_array, int batch_size, int make_new);
extern int DBG_NAME(resource_store) (DBG_PARAMS  resource_t * rc, void *item);
extern int DBG_NAME(resource_store_fifo) (DBG_PARAMS  resource_t * rc, void *item, int n_fifo);
extern int DBG_NAME(resource_store_timed) (DBG_PARAMS  resource_t * rc, void *item);
extern unsigned long DBG_NAME(resource_clear) (DBG_PARAMS  resource_t * rc, rc_destr_t destruct);
extern void DBG_NAME(_resource_adjust) (DBG_PARAMS  resource_t * rc);
extern void DBG_NAME(rc_resize) (DBG_PARAMS  resource_t * rc, int new_sz);
#ifdef MALLOC_DEBUG
#define resource_allocate(sz,constructor,destructor,clear_func,client_data)	dbg_resource_allocate(__FILE__,__LINE__,(sz),(constructor),(destructor),(clear_func),(client_data))
#define resource_allocate_primitive(sz,max_sz)					dbg_resource_allocate_primitive (__FILE__,__LINE__,(sz),(max_sz))
#define resource_track_new(item)						dbg_resource_track_new(__FILE__,__LINE__,(item))
#define resource_track_delete(item)						dbg_resource_track_delete(__FILE__,__LINE__,(item))
#define resource_get(rc)							dbg_resource_get(__FILE__,__LINE__,(rc))
#define resource_get_1(rc,make_new)						dbg_resource_get_1(__FILE__,__LINE__,(rc),(make_new))
#define resource_get_batch(rc,tgt_array,batch_size,make_new)			dbg_resource_get_batch (__FILE__,__LINE__,(rc),(tgt_array),(batch_size),(make_new))
#define resource_store(rc,item)							dbg_resource_store(__FILE__,__LINE__,(rc),(item))
#define resource_store_fifo(rc,item,n_fifo)					dbg_resource_store_fifo(__FILE__,__LINE__,(rc),(item),(n_fifo))
#define resource_store_timed(rc,item)						dbg_resource_store_timed(__FILE__,__LINE__,(rc),(item))
#define resource_clear(rc,destruct)						dbg_resource_clear(__FILE__,__LINE__,(rc),(destruct))
#define _resource_adjust(rc)							dbg__resource_adjust(__FILE__,__LINE__,(rc))
#define rc_resize(rc,new_sz)							dbg_rc_resize(__FILE__,__LINE__,(rc),(new_sz))
#else
#define resource_track_new(item)						do { } while (0)
#define resource_track_delete(item)						do { } while (0)
#endif

#endif
