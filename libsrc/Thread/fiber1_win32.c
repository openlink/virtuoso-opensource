/*
 *  fiber1_win32.c
 *
 *  $Id$
 *
 *  Win32 Native implementation for fibers
 *  Use this instead of fiber[12]_generic.c
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2012 OpenLink Software
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


typedef VOID (WINAPI *PFIBER_START_ROUTINE)(LPVOID lpFiberParameter);
typedef PFIBER_START_ROUTINE LPFIBER_START_ROUTINE;

WINBASEAPI LPVOID WINAPI CreateFiber(
    DWORD dwStackSize,
    LPFIBER_START_ROUTINE lpStartAddress,
    LPVOID lpParameter);

WINBASEAPI VOID WINAPI DeleteFiber (LPVOID lpFiber);

WINBASEAPI LPVOID WINAPI ConvertThreadToFiber (LPVOID lpParameter);

WINBASEAPI VOID WINAPI SwitchToFiber (LPVOID lpFiber);

WINBASEAPI BOOL WINAPI SwitchToThread (VOID);


unsigned long context_switches;

static void WINAPI
_fiber_start (void *param)
{
  auto unsigned int marker = THREAD_STACK_MARKER;
  thread_t *thr = (thread_t *) param;
  int rc;

  thr->thr_stack_marker = &marker;

  /* Store the context so we can easily restart a dead fiber */
  setjmp (thr->thr_init_context);

  rc = (*thr->thr_initial_function) (thr->thr_initial_argument);

  /* Fiber died, put it on the dead queue */
  thread_exit (rc);

  /* We should NEVER come here */
  GPF_T;
}


void
_fiber_switch (thread_t *new_thread)
{
  context_switches++;

  _current_fiber = new_thread;
  SwitchToFiber (new_thread->thr_handle);
}


void
_fiber_for_thread (thread_t *self, unsigned long stack_size)
{
  static int init_done;

  self->thr_stack_size = stack_size;

  if (init_done == 0)
    {
      init_done = 1;
      self->thr_handle = ConvertThreadToFiber (NULL);
    }
  else
    self->thr_handle = CreateFiber (stack_size, _fiber_start, self);

  assert (self->thr_handle != NULL);
}
