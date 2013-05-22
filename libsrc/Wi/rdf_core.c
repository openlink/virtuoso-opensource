/*
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
#include "security.h" /* for sec_proc_check() */
#include "http.h"
#include "../Dk/Dkhash64.h"

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

#ifdef _SSL
#include <openssl/crypto.h>
#include <openssl/ssl.h>
#define MD5Init MD5_Init
#define MD5Update MD5_Update
#define MD5Final MD5_Final
#else
#include "../util/md5.h"
#endif /* _SSL */
#include "mhash.h"

int uriqa_dynamic_local = 0;

caddr_t
uriqa_get_host_for_dynamic_local (client_connection_t *cli, int * is_https)
{
  caddr_t res = NULL;
  if (cli && NULL != cli->cli_ws)
    {
      ws_connection_t *ws = cli->cli_ws;
      res = ws_mime_header_field (ws->ws_lines, "Host", NULL, 0);
      if (NULL != is_https)
#ifdef _SSL
	*is_https = (NULL != tcpses_get_ssl (ws->ws_session->dks_session));
#else
	*is_https = 0;
#endif
    }
  if (NULL == res)
    {
      const char *regname = "URIQADefaultHost";
      caddr_t * place;
      IN_TXN;
      ASSERT_IN_TXN;
      place = (caddr_t *) id_hash_get (registry, (caddr_t) & regname);
      LEAVE_TXN;
      if (place)
        res = box_copy (place[0]);
      if (NULL != is_https)
	*is_https = 0; /* default host scheme is considered to be http: */
    }
  return res;
}

int
uriqa_iri_is_local (query_instance_t *qi, const char *iri)
{
  const char *regname = "URIQADefaultHost";
  caddr_t * place;
  if (!uriqa_dynamic_local)
    return 0;
/*                   01234567 */
  if (strncmp (iri, "http://", 7))
    return 0;
  if (qi && NULL != qi->qi_client->cli_http_ses)
    {
      ws_connection_t *ws = qi->qi_client->cli_ws;
      caddr_t host = ws_mime_header_field (ws->ws_lines, "Host", NULL, 0);
      if (NULL != host)
        {
          int host_len = strlen (host);
          if (!strncmp (iri+7, host, host_len) && ('/' == iri[7+host_len]))
	    {
	      dk_free_box (host);
              return 7 + host_len;
            }
	  dk_free_box (host);
        }
    }
  IN_TXN;
  ASSERT_IN_TXN;
  place = (caddr_t *) id_hash_get (registry, (caddr_t) & regname);
  LEAVE_TXN;
  if (NULL != place)
    {
      int host_len = strlen (place[0]);
      if (!strncmp (iri+7, place[0], host_len))
        return 7 + host_len;
    }
  return 0;
}

caddr_t
uriqa_get_default_for_connvar (query_instance_t *qi, const char *varname)
{
  if (!strcmp ("URIQADefaultHost", varname))
    {
      const char *regname = "URIQADefaultHost";
      caddr_t * place;
      IN_TXN;
      place = (caddr_t *) id_hash_get (registry, (caddr_t) & regname);
      LEAVE_TXN;
      if (place)
        return box_copy (place[0]);
      return NULL;
    }
  if (!strcmp ("WSHost", varname))
    return uriqa_get_host_for_dynamic_local (qi->qi_client, NULL);
  if (!strcmp ("WSHostName", varname))
    {
      caddr_t host = uriqa_get_host_for_dynamic_local (qi->qi_client, NULL);
      const char *colon;
      caddr_t res;
      if (NULL == host)
        return NULL;
      colon = strchr (host, ':');
      if (NULL == colon)
        return host;
      res = box_dv_short_nchars (host, colon - host);
      dk_free_box (host);
      return res;
    }
  if (!strcmp ("WSHostPort", varname))
    {
      caddr_t host = uriqa_get_host_for_dynamic_local (qi->qi_client, NULL);
      const char *colon;
      caddr_t res;
      if (NULL == host)
        return box_dv_short_string ("80");
      colon = strchr (host, ':');
      if (NULL == colon)
        {
          dk_free_box (host);
          return box_dv_short_string ("80");
        }
      res = box_dv_short_string (colon + 1);
      dk_free_box (host);
      return res;
    }
  return NULL;
}

triple_feed_t *
tf_alloc (void)
{
  NEW_VARZ (triple_feed_t, tf);
  tf->tf_blank_node_ids = id_hash_allocate (1021, sizeof (caddr_t), sizeof (caddr_t), strhash, strhashcmp);
  id_hash_set_rehash_pct (tf->tf_blank_node_ids, 220);
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
  id_hash_free (tf->tf_blank_node_ids);
  if (tf->tf_current_graph_uri != tf->tf_default_graph_uri)
    dk_free_tree (tf->tf_current_graph_uri);
  dk_free_tree (tf->tf_default_graph_iid);
  dk_free_tree (tf->tf_current_graph_iid);
  dk_free_tree (tf->tf_boxed_input_name);
  dk_free_tree (tf->tf_base_uri);
  dk_free_tree (tf->tf_default_graph_uri);
  dk_free (tf, sizeof (triple_feed_t));
}

void
sqlr_set_cbk_name_and_proc (client_connection_t *cli, const char *cbk_name, const char* cbk_param_types, const char *funname,
  char **full_name_ret, query_t **proc_ret, caddr_t *err_ret )
{
  const char *param_type_iter;
  char *full_name;
  proc_ret[0] = NULL;
  err_ret[0] = NULL;
  if ('\0' == cbk_name[0])
    {
      if (NULL != full_name_ret)
        full_name_ret[0] = NULL;
      proc_ret[0] = NULL;
      return;
    }
  if ('!' == cbk_name[0])
    {
      if (NULL != full_name_ret)
        full_name_ret[0] = cbk_name;
      proc_ret[0] = NULL;
      return;
    }
  full_name = sch_full_proc_name (wi_inst.wi_schema, cbk_name, cli_qual (cli), CLI_OWNER (cli));
  if (NULL != full_name_ret)
    full_name_ret[0] = full_name;
  if (NULL != full_name)
    proc_ret[0] = sch_proc_def (wi_inst.wi_schema, full_name);
  if (NULL == proc_ret[0])
    {
      err_ret[0] = srv_make_new_error ("42001", "SR574",
        "Undefined procedure name \"%.100s\" is passed as callback parameter to %.100s()", cbk_name, funname );
      return;
    }
  if (proc_ret[0]->qr_to_recompile)
    {
      proc_ret[0] = qr_recompile (proc_ret[0], err_ret);
      if (err_ret[0])
        return;
    }
  if (NULL != cli->cli_user && !sec_proc_check (proc_ret[0], cli->cli_user->usr_id, cli->cli_user->usr_g_id))
    {
      err_ret[0] = srv_make_new_error ("42000", "SR575", "No permission to execute %.300s as callback of %.100s() with user ID %d, group ID %d",
        full_name, funname, (int)(cli->cli_user->usr_id), (int)(cli->cli_user->usr_g_id) );
      return;
    }
  if (strlen (cbk_param_types) != dk_set_length (proc_ret[0]->qr_parms))
    {
      err_ret[0] = srv_make_new_error ("42000", "SR576",
        "The callback %.300s[] of %.100s() declaration contains %d arguments, not %d as expected",
        full_name, funname, (int)(dk_set_length (proc_ret[0]->qr_parms)), (int)(strlen (cbk_param_types)) );
      return;
    }
  param_type_iter = cbk_param_types;
  DO_SET (state_slot_t *, ssl, &(proc_ret[0]->qr_parms))
    {
      const char *problem = NULL;
      switch (param_type_iter[0])
        {
          case 'R':
            if (SSL_REF_PARAMETER != ssl->ssl_type)
	      problem = "should be declared as inout";
            break;
          case 'I':
            if (SSL_REF_PARAMETER == ssl->ssl_type)
	      problem = "should be declared as in";
            break;
#ifndef NDEBUG
          default:
            GPF_T1("bad param type decl string");
#endif
        }
      if (NULL != problem)
        {
          err_ret[0] = srv_make_new_error ("42000", "SR577",
            "The argument #%ld (%.100s) of callback %.300s[] of %.100s() %.100s",
            (long) (param_type_iter - cbk_param_types) + 1, ssl->ssl_name,
            full_name, funname, problem );
	  return;
	}
      param_type_iter++;
    }
  END_DO_SET();
}

static const char *tf_cbk_param_types[COUNTOF__TRIPLE_FEED__ALL] = {
  "RRR",	/* e.g., DB.DBA.TTLP_EV_NEW_GRAPH(?,?) */
  "RRR",	/* e.g., DB.DBA.TTLP_EV_NEW_BLANK(?,?, ?); there was 'select DB.DBA.TTLP_EV_NEW_BLANK(?,?)' */
  "RRRR",	/* e.g., DB.DBA.TTLP_EV_GET_IID(?,?,?, ?); there was 'select DB.DBA.TTLP_EV_GET_IID(?,?,?)'  */
  "RRRRR",	/* e.g., DB.DBA.TTLP_EV_TRIPLE(?, ?, ?, ?, ?) */
  "RRRRRRR",	/* e.g., DB.DBA.TTLP_EV_TRIPLE_L(?, ?, ?, ?,?,?, ?) */
  "RR",		/* e.g., DB.DBA.TTLP_EV_COMMIT(?,?) */
  "RRRRRRRRRRR",	/* e.g., DB.DBA.TTLP_EV_REPORT_DEFAULT(?,?,?,?,?,?,?,?,?,?,?) */
  "RRR" };		/* e.g., DB.DBA.TTLP_EV_NEW_BASE(?,?,?) */


void
tf_set_cbk_names (triple_feed_t *tf, ccaddr_t *cbk_names)
{
  int cbk_count = BOX_ELEMENTS (cbk_names);
  int ctr;
  for (ctr = 0; ctr < COUNTOF__TRIPLE_FEED__ALL; ctr++)
    {
      caddr_t err = NULL;
      if ((ctr >= cbk_count) || ('\0' == cbk_names[ctr][0]))
        {
          tf->tf_cbk_names[ctr] = NULL;
          tf->tf_cbk_qrs[ctr] = NULL;
          continue;
        }
      if ('!' == cbk_names[ctr][0])
        {
          tf->tf_cbk_names[ctr] = cbk_names[ctr];
          tf->tf_cbk_qrs[ctr] = NULL;
          continue;
        }
      sqlr_set_cbk_name_and_proc (tf->tf_qi->qi_client, cbk_names[ctr], tf_cbk_param_types[ctr], tf->tf_creator,
        (caddr_t *) (tf->tf_cbk_names + ctr), tf->tf_cbk_qrs + ctr, &err );
      if (NULL != err)
        sqlr_resignal (err);
    }
}

int32 tf_rnd_seed;

caddr_t
tf_get_iid (triple_feed_t *tf, caddr_t uri)
{
  dtp_t uri_dtp = DV_TYPE_OF (uri);
  caddr_t res;
  caddr_t err = NULL;
  query_t *cbk_qr;
  if ((DV_STRING != uri_dtp) && (DV_UNAME != uri_dtp))
    return box_copy_tree (uri);
  cbk_qr = tf->tf_cbk_qrs[TRIPLE_FEED_GET_IID];
  if (NULL == cbk_qr)
    { /* Now two meaningful cases are "!iri_to_id" and "!cached_iri_to_id" */
      const char *cbk_name = tf->tf_cbk_names[TRIPLE_FEED_GET_IID];
      if (NULL == cbk_name)
        res = box_copy_tree (uri);
      else if (!strcmp (cbk_name, "!iri_to_id"))
        res = iri_to_id ((caddr_t *)(tf->tf_qi), uri, IRI_TO_ID_WITH_CREATE, &err);
      else if (!strcmp (cbk_name, "!cached_iri_to_id"))
        res = iri_to_id ((caddr_t *)(tf->tf_qi), uri, IRI_TO_ID_IF_CACHED, &err);
      else
        sqlr_new_error ("22023", ".....", "Unsupported callback %.100s in RDF parser", cbk_name);
    }
  else
    {
      char params_buf [BOX_AUTO_OVERHEAD + sizeof (caddr_t) * 4];
      void **params;
      BOX_AUTO_TYPED (void **, params, params_buf, sizeof (caddr_t) * 4, DV_ARRAY_OF_POINTER);
      res = NULL;
      params[0] = &uri;
      params[1] = TF_GRAPH_ARG(tf);
      params[2] = &(tf->tf_app_env);
      params[3] = &res;
      err = qr_exec (tf->tf_qi->qi_client, cbk_qr, tf->tf_qi, NULL, NULL, NULL, (caddr_t *)params, NULL, 0);
      BOX_DONE (params, params_buf);
    }
  if (NULL != err)
    sqlr_resignal (err);
  return res;
}


void
tf_new_graph (triple_feed_t *tf, caddr_t uri)
{
  query_t *cbk_qr = tf->tf_cbk_qrs[TRIPLE_FEED_NEW_GRAPH];
  char params_buf [BOX_AUTO_OVERHEAD + sizeof (caddr_t) * 3];
  void **params;
  caddr_t err = NULL;
  if (NULL == cbk_qr)
    return;
  BOX_AUTO_TYPED (void **, params, params_buf, sizeof (caddr_t) * 3, DV_ARRAY_OF_POINTER);
  params[0] = &uri;
  params[1] = TF_GRAPH_ARG(tf);
  params[2] = &(tf->tf_app_env);
  err = qr_exec (tf->tf_qi->qi_client, cbk_qr, tf->tf_qi, NULL, NULL, NULL, (caddr_t *)params, NULL, 0);
  BOX_DONE (params, params_buf);
  if (NULL != err)
    sqlr_resignal (err);
}


void
tf_commit (triple_feed_t *tf)
{
  char params_buf [BOX_AUTO_OVERHEAD + sizeof (caddr_t) * 2];
  void **params;
  caddr_t err;
  query_t *cbk_qr = tf->tf_cbk_qrs[TRIPLE_FEED_COMMIT];
  if (NULL == cbk_qr)
    return;
  BOX_AUTO_TYPED (void **, params, params_buf, sizeof (caddr_t) * 2, DV_ARRAY_OF_POINTER);
  params[0] = TF_GRAPH_ARG(tf);
  params[1] = &(tf->tf_app_env);
  err = qr_exec (tf->tf_qi->qi_client, cbk_qr, tf->tf_qi, NULL, NULL, NULL, (caddr_t *)params, NULL, 0);
  BOX_DONE (params, params_buf);
  if (NULL != err)
    sqlr_resignal (err);
}

void
tf_report (triple_feed_t *tf, char msg_type, const char *sqlstate, const char *sqlmore, const char *descr)
{
  /* caddr_t res; */
  caddr_t err = NULL;
  query_t *cbk_qr;
  char params_buf [BOX_AUTO_OVERHEAD + sizeof (caddr_t) * 11];
  void **params;
  caddr_t msg_no_box, msg_type_box, inp_name_box, line_no_box, triple_no_box, sqlstate_box, sqlmore_box, descr_box;
  cbk_qr = tf->tf_cbk_qrs[TRIPLE_FEED_MESSAGE];
  if (NULL == cbk_qr)
    return;
  BOX_AUTO_TYPED (void **, params, params_buf, sizeof (caddr_t) * 11, DV_ARRAY_OF_POINTER);
  msg_no_box = box_num (tf->tf_message_count++);
  msg_type_box = box_dv_short_nchars (&msg_type, 1);
  inp_name_box = box_copy (tf->tf_boxed_input_name);
  line_no_box = ((NULL != tf->tf_line_no_ptr) ? box_num (tf->tf_line_no_ptr[0]) : NULL);
  triple_no_box = box_num (tf->tf_triple_count);
  sqlstate_box = box_dv_short_string (sqlstate);
  sqlmore_box = box_dv_short_string (sqlmore);
  descr_box = box_dv_short_string (descr);
  /* res = NULL; */
  params[0] = &msg_no_box;
  params[1] = &msg_type_box;
  params[2] = &inp_name_box;
  params[3] = &(tf->tf_base_uri);
  params[4] = &(tf->tf_current_graph_uri);
  params[5] = &line_no_box;
  params[6] = &triple_no_box;
  params[7] = &sqlstate_box;
  params[8] = &sqlmore_box;
  params[9] = &descr_box;
  params[10] = &(tf->tf_app_env);
  /*params[11] = &res;*/
  err = qr_exec (tf->tf_qi->qi_client, cbk_qr, tf->tf_qi, NULL, NULL, NULL, (caddr_t *)params, NULL, 0);
#ifdef DEBUG
  if (NULL != err)
    {
      printf ("tf_report callback error ");
      dbg_print_box (err, stdout);
      printf (" for arguments ");
      dbg_print_box ((caddr_t)params, stdout);
      printf ("\n");
    }
#endif
  dk_free_tree (msg_no_box);
  dk_free_tree (msg_type_box);
  dk_free_tree (inp_name_box);
  dk_free_tree (line_no_box);
  dk_free_tree (triple_no_box);
  dk_free_tree (sqlstate_box);
  dk_free_tree (sqlmore_box);
  dk_free_tree (descr_box);
  BOX_DONE (params, params_buf);
  if (NULL != err)
    sqlr_resignal (err);
#if 0
  if (NULL != res)
    {
      printf ("tf_report callback returns ");
      dbg_print_box (res, stdout);
      printf ("\n");
      dk_free_tree (res);
    }
#endif
}


void
tf_new_base (triple_feed_t *tf, caddr_t new_base)
{
  if ((NULL != tf->tf_cbk_names[TRIPLE_FEED_NEW_GRAPH]) && (NULL != tf->tf_current_graph_uri))
    tf_commit (tf);
  if (tf->tf_current_graph_uri != tf->tf_default_graph_uri)
    {
      dk_free_tree (tf->tf_current_graph_uri);
      tf->tf_current_graph_uri = NULL;
    }
  tf->tf_current_graph_uri = tf->tf_default_graph_uri;
  if (NULL != tf->tf_base_uri)
    {
      dk_free_box (new_base);
      sqlr_new_error ("37000", "SP029", "Multiple base URI declarations are not supported");
    }
  dk_free_box (tf->tf_base_uri); tf->tf_base_uri = box_dv_short_string (new_base);
  do {
      query_t *cbk_qr = tf->tf_cbk_qrs[TRIPLE_FEED_NEW_BASE];
      char params_buf [BOX_AUTO_OVERHEAD + sizeof (caddr_t) * 3];
      void **params;
      caddr_t err = NULL;
      if (NULL == cbk_qr)
        GPF_T;
      BOX_AUTO_TYPED (void **, params, params_buf, sizeof (caddr_t) * 3, DV_ARRAY_OF_POINTER);
      params[0] = &(tf->tf_base_uri);
      params[1] = &(tf->tf_default_graph_uri);
      params[2] = &(tf->tf_app_env);
      err = qr_exec (tf->tf_qi->qi_client, cbk_qr, tf->tf_qi, NULL, NULL, NULL, (caddr_t *)params, NULL, 0);
      BOX_DONE (params, params_buf);
      if (NULL != err)
        sqlr_resignal (err);
    } while (0);
  if (NULL != tf->tf_cbk_names[TRIPLE_FEED_NEW_GRAPH]) {
      dk_free_tree (tf->tf_current_graph_iid);
      if (TF_ONE_GRAPH_AT_TIME (tf)) {
          tf->tf_current_graph_iid = NULL; /* to avoid double free in case of error in tf_get_iid() below */
          tf->tf_default_graph_iid = tf_get_iid (tf, tf->tf_default_graph_uri); }
      tf->tf_current_graph_iid = box_copy (tf->tf_default_graph_iid);
      tf_new_graph (tf, tf->tf_current_graph_uri); }
}


caddr_t
bif_rdf_load_rdfxml_impl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, int mode_bits, const char *bifname)
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
  ccaddr_t *cbk_names;
  caddr_t *app_env;
  int n_args = BOX_ELEMENTS (args);
  /*wcharset_t * volatile charset = QST_CHARSET (qst) ? QST_CHARSET (qst) : default_charset;*/
  text_arg = bif_arg (qst, args, 0, bifname);
  mode_bits |= bif_long_arg (qst, args, 1, bifname);
  graph_uri = bif_string_or_wide_or_uname_arg (qst, args, 2, bifname);
  cbk_names = (ccaddr_t *)bif_strict_type_array_arg (DV_STRING, qst, args, 3, bifname);
  app_env = (caddr_t *) bif_arg (qst, args, 4, bifname);
  if ((COUNTOF__TRIPLE_FEED__REQUIRED > BOX_ELEMENTS (cbk_names)) || (COUNTOF__TRIPLE_FEED__ALL < BOX_ELEMENTS (cbk_names)))
    sqlr_new_error ("22023", "RDF01",
      "The argument #4 of %.200s() should be a vector of %d to %d names of stored procedures",
      bifname, COUNTOF__TRIPLE_FEED__REQUIRED, COUNTOF__TRIPLE_FEED__ALL );
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
	      "Function %.200s() does not support loading from string session with persistent XML data", bifname );
	  if (XE_XPACK_SERIALIZATION == ses_sort)
	    {
#if 1
	    sqlr_error ("42000",
	      "Function %.200s() does not support loading from string session with packed XML data", bifname );
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
	  "Function %.200s() does not support loading from persistent XML objects", bifname );
      if ((DV_BLOB_HANDLE == dtp_of_text_arg) || (DV_BLOB_WIDE_HANDLE == dtp_of_text_arg))
	{
	  int blob_sort = looks_like_serialized_xml (((query_instance_t *)(qst)), text_arg);
	  if (XE_XPER_SERIALIZATION == blob_sort)
	    sqlr_error ("42000",
	      "Function %.200s() does not support loading from BLOBs with persistent XML data", bifname );
	  if (XE_XPACK_SERIALIZATION == blob_sort)
	    {
#if 1
	    sqlr_error ("42000",
	      "Function %.200s() does not support loading from BLOBs with packed XML data", bifname );
#else
	      caddr_t *tree_tmp = NULL; /* Solely to avoid dummy warning C4090: 'function' : different 'volatile' qualifiers */
	      dk_session_t *ses = blob_to_string_output (((query_instance_t *)(qst))->qi_trx, text_arg);
	      xte_deserialize_packed (ses, &tree_tmp, dtd_ptr);
	      tree = (caddr_t)tree_tmp;
	      if (NULL != dtd)
	        dtd_addref (dtd, 0);
	      strses_free (ses);
	      if ((NULL == tree) && (DEAD_HTML != (parser_mode & ~(FINE_XSLT | GE_XML | WEBIMPORT_HTML | FINE_XML_SRCPOS))))
		sqlr_error ("42000", "The BLOB passed to a function %.200s() contains corrupted packed XML serialization data", bifname);
	      goto tree_complete; /* see below */
#endif
	    }
	  arg_is_wide = (DV_BLOB_WIDE_HANDLE == dtp_of_text_arg) ? 1 : 0;
	  break;
	}
      sqlr_error ("42000",
	"Function %.200s() needs a string or string session or BLOB as argument 1, not an arg of type %s (%d), bifname",
	bifname, dv_type_title (dtp_of_text_arg), dtp_of_text_arg);
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
      dtd_config = bif_array_or_null_arg (qst, args, 8, bifname);*/
    case 8:
      lh = lh_get_handler (bif_string_arg (qst, args, 7, bifname));
    case 7:
      enc = bif_string_arg (qst, args, 6, bifname);
    case 6:
      base_uri = bif_string_or_uname_or_wide_or_null_arg (qst, args, 5, bifname);
    case 5:
    case 4:
    case 3:
    case 2:
    case 1:
	  ;
    }
  rdfxml_parse ((query_instance_t *) qst, text_arg, (caddr_t *)&err, mode_bits,
    NULL /* source name is unknown */, base_uri, graph_uri, cbk_names, app_env, enc, lh
    /*, caddr_t dtd_config, dtd_t **ret_dtd, id_hash_t **ret_id_cache, &ns2dict*/ );
  if (NULL != err)
    sqlr_resignal (err);
  return NULL;
}


caddr_t
bif_rdf_load_rdfxml (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_rdf_load_rdfxml_impl (qst, err_ret, args, 0, "rdf_load_rdfxml");
}


caddr_t
bif_rdf_load_rdfa (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_rdf_load_rdfxml_impl (qst, err_ret, args, RDFXML_IN_ATTRIBUTES, "rdf_load_rdfa");
}


caddr_t
bif_rdf_load_microdata (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_rdf_load_rdfxml_impl (qst, err_ret, args, RDFXML_IN_MDATA, "rdf_load_microdata");
}


ttlp_t *
ttlp_alloc (void)
{
  ttlp_t *ttlp;
  ttlp = (ttlp_t *)dk_alloc (sizeof (ttlp_t));
  memset (ttlp, 0, sizeof (ttlp_t));
  ttlp->ttlp_lexlineno = 1;
  ttlp->ttlp_tf = tf_alloc ();
  ttlp->ttlp_tf->tf_creator = "rdf_load_turtle";
  return ttlp;
}

void
ttlp_enter_trig_group (ttlp_t *ttlp)
{
  ttlp->ttlp_default_ns_uri_saved = ttlp->ttlp_default_ns_uri;
  ttlp->ttlp_base_uri_saved = ttlp->ttlp_base_uri;
  ttlp->ttlp_in_trig_graph = 1;
}

void
ttlp_leave_trig_group (ttlp_t *ttlp)
{
  if (ttlp->ttlp_default_ns_uri_saved != ttlp->ttlp_default_ns_uri)
    {
      dk_free_box (ttlp->ttlp_default_ns_uri);
      ttlp->ttlp_default_ns_uri = ttlp->ttlp_default_ns_uri_saved;
      ttlp->ttlp_default_ns_uri_saved = NULL;
    }
  if (ttlp->ttlp_base_uri_saved != ttlp->ttlp_base_uri)
    {
      dk_free_box (ttlp->ttlp_base_uri);
      ttlp->ttlp_base_uri = ttlp->ttlp_base_uri_saved;
      ttlp->ttlp_base_uri_saved = NULL;
    }
  dk_free_box ((caddr_t)(ttlp->ttlp_inner_namespaces_prefix2iri));
  ttlp->ttlp_inner_namespaces_prefix2iri = NULL;
  ttlp->ttlp_in_trig_graph = 0;
}

void
ttlp_free (ttlp_t *ttlp)
{
  if (ttlp->ttlp_in_trig_graph)
    {
      dk_free_box ((caddr_t)(ttlp->ttlp_inner_namespaces_prefix2iri));
      if (ttlp->ttlp_default_ns_uri_saved != ttlp->ttlp_default_ns_uri)
        dk_free_box (ttlp->ttlp_default_ns_uri_saved);
      if (ttlp->ttlp_base_uri_saved != ttlp->ttlp_base_uri)
        dk_free_box (ttlp->ttlp_base_uri_saved);
    }
  dk_free_box (ttlp->ttlp_default_ns_uri);
  dk_free_box ((caddr_t)(ttlp->ttlp_namespaces_prefix2iri));
  while (NULL != ttlp->ttlp_saved_uris)
    dk_free_tree ((box_t) dk_set_pop (&(ttlp->ttlp_saved_uris)));
  while (NULL != ttlp->ttlp_unused_seq_bnodes)
    dk_free_tree ((box_t) dk_set_pop (&(ttlp->ttlp_unused_seq_bnodes)));
  dk_free_tree (ttlp->ttlp_last_complete_uri);
  dk_free_tree (ttlp->ttlp_subj_uri);
  dk_free_tree (ttlp->ttlp_pred_uri);
  dk_free_tree (ttlp->ttlp_obj);
  dk_free_tree (ttlp->ttlp_obj_type);
  dk_free_tree (ttlp->ttlp_obj_lang);
  dk_free_tree (ttlp->ttlp_formula_iid);
  tf_free (ttlp->ttlp_tf);
  dk_free (ttlp, sizeof (ttlp_t));
}

void
ttlyyerror_impl (ttlp_t *ttlp_arg, const char *raw_text, const char *strg)
{
  int lineno = ttlp_arg[0].ttlp_lexlineno;
  if (NULL == raw_text)
    raw_text = ttlp_arg[0].ttlp_raw_text;
  tf_report (ttlp_arg[0].ttlp_tf, 'F', "37000", "RDF29", strg);
  sqlr_new_error ("37000", "SP029",
      "%.400s, line %d: %.500s%.5s%.1000s",
      ttlp_arg[0].ttlp_err_hdr,
      lineno,
      strg,
      ((NULL == raw_text) ? "" : " at "),
      ((NULL == raw_text) ? "" : raw_text));
}


void
ttlyyerror_impl_1 (ttlp_t *ttlp_arg, const char *raw_text, int yystate, short *yyssa, short *yyssp, const char *strg)
{
  int sm2, sm1, sp1;
  int lineno = ttlp_arg[0].ttlp_lexlineno;
  if (NULL == raw_text)
    raw_text = ttlp_arg[0].ttlp_raw_text;
  tf_report (ttlp_arg[0].ttlp_tf, 'F', "37000", "RDF30", strg);
  sp1 = yyssp[1];
  sm1 = yyssp[-1];
  sm2 = ((sm1 > 0) ? yyssp[-2] : 0);
  sqlr_new_error ("37000", "RDF30",
     /*errlen,*/ "%.400s, line %d: %.500s [%d-%d-(%d)-%d]%.5s%.1000s%.5s",
      ttlp_arg[0].ttlp_err_hdr,
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


caddr_t ttlp_strliteral (ttlp_t *ttlp_arg, const char *strg, int mode, char delimiter)
{
  caddr_t tmp_buf;
  caddr_t res;
  const char *err_msg;
  const char *src_tail, *src_end;
  char *tgt_tail;
  int strg_is_long = (TTLP_STRLITERAL_QUOT_AT < mode);
  src_tail = strg + (strg_is_long ? 3 : 1);
  src_end = strg + strlen (strg) - (mode>>4);
  tgt_tail = tmp_buf = dk_alloc_box ((src_end - src_tail) + 1, DV_SHORT_STRING);
  while (src_tail < src_end)
    {
      switch (src_tail[0])
	{
	case '\\':
          {
	    const char *bs_src		= "abfnrtv\\\'\">uU\n\r";
	    const char *bs_trans	= "\a\b\f\n\r\t\v\\\'\">\0\0\0\0";
            const char *bs_lengths	= "\2\2\2\2\2\2\2\2\2\2\2\6\012\2\2";
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
	    else if (('\n' == src_tail[1]) || ('\r' == src_tail[1]))
              {
                (tgt_tail++)[0] = '\n';
                while (('\n' == nextchr[0]) || ('\r' == nextchr[0]))
                  nextchr++;
              }
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
  box_flags (res) = BF_UTF8;
  dk_free_box (tmp_buf);
  return res;

err:
  dk_free_box (tmp_buf);
  ttlyyerror_impl (ttlp_arg, NULL, err_msg);
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
caddr_t DBG_NAME (ttlp_expand_qname_prefix) (DBG_PARAMS ttlp_t *ttlp_arg, caddr_t qname)
{
  char *lname = strchr (qname, ':');
  id_hash_t *ns_dict;
  caddr_t ns_pref, ns_uri, *ns_uri_ptr, res;
  int ns_uri_len, local_len, res_len;
  if (NULL == lname)
    {
      lname = qname;
      ns_uri = ttlp_arg[0].ttlp_default_ns_uri;
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
      ns_uri = ttlp_arg[0].ttlp_default_ns_uri;
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
  ns_pref = box_dv_short_nchars (qname, lname - qname);
  do {
      if (ttlp_arg[0].ttlp_in_trig_graph)
        {
          ns_dict = ttlp_arg[0].ttlp_inner_namespaces_prefix2iri;
          ns_uri_ptr = ((NULL == ns_dict) ? NULL : (caddr_t *) id_hash_get (ns_dict, (caddr_t)(&ns_pref)));
          if (NULL != ns_uri_ptr)
            { ns_uri = ns_uri_ptr[0]; break; }
        }
      ns_dict = ttlp_arg[0].ttlp_namespaces_prefix2iri;
      ns_uri_ptr = ((NULL == ns_dict) ? NULL : (caddr_t *) id_hash_get (ns_dict, (caddr_t)(&ns_pref)));
      if (NULL != ns_uri_ptr)
        { ns_uri = ns_uri_ptr[0]; break; }
      if (!strcmp (ns_pref, "rdf:"))
        { ns_uri = uname_rdf_ns_uri; break; }
      if (!strcmp (ns_pref, "xsd:"))
        { ns_uri = uname_xmlschema_ns_uri_hash; break; }
      if (!strcmp (ns_pref, "virtrdf:"))
        { ns_uri = uname_virtrdf_ns_uri; break; }
      dk_free_box (ns_pref);
      ttlyyerror_impl (ttlp_arg, qname, "Undefined namespace prefix");
    } while (0);
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
ttlp_uri_resolve (ttlp_t *ttlp_arg, caddr_t qname)
{
  /*query_instance_t *qi = ttlp_arg[0].ttlp_tf->tf_qi;*/
  caddr_t res, err = NULL;
  if (('_' == qname[0]) && (':' == qname[1]))
    return qname;
  res = rfc1808_expand_uri (/*qi,*/ ttlp_arg[0].ttlp_tf->tf_base_uri, qname, "UTF-8", 1 /* ??? */, "UTF-8", "UTF-8", &err);
  if (res != qname)
    dk_free_box (qname);
  if (NULL != err)
    sqlr_resignal (err);
  if (res == ttlp_arg[0].ttlp_tf->tf_base_uri)
    return box_copy (res);
  return res;
}

void
ttlp_triple_and_inf (ttlp_t *ttlp_arg, caddr_t o_uri)
{
  triple_feed_t *tf = ttlp_arg[0].ttlp_tf;
  caddr_t s = ttlp_arg[0].ttlp_subj_uri;
  caddr_t p = ttlp_arg[0].ttlp_pred_uri;
  caddr_t o = o_uri;
  if ((NULL == s) || (NULL == p))
    return;
  if (ttlp_arg[0].ttlp_pred_is_reverse)
    {
      caddr_t swap = o;
      o = s;
      s = swap;
    }
  if (ttlp_arg[0].ttlp_formula_iid)
    {
      caddr_t stmt = tf_bnode_iid (tf, NULL);
      tf_triple (tf, stmt, uname_rdf_ns_uri_subject, s);
      tf_triple (tf, stmt, uname_rdf_ns_uri_predicate, p);
      tf_triple (tf, stmt, uname_rdf_ns_uri_object, o);
      tf_triple (tf, stmt, uname_rdf_ns_uri_type, uname_rdf_ns_uri_Statement);
      tf_triple (tf, ttlp_arg[0].ttlp_formula_iid, uname_swap_reify_ns_uri_statement, stmt);
    }
  tf_triple (tf, s, p, o);
}

void
ttlp_triple_l_and_inf (ttlp_t *ttlp_arg, caddr_t o_sqlval, caddr_t o_dt, caddr_t o_lang)
{
  triple_feed_t *tf = ttlp_arg[0].ttlp_tf;
  caddr_t s = ttlp_arg[0].ttlp_subj_uri;
  caddr_t p = ttlp_arg[0].ttlp_pred_uri;
  if ((NULL == s) || (NULL == p))
    return;
  if (ttlp_arg[0].ttlp_pred_is_reverse)
    {
      if (!(ttlp_arg[0].ttlp_flags & TTLP_SKIP_LITERAL_SUBJECTS))
        ttlyyerror_impl (ttlp_arg, "", "Virtuoso does not support literal subjects");
      if (ttlp_arg[0].ttlp_formula_iid)
        {
          caddr_t stmt = tf_bnode_iid (tf, NULL);
          tf_triple_l (tf, stmt, uname_rdf_ns_uri_subject, o_sqlval, o_dt, o_lang);
          tf_triple (tf, stmt, uname_rdf_ns_uri_predicate, p);
          tf_triple (tf, stmt, uname_rdf_ns_uri_object, s);
          tf_triple (tf, stmt, uname_rdf_ns_uri_type, uname_rdf_ns_uri_Statement);
          tf_triple (tf, ttlp_arg[0].ttlp_formula_iid, uname_swap_reify_ns_uri_statement, stmt);
        }
      return;
    }
  if (ttlp_arg[0].ttlp_formula_iid)
    {
      caddr_t stmt = tf_bnode_iid (tf, NULL);
      tf_triple (tf, stmt, uname_rdf_ns_uri_subject, s);
      tf_triple (tf, stmt, uname_rdf_ns_uri_predicate, p);
      tf_triple_l (tf, stmt, uname_rdf_ns_uri_object, o_sqlval, o_dt, o_lang);
      tf_triple (tf, stmt, uname_rdf_ns_uri_type, uname_rdf_ns_uri_Statement);
      tf_triple (tf, ttlp_arg[0].ttlp_formula_iid, uname_swap_reify_ns_uri_statement, stmt);
    }
  tf_triple_l (ttlp_arg[0].ttlp_tf, s, p, o_sqlval, o_dt, o_lang);
}

void
ttlp_triples_for_bnodes_debug (ttlp_t *ttlp_arg, caddr_t bnode_iid, int lineno, caddr_t label)
{
  triple_feed_t *tf = ttlp_arg[0].ttlp_tf;
  if (NULL != ttlp_arg->ttlp_base_uri)
    tf_triple_l (tf, bnode_iid, uname_virtrdf_ns_uri_bnode_base, ttlp_arg->ttlp_base_uri, NULL, NULL);
  tf_triple_l (tf, bnode_iid, uname_virtrdf_ns_uri_bnode_row, box_num_nonull (lineno), NULL, NULL);
  if (NULL != label)
    tf_triple_l (tf, bnode_iid, uname_virtrdf_ns_uri_bnode_label, label, NULL, NULL);
}


#ifdef DEBUG
#define TF_TRIPLE_PROGRESS_MESSAGE_MOD 25
#else
#define TF_TRIPLE_PROGRESS_MESSAGE_MOD 10000000
#endif

void
tf_triple (triple_feed_t *tf, caddr_t s_uri, caddr_t p_uri, caddr_t o_uri)
{
  char params_buf [BOX_AUTO_OVERHEAD + sizeof (caddr_t) * 5];
  void **params;
  caddr_t err;
  caddr_t replica_of = box_copy (tf->tf_qi->qi_trx->lt_replica_of);
  query_t *cbk_qr = tf->tf_cbk_qrs[TRIPLE_FEED_TRIPLE];
  if (NULL == cbk_qr)
    return;
#ifdef DEBUG
  switch (DV_TYPE_OF (o_uri))
    {
    case DV_LONG_INT:
      rdf_dbg_printf (("\ntf_triple (%ld)", (long)(o_uri)));
    case DV_STRING: case DV_UNAME:
      rdf_dbg_printf (("\ntf_triple (%s)", o_uri));
    }
#endif
  BOX_AUTO_TYPED (void **, params, params_buf, sizeof (caddr_t) * 5, DV_ARRAY_OF_POINTER);
  params[0] = TF_GRAPH_ARG(tf);
  params[1] = &s_uri;
  params[2] = &p_uri;
  params[3] = &o_uri;
  params[4] = &(tf->tf_app_env);
  err = qr_exec (tf->tf_qi->qi_client, cbk_qr, tf->tf_qi, NULL, NULL, NULL, (caddr_t *)params, NULL, 0);
  BOX_DONE (params, params_buf);
  tf->tf_triple_count++;
  if (!tf->tf_qi->qi_trx->lt_replica_of)
    tf->tf_qi->qi_trx->lt_replica_of = replica_of;
  else
    dk_free_box (replica_of);
  if (!(tf->tf_triple_count % TF_TRIPLE_PROGRESS_MESSAGE_MOD))
    tf_report (tf, 'P', NULL, NULL, "Loading is in progress");
  if (NULL != err)
    sqlr_resignal (err);
}

void tf_triple_l (triple_feed_t *tf, caddr_t s_uri, caddr_t p_uri, caddr_t obj_sqlval, caddr_t obj_datatype, caddr_t obj_language)
{
  char params_buf [BOX_AUTO_OVERHEAD + sizeof (caddr_t) * 7];
  void **params;
  caddr_t err;
  caddr_t replica_of = box_copy (tf->tf_qi->qi_trx->lt_replica_of);
  query_t *cbk_qr = tf->tf_cbk_qrs[TRIPLE_FEED_TRIPLE_L];
  if (NULL == cbk_qr)
    return;
#ifdef DEBUG
  switch (DV_TYPE_OF (obj_sqlval))
    {
    case DV_LONG_INT:
      rdf_dbg_printf (("\ntf_triple_l (%ld)", (long)(obj_sqlval))); break;
    case DV_STRING: case DV_UNAME:
      rdf_dbg_printf (("\ntf_triple_l (%s, %s, %s)", obj_sqlval, obj_datatype, obj_language)); break;
    default:
      rdf_dbg_printf (("\ntf_triple_l (..., %s, %s)", obj_datatype, obj_language)); break;
    }
#endif
  BOX_AUTO_TYPED (void **, params, params_buf, sizeof (caddr_t) * 7, DV_ARRAY_OF_POINTER);
  params[0] = TF_GRAPH_ARG(tf);
  params[1] = &s_uri;
  params[2] = &p_uri;
  params[3] = &obj_sqlval;
  params[4] = &obj_datatype;
  params[5] = &obj_language;
  params[6] = &(tf->tf_app_env);
  err = qr_exec (tf->tf_qi->qi_client, cbk_qr, tf->tf_qi, NULL, NULL, NULL, (caddr_t *)params, NULL, 0);
  BOX_DONE (params, params_buf);
  tf->tf_triple_count++;
  if (!tf->tf_qi->qi_trx->lt_replica_of)
    tf->tf_qi->qi_trx->lt_replica_of = replica_of;
  else
    dk_free_box (replica_of);
  if (!(tf->tf_triple_count % TF_TRIPLE_PROGRESS_MESSAGE_MOD))
    tf_report (tf, 'P', NULL, NULL, "Loading is in progress");
  if (NULL != err)
    sqlr_resignal (err);
}

caddr_t
bif_rdf_load_turtle (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t str = bif_string_or_wide_or_null_or_strses_arg (qst, args, 0, "rdf_load_turtle");
  caddr_t base_uri = bif_string_or_uname_arg (qst, args, 1, "rdf_load_turtle");
  caddr_t graph_uri = bif_string_or_uname_or_wide_or_null_arg (qst, args, 2, "rdf_load_turtle");
  long flags = bif_long_arg (qst, args, 3, "rdf_load_turtle");
  caddr_t *cbk_names = bif_strict_type_array_arg (DV_STRING, qst, args, 4, "rdf_load_turtle");
  caddr_t *app_env = (caddr_t *) bif_arg (qst, args, 5, "rdf_load_turtle");
  caddr_t err = NULL;
  caddr_t res;
  if ((COUNTOF__TRIPLE_FEED__REQUIRED > BOX_ELEMENTS (cbk_names)) || (COUNTOF__TRIPLE_FEED__ALL < BOX_ELEMENTS (cbk_names)))
    sqlr_new_error ("22023", "RDF01",
      "The argument #4 of rdf_load_turtle() should be a vector of %d to %d names of stored procedures",
      COUNTOF__TRIPLE_FEED__REQUIRED, COUNTOF__TRIPLE_FEED__ALL );
  res = rdf_load_turtle (str, 0, base_uri, graph_uri, flags,
    (ccaddr_t *) cbk_names, app_env,
    (query_instance_t *)qst, QST_CHARSET(qst), &err );
  if (NULL != err)
    {
      dk_free_tree (res);
      sqlr_resignal (err);
    }
  return res;
}

caddr_t
bif_rdf_load_turtle_local_file (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t str = bif_string_arg (qst, args, 0, "rdf_load_turtle_local_file");
  caddr_t base_uri = bif_string_or_uname_arg (qst, args, 1, "rdf_load_turtle_local_file");
  caddr_t graph_uri = bif_string_or_uname_or_wide_or_null_arg (qst, args, 2, "rdf_load_turtle_local_file");
  long flags = bif_long_arg (qst, args, 3, "rdf_load_turtle_local_file");
  caddr_t *cbk_names = bif_strict_type_array_arg (DV_STRING, qst, args, 4, "rdf_load_turtle_local_file");
  caddr_t *app_env = (caddr_t *) bif_arg (qst, args, 5, "rdf_load_turtle_local_file");
  caddr_t err = NULL;
  caddr_t res;
  if ((COUNTOF__TRIPLE_FEED__REQUIRED > BOX_ELEMENTS (cbk_names)) || (COUNTOF__TRIPLE_FEED__ALL < BOX_ELEMENTS (cbk_names)))
    sqlr_new_error ("22023", "RDF01",
      "The argument #4 of rdf_load_turtle() should be a vector of %d to %d names of stored procedures",
      COUNTOF__TRIPLE_FEED__REQUIRED, COUNTOF__TRIPLE_FEED__ALL );
  file_path_assert (str, NULL, 0);
  res = rdf_load_turtle (str, 1, base_uri, graph_uri, flags,
    (ccaddr_t *) cbk_names, app_env,
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
  int mode_flags = ((1 < BOX_ELEMENTS(args)) ? bif_long_arg (qst, args, 1, "turtle_lex_analyze") : 0);
  return ttl_lex_analyze (str, mode_flags, QST_CHARSET(qst));
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
#define TRIG "t"

#define LAST(x) "L", (x)
#define LAST1(x) "K", (x)
#define MISS(x) "M", (x)
#define ERR(x)  "E", (x)

#define PUNCT_TTL_LAST(x) PUNCT(x), TTL, LAST(x)
#define PUNCT_TRIG_LAST(x) PUNCT(x), TRIG, LAST(x)


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
      int mode_bits = 0, last_lval, last1_lval;
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
	    case 's': mode_bits = 0; break;
	    case 't': mode_bits = TTLP_ALLOW_TRIG; break;
	    case 'K': case 'L': case 'M': case 'E':
	      cmd_idx++;
	      lexems = (caddr_t **) ttl_lex_analyze (ld->ld_tests[cmd_idx], mode_bits, QST_CHARSET(qst));
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




id_hashed_key_t iristrhash (char *strp);
int iristrhashcmp (char *x, char *y);


void
nic_set_n_ways (name_id_cache_t * nic, int n_ways)
{
  int inx, sz;
  if (!n_ways)
    GPF_T1 ("n_ways in nic_set_n_ways must be > 0.");
  sz = 1 + (nic->nic_size / n_ways);
  nic->nic_n_ways = n_ways;
  id_hash_free (nic->nic_name_to_id);
  nic->nic_name_to_id = NULL;
  hash_table_free_64 (nic->nic_id_to_name);
  nic->nic_id_to_name = NULL;
  nic->nic_in_array = (dk_hash_64_t**)dk_alloc_box (sizeof (caddr_t) * n_ways, DV_BIN);
  nic->nic_ni_array = (id_hash_t **)dk_alloc_box (sizeof (caddr_t) * n_ways, DV_BIN);
  nic->nic_ni_mtx = dk_alloc_box (sizeof (dk_mutex_t) * n_ways, DV_BIN);
  nic->nic_in_mtx = dk_alloc_box (sizeof (dk_mutex_t) * n_ways, DV_BIN);
  for (inx = 0; inx < n_ways; inx++)
    {
      nic->nic_in_array[inx] = hash_table_allocate_64 (sz);
      nic->nic_ni_array[inx] = id_hash_allocate (sz, sizeof (caddr_t), sizeof (caddr_t), iristrhash, iristrhashcmp);
      dk_mutex_init (&nic->nic_in_mtx[inx], MUTEX_TYPE_SHORT);
      mutex_option (&nic->nic_in_mtx[inx], "NICB_IN", NULL, NULL);
      dk_mutex_init (&nic->nic_ni_mtx[inx], MUTEX_TYPE_SHORT);
      mutex_option (&nic->nic_in_mtx[inx], "NICB_NI", NULL, NULL);
    }
}


#define NIC_IN_ID(nic, __n, id) {__n = ((uint32)id) % nic->nic_n_ways; mutex_enter (&nic->nic_in_mtx[__n]);}
#define NIC_LEAVE_ID(nic, __n) mutex_leave (&nic->nic_in_mtx[__n])
#define NIC_WAY_OF_HI(nic,hi) ((((uint32)hi) >> 8) % (nic)->nic_n_ways)
#define NIC_IN_NAME(nic, __n, name, __hi) { __hi = iristrhash (&name); __n = NIC_WAY_OF_HI(nic,hi); mutex_enter (&nic->nic_ni_mtx[__n]);}
#define NIC_LEAVE_NAME(nic, __n) mutex_leave (&nic->nic_ni_mtx[__n])

boxint
nic_name_id_n (name_id_cache_t * nic, char * name)
{
  boxint * place, res = 0;
  id_hashed_key_t hi = iristrhash ((char*)&name);
  int nth_name = NIC_WAY_OF_HI(nic,hi);
  mutex_enter (&nic->nic_ni_mtx[nth_name]);
  place = (boxint*) id_hash_get_with_hash_number (nic->nic_ni_array[nth_name], (caddr_t) &name, hi);
  if (place)
    res = *place;
  mutex_leave (&nic->nic_ni_mtx[nth_name]);
  return res;
}

caddr_t
DBG_NAME (nic_id_name_n) (DBG_PARAMS name_id_cache_t * nic, boxint id)
{
  caddr_t ret;
  boxint r;
  int nth_id;
  NIC_IN_ID (nic, nth_id, id);
  gethash_64 (r, id, nic->nic_in_array[nth_id]);
  ret = r ? DBG_NAME(box_copy) (DBG_ARGS (caddr_t)((ptrlong)r)) : NULL;
  /* read the value inside the mtx because cache replacement may del it before the copy is made if not in the mtx */
  NIC_LEAVE_ID (nic, nth_id);
  return ret;
}

static void
nic_remove_some_elements_n (name_id_cache_t * nic, int nth_name, char cachelet_mutex_locked)
{
/*  id_hashed_key_t hi = iristrhash (&name);
  int nth_name = NIC_WAY_OF_HI(nic,hi); */
  int nth_id, flag;
  if (!cachelet_mutex_locked)
    mutex_enter (&nic->nic_ni_mtx[nth_name]);

  while (nic->nic_ni_array[nth_name]->ht_count > nic->nic_size / nic->nic_n_ways)
    {
      nic_name_id_cache_element_t el;
      int32 rnd  = sqlbif_rnd (&tf_rnd_seed);
      el.nicel_name = NULL;
      if (id_hash_remove_rnd (nic->nic_ni_array[nth_name], rnd, (caddr_t)&el.nicel_name, (caddr_t)&el.nicel_id))
        {
          mutex_leave (&nic->nic_ni_mtx[nth_name]);

          NIC_IN_ID (nic, nth_id, el.nicel_id);
          remhash_64_f ( el.nicel_id, nic->nic_in_array[nth_id], flag);
	  if (!flag)
	    log_error ("missed delete of name id cache %s %L (%p %s)", el.nicel_name + 4, el.nicel_id, el.nicel_name, el.nicel_name);
          NIC_LEAVE_ID (nic, nth_id);

          if (/* IvAn/121009 nic->nic_is_boxes && */ flag)
            dk_free_box (el.nicel_name);

          mutex_enter (&nic->nic_ni_mtx[nth_name]);
        }
    }

  if (!cachelet_mutex_locked)
    mutex_leave (&nic->nic_ni_mtx[nth_name]);
}

static void
nic_remove_some_elements (name_id_cache_t * nic, char cache_mutex_locked)
{
  if (!cache_mutex_locked)
    mutex_enter (nic->nic_mtx);

  while (nic->nic_id_to_name->ht_count > nic->nic_size)
    {
      nic_name_id_cache_element_t el;
      int32 rnd  = sqlbif_rnd (&tf_rnd_seed);
      el.nicel_name = NULL;
      if (id_hash_remove_rnd (nic->nic_name_to_id, rnd, (caddr_t)&el.nicel_name, (caddr_t)&el.nicel_id))
        {
          remhash_64 ( el.nicel_id, nic->nic_id_to_name);
          dk_free_box (el.nicel_name);
        }
    }

  if (!cache_mutex_locked)
    mutex_leave (nic->nic_mtx);
}

void
nic_set_n (name_id_cache_t * nic, caddr_t name, boxint id)
{
  caddr_t name_box = NULL;
  caddr_t * place;
  id_hashed_key_t hi = iristrhash ((char*)&name);
  int nth_name = NIC_WAY_OF_HI(nic,hi);
  int nth_id;

  mutex_enter (&nic->nic_ni_mtx[nth_name]);

  place = (caddr_t*) id_hash_get_with_hash_number (nic->nic_ni_array[nth_name], (caddr_t)&name, hi);
  if(place) /* the key is found */
    {
      boxint old_id = *(boxint*)place;
      name_box = ((caddr_t*)place) [-1];

      if (old_id == id) /* we already have this name <-> id pair */
	{
	  mutex_leave (&nic->nic_ni_mtx[nth_name]);
	  return;
	}

      *(boxint*) place = id;

      mutex_leave (&nic->nic_ni_mtx[nth_name]);

      NIC_IN_ID (nic, nth_id, old_id);
      remhash_64 (old_id, nic->nic_in_array[nth_id]);
      NIC_LEAVE_ID (nic, nth_id);

      NIC_IN_ID (nic, nth_id, id);
      sethash_64 (id, nic->nic_in_array[nth_id],  (boxint)((ptrlong)(name_box)));
      NIC_LEAVE_ID (nic, nth_id);
    }
  else
    {
      /* free some space in the cache if there is not enough */
      nic_remove_some_elements_n (nic, nth_name, 1);

      name_box = nic->nic_is_boxes ? box_copy (name) : box_dv_short_string (name);

      id_hash_set_with_hash_number (nic->nic_ni_array[nth_name], (caddr_t)&name_box, (caddr_t)&id, hi);

      mutex_leave (&nic->nic_ni_mtx[nth_name]);

      NIC_IN_ID (nic, nth_id, id);
      sethash_64 (id, nic->nic_in_array[nth_id], (boxint)((ptrlong)(name_box)));
      NIC_LEAVE_ID (nic, nth_id);
    }
}

void
nic_set (name_id_cache_t * nic, caddr_t name, boxint id)
{
  caddr_t name_box = NULL;
  caddr_t *place;
  if (nic->nic_n_ways)
    {
      nic_set_n (nic, name, id);
    }
  else
    {
      mutex_enter (nic->nic_mtx);
      place = (caddr_t *) id_hash_get (nic->nic_name_to_id, (caddr_t) & name);
      if (place)
	{
	  boxint old_id = *(boxint *) place;
	  name_box = ((caddr_t *) place)[-1];
	  *(boxint *) place = id;
	  remhash_64 (old_id, nic->nic_id_to_name);
	  sethash_64 (id, nic->nic_id_to_name, (boxint) ((ptrlong) (name_box)));
	}
      else
	{
	  nic_remove_some_elements (nic, 1);
	  name_box = nic->nic_is_boxes ? box_copy (name) : box_dv_short_string (name);
	  id_hash_set (nic->nic_name_to_id, (caddr_t) & name_box, (caddr_t) & id);
	  sethash_64 (id, nic->nic_id_to_name, (boxint) ((ptrlong) (name_box)));
	}
      mutex_leave (nic->nic_mtx);
    }
}


boxint
nic_name_id (name_id_cache_t * nic, char * name)
{
  boxint * place, res = 0;
  if (nic->nic_n_ways)
    return nic_name_id_n (nic, name);
  if (nic->nic_is_boxes)
    {
      id_hashed_key_t hi = iristrhash ((char*)&name);
      mutex_enter (nic->nic_mtx);
      place = (boxint*) id_hash_get_with_hash_number (nic->nic_name_to_id, (caddr_t) &name, hi);
      if (place)
	res = *place;
      mutex_leave (nic->nic_mtx);
      return res;
    }
  mutex_enter (nic->nic_mtx);
  place = (boxint*) id_hash_get (nic->nic_name_to_id, (caddr_t) &name);
  if (place)
    res = *place;
  mutex_leave (nic->nic_mtx);
  return res;
}

void
nic_merge_n (name_id_cache_t * to, name_id_cache_t * from)
{
  int inx;
  id_hash_iterator_t hit;
  caddr_t * pn;
  boxint * pid;
  for (inx = 0; inx < from->nic_n_ways; inx++)
    {
      id_hash_iterator (&hit, from->nic_ni_array[inx]);
      while (hit_next (&hit, (caddr_t*)&pn, (caddr_t*)&pid))
        {
          nic_set (to, *pn, *pid);
          dk_free_box (*pn);
        }
      id_hash_clear (from->nic_ni_array[inx]);
      id_hash_clear (from->nic_in_array[inx]);
    }
}

void
nic_merge (name_id_cache_t * to, name_id_cache_t * from)
{
  id_hash_iterator_t hit;
  caddr_t * pn;
  boxint * pid;

  if (from->nic_n_ways)
    {
      nic_merge_n ( to, from );
      return;
    }

  id_hash_iterator (&hit, from->nic_name_to_id);
  while (hit_next (&hit, (caddr_t*)&pn, (caddr_t*)&pid))
    {
      nic_set (to, *pn, *pid);
      dk_free_box (*pn);
    }
  id_hash_clear (from->nic_name_to_id);
  id_hash_clear (from->nic_id_to_name);
}

void
nic_clear_n (name_id_cache_t * nic)
{
  int inx;
  for (inx = 0; inx < nic->nic_n_ways; inx++)
    {
      id_hash_iterator_t hit;
      caddr_t * pn;
      boxint * pid;
      id_hash_iterator (&hit, nic->nic_ni_array[inx]);
      while (hit_next (&hit, (caddr_t*)&pn, (caddr_t*)&pid))
        {
          dk_free_box (*pn);
        }
      id_hash_clear (nic->nic_ni_array[inx]);
      id_hash_clear (nic->nic_in_array[inx]);
    }
}

void
nic_clear (name_id_cache_t * nic)
{
  id_hash_iterator_t hit;
  caddr_t * pn;
  boxint * pid;
  if (nic->nic_n_ways)
    {
      nic_clear_n (nic);
      return;
    }
  id_hash_iterator (&hit, nic->nic_name_to_id);
  while (hit_next (&hit, (caddr_t*)&pn, (caddr_t*)&pid))
    {
      dk_free_box (*pn);
    }
  id_hash_clear (nic->nic_name_to_id);
  id_hash_clear (nic->nic_id_to_name);
}

void
nic_free (name_id_cache_t * nic)
{
  nic_clear (nic);
  if (nic->nic_name_to_id)
  id_hash_free (nic->nic_name_to_id);
  if (nic->nic_id_to_name)
  id_hash_free (nic->nic_id_to_name);

  if (nic->nic_n_ways)
    {
      int inx;
      for (inx = 0; inx < nic->nic_n_ways; inx++)
        {
          hash_table_free_64 (nic->nic_in_array[inx]);
          id_hash_free (nic->nic_ni_array[inx]);
          mutex_free (&nic->nic_in_mtx[inx]);
          mutex_free (&nic->nic_ni_mtx[inx]);
        }
      dk_free ( nic->nic_ni_mtx, sizeof (dk_mutex_t) * nic->nic_n_ways );
      dk_free ( nic->nic_in_mtx, sizeof (dk_mutex_t) * nic->nic_n_ways );
      dk_free ( nic->nic_in_array, sizeof (caddr_t) * nic->nic_n_ways );
      dk_free ( nic->nic_ni_array, sizeof (caddr_t) * nic->nic_n_ways );
    }

  mutex_free (nic->nic_mtx);
  dk_free ((caddr_t)nic, sizeof (name_id_cache_t));
}

resource_t * iri_nic_rc;
resource_t * prefix_nic_rc;

void
nic_done (resource_t * rc, name_id_cache_t * nic)
{
  if (11 == nic->nic_name_to_id->ht_buckets)
    resource_store (rc, (void*) nic);
  else
    nic_free (nic);
}


void
lt_nic_commit_hook (lock_trx_t * lt)
{
  if (lt->lt_rdf_prefix)
    {
      nic_merge (iri_prefix_cache, lt->lt_rdf_prefix);
      nic_done (prefix_nic_rc, lt->lt_rdf_prefix);
      lt->lt_rdf_prefix = NULL;
    }
  if (lt->lt_rdf_iri)
    {
      nic_merge (iri_name_cache, lt->lt_rdf_iri);
      nic_done (iri_nic_rc, lt->lt_rdf_iri);
      lt->lt_rdf_iri = NULL;
    }
}


void
lt_nic_rollback_hook (lock_trx_t * lt)
{
  if (lt->lt_rdf_prefix)
    {
      nic_done (prefix_nic_rc, lt->lt_rdf_prefix);
      lt->lt_rdf_prefix = NULL;
    }
  if (lt->lt_rdf_iri)
    {
      nic_done (iri_nic_rc, lt->lt_rdf_iri);
      lt->lt_rdf_iri = NULL;
    }
}


caddr_t
DBG_NAME(nic_id_name) (DBG_PARAMS name_id_cache_t * nic, boxint id)
{
  caddr_t ret;
  boxint r;
  if (nic->nic_n_ways)
    return DBG_NAME(nic_id_name_n) (DBG_ARGS nic, id);
  mutex_enter (nic->nic_mtx);
  gethash_64 (r, id, nic->nic_id_to_name);
  ret = r ? DBG_NAME (box_copy) (DBG_ARGS (caddr_t) (ptrlong)r) : NULL;
  /* read the value inside the mtx because cache replacement may del it before the copy is made if not in the mtx */
  mutex_leave(nic->nic_mtx);
  return ret;
}


id_hashed_key_t
iristrhash (char *strp)
{
  char *str = *(char **) strp;
  int l = box_length (str) - 1;
  uint64 h = 1;
  MHASH_VAR (h, str, l);
  return h & 0x7fffffff;
}

int
iristrhashcmp (char *x, char *y)
{
  char * str1 = *(caddr_t *) x;
  char * str2 = *(caddr_t *) y;
  int l = box_length (str1);
  if (l != box_length (str2))
    return 0;
  l--;
  memcmp_8 (str1, str2, l, neq);
  return 1;
 neq:
  return 0;
}



name_id_cache_t *
nic_allocate (unsigned long sz, int is_box, int ht_init_sz)
{
  NEW_VARZ (name_id_cache_t, nic);
  nic->nic_size = sz;
  if (ht_init_sz)
    sz = ht_init_sz * 2;
  nic->nic_is_boxes = is_box;
  if (!is_box)
    nic->nic_name_to_id = id_hash_allocate (sz / 2, sizeof (caddr_t), sizeof (boxint), strhash, strhashcmp);
  else
    nic->nic_name_to_id = id_hash_allocate (sz, sizeof (caddr_t), sizeof (boxint), iristrhash, iristrhashcmp);
  nic->nic_id_to_name = hash_table_allocate_64 (sz);
  id_hash_set_rehash_pct (nic->nic_id_to_name, 220);
  id_hash_set_rehash_pct (nic->nic_name_to_id, 220);
  nic->nic_mtx =mutex_allocate ();
  mutex_option (nic->nic_mtx, is_box ? "NICB" : "NIC", NULL, NULL);
  return nic;
}

void
nic_flush_n (name_id_cache_t * nic)
{
  dk_set_t removed_keys = NULL;
  int bucket_ctr = 0, inx;
  int nth_id;

  for (inx = 0; inx < nic->nic_n_ways; inx++)
    {
      mutex_enter (&nic->nic_ni_mtx[inx]);

      for (bucket_ctr = nic->nic_ni_array[inx]->ht_buckets; bucket_ctr--; /* no step */)
        {
          nic_name_id_cache_element_t el;
          while (id_hash_remove_rnd (nic->nic_ni_array[inx], bucket_ctr, (caddr_t)&el.nicel_name, (caddr_t)&el.nicel_id))
            {
              nic_name_id_cache_element_t *new_el = dk_alloc( sizeof(nic_name_id_cache_element_t) );
              memcpy ( new_el, &el, sizeof(nic_name_id_cache_element_t) );
              dk_set_push ( &removed_keys, new_el );
            }
        }

      mutex_leave(&nic->nic_ni_mtx[inx]);
    }

  DO_SET(nic_name_id_cache_element_t*,el,&removed_keys)
  {
    NIC_IN_ID ( nic, nth_id, el->nicel_id );
    remhash_64 ( el->nicel_id, nic->nic_in_array[nth_id]);
    dk_free_box (el->nicel_name);
    dk_free (el, sizeof(nic_name_id_cache_element_t));
    NIC_LEAVE_ID( nic, nth_id);
  }
  END_DO_SET();
  dk_set_free(removed_keys);
}

void
nic_flush (name_id_cache_t * nic)
{
  int bucket_ctr = 0;
  if (nic->nic_n_ways)
  {
    nic_flush_n (nic);
    return;
  }
  mutex_enter (nic->nic_mtx);
  for (bucket_ctr = nic->nic_name_to_id->ht_buckets; bucket_ctr--; /* no step */)
    {
      caddr_t key;
      boxint id;
      while (id_hash_remove_rnd (nic->nic_name_to_id, bucket_ctr, (caddr_t)&key, (caddr_t)&id))
        {
          remhash_64 ( id, nic->nic_id_to_name);
          dk_free_box (key);
        }
    }
  mutex_leave (nic->nic_mtx);
}


void
lt_nic_set (lock_trx_t * lt, name_id_cache_t * nic, caddr_t name, boxint id)
{
  if (iri_name_cache == nic)
    {
      if (lt && !lt->lt_client->cli_row_autocommit)
	{
	  if (!lt->lt_rdf_iri)
	    {
	      lt->lt_rdf_iri = (name_id_cache_t*) resource_get (iri_nic_rc);
	      if (!lt->lt_rdf_iri)
		lt->lt_rdf_iri = nic_allocate (140000, 1, 11);
	      lt->lt_commit_hook = lt_nic_commit_hook;
	      lt->lt_rollback_hook = lt_nic_rollback_hook;
	    }
	  nic_set (lt->lt_rdf_iri, name, id);
	}
      else
	nic_set (iri_name_cache, name, id);
    }
  else
    {
      if (lt && !lt->lt_client->cli_row_autocommit)
	{
	  if (!lt->lt_rdf_prefix)
	    {
	      lt->lt_rdf_prefix = (name_id_cache_t*) resource_get (prefix_nic_rc);
	      if (!lt->lt_rdf_prefix)
		lt->lt_rdf_prefix = nic_allocate (4000, 0, 11);
	      lt->lt_commit_hook = lt_nic_commit_hook;
	      lt->lt_rollback_hook = lt_nic_rollback_hook;
	    }
	  nic_set (lt->lt_rdf_prefix, name, id);
	}
      else
	nic_set (iri_prefix_cache, name, id);
    }
}


boxint
lt_nic_name_id (lock_trx_t * lt, name_id_cache_t * nic, caddr_t name)
{
  name_id_cache_t * lt_nic = lt->lt_client->cli_row_autocommit ? NULL
    : nic == iri_name_cache ? lt->lt_rdf_iri : lt->lt_rdf_prefix;
  if (lt_nic)
    {
      boxint id = nic_name_id (lt_nic, name);
      if (id)
	return id;
    }
  return nic_name_id (nic, name);
}

#if 0
boxint
nic_prefix_local (lock_trx_t * lt, name_id_cache_t * nic, caddr_t name)
{
  name_id_cache_t * lt_nic = lt->lt_client->cli_row_autocommit ? NULL
    : nic == iri_name_cache ? lt->lt_rdf_iri : lt->lt_rdf_prefix;
  if (lt_nic)
    {
      boxint id = nic_name_id (lt_nic, name);
      if (id)
	return id;
    }
  return nic_name_id (nic, name);
}
#endif

caddr_t
DBG_NAME(lt_nic_id_name) (DBG_PARAMS lock_trx_t * lt, name_id_cache_t * nic, boxint id)
{
  name_id_cache_t * lt_nic = lt->lt_client->cli_row_autocommit ? NULL
    : nic == iri_name_cache ? lt->lt_rdf_iri : lt->lt_rdf_prefix;
  if (lt_nic)
    {
      caddr_t name = DBG_NAME(nic_id_name) (DBG_ARGS lt_nic, id);
      if (name)
	return name;
    }
  return DBG_NAME(nic_id_name) (DBG_ARGS nic, id);
}



#define IS_INT_LIKE(x) ((x) == DV_LONG_INT || (x) == DV_INT64 || (x) == DV_IRI_ID || (x) == DV_IRI_ID_8)


int
tb_string_and_id_check (dbe_table_t * tb, dbe_column_t ** str_col, dbe_column_t ** id_col)
{
  /* true if tb has string pk and int dependent and another key with the reverse */
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

int32 iri_range_size = 1000000;
#define N_IRI_SEQS 19
#define IRI_RANGE_SZ iri_range_size

extern dk_mutex_t * log_write_mtx;


boxint
rdf_new_iri_id (lock_trx_t * lt, char ** value_seq_ret, int nth, query_instance_t * qi)
{
  int rc;
  caddr_t log_array, * old_repl;
  static caddr_t iri_seq[N_IRI_SEQS];
  static caddr_t iri_seq_max[N_IRI_SEQS];
  static caddr_t range_seq;
  boxint id, id_max;
  if (-1 == nth)
    {
      du_thread_t * self = THREAD_CURRENT_THREAD;
      nth = (((uptrlong)self) ^ (((uptrlong)self) >> 11))
      % N_IRI_SEQS;
    }
  else
    nth = ((unsigned int)nth) % N_IRI_SEQS;
  if (!range_seq)
    {
      int inx;
      for (inx = 0; inx < N_IRI_SEQS; inx++)
	{
	  char name[20];
	  sprintf (name, "__IRI%d", inx);
	  iri_seq[inx] = box_dv_short_string (name);
	  sprintf (name, "__IRI_MAX%d", inx);
	  iri_seq_max[inx] = box_dv_short_string (name);
	}
      range_seq = box_dv_short_string ("RDF_URL_IID_NAMED");
    }
  IN_TXN;
  id = sequence_next_inc (iri_seq[nth], INSIDE_MAP, 1);
  id_max = sequence_set (iri_seq_max[nth], 0, SEQUENCE_GET, INSIDE_MAP);
  if (id < id_max)
    {
      LEAVE_TXN;
      *value_seq_ret = iri_seq[nth];
      return id;
    }
    id = sequence_next_inc (range_seq, INSIDE_MAP, IRI_RANGE_SZ);
  if (!id)
    sequence_set (range_seq, IRI_RANGE_SZ, SET_ALWAYS, INSIDE_MAP);
  sequence_set (iri_seq[nth], id + 1, SET_ALWAYS, INSIDE_MAP);
  sequence_set (iri_seq_max[nth], id + IRI_RANGE_SZ, SET_ALWAYS, INSIDE_MAP);
  LEAVE_TXN;
  if (!in_srv_global_init)
    {
      log_array = list (5, box_string ("DB.DBA.ID_RANGE_REPLAY (?, ?, ?, ?)"),
	  box_dv_short_string (iri_seq[nth]), box_dv_short_string (iri_seq_max[nth]),
	  box_num (id), box_num (id + IRI_RANGE_SZ));
      mutex_enter (log_write_mtx);
      old_repl = lt->lt_replicate;
      lt->lt_replicate = REPL_LOG;
      rc = log_text_array_sync (lt, log_array);
      lt->lt_replicate = old_repl;
      mutex_leave (log_write_mtx);
      dk_free_tree (log_array);
      if (rc != LTE_OK)
	{
	  static caddr_t details = NULL;
	  if (NULL == details)
	    details = box_dv_short_string ("while writing new IRI_ID range allocation to log file");
	  /*      if (lt->lt_client != bootstrap_cli) */
	  sqlr_resignal (srv_make_trx_error (rc, details));
	}
    }

  *value_seq_ret = iri_seq[nth];
  return id;
}



caddr_t
tb_new_id_and_name (lock_trx_t * lt, it_cursor_t * itc, dbe_table_t * tb, caddr_t name, char * value_seq_name)
{
  int rc;
  caddr_t log_array;
  dbe_key_t * id_key = (dbe_key_t *)(tb->tb_keys->data == tb->tb_primary_key ? tb->tb_keys->next->data : tb->tb_keys->data);
  caddr_t seq_box = box_dv_short_string (value_seq_name);
  int64 res = 0 == strcmp ("RDF_URL_IID_NAMED", seq_box)
    ? rdf_new_iri_id (lt, &value_seq_name, lt->lt_trx_no, NULL) : sequence_next_inc (seq_box, OUTSIDE_MAP, 1);
  dbe_column_t * id_col = (dbe_column_t *)id_key->key_parts->data;
  caddr_t res_box;
  LOCAL_RD (rd);
  if (!res)
    res = sequence_next_inc (seq_box, OUTSIDE_MAP, 1);
  dk_free_box (seq_box);
  res_box = box_iri_int64 (res, id_col->col_sqt.sqt_dtp);
  itc->itc_insert_key = tb->tb_primary_key;
  itc->itc_owned_search_par_fill= 0; /* do not free the name yet */
  itc_from (itc, itc->itc_insert_key, QI_NO_SLICE);
  ITC_SEARCH_PARAM(itc, name);
  ITC_OWNS_PARAM(itc, name);
  rd.rd_non_comp_len = itc->itc_insert_key->key_row_var_start[0] + box_length (name) - 1;
  rd.rd_n_values = 2;
  rd.rd_values[0] = name;
  rd.rd_values[1] = res_box;
  itc->itc_key_spec = itc->itc_insert_key->key_insert_spec;
  itc_insert_unq_ck (itc, &rd, NULL);
  rd.rd_values[0] = res_box;
  rd.rd_values[1] = name;
  itc->itc_insert_key = id_key;
  rd.rd_non_comp_len = itc->itc_insert_key->key_row_var_start[0] + box_length (name) - 1;
  itc->itc_owned_search_par_fill = 0; /* do not free the name yet */
  itc_from (itc, itc->itc_insert_key, QI_NO_SLICE);
  ITC_SEARCH_PARAM(itc, res_box);
  ITC_SEARCH_PARAM(itc, name);
  ITC_OWNS_PARAM (itc, name);
  itc->itc_key_spec = itc->itc_insert_key->key_insert_spec;

  itc_insert_unq_ck (itc, &rd, NULL);
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
  return res_box;
}


caddr_t
tb_cl_name_to_id (lock_trx_t * lt, it_cursor_t * itc)
{
  return (caddr_t) -1; /* is local, go ahead */
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
  itc_from (itc, key, QI_NO_SLICE);
  ITC_SEARCH_PARAM (itc, name);
  ITC_OWNS_PARAM(itc, name);
  if(lt)
    itc->itc_isolation =ISO_COMMITTED;
  else
    itc->itc_isolation = ISO_UNCOMMITTED;
  itc->itc_search_mode = SM_INSERT;
  itc->itc_key_spec = key->key_insert_spec;
  if (itc->itc_insert_key->key_partition)
    {
      sqlr_new_error ("42000", "CL...", "tb_cl_name_to_id is not to be run. Problem of initializing partitioned db with local only mode.");
      iri = tb_cl_name_to_id (lt, itc);
      if ((caddr_t)-1 != iri)
	{
	  itc_free (itc);
	  return iri;
	}
    }
  ITC_FAIL (itc)
    {
re_search:
      buf = itc_reset (itc);
      res = itc_search (itc, &buf);
      if (DVC_MATCH == res)
	{
	  KEY_TOUCH (itc->itc_insert_key);
	  iri = itc_box_column (itc, buf, iri_col->col_id, NULL);
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
	  if (ITC_AT_END == itc->itc_map_pos)
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
	du_thread_t * self = THREAD_CURRENT_THREAD;
	itc_free (itc);
	if (!lt || !self->thr_reset_ctx)
	  return NULL;
      }
  END_FAIL (itc);
  itc_free (itc);
  return iri;
}

int32 rdf_shorten_long_iri = 0;

static const char ctohex[] = "0123456789abcdef";

static char *
iri_shorten (char * iri, char * buf, size_t buf_len, int * ret_len)
{
  unsigned char digest[16];
  MD5_CTX ctx;
  int inx = 0;
  char *end = buf + buf_len - 1, *tail = buf + buf_len - 33, *str = iri + buf_len - 33;

  memcpy (buf, iri, buf_len - 33); /* hex md5 + zero byte */
  memset (&ctx, 0, sizeof (MD5_CTX));
  MD5Init (&ctx);
  MD5Update (&ctx, (unsigned char *) str, strlen (str));
  MD5Final (digest, &ctx);
  while (tail < end)
    {
      unsigned c = (unsigned) digest[inx++];
      *(tail++) = ctohex[0xf & (c >> 4)];
      *(tail++) = ctohex[0xf & c];
    }
  *tail = 0;
  *ret_len = strlen (buf);
  return buf;
}

int
iri_split (char * iri, caddr_t * pref, caddr_t * name)
{
  char * local_start;
  int len = strlen (iri);
  char tmp[MAX_RULING_PART_BYTES - 20];
  if (len > MAX_RULING_PART_BYTES - 20)
    {
      if (rdf_shorten_long_iri)
	iri = iri_shorten (iri, tmp, sizeof (tmp), &len);
      else
    return 0;
    }
  if (('_' == iri[0]) && (':' == iri[1]))
    { /* named blank node is a special case. Label can contain weird chars but it is treated as */
      local_start = iri + 2;
      goto local_start_found; /* see below */
    }
  local_start = strrchr (iri, '#');
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

local_start_found:
  *pref = box_dv_short_nchars (iri, local_start - iri);
  *name = box_dv_short_nchars (local_start - 4, 4 + strlen (local_start));
  return 1;
}

void
iri_split_ttl_qname (const char * iri, caddr_t * pref_ret, caddr_t * name_ret, int abbreviate_nodeid)
{
  const char *tail;
  int iri_strlen;
  if (!iri)
    {
      *name_ret = box_dv_short_string ("null_iri");
      *pref_ret = box_dv_short_string ("null_prefix");
	return;
    }
  iri_strlen = strlen (iri);
  for (tail = iri + iri_strlen; tail > iri; tail--)
    {
      unsigned char c = (unsigned char) tail[-1];
      if (!isalnum(c) && ('_' != c) && ('-' != c) && !(c & 0x80))
        break;
    }
  if (isdigit (tail[0]) || ('-' == tail[0]) || ((tail > iri) && (NULL == strchr ("#/:?", tail[-1]))))
    tail = iri + iri_strlen;
/*                                                         0123456789 */
  if (abbreviate_nodeid && (tail-iri >= 9) && !memcmp (iri, "nodeID://", 9))
    {
      int boxlen = (tail - iri) - (9 - 1);
      caddr_t pref = pref_ret[0] = dk_alloc_box (boxlen, DV_STRING);
      pref[0] = '_';
      memcpy (pref + 1, iri + 9, tail - (iri + 9));
      pref[boxlen-1] = '\0';
    }
  else
    pref_ret[0] = box_dv_short_nchars (iri, tail - iri);
  name_ret[0] = box_dv_short_nchars (tail, iri + iri_strlen - tail);
}

name_id_cache_t * iri_name_cache;
name_id_cache_t * iri_prefix_cache;
name_id_cache_t * rdf_lang_cache;
name_id_cache_t * rdf_type_cache;

caddr_t
key_name_to_iri_id_1 (lock_trx_t * lt, caddr_t name, int make_new)
{
  boxint pref_id_no, iri_id_no;
  caddr_t local_copy;
  caddr_t prefix, local;
  caddr_t pref_id, iri_id;
  if (DV_IRI_ID == DV_TYPE_OF (name))
    return box_copy (name);
#ifdef DEBUG
/*                                             01234567 */
  if (uriqa_dynamic_local && !strncmp (name, "http://", 7))
    {
      const char *regname = "URIQADefaultHost";
      caddr_t *host_ptr;
      IN_TXN;
      ASSERT_IN_TXN;
      host_ptr = (caddr_t *) id_hash_get (registry, (caddr_t) & regname);
      LEAVE_TXN;
      if ((NULL != host_ptr) && IS_BOX_POINTER (host_ptr[0]))
        {
          caddr_t host = host_ptr[0];
          int host_strlen = strlen (host);
          if (!strncmp (name + 7, host, host_strlen) && ('/' == name[7+host_strlen]))
            {
              printf ("\nOops, %s in key_name_to_iri_id()", name);
            }
        }
    }
#endif
  if (CL_RUN_SINGLE_CLUSTER == cl_run_local_only)
    return NULL;
  if (!iri_split (name, &prefix, &local))
    return NULL;
  pref_id_no = lt_nic_name_id (lt, iri_prefix_cache, prefix);
  if (!pref_id_no)
    {
      caddr_t pref_copy;
      pref_copy = box_copy (prefix);
      pref_id = tb_name_to_id (lt, "DB.DBA.RDF_PREFIX", prefix, make_new ? "RDF_PREF_SEQ" : NULL);
      if (!pref_id)
	{
	  dk_free_box (pref_copy);
	  dk_free_box (local);
	  return NULL;
	}
      pref_id_no = unbox (pref_id);
      lt_nic_set (lt, iri_prefix_cache, pref_copy, pref_id_no);
      dk_free_box (pref_id);
      dk_free_box (pref_copy);
    }
  else
    dk_free_box (prefix);
  LONG_SET_NA (local, pref_id_no);
  iri_id_no = lt_nic_name_id (lt, iri_name_cache, local);
  if (iri_id_no)
    {
      dk_free_box (local);
      return box_iri_id (iri_id_no);
    }
  local_copy = box_copy (local);
  iri_id = tb_name_to_id (lt, "DB.DBA.RDF_IRI", local,
    (  make_new ?
      ((('_' == name[0]) && (':' == name[1])) ?
        "RDF_URL_IID_NAMED_BLANK" : "RDF_URL_IID_NAMED" ) :
      NULL ) );
  if(!iri_id)
    {
      dk_free_box (local_copy);
      return NULL;
    }
  lt_nic_set (lt, iri_name_cache, local_copy, unbox_iri_id (iri_id));
  dk_free_box (local_copy);
  return iri_id;
}


caddr_t
key_name_to_iri_id (lock_trx_t * lt, caddr_t name, int make_new)
{
  caddr_t r;
  mem_pool_t * mp;
  int entered = 0;
  if (!lt)
    {
      int rc;
      client_connection_t * cli = sqlc_client ();
      lt = cli->cli_trx;
      if (0 == cli->cli_trx->lt_threads)
	{
	  entered = 1;
	  rc = lt_enter (cli->cli_trx);
	  if (LTE_OK != rc)
	    return NULL;
    }
    }
  /* can be called from compiler, can do a cluster req and can potentially service recursive req so where can lose the tmp pool so save */
  mp = THR_TMP_POOL;
  r = key_name_to_iri_id_1 (lt, name, make_new);
  SET_THR_TMP_POOL (mp);
  if (entered)
    {
      IN_TXN;
      lt_leave (lt);
      LEAVE_TXN;
    }
  return r;
}

dbe_key_t * sch_find_key (dbe_schema_t * sc, char * tb_name, char * key_name);


int64
key_find_rdf_obj_1 (rdf_box_t * rb, caddr_t name)
{
  int res;
  int64 id = 0;
  caddr_t id_box = NULL;
  dbe_key_t * key = sch_find_key (NULL, "DB.DBA.RDF_OBJ", "RO_VAL");
  dbe_column_t * val_col;
  dbe_column_t * dtlang_col;
  dbe_column_t * id_col;
  it_cursor_t itc_auto;
  it_cursor_t * itc = &itc_auto;
  caddr_t dtlang = box_num ((rb->rb_type << 16) | rb->rb_lang);
  buffer_desc_t * buf;
  search_spec_t sp, sp2;
  rb_dt_lang_check(rb);
  if (dk_set_length (key->key_parts) < 3)
    return 0;
  id_col = (dbe_column_t*)key->key_parts->next->next->data;
  val_col = (dbe_column_t*)key->key_parts->data;
  dtlang_col = (dbe_column_t*)key->key_parts->next->next->data;
  ITC_INIT (itc, key->key_fragments[0]->kf_it, NULL);
  itc_from (itc, key, QI_NO_SLICE);
  ITC_SEARCH_PARAM (itc, name);
  ITC_SEARCH_PARAM (itc, dtlang);
  ITC_OWNS_PARAM (itc, dtlang);
  itc->itc_isolation = ISO_UNCOMMITTED;
  itc->itc_key_spec.ksp_spec_array = &sp;
  itc->itc_key_spec.ksp_key_cmp = NULL;
  memset (&sp, 0, sizeof (sp));
  sp.sp_min_op = CMP_EQ;
  sp.sp_cl = *key_find_cl (key, ((dbe_column_t *) key->key_parts->data)->col_id);
  memset (&sp2, 0, sizeof (sp2));
  sp2.sp_min_op = CMP_EQ;
  sp2.sp_min = 1;
  sp2.sp_cl = *key_find_cl (key, ((dbe_column_t *) key->key_parts->next->data)->col_id);
  sp.sp_next = &sp2;
  ITC_FAIL (itc)
    {
      buf = itc_reset (itc);
      res = itc_search (itc, &buf);
      if (DVC_MATCH == res)
	{
	  id_box = itc_box_column (itc, buf, id_col->col_id, NULL);
	  id = unbox (id_box);
	  dk_free_box (id_box);
	}
      itc_page_leave (itc, buf);
    }
	ITC_FAILED
      {
	return 0;
      }
  END_FAIL (itc);
  itc_free (itc);
  return id;
}


rdf_box_t *
key_find_rdf_obj (lock_trx_t * lt, rdf_box_t * rb)
{
  int len;
  caddr_t allocd_content = NULL;
  int entered = 0;

  if (!lt)
    {
      int rc;
      client_connection_t * cli = sqlc_client ();
      lt = cli->cli_trx;
      if (0 == cli->cli_trx->lt_threads)
	{
	  entered = 1;
	  rc = lt_enter (cli->cli_trx);
	  if (LTE_OK != rc)
	    return rb;
	}
    }
  {
    caddr_t content = rb->rb_box;
    dtp_t cdtp = DV_TYPE_OF (content);

    if (DV_XML_ENTITY == cdtp && rb->rb_chksum_tail)
      {
	QNCAST (rdf_bigbox_t, rbb, rb);
	dk_check_tree (rbb->rbb_chksum);
	rb->rb_ro_id = key_find_rdf_obj_1 (rb, rbb->rbb_chksum);
      }
    else
      {
	if (DV_GEO == cdtp)
	  {
	    caddr_t err = NULL;
	    content = box_to_any (content, &err);
	    allocd_content = content;
	  }
	len = box_length (content) - 1;
	if (len > RB_BOX_HASH_MIN_LEN)
	  {
	    caddr_t trid = mdigest5 (content);
	    rb->rb_ro_id = key_find_rdf_obj_1 (rb, trid);
	    dk_free_box (trid);
	  }
	else
	  rb->rb_ro_id = key_find_rdf_obj_1 (rb, rb->rb_box);
	dk_free_box (allocd_content);
      }
  }
  if (entered)
    {
      IN_TXN;
      lt_leave (lt);
      LEAVE_TXN;
    }
  return rb;
}


caddr_t
key_name_to_existing_cached_iri_id (lock_trx_t * lt, caddr_t name)
{
  boxint pref_id_no, iri_id_no;
  caddr_t prefix, local;
  if (DV_IRI_ID == DV_TYPE_OF (name))
    return box_copy (name);
  if (!iri_split (name, &prefix, &local))
    return NULL;
#ifndef NDEBUG
/*                                             01234567 */
  if (uriqa_dynamic_local && !strncmp (name, "http://", 7))
    {
      const char *regname = "URIQADefaultHost";
      caddr_t *host_ptr;
      IN_TXN;
      ASSERT_IN_TXN;
      host_ptr = (caddr_t *) id_hash_get (registry, (caddr_t) & regname);
      LEAVE_TXN;
      if ((NULL != host_ptr) && IS_BOX_POINTER (host_ptr[0]))
        {
          caddr_t host = host_ptr[0];
          int host_strlen = strlen (host);
          if (!strncmp (name + 7, host, host_strlen) && ('/' == name[7+host_strlen]))
            {
              printf ("\nOops, %s in key_name_to_existing_cached_iri_id()", name);
            }
        }
    }
#endif
  pref_id_no = lt_nic_name_id (lt, iri_prefix_cache, prefix);
  dk_free_box (prefix);
  if (!pref_id_no)
    {
      dk_free_box (local);
      return NULL;
    }
  LONG_SET_NA (local, pref_id_no);
  iri_id_no = lt_nic_name_id (lt, iri_name_cache, local);
  dk_free_box (local);
  if (!iri_id_no)
    return NULL;
  return box_iri_id (iri_id_no);
}




caddr_t
bif_iri_id_new (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t *) qst;
  boxint id;
  caddr_t value_seq;
  int nth = -1;
  if (BOX_ELEMENTS (args))
    nth = bif_long_arg (qst, args, 0, "iri_id_new");
  else
    nth = qi->qi_client->cli_trx->lt_trx_no;
  id = rdf_new_iri_id (qi->qi_trx, &value_seq, nth, (query_instance_t *)qst);
  log_sequence (qi->qi_trx, value_seq, id + 1);
  return box_iri_id (id);
}

int
iri_canonicalize (query_instance_t *qi, caddr_t name, int mode, caddr_t *res_ret, caddr_t *err_ret)
{
  dtp_t dtp = DV_TYPE_OF (name);
  dtp_t orig_dtp = dtp;
  caddr_t box_to_delete = NULL;
  res_ret[0] = NULL;
again:
  switch (dtp)
    {
    case DV_DB_NULL:
      return 0;
    case DV_IRI_ID:
      res_ret[0] = name;
      return 1;
    case DV_WIDE:
      box_to_delete = name = box_wide_as_utf8_char (name, (box_length (name) / sizeof (wchar_t)) - 1, DV_STRING);
      break;
    case DV_XML_ENTITY:
      {
        xml_entity_t *xe = (xml_entity_t *)name;
        box_to_delete = NULL;
        xe_string_value_1 (xe, &box_to_delete, DV_STRING);
        if (NULL == box_to_delete)
          {
            err_ret[0] = srv_make_new_error ("RDFXX", ".....",
              "XML entity with no string value is passed as an argument to iri_to_id (), type %d", (unsigned int)orig_dtp );
            goto return_error; /* see below */
          }
        name = box_to_delete;
        break;
      }
    case DV_STRING:
    case DV_UNAME:
      break;
    case DV_RDF:
      {
        rdf_box_t *rb = (rdf_box_t *)name;
        if (!rb->rb_is_complete)
          {
            if (IRI_TO_ID_IF_CACHED == mode)
              return 0;
            rb_complete (rb, qi->qi_trx, qi);
          }
        name = box_copy_tree (rb->rb_box);
        dtp = DV_TYPE_OF (name);
        goto again; /* see above */
      }
    default:
      err_ret[0] = srv_make_new_error ("RDFXX", ".....",
        "Bad argument to iri_to_id (), type %d", (unsigned int)orig_dtp );
      goto return_error; /* see below */
    }
  if (1 == box_length (name))
    {
      err_ret[0] = srv_make_new_error ("RDFXX", ".....",
        "Empty string is not a valid argument to iri_to_id (), type %d", (unsigned int)orig_dtp );
      goto return_error; /* see below */
    }
/*                     0123456789 */
  if (!strncmp (name, "nodeID://", 9))
    {
      unsigned char *tail = (unsigned char *)(name + 9);
      int64 acc = 0;
      int64 prefix_base = 0;
      if ('b' == tail[0]) { prefix_base = MIN_64BIT_BNODE_IRI_ID; tail++; }
      else if ('t' == tail[0])
        {
          if (bnode_t_treshold == ~((boxint)0))
            {
              err_ret[0] = srv_make_new_error ("RDFXX", ".....",
                "Bad argument to iri_to_id (), '%.100s' is not supported while __rdf_set_bnode_t_treshold() is not called", name );
              goto return_error; /* see below */
            }
          prefix_base = bnode_t_treshold;
          tail++;
        }
      while (isdigit (tail[0]))
        acc = acc * 10 + ((tail++)[0] - '0');
      if ('\0' != tail[0])
        {
          err_ret[0] = srv_make_new_error ("RDFXX", ".....",
            "Bad argument to iri_to_id (), '%.100s' is not valid bnode IRI", name );
          goto return_error; /* see below */
        }
      acc += prefix_base;
      if ((acc > (2 * min_bnode_iri_id())) || (acc < min_bnode_iri_id()))
        {
          if ((bnode_iri_ids_are_huge) || (acc < 0))
            err_ret[0] = srv_make_new_error ("RDFXX", ".....",
              "Bad argument to iri_to_id (), '%.100s' is not valid bnode IRI", name );
          else
            err_ret[0] = srv_make_new_error ("RDFXX", ".....",
              "Bad argument to iri_to_id (), '%.100s' is not valid bnode IRI for 32-bit RDF storage", name );
          goto return_error; /* see below */
        }
      if (NULL != box_to_delete)
        dk_free_box (box_to_delete);
      res_ret[0] = box_iri_int64 (acc, DV_IRI_ID);
      return 1;
    }
  if (uriqa_dynamic_local)
    {
      int ofs = uriqa_iri_is_local (qi, name);
      if (0 != ofs)
        {
          int name_box_len = box_length (name);
/*  0123456 */
/* "local:" */
          caddr_t localized_name = dk_alloc_box (6 + name_box_len - ofs, DV_STRING);
          memcpy (localized_name, "local:", 6);
          memcpy (localized_name + 6, name + ofs, name_box_len - ofs);
          if (box_to_delete == name)
            dk_free_box (box_to_delete);
          box_to_delete = name = localized_name;
        }
    }
  res_ret[0] = name;
  if ((NULL != box_to_delete) && (name != box_to_delete))
    dk_free_box (box_to_delete);
  return 2;
return_error:
  if (NULL != box_to_delete)
    dk_free_box (box_to_delete);
  return 0;
}

caddr_t
canon_iri_to_id (query_instance_t *qi, caddr_t canon_name, int mode, caddr_t *err_ret)
{
  switch (cl_run_local_only)
    {
    case CL_RUN_LOCAL:
      switch (mode)
        {
        case IRI_TO_ID_IF_KNOWN:
          return key_name_to_iri_id (qi->qi_trx, canon_name, 0);
        case IRI_TO_ID_WITH_CREATE:
          {
            caddr_t boxed_iid = key_name_to_iri_id (qi->qi_trx, canon_name, 1);
#ifdef DEBUG
	  if (!boxed_iid) bing ();
#endif
            return boxed_iid;
          }
        case IRI_TO_ID_IF_CACHED:
          return key_name_to_existing_cached_iri_id (qi->qi_trx, canon_name);
        }
      break;
    default: err_ret[0] = srv_make_new_error ("RDFXX", ".....",
              "iri_to_id () refers to partitioned tables and can not be used before cluster is up");
    }
  return NULL;
}

caddr_t
iri_to_id (caddr_t *qst, caddr_t raw_name, int mode, caddr_t *err_ret)
    {
  query_instance_t *qi = (query_instance_t *) qst;
  caddr_t canon_name = NULL;
  caddr_t boxed_iid = NULL;
  int status;
  err_ret[0] = NULL;
  status = iri_canonicalize (qi, raw_name, mode, &canon_name, err_ret);
  if (NULL != err_ret[0])
    goto return_error;
  switch (status)
    {
    case 0:
      break;
    case 1:
#ifndef NDEBUG
      if (DV_IRI_ID != DV_TYPE_OF (canon_name))
	GPF_T1 ("iri_to_id: weird dv_type, should be IRI_ID");
#endif
      return ((canon_name == raw_name) ? box_copy_tree (canon_name) : canon_name);
    case 2:
      boxed_iid = canon_iri_to_id (qi, canon_name, mode, err_ret);
      break;
    }
  dk_check_tree (canon_name);
#ifndef NDEBUG
  if (DV_IRI_ID == DV_TYPE_OF (canon_name))
    GPF_T1 ("iri_to_id: weird dv_type, should not be IRI_ID");
  if ((canon_name == boxed_iid) && IS_BOX_POINTER (canon_name))
    GPF_T1 ("iri_to_id: weird cast");
#endif
  if ((NULL != canon_name) && (canon_name != raw_name))
    dk_free_box (canon_name);
  if (NULL == boxed_iid)
    return NEW_DB_NULL;
#ifndef NDEBUG
  if ((boxed_iid == raw_name) && IS_BOX_POINTER (raw_name))
    GPF_T1 ("iri_to_id: arg not copied and returned");
#endif
  return boxed_iid;
return_error:
  if (canon_name != raw_name)
    dk_free_box (canon_name);
  return NULL;
}

caddr_t
bif_iri_to_id (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t name = bif_arg (qst, args, 0, "iri_to_id");
  int make_new = (BOX_ELEMENTS (args) > 1 ? bif_long_arg (qst, args, 1, "iri_to_id") : 1);
  caddr_t err = NULL;
  caddr_t res = iri_to_id (qst, name, make_new ? IRI_TO_ID_WITH_CREATE : IRI_TO_ID_IF_KNOWN, &err);
  if (NULL != err)
    sqlr_resignal (err);
  if (NULL == res)
    {
      if (BOX_ELEMENTS (args) > 2)
        return box_copy_tree (bif_arg (qst, args, 2, "iri_to_id"));
      return NEW_DB_NULL;
    }
  return res;
}

caddr_t
bif_iri_to_id_repl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t name = bif_arg (qst, args, 0, "iri_to_id_repl");
  caddr_t err = NULL;
  caddr_t res;
  switch (DV_TYPE_OF (name))
    {
    case DV_LONG_INT: case DV_IRI_ID:
      {
        iri_id_t iid = unbox_iri_int64 (name);
        if (iid < min_bnode_iri_id ())
          sqlr_new_error ("22023", "SR626", "The argument of iri_to_id_repl() is an IRI_ID of URI");
#if 0
        if (iid >= MIN_64BIT_BNODE_IRI_ID)
          tmp_name = box_sprintf (40, "_:rr_b" IIDBOXINT_FMT, (boxint)(iid - MIN_64BIT_BNODE_IRI_ID));
        else
          tmp_name = box_sprintf (40, "_:rr" IIDBOXINT_FMT, (boxint)iid);
        res = canon_iri_to_id ((query_instance_t *)qst, tmp_name, IRI_TO_ID_WITH_CREATE, &err);
        dk_free_box (tmp_name);
        if (NULL != err)
          sqlr_resignal (err);
        return res;
#else
        return box_copy (name);
#endif
      }
    case DV_STRING: case DV_UNAME:
      break;
    default:
      sqlr_new_error ("22023", "SR626", "The argument of iri_to_id_repl() is of wrong type");
    }
  res = canon_iri_to_id ((query_instance_t *)qst, name, IRI_TO_ID_WITH_CREATE, &err);
  if (NULL != err)
    sqlr_resignal (err);
  return res;
}

caddr_t
bif_iri_canonicalize (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t raw_name = bif_arg (qst, args, 0, "iri_canonicalize");
  caddr_t canon_name = NULL;
  caddr_t err = NULL;
  err_ret[0] = NULL;
  iri_canonicalize ((query_instance_t *)qst, raw_name, IRI_TO_ID_WITH_CREATE, &canon_name, &err);
  if (NULL != err)
    {
      if ((NULL != canon_name) && (canon_name != raw_name))
        dk_free_box (canon_name);
      sqlr_resignal (err);
    }
  if (NULL == canon_name)
    return NEW_DB_NULL;
  if (DV_IRI_ID == DV_TYPE_OF (canon_name))
    {
      iri_id_t iid = unbox_iri_int64 (canon_name);
      if (min_bnode_iri_id() > iid)
        {
          caddr_t iri = key_id_to_iri ((query_instance_t *)qst, iid);
          if (canon_name != raw_name)
            dk_free_tree (canon_name);
          if (!iri)
            sqlr_new_error ("22023", "SR626", "Can not canonicalize unknown IRI ID " IIDBOXINT_FMT, (boxint)(iid));
          return iri;
        }
    }
  if (canon_name == raw_name)
    return box_copy_tree (canon_name);
  return canon_name;
}

caddr_t
bif_iri_to_id_nosignal (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t name = bif_arg (qst, args, 0, "iri_to_id_nosignal");
  int make_new = (BOX_ELEMENTS (args) > 1 ? bif_long_arg (qst, args, 1, "iri_to_id_nosignal") : 1);
  caddr_t err = NULL;
  caddr_t res = iri_to_id (qst, name, make_new ? IRI_TO_ID_WITH_CREATE : IRI_TO_ID_IF_KNOWN, &err);
  if (NULL != err)
    {
      if (!strcmp (ERR_STATE(err), "RDFXX"))
        return NEW_DB_NULL;
      sqlr_resignal (err);
    }
  if (NULL == res)
    {
      if (BOX_ELEMENTS (args) > 2)
        return box_copy_tree (bif_arg (qst, args, 2, "iri_to_id"));
      return NEW_DB_NULL;
    }
  return res;
}

caddr_t
bif_iri_to_id_if_cached (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t name = bif_arg (qst, args, 0, "iri_to_id_if_cached");
  caddr_t err = NULL;
  caddr_t res = iri_to_id (qst, name, IRI_TO_ID_IF_CACHED, &err);
  if (NULL != err)
    sqlr_resignal (err);
  if (NULL == res)
    {
      if (BOX_ELEMENTS (args) > 1)
        return box_copy_tree (bif_arg (qst, args, 1, "iri_to_id_if_cached"));
      return NEW_DB_NULL;
    }
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
  itc_from (itc, key, QI_NO_SLICE);
  ITC_SEARCH_PARAM (itc, id);
  itc->itc_isolation =ISO_COMMITTED;
  itc->itc_key_spec = key->key_insert_spec;
  ITC_FAIL (itc)
    {
      buf = itc_reset (itc);
      res = itc_search (itc, &buf);
      if (DVC_MATCH == res)
	{
	  iri = itc_box_column (itc, buf, str_col->col_id, NULL);
	}
      else
	iri = NULL;
      itc_page_leave (itc, buf);
    }
  ITC_FAILED
      {
	itc_free (itc);
	if (!lt)
	  return NULL;
      }
  END_FAIL (itc);
  itc_free (itc);
  return iri;
}

caddr_t
uriqa_dynamic_local_replace_nocheck (caddr_t name, client_connection_t * cli)
    {
      caddr_t host;
      int is_https = 0;
#ifndef NDEBUG
  if (strncmp (name, "local:", 6))
    GPF_T1 ("uriqa_dynamic_local_replace_nocheck(): should check but misused");
#endif
      host = uriqa_get_host_for_dynamic_local (cli, &is_https);
      if (NULL != host)
        {
          int name_box_len = box_length (name);
          int host_strlen = strlen (host);
          caddr_t expanded_name = dk_alloc_box (name_box_len - 6 + (7 + is_https + host_strlen), DV_STRING);
      if (!is_https)         /* 01234567 */
	    memcpy (expanded_name, "http://", 7);
      else                   /* 012345678 */
	    memcpy (expanded_name, "https://", 8);
          memcpy (expanded_name + 7 + is_https, host, host_strlen);
          memcpy (expanded_name + 7 + is_https + host_strlen, name + 6, name_box_len - 6);
          dk_free_box (name);
          name = expanded_name;
	  dk_free_box (host);
        }
  return name;
}

caddr_t
key_id_to_canonicalized_iri (query_instance_t * qi, iri_id_t iri_id_no)
{
  boxint pref_id;
  lock_trx_t * lt = qi->qi_trx;
  caddr_t local, prefix, name;
  local = lt_nic_id_name (lt, iri_name_cache, iri_id_no);
  if (!local)
    {
      caddr_t id_box;
      id_box = box_iri_id (iri_id_no);
      if (!cl_run_local_only)
	{
	  caddr_t ret = cl_id_to_iri (qi, id_box);
	  dk_free_box (id_box);
	  return ret;
	}

      local = tb_id_to_name (qi->qi_trx, "DB.DBA.RDF_IRI", id_box);
      dk_free_box (id_box);
      if (!local)
	return NULL;
      if (lt->lt_lock.ht_count)
	lt_nic_set (lt, iri_name_cache, local, iri_id_no);
      else
	nic_set (iri_name_cache, local, iri_id_no);
    }
  pref_id = LONG_REF_NA (local);
  prefix = nic_id_name (iri_prefix_cache, pref_id);
  if (!prefix)
    {
      if (!cl_run_local_only)
	{
	  caddr_t id_box = box_iri_id (iri_id_no);
	  caddr_t ret = cl_id_to_iri (qi, id_box);
	  dk_free_box (id_box);
	  dk_free_box (local);
	  return ret;
	}
      else
	{
	  caddr_t pref_id_box = box_num (pref_id);
	  prefix = tb_id_to_name (qi->qi_trx, "DB.DBA.RDF_PREFIX", pref_id_box);
	  dk_free_box (pref_id_box);
	  if (!prefix)
	    {
	      dk_free_box (local);
	      return NULL;
	    }
	  if (lt->lt_lock.ht_count)
	    lt_nic_set (lt, iri_prefix_cache, prefix, pref_id);
	  else
	    nic_set (iri_prefix_cache, prefix, pref_id);
	}
    }
  name = dk_alloc_box (box_length (local) + box_length (prefix) - 5, DV_STRING);
  /* subtract 4 for the prefix id in the local and 1 for one of the terminating nulls */
  memcpy (name, prefix, box_length (prefix) - 1);
  memcpy (name + box_length (prefix) - 1, local + 4, box_length (local) - 4);
  dk_free_box (prefix);
  dk_free_box (local);
  return name;
}


caddr_t
key_id_to_iri (query_instance_t * qi, iri_id_t iri_id_no)
        {
  caddr_t name = key_id_to_canonicalized_iri (qi, iri_id_no);
  caddr_t name_with_local_extended;
  dk_check_tree (name);
  if (NULL == name)
  return name;
  name_with_local_extended = uriqa_dynamic_local_replace (name, qi->qi_client);
  dk_check_tree (name_with_local_extended);
  return name_with_local_extended;
}

int
key_id_to_namespace_and_local (query_instance_t *qi, iri_id_t iid, caddr_t *subj_ns_ret, caddr_t *subj_loc_ret)
{
  boxint pref_id;
  caddr_t local, prefix;
  lock_trx_t * lt = qi->qi_trx;
  local = lt_nic_id_name (lt, iri_name_cache, iid);
  if (!local)
    {
      caddr_t id_box = box_iri_id (iid);
      if (!cl_run_local_only)
	{
	  caddr_t ret = cl_id_to_iri (qi, id_box);
	  iri_split_ttl_qname (ret, subj_ns_ret, subj_loc_ret, 1);
	  dk_free_box (ret);
	  dk_free_box (id_box);
	  return (NULL != ret);
	}

      local = tb_id_to_name (qi->qi_trx, "DB.DBA.RDF_IRI", id_box);
      dk_free_box (id_box);
      if (!local)
	return 0;
      lt_nic_set (lt, iri_name_cache, local, iid);
    }
  pref_id = LONG_REF_NA (local);
  prefix = lt_nic_id_name (lt, iri_prefix_cache, pref_id);
  if (!prefix)
    {
      if (!cl_run_local_only)
	{
	  caddr_t id_box = box_iri_id (iid);
	  caddr_t ret = cl_id_to_iri (qi, id_box);
	  iri_split_ttl_qname (ret, subj_ns_ret, subj_loc_ret, 1);
	  dk_free_box (ret);
	  dk_free_box (id_box);
	  return (NULL != ret);
	}
      else
	{
	  caddr_t pref_id_box = box_num (pref_id);
	  prefix = tb_id_to_name (qi->qi_trx, "DB.DBA.RDF_PREFIX", pref_id_box);
	  dk_free_box (pref_id_box);
	  if (!prefix)
        {
          dk_free_box (local);
	  return 0;
        }
	  lt_nic_set (lt, iri_prefix_cache, prefix, pref_id);
	}
    }
  /* may be replace following with uriqa_dynamic_local_replace */
/*                       0123456 */
  if (!strncmp (prefix, "local:", 6))
    {
      caddr_t host;
      int is_https = 0;
      host = uriqa_get_host_for_dynamic_local (qi->qi_client, &is_https);
      if (NULL != host)
        {
/*                                         012345678    01234567 */
          const char *proto = (is_https ? "https://" : "http://");
          int proto_strlen = (is_https ? 8 : 7);
          int prefix_box_len = box_length (prefix);
          int host_strlen = strlen (host);
          caddr_t expanded_prefix = dk_alloc_box (prefix_box_len - 6 + (proto_strlen + host_strlen), DV_STRING);
          memcpy (expanded_prefix, proto, proto_strlen);
          memcpy (expanded_prefix + proto_strlen, host, host_strlen);
          memcpy (expanded_prefix + proto_strlen + host_strlen, prefix + 6, prefix_box_len - 6);
          dk_free_box (prefix);
          prefix = expanded_prefix;
	  dk_free_box (host);
        }
    }
  subj_ns_ret[0] = prefix;
  subj_loc_ret[0] = box_dv_short_nchars (local+4, box_length (local) - 5);
  dk_free_tree (local);
  return 1;
}

caddr_t
bif_id_to_iri (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;
  caddr_t iid_box = bif_arg (qst, args, 0, "id_to_iri");
  switch (DV_TYPE_OF (iid_box))
    {
    case DV_DB_NULL:
      return NEW_DB_NULL;
    case DV_IRI_ID:
      {
	iri_id_t iid = unbox_iri_id (iid_box);
	caddr_t iri;
	if (0L == iid)
	  return NEW_DB_NULL;
	if ((min_bnode_iri_id () <= iid) && (min_named_bnode_iri_id () > iid))
	  iri = BNODE_IID_TO_LABEL (iid);
	else
	  {
	    iri = key_id_to_iri (qi, iid);
	    if (!iri)
	      return NEW_DB_NULL;
	  }
	box_flags (iri) = BF_IRI;
	return iri;
      }
    case DV_UNAME:
      return box_copy (iid_box);
    case DV_STRING:
      if (BF_IRI == box_flags (iid_box))
	return box_copy (iid_box);
      break;
    }
  sqlr_new_error ("22023", "SR008",
      "Function id_to_iri needs a string or UNAME or IRI_ID or NULL as argument 1, "
      "not an arg of type %s (%d)", dv_type_title (DV_TYPE_OF (iid_box)), DV_TYPE_OF (iid_box));
  return NULL;			/* never reached */
}

caddr_t
bif_id_to_canonicalized_iri (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t *) qst;
  caddr_t iid_box = bif_arg (qst, args, 0, "id_to_canonicalized_iri");
  switch (DV_TYPE_OF (iid_box))
    {
    case DV_DB_NULL:
      return NEW_DB_NULL;
    case DV_IRI_ID:
      {
       iri_id_t iid = unbox_iri_id (iid_box);
        caddr_t iri;
        if (0L == iid)
          return NEW_DB_NULL;
        if ((min_bnode_iri_id () <= iid) && (min_named_bnode_iri_id () > iid))
          iri = BNODE_IID_TO_LABEL(iid);
        else
          {
            iri = key_id_to_canonicalized_iri (qi, iid);
            if (!iri)
              return NEW_DB_NULL;
          }
        box_flags (iri) = BF_IRI;
        return iri;
      }
    case DV_UNAME:
      return box_copy (iid_box);
    case DV_STRING:
      if (BF_IRI == box_flags (iid_box))
        return box_copy (iid_box);
      break;
    }
  sqlr_new_error ("22023", "SR008",
    "Function id_to_canonicalized_iri needs a string or UNAME or IRI_ID or NULL as argument 1, "
    "not an arg of type %s (%d)", dv_type_title (DV_TYPE_OF (iid_box)), DV_TYPE_OF (iid_box) );
  return NULL; /* never reached */
}

caddr_t
bif_id_to_iri_nosignal (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;
  caddr_t iid_box;
  iid_box = bif_arg (qst, args, 0, "id_to_iri_nosignal");
  switch (DV_TYPE_OF (iid_box))
    {
    case DV_IRI_ID:
      {
	iri_id_t iid;
	caddr_t iri;
	iid = unbox_iri_id (iid_box);
	if (min_bnode_iri_id () <= iid)
	  iri = BNODE_IID_TO_LABEL (iid);
	else
	  {
	    iri = key_id_to_iri (qi, iid);
	    if (!iri)
	      return NEW_DB_NULL;
	  }
	box_flags (iri) = BF_IRI;
	return iri;
      }
    case DV_UNAME:
      return box_copy (iid_box);
    case DV_STRING:
      if (BF_IRI == box_flags (iid_box))
	return box_copy (iid_box);
      break;
    }
  return NEW_DB_NULL;
}

caddr_t
bif_iri_id_cache_flush (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t *) qst;
  lock_trx_t *lt = qi->qi_trx;
  caddr_t log_array;
  int rc;
  if (0 && !srv_have_global_lock (THREAD_CURRENT_THREAD))
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


caddr_t
bif_rdf_cache_id (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  QNCAST (query_instance_t, qi, qst);
  caddr_t mode = bif_string_arg (qst, args, 0, "rdf_cache_id");
  caddr_t pref = bif_string_or_uname_arg (qst, args, 1, "rdf_cache_id");
  name_id_cache_t * cache = mode[0] == 'p' ? iri_prefix_cache
    : mode[0] == 'l' ? rdf_lang_cache
    : mode[0] == 't' ? rdf_type_cache
    : mode[0] == 'i'? iri_name_cache : NULL;
  if (!cache)
    sqlr_new_error ("42000", "RDF..", "bad mode for rdf_cache_id");
  if (BOX_ELEMENTS (args) > 2)
    {
      boxint new_id = 'i' == mode[0] ? (boxint)bif_iri_id_arg (qst, args, 2, "rdf_cache_id")
	: bif_long_arg (qst, args, 2, "rdf_cache_id");
      if (cache == iri_name_cache || cache == iri_prefix_cache)
	lt_nic_set (qi->qi_trx, cache, pref, new_id);
      else
	nic_set (cache, pref, new_id);
      return 0;
    }
  if (cache == iri_name_cache || cache == iri_prefix_cache)
    return box_num (lt_nic_name_id (qi->qi_trx, cache, pref));
  else
    return box_num (nic_name_id (cache, pref));
}


caddr_t
bif_rdf_cache_id_to_name (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  QNCAST (query_instance_t, qi, qst);
  caddr_t mode = bif_string_arg (qst, args, 0, "rdf_cache_id_to_name");
  boxint id = bif_long_arg (qst, args, 1, "rdf_cache_id_to_name");
  name_id_cache_t * cache = mode[0] == 'p' ? iri_prefix_cache
    : mode[0] == 'l' ? rdf_lang_cache
    : mode[0] == 'i' ? iri_name_cache
    : mode[0] == 't' ? rdf_type_cache : NULL;
  if (!cache)
    sqlr_new_error ("42000", "RDF..", "bad mode for rdf_cache_id_to_name");
  if (cache == iri_name_cache || cache == iri_prefix_cache)
    return lt_nic_id_name (qi->qi_trx, cache, id);
  else
    return nic_id_name (cache, id);
}


#undef tf_bnode_iid
caddr_t DBG_NAME (tf_bnode_iid) (DBG_PARAMS triple_feed_t *tf, caddr_t txt)
{
  char params_buf [BOX_AUTO_OVERHEAD + sizeof (caddr_t) * 3];
  void **params;
  caddr_t res, *hit, err;
  query_t *cbk_qr = tf->tf_cbk_qrs[TRIPLE_FEED_NEW_BLANK];
  if (NULL == cbk_qr)
    {
      dk_free_box (txt);
      return box_iri_id (min_bnode_iri_id());
    }
  if (NULL != txt)
    {
      hit = (caddr_t *)id_hash_get (tf->tf_blank_node_ids, (caddr_t)(&(txt)));
      if (NULL != hit)
        {
          dk_free_box (txt);
          return box_copy_tree (hit[0]);
        }
    }
  BOX_AUTO_TYPED (void **, params, params_buf, sizeof (caddr_t) * 3, DV_ARRAY_OF_POINTER);
  res = NULL;
  params[0] = &(tf->tf_current_graph_uri);
  params[1] = &(tf->tf_app_env);
  params[2] = &res;
  err = qr_exec (tf->tf_qi->qi_client, cbk_qr, tf->tf_qi, NULL, NULL, NULL, (caddr_t *)params, NULL, 0);
  BOX_DONE (params, params_buf);
  if (NULL != err)
    {
      dk_free_box (txt);
      sqlr_resignal (err);
    }
  if (NULL == txt)
    return res;
  id_hash_set (tf->tf_blank_node_ids, (caddr_t)(&txt), (caddr_t)(&res));
  return DBG_NAME (box_copy_tree) (DBG_ARGS res);
}

#undef tf_formula_bnode_iid
caddr_t DBG_NAME (tf_formula_bnode_iid) (DBG_PARAMS ttlp_t *ttlp_arg, caddr_t txt)
{
  caddr_t btext = box_sprintf (10+strlen (txt), "%ld%s", (long)(unbox_iri_id(ttlp_arg[0].ttlp_formula_iid)), txt);
  caddr_t res;
  dk_free_box (txt);
  /*dk_set_push (&(ttlp_arg[0].ttlp_saved_uris), btext);*/
  res = DBG_NAME (tf_bnode_iid) (DBG_ARGS ttlp_arg[0].ttlp_tf, btext);
  /*dk_set_pop (&(ttlp_arg[0].ttlp_saved_uris));*/
  return res;
}


char * range_replay =
"create procedure ID_RANGE_REPLAY (in iri_seq varchar, in iri_seq_max varchar, in id int, in max_id int)\n"
"{\n"
"  sequence_set (iri_seq, id, 1);\n"
"  sequence_set (iri_seq_max, max_id, 1);\n"
"	sequence_set ('RDF_URL_IID_NAMED', max_id, 1);\n"
"}";


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

char * rdf_prefix_text = "create table DB.DBA.RDF_PREFIX (RP_NAME varchar not null primary key, RP_ID bigint not null unique)"
"alter index RDF_PREFIX on RDF_PREFIX partition (RP_NAME varchar (-10, 0hexffff))"
"alter index DB_DBA_RDF_PREFIX_UNQC_RP_ID on DB.DBA.RDF_PREFIX partition (RP_ID int (0hexffff00))";


char * rdf_iri_text = "create table DB.DBA.RDF_IRI (RI_NAME varchar not null primary key, RI_ID IRI_ID_8 not null unique)"
"alter index RDF_IRI on RDF_IRI partition (RI_NAME varchar (-10, 0hexffff))"
"alter index DB_DBA_RDF_IRI_UNQC_RI_ID on DB.DBA.RDF_IRI partition (RI_ID int (0hexffff00))";



/* Free text on DB.DBA.RDF_QUAD */

dk_mutex_t *rdf_obj_ft_rules_mtx = NULL;
id_hash_t *rdf_obj_ft_rules_by_iids = NULL;
id_hash_t *rdf_obj_ft_rules_by_iris = NULL;
id_hash_t *rdf_obj_ft_graph_rule_counts = NULL;
ptrlong rdf_obj_ft_predonly_rule_count = 0;

typedef struct rdf_obj_ft_rule_iid_hkey_s
{
   iri_id_t hkey_g;
   iri_id_t hkey_iid_p;
} rdf_obj_ft_rule_iid_hkey_t;

typedef struct rdf_obj_ft_rule_iri_hkey_s
{
   iri_id_t hkey_g;
   caddr_t hkey_iri_p;
} rdf_obj_ft_rule_iri_hkey_t;

id_hashed_key_t
rdf_obj_ft_rule_iid_hkey_hash (caddr_t p_data)
{
  rdf_obj_ft_rule_iid_hkey_t *ht = (rdf_obj_ft_rule_iid_hkey_t *)p_data;
  return ((id_hashed_key_t)(ht->hkey_g * 65539 + ht->hkey_iid_p) & ID_HASHED_KEY_MASK);
}

int
rdf_obj_ft_rule_iid_hkey_cmp (caddr_t d1, caddr_t d2)
{
  rdf_obj_ft_rule_iid_hkey_t *ht1 = (rdf_obj_ft_rule_iid_hkey_t *)d1;
  rdf_obj_ft_rule_iid_hkey_t *ht2 = (rdf_obj_ft_rule_iid_hkey_t *)d2;
  return ((ht1->hkey_g == ht2->hkey_g) && (ht1->hkey_iid_p == ht2->hkey_iid_p));
}

id_hashed_key_t
rdf_obj_ft_rule_iri_hkey_hash (caddr_t p_data)
{
  rdf_obj_ft_rule_iri_hkey_t *ht = (rdf_obj_ft_rule_iri_hkey_t *)p_data;
  caddr_t p_box = ht->hkey_iri_p;
  id_hashed_key_t hash = (ht->hkey_g & ID_HASHED_KEY_MASK);
  if (p_box)
    {
      BYTE_BUFFER_HASH (hash, p_box, box_length_inline (p_box) - 1);
    }
  return hash & ID_HASHED_KEY_MASK;
}

int rdf_obj_ft_rule_iri_hkey_cmp (caddr_t d1, caddr_t d2)
{
  rdf_obj_ft_rule_iri_hkey_t *ht1 = (rdf_obj_ft_rule_iri_hkey_t *)d1;
  rdf_obj_ft_rule_iri_hkey_t *ht2 = (rdf_obj_ft_rule_iri_hkey_t *)d2;
  return ((ht1->hkey_g == ht2->hkey_g) && !strcmp (ht1->hkey_iri_p, ht2->hkey_iri_p));
}

static ptrlong *
rdf_obj_ft_get_rule_count_ptr (iri_id_t g_id)
{
  boxint g_id_int = g_id;
  ptrlong *res;
  if (0 == g_id)
    return &rdf_obj_ft_predonly_rule_count;
  res = (ptrlong *)id_hash_get (rdf_obj_ft_graph_rule_counts, (caddr_t)(&g_id_int));
  if (NULL == res)
    {
      ptrlong ctr = 0;
      res = (ptrlong *) id_hash_add_new (rdf_obj_ft_graph_rule_counts, (caddr_t)(&g_id_int), (caddr_t)(&ctr));
    }
  return res;
}

caddr_t
bif_rdf_obj_ft_rule_add (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  iri_id_t g_id = bif_iri_id_or_null_arg (qst, args, 0, "__rdf_obj_ft_rule_add");
  iri_id_t p_id = bif_iri_id_or_null_arg (qst, args, 1, "__rdf_obj_ft_rule_add");
  caddr_t reason = bif_string_arg (qst, args, 2, "__rdf_obj_ft_rule_add");
  caddr_t p_iri = NULL;
  dk_set_t *known_reasons_ptr;
  rdf_obj_ft_rule_iid_hkey_t iid_hkey;
  rdf_obj_ft_rule_iri_hkey_t iri_hkey;
  iid_hkey.hkey_g = g_id;
  iid_hkey.hkey_iid_p = p_id;
  if (1)
    {
      iri_hkey.hkey_g = g_id;
      iri_hkey.hkey_iri_p = p_iri = ((0 == p_id) ? NULL
				     : cl_id_to_iri ((query_instance_t*)qst, bif_arg_nochecks (qst, args, 1)));
    }
  mutex_enter (rdf_obj_ft_rules_mtx);
  known_reasons_ptr = (dk_set_t *)id_hash_get (rdf_obj_ft_rules_by_iids, (caddr_t)(&iid_hkey));
  if (NULL == known_reasons_ptr)
    {
      ptrlong *rule_count_ptr = rdf_obj_ft_get_rule_count_ptr (g_id);
      dk_set_t new_reasons = NULL;
      dk_set_push (&new_reasons, box_copy (reason));
      id_hash_add_new (rdf_obj_ft_rules_by_iids, (caddr_t)(&iid_hkey), (caddr_t)(&new_reasons));
        id_hash_add_new (rdf_obj_ft_rules_by_iris, (caddr_t)(&iri_hkey), (caddr_t)(&new_reasons));
      rule_count_ptr[0]++;
      mutex_leave (rdf_obj_ft_rules_mtx);
      return box_num (1);
    }
  if (0 > dk_set_position_of_string (known_reasons_ptr[0], reason))
    {
      dk_set_push (known_reasons_ptr, box_copy (reason));
      if (1)
        {
          dk_set_t *second_ptr = (dk_set_t *)id_hash_get (rdf_obj_ft_rules_by_iris, (caddr_t)(&iri_hkey));
          second_ptr[0] = known_reasons_ptr[0];
          dk_free_box (p_iri);
        }
      mutex_leave (rdf_obj_ft_rules_mtx);
      return box_num (1);
    }
  mutex_leave (rdf_obj_ft_rules_mtx);
  if (1)
    dk_free_box (p_iri);
  return box_num (0);
}

caddr_t
bif_rdf_obj_ft_rule_del (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  iri_id_t g_id = bif_iri_id_or_null_arg (qst, args, 0, "__rdf_obj_ft_rule_del");
  iri_id_t p_id = bif_iri_id_or_null_arg (qst, args, 1, "__rdf_obj_ft_rule_del");
  caddr_t reason = bif_string_arg (qst, args, 2, "__rdf_obj_ft_rule_del");
  dk_set_t *known_reasons_ptr;
  int reason_pos;
  caddr_t p_iri = NULL;
  rdf_obj_ft_rule_iid_hkey_t iid_hkey;
  rdf_obj_ft_rule_iri_hkey_t iri_hkey;
  iid_hkey.hkey_g = g_id;
  iid_hkey.hkey_iid_p = p_id;
  mutex_enter (rdf_obj_ft_rules_mtx);
  known_reasons_ptr = (dk_set_t *)id_hash_get (rdf_obj_ft_rules_by_iids, (caddr_t)(&iid_hkey));
  if (NULL == known_reasons_ptr)
    {
      mutex_leave (rdf_obj_ft_rules_mtx);
      return box_num (0);
    }
  reason_pos = dk_set_position_of_string (known_reasons_ptr[0], reason);
  if (0 > reason_pos)
    {
      mutex_leave (rdf_obj_ft_rules_mtx);
      return box_num (0);
    }
  dk_free_box (dk_set_delete_nth (known_reasons_ptr, reason_pos));
  if (CL_RUN_LOCAL != cl_run_local_only)
    {
      iri_hkey.hkey_g = g_id;
      iri_hkey.hkey_iri_p = p_iri = ((0 == p_id) ? NULL
				     : cl_id_to_iri ((query_instance_t *)qst, bif_arg_nochecks (qst, args, 1)));
    }
  if (NULL == known_reasons_ptr[0])
    {
      ptrlong *rule_count_ptr = rdf_obj_ft_get_rule_count_ptr (g_id);
      id_hash_remove (rdf_obj_ft_rules_by_iids, (caddr_t)(&iid_hkey));
      if (CL_RUN_LOCAL != cl_run_local_only)
        {
          rdf_obj_ft_rule_iri_hkey_t *old_iri_hkey = (rdf_obj_ft_rule_iri_hkey_t *)id_hash_get_key (rdf_obj_ft_rules_by_iris, (caddr_t)(&iri_hkey));
          caddr_t old_iri_p = old_iri_hkey->hkey_iri_p;
          id_hash_remove (rdf_obj_ft_rules_by_iris, (caddr_t)(&iri_hkey));
          dk_free_box (old_iri_p);
          dk_free_box (p_iri);
        }
      rule_count_ptr[0]--;
    }
  else
    {
      if (CL_RUN_LOCAL != cl_run_local_only)
        {
          dk_set_t *second_ptr = (dk_set_t *)id_hash_get (rdf_obj_ft_rules_by_iris, (caddr_t)(&iri_hkey));
          second_ptr[0] = known_reasons_ptr[0];
          dk_free_box (p_iri);
        }
    }
  mutex_leave (rdf_obj_ft_rules_mtx);
  return box_num (1);
}

caddr_t
bif_rdf_obj_ft_rule_zap_all (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int bucket_ctr = 0;
  mutex_enter (rdf_obj_ft_rules_mtx);
  for (bucket_ctr = rdf_obj_ft_rules_by_iids->ht_buckets; bucket_ctr--; /* no step */)
    {
      rdf_obj_ft_rule_iid_hkey_t iid_key;
      dk_set_t reasons;
      while (id_hash_remove_rnd (rdf_obj_ft_rules_by_iids, bucket_ctr, (caddr_t)(&iid_key), (caddr_t)(&reasons)))
        {
          while (NULL != reasons)
            {
              caddr_t reason = dk_set_pop (&reasons);
              dk_free_box (reason);
            }
        }
    }
  for (bucket_ctr = rdf_obj_ft_rules_by_iris->ht_buckets; bucket_ctr--; /* no step */)
    {
      rdf_obj_ft_rule_iri_hkey_t iri_key;
      dk_set_t reasons;
      while (id_hash_remove_rnd (rdf_obj_ft_rules_by_iris, bucket_ctr, (caddr_t)(&iri_key), (caddr_t)(&reasons)))
        {
          dk_free_box (iri_key.hkey_iri_p);
        }
    }
  mutex_leave (rdf_obj_ft_rules_mtx);
  return 0;
}

caddr_t
bif_rdf_obj_ft_rule_check (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  iri_id_t g_id;
  caddr_t p;
  rdf_obj_ft_rule_iid_hkey_t iid_hkey;
  dtp_t g_dtp, p_dtp;
  if (CL_RUN_LOCAL != cl_run_local_only)
    {
      caddr_t cl_text_set = registry_get ("cl_rdf_text_index");
      char flag = cl_text_set ? cl_text_set[0] : '\0';
      dk_free_tree (cl_text_set);
      if ('1' == flag)
        return box_num (2);
    }

  if (!rdf_obj_ft_rules_by_iris->ht_count)
    return NULL;
  g_id = bif_arg (qst, args, 0, "__rdf_obj_ft_rule_check");
  p = bif_arg (qst, args, 1, "__rdf_obj_ft_rule_check");
  iid_hkey.hkey_g = 0;
  iid_hkey.hkey_iid_p = 0;
  mutex_enter (rdf_obj_ft_rules_mtx);
  if (NULL != id_hash_get (rdf_obj_ft_rules_by_iids, (caddr_t)(&iid_hkey)))
    goto hit; /* see_below */
  g_dtp = DV_TYPE_OF (g_id);
  switch (g_dtp)
    {
      case DV_IRI_ID: /* case DV_STRING: case DV_UNAME: */
        break;
      case DV_DB_NULL:
        g_id = 0;
        break;
      default:
        mutex_leave (rdf_obj_ft_rules_mtx);
        sqlr_new_error ("22023", "SR008",
          "Function __rdf_obj_ft_rule_check needs a IRI_ID as argument 1, "
          "not an arg of type %s (%d)", dv_type_title (g_dtp), g_dtp );
    }
  p_dtp = DV_TYPE_OF (p);
  switch (p_dtp)
    {
      case DV_IRI_ID: case DV_STRING: case DV_UNAME:
	  break;
      case DV_DB_NULL:
	  p = 0;
	  break;
      default:
        mutex_leave (rdf_obj_ft_rules_mtx);
	  sqlr_new_error ("22023", "SR008",
		    "Function __rdf_obj_ft_rule_check needs a string or UNAME or IRI_ID as argument 2, "
		    "not an arg of type %s (%d)", dv_type_title (p_dtp), p_dtp);
    }
  if (NULL != id_hash_get (rdf_obj_ft_rules_by_iids, (caddr_t)(&iid_hkey)))
    goto hit; /* see_below */
  if (DV_IRI_ID == p_dtp || DV_DB_NULL == p_dtp)
    {
      iri_id_t p_id = ((DV_IRI_ID == p_dtp) ? unbox_iri_id (p) : (iri_id_t)0);
      iid_hkey.hkey_g = g_id;
      iid_hkey.hkey_iid_p = 0;
      if (NULL != id_hash_get (rdf_obj_ft_rules_by_iids, (caddr_t)(&iid_hkey)))
        goto hit; /* see_below */
      iid_hkey.hkey_g = 0;
      iid_hkey.hkey_iid_p = p_id;
      if (NULL != id_hash_get (rdf_obj_ft_rules_by_iids, (caddr_t)(&iid_hkey)))
        goto hit; /* see_below */
      iid_hkey.hkey_g = g_id;
      iid_hkey.hkey_iid_p = p_id;
      if (NULL != id_hash_get (rdf_obj_ft_rules_by_iids, (caddr_t)(&iid_hkey)))
        goto hit; /* see_below */
      mutex_leave (rdf_obj_ft_rules_mtx);
      return box_num (0);
   }
  else
    {
      rdf_obj_ft_rule_iri_hkey_t iri_hkey;
      iri_hkey.hkey_g = g_id;
      iri_hkey.hkey_iri_p = 0;
      if (NULL != id_hash_get (rdf_obj_ft_rules_by_iris, (caddr_t)(&iri_hkey)))
        goto hit; /* see_below */
      iri_hkey.hkey_g = 0;
      iri_hkey.hkey_iri_p = p;
      if (NULL != id_hash_get (rdf_obj_ft_rules_by_iris, (caddr_t)(&iri_hkey)))
        goto hit; /* see_below */
      iri_hkey.hkey_g = g_id;
      iri_hkey.hkey_iri_p = p;
      if (NULL != id_hash_get (rdf_obj_ft_rules_by_iris, (caddr_t)(&iri_hkey)))
        goto hit; /* see_below */
      mutex_leave (rdf_obj_ft_rules_mtx);
      return box_num (0);
   }
hit:
  mutex_leave (rdf_obj_ft_rules_mtx);
  return box_num (1);
}

caddr_t
bif_rdf_obj_ft_rule_count_in_graph (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  ptrlong res = rdf_obj_ft_predonly_rule_count;
  ptrlong *graph_specific;
  boxint g_id_int;
  if (CL_RUN_LOCAL != cl_run_local_only)
    {
      char *  cl_text_set, flag;
      IN_TXN;
      cl_text_set = registry_get ("cl_rdf_text_index");
      LEAVE_TXN;
      flag = cl_text_set ? cl_text_set[0] : '\0';
      dk_free_tree (cl_text_set);
      if ('1' == flag)
        return box_num (-1);
    }
  g_id_int = bif_iri_id_arg (qst, args, 0, "__rdf_obj_ft_rule_count_in_graph");
  mutex_enter (rdf_obj_ft_rules_mtx);
  graph_specific = (ptrlong *)id_hash_get (rdf_obj_ft_graph_rule_counts, (caddr_t)(&g_id_int));
  if (NULL != graph_specific)
    res += graph_specific[0];
  mutex_leave (rdf_obj_ft_rules_mtx);
  return box_num (res);
}

int rdf_g_pref_digits = 3;

void
rdf_graph_keyword (iri_id_t id, char *ret)
{
  /* number in hex.  Low 6 digits first, then high digits */
  int brk;
  char ch[2];
  char str[30];
  sprintf (str, "%llx", id);
  if ((brk = strlen (str)) <= 6)
    {
      sprintf (ret, "g%s", str);
      return;
    }
  brk -= rdf_g_pref_digits;
  ch[0] = str[brk];
  ch[1] = 0;
  str[brk] = 0;
  sprintf (ret, "g%s%s%s", ch, &str[brk+1], str);
}

caddr_t
bif_rdf_graph_keyword (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  iri_id_t id = bif_iri_id_arg (qst, args, 0, "rdf_graph_keyword");
  char ret[30];
  rdf_graph_keyword (id, ret);
  return box_dv_short_string (ret);
}

caddr_t
bif_iri_split (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int n_args = BOX_ELEMENTS (args);
  int is_int = n_args > 2 ? bif_long_arg (qst, args, 2, "iri_split") : 0;
  caddr_t iri = bif_string_arg (qst, args, 0, "iri_split");
  caddr_t local, pref;
  if (is_int)
    iri_split (iri, &pref, &local);
  else
    iri_split_ttl_qname (iri, &pref, &local, 0);
  if (n_args > 1 && ssl_is_settable (args[1]))
    qst_set (qst, args[1], local);
  else
    dk_free_box (local);
  return pref;
}


caddr_t
bif_iri_ensure (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t name = bif_string_arg (qst, args, 0, "iri_ensure");
  return iri_ensure (qst, name, 0, err_ret);
}

caddr_t
bif_uriqa_iri_is_local (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t name = bif_string_or_uname_arg (qst, args, 0, "uriqa_iri_is_local");
  int tail = uriqa_iri_is_local ((query_instance_t *)qst, name);
  return box_num (tail);
}

caddr_t 
bif_uriqa_dynamic_local_replace (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t name = box_copy (bif_string_arg (qst, args, 0, "uriqa_dynamic_local_replace"));
  name = uriqa_dynamic_local_replace (name, ((query_instance_t *) qst)->qi_client);
  return name;
}

caddr_t 
bif_uriqa_dynamic_local_set (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int val = bif_long_range_arg (qst, args, 0, "uriqa_dynamic_local_set", 0, 1);
  sec_check_dba ((query_instance_t *)qst, "uriqa_dynamic_local_set");
  if (val != uriqa_dynamic_local)
    uriqa_dynamic_local = val;
  return box_num (val);
}


void rdf_inf_init ();

int iri_cache_size = 0;


dbe_key_t *
sch_find_key (dbe_schema_t * sc, char * tb_name, char * key_name)
{
  dbe_table_t *tb = sch_name_to_table (sc ? sc : wi_inst.wi_schema, tb_name);
  if (!tb)
    return NULL;
  DO_SET (dbe_key_t *, key, &tb->tb_keys)
    {
      if (0 == strcmp (key->key_name, key_name))
	return key;
    }
  END_DO_SET();
  return NULL;
}


dbe_col_loc_t *
key_cl_by_name (dbe_key_t * key, char * col_name)
{
  static dbe_col_loc_t dummy;
  dbe_col_loc_t * cl;
  dbe_column_t * col = tb_name_to_column (key->key_table, col_name);
  if (!col)
    return &dummy;
  cl =  key_find_cl (key, col->col_id);
  return cl ? cl : &dummy;
}


int sql_comp_iri_look_ready = 0;


int
sql_ensure_proc (char * name)
{
  query_t * qr = sch_proc_def (wi_inst.wi_schema, name);
  if (!qr)
    return 0;
  if (qr->qr_to_recompile)
    {
      caddr_t err = NULL;
      qr = qr_recompile (qr, &err);
      if (err)
	{
	  return 0;
	}
    }
  return 1;
}


void
rdf_key_comp_init ()
{
  /* set the key comp options for the rdf keys */
  dbe_key_t * gspo = sch_find_key (NULL, "DB.DBA.RDF_QUAD", "RDF_QUAD");
  dbe_key_t * ogps = sch_find_key (NULL, "DB.DBA.RDF_QUAD", "RDF_QUAD_OGPS");
  sql_comp_iri_look_ready = sql_ensure_proc ("DB.DBA.II_I_LOOK");
  sql_comp_iri_look_ready &= sql_ensure_proc ("DB.DBA.II_P_LOOK");
  if (!gspo || !ogps)
    return;
  key_cl_by_name (gspo, "P")->cl_comp_asc = 1;
  key_cl_by_name (gspo, "O")->cl_comp_asc = 1;

  key_cl_by_name (ogps, "P")->cl_comp_asc = 1;
  key_cl_by_name (ogps, "G")->cl_comp_asc = 1;
  key_cl_by_name (ogps, "S")->cl_comp_asc = 1;
}

void bif_rld_init ();
void bif_id2i_vec (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, state_slot_t * ret);


void
rdf_core_init (void)
{
  jso_init ();
  rdf_mapping_jso_init ();
  iri_nic_rc = resource_allocate (10, NULL, (rc_destr_t)nic_free, (rc_destr_t)nic_clear, 0);
  prefix_nic_rc = resource_allocate (10, NULL, (rc_destr_t)nic_free, (rc_destr_t)nic_clear, 0);
  bif_define_typed ("rdf_load_rdfxml", bif_rdf_load_rdfxml, &bt_xml_entity);
  bif_set_uses_index (bif_rdf_load_rdfxml);
  bif_define_typed ("rdf_load_rdfa", bif_rdf_load_rdfa, &bt_xml_entity);
  bif_set_uses_index (bif_rdf_load_rdfa);
  bif_define_typed ("rdf_load_microdata", bif_rdf_load_microdata, &bt_xml_entity);
  bif_set_uses_index (bif_rdf_load_microdata);
  bif_define ("rdf_load_turtle", bif_rdf_load_turtle);
  bif_set_uses_index (bif_rdf_load_turtle);
  bif_define ("rdf_load_turtle_local_file", bif_rdf_load_turtle_local_file);
  bif_set_uses_index (bif_rdf_load_turtle_local_file);
  bif_define ("turtle_lex_analyze", bif_turtle_lex_analyze);
  bif_define_typed ("iri_to_id", bif_iri_to_id, &bt_iri_id);
  bif_set_cluster_rec ("iri_to_id");
  bif_set_enlist ("iri_to_id");
  bif_define ("iri_ensure", bif_iri_ensure);
  bif_set_uses_index (bif_iri_to_id);
  bif_set_no_cluster ("iri_to_id");
  bif_define ("iri_to_id_repl", bif_iri_to_id_repl);
  bif_set_cluster_rec ("iri_to_id_repl");
  bif_set_enlist ("iri_to_id_repl");
  bif_set_uses_index (bif_iri_to_id_repl);
  bif_define ("iri_canonicalize", bif_iri_canonicalize);
  bif_set_uses_index (bif_iri_canonicalize);
  bif_define ("iri_to_id_nosignal", bif_iri_to_id_nosignal);
  bif_set_uses_index (bif_iri_to_id_nosignal);
  bif_set_cluster_rec ("iri_to_id_nosignal");
  bif_define_typed ("iri_to_id_if_cached", bif_iri_to_id_if_cached, &bt_varchar);
  bif_define_typed ("id_to_iri", bif_id_to_iri, &bt_varchar);
  bif_set_uses_index (bif_id_to_iri);
  bif_set_cluster_rec ("id_to_iri");
  bif_define_typed ("id_to_canonicalized_iri", bif_id_to_canonicalized_iri, &bt_varchar);
  bif_set_uses_index (bif_id_to_canonicalized_iri);
  bif_set_cluster_rec ("id_to_canonicalized_iri");
  bif_define_typed ("id_to_iri_nosignal", bif_id_to_iri_nosignal, &bt_varchar);
  bif_set_uses_index (bif_id_to_iri_nosignal);
  bif_set_cluster_rec ("id_to_iri_nosignal");

  bif_define ("iri_to_rdf_prefix_and_local", bif_iri_to_rdf_prefix_and_local);
  bif_define ("rdf_cache_id", bif_rdf_cache_id);
  bif_define ("rdf_cache_id_to_name", bif_rdf_cache_id_to_name);
  bif_define ("iri_id_cache_flush", bif_iri_id_cache_flush);
  bif_define ("iri_id_new", bif_iri_id_new);
  bif_define ("__rdf_obj_ft_rule_add", bif_rdf_obj_ft_rule_add);
  bif_define ("__rdf_obj_ft_rule_del", bif_rdf_obj_ft_rule_del);
  bif_define ("__rdf_obj_ft_rule_zap_all", bif_rdf_obj_ft_rule_zap_all);
  bif_define ("__rdf_obj_ft_rule_check", bif_rdf_obj_ft_rule_check);
  bif_define ("__rdf_obj_ft_rule_count_in_graph", bif_rdf_obj_ft_rule_count_in_graph);
  /* Short aliases for use in generated SQL text: */
  bif_define ("__i2idn", bif_iri_to_id_nosignal);
  bif_define ("__i2id", bif_iri_to_id);
  bif_define ("__i2idc", bif_iri_to_id_if_cached);
  bif_define_typed ("__id2i", bif_id_to_iri, &bt_varchar);
  bif_set_vectored (bif_id_to_iri, bif_id2i_vec);
  bif_set_uses_index (bif_id_to_iri);
  bif_define ("__id2in", bif_id_to_iri_nosignal);
  bif_define ("rdf_graph_keyword", bif_rdf_graph_keyword);
  bif_define ("iri_split", bif_iri_split);
  bif_define ("uriqa_dynamic_local_set", bif_uriqa_dynamic_local_set);
  bif_define ("uriqa_iri_is_local", bif_uriqa_iri_is_local);
  bif_define ("uriqa_dynamic_local_replace", bif_uriqa_dynamic_local_replace);
#ifdef DEBUG
  bif_define ("turtle_lex_test", bif_turtle_lex_test);
#endif
  if (100 >= iri_cache_size)
    iri_cache_size = MIN (500000, main_bufs / 2);
  iri_name_cache = nic_allocate (iri_cache_size, 1, 0);
  nic_set_n_ways (iri_name_cache, 64);
  iri_prefix_cache = nic_allocate (iri_cache_size / 10, 0, 0);
  nic_set_n_ways (iri_prefix_cache, 64);
  rdf_lang_cache = nic_allocate (255, 0, 0);
  rdf_type_cache = nic_allocate (1000, 0, 0);
  ddl_ensure_table ("DB.DBA.RDF_PREFIX", rdf_prefix_text);
  ddl_ensure_table ("DB.DBA.RDF_IRI", rdf_iri_text);
  rdf_obj_ft_rules_mtx = mutex_allocate ();
  mutex_option (rdf_obj_ft_rules_mtx, "rdf_ft_rules", NULL, NULL);
  rdf_obj_ft_rules_by_iids = id_hash_allocate (1000,
    sizeof (rdf_obj_ft_rule_iid_hkey_t), sizeof (dk_set_t),
    rdf_obj_ft_rule_iid_hkey_hash, rdf_obj_ft_rule_iid_hkey_cmp );
  rdf_obj_ft_rules_by_iris = id_hash_allocate (1000,
    sizeof (rdf_obj_ft_rule_iri_hkey_t), sizeof (dk_set_t),
    rdf_obj_ft_rule_iri_hkey_hash, rdf_obj_ft_rule_iri_hkey_cmp );
  rdf_obj_ft_graph_rule_counts = id_hash_allocate (1000,
    sizeof (boxint), sizeof (ptrlong),
    boxint_hash, boxint_hashcmp );
  ddl_std_proc (iri_replay, 0);
  ddl_std_proc (range_replay, 0);
  rdf_inf_init ();
  rdf_key_comp_init  ();
  bif_rld_init ();
}
