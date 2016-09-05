/*
 *  sslengine.c
 *
 *  $Id$
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
 */

#include "libutil.h"
#include "util/sslengine.h"
#include <openssl/err.h>

int
ssl_engine_startup (void)
{
#if OPENSSL_VERSION_NUMBER < 0x10100000
	CRYPTO_malloc_init ();
#else
	OPENSSL_malloc_init();
#endif
  ERR_load_crypto_strings();
  OpenSSL_add_all_algorithms();

  return 0;
}


int
ssl_engine_configure (const char *settings)
{
  return 0;
}


EVP_PKEY *
ssl_load_privkey (const char *keyname, const void *keypass)
{
  EVP_PKEY *pkey = NULL;
  BIO *bio_in;
  char *s;

  if ((bio_in = BIO_new_file (keyname, "r")) != NULL)
    {
      pkey = PEM_read_bio_PrivateKey (bio_in, NULL, NULL, NULL);
      BIO_free (bio_in);
    }

  return pkey;
}


/******************************************************************************/

X509 *
ssl_load_x509 (const char *filename)
{
  X509 *x509 = NULL;
  BIO *bio_in;

  if ((bio_in = BIO_new_file (filename, "r")) != NULL)
    {
      x509 = PEM_read_bio_X509 (bio_in, NULL, NULL, NULL);

      /* attempt binary certificates too, it's a native format on Windows */
      if (x509 == NULL &&
	(ERR_GET_REASON (ERR_peek_last_error ()) == PEM_R_NO_START_LINE))
	{
	  ERR_clear_error ();
	  BIO_seek (bio_in, 0);
	  x509 = d2i_X509_bio (bio_in, NULL);
	}

      BIO_free (bio_in);
    }

  return x509;
}
