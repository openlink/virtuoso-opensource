/*
 *  $Id$
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
 */

#include <stdio.h>
#include <stdlib.h>
#include <malloc.h>


void *
dk_alloc (size_t c)
{
  return malloc (c);
}


int
dk_free (void *ptr, size_t sz)
{
  free (ptr);
  return 0;
}


int
mutex_enter (void *mtx)
{
  return 0;
}


void
mutex_leave (void *mtx)
{
}


void
mutex_free (void *mtx)
{
}


void *
mutex_allocate (void)
{
  return (void *) 1;
}
