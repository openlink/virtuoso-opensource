/*
 *  sslengine.c
 *
 *  $Id$
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
 */
#ifndef _SSLENGINE_H
#define _SSLENGINE_H

#include <openssl/ssl.h>

BEGIN_CPLUSPLUS

int ssl_engine_startup (void);
int ssl_engine_configure (const char *settings);
EVP_PKEY *ssl_load_privkey (const char *keyname, const void *keypass);
X509 *ssl_load_x509 (const char *filename);

END_CPLUSPLUS

#endif
