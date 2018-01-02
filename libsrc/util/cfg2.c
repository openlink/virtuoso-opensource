/*
 *  cfg2.c
 *
 *  $Id$
 *
 *  Configuration Management
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


int
cfg_getstring (PCONFIG pconfig, char *section, char *id, char **valptr)
{
  if (cfg_find (pconfig, section, id))
    return -1;

  *valptr = pconfig->value;
  return 0;
}


int
cfg_getlong (PCONFIG pconfig, char *section, char *id, int32 *valptr)
{
  int32 value;
  int negative;
  char *np;

  if (cfg_getstring (pconfig, section, id, &np))
    return -1;

  while (isspace (*np))
    np++;
  negative = 0;
  value = 0;
  if (*np == '-')
    {
      negative = 1;
      np++;
    }
  else if (*np == '+')
    np++;
  if (np[0] == '0' && toupper (np[1]) == 'X')
    {
      np += 2;
      while (*np && isxdigit (*np))
	{
	  value *= 16;
	  if (isdigit (*np))
	    value += *np++ - '0';
	  else
	    value += toupper (*np++) - 'A' + 10;
	}
    }
  else
    while (*np && isdigit (*np))
      value = 10 * value + *np++ - '0';

  *valptr = negative ? -value : value;

  return 0;
}


int
cfg_getshort (PCONFIG pconfig, char *section, char *id, short *valptr)
{
  int32 value;

  if (cfg_getlong (pconfig, section, id, &value))
    return -1;

  *valptr = (short) value;
  return 0;
}
