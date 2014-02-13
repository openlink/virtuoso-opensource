/*
 *  wi_xid.h
 *
 *  $Id$
 *
 *  Functions to deal with XID structures
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

#ifndef _WI_XID_H
#define _WI_XID_H

#include "util/uuid.h"

/* XA ids support */
#if !defined (XA_H)

#define XIDDATASIZE	128		/* size in bytes */

struct virt_xid_t {
	int32 formatID;			/* format identifier */
	int32 gtrid_length;		/* value not to exceed 64 */
	int32 bqual_length;		/* value not to exceed 64 */
	char data[XIDDATASIZE];
  };
typedef struct virt_xid_t virtXID;

#endif

char* uuid_bin_encode (void* uuid);
void* uuid_bin_decode (const char* uuid_str);

char* xid_bin_encode (void* xid);
void* xid_bin_decode (const char* xid_str);

#endif
