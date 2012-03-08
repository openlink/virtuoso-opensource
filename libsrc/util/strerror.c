/*
 *  strerror.c
 *
 *  $Id$
 *
 *  Return error string
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


char *
opl_strerror (int err)
{
  static char msgbuf[512];

#if defined (VMS)

  /*
   *  Under VMS, vaxc$errno should contain the VMS status code
   */
  if (err == EVMSERR)
    {
      if (get_message (vaxc$errno, msgbuf) != 0)
	sprintf (msgbuf, _("VMS error %%x%08X"), vaxc$errno);
    }
  else if (err >= 0 && err < sys_nerr)
    {
      sprintf (msgbuf, "%s (%d, %d)", sys_errlist[err], err, vaxc$errno);
    }
  else
    {
      sprintf (msgbuf, _("Unknown error %u (%d)"), err, vaxc$errno);
    }

  return msgbuf;

#elif defined (macintosh)

  sprintf (msgbuf, _("Error %u"), err);
  return msgbuf
#elif defined (HAVE_STRERROR)

  char *s = strerror (err);
  if (s)
    return s;			/* Some implementations return NULL */

#else /* all other systems */

  if (err >= 0 && err < sys_nerr)
    return sys_errlist[err];

#endif

  /* unknown error */
  sprintf (msgbuf, _("Unknown error %u"), err);

  return msgbuf;
}
