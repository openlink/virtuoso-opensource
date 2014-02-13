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
 *  Copyright (C) 1998-2014 OpenLink Software
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
resource_t *resource_allocate (uint32 sz, rc_constr_t constructor, rc_destr_t destructor, rc_destr_t clear_func, void *client_data);
resource_t *resource_allocate_primitive (uint32 sz, int max_sz);
void resource_no_sem (resource_t * rc);
void *resource_get (resource_t * rc);
void *resource_get_1 (resource_t * rc, int make_new);
int resource_store (resource_t * rc, void *item);
int resource_store_fifo (resource_t * rc, void *item, int n_fifo);
int resource_store_timed (resource_t * rc, void *item);
unsigned long resource_clear (resource_t * rc, rc_destr_t destruct);
void _resource_adjust (resource_t * rc);
#endif
