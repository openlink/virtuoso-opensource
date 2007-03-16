/*
 *  $Id$
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
  return tf;
}


void
tf_free (triple_feed_t *tf)
{
  int ctr;
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
  id_hash_free (tf->tf_blank_node_ids);
  for (ctr = 0; ctr < COUNTOF__TRIPLE_FEED; ctr++)
    {
      if (tf->tf_queries[ctr])
	qr_free (tf->tf_queries[ctr]);
    }
  dk_free_tree (tf->tf_graph_iid);
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
  caddr_t err = NULL;
  if ((DV_STRING != uri_dtp) && (DV_UNAME != uri_dtp))
    return box_copy_tree (uri);
  params = (caddr_t *)list (6,
    unames_colon_number[0],
    box_copy (uri),
    unames_colon_number[1],
    box_copy (tf->tf_graph_iid),
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
      lc_free (lc);
      return iid;
    }
  lc_free (lc);
  sqlr_new_error ("22023", "RDF02",
    "RDF loader has failed to create ID for URI '%.100s' by '%.100s'",
    uri, tf->tf_stmt_texts[TRIPLE_FEED_GET_IID] );
  return NULL;
}


void
tf_commit (triple_feed_t *tf)
{
  caddr_t *params;
  caddr_t err = NULL;
  params = (caddr_t *)list (0);
  err = qr_exec (tf->tf_qi->qi_client, tf->tf_queries[TRIPLE_FEED_COMMIT], tf->tf_qi, NULL, NULL, NULL, params, NULL, 1);
  dk_free_box ((box_t) params);
  if (NULL != err)
    sqlr_resignal (err);
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
  dk_free_tree (ttlp->ttlp_tf->tf_graph_uri);
  tf_free (ttlp->ttlp_tf);
  while (NULL != ttlp->ttlp_namespaces)
    dk_free_tree ((box_t) dk_set_pop (&(ttlp->ttlp_namespaces)));
  while (NULL != ttlp->ttlp_saved_uris)
    dk_free_tree ((box_t) dk_set_pop (&(ttlp->ttlp_saved_uris)));
  dk_free_tree (ttlp->ttlp_base_uri);
  dk_free_tree (ttlp->ttlp_subj_uri);
  dk_free_tree (ttlp->ttlp_pred_uri);
  dk_free_tree (ttlp->ttlp_formula_iid);
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
            const char *bs_lengths	= "\2\2\2\2\2\2\2\2\2\2\2\6\012";
	    const char *hit = strchr (bs_src, src_tail[1]);
	    char bs_len, bs_tran;
	    const char *nextchr;
	    if (NULL == hit)
	      {
		err_msg = "Unsupported escape sequence after '\'";
		goto err;
	      }
            bs_len = bs_lengths [hit - bs_src];
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

ptrlong
ttlp_bit_of_special_qname (caddr_t qname)
{
  if (!strcmp (qname, "a"))	return TTLP_ALLOW_QNAME_A;
  if (!strcmp (qname, "has"))	return TTLP_ALLOW_QNAME_HAS;
  if (!strcmp (qname, "is"))	return TTLP_ALLOW_QNAME_IS;
  if (!strcmp (qname, "of"))	return TTLP_ALLOW_QNAME_OF;
  if (!strcmp (qname, "this"))	return TTLP_ALLOW_QNAME_THIS;
  return 0;
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
      lname = qname;
      ns_uri = ttlp_inst.ttlp_default_ns_uri;
      if (NULL == ns_uri)
        {
          ns_uri = "#";
          ns_uri_len = 1;
          goto ns_uri_found; /* see below */
        }
      ns_uri_len = box_length (ns_uri) - 1;
      goto ns_uri_found; /* see below */
    }
  if (qname == lname)
    {
      lname = qname + 1;
      ns_uri = ttlp_inst.ttlp_default_ns_uri;
      if (NULL == ns_uri)
        {
/* TimBL's sample:
The empty prefix "" is by default , bound to the empty URI "". 
this means that <#foo> can be written :foo and using @keywords one can reduce that to foo
*/
#if 0
          res = box_dv_short_nchars (qname + 1, box_length (qname) - 2);
          dk_free_box (qname);
          return res;
#else
          if (DV_STRING == DV_TYPE_OF (qname))
            {
	      qname[0] = '#';
      return qname;
    }
          ns_uri = "#";
          ns_uri_len = 1;
          goto ns_uri_found; /* see below */
#endif
        }
      ns_uri_len = box_length (ns_uri) - 1;
      goto ns_uri_found; /* see below */
    }
  lname++;
  ns_dict = ttlp_inst.ttlp_namespaces;
  ns_pref = box_dv_short_nchars (qname, lname - qname);
  ns_uri = (caddr_t) dk_set_get_keyword (ns_dict, ns_pref, NULL);
  if (NULL == ns_uri)
    {
      if (!strcmp (ns_pref, "rdf:"))
        ns_uri = uname_rdf_ns_uri;
      else if (!strcmp (ns_pref, "xsd:"))
        ns_uri = uname_xmlschema_ns_uri_hash;
      else if (!strcmp (ns_pref, "virtrdf:"))
        ns_uri = uname_virtrdf_ns_uri;
      else
        {
          dk_free_box (ns_pref);
          ttlyyerror_impl (TTLP_ARG qname, "Undefined namespace prefix");
        }
    }
  dk_free_box (ns_pref);
  ns_uri_len = box_length (ns_uri) - 1;

ns_uri_found:
  local_len = strlen (lname);
  res_len = ns_uri_len + local_len;
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

caddr_t
ttlp_uri_resolve (TTLP_PARAM caddr_t qname)
{
  query_instance_t *qi = ttlp_inst.ttlp_tf->tf_qi;
  caddr_t res, err = NULL;
  res = xml_uri_resolve_like_get (qi, &err, ttlp_inst.ttlp_base_uri, qname, "UTF-8");
  dk_free_box (qname);
  if (NULL != err)
    sqlr_resignal (err);
  return res;
}

void
ttlp_triple_and_inf (TTLP_PARAM caddr_t o_uri)
{
  triple_feed_t *tf = ttlp_inst.ttlp_tf;
  caddr_t s = ttlp_inst.ttlp_subj_uri;
  caddr_t p = ttlp_inst.ttlp_pred_uri;
  caddr_t o = o_uri;
  if (NULL == s)
    return;
  if (ttlp_inst.ttlp_pred_is_reverse)
    {
      caddr_t swap = o;
      o = s;
      s = swap;
    }
  if (ttlp_inst.ttlp_formula_iid)
    {
      caddr_t stmt = tf_bnode_iid (tf, NULL);
      tf_triple (tf, box_copy (stmt), uname_rdf_ns_uri_subject, box_copy (s));
      tf_triple (tf, box_copy (stmt), uname_rdf_ns_uri_predicate, box_copy (p));
      tf_triple (tf, box_copy (stmt), uname_rdf_ns_uri_object, box_copy (o));
      tf_triple (tf, box_copy (stmt), uname_rdf_ns_uri_type, uname_rdf_ns_uri_Statement);
      tf_triple (tf, box_copy (ttlp_inst.ttlp_formula_iid), uname_swap_reify_ns_uri_statement, stmt);
    }
  if (ttlp_inst.ttlp_pred_is_reverse)
    o = box_copy (o);
  else
    s = box_copy (s);
  tf_triple (tf, s, box_copy (p), o);
}

extern void ttlp_triple_l_and_inf (TTLP_PARAM caddr_t o_sqlval, caddr_t o_dt, caddr_t o_lang)
{
  triple_feed_t *tf = ttlp_inst.ttlp_tf;
  caddr_t s = ttlp_inst.ttlp_subj_uri;
  caddr_t p = ttlp_inst.ttlp_pred_uri;
  if (NULL == s)
    return;
  if (ttlp_inst.ttlp_pred_is_reverse)
    {
      if (!(ttlp_inst.ttlp_flags & TTLP_SKIP_LITERAL_SUBJECTS))
        ttlyyerror_impl (TTLP_ARG "", "Virtuoso does not support literal subjects");
      if (ttlp_inst.ttlp_formula_iid)
        {
          caddr_t stmt = tf_bnode_iid (tf, NULL);
          tf_triple_l (tf, box_copy (stmt), uname_rdf_ns_uri_subject, o_sqlval, o_dt, o_lang);
          tf_triple (tf, box_copy (stmt), uname_rdf_ns_uri_predicate, box_copy (p));
          tf_triple (tf, box_copy (stmt), uname_rdf_ns_uri_object, box_copy (s));
          tf_triple (tf, box_copy (stmt), uname_rdf_ns_uri_type, uname_rdf_ns_uri_Statement);
          tf_triple (tf, box_copy (ttlp_inst.ttlp_formula_iid), uname_swap_reify_ns_uri_statement, stmt);
        }
      return;
    }
  if (ttlp_inst.ttlp_formula_iid)
    {
      caddr_t stmt = tf_bnode_iid (tf, NULL);
      tf_triple (tf, box_copy (stmt), uname_rdf_ns_uri_subject, box_copy (s));
      tf_triple (tf, box_copy (stmt), uname_rdf_ns_uri_predicate, box_copy (p));
      tf_triple_l (tf, box_copy (stmt), uname_rdf_ns_uri_object, box_copy (o_sqlval), box_copy (o_dt), box_copy (o_lang));
      tf_triple (tf, box_copy (stmt), uname_rdf_ns_uri_type, uname_rdf_ns_uri_Statement);
      tf_triple (tf, box_copy (ttlp_inst.ttlp_formula_iid), uname_swap_reify_ns_uri_statement, stmt);
    }
  tf_triple_l (ttlp_inst.ttlp_tf, box_copy (s), box_copy (p), o_sqlval, o_dt, o_lang);
}


void
tf_triple (triple_feed_t *tf, caddr_t s_uri, caddr_t p_uri, caddr_t o_uri)
{
  caddr_t *params;
  local_cursor_t *lc = NULL;
  caddr_t err;
#ifdef DEBUG
  switch (DV_TYPE_OF (o_uri))
    {
    case DV_LONG_INT:
      rdf_dbg_printf (("\ntf_triple (%ld)", (long)(o_uri)));
    case DV_STRING: case DV_UNAME:
      rdf_dbg_printf (("\ntf_triple (%s)", o_uri));
    }
#endif
  params = (caddr_t *)list (10,
    unames_colon_number[0], box_copy (tf->tf_graph_iid),
    unames_colon_number[1], s_uri,
    unames_colon_number[2], p_uri,
    unames_colon_number[3], o_uri,
    unames_colon_number[4], box_copy_tree (tf->tf_app_env) );
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
  switch (DV_TYPE_OF (obj_sqlval))
    {
    case DV_LONG_INT:
      rdf_dbg_printf (("\ntf_triple_l (%ld)", (long)(obj_sqlval))); break;
    case DV_STRING: case DV_UNAME:
      rdf_dbg_printf (("\ntf_triple_l (%s, %s, %s)", obj_sqlval, obj_datatype, obj_language)); break;
    default:
      rdf_dbg_printf (("\ntf_triple_l (..., %s, %s)", obj_datatype, obj_language)); break;
    }
  params = (caddr_t *)list (14,
    unames_colon_number[0], box_copy (tf->tf_graph_iid),
    unames_colon_number[1], s_uri,
    unames_colon_number[2], p_uri,
    unames_colon_number[3], obj_sqlval,
    unames_colon_number[4], obj_datatype,
    unames_colon_number[5], obj_language,
    unames_colon_number[6], box_copy_tree (tf->tf_app_env) );
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
  if (box_length (base_uri) > 1)
  ttlp->ttlp_base_uri = box_copy (base_uri);
  QR_RESET_CTX
    {
      tf_set_stmt_texts (tf, (const char **)stmt_texts, NULL);
      tf->tf_graph_iid = tf_get_iid (tf, tf->tf_graph_uri);
      tf_commit (tf);
      ttlyy_reset ();
      ttlyyparse();
      tf_commit (tf);
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
  caddr_t base_uri = bif_string_or_uname_arg (qst, args, 1, "rdf_load_turtle");
  caddr_t graph_uri = bif_string_or_uname_or_wide_or_null_arg (qst, args, 2, "rdf_load_turtle");
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


typedef struct name_id_cache_s 
{
  dk_mutex_t *	nic_mtx;
  dk_hash_t *	nic_id_to_name;
  id_hash_t *	nic_name_to_id;
  unsigned long	nic_size;
} name_id_cache_t;


void
nic_set (name_id_cache_t * nic, caddr_t name, ptrlong id)
{
  caddr_t name_box = NULL;
  caddr_t * place;
  mutex_enter (nic->nic_mtx);
  place = (caddr_t*) id_hash_get (nic->nic_name_to_id, (caddr_t)&name);
  if(place)
    {
      ptrlong old_id = *(ptrlong*)place;
      name_box = ((caddr_t*)place) [-1];
      *(ptrlong*) place = id;
      remhash ((void*)old_id, nic->nic_id_to_name);
      sethash ((void*)id, nic->nic_id_to_name,  (void*) name_box);
    }
  else 
    {
      while (nic->nic_id_to_name->ht_count > nic->nic_size)
	{
	  caddr_t key;
	  ptrlong id;
	  int32 rnd  = sqlbif_rnd (&tf_rnd_seed);
	  if (id_hash_remove_rnd (nic->nic_name_to_id, rnd, (caddr_t)&key, (caddr_t)&id))
	    {
	      remhash ((void*) id, nic->nic_id_to_name);
	      dk_free_box (key);
	    }
	}
      name_box = treehash == nic->nic_name_to_id->ht_hash_func  ? box_copy (name) :  box_dv_short_string (name);
      id_hash_set (nic->nic_name_to_id, (caddr_t)&name_box, (caddr_t)&id);
      sethash ((void*)id, nic->nic_id_to_name, (void*) name_box);
    }
  mutex_leave (nic->nic_mtx);
}


ptrlong
nic_name_id (name_id_cache_t * nic, char * name)
{
  ptrlong * place, res = 0;
  mutex_enter (nic->nic_mtx);
  place = (ptrlong*) id_hash_get (nic->nic_name_to_id, (caddr_t) &name);
  if (place)
    res = *place;
  mutex_leave (nic->nic_mtx);
  return res;
}


caddr_t 
nic_id_name (name_id_cache_t * nic, ptrlong id)
{
  caddr_t res;
  mutex_enter (nic->nic_mtx);
  res = (caddr_t) gethash ((void*)id, nic->nic_id_to_name);
  mutex_leave(nic->nic_mtx);
  return res ? box_copy (res) : NULL;
}

name_id_cache_t *
nic_allocate (unsigned long sz, int is_box)
{
  NEW_VARZ (name_id_cache_t, nic);
  nic->nic_size = sz;
  if (!is_box)
    nic->nic_name_to_id = id_hash_allocate (sz / 3, sizeof (caddr_t), sizeof (ptrlong), strhash, strhashcmp);
  else
    nic->nic_name_to_id = id_hash_allocate (sz / 3, sizeof (caddr_t), sizeof (ptrlong), treehash, treehashcmp);
  nic->nic_id_to_name = hash_table_allocate (sz / 3);
  nic->nic_mtx =mutex_allocate ();
  mutex_option (nic->nic_mtx, is_box ? "NICB" : "NIC", NULL, NULL);
  return nic;
}

void
nic_flush (name_id_cache_t * nic)
{
  caddr_t name_box = NULL;
  int bucket_ctr = 0;
  mutex_enter (nic->nic_mtx);
  for (bucket_ctr = nic->nic_name_to_id->ht_buckets; bucket_ctr--; /* no step */)
    {
      caddr_t key;
      ptrlong id;
      while (id_hash_remove_rnd (nic->nic_name_to_id, bucket_ctr, (caddr_t)&key, (caddr_t)&id))
        {
          remhash ((void*) id, nic->nic_id_to_name);
          dk_free_box (key);
        }
    }
  mutex_leave (nic->nic_mtx);
}

void
tb_string_and_int_for_insert (dbe_key_t * key, db_buf_t image, it_cursor_t * ins_itc, caddr_t string, caddr_t id)
{
  /* two values.  string and iri/int or the other way around */
  caddr_t err = NULL;
  int v_fill = key->key_row_var_start;
  SHORT_SET (image +IE_KEY_ID, key->key_id);
  SHORT_SET (image +IE_NEXT_IE, 0);
  row_set_col (&image[IE_FIRST_KEY], key->key_key_var->cl_col_id ? key->key_key_var : key->key_row_var, string, &v_fill, ROW_MAX_DATA,
	       key, &err, ins_itc, (db_buf_t) "\000", NULL);
  if (err)
    goto err;
  row_set_col (&image[IE_FIRST_KEY], key->key_row_fixed->cl_col_id ? key->key_row_fixed : key->key_key_fixed, id, &v_fill, ROW_MAX_DATA,
	       key, &err, ins_itc, (db_buf_t) "\000", NULL);
  if (err)
    goto err;
  return;
 err:
  itc_free (ins_itc);
  sqlr_resignal (err);
}

#define IS_INT_LIKE(x) ((x) == DV_LONG_INT || (x) == DV_IRI_ID || (x) == DV_IRI_ID_8)


int
tb_string_and_id_check (dbe_table_t * tb, dbe_column_t ** str_col, dbe_column_t ** id_col)
{
  /* true if tb has string pk andint dependent and another key withthe reverse */
  dbe_key_t * pk = tb->tb_primary_key;
  dbe_column_t * col1 = (dbe_column_t *) pk->key_parts->data;
  dbe_column_t * col2 = pk->key_parts->next ? (dbe_column_t *) pk->key_parts->next->data : NULL;
  if (!col2
      || col1->col_sqt.sqt_dtp != DV_STRING
      || (! IS_INT_LIKE (col2->col_sqt.sqt_dtp))
      || !tb->tb_keys->next
      || tb->tb_keys->next->next)
  return 0;
  *str_col = col1;
  *id_col = col2;
  return 1;
}


extern dk_mutex_t * log_write_mtx;

caddr_t 
tb_new_id_and_name (lock_trx_t * lt, it_cursor_t * itc, dbe_table_t * tb, caddr_t name, char * value_seq_name)
{
  int rc;
  caddr_t log_array;
  dbe_key_t * id_key = (dbe_key_t *)(tb->tb_keys->data == tb->tb_primary_key ? tb->tb_keys->next->data : tb->tb_keys->data);
  caddr_t seq_box = box_dv_short_string (value_seq_name);
  int64 res = sequence_next_inc (seq_box, OUTSIDE_MAP, 1);
  dbe_column_t * id_col = (dbe_column_t *)id_key->key_parts->data;
  caddr_t res_box = box_iri_int64 (res, id_col->col_sqt.sqt_dtp);
  dtp_t pk_image[MAX_ROW_BYTES];
  dtp_t sk_image[MAX_ROW_BYTES];
  dk_free_box (seq_box);
  tb_string_and_int_for_insert (tb->tb_primary_key, pk_image, itc, name, res_box);
  itc->itc_insert_key = tb->tb_primary_key;
  itc->itc_owned_search_par_fill= 0; /* do not free the name yet */
  itc_from (itc, itc->itc_insert_key);
  ITC_SEARCH_PARAM(itc, name);
  ITC_OWNS_PARAM(itc, name);
  itc->itc_key_spec = itc->itc_insert_key->key_insert_spec;
  itc_insert_unq_ck (itc, pk_image, NULL);
  tb_string_and_int_for_insert (id_key, sk_image, itc, name, res_box);
  itc->itc_insert_key = id_key;
  itc->itc_owned_search_par_fill = 0; /* do not free the name yet */
  itc_from (itc, itc->itc_insert_key);
  ITC_SEARCH_PARAM(itc, res_box);
  ITC_SEARCH_PARAM(itc, name);
  ITC_OWNS_PARAM (itc, name);
  itc->itc_key_spec = itc->itc_insert_key->key_insert_spec;

  itc_insert_unq_ck (itc, sk_image, NULL);
  log_array = list (5, box_string ("DB.DBA.ID_REPLAY (?, ?, ?, ?)"),
		    box_dv_short_string (tb->tb_name), box_dv_short_string (value_seq_name), box_copy (name), box_copy (res_box));
  mutex_enter (log_write_mtx);
  rc = log_text_array_sync (lt, log_array);
  mutex_leave (log_write_mtx);
  dk_free_tree (log_array);
  if (rc != LTE_OK)
    {
static caddr_t details = NULL;
      if (NULL == details)
        details = box_dv_short_string ("while writing new IRI_ID allocation to log file");
/*      if (lt->lt_client != bootstrap_cli) */
      sqlr_resignal (srv_make_trx_error (rc, details));
    }
  lt_no_rb_insert (lt, pk_image);
  lt_no_rb_insert (lt, sk_image);
  return res_box;
}



caddr_t 
tb_name_to_id (lock_trx_t * lt, char * tb_name, caddr_t name, char * value_seq_name)
{
  /* the name param is freed */
  int res, rc;
  caddr_t iri = NULL;
  dbe_table_t * tb = sch_name_to_table (wi_inst.wi_schema, tb_name);
  dbe_key_t * key = tb ? tb->tb_primary_key : NULL;
  dbe_column_t * iri_col = key && key->key_parts && key->key_parts->next ? key->key_parts->next->data : NULL;
  it_cursor_t itc_auto;
  it_cursor_t * itc = &itc_auto;
  buffer_desc_t * buf;
  dbe_column_t *str_col, *id_col;
  if (!iri_col)
    return NULL;
  if (!tb_string_and_id_check (tb, &str_col, &id_col))
    return NULL;
  ITC_INIT (itc, key->key_fragments[0]->kf_it, NULL);
  itc->itc_ltrx = lt;
  itc_from (itc, key);
  ITC_SEARCH_PARAM (itc, name);
  ITC_OWNS_PARAM(itc, name);
  if(lt)
    itc->itc_isolation =ISO_COMMITTED;
  else
    itc->itc_isolation = ISO_UNCOMMITTED;
  itc->itc_search_mode = SM_INSERT;
  itc->itc_key_spec = key->key_insert_spec;
  ITC_FAIL (itc)
    {
re_search:
      buf = itc_reset (itc);
      res = itc_search (itc, &buf);
      if (DVC_MATCH == res)
	{
	  iri = itc_box_column (itc, buf->bd_buffer, iri_col->col_id, NULL);
	  itc_page_leave (itc, buf);
	}
      else if (NULL == value_seq_name)
        {
           iri = 0;
           itc_page_leave (itc, buf);
        }
      else
	{
	  itc->itc_isolation = ISO_SERIALIZABLE;
          itc->itc_lock_mode = PL_EXCLUSIVE;
          itc->itc_search_mode = SM_READ;
	  if (!itc->itc_position)
	    rc = NO_WAIT;
	  else
	    rc = itc_set_lock_on_row (itc, &buf);
	  if(NO_WAIT != rc)
	    {
	      itc_page_leave(itc, buf);
	      goto re_search; /* see above */
	    }
	  itc_page_leave (itc, buf);
          iri = tb_new_id_and_name (lt, itc, tb, name, value_seq_name);
	}
    }
  ITC_FAILED
      {
	itc_free (itc);
	return NULL;
      }
  END_FAIL (itc);
  itc_free (itc);
  return iri;
}


caddr_t 
box_n_chars (char * str, int len)
{
  caddr_t res = dk_alloc_box (len + 1, DV_STRING);
  memcpy (res, str, len);
  res[len] = 0;
  return res;
}

int 
iri_split (char * iri, caddr_t * pref, caddr_t * name)
{
  char * local_start = strrchr (iri, '#');
  int len = strlen (iri);
  if (len > MAX_RULING_PART_BYTES - 20)
    return 0;
  if (!local_start)
    local_start = strrchr (iri, '?');
  if (!local_start)
    {
      /* first / that is not // */
      char * ptr =iri;
      char * s;
      for (;;)
	{
	  s = strchr (ptr, '/');
	  if (!s)
	    break;
	  if ('/' != s[1])
	    break;
	  ptr = s + 2;
	}
      if (!s)
	local_start = iri;
      else 
	local_start = s + 1;
    }
  else 
    local_start++;
  *pref = box_n_chars (iri, local_start - iri);
  *name = box_n_chars (local_start - 4, 4 + strlen (local_start));
  return 1;
}


name_id_cache_t * iri_name_cache;
name_id_cache_t * iri_prefix_cache;


caddr_t
key_name_to_iri_id (lock_trx_t * lt, caddr_t name, int make_new)
{
  ptrlong pref_id_no, iri_id_no;
  caddr_t local_copy;
  caddr_t prefix, local;
  caddr_t pref_id, iri_id;
  if (!iri_split (name, &prefix, &local))
    return NULL;
  pref_id_no = nic_name_id (iri_prefix_cache, prefix);
  if (!pref_id_no)
    {
      caddr_t pref_copy = box_copy (prefix);
      pref_id = tb_name_to_id (lt, "DB.DBA.RDF_PREFIX", prefix, make_new ? "RDF_PREF_SEQ" : NULL);
      if (!pref_id)
	{
	  dk_free_box (pref_copy);
	  return NULL;
	}
      pref_id_no = unbox (pref_id);
      nic_set (iri_prefix_cache, pref_copy, pref_id_no);
      dk_free_box (pref_id);
      dk_free_box (pref_copy);
    }
  else
    dk_free_box (prefix);
  LONG_SET_NA (local, pref_id_no);
  iri_id_no = nic_name_id (iri_name_cache, local);
  if (iri_id_no)
    {
      dk_free_box (local);
      return box_iri_id (iri_id_no);
    }
  local_copy = box_copy (local);
  iri_id = tb_name_to_id (lt, "DB.DBA.RDF_IRI", local, make_new ? "RDF_URL_IID_NAMED" : NULL);
  if(!iri_id)
    {
      dk_free_box (local_copy);
      return NULL;
    }
  nic_set (iri_name_cache, local_copy, unbox_iri_id (iri_id));
  dk_free_box (local_copy);
  return iri_id;
} 


caddr_t
bif_iri_to_id (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t *) qst;
  caddr_t name = bif_arg (qst, args, 0, "iri_to_id");
  caddr_t box_to_delete = NULL;
  caddr_t res;
  int make_new = bif_long_arg (qst, args, 1, "iri_to_id");
  dtp_t dtp = DV_TYPE_OF (name);
  switch (dtp)
    {
    case DV_DB_NULL:
    case DV_IRI_ID:
      return box_copy (name);
    case DV_WIDE:
      box_to_delete = name = box_wide_as_utf8_char (name, (box_length (name) / sizeof (wchar_t)) - 1, DV_STRING);
      break;
    case DV_XML_ENTITY:
      {
        xml_entity_t *xe = (xml_entity_t *)name;
        box_to_delete = NULL;
        xe_string_value_1 (xe, &box_to_delete, DV_STRING);
        if (NULL == box_to_delete)
          sqlr_new_error ("RDFXX", ".....", "XML entity with no string value is passed as an argument to iri_to_id (), type %d", (unsigned int)dtp);
        name = box_to_delete;
        break;
      }
    case DV_STRING:
    case DV_UNAME:
      break;
    default:
      sqlr_new_error ("RDFXX", ".....", "Bad argument to iri_to_id (), type %d", (unsigned int)dtp);
    }
  if (1 == box_length (name))
    {
      if (NULL != box_to_delete)
        dk_free_box (box_to_delete);
      sqlr_new_error ("RDFXX", ".....", "Empty string is not a valid argument to iri_to_id (), type %d", (unsigned int)dtp);
    }
/*                    0123456789 */
  if (!strncmp (name, "nodeID://", 9))
    {
      unsigned char *tail = (unsigned char *)(name + 9);
      int64 acc = 0;
      while (isdigit (tail[0]))
        acc = acc * 10 + ((tail++)[0] - '0');
      if ('\0' != tail[0])
        sqlr_new_error ("RDFXX", ".....", "Bad argument to iri_to_id (), '%.100s' is not valid bnode IRI", name);
      if (NULL != box_to_delete)
        dk_free_box (box_to_delete);
      return box_iri_int64 (acc, DV_IRI_ID);
    }
  res = key_name_to_iri_id (qi->qi_trx, name, make_new);
  if (NULL == res)
    {
      if (NULL != box_to_delete)
        dk_free_box (box_to_delete);
      return NEW_DB_NULL;
    }
  if (NULL != box_to_delete)
    dk_free_box (box_to_delete);
  return res;
}


caddr_t 
tb_id_to_name (lock_trx_t * lt, char * tb_name, caddr_t id)
{
  int res;
  caddr_t iri = NULL;
  dbe_table_t * tb = sch_name_to_table (wi_inst.wi_schema, tb_name);
  dbe_key_t * key = tb ? tb->tb_primary_key : NULL;
  dbe_column_t * iri_col = key && key->key_parts && key->key_parts->next ? key->key_parts->next->data : NULL;
  it_cursor_t itc_auto;
  it_cursor_t * itc = &itc_auto;
  buffer_desc_t * buf;
  dbe_column_t *str_col, *id_col;
  if (!iri_col)
    return NULL;
  if (!tb_string_and_id_check (tb, &str_col, &id_col))
    return NULL;
  key = (dbe_key_t *)(tb->tb_keys->data == tb->tb_primary_key ? tb->tb_keys->next->data : tb->tb_keys->data);
  ITC_INIT (itc, key->key_fragments[0]->kf_it, NULL);
  itc->itc_ltrx = lt;
  itc_from (itc, key);
  ITC_SEARCH_PARAM (itc, id);
  itc->itc_isolation =ISO_COMMITTED;
  itc->itc_key_spec = key->key_insert_spec;
  ITC_FAIL (itc)
    {
      buf = itc_reset (itc);
      res = itc_search (itc, &buf);
      if (DVC_MATCH == res)
	{
	  iri = itc_box_column (itc, buf->bd_buffer, str_col->col_id, NULL);
	}
      else
	iri = NULL;
      itc_page_leave (itc, buf);
    }
  ITC_FAILED
      {
	itc_free (itc);
	return NULL;
      }
  END_FAIL (itc);
  itc_free (itc);
  return iri;
}


caddr_t 
key_id_to_iri (query_instance_t * qi, iri_id_t iri_id_no)
{
  ptrlong pref_id;
  caddr_t local, prefix, name;
  local = nic_id_name (iri_name_cache, iri_id_no);
  if (!local)
    {
      caddr_t id_box = box_iri_id (iri_id_no);
      local = tb_id_to_name (qi->qi_trx, "DB.DBA.RDF_IRI", id_box);
      dk_free_box (id_box);
      if (!local)
	return NULL;
      nic_set (iri_name_cache, local, iri_id_no);
    }
  pref_id = LONG_REF_NA (local);
  prefix = nic_id_name (iri_prefix_cache, pref_id);
  if (!prefix)
    {
      caddr_t pref_id_box = box_num (pref_id);
      prefix = tb_id_to_name (qi->qi_trx, "DB.DBA.RDF_PREFIX", pref_id_box);
      nic_set (iri_name_cache, prefix, pref_id);
      dk_free_box (pref_id_box);
    }
  if (!prefix)
    return NULL;
  name = dk_alloc_box (box_length (local) + box_length (prefix) - 5, DV_STRING);
  /* subtract 4 for the prefi x id in the local and 1 for one of the terminating nulls */
  memcpy (name, prefix, box_length (prefix) - 1);
  memcpy (name + box_length (prefix) - 1, local + 4, box_length (local) - 4);
  dk_free_box (prefix);
  dk_free_box (local);
  return name;
}


caddr_t
bif_id_to_iri (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t *) qst;
  iri_id_t id = bif_iri_id_or_null_arg (qst, args, 0, "id_to_iri");
  caddr_t iri;
  if (0L == id)
    return NEW_DB_NULL;
  iri = key_id_to_iri (qi, id);
  if (!iri)
    return NEW_DB_NULL;
  return iri;
}

caddr_t
bif_iri_id_cache_flush (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t *) qst;
  lock_trx_t *lt = qi->qi_trx;
  caddr_t log_array;
  int rc;
  if (!srv_have_global_lock (THREAD_CURRENT_THREAD))
    srv_make_new_error ("42000", "SR535", "iri_id_cache_flush() can be used only inside atomic section");
  nic_flush (iri_name_cache);
  nic_flush (iri_prefix_cache);
  log_array = list (1, box_string ("iri_id_cache_flush()"));
  mutex_enter (log_write_mtx);
  rc = log_text_array_sync (lt, log_array);
  mutex_leave (log_write_mtx);
  dk_free_tree (log_array);
  if (rc != LTE_OK)
    {
static caddr_t details = NULL;
      if (NULL == details)
        details = box_dv_short_string ("while writing new IRI_ID allocation to log file");
/*      if (lt->lt_client != bootstrap_cli) */
      sqlr_resignal (srv_make_trx_error (rc, details));
    }
  return NULL;
}

caddr_t
bif_iri_to_rdf_prefix_and_local (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t name = bif_string_or_uname_arg (qst, args, 0, "iri_to_rdf_prefix_and_local");
  caddr_t prefix, local;
  int res = iri_split (name, &prefix, &local);
  if (res)
    return list (2, prefix, local);
  return NEW_DB_NULL;
}

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

#undef tf_formula_bnode_iid
caddr_t DBG_NAME (tf_formula_bnode_iid) (DBG_PARAMS TTLP_PARAM const char *sparyytext)
{
  caddr_t btext = box_sprintf (10+strlen (sparyytext), "%ld%s", (long)(unbox_iri_id(ttlp_inst.ttlp_formula_iid)), sparyytext);
  caddr_t res;
  dk_set_push (&(ttlp_inst.ttlp_saved_uris), btext);
  res = DBG_NAME (tf_bnode_iid) (DBG_ARGS ttlp_inst.ttlp_tf, btext);
  dk_free_box (dk_set_pop (&(ttlp_inst.ttlp_saved_uris)));
  return res;
}

char * iri_replay =
"create procedure  DB.DBA.ID_REPLAY (in tb varchar, in seq varchar, in name varchar, in id an)\n"
"{\n"
"  if (isiri_id (id))\n"
"    id := iri_id_num (id);\n"
"  sequence_set (seq, id + 1, 1);\n"
"  if (tb = 'DB.DBA.RDF_PREFIX')\n"
"    insert replacing DB.DBA.RDF_PREFIX (RP_ID, RP_NAME) values (id, name);\n"
"  else if (tb = 'DB.DBA.RDF_IRI')\n"
"    insert replacing DB.DBA.RDF_IRI (RI_ID, RI_NAME) values (iri_id_from_num (id), name);\n"
"  else \n"
"    signal ('RDFXX', 'Unknown table in ID_REEPLAY ');\n"
  "}\n";

char * rdf_prefix_text = "create table DB.DBA.RDF_PREFIX (RP_NAME varchar primary key, RP_ID int not null unique)";

char * rdf_iri_text = "create table DB.DBA.RDF_IRI (RI_NAME varchar primary key, RI_ID IRI_ID not null unique)";

void
rdf_core_init (void)
{
  jso_init ();
  rdf_mapping_jso_init ();
  bif_define_typed ("rdf_load_rdfxml", bif_rdf_load_rdfxml, &bt_xml_entity);
  bif_set_uses_index (bif_rdf_load_rdfxml);
  bif_define ("rdf_load_turtle", bif_rdf_load_turtle);
  bif_set_uses_index (bif_rdf_load_turtle);
  bif_define ("turtle_lex_analyze", bif_turtle_lex_analyze);
  bif_define ("iri_to_id", bif_iri_to_id);
  bif_set_uses_index (bif_iri_to_id);
  bif_define ("id_to_iri", bif_id_to_iri);
  bif_set_uses_index (bif_id_to_iri);
  bif_define ("iri_to_rdf_prefix_and_local", bif_iri_to_rdf_prefix_and_local);
  bif_define ("iri_id_cache_flush", bif_iri_id_cache_flush);
#ifdef DEBUG
  bif_define ("turtle_lex_test", bif_turtle_lex_test);
#endif
  iri_name_cache = nic_allocate (main_bufs / 2, 1);
  iri_prefix_cache = nic_allocate (main_bufs / 20, 0);
  ddl_ensure_table ("DB.DBA.RDF_PREFIX", rdf_prefix_text);
  ddl_ensure_table ("DB.DBA.RDF_IRI", rdf_iri_text);
  ddl_std_proc (iri_replay, 0);
}
