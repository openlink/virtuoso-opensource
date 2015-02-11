/*
 *  schspace.h
 *
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

#ifndef _SCHSPACE_H
#define _SCHSPACE_H

#define DBG_HASHEXT_NAME(name) DBG_NAME(name)

id_hash_t *DBG_HASHEXT_NAME (id_casemode_hash_create) (DBG_PARAMS id_hashed_key_t buckets);
void DBG_HASHEXT_NAME (id_casemode_hash_copy) (DBG_PARAMS id_hash_t *to, id_hash_t * from);
void DBG_HASHEXT_NAME(id_casemode_hash_free) (DBG_PARAMS id_hash_t * hash);
caddr_t DBG_HASHEXT_NAME(id_casemode_hash_set) (DBG_PARAMS id_hash_t * ht, caddr_t _qn, caddr_t _o, caddr_t data);
caddr_t id_casemode_hash_get (id_hash_t * ht, caddr_t _qn, caddr_t _o);
int DBG_HASHEXT_NAME(id_casemode_hash_remove) (DBG_PARAMS id_hash_t * ht, caddr_t _qn, caddr_t _o);

#ifdef MALLOC_DEBUG
#define id_casemode_hash_create(buckets) \
	DBG_HASHEXT_NAME(id_casemode_hash_create)(__FILE__, __LINE__, buckets)
#define id_casemode_hash_copy(to,from) \
	DBG_HASHEXT_NAME(id_casemode_hash_copy)(__FILE__, __LINE__, to,from)
#define id_casemode_hash_free(hash) \
	DBG_HASHEXT_NAME(id_casemode_hash_free)(__FILE__, __LINE__, hash)
#define id_casemode_hash_set(ht,_qn,_o,data) \
	DBG_HASHEXT_NAME(id_casemode_hash_set)(__FILE__, __LINE__, ht,_qn,_o,data)
#define id_casemode_hash_remove(ht,_qn,_o) \
	DBG_HASHEXT_NAME(id_casemode_hash_remove)(__FILE__, __LINE__, ht,_qn,_o)
#endif

void *sch_name_to_object (struct dbe_schema_s *sc, sc_object_type type, const char *name, char *q_def, char *o_default,
    int find_many);
void * sch_name_to_object_sc (struct dbe_schema_s* sc, sc_object_type type, char *o_default,
    char *o, char *qn, int find_many);

typedef struct id_casemode_entry_llist_s
{
  caddr_t owner;
  caddr_t data;
  struct id_casemode_entry_llist_s *next;
} id_casemode_entry_llist_t;

typedef struct id_casemode_hash_iterator_s
{
  id_hash_iterator_t hit;
  id_casemode_entry_llist_t *iter;
} id_casemode_hash_iterator_t;

void id_casemode_hash_iterator (id_casemode_hash_iterator_t * hit, id_hash_t * ht);
int id_casemode_hit_next (id_casemode_hash_iterator_t * hit, char **data);

#endif /* _SCHSPACE_H */
