/*
 *  Dksets.h
 *
 *  $Id$
 *
 *  Sets
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

#ifndef _DKSETS_H
#define _DKSETS_H

typedef struct s_node_s s_node_t, *dk_set_t;
struct s_node_s
{
  void *	data;
  s_node_t *	next;
};

/* this is like car or first in lisp */
#define DK_SET_FIRST(set) \
	(*set ? (((dk_set_t) *set)->data) : NULL)

#ifdef DO_SET_DEBUG

#define DO_SET(_type, _var, _set) \
	{ \
	  _type _var; \
	  s_node_t *_iter = *(_set); \
	  s_node_t *_nxt; \
	  for ( ; (NULL != _iter); _iter = _nxt) \
	    { \
	      _var = (_type) (_iter->data); \
	      _nxt = _iter->next;

#define DO_KEYWORD_SET(_keyvar, _type, _valuevar, _set) \
	{ \
	  ccaddr_t _keyvar; \
	  _type _valuevar; \
	  s_node_t *_iter = *(_set); \
	  s_node_t *_nxt; \
	  for ( ; (NULL != _iter); _iter = _nxt) \
	    { \
	      _keyvar = (_type) (_iter->data); \
	      _nxt = _iter->next; \
	      _valuevar = (_type) (_nxt->data); \
	      _nxt = _nxt->next;

#define DO_SET_WRITABLE(_type, _var, _iter, _set) \
	{ \
	  _type _var; \
	  s_node_t *_nxt; \
	  for ((_iter) = *(_set) ; (NULL != (_iter)); (_iter) = _nxt) \
	    { \
	      _var = (_type) ((_iter)->data); \
	      _nxt = (_iter)->next;

#define DO_SET_WRITABLE2(_type, _var, _iter, _nxt, _set) \
	{ \
	  _type _var; \
	  for ((_iter) = *(_set) ; (NULL != (_iter)); (_iter) = (_nxt)) \
	    { \
	      _var = (_type) ((_iter)->data); \
	      (_nxt) = (_iter)->next;

#else

#define DO_SET(type, var, set) \
	{ \
	  type var; \
	  s_node_t *iter = *(set); \
	  s_node_t *nxt; \
	  for ( ; (NULL != iter); iter = nxt) \
	    { \
	      var = (type) (iter->data); \
	      nxt = iter->next;

#define DO_KEYWORD_SET(keyvar, type, valuevar, set) \
	{ \
	  ccaddr_t keyvar; \
	  type valuevar; \
	  s_node_t *iter = *(set); \
	  s_node_t *nxt; \
	  for ( ; (NULL != iter); iter = nxt) \
	    { \
	      keyvar = (ccaddr_t) (iter->data); \
	      nxt = iter->next; \
	      valuevar = (type) (nxt->data); \
	      nxt = nxt->next;

#define DO_SET_WRITABLE(type, var, iter, set) \
	{ \
	  type var; \
	  s_node_t *nxt; \
	  for ((iter) = *(set) ; (NULL != (iter)); (iter) = nxt) \
	    { \
	      var = (type) ((iter)->data); \
	      nxt = (iter)->next;

#define DO_SET_WRITABLE2(type, var, iter, nxt, set) \
	{ \
	  type var; \
	  for ((iter) = *(set) ; (NULL != (iter)); (iter) = (nxt)) \
	    { \
	      var = (type) ((iter)->data); \
	      (nxt) = (iter)->next;

#endif

#define END_DO_SET()   \
	    } \
	}


/* Dksets.c */
uint32 dk_set_length (s_node_t * set);
dk_set_t dk_set_last (dk_set_t set);
dk_set_t dk_set_conc (dk_set_t s1, dk_set_t s2);

EXE_EXPORT (caddr_t, list_to_array, (dk_set_t l));
EXE_EXPORT (caddr_t, copy_list_to_array, (dk_set_t l));
EXE_EXPORT (caddr_t, revlist_to_array, (dk_set_t l));
EXE_EXPORT (int, dk_set_delete, (dk_set_t * set, void *item));
EXE_EXPORT (void *, dk_set_delete_nth, (dk_set_t * set, int idx));
EXE_EXPORT (void, dk_set_push, (s_node_t ** set, void *item));
EXE_EXPORT (void, dk_set_push_two, (s_node_t ** set, void *car_item, void *cadr_item));
EXE_EXPORT (void, dk_set_pushnew, (s_node_t ** set, void *item));
EXE_EXPORT (void *, dk_set_pop, (s_node_t ** set));
EXE_EXPORT (void *, dk_set_pop_or_null, (s_node_t ** set));

#ifdef MALLOC_DEBUG
dk_set_t dbg_dk_set_cons (const char *file, int line, void *s1, dk_set_t s2);
void **dbg_dk_set_to_array (const char *file, int line, s_node_t * set);
caddr_t dbg_list_to_array (const char *file, int line, dk_set_t l);
caddr_t dbg_copy_list_to_array (const char *file, int line, dk_set_t l);
caddr_t dbg_revlist_to_array (const char *file, int line, dk_set_t l);
void dbg_dk_set_push (const char *file, int line, s_node_t ** set, void *item);
void dbg_dk_set_push_two (const char *file, int line, s_node_t ** set, void *car_item, void *cadr_item);
void dbg_dk_set_pushnew (const char *file, int line, s_node_t ** set, void *item);
void *dbg_dk_set_pop (const char *file, int line, s_node_t ** set);
void *dbg_dk_set_pop_or_null (const char *file, int line, s_node_t ** set);
int dbg_dk_set_delete (const char *file, int line, dk_set_t * set, void *item);
void *dbg_dk_set_delete_nth (const char *file, int line, dk_set_t * set, int idx);
void dbg_dk_set_free (const char *file, int line, s_node_t * set);
dk_set_t dbg_dk_set_copy (const char *file, int line, dk_set_t s);

#ifndef _USRDLL
#ifndef EXPORT_GATE

#define dk_set_cons(S1,S2)	dbg_dk_set_cons (__FILE__, __LINE__, (S1), (S2))
#define dk_set_to_array(S)	dbg_dk_set_to_array (__FILE__, __LINE__, (S))
#define list_to_array(S)	dbg_list_to_array (__FILE__, __LINE__, (S))
#define copy_list_to_array(S)	dbg_copy_list_to_array (__FILE__, __LINE__, (S))
#define revlist_to_array(S)	dbg_revlist_to_array (__FILE__, __LINE__, (S))
#define dk_set_push(S,I)	dbg_dk_set_push (__FILE__, __LINE__, (S), (I))
#define dk_set_push_two(S,A,AD)	dbg_dk_set_push_two (__FILE__, __LINE__, (S), (A), (AD))
#define dk_set_pushnew(S,I)	dbg_dk_set_pushnew (__FILE__, __LINE__, (S), (I))
#define dk_set_pop(S)		dbg_dk_set_pop (__FILE__, __LINE__, (S))
#define dk_set_pop_or_null(S)	dbg_dk_set_pop_or_null (__FILE__, __LINE__, (S))
#define dk_set_delete(S,I)	dbg_dk_set_delete (__FILE__, __LINE__, (S), (I))
#define dk_set_delete_nth(S,N)	dbg_dk_set_delete_nth (__FILE__, __LINE__, (S), (N))
#define dk_set_free(S)		dbg_dk_set_free (__FILE__,__LINE__, (S))
#define dk_set_copy(S)		dbg_dk_set_copy (__FILE__,__LINE__, (S))

#endif
#endif

#else
dk_set_t dk_set_cons (void *s1, dk_set_t s2);
void **dk_set_to_array (s_node_t * set);
caddr_t copy_list_to_array (dk_set_t l);
caddr_t revlist_to_array (dk_set_t l);
void dk_set_pushnew (s_node_t ** set, void *item);
void *dk_set_pop (s_node_t ** set);
void dk_set_free (s_node_t * set);
dk_set_t dk_set_copy (dk_set_t s);
#endif
extern s_node_t *dk_set_member (s_node_t * set, void *elt);
extern dk_set_t dk_set_nreverse (dk_set_t set);
extern void dk_set_check_straight (dk_set_t set);
extern int dk_set_position (dk_set_t set, void *elt);
extern int dk_set_position_of_string (dk_set_t set, const char *strg);
extern void *dk_set_get_keyword (dk_set_t set, const char *key_strg, void *dflt_val);
extern void **dk_set_getptr_keyword (dk_set_t set, const char *key_strg);

extern void *dk_set_nth (dk_set_t set, int nth);
extern int dk_set_is_subset (dk_set_t super, dk_set_t sub);


#define DK_SET_FREE_Z(v) (dk_set_free (v), v = NULL)

#endif
