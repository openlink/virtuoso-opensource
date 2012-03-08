/*
 *  xmlenc-dec.c
 *
 *  XML Encryption spec part 2 - decryption
 *
 *  $Id$
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

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif


#ifdef _SSL

#include "wi.h"
#include "sqlnode.h"
#include "sqlbif.h"
#include "xml.h"
#include "xmlgen.h"
#include "xmltree.h"
#include "xmlenc.h"
#include "xml_ecm.h"
#include "soap.h"
#include "security.h"
#include "date.h"
#include "bif_text.h"

#ifdef DEBUG
#include "xmlenc_test.h"
#endif


#define WSSE_UNKNOWN_CODE			"000"
#define WSSE_UNKNOWN_ERR			"unknown error"

#define WSSE_NO_ALGORITHM_CODE			"100"
#define WSSE_NO_ALGORITHM_ERR			"no algorithm specified"

#define WSSE_UNKNOWN_DIGEST_ALGORITHM_CODE	"101"
#define WSSE_UNKNOWN_DIGEST_ALGORITHM_ERR	"unknown digest algorithm %s"

#define WSSE_DIGEST_VALUE_UNINIT_CODE		"102"
#define WSSE_DIGEST_VALUE_UNINIT_ERR		"digest value is not specified"

#define WSSE_EMPTY_XPATH_EXPRESSION_CODE	"104"
#define WSSE_EMPTY_XPATH_EXPRESSION_ERR		"no XPath expression specified"

#define WSSE_EMPTY_SIGNATURE_VALUE_CODE		"105"
#define WSSE_EMPTY_SIGNATURE_VALUE_ERR		"signature value is not specified"

#define WSSE_CALLBACK_NOT_FOUND_CODE		"106"
#define WSSE_CALLBACK_NOT_FOUND_ERR		"tag is unknown %s"

#define WSSE_UNKNOWN_URI_CODE			"107"
#define WSSE_UNKNOWN_URI_ERR			"unknown namespace in security xml"

#define WSSE_UNKNOWN_CANON_ALGORITHM_CODE	"108"
#define WSSE_UNKNOWN_CANON_ALGORITHM_ERR	"unknown canonicalization algorithm %s"

#define WSSE_UNKNOWN_SIGN_ALGORITHM_CODE	"109"
#define WSSE_UNKNOWN_SIGN_ALGORITHM_ERR		"unknown signature algorithm %s"

#define WSSE_NO_TAG_CODE			"110"
#define WSSE_NO_TAG_ERR				"desired tag %s is not presented"

#define WSSE_ALGO_CODE				"111"
#define WSSE_ALGO_ERR				"algorithm %s internal error (key is not private?)"

#define WSSE_WRONG_SIGNVAL_CODE			"112"
#define WSSE_WRONG_SIGNVAL_ERR			"signature has wrong SignValue"

#define WSSE_EMPTY_CVAL_VALUE_CODE		"113"
#define WSSE_EMPTY_CVAL_VALUE_ERR		"no cipher value specified"

#define WSSE_NO_URI_CODE			"114"
#define WSSE_NO_URI_ERR				"no URI specified"

#define WSSE_EMPTYNAME_CODE			"115"
#define WSSE_EMPTYNAME_ERR			"no key name specified"

#define WSSE_NO_ENC_KEY				"116"
#define WSSE_CORRUPTED_ENC_KEY			"117"
#define WSSE_XML_CODE				"118"
#define WSSE_EMPTY_RSA_MODULUS_CODE		"119"
#define WSSE_EMPTY_RSA_EXPONENT_CODE		"120"
#define WSSE_UNKNOWN_KEY_CODE			"121"
#define WSSE_WRONG_KEY_CODE			"122"
#define WSSE_UNENCRYPTED_KEY_CODE		"123"
#define WSSE_ALGO_EMPTY_KEY_CODE		"124"
#define WSSE_UNRESOLVED_REF_URIS_CODE		"125"
#define WSSE_UNRESOLVED_REF_URI_CODE		"126"
#define WSSE_ENCKEY_REF_URI_NO_KEYINFO_CODE	"127"
#define WSSE_ENCKEY_REF_URI_NO_KEYNAME_CODE	"128"
#define WSSE_ENCKEY_REF_URI_EMPTY_KEYNAME_CODE	"129"
#define WSSE_BINARYSECTOKEN_CODE		"130"
#define WSSE_BINARYSECTOKENVALTYPE_CODE		"131"
#define WSSE_BINARYSECTOKENREF_CODE		"132"

struct wsse_error_templ_s
{
  char *		code;
  char *		templ;
} wsse_error_templs[] =
  {
    { WSSE_UNKNOWN_CODE, WSSE_UNKNOWN_ERR},
    { WSSE_NO_ALGORITHM_CODE, WSSE_NO_ALGORITHM_ERR },
    { WSSE_UNKNOWN_DIGEST_ALGORITHM_CODE, WSSE_UNKNOWN_DIGEST_ALGORITHM_ERR },
    { WSSE_DIGEST_VALUE_UNINIT_CODE, WSSE_DIGEST_VALUE_UNINIT_ERR },
    { WSSE_EMPTY_XPATH_EXPRESSION_CODE, WSSE_EMPTY_XPATH_EXPRESSION_ERR},
    { WSSE_EMPTY_SIGNATURE_VALUE_CODE, WSSE_EMPTY_SIGNATURE_VALUE_ERR},
    { WSSE_CALLBACK_NOT_FOUND_CODE, WSSE_CALLBACK_NOT_FOUND_ERR},
    { WSSE_UNKNOWN_URI_CODE, WSSE_UNKNOWN_URI_ERR},
    { WSSE_UNKNOWN_CANON_ALGORITHM_CODE, WSSE_UNKNOWN_CANON_ALGORITHM_ERR },
    { WSSE_UNKNOWN_SIGN_ALGORITHM_CODE, WSSE_UNKNOWN_SIGN_ALGORITHM_ERR },
    { WSSE_NO_TAG_CODE, WSSE_NO_TAG_ERR},
    { WSSE_ALGO_CODE, WSSE_ALGO_ERR},
    { WSSE_WRONG_SIGNVAL_CODE, WSSE_WRONG_SIGNVAL_ERR},
    { WSSE_EMPTY_CVAL_VALUE_CODE, WSSE_EMPTY_CVAL_VALUE_ERR},
    { WSSE_NO_URI_CODE, WSSE_NO_URI_ERR},
    { WSSE_EMPTYNAME_CODE, WSSE_EMPTYNAME_ERR},
    { WSSE_NO_ENC_KEY, "no encrypted key restored" },
    { WSSE_CORRUPTED_ENC_KEY, "encrypted key restored with error at %s" },
    { WSSE_XML_CODE, "could not parser signature xml" },
    { WSSE_EMPTY_RSA_MODULUS_CODE, "RSA modulus is empty" },
    { WSSE_EMPTY_RSA_EXPONENT_CODE, "RSA exponent is empty" },
    { WSSE_UNKNOWN_KEY_CODE, "key %s is unknown"},
    { WSSE_WRONG_KEY_CODE, "key %s could not be used by method %s"},
    { WSSE_UNENCRYPTED_KEY_CODE, "Unencrypted key declaration is not allowed"},
    { WSSE_ALGO_EMPTY_KEY_CODE, "algorithm %s internal error (no key provided?)"},
    { WSSE_UNRESOLVED_REF_URIS_CODE, "document contains unresolved references to encrypted data"},
    { WSSE_UNRESOLVED_REF_URI_CODE, "reference %s to encrypted data is unresolved"},
    { WSSE_ENCKEY_REF_URI_NO_KEYINFO_CODE, "EncryptedData does not contain key info [%s]"},
    { WSSE_ENCKEY_REF_URI_NO_KEYNAME_CODE, "EncryptedData/KeyInfo does not contain key name [%s]"},
    { WSSE_ENCKEY_REF_URI_EMPTY_KEYNAME_CODE, "EncryptedData/KeyInfo/KeyName is empty [%s]"},
    { WSSE_BINARYSECTOKEN_CODE, "error in BinarySecurityToken tag: %s"},
    { WSSE_BINARYSECTOKENVALTYPE_CODE, "error in SecurityTokenReference tag: value type %s is not supported"},
    { WSSE_BINARYSECTOKENREF_CODE, "Unknown binary security token referenced by key identifier %s"}
  };

ptrlong wsse_error_templs_len = sizeof (wsse_error_templs) / sizeof (struct wsse_error_templ_s);


#define XML_ELEMENT_NAME(x) \
  ((char *)( ((x) && DV_TYPE_OF (x) == DV_ARRAY_OF_POINTER && ((caddr_t *)(x))[0] && ((caddr_t **)(x))[0][0]) ? ((caddr_t **)(x))[0][0] : NULL))

#define XML_ELEMENT_ATTR_COUNT(x) \
    ( \
      ( \
	(x) && \
	DV_TYPE_OF (x) == DV_ARRAY_OF_POINTER && \
	((caddr_t *)x)[0] && \
	DV_TYPE_OF (((caddr_t *)x)[0]) == DV_ARRAY_OF_POINTER \
      ) \
      ? \
      (BOX_ELEMENTS (((caddr_t *)x)[0]) - 1) / 2 \
      : \
      0 \
    )

#define XML_ELEMENT_ATTR_NAME(x, n) \
    ( \
      XML_ELEMENT_ATTR_COUNT(x) >= n \
      ? \
      ((caddr_t **)x)[0][n * 2 + 1] \
      : \
      NULL \
    )

#define XML_ELEMENT_ATTR_VALUE(x, n) \
    ( \
      XML_ELEMENT_ATTR_COUNT(x) >= n \
      ? \
      ((caddr_t **)x)[0][n * 2 + 2] \
      : \
      NULL \
    )

#define XML_ELEMENT_CHILD(x, n) \
  ( ((x) && DV_TYPE_OF (x) == DV_ARRAY_OF_POINTER && BOX_ELEMENTS (x) > (n + 1) && \
     ((caddr_t *)(x))[n + 1]) ? \
       ((caddr_t **)(x))[n + 1] : \
       NULL)

/* temp declarations */
/* http.c */
int decode_base64 (char *src, char *end);
/* xmlenc_algos.c */
int xenc_decode_base64 (char *src, char *end);


static void __dbg_wsse_assert (char * file, long line)
{
  char buf[1024];
  snprintf (buf, sizeof (buf), "WSSE Assert failed at %s:%ld", file, line);
  GPF_T1 (buf);
}

#define WSSE_ASSERT(check) if (!check) __dbg_wsse_assert (__FILE__, __LINE__)

wsse_ctx_t * wsse_ctx_allocate ()
{
  NEW_VARZ (wsse_ctx_t, ctx);
  ctx->wc_id_cache = id_hash_allocate (31, sizeof (caddr_t), sizeof (caddr_t*),
					strhash, strhashcmp);
  return ctx;
}

void wsse_ctx_free (wsse_ctx_t * ctx)
{
  if (ctx->wc_dsig)
    dsig_free (ctx->wc_dsig);
  if (ctx->wc_dec)
    {
      DO_SET (xenc_enc_key_t*, ek, &ctx->wc_dec->xed_keys)
	{
	  caddr_t *tree;
	  dk_free_box (ek->xeke_name);
	  dk_free_box (ek->xeke_enc_method);
	  dk_free_box (ek->xeke_super_key);
	  dk_free_box (ek->xeke_carried_key_name);
	  dk_free_box (ek->xeke_cipher_value);
#if 0
	  dk_set_t		xeke_refs; /* xenc_reference_t */
	  xenc_key_t *		xeke_encrypted_key;
#endif

	  tree = (caddr_t *) dk_set_to_array (ek->xeke_refs);
	  dk_free_tree ((box_t) tree);
	  dk_set_free (ek->xeke_refs);
	  dk_free (ek, sizeof (xenc_enc_key_t));
	}
      END_DO_SET();
      dk_set_free (ctx->wc_dec->xed_keys);
      dk_free (ctx->wc_dec, sizeof (xenc_dec_t));
    }
  if (ctx->wc_id_cache)
    {
      id_hash_iterator_t hit;
      caddr_t * id;
      caddr_t * keyname;
      for (id_hash_iterator (&hit, ctx->wc_id_cache);
	   hit_next (&hit, (caddr_t*) &id, (caddr_t*) &keyname);
	   /* nop */)
	{
	  if (id) dk_free_box (id[0]);
	  if (keyname) dk_free_box (keyname[0]);
	}
      id_hash_free (ctx->wc_id_cache);
    }

  dk_free_box (ctx->wc_tb.xtb_err_buffer);
  dk_free (ctx, sizeof (wsse_ctx_t));
}

static
xenc_key_t * xenc_get_key_by_keyid (wsse_ctx_t * ctx, char * ref)
{
  id_hash_t * id_hash = ctx->wc_id_cache;
  caddr_t * keyname = (caddr_t *) id_hash_get (id_hash, (caddr_t) &ref);
  if (!keyname)
    {
      /* id */
      xenc_key_t ** k;
      mutex_enter (xenc_keys_mtx);
      k =  (xenc_key_t **) id_hash_get (xenc_certificates, (caddr_t) & ref);
      mutex_leave (xenc_keys_mtx);
      if (k)
	return k[0];
      return 0;
    }
  return xenc_get_key_by_name (keyname[0], 1);
}

typedef void (*wsse_callback_f) (char* uri, char* name, caddr_t * curr, wsse_ctx_t * ctx);

typedef struct wsse_callback_item_s
{
  char *		wsse_c_name;
  wsse_callback_f	wsse_c_callback;
} wsse_callback_item_t;


void wsse_canonmethod_callback (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx);
void wsse_digestmethod_callback (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx);
void wsse_digestvalue_callback  (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx);
void wsse_keyinfo_callback (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx);
void wsse_keyname_callback (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx);
void wsse_keyvalue_callback (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx);
void wsse_reference_callback (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx);
void wsse_signature_callback (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx);
void wsse_signaturemethod_callback (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx);
void wsse_signaturevalue_callback (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx);
void wsse_signedinfo_callback (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx);
void wsse_transform_callback (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx);
void wsse_transforms_callback (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx);
void wsse_xpath_callback (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx);
void wsse_dsakeyvalue_callback (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx);
void wsse_p_callback (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx);
void wsse_q_callback (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx);
void wsse_g_callback (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx);
void wsse_y_callback (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx);
void wsse_rsakeyvalue_callback (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx);
void wsse_modulus_callback (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx);
void wsse_exponent_callback (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx);
void wsse_x509data_callback (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx);
void wsse_x509certificate_callback (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx);

/* MUST keep this list in alphabetical order */
static
wsse_callback_item_t wsse_dsig_callbacks [] =
{
  {"CanonicalizationMethod", wsse_canonmethod_callback},
  {"DSAKeyValue", wsse_dsakeyvalue_callback},
  {"DigestMethod", wsse_digestmethod_callback},
  {"DigestValue", wsse_digestvalue_callback},
  {"Exponent", wsse_exponent_callback},
  {"G", wsse_p_callback},
  {"KeyInfo", wsse_keyinfo_callback},
  {"KeyName", wsse_keyname_callback},
  {"KeyValue", wsse_keyvalue_callback},
  {"Modulus", wsse_modulus_callback},
  {"P", wsse_p_callback},
  {"Q", wsse_q_callback},
  {"RSAKeyValue", wsse_rsakeyvalue_callback},
  {"Reference", wsse_reference_callback},
  {"Signature", wsse_signature_callback},
  {"SignatureMethod", wsse_signaturemethod_callback},
  {"SignatureValue", wsse_signaturevalue_callback},
  {"SignedInfo", wsse_signedinfo_callback},
  {"Transform", wsse_transform_callback},
  {"Transforms", wsse_transforms_callback},
  {"X509Certificate", wsse_x509certificate_callback},
  {"X509Data", wsse_x509data_callback},
  {"XPath", wsse_xpath_callback},
  {"Y", wsse_p_callback}
};

static
ptrlong wsse_dsig_callbacks_len = sizeof (wsse_dsig_callbacks) / sizeof (wsse_callback_item_t);

void wsse_cipherdata_c (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx);
void wsse_ciphervalue_c (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx);
void wsse_datareference_c (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx);
void wsse_encryptedkey_c (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx);
void wsse_encryptionmethod_c (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx);
void wsse_referencelist_c (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx);


static
wsse_callback_item_t wsse_xenc_callbacks [] =
{
  /*
     EncryptedKey,
     EncryptionMethod
     CipherData
     CipherValue
     ReferenceList
     DataReference
   */
  { "CipherData", wsse_cipherdata_c },
  { "CipherValue", wsse_ciphervalue_c },
  { "DataReference", wsse_datareference_c },
  { "EncryptedKey", wsse_encryptedkey_c },
  { "EncryptionMethod", wsse_encryptionmethod_c },
  { "ReferenceList", wsse_referencelist_c }
};

static
ptrlong wsse_xenc_callbacks_len = sizeof (wsse_xenc_callbacks) / sizeof (wsse_callback_item_t);

void wss_binarysectoken_c (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx);
void wss_reference_c (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx);
void wss_keyidentifier_c (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx);
void wss_security_c(char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx);
void wss_securitytokenref_c (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx);
void wss_usernametoken_c (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx);
void wss_dummy_c (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx);

static
wsse_callback_item_t wsse_callbacks [] =
{
  { "BinarySecurityToken", wss_binarysectoken_c},
  { "KeyIdentifier", wss_keyidentifier_c},
  { "Nonce", wss_dummy_c },
  { "Password", wss_dummy_c },
  { "Reference", wss_reference_c },
  { "Security", wss_security_c },
  { "SecurityTokenReference", wss_securitytokenref_c },
  { "Username", wss_dummy_c },
  { "UsernameToken", wss_usernametoken_c },
};

static
ptrlong wsse_callbacks_len = sizeof (wsse_callbacks) / sizeof (wsse_callback_item_t);


caddr_t DBG_NAME(wsse_get_content_val) (DBG_PARAMS caddr_t * curr)
{
  if (BOX_ELEMENTS (curr) > 1)
    {
      caddr_t value = curr[1];
      if (DV_STRINGP (value))
	{
	  return DBG_NAME(box_dv_short_string) (DBG_ARGS value);
	}
    }
  return NULL;
}



void wsse_canonmethod_callback (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx)
{
  char * algoname = xml_find_attribute (curr, "Algorithm", 0);
  if (!algoname)
    wsse_report_error (ctx, WSSE_NO_ALGORITHM_CODE, 0);
  WSSE_ASSERT (ctx->wc_dsig);

  dsig_canon_f_get (algoname, &ctx->wc_tb);

  ctx->wc_dsig->dss_canon_method = box_dv_short_string (algoname);
}

void wsse_signaturemethod_callback (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx)
{
  char * algoname = xml_find_attribute (curr, "Algorithm", 0);
  if (!algoname)
    wsse_report_error (ctx, WSSE_NO_ALGORITHM_CODE, 0);
  WSSE_ASSERT (ctx->wc_dsig);

  dsig_sign_f_get (algoname, &ctx->wc_tb);

  ctx->wc_dsig->dss_signature_method = box_dv_short_string (algoname);
}

void wsse_digestmethod_callback (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx)
{
  char * algoname = xml_find_attribute (curr, "Algorithm", 0);
  if (!algoname)
    wsse_report_error (ctx, WSSE_NO_ALGORITHM_CODE, 0);
  WSSE_ASSERT (ctx->wc_curr_ref);

  dsig_digest_f_get (algoname, &ctx->wc_tb);

  ctx->wc_curr_ref->dsr_digest_method = box_dv_short_string (algoname);
}

void wsse_digestvalue_callback  (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx)
{
  caddr_t res;
  WSSE_ASSERT (ctx->wc_curr_ref);

  res = wsse_get_content_val (curr);

  if (res)
    ctx->wc_curr_ref->dsr_digest = res;
  else if (!ctx->wc_allow_empty_vals)
    wsse_report_error (ctx, WSSE_DIGEST_VALUE_UNINIT_CODE, 0);

  /* after all transforms in reference */
  ctx->wc_curr_ref->dsr_transforms = dk_set_nreverse (ctx->wc_curr_ref->dsr_transforms);
}

void wsse_reference_callback (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx)
{
  dsig_reference_t * ref;
  char * URI;
  char * Id;
  char * Type;

  WSSE_ASSERT (ctx->wc_dsig);

  ref = (dsig_reference_t *) dk_alloc (sizeof (dsig_reference_t));
  memset (ref,0,sizeof (dsig_reference_t));

  ctx->wc_curr_ref = ref;

  URI = xml_find_attribute (curr, "URI", 0);
  Id = xml_find_attribute (curr, "Id", 0);
  Type = xml_find_attribute (curr, "Type", 0);

  ref->dsr_uri = box_dv_short_string (URI);
  ref->dsr_id = box_dv_short_string (Id);
  ref->dsr_type = box_dv_short_string (Type);

  if (URI && URI[0]) /* non empty URI */
    {
      NEW_VARZ (dsig_transform_t, tr);
      tr->dst_name = box_dv_short_string (DSIG_FAKE_URI_TRANSFORM_ALGO);
      tr->dst_data = box_dv_short_string (URI);
      dk_set_push (&ref->dsr_transforms, tr);
    }
  dk_set_push (&ctx->wc_dsig->dss_refs, (void*) ref);
}

void wsse_signedinfo_callback (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx)
{
}

void wsse_transform_callback (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx)
{
  char * algoname = xml_find_attribute (curr, "Algorithm", 0);

  WSSE_ASSERT (ctx->wc_curr_ref);

  if (algoname)
    {
      NEW_VARZ (dsig_transform_t, tr);
      tr->dst_name = box_dv_short_string (algoname);
      ctx->wc_curr_transform = tr;
      dk_set_push (&ctx->wc_curr_ref->dsr_transforms, tr);
    }
}

void wsse_transforms_callback (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx)
{
  WSSE_ASSERT (ctx->wc_curr_ref);
}

void wsse_xpath_callback (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx)
{
  dsig_transform_t * tr = ctx->wc_curr_transform;
  WSSE_ASSERT (tr);

  tr->dst_data = wsse_get_content_val (curr);

  if (!tr->dst_data)
    wsse_report_error (ctx, WSSE_EMPTY_XPATH_EXPRESSION_CODE, 0);
}

void wsse_dsakeyvalue_callback (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx)
{
}
void wsse_p_callback (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx)
{}
void wsse_q_callback (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx)
{}
void wsse_g_callback (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx)
{}
void wsse_y_callback (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx)
{}

void wsse_rsakeyvalue_callback (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx)
{
#if 1
  return;
#else
  xenc_key_t * k = ctx->wc_key;
  WSSE_ASSERT (ctx->wc_dsig);
  WSSE_ASSERT (ctx->wc_key);

  k->xek_type = DSIG_KEY_RSA;
  k->xek_enc_algo =  xenc_algorithms_get (XENC_RSA_ALGO);
  k->xek_sign_algo =  xenc_algorithms_get (DSIG_RSA_SHA1_ALGO);
#endif
}
void wsse_modulus_callback (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx)
{
#if 1
  return;
#else
  xenc_key_t * k = ctx->wc_key;
  char * mod;
  WSSE_ASSERT (ctx->wc_dsig);
  WSSE_ASSERT (ctx->wc_key);

  mod = wsse_get_content_val (curr);
  if (!mod)
    wsse_report_error (ctx, WSSE_EMPTY_RSA_MODULUS_CODE, 0);
  dk_free_box (mod);
#endif
}
void wsse_exponent_callback (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx)
{
#if 1
  return;
#else
  xenc_key_t * k = ctx->wc_key;
  char * exp;
  WSSE_ASSERT (ctx->wc_dsig);
  WSSE_ASSERT (ctx->wc_key);

  exp = wsse_get_content_val (curr);
  if (!exp)
    wsse_report_error (ctx, WSSE_EMPTY_RSA_EXPONENT_CODE, 0);
  dk_free_box (exp);
#endif
}

void wsse_signature_callback (char * uri, char * name, caddr_t * curr, wsse_ctx_t * ctx)
{
  NEW_VARZ (dsig_signature_t, d);
  ctx->wc_dsig = d;
  ctx->wc_object_type = XENC_T_DSIG;
}

void wsse_signaturevalue_callback (char * uri, char * name, caddr_t * curr, wsse_ctx_t * ctx)
{
  dsig_signature_t * dsig = ctx->wc_dsig;
  WSSE_ASSERT (dsig);

  dsig->dss_signature = wsse_get_content_val (curr);
  if (!ctx->wc_allow_empty_vals && !dsig->dss_signature)
    wsse_report_error (ctx, WSSE_EMPTY_SIGNATURE_VALUE_CODE, 0);

  /* after all references */
  dsig->dss_refs = dk_set_nreverse (dsig->dss_refs);
}

void wsse_keyinfo_callback (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx)
{
  switch (ctx->wc_object_type)
    {
    case XENC_T_DSIG:
      {
	WSSE_ASSERT (ctx->wc_dsig);
	break;
      }
    case XENC_T_ENCKEY:
      {
	WSSE_ASSERT (ctx->wc_curr_enckey);
	break;
      }
    case XENC_T_ENCCTX:
      {
	ctx->wc_key = (xenc_key_t *) dk_alloc (sizeof (xenc_key_t));
	memset (ctx->wc_key, 0, sizeof (xenc_key_t));
	break;
      }
#if 1
    case XENC_T_SECURITY: /* session key */
      break;
#endif
    default:
      wsse_report_error (ctx, WSSE_UNENCRYPTED_KEY_CODE, 0);
    }
}

void wsse_keyname_callback (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx)
{
  switch (ctx->wc_object_type)
    {
    case XENC_T_DSIG:
      {
	caddr_t keyname = wsse_get_content_val (curr);
	xenc_key_t * key;
	if (!keyname)
	  wsse_report_error (ctx, WSSE_EMPTYNAME_CODE, 0);


	key = xenc_get_key_by_name (keyname, 1);
	if (!key)
	  {
	    char tmpbuf[128];
	    strncpy (tmpbuf, keyname, 128);
	    tmpbuf[127] = 0; /* if strlen (keyname) >= 128 */
	    dk_free_box (keyname);
	    wsse_report_error (ctx, WSSE_UNKNOWN_KEY_CODE, strlen (tmpbuf), tmpbuf);
	  }
	dk_free_box (keyname);
	if (strcmp (key->xek_sign_algo->xea_ns, ctx->wc_dsig->dss_signature_method))
	  {
	    wsse_report_error (ctx, WSSE_WRONG_KEY_CODE, strlen (key->xek_name)
			       + strlen (ctx->wc_dsig->dss_signature_method), key->xek_name,
			       ctx->wc_dsig->dss_signature_method);
	  }
	ctx->wc_dsig->dss_key = key;
      }
      break;
    case XENC_T_ENCKEY:
      {
	caddr_t keyname = wsse_get_content_val (curr);
	if (!keyname)
	  wsse_report_error (ctx, WSSE_EMPTYNAME_CODE, 0);

	WSSE_ASSERT (ctx->wc_curr_enckey);

	ctx->wc_curr_enckey->xeke_super_key = keyname;
      }
      break;
    case XENC_T_ENCCTX:
      {
	char * keyname = wsse_get_content_val (curr);
	GPF_T;
	WSSE_ASSERT (ctx->wc_key);

	if (!keyname)
	  wsse_report_error (ctx, WSSE_EMPTYNAME_CODE, 0);

	ctx->wc_key->xek_name = keyname;
      }
      break;
#if 1
    case XENC_T_SECURITY: /* session key */
      {
	char * keyname = wsse_get_content_val (curr);
	WSSE_ASSERT (ctx->wc_dec);

	if (!keyname)
	  wsse_report_error (ctx, WSSE_EMPTYNAME_CODE, 0);
	else if (!xenc_get_key_by_name (keyname, 1))
	  {
	    char keyn[128];
	    strncpy (keyn, keyname, 127);
	    keyn[127] = 0;
	    dk_free_box (keyname);
	    wsse_report_error (ctx, WSSE_UNKNOWN_KEY_CODE, 128, keyn);
	  }
	else
	  {
	    NEW_VARZ (xenc_enc_key_t , ek);

	    ctx->wc_curr_enckey = ek;
	    dk_set_push (&ctx->wc_dec->xed_keys, ek);
	    ek->xeke_name = keyname;
	  }
      }
      break;
#endif
    default:
      GPF_T;
    }
}

void wsse_keyvalue_callback (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx)
{
}

void wsse_x509data_callback (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx)
{
  dsig_signature_t * dsig = ctx->wc_dsig;
  WSSE_ASSERT (ctx->wc_dsig);
  dsig->dss_key_value_type = XENC_T_X509_CERT;
}

void wsse_x509certificate_callback (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx)
{
  caddr_t content = wsse_get_content_val (curr);
  xenc_key_t * key;
  if (!content)
    wsse_report_error (ctx, WSSE_BINARYSECTOKEN_CODE, 100, "tag is empty");
  key = certificate_decode (content, WSSE_OASIS_X509_VALUE_TYPE, WSSE_OASIS_BASE64_ENCODING_TYPE);
  dk_free_box (content);
  if (!key)
    wsse_report_error (ctx, WSSE_BINARYSECTOKEN_CODE, 100, "could not decode certificate");
  if (ctx->wc_object_type == XENC_T_DSIG)
    {
      WSSE_ASSERT (ctx->wc_dsig);
      ctx->wc_dsig->dss_key = key;
    }
  else if (ctx->wc_object_type == XENC_T_ENCKEY)
    {
      WSSE_ASSERT (ctx->wc_curr_enckey);
      ctx->wc_curr_enckey->xeke_super_key = box_dv_short_string (key->xek_name);
    }
}

void wsse_cipherdata_c (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx)
{
  WSSE_ASSERT (ctx->wc_curr_enckey);
}

void wsse_ciphervalue_c (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx)
{
  xenc_enc_key_t * ek = ctx->wc_curr_enckey;
  WSSE_ASSERT (ek);

  ek->xeke_cipher_value = wsse_get_content_val (curr);
  if (!ek->xeke_cipher_value)
    wsse_report_error (ctx, WSSE_EMPTY_CVAL_VALUE_CODE, 0);
}

void wsse_datareference_c (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx)
{
  xenc_enc_key_t * ek = ctx->wc_curr_enckey;
  char * URI = xml_find_attribute (curr, "URI", 0);

  if (!URI)
    wsse_report_error (ctx, WSSE_NO_URI_CODE, 0);

  if (!ek) /* is not within EncryptedKey */
    {
      ek = (xenc_enc_key_t *) dk_alloc (sizeof (xenc_enc_key_t));
      memset (ek, 0, sizeof (xenc_enc_key_t));
      ek->xeke_is_raw = 1;

      WSSE_ASSERT (ctx->wc_dec);

      ctx->wc_curr_enckey = ek;
      dk_set_push (&ctx->wc_dec->xed_keys, ek);
      ctx->wc_object_type = XENC_T_ENCKEY;
    }
  dk_set_push (&ek->xeke_refs, box_dv_short_string (URI));
}


void wsse_encryptedkey_c (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx)
{
  NEW_VARZ (xenc_enc_key_t , ek);

  WSSE_ASSERT (ctx->wc_dec);

  ctx->wc_curr_enckey = ek;
  dk_set_push (&ctx->wc_dec->xed_keys, ek);
  ctx->wc_object_type = XENC_T_ENCKEY;
}

void wsse_encryptionmethod_c (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx)
{
  char * algo = xml_find_attribute (curr, "Algorithm", 0);

  WSSE_ASSERT (ctx->wc_curr_enckey);

  if (!algo)
    wsse_report_error (ctx, WSSE_NO_ALGORITHM_CODE, 0);

  ctx->wc_curr_enckey->xeke_enc_method = box_dv_short_string (algo);
}

void wsse_referencelist_c (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx)
{

}

void wss_security_c (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx)
{
  NEW_VARZ (xenc_dec_t, dec);

  ctx->wc_dec = dec;
#if 1
  ctx->wc_object_type = XENC_T_SECURITY;
#endif
}

void wss_binarysectoken_c (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx)
{
  char * value_type = xml_find_attribute (curr, "ValueType", 0);
  char * encoding_type = xml_find_attribute (curr, "EncodingType", 0);
  char * id = xml_find_attribute (curr, "Id", 0);
  char * content;
  xenc_key_t * key;

  if (!value_type)
    wsse_report_error (ctx, WSSE_BINARYSECTOKEN_CODE, 100, "no ValueType attribute");

  if (!encoding_type)
    wsse_report_error (ctx, WSSE_BINARYSECTOKEN_CODE, 100, "no EncodingType attribute");

#if 0
  /* WSS spec: An optional string label for this security token */
  if (!id)
    wsse_report_error (ctx, WSSE_BINARYSECTOKEN_CODE, 100, "no {wsse}:Id attribute");
#endif

  content = wsse_get_content_val (curr);
  if (!content)
    wsse_report_error (ctx, WSSE_BINARYSECTOKEN_CODE, 100, "tag is empty");

  key = certificate_decode (content, value_type, encoding_type);
  dk_free_box (content);
  if (!key)
    wsse_report_error (ctx, WSSE_BINARYSECTOKEN_CODE, 100, "could not decode certificate");
  if (id[0])
    {
      char * id_1 = dk_alloc_box (box_length (id) + 1, DV_STRING);
      char * kname = box_dv_short_string (key->xek_name);
      id_1[0] = '#';
      memcpy (id_1 + 1, id, box_length (id));
      id_hash_set (ctx->wc_id_cache, (caddr_t) &id_1, (caddr_t)&kname);
    }
}
void wss_reference_c (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx)
{
  char * ref = xml_find_attribute (curr, "URI", 0);
  if (ref)
    {
      xenc_key_t * k = xenc_get_key_by_keyid (ctx, ref);
      if (!k)
	wsse_report_error (ctx, WSSE_BINARYSECTOKENREF_CODE, strlen (ref), ref);
      if (ctx->wc_object_type == XENC_T_DSIG)
	{
	  ctx->wc_dsig->dss_key = k;
	}
      else if (ctx->wc_object_type == XENC_T_ENCKEY)
	{
	  WSSE_ASSERT (ctx->wc_curr_enckey);
	  ctx->wc_curr_enckey->xeke_super_key = box_dv_short_string (k->xek_name);
	}
    }
}
void wss_keyidentifier_c (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx)
{
  caddr_t value_type = xml_find_attribute (curr, "ValueType", 0);
  caddr_t keyident;

  if (!value_type)
    wsse_report_error (ctx, WSSE_BINARYSECTOKEN_CODE, 100, "Unknown type of key identifier");

  if (strcmp (value_type, WSSE_X509_VALUE_TYPE) && strcmp (value_type, WSSE_OASIS_X509_SUBJECT_KEYIDENTIFIER))
    wsse_report_error (ctx, WSSE_BINARYSECTOKENVALTYPE_CODE, strlen (value_type), value_type);
  keyident = wsse_get_content_val (curr);
  if (!keyident)
    wsse_report_error (ctx, WSSE_BINARYSECTOKEN_CODE, 100,
		       "Key identifier must be base64 encoded string");

  if (ctx->wc_object_type == XENC_T_DSIG ||
      ctx->wc_object_type == XENC_T_ENCKEY)
    {
      xenc_key_t * k = xenc_get_key_by_keyidentifier (keyident, 1);
      if (!k)
	{
	  char buf[201];
	  memset (buf, 0 , sizeof (buf));
	  strncpy (buf, keyident, 200);
	  dk_free_box (keyident);
	  wsse_report_error (ctx, WSSE_BINARYSECTOKENREF_CODE, strlen (buf), buf);
	}
      if (ctx->wc_object_type == XENC_T_DSIG)
	{
	  ctx->wc_dsig->dss_key = k;
	}
      else
	{
	  WSSE_ASSERT (ctx->wc_curr_enckey);
	  ctx->wc_curr_enckey->xeke_super_key = box_dv_short_string (k->xek_name);
	}
    }
  dk_free_box (keyident);
}


void wss_securitytokenref_c (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx)
{
}

void wss_usernametoken_c (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx)
{
  char * id = xml_find_attribute (curr, "Id", 0);
  xenc_key_t * key;
  caddr_t *tag_uname, *tag_pass, *tag_nonce, *tag_stamp, seed, pass_type = NULL;
  char *uname = NULL, *pass = NULL, *nonce = NULL, *stamp = NULL;
  dk_session_t *ses = strses_allocate ();
  dk_session_t *dgs = strses_allocate ();
  user_t * user;
  u_tok_t * utok;
  caddr_t * utok_opts = (caddr_t *) xenc_get_option (ctx->wc_opts, "UsernameToken", NULL);
  caddr_t wss_label = xenc_get_option (utok_opts, "label", "WS-Security");

  session_buffered_write (ses, wss_label, strlen (wss_label)); /* WSE2.0 silently defines WS-Security as label */

  if (NULL != (tag_nonce = (caddr_t *) xml_find_one_child (curr, "Nonce", wsse_uris, 0, 0)))
    {
      int len;
      caddr_t nonce1;
      nonce = wsse_get_content_val (tag_nonce);
      nonce1 = box_copy (nonce);
      len = xenc_decode_base64 (nonce1, nonce1 + box_length (nonce1));
      session_buffered_write (ses, nonce1, len);
      session_buffered_write (dgs, nonce1, len);
      dk_free_box (nonce1);
    }
  else if (ctx->wc_object_type == XENC_T_DSIG)
    {
      char nonce1[16], nonce2 [40];
      int len;
      RAND_pseudo_bytes ((unsigned char *)nonce1, 16);
      session_buffered_write (ses, nonce1, 16);
      len = xenc_encode_base64 (nonce1, nonce2, 16);
      nonce2[len] = 0;
      nonce = box_dv_short_string (nonce2);
    }
  else
    {
      wsse_report_error (ctx, WSSE_UNKNOWN_CODE, 100, "Mandatory wss:Nonce element is missing");
    }

  if (NULL != (tag_uname = (caddr_t *) xml_find_one_child (curr, "Username", wsse_uris, 0, 0)))
    {
      uname = wsse_get_content_val (tag_uname);
    }

  if (NULL != (tag_stamp = (caddr_t *) xml_find_one_child (curr, "Created", wsu_uris, 0, 0)))
    {
      stamp = wsse_get_content_val (tag_stamp);
      session_buffered_write (ses, stamp, box_length (stamp) - 1);
      session_buffered_write (dgs, stamp, box_length (stamp) - 1);
    }
  else if (ctx->wc_object_type == XENC_T_DSIG)
    {
      time_t now;
      char dt [DT_LENGTH], buf [100];

      time (&now);
      time_t_to_dt (now, 0, dt);
      DT_SET_TZ (dt, 0);
      dt_to_iso8601_string (dt, buf, sizeof (buf));
      stamp = box_dv_short_string (buf);
      session_buffered_write (ses, stamp, box_length (stamp) - 1);
    }

  if (NULL != (tag_pass  = (caddr_t *) xml_find_one_child (curr, "Password", wsse_uris, 0, 0)))
    {
      pass = wsse_get_content_val (tag_pass);
      pass_type = xml_find_attribute (tag_pass, "Type", 0);
      if (pass_type && !strncmp (pass_type, WSSE_OASIS_UTOKEN_PROFILE, strlen (WSSE_OASIS_UTOKEN_PROFILE)))
	{
	  pass_type = strrchr (pass_type, '#');
	  pass_type++;
	}
      else if (pass_type && strrchr (pass_type, ':'))
	{
	  pass_type = strrchr (pass_type, ':');
	  pass_type++;
	}
    }

  seed = strses_string (ses);
  strses_free (ses);

  if (ctx->wc_object_type != XENC_T_DSIG)
    {
      if (NULL == (user = sec_name_to_user (uname)))
	{
	  dk_free_box (pass); dk_free_box (uname); dk_free_box (stamp); dk_free_box (nonce);
	  dk_free_box (seed);
	  strses_free (dgs);
	  wsse_report_error (ctx, WSSE_UNKNOWN_CODE, 100, "Unknown user in wss:Username");
	}

      if (pass_type && !strcmp (pass_type, "PasswordDigest"))
	{
	  unsigned char md [SHA_DIGEST_LENGTH + 1], md64 [SHA_DIGEST_LENGTH * 2 + 1];
	  SHA_CTX ctx1;
	  int len;
	  caddr_t tmp;

	  session_buffered_write (dgs, user->usr_pass, box_length (user->usr_pass) - 1);
	  tmp = strses_string (dgs);
	  SHA1_Init(&ctx1);
	  SHA1_Update(&ctx1, tmp, box_length (tmp) - 1);
	  SHA1_Final(&(md[0]), &ctx1);
	  dk_free_box (tmp);
	  len = xenc_encode_base64 ((char *)md, (char *)md64, SHA_DIGEST_LENGTH);
	  md64 [len] = 0;
	  if (0 != strcmp ((char *)md64, pass))
	    {
	      dk_free_box (pass); dk_free_box (uname); dk_free_box (stamp); dk_free_box (nonce);
	      dk_free_box (seed);
	      strses_free (dgs);
	      wsse_report_error (ctx, WSSE_UNKNOWN_CODE, 100, "Invalid credentials");
	    }
	  else
	    {
	      dk_free_box (pass);
	      pass = box_copy (user->usr_pass);
	    }
	}
      else if (!pass || 0 != strcmp (user->usr_pass, pass))
	{
	  dk_free_box (pass); dk_free_box (uname); dk_free_box (stamp); dk_free_box (nonce);
	  dk_free_box (seed);
	  strses_free (dgs);
	  wsse_report_error (ctx, WSSE_UNKNOWN_CODE, 100, "Invalid credentials");
	}
    }
  strses_free (dgs);


  /*
     The secret is the password, the label is the client label (optionally specified in policies),
     and the seed is the nonce value specified by the client (a <Nonce> element is required).
     If such an element is specified in the <Username> element it is used,
     otherwise the value from the <Security> element is used.
     If a <wsu:Created> time element is specified in the <UsernameToken>, then it is also used.
     If this message is part of a shared context with another party,
     then the label is the concatenation of the client and server labels
     and the seed is the concatenation of the client and server nonces.
     The nonce is processed as a binary octet stream and the timestamp as a UTF-8 encoded string.
     P_SHA1 (password, label + nonce + timestamp)
  */

  utok = (u_tok_t *) dk_alloc (sizeof (u_tok_t));
  memset (utok, 0, sizeof (u_tok_t));
  utok->uname = uname;
  utok->pass = pass;
  utok->ts = stamp;
  utok->nonce = nonce;

  key = xenc_key_create_from_utok (utok, seed, ctx);
  dk_free_box (seed);

  if (!key)
    wsse_report_error (ctx, WSSE_UNKNOWN_CODE, 100, "could not decode username token");


  if (ctx->wc_object_type == XENC_T_DSIG)
    {
      ctx->wc_dsig->dss_key = key;
    }

  if (id && id[0])
    {
      char * id_1 = dk_alloc_box (box_length (id) + 1, DV_STRING);
      char * kname = box_dv_short_string (key->xek_name);
      id_1[0] = '#';
      memcpy (id_1 + 1, id, box_length (id));
      id_hash_set (ctx->wc_id_cache, (caddr_t) &id_1, (caddr_t)&kname);
    }

}


void wss_dummy_c (char* uri, char * name, caddr_t * curr, wsse_ctx_t * ctx)
{
}

wsse_callback_f wsse_get_callback (wsse_ctx_t * ctx, const char * uri, const char * name)
{
  ptrlong idx;
  wsse_callback_item_t * callbacks = NULL;
  ptrlong callbacks_len = 0;

  if (!strcmp (uri, XENC_URI))
    {
      callbacks = (wsse_callback_item_t *) wsse_xenc_callbacks;
      callbacks_len = wsse_xenc_callbacks_len;
    }
  else if (!strcmp (uri, DSIG_URI))
    {
      callbacks = (wsse_callback_item_t *) wsse_dsig_callbacks;
      callbacks_len = wsse_dsig_callbacks_len;
    }
  else if (is_in_urls (wsse_uris, uri, NULL))
    {
      callbacks = (wsse_callback_item_t *) wsse_callbacks;
      callbacks_len = wsse_callbacks_len;
    }
  else if (is_in_urls (wsu_uris, uri, NULL))
    {
      /* no callbacks at present */
      return 0;
    }
  else
    wsse_report_error (ctx, WSSE_UNKNOWN_URI_CODE, 0);

  idx = ecm_find_name (name, (void *)callbacks, callbacks_len, sizeof (wsse_callback_item_t));

  if (idx != -1)
    {
      wsse_callback_item_t * item = callbacks + idx;
      return item->wsse_c_callback;
    }
  wsse_report_error (ctx, WSSE_CALLBACK_NOT_FOUND_CODE, strlen (name), name);
  return 0;
}

int wsse_build_wsse_objects (caddr_t * curr, wsse_callback_f wsse_serialize, wsse_ctx_t * ctx)
{
  if (!wsse_serialize)
    return 0;
  else
    {
      char *szName = XML_ELEMENT_NAME (curr);
      char *szColon = strrchr (szName, ':');
      char *name;
      int inx;

      if (!szColon)
	return 0;

      name = szColon + 1;
      /* error handling must be here */
      ( wsse_serialize ) (0, name, curr, ctx);
      DO_BOX (caddr_t *, child, inx, curr)
	{
	  if (inx && DV_TYPE_OF (child) == DV_ARRAY_OF_POINTER)
	    {
	      char *szName = XML_ELEMENT_NAME (child);
	      char *szColon = strrchr (szName, ':');
	      char *name;
	      int colon_len = (int) (szColon - szName);
	      char uri[100];
	      wsse_callback_f new_serilize;

	      if (!szColon)
		continue;

	      strncpy (uri, szName, colon_len);
	      uri[colon_len] = 0;
	      name = szColon + 1;
	      new_serilize = wsse_get_callback (ctx, uri, name);

	      wsse_build_wsse_objects (child, new_serilize, ctx);
	    }
	}
      END_DO_BOX;
      return 1;
    }
}

void wsse_resolve_encrypted_keys (caddr_t * envelope, wsse_ctx_t * ctx)
{
  id_hash_t * id_cache = 0;
  dk_set_t unresolved = 0;
  xenc_dec_t * dec = ctx->wc_dec;

  if (!dec)
    return;

  DO_SET (xenc_enc_key_t*, enc_key, &dec->xed_keys)
    {
      if (enc_key->xeke_is_raw)
	{
	  dk_set_push (&unresolved, enc_key);
	}
    }
  END_DO_SET ();

  if (!unresolved)
    return;

  xenc_build_ids_hash (envelope, &id_cache, 1);
  if (!id_cache)
    {
      dk_set_free (unresolved);
      wsse_report_error (ctx, WSSE_UNRESOLVED_REF_URIS_CODE, 0);
    }

  DO_SET (xenc_enc_key_t*, enc_key, &unresolved)
    {
      caddr_t ** curr;
      caddr_t uri = (caddr_t) enc_key->xeke_refs->data;
      caddr_t * keyinfo;
      caddr_t * keyname;
      char * key_name;

      curr = (caddr_t **) id_hash_get (id_cache, (caddr_t) & uri);
      if (!curr)
	{
	  xenc_ids_hash_free (id_cache);
	  dk_set_free (unresolved);
	  wsse_report_error (ctx, WSSE_UNRESOLVED_REF_URI_CODE, strlen (uri), uri);
	}
      keyinfo = (caddr_t *) xml_find_child (curr[0], "KeyInfo", DSIG_URI, 0,0);
      if (!keyinfo)
	{
	  xenc_ids_hash_free (id_cache);
	  dk_set_free (unresolved);
	  wsse_report_error (ctx, WSSE_ENCKEY_REF_URI_NO_KEYINFO_CODE, strlen (uri), uri);
	}
      keyname = (caddr_t *) xml_find_child (keyinfo, "KeyName", DSIG_URI, 0, 0);
      if (!keyname)
	{
	  xenc_ids_hash_free (id_cache);
	  dk_set_free (unresolved);
	  wsse_report_error (ctx, WSSE_ENCKEY_REF_URI_NO_KEYNAME_CODE, strlen (uri), uri);
	}
      key_name = wsse_get_content_val (keyname);
      if (!key_name)
	{
	  xenc_ids_hash_free (id_cache);
	  dk_set_free (unresolved);
	  wsse_report_error (ctx, WSSE_ENCKEY_REF_URI_EMPTY_KEYNAME_CODE, strlen (uri), uri);
	}
      enc_key->xeke_name = key_name;
     }
  END_DO_SET ();
  xenc_ids_hash_free (id_cache);
  dk_set_free (unresolved);
}

/* returns 0 if failed */
int dsig_verify_signature (dsig_signature_t * d, xml_tree_ent_t * xte, id_hash_t * nss)
{
  caddr_t * signature_tree = xte->xte_current;
  caddr_t * doc_tree =  xte->xe_doc.xtd->xtd_tree;
  query_instance_t * qi = xte->xe_doc.xtd->xd_qi;
  dk_session_t * ses_out;
  dsig_verify_f verify = dsig_verify_f_get (d->dss_signature_method, 0);

  ses_out = strses_allocate ();

  if (!xml_canonicalize (qi, doc_tree, signature_tree, nss, ses_out))
    {
      strses_free (ses_out);
      return 0;
    }

  if (!verify(ses_out, strses_length (ses_out), d->dss_key, d->dss_signature))
    {
      strses_free (ses_out);
      return 0;
    }
  strses_free (ses_out);
  return 1;
}

xenc_err_code_t dsig_check_xml (query_instance_t * qi, dsig_signature_t * d, char * xml_text,
	 long len, xenc_err_code_t * c, char ** err, int is_wsse)
{
  dsig_signature_t * d_copy = dsig_copy_draft (d);
  xenc_err_code_t cc;
  dk_session_t * xml_doc;
  dsig_compare_t cmp;
  memset (&cmp, 0, sizeof (dsig_compare_t));
  if (err) err[0] = 0;

  xml_doc = strses_allocate ();
  xml_doc->dks_in_buffer = xml_text;
  xml_doc->dks_in_fill = len;
  xml_doc->dks_in_read = 0;

  SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_XENC_ERR_BUFFER, 0);
  SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_XENC_ERR_CODE, 0);

  if ((cc = dsig_initialize (qi, xml_doc, len, d_copy, c, err)))
    {
      dsig_free (d_copy);
      xml_doc->dks_in_buffer = NULL;
      strses_free (xml_doc);
      return cc;
    }
  xml_doc->dks_in_buffer = NULL;
  strses_free (xml_doc);
  xml_doc = NULL;

  if (dsig_compare (d, d_copy, &cmp))
    {
      if (c)
	cc = c[0] = DSIG_CHECK_ERR;

      if (err)
	{
	  char buf[1024];
	  memset (buf, 0, 1024);
	  snprintf (buf, 1023, "XML document failed signature check at %s with value %s [must be %s]",
		    cmp.dsc_obj, cmp.dsc_value1, cmp.dsc_value2);
	  err[0] = box_dv_short_string (buf);
	}
      dsig_free (d_copy);
      return cc;
    }

  dsig_free (d_copy);

  {
    id_hash_t * nss = 0;
    xml_tree_ent_t * xte = (xml_tree_ent_t *) xml_make_tree_with_ns (qi, xml_text,
	0, "UTF-8", lh_get_handler ("x-any"), &nss, 0);
    caddr_t * signature = xte ? xml_find_signedinfo (xte->xte_current, is_wsse) : 0;

    if (!signature)
      {
	dk_free_box ((box_t) xte);
	nss_free (nss);
	if (c)
	  c[0] = DSIG_CHECK_ERR;
	if (err)
	  err[0] = box_dv_short_string ("XML Document contains no Signature");
	return DSIG_CHECK_ERR;
      }
    xte->xte_current = signature;
    if (!dsig_verify_signature (d, xte, nss))
      {
	dk_free_box ((box_t) xte);
	nss_free (nss);
	if (c)
	  c[0] = DSIG_CHECK_ERR;
	if (err)
	  err[0] = box_dv_short_string ("Signature verify check error");
	return DSIG_CHECK_ERR;
      }
    dk_free_box ((box_t) xte);
    nss_free (nss);
  }
  return 0;
}

/* uri must not be zero! */
int xml_is (char * name, char * uri, char * tagname)
{
  char *col;
  int len;

  if (!name)
    return 0;

  col = strrchr (name, ':');
  len = (int) (col - name);

  if (!col)
    return 0;

  if (len != strlen (uri))
    return 0;

  if (strncmp (name, uri, len))
    return 0;

  if (strcmp (col + 1, tagname))
    return 0;
  return 1;
}

caddr_t dsig_sign_signature (dsig_signature_t * dsig, xml_tree_ent_t * xte, id_hash_t * nss, wsse_ctx_t * ctx)
{
  caddr_t * signature_tree = xte->xte_current;
  caddr_t * doc_tree =  xte->xe_doc.xtd->xtd_tree;
  query_instance_t * qi = xte->xe_doc.xtd->xd_qi;
  caddr_t * siginfo_tree = xml_find_child (signature_tree, "SignedInfo", DSIG_URI, 0, 0);
  dsig_canon_2_f canon_f;
  dsig_sign_f sign_f;
  dk_session_t * ses;
  caddr_t signval;

  if (!siginfo_tree)
    wsse_report_error (ctx, WSSE_NO_TAG_CODE, strlen ("SingInfo"), "SignInfo");

  canon_f = dsig_canon_2_f_get (dsig->dss_canon_method, &ctx->wc_tb);
  sign_f = dsig_sign_f_get (dsig->dss_signature_method, &ctx->wc_tb);

  ses = strses_allocate ();

  if (!(canon_f) (qi, doc_tree, siginfo_tree, nss, ses))
    {
      strses_free (ses);
      wsse_report_error (ctx, WSSE_ALGO_CODE, sizeof (dsig->dss_canon_method),
			 dsig->dss_canon_method);
    }

  if (!(sign_f) (ses, strses_length(ses), dsig->dss_key, &signval))
    {
      strses_free (ses);
      if (dsig->dss_key)
	wsse_report_error (ctx, WSSE_ALGO_CODE, sizeof (dsig->dss_signature_method),
			 dsig->dss_signature_method);
      else
	wsse_report_error (ctx, WSSE_ALGO_EMPTY_KEY_CODE, sizeof (dsig->dss_signature_method),
			 dsig->dss_signature_method);
    }
  strses_free (ses);

  return signval;
}
caddr_t dsig_sign_signature_ (query_instance_t * qi, dsig_signature_t * dsig, caddr_t dsig_template_str, xenc_err_code_t * c, char ** err)
{
  wsse_ctx_t * ctx;
  caddr_t signval = 0;
  caddr_t * signature;
  id_hash_t * nss = 0;
  xml_tree_ent_t * doc = NULL;

  ctx = wsse_ctx_allocate ();

  XENC_TRY (&ctx->wc_tb)
    {
      doc =  (xml_tree_ent_t *) xml_make_tree_with_ns (qi,
	dsig_template_str, err, "UTF-8", lh_get_handler ("x-any"), &nss, 0);

      if (!doc)
	wsse_report_error (ctx, WSSE_XML_CODE, 0);

      signature = xml_find_signature (doc->xte_current, 1);

      if (!signature)
	wsse_report_error (ctx, WSSE_NO_TAG_CODE, strlen ("Signature"), "Signature");

      doc->xte_current = signature;

      signval = dsig_sign_signature (dsig, doc, nss, ctx);
      dk_free_box ((box_t) doc);
      nss_free (nss);
    }
  XENC_CATCH
    {
      dk_free_box ((box_t) doc);
      nss_free (nss);
      if (c) c[0] = ctx->wc_tb.xtb_err_code;
      if (err) err[0] = box_dv_short_string (ctx->wc_tb.xtb_err_buffer);
      wsse_ctx_free (ctx);
      return 0;
    }
  XENC_TRY_END (&ctx->wc_tb);
  wsse_ctx_free (ctx);

  return signval;
}


/* procedure for validating xml against detached signature */
caddr_t bif_dsig_validate (caddr_t *qst, caddr_t *err, state_slot_t ** args)
{
  caddr_t xml_text = bif_string_arg (qst, args, 0, "dsig_validate");
  caddr_t signature_xml_text = BOX_ELEMENTS (args) > 1 ? bif_string_or_null_arg (qst, args, 1, "dsig_validate") : NULL;
  caddr_t enc = BOX_ELEMENTS (args) > 2 ? bif_string_arg (qst, args, 2, "dsig_validate") : "UTF-8";
  lang_handler_t *lh = BOX_ELEMENTS (args) > 3 ? lh_get_handler (bif_string_arg (qst, args, 3, "dsig_validate")) : server_default_lh;
  wsse_ctx_t * ctx;
  dsig_signature_t * dsig;
  caddr_t * signature_tag, err_ret = NULL;
  caddr_t * xml_doc;
  xenc_err_code_t c;
  caddr_t errm = NULL;
  id_hash_t * nss = 0;
  xml_tree_ent_t * xte;

  if (!signature_xml_text)
    signature_xml_text = xml_text;

  xte = (xml_tree_ent_t *) xml_make_tree_with_ns ((query_instance_t*) qst, signature_xml_text, &err_ret, enc, lh, &nss, 0);

  if (!xte)
    {
      nss_free (nss);
      if (!err_ret)
	sqlr_new_error ("42000", "XENC25", "Could not parse signature XML document");
      else
	{
	  *err = err_ret;
	  return NULL;
	}
    }

  xml_doc = xte->xte_current;
  signature_tag = xml_find_any_child (xml_doc, "Signature", DSIG_URI);
  if (!signature_tag)
    {
      dk_free_box ((box_t) xte);
      nss_free (nss);
      sqlr_new_error ("42000", "XENC26", "XML document is not XML Signature");
    }

  xte->xte_current = signature_tag;
  ctx = wsse_ctx_allocate();
  XENC_TRY (&ctx->wc_tb)
    {
      wsse_build_wsse_objects (signature_tag, wsse_get_callback (ctx, DSIG_URI , "Signature"), ctx);
    }
  XENC_CATCH
    {
      char errbuf[1024];
      dk_free_box ((box_t) xte);
      nss_free (nss);
      xenc_make_error (errbuf, 1024, ctx->wc_tb.xtb_err_code, ctx->wc_tb.xtb_err_buffer);
      wsse_ctx_free (ctx);
      sqlr_new_error ("42000", "XENC27", "dsig_validate function reports an error: %s", errbuf);
    }
  XENC_TRY_END(&ctx->wc_tb);

  dsig = ctx->wc_dsig;
  dk_free_box ((box_t) xte);
  nss_free (nss);

  if (dsig_check_xml ((query_instance_t*) qst, dsig, xml_text, box_length (xml_text) - 1, &c, &errm, 0))
    {
      char buf[1024];
      xenc_make_error (buf, 1024, c, errm);
      dk_free_tree (errm);
      wsse_ctx_free (ctx);
      sqlr_new_error ("42000", "XENC28", "error occurred when xml document was checked: %s", buf);
    }
  wsse_ctx_free (ctx);
  return NEW_DB_NULL;
}

caddr_t * xml_find_signature (caddr_t * doc, int is_wsse)
{
  caddr_t * envelope;
  if (!is_wsse)
    return xml_find_any_child (doc, "Signature", DSIG_URI);
  envelope = xml_find_child (doc, "Envelope", WSS_SOAP_URI, 0, NULL);
  if (envelope)
    {
      caddr_t * header = xml_find_child (envelope, "Header", WSS_SOAP_URI, 0,NULL);
      if (header)
	{
	  caddr_t * security = xml_find_one_child (header, "Security", wsse_uris, 0, NULL);
	  if (!security)
		return 0;
	  return xml_find_child (security, "Signature", DSIG_URI, 0, NULL);
	}
    }
  return 0;
}

caddr_t * xml_find_signedinfo (caddr_t * doc, int is_wsse)
{
  caddr_t * signature = xml_find_signature (doc, is_wsse);
  if (signature)
    {
      return xml_find_child (signature, "SignedInfo", DSIG_URI, 0, NULL);
    }
  return 0;
}


#define XENC_VALIDATE_NONE	0
#define XENC_VALIDATE_EXPLICIT	1
#define XENC_VALIDATE_IF	2
#define XENC_TRY_DECODE		4

#define xenc_signal_error(c,v,m) \
	if (err_ret) { \
	  *err_ret = srv_make_new_error (c, v, "%s", m); \
          return NULL; \
	} else { \
	  sqlr_new_error (c, v, "%s", m); \
	}

caddr_t *
xmlenc_get_keys (wsse_ctx_t * ctx)
{
  dk_set_t set = NULL;
  caddr_t * ret = (caddr_t *) list (2, 0, 0);
  xenc_dec_t * enc = ctx->wc_dec;
  dsig_signature_t * dsig = ctx->wc_dsig;

  DO_SET (xenc_enc_key_t *, enc_key, &enc->xed_keys)
    {
      if (enc_key->xeke_super_key)
	dk_set_push (&set, (void *) box_dv_short_string (enc_key->xeke_super_key));
    }
  END_DO_SET ();

  /* array of names of the data encryption keys */
  ret[0] = list_to_array (dk_set_nreverse (set));

  if (dsig && dsig->dss_key && dsig->dss_key->xek_name)
    {
      xenc_key_t * skey = dsig->dss_key;
      caddr_t * ksig = (caddr_t *) list (2, 0, 0);
      ksig[0] = box_dv_short_string (skey->xek_name);
      if (skey->xek_x509_KI)
        {
	  xenc_key_t * rkey = xenc_get_key_by_keyidentifier (skey->xek_x509_KI, 1);
	  if (rkey != skey && !rkey->xek_is_temp)
	    ksig[1] = box_dv_short_string (rkey->xek_name);
        }
      if (0 == ksig[1])
	ksig[1] = NEW_DB_NULL;
      /* name and matching key from local key store for xml signature */
      ret[1] = (caddr_t) ksig;
    }
  else
    ret[1] = NEW_DB_NULL;

  return ret;
}

/* xenc_decrypt internal function */
caddr_t
xmlenc_decrypt_soap (caddr_t * qst, char * xml_text, long soap_version, long validate_sign,
                     const char * enc, lang_handler_t *lh, caddr_t * err_ret, caddr_t * opts,
		     caddr_t *rkeys)
{
  wsse_ctx_t * ctx;
  xenc_err_code_t c = 0;
  char * errm = 0;
  caddr_t * doc ;
  caddr_t * envelope;
  caddr_t * header;
  caddr_t * security;
  caddr_t * signature;
  int is_valid_secxml = 0, try_decode = (validate_sign & 4);
  char * decrypted_xml_text = NULL;
  dk_session_t *decrypted_xml;
  wsse_ser_ctx_t sctx, *pctx = &sctx;

  memset (&sctx, 0, sizeof (wsse_ser_ctx_t));
  doc = (caddr_t *) xml_make_tree ((query_instance_t*) qst, xml_text, err_ret, (char *) enc, lh, 0);

  if (!doc)
    {
      xenc_signal_error ("42000", "XENC29", "Could not parse XML document, call xml_validate_dtd() for details");
    }

  validate_sign = validate_sign & 3;

  envelope = xml_find_child (doc, "Envelope", WSS_SOAP_URI, 0, NULL);
  if (!envelope)
    goto ret;

  header = xml_find_child (envelope, "Header", WSS_SOAP_URI, 0,NULL);
  if (!header)
    {
      if (try_decode) /* no security info, no signal */
	{
	  dk_free_tree ((box_t) doc);
	  return NULL;
	}
      else
	goto ret;
    }

  if (NULL == (security = xml_find_one_child (header, "Security", wsse_uris, 0, NULL)))
    {
      if (try_decode) /* no security info, no signal */
	{
	  dk_free_tree ((box_t) doc);
	  return NULL;
	}
      else
	goto ret;
    }

  signature = xml_find_child (security, "Signature", DSIG_URI, 0, NULL);
  if (validate_sign == XENC_VALIDATE_EXPLICIT && !signature)
    goto ret;

  is_valid_secxml = 1;

  ctx = wsse_ctx_allocate();
  ctx->wc_opts = opts;

  XENC_TRY (&ctx->wc_tb)
    {
      wsse_build_wsse_objects (security, wsse_get_callback (ctx, WSSE_URI(pctx) , "Security"), ctx);
      wsse_resolve_encrypted_keys (envelope, ctx);
    }
  XENC_CATCH
    {
      char errbuf[1024];
      xenc_make_error (errbuf, 1024, ctx->wc_tb.xtb_err_code, ctx->wc_tb.xtb_err_buffer);
      wsse_ctx_free (ctx);
      xenc_signal_error ("42000", "XENC30", errbuf);
    }
  XENC_TRY_END (&ctx->wc_tb);

  decrypted_xml = strses_allocate();

  if (xenc_decrypt_xml ((query_instance_t*) qst, ctx->wc_dec, xml_text, (caddr_t) enc,
	lh, decrypted_xml, &c, &errm))
    {
      char buf[1024];
      xenc_make_error (buf, 1024, c, errm);
      dk_free_box (errm);
      wsse_ctx_free (ctx);
      strses_free (decrypted_xml);
      xenc_signal_error ("42000", "XENC31", buf);
    }

  decrypted_xml_text = strses_string (decrypted_xml);

  if (validate_sign != XENC_VALIDATE_NONE && signature)
    if (dsig_check_xml ((query_instance_t*) qst, ctx->wc_dsig, xml_text, strlen (xml_text), &c, &errm, 1))
      {
	char buf[1024];
	wsse_ctx_free (ctx);
	xenc_make_error (buf, 1024, c, errm);
	dk_free_box (errm);
	dk_free_box (decrypted_xml_text);
	xenc_signal_error ("42000", "XENC32", buf);
      }
  if (rkeys)
    {
      *rkeys = (caddr_t) xmlenc_get_keys (ctx);
    }
  wsse_ctx_free (ctx);
  strses_free (decrypted_xml);
 ret:
  dk_free_tree ((box_t) doc);
  if (!is_valid_secxml)
    {
      xenc_signal_error ("42000", "XENC33", "XML document is not encrypted SOAP message");
    }

  return decrypted_xml_text;
}

/* this procedure takes xml text as first parameter, security entity as second
   decrypts and verifies it. Returns decrypted xml document as result */

/* bif_xmlenc_decrypt_soap
   @xml text
   @soap version
   @check signature
   @encoding
   @language
   @options
   @keys used
*/
caddr_t bif_xmlenc_decrypt_soap (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char * xml_text = bif_string_arg (qst, args, 0, "xenc_decrypt");
  long soap_version = bif_long_arg (qst, args, 1, "xenc_decrypt");
  long validate_sign = bif_long_arg (qst, args, 2, "xenc_decrypt");
  caddr_t enc = bif_string_arg (qst, args, 3, "xenc_decrypt");
  lang_handler_t *lh = lh_get_handler (bif_string_arg (qst, args, 4, "xenc_decrypt"));
  caddr_t opts = BOX_ELEMENTS(args) > 5 ? bif_strict_array_or_null_arg (qst, args, 5, "xenc_decrypt") : NULL;
  caddr_t ret, rkeys = NULL;

  ret = xmlenc_decrypt_soap (qst, xml_text, soap_version, validate_sign, enc, lh, err_ret,
      (caddr_t *)opts, &rkeys);

  if (BOX_ELEMENTS(args) > 6 && ssl_is_settable (args[6]))
    {
      if (!rkeys)
	rkeys = NEW_DB_NULL;
      qst_set (qst, args[6], rkeys);
    }
  else
    {
      dk_free_tree (rkeys);
    }

  return ret;
}

void wsse_report_error (struct wsse_ctx_s * ctx, char * code, int buflen, ...)
{
  ptrlong erridx;
  buflen += 512;
  /* WSSE_ASSERT (ctx->wc_is_try_block); */

 again:
  erridx = ecm_find_name (code, (void*) wsse_error_templs,
      wsse_error_templs_len, sizeof (struct wsse_error_templ_s));

  if (erridx != -1)
    {
      struct wsse_error_templ_s * wsse_err = wsse_error_templs + erridx;
      va_list tail;
      char * tmpbuf = (char *) dk_alloc (buflen);
      char * tmphead = tmpbuf;
      int rc;
      memset (tmpbuf, 0, buflen);

      memcpy (tmphead, code, strlen (code));
      tmphead += strlen (tmphead);

      tmphead[0] = '\t';
      tmphead++;

      va_start (tail, buflen);
      rc = vsnprintf (tmphead, buflen - strlen (code) - 1, wsse_err->templ, tail);
      if (rc > buflen)
	GPF_T1("Not enough buffer length for writing");
      va_end (tail);

      ctx->wc_tb.xtb_err_code = WSSE_ERR;
      ctx->wc_tb.xtb_err_buffer = box_dv_short_string (tmpbuf);
      dk_free (tmpbuf, buflen);
    }
  else
    {
      code = WSSE_UNKNOWN_CODE;
      goto again;
    }
#if 0
  if (xenc_test_processing())
    return;
#endif
  XENC_SIGNAL_FATAL (&ctx->wc_tb);
}

void wsse_check_built_encrypted_key (xenc_key_t * key, wsse_ctx_t * ctx)
{
  if (!key)
    wsse_report_error (ctx, WSSE_NO_ENC_KEY, 0);
  if (!key->xek_name)
    wsse_report_error (ctx, WSSE_CORRUPTED_ENC_KEY, strlen ("Key Name"), "Key Name");
  if (!key->xek_enc_algo)
    wsse_report_error (ctx, WSSE_CORRUPTED_ENC_KEY, strlen ("Algorithm"), "Algorithm");
  if (!key->xek_sign_algo)
    wsse_report_error (ctx, WSSE_CORRUPTED_ENC_KEY, strlen ("Algorithm"), "Algorithm");
}

/* returns encrypted key instance */
xenc_key_t * xenc_build_encrypted_key (const char * carried_name, dk_session_t * in,
				       const char * algo_name,  xenc_try_block_t * t)
{
  unsigned char * key_raw_data;
  xenc_key_t * key;
  int len;

  key_raw_data = (unsigned char *)strses_string (in);
#ifdef DEBUG
  printf ("\n%s\n", key_raw_data);
#endif
  mutex_enter (xenc_keys_mtx);

  if (carried_name)
    key = xenc_key_create (carried_name , algo_name, algo_name, 0);
  else
    key = xenc_key_create (0, algo_name, algo_name, 0);

  if (!key)
    goto error_end;

  switch (key->xek_type)
    {
    case DSIG_KEY_3DES:
      /* len = decode_base64 (key_raw_data, key_raw_data + box_length (key_raw_data) - 1); */
      len = strses_length (in);
      if (len != 192 / 8) /* 192 = 64 * 3 */
	{
	  xenc_key_remove (key, 0);
	  dk_free_box ((box_t) key_raw_data);
	  mutex_leave (xenc_keys_mtx);
	  xenc_report_error (t, 500 + strlen (algo_name), XENC_ENCKEY_ERR, "Serialized triple_des key %s has wrong size %ld", carried_name ? carried_name : "", len * 8);
	}
      xenc_key_3des_init (key, key_raw_data, key_raw_data + 8, key_raw_data + 16);
      break;
#ifdef AES_ENC_ENABLE
    case DSIG_KEY_AES:
      /* len = decode_base64 (key_raw_data, key_raw_data + box_length (key_raw_data) - 1); */
      len = strses_length (in);
      if (!carried_name && 0 == key->ki.aes.bits && algo_name)
	{
	  if (!strcmp (algo_name, XENC_AES128_ALGO))
	    key->ki.aes.bits = 128;
	  else if (!strcmp (algo_name, XENC_AES192_ALGO))
	    key->ki.aes.bits = 192;
	  else if (!strcmp (algo_name, XENC_AES256_ALGO))
	    key->ki.aes.bits = 256;
	}
      if (len != key->ki.aes.bits / 8)
	{
	  xenc_key_remove (key, 0);
	  dk_free_box ((box_t) key_raw_data);
	  mutex_leave (xenc_keys_mtx);
	  xenc_report_error (t, 500 + strlen (algo_name), XENC_ENCKEY_ERR, "Serialized AES key %s has wrong size", carried_name ? carried_name : "");
	}
      key->ki.aes.k = (unsigned char *) dk_alloc (key->ki.aes.bits / 8 /* number of bits in a byte */);
      memset (key->ki.aes.iv, 0, sizeof (key->ki.aes.iv));
      memcpy (key->ki.aes.k, key_raw_data, key->ki.aes.bits / 8 /* bits in one byte */);
      break;
#endif
    default:;
      /* do nothing */
    }
error_end:
  dk_free_box ((box_t) key_raw_data);

  mutex_leave (xenc_keys_mtx);

  if (!key)
    xenc_report_error (t, 500 + strlen (algo_name), XENC_ALGO_ERR, "Could not create key with algorithm %s",
		       algo_name);
  WSSE_ASSERT (key);
  return key;
}

/* builds uninitialized signature from xml template */
dsig_signature_t * dsig_template_ (query_instance_t * qi, caddr_t signature_xml_text, xenc_try_block_t * t, caddr_t * opts)
{
  id_hash_t * nss = 0;
  xml_tree_ent_t * xte = (xml_tree_ent_t *) xml_make_tree_with_ns (qi, signature_xml_text,
	0, "UTF-8", lh_get_handler ("x-any"), &nss, 0);
  wsse_ctx_t * ctx;
  caddr_t * signature;
  dsig_signature_t * dsig;

  if (!xte)
    xenc_report_error (t, 500, DSIG_TEMPL_ERR, "Could not parse signature template xml");

  signature = xml_find_child (xte->xte_current, "Signature", DSIG_URI, 0, 0);
  if (!signature)
    {
      dk_free_box ((box_t) xte); nss_free (nss);
      xenc_report_error (t, 500, DSIG_TEMPL_ERR, "xml doc is not signature template xml");
    }

  ctx = wsse_ctx_allocate();
  ctx->wc_allow_empty_vals = 1;
  ctx->wc_opts = opts;

  XENC_TRY (&ctx->wc_tb)
    {
      wsse_build_wsse_objects (signature, wsse_get_callback (ctx, DSIG_URI , "Signature"), ctx);
    }
  XENC_CATCH
    {
      char errbuf[1024];
      dk_free_box ((box_t) xte);
      nss_free (nss);
      xenc_make_error (errbuf, 1024, ctx->wc_tb.xtb_err_code, ctx->wc_tb.xtb_err_buffer);
      wsse_ctx_free (ctx);

      xenc_report_error (t, 500 + strlen (errbuf), DSIG_TEMPL_ERR, errbuf);
    }
  XENC_TRY_END(&ctx->wc_tb);

  dsig = ctx->wc_dsig;
  ctx->wc_dsig = 0;

  wsse_ctx_free (ctx);

  dk_free_box ((box_t) xte);
  nss_free (nss);
  return dsig;
}

/* test of wsse_err */
#ifdef DEBUG



void xmlenc_check_ecm_array (void * array, ptrlong len, size_t elem_size)
{
  ptrlong i = 0;
  for (i=0;i<len;i++)
    {
      char * name = ((char **) ((char*) array + i * elem_size))[0];
      ptrlong idx = ecm_find_name ( (const utf8char*) name, array, len, elem_size);
      if (idx != i)
	{
	  xenc_assert (0);
	  rep_printf ("--> %s <--\n", name);
	}
    }
}

void xmlenc_check_ecm_arrays ()
{
  xmlenc_check_ecm_array ((void *) wsse_error_templs, wsse_error_templs_len, sizeof (struct wsse_error_templ_s));
  xmlenc_check_ecm_array ((void *) wsse_dsig_callbacks, wsse_dsig_callbacks_len, sizeof (wsse_callback_item_t));
  xmlenc_check_ecm_array ((void*) wsse_xenc_callbacks, wsse_xenc_callbacks_len, sizeof (wsse_callback_item_t));
  xmlenc_check_ecm_array ((void*) wsse_callbacks, wsse_callbacks_len, sizeof (wsse_callback_item_t));
}

void xmlenc_test_wsse_error ()
{
  wsse_ctx_t * ctx = dk_alloc (sizeof (wsse_ctx_t));
  ctx->wc_is_try_block = 1;

  wsse_report_error (ctx, "100", 1024);
  printf ("%s\n",ctx->wc_tb.xtb_err_buffer);
  xenc_assert (!strcmp (ctx->wc_tb.xtb_err_buffer, "100	no algorithm specified"));
  dk_free_box (ctx->wc_tb.xtb_err_buffer);

  wsse_report_error (ctx, "101", 1024, "helo");
  printf ("%s\n",ctx->wc_tb.xtb_err_buffer);
  xenc_assert (!strcmp (ctx->wc_tb.xtb_err_buffer, "101	unknown digest algorithm helo"));
  dk_free_box (ctx->wc_tb.xtb_err_buffer);
  wsse_report_error (ctx, "102", 1024);
  printf ("%s\n",ctx->wc_tb.xtb_err_buffer);
  xenc_assert (!strcmp (ctx->wc_tb.xtb_err_buffer, "102	digest value is not specified"));
  dk_free_box (ctx->wc_tb.xtb_err_buffer);
  wsse_report_error (ctx, "103", 1024);
  printf ("%s\n",ctx->wc_tb.xtb_err_buffer);
  xenc_assert (!strcmp (ctx->wc_tb.xtb_err_buffer, "000	unknown error"));
  dk_free_box (ctx->wc_tb.xtb_err_buffer);
  wsse_report_error (ctx, "104", 1024);
  printf ("%s\n",ctx->wc_tb.xtb_err_buffer);
  xenc_assert (!strcmp (ctx->wc_tb.xtb_err_buffer, "104	no XPath expression specified"));
  dk_free_box (ctx->wc_tb.xtb_err_buffer);
  wsse_report_error (ctx, "105", 1024);
  printf ("%s\n",ctx->wc_tb.xtb_err_buffer);
  xenc_assert (!strcmp (ctx->wc_tb.xtb_err_buffer, "105	signature value is not specified"));
  dk_free_box (ctx->wc_tb.xtb_err_buffer);
  wsse_report_error (ctx, "106", 1024, "helo");
  printf ("%s\n",ctx->wc_tb.xtb_err_buffer);
  xenc_assert (!strcmp (ctx->wc_tb.xtb_err_buffer, "106	tag is unknown helo"));
  dk_free_box (ctx->wc_tb.xtb_err_buffer);
  fflush (stdout);
  dk_free (ctx, sizeof (wsse_ctx_t));

  /* dsig_is_signature_root test */
  xenc_assert (xml_is (DSIG_URI ":Signature", DSIG_URI, "Signature"));
  xenc_assert (!xml_is (DSIG_URI ":Signature", DSIG_URI, "Signatureeeeee"));
  xenc_assert (!xml_is (DSIG_URI ":Barbarrossa", DSIG_URI, "Signature"));
  xenc_assert (!xml_is (XENC_URI "#:Signature", DSIG_URI, "Signature"));
  xenc_assert (!xml_is (":Signature", DSIG_URI, "Signature"));
  xenc_assert (!xml_is (":Sign", DSIG_URI, "Signature"));
  xenc_assert (!xml_is ("", DSIG_URI, "Signature"));
  xenc_assert (!xml_is (":", DSIG_URI, "Signature"));

  xenc_asserts_print_report (stderr);
}

#endif /* DEBUG */


#endif /* _SSL */


