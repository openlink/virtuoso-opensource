/*
 *  ntapp.c
 *
 *  $Id$
 *
 *  NT Application specific code
 *  This function is a stub, if none is defined in the application
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


#if defined (WIN32)
int progmanLaunched;


void
EndNTApplication (void)
{
  if (progmanLaunched)
    {
      fprintf (stderr, "\nPress RETURN to exit %s", MYNAME);
      getchar ();
    }

  FreeConsole ();
}


/*
 *  Determines if the program was launched from the Program Manager
 */
void
StartNTApplication (void)
{
  CONSOLE_SCREEN_BUFFER_INFO csbi;
  HANDLE hStdOut;

  hStdOut = GetStdHandle (STD_OUTPUT_HANDLE);
  GetConsoleScreenBufferInfo (hStdOut, &csbi);
  progmanLaunched = ((csbi.dwCursorPosition.X == 0) &&
		     (csbi.dwCursorPosition.Y == 0));
  if ((csbi.dwSize.X <= 0) || (csbi.dwSize.Y <= 0))
    progmanLaunched = 0;
}
#endif
