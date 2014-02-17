/*
 *  fnqual.c
 *
 *  $Id$
 *
 *  Filename qualification
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2014 OpenLink Software
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

extern char *getcwd ();


/*
 *  Return a fully qualified filename, or NULL on error.
 *  The returned value (when != NULL) must be free()d after use
 */
char *
fnqualify (char *name)
{
  char pathBuffer[1024];
  struct stat sb;
  char currentDir[1024];
  int changeBack;
  char *slash;
  char *endPtr;

  if (stat (name, &sb) == -1)
    return NULL;

#ifdef DOSFS
  fntodos (name);
#endif
  if ((sb.st_mode & S_IFMT) == S_IFDIR)
    {
      if (getcwd (currentDir, sizeof (currentDir)) == NULL)
	return NULL;
      if (chdir (name) == -1)
	return NULL;
      if (getcwd (pathBuffer, sizeof (pathBuffer)) == NULL)
	return NULL;
      chdir (currentDir);
      return strdup (pathBuffer);
    }

  if ((slash = strrchr (name, SLASH)) == NULL)
    {
      slash = name;
      changeBack = 0;
    }
  else
    {
      slash++;
      memcpy (pathBuffer, name, (size_t) (slash - name));
      strcpy (&pathBuffer[(size_t) (slash - name)], ".");
      if (getcwd (currentDir, sizeof (currentDir)) == NULL)
	return NULL;
      if (chdir (pathBuffer) == -1)
	return NULL;
      changeBack = 1;
    }
  if (getcwd (pathBuffer, sizeof (pathBuffer)) == NULL)
    return NULL;
  if (changeBack)
    chdir (currentDir);
  endPtr = &pathBuffer[strlen (pathBuffer) - 1];
  if (*endPtr != SLASH)
    *++endPtr = SLASH;
  strcpy (++endPtr, slash);
  return strdup (pathBuffer);
}

#ifdef TEST

int
main (int argc, char **argv)
{
  while (--argc)
    {
      argv++;
      printf ("%s -> %s\n", *argv, fnqualify (*argv));
    }
  return 0;
}

#endif
