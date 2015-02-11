/*
 *  Dksets.c
 *
 *  $Id$
 *
 *  Sets
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

#include "Dk.h"

void
DBG_NAME (dk_set_push) (DBG_PARAMS s_node_t ** set, void *item)
{
  s_node_t *newn = (s_node_t *) DK_ALLOC (sizeof (s_node_t));
  newn->next = *set;
  newn->data = item;
  *set = newn;
}

void
DBG_NAME (dk_set_push_two) (DBG_PARAMS s_node_t ** set, void *car_item, void *cadr_item)
{
  s_node_t *cadr_newn = (s_node_t *) DK_ALLOC (sizeof (s_node_t));
  s_node_t *car_newn = (s_node_t *) DK_ALLOC (sizeof (s_node_t));
  cadr_newn->next = *set;
  cadr_newn->data = cadr_item;
  car_newn->next = cadr_newn;
  car_newn->data = car_item;
  *set = car_newn;
}

void
DBG_NAME (dk_set_pushnew) (DBG_PARAMS s_node_t ** set, void *item)
{
  if (!dk_set_member (*set, item))
    {
      s_node_t *newn = (s_node_t *) DK_ALLOC (sizeof (s_node_t));
      newn->next = *set;
      newn->data = item;
      *set = newn;
    }
}


void *
DBG_NAME (dk_set_pop) (DBG_PARAMS s_node_t ** set)
{
  if (*set)
    {
      void *item;
      s_node_t *old = *set;
      *set = old->next;
      item = old->data;
      DK_FREE (old, sizeof (s_node_t));

      return item;
    }

  return NULL;
}


int
DBG_NAME (dk_set_delete) (DBG_PARAMS dk_set_t * set, void *item)
{
  s_node_t *node = *set;
  dk_set_t *previous = set;
  while (node)
    {
      if (node->data == item)
	{
	  *previous = node->next;
	  DK_FREE (node, sizeof (s_node_t));

	  return 1;
	}
      previous = &(node->next);
      node = node->next;
    }
  return 0;
}


void *
DBG_NAME (dk_set_delete_nth) (DBG_PARAMS dk_set_t * set, int idx)
{
  s_node_t *node = *set;
  dk_set_t *previous = set;
  if (0 > idx)
    return NULL;
  while (node)
    {
      if (0 == idx)
	{
	  void *res = node->data;
	  *previous = node->next;
	  DK_FREE (node, sizeof (s_node_t));
	  return res;
	}
      previous = &(node->next);
      node = node->next;
      idx--;
    }
  return NULL;
}


uint32
dk_set_length (s_node_t * set)
{
  uint32 count;

  for (count = 0; set; set = set->next)
    count++;

  return count;
}


dk_set_t
dk_set_last (dk_set_t set)
{
  dk_set_t s;
  if (!set)
    return set;
  else
    {
      for (s = set; s->next; s = s->next)
	;
      return s;
    }
}


dk_set_t
dk_set_conc (dk_set_t s1, dk_set_t s2)
{
  dk_set_t last = dk_set_last (s1);
  if (last)
    {
      last->next = s2;
      return s1;
    }
  else
    {
      return s2;
    }
}


dk_set_t
DBG_NAME (dk_set_cons) (DBG_PARAMS void *s1, dk_set_t s2)
{
  dk_set_t tmp = (dk_set_t) DK_ALLOC (sizeof (s_node_t));
  tmp->data = s1;
  tmp->next = s2;
  return tmp;
}


void
DBG_NAME (dk_set_free) (DBG_PARAMS s_node_t * set)
{
  dk_set_t next;
  while (set)
    {
      next = set->next;
      DK_FREE ((void *) set, sizeof (s_node_t));
      set = next;
    }
}


s_node_t *
dk_set_member (s_node_t * set, void *elt)
{
  while (set)
    {
      if (elt == set->data)
	return set;
      set = set->next;
    }
  return NULL;
}


void **
DBG_NAME (dk_set_to_array) (DBG_PARAMS s_node_t * set)
{
  void **array;
  uint32 len;
  uint32 inx;

  len = dk_set_length (set);
  array = (void **) DBG_NAME (dk_alloc_box) (DBG_ARGS len * sizeof (void *), DV_ARRAY_OF_POINTER);
  inx = 0;
  DO_SET (void *, elt, &set)
  {
    array[inx++] = elt;
  }
  END_DO_SET ();
  return array;
}


caddr_t
DBG_NAME (list_to_array) (DBG_PARAMS s_node_t * set)
{
  void **array;
  uint32 len;
  uint32 inx;

  len = dk_set_length (set);
  array = (void **) DBG_NAME (dk_alloc_box) (DBG_ARGS len * sizeof (void *), DV_ARRAY_OF_POINTER);
  inx = 0;
  DO_SET (void *, elt, &set)
  {
    array[inx++] = elt;
  }
  END_DO_SET ();
  DBG_NAME (dk_set_free) (DBG_ARGS set);
  return (caddr_t) array;
}


caddr_t
DBG_NAME (copy_list_to_array) (DBG_PARAMS s_node_t * set)
{
  void **array;
  uint32 len;
  uint32 inx;

  len = dk_set_length (set);
  array = (void **) DBG_NAME (dk_alloc_box) (DBG_ARGS len * sizeof (void *), DV_ARRAY_OF_POINTER);
  inx = 0;
  DO_SET (void *, elt, &set)
  {
    array[inx++] = elt;
  }
  END_DO_SET ();
  return (caddr_t) array;
}


caddr_t
DBG_NAME (revlist_to_array) (DBG_PARAMS s_node_t * set)
{
  void **array;
  uint32 len;
  uint32 inx;

  inx = len = dk_set_length (set);
  array = (void **) DBG_NAME (dk_alloc_box) (DBG_ARGS len * sizeof (void *), DV_ARRAY_OF_POINTER);
  DO_SET (void *, elt, &set)
  {
    array[--inx] = elt;
  }
  END_DO_SET ();
  DBG_NAME (dk_set_free) (DBG_ARGS set);
  return (caddr_t) array;
}


dk_set_t
dk_set_nreverse (dk_set_t set)
{
  dk_set_t next;
  dk_set_t next2;

  if (!set)
    return NULL;

  next = set->next;
  set->next = NULL;

  for (;;)
    {
      if (!next)
	return set;

      next2 = next->next;
      next->next = set;
      set = next;
      next = next2;
    }
}


#define STEP_2(node) \
  if (node) node = node -> next; \
  if (node) node = node -> next;


/* true if non-circular and all nodes are valid pointers. */
void
dk_set_check_straight (dk_set_t set)
{
  dk_set_t fast = set;
  dk_set_t slow = set;

  STEP_2 (fast);
  while (slow)
    {
      if (slow == fast)
	{
	  GPF_T1 ("Circular list");
	}
      dk_alloc_assert (slow);
      STEP_2 (fast);
      slow = slow->next;
    }
}


int
dk_set_position (dk_set_t set, void *elt)
{
  int nth = 0;
  while (set)
    {
      if (set->data == elt)
	return nth;
      nth++;
      set = set->next;
    }
  return -1;
}


int
dk_set_position_of_string (dk_set_t set, const char *strg)
{
  int nth = 0;
  while (set)
    {
      if (!strcmp ((const char *) set->data, strg))
	return nth;
      nth++;
      set = set->next;
    }
  return -1;
}


void *
dk_set_get_keyword (dk_set_t set, const char *key_strg, void *dflt_val)
{
  while (set)
    {
      if (!strcmp ((const char *) set->data, key_strg))
	return set->next->data;
      set = set->next->next;
    }
  return dflt_val;
}


void **
dk_set_getptr_keyword (dk_set_t set, const char *key_strg)
{
  while (set)
    {
      if (!strcmp ((const char *) set->data, key_strg))
	return &(set->next->data);
      set = set->next->next;
    }
  return NULL;
}


void *
dk_set_nth (dk_set_t set, int nth)
{
  int inx;
  for (inx = 0; inx < nth; inx++)
    {
      if (set)
	set = set->next;
      else
	break;
    }
  if (set)
    return (set->data);
  else
    return NULL;
}


dk_set_t
DBG_NAME (dk_set_copy) (DBG_PARAMS dk_set_t s)
{
  dk_set_t r = NULL;
  dk_set_t *last = &r;
  while (s)
    {
      dk_set_t n = (dk_set_t) DK_ALLOC (sizeof (s_node_t));
      *last = n;
      n->data = s->data;
      n->next = NULL;
      last = &n->next;
      s = s->next;
    }
  return r;
}


int
dk_set_is_subset (dk_set_t super, dk_set_t sub)
{
  DO_SET (void *, elt, &sub)
  {
    if (!dk_set_member (super, elt))
      return 0;
  }
  END_DO_SET ();
  return 1;
}


/* Original signatures should exist for EXE-EXPORTed functions */
#ifdef MALLOC_DEBUG
#undef dk_set_delete
int
dk_set_delete (dk_set_t * set, void *item)
{
  return dbg_dk_set_delete (__FILE__, __LINE__, set, item);
}


#undef dk_set_delete_nth
void *
dk_set_delete_nth (dk_set_t * set, int n)
{
  return dbg_dk_set_delete_nth (__FILE__, __LINE__, set, n);
}


#undef dk_set_push
void
dk_set_push (s_node_t ** set, void *item)
{
  dbg_dk_set_push (__FILE__, __LINE__, set, item);
}

#undef dk_set_push_two
void
dk_set_push_two (s_node_t ** set, void *car_item, void *cadr_item)
{
  dbg_dk_set_push_two (__FILE__, __LINE__, set, car_item, cadr_item);
}

#undef dk_set_pushnew
void
dk_set_pushnew (s_node_t ** set, void *item)
{
  dbg_dk_set_pushnew (__FILE__, __LINE__, set, item);
}

#undef dk_set_pop
void *
dk_set_pop (s_node_t ** set)
{
  return dbg_dk_set_pop (__FILE__, __LINE__, set);
}


#undef list_to_array
caddr_t
list_to_array (dk_set_t l)
{
  return dbg_list_to_array (__FILE__, __LINE__, l);
}

#undef copy_list_to_array
caddr_t
copy_list_to_array (dk_set_t l)
{
  return dbg_copy_list_to_array (__FILE__, __LINE__, l);
}
#undef revlist_to_array
caddr_t
revlist_to_array (dk_set_t l)
{
  return dbg_revlist_to_array (__FILE__, __LINE__, l);
}
#endif
