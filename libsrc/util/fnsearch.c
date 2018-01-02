/*
 *  fnsearch.c
 *
 *  $Id$
 *
 *  Search a file in a search path
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

#include "libutil.h"

#ifdef DOSFS
#define PATHSEP		';'
#define SLASH		'\\'
#else
#define PATHSEP		':'
#define SLASH		'/'
#endif


char *
fnsearch (const char *filename, const char *path)
{
  static char namebuf[MAXPATHLEN];
  const char *cp;
  char *np;

  if (path == NULL)
    return NULL;
  np = namebuf;
  cp = path;
  while (1)
    {
      if (*cp == PATHSEP || *cp == '\0')
	{
	  *np++ = SLASH;
	  strcpy (np, filename);
	  if (access (namebuf, 0) == 0)
	    return namebuf;
	  if (*cp++ == '\0')
	    return NULL;
	  np = namebuf;
	}
      else
	*np++ = *cp++;
    }
}
