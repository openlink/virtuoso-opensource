/*
 *  xmlenc.c
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

#ifdef __cplusplus
extern "C" {
#endif
#include "xml_ecm.h"
#ifdef __cplusplus
}
#endif

#include "soap.h"
#include "xmlenc.h"

#ifdef __cplusplus
extern "C" {
#endif
#include "xmlparser.h"
#include "xmlparser_impl.h"
#ifdef __cplusplus
}
#endif
#include <openssl/evp.h>
#include <openssl/des.h>
#include <openssl/rand.h>
#include <openssl/bn.h>
#include <openssl/x509.h>
#include <openssl/x509v3.h>
#include <openssl/err.h>
#include <openssl/pem.h>

#include "http.h"
#include "libutil.h"
#include "bif_text.h"
#include "date.h"
#include "security.h"

#define XML_ELEMENT_NAME(x) \
  ((char *)( ((x) && DV_TYPE_OF (x) == DV_ARRAY_OF_POINTER && ((caddr_t *)(x))[0]) ? ((caddr_t **)(x))[0][0] : NULL))

#define SQLR_NEW_KEY_ERROR(name) \
      sqlr_new_error ("42000", "XENC04", "Key name <%s> is unknown", name)
#define SQLR_NEW_KEY_EXIST_ERROR(name) \
	sqlr_new_error ("42000", "XENC14", "Could not create %s key, possible reason - key with such name already exists", \
	name ? name : "temporary");

static X509_STORE * CA_certs = NULL;

static char WSSE_BASE64_ENCODING_TYPE[] = "wsse:Base64Binary";

#define XENC_BUF_SZ 80

#define xenc_id_free(id) dk_free_box(id)

#ifdef SHA256_ENABLE
#define	DEFAULT_SHA_DIGEST	"sha256"
#else
#define	DEFAULT_SHA_DIGEST	"sha1"
#endif

char * wsse_uris[] = { WSS_WSS_URI, WSS_WSS_URI_0204, WSS_WSS_URI_0207, WSS_WSS_URI_OASIS, NULL };
char * wsu_uris[] = { WSS_WSU_URI, WSS_WSU_URI_OASIS, NULL };

struct xpath_keyinst_s
{
  xml_tree_ent_t **	ents;
  xenc_key_inst_t *	keyinst;
  int			index;
  char *		tag_text;
  ptrlong		type_idx;
};

typedef struct subst_item_s
{
  caddr_t * orig;
  caddr_t * copy;
  ptrlong   type;
} subst_item_t;

id_hash_t * __xenc_keys;
id_hash_t * __xenc_certificates;
dk_set_t __xenc_temp_keys = 0;
dk_mutex_t * xenc_keys_mtx;

id_hash_t *
_xenc_keys (void)
{
  client_connection_t * cli = GET_IMMEDIATE_CLIENT_OR_NULL;
  user_t * usr;
  if (!cli || !cli->cli_user) /* revert to anonymous */
    return __xenc_keys;
  usr = cli->cli_user;
  if (!usr->usr_xenc_keys)
    usr->usr_xenc_keys = id_hash_allocate (231, sizeof (caddr_t), sizeof (caddr_t), strhash, strhashcmp);
  return usr->usr_xenc_keys;
}

id_hash_t *
_xenc_certificates (void)
{
  client_connection_t * cli = GET_IMMEDIATE_CLIENT_OR_NULL;
  user_t * usr;
  if (!cli || !cli->cli_user) /* revert to anonymous */
    return __xenc_certificates;
  usr = cli->cli_user;
  if (!usr->usr_xenc_certificates)
    usr->usr_xenc_certificates = id_hash_allocate (231, sizeof (caddr_t), sizeof (caddr_t), strhash, strhashcmp);
  return usr->usr_xenc_certificates;
}

dk_set_t *
_xenc_temp_keys (void)
{
  client_connection_t * cli = GET_IMMEDIATE_CLIENT_OR_NULL;
  user_t * usr;
  if (!cli || !cli->cli_user) /* revert to anonymous */
    return &(__xenc_temp_keys);
  usr = cli->cli_user;
  return &(usr->usr_xenc_temp_keys);
}

static void
xenc_temp_keys_clear (void)
{
  client_connection_t * cli = GET_IMMEDIATE_CLIENT_OR_NULL;
  user_t * usr;
  if (!cli || !cli->cli_user) /* revert to anonymous */
    {
      dk_set_free (__xenc_temp_keys);
      __xenc_temp_keys = 0;
    }
  else
    {
      usr = cli->cli_user;
      dk_set_free (usr->usr_xenc_temp_keys);
      usr->usr_xenc_temp_keys = 0;
    }
}

void uuid_set (uuid_t * u);

static xenc_id_t DBG_NAME (_xenc_id) (DBG_PARAMS uuid_t * uu_id)
{
  uuid_t * uu = (uuid_t *) DBG_NAME (dk_alloc_box) (DBG_ARGS sizeof (uuid_t), DV_BIN);
  memcpy (uu, uu_id, sizeof (uuid_t));
  return (xenc_id_t) uu;
}

static xenc_id_t DBG_NAME (xenc_next_id) (DBG_PARAMS_0)
{
  uuid_t * uu = (uuid_t *) DBG_NAME (dk_alloc_box) (DBG_ARGS sizeof (uuid_t), DV_BIN);
#ifdef DEBUG
  static int id_count = 0;
  memset (uu, 0, sizeof (uuid_t));
  ((int*) uu)[0] = ++id_count;
#else
  uuid_set (uu);
#endif
  return (xenc_id_t) uu;
}

#ifdef MALLOC_DEBUG
#define xenc_next_id() dbg_xenc_next_id (__FILE__, __LINE__)
#define _next_id() dbg__next_id (__FILE__, __LINE__)
#define _xenc_id(uu_id) dbg__xenc_id (__FILE__, __LINE__, uu_id)
#endif

caddr_t * fuse_arrays (caddr_t ** parr, caddr_t * arr2, dtp_t dtp);
xenc_key_t * xenc_get_key_by_name (const char * name, int protect);
caddr_t * xenc_generate_security_tags (query_instance_t* qi, xpath_keyinst_t ** arr,
				       dsig_signature_t * dsig, int gen_ref_list, caddr_t * err_ret,
				       wsse_ser_ctx_t * sctx);

static
void xenc_security_token_id_format (char * buf, int maxlen, xenc_id_t id, int is_ref);

caddr_t bif_dsig_a_test (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);

xenc_algo_t *	xenc_algos = 0;
ptrlong		xenc_algos_len = 0;

/* temp declarations */
/* xmlenc_algos.c */

typedef char * xenc_type_t;

xenc_type_t xenc_types[] =
{
  "Content",
  "Document",
  "Element"
};

ptrlong xenc_types_len = sizeof (xenc_types) / sizeof (xenc_type_t);

ptrlong XENCTypeContentIdx = -1; /* initialized in bif_xmlenc_init procedure */
ptrlong XENCTypeDocumentIdx = -1; /* initialized in bif_xmlenc_init procedure */
ptrlong XENCTypeElementIdx = -1; /* initialized in bif_xmlenc_init procedure */

static void check_ents (xml_tree_ent_t** ents, int arg, const char* funname)
{
  int inx;
  if (DV_TYPE_OF (ents) != DV_ARRAY_OF_POINTER)
    goto fail;

  DO_BOX (xml_tree_ent_t *, ent, inx, ents)
    {
      if (DV_TYPE_OF (ent) != DV_XML_ENTITY)
	goto fail;
    }
  END_DO_BOX;

  return;
fail:
  sqlr_new_error ("42000", "XENC01", "Argument %d of %s must be an array of entity", arg, funname);
}

static void check_key_instance (xenc_key_inst_t * kei, int arg, char* func)
{
  if (!kei)
    sqlr_new_error ("42000", "XENC02", "No key instance specified in %s procedure", func);

  while (kei)
    {
      if ( (DV_TYPE_OF (kei) != DV_ARRAY_OF_POINTER) ||
	   (BOX_ELEMENTS (kei) != 3) ||
	   ((DV_TYPE_OF (kei->xeki_key_name) != DV_C_STRING) &&
	    (DV_TYPE_OF (kei->xeki_key_name) != DV_STRING)))
	sqlr_new_error ("42000", "XENC03",
			  "Argument %d of %s is not key instance (%s)", arg + 1, func, kei->xeki_key_name);

      if (!xenc_get_key_by_name (kei->xeki_key_name, 1))
	SQLR_NEW_KEY_ERROR (kei->xeki_key_name);
      kei = kei->xeki_super_key_inst;
    }
}

caddr_t xenc_get_option (caddr_t *options, const char * opt, char * def)
{
  int ix;
  if (!options)
    return def;
  DO_BOX (caddr_t, elm, ix, options)
    {
      if (!strcmp (elm, opt))
	return options[ix+1];
      ix++;
    }
  END_DO_BOX;
  return def;
}


#define SES_WRITE(ses, str) \
	session_buffered_write (ses, str, strlen (str))

caddr_t xenc_encrypt (caddr_t src, xenc_key_inst_t * key)
{
  int len = box_length (src);
  dtp_t dtp = DV_TYPE_OF (src);
  caddr_t dest;
  dk_session_t * ss;

  if (IS_STRING_DTP(dtp) || dtp == DV_C_STRING)
    len--;

  dest = dk_alloc_box(len * 2 + 1, DV_STRING);
  /* len = encode_base64 ((char *)src, (char *)dest, len); */
  GPF_T;
  *(dest+len) = 0;

  ss = strses_allocate ();
  SES_WRITE (ss, "<xenc:EncryptedData id='i1' ");
  SES_WRITE (ss, XENC_NAMESPACE_STR);
  SES_WRITE (ss, ">\n");

  SES_WRITE (ss, "\t<xenc:EncryptionMethod Algorithm='");
  SES_WRITE (ss, XENC_BASE64_ALGO);
  SES_WRITE (ss, "'/>\n");

  SES_WRITE (ss, "\t<xenc:CipherData><xenc:CipherValue>\n");
  SES_WRITE (ss, dest);
  SES_WRITE (ss, "\n\t</xenc:CipherValue></xenc:CipherData>\n");
  SES_WRITE (ss, "</xenc:EncryptedData>\n");

  dk_free_box (dest);
  dest = strses_string (ss);
  strses_free (ss);

  return dest;
}


caddr_t
bif_xenc_encrypt (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  xml_tree_ent_t ** ents = (xml_tree_ent_t**) bif_arg (qst, args, 0, "xenc_encrypt");
  xenc_key_inst_t * key = (xenc_key_inst_t *) bif_arg (qst, args, 1, "xenc_encrypt");
  caddr_t src;
  int inx;
  dk_session_t * ses = strses_allocate ();
  dk_set_t l = 0;
  caddr_t ret;

  check_ents (ents, 1, "xenc_encrypt");

  DO_BOX (xml_tree_ent_t *, ent, inx, ents)
    {
      caddr_t src_enc;
      xte_serialize ((xml_entity_t*) ent, ses);
      src = strses_string (ses);
      strses_flush (ses);

      src_enc = xenc_encrypt (src, key);
      if (src_enc)
	dk_set_push (&l, src_enc);
      dk_free_box (src);
    }
  END_DO_BOX;

  l = dk_set_nreverse (l);
  ret = (caddr_t) dk_set_to_array (l);
  dk_set_free (l);
  return ret;
}


void xml_doc_subst_free (xml_doc_subst_t * xs)
{
  dk_free (xs, sizeof (xml_doc_subst_t));
}


close_tag_t *
bx_pop_ct (caddr_t *qst, dk_session_t * out, close_tag_t * ct, wcharset_t *src_charset, int child_num);

caddr_t * xenc_get_namespaces (caddr_t * curr, id_hash_t * namespaces)
{
  caddr_t ** nss = namespaces ? (caddr_t **) id_hash_get (namespaces, (caddr_t) (&curr)) : 0;
  if (nss)
    return nss[0];
  else
    return 0;
}

void xenc_set_namespaces (caddr_t * curr, caddr_t * nss, id_hash_t * h)
{
  id_hash_set (h, (caddr_t) & curr, (caddr_t) & nss);
}

void xenc_nss_add_namespace_prefix (id_hash_t * namespaces, caddr_t * tag,
	const char * uri, const char * prefix)
{
  /* namespace must indicated at root of xml document */
  caddr_t * nss = xenc_get_namespaces (tag, namespaces);
  caddr_t * new_nss = 0;

  new_nss = (caddr_t*) dk_alloc_box ((nss ? box_length (nss) : 0) + 2 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  if (nss)
    memcpy (new_nss + 2, nss, box_length (nss));
  new_nss[0] = box_dv_short_string (prefix);
  new_nss[1] = box_dv_short_string (uri);
  dk_free_box ((box_t) nss);
  xenc_set_namespaces (tag, new_nss, namespaces);
}

/*
   when do a canonization, make sure that
   namespace with same prefix is not occur in ancestor link
 */
static int ns_is_in_ancestor (dk_set_t nss1, caddr_t pref, caddr_t uri)
{
  dk_set_t namespaces = nss1 ? nss1->next : NULL;
  DO_SET (caddr_t *, nss, &namespaces)
    {
      if (nss)
	{
	  int i;
	  for (i = 0; i < BOX_ELEMENTS_INT (nss); i+=2)
	    {
	      caddr_t ns_pref = nss[i];
	      caddr_t ns_uri = nss[i + 1];
	      if (!strcmp (ns_pref, pref) && !strcmp (ns_uri, uri))
		{
		  return 1;
		}
	    }
	}
    }
  END_DO_SET();
  return 0;
}

#if 0
static int ns_print_link (dk_set_t nss1)
{
  DO_SET (caddr_t *, nss, &nss1)
    {
      fprintf (stderr, "loop:\n");
      if (nss)
	{
	  int i;
	  for (i = 0; i < BOX_ELEMENTS (nss); i+=2)
	    {
	      caddr_t ns_pref = nss[i];
	      caddr_t ns_uri = nss[i + 1];
	      fprintf (stderr, "%s, %s\n", ns_pref, ns_uri);
	    }
	}
    }
  END_DO_SET();
  return 0;
}
#endif

void
xenc_bx_out_q_name (caddr_t * qst, dk_session_t * out, close_tag_t * ct, caddr_t name, int is_attr, wcharset_t *src_charset, dk_set_t namespaces)
{
  caddr_t pref = NULL;
  int ns_len;
  char * local = strrchr (name, ':');
  if (!local)
    {
      bx_out_value (qst, out, (db_buf_t) name, QST_CHARSET(qst), src_charset, DKS_ESC_PTEXT);
      if (!is_attr)
	{
	  caddr_t * nss = (caddr_t*) (namespaces ? namespaces->data : 0);
	  int i;
	  if (!nss)
	    return;
	  for (i = 0; i < BOX_ELEMENTS_INT (nss); i+=2)
	    {
	      if (nss[i])
		{
		  SES_PRINT (out, " xmlns:");
		  SES_PRINT (out, nss[i]);
		}
	      else
		SES_PRINT (out, " xmlns");

	      SES_PRINT (out, "=\"");
	      bx_out_value (qst, out, (db_buf_t) nss[i+1], QST_CHARSET(qst), src_charset, DKS_ESC_DQATTR);
	      SES_PRINT (out, "\"");
	    }
	}
      return;
    }
  ns_len = (long) local - (long) name;
  pref = (bx_std_ns_uri (name, ns_len) ? uname_xml : NULL);
  if (!pref)
    {
      DO_SET (caddr_t *, nss, &namespaces)
	{
	  if (nss)
	    {
	      int i;
	      for (i = 0; i < BOX_ELEMENTS_INT (nss); i+=2)
		{
		  caddr_t ns = nss[i + 1];

		  if (strlen (ns) != ns_len)
		    continue;
		  if (!strncmp (ns, name, ns_len))
		    {
		      if (nss[i][0])
		      pref = box_dv_short_string (nss[i]);
		      goto end_search;
		    }
		}
	    }
	}
      END_DO_SET();
    }

 end_search:
  if (pref)
    {
      dks_esc_write  (out, pref, strlen (pref), QST_CHARSET (qst), CHARSET_UTF8, DKS_ESC_PTEXT);
      session_buffered_write_char (':', out);
      dk_free_box (pref);
    }
  dks_esc_write (out, local + 1, strlen (local + 1), QST_CHARSET (qst), CHARSET_UTF8, DKS_ESC_PTEXT);

  if (!is_attr)
    {
      caddr_t * nss = (caddr_t*) ( namespaces ? namespaces->data : 0);
      int i;
      if (nss)
	{
	  for (i = 0; i < BOX_ELEMENTS_INT (nss); i+=2)
	    {
	      int print_uri;
	      print_uri = 1;
	      if (nss[i] && nss[i][0] != 0)
		{
		  if (!ns_is_in_ancestor (namespaces, nss[i], nss[i+1]))
		    {
		      SES_PRINT (out, " xmlns:");
		      SES_PRINT (out, nss[i]);
		    }
		  else
		    print_uri = 0;
		}
	      else
		{
		  SES_PRINT (out, " xmlns");
		}
	      if (print_uri)
		{
		  SES_PRINT (out, "=\"");
		  bx_out_value (qst, out, (db_buf_t) nss[i+1], QST_CHARSET(qst), src_charset, DKS_ESC_DQATTR);
		  SES_PRINT (out, "\"");
	        }
	    }
	}
    }
}

void
xenc_bx_tree_start_tag  (caddr_t * qst, dk_session_t * ses, caddr_t * tag,
    close_tag_t ** ct_ret, int child_num, int output_mode,
    html_tag_descr_t *tag_descr, int is_xsl, wcharset_t *tgt_charset, wcharset_t *src_charset, dk_set_t namespaces)
{
  int inx, len = BOX_ELEMENTS (tag);
  caddr_t name = tag[0];
  bx_push_ct (ct_ret, 0, box_copy (name), NULL);
  SES_PRINT (ses, "<");
  xenc_bx_out_q_name (qst, ses, *ct_ret, name, 0, src_charset, namespaces);
  for (inx = 1; inx < len; inx += 2)
    {
      if (' ' == tag[inx][0])
	continue;
      SES_PRINT (ses, " ");
      xenc_bx_out_q_name (qst, ses, *ct_ret, tag[inx], 1, src_charset, namespaces);
      SES_PRINT (ses, "=\"");
#if 0
      if (is_xsl && xsl_is_qnames_attr (tag[inx]))
	{
	  int qnames_inx;
	  DO_BOX (caddr_t, qname, qnames_inx, ((caddr_t *)tag[inx + 1]))
	    {
	      if (qnames_inx)
		session_buffered_write_char (' ', ses);
	      bx_out_value (qst, ses, (db_buf_t) qname, tgt_charset, src_charset,
		(DKS_ESC_DQATTR | (IS_HTML_OUT(output_mode) ? DKS_ESC_COMPAT_HTML : 0)));
	    }
	  END_DO_BOX;
	}
      else
#endif
#if 1
      if (xml_is_sch_qname (tag[0], tag[inx]) ||
	       xml_is_soap_qname (tag[0], tag[inx]) ||
	       xml_is_wsdl_qname (tag[0], tag[inx]))
	xenc_bx_out_q_name (qst, ses, *ct_ret, tag[inx + 1], 2, src_charset, namespaces);
#endif
      else
	bx_out_value (qst, ses, (db_buf_t) tag[inx + 1], tgt_charset, src_charset,
	  (DKS_ESC_DQATTR | (IS_HTML_OUT(output_mode) ? DKS_ESC_COMPAT_HTML : 0)));
      SES_PRINT (ses, "\"");
    }
#if 0
  if (child_num)
    SES_PRINT (ses, ">");
  else
    SES_PRINT (ses, "/>");
#endif
  SES_PRINT (ses, ">");
}

close_tag_t *
xenc_bx_pop_ct (caddr_t *qst, dk_session_t * out, close_tag_t * ct, wcharset_t *src_charset, int child_num, dk_set_t namespaces)
{
  close_tag_t * tmp = ct->ct_prev;
  dk_set_t explicit_bottom, default_bottom;
  if (DV_STRINGP (ct->ct_trailing))
    bx_out_value (qst, out, (db_buf_t) ct->ct_trailing, QST_CHARSET(qst), src_charset, DKS_ESC_PTEXT);
  if (ct->ct_name)
    {
      SES_PRINT (out, "</");
      xenc_bx_out_q_name (qst, out, ct, ct->ct_name, 3, src_charset, namespaces);
      SES_PRINT (out, ">");
    }
  dk_free_box (ct->ct_name);
  dk_free_box (ct->ct_trailing);
  if (NULL == tmp)
    explicit_bottom = default_bottom = NULL;
  else
    {
      explicit_bottom = tmp->ct_all_explicit_ns;
      default_bottom = tmp->ct_all_default_ns;
    }
  while (ct->ct_all_explicit_ns != explicit_bottom)
    dk_free_box (dk_set_pop (&(ct->ct_all_explicit_ns)));
  while (ct->ct_all_default_ns != default_bottom)
    dk_free_box (dk_set_pop (&(ct->ct_all_default_ns)));
  dk_free ((caddr_t) ct, sizeof (close_tag_t));
  return tmp;
}

void
xenc_node_subst (caddr_t * current, dk_session_t * ses, xte_serialize_state_t * xsst)
{
  xml_doc_subst_t * xs = (xml_doc_subst_t *) xsst->xsst_data;
  long inx;
  dtp_t dtp = DV_TYPE_OF (current);
  char *data;
  int is_root = 0;
  caddr_t * content = 0;
  int len = xs->xs_subst_items ? box_length (xs->xs_subst_items)/sizeof (subst_item_t) : 0;

  if (xs->xs_discard == current)
    return;

  for (inx = 0; inx < len; inx++)
    {
      subst_item_t * item = xs->xs_subst_items + inx;
      if (item->orig == current)
	{
	  if (item->type == XENCTypeContentIdx)
	    content = item->copy;
	  else
	    {
	      session_buffered_write (ses, (char*)item->copy, strlen ((char*)item->copy));
	      return;
	    }
	}
    }

  if (DV_STRINGP (current))
    {
      dks_esc_write (ses, (char *) current,
	  box_length ((caddr_t) current) - 1, xsst->xsst_charset, CHARSET_UTF8, xsst->xsst_dks_esc_mode);
    }

  if (DV_ARRAY_OF_POINTER == dtp)
    {
      caddr_t *head = XTE_HEAD (current);
      caddr_t name = XTE_HEAD_NAME (head);
      int len = BOX_ELEMENTS (current);
      html_tag_descr_t curr_tag;
      memset (&curr_tag, 0, sizeof(html_tag_descr_t));
      if (' ' == name[0])
	{
	  if (uname__pi == name)
	    {
	      size_t head_len = BOX_ELEMENTS (head);
	      SES_PRINT (ses, "<?");
	      if (head_len > 2)
		SES_PRINT (ses, head[2]);
	      else
		session_buffered_write_char (' ', ses);
	      data = (len > 1) ? current[1] : NULL;
	      if ((NULL != data) && data[0])
		{
		  SES_PRINT (ses, " ");
		  SES_PRINT (ses, data);
		}
	      SES_PRINT (ses, xsst->xsst_out_method == OUT_METHOD_HTML ? ">" : "?>");
	      return ;
	    }
	  if (uname__comment == name)
	    {
	      SES_PRINT (ses, "<!--");
	      if (len > 1)
		SES_PRINT (ses, ((caddr_t *) current)[1]);
	      else
		session_buffered_write_char (' ', ses);
	      SES_PRINT (ses, "-->");
	      return ;
	    }
	  if (uname__ref == name)
	    {
	      SES_PRINT (ses, "&");
	      if (BOX_ELEMENTS (((caddr_t *) current)[0]) > 2)
		dks_esc_write (ses, ((caddr_t **) current)[0][2],
		    strlen (((caddr_t **) current)[0][2]), xsst->xsst_charset, CHARSET_UTF8, DKS_ESC_PTEXT);
	      SES_PRINT (ses, ";");
	      return ;
	    }
	  if (uname__disable_output_escaping == name)
	    {
	      if (len > 1)
		dks_esc_write (ses,
		    (char *) current[1],
		    box_length ((caddr_t) current[1]) - 1,
		    xsst->xsst_charset, CHARSET_UTF8, DKS_ESC_NONE);
	      return;
	    }
	  if (uname__attr == name)
	    return;
	  is_root = (uname__root == name);
	}
      if (!is_root)
	{
	  xenc_bx_tree_start_tag (xsst->xsst_qst, ses, (caddr_t *) current[0], &(xsst->xsst_ct),
		len - 1,  xsst->xsst_out_method, &curr_tag, 0, xsst->xsst_charset, CHARSET_UTF8,
		xs->xs_parent_link);
	}
      if (content)
	session_buffered_write (ses, (char*)content, strlen ((char*)content));
      else if ((len > 1) && !curr_tag.htmltd_is_empty)
	{
	  for (inx = 1; inx < len; inx++)
	    {
	      caddr_t * nss = xenc_get_namespaces ( (caddr_t*) current[inx], xs->xs_namespaces);
	      dk_set_push (&xs->xs_parent_link, nss);
	      xenc_node_subst ((caddr_t *) current[inx], ses, xsst);
	      dk_set_pop (&xs->xs_parent_link);
	    }
	}
      if (!is_root)
	{
          int childs = curr_tag.htmltd_is_empty ? 0 : len - 1;
	  xsst->xsst_ct = xenc_bx_pop_ct (xsst->xsst_qst, ses, xsst->xsst_ct, CHARSET_UTF8, childs, xs->xs_parent_link);
	}
    }
  return ;
}

caddr_t xml_doc_subst (xml_doc_subst_t * xs)
{
  dk_session_t * ses;
  xml_tree_ent_t * xte = xs->xs_doc;
  xml_entity_t * xe = (xml_entity_t*) xte;
  xte_serialize_state_t xsst;
  caddr_t text;
  caddr_t * header;
  caddr_t * new_header = 0;
  int inx;
  xsst.xsst_entity = (struct xml_tree_ent_s *) xte;
  xsst.xsst_cdata_names = xe->xe_doc.xd->xout_cdata_section_elements;
  xsst.xsst_ns_2dict = xe->xe_doc.xd->xd_ns_2dict;
  xsst.xsst_ct = NULL;
  xsst.xsst_qst = (caddr_t *) xe->xe_doc.xd->xd_qi;
  xsst.xsst_charset = NULL;
  xsst.xsst_do_indent = 0;
  xsst.xsst_indent_depth = 0;
  xsst.xsst_in_block = 0;
  xsst.xsst_dks_esc_mode = DKS_ESC_PTEXT;
  xsst.xsst_hook = 0;
  xsst.xsst_data = (void*) xs;

  xsst.xsst_out_method = OUT_METHOD_TEXT;

  /*  xsst.xsst_do_indent = xte->xe_doc.xtd->xout_indent; */

  if (xs->xs_envelope && xs->xs_new_child_tags)
    {
      header = xml_find_child (xs->xs_envelope, "Header", WSS_SOAP_URI, 0, NULL);
      if (header)
	{
	  new_header = (caddr_t *) dk_alloc_box (
	      box_length (header) + box_length (xs->xs_new_child_tags), DV_ARRAY_OF_POINTER);
	  memcpy (new_header, header, box_length (header));
	  memcpy (new_header + BOX_ELEMENTS (header), &xs->xs_new_child_tags, box_length (xs->xs_new_child_tags));
	  DO_BOX (caddr_t *, child, inx, xs->xs_envelope)
	    {
	      if (child == header)
		((caddr_t**)xs->xs_envelope)[inx] = new_header;
	    }
	  END_DO_BOX;
	}
      else
	dk_free_tree ((box_t) xs->xs_new_child_tags);
    }

  xsst.xsst_charset = wcharset_by_name_or_dflt (xte->xe_doc.xtd->xout_encoding, NULL);
  ses = strses_allocate ();
  {
    caddr_t * nss = xenc_get_namespaces (xte->xte_current, xs->xs_namespaces);
    /* when at top of parent link we have same namespaces,
       then it's already there; no need to put it twice
       furthermore that will screw-up detection of repeating NS declaration
       from ancestors.
     */
    if (xs->xs_parent_link && xs->xs_parent_link->data == nss)
      {
	xenc_node_subst (xte->xte_current, ses, &xsst);
      }
    else
      {
	dk_set_push (&xs->xs_parent_link, nss);
	xenc_node_subst (xte->xte_current, ses, &xsst);
	dk_set_pop (&xs->xs_parent_link);
      }
  }

  text = strses_string(ses);
  strses_free (ses);
#if 0
  if (new_header)
    dk_free_box (new_header);
#endif
  return text;
}

/* algorithm section */

/* test - base64 encoding, no key needed */

static
int xenc_base64_encryptor (dk_session_t * ses_in, long seslen, dk_session_t * ses_out,
			   xenc_key_t * key, xenc_try_block_t * t)
{
  char * buf = (char *) dk_alloc (seslen + 1);
  char * out_buf = (char *) dk_alloc (seslen * 2 + 1);
  int read_b;
  int tot_l = 0;
  int len;


  if (!seslen)
    return 0;

  CATCH_READ_FAIL (ses_in)
    {
      read_b = session_buffered_read (ses_in, buf, seslen);
    }
  FAILED
    {
      goto end;
    }
  END_READ_FAIL (ses_in);

  tot_l += read_b;

  buf[read_b] = 0;

  len = xenc_encode_base64 (buf, out_buf, read_b);

  CATCH_WRITE_FAIL (ses_out)
    {
      session_buffered_write (ses_out, (char *)out_buf, len);
    }
  FAILED
    {
      tot_l = 0;
      goto end;
    }
  END_WRITE_FAIL (ses_out);
 end:
  dk_free (buf, seslen + 1);
  dk_free (out_buf, seslen * 2 + 1);

  if (!tot_l && t)
    xenc_report_error (t, 500, XENC_ENC_ERR, "could not make base64 encryption");

  return tot_l;
}

static
int xenc_base64_decryptor (dk_session_t * ses_in, long seslen, dk_session_t * ses_out, xenc_key_t * key, xenc_try_block_t * t)
{
  int read_b;
  int len;
  char * buf = (char *) dk_alloc (seslen);

  CATCH_READ_FAIL (ses_in)
    {
      read_b  = session_buffered_read (ses_in, buf, seslen);
    }
  FAILED
    {
      END_READ_FAIL (ses_in);
      return 0;
    }
  END_READ_FAIL (ses_in);

  if (seslen != read_b)
    {
      dk_free (buf, seslen);
      return 0;
    }

  len = xenc_decode_base64(buf, buf + read_b);

  CATCH_WRITE_FAIL (ses_out)
    {
      session_buffered_write (ses_out, (char *)buf, len);
    }
  FAILED
    {
      END_WRITE_FAIL (ses_out);
      dk_free (buf, seslen);
      return 0;
    }
  END_WRITE_FAIL (ses_out);

  dk_free (buf, seslen);
  return len;
}


int
xenc_persist_key (xenc_key_t * k, caddr_t * qst, int store, caddr_t *err_ret)
{
  query_instance_t * qi = (query_instance_t *) qst;
  int idx = (store ? 0 : 1);
  static query_t * qr[2] = { NULL, NULL };
  static char *text[2] = { "DB.DBA.USER_KEY_STORE (user, ?, NULL, NULL, NULL)",
                           "DB.DBA.USER_KEY_DELETE (user, ?)" };

  caddr_t err = NULL;

  if (!qr[idx])
    {
      qr[idx] = sql_compile (text[idx], qi->qi_client, &err, SQLC_DEFAULT);
      if (SQL_SUCCESS != err)
	{
	  qr[idx] = NULL;
	  goto err;
	}

    }
  err = qr_rec_exec (qr[idx], qi->qi_client, NULL, qi, NULL, 1,
        ":0", k->xek_name, QRP_STR);
err:
  if (SQL_SUCCESS != err)
    {
      if (err_ret)
	*err_ret = err;
      return 0;
    }
  return 1;
}




typedef id_hash_t * xenc_collection_t;
xenc_collection_t xenc_collection ();
void * xenc_col_add_item (xenc_collection_t col, char * name, void * item);

#if 0
xenc_algo_t * xenc_algo_copy (xenc_algo_t * algo)
{
  NEW_VARZ(xenc_algo_t, copy);

  copy->xea_ns = box_copy (algo->xea_ns);
  copy->xea_name = box_copy (algo->xea_name);
  copy->xea_enc = algo->xea_enc; /* functions are never deleted */
  copy->xea_dect = algo->xea_dect; /* see above */
  copy->xea_gen = algo->xea_gen; /* see above */

  return copy;
}
#endif

xenc_algo_t * xenc_algorithms_get (const char* name)
{
  ptrlong idx = ecm_find_name (name, (void*) xenc_algos, xenc_algos_len, sizeof (xenc_algo_t));
  if (idx == -1)
    return 0;

  return xenc_algos + idx;
}

int xenc_algorithms_create (const char * ns0, const char * name,
			    xenc_encryptor_f enc,
			    xenc_decryptor_f dect,
			    DSIG_KEY_TYPE key_type)
{
  ptrlong idx;
  xenc_algo_t * algo;
  caddr_t ns = box_string (ns0);

  idx = ecm_add_name (ns, (void **) & xenc_algos, (ptrlong *) & xenc_algos_len, sizeof (xenc_algo_t));

  if (idx == -1)
    {
      dk_free_box (ns);
      return 0;
    }

  algo = xenc_algos + idx;

  algo->xea_name = box_string (name);
  algo->xea_enc = enc;
  algo->xea_dect = dect;
  algo->xea_gen = 0;
  algo->xea_key_type = key_type;
  return 1;
}


xenc_doc_t * xenc_doc_create (xml_tree_ent_t * doc_ent)
{
  xenc_doc_t * doc = (xenc_doc_t *) dk_alloc (sizeof (xenc_doc_t));
  memset (doc, 0, sizeof (xenc_doc_t));

  doc->xed_doc = doc_ent;
  return doc;
}

xenc_key_inst_t * xenc_create_key_instance (const char * name,
					    xenc_key_inst_t * super_key_inst)
{
  xenc_key_inst_t * key_inst = (xenc_key_inst_t *) dk_alloc_box (sizeof (xenc_key_inst_t), DV_ARRAY_OF_POINTER);
  memset (key_inst, 0, sizeof (xenc_key_inst_t));

  key_inst->xeki_key_name = box_string (name);
  key_inst->xeki_super_key_inst = (xenc_key_inst_t *) box_copy_tree ((box_t) super_key_inst);
  return key_inst;
}

caddr_t bif_xenc_key_inst_create (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t name = bif_string_arg (qst, args, 0, "xenc_key_inst_create");
  xenc_key_inst_t * super = 0;
  if (BOX_ELEMENTS (args) > 1)
    super = (xenc_key_inst_t *) bif_arg (qst, args, 1, "xenc_key_inst_create");

  if (super && ( DV_TYPE_OF (super) != DV_ARRAY_OF_POINTER ||
		 BOX_ELEMENTS (super) != 3))
    sqlr_new_error ("42000", "XENC05",
		    "Argument 2 of xenc_key_inst_create is not key instance");
  if (!xenc_get_key_by_name (name, 1))
    SQLR_NEW_KEY_ERROR (name);

  return (caddr_t) xenc_create_key_instance (name, super);
}

xenc_key_t * xenc_get_key_by_name (const char * name, int protect)
{
  xenc_key_t ** key_ptr;

  if (protect)
    mutex_enter (xenc_keys_mtx);

  key_ptr =  (xenc_key_t **)id_hash_get (xenc_keys, (caddr_t) & name);
  if (protect)
    mutex_leave (xenc_keys_mtx);
  if (!key_ptr)
    {
      return 0;
    }
  return key_ptr [0];
}

int xenc_store_key (xenc_key_t * key, int protect)
{
  if (protect) mutex_enter (xenc_keys_mtx);
  if (id_hash_get (xenc_keys, (caddr_t) & key->xek_name))
    {
      if (protect) mutex_leave (xenc_keys_mtx);
      return 0;
    }
  id_hash_set (xenc_keys, (caddr_t) & key->xek_name, (caddr_t) & key);
  if (protect) mutex_leave (xenc_keys_mtx);
  return 1;
}


/* xenc_keys_create
   if key_name is not null try to create key with key_name name,
   if key with such name is exists, returns zero

   if key_name is NULL, then the function try to find name for
   new key in form KEYXXX, where XXX is decimal numeric.
   if all KEYXXX are busy then function lpace message to log, and
   returns zero.
   in case of success, function returns new key for late initialization
*/
xenc_key_t * xenc_key_create (const char * key_name,
			      const char * enc_type /* algorithm */,
			      const char * sign_type /* algorithm */,
			      int lock)
{
  xenc_algo_t * enc_algo = xenc_algorithms_get (enc_type);
  xenc_algo_t * sign_algo = xenc_algorithms_get (sign_type);
  char * name = NULL;
  static int key_counter = 0;
  int full_cycle = 0;
  int internal_name = 0;
  if (!enc_algo || !sign_algo)
    {
      return 0;
    }

  if (lock) mutex_enter (xenc_keys_mtx);
  if (key_name)
    {
      name = box_dv_short_string (key_name);
    }
  else
    {
      internal_name = 1;
    again:
      dk_free_box (name); name = NULL;
      if (key_counter++ > 999)
	{
	  if (!full_cycle)
	    {
	      key_counter = 0;
	      full_cycle = 1;
	      goto again;
	    }
	  log_info ("too many encryption keys");
	  if (lock) mutex_leave (xenc_keys_mtx);
	  return 0;
	}
      name = dk_alloc_box ( 3 /* KEY */ + 4 /* XXXX number */ + 1 /* zero */, DV_SHORT_STRING);
      snprintf (name, box_length (name), "KEY%04d", key_counter);
      /*
      name[0] = 'K', name[1] = 'E', name[2] = 'Y', name[3] = key_counter / 1000 + '0';
      name[4] = (key_counter / 100) % 10 + '0';
      name[5] = (key_counter / 10) % 10 + '0';
      name[6] = (key_counter / 1) % 10 + '0';
      name[7] = 0;
      */
    }
  if (!xenc_get_key_by_name (name, 0))
    {
      NEW_VARZ (xenc_key_t, key);
      key->xek_name = name;
      key->xek_enc_algo = enc_algo;
      key->xek_sign_algo = sign_algo;
      key->xek_type = enc_algo->xea_key_type;
      xenc_store_key (key, 0);
      if (internal_name)
	{
	  key->xek_is_temp = 1;
	  dk_set_push (xenc_temp_keys, box_dv_short_string (key->xek_name));
	}
      if (lock) mutex_leave (xenc_keys_mtx);
      return key;
    }
  else if (internal_name)
    goto again;

  dk_free_box (name);
  if (lock) mutex_leave (xenc_keys_mtx);
  return 0;
}


void xenc_key_remove (xenc_key_t * key, int lock)
{
  if (lock) mutex_enter (xenc_keys_mtx);
  id_hash_remove (xenc_keys, (caddr_t) & key->xek_name);
  dk_free_box (key->xek_name);
  if (key->xek_x509_KI)
    {
      xenc_key_t * rkey = xenc_get_key_by_keyidentifier (key->xek_x509_KI, 0);
      if (rkey == key)
        id_hash_remove (xenc_certificates, (caddr_t) & key->xek_x509_KI);
      dk_free_box (key->xek_x509_KI);
    }
  dk_free_box ((box_t) key->xek_x509_ref);
  if (key->xek_x509_ref_str)
    {
      xenc_key_t * rkey = xenc_get_key_by_keyidentifier (key->xek_x509_ref_str, 0);
      if (rkey == key)
	id_hash_remove (xenc_certificates, (caddr_t) & key->xek_x509_ref_str);
      dk_free_box (key->xek_x509_ref_str);
    }
#ifdef AES_ENC_ENABLE
  if (key->xek_type == DSIG_KEY_AES)
    {
      dk_free (key->ki.aes.k, key->ki.aes.bits / 8 /* number of bits in byte */);
    }
#endif
  if (key->xek_type == DSIG_KEY_RAW)
    {
      dk_free_box (key->ki.raw.k);
    }
  if (key->xek_utok)
    {
      dk_free_box (key->xek_utok->uname);
      dk_free_box (key->xek_utok->pass);
      dk_free_box (key->xek_utok->nonce);
      dk_free_box (key->xek_utok->ts);
      dk_free (key->xek_utok, sizeof (u_tok_t));
    }
  dk_free (key, sizeof (xenc_key_t));
  if (lock) mutex_leave (xenc_keys_mtx);
}


static void
genrsa_cb(int p, int n, void *arg)
{
#ifdef LINT
  p=n;
#endif
}

int
__xenc_key_rsa_init (char *name)
{
  RSA *rsa = NULL;
  int num=1024;
  unsigned long f4=RSA_F4;
  int r;
  xenc_key_t * pkey = xenc_get_key_by_name (name, 1);
  if (NULL == pkey)
    SQLR_NEW_KEY_ERROR (name);

  rsa=RSA_generate_key(num,f4,genrsa_cb,NULL);
  r = RSA_check_key(rsa);
  pkey->ki.rsa.pad = RSA_PKCS1_PADDING;
  if (rsa == NULL)
    {
      sqlr_new_error ("42000", "XENC06",
		    "RSA parameters generation error");
    }
  pkey->xek_rsa = rsa;
  pkey->xek_private_rsa = rsa;
  return 0;
}


#define CERT_TYPE_PEM_FORMAT	1
#define CERT_TYPE_PKCS12_FORMAT	2
#define CERT_DER_FORMAT		3

static
int pass_cb(char *buf, int size, int rwflag, void *u)
{
  int len;
  if (!u)
    return 0;

  len = strlen ((char*)u);
  if (len  > size)
    len = size;

  memcpy(buf, u, len);

  return len;
}


void xenc_certificates_hash_add (caddr_t keyidentifier, xenc_key_t * k, int lock)
{
  if (lock) mutex_enter (xenc_keys_mtx);
  if (!id_hash_get (xenc_certificates, (caddr_t) & keyidentifier))
    id_hash_set (xenc_certificates, (caddr_t) & keyidentifier, (caddr_t) & k);
  if (lock) mutex_leave (xenc_keys_mtx);
}

static
caddr_t bif_delete_temp_keys (caddr_t * qst, caddr_t * err_r, state_slot_t ** args)
{
  int c = 0;
  mutex_enter (xenc_keys_mtx);
  DO_SET (char *, name, xenc_temp_keys)
    {
      xenc_key_t * k = xenc_get_key_by_name (name, 0);
      dk_free_box (name);
      if (k)
	{
	  c++;
	  xenc_key_remove (k, 0);
	}
    }
  END_DO_SET ();
  xenc_temp_keys_clear ();
  mutex_leave (xenc_keys_mtx);
  return box_num (c);
}


static
caddr_t bif_xenc_set_primary_key (caddr_t * qst, caddr_t * err_r, state_slot_t ** args)
{
  caddr_t name = bif_string_arg (qst, args, 0, "xenc_set_primary_key");
  xenc_key_t * k;
  mutex_enter (xenc_keys_mtx);
  k = xenc_get_key_by_name (name, 0);
  if (!k)
    {
      mutex_leave (xenc_keys_mtx);
      SQLR_NEW_KEY_ERROR (name);
    }
  if (!k->xek_x509 || !k->xek_x509_KI)
    {
      mutex_leave (xenc_keys_mtx);
      sqlr_new_error ("42000", "XENC07", "Key %s does not contain certificate", name);
    }
  id_hash_set (xenc_certificates, (caddr_t) & k->xek_x509_KI, (caddr_t) & k);
  mutex_leave (xenc_keys_mtx);
  return NEW_DB_NULL;
}


xenc_key_t * xenc_get_key_by_keyidentifier (caddr_t keyident, int lock)
{
  if (lock) mutex_enter (xenc_keys_mtx);
  if (keyident)
    {
      xenc_key_t ** k = (xenc_key_t **) id_hash_get (xenc_certificates, (caddr_t) &keyident);
      if (lock) mutex_leave (xenc_keys_mtx);
      if (k)
	return k[0];
      return 0;
    }
  if (lock) mutex_leave (xenc_keys_mtx);
  return 0;
}

#define VIRT_PASS_LEN 1024

static char *
xenc_get_password (char * name, char *tpass)
{
  char *tmp = NULL;
  char prompt[1024];
  snprintf (prompt, sizeof (prompt), "Enter a password for key \"%s\": ", name);
  if (0 == EVP_read_pw_string(tpass, VIRT_PASS_LEN, prompt, 0 /* no verify */))
    {
      tmp = strchr(tpass, '\n');
      if(tmp) *tmp = 0;
      tmp = tpass;
    }
  return tmp;
}

/* certificate MUST be non zero */
xenc_key_t * xenc_key_create_from_x509_cert (char * name, char * certificate, char * private_key_str,
					     const char * private_key_passwd, int is_digest, long type, long ask_pwd, int import_chain)
{
  xenc_key_t * k = 0;
  X509 *x509 = 0;
  EVP_PKEY *pkey = 0;
  EVP_PKEY *private_key = 0;
  BIO * b = BIO_new (BIO_s_mem());
  BIO * b_priv = 0;
  RSA * rsa = 0;
  RSA * private_rsa = 0;
  DSA * dsa = 0;
  DSA * private_dsa = 0;
  char * enc_algoname = 0;
  char * sign_algoname = 0;
  char tpass [VIRT_PASS_LEN];

  if (ask_pwd && !private_key_passwd)
    private_key_passwd = xenc_get_password(name, tpass);

  BIO_write (b, certificate, box_length (certificate) - 1);
  if (private_key_str)
    {
      b_priv = BIO_new (BIO_s_mem());
      BIO_write (b_priv, private_key_str, box_length (private_key_str) - 1);
    }


  if (type == CERT_TYPE_PEM_FORMAT) /* PEM format */
    {
#if OPENSSL_VERSION_NUMBER >= 0x00908000L
      x509 = (X509 *)PEM_ASN1_read_bio ((d2i_of_void *)d2i_X509,
					PEM_STRING_X509,
					b, NULL, NULL, NULL);
#else
      x509 = (X509 *)PEM_ASN1_read_bio ((char *(*)())d2i_X509,
					PEM_STRING_X509,
					b, NULL, NULL, NULL);
#endif
    }
  else if (type == CERT_TYPE_PKCS12_FORMAT) /* PKCS12 format */
    {
      PKCS12 *pk12 = NULL;
      STACK_OF(X509) *ca_list = NULL;
      pk12 = d2i_PKCS12_bio (b, NULL);
      PKCS12_parse (pk12, private_key_passwd, &private_key, &x509, import_chain ? &ca_list : NULL);
      if (ca_list && import_chain)
	{
	  int i;
	  mutex_enter (xenc_keys_mtx);
	  for (i = 0; i < sk_X509_num (ca_list) ; i++)
	    {
	      X509 * x = sk_X509_value (ca_list, i);
	      X509_STORE_add_cert (CA_certs, x);
	    }
	  mutex_leave (xenc_keys_mtx);
	  sk_free (ca_list);
	}
    }
  else if (type == CERT_DER_FORMAT)
    {
      x509 = d2i_X509_bio (b, NULL);
    }
  else
    {
      /* no idea what format it's */
      goto finish;
    }

  if (b_priv)
    {
#if OPENSSL_VERSION_NUMBER >= 0x00908000L
      private_key = PEM_read_bio_PrivateKey(b_priv, NULL, pass_cb, (void *) private_key_passwd);
#else
      private_key = (EVP_PKEY*)PEM_ASN1_read_bio ((char *(*)())d2i_PrivateKey,
					     PEM_STRING_EVP_PKEY,
					     b_priv,
					     NULL, pass_cb, (void *) private_key_passwd);
#endif
      if (!private_key)
	{
#if 0
	  unsigned long err;
	  while ((err = ERR_peek_error()) != 0)
	    {
	      log_error ("%s", ERR_reason_error_string(err));
	      ERR_get_error();
	    }
#endif
	goto finish;
    }
    }

  memset (tpass, 0, sizeof (tpass));

  if (x509)
    pkey=X509_extract_key(x509);

  if (pkey)
    {
      switch (EVP_PKEY_type (pkey->type))
	{
	case EVP_PKEY_DSA:
	  sign_algoname = DSIG_DSA_SHA1_ALGO;
	  enc_algoname = XENC_DSA_ALGO;
	  dsa = pkey->pkey.dsa;
	  private_dsa = private_key ? private_key->pkey.dsa : 0;
	  break;
	case EVP_PKEY_RSA:
	  sign_algoname = DSIG_RSA_SHA1_ALGO;
	  enc_algoname = XENC_RSA_ALGO;
	  rsa = pkey->pkey.rsa;
	  private_rsa = private_key ? private_key->pkey.rsa : 0;
	  break;
	default:
	  goto finish;
	}
      mutex_enter (xenc_keys_mtx);
      k = xenc_key_create (name, enc_algoname, sign_algoname, 0);
      if (!k)
	{
	  mutex_leave (xenc_keys_mtx);
	  goto finish;
	}
      if (rsa)
	{
	  k->xek_rsa = rsa;
	  k->xek_private_rsa = private_rsa;
	  /* check MUST be here */
	  /* RSA_check_key(rsa); */
	  k->ki.rsa.pad = RSA_PKCS1_PADDING;
	}
      else if (dsa)
	{
	  k->xek_dsa = private_dsa ? private_dsa : dsa;
	  k->xek_private_dsa = private_dsa;
	}
      k->xek_evp_key = pkey;
      k->xek_evp_private_key = private_key;
      k->xek_x509 = x509; x509 = 0;
      k->xek_x509_ref =  xenc_next_id ();
      {
	char out[255];
	xenc_security_token_id_format (out, sizeof (out), k->xek_x509_ref, 1);
	k->xek_x509_ref_str = box_dv_short_string (out);
	xenc_certificates_hash_add (k->xek_x509_ref_str, k, 0);
      }
      k->xek_x509_KI = xenc_x509_KI_base64 (k->xek_x509);
      if (k->xek_x509_KI)
	xenc_certificates_hash_add (k->xek_x509_KI, k, 0);

      pkey = 0;
      mutex_leave (xenc_keys_mtx);
    }
 finish:
  BIO_free (b);
  if (x509) X509_free(x509);
  EVP_PKEY_free(pkey);
  return k;
}

static void dh_cb(int p, int n, void *arg)
{
#ifdef LINT
  p=n;
#endif
}

static /*xenc_key_DSA_create */
caddr_t bif_xenc_key_dsa_create (caddr_t * qst, caddr_t * err_r, state_slot_t ** args)
{
  xenc_key_t * key;
  caddr_t name = bif_string_arg (qst, args, 0, "xenc_key_DSA_create");
  int num = BOX_ELEMENTS (args) > 1 ? (int) bif_long_arg (qst, args, 1, "xenc_key_DSA_create") : 512;
  mutex_enter (xenc_keys_mtx);
  if (NULL == (key = xenc_key_create (name, XENC_DSA_ALGO , DSIG_DSA_SHA1_ALGO, 0)))
    {
      mutex_leave (xenc_keys_mtx);
      SQLR_NEW_KEY_EXIST_ERROR (name);
    }
  __xenc_key_dsa_init (name, 0, num);
  /* xenc_store_key (key, 0); */
  mutex_leave (xenc_keys_mtx);
  return NULL;
}

static
caddr_t bif_xenc_key_DH_create (caddr_t * qst, caddr_t * err_r, state_slot_t ** args)
{
  xenc_key_t * key;
  caddr_t name = bif_string_arg (qst, args, 0, "xenc_key_DH_create");
  int g = BOX_ELEMENTS (args) > 1 ? bif_long_arg (qst, args, 1, "xenc_key_DH_create") : 2;
  int num = 512;
  caddr_t p = BOX_ELEMENTS (args) > 2 ? bif_arg (qst, args, 2, "xenc_key_DH_create") : NULL;
  DH *dh;

  if (g != 2 && g != 5)
     sqlr_new_error ("42000", "XENC11", "DH generator value could be 2 or 5");

  if (p != NULL && (DV_TYPE_OF (p) == DV_LONG_INT || DV_TYPE_OF (p) == DV_SHORT_INT))
    {
      num = unbox (p);
      p = NULL;
    }
  else if (p)
    {
      p = bif_string_arg (qst, args, 2, "xenc_key_DH_create");
    }

  if (num <= 0)
     sqlr_new_error ("42000", "XENC11", "DH bits number should be greater than 0");

  mutex_enter (xenc_keys_mtx);
  if (NULL == (key = xenc_key_create (name, XENC_DH_ALGO, DSIG_DH_SHA1_ALGO, 0)))
    {
      mutex_leave (xenc_keys_mtx);
      SQLR_NEW_KEY_EXIST_ERROR (name);
    }
  if (p)
    {
      BIGNUM *bn_p, *bn_g;
      caddr_t mod, mod_b64 = box_copy (p);
      unsigned char g_bin[1];
      int p_len;

      g_bin[0] = (unsigned char)g;
      p_len = xenc_decode_base64 (mod_b64, mod_b64 + box_length (mod_b64));
      mod = dk_alloc_box (p_len, DV_BIN);
      memcpy (mod, mod_b64, p_len);

      dh = DH_new ();
      bn_p = BN_bin2bn ((unsigned char *)mod, p_len, NULL);
      bn_g = BN_bin2bn (g_bin, 1, NULL);
      dh->p = bn_p;
      dh->g = bn_g;

      dk_free_box (mod_b64);
      dk_free_box (mod);
    }
  else
    {
      dh = DH_generate_parameters (num, g, dh_cb, NULL);
    }
  if (!dh)
    {
      mutex_leave (xenc_keys_mtx);
      sqlr_new_error ("42000", "XENC11",
		    "DH parameters generation error");
    }
  if (!dh || !DH_generate_key(dh))
    {
      mutex_leave (xenc_keys_mtx);
      sqlr_new_error ("42000", "XENC12",
		    "Can't generate the DH private key");
    }
  key->ki.dh.dh_st = dh;
  key->xek_private_dh = dh;
  mutex_leave (xenc_keys_mtx);
  return NULL;
}

static
caddr_t bif_xenc_DH_get_params (caddr_t * qst, caddr_t * err_r, state_slot_t ** args)
{
  xenc_key_t * key;
  caddr_t name = bif_string_arg (qst, args, 0, "xenc_DH_get_params");
  int param = (int) bif_long_arg (qst, args, 1, "xenc_DH_get_params");
  size_t buf_len = 0;
  int n, len;
  caddr_t buf = NULL, ret, b64;
  DH *dh;
  BIGNUM *num;

  mutex_enter (xenc_keys_mtx);
  key = xenc_get_key_by_name (name, 0);
  if (!key || key->xek_type != DSIG_KEY_DH)
    {
      mutex_leave (xenc_keys_mtx);
      SQLR_NEW_KEY_ERROR (name);
    }

  dh = key->xek_private_dh;

  switch (param)
    {
  	case 1:
	 num = dh->p;
	 break;
	case 2:
	 num = dh->g;
	 break;
	case 3:
	 num = dh->pub_key;
	 break;
	case 4:
	 num = dh->priv_key;
	 break;
	default:
	 num = dh->pub_key;
    }

  buf_len = (size_t)BN_num_bytes(num);
  buf = dk_alloc_box (buf_len, DV_BIN);
  n = BN_bn2bin (num, (unsigned char*) buf);
  if (n != buf_len)
    GPF_T;
  mutex_leave (xenc_keys_mtx);

  b64 = dk_alloc_box (buf_len*2, DV_STRING);
  len = xenc_encode_base64 (buf, b64, buf_len);
  ret = dk_alloc_box (len + 1, DV_STRING);
  memcpy (ret, b64, len);
  ret[len] = 0;
  dk_free_box (buf);
  dk_free_box (b64);

  return ret;
}

static
caddr_t bif_xenc_DH_compute_key (caddr_t * qst, caddr_t * err_r, state_slot_t ** args)
{
  xenc_key_t * key;
  caddr_t name = bif_string_arg (qst, args, 0, "xenc_DH_compute_key");
  caddr_t pub, pub_b64 = box_copy (bif_string_arg (qst, args, 1, "xenc_DH_compute_key"));
  DH *dh;
  BIGNUM *pub_key;
  size_t buf_len, len;
  long shared_secret_len;
  caddr_t buf, ret, b64;
  char err_buf [1024];

  len = xenc_decode_base64 (pub_b64, pub_b64 + box_length (pub_b64));
  pub = dk_alloc_box (len + 1, DV_STRING);
  memcpy (pub, pub_b64, len);

  mutex_enter (xenc_keys_mtx);
  key = xenc_get_key_by_name (name, 0);
  if (!key || key->xek_type != DSIG_KEY_DH)
    {
      mutex_leave (xenc_keys_mtx);
      dk_free_box (pub);
      dk_free_box (pub_b64);
      SQLR_NEW_KEY_ERROR (name);
    }

  pub_key = BN_bin2bn ((unsigned char *)pub, len, NULL);
  dh = key->xek_private_dh;
  buf_len = DH_size (dh);
  buf = dk_alloc_box (buf_len, DV_BIN);
  shared_secret_len = DH_compute_key ((unsigned char *)buf, pub_key, dh);
  BN_free (pub_key);
  mutex_leave (xenc_keys_mtx);
  if (shared_secret_len < 0)
    {
      ERR_error_string_n (ERR_get_error(), err_buf, sizeof (err_buf));
      sqlr_new_error ("22023", "XENCX", "%s", err_buf);
    }

  b64 = dk_alloc_box (buf_len*2, DV_STRING);
  len = xenc_encode_base64 (buf, b64, buf_len);
  ret = dk_alloc_box (len + 1, DV_STRING);
  memcpy (ret, b64, len);
  ret[len] = 0;

  dk_free_box (buf);
  dk_free_box (b64);
  dk_free_box (pub);
  dk_free_box (pub_b64);
  return ret;
}

static
caddr_t bif_xenc_xor (caddr_t * qst, caddr_t * err_r, state_slot_t ** args)
{
  caddr_t x = box_copy (bif_string_arg (qst, args, 0, "xenc_xor"));
  caddr_t y = box_copy (bif_string_arg (qst, args, 1, "xenc_xor"));
  caddr_t z = NULL, b64, ret;
  size_t len, i, x_len, y_len;

  x_len = xenc_decode_base64 (x, x + box_length (x));
  y_len = xenc_decode_base64 (y, y + box_length (y));

  if (x_len != y_len)
    {
      dk_free_box (x);
      dk_free_box (y);
      sqlr_new_error ("22023", "XENCXX", "Both arguments needs to be same length");
    }

  len = x_len;
  z = dk_alloc_box (len, DV_BIN);
  for (i = 0; i < len; i++)
    z[i] = x[i] ^ y[i];

  dk_free_box (x);
  dk_free_box (y);

  b64 = dk_alloc_box (len*2, DV_STRING);
  len = xenc_encode_base64 (z, b64, x_len);
  ret = dk_alloc_box (len + 1, DV_STRING);
  memcpy (ret, b64, len);
  ret[len] = 0;

  dk_free_box (b64);
  dk_free_box (z);

  return ret;
}

caddr_t bif_xenc_bn2dec (caddr_t * qst, caddr_t * err_r, state_slot_t ** args)
{
  caddr_t x = box_copy (bif_string_arg (qst, args, 0, "xenc_bn2dec"));
  size_t len;
  caddr_t ret;
  char *dec;
  BIGNUM *n;

  len = xenc_decode_base64 (x, x + box_length (x));
  n = BN_bin2bn ((unsigned char *)x, len, NULL);
  dec = BN_bn2dec (n);
  len = strlen (dec);
  ret = dk_alloc_box (len+1, DV_STRING);
  memcpy (ret, dec, len);
  ret[len] = 0;

  BN_free (n);
  OPENSSL_free (dec);
  dk_free_box (x);
  return ret;
}

static int
xenc_key_len_get (const char * algo)
{
  int len = 0;

  if (!algo)
    len = 0;
  else if (!strcmp (algo, XENC_TRIPLEDES_ALGO))
    len = 3 * sizeof (DES_cblock);
  else if (!strcmp (algo, XENC_AES128_ALGO))
    len = 128;
  else if (!strcmp (algo, XENC_AES256_ALGO))
    len = 256;
  else if (!strcmp (algo, XENC_AES192_ALGO))
    len = 192;
  return len;
}

static /*xenc_key_RSA_create */
caddr_t bif_xenc_key_rsa_create (caddr_t * qst, caddr_t * err_r, state_slot_t ** args)
{
  xenc_key_t * k;
  caddr_t name = bif_string_arg (qst, args, 0, "xenc_key_RSA_create");
  int num = (int) bif_long_arg (qst, args, 1, "xenc_key_RSA_create");
  RSA *rsa = NULL;

  mutex_enter (xenc_keys_mtx);
  if (NULL == (k = xenc_key_create (name, XENC_RSA_ALGO , DSIG_RSA_SHA1_ALGO, 0)))
    {
      mutex_leave (xenc_keys_mtx);
      SQLR_NEW_KEY_EXIST_ERROR (name);
    }

  rsa = RSA_generate_key (num, RSA_F4, NULL, NULL);

  if (rsa == NULL)
    {
      sqlr_new_error ("42000", "XENC06", "RSA generation error");
    }

  k->xek_rsa = RSAPublicKey_dup (rsa);
  k->xek_private_rsa = rsa;
  k->ki.rsa.pad = RSA_PKCS1_PADDING;

  k->xek_evp_private_key = EVP_PKEY_new();
  if (k->xek_evp_private_key) EVP_PKEY_assign_RSA (k->xek_evp_private_key, k->xek_private_rsa);

  k->xek_evp_key = EVP_PKEY_new();
  if (k->xek_evp_key) EVP_PKEY_assign_RSA (k->xek_evp_key, k->xek_rsa);

  mutex_leave (xenc_keys_mtx);
  return NULL;
}

xenc_key_t *
xenc_key_create_from_utok (u_tok_t * utok, caddr_t seed, wsse_ctx_t * ctx)
{
  xenc_key_t * key;
  P_SHA1_CTX * psha1;
  DES_cblock _key[5];
  int key_len = 0;
  caddr_t * utok_opts = (caddr_t *) xenc_get_option (ctx->wc_opts, "UsernameToken", NULL);
  caddr_t key_algo = xenc_get_option (utok_opts, "keyAlgorithm", XENC_TRIPLEDES_ALGO);

  psha1 = P_SHA1_init (utok->pass, box_length (utok->pass) - 1, seed, box_length (seed) - 1);
  P_SHA1_block (psha1, (char *) &_key[0]);
  P_SHA1_block (psha1, (char *) &_key[0] + SHA_DIGEST_LENGTH);
  P_SHA1_free (psha1);

  mutex_enter (xenc_keys_mtx);
  key = xenc_key_create (NULL, key_algo, DSIG_HMAC_SHA1_ALGO, 0);
  key_len = xenc_key_len_get (key_algo);

  if (!key || !key_len)
    {
      mutex_leave (xenc_keys_mtx);
      return NULL;
    }

  switch (key->xek_type)
    {
      case DSIG_KEY_3DES:
	    {
	      memset (&key->ki.triple_des.ks1, 0, sizeof (key->ki.triple_des.ks1));
	      memset (&key->ki.triple_des.ks2, 0, sizeof (key->ki.triple_des.ks2));
	      memset (&key->ki.triple_des.ks3, 0, sizeof (key->ki.triple_des.ks3));
	      memset (&key->ki.triple_des.iv,  0, sizeof (key->ki.triple_des.iv));

	      DES_set_key_unchecked(&_key[0], &key->ki.triple_des.ks1);
	      DES_set_key_unchecked(&_key[1], &key->ki.triple_des.ks2);
	      DES_set_key_unchecked(&_key[2], &key->ki.triple_des.ks3);

	      memcpy (key->ki.triple_des.k1, &_key[0], sizeof (DES_cblock));
	      memcpy (key->ki.triple_des.k2, &_key[1], sizeof (DES_cblock));
	      memcpy (key->ki.triple_des.k3, &_key[2], sizeof (DES_cblock));
	      break;
	    }
#ifdef AES_ENC_ENABLE
      case DSIG_KEY_AES:
	    {
	      key->ki.aes.k = (unsigned char *) dk_alloc (key_len / 8);
	      key->ki.aes.bits = key_len;
	      memcpy (key->ki.aes.k, &_key[0], key_len / 8);
	      break;
	    }
#endif
      default:
	  return NULL;
    }

  key->xek_utok = utok;
  key->xek_x509_ref = xenc_next_id ();
  {
    char out[255];
    xenc_security_token_id_format (out, sizeof (out), key->xek_x509_ref, 1);
    key->xek_x509_ref_str = box_dv_short_string (out);
    xenc_certificates_hash_add (key->xek_x509_ref_str, key, 0);
  }
  mutex_leave (xenc_keys_mtx);
  return key;
}

#ifdef _KERBEROS
int
_krb_init_srv_ctx (caddr_t service_name, caddr_t tkt, gss_ctx_id_t * context);
#endif

#define XENC_SERVICE_NAME "host"

xenc_key_t * xenc_key_create_from_kerberos_tgs_cert (const char * name, caddr_t decoded_cert)
{
#if 0
  _krb_init_srv_ctx (XENC_SERVICE_NAME, decoded_cert, &context);
#endif
  return 0;
}

typedef struct xenc_cert_type_s
{
  char *	xcert_name;
} xenc_cert_type_t;

static
xenc_cert_type_t xenc_cert_types[] =
  {
    {"Kerberosv5TGT"},
    {"Kerberosv5ST"},
    {"X.509"}
  };

static ptrlong xenc_cert_X509_idx = -1;
static ptrlong xenc_cert_KERB5TGT_idx = -1;
static ptrlong xenc_cert_KERB5ST_idx = -1;

#define xenc_cert_types_len (sizeof(xenc_cert_types)/sizeof(xenc_cert_type_t))

static
caddr_t bif_key_name_arg (caddr_t * qst, state_slot_t ** args, int arg, const char * funcname)
{
  caddr_t name = bif_arg (qst, args, arg, (char*) funcname);
  dtp_t dtp = DV_TYPE_OF (name);

  if (dtp == DV_DB_NULL)
    return 0;
  if (dtp == DV_STRING)
    return name;

  sqlr_new_error ("42000", "XENC13", "%s function needs key name argument no. %d of string or null type,"
		  " not %s", funcname, arg + 1, dv_type_title (dtp));
  return 0; /* keeps compiler happy */
}

static /*xenc_key_create_cert */
caddr_t bif_xenc_key_create_cert (caddr_t * qst, caddr_t * err_r, state_slot_t ** args)
{
  caddr_t name = bif_key_name_arg (qst, args, 0, "xenc_key_create_cert");
  caddr_t cert = bif_string_arg (qst, args, 1, "xenc_key_create_cert");
  caddr_t cert_type = bif_string_arg (qst, args, 2, "xenc_sign_key_create_cert");
  client_connection_t * cli = ((query_instance_t *) qst)->qi_client;
  long type = BOX_ELEMENTS(args) > 3 ?
    bif_long_arg (qst, args, 3, "xenc_key_create_cert") : CERT_TYPE_PEM_FORMAT;
  xenc_key_t *k;

  caddr_t private_key = (BOX_ELEMENTS(args) > 4 && type != CERT_TYPE_PKCS12_FORMAT) ?
    bif_string_or_null_arg (qst, args, 4, "xenc_key_create_cert") : 0;
  const char * private_key_passwd = BOX_ELEMENTS(args) > 5 ?
    bif_string_or_null_arg (qst, args, 5,"xenc_key_create_cert") : "password";
  long ask_pwd = cli == bootstrap_cli ?  1 : 0;
  long import_chain = BOX_ELEMENTS(args) > 6 ?  bif_long_arg (qst, args, 6,"xenc_key_create_cert") : 0;

  ptrlong cert_type_idx = ecm_find_name (cert_type, (void*)xenc_cert_types, xenc_cert_types_len,
					 sizeof (xenc_cert_type_t));

  if (cert_type_idx == -1)
    sqlr_new_error ("42000", "XENC09", "Unknown certificate type %s", cert_type);
  if (cert_type_idx != xenc_cert_X509_idx)
    sqlr_new_error ("42000", "XENC34", "%s certificates are still not supported",
		    xenc_cert_types[cert_type_idx].xcert_name);

  if (NULL == (k = xenc_key_create_from_x509_cert (name, cert, private_key, private_key_passwd, 0, type, ask_pwd, import_chain)))
    sqlr_new_error ("42000", "XENC10", "Could not create key %s with certificate", name);

  /* store a key nfo in U_OPTS as "KEYS" option */
  /*
  if (!xenc_persist_key (k, qst, 1, err_r))
    return NEW_DB_NULL;
  */
  return box_dv_short_string (k->xek_name);
}

static /* xenc_key_remove */
caddr_t bif_xenc_key_remove (caddr_t * qst, caddr_t * err_r, state_slot_t ** args)
{
  caddr_t name = bif_string_arg (qst, args, 0, "xenc_key_remove");
  int persist  = BOX_ELEMENTS (args) > 1 ? bif_long_arg (qst, args, 1, "xenc_key_remove") : 1;
  xenc_key_t * key;

  mutex_enter (xenc_keys_mtx);
  key = xenc_get_key_by_name (name, 0);
  if (!key)
    {
      mutex_leave (xenc_keys_mtx);
      SQLR_NEW_KEY_ERROR (name);
    }
  if (persist)
    xenc_persist_key (key, qst, 0, err_r); /*XXX: remove a key nfo in U_OPTS as "KEYS" option */
  xenc_key_remove (key, 0);
  mutex_leave (xenc_keys_mtx);
  return NEW_DB_NULL;
}

static
caddr_t bif_xenc_key_exists (caddr_t * qst, caddr_t * err_r, state_slot_t ** args)
{
  caddr_t name = bif_string_arg (qst, args, 0, "xenc_key_exists");
  xenc_key_t * key = xenc_get_key_by_name (name, 1);
  return box_num (key ? 1 : 0);
}

int __xenc_key_dsa_init (char *name, int lock, int num)
{
  DSA *dsa;
  xenc_key_t * pkey = xenc_get_key_by_name (name, lock);
  if (NULL == pkey)
    SQLR_NEW_KEY_ERROR (name);

  RAND_poll ();
  dsa = DSA_generate_parameters(num, NULL, 0, NULL, NULL, dh_cb, NULL);
  if (dsa == NULL)
    {
      sqlr_new_error ("42000", "XENC11",
		    "DSA parameters generation error");
    }
  if (!DSA_generate_key(dsa))
    {
      sqlr_new_error ("42000", "XENC12",
		    "Can't generate the DSA private key");
    }
  pkey->xek_dsa = dsa;
  pkey->xek_private_dsa = dsa;
  return 0;
}

int __xenc_key_dh_init (char *name, int lock)
{
  DH *dh;
  int num=512, g=2;
  xenc_key_t * pkey = xenc_get_key_by_name (name, lock);
  if (NULL == pkey)
    SQLR_NEW_KEY_ERROR (name);

  dh = DH_generate_parameters (num, g, dh_cb, NULL);
  if (!dh)
    {
      sqlr_new_error ("42000", "XENC11",
		    "DH parameters generation error");
    }
  if (!dh || !DH_generate_key(dh))
    {
      sqlr_new_error ("42000", "XENC12",
		    "Can't generate the DH private key");
    }
  pkey->ki.dh.dh_st = dh;
  pkey->xek_private_dh = dh;
  return 0;
}

#define KEYSIZ	8
#define KEYSIZB 1024

#if 0
static
caddr_t bif_xenc_dsa_sha1_sign (caddr_t * qst, caddr_t * err_r, state_slot_t ** args)
{
  caddr_t name = bif_string_arg (qst, args, 0, "xenc_key_DSA_create");
  xenc_key_t * pkey = xenc_get_key_by_name (name, 1);
  if (NULL == pkey)
    sqlr_new_error ("....", "....", "Can't find DSA key specified, '%s'", name);

  return NULL;
}

static
caddr_t bif_xenc_dsa_sha1_verify (caddr_t * qst, caddr_t * err_r, state_slot_t ** args)
{
  caddr_t name = bif_string_arg (qst, args, 0, "xenc_key_DSA_create");
  xenc_key_t * pkey = xenc_get_key_by_name (name, 1);
  if (NULL == pkey)
    sqlr_new_error ("....", "....", "Can't find DSA key specified, '%s'", name);

  return NULL;
}
#endif

static
int __xenc_key_3des_init (char *name, char *pwd, int lock)
{
  char _key[KEYSIZB+1];
  DES_cblock key[3];

  xenc_key_t * pkey = xenc_get_key_by_name (name, lock);
  if (NULL == pkey)
    SQLR_NEW_KEY_ERROR (name);

  memset (&pkey->ki.triple_des.ks1, 0, sizeof (pkey->ki.triple_des.ks1));
  memset (&pkey->ki.triple_des.ks2, 0, sizeof (pkey->ki.triple_des.ks2));
  memset (&pkey->ki.triple_des.ks3, 0, sizeof (pkey->ki.triple_des.ks3));
  memset (&pkey->ki.triple_des.iv, 0, sizeof (pkey->ki.triple_des.iv));

  memset(_key,0,sizeof(key));
  strncpy(_key, pwd, KEYSIZB);
/*  RAND_pseudo_bytes(pkey->ki.triple_des.salt, PKCS5_SALT_LEN); - nosalt */

  EVP_BytesToKey(EVP_des_ede3_cbc(),EVP_md5(),
	NULL /*pkey->ki.triple_des.salt - nosalt*/,
	(unsigned char *)_key,
	strlen(_key), 1, (unsigned char*) &key[0], pkey->ki.triple_des.iv);

  DES_set_key_unchecked(&key[0], &pkey->ki.triple_des.ks1);
  DES_set_key_unchecked(&key[1], &pkey->ki.triple_des.ks2);
  DES_set_key_unchecked(&key[2], &pkey->ki.triple_des.ks3);

  memcpy (pkey->ki.triple_des.k1, &key[0], sizeof (DES_cblock));
  memcpy (pkey->ki.triple_des.k2, &key[1], sizeof (DES_cblock));
  memcpy (pkey->ki.triple_des.k3, &key[2], sizeof (DES_cblock));

  xenc_store_key (pkey, lock);
  return 0;
}

void xenc_key_3des_init (xenc_key_t * pkey, unsigned char * k1, unsigned char * k2, unsigned char * k3)
{
  memcpy (pkey->ki.triple_des.k1, k1, sizeof (DES_cblock));
  memcpy (pkey->ki.triple_des.k2, k2, sizeof (DES_cblock));
  memcpy (pkey->ki.triple_des.k3, k3, sizeof (DES_cblock));

  DES_set_key_unchecked((const_DES_cblock*) k1, &pkey->ki.triple_des.ks1);
  DES_set_key_unchecked((const_DES_cblock*) k2, &pkey->ki.triple_des.ks2);
  DES_set_key_unchecked((const_DES_cblock*) k3, &pkey->ki.triple_des.ks3);
}


static
caddr_t bif_xenc_key_3des_create (caddr_t * qst, caddr_t * err_r, state_slot_t ** args)
{
  caddr_t name = bif_key_name_arg (qst, args, 0, "xenc_key_3DES_create");
  caddr_t pwd = bif_string_arg (qst, args, 1, "xenc_key_3DES_create");
  xenc_key_t * key;

  mutex_enter (xenc_keys_mtx);
  key = xenc_key_create (name, XENC_TRIPLEDES_ALGO, XENC_TRIPLEDES_ALGO, 0);

  if (NULL == key)
    {
      mutex_leave (xenc_keys_mtx);
      SQLR_NEW_KEY_EXIST_ERROR (name);
    }

  __xenc_key_3des_init (key->xek_name, pwd, 0);
  xenc_store_key (key, 0);
  mutex_leave (xenc_keys_mtx);

  return box_dv_short_string (key->xek_name);
}

static
caddr_t bif_xenc_key_3des_rand_create (caddr_t * qst, caddr_t * err_r, state_slot_t ** args)
{
  caddr_t name = bif_key_name_arg (qst, args, 0, "xenc_key_3DES_rand_create");
  xenc_key_t * k = 0;
  DES_cblock k1;
  DES_cblock k2;
  DES_cblock k3;
  DES_key_schedule ks1;
  DES_key_schedule ks2;
  DES_key_schedule ks3;

  DES_random_key (&k1);
  DES_random_key (&k2);
  DES_random_key (&k3);

  if ( (DES_set_key_checked (&k1, &ks1) < 0) ||
       (DES_set_key_checked (&k2, &ks2) < 0) ||
       (DES_set_key_checked (&k3, &ks3) < 0) )
    GPF_T; /* parity check failed, library error - could not check result of it's own work */

  mutex_enter (xenc_keys_mtx);
  k = xenc_key_create (name, XENC_DES3_ALGO, XENC_DES3_ALGO, 0);

  if (!k)
    {
      mutex_leave (xenc_keys_mtx);
      SQLR_NEW_KEY_EXIST_ERROR (name);
    }
  memcpy (&k->ki.triple_des.k1, &k1, sizeof (DES_cblock));
  memcpy (&k->ki.triple_des.k2, &k2, sizeof (DES_cblock));
  memcpy (&k->ki.triple_des.k3, &k3, sizeof (DES_cblock));

  memcpy (&k->ki.triple_des.ks1, &ks1, sizeof (DES_key_schedule));
  memcpy (&k->ki.triple_des.ks2, &ks2, sizeof (DES_key_schedule));
  memcpy (&k->ki.triple_des.ks3, &ks3, sizeof (DES_key_schedule));

  mutex_leave (xenc_keys_mtx);

  return box_dv_short_string (k->xek_name);
}


static
caddr_t bif_xenc_key_3des_read (caddr_t * qst, caddr_t * err_r, state_slot_t ** args)
{
  caddr_t name = bif_key_name_arg (qst, args, 0, "xenc_key_3DES_read");
  caddr_t key_data = bif_string_arg (qst, args, 1, "xenc_key_3DES_read");
  xenc_key_t * k;
  int len;
  unsigned char * key_base64 = (unsigned char *) box_copy (key_data);
#if 0
  unsigned char _key [8 * 3];
#endif
  len = xenc_decode_base64 ((char *)key_base64, (char *)(key_base64 + box_length (key_base64)));
  if (len != 8 * 3)
    sqlr_new_error ("42000", "XENC15", "3DES key must 192 bits length, not %d", len * 8);

  mutex_enter (xenc_keys_mtx);
  k = xenc_key_create (name, XENC_DES3_ALGO, XENC_DES3_ALGO,  0);

  if (NULL == k)
    {
      mutex_leave (xenc_keys_mtx);
      SQLR_NEW_KEY_EXIST_ERROR (name);
    }

#ifndef DEBUG
  RAND_pseudo_bytes(k->ki.triple_des.iv, 8);
#else
  {
    unsigned char debug_iv [] = {34, 34, 34, 34, 34, 34, 34, 34 };
    memcpy (k->ki.triple_des.iv, debug_iv, 8);
  }
#endif

#if 1
  xenc_key_3des_init (k, key_base64, key_base64 + 8, key_base64 + 16);
#else
  EVP_BytesToKey(EVP_des_ede3_cbc(),EVP_md5(),
		 NULL,
		 (unsigned char *) key_base64,
		 24, 1, (unsigned char *) _key, k->ki.triple_des.iv);
  xenc_key_3des_init (k, &_key[0], &_key[8], &_key[16]);
#endif

  mutex_leave (xenc_keys_mtx);
  return box_dv_short_string (k->xek_name);
}

static caddr_t
bif_xenc_key_rsa_read (caddr_t * qst, caddr_t * err_r, state_slot_t ** args)
{
  caddr_t name = bif_key_name_arg (qst, args, 0, "xenc_key_RSA_read");
  caddr_t key_data = bif_string_arg (qst, args, 1, "xenc_key_RSA_read");
  long fmt = BOX_ELEMENTS (args) > 2 ? bif_long_arg (qst, args, 2, "xenc_key_RSA_read") : 0;
  xenc_key_t * k;
  int len;
  caddr_t key_base64 = box_copy (key_data);
  RSA *r = NULL, *p = NULL;
  BIO * in;
  EVP_PKEY * pkey = NULL, * pkkey = NULL;

  len = xenc_decode_base64 (key_base64, key_base64 + box_length (key_base64));
  if (fmt)
    {
      in = BIO_new_mem_buf (key_base64, len);
      pkey = d2i_PUBKEY_bio (in, NULL);
      if (pkey && pkey->type == EVP_PKEY_RSA)
	p = pkey->pkey.rsa;
      BIO_reset (in);
      pkkey = d2i_PrivateKey_bio (in, NULL);
      if (pkkey && pkkey->type == EVP_PKEY_RSA)
	r = pkkey->pkey.rsa;
      BIO_free (in);
    }
  else
    {
      r = d2i_RSAPrivateKey (NULL, (const unsigned char **) &key_base64, len);
      p = d2i_RSAPublicKey (NULL, (const unsigned char **) &key_base64, len);
    }

  if (!r && !p)
    {
      if (pkey) EVP_PKEY_free (pkey);
      if (pkkey) EVP_PKEY_free (pkkey);
      dk_free_box (key_base64);
      sqlr_new_error ("42000", "XENC05", "Cannot import the supplied RSA key");
    }

  if (!p)
    {
      p = RSA_new ();
      p->n = BN_dup (r->n);
      p->e = BN_dup (r->e);
    }

  mutex_enter (xenc_keys_mtx);
  k = xenc_key_create (name, XENC_RSA_ALGO, DSIG_RSA_SHA1_ALGO, 0);
  if (NULL == k)
    {
      mutex_leave (xenc_keys_mtx);
      SQLR_NEW_KEY_EXIST_ERROR (name);
    }
  k->xek_private_rsa = r;
  k->xek_rsa = p;
  k->ki.rsa.pad = RSA_PKCS1_PADDING;
  if (r)
    {
      if (pkkey)
	k->xek_evp_private_key = pkkey;
      else
	{
	  k->xek_evp_private_key = EVP_PKEY_new();
	  if (k->xek_evp_private_key) EVP_PKEY_assign_RSA (k->xek_evp_private_key, k->xek_private_rsa);
	}
    }
  if (pkey)
    k->xek_evp_key = pkey;
  else
    {
      k->xek_evp_key = EVP_PKEY_new();
      if (k->xek_evp_key) EVP_PKEY_assign_RSA (k->xek_evp_key, k->xek_rsa);
    }
  mutex_leave (xenc_keys_mtx);
  return box_dv_short_string (k->xek_name);
}

static caddr_t
bif_xenc_key_rsa_construct (caddr_t * qst, caddr_t * err_r, state_slot_t ** args)
{
  static char * me = "xenc_key_RSA_construct";
  caddr_t name = bif_key_name_arg (qst, args, 0, me);
  caddr_t mod = bif_string_arg (qst, args, 1, me);
  caddr_t exp = bif_string_arg (qst, args, 2, me);
  caddr_t pexp = BOX_ELEMENTS (args) > 3 ? bif_string_arg (qst, args, 3, me) : 0;
  BIGNUM *e, *n;
  xenc_key_t * k;
  RSA *p, *pk = NULL;

  p = RSA_new ();
  n = BN_bin2bn ((unsigned char *) mod, box_length (mod) - 1, NULL);
  e = BN_bin2bn ((unsigned char *) exp, box_length (exp) - 1, NULL);
  p->n = n;
  p->e = e;
  if (pexp)
    {
      pk = RSA_new ();
      pk->d = BN_bin2bn ((unsigned char *) pexp, box_length (pexp) - 1, NULL);
      pk->n = BN_dup (n);
      pk->e = BN_dup (e);
    }
  mutex_enter (xenc_keys_mtx);
  k = xenc_key_create (name, XENC_RSA_ALGO, DSIG_RSA_SHA1_ALGO, 0);
  if (NULL == k)
    {
      mutex_leave (xenc_keys_mtx);
      SQLR_NEW_KEY_EXIST_ERROR (name);
    }
  k->xek_private_rsa = pk;
  k->xek_rsa = p;
  k->ki.rsa.pad = RSA_PKCS1_PADDING;
  k->xek_evp_key = EVP_PKEY_new ();
  EVP_PKEY_assign_RSA (k->xek_evp_key, k->xek_rsa);
  if (pk)
    {
      k->xek_evp_private_key = EVP_PKEY_new ();
      EVP_PKEY_assign_RSA (k->xek_evp_private_key, k->xek_private_rsa);
    }
  mutex_leave (xenc_keys_mtx);
  return box_dv_short_string (k->xek_name);
}

static caddr_t
bif_xenc_key_dsa_read (caddr_t * qst, caddr_t * err_r, state_slot_t ** args)
{
  caddr_t name = bif_key_name_arg (qst, args, 0, "xenc_key_DSA_read");
  caddr_t key_data = bif_string_arg (qst, args, 1, "xenc_key_DSA_read");
  xenc_key_t * k;
  int len, is_private = 1;
  const unsigned char * key_base64 = (unsigned char *)box_copy (key_data);
  DSA *r;

  len = xenc_decode_base64 ((char *)key_base64, (char *)(key_base64 + box_length (key_base64)));
  r = d2i_DSAPrivateKey (NULL, &key_base64, len);
  if (!r)
    {
      r = d2i_DSAPublicKey (NULL, &key_base64, len);
      is_private = 0;
    }

  if (!r)
    sqlr_new_error ("42000", "XENC05", "Cannot import the supplied DSA key");

  mutex_enter (xenc_keys_mtx);
  k = xenc_key_create (name, XENC_DSA_ALGO, DSIG_DSA_SHA1_ALGO, 0);
  if (NULL == k)
    {
      mutex_leave (xenc_keys_mtx);
      SQLR_NEW_KEY_EXIST_ERROR (name);
    }
  if (is_private)
    k->xek_private_dsa = r;
  k->xek_dsa = r;
  mutex_leave (xenc_keys_mtx);
  return box_dv_short_string (k->xek_name);
}

static caddr_t
bif_xenc_get_key_algo (caddr_t * qst, caddr_t * err_r, state_slot_t ** args)
{
  caddr_t name = bif_key_name_arg (qst, args, 0, "xenc_get_key_algo");
  xenc_key_t * key;
  key = xenc_get_key_by_name (name, 1);
  if (key)
    {
      return box_dv_short_string (key->xek_sign_algo->xea_ns);
    }
  else
    return NEW_DB_NULL;
}

static
caddr_t bif_xenc_key_raw_read (caddr_t * qst, caddr_t * err_r, state_slot_t ** args)
{
  caddr_t name = bif_key_name_arg (qst, args, 0, "xenc_key_RAW_read");
  caddr_t key_data = bif_string_arg (qst, args, 1, "xenc_key_RAW_read");
  xenc_key_t * k;
  int len;
  unsigned char * key_base64 = (unsigned char *) box_copy (key_data);
  len = xenc_decode_base64 ((char *)key_base64, (char *)(key_base64 + box_length (key_base64)));

  mutex_enter (xenc_keys_mtx);
  k = xenc_key_create (name, XENC_BASE64_ALGO, DSIG_HMAC_SHA1_ALGO,  0);

  if (NULL == k)
    {
      mutex_leave (xenc_keys_mtx);
      SQLR_NEW_KEY_EXIST_ERROR (name);
    }

  k->ki.raw.k = key_base64;
  k->ki.raw.bits = len * 8;

  mutex_leave (xenc_keys_mtx);
  return box_dv_short_string (k->xek_name);
}

static
caddr_t bif_xenc_key_raw_rand_create (caddr_t * qst, caddr_t * err_r, state_slot_t ** args)
{
  caddr_t name = bif_key_name_arg (qst, args, 0, "xenc_key_RAW_rand_create");
  int len = (int) bif_long_arg (qst, args, 1, "xenc_key_RAW_rand_create");
  xenc_key_t * k;
  int rc;
  unsigned char buf[4096];
  unsigned char * key_data;

  if (len < 1 || len > sizeof (buf))
    len = sizeof (buf);
  rc = RAND_bytes(buf, len);

  if (rc <= 0)
    sqlr_new_error ("42000", "XENC14", "Cannot generate key data");

  mutex_enter (xenc_keys_mtx);
  k = xenc_key_create (name, XENC_BASE64_ALGO, DSIG_HMAC_SHA1_ALGO,  0);

  if (NULL == k)
    {
      mutex_leave (xenc_keys_mtx);
      SQLR_NEW_KEY_EXIST_ERROR (name);
    }

  key_data = (unsigned char *) dk_alloc_box (len, DV_STRING);
  memcpy (key_data, buf, len);

  k->ki.raw.k = key_data;
  k->ki.raw.bits = len * 8;

  mutex_leave (xenc_keys_mtx);
  return box_dv_short_string (k->xek_name);
}

static
caddr_t bif_xenc_rand_bytes (caddr_t * qst, caddr_t * err_r, state_slot_t ** args)
{
  int len = (int) bif_long_arg (qst, args, 0, "xenc_rand_bytes");
  int mode = (int) bif_long_arg (qst, args, 1, "xenc_rand_bytes");
  int rc, i;
  unsigned char buf[4096], tmp[3];
  caddr_t ret;

  if (len < 1 || len > sizeof (buf))
    len = sizeof (buf);
  rc = RAND_bytes(buf, len);

  if (rc <= 0)
    sqlr_new_error ("42000", "XENC14", "Cannot generate key data");

  if (1 == mode) /* HEX */
    {
      ret = dk_alloc_box (len * 2 + 1, DV_SHORT_STRING);
      ret[0] = 0;
      for (i = 0; i < len; i++)
	{
	  snprintf ((char *) tmp, sizeof (tmp), "%02x", (unsigned char) buf[i]);
	  strcat_box_ck (ret, (char *)tmp);
	}
      ret[2 * len] = 0;
    }
  else if (2 == mode) /* base64 */
    {
      caddr_t b64;
      int b64_len;
      b64 = dk_alloc_box (len * 2, DV_BIN);
      b64_len = xenc_encode_base64 ((char *)buf, b64, len);
      ret = dk_alloc_box (b64_len + 1, DV_STRING);
      memcpy (ret, b64, b64_len);
      dk_free_box (b64);
    }
  else
    { /* RAW */
      ret = dk_alloc_box (len, DV_BIN);
      memcpy (ret, buf, len);
    }
  return ret;
}

static caddr_t
bif_xenc_get_key_identifier (caddr_t * qst, caddr_t * err_r, state_slot_t ** args)
{
  caddr_t name = bif_key_name_arg (qst, args, 0, "xenc_get_key_identifier");
  xenc_key_t * key;
  key = xenc_get_key_by_name (name, 1);
  if (key && key->xek_x509_KI)
    {
      return box_dv_short_string (key->xek_x509_KI);
    }
  else
    return NEW_DB_NULL;
}

#ifdef DEBUG
static
caddr_t bif_xenc_key_3des_test_create (caddr_t * qst, caddr_t * err_r, state_slot_t ** args)
{
  caddr_t name = bif_arg (qst, args, 0, "xenc_key_3DES_read");
  caddr_t key_base64 = bif_string_arg (qst, args, 1, "xenc_key_3DES_read");
  caddr_t iv = "IV001234";
  xenc_key_t * k;
  int len = xenc_decode_base64 (key_base64, key_base64 + box_length (key_base64));
  if (len != 8 * 3)
    sqlr_new_error ("....", "....", "3DES key must 192 bits length, not %d", len * 8);

  if (DV_TYPE_OF (name) == DV_STRING)
    {
      mutex_enter (xenc_keys_mtx);
      k = xenc_key_create (name, XENC_DES3_ALGO, XENC_DES3_ALGO,  0);
    }
  else if (DV_TYPE_OF (name) == DV_DB_NULL)
    {
      mutex_enter (xenc_keys_mtx);
      k = xenc_key_create (NULL, XENC_DES3_ALGO, XENC_DES3_ALGO, 0);
    }
  else
    sqlr_new_error ("....", "....", "type of key name must be either string or NULL not %s",
		    dv_type_title (DV_TYPE_OF (name)));

  if (NULL == k)
    {
      mutex_leave (xenc_keys_mtx);
      sqlr_new_error ("....", "....", "Duplicate key, %s", XENC_TRIPLEDES_ALGO);
    }

  memcpy (k->ki.triple_des.iv, iv, 8);

  xenc_key_3des_init (k, key_base64, key_base64 + 8, key_base64 + 16);
  mutex_leave (xenc_keys_mtx);
  return box_dv_short_string (k->xek_name);
}
#endif

static
caddr_t bif_xenc_key_serialize (caddr_t * qst, caddr_t * err_r, state_slot_t ** args)
{
  caddr_t name = bif_string_arg (qst, args, 0, "xenc_key_serialize");
  int pub = BOX_ELEMENTS (args) > 1 ? bif_long_arg (qst, args, 1, "xenc_key_serialize") : 0;
  xenc_key_t * k = xenc_get_key_by_name (name, 1);
  unsigned char * buf;
  int len;
  caddr_t ret;
  caddr_t in_buf;

  if (!k)
    SQLR_NEW_KEY_ERROR (name);

  if (k->xek_type == DSIG_KEY_3DES)
    {
      len = 8 * 3;
    }
  else if (k->xek_type == DSIG_KEY_RSA)
    {
      if (!pub && k->xek_private_rsa)
	len = i2d_RSAPrivateKey (k->xek_private_rsa, NULL) + 20;
      else if (pub && k->xek_private_rsa)
	len = i2d_RSAPublicKey (k->xek_private_rsa, NULL) + 20;
      else
	len = i2d_RSAPublicKey (k->xek_rsa, NULL) + 20;
    }
  else if (k->xek_type == DSIG_KEY_DSA)
    {
      if (!pub && k->xek_private_dsa)
	len = i2d_DSAPrivateKey (k->xek_dsa, NULL) + 20;
      else
	len = i2d_DSAPublicKey (k->xek_dsa, NULL) + 20;
    }
  else if (k->xek_type == DSIG_KEY_RAW)
    {
      len = k->ki.raw.bits / 8;
    }
  else if (k->xek_type == DSIG_KEY_AES)
    {
      len = k->ki.aes.bits / 8;
    }
  else
    return NEW_DB_NULL;

  buf = (unsigned char *) dk_alloc_box (len * 2, DV_BIN);
  in_buf = dk_alloc_box (len + 1, DV_BIN);

  if (k->xek_type == DSIG_KEY_3DES)
    {
      memcpy (in_buf, k->ki.triple_des.k1, sizeof (DES_cblock));
      memcpy (in_buf + sizeof (DES_cblock), k->ki.triple_des.k2, sizeof (DES_cblock));
      memcpy (in_buf + 2*sizeof (DES_cblock), k->ki.triple_des.k3, sizeof (DES_cblock));
    }
  else if (k->xek_type == DSIG_KEY_RSA)
    {
      unsigned char *p = (unsigned char *)in_buf;
      if (!pub && k->xek_private_rsa)
	len = i2d_RSAPrivateKey (k->xek_private_rsa, &p);
      else if (pub && k->xek_private_rsa)
	len = i2d_RSAPublicKey (k->xek_private_rsa, &p);
      else
	len = i2d_RSAPublicKey (k->xek_rsa, &p);
    }
  else if (k->xek_type == DSIG_KEY_DSA)
    {
      unsigned char *p = (unsigned char *)in_buf;
      if (!pub && k->xek_private_dsa)
	len = i2d_DSAPrivateKey (k->xek_dsa, &p);
      else
	len = i2d_DSAPublicKey (k->xek_dsa, &p);
    }
  else if (k->xek_type == DSIG_KEY_RAW)
    {
      memcpy (in_buf, k->ki.raw.k, len);
    }
  else if (k->xek_type == DSIG_KEY_AES)
    {
      memcpy (in_buf, k->ki.aes.k, len);
    }
  else
    GPF_T;

  len = xenc_encode_base64 (in_buf, (char *)buf, len);

  ret = dk_alloc_box (len + 1, DV_STRING);
  memcpy (ret, buf, len);
  ret[len] = 0;
  dk_free_box ((box_t) buf);
  dk_free_box (in_buf);
  return ret;
}

static
caddr_t bif_xenc_x509_cert_serialize (caddr_t * qst, caddr_t * err_r, state_slot_t ** args)
{
  caddr_t name = bif_string_arg (qst, args, 0, "xenc_X509_certificate_serialize");
  xenc_key_t * k = xenc_get_key_by_name (name, 1);
  int len;
  caddr_t ret, p, buf, in_buf;

  if (!k)
    SQLR_NEW_KEY_ERROR (name);

  if (k->xek_x509)
    {
      X509 * cert = k->xek_x509;
      len = i2d_X509 (cert, NULL);
      in_buf = dk_alloc_box (len, DV_BIN);
      p = in_buf;
      len = i2d_X509 (cert, (unsigned char **)&p);
      if (len < 0)
	{
	  dk_free_box (in_buf);
	  sqlr_new_error ("42000", "XENC05", "Cannot export certificate");
	}
      buf = dk_alloc_box (len * 2, DV_BIN);

      len = xenc_encode_base64 (in_buf, buf, len);
      ret = dk_alloc_box (len + 1, DV_STRING);
      memcpy (ret, buf, len);
      ret[len] = 0;
      dk_free_box (buf);
      dk_free_box (in_buf);
    }
  else
    return NEW_DB_NULL;
  return ret;
}

#ifdef AES_ENC_ENABLE
xenc_key_t * xenc_key_aes_create (const char * name, int keylen, const char * pwd)
{
  char _key[KEYSIZB+1];
  xenc_key_t * k;
  const char * algoname;
  const EVP_CIPHER * cipher;

  strncpy(_key, pwd, KEYSIZB);

  switch (keylen)
    {
    case 128:
      algoname = XENC_AES128_ALGO;
      cipher = EVP_aes_128_cbc();
      break;
    case 192:
      algoname = XENC_AES192_ALGO;
      cipher = EVP_aes_192_cbc();
      break;
    case 256:
      algoname = XENC_AES256_ALGO;
      cipher = EVP_aes_256_cbc();
      break;
    default:
      sqlr_new_error ("42000", "XENC16", "AES key with length %d is not supported", keylen);
      algoname = NULL; cipher = NULL; /* To keep gcc 4.0 happy */
    }

  k = xenc_key_create (name, algoname, algoname, 0);
  if (!k)
    SQLR_NEW_KEY_EXIST_ERROR (name);

  k->xek_type = DSIG_KEY_AES;
  k->ki.aes.k = (unsigned char *) dk_alloc (keylen / 8 /* number of bits in a byte */);
  k->ki.aes.bits = keylen;

  EVP_BytesToKey(cipher,EVP_md5(),
		 NULL,
		 (unsigned char *) _key,
		 strlen(_key), 1, (unsigned char*) k->ki.aes.k, k->ki.aes.iv);

  return k;
}

static
caddr_t bif_xenc_key_aes_create (caddr_t * qst, caddr_t * err_r, state_slot_t ** args)
{
  char * name = bif_key_name_arg (qst, args, 0, "xenc_key_aes_create");
  long bits = bif_long_arg (qst, args, 1, "xenc_key_aes_create");
  char * pwd = bif_string_arg (qst, args, 2, "xenc_key_aes_create");
  xenc_key_t * k;

  k = xenc_key_aes_create (name, bits, pwd);

  return box_dv_short_string (k->xek_name);
}

static
caddr_t bif_xenc_key_aes_rand_create (caddr_t * qst, caddr_t * err_r, state_slot_t ** args)
{
  char * name = bif_key_name_arg (qst, args, 0, "xenc_key_aes_rnd_create");
  long bits = bif_long_arg (qst, args, 1, "xenc_key_aes_rnd_create");
  xenc_key_t * k;
  int rc;
  unsigned char buf[KEYSIZB];

  rc = RAND_bytes(buf, sizeof (buf));
  if (rc <= 0)
    sqlr_new_error ("42000", "XENC14", "Cannot generate key data");
  k = xenc_key_aes_create (name, bits, buf);
  if (!k)
    SQLR_NEW_KEY_EXIST_ERROR (name);

  return box_dv_short_string (k->xek_name);
}
#endif

#ifdef _KERBEROS

void
krb_init_ctx (char * service_name, gss_ctx_id_t * context, caddr_t * tkt);

/* can throw an error!!! */
xenc_key_t * xenc_key_kerberos_create (const char * name, const char * service)
{
  gss_ctx_id_t context;
  caddr_t tkt = NULL;
  xenc_key_t * k;
  krb_init_ctx ((char*)service, &context, &tkt);

  mutex_enter (xenc_keys_mtx);
  k = xenc_key_create (name,
		       XENC_TRIPLEDES_ALGO,
		       DSIG_HMAC_SHA1_ALGO,
		       0);
  if (!k)
    {
      mutex_leave (xenc_keys_mtx);
      return 0;
    }
  k->xek_type = DSIG_KEY_KERBEROS;
  if (k)
    {
      xenc_id_t xenc_id = xenc_next_id ();
      k->xek_x509_ref = xenc_id;
      k->ki.kerb.context = context;
      k->ki.kerb.service_name = box_dv_short_string (service);
      k->ki.kerb.tkt = tkt;
    }
  mutex_leave (xenc_keys_mtx);
  return k;
}

static
caddr_t bif_xenc_key_kerberos_create (caddr_t * qst, caddr_t * err_r, state_slot_t ** args)
{
  char * name = bif_key_name_arg (qst, args, 0, "xenc_key_kerberos_create");
  char * service_name = bif_string_arg (qst, args, 1, "xenc_key_kerberos_create");
  xenc_key_t * k = xenc_key_kerberos_create (name, service_name);
  if (!k)
    {
      SQLR_NEW_KEY_EXIST_ERROR (name);
    }
  return box_dv_short_string (k->xek_name);
}
#endif

xenc_id_t xenc_encode_by_key (xenc_key_t * key, dk_session_t * ses, long seslen,
			      ptrlong type_idx, dk_session_t * oses, xenc_key_inst_t * superkey,
			      xenc_try_block_t * t, wsse_ser_ctx_t * sctx)
{
  char buf [1024];
  xenc_id_t id = xenc_next_id ();
  char id_str[200];
  uuid_t id_stat;
  uuid_unparse (id, id_str);
  memcpy (&id_stat, id, sizeof (uuid_t));

  snprintf (buf, 1024, "<xenc:EncryptedData Type=\"" XENC_NS "%s" "\" Id=\"Id-%s\" ", xenc_types[type_idx], id_str);
  SES_WRITE (oses, buf);
  SES_WRITE (oses, XENC_NAMESPACE_STR);
  SES_WRITE (oses, ">");

  SES_WRITE (oses, "<xenc:EncryptionMethod Algorithm='");
  SES_WRITE (oses, key->xek_enc_algo->xea_ns);
  SES_WRITE (oses, "'/>");

  dk_free_box ((box_t) id);

  if (key->xek_x509_ref)
    {
      char out[255];
      xenc_security_token_id_format (out, sizeof (out), key->xek_x509_ref, 1);
      SES_WRITE (oses, "<ds:KeyInfo ");
      SES_WRITE (oses, "xmlns:ds=\"");
      SES_WRITE (oses, DSIG_URI "\"");
      SES_WRITE (oses, "xmlns:wsse=\"");
      SES_WRITE (oses, WSSE_URI(sctx));
      SES_WRITE (oses, "\"");

      SES_WRITE (oses, "><wsse:SecurityTokenReference><wsse:Reference URI=\"");
      SES_WRITE (oses, out);
      SES_WRITE (oses, "\"/></wsse:SecurityTokenReference></ds:KeyInfo>");
    }
  else if (!superkey) /* symmetric encryption */
    {
      SES_WRITE (oses, "<ds:KeyInfo ");
      SES_WRITE (oses, "xmlns:ds=\"");
      SES_WRITE (oses, DSIG_URI "\"");
      SES_WRITE (oses, "><ds:KeyName>");
      SES_WRITE (oses, key->xek_name);
      SES_WRITE (oses, "</ds:KeyName></ds:KeyInfo>");
    }

  SES_WRITE (oses, "<xenc:CipherData><xenc:CipherValue>");

  (key->xek_enc_algo->xea_enc) (ses, strses_length (ses), oses, key, t);

  SES_WRITE (oses, "</xenc:CipherValue></xenc:CipherData>");
  SES_WRITE (oses, "</xenc:EncryptedData>");

  id = _xenc_id (&id_stat);
  return id;
}

void
xenc_xte_serialize_with_nss (xml_tree_ent_t * xte, dk_session_t * ses, id_hash_t * nss)
{
  caddr_t ret_text;
  xml_doc_subst_t * xs;


  xs = (xml_doc_subst_t *) dk_alloc (sizeof (xml_doc_subst_t));
  memset (xs, 0, sizeof (xml_doc_subst_t));

  xml_c_build_ancessor_ns_link (xte->xe_doc.xtd->xtd_tree, xte->xte_current, nss, &xs->xs_parent_link);

  xs->xs_doc = xte;
  xs->xs_namespaces = nss;

  ret_text = xml_doc_subst (xs);
  CATCH_WRITE_FAIL (ses)
    {
      session_buffered_write (ses, ret_text, box_length (ret_text) - 1);
    }
  FAILED
    {
    }
  END_WRITE_FAIL (ses);

  dk_set_free (xs->xs_parent_link);
  xml_doc_subst_free (xs);
  dk_free_box (ret_text);
}


caddr_t* xenc_generate_enc_texts (xenc_key_inst_t * keyins, ptrlong type_idx,
				  xml_tree_ent_t ** ents, id_hash_t * nss, caddr_t * err_ret,
				  wsse_ser_ctx_t * sctx)
{
  int inx;
  dk_session_t * ses = strses_allocate ();
  dk_session_t * oses = strses_allocate ();
  dk_set_t l = 0;
  caddr_t * ret;
  xenc_key_t * key = xenc_get_key_by_name (keyins->xeki_key_name, 1);
  dk_set_t ids = 0;
  caddr_t * ids_arr;
  xenc_try_block_t t;
  int err = 0;

  if (!key)
    return 0;

  XENC_TRY (&t)
    {
      DO_BOX (xml_tree_ent_t *, ent, inx, ents)
	{
	  if (type_idx == XENCTypeContentIdx)
	    {
	      if ((DV_TYPE_OF (ent->xte_current) == DV_ARRAY_OF_POINTER) &&
		  (BOX_ELEMENTS (ent->xte_current) > 1))
		{
		  int inx;
		  caddr_t * current = ent->xte_current;
		  DO_BOX (caddr_t *, child, inx, current)
		    {
		      if (!inx)
			continue;
		      ent->xte_current = child;
		      xenc_xte_serialize_with_nss (ent, ses, nss);
		    }
		  END_DO_BOX;
		  ent->xte_current = current;
		}
	    }
	  else if (type_idx == XENCTypeElementIdx)
	    {
	      xenc_xte_serialize_with_nss (ent, ses, nss);
	    }
	  else  /* must be checked later */
	    GPF_T;
	  dk_set_push (&ids, (void*) xenc_encode_by_key (key, ses, strses_length (ses),
							 type_idx, oses, keyins->xeki_super_key_inst, &t, sctx));

	  dk_set_push (&l, strses_string (oses));
	  strses_flush (ses);
	  strses_flush (oses);
	}
      END_DO_BOX;
    }
  XENC_CATCH
    {
      char buf [1024];
      xenc_make_error (buf, sizeof (buf), t.xtb_err_code, t.xtb_err_buffer);
      if (err_ret) err_ret[0] = box_dv_short_string (buf);
      err = 1;
    }
  XENC_TRY_END (&t);

  l = dk_set_nreverse (l);
  ret = (caddr_t *) dk_set_to_array (l);
  dk_set_free (l);
  ids_arr = (caddr_t *) dk_set_to_array (ids);
  dk_set_free (ids);

  if (err)
    {
      dk_free_tree ((box_t) ids_arr);
      dk_free_tree ((box_t) ret);
      return 0;
    }
  else
    {
      fuse_arrays ((caddr_t**) &keyins->xeki_ids, ids_arr, DV_ARRAY_OF_POINTER);
      dk_free_box ((box_t) ids_arr);
      return ret;
    }
}


/*
  CDATA entity with element encryption type is not allowed
*/
int xenc_check_ents_encryptability (xml_tree_ent_t ** ents, ptrlong type_idx)
{
  int inx;
  if (type_idx == XENCTypeDocumentIdx)
    return 0;

  DO_BOX (xml_tree_ent_t*, ent, inx, ents)
    {
      if (DV_STRINGP (ent->xte_current))
	{
	  if (type_idx == XENCTypeElementIdx)
	    return 0;
	}
    }
  END_DO_BOX;
  return 1;
}

/*
   example:
	xmlenc_encrypt (xml_text, soap_ver, signature_template, xpath_expr1,  keyinst1, xpath_expr2, keyinst2, ...)
*/

static void xpath_keyinst_free (xpath_keyinst_t * xpkei)
{
  dk_free_tree ((box_t) xpkei->keyinst);
  dk_free (xpkei, sizeof (xpath_keyinst_t));
}

xml_tree_ent_t * xenc_get_entity_arg (query_instance_t * qi, state_slot_t **args, int inx, char * func, id_hash_t ** _nss)
{
  caddr_t text = bif_arg ((caddr_t *)qi, args, inx, func);
  caddr_t err = 0;
  wcharset_t * volatile charset = QST_CHARSET (qi) ? QST_CHARSET (qi) : default_charset;
  xml_tree_ent_t * xte;


  xte = (xml_tree_ent_t *) xml_make_tree_with_ns (qi, text, &err, CHARSET_NAME (charset, NULL), server_default_lh, _nss, 0);

  if (err)
    sqlr_resignal (err);

  return xte;
}

#if 0
static void
dbg_hash_tables (void)
{
  id_hash_iterator_t hit;
  char ** kn;
  xenc_key_t ** key;

  fprintf (stderr, "===== KEYS =====\n");
  for (id_hash_iterator (&hit, xenc_keys); hit_next (&hit, (char**)&kn, (char**)&key); /* */)
    {
      fprintf (stderr, "%s\n", *kn);
    }
  fprintf (stderr, "===== CERTS =====\n");
  for (id_hash_iterator (&hit, xenc_certificates); hit_next (&hit, (char**)&kn, (char**)&key); /* */)
    {
      fprintf (stderr, "%s\n", *kn);
    }
}
#endif

void
xenc_set_serialization_ctx (caddr_t try_ns_spec, wsse_ser_ctx_t * sctx)
{
  caddr_t * ns_spec = (caddr_t *) try_ns_spec;
  int i;

  if (!ARRAYP (ns_spec) || BOX_ELEMENTS_INT (ns_spec) % 2 != 0)
    return;

  for (i = 0; i < BOX_ELEMENTS_INT (ns_spec) - 1; i+=2)
    {
      caddr_t ns = ns_spec[i];
      caddr_t ns_uri = ns_spec[i+1];
      int idx;
      char ** arr;
      arr = NULL; idx = 0;

      if (!DV_STRINGP (ns) || !DV_STRINGP (ns_uri))
	continue;

      if (!stricmp (ns, "wsse"))
	arr = wsse_uris;
      else if (!stricmp (ns, "wsu"))
	arr = wsu_uris;

      if (arr && is_in_urls (arr, ns_uri, &idx))
	{
	  if (wsse_uris == arr)
	    {
	      sctx->wsc_wsse = (WSSE_TYPE_T) idx;
	    }
	  else if (wsu_uris == arr)
	    {
	      sctx->wsc_wsu = (WSU_TYPE_T) idx;
	    }
	}

    }
}

caddr_t
bif_xmlenc_encrypt (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int xpath_arg_pointer = 3; /* doc & soap_version & dsig_templ args */
  dk_set_t xp_keys = 0;
  xpath_keyinst_t ** xp_keys_arr;
  int inx;
  id_hash_t * _nss = 0;
  xml_tree_ent_t * doc = xenc_get_entity_arg ((query_instance_t*) qst, args, 0, "xenc_encrypt", &_nss);
  caddr_t text = bif_string_arg (qst, args, 0, "xenc_encrypt");
  int soap_version = bif_long_arg (qst, args, 1, "xenc_encrypt");
  caddr_t dsig_template_str = bif_arg (qst, args, 2, "xenc_encrypt");
  xml_doc_subst_t * xs;
  xpath_keyinst_t * xpath_key;
  xml_tree_ent_t ** origs_ents = 0;
  caddr_t * copies = 0;
  caddr_t ret_text = 0;
  local_cursor_t * lc = NULL;
  dk_set_t lcl = 0;
  query_instance_t * qi = (query_instance_t*) qst;
  caddr_t * err = 0;
  query_t * qr;
  caddr_t * security_tags;
  int xpath_arg_pointer_old;
  dsig_signature_t * dsig = 0;
  xenc_try_block_t t;
  xenc_err_code_t c;
  char * c_err;
  dk_session_t * doc_ses;
  subst_item_t * subst_items = 0;
  dk_set_t s_type_idxs = 0;
  ptrlong * type_idxs = 0;
  int generate_ref_list = 0;
  caddr_t * envelope = 0, *header = 0, *new_header = 0, * signature = 0;
  caddr_t signature_val = 0;
  wsse_ctx_t * ctx;
  char err_buf[1024];
  int sign_err = 0;
  caddr_t err_ret_sec_tags = 0;
  wsse_ser_ctx_t sctx;
  caddr_t * opts = NULL;

  memset (&sctx, 0, sizeof (wsse_ser_ctx_t));

  switch (DV_TYPE_OF (dsig_template_str))
    {
    case DV_DB_NULL:
      dsig_template_str = 0;
      break;
    case DV_STRING:
      break;
    default:
      {
	dk_free_box ((box_t) doc);
	nss_free (_nss);
	sqlr_new_error ("42000", "XENC17", "XML Signature template is expected to be either NULL of VARCHAR");
      }
    }

  if (BOX_ELEMENTS_INT(args) > 3)
    {
      caddr_t try_ns_spec = bif_arg (qst, args, 3, "xenc_encrypt");
      if (ARRAYP (try_ns_spec)) /* namespaces are defined */
	{
	  xenc_set_serialization_ctx (try_ns_spec, &sctx);
	  xpath_arg_pointer++;
	  opts = (caddr_t *)try_ns_spec;
	}
    }

  xpath_arg_pointer_old = xpath_arg_pointer;
  while (xpath_arg_pointer < BOX_ELEMENTS_INT (args) - 2)
    {
      xenc_key_inst_t * keyinst;
      bif_string_arg (qst, args, xpath_arg_pointer, "xenc_encrypt");
      keyinst = (xenc_key_inst_t *) bif_arg (qst, args, xpath_arg_pointer + 1, "xenc_encrypt");

      check_key_instance (keyinst, xpath_arg_pointer + 1, "xenc_encrypt");
      xpath_arg_pointer+=3;
    }
  xpath_arg_pointer = xpath_arg_pointer_old;

  qr = sql_compile ("select xpath_eval (? , ?, 0)",
		    qi->qi_client , (caddr_t*)  &err, SQLC_DEFAULT);
  if (err)
    {
#ifdef DEBUG
      log_error ("Could not create ents: %s %s", err[1], err[2]);
#endif
      qr_free (qr);
      dk_free_box ((box_t) doc); nss_free (_nss);
      sqlr_resignal ((caddr_t)err);
    }

  while (xpath_arg_pointer < BOX_ELEMENTS_INT (args) - 2)
    {
      caddr_t xpath_expr = bif_string_arg (qst, args, xpath_arg_pointer, "xenc_encrypt");
      xenc_key_inst_t * keyinst = (xenc_key_inst_t *) bif_arg (qst, args, xpath_arg_pointer + 1, "xenc_encrypt");
      xml_tree_ent_t ** ents = 0;
      xml_tree_ent_t ** ret = 0;
      caddr_t type = bif_string_arg (qst, args, xpath_arg_pointer + 2, "xenc_encrypt");
      ptrlong type_idx;

      err = (caddr_t *) qr_rec_exec (qr, qi->qi_client, &lc, qi, NULL, 2,
				       ":0", xpath_expr, QRP_STR,
				       ":1", doc, QRP_RAW);

      if ((caddr_t*) SQL_SUCCESS != err)
	{
#ifdef DEBUG
          log_error ("XPATH error %s %s", err[1], err[2]);
#endif
          LC_FREE (lc);
          qr_free (qr);
          dk_free_tree ((box_t) err);
        }
      else if (lc && lc_next (lc))
        {
          ret = (xml_tree_ent_t **) (lc_nth_col (lc, 0));
          dk_set_push (&lcl, lc);
          lc = NULL;
          ents =  ret;
        }

      type_idx = ecm_find_name (type, xenc_types, xenc_types_len, sizeof (xenc_type_t));
      if (type_idx == -1)
        type_idx = XENCTypeElementIdx;
      
      if (!ents || !xenc_check_ents_encryptability (ents, type_idx))
        {
          DO_SET (local_cursor_t*, lc, &lcl)
            {
              lc_free (lc);
            }
          END_DO_SET();
      
          DO_SET (xpath_keyinst_t*, xpath_kei, &xp_keys)
            {
              xpath_keyinst_free (xpath_kei);
            }
          END_DO_SET();
      
          if (!lcl)
            dk_free_box ((box_t) doc);
      
          dk_set_free (lcl);
      
          nss_free (_nss);
      
          if (err && err[0] == (caddr_t)3)
            sqlr_new_error ("42000", "XENC20", "XENC internal error %s %s", err[1], err[2]);
          else
            sqlr_new_error ("42000", "XENC20", "XENC internal error");
        }
      
      xpath_key = (xpath_keyinst_t *) dk_alloc_box ( sizeof (xpath_keyinst_t), DV_ARRAY_OF_POINTER);
      memset (xpath_key, 0, sizeof (xpath_keyinst_t));
      xpath_key->ents = ents;
      xpath_key->keyinst = (xenc_key_inst_t *) box_copy_tree ((box_t) keyinst);
      xpath_key->index = xpath_arg_pointer + 1;
      xpath_key->type_idx = type_idx;
      
      dk_set_push (&xp_keys, xpath_key);
      xpath_arg_pointer+=3;
    }

  xp_keys = dk_set_nreverse (xp_keys);
  xp_keys_arr = (xpath_keyinst_t **) dk_set_to_array (xp_keys);
  dk_set_free (xp_keys);

  DO_BOX (xpath_keyinst_t *, xk, inx, xp_keys_arr)
    {
      caddr_t err_ret = 0;
      caddr_t * txt_ents = xenc_generate_enc_texts (xk->keyinst, xk->type_idx, xk->ents, _nss, &err_ret, &sctx);
      int ent_inx;
      if (!xk->keyinst->xeki_super_key_inst)
	generate_ref_list = 1;
      if (!txt_ents)
	{
	  /* must free everything */
	  /* ... */
	  sqlr_new_error (".....", ".....", "%s", err_ret);
	}
      _DO_BOX (ent_inx, txt_ents)
	{
	  dk_set_push (&s_type_idxs, (void*) xk->type_idx);
	}
      END_DO_BOX;

      copies = fuse_arrays (&copies, txt_ents, DV_ARRAY_OF_POINTER);
      dk_free_box ((box_t) txt_ents);
      origs_ents = (xml_tree_ent_t**) fuse_arrays ((caddr_t**)&origs_ents, (caddr_t*)xk->ents, DV_ARRAY_OF_POINTER);

    }
  END_DO_BOX;

  if (s_type_idxs)
    {
      s_type_idxs = dk_set_nreverse (s_type_idxs);
      type_idxs = (ptrlong*) dk_set_to_array (s_type_idxs);
      dk_set_free (s_type_idxs);
    }

  DO_BOX (xpath_keyinst_t *, xk, inx, xp_keys_arr)
    {
      if (args[xk->index]->ssl_type != SSL_CONSTANT)
	qst_set (qst, args[xk->index], (caddr_t) xk->keyinst);
    }
  END_DO_BOX;


  if (dsig_template_str)
    {
      XENC_TRY (&t)
	{
	  dsig = dsig_template_ ((query_instance_t*) qst, dsig_template_str, &t, opts);
	}
      XENC_CATCH
	{
	  char buf [1024];
	  xenc_make_error (buf, sizeof (buf), t.xtb_err_code, t.xtb_err_buffer);
	  dk_free_box (t.xtb_err_buffer);
          DO_SET (local_cursor_t *, lc, &lcl)
            {
              lc_free (lc);
            }
          END_DO_SET();
	  if (!lcl)
	    dk_free_box ((box_t) doc);
	  dk_set_free (lcl);
	  nss_free (_nss);
	  sqlr_new_error ("42000", "XENC18", "could not create XML signature from template : %s", buf);
	}
      XENC_TRY_END (&t);

      dsig->dss_signature_1 = box_dv_short_string ("uninitialized");

      /* here we need encrypted parts */
      doc_ses = strses_allocate();

      if (origs_ents && BOX_ELEMENTS (origs_ents) > 0)
	{
	  caddr_t enc_text = NULL;
	  int inxs = BOX_ELEMENTS (origs_ents);

	  doc->xte_current = doc->xe_doc.xtd->xtd_tree;
	  subst_items = (subst_item_t *) dk_alloc_box (inxs * sizeof (subst_item_t), DV_ARRAY_OF_POINTER);

	  for (inx = 0; inx < inxs; inx++)
	    {
	      subst_items[inx].orig = (caddr_t*) origs_ents[inx]->xte_current;
	      subst_items[inx].copy = (caddr_t*) copies[inx];
	      subst_items[inx].type = type_idxs[inx];
	    }

	  xs = (xml_doc_subst_t *) dk_alloc (sizeof (xml_doc_subst_t));
	  memset (xs, 0, sizeof (xml_doc_subst_t));

	  xs->xs_doc = doc;
	  xs->xs_subst_items = subst_items;
	  xs->xs_soap_version = soap_version;
	  xs->xs_sign = 1;
	  xs->xs_namespaces = _nss;

	  enc_text = xml_doc_subst (xs);
	  SES_PRINT (doc_ses, enc_text);

	  dk_free_box ((box_t) subst_items);
          subst_items = 0;
	  xml_doc_subst_free(xs);
	  dk_free_box (enc_text);
	}
      else
	{
	  SES_PRINT (doc_ses, text);
	}

      if (dsig_initialize (qi, doc_ses, strses_length (doc_ses), dsig, &c, &c_err))
	{
	  char buf [1024];
          DO_SET (local_cursor_t *, lc, &lcl)
            {
              lc_free (lc);
            }
          END_DO_SET();
	  if (!lcl)
	    dk_free_box ((box_t) doc);
	  dk_set_free (lcl);
	  nss_free (_nss);
	  doc_ses->dks_in_buffer = NULL;
	  strses_free (doc_ses);
	  dsig_free (dsig);
	  strncpy (buf, c_err, 1024);
	  sqlr_new_error ("42000", "XENC19", "could not sign XML signature, %s", buf);
	}
      strses_free (doc_ses);
    }


  security_tags = xenc_generate_security_tags ((query_instance_t*) qst, xp_keys_arr, dsig, generate_ref_list, &err_ret_sec_tags, &sctx);
  if (err_ret_sec_tags)
    {
      dsig->dss_signature_1 = 0;
      goto finish2;
    }

  envelope = xml_find_child (doc->xte_current, "Envelope", WSS_SOAP_URI, 0, NULL);
  if (envelope && security_tags)
    {
      header = xml_find_child (envelope, "Header", WSS_SOAP_URI, 0, NULL);
      if (header)
	{
	  new_header = (caddr_t *) dk_alloc_box (box_length (header) + sizeof (caddr_t), DV_ARRAY_OF_POINTER);
	  memcpy (new_header, header, box_length (header));
	  memcpy (new_header + BOX_ELEMENTS (header), &security_tags, sizeof (caddr_t));
	  DO_BOX (caddr_t *, child, inx, envelope)
	    {
	      if (child == header)
		((caddr_t**)envelope)[inx] = new_header;
	    }
	  END_DO_BOX;
	}
      else
	{
	  dk_free_box ((box_t) security_tags);
	  security_tags = NULL;
	}
    }
  else
    {
      dk_free_box ((box_t) security_tags);
      security_tags = NULL;
    }

  xenc_nss_add_namespace_prefix (_nss, security_tags, WSSE_URI(&sctx), "wsse");
  xenc_nss_add_namespace_prefix (_nss, security_tags, DSIG_URI, "ds");
  xenc_nss_add_namespace_prefix (_nss, security_tags, XENC_URI, "xenc");
  xenc_nss_add_namespace_prefix (_nss, security_tags, WSU_URI(&sctx), "wsu");
  xenc_nss_add_namespace_prefix (_nss, security_tags, SOAP_URI(11), "SOAP");

  signature = xml_find_child (security_tags, "Signature", DSIG_URI, 0, 0);
  if (signature)
    {
      ctx = wsse_ctx_allocate ();
      XENC_TRY (&ctx->wc_tb)
	{
	  doc->xte_current = signature;
	  signature_val = dsig_sign_signature (dsig, doc, _nss, ctx);
	}
      XENC_CATCH
	{
	  xenc_make_error (err_buf, sizeof (err_buf), ctx->wc_tb.xtb_err_code, ctx->wc_tb.xtb_err_buffer);
	  wsse_ctx_free (ctx);
	  sign_err = 1;
	  dsig->dss_signature_1 = 0;
	  goto finish2;
	}
      XENC_TRY_END (&ctx->wc_tb);
      wsse_ctx_free (ctx);
    }

  doc->xte_current = doc->xe_doc.xtd->xtd_tree;

  if (origs_ents || signature_val)
    {
      int inxs = origs_ents ? BOX_ELEMENTS (origs_ents) : 0;
      int c = 0;
      inx = 0;
      if (signature_val)
	inxs ++;

      subst_items = (subst_item_t *) dk_alloc_box (inxs * sizeof (subst_item_t), DV_ARRAY_OF_POINTER);

      if (signature_val)
	{
	  subst_items[0].orig = (caddr_t *)dsig->dss_signature_1;
	  dsig->dss_signature_1 = 0;
	  subst_items[0].copy = (caddr_t *)signature_val;
	  subst_items[0].type = XENCTypeElementIdx;
	  inx = 1;
	  c = 1;
	}
      for (; inx < inxs; inx++)
	{
	  subst_items[inx].orig = (caddr_t*) origs_ents[inx - c]->xte_current;
	  subst_items[inx].copy = (caddr_t*) copies[inx - c];
	  subst_items[inx].type = type_idxs[inx - c];
	}
    }

  xs = (xml_doc_subst_t *) dk_alloc (sizeof (xml_doc_subst_t));
  memset (xs, 0, sizeof (xml_doc_subst_t));

  xs->xs_doc = doc;
  xs->xs_subst_items = subst_items;
  xs->xs_soap_version = soap_version;
  xs->xs_sign = 1;
  xs->xs_namespaces = _nss;

  /*  xs->xs_envelope = xml_find_child (doc->xte_current, "Envelope", WSS_SOAP_URI, 0, NULL);
      xs->xs_new_child_tags = security_tags; */

  ret_text = xml_doc_subst (xs);

  dk_free_tree ((box_t) copies);
  dk_free_box ((box_t) origs_ents);
  dk_free_box ((box_t) type_idxs);
  dk_free_box ((box_t) subst_items);

  xml_doc_subst_free(xs);

 finish2:

  DO_BOX (xpath_keyinst_t *, xk, inx, xp_keys_arr)
    {
      dk_free_box (xk->tag_text);
      dk_free_box ((box_t) xk);
    }
  END_DO_BOX;

  dk_free_box ((box_t) xp_keys_arr);


  DO_SET (local_cursor_t *, lc, &lcl)
    {
      lc_free (lc);
    }
  END_DO_SET();

  if (dsig)
    dsig_free (dsig);
  if (!lcl)
    dk_free_box ((box_t) doc);
  nss_free (_nss);
  dk_set_free (lcl);
  dk_free_box (signature_val);
  if (qr)
    qr_free (qr);

  if(sign_err)
    sqlr_new_error ("42000", "XENC34", "could not sign SOAP signed info: %s", err_buf);
  if (err_ret_sec_tags)
    sqlr_new_error ("42000", "XENC35", "%s", err_ret_sec_tags);
  return ret_text;
}

caddr_t
bif_xml_sign (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  id_hash_t * _nss = 0;
  xml_tree_ent_t * doc = xenc_get_entity_arg ((query_instance_t*) qst, args, 0, "xml_sign", &_nss);
  caddr_t text = bif_string_arg (qst, args, 0, "xml_sign");
  caddr_t dsig_template_str = bif_string_arg (qst, args, 1, "xml_sign");
  caddr_t top_elem = bif_string_arg (qst, args, 2, "xml_sign");
  xml_doc_subst_t * xs;
  caddr_t ret_text = 0;
  query_instance_t * qi = (query_instance_t*) qst;
  dsig_signature_t * dsig = 0;
  xenc_try_block_t t;
  xenc_err_code_t c;
  char * c_err;
  dk_session_t * doc_ses;
  subst_item_t * subst_items = 0;
  caddr_t *elem = 0, *signature = 0;
  caddr_t signature_val = 0;
  wsse_ctx_t * ctx;
  char err_buf[1024];
  int sign_err = 0;
  wsse_ser_ctx_t sctx;
  caddr_t * opts = NULL, *top, curr_nss, elem_copy = box_copy (top_elem), local;

  memset (&sctx, 0, sizeof (wsse_ser_ctx_t));

  XENC_TRY (&t)
    {
      dsig = dsig_template_ ((query_instance_t*) qst, dsig_template_str, &t, opts);
    }
  XENC_CATCH
    {
      char buf [1024];
      xenc_make_error (buf, sizeof (buf), t.xtb_err_code, t.xtb_err_buffer);
      dk_free_box (t.xtb_err_buffer);
      dk_free_box ((box_t) doc);
      nss_free (_nss);
      sqlr_new_error ("42000", "XENC18", "could not create XML signature from template : %s", buf);
    }
  XENC_TRY_END (&t);

  dsig->dss_signature_1 = box_dv_short_string ("uninitialized");

  doc_ses = strses_allocate();
  SES_PRINT (doc_ses, text);
  if (dsig_initialize (qi, doc_ses, strses_length (doc_ses), dsig, &c, &c_err))
    {
      char buf [1024];
      dk_free_box ((box_t) doc);
      nss_free (_nss);
      doc_ses->dks_in_buffer = NULL;
      strses_free (doc_ses);
      dsig_free (dsig);
      strncpy (buf, c_err, 1024);
      sqlr_new_error ("42000", "XENC19", "could not sign XML signature, %s", buf);
    }
  strses_free (doc_ses);

  signature = (caddr_t *) signature_serialize_1 (dsig, &sctx);
  if (!signature)
    {
      dsig->dss_signature_1 = 0;
      goto finish2;
    }

  top = doc->xte_current;
  /* must be configurable */
  local = strrchr (elem_copy, ':');
  if (local)
    {
      *local = 0;
      local++;
      elem = xml_find_child (top, (char *) elem, elem_copy, 0, NULL);
    }
  if (elem)
    {
      int inx;
      caddr_t * new_elem = (caddr_t *) dk_alloc_box (box_length (elem) + sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      memcpy (new_elem, elem, box_length (elem));
      memcpy (new_elem + BOX_ELEMENTS (elem), &signature, sizeof (caddr_t));
      curr_nss = (caddr_t) xenc_get_namespaces (elem, _nss);
      DO_BOX (caddr_t *, child, inx, top)
	{
	  if (child == elem)
	    {
	      dk_free_box (child);
	      ((caddr_t**)top)[inx] = new_elem;
	    }
	}
      END_DO_BOX;
      xenc_set_namespaces (new_elem, box_copy_tree (curr_nss), _nss);
    }
  else
    {
      sqlr_new_error (".....", ".....", "Can not find tag to sign");
    }

  xenc_nss_add_namespace_prefix (_nss, signature, DSIG_URI, "ds");
  xenc_nss_add_namespace_prefix (_nss, signature, XENC_URI, "xenc");

  ctx = wsse_ctx_allocate ();
  XENC_TRY (&ctx->wc_tb)
    {
      doc->xte_current = signature;
      signature_val = dsig_sign_signature (dsig, doc, _nss, ctx);
    }
  XENC_CATCH
    {
      xenc_make_error (err_buf, sizeof (err_buf), ctx->wc_tb.xtb_err_code, ctx->wc_tb.xtb_err_buffer);
      wsse_ctx_free (ctx);
      sign_err = 1;
      dsig->dss_signature_1 = 0;
      goto finish2;
    }
  XENC_TRY_END (&ctx->wc_tb);
  wsse_ctx_free (ctx);

  doc->xte_current = doc->xe_doc.xtd->xtd_tree;

  if (signature_val)
    {
      subst_items = (subst_item_t *) dk_alloc_box (sizeof (subst_item_t), DV_ARRAY_OF_POINTER);
      subst_items[0].orig = (caddr_t *)dsig->dss_signature_1;
      dsig->dss_signature_1 = 0;
      subst_items[0].copy = (caddr_t *)signature_val;
      subst_items[0].type = XENCTypeElementIdx;
    }

  xs = (xml_doc_subst_t *) dk_alloc (sizeof (xml_doc_subst_t));
  memset (xs, 0, sizeof (xml_doc_subst_t));

  xs->xs_doc = doc;
  xs->xs_subst_items = subst_items;
  xs->xs_soap_version = 0;
  xs->xs_sign = 1;
  xs->xs_namespaces = _nss;

  ret_text = xml_doc_subst (xs);
  dk_free_box ((box_t) subst_items);
  xml_doc_subst_free(xs);
  doc->xte_current = top;

 finish2:

  if (dsig)
    dsig_free (dsig);
  dk_free_box ((box_t) doc);
  nss_free (_nss);
  dk_free_box (signature_val);
  dk_free_box (elem_copy);
  if (sign_err)
    sqlr_new_error ("42000", "XENC34", "could not sign XML signed info: %s", err_buf);
  return ret_text;
}

typedef struct dsig_fullname_s
{
  caddr_t	uri;
  caddr_t	name;
} dsig_fullname_t;

void dsig_fullnames_free (dk_set_t names)
{
  DO_SET (dsig_fullname_t*, fullname, &names)
    {
      dk_free (fullname, sizeof (dsig_fullname_t));
    }
  END_DO_SET ();
  dk_set_free (names);
}

/* zero means error */
int dsig_add_reference_1 (dsig_signature_t * dsig, const char * uri, const char * name, caddr_t * curr)
{
  char * id = xml_find_attribute (curr, "Id", NULL);
  if (id)
    {
      NEW_VAR (dsig_reference_t, ref);
      NEW_VARZ (dsig_transform_t, tr);
      memset (ref, 0, sizeof (dsig_reference_t));

      ref->dsr_digest_method = box_dv_short_string (DSIG_SHA1_ALGO);
      ref->dsr_uri = dk_alloc_box (strlen (id) + 2 /* # . "zero" */, DV_STRING);
      ref->dsr_uri[0] = '#';
      memcpy (ref->dsr_uri + 1, id, strlen (id));
      ref->dsr_uri[box_length(ref->dsr_uri) - 1] = 0;


      tr->dst_name = box_dv_short_string (XML_CANON_EXC_ALGO);
      dk_set_push (&ref->dsr_transforms, tr);

      dk_set_push (&dsig->dss_refs, ref);
      return 1;
    }
  return 0;
}

/* zero means error */
int dsig_add_reference (dsig_signature_t * dsig, caddr_t * curr, dk_set_t names, char ** error_tag)
{
  if (DV_TYPE_OF (curr) != DV_ARRAY_OF_POINTER)
    return 1;
  else
    {
      char *szName = XML_ELEMENT_NAME (curr);
      char *szColon = strrchr (szName, ':');
      char *name = szColon ? szColon + 1 : szName;
      char *uri = szColon ? szName : 0;
      int uri_len = szColon ? szColon - szName : 0;
      int inx;

      error_tag[0] = name;

      DO_SET (dsig_fullname_t* , fullname, &names)
	{
	  if (!strcmp (name, fullname->name))
	    {
	      if (uri && (!strncmp (uri, fullname->uri, uri_len)))
		{
		  return dsig_add_reference_1 (dsig, uri, name, curr);
		}
	    }
	}
      END_DO_SET();

      DO_BOX (caddr_t*,child, inx, curr)
	{
	  if (inx)
	    {
	      if (!dsig_add_reference (dsig, child, names, error_tag))
		return 0;
	    }
	}
      END_DO_BOX;
    }
  return 1;
}

id_hash_t * nss_allocate (caddr_t * curr, const char * prefix, const char * uri,
			  const char * pr2, const char * uri2,
			  const char * pr3, const char * uri3)
{
  id_hash_t * h = id_hash_allocate (31, sizeof (caddr_t*), sizeof (caddr_t*),
				    voidptrhash, voidptrhashcmp);
  caddr_t * namespaces;

  namespaces = (caddr_t *) dk_alloc_box (2 * 3* sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  namespaces [0] = box_dv_short_string (prefix);
  namespaces [1] = box_dv_short_string (uri);
  namespaces [2] = box_dv_short_string (pr2);
  namespaces [3] = box_dv_short_string (uri2);
  namespaces [4] = box_dv_short_string (pr3);
  namespaces [5] = box_dv_short_string (uri3);
  id_hash_set (h, (caddr_t) &curr, (caddr_t)&namespaces);

  return h;
}

/* loads dsig template and extend it by inclusion additional tags to be signed */
/* dsig_template_ext
   @ xml - initialization xml entity to be signed,
   @ dsig template pre - initial XML signature text,
   [
     @ uri - URI of tag to be signed,
     @ name - name of tag to be signed
   ]*
*/
caddr_t bif_dsig_template_ext (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  xml_tree_ent_t * xml = bif_tree_ent_arg (qst, args, 0, "dsig_template_ext");
  caddr_t dsig_template_pre = bif_string_arg (qst, args, 1, "dsig_template_ext");
  int curr_arg_sel;
  int curr_arg_sel_o =  curr_arg_sel = 2;
  dk_set_t names = 0; /* dsig_fullname_t */
  xenc_try_block_t t;
  dsig_signature_t * dsig = 0;
  caddr_t * ret;
  char * error_tag = "unknown";
  xml_tree_ent_t * dsig_xte = 0;
  xml_doc_subst_t * xs;
  caddr_t ret_text;
  wsse_ser_ctx_t sctx;
  caddr_t * opts = NULL;

  memset (&sctx, 0, sizeof (wsse_ser_ctx_t));

  if (BOX_ELEMENTS_INT(args) > 2)
    {
      caddr_t try_ns_spec = bif_arg (qst, args, 2, "xenc_encrypt");
      if (ARRAYP (try_ns_spec)) /* namespaces are defined */
	{
	  xenc_set_serialization_ctx (try_ns_spec, &sctx);
	  curr_arg_sel ++;
	  curr_arg_sel_o = curr_arg_sel;
	  opts = (caddr_t *)try_ns_spec;
	}
    }
  /* read URI, tag pair */
  while (BOX_ELEMENTS_INT (args) > curr_arg_sel + 1)
    {
      bif_string_arg (qst, args, curr_arg_sel, "dsig_template_ext");
      bif_string_arg (qst, args, curr_arg_sel + 1, "dsig_template_ext");
      curr_arg_sel+=2;
    }
  curr_arg_sel = curr_arg_sel_o;

  while (BOX_ELEMENTS_INT (args) > curr_arg_sel + 1)
    {
      caddr_t uri = bif_string_arg (qst, args, curr_arg_sel, "dsig_template_ext");
      caddr_t name = bif_string_arg (qst, args, curr_arg_sel + 1, "dsig_template_ext");
      NEW_VARZ (dsig_fullname_t, ff);

      ff->uri = uri;
      ff->name = name;
      dk_set_push (&names, ff);
      curr_arg_sel+=2;
    }

  XENC_TRY (&t)
    {
      dsig = dsig_template_ ((query_instance_t*) qst, dsig_template_pre, &t, opts);
    }
  XENC_CATCH
    {
      char buf [1024];
      xenc_make_error (buf, sizeof (buf), t.xtb_err_code, t.xtb_err_buffer);
      dsig_fullnames_free (names);
      dk_free_box (t.xtb_err_buffer);
      sqlr_new_error ("42000", "XENC21", "could not create XML signature from template : %s", buf);
    }
  XENC_TRY_END (&t);

  if (!dsig_add_reference (dsig, xml->xte_current, names, &error_tag))
    {
      dsig_fullnames_free (names);
      dsig_free (dsig);
      sqlr_new_error ("42000", "XENC22", "referenced tag [%s] has no Id attribute", error_tag);
    }

  dsig_fullnames_free (names);

  ret = signature_serialize_1 (dsig, &sctx);
  dsig_xte = xte_from_tree ((caddr_t) ret, (query_instance_t*) qst);

  xs = (xml_doc_subst_t *) dk_alloc (sizeof (xml_doc_subst_t));
  memset (xs, 0, sizeof (xml_doc_subst_t));

  xs->xs_doc = dsig_xte;
  xs->xs_namespaces = nss_allocate(dsig_xte->xte_current, "ds", DSIG_URI,
				   "wsse", WSSE_URI(&sctx),
				   "wsu", WSU_URI(&sctx));
  ret_text = xml_doc_subst (xs);
  dk_free_tree ((box_t) ret);
  nss_free (xs->xs_namespaces);
  xml_doc_subst_free (xs);

  dsig_free (dsig);
  return  ret_text;
}

void dsig_sec_init();

/* util functions */

caddr_t * fuse_arrays (caddr_t ** parr, caddr_t * arr2, dtp_t dtp)
{
  uint32 sz = (parr[0] ? box_length (parr[0]):0) +box_length (arr2);
  caddr_t * arr = (caddr_t *) dk_alloc_box (sz, dtp);

  if (parr[0])
    memcpy (arr, parr[0], box_length (parr[0]));
  memcpy (arr + (parr[0] ? BOX_ELEMENTS(parr[0]) : 0), arr2, box_length (arr2));

  dk_free_box ((box_t) parr[0]);
  parr[0] = arr;

  fflush (stdout);


  return arr;
}


int type_of (caddr_t box)
{
  return DV_TYPE_OF (box);
}

static
void xenc_security_token_id_format (char * buf, int maxlen, xenc_id_t id, int is_ref)
{
  if (maxlen < 250)
    {
      snprintf (buf, maxlen, "overflow");
      return;
    }

  memset (buf, 0, maxlen);
  if (!is_ref)
    snprintf (buf, maxlen, "SecurityToken-");
  else
    snprintf (buf, maxlen, "#SecurityToken-");

  uuid_unparse (id, buf + strlen (buf));
}

void xenc_write_key_info_tag (dk_session_t * ses, const char * name)
{
  SES_WRITE (ses, "<ds:KeyInfo " DS_NAMESPACE_STR ">");
  SES_WRITE (ses, "<ds:KeyName>");
  SES_WRITE (ses, (char*)name);
  SES_WRITE (ses, "</ds:KeyName></ds:KeyInfo>");
}

typedef struct xenc_tag_s
{
  char *	xt_name;
  dk_set_t	xt_atts;
  dk_set_t	xt_childs;
} xenc_tag_t;


xenc_tag_t * xenc_tag_create (const char * uri, const char * name)
{
  xenc_tag_t * tag = (xenc_tag_t *) dk_alloc (sizeof (xenc_tag_t));
  size_t urilen = strlen (uri);
  caddr_t tag_name = box_dv_ubuf (urilen + strlen (name));
  memset (tag, 0, sizeof (xenc_tag_t));
  strcpy (tag_name, uri);
  strcpy (tag_name + urilen, name);
  tag->xt_name = box_dv_uname_from_ubuf (tag_name);

#ifdef DEBUG
  dbg_printf (("xenc_tag_create (%s)\n", name));
#endif
  return tag;
}

void xenc_tag_add_att (xenc_tag_t * t, char* name, char* val)
{
  char * _val = box_dv_short_string (val);
  char * _name = box_dv_uname_string (name);
#ifdef DEBUG
  dbg_printf (("xenc_tag_add_att (%s,%s,%s)\n", t->xt_name, name, val));
#endif
  dk_set_push (&t->xt_atts, _val);
  dk_set_push (&t->xt_atts, _name);
}

void xenc_tag_add_att_ns (xenc_tag_t * t, const char*ns, const char* name, const char* val)
{
  caddr_t _val = box_dv_short_string (val);
  caddr_t _name = box_dv_ubuf (strlen (ns) + strlen (name));

  snprintf (_name, box_length (_name), "%s%s", ns, name);
#ifdef DEBUG
  dbg_printf (("xenc_tag_add_att_ns (%s,%s,%s)\n", t->xt_name, _name, val));
#endif
  dk_set_push (&t->xt_atts, _val);
  dk_set_push (&t->xt_atts, box_dv_uname_from_ubuf (_name));
}

xenc_tag_t* xenc_tag_add_child (xenc_tag_t * t, caddr_t * child)
{
#ifdef DEBUG
  /* dbg_printf (("xenc_tag_add_child (%s,%s)\n", t->xt_name, ((caddr_t*)child[0])[0])); */
  dbg_printf (("xenc_tag_add_child (%s, ...)\n", t->xt_name));
#endif
  dk_set_push (&t->xt_childs, (caddr_t)child);
  return t;
}

caddr_t * xenc_tag_finalize (xenc_tag_t * t)
{
  dk_set_t atts = CONS (t->xt_name, t->xt_atts);
  dk_set_t childs = dk_set_nreverse (t->xt_childs);
  caddr_t * tag_node;

#ifdef DEBUG
  dbg_printf (("xenc_tag_finalize (%s)\n", t->xt_name));
#endif

  dk_set_push (&childs, dk_set_to_array (atts));
  tag_node = (caddr_t *) dk_set_to_array (childs);

  t->xt_childs = childs; /* for later delete */
  t->xt_atts = atts; /* for later delete */
  return tag_node;
}

void xenc_tag_free (xenc_tag_t * t)
{
#ifdef DEBUG
  dbg_printf (("xenc_tag_free (%s)...", t->xt_name));
#endif
  dk_set_free (t->xt_childs);
  dk_set_free (t->xt_atts);
  dk_free (t, sizeof (xenc_tag_t));
#ifdef DEBUG
  dbg_printf (("done.\n"));
#endif
}

xenc_tag_t * xenc_tag_add_child_BN (xenc_tag_t * tag, BIGNUM * bn)
{
 char * buffer = dk_alloc_box (BN_num_bytes (bn), DV_BIN);
 char * buffer_base64 = dk_alloc_box (box_length (buffer) * 2, DV_STRING);
 char * bn_base64;
 long len;
 BN_bn2bin (bn, (unsigned char *)buffer);
 len = xenc_encode_base64 (buffer, buffer_base64, box_length (buffer));

 bn_base64 = dk_alloc_box (len + 1, DV_STRING);
 memcpy (bn_base64, buffer_base64, len);
 bn_base64 [len] = 0;

 xenc_tag_add_child (tag, (caddr_t*) bn_base64);
 dk_free_box (buffer);
 dk_free_box (buffer_base64);
 return tag;
}

caddr_t ** xenc_generate_ext_info (xenc_key_t * key)
{
  dk_set_t l = 0;
  caddr_t ** array;
  if (key->xek_type == DSIG_KEY_RSA)
    {
      xenc_tag_t * rsakeyval = xenc_tag_create (DSIG_URI, ":RSAKeyValue");
      xenc_tag_t * rsamodulus = xenc_tag_create (DSIG_URI, ":Modulus");
      xenc_tag_t * rsaexponent = xenc_tag_create (DSIG_URI, ":Exponent");

      xenc_tag_add_child_BN (rsamodulus, key->ki.rsa.rsa_st->n);
      xenc_tag_add_child_BN (rsaexponent, key->ki.rsa.rsa_st->e);

      xenc_tag_add_child (rsakeyval, xenc_tag_finalize (rsamodulus));
      xenc_tag_add_child (rsakeyval, xenc_tag_finalize (rsaexponent));

      dk_set_push (&l, (void *) xenc_tag_finalize (rsakeyval));

      xenc_tag_free (rsamodulus);
      xenc_tag_free (rsaexponent);
      xenc_tag_free (rsakeyval);
    }
  else if (key->xek_type == DSIG_KEY_DSA)
    {
      xenc_tag_t * dsakeyval = xenc_tag_create (DSIG_URI, ":DSAKeyValue");
      xenc_tag_t * p = xenc_tag_create (DSIG_URI, ":P");
      xenc_tag_t * q = xenc_tag_create (DSIG_URI, ":Q");
      xenc_tag_t * g = xenc_tag_create (DSIG_URI, ":G");
      xenc_tag_t * y = xenc_tag_create (DSIG_URI, ":Y");
      DSA * dsa = key->ki.dsa.dsa_st;


      xenc_tag_add_child_BN (p, dsa->p);
      xenc_tag_add_child_BN (p, dsa->q);
      xenc_tag_add_child_BN (p, dsa->g);
      xenc_tag_add_child_BN (p, dsa->pub_key);

      xenc_tag_add_child (dsakeyval, xenc_tag_finalize (p));
      xenc_tag_add_child (dsakeyval, xenc_tag_finalize (q));
      xenc_tag_add_child (dsakeyval, xenc_tag_finalize (g));
      xenc_tag_add_child (dsakeyval, xenc_tag_finalize (y));

      dk_set_push (&l, (void *) xenc_tag_finalize (dsakeyval));

      xenc_tag_free (dsakeyval);
      xenc_tag_free (p);
      xenc_tag_free (q);
      xenc_tag_free (g);
      xenc_tag_free (y);
    }

  l = dk_set_nreverse (l);

  array = (caddr_t**) dk_set_to_array (l);
  dk_set_free (l);

  return array;
}

caddr_t *
xenc_generate_key_tag (xenc_key_t * key, int extended_ver, xenc_id_t * ids, int pref_KI, wsse_ser_ctx_t * sctx, int x509sertype)
{
  caddr_t * ret;
  xenc_tag_t * keyi = xenc_tag_create(DSIG_URI, ":KeyInfo");

  if (XENC_T_X509_CERT == x509sertype && key->xek_x509)
    {
      caddr_t encoded_cert = 0;
      xenc_tag_t * data = (xenc_tag_t *) xenc_tag_create (DSIG_URI, ":X509Data");
      xenc_tag_t * cert = (xenc_tag_t *) xenc_tag_create (DSIG_URI, ":X509Certificate");
      X509 * x509 = key->xek_x509;
      BIO * b = BIO_new (BIO_s_mem());

      if (i2d_X509_bio(b,x509))
	{
	  encoded_cert = certificate_encode (b, WSSE_BASE64_ENCODING_TYPE);
	}
      BIO_free (b);

      xenc_tag_add_child (cert, (caddr_t *) encoded_cert); /* b64 encoded certificate */
      xenc_tag_add_child (data, xenc_tag_finalize (cert));
      xenc_tag_add_child (keyi, xenc_tag_finalize (data));
      xenc_tag_free (data);
      xenc_tag_free (cert);
    }
  else if (key->xek_x509_ref || key->xek_x509_KI || (key->xek_type == DSIG_KEY_KERBEROS))
    {
      xenc_tag_t * stokenref = (xenc_tag_t *) xenc_tag_create (WSSE_URI(sctx), ":SecurityTokenReference");
      xenc_tag_t * ref;
      if (pref_KI && (key->xek_x509_KI || key->xek_kerb_KI))
	{
	  ref = (xenc_tag_t *) xenc_tag_create (WSSE_URI(sctx), ":KeyIdentifier");
	  if (key->xek_kerb_KI)
	    {
	      xenc_tag_add_att (ref, "ValueType", WSSE_KERBTGT_VALUE_TYPE);
	      xenc_tag_add_child (ref, (caddr_t *) box_dv_short_string (key->xek_kerb_KI));
	    }
	  else
	    {
	      if (sctx->wsc_wsse == WSOASIS)
		xenc_tag_add_att (ref, "ValueType", WSSE_OASIS_X509_SUBJECT_KEYIDENTIFIER);
	      else
		xenc_tag_add_att (ref, "ValueType", WSSE_X509_VALUE_TYPE);
	      xenc_tag_add_child (ref, (caddr_t *) box_dv_short_string (key->xek_x509_KI));
	    }
	}
      else
	{
	  char buf[255];
	  ref =  xenc_tag_create (WSSE_URI(sctx), ":Reference");
	  xenc_security_token_id_format (buf, 255, key->xek_x509_ref, 1);
	  xenc_tag_add_att (ref, "URI", buf);
	  if (sctx->wsc_wsse == WSOASIS)
	    {
	      if (key->xek_utok)
		xenc_tag_add_att (ref, "ValueType", WSSE_OASIS_UTOKEN_PROFILE "#UsernameToken");
	      else
		xenc_tag_add_att (ref, "ValueType", WSSE_OASIS_X509_VALUE_TYPE);
	    }
	}

      xenc_tag_add_child (stokenref, xenc_tag_finalize (ref));
      xenc_tag_add_child (keyi, xenc_tag_finalize (stokenref));
      xenc_tag_free (stokenref);
      xenc_tag_free (ref);
    }
  else
    {
      xenc_tag_t * keyn = xenc_tag_create(DSIG_URI, ":KeyName");
      xenc_tag_add_child (keyn, (caddr_t *) box_dv_short_string (key->xek_name));
      xenc_tag_add_child (keyi, xenc_tag_finalize (keyn));
      if (extended_ver)
	{
	  caddr_t ** exts = xenc_generate_ext_info (key);
	  int inx;
	  DO_BOX (caddr_t *, ext, inx, exts)
	    {
	      xenc_tag_add_child (keyi, ext);
	    }
	  END_DO_BOX;
	  dk_free_box ((box_t) exts);
	}
      if (ids)
	{
	  int inx;
	  xenc_tag_t * rl = xenc_tag_create (XENC_NS, ":ReferenceList");
	  DO_BOX (xenc_id_t, id, inx, ids)
	    {
	      char uuid_str[200];
	      char buf[256];
	      xenc_tag_t * dr;
	      uuid_unparse (id, uuid_str);
	      snprintf (buf, 255, "#Id-%s", uuid_str);
	      dr = xenc_tag_create (XENC_NS, ":DataReference");
	      xenc_tag_add_att (dr, "URI", buf);
	      xenc_tag_add_child (rl, xenc_tag_finalize (dr));
	      xenc_tag_free (dr);
	    }
	  END_DO_BOX;
	  xenc_tag_add_child (keyi, xenc_tag_finalize (rl));
	  xenc_tag_free (rl);
	}
      xenc_tag_free (keyn);
    }
  ret = xenc_tag_finalize (keyi);
  xenc_tag_free (keyi);
  return ret;
}

#define DSIG_SER_EXT_V	1
#define DSIG_SER_REST_V	0

#if 0
void xenc_serialize_key (query_instance_t * qi, xenc_key_t * key, dk_session_t * ses)
{
  caddr_t * key_tag = xenc_generate_key_tag (key, DSIG_SER_EXT_V);
  xml_tree_ent_t * xte = xte_from_tree ( (caddr_t) key_tag, qi);

  xte_serialize ( (xml_entity_t*) xte, ses);

  /* dk_free_box (key_tag); */
  dk_free_box (xte);
}
#else
void xenc_serialize_key (query_instance_t * qi, xenc_key_t * key, dk_session_t * ses)
{
  switch (key->xek_type)
    {
    case DSIG_KEY_3DES:
      /* */
      CATCH_WRITE_FAIL (ses)
	{
	  session_buffered_write (ses, (char *)(key->ki.triple_des.k1), 8);
	  session_buffered_write (ses, (char *)(key->ki.triple_des.k2), 8);
	  session_buffered_write (ses, (char *)(key->ki.triple_des.k3), 8);
	}
      FAILED
	{
	}
      END_WRITE_FAIL (ses);
      break;
#ifdef AES_ENC_ENABLE
    case DSIG_KEY_AES:
      CATCH_WRITE_FAIL (ses)
	{
	  session_buffered_write (ses, (char *)(key->ki.aes.k), key->ki.aes.bits / 8 /* number of bits in a byte */);
	}
      FAILED
	{
	}
      END_WRITE_FAIL (ses);
      break;
#endif
    case DSIG_KEY_RAW:
      /* */
      CATCH_WRITE_FAIL (ses)
	{
	  session_buffered_write (ses, "hi!", 3);
	}
      FAILED
	{
	}
      END_WRITE_FAIL (ses);
      break;
    case DSIG_KEY_DSA:
      CATCH_WRITE_FAIL (ses)
	{
	  session_buffered_write (ses, "XXXXXXXXXXXX CCCCCCC CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC", 30);
	}
      FAILED
	{
	}
      END_WRITE_FAIL (ses);
      break;

    case DSIG_KEY_RSA:
    default:
      GPF_T1 ("key serialization is not supported");
    }
}
#endif


caddr_t certificate_encode (BIO * b, const char * encoding_type)
{
  if (!strcmp (encoding_type, WSSE_BASE64_ENCODING_TYPE))
    {
      caddr_t data_cert0;
      int len = BIO_get_mem_data (b, &data_cert0);
      caddr_t data_cert_base64 = (caddr_t) dk_alloc (len * 2 + 1);
      int len_base64;
      caddr_t data_cert = dk_alloc_box (len + 1, DV_BIN);
      caddr_t encoded_cert;

      memcpy (data_cert, data_cert0, len);
      data_cert[len] = 0;
      len_base64 = xenc_encode_base64 (data_cert, data_cert_base64, len);
      encoded_cert = dk_alloc_box (len_base64 + 1, DV_STRING);
      memcpy (encoded_cert, data_cert_base64, len_base64);
      encoded_cert [len_base64] = 0;
      dk_free (data_cert_base64, len * 2 + 1);
      dk_free_box (data_cert);
      return encoded_cert;
    }
  else
    return 0;
}

caddr_t
decode_box (caddr_t encoded_cert, const char * encoding_type)
{
  if (!encoded_cert)
    return 0;
  if (!strcmp (encoding_type, WSSE_BASE64_ENCODING_TYPE)
      || !strcmp (encoding_type, WSSE_OASIS_BASE64_ENCODING_TYPE))
    {
      caddr_t cert = box_copy (encoded_cert);
      int len = xenc_decode_base64 (cert, cert + box_length (encoded_cert));
      caddr_t ret_cert = dk_alloc_box (len + 1, DV_STRING);
      memcpy (ret_cert, cert, len);
      ret_cert[len] = 0;
      dk_free_box (cert);
      return ret_cert;
    }
  return 0;
}

xenc_key_t *
certificate_decode (caddr_t encoded_cert, const char * value_type,
		     const char * encoding_type)
{
  if (!strcmp (value_type, WSSE_X509_VALUE_TYPE) || !strcmp (value_type, WSSE_OASIS_X509_VALUE_TYPE))
    {
      caddr_t decoded_cert = decode_box (encoded_cert, encoding_type);
      if (decoded_cert)
	{
	  xenc_key_t * key = xenc_key_create_from_x509_cert (NULL, decoded_cert, NULL, NULL, 1, CERT_DER_FORMAT,0,0);
	  dk_free_box (decoded_cert);
	  return key;
	}
    }
  else if (!strcmp (value_type, WSSE_KERBTGS_VALUE_TYPE))
    {
      caddr_t decoded_cert = decode_box (encoded_cert, encoding_type);
      if (decoded_cert)
	{
	  xenc_key_t * key = xenc_key_create_from_kerberos_tgs_cert (NULL, decoded_cert);
	  dk_free_box (decoded_cert);
	  return key;
	}
    }
#if 0 /* still not supported */
  else if (!strcmp (value_type, WSSE_KERB_VALUE_TYPE))
    {
      kerb[0] = (unsigned char*) certificate_KERB_decode (encoded_cert, encoding_type);
    }
#endif
  return 0;
}

void xenc_generate_certificate_tag (query_instance_t * qi, xenc_key_t * k,
				    dk_set_t * l, xenc_id_t * ids, wsse_ser_ctx_t * sctx)
{
  if (k)
    {
      caddr_t encoded_cert = 0;
      caddr_t value_type = 0;

      /* x509 certificate */
      if (k->xek_x509)
	{
	  X509 * x509 = k->xek_x509;
	  BIO * b = BIO_new (BIO_s_mem());

	  if (i2d_X509_bio(b,x509))
	    {
	      encoded_cert = certificate_encode (b, WSSE_BASE64_ENCODING_TYPE);
	      if (sctx->wsc_wsse == WSOASIS)
		value_type = WSSE_OASIS_X509_VALUE_TYPE;
	      else
		value_type = WSSE_X509_VALUE_TYPE;
	    }
	  BIO_free (b);
	}
#ifdef _KERBEROS
      else if (k->xek_type == DSIG_KEY_KERBEROS)
	{
	  BIO * b = BIO_new (BIO_s_mem());
	  BIO_write (b, k->xek_kerberos_tgs,  box_length (k->xek_kerberos_tgs));
	  encoded_cert = certificate_encode (b, WSSE_BASE64_ENCODING_TYPE);
	  value_type = WSSE_KERBTGS_VALUE_TYPE;
	}
#endif
      if (encoded_cert)
	{
	  xenc_tag_t * bst = (xenc_tag_t *) xenc_tag_create (WSSE_URI(sctx), ":BinarySecurityToken");
	  char out[255];
	  xenc_security_token_id_format (out, 255, k->xek_x509_ref, 0);

	  xenc_tag_add_att (bst, "ValueType", value_type);
	  if (sctx->wsc_wsse == WSOASIS)
	    xenc_tag_add_att (bst, "EncodingType", WSSE_OASIS_BASE64_ENCODING_TYPE);
	  else
	    xenc_tag_add_att (bst, "EncodingType", WSSE_BASE64_ENCODING_TYPE);

	  xenc_tag_add_att_ns (bst, WSU_URI(sctx), ":Id", out);
	  xenc_tag_add_child (bst, (caddr_t *) encoded_cert);

	  dk_set_push (l, xenc_tag_finalize (bst));
	  xenc_tag_free (bst);
	}
      if (k->xek_utok)
	{
	  xenc_tag_t * bst = xenc_tag_create (WSSE_URI(sctx), ":UsernameToken");
	  xenc_tag_t * uname = xenc_tag_create (WSSE_URI(sctx), ":Username");
	  xenc_tag_t * passw = xenc_tag_create (WSSE_URI(sctx), ":Password");
	  xenc_tag_t * nonce = xenc_tag_create (WSSE_URI(sctx), ":Nonce");
	  xenc_tag_t * creat = xenc_tag_create (WSU_URI(sctx), ":Created");
	  u_tok_t * tok = k->xek_utok;
	  char out[255];

	  xenc_security_token_id_format (out, 255, k->xek_x509_ref, 0);

	  xenc_tag_add_child (uname, (caddr_t *)box_copy(tok->uname));
	  xenc_tag_add_child (bst, xenc_tag_finalize (uname));
	  xenc_tag_free (uname);

	  xenc_tag_add_child (passw, (caddr_t *)box_copy(tok->pass));
	  if (sctx->wsc_wsse == WSOASIS)
	    xenc_tag_add_att (passw, "Type", WSSE_OASIS_UTOKEN_PROFILE "#PasswordText");
	  else
	    xenc_tag_add_att (passw, "Type", "wsse:PasswordText");
	  xenc_tag_add_child (bst, xenc_tag_finalize (passw));
	  xenc_tag_free (passw);

	  xenc_tag_add_child (nonce, (caddr_t *)box_copy(tok->nonce));
	  xenc_tag_add_child (bst, xenc_tag_finalize (nonce));
	  xenc_tag_free (nonce);

	  xenc_tag_add_child (creat, (caddr_t *)box_copy(tok->ts));
	  xenc_tag_add_child (bst, xenc_tag_finalize (creat));
	  xenc_tag_free (creat);

	  xenc_tag_add_att_ns (bst, WSU_URI(sctx), ":Id", out);

	  dk_set_push (l, xenc_tag_finalize (bst));
	  xenc_tag_free (bst);
	}
    }
}


caddr_t xenc_generate_encrypted_key_tag (query_instance_t * qi, xenc_key_inst_t * kei, xenc_key_inst_t * superi, caddr_t * err_ret, wsse_ser_ctx_t * sctx)
{
  xenc_key_t * key = xenc_get_key_by_name (kei->xeki_key_name, 1);
  xenc_key_t * super = xenc_get_key_by_name (superi->xeki_key_name, 1);
  dk_session_t * ses;
  dk_session_t * kses;
  caddr_t ret;
  int inx, refs = 0;
  xenc_tag_t * ek, *em, *cd, *cv;

  if (!key || !super)
    GPF_T1 ("Some encryption keys are not found");


  ek = xenc_tag_create (XENC_NS, ":EncryptedKey");
  em = xenc_tag_create (XENC_NS, ":EncryptionMethod");
  cd = xenc_tag_create (XENC_NS, ":CipherData");
  cv = xenc_tag_create (XENC_NS, ":CipherValue");

  xenc_tag_add_att (em, "Algorithm", super->xek_enc_algo->xea_ns);
  xenc_tag_add_child (ek, xenc_tag_finalize (em));
  xenc_tag_add_child (ek, xenc_generate_key_tag (super, DSIG_SER_REST_V, 0, 1 /* KI when possible */, sctx, 0));


  ses = strses_allocate ();
  kses = strses_allocate ();
  CATCH_WRITE_FAIL (kses)
    {
      xenc_serialize_key (qi, key, kses);
    }
  FAILED
    {
      GPF_T;
    }
  END_WRITE_FAIL (kses);

  {
    xenc_try_block_t t;
    XENC_TRY (&t)
      {
	(super->xek_enc_algo->xea_enc) (kses, strses_length (kses), ses, super, &t);
      }
    FAILED
      {
	char buf [1024];
	xenc_make_error (buf, sizeof (buf), t.xtb_err_code, t.xtb_err_buffer);
	if (err_ret) err_ret[0] = box_dv_short_string (buf);
      }
    XENC_TRY_END (&t);
  }

  xenc_tag_add_child (cv, (caddr_t*) strses_string (ses));
  strses_free (kses);
  strses_free (ses);

  xenc_tag_add_child (cd, xenc_tag_finalize (cv));
  xenc_tag_add_child (ek, xenc_tag_finalize (cd));

  if (kei->xeki_ids)
    {
      xenc_tag_t * reflist = xenc_tag_create (XENC_URI, ":ReferenceList");
      DO_BOX (xenc_id_t, id, inx, kei->xeki_ids)
	{
	  char uuid_str[200];
	  char buf[256];
	  xenc_tag_t * dr;
	  uuid_unparse (id, uuid_str);
	  snprintf (buf, 255, "#Id-%s", uuid_str);
	  dr = xenc_tag_create (XENC_NS, ":DataReference");
	  xenc_tag_add_att (dr, "URI", buf);
	  xenc_tag_add_child (reflist, xenc_tag_finalize (dr));
	  xenc_tag_free (dr);
	  refs ++;
	}
      END_DO_BOX;
      xenc_tag_add_child (ek, xenc_tag_finalize (reflist));
      xenc_tag_free (reflist);
    }

  ret = (caddr_t) xenc_tag_finalize (ek);
  xenc_tag_free (ek);
  xenc_tag_free (em);
  xenc_tag_free (cv);
  xenc_tag_free (cd);

  if (!refs)
    {
      dk_free_tree (ret);
      ret = NULL;
    }

  return ret;
}

caddr_t * xenc_generate_ref_list (query_instance_t * qi, xenc_id_t * ids)
{
  xenc_tag_t * reflist = xenc_tag_create (XENC_URI, ":ReferenceList");
  int inx;
  caddr_t * ret;
  DO_BOX (xenc_id_t, id, inx, ids)
    {
      char id_str[200];
      xenc_tag_t * ref;
      memset (id_str, 0, 200);
      stpcpy (id_str, "#Id-");
      uuid_unparse ((uuid_t*)id, id_str + strlen (id_str));

      ref = xenc_tag_create (XENC_URI, ":DataReference");
      xenc_tag_add_att (ref, "URI", id_str);
      xenc_tag_add_child (reflist, xenc_tag_finalize (ref));
      xenc_tag_free (ref);
    }
  END_DO_BOX;
  ret = xenc_tag_finalize (reflist);
  xenc_tag_free (reflist);
  return ret;
}

void xenc_generate_key_taglist (query_instance_t * qi, xenc_key_inst_t * xki, dk_set_t * tags,
				int generate_ref_list, caddr_t * err_ret, wsse_ser_ctx_t * sctx)
{
  xenc_key_inst_t * kei = xki;
  xenc_key_inst_t * super_kei = 0;
  dk_set_t l = 0;

  dk_set_push (&l, kei);

  while (kei->xeki_super_key_inst)
    {
      dk_set_push (&l, kei->xeki_super_key_inst);
      kei = kei->xeki_super_key_inst;
    }

  DO_SET (xenc_key_inst_t *, key_inst, &l)
    {
      xenc_key_t * key = xenc_get_key_by_name (key_inst->xeki_key_name, 1);
      if (key_inst->xeki_ids)
	{
	  if (super_kei)
	    {
	      caddr_t ki_tag = xenc_generate_encrypted_key_tag (qi, key_inst, super_kei, err_ret, sctx);
	      if (ki_tag)
	        dk_set_push (tags, ki_tag);
	    }
	  else if (key->xek_x509_ref) /* some certificate */
	    xenc_generate_certificate_tag (qi, key, tags, key_inst->xeki_ids, sctx);
#if 1
	  else
	    {
#if 0
	      dk_set_push (tags, xenc_generate_key_tag (key, DSIG_SER_REST_V, 0));
#endif
	      if (generate_ref_list)
		dk_set_push (tags, xenc_generate_ref_list (qi, key_inst->xeki_ids));
	    }
#endif
	}
      super_kei = key_inst;
    }
  END_DO_SET ();

  dk_set_free (l);
}


caddr_t *
xenc_generate_security_tags (query_instance_t* qi, xpath_keyinst_t ** arr,
    dsig_signature_t * dsig, int generate_ref_list, caddr_t * err_ret,
    wsse_ser_ctx_t * sctx)
{
  int inx;
  dk_set_t l = 0;
  xenc_tag_t * security;
  caddr_t * arr_ret;

  security = xenc_tag_create (WSSE_URI(sctx), ":Security");
  xenc_tag_add_att (security, SOAP_TYPE_SCHEMA11 ":mustUnderstand", "1");

  /* Certificates */
  if (dsig && dsig->dss_key)
    xenc_generate_certificate_tag (qi, dsig->dss_key, &l, 0, sctx);

  if (dsig)
    {
      caddr_t * dsig_tag;

      dsig_tag = (caddr_t *) signature_serialize_1 (dsig, sctx);

      if (dsig_tag)
	dk_set_push (&l, dsig_tag);
#ifdef DEBUG
      else
	GPF_T1 ("signature can not be serialized");
#endif
    }

  if (arr)
    {
      DO_BOX (xpath_keyinst_t *, xk, inx, arr)
	{
	  xenc_generate_key_taglist (qi, xk->keyinst, &l, generate_ref_list, err_ret, sctx);
	}
      END_DO_BOX;
    }

  l = dk_set_nreverse (l);

  DO_SET (caddr_t *, elem, &l)
    {
      xenc_tag_add_child (security, elem);
    }
  END_DO_SET();

  dk_set_free (l);

  arr_ret = xenc_tag_finalize (security);
  xenc_tag_free (security);

  if (err_ret && err_ret[0])
    {
      dk_free_tree ((box_t) arr_ret);
      return 0;
    }
  return arr_ret;
}

typedef struct xenc_replace_s
{
  caddr_t *		xr_sel_tag;
  xenc_reference_t	xr_id;
  caddr_t		xr_replace_text;
} xenc_replace_t;

caddr_t * xenc_sel_tree_get (caddr_t * tree, xenc_reference_t ref, id_hash_t * id_cache)
{
  caddr_t ** ret = (caddr_t **)id_hash_get (id_cache, (caddr_t) &ref);

  if (!ret)
    return 0;

  return ret[0];
}

xenc_err_code_t xenc_id_repl_text_get (xenc_enc_key_t * ek, xenc_replace_t * repl,
				       xenc_err_code_t * c, char ** err)
{
  xenc_key_t * key = ek->xeke_encrypted_key;
  dk_session_t * out;
  dk_session_t * in;
  xenc_try_block_t t;
  caddr_t * reference = repl->xr_sel_tag;
  caddr_t * cipherdata = xml_find_child (reference, "CipherData", XENC_NS, 0, 0);
  caddr_t * ciphervalue = cipherdata ? xml_find_child (cipherdata, "CipherValue", XENC_NS, 0, 0) : 0;
  caddr_t val = ciphervalue ? wsse_get_content_val (ciphervalue) : 0;
  xenc_err_code_t cc = 0;

  if (!val)
    {
      cc = XENC_REF_EMPTY_ERR;
      if (c) c[0] = cc;
      if (err) err[0] = box_dv_short_string ("EncryptedData without data");
      return cc;
    }

  in = strses_allocate();
  in->dks_in_buffer = val;
  in->dks_in_fill = box_length (val) - 1;
  in->dks_in_read = 0;

  out = strses_allocate ();

  XENC_TRY (&t)
    {
      (key->xek_enc_algo->xea_dect) (in, in->dks_in_fill, out, key, &t);
    }
  XENC_CATCH
    {
      strses_free (in);
      strses_free (out);
      if (c) c[0] = t.xtb_err_code;
      if (err) err[0] = t.xtb_err_buffer;
      dk_free_box (val);
      return t.xtb_err_code;
    }
  XENC_TRY_END (&t);
  dk_free_box (val);
  in->dks_in_buffer = NULL;
  strses_free (in);
  repl->xr_replace_text = strses_string (out);
  strses_free (out);

  return 0;
}

xenc_err_code_t xenc_enc_key_check (xenc_enc_key_t * ek, xenc_err_code_t * c, char ** err)
{
  xenc_key_t * skey;
  xenc_err_code_t cc = 0;

#if 0
  if (!ek->xeke_super_key)
    {
      cc = XENC_PURE_KEY_ERR;
      if (c) c[0] = cc;
      if (err) err[0] = box_dv_short_string ("not encrypted keys are not allowed");
      return cc;
    }
#endif
  if (!ek->xeke_super_key)
    return 0;
  skey = xenc_get_key_by_name (ek->xeke_super_key, 1);
  if (!skey)
    {
      cc = XENC_UNKNOWN_SUPER_KEY_ERR;
      if (c) c[0] = cc;
      if (err) err[0] = box_dv_short_string (ek->xeke_super_key);
    }
#if 0
  else if (strcmp (skey->xek_algo->xea_ns, ek->xeke_enc_method))
    {
      cc = XENC_DIFF_KEYS_ALGO_ERR;
      if (c) c[0] = cc;
      if (err) err[0] = box_dv_short_string (ek->xeke_super_key);
    }
#endif

  return cc;
}

/* supet_key MUST be known */
xenc_err_code_t xenc_decrypt_key (query_instance_t * qi, caddr_t enc, lang_handler_t * lh,
				  xenc_enc_key_t * enc_key, id_hash_t * id_cache,
				  xenc_err_code_t * c, char ** err)
{
  xenc_key_t * key = 0;
  dk_session_t * in, *out;
  xenc_try_block_t t;
  caddr_t ** encrypteddata = 0;
  char * algo = 0;
  char * id;
  int is_unenc = 0;

  if (enc_key->xeke_super_key)
    key = xenc_get_key_by_name (enc_key->xeke_super_key, 1);
  else
    is_unenc = 1;

  if (id_cache && enc_key->xeke_refs)
    {
      id = (char *) enc_key->xeke_refs->data;
      encrypteddata = (caddr_t **) id_hash_get (id_cache, (caddr_t) &id);
      if (encrypteddata)
	{
	  caddr_t * encmethod = xml_find_child (encrypteddata[0], "EncryptionMethod", XENC_NS, 0, 0);
	  if (encmethod)
	    algo = xml_find_attribute (encmethod, "Algorithm", 0);
	}
    }
  if (!algo)
    {
      char err_str[500 + 200];
      xenc_err_code_t cc = XENC_ALGO_ERR;
      snprintf (err_str, sizeof (err_str), "Could not obtain algorithm for key [ref %s]", id);
      if (c) c[0] = cc;
      if (err) err[0] = box_dv_short_string (err_str);
      return cc;
    }

  if (is_unenc || enc_key->xeke_is_raw) /* no super key */
    {
      if (!enc_key->xeke_name)
	{
	  if (c) c[0] = XENC_UNKNOWN_KEY_ERR;
	  if (err) err[0] = box_dv_short_string ("NULL");
	  return XENC_UNKNOWN_KEY_ERR;
	}
      enc_key->xeke_encrypted_key = xenc_get_key_by_name (enc_key->xeke_name, 1);
      if (!enc_key->xeke_encrypted_key)
	{
	  if (c) c[0] = XENC_UNKNOWN_KEY_ERR;
	  if (err) err[0] = box_dv_short_string (enc_key->xeke_name);
	  return XENC_UNKNOWN_KEY_ERR;
	}
      if (0 != strcmp (enc_key->xeke_encrypted_key->xek_enc_algo->xea_ns,algo))
	{
	  if (c) c[0] = XENC_DIFF_KEYS_ALGO_ERR;
	  if (err) err[0] = box_dv_short_string (enc_key->xeke_name);
	  return XENC_DIFF_KEYS_ALGO_ERR;
	}
      return 0;
    }
  if (!key)
    GPF_T;

  in = strses_allocate();
  in->dks_in_buffer = enc_key->xeke_cipher_value;
  /* cipher is always base64 encoded string */
  in->dks_in_fill = box_length (enc_key->xeke_cipher_value) - 1;
  in->dks_in_read = 0;

  out = strses_allocate();

  XENC_TRY (&t)
    {
      ( key->xek_enc_algo->xea_dect ) (in, in->dks_in_fill, out, key, &t);
      enc_key->xeke_encrypted_key = xenc_build_encrypted_key (enc_key->xeke_carried_key_name, out, algo, &t);
    }
  XENC_CATCH
    {
      in->dks_in_buffer = NULL;
      strses_free (in);
      strses_free (out);
      if (c) c[0] = t.xtb_err_code;
      if (err) err[0] = t.xtb_err_buffer;
      return t.xtb_err_code;
    }
  XENC_TRY_END (&t);
  strses_free (out);
  return 0;
}

void xenc_repls_free (dk_set_t repls)
{
  DO_SET (xenc_replace_t *, repl, &repls)
    {
      dk_free_box (repl->xr_replace_text);
      dk_free (repl, sizeof (xenc_replace_t));
    }
  END_DO_SET();
  dk_set_free (repls);
}

void xenc_build_ids_hash (caddr_t * curr, id_hash_t ** id_hash, int only_encrypted_data)
{
  int inx;
  if (DV_TYPE_OF (curr) != DV_ARRAY_OF_POINTER)
    return;

  if (!only_encrypted_data || !strcmp ((((caddr_t **)(curr))[0][0]), XENC_URI ":EncryptedData"))
    {
      char * Id = xml_find_attribute (curr, "Id", 0);
      if (!Id)
	Id = xml_find_attribute (curr, "id", 0);
      if (Id)
	{
	  char idbuf[128];
	  if (!id_hash[0])
	    id_hash[0] = id_hash_allocate (31, sizeof (caddr_t), sizeof (caddr_t*),
					strhash, strhashcmp);

	  if (id_hash_get (id_hash[0], (caddr_t) & Id))
	    return;

	  memset (idbuf, 0, 128);
	  idbuf[0] = '#';
	  strncpy (&idbuf[1], Id, 128 - 2);

	  Id = box_dv_short_string (idbuf);
	  id_hash_set (id_hash[0], (caddr_t) &Id, (caddr_t) &curr);
	}
    }

  DO_BOX (caddr_t*,child, inx, curr)
    {
      if (inx)
	{
	  xenc_build_ids_hash (child, id_hash, only_encrypted_data);
	}
    }
  END_DO_BOX;
}

void xenc_ids_hash_free (id_hash_t * ids)
{
  id_hash_iterator_t hit;
  char ** id;
  caddr_t ** curr;

  for (id_hash_iterator (&hit, ids);
       hit_next (&hit, (char**)&id, (char**)&curr);
       /* */)
    {
      if (id)
	dk_free_box (id[0]);
    }
  id_hash_free (ids);
}

xenc_err_code_t xenc_decrypt_xml (query_instance_t * qi, xenc_dec_t * enc,
				  caddr_t in_xml, caddr_t encode, lang_handler_t * lh,
				  dk_session_t * out_xml, xenc_err_code_t * c, char ** err)
{
  id_hash_t * nss = 0;
  xml_tree_ent_t * doc;
  xenc_err_code_t cc = 0;
  id_hash_t * id_cache = 0;
  dk_set_t repls = 0;
  xml_doc_subst_t * xs;
  caddr_t ret_text = 0;
  subst_item_t * subst_items= 0;
  DO_SET (xenc_enc_key_t *, enc_key, &enc->xed_keys)
    {
      if ((cc=xenc_enc_key_check (enc_key, c, err)))
	return cc;
    }
  END_DO_SET ();

  /* remember that in_xml MUST be valid, since if error occurs then
     memory leak will occur
  */
  doc = (xml_tree_ent_t *) xml_make_tree_with_ns (qi, in_xml, err, encode, lh, &nss, 0);
  if (!doc)
    GPF_T1 ("Corrupted XML text");

  xenc_build_ids_hash (doc->xte_current, &id_cache, 1);

  DO_SET (xenc_enc_key_t *, enc_key, &enc->xed_keys)
    {
      if ((cc=xenc_decrypt_key (qi, encode, lh, enc_key, id_cache, c, err)))
	goto failed;
      DO_SET (xenc_reference_t, ref, &enc_key->xeke_refs)
	{
	  NEW_VARZ (xenc_replace_t, repl);

	  dk_set_push (&repls, repl);

	  repl->xr_id = ref;
	  repl->xr_sel_tag = xenc_sel_tree_get (doc->xte_current, ref, id_cache);
	  if (!repl->xr_sel_tag)
	    {
	      cc = XENC_UNKNOWN_ID_ERR;
	      if (c) c[0] = cc;
	      if (err) err[0] = box_dv_short_string (ref);
	      goto failed;
	    }
	  if ((cc=xenc_id_repl_text_get (enc_key, repl, c, err)))
	    goto failed;
	}
      END_DO_SET();
    }
  END_DO_SET();

  if (repls)
    {
      int inx = 0;
      subst_items = (subst_item_t *) dk_alloc_box (
	  sizeof (subst_item_t) * dk_set_length (repls), DV_ARRAY_OF_POINTER);

      DO_SET (xenc_replace_t *, repl, &repls)
	{
	  subst_items[inx].orig = repl->xr_sel_tag;
	  subst_items[inx].copy = (caddr_t *) repl->xr_replace_text;
	  subst_items[inx].type = XENCTypeElementIdx;
	  inx++;
	}
      END_DO_SET();
    }

  xs = (xml_doc_subst_t *) dk_alloc (sizeof (xml_doc_subst_t));
  memset (xs, 0, sizeof (xml_doc_subst_t));

  xs->xs_doc = doc;
  xs->xs_subst_items = subst_items;
  xs->xs_soap_version = 0;
  xs->xs_sign = 0;
  xs->xs_namespaces = nss;

  xs->xs_envelope = 0;
  xs->xs_new_child_tags = 0;

  ret_text = xml_doc_subst (xs);

  xml_doc_subst_free(xs);

  CATCH_WRITE_FAIL (out_xml)
    {
      session_buffered_write (out_xml, ret_text, box_length (ret_text) - 1);
    }
  FAILED
    {
      cc = XENC_WRITE_ERR;
      if (c) c[0] = cc;
      if (err) err[0] = box_dv_short_string ("in xenc_decrypt_xml internal error");
      goto failed;
    }
  END_WRITE_FAIL (out_xml);

 failed:
  if (id_cache)
    xenc_ids_hash_free (id_cache);
  dk_free_box (ret_text);
  dk_free_box ((box_t) doc);
  nss_free (nss);
  if (repls) xenc_repls_free (repls);
  if (subst_items)
    dk_free_box ((box_t) subst_items);
  return cc;
}


/* XML Signature impl. */

/*
  pre: dsig must filled with all (dsr_digest)s, dss_signature
  post: returns SignedInfo tag
*/
caddr_t * signature_serialize_1 (dsig_signature_t * dsig, wsse_ser_ctx_t * sctx);
/*
  pre: dsig is valid but computable field are empty (dsr_digest, dss_signature),
	xml text in xml_doc,
	out_tag is not null
  post: if ok - out_tag[0] = Signaturetag,
	else returns error code, code & err are filled if they are not null
*/
xenc_err_code_t dsig_signature_serialize (query_instance_t * qi, dsig_signature_t * dsig,
	 dk_session_t * xml_doc, long xml_ses_len,  caddr_t ** out_tag, xenc_err_code_t * code, char ** err,
	 wsse_ser_ctx_t * sctx)
{
  xenc_err_code_t c;

  if (!(c=dsig_initialize (qi, xml_doc, xml_ses_len, dsig, code, err)))
    {
      out_tag[0] = signature_serialize_1 (dsig, sctx);
    }

  return c;
}

caddr_t * dsig_ref_tag_create (dsig_reference_t * ref)
{
  xenc_tag_t * ref_tag = xenc_tag_create (DSIG_NS, ":Reference");
  xenc_tag_t * digest_tag = xenc_tag_create (DSIG_NS, ":DigestMethod");
  xenc_tag_t * digestval_tag = xenc_tag_create (DSIG_NS, ":DigestValue");
  xenc_tag_t * transforms_tag = 0;
  caddr_t * ret_tag;

  DO_SET (dsig_transform_t*, tr, &ref->dsr_transforms)
    {
      xenc_tag_t * tr_tag;
      if (!strcmp (tr->dst_name, DSIG_FAKE_URI_TRANSFORM_ALGO))
	continue;
      if (!transforms_tag)
	transforms_tag = xenc_tag_create (DSIG_NS, ":Transforms");

      tr_tag = xenc_tag_create (DSIG_NS, ":Transform");
      xenc_tag_add_att (tr_tag, "Algorithm", tr->dst_name);
      xenc_tag_add_child (transforms_tag, xenc_tag_finalize (tr_tag));
      xenc_tag_free (tr_tag);
    }
  END_DO_SET();

  if (transforms_tag)
    {
      xenc_tag_add_child (ref_tag, xenc_tag_finalize (transforms_tag));
      xenc_tag_free (transforms_tag);
    }

  if (ref->dsr_uri && ref->dsr_uri[0])
    xenc_tag_add_att (ref_tag, "URI", ref->dsr_uri);

  xenc_tag_add_att (digest_tag, "Algorithm", ref->dsr_digest_method);
  xenc_tag_add_child (ref_tag, xenc_tag_finalize (digest_tag));
  xenc_tag_free (digest_tag);

  xenc_tag_add_child (digestval_tag, (caddr_t *) box_dv_short_string (ref->dsr_digest));
  xenc_tag_add_child (ref_tag, xenc_tag_finalize (digestval_tag));
  xenc_tag_free (digestval_tag);

  ret_tag = xenc_tag_finalize (ref_tag);
  xenc_tag_free (ref_tag);

  return ret_tag;
}

caddr_t * dsig_signinfo_tag_create (dsig_signature_t * dsig)
{
  xenc_tag_t * signinfo_tag = xenc_tag_create (DSIG_NS, ":SignedInfo");
  xenc_tag_t * canon_tag = xenc_tag_create (DSIG_NS, ":CanonicalizationMethod");
  xenc_tag_t * sign_tag = xenc_tag_create (DSIG_NS, ":SignatureMethod");
  caddr_t * ret_tag;

  xenc_tag_add_att (canon_tag, "Algorithm", dsig->dss_canon_method);
  xenc_tag_add_att (sign_tag, "Algorithm", dsig->dss_signature_method);

  xenc_tag_add_child (signinfo_tag, xenc_tag_finalize (canon_tag));
  xenc_tag_free (canon_tag);
  xenc_tag_add_child (signinfo_tag, xenc_tag_finalize (sign_tag));
  xenc_tag_free (sign_tag);

  DO_SET (dsig_reference_t*, ref, &dsig->dss_refs)
    {
      xenc_tag_add_child (signinfo_tag, dsig_ref_tag_create (ref));
    }
  END_DO_SET();

  ret_tag = xenc_tag_finalize (signinfo_tag);
  xenc_tag_free (signinfo_tag);

  return ret_tag;
}

caddr_t * dsig_signval_tag (dsig_signature_t * dsig)
{
  xenc_tag_t * tag = xenc_tag_create (DSIG_NS, ":SignatureValue");
  caddr_t * ret_tag;

  caddr_t val = dsig->dss_signature_1 ? dsig->dss_signature_1 : box_dv_short_string (dsig->dss_signature);
  xenc_tag_add_child (tag, (caddr_t*) val);
  ret_tag = xenc_tag_finalize (tag);
  xenc_tag_free (tag);
  return ret_tag;
}

void dsig_generate_signedinfo (query_instance_t * qst, dsig_signature_t * dsig,
			       dk_session_t * ses, xenc_try_block_t * t)
{
  caddr_t * signinfo_tree = dsig_signinfo_tag_create(dsig);
  xml_doc_subst_t * xs;
  caddr_t ret_text;
  xml_tree_ent_t *xte = xte_from_tree ((caddr_t) signinfo_tree, (query_instance_t*) qst);
  xte->xe_doc.xd->xd_uri = 0;
  xte->xe_doc.xd->xd_dtd = 0;
  xte->xe_doc.xd->xd_id_dict = 0;
  xte->xe_doc.xd->xd_id_scan = 0;

  xs = (xml_doc_subst_t *) dk_alloc (sizeof (xml_doc_subst_t));
  memset (xs, 0, sizeof (xml_doc_subst_t));

  xs->xs_doc = xte;

  ret_text = xml_doc_subst (xs);

#ifdef DEBUG
  printf ("\n%s\n", ret_text);
  fflush (stdout);
#endif

  xml_doc_subst_free(xs);

  CATCH_WRITE_FAIL (ses)
    {
      session_buffered_write (ses, ret_text, box_length (ret_text) - 1);
    }
  FAILED
    {
      dk_free_box (ret_text);
      SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_XENC_ERR_CODE, (void*) XENC_WRITE_ERR);
      SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_XENC_ERR_BUFFER, box_dv_short_string ("SignInfo"));
      XENC_SIGNAL_FATAL (t);
    }
  END_WRITE_FAIL (ses);

  dk_free_box (ret_text);
}

caddr_t * signature_serialize_1 (dsig_signature_t * dsig, wsse_ser_ctx_t * sctx)
{
  xenc_tag_t * sign_tag = xenc_tag_create(DSIG_NS, ":Signature");
  caddr_t * signinfo_tag = dsig_signinfo_tag_create(dsig);
  caddr_t * signval_tag = dsig_signval_tag(dsig);
  caddr_t * ret_tag;

  xenc_tag_add_child (sign_tag, signinfo_tag);
  xenc_tag_add_child (sign_tag, signval_tag);
  if (dsig->dss_key)
    xenc_tag_add_child (sign_tag, xenc_generate_key_tag (dsig->dss_key, DSIG_SER_EXT_V, 0, 0 /* no KI */, sctx, dsig->dss_key_value_type));

  ret_tag = xenc_tag_finalize (sign_tag);
  xenc_tag_free (sign_tag);

  return ret_tag;
}

dsig_signature_t * dsig_template_1 ()
{
  NEW_VAR (dsig_signature_t, dsig);
  NEW_VAR (dsig_transform_t, tr);
  NEW_VARZ (dsig_reference_t, ref);

  memset (dsig, 0, sizeof (dsig_signature_t));

  tr->dst_name = box_dv_short_string ("http://localhost#str");
  tr->dst_data = NULL;

  dk_set_push (&ref->dsr_transforms, (void*) tr);
  ref->dsr_digest_method = box_dv_short_string (DSIG_SHA1_ALGO);
  ref->dsr_text = 0;
  ref->dsr_digest = 0;

  dsig->dss_canon_method = box_dv_short_string (XML_CANON_EXC_ALGO);
  dsig->dss_signature_method = box_dv_short_string (DSIG_RSA_SHA1_ALGO);
  dsig->dss_signature = 0;
  dk_set_push (&dsig->dss_refs, (void*) ref);
  return dsig;
}

dsig_signature_t * dsig_template_xpath(char * signature_method, char * xpath_sel)
{
  NEW_VAR (dsig_signature_t, dsig);
  NEW_VAR (dsig_transform_t, tr);
  NEW_VARZ (dsig_reference_t, ref);

  memset (dsig, 0, sizeof (dsig_signature_t));

  tr->dst_name = box_dv_short_string (DSIG_XPATH_TRANSFORM_NS);
  tr->dst_data = box_dv_short_string (xpath_sel);

  dk_set_push (&ref->dsr_transforms, (void*) tr);
  ref->dsr_digest_method = box_dv_short_string (DSIG_SHA1_ALGO);
  ref->dsr_text = 0;
  ref->dsr_digest = 0;

  dsig->dss_canon_method = box_dv_short_string (XML_CANON_EXC_ALGO);
  dsig->dss_signature_method = box_dv_short_string (signature_method);
  dsig->dss_signature = 0;
  dk_set_push (&dsig->dss_refs, (void*) ref);
  return dsig;
}


xenc_err_code_t dsig_initialize (query_instance_t * qi, dk_session_t* xml_doc, long xml_ses_len,
				 dsig_signature_t * dsig, xenc_err_code_t * c, char** err)
{
  dk_session_t * xml_ses = 0;
  dk_session_t * xml_doc_out = 0;
  dk_session_t * xml_doc_canon_out = 0;
  caddr_t canon_text_output = 0;
  dsig_canon_f canon_f;
  dsig_verify_f verify_f;
  xenc_err_code_t ccode = 0;
  xenc_try_block_t t;

  xml_ses = strses_allocate ();
  xml_doc_out = strses_allocate ();
  xml_doc_canon_out = strses_allocate ();

  XENC_TRY(&t)
    {
      canon_f = dsig_canon_f_get (dsig->dss_canon_method, &t);
      verify_f = dsig_verify_f_get (dsig->dss_signature_method, &t);

      (canon_f) (xml_doc, xml_ses_len, xml_doc_canon_out);
      canon_text_output = strses_string (xml_doc_canon_out);

      DO_SET (dsig_reference_t *, ref, &dsig->dss_refs)
	{
	  dsig_digest_f digest_f = dsig_digest_f_get (ref->dsr_digest_method, &t);
	  dk_session_t * ses_in, *ses_out;
	  caddr_t transform_data = 0;

	  strses_flush (xml_doc_out);
	  session_buffered_write (xml_doc_out, canon_text_output, box_length (canon_text_output) - 1);
	  /*
	  xml_doc_out->dks_in_buffer = canon_text_output;
	  xml_doc_out->dks_in_fill = box_length (canon_text_output) - 1;
	  xml_doc_out->dks_in_read = 0;*/

	  ses_in = xml_doc_out;
	  ses_out = xml_ses;

	  DO_SET (dsig_transform_t *, tr, &ref->dsr_transforms)
	    {
	      dsig_transform_f tr_func = dsig_transform_f_get (tr->dst_name, &t);
	      dk_session_t * ses;

	      strses_flush (ses_out);

	      if (tr->dst_data) /* URI */
		transform_data = tr->dst_data;
	      if (!tr->dst_data)
		tr->dst_data = box_copy (transform_data);

	      if (!(tr_func)(qi, ses_in, strses_length (ses_in)
		             /*ses_in->dks_in_fill - ses_in->dks_in_read +
			     ses_in->dks_out_fill - ses_in->dks_out_written*/,
			     ses_out, tr->dst_data))
		{
		  if (IS_STRING_DTP (DV_TYPE_OF (tr->dst_data)))
		    {
		      xenc_report_error (&t, 500 + strlen (tr->dst_name),
				     XENC_ALGO_ERR, "Transform error at %s [%s]",
				     tr->dst_name, tr->dst_data);
		    }
		  else
		      xenc_report_error (&t, 500 + strlen (tr->dst_name),
				     XENC_ALGO_ERR, "Transform error at %s",
				     tr->dst_name);
		}
	      ses = ses_out;
	      ses_out = ses_in;
	      ses_in = ses;
	    }
	  END_DO_SET();



	  if (!(digest_f) (xml_doc_out, strses_length (xml_doc_out), &ref->dsr_digest))
	    xenc_report_error (&t, 500 + strlen (ref->dsr_digest_method),
			       XENC_ALGO_ERR, "Digest error at %s",
			       ref->dsr_digest_method);
	}
      END_DO_SET();

      strses_flush (xml_ses);
      strses_flush (xml_doc_out);
      strses_flush (xml_doc_canon_out);
    }
  XENC_CATCH
    {
      ccode = t.xtb_err_code;
      goto failed_or_ret;
    }
  XENC_TRY_END(&t);

 failed_or_ret:
  strses_free (xml_ses);
  /*xml_doc_out->dks_in_buffer = NULL;*/
  strses_free (xml_doc_out);
  strses_free (xml_doc_canon_out);
  dk_free_box (canon_text_output);

 if (c)
    {
      c[0] = t.xtb_err_code;
      err[0] = t.xtb_err_buffer;
    }
  else
    dk_free_box (t.xtb_err_buffer);

  return ccode;
}

int base64_strcmp (char * _s1, char * _s2)
{
  char * s1 = box_dv_short_string (_s1);
  char * s2 = box_dv_short_string (_s2);
  int l1 = xenc_decode_base64 (s1, s1 + box_length (s1));
  int l2 = xenc_decode_base64 (s2, s2 + box_length (s2));
  int res = l1 - l2;

  if (!res)
    res = memcmp (s1,s2,l1);

  dk_free_box (s1);
  dk_free_box (s2);

  return res;
}

/* pre: d1 & d2 are valid initialized objects with equal algos
   post: cmp will be initialized by static string for object name and reference
	to string in d1.
   returns: 0 if eq.

   exceptions: no
*/
int dsig_compare (dsig_signature_t * d1, dsig_signature_t * d2, dsig_compare_t * cmp)
{
  /* signatures are used to check signature validness */
#if 0
  if (strcmp (d1->dss_signature, d2->dss_signature))
    {
      cmp->dsc_obj = "SignatureValue";
      cmp->dsc_value = d1->dss_signature;
      return 1;
    }
#endif
  dk_set_t d1refs = d1->dss_refs;
  dk_set_t d2refs = d2->dss_refs;
  dsig_reference_t * d1ref;
  dsig_reference_t * d2ref;
  if (!d2refs && !d1refs)
    return 0;
  if (!d2refs || !d1refs)
    {
      dk_set_t set = d1refs ? d1refs : d2refs;
      char * digest = ((dsig_reference_t*)set->data)->dsr_digest;
      cmp->dsc_obj = "Digest";
      cmp->dsc_value1 = digest;
      cmp->dsc_value2 = 0;
      return 1;
    }

  d1ref = (dsig_reference_t*) d1refs->data;
  d2ref = (dsig_reference_t*) d2refs->data;

  if (dk_set_length (d1refs) != dk_set_length (d2refs))
    {
      cmp->dsc_obj = "Digest";
      cmp->dsc_value1 = d1ref->dsr_digest;
      cmp->dsc_value2 = 0;
      return 1;
    }

  while (1)
    {
      if (base64_strcmp (d1ref->dsr_digest, d2ref->dsr_digest))
	{
	  cmp->dsc_obj = "Digest";
	  cmp->dsc_value1 = d1ref->dsr_digest;
	  cmp->dsc_value2 = d2ref->dsr_digest;
	  return 1;
	}
      d1refs = d1refs->next;
      d2refs = d2refs->next;

      if (!d1refs)
	return 0;

      d1ref = (dsig_reference_t*) d1refs->data;
      d2ref = (dsig_reference_t*) d2refs->data;
    }
}

dsig_signature_t * dsig_copy_draft (dsig_signature_t * d1)
{
  NEW_VARZ(dsig_signature_t, new_d);

  new_d->dss_canon_method = box_copy (d1->dss_canon_method);
  new_d->dss_signature_method = box_copy (d1->dss_signature_method);

  DO_SET (dsig_reference_t*, ref, &d1->dss_refs)
    {
      NEW_VARZ (dsig_reference_t, new_r);
      DO_SET (dsig_transform_t* , tr, &ref->dsr_transforms)
	{
	  NEW_VARZ (dsig_transform_t, new_tr);
	  new_tr->dst_name = box_copy (tr->dst_name);
	  new_tr->dst_data = box_copy (tr->dst_data);
	  dk_set_push (&new_r->dsr_transforms, new_tr);
	}
      END_DO_SET();
      if (new_r->dsr_transforms)
	new_r->dsr_transforms = dk_set_nreverse (new_r->dsr_transforms);
      new_r->dsr_digest_method = box_copy (ref->dsr_digest_method);
      dk_set_push (&new_d->dss_refs, new_r);
    }
  END_DO_SET();

  if (new_d->dss_refs)
    new_d->dss_refs = dk_set_nreverse (new_d->dss_refs);

  return new_d;
}

void dsig_free (dsig_signature_t * d)
{
  dk_free_box (d->dss_canon_method);
  dk_free_box (d->dss_signature_method);
  dk_free_box (d->dss_signature);
  dk_free_box (d->dss_signature_1);
  DO_SET (dsig_reference_t*, r, &d->dss_refs)
    {
      dk_free_box (r->dsr_text);
      dk_free_box (r->dsr_digest_method);
      dk_free_box (r->dsr_uri);
      dk_free_box (r->dsr_type);
      dk_free_box (r->dsr_id);
      dk_free_box (r->dsr_digest);
      DO_SET (dsig_transform_t *, tr, &r->dsr_transforms)
	{
	  dk_free_box (tr->dst_name);
	  dk_free_box (tr->dst_data);
	  dk_free (tr, sizeof (dsig_transform_t));
	}
      END_DO_SET();
      dk_set_free (r->dsr_transforms);
      dk_free (r, sizeof (dsig_reference_t));
    }
  END_DO_SET();
  dk_set_free (d->dss_refs);
  dk_free (d, sizeof (dsig_signature_t));
}

void xenc_make_error (char * buf,long  maxlen, xenc_err_code_t c, const char * err)
{
  char * buf_ptr = buf;
  int len;
  memset (buf, 0, maxlen);
  if (!c || !err)
    {
      strncpy (buf, "Unknown error", maxlen);
      return;
    }
  if (c)
    snprintf (buf_ptr, maxlen, "[%ld] ", c);

  len = strlen (buf_ptr);

  buf_ptr += len;
  strncpy (buf_ptr, err, maxlen - len - 1);
  return;
}

void xenc_report_error (xenc_try_block_t * t, long buflen, xenc_err_code_t c, char * errbuf, ...)
{
  if (t)
    {
      int res;
      va_list tail;
      char * tmphead;

      tmphead = (char *) dk_alloc (buflen);

      va_start (tail, errbuf);
      res = vsnprintf (tmphead, buflen, errbuf, tail);
      if (res > buflen)
	GPF_T1("Not enough buffer length for writing");
      va_end (tail);

      t->xtb_err_code = c;
      t->xtb_err_buffer = box_dv_short_string (tmphead);
      dk_free (tmphead, buflen);
      XENC_SIGNAL_FATAL (t);
    }
}

#ifdef DEBUG
/* tests */

#include "xmlenc_test.h"

caddr_t bif_dsig_a_test (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t * dsig_tag;
  wsse_ser_ctx_t sctx;
  NEW_VAR (dsig_signature_t, dsig);
  NEW_VAR (dsig_transform_t, tr);
  NEW_VARZ (dsig_reference_t, ref);
  memset (&sctx, 0, sizeof (wsse_ser_ctx_t));
  memset (dsig, 0, sizeof (dsig_signature_t));

  tr->dst_name = box_dv_short_string ("http://localhost#str");
  tr->dst_data = NULL;

  dk_set_push (&ref->dsr_transforms, (void*) tr);
  ref->dsr_digest_method = box_dv_short_string (DSIG_SHA1_ALGO);
  ref->dsr_text = box_dv_short_string ("Text_sdkdaldadkj213921k3oiu2398424iu2h3i4u239484_last_word");
  ref->dsr_digest = box_dv_short_string ("Digest#1");

  dsig->dss_canon_method = box_dv_short_string (XML_CANON_EXC_ALGO);
  dsig->dss_signature_method = box_dv_short_string (DSIG_RSA_SHA1_ALGO);
  dsig->dss_signature = box_dv_short_string ("Signature_askdjaljalskd12313lkjsdflk_last_word");
  dk_set_push (&dsig->dss_refs, (void*) ref);

  dsig_tag = signature_serialize_1 (dsig, &sctx);

  return (caddr_t) dsig_tag;
}


char * test_xml_text =
"\
<?xml version='1.0'?>\n\
	<root>\n\
		<child1/>\n\
		<child2/>\n\
		<child3>\n\
			hello world!\n\
		</child3>\n\
	</root>\n\
";


caddr_t bif_dsig_b_test (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t * dsig_tag;
  caddr_t xml_text;

  NEW_VAR (dsig_signature_t, dsig);
  NEW_VAR (dsig_transform_t, tr);
  NEW_VARZ (dsig_reference_t, ref);

  memset (dsig, 0, sizeof (dsig_signature_t));

  tr->dst_name = box_dv_short_string ("http://localhost#str");
  tr->dst_data = NULL;

  dk_set_push (&ref->dsr_transforms, (void*) tr);
  ref->dsr_digest_method = box_dv_short_string (DSIG_SHA1_ALGO);
  ref->dsr_text = 0;
  ref->dsr_digest = 0;

  dsig->dss_canon_method = box_dv_short_string (XML_CANON_EXC_ALGO);
  dsig->dss_signature_method = box_dv_short_string (DSIG_RSA_SHA1_ALGO);
  dsig->dss_signature = 0;
  dk_set_push (&dsig->dss_refs, (void*) ref);

  xml_text = box_dv_short_string (test_xml_text);

  {
    char * err;
    xenc_err_code_t c;
    wsse_ser_ctx_t sctx;
    dk_session_t * xml_doc = strses_allocate ();
    memset (&sctx, 0, sizeof (wsse_ser_ctx_t));

    xml_doc->dks_in_buffer = xml_text;
    xml_doc->dks_in_fill = box_length (xml_text);
    xml_doc->dks_in_read = 0;

    if (dsig_signature_serialize ((query_instance_t *) qst, dsig, xml_doc, box_length (xml_text), &dsig_tag, &c, &err, &sctx))
      {
	char buf[1024];
	snprintf (buf, sizeof (buf), "failed: %ld, err = %s", c, err);
	return box_dv_short_string (buf);
      }

    return (caddr_t) dsig_tag;
  }
}

/* xenc_test_begin(); */

void xenc_test_a();
void xmlenc_test_wsse_error ();
void xmlenc_check_ecm_arrays ();
void dsig_tr_enveloped_signature_test (query_instance_t * qi);
void dsig_sha1_digest_test();
void dsig_dha1_digest_test();
void dsig_dsa_sha1_sign_test();
void xenc_I2OSP_test();
void xenc_alloc_cbc_box_test ();
void xenc_aes_enctest();
void xenc_kt_test ();
void dsig_rsa_sha1_sign_test();

void xmlenc_base64_test()
{
  char buf0[] = "The Importers are used by the proxy generator of ASP.NET, which is used by Visual Studio .NET and the wsdl.exe command-line tool. The Importers will pick up any known <<format extensions>> that exist in the WSDL file and will turn them into client side SOAP extension attributes in the proxy. The Importers will also inspect the WSDL file for the relevant WS-Security headers and will remove the automatically handled and created SoapHeaders on the client side from the generated proxy, because the client-side proxy will handle these headers internally.";
    char buf1[] = "The Importers are used by the proxy generator of ASP.NET";
    char buf1_enc[] = "VGhlIEltcG9ydGVycyBhcmUgdXNlZCBieSB0aGUgcHJveHkgZ2VuZXJhdG9yIG9mIEFTUC5ORVQ=";

    char * buf = buf0;

  xenc_try_block_t t;
  dk_session_t * ses_out = strses_allocate ();
  dk_session_t * ses_in = strses_allocate ();
  ses_in->dks_in_buffer = buf;
  ses_in->dks_in_fill = strlen (buf);
  ses_in->dks_in_read = 0;

  XENC_TRY (&t)
    {
      xenc_base64_encryptor (ses_in, strlen (buf) , ses_out, xenc_get_key_by_name ("virtdev@localhost",1), &t);
      strses_flush (ses_in);
      xenc_base64_decryptor (ses_out, strses_length (ses_out), ses_in,
			     xenc_get_key_by_name ("virtdev@localhost",1), &t);
    }
  XENC_CATCH
    {
      xenc_assert (0);
      dk_free_box (t.xtb_err_buffer);
      return;
    }
  XENC_TRY_END (&t);
  {
    char * ses_in_str = strses_string (ses_in);
    if (strcmp (ses_in_str, buf))
      {
	xenc_assert (0); /* increments count of failed tests */
	rep_printf ("enc/dec pair failed. orig:\n%s\nres:\n%s\n", strses_string (ses_in), buf);
      }
    dk_free_box (ses_in_str);
  }

  strses_flush (ses_in);
  strses_flush (ses_out);
  buf = buf1;
  ses_in->dks_in_buffer = buf;
  ses_in->dks_in_fill = strlen (buf);
  ses_in->dks_in_read = 0;

  XENC_TRY (&t)
    {
      xenc_base64_encryptor (ses_in, strlen (buf), ses_out, xenc_get_key_by_name ("virtdev@localhost",1), &t);
    }
  XENC_CATCH
    {
      xenc_assert (0);
      dk_free_box (t.xtb_err_buffer);
      return;
    }
  XENC_TRY_END (&t);

  {
    char * ses_out_str = strses_string (ses_out);
    if (strcmp (ses_out_str, buf1_enc))
      {
	xenc_assert (0); /* increments count of failed tests */
	rep_printf ("enc failed. orig:\n%s\nres:\n%s\n", strses_string (ses_out), buf1_enc);
      }
    dk_free_box (ses_out_str);
  }

  return;
}

void xmlenc_des3_test()
{
  xenc_try_block_t t;
  char inbuf[] = "The Importers are used by the proxy generator of ASP.NET, which is used by Visual Studio .NET and the wsdl.exe command-line tool. The Importers will pick up any known <<format extensions>> that exist in the WSDL file and will turn them into client side SOAP extension attributes in the proxy. The Importers will also inspect the WSDL file for the relevant WS-Security headers and will remove the automatically handled and created SoapHeaders on the client side from the generated proxy, because the client-side proxy will handle these headers internally.";
  char buf0[] =
    "\n"
    "<cli:AddInt xmlns:cli=\"http://microsoft.com/wsdk/samples/SumService\" SOAP:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\">\n"
    "<a xsi:type=\"xsd:int\" dt:dt=\"int\">1</a><b xsi:type=\"xsd:int\" dt:dt=\"int\">2</b></cli:AddInt>";
#if 0
  char buf1[] = "The Importers are used by the proxy generator of ASP.NET";
  char buf1_enc[] = {
	0x46, 0x76, 0xbe, 0x1f, 0x42, 0xd6, 0x3a, 0x8d,
	0xac, 0xfc, 0x77, 0xab, 0x0b, 0x93, 0x5c, 0xa5,
	0xd2, 0x85, 0xc9, 0x38, 0x4f, 0x5f, 0xcc, 0xd9,
	0x7b, 0x3f, 0x92, 0x85, 0xef, 0xfa, 0x88, 0xc1,
	0xde, 0xd7, 0xcf, 0x7d, 0x71, 0x59, 0xb8, 0xae,
	0xad, 0x1e, 0xbe, 0xba, 0x55, 0xc2, 0xcb, 0xa0,
	0xc1, 0xf4, 0x93, 0xa7, 0x51, 0xfc, 0x32, 0x52,
	0x5d, 0x3b, 0x2c, 0xc4, 0xe3, 0x11, 0x9a, 0x94, 0};
#endif
  int res;
  char encbuf [] = "MjIyMjIyMjKtkmmDfHYqCt1kQPGRCdZyiQuuEhrYxyBjYh0omdUH5g==";
  /* char inbuf [] = "1234567890  !hello world!"; */
  char * buf = buf0;
  char * res_str;

  dk_session_t * ses_out = strses_allocate ();
  dk_session_t * ses_in = strses_allocate ();
  ses_in->dks_in_buffer = buf;
  ses_in->dks_in_fill = strlen (buf);
  ses_in->dks_in_read = 0;

  /* __xenc_key_3des_init ("virtdev3@localhost", "!sectym!", 1); */

  XENC_TRY (&t)
    {
      xenc_des3_encryptor (ses_in, strlen (buf) , ses_out, xenc_get_key_by_name ("virtdev3@localhost", 1), &t);
      strses_flush (ses_in);

      xenc_des3_decryptor (ses_out, strses_length (ses_out), ses_in,
			     xenc_get_key_by_name ("virtdev3@localhost", 1), &t);
    }
  XENC_CATCH
    {
      xenc_assert (0);
      dk_free_box (t.xtb_err_buffer);
      return;
    }
  XENC_TRY_END (&t);

  res_str = strses_string (ses_in);

  res = strcmp (res_str, buf);
  if (res)
    {
      int c = 0;
      while (c < strlen (buf))
	{
	  if (res_str[c] != buf[c])
	    break;
	  c++;
	}
      xenc_assert (0); /* increments count of failed tests */
      rep_printf ("enc/dec pair failed. %d orig:\n%s\nres:\n%s\n", c, strses_string (ses_in), buf);

    }
  dk_free_box (res_str);

  XENC_TRY (&t)
    {
      unsigned char _key[24] = {
	45,78,244,27,111,132,59,154,7,136,146,112,74,174,98,80,111,207,8,214,237,235,231,247
      };
      unsigned char * key = (unsigned char * )_key;
      strses_flush (ses_out);
      ses_in->dks_in_buffer = inbuf;
      ses_in->dks_in_fill = sizeof (inbuf) - 1;
      ses_in->dks_in_read = 0;

      xenc_key_3des_init (xenc_get_key_by_name ("virtdev3@localhost",1), key, key + 8, key + 16);

      xenc_des3_encryptor (ses_in, ses_in->dks_in_fill, ses_out,
			   xenc_get_key_by_name ("virtdev3@localhost", 1), &t);
      {
	char * str = strses_string (ses_out);
	rep_printf ("dec res =%s\n", str);
	dk_free_box (str);
      }

    }
  XENC_CATCH
    {
      xenc_assert (0);
      dk_free_box (t.xtb_err_buffer);
      return;
    }
  XENC_TRY_END (&t);




#if 0
  __xenc_key_3des_init ("virtdev3@localhost", "!sectym!");

  strses_flush (ses_in);
  strses_flush (ses_out);
  buf = buf1;
  ses_in->dks_in_buffer = buf;
  ses_in->dks_in_fill = strlen (buf);
  ses_in->dks_in_read = 0;

  XENC_TRY (&t)
    {
      xenc_des3_encryptor (ses_in, strlen (buf), ses_out, xenc_get_key_by_name ("virtdev3@localhost",1), &t);
    }
  XENC_CATCH
    {
      xenc_assert (0);
      dk_free_box (t.xtb_err_buffer);
      return;
    }
  XENC_TRY_END (&t);

  res =strcmp (strses_string (ses_out), buf1_enc);
  if (res)
    {
      xenc_assert (0); /* increments count of failed tests */
      rep_printf ("enc failed. %d orig:\n%s\nres:\n%s\n",res, strses_string (ses_out), buf1_enc);
    }
#endif

  return;
}

void xmlenc_rsa_test()
{
  xenc_try_block_t t;
  char buf0[] = "The Importers are used by the proxy generator of ASP.NET, which is used by Visual Studio .NET and the wsdl.exe command-line tool. The Importers will pick up any known <<format extensions>> that exist in the WSDL file and will turn them into client side SOAP extension attributes in the proxy. The Importers will also inspect the WSDL file for the relevant WS-Security headers and will remove the automatically handled and created SoapHeaders on the client side from the generated proxy, because the client-side proxy will handle these headers internally.";

  char * buf = buf0;
  int res;

  dk_session_t * ses_out = strses_allocate ();
  dk_session_t * ses_in = strses_allocate ();
  ses_in->dks_in_buffer = buf;
  ses_in->dks_in_fill = strlen (buf);
  ses_in->dks_in_read = 0;

  __xenc_key_rsa_init ("virtdev5@localhost");

  XENC_TRY (&t)
    {
      xenc_rsa_encryptor (ses_in, strlen (buf) , ses_out, xenc_get_key_by_name ("virtdev5@localhost", 1), &t);
      strses_flush (ses_in);

      xenc_rsa_decryptor (ses_out, strses_length (ses_out), ses_in,
			     xenc_get_key_by_name ("virtdev5@localhost", 1), &t);
    }
  XENC_CATCH
    {
      xenc_assert (0);
      dk_free_box (t.xtb_err_buffer);
      return;
    }
  XENC_TRY_END (&t);

  res = strcmp (strses_string (ses_in), buf);
  if (res)
    {
      xenc_assert (0); /* increments count of failed tests */
      rep_printf ("enc/dec pair failed. orig:\n%s\nres:\n%s\n[%d]\n", strses_string (ses_in), buf, res);
    }
  return;
}

caddr_t bif_xenc_test (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  if (!xenc_key_create ("virtdev@localhost", XENC_BASE64_ALGO, XENC_BASE64_ALGO, 1))
    log_info ("Unknown algo or duplicate key, %s", XENC_BASE64_ALGO);

  if (!xenc_key_create ("virtdev2@localhost", XENC_BASE64_ALGO, XENC_BASE64_ALGO, 1))
     log_info ("Unknown algo or duplicate key, %s", XENC_BASE64_ALGO);

  if (!xenc_key_create ("virtdev3@localhost", XENC_TRIPLEDES_ALGO, XENC_TRIPLEDES_ALGO, 1))
    log_info ("Unknown algo or duplicate key, %s", XENC_TRIPLEDES_ALGO);

  if (!xenc_key_create ("virtdev4@localhost", XENC_DSA_ALGO, DSIG_DSA_SHA1_ALGO, 1))
    log_info ("Unknown algo or duplicate key, %s", XENC_DSA_ALGO);
  __xenc_key_dsa_init ("virtdev4@localhost", 1, 512);


  if (!xenc_key_create ("virtdev5@localhost", XENC_RSA_ALGO, DSIG_RSA_SHA1_ALGO, 1))
    log_info ("Unknown algo or duplicate key, %s", XENC_RSA_ALGO);

  if (!xenc_key_create ("virtdev6@localhost", XENC_RSA_ALGO, DSIG_RSA_SHA1_ALGO, 1))
    log_info ("Unknown algo or duplicate key, %s", DSIG_RSA_SHA1_ALGO);

  xenc_test_begin();
  trset_start(qst);

  xenc_test_a();
  xmlenc_test_wsse_error ();
  xmlenc_base64_test();
  xmlenc_des3_test();
  xmlenc_rsa_test();
  xmlenc_check_ecm_arrays ();
  dsig_tr_enveloped_signature_test ((query_instance_t *) qst);
  dsig_sha1_digest_test();

  dsig_dsa_sha1_sign_test();
  dsig_rsa_sha1_sign_test();

  xenc_alloc_cbc_box_test ();
  xenc_aes_enctest();
  xenc_kt_test();

  /*  xenc_I2OSP_test(); */

  trset_end();
  xenc_test_end();
  return NULL;
}

/* encrypts 3DES key by itself, and decrypt it. */
void xenc_kt_test ()
{
  xenc_key_t * key = xenc_key_create ("virtdev_test@localhost", XENC_TRIPLEDES_ALGO, XENC_TRIPLEDES_ALGO, 1);
  xenc_key_t * new_key = 0;
  xenc_try_block_t t;
  dk_session_t *in, *out;
  caddr_t key_data;
  char data[] = "hello world!!!!123456789the end.";

  in = strses_allocate ();
  out = strses_allocate ();

  __xenc_key_3des_init ("virtdev_test@localhost", "!secnum!", 1);

  CATCH_READ_FAIL (in)
    {
      session_buffered_write (in, key->ki.triple_des.k1, 8);
      session_buffered_write (in, key->ki.triple_des.k2, 8);
      session_buffered_write (in, key->ki.triple_des.k3, 8);
    }
  FAILED
    {
      xenc_assert (0);
      goto end;
    }
  END_READ_FAIL (in);

  key_data = strses_string (in);

  XENC_TRY (&t)
    {
      caddr_t key_data_2;
      xenc_des3_encryptor (in, 24, out, key, &t);
      strses_flush (in);

      xenc_des3_decryptor (out, strses_length (out), in, key, &t);
      key_data_2 = strses_string (in);

      if (memcmp (key_data, key_data_2, 3 * sizeof (DES_cblock)))
	xenc_assert (0);
      dk_free_box (key_data_2);
      dk_free_box (key_data);

      new_key = xenc_build_encrypted_key ("virtdev_test_rest", in, XENC_TRIPLEDES_ALGO, &t);

      if (memcmp (new_key->ki.triple_des.k1,
		  key->ki.triple_des.k1, sizeof (DES_cblock)))
	xenc_assert (0);
      if (memcmp (new_key->ki.triple_des.k2,
		  key->ki.triple_des.k2, sizeof (DES_cblock)))
	xenc_assert (0);
      if (memcmp (new_key->ki.triple_des.k3,
		  key->ki.triple_des.k3, sizeof (DES_cblock)))
	xenc_assert (0);

      strses_flush (in);
      strses_flush (out);

      in->dks_in_buffer = data;
      in->dks_in_fill = sizeof (data) - 1;
      in->dks_in_read = 0;

      xenc_des3_encryptor (in, in->dks_in_fill, out, key, &t);
      strses_flush (in);
      xenc_des3_decryptor (out, strses_length (out), in, new_key, &t);

      {
	char * str = strses_string (in);
	if (strcmp (data, str))
	  {
	    xenc_assert (0);
	    rep_printf ("output of xenc_kt_test = ***%s***\n", strses_string(in));
	  }
	dk_free_box (str);
      }
    }
  FAILED
    {
      xenc_assert (0);
      dk_free_box (t.xtb_err_buffer);
      goto end;
    }
  XENC_TRY_END (&t);


 end:
  if (new_key)
    xenc_key_remove (new_key, 1);
  xenc_key_remove (key, 1);
}


static caddr_t
bif_print_KI (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  unsigned char code[] = {0xEA,0xCE,0x53,0x30,0x90,0xF7,0x31,0x48,0x77,0x99,0xBF,0x2A,
			  0xC2,0x1A,0x70,0x17,0x55,0x81,0xEC,0x33,0x00};
  unsigned char base[sizeof (code) * 2 +1];
  int len = xenc_encode_base64 (code, base, sizeof (code) - 1);
  caddr_t ret = dk_alloc_box (len + 1, DV_STRING);
  memcpy (ret, base, len);
  ret[len] = 0;
  return ret;
}
#endif

caddr_t xenc_x509_get_key_identifier (X509 * cert)
{
  ASN1_OCTET_STRING *ikeyid = NULL;
  X509_EXTENSION *ext;
  int i;
  caddr_t ret;
  if (!cert)
    return 0;

  i = X509_get_ext_by_NID(cert, NID_subject_key_identifier, -1);
  if((i >= 0)  && (ext = X509_get_ext(cert, i)))
    ikeyid = (ASN1_OCTET_STRING *) X509V3_EXT_d2i(ext);
  if(!ikeyid)
    {
      EVP_PKEY *pkey = X509_get_pubkey (cert);
      int i, len;
      char md[SHA_DIGEST_LENGTH];
      unsigned char * data, *p;
      SHA_CTX ctx;

      if (!pkey)
	return 0;

      len = i2d_PUBKEY (pkey, NULL);

      if (len < 1)
        return 0;

      data = (unsigned char *) dk_alloc (len + 20);
      p = data;
      i = i2d_PUBKEY (pkey, &p);
      SHA1_Init(&ctx);
      SHA1_Update(&ctx, data, (unsigned long)i);
      SHA1_Final((unsigned char *)md,&ctx);
      ret = dk_alloc_box (SHA_DIGEST_LENGTH, DV_BIN);
      memcpy (ret, md, SHA_DIGEST_LENGTH);
      dk_free (data, len + 20);
      return ret;
    }

  ret = dk_alloc_box (ikeyid->length, DV_BIN);
  memcpy (ret, ikeyid->data, ikeyid->length);
  M_ASN1_OCTET_STRING_free(ikeyid);
  return ret;
}

caddr_t xenc_x509_KI_base64 (X509 * cert)
{
  caddr_t KI = xenc_x509_get_key_identifier (cert);
  if (KI)
    {
      caddr_t encoded = (caddr_t) dk_alloc (box_length (KI)*2 + 1);
      int len;
      caddr_t ret;
      memset (encoded, 0, box_length (KI) * 2 + 1);
      len = xenc_encode_base64 (KI, encoded, box_length (KI));
      ret = dk_alloc_box (len + 1, DV_STRING);
      memcpy (ret, encoded, len);
      ret[len] = 0;
      dk_free (encoded, box_length (KI) * 2 +1);
      dk_free_box (KI);
      return ret;
    }
  return 0;
}

caddr_t
xenc_get_keyname_by_ki (caddr_t keyident)
{
   xenc_key_t * k = xenc_get_key_by_keyidentifier (keyident, 1);

  if (k)
    return box_dv_short_string (k->xek_name);

  return NEW_DB_NULL;
}

static caddr_t
bif_x509_get_subject (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char * name = bif_string_arg (qst, args, 0, "X509_get_subject");
  xenc_key_t * k = xenc_get_key_by_name (name, 1);
  X509 * cert;
  ASN1_OCTET_STRING *ikeyid = NULL;
  X509_EXTENSION *ext;
  int i;
  caddr_t ret;
  if (!k || !k->xek_x509)
    sqlr_new_error ("42000", "XENC23", "could not get certificate %s", name);

  cert = k->xek_x509;

  i = X509_get_ext_by_NID(cert, NID_subject_key_identifier, -1);
  if((i >= 0)  && (ext = X509_get_ext(cert, i)))
    ikeyid = (ASN1_OCTET_STRING *) X509V3_EXT_d2i(ext);
  if(!ikeyid)
    {
      sqlr_new_error ("42000", "XENC24", "could not get subject key identifier for %s certificate", name);
    }

  ret = dk_alloc_box (ikeyid->length, DV_BIN);
  memcpy (ret, ikeyid->data, ikeyid->length);
  M_ASN1_OCTET_STRING_free(ikeyid);
  return ret;
}

static caddr_t
bif_xenc_sha1_digest (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char * text = bif_string_arg (qst, args, 0, "xenc_sha1_digest");
  dk_session_t * ses = strses_allocate ();
  caddr_t res = NULL;
  session_buffered_write (ses, text, box_length (text) - 1);
  dsig_sha1_digest (ses, strses_length (ses), &res);
  dk_free_box (ses);
  return res;
}

#ifdef SHA256_ENABLE
static caddr_t
bif_xenc_sha256_digest (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char * text = bif_string_arg (qst, args, 0, "xenc_sha256_digest");
  dk_session_t * ses = strses_allocate ();
  caddr_t res = NULL;
  session_buffered_write (ses, text, box_length (text) - 1);
  dsig_sha256_digest (ses, strses_length (ses), &res);
  dk_free_box (ses);
  return res;
}

static caddr_t
bif_xenc_hmac_sha256_digest (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char * text = bif_string_arg (qst, args, 0, "xenc_hmac_sha256_digest");
  caddr_t name = bif_string_arg (qst, args, 1, "xenc_hmac_sha256_digest");
  xenc_key_t * key = xenc_get_key_by_name (name, 1);
  dk_session_t * ses = strses_allocate ();
  caddr_t res = NULL;
  int rc = 0;

  SES_PRINT (ses, text);
  rc = dsig_hmac_sha256_digest (ses, strses_length (ses), key, &res);
  dk_free_box (ses);
  if (0 == rc)
    sqlr_new_error ("42000", "XENC36", "Could not make HMAC-SHA256 digest");

  return res;
}
#endif

static caddr_t
bif_xenc_rsa_sha1_digest (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char * me = "xenc_rsa_sha1_digest";
  char * text = bif_string_arg (qst, args, 0, me);
  caddr_t name = bif_string_arg (qst, args, 1, me);
  xenc_key_t * key = xenc_get_key_by_name (name, 1);
  dk_session_t * ses = strses_allocate ();
  caddr_t res = NULL;
  session_buffered_write (ses, text, box_length (text) - 1);
  dsig_rsa_sha1_digest (ses, strses_length (ses), key, &res);
  dk_free_box (ses);
  return res;
}

static caddr_t
bif_xenc_dsig_signature (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char * me = "xenc_dsig_signature";
  caddr_t  text = bif_string_arg (qst, args, 0, me);
  caddr_t name = bif_string_arg (qst, args, 1, me);
  caddr_t signature_method = bif_string_arg (qst, args, 2, me);
  xenc_key_t * key = xenc_get_key_by_name (name, 1);
  dsig_sign_f sign_f = dsig_sign_f_get (signature_method, 0);
  caddr_t signval;
  dk_session_t * ses;
  ses = strses_allocate ();
  session_buffered_write (ses, text, box_length (text) - 1);
  if (!sign_f || !(sign_f) (ses, strses_length(ses), key, &signval))
    signval = NEW_DB_NULL;
  dk_free_box (ses);
  return signval;
}

static caddr_t
bif_xenc_dsig_verify (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char * me = "xenc_dsig_verify";
  caddr_t  text = bif_string_arg (qst, args, 0, me);
  caddr_t name = bif_string_arg (qst, args, 1, me);
  caddr_t signature_method = bif_string_arg (qst, args, 2, me);
  caddr_t signval = bif_string_arg (qst, args, 3, me);
  xenc_key_t * key = xenc_get_key_by_name (name, 1);
  dsig_verify_f verify_f = dsig_verify_f_get (signature_method, 0);
  caddr_t rc;

  dk_session_t * ses;
  ses = strses_allocate ();
  session_buffered_write (ses, text, box_length (text) - 1);
  if (!verify_f || !(verify_f) (ses, strses_length(ses), key, signval))
    rc = box_num (0);
  else
    rc = box_num (1);
  dk_free_box (ses);
  return rc;
}

static caddr_t
bif_xenc_hmac_sha1_digest (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char * text = bif_string_arg (qst, args, 0, "xenc_hmac_sha1_digest");
  caddr_t name = bif_string_arg (qst, args, 1, "xenc_hmac_sha1_digest");
  xenc_key_t * key = xenc_get_key_by_name (name, 1);
  dk_session_t * ses = strses_allocate ();
  caddr_t res = NULL;
  int rc = 0;

  SES_PRINT (ses, text);
  rc = dsig_hmac_sha1_digest (ses, strses_length (ses), key, &res);
  dk_free_box (ses);
  if (0 == rc)
    sqlr_new_error ("42000", "XENC36", "Could not make HMAC-SHA1 digest");

  return res;
}

static int x509_add_ext (X509 *cert, int nid, char *value)
{
  X509_EXTENSION *ex;
  X509V3_CTX ctx;
  X509V3_set_ctx_nodb (&ctx);
  X509V3_set_ctx (&ctx, cert, cert, NULL, NULL, 0);
  ex = X509V3_EXT_conf_nid (NULL, &ctx, nid, value);
  if (!ex)
    return 0;
  X509_add_ext(cert,ex,-1);
  X509_EXTENSION_free(ex);
  return 1;
}

static void
x509_add_custom (X509 * x, ccaddr_t n, ccaddr_t v)
{
  int nid = OBJ_create (n, n, n);
  X509V3_EXT_add_alias (nid, NID_netscape_comment);
  x509_add_ext (x, nid, (char *) v);
}


static caddr_t
bif_xenc_x509_generate (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t key_name = bif_string_arg (qst, args, 0, "xenc_x509_generate");
  caddr_t cli_pub_key = bif_string_arg (qst, args, 1, "xenc_x509_generate");
  long serial = bif_long_arg (qst, args, 2, "xenc_x509_generate");
  long days = bif_long_arg (qst, args, 3, "xenc_x509_generate");
  caddr_t * subj = (caddr_t *) bif_strict_array_or_null_arg (qst, args, 4, "xenc_x509_generate");
  caddr_t * exts = (caddr_t *) bif_strict_array_or_null_arg (qst, args, 5, "xenc_x509_generate");
  float hours = BOX_ELEMENTS (args) > 6 ? (float) bif_float_arg (qst, args, 6, "xenc_x509_generate") : 0;
  caddr_t digest_name = BOX_ELEMENTS (args) > 7 ? bif_string_arg (qst, args, 7, "xenc_x509_generate") : DEFAULT_SHA_DIGEST;
  xenc_key_t * ca_key = xenc_get_key_by_name (key_name, 1);
  xenc_key_t * cli_key = xenc_get_key_by_name (cli_pub_key, 1);
  X509 *x = NULL;
  EVP_PKEY *pk = NULL, *cli_pk = NULL;
  RSA *rsa = NULL;
  DSA *dsa = NULL;
  X509_NAME *name = NULL;
  int i;
  const EVP_MD *digest = EVP_get_digestbyname (digest_name);

  if (!digest)
    sqlr_new_error ("42000", "XECXX", "Cannot find digest %s", digest_name);

  /* check ca cert */
  if (!ca_key || !ca_key->xek_evp_private_key || !ca_key->xek_x509)
    {
      *err_ret = srv_make_new_error ("22023", "XECXX", "Missing or invalid signer certificate");
      goto err;
    }
  if (!cli_key)
    {
      *err_ret = srv_make_new_error ("22023", "XECXX", "Missing public key");
      goto err;
    }
  /* check pub key */
  if (cli_key->xek_type != DSIG_KEY_RSA && cli_key->xek_type != DSIG_KEY_DSA)
    {
      *err_ret = srv_make_new_error ("22023", "XECXX", "Public Key must be DSA or RSA");
      goto err;
    }

  rsa = cli_key->xek_type == DSIG_KEY_RSA ? cli_key->xek_rsa : NULL;
  dsa = cli_key->xek_type == DSIG_KEY_DSA ? cli_key->xek_dsa : NULL;

  if (!rsa && !dsa)
    {
      *err_ret = srv_make_new_error ("22023", "XECXX", "Missing private key");
      goto err;
    }
  /* check params */
  if ((BOX_ELEMENTS (subj) % 2) != 0)
    {
      *err_ret = srv_make_new_error ("22023", "XECXX", "Subject array must be name/value pairs");
      goto err;
    }

  if ((BOX_ELEMENTS (exts) % 2) != 0)
    {
      *err_ret = srv_make_new_error ("22023", "XECXX", "Extension array must be name/value pairs");
      goto err;
    }

  pk = ca_key->xek_evp_private_key;
  cli_pk = cli_key->xek_evp_key;
  if (!cli_pk)
    {
      if ((cli_pk=EVP_PKEY_new()) == NULL)
	{
	  *err_ret = srv_make_new_error ("42000", "XECXX", "Can not create pkey");
	  goto err;
	}

      if (rsa && !EVP_PKEY_assign_RSA (cli_pk,rsa))
	{
	  *err_ret = srv_make_new_error ("42000", "XECXX", "Can not assign primary key");
	  goto err;
	}
      if (dsa && !EVP_PKEY_assign_DSA (cli_pk,dsa))
	{
	  *err_ret = srv_make_new_error ("42000", "XECXX", "Can not assign primary key");
	  goto err;
	}
    }

  if ((x = X509_new()) == NULL)
    {
      *err_ret = srv_make_new_error ("42000", "XECXX", "Can not create x.509 structure");
      goto err;
    }


  X509_set_version (x,2);
  ASN1_INTEGER_set (X509_get_serialNumber (x), serial);
  X509_gmtime_adj (X509_get_notBefore (x), 0);
  X509_gmtime_adj (X509_get_notAfter (x), (long) (((days * 24) + hours) * 60 * 60));
  X509_set_pubkey (x, cli_pk);
  name = X509_get_subject_name(x);

  for (i = 0; i < BOX_ELEMENTS (subj); i += 2)
    {
      if (DV_STRINGP (subj[i]) && DV_STRINGP (subj[i + 1]) && box_length (subj[i + 1]) > 1 &&
	  0 == X509_NAME_add_entry_by_txt (name, subj[i], MBSTRING_ASC, (unsigned char *) subj[i+1], -1, -1, 0))
	{
	  sqlr_warning ("01V01", "QW001", "Unknown name entry %s", subj[i]);
	}
    }

  /* issuer */
  X509_set_issuer_name(x,X509_NAME_dup (X509_get_subject_name (ca_key->xek_x509)));

  /* Add standard extensions */
  x509_add_ext (x, NID_subject_key_identifier, "hash");

  for (i = 0; i < BOX_ELEMENTS (exts); i += 2)
    {
      int nid;
      if (!DV_STRINGP (exts[i]) || !DV_STRINGP (exts[i + 1]) || box_length (exts[i + 1]) < 2)
	continue;
      nid = OBJ_sn2nid (exts[i]);
      if (nid == NID_undef)
	{
	  x509_add_custom (x, exts[i], exts[i+1]);
	  sqlr_warning ("01V01", "QW001", "Unknown extension entry %s", exts[i]);
	  continue;
	}
      x509_add_ext (x, nid, exts[i+1]);
    }

  if (!X509_sign (x, pk, digest))
    {
      pk = NULL; /* keep one in the xenc_key */
      *err_ret = srv_make_new_error ("42000", "XECXX", "Can not sign certificate");
      goto err;
    }
  cli_key->xek_x509 = x;
  cli_key->xek_evp_key = X509_extract_key (x);
  cli_key->xek_x509_KI = xenc_x509_KI_base64 (x);
  if (cli_key->xek_x509_KI)
    xenc_certificates_hash_add (cli_key->xek_x509_KI, cli_key, 0);
  return box_num (1);
err:
  EVP_PKEY_free (pk);
  X509_free (x);
  return 0;
}

static caddr_t
bif_xenc_x509_ss_generate (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t key_name = bif_string_arg (qst, args, 0, "xenc_x509_ss_generate");
  long serial = bif_long_arg (qst, args, 1, "xenc_x509_ss_generate");
  long days = bif_long_arg (qst, args, 2, "xenc_x509_ss_generate");
  caddr_t * subj = (caddr_t *) bif_strict_array_or_null_arg (qst, args, 3, "xenc_x509_ss_generate");
  caddr_t * exts = (caddr_t *) bif_strict_array_or_null_arg (qst, args, 4, "xenc_x509_ss_generate");
  float hours = BOX_ELEMENTS (args) > 5 ? (float) bif_float_arg (qst, args, 5, "xenc_x509_ss_generate") : 0;
  caddr_t digest_name = BOX_ELEMENTS (args) > 6 ? bif_string_arg (qst, args, 6, "xenc_x509_ss_generate") : DEFAULT_SHA_DIGEST;
  xenc_key_t * key = xenc_get_key_by_name (key_name, 1);
  X509 *x = NULL;
  EVP_PKEY *pk = NULL;
  RSA *rsa = NULL;
  DSA *dsa = NULL;
  X509_NAME *name = NULL;
  char buf [512];
  int i;
  const EVP_MD *digest = EVP_get_digestbyname (digest_name);

  if (!digest)
    sqlr_new_error ("42000", "XECXX", "Cannot find digest %s", digest_name);

  if (!key)
    {
      *err_ret = srv_make_new_error ("22023", "XECXX", "Missing key");
      goto err;
    }

  if (key->xek_type != DSIG_KEY_RSA && key->xek_type != DSIG_KEY_DSA)
    {
      *err_ret = srv_make_new_error ("22023", "XECXX", "Key is not DSA nor RSA");
      goto err;
    }

  rsa = key->xek_type == DSIG_KEY_RSA ? key->xek_private_rsa : NULL;
  dsa = key->xek_type == DSIG_KEY_DSA ? key->xek_private_dsa : NULL;

  if (!rsa && !dsa)
    {
      *err_ret = srv_make_new_error ("22023", "XECXX", "Missing private key");
      goto err;
    }

  if (NULL != key->xek_x509)
    {
      *err_ret = srv_make_new_error ("22023", "XECXX", "Certificate is already generated");
      goto err;
    }

  if ((BOX_ELEMENTS (subj) % 2) != 0)
    {
      *err_ret = srv_make_new_error ("22023", "XECXX", "Subject array must be name/value pairs");
      goto err;
    }

  if ((BOX_ELEMENTS (exts) % 2) != 0)
    {
      *err_ret = srv_make_new_error ("22023", "XECXX", "Extension array must be name/value pairs");
      goto err;
    }

  pk = key->xek_evp_private_key;

  if (!pk)
    {
      if ((pk=EVP_PKEY_new()) == NULL)
	{
	  *err_ret = srv_make_new_error ("42000", "XECXX", "Can not create pkey");
	  goto err;
	}

      if (rsa && !EVP_PKEY_assign_RSA (pk,rsa))
	{
	  *err_ret = srv_make_new_error ("42000", "XECXX", "Can not assign primary key");
	  goto err;
	}
      else if (dsa && !EVP_PKEY_assign_DSA (pk,dsa))
	{
	  *err_ret = srv_make_new_error ("42000", "XECXX", "Can not assign primary key");
	  goto err;
	}
      key->xek_evp_private_key = pk;
    }


  if ((x = X509_new()) == NULL)
    {
      *err_ret = srv_make_new_error ("42000", "XECXX", "Can not create x.509 structure");
      goto err;
    }


  X509_set_version (x,2);
  ASN1_INTEGER_set (X509_get_serialNumber (x), serial);
  X509_gmtime_adj (X509_get_notBefore (x), 0);
  X509_gmtime_adj (X509_get_notAfter (x), (long) 60 * 60 * 24 * days);
  X509_set_pubkey (x, pk);
  name = X509_get_subject_name(x);

  for (i = 0; i < BOX_ELEMENTS (subj); i += 2)
    {
      if (DV_STRINGP (subj[i]) && DV_STRINGP (subj[i + 1]) && box_length (subj[i + 1]) > 1 &&
	  0 == X509_NAME_add_entry_by_txt (name, subj[i], MBSTRING_ASC, (unsigned char *) subj[i+1], -1, -1, 0))
	{
	  sqlr_warning ("01V01", "QW001", "Unknown name entry %s", subj[i]);
	}
    }

  /* self signed */
  X509_set_issuer_name(x,name);

  /* Add standard extensions */
  x509_add_ext (x, NID_subject_key_identifier, "hash");

  for (i = 0; i < BOX_ELEMENTS (exts); i += 2)
    {
      int nid;
      if (!DV_STRINGP (exts[i]) || !DV_STRINGP (exts[i + 1]) || box_length (exts[i + 1]) < 2)
	continue;
      nid = OBJ_sn2nid (exts[i]);
      if (nid == NID_undef)
	{
	  x509_add_custom (x, exts[i], exts[i+1]);
	  sqlr_warning ("01V01", "QW001", "Unknown extension entry %s", exts[i]);
	  continue;
	}
      x509_add_ext (x, nid, exts[i+1]);
    }

  if (!X509_sign (x, pk, digest))
    {
      pk = NULL; /* keep one in the xenc_key */
      *err_ret = srv_make_new_error ("42000", "XECXX", "Can not sign certificate : %s", get_ssl_error_text (buf, sizeof (buf)));
      goto err;
    }

  key->xek_x509 = x;
  key->xek_evp_key = X509_extract_key (x);
  key->xek_x509_KI = xenc_x509_KI_base64 (x);
  if (key->xek_x509_KI)
    xenc_certificates_hash_add (key->xek_x509_KI, key, 0);
  return box_num (1);
err:
  EVP_PKEY_free (pk);
  X509_free (x);
  return 0;
}

static caddr_t
bif_xenc_x509_csr_generate (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  static char * me = "xenc_x509_csr_generate";
  caddr_t key_name = bif_string_arg (qst, args, 0, me);
  caddr_t * subj = (caddr_t *) bif_strict_array_or_null_arg (qst, args, 1, me);
  caddr_t * exts = (caddr_t *) bif_strict_array_or_null_arg (qst, args, 2, me);
  xenc_key_t * key = xenc_get_key_by_name (key_name, 1);
  X509_REQ *x = NULL;
  EVP_PKEY *pk = NULL;
  RSA *rsa = NULL;
  DSA *dsa = NULL;
  X509_NAME *name = NULL;
  char buf [512];
  int i;
  BIO * b;
  char *data_ptr;
  int len;
  caddr_t ret = NULL;
  STACK_OF(X509_EXTENSION) *st_exts = NULL;

  if (!key)
    {
      *err_ret = srv_make_new_error ("22023", "XECXX", "Missing key");
      goto err;
    }

  if (key->xek_type != DSIG_KEY_RSA && key->xek_type != DSIG_KEY_DSA)
    {
      *err_ret = srv_make_new_error ("22023", "XECXX", "Key is not DSA nor RSA");
      goto err;
    }

  rsa = key->xek_type == DSIG_KEY_RSA ? key->xek_private_rsa : NULL;
  dsa = key->xek_type == DSIG_KEY_DSA ? key->xek_private_dsa : NULL;

  if (!rsa && !dsa)
    {
      *err_ret = srv_make_new_error ("22023", "XECXX", "Missing private key");
      goto err;
    }

  if ((BOX_ELEMENTS (subj) % 2) != 0)
    {
      *err_ret = srv_make_new_error ("22023", "XECXX", "Subject array must be name/value pairs");
      goto err;
    }

  if ((BOX_ELEMENTS (exts) % 2) != 0)
    {
      *err_ret = srv_make_new_error ("22023", "XECXX", "Extension array must be name/value pairs");
      goto err;
    }

  pk = key->xek_evp_private_key;

  if (!pk)
    {
      if ((pk=EVP_PKEY_new()) == NULL)
	{
	  *err_ret = srv_make_new_error ("42000", "XECXX", "Can not create pkey");
	  goto err;
	}

      if (rsa && !EVP_PKEY_assign_RSA (pk,rsa))
	{
	  *err_ret = srv_make_new_error ("42000", "XECXX", "Can not assign primary key");
	  goto err;
	}
      else if (dsa && !EVP_PKEY_assign_DSA (pk,dsa))
	{
	  *err_ret = srv_make_new_error ("42000", "XECXX", "Can not assign primary key");
	  goto err;
	}
      key->xek_evp_private_key = pk;
    }


  if ((x = X509_REQ_new()) == NULL)
    {
      *err_ret = srv_make_new_error ("42000", "XECXX", "Can not create x.509 structure");
      goto err;
    }


  X509_REQ_set_pubkey (x, pk);
  name = X509_REQ_get_subject_name(x);
  st_exts = sk_X509_EXTENSION_new_null();

  for (i = 0; i < BOX_ELEMENTS (subj); i += 2)
    {
      if (DV_STRINGP (subj[i]) && DV_STRINGP (subj[i + 1]) && box_length (subj[i + 1]) > 1 &&
	  0 == X509_NAME_add_entry_by_txt (name, subj[i], MBSTRING_ASC, (unsigned char *) subj[i+1], -1, -1, 0))
	{
	  sqlr_warning ("01V01", "QW001", "Unknown name entry %s", subj[i]);
	}
    }

  for (i = 0; i < BOX_ELEMENTS (exts); i += 2)
    {
      int nid;
      X509_EXTENSION *ex;
      if (!DV_STRINGP (exts[i]) || !DV_STRINGP (exts[i + 1]) || box_length (exts[i + 1]) < 2)
	continue;
      nid = OBJ_sn2nid (exts[i]);
      if (nid == NID_undef)
	{
	  sqlr_warning ("01V01", "QW001", "Unknown extension entry %s", exts[i]);
	  continue;
	}
      ex = X509V3_EXT_conf_nid(NULL, NULL, nid, exts[i+1]);
      if (ex)
	sk_X509_EXTENSION_push(st_exts, ex);
    }
  X509_REQ_add_extensions(x, st_exts);
  if (!X509_REQ_sign (x, pk, (pk->type == EVP_PKEY_RSA ? EVP_md5() : EVP_dss1())))
    {
      pk = NULL; /* keep one in the xenc_key */
      *err_ret = srv_make_new_error ("42000", "XECXX", "Can not sign certificate : %s", get_ssl_error_text (buf, sizeof (buf)));
      goto err;
    }

  b = BIO_new (BIO_s_mem());
  PEM_write_bio_X509_REQ (b, x);
  len = BIO_get_mem_data (b, &data_ptr);
  if (len > 0 && data_ptr)
    {
      ret = dk_alloc_box (len + 1, DV_STRING);
      memcpy (ret, data_ptr, len);
      ret[len] = 0;
    }
  BIO_free (b);
  X509_REQ_free (x);
  sk_X509_EXTENSION_pop_free(st_exts, X509_EXTENSION_free);
  return ret;
err:
  EVP_PKEY_free (pk);
  X509_REQ_free (x);
  sk_X509_EXTENSION_pop_free(st_exts, X509_EXTENSION_free);
  return NEW_DB_NULL;
}

static caddr_t
bif_xenc_x509_from_csr (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  static char * me = "xenc_x509_from_csr";
  caddr_t key_name = bif_string_arg (qst, args, 0, me);
  caddr_t cli_name = bif_string_arg (qst, args, 1, me);
  caddr_t csr_str  = bif_string_arg (qst, args, 2, me);
  long serial = bif_long_arg (qst, args, 3, me);
  long days = bif_long_arg (qst, args, 4, me);
  float hours = BOX_ELEMENTS (args) > 5 ? (float) bif_float_arg (qst, args, 5, me) : 0;
  caddr_t digest_name = BOX_ELEMENTS (args) > 6 ? bif_string_arg (qst, args, 6, me) : DEFAULT_SHA_DIGEST;
  xenc_key_t * ca_key = xenc_get_key_by_name (key_name, 1), * k = xenc_get_key_by_name (cli_name, 1);
  X509 *x = NULL;
  X509_REQ *req = NULL;
  EVP_PKEY *pk = NULL, *cli_pk = NULL;
  RSA *rsa = NULL;
  DSA *dsa = NULL;
  char * enc_algoname, * sign_algoname;
  X509_NAME *name = NULL, *xn;
  int i;
  BIO *b;
  STACK_OF(X509_EXTENSION) *exts = NULL;
  X509_EXTENSION *ext;
  const EVP_MD *digest = EVP_get_digestbyname (digest_name);

  if (!digest)
    sqlr_new_error ("42000", "XECXX", "Cannot find digest %s", digest_name);

  if (k)
    {
      *err_ret = srv_make_new_error ("22023", "XECXX", "The key [%s] already exists", cli_name);
      goto err;
    }

  /* check ca cert */
  if (!ca_key || !ca_key->xek_evp_private_key || !ca_key->xek_x509)
    {
      *err_ret = srv_make_new_error ("22023", "XECXX", "Missing or invalid signer certificate");
      goto err;
    }

  b = BIO_new (BIO_s_mem());
  BIO_write (b, csr_str, box_length (csr_str) - 1);
  req = PEM_read_bio_X509_REQ (b, NULL, NULL, NULL);
  BIO_free (b);


  if (!req)
    {
      *err_ret = srv_make_new_error ("22023", "XECXX", "Invalid certificate request");
      goto err;
    }

  cli_pk = X509_REQ_get_pubkey(req);
  if (!cli_pk)
    {
      *err_ret = srv_make_new_error ("22023", "XECXX", "Invalid certificate request public key");
      goto err;
    }

  i = X509_REQ_verify (req, cli_pk);
  if (i <= 0)
    {
      /* XXX: free */
      *err_ret = srv_make_new_error ("22023", "XECXX", "Signature did not match the certificate request");
      goto err;
    }

  xn = X509_REQ_get_subject_name(req);
  if (!xn)
    {
      *err_ret = srv_make_new_error ("22023", "XECXX", "Invalid certificate request subject name");
      goto err;
    }


  pk = ca_key->xek_evp_private_key;

  if ((x = X509_new()) == NULL)
    {
      *err_ret = srv_make_new_error ("42000", "XECXX", "Can not create x.509 structure");
      goto err;
    }


  X509_set_version (x,2);
  ASN1_INTEGER_set (X509_get_serialNumber (x), serial);
  X509_gmtime_adj (X509_get_notBefore (x), 0);
  X509_gmtime_adj (X509_get_notAfter (x), (long) (((days * 24) + hours) * 60 * 60));
  X509_set_pubkey (x, cli_pk);
  X509_set_subject_name (x, X509_NAME_dup (xn));
  name = X509_get_subject_name (x);

  /* issuer */
  X509_set_issuer_name(x, X509_NAME_dup (X509_get_subject_name (ca_key->xek_x509)));

  /* Add standard extensions */
  x509_add_ext (x, NID_subject_key_identifier, "hash");
  exts = X509_REQ_get_extensions (req);
  for (i = 0; i < sk_X509_EXTENSION_num (exts); i++)
    {
      ext = sk_X509_EXTENSION_value (exts, i);
      if (!X509_add_ext(x, ext, -1))
	sqlr_warning ("01V01", "QW001", "Unknown extension entry");
    }

  if (!X509_sign (x, pk, digest))
    {
      pk = NULL; /* keep one in the xenc_key */
      *err_ret = srv_make_new_error ("42000", "XECXX", "Can not sign certificate");
      goto err;
    }
  switch (EVP_PKEY_type (cli_pk->type))
    {
      case EVP_PKEY_DSA:
	  sign_algoname = DSIG_DSA_SHA1_ALGO;
	  enc_algoname = XENC_DSA_ALGO;
	  dsa = cli_pk->pkey.dsa;
	  break;
      case EVP_PKEY_RSA:
	  sign_algoname = DSIG_RSA_SHA1_ALGO;
	  enc_algoname = XENC_RSA_ALGO;
	  rsa = cli_pk->pkey.rsa;
	  break;
      default:
	  *err_ret = srv_make_new_error ("42000", "XECXX", "The type of public key is not supported mus tbe RSA or DSA");
	  goto err;
    }
  mutex_enter (xenc_keys_mtx);
  k = xenc_key_create (cli_name, enc_algoname, sign_algoname, 0);
  if (!k)
    {
      mutex_leave (xenc_keys_mtx);
      *err_ret = srv_make_new_error ("42000", "XECXX", "Can not create a key");
      goto err;
    }
  if (rsa)
    {
      k->xek_rsa = rsa;
      k->xek_private_rsa = 0;
      k->ki.rsa.pad = RSA_PKCS1_PADDING;
    }
  else if (dsa)
    {
      k->xek_dsa = dsa;
      k->xek_private_dsa = 0;
    }
  k->xek_evp_key = cli_pk;
  k->xek_x509_ref = xenc_next_id ();
  k->xek_x509 = x;
  k->xek_x509_KI = xenc_x509_KI_base64 (x);
  if (k->xek_x509_KI)
    xenc_certificates_hash_add (k->xek_x509_KI, k, 0);
  mutex_leave (xenc_keys_mtx);
  X509_REQ_free (req);
  return box_num (1);
err:
  X509_REQ_free (req);
  X509_free (x);
  return 0;
}


static caddr_t
bif_xenc_pkcs12_export (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t key_name = bif_string_arg (qst, args, 0, "xenc_pkcs12_export");
  caddr_t name  = bif_string_arg (qst, args, 1, "xenc_pkcs12_export");
  caddr_t pass  = bif_string_arg (qst, args, 2, "xenc_pkcs12_export");
  int export_chain = BOX_ELEMENTS (args) > 3 ? bif_long_arg (qst, args, 3, "xenc_pkcs12_export") : 0;
  caddr_t acerts = BOX_ELEMENTS (args) > 4 ? bif_string_arg (qst, args, 4, "xenc_pkcs12_export") : NULL;

  xenc_key_t * key = xenc_get_key_by_name (key_name, 1);
  X509 *x;
  EVP_PKEY *pk;
  PKCS12 *p12;
  BIO * b;
  char *data_ptr;
  int len;
  caddr_t ret = NULL;
  STACK_OF (X509) * chain = NULL, *certs = NULL;
  STACK_OF (X509_INFO) * inf = NULL;

  if (!key || !key->xek_evp_private_key || !key->xek_x509)
    goto err;

  if (acerts)
    {
      BIO *in = BIO_new_mem_buf (acerts, box_length (acerts) - 1);
      inf = PEM_X509_INFO_read_bio (in, NULL, NULL, NULL);
      BIO_free (in);
    }

  pk = key->xek_evp_private_key;
  x = key->xek_x509;

  if (export_chain)
    {
      int i;
      X509_STORE_CTX store_ctx;
      X509_STORE_CTX_init (&store_ctx, CA_certs, x, NULL);
      if (X509_verify_cert (&store_ctx) > 0)
	chain = X509_STORE_CTX_get1_chain (&store_ctx);
      else
	{
	  const char *err_str;
	  err_str = X509_verify_cert_error_string (store_ctx.error);
	  *err_ret = srv_make_new_error ("22023", "XENCX", "X509 error: %s", err_str);
	  X509_STORE_CTX_cleanup (&store_ctx);
	  goto err;
	}
      X509_STORE_CTX_cleanup (&store_ctx);
      if (chain)
	{
	  certs = sk_X509_new_null ();
	  for (i = 1; i < sk_X509_num (chain) ; i++)
	    sk_X509_push (certs, sk_X509_value (chain, i));
	  sk_free (chain);
	}
      if (inf)
	{
	  for (i = 0; i < sk_X509_INFO_num (inf); i++)
	    {
	      X509_INFO *itmp = sk_X509_INFO_value (inf, i);
	      if (itmp->x509)
		sk_X509_push (certs, itmp->x509);
	    }
	}
    }
  p12 = PKCS12_create(pass, name, pk, x, certs, 0,0,0,0,0);
  b = BIO_new (BIO_s_mem());
  i2d_PKCS12_bio (b, p12);
  len = BIO_get_mem_data (b, &data_ptr);
  if (len > 0 && data_ptr)
    {
      ret = dk_alloc_box (len, DV_BIN);
      memcpy (ret, data_ptr, len);
    }
  BIO_free (b);
  PKCS12_free (p12);
  sk_free (certs);
  if (inf)
    sk_X509_INFO_pop_free (inf, X509_INFO_free);
  return ret;
err:
  if (inf)
    sk_X509_INFO_pop_free (inf, X509_INFO_free);
  return NULL;
}

static caddr_t
bif_xenc_pem_export (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t key_name = bif_string_arg (qst, args, 0, "xenc_pem_export");
  long pkey = BOX_ELEMENTS (args) > 1 ? bif_long_arg (qst, args, 1, "xenc_pem_export") : 0;
  caddr_t cipher_name = BOX_ELEMENTS (args) > 2 ? bif_string_arg (qst, args, 2, "xenc_pem_export") : NULL;
  caddr_t pass = BOX_ELEMENTS (args) > 2 ? bif_string_arg (qst, args, 3, "xenc_pem_export") : NULL;
  xenc_key_t * key = xenc_get_key_by_name (key_name, 1);
  BIO * b;
  char *data_ptr;
  int len;
  caddr_t ret = NULL;
  const EVP_CIPHER *enc = pass && strlen (pass) ? EVP_get_cipherbyname (cipher_name) : NULL;

  if (!enc && pass && strlen (pass))
    sqlr_new_error ("42000", "CR006", "Cannot find cipher");

  if (!key)
    goto err;

  b = BIO_new (BIO_s_mem());
  if (key->xek_x509)
    {
      PEM_write_bio_X509 (b, key->xek_x509);
      if (pkey && key->xek_evp_private_key)
	PEM_write_bio_PrivateKey (b, key->xek_evp_private_key, enc, NULL, 0, NULL, pass);
    }
  else if (key->xek_type == DSIG_KEY_RSA)
    PEM_write_bio_RSAPrivateKey (b, key->xek_private_rsa, enc, NULL, 0, NULL, pass);
  else if (key->xek_type == DSIG_KEY_DSA)
    PEM_write_bio_DSAPrivateKey (b, key->xek_private_dsa, enc, NULL, 0, NULL, pass);
  else
    {
      BIO_free (b);
      goto err;
    }

  len = BIO_get_mem_data (b, &data_ptr);
  if (len > 0 && data_ptr)
    {
      ret = dk_alloc_box (len + 1, DV_STRING);
      memcpy (ret, data_ptr, len);
      ret[len] = 0;
    }
  BIO_free (b);
  return ret;
err:
  return NEW_DB_NULL;
}

static caddr_t
bif_xenc_pubkey_pem_export (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t key_name = bif_string_arg (qst, args, 0, "xenc_pubkey_pem_export");
  xenc_key_t * key = xenc_get_key_by_name (key_name, 1);
  BIO * b;
  char *data_ptr;
  int len;
  caddr_t ret = NULL;
  EVP_PKEY * k;

  if (!key)
    goto err;

  b = BIO_new (BIO_s_mem());
  if (key->xek_x509)
    {
      k = X509_get_pubkey (key->xek_x509);
#ifdef EVP_PKEY_RSA
      if (k->type == EVP_PKEY_RSA)
	{
	  RSA * x = k->pkey.rsa;
	  PEM_write_bio_RSA_PUBKEY (b, x);
	}
#endif
#ifdef EVP_PKEY_DSA
      if (k->type == EVP_PKEY_DSA)
	{
	  DSA * x = k->pkey.dsa;
	  PEM_write_bio_DSA_PUBKEY (b, x);
	}
#endif
      EVP_PKEY_free (k);
    }
  else if (key->xek_type == DSIG_KEY_RSA)
    PEM_write_bio_RSA_PUBKEY (b, key->xek_rsa);
  else if (key->xek_type == DSIG_KEY_DSA)
    PEM_write_bio_DSA_PUBKEY (b, key->xek_dsa);
  else
    {
      BIO_free (b);
      goto err;
    }
  len = BIO_get_mem_data (b, &data_ptr);
  if (len > 0 && data_ptr)
    {
      ret = dk_alloc_box (len + 1, DV_STRING);
      memcpy (ret, data_ptr, len);
      ret[len] = 0;
    }
  BIO_free (b);
  return ret;
err:
  return NEW_DB_NULL;
}

static caddr_t
bif_xenc_pubkey_der_export (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t key_name = bif_string_arg (qst, args, 0, "xenc_pubkey_DER_export");
  xenc_key_t * key = xenc_get_key_by_name (key_name, 1);
  BIO * b;
  char *data_ptr;
  int len;
  caddr_t ret = NULL;
  EVP_PKEY * k;

  if (!key)
    goto err;

  b = BIO_new (BIO_s_mem());
  if (key->xek_x509)
    {
      k = X509_get_pubkey (key->xek_x509);
#ifdef EVP_PKEY_RSA
      if (k->type == EVP_PKEY_RSA)
	{
	  RSA * x = k->pkey.rsa;
	  i2d_RSA_PUBKEY_bio (b, x);
	}
#endif
#ifdef EVP_PKEY_DSA
      if (k->type == EVP_PKEY_DSA)
	{
	  DSA * x = k->pkey.dsa;
	  i2d_DSA_PUBKEY_bio (b, x);
	}
#endif
      EVP_PKEY_free (k);
    }
  else if (key->xek_type == DSIG_KEY_RSA)
    i2d_RSA_PUBKEY_bio (b, key->xek_rsa);
  else if (key->xek_type == DSIG_KEY_DSA)
    i2d_DSA_PUBKEY_bio (b, key->xek_dsa);
  else
    {
      BIO_free (b);
      goto err;
    }
  len = BIO_get_mem_data (b, &data_ptr);
  if (len > 0 && data_ptr)
    {
      ret = dk_alloc_box (len, DV_BIN);
      memcpy (ret, data_ptr, len);
    }
  BIO_free (b);
  return ret;
err:
  return NEW_DB_NULL;
}

static caddr_t
BN2binbox (BIGNUM * x)
{
  size_t buf_len, n;
  caddr_t buf;
  buf_len = (size_t) BN_num_bytes (x);
  buf = dk_alloc_box (buf_len, DV_BIN);
  n = BN_bn2bin (x, (unsigned char *) buf);
  if (n != buf_len)
    GPF_T;
  return buf;
}

/* encode BIN box to base64 and free the input box */
static caddr_t
xenc_encode_base64_binbox (caddr_t box, int free)
{
  caddr_t buf, ret;
  int len = box_length (box);
  if (!IS_BOX_POINTER (box))
    return NULL;
  buf = dk_alloc_box (len * 2, DV_BIN);
  len = xenc_encode_base64 ((char *)box, buf, len);
  ret = dk_alloc_box (len + 1, DV_STRING);
  memcpy (ret, buf, len);
  ret[len] = 0;
  dk_free_box (buf);
  if (free)
    dk_free_box (box);
  return ret;
}

static caddr_t
xenc_rsa_pub_magic (RSA * x)
{
  caddr_t ret;
  caddr_t n = BN2binbox (x->n); /* modulus */
  caddr_t e = BN2binbox (x->e); /* public exponent */
  n = xenc_encode_base64_binbox (n, 1);
  e = xenc_encode_base64_binbox (e, 1);
  ret = dk_alloc_box (box_length (n) + box_length (e) + 4 /* two dots - one trailing zero + RSA prefix */, DV_STRING);
  snprintf (ret, box_length (ret), "RSA.%s.%s", n, e);
  dk_free_box (n);
  dk_free_box (e);
  return ret;
}

static caddr_t
bif_xenc_pubkey_magic_export (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t key_name = bif_string_arg (qst, args, 0, "xenc_pubkey_magic_export");
  xenc_key_t * key = xenc_get_key_by_name (key_name, 1);
  caddr_t ret = NULL;
  EVP_PKEY * k;

  if (!key)
    SQLR_NEW_KEY_ERROR (key_name);

  if (key->xek_x509)
    {
      k = X509_get_pubkey (key->xek_x509);
#ifdef EVP_PKEY_RSA
      if (k->type == EVP_PKEY_RSA)
	{
	  RSA * x = k->pkey.rsa;
	  ret = xenc_rsa_pub_magic (x);
	}
#endif
      EVP_PKEY_free (k);
    }
  else if (key->xek_type == DSIG_KEY_RSA)
    {
       RSA * x = key->xek_rsa;
       ret = xenc_rsa_pub_magic (x);
    }
  else
    sqlr_new_error ("42000", "XENC..", "The key type is not supported for export.");

  return ret;
}

static int
xenc_ssh_encode (caddr_t dest, caddr_t src)
{
  int32 new_len, len, pos;
  new_len = len = box_length (src);
  if (*src & 0x80)
    {
      new_len++;
      dest[4] = 0;
      pos = 5;
    }
  else
    {
      pos = 4;
    }
  LONG_SET_NA (dest, new_len);
  memcpy(&dest[pos], src, len);
  return pos + len;
}

static caddr_t
xenc_rsa_pub_ssh_export (RSA * x)
{
  static char * ssh_header = "\x00\x00\x00\x07ssh-rsa";
  caddr_t ret;
  int len, pos;
  caddr_t n = BN2binbox (x->n); /* modulus */
  caddr_t e = BN2binbox (x->e); /* public exponent */
  len = 11 + 8 + box_length (n) + box_length (e);
  if (n[0] & 0x80)
    len ++;
  if (e[0] & 0x80)
    len ++;
  ret = dk_alloc_box (len, DV_BIN);
  memcpy (ret, ssh_header, 11);
  pos = xenc_ssh_encode (&ret[11], e);
  pos = xenc_ssh_encode (&ret[11 + pos], n);
  dk_free_box (n);
  dk_free_box (e);
  ret = xenc_encode_base64_binbox (ret, 1);
  return ret;
}

static caddr_t
bif_xenc_pubkey_ssh_export (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t key_name = bif_string_arg (qst, args, 0, "xenc_pubkey_ssh_export");
  xenc_key_t * key = xenc_get_key_by_name (key_name, 1);
  caddr_t ret = NULL;
  EVP_PKEY * k;

  if (!key)
    SQLR_NEW_KEY_ERROR (key_name);

  if (key->xek_x509)
    {
      k = X509_get_pubkey (key->xek_x509);
#ifdef EVP_PKEY_RSA
      if (k->type == EVP_PKEY_RSA)
	{
	  RSA * x = k->pkey.rsa;
	  ret = xenc_rsa_pub_ssh_export (x);
	}
#endif
      EVP_PKEY_free (k);
    }
  else if (key->xek_type == DSIG_KEY_RSA)
    {
       RSA * x = key->xek_rsa;
       ret = xenc_rsa_pub_ssh_export (x);
    }
  else
    sqlr_new_error ("42000", "XENC..", "The key type is not supported for export.");

  return ret;
}

static caddr_t
bif_xenc_SPKI_read (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t name = bif_key_name_arg (qst, args, 0, "xenc_SPKI_read");
  caddr_t key_data = bif_string_arg (qst, args, 1, "xenc_SPKI_read");
  xenc_key_t * k;
  RSA *p;
  NETSCAPE_SPKI * spki = NETSCAPE_SPKI_b64_decode (key_data, box_length (key_data) - 1);
  EVP_PKEY * pk;

  if (!spki)
    {
      *err_ret = srv_make_new_error ("42000", "XECXX", "Can not decode SPKI");
      return NULL;
    }
  pk = NETSCAPE_SPKI_get_pubkey (spki);
  if (!pk || pk->type != EVP_PKEY_RSA)
    {
      NETSCAPE_SPKI_free (spki);
      *err_ret = srv_make_new_error ("42000", "XECXX", "Can not retrieve RSA key");
      return NULL;
    }
  p = EVP_PKEY_get1_RSA (pk);
  mutex_enter (xenc_keys_mtx);
  k = xenc_key_create (name, XENC_RSA_ALGO, DSIG_RSA_SHA1_ALGO, 0);
  if (NULL == k)
    {
      mutex_leave (xenc_keys_mtx);
      SQLR_NEW_KEY_EXIST_ERROR (name);
    }
  k->xek_private_rsa = NULL;
  k->xek_rsa = p;
  k->ki.rsa.pad = RSA_PKCS1_PADDING;
  k->xek_evp_key = pk;
  mutex_leave (xenc_keys_mtx);
  NETSCAPE_SPKI_free (spki);
  return box_dv_short_string (k->xek_name);
}

static caddr_t
bif_xenc_x509_verify (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char * me = "x509_verify";
  caddr_t cert_name = bif_string_arg (qst, args, 0, me);
  caddr_t key_name  = bif_string_arg (qst, args, 1, me);
  xenc_key_t * cert = xenc_get_key_by_name (cert_name, 1);
  xenc_key_t * key = xenc_get_key_by_name (key_name, 1);
  int rc = 0;

  if (!key)
    SQLR_NEW_KEY_ERROR (key_name);
  if (!cert)
    SQLR_NEW_KEY_ERROR (cert_name);
  if (!cert->xek_x509)
    sqlr_new_error ("22023", ".....", "The certificate key does not have x509 assigned.");
  if (!key->xek_evp_key)
    sqlr_new_error ("22023", ".....", "The key is incomplete.");
  rc = X509_verify (cert->xek_x509, key->xek_evp_key);
  return box_num (rc);
}

static X509 *
x509_from_pem (caddr_t pem)
{
  BIO *buf;
  X509 *ret;
  buf = BIO_new_mem_buf (pem, box_length (pem) - 1);
  ret = PEM_read_bio_X509 (buf, NULL, NULL, NULL);
  BIO_free (buf);
  return ret;
}

static caddr_t
bif_xenc_x509_verify_array (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char * me = "x509_verify_array";
  caddr_t cert_name = bif_string_arg (qst, args, 0, me);
  caddr_t * ca_certs  = bif_arg (qst, args, 1, me);
  xenc_key_t * cert = xenc_get_key_by_name (cert_name, 1);
  int rc = 0, inx;
  BIO *buf;
  X509 *ca_cert;

  if (!cert)
    SQLR_NEW_KEY_ERROR (cert_name);
  if (!cert->xek_x509)
    sqlr_new_error ("22023", ".....", "The certificate key does not have x509 assigned.");
  if (!ARRAYP (ca_certs))
    sqlr_new_error ("22023", ".....", "The x509_verify_array needs and array of PEM encoded CA certificates.");
  DO_BOX (caddr_t, ca, inx, ca_certs)
    {
      EVP_PKEY * pubkey;
      if (!DV_STRINGP (ca))
	sqlr_new_error ("22023", ".....", "The CA certificates array must be array of strings.");
      ca_cert = x509_from_pem (ca);
      if (ca_cert)
	{
	  pubkey = X509_get_pubkey (ca_cert);
	  rc = X509_verify (cert->xek_x509, pubkey);
	  EVP_PKEY_free (pubkey);
	  X509_free (ca_cert);
	}
      if (rc)
	break;
    }
  END_DO_BOX;
  return box_num (rc);
}

static caddr_t
bif_xenc_x509_cert_verify_array (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char * me = "x509_cert_verify_array";
  caddr_t cert_text = bif_string_arg (qst, args, 0, me);
  caddr_t * ca_certs  = bif_arg (qst, args, 1, me);
  X509 * cert = x509_from_pem (cert_text);
  int rc = 0, inx;
  BIO *buf;
  X509 *ca_cert;

  if (!cert)
    sqlr_new_error ("22023", ".....", "The certificate cannot be loaded.");
  if (!ARRAYP (ca_certs))
    sqlr_new_error ("22023", ".....", "The x509_verify_array needs and array of PEM encoded CA certificates.");
  DO_BOX (caddr_t, ca, inx, ca_certs)
    {
      EVP_PKEY * pubkey;
      if (!DV_STRINGP (ca))
	sqlr_new_error ("22023", ".....", "The CA certificates array must be array of strings.");
      ca_cert = x509_from_pem (ca);
      if (ca_cert)
	{
	  pubkey = X509_get_pubkey (ca_cert);
	  rc = X509_verify (cert, pubkey);
	  EVP_PKEY_free (pubkey);
	  X509_free (ca_cert);
	}
      if (rc)
	break;
    }
  END_DO_BOX;
  X509_free (cert);
  return box_num (rc);
}


static caddr_t
bif_xenc_x509_ca_cert_add (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char * me = "x509_ca_cert_add";
  caddr_t cert_text = bif_string_arg (qst, args, 0, me);
  char err_buf[512];
  sec_check_dba ((QI*)qst, me);
  mutex_enter (xenc_keys_mtx);
  if (CA_certs)
    {
      X509 * cacert = x509_from_pem (cert_text);
      if (cacert)
	X509_STORE_add_cert (CA_certs, cacert);
      else
	*err_ret = srv_make_new_error ("42000", ".....", "%s", get_ssl_error_text (err_buf, sizeof (err_buf)));
    }
  mutex_leave (xenc_keys_mtx);
  return NULL;
}

static caddr_t
bif_xenc_x509_ca_certs_remove (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char * me = "x509_ca_certs_remove";

  sec_check_dba ((QI*)qst, me);
  mutex_enter (xenc_keys_mtx);
  X509_STORE_free (CA_certs);
  CA_certs = X509_STORE_new ();
  mutex_leave (xenc_keys_mtx);
  return NULL;
}

static caddr_t
bif_xenc_x509_ca_certs_list (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char * me = "x509_ca_certs_list";
  STACK_OF (X509_OBJECT) * certs;
  BIO *in;
  caddr_t ret;
  int i, len;
  char * ptr;
  dk_set_t set = NULL;

  sec_check_dba ((QI*)qst, me);
  in = BIO_new (BIO_s_mem ());
  mutex_enter (xenc_keys_mtx);
  certs = CA_certs->objs;
  len = sk_X509_OBJECT_num (certs);
  for (i = 0; i < len; i++)
    {
      X509_OBJECT * obj = sk_X509_OBJECT_value (certs, i);
      if (obj->type == X509_LU_X509)
	{
	  X509 *x = obj->data.x509;
	  caddr_t itm;
	  int blen;
	  BIO_reset (in);
	  PEM_write_bio_X509 (in, x);
	  blen = BIO_get_mem_data (in, &ptr);
	  itm = dk_alloc_box (blen + 1, DV_SHORT_STRING);
	  memcpy (itm, ptr, blen);
          itm [blen] = 0;
	  dk_set_push (&set, itm);
	}
    }
  mutex_leave (xenc_keys_mtx);
  BIO_free (in);
  ret = list_to_array (dk_set_nreverse (set));
  return ret;
}

void bif_xmlenc_init ()
{
#ifdef DEBUG
  log_info ("xmlenc_init()");
#endif

  CA_certs = X509_STORE_new ();
  xenc_keys_mtx = mutex_allocate ();
  __xenc_keys = id_hash_allocate (231, sizeof (caddr_t), sizeof (caddr_t), strhash,
				strhashcmp);
  __xenc_certificates = id_hash_allocate (231, sizeof (caddr_t), sizeof (caddr_t),
					strhash, strhashcmp);

  algo_stores_init();
  dsig_sec_init();

  /* test keys */
  xenc_algorithms_create (XENC_DES3_ALGO, "tripledes encoding algorithm",
			  xenc_des3_encryptor,
			  xenc_des3_decryptor,
			  DSIG_KEY_3DES);

  xenc_algorithms_create (DSIG_DSA_SHA1_ALGO, "dsa sha1 algorithm",
			  xenc_signature_wrapper,
			  xenc_signature_wrapper_1,
			  DSIG_KEY_DSA);

  xenc_algorithms_create (DSIG_RSA_SHA1_ALGO, "rsa sha1 algorithm",
			  xenc_signature_wrapper,
			  xenc_signature_wrapper_1,
			  DSIG_KEY_RSA);

  xenc_algorithms_create (XENC_BASE64_ALGO, "base64 encoding algorithm",
			  xenc_base64_encryptor,
			  xenc_base64_decryptor,
			  DSIG_KEY_RAW);

  xenc_algorithms_create (XENC_RSA_ALGO, "rsa encoding algorithm",
			  xenc_rsa_encryptor,
			  xenc_rsa_decryptor,
			  DSIG_KEY_RSA);
  xenc_algorithms_create (XENC_DSA_ALGO, "dsa encoding algorithm",
			  xenc_dsa_encryptor,
			  xenc_dsa_decryptor,
			  DSIG_KEY_DSA);

#ifdef AES_ENC_ENABLE
  xenc_algorithms_create (XENC_AES128_ALGO, "aes 128 cbc encoding algorithm",
			  xenc_aes_encryptor,
			  xenc_aes_decryptor,
			  DSIG_KEY_AES);
  xenc_algorithms_create (XENC_AES192_ALGO, "aes 192 cbc encoding algorithm",
			  xenc_aes_encryptor,
			  xenc_aes_decryptor,
			  DSIG_KEY_AES);
  xenc_algorithms_create (XENC_AES256_ALGO, "aes 256 cbc encoding algorithm",
			  xenc_aes_encryptor,
			  xenc_aes_decryptor,
			  DSIG_KEY_AES);
#endif

  xenc_algorithms_create (XENC_DH_ALGO, "dh encoding algorithm",
			  xenc_dh_encryptor,
			  xenc_dh_decryptor,
			  DSIG_KEY_DH);

  xenc_algorithms_create (DSIG_DH_SHA1_ALGO, "dsa sha1 algorithm",
			  xenc_signature_wrapper,
			  xenc_signature_wrapper_1,
			  DSIG_KEY_DH);


  bif_define ("xenc_encrypt", bif_xmlenc_encrypt);
  bif_define ("xml_sign", bif_xml_sign);

  bif_define ("xenc_key_inst_create", bif_xenc_key_inst_create);
  bif_define ("xenc_decrypt_soap", bif_xmlenc_decrypt_soap); /* decrypts & validates encrypted & signed SOAP message */
  bif_define ("dsig_validate", bif_dsig_validate); /* validates xml against detached signature */
  bif_define ("xenc_key_3DES_create", bif_xenc_key_3des_create);
  bif_define ("xenc_key_3DES_rand_create", bif_xenc_key_3des_rand_create);
#if 0
  bif_define ("xenc_DSA_SHA1_sign", bif_xenc_dsa_sha1_sign);
  bif_define ("xenc_DSA_SHA1_verify", bif_xenc_dsa_sha1_verify);
#endif
  bif_define ("xenc_key_DSA_create", bif_xenc_key_dsa_create);
  bif_define ("xenc_key_RSA_create", bif_xenc_key_rsa_create);
  bif_define ("xenc_key_create_cert", bif_xenc_key_create_cert);
  bif_define ("xenc_key_remove", bif_xenc_key_remove);
  bif_define ("xenc_key_exists", bif_xenc_key_exists);

  bif_define ("dsig_template_ext", bif_dsig_template_ext);

#ifdef AES_ENC_ENABLE
  bif_define ("xenc_key_AES_create", bif_xenc_key_aes_create);
  bif_define ("xenc_key_AES_rand_create", bif_xenc_key_aes_rand_create);
#endif

  bif_define ("xenc_key_3DES_read", bif_xenc_key_3des_read);
  bif_define ("xenc_key_RSA_read", bif_xenc_key_rsa_read);
  bif_define ("xenc_key_RSA_construct", bif_xenc_key_rsa_construct);
  bif_define ("xenc_key_DSA_read", bif_xenc_key_dsa_read);
  bif_define ("xenc_key_RAW_read", bif_xenc_key_raw_read);
  bif_define ("xenc_key_RAW_rand_create", bif_xenc_key_raw_rand_create);
  bif_define ("xenc_rand_bytes", bif_xenc_rand_bytes);
  bif_define ("xenc_key_serialize", bif_xenc_key_serialize);
  bif_define ("xenc_X509_certificate_serialize", bif_xenc_x509_cert_serialize);
  bif_define ("xenc_set_primary_key", bif_xenc_set_primary_key);
  bif_define ("xenc_get_key_algo", bif_xenc_get_key_algo);
  bif_define ("xenc_get_key_identifier", bif_xenc_get_key_identifier);
  bif_define ("xenc_delete_temp_keys", bif_delete_temp_keys);
  bif_define ("xenc_x509_ss_generate", bif_xenc_x509_ss_generate);
  bif_define ("xenc_x509_generate", bif_xenc_x509_generate);
  bif_define ("xenc_x509_csr_generate", bif_xenc_x509_csr_generate);
  bif_define ("xenc_x509_from_csr", bif_xenc_x509_from_csr);
  bif_define ("xenc_pkcs12_export", bif_xenc_pkcs12_export);
  bif_define ("xenc_pem_export", bif_xenc_pem_export);
  bif_define ("xenc_pubkey_pem_export", bif_xenc_pubkey_pem_export);
  bif_define ("xenc_pubkey_DER_export", bif_xenc_pubkey_der_export);
  bif_define ("xenc_pubkey_magic_export", bif_xenc_pubkey_magic_export);
  bif_define ("xenc_pubkey_ssh_export", bif_xenc_pubkey_ssh_export);
  bif_define ("xenc_SPKI_read", bif_xenc_SPKI_read);

#ifdef _KERBEROS
  bif_define ("xenc_key_kerberos_create", bif_xenc_key_kerberos_create);
#endif

  XENCTypeContentIdx = ecm_find_name ("Content", xenc_types, xenc_types_len, sizeof (xenc_type_t));
  XENCTypeDocumentIdx =  ecm_find_name ("Document", xenc_types, xenc_types_len, sizeof (xenc_type_t));
  XENCTypeElementIdx =  ecm_find_name ("Element", xenc_types, xenc_types_len, sizeof (xenc_type_t));

#ifdef DEBUG
  bif_define ("dsig_a_test", bif_dsig_a_test);
  bif_define ("dsig_b_test", bif_dsig_b_test);
  bif_define ("xenc_key_3DES_test_create", bif_xenc_key_3des_test_create);
  bif_define ("xenc_test", bif_xenc_test);
  bif_define ("print_KI", bif_print_KI);
#endif
  bif_define ("X509_get_subject", bif_x509_get_subject);
  bif_define ("xenc_sha1_digest", bif_xenc_sha1_digest);
  bif_define ("xenc_hmac_sha1_digest", bif_xenc_hmac_sha1_digest);
#ifdef SHA256_ENABLE
  bif_define ("xenc_sha256_digest", bif_xenc_sha256_digest);
  bif_define ("xenc_hmac_sha256_digest", bif_xenc_hmac_sha256_digest);
#endif
  bif_define ("xenc_rsa_sha1_digest", bif_xenc_rsa_sha1_digest);
  bif_define ("xenc_key_DH_create", bif_xenc_key_DH_create);
  bif_define ("xenc_DH_get_params", bif_xenc_DH_get_params);
  bif_define ("xenc_DH_compute_key", bif_xenc_DH_compute_key);
  bif_define ("xenc_xor", bif_xenc_xor);
  bif_define ("xenc_bn2dec", bif_xenc_bn2dec);
  bif_define ("xenc_dsig_sign", bif_xenc_dsig_signature);
  bif_define ("xenc_dsig_verify", bif_xenc_dsig_verify);
  bif_define ("x509_verify", bif_xenc_x509_verify);
  bif_define ("x509_verify_array", bif_xenc_x509_verify_array);
  bif_define ("x509_cert_verify_array", bif_xenc_x509_cert_verify_array);
  bif_define ("x509_ca_cert_add", bif_xenc_x509_ca_cert_add);
  bif_define ("x509_ca_certs_remove", bif_xenc_x509_ca_certs_remove);
  bif_define ("xenc_x509_ca_certs_list", bif_xenc_x509_ca_certs_list);

  xenc_cert_X509_idx = ecm_find_name ("X.509", (void*)xenc_cert_types, xenc_cert_types_len,
					 sizeof (xenc_cert_type_t));
  xenc_cert_KERB5TGT_idx = ecm_find_name ("Kerberosv5TGT", (void*)xenc_cert_types, xenc_cert_types_len,
					 sizeof (xenc_cert_type_t));
  xenc_cert_KERB5ST_idx = ecm_find_name ("Kerberosv5ST", (void*)xenc_cert_types, xenc_cert_types_len,
					 sizeof (xenc_cert_type_t));


}

#ifdef DEBUG
void print_hash (id_hash_t * h)
{
  id_hash_iterator_t iter;
  caddr_t * tag;
  caddr_t * nss;
  for (id_hash_iterator (&iter, h);
       hit_next (&iter, (caddr_t *) &tag, (caddr_t *) &nss);
       /* */)
    {
      printf ("*********************\n");
      dbg_print_box (nss[0], stdout);
      fflush (stdout);
    }
}
#endif

#else /* _SSL */
#include "sqlnode.h"
#include "sqlbif.h"

/* dummy BIF when no SSL, this is to work PL code */
static
caddr_t bif_xenc_key_exists (caddr_t * qst, caddr_t * err_r, state_slot_t ** args)
{
  return box_num (0);
}


void bif_xmlenc_init ()
{
  bif_define ("xenc_key_exists", bif_xenc_key_exists);
}

#endif /* _SSL */
