/*
 *  ssl_compat.h
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2022 OpenLink Software
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
 *  This file contains OpenSSL 1.1.x compatible API functions for
 *  compiling Virtuoso against the following versions of OpenSSL and LibreSSL:
 *
 *    OpenSSL 0.9.8
 *    OpenSSL 1.0.0
 *    OpenSSL 1.0.1
 *    OpenSSL 1.0.2
 *    OpenSSL 1.1.0
 *    OpenSSL 1.1.1
 *
 *    LibreSSL 2.x
 *    LibreSSL 3.x
 *
 *  Based on information from:
 *      https://wiki.openssl.org/index.php/OpenSSL_1.1.0_Changes
 *
 *  and various source archives.
 *
 */

#if defined (_SSL) && !defined (_SSL_COMPAT_H)
#define _SSL_COMPAT_H


#include <openssl/opensslv.h>


#if OPENSSL_VERSION_NUMBER < 0x10100000L

#include <string.h>
#include <openssl/engine.h>
#include <openssl/bn.h>
#include <openssl/rand.h>
#include <openssl/evp.h>
#include <openssl/dh.h>
#include <openssl/ecdh.h>
#include <openssl/md5.h>
#include <openssl/sha.h>
#include <openssl/lhash.h>
#include <openssl/hmac.h>
#include <openssl/x509.h>

/*
 *  Macros for backward compatible LHASH
 */
#if (OPENSSL_VERSION_NUMBER < 0x10000000L)
#define _LHASH LHASH
#endif

#define OPENSSL_LH_DOALL_FUNC	LHASH_DOALL_FN_TYPE

#define OPENSSL_LH_delete	lh_delete
#define OPENSSL_LH_free		lh_free
#define OPENSSL_LH_insert	lh_insert
#define OPENSSL_LH_new		lh_new
#define OPENSSL_LH_retrieve	lh_retrieve
#define OPENSSL_LH_strhash	lh_strhash
#define OPENSSL_LH_doall	lh_doall


/*
 *  OpenSSL 1.1 simple function name remap
 */
#define OPENSSL_malloc_init	CRYPTO_malloc_init


/*
 *  Check INLINE situation
 */
#ifndef NDEBUG
#define NO_SSL_COMPAT_INLINE
#endif

#ifndef NO_SSL_COMPAT_INLINE
#  define SSL_COMPAT_INLINE static inline
#else
#  define SSL_COMPAT_INLINE static
#endif


/*
 * ----------------------------------------------------------------------
 *  DH
 * ----------------------------------------------------------------------
 */

SSL_COMPAT_INLINE void
DH_get0_pqg (const DH * dh, const BIGNUM ** p, const BIGNUM ** q, const BIGNUM ** g)
{
  if (p != NULL)
    *p = dh->p;
  if (q != NULL)
    *q = dh->q;
  if (g != NULL)
    *g = dh->g;
}


SSL_COMPAT_INLINE int
DH_set0_pqg (DH * dh, BIGNUM * p, BIGNUM * q, BIGNUM * g)
{
  if ((dh->p == NULL && p == NULL) || (dh->g == NULL && g == NULL))
    return 0;

  if (p != NULL)
    {
      BN_free (dh->p);
      dh->p = p;
    }
  if (q != NULL)
    {
      BN_free (dh->q);
      dh->q = q;
    }
  if (g != NULL)
    {
      BN_free (dh->g);
      dh->g = g;
    }
  if (q != NULL)
    {
      dh->length = BN_num_bits (q);
    }

  return 1;
}


SSL_COMPAT_INLINE void
DH_get0_key (const DH * dh, const BIGNUM ** pub_key, const BIGNUM ** priv_key)
{
  if (pub_key != NULL)
    *pub_key = dh->pub_key;
  if (priv_key != NULL)
    *priv_key = dh->priv_key;
}


SSL_COMPAT_INLINE int
DH_set0_key (DH * dh, BIGNUM * pub_key, BIGNUM * priv_key)
{
  if (dh->pub_key == NULL && pub_key == NULL)
    return 0;

  if (pub_key != NULL)
    {
      BN_free (dh->pub_key);
      dh->pub_key = pub_key;
    }
  if (priv_key != NULL)
    {
      BN_free (dh->priv_key);
      dh->priv_key = priv_key;
    }
  return 1;
}


SSL_COMPAT_INLINE int
DH_set_length (DH * dh, long length)
{
  dh->length = length;
  return 1;
}


/*
 * ----------------------------------------------------------------------
 *  DSA
 * ----------------------------------------------------------------------
 */

SSL_COMPAT_INLINE int
DSA_set0_pqg (DSA * d, BIGNUM * p, BIGNUM * q, BIGNUM * g)
{
  if ((d->p == NULL && p == NULL) || (d->q == NULL && q == NULL) || (d->g == NULL && g == NULL))
    return 0;

  if (p != NULL)
    {
      BN_free (d->p);
      d->p = p;
    }
  if (q != NULL)
    {
      BN_free (d->q);
      d->q = q;
    }
  if (g != NULL)
    {
      BN_free (d->g);
      d->g = g;
    }
  return 1;
}


SSL_COMPAT_INLINE void
DSA_get0_key (const DSA * d, const BIGNUM ** pub_key, const BIGNUM ** priv_key)
{
  if (pub_key != NULL)
    *pub_key = d->pub_key;
  if (priv_key != NULL)
    *priv_key = d->priv_key;
}


SSL_COMPAT_INLINE int
DSA_set0_key (DSA * d, BIGNUM * pub_key, BIGNUM * priv_key)
{
  if (d->pub_key == NULL && pub_key == NULL)
    return 0;

  if (pub_key != NULL)
    {
      BN_free (d->pub_key);
      d->pub_key = pub_key;
    }
  if (priv_key != NULL)
    {
      BN_free (d->priv_key);
      d->priv_key = priv_key;
    }
  return 1;
}


SSL_COMPAT_INLINE void
DSA_SIG_get0 (const DSA_SIG * sig, const BIGNUM ** pr, const BIGNUM ** ps)
{
  if (pr != NULL)
    *pr = sig->r;
  if (ps != NULL)
    *ps = sig->s;
}


SSL_COMPAT_INLINE int
DSA_SIG_set0 (DSA_SIG * sig, BIGNUM * r, BIGNUM * s)
{
  if (r == NULL || s == NULL)
    return 0;
  BN_clear_free (sig->r);
  BN_clear_free (sig->s);
  sig->r = r;
  sig->s = s;
  return 1;
}


/*
 * ----------------------------------------------------------------------
 * EVP
 * ----------------------------------------------------------------------
 */

SSL_COMPAT_INLINE int
EVP_PKEY_up_ref (EVP_PKEY * pkey)
{
  return CRYPTO_add (&(pkey)->references, 0, CRYPTO_LOCK_EVP_PKEY);
}


#if OPENSSL_VERSION_NUMBER < 0x10000000L
SSL_COMPAT_INLINE int
EVP_PKEY_id (const EVP_PKEY * pkey)
{
  return pkey->type;
}
#endif


SSL_COMPAT_INLINE DSA *
EVP_PKEY_get0_DSA (EVP_PKEY * pkey)
{
  if (pkey->type != EVP_PKEY_DSA)
    return NULL;
  return pkey->pkey.dsa;
}


SSL_COMPAT_INLINE RSA *
EVP_PKEY_get0_RSA (EVP_PKEY * pkey)
{
  if (pkey->type != EVP_PKEY_RSA)
    return NULL;
  return pkey->pkey.rsa;
}


SSL_COMPAT_INLINE DH *
EVP_PKEY_get0_DH (EVP_PKEY * pkey)
{
  if (pkey->type != EVP_PKEY_DH)
    return NULL;
  return pkey->pkey.dh;
}


SSL_COMPAT_INLINE const unsigned char *
EVP_CIPHER_CTX_iv (const EVP_CIPHER_CTX * ctx)
{
  return ctx->iv;
}


SSL_COMPAT_INLINE unsigned char *
EVP_CIPHER_CTX_iv_noconst (EVP_CIPHER_CTX * ctx)
{
  return ctx->iv;
}


SSL_COMPAT_INLINE EVP_MD_CTX *
EVP_MD_CTX_new (void)
{
  EVP_MD_CTX *ctx = (EVP_MD_CTX *) OPENSSL_malloc (sizeof (EVP_MD_CTX));
  if (ctx)
    memset (ctx, '\0', sizeof (EVP_MD_CTX));
  return ctx;
}


SSL_COMPAT_INLINE void
EVP_MD_CTX_free (EVP_MD_CTX * ctx)
{
  EVP_MD_CTX_cleanup (ctx);
  OPENSSL_free (ctx);
}


/*
 * ----------------------------------------------------------------------
 * HMAC
 * ----------------------------------------------------------------------
 */

SSL_COMPAT_INLINE HMAC_CTX *
HMAC_CTX_new (void)
{
  HMAC_CTX *ctx = OPENSSL_malloc (sizeof (HMAC_CTX));
  if (ctx != NULL)
    HMAC_CTX_init (ctx);
  return ctx;
}


SSL_COMPAT_INLINE void
HMAC_CTX_free (HMAC_CTX * ctx)
{
  if (ctx != NULL)
    {
      HMAC_CTX_cleanup (ctx);
      OPENSSL_free (ctx);
    }
}


/*
 * ----------------------------------------------------------------------
 * RSA
 * ----------------------------------------------------------------------
 */

SSL_COMPAT_INLINE int
RSA_set0_key (RSA * r, BIGNUM * n, BIGNUM * e, BIGNUM * d)
{
  /* If the fields n and e in r are NULL, the corresponding input
   * parameters MUST be non-NULL for n and e.  d may be
   * left NULL (in case only the public key is used).
   */
  if ((r->n == NULL && n == NULL) || (r->e == NULL && e == NULL))
    return 0;

  if (n != NULL)
    {
      BN_free (r->n);
      r->n = n;
    }
  if (e != NULL)
    {
      BN_free (r->e);
      r->e = e;
    }
  if (d != NULL)
    {
      BN_free (r->d);
      r->d = d;
    }

  return 1;
}


SSL_COMPAT_INLINE int
RSA_set0_factors (RSA * r, BIGNUM * p, BIGNUM * q)
{
  /* If the fields p and q in r are NULL, the corresponding input
   * parameters MUST be non-NULL.
   */
  if ((r->p == NULL && p == NULL) || (r->q == NULL && q == NULL))
    return 0;

  if (p != NULL)
    {
      BN_free (r->p);
      r->p = p;
    }
  if (q != NULL)
    {
      BN_free (r->q);
      r->q = q;
    }
  return 1;
}


SSL_COMPAT_INLINE int
RSA_set0_crt_params (RSA * r, BIGNUM * dmp1, BIGNUM * dmq1, BIGNUM * iqmp)
{
  /* If the fields dmp1, dmq1 and iqmp in r are NULL, the corresponding input
   * parameters MUST be non-NULL.
   */
  if ((r->dmp1 == NULL && dmp1 == NULL) || (r->dmq1 == NULL && dmq1 == NULL) || (r->iqmp == NULL && iqmp == NULL))
    return 0;

  if (dmp1 != NULL)
    {
      BN_free (r->dmp1);
      r->dmp1 = dmp1;
    }
  if (dmq1 != NULL)
    {
      BN_free (r->dmq1);
      r->dmq1 = dmq1;
    }
  if (iqmp != NULL)
    {
      BN_free (r->iqmp);
      r->iqmp = iqmp;
    }
  return 1;
}


SSL_COMPAT_INLINE void
RSA_get0_key (const RSA * r, const BIGNUM ** n, const BIGNUM ** e, const BIGNUM ** d)
{
  if (n != NULL)
    *n = r->n;
  if (e != NULL)
    *e = r->e;
  if (d != NULL)
    *d = r->d;
}


SSL_COMPAT_INLINE void
RSA_get0_factors (const RSA * r, const BIGNUM ** p, const BIGNUM ** q)
{
  if (p != NULL)
    *p = r->p;
  if (q != NULL)
    *q = r->q;
}


SSL_COMPAT_INLINE void
RSA_get0_crt_params (const RSA * r, const BIGNUM ** dmp1, const BIGNUM ** dmq1, const BIGNUM ** iqmp)
{
  if (dmp1 != NULL)
    *dmp1 = r->dmp1;
  if (dmq1 != NULL)
    *dmq1 = r->dmq1;
  if (iqmp != NULL)
    *iqmp = r->iqmp;
}


SSL_COMPAT_INLINE void
DSA_get0_pqg (const DSA * d, const BIGNUM ** p, const BIGNUM ** q, const BIGNUM ** g)
{
  if (p != NULL)
    *p = d->p;
  if (q != NULL)
    *q = d->q;
  if (g != NULL)
    *g = d->g;
}


SSL_COMPAT_INLINE RSA_METHOD *
RSA_meth_dup (const RSA_METHOD * meth)
{
  RSA_METHOD *ret;

  ret = OPENSSL_malloc (sizeof (RSA_METHOD));

  if (ret != NULL)
    {
      memcpy (ret, meth, sizeof (RSA_METHOD));
      ret->name = OPENSSL_malloc (strlen(meth->name) + 1);
      if (ret->name == NULL)
	{
	  OPENSSL_free (ret);
	  return NULL;
	}
      strcpy (ret->name, meth->name);
    }
  return ret;
}


SSL_COMPAT_INLINE int
RSA_meth_set1_name (RSA_METHOD * meth, const char *name)
{
  char *tmpname;

  tmpname = OPENSSL_malloc (strlen(name) + 1);
  if (tmpname == NULL)
    {
      return 0;
    }
  strcpy (tmpname, meth->name);
  OPENSSL_free ((char *) meth->name);
  meth->name = tmpname;

  return 1;
}


SSL_COMPAT_INLINE int
RSA_meth_set_priv_enc (RSA_METHOD * meth,
    int (*priv_enc) (int flen, const unsigned char *from, unsigned char *to, RSA * rsa, int padding))
{
  meth->rsa_priv_enc = priv_enc;
  return 1;
}


SSL_COMPAT_INLINE int
RSA_meth_set_priv_dec (RSA_METHOD * meth,
    int (*priv_dec) (int flen, const unsigned char *from, unsigned char *to, RSA * rsa, int padding))
{
  meth->rsa_priv_dec = priv_dec;
  return 1;
}


SSL_COMPAT_INLINE int
RSA_meth_set_finish (RSA_METHOD * meth, int (*finish) (RSA * rsa))
{
  meth->finish = finish;
  return 1;
}


SSL_COMPAT_INLINE void
RSA_meth_free (RSA_METHOD * meth)
{
  if (meth != NULL)
    {
      OPENSSL_free ((char *) meth->name);
      OPENSSL_free (meth);
    }
}


SSL_COMPAT_INLINE int
RSA_bits (const RSA * r)
{
  return (BN_num_bits (r->n));
}


/*
 * ----------------------------------------------------------------------
 * X509
 * ----------------------------------------------------------------------
 */

SSL_COMPAT_INLINE int
X509_up_ref (X509 * x)
{
  return CRYPTO_add (&x->references, 1, CRYPTO_LOCK_X509);
}


SSL_COMPAT_INLINE
STACK_OF (X509_OBJECT) *
X509_STORE_get0_objects (X509_STORE * v)
{
  return v->objs;
}


SSL_COMPAT_INLINE int
X509_OBJECT_get_type (const X509_OBJECT * a)
{
  return a->type;
}


SSL_COMPAT_INLINE X509 *
X509_OBJECT_get0_X509 (const X509_OBJECT * a)
{
  if (a == NULL || a->type != X509_LU_X509)
    return NULL;
  return a->data.x509;
}


SSL_COMPAT_INLINE const
STACK_OF (X509_EXTENSION) *
X509_get0_extensions (const X509 * x)
{
  return x->cert_info->extensions;
}


SSL_COMPAT_INLINE int X509_CRL_up_ref(X509_CRL *crl)
{
  return CRYPTO_add (&crl->references, 1, CRYPTO_LOCK_X509_CRL);
}


#if OPENSSL_VERSION_NUMBER < 0x1000100FL
SSL_COMPAT_INLINE
void SSL_set_state(SSL *ssl, int state)
{
	ssl->state = state;
}
#endif


#if OPENSSL_VERSION_NUMBER < 0x10002000L
SSL_COMPAT_INLINE
void X509_get0_signature(ASN1_BIT_STRING **psig, X509_ALGOR **palg, const X509 *x)
{
    if (psig)
        *psig = x->signature;
    if (palg)
        *palg = x->sig_alg;
}
#endif

#endif /* OPENSSL_VERSION_NUMBER */
#endif /* _SSL */
