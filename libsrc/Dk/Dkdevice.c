/*
 *  Dkdevice.c
 *
 *  $Id$
 *
 *  Devices
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
 */

#include "Dk.h"

device_t *tcpdev_allocate (void);
device_t *unixdev_allocate (void);
device_t *udpdev_allocate (void);
device_t *nmpdev_allocate (void);


device_t *
device_allocate (int devclass)
{

  switch (devclass)
    {
#ifdef COM_TCPIP
    case SESCLASS_TCPIP:
      return tcpdev_allocate ();
#endif

#ifdef COM_UDPIP
    case SESCLASS_UDPIP:
      return udpdev_allocate ();
#endif

#ifdef COM_NMPIPE
    case SESCLASS_NMPIPE:
      return nmpdev_allocate ();
#endif /* COM_NMPIPE */

#ifdef COM_UNIXSOCK
    case SESCLASS_UNIX:
      return unixdev_allocate ();
#endif /* COM_UNIXSOCK */

    default:
      return ((device_t *) 0);
    }
}


int
device_free (device_t * dev)
{
  return ((*dev->dev_funs->dfp_free) (dev));
}
