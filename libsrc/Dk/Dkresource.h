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

typedef void *(*rc_constr_t) (void *cdata);
typedef void (*rc_destr_t) (void *item);

typedef struct
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
} resource_t;


/* Dkresource.c */
extern resource_t *DBG_NAME(resource_allocate) (DBG_PARAMS  uint32 sz, rc_constr_t constructor, rc_destr_t destructor, rc_destr_t clear_func, void *client_data);
extern resource_t *DBG_NAME(resource_allocate_primitive) (DBG_PARAMS  uint32 sz, int max_sz);
extern void resource_no_sem (resource_t * rc);
extern void * DBG_NAME(resource_get) (DBG_PARAMS  resource_t * rc);
extern void * DBG_NAME(resource_get_1) (DBG_PARAMS  resource_t * rc, int make_new);
extern int DBG_NAME(resource_store) (DBG_PARAMS  resource_t * rc, void *item);
extern int DBG_NAME(resource_store_fifo) (DBG_PARAMS  resource_t * rc, void *item, int n_fifo);
extern int DBG_NAME(resource_store_timed) (DBG_PARAMS  resource_t * rc, void *item);
extern unsigned long resource_clear (resource_t * rc, rc_destr_t destruct);
extern void DBG_NAME(_resource_adjust) (DBG_PARAMS  resource_t * rc);
extern void DBG_NAME(rc_resize) (DBG_PARAMS  resource_t * rc, int new_sz);
#ifdef MALLOC_DEBUG
#define resource_allocate(sz,constructor,destructor,clear_func,client_data)	dbg_resource_allocate(__FILE__,__LINE__,(sz),(constructor),(destructor),(clear_func),(client_data))
#define resource_allocate_primitive(sz,max_sz)					dbg_resource_allocate_primitive (__FILE__,__LINE__,(sz),(max_sz))
#define resource_get(rc)							dbg_resource_get(__FILE__,__LINE__,(rc))
#define resource_get_1(rc,make_new)						dbg_resource_get_1(__FILE__,__LINE__,(rc),(make_new))
#define resource_store(rc,item)							dbg_resource_store(__FILE__,__LINE__,(rc),(item))
#define resource_store_fifo(rc,item,n_fifo)					dbg_resource_store_fifo(__FILE__,__LINE__,(rc),(item),(n_fifo))
#define resource_store_timed(rc,item)						dbg_resource_store_timed(__FILE__,__LINE__,(rc),(item))
#define _resource_adjust(rc)							dbg__resource_adjust(__FILE__,__LINE__,(rc))
#define rc_resize(rc,new_sz)							dbg_rc_resize(__FILE__,__LINE__,(rc),(new_sz))
#endif
#endif
