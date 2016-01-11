/*
 *  schspace.c
 *
 *  $Id$
 *
 *  schema space resolution functions
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2016 OpenLink Software
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
#include "libutil.h"
#include "sqlfn.h"
#include "wifn.h"

static id_hashed_key_t (*casemode_strhash) (char *strp) = NULL;
static int (*casemode_strhashcmp) (char *x, char *y) = NULL;

static id_hashed_key_t
strihash (char *strp)
{
  char *str = *(char **) strp;
  id_hashed_key_t h = 1;
  while (*str)
    {
      h = (h + h * toupper (*str)) ^ h >> 17;
      str++;
    }
  return (h & ID_HASHED_KEY_MASK);
}


static int
strihashcmp (char *x, char *y)
{
  return 0 == stricmp(((char **)x)[0], ((char **)y)[0]);
}


id_hash_t *
DBG_HASHEXT_NAME (id_casemode_hash_create) (DBG_PARAMS id_hashed_key_t buckets)
{
  if (!casemode_strhash)
    {
      casemode_strhash = case_mode == CM_MSSQL ? strihash : strhash;
      casemode_strhashcmp = case_mode == CM_MSSQL ? strihashcmp : strhashcmp;
    }

  return (DBG_HASHEXT_NAME(id_hash_allocate) (DBG_ARGS buckets,
	sizeof (void *), sizeof (void *),
	casemode_strhash, casemode_strhashcmp));
}


static int
id_casemode_hit_next_inner (id_casemode_hash_iterator_t * hit, caddr_t *data, caddr_t *k, caddr_t *k2)
{
  id_casemode_entry_llist_t **ptr = NULL;
  while (1)
    {
      if (hit->iter)
	{
	  *data = (caddr_t) &(hit->iter->data);
	  *k2 = (caddr_t) &hit->iter->owner;
	  hit->iter = hit->iter->next;
	  return 1;
	}

      if (!hit_next (&(hit->hit), k, (caddr_t *) &ptr))
	{
	  return 0;
	}
      if (ptr)
	hit->iter = *ptr;
    }
}


void
DBG_HASHEXT_NAME (id_casemode_hash_copy) (DBG_PARAMS id_hash_t *to, id_hash_t * from)
{
  id_casemode_hash_iterator_t hit;
  char **kp;
  char **kp2;
  char *dp;

  id_casemode_hash_iterator (&hit, from);

  while (id_casemode_hit_next_inner (&hit, (caddr_t *) &dp, (caddr_t *)&kp, (caddr_t *)&kp2))
    {
      id_casemode_hash_set (to, (caddr_t) *kp, (caddr_t) *kp2, (caddr_t) dp);
    }
}


void
DBG_HASHEXT_NAME(id_casemode_hash_free) (DBG_PARAMS id_hash_t * hash)
{
  id_hash_iterator_t hit;
  char *kp;
  char *dp;

  id_hash_iterator (&hit, hash);
  while (hit_next (&hit, &kp, &dp))
    {
      if (dp)
	{
	  id_casemode_entry_llist_t *iter = *(id_casemode_entry_llist_t **) dp;
	  while (iter)
	    {
	      id_casemode_entry_llist_t *iter_next = iter->next;
	      dk_free (iter, sizeof (id_casemode_entry_llist_t));
	      iter = iter_next;
	    }
	}
    }
  DBG_HASHEXT_NAME(id_hash_free) (DBG_ARGS hash);
}


void
id_casemode_hash_print_dbx (id_hash_t *it, caddr_t qn, caddr_t o)
{
  id_casemode_hash_iterator_t hit;
  caddr_t *k1 = NULL;
  caddr_t *k2 = NULL;
  caddr_t data = NULL;

  id_casemode_hash_iterator (&hit, it);
  fprintf (stderr, "***ht\n");
  while (id_casemode_hit_next_inner (&hit, &data, (caddr_t *) &k1, (caddr_t *) &k2))
    {
      fprintf (stderr, "QN:[%s] O:[%s]\n", *k1, *k2);
    }
  fprintf (stderr, "###ht\n");
}


caddr_t
DBG_HASHEXT_NAME(id_casemode_hash_set) (DBG_PARAMS id_hash_t * ht, caddr_t _qn, caddr_t _o, caddr_t data)
{
  id_casemode_entry_llist_t **list;
  caddr_t ret;

  list = (id_casemode_entry_llist_t **) id_hash_get (ht, (caddr_t) &_qn);
  if (list)
    {
      id_casemode_entry_llist_t *iter = *list;
      while (iter)
	{
	  if (casemode_strhashcmp ((char *) &(iter->owner), (char *) &_o))
	    {
	      caddr_t old_value = *((caddr_t *)iter->data);
	      iter->data = data;
	      ret = old_value;
	      break;
	    }
	  iter = iter->next;
	}
      if (!iter)
	{
	  NEW_VARZ (id_casemode_entry_llist_t, new_iter);
	  new_iter->owner = _o;
	  new_iter->data = *((caddr_t *)data);
	  new_iter->next = *list;
	  *list = new_iter;
	  ret = NULL;
	}
    }
  else
    {
      NEW_VARZ (id_casemode_entry_llist_t, new_iter);
      new_iter->owner = _o;
      new_iter->data = *((caddr_t *)data);

      DBG_HASHEXT_NAME (id_hash_set) (DBG_ARGS ht, (caddr_t)&_qn, (caddr_t) &new_iter);
      ret = NULL;
    }

  return ret;
}


caddr_t
id_casemode_hash_get (id_hash_t * ht, caddr_t _qn, caddr_t _o)
{
  id_casemode_entry_llist_t **list;

  list = (id_casemode_entry_llist_t **) id_hash_get (ht, (caddr_t) &_qn);

  if (list && *list)
    {
      id_casemode_entry_llist_t *iter = *list;
      while (iter)
	{
	  if (casemode_strhashcmp ((char *) &_o, (char *) &(iter->owner)))
	    return (caddr_t) &(iter->data);
	  iter = iter->next;
	}
    }
  return NULL;
}


int
DBG_HASHEXT_NAME(id_casemode_hash_remove) (DBG_PARAMS id_hash_t * ht, caddr_t _qn, caddr_t _o)
{
  id_casemode_entry_llist_t **list;

  list = (id_casemode_entry_llist_t **) id_hash_get (ht, (caddr_t) &_qn);

  if (list && *list)
    {
      id_casemode_entry_llist_t seed;
      id_casemode_entry_llist_t *iter = &seed;
      seed.next = *list;
      while (iter->next)
	{
	  if (casemode_strhashcmp ((char *) &(iter->next->owner), (char *) &_o))
	    {
	      id_casemode_entry_llist_t *to_delete = iter->next;
	      iter->next = iter->next->next;
	      dk_free (to_delete, sizeof (id_casemode_entry_llist_t));
	      *list = seed.next;
	      return 1;
	    }
	  iter = iter->next;
	}
    }
  return 0;
}


void *
sch_name_to_object_sc (dbe_schema_t * sc, sc_object_type type, char *o_default,
    char *o, char *qn, int find_many)
{
  id_casemode_entry_llist_t **list_ptr;
  id_casemode_entry_llist_t *found = NULL;
  int n_found = 0;

  if (NULL != (list_ptr = (id_casemode_entry_llist_t **) id_hash_get (sc->sc_name_to_object[type], (caddr_t) &qn))
      && NULL != *list_ptr)
    {
      id_casemode_entry_llist_t *iter = *list_ptr;
      while (iter)
	{
	  if (o[0])
	    {
	      if (casemode_strhashcmp ((char *) &o, (char *) &(iter->owner)))
		return iter->data;
	      else
		{
		  iter = iter->next;
		  continue;
		}
	    }
	  else if (o_default)
	    {
	      if (casemode_strhashcmp ((char *) &(o_default), (char *) &(iter->owner)))
		return iter->data;
	      found = iter;
	      n_found += 1;
	    }
	  iter = iter->next;
	}
    }
  if (found && o_default)
    {
      if (n_found > 1)
	return ((void *) -1);
      else
	return found->data;
    }

  if (sc->sc_prev)
    return sch_name_to_object_sc (sc->sc_prev, type, o_default, o, qn, find_many);
  return NULL;
}


void *
sch_name_to_object (dbe_schema_t *sc, sc_object_type type, const char *name, char *q_def, char *o_default,
    int find_many)
{
  void *obj;

  char q[MAX_NAME_LEN];
  char o[MAX_NAME_LEN];
  char n[MAX_NAME_LEN];
  char qn[2*MAX_NAME_LEN + 1];
  q[0] = 0;
  o[0] = 0;
  n[0] = 0;
  sch_split_name (q_def, name, q, o, n);
  strcpy_ck (qn, q);
  strcat_ck (qn, ".");
  strcat_ck (qn, n);

  obj = sch_name_to_object_sc (sc, type, o_default, o, qn, find_many);
  if ((void *) -1L == obj)
    return NULL;
  return obj;
}


void
id_casemode_hash_iterator (id_casemode_hash_iterator_t * hit, id_hash_t * ht)
{
  id_hash_iterator (&(hit->hit), ht);
  hit->iter = NULL;
}


int
id_casemode_hit_next (id_casemode_hash_iterator_t * hit, char **data)
{
  char **k = NULL, **k2 = NULL;
  return id_casemode_hit_next_inner (hit, (caddr_t *) data, (caddr_t *) &k, (caddr_t *) &k2);
}
