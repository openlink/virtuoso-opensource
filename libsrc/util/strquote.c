/*
 *  strquote.c
 *
 *  $Id$
 *
 *  strquote - strdup's a string, adding quotes.
 *  strunquote - strdup's a string, stripping off quotes.
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2017 OpenLink Software
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

#include <libutil.h>

#define SQL_NTS -3

char *
strquote (char *s, ssize_t size, int quoteChr)
{
  char *pszOut;

  if (s == NULL)
    {
      s = "";
      size = SQL_NTS;
    }

  if (quoteChr == ' ')
    return strdup (s);

  if (size == SQL_NTS)
    size = strlen (s);

  if ((pszOut = (char *) malloc (size + 3)) != NULL)
    {
      memcpy (&pszOut[1], s, size);
      pszOut[0] = quoteChr;
      pszOut[++size] = '\0';

      /*
       *  Add the quote character to the right end of the string
       */
      size = strlen (pszOut);
      pszOut[size] = quoteChr;
      pszOut[++size] = '\0';
    }

  return pszOut;
}


char *
strunquote (char *s, ssize_t size, int quoteChr)
{
  char *pszOut;

  if (s == NULL)
    pszOut = strdup ("");
  else
    {
      if (size == SQL_NTS)
        size = (short) strlen (s);

      if (quoteChr != ' ' && size > 1 && s[0] == quoteChr &&
          s[size - 1] == quoteChr)
        {
          pszOut = strdup ((char *) &s[1]);
          pszOut[size - 2] = '\0';
        }
      else
        pszOut = strdup (s);
    }

  return pszOut;
}
