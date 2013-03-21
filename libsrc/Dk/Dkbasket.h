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
 *  Copyright (C) 1998-2013 OpenLink Software
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

#if 0
#define DO_DELETE(type, var, start)  \
	{ \
	  type var = start; \
	  type *prev = &start; \
	  while (var) \
	    {

#define REMOVE_THIS(var, next) \
	      *prev = next; \
	      break;

#define END_DO_DELETE(var, next) \
	      prev = &next; \
	      var = next; \
	    } \
	}

#define BASKET_PEEK(b) ((b)->first_token ? (b)->first_token->data : NULL)
#endif


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

#endif
