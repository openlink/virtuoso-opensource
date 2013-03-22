/*
 *  Dksestcp.h
 *
 *  $Id$
 *
 *  TCP sessions
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2013 OpenLink Software
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

#ifndef _DKSESTCP_H
#define _DKSESTCP_H

#ifdef SUNRPC
# include <rpc/rpc.h>
#endif

#ifdef UNIX
# include <sys/socket.h>
# include <sys/ioctl.h>
# include <netinet/in.h>
# include <net/if.h>
# include <arpa/inet.h>
# ifdef HAVE_SYS_SELECT_H
#  include <sys/select.h>
# endif
# ifdef HAVE_SYS_SOCKIO_H
#  include <sys/sockio.h>
# endif
# ifdef OPL_SOURCE
#  define RPCFUN
#  include <rpc/netdb.h>
# else
#  include <netdb.h>
# endif
#endif

#ifdef COM_UNIXSOCK
#include <sys/socket.h>
#include <sys/un.h>
#endif

#if defined (PCTCP)
# include <windows.h>
extern int last_errno;
/*static int pctcp_started=0; */
# define init_tcpip()
/* if (!pctcp_started) {pctcp_started=1;init_pctcp();};
  Init called from level 2.  */
# define EMSGSIZE WSAEMSGSIZE
#else /* PCTCP */
# define init_tcpip()
#endif


/* DANGER! OS specific */
/* The errno value indicating that
   "non-blocking I/O request would block"
   differs from one operating system to another.
   Please define the SYS_EWBLK correctly before compiling.
*/
#if defined (ULTRIX) || defined (SUNOS)
# define SYS_EWBLK   EWOULDBLOCK
# define SYS_EINTR   EINTR

#elif defined (PCTCP)
# define SYS_EWBLK   WSAEWOULDBLOCK
# define SYS_EINTR   WSAEINTR

#else
# define SYS_EWBLK   EAGAIN
# define SYS_EINTR   EINTR
#endif

/* a MacOSX 10.2 specific hack */
#if defined (__APPLE__)
# include <AvailabilityMacros.h>
# if (!defined(MAC_OS_X_VERSION_10_3) || (MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_3) )
typedef unsigned int socklen_t;
# endif
#endif

#if defined (HPUX_11) && defined (POINTER_64)
#define socklen_t unsigned int
#endif

#endif /* _DKSESTCP_H */
