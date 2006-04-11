/*
 *  utalloc.c
 *
 *  $Id$
 *
 *  Save memory management
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2006 OpenLink Software
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

#include "libutil.h"


void terminate (int);


#undef s_alloc

void *
s_alloc (size_t s, size_t n)
{
  void *core;


  /*
   * Some systems return a NULL pointer if one of the arguments is 0
   * but we like to get a memory block anyway and promise to 
   * free it afterwards.
   */
  if (n == 0 || s == 0)
    n = s = 1;

  if ((core = calloc (s, n)) == NULL)
    {
      log (L_ERR, "s_alloc: out of memory");
      terminate (1);
    }
  return core;
}


void *
s_realloc (void *s, size_t n)
{
  void *core;

  if ((core = realloc (s, n)) == NULL)
    {
      log (L_ERR, "s_realloc: out of memory");
      terminate (1);
    }
  return core;
}


#if 1
#undef s_strdup 
char *
s_strdup (const char *s)
{
  char *str;

  str = (char *) s_alloc (strlen (s) + 1, 1);
  strcpy (str, s);
  return str;
}
#endif
