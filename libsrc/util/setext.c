/*
 *  setext.c
 *
 *  $Id$
 *
 *  usage:
 *	char *setext (char *path, char *ext, int mode);
 *
 *	path	- filename
 *	ext	- extension, without '.'
 *	mode	- one of
 *			EXT_SET		force the extension to be set
 *			EXT_REMOVE	remove the extension (ext ignored)
 *			EXT_ADDIFNONE	add extension if omitted
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

#include "libutil.h"

#ifdef DOSFS
#define SLASH	'\\'
#else
#define SLASH	'/'
#endif


char *
setext (const char *path, const char *ext, int mode)
{
  static char name[MAXPATHLEN];
  char *slash;
  char *dot;

  strcpy (name, path);

#ifdef VMS
  if ((slash = strrchr (name, ']')) == NULL)
    slash = name;
  if ((dot = strrchr (slash, ';')) != NULL)
    *dot = '\0';
#else
  if ((slash = strrchr (name, SLASH)) == NULL)
    slash = name;
#endif

  if ((dot = strrchr (slash, '.')) != NULL
      && dot > slash && dot[-1] != SLASH		/* Test for .xxxx */
    )
    {
      if (mode != 2)
	*dot = '\0';
    }
  else
    dot = NULL;

  if ((mode == 2 && dot == NULL) || mode == 1)
    strcat (strcat (name, "."), ext);

  return name;
}
