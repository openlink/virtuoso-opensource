/*
 *  fiber_unix.c
 *
 *  $Id$
 *
 *  Fiber Event Loop (Unix implementation)
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

#include "Dk.h"


#ifdef EXPIRIMENTAL

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

  /* Signalled in _fiber_event_loop () */
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


static int
_fd_set_or (fd_set * s1, fd_set * s2)
{
  uint32 *p1 = (uint32 *) s1;
  uint32 *p2 = (uint32 *) s2;
  uint32 n;
  int res;

  res = 0;
  for (n = 0; n < sizeof (fd_set) / sizeof (uint32); n++)
    if (p1[n] |= p2[n])
      res = (n + 1) * 32;

  return res;
}


static int
_fd_set_intersect (fd_set * s1, fd_set * s2)
{
  uint32 *p1 = (uint32 *) s1;
  uint32 *p2 = (uint32 *) s2;
  uint32 n;

  for (n = 0; n < sizeof (fd_set) / sizeof (uint32); n++)
    if (p1[n] & p2[n])
      return 1;

  return 0;
}


static int
_fd_set_and (fd_set * s1, fd_set * s2)
{
  uint32 *p1 = (uint32 *) s1;
  uint32 *p2 = (uint32 *) s2;
  uint32 n;
  int ok;

  ok = 0;
  for (n = 0; n < sizeof (fd_set) / sizeof (uint32); n++)
    if ((p1[n] &= p2[n]) != 0)
      ok = 1;

  return ok;
}


#ifdef DEBUG
static void
dumpfds (char *lbl, int n, fd_set *p)
{
  int i;

  fprintf (stderr, "%s:", lbl);
  for (i = 0; i < n; i++)
    {
      if (FD_ISSET (i, p))
	fprintf (stderr, " %d", i);
    }
  fprintf (stderr, "\n");
}
#endif


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

      FD_ZERO (&readfds);
      FD_ZERO (&writefds);

      for (thr = (thread_t *) _waitq.thq_head.thr_next;
	  thr != (thread_t *) &_waitq.thq_head;
	  thr = (thread_t *) thr->thr_hdr.thr_next)
	{
	  if (thr->thr_nfds)
	    {
	      nreadfds = _fd_set_or (&readfds, &thr->thr_rfds);
	      nwritefds = _fd_set_or (&writefds, &thr->thr_wfds);
	    }
	}
      nfds = MAX (nreadfds, nwritefds);

      if (timeout == 0)
	ptv = NULL;
      else
	{
	  tv.tv_sec = timeout / 1000;
	  tv.tv_usec = (timeout % 1000) * 1000;
	  ptv = &tv;
	}
      rc = select (nfds, &readfds, &writefds, NULL, ptv);
      if (rc == -1)
	{
	  if (errno != EINTR)
	    GPF_T1 ("select() returned -1");
	  continue;
	}
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
      break;
    }
}
#endif
