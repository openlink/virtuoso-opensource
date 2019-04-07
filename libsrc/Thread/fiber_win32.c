/*
 *  fiber_win32.c
 *
 *  $Id$
 *
 *  Fiber Event Loop (Win32 implementation)
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2019 OpenLink Software
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


#ifdef EXPIRIMENTAL

static int _fd_set_or (fd_set * s1, fd_set * s2);
static int _fd_set_intersect (fd_set * s1, fd_set * s2);
static void _fd_set_and (fd_set * s1, fd_set * s2);


int
thread_select (int n, fd_set *rfds, fd_set *wfds, void *event, TVAL timeout)
{
  thread_t *thr = _current_fiber;

  if (rfds)
    thr->thr_rfds = *rfds;
  else
    FD_ZERO (&thr->thr_rfds);

  if (wfds)
    thr->thr_wfds = *wfds;
  else
    FD_ZERO (&thr->thr_wfds);
  thr->thr_nfds = n;

  /* Signalled in _event_loop () */
  if (_fiber_sleep (event, timeout) == -1)
    {
      thr->thr_nfds = 0;
      return 0;
    }

  thr->thr_nfds = 0;
  if (rfds)
    *rfds = thr->thr_rfds;
  if (wfds)
    *wfds = thr->thr_wfds;

  return thr->thr_retcode;
}


void
thread_sleep (TVAL timeout)
{
  _fiber_sleep (NULL, timeout);
  thr_errno = 0;
}


static void
dumpfds (char *lbl, fd_set *p)
{
  u_int i;

  fprintf (stderr, "%s:", lbl);
  for (i = 0; i < p->fd_count; i++)
    fprintf (stderr, " %d", p->fd_array[i]);

  fprintf (stderr, "\n");
}


/*
 *  This is the idle task, that runs at the lowest possible priority.
 *  It's only called when there are no other fibers ready for scheduling.
 */
void
_fiber_event_loop (void)
{
  /* These are all static, to minimize stack usage */
  static fd_set readfds;
  static fd_set writefds;
  static int nreadfds;
  static int nwritefds;
  static int nfds;
  static thread_t *thr, *next;
  static TVAL timeout;
  static struct timeval tv, *ptv;
  static int rc;

  for (;;)
    {
      timeout = timer_queue_update (_timerq,
	  timer_queue_time_elapsed (_timerq));
      if (_thread_num_runnable)
	return;

//fprintf (stderr, "--------- SELECT to=%d --------\n", timeout);
      FD_ZERO (&readfds);
      FD_ZERO (&writefds);

      for (thr = (thread_t *) _waitq.thq_head.thr_next;
	  thr != (thread_t *) &_waitq.thq_head;
	  thr = (thread_t *) thr->thr_hdr.thr_next)
	{
	  if (thr->thr_nfds)
	    {
//fprintf (stderr, "THR %p ", thr); dumpfds ("READ", &thr->thr_rfds);
//fprintf (stderr, "THR %p ", thr); dumpfds ("WRIT", &thr->thr_wfds);
	      nreadfds = _fd_set_or (&readfds, &thr->thr_rfds);
	      nwritefds = _fd_set_or (&writefds, &thr->thr_wfds);
	    }
	}
      nfds = MAX (nreadfds, nwritefds);
//dumpfds ("ALL READ", &readfds);
//dumpfds ("ALL WRIT", &writefds);
//fprintf (stderr, "NFDS=%d\n", nfds);

      if (timeout == 0)
	ptv = NULL;
      else
	{
	  tv.tv_sec = timeout / 1000;
	  tv.tv_usec = (timeout % 1000) * 1000;
	  ptv = &tv;
	}
      if (nfds == 0)
	{
	  Sleep (timeout);
	  timer_queue_update (_timerq, timeout);
	  return;
	}

      rc = select (nfds, &readfds, &writefds, NULL, ptv);
      if (rc == -1)
	{
	  if (errno != EINTR)
	    GPF_T1 ("select() returned -1");
	  continue;
	}
//dumpfds ("SEL READ", &readfds);
//dumpfds ("SEL WRIT", &writefds);
      timer_queue_update (_timerq, timer_queue_time_elapsed (_timerq));

      if (rc > 0)
	{
	  /* Wake up waiting fibers for which an event occurred */
	  for (thr = (thread_t *) _waitq.thq_head.thr_next;
	      thr != (thread_t *) &_waitq.thq_head;
	      thr = next)
	    {
	      next = (thread_t *) thr->thr_hdr.thr_next;
	      if (thr->thr_nfds == 0)
		continue;
	      if (_fd_set_intersect (&thr->thr_rfds, &readfds) ||
		  _fd_set_intersect (&thr->thr_wfds, &writefds))
		{
		  _fd_set_and (&thr->thr_rfds, &readfds);
		  _fd_set_and (&thr->thr_wfds, &writefds);
		  thr->thr_event = NULL;
		  thr->thr_retcode = 1;
		  _fiber_status (thr, RUNNABLE);
		}
	    }
	}
//fprintf (stderr, "LEAVE SELECT\n");
      break;
    }
}


static int
_fd_set_or (fd_set * s1, fd_set * s2)
{
  u_int i;

  for (i = 0; i < s2->fd_count; i++)
    {
      FD_SET (s2->fd_array[i], s1);
    }

  return s1->fd_count;
}


static int
_fd_set_intersect (fd_set * s1, fd_set * s2)
{
  u_int i;

  for (i = 0; i < s2->fd_count; i++)
    if (FD_ISSET (s2->fd_array[i], s1))
      return 1;

  return 0;
}


static void
_fd_set_and (fd_set * s1, fd_set * s2)
{
  fd_set ret;
  u_int i;

  FD_ZERO (&ret);
  for (i = 0; i < s1->fd_count; i++)
    if (FD_ISSET (s1->fd_array[i], s2))
      FD_SET (s1->fd_array[i], &ret);
  *s1 = ret;
}

#endif /* EXPIRIMENTAL */
