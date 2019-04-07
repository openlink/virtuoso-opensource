/*
 *  login_digest.c
 *
 *  $Id$
 *
 *  login digest calculator
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
 *  
*/

#include "libutil.h"

#ifdef _SSL
#include <openssl/md5.h>
#define MD5Init   MD5_Init
#define MD5Update MD5_Update
#define MD5Final  MD5_Final
#else
#include "util/md5.h"
#endif /* _SSL */

void
sec_login_digest (char *ses_name, char *user, char *pwd, unsigned char *digest)
{
  MD5_CTX ctx;

  MD5Init (&ctx);
  /* ses_name has binary parts */
  MD5Update (&ctx, (unsigned char *) ses_name, box_length (ses_name) - 1);
  MD5Update (&ctx, (unsigned char *) user, strlen (user));
  MD5Update (&ctx, (unsigned char *) pwd, strlen (pwd));
  MD5Final (digest, &ctx);
}
