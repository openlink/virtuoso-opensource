/*
 *  strcpyin.c
 *
 *  $Id$
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

#include "libutil.h"

#define SQL_NTS -3


int
StrCopyIn (char **poutStr, char *inStr, ssize_t size)
{
  char *outStr;

  if (inStr == NULL)
    inStr = "";

  if (size == SQL_NTS)
    *poutStr = strdup (inStr);
  else
    {
      if ((outStr = (char *) malloc (size + 1)) != NULL)
        {
          memcpy (outStr, inStr, size);
          outStr[size] = '\0';
        }
      *poutStr = outStr;
    }

  return 0;
}

/*
 * Strips off quotes from a quoted string in the course of copying
 */
int
StrCopyInUQ (char **poutStr, char *inStr, ssize_t size)
{
  size_t cbLen = size; 

  if (inStr != NULL)
    {
      if (size == SQL_NTS)
        cbLen = strlen (inStr);
    
      if (cbLen >= 2 && (inStr[0] == '\'' || inStr[0] == '"') &&
  	  inStr[cbLen - 1] == inStr[0])
        {
	  cbLen -= 2;
	  return StrCopyIn (poutStr, &inStr[1], cbLen);
        }
    }

  return StrCopyIn (poutStr, inStr, size);
}
