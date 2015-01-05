/*
 *  cslentry.c
 *
 *  $Id$
 *
 *  Return an entry from a comma seperated list
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

#include "libutil.h"


char *
cslentry (const char *list, int idx)
{
  char *start;
  size_t length;

  if (!list || !list[0] || !idx)
    return NULL;

  for (--idx; idx && *list; idx--)
    {
      if ((list = strchr (list, ',')) == NULL)
	return NULL;
      list++;
    }
  start = (char *) ltrim (list);
  if ((list = strchr (start, ',')) == NULL)
    length = strlen (start);
  else
    length = (u_int) (list - start);

  if ((start = strdup (start)) != NULL)
    {
      start[length] = 0;
      rtrim (start);
    }

  return start;
}
