/*
 *  timer_queue.c
 *
 *  $Id$
 *
 *  Timers and Timer Queues
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
 *  
*/

#include "Dk.h"


#ifdef EXPIRIMENTAL

#define TIMERQ_LOCK(X)		mutex_enter (X->tmq_lock);
#define TIMERQ_UNLOCK(X)	mutex_leave (X->tmq_lock);



/*
 *  Call this first to initialize the timer list
 */
timer_queue_t *
timer_queue_allocate (void)
{
  NEW_VARZ (timer_queue_t, tmq);
  LISTINIT (&tmq->tmq_active, tmr_next, tmr_prev);
  tmq->tmq_lock = mutex_allocate ();
  return tmq;
}


void
timer_queue_free (timer_queue_t *self)
{
  timer_t *p, *q;

  TIMERQ_LOCK (self);
  for (p = self->tmq_active.tmr_next; p != &self->tmq_active; p = q)
    {
      q = p->tmr_next;
      timer_deactivate (p);
    }
  TIMERQ_UNLOCK (self);
  mutex_free (self->tmq_lock);
  dk_free (self, sizeof (timer_queue_t));
}


TVAL
timer_queue_time_elapsed (timer_queue_t *self)
{
#if defined (WIN32)
  long clock, ticks;

  clock = GetTickCount ();
  ticks = clock - self->tmq_measure.tv_sec;
  self->tmq_measure.tv_sec = clock;
  if (ticks < 0)
    ticks = -ticks;
  return ticks;

#elif 1
  static struct timeval now;
  static struct timeval ret;

  if (self->tmq_measure.tv_sec == 0)
    {
      gettimeofday (&self->tmq_measure, NULL);
      return 0;
    }
  gettimeofday (&now, NULL);
  if (now.tv_usec >= self->tmq_measure.tv_usec)
    {
      ret.tv_sec = now.tv_sec - self->tmq_measure.tv_sec;
      ret.tv_usec = now.tv_usec - self->tmq_measure.tv_usec;
    }
  else
    {
      ret.tv_sec = now.tv_sec - self->tmq_measure.tv_sec - 1;
      ret.tv_usec = now.tv_usec + 1000000 - self->tmq_measure.tv_usec;
    }
  self->tmq_measure = now;
  return ret.tv_sec * 1000 + (ret.tv_usec + 500) / 1000;

#else
  static time_t prev, now;
  time_t ret;

  if (prev == 0)
    {
      time (&prev);
      self->tmq_measure.tv_sec = prev;
      return 0;
    }
  time (&now);
  ret = now - self->tmq_measure.tv_sec;
  self->tmq_measure.tv_sec = now;
  return ret * 1000;
#endif
}


/*
 *  Call this function periodically.
 *
 *  The argument elapsed tells how many msecs have elapsed since
 *  the last call (caller should keep track)
 *
 *  The return value is the next delay the caller should wait.
 *
 *  All expired (and late) timers are called out.
 */
TVAL
timer_queue_update (timer_queue_t *self, TVAL elapsed)
{
  timer_t q2;
  timer_t *p;
  timer_t *q;
  TVAL abst;
  TVAL zero;

  q2.tmr_next = q2.tmr_prev = &q2;
  TV_ZERO (zero);

  TIMERQ_LOCK (self);
  if (self->tmq_active.tmr_next == &self->tmq_active)
    {
      TIMERQ_UNLOCK (self);
      return zero;
    }

  TV_XSUBY (self->tmq_active.tmr_next->tmr_remain,
      self->tmq_active.tmr_next->tmr_remain, elapsed);

again:
  TV_ZERO (abst);
  for (p = self->tmq_active.tmr_next; p != &self->tmq_active; p = q)
    {
      TV_XADDY (abst, abst, p->tmr_remain);
      if (TV_XLTY (zero, abst))
        break;
      q = p->tmr_next;
      TV_XSUBY (abst, abst, p->tmr_remain);

      /*
       * This is actually timer_deactivate(p) inlined, because
       *  we already hold the lock
       */
      if (q != &self->tmq_active)
	{
	  TV_XADDY (q->tmr_remain, q->tmr_remain, p->tmr_remain);
	}
      LISTDELETE (p, tmr_next, tmr_prev);

      p->tmr_calling = 1;
      (*p->tmr_callout) (p->tmr_call_arg);
      p->tmr_calling = 0;

      if (TV_ISZERO (p->tmr_interval))
        timer_unref (p);
      else
        {
	  TV_XADDY (p->tmr_remain, p->tmr_remain, p->tmr_interval);
	  LISTPUTAFTER (q2.tmr_next, p, tmr_next, tmr_prev);
	}
    }

  if (q2.tmr_next != &q2)
    {
      for (p = q2.tmr_next; p != &q2; p = q)
	{
	  q = p->tmr_next;
	  LISTDELETE (p, tmr_next, tmr_prev);
	  timer_activate (p);
	  timer_unref (p);
	}
      goto again;
    }

  abst = self->tmq_active.tmr_next->tmr_remain;
  TIMERQ_UNLOCK (self);

  return abst;
}


/*
 *  Allocates and activates a new timer.
 *
 *  Timers use reference counting, which means that the timer is freed when
 *  the reference counter reaches zero. The timer functions increment the
 *  reference when it's on the callout list.
 *
 *  When the msecs delay == TV_INFINITE, the timer will never be activated.
 *  If interval == 0, it's a one shot timer (unreferenced after callout)
 */
timer_t *
timer_queue_new_timer (
    timer_queue_t *self,
    TVAL msecs,
    TVAL interval,
    timer_callback_t callout,
    void *arg)
{
  NEW_VARZ (timer_t, tmr);

  tmr->tmr_queue = self;
  tmr->tmr_callout = callout;
  tmr->tmr_call_arg = arg;

  timer_ref (tmr);
  timer_set (tmr, msecs, interval);

  return tmr;
}


void
timer_free (timer_t *self)
{
  timer_deactivate (self);
  dk_free (self, sizeof (timer_t));
}


timer_t *
timer_ref (timer_t *self)
{
  self->tmr_ref++;
  return self;
}


void
timer_unref (timer_t *self)
{
  if (self->tmr_ref == 0 || --self->tmr_ref == 0)
    {
      assert (!timer_isactive (self));
      timer_free (self);
    }
}


void
timer_set (timer_t *self, TVAL msecs, TVAL interval)
{
  self->tmr_remain = msecs;
  self->tmr_interval = interval;
  timer_activate (self);
}


int
timer_isactive (timer_t *self)
{
  return self->tmr_next != NULL;
}


void
timer_activate (timer_t *self)
{
  timer_queue_t *tmq;
  timer_t *p, *q;

  timer_ref (self);
  timer_deactivate (self);

  if (TV_ISINF (self->tmr_remain))
    {
      timer_unref (self);
      return;
    }

  tmq = self->tmr_queue;
  if (!self->tmr_calling)
    TIMERQ_LOCK (tmq);
  p = &tmq->tmq_active;
  for (q = p->tmr_next; q != &tmq->tmq_active; q = q->tmr_next)
    {
      if (TV_XLTY (self->tmr_remain, q->tmr_remain))
	{
	  TV_XSUBY (q->tmr_remain, q->tmr_remain, self->tmr_remain);
	  break;
	}
      TV_XSUBY (self->tmr_remain, self->tmr_remain, q->tmr_remain);
      p = q;
    }

  self->tmr_next = self->tmr_prev = NULL;
  LISTPUTAFTER (p, self, tmr_next, tmr_prev);
  if (!self->tmr_calling)
    TIMERQ_UNLOCK (tmq);
}


void
timer_deactivate (timer_t *self)
{
  if (timer_isactive (self))
    {
      timer_queue_t *tmq = self->tmr_queue;
      TIMERQ_LOCK (tmq);
      if (self->tmr_next != &tmq->tmq_active)
	{
	  TV_XADDY (self->tmr_next->tmr_remain,
	      self->tmr_next->tmr_remain, self->tmr_remain);
	}
      LISTDELETE (self, tmr_next, tmr_prev);
      TIMERQ_UNLOCK (tmq);
      timer_unref (self);
    }
}

#endif /* EXPIRIMENTAL */
