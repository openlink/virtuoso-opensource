/*
 *  Dksestcpint.h
 *
 *  $Id$
 *
 *  Internal of Dksestcp.h
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
 */

#ifndef _DKSESTCPINT_H
#define _DKSESTCPINT_H

#ifdef _SSL
#include <openssl/rsa.h>
#include <openssl/crypto.h>
#include <openssl/x509.h>
#include <openssl/pem.h>
#include <openssl/ssl.h>
#include <openssl/err.h>
#endif

#ifndef WIN32
#define closesocket	close
#define ioctlsocket	ioctl
#endif


typedef struct sockaddr_in saddrin_t;
typedef struct sockaddr saddr_t;
#ifdef COM_UNIXSOCK
typedef struct sockaddr_un saddrun_t;
#endif

typedef union
{
  saddrin_t 	t;
#ifdef COM_UNIXSOCK
  saddrun_t 	u;
#endif
  saddr_t 	a;
} usaddr_t;
#define TCP_HOSTNAMELEN     100				   /* Something */



struct addresstruct
{
  usaddr_t 	a_serveraddr;
  char 		a_hostname[TCP_HOSTNAMELEN];
  int 		a_port;
};


struct connectionstruct
{
  int 		con_s;			/* socket descriptor, must be first field */
  usaddr_t 	con_clientaddr;
  int 		con_is_file;
#ifdef _SSL
  void *	ssl;
  void *	ssl_ctx;		/* SSL context, setted only for https listeners */
#endif
  void *	con_gzfile;
};

#endif
