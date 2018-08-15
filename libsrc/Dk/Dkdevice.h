/*
 *  Dkdevice.h
 *
 *  $Id$
 *
 *  Devices
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
 */

#ifndef _DKDEVICE_H
#define _DKDEVICE_H


/* Device functions */
typedef struct devfuns_s devfuns_t;

/* Device specific type containing address information */
typedef struct addresstruct address_t;

/* Device specific type containing address information */
typedef struct unix_addresstruct unix_address_t;

/* Device specific type containing connection information */
typedef struct connectionstruct connection_t;

/* General communications device structure */
struct device_s
{
  address_t *		dev_address;		/* address instance (partner?) */
  connection_t *	dev_connection;		/* connection instance */
  devfuns_t *		dev_funs;		/* implemented functions */
  int 			dev_check;		/* internal check field */
  address_t *		dev_accepted_address;	/* listening session address */
};

/* Common "methods" for all communication devices */
struct devfuns_s
{
  device_t *(*dfp_allocate) (void);
  int (*dfp_free) (device_t * dev);
  int (*dfp_set_address) (session_t * ses, char *addrinfo);
  int (*dfp_listen) (session_t * ses);
  int (*dfp_accept) (session_t * ses, session_t * new_ses);
  int (*dfp_connect) (session_t * ses);
  int (*dfp_disconnect) (session_t * ses);
  int (*dfp_write) (session_t * ses, char *buffer, int n_bytes);
  int (*dfp_read) (session_t * ses, char *buffer, int n_bytes);
  int (*dfp_flush) (session_t * ses, char *buffer, int n_bytes);
  int (*dfp_select) (int ses_count, session_t ** reads, session_t ** writes, timeout_t * timeout);
  int (*dfp_set_control) (session_t * ses, int fld, char *v, int sz);
  int (*dfp_get_control) (session_t * ses, int fld, char *v, int sz);
};

/*
 *  Session classes
 */
#define SESCLASS_TCPIP			0
#define SESCLASS_NMPIPE			1
#define SESCLASS_NETBIOS		2
#define SESCLASS_STRING			4
#define SESCLASS_UDPIP			7
#define SESCLASS_UNIX			8

device_t *device_allocate (int sesclass);
int device_free (device_t * dev);

#endif
