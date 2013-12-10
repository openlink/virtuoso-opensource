/*
 *  xmlenc.h
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
 *
 */

#ifndef XMLENC_ALGO_H
#define XMLENC_ALGO_H
#include <openssl/opensslv.h>
#if (OPENSSL_VERSION_NUMBER < 0x00907000L)
/*#warning aes is not supported*/
#else
#define AES_ENC_ENABLE
#endif

#include <openssl/evp.h>
#include <openssl/dsa.h>
#include <openssl/rsa.h>
#include <openssl/des.h>

#ifdef AES_ENC_ENABLE
#include <openssl/aes.h>
#endif

#include <openssl/x509.h>
#include <openssl/rand.h>

#if defined (SHA256_DIGEST_LENGTH)
#define SHA256_ENABLE
#endif


#include "libutil.h"
#include "soap.h"

#ifdef _KERBEROS
#include <krb5.h>
#include <gssapi/gssapi.h>
#include <gssapi/gssapi_generic.h>
#include <gssapi/gssapi_krb5.h>
#endif


/* uris */
/* from Web Services Security Addendum */
#if 0
#define WSS_SOAP_URI	"http://www.w3.org/2001/12/soap-envelope"
#else
#define WSS_SOAP_URI	SOAP_URI (11)
#endif
#define WSS_DSIG_URI	  "http://www.w3.org/2000/09/xmldsig#"
#define WSS_XENC_URI	  "http://www.w3.org/2001/04/xmlenc#"
#define WSS_M_URI	  "http://schemas.xmlsoap.org/rp"

/* security extensions for SOAP variants */
#define WSS_WSS_URI	  "http://schemas.xmlsoap.org/ws/2002/12/secext"
#define WSS_WSS_URI_0204  "http://schemas.xmlsoap.org/ws/2002/04/secext"
#define WSS_WSS_URI_0207  "http://schemas.xmlsoap.org/ws/2002/07/secext"
#define WSS_WSS_URI_OASIS "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"

/* utilities variants */
#define WSS_WSU_URI	  "http://schemas.xmlsoap.org/ws/2002/07/utility"
#define WSS_WSU_URI_OASIS "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd"

/* XML Schema */
#define WSS_XSD_URI	  "http://www.w3.org/2001/XMLSchema"

#define XENC_URI WSS_XENC_URI
#define DSIG_URI WSS_DSIG_URI

/* aliases */
#define WSSE_URI(sctx) (sctx ? wsse_uris[(sctx)->wsc_wsse] : WSS_WSS_URI)
#define WSU_URI(sctx)  (sctx ? wsu_uris[(sctx)->wsc_wsu] : WSS_WSU_URI)

extern char * wsse_uris[]; /* defined in xmlenc.c */
extern char * wsu_uris[];

typedef enum {
  WSS0212 = 0,
  WSS0204,
  WSS0207,
  WSOASIS
} WSSE_TYPE_T;

typedef enum {
  WSU0207 = 0,
  WSUOASIS
} WSU_TYPE_T;


#define XENC_NS			XENC_URI
#define XENC_NAMESPACE_STR	"xmlns:xenc=\"" XENC_NS "\""
#define DSIG_NS			DSIG_URI
#define DSIG_PRX		"ds"
#define DS_NAMESPACE_STR	"xmlns:" DSIG_PRX "=\"" DSIG_NS "\""

#define XENC_ELEMENT_NS		XENC_NS "Element"


/* algos */
#define DSIG_RSA_URI	"http://www.w3.org/2000/09/xmldsig#rsa"
#define XML_CANON_EXC_ALGO	"http://www.w3.org/2001/10/xml-exc-c14n#"
#define XML_CANON_EXC_20010315_ALGO	"http://www.w3.org/TR/2001/REC-xml-c14n-20010315"

#define XENC_BASE64_ALGO	"http://www.w3.org/2001/04/xmlenc#base64"
#define XENC_TRIPLEDES_ALGO	"http://www.w3.org/2001/04/xmlenc#tripledes-cbc"
#define XENC_DES3_ALGO		"http://www.w3.org/2001/04/xmlenc#tripledes-cbc"
/* key transport */
#define XENC_RSA_ALGO		"http://www.w3.org/2001/04/xmlenc#rsa-1_5"
#define XENC_DSA_ALGO		"http://www.w3.org/2001/04/xmlenc#dsa"
#define XENC_DH_ALGO		"http://www.w3.org/2001/04/xmlenc#dh"

/* block encryption */
#define XENC_3DES_ALGO		"http://www.w3.org/2001/04/xmlenc#tripledes-cbc"
#define XENC_AES128_ALGO	"http://www.w3.org/2001/04/xmlenc#aes128-cbc"
#define XENC_AES192_ALGO	"http://www.w3.org/2001/04/xmlenc#aes192-cbc"
#define XENC_AES256_ALGO	"http://www.w3.org/2001/04/xmlenc#aes256-cbc"

#define DSIG_RSA_URI		"http://www.w3.org/2000/09/xmldsig#rsa"
#define XENC_TRIPLEDES_ALGO	"http://www.w3.org/2001/04/xmlenc#tripledes-cbc"
#define DSIG_SHA1_ALGO		"http://www.w3.org/2000/09/xmldsig#sha1"
#define DSIG_SHA256_ALGO	"http://www.w3.org/2000/09/xmldsig#sha256"

#define DSIG_RSA_SHA1_ALGO	"http://www.w3.org/2000/09/xmldsig#rsa-sha1"
#define DSIG_RSA_SHA256_ALGO	"http://www.w3.org/2000/09/xmldsig#rsa-sha256"
#define DSIG_DSA_SHA1_ALGO	"http://www.w3.org/2000/09/xmldsig#dsa-sha1"
#define DSIG_DH_SHA1_ALGO	"http://www.w3.org/2000/09/xmldsig#dh-sha1"
#define DSIG_DH_SHA256_ALGO	"http://www.w3.org/2000/09/xmldsig#dh-sha256"

#define DSIG_HMAC_SHA1_ALGO  	"http://www.w3.org/2000/09/xmldsig#hmac-sha1"
#define DSIG_HMAC_SHA256_ALGO  	"http://www.w3.org/2000/09/xmldsig#hmac-sha256"

/* transforms */
#define DSIG_ENVELOPED_SIGNATURE_ALGO	"http://www.w3.org/2000/09/xmldsig#enveloped-signature"
/* only for internal purposes */
#define DSIG_FAKE_URI_TRANSFORM_ALGO	"fake://www.openlinksw.com/xmldsig#uri"

#define DSIG_XPATH_TRANSFORM_NS	"http://www.w3.org/TR/1999/REC-xpath-19991116"

#define DSIG_TEST_ALGO		"http://localhost/xmldsig#test"

/* fake declaration, only for internal usage */
#define DSIG_KEY_UNSET_URI	"http://www.openlinksw.com/dsig#unset"


#define WSSE_X509_VALUE_TYPE	"wsse:X509v3"
#define WSSE_KERBTGT_VALUE_TYPE	"wsse:Kerberosv5TGT"
#define WSSE_KERBTGS_VALUE_TYPE	"wsse:Kerberosv5ST"

/* OASIS attributes */
#define OASIS_BASE_URI "http://docs.oasis-open.org/wss/2004/01/"
#define WSSE_OASIS_X509_VALUE_TYPE 		OASIS_BASE_URI "oasis-200401-wss-x509-token-profile-1.0#X509v3"
#define WSSE_OASIS_X509_SUBJECT_KEYIDENTIFIER   OASIS_BASE_URI "oasis-200401-wss-x509-token-profile-1.0#X509SubjectKeyIdentifier"
#define WSSE_OASIS_X509_REFERENCE OASIS_BASE_URI "oasis-200401-wss-x509-token-profile-1.0#X509v3"
#define WSSE_OASIS_BASE64_ENCODING_TYPE OASIS_BASE_URI "oasis-200401-wss-soap-message-security-1.0#Base64Binary"
#define WSSE_OASIS_UTOKEN_PROFILE OASIS_BASE_URI "oasis-200401-wss-username-token-profile-1.0"


#define TA_XENC_ERR_BUFFER	1098
#define TA_XENC_ERR_CODE	1099

/* xenc_err_code_t codes */
#define DSIG_CHECK_ERR		200
#define DSIG_TEMPL_ERR		201

#define XENC_UNKNOWN_ALGO_ERR	300
#define XENC_WRITE_ERR		301
#define XENC_ALGO_ERR		302
#define XENC_WRONG_XML_DOC	303
#define XENC_DIFF_KEYS_ALGO_ERR	304
#define XENC_UNKNOWN_SUPER_KEY_ERR	305
#define XENC_UNKNOWN_ID_ERR	306
#define XENC_ENCKEY_ERR		307
#define XENC_PURE_KEY_ERR	308
#define XENC_ID_ERR		309
#define XENC_ENC_ERR		310
#define XENC_REF_EMPTY_ERR	311
#define XENC_UNKNOWN_KEY_ERR	312

#define WSSE_ERR		400

#define xenc_keys _xenc_keys()
#define xenc_certificates _xenc_certificates()
#define xenc_temp_keys _xenc_temp_keys()
id_hash_t * _xenc_certificates (void);

typedef struct {
  int  seed_len;
  int  secret_len;
  char A[20];
  /* Pseudo-elements:
     char seed[seed_len];
     char secret[secret_len];
     The algorithm requires that seed immediately follows A */
} P_SHA1_CTX;


struct xenc_key_s;
typedef struct xenc_key_s xenc_key_t;
typedef ptrlong xenc_err_code_t;

typedef struct xenc_try_block_s
{
  jmp_buf_splice	xtb_buf;
  xenc_err_code_t	xtb_err_code;
  char *		xtb_err_buffer;
} xenc_try_block_t;

typedef int (*xenc_encryptor_f) (dk_session_t * ses_in, long len, dk_session_t * ses_out,
				 xenc_key_t * key, xenc_try_block_t * tb);

typedef int (*xenc_decryptor_f) (dk_session_t * ses_in, long len, dk_session_t * ses_out,
				 xenc_key_t * key, xenc_try_block_t * tb);

typedef int (*dsig_digest_f) (dk_session_t * ses_in, long len, caddr_t * digest_out);

typedef int (*dsig_sign_f) (dk_session_t * ses_in, long len, xenc_key_t * key, caddr_t * sign_out);
typedef int (*dsig_verify_f) (dk_session_t * ses_in, long len, xenc_key_t * key, caddr_t digest);

typedef int (*dsig_transform_f) (query_instance_t * qi, dk_session_t * ses_in, long len,
				 dk_session_t * ses_out, caddr_t transform_data);

typedef int (*dsig_canon_f) (dk_session_t * ses_in, long len, dk_session_t * ses_out);

typedef int (*dsig_canon_2_f) (query_instance_t * qi, caddr_t *  doc_tree, caddr_t * siginfo_tree,
			       id_hash_t * nss, dk_session_t * ses_out);

typedef xenc_key_t * (*xenc_generator_f) (void);

typedef enum {
  DSIG_KEY_RSA = 1,
  DSIG_KEY_DSA = 2,
  DSIG_KEY_3DES = 3,
  DSIG_KEY_AES = 4,
  DSIG_KEY_KERBEROS = 5,
  DSIG_KEY_DH = 6,
  DSIG_KEY_RAW = 15 /* base64 encoded */
} DSIG_KEY_TYPE;

typedef struct xenc_algo_s
{
  char *		xea_ns;
  char *		xea_name;
  DSIG_KEY_TYPE		xea_key_type;
  xenc_encryptor_f	xea_enc;
  xenc_decryptor_f	xea_dect;
  xenc_generator_f	xea_gen;
} xenc_algo_t;

typedef enum {
  UTOK_PASSWORD_TEXT = 0,
  UTOK_PASSWORD_DIGEST,
  UTOK_PASSWORD_NONE
} XENC_UTOK_TYPE;

typedef struct u_tok_s
{
  caddr_t 	uname;
  caddr_t 	pass;
  caddr_t 	nonce;
  caddr_t	ts;
  XENC_UTOK_TYPE type;
} u_tok_t;

typedef uuid_t * xenc_id_t;

#define xek_rsa ki.rsa.rsa_st
#define xek_private_rsa ki.rsa.private_rsa_st
#define xek_dsa ki.dsa.dsa_st
#define xek_private_dsa ki.dsa.private_dsa_st
#define xek_kerberos_tgs ki.kerb.tkt
#define xek_dh ki.dh.dh_st
#define xek_private_dh ki.dh.private_dh_st

struct xenc_key_s
{
  char *	xek_name;
  xenc_algo_t *	xek_enc_algo;
  xenc_algo_t * xek_sign_algo;

  DSIG_KEY_TYPE	xek_type;
  union {
    struct dsig_rsa_keyinfo_s
    {
      RSA*	rsa_st;
      RSA*	private_rsa_st;
      unsigned  char pad;
    } rsa;
    struct dsig_dsa_keyinfo_s
    {
      DSA*	dsa_st;
      DSA*	private_dsa_st;
    } dsa;
    struct dsig_des3_keyinfo_s
    {
      des_cblock k1;
      des_cblock k2;
      des_cblock k3;

      des_key_schedule ks1;/* key schedule */
      des_key_schedule ks2;/* key schedule (for ede) */
      des_key_schedule ks3;/* key schedule (for ede3) */

      des_cblock iv;
#define PKCS5_SALT_LEN			8
      unsigned char salt[PKCS5_SALT_LEN];
    } triple_des;
#ifdef AES_ENC_ENABLE
    struct dsig_aes_keyinfo_s
    {
      /* key */
      unsigned char *	k;
      int		bits;
      unsigned char	iv[16];
    } aes;
#endif
#ifdef _KERBEROS
    struct dsig_kerberos_s
    {
      char *		service_name;
      gss_ctx_id_t	context;
      caddr_t		tkt;
    } kerb;
#endif
    struct dsig_dh_keyinfo_s
    {
      DH*	dh_st;
      DH*	private_dh_st;
    } dh;
    struct  dsig_raw_keyinfo_s
    {
      unsigned char *   k;
      int               bits;
    } raw;
  } ki; /* union is select by xek_type */
  EVP_PKEY *	xek_evp_key;
  EVP_PKEY *	xek_evp_private_key;
  X509 *	xek_x509;
  xenc_id_t	xek_x509_ref;
  caddr_t	xek_x509_ref_str;
  caddr_t	xek_x509_KI; /* subject key identifier, optional */
  caddr_t	xek_kerb_KI; /* ? ? ? kerberos key identifier, optional */
  u_tok_t *	xek_utok;
  int 		xek_is_temp;
};

struct xenc_key_inst_s;
typedef struct xenc_key_inst_s xenc_key_inst_t;


struct xenc_key_inst_s
{
  char *		xeki_key_name;
  xenc_key_inst_t *	xeki_super_key_inst;/* Indicates that this key
					       instance (this*) must be
					       encrypted also by super key */
  xenc_id_t *		xeki_ids;
};

typedef char * xenc_reference_t;

typedef struct xenc_enc_key_s
{
  char *		xeke_name;
  char *		xeke_enc_method;
  char *		xeke_super_key;

  char *		xeke_carried_key_name;
  caddr_t		xeke_cipher_value;
  dk_set_t		xeke_refs; /* xenc_reference_t */

  xenc_key_t *		xeke_encrypted_key;
  int			xeke_is_raw;
} xenc_enc_key_t;


typedef struct xenc_doc_s
{
  id_hash_t		xed_keys; /* key instances */
  xml_tree_ent_t *	xed_doc;
} xenc_doc_t ;

typedef struct xpath_keyinst_s xpath_keyinst_t;

typedef struct xenc_enc_s
{
  dk_set_t		xed_keis; /* key instances */
} xenc_enc_t;

typedef struct xenc_dec_s
{
  dk_set_t		xed_keys; /* xenc_enc_key_t */
  dk_set_t		xed_cert_ids; /* char*s */
} xenc_dec_t;

/* Signature declarations */
typedef struct dsig_transform_s
{
  char *		dst_name;
  caddr_t		dst_data; /* additional data for transform */
} dsig_transform_t;

typedef struct dsig_reference_s
{
  dk_set_t	 	dsr_transforms; /* type dsig_transform_f */
  char *		dsr_digest_method;
  char *		dsr_uri;
  char *		dsr_type;
  char *		dsr_id;
  char *		dsr_digest; /* computed by method below */
  char *		dsr_text; /* result of reference */
} dsig_reference_t;

typedef enum {
  XENC_T_DEFAULT = 0,
  XENC_T_X509_CERT = 1
} XENC_VALUE_TYPE_T;

typedef struct dsig_signature_s
{
  char *	dss_canon_method;
  char *	dss_signature_method;
  dk_set_t	dss_refs; /* type dsig_reference_t */
  char *	dss_signature; /* computed by dss_signature_method */
  char *	dss_signature_1;

  xenc_key_t *	dss_key;
  XENC_VALUE_TYPE_T dss_key_value_type;
} dsig_signature_t;

typedef struct dsig_compare_s
{
  char *	dsc_obj;
  char *	dsc_value1;
  char *	dsc_value2;
} dsig_compare_t;

/* WSSE declarations */

typedef char* wsse_error_t;

/* where KeyInfo can appear */
typedef enum {
  XENC_T_ENCKEY = 1,
  XENC_T_DSIG = 2,
  XENC_T_ENCCTX = 3,
  XENC_T_SECURITY = 4
} XENC_TYPE_T;

typedef struct wsse_ser_ctx_s
{
  WSSE_TYPE_T		wsc_wsse;
  WSU_TYPE_T		wsc_wsu;
} wsse_ser_ctx_t;


typedef struct wsse_ctx_s
{
  dsig_signature_t *	wc_dsig;
  dsig_reference_t *	wc_curr_ref;
  dsig_transform_t *	wc_curr_transform;

  xenc_dec_t *		wc_dec;
  xenc_enc_key_t *	wc_curr_enckey;

  xenc_key_t *		wc_key;

  XENC_TYPE_T		wc_object_type;
  int			wc_allow_empty_vals; /*!< allow some uninitialized values, which will be resolved later */

  id_hash_t *		wc_id_cache;

  caddr_t *		wc_opts;

  int			wc_is_try_block;
  xenc_try_block_t	wc_tb;
} wsse_ctx_t;

struct xpath_keyinst_s;
struct subst_item_s;

typedef struct xml_doc_subst_s
{
  xml_tree_ent_t *	xs_doc;
#if 0
  caddr_t *		xs_origs; /* tree elements */
  caddr_t *		xs_copies; /* texts */
#endif
  struct subst_item_s *	xs_subst_items;
  caddr_t *		xs_discard;
  caddr_t *		xs_envelope;
  caddr_t *		xs_new_child_tags;
  int			xs_soap_version;
  int			xs_sign;
  id_hash_t *		xs_namespaces;
  dk_set_t		xs_parent_link;
} xml_doc_subst_t;



void dsig_free (dsig_signature_t * dsig);
dsig_signature_t * dsig_copy_draft (dsig_signature_t * dsig);
/* pre: dsig must be empty. All algorithms must be valid.
   post: fills dsig object, only DigestValue remains untouched.

   exceptions: no
*/
xenc_err_code_t dsig_initialize (query_instance_t * qi, dk_session_t * doc, long xml_ses_len,
	dsig_signature_t * dsig, xenc_err_code_t * c, char ** err);


int dsig_compare (dsig_signature_t * d1, dsig_signature_t * d2, dsig_compare_t * cmp);

int dsig_digest_algo_create (const char* xmln, dsig_digest_f f);
int dsig_sign_algo_create (const char * xmln, dsig_sign_f f);
int dsig_verify_algo_create (const char * xmln, dsig_verify_f f);

dsig_canon_f dsig_canon_f_get (const char * name, xenc_try_block_t * t);
dsig_canon_2_f dsig_canon_2_f_get (const char * name, xenc_try_block_t * t);
dsig_sign_f dsig_sign_f_get (const char * name, xenc_try_block_t * t);
dsig_verify_f dsig_verify_f_get (const char * name, xenc_try_block_t * t);
dsig_digest_f dsig_digest_f_get (const char * name, xenc_try_block_t * t);
dsig_transform_f dsig_transform_f_get (const char * name, xenc_try_block_t * t);

#include "xmlenc_algos.h"

#define XENC_WAR	1
#define XENC_ERR	2
#define XENC_FATAL	3

#define XENC_TRY(tb) { (tb)->xtb_err_code = 0; (tb)->xtb_err_buffer = 0; if (0 == setjmp_splice (&(tb)->xtb_buf))
#define XENC_CATCH else
#define XENC_TRY_END(tb) dk_free_box ( (tb)->xtb_err_buffer ); (tb)->xtb_err_buffer = 0; }
#define XENC_SIGNAL(tb,type) longjmp_splice (&(tb)->xtb_buf, type)
#define XENC_SIGNAL_WAR(tb) XENC_SIGNAL(tb, XENC_WAR)
#define XENC_SIGNAL_ERR(tb) XENC_SIGNAL(tb, XENC_ERR)
#define XENC_SIGNAL_FATAL(tb) XENC_SIGNAL(tb, XENC_FATAL)


void algo_stores_init (void);

caddr_t * signature_serialize_1 (dsig_signature_t * dsig, wsse_ser_ctx_t * sctx);

void xenc_make_error (char * buf,long  maxlen, xenc_err_code_t c, const char * err);

void wsse_report_error (wsse_ctx_t * ctx, char * code, int buflen, ...);
void xenc_report_error (xenc_try_block_t * t, long buflen, xenc_err_code_t c, char * errbuf, ...);

xenc_err_code_t xenc_decrypt_xml (query_instance_t * qi, xenc_dec_t * enc, caddr_t in_xml, caddr_t encode,
				  lang_handler_t * lh,  dk_session_t * out_xml, xenc_err_code_t * c,
				  char ** err);

caddr_t * xenc_get_namespaces (caddr_t * curr, id_hash_t * namespaces);
caddr_t xml_doc_subst (xml_doc_subst_t * xs);
void xml_doc_subst_free(xml_doc_subst_t * xs);

xenc_key_t * xenc_build_encrypted_key (const char * carried_name, dk_session_t * in,
				       const char * algo_name,  xenc_try_block_t * t);
xenc_key_t * xenc_key_create (const char * name,  const char * enc_type, const char * sign_type, int lock);
dsig_signature_t * dsig_template_ (query_instance_t * qi, caddr_t signature_xml_text, xenc_try_block_t * t, caddr_t * opts);
caddr_t dsig_sign_signature_ (query_instance_t * qi, dsig_signature_t * dsig, caddr_t dsig_template, xenc_err_code_t * c, char ** c_err);
xenc_algo_t * xenc_algorithms_get (const char* name);
#ifdef MALLOC_DEBUG
caddr_t dbg_wsse_get_content_val (DBG_PARAMS caddr_t * tag);
#define wsse_get_content_val(tag) dbg_wsse_get_content_val (__FILE__,__LINE__,tag)
#else
caddr_t wsse_get_content_val (caddr_t * curr);
#endif


xenc_key_t * xenc_key_aes_create (const char * name, int keylen, const char * pwd);
void xenc_key_remove (xenc_key_t * key, int lock);
int __xenc_key_dsa_init (char *name, int lock, int num);
int __xenc_key_dh_init (char *name, int lock);

void xenc_key_3des_init (xenc_key_t * pkey, unsigned char * k1, unsigned char * k2, unsigned char * k3);
int xml_c_build_ancessor_ns_link (caddr_t * doc_tree, caddr_t * select_tree,
				  id_hash_t * nss, dk_set_t * parent_link);
xenc_key_t * xenc_get_key_by_name (const char * name, int protect);
void xenc_ids_hash_free (id_hash_t * ids);
void xenc_build_ids_hash (caddr_t * curr, id_hash_t ** id_hash, int only_encrypted_data);

caddr_t xmlenc_decrypt_soap (caddr_t * qst, char * xml_text, long soap_version, long validate_sign,
                     const char * enc, lang_handler_t *lh, caddr_t * err_ret, caddr_t * opts, caddr_t *rkeys);

xenc_key_t *certificate_decode (caddr_t encoded_cert, const char * value_type,
				 const char * encoding_type);
caddr_t xenc_x509_get_key_identifier (X509 * cert);
caddr_t xenc_x509_KI_base64 (X509 * cert);
caddr_t xenc_get_keyname_by_ki (caddr_t keyident);
xenc_key_t * xenc_get_key_by_keyidentifier (caddr_t keyident, int lock);
int xenc_algorithms_create (const char * ns0, const char * name,
			    xenc_encryptor_f enc,
			    xenc_decryptor_f dect,
			    DSIG_KEY_TYPE key_type);
caddr_t * xml_find_signedinfo (caddr_t * root, int is_wsse);
caddr_t * xml_find_signature (caddr_t * root, int is_wsse);
wsse_ctx_t * wsse_ctx_allocate (void);
void wsse_ctx_free (wsse_ctx_t * ctx);
caddr_t dsig_sign_signature (dsig_signature_t * dsig, xml_tree_ent_t * xte, id_hash_t * nss, wsse_ctx_t * ctx);
int xenc_encode_base64(char * input, char * output, size_t len);
int xenc_decode_base64(char * src, char * end);
xenc_key_t * xenc_key_create_from_utok (u_tok_t * utok, caddr_t seed, wsse_ctx_t * ctx);
void xenc_set_serialization_ctx (caddr_t try_ns_spec, wsse_ser_ctx_t * sctx);
caddr_t bif_xmlenc_decrypt_soap (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);
caddr_t bif_dsig_validate (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);
caddr_t xenc_get_option (caddr_t *options, const char * opt, char * def);
caddr_t certificate_encode (BIO * b, const char * encoding_type);
caddr_t * xml_find_any_child (caddr_t * curr, const char * name, const char * uri);

extern dk_mutex_t * xenc_keys_mtx;

#endif

