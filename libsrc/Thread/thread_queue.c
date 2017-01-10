/*
 *  threadqueue.c
 *
 *  $Id$
 *
 *  Thread Queues
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
 *  
*/

#include "thread_int.h"


DK_INLINE void
thread_queue_init (thread_queue_t *thq)
{
  LISTINIT (&thq->thq_head, thr_next, thr_prev);
  thq->thq_count = 0;
}


/*
 *  Add a thread to the end of a queue
 */
DK_INLINE void
thread_queue_to (thread_queue_t *thq, thread_t *thr)
{
  thq->thq_count++;
  LISTPUTBEFORE (&thq->thq_head, &thr->thr_hdr, thr_next, thr_prev);
}


/*
 *  Remove a thread from a queue
 */
DK_INLINE thread_t *
thread_queue_remove (thread_queue_t *thq, thread_t *thr)
{
  thq->thq_count--;
  LISTDELETE (&thr->thr_hdr, thr_next, thr_prev);
  return thr;
}


/*
 *  Remove a thread from the head of a queue
 */
DK_INLINE thread_t *
thread_queue_from (thread_queue_t *thq)
{
  if (thq->thq_count == 0)
    return NULL;

  return thread_queue_remove (thq, (thread_t *) thq->thq_head.thr_next);
}
