/*
 *  sqlbif.c
 *
 *  $Id$
 *
 *  SQL Built In Functions
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

/*
   NEVER write bif functions that return the same boxed argument
   that they got as an argument. The result will be a crash after
   a while, when that same box is free'ed twice!
 */

#include <math.h>

#if defined(unix) && !defined(HAVE_GETRUSAGE)
#define HAVE_GETRUSAGE
#endif

#ifdef HAVE_GETRUSAGE
#include <sys/resource.h>
#endif

#include "sqlnode.h"
#include "sqlver.h"
#include "sqlfn.h"
#include "eqlcomp.h"
#include "lisprdr.h"
#include "sqlpar.h"
#include "sqlcmps.h"
#include "sqlintrp.h"
#include "sqlparext.h"
#include "sqlbif.h"
#include "arith.h"
#include "security.h"
#include "sqlpfn.h"
#include "date.h"
#include "datesupp.h"
#include "multibyte.h"
#include "srvmultibyte.h"
#include "bif_xper.h"
#include "libutil.h"
#include "recovery.h"
#if !defined (__APPLE__)
#include <wchar.h>
#endif
#include "http.h"
#include "sqlofn.h"
#include "statuslog.h"
#include "bif_text.h"
#include "xmltree.h"
#ifdef __cplusplus
extern "C" {
#endif
#include "xmlparser.h"
#ifdef __cplusplus
}
#endif
#ifndef __SQL3_H
#define __SQL3_H
#include "sql3.h"
#endif
#include "repl.h"
#include "replsr.h"
#include "sqltype.h" /* for XMLTYPE_TO_ENTITY */
#include "msdtc.h"
#include "sqlcstate.h"
#include "virtpwd.h"
#include "rdf_core.h"
#include "shcompo.h"
#include "http_client.h" /* for MD5Init and the like */
#include "sparql.h"

#define box_bool(n) ((caddr_t)((ptrlong)((n) ? 1 : 0)))

id_hash_t *icc_locks;
dk_mutex_t *icc_locks_mutex;
id_hash_t *dba_sequences;

extern void qi_read_table_schema (query_instance_t * qi, char *read_tb);
extern void ddl_rename_table_1 (query_instance_t * qi, char *old, char *new_name, caddr_t *err_ret);
extern void bif_date_init (void);
extern void bif_geo_init (void);
extern void bif_file_init (void);
extern void bif_explain_init (void);
extern void bif_status_init (void);
extern void bif_repl_init (void);
extern void bif_intl_init (void);
extern void recovery_init (void);
extern void backup_online_init (void);
extern void bif_xml_init (void);
extern void bif_xper_init (void);
extern void bif_soap_init (void);
extern void bif_http_client_init (void);
extern void bif_smtp_init (void);
extern void bif_pop3_init (void);
extern void bif_imap_init (void);
extern void bif_nntp_init (void);
extern void bif_regexp_init(void);
extern void bif_crypto_init(void);
extern void bif_audio_init (void);
extern void bif_uuencode_init(void);
extern void bif_udt_init(void);
extern void bif_xmlenc_init(void);
extern void tp_bif_init(void);
extern void bif_json_init (void);
extern void col_init ();
extern void geo_init ();
#ifdef _KERBEROS
extern void  bif_kerberos_init (void);
#endif

#ifdef VIRTTP
#include "2pc.h"
#endif
#include "log.h"

id_hash_t *name_to_bif_metadata_idhash = NULL;
dk_hash_t *bif_to_bif_metadata_hash = NULL;
dk_hash_t *name_to_bif_sparql_only_metadata_hash = NULL;

#define bif_arg_nochecks(qst,args,nth) QST_GET ((qst), (args)[(nth)])

caddr_t
bif_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func)
{
  if (((uint32) nth) >= BOX_ELEMENTS (args))
    sqlr_new_error ("22003", "SR030", "Too few (only %d) arguments for %s.", (int)(BOX_ELEMENTS (args)), func);
  return bif_arg_nochecks(qst,args,nth);
}

caddr_t
bif_arg_unrdf (caddr_t * qst, state_slot_t ** args, int nth, const char *func)
{
  caddr_t arg;
  if (((uint32) nth) >= BOX_ELEMENTS (args))
    sqlr_new_error ("22003", "SR030", "Too few (only %d) arguments for %s.", (int)(BOX_ELEMENTS (args)), func);
  arg = bif_arg_nochecks(qst,args,nth);
  if (DV_RDF != DV_TYPE_OF (arg))
    return arg;
  if (!((rdf_box_t *)arg)->rb_is_complete)
    sqlr_new_error ("22003", "SR586", "Incomplete RDF box as argument %d for %s().", nth, func);
  return ((rdf_box_t *)arg)->rb_box;
}

caddr_t
bif_arg_unrdf_ext (caddr_t * qst, state_slot_t ** args, int nth, const char *func, caddr_t *ret_orig)
{
  caddr_t arg;
  if (((uint32) nth) >= BOX_ELEMENTS (args))
    sqlr_new_error ("22003", "SR030", "Too few (only %d) arguments for %s.", (int)(BOX_ELEMENTS (args)), func);
  ret_orig[0] = arg = bif_arg_nochecks(qst,args,nth);
  if (DV_RDF != DV_TYPE_OF (arg))
    return arg;
  if (!((rdf_box_t *)arg)->rb_is_complete)
    sqlr_new_error ("22003", "SR586", "Incomplete RDF box as argument %d for %s().", nth, func);
  return ((rdf_box_t *)arg)->rb_box;
}

caddr_t
bif_string_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func)
{
  caddr_t arg = bif_arg_unrdf (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  if (dtp != DV_STRING)
    sqlr_new_error ("22023", "SR014",
  "Function %s needs a string as argument %d, not an arg of type %s (%d)",
  func, nth + 1, dv_type_title (dtp), dtp);
  return arg;
}

caddr_t *
bif_strict_type_array_arg (dtp_t element_dtp, caddr_t * qst, state_slot_t ** args, int nth, const char *func)
{
  caddr_t * arg =  (caddr_t*) bif_arg (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  int inx;
  if (dtp != DV_ARRAY_OF_POINTER)
    sqlr_new_error ("22023", "SR476",
		    "Function %s needs an array of %s as argument %d, not an arg of type %s (%d)",
		    func, dv_type_title (element_dtp), nth + 1, dv_type_title (dtp), dtp);
  DO_BOX (caddr_t, el, inx, arg)
    {
      if (DV_TYPE_OF (el) != element_dtp)
	sqlr_new_error ("22023", "SR476",
			"Function %s needs an array of %s as argument %d, not an array of %s (%d)",
			func, dv_type_title (element_dtp), nth + 1, dv_type_title (DV_TYPE_OF (el)), DV_TYPE_OF (el));
    }
  END_DO_BOX;
  return arg;
}


caddr_t *
bif_strict_2type_array_arg (dtp_t element_dtp1, dtp_t element_dtp2, caddr_t * qst, state_slot_t ** args, int nth, const char *func)
{
  caddr_t * arg =  (caddr_t*) bif_arg (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  int inx;
  if (dtp != DV_ARRAY_OF_POINTER)
    sqlr_new_error ("22023", "SR476",
		    "Function %s needs an array of %s or %s as argument %d, not an arg of type %s (%d)",
		    func, dv_type_title (element_dtp1), dv_type_title (element_dtp2),
                    nth + 1, dv_type_title (dtp), dtp );
  DO_BOX (caddr_t, el, inx, arg)
    {
      if ((DV_TYPE_OF (el) != element_dtp1) && (DV_TYPE_OF (el) != element_dtp2))
	sqlr_new_error ("22023", "SR476",
			"Function %s needs an array of %s or %s as argument %d, not an array of %s (%d)",
			func, dv_type_title (element_dtp1), dv_type_title (element_dtp2),
                        nth + 1, dv_type_title (DV_TYPE_OF (el)), DV_TYPE_OF (el) );
    }
  END_DO_BOX;
  return arg;
}

caddr_t
bif_string_or_uname_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func)
{
  caddr_t arg = bif_arg_unrdf (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  if ((dtp != DV_UNAME) && (dtp != DV_STRING))
    sqlr_new_error ("22023", "SR014",
  "Function %s needs a string or a UNAME as argument %d, not an arg of type %s (%d)",
  func, nth + 1, dv_type_title (dtp), dtp);
  return arg;
}

caddr_t
bif_string_or_wide_or_uname_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func)
{
  caddr_t arg = bif_arg_unrdf (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  if ((dtp != DV_UNAME) && (dtp != DV_STRING) && (dtp != DV_WIDE))
    sqlr_new_error ("22023", "SR014",
  "Function %s needs a string or wide or a UNAME as argument %d, not an arg of type %s (%d)",
  func, nth + 1, dv_type_title (dtp), dtp);
  return arg;
}


caddr_t
bif_strses_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func)
{
  caddr_t arg = bif_arg (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  if (dtp != DV_STRING_SESSION)
  sqlr_new_error ("22023", "SR002",
  "Function %s needs a string output as argument %d, not an arg of type %s (%d)",
  func, nth + 1, dv_type_title (dtp), dtp);
  return arg;
}

dk_session_t *
bif_strses_or_http_ses_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func)
{
  caddr_t arg = bif_arg (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  if (DV_LONG_INT == dtp)
    {
      dk_session_t *http_ses = ((query_instance_t *)qst)->qi_client->cli_http_ses; /*(dk_session_t *)((ptrlong)(unbox ((caddr_t)ses)));*/
      if (!http_ses)
	sqlr_new_error ("22023", "HT081",
	    "Function %.200s() outside of HTTP context and no stream specified", func );
      return http_ses;
    }
  if (DV_STRING_SESSION == dtp)
    return (dk_session_t *) arg;
  sqlr_new_error ("22023", "SR002",
    "Function %s needs a string output (or an integer for HTTP output) as argument %d, not an arg of type %s (%d)",
    func, nth + 1, dv_type_title (dtp), dtp);
  return NULL; /* never reached */
}


#ifdef BIF_XML
struct xml_entity_s *
bif_entity_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func)
{
  caddr_t arg = bif_arg_unrdf (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  switch (dtp)
    {
    case DV_XML_ENTITY:
      break;
    case DV_OBJECT:
      {
        xml_entity_t *res = XMLTYPE_TO_ENTITY(arg);
	if (NULL != res)
    	  return res;
      }
      /* no break */
    default:
      sqlr_new_error ("22023", "SR003",
	"Function %s needs an XML entity or an instance of XMLType as argument %d, not an arg of type %s (%d)",
      func, nth + 1, dv_type_title (dtp), dtp);
    }
  return (xml_entity_t *)arg;
}

struct xml_tree_ent_s *
bif_tree_ent_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func)
{
  caddr_t arg = bif_arg_unrdf (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  switch (dtp)
    {
    case DV_XML_ENTITY:
      break;
    case DV_OBJECT:
      {
	xml_entity_t *res = XMLTYPE_TO_ENTITY(arg);
	if (NULL != res)
	  arg = (caddr_t)res;
	break;
      }
    default:
      sqlr_new_error ("22023", "SR344",
	"Function %s needs an XML tree entity as argument %d, not an arg of type %s (%d)",
	func, nth + 1, dv_type_title (dtp), dtp);
    }
  if (!XE_IS_TREE (arg))
    sqlr_new_error ("22023", "SR345", "Persistent XML not allowed as an argument %d to function %s; this function accepts only XML tree entities", nth+1, func);
  return (xml_tree_ent_t *)arg;
}
#endif

caddr_t
bif_bin_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func)
{
  caddr_t arg = bif_arg_unrdf (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  if (dtp != DV_BIN && dtp != DV_LONG_BIN)
  sqlr_new_error ("22023", "SR004",
  "Function %s needs a binary as argument %d, not an arg of type %s (%d)",
  func, nth + 1, dv_type_title (dtp), dtp);
  return arg;
}


caddr_t
bif_string_or_null_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func)
{
  caddr_t arg = bif_arg_unrdf (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  if (DV_DB_NULL == dtp)
  {
    return (NULL);
  }

  if (dtp != DV_SHORT_STRING && dtp != DV_LONG_STRING
      &&  dtp != DV_C_STRING)
    {
      sqlr_new_error ("22023", "SR005",
    "Function %s needs a string or NULL as argument %d, "
    "not an arg of type %s (%d)",
    func, nth + 1, dv_type_title (dtp), dtp);
  }
  return arg;
}


caddr_t
bif_string_or_blob_or_null_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func)
{
  caddr_t arg = bif_arg_unrdf (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  if (DV_DB_NULL == dtp)
  {
    return (NULL);
  }
  else if (dtp == DV_BLOB_HANDLE)
    {
      caddr_t bs = blob_to_string (((query_instance_t *) qst)->qi_trx, arg);
      qst_set (qst, args[nth], bs);
      return bs;
    }
  if (dtp != DV_SHORT_STRING && dtp != DV_LONG_STRING
      &&  dtp != DV_C_STRING)
    {
      sqlr_new_error ("22023", "SR005",
    "Function %s needs a string or NULL as argument %d, "
    "not an arg of type %s (%d)",
    func, nth + 1, dv_type_title (dtp), dtp);
  }
  return arg;
}


caddr_t
bif_string_or_wide_or_null_or_strses_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func)
{
  caddr_t arg = bif_arg_unrdf (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  if (DV_DB_NULL == dtp)
  {
    return (NULL);
  }
  if (dtp != DV_SHORT_STRING && dtp != DV_LONG_STRING
       && dtp != DV_C_STRING
      && !IS_WIDE_STRING_DTP (dtp) && dtp != DV_STRING_SESSION)
    {
      sqlr_new_error ("22023", "SR006",
    "Function %s needs a string or string session or wide string or NULL as argument %d, "
    "not an arg of type %s (%d)",
    func, nth + 1, dv_type_title (dtp), dtp);
  }
  return arg;
}

caddr_t
bif_string_or_wide_or_null_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func)
{
  caddr_t arg = bif_arg_unrdf (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  if (DV_DB_NULL == dtp)
  {
    return (NULL);
  }
  if (dtp != DV_SHORT_STRING && dtp != DV_LONG_STRING
      && dtp != DV_C_STRING
      && !IS_WIDE_STRING_DTP (dtp))
    {
      sqlr_new_error ("22023", "SR007",
    "Function %s needs a string or NULL as argument %d, "
    "not an arg of type %s (%d)",
    func, nth + 1, dv_type_title (dtp), dtp);
  }
  return arg;
}

caddr_t
bif_string_or_uname_or_wide_or_null_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func)
{
  caddr_t arg = bif_arg_unrdf (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  if (DV_DB_NULL == dtp)
  {
    return (NULL);
  }
  if (dtp != DV_STRING && dtp != DV_UNAME
      && dtp != DV_C_STRING
      && !IS_WIDE_STRING_DTP (dtp))
    {
      sqlr_new_error ("22023", "SR007",
    "Function %s needs a string or UNAME or NULL as argument %d, "
    "not an arg of type %s (%d)",
    func, nth + 1, dv_type_title (dtp), dtp);
  }
  return arg;
}

bif_type_t bt_varchar = {NULL, DV_LONG_STRING, 0, 0};
bif_type_t bt_wvarchar = {NULL, DV_WIDE, 0, 0};
bif_type_t bt_varbinary = {NULL, DV_BIN, 0, 0};
bif_type_t bt_any = {NULL, DV_ANY, 0, 0};			/*!< Vector of values of for this "any" type will keep its members serialized into plain session representation. It means that the RDF boxes will loose "long" part and only RO_IDs are preserved, boxes will become incomplete. */
bif_type_t bt_any_box = {NULL, DV_ARRAY_OF_POINTER, 0, 0};	/*!< Vector of values of for this "any" type will keep its members as plain boxes. No serialization, no loss of "long" content of RDF boxes. */
bif_type_t bt_iri_id = {NULL, DV_IRI_ID, 0, 0};
bif_type_t bt_integer = {NULL, DV_LONG_INT, 0, 0};
bif_type_t bt_integer_nn = {NULL, DV_LONG_INT, 0, 0, 1};
bif_type_t bt_iri = {NULL, DV_IRI_ID, 0, 0};
bif_type_t bt_double = {NULL, DV_DOUBLE_FLOAT, 0, 0};
bif_type_t bt_float = {NULL, DV_SINGLE_FLOAT, 0, 0};
bif_type_t bt_numeric = {NULL, DV_NUMERIC, 40, 20};
bif_type_t bt_time = {NULL, DV_TIME, 0, 0};
bif_type_t bt_date = {NULL, DV_DATE, 10, 0};
bif_type_t bt_datetime = {NULL, DV_DATETIME, 10, 0};
bif_type_t bt_timestamp = {NULL, DV_DATETIME, 10, 0};
bif_type_t bt_bin = {NULL, DV_BIN, 10, 0};

boxint
bif_long_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func)
{
  caddr_t arg = bif_arg_unrdf (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  if (dtp == DV_SINGLE_FLOAT)
  return ((boxint) unbox_float (arg));
  if (dtp == DV_DOUBLE_FLOAT)
  return ((boxint) unbox_double (arg));
  if (dtp == DV_NUMERIC)
  {
    int64 tl;
    numeric_to_int64 ((numeric_t) arg, &tl);
    return tl;
  }
  if (dtp != DV_SHORT_INT && dtp != DV_LONG_INT)
  {
    sqlr_new_error ("22023", "SR008",
    "Function %s needs an integer as argument %d, "
    "not an arg of type %s (%d)",
    func, nth + 1, dv_type_title (dtp), dtp);
  }
  return (unbox (arg));
}


iri_id_t
bif_iri_id_or_long_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func)
{
  caddr_t arg = bif_arg_unrdf (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  if (dtp == DV_SINGLE_FLOAT)
    return ((iri_id_t) (unsigned int64) unbox_float (arg));
  if (dtp == DV_DOUBLE_FLOAT)
    return ((iri_id_t) (unsigned int64) unbox_double (arg));
  if (dtp == DV_NUMERIC)
    {
      int64 tl;
      numeric_to_int64 ((numeric_t) arg, &tl);
      return (iri_id_t)(unsigned int64) tl;
    }
  if (dtp == DV_IRI_ID)
    return unbox_iri_id (arg);
  if (dtp != DV_SHORT_INT && dtp != DV_LONG_INT)
    {
      sqlr_new_error ("22023", "SR008",
      "Function %s needs an IRI_ID or an integer as argument %d, "
      "not an arg of type %s (%d)",
      func, nth + 1, dv_type_title (dtp), dtp);
    }
  return (iri_id_t) (unsigned int64) (unbox (arg));
}


iri_id_t
bif_iri_id_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func)
{
  caddr_t arg = bif_arg (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  if (dtp != DV_IRI_ID)
    sqlr_new_error ("22023", "SR008",
		    "Function %s needs an IRI_ID as argument %d, "
		    "not an arg of type %s (%d)",
		    func, nth + 1, dv_type_title (dtp), dtp);
  return (unbox_iri_id (arg));
}

iri_id_t
bif_iri_id_or_null_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func)
{
  caddr_t arg = bif_arg (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  if (DV_DB_NULL == dtp)
    return 0;
  if (dtp != DV_IRI_ID)
    sqlr_new_error ("22023", "SR008",
		    "Function %s needs an IRI_ID or NULL as argument %d, "
		    "not an arg of type %s (%d)",
		    func, nth + 1, dv_type_title (dtp), dtp);
  return (unbox_iri_id (arg));
}

caddr_t
bif_string_or_uname_or_iri_id_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func)
{
  caddr_t arg = bif_arg (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  switch (dtp)
    {
    case DV_IRI_ID: case DV_STRING: case DV_UNAME:
      return arg;
    }
  sqlr_new_error ("22023", "SR008",
		    "Function %s needs a string or UNAME or IRI_ID as argument %d, "
		    "not an arg of type %s (%d)",
		    func, nth + 1, dv_type_title (dtp), dtp);
  return NULL; /* never reached */
}

ptrlong
bif_long_range_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func, ptrlong low, ptrlong hi)
{
  ptrlong arg = bif_long_arg (qst, args, nth, func);
  if (arg < low)
    sqlr_new_error ("22023", "SR339", "Function %s needs an integer not less than %ld as argument %d",
  func, low, nth + 1);
  if (arg > hi)
    sqlr_new_error ("22023", "SR340", "Function %s needs an integer not greater than than %ld as argument %d",
  func, hi, nth + 1);
  return arg;
}


ptrlong
bif_long_low_range_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func, ptrlong low)
{
  ptrlong arg = bif_long_arg (qst, args, nth, func);
  if (arg < low)
    sqlr_new_error ("22023", "SR378", "Function %s needs an integer not less than %ld as argument %d",
  func, low, nth + 1);
  return arg;
}


boxint
bif_long_or_null_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func, int *isnull)
{
  caddr_t arg = bif_arg_unrdf (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  *isnull = 0;
  if (DV_DB_NULL == dtp)
    {
      *isnull = 1;
      return 0;
    }
  if (dtp == DV_SINGLE_FLOAT)
    return ((boxint) unbox_float (arg));
  if (dtp == DV_DOUBLE_FLOAT)
    return ((boxint) unbox_double (arg));
  if (dtp == DV_NUMERIC)
  {
    int64 tl;
    numeric_to_int64 ((numeric_t) arg, &tl);
    return tl;
  }
  if (dtp != DV_SHORT_INT && dtp != DV_LONG_INT)
  {
    sqlr_new_error ("22023", "SR008",
    "Function %s needs an integer as argument %d, "
    "not an arg of type %s (%d)",
    func, nth + 1, dv_type_title (dtp), dtp);
  }
  return (unbox (arg));
}

float
bif_float_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func)
{
  caddr_t arg = bif_arg_unrdf (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  if (dtp == DV_SHORT_INT || dtp == DV_LONG_INT)
  return ((float) unbox (arg));
  else if (dtp == DV_SINGLE_FLOAT)
  return (unbox_float (arg));
  else if (dtp == DV_DOUBLE_FLOAT)
  return ((float) unbox_double (arg));
  else if (dtp == DV_NUMERIC)
  {
    double dt;
    numeric_to_double ((numeric_t) arg, &dt);
    return ((float) dt);
  }

  sqlr_new_error ("22023", "SR009",
   "Function %s needs a float as argument %d, "
   "not an arg of type %s (%d)",
   func, nth + 1, dv_type_title (dtp), dtp);
  return 0;     /*dummy */
}


double
bif_double_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func)
{
  caddr_t arg = bif_arg_unrdf (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  if (dtp == DV_SHORT_INT || dtp == DV_LONG_INT)
  return ((double) unbox (arg));
  else if (dtp == DV_SINGLE_FLOAT)
  return ((double) unbox_float (arg));
  else if (dtp == DV_DOUBLE_FLOAT)
  return (unbox_double (arg));
  else if (dtp == DV_NUMERIC)
  {
    double dt;
    numeric_to_double ((numeric_t) arg, &dt);
    return dt;
  }

  sqlr_new_error ("22023", "SR010",
  "Function %s needs a double as argument %d, "
  "not an arg of type %s (%d)",
  func, nth + 1, dv_type_title (dtp), dtp);
  return 0;
}

double
bif_double_or_null_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func, int * isnull)
{
  caddr_t arg = bif_arg_unrdf (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  *isnull = 0;
  if (DV_DB_NULL == dtp)
    {
      *isnull = 1;
      return 0;
    }
  if (dtp == DV_SHORT_INT || dtp == DV_LONG_INT)
  return ((double) unbox (arg));
  else if (dtp == DV_SINGLE_FLOAT)
  return ((double) unbox_float (arg));
  else if (dtp == DV_DOUBLE_FLOAT)
  return (unbox_double (arg));
  else if (dtp == DV_NUMERIC)
  {
    double dt;
    numeric_to_double ((numeric_t) arg, &dt);
    return dt;
  }

  sqlr_new_error ("22023", "SR010",
  "Function %s needs a double as argument %d, "
  "not an arg of type %s (%d)",
  func, nth + 1, dv_type_title (dtp), dtp);
  return 0;
}

caddr_t
bif_varchar_or_bin_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func)
{
  caddr_t arg = bif_arg_unrdf (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  if ((dtp != DV_BIN && dtp != DV_LONG_BIN &&
       !IS_STRING_DTP (dtp)) || (box_length (args) < 1))
    sqlr_new_error("22023", "SR460",
		   "Function %s needs a varbinary or varchar argument %d with length more than zero, "
		   "not an arg of type %s (%d)",
		   func, nth + 1, dv_type_title (dtp), dtp);
  return arg;
}

ptrlong
bif_long_or_char_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func)
{
  caddr_t arg = bif_arg_unrdf (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  if ((dtp == DV_SHORT_STRING) || (dtp == DV_LONG_STRING))  /* If string */
  {
    return (*((unsigned char *) arg));
  }       /* then give the first character */
  if (IS_WIDE_STRING_DTP (dtp))
  {
    return (*((wchar_t *) arg));
  }
  if (dtp != DV_SHORT_INT && dtp != DV_LONG_INT && dtp != DV_CHARACTER)
  {
    sqlr_new_error ("22023", "SR011",
    "Function %s needs an int or a string as argument %d, "
    "not an arg of type %s (%d)",
    func, nth + 1, dv_type_title (dtp), dtp);
  }
  return (unbox (arg));
}


#define NO_CADDR_T return NULL


caddr_t
bif_array_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func)
{
  caddr_t arg = bif_arg (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  if (dtp == DV_SHORT_STRING || dtp == DV_LONG_STRING
    || IS_NONLEAF_DTP(dtp)
    || dtp == DV_ARRAY_OF_LONG || dtp == DV_ARRAY_OF_FLOAT
    || dtp == DV_ARRAY_OF_DOUBLE || IS_WIDE_STRING_DTP (dtp))
  return (arg);
  sqlr_new_error ("22023", "SR012",
    "Function %s needs a string or an array as argument %d, "
    "not an arg of type %s (%d)",
    func, nth + 1, dv_type_title (dtp), dtp);
  NO_CADDR_T;
}

caddr_t  *
bif_array_of_pointer_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func)
{
  caddr_t arg = bif_arg (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  if (dtp != DV_ARRAY_OF_POINTER)
    sqlr_new_error ("22023", "SR014",
  "Function %s needs a generic array as argument %d, not an arg of type %s (%d)",
  func, nth + 1, dv_type_title (dtp), dtp);
  return (caddr_t *)arg;
}

caddr_t
bif_array_or_strses_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func)
{
  caddr_t arg = bif_arg (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  if (dtp == DV_SHORT_STRING || dtp == DV_LONG_STRING || dtp == DV_UNAME
    || IS_NONLEAF_DTP(dtp)
    || dtp == DV_ARRAY_OF_LONG || dtp == DV_ARRAY_OF_FLOAT
    || dtp == DV_ARRAY_OF_DOUBLE || IS_WIDE_STRING_DTP (dtp)
    || dtp == DV_STRING_SESSION)
  return (arg);
  sqlr_new_error ("22023", "SR012",
    "Function %s needs a string or an array as argument %d, "
    "not an arg of type %s (%d)",
    func, nth + 1, dv_type_title (dtp), dtp);
  NO_CADDR_T;
}

caddr_t
bif_array_or_null_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func)
{
  caddr_t arg = bif_arg (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  if (dtp == DV_DB_NULL)
  return (NULL);
  if (dtp == DV_SHORT_STRING || dtp == DV_LONG_STRING
    || IS_NONLEAF_DTP(dtp)
    || dtp == DV_ARRAY_OF_LONG || dtp == DV_ARRAY_OF_FLOAT
    || dtp == DV_ARRAY_OF_DOUBLE || IS_WIDE_STRING_DTP (dtp))
  return (arg);
  sqlr_new_error ("22023", "SR013",
    "Function %s needs a string or an array as argument %d, "
    "not an arg of type %s (%d)",
    func, nth + 1, dv_type_title (dtp), dtp);
  NO_CADDR_T;
}


caddr_t
bif_strict_array_or_null_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func)
{
  caddr_t arg = bif_arg (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  if (dtp == DV_DB_NULL)
  return (NULL);
  if (IS_NONLEAF_DTP(dtp)
    || dtp == DV_ARRAY_OF_LONG || dtp == DV_ARRAY_OF_FLOAT
    || dtp == DV_ARRAY_OF_DOUBLE || IS_WIDE_STRING_DTP (dtp))
  return (arg);
  sqlr_new_error ("22023", "SR014",
    "Function %s needs an array as argument %d, "
    "not an arg of type %s (%d)",
    func, nth + 1, dv_type_title (dtp), dtp);
  NO_CADDR_T;
}


dbe_key_t *
bif_key_arg (caddr_t * qst, state_slot_t ** args, int n, char * fn)
{
  query_instance_t *qi = (query_instance_t *) qst;
  caddr_t tb_name = bif_string_arg (qst, args, n, fn);
  caddr_t key_name = bif_string_arg (qst, args, n + 1, fn);
  dbe_table_t *tb = qi_name_to_table (qi, tb_name);
  if (!tb)
    {
      sqlr_new_error ("42S02", "SR243", "No table %s in %s", tb_name, fn);
    }
  return tb_find_key (tb, key_name, 1);
}



#define PF_ARG(n) (n < n_args ? unbox (qst_get (qst, args [n])) : 0)


caddr_t bif_sprintf (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);

caddr_t
bif_dbg_printf (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t ret = bif_sprintf (qst, err_ret, args);

  if (ret && IS_STRING_DTP (DV_TYPE_OF (ret)))
    {
      printf ("%s\n", ret);
      fflush (stdout);
    }

  dk_free_box (ret);

  return NULL;
}


caddr_t
bif_dbg_obj_print (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int inx;
  if (c_no_dbg_print)
    return NULL;
  DO_BOX (state_slot_t *, arg, inx, args)
  {
    dbg_print_box (qst_get (qst, arg), stdout);
  }
  END_DO_BOX;

  printf ("\n");		/* Added by AK, 16-JAN-1997 for nicer output. */
  fflush (stdout);

  return NULL;
}

caddr_t
bif_dbg_obj_print_vars (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int inx;

  DO_BOX (state_slot_t *, arg, inx, args)
    {
      if (SSL_HAS_NAME (arg))
	fprintf (stdout, "%s: ", arg->ssl_name);
      printf ("[");
      dbg_print_box (qst_get (qst, arg), stdout);
      printf ("]\n");
    }
  END_DO_BOX;
  fflush (stdout);
  return NULL;
}

static const char *
dbg_user_dump_user_ref (oid_t uid)
{
  static char buf [200];
  user_t *user = sec_id_to_user (uid);
  if (NULL == user)
    {
      sprintf (buf, "[#%ld->!INVALID!]", (long)uid);
      return buf;
    }
  sprintf (buf, "[%s%s,#%ld->\"%.100s\"]",
    (user->usr_disabled ? "DISABLED," : ""), (user->usr_is_role ? "group" : "user"),
    (long)(user->usr_id), user->usr_name );
  return buf;
}

caddr_t
bif_dbg_user_dump (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  user_t *user = bif_user_t_arg (qst, args, 0, "dbg_user_dump", 0, 0);
  if (NULL == user)
    {
      caddr_t uid_or_uname = bif_user_id_or_name_arg (qst, args, 0, "dbg_user_dump");
      if (DV_STRING == DV_TYPE_OF (uid_or_uname))
        printf ("User dump for user \"%s\": no such account at all\n", uid_or_uname);
      else
        printf ("User dump for user #%ld: no such account at all\n", (long)(unbox(uid_or_uname)));
      return NULL;
    }
  printf ("User dump for %s:%s", dbg_user_dump_user_ref (user->usr_id), (user->usr_is_sql ? " SQL on" : " SQL off"));
  printf (", main group %s\n", dbg_user_dump_user_ref (user->usr_g_id));
  if (NULL != user->usr_member_ids)
    {
      int ctr;
      printf ("The group has following members:");
      DO_BOX_FAST (ptrlong, memb_id, ctr, user->usr_member_ids) { printf ("  %s", dbg_user_dump_user_ref (memb_id)); } END_DO_BOX_FAST;
      printf ("\n");
    }
  if (NULL != user->usr_g_ids)
    {
      int ctr;
      printf ("Directly assigned roles:");
      DO_BOX_FAST (ptrlong, role_id, ctr, user->usr_member_ids) { printf ("  %s", dbg_user_dump_user_ref (role_id)); } END_DO_BOX_FAST;
      printf ("\n");
    }
  printf ("Flatten roles were %s:", (0 != user->usr_flatten_g_ids_len) ? "cached" : "NOT cached");
  if (0 == user->usr_flatten_g_ids_len)
    sec_usr_flatten_g_ids_refill (user);
  if ((1 == user->usr_flatten_g_ids_len) && (user->usr_id == user->usr_flatten_g_ids[0]))
    printf (" self only\n");
  else
    {
      int ctr;
      for (ctr = 0; ctr < user->usr_flatten_g_ids_len; ctr++) printf ("  %s", dbg_user_dump_user_ref (user->usr_flatten_g_ids[ctr]));
      printf ("\n");
    }
  NO_CADDR_T;
}

caddr_t
bif_dbg_obj_princ (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int inx;
  int prev_is_strg_const = 1;
  dk_set_t iri_labels = NULL;
  static dk_mutex_t *mtx = NULL;
  static void *prev_thread = NULL;
  void *curr_thread;
  if (c_no_dbg_print)
    return NULL;
  if (NULL == mtx) mtx = mutex_allocate ();
  DO_BOX_FAST_REV (state_slot_t *, arg, inx, args)
  {
    caddr_t val = qst_get (qst, arg);
    if (DV_IRI_ID == DV_TYPE_OF (val))
      {
        iri_id_t iid = unbox_iri_id (val);
        if ((0L != iid) && ((min_bnode_iri_id () > iid) || (min_named_bnode_iri_id () < iid)))
          {
            caddr_t iri = key_id_to_iri ((query_instance_t *) qst, iid);
            dk_set_push (&iri_labels, iri);
          }
      }
  }
  END_DO_BOX_FAST_REV;
/* At this point any use if indexes is complete so the function can enter its own internal mutex w/o the risk of deadlock */
  mutex_enter (mtx);
  curr_thread = THREAD_CURRENT_THREAD;
  if (curr_thread != prev_thread)
    {
      printf ("[THREAD %p]:\n", curr_thread);
      prev_thread = curr_thread;
    }
  DO_BOX (state_slot_t *, arg, inx, args)
  {
    caddr_t val = qst_get (qst, arg);
    int this_is_strg_const = ((SSL_CONSTANT == arg->ssl_type) && (DV_STRING == DV_TYPE_OF (val)));
    if (!(this_is_strg_const || prev_is_strg_const))
      printf (", ");
    if (this_is_strg_const)
      printf ("%s", val);
    else
      {
        dbg_print_box (val, stdout);
        if (DV_IRI_ID == DV_TYPE_OF (val))
          {
            iri_id_t iid = unbox_iri_id (val);
            if (0L == iid)
              goto done_iid; /* see below */
            if ((min_bnode_iri_id () <= iid) && (min_named_bnode_iri_id () > iid))
              {
                caddr_t iri = BNODE_IID_TO_LABEL (iid);
                printf ("=%s", iri);
                dk_free_box (iri);
              }
            else
              {
                caddr_t iri = dk_set_pop (&iri_labels);
                if (!iri)
                  goto done_iid; /* see below */
                printf ("=<%s>", iri);
                dk_free_box (iri);
              }
done_iid: ;
          }
      }
    prev_is_strg_const = this_is_strg_const;
  }
  END_DO_BOX;
  printf ("\n");
  fflush (stdout);
  mutex_leave (mtx);
  return NULL;
}


caddr_t
bif_clear_temp (caddr_t *  qst, caddr_t * err_ret, state_slot_t ** args)
{
  hash_area_t * ha = (hash_area_t *) (ptrlong) bif_long_arg (qst, args, 0, "__clear_temp");
  /*sec_check_dba ((query_instance_t *) qst, "__clear_temp");*/
  setp_temp_clear (NULL, ha, qst);
  return NULL;
}


caddr_t
bif_proc_table_result (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args,
         client_connection_t * cli, va_list ap, int n_ext_args)
{
  state_slot_t vals[TB_MAX_COLS];
  state_slot_t *pvals_buf[TB_MAX_COLS + 20], **saved_slots;
  hash_area_t *ha_orig = (hash_area_t *) cli->cli_result_ts;
  hash_area_t ha_copy = *ha_orig;
  hash_area_t *ha = &ha_copy;
  itc_ha_feed_ret_t ihfr;
  caddr_t * result_qst = (caddr_t *) cli->cli_result_qi;
  QNCAST (query_instance_t, result_qi, result_qst);
  state_slot_t *proc_ctr = ha->ha_slots[0];
  int inx;
  int n_args = qst ? BOX_ELEMENTS (args) : n_ext_args;
  int n_slots, ha_dtp_check_done = 0;
  char autonull[10];
  caddr_t nullptr;
  caddr_t pvals_ptr;
  state_slot_t **pvals;
  BOX_AUTO (nullptr,autonull, 0, DV_DB_NULL);

  n_slots = ha && ha->ha_slots ? BOX_ELEMENTS (ha->ha_slots) : 0;

  box_add (qst_get (result_qst, proc_ctr), box_num (1), result_qst, proc_ctr);
  if (qst && qst != (caddr_t *) -1)
    {
      QNCAST (query_instance_t, qi, qst);
      int64 ctr = unbox (qst_get (result_qst, proc_ctr));
      int64 res_set = qi->qi_query->qr_proc_vectored ? qi->qi_set : result_qi->qi_set;
      ctr = (ctr & 0xffffffffff) | ((int64)res_set << 40);
      qst_set_long (result_qst, proc_ctr, ctr);
    }
  memset (&(vals[0]), 0, sizeof (vals));
  memset (&(pvals_buf[0]), 0, sizeof (pvals_buf));
  memset (&ihfr, 0, sizeof (itc_ha_feed_ret_t));
  BOX_AUTO (pvals_ptr,pvals_buf, n_slots * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  n_slots--;
  pvals = (state_slot_t **) pvals_ptr;
  pvals[0] = proc_ctr;

  for (inx = 0; inx < MIN (n_args, n_slots); inx++)
    {
      state_slot_t *ssl = ha->ha_slots[inx];
      caddr_t v;
      dtp_t dtp, target_dtp = 0;

      if (qst)
	{
	  if (qst != (caddr_t *) -1)
	    v = qst_get (qst, args[inx]);
	  else
	    v = (caddr_t) args[inx];
	}
      else
	{
	  v = va_arg (ap, caddr_t);
	}
      vals[inx + 1].ssl_type = SSL_CONSTANT;
      vals[inx + 1].ssl_constant = v;
      if (ssl)
	vals[inx].ssl_sqt = ssl->ssl_sqt;
      dtp = DV_TYPE_OF (v);
      if (ha->ha_key_cols[inx + 1].cl_col_id == 0)
	ha_dtp_check_done = 1;
      else
	{
	  target_dtp = ha->ha_key_cols[inx + 1].cl_sqt.sqt_dtp;
	  if (IS_BLOB_DTP (target_dtp))
	    target_dtp = DV_BLOB_INLINE_DTP (target_dtp);
	}
      if (dtp != DV_DB_NULL && !ha_dtp_check_done && dtp != target_dtp
          && (DV_ANY != target_dtp)
	  && !(dtp == DV_LONG_INT && IS_INT_DTP (target_dtp))
	  && !(ha->ha_key_cols[inx + 1].cl_sqt.sqt_is_xml && XE_IS_VALID_VALUE_FOR_XML_COL (v)))
	{
	  *err_ret = srv_make_new_error ("22023", "SR540",
	      "procedure view's procedure returned value of type %.50s (dtp %d) instead of %.50s (dtp %d)"
	      " for column %.128s (inx: %d)",
	      dv_type_title (dtp), dtp,
	      dv_type_title (target_dtp),
	      target_dtp,
	      (ha->ha_slots && inx + 1 < n_slots && SSL_HAS_NAME (ha->ha_slots[inx + 1]) ?
	       ha->ha_slots[inx + 1]->ssl_name : ""),
	      inx + 1);
	  return NULL;
	}
      pvals[inx + 1] = &vals[inx + 1];

    }
  for (; inx < n_slots; inx++)
    {
      state_slot_t *ssl = ha->ha_slots[inx];
      vals[inx + 1].ssl_type = SSL_CONSTANT;
      vals[inx + 1].ssl_constant = nullptr;
      if (ssl)
	vals[inx].ssl_sqt = ssl->ssl_sqt;
      pvals[inx + 1] = &vals[inx + 1];
    }
  saved_slots = ha->ha_slots;
  ha->ha_slots = pvals;
  QR_RESET_CTX
    {
      itc_ha_feed (&ihfr, ha, result_qst, 1);
    }
  QR_RESET_CODE
    {
      caddr_t err;
      POP_QR_RESET;
      ha->ha_slots = saved_slots;
      err = thr_get_error_code (THREAD_CURRENT_THREAD);
      if (err && err != (caddr_t) SQL_NO_DATA_FOUND)
	{ /* prefix the error with the procedure view */
	  caddr_t new_err = srv_make_new_error ("22023", "SR342",
	      "Error returning data for procedure view from it\'s procedure : [%.5s] %s",
	      ERR_STATE(err), ERR_MESSAGE (err));
	  dk_free_tree (err);
	  err = new_err;
	}
      sqlr_resignal (err);
    }
  END_QR_RESET;
  ha->ha_slots = saved_slots;
  BOX_DONE (nullptr, autonull);
  BOX_DONE (pvals_ptr, pvals_buf);
  return NULL;
}


caddr_t
bif_result (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t cli_ws = (caddr_t) ((query_instance_t *) qst)->qi_client->cli_ws;
  client_connection_t *cli = (client_connection_t *) ((query_instance_t *) qst)->qi_client;
  va_list dummy;

  if (cli->cli_result_qi)
    {
      bif_proc_table_result (qst, err_ret, args, cli, dummy, 0);
      return NULL;
    }
  if ((!cli_ws && cli_is_interactive (cli)) || cli->cli_resultset_data_ptr)
    {
      if (cli->cli_resultset_data_ptr && !cli->cli_resultset_max_rows)
	return NULL;
      else
	{
	  long len;
	  long n_args = BOX_ELEMENTS ((caddr_t) args);
	  long n_cols = cli->cli_resultset_cols;
	  int inx;
	  caddr_t *out;
	  if (n_args < n_cols)
	    sqlr_new_error ("22023", "SR534",
		"Function result() is called with %ld arguments, but the declared result-set contains %ld columns", n_args, n_cols);
	  len = sizeof (caddr_t) * MAX (n_args, n_cols);
	  if (!cli->cli_resultset_data_ptr)
	    {
	      caddr_t anil = NEW_DB_NULL;
	      out = (caddr_t *) dk_alloc_box (sizeof (caddr_t) + len, DV_ARRAY_OF_POINTER);
	      out[0] = (caddr_t) QA_ROW;
	      DO_BOX (state_slot_t *, arg, inx, args)
	      {
		out[inx + 1] = qst_get (qst, arg);
	      }
	      END_DO_BOX;
	      for (; inx < n_cols; inx++)
		out[inx + 1] = anil;
	      IO_SECT (qst)
	      {
		PrpcAddAnswer ((caddr_t) out, DV_ARRAY_OF_POINTER, PARTIAL, 0);
	      }
	      END_IO_SECT (err_ret);
	      dk_free_box ((box_t) out);
	      dk_free_box (anil);
	    }
	  else
	    {
	      out = (caddr_t *) dk_alloc_box (len, DV_ARRAY_OF_POINTER);
	      DO_BOX (state_slot_t *, arg, inx, args)
	      {
		out[inx] = box_copy_tree (qst_get (qst, arg));
	      }
	      END_DO_BOX;
	      for (; inx < n_cols; inx++)
		out[inx + 1] = NEW_DB_NULL;
	      dk_set_push (cli->cli_resultset_data_ptr, out);
	      if (cli->cli_resultset_max_rows != -1)
		cli->cli_resultset_max_rows--;
	    }
	}
    }
  return NULL;
}


static caddr_t
bif_exec_result (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t cli_ws = (caddr_t) ((query_instance_t *) qst)->qi_client->cli_ws;
  client_connection_t *cli = (client_connection_t *) ((query_instance_t *) qst)->qi_client;
  va_list dummy;
  caddr_t arg_values = bif_arg (qst, args, 0, "exec_result");

  if (DV_TYPE_OF (arg_values) != DV_ARRAY_OF_POINTER || BOX_ELEMENTS (arg_values) < 1)
    sqlr_new_error ("22023", "SR334", "The result names description should be an array in exec_result");

  if (cli->cli_result_qi)
    {
      bif_proc_table_result ((caddr_t *) - 1, err_ret, (state_slot_t **) arg_values, cli, dummy, 0);
      return NULL;
    }
  if ((!cli_ws && cli_is_interactive (cli)) || cli->cli_resultset_data_ptr)
    {
      if (cli->cli_resultset_data_ptr && !cli->cli_resultset_max_rows)
	return NULL;
      else
	{
	  long len;
	  long n_cols = cli->cli_resultset_cols;
	  int inx;
	  caddr_t *out;
	  len = MAX ((n_cols * sizeof (caddr_t)), (box_length ((caddr_t) arg_values)));
	  if (!cli->cli_resultset_data_ptr)
	    {
	      caddr_t anil = NEW_DB_NULL;
	      out = (caddr_t *) dk_alloc_box (sizeof (caddr_t) + len, DV_ARRAY_OF_POINTER);
	      out[0] = (caddr_t) QA_ROW;
	      _DO_BOX (inx, ((caddr_t *) arg_values))
	      {
		out[inx + 1] = ((caddr_t *) arg_values)[inx];
	      }
	      END_DO_BOX;
	      for (; inx < n_cols; inx++)
		out[inx + 1] = anil;
	      IO_SECT (qst)
	      {
		PrpcAddAnswer ((caddr_t) out, DV_ARRAY_OF_POINTER, PARTIAL, 0);
	      }
	      END_IO_SECT (err_ret);
	      dk_free_box ((box_t) out);
	      dk_free_box (anil);
	    }
	  else
	    {
	      out = (caddr_t *) dk_alloc_box (len, DV_ARRAY_OF_POINTER);
	      _DO_BOX (inx, ((caddr_t *) arg_values))
	      {
		out[inx] = box_copy_tree (((caddr_t *) arg_values)[inx]);
	      }
	      END_DO_BOX;
	      for (; inx < n_cols; inx++)
		out[inx + 1] = NEW_DB_NULL;
	      dk_set_push (cli->cli_resultset_data_ptr, out);
	      if (cli->cli_resultset_max_rows != -1)
		cli->cli_resultset_max_rows--;
	    }
	}
    }
  return NULL;
}


void
bif_result_inside_bif (int n, ...)
{
  caddr_t *out;
  int inx;
  va_list ap;
  client_connection_t *cli;


  cli = GET_IMMEDIATE_CLIENT_OR_NULL;
  if (NULL == cli)
  return;

  va_start (ap, n);
  if (cli && cli->cli_result_qi)
  {
    bif_proc_table_result (NULL, NULL, NULL, cli, ap, n);
    return;
  }

  if (!cli)
  return;
  if (cli->cli_ws)
  {
    if (!cli->cli_resultset_data_ptr)
  return;
  }
  else if (!cli_is_interactive(cli))
  return;

  if (cli->cli_resultset_comp_ptr && !cli->cli_resultset_max_rows)
  return;
  if (!cli->cli_resultset_comp_ptr)
  {
    out = (caddr_t *) dk_alloc_box (sizeof (caddr_t) * (1 + n), DV_ARRAY_OF_POINTER);
    out[0] = (caddr_t) QA_ROW;
    for (inx = 0; inx < n; inx++)
  out[inx + 1] = va_arg (ap, caddr_t);
    PrpcAddAnswer ((caddr_t) out, DV_ARRAY_OF_POINTER, PARTIAL, 0);
    dk_free_box ((box_t) out);
  }
  else
  {
    out = (caddr_t *) dk_alloc_box (sizeof (caddr_t) * n, DV_ARRAY_OF_POINTER);
    for (inx = 0; inx < n; inx++)
    out[inx] = box_copy_tree (va_arg (ap, caddr_t));
    dk_set_push (cli->cli_resultset_data_ptr, out);
    if (cli->cli_resultset_max_rows != -1)
  cli->cli_resultset_max_rows--;
  }
  va_end (ap);
}


caddr_t
bif_end_result (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t cli_ws = (caddr_t) ((query_instance_t *) qst)->qi_client->cli_ws;
  client_connection_t *cli = (client_connection_t *) ((query_instance_t *) qst)->qi_client;

  if (!cli_ws && cli_is_interactive (cli) && !cli->cli_result_qi && !cli->cli_resultset_comp_ptr)
    {
      IO_SECT (qst)
      {
	PrpcAddAnswer (SQL_SUCCESS, DV_ARRAY_OF_POINTER, PARTIAL, 0);
      }
      END_IO_SECT (err_ret);
      cli->cli_resultset_cols = 0;
    }
  return NULL;
}


caddr_t
bif_result_names_impl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, int is_select)
{
  long n_out = BOX_ELEMENTS (args), inx;
  caddr_t cli_ws = (caddr_t) ((query_instance_t *) qst)->qi_client->cli_ws;
  client_connection_t *cli = (client_connection_t *) ((query_instance_t *) qst)->qi_client;

  if (cli->cli_result_qi)
    return NULL;
  if ((!cli_ws && cli_is_interactive (cli)) || cli->cli_resultset_comp_ptr)
    {
      if (cli->cli_resultset_comp_ptr && *cli->cli_resultset_comp_ptr)
	{
	  *err_ret = srv_make_new_error ("37000", "SR001", "More than one resultset not supported in a procedure called from exec");
	  return NULL;
	}
      else
	{
	  stmt_compilation_t *sc = (stmt_compilation_t *) dk_alloc_box (sizeof (stmt_compilation_t), DV_ARRAY_OF_POINTER);
	  col_desc_t **cols = (col_desc_t **) dk_alloc_box (n_out * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
	  memset (sc, 0, sizeof (stmt_compilation_t));

	  for (inx = 0; inx < n_out; inx++)
	    {
	      col_desc_t *desc = (col_desc_t *) dk_alloc_box (sizeof (col_desc_t),
		  DV_ARRAY_OF_POINTER);
	      state_slot_t *sl = args[inx];
	      dtp_t dtp = sl->ssl_dtp;

	      cols[inx] = desc;
	      memset (desc, 0, sizeof (col_desc_t));
	      if (SSL_HAS_NAME (sl))
		desc->cd_name = box_dv_short_string (sl->ssl_name);
	      desc->cd_dtp = dtp;
	      desc->cd_scale = box_num (sl->ssl_scale);
	      desc->cd_precision = box_num (sl->ssl_prec);
	      desc->cd_searchable = box_num (0);
	      desc->cd_nullable = box_num (1);
	      desc->cd_updatable = box_num (0);
	    }
	  sc->sc_columns = (caddr_t *) cols;
	  sc->sc_is_select = is_select;
	  if (!cli->cli_resultset_comp_ptr)
	    {
	      caddr_t *desc_box = (caddr_t *) dk_alloc_box (2 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
	      desc_box[0] = (caddr_t) QA_COMPILED;
	      desc_box[1] = (caddr_t) sc;
	      IO_SECT (qst)
	      {
		PrpcAddAnswer ((caddr_t) desc_box, DV_ARRAY_OF_POINTER, PARTIAL, 0);
	      }
	      END_IO_SECT (err_ret);
	      dk_free_tree ((caddr_t) desc_box);
	    }
	  else
	    *((caddr_t *) cli->cli_resultset_comp_ptr) = (caddr_t) sc;
	  cli->cli_resultset_cols = n_out;
	}
    }
  return NULL;
}

caddr_t
bif_result_names (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_result_names_impl (qst, err_ret, args, QT_PROC_CALL);
}

static caddr_t
bif_exec_result_names (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  long n_out, inx;
  caddr_t cli_ws = (caddr_t) ((query_instance_t *) qst)->qi_client->cli_ws;
  client_connection_t *cli = (client_connection_t *) ((query_instance_t *) qst)->qi_client;
  caddr_t arg_descs = bif_arg (qst, args, 0, "exec_result_names");

  if (DV_TYPE_OF (arg_descs) != DV_ARRAY_OF_POINTER || BOX_ELEMENTS (arg_descs) < 1)
    sqlr_new_error ("22023", "SR335", "The result names description should be an array in exec_result_names");

  n_out = BOX_ELEMENTS (arg_descs);
  if (cli->cli_result_qi)
    return NULL;
  if ((!cli_ws && cli_is_interactive (cli)) || cli->cli_resultset_comp_ptr)
    {
      if (cli->cli_resultset_comp_ptr && *cli->cli_resultset_comp_ptr)
	{
	  *err_ret = srv_make_new_error ("37000", "SR001", "More than one resultset not supported in a procedure called from exec");
	  return NULL;
	}
      else
	{
	  stmt_compilation_t *sc = (stmt_compilation_t *) dk_alloc_box (sizeof (stmt_compilation_t), DV_ARRAY_OF_POINTER);
	  col_desc_t **cols = (col_desc_t **) dk_alloc_box (n_out * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
	  memset (sc, 0, sizeof (stmt_compilation_t));
	  memset (cols, 0, n_out * sizeof (caddr_t));

	  for (inx = 0; inx < n_out; inx++)
	    {
	      col_desc_t *desc = (col_desc_t *) dk_alloc_box (sizeof (col_desc_t),
		  DV_ARRAY_OF_POINTER);
	      caddr_t *value = ((caddr_t **) arg_descs)[inx];

	      cols[inx] = desc;
	      memset (desc, 0, sizeof (col_desc_t));

	      if (DV_STRINGP (value))
		{
		  desc->cd_name = box_dv_short_string ((caddr_t) value);
		  desc->cd_dtp = DV_SHORT_STRING;
		  desc->cd_nullable = box_num (1);
		  desc->cd_precision = box_num (256);
		}
	      else if (DV_TYPE_OF (value) == DV_ARRAY_OF_POINTER &&
		  (BOX_ELEMENTS (value) == 7 || BOX_ELEMENTS (value) == 12) /* num elements in col_desc_t */ )
		{
		  if (DV_TYPE_OF (value[1]) != DV_LONG_INT || !strcmp (dv_type_title ((int) (ptrlong) value[1]), "UNK_DV_TYPE"))
		    goto error;
		  if (DV_TYPE_OF (value[2]) != DV_LONG_INT || unbox (value[2]) < 0 || unbox (value[2]) > 20)
		    {
		      /* scale can be negative w oracle jdbc */
		      dk_free_tree (value[2]);
		      value[2] = 0;
		    }
		  if (DV_TYPE_OF (value[3]) != DV_LONG_INT || unbox (value[3]) < 0)
		    goto error;

		  desc->cd_name = box_dv_short_string (value[0]);
		  desc->cd_dtp = (ptrlong) value[1];
		  desc->cd_scale = box_num (unbox (value[2]));
		  desc->cd_precision = box_num (unbox (value[3]));
		  desc->cd_nullable = value[4] ? box_num (1) : box_num (0);
		  desc->cd_updatable = value[5] ? box_num (1) : box_num (0);
		  desc->cd_searchable = value[6] ? box_num (1) : box_num (0);
		}
	      else
		{
		error:
		  dk_free_tree ((box_t) cols);
		  dk_free_box ((box_t) sc);
		  sqlr_new_error ("22023", "SR336", "Wrong result description in bif_result_string_names.");
		}
	    }
	  sc->sc_columns = (caddr_t *) cols;
	  sc->sc_is_select = QT_PROC_CALL;
	  if (!cli->cli_resultset_comp_ptr)
	    {
	      caddr_t *desc_box = (caddr_t *) dk_alloc_box (2 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
	      desc_box[0] = (caddr_t) QA_COMPILED;
	      desc_box[1] = (caddr_t) sc;
	      IO_SECT (qst)
	      {
		PrpcAddAnswer ((caddr_t) desc_box, DV_ARRAY_OF_POINTER, PARTIAL, 0);
	      }
	      END_IO_SECT (err_ret);
	      dk_free_tree ((caddr_t) desc_box);
	    }
	  else
	    *((caddr_t *) cli->cli_resultset_comp_ptr) = (caddr_t) sc;
	  cli->cli_resultset_cols = n_out;
	}
    }
  return NULL;
}

void
bif_define_int (caddr_t name, bif_t bif, bif_metadata_t *bmd)
{
  if (NULL == name_to_bif_metadata_idhash)
    {
      name_to_bif_metadata_idhash = id_str_hash_create (511);
      bif_to_bif_metadata_hash = hash_table_allocate (511);
      name_to_bif_sparql_only_metadata_hash = hash_table_allocate (31);
    }
  else
    {
      bif_metadata_t *old_bmd = find_bif_metadata_by_name (name);
      if (NULL != old_bmd)
          GPF_T1 ("bif name cannot be redefined");
	}
  id_hash_set (name_to_bif_metadata_idhash, (caddr_t)(&name), (caddr_t)(&bmd));
  sethash (bif, bif_to_bif_metadata_hash, bmd);
}

bif_metadata_t *
bif_define (const char *raw_name, bif_t bif)
{
  caddr_t name;
  bif_metadata_t *bmd;
  name = sqlp_box_id_upcase (raw_name);
  bmd = (bif_metadata_t *)dk_alloc_zero (sizeof (bif_metadata_t));
  bmd->bmd_name = box_dv_short_string (name);
  bmd->bmd_main_impl = bif;
  bmd->bmd_max_argcount = MAX_BOX_ELEMENTS;
  bif_define_int (name, bif, bmd);
  return bmd;
}

bif_metadata_t *
bif_define_ex (const char *raw_name, bif_t bif, ...)
{
  unsigned options_bitmask = 0;
  va_list tail;
  bif_metadata_t *bmd = (bif_metadata_t *)dk_alloc_zero (sizeof (bif_metadata_t));
  int bif_is_sparql_only = 0;
  bmd->bmd_main_impl = bif;
  bmd->bmd_max_argcount = MAX_BOX_ELEMENTS;
  va_start (tail, bif);
  for (;;)
    {
      int op = va_arg (tail, int);
      if (BMD_DONE == op)
        break;
      if ((0 >= op) || (COUNTOF__BMD_OPTIONs <= op))
        GPF_T1 ("invalid option in bif_define_ex");
      if (options_bitmask & (1 << op))
        GPF_T1 ("duplicate option in bif_define_ex");
      options_bitmask |= (1 << op);
      switch (op)
        {
        case BMD_DONE: break;
        case BMD_VECTOR_IMPL:		bmd->bmd_vector_impl = va_arg (tail, void *); break;
        case BMD_SQL_OPTIMIZER_IMPL:	bmd->bmd_sql_optimizer_impl = va_arg (tail, void *); break;
        case BMD_SPARQL_OPTIMIZER_IMPL:	bmd->bmd_sparql_optimizer_impl = va_arg (tail, void *); break;
        case BMD_RET_TYPE:		bmd->bmd_ret_type = va_arg (tail, bif_type_t *); break;
        case BMD_MIN_ARGCOUNT:		bmd->bmd_min_argcount = va_arg (tail, int); break;
        case BMD_ARGCOUNT_INC:		bmd->bmd_argcount_inc = va_arg (tail, int); break;
        case BMD_MAX_ARGCOUNT:		bmd->bmd_max_argcount = va_arg (tail, int); break;
        case BMD_IS_AGGREGATE:		bmd->bmd_is_aggregate = 1; break;
        case BMD_IS_PURE:		bmd->bmd_is_pure = 1; break;
        case BMD_IS_DBA_ONLY:		bmd->bmd_is_dba_only = 1; break;
        case BMD_USES_INDEX:		bmd->bmd_uses_index = 1; break;
        case BMD_NO_CLUSTER:		bmd->bmd_no_cluster = 1; break;
        case BMD_SPARQL_ONLY:		bif_is_sparql_only = 1; break;
        default: GPF_T1 ("invalid option in bif_define_ex");
        }
    }
  if (bif_is_sparql_only)
    {
      bmd->bmd_name = box_dv_uname_string (raw_name);
      if (NULL != gethash (bmd->bmd_name, name_to_bif_sparql_only_metadata_hash))
        GPF_T1 ("sparql-only pseudo bif name cannot be redefined");
      sethash (bmd->bmd_name, name_to_bif_sparql_only_metadata_hash, bmd);
    }
  else
    {
      caddr_t name = sqlp_box_id_upcase (raw_name);
      bmd->bmd_name = box_dv_short_string (name);
      bif_define_int (name, bif, bmd);
    }
  return bmd;
}

bif_metadata_t *
bif_define_typed (const char *name, bif_t bif, bif_type_t * bt)
{
  bif_metadata_t *bmd = bif_define (name, bif);
  if (NULL != bmd->bmd_ret_type)
    GPF_T1 ("bif return type cannot be changed");
  bmd->bmd_ret_type = bt;
  return bmd;
}

bif_metadata_t *
find_bif_metadata_by_name (const char *name)
{
  bif_metadata_t **bmd_ptr = (bif_metadata_t **)id_hash_get (name_to_bif_metadata_idhash, (caddr_t)(&name));
  if (!bmd_ptr)
    {
      caddr_t n2 = sqlp_box_id_upcase (name);
      bmd_ptr = (bif_metadata_t **)id_hash_get (name_to_bif_metadata_idhash, (caddr_t)(&n2));
      dk_free_box (n2);
    }
  if (NULL != bmd_ptr) return bmd_ptr[0];
  return NULL;
}

bif_metadata_t *
find_bif_metadata_by_raw_name (const char *name)
{
  bif_metadata_t *bmd = find_bif_metadata_by_name (name);
  if (NULL != bmd)
    return bmd;
  switch (case_mode)
    {
    case CM_MSSQL:
      {
        char *box = strlwr (box_string (name));
        bmd = find_bif_metadata_by_name (box);
        dk_free_box(box);
        if (NULL != bmd)
          return bmd;
        return NULL;
      }
    case CM_UPPER:
      {
        char *box = strupr (box_string (name));
        bmd = find_bif_metadata_by_name (box);
        dk_free_box(box);
        if (NULL != bmd)
          return bmd;
        return NULL;
      }
    }
  return NULL;
}


bif_t
bif_find (const char *name)
{
  bif_metadata_t *bmd = find_bif_metadata_by_raw_name (name);
  if (NULL != bmd)
    return (bmd->bmd_main_impl);
  return NULL;
}


bif_type_t *
bif_type (const char *name)
{
  bif_metadata_t *bmd = find_bif_metadata_by_raw_name (name);
  if (NULL != bmd)
    return (bmd->bmd_ret_type);
  return NULL;
}


void
bif_type_set (bif_type_t *bt, state_slot_t *ret, state_slot_t **params)
{
  if (!bt)
    return;
  if (bt->bt_func)
    {
      long dt, sc_ret, sc_prec, sc_non_null = 0;
      bt->bt_func (params, &dt, &sc_prec, &sc_ret, (caddr_t *) &ret->ssl_sqt.sqt_collation, &sc_non_null);
      ret->ssl_prec = (uint32) sc_prec;
      ret->ssl_scale = (char) sc_ret;
      ret->ssl_dtp = (dtp_t) dt;
      ret->ssl_sqt.sqt_non_null = sc_non_null;
    }
  else
    {
      ret->ssl_dtp = (dtp_t) bt->bt_dtp;
      ret->ssl_prec = bt->bt_prec;
      ret->ssl_scale = (char) bt->bt_scale;
      ret->ssl_sqt.sqt_non_null = bt->bt_non_null;
    }
}


caddr_t
bif_signal (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t state = bif_arg (qst, args, 0, "signal");
  dtp_t state_dtp;

  state_dtp = DV_TYPE_OF (state);

  if ((DV_LONG_INT == state_dtp || DV_SHORT_INT == state_dtp) && SQL_NO_DATA_FOUND == unbox (state))
  *err_ret = box_copy (state);
  else if (!DV_STRINGP (state))
  {
    sqlr_new_error ("22023", "SR169",
    "signal state should be an integer 100 (NO DATA FOUND) or a string value, not an %s",
    dv_type_title (state_dtp));
  }
  else if (BOX_ELEMENTS (args) == 2)
  {
    caddr_t message = bif_arg (qst, args, 1, "signal");
    if (!DV_STRINGP (message))
      *err_ret = list (3, QA_ERROR, box_copy (state), box_dv_short_string ("No data found or unspecified message"));
    else
      *err_ret = list (3, QA_ERROR, box_copy (state), box_copy (message));
  }
  else if (BOX_ELEMENTS (args) == 3)
  {
    caddr_t message = bif_string_arg (qst, args, 1, "signal");
    caddr_t ncode = bif_string_arg (qst, args, 2, "signal");
    *err_ret = srv_make_new_error (state, ncode, "%s", message);
  }
  else
  sqlr_error ("07001", "signal state can accept up to 3 arguments.");
  return NULL;
}


/* Now returns 0 for NULL, and also the lengths of the BLOBS.
   Modified by AK 30-JAN-1997.  */
caddr_t
bif_length (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  long len = 0;
  caddr_t arg = bif_arg_unrdf (qst, args, 0, "length"); /* Was: bif_array_arg */
  dtp_t dtp = DV_TYPE_OF (arg);
  switch (dtp)
    {
    case DV_DB_NULL:
      return (box_num (0));
    case DV_BLOB_HANDLE:
    case DV_BLOB_WIDE_HANDLE:
      return box_num (((blob_handle_t *) arg)->bh_length);
#ifdef BIF_XML
    case DV_XML_ENTITY:
      if (XE_IS_PERSISTENT((xml_entity_t *)arg))
  return box_num (((xml_entity_t *) arg)->xe_doc.xpd->xpd_bh->bh_length);
    else
  sqlr_new_error ("22023", "SR015", "Function length is not applicable to XML tree entity");
#endif
    }
  if (IS_BOX_POINTER (arg))
  len = box_length (arg);
  switch (dtp)      /* Was: switch(box_tag (arg)) */
  {
  case DV_STRING:
  case DV_C_STRING:
  case DV_UNAME:
    return (box_num (len - 1));
  case DV_BIN:
  case DV_LONG_BIN:
    return (box_num (len));
  case DV_ARRAY_OF_POINTER: case DV_LIST_OF_POINTER: case DV_ARRAY_OF_XQVAL:
  case DV_ARRAY_OF_LONG:
    return (box_num (len / sizeof (ptrlong)));
  case DV_ARRAY_OF_FLOAT:
    return (box_num (len / sizeof (long)));
  case DV_ARRAY_OF_DOUBLE:
    return (box_num (len / sizeof (double)));
  case DV_WIDE:
  case DV_LONG_WIDE:
    return (box_num (len / sizeof (wchar_t) - 1));
  case DV_STRING_SESSION:
    return (box_num (strses_length ((dk_session_t *) arg)));
  case DV_COMPOSITE:
    return (box_num (box_length (arg) - 2));
  default:      /* Was: return 0; */
    {
  sqlr_new_error ("22023", "SR016",
    "Function length needs a string or array as its argument, "
    "not an argument of type %d (= %s)",
    dtp, dv_type_title (dtp)
    );
    }
  }
  NO_CADDR_T;
}

long raw_length (caddr_t arg)
{
  long len = 0;
  dtp_t dtp = DV_TYPE_OF (arg);
  switch (dtp)
    {
    case DV_DB_NULL:
      return 0;
    case DV_BLOB_HANDLE:
    case DV_BLOB_WIDE_HANDLE:
      return ((blob_handle_t *) arg)->bh_diskbytes;
#ifdef BIF_XML
    case DV_XML_ENTITY:
      if (XE_IS_PERSISTENT((xml_entity_t *)arg))
        return ((xml_entity_t *) arg)->xe_doc.xpd->xpd_bh->bh_diskbytes;
#endif
    }
  if (IS_BOX_POINTER (arg))
    len = box_length (arg);
  else
    len = sizeof (box_t);
  switch (dtp)      /* Was: switch(box_tag (arg)) */
  {
  case DV_STRING:
  case DV_C_STRING:
    return len - 1;
  case DV_WIDE:
  case DV_LONG_WIDE:
    return len  - sizeof (wchar_t);
  case DV_STRING_SESSION:
    return strses_length ((dk_session_t *) arg);
  case DV_COMPOSITE:
    return box_length (arg) - 2;
  case DV_ARRAY_OF_POINTER:
  case DV_LIST_OF_POINTER:
  case DV_ARRAY_OF_XQVAL:
  case DV_ARRAY_OF_LONG:
  case DV_ARRAY_OF_FLOAT:
  case DV_ARRAY_OF_DOUBLE:
  default:
    {
      return len;
    }
  }
}

caddr_t
bif_raw_length (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg = bif_arg (qst, args, 0, "raw_length"); /* Was: bif_array_arg */
  dtp_t dtp = DV_TYPE_OF (arg);
  if (DV_RDF == dtp)
    return box_num (box_length (arg) + raw_length (((rdf_box_t *)arg)->rb_box));
  return box_num (raw_length (arg));
}



/* Generic vector accessor for bif_aref and bif_get_keyword.
   inx is zero-based index. Its validity should have been
   checked beforehand.
   Maybe this should be a macro?
 */
/* Yes, now it has been defined as a macro in widv.h, so commented
   out here:
   caddr_t gen_aref(caddr_t arr, long inx, dtp_t vectype, char *calling_fun)
   {
   switch(vectype)
   {
   case DV_ARRAY_OF_POINTER: case DV_LIST_OF_POINTER: case DV_ARRAY_OF_XQVAL:
   { return (box_copy_tree (((caddr_t*)arr) [inx])); }
   case DV_ARRAY_OF_LONG:
   { return (box_num ( (((long *)arr) [inx])) ); }
   case DV_ARRAY_OF_DOUBLE:
   { return (box_double (((double*)arr) [inx])); }
   case DV_ARRAY_OF_FLOAT:
   { return (box_float (((float*)arr) [inx])); }
   case DV_SHORT_STRING: case DV_LONG_STRING:
   { return (box_num ( (((unsigned char *) arr) [inx]))); }
   default:
   {
   sqlr_new_error ("42000", "XXXXX"
   "%s expects a vector, not an arg of type %s (%d)",
   calling_fun,dv_type_title(vectype), vectype);
   }
   }
   }
 */

int
strses_aref (caddr_t ses1, int idx)
{
  dk_session_t *ses = (dk_session_t *)ses1;
  unsigned char buf;

  if (strses_get_part (ses, &buf, idx, 1))
    sqlr_new_error ("22003", "SR017",
	"aref: Bad array subscript (zero-based) %d for an arg of type \'string_output\' "
	" and length %lu.",
	idx, (unsigned long)strses_length(ses));

  return buf;
}

/* Should we allow also reference to terminal-zero with strings?
   E.g. aref('kala',4) -> 0 ???
   Now this allows it.
 */
caddr_t
bif_aref (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arr = bif_array_or_strses_arg (qst, args, 0, "aref");
  int inx, n_elems;
  dtp_t dtp;
  int idxcount = BOX_ELEMENTS (args) - 1;
  int idxctr = 1;
  if (idxcount <= 0)
    sqlr_new_error ("22003", "SR020", "aref() requires 2 or more arguments, but only %d passed.", idxcount+1);
  dtp = DV_TYPE_OF (arr);

again:
  inx = (long) bif_long_arg (qst, args, idxctr, "aref");
  n_elems = (box_length (arr) / get_itemsize_of_vector (dtp));
  if ((inx >= n_elems && DV_STRING_SESSION != box_tag(arr)) || (inx < 0)) /* Catch negative indexes also! */
    {
      sqlr_new_error ("22003", "SR017",
      "aref: Bad array subscript (zero-based) %d for an arg of type %s "
      "(%d) and length %d.",
      inx, dv_type_title (dtp), dtp, n_elems);
    }
  if (idxctr == idxcount)
    return (gen_aref (arr, inx, dtp, "aref"));
  if (IS_NONLEAF_DTP (dtp))
    {
      arr = ((caddr_t *)arr)[inx];
      dtp = DV_TYPE_OF (arr);
      if (dtp == DV_SHORT_STRING || dtp == DV_LONG_STRING || dtp == DV_UNAME
		|| IS_NONLEAF_DTP(dtp)
		|| dtp == DV_ARRAY_OF_LONG || dtp == DV_ARRAY_OF_FLOAT
		|| dtp == DV_ARRAY_OF_DOUBLE || IS_WIDE_STRING_DTP (dtp)
		|| dtp == DV_STRING_SESSION)
	 {
	   idxctr ++;
	   goto again; /* see above */
	 }
    }
/* failed_indexing */
  sqlr_new_error ("22003", "SR020", "aref() is called with %d index arguments but only %d first indexes can be accessed.", idxcount, idxctr);
  NO_CADDR_T;
}


caddr_t
bif_aref_or_default (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arr = bif_array_or_strses_arg (qst, args, 0, "aref_or_default");
  int inx, n_elems;
  dtp_t dtp;
  int argcount = BOX_ELEMENTS (args);
  int idxcount = argcount - 2;
  int idxctr = 1;
  if (idxcount <= 0)
    sqlr_new_error ("22003", "SR020", "aref_or_default() requires 3 or more arguments, but only %d passed.", argcount);
  dtp = DV_TYPE_OF (arr);

again:
  inx = (long) bif_long_arg (qst, args, idxctr, "aref_or_default");
  n_elems = (box_length (arr) / get_itemsize_of_vector (dtp));
  if ((inx >= n_elems && DV_STRING_SESSION != box_tag(arr)) || (inx < 0)) /* Catch negative indexes also! */
    goto use_default; /* see below */
  if (idxctr == idxcount)
    return (gen_aref (arr, inx, dtp, "aref_or_default"));
  if (IS_NONLEAF_DTP (dtp))
    {
      arr = ((caddr_t *)arr)[inx];
      dtp = DV_TYPE_OF (arr);
      if (dtp == DV_SHORT_STRING || dtp == DV_LONG_STRING || dtp == DV_UNAME
		|| IS_NONLEAF_DTP(dtp)
		|| dtp == DV_ARRAY_OF_LONG || dtp == DV_ARRAY_OF_FLOAT
		|| dtp == DV_ARRAY_OF_DOUBLE || IS_WIDE_STRING_DTP (dtp)
		|| dtp == DV_STRING_SESSION)
	 {
	   idxctr ++;
	   goto again; /* see above */
	 }
    }
use_default:
  return box_copy_tree (bif_arg (qst, args, argcount-1, "aref_or_default"));
}


caddr_t
bif_aref_set_0 (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t *arr = (caddr_t *) bif_array_arg (qst, args, 0, "aref_set_0");
  caddr_t res;
  int inx, n_elems;
  dtp_t dtp;
  int argcount = BOX_ELEMENTS (args);
  int idxctr = 1;
  if (argcount <= 1)
    sqlr_new_error ("22003", "SR020", "aref_set_0() requires 2 or more arguments, but only %d passed.", argcount);
  dtp = DV_TYPE_OF (arr);

again:
  inx = (int) bif_long_arg (qst, args, idxctr, "aref_set_0");
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (arr))
    sqlr_new_error ("22003", "SR020", "aref_set_0() is called with %d index arguments but only %d first indexes can be accessed.", argcount-1, idxctr-1);
  n_elems = BOX_ELEMENTS (arr);
  if ((inx >= n_elems) || (inx < 0)) /* Catch negative indexes also! */
    sqlr_new_error ("22003", "SR017",
      "aref_set_0: Bad array subscript (zero-based) %d for an arg of type %s (%d) and length %d.",
      inx, dv_type_title (dtp), dtp, n_elems );
  if (++idxctr < argcount)
    goto again; /* see above */
  res = arr[inx];
  arr[inx] = NULL;
  return res;
}

caddr_t
bif_aset (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arr = bif_array_arg (qst, args, 0, "aset");
  long inx, len;
  int idxcount = BOX_ELEMENTS (args) - 2;
  int idxctr = 1;
  caddr_t it;
  if (idxcount <= 0)
    sqlr_new_error ("22003", "SR020", "aset() requires 3 or more arguments, but only %d passed.", idxcount+2);
  it = bif_arg (qst, args, idxcount + 1, "aset");
#if 0
  if (args[0]->ssl_is_observer)
    sqlr_new_error ("22023", "UD003", "aset has no effect on values returned by member observers");
#endif

again:
  inx = (long) bif_long_arg (qst, args, idxctr, "aset");
  if (inx < 0)
  goto bs;
  len = box_length (arr);
  switch (box_tag (arr))
  {
  case DV_STRING:
    if (inx >= len)
  goto bs;
    arr[inx] = (char) bif_long_arg (qst, args, idxcount + 1, "aset");
    break;
  case DV_ARRAY_OF_POINTER: case DV_LIST_OF_POINTER: case DV_ARRAY_OF_XQVAL:
    if (((size_t) (inx)) >= len / sizeof (caddr_t))
      goto bs;
    if (idxctr < idxcount)
      {
	arr = ((caddr_t *) arr)[inx];
	idxctr ++;
	if (!IS_BOX_POINTER (arr))
          sqlr_new_error ("22003", "SR020", "aset() requires %d or more dimensions for input vector.", idxctr);
	goto again; /* see above */
      }
    dk_free_tree (((caddr_t *) arr)[inx]);
    ((caddr_t *) arr)[inx] = box_copy_tree (it);
    break;

  case DV_ARRAY_OF_LONG:
    if (((size_t) inx) >= len / sizeof (caddr_t))
  goto bs;
    ((ptrlong *) arr)[inx] = unbox (it);
    break;
  case DV_ARRAY_OF_FLOAT:
    if (((size_t) inx) >= len / sizeof (caddr_t))
  goto bs;
    ((float *) arr)[inx] = bif_float_arg (qst, args, idxcount + 1, "aset");
    break;
  case DV_ARRAY_OF_DOUBLE:
    if (((size_t) inx) >= len / sizeof (double))
    goto bs;
    ((double *) arr)[inx] = bif_double_arg (qst, args, idxcount + 1, "aset");
    break;
  case DV_WIDE:
  case DV_LONG_WIDE:
    if (((size_t) inx) >= len / sizeof (wchar_t))
  goto bs;
    ((wchar_t *)arr)[inx] = (wchar_t) unbox (it);
    break;
  default:
    if (1 == idxctr)
      return 0;
  }
  if (idxctr < idxcount)
    sqlr_new_error ("22003", "SR020", "aset() is called with %d index arguments but only %d first indexes can be accessed.", idxcount, idxctr);
  return 0;

bs:
  if (1 == idxcount)
    sqlr_new_error ("22003", "SR020", "Bad array subscript %ld in aset.", (long)inx);
  else
    sqlr_new_error ("22003", "SR020", "Argument %d of aset is a bad array subscript (value %ld exceeds array size).", idxcount+1, (long)inx);
  NO_CADDR_T;
}

caddr_t
bif_aset_zap_arg (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t *arr = (caddr_t *) bif_array_arg (qst, args, 0, "aset_zap_arg");
  int inx, n_elems;
  dtp_t dtp;
  int argcount = BOX_ELEMENTS (args);
  int idxctr = 1;
  if (argcount <= 2)
    sqlr_new_error ("22003", "SR020", "aset_zap_arg() requires 3 or more arguments, but only %d passed.", argcount);
  dtp = DV_TYPE_OF (arr);

again:
  inx = (int) bif_long_arg (qst, args, idxctr, "aset_zap_arg");
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (arr))
    sqlr_new_error ("22003", "SR020", "aset_zap_arg() is called with %d index arguments but only %d first indexes can be accessed.", argcount-2, idxctr-1);
  n_elems = BOX_ELEMENTS (arr);
  if ((inx >= n_elems) || (inx < 0)) /* Catch negative indexes also! */
    sqlr_new_error ("22003", "SR017",
      "aref_set_0: Bad array subscript (zero-based) %d for an arg of type %s (%d) and length %d.",
      inx, dv_type_title (dtp), dtp, n_elems );
  if (++idxctr < argcount-1)
    goto again; /* see above */
  return (caddr_t) (ptrlong) qst_swap_or_get_copy (qst, args[argcount-1], arr+inx);
}


caddr_t
bif_aset_1_2_zap (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  /* destructive a[tgt] := b[src1][src2] */
  caddr_t * tgt = bif_array_of_pointer_arg (qst, args, 0, "aset_1_2_zap");
  unsigned int tgt_inx = bif_long_arg (qst, args, 1,  "aset_1_2_zap");
  caddr_t ** src = (caddr_t**)bif_array_of_pointer_arg (qst, args, 2, "aset_1_2_zap");
  unsigned int src_inx_1 = bif_long_arg (qst, args, 3,  "aset_1_2_zap");
  unsigned int src_inx_2 = bif_long_arg (qst, args, 4,  "aset_1_2_zap");
  if (tgt_inx >= BOX_ELEMENTS (tgt) || src_inx_1 >= BOX_ELEMENTS (src)
      || DV_ARRAY_OF_POINTER != DV_TYPE_OF (src[src_inx_1])
      || src_inx_2 >= BOX_ELEMENTS (src[src_inx_1]))
    sqlr_new_error ("42000", "VEC..",  "Bad arguments to aset_1_2_zap ");
  if (tgt[tgt_inx])
    dk_free_tree (tgt[tgt_inx]);
  tgt[tgt_inx] = src[src_inx_1][src_inx_2];
  src[src_inx_1][src_inx_2] = NULL;
  return NULL;
}



/* Now returns back the modified array itself (given as a first argument)
   instead of the ascii value stored to place as before.
   I think this is more useful this way, at least when arr is a string.
   E.g. chr$(65) can be defined now as aset(make_string(1),0,65)
   (AK 15-JAN-1997) (Now defined internally. See bif_chr below.)
   I do not know what happens when the arr argument is some other kind
   of an array...

   Fuck! It's not possible to create bif functions that return back
   the same box they got as an argument (it will be free'ed twice
   and then whole Kubl will soon bomb out.)
   So the old ways have been restored now.
 */

caddr_t
bif_make_string (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  ptrlong n = bif_long_range_arg (qst, args, 0, "make_string", 0, 10000000);
  caddr_t str = dk_alloc_box_zero (n + 1, DV_LONG_STRING);
  return str;
}


caddr_t
bif_make_wstring (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  ptrlong n = bif_long_range_arg (qst, args, 0, "make_wstring", 0, 10000000 / VIRT_MB_CUR_MAX);
  caddr_t str = dk_alloc_box_zero ((n + 1) * sizeof (wchar_t), DV_LONG_WIDE); /* was: n*sizeof (wchar_t)+1 */
  return str;
}


caddr_t
bif_make_bin_string (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  ptrlong n = bif_long_range_arg (qst, args, 0, "make_bin_string", 0, 10000000);
  caddr_t str = dk_alloc_box_zero (n * sizeof (wchar_t), DV_BIN);
  return str;
}


caddr_t
bif_make_array (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  ptrlong n = bif_long_range_arg (qst, args, 0, "make_array", 0, 10000000);
  caddr_t tp = bif_string_arg (qst, args, 1, "make_array");
  dtp_t dtp = 0;
  caddr_t arr;
  if (n < 0)
  sqlr_new_error ("22003", "SR021", "make_array called with an invalid count %ld", n);
  if (0 == strcmp (tp, "float"))
  {
    dtp = DV_ARRAY_OF_FLOAT;
    n = n * sizeof (float); /* Was: 4 */
  }
  else if (0 == strcmp (tp, "double"))
  {
    dtp = DV_ARRAY_OF_DOUBLE;
    n = n * sizeof (double);  /* Was: 8 */
  }
  else if (0 == strcmp (tp, "long"))
  {
    dtp = DV_ARRAY_OF_LONG;
    n = n * sizeof (ptrlong);  /* Was: 8 */
  }
  else if (0 == strcmp (tp, "any"))
  {
    dtp = DV_ARRAY_OF_POINTER;
    n = n * sizeof (caddr_t); /* Was (incorrectly) 4 */
  }
  else
  sqlr_new_error ("22023", "SR022",
  "Type for make_array must be float, double, long or any");

  if (NULL == (arr = dk_try_alloc_box (n, dtp)))
    qi_signal_if_trx_error ((query_instance_t *)qst);
  memset (arr, 0, n);
  return arr;
}


/* New modification at 22-2-1997 by AK.
   Now allows a call with only two arguments,
   as well as calls with any of the three arguments given as NULL.
   Furthermore, the first argument can be also of type DV_G_REF
   or DV_G_REF_CLASS, that is an object id, which is dissected
   in the similar way as any other string.
   If the first argument is NULL, then NULL is returned.

   In the case where third argument is missing or is NULL,
   subseq acts like it were supplied as length(string)
   (where string is the first argument), that is takes everything
   from 'from' to the end of string.

   E.g. this allows now:

   subseq(str,i) is equal to subseq(str,i,length(str))

   subseq(str,0,strchr(str,'/'))
   Cut everything after, and including the first slash if there is one.

   subseq(str,strchr(str,'/'))
   Take everything from the first slash onwards (including it),
   or, if there are no slashes, return an empty string.

   subseq(str,strchr(str,'/'),strrchr(str,'/'))
   Take everything from the first slash onwards to the last
   slash in the str (but excluding it),
   or, if there is only one slash, or no slashes at all,
   return an empty string.

 */
dk_session_t *
strses_subseq (dk_session_t *ses, long from, long to)
{
  dk_session_t *out = strses_allocate ();
  char in_buffer[DKSES_OUT_BUFFER_LENGTH];

  if (ses->dks_session->ses_file->ses_max_blocks_init)
    strses_enable_paging (out,
	ses->dks_session->ses_file->ses_max_blocks_init * DKSES_IN_BUFFER_LENGTH);

  while (from < to)
    {
      int to_read = MIN (sizeof (in_buffer), to - from);
      if (strses_get_part (ses, in_buffer, from, to_read))
	break;
      session_buffered_write (out, in_buffer, to_read);
      from += to_read;
    }
  return out;
}


caddr_t
bif_subseq (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int n_args = BOX_ELEMENTS (args);
  caddr_t str = bif_arg (qst, args, 0, "subseq");

  long from = 0; /* = bif_long_arg(qst, args, 1, "subseq"); Inclusive start */
  long to = 0;   /* = bif_long_arg(qst, args, 2, "subseq"); Exclusive end  */
  caddr_t num_arg2 = bif_arg (qst, args, 1, "subseq");
  caddr_t num_arg3 = ((n_args > 2) ? bif_arg (qst, args, 2, "subseq") : NULL);

  dtp_t dtp1;
  dtp_t dtp2 = DV_TYPE_OF (num_arg2);

  /* If the third argument is missing, then act like it were NULL: */
  dtp_t dtp3 = ((n_args > 2) ? DV_TYPE_OF (num_arg3) : DV_DB_NULL);
  int fail_in_dtp3 = 0;
  long len;
  caddr_t res;
  int sizeof_char;

retry_unrdf:
  dtp1 = DV_TYPE_OF (str);
  sizeof_char = IS_WIDE_STRING_DTP (dtp1) ? sizeof (wchar_t) : sizeof (char);
  /* Return NULL if the first argument is NULL: */
  if (DV_DB_NULL == dtp1)
    return (NEW_DB_NULL);
  switch (dtp1)
    {
    case DV_RDF:
      {
        rdf_box_t *rb = (rdf_box_t *)str;
        /*if (RDF_BOX_DEFAULT_TYPE != rb->rb_type)
          sqlr_new_error ("22023", "SR587",
            "Function subseq() can not use a typed RDF box as its first argument" );*/
        str = rb->rb_box;
        goto retry_unrdf; /* see above */
      }
    case DV_STRING: case DV_UNAME: case DV_WIDE: case DV_LONG_WIDE:
    case DV_BLOB_HANDLE: case DV_BLOB_WIDE_HANDLE: case DV_BLOB_XPER_HANDLE:
    case DV_STRING_SESSION: case DV_ARRAY_OF_POINTER: case DV_BIN:
      break;
    default:
      sqlr_new_error ("22023", "SR023",
        "Function subseq needs a string, array or object id as its first argument, "
        "not an arg of type %s (%d)",
        dv_type_title (dtp1), dtp1 );
    }

  /* box_length returns a string length + 1, except with object id's */
  if (dtp1 == DV_ARRAY_OF_POINTER)
    len = BOX_ELEMENTS (str);
  else if (dtp1 == DV_STRING_SESSION)
    len = strses_length ((dk_session_t *)str);
  else if (dtp1 == DV_BIN) /* no trailing zero */
    len = box_length (str) / sizeof_char;
  else
    len = box_length (str) / sizeof_char - 1;
  /* Second argument is NULL? Force an empty substring as result. */
  if (DV_DB_NULL == dtp2)
    {
      from = len;
      to = len;
    }
  /* If the third arg is NULL or missing, then set 'to' to the end of string: */
  else if (is_some_sort_of_an_integer (dtp2) && (DV_DB_NULL == dtp3))
    {
      from = (long) unbox (num_arg2);
      to = len;
    }

  else if (!is_some_sort_of_an_integer (dtp2) ||
    ((fail_in_dtp3 = 1), !is_some_sort_of_an_integer (dtp3)))
    {
      sqlr_new_error ("22023", "SR024",
      "Function subseq needs integers or NULLs as its arguments 2 and 3, "
      "not an argument of type %s (%d)",
      dv_type_title (fail_in_dtp3 ? dtp3 : dtp2),
      (fail_in_dtp3 ? dtp3 : dtp2)
      );
    }
  else
    /* Both are integers. */
    {
      from = (long) unbox (num_arg2);
      to = (long) unbox (num_arg3);
    }

  if (from < 0 || to < 0)
    sqlr_new_error ("22023", "SR345", "invalid offset arguments to subseq");
  if (DV_BLOB_HANDLE == dtp1 || DV_BLOB_WIDE_HANDLE == dtp1)
    {
      blob_handle_t *pbh=(blob_handle_t*)str;
      caddr_t bs = blob_subseq (((query_instance_t *) qst)->qi_trx, (caddr_t) pbh,from,to);
      return bs;
    }

  to = MIN (to, len);

  /* Changed (from >= to) to (from > to), allowing now empty substrings. */
  if (from > to)
  sqlr_new_error ("22011", "SR025",
    "subseq: Bad string subrange: from=%ld, to=%ld, len=%ld.",
  (long)from, (long)to, (long)len);

  if (DV_ARRAY_OF_POINTER == dtp1)
    {
      res = dk_alloc_box ((to - from) * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      if (to > from)
        {
          int inx;
          for (inx = from; inx < to; inx++)
            ((caddr_t *)res)[inx - from] = box_copy_tree (((caddr_t *)str)[inx]);
        }
      return res;
    }
  if (DV_STRING_SESSION == dtp1)
    return (caddr_t) strses_subseq ((dk_session_t *)str, from, to);

  if (DV_UNAME == dtp1)
    {
      if ((0x80 == (str[from] & 0xC0)) || (0x80 == (str[to] & 0xC0)))
        sqlr_new_error ("22011", "SR541",
          "subseq: subrange from=%ld, to=%ld crosses UTF-8 character in the middle",
             (long)from, (long)to );
      return box_dv_uname_nchars (str + from, to - from);
    }
  res = dk_alloc_box (((to - from) + 1) * sizeof_char,
    (dtp_t)(IS_WIDE_STRING_DTP (dtp1) ? DV_WIDE : DV_LONG_STRING));
  memcpy (res, str + from * sizeof_char, (to - from) * sizeof_char);
  memset (res + (to - from) * sizeof_char, 0, sizeof_char);
  return res;
}



/* This is more to SQL-standard, substr or substring */
caddr_t
bif_substr (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t str = bif_string_or_wide_or_null_or_strses_arg (qst, args, 0, "substr");
  long from = (long) bif_long_low_range_arg (qst, args, 1, "substr", 1); /* One-based start */
  long piecelen = (long) bif_long_range_arg (qst, args, 2, "substr", 0, 10000000); /* substr length */
  long len;
  long to;
  caddr_t res;
  dtp_t dtp1 = DV_TYPE_OF (str);
  int sizeof_char = IS_WIDE_STRING_DTP (dtp1) ? sizeof (wchar_t) : sizeof (char);


  if (NULL == str)
    {
      return (NEW_DB_NULL);
    }
  if (dtp1 == DV_STRING_SESSION)
    len = strses_length ((dk_session_t *) str);
  else
    len = (box_length (str) / sizeof_char - 1); /* box_length returns a length + 1 */

  if (from)
    {
      from--;
    }       /* One-based indexing. */
  to = from + piecelen;
  to = MIN (to, len);

  if (from > to)
    sqlr_new_error ("22011", "SR026",
	"substr: Bad string subrange: from=%ld, to=%ld, len=%ld.",
	(long)from, (long)to, (long)len);

  res = dk_alloc_box (((to - from) + 1) * sizeof_char, (dtp_t)(IS_WIDE_STRING_DTP (dtp1) ? DV_WIDE : DV_LONG_STRING));
  if (dtp1 == DV_STRING_SESSION)
    strses_get_part ((dk_session_t *) str, res, from, to - from);
  else
    memcpy (res, str + from * sizeof_char, (to - from) * sizeof_char);
  memset (res + ((to - from) * sizeof_char), 0, sizeof_char);
  return res;
}


/* left(str,n) takes n first characters of str. */
caddr_t
bif_left (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t str = bif_arg (qst, args, 0, "left");
  long to = (long) bif_long_range_arg (qst, args, 1, "left", 0, 10000000); /* substr length */
  caddr_t res;
  long len;
  dtp_t dtp1;
  int sizeof_char;

retry_unrdf:
  dtp1 = DV_TYPE_OF (str);
  sizeof_char = IS_WIDE_STRING_DTP (dtp1) ? sizeof (wchar_t) : sizeof (char);
  if (dtp1 == DV_DB_NULL)
    str = NULL;
  else if (dtp1 != DV_STRING && dtp1 != DV_C_STRING &&
      !IS_WIDE_STRING_DTP (dtp1) && dtp1 != DV_UNAME &&
      dtp1 != DV_BIN  && dtp1 != DV_LONG_BIN)
    {
      if (DV_RDF == dtp1)
        {
          rdf_box_t *rb = (rdf_box_t *)str;
          /*if (RDF_BOX_DEFAULT_TYPE != rb->rb_type)
            sqlr_new_error ("22023", "SR588",
              "Function left() can not use a typed RDF box as its first argument" );*/
          str = rb->rb_box;
          goto retry_unrdf; /* see above */
        }
      sqlr_new_error ("22023", "SR007",
	"Function left needs a string or NULL or binary as argument 1, "
	"not an arg of type %s (%d)",
	dv_type_title (dtp1), dtp1);
     }
  if (NULL == str)
    {
      return (NEW_DB_NULL);
    }

  if (dtp1 != DV_BIN  && dtp1 != DV_LONG_BIN)
    len = (box_length (str) / sizeof_char - 1); /* box_length returns a length + 1 */
  else
    len = (box_length (str) / sizeof_char);

  to = MIN (to, len);

  if (dtp1 != DV_BIN  && dtp1 != DV_LONG_BIN)
    {
      if (DV_UNAME == dtp1)
        {
          if (0x80 == (str[to] & 0xC0))
            sqlr_new_error ("22011", "SR591",
              "Function LEFT: ending offset %ld crosses UTF-8 character in the middle", (long)to);
          return box_dv_uname_nchars (str, to);
        }
      res = dk_alloc_box ((to + 1) * sizeof_char, (dtp_t)(IS_WIDE_STRING_DTP (dtp1) ? DV_WIDE : DV_LONG_STRING));
      memcpy (res, str, to * sizeof_char);
      memset (res + to * sizeof_char, 0, sizeof_char);
    }
  else
    {
      res = dk_alloc_box (to * sizeof_char, (dtp_t) DV_BIN);
      memcpy (res, str, to * sizeof_char);
    }
  return res;
}


/* right(str,n) takes n last characters of str. */
caddr_t
bif_right (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t str = bif_string_or_uname_or_wide_or_null_arg (qst, args, 0, "right");
  long n_last = (long) bif_long_range_arg (qst, args, 1, "right", 0, 10000000);  /* substr length */
  caddr_t res;
  long len;
  dtp_t dtp1 = DV_TYPE_OF (str);
  int sizeof_char = IS_WIDE_STRING_DTP (dtp1) ? sizeof (wchar_t) : sizeof (char);
  if (NULL == str)
    {
      return (NEW_DB_NULL);
    }
  len = (box_length (str) / sizeof_char - 1); /* box_length returns a length + 1 */
  n_last = MIN (n_last, len);
  if (DV_UNAME == dtp1)
    {
      if (0x80 == (str[(len - n_last)] & 0xC0))
        sqlr_new_error ("22011", "SR591",
          "Function RIGHT: starting offset %ld crosses UTF-8 character in the middle", (long)(len - n_last));
      return box_dv_uname_nchars (str + (len - n_last), n_last);
    }
  res = dk_alloc_box ((n_last + 1) * sizeof_char, (dtp_t)(IS_WIDE_STRING_DTP (dtp1) ? DV_WIDE : DV_LONG_STRING));
  memcpy (res, (str + (len - n_last) * sizeof_char), n_last * sizeof_char);
  memset (res + n_last * sizeof_char, 0, sizeof_char);
  return res;
}


/* repeat(str,n) duplicates string str n times.
   If n is 0 then an empty string is returned.  */
caddr_t
bif_repeat (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *)qst;
  caddr_t str = bif_string_or_wide_or_null_arg (qst, args, 0, "repeat");
  long n_times = (long) bif_long_arg (qst, args, 1, "repeat");
  long len;
  caddr_t res;
  long totlen;
  long int i, offset;
  dtp_t dtp1 = DV_TYPE_OF (str);
  int sizeof_char = IS_WIDE_STRING_DTP (dtp1) ? sizeof (wchar_t) : sizeof (char);
  if (n_times < 0)
    sqlr_new_error ("22023", "SR082", "Negative parameter 2 (count) in call of repeat()");
  if (NULL == str)
  {
    return (NEW_DB_NULL);
  }

  len = (box_length (str) / sizeof_char - 1);
  totlen = (len * n_times);
  if ((totlen < 0) || (totlen > 10000000))
    sqlr_new_error ("22023", "SR083", "The expected result length is too large in call of repeat()");
  if (NULL == (res = dk_try_alloc_box ((totlen + 1) * sizeof_char , (dtp_t)(IS_WIDE_STRING_DTP (dtp1) ? DV_WIDE : DV_LONG_STRING))))
    qi_signal_if_trx_error (qi);

  for (i = 0, offset = 0; i < n_times; i++, offset += len)
  {
    memcpy (res + offset * sizeof_char, str, len * sizeof_char);
  }

  memset (res + totlen * sizeof_char, 0, sizeof_char);
  return res;
}


/* space(n) is same as repeat(' ',n)
   If n is 0 then an empty string is returned.  */
caddr_t
bif_space (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  ptrlong n_times = bif_long_range_arg (qst, args, 0, "space", 0, 10000000);
  caddr_t res;
  ptrlong totlen = n_times + 1;

/*
   if(totlen > JOKU_RAJA) anna joku virhe ilmoitus tai tee jotakin...
 */

  if (n_times < 0)
    sqlr_new_error ("22023", "SR083", "Negative parameter 2 (count) in call of space()");
  if ((totlen < 0) || (totlen > 10000000))
    sqlr_new_error ("22023", "SR084", "The expected result length is too large in call of space()");
  if (NULL == (res = dk_try_alloc_box (totlen, DV_LONG_STRING)))
    qi_signal_if_trx_error ((query_instance_t *)qst);

  if (n_times)
  {
    memset (res, ' ', n_times);
  }       /* Fill with blanks. */
  res[n_times] = 0;
  return res;
}

#define char_strchr strchr
#define wchar_t_strchr  virt_wcschr

/* These two functions are for the needs of ltrim, rtrim and trim */
#define skip_any_of_these_func(type) \
type * \
type##_skip_any_of_these (type *str, type *skip_str, int len) \
{ \
  type *s = (( type *) str);  \
\
  if (!*skip_str) \
  { \
    return ((type *) s); \
  }       /* Don't skip anything if an empty skip_str */ \
  if (!*(skip_str + 1))   /* Just one char to be trimmed, e.g. blank */ \
  {       /* No need to call strchr function. */ \
    while ((s < (str + len)) && (*s == *skip_str)) \
  { \
    s++; \
  } \
  } \
  else \
  { \
    /* Argument of strchr shouldn't be sign-extended ??!!! */ \
    /* Well, with MSDEV C, both -2 and 254 find the character 254. */ \
    while ((s < (str + len)) && type##_strchr (skip_str, *s)) \
  { \
    s++; \
  } \
  } \
\
  return ((type *) s); \
}

skip_any_of_these_func (char)
skip_any_of_these_func (wchar_t)
/* Like previous, but from the right. Returns pointer to the first
   character of the last set of characters of str belonging to skip_str,
   or to the last character of str. I.e. it's the point which can
   be cut with a terminating zero, or is already cut (i.e. the terminating
   zero byte of the string in case there were nothing to trim.) */
#define skip_from_right_any_of_these(type) \
type * \
type##_skip_from_right_any_of_these (type *str, type *skip_str, int len) \
{ \
  type *s; \
  s = ((( type *) str) + len - 1);  /* Pointer to the last char. */ \
\
  if (!*skip_str || (0 == len)) \
  { \
    return (((type *) s) + 1); \
  }     /* Don't skip anything if an empty str or skip_str */ \
\
  if (!*(skip_str + 1))   /* Just one char to be trimmed, e.g. blank. */ \
  {       /* No need to call strchr function. */ \
    while ((s >= str) && (*s == *skip_str)) \
  { \
    s--; \
  } \
  } \
  else \
  { \
    while ((s >= str) && type##_strchr (skip_str, *s)) \
  { \
    s--; \
  } \
  } \
\
  return ((type *) s + 1);  /* The loop decremented one too far left. */ \
}


skip_from_right_any_of_these (char)
skip_from_right_any_of_these (wchar_t)
/* ltrim(str) trims all spaces off from the left of str.
   ltrim(str,skip_str) trims all the characters of skip_str off from the
   left of str.
   E.g. ltrim('   Huikka') -> 'Huikka'
   ltrim(':::Huikka',':') -> 'Huikka'
   ltrim(', /;  Huikka',',/; ') -> 'Huikka' */
caddr_t
bif_ltrim (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int n_args = BOX_ELEMENTS (args);
  caddr_t str = bif_string_or_wide_or_null_arg (qst, args, 0, "ltrim");
  caddr_t skip_str = ((n_args > 1)
    ? bif_string_arg (qst, args, 1, "ltrim")
    : (caddr_t) " ");  /* If second arg is not present it's a space by default. */
  long len;
  long from;
  caddr_t res;
  dtp_t dtp1 = DV_TYPE_OF (str);
  int sizeof_char = IS_WIDE_STRING_DTP (dtp1) ? sizeof (wchar_t) : sizeof (char);

  if (NULL == str)
  {
    return (NEW_DB_NULL);
  }
  len = (box_length (str) - 1); /* box_length returns a length + 1 */

  /* At max skip_any_of_these returns pointer to the end of str, in which
   case from will be equal to len. (Everything is trimmed.) */
  if (IS_WIDE_STRING_DTP (dtp1))
    from = (long) (wchar_t_skip_any_of_these ((wchar_t *)str, (wchar_t *)skip_str, len) - ((wchar_t *)str));
  else
    from = (long) (char_skip_any_of_these (str, skip_str, len) - str);

  res = dk_alloc_box (((len - from) + 1) * sizeof_char, (dtp_t)(IS_WIDE_STRING_DTP (dtp1) ? DV_WIDE : DV_LONG_STRING));
  if (len - from)
  {
    memcpy (res, str + from * sizeof_char, (len - from) * sizeof_char);
  }
  memset (res + (len - from) * sizeof_char, 0, sizeof_char);
  return res;
}


/* rtrim(str) trims all spaces off from the right of str.
   rtrim(str,skip_str) trims all the characters of skip_str off from the
   right hand side, i.e. end of str.
   E.g. rtrim('Huikka ') -> 'Huikka'
   rtrim(':::Huikka:::',':') -> ':::Huikka'
   rtrim('Huikka 123','1234567890') -> 'Huikka ' */
caddr_t
bif_rtrim (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int n_args = BOX_ELEMENTS (args);
  caddr_t str = bif_string_or_wide_or_null_arg (qst, args, 0, "rtrim");
  caddr_t skip_str = ((n_args > 1)
    ? bif_string_arg (qst, args, 1, "rtrim")
    : (caddr_t) " "); /* If second arg is not present it's a space by default. */
  long len;
  long to;
  caddr_t res;
  dtp_t dtp1 = DV_TYPE_OF (str);
  int sizeof_char = IS_WIDE_STRING_DTP (dtp1) ? sizeof (wchar_t) : sizeof (char);

  if (NULL == str)
  {
    return (NEW_DB_NULL);
  }
  len = (box_length (str) / sizeof_char - 1); /* box_length returns a length + 1 */

  /* At max to_the_last_not_any_of_these returns pointer to the
   terminating zero of str, in which case variable 'to' will be
   equal to len. (I.e nothing is trimmed.)
   At min, it can return str, so to=0, i.e. everything is to be trimmed.  */
  if (IS_WIDE_STRING_DTP (dtp1))
    to = (long) (wchar_t_skip_from_right_any_of_these ((wchar_t *)str, (wchar_t *)skip_str, len) - ((wchar_t *)str));
  else
    to = (long) (char_skip_from_right_any_of_these (str, skip_str, len) - str);

  /* Note the similarity with bif_left */
  res = dk_alloc_box ((to + 1) * sizeof_char, (dtp_t)(IS_WIDE_STRING_DTP (dtp1) ? DV_WIDE : DV_LONG_STRING));
  memcpy (res, str, to * sizeof_char);
  memset (res + to * sizeof_char, 0, sizeof_char);
  return res;
}


/* trim(str) trims all spaces off from the left and right side of str.
   trim(str,skip_str) trims all the characters of skip_str off from the
   left and right hand side of str.
   E.g. trim('   Huikka  ') -> 'Huikka'
   trim(':::Huikka:::',':') -> 'Huikka'
   trim(', /;  Huikka // ',',/; ') -> 'Huikka' */
caddr_t
bif_trim (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int n_args = BOX_ELEMENTS (args);
  caddr_t str = bif_string_or_wide_or_null_arg (qst, args, 0, "trim");
  caddr_t skip_str_orig = NULL;
  caddr_t skip_str = NULL;
  long len;
  long from;
  long to;
  char *from_ptr;
  caddr_t res;
  dtp_t dtp1 = DV_TYPE_OF (str);
  int sizeof_char = IS_WIDE_STRING_DTP (dtp1) ? sizeof (wchar_t) : sizeof (char);
  caddr_t to_free = NULL;

  if (NULL == str)
    return (NEW_DB_NULL);

  if (n_args > 1)
    skip_str_orig = bif_string_or_wide_or_null_arg (qst, args, 1, "trim");
  if (NULL == skip_str_orig)
    skip_str = ((IS_WIDE_STRING_DTP (dtp1)) ? (caddr_t)L" " : " ");
  else if (IS_WIDE_STRING_DTP (dtp1) && !DV_WIDESTRINGP (skip_str_orig))
    {
      to_free = (caddr_t) box_narrow_string_as_wide ((unsigned char *) skip_str_orig, NULL, 0, QST_CHARSET (qst), err_ret, 1);
      if (!to_free)
        return NULL;
      skip_str = to_free;
    }
  else if (!IS_WIDE_STRING_DTP (dtp1) && DV_WIDESTRINGP (skip_str_orig))
    {
      to_free = box_wide_string_as_narrow (skip_str_orig, NULL, 0, QST_CHARSET (qst));
      skip_str = to_free;
    }
  else
    skip_str = skip_str_orig;

  len = (box_length (str) / sizeof_char - 1); /* box_length returns a length + 1 */

  /* At max skip_any_of_these returns pointer to the end of str, in which
     case from will be equal to len. (Everything is trimmed.) */
  if (IS_WIDE_STRING_DTP (dtp1))
    {
      from = (long) ((wchar_t *)(from_ptr = (char *)wchar_t_skip_any_of_these ((wchar_t *)str, (wchar_t *)skip_str, len)) - ((wchar_t *)str));
      if ((len - from) > 1)
	{
	  /* There are at least two characters left at the right side. */
	  to = (long) (wchar_t_skip_from_right_any_of_these ((wchar_t *)from_ptr, (wchar_t *)skip_str, (len - from))
	      - ((wchar_t *)str));
	}
      else
	{
	  to = len;
	}
    }
  else
    {
      from = (long) ((from_ptr = char_skip_any_of_these (str, skip_str, len)) - str);
      if ((len - from) > 1)
	{
	  /* There are at least two characters left at the right side. */
	  to = (long) (char_skip_from_right_any_of_these (from_ptr, skip_str, (len - from))
	      - str);
	}
      else
	{
	  to = len;
	}
    }

  dk_free_box (to_free);

  /* Note the similarity with subseq */
  res = dk_alloc_box (((to - from) + 1) * sizeof_char, (dtp_t)(IS_WIDE_STRING_DTP (dtp1) ? DV_WIDE : DV_LONG_STRING));
  memcpy (res, str + from * sizeof_char, (to - from) * sizeof_char);
  memset (res + (to - from) * sizeof_char, 0, sizeof_char);
  return res;
}


/* Modified by AK 29-OCT-1997 to skip all NULL arguments (i.e.
   the result being exactly like they were empty strings "") */
caddr_t
bif_concatenate (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;
  int n_args = BOX_ELEMENTS (args), inx;
  /*caddr_t *orig_args = dk_alloc_list_zero (n_args); */
  caddr_t *cast_args = NULL;
  int alen;
  caddr_t a;
  int len = 0, fill = 0;
  caddr_t res;
  int haveWides = 0, haveWeirds = 0;
  dtp_t dtp1;
  int sizeof_char = 1;
  /* First count the required length for a resulting string buffer. */
  for (inx = 0; inx < n_args; inx++)
    {
      a = bif_arg_nochecks (qst, args, inx);
      dtp1 = DV_TYPE_OF (a);
      switch (dtp1)
	{
	case DV_DB_NULL:
	  continue;		/* Nulls are totally ignored */
	case DV_STRING:
	case DV_UNAME:
	  len += box_length (a) - 1;
	  break;
	case DV_WIDE:
	case DV_LONG_WIDE:
	  haveWides = 1;
	  len += box_length (a) / sizeof (wchar_t) - 1;
	  break;
	default:
	  if (NULL == cast_args)
	    cast_args = dk_alloc_list_zero (n_args);
	  haveWeirds = 1;
	  break;
	}
    }
  if (haveWeirds)
    {
      for (inx = 0; inx < n_args; inx++)
	{
	  a = bif_arg_nochecks (qst, args, inx);
	  dtp1 = DV_TYPE_OF (a);
	  switch (dtp1)
	    {
	    case DV_DB_NULL:
	      continue;		/* Nulls are totally ignored */
	    case DV_STRING:
	    case DV_UNAME:
	    case DV_WIDE:
	    case DV_LONG_WIDE:
	      break;
	    case DV_LONG_INT:
	      if (!haveWides)
		{
		  char buf[50];
		  if (NULL == cast_args)
		    cast_args = dk_alloc_list_zero (n_args);
		  sprintf (buf, BOXINT_FMT, unbox (a));
		  cast_args[inx] = box_dv_short_string (buf);
		  len += box_length (cast_args[inx]) - 1;
		  break;
		}
	      /* no break */
	    default:
	      {
		QR_RESET_CTX
		{
		  if (haveWides)
		    {
		      cast_args[inx] = box_cast (qst, a, st_nvarchar, dtp1);
		      len += box_length (cast_args[inx]) / sizeof (wchar_t) - 1;
		    }
		  else
		    {
		      cast_args[inx] = box_cast (qst, a, st_varchar, dtp1);
		      len += box_length (cast_args[inx]) - 1;
		    }
		}
		QR_RESET_CODE
		{
		  du_thread_t *self = THREAD_CURRENT_THREAD;
		  caddr_t err = thr_get_error_code (self);
		  thr_set_error_code (self, NULL);
		  POP_QR_RESET;
		  /*dk_free_box ((caddr_t)orig_args); */
		  dk_free_tree ((caddr_t) cast_args);
		  sqlr_resignal (err);
		}
		END_QR_RESET break;
	      }
	    }
	}
    }
  sizeof_char = haveWides ? sizeof (wchar_t) : sizeof (char);
  if (((len + 1) * sizeof_char) > 10000000)
    {
      /*dk_free_box ((caddr_t)orig_args); */
      dk_free_tree ((caddr_t) cast_args);
      sqlr_new_error ("22023", "SR578", "The expected result length of string concatenation is too large (%ld bytes)",
	  (long) ((len + 1) * sizeof_char));
    }
  if (NULL == (res = dk_try_alloc_box ((len + 1) * sizeof_char, (dtp_t) (haveWides ? DV_WIDE : DV_LONG_STRING))))
    {
      /*dk_free_box ((caddr_t)orig_args); */
      dk_free_tree ((caddr_t) cast_args);
    qi_signal_if_trx_error (qi);
    }
  for (inx = 0; inx < n_args; inx++)
    {
      a = bif_arg_nochecks (qst, args, inx);
      dtp1 = DV_TYPE_OF (a);
      switch (dtp1)
	{
	case DV_DB_NULL:
	  continue;		/* Nulls are totally ignored */
	case DV_STRING:
	case DV_UNAME:
	  if (haveWides)
	    {
	      alen = box_length (a) - 1;
	      box_narrow_string_as_wide ((unsigned char *) a, res + fill * sizeof_char, alen, QST_CHARSET (qst), err_ret, 1);
	      break;
	    }
	  /* no break */
	case DV_WIDE:
	case DV_LONG_WIDE:
	  /* no break */
	case DV_LONG_INT:
	  /* no break */
	default:
	  {
	    if ((NULL != cast_args) && (NULL != cast_args[inx]))
	      a = cast_args[inx];
	    alen = box_length (a) / sizeof_char - 1;
	    memcpy (res + fill * sizeof_char, a, alen * sizeof_char);
	    break;
	  }
	}
      fill += alen;
    }
  if (fill != len)
    GPF_T1 ("Memory corruption in bif_concat");
  memset (res + len * sizeof_char, 0, sizeof_char);
  /*dk_free_box ((caddr_t)orig_args); */
  if (NULL != cast_args)
    dk_free_tree ((caddr_t) cast_args);
  return res;
}


caddr_t
bif_vector_concatenate (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *)qst;
  int n_args = BOX_ELEMENTS (args), inx, inx1;
  int alen;
  caddr_t *a;
  int len = 0, fill = 0;
  caddr_t *res;

  /* First count the required length for a resulting vector. */
  for (inx = 0; inx < n_args; inx++)
  {
    a = (caddr_t *) bif_strict_array_or_null_arg (qst, args, inx, "vector_concat");
    if (NULL == a)
      continue;
    len += BOX_ELEMENTS (a);
  }

  if (DK_MEM_RESERVE)
    qi_signal_if_trx_error (qi);
  if ((len * sizeof (caddr_t)) & ~0xffffff)
    sqlr_new_error ("22023", "SR486", "The result vector is too large");
  res = (caddr_t *) dk_try_alloc_box (len * sizeof(caddr_t), DV_ARRAY_OF_POINTER);
  for (inx = 0; inx < n_args; inx++)
  {
    a = (caddr_t *) bif_array_or_null_arg (qst, args, inx, "vector_concat");
    if (NULL == a)
      continue;
    alen = BOX_ELEMENTS (a);
    for (inx1 = 0; inx1 < alen; inx1++)
      {
        res[fill + inx1] = box_try_copy_tree(((box_t *)a)[inx1], NULL);
        if (DK_MEM_RESERVE)
	  {
	    dk_free_tree ((box_t) res);
	    qi_signal_if_trx_error (qi);
	  }
      }
    fill += alen;
  }
#ifdef DEBUG
  if (fill != len)
    GPF_T;
#endif
  return (caddr_t) res;
}

#ifndef HAVE_MEMMEM
static void *
memmem (const void *_haystack, size_t haystack_bytes, const void *_needle, size_t needle_bytes)
{
  const char *haystack = (const char *) _haystack;
  const char *needle = (const char *) _needle;

  if (!needle_bytes)
    return (void *) haystack;	/* Empty needle */

  while (haystack_bytes >= needle_bytes)
    {
      if ((haystack[0] == needle[0]) && !memcmp (haystack, needle, needle_bytes))
	return (void *) haystack;
      haystack++;
      haystack_bytes--;
    }
  return NULL;
}
#endif

static void *
memmem1 (const void *_haystack, size_t haystack_bytes, const void *_needle, size_t needle_bytes)
{
  const char *haystack = (const char *) _haystack;
  const char *needle = (const char *) _needle;
  while (haystack_bytes)
    {
      if (haystack[0] == needle[0])
	return (void *) haystack;
      haystack++;
      haystack_bytes--;
    }
  return NULL;
}

static void *
widememmem (const void *_haystack, size_t haystack_bytes, const void *_needle, size_t needle_bytes)
{
  const wchar_t *haystack = (const wchar_t *) _haystack;
  const wchar_t *needle = (const wchar_t *) _needle;

  if (!needle_bytes)
    return (void *) haystack;	/* Empty needle */

  while (haystack_bytes >= needle_bytes)
    {
      if ((haystack[0] == needle[0]) && !memcmp (haystack, needle, needle_bytes))
	return (void *) haystack;
      haystack++;
      haystack_bytes -= sizeof (wchar_t);
    }
  return NULL;
}

typedef void * (* memmem_fun_t) (const void *needle, size_t needle_len, const void *haystack, size_t haystack_len);


/* replace(string_exp1, from_exp, to_exp [, max_n_replacements])

   Replace every from_exp from string_exp1 with to_exp.
   If the optional fourth argument is present, then replace
   at maximum that many occurrences.  */
caddr_t
bif_replace (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char *me = "replace";
  int n_args = BOX_ELEMENTS (args);
  caddr_t src_str = bif_string_or_wide_or_null_arg (qst, args, 0, me);
  caddr_t from_str = bif_string_or_wide_or_null_arg (qst, args, 1, me);
  caddr_t to_str = bif_string_or_wide_or_null_arg (qst, args, 2, me);
  int only_n_flag = (n_args > 3);
  int only_n, src_bytes, from_bytes, to_bytes, difference, occurrences;
  int res_bytes, non_changed_bytes, n_changes;
  char *src_tail, *src_end, *res_ptr;
  memmem_fun_t searcher;
  caddr_t res;
  dtp_t dtp_src = DV_TYPE_OF (src_str);
  dtp_t dtp_from = DV_TYPE_OF (from_str);
  dtp_t dtp_to = DV_TYPE_OF (to_str);

  int sizeof_char =
    ((IS_WIDE_STRING_DTP (dtp_src) ||
      IS_WIDE_STRING_DTP (dtp_from) ||
      IS_WIDE_STRING_DTP (dtp_to) ) ?
     sizeof (wchar_t) : sizeof (char) );

  if ((NULL == src_str) || (NULL == from_str) || (NULL == to_str))
    return (NEW_DB_NULL);

  if (sizeof (wchar_t) == sizeof_char)
    {
      if (!IS_WIDE_STRING_DTP (dtp_src))
  sqlr_new_error ("22023", "SR027", "Source string arg (#1) to %s was not a wide string", me);
      if (!IS_WIDE_STRING_DTP (dtp_from))
  sqlr_new_error ("22023", "SR028", "From arg (#2) to %s was not a wide string", me);
      if (!IS_WIDE_STRING_DTP (dtp_to))
  sqlr_new_error ("22023", "SR029", "To arg (#3) to %s was not a wide string", me);
    }

  src_bytes = box_length (src_str) - sizeof_char;
  src_end = src_str + src_bytes;
  from_bytes = box_length (from_str) - sizeof_char;
  searcher = (
    (sizeof(wchar_t) == sizeof_char) ?
      widememmem :
      ((1 == from_bytes) ? memmem1 : memmem)
    );
  to_bytes = box_length (to_str) - sizeof_char;
  only_n = (only_n_flag ? (int) bif_long_range_arg (qst, args, 3, me, 0, 10000000) : src_bytes);
  difference = (to_bytes - from_bytes); /* How many bytes longer? */

  /* Don't know actually what we should do when from is an empty string.
   Now just return the string_exp1 back as it is. */
  if (0 == from_bytes)
    return (box_copy (src_str));
 /* if(only_n_flag && (0 == only_n)) { return(box_copy(src_str)); } */

  if (0 != difference)   /* The resulting string would be longer or shorter. */
    {
    /* So we have to count the number of occurrences of from_str in src_src */
      src_tail = src_str;
      occurrences = 0;
      while (occurrences < only_n)
  {
    src_tail = (char *) searcher (src_tail, src_end-src_tail, from_str, from_bytes);
    if (NULL == src_tail)
      break;
    occurrences++;
    src_tail += from_bytes;
  }
      difference *= occurrences; /* Now the difference in final length. */
      if (0 == occurrences) /* Nothing to replace. */
        return (box_copy (src_str));
    }
  else
    occurrences = only_n;

/* If from_str and to_str are identical strings? Not really necessary.
   if(((0 == difference) && (0 == strcmp(from_str,to_str))))
   {
   return(box_copy(src_str));
   }
 */

  res_bytes = (src_bytes + difference); /* Difference can be -, 0, + */

/*
  printf ("%s: Allocating res of len %d for src_len %d, with from_len %d,"
    " to_len %d, occurrences %d, difference %d, only_n=%d,%d\n",
    me, res_len, src_len, from_len, to_len, occurrences, difference,
    only_n_flag, only_n);
  fflush (stdout);
 */

  /* +1 for the final zero. */
  res = dk_alloc_box (res_bytes + sizeof_char,
    (dtp_t)(sizeof_char == sizeof (wchar_t) ? DV_WIDE : DV_LONG_STRING));
  res_ptr = res;
  src_tail = src_str;
  n_changes = 0;
  while (n_changes < occurrences)
    {
      char *next = (char *) searcher (src_tail, src_end-src_tail, from_str, from_bytes);
      if (NULL == next)
  break;
      non_changed_bytes = (int) (next - src_tail);
      if (0 != non_changed_bytes) /* Something stays same? */
  {
    memcpy (res_ptr, src_tail, non_changed_bytes);
    res_ptr += non_changed_bytes;
  }
      if (0 != to_bytes)  /* When to_len is zero, we actually delete items. */
  {
    memcpy (res_ptr, to_str, to_bytes);
    res_ptr += to_bytes;
  }
      src_tail = next + from_bytes;
      n_changes++;
    }
  /* Copy the last remaining piece if necessary. */
  non_changed_bytes = (int) (src_end - src_tail);
  /* (src_str+src_len)-prevptr */
  if (0 != non_changed_bytes)
    {
      memcpy (res_ptr, src_tail, non_changed_bytes);
      res_ptr += non_changed_bytes;
    }
#ifdef DEBUG
  if (res_ptr != (res + box_length(res) - sizeof_char))
    GPF_T;
#endif
  memset (res_ptr, 0, sizeof_char);
  return res;
}


#define SP_ARG(n) \
  ((n < n_args) ? (char*)unbox (bif_arg (qst, args, n, "sprintf")) : NULL)

#define SPRINTF_BUF_SPACE  2000
#define SPRINTF_BUF_MARGIN 1000


void
sprintf_escaped_id (caddr_t str, char *out, dk_session_t * ses)
{
  int len = box_length (str) - 1;
  char *sp, *dp;

  for (sp = str, dp = out; *sp && sp - str < len && (ses || dp - out < SPRINTF_BUF_SPACE - 1);)
    {
      if (*sp == '\"' && sp > str && sp - str < len - 1 && *(sp + 1) != '\"' && *(sp - 1) != '\"')
	{
	  if (out)
	    *dp++ = '\"';
	  else if (ses)
	    session_buffered_write_char ('\"', ses);
	}
      if (out)
	*dp++ = *sp++;
      else if (ses)
	session_buffered_write_char (*sp++, ses);
    }
  if (out)
    *dp = 0;
}


void
sprintf_escaped_str_literal (caddr_t str, char *out, dk_session_t * ses)
{
  int len = (int) strlen (str);
  char *sp, *dp;

  for (sp = str, dp = out; *sp && sp - str < len && (ses || dp - out < SPRINTF_BUF_SPACE - 1);)
    {
      if (*sp == '\'' && sp > str && sp - str < len - 1 && *(sp + 1) != '\'' && *(sp - 1) != '\'')
	{
	  if (out)
	    *dp++ = '\'';
	  else if (ses)
	    session_buffered_write_char ('\'', ses);
	}
      if (out)
	*dp++ = *sp++;
      else if (ses)
	session_buffered_write_char (*sp++, ses);
    }
  if (out)
    *dp = 0;
}


void
sprintf_escaped_table_name (char *out, char *name)
{
  char q[MAX_NAME_LEN];
  char o[MAX_NAME_LEN];
  char n[MAX_NAME_LEN];
  char *ptr = out;

  q[0] = o[0] = n[0] = 0;
  sch_split_name (NULL, name, q, o, n);

  if (q[0])
    {
      *ptr++ = '"';
      sprintf_escaped_str_literal (q, ptr, NULL);
      ptr += strlen (ptr);
      *ptr++ = '"';
      *ptr++ = '.';
    }

  if (o[0])
    {
      *ptr++ = '"';
      sprintf_escaped_str_literal (o, ptr, NULL);
      ptr += strlen (ptr);
      *ptr++ = '"';
    }

  if (q[0] || o[0])
    *ptr++ = '.';

  *ptr++ = '"';
  sprintf_escaped_str_literal (n, ptr, NULL);
  ptr += strlen (ptr);
  *ptr++ = '"';
  *ptr++ = 0;
}


caddr_t
box_sprintf_escaped (caddr_t str, int is_id)
{
  char dest[SPRINTF_BUF_SPACE + SPRINTF_BUF_MARGIN + 1];
  dest[SPRINTF_BUF_SPACE] = '\0';

  if (is_id)
    sprintf_escaped_id (str, dest, NULL);
  else
    sprintf_escaped_str_literal (str, dest, NULL);

  if (dest[SPRINTF_BUF_SPACE])
    {
      GPF_T1 ("SQL sprintf buffer overflowed. sprintf of over 2000 characters caused this.");
    }

  return box_dv_short_string (dest);
}


caddr_t
bif_sprintf (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  static char *szMe = "sprintf";
  dk_session_t *ses = strses_allocate ();
  char tmp[SPRINTF_BUF_SPACE + SPRINTF_BUF_MARGIN + 1];
  char format[100];
  char *volatile ptr;
  char *volatile start;
  char *volatile modifier;
  char buf[100];
  char *bufptr;
  caddr_t str = bif_string_arg (qst, args, 0, szMe);
  int volatile len = box_length (str) - 1;
  int volatile arg_inx = 1;
  int arg_len = 0, arg_prec = 0;

  ptr = str;
  *err_ret = NULL;

  QR_RESET_CTX
  {
  next_fragment:
    start = strchr (ptr, '%');

    if (!start)
      {				/* write the reminder */
	session_buffered_write (ses, ptr, len);
	ptr += len;
	len = 0;
	goto format_string_completed;	/* see below */
      }

    if (start - ptr)
      {				/* write the constant part before the % if any */
	session_buffered_write (ses, ptr, start - ptr);
	len -= (int) (start - ptr);
      }

    ptr = start + 1;

    switch (ptr[0])
      {
      case '\0':
	goto format_char_found;	/* see below */

      case '%':
	session_buffered_write_char ('%', ses);
	goto get_next_no_arg_inx_increment;	/* see below */

      case '{':
	{
	  caddr_t connvar_name, connvar_value, *connvar_valplace;
	  dtp_t connvar_dtp;
	  query_instance_t *qi = (query_instance_t *) qst;
	  client_connection_t *cli = qi->qi_client;

	  ptr++;

	  while (isalnum ((unsigned char) (ptr[0])) || ('_' == ptr[0]))
	    ptr++;

	  if ('}' != ptr[0])
	    sqlr_new_error ("22026", "SR585",
		"sprintf format %%{ should have '}' immediately after the name of connection variable");

	  ptr++;

	  if (!*ptr || !strchr ("sU" /*"diouxXeEfgcsSIVU" */ , *ptr))
	    sqlr_new_error ("22023", "SR586", "Invalid format string for sprintf at escape %d", arg_inx);

	  memset (format, 0, sizeof (format));
	  memcpy (format, start + 2, MIN ((ptr - start) - 3, sizeof (format) - 1));

	  connvar_name = box_dv_short_string (format);
	  connvar_valplace = (caddr_t *) id_hash_get (cli->cli_globals, (caddr_t) & connvar_name);
	  dk_free_box (connvar_name);

	  if (NULL != connvar_valplace)
	    connvar_value = connvar_valplace[0];
	  else
	    {
	      connvar_value = uriqa_get_default_for_connvar (qi, format);
	      if (NULL == connvar_value)
		sqlr_new_error ("22023", "SR587",
		    "Connection variable is mentioned by sprintf format %%{%s} but it does not exist", format);
	    }

	  connvar_dtp = DV_TYPE_OF (connvar_value);

	  switch (*ptr)
	    {
	    case 'U':
	    case 's':
	      if (DV_STRING != connvar_dtp)
		{
		  if (NULL == connvar_valplace)
		    dk_free_box (connvar_value);
		  sqlr_new_error ("22023", "SR588",
		      "Connection variable is mentioned by sprintf format %%{%s}%c but its value is not a string", format, ptr[0]);
		}

	      switch (*ptr)
		{
		case 'U':
		  http_value_esc (qst, ses, connvar_value, NULL, DKS_ESC_URI);
		  break;

		case 's':
		  session_buffered_write (ses, connvar_value, box_length (connvar_value) - 1);
		  break;
		}

	      if (NULL == connvar_valplace)
		dk_free_box (connvar_value);
	      break;

	    default:
	      if (NULL == connvar_valplace)
		dk_free_box (connvar_value);

	      sqlr_new_error ("22023", "SR595",
		  "Current implementation of sprintf() supports only %%U sprintf() format for connection variables, %%{%.200s}%c is not supported",
		  format, ptr[0]);
	    }
	  goto get_next_no_arg_inx_increment;	/* see below */
	}
      }

    /* Now we know that we process a real format specifier */
    if (arg_inx >= BOX_ELEMENTS_INT (args))
      sqlr_new_error ("22026", "SR352",
	  "Not enough arguments (only %lu) for sprintf to match format '%s'", (unsigned long) BOX_ELEMENTS (args), str);

    arg_len = arg_prec = 0;

    /* skip the modifier */
    modifier = NULL;
    while (ptr && *ptr && strchr ("#0- +'_", *ptr))
      {
	modifier = ptr;
        ptr++;
      }

    bufptr = buf;

    /* skip the width */
    while (ptr && *ptr && strchr ("0123456789", *ptr))
      {
	if (bufptr - buf < sizeof (buf))
	  *bufptr++ = *ptr;
	ptr++;
      }

    *bufptr = 0;
    arg_len = atoi (buf);

    /* skip the precision */
    if (ptr && *ptr == '.')
      {
	bufptr = buf;
	ptr++;			/* skip the dot */

	while (*ptr && strchr ("0123456789", *ptr))
	  {
	    if (bufptr - buf < sizeof (buf))
	      *bufptr++ = *ptr;
	    ptr++;
	  }

	*bufptr = 0;
	arg_prec = atoi (buf);
      }

    /* skip the size modifier */
    if (*ptr && strchr ("hlLq", *ptr))
      ptr++;

  format_char_found:
    if (!ptr || !*ptr || !strchr ("dDiouxXeEfgcsRSIVU", *ptr) || ('R' != *ptr && modifier && '_' == modifier[0]))
      {
	sqlr_new_error ("22023", "SR031", "Invalid format string for sprintf at escape %d", arg_inx);
      }

    memset (format, 0, sizeof (format));
    memcpy (format, start, MIN (ptr - start + 1, sizeof (format) - 1));

    if (arg_len > SPRINTF_BUF_SPACE)
      {
	sqlr_new_error ("22026", "SR032",
	    "sprintf escape %d (%s) exceeds the internal buffer of %d", arg_inx, format, SPRINTF_BUF_SPACE);
      }

    tmp[SPRINTF_BUF_SPACE] = '\0';

    switch (*ptr)
      {
      case 'd':
      case 'i':
      case 'o':
      case 'u':
      case 'x':
      case 'X':
	if (ptr[-1] == 'h')
	  snprintf (tmp, SPRINTF_BUF_SPACE, format, (short) bif_long_arg (qst, args, arg_inx, szMe));
	else if (ptr[-1] == 'l')
#if SIZEOF_LONG == 4
	  snprintf (tmp, SPRINTF_BUF_SPACE, format, (int32) bif_long_arg (qst, args, arg_inx, szMe));
#else
	  snprintf (tmp, SPRINTF_BUF_SPACE, format, bif_long_arg (qst, args, arg_inx, szMe));
#endif
	else
	  snprintf (tmp, SPRINTF_BUF_SPACE, format, (int) bif_long_arg (qst, args, arg_inx, szMe));
	break;

      case 'e':
      case 'E':
      case 'f':
      case 'g':
	{
	  caddr_t arg = bif_arg (qst, args, arg_inx, szMe);
	  if ((DV_NUMERIC == DV_TYPE_OF (arg)) && !arg_len && !arg_prec)
	    {
	      caddr_t strg = box_cast_to (qst, arg, DV_NUMERIC, DV_SHORT_STRING, NUMERIC_MAX_PRECISION, NUMERIC_MAX_SCALE, err_ret);
	      session_buffered_write (ses, strg, box_length (strg) - 1);
	      dk_free_box (strg);
	      goto get_next;
	    }

	  if (ptr[-1] == 'L' || ptr[-1] == 'q')
	    snprintf (tmp, SPRINTF_BUF_SPACE, format, (long double) bif_double_arg (qst, args, arg_inx, szMe));
	  else
	    snprintf (tmp, SPRINTF_BUF_SPACE, format, bif_double_arg (qst, args, arg_inx, szMe));
	}
	break;

      case 'c':
	snprintf (tmp, SPRINTF_BUF_SPACE, format, (int) bif_long_arg (qst, args, arg_inx, szMe));
	break;

      case 's':
	{
	  caddr_t arg = bif_string_or_uname_or_wide_or_null_arg (qst, args, arg_inx, szMe);
	  caddr_t narrow_arg = NULL;

	  if (DV_WIDESTRINGP (arg))
	    arg = narrow_arg = box_wide_string_as_narrow (arg, NULL, 0, NULL);
	  else if (!arg)
	    arg = narrow_arg = box_dv_short_string ("(NULL)");

	  if (arg_len || arg_prec)
	    {
	      if (box_length (arg) - 1 > SPRINTF_BUF_SPACE)
		{
		  if (narrow_arg)
		    dk_free_box (narrow_arg);
		  sqlr_new_error ("22026", "SR033",
		      "The length of the data for sprintf argument %d exceed the maximum of %d", arg_inx, SPRINTF_BUF_SPACE);
		}

	      snprintf (tmp, SPRINTF_BUF_SPACE, format, arg);

	      if (narrow_arg)
		dk_free_box (narrow_arg);
	    }
	  else
	    {
	      session_buffered_write (ses, arg, box_length (arg) - 1);

	      if (narrow_arg)
		dk_free_box (narrow_arg);

	      goto get_next;
	    }
	}
	break;

      case 'R': /* replace spaces with modifier character */
	{
	  caddr_t arg = bif_string_or_uname_or_wide_or_null_arg (qst, args, arg_inx, szMe);
	  caddr_t narrow_arg = NULL;

	  if (DV_WIDESTRINGP (arg))
	    arg = narrow_arg = box_wide_string_as_narrow (arg, NULL, 0, NULL);
	  else if (!arg)
	    arg = narrow_arg = box_dv_short_string ("(NULL)");

	  if (modifier)
	    {
	      size_t pos = strspn (arg, " ");
	      if (pos)
		{
		  memset (tmp, modifier[0], pos);
		  tmp[pos] = '\0';
		  session_buffered_write (ses, tmp, strlen (tmp));
		}
	      if (pos < (box_length (arg) - 1))
		session_buffered_write (ses, arg + pos, box_length (arg) - pos - 1);
	    }
	  else
	    {
	      session_buffered_write (ses, arg, box_length (arg) - 1);
	    }
	  if (narrow_arg)
	    dk_free_box (narrow_arg);
	  goto get_next;
	}
	break;


      case 'S':
	{
	  caddr_t arg = bif_string_or_uname_or_wide_or_null_arg (qst, args, arg_inx, szMe);
	  caddr_t narrow_arg = NULL;

	  if (DV_WIDESTRINGP (arg))
	    arg = narrow_arg = box_wide_string_as_narrow (arg, NULL, 0, NULL);
	  else if (!arg)
	    arg = narrow_arg = box_dv_short_string ("(NULL)");

	  if (arg_len || arg_prec)
	    {
	      if (box_length (arg) - 1 > SPRINTF_BUF_SPACE)
		{
		  if (narrow_arg)
		    dk_free_box (narrow_arg);
		  sqlr_new_error ("22026", "SR034",
		      "The length of the data for sprintf argument %d exceed the maximum of %d", arg_inx, SPRINTF_BUF_SPACE);
		}

	      sprintf_escaped_str_literal (arg, tmp, NULL);

	      if (narrow_arg)
		dk_free_box (narrow_arg);
	    }
	  else
	    {
	      sprintf_escaped_str_literal (arg, NULL, ses);

	      if (narrow_arg)
		dk_free_box (narrow_arg);

	      goto get_next;
	    }
	}
	break;

      case 'I':
	{
	  caddr_t arg = bif_string_or_uname_or_wide_or_null_arg (qst, args, arg_inx, szMe);
	  caddr_t narrow_arg = NULL;

	  if (DV_WIDESTRINGP (arg))
	    arg = narrow_arg = box_wide_string_as_narrow (arg, NULL, 0, NULL);
	  else if (!arg)
	    arg = narrow_arg = box_dv_short_string ("(NULL)");

	  if (arg_len || arg_prec)
	    {
	      if (box_length (arg) - 1 > SPRINTF_BUF_SPACE)
		{
		  if (narrow_arg)
		    dk_free_box (narrow_arg);
		  sqlr_new_error ("22026", "SR035",
		      "The length of the data for sprintf argument %d exceed the maximum of %d", arg_inx, SPRINTF_BUF_SPACE);
		}

	      sprintf_escaped_id (arg, tmp, NULL);

	      if (narrow_arg)
		dk_free_box (narrow_arg);
	    }
	  else
	    {
	      sprintf_escaped_id (arg, NULL, ses);

	      if (narrow_arg)
		dk_free_box (narrow_arg);

	      goto get_next;
	    }
	}
	break;

      case 'U':
	{
	  caddr_t arg, narrow_arg;

	  if (arg_len || arg_prec)
	    sqlr_new_error ("22025", "SR036", "The 'URL escaping' sprintf escape %d does not support modifiers", arg_inx);

	  arg = bif_arg (qst, args, arg_inx, szMe);

	  if (DV_NUMERIC == DV_TYPE_OF (arg))
	    {
	      narrow_arg = box_cast_to (qst, arg, DV_NUMERIC, DV_SHORT_STRING, NUMERIC_MAX_PRECISION, NUMERIC_MAX_SCALE, err_ret);
	      session_buffered_write (ses, narrow_arg, box_length (narrow_arg) - 1);
	      dk_free_box (narrow_arg);
	      goto get_next;
	    }

	  arg = bif_string_or_uname_or_wide_or_null_arg (qst, args, arg_inx, szMe);
	  narrow_arg = NULL;
/*
	  if (DV_WIDESTRINGP (arg))
	    arg = narrow_arg = box_wide_string_as_narrow (arg, NULL, 0, NULL);
	  else*/ if (!arg)
	    arg = narrow_arg = box_dv_short_string ("(NULL)");

	  http_value_esc (qst, ses, arg, NULL, DKS_ESC_URI);

	  if (narrow_arg)
	    dk_free_box (narrow_arg);

	  goto get_next;
	}
	break;

      case 'V':
	{
	  caddr_t arg = bif_string_or_uname_or_wide_or_null_arg (qst, args, arg_inx, szMe);
	  caddr_t narrow_arg = NULL;

	  if (!arg)
	    arg = narrow_arg = box_dv_short_string ("(NULL)");

	  if (arg_len || arg_prec)
	    {
	      if (narrow_arg)
		dk_free_box (narrow_arg);

	      sqlr_new_error ("22025", "SR037", "The HTTP escaping sprintf escape %d does not support modifiers", arg_inx);
	    }
	  else
	    {
	      http_value_esc (qst, ses, arg, NULL, DKS_ESC_PTEXT);

	      if (narrow_arg)
		dk_free_box (narrow_arg);

	      goto get_next;
	    }
	}
	break;

      case 'D':
	{
	  caddr_t arg = bif_date_arg (qst, args, arg_inx, szMe);
	  dt_print_to_buffer (tmp, arg, arg_len);
	}
	break;

      default:
	sqlr_new_error ("22023", "SR038", "Invalid format string for sprintf: '%.1000s'", str);
      }

    if (tmp[SPRINTF_BUF_SPACE])	/* Was: (strlen (tmp) > sizeof (tmp) - 1) */
      {
	GPF_T1 ("SQL sprintf buffer overflowed. sprintf of over 2000 characters caused this.");
      }

    session_buffered_write (ses, tmp, strlen (tmp));

  get_next:
    arg_inx++;

  get_next_no_arg_inx_increment:
    ptr++;
    len -= (int) (ptr - start);
    if (!*err_ret && len && ptr && *ptr)
      goto next_fragment;	/* see above */

  format_string_completed:
    ;
  }
  QR_RESET_CODE
  {
    caddr_t err = thr_get_error_code (((query_instance_t *) qst)->qi_thread);
    POP_QR_RESET;
    strses_free (ses);
    sqlr_resignal (err);
  }
  END_QR_RESET;

  if (!STRSES_CAN_BE_STRING (ses))
    {
      *err_ret = STRSES_LENGTH_ERROR ("sprintf");
      ptr = NULL;
    }
  else
    ptr = strses_string (ses);

  strses_free (ses);

  if (*err_ret)
    {
      dk_free_box (ptr);
      ptr = NULL;
    }

  return ((caddr_t) ptr);
}


caddr_t
bif_sprintf_or_null (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int argctr, argcount = BOX_ELEMENTS (args);

  for (argctr = 0; argctr < argcount; argctr++)
    {
      caddr_t arg = bif_arg_nochecks (qst, args, argctr);
      if (DV_DB_NULL == DV_TYPE_OF (arg))
	return NEW_DB_NULL;
    }

  return bif_sprintf (qst, err_ret, args);
}


caddr_t
bif_sprintf_iri (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t res = bif_sprintf (qst, err_ret, args);

  box_flags (res) = BF_IRI;

  return res;
}


caddr_t
bif_sprintf_iri_or_null (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t res = bif_sprintf_or_null (qst, err_ret, args);

  if (DV_STRING == DV_TYPE_OF (res))
    box_flags (res) = BF_IRI;

  return res;
}


caddr_t
bif_sprintf_inverse (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t str = bif_arg (qst, args, 0, "sprintf_inverse");
  caddr_t fmt = bif_string_arg (qst, args, 1, "sprintf_inverse");
  long hide_errors = bif_long_arg (qst, args, 2, "sprintf_inverse");
  caddr_t expected_dtp_strg = ((3 < BOX_ELEMENTS (args)) ? bif_string_or_null_arg (qst, args, 3, "sprintf_inverse") : NULL);
  caddr_t err = NULL;
  caddr_t res = sprintf_inverse_ex (qst, &err, str, fmt, hide_errors, (unsigned char *) expected_dtp_strg);
  if (NULL != err)
    sqlr_resignal (err);
  return res;
}

caddr_t
sprintf_inverse (caddr_t *qst, caddr_t *err_ret, ccaddr_t str, ccaddr_t fmt, long hide_errors)
{
  return sprintf_inverse_ex (qst, err_ret, str, fmt, hide_errors, NULL);
}

caddr_t
sprintf_inverse_ex (caddr_t *qst, caddr_t *err_ret, ccaddr_t str, ccaddr_t fmt, long hide_errors, unsigned char *expected_dtp_strg)
{
  dtp_t str_dtp = DV_TYPE_OF (str);
  dk_set_t res = NULL;
  char *str_tail = (char *)str;
  char *fmt_tail = (char *)fmt;
  char *field_start, *field_end, *next_field_start, *fmt_modifier;
  char *val_start, *val_end, *str_scan_tail;
  int field_len, field_prec;
  char field_fmt_buf[100];
  char *field_fmt_tail;
  int field_ctr = 0;
  int expected_dtp_len = ((NULL == expected_dtp_strg) ? 0 : box_length (expected_dtp_strg) - 1);
  caddr_t val;

retry_unrdf:
  if ((DV_STRING != str_dtp) && (DV_UNAME != str_dtp))
    {
      if (DV_RDF == str_dtp)
	{
	  str = ((rdf_box_t *) str)->rb_box;
	  str_dtp = DV_TYPE_OF (str);
	  goto retry_unrdf;	/* see above */
	}
      if ((0 == hide_errors) && (DV_DB_NULL != str_dtp))
	{
          err_ret[0] = srv_make_new_error ("22023", "SR536",
	      "Function sprintf_inverse needs a string as argument 0 if argument 2 is zero, not an arg of type %s (%d)",
	      dv_type_title (str_dtp), str_dtp );
          return NULL;
	}
      goto format_mismatch;
    }
  QR_RESET_CTX
  {
  find_next_format:
    while ('\0' != fmt_tail[0])
      {
	if ('%' == fmt_tail[0])
	  {
	    switch (fmt_tail[1])
	      {
	      case '%':
		fmt_tail++;
		break;

	      case '{':
		{
		  caddr_t connvar_name, connvar_value, *connvar_valplace;
		  dtp_t connvar_dtp;
		  query_instance_t *qi = (query_instance_t *) qst;
		  client_connection_t *cli;
		  const char *val_tail;

		  field_start = fmt_tail;
		  fmt_tail++;
		  fmt_tail++;

		  while (isalnum ((unsigned char) (fmt_tail[0])) || ('_' == fmt_tail[0]))
		    fmt_tail++;

		  if ('}' != fmt_tail[0])
		    sqlr_new_error ("22026", "SR589",
			"sprintf_inverse format %%{ should have '}' immediately after the name of connection variable");

		  fmt_tail++;

		  if (!*fmt_tail || !strchr ("sU" /*"diouxXeEfgcsSIVU" */ , *fmt_tail))
		    sqlr_new_error ("22023", "SR590", "Invalid format string for sprintf_inverse at escape %d", field_ctr);

		  memset (field_fmt_buf, 0, sizeof (field_fmt_buf));
		  memcpy (field_fmt_buf, field_start + 2, MIN ((fmt_tail - field_start) - 3, sizeof (field_fmt_buf) - 1));

                  if (NULL == qi)
		    sqlr_new_error ("22026", "SR597",
		      "sprintf_inverse can not process %%{%.200s}%c at compile time", field_fmt_buf, *fmt_tail);
                  cli = qi->qi_client;
		  connvar_name = box_dv_short_string (field_fmt_buf);
		  connvar_valplace = (caddr_t *) id_hash_get (cli->cli_globals, (caddr_t) & connvar_name);
		  dk_free_box (connvar_name);

		  if (NULL != connvar_valplace)
		    connvar_value = connvar_valplace[0];
		  else
		    {
		      connvar_value = uriqa_get_default_for_connvar (qi, field_fmt_buf);

		      if (NULL == connvar_value)
			{
			  sqlr_new_error ("22023", "SR591",
			      "Connection variable is mentioned by sprintf_inverse format %%{%.200s} but it does not exist",
			      field_fmt_buf);
			}
		    }

		  connvar_dtp = DV_TYPE_OF (connvar_value);

		  switch (*fmt_tail)
		    {
		    case 's':
		      if (DV_STRING != connvar_dtp)
			{
			  if (NULL == connvar_valplace)
			    dk_free_box (connvar_value);
			  sqlr_new_error ("22023", "SR588",
			      "Connection variable is mentioned by sprintf_inverse format %%{%.200s}s but its value is not a string",
			      field_fmt_buf);
			}

		      val_end = connvar_value + box_length (connvar_value) - 1;

		      for (val_tail = connvar_value; val_tail < val_end; val_tail++)
			{
			  if (str_tail[0] == val_tail[0])
			    {
			      str_tail++;
			      continue;
			    }

			  if (NULL == connvar_valplace)
			    dk_free_box (connvar_value);

			  goto POP_format_mismatch;
			}

		      if (NULL == connvar_valplace)
			dk_free_box (connvar_value);
		      break;

		    case 'U':
		      if (DV_STRING != connvar_dtp)
			{
			  if (NULL == connvar_valplace)
			    dk_free_box (connvar_value);
			  sqlr_new_error ("22023", "SR588",
			      "Connection variable is mentioned by sprintf_inverse format %%{%.200s}U but its value is not a string",
			      field_fmt_buf);
			}

		      val_end = connvar_value + box_length (connvar_value) - 1;

		      for (val_tail = connvar_value; val_tail < val_end; val_tail++)
			{
			  if (DKS_ESC_CHARCLASS_ACTION ((unsigned char) (val_tail[0]), DKS_ESC_URI))
			    {
			      ws_connection_t *ws = ((query_instance_t *) qst)->qi_client->cli_ws;
			      dk_session_t *ses = strses_allocate ();
			      caddr_t converted;

			      dks_esc_write (ses, val_tail, val_end - val_tail, WS_CHARSET (ws, qst), default_charset, DKS_ESC_URI);
			      converted = strses_string (ses);
			      dk_free_box (ses);

			      if (NULL == connvar_valplace)
				dk_free_box (connvar_value);

			      val_end = converted + box_length (converted) - 1;

			      for (val_tail = converted; val_tail < val_end; val_tail++)
				{
				  if (str_tail[0] != val_tail[0])
				    {
				      dk_free_box (converted);
				      goto POP_format_mismatch;
				    }

				  str_tail++;
				}

			      dk_free_box (converted);
			      fmt_tail++;
			      goto find_next_format;	/* see above */
			    }

			  if (str_tail[0] == val_tail[0])
			    {
			      str_tail++;
			      continue;
			    }

			  if (NULL == connvar_valplace)
			    dk_free_box (connvar_value);
			  goto POP_format_mismatch;
			}

		      if (NULL == connvar_valplace)
			dk_free_box (connvar_value);
		      break;

		    default:
		      if (NULL == connvar_valplace)
			dk_free_box (connvar_value);

		      sqlr_new_error ("22023", "SR594",
			  "Current implementation of sprintf_inverse() supports only %%U format for connection variables, %%{%.200s}%c is not supported",
			  field_fmt_buf, fmt_tail[0]);
		    }

		  fmt_tail++;
		  goto find_next_format;	/* see above */
		}

	      default:
		goto next_field;	/* see below */
	      }
	  }

	if (str_tail[0] != fmt_tail[0])
	  goto POP_format_mismatch;	/* see below */

	fmt_tail++;
	str_tail++;
      }

    if ('\0' != str_tail[0])
      {
	goto POP_format_mismatch;	/* see below */
      }
    POP_QR_RESET;

    return (caddr_t) (revlist_to_array (res));

  next_field:
    field_start = fmt_tail;
    field_len = field_prec = 0;

    /* skip the percent */
    fmt_tail++;

    /* skip the modifier */
    fmt_modifier = NULL;
    while (('\0' != fmt_tail[0]) && (NULL != strchr ("#0- +'_", fmt_tail[0])))
      {
	fmt_modifier = fmt_tail;
        fmt_tail++;
      }

    field_fmt_tail = field_fmt_buf;

    /* skip the width */
    while (('\0' != fmt_tail[0]) && (NULL != strchr ("0123456789", fmt_tail[0])))
      {
	if (field_fmt_tail - field_fmt_buf < sizeof (field_fmt_buf))
	  *field_fmt_tail++ = fmt_tail[0];
	fmt_tail++;
      }

    *field_fmt_tail = 0;
    field_len = atoi (field_fmt_buf);

    /* skip the precision */
    if ('.' == fmt_tail[0])
      {
	field_fmt_tail = field_fmt_buf;
	fmt_tail++;		/* skip the dot */

	while (('\0' != fmt_tail[0]) && (NULL != strchr ("0123456789", fmt_tail[0])))
	  {
	    if (field_fmt_tail - field_fmt_buf < sizeof (field_fmt_buf))
	      *field_fmt_tail++ = fmt_tail[0];
	    fmt_tail++;
	  }

	*field_fmt_tail = 0;
	field_prec = atoi (field_fmt_buf);
      }

    /* skip the size modifier */
    if (('\0' != fmt_tail[0]) && (NULL != strchr ("hlLq", fmt_tail[0])))
      fmt_tail++;

    if (('\0' != fmt_tail[0]) && (NULL != strchr ("dDiouxXeEfgcsRSIVU", fmt_tail[0]))
	&& (!fmt_modifier || 'R' == fmt_tail[0] || '_' != fmt_modifier[0]))
      fmt_tail++;
    else
      sqlr_new_error ("22023", "SR523",
	  "Invalid format string for sprintf_inverse at field %d (column %ld of format '%.1000s')",
	  field_ctr, (long) (fmt_tail - fmt), fmt);

    field_end = fmt_tail;
    val_start = val_end = str_tail;

  check_val_end:
    next_field_start = field_end;

    if ('\0' == fmt_tail[0])
      {
	while ('\0' != val_end[0])
	  val_end++;

	str_scan_tail = val_end;
	goto val_end_found;
      }

    str_scan_tail = val_end;

    while ('\0' != next_field_start[0])
      {
	if ('%' == next_field_start[0])
	  {
	    if ('%' == next_field_start[1])
	      next_field_start++;
	    else
	      goto val_end_found;	/* see below */
	  }

	if (str_scan_tail[0] != next_field_start[0])
	  {
	    if ('\0' == str_scan_tail[0])
	      goto POP_format_mismatch_mid_field;	/* see below */

	    val_end++;
	    goto check_val_end;	/* see above */
	  }

	next_field_start++;
	str_scan_tail++;
      }

    if ('\0' != str_scan_tail[0])
      goto POP_format_mismatch_mid_field;	/* see below */

  val_end_found:
    fmt_tail = next_field_start;
    str_tail = str_scan_tail;
    switch (field_end[-1])
      {
      case 'd':
      case 'i':
	{
	  int acc = 0;
	  int is_neg = 0;
	  const char *val_tail = val_start;

	  if (val_tail == val_end)
	    goto POP_format_mismatch_mid_field;

	  if ('+' == val_tail[0])
	    {
	      val_tail++;

	      if (val_tail == val_end)
		goto POP_format_mismatch_mid_field;
	    }
	  else if ('-' == val_tail[0])
	    {
	      is_neg = 1;
	      val_tail++;

	      if (val_tail == val_end)
		goto POP_format_mismatch_mid_field;
	    }

	  while (val_tail < val_end)
	    {
	      if (!isdigit (val_tail[0]))
		goto POP_format_mismatch_mid_field;
	      acc = acc * 10 + (val_tail[0] - '0');
	      val_tail++;
	    }

	  dk_set_push (&res, box_num (is_neg ? -acc : acc));
	}
	break;

      case 'o':
	{
	  int acc = 0;
	  const char *val_tail = val_start;

	  if (val_tail == val_end)
	    goto POP_format_mismatch_mid_field;

	  while (val_tail < val_end)
	    {
#ifdef isoctdigit		/* Available not on all platforms */
	      if (!isoctdigit (val_tail[0]))
#else
	      if (('0' > val_tail[0]) || ('7' < val_tail[0]))
#endif
		goto POP_format_mismatch_mid_field;

	      acc = acc * 8 + (val_tail[0] - '0');
	      val_tail++;
	    }

	  dk_set_push (&res, box_num (acc));
	}
	break;

      case 'u':
	{
	  int acc = 0;
	  const char *val_tail = val_start;

	  if (val_tail == val_end)
	    goto POP_format_mismatch_mid_field;

	  while (val_tail < val_end)
	    {
	      if (!isdigit (val_tail[0]))
		goto POP_format_mismatch_mid_field;

	      acc = acc * 10 + (val_tail[0] - '0');
	      val_tail++;
	    }

	  dk_set_push (&res, box_num (acc));
	}
	break;

      case 'x':
	{
	  int acc = 0;
	  const char *val_tail = val_start;

	  if (val_tail == val_end)
	    goto POP_format_mismatch_mid_field;

	  while (val_tail < val_end)
	    {
	      if (!isxdigit (val_tail[0]) || isupper (val_tail[0]))
		goto POP_format_mismatch_mid_field;

#define HEXDIGITVAL(n) \
  (isdigit (n) ? ((n)-'0') : ((n) + 10 - (isupper (n) ? 'A' : 'a')))

	      acc = (acc << 4) + HEXDIGITVAL (val_tail[0]);
	      val_tail++;
	    }

	  dk_set_push (&res, box_num (acc));
	}
	break;

      case 'X':
	{
	  int acc = 0;
	  const char *val_tail = val_start;

	  if (val_tail == val_end)
	    goto POP_format_mismatch_mid_field;

	  while (val_tail < val_end)
	    {
	      if (!isxdigit (val_tail[0]) || islower (val_tail[0]))
		goto POP_format_mismatch_mid_field;

	      acc = (acc << 4) + HEXDIGITVAL (val_tail[0]);
	      val_tail++;
	    }

	  dk_set_push (&res, box_num (acc));
	}
	break;

      case 'e':
      case 'E':
      case 'f':
      case 'g':
        {
          const char *val_tail = val_start;
          int fmt_idx = dk_set_length (res);
          caddr_t val_buf;
          int exp_dtp = 0x80 | ((int)((fmt_idx < expected_dtp_len) ? (expected_dtp_strg[fmt_idx] & 0x7F) : 0));
          if (('-' == val_tail[0]) || ('+' == val_tail[0]))
            val_tail++;
          if (!isdigit (val_tail[0]))
            goto POP_format_mismatch_mid_field;
          val_tail++;
          while (isdigit (val_tail[0])) val_tail++;
          if ('.' == val_tail[0])
            {
              val_tail++;
              if (!isdigit (val_tail[0]))
                goto POP_format_mismatch_mid_field;
              val_tail++;
              while (isdigit (val_tail[0])) val_tail++;
            }
          if (('f' != field_end[-1]) && (('e' == val_tail[0]) || ('E' == val_tail[0])))
            {
              const char *val_tail_try = val_tail+1;
              if (('-' == val_tail_try[0]) || ('+' == val_tail_try[0]))
                val_tail_try++;
              if (isdigit (val_tail_try[0]))
                {
                  val_tail_try++;
                  while (isdigit (val_tail_try[0])) val_tail_try++;
                  val_tail = val_tail_try;
                }
            }
          if (val_tail != val_end)
            goto POP_format_mismatch_mid_field;
          val_buf = box_dv_short_nchars (val_start, val_end - val_start);
          switch (exp_dtp)
            {
            case DV_SINGLE_FLOAT:
              {
                float f = 0.0;
                int sctr = sscanf (val_buf, "%f", &f);
                dk_free_box (val_buf);
                if (1 != sctr)
                  goto POP_format_mismatch_mid_field;
                dk_set_push (&res, box_float (f));
                break;
              }
            case DV_DOUBLE_FLOAT:
            default:
              {
                double d = 0.0;
                int sctr = sscanf (val_buf, "%lf", &d);
                dk_free_box (val_buf);
                if (1 != sctr)
                  goto POP_format_mismatch_mid_field;
                dk_set_push (&res, box_float (d));
                break;
              }
            case DV_NUMERIC:
              {
                numeric_t res = numeric_allocate ();
                int errcode = numeric_from_string (res, val_buf);
                dk_free_box (val_buf);
                if (NUMERIC_STS_SUCCESS != errcode)
                  {
                    numeric_free (res);
                    goto POP_format_mismatch_mid_field;
                  }
                return ((caddr_t) res);
              }
            }
          break;
        }

      case 'c':

	goto sorry_unsupported;
	break;

      case 's':
	val = box_dv_short_nchars (val_start, val_end - val_start);
	dk_set_push (&res, val);
	break;

      case 'R': /* replace modifier character with space */
	val = box_dv_short_nchars (val_start, val_end - val_start);
	if (fmt_modifier)
	  {
	    size_t pos;
	    char tmp_buf [2] = {0,0};
	    tmp_buf[0] = fmt_modifier[0];
	    pos = strspn (val, tmp_buf);
	    if (pos > 0)
	      memset (val, ' ', pos);
	  }
	dk_set_push (&res, val);
	break;

      case 'S':		/* via sprintf_escaped_str_literal */
	goto sorry_unsupported;
	break;

      case 'I':		/* via sprintf_escaped_id */
	goto sorry_unsupported;
	break;

      case 'U':
	{
	  caddr_t buf = box_dv_short_nchars (val_start, val_end - val_start);
	  char *out = buf;
	  char *in;
          int buf_contains_pct_8bit = 0;
	  for (in = buf; '\0' != in[0]; in++)
	    {
              int chr;
	      if ('%' == in[0])
		{
		  if (isxdigit (in[1]) && isxdigit (in[2]))
		    {
		      int hi = HEXDIGITVAL (in[1]);
		      int lo = HEXDIGITVAL (in[2]);
                      chr = ((hi << 4) | lo);
		      in += 2;
		    }
		  else
		    {
		      dk_free_box (buf);
		      goto POP_format_mismatch_mid_field;
		    }
		}
	      else if ('+' == in[0])
		chr = ' ';
	      else
		chr = in[0];
              if (chr & ~0x7F)
                buf_contains_pct_8bit = 1;
              (out++)[0] = chr;
	    }
          if (buf_contains_pct_8bit && expected_dtp_len)
            {
              int fmt_idx = dk_set_length (res);
              if ((fmt_idx < expected_dtp_len) && ((DV_WIDE & 0x7F) == (expected_dtp_strg[fmt_idx] & 0x7F)))
                {
                  val = box_utf8_as_wide_char (buf, NULL, out-buf, 0, DV_WIDE);
                  if (NULL == val)
                    {
		      dk_free_box (buf);
		      goto POP_format_mismatch_mid_field;
                    }
                  dk_free_box (buf);
                  dk_set_push (&res, val);
                  break;
                }
            }
	  val = box_dv_short_nchars (buf, out - buf);
	  dk_free_box (buf);
	  dk_set_push (&res, val);
          break;
	}

      case 'D':
	{
	  const char *err_msg = NULL;
	  int skip_len = dt_scan_from_buffer (val_start, field_len, &val, &err_msg);

	  if ((NULL == val) || (skip_len != (val_end - val_start)))
	    {
	      dk_free_box (val);
	      goto POP_format_mismatch_mid_field;
	    }

	  dk_set_push (&res, val);
	}
	break;

      case 'V':		/* via http_value_esc (qst, ses, arg, NULL, DKS_ESC_PTEXT); */
	goto sorry_unsupported;
	break;

      default:
	GPF_T;
      }

    if ('\0' == fmt_tail[0])
      {
	POP_QR_RESET;
	return (caddr_t) (revlist_to_array (res));
      }

    goto next_field;		/* see above */

  sorry_unsupported:
    sqlr_new_error ("22023", "SR524",
	"Sorry, unsupported format string for sprintf_inverse at field %d (column %ld of format '%.1000s')",
	field_ctr, (long) (fmt_tail - fmt), fmt);

  POP_format_mismatch_mid_field:
    POP_QR_RESET;
    goto format_mismatch_mid_field;	/* see below */

  POP_format_mismatch:
    POP_QR_RESET;
    goto format_mismatch;	/* see below */

  }
  QR_RESET_CODE
  {
    caddr_t err = thr_get_error_code (((query_instance_t *) qst)->qi_thread);
    POP_QR_RESET;

    if (!hide_errors)
      {
	while (NULL != res)
	  dk_free_tree (dk_set_pop (&res));
        err_ret[0] = err;
        return NULL;
      }
    goto format_mismatch_mid_field;	/* see below */
  }
  END_QR_RESET;

format_mismatch_mid_field:
  if (2 == hide_errors)
    dk_set_push (&res, NEW_DB_NULL);

format_mismatch:
  switch (hide_errors)
    {
    case 2:
      while ('\0' != fmt_tail[0])
	{
	  if ('%' == fmt_tail[0])
	    {
	      if (('%' == fmt_tail[1]) || ('{' == fmt_tail[1]))
		fmt_tail++;
	      else
		dk_set_push (&res, NEW_DB_NULL);
	    }

	  fmt_tail++;
	}
      /* no break: */

    case 3:
      return (caddr_t) (revlist_to_array (res));

    default:
      while (NULL != res)
	dk_free_tree (dk_set_pop (&res));

      return NEW_DB_NULL;
    }

  return (caddr_t) (revlist_to_array (res));
}


/* New functions by AK 15-JAN-1997. */

/* strchr(str,chr)
   Finds the first occurrence of the character chr from the string str.
   If it is not found, returns NULL, otherwise returns the zero-based
   index of the character.
   Argument chr can be either an ascii value (an integer) or
   a string. In the latter case, the first character of the string
   is searched for. strchr('Shakaali',97) is same as strchr('Shakaali','a')
   and should return 2. */
caddr_t
bif_strchr (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t str = bif_string_or_uname_or_wide_or_null_arg (qst, args, 0, "strchr");
  unsigned long chr = (unsigned long) bif_long_or_char_arg (qst, args, 1, "strchr");
  char *inx;
  int sizeof_char;

  if (NULL == str)
  {
    return (NEW_DB_NULL);
  }
  if (DV_WIDESTRINGP (str))
  {
    sizeof_char = sizeof (wchar_t);
    inx = (char *)virt_wcschr ((wchar_t *)str, (wchar_t)chr);
  }
  else
  {
    sizeof_char = sizeof (char);
    inx = strchr (str, chr);
  }

  if (!inx)
  {
    /* 0 or 1 ??? Not so good idea. Where this is free'ed??? */
    return (NEW_DB_NULL);
  }
  else
  {
    return (box_num ((inx - str) / sizeof_char));
  }
}


caddr_t
bif_strrchr (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t str = bif_string_or_uname_or_wide_or_null_arg (qst, args, 0, "strrchr");
  unsigned long chr = (unsigned long) bif_long_or_char_arg (qst, args, 1, "strrchr");
  char *inx;
  int sizeof_char;

  if (NULL == str)
  {
    return (NEW_DB_NULL);
  }
  if (DV_WIDESTRINGP (str))
  {
    sizeof_char = sizeof (wchar_t);
    inx = (char *)virt_wcsrchr ((wchar_t *)str, (wchar_t)chr);
  }
  else
  {
    sizeof_char = sizeof (char);
    inx = strrchr (str, chr);
  }

  if (!inx)
  {
    /* 0 or 1 ??? Not so good idea. Where this is free'ed??? */
    return (NEW_DB_NULL);
  }
  else
  {
    return (box_num ((inx - str) / sizeof_char));
  }
}

#define BIF_STRSTR_POS		0
#define BIF_STRSTR_BOOL_ANY	1
#define BIF_STRSTR_BOOL_START	2
#define BIF_STRSTR_BOOL_END	3

caddr_t
bif_strstr_imp (caddr_t * qst, state_slot_t ** args, int opcode, const char *func_name)
{
  caddr_t str1 = bif_string_or_uname_or_wide_or_null_arg (qst, args, 0, func_name);
  caddr_t str2 = bif_string_or_uname_or_wide_or_null_arg (qst, args, 1, func_name);
  char *inx = NULL;
  dtp_t dtp1 = DV_TYPE_OF (str1);
  dtp_t dtp2 = DV_TYPE_OF (str2);
  int len1, len2;
  int sizeof_char =
    (IS_WIDE_STRING_DTP (dtp1) || IS_WIDE_STRING_DTP (dtp2)) ?
    sizeof (wchar_t) :
    sizeof (char);

  if ((NULL == str1) || (NULL == str2))
    return (NEW_DB_NULL);

  if (sizeof_char == sizeof (wchar_t))
    {
      if (!IS_WIDE_STRING_DTP (dtp1))
        sqlr_new_error ("22023", "SR039", "The first argument to %s() is not a wide string", func_name);
      if (!IS_WIDE_STRING_DTP (dtp2))
        sqlr_new_error ("22023", "SR040", "The second argument to %s() is not a wide string", func_name);
      switch (opcode)
        {
        case BIF_STRSTR_POS:
        case BIF_STRSTR_BOOL_ANY:
          inx = (char *)virt_wcsstr ((wchar_t *)str1, (wchar_t *)str2);
          break;
        case BIF_STRSTR_BOOL_START:
          len1 = box_length (str1);
          len2 = box_length (str2);
          if ((len2 > len1) || memcmp (str1, str2, len2 - sizeof (wchar_t)))
            inx = 0;
          else
            inx = str1;
          break;
        case BIF_STRSTR_BOOL_END:
          len1 = box_length (str1);
          len2 = box_length (str2);
          if ((len2 > len1) || memcmp (str1 + len1 - len2, str2, len2 - sizeof (wchar_t)))
            inx = 0;
          else
            inx = str1 + (len1 - len2);
          break;
        }
    }
  else
    {
      switch (opcode)
        {
        case BIF_STRSTR_POS:
        case BIF_STRSTR_BOOL_ANY:
          inx = strstr (str1, str2);
          break;
        case BIF_STRSTR_BOOL_START:
          len1 = box_length (str1);
          len2 = box_length (str2);
          if ((len2 > len1) || memcmp (str1, str2, len2 - 1))
            inx = 0;
          else
            inx = str1;
          break;
        case BIF_STRSTR_BOOL_END:
          len1 = box_length (str1);
          len2 = box_length (str2);
          if ((len2 > len1) || memcmp (str1 + (len1 - len2), str2, len2 - 1))
            inx = 0;
          else
            inx = str1 + (len1 - len2);
          break;
        }
    }
  if (BIF_STRSTR_POS == opcode)
    {
      if (!inx)
        return (NEW_DB_NULL);
      else
        return (box_num ((inx - str1) / sizeof_char));
    }
  else
    return box_bool (inx);
}

caddr_t
bif_strstr (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_strstr_imp (qst, args, BIF_STRSTR_POS, "strstr");
}

caddr_t
bif_strcontains (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_strstr_imp (qst, args, BIF_STRSTR_BOOL_ANY, "strcontains");
}

caddr_t
bif_starts_with (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_strstr_imp (qst, args, BIF_STRSTR_BOOL_START, "starts_with");
}

caddr_t
bif_ends_with (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_strstr_imp (qst, args, BIF_STRSTR_BOOL_END, "ends_with");
}

/* Like previous, but use our own function nc_strstr instead, defined in
   the module string.c, which does its job ignoring the case
   (as well as the ISO 8859/1 diacritic letters).
   nc_strstr(str1,str2) should produce the same result as
   matches_like(str1,concatenate('**',str2)) */
caddr_t
bif_nc_strstr (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t str1 = bif_string_or_null_arg (qst, args, 0, "nc_strstr");
  caddr_t str2 = bif_string_or_null_arg (qst, args, 1, "nc_strstr");
  char *inx;

  if ((NULL == str1) || (NULL == str2))
  {
    return (NEW_DB_NULL);
  }
  inx = (char *) nc_strstr ((unsigned char *) str1, (unsigned char *) str2);  /* Defined in string.c */
  if (!inx)
  {
    /* 0 or 1 ??? Not so good idea. Where this is free'ed??? */
    return (NEW_DB_NULL);
  }
  else
  {
    return (box_num (inx - str1));
  }
}

static caddr_t
bif_casemode_strcmp (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t str1 = bif_string_or_uname_arg (qst, args, 0, "casemode_strcmp");
  caddr_t str2 = bif_string_or_uname_arg (qst, args, 1, "casemode_strcmp");
  return box_num (CASEMODESTRCMP (str1, str2));
}


static caddr_t
bif_fix_identifier_case (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t ident = bif_string_or_uname_arg (qst, args, 0, "fix_identifier_case");
  caddr_t out = sqlp_box_id_upcase (ident);
  caddr_t out1 = box_dv_short_string (out);
  dk_free_box (out);
  return out1;
}



/*
   locate: more to standard than strstr
   LOCATE(string_exp1, string_exp2[, start])
   Returns the starting position of the first occurrence of
   string_exp1 within string_exp2. The search for the first occurrence
   of string_exp1 begins with the first character position in string_exp2
   unless the optional argument, start, is specified.
   If start is specified, the search begins with the character
   position indicated by the value of start.
   The first character position in string_exp2 is indicated by the value 1.
   If string_exp1 is not found within string_exp2, the value 0 is returned.

   What should return when str1 is "" (an empty string) ???
   Now returns 1.
 */
caddr_t
bif_locate (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char *me = "locate";
  int n_args = BOX_ELEMENTS (args);
  caddr_t str1 = bif_string_or_uname_or_wide_or_null_arg (qst, args, 0, me);
  caddr_t str2 = bif_string_or_uname_or_wide_or_null_arg (qst, args, 1, me);
  long int start = (long int) ((n_args > 2) ? bif_long_arg (qst, args, 2, me) - 1 : 0);
  long int len1, len2;
  char *inx;
  dtp_t dtp1 = DV_TYPE_OF (str1), dtp2 = DV_TYPE_OF (str2);
  int sizeof_char = (IS_WIDE_STRING_DTP (dtp1) || IS_WIDE_STRING_DTP (dtp2)) ? sizeof (wchar_t) : sizeof (char);

  if ((NULL == str1) || (NULL == str2))
  {
    return (NEW_DB_NULL);
  }

  if (sizeof_char == sizeof (wchar_t))
  {
    if (!IS_WIDE_STRING_DTP (dtp1))
  sqlr_new_error ("22023", "SR041", "Argument 1 of %s is not a wide string", me);
    if (!IS_WIDE_STRING_DTP (dtp2))
  sqlr_new_error ("22023", "SR042", "Argument 2 of %s is not a wide string", me);
  }

  len1 = (box_length (str1) / sizeof_char - 1); /* box_length returns a length + 1 */
  len2 = (box_length (str2) / sizeof_char - 1); /* box_length returns a length + 1 */

/* Returns 0 (false), if start > len2 (i.e. len2-start would be < 0, as
   len1 is always 0 or more.) Also false if the remaining piece of str2
   is shorter than len1.
   Also if a stupid caller gives start as a negative number.
 */
  if ((start < 0) || ((len2 - start) < len1))
  {
    return (box_num (0));
  }
  if (sizeof_char == sizeof (wchar_t))
  inx = (char *)virt_wcsstr ((wchar_t *)(str2 + start), (wchar_t *)str1); /* Note the reversed order ! */
  else
  inx = strstr ((str2 + start), str1);  /* Note the reversed order ! */
  if (!inx)
  {
    return (box_num (0));
  }
  else
  {
    return (box_num ((inx - str2) / sizeof_char + 1));
  }       /* Result is also one-based. */
}


/* Returns 1 if the given two string arguments match in the similar way as
   with like operand in queries: string1 LIKE string2
   or 0, if they do not match. Uses cmp_like function defined in the
   module string.c
   String2 can be prefixed with the same special characters '%%', '**'
   or one or more @'s, to get the same special effects as with LIKE. */
caddr_t
bif_matches_like (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int st = LIKE_ARG_CHAR, pt = LIKE_ARG_CHAR;
  caddr_t str1 = bif_string_or_uname_or_wide_or_null_arg (qst, args, 0, "matches_like");
  caddr_t str2 = bif_string_or_uname_or_wide_or_null_arg (qst, args, 1, "matches_like");
  dtp_t ltype = DV_TYPE_OF (str1);
  dtp_t rtype = DV_TYPE_OF (str2);
  long res1;
  collation_t *coll1, *coll2;
  caddr_t escape = "\\";
  if (BOX_ELEMENTS (args) > 2)
    escape = bif_string_arg (qst, args, 2, "matches_like");
  if (strlen (escape) != 1)
  sqlr_new_error ("22019", "SR043", "the escape should be non-empty string of length 1 in matches_like");

  if (DV_WIDE == rtype || DV_LONG_WIDE == rtype)
    pt = LIKE_ARG_WCHAR;
  if (DV_WIDE == ltype || DV_LONG_WIDE == ltype)
    st = LIKE_ARG_WCHAR;

  if ((NULL == str1) || (NULL == str2))
  {
    return (NEW_DB_NULL);
  }       /* ??? */

  coll1 = args[0]->ssl_sqt.sqt_collation;
  coll2 = args[1]->ssl_sqt.sqt_collation;
  if (coll1)
  {
    if (coll1 && coll2 != coll1)
  coll1 = default_collation;
  }
  else
  coll1 = coll2;
  res1 = (cmp_like (str1, str2, coll1, escape[0], st, pt) == DVC_MATCH);  /* Defined in wi.h */
  return (box_num (res1));
}


caddr_t
box_n_chars (dtp_t * bin, int len)
{
  caddr_t res = dk_alloc_box (len + 1, DV_STRING);
  memcpy (res, bin, len);
  res[len] = 0;
  return res;
}


caddr_t
bif_rdf_rng_min (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  /* 10 first chars if over 10 */
  caddr_t str_in = bif_arg_unrdf (qst, args, 0, "__like_min");
  if (!DV_STRINGP (str_in)
      || box_length (str_in) - 1 < 10)
    return box_copy_tree (str_in);
  return box_n_chars ((db_buf_t)str_in, 10);
}


caddr_t
bif_like_min (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int len;
  caddr_t res;
  caddr_t str_in = bif_string_or_wide_or_null_arg (qst, args, 0, "__like_min");
  caddr_t str = NULL;
  dtp_t dtp = DV_TYPE_OF (str_in);
  char esc = (char) (BOX_ELEMENTS (args) > 1 ? bif_long_arg (qst, args, 1, "__like_min") : 0);
  char * ctr = NULL;

  if (!str_in)
    return dk_alloc_box (0, DV_DB_NULL);
  switch (dtp)
    {
      case DV_STRING:
      case DV_C_STRING:
	  str = box_copy (str_in);
	  break;
      case DV_WIDE:
	  str = box_wide_as_utf8_char (str_in, box_length (str_in) / sizeof (wchar_t) - 1, DV_SHORT_STRING);
	  break;
      default:
	  sqlr_new_error ("22023", "SR484", "Function __like_min needs a string as argument 0, not an arg of type %s (%d)",
	      dv_type_title (dtp), dtp);
    }
  if (esc != '\0' && NULL != strchr (str, esc))
    {
      char * ptr = str, * end = str + strlen (str);
      for (;;)
	{
	  ctr = strpbrk (ptr, "%_*[]");
	  ptr = strchr (ptr, esc);
	  if ((ctr && ctr < ptr) || !ptr)
	    break;
	  memmove (ptr, ptr+1, end - ptr);
	  ptr ++;
	}
    }
  else
    ctr = strpbrk (str, "%_*[]");
  if (!ctr)
    {
      res = box_dv_short_string (str);
      goto ret;
    }
  len = ctr - str;
  res = dk_alloc_box (1+len, DV_STRING);
  memcpy (res, str, len);
  res[len] = 0;
ret:
  dk_free_box (str);
  return res;
}


caddr_t
bif_like_max (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int len;
  caddr_t res;
  caddr_t str_in = bif_string_or_wide_or_null_arg (qst, args, 0, "__like_max");
  caddr_t str = NULL;
  dtp_t dtp = DV_TYPE_OF (str_in);
  char esc = (char) (BOX_ELEMENTS (args) > 1 ? bif_long_arg (qst, args, 1, "__like_max") : 0);
  char * ctr;

  if (!str_in)
    return dk_alloc_box (0, DV_DB_NULL);
  switch (dtp)
    {
      case DV_STRING:
      case DV_C_STRING:
	  str = box_copy (str_in);
	  break;
      case DV_WIDE:
	  str = box_wide_as_utf8_char (str_in, box_length (str_in) / sizeof (wchar_t) - 1, DV_SHORT_STRING);
	  break;
      default:
	  sqlr_new_error ("22023", "SR484", "Function __like_max needs a string as argument 0, not an arg of type %s (%d)",
	      dv_type_title (dtp), dtp);
    }
  if (esc != '\0' && NULL != strchr (str, esc))
    {
      char * ptr = str, * end = str + strlen (str);
      for (;;)
	{
	  ctr = strpbrk (ptr, "%_*[]");
	  ptr = strchr (ptr, esc);
	  if ((ctr && ctr < ptr) || !ptr)
	    break;
	  memmove (ptr, ptr+1, end - ptr);
	  ptr ++;
	}
    }
  else
    ctr = strpbrk (str, "%_*[]");
  if (!ctr)
    {
      res = box_dv_short_string (str);
      goto ret;
    }
  len = ctr - str;
  if (0 == len || 0xff == (unsigned char) ctr[0])
    {
      res = dk_alloc_box (5+len, DV_STRING);
      memcpy (res, str, len);
      res[len] = 0xff;
      res[len+1] = 0xff;
      res[len+2] = 0xff;
      res[len+3] = 0xff;
      res[len + 4] = 0;
    }
  else
    {
      res = dk_alloc_box (1+len, DV_STRING);
      memcpy (res, str, len);
      res[len-1]++;
      res[len] = 0;
    }
ret:
  dk_free_box (str);
  return res;
}


/* ascii(str) is equal to aref(str,0) when argument is a string. */
caddr_t
bif_ascii (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg = bif_string_or_wide_or_uname_arg (qst, args, 0, "ascii");
  dtp_t dtp = DV_TYPE_OF (arg);

  /* if(DV_DB_NULL == dtp) { return(box_num(0)); } */

  switch (dtp)
  {
  case DV_STRING:
    return (box_num (*((unsigned char *) arg)));
  case DV_WIDE:
  case DV_LONG_WIDE:
    return (box_num (*((wchar_t *) arg)));
  default:
    {
  sqlr_new_error ("22023", "SR044",
    "Function ascii needs a string or similar thing as its argument, "
    "not an argument of type %d (= %s)",
    dtp, dv_type_title (dtp)
    );
    }
  }
  NO_CADDR_T;
}


/* A new function by AK, 16-JAN-1997. Returns a new, one character long
   string formed from the ascii value given as an argument.
   Well, if the value is over > 255, then form a new string of so
   many bytes as there are significant (non-zero) bytes in the long,
   however, max. 4 bytes. (I.e. if user supplies an UNICODE code of
   16-bits, then two byte long string is formed.)
   Bytes are stored into the string starting from the lowest byte.
 */
caddr_t
bif_chr (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  unsigned long n = (unsigned long) bif_long_arg (qst, args, 0, "chr");
  caddr_t str;
  int i;
  char temp[5];
  for (i = 0; n && (i < 4); i++)
  {
    temp[i] = (char) (n & 0xFF);
    n >>= 8;      /* Next highest byte in the long arg. */
  }
  temp[i] = '\0';
  str = dk_alloc_box ((i + 1), DV_LONG_STRING);
  memcpy (str, temp, (i + 1));
  return str;
}

caddr_t
bif_chr1 (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  unsigned long n = (unsigned long) bif_long_arg (qst, args, 0, "chr1");
  caddr_t str = dk_alloc_box (2, DV_LONG_STRING);
  str[0] = (n & 0xff);
  str[1] = '\0';
  return str;
}


/* Let's use our own definitions in the following functions, so that we
   get also the ISO 8859/1 diacritic letters between 192 and 255
   converted correctly.
   Note that 215 (multiplicative sign x) is converted to 247 (quotient
   sign) and vice versa. However, it's not especially checked, as some
   other ISO 8859/x (e.g. the Eastern European character set) might
   contain a real letter in that position.
   However, positions 223 (German double-s) and 255 (y with diaeresis,
   i.e. two dots) are checked and are not converted to each other,
   as there has been a few putative customers from German speaking
   countries, jah-jah-jah.

   Maybe we should have later here some kind of a flag for strange
   monocase character sets like Arabian, Unicodes, etc
   And for the Turkish special case, where the uppercase variant of i is
   a big dotted I, and the lowercase variant of I in turn is a small
   dotless i.
   Maybe we could convert hiragana to katakana and vice versa, whatever
   is the standard usage.

   I do not know about AIX, but I could guess that its native isalpha,
   etc. macros, using ctp, or whatever table, could be configurable,
   maybe even in run-time, with some SET LOCALITY option from the
   operating system. I do not know, have to check that.
 */

/* C should be given unsigned! */
#define isISOletter(C) \
  ((C) && isalpha(C))
  /* this is cover only ISO 8859v encodings */
  /*((C) && (isalpha(C) || (((C) >= 192) && ((C) != 223) && ((C) != 255))))*/

#define raw_tolower(C) ((C) | 32)
#define raw_toupper(C) ((C) & (255-32))


caddr_t
bif_lcase (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t str = bif_string_or_uname_or_wide_or_null_arg (qst, args, 0, "lcase");
  long len;
  caddr_t res;
  int i;

  if (NULL == str)
  {
    return (NEW_DB_NULL);
  }
  if (DV_WIDESTRINGP (str))
    {
      len = box_length (str)/sizeof (wchar_t);
      res = dk_alloc_box (len * sizeof (wchar_t), DV_WIDE);
      for (i = 0; i < len; i++)
  ((wchar_t *)res)[i] = (wchar_t)unicode3_getlcase((unichar)((wchar_t *)str)[i]);
      return res;
    }


  len = (box_length (str) - 1); /* box_length returns a length + 1 */
  res = dk_alloc_box (len + 1, DV_LONG_STRING);
  for (i = 0; i <= len; i++)
  {
    if (isISOletter (((unsigned char *) str)[i]))
  {
    (((unsigned char *) res)[i]) = raw_tolower (((unsigned char *) str)[i]);
  }
    else
  {
    /* Otherwise, just copy the byte, whatever it is: */
    (((unsigned char *) res)[i]) = (((unsigned char *) str)[i]);
  }
  }

  return res;
}


caddr_t
bif_ucase (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t str = bif_string_or_uname_or_wide_or_null_arg (qst, args, 0, "ucase");
  long len;
  caddr_t res;
  int i;

  if (NULL == str)
  {
    return (NEW_DB_NULL);
  }
  if (DV_WIDESTRINGP (str))
    {
      len = box_length (str)/sizeof (wchar_t);
      res = dk_alloc_box (len * sizeof (wchar_t), DV_WIDE);
      for (i = 0; i < len; i++)
  ((wchar_t *)res)[i] = (wchar_t)unicode3_getucase((unichar)((wchar_t *)str)[i]);
      return res;
    }

  len = (box_length (str) - 1); /* box_length returns a length + 1 */
  res = dk_alloc_box (len + 1, DV_LONG_STRING);
  for (i = 0; i <= len; i++)
  {
    if (isISOletter (((unsigned char *) str)[i]))
  {
    (((unsigned char *) res)[i]) = raw_toupper (((unsigned char *) str)[i]);
  }
    else
  /* Otherwise, just copy the byte, whatever it is: */
  {
    (((unsigned char *) res)[i]) = (((unsigned char *) str)[i]);
  }
  }


  return res;
}


/* The name is from Oracle. Could be also capitalize or capit ? */
caddr_t
bif_initcap (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t str = bif_string_or_null_arg (qst, args, 0, "initcap");
  long len;
  caddr_t res;

  if (NULL == str)
  {
    return (NEW_DB_NULL);
  }

  len = (box_length (str)); /* box_length returns a length + 1 */

  res = dk_alloc_box (len, DV_LONG_STRING);
  memcpy (res, str, len); /* Copy the whole thing first. */

  /* Then, if the first letter needs converting, overwrite it: */
  if (isISOletter (*((unsigned char *) str)))
  {
    *((unsigned char *) res) = raw_toupper (*((unsigned char *) str));
  }

  return res;
}


/* ================================================================== */
/*  TYPE TESTING FUNCTIONS, ETC.            */
/* ================================================================== */


/* This is copied straight from cliuti.c which seems not to be included
   in the build of the Kubl server (WI.EXE)
   Constants referencing to SQL types has been replaced with corresponding
   integers, so we do not need to include sqlcli.h or sql.h or sqlext.h
   header files here. */
int
dv_to_sql_type_server_side (int dv)
{
  switch (dv)
    {
    case DV_SHORT_INT:
      return 5;
    case DV_LONG_INT:
      return 4;     /* SQL_INTEGER */
    case DV_DOUBLE_FLOAT:
      return 8;     /* SQL_DOUBLE */
    case DV_SINGLE_FLOAT:
      return 7;     /* SQL_REAL */
    case DV_NUMERIC:
    case DV_INT64:
      return 2;     /* SQL_DECIMAL */
    case DV_BLOB:
      return (-1);    /* SQL_LONGVARCHAR */
    case DV_BLOB_BIN:
      return (-4);    /* SQL_LONGVARBINARY */
    case DV_BLOB_WIDE:
      return (-10);   /* SQL_WLONGVARCHAR */
    case DV_BIN:
      return -3; /* SQL_VARBINARY */
    case DV_DATE:
      return 9;     /* SQL_DATE or SQL_DATETIME */
    case DV_TIMESTAMP:
      return cli_binary_timestamp ? -2 : 11;
    case DV_DATETIME:
      return 11;    /* SQL_TIMESTAMP */
    case DV_TIME:
      return 10;
    case DV_WIDE:
    case DV_LONG_WIDE:
      return -9;    /* SQL_WVARCHAR */
    default:
      return 12;    /* SQL_VARCHAR */
    }
}


caddr_t
bif_tag (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t x = bif_arg (qst, args, 0, "__tag");
  return (box_num (DV_TYPE_OF (x)));
}


caddr_t
bif_box_flags (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t x = bif_arg (qst, args, 0, "__box_flags");
  if (!IS_BOX_POINTER (x))
    return box_num (0);
  return (box_num (box_flags (x)));
}

caddr_t
bif_box_flags_set (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t x = bif_arg (qst, args, 0, "__box_flags_set");
  ptrlong flags = bif_long_arg (qst, args, 1, "__box_flags_set");
  if (!IS_BOX_POINTER (x))
    sqlr_new_error ("22023", "SR590", "__box_flags_set () can not handle integer as a first argument");
  box_flags (x) = flags;
  return (box_num (flags));
}

caddr_t
bif_box_flags_tweak (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t x = bif_arg (qst, args, 0, "__box_flags_tweak");
  ptrlong flags = bif_long_arg (qst, args, 1, "__box_flags_tweak");
  caddr_t res;
  if (!IS_BOX_POINTER (x))
    return x; /*was: sqlr_new_error ("22023", "SR589", "__box_flags_tweak () can not handle integer as a first argument");*/
  res = box_copy_tree (x);
  box_flags (res) = flags;
  return res;
}

/* The following three functions added 20.JAN.1997 by AK.
   Used by SQLColumns
   This one is more important than the next.  */
caddr_t
bif_dv_to_sql_type (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  long int type = (long) bif_long_arg (qst, args, 0, "internal_to_sql_type");
  type = dv_to_sql_type_server_side (type);
  return (box_num (type));
}

caddr_t
bif_dv_to_sql_type3 (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  long int type = (long) bif_long_arg (qst, args, 0, "internal_to_sql_type");
  type = dv_to_sql_type_server_side (type);
  switch (type) {
    case 9: type = 91; break;
    case 10:  type = 92; break;
    case 11:  type = 93; break;
  }

  return (box_num (type));
}

const char *
dv_type_title (int type)
{
  return DV_TYPE_TITLE (type);
}


int
dv_buffer_length (int type, int prec)
{
  switch (type)
    {
  case DV_BLOB: /* 125 */
  case DV_BLOB_BIN: /* 131 */
  case DV_BLOB_WIDE: /* 132 */
  case DV_BLOB_HANDLE: /* 126 */
  case DV_BLOB_WIDE_HANDLE: /* 133 */
  case DV_BLOB_XPER: /* 134 */
  case DV_BLOB_XPER_HANDLE: /* 135 */
  case DV_STRING_SESSION: /* 185 */
  case DV_ARRAY_OF_POINTER: /* 193 */
  case DV_ARRAY_OF_LONG: /* 194 */
  case DV_ARRAY_OF_DOUBLE: /* 195 */
  case DV_ARRAY_OF_FLOAT: /* 202 */
  case DV_ARRAY_OF_XQVAL:
  case DV_LIST_OF_POINTER: /* 196 */
  case DV_OBJECT_AND_CLASS: /* 197 */
  case DV_OBJECT_REFERENCE: /* 198 */
  case DV_MEMBER_POINTER: /* 200 */
  case DV_CUSTOM: /* 203 */
  case DV_XML_ENTITY: /* 230 */
  case DV_XML_DTD: /* 236 */
  case DV_OBJECT: /* 254 */
  case DV_ANY:
  case DV_REFERENCE:
    return 0x7FFFFFFF;
  case DV_SYMBOL: /* 127 */
  case DV_SHORT_CONT_STRING: /* 186 */
  case DV_LONG_CONT_STRING: /* 187 */
  case DV_STRING: /* 182 */
  case DV_C_STRING: /* 183 */
  case DV_CHARACTER: /* 192 */
    return ((prec > 0) ? prec : MAX_ROW_BYTES) + 1;
  case DV_WIDE: /* 225 */
  case DV_LONG_WIDE: /* 226 */
    return ((prec > 0) ? prec : MAX_ROW_BYTES) + 2;
  case DV_BIN:
    return ((prec > 0) ? prec : MAX_ROW_BYTES) * 2 + 1;
  case DV_TIMESTAMP:
    return 27;
  case DV_DATE: /* 129 */
    return 11;
  case DV_TIME:
    return 16;
  case DV_DATETIME:
    return 27;
  case DV_C_SHORT: /* 184 */
    return 4;
  case DV_SHORT_INT: /* 188 */
    return 4;
  case DV_LONG_INT: /* 189 */
    return 4;
  case DV_INT64:
    return 20; /* max 19 chars plus sign */
  case DV_SINGLE_FLOAT: /* 190 */
    return 10;
  case DV_DOUBLE_FLOAT: /* 191 */
    return 10;
  case DV_C_INT: /* 201 */
    return 4;
  case DV_NUMERIC:
    return ((prec < 10) ? 12 : (prec + 3));
  case DV_GAP1: /* 121 */
  case DV_SHORT_GAP: /* 121 */
  case DV_LONG_GAP: /* 123 */
  case DV_OWNER: /* 130 */
  case DV_NULL: /* 180 */
  case DV_DELETED: /* 199 */
  case DV_DB_NULL: /* 204 */
  case DV_PL_CURSOR: /* 234 */
  default:
    return 100; /* To fit an error mark */
  }
}


caddr_t
bif_any_grants (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  dbe_table_t * tb;
  caddr_t tb_name = bif_string_arg (qst, args, 0, "__any_grants");
  query_instance_t * qi = (query_instance_t *) qst;
  long op = GR_SELECT | GR_INSERT | GR_DELETE | GR_UPDATE | GR_REFERENCES;
  caddr_t col_name = NULL;

  if (QI_IS_DBA (qi))
    return (box_num (1));
  tb = qi_name_to_table (qi, tb_name);
  if (!tb)
    return (box_num (0));
  if (BOX_ELEMENTS (args) > 1)
    op = (long) bif_long_arg (qst, args, 1, "__any_grants");
  if (sec_tb_check (tb, qi->qi_u_id, qi->qi_g_id, op))
    return (box_num (1));
  if (BOX_ELEMENTS (args) > 2)
    col_name = bif_string_arg (qst, args, 2, "__any_grants");
  if (col_name)
    {
      dbe_column_t *col = tb_name_to_column (tb, col_name);
      if (!col || !sec_col_check (col, qi->qi_u_id, qi->qi_g_id, op))
  return box_num (0);
      else
  return box_num (1);
    }

  DO_SET (dbe_column_t *, col, &tb->tb_primary_key->key_parts)
    {
      if (sec_col_check (col, qi->qi_u_id, qi->qi_g_id, op))
  return (box_num (1));
    }
  END_DO_SET();
  return (box_num (0));
}


caddr_t
bif_any_grants_to_user (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  dbe_table_t * tb;
  caddr_t col_name = NULL;
  caddr_t tb_name = bif_string_arg (qst, args, 0, "__any_grants_to_user");
  caddr_t user_name = bif_string_or_null_arg (qst, args, 1, "__any_grants_to_user");
  long op = GR_SELECT | GR_INSERT | GR_DELETE | GR_UPDATE | GR_REFERENCES;
  query_instance_t * qi = (query_instance_t *) qst;
  oid_t u_g_id = (oid_t) -1, u_id = (oid_t) -1;
  user_t *user = user_name ? sec_name_to_user (user_name) : NULL;
  sec_check_dba (qi, "_any_grants_to_user");
  tb = qi_name_to_table (qi, tb_name);
  if (user)
  {
    u_id = user->usr_id;
    u_g_id = user->usr_g_id;
  }
  if (!tb)
  return (box_num (0));

  if (sec_user_has_group (0, u_id) || sec_user_has_group (0, u_g_id))
  return box_num (1);

  if (BOX_ELEMENTS (args) > 2)
  op = (long) bif_long_arg (qst, args, 2, "__any_grants_to_user");

  if (sec_tb_check (tb, u_id, u_g_id, op))
  return (box_num (1));

  if (BOX_ELEMENTS (args) > 3)
    col_name = bif_string_arg (qst, args, 3, "__any_grants_to_user");
  if (col_name)
    {
      dbe_column_t *col = tb_name_to_column (tb, col_name);
      if (!col || !sec_col_check (col, u_id, u_g_id, op))
  return box_num (0);
      else
  return box_num (1);
    }
  DO_SET (dbe_column_t *, col, &tb->tb_primary_key->key_parts)
  {
  if (sec_col_check (col, u_id, u_g_id, op))
    return (box_num (1));
  }
  END_DO_SET();
  return (box_num (0));
}


static id_hash_t *id_hash_system_tables = NULL;
#define SYSTEM_TABLE(_name) \
  name = box_dv_short_string (_name); \
  if (id_hash_get (id_hash_system_tables, (char *)&name)) \
    GPF_T1 ("table already defined as system table"); \
  id_hash_set (id_hash_system_tables, (char *)&name, (char *)&system_table)

static void
bif_fillup_system_tables_hash (void)
{
  caddr_t name, system_table = box_dv_short_string ("SYSTEM TABLE");
  id_hash_system_tables = id_str_hash_create (100);

  /* SQL server tables */
  SYSTEM_TABLE ("DB.DBA.SYS_ATTR");
  SYSTEM_TABLE ("DB.DBA.SYS_ATTR_META");
  SYSTEM_TABLE ("DB.DBA.SYS_DATA_SOURCE");
  SYSTEM_TABLE ("DB.DBA.SYS_D_STAT");
  SYSTEM_TABLE ("DB.DBA.SYS_ELEMENT_MAP");
  SYSTEM_TABLE ("DB.DBA.SYS_ELEMENT_TABLE");
  SYSTEM_TABLE ("DB.DBA.SYS_END");
  SYSTEM_TABLE ("DB.DBA.SYS_FOREIGN_KEYS");
  /*SYSTEM_TABLE ("DB.DBA.SYS_HTTP_MAP"); the old version of HTTP mappings, obsoleted in 3.0 */
  SYSTEM_TABLE ("DB.DBA.SYS_K_STAT");
  SYSTEM_TABLE ("DB.DBA.SYS_L_STAT");
  SYSTEM_TABLE ("DB.DBA.SYS_PASS_THROUGH_FUNCTION");
  SYSTEM_TABLE ("DB.DBA.SYS_REMOTE_TABLE");
  SYSTEM_TABLE ("DB.DBA.SYS_SCHEDULED_EVENT");
  SYSTEM_TABLE ("DB.DBA.SYS_SNAPSHOT");
  SYSTEM_TABLE ("DB.DBA.SYS_SNAPSHOT_LOG");
  SYSTEM_TABLE ("DB.DBA.SYS_TP_GRANT");
  SYSTEM_TABLE ("DB.DBA.SYS_TP_ITEM");
  SYSTEM_TABLE ("DB.DBA.SYS_USER_GROUP");
  SYSTEM_TABLE ("DB.DBA.SYS_VT_INDEX");
  SYSTEM_TABLE ("DB.DBA.SYS_INDEX_SPACE_STATS");
  SYSTEM_TABLE ("DB.DBA.REPL_ACCOUNTS");
  SYSTEM_TABLE ("DB.DBA.TP_ITEM");
  SYSTEM_TABLE ("DB.DBA.SYS_REMOTE_PROCEDURES");

  SYSTEM_TABLE ("SYS_CONSTRAINTS");
  SYSTEM_TABLE ("SYS_FREE_KEY_IDS");
  SYSTEM_TABLE ("SYS_FREE_RANGES");
  SYSTEM_TABLE ("SYS_GRANTS");
  SYSTEM_TABLE ("SYS_KEY_SUBKEY");
  SYSTEM_TABLE ("SYS_LAST_ID");
  SYSTEM_TABLE ("SYS_LOCAL_PREFIX");
  SYSTEM_TABLE ("SYS_PROCEDURES");
  SYSTEM_TABLE ("SYS_PROC_COLS");
  SYSTEM_TABLE ("SYS_REPL_ACCOUNTS");
  SYSTEM_TABLE ("SYS_SERVERS");
  SYSTEM_TABLE ("SYS_SUBTABLES");
  SYSTEM_TABLE ("SYS_TABLE_SUBTABLE");
  SYSTEM_TABLE ("SYS_TRIGGERS");
  SYSTEM_TABLE ("DB.DBA.SYS_USERS");
  SYSTEM_TABLE ("DB.DBA.SYS_ROLE_GRANTS");
  SYSTEM_TABLE ("SYS_VIEWS");
  SYSTEM_TABLE ("SYS_METHODS");
  SYSTEM_TABLE ("SYS_SQL_INVERSE");
  SYSTEM_TABLE ("DB.DBA.SYS_KEY_COLUMNS");
  SYSTEM_TABLE ("DB.DBA.SYS_LDAP_SERVERS");

  /* HTTP server virtual directory mappings */
  SYSTEM_TABLE ("DB.DBA.HTTP_PATH");
  SYSTEM_TABLE ("DB.DBA.HTTP_ACL");
  SYSTEM_TABLE ("DB.DBA.HTTP_PROXY_ACL");

  SYSTEM_TABLE ("WS.WS.SYS_RC_CACHE");
  SYSTEM_TABLE ("WS.WS.SYS_CACHEABLE");

  /* Admin interface table */
  SYSTEM_TABLE ("DB.DBA.ADMIN_SESSION");
  SYSTEM_TABLE ("DB.DBA.DEFINED_TYPES");
  SYSTEM_TABLE ("DB.DBA.CLASS_LIST");
  SYSTEM_TABLE ("DB.DBA.ADM_OPT_ARRAY_TO_RS_PVIEW");
  SYSTEM_TABLE ("DB.DBA.ADM_XML_VIEWS");
  SYSTEM_TABLE ("WS.WS.AUDIT_LOG");
  SYSTEM_TABLE ("DB.DBA.defined_types");
  SYSTEM_TABLE ("DB.DBA.class_list");

  /* News server tables  */
  SYSTEM_TABLE ("DB.DBA.NEWS_SERVERS");
  SYSTEM_TABLE ("DB.DBA.NEWS_GROUPS");
  SYSTEM_TABLE ("DB.DBA.NEWS_MSG");
  SYSTEM_TABLE ("DB.DBA.NEWS_MULTI_MSG");
  SYSTEM_TABLE ("DB.DBA.NEWS_ACL");
  SYSTEM_TABLE ("DB.DBA.NEWS_GROUPS_AVAILABLE");
  SYSTEM_TABLE ("DB.DBA.NEWS_MESSAGES");

  SYSTEM_TABLE ("DB.DBA.NEWS_MSG_NM_BODY_HIT");
  SYSTEM_TABLE ("DB.DBA.NEWS_MSG_NM_BODY_QUERY");
  SYSTEM_TABLE ("DB.DBA.NEWS_MSG_NM_BODY_USER");

  SYSTEM_TABLE ("DB.DBA.NEWS_MSG_NM_BODY_WORDS");
  SYSTEM_TABLE ("DB.DBA.VTLOG_DB_DBA_NEWS_MSG");

  /* Mail server tables  */
  SYSTEM_TABLE ("DB.DBA.MAIL_MESSAGE");
  SYSTEM_TABLE ("DB.DBA.MAIL_PARTS");

  /* SOAP datatypes table */
  SYSTEM_TABLE ("DB.DBA.SYS_SOAP_DATATYPES");
  SYSTEM_TABLE ("DB.DBA.SYS_SOAP_UDT_PUB");

  SYSTEM_TABLE ("DB.DBA.MAIL_MESSAGE_MM_BODY_HIT");
  SYSTEM_TABLE ("DB.DBA.MAIL_MESSAGE_MM_BODY_QUERY");
  SYSTEM_TABLE ("DB.DBA.MAIL_MESSAGE_MM_BODY_USER");

  SYSTEM_TABLE ("DB.DBA.MAIL_MESSAGE_MM_BODY_WORDS");
  SYSTEM_TABLE ("DB.DBA.VTLOG_DB_DBA_MAIL_MESSAGE");

  /* WebBot tables */
  SYSTEM_TABLE ("WS.WS.VFS_QUEUE");
  SYSTEM_TABLE ("WS.WS.VFS_SITE");
  SYSTEM_TABLE ("WS.WS.VFS_URL");

  /* DAV tables */
  SYSTEM_TABLE ("WS.WS.SYS_DAV_COL");
  SYSTEM_TABLE ("WS.WS.SYS_DAV_GROUP");
  SYSTEM_TABLE ("WS.WS.SYS_DAV_LOCK");
  SYSTEM_TABLE ("WS.WS.SYS_DAV_PROP");
  SYSTEM_TABLE ("WS.WS.SYS_DAV_RES");
  SYSTEM_TABLE ("WS.WS.SYS_DAV_RES_CONTENT_HIT");
  SYSTEM_TABLE ("WS.WS.SYS_DAV_RES_CONTENT_QUERY");
  SYSTEM_TABLE ("WS.WS.SYS_DAV_RES_CONTENT_USER");
  SYSTEM_TABLE ("WS.WS.SYS_DAV_RES_CONTENT_WORDS");
  SYSTEM_TABLE ("WS.WS.SYS_DAV_RES_TYPES");
  SYSTEM_TABLE ("WS.WS.SYS_DAV_USER");
  SYSTEM_TABLE ("WS.WS.SYS_DAV_USER_GROUP");

  SYSTEM_TABLE ("WS.WS.SYS_DAV_RES_RES_CONTENT_HIT");
  SYSTEM_TABLE ("WS.WS.SYS_DAV_RES_RES_CONTENT_QUERY");
  SYSTEM_TABLE ("WS.WS.SYS_DAV_RES_RES_CONTENT_USER");

  SYSTEM_TABLE ("WS.WS.SYS_DAV_RES_RES_CONTENT_WORDS");
  SYSTEM_TABLE ("WS.WS.VTLOG_WS_WS_SYS_DAV_RES");
  SYSTEM_TABLE ("DB.DBA.DAV_DIR");

  /* XPATH extension functions */
  SYSTEM_TABLE ("DB.DBA.SYS_XPF_EXTENSIONS");

  /* Old style XML tables */
  SYSTEM_TABLE ("DB.DBA.VXML_DOCUMENT");
  SYSTEM_TABLE ("DB.DBA.VXML_ENTITY");
  SYSTEM_TABLE ("DB.DBA.VXML_TEXT_FRAGMENT");

  /* CLR access restrictions */
  SYSTEM_TABLE ("DB.DBA.CLR_VAC");

  /* cached resources */
  SYSTEM_TABLE ("DB.DBA.SYS_CACHED_RESOURCES");

  /* replication tables */
  SYSTEM_TABLE ("DB.DBA.SYS_DAV_CR");
  SYSTEM_TABLE ("DB.DBA.SYS_REPL_CR");
  SYSTEM_TABLE ("DB.DBA.SYS_REPL_POSTPONED_RES");
  SYSTEM_TABLE ("DB.DBA.SYS_REPL_SUBSCRIBERS");
  SYSTEM_TABLE ("WS.WS.RLOG_SYS_DAV_RES");
  SYSTEM_TABLE ("WS.WS.RPLOG_SYS_DAV_RES");
  SYSTEM_TABLE ("DB.DBA.SYS_SNAPSHOT_CR");
  SYSTEM_TABLE ("DB.DBA.SYS_SNAPSHOT_PUB");
  SYSTEM_TABLE ("DB.DBA.SYS_SNAPSHOT_SUB");

  /* Blog tables */
  SYSTEM_TABLE ("DB.DBA.BLOG_COMMENTS");
  SYSTEM_TABLE ("DB.DBA.MAIL_ATTACHMENT");
  SYSTEM_TABLE ("DB.DBA.MSG_SPAMS_COUNT");
  SYSTEM_TABLE ("DB.DBA.MSG_WORDS");
  SYSTEM_TABLE ("DB.DBA.MTYPE_BLOG_CATEGORY");
  SYSTEM_TABLE ("DB.DBA.MTYPE_CATEGORIES");
  SYSTEM_TABLE ("DB.DBA.MTYPE_TRACKBACK_PINGS");
  SYSTEM_TABLE ("DB.DBA.SYS_BLOGS");
  SYSTEM_TABLE ("DB.DBA.SYS_BLOGS_B_CONTENT_WORDS");
  SYSTEM_TABLE ("DB.DBA.SYS_BLOGS_ROUTING_LOG");
  SYSTEM_TABLE ("DB.DBA.SYS_BLOG_CHANNELS");
  SYSTEM_TABLE ("DB.DBA.SYS_BLOG_CHANNEL_FEEDS");
  SYSTEM_TABLE ("DB.DBA.SYS_BLOG_CHANNEL_INFO");
  SYSTEM_TABLE ("DB.DBA.SYS_BLOG_CLOUD_NOTIFICATION");
  SYSTEM_TABLE ("DB.DBA.SYS_BLOG_CONTACTS");
  SYSTEM_TABLE ("DB.DBA.SYS_BLOG_DOMAINS");
  SYSTEM_TABLE ("DB.DBA.SYS_BLOG_INFO");
  SYSTEM_TABLE ("DB.DBA.SYS_BLOG_REFFERALS");
  SYSTEM_TABLE ("DB.DBA.SYS_BLOG_VISITORS");
  SYSTEM_TABLE ("DB.DBA.SYS_BLOG_WEBLOG_HOSTS");
  SYSTEM_TABLE ("DB.DBA.SYS_BLOG_WEBLOG_PING");
  SYSTEM_TABLE ("DB.DBA.SYS_ROUTING");
  SYSTEM_TABLE ("DB.DBA.SYS_ROUTING_PROTOCOL");
  SYSTEM_TABLE ("DB.DBA.SYS_ROUTING_TYPE");
  SYSTEM_TABLE ("DB.DBA.SYS_WEBLOG_UPDATES_PINGS");
  SYSTEM_TABLE ("DB.DBA.VSPX_CUSTOM_CONTROL");
  SYSTEM_TABLE ("DB.DBA.VTLOG_DB_DBA_SYS_BLOGS");
  SYSTEM_TABLE ("DB.DBA.SYS_BLOGS_B_CONTENT_HIT");
  SYSTEM_TABLE ("DB.DBA.SYS_BLOGS_B_CONTENT_QUERY");
  SYSTEM_TABLE ("DB.DBA.SYS_BLOGS_B_CONTENT_USER");
  SYSTEM_TABLE ("DB.DBA.SYS_BLOG_CHANNEL_CATEGORY");
  SYSTEM_TABLE ("DB.DBA.SYS_BLOG_SEARCH_ENGINE");
  SYSTEM_TABLE ("DB.DBA.SYS_BLOG_SEARCH_ENGINE_SETTINGS");
  SYSTEM_TABLE ("DB.DBA.BLOG_USERS_BLOGS");
  SYSTEM_TABLE ("DB.DBA.BLOG_RSS_FEEDS");
  SYSTEM_TABLE ("DB.DBA.SYS_BLOG_DOMAIN_INFO");
  SYSTEM_TABLE ("DB.DBA.BLOG_CHANNELS");

  /* WS Referrals cache */
  SYSTEM_TABLE ("DB.DBA.WS_REFERRALS");

  /* VSPX tables */
  SYSTEM_TABLE ("DB.DBA.VSPX_APP_COL_STYLES");
  SYSTEM_TABLE ("DB.DBA.VSPX_APP_MODELS");
  SYSTEM_TABLE ("DB.DBA.VSPX_SESSION");
  SYSTEM_TABLE ("DB.DBA.VSPX_STYLES");


  /* VAD tables */
  SYSTEM_TABLE ("PUMP.DBA.DBPUMP_HELP");
  SYSTEM_TABLE ("VAD.DBA.VAD_HELP");
  SYSTEM_TABLE ("VAD.DBA.VAD_LOG");
  SYSTEM_TABLE ("VAD.DBA.VAD_REGISTRY");

  SYSTEM_TABLE ("WS.WS.HTTP_SES_TRAP_DISABLE");
  SYSTEM_TABLE ("WS.WS.SESSION");
  SYSTEM_TABLE ("_2PC.DBA.TRANSACTIONS");

  /*UDDI tables*/
  SYSTEM_TABLE ("UDDI.DBA.ADDRESS_LINE");
  SYSTEM_TABLE ("UDDI.DBA.BINDING_TEMPLATE");
  SYSTEM_TABLE ("UDDI.DBA.BUSINESS_ENTITY");
  SYSTEM_TABLE ("UDDI.DBA.BUSINESS_SERVICE");
  SYSTEM_TABLE ("UDDI.DBA.CATEGORY_BAG");
  SYSTEM_TABLE ("UDDI.DBA.CONTACTS");
  SYSTEM_TABLE ("UDDI.DBA.DESCRIPTION");
  SYSTEM_TABLE ("UDDI.DBA.DISCOVERY_URL");
  SYSTEM_TABLE ("UDDI.DBA.EMAIL");
  SYSTEM_TABLE ("UDDI.DBA.IDENTIFIER_BAG");
  SYSTEM_TABLE ("UDDI.DBA.INSTANCE_DETAIL");
  SYSTEM_TABLE ("UDDI.DBA.OVERVIEW_DOC");
  SYSTEM_TABLE ("UDDI.DBA.PHONE");
  SYSTEM_TABLE ("UDDI.DBA.TMODEL");

  /* SQL statistics tables */
  SYSTEM_TABLE ("DB.DBA.SYS_COL_STAT");
  SYSTEM_TABLE ("DB.DBA.SYS_COL_HIST");
  SYSTEM_TABLE ("DB.DBA.SYS_STAT_VDB_MAPPERS");
  SYSTEM_TABLE ("DB.DBA.ALL_COL_STAT");
  SYSTEM_TABLE ("DB.DBA.USER_COL_STAT");
  SYSTEM_TABLE ("DB.DBA.ALL_COL_HIST");
  SYSTEM_TABLE ("DB.DBA.USER_COL_HIST");

  /* RLS table */
  SYSTEM_TABLE ("DB.DBA.SYS_RLS_POLICY");

  /* SyncML tables */
  SYSTEM_TABLE ("DB.DBA.SYNC_ANCHORS");
  SYSTEM_TABLE ("DB.DBA.SYNC_DEVICES");
  SYSTEM_TABLE ("DB.DBA.SYNC_MAPS");
  SYSTEM_TABLE ("DB.DBA.SYNC_RPLOG");
  SYSTEM_TABLE ("DB.DBA.SYNC_SESSION");

  /* WS-RM */
  SYSTEM_TABLE ("DB.DBA.SYS_WSRM_IN_MESSAGE_LOG");
  SYSTEM_TABLE ("DB.DBA.SYS_WSRM_IN_SEQUENCES");
  SYSTEM_TABLE ("DB.DBA.SYS_WSRM_OUT_MESSAGE_LOG");
  SYSTEM_TABLE ("DB.DBA.SYS_WSRM_OUT_SEQUENCES");

  /* WS Trust */
  SYSTEM_TABLE ("DB.DBA.WST_SERVER_ISSUER_TOKENS");

  /* Online backup */
  SYSTEM_TABLE ("DB.DBA.SYS_BACKUP_DIRS");
}


caddr_t
bif_table_type (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t tb = bif_string_arg (qst, args, 0, "table_type");
  caddr_t *type;
  query_instance_t *qi = (query_instance_t *)qst;

  if (!qi->qi_client->cli_no_system_tables)
    {
      type = (caddr_t *) id_hash_get (id_hash_system_tables, (caddr_t) &tb);
      if (type)
  return box_copy (*type);
    }

  if (sch_view_def (isp_schema (((query_instance_t *) qst)->qi_space), tb))
    return (box_dv_short_string ("VIEW"));

  return (box_dv_short_string ("TABLE"));
}


caddr_t
bif_dv_type_title (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  long int type = (long) bif_long_arg (qst, args, 0, "internal_type_name");
  const char *s = dv_type_title (type);
  return (box_dv_short_string (s));
}


caddr_t
bif_dv_buffer_length (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  long int type = (long) bif_long_arg (qst, args, 0, "dv_buffer_length");
  long int prec = (long) bif_long_arg (qst, args, 1, "dv_buffer_length");
  int len = dv_buffer_length (type, prec);
  return box_num(len);
}


caddr_t
bif_internal_type (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg1 = bif_arg (qst, args, 0, "internal_type");

  dtp_t dtp = DV_TYPE_OF (arg1);
  return (box_num (dtp));
}


caddr_t
bif_isblob_handle (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg1 = bif_arg (qst, args, 0, "isblob");
  int result;

  dtp_t dtp = DV_TYPE_OF (arg1);
  switch (dtp)
  {
  case DV_BLOB_HANDLE:  /* What else? */
  case DV_BLOB_XPER_HANDLE:
  case DV_BLOB_WIDE_HANDLE:
    {
  result = 1;
  break;
    }
  default:
    {
  result = 0;
  break;
    }
  }

  return (box_num (result));
}


caddr_t
bif_isentity (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg0 = bif_arg (qst, args, 0, "isentity");
  return box_bool (DV_XML_ENTITY == DV_TYPE_OF (arg0));
}


caddr_t
bif_isinteger (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg1 = bif_arg (qst, args, 0, "isinteger");
  int result;

  dtp_t dtp = DV_TYPE_OF (arg1);
  switch (dtp)
  {
  case DV_SHORT_INT:
  case DV_LONG_INT:
  case DV_C_SHORT:    /* These are  */
  case DV_C_INT:    /*  not needed? Or no? */
    {
  result = 1;
  break;
    }
  default:
    {
  result = 0;
  break;
    }
  }

  return (box_num (result));
}


/* Either a sort of integer or a sort of float or double. */
caddr_t
bif_isnumeric (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg1 = bif_arg (qst, args, 0, "isnumeric");
  int result;

  dtp_t dtp = DV_TYPE_OF (arg1);
  switch (dtp)
  {
  case DV_SHORT_INT:
  case DV_LONG_INT:
  case DV_C_SHORT:    /* These are  */
  case DV_C_INT:    /*  not needed? Or no? */
  case DV_SINGLE_FLOAT:
  case DV_DOUBLE_FLOAT:
  case DV_NUMERIC:
    {
  result = 1;
  break;
    }
  default:
    {
  result = 0;
  break;
    }
  }

  return (box_num (result));
}

caddr_t
bif_isfinitenumeric (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg1 = bif_arg (qst, args, 0, "isfinitenumeric");
  int result;

  dtp_t dtp = DV_TYPE_OF (arg1);
  switch (dtp)
  {
  case DV_SHORT_INT:
  case DV_LONG_INT:
  case DV_C_SHORT:    /* These are  */
  case DV_C_INT:    /*  not needed? Or no? */
    result = 1;
    break;
  case DV_SINGLE_FLOAT:
    {
      float val = unbox_float (arg1);
#ifdef isfinite
      result = (isfinite(val) ? 1 : 0);
#elif WIN32
      result = _finite (val) ? 1 : 0;
#else
      float myNAN_f = 0.0/0.0;
      float myPOSINF_f = 1.0/0.0;
      float myNEGINF_f = -1.0/0.0;
      result = (((val == myNAN_f) || (val == myPOSINF_f) || (val == myNEGINF_f)) ? 0 : 1);
#endif
      break;
    }
  case DV_DOUBLE_FLOAT:
    {
      double val = unbox_double (arg1);
#ifdef isfinite
      result = (isfinite(val) ? 1 : 0);
#elif WIN32
      result = _finite (val) ? 1 : 0;
#else
      double myNAN_d = 0.0/0.0;
      double myNEGNAN_d = -0.0/0.0;
      double myPOSINF_d = 1.0/0.0;
      double myNEGINF_d = -1.0/0.0;
      result = (((val == myNAN_d) || (val == myNEGNAN_d) || (val == myPOSINF_d) || (val == myNEGINF_d)) ? 0 : 1);
#endif
      break;
    }
  case DV_NUMERIC:
    {
      numeric_t val = (numeric_t)arg1;
      result = (num_is_invalid(val) ? 0 : 1);
      break;
    }
  default:
    result = 0;
    break;
  }

  return (box_num (result));
}

/* Is arg a single float? */
caddr_t
bif_isfloat (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg0 = bif_arg (qst, args, 0, "isfloat");
  return box_bool (DV_SINGLE_FLOAT == DV_TYPE_OF (arg0));
}

/* Is arg a double? */
caddr_t
bif_isdouble (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg0 = bif_arg (qst, args, 0, "isdouble");
  return box_bool (DV_DOUBLE_FLOAT == DV_TYPE_OF (arg0));
}


caddr_t
bif_isnull (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg0 = bif_arg (qst, args, 0, "isnull");
  return box_bool (DV_DB_NULL == DV_TYPE_OF (arg0));
}


void
bif_isnotnull_vec (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, state_slot_t * ret)
{
  data_col_t * dc, * arg;
  QNCAST (query_instance_t, qi, qst);
  db_buf_t set_mask = qi->qi_set_mask;
  int set, n_sets = qi->qi_n_sets, first_set = 0;
  int inx;
  state_slot_t * ssl = args[0];
  if (!ret)
    return;
  dc = QST_BOX (data_col_t *, qst, ret->ssl_index);
  if (BOX_ELEMENTS (args) < 1)
    sqlr_new_error ("42001", "VEC..", "Not enough arguments for is_no_null");
  DC_CHECK_LEN (dc, qi->qi_n_sets - 1);
  arg = QST_BOX (data_col_t *, qst, ssl->ssl_index);
  if (!arg->dc_any_null || ssl->ssl_sqt.sqt_non_null)
    {
      if (!qi->qi_set_mask && (DCT_NUM_INLINE & dc->dc_type))
	{
	  for (inx = 0; inx < qi->qi_n_sets; inx++)
	    ((int64*)dc->dc_values)[inx] = 1;
	  if (dc->dc_nulls)
	    memset (dc->dc_nulls, 0, ALIGN_8 (qi->qi_n_sets) / 8);
	  dc->dc_n_values = qi->qi_n_sets;
	  return;
	}
      else
	{
	  SET_LOOP
	    {
	      dc_set_long (dc, set, 1);
	    }
	  END_SET_LOOP;
	}
      return;
    }
  SET_LOOP
    {
      int row_no = set;
      if (SSL_REF == ssl->ssl_type)
	row_no = sslr_set_no (qst, ssl, row_no);
      if (DCT_BOXES & arg->dc_type)
	dc_set_long (dc, set, DV_DB_NULL != DV_TYPE_OF (((caddr_t*)arg->dc_values)[row_no]));
      else if (DV_ANY == arg->dc_dtp)
	dc_set_long (dc, set, DV_DB_NULL != ((db_buf_t*)arg->dc_values)[row_no][0]);
      else
	dc_set_long (dc, set, DC_IS_NULL (arg, row_no) ? 0 : 1);
    }
  END_SET_LOOP;
}


caddr_t
bif_isnotnull (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg0 = bif_arg (qst, args, 0, "isnotnull");
  return box_bool (DV_DB_NULL != DV_TYPE_OF (arg0));
}

caddr_t
bif_isstring (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg0 = bif_arg (qst, args, 0, "isstring");
  return box_bool (DV_STRING == DV_TYPE_OF (arg0));
}

caddr_t
bif_isstring_session (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg0 = bif_arg (qst, args, 0, "isstring_session");
  return box_bool (DV_STRING_SESSION == DV_TYPE_OF (arg0));
}

caddr_t
bif_isbinary (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg0 = bif_arg (qst, args, 0, "isbinary");
  return box_bool (DV_BIN == DV_TYPE_OF (arg0));
}


caddr_t
bif_isarray (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg1 = bif_arg (qst, args, 0, "isarray");
  int result;

  dtp_t dtp = DV_TYPE_OF (arg1);
  switch (dtp)
  {
  case DV_ARRAY_OF_POINTER: case DV_LIST_OF_POINTER: case DV_ARRAY_OF_XQVAL:
  case DV_ARRAY_OF_LONG:
  case DV_ARRAY_OF_LONG_PACKED:
  case DV_ARRAY_OF_FLOAT:
  case DV_ARRAY_OF_DOUBLE:
  case DV_STRING:
    {
  result = 1;
  break;
    }
  default:
    {
  result = 0;
  break;
    }
  }
  return (box_num (result));
}

caddr_t
bif_isvector (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg0 = bif_arg (qst, args, 0, "isvector");
  return box_bool (DV_ARRAY_OF_POINTER == DV_TYPE_OF (arg0));
}

caddr_t
bif_isuname (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg0 = bif_arg (qst, args, 0, "isuname");
  return box_bool (DV_UNAME == DV_TYPE_OF (arg0));
}


caddr_t
bif_isiri_id (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg0 = bif_arg (qst, args, 0, "isiri_id");
  return box_bool (DV_IRI_ID == DV_TYPE_OF (arg0));
}

caddr_t
bif_is_named_iri_id (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg0 = bif_arg (qst, args, 0, "is_named_iri_id");
  iri_id_t iid;
  if (DV_IRI_ID != DV_TYPE_OF (arg0))
    return box_bool (0);
  iid = unbox_iri_id (arg0);
  return box_bool (iid < min_bnode_iri_id());
}

caddr_t
bif_is_bnode_iri_id (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg0 = bif_arg (qst, args, 0, "is_bnode_iri_id");
  iri_id_t iid;
  if (DV_IRI_ID != DV_TYPE_OF (arg0))
    return box_bool (0);
  iid = unbox_iri_id (arg0);
  return box_bool (iid >= min_bnode_iri_id());
}

caddr_t
bif_iri_id_num (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  iri_id_t iri_id = bif_iri_id_arg (qst, args, 0, "iri_id_num");
  return box_num (iri_id);
}

caddr_t
bif_iri_id_from_num (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  iri_id_t arg = bif_iri_id_or_long_arg (qst, args, 0, "iri_id_from_num");
  return box_iri_id (arg);
}

caddr_t
bif_set_64bit_min_bnode_iri_id (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  sec_check_dba ((query_instance_t *)qst, "__set_64bit_min_bnode_iri_id");
  /*bnode_iri_ids_are_huge = 1; */
  return NEW_DB_NULL;
}

caddr_t
bif_min_bnode_iri_id (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return box_iri_id (min_bnode_iri_id());
}

caddr_t
bif_max_bnode_iri_id (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return box_iri_id (max_bnode_iri_id());
}

caddr_t
bif_min_named_bnode_iri_id (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return box_iri_id (min_named_bnode_iri_id());
}

caddr_t
bif_iri_id_bnode32_to_bnode64 (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg0 = bif_arg (qst, args, 0, "iri_id_bnode32_to_bnode64");
  iri_id_t iid;
  if (DV_IRI_ID != DV_TYPE_OF (arg0))
    return box_copy_tree (arg0);
  iid = unbox_iri_id (arg0);
  if (iid < MIN_32BIT_BNODE_IRI_ID)
    return box_iri_id (iid);
  if (iid >= MIN_64BIT_BNODE_IRI_ID)
    sqlr_new_error ("22012", "SR563", "64 bit bnode IRI ID is not a valid argument of iri_id_bnode32_to_bnode64() function");
  if (iid < MIN_32BIT_NAMED_BNODE_IRI_ID)
    return box_iri_id (iid + (MIN_64BIT_BNODE_IRI_ID - MIN_32BIT_BNODE_IRI_ID));
  return box_iri_id (iid + (MIN_64BIT_NAMED_BNODE_IRI_ID - MIN_32BIT_NAMED_BNODE_IRI_ID));
}

caddr_t
bif_min_32bit_bnode_iri_id (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return box_iri_id (MIN_32BIT_BNODE_IRI_ID);
}

caddr_t
bif_min_32bit_named_bnode_iri_id (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return box_iri_id (MIN_32BIT_NAMED_BNODE_IRI_ID);
}

caddr_t
bif_min_64bit_bnode_iri_id (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return box_iri_id (MIN_64BIT_BNODE_IRI_ID);
}

caddr_t
bif_min_64bit_named_bnode_iri_id (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return box_iri_id (MIN_64BIT_NAMED_BNODE_IRI_ID);
}

caddr_t
bif_all_eq (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int inx;
  caddr_t first = bif_arg (qst, args, 0, "__all_eq");
  for (inx = 1; inx < BOX_ELEMENTS_INT (args); inx++)
  {
    collation_t * coll = args[0]->ssl_sqt.sqt_collation;
    if (DVC_MATCH != cmp_boxes (first, bif_arg (qst, args, inx, "__all_eq"), coll, coll))
  return (dk_alloc_box (0, DV_DB_NULL));
  }
  return (box_copy_tree (first));
}

caddr_t
bif_max (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int inx;
  caddr_t best = bif_arg (qst, args, 0, "__max");
  collation_t * coll = args[0]->ssl_sqt.sqt_collation;
  for (inx = 1; inx < BOX_ELEMENTS_INT (args); inx++)
    {
      caddr_t a = bif_arg (qst, args, inx, "__max");
      if (DVC_GREATER == cmp_boxes (a, best, coll, coll))
        best = a;
    }
  return (box_copy_tree (best));
}


caddr_t
bif_min (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int inx;
  caddr_t best = bif_arg (qst, args, 0, "__min");
  collation_t * coll = args[0]->ssl_sqt.sqt_collation;
  for (inx = 1; inx < BOX_ELEMENTS_INT (args); inx++)
    {
      caddr_t a = bif_arg (qst, args, inx, "__min");
      if (DVC_LESS == cmp_boxes (a, best, coll, coll))
        best = a;
    }
  return (box_copy_tree (best));
}


caddr_t
bif_max_notnull (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int notnull_found = 0;
  int inx;
  caddr_t best = NULL;
  collation_t * coll = NULL;
  for (inx = 0; inx < BOX_ELEMENTS_INT (args); inx++)
    {
      caddr_t a = bif_arg (qst, args, inx, "__max_notnull");
      if (DV_DB_NULL == DV_TYPE_OF (a))
        continue;
      if (!notnull_found)
        {
          coll = args[0]->ssl_sqt.sqt_collation;
          best = a;
          notnull_found = 1;
        }
      else if (DVC_GREATER == cmp_boxes (a, best, coll, coll))
        best = a;
    }
  if (notnull_found)
    return (box_copy_tree (best));
  return NEW_DB_NULL;
}


caddr_t
bif_min_notnull (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int notnull_found = 0;
  int inx;
  caddr_t best = NULL;
  collation_t * coll = NULL;
  for (inx = 0; inx < BOX_ELEMENTS_INT (args); inx++)
    {
      caddr_t a = bif_arg (qst, args, inx, "__min_notnull");
      if (DV_DB_NULL == DV_TYPE_OF (a))
        continue;
      if (!notnull_found)
        {
          coll = args[0]->ssl_sqt.sqt_collation;
          best = a;
          notnull_found = 1;
        }
      else if (DVC_LESS == cmp_boxes (a, best, coll, coll))
        best = a;
    }
  if (notnull_found)
    return (box_copy_tree (best));
  return NEW_DB_NULL;
}


/* This function works a little bit like the ternary operator
   (arg1 ? arg2 : arg3) of the C-language, or the form (if arg1 arg2 arg3)
   of the Common Lisp. That is, if the first argument is zero
   (or NULL, but NOT ANYMORE), then the third argument (else-part)
   is returned, otherwise the second (then-part) is returned.

   However, all arguments are always evaluated (also the one which is
   not selected), and copy is made of the selected argument in case
   it's a true box or tree of boxes. (Because of the inherent limitation
   mentioned in the beginning notes of this module.)

   Hmm, what about a lazy evaluation model, where the argument of
   bif function is not evaluated before it is fetched with bif_arg ???

   Important change 27-FEB-1997 by AK. Doesn't check for NULL anymore,
   that is, if argument is NULL, then the second "THEN" argument is
   copied. Use either(isnull(X),'Yes it is NULL','Not NULL') if you
   want to check for NULL.
 */
caddr_t
bif_either (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg1 = bif_arg (qst, args, 0, "either");
  int condition = 0;

  dtp_t dtp = DV_TYPE_OF (arg1);
  switch (dtp)
  {
/*  case DV_DB_NULL: { condition = 0; break; }  Commented OUT 27-FEB-97 */
  case DV_SHORT_INT:
  case DV_LONG_INT:
  case DV_CHARACTER:
  case DV_C_SHORT:    /* These are  */
  case DV_C_INT:    /*  not needed? */
    condition = (unbox (arg1) != 0);
    break;

  default:
    /* Anything else, e.g. strings, means that condition is yes. */
    condition = 1;
    break;
  }

  /* Depending whether condition is non-zero or zero, we return either
  the second or the third argument back, copied */
  return (box_copy_tree (bif_arg (qst, args, (condition ? 1 : 2), "either")));
}


/* Simplified form of the above one, by AK 29-OCT-1997.
   If the first argument is non-NULL,
   then return (a copy of) it, otherwise, return (a copy of) the
   second argument.
   As with above one, here the second argument is unnecessarily
   evaluated every time, which is probably against what the
   standard intends, and furthermore, copies are made unnecessarily.
   We really need to implement these two functions better than this.  */
caddr_t
bif_ifnull (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg1 = bif_arg (qst, args, 0, "ifnull");
  int is_null = 0;
  dtp_t dtp = DV_TYPE_OF (arg1);
  if (DV_DB_NULL == dtp)
  {
    is_null = 1;
  }

  /* Depending whether is_null is non-zero or zero, we return either
  the second or the first argument back, copied: */
  return (box_copy_tree (bif_arg (qst, args, is_null, "ifnull")));
}

caddr_t
bif_and (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int argctr, argcount = BOX_ELEMENTS (args);
  for (argctr = 0; argctr < argcount; argctr++)
    {
      caddr_t arg = bif_arg_nochecks(qst,args,argctr);
      dtp_t dtp = DV_TYPE_OF (arg);
      switch (dtp)
        {
        case DV_DB_NULL: return NEW_DB_NULL;
        case DV_SHORT_INT:
        case DV_LONG_INT:
        case DV_CHARACTER:
        case DV_C_SHORT:    /* These are  */
        case DV_C_INT:    /*  not needed? */
          if (0 == unbox (arg))
	    return 0;
        }
    }
  return (caddr_t)((ptrlong)(1));
}

caddr_t
bif_or (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int argctr, argcount = BOX_ELEMENTS (args);
  for (argctr = 0; argctr < argcount; argctr++)
    {
      caddr_t arg = bif_arg_nochecks(qst,args,argctr);
      dtp_t dtp = DV_TYPE_OF (arg);
      switch (dtp)
        {
        case DV_DB_NULL: return NEW_DB_NULL;
        case DV_SHORT_INT:
        case DV_LONG_INT:
        case DV_CHARACTER:
        case DV_C_SHORT:    /* These are  */
        case DV_C_INT:    /*  not needed? */
          if (0 == unbox (arg))
            continue;
        /* no break */
        default: return (caddr_t)((ptrlong)(1));
        }
    }
  return 0;
}

caddr_t
bif_transparent_or (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int argctr, argcount = BOX_ELEMENTS (args);
  for (argctr = 0; argctr < argcount; argctr++)
    {
      caddr_t arg = bif_arg_nochecks(qst,args,argctr);
      dtp_t dtp = DV_TYPE_OF (arg);
      switch (dtp)
        {
        case DV_DB_NULL: return NEW_DB_NULL;
        case DV_SHORT_INT:
        case DV_LONG_INT:
        case DV_CHARACTER:
        case DV_C_SHORT:    /* These are  */
        case DV_C_INT:    /*  not needed? */
          if (0 == unbox (arg))
            continue;
        /* no break */
        default: return box_copy_tree (arg);
        }
    }
  return (caddr_t)0;
}

caddr_t
bif_not (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg1 = bif_arg (qst, args, 0, "not");
  dtp_t dtp;

retry_unrdf:
  dtp = DV_TYPE_OF (arg1);
  switch (dtp)
    {
    case DV_DB_NULL: return NEW_DB_NULL;
    case DV_SHORT_INT:
    case DV_LONG_INT:
    case DV_CHARACTER:
    case DV_C_SHORT:    /* These are  */
    case DV_C_INT:    /*  not needed? */
      return (caddr_t)((ptrlong)((0 == unbox (arg1)) ? 1 : 0));
    case DV_RDF:
      arg1 = ((rdf_box_t *)arg1)->rb_box;
      goto retry_unrdf;
    default:
      return 0;
  }
}

/* ================================================================== */
/*  COMPARISON FUNCTIONS FOR NUMERIC ARGUMENTS, ETC.      */
/* ================================================================== */


/*
   cmp_boxes has been defined in arith.c
   The macro GENERAL_COMPARISON_FUNC was inspired by similar
   macro ARTM_BIN_FUNC in arith.c
   Maybe mod could be implemented there by giving
   a macro call like ARTM_BIN_FUNC (box_mod, %, 1)
   there.
 */

#define GENERAL_COMPARISON_FUNC(name, namestr, comp_op, comp_val) \
caddr_t name (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)\
{\
  caddr_t arg1 = bif_arg (qst, args, 0, namestr);\
  caddr_t arg2 = bif_arg (qst, args, 1, namestr);\
  if (comp_val comp_op cmp_boxes(arg1,arg2,args[0]->ssl_sqt.sqt_collation,args[1]->ssl_sqt.sqt_collation)) \
  return (box_num(1)); \
  else \
  return (box_num(0));\
}


GENERAL_COMPARISON_FUNC (bif_lt, "lt", ==, DVC_LESS)
GENERAL_COMPARISON_FUNC (bif_gte, "gte", !=, DVC_LESS)
GENERAL_COMPARISON_FUNC (bif_gt, "gt", ==, DVC_GREATER)
GENERAL_COMPARISON_FUNC (bif_lte, "lte", !=, DVC_GREATER)
GENERAL_COMPARISON_FUNC (bif_equ, "equ", ==, DVC_MATCH)
GENERAL_COMPARISON_FUNC (bif_neq, "neq", !=, DVC_MATCH)



/* Returns 1 if the argument is an integral number which is zero,
   and 0 if it is an integral number with any other value.
   If the argument is anything else, zero is returned.
   AK 15-JAN-1997.
   Now returns 1 also for single and double floating point 0.0
   AK 21-FEB-1997.

   Similarly would be useful isless, isgreater, isinteger, isstring, etc.
   (Or what about Lisp-like names: zerop,lessp,greaterp,integerp,stringp?)
 */
caddr_t
bif_iszero (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg = bif_arg (qst, args, 0, "iszero");
  dtp_t dtp = DV_TYPE_OF (arg);
  switch (dtp)
  {
  case DV_SHORT_INT:
  case DV_LONG_INT:
  case DV_CHARACTER:
  case DV_C_SHORT:    /* These are  */
  case DV_C_INT:    /*  not needed? */
    {
  long num = (unbox (arg) == 0);
  return (box_num (num));
    }
  case DV_SINGLE_FLOAT:
    {
  long num;
  num = (cmp_double (unbox_float (arg), (float) 0.0, FLT_EPSILON) == 0);
  return (box_num (num));
    }
  case DV_DOUBLE_FLOAT:
    {
  long num;
  num = (cmp_double (unbox_double (arg), (double) 0.0, FLT_EPSILON) == 0);
  return (box_num (num));
    }
  case DV_NUMERIC:
    { NUMERIC_VAR (zero);
  long num;
  NUMERIC_INIT (zero);
  num = (numeric_compare ((numeric_t) arg, (numeric_t) zero) == 0);
  return (box_num (num));
    }
  default:
    {
  /* Anything else (e.g. NULL, strings, etc) returns zero */
  return (box_num (0));
    }
  }       /* switch */
}



/* Few arithmetic functions. */

caddr_t
bif_atod (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t str = bif_string_arg (qst, args, 0, "atod");
  double d = 0;
  sscanf (str, "%lg", &d);
  return (box_double (d));
}


caddr_t
bif_atof (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t str = bif_string_arg (qst, args, 0, "atof");
  float f = (0.0);
  sscanf (str, "%f", &f);
  return (box_float (f));
}


caddr_t
bif_atoi (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t str = bif_string_or_null_arg (qst, args, 0, "atoi");
  long int l;

  if (NULL == str)
  {
    return (NEW_DB_NULL);
  }
  l = atoi (str);
  return (box_num (l));
}


caddr_t
bif_dtoi (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg = bif_arg (qst, args, 0, "dtoi");
  dtp_t dtp = DV_TYPE_OF (arg);
  if (DV_LONG_INT == dtp)
    {
      int64 i = unbox (arg);
      return box_double (*(double*)&i);
    }
  if (DV_DOUBLE_FLOAT == dtp)
      return box_num (*(int64*)arg);
  return NULL;
}


caddr_t
bif_mod (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int isnull1 = 0, isnull2 = 0;
  long long1 = (long) bif_long_or_null_arg (qst, args, 0, "mod", &isnull1);
  long long2 = (long) bif_long_or_null_arg (qst, args, 1, "mod", &isnull2);

  if (isnull1 || isnull2)
    return (NEW_DB_NULL);
  if (0 == long2)
  {
    sqlr_new_error ("22012", "SR046", "Division by zero in mod(%ld,%ld)",
    long1, long2);
  }

  return (box_num (long1 % long2));
}


caddr_t
bif_frexp (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int exponent;
  double temp;
  double x = bif_double_arg (qst, args, 0, "frexp");
  dk_set_t ret = NULL;

  temp = x;

  temp = frexp (temp, &exponent);

  dk_set_push (&ret, box_num(exponent));
  dk_set_push (&ret, box_double (temp));

  return list_to_array (ret);
}

/* Returns -1, 0, or 1 for numeric types, NULL for NULLs, and error
   for any other types.  */
caddr_t
bif_sign (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg = bif_arg (qst, args, 0, "sign");
  dtp_t dtp = DV_TYPE_OF (arg);
  switch (dtp)
  {
  case DV_DB_NULL:
    {
  return (NEW_DB_NULL);
    }
  case DV_SHORT_INT:
  case DV_LONG_INT:
  case DV_CHARACTER:
  case DV_C_SHORT:    /* These are  */
  case DV_C_INT:    /*  not needed? */
    {
  long num = (long) unbox (arg);
  num = ((num < 0) ? -1 : ((num > 0) ? 1 : 0));
  return (box_num (num));
    }
  case DV_SINGLE_FLOAT:
    {
  float flotflot = unbox_float (arg);
  long num = ((flotflot < 0.0) ? -1 : ((flotflot > 0.0) ? 1 : 0));
  return (box_num (num));
    }
  case DV_DOUBLE_FLOAT:
    {
  double dubdub = unbox_double (arg);
  long num = ((dubdub < 0.0) ? -1 : ((dubdub > 0.0) ? 1 : 0));
  return (box_num (num));
    }
  case DV_NUMERIC:
    { NUMERIC_VAR (zero);
  NUMERIC_INIT (zero);
  return (box_num (numeric_compare ((numeric_t) arg, (numeric_t) zero)));
    }
  default:      /* Any other type is an error. */
    {
  sqlr_new_error ("22023", "SR047",
    "Function sign needs a numeric type as its argument, "
    "not an argument of type %s (%d)",
    dv_type_title (dtp), dtp);
    }
  }       /* switch */
  NO_CADDR_T;
}


/* Returns the absolute value for numeric types (i.e. if number is
   negative it is negated to the positive value, otherwise kept same),
   NULL for NULLs, and error for any other types.  */
caddr_t
bif_abs (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg = bif_arg_unrdf (qst, args, 0, "abs");
  dtp_t dtp = DV_TYPE_OF (arg);
  switch (dtp)
  {
  case DV_DB_NULL:
    {
  return (NEW_DB_NULL);
    }
  case DV_SHORT_INT:
  case DV_LONG_INT:
  case DV_CHARACTER:
  case DV_C_SHORT:    /* These are  */
  case DV_C_INT:    /*  not needed? */
    {
  long num = (long) unbox (arg);
  num = ((num < 0) ? -num : num);
  return (box_num (num));
    }
  case DV_SINGLE_FLOAT:
    {
  float flotflot = unbox_float (arg);
  flotflot = ((flotflot < 0.0) ? -flotflot : flotflot);
  return (box_float (flotflot));
    }
  case DV_DOUBLE_FLOAT:
    {
  double dubdub = unbox_double (arg);
  dubdub = ((dubdub < 0.0) ? -dubdub : dubdub);
  return (box_double (dubdub));
    }
  case DV_NUMERIC:
    {
  numeric_t result = numeric_allocate ();
  if (numeric_compare ((numeric_t) arg, result) < 0)
    numeric_negate (result, (numeric_t) arg);
  else
    numeric_copy (result, (numeric_t) arg);
  return (caddr_t) result;
    }
  default:      /* Any other type is an error. */
    {
  sqlr_new_error ("22023", "SR048",
    "Function abs needs a numeric type as its argument, "
    "not an argument of type %s (%d)",
    dv_type_title (dtp), dtp);
    }
  }       /* switch */
  NO_CADDR_T;
}


#define   KUBL_PI  ((double)3.14159265358979)


caddr_t
bif_pi (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return (box_double (KUBL_PI));
}


#define DEGREES_IN_RADIAN ((double)57.2957795131)
#define RADIANS_IN_DEGREE (((double)1.0)/DEGREES_IN_RADIAN)

#define GENERAL_DOUBLE_FUNC(BIF_NAME, NAMESTR, OPERATION)\
caddr_t BIF_NAME (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)\
{\
  int isnull = 0; \
  double x = bif_double_or_null_arg (qst, args, 0, NAMESTR, &isnull);\
  return(isnull ? NEW_DB_NULL : box_double(OPERATION));\
}


GENERAL_DOUBLE_FUNC (bif_acos, "acos", acos (x))
GENERAL_DOUBLE_FUNC (bif_asin, "asin", asin (x))
GENERAL_DOUBLE_FUNC (bif_atan, "atan", atan (x))
GENERAL_DOUBLE_FUNC (bif_cos, "cos", cos (x))
GENERAL_DOUBLE_FUNC (bif_sin, "sin", sin (x))
GENERAL_DOUBLE_FUNC (bif_tan, "tan", tan (x))
GENERAL_DOUBLE_FUNC (bif_cot, "cot", (((double) 1.0) / tan (x)))

/* Not available on every platform, e.g. tanh not in Windows NT
   GENERAL_DOUBLE_FUNC(bif_cosh, "cosh", cosh(x))
   GENERAL_DOUBLE_FUNC(bif_sinh, "sinh", sinh(x))
   GENERAL_DOUBLE_FUNC(bif_tanh, "tanh", tanh(x))
 */

GENERAL_DOUBLE_FUNC (bif_degrees, "degrees", (DEGREES_IN_RADIAN * (x)))
GENERAL_DOUBLE_FUNC (bif_radians, "radians", (RADIANS_IN_DEGREE * (x)))

GENERAL_DOUBLE_FUNC (bif_exp, "exp", exp (x))
GENERAL_DOUBLE_FUNC (bif_log, "log", log (x))
GENERAL_DOUBLE_FUNC (bif_log10, "log10", log10 (x))
GENERAL_DOUBLE_FUNC (bif_sqrt, "sqrt", sqrt (x))

GENERAL_DOUBLE_FUNC (bif_round, "round", (((x-floor(x))>0.5 ? ceil(x):floor(x))))

#define GENERAL_DOUBLE2_FUNC(BIF_NAME, NAMESTR, OPERATION)\
caddr_t BIF_NAME (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)\
{\
  int isnull1 = 0, isnull2 = 0; \
  double x = bif_double_or_null_arg (qst, args, 0, NAMESTR, &isnull1);\
  double y = bif_double_or_null_arg (qst, args, 1, NAMESTR, &isnull2);\
  return ((isnull1 || isnull2) ? NEW_DB_NULL : box_double(OPERATION));\
}

GENERAL_DOUBLE2_FUNC (bif_atan2, "atan2", atan2 (x, y))
GENERAL_DOUBLE2_FUNC (bif_power, "power", pow (x, y))

#define GENERAL_DOUBLE_TO_INT_FUNC(BIF_NAME, NAMESTR, OPERATION)\
caddr_t BIF_NAME (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)\
{\
  int isnull = 0; \
  double x = bif_double_or_null_arg (qst, args, 0, NAMESTR, &isnull);\
  return(isnull ? NEW_DB_NULL : box_num(((long int)(OPERATION))));\
}

GENERAL_DOUBLE_TO_INT_FUNC (bif_ceiling, "ceiling", ceil (x))
GENERAL_DOUBLE_TO_INT_FUNC (bif_floor, "floor", floor (x))



#define RNG_M 2147483647L  /* m = 2^31 - 1 */
#define RNG_A 16807L
#define RNG_Q 127773L    /* m div a */
#define RNG_R 2836L    /* m mod a */

/* 32 bit seed */
int32 rnd_seed;

/* another 32 bit seed used in blobs */
int32 rnd_seed_b;


#if 0
/* set seed to value between 1 and m-1 */
void
set_rnd_seed (int32 seedval)
{
  rnd_seed = (seedval % (RNG_M - 1)) + 1;
}
#endif

/* returns a pseudo-random number from set 1, 2, ..., RNG_M - 1 */
int32
sqlbif_rnd (int32* seed)
{
  int32 hi, lo;

  if (!seed[0] || seed[0] == RNG_M)
    {
#ifdef WIN32
      seed[0] = (long) (((long) GetTickCount () << 16) ^ time (NULL));
#else
      seed[0] = (long) (((long) getpid () << 16) ^ time (NULL));
#endif
#ifdef VIRT_RECORD_RAND
      if (seed == &rnd_seed || seed == &rnd_seed_b)
	log_debug ("rnd %s=%ld",
	    seed == &rnd_seed ?  "rnd_seed" : "rnd_seed_b",
	    (long)seed[0]);
#endif
    }

  hi = seed[0] / RNG_Q;
  lo = seed[0] % RNG_Q;
  if ((seed[0] = ((int32)(RNG_A * lo)) - ((int32)(RNG_R * hi))) <= 0)
    {
      seed[0] += RNG_M;
      seed[0] &= 0x7fffffff;
    }
  return seed[0] & 0x7fffffff;
}

double
sqlbif_rnd_double (int32* seed, double upper_limit)
{
  int32 tmpres = sqlbif_rnd (&rnd_seed);
  return (tmpres * upper_limit) / (double)(RNG_M);
}


caddr_t
bif_randomize  (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  long n = (long) bif_long_arg (qst, args, 0, "randomize");
  rnd_seed = n;
  return NULL;
}


caddr_t
bif_rnd  (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  long n = (long) bif_long_arg (qst, args, 0, "rnd");
  if (0 == n)
    return (box_num (0));
  return (box_num (sqlbif_rnd (&rnd_seed) %n));
}


/* ================================================================== */
/*        MISCELLANEOUS        */
/* ================================================================== */


caddr_t
bif_dbname (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;
  return (box_dv_short_string (qi->qi_client->cli_qualifier));
}


caddr_t
bif_user (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  user_t *sec_id_to_user (oid_t id);  /* In security.c */
  query_instance_t *qi = (query_instance_t *) QST_INSTANCE (qst);
  user_t *user = NULL;
#if 0
  if (qi && qi->qi_client /*&& qi->qi_client->cli_ws  BUG N654*/
    && qi->qi_client->cli_user && qi->qi_client->cli_saved_user)
  /* this special case needed to handle 'su action inside HTTP call*/
  user = qi->qi_client->cli_user;
  else
#endif
  user = sec_id_to_user (qi->qi_u_id);
  if (!user)
  return (box_dv_short_string ("unknown"));
  else
  return (box_dv_short_string (user->usr_name));
}

char *pwd_magic_users_list = NULL;
static dk_set_t pwd_magic_users = NULL;

static void
init_pwd_magic_users (void)
{
  if (pwd_magic_users_list)
    {
      char *tmp, *tok_s = NULL, *tok;
      tok_s = NULL;
      tok = strtok_r (pwd_magic_users_list, ",", &tok_s);
      pwd_magic_users = NULL;
      while (tok)
  {
    while (*tok && isspace (*tok))
      tok++;
    if (tok_s)
      tmp = tok_s - 2;
    else if (tok && strlen (tok) > 1)
      tmp = tok + strlen (tok) - 1;
    else
      tmp = NULL;
    while (tmp && tmp >= tok && isspace (*tmp))
     *(tmp--) = 0;
    if (*tok)
      {
        if (!stricmp (tok, "all"))
    {
      dk_free_box (list_to_array (pwd_magic_users));
      pwd_magic_users = NULL;
      pwd_magic_users_list = NULL;
      return;
    }
        else if (!stricmp (tok, "none"))
    {
      dk_free_box (list_to_array (pwd_magic_users));
      pwd_magic_users = (dk_set_t) 1;
      pwd_magic_users_list = NULL;
      return;
    }
        else
    {
      dk_set_pushnew (&pwd_magic_users, box_dv_short_string (tok));
    }
      }
    tok = strtok_r (NULL, ",", &tok_s);
  }
      pwd_magic_users_list = NULL;
    }
}


static caddr_t
bif_pwd_magic_calc (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) QST_INSTANCE (qst);
  caddr_t name, password, new_password;
  long plain_required = 0;

  if (pwd_magic_users && qi->qi_client != bootstrap_cli)
    {
      client_connection_t *cli = qi->qi_client;
      caddr_t uname = cli->cli_user ? cli->cli_user->usr_name : (caddr_t) "dba";
      if (pwd_magic_users != (dk_set_t) 1)
        {
          DO_SET (caddr_t, un, &pwd_magic_users)
            {
              if (!strcmp (un, uname))
                goto permit; /* see below */
            }
          END_DO_SET();
        }
      sqlr_new_error ("42000", "SR343",
        "Access to pwd_magic_calc not permitted."
        "If you are getting this message in the Admin interface and you are a DBA,"
        "then you need to enable the function from the INI file in order to use it.");
    }

permit:
  name = bif_string_or_null_arg (qst, args, 0, "pwd_magic_calc");
  password = bif_string_or_null_arg (qst, args, 1, "pwd_magic_calc");
  if (BOX_ELEMENTS (args) > 2)
  plain_required = (long) bif_long_arg (qst, args, 2, "pwd_magic_calc");
  if (!password)
  return dk_alloc_box (0, DV_DB_NULL);
  if (!password[0] && box_length (password) > 1)
  { /* decrypt */
    sec_check_dba (qi, "pwd_magic_calc");
    new_password = dk_alloc_box (box_length (password) - 1, DV_SHORT_STRING);
    memcpy (new_password, password + 1, box_length (password) - 1);
    xx_encrypt_passwd (new_password, box_length (password) - 2, name);
  }
  else
  {
    if (plain_required || box_length (password) < 2)
  new_password = box_dv_short_string (password);
    else
  { /* encrypt */
    new_password = dk_alloc_box (box_length (password) + 1, DV_SHORT_STRING);
    new_password[0] = 0;
    memcpy (new_password + 1, password, box_length (password));
    xx_encrypt_passwd (new_password + 1, box_length (password) - 1, name);
  }
  }
  return new_password;
}


/* Changed by AK 23-FEB-1997. Now checks also for that cli itself
   is not null (previously crashed the server when it encountered NULL cli)
   and keeps count of the users disconnected, which it returns as a result.
   If, if no users disconnected, returns zero, if one disconnected,
   returns one, etc.
   User name can now be specified as a wildcard pattern, so it's possible
   to disconnect all users with disconnect_user('%');
   A new tentative addition: If the argument is NULL, then disconnect
   all other connections except the one where this function call
   was issued from.
 */
caddr_t
bif_disconnect (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;
  char *name = bif_string_or_null_arg (qst, args, 0, "disconnect");
  dk_session_t *this_client_ses = IMMEDIATE_CLIENT;
  long disconnected_users = 0;
  dk_set_t users;

  sec_check_dba (qi, "disconnect_user");

  IN_TXN;
  mutex_enter (thread_mtx);
  users = srv_get_logons ();
  DO_SET (dk_session_t *, ses, &users)
  {
    if (name || ses != this_client_ses)
      {
	client_connection_t *cli = DKS_DB_DATA (ses);
	if (cli &&
  	    (!name || (cli->cli_user && (DVC_MATCH == cmp_like (cli->cli_user->usr_name, name, NULL, 0, LIKE_ARG_CHAR, LIKE_ARG_CHAR)))))
	  {
	    ASSERT_IN_TXN;
	    DO_SET (lock_trx_t *, lt, &all_trxs)
	    {
	      if (lt->lt_client == cli)
		if (lt != qi->qi_trx && lt->lt_status == LT_PENDING && (lt->lt_threads > 0 || lt_has_locks (lt)))
		  {
		    LT_ERROR_DETAIL_SET (lt, box_dv_short_string ("DBA forced disconnect"));
		    lt->lt_error = LTE_SQL_ERROR;
		    lt_kill_other_trx (lt, NULL, NULL, LT_KILL_ROLLBACK);
		  }
	    }
	    END_DO_SET ();
	    PrpcDisconnect (ses);
	    disconnected_users++;
	  }
      }
  }
  END_DO_SET ();
  mutex_leave (thread_mtx);
  LEAVE_TXN;
  return (box_num (disconnected_users));
}


caddr_t
bif_connection_id (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t *) qst;
  client_connection_t * cli = qi->qi_client;
  dk_session_t * ses = cli->cli_session;
  const char * name;
  char tmp[50];

  if (!cli->cli_ws)
  name = ses->dks_peer_name ? ses->dks_peer_name : "INTERNAL";
  else
  {
    snprintf (tmp, sizeof (tmp), "INTERNAL:%lX", (unsigned long) (ptrlong) cli->cli_ws);
    name = tmp;
  }
  return (box_dv_short_string (name));
}


int
box_outlives_qi (caddr_t xx)
{
  dtp_t dtp = DV_TYPE_OF (xx);
  switch (dtp)
  {
  case DV_EXEC_CURSOR:
  case DV_BLOB_HANDLE:
  case DV_BLOB_WIDE_HANDLE:
  case DV_BLOB_XPER_HANDLE:
    return 0;
#ifdef BIF_XML
  case DV_XML_ENTITY:
    return XE_IS_TREE (xx);
#endif
  case DV_ARRAY_OF_POINTER:
  case DV_ARRAY_OF_XQVAL:
    {
  int inx;
  caddr_t * a = (caddr_t*) xx;
  DO_BOX (caddr_t, elt, inx, a)
    {
    if (!box_outlives_qi (elt))
      return 0;
    }
  END_DO_BOX;
    }
  default:
    return 1;
  }
}

void
connection_set (client_connection_t *cli, caddr_t name, caddr_t val)
{
  caddr_t * place = (caddr_t *) id_hash_get (cli->cli_globals, (caddr_t) &name);
  if (!place)
  {
    caddr_t n2 = box_copy (name);
    caddr_t v2 = box_copy_tree (val);
    id_hash_set (cli->cli_globals, (caddr_t) &n2, (caddr_t) &v2);
  }
  else
  {
    dk_free_tree (*place);
    *place = box_copy_tree (val);
  }
  cli->cli_globals_dirty = 1;
}


caddr_t
bif_connection_set (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t *)qst;
  client_connection_t * cli = qi->qi_client;
  caddr_t name = bif_string_arg (qst, args, 0, "connection_set");
  caddr_t val = bif_arg (qst, args, 1, "connection_set");
  if (!box_outlives_qi (val))
  sqlr_new_error ("22023", "SR049",
    "Data type is not suitable for storage into a global variable (connection_set)");
  connection_set (cli, name, val);
  return 0;
}


caddr_t
bif_connection_get (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t *)qst;
  client_connection_t * cli = qi->qi_client;
  int n_args = BOX_ELEMENTS (args);
  caddr_t name = bif_string_arg (qst, args, 0, "connection_get");
  caddr_t * place = (caddr_t *) id_hash_get (cli->cli_globals, (caddr_t) &name);
  if (!place)
    {
      if (n_args > 1)
        return box_copy_tree (bif_arg (qst, args, 1, "connection_get"));
      return NEW_DB_NULL;
    }
  return (box_copy_tree (*place));
}


caddr_t
bif_connection_is_dirty (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t *)qst;
  return box_num (qi->qi_client->cli_globals_dirty);
}

caddr_t
bif_connection_vars (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t *)qst;
  client_connection_t * cli = qi->qi_client;
  id_hash_iterator_t it;
  dk_set_t set = NULL;
  caddr_t * name, * val;

  id_hash_iterator (&it, cli->cli_globals);
  while (hit_next (&it, (caddr_t *) &name, (caddr_t *) &val))
  {
    dk_set_push (&set, box_copy_tree (*val));
    dk_set_push (&set, box_copy (*name));
  }
  return (list_to_array (set));
}

caddr_t
bif_connection_vars_set (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t *)qst;
  client_connection_t * cli = qi->qi_client;
  caddr_t val = bif_arg (qst, args, 0, "connection_vars_set");
  dtp_t dtp = DV_TYPE_OF (val);
  int len = 0, ix;
  id_hash_iterator_t it;
  caddr_t * name, * val1, vname;

  if (dtp != DV_DB_NULL && dtp != DV_ARRAY_OF_POINTER)
    sqlr_new_error ("22023", "SR050",
    "connenction_vars_set expects a vector or null as argument "
    "not of type %s (%d)",
     dv_type_title (dtp), dtp);
  len = ((dtp == DV_ARRAY_OF_POINTER) ? BOX_ELEMENTS (val) : 0);
  if (len % 2 != 0)
  {
    sqlr_new_error ("22023", "SR051",
    "connenction_vars_set expects a vector of even length, "
    "not of length %d (of type %s (%d))",
    len, dv_type_title (dtp), dtp);
  }

  for (ix = 0; ix < len; ix += 2)
  {
    vname = ((caddr_t *) val) [ix];
    dtp = DV_TYPE_OF (vname);
    if (!IS_STRING_DTP (dtp))
  sqlr_new_error ("22023", "SR052",
    "connenction_vars_set expects a string as name of connection variable not of type %s (%d)",
    dv_type_title (dtp), dtp);
    if (!box_outlives_qi (((caddr_t *) val) [ix + 1]))
  sqlr_new_error ("22023", "SR053",
    "Data type is not suitable for storage into a global variable (connection_set)");
  }

  id_hash_iterator (&it, cli->cli_globals);
  while (hit_next (&it, (caddr_t *) &name, (caddr_t *) &val1))
  {
    dk_free_tree (*val1);
    dk_free_box (*name);
  }
  id_hash_clear (cli->cli_globals);
  cli->cli_globals_dirty = 0;
  for (ix = 0; ix < len; ix += 2)
  {
    vname = ((caddr_t *) val) [ix];
    connection_set (cli, vname, ((caddr_t *) val) [ix + 1]);
  }
  NO_CADDR_T;
}

caddr_t
bif_backup (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t fname, fname_cvt;
  sec_check_dba ((query_instance_t *) qst, "backup");
  fname = bif_string_or_wide_or_uname_arg (qst, args, 0, "backup");
  fname_cvt = file_native_name (fname);
  file_path_assert (fname_cvt, NULL, 1);
  db_backup ((query_instance_t *) QST_INSTANCE (qst), fname_cvt);
  dk_free_box (fname_cvt);
  return 0;
}


caddr_t
bif_check (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  sec_check_dba ((query_instance_t *) qst, "check");
  db_check ((query_instance_t *) QST_INSTANCE (qst));
  return 0;
}


caddr_t
sql_lex_analyze (const char * str2, caddr_t * qst, int max_lexems, int use_strval, int find_lextype)
{
  if (!str2)
    {
      return list (1, list (3, 0, 0, "SQL lex analyzer: input text is NULL, not a string"));
    }
  else
    {
      SCS_STATE_FRAME;
      dk_set_t lexems = NULL;
      sql_comp_t sc;
      caddr_t result_array = NULL;
      caddr_t str;
      memset (&sc, 0, sizeof (sc));

      if (!parse_sem)
	parse_sem = semaphore_allocate (1);
      MP_START ();
      semaphore_enter (parse_sem);
      SCS_STATE_PUSH;
      str = (caddr_t) t_alloc_box (20 + strlen (str2), DV_SHORT_STRING);
      snprintf (str, box_length (str), "EXEC SQL %s;", str2);


      yy_string_input_init (str);
      sql_err_state[0] = 0;
      sql_err_native[0] = 0;
      if (0 == setjmp_splice (&parse_reset))
	{
	  int lextype, olex = -1;
	  long n_lexem;
	  sql_yy_reset ();
	  yyrestart (NULL);
	  for (n_lexem = 0;;)
	    {
	      caddr_t boxed_plineno, boxed_text, boxed_lextype;
	      lextype = yylex ();
	      if (!lextype)
		break;
	      if (olex == lextype && lextype == ';')
		continue;
	      boxed_plineno = box_num (scn3_plineno);
	      /* if use_strval is given this means names etc. are expected to be in proper casemode,
	         so must check for DV_SYMBOL otherwise stored procedure with lower case would fail on startup
	         when cm_upper is set  */
	      boxed_text = ((use_strval && (DV_STRINGP (yylval.strval) || DV_SYMBOL == DV_TYPE_OF (yylval.strval))) ?
		  box_dv_short_string (yylval.strval) : box_dv_short_nchars (yytext, get_yyleng ()));
	      boxed_lextype = box_num (lextype);
	      dk_set_push (&lexems, list (3, boxed_plineno, boxed_text, boxed_lextype));
	      olex = lextype;
	      if (max_lexems && (++n_lexem) >= max_lexems)
		break;
	      if (find_lextype && find_lextype == lextype)
		break;
	    }
	  lexems = dk_set_nreverse (lexems);
	}
      else
	{
	  char err[1000];
	  snprintf (err, sizeof (err), "SQL lex analyzer: %s ", sql_err_text);
	  lexems = dk_set_nreverse (lexems);
	  dk_set_push (&lexems, list (2, scn3_plineno, box_dv_short_string (err)));
	  goto cleanup;
	}
    cleanup:
      sql_pop_all_buffers ();
      SCS_STATE_POP;
      semaphore_leave (parse_sem);
      MP_DONE ();
      sc_free (&sc);
      result_array = (caddr_t) (dk_set_to_array (lexems));
      dk_set_free (lexems);
      return result_array;
    }
}


static
caddr_t
bif_sql_lex_analyze (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t str = bif_string_arg (qst, args, 0, "sql_lex_analyze");
  return sql_lex_analyze (str, qst, 0, 0, 0);
}

#if 0
static
caddr_t
bif_sql_split_text (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t str = bif_string_arg (qst, args, 0, "sql_split_text");
  caddr_t **token_array = (caddr_t **)sql_lex_analyze (str, qst, 0, 0);
  int level=0, i, line, oline = 1, n = BOX_ELEMENTS(token_array), last_semi;
  dk_set_t stmts = NULL;
  caddr_t result_array = NULL;

  dk_session_t * ses = NULL;
  if ((0 < n) && (2 == BOX_ELEMENTS (token_array[0])))
    {
      char err[2010];
      strcpy_ck (err, token_array[0][1]);
      dk_free_tree ((box_t) token_array);
      sqlr_new_error ("37000", "SQ201", "%s", err);
    }
  ses = strses_allocate ();
  last_semi = -1;
  for (i=0; i<n; i++)
  {
    caddr_t *p = token_array[i];
    caddr_t token = p[1];
          line = (int) (ptrlong) p [0];
    assert (NULL != token);

    if (level || ';' != *token)
    {
        if (line != oline)
          session_buffered_write (ses, "\n", 1);
      session_buffered_write (ses, token, strlen(token));
      session_buffered_write (ses, " ", 1);
      switch (*token) {
        case '{': level++; break;
        case '}': level--; break;
      }
      oline = line;
      continue;
    }
    if (i > (1 + last_semi))
    {
      int len = strses_length (ses);
      char *out = (char *) dk_alloc_box (len + 1, DV_LONG_STRING);
      strses_to_array (ses, out);
      strses_flush (ses);
      out[len] = 0;
      dk_set_push (&stmts, out);
    }
    else
      strses_flush (ses);
    last_semi = i;
    oline = line;
  }

    if (i > (1 + last_semi))
    {
      int len = strses_length (ses);
      char *out = (char *) dk_alloc_box (len + 1, DV_LONG_STRING);
      strses_to_array (ses, out);
      strses_flush (ses);
      out[len] = 0;
      dk_set_push (&stmts, out);
    }
  dk_free_box ((box_t) ses);
  dk_free_tree ((box_t) token_array);

  result_array = revlist_to_array (stmts);
  return result_array;
}
#endif

#define SQL_SPLIT_TEXT_DEFAULT 0x0
#define SQL_SPLIT_TEXT_KEEP_SEMICOLON 0x1
#define SQL_SPLIT_TEXT_KEEP_EMPTY_STATEMENTS 0x2
#define SQL_SPLIT_TEXT_VERBOSE 0x4

extern dk_session_t *scn3split_ses_code;
extern dk_session_t *scn3split_ses_tail;


caddr_t
sql_split_text (const char * str2, caddr_t * qst, int flags)
{
  dk_set_t res = NULL;
  sql_comp_t sc;
  caddr_t str;
  caddr_t start_filename = NULL;
  int has_useful_lexems;
  int start_lineno;
  int start_plineno;
  SCS_STATE_FRAME;
  memset (&sc, 0, sizeof (sc));

  if (!parse_sem)
    parse_sem = semaphore_allocate (1);
  MP_START();
  semaphore_enter (parse_sem);
  SCS_STATE_PUSH;
  str = (caddr_t) t_alloc_box (20 + strlen (str2), DV_SHORT_STRING);
  snprintf (str, box_length (str), "EXEC SQL %s", str2);
  yy_string_input_init (str);
  sql_err_state[0] = 0;
  sql_err_native[0] = 0;
  if (0 == setjmp_splice (&parse_reset))
    {
      int lextype = -1;
      /*int trail_pline = -1;*/
      caddr_t full_text, descr;
      size_t full_text_blen;
      scn3split_yy_reset ();
      scn3splityyrestart (NULL);
      scn3split_ses = strses_allocate ();
      has_useful_lexems = 0;
      start_lineno = scn3_lineno;
      start_plineno = scn3_plineno;
      start_filename = box_dv_short_string (scn3_get_file_name ());
      while (0 != lextype)
        {
          caddr_t end_filename;
          lextype = scn3splityylex();
          if (!lextype)
	    goto commit_the_statement; /* see below */
          if ((WS_WHITESPACE > lextype) && (';' != lextype))
            has_useful_lexems = 1;
          if (((';' == lextype) || ('}' == lextype)) && (0 == scn3_lexdepth))
            {
              /*trail_pline = scn3_plineno;*/
              goto commit_the_statement; /* see below */
            }
          continue;

commit_the_statement:
          end_filename = box_dv_short_string (scn3_get_file_name ());
          full_text = strses_string (scn3split_ses);
          dk_free_tree (scn3split_ses);
          scn3split_ses = strses_allocate ();
          full_text_blen = box_length(full_text);
          if (!has_useful_lexems && !(flags & SQL_SPLIT_TEXT_KEEP_EMPTY_STATEMENTS))
            goto nothing_to_commit;
          if (full_text_blen < 2)
            goto nothing_to_commit;
          if ((';' == full_text[full_text_blen-2]) && !(flags & SQL_SPLIT_TEXT_KEEP_SEMICOLON))
            full_text[full_text_blen-2] = ' ';
          if (flags & SQL_SPLIT_TEXT_VERBOSE)
            {
              descr = list (8,
                full_text,
                start_filename, box_num(start_lineno), box_num (start_plineno),
                box_copy (end_filename), box_num (scn3_lineno), box_num (scn3_plineno),
                box_num (param_inx) );
            }
          else
            descr = full_text;
          dk_set_push (&res, descr);
nothing_to_commit:
          has_useful_lexems = 0;
          start_filename = end_filename;
          start_lineno = scn3_lineno;
          start_plineno = scn3_plineno;
          param_inx = 0;
          if (!lextype)
	    break;
        }
    }
  else
    {
      char err[1000];
      snprintf (err, sizeof (err), "SQL lex splitter: %s ", sql_err_text);
      dk_set_push (&res, list (2,
        scn3_plineno,
        box_dv_short_string (err) ) );
      goto cleanup;
    }
cleanup:
  scn3split_pop_all_buffers ();
  MP_DONE();
  SCS_STATE_POP;
  dk_free_box (scn3split_ses); /* must be released inside semaphore */
  scn3split_ses = NULL;
  semaphore_leave (parse_sem);
  sc_free (&sc);
  dk_free_box (start_filename);
  return revlist_to_array (res);
}


static
caddr_t
bif_sql_split_text (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t str = bif_string_arg (qst, args, 0, "sql_split_text");
  ptrlong flags = ((BOX_ELEMENTS(args) > 1) ? bif_long_arg (qst, args, 1, "sql_split_text") : SQL_SPLIT_TEXT_DEFAULT);
  return sql_split_text (str, qst, flags);
}


/* An excerpt from KUBLMAN.DOC

   An object ID is a special data type that encodes an identity based
   reference. The object ID is logically composed of the ID, a variable
   length binary string and of a 4 byte class specification that encodes
   the class of the referenced entity.
   Only the ID part of an object ID is meaningful in  comparing ID's.
   An object, i.e. row of any table can be located given its object ID
   by searching  the object ID index cluster which holds all 'object ID'
   keys.
   A key can have the object ID property.  If so, its first key part
   should be of the object ID type and should uniquely identify the
   object.
   Any object that belongs to a table which has an object ID key can be
   retrieved without specification of table by using the ID.
 */


/* Oring an ascii upper or lowercase letter with decimal 96. forces it
   to lowercase. */
#define hexdigtoi(C)\
 (isdigit(C) ? ((C) - '0') : (((C)|96) - ('a' - 10)))

int
hexno (char c)
{
  if (c >= '0' && c <= '9')
  return (c - '0');
  if (c >= 'a' && c <= 'f')
  return (10 + c - 'a');
  if (c >= 'A' && c <= 'F')
  return (10 + c - 'A');
  return -1;   /* It's not a hex digit, return this as a sign of error. */
}


/*
   split_and_decode converts the escaped var=val pair inputs text to
   corresponding vector of string elements. If the optional third
   argument is a string of less than three characters, then does only
   the decoding (but no splitting) and returns back a string.

   The optional second argument, if present should be an integer
   either 0, 1 or 2, which tells whether "variable name"-parts
   (those at the left side of the fourth character given in
   third argument (or = if using the default URL-decoding))
   are converted to UPPERCASE (1), lowercase (2) or left intact
   (0 or when the second argument is not given).

   Note how this avoids all hard-coded limits for the length
   of elements, by scanning the inputs string three times.
   First for the total number of elements (the length of vector
   to allocate), then calculating the length of each string element
   to be allocated, and finally transferring the characters of elements
   to the allocated string elements.

   (E.g. we might get almost ten thousand bytes long HTML Form inputs
   string from GLOW, which contained only one variable with contents
   of nine thousand bytes and more.)

   Coded by AK 4. December 1997, mainly for the needs of GLOW-programming,
   although this is useful for other purposes as well.

   E.g.:
   split_and_decode('Tulipas=Taloon+kumi=kala&Joka=haisi+pahalle&kuin&%E4lymyst\xE4porkkana=ilman ruuvausta',1)
   produces a vector:
   ('TULIPAS' 'Taloon kumi=kala' 'JOKA' 'haisi pahalle' 'KUIN' NULL
   '\xE4LYMYST\xE4PORKKANA' 'ilman ruuvausta')

   split_and_decode(NULL)   => NULL
   split_and_decode("")  => NULL
   split_and_decode("A")  => ("A" NULL)
   split_and_decode("A=B")  => ("A" "B")
   split_and_decode("A&B")  => ("A" NULL "B" NULL)
   split_and_decode("=")  => ("" "")
   split_and_decode("&")  => ("" NULL "" NULL)
   split_and_decode("&=")   => ("" NULL "" "")
   split_and_decode("&=&")  => ("" NULL "" "" "" NULL)
   split_and_decode("%")  => ("%" NULL)
   split_and_decode("%%")   => ("%" NULL)
   split_and_decode("%41")  => ("A" NULL)
   split_and_decode("%4")   => ("%4" NULL)
   split_and_decode("%?41") => ("%?41" NULL)
   Can also work like Perl's split function (we define the escape prefix
   and space escape character as NUL-characters, so that they won't be
   encountered at all:
   split_and_decode('Un,dos,tres',0,'\0\0,') => ("Un" "dos" "tres")
   split_and_decode("Un,dos,tres",1,'\0\0,') => ("UN" "DOS" "TRES")
   split_and_decode("Un,dos,tres",2,'\0\0,') => ("un" "dos" "tres")

   Can also be used as replace and ucase (or lcase) together,
   for example, here we use the comma as space-escape instead of
   element-separator: (not recommended, use replace and ucase instead.
   split_and_decode("Un,dos,tres",0,'\0,')   => "Un dos tres"
   split_and_decode("Un,dos,tres",1,'\0,')   => "UN DOS TRES"

   Can be also used for decoding (some of) MIME-encoded mail-headers:
   split_and_decode('=?ISO-8859-1?Q?Tiira_lent=E4=E4_taas?=',0,'=_')
   =>  '=?ISO-8859-1?Q?Tiira lent\xE4\xE4 taas?='

   split_and_decode('Message-Id: <199511141036.LAA06462@correo.unet.ar>\nFrom: "=?ISO-8859-1?Q?Jorge_Mo=F1as?=" <jorgem@unet.ar>\nTo: "Jore Carvajal" <carvajal@wanabee.fr>\nSubject: RE: Um-pah-pah\nDate: Wed, 12 Nov 1997 11:28:51 +0100\nX-MSMail-Priority: Normal\nX-Priority: 3\nX-Mailer: Molosoft Internet Mail 4.70.1161\nMIME-Version: 1.0\nContent-Type: text/plain; charset=ISO-8859-1\nContent-Transfer-Encoding: 8bit\nX-Mozilla-Status: 0011',
   1,'=_\n:');
   => ('MESSAGE-ID' ' <199511141036.LAA06462@correo.unet.ar>'
   'FROM' ' '"=?ISO-8859-1?Q?Jorge Mo\xF1as?=" <jorgem@unet.ar>'
   'TO' ' "Jore Carvajal" <carvajal@wanabee.fr>'
   'SUBJECT' ' RE: Um-pah-pah'
   'DATE' ' Wed, 12 Nov 1997 11:28:51 +0100'
   'X-MSMAIL-PRIORITY' ' Normal'
   'X-PRIORITY' ' 3'
   'X-MAILER' ' Molosoft Internet Mail 4.70.1161'
   'MIME-VERSION' ' 1.0'
   'CONTENT-TYPE' ' text/plain; charset=ISO-8859-1'
   'CONTENT-TRANSFER-ENCODING' ' 8bit'
   'X-MOZILLA-STATUS' ' 0011')

   Same, but let's use space, not colon as a variable=value separator:
   split_and_decode('Message-Id: <199511141036.LAA06462@correo.unet.ar>\nFrom: "=?ISO-8859-1?Q?Jorge_Mo=F1as?=" <jorgem@unet.ar>\nTo: "Jore Carvajal" <carvajal@wanabee.fr>\nSubject: RE: Um-pah-pah\nDate: Wed, 12 Nov 1997 11:28:51 +0100\nX-MSMail-Priority: Normal\nX-Priority: 3\nX-Mailer: Molosoft Internet Mail 4.70.1161\nMIME-Version: 1.0\nContent-Type: text/plain; charset=ISO-8859-1\nContent-Transfer-Encoding: 8bit\nX-Mozilla-Status: 0011',
   1,'=_\n ')
   => ('MESSAGE-ID:' '<199511141036.LAA06462@correo.unet.ar>'
   'FROM:' '"=?ISO-8859-1?Q?Jorge Mo\xF1as?=" <jorgem@unet.ar>'
   'TO:' '"Jore Carvajal" <carvajal@wanabee.fr>'
   'SUBJECT:' 'RE: Um-pah-pah'
   'DATE:' 'Wed, 12 Nov 1997 11:28:51 +0100'
   'X-MSMAIL-PRIORITY:' 'Normal'
   'X-PRIORITY:' '3'
   'X-MAILER:' 'Molosoft Internet Mail 4.70.1161'
   'MIME-VERSION:' '1.0'
   'CONTENT-TYPE:' 'text/plain; charset=ISO-8859-1'
   'CONTENT-TRANSFER-ENCODING:' '8bit'
   'X-MOZILLA-STATUS:' '0011')

   Of course this approach does not work with multiline headers, except
   somewhat kludgy.
   If the lines are separated by CR+LF, there is left one trailing
   CR at the end of each valuepart string.

 */

#define DEFAULT_SEPARATORS "%+&=" /* For URL-encoded HTML-Input-strings. */

caddr_t
bif_split_and_decode (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char *me = "split_and_decode";
  int n_args = BOX_ELEMENTS (args);
  caddr_t inputs = bif_string_or_null_arg (qst, args, 0, me);
  long int convert_names_to /* 0=PrEsErVe, 1=UPPERCASE, 2=lowercase */
  = ((n_args > 1) ? (long) bif_long_arg (qst, args, 1, me) : 0);
  caddr_t alt_seps
  = ((n_args > 2) ? bif_string_arg (qst, args, 2, me) : (caddr_t) DEFAULT_SEPARATORS);
  int alt_seps_len
  = ((n_args > 2) ? (box_length (alt_seps) - 1) : (sizeof (DEFAULT_SEPARATORS) - 1));
  int inputs_len = ((NULL != inputs) ? (box_length (inputs) - 1) : 0);
/*
   long int to_int_if_possible
   = ((n_args>3)?bif_long_arg (qst, args, 3, me): 1);
 */
  /*unsigned */ char res_char;
  unsigned char sep1, sep2, esc_char, space_esc;
  int reading_value, switch_to_val, counting_only;  /* Flags. 0 or 1 */
  int split_it, in_pairs; /* Flags. */
  int occurrences, vec_inx, item_len; /* Counters and indices. */
  caddr_t arr = NULL;
  /*unsigned */ char *item = NULL;
  /* Vector and string boxes. */
  unsigned char *ptr, *end_ptr, *item_start;

  /* First determine from alt_seps string how we should act.
   I.e. what are the encoding/decoding escape-characters,
   and should we also split the inputs string into vector elements
   (in case the third and possibly also fourth characters are
   present in the alt_seps string). */
  {
  if (alt_seps_len > 0)
    {
  esc_char = *(((unsigned char *) alt_seps) + 0);
    }
  else
    {
  esc_char = '\0';
    }

  if (alt_seps_len > 1)
    {
  space_esc = *(((unsigned char *) alt_seps) + 1);
    }
  else
    {
  space_esc = '\0';
    }

  if (alt_seps_len > 2)
    {
  sep1 = *(((unsigned char *) alt_seps) + 2);
  split_it = 1;
    }
  else
    {
  sep1 = '\0';
  split_it = 0;
    }

  if (alt_seps_len > 3)
    {
  sep2 = *(((unsigned char *) alt_seps) + 3);
  in_pairs = 1;
    }
  else
    {
  sep2 = '\0';
  in_pairs = 0;
    }
  /* User didn't give the var=val separator,
     so we are not reading stuff as pairs. */
  }

  /* If we are not splitting, then if the user gave an empty string,
   return as the result an empty string back (instead of NULL).
   */
  if (!split_it && inputs && (0 == inputs_len))
  {
    return (box_copy (inputs));
  }

  if ((NULL == inputs) || (0 == inputs_len))
  {
    return (NEW_DB_NULL);
  }       /* NULL for NULL, ashes to ashes. */

  end_ptr = (unsigned char *)(inputs + inputs_len);

  /* First count the number of occurrences of ampersands in inputs */
  {
  occurrences = 1;    /* Always at least one element. */
  ptr = (unsigned char *)inputs;
  while ((ptr < end_ptr)) /* (ptr = strchr(ptr,sep1)) */
    {
  if (sep1 == *ptr++)
    {
    occurrences++;
    }
    }
  }

  if (split_it)     /* Only if sep1 is given the vector is allocated. */
  {
    if (in_pairs)
  {
    occurrences += occurrences;
  }
    /* And allocate a vector of once or twice of that many elements. */
    arr = dk_alloc_box ((occurrences * sizeof (caddr_t)), DV_ARRAY_OF_POINTER);
  }

/*
   printf(
   "DEBUG: %s(\"%s\",%d,\"%s\"): split_it=%d, in_pairs=%d, occurrences=%d\n",
   me,inputs,convert_names_to,alt_seps,split_it,in_pairs,occurrences);
   fflush(stdout);
 */

  /* Start scanning the inputs string again. */
  {
  ptr = (unsigned char *)inputs;
  reading_value = 0;
  counting_only = 1;
  vec_inx = 0;
  item_len = 0;
  switch_to_val = 0;
  item_start = ptr;

#define is_at_top_split(PTR) (((PTR) >= end_ptr) || (sep1 == *(PTR)))

  /* Scan each element twice, first with counting_only flag 1,
     (to get the length), and then with counting_only flag 0 */
  while ((ptr < end_ptr) || counting_only)
    {
/*
   printf(
   "c_o=%d, r_v=%d, i_a_t_s(ptr)=%d, (ptr-inputs)=%d, (item_start-inputs)=%d"
   " *ptr=%c, i_l=%d, sep1=%c, sep2=%c\n",
   counting_only,reading_value,is_at_top_split(ptr),(ptr-inputs),
   (item_start-inputs),(*ptr ? *ptr : 'Z'),item_len,sep1,sep2);
   fflush(stdout);
 */
  /* An ampersand (&) or the end of inputs string encountered?
     or the first equal sign (=) after ampersand?
     switch_to_val is purposely set to 1 in the and-clause. */
  switch_to_val = 0;
  if (is_at_top_split (ptr)
    || ((0 == reading_value) && (sep2 == *ptr) && (switch_to_val = 1)))
    {
    if (counting_only)  /* We have just counted the name and val len. */
      {
    item
      = ((char *) dk_alloc_box (item_len + 1, DV_LONG_STRING));
    if (split_it)
      {
         if (vec_inx >= occurrences) /*XXX: we should prevent the memory overrun */
           {
       dk_free_box (item);
       break;
           }
      ((caddr_t *) arr)[vec_inx++] = ((caddr_t) item);
      }

    /* A special case: &varname& without an equal sign between
       (or a trailing varname),
       allocate a NULL as a value of that element, so that we
       keep all varname's in even positions in vector.
       (Unless in_pairs flag is set to zero.)
     */
    if (in_pairs && (0 == reading_value) && is_at_top_split (ptr))
      {
         if (vec_inx >= occurrences) /*XXX: we should prevent the memory overrun */
           break;
      ((caddr_t *) arr)[vec_inx++] = NEW_DB_NULL;
      }
    item[item_len] = '\0';  /* Terminating zero. */
    item_len = 0; /* Works again as an index to item. */
    ptr = item_start; /* Scan the third time, also copying it. */
    counting_only = 0;
    /* Keep reading_value as it was, when we "return" back
       to item's start. */
      }
    else
      /* Inserted the previous item into place, */
      {
    /* now count the length of the next one. */
    counting_only = 1;
    item_start = ++ptr;
    item_len = 0;
    reading_value = switch_to_val;
      }
    }
  else
    /* Any other character. */
    {
    if (esc_char == *ptr)
      {
    /* Double esc is one esc. Just a convention. */
    if (esc_char == *(ptr + 1))
      {
      res_char = esc_char;
      ptr += 2;
      }
    else
      {
      /* The next character is not another esc_char ? */
      int code, code2;
      if (((code = hexno (*(ptr + 1))) >= 0)
      && ((code2 = hexno (*(ptr + 2))) >= 0))
        {
      ptr += 3;
      code = (code * 16) + code2;
      res_char = ((unsigned char) code);
        }
      else
        /* An esc char not followed by two hex-digits? */
        { /* Just copy the escape literally, and proceed. */
      res_char = *ptr;
      ptr++;
        }
      }
      }     /* Was an escape character? */
    else if (space_esc == *ptr)   /* E.g. + with URL-encoding. */
      {
    res_char = ' ';
    ptr++;
      }
    else
      /* All other characters are copied literally. */
      {
    res_char = *ptr;
    ptr++;
      }

    if (!counting_only)
      {
    if ((0 == reading_value)  /* Reading a name? */
      && isISOletter ((unsigned char) res_char))
      /* this char needs conversion? */
      {
      if (1 == convert_names_to)
        {
      res_char = raw_toupper (res_char);
        }
      else if (2 == convert_names_to)
        {
      res_char = raw_tolower (res_char);
        }
      }
    item[item_len] = res_char;
      }
    item_len++;
    }     /* Not a sep1 or sep2. */

    }       /* while(*ptr) loop over inputs second and third time. */
  }       /* Just a block. */

  return (split_it ? arr : item);
}


caddr_t
bif_vector (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int len = BOX_ELEMENTS (args);
  caddr_t *res = (caddr_t *) dk_alloc_box (len * sizeof (caddr_t),
    DV_ARRAY_OF_POINTER);
  int inx;
  for (inx = 0; inx < len; inx++)
  {
    caddr_t arg = bif_arg (qst, args, inx, "vector");
    if (DV_LONG_INT == DV_TYPE_OF (arg) && 0 == unbox (arg))
      arg = NULL; /* an int 0 must be a null, not an int box with 0.  Need for making parse trees in pl */
    res[inx] = box_copy_tree (arg);
  }
  return ((caddr_t) res);
}

caddr_t
bif_vector_zap_args (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int len = BOX_ELEMENTS (args);
  caddr_t *res = (caddr_t *) dk_alloc_box (len * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  int inx;
  for (inx = 0; inx < len; inx++)
    {
      caddr_t z = NULL;
      qst_swap_or_get_copy (qst, args[inx], &z);
      res[inx] = z;
    }
  return ((caddr_t) res);
}

caddr_t
bif_lvector (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int len = BOX_ELEMENTS (args);
  ptrlong *res = (ptrlong *) dk_alloc_box (len * sizeof (caddr_t), DV_ARRAY_OF_LONG);
  int inx;
  for (inx = 0; inx < len; inx++)
  {
    res[inx] = bif_long_arg (qst, args, inx, "lvector");
  }
  return ((caddr_t) res);
}


caddr_t
bif_fvector (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int len = BOX_ELEMENTS (args);
  float *res = (float *) dk_alloc_box (len * sizeof (caddr_t),
    DV_ARRAY_OF_FLOAT);
  int inx;
  for (inx = 0; inx < len; inx++)
  {
    res[inx] = bif_float_arg (qst, args, inx, "fvector");
  }
  return ((caddr_t) res);
}


caddr_t
bif_dvector (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int len = BOX_ELEMENTS (args);
  double *res = (double *) dk_alloc_box (len * sizeof (double),
    DV_ARRAY_OF_DOUBLE);
  int inx;
  for (inx = 0; inx < len; inx++)
  {
    res[inx] = bif_double_arg (qst, args, inx, "dvector");
  }
  return ((caddr_t) res);
}


#define boxes_match(X,Y) (DVC_MATCH == cmp_boxes((X),(Y), NULL, NULL))

/* Could be also: box_equal((X),(Y)) except that it does not work so well. */

/* The last case is for strings. For them and longvectors it is assumed
   that elem2 has already been unboxed (i.e. dereferenced). */

#define vecelem_equal(elem1ptr,elem2,vtype)\
 ((IS_NONLEAF_DTP(vtype)) \
    ? boxes_match((*((caddr_t *)(elem1ptr))),((caddr_t)(elem2)))\
  : ((DV_ARRAY_OF_LONG == (vtype)) ? ((*((ptrlong *)(elem1ptr))) == ((ptrlong)(elem2)))\
  : ((DV_ARRAY_OF_DOUBLE == (vtype)) ? (*((double *)(elem1ptr)) == unbox_double((elem2)))\
  : ((DV_ARRAY_OF_FLOAT == (vtype)) ? (*((float *)(elem1ptr)) == unbox_float((elem2)))\
  : (((caddr_t)(ptrlong)*((unsigned char *)(elem1ptr))) == (elem2))))))


/* Generic function for finding item item (which can be of any type)
   from vector vec (which can be an ordinary heterogeneous vector
   or lvector, fvector or dvector, or even string), starting from start:th
   element (zero-based), and skipping skip_value elements at times.
   Returns an one-based index where the first occurrence of item
   was found, or 0 if not found or if start is longer than veclen.
   veclen is given as a length of vector (count of items), not as
   its length in bytes.
   By AK 30. October 1997.

   What's the difference between DV_ARRAY_OF_POINTER and DV_LIST_OF_POINTER
   ??? Does this work with the latter, if one ever comes across?
 */
int
find_index_to_vector (caddr_t item, caddr_t vec, int veclen,
  dtp_t vectype, int start, int skip_value, const char *calling_fun)
{
  int item_type = DV_TYPE_OF (item);
  int elem_size = 1;
  float float_item;
  double double_item;
  char *end_ptr, *vec_ptr = ((char *) vec);

  if (start >= veclen)
  {
    return (0);
  }       /* Not that many elements? */

  switch (vectype)    /* Get the size of one element in bytes. */
  {
  case DV_ARRAY_OF_POINTER: case DV_LIST_OF_POINTER: case DV_ARRAY_OF_XQVAL:
    {
  elem_size = sizeof (caddr_t);
  break;
    }
  case DV_ARRAY_OF_LONG:
    {
  if ((item_type != DV_SHORT_INT) && (item_type != DV_LONG_INT))
    {
    goto wrong_item_type;
    }
  elem_size = sizeof (ptrlong);
  /* Do it here, not in loop. I hope that long fits to caddr_t (char *) */
  item = ((caddr_t) unbox_ptrlong (item));
  break;
    }
  case DV_ARRAY_OF_DOUBLE:
    {
  if ((item_type == DV_SINGLE_FLOAT))
    {
    double_item = ((double) unbox_float (item));
    item = ((caddr_t) & double_item);
    }
  else if ((item_type != DV_DOUBLE_FLOAT))
    {
    goto wrong_item_type;
    }
  elem_size = sizeof (double);
  break;
    }
  case DV_ARRAY_OF_FLOAT:
    {
  if ((item_type == DV_DOUBLE_FLOAT))
    {
    float_item = ((float) unbox_double (item));
    item = ((caddr_t) & float_item);
    }
  else if ((item_type != DV_SINGLE_FLOAT))
    {
    goto wrong_item_type;
    }
  elem_size = sizeof (float);
  break;
    }
  case DV_STRING: case DV_UNAME:
    {
  /* if item is a string, then use its first character
    (which could be a terminating zero if string is empty),
    otherwise it must be an integer, which should be an unsigned
    ascii value of the character. */
  if ((DV_STRING == item_type) || (DV_UNAME == item_type))
    {
    item = ((caddr_t) (ptrlong) *((unsigned char *) item));
    }
  else if ((item_type == DV_SHORT_INT) || (item_type == DV_LONG_INT))
    {
    item = ((caddr_t) unbox_ptrlong (item));
    }
  else
    {
    goto wrong_item_type;
    }
  elem_size = sizeof (char);
  break;
    }
  }

  end_ptr = vec_ptr + (veclen * elem_size);
  vec_ptr += (start * elem_size);

  for (; vec_ptr < end_ptr; vec_ptr += (skip_value * elem_size))
  {
    if (vecelem_equal (vec_ptr, item, vectype))
  {
    return (int) (1 + ((vec_ptr - ((char *) vec)) / elem_size));
  }
  }
  return (0);     /* Not found. */

wrong_item_type:

  sqlr_new_error ("22023", "SR056",
    "%s expects the type of item searched for (%s (%d)) and "
    "the type of the vector searched from (%s (%d)) to match. Veclen=%d.",
    calling_fun, dv_type_title (item_type), item_type,
    dv_type_title (vectype), vectype, veclen);
  return (0);
}


/* Change at 29.October 1997 by AK:
   If the third argument (default) is missing, then act like it were NULL.
   So if get_keyword(item,vector) does not find item from vector,
   it will return NULL.

   Change 30. October 1997 by AK: Now should work with vectors (arrays)
   of any type, e.g. vector, lvector, fvector, dvector even strings
   of even length. */
caddr_t
bif_get_keyword (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char *me = "get_keyword";
  int n_args = BOX_ELEMENTS (args);
  caddr_t item = bif_arg (qst, args, 0, me);
  caddr_t arr = (caddr_t) bif_array_or_null_arg (qst, args, 1, me);
  long is_set_0 = (long) ((n_args > 3) ? bif_long_arg (qst, args, 3, me) : 0);
  int inx;
  dtp_t vectype;
  int boxlen, len;
  if (NULL == arr)
    return (n_args > 2 ? box_copy_tree (bif_arg (qst, args, 2, me)) : NEW_DB_NULL);
  vectype = DV_TYPE_OF (arr);
  boxlen = (is_string_type (vectype)
    ? box_length (arr) - 1
    : box_length (arr));
  len = (boxlen / get_itemsize_of_vector (vectype));
/* Try also lvectors and dvectors.
   if (DV_ARRAY_OF_POINTER != box_tag (arr))
   sqlr_new_error ("42000", "XXX", "get_keyword expects a vector");
 */
  if (len % 2 != 0)
  {
    sqlr_new_error ("22023", "SR057",
    "get_keyword expects a vector of even length, "
    "not of length %d (of type %s (%d))",
    len, dv_type_title (vectype), vectype);
  }

  inx = find_index_to_vector (item, arr, len, vectype, 0, 2, me);

  if (0 == inx)
  {
    return (n_args > 2 ? box_copy_tree (bif_arg (qst, args, 2, me)) : NEW_DB_NULL);
  }
  else
  {
    if (vectype == DV_ARRAY_OF_POINTER && is_set_0)
      {
        caddr_t res = ((caddr_t *)arr)[inx];
        ((caddr_t *)arr)[inx] = NULL;
        return res;
      }
    else
      return (gen_aref (arr, inx, vectype, me));
  }

  /* Note how by using one-based result of find_index_to_vector (inx) to
  access the arr with zero-based gen_aref fetches just what
  we want: the next element! */
}

caddr_t
get_keyword_int (caddr_t * arr, char * item1, const char * me)
{
  int inx;
  dtp_t vectype = DV_TYPE_OF (arr);
  int boxlen = (is_string_type (vectype) ? box_length (arr) - 1 : box_length (arr));
  int len = (boxlen / get_itemsize_of_vector (vectype));
  caddr_t * item = (caddr_t *) box_dv_short_string (item1);
  inx = find_index_to_vector ((caddr_t) item, (caddr_t)arr, len, vectype, 0, 2, me);
  dk_free_box ((box_t) item);
  if (inx)
    return (gen_aref (arr, inx, vectype, me));
  return NULL;
}


/* same as the above but only for DV_ARRAY_OF_VECTOR with string keys */

caddr_t
get_keyword_ucase_int (caddr_t * arr, const char * item, caddr_t dflt)
{
  int inx, len = BOX_ELEMENTS (arr);
  for (inx = 0; inx < len-1; inx += 2)
    {
      caddr_t key = arr[inx];
      dtp_t keydtp = DV_TYPE_OF (key);
      if (IS_STRING_DTP (keydtp) && !stricmp (key, item))
        return box_copy_tree (arr [inx + 1]);
    }
  return box_copy_tree (dflt);
}


caddr_t
bif_get_keyword_ucase (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char *me = "get_keyword_ucase";
  int n_args = BOX_ELEMENTS (args);
  caddr_t item = bif_string_or_uname_arg (qst, args, 0, me);
  caddr_t arr = (caddr_t) bif_array_or_null_arg (qst, args, 1, me);
  long is_set_0 = (long) ((n_args > 3) ? bif_long_arg (qst, args, 3, me) : 0);
  int inx;
  dtp_t vectype;
  int len;
  if (NULL == arr)
    return (n_args > 2 ? box_copy_tree (bif_arg (qst, args, 2, me)) : NEW_DB_NULL);
  vectype = DV_TYPE_OF (arr);
  len = BOX_ELEMENTS (arr);
  if (DV_ARRAY_OF_POINTER != box_tag (arr))
    sqlr_new_error ("22023", "SR058", "get_keyword expects a vector");

  if (len % 2 != 0)
    {
      sqlr_new_error ("22024", "SR059",
    "get_keyword_ucase expects a vector of even length, "
    "not of length %d (of type %s (%d))",
    len, dv_type_title (vectype), vectype);
    }

  for (inx = 0; inx < len; inx += 2)
    {
      caddr_t key = ((caddr_t *)arr)[inx];
      dtp_t keydtp = DV_TYPE_OF (key);
      if (IS_STRING_DTP (keydtp))
  {
    if (!stricmp (key, item))
      break;
  }
    }
  if (inx >= len)
    {
      return (n_args > 2 ? box_copy_tree (bif_arg (qst, args, 2, me)) : NEW_DB_NULL);
    }
  else
    {
      if (!is_set_0)
  return (box_copy_tree (((caddr_t *)arr)[inx + 1]));
      else
  {
    caddr_t res = ((caddr_t *)arr)[inx + 1];
    ((caddr_t *)arr)[inx + 1] = NULL;
    return res;
  }
    }
}

static caddr_t*
bif_set_by_keywords_imp (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, int is_tweak, const char *fname)
{
  int argcount = BOX_ELEMENTS (args);
  caddr_t *orig_arr = (caddr_t *)bif_array_or_null_arg (qst, args, 0, fname);
  caddr_t *curr_arr = (NULL != orig_arr) ? orig_arr : dk_alloc_list (0);
  int curr_arr_len = BOX_ELEMENTS (curr_arr);
  caddr_t *changed_arr;
  if (1 != (argcount % 3))
    sqlr_new_error ("22023", "SR651", "Wrong argument of arguments (%d) in call of %s()", argcount, fname);
  if (curr_arr_len % 2 != 0)
    sqlr_new_error ("22024", "SR652", "%s() expects a vector of even length, not of length %d", fname, curr_arr_len);
  curr_arr = NULL;
  if (is_tweak)
    curr_arr = (caddr_t *)box_copy_tree ((caddr_t)orig_arr);
  else
    {
      if (!qst_swap_or_get_copy (qst, args[0], (caddr_t *)(&curr_arr)))
        {
          dk_free_tree ((caddr_t)curr_arr);
          sqlr_new_error ("22024", "SR656", "%s() expects a settable variable as first argument", fname);
        }
    }
  changed_arr = curr_arr;
  QR_RESET_CTX
    {
      int argctr;
      for (argctr = 1; argctr < argcount; argctr += 3)
        {
          caddr_t opcode = bif_string_or_uname_arg (qst, args, argctr, fname);
          caddr_t kwd = bif_string_or_uname_arg (qst, args, argctr+1, fname);
          caddr_t val = bif_arg (qst, args, argctr+2, fname);
          int old_kwd_pos;
          for (old_kwd_pos = 0; old_kwd_pos < curr_arr_len; old_kwd_pos += 2)
            {
              caddr_t k = curr_arr[old_kwd_pos];
              if ((DV_STRING != DV_TYPE_OF (k)) && (DV_UNAME != DV_TYPE_OF (k)))
                sqlr_new_error ("22024", "SR653", "The get_keyword-style vector contains a non-string key at index %d", old_kwd_pos);
              if (!strcmp (kwd, k))
                goto kwd_pos_done;
            }
          old_kwd_pos = -1;
kwd_pos_done:
          if (!strcmp (opcode, "new"))
            {
              if (-1 != old_kwd_pos)
                sqlr_new_error ("22024", "SR654", "The function %s() gets opcode '%s' as %d-th argument but the specified keyword %.500s is already in the array at index %d", fname, opcode, argctr+1, kwd, old_kwd_pos);
              goto op_do_extend;
            }
          if (!strcmp (opcode, "set"))
            {
              if (-1 != old_kwd_pos)
                goto op_do_replace;
              goto op_do_extend;
            }
          if (!strcmp (opcode, "soft"))
            {
              if (-1 != old_kwd_pos)
                continue;
              goto op_do_extend;
            }
          if (!strcmp (opcode, "replace"))
            {
              if (-1 != old_kwd_pos)
                goto op_do_replace;
              sqlr_new_error ("22024", "SR654", "The function %s() gets opcode '%s' as %d-th argument but the specified keyword %.500s is not found in the array", fname, opcode, argctr+1, kwd);
            }
          if (!strcmp (opcode, "delete"))
            {
              if (-1 != old_kwd_pos)
                goto op_do_remove;
              continue;
            }
          sqlr_new_error ("22024", "SR655", "The function %s() gets invalid opcode '%.500s' as %d-th argument", fname, opcode, argctr+1);
op_do_replace:
          dk_free_tree (curr_arr[old_kwd_pos + 1]);
          curr_arr[old_kwd_pos+1] = box_copy (val);
#if 0
              caddr_t old_val = curr_arr[old_kwd_pos + 1];
              curr_arr[old_kwd_pos + 1] = NULL;
              changed_arr = (caddr_t *)box_copy_tree ((caddr_t)curr_arr);
              curr_arr[old_kwd_pos + 1] = old_val;
              changed_arr[old_kwd_pos + 1] = box_copy (val);
#endif
          goto op_done;
op_do_extend:
          list_extend ((caddr_t *)(&changed_arr), 2, box_copy (kwd), box_copy (val));
          curr_arr = NULL;
          goto op_done;
op_do_remove:
          changed_arr = dk_alloc_list (curr_arr_len - 2);
          memcpy (changed_arr, curr_arr, sizeof (caddr_t) * old_kwd_pos);
          memcpy (changed_arr + old_kwd_pos, curr_arr + old_kwd_pos + 2, sizeof (caddr_t) * ((curr_arr_len - 2) - old_kwd_pos));
#if 0
          if (curr_arr == orig_arr)
            {
              int ctr;
              for (ctr = curr_arr_len - 2; ctr--; /*no step*/)
                changed_arr[ctr] = box_copy_tree (changed_arr[ctr]);
            }
#endif
          goto op_done;
op_done:
          if (curr_arr != changed_arr)
            {
              dk_free_box ((caddr_t)curr_arr);
              curr_arr = changed_arr;
              curr_arr_len = BOX_ELEMENTS (curr_arr);
            }
        }
    }
  QR_RESET_CODE
    {
      du_thread_t * self = THREAD_CURRENT_THREAD;
      caddr_t err = thr_get_error_code (self);
      dk_free_box ((caddr_t)curr_arr);
      if ((changed_arr != orig_arr) && (changed_arr != curr_arr))
        dk_free_box ((caddr_t)changed_arr);
      POP_QR_RESET;
      sqlr_resignal (err);
    }
  END_QR_RESET
  return changed_arr;
}


caddr_t
bif_set_by_keywords (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t *res = bif_set_by_keywords_imp (qst, err_ret, args, 0, "set_by_keywords");
  qst_swap (qst, args[0], (caddr_t *)(&res));
  return NULL;
}

caddr_t
bif_tweak_by_keywords (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t *res = bif_set_by_keywords_imp (qst, err_ret, args, 1, "tweak_by_keywords");
  return (caddr_t)res;
}

/*
   First argument: Any scalar item, or maybe a vector itself
   (in case vectors may contain subvectors as their elements).
   Second argument: A vector (of any type) where the item is
   searched from.
   Optional third argument: One-based starting index. If missing,
   the search starts from first element (1.).
   Optional fourth argument: Every_nth. If missing, it's 1 by default.
   E.g. give it as 2 to emulate get_keyword
   like behaviour, checking only for every
   even-indexed element.

   Returns as a result the one-based ndex where the first occurrence
   of item was found, starting from start:th or first element.
   If item is not found, then returns zero.
 */
caddr_t
bif_position (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int n_args = BOX_ELEMENTS (args);
  char *me = "position";
  caddr_t item = bif_arg (qst, args, 0, me);
  caddr_t arr = (caddr_t) bif_array_arg (qst, args, 1, me);
  long int start = (long) ((n_args > 2) ? bif_long_arg (qst, args, 2, me) - 1 : 0);
  long every_nth = (long) ((n_args > 3) ? bif_long_arg (qst, args, 3, me) : 1);
  dtp_t vectype = DV_TYPE_OF (arr);
  int boxlen = (is_string_type (vectype) ? box_length (arr) - 1 : box_length (arr));
  int len = (boxlen / get_itemsize_of_vector (vectype));

  if (start < 0)
  start = 0;

  if (0 == every_nth)
  {
    sqlr_new_error ("22003", "SR060",
    "%s: cannot check every 0th element of vector of type %s",
    me, dv_type_title (vectype));
  }
  else if ((every_nth > 1) && ((len % every_nth) != 0))
  {
    sqlr_new_error ("22023", "SR061",
    "%s: expects a vector whose length is divisible by %ld, "
    "not of length %d (of type %s (%d))",
    me, every_nth, len, dv_type_title (vectype), vectype);
  }

  return (box_num (
    find_index_to_vector (item, arr, len, vectype, start, every_nth, me)));
}


/* one_of_these(item,arg1,arg2,arg3,arg4,arg5,...,argn)

   returns an index (zero-based if we think item as first argument)
   of a first argument that is equal to item, zero otherwise. */
caddr_t
bif_one_of_these (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char *me = "one_of_these";
  query_instance_t * qi = (query_instance_t *) qst;
  int n_args = BOX_ELEMENTS (args);
  caddr_t item = bif_arg (qst, args, 0, me);
  dtp_t item_dtp = DV_TYPE_OF (item);
  int inx;
  caddr_t value;
  dtp_t val_dtp;
  int they_match;

  for (inx = 1; inx < n_args; inx++)
    {
      caddr_t values = qst_get (qst, args[inx]);
      int is_array = DV_ARRAY_OF_POINTER == DV_TYPE_OF (values);
      int nth, n_values = is_array ? BOX_ELEMENTS (values) : 1;
      for (nth = 0; nth < n_values; nth++)
	{
	  value = is_array ? ((caddr_t*)values)[nth] : values;
	  val_dtp = DV_TYPE_OF (value);
	  if (IS_WIDE_STRING_DTP (item_dtp) && IS_STRING_DTP (val_dtp))
	    {
	      caddr_t wide = box_narrow_string_as_wide ((unsigned char *) value, NULL, 0, QST_CHARSET (qst), err_ret, 1);
	      if (*err_ret)
		return NULL;
	      they_match = boxes_match (item, wide);
	      dk_free_box (wide);
	    }
	  else if (IS_STRING_DTP (item_dtp) && IS_WIDE_STRING_DTP (val_dtp))
	    {
	      caddr_t wide = box_narrow_string_as_wide ((unsigned char *) item, NULL, 0, QST_CHARSET (qst), err_ret, 1);
	      if (*err_ret)
		return NULL;
	      they_match = boxes_match (wide, value);
	      dk_free_box (wide);
	    }
	  else if (item_dtp != val_dtp && item_dtp != DV_DB_NULL && val_dtp != DV_DB_NULL)
	    {
	      caddr_t tmp_val = box_cast_to (qst, value, val_dtp, item_dtp, NUMERIC_MAX_PRECISION, NUMERIC_MAX_SCALE, err_ret);
	      if (*err_ret)
		{
		  if (qi->qi_no_cast_error)
		    {
		      dk_free_tree (*err_ret);
		      *err_ret = NULL;
		      continue;
		    }
		  return NULL;
		}
	      else
		they_match = boxes_match (item, tmp_val);
	      dk_free_tree (tmp_val);
	    }
	  else
	    they_match = boxes_match (item, value);
	  if (they_match)
	    return (box_num (inx));
	}
    }
  return (box_num (0));
}


void
row_str_check (db_buf_t str)
{
  dtp_t str_type = DV_TYPE_OF (str);
  /*dtp_t str_first;*/
  if (str_type != DV_LONG_CONT_STRING &&
    str_type != DV_SHORT_CONT_STRING &&
    str_type != DV_LONG_STRING &&
    str_type != DV_SHORT_STRING &&
    str_type != DV_REFERENCE)
  {
    sqlr_new_error ("22023", "SR062", "Row in a row function is not a valid row string.");
  }
/*  str_first = str[0];
  if (str_first != DV_LONG_CONT_STRING && str_first != DV_SHORT_CONT_STRING)
  sqlr_new_error ("22023", "SR063", "row string must begin with container header");*/
}


caddr_t
row_str_table (caddr_t * qst, db_buf_t str)
{
#ifndef KEYCOMP
  query_instance_t *qi = (query_instance_t *) QST_INSTANCE (qst);
  dbe_schema_t *sc = isp_schema (qi->qi_space);
  dbe_key_t *key;
  key_id_t k_id;

  row_str_check (str);

  k_id = SHORT_REF (str + IE_KEY_ID);

  key = sch_id_to_key (sc, k_id);
  if (!key)
    {
      return (NEW_DB_NULL);
    }
  return (box_dv_short_string (key->key_table->tb_name));
#else
  KEYCOMP; return 0;
#endif
}


caddr_t
bif_row_table (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  db_buf_t str = (db_buf_t) bif_arg (qst, args, 0, "row_table");
  return (row_str_table (qst, str));
}


#define DEFAULT_EXISTING 1


caddr_t
row_str_column (caddr_t * qst, db_buf_t str, char *tb_name, char *col_name,
  int *exists)
{
#ifndef KEYCOMP

  it_cursor_t ref_itc;
  caddr_t val;
  query_instance_t *qi = (query_instance_t *) QST_INSTANCE (qst);
  dbe_schema_t *sc = wi_inst.wi_schema;
  dbe_key_t *key;
  dbe_table_t *tb = NULL;
  dbe_column_t *col;
  key_id_t k_id;
  dbe_col_loc_t *cl;

  row_str_check (str);
  k_id = SHORT_REF (str + IE_KEY_ID);

  key = sch_id_to_key (sc, k_id);
  if (!key)
    return NEW_DB_NULL;

  memset (&ref_itc, 0, sizeof (ref_itc));
  itc_from (&ref_itc, key);
  ref_itc.itc_position = 0;
  ref_itc.itc_row_data = str + IE_FIRST_KEY;

  tb = qi_name_to_table (qi, tb_name);
  if (!tb)
    return NEW_DB_NULL;
  col = tb_name_to_column (tb, col_name);
  if (!col)
    return NEW_DB_NULL;
  if (DV_TYPE_OF (str) != DV_REFERENCE)
    {
      cl = key_find_cl (key, col->col_id);
    }
  else
    {
      cl = cl_list_find (key->key_key_fixed, col->col_id);
      if (!cl)
  cl = cl_list_find (key->key_key_var, col->col_id);
    }
  if (!cl)
    return NEW_DB_NULL;
  *exists = 1;
  val = itc_box_column (&ref_itc, str, col->col_id, cl);
  return val;
#else
  KEYCOMP; return 0;
#endif
}


caddr_t
bif_row_column (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  db_buf_t str = (db_buf_t) bif_arg (qst, args, 0, "row_table");
  caddr_t tb = bif_string_arg (qst, args, 1, "row_column");
  caddr_t col = bif_string_arg (qst, args, 2, "row_column");
  long n_args = BOX_ELEMENTS (args);
  int exists = 0;
  caddr_t res = row_str_column (qst, str, tb, col, &exists);
  if (4 == n_args)
    qst_set (qst, args[3], box_num (exists));
  return res;
}


caddr_t
row_identity (db_buf_t row)
{
#ifndef KEYCOMP
  it_cursor_t ref_itc, *itc = &ref_itc;
  dbe_col_loc_t * cl;
  int len;
  db_buf_t row_data;
  dbe_schema_t *sc = wi_inst.wi_schema;
  key_id_t key_id = SHORT_REF (row + IE_KEY_ID);
  dbe_key_t * key = key_id ? sch_id_to_key (sc, key_id) : NULL;
  dtp_t image[PAGE_DATA_SZ];
  db_buf_t res = &image[0];
  int inx = 0, prev_end = 0;
  caddr_t res_box;

  if (!key_id)
    return NEW_DB_NULL;
  memset (itc, 0, sizeof (ref_itc));
  itc_from (itc, key);
  SHORT_SET (res + IE_NEXT_IE, 0);
  SHORT_SET (res + IE_KEY_ID, key_id);
  res += 4;
  row_data = row + IE_FIRST_KEY;
  if (key->key_key_fixed)
    {
      for (inx = 0; key->key_key_fixed[inx].cl_col_id; inx++)
  {
    int off;
    cl = &key->key_key_fixed[inx];
    off = cl->cl_pos;
    memcpy (res + off, row_data + off, cl->cl_fixed_len);
    if (cl->cl_null_mask)
      res[cl->cl_null_flag] = row_data[cl->cl_null_flag];
    /* copy the byte since all parts have their bit copied */
  }
    }
  if (key->key_key_var)
    {
      itc->itc_row_data = row_data;
      prev_end = key->key_key_var_start;
      for (inx = 0; key->key_key_var[inx].cl_col_id; inx++)
  {
    int off;
    cl = &key->key_key_var[inx];
    ITC_COL (itc, (*cl), off, len);
    memcpy (res + prev_end, row_data + off, len);
    if (0 == inx)
      SHORT_SET (res + key->key_length_area, len + prev_end);
    else
      SHORT_SET ((res - cl->cl_fixed_len) + 2, len + prev_end);
    prev_end = prev_end + len;
    if (cl->cl_null_mask)
      res[cl->cl_null_flag] = row_data[cl->cl_null_flag];
    /* copy the byte since all parts have their bit copied */
  }
    }
  res_box = dk_alloc_box (4 + prev_end, DV_REFERENCE);
  if (4 + prev_end)
    memcpy (res_box, &image[0], 4 + prev_end);
  return res_box;
#else
  KEYCOMP; return 0;
#endif
}


caddr_t
bif_row_identity (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  db_buf_t row = (db_buf_t) bif_arg (qst, args, 0, "row_deref");
  row_str_check (row);
  return (row_identity (row));
}


#ifndef NDEBUG
dp_addr_t dbg_row_deref_page;
int dbg_row_deref_pos;

caddr_t
bif_dbg_row_deref_page (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return (box_num (dbg_row_deref_page));
}


caddr_t
bif_dbg_row_deref_pos (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return (box_num (dbg_row_deref_pos));
}



#endif


void
row_deref (caddr_t * qst, caddr_t id, placeholder_t **place_ret, caddr_t * row_ret, int lock_mode)
{
#ifndef KEYCOMP
  int res;
  query_instance_t *qi = (query_instance_t *) QST_INSTANCE (qst);
  it_cursor_t volatile *ref_itc = itc_create (qi->qi_space, qi->qi_trx);
  buffer_desc_t *ref_buf;
  key_id_t key_id = SHORT_REF (id + IE_KEY_ID);
  dbe_key_t *key = key_id ? sch_id_to_key (isp_schema (NULL), key_id) : NULL;

  if (!key_id)
    return;
  itc_from ((ITC) ref_itc, key);
  itc_make_deref_spec ((ITC) ref_itc, (db_buf_t) id);

  ref_itc->itc_lock_mode = lock_mode;
  ref_itc->itc_search_mode = SM_READ;

  ITC_FAIL (ref_itc)
    {
      ref_buf = itc_reset ((ITC) ref_itc);
      res = itc_search ((ITC) ref_itc, &ref_buf);
      if (res == DVC_MATCH)
	{
	  if (row_ret)
	    {
	      dbe_key_t *cr_key = itc_get_row_key ((ITC) ref_itc, ref_buf);
	      if (cr_key->key_is_primary)
		{
		  *row_ret =
		      itc_box_row ((ITC) ref_itc, ref_buf->bd_buffer);
#ifndef NDEBUG
		  dbg_row_deref_page = ref_itc -> itc_page;
		  dbg_row_deref_pos = ref_itc -> itc_position;
#endif
		}
	      else
		{
		  it_cursor_t *main_itc =
		      itc_create (NULL, ref_itc->itc_ltrx);
		  caddr_t row = deref_node_main_row ((ITC) ref_itc, &ref_buf,
		      cr_key->key_table->tb_primary_key, main_itc);
		  if (!row)
		    {
		      itc_free ((ITC) ref_itc);
		      itc_free (main_itc);
		      return;
		    }
		  itc_free ((ITC) ref_itc);
		  ref_itc = main_itc;
		  *row_ret = row;

		}
	    }
	  if (place_ret)
	    {
	      NEW_PLH (pl);
	      ITC_IN_KNOWN_MAP (ref_itc, ref_itc->itc_page);
	      memcpy (pl, (ITC) ref_itc, ITC_PLACEHOLDER_BYTES);
	      pl->itc_type = ITC_PLACEHOLDER;
	      itc_register ((it_cursor_t *) pl, ref_buf);
	      *place_ret = pl;
	    }
	}
	  itc_page_leave ((ITC) ref_itc, ref_buf);
	}
      ITC_FAILED
	{
      if (ref_itc)
	{
	  itc_free ((ITC) ref_itc);
	  ref_itc = NULL;
	}
    }
  END_FAIL ((ITC) ref_itc);
  if (ref_itc)
    itc_free ((ITC) ref_itc);
#else
  KEYCOMP;
#endif
}


caddr_t
bif_row_deref (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t row = NULL;
  caddr_t id = bif_arg (qst, args, 0, "row_deref");
  int lock_mode = PL_SHARED;
  int n_args = BOX_ELEMENTS (args);
  if (n_args > 1 && bif_long_arg (qst, args, 1, "row_deref"))
  lock_mode = PL_EXCLUSIVE;
  row_str_check ((db_buf_t) id);
  row = NULL;
  row_deref (qst, id, NULL, &row, lock_mode);
  if (!row)
    return (NEW_DB_NULL);
  else
    return row;
}


caddr_t
bif_page_dump (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;
  long volatile dp = (long) bif_long_arg (qst, args, 0, "page_dump");
  buffer_desc_t buf_auto;
  ALIGNED_PAGE_BUFFER (bd_buffer);
  buffer_desc_t *buf = NULL;
  it_cursor_t itc_auto, *itc = &itc_auto;

  sec_check_dba (qi, "page_dump");

  memset (&itc_auto, 0, sizeof (itc_auto));
  ITC_INIT (itc, NULL, qi->qi_trx);

  DO_SET (index_tree_t *, it, &wi_inst.wi_master->dbs_trees)
  {
    itc_from_it (itc, it);
    ITC_IN_KNOWN_MAP (itc, dp);
    buf = (buffer_desc_t *) gethash (DP_ADDR2VOID (dp), &IT_DP_MAP (it, dp)->itm_dp_to_buf);
    if (buf)
      {
	ITC_LEAVE_MAP_NC (itc);
	col_ac_set_dirty (qst, args, itc, buf, 5, 10);
	dbg_page_map (buf);
	return 0;
      }
    ITC_LEAVE_MAP_NC (itc);
  }
  END_DO_SET ();

  buf = &buf_auto;
  memset (&buf_auto, 0, sizeof (buf_auto));
  buf->bd_buffer = bd_buffer;
  buf->bd_page = buf->bd_physical_page = dp;
  buf->bd_storage = wi_inst.wi_master;
  if (WI_ERROR == buf_disk_read (buf))
    {
      sqlr_new_error ("42000", "SR459", "Error reading page %ld", dp);
    }
  else
    {
      itc_from_it (itc, buf->bd_tree);
      col_ac_set_dirty (qst, args, itc, buf, 5, 10);
    dbg_page_map (buf);
    }
  if (buf->bd_content_map)
    resource_store (PM_RC (buf->bd_content_map->pm_size), (void *) buf->bd_content_map);

  return 0;
}


caddr_t
bif_mem_enter_reserve_mode (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;

  sec_check_dba (qi, "mem_enter_reserve_mode");

  dk_alloc_set_reserve_mode (DK_ALLOC_RESERVE_IN_USE);
  return box_num (DK_ALLOC_ON_RESERVE ? 1 : 0);
}


caddr_t
bif_mem_debug_enabled (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
#ifdef MALLOC_DEBUG
  return box_num (1);
#else
  return box_num (0);
#endif
}


#ifdef MALLOC_DEBUG
caddr_t
bif_mem_all_in_use (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char *dp = bif_string_or_null_arg (qst, args, 0, "mem_all_in_use");
  FILE *fd = dp ? fopen (dp, "at") : NULL;
  int nth = BOX_ELEMENTS (args) > 1 ? bif_long_arg (qst, args, 1, "mem_all_in_use") : 0;
  dbg_malstats (fd ? fd : stderr, DBG_MALSTATS_ALL);
  if (fd)
  fclose (fd);
  return NULL;
}


caddr_t
bif_mem_new_in_use (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char *dp = bif_string_or_null_arg (qst, args, 0, "mem_new_in_use");
  FILE *fd = dp ? fopen (dp, "at") : NULL;
  int nth = BOX_ELEMENTS (args) > 1 ? bif_long_arg (qst, args, 1, "mem_all_in_use") : 0;
  dbg_malstats (fd ? fd : stderr, DBG_MALSTATS_NEW);
  if (fd)
  fclose (fd);
  return NULL;
}


caddr_t
bif_mem_leaks (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char *dp = bif_string_or_null_arg (qst, args, 0, "mem_leaks");
  FILE *fd = dp ? fopen (dp, "at") : NULL;
  dbg_malstats (fd ? fd : stderr, DBG_MALSTATS_LEAKS);
  if (fd)
  fclose (fd);
  return NULL;
}
#endif


caddr_t bif_mem_get_current_total (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
#ifdef MALLOC_DEBUG
  return box_num (dbg_malloc_get_current_total());
#else
  return NULL;
#endif
}


caddr_t
bif_mem_summary (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char *dp = bif_string_or_null_arg (qst, args, 0, "mem_summary");
  return NULL;
}


#ifdef MALLOC_STRESS
caddr_t
bif_set_hard_memlimit (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;
  ptrlong consumption = bif_long_arg (qst, args, 0, "set_hard_memlimit");

  sec_check_dba (qi, "set_hard_memlimit");

  dbg_malloc_set_hard_memlimit ((size_t) consumption);

  return box_num (consumption);
}

caddr_t
bif_set_hit_memlimit (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;
  caddr_t name = bif_string_arg (qst, args, 0, "set_hit_memlimit");
  ptrlong consumption = bif_long_arg (qst, args, 1, "set_hit_memlimit");

  sec_check_dba (qi, "set_hit_memlimit");

  dbg_malloc_set_hit_memlimit (box_uname_string (name), consumption);

  return box_num (consumption);
}
#endif


void
bif_convert_type (state_slot_t ** args, long *dtp, long *prec, long *scale, collation_t **collation)
{
  long *type = (long *) args[0]->ssl_constant;
  if (!type)
  return;
  *dtp = type[0];
  *prec = type[1];
  *scale = BOX_ELEMENTS (type) > 2 ? type[2] : 0;
  *collation = BOX_ELEMENTS (args) > 2 ? sch_name_to_collation (args[2]->ssl_constant) : NULL;
}


bif_type_t bt_convert = { (bif_type_func_t) bif_convert_type, 0, 0, 0};

void
bif_string_type (state_slot_t ** args, long *dtp, long *prec, long *scale, collation_t **collation)
{
  state_slot_t *sl;
  int n;
  int nWides = 0;
  for (n = 0; ((uint32) n) < BOX_ELEMENTS (args); n++)
  {
    sl = args[n];
    if (IS_WIDE_STRING_DTP (sl->ssl_sqt.sqt_dtp) ||
    sl->ssl_sqt.sqt_dtp == DV_BLOB_WIDE_HANDLE ||
    sl->ssl_sqt.sqt_dtp == DV_BLOB_WIDE)
  {
    nWides = 1;
    break;
  }
  }
  *dtp = nWides ? DV_WIDE : DV_LONG_STRING;
  *prec = 0;
  *scale = 0;
  *collation = NULL;
}

bif_type_t bt_string = { (bif_type_func_t) bif_string_type, 0, 0, 0};

caddr_t string_to_dt_box (char * data);
caddr_t string_to_time_dt_box (char * data);

#define NUMCK(rc) \
  if (rc != NUMERIC_STS_SUCCESS) \
  sqlr_new_error ("22015", "SR064", "Conversion overflow from numeric");

int64 num_precs[19];

boxint
num_check_prec (boxint val, int prec, char *title, caddr_t *err_ret)
{
  int64 prec_upper, prec_lower;
  if (19 <= prec || !prec)
    return val;
  prec_upper = num_precs[prec];
  prec_lower = - prec_upper;
  if (val >= prec_lower && val <= prec_upper)
    return val;
  else
  {
    caddr_t err =
        srv_make_new_error ("22023", "SR346",
      "precision (%d) overflow in %s",
			    prec, title);
    if (err_ret)
      *err_ret = err;
    else
      sqlr_resignal (err);
    return 0;
  }
}


caddr_t
box_cast (caddr_t * qst, caddr_t data, ST * dtp, dtp_t arg_dtp)
{
  caddr_t err;
  if (arg_dtp == DV_DB_NULL)
    return (dk_alloc_box (0, DV_DB_NULL));
  if (!ARRAYP (dtp) || 0 == BOX_ELEMENTS (dtp))
    sqlr_new_error ("22023", "SR066", "Unsupported case in CONVERT (%s -> <unknown type>)", dv_type_title(arg_dtp));
  if (DV_RDF == arg_dtp)
    {
      rdf_box_t *rb = (rdf_box_t *)data;
      rdf_box_audit(rb);
      if (DV_RDF == dtp->type)
        {
          rb->rb_ref_count++;
          return data;
        }
      if (0 == rb->rb_is_complete)
#ifdef DEBUG
        sqlr_new_error ("22023", (IS_BOX_POINTER (qst) && (((query_instance_t *)qst)->qi_no_cast_error)) ? "sR066" : "SR066", "Unsupported case in CONVERT (incomplete RDF box -> %s)", dv_type_title((int) (dtp->type)));
#else
        sqlr_new_error ("22023", "SR066", "Unsupported case in CONVERT (incomplete RDF box -> %s)", dv_type_title((int) (dtp->type)));
#endif
      data = rb->rb_box;
      arg_dtp = DV_TYPE_OF (data);
      if (DV_STRING == arg_dtp)
        box_flags (data) |= BF_UTF8;
    }
  switch (dtp->type)
    {
      case DV_STRING: goto do_long_string;
    case DV_LONG_INT: case DV_INT64: case DV_SHORT_INT: goto do_long_int;
      case DV_SINGLE_FLOAT: goto do_single_float;
      case DV_DOUBLE_FLOAT: goto do_double_float;
      case DV_NUMERIC: goto do_numeric;
      case DV_DATETIME: case DV_DATE: case DV_TIMESTAMP: goto do_datetime;
      case DV_BIN: case DV_LONG_BIN: goto do_bin;
      case DV_TIME: goto do_time;
      case DV_WIDE: case DV_LONG_WIDE: goto do_wide;
      case DV_ANY: goto do_any;
    case DV_IRI_ID: case DV_IRI_ID_8:
      if (DV_IRI_ID == arg_dtp)
	return box_copy (data);
      goto cvt_error;
    default: goto cvt_error;
    }

do_long_string:
    {
      char tmp[NUMERIC_MAX_STRING_BYTES + 500];
      /* long enough for max double exponent worth of 0's */
      /* long len = (long) dtp -> _.op.arg_1; */
      switch (arg_dtp)
	{
	  case DV_LONG_INT:
	  case DV_SHORT_INT:
	      snprintf (tmp, sizeof (tmp), BOXINT_FMT, unbox (data));
	      break;
	  case DV_SINGLE_FLOAT:
	      snprintf (tmp, sizeof (tmp), "%.16g", unbox_float (data));
	      break;
	  case DV_DOUBLE_FLOAT:
	      snprintf (tmp, sizeof (tmp), "%.16g", unbox_double (data));
	      break;
	  case DV_STRING_SESSION:
		{
		  caddr_t ret;
		  int bytes = strses_length ((dk_session_t*)data);
		  if (bytes >= 10000000)
		    sqlr_new_error ("22003", "SR0??",
			"The requested string session is longer than 10Mb, thus it cannot be stored as a string");
		  ret = dk_alloc_box (bytes + 1, DV_LONG_STRING);
		  strses_to_array ((dk_session_t*)data, ret);
		  ret[bytes]='\0';
		  return ret;
		}
	  case DV_NUMERIC:
	      numeric_to_string ((numeric_t) data, tmp, sizeof (tmp));
	      break;
	  case DV_STRING:
	      return (box_copy (data));
	  case DV_UNAME:
              {
                caddr_t res = box_dv_short_nchars (data, box_length (data)-1);
                box_flags (res) |= BF_IRI;
                return res;
              }
	  case DV_C_STRING:
	      return (box_dv_short_string (data));
	  case DV_LONG_CONT_STRING:
	  case DV_SHORT_CONT_STRING:
		{
		  int l = box_length (data);
		  caddr_t res = dk_alloc_box (l + 1, DV_LONG_STRING);
		  memcpy (res, data, l);
		  res[l] = 0;
		  return res;
		}
	  case DV_SYMBOL:
	      return (box_dv_short_string (data));
	  case DV_DATETIME:
		{
		  char tmp [100];
		  dt_to_string (data, tmp, sizeof (tmp));
		  return (box_dv_short_string (tmp));
		}
	  case DV_BIN:
		{
		  long len = box_length (data);
		  caddr_t res = dk_alloc_box (len + 1, DV_STRING);
		  memcpy (res, data, len);
		  res[len] = 0;
		  return res;
		}

	  case DV_WIDE:
	  case DV_LONG_WIDE:
		{
		  return box_wide_string_as_narrow (data, NULL, 0, qst ? QST_CHARSET (qst) : NULL);
		}

	  case DV_BLOB_HANDLE:
	  case DV_BLOB_WIDE_HANDLE:
		{
		  query_instance_t * qi = (query_instance_t *) qst;
		  caddr_t ret;
		  blob_handle_t * bh = (blob_handle_t *) data;
		  if (!qst)
		    sqlr_new_error ("22023", "SRUUU",
			"Can't convert data to varchar.");
		  if (bh->bh_ask_from_client)
		    sqlr_new_error ("22023", "SR065",
			"Can't convert SQL_DATA_AT_EXEC blob to varchar. "
			"Parameter may only be used in insert or update");
		  ret = blob_to_string (qi->qi_trx, data);
		  if (!DV_STRINGP (ret))
		    {
		      caddr_t ret1;
                      err = NULL;
		      ret1 = box_cast_to (qst, ret, DV_TYPE_OF (ret), DV_SHORT_STRING,
			  NUMERIC_MAX_PRECISION, NUMERIC_MAX_SCALE, &err);

		      dk_free_box (ret);
		      if (err)
			goto inner_error;
		      ret = ret1;
		    }
		  return ret;
		}
#ifdef BIF_XML
	  case DV_XML_ENTITY:
		{
		  caddr_t res = NULL;
		  xe_sqlnarrow_string_value ((xml_entity_t *)(data), &res, DV_LONG_STRING);
		  return res;
		}
#endif
	  case DV_ARRAY_OF_XQVAL:
		{
		  size_t ctr, els = BOX_ELEMENTS(data);
		  caddr_t *subresults = (caddr_t *)dk_alloc_box_zero(els * sizeof(caddr_t), DV_ARRAY_OF_POINTER);
		  size_t res_len = 0, res_fill = 0;
		  caddr_t res = NULL;
                  err = NULL;
		  QR_RESET_CTX
		    {
		      for (ctr = 0; ctr < els; ctr++)
			{
			  caddr_t subdatum = ((caddr_t *)(data))[ctr];
			  if (NULL != subdatum)
			    {
			      subresults[ctr] = box_cast (qst, subdatum, dtp, DV_TYPE_OF(subdatum));
			      res_len += box_length(subresults[ctr])-1;
			    }
			}
		    }
		  QR_RESET_CODE
		    {
		      du_thread_t *self = THREAD_CURRENT_THREAD;
		      err = thr_get_error_code (self);
                      dk_free_tree (subresults);
		    }
		  END_QR_RESET;
                  if (err)
                    goto inner_error;
		  res = dk_alloc_box (res_len+1, DV_SHORT_STRING);
		  for (ctr = 0; ctr < els; ctr++)
		    {
		      caddr_t subres = subresults[ctr];
		      if (NULL != subres)
			{
			  size_t sublen = box_length(subres)-1;
			  memcpy (res+res_fill, subres, sublen);
			  res_fill += sublen;
			}
		    }
		  res[res_fill] = '\0';
		  dk_free_tree ((box_t) subresults);
		  return res;

		}
	  case DV_XML_DTD:
		{
		  dtd_t *dtd = ((dtd_t **) data)[0];
		  dk_session_t * ses = strses_allocate ();
		  caddr_t res;
		  dtd_serialize (dtd, ses);
		  if (!STRSES_CAN_BE_STRING (ses))
		    {
		      dk_free_box ((box_t) ses);
		      sqlr_resignal (STRSES_LENGTH_ERROR ("CONVERT"));
		    }
		  res = strses_string (ses);
		  dk_free_box ((box_t) ses);
		  return res;
		}
	  case DV_IRI_ID: /* TBD: 64bit case */
		{
		  iri_id_t iid = unbox_iri_id (data);
                  if (iid >= MIN_64BIT_BNODE_IRI_ID)
                    snprintf (tmp, sizeof (tmp), "#ib" IIDBOXINT_FMT, (boxint)(iid-MIN_64BIT_BNODE_IRI_ID));
                  else
                    snprintf (tmp, sizeof (tmp), "#i" IIDBOXINT_FMT, (boxint)(iid) );
		  break;
		}
	case DV_GEO:
	  return geo_wkt (data);
	  default:
	      goto cvt_error;
	}
      return (box_dv_short_string (tmp));
    }

do_long_int:
    {
      int prec = BOX_ELEMENTS (dtp) > 1 ? (int) (unbox (((caddr_t *) dtp)[1])) : 0;
      boxint val;
      err = NULL;
      switch (arg_dtp)
	{
	  case DV_LONG_INT:
	  case DV_SHORT_INT:
	      val = unbox (data); break;
	  case DV_SINGLE_FLOAT:
	      val = (boxint) unbox_float (data); break;
	  case DV_DOUBLE_FLOAT:
	      val = (boxint) unbox_double (data); break;
	  case DV_STRING:
		val = safe_atoi (data, &err);
                break;
#ifdef BIF_XML
	  case DV_XML_ENTITY:
		{
		  caddr_t tmp_res = NULL;
		  xe_sqlnarrow_string_value ((xml_entity_t *)(data), &tmp_res, DV_LONG_STRING);
		  val = safe_atoi (tmp_res, &err);
		  dk_free_box (tmp_res);
                  break;
		}
#endif
	  case DV_NUMERIC:
		{
		  int64 i;
		  NUMCK (numeric_to_int64 ((numeric_t) data, &i));
		  val = i;
		  break;
		}
	  case DV_WIDE:
	  case DV_LONG_WIDE:
		{
		  char narrow [512];
		  box_wide_string_as_narrow (data, narrow, 512, qst ? QST_CHARSET (qst) : NULL);
		  val = safe_atoi (narrow, &err);
                  break;
		}
	  default:
	      goto cvt_error;
	}
      if (err)
        goto inner_error;
      return box_num (num_check_prec (val, prec, "CONVERT", NULL));
    }

do_single_float:
    {
      switch (arg_dtp)
	{
	  case DV_LONG_INT:
	  case DV_SHORT_INT:
	      return (box_float ((float) unbox (data)));
	  case DV_SINGLE_FLOAT:
	      return (box_float ((float) unbox_float (data)));
	  case DV_DOUBLE_FLOAT:
	      return (box_float ((float) unbox_double (data)));
	  case DV_STRING:
            {
	      double d;
              err = NULL;
              d = safe_atof (data, &err);
              if (err)
                goto inner_error;
              return (box_float ((float)d));
            }
	  case DV_NUMERIC:
		{
		  double dt;
		  NUMCK (numeric_to_double ((numeric_t) data, &dt));
		  return (box_float ((float)dt));
		}
	  case DV_WIDE:
	  case DV_LONG_WIDE:
            {
              char narrow [512];
	      double d;
              err = NULL;
              box_wide_string_as_narrow (data, narrow, 512, qst ? QST_CHARSET (qst) : NULL);
              d = safe_atof (narrow, &err);
              if (err)
                goto inner_error;
              return (box_float ((float)d));
            }
	  default:
	      goto cvt_error;
	}
    }

do_double_float:
    {
      switch (arg_dtp)
	{
	  case DV_LONG_INT:
	  case DV_SHORT_INT:
	      return (box_double ((double) unbox (data)));
	  case DV_SINGLE_FLOAT:
	      return (box_double ((double) unbox_float (data)));
	  case DV_DOUBLE_FLOAT:
	      return (box_double ((double) unbox_double (data)));
	  case DV_LONG_STRING:
		{
		  double d = 0.0;
                  const char *start = numeric_from_string_is_ok (data);
                  if (NULL == start)
                    goto cvt_error;
		  if (1 == sscanf (start, "%lf", &d))
		    return (box_double (d));
		  goto cvt_error;
		}
	  case DV_NUMERIC:
		{
		  double dt;
		  NUMCK (numeric_to_double ((numeric_t) data, &dt));
		  return (box_double (dt));
		}
	  case DV_WIDE:
	  case DV_LONG_WIDE:
		{
		  char narrow [512];
		  double d = 0.0;
                  const char *start;
		  box_wide_string_as_narrow (data, narrow, 512, qst ? QST_CHARSET (qst) : NULL);
		  /* return (box_double (atof (narrow)));*/
                  start = numeric_from_string_is_ok (narrow);
                  if (NULL == start)
                    goto cvt_error;
		  if (1 == sscanf (start, "%lf", &d))
		    return (box_double (d));
		  goto cvt_error;
		}
	  default:
	      goto cvt_error;
	}
    }

do_numeric:
    {
      numeric_t res = numeric_allocate ();
      err = numeric_from_x (res, data, (int) unbox (((caddr_t*)dtp)[1]), (int) unbox (((caddr_t*)dtp)[2]), "CAST", 0, NULL);
      if (err)
	{
	  numeric_free (res);
          goto inner_error;
	}
      return ((caddr_t) res);
    }

do_datetime:
    {
      caddr_t res;
      switch (arg_dtp)
	{
	case DV_STRING:
	  res = string_to_dt_box (data);
          break;
	case DV_DATETIME:
	case DV_DATE:
	case DV_TIME:
	  res = box_copy_tree (data);
          break;
	case DV_BIN:
	  if (dt_validate (data))
	    sqlr_new_error ("22003", "SR351",
	      "Invalid data supplied in VARBINARY -> DATETIME conversion");
	  res = box_copy (data);
	  box_tag_modify (res, DV_DATETIME);
	  break;
	  case DV_WIDE:
	case DV_LONG_WIDE:
	  {
	    caddr_t narrow = box_wide_string_as_narrow (data, NULL, 0, qst ? QST_CHARSET (qst) : NULL);
	    res = string_to_dt_box (narrow);
	    dk_free_box (narrow);
            break;
	  }
	default:
	  goto cvt_error;
	}
      if (ST_P (dtp, DV_DATE))
	{
	  dt_date_round (res);
	}
      else if (ST_P (dtp, DV_DATE) || ST_P (dtp, DV_TIME))
	{
	  DT_SET_FRACTION (res, 0);
	}
      SET_DT_TYPE_BY_DTP (res, dtp->type);
      return res;
    }

do_time:
    {
      caddr_t res;
      switch (arg_dtp)
	{
	  case DV_SHORT_STRING:
	      res = string_to_time_dt_box (data);
	      return res;
	  case DV_DATETIME:
	  case DV_TIMESTAMP:
		{
		  res = box_copy_tree (data);
		  dt_make_day_zero (res);
		  return res;
		}
	  case DV_TIME:
	      return box_copy_tree (data);
	  case DV_WIDE:
	  case DV_LONG_WIDE:
		{
		  caddr_t narrow = box_wide_string_as_narrow (data, NULL, 0, qst ? QST_CHARSET (qst) : NULL);
		  res = string_to_time_dt_box (narrow);
		  dk_free_box (narrow);
		  return res;
		}

	  default:
	      goto cvt_error;
	}
    }

do_any:
  return box_copy_tree (data);

do_bin:
    {
      if (IS_BOX_POINTER (data))
	{
	  long len = box_length (data);
	  caddr_t tmp_res = NULL;
	  caddr_t res;
	  if (arg_dtp == DV_SHORT_STRING || arg_dtp == DV_LONG_STRING)
	    len--;
do_bin_again:
	  if (IS_WIDE_STRING_DTP (arg_dtp))
	    {
	      long utf8_len;
	      virt_mbstate_t state;
	      wchar_t *wide = (wchar_t *) data;
	      wchar_t *wide_work;
	      int wide_len = box_length (data) / sizeof (wchar_t) - 1;

	      wide_work = wide;
	      memset (&state, 0, sizeof (virt_mbstate_t));
	      utf8_len = (long) virt_wcsnrtombs (NULL, &wide_work, wide_len, 0, &state);
	      if (utf8_len < 0)
		sqlr_new_error ("22005", "IN014",
		    "Invalid data supplied in NVARCHAR -> VARBINARY conversion");
	      res = dk_alloc_box (utf8_len, DV_BIN);

	      wide_work = wide;
	      memset (&state, 0, sizeof (virt_mbstate_t));
	      if (utf8_len != virt_wcsnrtombs ((unsigned char *) res, &wide_work, wide_len, utf8_len, &state))
		GPF_T1("non consistent wide char to multi-byte translation of a buffer");
	      if (NULL != tmp_res)
		dk_free_box (tmp_res);
	      return res;
	    }
	  if (DV_BLOB_HANDLE == arg_dtp || DV_BLOB_WIDE_HANDLE == arg_dtp)
	    {
	      query_instance_t * qi = (query_instance_t *) qst;
	      caddr_t ret;
	      blob_handle_t * bh = (blob_handle_t *) data;
	      if (!qst)
		sqlr_new_error ("22023", "SRUUU",
		    "Can't convert data to varchar.");
	      if (bh->bh_ask_from_client)
		sqlr_new_error ("22023", "SR065",
		    "Can't convert SQL_DATA_AT_EXEC blob to varbinary. "
		    "Parameter may only be used in insert or update");
	      ret =  blob_to_string (qi->qi_trx, data);
	      arg_dtp = (dtp_t)DV_TYPE_OF (ret);
	      if (IS_WIDE_STRING_DTP (arg_dtp))
		{
		  tmp_res = ret;
		  data = ret;
		  goto do_bin_again;
		}
	      return ret;
	    }
	  res = dk_alloc_box (len, DV_BIN);
	  memcpy (res, data, len);
	  return res;
	}
    }
  goto cvt_error;

do_wide:
    {
      char tmp[NUMERIC_MAX_STRING_BYTES + 100];
      caddr_t ret;
      err = NULL;
      switch (arg_dtp)
	{
	case DV_STRING:
	  ret = box_narrow_string_as_wide ((unsigned char *) data, NULL, 0, qst ? QST_CHARSET (qst) : NULL, &err, 1);
          if (err)
            goto inner_error;
	  return ret;
	  case DV_UNAME:
            {
              unsigned char *utf8 = (unsigned char *) data;
              unsigned char *utf8work;
              size_t utf8_len = box_length (data) - 1;
              size_t wide_len;
              virt_mbstate_t state;
              utf8work = utf8;
              memset (&state, 0, sizeof (virt_mbstate_t));
              wide_len = virt_mbsnrtowcs (NULL, &utf8work, utf8_len, 0, &state);
              if (((long) wide_len) < 0)
	        sqlr_new_error ("22005", "IN015",
	          "Invalid data supplied in UNAME -> NVARCHAR conversion");
              ret = dk_alloc_box ((int) (wide_len  + 1) * sizeof (wchar_t), DV_WIDE);
              utf8work = utf8;
              memset (&state, 0, sizeof (virt_mbstate_t));
              if (wide_len != virt_mbsnrtowcs ((wchar_t *) ret, &utf8work, utf8_len, wide_len, &state))
                {
                  dk_free_box (ret);
	          sqlr_new_error ("22005", "IN015",
	            "Inconsistent UTF-8 data supplied in UNAME -> NVARCHAR conversion");
                }
              ((wchar_t *)ret)[wide_len] = L'\0';
              return ret;
            }
	  case DV_DATETIME:
	  case DV_DATE:
	  case DV_TIME:
	      dt_to_string (data, tmp, sizeof (tmp));
	      break;
	  case DV_NUMERIC:
	      numeric_to_string ( (numeric_t) data, tmp, sizeof (tmp));
	      break;
	  case DV_WIDE:
	  case DV_LONG_WIDE:
	      return (box_copy (data));
	  case DV_BIN:
		{
		  caddr_t res = box_utf8_as_wide_char (data, NULL, box_length (data), 0, DV_WIDE);
		  if (res)
		    return res;
		  else
		    sqlr_new_error ("22005", "IN015",
			"Invalid data supplied in VARBINARY -> NVARCHAR conversion");
		  break;
		}
	  case DV_LONG_INT:
	  case DV_SHORT_INT:
	      snprintf (tmp, sizeof (tmp), BOXINT_FMT, unbox (data));
	      break;
	  case DV_SINGLE_FLOAT:
	      snprintf (tmp, sizeof (tmp), "%f", unbox_float (data));
	      break;
	  case DV_DOUBLE_FLOAT:
	      snprintf (tmp, sizeof (tmp), "%f", unbox_double (data));
	      break;
	  case DV_BLOB_HANDLE:
	  case DV_BLOB_WIDE_HANDLE:
		{
		  query_instance_t * qi = (query_instance_t *) qst;
		  caddr_t ret;
		  blob_handle_t * bh = (blob_handle_t *) data;
		  if (!qst)
		    sqlr_new_error ("22023", "SRUUU",
			"Can't convert data to varchar.");
		  if (bh->bh_ask_from_client)
		    sqlr_new_error ("22023", "SR065",
			"Can't convert SQL_DATA_AT_EXEC blob to varchar. "
			"Parameter may only be used in insert or update");
		  ret =  blob_to_string (qi->qi_trx, data);
		  if (arg_dtp == DV_BLOB_HANDLE)
		    {
		      caddr_t wide_ret = box_narrow_string_as_wide ((unsigned char *) ret,
			  NULL, 0, qst ? QST_CHARSET (qst) : NULL, &err, 1);
		      dk_free_box (ret);
                      if (err)
                        goto inner_error;
		      return wide_ret;
		    }
		  return ret;
		}

	  default:
	      goto cvt_error;
	}
      ret = box_narrow_string_as_wide ((unsigned char *) tmp, NULL, 0, qst ? QST_CHARSET (qst) : NULL, &err, 0);
      if (err)
	sqlr_resignal (err);
      return ret;
    }
  goto cvt_error;

inner_error:
  if (!IS_BOX_POINTER (qst) || !(((query_instance_t *)qst)->qi_no_cast_error))
    sqlr_resignal (err);
  dk_free_tree (err);
  return NEW_DB_NULL;

cvt_error:
  if (IS_BOX_POINTER (qst) && (((query_instance_t *)qst)->qi_no_cast_error))
    return NEW_DB_NULL;
#ifdef DEBUG
  sqlr_new_error ("22023", (IS_BOX_POINTER (qst) && (((query_instance_t *)qst)->qi_no_cast_error)) ? "sR066" : "SR066", "Unsupported case in CONVERT (%s -> %s)", dv_type_title(arg_dtp), dv_type_title((int) (dtp->type)));
#else
  sqlr_new_error ("22023", "SR066", "Unsupported case in CONVERT (%s -> %s)", dv_type_title(arg_dtp), dv_type_title((int) (dtp->type)));
#endif
  NO_CADDR_T;
}

caddr_t
box_cast_to (caddr_t *qst, caddr_t data, dtp_t data_dtp,
    dtp_t to_dtp, ptrlong prec, unsigned char scale, caddr_t *err_ret)
{
  caddr_t tmp[6];
  caddr_t * ptmp;
  caddr_t volatile string_value = NULL;
  caddr_t prec_box = box_num (prec);
  sql_tree_tmp *proposed;

  BOX_AUTO_TYPED (caddr_t *, ptmp, tmp, 3 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  proposed = (sql_tree_tmp *) ptmp;
  ptmp[0] = (caddr_t) (uptrlong) to_dtp;
  ptmp[1] = prec_box;
  ptmp[2] = (caddr_t) (uptrlong) scale;

  QR_RESET_CTX
    {
      string_value = box_cast (qst, data, proposed, data_dtp);
    }
  QR_RESET_CODE
    {
      caddr_t err;
      POP_QR_RESET;
      if (IS_BOX_POINTER (prec_box))
	dk_free_box ((box_t) prec_box);
      err = thr_get_error_code (THREAD_CURRENT_THREAD);
      if (err_ret)
	{
	  *err_ret = err;
	  return NULL;
	}
      else
	sqlr_resignal (err);
    }
  END_QR_RESET;
  if (IS_BOX_POINTER (prec_box))
    dk_free_box ((box_t) prec_box);
  return string_value;
}


caddr_t
bif_convert (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  ST *dtp = (ST *) QST_GET (qst, args[0]);
  caddr_t data = bif_arg (qst, args, 1, "convert");
  dtp_t arg_dtp = DV_TYPE_OF (data);

  if (BOX_ELEMENTS (args) > 2 &&
    ! (ST_P (dtp, DV_SHORT_STRING) || ST_P (dtp, DV_LONG_STRING)))
  sqlr_new_error ("22023", "SR067",
  "Collation specified in cast for non-string datatype %s",
  ARRAYP (dtp) ? dv_type_title ((int) (dtp->type)) : "unknown");

  return (box_cast (qst,data, dtp, arg_dtp));
}


caddr_t
bif_cast_internal (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t data = bif_arg (qst, args, 0, "__cast_internal");
  ST * dtp_st = (ST *) bif_arg (qst, args, 1, "__cast_internal");
  dtp_t arg_dtp = DV_TYPE_OF (data);

  if (DV_SHORT_STRING == arg_dtp || DV_LONG_STRING == arg_dtp)
    {
      caddr_t res = box_cast (qst, data, dtp_st, arg_dtp);
      qst_set (qst, args[3], res);
      qst_set_ref (qst, args[2], qst_address (qst, args[3]));
    }
  else
  {
    /* no conversion, set the ref to point to the arg, no copying */
    qst_set_ref (qst, args[2], qst_address (qst, args[0]));
  }


  return NULL;
}

caddr_t
bif_stub_impl (const char *fname)
{
  sqlr_new_error ("22023", "SR468", "%.200s() can not be called as plain built-in function, it's a macro handled by SQL compiler", fname);
  return NULL;
}

#define BIF_STUB(bifname,fname) caddr_t bifname (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args) { return bif_stub_impl (fname); }

BIF_STUB (bif_stub_ssl_const		, "__ssl_const"		)
BIF_STUB (bif_stub_coalesce		, "coalesce"		)
BIF_STUB (bif_stub_exists		, "exists"		)
BIF_STUB (bif_stub_contains		, "contains"		)
BIF_STUB (bif_stub_xpath_contains	, "xpath_contains"	)
BIF_STUB (bif_stub_xquery_contains	, "xquery_contains"	)
BIF_STUB (bif_stub_xcontains		, "xcontains"		)


caddr_t
bif_blob_to_string (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) QST_INSTANCE (qst);
  caddr_t bh = bif_arg (qst, args, 0, "blob_to_string");
  caddr_t res;

  dtp_t dtp = DV_TYPE_OF (bh);

  /*if (BOX_ELEMENTS (args) > 1)
    use_temp = (long) bif_long_arg (qst, args, 1, "blob_to_string");*/

  if (DV_DB_NULL == dtp)
    {
      return (NEW_DB_NULL);
    }

  if (dtp == DV_SHORT_STRING || dtp == DV_LONG_STRING)
    return (box_copy ((caddr_t) bh));
  else if (IS_WIDE_STRING_DTP (dtp))
    return (box_copy ((caddr_t) bh));
  else if (dtp == DV_STRING_SESSION)
    {
      if (!STRSES_CAN_BE_STRING ((dk_session_t *) bh))
	sqlr_resignal (STRSES_LENGTH_ERROR ("blob_to_string"));
      return (strses_string ( (dk_session_t *) bh));
    }
  else if (dtp == DV_BIN) /* needed for blob_to_string over blobs */
    return box_varchar_string ((db_buf_t) bh, box_length ((caddr_t) bh), DV_LONG_STRING);
#ifdef BIF_XML
  else if (DV_XML_ENTITY == dtp)
    {
      if (!XE_IS_PERSISTENT((xml_entity_t *)(bh)))
	sqlr_new_error ("22023", "SR068", "XML tree cannot be used as argument of blob_to_string");
      bh = (caddr_t)(((xml_entity_t *)(bh))->xe_doc.xpd->xpd_bh);
      if (((blob_handle_t*)bh)->bh_length > 10000000)
	sqlr_new_error ("22001", "SR069",
	    "Attempt to convert a persistent XML document longer than VARCHAR maximum in blob_to_string");
      res = blob_to_string (qi->qi_trx, bh);
      return res;
    }
#endif
  else if (!IS_BLOB_HANDLE_DTP(dtp))
    {
      sqlr_new_error ("22023", "SR070",
	  "blob_to_string requires a blob or string argument");
    }
  if (((blob_handle_t *) bh)->bh_ask_from_client)
    sqlr_new_error ("22023", "SR071",
	"Blob argument to blob_to_string must be a non-interactive blob");

  /* If blob is of length 0 (an empty blob, not NULL), then make
     sure that an empty string '' is returned.
     (Without this an integer 0 would be returned. Is there a
     bug in blob_to_string in blobs.c ???)
   */
  if (0 == (((blob_handle_t *) bh)->bh_length))
    {
      if (dtp == DV_BLOB_WIDE_HANDLE)
	{
	  res = dk_alloc_box (sizeof (wchar_t), DV_WIDE);
	  *((wchar_t *) res) = L'\0';
	}
      else
	{
	  res = dk_alloc_box (sizeof (char), DV_LONG_STRING);
	  *((char *) res) = '\0';
	}
      return (res);
    }

  if (((blob_handle_t*)bh)->bh_length > 10000000)
    sqlr_new_error ("22001", "SR072",
	"Blob longer than maximum string length not allowed in blob_to_string");
    res = blob_to_string (qi->qi_trx, bh);
  return res;
}


caddr_t
bif_blob_to_string_output (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) QST_INSTANCE (qst);
  caddr_t bh = bif_arg (qst, args, 0, "blob_to_string_output");
  dk_session_t *res;
  /*long use_temp = 0;*/

  dtp_t dtp = DV_TYPE_OF (bh);

  /*if (BOX_ELEMENTS (args) > 1)
    use_temp = (long) bif_long_arg (qst, args, 1, "blob_to_string_output");*/

  if (DV_DB_NULL == dtp)
    {
      return (NEW_DB_NULL);
    }

  if (dtp == DV_SHORT_STRING || dtp == DV_LONG_STRING)
    return (box_copy ((caddr_t) bh));
  else if (IS_WIDE_STRING_DTP (dtp))
    return (box_copy ((caddr_t) bh));
  else if (dtp == DV_STRING_SESSION)
    {
      if (!STRSES_CAN_BE_STRING ((dk_session_t *) bh))
	sqlr_resignal (STRSES_LENGTH_ERROR ("blob_to_string_output"));
      return (strses_string ( (dk_session_t *) bh));
    }
  else if (dtp == DV_BIN) /* needed for blob_to_string over blobs */
    return box_varchar_string ((db_buf_t) bh, box_length ((caddr_t) bh), DV_LONG_STRING);
#ifdef BIF_XML
  if (DV_XML_ENTITY == dtp)
    {
      if (!XE_IS_PERSISTENT((xml_entity_t *)(bh)))
	{
	  dk_session_t *ses = strses_allocate ();
	  xml_entity_t *xe = (xml_entity_t *) bh;

	  strses_enable_paging (ses, 2000000);
	  xe->_->xe_serialize (xe, ses);
	  return (caddr_t) ses;
	}
      bh = (caddr_t)(((xml_entity_t *)(bh))->xe_doc.xpd->xpd_bh);
      res = blob_to_string_output (qi->qi_trx, bh);
      return (caddr_t) res;
    }
#endif
  if (!IS_BLOB_HANDLE_DTP(dtp))
    {
      sqlr_new_error ("22023", "SR070",
	  "blob_to_string_output requires a blob or string argument");
    }
  if (((blob_handle_t *) bh)->bh_ask_from_client)
    sqlr_new_error ("22023", "SR071",
	"Blob argument to blob_to_string_output must be a non-interactive blob");


    res = blob_to_string_output (qi->qi_trx, bh);
  return (caddr_t) res;
}


caddr_t
bif_blob_page (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t bh = bif_arg (qst, args, 0, "blob_page");

  dtp_t dtp = DV_TYPE_OF (bh);
  if (dtp != DV_BLOB_HANDLE && dtp != DV_BLOB_WIDE_HANDLE)
  return (box_num (0));
  return (box_num ((((blob_handle_t *) bh)->bh_page)));
}


caddr_t
bif_lisp_read (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t str = bif_string_arg (qst, args, 0, "lisp_read");
  lisp_stream_t st;
  volatile caddr_t res = NULL;
  lisp_stream_init (&st, str);
  CATCH (CATCH_LISP_ERROR)
  {
  res = lisp_read (&st);
  }
  END_CATCH;
  return res;
}


caddr_t
bif_raw_exit (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int f = 0;
  query_instance_t *qi = (query_instance_t *) qst;
  int atomic = srv_have_global_lock  (THREAD_CURRENT_THREAD);
  if (BOX_ELEMENTS (args) > 0)
  f = (int) bif_long_arg (qst, args, 0, "raw_exit");
  if (!QI_IS_DBA (qst))
  return 0;
  if (qi->qi_client && qi->qi_client->cli_session)
    session_flush (qi->qi_client->cli_session);
  if (!f && !atomic)
    IN_CPT (((query_instance_t *) qst)->qi_trx); /* not during checkpoint */
  call_exit (0);
  return NULL; /* dummy */
}

dbe_table_t *
sequence_auto_increment_of (caddr_t name)
{
  char *dot = name, *start_pos = NULL, *end_pos = NULL;
  char tb [MAX_NAME_LEN * 3];
  int ndots = 0;
  dbe_table_t * tbl = NULL;

  for (dot = strchr (dot, '.'); NULL != dot; dot = strchr (dot, '.'))
    {
      dot++;
      ndots++;
      if (ndots == 2) start_pos = dot;
      if (ndots == 5) end_pos = dot;
      if (ndots > 5) break;
    }
  if (ndots == 5) /* look-like a autoincrement */
    {
      dbe_column_t *col = NULL;
      memset (tb, 0, sizeof (tb));
      strncpy (tb, start_pos, end_pos - start_pos - 1);
      tbl = sch_name_to_table (wi_inst.wi_schema, tb);
      if (tbl)
	col = tb_name_to_column (tbl, end_pos);
      if (!col)
	tbl = NULL;
    }
  return tbl;
}

#if 0
/* used to dump sequences created by dba */
caddr_t
bif_sequence_is_auto_increment (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) QST_INSTANCE (qst);
  caddr_t name = bif_string_arg (qst, args, 0, "sequence_is_auto_increment");
  dbe_table_t * tb;
  sec_check_dba (qi, "sequence_is_auto_increment");
  tb = sequence_auto_increment_of (name);
  if (tb)
    return box_num (1);
  return box_num (0);
}
#endif

caddr_t
bif_add_protected_sequence (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) QST_INSTANCE (qst);
  caddr_t name = bif_string_arg (qst, args, 0, "add_protected_sequence");
  caddr_t copy;
  ptrlong one = 1;
  sec_check_dba (qi, "add_protected_sequence");
  copy = box_dv_short_string (name);
  id_hash_set (dba_sequences, (caddr_t)&copy, (caddr_t)&one);
  NO_CADDR_T;
}

void
check_sequence_grants (query_instance_t * qi, caddr_t name)
{
  dbe_table_t * tbl = NULL;
  if (sec_bif_caller_is_dba (qi))
    return;
  if (id_hash_get (dba_sequences, (caddr_t)&name))
    sqlr_new_error ("42000", "SR159", "Sequence %.300s restricted to dba group.", name);
  tbl = sequence_auto_increment_of (name);
  if (tbl && !sec_tb_check (tbl, qi->qi_u_id, qi->qi_g_id, GR_INSERT))
    sqlr_new_error ("42000", "SR159", "No permission to write sequence %.300s.", name);
}

static int registry_name_is_protected (const caddr_t name)
{
  if (!strncmp (name, "__key__", 7))
    return 2;
  if (!strcmp (name, "__next_free_port"))
    return 1;
  if (!strcmp (name, "cl_host_map"))
    return 1;
  return 0;
}

#if 0
/* used to dump sequences created by dba */
caddr_t
bif_sequence_is_auto_increment (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) QST_INSTANCE (qst);
  caddr_t name = bif_string_arg (qst, args, 0, "sequence_is_auto_increment");
  dbe_table_t * tb;
  sec_check_dba (qi, "sequence_is_auto_increment");
  tb = sequence_auto_increment_of (name);
  if (tb)
    return box_num (1);
  return box_num (0);
}
#endif

caddr_t
bif_sequence_set_impl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, int sec_check)
{
  boxint res;
  query_instance_t *qi = (query_instance_t *) QST_INSTANCE (qst);
  caddr_t name = bif_string_arg (qst, args, 0, "sequence_set");
  boxint count = (boxint) bif_long_arg (qst, args, 1, "sequence_set");
  long mode = (long) bif_long_arg (qst, args, 2, "sequence_set");

  if (sec_check && mode != SEQUENCE_GET)
    {
      query_instance_t *eff_qi = qi;
      check_sequence_grants (eff_qi, name);
    }

  res = sequence_set_1 (name, count, mode, OUTSIDE_MAP, err_ret);
  if (*err_ret)
    return NULL;
  if (mode == SET_IF_GREATER)
    log_sequence (qi->qi_trx, name, res);
  else if (mode == SET_ALWAYS)
    {
      caddr_t log_array;

      log_array = list (4, box_string ("__sequence_set (?, ?, ?)"),
	    box_string (name), box_num (count), box_num (mode));
      log_text_array (qi->qi_trx, log_array);
      dk_free_tree (log_array);
    }

  return (box_num (res));
}


caddr_t
bif_sequence_next_impl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, int sec_check)
{
  query_instance_t *qi = (query_instance_t *) QST_INSTANCE (qst);
  caddr_t name = bif_string_arg (qst, args, 0, "sequence_next");
  boxint inc_by = 1, res = 0;

  if (strlen (name) > SEQ_MAX_CHARS)
    sqlr_new_error ("42000", "SEQMA", "Sequence name too long");
  if (BOX_ELEMENTS (args) > 1)
    {
      inc_by = (long) bif_long_arg (qst, args, 1, "sequence_next");
      if (inc_by < 1)
	sqlr_new_error ("22023", "SR376",
	    "sequence_next() needs an nonnegative integer as a second argument, not " BOXINT_FMT, inc_by);
    }

  if (sec_check)
    check_sequence_grants (qi, name);
  if (cl_run_local_only)
    res = sequence_next_inc_1 (name, OUTSIDE_MAP, inc_by, err_ret);
  else
    {
      GPF_T;
    }
  if (*err_ret)
    return NULL;
  log_sequence (qi->qi_trx, name, res + inc_by);
  return (box_num (res));
}

caddr_t
bif_sequence_set (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_sequence_set_impl (qst, err_ret, args, 1);
}

caddr_t
bif_sequence_next (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_sequence_next_impl (qst, err_ret, args, 1);
}

caddr_t
bif_sequence_set_no_check (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_sequence_set_impl (qst, err_ret, args, 0);
}

caddr_t
bif_sequence_next_no_check (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_sequence_next_impl (qst, err_ret, args, 0);
}

caddr_t
bif_sequence_remove (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  long res;
  query_instance_t *qi = (query_instance_t *) QST_INSTANCE (qst);
  caddr_t name = bif_string_arg (qst, args, 0, "sequence_remove");

  check_sequence_grants (qi, name);
  res = sequence_remove (name, OUTSIDE_MAP);
  log_sequence_remove (qi->qi_trx, name);
  return (box_num (res));
}


static caddr_t
bif_set_identity (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) QST_INSTANCE (qst);
  client_connection_t * cli = qi->qi_client;
  caddr_t val = bif_arg (qst, args, 0, "__set_identity");
  dk_free_tree (cli->cli_identity_value);
  cli->cli_identity_value = box_copy (val);
  return (box_copy (val));
}


caddr_t
bif_registry_get_all (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) QST_INSTANCE (qst);
  if (!QI_IS_DBA (qi))
  return NULL;
  return registry_get_all ();
}


caddr_t
bif_sequence_get_all (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) QST_INSTANCE (qst);
  if (!QI_IS_DBA (qi))
  return NULL;
  return sequence_get_all ();
}


#define VOID_USER (user_t *)(-1L)

int
set_user_id (client_connection_t * cli, caddr_t name, caddr_t preserve_qual)
{
  user_t * user;
  user = sec_name_to_user (name);

  if (!user || /* !user->usr_is_sql || */ user->usr_is_role)
    return 0;

  cli->cli_user = user;
  dk_free_tree (cli->cli_qualifier);
  cli->cli_qualifier = NULL;
  cli_set_default_qual (cli);
  if (!cli->cli_qualifier)
    CLI_SET_QUAL (cli, "DB");

  if (!in_srv_global_init)
    {
      CHANGE_THREAD_USER (user);
    }

  return 1;
}

void
pop_user_id (client_connection_t * cli)
{
}

static caddr_t
bif_pop_user_id (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return NULL;
}

static caddr_t
bif_set_user_id (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) QST_INSTANCE (qst);
  client_connection_t * cli = qi->qi_client;
  caddr_t uname = bif_string_arg (qst, args, 0, "__set_user_id");
  long mode = BOX_ELEMENTS (args) > 1 ? (long) bif_long_arg (qst, args, 1, "__set_user_id") : 1;
  caddr_t pass = BOX_ELEMENTS (args) > 2 ? bif_string_arg (qst, args, 2, "__set_user_id") : NULL;
  user_t * user = sec_name_to_user (uname);

  if (!user /*|| !user->usr_is_sql*/ || user->usr_is_role)
    sqlr_new_error ("22023", "HT042", "Not valid user id \"%s\"", uname);

  if (pass && (0 != strcmp (pass, user->usr_pass) || user->usr_disabled))
    sqlr_new_error ("22023", "HT042", "Invalid credentials for user id \"%s\"", uname);

  if (!pass)
    sec_check_dba ((query_instance_t *) qst, "__set_user_id");

  set_user_id (cli, uname, NULL);
  qi->qi_pop_user = mode;
  qi->qi_u_id = user->usr_id;
  qi->qi_g_id = user->usr_g_id;

  return (box_num (0));
}

static caddr_t
bif_get_user_id (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) QST_INSTANCE (qst);
  long what = bif_long_range_arg (qst, args, 0, "__get_user_id", 1, 4);
  switch (what)
    {
    case 1: return box_num (qi->qi_u_id);
    case 2: return box_num (qi->qi_g_id);
    case 3: return box_num (qi->qi_client->cli_user->usr_id);
    case 4: return box_num (qi->qi_client->cli_user->usr_g_id);
    }
  return NULL;
}

static caddr_t
bif_identity_value (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) QST_INSTANCE (qst);
  return (box_copy (qi->qi_client->cli_identity_value));
}


caddr_t
bif_registry_name_is_protected (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t name = bif_string_arg (qst, args, 0, "registry_name_is_protected");
  return box_num (registry_name_is_protected (name));
}


caddr_t
bif_registry_set (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t name = bif_string_arg (qst, args, 0, "registry_set");
  caddr_t val = bif_string_arg (qst, args, 1, "registry_set");
  int name_is_protected = registry_name_is_protected (name);
  int force = 0;
  if (2 < BOX_ELEMENTS (args))
    {
      if (!sec_bif_caller_is_dba ((query_instance_t *)qst))
        sqlr_new_error ("42000", "SR159", "Function registry_set restricted to dba group when is called with 3 arguments.");
      force = bif_long_arg (qst, args, 2, "registry_set");
    }
  switch (name_is_protected)
    {
    case 0: break;
    case 1:
      if (force) break;
      sqlr_new_error ("42000", "SR483", "Function registry_set needs nonzero third argument to modify registry variable '%.300s'.", name);
    case 2:
      if (2 == force)
        return (box_num (0));
      sqlr_new_error ("42000", "SR484", "Function registry_set can not modify protected registry variable '%.300s'.", name);
    }
  check_sequence_grants ((query_instance_t *)qst, name);
  IN_TXN;
  registry_set_1 (name, val, 1, err_ret);
  log_registry_set (((query_instance_t *) qst)->qi_trx, name, val);
  LEAVE_TXN;
  if (in_log_replay && DV_STRINGP (val))
    {
      db_replay_registry_setting (val, err_ret);
    }
  return (box_num (1));
}


caddr_t
bif_registry_get (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t res;
  caddr_t name = bif_string_arg (qst, args, 0, "registry_get");
  IN_TXN;
  res = registry_get (name);
  LEAVE_TXN;
  return res;
}


caddr_t
bif_registry_remove (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t res = NULL;
  caddr_t name = bif_string_arg (qst, args, 0, "registry_remove");
  if (registry_name_is_protected (name))
    sqlr_new_error ("42000", "SR485", "Function registry_remove can not remove protected registry variable '%.300s'.", name);
  check_sequence_grants ((query_instance_t *)qst, name);
  IN_TXN;
  res = registry_remove (name);
  LEAVE_TXN;
  return res;
}


caddr_t
bif_set_qualifier (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t *msg;
  query_instance_t *qi = (query_instance_t *)qst;
  caddr_t qual = bif_string_or_wide_or_null_arg (qst, args, 0, "set_qualifier");
  caddr_t q = NULL;
  caddr_t cli_ws = (caddr_t) ((query_instance_t *)qst)->qi_client->cli_ws;
  client_connection_t * cli = (client_connection_t *) ((query_instance_t *)qst)->qi_client;
  dtp_t dtp = DV_TYPE_OF (qual);

  switch (dtp)
    {
      case DV_STRING:
	  q = box_string (qual);
	  break;
      case DV_WIDE:
	  q = box_wide_as_utf8_char (qual, box_length (qual) / sizeof (wchar_t) - 1, DV_SHORT_STRING);
	  break;
      default:
	  sqlr_new_error ("22023", "SR484", "Function set_qualifier needs a string as argument 0, not an arg of type %s (%d)",
	      dv_type_title (dtp), dtp);
    }

  if (box_length (q) >= MAX_NAME_LEN || strlen (q) < 1)
    {
      dk_free_box (q);
      sqlr_new_error ("22023", "SR484", "The qualifier cannot be longer than %d characters nor empty string", MAX_NAME_LEN);
    }
  sch_normalize_new_table_case (isp_schema (qi->qi_space), q, box_length (q), NULL, 0);
  semaphore_enter (parse_sem);
  dk_free_box (qi->qi_client->cli_qualifier);
  qi->qi_client->cli_qualifier = q;
  semaphore_leave (parse_sem);

  if (!cli_ws && cli_is_interactive (cli))
  {
    msg = (caddr_t *) dk_alloc_box (QA_LOGIN_FIELDS * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
    memset (msg, 0, box_length ((caddr_t) msg));
    msg[0] = (caddr_t) QA_LOGIN;
    msg[LG_QUALIFIER] = box_dv_short_string (q);
    msg[LG_DEFAULTS] = srv_client_defaults ();
    PrpcAddAnswer ((caddr_t) msg, DV_ARRAY_OF_POINTER, PARTIAL, 0);
    dk_free_tree ((caddr_t) msg);
  }
  return (box_num (1));
}


caddr_t
bif_complete_table_name (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t result;
  caddr_t tb_name = bif_string_arg (qst, args, 0, "complete_table_name");
  long mode = (long) bif_long_arg (qst, args, 1, "complete_table_name");
  query_instance_t *qi = (query_instance_t *) qst;
  dbe_table_t *tb = NULL;
  sqlc_set_client (qi->qi_client);
  if (mode == DEFAULT_EXISTING)
  tb = qi_name_to_table (qi, tb_name);
  if (tb)
  {
    result = box_dv_short_string (tb->tb_name);
  }
  else
  {
    char q[MAX_NAME_LEN];
    char o[MAX_NAME_LEN];
    char n[MAX_NAME_LEN];
    char complete[MAX_QUAL_NAME_LEN];
    q[0] = 0;
    o[0] = 0;
    n[0] = 0;
    sch_split_name (qi->qi_client->cli_qualifier, tb_name, q, o, n);
    if (0 == o[0])
      strcpy_ck (o, cli_owner (qi->qi_client));
    snprintf (complete, sizeof (complete), "%s.%s.%s", q, o, n);
    result = box_dv_short_string (complete);
  }
  return result;
}

caddr_t
bif_complete_proc_name (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t result;
  caddr_t proc_name = bif_string_arg (qst, args, 0, "complete_proc_name");
  long mode = (long) bif_long_arg (qst, args, 1, "complete_proc_name");
  query_instance_t *qi = (query_instance_t *) qst;
  query_t *qr = NULL;
  sqlc_set_client (qi->qi_client);
  if (mode == DEFAULT_EXISTING)
  {
    char *name = NULL;
    name = sch_full_proc_name (isp_schema (qi->qi_space), proc_name,
    qi->qi_query->qr_qualifier, CLI_OWNER (qi->qi_client));
    if (name)
  qr = sch_proc_def (isp_schema (qi->qi_space), name);
    else
  {
    name = sch_full_module_name (isp_schema (qi->qi_space), proc_name,
      qi->qi_query->qr_qualifier, CLI_OWNER (qi->qi_client));
    if (name)
    qr = sch_module_def (isp_schema (qi->qi_space), name);
  }
  }

  if (qr)
  result = box_dv_short_string (qr->qr_proc_name);
  else
  {
    char q[MAX_NAME_LEN];
    char o[MAX_NAME_LEN];
    char n[MAX_NAME_LEN];
    char complete[MAX_QUAL_NAME_LEN];
    q[0] = 0;
    o[0] = 0;
    n[0] = 0;
    sch_split_name (qi->qi_client->cli_qualifier, proc_name, q, o, n);
    if (0 == o[0])
      strcpy_ck (o, cli_owner (qi->qi_client));
    snprintf (complete, sizeof (complete), "%s.%s.%s", q, o, n);
    result = box_dv_short_string (complete);
  }
  return result;
}


char *
part_tok (char ** place)
{
  char * start = *place;
  char * ptr = start;
  for (;;)
  {
    if (*ptr == '.')
  {
    *ptr = 0;
    *place = ptr+1;
    return start;
  }
    if (*ptr == '\x0A')
  {
    *ptr++ = '.';
    continue;
  }
    if (*ptr == 0)
  {
    if (0 == *start)
    return NULL;
    *place = ptr;
    return start;
  }
    ptr ++;
  }
}


caddr_t
bif_name_part (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  const char * ret;
  char *xx = NULL;    /* strtok_r */
  caddr_t name = bif_string_arg (qst, args, 0, "name_part");
  long nth = (long) bif_long_arg (qst, args, 1, "name_part");
  const char * deflt  = BOX_ELEMENTS (args) > 2 ? bif_arg (qst, args, 2, "name_part") : NULL;
  int len = (int) strlen (name);
  char temp[MAX_QUAL_NAME_LEN];
  const char *part1, *part2, *part3;
  memcpy (temp, name, len + 1);
  xx = &temp[0];
  part1 = part_tok (&xx);
  part2 = part_tok (&xx);
  part3 = part_tok (&xx);

  if (deflt)
    {
      if (DV_TYPE_OF (deflt) != DV_DB_NULL &&
        !DV_STRINGP (deflt))
        sqlr_new_error ("42000", "SR472",
          "Value of incompatible type (%s) supplied for the third optional argument of name_part()",
          dv_type_title (DV_TYPE_OF (deflt)));
    }
  if (!part2)
  {
    part3 = part1;
    part1 = deflt ? deflt : "DB";
    part2 = deflt ? deflt : "DBA";
  }
  else if (!part3)
  {
    part3 = part2;
    part2 = part1;
    part1 = deflt ? deflt : "DB";
  }

  ret =  (nth == 0 ? part1 : (nth == 1 ? part2 : part3));
  if (nth == 1 && ret != deflt && strlen (ret) == 0)
    ret = deflt;
  if (ret == deflt)
    return (box_copy_tree ((box_t) ret));
  return (box_dv_short_string (ret));
}


caddr_t
bif_clear_index (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t *)qst;
  it_cursor_t itc_auto;
  it_cursor_t * itc = &itc_auto;
  dbe_key_t * key = bif_key_arg (qst, args, 0, "__clear_index");
  ITC_INIT (itc, NULL, NULL);
  itc->itc_ltrx = qi->qi_trx;
  sec_check_dba (qi, "__clear_index");
  itc_drop_index (itc, key);
  return NULL;
}


caddr_t
bif_key_replay_insert (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  slice_id_t slice = QI_NO_SLICE;
  query_instance_t *qi = (query_instance_t *) qst;
  row_delta_t rd;
  int cinx = 1;
  caddr_t * arr = (caddr_t*) bif_array_arg (qst, args, 0, "key_replay_insert");
  int ins_mode = bif_long_arg (qst, args, 1, "key_replay_insert");
  int col_ctr = 0;
  caddr_t err = NULL;
  buffer_desc_t *unq_buf;
  buffer_desc_t **unq_buf_ptr = NULL;
  int inx = 0, rc;
  dbe_key_t * key = sch_id_to_key (wi_inst.wi_schema, unbox (arr[0]));
  it_cursor_t itc_auto;
  it_cursor_t * it = &itc_auto;
  QI_CHECK_STACK (qi, &qst, INS_STACK_MARGIN);
  sec_check_dba (qi, "key_replay_insert");
  ITC_INIT (it, NULL, qi->qi_trx);
  memset (&rd, 0, sizeof (row_delta_t));
  if (!key || dk_set_length (key->key_parts) != BOX_ELEMENTS (arr) - 1)
    sqlr_new_error ("42000", "KI...", "No key for the id or bad number of columns in key_replay_insert");
  rd.rd_allocated = RD_AUTO;
  rd.rd_key = key;
  rd.rd_op = RD_INSERT;
  rd.rd_non_comp_len = key->key_row_var_start[0];
  rd.rd_non_comp_max = MAX_ROW_BYTES;
  rd.rd_itc = it;
  rd.rd_qst = qst;
  it->itc_tree = key->key_fragments[0]->kf_it;
  it->itc_key_spec = key->key_insert_spec;
  it->itc_out_state = qst;
  ITC_START_SEARCH_PARS (it);
  it->itc_search_par_fill = key->key_n_significant;
  if (!key->key_parts)
    sqlr_new_error ("42S11", "SR119", "Key %s has 0 parts. Create index probably failed",
		    key->key_name);

  DO_CL_0 (cl, key->key_key_fixed)
    {
      caddr_t data = arr[cinx++];
      ITC_SEARCH_PARAM (it, data);
      if (err)
	break;
      inx++;
    }
  END_DO_CL;
  if (err)
    {
      itc_free_owned_params (it);
      sqlr_resignal (err);
    }
  DO_CL_0 (cl, key->key_key_var)
    {
      caddr_t data = arr[cinx++];
      ITC_SEARCH_PARAM (it, data);
      rd.rd_non_comp_len += box_col_len (data);
      if (err)
	break;
      inx++;
    }
  END_DO_CL;
  if (err)
    {
      itc_free_owned_params (it);
      sqlr_resignal (err);
    }

  if (rd.rd_non_comp_len - key->key_row_var_start[0] + key->key_key_var_start[0] > MAX_RULING_PART_BYTES)
    {
      itc_free_owned_params (it);
      sqlr_error ("22026", "Key too long");
    }

  col_ctr = inx;
  for (inx = 0; key->key_row_fixed[inx].cl_col_id; inx++)
    {
      caddr_t data = arr[cinx++];
      ITC_SEARCH_PARAM (it, data);
      if (err)
	break;
    }
  col_ctr += inx;
  if (err)
    {
      itc_free_owned_params (it);
      sqlr_resignal (err);
    }
  itc_from_keep_params (it, key, slice);  /* fragment needs to be known before setting blobs */
  for (inx = 0; key->key_row_var[inx].cl_col_id; inx++)
    {
      caddr_t data;
      if (CI_BITMAP == key->key_row_var[inx].cl_col_id)
	break; /* the bitmap string of a bm inx row is always the last */
      data = arr[cinx++];
      ITC_SEARCH_PARAM (it, data);
      rd.rd_non_comp_len += box_col_len (data);
      if (err)
	break;
    }
  if (err)
    {
      itc_free_owned_params (it);
      sqlr_resignal (err);
    }
  rd.rd_values = &it->itc_search_params[key->key_n_significant];
  rd.rd_n_values = it->itc_search_par_fill - key->key_n_significant;
  /* now the cols are in layout order, kf kv rf rv.  Put them now at the head in key order */
  if (qi->qi_client->cli_is_log)
    rd_fixup_blob_refs (it, &rd);
  for (inx = 0; inx < key->key_n_significant; inx++)
    it->itc_search_params[inx] = it->itc_search_params[key->key_n_significant + key->key_part_in_layout_order[inx]];
  unq_buf_ptr = &unq_buf;
  it->itc_insert_key = key;
  if (key->key_is_bitmap)
    {
      if (!qi->qi_non_txn_insert)
	rd.rd_make_ins_rbe = 1;
      ITC_FAIL (it)
	{
	  key_bm_insert (it, &rd);
	}
      ITC_FAILED
	{
	}
      END_FAIL (it);
      itc_free_owned_params (it);
      return (caddr_t)DVC_LESS;
    }
  if (key->key_is_primary)
    ins_mode = INS_REPLACING;
  else
    ins_mode = INS_SOFT;
  if (KI_TEMP != key->key_id && !qi->qi_non_txn_insert)
    rd.rd_make_ins_rbe = 1;
  ITC_FAIL (it)
    {
      rc = itc_insert_unq_ck (it, &rd, unq_buf_ptr);
      if (DVC_MATCH == rc)
	{
	  /* duplicate */
	  switch (ins_mode)
	    {
	    case INS_REPLACING:
	      log_insert (it->itc_ltrx, &rd, LOG_KEY_ONLY | ins_mode);
	      QI_ROW_AFFECTED (QST_INSTANCE (qst));
	      itc_replace_row (it, unq_buf, &rd, qst, 1);
	      itc_free_owned_params (it);

	      return (caddr_t)DVC_MATCH;

	    case INS_NORMAL:
	    case INS_SOFT:

	      /* leave and return */
	      itc_free_owned_params (it);
	      itc_page_leave (it, unq_buf);
	      if (ins_mode == INS_SOFT && key->key_is_primary)
		{
		  it->itc_map_pos = ITC_AT_END;
		  it->itc_row_key = key;
		  itc_delete_blob_search_pars (it, &rd);
		  log_insert (it->itc_ltrx, &rd, LOG_KEY_ONLY | ins_mode);
		}
	      return (caddr_t)DVC_MATCH;
	    }
	  return (caddr_t)DVC_MATCH;
	}
      else
	log_insert (it->itc_ltrx, &rd, LOG_KEY_ONLY | ins_mode);

    }
  ITC_FAILED
    {
    }
  END_FAIL (it);
  return 0;
}



caddr_t
bif_set_user_struct (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t u_name = bif_string_arg (qst, args, 0, "set_user_struct");
  caddr_t u_pwd = bif_string_arg (qst, args, 1, "set_user_struct");
  long u_id = (long) bif_long_arg (qst, args, 2, "set_user_struct");
  long u_g_id = (long) bif_long_arg (qst, args, 3, "set_user_struct");
  caddr_t u_dta = bif_string_or_null_arg (qst, args, 4, "set_user_struct");
  long is_role = (BOX_ELEMENTS (args) > 5 ? (long) bif_long_arg (qst, args, 5, "set_user_struct") : 0);
  caddr_t u_sys_name = (BOX_ELEMENTS (args) > 6 ? bif_string_or_null_arg (qst, args, 6, "set_user_struct") : NULL);
  caddr_t u_sys_pwd = (BOX_ELEMENTS (args) > 7 ? bif_string_or_null_arg (qst, args, 7, "set_user_struct") : NULL);

  caddr_t *qi = QST_INSTANCE (qst);

  if (!QI_IS_DBA (qi))
    return 0;

  sec_set_user_struct (u_name, u_pwd, u_id, u_g_id, u_dta, (int) is_role, u_sys_name, u_sys_pwd);

  return NULL;
}


#ifdef WIN32
caddr_t
bif_set_user_os_acount_int (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t u_name = bif_string_arg (qst, args, 0, "__set_user_os_acount_int");
  caddr_t u_sys_name = bif_string_or_null_arg (qst, args, 1, "__set_user_os_acount_int");
  caddr_t u_sys_pwd = bif_string_or_null_arg (qst, args, 2, "__set_user_os_acount_int");

  query_instance_t *qi = (query_instance_t *) qst;
  client_connection_t *cli = qi->qi_client;
  user_t * user = cli->cli_user;

  int perm = 0;

  if (BOX_ELEMENTS (args) > 3)
    {
       return box_num (check_os_user (u_sys_name, u_sys_pwd));
    }

  if (user && !strncmp (user->usr_name, u_name, sizeof (user->usr_name)))
    perm = 1;
  else if (user && sec_user_has_group (0, user->usr_id))
    perm = 1;
  else if (!user && sec_bif_caller_is_dba (qi))
    perm = 1;

  if (!perm)
    return box_num (0);

  return box_num (sec_set_user_os_struct (u_name, u_sys_name, u_sys_pwd));
}
#else
caddr_t
bif_set_user_os_acount_int (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  /* Only for server startup */
  return box_num (0);
}
#endif


caddr_t
bif_set_user_data (caddr_t * inst, caddr_t * err_ret, state_slot_t ** args)
{
  sec_set_user_data (bif_string_arg (inst, args, 0, "set_set_user_data"),
    bif_string_arg (inst, args, 1, "set_set_user_data"));
  return 0;
}

caddr_t
bif_remove_user_struct (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;
  caddr_t u_name = bif_string_arg (qst, args, 0, "remove_user_struct");
  user_t *user;

  if (!QI_IS_DBA (qi))
  return 0;

  user = sec_name_to_user (u_name);
  if (!user)
    sqlr_new_error ("28000", "SR153", "No user in delete user");
  sec_remove_user_struct (qi, user, u_name);
  return NULL;
}

caddr_t
bif_grant_user_role (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  static char * me = "sec_grant_user_role";
  oid_t u_id = (oid_t) bif_long_arg (qst, args, 0, me);
  oid_t g_id = (oid_t) bif_long_arg (qst, args, 1, me);
  user_t *user, *gr;

  sec_check_dba ((query_instance_t *) qst, me);

  if (NULL == (user = sec_id_to_user (u_id)))
    sqlr_new_error ("42000", "SR146", "No user with id %ld", (long)u_id);

  if (NULL == (gr = sec_id_to_user (g_id)))
    sqlr_new_error ("42000", "SR143", "No group with id %ld", (long)g_id);

  sec_grant_single_role (user, gr, 0);

  return 0;
}

static caddr_t
bif_user_set_password (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t u_name = bif_string_arg (qst, args, 0, "user_set_password");
  caddr_t u_pwd = bif_string_or_wide_or_uname_arg (qst, args, 1, "user_set_password");
  caddr_t u_pwd_to_delete = NULL;

  query_instance_t *qi = (query_instance_t *) (qst);
  user_t *usr = sec_name_to_user (u_name);
  client_connection_t *cli = qi->qi_client;
  /*caddr_t *old_log = qi->qi_trx->lt_replicate;*/
  caddr_t *log_array = NULL;

  sec_check_dba (qi, "user_set_password");

  if (!usr)
    sqlr_new_error ("42000", "SR286", "The user %.50s does not exist", u_name);
  if ((DV_WIDE == DV_TYPE_OF (u_pwd)) ? (0 == ((wchar_t *)u_pwd)[0]) : ('\0' == u_pwd[0]))
    sqlr_new_error ("42000", "SR287", "The new password for %.50s cannot be empty", usr->usr_name);
  switch (DV_TYPE_OF (u_pwd))
    {
    case DV_WIDE:
      u_pwd_to_delete = u_pwd = box_wide_as_utf8_char (u_pwd, box_length (u_pwd) / sizeof (wchar_t) - 1, DV_SHORT_STRING);
      break;
    case DV_UNAME:
      u_pwd_to_delete = u_pwd = box_dv_short_string (u_pwd);
      break;
    default:
      if (strlen (u_pwd) != (box_length (u_pwd) - 1))
        sqlr_new_error ("42000", "SR287", "The new password for %.50s cannot contain zero bytes", usr->usr_name);
      break;
    }
  /*qi->qi_client = bootstrap_cli;*/
  /*qi->qi_trx->lt_replicate = REPL_NO_LOG; */
  QR_RESET_CTX_T (qi->qi_thread)
    {
      sec_set_user (qi, usr->usr_name, u_pwd, 1);
    }
  QR_RESET_CODE
    {
      dk_free_box (u_pwd_to_delete);
      POP_QR_RESET;
      /*qi->qi_trx->lt_replicate = old_log; */
      qi->qi_client = cli;
      longjmp_splice (THREAD_CURRENT_THREAD->thr_reset_ctx, reset_code);
    }
  END_QR_RESET
  /*qi->qi_trx->lt_replicate = old_log; */
  /*qi->qi_client = cli;*/

  log_array = (caddr_t *) dk_alloc_box (6 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  log_array[0] = box_string ("sec_set_user_struct (?, ?, ?, ?, ?)");
  log_array[1] = box_string (usr->usr_name);
  log_array[2] = box_string (u_pwd);
  log_array[3] = box_num (usr->usr_id);
  log_array[4] = box_num (usr->usr_g_id);
  log_array[5] = usr->usr_data ? box_string (usr->usr_data) : dk_alloc_box (0, DV_DB_NULL);
  log_text_array (qi->qi_trx, (caddr_t) log_array);
  dk_free_tree ((box_t) log_array);
  dk_free_box (u_pwd_to_delete);
  return NULL;
}


caddr_t
bif_revoke_user_role (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  static char * me = "sec_revoke_user_role";
  oid_t u_id = (oid_t) bif_long_arg (qst, args, 0, me);
  oid_t g_id = (oid_t) bif_long_arg (qst, args, 1, me);
  user_t *user, *gr;

  sec_check_dba ((query_instance_t *) qst, me);

  if (NULL == (user = sec_id_to_user (u_id)))
    sqlr_new_error ("42000", "SR398", "No user with id %ld", (long)u_id);

  if (NULL == (gr = sec_id_to_user (g_id)))
    sqlr_new_error ("42000", "SR399", "No group with id %ld", (long)g_id);

  sec_revoke_single_role (user, gr, 0);

  cli_flush_stmt_cache (user);

  return 0;
}

#if 1

static caddr_t
bif_list_role_grants (caddr_t * inst, caddr_t * err_ret, state_slot_t ** args)
{
  user_t **place;
  caddr_t *name_found;
  id_hash_iterator_t it;
  dk_set_t set = NULL;

  sec_check_dba ((query_instance_t *) inst, "list_role_grants");
  id_hash_iterator (&it, sec_users);
  while (hit_next (&it, (caddr_t *) &name_found, (caddr_t *) &place))
    {
      user_t *usr = *place;
      int inx;
      dk_set_t rset = NULL;
      caddr_t grs = NULL;
      dk_set_push (&set, box_dv_short_string (usr->usr_name));
      _DO_BOX (inx, usr->usr_g_ids)
	{
	  long g_id = (long) (ptrlong) usr->usr_g_ids[inx];
	  user_t *gr = sec_id_to_user (g_id);
	  if (NULL != gr)
	    dk_set_push (&rset, box_dv_short_string (gr->usr_name));
	  else
	    {
	      char tmp[128];
	      snprintf_ck (tmp, sizeof (tmp), "<non-sql group id: %ld>", g_id);
	      dk_set_push (&rset, box_dv_short_string (tmp));
	    }
	}
      END_DO_BOX;
      grs = list_to_array (dk_set_nreverse (rset));
      dk_set_push (&set, grs);
    }
  return list_to_array (dk_set_nreverse (set));
}
#endif

caddr_t
bif_set_user_cert (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t u_name = bif_string_arg (qst, args, 0, "set_user_cert");
  caddr_t u_cert = bif_string_arg (qst, args, 1, "set_user_cert");
  caddr_t *qi = QST_INSTANCE (qst);

  if (!QI_IS_DBA (qi))
  return 0;

  sec_set_user_cert (u_name, u_cert);
  return NULL;
}

caddr_t
bif_set_user_enable (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t u_name = bif_string_arg (qst, args, 0, "sec_user_enable");
  int flag = (int) bif_long_arg (qst, args, 1, "sec_user_enable");
  caddr_t *qi = QST_INSTANCE (qst);

  if (!QI_IS_DBA (qi))
    return NULL;

  sec_user_disable (u_name, flag ? 0 : 1);
  return NULL;
}

caddr_t
bif_remove_user_cert (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t u_name = bif_string_arg (qst, args, 0, "remove_user_cert");
  caddr_t u_cert = bif_string_arg (qst, args, 1, "remove_user_cert");
  caddr_t *qi = QST_INSTANCE (qst);

  if (!QI_IS_DBA (qi))
  return 0;

  sec_user_remove_cert (u_name, u_cert);
  return NULL;
}

caddr_t
bif_get_user_by_cert (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;
  caddr_t u_cert = bif_string_or_null_arg (qst, args, 0, "get_user_by_cert");
  sec_check_dba (qi, "set_get_user_by_cert");

  return sec_get_user_by_cert (u_cert);
}

void
bif_log_text_array_impl (caddr_t * inst, caddr_t *arr)
{
  query_instance_t *qi = (query_instance_t *) inst;
  client_connection_t * cli = qi->qi_client;
  int inx, len = BOX_ELEMENTS (arr);
  dk_set_t temp_blobs = NULL;
  for (inx = 0; inx < len; inx++)
    {
      if (IS_BLOB_HANDLE (arr[inx]))
	{
	  arr[inx] = blob_to_string (qi->qi_trx, arr[inx]);
	  dk_set_push (&temp_blobs, arr[inx]);
	}
    }
  if (sec_bif_caller_is_dba (qi) || !cli->cli_user)
    log_text_array (qi->qi_trx, (caddr_t) arr);
  else
    log_text_array_as_user (cli->cli_user, qi->qi_trx, (caddr_t) arr);
  while (NULL != temp_blobs) dk_free_tree (dk_set_pop (&temp_blobs));
}

caddr_t
bif_log_text_array (caddr_t * inst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t *arr;
  if (1 == BOX_ELEMENTS (args))
    arr = box_copy (bif_array_of_pointer_arg (inst, args, 0, "log_text_array"));
  else
    {
      caddr_t qry_text = bif_string_arg (inst, args, 0, "log_text_array");
      caddr_t *arg1 = bif_array_of_pointer_arg (inst, args, 1, "log_text_array");
      int len = BOX_ELEMENTS (arg1);
      arr = (caddr_t *) dk_alloc_box ((len+1) * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      arr[0] = qry_text;
      memcpy (arr+1, arg1, len * sizeof (caddr_t));
    }
  bif_log_text_array_impl (inst, arr);
  dk_free_box ((caddr_t) arr);
  return 0;
}

caddr_t
bif_log_text (caddr_t * inst, caddr_t * err_ret, state_slot_t ** args)
{
  int inx, len = BOX_ELEMENTS (args);
  caddr_t *arr = (caddr_t *) dk_alloc_box (len * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  for (inx = 0; inx < len; inx++)
    arr[inx] = bif_arg (inst, args, inx, "log_text");
  bif_log_text_array_impl (inst, arr);
  dk_free_box ((caddr_t) arr);
  return 0;
}

caddr_t
bif_repl_text (caddr_t * inst, caddr_t * err_ret, state_slot_t ** args)
{
  return 0;
}


caddr_t
bif_repl_text_pushback (caddr_t * inst, caddr_t * err_ret, state_slot_t ** args)
{
  return 0;
}


caddr_t
bif_repl_set_raw (caddr_t * inst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) inst;
  long is_raw = (int) bif_long_arg (inst, args, 0, "repl_set_raw");

  sec_check_dba (qi, "repl_set_raw");

  qi->qi_trx->lt_repl_is_raw = is_raw;

  return 0;
}


caddr_t
bif_repl_is_raw (caddr_t * inst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) inst;
  return box_num (qi->qi_trx->lt_repl_is_raw);
}


caddr_t
bif_log_enable (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;
  int flag_is_null = 0;
  long flag = (long) bif_long_or_null_arg (qst, args, 0, "log_enable", &flag_is_null);
  long quiet;
  long old_value;
  int in_atomic = 4 & flag;
  flag &= 3;
  old_value = (((REPL_NO_LOG == qi->qi_trx->lt_replicate) ? 0 : 1) |	/* not || */
      (qi->qi_client->cli_row_autocommit ? 2 : 0));

  if (flag_is_null)
    return box_num (old_value);

  quiet = (BOX_ELEMENTS (args) > 1) ? (long) bif_long_arg (qst, args, 1, "log_enable") : 0L;

  if (!in_atomic && srv_have_global_lock (THREAD_CURRENT_THREAD))
    return box_num (old_value);

  if (!(flag & 1) && qi->qi_client != bootstrap_cli && qi->qi_trx->lt_replicate == REPL_NO_LOG)
    {
      if (quiet)
	{
	  qi->qi_client->cli_row_autocommit = ((flag & 2) ? 1 : 0);
	  if (!flag)
	    qi->qi_non_txn_insert = 0;
	  return box_num (old_value);
	}
      sqlr_new_error ("42000", "SR471", "log_enable () called twice to disable the already disabled log output");
    }

  qi->qi_client->cli_row_autocommit = ((flag & 2) ? 1 : 0);
  qi->qi_trx->lt_replicate = ((flag & 1) ? (caddr_t *) box_copy_tree ((caddr_t) qi->qi_client->cli_replicate) : REPL_NO_LOG);

  return box_num (old_value);
}


caddr_t
print_object_to_new_string (caddr_t xx, const char *fun_name, caddr_t * err_ret)
{
  scheduler_io_data_t iod;
  caddr_t res;
  dk_session_t *out = strses_allocate ();

  if (!SESSION_SCH_DATA (out))
  SESSION_SCH_DATA (out) = &iod;
  memset (&iod, 0, sizeof (iod));

  CATCH_WRITE_FAIL (out)
    {
      print_object (xx, out, NULL, NULL);
    }
  FAILED
    {
      dtp_t tag = DV_TYPE_OF (xx);
      *err_ret = srv_make_new_error ("22023", "SR479",
	  "Cannot serialize the data of type %s (%u) in BIF %s",
	  dv_type_title (tag), (unsigned) tag, fun_name );
    }
  END_WRITE_FAIL (out);
  if (!STRSES_CAN_BE_STRING (out))
    {
      *err_ret = STRSES_LENGTH_ERROR ("serialize");
      res = NULL;
    }
  else
    res = strses_string (out);
  strses_free (out);
  return (res);
}


caddr_t
bif_serialize (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t xx = bif_arg (qst, args, 0, "serialize");
  return print_object_to_new_string (xx, "serialize", err_ret);
}

caddr_t
bif_deserialize (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *)qst;
  caddr_t xx = bif_arg (qst, args, 0, "deserialize");
  caddr_t tmp_xx, res = NULL;
  dtp_t dtp = DV_TYPE_OF (xx);
  if (dtp == DV_SHORT_STRING || dtp == DV_LONG_STRING || dtp == DV_BIN)
    return (box_deserialize_string (xx, 0, 0));
  if (DV_DB_NULL == dtp)
    return NEW_DB_NULL;
  if (!IS_BLOB_HANDLE_DTP(dtp))
    sqlr_new_error ("22023", "SR581", "deserialize() requires a blob or NULL or string argument");
  if (((blob_handle_t *) xx)->bh_ask_from_client)
    sqlr_new_error ("22023", "SR582", "Blob argument to deserialize () must be a non-interactive blob");
  if (0 == (((blob_handle_t *) xx)->bh_length))
    sqlr_new_error ("22023", "SR583", "Empty blob is not a valid argument for deserialize () built-in function");
  if (((blob_handle_t*)xx)->bh_length > 10000000)
    sqlr_new_error ("22001", "SR584", "Blob longer than maximum string length not allowed in deserialize ()");
    tmp_xx = blob_to_string (qi->qi_trx, xx);
  QR_RESET_CTX
    {
      res = box_deserialize_string (tmp_xx, 0, 0);
    }
  QR_RESET_CODE
    {
      caddr_t err = thr_get_error_code (THREAD_CURRENT_THREAD);
      POP_QR_RESET;
      dk_free_box (tmp_xx);
      sqlr_resignal (err);
    }
  END_QR_RESET
  dk_free_box (tmp_xx);
  return res;
}


caddr_t
bif_composite (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  unsigned char *box;
  int inx, init, len;
  dtp_t key_image[255];
  dk_session_t sesn;
  ROW_OUT_SES (sesn, key_image);

  init = sesn.dks_out_fill;
  for (inx = 0; inx < BOX_ELEMENTS_INT (args); inx++)
  {
    caddr_t arg = bif_arg (qst, args, inx, "composite");
    print_object (arg, &sesn, NULL, NULL);
  }
  if (sesn.dks_out_fill > 254)
  sqlr_new_error ("22026", "FT001", "Length limit of composite exceeded.");
  len = sesn.dks_out_fill - init;
  box = (unsigned char *) dk_alloc_box (len + 2, DV_COMPOSITE);
  box[0] = DV_COMPOSITE;
  box[1] = len;
  memcpy (box + 2, &sesn.dks_out_buffer[init], len);
  return (caddr_t)box;
}


caddr_t
bif_composite_ref (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  unsigned char * box = (unsigned char *) bif_arg (qst, args, 0, "composite_ref");
  int inx = (int) bif_long_arg (qst, args, 1, "composite_ref");
  int ctr = 0, len;
  dk_session_t ses, *pses = &ses;
  caddr_t res = NULL;
  scheduler_io_data_t sio, *psio = &sio;

  if (DV_TYPE_OF (box) != DV_COMPOSITE)
    sqlr_new_error ("22023", "FT039", "composite expected for composite_ref");
  if (inx < 0)
    sqlr_new_error ("22023", "FT041", "negative offset not allowed in composite_ref");
  len = box[1] + 2;

#if 0
  ROW_IN_SES_2 (ses, sio, box + 2, len);
#else
  memset (pses, 0, sizeof (dk_session_t));
  memset (psio, 0, sizeof (scheduler_io_data_t));
  SESSION_SCH_DATA (pses) = psio;
  pses->dks_in_buffer = (char*) (box + 2);
  pses->dks_in_length = len;
  pses->dks_in_fill = len;
#endif
  CATCH_READ_FAIL (pses)
    {
      for (ctr = 0; ctr < inx + 1; ctr++)
	{
	  res = (caddr_t) scan_session_boxing (pses);
	  if (ctr < inx)
	    {
	      dk_free_tree (res);
	      res = NULL;
	    }
	}
    }
  FAILED
    {
      *err_ret = srv_make_new_error ("22003", "FT003",
	"zero based composite index out of range %d for length %d", inx, ctr);
      dk_free_tree (res);
      res = NULL;
    }
  END_READ_FAIL (pses);
  return res;
}


icc_lock_t *icc_lock_alloc (caddr_t name, client_connection_t * cli, query_instance_t * qi)
{
  NEW_VARZ (icc_lock_t, res);
  res->iccl_name = name                                                               ;
  res->iccl_cli = cli;
  res->iccl_qi = qi;
  return res;
}


icc_lock_t *icc_lock_from_hashtable (caddr_t name)
{
  icc_lock_t **hash_lock_ptr;
  icc_lock_t *hash_lock;
  if (NULL == icc_locks_mutex)
    GPF_T1 ("icc_locks_mutex is uninitialized");
  mutex_enter (icc_locks_mutex);
  hash_lock_ptr = ((icc_lock_t **)(id_hash_get (icc_locks, (caddr_t)(&name))));
  if (NULL == hash_lock_ptr)
    {
      hash_lock = icc_lock_alloc (box_copy (name), NULL, NULL);
      hash_lock->iccl_sem = semaphore_allocate (1);
      id_hash_set (icc_locks, (caddr_t)(&(hash_lock->iccl_name)), (caddr_t)(&(hash_lock)));
    }
  else
    hash_lock = hash_lock_ptr[0];
  mutex_leave (icc_locks_mutex);
  return hash_lock;
}


int icc_lock_release (caddr_t name, client_connection_t *cli)
{
  int sem_leave = 0;
  icc_lock_t *hash_lock;
  icc_lock_t *cli_lock = cli->cli_icc_lock;
  if (NULL == cli_lock)
    return 0;
  if (strcmp (cli_lock->iccl_name, name))
    return 0;
  hash_lock = icc_lock_from_hashtable (name);
  if (cli == hash_lock->iccl_cli)
    {
      sem_leave = 1;
    }
  if (NULL != hash_lock->iccl_qi)
    hash_lock->iccl_qi->qi_icc_lock = NULL;
  cli->cli_icc_lock = NULL;
  icc_lock_free (cli_lock);
  if (sem_leave)
    {
      hash_lock->iccl_qi = NULL;
      hash_lock->iccl_cli = NULL;
      semaphore_leave (hash_lock->iccl_sem);
    }
  return 1;
}


caddr_t bif_icc_name_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func, int name_to_set)
{
  query_instance_t *qi = (query_instance_t *)qst;
  caddr_t arg = bif_string_arg (qst, args, nth, func);
  int caller_is_dba = sec_bif_caller_is_dba ((query_instance_t *)qst);
  if (caller_is_dba)
    return arg;
  if (' ' == arg[0])
    sqlr_new_error ("42000", "ICC01", "Lock names whose first char is whitespace are reserved for dba group.");
  if (name_to_set)
    {
      char *at_sign = strrchr(arg, '@');
      if (NULL != at_sign)
  {
    char *proc_name = qi->qi_query->qr_proc_name;
    if (NULL == proc_name)
      proc_name = "";
    if (strcmp (at_sign+1,qi->qi_query->qr_proc_name))
      sqlr_new_error ("42000", "ICC02", "ICC lock '%s' whose name ends by '%s' cannot be set %s%s.",
        arg, at_sign,
        (('\0' == proc_name[0]) ? " outside the function body" : "in function "),
        proc_name );
  }
    }
  return arg;
}


caddr_t bif_icc_try_lock (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *)qst;
  client_connection_t *cli = qi->qi_client;
  caddr_t name = bif_icc_name_arg (qst, args, 1, "icc_try_lock", 1 /* to be set */);
  int flags = (int) bif_long_arg (qst, args, 2, "icc_try_lock");
  icc_lock_t *hash_lock, *cli_lock;
  if (NULL != cli->cli_icc_lock)
    {
      return NEW_DB_NULL;
    }
  hash_lock = icc_lock_from_hashtable (name);
  if (!semaphore_try_enter (hash_lock->iccl_sem))
    return box_num (0);
  hash_lock->iccl_cli = qi->qi_client;
  cli_lock = icc_lock_alloc (hash_lock->iccl_name, cli, ((flags & ICCL_IS_LOCAL) ? qi : NULL));
  hash_lock->iccl_qi = cli_lock->iccl_qi;
  cli_lock->iccl_sem = hash_lock->iccl_sem;
  cli->cli_icc_lock = cli_lock;
  if (flags & ICCL_IS_LOCAL)
    qi->qi_icc_lock = cli_lock;
  return box_num (1);
}


caddr_t bif_icc_lock_at_commit (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *)qst;
  client_connection_t *cli = qi->qi_client;
  caddr_t name = bif_icc_name_arg (qst, args, 0, "icc_lock_at_commit", 1 /* to be set */);
  int flags = (int) bif_long_arg (qst, args, 1, "icc_lock_at_commit");
  icc_lock_t *hash_lock, *cli_lock;
  if (NULL != cli->cli_icc_lock)
    {
      sqlr_new_error ("42000", "ICC03", "Unable to schedule ICC lock '%s' in the client connection that has %s the lock '%s' already.",
  name,
  (cli->cli_icc_lock->iccl_waits_for_commit ? "scheduled" : "obtained"),
  cli->cli_icc_lock->iccl_name );
    }
  hash_lock = icc_lock_from_hashtable (name);
  cli_lock = icc_lock_alloc (hash_lock->iccl_name, cli, ((flags & ICCL_IS_LOCAL) ? qi : NULL));
  cli_lock->iccl_waits_for_commit = 1;
  cli_lock->iccl_sem = hash_lock->iccl_sem;
  cli->cli_icc_lock = cli_lock;
  if (flags & ICCL_IS_LOCAL)
    qi->qi_icc_lock = cli_lock;
  return box_copy (name);
}


caddr_t bif_icc_unlock_now (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *)qst;
  client_connection_t *cli = qi->qi_client;
  caddr_t name = bif_string_arg (qst, args, 0, "icc_unlock_now");
  int release_res = icc_lock_release (name, cli);
  return box_num (release_res);
}


caddr_t
bif_txn_error (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  long code = (long) bif_long_arg (qst, args, 0, "txn_error");
  query_instance_t *qi = (query_instance_t *) qst;
  qi->qi_trx->lt_error = code;
  qi->qi_trx->lt_status = LT_BLOWN_OFF;
  return 0;
}


caddr_t
bif_trx_no (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
#ifdef PAGE_TRACE
  return (box_num (((query_instance_t *) qst)->qi_trx->lt_trx_no));
#else
  return (box_num (-1));
#endif
}


caddr_t
bif_commit (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;
  int rc;
  if (qi->qi_trx->lt_branch_of || qi->qi_trx->lt_cl_main_enlisted)
    sqlr_new_error ("4000X", "CL...", "Cannot explicitly commit a cluster transaction branch from non owner node.");
  IN_TXN;
  if (IS_ENLISTED_TXN (qi))
    {
      LEAVE_TXN;
      *err_ret = srv_make_new_error ("42000", "DC003", "COMMIT WORK is not allowed in a subordinate session");
      return NULL;
    }
  rc = lt_commit (qi->qi_trx, TRX_CONT);
  LEAVE_TXN;
  if (rc != LTE_OK)
    {
      caddr_t err;
      MAKE_TRX_ERROR (rc, err, LT_ERROR_DETAIL (qi->qi_trx));
      *err_ret = err;
    }
  else
    {
      /* At this point we are sure that there are no operations waiting for something.
         So it is possible to wait for an icc mutex without the danger of deadlock. */
      if (qi->qi_client->cli_icc_lock)
	{
	  icc_lock_t *cli_lock = qi->qi_client->cli_icc_lock;
	  if (cli_lock->iccl_waits_for_commit)
	    {
	      icc_lock_t *hash_lock = icc_lock_from_hashtable (cli_lock->iccl_name);
	      cli_lock->iccl_waits_for_commit = 0;
	      IO_SECT (qst)
	      {
		semaphore_enter (cli_lock->iccl_sem);
	      }
	      END_IO_SECT (err_ret);
	      hash_lock->iccl_cli = qi->qi_client;
	      hash_lock->iccl_qi = cli_lock->iccl_qi;
	    }
	}
    }
  return 0;
}


caddr_t
bif_rollback (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;
  if (qi->qi_trx->lt_branch_of)
    sqlr_new_error ("4000X", "CL...", "Cannot explicitly rollback a cluster transaction branch from non owner node");
  IN_TXN;
  if (IS_ENLISTED_TXN (qi))
    {
      LEAVE_TXN;
      *err_ret = srv_make_new_error ("42000", "DC004", "ROLLBACK WORK is not allowed in a subordinate session");
      return NULL;
    }
  lt_rollback (qi->qi_trx, TRX_CONT);
  LEAVE_TXN;
  return 0;
}


caddr_t
bif_txn_killall (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int n = BOX_ELEMENTS (args);
  int lte = n >= 1 ? bif_long_arg (qst, args, 0, "txn_killall") : LTE_TIMEOUT;
  query_instance_t *qi = (query_instance_t *) qst;
  sec_check_dba (qi, "txn_killall");
  if (lte)
    {
  IO_SECT (qi)
    {
      IN_TXN;
      lt_killall (qi->qi_trx, lte);
      LEAVE_TXN;
    }
  END_IO_SECT (err_ret);
    }
  return 0;
}


caddr_t
bif_replay (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;
  char *fname = bif_string_arg (qst, args, 0, "replay");
  int f = BOX_ELEMENTS (args) > 1 ? bif_long_arg (qst, args, 1, "replay") : f_read_from_rebuilt_database;
  int fd, flag;

  sec_check_dba (qi, "replay");

  if (lt_has_locks (qi->qi_trx))
    sqlr_new_error ("25000", "SR074", "replay must be run in a fresh transaction.");

  fd = open (fname, O_RDONLY | O_BINARY);
  if (fd < 0)
    {
      int errno_save = errno;
      sqlr_new_error ("42000", "FA002", "Can't open file %s, error %d (%s)", fname, errno, strerror (errno_save));
    }

  flag = f_read_from_rebuilt_database;
  f_read_from_rebuilt_database = f;
  IO_SECT (qst)
    {
  log_replay_file (fd);
    }
  END_IO_SECT (err_ret);
  close (fd);
  f_read_from_rebuilt_database = flag;

  return NULL;
}


caddr_t
bif_ddl_change (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char *tb = bif_string_arg (qst, args, 0, "__ddl_change");
  query_instance_t *qi = (query_instance_t *) qst;
  caddr_t repl = box_copy_tree ((box_t) qi->qi_trx->lt_replicate);
  /* save the logging mode across the autocommit inside the schema read */
  dbe_table_t * tb_def = sch_name_to_table (wi_inst.wi_schema, tb);
  if (tb_def && tb_def->tb_primary_key && tb_def->tb_primary_key->key_id <= KI_UDT)
    sqlr_new_error ("42000", ".....", "May not redef or reload def of system table");
  log_dd_change (qi -> qi_trx, tb);
  qi_read_table_schema (qi, tb);
  qi->qi_trx->lt_replicate = (caddr_t *)repl;
  return 0;
}

#if 0
caddr_t
bif_ddl_table_renamed (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char *old = bif_string_arg (qst, args, 0, "__ddl_table_renamed");
  char *_new = bif_string_arg (qst, args, 1, "__ddl_table_renamed");
  GPF_T1("This function is obsolete, replaced with one in ddlrun.c");
  query_instance_t *qi = (query_instance_t *) qst;
  caddr_t repl = box_copy_tree ((box_t) qi->qi_trx->lt_replicate);
  /* save the logging mode across the autocommit inside the schema read */
  ddl_rename_table_1 (qi, old, _new, err_ret);
  qi->qi_trx->lt_replicate = (caddr_t *)repl;
  return 0;
}
#endif

void ddl_index_def (query_instance_t * qi, caddr_t name, caddr_t table, caddr_t * cols, caddr_t * opts);

caddr_t
bif_ddl_index_def (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t name = bif_string_arg (qst, args, 0, "__ddl_index_def");
  caddr_t table = bif_string_arg (qst, args, 1, "__ddl_index_def");
  caddr_t * cols = (caddr_t *) bif_array_arg (qst, args, 2, "__ddl_index_def");
  caddr_t * opts = NULL;
  query_instance_t *qi = (query_instance_t *) qst;
  if (BOX_ELEMENTS (args) > 3)
  opts = (caddr_t *) bif_array_arg (qst, args, 3, "__ddl_index_def");
  ddl_index_def (qi, name, table, cols, opts);
  return 0;
}


caddr_t
bif_row_count_exceed (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t table = bif_string_arg (qst, args, 0, "__row_count_exceed");
  long cols = (long) bif_long_arg (qst, args, 1, "__row_count_exceed");
  query_instance_t *qi = (query_instance_t *) qst;
  long res = 0;

  if (BOX_ELEMENTS (args) > 2) /* if the third parameter specified then name is a view */
  res = count_exceed (qi, NULL, cols, table);
  else
  res = count_exceed (qi, table, cols, NULL);

  return box_num (res);
}


caddr_t
bif_view_changed (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char owner[MAX_NAME_LEN];
  char v_q[MAX_NAME_LEN];
  char v_n[MAX_NAME_LEN];
  /*query_t * qr; */
  caddr_t err = NULL;
  char *name = bif_string_arg (qst, args, 0, "__view_changed");
  char *qual = bif_string_arg (qst, args, 1, "__view_changed");
  char *text = bif_string_arg (qst, args, 2, "__view_changed");
  query_instance_t *qi = (query_instance_t *) qst;
  client_connection_t * cli = qi->qi_client;
  user_t * u = cli->cli_user;
  caddr_t q = cli->cli_qualifier;
  user_t * owner_user;
  sch_split_name ("", name, v_q, owner, v_n);
  owner_user = sec_name_to_user (owner);
  if (!owner_user)
  {
    if (strlen (text) > 50)
  text[50] = 0;
    sqlr_new_error ("28000", "SQ001", "No owner user in __view_changed for %s", text);
  }
  CLI_QUAL_ZERO (cli);
  CLI_SET_QUAL (cli, qual);
  cli->cli_user = owner_user;
  /* qr =*/ sql_compile (text, qi->qi_client, &err, SQLC_DO_NOT_STORE_PROC);
  CLI_RESTORE_QUAL (cli, q);
  cli->cli_user = u;
  tb_mark_affected (name);
  return 0;
}


caddr_t
bif_mapping_schema_changed (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  /*char owner[MAX_NAME_LEN];
  char v_q[MAX_NAME_LEN];
  char v_n[MAX_NAME_LEN];*/
  query_t * qr;
  caddr_t err = NULL;
  /*char *name = bif_string_arg (qst, args, 0, "__mapping_schema_changed");*/
  char *qual = bif_string_arg (qst, args, 1, "__mapping_schema_changed");
  char *text = bif_string_arg (qst, args, 2, "__mapping_schema_changed");
  query_instance_t *qi = (query_instance_t *) qst;
  client_connection_t * cli = qi->qi_client;
  user_t * u = cli->cli_user;
  caddr_t q = cli->cli_qualifier;
  user_t * owner_user;
  /*sch_split_name ("", name, v_q, owner, v_n);
  owner_user = sec_name_to_user (owner);
  if (!owner_user)
  {
    if (strlen (text) > 50)
  text[50] = 0;
    sqlr_new_error ("28000", "SQ001", "No owner user in __mapping_schema_changed for '%s'", name);
  }*/
  owner_user = sec_name_to_user ("dba");
  if (box_length (qual) >= MAX_NAME_LEN)
    sqlr_new_error ("22023", "SR485", "The qualifier cannot be longer than %d characters", MAX_NAME_LEN);
  cli->cli_qualifier = qual;
  cli->cli_user = owner_user;
  qr = sql_compile (text, qi->qi_client, &err, SQLC_DO_NOT_STORE_PROC);
  if (!err)
    err = qr_rec_exec (qr, qi->qi_client, NULL, qi, NULL, 0);
  cli->cli_qualifier = q;
  cli->cli_user = u;
  if (!err)
    sqlr_resignal (err);
  /* tb_mark_affected (name); -- not a view :) */
  return 0;
}


void
bif_copy_type (state_slot_t ** args, long *dtp, long *prec, long *scale, collation_t **collation)
{
  state_slot_t * arg = BOX_ELEMENTS (args) == 1 ? args[0] : NULL;
  if (!arg)
  return;
  *dtp = arg->ssl_sqt.sqt_dtp;
  *prec = arg->ssl_sqt.sqt_precision;
  *scale = arg->ssl_sqt.sqt_scale;
  *collation = NULL;
}


bif_type_t bt_copy = { (bif_type_func_t) bif_copy_type, 0, 0, 0};


caddr_t
bif_copy (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  /* identity function */
  return (box_copy_tree (bif_arg (qst, args, 0, "__copy")));
}


caddr_t
bif_copy_non_local (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  /* identity function, flagged soas to use index, for preventing use of local code */
  return (box_copy_tree (bif_arg (qst, args, 0, "__copy")));
}

/*In case of procedure replay we got procedure name, in case of a trigger we got a two-part name and table name */
caddr_t
bif_proc_changed (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char *name = bif_string_arg (qst, args, 0, "__proc_changed");
  query_instance_t *qi = (query_instance_t *) qst;
  client_connection_t *cli = qi->qi_trx->lt_client;
  user_t *org_user = cli->cli_user;
  caddr_t org_qual = cli->cli_qualifier;
  query_t *proc_qr, *rdproc;
  caddr_t err, tb_name = NULL;
  local_cursor_t *lc;
  int is_trig = 0;
  /* Procedure's calls published for replication */

  if (BOX_ELEMENTS (args) > 1)
    {
      is_trig = 1;
      tb_name = bif_string_arg (qst, args, 1, "__proc_changed");
    }

  if (!is_trig)
    rdproc = sql_compile (
	"select coalesce (P_TEXT, blob_to_string (P_MORE)), P_OWNER, P_QUAL "
	"from DB.DBA.SYS_PROCEDURES where P_NAME = ?",
	cli, &err, SQLC_DEFAULT);
  else
    rdproc = sql_compile_static ("select coalesce (T_TEXT, blob_to_string (T_MORE)), name_part (T_NAME, 1), T_SCH from DB.DBA.SYS_TRIGGERS where T_NAME = ? AND T_TABLE = ?", cli, &err, SQLC_DEFAULT);
  if (!err)
    {
      if (!is_trig)
	err = qr_rec_exec (rdproc, cli, &lc, qi, NULL, 1,
	    ":0", name, QRP_STR);
      else
	err = qr_rec_exec (rdproc, cli, &lc, qi, NULL, 2,
	    ":0", name, QRP_STR,
	    ":1", tb_name, QRP_STR);
    }
  CLI_QUAL_ZERO (cli);
  if (!err && lc_next (lc))
    {
      char *text = lc_nth_col (lc, 0);
      char *owner = lc_nth_col (lc, 1);
      char *qual = lc_nth_col (lc, 2);
      user_t *owner_user = sec_name_to_user (owner);
      /* Procedure's calls published for replication */
      int retry = 1;
      if (0 == strcmp (qual, "S")) qual = "DB";

      CLI_SET_QUAL (cli, qual);
      if (owner_user)
	cli->cli_user = owner_user;
      else
	{
	  log_error ("Procedure '%s' has bad owner, owner = %s", name, owner);
	  goto end;
	}
      /* Procedure's calls published for replication */
retry_compile:
      proc_qr = sql_compile (text, cli, &err, SQLC_DO_NOT_STORE_PROC);
#if 1
      if (err &&  0 != retry && cl_run_local_only == CL_RUN_CLUSTER && 0 == server_lock.sl_count && strstr (((caddr_t*)err)[2], "RDFNI"))
	{
	  dk_free_tree (err);
	  err = NULL;
	  retry = 0;
	  cl_rdf_inf_init (cli, &err);
	  if (!err)
            goto retry_compile;
	}
#endif
      if (err)
	{
	  if (text && strlen (text) > 60)
	    text[59] = 0;
	  log_error ("Error compiling stored procedure '%s' %s : %s", name,
	      ((caddr_t *) err)[QC_ERRNO], ((caddr_t *) err)[QC_ERROR_STRING],
	      text);
	  goto end;
	}
    }
end:
  cli->cli_user = org_user;
  CLI_RESTORE_QUAL (cli, org_qual);

  if (lc)
    lc_free (lc);
  if (err)
    dk_free_tree (err);
  if (!qi->qi_trx->lt_branch_of && !qi->qi_client->cli_is_log)
    cl_ddl (qi, qi->qi_trx, name, is_trig ? CLO_DDL_TRIG : CLO_DDL_PROC, tb_name);
  if (qi->qi_trx->lt_branch_of && !qi->qi_client->cli_is_log)
    {
      caddr_t * arr = is_trig
	? (caddr_t*)list (3, box_dv_short_string ("__proc_changed (?, ?)"), box_dv_short_string (name), box_dv_short_string (tb_name))
	: (caddr_t *)list (2, box_dv_short_string ("__proc_changed (?)"), box_dv_short_string (name));
      log_text_array (qi->qi_trx, (caddr_t) arr);
      dk_free_tree (arr);
    }
  qr_free (rdproc);
  return NULL;
}


caddr_t
bif_drop_trigger (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;
  char *tb_name = bif_string_arg (qst, args, 0, "__drop_trigger");
  char *tr = bif_string_arg (qst, args, 1, "__drop_trigger");
  dbe_table_t *tb = qi_name_to_table (qi, tb_name);
  if (!tb)
  sqlr_new_error ("42S02", "SQ002", "Bad table in drop trigger.");
  tb_drop_trig_def (tb, tr);
  return NULL;
}


caddr_t
bif_drop_proc (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_t * proc = NULL;
  query_instance_t *qi = (query_instance_t *) qst;
  char *proc_name = bif_string_arg (qst, args, 0, "__drop_proc");
  char * full_name;
  long is_proc = 1;

  if (BOX_ELEMENTS (args) > 1)
    is_proc = (long) bif_long_arg (qst, args, 1, "__drop_proc");

  if (is_proc)
    {
      full_name = sch_full_proc_name (isp_schema (qi->qi_space), proc_name,
    cli_qual (qi->qi_client), CLI_OWNER (qi->qi_client));
      if (full_name)
  proc = sch_proc_def (isp_schema (qi->qi_space), full_name);
    }
  else
    {
      full_name = sch_full_module_name (isp_schema (qi->qi_space), proc_name,
    cli_qual (qi->qi_client), CLI_OWNER (qi->qi_client));
      if (full_name)
  proc = sch_module_def (isp_schema (qi->qi_space), full_name);
    }
  if (!proc)
    {
      return (dk_alloc_box (0, DV_DB_NULL));
    }
  if (is_proc)
    sch_set_proc_def (isp_schema (qi->qi_space), proc->qr_proc_name, NULL);
  else
    sch_drop_module_def (isp_schema (qi->qi_space), proc);

  if (DO_LOG(LOG_DDL))
    {
      user_t * usr = ((query_instance_t *)(qst))->qi_client->cli_user;
      log_info ("DDLC_3 %s Drop procedure %.*s", GET_USER, LOG_PRINT_STR_L, proc_name);
    }

  return (box_dv_short_string (proc->qr_proc_name));
}


caddr_t
bif_proc_exists (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_t * proc = NULL;
  query_instance_t *qi = (query_instance_t *) qst;
  char *proc_name = bif_string_arg (qst, args, 0, "__proc_exists");
  long is_proc = 1;
  long check_grants = 0;
  char * full_name;

  if (BOX_ELEMENTS (args) > 1)
    is_proc = (long) bif_long_arg (qst, args, 1, "__proc_exists");

  if (BOX_ELEMENTS (args) > 2)
    check_grants = (long) bif_long_arg (qst, args, 2, "__proc_exists");

  switch (is_proc)
    {
      case 1: /* Plain Virtuoso/PL procedure or function */
	  proc = sch_proc_def (isp_schema (qi->qi_space), proc_name);
	  if (!proc)
	    {
	      full_name = sch_full_proc_name (isp_schema (qi->qi_space), proc_name,
		  cli_qual (qi->qi_client), CLI_OWNER (qi->qi_client));
	      if (full_name)
		proc = sch_proc_def (isp_schema (qi->qi_space), full_name);
	      if ((NULL != proc) && (NULL != proc->qr_aggregate))
		proc = NULL;
	    }
	  if (proc && check_grants && !sec_proc_check (proc, qi->qi_g_id, qi->qi_u_id))
	    proc = NULL;
	  break;
      case 2: /* BIF */
	  if (!bif_find (proc_name))
	    {
	      return (dk_alloc_box (0, DV_DB_NULL));
	    }
	  else
	    {
	      caddr_t res = sqlp_box_id_upcase (proc_name);
	      box_tag_modify (res, DV_SHORT_STRING);
	      return res;
	    }
	  break;
      case 0: /* Module */
	  full_name = sch_full_module_name (isp_schema (qi->qi_space), proc_name,
	      cli_qual (qi->qi_client), CLI_OWNER (qi->qi_client));
	  if (full_name)
	    proc = sch_module_def (isp_schema (qi->qi_space), full_name);
	  if (proc && check_grants && !sec_proc_check (proc, qi->qi_g_id, qi->qi_u_id))
	    proc = NULL;
	  break;
      case 4: /* User aggregate */
	  full_name = sch_full_proc_name (isp_schema (qi->qi_space), proc_name,
	      cli_qual (qi->qi_client), CLI_OWNER (qi->qi_client));
	  if (full_name)
	    proc = sch_proc_def (isp_schema (qi->qi_space), full_name);
	  if ((NULL != proc) && (NULL == proc->qr_aggregate))
	    proc = NULL;
	  if (proc && check_grants && !sec_proc_check (proc, qi->qi_g_id, qi->qi_u_id))
	    proc = NULL;
	  break;
      default:
	  sqlr_new_error ("42000", "SR313",
	      "Unsupported value of argument 2 in __proc_exists; only values 0, 1, 2 and 4 are valid, not %ld.", (long)is_proc);
    }
  if (NULL == proc)
    {
      return (dk_alloc_box (0, DV_DB_NULL));
    }
  if (proc && is_proc && QR_IS_MODULE_PROC (proc))
    sqlr_new_error ("42000", "SR313",
	"The procedure %s is part of module %s. Drop the module instead.",
	proc->qr_proc_name, proc->qr_module->qr_proc_name);
  return (box_dv_short_string (proc->qr_proc_name));
}


int
iso_string_to_code (char * i)
{
  switch (i[0])
  {
  case 'U': case 'u': return (ISO_UNCOMMITTED);
  case 'C': case 'c': return (ISO_COMMITTED);
  case 'R': case 'r': return (ISO_REPEATABLE);
  case 'S': case 's': return (ISO_SERIALIZABLE);
  default: sqlr_new_error ("22023", "SR075",
     "Bad isolation. Must be uncommitted / committed / repeatable / serializable");
  }
  return -1;
}


caddr_t
bif_set (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;
  caddr_t opt = bif_string_arg (qst, args, 0, "set");
  caddr_t value = bif_arg (qst, args, 1, "set");
  long lvalue = (long) unbox (value);
  dtp_t dtp = DV_TYPE_OF (value);

  if (0 == stricmp (opt, "TRIGGERS"))
    {
      int is_off = unbox (value) == 0;
      if (qi->qi_caller == CALLER_CLIENT)
	qi->qi_client->cli_no_triggers = is_off;
      else
	qi->qi_no_triggers = is_off;
    }
  else if (0 == stricmp (opt, "PARAM_BATCH"))
    {
      if (lvalue >= 0 && lvalue <= 1000)
	vd_param_batch = lvalue;
    }
  else if (0 == stricmp (opt, "ISOLATION"))
    {
      if (dtp != DV_LONG_STRING && dtp != DV_SHORT_STRING)
	sqlr_new_error ("22023", "SR076",
	    "ISOLATION option needs a string as value (uncommitted / committed / repeatable / serializable)");
      qi->qi_isolation = iso_string_to_code (value);
    }
  else if (0 == stricmp (opt, "LOCK_ESCALATION_PCT"))
    {
      lock_escalation_pct = lvalue;
    }
  else if (0 == stricmp (opt, "non_txn_insert"))
    {
      qi->qi_non_txn_insert = lvalue != 0;
    }
  else if (0 == stricmp (opt, "RESULT_TIMEOUT"))
    {
      client_connection_t * cli = qi->qi_client;
      if (cli->cli_ws && !qi->qi_query->qr_proc_name)
	sqlr_new_error ("42000", "RC...", "Query in a web context cannot set timeouts, must be a procedure for that");
      qi->qi_client->cli_anytime_timeout_orig = qi->qi_client->cli_anytime_timeout = lvalue;
      qi->qi_client->cli_anytime_checked = 0;
      qi->qi_client->cli_anytime_started = lvalue ? get_msec_real_time () : 0;
    }
  else   if (0 == stricmp (opt, "DIVE_CACHE"))
    dive_cache_enable = (int) unbox (value);
  else   if (0 == stricmp (opt, "NO_CHAR_C_ESCAPE"))
    qi->qi_client->cli_not_char_c_escape = (int) unbox (value);
  else   if (0 == stricmp (opt, "UTF8_EXECS"))
    qi->qi_client->cli_utf8_execs = (int) unbox (value);
  else   if (0 == stricmp (opt, "NO_SYSTEM_TABLES"))
    qi->qi_client->cli_no_system_tables = (int) unbox (value);
  else   if (0 == stricmp (opt, "CHARSET"))
    {
      caddr_t charset_name = sqlp_box_upcase (value);
      wcharset_t *charset = sch_name_to_charset (charset_name);
      if (!strcmp (charset_name, "UTF-8"))
	charset = NULL;
      dk_free_box (charset_name);
      qi->qi_client->cli_charset = charset ? charset : default_charset;
      if (NULL != charset && ssl_is_settable (args[1]))
	{
	  caddr_t ret_table = box_wide_char_string ((caddr_t) &charset->chrs_table[1],
	      255 * sizeof (wchar_t), DV_WIDE);
	  qst_set (qst, args[1], ret_table);
	}
    }
  else   if (0 == stricmp (opt, "HTTP_CHARSET"))
    {
      caddr_t charset_name = sqlp_box_upcase (value);
      wcharset_t * charset = sch_name_to_charset (charset_name);
      if (!strcmp (charset_name, "UTF-8"))
	charset = CHARSET_UTF8;
      dk_free_box (charset_name);
      if (qi->qi_client->cli_ws)
	qi->qi_client->cli_ws->ws_charset = charset ? charset : ws_default_charset;
    }
  else   if (0 == stricmp (opt, "MTS_2PC"))
    {
      int yes_no = (int) unbox (value);
      if (vd_use_mts)
	{
	  if ((yes_no == 1) || (yes_no == 0)) {
	    qi->qi_trx->lt_2pc._2pc_type = yes_no ? TP_MTS_TYPE : 0;
	  } else
	    {
	      sqlr_new_error ("22023", "DC001", "Bad option for SET 2PC");
	    }
	}
      else if (yes_no)
	sqlr_new_error ("37100", "DC002", "MTS support is not enabled");

    }
#ifdef VIRTTP
  else   if (0 == stricmp (opt, "VIRT_2PC"))
    {
      qi->qi_trx->lt_2pc._2pc_type = (unbox(value) ? TP_VIRT_TYPE : 0);
    }
#endif /* VIRTTP */

  else if (0 == stricmp (opt, "VDB_TIMEOUT"))
    {
      if (dtp != DV_LONG_INT)
	sqlr_new_error ("22023", "VD001", "Value of vdb_timeout must be an integer");
      if (lvalue >= 0 && lvalue <= 10000)
	qi->qi_rpc_timeout = lvalue;
    }

  else if (0 == stricmp (opt, "TRANSACTION_TIMEOUT"))
    {
      if (dtp != DV_LONG_INT)
	sqlr_new_error ("22023", "VD001", "Value of transaction_timeout must be an integer");
      if (lvalue >= 0)
	qi->qi_trx->lt_timeout = lvalue;
    }


  else if (0 == stricmp (opt, "HTTP_IGNORE_DISCONNECT"))
    {
      if (dtp != DV_LONG_INT)
	sqlr_new_error ("22023", "HT075", "Value of HTTP_IGNORE_DISCONNECT must be ON/OFF");
      if (qi->qi_client->cli_ws)
	qi->qi_client->cli_ws->ws_ignore_disconnect = (lvalue != 0) ? 1 : 0;
    }

  else
    sqlr_new_error ("42S22", "SR077" , "Bad option for SET");
  return NULL;
}


caddr_t
bif_checkpoint_interval (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;
  int32 old_cp_interval;
  int atomic = srv_have_global_lock  (THREAD_CURRENT_THREAD);
  c_checkpoint_interval = (int32) bif_long_arg (qst, args, 0, "checkpoint_interval");
  old_cp_interval = cfg_autocheckpoint / 60000L;

  sec_check_dba (qi, "checkpoint_interval");

  if (!atomic)
    {
    IN_CPT (((query_instance_t *) qst)->qi_trx);
    }
  if (-1 > c_checkpoint_interval)
  c_checkpoint_interval = -1;
  cfg_autocheckpoint = 60000L * c_checkpoint_interval;
#if 0
  /*
   * PMN: THIS SHOULD NEVER BE WRITTEN BACK INTO THE .INI FILE !!!!
   */
  cfg_set_checkpoint_interval (c_checkpoint_interval);
#endif
  if (!atomic)
    {
    LEAVE_CPT(((query_instance_t *) qst)->qi_trx);
    }
  return box_num (old_cp_interval);
}


caddr_t
bif_exec_error (caddr_t * qst, state_slot_t ** args, caddr_t err, dk_set_t warnings, shcompo_t *shc, query_t *qr)
{
  char buf[80];
  if ((BOX_ELEMENTS (args) < 3) || !ssl_is_settable (args[1]))
    {
      dk_free_tree (list_to_array (sql_warnings_save (warnings)));
      if (NULL != shc)
	shcompo_release (shc);
      else
	qr_free (qr);
      sqlr_resignal (err);
    }
  if (IS_POINTER(err))
    {
      qst_set (qst, args[1], ERR_STATE (err));
      if (ssl_is_settable (args[2]))
	qst_set (qst, args[2], ERR_MESSAGE (err));
      dk_free_box(err);
    }
  else
    {
      qst_set (qst, args[1], IS_POINTER(err) ? ERR_STATE (err) : box_dv_short_string("01W01"));
      if (ssl_is_settable (args[2]))
	{
	  snprintf (buf, sizeof (buf), "No WHENEVER statement provided for SQLCODE %d", (int)(ptrlong)(err));
	  qst_set (qst, args[2], box_dv_short_string(buf));
	}
    }
  return (box_num (-1));
}

static int
qr_have_named_params (query_t * qr)
{
  int rc = 0;
  if (!qr)
    return 0;
  DO_SET (state_slot_t *, ssl, &qr->qr_parms)
    {
      char *name = ssl->ssl_name;
      if (NULL != name && name[0] == ':')
	{
	  name++;
	  if (alldigits (name))
	    {
	      rc = 0;
	      break;
	    }
	  else
	    rc = 1;
	}
    }
  END_DO_SET ();
  return rc;
}


#define EXEC_PARAM(name, n) \
  name,  IS_BOX_POINTER(params) && BOX_ELEMENTS (params) > n ? box_copy_tree (params[n]) : NULL, QRP_RAW

static caddr_t *
make_qr_exec_params(caddr_t *params, int named_pars)
{
  caddr_t *ret;
  int inx;
  int n_params = 0;
  char szName[20];


  if (IS_BOX_POINTER(params))
    n_params = BOX_ELEMENTS(params);

  if (named_pars && 0 == (n_params % 2)) /* if named then params have te be a name/value */
    return (caddr_t *) box_copy_tree ((box_t) params);

  /* if the params are not named or passed array is not name/value pairs */
  ret = (caddr_t *) dk_alloc_box(2 * n_params * sizeof(caddr_t), DV_ARRAY_OF_POINTER);

  for (inx = 0; inx < 2 * n_params; inx += 2)
  {
    snprintf (szName, sizeof (szName), ":%d", inx / 2);
    ret[inx] = box_string(szName);
    ret[inx + 1] = box_copy_tree((box_t) params[inx/2]);
  }
  return ret;
}


static int
type_lc_destroy (caddr_t box)
{
  caddr_t *ret = (caddr_t *) box;
  local_cursor_t *lc;
  query_t *qr;

  if (!IS_BOX_POINTER(ret))
    return -1;

  qr = (query_t *) ret[0];
  lc = (local_cursor_t *) ret[1];

  if (lc)
  {
    lc_free (lc);
    ret[1] = NULL;
  }
  if (qr)
  {
    qr_free (qr);
    ret[0] = NULL;
  }

  return 0;
}

static caddr_t
bif_set_row_count (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;
  long increment = (long) bif_long_arg (qst, args, 0, "set_row_count");
  long what = BOX_ELEMENTS (args) > 1 ? (long) bif_long_arg (qst, args, 1, "set_row_count") : 0;
  int64 *affected_ptr;
  if (!(what & 0x1) && IS_BOX_POINTER (qi))
    affected_ptr = &(qi->qi_n_affected);
  else if ((what & 0x1) && IS_BOX_POINTER (qi->qi_caller))
    affected_ptr = &(qi->qi_caller->qi_n_affected);
  else
    return box_num (-1);
  if (what & 0x2)
    affected_ptr[0] = increment;
  else
    affected_ptr[0] += increment;
  return box_num (affected_ptr[0]);
}

id_hash_t * bif_exec_pending;
dk_mutex_t bif_exec_pending_mtx;
int bif_exec_ctr;
int enable_bif_exec_stat = 1;

int64
bif_exec_start (client_connection_t * cli, caddr_t text)
{
  bif_exec_stat_t stat;
  int64 ctr;
  if (!enable_bif_exec_stat)
    return 0;
  if (!bif_exec_pending)
    {
      dk_mutex_init (&bif_exec_pending_mtx, MUTEX_TYPE_SHORT);
      bif_exec_pending = id_hash_allocate (201, sizeof (int64), sizeof (bif_exec_stat_t), boxint_hash, boxint_hashcmp);
    }
  stat.exs_text = box_copy (text);
  stat.exs_start = get_msec_real_time ();
  stat.exs_cli = cli;
  mutex_enter (&bif_exec_pending_mtx);
  ctr = bif_exec_ctr++;
  id_hash_set (bif_exec_pending, (caddr_t)&ctr, (caddr_t)&stat);
  mutex_leave (&bif_exec_pending_mtx);
  return ctr;
}

void
bif_exec_done (int64 k)
{
  bif_exec_stat_t * place;
  if (!enable_bif_exec_stat)
    return;
  mutex_enter (&bif_exec_pending_mtx);
  place = (bif_exec_stat_t*) id_hash_get (bif_exec_pending, (caddr_t)&k);
  if (place)
    {
      dk_free_box (place->exs_text);
      id_hash_remove (bif_exec_pending, (caddr_t)&k);
    }
  mutex_leave (&bif_exec_pending_mtx);
}


caddr_t
bif_exec (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  /* in text, out sqlstate, out message, in params, in max_rows,
   * out result_desc, out rows, out handle, out warnings */
  int64 k;
  local_cursor_t *lc = NULL;
  dk_set_t rlist = NULL, proc_resultset = NULL;
  int n_args = BOX_ELEMENTS (args), n_cols, named_pars = 0;
  query_instance_t *qi = (query_instance_t *) qst;
  stmt_compilation_t *comp = NULL, *proc_comp = NULL;
  caddr_t _text;
  caddr_t text = NULL;
  caddr_t *params = NULL;
  caddr_t *new_params = NULL;
  caddr_t err = NULL;
  query_t *qr = NULL;
  long max = 0;
  client_connection_t *cli = qi->qi_client;
  caddr_t res = NULL;
  dk_set_t warnings = NULL;
  ST *pt = NULL;
  boxint max_rows = -1;
  int max_rows_is_set = 0;
  caddr_t *options = NULL;
  shcompo_t *shc = NULL;
  PROC_SAVE_VARS;

  _text = bif_arg (qst, args, 0, "exec");

  if (DV_STRINGP (_text))
    text = _text;
  else if (DV_WIDESTRINGP (_text))
    {
      unsigned out_len, wide_len = box_length (_text) / sizeof (wchar_t) - 1;
      text = dk_alloc_box (wide_len * 9 + 1, DV_LONG_STRING);
      out_len = (unsigned) cli_wide_to_escaped (QST_CHARSET (qst), 0, (wchar_t *) _text, wide_len,
	  (unsigned char *) text, wide_len * 9, NULL, NULL);
      text[out_len] = 0;
    }
  else if (ARRAYP (_text))
    {
      pt = (ST *) _text;
    }
  else
    sqlr_new_error ("22023", "SR308", "exec() called with an invalid text to execute");
  if (n_args > 3)
    params = (caddr_t *) bif_strict_array_or_null_arg (qst, args, 3, "exec");
  if (n_args > 4)
    {
      dtp_t options_dtp;
      options = (caddr_t *)bif_arg(qst, args, 4, "exec");
      options_dtp = DV_TYPE_OF (options);
      if (DV_ARRAY_OF_POINTER != options_dtp)
        {
          if (DV_LONG_INT == options_dtp)
            {
              max_rows = unbox ((caddr_t)options);
              max_rows_is_set = 1;
              options = NULL;
            }
          else if (DV_DB_NULL == options_dtp)
            options = NULL;
          else
            sqlr_new_error ("22023", "SR599", "Argument #5 of exec() should be either integer (max no of rows) or array of options or NULL");
        }
      else
        {
          caddr_t b = get_keyword_ucase_int (options, "max_rows", NULL);
          if (NULL != b)
            {
              max_rows = unbox (b);
              max_rows_is_set = 1;
              dk_free_tree (b);
            }
        }
    }
  PROC_SAVE_PARENT;
  warnings = sql_warnings_save (NULL);
  if (n_args < 8 || !ssl_is_settable (args[7]))
    { /* no cursor for stored procedures */
      if (max_rows_is_set)
        cli->cli_resultset_max_rows = max_rows ? max_rows : -1;
      if (n_args > 5 && ssl_is_settable (args[5]))
	cli->cli_resultset_comp_ptr = (caddr_t *) &proc_comp;
      if (n_args > 6 && ssl_is_settable (args[6]))
	cli->cli_resultset_data_ptr = &proc_resultset;
    }
  if (NULL != options)
    {
      caddr_t cache_b = get_keyword_ucase_int (options, "use_cache", NULL);
      if ((DV_LONG_INT == DV_TYPE_OF (cache_b)) && unbox (cache_b))
        {
          shc = shcompo_get_or_compile (&shcompo_vtable__qr, list (3, box_copy_tree (text), qi->qi_u_id, qi->qi_g_id), 0, qi, NULL, &err);
          if (NULL == err)
            {
              shcompo_recompile_if_needed (&shc);
              if (NULL != shc->shcompo_error)
                err = box_copy_tree (shc->shcompo_error);
            }
          if (NULL == err)
            qr = (query_t *)(shc->shcompo_data);
	  dk_free_tree (cache_b);
          goto qr_set;
        }
      dk_free_tree (cache_b);
    }
  if (pt)
    qr = sql_compile_1 ("", qi->qi_client, &err, SQLC_DEFAULT, pt, NULL);
  else
    qr = sql_compile (text, qi->qi_client, &err, SQLC_DEFAULT);

qr_set:
  if (err)
    {
      PROC_RESTORE_SAVED;
      if (text != _text)
	dk_free_box (text);
      dk_free_tree (list_to_array (proc_resultset));
      dk_free_tree ((caddr_t) proc_comp);
      res = bif_exec_error (qst, args, err, warnings, shc, qr);
      goto done;
    }
  if (text != _text)
    dk_free_box (text);
  named_pars = IS_BOX_POINTER(params) && qr_have_named_params (qr);
  new_params = make_qr_exec_params(params, named_pars);

  if (prof_on)
    cli->cli_log_qi_stats = 1;
  k = bif_exec_start (cli, qr->qr_text);
  cli_set_start_times (cli);
  err = qr_exec(qi->qi_client, qr, qi, NULL, NULL, &lc,
      new_params, NULL, 1);
  bif_exec_done (k);
  dk_free_box ((box_t) new_params);
  if (err)
    {
      if (cli->cli_terminate_requested == CLI_RESULT)
	{
	  cli->cli_terminate_requested = 0;
	  cli->cli_anytime_timeout_orig = cli->cli_anytime_timeout = 0;
	  cli->cli_anytime_started = 0;
	}
      if (lc)
	{
	  qi->qi_n_affected = lc->lc_row_count;
	  lc_free (lc);
	}
      PROC_RESTORE_SAVED;
      dk_free_tree ((caddr_t) proc_comp);
      dk_free_tree (list_to_array (proc_resultset));
      res = bif_exec_error (qst, args, err, warnings, shc, qr);
      goto done;
    }

  PROC_RESTORE_SAVED;
  if (lc) /* set the row_count */
    qi->qi_n_affected = (long)(lc->lc_row_count);

  if (lc && qr->qr_select_node)
    {
      long curr_row = 0;

      if (proc_comp)
	dk_free_tree ((caddr_t) proc_comp);
      if (proc_resultset)
	dk_free_tree (list_to_array (proc_resultset));

      if (max_rows > 0)
	max = max_rows;

      comp = qr_describe (qr, NULL);
      n_cols = BOX_ELEMENTS (comp->sc_columns);
      if (n_args > 5 && ssl_is_settable (args[5]))
	qst_set (qst, args[5], (caddr_t) comp);
      else
	dk_free_tree ((caddr_t) comp);

      if (n_args > 7)
	{
	  if (ssl_is_settable (args[7]))
	    {
	      caddr_t *ret = (caddr_t *) dk_alloc_box (3 * sizeof (caddr_t), DV_EXEC_CURSOR);
	      ret[0] = (caddr_t) qr;
	      ret[1] = (caddr_t) lc;
	      ret[2] = (caddr_t) (ptrlong) n_cols;
	      qst_set (qst, args[7], (caddr_t) ret);
	      res = box_num (0);
	      qr = NULL;
	      goto done;
	    }
	  else
	    {
	      lc_free (lc);
	      if (DV_TYPE_OF (qst_get (qst, args[7])) != DV_DB_NULL)
		{
		  res = bif_exec_error (qst, args,
		      srv_make_new_error ("22005", "SR078", "The cursor parameter is not settable"), warnings, shc, qr);
		  goto done;
		}
	    }
	}

      if (n_args > 6)
	{
	  int rs_needed = ssl_is_settable (args[6]);
	  while (lc_next (lc) && (max == 0 || (max > 0 && curr_row < max)))
	    {
	      int inx;
	      if (rs_needed)
		{
		  caddr_t *row = (caddr_t *)
		      dk_alloc_box (n_cols * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
		  for (inx = 0; inx < n_cols; inx++)
		    row[inx] = box_copy_tree (lc_nth_col (lc, inx));
		  dk_set_push (&rlist, (void *) row);
		}
	      curr_row += 1;
	      if (curr_row >= MAX_BOX_ELEMENTS)
		{
		  dk_free_tree (list_to_array (rlist));
		  lc_free (lc);
		  res = bif_exec_error (qst, args,
		      srv_make_new_error ("22023", "SR078", "The result set is too long, must limit result for at most %lu rows", (unsigned long) MAX_BOX_ELEMENTS), warnings, shc, qr);
		  goto done;
		}
	    }
	  if (rs_needed)
	    qst_set (qst, args[6],
		list_to_array (dk_set_nreverse (rlist)));
	  else
	    dk_free_tree (list_to_array (rlist));
	}
      err = lc->lc_error;
      lc->lc_error = NULL;
      lc_free (lc);
      if (err)
	{
	  res = bif_exec_error (qst, args, err, warnings, shc, qr);
	  goto done;
	}
    }
  else
    { /* handle procedure resultsets */
      if (n_args > 5 && ssl_is_settable (args[5]) && proc_comp)
	qst_set (qst, args[5], (caddr_t) proc_comp);
      else
	dk_free_tree ((caddr_t) proc_comp);

      if (n_args > 6 && ssl_is_settable (args[6]) && proc_resultset)
        {
          caddr_t ** rset = ((caddr_t **)list_to_array (dk_set_nreverse (proc_resultset)));
#ifdef MALLOC_DEBUG
          dk_check_tree (qst_get (qst, args[6]));
          dk_check_tree (rset);
#endif
	  qst_set (qst, args[6], (caddr_t) rset);
#ifdef MALLOC_DEBUG
          dk_check_tree (qst_get (qst, args[6]));
#endif
        }
      else if (n_args > 6 && ssl_is_settable (args[6]) && lc)
	qst_set (qst, args[6], box_num (lc->lc_row_count));
      else
        {
	  dk_free_tree (list_to_array (proc_resultset));
          if (n_args > 6 && ssl_is_settable (args[6]))
            {
#ifdef MALLOC_DEBUG
              dk_check_tree (qst_get (qst, args[6]));
#endif
	      qst_set (qst, args[6], NEW_DB_NULL);
            }
        }
      if (lc)
	{
	  err = lc->lc_error;
	  lc->lc_error = NULL;
	  lc_free (lc);
	  if (err)
	    {
	      res = bif_exec_error (qst, args, err, warnings, shc, qr);
	      goto done;
	    }
	}
    }
  if (n_args > 8 && ssl_is_settable (args[8]))
    {
      dk_set_t new_warnings = sql_warnings_save (NULL);
      qst_set (qst, args[8], list_to_array (dk_set_nreverse (new_warnings)));
    }

done:
  dk_free_tree (list_to_array (sql_warnings_save (warnings)));
  if (NULL != shc)
    shcompo_release (shc);
  else
    qr_free (qr);
  return res ? res : box_num (0);
}




#define LC_BOX_ARRAY 1
#define MAX_COLS 16

void
lc_result_array (int * set_ret, mem_pool_t * mp, srv_stmt_t * lc, int fmt, dk_set_t * all_res)
{
  QNCAST (QI, qi, lc->sst_qst);
  caddr_t * inst = lc->sst_qst; 
  caddr_t * row;
  int start = qi->qi_set, org_set, ref_set, set, sslinx;
  int n_read = lc->sst_vec_n_rows - start;
  int sets[MAX_COLS][128];
  select_node_t * sel = lc->sst_query->qr_select_node;
  state_slot_t ** out_slots = sel->sel_out_slots;
  int n_out = BOX_ELEMENTS (out_slots);
  int set_nos[128];
  n_read = MIN (n_read, 128);
  sslr_n_consec_ref (lc->sst_qst, (state_slot_ref_t*)sel->sel_set_no, set_nos, start, n_read);
  DO_BOX (state_slot_t *, ssl, sslinx, out_slots)
    {
      if (SSL_REF == ssl->ssl_type)
	{
	  sslr_n_consec_ref (lc->sst_qst, (state_slot_ref_t*)ssl, (int*)&sets[sslinx], start, n_read);
	}
    }
  END_DO_BOX;
  for (set = start; set < start + n_read; set++)
    {
      switch (fmt)
	{
	case LC_BOX_ARRAY:
	  org_set = set;
	  row = dk_alloc_box (n_out * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
	  for (sslinx = 0; sslinx < n_out; sslinx++)
	    {
	      state_slot_t * ssl = out_slots[sslinx];
	      if (SSL_REF == ssl->ssl_type)
		{
		  ref_set = sets[sslinx][set - start];
		  ssl = ((state_slot_ref_t*)ssl)->sslr_ssl;
		}
	      else
		ref_set = set;
	      row[sslinx] = box_copy_tree (sslr_qst_get (inst, (state_slot_ref_t*)ssl, ref_set));
	    }
	  if (all_res)
	    mp_set_push (mp, &all_res[set_nos[org_set - start]] + lc->sst_parms_processed, (void*)row);
	  break;
	}

    }
  qi->qi_set += n_read;
}


void 
exec_read_lc (srv_stmt_t * lc, int rc, caddr_t * err_ret, mem_pool_t * mp, int fmt, void * all_res)
{
  if (LC_INIT == rc)
    rc = lc_exec (lc, NULL, NULL, 0);
  for (;;)
    {
      if (LC_ERROR == rc)
	{
	  caddr_t err = lc->sst_pl_error;
	  lc->sst_pl_error = NULL;
	  *err_ret = err;
	  return;
	}
      if (LC_ROW == rc)
	{
	  while (((QI*)lc->sst_qst)->qi_set < lc->sst_vec_n_rows)
	    lc_result_array (NULL, mp,  lc, fmt, all_res);
	}
      if (LC_AT_END == rc)
	{
	  lc_reuse (lc);
	  return;
	}
      rc = lc_exec (lc, NULL, NULL, 0);
    }
}


caddr_t 
qr_exec_vec_lc (query_t * qr, caddr_t * caller, caddr_t ** params, caddr_t ** rsets)
{
  caddr_t err = NULL;
  QNCAST (QI, qi, caller);
  caddr_t * arr;
  int n_sets = BOX_ELEMENTS (params), rc, inx;
  mem_pool_t * mp = mem_pool_alloc ();
  dk_set_t *  all_res = (dk_set_t*)mp_alloc_box_ni (mp, sizeof (caddr_t) * n_sets, DV_BIN);
  int pinx;
  srv_stmt_t * lc;
  memzero (all_res, box_length (all_res));
  if (qr->qr_select_node)
    qr->qr_select_node->src_gen.src_input = (qn_input_fn)select_node_input_subq;
  lc = qr_multistate_lc (qr, qi, n_sets);
  if (qr->qr_select_node)
    lc->sst_qst[qr->qr_select_node->sel_out_quota] = 0; /* make no local out buffer of rows */
  rc = LC_AT_END;
  DO_BOX (caddr_t *, p_row, pinx, params)
    {
      rc = lc_exec (lc, p_row, NULL, 1);
      if (LC_INIT == rc)
	continue;
      if (LC_ERROR == rc)
	{
	  caddr_t err = lc->sst_pl_error;
	  lc->sst_pl_error = NULL;
	  dk_free_box ((caddr_t)lc);
	  return err;
	}
      exec_read_lc (lc, rc, &err, mp, LC_BOX_ARRAY, all_res);
      lc->sst_parms_processed = pinx;
    }
  END_DO_BOX;
  if (LC_AT_END != rc)
    exec_read_lc (lc, rc, &err, mp, LC_BOX_ARRAY, all_res);
  dk_free_box ((caddr_t)lc);
  arr = (caddr_t*)dk_alloc_box (n_sets * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  for (inx = 0; inx < n_sets; inx++)
    arr[inx] = (caddr_t)dk_set_to_array (dk_set_nreverse (all_res[inx]));
  *rsets = arr;
  mp_free (mp);
  return NULL;
}




caddr_t
bif_exec_vec (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  /* in text, out sqlstate, out message, in params, in max_rows,
   * out result_desc, out rows, out handle, out warnings */
  caddr_t * rsets = NULL;
  int64 k;
  dk_set_t proc_resultset = NULL;
  int n_args = BOX_ELEMENTS (args), n_cols;
  query_instance_t *qi = (query_instance_t *) qst;
  stmt_compilation_t *comp = NULL, *proc_comp = NULL;
  caddr_t _text;
  caddr_t text = NULL;
  caddr_t *params = NULL;
  caddr_t err = NULL;
  query_t *qr = NULL;
  long max = 0;
  client_connection_t *cli = qi->qi_client;
  caddr_t res = NULL;
  dk_set_t warnings = NULL;
  ST *pt = NULL;
  boxint max_rows = -1;
  int max_rows_is_set = 0;
  caddr_t *options = NULL;
  shcompo_t *shc = NULL;
  PROC_SAVE_VARS;

  _text = bif_arg (qst, args, 0, "exec");

  if (DV_STRINGP (_text))
    text = _text;
  else if (DV_WIDESTRINGP (_text))
    {
      unsigned out_len, wide_len = box_length (_text) / sizeof (wchar_t) - 1;
      text = dk_alloc_box (wide_len * 9 + 1, DV_LONG_STRING);
      out_len = (unsigned) cli_wide_to_escaped (QST_CHARSET (qst), 0, (wchar_t *) _text, wide_len,
	  (unsigned char *) text, wide_len * 9, NULL, NULL);
      text[out_len] = 0;
    }
  else if (ARRAYP (_text))
    {
      pt = (ST *) _text;
    }
  else
    sqlr_new_error ("22023", "SR308", "exec() called with an invalid text to execute");
  if (n_args > 3)
    {
      params = (caddr_t *) bif_strict_array_or_null_arg (qst, args, 3, "exec");
    }

  if (n_args > 4)
    {
      dtp_t options_dtp;
      options = (caddr_t *)bif_arg(qst, args, 4, "exec");
      options_dtp = DV_TYPE_OF (options);
      if (DV_ARRAY_OF_POINTER != options_dtp)
        {
          if (DV_LONG_INT == options_dtp)
            {
              max_rows = unbox ((caddr_t)options);
              max_rows_is_set = 1;
              options = NULL;
            }
          else if (DV_DB_NULL == options_dtp)
            options = NULL;
          else
            sqlr_new_error ("22023", "SR599", "Argument #5 of exec() should be either integer (max no of rows) or array of options or NULL");
        }
      else
        {
          caddr_t b = get_keyword_ucase_int (options, "max_rows", NULL);
          if (NULL != b)
            {
              max_rows = unbox (b);
              max_rows_is_set = 1;
              dk_free_tree (b);
            }
        }
    }
  PROC_SAVE_PARENT;
  warnings = sql_warnings_save (NULL);
  if (n_args < 8 || !ssl_is_settable (args[7]))
    { /* no cursor for stored procedures */
      if (max_rows_is_set)
        cli->cli_resultset_max_rows = max_rows ? max_rows : -1;
      if (n_args > 5 && ssl_is_settable (args[5]))
	cli->cli_resultset_comp_ptr = (caddr_t *) &proc_comp;
      if (n_args > 6 && ssl_is_settable (args[6]))
	cli->cli_resultset_data_ptr = &proc_resultset;
    }
  if (NULL != options)
    {
      caddr_t cache_b = get_keyword_ucase_int (options, "use_cache", NULL);
      if ((DV_LONG_INT == DV_TYPE_OF (cache_b)) && unbox (cache_b))
        {
          shc = shcompo_get_or_compile (&shcompo_vtable__qr, list (3, box_copy_tree (text), qi->qi_u_id, qi->qi_g_id), 0, qi, NULL, &err);
          if (NULL == err)
            {
              shcompo_recompile_if_needed (&shc);
              if (NULL != shc->shcompo_error)
                err = box_copy_tree (shc->shcompo_error);
            }
          if (NULL == err)
            qr = (query_t *)(shc->shcompo_data);
	  dk_free_tree (cache_b);
          goto qr_set;
        }
      dk_free_tree (cache_b);
    }
  if (pt)
    qr = sql_compile_1 ("", qi->qi_client, &err, SQLC_DEFAULT, pt, NULL);
  else
    qr = sql_compile (text, qi->qi_client, &err, SQLC_DEFAULT);

qr_set:
  if (err)
    {
      PROC_RESTORE_SAVED;
      if (text != _text)
	dk_free_box (text);
      dk_free_tree (list_to_array (proc_resultset));
      dk_free_tree ((caddr_t) proc_comp);
      res = bif_exec_error (qst, args, err, warnings, shc, qr);
      goto done;
    }
  if (text != _text)
    dk_free_box (text);

  if (prof_on)
    cli->cli_log_qi_stats = 1;
  k = bif_exec_start (cli, qr->qr_text);
  cli_set_start_times (cli);
  err =qr_exec_vec_lc (qr, qst, params,  &rsets);
  bif_exec_done (k);
  if (n_args > 6 && ssl_is_settable (args[6]))
    qst_set (qst, args[6], (caddr_t)rsets);
  else
    dk_free_tree ((caddr_t)rsets);
  if (err)
    {
      if (cli->cli_terminate_requested == CLI_RESULT)
	{
	  cli->cli_terminate_requested = 0;
	  cli->cli_anytime_timeout_orig = cli->cli_anytime_timeout = 0;
	  cli->cli_anytime_started = 0;
	}
      PROC_RESTORE_SAVED;
      dk_free_tree ((caddr_t) proc_comp);
      dk_free_tree (list_to_array (proc_resultset));
      res = bif_exec_error (qst, args, err, warnings, shc, qr);
      goto done;
    }

  PROC_RESTORE_SAVED;
done:
  dk_free_tree (list_to_array (sql_warnings_save (warnings)));
  if (NULL != shc)
    shcompo_release (shc);
  else
    qr_free (qr);
  return res ? res : box_num (0);
}




#if 0
caddr_t
bif_transpose (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t * arr = bif_array_of_pointer_arg (qst, args, 0, "transpose");
  int l = BOX_ELEMENTS (arr);
  if (l < 2)
    ;
}
#endif


/*##
     exec_metadata() , this is to retrieve the column metadata
     w/o execution the parameters are like exec ()
     no parameters or rowset data
*/

caddr_t
bif_exec_metadata (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  /* in text, out sqlstate, out message, * out result_desc */
  int n_args = BOX_ELEMENTS (args);
  query_instance_t *qi = (query_instance_t *) qst;
  stmt_compilation_t *comp = NULL, *proc_comp = NULL;
  caddr_t _text = bif_string_or_wide_or_null_arg (qst, args, 0, "exec_metadata");
  caddr_t text = NULL;
  caddr_t err = NULL;
  query_t *qr;
  client_connection_t *cli = qi->qi_client;
  PROC_SAVE_VARS;

  if (DV_STRINGP (_text))
    text = _text;
  else if (DV_WIDESTRINGP (_text))
    {
      unsigned out_len, wide_len = box_length (_text) / sizeof (wchar_t) - 1;
      text = dk_alloc_box (wide_len * 9 + 1, DV_LONG_STRING);
      out_len = (unsigned) cli_wide_to_escaped (QST_CHARSET (qst), 0, (wchar_t *) _text, wide_len,
    (unsigned char *) text, wide_len * 9, NULL, NULL);
      text[out_len] = 0;
    }
  else
    sqlr_new_error ("22023", "SR308", "exec_metadata() called with an invalid text to execute");

  PROC_SAVE_PARENT;

  cli->cli_resultset_max_rows = -1;
  if (n_args > 3 && ssl_is_settable (args[3]))
    cli->cli_resultset_comp_ptr = (caddr_t *) &proc_comp;

  qr = sql_compile (text, qi->qi_client, &err, SQLC_DEFAULT);

  PROC_RESTORE_SAVED;

  if (text != _text)
    dk_free_box (text);

  if (err)
    {
      return (bif_exec_error (qst, args, err, NULL, NULL, NULL));
    }

  if (qr->qr_select_node)
    {
      comp = qr_describe (qr, NULL);
      if (n_args > 3 && ssl_is_settable (args[3]))
  qst_set (qst, args[3], (caddr_t) comp);
      else
  dk_free_tree ((caddr_t) comp);
    }
  else
    {
      if (n_args > 3 && ssl_is_settable (args[3]) && proc_comp)
  qst_set (qst, args[3], (caddr_t) proc_comp);
      else
  dk_free_tree ((caddr_t) proc_comp);

    }
  qr_free (qr);
  return (box_num (0));
}

caddr_t
bif_exec_score (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  /* in text, out sqlstate, out message, * out result_desc */
  query_instance_t *qi = (query_instance_t *) qst;
  caddr_t _text = bif_string_or_wide_or_null_arg (qst, args, 0, "exec_metadata");
  caddr_t text = NULL;
  caddr_t err = NULL;
  caddr_t score_box = NULL;
  float score;
  client_connection_t *cli = qi->qi_client;
  PROC_SAVE_VARS;

  if (DV_STRINGP (_text))
    text = _text;
  else if (DV_WIDESTRINGP (_text))
    {
      unsigned out_len, wide_len = box_length (_text) / sizeof (wchar_t) - 1;
      text = dk_alloc_box (wide_len * 9 + 1, DV_LONG_STRING);
      out_len = (unsigned) cli_wide_to_escaped (QST_CHARSET (qst), 0, (wchar_t *) _text, wide_len,
	  (unsigned char *) text, wide_len * 9, NULL, NULL);
      text[out_len] = 0;
    }
  else
    sqlr_new_error ("22023", "SR308", "exec_metadata() called with an invalid text to execute");

  PROC_SAVE_PARENT;

  cli->cli_resultset_max_rows = -1;
  score_box = (caddr_t) sql_compile (text, qi->qi_client, &err, SQLC_SQLO_SCORE);
  if (score_box)
    {
      score = unbox_float (score_box);
      dk_free_tree (score_box);
    }
  else
    score = 0;

  score = compiler_unit_msecs * score;

  PROC_RESTORE_SAVED;

  if (text != _text)
    dk_free_box (text);

  if (err)
    {
      return (bif_exec_error (qst, args, err, NULL, NULL, NULL));
    }
  return (box_float (score));
}


caddr_t
bif_exec_next (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t *handle = (caddr_t *) bif_arg (qst, args, 0, "exec_next");
  local_cursor_t *lc;
  int n_cols;

  int n_args = BOX_ELEMENTS (args);
  caddr_t err = NULL;

  if (n_args < 4)
    return bif_exec_error (qst, args,
	srv_make_new_error ("22023", "SR079", "Too few arguments to exec_next(cursor, state, message, row)"), NULL, NULL, NULL);

  if (DV_TYPE_OF (handle) != DV_EXEC_CURSOR || BOX_ELEMENTS(handle) != 3)
    return bif_exec_error (qst, args,
	srv_make_new_error ("22023", "SR080", "Parameter 4 is not a valid local exec handle"), NULL, NULL, NULL);

  /*qr = (query_t *) handle[0];*/
  lc = (local_cursor_t *) handle[1];
  n_cols = (int) (ptrlong) handle[2];

  if (!lc_next (lc))
    {
      err = lc->lc_error;
      lc->lc_error = NULL;
      if (err)
	{
	  return (bif_exec_error (qst, args, err, NULL, NULL, NULL));
	}
      else
	return (box_num(SQL_NO_DATA_FOUND));
    }
  else
    {
      int inx;
      caddr_t *row = (caddr_t *)
	  dk_alloc_box (n_cols * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      for (inx = 0; inx < n_cols; inx++)
	row[inx] = box_copy_tree (lc_nth_col (lc, inx));
      if (ssl_is_settable (args[3]))
	qst_set (qst, args[3], (caddr_t) row);
      else
	dk_free_tree ((caddr_t) row);
      return box_num (0);
    }
  NO_CADDR_T;
}


caddr_t
bif_exec_close (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t *handle = (caddr_t *) bif_arg (qst, args, 0, "exec_close");
  local_cursor_t *lc;
  query_t *qr;

  if (DV_TYPE_OF (handle) != DV_EXEC_CURSOR || BOX_ELEMENTS(handle) != 3)
    return bif_exec_error (qst, args,
	srv_make_new_error ("22023", "SR081", "Parameter 1 is not a valid local exec handle"), NULL, NULL, NULL);

  qr = (query_t *) handle[0];
  lc = (local_cursor_t *) handle[1];

  if (NULL != lc)
    lc_free (lc);
  handle[0] = NULL;
  qr_free (qr);
  handle[1] = NULL;

  return (NULL);
}


caddr_t
bif_mutex_stat (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
#ifdef MTX_METER
  mutex_stat ();
  fflush (stdout);
#endif
  return 0;
}


caddr_t
bif_mutex_meter (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;
  /* number of iterations, flag = 0 for all on same, 2 all on different, 2 all on same with try enter */
  long inx;
  long n = (long) bif_long_arg (qst, args, 0, "mutex_meter");
  long fl = (long) bif_long_arg (qst, args, 1, "mutex_meter");
  long type = (long) bif_long_arg (qst, args, 2, "mutex_meter");
  long waits = 0;
  static dk_mutex_t *stmtx;
  static dk_mutex_t *stmtx_long;
  static dk_mutex_t *stmtx_spin;
  dk_mutex_t *mtx;

  sec_check_dba (qi, "mutex_meter");

  if (!stmtx)
    {
      stmtx = mutex_allocate_typed (MUTEX_TYPE_SHORT);
      stmtx_long = mutex_allocate_typed (MUTEX_TYPE_LONG);
      stmtx_spin = mutex_allocate_typed (MUTEX_TYPE_SPIN);
    }

  if (1 == fl)
    mtx = mutex_allocate_typed (type);
  else
    {
      switch (type)
	{
	case MUTEX_TYPE_SPIN:
	  mtx = stmtx_spin;
	  break;
	case MUTEX_TYPE_LONG:
	  mtx = stmtx_long;
	  break;
	default:
	  mtx = stmtx;
	}
    }

  for (inx = 0; inx < n; inx++)
    {
      if (2 == fl)
	{
	  if (mutex_try_enter (mtx))
	    mutex_leave (mtx);
	  else
	    {
	      waits++;
	      mutex_enter (mtx);
	      mutex_leave (mtx);
	    }
	}
      else
	{
	  mutex_enter (mtx);
	  mutex_leave (mtx);
	}
    }

  if (1 == fl)
    mutex_free (mtx);

  return box_num (waits);
}


caddr_t
bif_spin_wait_meter (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;
  /* number of iterations, flag = 0 for all on same, 2 all on different, 2 all on same with try enter */
  int hncooh = 0;
#ifdef _PTHREAD_H
  long inx;
  long n_loops = (long) bif_long_arg (qst, args, 0, "spin__wait_meter");
  long loop_len = (long) bif_long_arg (qst, args, 1, "spin_wait_meter");
  dk_mutex_t *mtx;

  sec_check_dba (qi, "spin_wait_meter");

  mtx = mutex_allocate ();
  mutex_enter (mtx);

  for (inx = 0; inx < n_loops; inx++)
    {
      int inx2;
      pthread_mutex_trylock ((pthread_mutex_t *) mtx->mtx_handle);
      for (inx2 = 0; inx2 < loop_len; inx2++)
	hncooh++;
    }

  mutex_leave (mtx);
  mutex_free (mtx);
#endif

  return box_num (hncooh);
}


caddr_t
bif_spin_meter (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
#if HAVE_SPINLOCK
  query_instance_t *qi = (query_instance_t *) qst;
  long inx;
  long n = (long) bif_long_arg (qst, args, 0, "spin_meter");
  long fl = (long) bif_long_arg (qst, args, 1, "spin_meter");
  static pthread_spinlock_t sl_st;
  pthread_spinlock_t *sl;
  static int inited = 0;

  sec_check_dba (qi, "spin_meter");

  if (!inited)
    {
      pthread_spin_init (&sl_st, 0);
      inited = 1;
    }

  if (fl)
    {
      sl = malloc (sizeof (pthread_spinlock_t));
      pthread_spin_init (sl, 0);
    }
  else
    sl = &sl_st;

  for (inx = 0; inx < n; inx++)
    {
      pthread_spin_lock (sl);
      pthread_spin_unlock (sl);
    }

  if (fl)
    {
      pthread_spin_destroy (sl);
      free (sl);
    }
#endif

  return 0;
}


long
mem_traverse (int32 ** arr, int sz, int step, int wr)
{
  int inx;
  long sum = 0;
  int ainx = 0;
  for (ainx = 0; ainx < sz; ainx++)
    {
      for (inx = 0; inx < 1024; inx += step)
	{
	  sum += arr[ainx][inx];
	  if (wr)
	    arr[ainx][inx]++;
	}
    }
  return sum;
}


caddr_t
bif_mem_meter (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;
  long inx, ctr, inx2;
  long sum = 0;
  long n = (long) bif_long_arg (qst, args, 0, "mem_meter");
  long sz = (long) bif_long_arg (qst, args, 1, "mem_meter");

  sec_check_dba (qi, "mem_meter");

  for (ctr = 0; ctr < n; ctr++)
    {
      int32 **arr = (int32 **) malloc (sizeof (void *) * sz);

      for (inx = 0; inx < sz; inx++)
	{
	  arr[inx] = (int32 *) malloc (sizeof (int32) * 1024);
	  memset (arr[inx], 0, 1024 * sizeof (int32));
	}

      for (inx = 0; inx < sz; inx++)
	{
	  for (inx2 = 0; inx2 < 1024; inx2++)
	    sum += arr[inx][inx2];
	}

      sum += mem_traverse (arr, sz, 10, 0);
      sum += mem_traverse (arr, sz, 10, 1);
      sum += mem_traverse (arr, sz, 7, 0);
      sum += mem_traverse (arr, sz, 22, 0);
      sum += mem_traverse (arr, sz, 9, 1);
      sum += mem_traverse (arr, sz, 40, 0);
      sum += mem_traverse (arr, sz, 10, 1);
      sum += mem_traverse (arr, sz, 7, 0);
      sum += mem_traverse (arr, sz, 11, 1);

      for (inx = 0; inx < sz; inx++)
	free ((void *) arr[inx]);

      free ((void *) arr);
    }

  return box_num (sum);
}


caddr_t
bif_malloc_meter (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;
  long inx;
  long n = (long) bif_long_arg (qst, args, 0, "malloc_meter");
  caddr_t x;
  long fl = (long) bif_long_arg (qst, args, 1, "malloc_meter");

  sec_check_dba (qi, "malloc_meter");

/*  static dk_mutex_t * stmtx; */
  for (inx = 0; inx < n; inx++)
    {
      if (0 == fl)
	{
	  x = (caddr_t) malloc (16);
	  free ((void *) x);
	}
      else
	{
	  x = (caddr_t) dk_alloc (16);
	  dk_free (x, 16);
	}
    }

  return 0;
}


caddr_t
bif_copy_meter (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;
  long target[100];
  long inx, ct;
  long n = (long) bif_long_arg (qst, args, 0, "copy_meter");
  /*caddr_t x; */
  long fl = (long) bif_long_arg (qst, args, 1, "copy_meter");
  char *from = (char *) &n;

  sec_check_dba (qi, "copy_meter");

  for (ct = 0; ct < n; ct++)
    {
      switch (fl)
	{
	case 0:
	  memcpy (target, from, 32);
	  break;

	case 1:
	  memcpy (target, from + 1, 32);
	  break;

	case 2:
	  for (inx = 0; inx < 8; inx++)
	    ((long *) &target)[inx] = ((long *) from)[inx];
	  break;

	case 3:
	  from = ((char *) &fl) + 1;
	  for (inx = 0; inx < 8; inx++)
	    ((long *) &target)[inx] = ((long *) from)[inx];
	  break;

	case 4:
	  for (inx = 0; inx < 4; inx++)
	    ((int64 *) & target)[inx] = ((int64 *) from)[inx];
	  break;

	case 5:
	  from = ((char *) &fl) + 1;
	  for (inx = 0; inx < 4; inx++)
	    ((int64 *) & target)[inx] = ((int64 *) from)[inx];
	  break;
	}
    }

  return 0;
}


caddr_t
bif_busy_meter (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;
  long inx, n_busy = 0, n_samples = 0, n_key;
  long n = (long) bif_long_arg (qst, args, 0, "busy_meter");
  caddr_t tb_name = BOX_ELEMENTS (args) > 1 ? bif_string_arg (qst, args, 1, "busy_meter") : NULL;
  dbe_table_t *tb = NULL;
  long *counts = NULL;

  sec_check_dba (qi, "busy_meter");

  if (tb_name)
    {
      tb = sch_name_to_table (wi_inst.wi_schema, tb_name);
      if (tb)
	{
	  counts = dk_alloc_box_zero (dk_set_length (tb->tb_keys) * sizeof (long), DV_STRING);
	}
    }

  for (inx = 0; inx < n; inx++)
    {
      if (mutex_try_enter (wi_inst.wi_txn_mtx))
	mutex_leave (wi_inst.wi_txn_mtx);
      else
	n_busy++;
      if (tb)
	{
	  n_key = 0;
	  DO_SET (dbe_key_t *, key, &tb->tb_keys)
	  {
	    int inx;
	    for (inx = 0; inx < IT_N_MAPS; inx++)
	      {
		if (mutex_try_enter (&key->key_fragments[0]->kf_it->it_maps[inx].itm_mtx))
		  mutex_leave (&key->key_fragments[0]->kf_it->it_maps[inx].itm_mtx);
		else
		  counts[n_key]++;
	      }
	    n_key++;
	  }
	  END_DO_SET ();
	}
      n_samples++;
      virtuoso_sleep (0, 1000);
    }

  printf ("  %ld samples taken, %ld with txn mtx occupied\n", n_samples, n_busy);
  if (tb)
    {
      n_key = 0;
      DO_SET (dbe_key_t *, key, &tb->tb_keys)
      {
	printf ("Key %s busy %ld\n", key->key_name, counts[n_key]);
	n_key++;
      }
      END_DO_SET ();
      dk_free_box ((caddr_t) counts);
    }

  return box_num (n_busy);
}


caddr_t
bif_self_meter (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;
  long inx;
  long n = (long) bif_long_arg (qst, args, 0, "self_meter");

  sec_check_dba (qi, "self_meter");

  for (inx = 0; inx < n; inx++)
    {
      THREAD_CURRENT_THREAD;
    }

  return 0;
}

#ifndef RUSAGE_SELF
#undef HAVE_GETRUSAGE
#endif

caddr_t
bif_getrusage (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
#ifdef HAVE_GETRUSAGE
  caddr_t * res = dk_alloc_box_zero (sizeof (caddr_t) * 10, DV_ARRAY_OF_POINTER);
  struct rusage ru;
  getrusage (RUSAGE_SELF, &ru);
  res[0] = box_num (ru.ru_utime.tv_sec * 1000 +  ru.ru_utime.tv_usec / 1000);
  res[1] = box_num (ru.ru_stime.tv_sec * 1000 +  ru.ru_stime.tv_usec / 1000);
  res[2] = box_num (ru.ru_maxrss);
  res[3] = box_num (ru.ru_minflt);
  res[4] = box_num (ru.ru_majflt);
  res[5] = box_num (ru.ru_nswap);
  res[6] = box_num (ru.ru_inblock);
  res[7] = box_num (ru.ru_oublock);
  res[8] = box_num (ru.ru_nvcsw);
  res[9] = box_num (ru.ru_nivcsw);
  return (caddr_t) res;
#else
  return box_num (0);
#endif
}


caddr_t
bif_rdtsc (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return box_num (rdtsc ());
}


void dk_alloc_cache_status (resource_t ** cache);

caddr_t
bif_alloc_cache_status (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  dk_alloc_cache_status ((resource_t**) THREAD_CURRENT_THREAD->thr_alloc_cache);
  return 0;
}


caddr_t
bif_row_count (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t *) qst;
  long what = 0;
  long ret = 0;
  if (BOX_ELEMENTS (args) > 0)
    what = bif_long_arg (qst, args, 0, "row_count");
  if (what)
    {
      if (qi->qi_caller && IS_BOX_POINTER (qi->qi_caller))
        ret = qi->qi_caller->qi_n_affected;
    }
  else
    ret = qi->qi_n_affected;
  return (box_num (ret));
}


caddr_t
bif_assert_found (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t *) qst;
  qi->qi_assert_found = 1;
  return 0;
}


caddr_t
bif_atomic (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;
  int flag = (int) bif_long_arg (qst, args, 0, "__atomic");

  sec_check_dba (qi, "__atomic");

  srv_global_lock (qi, flag);

  return 0;
}

caddr_t
bif_is_atomic (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return box_num (server_lock.sl_count);
}


caddr_t
bif_trx_disk_log_length (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t *) qst;
  long mode = bif_long_arg (qst, args, 0, "__trx_disk_log_length");
  lock_trx_t *lt = qi->qi_trx;
  switch (mode)
    {
    case 0: return box_num (lt->lt_log->dks_bytes_sent);
    case 1:
      if (txn_after_image_limit > 0)
        return box_num ((txn_after_image_limit - 10000L) - lt->lt_log->dks_bytes_sent);
      return box_num (2000000000);
    default: sqlr_new_error ("22023", "SR562", "Supported values of argument 1 of __trx_disk_log_length() are 0 and 1 but not %ld", mode);
    }
  return NULL; /* never reached */
}

caddr_t
bif_client_trace (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;
  long fl;

  sec_check_dba (qi, "client_trace");

  fl = (long) bif_long_arg (qst, args, 0, "client_trace");

  if (0 != fl)
    {
      client_trace_flag = 1;
      return (caddr_t) 1L;
    }

  client_trace_flag = 0;

  return 0;
}




dk_hash_t * fcache;
dk_mutex_t * fcache_mtx;


caddr_t
bif_cache_set (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  long id = (long) bif_long_arg (qst, args, 0, "cache_set");
  caddr_t d = bif_arg (qst, args, 1, "cache_set");
  caddr_t od;
  mutex_enter (fcache_mtx);
  od = (caddr_t) gethash ((void*) (ptrlong) id, fcache);
  dk_free_tree (od);
  sethash ((void*)(ptrlong) id, fcache, (void*) box_copy_tree (d));
  mutex_leave (fcache_mtx);
  return 0;
}

caddr_t
bif_cache_get (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  long id = (long) bif_long_arg (qst, args, 0, "cache_get");
  caddr_t od;
  mutex_enter (fcache_mtx);
  od = (caddr_t) gethash ((void*) (ptrlong) id, fcache);
  mutex_leave (fcache_mtx);
  return (box_copy_tree (od));
}



caddr_t
bif_sqlo (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  ptrlong sqlo_enable = bif_long_arg (qst, args, 0, "sqlo");
  sec_check_dba ((query_instance_t *) qst, "sqlo");
  hash_join_enable = (int) (2 & sqlo_enable);
  sqlo_print_debug_output = (int) (4 & sqlo_enable);
  return NULL;
}


caddr_t
bif_hic_clear (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  sec_check_dba ((query_instance_t *) qst, "sqlo");
  hic_clear ();
  return NULL;
}

caddr_t
bif_hic_set_memcache_size (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  long new_size = bif_long_arg (qst, args, 0, "hic_set_memcache_size");
  long old_size = hi_end_memcache_size;
  if (new_size >= 0 && QI_IS_DBA (qst))
    hi_end_memcache_size = new_size;
  return box_num (old_size);
}

caddr_t
bif_bit_and (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int64 x1 = (int64) bif_long_arg (qst, args, 0, "bit_and");
  int64 x2 = (int64) bif_long_arg (qst, args, 1, "bit_and");
  return box_num (x1 & x2);
}


caddr_t
bif_bit_or (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int64 x1 = (int64) bif_long_arg (qst, args, 0, "bit_or");
  int64 x2 = (int64) bif_long_arg (qst, args, 1, "bit_or");
  return box_num (x1 | x2);
}


caddr_t
bif_bit_xor (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int64 x1 = (int64) bif_long_arg (qst, args, 0, "bit_xor");
  int64 x2 = (int64) bif_long_arg (qst, args, 1, "bit_xor");
  return box_num (x1 ^ x2);
}


caddr_t
bif_bit_not (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int64 x1 = (int64) bif_long_arg (qst, args, 0, "bit_not");
  return box_num (~x1);
}


caddr_t
bif_bit_shift (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int64 x1 = (int64) bif_long_arg (qst, args, 0, "bit_shift");
  int64 x2 = (int64) bif_long_arg (qst, args, 1, "bit_shift");
  if (x2 >= 0)
    return box_num (x1 << x2);
  else
    return box_num (x1 >> (-x2));
}

caddr_t
bif_byte_order_check (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  long order = bif_long_arg (qst, args, 0, "byte_order_check");
  caddr_t *qi = QST_INSTANCE (qst);
  if (!QI_IS_DBA (qi))
    return 0;
  if (f_read_from_rebuilt_database) /* doing a replay from backup dump must be possible on a different architecture */
    return 0;
  if (order != DB_ORDER_UNKNOWN && order != DB_SYS_BYTE_ORDER)
    {
      log_error ("The transaction log file has been produced with wrong byte order. You can not replay it on this machine. "
"If the transaction log is empty or you do not want to replay it then delete it and start the server again.");
      call_exit(0);
    }
  return NEW_DB_NULL;
}

caddr_t
bif_server_version_check (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t version = bif_string_arg (qst, args, 0, "server_version_check");
  caddr_t *qi = QST_INSTANCE (qst);
  if (!QI_IS_DBA (qi))
    return 0;
  if (strcmp (version, DBMS_SRV_VER))
    {
      log_error ("The transaction log file has been produced by server version '%s'. "
"The version of this server is '%s'. "
"If the transaction log is empty or you do not want to replay it then delete it and start the server again. "
"Otherwise replay the log using the server of version '%s' and make checkpoint and shutdown to ensure that the log is empty, then delete it and start using new version.",
        version, DBMS_SRV_VER, version );
      call_exit(0);
    }
  return NEW_DB_NULL;
}

caddr_t
bif_server_id_check (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t id = bif_string_arg (qst, args, 0, "server_id_check");
  caddr_t *qi = QST_INSTANCE (qst);
  unsigned char db_id[16];
  int inx, c;
  if (!QI_IS_DBA (qi))
    return 0;
  if (f_read_from_rebuilt_database)
    return 0;

  if (box_length (id) < sizeof (db_id) * 2)
    return 0;

  for (inx = 0; inx < sizeof (db_id); inx ++)
    {
      sscanf (id + (inx * 2), "%02x", &c);
      db_id[inx] = (unsigned char) c;
    }

  if (memcmp (db_id, wi_inst.wi_master->dbs_id, sizeof (db_id)))
    {
      log_error ("The transaction log file has been produced by different server instance.");
      call_exit(0);
    }
  return NEW_DB_NULL;
}

caddr_t
bif_proc_params_num (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_t * proc = NULL;
  query_instance_t *qi = (query_instance_t *) qst;
  char *proc_name = bif_string_arg (qst, args, 0, "procedure_params_num");
  char * full_name;

  proc = sch_proc_def (isp_schema (qi->qi_space), proc_name);
  if (!proc)
    {
      full_name = sch_full_proc_name (isp_schema (qi->qi_space), proc_name,
	  cli_qual (qi->qi_client), CLI_OWNER (qi->qi_client));
      if (full_name)
	proc = sch_proc_def (isp_schema (qi->qi_space), full_name);
    }
  if (NULL == proc)
    return (dk_alloc_box (0, DV_DB_NULL));
  if (proc->qr_to_recompile)
    {
      proc = qr_recompile (proc, err_ret);
      if (*err_ret)
	return NULL;
    }
  return (box_num (dk_set_length (proc->qr_parms)));
}

void
fcache_init ()
{
  fcache = hash_table_allocate (23);
  dk_hash_set_rehash (fcache, 3);
  fcache_mtx = mutex_allocate ();
  bif_define ("cache_set", bif_cache_set);
  bif_define ("cache_get", bif_cache_get);
}


void bif_cursors_init (void);

sql_tree_tmp * st_varchar;
sql_tree_tmp * st_nvarchar;



caddr_t bif_hash (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);
caddr_t bif_md5_box (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);


caddr_t
bif_box_hash (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return box_num (box_hash (bif_arg (qst, args, 0, "box_hash")));
}


#if 1
caddr_t bif_grouping (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);
caddr_t bif_grouping_set_bitmap (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);
#endif

#if 1

#define FASSERT(x,s) if (!(x)) { fprintf (stderr, "%s assert failed\n", (s)); } \
	else { fprintf (stderr, "%s assert PASSED\n", (s)); }

caddr_t
test_xid_encode_decode (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  virtXID test_xid, * test_xid_2;
  char * res;

  test_xid.formatID = 1234;
  test_xid.gtrid_length = 5678;
  test_xid.bqual_length = 12343444;
#if 0 /*GK : sure gpf */
  strcpy (test_xid.data, "hello world!!!!");
#endif

  res = xid_bin_encode ((unsigned char*) &test_xid);

  fprintf (stderr, "xid encoding = %s\n", res);

  test_xid_2 = (virtXID *) xid_bin_decode (res);
  fprintf (stderr, "decoded xid = %ld %ld %ld %s\n",
	(long) test_xid_2->formatID,
	(long) test_xid_2->gtrid_length,
	(long) test_xid_2->bqual_length,
	test_xid_2->data);

  dk_free_box (res);

  FASSERT (test_xid_2->formatID==test_xid.formatID, "formatID decoding");
  FASSERT (test_xid_2->gtrid_length==test_xid.gtrid_length, "gtrid decoding");
  FASSERT (test_xid_2->bqual_length==test_xid.bqual_length, "bqual_length decoding");
  FASSERT ((!strcmp (test_xid_2->data, test_xid.data)), "data decoding");

  dk_free_box ((box_t) test_xid_2);


  test_xid_2 = (virtXID *) xid_bin_decode("00000000000000110a302918bc631a40200000002100000000000000100000c100000000c830020bc00700000831020b0000000041000000000000002e0000b6687474703a2f2f7777772e77332e6f72672f313939392f58534c2f5472616e73666f726d3a76616c75652d6f66000000000000003100000000000000170000b6687474703a2f2f6c6f63616c");
  fprintf (stderr, "decoded xid = %ld %ld %ld %s\n",
	(long) test_xid_2->formatID,
	(long) test_xid_2->gtrid_length,
	(long) test_xid_2->bqual_length,
	test_xid_2->data);

  fflush (stderr);

  return NULL;
}
#endif


#define BITS_IN_CHAR 8
#define BITARR_BYTE_LEN(a) (IS_STRING_DTP(DV_TYPE_OF((a)))? (box_length((a))-1) : box_length((a)))
#define BITARR_LEN(a) (IS_STRING_DTP(DV_TYPE_OF((a))) ? \
	((box_length((a))-3)*BITS_IN_CHAR+(a)[0]) \
	:((box_length((a))-2)*BITS_IN_CHAR+(a)[0]))



static
caddr_t v_bit_print (int ret, unsigned char* b)
{
  char tmp[1024];
  char *ptr = tmp;
  int inx;
  memset (tmp, 0, 1024);
  sprintf (ptr, "%d: ", (int) b[0]);
  ptr+=strlen(ptr);

  for (inx=1;inx<(BITARR_BYTE_LEN(b)/sizeof(unsigned char));inx++)
    {
      sprintf(ptr,"%.2x ", b[inx]);
      ptr+=strlen(ptr);
    }
  if (!ret)
    log_info ("ba: %s", tmp);
  else
    return box_string (tmp);
  return 0;
}

static
caddr_t bif_bit_print (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  unsigned char * b = (unsigned char *) bif_varchar_or_bin_arg (qst, args, 0, "bit_print");
  return v_bit_print(1, b);
}


static
caddr_t bif_v_bit_or (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  unsigned char * vb1 = (unsigned char *) bif_varchar_or_bin_arg (qst, args, 0, "v_bit_or");
  unsigned char * vb2 = (unsigned char *) bif_varchar_or_bin_arg (qst, args, 1, "v_bit_or");
  unsigned char * b1, *b2;
  unsigned char * res;
  int inx;
#if 0
  log_info ("OR:");
  v_bit_print (vb1);
  v_bit_print (vb2);
#endif

  if (BITARR_LEN(vb1) > BITARR_LEN(vb2))
    {
      b1 = vb1;
      b2 = vb2;
    }
  else
    {
      b1 = vb2;
      b2 = vb1;
    }
  res = (unsigned char *) box_copy ((box_t) b1);
  for (inx=1;inx<(BITARR_BYTE_LEN(b2)/sizeof(char));inx++)
    res[inx] |= b2[inx];
  return (caddr_t) res;
}

static
caddr_t bif_v_bit_and (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  unsigned char * vb1 = (unsigned char *) bif_varchar_or_bin_arg (qst, args, 0, "v_bit_and");
  unsigned char * vb2 = (unsigned char *) bif_varchar_or_bin_arg (qst, args, 1, "v_bit_and");
  unsigned char * b1,*b2;
  unsigned char * res;
  int inx;
#if 0
  log_info ("AND:");
  v_bit_print (vb1);
  v_bit_print (vb2);
#endif

  if (BITARR_LEN(vb1) > BITARR_LEN(vb2))
    {
      b1 = vb2;
      b2 = vb1;
    }
  else
    {
      b1 = vb1;
      b2 = vb2;
    }
  res = (unsigned char *) box_copy ((box_t) b1);
  for (inx=1;inx<(BITARR_BYTE_LEN(b1)/sizeof(char));inx++)
    res[inx] &= b2[inx];
  return (caddr_t) res;
}

static
caddr_t bif_v_bit_not (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  unsigned char * b1 = (unsigned char *) bif_varchar_or_bin_arg (qst, args, 0, "v_bit_not");
  unsigned char * res;
  int inx;
#if 0
  log_info ("NOT:");
  v_bit_print (b1);
#endif

  res = (unsigned char *) box_copy ((box_t) b1);
  for (inx=1;inx<(BITARR_BYTE_LEN(b1)/sizeof(char));inx++)
    res[inx] = ~(res[inx]);
  if (res[0])
    res[inx-1] &= ((1 << res[0]) - 1);
  return (caddr_t) res;
}

static
caddr_t bif_v_bit_all_pos (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  unsigned char * res = (unsigned char *) box_copy (bif_bin_arg (qst, args, 0, "v_bit_all_pos"));
  int idx = 1;
  while (idx < box_length ((box_t) res) / sizeof (unsigned char))
    {
      res [idx++] = 0xFF;
    }
  /* idx always > 2 since there is no exception for empty script */
  res [idx - 1] = (1 << res [0]) - 1;
  return (caddr_t) res;
}

static
caddr_t bif_all_bits_set (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  unsigned char * res = (unsigned char *) bif_varchar_or_bin_arg (qst, args, 0, "all_bits_set");
  /* long cnt = bif_long_arg (qst, args, 1, "all_bits_set"); */
  long cnt = BITARR_LEN (res);
  int inx;

#if 0
  if (BITARR_LEN(res) < cnt)
    return box_num (0);
#endif

  for (inx=0;inx<(cnt/BITS_IN_CHAR);inx++)
    {
      if (res[inx+1] != 0xFF)
	goto fail;
    }
  /* if (res[inx+1] != ((1 << (cnt % BITS_IN_CHAR + 1)) - 1)) */
  if ((cnt%BITS_IN_CHAR)&&(res[inx+1]!=((1<<(cnt%BITS_IN_CHAR))-1)))
    goto fail;
  return box_num(1);
 fail:
  return box_num(0);
}

static
caddr_t bif_v_true (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  unsigned char * res = (unsigned char *) bif_varchar_or_bin_arg (qst, args, 0, "v_bit_not");
  int inx;
#if 0
  log_info ("TRUE:");
  v_bit_print (res);
#endif

  for (inx=1;inx<(BITARR_BYTE_LEN(res)/sizeof(char));inx++)
    if (res[inx] != 0)
      return box_num (1);
  return box_num(0);
}

static
caddr_t bif_v_equal (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  unsigned char * vb1 = (unsigned char *) bif_varchar_or_bin_arg (qst, args, 0, "bit_v_equal");
  unsigned char * vb2 = (unsigned char *) bif_varchar_or_bin_arg (qst, args, 1, "bit_v_equal");
  unsigned char * b1, *b2;
#if 0
  log_info ("EQ:");
  v_bit_print (vb1);
  v_bit_print (vb2);
#endif

  if (BITARR_BYTE_LEN (vb1) > BITARR_BYTE_LEN (vb2))
    {
      b1 = vb2;
      b2 = vb1;
    }
  else
    {
      b1 = vb1;
      b2 = vb2;
    }
  if (!memcmp (b1+1, b2+1, BITARR_BYTE_LEN (b1) - 1))
    { /* check is the rest of biggest array is nulls */
      int inx = BITARR_BYTE_LEN (b1)/sizeof (char);
      while (inx < (BITARR_BYTE_LEN (b2) / sizeof (char)))
	{
	  if (b2[inx++])
	    return box_num (0);
	}
      return box_num (1);
    }
  return box_num (0);
}

static
caddr_t bif_bit_set (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  unsigned char * bitarr = (unsigned char *) bif_varchar_or_bin_arg (qst, args, 0, "bit_set");
  long bitn = bif_long_arg (qst, args, 1, "bit_set");
  int len = BITARR_LEN(bitarr);
  unsigned char * res;
#if 0
  log_info ("SET: %ld", bitn);
  v_bit_print (bitarr);
#endif


  if ((bitn/BITS_IN_CHAR) >= (len/BITS_IN_CHAR))
    res = (unsigned char *) dk_alloc_box (bitn/BITS_IN_CHAR + 2, DV_BIN);
  else
    res = (unsigned char *) dk_alloc_box (BITARR_BYTE_LEN (bitarr), DV_BIN);
  memset (res, 0, BITARR_BYTE_LEN (res));
  memcpy (res, bitarr, BITARR_BYTE_LEN(bitarr));
  if (bitn >= len)
    res[0]=(unsigned char)(bitn % BITS_IN_CHAR + 1);
  res[1+bitn/BITS_IN_CHAR] |= 1 << (bitn % BITS_IN_CHAR);
  return (caddr_t) res;
}

static
caddr_t bif_is_set (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  unsigned char * bitarr = (unsigned char *) bif_varchar_or_bin_arg (qst, args, 0, "bit_set");
  long bitn = bif_long_arg (qst, args, 1, "bit_set");
  int len = BITARR_LEN(bitarr);
#if 0
  log_info ("IS SET: %ld", bitn);
  v_bit_print (bitarr);
#endif

  if ((bitn/BITS_IN_CHAR) > (len/BITS_IN_CHAR))
    {
      return box_num (0);
    }
  if (0!=(bitarr[1+bitn/BITS_IN_CHAR] & 1 << (bitn % BITS_IN_CHAR)))
    {
      return box_num (1);
    }
  else
    {
      return box_num (0);
    }
}

static
caddr_t bif_bit_clear (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  unsigned char * bitarr = (unsigned char *) bif_varchar_or_bin_arg (qst, args, 0, "bit_cleart");
  long bitn = bif_long_arg (qst, args, 1, "bit_clear");
  int len = BITARR_LEN(bitarr);
  unsigned char * res;
#if 0
  log_info ("CLEAR: %ld", bitn);
  v_bit_print (bitarr);
#endif

  res = (unsigned char *) box_copy ((box_t) bitarr);
  if ((bitn/BITS_IN_CHAR) > (len/BITS_IN_CHAR))
    {
      return (caddr_t) res;
    }
  res[1+bitn/BITS_IN_CHAR] &= ~(1 << (bitn % BITS_IN_CHAR));
  return (caddr_t) res;
}

static
caddr_t bif_bit_v_count (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  unsigned char * bitarr = (unsigned char *) bif_varchar_or_bin_arg (qst, args, 0, "bit_v_count");
  int len = BITARR_LEN(bitarr);
  return box_num(len);
}


void ssl_constant_init ();
void bif_diff_init ();
void bif_aq_init ();
void rdf_box_init ();
void   dbs_cache_check (dbe_storage_t *, int);


caddr_t
bif_cache_check (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  wi_inst.wi_checkpoint_atomic = 1;
  dbs_cache_check (wi_inst.wi_master, IT_CHECK_ALL);
  wi_inst.wi_checkpoint_atomic = 0;
  return NULL;
}


extern uint32 col_ac_last_duration;

caddr_t
bif_autocompact (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
    {
  int flags = BOX_ELEMENTS (args) ? bif_long_arg (qst, args, 0, "__autocompact") : 0;
  if (flags)
{
      buffer_pool_t * bp = wi_inst.wi_bps[0];
      if (2 == flags)
	col_ac_last_duration = 0; /* do col ac anyway, even if not due by local reckoning */
      bp_flush (bp);
	}
      else
    wi_check_all_compact (0);
  return NULL;
}


caddr_t
bif_qi_is_branch (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
    {
  QNCAST (query_instance_t, qi, qst);
  return box_num (qi->qi_is_branch);
    }


caddr_t
bif_partition_def (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return NULL;
}

caddr_t
bif_dummy (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
    {
  return NEW_DB_NULL;
}


caddr_t
bif_cl_idn (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
	{
  return box_copy_tree (bif_arg (qst, args, 0, "cl_idn"));
}


caddr_t
bif_cl_idni (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
	    {
  return box_copy_tree (bif_arg (qst, args, 0, "cl_idn"));
	    }


void
bif_cl_idni_vec (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, state_slot_t * res)
	    {
  QNCAST (QI, qi, qst);
  data_col_t * res_dc = QST_BOX (data_col_t *, qst, res->ssl_index);
  data_col_t * arg;
  if (!res_dc || BOX_ELEMENTS (args))
    return;
  arg = QST_BOX (data_col_t *, qst, args[0]->ssl_index);
  DC_CHECK_LEN (res_dc, qi->qi_n_sets - 1);
  if (SSL_VEC == args[0]->ssl_type)
		{
      memcpy_16 (res_dc->dc_values, arg->dc_values, sizeof (int64) * qi->qi_n_sets);
		}
  else if (SSL_REF == args[0]->ssl_type)
		{
      int sets[256];
      int inx, last, inx2;
      int64 * resv = (int64 *)res_dc->dc_values;
      int64 * argv = (int64*)arg->dc_values;
      for (inx = 0; inx < qi->qi_n_sets; inx += 256)
	{
	  last = MIN (qi->qi_n_sets, inx + 256);
	  sslr_n_consec_ref (qst, (state_slot_ref_t*)args[0], sets, inx, last - inx);
	  for (inx2 = 0; inx2 < last - inx; inx2++)
	    resv[inx2 + inx] = argv[sets[inx2]];
	    }
	}
  res_dc->dc_n_values = qi->qi_n_sets;
}


caddr_t
bif_idn (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return box_mt_copy_tree (bif_arg (qst, args, 0, "cl_idn"));
}


caddr_t
bif_idn_no_copy (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return box_copy_tree (bif_arg (qst, args, 0, "cl_idn"));
}


void
bif_idn_no_copy_vec (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, state_slot_t * ret)
    {
  QNCAST (QI, qi, qst);
  caddr_t * source;
  data_col_t * ret_dc, *arg;
  db_buf_t set_mask = qi->qi_set_mask;
  int set, n_sets = qi->qi_n_sets;
  ret_dc = QST_BOX (data_col_t *, qst, ret->ssl_index);
  dc_reset (ret_dc);
  DC_CHECK_LEN (ret_dc, qi->qi_n_sets);
  if (BOX_ELEMENTS (args) < 1 || SSL_VEC != args[0]->ssl_type )
    goto no;
  arg = QST_BOX (data_col_t *, qst, args[0]->ssl_index);
  if (!(DCT_BOXES & arg->dc_type) || !(DCT_BOXES & ret_dc->dc_type) || set_mask)
    goto no;
  source = (caddr_t*)arg->dc_values;
  n_sets = MIN (n_sets, arg->dc_n_values);
  for (set = 0; set < n_sets; set++)
	{
      ((caddr_t*)ret_dc->dc_values)[set] = source[set];
      source[set] = NULL;
    }
  ret_dc->dc_n_values = qi->qi_n_sets;
  return;
 no:
  *err_ret = BIF_NOT_VECTORED;
}


caddr_t
bif_asg_v (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  QNCAST (QI, qi, qst);
  caddr_t v = bif_arg (qst, args, 1, "asg_v");
  int set = qi->qi_set;
  state_slot_t * ssl = args[0];
  qi->qi_set = sslr_set_no (qst, args[0], qi->qi_set);
  if (SSL_REF == ssl->ssl_type)
    ssl = ((state_slot_ref_t *)ssl)->sslr_ssl;
  if (SSL_VEC != ssl->ssl_type)
    sqlr_new_error ("42000", "VECEQ", "asg_v applies only to vectored variables");
  qst_set (qst, ssl, v);
  qi->qi_set = set;
  return NULL;
}


caddr_t
bif_rdf_rand_impl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  double upper_limit = 1.0;
  if (BOX_ELEMENTS (args) > 0)
    upper_limit = bif_double_arg (qst, args, 0, "rdf_rand_impl");
  if (upper_limit <= DBL_EPSILON)
    sqlr_new_error ("22023", "SL001", "The range limit of SPARQL rand() function is too small");

  return (box_double (sqlbif_rnd_double (&rnd_seed, upper_limit)));
}

caddr_t
bif_rdf_floor_ceil_impl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, int is_floor)
{
  caddr_t arg = bif_arg_unrdf (qst, args, 0, is_floor ? "rdf_floor_impl" : "rdf_ceil_impl");
  switch (DV_TYPE_OF (arg))
    {
    case DV_LONG_INT: return box_copy (arg);
    case DV_DOUBLE_FLOAT: { double x = unbox_double (arg); return box_double (is_floor ? floor(x) : ceil (x)); }
    case DV_SINGLE_FLOAT: { float x = unbox_float (arg); return box_float (is_floor ? floor(x) : ceil (x)); }
    case DV_NUMERIC:
      {
        numeric_t res;
        numeric_t x = (numeric_t)arg;
        if (0 == x->n_scale)
          return box_copy (arg);
        if (is_floor ? x->n_neg : !x->n_neg)
          {
            numeric_t temp;
            numeric_t shifted;
            /* construct +-0.5 */
            NUMERIC_VAR (temp_buf);
            NUMERIC_INIT (temp_buf);
            temp = (numeric_t)temp_buf;
            temp->n_value[0] = 1;
            temp->n_len = 1;
            temp->n_scale = 0;
            temp->n_neg = is_floor;
            shifted = numeric_allocate ();
            num_add (shifted, x, temp, 0);
            res = numeric_allocate ();
            numeric_rescale_noround (res, shifted, shifted->n_len+1, 0);
            numeric_free (shifted);
            return (caddr_t)res;
          }
        res = numeric_allocate ();
        numeric_rescale_noround (res, x, x->n_len+1, 0);
        return (caddr_t)res;
      }
    case DV_DB_NULL: return NEW_DB_NULL;
    default:
      sqlr_new_error ("22023", "SL002", "The SPARQL 1.1 function %.10s() needs a numeric value as an argument", is_floor ? "floor" : "ceil");
    return NULL;
    }
}

caddr_t
bif_rdf_floor_impl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_rdf_floor_ceil_impl (qst, err_ret, args, 1);
}

caddr_t
bif_rdf_ceil_impl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_rdf_floor_ceil_impl (qst, err_ret, args, 0);
}

caddr_t
bif_rdf_round_impl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg = bif_arg_unrdf (qst, args, 0, "rdf_round_impl");
  switch (DV_TYPE_OF (arg))
    {
    case DV_LONG_INT: return box_copy (arg);
    case DV_DOUBLE_FLOAT: { double x = unbox_double (arg); return box_double (((x-floor(x)) >= 0.5 ? ceil(x) : floor(x))); }
    case DV_SINGLE_FLOAT: { float x = unbox_float (arg); return box_float (((x-floor(x)) >= 0.5 ? ceil(x) : floor(x))); }
    case DV_NUMERIC:
      {
        numeric_t res;
        numeric_t x = (numeric_t)arg;
        int tenths;
        if (0 == x->n_scale)
          return box_copy (arg);
        tenths = x->n_value[(int)(x->n_len)];
        if (x->n_neg ?
          ((tenths > 5) || ((5 == tenths) && (1 < x->n_scale))) :
          (tenths >= 5) )
          {
            numeric_t temp;
            numeric_t shifted;
            /* construct +-0.5 */
            NUMERIC_VAR (temp_buf);
            NUMERIC_INIT (temp_buf);
            temp = (numeric_t)temp_buf;
            temp->n_value[0] = 5;
            temp->n_scale = 1;
            temp->n_neg = x->n_neg;
            shifted = numeric_allocate ();
            num_add (shifted, x, temp, 0);
            res = numeric_allocate ();
            numeric_rescale_noround (res, shifted, shifted->n_len+1, 0);
            numeric_free (shifted);
            return (caddr_t)res;
          }
        res = numeric_allocate ();
        numeric_rescale_noround (res, x, x->n_len+1, 0);
        return (caddr_t)res;
      }
    case DV_DB_NULL: return NEW_DB_NULL;
    default:
      sqlr_new_error ("22023", "SL001", "The SPARQL 1.1 function round() needs a numeric value as an argument");
    return NULL;
    }
}

/**
 * 17.4.3.2 STRLEN
 * xsd:integer STRLEN(string literal str)
 * The strlen function corresponds to the XPath fn:string-length function and returns an xsd:integer equal to the length in characters of the lexical form of the literal.
 *
 */
caddr_t
bif_rdf_strlen_impl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg = bif_arg_unrdf (qst, args, 0, "rdf_strlen_impl");
  dtp_t dtp = DV_TYPE_OF (arg);
  switch (dtp)
    {
    case DV_STRING:
    case DV_UNAME:
      return (caddr_t)box_num ( wide_char_length_of_utf8_string ((const unsigned char *)arg, box_length(arg)) );
    case DV_WIDE:
      return (caddr_t)box_num( virt_wcslen ((wchar_t *)(arg)) );
    case DV_DB_NULL:
      return NEW_DB_NULL;
    default:
      sqlr_new_error ("22023", "SL001", "The SPARQL 1.1 function strlen() needs a string value as an argument");
    return NULL;
    }
}

/* this function take a string, not a box as 'source' argument */
caddr_t
t_box_utf8_string (ccaddr_t utf8src, size_t max_chars)
{
  const unsigned char *src = (const unsigned char *) utf8src;

  virt_mbstate_t state;
  size_t inx, max_bytes = 0;
  caddr_t box;
  memset (&state, 0, sizeof(virt_mbstate_t));
  for (inx=0; inx<max_chars && src[max_bytes]; ++inx)
    {
      max_bytes += virt_mbrlen ((const char *)(src + max_bytes), VIRT_MB_CUR_MAX, &state);
    }

  box = dk_alloc_box (max_bytes + 1, DV_STRING);

  strncpy (box, (const char *)(src), max_bytes);
  box[max_bytes] = 0;
  return box;
}

/*
17.4.3.3 SUBSTR
string literal  SUBSTR(string literal source, xsd:integer startingLoc)
string literal  SUBSTR(string literal source, xsd:integer startingLoc, xsd:integer length)
The substr function corresponds to the XPath fn:substring function and returns a literal of
the same kind (simple literal, literal with language tag, xsd:string typed literal) as
the source input parameter but with a lexical form formed from the substring of
the lexcial form of the source.
The arguments startingLoc and length may be derived types of xsd:integer.
The index of the first character in a strings is 1.
*/
caddr_t
bif_rdf_substr_impl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char b[128] = "";
  rdf_box_t *src_rdf_box;
  caddr_t src = bif_arg_unrdf_ext (qst, args, 0, "rdf_substr_impl", (caddr_t *)(&src_rdf_box));
  char src_is_rdf_box = DV_TYPE_OF (src_rdf_box) == DV_RDF;
  boxint startl = bif_long_arg(qst, args, 1, "rdf_substr_impl");
  unsigned start = (unsigned) startl - 1;
  boxint lenl;
  unsigned len = UINT_MAX;
  size_t str_n_chars;
  box_t r;
  if (BOX_ELEMENTS (args) >= 3)
    {
      lenl = bif_long_arg (qst, args, 2, "rdf_substr_impl");
      len = (unsigned) lenl;
    }

  switch (DV_TYPE_OF (src))
    {
    case DV_STRING: /* utf-8 */
    case DV_UNAME:
      {
        virt_mbstate_t mbstate;
        const char *pstart = src;
        size_t i;
        memset (&mbstate, 0, sizeof(virt_mbstate_t));
        for (i=0; i<start && *pstart; ++i)
          {
            pstart += virt_mbrlen (pstart, VIRT_MB_CUR_MAX, &mbstate);
          }
        str_n_chars = wide_char_length_of_utf8_string ((const unsigned char *)pstart, strlen(pstart));

        if (startl < 1 || !str_n_chars ||
            (BOX_ELEMENTS (args) >= 3 && (lenl < 1 || lenl > str_n_chars)) )
          goto bad_subrange;

        if (len > str_n_chars)
          len = str_n_chars;
        r = t_box_utf8_string (pstart, len);
      }
      break;
    case DV_WIDE:
    case DV_LONG_WIDE:
      {
	const wchar_t *pstart;
	size_t strlength;
        str_n_chars = virt_wcslen ((const wchar_t *)src);

        if (startl < 1 || startl > str_n_chars ||
            (BOX_ELEMENTS (args) >= 3 && (lenl < 1 || lenl > str_n_chars - start + 1)) )
          goto bad_subrange;

        pstart = (const wchar_t *)src + start;
        strlength = virt_wcslen(pstart);
        if (len > strlength)
          len = strlength;
        r = box_wide_as_utf8_char ((ccaddr_t)pstart, len, DV_STRING);
      }
      break;
    case DV_DB_NULL:
      return NEW_DB_NULL;
    default:
      sqlr_new_error ("22023", "SL001", "The SPARQL 1.1 function substr() needs a string value as 1st argument");
    return NULL;
    }
  box_flags(r) |= BF_UTF8;
  if (src_is_rdf_box)
    {
      rdf_box_t *r_rdf_box = rb_allocate();
      r_rdf_box->rb_is_complete = 1;
      r_rdf_box->rb_type = src_rdf_box->rb_type;
      r_rdf_box->rb_lang = src_rdf_box->rb_lang;
      r_rdf_box->rb_box = r;
      return (caddr_t)r_rdf_box;
    }
  else
    return (caddr_t)r;

bad_subrange:
  if (BOX_ELEMENTS (args) >= 3)
    snprintf (b, 128, ", len=%ld", (long)lenl);
  sqlr_new_error ("22011", "SR026",
      "SPARQL substr: Bad string subrange: from=%ld%s.", (long)startl, b);
  return NEW_DB_NULL;
}

/*
17.4.3.4 UCASE
string literal  UCASE(string literal str)
The UCASE function corresponds to the XPath fn:upper-case function. It returns a string literal whose lexical form is the upper case of the lexcial form of the argument.
17.4.3.5 LCASE
string literal  LCASE(string literal str)
The LCASE function corresponds to the XPath fn:lower-case function. It returns a string literal whose lexical form is the lower case of the lexcial form of the argument.
*/
caddr_t
bif_rdf_ucase_lcase_impl(caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, char upcase /* == 1 - upcase, ==0 - lcase */)
{
  rdf_box_t *str_rdf_box;
  caddr_t str = bif_arg_unrdf_ext (qst, args, 0, upcase ? "rdf_ucase_impl" : "rdf_lcase_impl", (caddr_t *)(&str_rdf_box));
  char src_is_rdf_box = DV_TYPE_OF (str_rdf_box) == DV_RDF;
  size_t i, str_n_chars;
  wchar_t *wide_box = NULL;
  box_t r;
  unichar (*unicode3_get_x_case) (unichar);
  switch (DV_TYPE_OF (str))
    {
    case DV_STRING: /* utf-8 */
    case DV_UNAME:
      {
        wide_box =  (wchar_t*) box_utf8_as_wide_char (str, NULL, strlen(str), 0, DV_WIDE);
        str_n_chars= virt_wcslen (wide_box);
      }
      break;
    case DV_WIDE:
    case DV_LONG_WIDE:
      {
        wide_box =  (wchar_t*)box_wide_string ((const wchar_t*)str);
        str_n_chars = virt_wcslen ( (const wchar_t*)str);
      }
      break;
    case DV_DB_NULL:
      return NEW_DB_NULL;
    default:
      sqlr_new_error ("22023", "SL001", "The SPARQL 1.1 function %scase() needs a string value as 1st argument",
          upcase ? "u" : "l" );
    return NULL;
    }

  unicode3_get_x_case = upcase ? unicode3_getucase : unicode3_getlcase;
  for (i=0; i<str_n_chars; ++i)
    {
      wide_box[i] = unicode3_get_x_case (wide_box[i]);
    }
  r = box_wide_as_utf8_char ((ccaddr_t)wide_box, str_n_chars, DV_STRING);
  dk_free_box ((caddr_t)wide_box);

  box_flags(r) |= BF_UTF8;
  if (src_is_rdf_box)
    {
      rdf_box_t *r_rdf_box = rb_allocate();
      r_rdf_box->rb_is_complete = 1;
      r_rdf_box->rb_type = str_rdf_box->rb_type;
      r_rdf_box->rb_lang = str_rdf_box->rb_lang;
      r_rdf_box->rb_box = r;
      return (caddr_t)r_rdf_box;
    }
  else
    return (caddr_t)r;
}

caddr_t
bif_rdf_ucase_impl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_rdf_ucase_lcase_impl (qst, err_ret, args, 1);
}

caddr_t
bif_rdf_lcase_impl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_rdf_ucase_lcase_impl (qst, err_ret, args, 0);
}

/*
17.4.3.6 STRSTARTS

xsd:boolean  STRSTARTS(string literal arg1, string literal arg2)

The STRSTARTS function corresponds to the XPath fn:starts-with function. The arguments must be argument compatible otherwise an error is raised.
For such input pairs, the function returns true if the lexical form of arg1 starts with the lexical form of arg2, otherwise it returns false.

17.4.3.7 STRENDS

xsd:boolean  STRENDS(string literal arg1, string literal arg2)

The STRENDS function corresponds to the XPath fn:starts-with function. The arguments must be argument compatible otherwise an error is raised.
For such input pairs, the function returns true if the lexical form of arg1 ends with the lexical form of arg2, otherwise it returns false.

17.4.3.8 CONTAINS

xsd:boolean  CONTAINS(string literal arg1, string literal arg2)

The CONTAINS function corresponds to the XPath fn:contains. The arguments must be argument compatible otherwise an error is raised.
*/

#define STRCONTAINS_AT_START	0x00
#define STRCONTAINS_INSIDE	0x01
#define STRCONTAINS_AT_END	0x02
#define STRCONTAINS_RET_BOOL	0x10
#define STRCONTAINS_RET_AFTER	0x20
#define STRCONTAINS_RET_BEFORE	0x30

caddr_t
bif_rdf_strcontains_x_impl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, const char *fnname, const char *sparql_fnname, int op_flags)
{
  ccaddr_t str = bif_arg_unrdf (qst, args, 0, fnname);
  ccaddr_t pattern = bif_arg_unrdf (qst, args, 1, fnname);
  /*ccaddr_t str_end, pattern_position;*/
  size_t str_len, size_of_str_char, /*str_n_chars, pattern_n_chars,*/ pattern_len;
  int op_flags_place = op_flags & 0x0F;
  int op_flags_ret = op_flags & 0xF0;
  int found = 0;
  size_t hit_pos = 0;
  caddr_t res;
  switch (DV_TYPE_OF (pattern))
    {
      case DV_STRING: 
      case DV_UNAME:
      case DV_WIDE:
      case DV_LONG_WIDE:
	  break;
      default:
	  sqlr_new_error ("22023", "SL001", "The SPARQL 1.1 function %s() needs a string value as 2d argument", sparql_fnname);
	  return NULL;
    }
  switch (DV_TYPE_OF (str))
    {
    case DV_STRING: /* utf-8 */
    case DV_UNAME:
      {
        /*virt_mbstate_t mbstate;*/
        str_len = box_length (str) - 1;
        pattern_len = box_length (pattern) - 1;
        size_of_str_char = 1;
/*        memset (&mbstate, 0, sizeof(virt_mbstate_t));
        str_n_chars = wide_char_length_of_utf8_string ((const unsigned char*)str, box_length (str) - 1);
        memset (&mbstate, 0, sizeof(virt_mbstate_t));
        pattern_n_chars = wide_char_length_of_utf8_string ((const unsigned char*)pattern, box_length (pattern) - 1);*/
        if (pattern_len && pattern_len <= str_len)
          {
            switch (op_flags_place)
              {
              case STRCONTAINS_AT_START:
                found = !memcmp ((const char*)str, (const char*)pattern, pattern_len);
                break;
              case STRCONTAINS_INSIDE:
                {
                  const char *c = (const char *)memmem (str, str_len, pattern, pattern_len);
                  if (NULL != c) { found = 1; hit_pos = (c - str); }
                  break;
                }
              case STRCONTAINS_AT_END:
                found = !memcmp ((const char*)str + str_len - pattern_len, (const char*)pattern, pattern_len);
                if (found)
                  hit_pos = str_len - pattern_len;
                break;
              }
          }
      }
      break;
    case DV_WIDE: /* utf-32 */
    case DV_LONG_WIDE:
      {
        str_len = box_length (str) - sizeof (wchar_t);
        pattern_len = box_length (pattern) - sizeof (wchar_t);
        size_of_str_char = sizeof (wchar_t);
        /*str_n_chars = virt_wcslen ((const wchar_t*)str);
        pattern_n_chars = virt_wcslen ((const wchar_t*)pattern);
        str_end = (ccaddr_t)(((const wchar_t*)str) + str_n_chars - pattern_n_chars);
        ok_position = op_flags_place == STRCONTAINS_AT_START ? str : str_end;*/
        if (pattern_len && pattern_len <= str_len)
          {
            switch (op_flags_place)
              {
              case STRCONTAINS_AT_START:
                found = !memcmp ((const char*)str, (const char*)pattern, pattern_len);
                break;
              case STRCONTAINS_INSIDE:
                {
                  const char *c = (ccaddr_t) virt_wcsstr ((const wchar_t*)str, (const wchar_t*)pattern);
                  if (NULL != c) { found = 1; hit_pos = (c - str); }
                  break;
                }
              case STRCONTAINS_AT_END:
                found = !memcmp ((const char*)str + str_len - pattern_len, (const char*)pattern, pattern_len);
                if (found)
                  hit_pos = str_len - pattern_len;
                break;
              }
          }
      }
      break;
    case DV_DB_NULL:
      return NEW_DB_NULL;
    default:
      sqlr_new_error ("22023", "SL001", "The SPARQL 1.1 function %s() needs a string value as 1st argument", sparql_fnname);
    return NULL;
    }
  switch (op_flags_ret)
    {
    case STRCONTAINS_RET_BOOL:
      res = (caddr_t)box_bool(found);
      break;
    case STRCONTAINS_RET_AFTER:
      if (!found)
        return box_dv_short_string ("");
      res = dk_alloc_box (str_len + size_of_str_char - (hit_pos + pattern_len), box_tag (str));
      memcpy (res, str + hit_pos + pattern_len, str_len + size_of_str_char - (hit_pos + pattern_len));
      break;
    case STRCONTAINS_RET_BEFORE:
      if (!found)
        return box_dv_short_string ("");
      res = dk_alloc_box (hit_pos + size_of_str_char, box_tag (str));
      memcpy (res, str, hit_pos + size_of_str_char);
      break;
    }
  return res;
}

caddr_t
bif_rdf_strstarts_impl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_rdf_strcontains_x_impl (qst, err_ret, args, "rdf_strstarts_impl", "STRSTARTS", STRCONTAINS_AT_START | STRCONTAINS_RET_BOOL);
}

caddr_t
bif_rdf_strends_impl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_rdf_strcontains_x_impl (qst, err_ret, args, "rdf_strends_impl", "STRENDS", STRCONTAINS_AT_END | STRCONTAINS_RET_BOOL);
}

caddr_t
bif_rdf_contains_impl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_rdf_strcontains_x_impl (qst, err_ret, args, "rdf_contains_impl", "CONTAINS", STRCONTAINS_INSIDE | STRCONTAINS_RET_BOOL);
}

caddr_t
bif_rdf_strafter_impl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_rdf_strcontains_x_impl (qst, err_ret, args, "rdf_strafter_impl", "STRAFTER", STRCONTAINS_INSIDE | STRCONTAINS_RET_AFTER);
}

caddr_t
bif_rdf_strbefore_impl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_rdf_strcontains_x_impl (qst, err_ret, args, "rdf_strbefore_impl", "STRBEFORE", STRCONTAINS_INSIDE | STRCONTAINS_RET_BEFORE);
}

/*
17.4.3.11 ENCODE_FOR_IRI

A clone of XPath fn:encode-for-uri.
*/
caddr_t
bif_rdf_encode_for_uri_impl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  dk_session_t *ses;
  caddr_t str = bif_string_or_uname_or_wide_or_null_arg (qst, args, 0, "rdf_encode_for_uri");
  if (NULL == str)
    return NEW_DB_NULL;
  switch (DV_TYPE_OF (str))
    {
    case DV_STRING: /* utf-8 */
    case DV_UNAME:
      {
        ses = strses_allocate ();
        dks_esc_write (ses, str, box_length (str) - 1, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_URI);
      }
      break;
    case DV_WIDE:
    case DV_LONG_WIDE:
      {
        ses = strses_allocate ();
        dks_esc_write (ses, str, box_length (str) - 1, CHARSET_UTF8, CHARSET_WIDE, DKS_ESC_URI);
      }
      break;
    default:
#ifndef NDEBUG
      GPF_T;
#endif
      return NULL;
    }
  if (STRSES_CAN_BE_STRING ((dk_session_t *) ses))
    {
      caddr_t res_strg = strses_string (ses);
      dk_free_box ((caddr_t)ses);
      box_flags(res_strg) |= BF_UTF8;
      return res_strg;
    }
  strses_free (ses);
  sqlr_resignal (STRSES_LENGTH_ERROR ("rdf_encode_for_uri"));
  return NULL;
}

/*
17.4.3.11 CONCAT

*/
caddr_t
bif_rdf_concat_impl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t res_strg = bif_concatenate (qst, err_ret, args);
  int n_args = BOX_ELEMENTS (args), inx;
  unsigned short common_type_twobytes = 0;
  unsigned short common_lang_twobytes = 0;
  for (inx = 0; inx < n_args; inx++)
    {
      rdf_box_t *arg = (rdf_box_t *)bif_arg_nochecks (qst, args, inx);
      if (DV_RDF != DV_TYPE_OF (arg))
        {
          common_lang_twobytes = RDF_BOX_ILL_LANG;
          common_type_twobytes = RDF_BOX_ILL_LANG;
          continue;
        }
      if (RDF_BOX_DEFAULT_LANG != arg->rb_lang)
        {
          if (0 == common_lang_twobytes)
            common_lang_twobytes = arg->rb_lang;
          else if (common_lang_twobytes != arg->rb_lang)
            common_lang_twobytes = RDF_BOX_ILL_LANG;
        }
      else if (RDF_BOX_DEFAULT_TYPE != arg->rb_type)
        {
          if (0 == common_type_twobytes)
            common_type_twobytes = arg->rb_type;
          else if (common_type_twobytes != arg->rb_type)
            common_type_twobytes = RDF_BOX_ILL_TYPE;
        }
    }
  if ((0 != common_type_twobytes) && (RDF_BOX_ILL_TYPE != common_type_twobytes))
    {
static unsigned short xsd_string_twobytes = 0;
      if (0 == xsd_string_twobytes)
        xsd_string_twobytes = nic_name_id (rdf_type_cache, uname_xmlschema_ns_uri_hash_string);
      if (common_type_twobytes == xsd_string_twobytes)
        {
          rdf_box_t *rb_res = rb_allocate ();
          rb_res->rb_box = res_strg;
          rb_res->rb_is_complete = 1;
          rb_res->rb_type = xsd_string_twobytes;
          rb_res->rb_lang = RDF_BOX_DEFAULT_LANG;
          return (caddr_t)rb_res;
        }
    }
  if ((0 != common_lang_twobytes) && (RDF_BOX_ILL_LANG != common_lang_twobytes))
    {
      rdf_box_t *rb_res = rb_allocate ();
      rb_res->rb_box = res_strg;
      rb_res->rb_is_complete = 1;
      rb_res->rb_type = RDF_BOX_DEFAULT_TYPE;
      rb_res->rb_lang = common_lang_twobytes;
      return (caddr_t)rb_res;
    }
  return res_strg;
}

caddr_t
bif_rdf_seconds_impl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t dt = bif_date_arg (qst, args, 0, "rdf_seconds_impl");
  TIMESTAMP_STRUCT ts;
  dt_to_timestamp_struct (dt, &ts);
  return box_double (ts.second + ts.fraction / 1000000000.0);
}

caddr_t
bif_rdf_checksum_int (caddr_t * qst, state_slot_t ** args, int op, const char *fname)
{
  caddr_t arg = bif_arg_unrdf (qst, args, 0, fname);
  caddr_t arg_strg = NULL;
  caddr_t res = NULL;
  int ctr, res_len;
  dtp_t arg_dtp = DV_TYPE_OF (arg);
  if ((DV_STRING != arg_dtp) || (DV_UNAME != arg_dtp))
    arg_strg = box_cast_to_UTF8 (qst, arg);
  else
    arg_strg = arg;
  switch (op)
    {
    case SPAR_BIF_MD5:
      {
        MD5_CTX ctx;
        memset (&ctx, 0, sizeof (MD5_CTX));
        MD5Init (&ctx);
        MD5Update (&ctx, arg_strg, box_length (arg_strg)-1);
        res_len = MD5_SIZE;
        res = dk_alloc_box (res_len*2 + 1, DV_SHORT_STRING);
        MD5Final ((unsigned char *) res, &ctx);
        break;
      }
#if !defined(OPENSSL_NO_SHA1) && defined (SHA_DIGEST_LENGTH)
    case SPAR_BIF_SHA1:
      {
        SHA_CTX ctx;
        memset (&ctx, 0, sizeof (SHA_CTX));
        SHA1_Init (&ctx);
        SHA1_Update (&ctx, arg_strg, box_length (arg_strg)-1);
        res_len = SHA_DIGEST_LENGTH;
        res = dk_alloc_box (res_len*2 + 1, DV_SHORT_STRING);
        SHA1_Final ((unsigned char *) res, &ctx);
        break;
      }
#endif
#if !defined( OPENSSL_NO_SHA256) && defined (SHA256_DIGEST_LENGTH)
    case SPAR_BIF_SHA224:
      {
        SHA256_CTX ctx;
        memset (&ctx, 0, sizeof (SHA256_CTX));
        SHA224_Init (&ctx);
        SHA224_Update (&ctx, arg_strg, box_length (arg_strg)-1);
        res_len = SHA224_DIGEST_LENGTH;
        res = dk_alloc_box (res_len*2 + 1, DV_SHORT_STRING);
        SHA224_Final ((unsigned char *) res, &ctx);
        break;
      }
    case SPAR_BIF_SHA256:
      {
        SHA256_CTX ctx;
        memset (&ctx, 0, sizeof (SHA256_CTX));
        SHA256_Init (&ctx);
        SHA256_Update (&ctx, arg_strg, box_length (arg_strg)-1);
        res_len = SHA256_DIGEST_LENGTH;
        res = dk_alloc_box (res_len*2 + 1, DV_SHORT_STRING);
        SHA256_Final ((unsigned char *) res, &ctx);
        break;
      }
#endif
#if !defined(OPENSSL_NO_SHA512) && defined (SHA512_DIGEST_LENGTH)
    case SPAR_BIF_SHA384:
      {
        SHA512_CTX ctx;
        memset (&ctx, 0, sizeof (SHA512_CTX));
        SHA384_Init (&ctx);
        SHA384_Update (&ctx, arg_strg, box_length (arg_strg)-1);
        res_len = SHA384_DIGEST_LENGTH;
        res = dk_alloc_box (res_len*2 + 1, DV_SHORT_STRING);
        SHA384_Final ((unsigned char *) res, &ctx);
        break;
      }
    case SPAR_BIF_SHA512:
      {
        SHA512_CTX ctx;
        memset (&ctx, 0, sizeof (SHA512_CTX));
        SHA512_Init (&ctx);
        SHA512_Update (&ctx, arg_strg, box_length (arg_strg)-1);
        res_len = SHA512_DIGEST_LENGTH;
        res = dk_alloc_box (res_len*2 + 1, DV_SHORT_STRING);
        SHA512_Final ((unsigned char *) res, &ctx);
        break;
      }
#endif
    default:
      sqlr_new_error ("42001", "SR646", "The function %.100s() is not supported in the OpenSSL library used in this Virtuoso build", fname);
    }
  res[res_len * 2] = '\0';
  for (ctr = res_len; ctr--; /* no step */)
    {
      unsigned char c = res[ctr];
      res[ctr * 2 + 1] = "0123456789abcdef"[c & 0xf];
      res[ctr * 2] = "0123456789abcdef"[c >> 4];
    }
  if (arg_strg != arg)
    dk_free_box (arg_strg);
  return res;
}

caddr_t
bif_rdf_MD5_impl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{ return bif_rdf_checksum_int (qst, args, SPAR_BIF_MD5, "rdf_md5_impl"); }

caddr_t
bif_rdf_SHA1_impl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{ return bif_rdf_checksum_int (qst, args, SPAR_BIF_SHA1, "rdf_sha1_impl"); }

caddr_t
bif_rdf_SHA224_impl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{ return bif_rdf_checksum_int (qst, args, SPAR_BIF_SHA224, "rdf_sha224_impl"); }

caddr_t
bif_rdf_SHA256_impl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{ return bif_rdf_checksum_int (qst, args, SPAR_BIF_SHA256, "rdf_sha256_impl"); }

caddr_t
bif_rdf_SHA384_impl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{ return bif_rdf_checksum_int (qst, args, SPAR_BIF_SHA384, "rdf_sha384_impl"); }

caddr_t
bif_rdf_SHA512_impl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{ return bif_rdf_checksum_int (qst, args, SPAR_BIF_SHA512, "rdf_sha512_impl"); }

void
bif_sparql_init (void)
{
  bif_define ("rdf_abs_impl", bif_abs);
  bif_define ("rdf_ceil_impl", bif_rdf_ceil_impl);
  bif_define ("rdf_floor_impl", bif_rdf_floor_impl);
  bif_define_typed ("rdf_rand_impl", bif_rdf_rand_impl, &bt_double);
  bif_define ("rdf_round_impl", bif_rdf_round_impl);
  bif_define_typed ("rdf_strlen_impl", bif_rdf_strlen_impl, &bt_integer);
  bif_define_typed ("rdf_substr_impl", bif_rdf_substr_impl, &bt_string);
  bif_define_typed ("rdf_ucase_impl", bif_rdf_ucase_impl, &bt_string);
  bif_define_typed ("rdf_lcase_impl", bif_rdf_lcase_impl, &bt_string);
  bif_define_ex ("rdf_strafter_impl"	, bif_rdf_strafter_impl	, BMD_RET_TYPE, &bt_any		, BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 2	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("rdf_strbefore_impl"	, bif_rdf_strbefore_impl, BMD_RET_TYPE, &bt_any		, BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 2	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("rdf_strstarts_impl"	, bif_rdf_strstarts_impl, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 2	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("rdf_strends_impl"	, bif_rdf_strends_impl	, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 2	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("rdf_contains_impl"	, bif_rdf_contains_impl	, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 2	, BMD_IS_PURE, BMD_DONE);
  bif_define_typed ("rdf_encode_for_uri_impl", bif_rdf_encode_for_uri_impl, &bt_varchar);
  bif_define_typed ("rdf_concat_impl", bif_rdf_concat_impl, &bt_varchar);
  /* Functions rdf_now_impl() and rdf_year_impl() to rdf_minutes_impl() are in bif_date.c */
  bif_define_typed ("rdf_seconds_impl", bif_rdf_seconds_impl, &bt_double);
  bif_define_typed ("rdf_md5_impl", bif_rdf_MD5_impl, &bt_string);
  bif_define_typed ("rdf_sha1_impl", bif_rdf_SHA1_impl, &bt_string);
  bif_define_typed ("rdf_sha224_impl", bif_rdf_SHA224_impl, &bt_string);
  bif_define_typed ("rdf_sha256_impl", bif_rdf_SHA256_impl, &bt_string);
  bif_define_typed ("rdf_sha384_impl", bif_rdf_SHA384_impl, &bt_string);
  bif_define_typed ("rdf_sha512_impl", bif_rdf_SHA512_impl, &bt_string);
}

extern caddr_t bif_search_excerpt (caddr_t *qst, caddr_t * err_ret, state_slot_t ** args);
extern caddr_t bif_fct_level (caddr_t *qst, caddr_t * err_ret, state_slot_t ** args);
void bif_fct_level_vec (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, state_slot_t * ret);
caddr_t bif_sum_rank (caddr_t *qst, caddr_t * err_ret, state_slot_t ** args);
caddr_t bif_dpipe_define (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);


void
sql_bif_init (void)
{
  static int bifs_initialized = 0;
  if (bifs_initialized)
  return;
  else
  bifs_initialized = 1;
  dk_mem_hooks (DV_EXEC_CURSOR, box_non_copiable, type_lc_destroy, 0);

  ssl_constant_init ();
  bif_cursors_init();

  icc_locks_mutex = mutex_allocate();
  icc_locks = id_str_hash_create (31);
  dba_sequences = id_str_hash_create (11);
/* For debugging */
  bif_define_typed ("dbg_printf", bif_dbg_printf, &bt_varchar);
  bif_define ("dbg_obj_print", bif_dbg_obj_print);
  bif_define ("dbg_obj_princ", bif_dbg_obj_princ); bif_set_uses_index (bif_dbg_obj_princ);
  bif_define ("dbg_obj_prin1", bif_dbg_obj_princ);
  bif_define ("dbg_obj_print_vars", bif_dbg_obj_print_vars);
  bif_define ("dbg_user_dump", bif_dbg_user_dump);
  bif_define ("__cache_check", bif_cache_check);
  bif_define ("__autocompact", bif_autocompact);
  bif_define_typed ("__qi_is_branch", bif_qi_is_branch, &bt_integer);
#if 0
  /*partition_def_bif_define ();*/
  dpipe_define_1_bif_define ();
#endif
  bif_define ("dpipe_define", bif_dpipe_define);

#if 1
  bif_define ("xid_test", test_xid_encode_decode);
#endif


/* Functions for error & result handling in user created procedures: */
  bif_define ("signal", bif_signal);
  bif_define ("result", bif_result);
  bif_define ("result_names", bif_result_names);
  bif_define ("end_result", bif_end_result);

/* Time and Date related functions: */


/* These are all SQL-92 standard functions. */

/* String manipulation. */
  bif_define_typed ("length", bif_length, &bt_integer);
  bif_define_typed ("char_length", bif_length, &bt_integer);
  bif_define_typed ("character_length", bif_length, &bt_integer);
  bif_define_typed ("octet_length", bif_length, &bt_integer);

  bif_define_typed ("aref", bif_aref, &bt_any_box);
  bif_define_typed ("aref_or_default", bif_aref_or_default, &bt_any_box);
  bif_define_typed ("aref_set_0", bif_aref_set_0, &bt_any_box);
  bif_define_typed ("aset", bif_aset, &bt_integer);
  bif_define_typed ("aset_zap_arg", bif_aset_zap_arg, &bt_integer);
  bif_define ("aset_1_2_zap", bif_aset_1_2_zap);
  bif_define ("composite", bif_composite);
  bif_define ("composite_ref", bif_composite_ref);
  bif_define_typed ("ascii", bif_ascii, &bt_integer);
  bif_define_typed ("chr", bif_chr, &bt_varchar);
  bif_define_typed ("chr1", bif_chr1, &bt_varchar);

/* Substring extraction: */
  bif_define_ex ("subseq"		, bif_subseq		, BMD_RET_TYPE, &bt_string	, BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 3	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("substring"		, bif_substr		, BMD_RET_TYPE, &bt_string	, BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 3	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("left"			, bif_left		, BMD_RET_TYPE, &bt_string	, BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 2	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("right"		, bif_right		, BMD_RET_TYPE, &bt_string	, BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 2	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("ltrim"		, bif_ltrim		, BMD_RET_TYPE, &bt_string	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 2	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("rtrim"		, bif_rtrim		, BMD_RET_TYPE, &bt_string	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 2	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("trim"			, bif_trim		, BMD_RET_TYPE, &bt_string	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 2	, BMD_IS_PURE, BMD_DONE);

/* Producing new strings by repetition: */
  bif_define_ex ("repeat"		, bif_repeat		, BMD_RET_TYPE, &bt_string	, BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 2	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("space"		, bif_space		, BMD_RET_TYPE, &bt_varchar	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("make_string"		, bif_make_string	, BMD_RET_TYPE, &bt_varchar	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("make_wstring"		, bif_make_wstring	, BMD_RET_TYPE, &bt_wvarchar	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("make_bin_string"	, bif_make_bin_string	, BMD_RET_TYPE, &bt_varbinary	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("concatenate"		, bif_concatenate	, BMD_RET_TYPE, &bt_string	, BMD_MIN_ARGCOUNT, 0				, BMD_IS_PURE, BMD_DONE);  /* Synonym for old times */
  bif_define_ex ("concat"		, bif_concatenate	, BMD_RET_TYPE, &bt_string	, BMD_MIN_ARGCOUNT, 0				, BMD_IS_PURE, BMD_DONE); /* This is more to standard */
  bif_define_ex ("replace"		, bif_replace		, BMD_RET_TYPE, &bt_string	, BMD_MIN_ARGCOUNT, 3, BMD_MAX_ARGCOUNT, 4	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("sprintf"		, bif_sprintf		, BMD_RET_TYPE, &bt_varchar	, BMD_MIN_ARGCOUNT, 1				, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("sprintf_or_null"	, bif_sprintf_or_null	, BMD_RET_TYPE, &bt_varchar	, BMD_MIN_ARGCOUNT, 1				, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("sprintf_iri"		, bif_sprintf_iri	, BMD_RET_TYPE, &bt_varchar	, BMD_MIN_ARGCOUNT, 1				, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("sprintf_iri_or_null"	, bif_sprintf_iri_or_null, BMD_RET_TYPE, &bt_varchar	, BMD_MIN_ARGCOUNT, 1				, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("sprintf_inverse"	, bif_sprintf_inverse					, BMD_MIN_ARGCOUNT, 3, BMD_MAX_ARGCOUNT, 3	, BMD_IS_PURE, BMD_DONE);

/* Finding occurrences of characters and substrings in strings: */
  bif_define_ex ("strchr"		, bif_strchr		, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 2	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("strrchr"		, bif_strrchr		, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 2	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("strstr"		, bif_strstr		, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 2	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("strcontains"		, bif_strcontains	, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 2	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("starts_with"		, bif_starts_with	, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 2	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("ends_with"		, bif_ends_with		, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 2	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("strindex"		, bif_strstr		, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 2	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("strcasestr"		, bif_nc_strstr		, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 2	, BMD_IS_PURE, BMD_DONE);  /* Name was nc_strstr */
  bif_define_ex ("locate"		, bif_locate		, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 3	, BMD_IS_PURE, BMD_DONE);   /* Standard SQL function. */
  bif_define_ex ("matches_like"		, bif_matches_like	, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 3	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("__like_min"		, bif_like_min		, BMD_RET_TYPE, &bt_string	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 2	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("__like_max"		, bif_like_max		, BMD_RET_TYPE, &bt_string	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 2	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("__rdf_rng_min"	, bif_rdf_rng_min	, BMD_RET_TYPE, &bt_string	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("fix_identifier_case"	, bif_fix_identifier_case, BMD_RET_TYPE, &bt_varchar	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("casemode_strcmp"	, bif_casemode_strcmp	, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 2	, BMD_IS_PURE, BMD_DONE);

/* Conversion between cases: */
  bif_define_ex ("lcase"		, bif_lcase		, BMD_RET_TYPE, &bt_string	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("lower"		, bif_lcase		, BMD_RET_TYPE, &bt_string	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE); /* Synonym to lcase */
  bif_define_ex ("ucase"		, bif_ucase		, BMD_RET_TYPE, &bt_string	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("upper"		, bif_ucase		, BMD_RET_TYPE, &bt_string	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE); /* Synonym to ucase */
  bif_define_ex ("initcap"		, bif_initcap		, BMD_RET_TYPE, &bt_varchar	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE); /* Name is taken from Oracle */
  bif_define_ex ("split_and_decode"	, bif_split_and_decode	, BMD_RET_TYPE, &bt_any_box		, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 3	, BMD_IS_PURE, BMD_DONE);   /* Does it all! */

/* Type testing functions. */
  bif_define_ex ("__tag"		, bif_tag		, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);   /* for sqlext.c */
  bif_define_ex ("__box_flags"		, bif_box_flags		, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("__box_flags_set"	, bif_box_flags_set					, BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 2			, BMD_DONE);
  bif_define_ex ("__box_flags_tweak"	, bif_box_flags_tweak					, BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 2	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("dv_to_sql_type"	, bif_dv_to_sql_type	, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);   /* for sqlext.c */
  bif_define_ex ("dv_to_sql_type3"	, bif_dv_to_sql_type3	, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);   /* for sqlext.c */
  bif_define_ex ("internal_to_sql_type"	, bif_dv_to_sql_type	, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("dv_type_title"	, bif_dv_type_title	, BMD_RET_TYPE, &bt_varchar	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE); /* needed by sqlext.c */
  bif_define_ex ("dv_buffer_length"	, bif_dv_buffer_length	, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE); /* needed by sqlext.c */
  bif_define_ex ("table_type"		, bif_table_type	, BMD_RET_TYPE, &bt_varchar	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1			, BMD_DONE);
  bif_define_ex ("internal_type_name"	, bif_dv_type_title	, BMD_RET_TYPE, &bt_varchar	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);  /* Alias for prev */
  bif_define_ex ("internal_type"	, bif_internal_type	, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("isinteger"		, bif_isinteger		, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("isnumeric"		, bif_isnumeric		, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("isfinitenumeric"	, bif_isfinitenumeric	, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("isfloat"		, bif_isfloat		, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("isdouble"		, bif_isdouble		, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("isnull"		, bif_isnull		, BMD_RET_TYPE, &bt_integer_nn	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("isnotnull"		, bif_isnotnull		, BMD_VECTOR_IMPL, bif_isnotnull_vec, BMD_RET_TYPE, &bt_integer_nn	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("isblob"		, bif_isblob_handle	, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("isentity"		, bif_isentity		, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("isstring"		, bif_isstring		, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("isstring_session"	, bif_isstring_session	, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("isbinary"		, bif_isbinary		, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("isarray"		, bif_isarray		, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("isvector"		, bif_isvector		, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("isiri_id"		, bif_isiri_id		, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("is_named_iri_id"	, bif_is_named_iri_id	, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("is_bnode_iri_id"	, bif_is_bnode_iri_id	, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("isuname"		, bif_isuname		, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);

  bif_define_ex ("iri_id_num"		, bif_iri_id_num	, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("iri_id_from_num"	, bif_iri_id_from_num	, BMD_RET_TYPE, &bt_iri		, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define ("__set_64bit_min_bnode_iri_id"	, bif_set_64bit_min_bnode_iri_id);
  bif_define_ex ("min_bnode_iri_id"	, bif_min_bnode_iri_id	, BMD_RET_TYPE, &bt_iri	, BMD_MIN_ARGCOUNT, 0, BMD_MAX_ARGCOUNT, 0	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("max_bnode_iri_id"	, bif_max_bnode_iri_id	, BMD_RET_TYPE, &bt_iri	, BMD_MIN_ARGCOUNT, 0, BMD_MAX_ARGCOUNT, 0	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("min_named_bnode_iri_id"	, bif_min_named_bnode_iri_id		, BMD_RET_TYPE, &bt_iri	, BMD_MIN_ARGCOUNT, 0, BMD_MAX_ARGCOUNT, 0	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("min_32bit_bnode_iri_id"	, bif_min_32bit_bnode_iri_id		, BMD_RET_TYPE, &bt_iri	, BMD_MIN_ARGCOUNT, 0, BMD_MAX_ARGCOUNT, 0	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("min_32bit_named_bnode_iri_id"	, bif_min_32bit_named_bnode_iri_id	, BMD_RET_TYPE, &bt_iri	, BMD_MIN_ARGCOUNT, 0, BMD_MAX_ARGCOUNT, 0	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("min_64bit_bnode_iri_id"	, bif_min_64bit_bnode_iri_id		, BMD_RET_TYPE, &bt_iri	, BMD_MIN_ARGCOUNT, 0, BMD_MAX_ARGCOUNT, 0	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("min_64bit_named_bnode_iri_id"	, bif_min_64bit_named_bnode_iri_id	, BMD_RET_TYPE, &bt_iri	, BMD_MIN_ARGCOUNT, 0, BMD_MAX_ARGCOUNT, 0	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("iri_id_bnode32_to_bnode64"	, bif_iri_id_bnode32_to_bnode64		, BMD_RET_TYPE, &bt_iri	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);

  bif_define_ex ("__all_eq"		, bif_all_eq		, BMD_RET_TYPE, &bt_any_box		, BMD_MIN_ARGCOUNT, 0				, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("__max"		, bif_max		, BMD_RET_TYPE, &bt_any_box		, BMD_MIN_ARGCOUNT, 0				, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("__min"		, bif_min		, BMD_RET_TYPE, &bt_any_box		, BMD_MIN_ARGCOUNT, 0				, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("__max_notnull"	, bif_max_notnull	, BMD_RET_TYPE, &bt_any_box		, BMD_MIN_ARGCOUNT, 0				, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("__min_notnull"	, bif_min_notnull	, BMD_RET_TYPE, &bt_any_box		, BMD_MIN_ARGCOUNT, 0				, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("either"		, bif_either		, BMD_RET_TYPE, &bt_any_box		, BMD_MIN_ARGCOUNT, 3, BMD_MAX_ARGCOUNT, 3	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("ifnull"		, bif_ifnull		, BMD_RET_TYPE, &bt_any		, BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 2	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("__and"		, bif_and		, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 0				, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("__or"			, bif_or		, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 0				, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("__transparent_or"	, bif_transparent_or	, BMD_RET_TYPE, &bt_any		, BMD_MIN_ARGCOUNT, 0				, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("__not"		, bif_not		, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);

/* Comparison functions */
  bif_define_ex ("lt"			, bif_lt	, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 2	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("gte"			, bif_gte	, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 2	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("gt"			, bif_gt	, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 2	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("lte"			, bif_lte	, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 2	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("equ"			, bif_equ	, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 2	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("neq"			, bif_neq	, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 2	, BMD_IS_PURE, BMD_DONE);

/* Arithmetic functions. */
  bif_define_ex ("iszero"		, bif_iszero	, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("atod"			, bif_atod	, BMD_RET_TYPE, &bt_double	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("atof"			, bif_atof	, BMD_RET_TYPE, &bt_float	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("atoi"			, bif_atoi	, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("dtoi"			, bif_dtoi	, BMD_RET_TYPE, &bt_any_box	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("mod"			, bif_mod	, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 2	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("abs"			, bif_abs	, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("sign"			, bif_sign	, BMD_RET_TYPE, &bt_double	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("acos"			, bif_acos	, BMD_RET_TYPE, &bt_double	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("asin"			, bif_asin	, BMD_RET_TYPE, &bt_double	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("atan"			, bif_atan	, BMD_RET_TYPE, &bt_double	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("cos"			, bif_cos	, BMD_RET_TYPE, &bt_double	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("sin"			, bif_sin	, BMD_RET_TYPE, &bt_double	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("tan"			, bif_tan	, BMD_RET_TYPE, &bt_double	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("cot"			, bif_cot	, BMD_RET_TYPE, &bt_double	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("frexp"		, bif_frexp	, BMD_RET_TYPE, &bt_double	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("degrees"		, bif_degrees	, BMD_RET_TYPE, &bt_double	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("radians"		, bif_radians	, BMD_RET_TYPE, &bt_double	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("exp"			, bif_exp	, BMD_RET_TYPE, &bt_double	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("log"			, bif_log	, BMD_RET_TYPE, &bt_double	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("log10"		, bif_log10	, BMD_RET_TYPE, &bt_double	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("sqrt"			, bif_sqrt	, BMD_RET_TYPE, &bt_double	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("atan2"		, bif_atan2	, BMD_RET_TYPE, &bt_double	, BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 2	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("power"		, bif_power	, BMD_RET_TYPE, &bt_double	, BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 2	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("ceiling"		, bif_ceiling	, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("floor"		, bif_floor	, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("pi"			, bif_pi	, BMD_RET_TYPE, &bt_double	, BMD_MIN_ARGCOUNT, 0, BMD_MAX_ARGCOUNT, 0	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("round"		, bif_round	, BMD_RET_TYPE, &bt_double	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);

  bif_define_ex ("rnd"			, bif_rnd	, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 1				/*, BMD_IS_PURE*/, BMD_DONE);
  bif_define_ex ("rand"			, bif_rnd	, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 1				/*, BMD_IS_PURE*/, BMD_DONE); /* SQL 92 standard function */
  bif_define ("randomize", bif_randomize);
  bif_define_ex ("hash"			, bif_hash	, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("md5_box"		, bif_md5_box	, BMD_RET_TYPE, &bt_varchar	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("box_hash"		, bif_box_hash	, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
/* Bitwise: */
  bif_define_ex ("bit_and"		, bif_bit_and	, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 0				, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("bit_or"		, bif_bit_or	, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 0				, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("bit_xor"		, bif_bit_xor	, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 2	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("bit_not"		, bif_bit_not	, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1	, BMD_IS_PURE, BMD_DONE);
  bif_define_ex ("bit_shift"		, bif_bit_shift	, BMD_RET_TYPE, &bt_integer	, BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 2	, BMD_IS_PURE, BMD_DONE);

/* Miscellaneous: */
  bif_define_typed ("dbname", bif_dbname, &bt_varchar);   /* Standard system function ? */
  bif_define_typed ("get_user", bif_user, &bt_varchar);
  bif_set_no_cluster ("get_user");
  bif_define_typed ("pwd_magic_calc", bif_pwd_magic_calc, &bt_varchar);
  bif_define_typed ("username", bif_user, &bt_varchar);   /* Standard system function name ? */
  bif_define_typed ("disconnect_user", bif_disconnect, &bt_integer);
  bif_define_typed ("connection_id", bif_connection_id, &bt_varchar);
  bif_set_no_cluster ("connection_id");
  bif_define ("connection_set", bif_connection_set);
  bif_set_no_cluster ("connection_set");
  bif_define ("connection_get", bif_connection_get);
  bif_set_no_cluster ("connection_get");
  bif_define ("connection_vars_set", bif_connection_vars_set);
  bif_set_no_cluster ("connection_vars_set");
  bif_define ("connection_vars", bif_connection_vars);
  bif_set_no_cluster ("connection_vars");
  bif_define ("connection_is_dirty", bif_connection_is_dirty);
  bif_set_no_cluster ("connection_is_dirty");
  bif_define ("backup", bif_backup);
  bif_set_no_cluster ("backup");
  bif_define ("db_check", bif_check);
  bif_set_no_cluster ("db_check");
  bif_define ("cl_idn", bif_cl_idn);
  bif_set_no_cluster ("cl_idn");
  bif_define_typed ("cl_idni", bif_cl_idni, &bt_integer);
  bif_set_no_cluster ("cl_idni");
  bif_set_vectored (bif_cl_idni, bif_cl_idni_vec);
  bif_define ("idn", bif_idn);
  bif_define_typed ("idn_no_copy", bif_idn_no_copy, &bt_any_box);
  bif_set_vectored (bif_idn_no_copy, bif_idn_no_copy_vec);
  bif_define ("asg_v", bif_asg_v);
  bif_define_typed ("vector", bif_vector, &bt_any_box);
  bif_define_typed ("vector_zap_args", bif_vector_zap_args, &bt_any_box);
  bif_define_typed ("get_keyword", bif_get_keyword, &bt_any_box);
  bif_define_typed ("get_keyword_ucase", bif_get_keyword_ucase, &bt_any_box);
  bif_define_typed ("set_by_keywords", bif_set_by_keywords, &bt_integer);
  bif_define_typed ("tweak_by_keywords", bif_tweak_by_keywords, &bt_any_box);
  bif_define_typed ("position", bif_position, &bt_integer);
  bif_define_typed ("one_of_these", bif_one_of_these, &bt_integer);
#if 0
  bif_define_typed ("row_table", bif_row_table, &bt_varchar);
  bif_define_typed ("row_column", bif_row_column, &bt_any);
  bif_define ("row_identity", bif_row_identity);
  bif_define ("row_deref", bif_row_deref);
#endif

#ifndef NDEBUG
  bif_define_typed ("dbg_row_deref_page", bif_dbg_row_deref_page, &bt_integer);
  bif_define_typed ("dbg_row_deref_pos", bif_dbg_row_deref_pos, &bt_integer);
#endif
  bif_define ("page_dump", bif_page_dump);
  bif_define_typed ("lisp_read", bif_lisp_read, &bt_any_box);

  bif_define_typed ("make_array", bif_make_array, &bt_any_box);
  bif_define_typed ("lvector", bif_lvector, &bt_any_box);
  bif_define_typed ("fvector", bif_fvector, &bt_any_box);
  bif_define_typed ("dvector", bif_dvector, &bt_any_box);
  bif_define ("raw_exit", bif_raw_exit);
  bif_define_typed ("blob_to_string", bif_blob_to_string, &bt_string);
  bif_define_typed ("blob_to_string_output", bif_blob_to_string_output, &bt_any_box);
  bif_define ("blob_page", bif_blob_page);
  bif_define_ex ("_cvt"		, bif_convert		, BMD_RET_TYPE, &bt_convert	, BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 3	, BMD_IS_PURE, BMD_DONE);
  bif_define ("__cast_internal", bif_cast_internal);
  bif_define ("__ssl_const", bif_stub_ssl_const);
  bif_define ("coalesce", bif_stub_coalesce);
  bif_define ("contains", bif_stub_contains);
  bif_define ("xpath_contains", bif_stub_xpath_contains);
  bif_define ("xquery_contains", bif_stub_xquery_contains);
  bif_define ("xcontains", bif_stub_xcontains);
  bif_define_typed ("exists", bif_stub_exists, &bt_integer);
  st_varchar = (sql_tree_tmp *) list (3, DV_LONG_STRING, 0, 0);
  st_nvarchar = (sql_tree_tmp *) list (3, DV_LONG_WIDE, 0, 0);


  bif_define_typed ("sequence_next", bif_sequence_next, &bt_integer);
  bif_define_typed ("sequence_remove", bif_sequence_remove, &bt_integer);
  bif_define_typed ("__sequence_set", bif_sequence_set, &bt_integer);
  bif_define_typed ("get_all_sequences", bif_sequence_get_all, &bt_any_box);
  bif_define_typed ("sequence_get_all", bif_sequence_get_all, &bt_any_box);
  bif_define_ex ("\x01__sequence_set_no_check", bif_sequence_set_no_check, BMD_MIN_ARGCOUNT, 3, BMD_MAX_ARGCOUNT, 3, BMD_IS_DBA_ONLY, BMD_DONE);
  bif_define_ex ("\x01__sequence_next_no_check", bif_sequence_next_no_check, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 3, BMD_IS_DBA_ONLY, BMD_DONE);
  bif_define_typed ("registry_get_all", bif_registry_get_all, &bt_any_box);
  bif_define_typed ("registry_get", bif_registry_get, &bt_varchar);
  bif_define_typed ("registry_name_is_protected", bif_registry_name_is_protected, &bt_integer);
  bif_define_typed ("registry_set", bif_registry_set, &bt_integer);
  bif_define_typed ("registry_remove", bif_registry_remove, &bt_integer);
  bif_define_typed ("set_qualifier", bif_set_qualifier, &bt_integer);
  bif_set_no_cluster ("set_qualifier");
  bif_define_typed ("name_part", bif_name_part, &bt_varchar);
  bif_define_typed ("key_replay_insert", bif_key_replay_insert, &bt_integer);
  bif_define ("__clear_index", bif_clear_index);

  /* security functions */
  bif_define ("sec_set_user_data", bif_set_user_data);
  bif_define ("sec_set_user_struct", bif_set_user_struct);
  bif_define ("__set_user_os_acount_int", bif_set_user_os_acount_int);
  bif_define ("sec_remove_user_struct", bif_remove_user_struct);
  bif_define ("sec_grant_user_role", bif_grant_user_role);
  bif_define ("sec_revoke_user_role", bif_revoke_user_role);
#if 1
  bif_define ("list_role_grants", bif_list_role_grants);
#endif
  bif_define ("sec_set_user_cert", bif_set_user_cert);
  bif_define ("sec_remove_user_cert", bif_remove_user_cert);
  bif_define ("sec_get_user_by_cert", bif_get_user_by_cert);
  bif_define ("sec_user_enable", bif_set_user_enable);

  bif_define ("user_set_password", bif_user_set_password); /* only for SQL users */
  bif_define ("log_text", bif_log_text);
  bif_define ("log_text_array", bif_log_text_array);
  bif_define ("repl_text", bif_repl_text);
  bif_define ("repl_text_pushback", bif_repl_text_pushback);
  bif_define ("repl_set_raw", bif_repl_set_raw);
  bif_define ("repl_is_raw", bif_repl_is_raw);
  bif_define ("log_enable", bif_log_enable);
  bif_set_vectored (bif_log_enable, (bif_vec_t)bif_log_enable);
  bif_define_typed ("serialize", bif_serialize, &bt_any);
  bif_define_typed ("deserialize", bif_deserialize, &bt_any);
  bif_define_typed ("complete_table_name", bif_complete_table_name, &bt_varchar);
  bif_define_typed ("complete_proc_name", bif_complete_proc_name, &bt_varchar);
  bif_define_typed ("__any_grants", bif_any_grants, &bt_integer);
  bif_define_typed ("__any_grants_to_user", bif_any_grants_to_user, &bt_integer);
  bif_define ("txn_error", bif_txn_error);
  bif_define ("__trx_no", bif_trx_no);
  bif_define ("__commit", bif_commit);
  bif_set_no_cluster ("__commit");
  bif_define ("__rollback", bif_rollback);
  bif_set_no_cluster ("__rollback");
  bif_define ("replay", bif_replay);
  bif_define ("txn_killall", bif_txn_killall);

  bif_define ("__ddl_changed", bif_ddl_change);
  /*bif_define ("__ddl_table_renamed", bif_ddl_table_renamed);*/
  bif_define ("__ddl_index_def", bif_ddl_index_def);
  bif_define_typed ("__row_count_exceed", bif_row_count_exceed, &bt_integer);
  bif_define ("__view_changed", bif_view_changed);
  bif_set_uses_index (bif_view_changed);
  bif_define ("__mapping_schema_changed", bif_mapping_schema_changed);
  bif_set_uses_index (bif_mapping_schema_changed);
  bif_define ("__proc_changed", bif_proc_changed);
  bif_set_uses_index (bif_proc_changed);
  bif_define ("__drop_trigger", bif_drop_trigger);
  bif_define ("__drop_proc", bif_drop_proc);
  bif_define ("__proc_exists", bif_proc_exists);
  bif_define ("__proc_params_num", bif_proc_params_num);
  bif_define_typed ("__copy", bif_copy, &bt_copy);
  bif_define_typed ("__copy_non_local", bif_copy_non_local, &bt_copy);
  bif_set_uses_index (bif_copy_non_local);
  bif_define_typed ("exec", bif_exec, &bt_integer);
  bif_define_typed ("exec_vec", bif_exec_vec, &bt_integer);
  bif_define_typed ("exec_metadata", bif_exec_metadata, &bt_integer);
  bif_define ("exec_score", bif_exec_score);
  bif_set_uses_index (bif_exec);
  bif_define_typed ("exec_next", bif_exec_next, &bt_integer);
  bif_define ("exec_close", bif_exec_close);
  bif_define ("exec_result_names", bif_exec_result_names);
  bif_define ("exec_result", bif_exec_result);
  bif_define ("__set", bif_set);
  bif_set_vectored (bif_set, (bif_vec_t)bif_set);
  bif_define_typed ("vector_concat", bif_vector_concatenate, &bt_any_box);
#if 1 /* meter functions */
  bif_define ("mutex_meter", bif_mutex_meter);
  bif_define ("spin_wait_meter", bif_spin_wait_meter);
  bif_define ("spin_meter", bif_spin_meter);
  bif_define ("mem_meter", bif_mem_meter);
  bif_define ("mutex_stat", bif_mutex_stat);
  bif_define ("self_meter", bif_self_meter);
  bif_define ("malloc_meter", bif_malloc_meter);
  bif_define ("copy_meter", bif_copy_meter);
  bif_define ("busy_meter", bif_busy_meter);
  bif_define ("alloc_cache_status", bif_alloc_cache_status);
#endif
  bif_define ("getrusage", bif_getrusage);
  bif_define_typed ("rdtsc",  bif_rdtsc, &bt_integer);
  bif_define_typed ("row_count", bif_row_count, &bt_integer);
  bif_define_typed ("set_row_count", bif_set_row_count, &bt_integer);
  bif_define ("__assert_found", bif_assert_found);
  bif_define ("__atomic", bif_atomic);
  bif_define ("is_atomic", bif_is_atomic);
  bif_define_ex ("\x01__reset_temp" /* was "__reset_temp" */, bif_clear_temp, BMD_MAX_ARGCOUNT, 0, BMD_IS_DBA_ONLY, BMD_DONE);
  bif_define ("__trx_disk_log_length", bif_trx_disk_log_length);
  bif_define ("checkpoint_interval", bif_checkpoint_interval);
  bif_define ("sql_lex_analyze", bif_sql_lex_analyze);
  bif_define ("sql_split_text", bif_sql_split_text);

  bif_define ("client_trace", bif_client_trace);

  bif_define ("__set_identity", bif_set_identity);
  bif_define ("__set_user_id", bif_set_user_id);
  bif_define ("set_user_id", bif_set_user_id);
  bif_define ("get_user_id", bif_get_user_id);
  bif_define ("__pop_user_id", bif_pop_user_id);
  bif_define ("identity_value", bif_identity_value);
  fcache_init ();
  bif_define ("mem_enter_reserve_mode", bif_mem_enter_reserve_mode);
  bif_define ("mem_debug_enabled", bif_mem_debug_enabled);
#ifdef MALLOC_DEBUG
  bif_define ("mem_all_in_use", bif_mem_all_in_use);
  bif_define ("mem_new_in_use", bif_mem_new_in_use);
  bif_define ("mem_leaks", bif_mem_leaks);
#endif
  bif_define_typed ("mem_get_current_total", bif_mem_get_current_total, &bt_integer);
  bif_define ("mem_summary", bif_mem_summary);
#ifdef MALLOC_STRESS
  bif_define ("set_hard_memlimit", bif_set_hard_memlimit);
  bif_define ("set_hit_memlimit", bif_set_hit_memlimit);
#endif
  bif_define ("sqlo_enable", bif_sqlo);
  bif_define ("hic_clear", bif_hic_clear);
  bif_define ("hic_set_memcache_size", bif_hic_set_memcache_size);

  bif_define ("icc_try_lock", bif_icc_try_lock);
  bif_define ("icc_lock_at_commit", bif_icc_lock_at_commit);
  bif_define ("icc_unlock_now", bif_icc_unlock_now);

  /* for system use only ruslan@openlinksw.com */
  bif_define ("raw_length", bif_raw_length);

  /* check byteorder/version in the log */
  bif_define ("byte_order_check", bif_byte_order_check);
  bif_define ("server_version_check", bif_server_version_check);
  bif_define ("server_id_check", bif_server_id_check);

  /* bit operations for BPEL */
  bif_define ("bit_set", bif_bit_set);
  bif_define ("bit_clear", bif_bit_clear);
  bif_define ("bit_v_count", bif_bit_v_count);
  bif_define ("bit_is_set", bif_is_set);
  bif_define ("v_bit_or", bif_v_bit_or);
  bif_define ("v_bit_and", bif_v_bit_and);
  bif_define ("v_bit_not", bif_v_bit_not);
  bif_define ("v_true", bif_v_true);
  bif_define ("all_bits_set", bif_all_bits_set);
  bif_define ("v_bit_all_pos", bif_v_bit_all_pos);
  bif_define ("v_equal", bif_v_equal);
  bif_define ("bit_print", bif_bit_print);
  bif_define ("search_excerpt", bif_search_excerpt);
  bif_define_typed ("fct_level", bif_fct_level, &bt_varchar);
  bif_define_typed ("sum_rank", bif_sum_rank, &bt_double);
  bif_set_vectored (bif_fct_level, bif_fct_level_vec);

  /* Short aliases for use in generated SQL text: */
  bif_define ("__bft", bif_box_flags_tweak);
  bif_define ("__spf", bif_sprintf);
  bif_define ("__spfn", bif_sprintf_or_null);
  bif_define ("__spfi", bif_sprintf_iri);
  bif_define ("__spfin", bif_sprintf_iri_or_null);
  bif_define ("__spfinv", bif_sprintf_inverse);

  sqlbif2_init ();
  bif_sparql_init ();

#ifdef BIF_PURIFY
  bif_purify_init ();
#endif

#ifdef BIF_GNW
  bif_gnw_init ();
#endif

  bif_intl_init ();

  langfunc_kernel_init();
  if (NULL != server_default_language_name)
    server_default_lh = lh_get_handler(server_default_language_name);
  else
    {
      server_default_language_name = "en-US";
      server_default_lh = lh_get_handler("en-US");
    }

#ifdef BIF_XML
  bif_xml_init ();
#endif

#ifdef BIF_XPER
  bif_xper_init ();
#endif

  bif_date_init ();
  bif_geo_init ();
  bif_file_init ();
  bif_status_init ();
  bif_explain_init ();
  recovery_init ();
  backup_online_init ();
  bif_repl_init ();
  bif_regexp_init ();
#ifdef BIF_XML
  bif_soap_init ();
  bif_http_client_init ();
  bif_smtp_init ();
#endif
#ifdef _IMSG
  bif_pop3_init ();
  bif_imap_init ();
  bif_nntp_init ();
#endif
#ifdef VIRTTP
  tp_bif_init();
#endif
  if (MSDTC_IS_LOADED)
    mts_bif_init();
#ifdef _LDAP
  bif_ldapcli_init();
#endif
#ifdef _KERBEROS
  bif_kerberos_init ();
#endif
  bif_crypto_init ();
  bif_audio_init ();
  bif_uuencode_init();
  bif_udt_init();

  bif_xmlenc_init();

  bif_fillup_system_tables_hash();
  init_pwd_magic_users ();
  bif_define ("__grouping", bif_grouping);
  bif_define ("__grouping_set_bitmap", bif_grouping_set_bitmap);
#if 0
  bif_define ("sequence_is_auto_increment", bif_sequence_is_auto_increment);
#endif
  bif_define ("add_protected_sequence", bif_add_protected_sequence);
  bif_hosting_init ();
  bif_aq_init ();
  bif_diff_init();
  rdf_box_init ();
  bif_json_init ();
  col_init ();
  geo_init ();
  bif_define ("repl_this_server", bif_dummy);
  return;
}


dk_set_t bif_index_users = NULL;

void
bif_set_uses_index (bif_t  bif)
{
  bif_metadata_t *bmd = find_bif_metadata_by_bif (bif);
  if (NULL == bmd)
    GPF_T;
  bmd->bmd_uses_index = 1;
}

void
bif_set_is_aggregate (bif_t  bif)
{
  bif_metadata_t *bmd = find_bif_metadata_by_bif (bif);
  if (NULL == bmd)
    GPF_T;
  bmd->bmd_is_aggregate = 1;
}

int
bif_uses_index (bif_t bif)
{
  bif_metadata_t *bmd;
  if (bif_key_replay_insert == bif || bif_row_deref == bif)
  return 1;
  bmd = find_bif_metadata_by_bif (bif);
  if (NULL == bmd)
    {
      print_trace ();
      log_info ("bif_uses_index () with unregistered %p\n", bif);
      return 0;
    }
  return bmd->bmd_uses_index;
}

int
bif_is_aggregate (bif_t bif)
{
  bif_metadata_t *bmd = find_bif_metadata_by_bif (bif);
  if (NULL == bmd)
    {
      print_trace ();
      log_info ("bif_is_aggregate () with unregistered %p\n", bif);
      return 0;
    }
  return bmd->bmd_is_aggregate;
}


int
bif_is_no_cluster (bif_t bif)
{
  int fl;
  bif_metadata_t *bmd = find_bif_metadata_by_bif (bif);
  if (NULL == bmd)
    GPF_T;
  fl = bmd->bmd_no_cluster;
  return enable_rec_qf ? fl & BIF_NO_CLUSTER : fl & (BIF_NO_CLUSTER | BIF_OUT_OF_PARTITION);
}

int
bif_need_enlist (bif_t bif)
    {
  int fl;
  bif_metadata_t *bmd = find_bif_metadata_by_bif (bif);
  if (NULL == bmd)
    GPF_T;
  fl = bmd->bmd_no_cluster;
  return fl & BIF_ENLIST;
}

void
bif_set_no_cluster (char * n)
{
  bif_metadata_t *bmd = find_bif_metadata_by_raw_name (n);
  if (NULL == bmd)
    GPF_T1 (n);
  bmd->bmd_no_cluster = BIF_NO_CLUSTER;
    }


void
bif_set_cluster_rec (char * n)
{
  bif_metadata_t *bmd = find_bif_metadata_by_raw_name (n);
  if (NULL == bmd)
    GPF_T1 (n);
  bmd->bmd_no_cluster |= BIF_OUT_OF_PARTITION;
}


void
bif_set_enlist (char * n)
{
  bif_metadata_t *bmd = find_bif_metadata_by_raw_name (n);
  if (NULL == bmd)
    GPF_T1 (n);
  bmd->bmd_no_cluster |= BIF_ENLIST;
}


bif_vec_t
bif_vectored (bif_t bif)
{
  bif_metadata_t *bmd = find_bif_metadata_by_bif (bif);
  if (NULL == bmd)
    return NULL; /* not GPF_T; to work during startup */
  return bmd->bmd_vector_impl;
}


void
bif_set_vectored (bif_t bif, bif_vec_t vectored)
{
  bif_metadata_t *bmd = find_bif_metadata_by_bif (bif);
  if (NULL == bmd)
    GPF_T;
  bmd->bmd_vector_impl = vectored;
}


char * bpel_run_check_proc = "RESTART_ALL_BPEL_INSTANCES ()";

#if 0
#define CHECKP(x)  fprintf (stderr, x "." );  fflush (stderr)
#else
#define CHECKP(x)
#endif

static const char * set_var_proc =
  "select BPEL.BPEL.set_var_to_dump (?, ?, ?, ?, ?, ?)";

caddr_t bpel_set_var_by_dump (const char * my_name, const char * my_part,
			      const char * my_query, const char * my_val,
			      const char * my_vars, const char* my_xmlnss)
{
  client_connection_t * cli = client_connection_create ();
  query_t * qr = 0;
  caddr_t err = 0;
  local_cursor_t * lc = 0;
  caddr_t res = 0;

  CHECKP("1");
  IN_TXN;
  cli_set_new_trx (cli);
  lt_threads_set_inner (cli->cli_trx, 1);
  LEAVE_TXN;
  CHECKP("2");
  qr = eql_compile (set_var_proc, cli);
  CHECKP("2");
  if (!qr)
    goto fin;
  CHECKP("2");
  err = qr_quick_exec (qr, cli, "", &lc, 6,
		       ":0", my_name, QRP_STR,
		       ":1", my_part, QRP_STR,
		       ":2", my_query, QRP_STR,
		       ":3", my_val, QRP_STR,
		       ":4", my_vars, QRP_STR,
		       ":5", my_xmlnss, QRP_STR);
  CHECKP("3");
  if (err)
    goto fin;
  CHECKP("4");
  if (lc_next (lc))
    {
      CHECKP("5");
      res = box_copy (lc_nth_col (lc, 0));
    }
 fin:
  CHECKP("6");
  if (lc)
    lc_free (lc);
  CHECKP("7");
  if (qr)
    {
      CHECKP("8");
      qr_free (qr);
    }
  CHECKP("9");
  IN_TXN;
  CHECKP("10");
  lt_rollback (cli->cli_trx, TRX_FREE);
  CHECKP("11");
  LEAVE_TXN;
  CHECKP("12");
  client_connection_free (cli);
  CHECKP("13");
  return res;
}

static const char * get_var_proc =
  "select BPEL.BPEL.get_var_from_dump (?, ?, ?, ?, ?)";
caddr_t bpel_get_var_by_dump (const char * my_name, const char * my_part,
			      const char * my_query, const char * my_vars, const char* my_xmlnss)
{
  client_connection_t * cli = client_connection_create ();
  query_t * qr = 0;
  caddr_t err = 0;
  local_cursor_t * lc = 0;
  caddr_t res = 0;

  CHECKP("1");
  IN_TXN;
  cli_set_new_trx (cli);
  lt_threads_set_inner (cli->cli_trx, 1);
  LEAVE_TXN;
  CHECKP("2");
  qr = eql_compile (get_var_proc, cli);
  CHECKP("2");
  if (!qr)
    goto fin;
  CHECKP("2");
  err = qr_quick_exec (qr, cli, "", &lc, 5,
		       ":0", my_name, QRP_STR,
		       ":1", my_part, QRP_STR,
		       ":2", my_query, QRP_STR,
		       ":3", my_vars, QRP_STR,
		       ":4", my_xmlnss, QRP_STR);
  CHECKP("3");
  if (err)
    goto fin;
  CHECKP("4");
  if (lc_next (lc))
    {
      CHECKP("5");
      res = box_copy (lc_nth_col (lc, 0));
    }
 fin:
  CHECKP("6");
  if (lc)
    lc_free (lc);
  CHECKP("7");
  if (qr)
    {
      CHECKP("8");
      qr_free (qr);
    }
  CHECKP("9");
  IN_TXN;
  CHECKP("10");
  lt_rollback (cli->cli_trx, TRX_FREE);
  CHECKP("11");
  LEAVE_TXN;
  CHECKP("12");
  client_connection_free (cli);
  CHECKP("13");
  return res;
}




void bpel_init ()
{
  ddl_ensure_table ("do this always", bpel_run_check_proc);
}
