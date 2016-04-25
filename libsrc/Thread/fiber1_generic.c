/*
 *  fiber1_generic.c
 *
 *  $Id$
 *
 *  _fiber_boot and _fiber_switch
 *  Implementations for simulated threads
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2016 OpenLink Software
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


unsigned long context_switches;


/*
 *  These functions are in a separate file because we do not want the C compiler
 *  to optimize the calling of them away in any way. The compiler will save
 *  additional registers before calling the context switch, so our code
 *  won't crash...
 */

/*
 *  Every new fiber starts running this function
 */
void
_fiber_boot (thread_t * volatile thr)
{
  auto unsigned int marker = THREAD_STACK_MARKER;
  int rc;

  thr->thr_stack_marker = &marker;

  /*
   *  Initially we are called from _fiber_for_thread which does something
   *  like alloca right after we return
   *  Remember our context so the fiber can continue with the right stack
   */
  if (setjmp (thr->thr_context) == 0)
    return;

  /* When we get here, the entire stack is garbage. carefully reinitialize */

  /* thr->thr_stack_marker is reinitialized elsewhere */
  thr = current_thread;

  thr->thr_stack_base = (void*) &thr;
  /* Store the context so we can easily restart a dead fiber */
  setjmp (thr->thr_init_context);

  rc = (*thr->thr_initial_function) (thr->thr_initial_argument);

  /* Fiber died, put it on the dead queue */
  thread_exit (rc);

  /* We should NEVER come here */
  GPF_T;
}


/*
 *  The actual context switch
 */
void
_fiber_switch (thread_t *new_thread)
{
  context_switches++;

  assert (*new_thread->thr_stack_marker == THREAD_STACK_MARKER);

  if (setjmp (current_thread->thr_context) == 0)
    {
      _current_fiber = new_thread;
      longjmp (new_thread->thr_context, 1);
    }
}
