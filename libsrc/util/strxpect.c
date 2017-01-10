/*
 *  strxpect.c
 *
 *  $Id$
 *
 *  Performs a keyword compare
 *  This functions tests if the second string (which is usually longer than
 *  the first) begins with the keyword in the first string.
 *  If so, it returns a pointer to the first non-white character in the second
 *  string; otherwise a NULL is returned.
 *
 *  Example
 *	keyword		source			returns
 *      -----------------------------------------------
 *	"SELECT"	"SELECT\tA,..."		"A,..."
 *	"SELECT"	"SELECTALL ..."		NULL
 *	"SELECTALL"	"SELECT "		NULL
 *	"SELECT"	"SELECT"		""
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

#include "libutil.h"


char *
strexpect (char *keyword, char *source)
{
  while (isspace (*source))
    source++;

  while (*keyword && toupper (*keyword) == toupper (*source))
    {
      keyword++;
      source++;
    }

  if (*keyword)
    return NULL;

  if (*source == '\0')
    return source;
  
  if (isspace (*source))
    {
      while (isspace (*source))
	source++;
      return source;
    }

  return NULL;
}
