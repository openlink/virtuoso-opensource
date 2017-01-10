/*
 *  Dkbasket.c
 *
 *  $Id$
 *
 *  Baskets
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

#ifndef _DKBASKET_H
#define _DKBASKET_H

/*
 * struct basket_t
 *
 * This is a queue of tokens. The next_token member of the token is used
 * to link successive tokens when they are in a basket. A token is either
 * in no basket or in exactly one basket
 */
typedef struct basket_s basket_t;

struct basket_s
{
  basket_t *	bsk_next;
  basket_t *	bsk_prev;
  union
  {
    long	longval;
    void *	ptrval;
  } bsk_data;
#ifdef MTX_DEBUG
  dk_mutex_t *	bsk_req_mtx;
#endif
};

#define bsk_count	bsk_data.longval
#define bsk_pointer	bsk_data.ptrval


/* Dkbasket.c */
void basket_init (basket_t * bsk);
void basket_add (basket_t * bsk, void *token);
void *basket_peek (basket_t * bsk);
void *basket_get (basket_t * bsk);
void *basket_first (basket_t * bsk);
int basket_is_empty (basket_t * bsk);
void mp_basket_add (mem_pool_t * mp, basket_t * bsk, void *token);
void *mp_basket_get (basket_t * bsk);


typedef int (*basket_check_t) (void *elt, void *cd);
void *basket_remove_if (basket_t * bsk, basket_check_t f, void *cd);


typedef struct rbasket_s
{
  mem_pool_t *	rb_pool;
  caddr_t **	rb_array;
  int 		rb_length;
  int 		rb_head;
  int 		rb_tail;
} rbasket_t;


void rbasket_init (rbasket_t * bsk);
void rbasket_add (rbasket_t * bsk, void *token);
void *rbasket_first (rbasket_t * bsk);
void *rbasket_get (rbasket_t * bsk);
int rbasket_count (rbasket_t * bsk);

#ifdef MTX_DEBUG
#define BSK_REQ_MTX(b, m)  		(b)->bsk_req_mtx = m
#else
#define BSK_REQ_MTX(b, m)
#endif


#ifndef __LIST2_H
#define __LIST2_H

/*#ifdef MALLOC_DEBUG
#define L2_DEBUG
#endif*/

#ifdef L2_DEBUG
#define L2_ASSERT_SOLO(elt, ep) { \
  if (NULL != elt->ep##prev) \
    { \
      if (elt == elt->ep##prev->ep##next) \
        GPF_T1("L2_DEBUG: elt is next of prev of elt before insert, about to destroy other list"); \
    } \
  if (NULL != elt->ep##next) \
    { \
      if (elt == elt->ep##next->ep##prev) \
        GPF_T1("L2_DEBUG: elt is prev of next of elt before insert, about to destroy other list"); \
    } \
}

#define L2_ASSERT_PROPER_ENDS(first, last, ep) { \
  if (NULL != first) \
    { \
      if (NULL == last) GPF_T1("L2_DEBUG: last is NULL but first is not"); \
      if (NULL != first->ep##prev) GPF_T1("L2_DEBUG: _prev of first is not NULL"); \
      if (NULL != last->ep##next) GPF_T1("L2_DEBUG: _next of last is not NULL"); \
    } \
  else \
    if (NULL != last) GPF_T1("L2_DEBUG: first is NULL but last is not"); \
}

#define L2_ASSERT_CONNECTION(first, last, ep) { \
  int __prev_ofs = ((char *)(&(first->ep##prev))) - ((char *)(first)); \
  int __next_ofs = ((char *)(&(first->ep##next))) - ((char *)(first)); \
  char *__iprev = NULL; \
  char *__iter = (void *)first; \
  while (__iter != last) { \
      if (NULL == __iter) GPF_T1("L2_DEBUG: last not found to the right of first"); \
      __iter = ((char **)(__iter + __next_ofs))[0]; \
    } \
}

#define L2_ASSERT_DISCONNECTION(first, outer, ep) { \
  int __prev_ofs = ((char *)(&(first->ep##prev))) - ((char *)(first)); \
  int __next_ofs = ((char *)(&(first->ep##next))) - ((char *)(first)); \
  char *__iprev = NULL; \
  char *__iter = (void *)first; \
  while (NULL != __iter) { \
      if (outer == __iter) GPF_T1("L2_DEBUG: unexpected occurrence of outer to the right of first"); \
      __iter = ((char **)(__iter + __next_ofs))[0]; \
    } \
}

#else
#define L2_ASSERT_SOLO(elt, ep)
#define L2_ASSERT_PROPER_ENDS(first, last, ep)
#define L2_ASSERT_CONNECTION(first, last, ep)
#define L2_ASSERT_DISCONNECTION(first, outer, ep)
#endif

#define L2_PUSH(first, last, elt, ep) \
{ \
  L2_ASSERT_SOLO(elt, ep) \
  L2_ASSERT_PROPER_ENDS(first, last, ep) \
  L2_ASSERT_CONNECTION(first, last, ep) \
  L2_ASSERT_DISCONNECTION(first, elt, ep) \
  elt->ep##next = first; \
  if (first) \
    first->ep##prev = elt; \
  elt->ep##prev = NULL; \
  if (!last) last = elt; \
  first = elt; \
}


#define L2_PUSH_LAST(first, last, elt, ep) \
{ \
  L2_ASSERT_SOLO(elt, ep) \
  L2_ASSERT_PROPER_ENDS(first, last, ep) \
  L2_ASSERT_CONNECTION(first, last, ep) \
  L2_ASSERT_DISCONNECTION(first, elt, ep) \
  elt->ep##prev = last; \
  if (last) \
    last->ep##next = elt; \
  elt->ep##next = NULL; \
  if (!first) first = elt; \
  last = elt; \
}

#define L2_DELETE(first, last, elt, ep) \
{ \
  L2_ASSERT_PROPER_ENDS(first, last, ep) \
  L2_ASSERT_CONNECTION(first, elt, ep) \
  L2_ASSERT_CONNECTION(elt, last, ep) \
  if (elt->ep##prev) \
    elt->ep##prev->ep##next = elt->ep##next; \
  if (elt->ep##next) \
    elt->ep##next->ep##prev = elt->ep##prev; \
  if (elt == first) \
    first = elt->ep##next; \
  if (elt == last) \
    last = elt->ep##prev; \
  elt->ep##prev = elt->ep##next = NULL; \
}

#define L2_INSERT(first, last, before, it, ep) \
{ \
  L2_ASSERT_PROPER_ENDS(first, last, ep) \
  L2_ASSERT_CONNECTION(first, before, ep) \
  L2_ASSERT_CONNECTION(before, last, ep) \
  if (before != it->ep##next) \
    { \
      L2_ASSERT_SOLO(it, ep) \
      L2_ASSERT_DISCONNECTION(first, it, ep) \
    } \
  L2_ASSERT_DISCONNECTION(first, it, ep) \
  if (before == first) \
    { \
      L2_PUSH (first, last, it, ep); \
    } \
  else \
    { \
      it->ep##prev = before->ep##prev; \
      it->ep##next = before; \
      before->ep##prev->ep##next = it; \
      before->ep##prev = it; \
    } \
}


#define L2_INSERT_AFTER(first, last, after, it, ep)  \
{  \
  L2_ASSERT_PROPER_ENDS(first, last, ep) \
  if (!after) \
    { \
      L2_ASSERT_SOLO(it, ep) \
      L2_ASSERT_DISCONNECTION(first, it, ep) \
      L2_ASSERT_CONNECTION(first, last, ep) \
      L2_PUSH (first, last, it, ep); \
    } \
  else \
    { \
      if (after != it->ep##prev) \
        { \
          L2_ASSERT_SOLO(it, ep) \
          L2_ASSERT_DISCONNECTION(first, it, ep) \
        } \
      L2_ASSERT_CONNECTION(first, after, ep) \
      L2_ASSERT_CONNECTION(after, last, ep) \
      it->ep##next = after->ep##next;  \
      it->ep##prev = after; \
      after->ep##next = it; \
      if (it->ep##next)  \
	it->ep##next->ep##prev = it; \
      else  \
	last = it; \
    } \
}

#endif



#define RBE_LEN 128
#define RBE_NEXT(rbe, r)  ((r + 1) & (RBE_LEN - 1))


typedef struct rbuf_elt_s
{
  struct rbuf_elt_s *  rbe_next;
  struct rbuf_elt_s *	rbe_prev;
  short	rbe_write;
  short	rbe_read;
  short	rbe_count;
  void * rbe_data[RBE_LEN];
} rbuf_elt_t;


typedef struct rbuf_s rbuf_t;

typedef void (* rbuf_free_t)(caddr_t);
typedef void (*rbuf_add_cb_t) (rbuf_t * rb, void* data);

struct rbuf_s
{
  rbuf_elt_t *rb_first;
  rbuf_elt_t *	rb_last;
  rbuf_elt_t *	rb_rewrite_last;
  rbuf_add_cb_t	rb_add_cb;
  short	rb_rewrite;
  char	rb_is_new_data;
  int		rb_count;
  rbuf_free_t 	rb_free_func;

};

#define DO_RBUF(dtp, item, rbe, inx, rb)  \
{ \
 dtp item; int inx = 0; rbuf_elt_t * rbe;		\
  rbuf_elt_t * __next; \
  for (rbe = (rb)->rb_first; rbe; rbe = __next)	\
    { \
  __next = rbe->rbe_next; __builtin_prefetch (__next);			\
  for (inx = inx < -1 ? -inx - 2 : rbe->rbe_read; inx >= 0 && inx != rbe->rbe_write; inx = (inx >= 0 ? RBE_NEXT (rbe, inx) : inx)) \
    { /* a delete in the loop can set the inx to -1 meaning start at the start of the next rbe or to < -1 meaning start in the next rbe at index -inx + 2.  Latter if delete of item causes rbe to be merged into next and some elts of the merged have akready been processed in the loop, so no elt comes twice */  \
      __builtin_prefetch (rbe->rbe_data[(inx + 2) & (RBE_LEN - 1)]); \
	  if (!(item = (dtp)rbe->rbe_data[inx])) \
	    continue;

#define END_DO_RBUF \
  }}}

void rbuf_add (rbuf_t * rb, void* elt);
void * rbuf_get (rbuf_t * rb);
void * rbuf_first (rbuf_t * rb);
void rbuf_delete (rbuf_t * rb, rbuf_elt_t * rbe, int * inx);
void rbuf_destroy (rbuf_t * rb);
rbuf_t * rbuf_allocate ();
int  rbuf_free_cb (rbuf_t * rb);
void  rbuf_append (rbuf_t * dest, rbuf_t * src);
void rbuf_delete_all (rbuf_t *);
void rbuf_rewrite (rbuf_t * rb);
void rbuf_keep (rbuf_t * rb, void * elt);
void rbuf_rewrite_done (rbuf_t * rb);
void rb_ck_cnt (rbuf_t * rb);

#define RBUF_REQ_MTX(rb, mtx)

#endif
