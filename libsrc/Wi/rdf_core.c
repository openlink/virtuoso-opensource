/*
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2006 OpenLink Software
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
#include "sqlnode.h"
#include "sqlbif.h"
#include "sqlparext.h"
#include "bif_text.h"
#include "bif_xper.h"
#include "xmlparser.h"
#include "xmltree.h"
#include "numeric.h"
#include "sqlcmps.h"
#include "rdf_core.h"
#ifdef __cplusplus
extern "C" {
#endif
#include "turtle_p.h"
#ifdef __cplusplus
}
#endif

#ifdef RDF_DEBUG
#define rdf_dbg_printf(x) printf(x)
#else
#define rdf_dbg_printf(x)
#endif

triple_feed_t *
tf_alloc (void)
{
  NEW_VARZ (triple_feed_t, tf);
  tf->tf_blank_node_ids = id_hash_allocate (1021, sizeof (caddr_t), sizeof (caddr_t), strhash, strhashcmp);
  tf->tf_cached_iids = id_hash_allocate (21021, sizeof (caddr_t), sizeof (caddr_t), strhash, strhashcmp);
  return tf;
}


void
tf_free (triple_feed_t *tf)
{
  id_hash_t *dict;			/*!< Current dictionary to be zapped */
  id_hash_iterator_t dict_hit;		/*!< Iterator to zap dictionary */
  char **dict_key, **dict_val;		/*!< Current key to zap */
  dict = tf->tf_blank_node_ids;
  for( id_hash_iterator (&dict_hit,dict);
    hit_next(&dict_hit, (char **)(&dict_key), (char **)(&dict_val));
    /*no step*/ )
    {
      dk_free_box (dict_key[0]);      
      dk_free_tree (dict_val[0]);
    }
  dict = tf->tf_cached_iids;
  for( id_hash_iterator (&dict_hit,dict);
    hit_next(&dict_hit, (char **)(&dict_key), (char **)(&dict_val));
    /*no step*/ )
    {
      dk_free_box (dict_key[0]);
      dk_free_tree (dict_val[0]);
    }
  id_hash_free (tf->tf_blank_node_ids);
  id_hash_free (tf->tf_cached_iids);
  dk_free (tf, sizeof (triple_feed_t));
}


void
tf_set_stmt_texts (triple_feed_t *tf, const char **stmt_texts, caddr_t *err_ptr)
{
  int ctr;
  caddr_t err = NULL;
  for (ctr = 0; ctr < COUNTOF__TRIPLE_FEED; ctr++)
    {
      tf->tf_stmt_texts[ctr] = stmt_texts[ctr];
      tf->tf_queries[ctr] = sql_compile (stmt_texts[ctr], tf->tf_qi->qi_client, &err, SQLC_DEFAULT);
      if (NULL != err)
        {
          if (NULL == err_ptr)
            sqlr_resignal (err);
          err_ptr[0] = err;
          return;
        }
    }
}


int32 tf_rnd_seed;

caddr_t
tf_get_iid (triple_feed_t *tf, caddr_t uri)
{
  caddr_t *params;
  local_cursor_t *lc = NULL;
  dtp_t uri_dtp = DV_TYPE_OF (uri);
  caddr_t *hit;
  caddr_t err = NULL;
  if ((DV_STRING != uri_dtp) && (DV_UNAME != uri_dtp))
    return box_copy_tree (uri);
  hit = (caddr_t *)id_hash_get (tf->tf_cached_iids, (caddr_t)(&(uri)));
  if (NULL != hit)
    return box_copy_tree (hit[0]);
  params = (caddr_t *)list (6,
    unames_colon_number[0],
    box_copy (uri),
    unames_colon_number[1],
    box_copy (tf->tf_graph_uri),
    unames_colon_number[2],
    box_copy_tree (tf->tf_app_env) );
  err = qr_exec (tf->tf_qi->qi_client, tf->tf_queries[TRIPLE_FEED_GET_IID], tf->tf_qi, NULL, NULL, &lc, params, NULL, 1);
  dk_free_box ((box_t) params);
  if (NULL != err)
    {
      lc_free (lc);
      sqlr_resignal (err);
    }
  if (lc && lc_next (lc))
    {
      caddr_t iid = box_copy_tree (lc_nth_col (lc, 0));
      caddr_t key = box_copy (uri);
      if (tf->tf_cached_iids->ht_count > 3 * tf->tf_cached_iids->ht_buckets)
	{
	  int rnd_inx = sqlbif_rnd (&tf_rnd_seed);
	  caddr_t del_key, del_data;
	  if (id_hash_remove_rnd (tf->tf_cached_iids, rnd_inx, (caddr_t)&del_key, (caddr_t) &del_data))
	    {
	      dk_free_tree (del_key);
	      dk_free_tree (del_data);
	    }
	}
      id_hash_set (tf->tf_cached_iids, (caddr_t)(&key), (caddr_t)(&iid));      
      lc_free (lc);
      return box_copy_tree (iid);
    }
  lc_free (lc);
  sqlr_new_error ("22023", "RDF02",
    "RDF loader has failed to create ID for URI '%.100s' by '%.100s'",
    uri, tf->tf_stmt_texts[TRIPLE_FEED_GET_IID] );
  return NULL;
}


caddr_t
bif_rdf_load_rdfxml (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t text_arg;
  dtp_t dtp_of_text_arg;
  int arg_is_wide = 0;
  char * volatile enc = NULL;
  lang_handler_t *volatile lh = server_default_lh;
  /*caddr_t volatile dtd_config = NULL;*/
  caddr_t base_uri = NULL;
  caddr_t err = NULL;
  /*xml_ns_2dict_t ns_2dict;*/
  caddr_t graph_uri;
  ccaddr_t *stmt_texts;
  caddr_t app_env;
  int omit_top_rdf = 0;
  int n_args = BOX_ELEMENTS (args);
  /*wcharset_t * volatile charset = QST_CHARSET (qst) ? QST_CHARSET (qst) : default_charset;*/
  text_arg = bif_arg (qst, args, 0, "rdf_load_rdfxml");
  omit_top_rdf = bif_long_arg (qst, args, 1, "rdf_load_rdfxml");
  graph_uri = bif_string_or_wide_or_uname_arg (qst, args, 2, "rdf_load_rdfxml");
  stmt_texts = (ccaddr_t *)bif_strict_type_array_arg (DV_STRING, qst, args, 3, "rdf_load_rdfxml");
  app_env = bif_arg (qst, args, 4, "rdf_load_rdfxml");
  if (COUNTOF__TRIPLE_FEED != BOX_ELEMENTS (stmt_texts))
    sqlr_new_error ("22023", "RDF01",
      "The argument #4 of rdf_load_rdfxml() should be a vector of %d texts of SQL statements",
      COUNTOF__TRIPLE_FEED );
  dtp_of_text_arg = DV_TYPE_OF (text_arg);
  /*ns_2dict.xn2_size = 0;*/
  do
    {
      if ((dtp_of_text_arg == DV_SHORT_STRING) ||
	  (dtp_of_text_arg == DV_LONG_STRING) ||
	  (dtp_of_text_arg == DV_C_STRING) )
	{ /* Note DV_TIMESTAMP_OBJ is not enumerated in if(...), unlike bif_string_arg)_ */
	  break;
	}
      if (IS_WIDE_STRING_DTP (dtp_of_text_arg))
	{
	  arg_is_wide = 1;
	  break;
	}
      if (dtp_of_text_arg == DV_STRING_SESSION)
	{
	  int ses_sort = looks_like_serialized_xml (((query_instance_t *)(qst)), text_arg);
	  if (XE_XPER_SERIALIZATION == ses_sort)
	    sqlr_error ("42000",
	      "Function rdf_load_rdfxml() does not support loading from string session with persistent XML data");
	  if (XE_XPACK_SERIALIZATION == ses_sort)
	    {
#if 1
	    sqlr_error ("42000",
	      "Function rdf_load_rdfxml() does not support loading from string session with packed XML data");
#else
	      caddr_t *tree_tmp = NULL; /* Solely to avoid dummy warning C4090: 'function' : different 'volatile' qualifiers */
	      xte_deserialize_packed ((dk_session_t *)text_arg, &tree_tmp, dtd_ptr);
	      tree = (caddr_t)tree_tmp;
	      if (NULL != dtd)
	        dtd_addref (dtd, 0);
	      if ((NULL == tree) && (DEAD_HTML != (parser_mode & ~(FINE_XSLT | GE_XML | WEBIMPORT_HTML | FINE_XML_SRCPOS))))
		sqlr_error ("42000", "The BLOB passed to a function rdf_load_rdfxml() contains corrupted packed XML serialization data");
	      goto tree_complete; /* see below */
#endif
	    }
	  break;
	}
      if (dtp_of_text_arg == DV_BLOB_XPER_HANDLE)
	sqlr_error ("42000",
	  "Function rdf_load_rdfxml() does not support loading from persistent XML objects");
      if ((DV_BLOB_HANDLE == dtp_of_text_arg) || (DV_BLOB_WIDE_HANDLE == dtp_of_text_arg))
	{
	  int blob_sort = looks_like_serialized_xml (((query_instance_t *)(qst)), text_arg);
	  if (XE_XPER_SERIALIZATION == blob_sort)
	    sqlr_error ("42000",
	      "Function rdf_load_rdfxml() does not support loading from BLOBs with persistent XML data");
	  if (XE_XPACK_SERIALIZATION == blob_sort)
	    {
#if 1
	    sqlr_error ("42000",
	      "Function rdf_load_rdfxml() does not support loading from BLOBs with packed XML data");
#else
	      caddr_t *tree_tmp = NULL; /* Solely to avoid dummy warning C4090: 'function' : different 'volatile' qualifiers */
	      dk_session_t *ses = blob_to_string_output (((query_instance_t *)(qst))->qi_trx, text_arg);
	      xte_deserialize_packed (ses, &tree_tmp, dtd_ptr);
	      tree = (caddr_t)tree_tmp;
	      if (NULL != dtd)
	        dtd_addref (dtd, 0);
	      strses_free (ses);
	      if ((NULL == tree) && (DEAD_HTML != (parser_mode & ~(FINE_XSLT | GE_XML | WEBIMPORT_HTML | FINE_XML_SRCPOS))))
		sqlr_error ("42000", "The BLOB passed to a function rdf_load_rdfxml() contains corrupted packed XML serialization data");
	      goto tree_complete; /* see below */
#endif
	    }
	  arg_is_wide = (DV_BLOB_WIDE_HANDLE == dtp_of_text_arg) ? 1 : 0;
	  break;
	}
      sqlr_error ("42000",
	"Function rdf_load_rdfxml() needs a string or string session or BLOB as argument 1, not an arg of type %s (%d)",
	dv_type_title (dtp_of_text_arg), dtp_of_text_arg);
    } while (0);
  /* Now we have \c text ready to process */

/*
  if (n_args < 3)
    enc = CHARSET_NAME (charset, NULL);
*/
  switch (n_args)
    {
    default:
/*    case 9:
      dtd_config = bif_array_or_null_arg (qst, args, 8, "rdf_load_rdfxml");*/
    case 8:
      lh = lh_get_handler (bif_string_arg (qst, args, 7, "rdf_load_rdfxml"));
    case 7:
      enc = bif_string_arg (qst, args, 6, "rdf_load_rdfxml");
    case 6:
      base_uri = bif_string_or_uname_arg (qst, args, 5, "rdf_load_rdfxml");
    case 5:
    case 4:
    case 3:
    case 2:
    case 1:
	  ;
    }
  rdfxml_parse ((query_instance_t *) qst, text_arg, (caddr_t *)&err, omit_top_rdf,
    base_uri, graph_uri, stmt_texts, app_env, enc, lh
    /*, caddr_t dtd_config, dtd_t **ret_dtd, id_hash_t **ret_id_cache, &ns2dict*/ );
  if (NULL != err)
    sqlr_resignal (err);
  return NULL;
}


dk_mutex_t *ttl_lex_mtx = NULL;
ttlp_t global_ttlp;

ttlp_t *
ttlp_alloc (void)
{
#ifdef RE_ENTRANT_TTLYY
  ttlp_t *ttlp = (ttlp_t *)dk_alloc (sizeof (ttlp_t));
#else
  ttlp_t *ttlp = &global_ttlp;
#endif
  memset (ttlp, 0, sizeof (ttlp_t));
  ttlp->ttlp_lexlineno = 1;
  ttlp->ttlp_tf = tf_alloc();
  return ttlp;
}

void
ttlp_free (ttlp_t *ttlp)
{
  dk_free_box (ttlp->ttlp_tf->tf_graph_uri);
  tf_free (ttlp->ttlp_tf);
  while (NULL != ttlp->ttlp_namespaces)
    dk_free_tree ((box_t) dk_set_pop (&(ttlp->ttlp_namespaces)));
  while (NULL != ttlp->ttlp_saved_uris)
    dk_free_tree ((box_t) dk_set_pop (&(ttlp->ttlp_saved_uris)));
  dk_free_box (ttlp->ttlp_base_uri);
  dk_free_box (ttlp->ttlp_subj_uri);
  dk_free_box (ttlp->ttlp_pred_uri);
#ifdef RE_ENTRANT_TTLYY
  dk_free (ttlp, sizeof (ttlp_t));
#endif
}

void
ttlyyerror_impl (TTLP_PARAM const char *raw_text, const char *strg)
{
  int lineno = ttlp_inst.ttlp_lexlineno;
  if (NULL == raw_text)
    raw_text = ttlp_inst.ttlp_raw_text;
  sqlr_new_error ("37000", "SP029",
      "%.400s, line %d: %.500s%.5s%.1000s",
      ttlp_inst.ttlp_err_hdr,
      lineno,
      strg,
      ((NULL == raw_text) ? "" : " at "),
      ((NULL == raw_text) ? "" : raw_text));
}


void
ttlyyerror_impl_1 (TTLP_PARAM const char *raw_text, int yystate, short *yyssa, short *yyssp, const char *strg)
{
  int sm2, sm1, sp1;
  int lineno = ttlp_inst.ttlp_lexlineno;
  if (NULL == raw_text)
    raw_text = ttlp_inst.ttlp_raw_text;
  sp1 = yyssp[1];
  sm1 = yyssp[-1];
  sm2 = ((sm1 > 0) ? yyssp[-2] : 0);
  sqlr_new_error ("37000", "RDF30",
     /*errlen,*/ "%.400s, line %d: %.500s [%d-%d-(%d)-%d]%.5s%.1000s%.5s",
      ttlp_inst.ttlp_err_hdr,
      lineno,
      strg,
      sm2,
      sm1,
      yystate,
      ((sp1 & ~0x7FF) ? -1 : sp1) /* stub to avoid printing random garbage in logs */ ,
      ((NULL == raw_text) ? "" : " at '"),
      ((NULL == raw_text) ? "" : raw_text),
      ((NULL == raw_text) ? "" : "'")
      );
}


caddr_t ttlp_strliteral (TTLP_PARAM const char *strg, int strg_is_long, char delimiter)
{
  caddr_t tmp_buf;
  caddr_t res;
  const char *err_msg;
  const char *src_tail, *src_end;
  char *tgt_tail;
  src_tail = strg + (strg_is_long ? 3 : 1);
  src_end = strg + strlen (strg) - (strg_is_long ? 3 : 1);
  tgt_tail = tmp_buf = dk_alloc_box ((src_end - src_tail) + 1, DV_SHORT_STRING);
  while (src_tail < src_end)
    {
      switch (src_tail[0])
	{
	case '\\':
          {
	    const char *bs_src		= "abfnrtv\\\'\">uU";
	    const char *bs_trans	= "\a\b\f\n\r\t\v\\\'\">\0\0";
            const char *bs_lenghts	= "\2\2\2\2\2\2\2\2\2\2\2\6\012";
	    const char *hit = strchr (bs_src, src_tail[1]);
	    char bs_len, bs_tran;
	    const char *nextchr;
	    if (NULL == hit)
	      {
		err_msg = "Unsupported escape sequence after '\'";
		goto err;
	      }
            bs_len = bs_lenghts [hit - bs_src];
            bs_tran = bs_trans [hit - bs_src];
	    nextchr = src_tail + bs_len;
	    if ((src_tail + bs_len) > src_end)
	      {
	        err_msg = "There is no place for escape sequence between '\' and the end of string";
	        goto err;
	      }
            if ('\0' != bs_tran)
              (tgt_tail++)[0] = bs_tran;
	    else
	      {
		unichar acc = 0;
		for (src_tail += 2; src_tail < nextchr; src_tail++)
		  {
		    int dgt = src_tail[0];
		    if ((dgt >= '0') && (dgt <= '9'))
		      dgt = dgt - '0';
		    else if ((dgt >= 'A') && (dgt <= 'F'))
		      dgt = 10 + dgt - 'A';
		    else if ((dgt >= 'a') && (dgt <= 'f'))
		      dgt = 10 + dgt - 'a';
		    else
		      {
		        err_msg = "Invalid hexadecimal digit in escape sequence";
			goto err;
		      }
		    acc = acc * 16 + dgt;
		  }
		if (acc < 0)
		  {
		    err_msg = "The \\U escape sequence represents invalid Unicode char";
		    goto err;
		  }
		tgt_tail = eh_encode_char__UTF8 (acc, tgt_tail, tgt_tail + MAX_UTF8_CHAR);
	      }
	    src_tail = nextchr;
            continue;
	  }
	default: (tgt_tail++)[0] = (src_tail++)[0];
	}
    }
  res = box_dv_short_nchars (tmp_buf, tgt_tail - tmp_buf);
  dk_free_box (tmp_buf);
  return res;

err:
  dk_free_box (tmp_buf);
  ttlyyerror_impl (TTLP_ARG NULL, err_msg);
  return NULL;
}

#undef ttlp_expand_qname_prefix
caddr_t DBG_NAME (ttlp_expand_qname_prefix) (DBG_PARAMS TTLP_PARAM caddr_t qname)
{
  char *lname = strchr (qname, ':');
  dk_set_t ns_dict;
  caddr_t ns_pref, ns_uri, res;
  int ns_uri_len, local_len, res_len;
  if (NULL == lname)
    {
      return qname;
    }
  lname++;
  ns_dict = ttlp_inst.ttlp_namespaces;
  ns_pref = box_dv_short_nchars (qname, lname - qname);
  ns_uri = (caddr_t) dk_set_get_keyword (ns_dict, ns_pref, NULL);
  if (NULL == ns_uri)
    {
      if (!strcmp (ns_pref, "rdf:"))
        ns_uri = box_dv_uname_string ("http://www.w3.org/1999/02/22-rdf-syntax-ns#");
      else
        {
          dk_free_box (ns_pref);
          ttlyyerror_impl (TTLP_ARG ns_pref, "Undefined namespace prefix");
        }
    }
  ns_uri_len = box_length (ns_uri) - 1;
  local_len = strlen (lname);
  res_len = ns_uri_len + local_len;
  dk_free_box (ns_pref);
#if 1
  res = DBG_NAME (dk_alloc_box) (DBG_ARGS res_len+1, DV_STRING);
  memcpy (res, ns_uri, ns_uri_len);
  memcpy (res + ns_uri_len, lname, local_len);
  res[res_len] = '\0';
  dk_free_box (qname);
  return res;
#else
  res = box_dv_ubuf (res_len);
  memcpy (res, ns_uri, ns_uri_len);
  memcpy (res + ns_uri_len, lname, local_len);
  res[res_len] = '\0';
  dk_free_box (qname);
  return box_dv_uname_from_ubuf (res);
#endif
}


void
tf_triple (triple_feed_t *tf, caddr_t s_uri, caddr_t p_uri, caddr_t o_uri)
{
  caddr_t *params;
  local_cursor_t *lc = NULL;
  caddr_t err;
  caddr_t g_uri;
  caddr_t g_iid, s_iid, p_iid, o_iid;
#ifdef DEBUG
  switch (DV_TYPE_OF (o_uri))
    {
    case DV_LONG_INT:
      rdf_dbg_printf (("\ntf_triple (%ld)", (long)(o_uri)));
    case DV_STRING: case DV_UNAME:
      rdf_dbg_printf (("\ntf_triple (%s)", o_uri));
    }
#endif
  g_uri = box_copy (tf->tf_graph_uri);
  g_iid = tf_get_iid (tf, g_uri);
  s_iid = tf_get_iid (tf, s_uri);
  p_iid = tf_get_iid (tf, p_uri);
  o_iid = tf_get_iid (tf, o_uri);
  params = (caddr_t *)list (18,
    unames_colon_number[0], g_uri,
    unames_colon_number[1], g_iid,
    unames_colon_number[2], s_uri,
    unames_colon_number[3], s_iid,
    unames_colon_number[4], p_uri,
    unames_colon_number[5], p_iid,
    unames_colon_number[6], o_uri,
    unames_colon_number[7], o_iid,
    unames_colon_number[8], box_copy_tree (tf->tf_app_env) );
  err = qr_exec (tf->tf_qi->qi_client, tf->tf_queries[TRIPLE_FEED_TRIPLE], tf->tf_qi, NULL, NULL, &lc, params, NULL, 1);
  lc_free (lc);
  dk_free_box ((box_t) params);
  if (NULL != err)
    sqlr_resignal (err);
}

void tf_triple_l (triple_feed_t *tf, caddr_t s_uri, caddr_t p_uri, caddr_t obj_sqlval, caddr_t obj_datatype, caddr_t obj_language)
{
  caddr_t *params;
  local_cursor_t *lc = NULL;
  caddr_t err;
  caddr_t g_uri;
  caddr_t g_iid, s_iid, p_iid;
  switch (DV_TYPE_OF (obj_sqlval))
    {
    case DV_LONG_INT:
      rdf_dbg_printf (("\ntf_triple_l (%ld)", (long)(obj_sqlval))); break;
    case DV_STRING: case DV_UNAME:
      rdf_dbg_printf (("\ntf_triple_l (%s, %s, %s)", obj_sqlval, obj_datatype, obj_language)); break;
    default:
      rdf_dbg_printf (("\ntf_triple_l (..., %s, %s)", obj_datatype, obj_language)); break;
    }
  g_uri = box_copy (tf->tf_graph_uri);
  g_iid = tf_get_iid (tf, g_uri);
  s_iid = tf_get_iid (tf, s_uri);
  p_iid = tf_get_iid (tf, p_uri);
  params = (caddr_t *)list (20,
    unames_colon_number[0], g_uri,
    unames_colon_number[1], g_iid,
    unames_colon_number[2], s_uri,
    unames_colon_number[3], s_iid,
    unames_colon_number[4], p_uri,
    unames_colon_number[5], p_iid,
    unames_colon_number[6], obj_sqlval,
    unames_colon_number[7], obj_datatype,
    unames_colon_number[8], obj_language,
    unames_colon_number[9], box_copy_tree (tf->tf_app_env) );
  err = qr_exec (tf->tf_qi->qi_client, tf->tf_queries[TRIPLE_FEED_TRIPLE_L], tf->tf_qi, NULL, NULL, &lc, params, NULL, 1);
  lc_free (lc);
  dk_free_box ((box_t) params);
  if (NULL != err)
    sqlr_resignal (err);
}

caddr_t
rdf_load_turtle (
  caddr_t text, caddr_t base_uri, caddr_t graph_uri, long flags,
  caddr_t *stmt_texts, caddr_t app_env,
  query_instance_t *qi, wcharset_t *query_charset, caddr_t *err_ret )
{
  bh_from_client_fwd_iter_t bcfi;
  bh_from_disk_fwd_iter_t bdfi;
  dk_session_fwd_iter_t dsfi;
  /* !!!TBD: add wide support: int text_strg_is_wide = 0; */
  dtp_t dtp_of_text = DV_TYPE_OF (text);
  caddr_t res;
  ttlp_t *ttlp;
  triple_feed_t *tf;
  if (DV_BLOB_XPER_HANDLE == dtp_of_text)
    sqlr_new_error ("42000", "SP036", "Unable to parse TURTLE from persistent XML object");
  if (!ttl_lex_mtx)
    ttl_lex_mtx = mutex_allocate ();
  mutex_enter (ttl_lex_mtx);
  ttlp = ttlp_alloc ();
  ttlp->ttlp_flags = flags;
  tf = ttlp->ttlp_tf;
  tf->tf_qi = qi;
  tf->tf_graph_uri = box_copy (graph_uri);
  tf->tf_app_env = app_env;
  if ((DV_BLOB_HANDLE == dtp_of_text) /* !!!TBD: add wide support: || (DV_BLOB_WIDE_HANDLE == dtp_of_text)*/ )
    {
      blob_handle_t *bh = (blob_handle_t *) text;
#if 0 /* !!!TBD: add wide support: */
      text_strg_is_wide = ((DV_BLOB_WIDE_HANDLE == dtp_of_text) ? 1 : 0);
#endif      
      if (bh->bh_ask_from_client)
        {
          bcfi_reset (&bcfi, bh, qi->qi_client);
          ttlp->ttlp_iter = bcfi_read;
          ttlp->ttlp_iter_abend = bcfi_abend;
          ttlp->ttlp_iter_data = &bcfi;
	  goto iter_is_set;
        }
      bdfi_reset (&bdfi, bh, qi);
      ttlp->ttlp_iter = bdfi_read;
      ttlp->ttlp_iter_data = &bdfi;
      goto iter_is_set;
    }
  if (DV_STRING_SESSION == dtp_of_text)
    {
      dk_session_t *ses = (dk_session_t *) text;
      dsfi_reset (&dsfi, ses);
      ttlp->ttlp_iter = dsfi_read;
      ttlp->ttlp_iter_data = &dsfi;
      goto iter_is_set;
    }
#if 0 /* !!!TBD: add wide support: */
   if (IS_WIDE_STRING_DTP (dtp_of_text))
    {
      text_len = (s_size_t) (box_length(text)-sizeof(wchar_t));
      text_strg_is_wide = 1;
      goto iter_is_set;
    }
#endif
  if (IS_STRING_DTP (dtp_of_text))
    {
      ttlp->ttlp_text = text;
      ttlp->ttlp_text_len = box_length(text) - 1;
      goto iter_is_set;
    }
  mutex_leave (ttl_lex_mtx);
  ttlp_free (ttlp);
  sqlr_new_error ("42000", "SP037",
    "Unable to parse TURTLE from data of type %s (%d)", dv_type_title (dtp_of_text), dtp_of_text);

iter_is_set:
  ttlp->ttlp_err_hdr = "TURTLE RDF loader";
  if (NULL == query_charset)
    query_charset = default_charset;
  if (NULL == query_charset)
    ttlp->ttlp_enc = &eh__ISO8859_1;
  else
    {
      ttlp->ttlp_enc = eh_get_handler (CHARSET_NAME (query_charset, NULL));
      if (NULL == ttlp->ttlp_enc)
        ttlp->ttlp_enc = &eh__ISO8859_1;
    }
  ttlp->ttlp_base_uri = box_copy (base_uri);
  QR_RESET_CTX
    {
      tf_set_stmt_texts (tf, (const char **)stmt_texts, NULL);
      ttlyy_reset ();
      ttlyyparse();
    }
  QR_RESET_CODE
    {
      du_thread_t *self = THREAD_CURRENT_THREAD;
      ttlp->ttlp_catched_error = thr_get_error_code (self);
      thr_set_error_code (self, NULL);
      if (NULL != ttlp->ttlp_iter_abend)
        {
          ttlp->ttlp_iter_abend (ttlp->ttlp_iter_data);
          ttlp->ttlp_iter_abend = NULL;
        }
      /*no POP_QR_RESET*/;
    }
  END_QR_RESET
  mutex_leave (ttl_lex_mtx);
  err_ret[0] = ttlp->ttlp_catched_error;
  ttlp->ttlp_catched_error = NULL;
  res = ttlp->ttlp_tf->tf_graph_uri;
  ttlp->ttlp_tf->tf_graph_uri = NULL;
  ttlp_free (ttlp);
  return res;
}

caddr_t
bif_rdf_load_turtle (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t str = bif_string_or_wide_or_null_or_strses_arg (qst, args, 0, "rdf_load_turtle");
  caddr_t base_uri = bif_string_or_wide_or_uname_arg (qst, args, 1, "rdf_load_turtle");
  caddr_t graph_uri = bif_string_or_wide_or_uname_arg (qst, args, 2, "rdf_load_turtle");
  long flags = bif_long_arg (qst, args, 3, "rdf_load_turtle");
  caddr_t *stmt_texts = bif_strict_type_array_arg (DV_STRING, qst, args, 4, "rdf_load_turtle");
  caddr_t app_env = bif_arg (qst, args, 5, "rdf_load_turtle");
  caddr_t err = NULL;
  caddr_t res;
  if (COUNTOF__TRIPLE_FEED != BOX_ELEMENTS (stmt_texts))
    sqlr_new_error ("22023", "RDF01",
      "The argument #4 of rdf_load_turtle() should be a vector of %d texts of SQL statements",
      COUNTOF__TRIPLE_FEED );
  res = rdf_load_turtle (str, base_uri, graph_uri, flags,
    stmt_texts, app_env,
    (query_instance_t *)qst, QST_CHARSET(qst), &err );
  if (NULL != err)
    {
      dk_free_tree (res);
      sqlr_resignal (err);
    }
  return res;
}



caddr_t
bif_turtle_lex_analyze (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t str = bif_string_arg (qst, args, 0, "turtle_lex_analyze");
  return ttl_query_lex_analyze (str, QST_CHARSET(qst));
}

#ifdef DEBUG

typedef struct ttl_lexem_descr_s
{
  int ld_val;
  const char *ld_yname;
  char ld_fmttype;
  const char * ld_fmt;
  caddr_t *ld_tests;
} ttl_lexem_descr_t;

ttl_lexem_descr_t ttl_lexem_descrs[__TTL_NONPUNCT_END+1];

#define LEX_PROPS ttl_lex_props
#define PUNCT(x) 'P', (x)
#define LITERAL(x) 'L', (x)
#define FAKE(x) 'F', (x)
#define TTL "s"

#define LAST(x) "L", (x)
#define LAST1(x) "K", (x)
#define MISS(x) "M", (x)
#define ERR(x)  "E", (x)

#define PUNCT_TTL_LAST(x) PUNCT(x), TTL, LAST(x)


static void ttl_lex_props (int val, const char *yname, char fmttype, const char *fmt, ...)
{
  va_list tail;
  const char *cmd;
  dk_set_t tests = NULL;
  ttl_lexem_descr_t *ld = ttl_lexem_descrs + val;
  if (0 != ld->ld_val)
    GPF_T;
  ld->ld_val = val;
  ld->ld_yname = yname;
  ld->ld_fmttype = fmttype;
  ld->ld_fmt = fmt;
  va_start (tail, fmt);
  for (;;)
    {
      cmd = va_arg (tail, const char *);
      if (NULL == cmd)
	break;
      dk_set_push (&tests, box_dv_short_string (cmd));
    }
  va_end (tail);
  ld->ld_tests = (caddr_t *)revlist_to_array (tests);
}

static void ttl_lexem_descrs_fill (void)
{
  static int first_run = 1;
  if (!first_run)
    return;
  first_run = 0;
  #include "turtle_lex_props.c"
}

caddr_t
bif_turtle_lex_test (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  dk_set_t report = NULL;
  int tested_lex_val = 0;
  ttl_lexem_descrs_fill ();
  for (tested_lex_val = 0; tested_lex_val < __TTL_NONPUNCT_END; tested_lex_val++)
    {
      char cmd;
      caddr_t **lexems;
      unsigned lex_count;
      unsigned cmd_idx = 0;
      int last_lval, last1_lval;
      ttl_lexem_descr_t *ld = ttl_lexem_descrs + tested_lex_val;
      if (0 == ld->ld_val)
	continue;
      dk_set_push (&report, box_dv_short_string (""));
      dk_set_push (&report,
        box_sprintf (0x100, "#define % 25s %d /* '%s' (%c) */",
	  ld->ld_yname, ld->ld_val, ld->ld_fmt, ld->ld_fmttype ) );
      for (cmd_idx = 0; cmd_idx < BOX_ELEMENTS(ld->ld_tests); cmd_idx++)
	{
	  cmd = ld->ld_tests[cmd_idx][0];
	  switch (cmd)
	    {
	    case 's': break;	/* Fake, TURTLE has only one mode */
	    case 'K': case 'L': case 'M': case 'E':
	      cmd_idx++;
	      lexems = (caddr_t **) ttl_query_lex_analyze (ld->ld_tests[cmd_idx], QST_CHARSET(qst));
	      dk_set_push (&report, box_dv_short_string (ld->ld_tests[cmd_idx]));
	      lex_count = BOX_ELEMENTS (lexems);
	      if (0 == lex_count)
		{
		  dk_set_push (&report, box_dv_short_string ("FAILED: no lexems parsed and no error reported!"));
		  goto end_of_test;
		}
	      { char buf[0x1000]; char *buf_tail = buf;
	        unsigned lctr = 0;
		for (lctr = 0; lctr < lex_count && (5 == BOX_ELEMENTS(lexems[lctr])); lctr++)
		  {
		    ptrlong *ldata = ((ptrlong *)(lexems[lctr]));
		    int lval = ldata[3];
		    ttl_lexem_descr_t *ld = ttl_lexem_descrs + lval;
		    if (ld->ld_val)
		      buf_tail += sprintf (buf_tail, " %s", ld->ld_yname);
		    else if (lval < 0x100)
		      buf_tail += sprintf (buf_tail, " '%c'", lval);
		    else GPF_T;
		    buf_tail += sprintf (buf_tail, " %ld ", (long)(ldata[4]));
		  }
	        buf_tail[0] = '\0';
		dk_set_push (&report, box_dv_short_string (buf));
	      }
	      if (3 == BOX_ELEMENTS(lexems[lex_count-1])) /* lexical error */
		{
		  dk_set_push (&report,
		    box_sprintf (0x1000, "%s: ERROR %s",
		      ('E' == cmd) ? "PASSED": "FAILED", lexems[lex_count-1][2] ) );
		  goto end_of_test;
		}
/*
	      if (END_OF_TURTLE_TEXT != ((ptrlong *)(lexems[lex_count-1]))[3])
		{
		  dk_set_push (&report, box_dv_short_string ("FAILED: end of source is not reached and no error reported!"));
		  goto end_of_test;
		}
*/
	      if (0 /*1*/ == lex_count)
		{
		  dk_set_push (&report, box_dv_short_string ("FAILED: no lexems parsed and only end of source has found!"));
		  goto end_of_test;
		}
	      last_lval = ((ptrlong *)(lexems[lex_count-/*2*/1]))[3];
	      if ('E' == cmd)
		{
		  dk_set_push (&report,
		    box_sprintf (0x1000, "FAILED: %d lexems found, last lexem is %d, must be error",
		      lex_count, last_lval) );
		  goto end_of_test;
		}
	      if ('K' == cmd)
		{
		  if (/*4*/2 > lex_count)
		    {
		      dk_set_push (&report,
			box_sprintf (0x1000, "FAILED: %d lexems found, the number of actual lexems is less than two",
			  lex_count ) );
		      goto end_of_test;
		    }
		  last1_lval = ((ptrlong *)(lexems[lex_count-/*3*/2]))[3];
		  dk_set_push (&report,
		    box_sprintf (0x1000, "%s: %d lexems found, one-before-last lexem is %d, must be %d",
		      (last1_lval == tested_lex_val) ? "PASSED": "FAILED", lex_count, last1_lval, tested_lex_val) );
		  goto end_of_test;
		}
	      if ('L' == cmd)
		{
		  dk_set_push (&report,
		    box_sprintf (0x1000, "%s: %d lexems found, last lexem is %d, must be %d",
		      (last_lval == tested_lex_val) ? "PASSED": "FAILED", lex_count, last_lval, tested_lex_val) );
		  goto end_of_test;
		}
	      if ('M' == cmd)
		{
		  unsigned lctr;
		  for (lctr = 0; lctr < lex_count; lctr++)
		    {
		      int lval = ((ptrlong *)(lexems[lctr]))[3];
		      if (lval == tested_lex_val)
			{
			  dk_set_push (&report,
			    box_sprintf (0x1000, "FAILED: %d lexems found, lexem %d is found but it should not occur",
			      lex_count, tested_lex_val) );
			  goto end_of_test;
			}
		    }
		  dk_set_push (&report,
		    box_sprintf (0x1000, "PASSED: %d lexems found, lexem %d is not found and it should not occur",
		      lex_count, tested_lex_val) );
		  goto end_of_test;
		}
	      GPF_T;
end_of_test:
	      dk_free_tree (lexems);
	      break;		
	    default: GPF_T;
	    }
	  }
    }
  return revlist_to_array (report);
}
#endif


#undef tf_bnode_iid
caddr_t DBG_NAME (tf_bnode_iid) (DBG_PARAMS triple_feed_t *tf, const char *txt)
{
  caddr_t *params;
  local_cursor_t *lc = NULL;
  caddr_t *hit;
  caddr_t err = NULL;
  if (NULL != txt)
    {
      hit = (caddr_t *)id_hash_get (tf->tf_blank_node_ids, (caddr_t)(&(txt)));
      if (NULL != hit)
        return box_copy_tree (hit[0]);
    }
  params = (caddr_t *)list (4,
    unames_colon_number[0],
    box_copy (tf->tf_graph_uri),
    unames_colon_number[1],
    box_copy_tree (tf->tf_app_env) );
  err = qr_exec (tf->tf_qi->qi_client, tf->tf_queries[TRIPLE_FEED_NEW_BLANK], tf->tf_qi, NULL, NULL, &lc, params, NULL, 1);
  dk_free_box ((box_t) params);
  if (NULL != err)
    {
      lc_free (lc);
      sqlr_resignal (err);
    }
  if (lc && lc_next (lc))
    {
      caddr_t iid = DBG_NAME (box_copy_tree) (DBG_ARGS lc_nth_col (lc, 0));
      if (NULL != txt)
        {
          caddr_t key = box_dv_short_string (txt);
          id_hash_set (tf->tf_blank_node_ids, (caddr_t)(&key), (caddr_t)(&iid));
          iid = DBG_NAME (box_copy_tree) (DBG_ARGS iid);
        }
      lc_free (lc);
      return iid;
    }
  lc_free (lc);
  sqlr_new_error ("22023", "RDF03",
    "RDF loader has failed to create ID for blank node '%.100s' by '%.100s'",
    ((NULL == txt) ? "[]" : txt), tf->tf_stmt_texts[TRIPLE_FEED_NEW_BLANK] );
  return NULL;
}


void
rdf_core_init (void)
{
  bif_define_typed ("rdf_load_rdfxml", bif_rdf_load_rdfxml, &bt_xml_entity);
  bif_set_uses_index (bif_rdf_load_rdfxml);
  bif_define ("rdf_load_turtle", bif_rdf_load_turtle);
  bif_set_uses_index (bif_rdf_load_turtle);
  bif_define ("turtle_lex_analyze", bif_turtle_lex_analyze);
#ifdef DEBUG
  bif_define ("turtle_lex_test", bif_turtle_lex_test);
#endif
}
