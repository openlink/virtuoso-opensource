/*
 *  $Id$
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

#ifndef _CLQ_H
#define _CLQ_H
#define CL_RBUF

#ifdef CL_RBUF

#define cl_queue_t rbuf_t

#define clq_get(q) rbuf_get (q)
#define clq_add(q, i) rbuf_add (q, i)
#define clq_count(q)  (q)->rb_count

#define DO_CLQ(dtp, it, rbe, inx, clq) DO_RBUF (dtp, it, rbe, inx, clq)
#define END_DO_CLQ END_DO_RBUF

#define clq_next(q, rbe, inx)
#define clq_delete(q, rbe, inx) rbuf_delete (q, rbe, &inx)
#define clq_is_empty(q) (0 == (q)->rb_count)
#define clq_first(q) rbuf_first(q)

#define CLQ_REQ_MTX(clq, mtx) RBUF_REQ_MTX (clq, mtx)

#else


#define cl_queue_t basket_t

#define clq_get(q) basket_get (q)
#define clq_add(q, i) basket_add (q, i)
#define clq_count(q) (q)->bsk_count

#define DO_CLQ(dtp, it, rbe, inx, clq)  \
{ \
  basket_t * rbe = (clq)->bsk_next; \
  while (rbe && rbe != clq) \
    { dtp it = (dtp)elt->bsk_data.ptrval; \
      __builtin_prefetch (elt->bsk_next->bsk_data.ptrval);



#define END_DO_CLQ }}

#define clq_next(q, rbe, inx) rbe = rbe->bsk_next
#define clq_delete(q, rbe, inx) basket_delete ((q), &rbe)
#define clq_is_empty(q) basket_is_empty(q)
#define clq_first(q) basket_first(q)

#define CLQ_REQ_MTX(clq, mtx) BSK_REQ_MTX (clq, mtx)
#endif

#endif /* _CLQ_H */
