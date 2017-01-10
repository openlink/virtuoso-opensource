/*
 *  Dkrusage.c
 *
 *  $Id$
 *
 *  Helper function to increase server resources on BSD machines
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
 */

#include "Dk.h"

#ifdef HAVE_SYS_RESOURCE_H

# include <sys/resource.h>


static void
max_resource_usage (int w)
{
  struct rlimit r;
  int i;

  if ((i = getrlimit (w, &r)) == 0 && r.rlim_cur != r.rlim_max)
    {
      /*
       * XXX Should calculate reasonable values and
       *     do error checking as well
       */
      r.rlim_cur = r.rlim_max;
      setrlimit (w, &r);
    }
}


void
dk_set_resource_usage (void)
{
#ifdef RLIMIT_CPU
  max_resource_usage (RLIMIT_CPU);		 /* CPU Time */
#endif

#ifdef RLIMIT_DATA
  max_resource_usage (RLIMIT_DATA);		 /* Data size (malloc) */
#endif

#ifdef RLIMIT_STACK
  max_resource_usage (RLIMIT_STACK);		 /* Stack size (fibers) */
#endif

#ifdef RLIMIT_NOFILE
  max_resource_usage (RLIMIT_NOFILE);		 /* Number of files (connections) */
#endif

#ifdef RLIMIT_FSIZE
  max_resource_usage (RLIMIT_FSIZE);		 /* File size (database) */
#endif
}


#else

void
dk_set_resource_usage (void)
{
}
#endif
