/*
 *  csllkup.c
 *
 *  $Id$
 *
 *  Find an entry in a comma separated list
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

#include "libutil.h"


/*
 *  Returns index of string entry in comma seperated list
 *  Return 0 if not found, or 1 .. cslnumentries
 */
int
csllookup (const char *list, const char *expr)
{
  size_t size;
  int idx;

  if (!expr || !list)
    return 0;

  size = strlen (expr);
  for (idx = 1; *list; list++, idx++)
    {
      list = ltrim (list);
      if (!strncmp (list, expr, size) &&
	  (list[size] == ',' || list[size] == 0))
	return idx;
      if ((list = strchr (list, ',')) == NULL)
	break;
    }

  return 0;
}
