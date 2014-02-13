/*
 *  gettimeofday.c
 *
 *  $Id$
 *
 *  gettimeofday emulation
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
#if defined(VMS) || defined(macintosh)
# include <time.h>
#else
# include <sys/times.h>
#endif

#ifndef HAVE_GETTIMEOFDAY

#ifndef HZ
# define HZ 100
#endif

int 
gettimeofday (struct timeval *tvp, struct timezone *tzp)
{
#ifdef WIN32
  tvp->tv_sec = time (NULL);
  tvp->tv_usec = GetTickCount () % 1000;
#else

#ifndef macintosh
  static long offset = 0;
#else
  static time_t offset = 0;
#endif
#if !defined(VMS) && !defined(macintosh)
  struct tms buffer;
#endif
  long ticks;

  if (tvp == NULL)
    return (0);

  if (!offset)
    {
      time (&offset);
#if defined(VMS) || defined(macintosh)
      offset -= (clock () / 100);
#else
      offset -= (times (&buffer) / 100);
#endif
    }
#if defined(VMS) || defined(macintosh)
  ticks = clock ();
  tvp->tv_sec = offset + ticks / CLK_TCK;
  tvp->tv_usec = (ticks % CLK_TCK) * 10000;
#else
  ticks = times (&buffer);
  tvp->tv_sec = offset + ticks / HZ;
  tvp->tv_usec = (ticks % HZ) * 10000;
#endif

  if (tzp != NULL)
    {
      tvp->tv_sec -= (tzp->tz_minuteswest * 60);
      /*
         here we should handle tz_dsttime, but since I have no information
         about a specific conversation, this is missing here
      */
    }
#endif

  return (0);
}

#endif
