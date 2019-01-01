/*
 *  mts_client.h
 *
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2019 OpenLink Software
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

#ifndef _MTS_CLIENT_H
#define _MTS_CLIENT_H

#include "CLI.h"
#include "Dk/Dktypes.h"
#include "msdtc.h"

EXE_IMPORT (void, mts_get_trx_cookie, (void *con, void *i_trx, void **cookie,
	unsigned long *cookie_len));
EXE_IMPORT (caddr_t, mts_bin_encode, (void *bin_array,
	unsigned long bin_array_len));
EXE_IMPORT (int, mts_bin_decode, (const char *encoded_str, void **array,
	unsigned long *len));
void mts_client_init ();

#endif /* _MTS_CLIENT_H */
