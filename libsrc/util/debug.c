/*
 *  debug.c
 *
 *  $Id$
 *
 *  Code for debugging
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

#include <stdio.h>


/*
 *  Produces memory dump a la DEBUG.EXE
 *  Sometimes handy for packet tracing
 */
void
_debug_dump_data (FILE *fd, char *where, void *memory, size_t length)
{
  unsigned char *address;
  size_t offset;
  int display;
  int i;

  address = (unsigned char *) memory;
  offset = 0;

  if (where)
    fprintf (fd, "%s: \n", where);
  while (length)
    {
      fprintf (fd, "%04X:", (unsigned int) offset);
      display = length > 16 ? 16 : length;
      for (i = 0; i < 16; i++)
        {
	  if (i < display)
            fprintf (fd, " %02X", address[i]);
	  else
	    fprintf (fd, "   ");
	}
      fprintf (fd, " |");
      for (i = 0; i < display; i++)
        {
	  if (address[i] >= ' ' && address[i] < 128)
	    fputc (address[i], fd);
	  else
	    fputc (' ', fd);
	}
      fputc ('\n', fd);
      address += display;
      offset += display;
      length -= display;
    }
}
