/*
 *  bif_crypto.c
 *
 *  $Id$
 *
 *  Cryptography functions
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2012 OpenLink Software
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

#include "sqlnode.h"
#include "sqlbif.h"
#include "srvmultibyte.h"
#include "xmltree.h"

/*#undef _SSL*/

#ifdef _SSL
#include "xmlenc.h"
#include "http.h"

#include <openssl/sha.h>
#include <openssl/evp.h>
#include <openssl/hmac.h>
#include <openssl/asn1.h>
#include <openssl/bn.h>
#include <openssl/dsa.h>
#include <openssl/x509.h>
#include <openssl/x509v3.h>
#include <openssl/x509_vfy.h>
#include <openssl/pem.h>
#include <openssl/err.h>
#include <openssl/ssl.h>

#define DO_BOX_ALG_1(A_TYPE,A_NAME,A_PREFIX) \
void \
box_##A_NAME##_1 (caddr_t box, A_TYPE##_CTX * ctx) \
{ \
  dtp_t dtp; \
  int len, inx; \
  if (!IS_BOX_POINTER (box)) \
    { \
      A_PREFIX##Update (ctx, (unsigned char *) &box, sizeof (long)); \
      return; \
    } \
  dtp = box_tag (box); \
  len = box_length (box); \
  switch (dtp) \
    { \
    case DV_ARRAY_OF_POINTER: case DV_LIST_OF_POINTER: case DV_ARRAY_OF_XQVAL: case DV_XTREE_HEAD: case DV_XTREE_NODE: \
      { \
	for (inx = 0; inx < (int) (len / sizeof (caddr_t)); inx++) \
	  box_##A_NAME##_1 (((caddr_t *) box)[inx], ctx); \
      } \
      break; \
    case DV_BLOB_HANDLE: \
    case DV_BLOB_WIDE_HANDLE: \
      return; \
    case DV_STRING: \
    case DV_C_STRING: \
      box_tag_modify (box, DV_SHORT_STRING); \
      A_PREFIX##Update (ctx, (unsigned char *) box, len); \
      box_tag_modify (box, dtp); \
      break; \
    default: \
      A_PREFIX##Update (ctx, (unsigned char *) box, len); \
      break; \
    } \
}

#define DO_BOX_ALG(A_TYPE,A_NAME,A_PREFIX,A_LENGTH) \
caddr_t \
box_##A_NAME (caddr_t box) \
{ \
  caddr_t res = dk_alloc_box (A_LENGTH + 1, DV_SHORT_STRING); \
  A_TYPE##_CTX ctx; \
  A_PREFIX##Init (&ctx); \
  box_##A_NAME##_1 (box, &ctx); \
  A_PREFIX##Final ((unsigned char *) res, &ctx); \
  res[A_LENGTH] = 0; \
  return res; \
}

#define DO_BIF_TREE_ALG(A_TYPE,A_NAME,A_PREFIX,A_LENGTH) \
static caddr_t \
bif_tree_##A_NAME  (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args) \
{ \
  caddr_t x = bif_arg (qst, args, 0, "tree_A_NAME"); \
  caddr_t hex = box_##A_NAME (x), out; \
  long make_it_hex = 0; \
  int inx; \
\
  if (BOX_ELEMENTS (args) > 1) \
    make_it_hex = bif_long_arg (qst, args, 1, "tree_A_NAME"); \
  if (make_it_hex) \
    { \
      char tmp[3]; \
      out = dk_alloc_box (2 * (box_length (hex) - 1) + 1, DV_SHORT_STRING); \
      out[0] = 0; \
      for (inx = 0; ((uint32) inx) < box_length (hex) - 1; inx++) \
	 { \
	   snprintf (tmp, sizeof (tmp), "%02x", (unsigned char) hex[inx]); \
	   strcat_box_ck (out, tmp); \
	   /*sprintf (out + inx * 2, "%02x", (unsigned int) hex[inx]); */ \
	 } \
      out[2 * (box_length (hex) - 1)] = 0; \
      dk_free_box (hex); \
    } \
  else \
    out = hex; \
  return (out); \
}

#define DO_ALG(A_TYPE,A_NAME,A_PREFIX,A_LENGTH) \
DO_BOX_ALG_1(A_TYPE,A_NAME,A_PREFIX) \
DO_BOX_ALG(A_TYPE,A_NAME,A_PREFIX,A_LENGTH) \
DO_BIF_TREE_ALG(A_TYPE,A_NAME,A_PREFIX,A_LENGTH)


DO_ALG (SHA, sha1, SHA1_, SHA_DIGEST_LENGTH)
DO_BOX_ALG_1 (HMAC, hmac, HMAC_)

caddr_t
get_ssl_error_text (char *buf, int len)
{
  char *err_ptr = NULL;
  caddr_t res = NULL;
  int err_len;
  BIO *bio = BIO_new (BIO_s_mem ());

  ERR_print_errors (bio);
  if (0 < (err_len = BIO_get_mem_data (bio, &err_ptr)))
    {
      if (!buf)
	res = dk_alloc_box (err_len + 1, DV_SHORT_STRING);
      else
	{
	  res = buf;
	  err_len = err_len > len - 1 ? len - 1 : err_len;
	}
      memcpy (res, err_ptr, err_len);
      res[err_len] = 0;
    }
  else
    {
      err_len = sizeof ("<Unspecified>") - 1;
      if (!buf)
	res = dk_alloc_box (err_len + 1, DV_SHORT_STRING);
      else
	{
	  res = buf;
	  err_len = err_len > len - 1 ? len - 1 : err_len;
	}
      strncpy (res, "<Unspecified>", err_len);
    }
  BIO_free (bio);
  return res;
}


caddr_t
box_hmac (caddr_t box, caddr_t key, int alg)
{
  unsigned char temp[EVP_MAX_MD_SIZE];
  unsigned int size = 0;
  caddr_t res = NULL;
  HMAC_CTX ctx;
  const EVP_MD *md = EVP_sha1 ();

  if (alg == 1)
    md = EVP_ripemd160 ();

  HMAC_Init (&ctx, key, box_length (key) - DV_STRINGP (key) ? 1 : 0, md);
  box_hmac_1 (box, &ctx);
  HMAC_Final (&ctx, temp, &size);
  if (size)
    {
      res = dk_alloc_box (size + 1, DV_SHORT_STRING);
      memcpy (res, temp, size);
      res[size] = 0;
    }
  return res;
}


int
asn1_print_xml_tree_info (BIO * bp, int tag, int xclass, int constructed, int indent, int close)
{
  static const char fmt[] = "<%s>";
  static const char fmt2[] = "</%s>";
  char str[128];
  const char *p = NULL;
  p = str;
  p = ASN1_tag2str (tag);
  if (close == 0)
    {
      if (BIO_printf (bp, fmt, p) <= 0)
	goto err;
    }
  else
    {
      if (BIO_printf (bp, fmt2, p) <= 0)
	goto err;
    }
  return (1);
err:
  return (0);
}


int
asn1_parse_to_xml (BIO * bp, unsigned char **pp, long length, int offset, int depth, int indent, int dump)
{
  unsigned char *p, *ep, *tot, *op, *opp;
  long len;
  int save_tag, tag, xclass, ret = 0;
  int nl, hl, j, r;
  ASN1_OBJECT *o = NULL;
  ASN1_OCTET_STRING *os = NULL;
  /* ASN1_BMPSTRING *bmp=NULL; */
  int dump_indent;

#if 0
  dump_indent = indent;
#else
  dump_indent = 6;				 /* Because we know BIO_dump_indent() */
#endif
  p = *pp;
  tot = p + length;
  op = p - 1;
  while ((p < tot) && (op < p))
    {
      op = p;
      j = ASN1_get_object (&p, &len, &tag, &xclass, length);
      save_tag = tag;
#ifdef LINT
      j = j;
#endif
      if (j & 0x80)
	{
	  if (BIO_write (bp, "Error in encoding\n", 18) <= 0)
	    goto end;
	  ret = 0;
	  goto end;
	}
      hl = (p - op);
      length -= hl;
      /* if j == 0x21 it is a constructed indefinite length object */
      /*if (BIO_printf(bp,"%5ld:",(long)offset+(long)(op- *pp))
         <= 0) goto end; */

      /*
         if (j != (V_ASN1_CONSTRUCTED | 1))
           {
             if (BIO_printf(bp,"d=%-2d hl=%ld l=%4ld ", depth,(long)hl,len) <= 0)
               goto end;
           }
         else
           {
             if (BIO_printf(bp,"d=%-2d hl=%ld l=inf  ", depth,(long)hl) <= 0)
               goto end;
           }
      */
      if (!asn1_print_xml_tree_info (bp, tag, xclass, j, (indent) ? depth : 0, 0))
	goto end;
      if (j & V_ASN1_CONSTRUCTED)
	{
	  ep = p + len;
	  /*if (BIO_write(bp,"\n",1) <= 0) goto end; */
	  if (len > length)
	    {
	      BIO_printf (bp, "length is greater than %ld\n", length);
	      ret = 0;
	      goto end;
	    }
	  if ((j == 0x21) && (len == 0))
	    {
	      for (;;)
		{
		  r = asn1_parse_to_xml (bp, &p, (long) (tot - p), offset + (p - *pp), depth + 1, indent, dump);
		  if (r == 0)
		    {
		      ret = 0;
		      goto end;
		    }
		  if ((r == 2) || (p >= tot))
		    break;
		}
	    }
	  else
	    while (p < ep)
	      {
		r = asn1_parse_to_xml (bp, &p, (long) len, offset + (p - *pp), depth + 1, indent, dump);
		if (r == 0)
		  {
		    ret = 0;
		    goto end;
		  }
	      }
	}
      else if (xclass != 0)
	{
	  p += len;
	  /*if (BIO_write(bp,"\n",1) <= 0) goto end; */
	}
      else
	{
	  nl = 0;
	  if ((tag == V_ASN1_PRINTABLESTRING) || (tag == V_ASN1_T61STRING) || (tag == V_ASN1_IA5STRING) || (tag == V_ASN1_VISIBLESTRING) || (tag == V_ASN1_UTCTIME) || (tag == V_ASN1_GENERALIZEDTIME))
	    {
	      /*if (BIO_write(bp,":",1) <= 0) goto end; */
	      if ((len > 0) && BIO_write (bp, (const char *) p, (int) len) != (int) len)
		goto end;
	    }
	  else if (tag == V_ASN1_OBJECT)
	    {
	      opp = op;
	      if (d2i_ASN1_OBJECT (&o, &opp, len + hl) != NULL)
		{
		  /*if (BIO_write(bp,":",1) <= 0) goto end; */
		  i2a_ASN1_OBJECT (bp, o);
		}
	      else
		{
		  if (BIO_write (bp, ":BAD OBJECT", 11) <= 0)
		    goto end;
		}
	    }
	  else if (tag == V_ASN1_BOOLEAN)
	    {
	      int ii;

	      opp = op;
	      ii = d2i_ASN1_BOOLEAN (NULL, &opp, len + hl);
	      if (ii < 0)
		{
		  if (BIO_write (bp, "Bad boolean\n", 12))
		    goto end;
		}
	      BIO_printf (bp, "%d", ii);
	    }
	  else if (tag == V_ASN1_BMPSTRING)
	    {
	      /* do the BMP thing */
	    }
	  else if (tag == V_ASN1_OCTET_STRING)
	    {
	      int i, printable = 1;

	      opp = op;
	      os = d2i_ASN1_OCTET_STRING (NULL, &opp, len + hl);
	      if (os != NULL && os->length > 0)
		{
		  opp = os->data;
		  /* testing whether the octet string is
		   * printable */
		  for (i = 0; i < os->length; i++)
		    {
		      if (((opp[i] < ' ') && (opp[i] != '\n') && (opp[i] != '\r') && (opp[i] != '\t')) || (opp[i] > '~'))
			{
			  printable = 0;
			  break;
			}
		    }
		  if (printable)
		    /* printable string */
		    {
		      /*if (BIO_write(bp,":",1) <= 0)
		         goto end; */
		      if (BIO_write (bp, (const char *) opp, os->length) <= 0)
			goto end;
		    }
		  else if (!dump)
		    /* not printable => print octet string
		     * as hex dump */
		    {
		      /*if (BIO_write(bp,"[HEX DUMP]:",11) <= 0)
		         goto end; */
		      for (i = 0; i < os->length; i++)
			{
			  if (BIO_printf (bp, "%02X", opp[i]) <= 0)
			    goto end;
			}
		    }
		  else
		    /* print the normal dump */
		    {
		      if (!nl)
			{
			  /*if (BIO_write(bp,"\n",1) <= 0)
			     goto end; */
			  ;
			}
		      if (BIO_dump_indent (bp, (const char *) opp, ((dump == -1 || dump > os->length) ? os->length : dump), dump_indent) <= 0)
			goto end;
		      nl = 1;
		    }
		}
	      if (os != NULL)
		{
		  M_ASN1_OCTET_STRING_free (os);
		  os = NULL;
		}
	    }
	  else if (tag == V_ASN1_INTEGER)
	    {
	      ASN1_INTEGER *bs;
	      int i;

	      opp = op;
	      bs = d2i_ASN1_INTEGER (NULL, &opp, len + hl);
	      if (bs != NULL)
		{
		  /*if (BIO_write(bp,":",1) <= 0) goto end; */
		  if (bs->type == V_ASN1_NEG_INTEGER)
		    if (BIO_write (bp, "-", 1) <= 0)
		      goto end;
		  for (i = 0; i < bs->length; i++)
		    {
		      if (BIO_printf (bp, "%02X", bs->data[i]) <= 0)
			goto end;
		    }
		  if (bs->length == 0)
		    {
		      if (BIO_write (bp, "00", 2) <= 0)
			goto end;
		    }
		}
	      else
		{
		  if (BIO_write (bp, "BAD INTEGER", 11) <= 0)
		    goto end;
		}
	      M_ASN1_INTEGER_free (bs);
	    }
	  else if (tag == V_ASN1_ENUMERATED)
	    {
	      ASN1_ENUMERATED *bs;
	      int i;

	      opp = op;
	      bs = d2i_ASN1_ENUMERATED (NULL, &opp, len + hl);
	      if (bs != NULL)
		{
		  /*if (BIO_write(bp,":",1) <= 0) goto end; */
		  if (bs->type == V_ASN1_NEG_ENUMERATED)
		    if (BIO_write (bp, "-", 1) <= 0)
		      goto end;
		  for (i = 0; i < bs->length; i++)
		    {
		      if (BIO_printf (bp, "%02X", bs->data[i]) <= 0)
			goto end;
		    }
		  if (bs->length == 0)
		    {
		      if (BIO_write (bp, "00", 2) <= 0)
			goto end;
		    }
		}
	      else
		{
		  if (BIO_write (bp, "BAD ENUMERATED", 11) <= 0)
		    goto end;
		}
	      M_ASN1_ENUMERATED_free (bs);
	    }
	  else if (len > 0 && dump)
	    {
	      if (!nl)
		{
		  /*if (BIO_write(bp,"\n",1) <= 0)
		     goto end; */
		  ;
		}
	      if (BIO_dump_indent (bp, (const char *) p, ((dump == -1 || dump > len) ? len : dump), dump_indent) <= 0)
		goto end;
	      nl = 1;
	    }

	  if (!nl)
	    {
	      /*if (BIO_write(bp,"\n",1) <= 0) goto end; */
	      ;
	    }
	  p += len;
	  if ((tag == V_ASN1_EOC) && (xclass == 0))
	    {
	      ret = 2;				 /* End of sequence */
	      goto end;
	    }
	}
      length -= len;
      if (!asn1_print_xml_tree_info (bp, save_tag, xclass, j, (indent) ? depth : 0, 1))
	goto end;
    }
  ret = 1;
end:
  if (o != NULL)
    ASN1_OBJECT_free (o);
  if (os != NULL)
    M_ASN1_OCTET_STRING_free (os);
  *pp = p;
  return (ret);
}


static caddr_t
bif_asn1_to_xml (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t res;
  BIO *out = NULL;
  int len = 0;
  char tmpbuf[100000];
  caddr_t bytes = bif_string_arg (qst, args, 0, "asn1_to_xml");
  long length = BOX_ELEMENTS (args) > 1 ? bif_long_arg (qst, args, 1, "asn1_to_xml") : 0;
  if (!(out = BIO_new (BIO_s_mem ())))
    return NEW_DB_NULL;
  if (0 == length)
    length = box_length (bytes) - 1;
  if (asn1_parse_to_xml (out, (unsigned char **) &bytes, length, 0, 0, 0, 1) != 1)
    {
      res = NEW_DB_NULL;
      goto err;
    }
  len = BIO_read (out, tmpbuf, sizeof (tmpbuf));
  if (len <= 0 || len == sizeof (tmpbuf))
    {
      res = NEW_DB_NULL;
      goto err;
    }
  res = box_dv_short_string (tmpbuf);
err:
  if (out != NULL)
    BIO_free_all (out);
  return res;
}


static caddr_t
bif_tree_hmac (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t x = bif_arg (qst, args, 0, "tree_hmac");
  caddr_t key = bif_string_arg (qst, args, 1, "tree_hmac");
  long alg = 0;
  caddr_t hex, out;
  long make_it_hex = 0;
  int inx;
  if (BOX_ELEMENTS (args) > 2)
    alg = bif_long_arg (qst, args, 2, "tree_hmac");
  if (BOX_ELEMENTS (args) > 3)
    make_it_hex = bif_long_arg (qst, args, 3, "tree_hmac");

  if (NULL == (hex = box_hmac (x, key, alg)))
    return dk_alloc_box (0, DV_DB_NULL);

  if (make_it_hex)
    {
      char tmp[3];
      out = dk_alloc_box (2 * (box_length (hex) - 1) + 1, DV_SHORT_STRING);
      out[0] = 0;
      for (inx = 0; ((uint32) inx) < box_length (hex) - 1; inx++)
	{
	  snprintf (tmp, sizeof (tmp), "%02x", (unsigned char) hex[inx]);
	  strcat_box_ck (out, tmp);
	  /*sprintf (out + inx * 2, "%02x", (unsigned int) hex[inx]); */
	}
      out[2 * (box_length (hex) - 1)] = 0;
      dk_free_box (hex);
    }
  else
    out = hex;
  return (out);
}


static int
X509_load_cert_crl_buf (X509_STORE * store, caddr_t buf, caddr_t * err_ret)
{
  BIO *in;
  STACK_OF (X509_INFO) * inf;
  X509_INFO *itmp;
  int i, count = 0;
  char err_buf[512];

  in = BIO_new_mem_buf (buf, box_length (buf) - 1);
  if (!in)
    {
      *err_ret = srv_make_new_error ("42000", "CR001", "Cannot allocate temp space. SSL Error : %s", get_ssl_error_text (err_buf, sizeof (err_buf)));
      return 0;
    }
  inf = PEM_X509_INFO_read_bio (in, NULL, NULL, NULL);
  BIO_free (in);
  if (!inf)
    {
      *err_ret = srv_make_new_error ("42000", "CR002", "Cannot read certificates. SSL Error : %s", get_ssl_error_text (err_buf, sizeof (err_buf)));
      return 0;
    }
  for (i = 0; i < sk_X509_INFO_num (inf); i++)
    {
      itmp = sk_X509_INFO_value (inf, i);
      if (itmp->x509)
	{
	  X509_STORE_add_cert (store, itmp->x509);
	  count++;
	}
      else if (itmp->crl)
	{
	  X509_STORE_add_crl (store, itmp->crl);
	  count++;
	}
    }
  sk_X509_INFO_pop_free (inf, X509_INFO_free);
  return count;
}


static X509_STORE *
smime_get_store_from_array (caddr_t array, caddr_t * err_ret)
{
  X509_STORE *store;
  int inx;

  *err_ret = NULL;
  store = X509_STORE_new ();

  if (DV_TYPE_OF (array) != DV_ARRAY_OF_POINTER || BOX_ELEMENTS (array) == 0)
    return store;

  DO_BOX (caddr_t, cert, inx, ((caddr_t *) array))
  {
    if (DV_STRINGP (cert))
      {
	X509_load_cert_crl_buf (store, cert, err_ret);
	if (*err_ret)
	  {
	    X509_STORE_free (store);
	    return NULL;
	  }
      }
  }
  END_DO_BOX;
  return store;
}


static caddr_t
pkcs7_signer_info_to_array (PKCS7 * p7)
{
  caddr_t *ret = NULL;
  STACK_OF (X509) * inf = NULL;

  if (p7)
    inf = PKCS7_get0_signers (p7, NULL, 0);

  if (inf)
    {
      int i, n_certs = sk_X509_num (inf);
      X509 *itmp;
      BIO *bio_mem;
      char *ptr;

      ret = (caddr_t *) dk_alloc_box_zero (n_certs * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      for (i = 0; i < n_certs; i++)
	{
	  itmp = sk_X509_value (inf, i);
	  bio_mem = BIO_new (BIO_s_mem ());
	  PEM_write_bio_X509 (bio_mem, itmp);
	  ret[i] = dk_alloc_box (BIO_get_mem_data (bio_mem, &ptr) + 1, DV_SHORT_STRING);
	  memcpy (ret[i], ptr, box_length (ret[i]) - 1);
	  ret[i][box_length (ret[i]) - 1] = 0;
	  BIO_free (bio_mem);
	}
      sk_X509_free (inf);
    }
  return (caddr_t) ret;
}

BIO *
strses_to_bio (dk_session_t * ses)
{
  BIO * in_bio;
  int len = strses_length (ses), to_read = len, readed = 0;
  char buf[4096];
  char err_buf[512];

  in_bio = BIO_new (BIO_s_mem ());
  CATCH_READ_FAIL (ses)
    {
      do {
	readed = session_buffered_read (ses, buf, MIN (sizeof (buf), to_read));
	if (readed && readed != BIO_write (in_bio, buf, readed))
	  sqlr_new_error ("42000", "CR003", "Can not write to BIO. SSL Error : %s", get_ssl_error_text (err_buf, sizeof (err_buf)));
	to_read -= readed;
      } while (to_read > 0);
    }
  END_READ_FAIL (ses);
  return in_bio;
}

dk_session_t * 
bio_to_strses (BIO * out_bio)
{
  dk_session_t * ses = strses_allocate ();
  char buf[4096], *to_free;
  char *ptr = NULL;
  int len = BIO_get_mem_data (out_bio, &ptr);
  int to_read = len, readed = 0;

  to_free = ((BUF_MEM *) out_bio->ptr)->data;
  BIO_set_flags (out_bio, BIO_FLAGS_MEM_RDONLY);
  CATCH_WRITE_FAIL (ses)
    {
      do {
	readed = BIO_read (out_bio, buf, MIN (sizeof (buf), to_read));
	if (readed > 0)
	  session_buffered_write (ses, buf, readed);
	to_read -= readed;
      } while (to_read > 0);
    }
  END_WRITE_FAIL (ses);
  ((BUF_MEM *) out_bio->ptr)->data = to_free;
  BIO_clear_flags (out_bio, BIO_FLAGS_MEM_RDONLY);
  return ses;
}

static caddr_t
bif_smime_verify (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t msg = bif_arg (qst, args, 0, "smime_verify");
  caddr_t certs = bif_array_arg (qst, args, 1, "smime_verify");
  int flags = 0;
  caddr_t ret = NULL;

  caddr_t err = NULL;
  BIO *out_bio = NULL, *in_bio = NULL, *data_bio = NULL;
  PKCS7 *p7 = NULL;
  X509_STORE *store = NULL;
  char * to_free = NULL;
  int res;
  char err_buf[512];

  if (BOX_ELEMENTS (args) > 3)
    flags = (int) bif_long_arg (qst, args, 3, "smime_verify");

  if (!IS_BOX_POINTER (msg) || (DV_TYPE_OF (msg) != DV_STRING && DV_TYPE_OF (msg) != DV_STRING_SESSION))
     msg = bif_string_arg (qst, args, 0, "smime_verify");

  store = smime_get_store_from_array (certs, &err);
  if (err)
    sqlr_resignal (err);
  if (!store)
    sqlr_new_error ("42000", "CR003", "No CA certificates. SSL Error : %s", get_ssl_error_text (err_buf, sizeof (err_buf)));
  if (DV_TYPE_OF (msg) == DV_STRING_SESSION)
    {
      in_bio = strses_to_bio ((dk_session_t *) msg);
      to_free = ((BUF_MEM *) in_bio->ptr)->data;
      BIO_set_flags (in_bio, BIO_FLAGS_MEM_RDONLY);
    }
  else
    in_bio = BIO_new_mem_buf (msg, box_length (msg) - 1);
  if (in_bio)
    {
      p7 = SMIME_read_PKCS7 (in_bio, &data_bio);
      if (to_free)
	{
	  ((BUF_MEM *) in_bio->ptr)->data = to_free;
	  BIO_clear_flags (in_bio, BIO_FLAGS_MEM_RDONLY);
	}
      BIO_free (in_bio);
    }

  if (!p7)
    {
      if (store)
	X509_STORE_free (store);
      if (data_bio)
	BIO_free (data_bio);
      sqlr_new_error ("42000", "CR004", "Cannot read PKCS7 attached signature. SSL Error : %s", get_ssl_error_text (err_buf, sizeof (err_buf)));
    }

  out_bio = BIO_new (BIO_s_mem ());
  if (!out_bio)
    {
      if (store)
	X509_STORE_free (store);
      if (data_bio)
	BIO_free (data_bio);
      if (p7)
	PKCS7_free (p7);
      sqlr_new_error ("42000", "CR005", "Cannot allocate output storage. SSL Error : %s", get_ssl_error_text (err_buf, sizeof (err_buf)));
    }

  res = PKCS7_verify (p7, NULL, store, data_bio, out_bio, flags);
  if (BOX_ELEMENTS (args) > 2 && ssl_is_settable (args[2]))
    qst_set (qst, args[2], pkcs7_signer_info_to_array (p7));

  PKCS7_free (p7);
  if (res)
    {
      char *ptr = NULL;
      int len = BIO_get_mem_data (out_bio, &ptr);
      if (len >= MAX_BOX_LENGTH)
	{
	  ret = (caddr_t) bio_to_strses (out_bio);
	}
      else
	{
	  ret = dk_alloc_box (len + 1, DV_SHORT_STRING);
	  memcpy (ret, ptr, box_length (ret) - 1);
	  ret[box_length (ret) - 1] = 0;
	}
    }

  BIO_free (out_bio);
  if (data_bio)
    BIO_free (data_bio);
  if (!ret)
    ret = dk_alloc_box (0, DV_DB_NULL);
  return ret;
}


static X509 *
x509_get_cert_from_buffer (caddr_t buffer)
{
  BIO *buf = BIO_new_mem_buf (buffer, box_length (buffer) - 1);
  X509 *cert = PEM_read_bio_X509 (buf, NULL, NULL, NULL);
  BIO_free (buf);
  return cert;
}


static int
virt_pem_password_cb (char *buf, int size, int rwflag, void *userdata)
{
  if (userdata && DV_STRINGP (userdata))
    {
      int length = box_length (userdata) - 1;
      if (length > size - 1)
	length = size - 1;
      memcpy (buf, userdata, length);
      buf[length] = 0;
      return length;
    }
  else
    {
      memset (buf, 0, size);
      return 0;
    }
}

static EVP_PKEY *
x509_get_pkey_from_buffer (caddr_t buffer, caddr_t password)
{
  BIO *buf = BIO_new_mem_buf (buffer, box_length (buffer) - 1);
  EVP_PKEY *pkey = PEM_read_bio_PrivateKey (buf, NULL, virt_pem_password_cb, password);
  BIO_free (buf);
  return pkey;
}


static caddr_t
bif_smime_sign (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t msg = bif_string_arg (qst, args, 0, "smime_sign");
  caddr_t signcert = bif_string_arg (qst, args, 1, "smime_sign");
  caddr_t privatekey = bif_string_arg (qst, args, 2, "smime_sign");
  caddr_t privatepass = bif_string_or_null_arg (qst, args, 3, "smime_sign");
  caddr_t scerts = bif_array_arg (qst, args, 4, "smime_sign");
  int flags = PKCS7_DETACHED;
  caddr_t ret = NULL;

  caddr_t err = NULL;
  BIO *out_bio = NULL, *in_bio = NULL;
  PKCS7 *p7 = NULL;
  X509_STORE *store = NULL;
  X509 *signer_cert = NULL;
  EVP_PKEY *signer_key = NULL;
  STACK_OF (X509) * certs = NULL;
  int inx;
  char err_buf[512];
  char *ptr = NULL;

  if (BOX_ELEMENTS (args) > 5)
    flags = (int) bif_long_arg (qst, args, 5, "smime_sign");
  store = smime_get_store_from_array (scerts, &err);
  if (err)
    sqlr_resignal (err);
  if (!store)
    sqlr_new_error ("42000", "CR006", "No CA certificates");

  signer_cert = x509_get_cert_from_buffer (signcert);
  if (!signer_cert)
    {
      if (store)
	X509_STORE_free (store);
      sqlr_new_error ("42000", "CR007", "Error reading the signer certificate. SSL error : %s", get_ssl_error_text (err_buf, sizeof (err_buf)));
    }

  signer_key = x509_get_pkey_from_buffer (privatekey, privatepass);
  if (!signer_key)
    {
      if (store)
	X509_STORE_free (store);
      X509_free (signer_cert);
      sqlr_new_error ("42000", "CR008", "Error reading the signer private key. SSL error : %s", get_ssl_error_text (err_buf, sizeof (err_buf)));
    }

  certs = sk_X509_new_null ();
  if (store && store->objs)
    {
      for (inx = 0; inx < sk_X509_OBJECT_num (store->objs); inx++)
	{
	  X509_OBJECT *obj = sk_X509_OBJECT_value (store->objs, inx);
	  if (obj->type == X509_LU_X509)
	    sk_X509_push (certs, X509_dup (obj->data.x509));
	}

    }
  if (store)
    X509_STORE_free (store);
  in_bio = BIO_new_mem_buf (msg, box_length (msg) - 1);
  if (in_bio)
    {
      p7 = PKCS7_sign (signer_cert, signer_key, certs, in_bio, flags);
      BIO_free (in_bio);
      in_bio = BIO_new_mem_buf (msg, box_length (msg) - 1);
    }
  X509_free (signer_cert);
  EVP_PKEY_free (signer_key);
  sk_X509_pop_free (certs, X509_free);

  if (!p7)
    {
      if (in_bio)
	BIO_free (in_bio);
      sqlr_new_error ("42000", "CR009", "Cannot generate PKCS7 signature. SSL error : %s", get_ssl_error_text (err_buf, sizeof (err_buf)));
    }

  out_bio = BIO_new (BIO_s_mem ());
  if (!out_bio)
    {
      if (p7)
	PKCS7_free (p7);
      if (in_bio)
	BIO_free (in_bio);
      sqlr_new_error ("42000", "CR010", "Cannot allocate output storage. SSL error : %s", get_ssl_error_text (err_buf, sizeof (err_buf)));
    }

  SMIME_write_PKCS7 (out_bio, p7, in_bio, flags);
  PKCS7_free (p7);
  BIO_free (in_bio);

  ret = dk_alloc_box (BIO_get_mem_data (out_bio, &ptr) + 1, DV_SHORT_STRING);
  memcpy (ret, ptr, box_length (ret) - 1);
  ret[box_length (ret) - 1] = 0;

  BIO_free (out_bio);
  return ret;
}

static caddr_t
bif_smime_encrypt (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char * me = "smime_encrypt";
  caddr_t msg = bif_string_arg (qst, args, 0, me);
  caddr_t scerts = bif_array_arg (qst, args, 1, me);
  caddr_t cipher_name = bif_string_arg (qst, args, 2, me);
  caddr_t ret = NULL;
  caddr_t err = NULL;
  BIO *out_bio = NULL, *in_bio = NULL;
  PKCS7 *p7 = NULL;
  X509_STORE *store = NULL;
  STACK_OF (X509) * certs = NULL;
  int inx;
  char err_buf[512];
  char *ptr = NULL;
  int flags = 0;
  const EVP_CIPHER *cipher = NULL;

  cipher = EVP_get_cipherbyname (cipher_name);
  if (!cipher)
    sqlr_new_error ("42000", "CR006", "Cannot find cipher");
  store = smime_get_store_from_array (scerts, &err);
  if (err)
    sqlr_resignal (err);
  if (!store)
    sqlr_new_error ("42000", "CR006", "No recipient certificates");

  certs = sk_X509_new_null ();
  if (store && store->objs)
    {
      for (inx = 0; inx < sk_X509_OBJECT_num (store->objs); inx++)
	{
	  X509_OBJECT *obj = sk_X509_OBJECT_value (store->objs, inx);
	  if (obj->type == X509_LU_X509)
	    sk_X509_push (certs, X509_dup (obj->data.x509));
	}
    }
  if (store)
    X509_STORE_free (store);
  in_bio = BIO_new_mem_buf (msg, box_length (msg) - 1);
  if (in_bio)
    {
      p7 = PKCS7_encrypt(certs, in_bio, cipher, flags);
      BIO_free (in_bio);
      in_bio = BIO_new_mem_buf (msg, box_length (msg) - 1);
    }
  sk_X509_pop_free (certs, X509_free);

  if (!p7)
    {
      if (in_bio)
	BIO_free (in_bio);
      sqlr_new_error ("42000", "CR009", "Cannot generate PKCS7 structure. SSL error : %s", get_ssl_error_text (err_buf, sizeof (err_buf)));
    }

  out_bio = BIO_new (BIO_s_mem ());
  if (!out_bio)
    {
      if (p7)
	PKCS7_free (p7);
      if (in_bio)
	BIO_free (in_bio);
      sqlr_new_error ("42000", "CR010", "Cannot allocate output storage. SSL error : %s", get_ssl_error_text (err_buf, sizeof (err_buf)));
    }

  SMIME_write_PKCS7 (out_bio, p7, in_bio, flags);
  PKCS7_free (p7);
  BIO_free (in_bio);

  ret = dk_alloc_box (BIO_get_mem_data (out_bio, &ptr) + 1, DV_SHORT_STRING);
  memcpy (ret, ptr, box_length (ret) - 1);
  ret[box_length (ret) - 1] = 0;

  BIO_free (out_bio);
  return ret;
}

static caddr_t
bif_smime_decrypt (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char * me = "smime_decrypt";
  caddr_t msg = bif_string_arg (qst, args, 0, me);
  caddr_t cert = bif_string_arg (qst, args, 1, me);
  caddr_t privatekey = bif_string_arg (qst, args, 2, me);
  caddr_t privatepass = bif_string_or_null_arg (qst, args, 3, me);
  int flags = 0;
  caddr_t ret = NULL;
  BIO *out_bio = NULL, *in_bio = NULL, *data_bio = NULL;
  PKCS7 *p7 = NULL;
  X509 *recip_cert = NULL;
  EVP_PKEY *recip_key = NULL;
  int rc;
  char err_buf[512];
  char *ptr = NULL;

  recip_cert = x509_get_cert_from_buffer (cert);
  if (!recip_cert)
    {
      sqlr_new_error ("42000", "CR007", "Error reading the recipient certificate. SSL error : %s", get_ssl_error_text (err_buf, sizeof (err_buf)));
    }

  recip_key = x509_get_pkey_from_buffer (privatekey, privatepass);
  if (!recip_key)
    {
      X509_free (recip_cert);
      sqlr_new_error ("42000", "CR008", "Error reading the recipient private key. SSL error : %s", get_ssl_error_text (err_buf, sizeof (err_buf)));
    }

  in_bio = BIO_new_mem_buf (msg, box_length (msg) - 1);
  if (in_bio)
    {
      p7 = SMIME_read_PKCS7 (in_bio, &data_bio);
      BIO_free (in_bio);
    }
  if (!p7)
    {
      X509_free (recip_cert);
      EVP_PKEY_free (recip_key);
      if (data_bio) BIO_free (data_bio);
      sqlr_new_error ("42000", "CR004", "Cannot read PKCS7 attached signature. SSL Error : %s", get_ssl_error_text (err_buf, sizeof (err_buf)));
    }
  out_bio = BIO_new (BIO_s_mem ());
  if (!out_bio)
    {
      X509_free (recip_cert);
      EVP_PKEY_free (recip_key);
      PKCS7_free (p7);
      if (data_bio) BIO_free (data_bio);
      sqlr_new_error ("42000", "CR010", "Cannot allocate output storage. SSL error : %s", get_ssl_error_text (err_buf, sizeof (err_buf)));
    }

  rc = PKCS7_decrypt(p7, recip_key, recip_cert, out_bio, flags);

  X509_free (recip_cert);
  EVP_PKEY_free (recip_key);

  if (rc)
    {
      ret = dk_alloc_box (BIO_get_mem_data (out_bio, &ptr) + 1, DV_SHORT_STRING);
      memcpy (ret, ptr, box_length (ret) - 1);
      ret[box_length (ret) - 1] = 0;
    }
  else
    ret = NEW_DB_NULL;

  PKCS7_free (p7);
  if (data_bio) BIO_free (data_bio);
  BIO_free (out_bio);
  return ret;
}


static caddr_t
bif_pem_certificates_to_array (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t buf = bif_string_arg (qst, args, 0, "certificates_to_array");
  caddr_t *ret = NULL;
  BIO *in = NULL;
  STACK_OF (X509_INFO) * inf = NULL;
  X509_INFO *itmp = NULL;
  int i, count = 0;
  char err_buf[512], *ptr;

  in = BIO_new_mem_buf (buf, box_length (buf) - 1);
  if (!in)
    {
      sqlr_new_error ("42000", "CR011", "Cannot allocate temp space. SSL error : %s", get_ssl_error_text (err_buf, sizeof (err_buf)));
      return 0;
    }
  inf = PEM_X509_INFO_read_bio (in, NULL, NULL, NULL);
  BIO_free (in);
  if (!inf)
    {
      sqlr_new_error ("42000", "CR012", "Cannot read certificates. SSL error : %s", get_ssl_error_text (err_buf, sizeof (err_buf)));
      return 0;
    }

  in = BIO_new (BIO_s_mem ());
  ret = (caddr_t *) dk_alloc_box_zero (sk_X509_INFO_num (inf) * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  for (i = 0; i < sk_X509_INFO_num (inf); i++)
    {
      itmp = sk_X509_INFO_value (inf, i);
      if (itmp->x509)
	{
	  BIO_reset (in);
	  PEM_write_bio_X509 (in, itmp->x509);
	  ret[i] = dk_alloc_box (BIO_get_mem_data (in, &ptr) + 1, DV_SHORT_STRING);
	  memcpy (ret[i], ptr, box_length (ret[i]) - 1);
	  ret[i][box_length (ret[i]) - 1] = 0;
	  count++;
	}
    }
  BIO_free (in);
  sk_X509_INFO_pop_free (inf, X509_INFO_free);
  return (caddr_t) ret;
}


static int
x509_certificate_verify_cb (int ok, X509_STORE_CTX * ctx)
{
  char *opts = (char *) X509_STORE_CTX_get_app_data (ctx);
  if (!ok && opts)
    {
      switch (ctx->error)
	{
	case X509_V_ERR_CERT_HAS_EXPIRED:
	  if (strstr (opts, "expired"))
	    ok = 1;
	  break;
	case X509_V_ERR_DEPTH_ZERO_SELF_SIGNED_CERT:
	  if (strstr (opts, "self-signed"))
	    ok = 1;
	  break;
	case X509_V_ERR_INVALID_CA:
	  if (strstr (opts, "invalid-ca"))
	    ok = 1;
	  break;
	case X509_V_ERR_INVALID_PURPOSE:
	  if (strstr (opts, "invalid-purpose"))
	    ok = 1;
	  break;
#if defined(X509_V_ERR_UNHANDLED_CRITICAL_EXTENSION)
	case X509_V_ERR_UNHANDLED_CRITICAL_EXTENSION:
	  if (strstr (opts, "unhandled-extension"))
	    ok = 1;
	  break;
#endif
	}
    }
  return ok;
}


static caddr_t
bif_x509_certificate_verify (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  X509 *cert = NULL, *cacert = NULL;
  caddr_t scert = bif_string_arg (qst, args, 0, "x509_certificate_verify");
  caddr_t array = bif_strict_array_or_null_arg (qst, args, 1, "x509_certificate_verify");
  BIO *mem_bio = BIO_new_mem_buf (scert, box_length (scert) - 1);
  X509_STORE *cert_ctx = NULL;
  X509_STORE_CTX *csc = NULL;
  STACK_OF (X509) * uchain = NULL;
  caddr_t opts = BOX_ELEMENTS (args) > 2 ? bif_string_arg (qst, args, 2, "x509_certificate_verify") : NULL;
  int i, inx;

  cert = d2i_X509_bio (mem_bio, NULL);
  BIO_free (mem_bio);

  if (!cert)
    {
      *err_ret = srv_make_new_error ("22023", "CR014", "Invalid certificate");
      goto err_ret;
    }

  if (NULL == (cert_ctx = X509_STORE_new ()))
    {
      *err_ret = srv_make_new_error ("22023", "CR016", "Can not allocate a X509 store");
      goto err_ret;
    }

  X509_STORE_set_verify_cb_func (cert_ctx, x509_certificate_verify_cb);

  DO_BOX (caddr_t, ca, inx, ((caddr_t *) array))
  {
    mem_bio = BIO_new_mem_buf (ca, box_length (ca) - 1);
    cacert = d2i_X509_bio (mem_bio, NULL);
    BIO_free (mem_bio);
    if (!cacert)
      {
	*err_ret = srv_make_new_error ("22023", "CR019", "Invalid CA certificate");
	goto err_ret;
      }
    X509_STORE_add_cert (cert_ctx, cacert);
  }
  END_DO_BOX;

  if (NULL == (csc = X509_STORE_CTX_new ()))
    {
      *err_ret = srv_make_new_error ("22023", "CR017", "Can not allocate X509 verification context");
      goto err_ret;
    }

#if (OPENSSL_VERSION_NUMBER < 0x00907000L)
  X509_STORE_CTX_init (csc, cert_ctx, cert, uchain);
#else
  if (!X509_STORE_CTX_init (csc, cert_ctx, cert, uchain))
    {
      *err_ret = srv_make_new_error ("22023", "CR018", "Can not initialize X509 verification context");
      goto err_ret;
    }
#endif

  X509_STORE_CTX_set_app_data (csc, (void *) opts);

  i = X509_verify_cert (csc);

  if (!i)
    {
      const char *err_str;
      err_str = X509_verify_cert_error_string (csc->error);
      *err_ret = srv_make_new_error ("22023", "CR015", "X509 error: %s", err_str);
    }

err_ret:
  if (csc)
    X509_STORE_CTX_free (csc);
  sk_X509_pop_free (uchain, X509_free);
  if (cert_ctx != NULL)
    X509_STORE_free (cert_ctx);
  if (cert)
    X509_free (cert);
  if (cacert)
    X509_free (cacert);
  return NULL;

}

#define VIRT_CERT_EXT "2.16.840.1.1113.1"

static caddr_t
BN_box (BIGNUM * x)
{
  size_t buf_len, n;
  caddr_t buf;
  buf_len = (size_t) BN_num_bytes (x);
  if (buf_len <= BN_BYTES)
    buf = box_num ((unsigned long) x->d[0]);
  else
    {
      buf = dk_alloc_box (buf_len, DV_BIN);
      n = BN_bn2bin (x, (unsigned char *) buf);
      if (n != buf_len)
	GPF_T;
    }
  return buf;
}

/*
   1 - info type
   2 - certificate
   3 - certifcate file type (1 - DER, 2 - PKCS12, 0 - PEM, 3 - internal key name)
   4 - password to open pkcs12 bundle
   5 - extension OID (7); attribute e.g. CN (10)
*/
static caddr_t
bif_get_certificate_info (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;
  SSL *ssl = NULL;
  X509 *cert = NULL;
  caddr_t ret = NULL;
  long input_type = 0;
  long type = bif_long_arg (qst, args, 0, "get_certificate_info");
  caddr_t scert = BOX_ELEMENTS (args) > 1 ? bif_string_or_null_arg (qst, args, 1, "get_certificate_info") : NULL;
  int internal = 0;
  char buffer[4096];

  if (qi->qi_client->cli_ws)
    ssl = (SSL *) tcpses_get_ssl (qi->qi_client->cli_ws->ws_session->dks_session);
  else if (qi->qi_client->cli_session && qi->qi_client->cli_session->dks_session)
    ssl = (SSL *) tcpses_get_ssl (qi->qi_client->cli_session->dks_session);

  if (scert != NULL && BOX_ELEMENTS (args) > 1)
    {
      BIO *mem_bio = BIO_new_mem_buf (scert, box_length (scert) - 1);

      if (BOX_ELEMENTS (args) > 2)
	{					 /* input type: 1 - X509, 2 - PKCS12, 0 - PEM, 3 - by key name */
	  input_type = bif_long_arg (qst, args, 2, "get_certificate_info");
	}

      if (input_type == 1)
	{
	  cert = d2i_X509_bio (mem_bio, NULL);
	}
      else if (input_type == 2)
	{
	  PKCS12 *pk12 = NULL;
	  EVP_PKEY *pkey = NULL;
	  STACK_OF (X509) * ca_list = NULL;
	  char *pass = bif_string_or_null_arg (qst, args, 3, "get_certificate_info");

	  pk12 = d2i_PKCS12_bio (mem_bio, NULL);
	  PKCS12_parse (pk12, pass, &pkey, &cert, &ca_list);	/*TODO: check whether pkey & brothers needs to be freed */
	}
      else if (input_type == 3)
	{
	  xenc_key_t *k = xenc_get_key_by_name (scert, 1);
	  cert = k ? k->xek_x509 : NULL;
	  internal = 1;
	}
      else
	cert = PEM_read_bio_X509 (mem_bio, NULL, NULL, NULL);
      BIO_free (mem_bio);
    }
  else
    {
      if (!ssl)
	sqlr_new_error ("22023", "SR309", "Non-encrypted session");
      cert = SSL_get_peer_certificate (ssl);
    }
  if (!cert)
    return dk_alloc_box (0, DV_DB_NULL);

  ret = NULL;
  switch (type)
    {
    case 1:					 /* Serial number */
      {
	ASN1_INTEGER *ai = X509_get_serialNumber (cert);
	BIGNUM *n = ASN1_INTEGER_to_BN (ai, NULL);
	char *dec = BN_bn2dec (n);
	size_t len = strlen (dec);
	ret = dk_alloc_box (len + 1, DV_STRING);
	memcpy (ret, dec, len);
	ret[len] = 0;
	BN_free (n);
	OPENSSL_free (dec);
	break;
      }
    case 2:					 /* Subject */
      {
	X509_NAME *subj = X509_get_subject_name (cert);
	if (subj)
	  {
	    X509_NAME_oneline (subj, buffer, sizeof (buffer));
	    ret = box_dv_short_string (buffer);
	    break;
	  }
	break;
      }
    case 3:					 /* Issuer */
      {
	X509_NAME *subj = X509_get_issuer_name (cert);
	if (subj)
	  {
	    X509_NAME_oneline (subj, buffer, sizeof (buffer));
	    ret = box_dv_short_string (buffer);
	    break;
	  }
	break;
      }
    case 4:					 /* not before */
      {
	int len;
	char *data_ptr;
	BIO *mem = BIO_new (BIO_s_mem ());
	ASN1_TIME_print (mem, X509_get_notBefore (cert));
	len = BIO_get_mem_data (mem, &data_ptr);
	if (len > 0 && data_ptr)
	  {
	    ret = dk_alloc_box (len + 1, DV_SHORT_STRING);
	    memcpy (ret, data_ptr, len);
	    ret[len] = 0;
	  }
	BIO_free (mem);
	break;
      }
    case 5:					 /* not after */
      {
	int len;
	char *data_ptr;
	BIO *mem = BIO_new (BIO_s_mem ());
	ASN1_TIME_print (mem, X509_get_notAfter (cert));
	len = BIO_get_mem_data (mem, &data_ptr);
	if (len > 0 && data_ptr)
	  {
	    ret = dk_alloc_box (len + 1, DV_SHORT_STRING);
	    memcpy (ret, data_ptr, len);
	    ret[len] = 0;
	  }
	BIO_free (mem);
	break;
      }
    case 6:
      {
	const EVP_MD *digest = EVP_md5 ();
	int j;
	unsigned int n;
	unsigned char md[EVP_MAX_MD_SIZE];
	char tmp[4];
	char *digest_name = (char *) (BOX_ELEMENTS (args) > 4 ? bif_string_or_null_arg (qst, args, 4, "get_certificate_info") : NULL);

	if (digest_name)
	  {
	    digest = EVP_get_digestbyname (digest_name);
	    if (!digest)
	      sqlr_new_error ("22023", "SR...", "Can not find digest %s", digest_name);
	  }

	if (!X509_digest (cert, digest, md, &n))
	  {
	    sqlr_new_error ("22023", "SR...", "The certificate fingerprint cannot be made");
	  }
	ret = dk_alloc_box_zero (n * 3, DV_STRING);
	for (j = 0; j < (int) n; j++)
	  {
	    if (j + 1 < (int) n)
	      snprintf (tmp, sizeof (tmp), "%02X:", md[j]);
	    else
	      snprintf (tmp, sizeof (tmp), "%02X", md[j]);
	    strcat_box_ck (ret, tmp);
	  }
	break;
      }
    case 7:					 /* default private extension: sqlUserName */
      {
	int i;
	char tmp[1024];
	char *ext_oid = (char *) (BOX_ELEMENTS (args) > 4 ? bif_string_arg (qst, args, 4, "get_certificate_info") : VIRT_CERT_EXT);
	STACK_OF (X509_EXTENSION) * exts = cert->cert_info->extensions;
	for (i = 0; i < sk_X509_EXTENSION_num (exts); i++)
	  {
	    X509_EXTENSION *ex = sk_X509_EXTENSION_value (exts, i);
	    ASN1_OBJECT *obj = X509_EXTENSION_get_object (ex);
	    OBJ_obj2txt (tmp, sizeof (tmp), obj, 1);
	    if (!strcmp (tmp, ext_oid))
	      {
		int len;
		char *data_ptr;
		BIO *mem = BIO_new (BIO_s_mem ());
		if (!X509V3_EXT_print (mem, ex, 0, 0))
		  M_ASN1_OCTET_STRING_print (mem, ex->value);
		len = BIO_get_mem_data (mem, &data_ptr);
		if (len > 0 && data_ptr)
		  {
		    ret = dk_alloc_box (len + 1, DV_STRING);
		    memcpy (ret, data_ptr, len);
		    ret[len] = 0;
		  }
		BIO_free (mem);
	      }
	  }
	break;
      }
    case 8:					 /* Certificate name  */
      {
	caddr_t KI = NULL;
	KI = xenc_x509_KI_base64 (cert);
	ret = xenc_get_keyname_by_ki (KI);
	dk_free_box (KI);
	break;
      }
    case 9:					 /* certificate public key */
      {
	EVP_PKEY *k = X509_get_pubkey (cert);
	if (k)
	  {
#ifdef EVP_PKEY_RSA
	    if (k->type == EVP_PKEY_RSA)
	      {
		RSA *x = k->pkey.rsa;
		ret = list (3, box_dv_short_string ("RSAPublicKey"), BN_box (x->e), BN_box (x->n));
	      }
	    else
#endif
#ifdef EVP_PKEY_DSA
	    if (k->type == EVP_PKEY_DSA)
	      {
		DSA *x = k->pkey.dsa;
		ret = list (2, box_dv_short_string ("DSAPublicKey"), BN_box (x->pub_key));
	      }
	    else
#endif
	      *err_ret = srv_make_new_error ("42000", "XXXXX", "The certificate's public key not supported");
	    EVP_PKEY_free (k);
	  }
	else
	  *err_ret = srv_make_new_error ("42000", "XXXXX", "Can not read the public key from the certificate");
	break;
      }
    case 10:
      {
	char *attr = BOX_ELEMENTS (args) > 4 ? bif_string_arg (qst, args, 4, "get_certificate_info") : "CN";
	X509_NAME *subj = X509_get_subject_name (cert);
	X509_NAME_ENTRY *ne, *ne_ret = NULL;
	int n, i, len;
	char *s, *data_ptr;
	BIO *mem = BIO_new (BIO_s_mem ());
	for (i = 0; NULL != subj && i < sk_X509_NAME_ENTRY_num(subj->entries); i++)
	  {
	    ne = sk_X509_NAME_ENTRY_value(subj->entries,i);
	    n = OBJ_obj2nid (ne->object);
	    if ((n == NID_undef) || ((s = OBJ_nid2sn (n)) == NULL))
	      {
		i2t_ASN1_OBJECT (buffer, sizeof (buffer), ne->object);
		s = buffer;
	      }
	    if (!strcmp (s, attr))
	      {
		ne_ret = ne;
		break;
	      }
	  }
	if (ne_ret)
	  {
	    ASN1_STRING_print (mem, ne_ret->value);
	    len = BIO_get_mem_data (mem, &data_ptr);
	    if (len > 0 && data_ptr)
	      {
		ret = dk_alloc_box (len + 1, DV_SHORT_STRING);
		memcpy (ret, data_ptr, len);
		ret[len] = 0;
	      }
	  }
	BIO_free (mem);
	break;
      }
    case 11:
      {
	X509_NAME *subj = X509_get_subject_name (cert);
	X509_NAME_ENTRY *ne;
	int n, i, len;
	char *s, *data_ptr;
	dk_set_t set = NULL; 
	caddr_t val;
	BIO *mem = BIO_new (BIO_s_mem ());
	for (i = 0; NULL != subj && i < sk_X509_NAME_ENTRY_num(subj->entries); i++)
	  {
	    val = NULL;
	    ne = sk_X509_NAME_ENTRY_value(subj->entries,i);
	    n = OBJ_obj2nid (ne->object);
	    if ((n == NID_undef) || ((s = OBJ_nid2sn (n)) == NULL))
	      {
		i2t_ASN1_OBJECT (buffer, sizeof (buffer), ne->object);
		s = buffer;
	      }
	    ASN1_STRING_print (mem, ne->value);
	    len = BIO_get_mem_data (mem, &data_ptr);
	    if (len > 0 && data_ptr)
	      {
		val = dk_alloc_box (len + 1, DV_SHORT_STRING);
		memcpy (val, data_ptr, len);
		val[len] = 0;
	      }
	    dk_set_push (&set, box_dv_short_string (s));
	    dk_set_push (&set, val ? val : NEW_DB_NULL);
	    BIO_reset (mem);
	  }
	BIO_free (mem);
	ret = list_to_array (dk_set_nreverse (set));
	break;
      }
    default:
      {
	if (!internal)
	  X509_free (cert);
	sqlr_new_error ("22023", "SR310", "Invalid certificate info index %ld", type);
      }
    }
  if (!internal)
    X509_free (cert);
  return ret ? ret : dk_alloc_box (0, DV_DB_NULL);
}


static caddr_t
bif_bin2hex (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t bin = bif_bin_arg (qst, args, 0, "bin2hex");
  caddr_t out = dk_alloc_box (2 * box_length (bin) + 1, DV_SHORT_STRING);
  uint32 inx;
  char tmp[3];
  out[0] = 0;
  for (inx = 0; inx < box_length (bin); inx++)
    {
      snprintf (tmp, sizeof (tmp), "%02x", (unsigned char) bin[inx]);
      strcat_box_ck (out, tmp);
    }
  out[2 * box_length (bin)] = 0;
  return out;
}

static caddr_t
bif_hex2bin (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t str = bif_string_arg (qst, args, 0, "hex2bin");
  caddr_t out;
  uint32 inx, len = box_length (str) - 1;
  unsigned int tmp;

  if (!len)
    return NEW_DB_NULL;
  if (len % 2)
    sqlr_new_error ("22023", "ENC..", "The input string must have a length multiple by two");
  out = dk_alloc_box (len / 2, DV_BIN);
  out[0] = 0;
  for (inx = 0; inx < len; inx += 2)
    {
      if (1 != sscanf (str+inx, "%02x", &tmp))
	{
	  dk_free_box (out);
	  sqlr_new_error ("22023", "ENC..", "The input string does not contains hexadecimal string");
	}
      out [inx/2] = (unsigned char) tmp;
    }
  return out;
}


static caddr_t
bif_sha1_digest (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t data = (caddr_t) bif_string_arg (qst, args, 0, "sha1");
  unsigned char md[SHA_DIGEST_LENGTH], md64[SHA_DIGEST_LENGTH * 2 + 1];
  int len;
  SHA_CTX ctx;

  SHA1_Init (&ctx);
  SHA1_Update (&ctx, data, box_length (data) - 1);
  SHA1_Final (&(md[0]), &ctx);
  len = xenc_encode_base64 ((char *) md, (char *) md64, SHA_DIGEST_LENGTH);
  md64[len] = 0;
  return box_dv_short_string ((char *) md64);
}

void
bif_crypto_init (void)
{
  bif_define_typed ("tree_sha1", bif_tree_sha1, &bt_varchar);
  bif_define_typed ("sha1_digest", bif_sha1_digest, &bt_varchar);
  bif_define_typed ("asn1_to_xml", bif_asn1_to_xml, &bt_varchar);
  bif_define_typed ("tree_hmac", bif_tree_hmac, &bt_varchar);
  bif_define_typed ("smime_verify", bif_smime_verify, &bt_varchar);
  bif_define_typed ("smime_sign", bif_smime_sign, &bt_varchar);
  bif_define_typed ("smime_encrypt", bif_smime_encrypt, &bt_varchar);
  bif_define_typed ("smime_decrypt", bif_smime_decrypt, &bt_varchar);
  bif_define_typed ("pem_certificates_to_array", bif_pem_certificates_to_array, &bt_any);
  bif_define_typed ("get_certificate_info", bif_get_certificate_info, &bt_any);
  bif_define_typed ("x509_certificate_verify", bif_x509_certificate_verify, &bt_any);
  bif_define_typed ("bin2hex", bif_bin2hex, &bt_varchar);
  bif_define_typed ("hex2bin", bif_hex2bin, &bt_bin);
}

#else /* _SSL dummy section for bifs that are defined here to not break existing apps */

static caddr_t
bif_get_certificate_info (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return dk_alloc_box (0, DV_DB_NULL);
}


static caddr_t
bif_smime_verify (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t msg = bif_string_arg (qst, args, 0, "smime_verify");
  return box_copy (msg);
}


void
bif_crypto_init (void)
{
  bif_define_typed ("smime_verify", bif_smime_verify, &bt_varchar);
  bif_define_typed ("smime_sign", bif_smime_verify, &bt_varchar);
  bif_define_typed ("pem_certificates_to_array", bif_get_certificate_info, &bt_any);
  bif_define_typed ("get_certificate_info", bif_get_certificate_info, &bt_any);
}
#endif

