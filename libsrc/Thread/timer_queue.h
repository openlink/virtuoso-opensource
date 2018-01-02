/*
 *  timer_queue.h
 *
 *  $Id$
 *
 *  Timers and Timer Queues
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2018 OpenLink Software
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

#ifndef _DKTIMERS_H
#define _DKTIMERS_H

#define timer_t	opl_timer_t

typedef struct timer_s timer_t;
typedef struct timer_queue_s timer_queue_t;

typedef void (*timer_callback_t) (void *arg);

typedef struct timeval timeval_t;

struct timer_s
  {
    timer_t *		tmr_next;	/* chain for activated timers */
    timer_t *		tmr_prev;	/* chain for activated timers */
    timer_queue_t *	tmr_queue;	/* owner */
    int			tmr_ref;	/* reference counter */
    int32		tmr_remain;	/* remaining time, if activated */
    TVAL		tmr_interval;	/* interval time for autorepeat */
    int			tmr_calling;	/* to avoid recursive locks */
    timer_callback_t	tmr_callout;	/* function to call when fired */
    void *		tmr_call_arg;	/* argument to tmr_callout */
  };

struct timer_queue_s
  {
    dk_mutex_t *	tmq_lock;
    timer_t		tmq_active;
    timeval_t		tmq_measure;
  };

/* Dktimers.c */
timer_queue_t *timer_queue_allocate (void);
void timer_queue_free (timer_queue_t *self);
TVAL timer_queue_time_elapsed (timer_queue_t *self);
TVAL timer_queue_update (timer_queue_t *self, TVAL elapsed);
timer_t *timer_queue_new_timer (timer_queue_t *self, TVAL msecs, TVAL interval, timer_callback_t callout, void *arg);
void timer_free (timer_t *self);
timer_t *timer_ref (timer_t *self);
void timer_unref (timer_t *self);
void timer_set (timer_t *self, TVAL msecs, TVAL interval);
int timer_isactive (timer_t *self);
void timer_activate (timer_t *self);
void timer_deactivate (timer_t *self);

#endif
