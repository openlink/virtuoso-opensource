/*
 *  fiber2_generic.c
 *
 *  $Id$
 *
 *  _fiber_for_thread and spinlocks
 *  Implementation for simulated threads
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
 *  
*/

#include "thread_int.h"


static jmp_buf _stack_jmp;
static jmp_buf _cont_jmp;
static thread_t *_boot;
static int _stack_direction;


static void
stack_helper (char *addr)
{
  /* # bytes overhead per call - probably too optimistic */
#define STK_FRAME_LEN           16
  auto char here[4096];
  auto ptrlong sz;

  if (addr == NULL)
    stack_helper (here);

  if (_stack_direction == -1)
    sz = addr - here;
  else
    sz = here - addr;
  assert (sz > 0);
  sz += STK_FRAME_LEN + sizeof (here) + sizeof (sz);

  if ((unsigned long) sz < _boot->thr_stack_size)
    stack_helper (addr);

  *_boot->thr_stack_marker = THREAD_STACK_MARKER;

  if (setjmp (_cont_jmp) == 0)
    longjmp (_stack_jmp, 1);

  _fiber_boot (_boot);

  stack_helper (here);
}


static int
find_stack_direction (char *addr)
{
  auto char here;

  if (addr == NULL)
    return find_stack_direction (&here);

  return (&here > addr) ? 1 : -1;
}


/*
 *  Associate a fiber with a thread structure
 */
void
_fiber_for_thread (thread_t *self, unsigned long stack_size)
{
  self->thr_stack_size = stack_size;

  /*
   * If this is the first time, it's the main thread converting
   * itself into a fiber
   */
  if (_boot == NULL)
    {
      _stack_direction = find_stack_direction (NULL);
      _boot = self;
      if (setjmp (_stack_jmp) == 0)
	stack_helper (NULL);
      return;
    }

  _boot = self;
  if (setjmp (_stack_jmp) == 0)
    longjmp (_cont_jmp, 1);
}
