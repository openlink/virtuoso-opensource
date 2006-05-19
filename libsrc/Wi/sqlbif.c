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

/*
   NEVER write bif functions that return the same boxed argument
   that they got as an argument. The result will be a crash after
   a while, when that same box is free'ed twice!

   CHANGES -- Beginning from 15.JAN.1997

   15.JAN.1997 AK  Made sure that the server won't bomb out any more
   if the user gives nonsensible date-time values
   for the date conversion functions.
   I.e. now we check that the return value of localtime
   is not a null pointer.
   Changed in functions bif_date_string, bif_date_add
   and bif_date_diff the following lines:

   memcpy (& tm, localtime (& tv.tv_sec), sizeof (tm));
   to these:  tm = localtime (& tv.tv_sec);
   And changed each:       struct tm tm;
   to the corresponding pointer definition:  struct tm *tm;
   And replaced element references like:   tm.tm_year
   with corresponding pointer references: tm->tm_year

   Modified also functions aset (now returns the modified
   array or string instead of the stored element),
   subseq (allows also empty substrings).

   Added a new argument fetching function
   bif_long_or_char_arg (for the internal use only)
   and functions bif_strchr and bif_iszero to be
   used by the user.

   16.JAN.1997 AK  Corrected few bugs I created yesterday.
   Remodified aset to return back the element
   it gets, not the modified array or string
   (See the note above to see why.)
   Corrected few bugs in date conversion functions.
   Added functions bif_strrchr and bif_chr

   dbg_printf and dbg_obj_print now print out one
   newline ('\n') after everything else, so that
   the debugger's life shall be less harsh.
   (As there are now easy way how user could insert
   newline into the control string of dbg_printf)

   17.JAN.1997 AK  Added functions bif_strstr, bif_nc_strstr,
   bif_matches_like and bif_either

   20.JAN.1997 AK  Added functions bif_isnull, bif_dv_to_sql_type
   and bif_dv_type_title for the needs of a
   new version of SQLColumns in sqlext.c

   30.JAN.1997 AK  Modified bif_length so that it now returns zero
   for NULL instead of generating an error.
   Also returns the length of LONG VARCHAR's which it will
   find from their DV_BLOB_HANDLE header (bh_length).

   Added also the functions bif_internal_type (mainly
   for debugging), bif_isblob_handle, bif_isinteger
   and bif_isstring

   22-FEB-1997 AK  A wholly new revision, with a monton of new functions
   and improvements to the old ones. See file funref.doc
   for more results.
   Also, the following old functions has now been renamed

   isblob_handle -> isblob

   and the following new aliases has been defined, with
   the old name still working

   get_timestamp -> now
   concatenate -> concat
   dv_to_sql_type -> internal_to_sql_type
   dv_type_title -> internal_type_name


   04-MAR-1997 AK  Changed first argument of get_keyword from string
   to anything, so anything can be used as keywords,
   including numbers.

   10-MAR-1997 AK  Changed desc -> cd_precision to 64 from old 8
   in function bif_result_names, so that gettypeinfo
   will return its type names untruncated to JDBC test.
   (Maximum is "DOUBLE PRECISION" 16 characters.)

   11-MAR-1997 AK  In version synced with OUI's one this is replaced again,
   by assigning desc -> cd_precision to sl -> ssl_prec
   bif_sprintf taken from OUI's version, made few
   fixes to it also.

   22-MAR-1997 AK  Added function stringtime, and alias   t   for it,
   as well as aliases   d   and   ts   for stringdate.
   For the needs of lazy implementation of ODBC brace
   escaped date/time literals like {d '2038-01-18'}
   etc. See sql2.y for the kludgeous way how they have
   been implemented.

   Mar 28 97  oui   lvector, fvector, dvector, make_array, bif_float_arg, bif_double_arg


   Apr 13 97 oui row_identity, row_deref, raw_exit
   May 25 97 - oui use tm_isdst = -1 before mktime

   29-OCT-1997 AK  Added functions
   bif_curdate, bif_locate, bif_position
   ODBC "System functions" ifnull, dbname, username
   and modified old ones
   ltrim, rtrim, trim, strchr, strrchr, strstr, nc_strstr,
   matches_like, lcase, ucase, initcap, right, left,
   repeat and concat to use
   a new function bif_string_or_null_arg instead
   of an old big_string_arg, so when their
   first (and sometimes second) argument is SQL NULL
   instead of a string, the same kind of NULL will
   be returned.
   The exception is concat, which will just skip
   all NULL's which are its arguments, effectively
   like they were empty strings ""'s.

   bif_disconnect (disconnect_user) modified so that
   if given NULL argument, then disconnects all
   other users than the one who issued that function
   call.

   01-04.NOV.97 AK  Other improvements. Most of the timedate functions.
   Most of the floating point functions like sin, sqrt.
   get_keyword and a new position function made more
   generic in regard to their arguments: may be now
   vector type, also long, double, float.

   New function one_of_these for implementing IN predicate.
   make_array corrected.

   NOTE: at least week() and dayofyear() are still buggy.

   29-NOV-1997  AK  Added bif_replace(src_str,from_str,to_str[,max_n])

   04-DEC-1997  AK  Added bif_split_and_decode(src_str[,0/1/2[,alt_seps])
   first for the needs of GLOW-programming, later for
   any generic purpose.
 */

#include "sqlnode.h"
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
#include <math.h>
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
#include "sql3.h"
#include "repl.h"
#include "replsr.h"
#include "sqltype.h" /* for XMLTYPE_TO_ENTITY */
#include "msdtc.h"
#include "sqlcstate.h"
#include "virtpwd.h"

#define box_bool(n) ((caddr_t)((ptrlong)((n) ? 1 : 0)))

id_hash_t *icc_locks;
dk_mutex_t *icc_locks_mutex;

void qi_read_table_schema (query_instance_t * qi, char *read_tb);
void ddl_rename_table_1 (query_instance_t * qi, char *old, char *new_name, caddr_t *err_ret);
void bif_date_init (void);
void bif_file_init (void);
void bif_explain_init (void);
void bif_status_init (void);
void bif_repl_init (void);
void bif_intl_init (void);
void recovery_init (void);
void backup_online_init (void);
void bif_xml_init (void);
void bif_xper_init (void);
void bif_soap_init (void);
void bif_http_client_init (void);
void bif_smtp_init (void);
void bif_pop3_init (void);
void bif_nntp_init (void);
void bif_regexp_init(void);
void bif_crypto_init(void);
void bif_uuencode_init(void);
void bif_udt_init(void);
void bif_xmlenc_init(void);
void tp_bif_init(void);
#ifdef _KERBEROS
void  bif_kerberos_init (void);
#endif

#ifdef VIRTTP
#include "2pc.h"
#endif

id_hash_t *name_to_bif;
id_hash_t *name_to_bif_type;


caddr_t
bif_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func)
{
  if (((uint32) nth) >= BOX_ELEMENTS (args))
  sqlr_new_error ("22003", "SR030", "Too few arguments for %s.", func);
  return (QST_GET (qst, args[nth]));
}


caddr_t
bif_string_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func)
{
  caddr_t arg = bif_arg (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
#ifndef O12
  if (dtp == DV_BLOB_HANDLE)
  {
    caddr_t bs = blob_to_string (((query_instance_t *) qst)->qi_trx, arg);
    qst_set (qst, args[nth], bs);
    return bs;
  }
#endif
  if (dtp != DV_SHORT_STRING && dtp != DV_LONG_STRING)
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

caddr_t
bif_string_or_wide_or_uname_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func)
{
  caddr_t arg = bif_arg (qst, args, nth, func);
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


#ifdef BIF_XML
struct xml_entity_s *
bif_entity_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func)
{
  caddr_t arg = bif_arg (qst, args, nth, func);
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
  caddr_t arg = bif_arg (qst, args, nth, func);
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
    sqlr_new_error ("22023", "SR345", "Persistent XML not allowed as an argument %d to funtion %s; this function accepts only XML tree entities", nth+1, func);
  return (xml_tree_ent_t *)arg;
}
#endif

caddr_t
bif_bin_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func)
{
  caddr_t arg = bif_arg (qst, args, nth, func);
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
  caddr_t arg = bif_arg (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  if (DV_DB_NULL == dtp)
  {
    return (NULL);
  }
#ifndef O12
  else if (dtp == DV_BLOB_HANDLE)
  {
    caddr_t bs = blob_to_string (((query_instance_t *) qst)->qi_trx, arg);
    qst_set (qst, args[nth], bs);
    return bs;
  }
#endif

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
  caddr_t arg = bif_arg (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  if (DV_DB_NULL == dtp)
  {
    return (NULL);
  }
#ifndef O12
  if (dtp == DV_BLOB_HANDLE || dtp == DV_BLOB_WIDE_HANDLE)
  {
    caddr_t bs = blob_to_string (((query_instance_t *) qst)->qi_trx, arg);
    qst_set (qst, args[nth], bs);
    return bs;
  }
#endif
  if (dtp != DV_SHORT_STRING && dtp != DV_LONG_STRING
       && dtp != DV_C_STRING
      && !IS_WIDE_STRING_DTP (dtp) && dtp != DV_STRING_SESSION)
    {
      sqlr_new_error ("22023", "SR006",
    "Function %s needs a string or string session or NULL as argument %d, "
    "not an arg of type %s (%d)",
    func, nth + 1, dv_type_title (dtp), dtp);
  }
  return arg;
}

caddr_t
bif_string_or_wide_or_null_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func)
{
  caddr_t arg = bif_arg (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  if (DV_DB_NULL == dtp)
  {
    return (NULL);
  }
#ifndef O12
  if (dtp == DV_BLOB_HANDLE || dtp == DV_BLOB_WIDE_HANDLE)
  {
    caddr_t bs = blob_to_string (((query_instance_t *) qst)->qi_trx, arg);
    qst_set (qst, args[nth], bs);
    return bs;
  }
#endif
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
bif_type_t bt_varchar = {NULL, DV_LONG_STRING, 0, 0};
bif_type_t bt_wvarchar = {NULL, DV_WIDE, 0, 0};
bif_type_t bt_varbinary = {NULL, DV_BIN, 0, 0};
bif_type_t bt_any = {NULL, DV_ANY, 0, 0};
bif_type_t bt_integer = {NULL, DV_LONG_INT, 0, 0};
bif_type_t bt_iri = {NULL, DV_IRI_ID, 0, 0};



ptrlong
bif_long_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func)
{
  caddr_t arg = bif_arg (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  if (dtp == DV_SINGLE_FLOAT)
  return ((ptrlong) unbox_float (arg));
  if (dtp == DV_DOUBLE_FLOAT)
  return ((ptrlong) unbox_double (arg));
  if (dtp == DV_NUMERIC)
  {
    int32 tl;
    numeric_to_int32 ((numeric_t) arg, &tl);
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
  caddr_t arg = bif_arg (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  if (dtp == DV_SINGLE_FLOAT)
    return ((iri_id_t) (uint32) unbox_float (arg));
  if (dtp == DV_DOUBLE_FLOAT)
    return ((iri_id_t) (uint32) unbox_double (arg));
  if (dtp == DV_NUMERIC)
    {
      int32 tl;
      numeric_to_int32 ((numeric_t) arg, &tl);
      return (iri_id_t)(uint32) tl;
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
  return (iri_id_t) (uint32) (unbox (arg));
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


ptrlong
bif_long_or_null_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func, int *isnull)
{
  caddr_t arg = bif_arg (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  *isnull = 0;
  if (DV_DB_NULL == dtp)
    {
      *isnull = 1;
      return 0;
    }
  if (dtp == DV_SINGLE_FLOAT)
    return ((ptrlong) unbox_float (arg));
  if (dtp == DV_DOUBLE_FLOAT)
    return ((ptrlong) unbox_double (arg));
  if (dtp == DV_NUMERIC)
  {
    int32 tl;
    numeric_to_int32 ((numeric_t) arg, &tl);
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
  caddr_t arg = bif_arg (qst, args, nth, func);
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
  caddr_t arg = bif_arg (qst, args, nth, func);
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

static caddr_t
bif_varchar_or_bin_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func)
{
  caddr_t arg = bif_arg (qst, args, nth, func);
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
  caddr_t arg = bif_arg (qst, args, nth, func);
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

caddr_t
bif_array_or_strses_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func)
{
  caddr_t arg = bif_arg (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  if (dtp == DV_SHORT_STRING || dtp == DV_LONG_STRING
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


#define PF_ARG(n) (n < n_args ? unbox (qst_get (qst, args [n])) : 0)


caddr_t bif_sprintf (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);

caddr_t
bif_dbg_printf (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t ret = bif_sprintf (qst, err_ret, args);
#if 0
  long n_args = BOX_ELEMENTS (args);
  printf ((char *) PF_ARG (0), PF_ARG (1), PF_ARG (2), PF_ARG (3),
    PF_ARG (4), PF_ARG (5), PF_ARG (6), PF_ARG (7), PF_ARG (8));
  printf ("\n");    /* Added by AK, 16-JAN-1997 for nicer output. */
  fflush (stdout);
#endif
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
  DO_BOX (state_slot_t *, arg, inx, args)
  {
  dbg_print_box (qst_get (qst, arg), stdout);
  }
  END_DO_BOX;
  printf ("\n");    /* Added by AK, 16-JAN-1997 for nicer output. */
  fflush (stdout);
  return NULL;
}


caddr_t
bif_dbg_obj_princ (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int inx;
  int prev_is_strg_const = 1;
  DO_BOX (state_slot_t *, arg, inx, args)
  {
    caddr_t val = qst_get (qst, arg);
    int this_is_strg_const = ((SSL_CONSTANT == arg->ssl_type) && (DV_STRING == DV_TYPE_OF (val)));
    if (! (this_is_strg_const || prev_is_strg_const))
      printf (", ");
    if (this_is_strg_const)
      printf ("%s", val);
    else
      dbg_print_box (val, stdout);
    prev_is_strg_const = this_is_strg_const;
  }
  END_DO_BOX;
  printf ("\n");    /* Added by AK, 16-JAN-1997 for nicer output. */
  fflush (stdout);
  return NULL;
}


caddr_t
bif_clear_temp (caddr_t *  qst, caddr_t * err_ret, state_slot_t ** args)
{
  hash_area_t * ha = (hash_area_t *) (ptrlong) bif_long_arg (qst, args, 0, "__clear_temp");
  setp_temp_clear (NULL, ha, qst);
  return NULL;
}


caddr_t
bif_proc_table_result (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args,
         client_connection_t * cli, va_list ap, int n_ext_args)
{
  state_slot_t vals[TB_MAX_COLS];
  state_slot_t *pvals_buf[TB_MAX_COLS + 20], **saved_slots;
  hash_area_t *ha = (hash_area_t *) cli->cli_result_ts;
  itc_ha_feed_ret_t ihfr;
  caddr_t * result_qst = (caddr_t *) cli->cli_result_qi;
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
      dtp_t dtp, target_dtp;

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
	  && !(dtp == DV_LONG_INT && target_dtp == DV_SHORT_INT)
	  && !(ha->ha_key_cols[inx + 1].cl_sqt.sqt_is_xml && XE_IS_VALID_VALUE_FOR_XML_COL (v)))
	{
	  *err_ret = srv_make_new_error ("22023", "SR342",
	      "procedure view's procedure returned value of type %.50s(dtp %d) instead of %.50s(dtp %d)"
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
  caddr_t cli_ws = (caddr_t) ((query_instance_t *)qst)->qi_client->cli_ws;
  client_connection_t * cli = (client_connection_t *) ((query_instance_t *)qst)->qi_client;
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
    long n_cols = cli->cli_resultset_cols;
    int inx;
    caddr_t * out;
    len = MAX ((n_cols * sizeof (caddr_t)), (box_length ((caddr_t) args)));
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
        PrpcAddAnswer ((caddr_t) out, DV_ARRAY_OF_POINTER, PARTIAL, 0);
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
  caddr_t cli_ws = (caddr_t) ((query_instance_t *)qst)->qi_client->cli_ws;
  client_connection_t * cli = (client_connection_t *) ((query_instance_t *)qst)->qi_client;
  va_list dummy;
  caddr_t arg_values = bif_arg (qst, args, 0, "exec_result");

  if (DV_TYPE_OF (arg_values) != DV_ARRAY_OF_POINTER ||
      BOX_ELEMENTS (arg_values) < 1)
    sqlr_new_error ("22023", "SR334",
  "The result names description should be an array in exec_result");

  if (cli->cli_result_qi)
    {
      bif_proc_table_result ((caddr_t *) -1, err_ret, (state_slot_t **) arg_values, cli, dummy, 0);
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
    caddr_t * out;
    len = MAX ((n_cols * sizeof (caddr_t)), (box_length ((caddr_t) arg_values)));
    if (!cli->cli_resultset_data_ptr)
      {
        caddr_t anil = NEW_DB_NULL;
        out = (caddr_t *) dk_alloc_box (sizeof (caddr_t) + len, DV_ARRAY_OF_POINTER);
        out[0] = (caddr_t) QA_ROW;
        _DO_BOX (inx, ((caddr_t *)arg_values))
    {
      out[inx + 1] = ((caddr_t *) arg_values)[inx];
    }
        END_DO_BOX;
        for (; inx < n_cols; inx++)
    out[inx + 1] = anil;
        PrpcAddAnswer ((caddr_t) out, DV_ARRAY_OF_POINTER, PARTIAL, 0);
        dk_free_box ((box_t) out);
        dk_free_box (anil);
      }
    else
      {
        out = (caddr_t *) dk_alloc_box (len, DV_ARRAY_OF_POINTER);
        _DO_BOX (inx, ((caddr_t *)arg_values))
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
  caddr_t cli_ws = (caddr_t) ((query_instance_t *)qst)->qi_client->cli_ws;
  client_connection_t * cli = (client_connection_t *) ((query_instance_t *)qst)->qi_client;

  if (!cli_ws && cli_is_interactive (cli) && !cli->cli_result_qi &&
      !cli->cli_resultset_comp_ptr)
    {
      PrpcAddAnswer (SQL_SUCCESS, DV_ARRAY_OF_POINTER, PARTIAL, 0);
      cli->cli_resultset_cols = 0;
    }
  return NULL;
}


caddr_t
bif_result_names (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  long n_out = BOX_ELEMENTS (args), inx;
  caddr_t cli_ws = (caddr_t) ((query_instance_t *)qst)->qi_client->cli_ws;
  client_connection_t * cli = (client_connection_t *) ((query_instance_t *)qst)->qi_client;

  if (cli->cli_result_qi)
    return NULL;
  if ((!cli_ws && cli_is_interactive (cli)) || cli->cli_resultset_comp_ptr)
    {
      if (cli->cli_resultset_comp_ptr && *cli->cli_resultset_comp_ptr)
	{
	  *err_ret = srv_make_new_error ("37000", "SR001",
	      "More than one resultset not supported in a procedure called from exec");
	  return NULL;
	}
      else
	{
	  stmt_compilation_t *sc = (stmt_compilation_t *)
	      dk_alloc_box (sizeof (stmt_compilation_t), DV_ARRAY_OF_POINTER);
	  col_desc_t **cols = (col_desc_t **)
	      dk_alloc_box (n_out * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
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
	      desc->cd_searchable = 0;
	      desc->cd_nullable = 1;
	      desc->cd_updateable = 0;
	    }
	  sc->sc_columns = (caddr_t *) cols;
	  sc->sc_is_select = QT_PROC_CALL;
	  if (!cli->cli_resultset_comp_ptr)
	    {
	      caddr_t *desc_box = (caddr_t *) dk_alloc_box (2 * sizeof (caddr_t),
		  DV_ARRAY_OF_POINTER);
	      desc_box[0] = (caddr_t) QA_COMPILED;
	      desc_box[1] = (caddr_t) sc;
	      PrpcAddAnswer ((caddr_t) desc_box, DV_ARRAY_OF_POINTER, PARTIAL, 0);
	      dk_free_tree ((caddr_t) desc_box);
	    }
	  else
	    *((caddr_t *)cli->cli_resultset_comp_ptr) = (caddr_t) sc;
	  cli->cli_resultset_cols = n_out;
	}
    }
  return NULL;
}


static caddr_t
bif_exec_result_names (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  long n_out, inx;
  caddr_t cli_ws = (caddr_t) ((query_instance_t *)qst)->qi_client->cli_ws;
  client_connection_t * cli = (client_connection_t *) ((query_instance_t *)qst)->qi_client;
  caddr_t arg_descs = bif_arg (qst, args, 0, "exec_result_names");

  if (DV_TYPE_OF (arg_descs) != DV_ARRAY_OF_POINTER ||
      BOX_ELEMENTS (arg_descs) < 1)
    sqlr_new_error ("22023", "SR335",
  "The result names description should be an array in exec_result_names");

  n_out = BOX_ELEMENTS (arg_descs);
  if (cli->cli_result_qi)
    return NULL;
  if ((!cli_ws && cli_is_interactive (cli)) || cli->cli_resultset_comp_ptr)
    {
      if (cli->cli_resultset_comp_ptr && *cli->cli_resultset_comp_ptr)
  {
    *err_ret = srv_make_new_error ("37000", "SR001",
        "More than one resultset not supported in a procedure called from exec");
    return NULL;
  }
      else
  {
    stmt_compilation_t *sc = (stmt_compilation_t *)
        dk_alloc_box (sizeof (stmt_compilation_t), DV_ARRAY_OF_POINTER);
    col_desc_t **cols = (col_desc_t **)
        dk_alloc_box (n_out * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
    memset (sc, 0, sizeof (stmt_compilation_t));
    memset (cols, 0, n_out * sizeof (caddr_t));

    for (inx = 0; inx < n_out; inx++)
      {
        col_desc_t *desc = (col_desc_t *) dk_alloc_box (sizeof (col_desc_t),
      DV_ARRAY_OF_POINTER);
        caddr_t *value = ((caddr_t **)arg_descs)[inx];

        cols[inx] = desc;
        memset (desc, 0, sizeof (col_desc_t));

        if (DV_STRINGP (value))
    {
      desc->cd_name = box_dv_short_string ((caddr_t) value);
      desc->cd_dtp = DV_SHORT_STRING;
      desc->cd_nullable = 1;
      desc->cd_precision = box_num (256);
    }
        else if (DV_TYPE_OF (value) == DV_ARRAY_OF_POINTER &&
      (BOX_ELEMENTS (value) == 7 || BOX_ELEMENTS (value) == 12)  /* num elements in col_desc_t */)
    {
      if (DV_TYPE_OF (value[1]) != DV_LONG_INT ||
          !strcmp (dv_type_title ((int) (ptrlong) value[1]), "UNK_DV_TYPE"))
        goto error;
      if (DV_TYPE_OF (value[2]) != DV_LONG_INT ||
          unbox(value[2]) < 0 || unbox(value[2]) > 20)
        goto error;
      if (DV_TYPE_OF (value[3]) != DV_LONG_INT ||
          unbox(value[3]) < 0)
        goto error;

      desc->cd_name = box_dv_short_string (value[0]);
      desc->cd_dtp = (ptrlong) value[1];
      desc->cd_scale = box_num (unbox (value[2]));
      desc->cd_precision = box_num (unbox (value[3]));
      desc->cd_nullable = value[4] ? 1 : 0;
      desc->cd_updateable = value[5] ? 1 : 0;
      desc->cd_searchable = value[6] ? 1 : 0;
    }
        else
    {
error:
      dk_free_tree ((box_t) cols);
      dk_free_box ((box_t) sc);
      sqlr_new_error ("22023", "SR336",
          "Wrong result description in bif_result_string_names.");
    }
      }
    sc->sc_columns = (caddr_t *) cols;
    sc->sc_is_select = QT_PROC_CALL;
    if (!cli->cli_resultset_comp_ptr)
      {
        caddr_t *desc_box = (caddr_t *) dk_alloc_box (2 * sizeof (caddr_t),
      DV_ARRAY_OF_POINTER);
        desc_box[0] = (caddr_t) QA_COMPILED;
        desc_box[1] = (caddr_t) sc;
        PrpcAddAnswer ((caddr_t) desc_box, DV_ARRAY_OF_POINTER, PARTIAL, 0);
        dk_free_tree ((caddr_t) desc_box);
      }
    else
      *((caddr_t *)cli->cli_resultset_comp_ptr) = (caddr_t) sc;
    cli->cli_resultset_cols = n_out;
  }
    }
  return NULL;
}


void
bif_define (const char *name, bif_t bif)
{
  if (!name_to_bif)
  {
    name_to_bif = id_str_hash_create (501);
    name_to_bif_type = id_str_hash_create (301);
  }
  name = sqlp_box_id_upcase (name);
  id_hash_set (name_to_bif, (char *) &name, (char *) &bif);
}


void
bif_define_typed (const char *name, bif_t bif, bif_type_t * bt)
{
  bif_define (name, bif);
  name = sqlp_box_id_upcase (name);
  id_hash_set (name_to_bif_type, (char *) &name, (char *) &bt);
}


bif_t
bif_find (const char *name)
{
  bif_t *place = (bif_t *) id_hash_get (name_to_bif, (caddr_t) & name);
  if (place)
    return (*place);
  else if (case_mode == CM_MSSQL)
  {
    char *box = strlwr(box_string(name));

    place = (bif_t *) id_hash_get(name_to_bif, (caddr_t) & box);
    dk_free_box(box);
    if (place)
    return (*place);
  }
  return NULL;
}


bif_type_t *
bif_type (const char *name)
{
  bif_type_t **place =
    (bif_type_t **) id_hash_get (name_to_bif_type, (caddr_t) & name);
  if (place)
  return (*place);
  else if (case_mode == CM_MSSQL)
  {
    char *box = strlwr(box_string(name));
    place = (bif_type_t **) id_hash_get(name_to_bif_type, (caddr_t) & box);
    dk_free_box(box);
    if (place)
    return (*place);
  }
  return NULL;
}


void
bif_type_set (bif_type_t *bt, state_slot_t *ret, state_slot_t **params)
{
  if (!bt)
    return;
  if (bt->bt_func)
    {
      long dt, sc_ret, sc_prec;
      bt->bt_func (params, &dt, &sc_prec, &sc_ret, (caddr_t *) &ret->ssl_sqt.sqt_collation);
      ret->ssl_prec = (uint32) sc_prec;
      ret->ssl_scale = (char) sc_ret;
      ret->ssl_dtp = (dtp_t) dt;
    }
  else
    {
      ret->ssl_dtp = (dtp_t) bt->bt_dtp;
      ret->ssl_prec = bt->bt_prec;
      ret->ssl_scale = (char) bt->bt_scale;
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
  caddr_t arg = bif_arg (qst, args, 0, "length"); /* Was: bif_array_arg */
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
    return (box_num (len - 1));
  case DV_BIN:
  case DV_LONG_BIN:
#ifndef O12
  case DV_G_REF_CLASS:  /* Added by AK 21-FEB-1997. */
  case DV_G_REF:
#endif
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

caddr_t
bif_raw_length (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  long len = 0;
  caddr_t arg = bif_arg (qst, args, 0, "raw_length"); /* Was: bif_array_arg */
  dtp_t dtp = DV_TYPE_OF (arg);
  switch (dtp)
    {
    case DV_DB_NULL:
      return (box_num (0));
    case DV_BLOB_HANDLE:
    case DV_BLOB_WIDE_HANDLE:
      return box_num (((blob_handle_t *) arg)->bh_diskbytes);
#ifdef BIF_XML
    case DV_XML_ENTITY:
      if (XE_IS_PERSISTENT((xml_entity_t *)arg))
  return box_num (((xml_entity_t *) arg)->xe_doc.xpd->xpd_bh->bh_diskbytes);
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
    return (box_num (len - 1));
  case DV_WIDE:
  case DV_LONG_WIDE:
    return (box_num (len  - sizeof (wchar_t)));
  case DV_STRING_SESSION:
    return (box_num (strses_length ((dk_session_t *) arg)));
  case DV_COMPOSITE:
    return (box_num (box_length (arg) - 2));

  case DV_ARRAY_OF_POINTER:
  case DV_LIST_OF_POINTER:
  case DV_ARRAY_OF_XQVAL:
#ifndef O12
  case DV_G_REF_CLASS:
  case DV_G_REF:
#endif
  case DV_ARRAY_OF_LONG:
  case DV_ARRAY_OF_FLOAT:
  case DV_ARRAY_OF_DOUBLE:
  default:
    {
      return box_num(len);
    }
  }
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
      if (dtp == DV_SHORT_STRING || dtp == DV_LONG_STRING
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
bif_aref_set_0 (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t res;
  caddr_t arr = bif_array_arg (qst, args, 0, "aref_set_0");
  long inx = (long) bif_long_arg (qst, args, 1, "aref_set_0");
  if (DV_TYPE_OF (arr) != DV_ARRAY_OF_POINTER)
  sqlr_new_error ("22023", "SR018", "non-generic vector for aref_set_0");
  if (BOX_ELEMENTS (arr) <= ((uint32) inx) || inx < 0)
  sqlr_new_error ("22003", "SR019", "Bad subscript for aref_set_0");
  res = ((caddr_t*)arr)[inx];
  ((caddr_t*) arr)[inx] = NULL;
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
    sqlr_new_error ("22003", "SR020", "Argument %d of aset is a bad array subscript (value %ld exceedes array size).", idxcount+1, (long)inx);
  NO_CADDR_T;
}


/* Now returns back the modified array itself (given as a first argument)
   instead of the ascii value stored to place as before.
   I think this is more useful this way, at least when arr is a string.
   E.g. chr$(65) can be defined now as aset(make_string(1),0,65)
   (AK 15-JAN-1997) (Now defined internally. See bif_chr below.)
   I don't know what happens when the arr argument is some other kind
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
static dk_session_t *
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

  dtp_t dtp1 = DV_TYPE_OF (str);
  dtp_t dtp2 = DV_TYPE_OF (num_arg2);

  /* If the third argument is missing, then act like it were NULL: */
  dtp_t dtp3 = ((n_args > 2) ? DV_TYPE_OF (num_arg3) : DV_DB_NULL);
  int fail_in_dtp3 = 0;
  long len;
  caddr_t res;
  int sizeof_char = IS_WIDE_STRING_DTP (dtp1) ? sizeof (wchar_t) : sizeof (char);

  /* Return NULL if the first argument is NULL: */
  if (DV_DB_NULL == dtp1)
  {
    return (NEW_DB_NULL);
  }

  if (!is_some_sort_of_a_string (dtp1) && !IS_WIDE_STRING_DTP (dtp1) && !IS_BLOB_HANDLE_DTP (dtp1) && (DV_STRING_SESSION != dtp1) &&
    dtp1 != DV_ARRAY_OF_POINTER)
  {
    sqlr_new_error ("22023", "SR023",
    "Function subseq needs a string, array or object id as its first argument, "
    "not an arg of type %s (%d)",
    dv_type_title (dtp1), dtp1);
  }

  /* box_length returns a string length + 1, except with object id's */
  if (dtp1 == DV_ARRAY_OF_POINTER)
  len = BOX_ELEMENTS (str);
  else if (dtp1 == DV_STRING_SESSION)
  len = strses_length((dk_session_t *)str);
  else
#ifndef O12
  len = box_length (str) / sizeof_char - ((dtp1 != DV_G_REF_CLASS) ? 1 : 0);
#else
  len = box_length (str) / sizeof_char - 1;
#endif
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
  {
    return (caddr_t) strses_subseq ((dk_session_t *)str, from, to);
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
  res[(to - from) * sizeof_char] = 0;
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
  dtp_t dtp1 = DV_TYPE_OF (str);
  int sizeof_char = IS_WIDE_STRING_DTP (dtp1) ? sizeof (wchar_t) : sizeof (char);

  if (dtp1 == DV_DB_NULL)
    str = NULL;
  else if (dtp1 != DV_STRING && dtp1 != DV_C_STRING &&
      !IS_WIDE_STRING_DTP (dtp1) &&
      dtp1 != DV_BIN  && dtp1 != DV_LONG_BIN)
    sqlr_new_error ("22023", "SR007",
	"Function left needs a string or NULL or binary as argument 1, "
	"not an arg of type %s (%d)",
	dv_type_title (dtp1), dtp1);

  if (NULL == str)
  {
    return (NEW_DB_NULL);
  }

  len = (box_length (str) / sizeof_char - 1); /* box_length returns a length + 1 */

  to = MIN (to, len);

  res = dk_alloc_box ((to + 1) * sizeof_char, (dtp_t)(IS_WIDE_STRING_DTP (dtp1) ? DV_WIDE : DV_LONG_STRING));
  memcpy (res, str, to * sizeof_char);
  memset (res + to * sizeof_char, 0, sizeof_char);
  return res;
}


/* right(str,n) takes n last characters of str. */
caddr_t
bif_right (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t str = bif_string_or_wide_or_null_arg (qst, args, 0, "right");
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
  caddr_t skip_str = NULL; /*((n_args > 1)
			     ? bif_string_arg (qst, args, 1, "trim")
			     : (caddr_t) " "); */ /* If second arg is not present it's a space by default. */
  long len;
  long from;
  long to;
  char *from_ptr;
  caddr_t res;
  dtp_t dtp1 = DV_TYPE_OF (str);
  int sizeof_char = IS_WIDE_STRING_DTP (dtp1) ? sizeof (wchar_t) : sizeof (char);
  caddr_t to_free = NULL;

  if (NULL == str)
    {
      return (NEW_DB_NULL);
    }

  if (n_args > 1)
    {
      caddr_t x = bif_string_or_wide_or_null_arg (qst, args, 1, "trim");
      if (IS_WIDE_STRING_DTP (dtp1) && !DV_WIDESTRINGP (x))
	{
	  to_free = (caddr_t) box_narrow_string_as_wide ((unsigned char *) x, NULL, 0, QST_CHARSET (qst));
	  skip_str = to_free;
	}
      else if (!IS_WIDE_STRING_DTP (dtp1) && DV_WIDESTRINGP (x))
	{
	  to_free = box_wide_string_as_narrow (x, NULL, 0, QST_CHARSET (qst));
	  skip_str = to_free;
	}
      else
	{
	  skip_str = x;
	}
    }
  else
    {
      if (IS_WIDE_STRING_DTP (dtp1))
	{
	  skip_str = (caddr_t) L" ";
	}
      else
	{
	  skip_str = " ";
	}
    }

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
  query_instance_t *qi = (query_instance_t *)qst;
  int n_args = BOX_ELEMENTS (args), inx;
  int alen;
  caddr_t a;
  int len = 0, fill = 0;
  caddr_t res;
  int haveWides = 0;
  dtp_t dtp1;
  int sizeof_char = 1;

  /* First count the required length for a resulting string buffer. */
  for (inx = 0; inx < n_args; inx++)
  {
    a = bif_string_or_wide_or_null_arg (qst, args, inx, "concat");
    if (NULL == a)
  {
    continue;
  }     /* Skip NULL's */
    dtp1 = DV_TYPE_OF (a);
    if (IS_WIDE_STRING_DTP (dtp1))
  {
    haveWides = 1;
    len += box_length (a) / sizeof (wchar_t) - 1;
  }
    else
  len += box_length (a) - 1;
  }

  sizeof_char = haveWides ? sizeof (wchar_t) : sizeof (char);
  if (NULL == (res = dk_try_alloc_box ((len + 1) * sizeof_char, (dtp_t)(haveWides ? DV_WIDE : DV_LONG_STRING))))
    qi_signal_if_trx_error (qi);

  for (inx = 0; inx < n_args; inx++)
  {
    a = bif_string_or_wide_or_null_arg (qst, args, inx, "concat");
    if (NULL == a)
      continue;
    dtp1 = DV_TYPE_OF (a);
    if (!IS_WIDE_STRING_DTP (dtp1) && haveWides)
  {
    alen = box_length (a) - 1;
    box_narrow_string_as_wide ((unsigned char *) a, res + fill * sizeof_char, alen, QST_CHARSET (qst));
  }
    else
  {
    alen = box_length (a) / sizeof_char - 1;
    memcpy (res + fill * sizeof_char, a, alen * sizeof_char);
  }
    fill += alen;
  }
#ifdef DEBUG
  if (fill != len)
    GPF_T;
#endif
  memset (res + len * sizeof_char, 0, sizeof_char);
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

#ifndef _GNU_SOURCE
void *
memmem (const void *_haystack, size_t haystack_bytes, const void *_needle, size_t needle_bytes)
{
  const char *haystack = (const char *)_haystack;
  const char *needle = (const char *)_needle;
  while (haystack_bytes >= needle_bytes)
    {
      if (!memcmp(haystack,needle,needle_bytes))
	return (void *) haystack;
      haystack++; haystack_bytes--;
    }
  return NULL;
}
#endif

void *
memmem1 (const void *_haystack, size_t haystack_bytes, const void *_needle, size_t needle_bytes)
{
  const char *haystack = (const char *)_haystack;
  const char *needle = (const char *)_needle;
  char needle_0 = needle[0];
  while (haystack_bytes)
    {
      if (haystack[0] == needle_0)
	return (void *) haystack;
      haystack++; haystack_bytes--;
    }
  return NULL;
}

void *
widememmem (const void *_haystack, size_t haystack_bytes, const void *_needle, size_t needle_bytes)
{
  const wchar_t *haystack = (const wchar_t *)_haystack;
  const wchar_t *needle = (const wchar_t *)_needle;
  while (haystack_bytes >= needle_bytes)
    {
      if ((haystack[0] == needle[0]) && !memcmp(haystack,needle,needle_bytes))
	return (void *) haystack;
      haystack ++; haystack_bytes -= sizeof(wchar_t);
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
  int only_n, src_bytes, from_bytes, from_strlen, to_bytes, difference, occurrences;
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
  from_strlen = ((sizeof(wchar_t) == sizeof_char) ? 0 : (int) strlen (from_str));
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
sprintf_escaped_id (caddr_t str, char *out, dk_session_t *ses)
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
sprintf_escaped_str_literal (caddr_t str, char *out, dk_session_t *ses)
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
  char dest [SPRINTF_BUF_SPACE + SPRINTF_BUF_MARGIN + 1];
  dest[SPRINTF_BUF_SPACE] = '\0';
  if (is_id)
  sprintf_escaped_id (str, dest, NULL);
  else
  sprintf_escaped_str_literal (str, dest, NULL);
  if (dest[SPRINTF_BUF_SPACE])
  {
    GPF_T1 ("SQL sprintf buffer overflowed. "
    "sprintf of over 2000 characters caused this.");
  }
  return box_dv_short_string (dest);
}


caddr_t
bif_sprintf (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  static char *szMe = "sprintf";
  dk_session_t *ses = strses_allocate ();
  char tmp[SPRINTF_BUF_SPACE + SPRINTF_BUF_MARGIN + 1];
  char format [100];
  char * volatile ptr;
  char * volatile start;
  char buf[100];
  char *bufptr;
  caddr_t str = bif_string_arg (qst, args, 0, szMe);
  int volatile len = box_length (str) - 1;
  int volatile arg_inx = 1;
  int arg_len, arg_prec;

  ptr = str;
  *err_ret = NULL;
  QR_RESET_CTX
    {
      while (!*err_ret && len && ptr && *ptr)
	{
	  start = strchr (ptr, '%');

	  if (!start)
	    { /* write the reminder */
	      session_buffered_write (ses, ptr, len);
	      ptr += len;
	      len = 0;
	    }
	  else
	    {
	      if (start - ptr)
		{ /* write the constant part before the % if any */
		  session_buffered_write (ses, ptr, start - ptr);
		  len -= (int) (start - ptr);
		}
	      ptr = start + 1;
	      if (ptr && *ptr == '%') /* double % */
		session_buffered_write_char (*ptr, ses);
	      else
		{ /* a real format specifier */
		  if (arg_inx >= BOX_ELEMENTS_INT(args))
		    sqlr_new_error ("22026", "SR352",
			"Not enough arguments (only %lu) for sprintf to match format '%s'",
			(unsigned long)BOX_ELEMENTS(args), str);
		  arg_len = arg_prec = 0;
		  /* skip the modifier */
		  while (ptr && *ptr && strchr ("#0- +'", *ptr))
		    ptr++;

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
		      ptr++; /* skip the dot */
		      while (ptr && *ptr && strchr ("0123456789", *ptr))
			{
			  if (bufptr - buf < sizeof (buf))
			    *bufptr++ = *ptr;
			  ptr++;
			}
		      *bufptr = 0;
		      arg_prec = atoi (buf);
		    }

		  /* skip the size modifier */
		  if (ptr && *ptr && strchr ("hlLq", *ptr))
		    ptr++;

		  if (!ptr || !*ptr || !strchr ("diouxXeEfgcsSIVU", *ptr))
		    {
		      sqlr_new_error ("22023", "SR031",
			  "Invalid format string for sprintf at escape %d", arg_inx);
		    }
		  memset (format, 0, sizeof (format));
		  memcpy (format, start, MIN (ptr - start + 1, sizeof (format) - 1));

		  if (arg_len > SPRINTF_BUF_SPACE)
		    {
		      sqlr_new_error ("22026", "SR032",
			  "sprintf escape %d (%s) exceeds the internal buffer of %d",
			  arg_inx, format, SPRINTF_BUF_SPACE);
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
			    snprintf (tmp, SPRINTF_BUF_SPACE,
				format, (short) bif_long_arg (qst, args, arg_inx++, szMe));
			  else if (ptr[-1] == 'l')
			    snprintf (tmp, SPRINTF_BUF_SPACE,
				format, bif_long_arg (qst, args, arg_inx++, szMe));
			  else
			    snprintf (tmp, SPRINTF_BUF_SPACE,
				format, (int)bif_long_arg (qst, args, arg_inx++, szMe));
			  break;

		      case 'e':
		      case 'E':
		      case 'f':
		      case 'g':
			  if (ptr[-1] == 'L' || ptr[-1] == 'q')
			    snprintf (tmp, SPRINTF_BUF_SPACE,
				format, (long double) bif_double_arg (qst, args, arg_inx++, szMe));
			  else
			    snprintf (tmp, SPRINTF_BUF_SPACE,
				format, bif_double_arg (qst, args, arg_inx++, szMe));
			  break;

		      case 'c':
			  snprintf (tmp, SPRINTF_BUF_SPACE,
			      format, (int) bif_long_arg (qst, args, arg_inx++, szMe));
			  break;

		      case 's':
			    {
			      caddr_t arg = bif_string_or_wide_or_null_arg (qst, args, arg_inx++, szMe);
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
					  "The length of the data for sprintf argument %d exceed the maximum of %d",
					  arg_inx - 1, SPRINTF_BUF_SPACE);
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

		      case 'S':
			    {
			      caddr_t arg = bif_string_or_wide_or_null_arg (qst, args, arg_inx++, szMe);
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
					  "The length of the data for sprintf argument %d exceed the maximum of %d",
					  arg_inx - 1, SPRINTF_BUF_SPACE);
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
			      caddr_t arg = bif_string_or_wide_or_null_arg (qst, args, arg_inx++, szMe);
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
					  "The length of the data for sprintf argument %d exceed the maximum of %d",
					  arg_inx - 1, SPRINTF_BUF_SPACE);
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
			      caddr_t arg = bif_string_or_wide_or_null_arg (qst, args, arg_inx++, szMe);
			      caddr_t narrow_arg = NULL;
			      if (DV_WIDESTRINGP (arg))
				arg = narrow_arg = box_wide_string_as_narrow (arg, NULL, 0, NULL);
			      else if (!arg)
				arg = narrow_arg = box_dv_short_string ("(NULL)");
			      if (arg_len || arg_prec)
				{
				  if (narrow_arg)
				    dk_free_box (narrow_arg);
				  sqlr_new_error ("22025", "SR036",
				      "The URL escaping sprintf escape %d doesn't support modifiers",
				      arg_inx - 1);
				}
			      else
				{
				  http_value_esc (qst, ses, arg, NULL, DKS_ESC_URI);
				  if (narrow_arg)
				    dk_free_box (narrow_arg);
				  goto get_next;
				}
			    }
			  break;

		      case 'V':
			    {
			      caddr_t arg = bif_string_or_wide_or_null_arg (qst, args, arg_inx++, szMe);
			      caddr_t narrow_arg = NULL;
			      if (!arg)
				arg = narrow_arg = box_dv_short_string ("(NULL)");
			      if (arg_len || arg_prec)
				{
				  if (narrow_arg)
				    dk_free_box (narrow_arg);
				  sqlr_new_error ("22025", "SR037",
				      "The HTTP escaping sprintf escape %d doesn't support modifiers",
				      arg_inx - 1);
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

		      default:
			  sqlr_new_error ("22023", "SR038", "Invalid format string for sprintf: '%.1000s'", str);
		    }

		  if (tmp[SPRINTF_BUF_SPACE]) /* Was: (strlen (tmp) > sizeof (tmp) - 1) */
		    {
		      GPF_T1 ("SQL sprintf buffer overflowed. "
			  "sprintf of over 2000 characters caused this.");
		    }
		  session_buffered_write (ses, tmp, strlen (tmp));
		}
get_next:
	      ptr++;
	      len -= (int) (ptr - start);
	    }
	}
    }
  QR_RESET_CODE
    {
      caddr_t err = thr_get_error_code (((query_instance_t *)qst)->qi_thread);
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
  caddr_t str = bif_string_or_wide_or_null_arg (qst, args, 0, "strchr");
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
  caddr_t str = bif_string_or_wide_or_null_arg (qst, args, 0, "strrchr");
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


caddr_t
bif_strstr (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t str1 = bif_string_or_wide_or_null_arg (qst, args, 0, "strstr");
  caddr_t str2 = bif_string_or_wide_or_null_arg (qst, args, 1, "strstr");
  char *inx;
  dtp_t dtp1 = DV_TYPE_OF (str1);
  dtp_t dtp2 = DV_TYPE_OF (str2);
  int sizeof_char =
    (IS_WIDE_STRING_DTP (dtp1) || IS_WIDE_STRING_DTP (dtp2)) ?
    sizeof (wchar_t) :
    sizeof (char);

  if ((NULL == str1) || (NULL == str2))
  {
    return (NEW_DB_NULL);
  }

  if (sizeof_char == sizeof (wchar_t))
  {
    if (!IS_WIDE_STRING_DTP (dtp1))
  sqlr_new_error ("22023", "SR039", "The first argument to strstr is not a wide string");
    if (!IS_WIDE_STRING_DTP (dtp2))
  sqlr_new_error ("22023", "SR040", "The second argument to strstr is not a wide string");
    inx = (char *)virt_wcsstr ((wchar_t *)str1, (wchar_t *)str2);
  }
  else
  inx = strstr (str1, str2);
  if (!inx)
  {
    /* 0 or 1 ??? Not so good idea. Where this is free'ed??? */
    return (NEW_DB_NULL);
  }
  else
  {
    return (box_num ((inx - str1) / sizeof_char));
  }
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
  caddr_t str1 = bif_string_arg (qst, args, 0, "casemode_strcmp");
  caddr_t str2 = bif_string_arg (qst, args, 1, "casemode_strcmp");
  return box_num (CASEMODESTRCMP (str1, str2));
}


static caddr_t
bif_fix_identifier_case (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t ident = bif_string_arg (qst, args, 0, "fix_identifier_case");
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
  caddr_t str1 = bif_string_or_wide_or_null_arg (qst, args, 0, me);
  caddr_t str2 = bif_string_or_wide_or_null_arg (qst, args, 1, me);
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
   or 0, if they don't match. Uses cmp_like function defined in the
   module string.c
   String2 can be prefixed with the same special characters '%%', '**'
   or one or more @'s, to get the same special effects as with LIKE. */
caddr_t
bif_matches_like (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int st = LIKE_ARG_CHAR, pt = LIKE_ARG_CHAR;
  caddr_t str1 = bif_string_or_wide_or_null_arg (qst, args, 0, "matches_like");
  caddr_t str2 = bif_string_or_wide_or_null_arg (qst, args, 1, "matches_like");
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
bif_like_min (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int len;
  caddr_t res;
  caddr_t str = bif_string_or_null_arg (qst, args, 0, "__like_min");
  char * ctr;
  if (!str)
    return dk_alloc_box (0, DV_DB_NULL);
  ctr = strpbrk (str, "%_*[]");
  if (!ctr)
    return box_copy (str);
  len = ctr - str;
  res = dk_alloc_box (1+len, DV_STRING);
  memcpy (res, str, len);
  res[len] = 0;
  return res;
}


caddr_t
bif_like_max (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int len;
  caddr_t res;
  caddr_t str = bif_string_or_null_arg (qst, args, 0, "__like_min");
  char * ctr;
  if (!str)
    return dk_alloc_box (0, DV_DB_NULL);
  ctr = strpbrk (str, "%_*[]");
  if (!ctr)
    return (box_copy (str));
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
      return res;
    }
  else
    {
      res = dk_alloc_box (1+len, DV_STRING);
      memcpy (res, str, len);
      res[len-1]++;
      res[len] = 0;
      return res;
    }
}


/* ascii(str) is equal to aref(str,0) when argument is a string. */
caddr_t
bif_ascii (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg = bif_arg (qst, args, 0, "ascii");
  dtp_t dtp = DV_TYPE_OF (arg);

  /* if(DV_DB_NULL == dtp) { return(box_num(0)); } */

  switch (dtp)
  {
#ifndef O12
  case DV_G_REF_CLASS:
  case DV_G_REF:
#endif
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

   I don't know about AIX, but I could guess that its native isalpha,
   etc. macros, using ctp, or whatever table, could be configurable,
   maybe even in run-time, with some SET LOCALITY option from the
   operating system. I don't know, have to check that.
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
  caddr_t str = bif_string_or_wide_or_null_arg (qst, args, 0, "lcase");
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
  caddr_t str = bif_string_or_wide_or_null_arg (qst, args, 0, "ucase");
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
   integers, so we don't need to include sqlcli.h or sql.h or sqlext.h
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
#ifndef O12
  case DV_G_REF_CLASS: /* 205 */
  case DV_G_REF: /* 206 */
#endif
  case DV_BLOB_HEAD: /* 207 */
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
    GPF_T1 ("table allready defined as system table"); \
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


caddr_t
bif_isstring (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg0 = bif_arg (qst, args, 0, "isstring");
  return box_bool (DV_STRING == DV_TYPE_OF (arg0));
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
  caddr_t first = bif_arg (qst, args, 0, "__max");
  for (inx = 1; inx < BOX_ELEMENTS_INT (args); inx++)
  {
    collation_t * coll = args[0]->ssl_sqt.sqt_collation;
    caddr_t a = bif_arg (qst, args, inx, "__max");
    if (DVC_GREATER == cmp_boxes (a, first, coll, coll))
  first = a;
  }
  return (box_copy_tree (first));
}


caddr_t
bif_min (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int inx;
  caddr_t first = bif_arg (qst, args, 0, "__min");
  for (inx = 1; inx < BOX_ELEMENTS_INT (args); inx++)
  {
    collation_t * coll = args[0]->ssl_sqt.sqt_collation;
    caddr_t a = bif_arg (qst, args, inx, "__min");
    if (DVC_LESS == cmp_boxes (a, first, coll, coll))
  first = a;
  }
  return (box_copy_tree (first));
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
  caddr_t arg = bif_arg (qst, args, 0, "abs");
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
  double x = bif_double_arg (qst, args, 0, NAMESTR);\
  return(box_double(OPERATION));\
}


bif_type_t bt_double = {NULL, DV_DOUBLE_FLOAT, 0, 0};
bif_type_t bt_float = {NULL, DV_SINGLE_FLOAT, 0, 0};
bif_type_t bt_numeric = {NULL, DV_NUMERIC, 40, 20};

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

#define GENERAL_DOUBLE2_FUNC(BIF_NAME, NAMESTR, OPERATION)\
caddr_t BIF_NAME (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)\
{\
  double x = bif_double_arg (qst, args, 0, NAMESTR);\
  double y = bif_double_arg (qst, args, 1, NAMESTR);\
  return (box_double(OPERATION));\
}

GENERAL_DOUBLE2_FUNC (bif_atan2, "atan2", atan2 (x, y))
GENERAL_DOUBLE2_FUNC (bif_power, "power", pow (x, y))

#define GENERAL_DOUBLE_TO_INT_FUNC(BIF_NAME, NAMESTR, OPERATION)\
caddr_t BIF_NAME (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)\
{\
  double x = bif_double_arg (qst, args, 0, NAMESTR);\
  return(box_num(((long int)(OPERATION))));\
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
    seed[0] += RNG_M;

  return seed[0];
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
      int permit = 0;
      if (pwd_magic_users != (dk_set_t) 1)
  {
    DO_SET (caddr_t, un, &pwd_magic_users)
      {
        if (!strcmp (un, uname))
    {
      permit = 1;
      nxt = NULL;
    }
      }
    END_DO_SET();
  }
      if (!permit)
  sqlr_new_error ("42000", "SR343",
      "Access to pwd_magic_calc not permitted."
      "If you are getting this message in the Admin interface and you are a DBA,"
      "then you need to enable the function from the INI file in order to use it.");
    }

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
  char *name = bif_string_or_null_arg (qst, args, 0, "disconnect");
  dk_session_t *this_client_ses = IMMEDIATE_CLIENT;
  query_instance_t * qi = (query_instance_t *) qst;
  long disconnected_users = 0;
  dk_set_t users;

  IN_TXN;
  mutex_enter (thread_mtx);
  users = srv_get_logons ();
  DO_SET (dk_session_t *, ses, &users)
    {
      if (name || ses != this_client_ses)
	{
	  client_connection_t *cli = DKS_DB_DATA (ses);
	  if (cli &&    /* A missing check added by AK 23-FEB-1997 */
	      (!name ||
	       (cli->cli_user && (DVC_MATCH == cmp_like (cli->cli_user->usr_name, name, NULL, 0,
							 LIKE_ARG_CHAR, LIKE_ARG_CHAR))))
	     )
	    {
	      ASSERT_IN_TXN;
	      DO_SET (lock_trx_t *, lt, &all_trxs)
		{
		  if (lt->lt_client == cli)
		    if (lt != qi->qi_trx &&
			lt->lt_status == LT_PENDING
			&& (lt->lt_threads > 0 || lt->lt_locks))
		      {
			LT_ERROR_DETAIL_SET (lt,
			    box_dv_short_string ("DBA forced disconnect"));
			lt->lt_error  = LTE_SQL_ERROR;
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
  caddr_t file = bif_string_arg (qst, args, 0, "backup");
  sec_check_dba ((query_instance_t *) qst, "backup");
  if (!is_allowed (file))
  sqlr_new_error ("42000", "FA001", "Access to %s is denied", file);
  db_backup ((query_instance_t *) QST_INSTANCE (qst), file);
  return 0;
}


caddr_t
bif_check (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  sec_check_dba ((query_instance_t *) qst, "check");
  db_check ((query_instance_t *) QST_INSTANCE (qst));
  return 0;
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

#ifndef O12
caddr_t
bif_make_oid (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t str = bif_string_arg (qst, args, 0, "make_oid");
  long cid = bif_long_arg (qst, args, 1, "make_oid");
  int slen = box_length (str);
  caddr_t res = dk_alloc_box (slen + 4 - 1, DV_G_REF_CLASS);
  memcpy (res, str, slen - 1);
  LONG_SET (res + slen - 1, cid);
  return res;
}
/* The above bug of long_setting the wrong variable corrected,
   as well as this new function, which returns the class specified
   number of the object id,
   by AK 22-FEB-1997. */
caddr_t
bif_oid_class_spec (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg = bif_arg (qst, args, 0, "oid_class_spec");
  int slen;
  dtp_t dtp;
  long classnum;

  if (DV_G_REF_CLASS != (dtp = DV_TYPE_OF (arg)))
  {
    sqlr_new_error ("22023", "SR054",
    "Function oid_class_spec needs an object id as its argument, "
    "not an argument of type %s (%d)",
    dv_type_title (dtp), dtp);
  }

  slen = box_length (arg);
  if (slen < 4)
  {
    sqlr_new_error ("22023", "SR055",
    "Function oid_class_spec detected an object id whose length %d < 4. "
    "oid[0]=%u. oid[1]=%u. oid[2]=%u. ",
    slen, (((unsigned char *) arg)[0]),
    (((unsigned char *) arg)[1]),
    (((unsigned char *) arg)[2]));
  }

  classnum = LONG_REF (arg + slen - 4);   /* Take the four last bytes. */
  return (box_num (classnum));
}
#endif

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
   split_and_decode("Tulipas=Taloon+kumi=kala&Joka=haisi+pahalle&kuin&%E4lymystöporkkana=ilman ruuvausta",1)
   produces a vector:
   ("TULIPAS" "Taloon kumi=kala" "JOKA" "haisi pahalle" "KUIN" NULL
   "ÄLYMYSTÖPORKKANA" "ilman ruuvausta")

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
   =>  "=?ISO-8859-1?Q?Tiira lentää taas?="

   split_and_decode('Message-Id: <199511141036.LAA06462@correo.unet.ar>\nFrom: "=?ISO-8859-1?Q?Jorge_Mo=F1as?=" <jorgem@unet.ar>\nTo: "Jore Carvajal" <carvajal@wanabee.fr>\nSubject: RE: Um-pah-pah\nDate: Wed, 12 Nov 1997 11:28:51 +0100\nX-MSMail-Priority: Normal\nX-Priority: 3\nX-Mailer: Molosoft Internet Mail 4.70.1161\nMIME-Version: 1.0\nContent-Type: text/plain; charset=ISO-8859-1\nContent-Transfer-Encoding: 8bit\nX-Mozilla-Status: 0011',
   1,'=_\n:');
   => ('MESSAGE-ID' ' <199511141036.LAA06462@correo.unet.ar>'
   'FROM' ' "=?ISO-8859-1?Q?Jorge Moñas?=" <jorgem@unet.ar>'
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
   'FROM:' '"=?ISO-8859-1?Q?Jorge Moñas?=" <jorgem@unet.ar>'
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

   Of course this approach doesn't work with multiline headers, except
   somewhat kludgeously.
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
  char *ptr, *end_ptr, *item_start;

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

  end_ptr = (inputs + inputs_len);

  /* First count the number of occurrences of ampersands in inputs */
  {
  occurrences = 1;    /* Always at least one element. */
  ptr = inputs;
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
  ptr = inputs;
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
    res[inx] = box_copy_tree (bif_arg (qst, args, inx, "vector"));
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

/* Could be also: box_equal((X),(Y)) except that it doesn't work so well. */

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
   from vector vec (which can be an ordinary heterogenous vector
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
  dtp_t vectype, int start, int skip_value, char *calling_fun)
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
  item = ((caddr_t) unbox (item));
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
  case DV_STRING:
    {
  /* if item is a string, then use its first character
    (which could be a terminating zero if string is empty),
    otherwise it must be an integer, which should be an unsigned
    ascii value of the character. */
  if ((DV_SHORT_STRING == item_type) || (DV_LONG_STRING == item_type))
    {
    item = ((caddr_t) (ptrlong) *((unsigned char *) item));
    }
  else if ((item_type == DV_SHORT_INT) || (item_type == DV_LONG_INT))
    {
    item = ((caddr_t) unbox (item));
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
   So if get_keyword(item,vector) doesn't find item from vector,
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
  caddr_t arr = (caddr_t) bif_array_arg (qst, args, 1, me);
  long is_set_0 = (long) ((n_args > 3) ? bif_long_arg (qst, args, 3, me) : 0);
  int inx;
  dtp_t vectype = DV_TYPE_OF (arr);
  int boxlen = (is_string_type (vectype)
    ? box_length (arr) - 1
    : box_length (arr));
  int len = (boxlen / get_itemsize_of_vector (vectype));
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
get_keyword_int (caddr_t * arr, char * item1, char * me)
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
bif_get_keyword_ucase (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char *me = "get_keyword_ucase";
  int n_args = BOX_ELEMENTS (args);
  caddr_t item = bif_string_arg (qst, args, 0, me);
  caddr_t arr = (caddr_t) bif_array_arg (qst, args, 1, me);
  long is_set_0 = (long) ((n_args > 3) ? bif_long_arg (qst, args, 3, me) : 0);
  int inx;
  dtp_t vectype = DV_TYPE_OF (arr);
  int len = BOX_ELEMENTS (arr);

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
  int n_args = BOX_ELEMENTS (args);
  caddr_t item = bif_arg (qst, args, 0, me);
  dtp_t item_dtp = DV_TYPE_OF (item);
  int inx;
  caddr_t value;
  dtp_t val_dtp;
  int they_match;

  for (inx = 1; inx < n_args; inx++)
  {
    value = qst_get (qst, args[inx]);
    val_dtp = DV_TYPE_OF (value);
    if (IS_WIDE_STRING_DTP (item_dtp) && IS_STRING_DTP (val_dtp))
  {
    caddr_t wide = box_narrow_string_as_wide ((unsigned char *) value, NULL, 0, QST_CHARSET (qst));
    they_match = boxes_match (item, wide);
    dk_free_box (wide);
  }
    else if (IS_STRING_DTP (item_dtp) && IS_WIDE_STRING_DTP (val_dtp))
  {
    caddr_t wide = box_narrow_string_as_wide ((unsigned char *) item, NULL, 0, QST_CHARSET (qst));
    they_match = boxes_match (wide, value);
    dk_free_box (wide);
  }
    else
    they_match = boxes_match (item, value);
    if (they_match)
  return (box_num (inx));
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
      ref_itc.itc_row_key_id = key->key_id;
      cl = key_find_cl (key, col->col_id);
    }
  else
    {
      cl = cl_list_find (key->key_key_fixed, col->col_id);
      if (!cl)
  cl = cl_list_find (key->key_key_var, col->col_id);
      ref_itc.itc_row_key_id = 0;
    }
  if (!cl)
    return NEW_DB_NULL;
  *exists = 1;
  val = itc_box_column (&ref_itc, str, col->col_id, cl);
  return val;
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
  it_cursor_t ref_itc, *itc = &ref_itc;
  dbe_col_loc_t * cl;
  int len;
  db_buf_t row_data;
  dbe_schema_t *sc = wi_inst.wi_schema;
  key_id_t key_id = SHORT_REF (row + IE_KEY_ID);
  dbe_key_t * key = key_id ? sch_id_to_key (sc, key_id) : NULL;
  dtp_t image[PAGE_DATA_SZ];
  db_buf_t res = &image[0];
  int inx = 0, prev_end;
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
      itc->itc_row_key_id = key_id;
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
      ITC_LEAVE_MAP (ref_itc);
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
		      itc_create (ref_itc->itc_space, ref_itc->itc_ltrx);
		  caddr_t row = deref_node_main_row ((ITC) ref_itc, &ref_buf,
		      cr_key->key_table->tb_primary_key, main_itc);
		  ITC_LEAVE_MAP (main_itc);
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
	      NEW_VAR (placeholder_t, pl);
	      ITC_IN_MAP (ref_itc);
	      memcpy (pl, (ITC) ref_itc, ITC_PLACEHOLDER_BYTES);
	      pl->itc_type = ITC_PLACEHOLDER;
	      itc_register_cursor ((it_cursor_t *) pl, INSIDE_MAP);
	      *place_ret = pl;
	    }
	}
      ITC_FAIL (ref_itc)
	{
	  /* make new fail ctx because ref_itc may have been set above */
	  itc_page_leave ((ITC) ref_itc, ref_buf);
	}
      ITC_FAILED
	{
	  itc_free ((ITC) ref_itc);
	  ref_itc = NULL;
	}
      END_FAIL (((ITC) ref_itc));
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
  long volatile dp = (long) bif_long_arg (qst, args, 0, "page_dump");
  buffer_desc_t buf_auto;
  unsigned char bd_buffer[PAGE_SZ];
  buffer_desc_t *buf = NULL;
  it_cursor_t itc_auto, *itc = &itc_auto;

  memset (&itc_auto, 0, sizeof (itc_auto));

  DO_SET (index_tree_t *, it, &wi_inst.wi_master->dbs_trees)
    {
      itc->itc_tree = it;
      ITC_IN_MAP (itc);
      buf = (buffer_desc_t *) gethash (DP_ADDR2VOID (dp), it->it_commit_space->isp_dp_to_buf);
      if (!buf)
	buf = (buffer_desc_t *) gethash (DP_ADDR2VOID (dp), it->it_checkpoint_space->isp_dp_to_buf);
      if (buf)
	{
	  dbg_page_map (buf);
	  ITC_LEAVE_MAP(itc);
	  return 0;
	}
      ITC_LEAVE_MAP(itc);
    }
  END_DO_SET();

  buf = &buf_auto;
  memset (&buf_auto, 0, sizeof (buf_auto));
  buf->bd_buffer = &bd_buffer[0];
  buf->bd_page = buf->bd_physical_page = dp;
  buf->bd_storage = wi_inst.wi_master;
  if (WI_ERROR == buf_disk_read (buf))
    {
      sqlr_new_error ("42000", "SR459", "Error reading page %ld", dp);
    }
  else
    dbg_page_map (buf);

  if (buf->bd_content_map)
    resource_store (PM_RC (buf->bd_content_map->pm_size), (void*) buf->bd_content_map);
  return 0;
}


caddr_t
bif_corrupt_page (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  O12;
#ifndef O12

  long volatile dp = bif_long_arg (qst, args, 0, "corrupt_page");
  long volatile offset = bif_long_arg (qst, args, 1, "corrupt_page");
  unsigned char volatile crap = 0xFF;
  long volatile craplength = 1, i;
  buffer_desc_t *buf;
  query_instance_t *qi = (query_instance_t *) QST_INSTANCE (qst);
  it_cursor_t *it = itc_create (qi->qi_space, qi->qi_trx);

  if (BOX_ELEMENTS (args) > 2)
  crap = (unsigned char) bif_long_arg (qst, args, 2, "corrupt_page");
  if (BOX_ELEMENTS (args) > 3)
  craplength = bif_long_arg (qst, args, 3, "corrupt_page");
  it->itc_page = dp;
  ITC_FAIL (it)
  {
  do
    {
  ITC_IN_MAP (it);
  page_wait_access (it, dp, NULL, NULL, &buf, PA_READ, RWG_WAIT_SPLIT);
    }
  while (!buf);
  if (offset + craplength  >= PAGE_SZ)
    offset = PAGE_SZ - craplength;
  for (i = offset; i < offset + craplength; i++)
    buf->bd_buffer[i] = crap;
  buf_set_dirty(buf);
  itc_page_leave (it, buf);
  ITC_LEAVE_MAP (it);
  }
  ITC_FAILED
  {
  }
  END_FAIL (it);
  itc_free (it);
#endif
  return 0;
}

caddr_t
bif_mem_enter_reserve_mode (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
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

caddr_t bif_mem_get_current_total (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return box_num (dbg_malloc_get_current_total());
}
#endif


#ifdef MALLOC_STRESS
caddr_t bif_set_hard_memlimit (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  ptrlong consumption = bif_long_arg (qst, args, 0, "set_hard_memlimit");
  dbg_malloc_set_hard_memlimit ((size_t)consumption);
  return box_num (consumption);
}

caddr_t bif_set_hit_memlimit (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t name = bif_string_arg (qst, args, 0, "set_hit_memlimit");
  ptrlong consumption = bif_long_arg (qst, args, 1, "set_hit_memlimit");
  dbg_malloc_set_hit_memlimit (box_uname_string(name), consumption);
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

long
num_check_prec (long val, int prec, char *title, caddr_t *err_ret)
{
  if (prec)
    {
      long v1 = val;
      int prec_save = prec;
      while (prec--)
  v1 /= 10;
      if (v1)
  {
    caddr_t err =
        srv_make_new_error ("22023", "SR346",
      "precision (%d) overflow in %s",
      prec_save, title);
    if (err_ret)
      *err_ret = err;
    else
      sqlr_resignal (err);
    return 0;
  }
    }
  return val;
}

caddr_t
box_cast (caddr_t * qst, caddr_t data, ST * dtp, dtp_t arg_dtp)
{
  if (arg_dtp == DV_DB_NULL)
    return (dk_alloc_box (0, DV_DB_NULL));
  if (!ARRAYP (dtp) || 0 == BOX_ELEMENTS (dtp))
    sqlr_new_error ("22023", "SR066", "Unsupported case in CONVERT (%s -> <unknown type>)", dv_type_title(arg_dtp));
  switch (dtp->type)
    {
      case DV_STRING: goto do_long_string;
      case DV_LONG_INT: case DV_SHORT_INT: goto do_long_int;
      case DV_SINGLE_FLOAT: goto do_single_float;
      case DV_DOUBLE_FLOAT: goto do_double_float;
      case DV_NUMERIC: goto do_numeric;
      case DV_DATETIME: case DV_DATE: case DV_TIMESTAMP: goto do_datetime;
      case DV_BIN: case DV_LONG_BIN: goto do_bin;
      case DV_TIME: goto do_time;
      case DV_WIDE: case DV_LONG_WIDE: goto do_wide;
      case DV_ANY: goto do_any;
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
	      snprintf (tmp, sizeof (tmp), "%ld", unbox (data));
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
	      return box_dv_short_nchars (data, box_length (data)-1);
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
		      caddr_t err = NULL, ret1;

		      ret1 = box_cast_to (qst, ret, DV_TYPE_OF (ret), DV_SHORT_STRING,
			  NUMERIC_MAX_PRECISION, NUMERIC_MAX_SCALE, &err);

		      dk_free_box (ret);
		      if (err)
			sqlr_resignal (ret);
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
		      caddr_t err = thr_get_error_code (self);
		      POP_QR_RESET;
		      dk_free_tree ((box_t) subresults);
		      sqlr_resignal (err);
		    }
		  END_QR_RESET;
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
	  default:
	      goto cvt_error;
	}
      return (box_dv_short_string (tmp));
    }

do_long_int:
    {
      int prec = BOX_ELEMENTS (dtp) > 1 ? (int) (unbox (((caddr_t *) dtp)[1])) : 0;
      long val;
      switch (arg_dtp)
	{
	  case DV_LONG_INT:
	  case DV_SHORT_INT:
	      val = (long) unbox (data); break;
	  case DV_SINGLE_FLOAT:
	      val = (long) unbox_float (data); break;
	  case DV_DOUBLE_FLOAT:
	      val = (long) unbox_double (data); break;
	  case DV_STRING:
	      val = safe_atoi (data, NULL); break;
#ifdef BIF_XML
	  case DV_XML_ENTITY:
		{
		  caddr_t tmp_res = NULL;
		  caddr_t err = NULL;
		  xe_sqlnarrow_string_value ((xml_entity_t *)(data), &tmp_res, DV_LONG_STRING);
		  val = safe_atoi (tmp_res, &err);
		  dk_free_box (tmp_res);
		  if (NULL != err)
		    sqlr_resignal (err);
		  break;
		}
#endif
	  case DV_NUMERIC:
		{
		  int32 i;
		  NUMCK (numeric_to_int32 ((numeric_t) data, &i));
		  val = i;
		  break;
		}
	  case DV_WIDE:
	  case DV_LONG_WIDE:
		{
		  char narrow [512];
		  box_wide_string_as_narrow (data, narrow, 512, qst ? QST_CHARSET (qst) : NULL);
		  val = safe_atoi (narrow, NULL);
		  break;
		}
	  default:
	      goto cvt_error;
	}
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
	      return (box_float ((float) safe_atof (data, NULL)));
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
		  box_wide_string_as_narrow (data, narrow, 512, qst ? QST_CHARSET (qst) : NULL);
		  return (box_float ((float) safe_atof (narrow, NULL)));
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
		  sscanf (data, "%lf", &d);
		  return (box_double (d));
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
		  box_wide_string_as_narrow (data, narrow, 512, qst ? QST_CHARSET (qst) : NULL);
		  return (box_double (atof (narrow)));
		}
	  default:
	      goto cvt_error;
	}
    }

do_numeric:
    {
      numeric_t res = numeric_allocate ();
      caddr_t err;
      err = numeric_from_x (res, data, (int) unbox (((caddr_t*)dtp)[1]), (int) unbox (((caddr_t*)dtp)[2]), "CAST", 0, NULL);
      if (err)
	{
	  numeric_free (res);
	  sqlr_resignal (err);
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
	  case DV_DATETIME:
	  case DV_DATE:
	  case DV_TIME:
	      res = box_copy_tree (data);
	      SET_DT_TYPE_BY_DTP (res, dtp->type);
	      return res;
	  case DV_BIN:
	      if (dt_validate (data))
		sqlr_new_error ("22003", "SR351",
		    "Invalid data supplied in VARBINARY -> DATETIME conversion");
	      res = box_copy (data);
	      box_tag_modify (res, DV_DATETIME);
	      return res;
	  case DV_WIDE:
	  case DV_LONG_WIDE:
		{
		  caddr_t narrow = box_wide_string_as_narrow (data, NULL, 0, qst ? QST_CHARSET (qst) : NULL);
		  res = string_to_dt_box (narrow);
		  dk_free_box (narrow);
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

	  default:
	      goto cvt_error;
	}
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
      switch (arg_dtp)
	{
	  case DV_STRING:
	      return box_narrow_string_as_wide ((unsigned char *) data, NULL, 0, qst ? QST_CHARSET (qst) : NULL);
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
	      snprintf (tmp, sizeof (tmp), "%ld", unbox (data));
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
			  NULL, 0, qst ? QST_CHARSET (qst) : NULL);
		      dk_free_box (ret);
		      return wide_ret;
		    }
		  return ret;
		}

	  default:
	      goto cvt_error;
	}
      return box_narrow_string_as_wide ((unsigned char *) tmp, NULL, 0, qst ? QST_CHARSET (qst) : NULL);
    }


cvt_error:
  sqlr_new_error ("22023", "SR066", "Unsupported case in CONVERT (%s -> %s)", dv_type_title(arg_dtp), dv_type_title((int) (dtp->type)));
  NO_CADDR_T;
}

caddr_t
box_cast_to (caddr_t *qst, caddr_t data, dtp_t data_dtp,
    dtp_t to_dtp, ptrlong prec, ptrlong scale, caddr_t *err_ret)
{
  sql_tree_tmp *proposed = (sql_tree_tmp *) list (3, to_dtp, box_num (prec), box_num (scale));
  caddr_t volatile string_value = NULL;

  QR_RESET_CTX
    {
      string_value = box_cast (qst, data, proposed, data_dtp);
    }
  QR_RESET_CODE
    {
      caddr_t err;
      POP_QR_RESET;
      dk_free_tree ((box_t) proposed);
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
  dk_free_tree ((box_t) proposed);
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
  ST * dtp_st = (ST *) bif_arg (qst, args, 1, "cast_internal");
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
bif_blob_to_string (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) QST_INSTANCE (qst);
  caddr_t bh = bif_arg (qst, args, 0, "blob_to_string");
  caddr_t res;
  long use_temp = 0;

  dtp_t dtp = DV_TYPE_OF (bh);

  if (BOX_ELEMENTS (args) > 1)
    use_temp = (long) bif_long_arg (qst, args, 1, "blob_to_string");

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
    return box_bin_string ((db_buf_t) bh, box_length ((caddr_t) bh) + 1, DV_LONG_STRING);
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
#ifndef O12
  if (use_temp && qi->qi_temp_isp)
    res = blob_to_string_isp (NULL, qi->qi_temp_isp, bh);
  else
#endif
    res = blob_to_string (qi->qi_trx, bh);
  return res;
}


caddr_t
bif_blob_to_string_output (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) QST_INSTANCE (qst);
  caddr_t bh = bif_arg (qst, args, 0, "blob_to_string_output");
  dk_session_t *res;
  long use_temp = 0;

  dtp_t dtp = DV_TYPE_OF (bh);

  if (BOX_ELEMENTS (args) > 1)
    use_temp = (long) bif_long_arg (qst, args, 1, "blob_to_string_output");

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


#ifndef O12
  if (use_temp && qi->qi_temp_isp)
    res = blob_to_string_output_isp (NULL, qi->qi_temp_isp, bh);
  else
#endif
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
  if (BOX_ELEMENTS (args) > 0)
  f = (int) bif_long_arg (qst, args, 0, "raw_exit");
  if (!QI_IS_DBA (qst))
  return 0;
  if (qi->qi_client && qi->qi_client->cli_session)
    session_flush (qi->qi_client->cli_session);
  if (!f)
    IN_CPT (((query_instance_t *) qst)->qi_trx); /* not during checkpoint */
  call_exit (0);
  return NULL; /* dummy */
}


caddr_t
bif_sequence_set (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  long res;
  query_instance_t *qi = (query_instance_t *) QST_INSTANCE (qst);
  caddr_t name = bif_string_arg (qst, args, 0, "sequence_set");
  long count = (long) bif_long_arg (qst, args, 1, "sequence_set");
  long mode = (long) bif_long_arg (qst, args, 2, "sequence_set");
  res = sequence_set (name, count, mode, OUTSIDE_MAP);
  if (mode == SET_IF_GREATER)
    log_sequence (qi->qi_trx, name, res);
  else if (mode == SET_ALWAYS)
    {
      caddr_t log_array;

      log_array = list (4, box_string ("sequence_set (?, ?, ?)"),
	    box_string (name), box_num (count), box_num (mode));
      log_text_array (qi->qi_trx, log_array);
      dk_free_tree (log_array);
    }

  return (box_num (res));
}


caddr_t
bif_sequence_next (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) QST_INSTANCE (qst);
  caddr_t name = bif_string_arg (qst, args, 0, "sequence_next");
  long inc_by = 1, res;

  if (BOX_ELEMENTS (args) > 1)
    {
      inc_by = (long) bif_long_arg (qst, args, 1, "sequence_next");
      if (inc_by < 1)
	sqlr_new_error ("22023", "SR376",
	    "sequence_next() needs an integer >= 0 as a second argument, not %ld", inc_by);
    }
  res = sequence_next_inc (name, OUTSIDE_MAP, inc_by);
  log_sequence (qi->qi_trx, name, res + inc_by);
  return (box_num (res));
}


caddr_t
bif_sequence_remove (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  long res;
  query_instance_t *qi = (query_instance_t *) QST_INSTANCE (qst);
  caddr_t name = bif_string_arg (qst, args, 0, "sequence_remove");

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

  if (!user || !user->usr_is_sql || user->usr_is_role)
    return 0;

  cli->cli_user = user;
  dk_free_tree (cli->cli_qualifier);
  cli->cli_qualifier = NULL;
  cli_set_default_qual (cli);
  if (!cli->cli_qualifier)
    CLI_SET_QUAL (cli, "DB");

  if (!in_srv_global_init)
    CHANGE_THREAD_USER (user);

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

  if (!user || !user->usr_is_sql || user->usr_is_role)
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
bif_identity_value (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) QST_INSTANCE (qst);
  return (box_copy (qi->qi_client->cli_identity_value));
}


static int registry_name_is_protected (const caddr_t name)
{
  if (!strncmp (name, "__key__", 7))
    return 2;
  if (!strcmp (name, "__next_free_port"))
    return 1;
  return 0;
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
  IN_TXN;
  registry_set_1 (name, val, 1);
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
  caddr_t q = box_string (bif_string_arg (qst, args, 0, "set_qualifier"));
  caddr_t cli_ws = (caddr_t) ((query_instance_t *)qst)->qi_client->cli_ws;
  client_connection_t * cli = (client_connection_t *) ((query_instance_t *)qst)->qi_client;

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
bif_key_insert (caddr_t * inst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) inst;
  db_buf_t row = (db_buf_t) bif_arg (inst, args, 0, "key_insert");
  caddr_t tb_name = bif_string_arg (inst, args, 1, "key_insert");
  caddr_t k_name = bif_string_arg (inst, args, 2, "key_insert");
  dbe_table_t *tb = qi_name_to_table (qi, tb_name);
  dbe_key_t *key = tb_name_to_key (tb, k_name, 1);
  it_cursor_t *it = itc_create (qi->qi_space, qi->qi_trx);

  ITC_FAIL (it)
  {
  itc_row_key_insert (it, row, key);
  }
  ITC_FAILED
  {
  itc_free (it);
  }
  END_FAIL (it);
  itc_free (it);
  return ((caddr_t) 1L);
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
  caddr_t u_pwd = bif_string_arg (qst, args, 1, "user_set_password");

  query_instance_t *qi = (query_instance_t *) (qst);
  user_t *usr = sec_name_to_user (u_name);
  client_connection_t *cli = qi->qi_client;
  /*caddr_t *old_log = qi->qi_trx->lt_replicate;*/
  caddr_t *log_array = NULL;

  sec_check_dba (qi, "user_set_password");

  if (!usr)
    sqlr_new_error ("42000", "SR286", "The user %.50s does not exist", u_name);
  if (strlen (u_pwd) == 0)
    sqlr_new_error ("42000", "SR287", "The new password for %.50s cannot be empty", usr->usr_name);
  qi->qi_client = bootstrap_cli;
  /*qi->qi_trx->lt_replicate = REPL_NO_LOG; */
  QR_RESET_CTX_T (qi->qi_thread)
    {
      sec_set_user (qi, usr->usr_name, u_pwd, 1);
    }
  QR_RESET_CODE
    {
      POP_QR_RESET;
      /*qi->qi_trx->lt_replicate = old_log; */
      qi->qi_client = cli;
      longjmp_splice (THREAD_CURRENT_THREAD->thr_reset_ctx, reset_code);
    }
  END_QR_RESET
  /*qi->qi_trx->lt_replicate = old_log; */
  qi->qi_client = cli;

  log_array = (caddr_t *) dk_alloc_box (6 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  log_array[0] = box_string ("sec_set_user_struct (?, ?, ?, ?, ?)");
  log_array[1] = box_string (usr->usr_name);
  log_array[2] = box_string (u_pwd);
  log_array[3] = box_num (usr->usr_id);
  log_array[4] = box_num (usr->usr_g_id);
  log_array[5] = usr->usr_data ? box_string (usr->usr_data) : dk_alloc_box (0, DV_DB_NULL);
  log_text_array (qi->qi_trx, (caddr_t) log_array);
  dk_free_tree ((box_t) log_array);
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


caddr_t
bif_log_text (caddr_t * inst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) inst;
  int inx, len = BOX_ELEMENTS (args);
  caddr_t * arr = (caddr_t *) dk_alloc_box (len * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  dk_set_t temp_blobs = NULL;

  for (inx = 0; inx < len; inx++)
  {
    arr[inx] = bif_arg (inst, args, inx, "log_text");
    if (IS_BLOB_HANDLE (arr[inx]))
      {
        arr[inx] = blob_to_string (qi->qi_trx, arr[inx]);
	dk_set_push(&temp_blobs, arr[inx]);
      }
  }
  log_text_array (qi->qi_trx, (caddr_t) arr);
  dk_free_box ((caddr_t) arr);
  dk_free_tree(list_to_array (temp_blobs));
  return 0;
}


caddr_t
bif_repl_text (caddr_t * inst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) inst;
  caddr_t acct = bif_string_arg (inst, args, 0, "repl_text");
  int n_args = BOX_ELEMENTS (args) - 1;
  caddr_t * arr = (caddr_t*) dk_alloc_box (n_args * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  int inx;
  for (inx = 0; inx < n_args; inx++)
  arr[inx] = bif_arg (inst, args, inx + 1, "repl_text");
  log_repl_text_array (qi->qi_trx, NULL, acct, (caddr_t) arr);
  dk_free_box ((caddr_t) arr);
  return 0;
}

caddr_t
bif_repl_text_pushback (caddr_t * inst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) inst;
  caddr_t srv = bif_string_arg (inst, args, 0, "repl_text_pushback");
  caddr_t acct = bif_string_arg (inst, args, 1, "repl_text_pushback");
  int n_args = BOX_ELEMENTS (args) - 2;
  caddr_t * arr = (caddr_t*) dk_alloc_box (n_args * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  int inx;
  for (inx = 0; inx < n_args; inx++)
  arr[inx] = bif_arg (inst, args, inx + 2, "repl_text_pushback");
  log_repl_text_array (qi->qi_trx, srv, acct, (caddr_t) arr);
  dk_free_box ((caddr_t) arr);
  return 0;
}

caddr_t
bif_repl_set_raw (caddr_t * inst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) inst;
  long is_raw = (int) bif_long_arg (inst, args, 0, "repl_set_raw");
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
  long flag = (long) bif_long_arg (qst, args, 0, "log_enable");
  long quiet = (BOX_ELEMENTS (args) > 1) ? (long) bif_long_arg (qst, args, 1, "log_enable") : 0L;

  if (srv_have_global_lock (THREAD_CURRENT_THREAD))
    return box_num (1);


  if (!flag && qi->qi_client != bootstrap_cli &&
      qi->qi_trx->lt_replicate == REPL_NO_LOG)
    {
      if (quiet)
        return box_num (0);
      sqlr_new_error ("42000", "SR471",
	"log_enable () called twice to disable the already disabled log output" );
    }
  qi->qi_trx->lt_replicate = flag
  ? (caddr_t*) box_copy_tree ((caddr_t) qi->qi_client->cli_replicate)  : REPL_NO_LOG;
  return box_num (1);
}


caddr_t
bif_serialize (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  scheduler_io_data_t iod;
  caddr_t res;
  caddr_t xx = bif_arg (qst, args, 0, "serialize");
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
	  "Cannot serialize the data of type %s (%u)",
	  dv_type_title (tag), (unsigned) tag);
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
bif_deserialize (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t xx = bif_string_or_null_arg (qst, args, 0, "deserialize");
  dtp_t dtp = DV_TYPE_OF (xx);
  if (dtp == DV_SHORT_STRING
    || dtp == DV_LONG_STRING)
  {
    return (box_deserialize_string (xx, 0));
  }
  return (dk_alloc_box (0, DV_DB_NULL));
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
    {
      icc_locks_mutex = mutex_allocate();
      icc_locks = id_str_hash_create (31);
    }
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
        semaphore_enter (cli_lock->iccl_sem);
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
  query_instance_t *qi = (query_instance_t *) qst;
  IN_TXN;
  lt_killall (qi->qi_trx);
  LEAVE_TXN;
  return 0;
}


caddr_t
bif_replay (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;

  char * fname = bif_string_arg (qst, args, 0, "replay");
  int fd;
  if (qi->qi_trx->lt_locks)
  sqlr_new_error ("25000", "SR074", "replay must be run in a fresh transaction.");
  fd = open (fname, O_RDONLY | O_BINARY);
  if (-1 == fd)
  {
    int errno_save = errno;
    sqlr_new_error ("42000", "FA002", "Can't open file %s, error %d (%s)", fname, errno, strerror (errno_save));
  }
  log_replay_file (fd);
  close (fd);
  return NULL;
}


caddr_t
bif_ddl_change (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char *tb = bif_string_arg (qst, args, 0, "__ddl_change");
  query_instance_t *qi = (query_instance_t *) qst;
  caddr_t repl = box_copy_tree ((box_t) qi->qi_trx->lt_replicate);
  /* save the logging mode across the autocommit inside the schema read */
  qi_read_table_schema (qi, tb);
  qi->qi_trx->lt_replicate = (caddr_t *)repl;
  log_dd_change (qi -> qi_trx, tb);
  return 0;
}

caddr_t
bif_ddl_table_renamed (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  char *old = bif_string_arg (qst, args, 0, "__ddl_table_renamed");
  char *_new = bif_string_arg (qst, args, 1, "__ddl_table_renamed");
  query_instance_t *qi = (query_instance_t *) qst;
  caddr_t repl = box_copy_tree ((box_t) qi->qi_trx->lt_replicate);
  /* save the logging mode across the autocommit inside the schema read */
  ddl_rename_table_1 (qi, old, _new, err_ret);
  qi->qi_trx->lt_replicate = (caddr_t *)repl;
  return 0;
}

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
  query_t * qr;
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
  qr = sql_compile (text, qi->qi_client, &err, SQLC_DO_NOT_STORE_PROC);
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
  caddr_t err, tb_name;
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
    rdproc = sql_compile ("select coalesce (T_TEXT, blob_to_string (T_MORE)), name_part (T_NAME, 1), T_SCH from DB.DBA.SYS_TRIGGERS where T_NAME = ? AND T_TABLE = ?", cli, &err, SQLC_DEFAULT);
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
#ifdef REPLICATION_SUPPORT2
      char *replic_acct = NULL;
      char *procstmt = NULL;
#endif
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
#ifdef REPLICATION_SUPPORT2
      procstmt = text;
      replic_acct = find_repl_account_in_src_text (&procstmt);
      proc_qr = sql_compile (procstmt, cli, &err, SQLC_DO_NOT_STORE_PROC);
      if (proc_qr && !err)
	proc_qr->qr_proc_repl_acct = ((NULL != replic_acct) ? box_string (replic_acct) : NULL);
      if (!err)
	qr_proc_repl_check_valid (proc_qr, &err);
#else
      proc_qr = sql_compile (text, cli, &err, SQLC_DO_NOT_STORE_PROC);
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
#ifdef UNIVERSE
  if (IS_REMOTE_ROUTINE_QR (proc))
    {
      sch_set_remote_proc_def (full_name, NULL);
    }
#endif
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
  else if (0 == stricmp (opt, "DIVE_CACHE_THRESHOLD"))
    {
      dive_cache_threshold = lvalue;
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
  int32 old_cp_interval;

  c_checkpoint_interval = (int32) bif_long_arg (qst, args, 0, "checkpoint_interval");
  old_cp_interval = cfg_autocheckpoint / 60000L;

  IN_CPT (((query_instance_t *) qst)->qi_trx);
  if (-1 > c_checkpoint_interval)
  c_checkpoint_interval = -1;
  cfg_autocheckpoint = 60000L * c_checkpoint_interval;
  cfg_set_checkpoint_interval (c_checkpoint_interval);
  LEAVE_CPT(((query_instance_t *) qst)->qi_trx);
  return box_num (old_cp_interval);
}


caddr_t
bif_exec_error (caddr_t * qst, state_slot_t ** args, caddr_t err)
{
  char buf[80];
  if ((BOX_ELEMENTS (args) < 3) || !ssl_is_settable (args[1]))
  sqlr_resignal (err);
  if (IS_POINTER(err))
  {
    qst_set (qst, args[1], ERR_STATE (err));
    if (ssl_is_settable (args[2]))
  qst_set (qst, args[2], ERR_MESSAGE (err));
    dk_free_box(err);
  } else {
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
  long affected = -1;
  if (!what && IS_BOX_POINTER (qi))
    {
      qi->qi_n_affected += increment;
      affected = qi->qi_n_affected;
    }
  else if (what && IS_BOX_POINTER (qi->qi_caller))
    {
      qi->qi_caller->qi_n_affected += increment;
      affected = qi->qi_caller->qi_n_affected;
    }
  return (caddr_t) box_num(affected);
}


caddr_t
bif_exec (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  /* in text, out sqlstate, out message, in params, in max_rows,
   * out result_desc, out rows, out handle, out warnings */
  local_cursor_t *lc = NULL;
  dk_set_t rlist = NULL, proc_resultset = NULL;
  int n_args = BOX_ELEMENTS (args), n_cols, named_pars = 0;
  query_instance_t *qi = (query_instance_t *) qst;
  stmt_compilation_t *comp = NULL, *proc_comp = NULL;
  caddr_t _text;
  caddr_t text = NULL;
  caddr_t *params = NULL;
  caddr_t *new_params = NULL;
  dtp_t ptype = DV_DB_NULL;
  caddr_t err = NULL;
  query_t *qr;
  long max = 0;
  client_connection_t *cli = qi->qi_client;
  caddr_t res = NULL;
  dk_set_t warnings = NULL;
  ST *pt = NULL;
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
      ptype = DV_TYPE_OF (params);
    }

  PROC_SAVE_PARENT;
  warnings = sql_warnings_save (NULL);
  if (n_args < 8 || !ssl_is_settable (args[7]))
    { /* no cursor for stored procedures */
      if (n_args > 4)
	{
	  cli->cli_resultset_max_rows = (long) bif_long_arg (qst, args, 4, "exec");
	  if (!cli->cli_resultset_max_rows)
	    cli->cli_resultset_max_rows = -1;
	}
      if (n_args > 5 && ssl_is_settable (args[5]))
	cli->cli_resultset_comp_ptr = (caddr_t *) &proc_comp;
      if (n_args > 6 && ssl_is_settable (args[6]))
	cli->cli_resultset_data_ptr = &proc_resultset;
    }

  if (pt)
    qr = sql_compile_1 ("", qi->qi_client, &err, SQLC_DEFAULT, pt, NULL);
  else
    qr = sql_compile (text, qi->qi_client, &err, SQLC_DEFAULT);
  if (err)
    {
      PROC_RESTORE_SAVED;
      if (text != _text)
	dk_free_box (text);
      dk_free_tree (list_to_array (proc_resultset));
      dk_free_tree ((caddr_t) proc_comp);
      res = bif_exec_error (qst, args, err);
      goto done;
    }
  if (text != _text)
    dk_free_box (text);
  named_pars = qr_have_named_params (qr);
  new_params = make_qr_exec_params(params, named_pars);

  err = qr_exec(qi->qi_client, qr, qi, NULL, NULL, &lc,
      new_params, NULL, 1);
  dk_free_box ((box_t) new_params);
  if (err)
    {
      if (lc)
	lc_free (lc);
      PROC_RESTORE_SAVED;
      dk_free_tree ((caddr_t) proc_comp);
      dk_free_tree (list_to_array (proc_resultset));
      res = bif_exec_error (qst, args, err);
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

      if (n_args > 4)
	max = (long) bif_long_arg (qst, args, 4, "exec");

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
		      srv_make_new_error ("22005", "SR078", "The cursor parameter is not settable"));
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
	  res = bif_exec_error (qst, args, err);
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
	qst_set (qst, args[6], list_to_array (dk_set_nreverse (proc_resultset)));
      else if (n_args > 6 && ssl_is_settable (args[6]) && lc)
	qst_set (qst, args[6], box_num (lc->lc_row_count));
      else
	dk_free_tree (list_to_array (proc_resultset));
      if (lc)
	{
	  err = lc->lc_error;
	  lc->lc_error = NULL;
	  lc_free (lc);
	  if (err)
	    {
	      res = bif_exec_error (qst, args, err);
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
  qr_free (qr);
  return res ? res : box_num (0);
}

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
      return (bif_exec_error (qst, args, err));
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
bif_exec_next (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t *handle = (caddr_t *) bif_arg (qst, args, 0, "exec_next");
  local_cursor_t *lc;
  query_t *qr;
  int n_cols;

  int n_args = BOX_ELEMENTS (args);
  caddr_t err = NULL;

  if (n_args < 4)
  return bif_exec_error (qst, args,
  srv_make_new_error ("22023", "SR079", "Too few arguments to exec_next(cursor, state, message, row)"));

  if (DV_TYPE_OF (handle) != DV_EXEC_CURSOR || BOX_ELEMENTS(handle) != 3)
  return bif_exec_error (qst, args,
  srv_make_new_error ("22023", "SR080", "Parameter 4 is not a valid local exec handle"));

  qr = (query_t *) handle[0];
  lc = (local_cursor_t *) handle[1];
  n_cols = (int) (ptrlong) handle[2];

  if (!lc_next (lc))
  {
    err = lc->lc_error;
    lc->lc_error = NULL;
    if (err)
  {
    return (bif_exec_error (qst, args, err));
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
}


caddr_t
bif_exec_close (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t *handle = (caddr_t *) bif_arg (qst, args, 0, "exec_close");
  local_cursor_t *lc;
  query_t *qr;

  if (DV_TYPE_OF (handle) != DV_EXEC_CURSOR || BOX_ELEMENTS(handle) != 3)
  return bif_exec_error (qst, args,
  srv_make_new_error ("22023", "SR081", "Parameter 1 is not a valid local exec handle"));

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
#endif
  return 0;
}


caddr_t
bif_mutex_meter (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  long inx;
  long n = (long) bif_long_arg (qst, args, 0, "mutex_meter");
  long fl = (long) bif_long_arg (qst, args, 1, "mutex_meter");
  static dk_mutex_t * stmtx;
  dk_mutex_t * mtx;
  if (!stmtx)
  stmtx = mutex_allocate ();
  if (fl)
  mtx = mutex_allocate ();
  else
  mtx = stmtx;
  for (inx = 0; inx < n; inx++)
  {
    mutex_enter (mtx);
    mutex_leave (mtx);
  }
  if (fl)
  mutex_free (mtx);
  return 0;
}


caddr_t
bif_malloc_meter (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  long inx;
  long n = (long) bif_long_arg (qst, args, 0, "malloc_meter");
  caddr_t x;
  long fl = (long) bif_long_arg (qst, args, 1, "malloc_meter");
/*  static dk_mutex_t * stmtx; */
  for (inx = 0; inx < n; inx++)
  {
    if (0 == fl)
  {
    x = (caddr_t) malloc (16);
    free ((void*) x);
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
  long target[100];
  long inx, ct;
  long n = (long) bif_long_arg (qst, args, 0, "malloc_meter");
  /*caddr_t x;*/
  long fl = (long) bif_long_arg (qst, args, 1, "malloc_meter");
  char * from = (char *) &n;

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
    ((long*)&target)[inx] = ((long*)from)[inx];
        break;
      case 3:
        from =  ((char *)&fl) + 1;
        for (inx = 0; inx < 8; inx++)
    ((long*)&target)[inx] = ((long*)from)[inx];
        break;
      case 4:
        for (inx = 0; inx < 4; inx++)
    ((int64*)&target)[inx] = ((int64*)from)[inx];
        break;
      case 5:
        from =  ((char *)&fl) + 1;
        for (inx = 0; inx < 4; inx++)
    ((int64*)&target)[inx] = ((int64*)from)[inx];
        break;

      }
  }
  return 0;
}

caddr_t
bif_self_meter (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  long inx;
  long n = (long) bif_long_arg (qst, args, 0, "mutex_meter");
  for (inx = 0; inx < n; inx++)
  {
    THREAD_CURRENT_THREAD;
  }
  return 0;
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
  return (box_num (qi->qi_n_affected));
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
  query_instance_t * qi = (query_instance_t *) qst;
  int flag = (int) bif_long_arg (qst, args, 0, "__atomic");
  srv_global_lock (qi, flag);
  return 0;
}


caddr_t
bif_client_trace (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  long fl;

  fl = (long) bif_long_arg(qst, args, 0, "client_trace");
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
  hash_join_enable = (int) (2 & sqlo_enable);
  sqlo_print_debug_output = (int) (4 & sqlo_enable);
  return NULL;
}


caddr_t
bif_hic_clear (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  hic_clear ();
  return NULL;
}


caddr_t
sql_lex_analyze (const char * str2, caddr_t * qst, int max_lexems, int use_strval)
{
  if (!str2)
    {
      return list (1, list (3, 0, 0, "SQL lex analyzer: input text is NULL, not a string"));
    }
  else
    {
      dk_set_t lexems = NULL;
      sql_comp_t sc;
      caddr_t result_array = NULL;
      caddr_t str;
      memset (&sc, 0, sizeof (sc));

      if (!parse_sem)
  parse_sem = semaphore_allocate (1);
      MP_START();
      semaphore_enter (parse_sem);
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
        lextype = yylex();
        if (!lextype)
	  break;
        if (olex == lextype && lextype == ';')
	  continue;
        boxed_plineno = box_num (scn3_plineno);
        boxed_text = use_strval ?
	  box_dv_short_string (yylval.strval) :
	  box_dv_short_nchars (yytext, yyleng);
        boxed_lextype = box_num (lextype);
        dk_set_push (&lexems, list (3, boxed_plineno, boxed_text, boxed_lextype));
        olex = lextype;
        if (max_lexems && (++n_lexem) >= max_lexems)
	  break;
      }
    lexems = dk_set_nreverse (lexems);
  }
      else
  {
    char err[1000];
    snprintf (err, sizeof (err), "SQL lex analyzer: %s ", sql_err_text);
    lexems = dk_set_nreverse (lexems);
    dk_set_push (&lexems, list (2,
      scn3_plineno,
      box_dv_short_string (err) ) );
    goto cleanup;
  }
cleanup:
      semaphore_leave (parse_sem);
      MP_DONE();
      sc_free (&sc);
      result_array = (caddr_t)(dk_set_to_array (lexems));
      dk_set_free (lexems);
      return result_array;
    }
}


static
caddr_t
bif_sql_lex_analyze (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t str = bif_string_arg (qst, args, 0, "sql_lex_analyze");
  return sql_lex_analyze (str, qst, 0, 0);
}


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


caddr_t
bif_bit_and (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  long x1 = (long) (0xffffffff & bif_long_arg (qst, args, 0, "bit_and"));
  long x2 = (long) (0xffffffff & bif_long_arg (qst, args, 1, "bit_and"));
  return box_num (x1 & x2);
}


caddr_t
bif_bit_or (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  long x1 = (long) (0xffffffff & bif_long_arg (qst, args, 0, "bit_or"));
  long x2 = (long) (0xffffffff & bif_long_arg (qst, args, 1, "bit_or"));
  return box_num (x1 | x2);
}


caddr_t
bif_bit_xor (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  long x1 = (long) (0xffffffff & bif_long_arg (qst, args, 0, "bit_xor"));
  long x2 = (long) (0xffffffff & bif_long_arg (qst, args, 1, "bit_xor"));
  return box_num (x1 ^ x2);
}


caddr_t
bif_bit_not (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  long x1 = (long) (0xffffffff & bif_long_arg (qst, args, 0, "bit_or"));
  return box_num (~x1);
}


caddr_t
bif_bit_shift (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  long x1 = (long) (0xffffffff & bif_long_arg (qst, args, 0, "bit_shift"));
  long x2 = bif_long_arg (qst, args, 1, "bit_shift");
  if (x2 >= 0)
    return box_num (x1 << x2);
  else /* The trick here is for guaranteed accurate work on 64-bit platforms. */
    {
      if (x1 & 0x80000000)
        return box_num (0xffffffff ^ ((x1 ^ 0xffffffff) >> (-x2)));
      else
        return box_num (x1 >> (-x2));
    }
}

caddr_t
bif_byte_order_check (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  long order = bif_long_arg (qst, args, 0, "byte_order_check");
  caddr_t *qi = QST_INSTANCE (qst);
  if (!QI_IS_DBA (qi))
    return 0;
  if (order != DB_ORDER_UNKNOWN && order != DB_SYS_BYTE_ORDER)
    {
      log_error ("The transaction file has been produced with wrong byte order. Please, delete it and start the server again");
      call_exit(0);
    }
  return NEW_DB_NULL;
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


bif_type_t bt_time = {NULL, DV_TIME, 0, 0};
bif_type_t bt_date = {NULL, DV_DATE, 10, 0};
bif_type_t bt_datetime = {NULL, DV_DATETIME, 10, 0};
bif_type_t bt_timestamp = {NULL, DV_DATETIME, 10, 0};
bif_type_t bt_bin = {NULL, DV_BIN, 10, 0};

void bif_cursors_init (void);

sql_tree_tmp * st_varchar;
sql_tree_tmp * st_nvarchar;



caddr_t bif_hash (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);
caddr_t bif_md5_box (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);

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
  fprintf (stderr, "decoded xid = %ld %ld %ld %s\n", test_xid_2->formatID, test_xid_2->gtrid_length, test_xid_2->bqual_length, test_xid_2->data);


  dk_free_box (res);

  FASSERT (test_xid_2->formatID==test_xid.formatID, "formatID decoding");
  FASSERT (test_xid_2->gtrid_length==test_xid.gtrid_length, "gtrid decoding");
  FASSERT (test_xid_2->bqual_length==test_xid.bqual_length, "bqual_length decoding");
  FASSERT ((!strcmp (test_xid_2->data, test_xid.data)), "data decoding");

  dk_free_box ((box_t) test_xid_2);


  test_xid_2 = (virtXID *) xid_bin_decode("00000000000000110a302918bc631a40200000002100000000000000100000c100000000c830020bc00700000831020b0000000041000000000000002e0000b6687474703a2f2f7777772e77332e6f72672f313939392f58534c2f5472616e73666f726d3a76616c75652d6f66000000000000003100000000000000170000b6687474703a2f2f6c6f63616c");
  fprintf (stderr, "decoded xid = %ld %ld %ld %s\n", test_xid_2->formatID, test_xid_2->gtrid_length, test_xid_2->bqual_length, test_xid_2->data);


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


/* search_excerpt */

typedef struct se_hit_s
{
  ptrlong	seh_idx; /* index of hit word in word_hit */
  caddr_t	seh_hit_pointer; /* pointer of hit word found in main doc */
} se_hit_t;

#define HIT_TAG_LEN 80
typedef struct search_excerpt_s
{
  char *	se_doc;
  caddr_t *	se_hit_words;
  se_hit_t **	se_hits;
  int		se_hits_len;
  int		se_total;
  int		se_excerpt_max;
  int		se_text_mode;
  char		se_hit_tag[HIT_TAG_LEN];
  /* result */
  caddr_t **	se_sentences;
  /* do not search hit words, just make an excerpt from begin */
  int		se_from_begin;
} search_excerpt_t;

#define MAX_EXCERPT_HITS	10
#define MAX_EXCERPT_HITS_STR	"10"

#define HIT_WORD_WEIGHT		100
#define SE_HIT_POINTER(seh)	(((se_hit_t*) seh )->seh_hit_pointer)

#define ISHITCHAR(c) ( isalpha(c) || isdigit(c) )
#define WORD_POINTS		(caddr_t)1
#define WORD_POINT_1		(caddr_t)2

#define SEARCH_EXCERPT_MODE_HTML 0
#define SEARCH_EXCERPT_MODE_WIKI 1
#define SEARCH_EXCERPT_MODE_TEXT 2
#define SEARCH_EXCERPT_MODE_MAX 3

static
int search_excerpt_check_html_tag (char ** wpoint);

/* creates ordered set from ordered sets of ptrlongs
 */
dk_set_t merge_sets (dk_set_t s1, dk_set_t s2)
{
  dk_set_t res = 0;
  while (s1 && s2)
    {
      if (SE_HIT_POINTER(s1->data) < SE_HIT_POINTER(s2->data))
	{
	  dk_set_push (&res, s1->data);
	  s1 = s1->next;
	}
      else
	{
	  dk_set_push (&res, s2->data);
	  s2 = s2->next;
	}
    }
  while (s1)
    {
      dk_set_push (&res, s1->data);
      s1 = s1->next;
    }
  while (s2)
    {
      dk_set_push (&res, s2->data);
      s2 = s2->next;
    }
  return res;
}

caddr_t search_excerpt_print (search_excerpt_t * se)
{
  caddr_t _result;
  dk_session_t * strses = strses_allocate();
  int sent_inx, word_inx;
  int points = 0;
  DO_BOX (caddr_t, sentence, sent_inx, se->se_sentences)
    {
      if (sent_inx && BOX_ELEMENTS (sentence))
	SES_PRINT (strses, " ");
      DO_BOX (caddr_t, word, word_inx, sentence)
	{
	  if (word == WORD_POINTS)
	    points++;
	  else
	    points = 0;
	  if (points == 2)
	    {
	      points = 0;
	      continue;
	    }
	  if (word == WORD_POINTS)
	    SES_PRINT (strses, "...");
	  else if (word == WORD_POINT_1)
	    SES_PRINT (strses, ".");
	  else if (DV_TYPE_OF (word) != DV_ARRAY_OF_POINTER)
	    SES_PRINT (strses, word);
	  else
	    {
	      if (!se->se_text_mode)
		{
		  session_buffered_write_char ('<', strses);
		  SES_PRINT (strses, se->se_hit_tag);
		  session_buffered_write_char ('>', strses);
		}
	      SES_PRINT (strses, ((caddr_t*)word) [1] );
	      if (!se->se_text_mode)
		{
		  SES_PRINT (strses, "</");
		  SES_PRINT (strses, se->se_hit_tag);
		  session_buffered_write_char ('>', strses);
		}
	    }
	  if (word_inx + 2 < BOX_ELEMENTS (sentence)) /* word before . or ... */
	    SES_PRINT (strses, " ");
	}
      END_DO_BOX;
    }
  END_DO_BOX;
  _result = strses_string (strses);
  strses_free (strses);
  return _result;
}

void search_excerpt_push_hit_word (dk_set_t* set, char * start, char * end)
{
  caddr_t * pair = (caddr_t *) dk_alloc_box (2 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  pair [0] = box_num (1);
  pair [1] = box_dv_short_nchars (start, end - start);
  dk_set_push (set, pair);
}

/* returns offset to begin of tag */
static
int search_excerpt_get_html_tag_offset (caddr_t doc, caddr_t pointer, int max_offset)
{
  caddr_t start = pointer;
  while (--start > doc)
    {
      if (pointer - start > max_offset)
	return max_offset + 1;
      if (start[0] == '<')
	{
	  caddr_t tag_end = start;
	  if (search_excerpt_check_html_tag (&tag_end) && (tag_end == (pointer + 1)))
	    return (pointer - start);
	}
    }
  return 0;
}

/* return either begin of the sentence or pointer after left_border */
caddr_t search_excerpt_to_begin (caddr_t doc, caddr_t left_border, caddr_t start_from, int max_offset, int text_mode, int * hit_left_border)
{
  caddr_t pointer = start_from;
  while ((max_offset-- >= 0) && (pointer > left_border))
    {
      if (pointer[0] == '.')
	return pointer + 1;
      else if (!text_mode && (pointer[0] == '>')) /* possible tag */
	{
	  int back_offset = search_excerpt_get_html_tag_offset (doc, pointer, max_offset);
	  if (back_offset > max_offset)
	    return pointer + 1;
	  else if (back_offset)
	    {
	      max_offset -= back_offset;
	      pointer -= back_offset + 1;
	      continue;
	    }
	}
      pointer--;
    }
  if (left_border == pointer)
    {
      if (hit_left_border)
	hit_left_border[0] = 1;
      if (doc == left_border)
	return pointer;
    }
  return pointer + 1;
}

/* return 1 if html tag detected,
   points wpoint to the end of tag
*/
static
int search_excerpt_check_html_tag (char ** wpoint)
{
  char * p = wpoint[0];
  if (p[0] == '<')
    {
      p++;
      if ((p[0] == '/') && isalpha(p[1]))
	{ /* close tag */
	  p++;
	  while (p[0] && (p[0] != '>')) p++;
	  if (p[0])
	    {
	      wpoint[0] = p + 1;
	      return 1;
	    }
	}
      else if (isalpha (p[0]))
	{ /* open tag, empty tag */
	  while (p[0] && (p[0] != '>')) p++;
	  if (p[0])
	    {
	      wpoint[0] = p + 1;
	      return 1;
	    }
	}
      else if (p[0] == '!' &&
	       p[1] == '-' &&
	       p[2] == '-') /* comments */
	{
	  p += 2;
	  while (p[0] && p[1] && p[2])
	    {
	      if (p[0] == '-' &&
		  p[1] == '-' &&
		  p[2] == '>')
		{
		  wpoint[0] = p + 3;
		  return 1;
		}
	      p++;
	    }
	}
    }
  else if (p[0] == '&')
    {
      p++;
      while (isalpha (p[0])) ++p;
      if (p[0] == ';')
        {
	  wpoint[0] = ++p;
	  return 1;
	}
    }
  return 0;
}

#define NOTWORDCHAR(c) ((!isalnum((unsigned char)(c))\
			&& ((c) != '.')))


void search_excerpt_tokenize_doc (search_excerpt_t * se)
{
  caddr_t * curr_sentence;
  dk_set_t curr_sentence_set = 0;
  dk_set_t sentences_set = 0;
  caddr_t wstart, wpoint;
  int hidx = 0;
  int sentence_hit_weight = 0;
  int total_counter = 0, prev_total_counter = 0;
  int excerpt_counter = 0;
  int all_complete = 0;
  int point_at_the_end = 0;
  int sentences_count = 0;

  if (!se->se_from_begin)
    wpoint = search_excerpt_to_begin (se->se_doc, se->se_doc, se->se_hits[0]->seh_hit_pointer, se->se_excerpt_max / 2, se->se_text_mode, 0);
  else
    wpoint = search_excerpt_to_begin (se->se_doc, se->se_doc, se->se_doc, se->se_excerpt_max / 2, se->se_text_mode, 0);
  wstart = wpoint;
  /* search sentence */
 again:
  while (wpoint[0] && wpoint[0] != '.')
    {
      if (!sentences_count)
	{
	  if (wpoint != se->se_doc)
	    dk_set_push (&curr_sentence_set, WORD_POINTS);
	  ++sentences_count;
	}
      if (NOTWORDCHAR(wpoint[0])) /* instead of isspace (wpoint[0])) */
	{
	  if (total_counter + wpoint - wstart >= se->se_total)
	    {
	      all_complete = 1;
	      goto excerpt_end;
	    }
	  if (excerpt_counter +  wpoint - wstart >= se->se_excerpt_max)
	    {
	      wpoint = wstart;
	      goto excerpt_end;
	    }
  	  if (!se->se_from_begin)
	    {
	      while ( (hidx < se->se_hits_len) && (se->se_hits[hidx]->seh_hit_pointer < wstart) )
	        hidx++;
	      if ( (hidx < se->se_hits_len ) && (se->se_hits[hidx]->seh_hit_pointer == wstart) )
	    	{
		  if ( ((wpoint - wstart) == strlen (se->se_hit_words[se->se_hits[hidx]->seh_idx])) ||
		   !ISHITCHAR(wstart[strlen (se->se_hit_words[se->se_hits[hidx]->seh_idx])]))
		    {
		      search_excerpt_push_hit_word (&curr_sentence_set, wstart, wpoint);
		      sentence_hit_weight += HIT_WORD_WEIGHT;
		    }
		  hidx++;
	         }
	        else if (wpoint - wstart)
	         dk_set_push (&curr_sentence_set,
			 box_dv_short_nchars (wstart, wpoint - wstart));
	    }
	  else if (wpoint - wstart)
            dk_set_push (&curr_sentence_set,
			 box_dv_short_nchars (wstart, wpoint - wstart));
	  total_counter += wpoint - wstart;
	  excerpt_counter += wpoint - wstart;
          if (!se->se_text_mode && search_excerpt_check_html_tag (&wpoint))
	    wstart = wpoint;
	  while (wpoint[0] && NOTWORDCHAR (*wpoint))
	    {
	      if (!se->se_text_mode && search_excerpt_check_html_tag (&wpoint))
		wstart = wpoint;
	      else
		wstart = wpoint[0] ? ++wpoint : wpoint;
	    }
	}
      else
	wpoint++;
    }
  if ((wstart+1) != wpoint) /* "{ws}." */
    {
      if (total_counter + wpoint - wstart >= se->se_total)
	{
	  all_complete = 1;
	  goto excerpt_end;
	}
      if (excerpt_counter +  wpoint - wstart >= se->se_excerpt_max)
	{
	  wpoint = wstart;
	  goto excerpt_end;
	}
      if (!se->se_from_begin && ((hidx < se->se_hits_len ) && (se->se_hits[hidx]->seh_hit_pointer == wstart)))
	{
	  if ( ((wpoint - wstart) == strlen (se->se_hit_words[se->se_hits[hidx]->seh_idx])) ||
	       !ISHITCHAR(wstart[strlen (se->se_hit_words[se->se_hits[hidx]->seh_idx])]))
	    {
	      search_excerpt_push_hit_word (&curr_sentence_set, wstart, wpoint);
	      sentence_hit_weight += HIT_WORD_WEIGHT;
	    }
	  hidx++;
	}
      else if (wpoint-wstart)
	dk_set_push (&curr_sentence_set,
		     box_dv_short_nchars (wstart, wpoint - wstart));
      dk_set_push (&curr_sentence_set, WORD_POINT_1);
      point_at_the_end = 1;
    }
 excerpt_end:
  if(!point_at_the_end)
    dk_set_push (&curr_sentence_set, WORD_POINTS);
  if (wpoint[0] == '.')
    wpoint++;

  if (se->se_from_begin || sentence_hit_weight)
    {
      /* dk_set_append_1 (&curr_sentence_set, box_num (sentence_hit_weight)); */
      if (dk_set_length(curr_sentence_set) > 0)
	{
	  curr_sentence = (caddr_t *) list_to_array (dk_set_nreverse (curr_sentence_set));
	  dk_set_push (&sentences_set, curr_sentence);
	}
      ++sentences_count;
    }
  else
    {
      DO_SET (caddr_t, el, &curr_sentence_set)
	{
	  dk_free_box (el);
	}
      END_DO_SET();
      all_complete = 0;
      total_counter = prev_total_counter;
      dk_set_free (curr_sentence_set);
      --sentences_count;
    }
  curr_sentence_set = 0;

  if (!se->se_from_begin)
    {
      if (!all_complete)
	{
	  while ((hidx < se->se_hits_len) && (se->se_hits[hidx]->seh_hit_pointer < wpoint))
	    hidx++;
	  if (hidx < se->se_hits_len)
	    {
	      int hit_left_border = 0;
	      if (!point_at_the_end && !hit_left_border)
		dk_set_push (&curr_sentence_set, WORD_POINTS);
	      wstart = wpoint = search_excerpt_to_begin (se->se_doc, wpoint, se->se_hits [hidx]->seh_hit_pointer, se->se_excerpt_max / 2,
							 se->se_text_mode, &hit_left_border);
	      if (!hit_left_border || (se->se_doc != wpoint))
		{
		  sentence_hit_weight = 0;
		  excerpt_counter = 0;
		  point_at_the_end = 0;
		  prev_total_counter = total_counter;
		  goto again;
		}
	    }
	}
    }
  else if (wpoint[0])
    {
      sentence_hit_weight = 0;
      excerpt_counter = 0;
      prev_total_counter = total_counter;
      ++wpoint;
      goto again;
    }
  se->se_sentences = (caddr_t**) list_to_array (dk_set_nreverse (sentences_set));
}

int search_excerpt_search_cluster (se_hit_t ** hit_index, int hit_index_sz, int cluster_sz)
{
  int idx ;
  for (idx = 1; idx < hit_index_sz; idx ++)
    if ((hit_index[idx]->seh_hit_pointer - hit_index[idx-1]->seh_hit_pointer) < cluster_sz)
      return idx - 1;
  return 0;
}

static
caddr_t search_excerpt_new_hit (int idx, caddr_t pointer)
{
  se_hit_t * seh = (se_hit_t*) dk_alloc (sizeof (se_hit_t));
  seh->seh_idx = idx;
  seh->seh_hit_pointer = pointer;
  return (caddr_t) seh;
}


static
caddr_t bif_search_excerpt (caddr_t *qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t * word_hits = bif_strict_type_array_arg (DV_STRING, qst, args, 0, "search_excerpt");
  caddr_t text, text_with_offset = 0, original_text  = bif_string_arg (qst, args, 1, "search_excerpt");
  ptrlong within_first = 200000;
  ptrlong max_excerpt = 90;
  ptrlong total = 200;
  caddr_t html_hit_tag;
  caddr_t _result = 0;
  long mode = SEARCH_EXCERPT_MODE_HTML;

  se_hit_t ** hit_index;
  int hit_inx = 0;
  int inx;
  dk_set_t hit_sets[MAX_EXCERPT_HITS];
  dk_set_t hit_res_set = 0;
  memset (hit_sets, 0, sizeof (hit_sets));

  if (BOX_ELEMENTS (word_hits) > MAX_EXCERPT_HITS)
    sqlr_new_error ("XXXXX", "SRXXX", "search_excerpt does not support more than " MAX_EXCERPT_HITS_STR " hits");

  if (BOX_ELEMENTS (args) > 2)
    within_first = bif_long_arg (qst, args, 2, "search_excerpt");
  if (BOX_ELEMENTS (args) > 3)
    max_excerpt = bif_long_arg (qst, args, 3, "search_excerpt");
  if (BOX_ELEMENTS (args) > 4)
    total = bif_long_arg (qst, args, 4, "search_excerpt");
  if (BOX_ELEMENTS (args) > 5)
    html_hit_tag = bif_string_or_null_arg (qst, args, 5, "search_excerpt");
  else
    html_hit_tag = "b";
  if (BOX_ELEMENTS (args) > 6)
    mode = bif_long_arg (qst, args, 6, "search_excerpt");
  if ( (mode < 0) && (mode >= SEARCH_EXCERPT_MODE_MAX))
    mode = SEARCH_EXCERPT_MODE_HTML;
  DO_BOX (caddr_t, hit, inx, word_hits)
    {
      if (!box_length (hit) || !hit[0])
	sqlr_new_error ("XXXXX", "SRXXX", "hit words must be non-zero length");
    }
  END_DO_BOX;

  if (box_length (original_text) > within_first)
    text = box_dv_short_nchars (original_text, within_first);
  else
    text = original_text;

  if (html_hit_tag && (mode == SEARCH_EXCERPT_MODE_HTML))
    text_with_offset = (caddr_t) nc_strstr ((unsigned char *) text, (unsigned char *) "<body");
  if (!text_with_offset)
    text_with_offset = text;

  DO_BOX (caddr_t, hit, inx, word_hits)
    {
      char * hit_pointer = text_with_offset;
      while ( (hit_pointer = (char *) nc_strstr ( (unsigned char *) hit_pointer, (unsigned char *) hit) ) )
	{
	  dk_set_push (&hit_sets[inx], search_excerpt_new_hit (inx, hit_pointer++));
	  hit_inx++;
	}
      hit_sets[inx] = dk_set_nreverse (hit_sets[inx]);
    }
  END_DO_BOX;
  if (!hit_inx)
    goto fin;
  hit_res_set = hit_sets[0];
  for (inx = 1; inx < BOX_ELEMENTS (word_hits); inx++)
    {
      dk_set_t _prev = hit_res_set;
      hit_res_set = dk_set_nreverse (merge_sets (_prev, hit_sets[inx]));
      if (_prev != hit_sets[0])
	dk_set_free (_prev);
    }


  hit_index = (se_hit_t **) dk_set_to_array (hit_res_set);
  if (hit_res_set != hit_sets[0])
    dk_set_free (hit_res_set);
  for (inx = 0; inx < BOX_ELEMENTS (word_hits); inx++)
    dk_set_free (hit_sets[inx]);

  { /* check consistency */
    caddr_t prev_el_hit = 0;
    DO_BOX (se_hit_t*, el, inx, hit_index)
      {
	/*	printf ("%s %x\n", el, el);
		fflush (stdout); */
	if (prev_el_hit > el->seh_hit_pointer)
	  GPF_T;
	prev_el_hit = el->seh_hit_pointer;
      }
    END_DO_BOX;
  }
  {
    search_excerpt_t se;
    int hit_index_cluster_ofs = search_excerpt_search_cluster (hit_index, BOX_ELEMENTS (hit_index), max_excerpt / 2);
    memset (&se, 0, sizeof (search_excerpt_t));
    se.se_doc = text_with_offset;
    se.se_hit_words = word_hits;
    se.se_hits = hit_index + hit_index_cluster_ofs;
    se.se_hits_len = BOX_ELEMENTS (hit_index) - hit_index_cluster_ofs;
    se.se_total = total;
    se.se_excerpt_max = max_excerpt;
    se.se_text_mode = (!html_hit_tag);
    if (html_hit_tag)
      strncpy (se.se_hit_tag, html_hit_tag, HIT_TAG_LEN-1);
    else
      strcpy (se.se_hit_tag, "b");
    search_excerpt_tokenize_doc (&se);
    _result = search_excerpt_print (&se);
    /* dbg_print_box_dbx (se.se_sentences); */
    dk_free_tree ((caddr_t) se.se_sentences);
  }

  DO_BOX (caddr_t, seh, inx, hit_index)
    {
      dk_free (seh, sizeof (se_hit_t));
    }
  END_DO_BOX;
  dk_free_box ((caddr_t)hit_index);

fin:
  if (!_result)
    {
      search_excerpt_t se;
      memset (&se, 0, sizeof (search_excerpt_t));
      se.se_doc = text_with_offset;
      se.se_total = total;
      se.se_excerpt_max = max_excerpt;
      se.se_text_mode = (!html_hit_tag);
      if (html_hit_tag)
        strncpy (se.se_hit_tag, html_hit_tag, HIT_TAG_LEN-1);
      else
        strcpy (se.se_hit_tag, "b");
      se.se_from_begin = 1;
      search_excerpt_tokenize_doc (&se);
      _result = search_excerpt_print (&se);
      dk_free_tree ((box_t) se.se_sentences);
    }
  if (text != original_text)
    dk_free_box (text);
  return _result;
}

void ssl_constant_init ();
void bif_diff_init ();

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
/* For debugging */
  bif_define_typed ("dbg_printf", bif_dbg_printf, &bt_varchar);
  bif_define ("dbg_obj_print", bif_dbg_obj_print);
  bif_define ("dbg_obj_princ", bif_dbg_obj_princ);

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

  bif_define_typed ("aref", bif_aref, &bt_any);
  bif_define_typed ("aref_set_0", bif_aref_set_0, &bt_any);
  bif_define_typed ("aset", bif_aset, &bt_integer);
  bif_define ("composite", bif_composite);
  bif_define ("composite_ref", bif_composite_ref);
  bif_define_typed ("ascii", bif_ascii, &bt_integer);
  bif_define_typed ("chr", bif_chr, &bt_varchar);

/* Substring extraction: */
  bif_define_typed ("subseq", bif_subseq, &bt_string);
  bif_define_typed ("substring", bif_substr, &bt_string);
  bif_define_typed ("left", bif_left, &bt_string);
  bif_define_typed ("right", bif_right, &bt_string);
  bif_define_typed ("ltrim", bif_ltrim, &bt_string);
  bif_define_typed ("rtrim", bif_rtrim, &bt_string);
  bif_define_typed ("trim", bif_trim, &bt_string);

/* Producing new strings by repetition: */
  bif_define_typed ("repeat", bif_repeat, &bt_string);
  bif_define_typed ("space", bif_space, &bt_varchar);
  bif_define_typed ("make_string", bif_make_string, &bt_varchar);
  bif_define_typed ("make_wstring", bif_make_wstring, &bt_wvarchar);
  bif_define_typed ("make_bin_string", bif_make_bin_string, &bt_varbinary);
  bif_define_typed ("concatenate", bif_concatenate, &bt_string);  /* Synonym for old times */
  bif_define_typed ("concat", bif_concatenate, &bt_string); /* This is more to standard */
  bif_define_typed ("replace", bif_replace, &bt_string);
  bif_define_typed ("sprintf", bif_sprintf, &bt_varchar);

/* Finding occurrences of characters and substrings in strings: */
  bif_define_typed ("strchr", bif_strchr, &bt_integer);
  bif_define_typed ("strrchr", bif_strrchr, &bt_integer);
  bif_define_typed ("strstr", bif_strstr, &bt_integer);
  bif_define_typed ("strindex", bif_strstr, &bt_integer);
  bif_define_typed ("strcasestr", bif_nc_strstr, &bt_integer);  /* Name was nc_strstr */
  bif_define_typed ("locate", bif_locate, &bt_integer);   /* Standard SQL function. */
  bif_define_typed ("matches_like", bif_matches_like, &bt_integer);
  bif_define_typed ("__like_min", bif_like_min, &bt_string);
  bif_define_typed ("__like_max", bif_like_max, &bt_string);
  bif_define_typed ("fix_identifier_case", bif_fix_identifier_case, &bt_varchar);
  bif_define_typed ("casemode_strcmp", bif_casemode_strcmp, &bt_integer);

/* Conversion between cases: */
  bif_define_typed ("lcase", bif_lcase, &bt_string);
  bif_define_typed ("lower", bif_lcase, &bt_string); /* Synonym to lcase */
  bif_define_typed ("ucase", bif_ucase, &bt_string);
  bif_define_typed ("upper", bif_ucase, &bt_string); /* Synonym to ucase */
  bif_define_typed ("initcap", bif_initcap, &bt_varchar); /* Name is taken from Oracle */
  bif_define_typed ("split_and_decode", bif_split_and_decode, &bt_any);   /* Does it all! */

/* Type testing functions. */
  bif_define_typed ("__tag", bif_tag, &bt_integer);   /* for sqlext.c */
  bif_define_typed ("dv_to_sql_type", bif_dv_to_sql_type, &bt_integer);   /* for sqlext.c */
  bif_define_typed ("dv_to_sql_type3", bif_dv_to_sql_type3, &bt_integer);   /* for sqlext.c */
  bif_define_typed ("internal_to_sql_type", bif_dv_to_sql_type, &bt_integer);
  bif_define_typed ("dv_type_title", bif_dv_type_title, &bt_varchar); /* needed by sqlext.c */
  bif_define_typed ("dv_buffer_length", bif_dv_buffer_length, &bt_integer); /* needed by sqlext.c */
  bif_define_typed ("table_type", bif_table_type, &bt_varchar);
  bif_define_typed ("internal_type_name", bif_dv_type_title, &bt_varchar);  /* Alias for prev */
  bif_define_typed ("internal_type", bif_internal_type, &bt_integer);
  bif_define_typed ("isinteger", bif_isinteger, &bt_integer);
  bif_define_typed ("isnumeric", bif_isnumeric, &bt_integer);
  bif_define_typed ("isfloat", bif_isfloat, &bt_integer);
  bif_define_typed ("isdouble", bif_isdouble, &bt_integer);
  bif_define_typed ("isnull", bif_isnull, &bt_integer);
  bif_define_typed ("isblob", bif_isblob_handle, &bt_integer);
  bif_define_typed ("isentity", bif_isentity, &bt_integer);
  bif_define_typed ("isstring", bif_isstring, &bt_integer);
  bif_define_typed ("isbinary", bif_isbinary, &bt_integer);
  bif_define_typed ("isarray", bif_isarray, &bt_integer);
  bif_define_typed ("isiri_id", bif_isiri_id, &bt_integer);
  bif_define_typed ("isuname", bif_isuname, &bt_integer);

  bif_define_typed ("iri_id_num", bif_iri_id_num, &bt_integer);
  bif_define_typed ("iri_id_from_num", bif_iri_id_from_num, &bt_iri);

  bif_define ("__all_eq", bif_all_eq);
  bif_define ("__max", bif_max);
  bif_define ("__min", bif_min);
  bif_define_typed ("either", bif_either, &bt_any);
  bif_define_typed ("ifnull", bif_ifnull, &bt_any);

/* Comparison functions */
  bif_define_typed ("lt", bif_lt, &bt_integer);
  bif_define_typed ("gte", bif_gte, &bt_integer);
  bif_define_typed ("gt", bif_gt, &bt_integer);
  bif_define_typed ("lte", bif_lte, &bt_integer);
  bif_define_typed ("equ", bif_equ, &bt_integer);
  bif_define_typed ("neq", bif_neq, &bt_integer);

/* Arithmetic functions. */
  bif_define_typed ("iszero", bif_iszero, &bt_integer);
  bif_define_typed ("atod", bif_atod, &bt_double);
  bif_define_typed ("atof", bif_atof, &bt_float);
  bif_define_typed ("atoi", bif_atoi, &bt_integer);
  bif_define_typed ("mod", bif_mod, &bt_integer);
  bif_define_typed ("abs", bif_abs, &bt_integer);
  bif_define_typed ("sign", bif_sign, &bt_double);
  bif_define_typed ("acos", bif_acos, &bt_double);
  bif_define_typed ("asin", bif_asin, &bt_double);
  bif_define_typed ("atan", bif_atan, &bt_double);
  bif_define_typed ("cos", bif_cos, &bt_double);
  bif_define_typed ("sin", bif_sin, &bt_double);
  bif_define_typed ("tan", bif_tan, &bt_double);
  bif_define_typed ("cot", bif_cot, &bt_double);
  bif_define_typed ("frexp", bif_frexp, &bt_double);
  bif_define_typed ("degrees", bif_degrees, &bt_double);
  bif_define_typed ("radians", bif_radians, &bt_double);
  bif_define_typed ("exp", bif_exp, &bt_double);
  bif_define_typed ("log", bif_log, &bt_double);
  bif_define_typed ("log10", bif_log10, &bt_double);
  bif_define_typed ("sqrt", bif_sqrt, &bt_double);
  bif_define_typed ("atan2", bif_atan2, &bt_double);
  bif_define_typed ("power", bif_power, &bt_double);
  bif_define_typed ("ceiling", bif_ceiling, &bt_integer);
  bif_define_typed ("floor", bif_floor, &bt_integer);
  bif_define_typed ("pi", bif_pi, &bt_double);

/* Object ids */
#ifndef O12
  bif_define ("make_oid", bif_make_oid);
  bif_define_typed ("oid_class_spec", bif_oid_class_spec, &bt_integer);
#endif

  bif_define_typed ("rnd", bif_rnd, &bt_integer);
  bif_define_typed ("rand", bif_rnd, &bt_integer); /* SQL 92 standard function */
  bif_define ("randomize", bif_randomize);
  bif_define_typed ("hash", bif_hash, &bt_integer);
  bif_define_typed ("md5_box", bif_md5_box, &bt_varchar);
/* Bitwise: */
  bif_define_typed ("bit_and", bif_bit_and, &bt_integer);
  bif_define_typed ("bit_or", bif_bit_or, &bt_integer);
  bif_define_typed ("bit_xor", bif_bit_xor, &bt_integer);
  bif_define_typed ("bit_not", bif_bit_not, &bt_integer);
  bif_define_typed ("bit_shift", bif_bit_shift, &bt_integer);

/* Miscellaneous: */
  bif_define_typed ("dbname", bif_dbname, &bt_varchar);   /* Standard system function ? */
  bif_define_typed ("get_user", bif_user, &bt_varchar);
  bif_define_typed ("pwd_magic_calc", bif_pwd_magic_calc, &bt_varchar);
  bif_define_typed ("username", bif_user, &bt_varchar);   /* Standard system function name ? */
  bif_define_typed ("disconnect_user", bif_disconnect, &bt_integer);
  bif_define_typed ("connection_id", bif_connection_id, &bt_varchar);
  bif_define ("connection_set", bif_connection_set);
  bif_define ("connection_get", bif_connection_get);
  bif_define ("connection_vars_set", bif_connection_vars_set);
  bif_define ("connection_vars", bif_connection_vars);
  bif_define ("connection_is_dirty", bif_connection_is_dirty);
  bif_define ("backup", bif_backup);
  bif_define ("db_check", bif_check);
  bif_define_typed ("vector", bif_vector, &bt_any);
  bif_define_typed ("get_keyword", bif_get_keyword, &bt_any);
  bif_define_typed ("get_keyword_ucase", bif_get_keyword_ucase, &bt_any);
  bif_define_typed ("position", bif_position, &bt_integer);
  bif_define_typed ("one_of_these", bif_one_of_these, &bt_integer);
  bif_define_typed ("row_table", bif_row_table, &bt_varchar);
  bif_define_typed ("row_column", bif_row_column, &bt_any);
  bif_define ("row_identity", bif_row_identity);
  bif_define ("row_deref", bif_row_deref);


#ifndef NDEBUG
  bif_define_typed ("dbg_row_deref_page", bif_dbg_row_deref_page, &bt_integer);
  bif_define_typed ("dbg_row_deref_pos", bif_dbg_row_deref_pos, &bt_integer);
#endif
  bif_define ("page_dump", bif_page_dump);
  bif_define ("corrupt_page", bif_corrupt_page);
  bif_define_typed ("lisp_read", bif_lisp_read, &bt_any);

  bif_define_typed ("make_array", bif_make_array, &bt_any);
  bif_define_typed ("lvector", bif_lvector, &bt_any);
  bif_define_typed ("fvector", bif_fvector, &bt_any);
  bif_define_typed ("dvector", bif_dvector, &bt_any);
  bif_define ("raw_exit", bif_raw_exit);
  bif_define_typed ("blob_to_string", bif_blob_to_string, &bt_string);
  bif_define_typed ("blob_to_string_output", bif_blob_to_string_output, &bt_varchar);
  bif_define ("blob_page", bif_blob_page);
  bif_define_typed ("_cvt", bif_convert, &bt_convert);
  bif_define ("__cast_internal", bif_cast_internal);
  st_varchar = (sql_tree_tmp *) list (3, DV_LONG_STRING, 0, 0);
  st_nvarchar = (sql_tree_tmp *) list (3, DV_LONG_WIDE, 0, 0);


  bif_define_typed ("sequence_next", bif_sequence_next, &bt_integer);
  bif_define_typed ("sequence_remove", bif_sequence_remove, &bt_integer);
  bif_define_typed ("sequence_set", bif_sequence_set, &bt_integer);
  bif_define_typed ("get_all_sequences", bif_sequence_get_all, &bt_any);
  bif_define_typed ("sequence_get_all", bif_sequence_get_all, &bt_any);
  bif_define_typed ("registry_get_all", bif_registry_get_all, &bt_any);
  bif_define_typed ("registry_get", bif_registry_get, &bt_varchar);
  bif_define_typed ("registry_name_is_protected", bif_registry_name_is_protected, &bt_integer);
  bif_define_typed ("registry_set", bif_registry_set, &bt_integer);
  bif_define_typed ("registry_remove", bif_registry_remove, &bt_integer);
  bif_define_typed ("set_qualifier", bif_set_qualifier, &bt_integer);
  bif_define_typed ("name_part", bif_name_part, &bt_varchar);
  bif_define_typed ("key_insert", bif_key_insert, &bt_integer);

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
  bif_define ("repl_text", bif_repl_text);
  bif_define ("repl_text_pushback", bif_repl_text_pushback);
  bif_define ("repl_set_raw", bif_repl_set_raw);
  bif_define ("repl_is_raw", bif_repl_is_raw);
  bif_define ("log_enable", bif_log_enable);

  bif_define_typed ("serialize", bif_serialize, &bt_any);
  bif_define_typed ("deserialize", bif_deserialize, &bt_any);
  bif_define_typed ("complete_table_name", bif_complete_table_name, &bt_varchar);
  bif_define_typed ("complete_proc_name", bif_complete_proc_name, &bt_varchar);
  bif_define_typed ("__any_grants", bif_any_grants, &bt_integer);
  bif_define_typed ("__any_grants_to_user", bif_any_grants_to_user, &bt_integer);
  bif_define ("txn_error", bif_txn_error);
  bif_define ("__trx_no", bif_trx_no);
  bif_define ("__commit", bif_commit);
  bif_define ("__rollback", bif_rollback);
  bif_define ("replay", bif_replay);
  bif_define ("txn_killall", bif_txn_killall);

  bif_define ("__ddl_changed", bif_ddl_change);
  bif_define ("__ddl_table_renamed", bif_ddl_table_renamed);
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
  bif_define_typed ("__copy", bif_copy, &bt_copy);
  bif_define_typed ("exec", bif_exec, &bt_integer);
  bif_define_typed ("exec_metadata", bif_exec_metadata, &bt_integer);
  bif_set_uses_index (bif_exec);
  bif_define_typed ("exec_next", bif_exec_next, &bt_integer);
  bif_define ("exec_close", bif_exec_close);
  bif_define ("exec_result_names", bif_exec_result_names);
  bif_define ("exec_result", bif_exec_result);
  bif_define ("__set", bif_set);
  bif_define_typed ("vector_concat", bif_vector_concatenate, &bt_any);
  bif_define ("mutex_meter", bif_mutex_meter);
  bif_define ("mutex_stat", bif_mutex_stat);
  bif_define ("self_meter", bif_self_meter);
  bif_define ("malloc_meter", bif_malloc_meter);
  bif_define ("copy_meter", bif_copy_meter);
  bif_define ("alloc_cache_status", bif_alloc_cache_status);
  bif_define_typed ("row_count", bif_row_count, &bt_integer);
  bif_define_typed ("set_row_count", bif_set_row_count, &bt_integer);
  bif_define ("__assert_found", bif_assert_found);
  bif_define ("__atomic", bif_atomic);
  bif_define ("__reset_temp", bif_clear_temp);
  bif_define ("checkpoint_interval", bif_checkpoint_interval);
  bif_define ("sql_lex_analyze", bif_sql_lex_analyze);
  bif_define ("sql_split_text", bif_sql_split_text);

  bif_define ("client_trace", bif_client_trace);

  bif_define ("__set_identity", bif_set_identity);
  bif_define ("__set_user_id", bif_set_user_id);
  bif_define ("set_user_id", bif_set_user_id);
  bif_define ("__pop_user_id", bif_pop_user_id);
  bif_define ("identity_value", bif_identity_value);
  fcache_init ();
  bif_define ("mem_enter_reserve_mode", bif_mem_enter_reserve_mode);
  bif_define ("mem_debug_enabled", bif_mem_debug_enabled);
#ifdef MALLOC_DEBUG
  bif_define ("mem_all_in_use", bif_mem_all_in_use);
  bif_define ("mem_new_in_use", bif_mem_new_in_use);
  bif_define ("mem_leaks", bif_mem_leaks);
  bif_define ("mem_get_current_total", bif_mem_get_current_total);
#endif
#ifdef MALLOC_STRESS
  bif_define ("set_hard_memlimit", bif_set_hard_memlimit);
  bif_define ("set_hot_memlimit", bif_set_hot_memlimit);
#endif
  bif_define ("sqlo_enable", bif_sqlo);
  bif_define ("hic_clear", bif_hic_clear);

  bif_define ("icc_try_lock", bif_icc_try_lock);
  bif_define ("icc_lock_at_commit", bif_icc_lock_at_commit);
  bif_define ("icc_unlock_now", bif_icc_unlock_now);

  /* for system use only ruslan@openlinksw.com */
  bif_define ("raw_length", bif_raw_length);

  /* check byteoreder in the log */
  bif_define ("byte_order_check", bif_byte_order_check);

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

  sqlbif2_init ();
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
  bif_uuencode_init();
  bif_udt_init();

  bif_xmlenc_init();

  bif_fillup_system_tables_hash();
  init_pwd_magic_users ();
  bif_define ("__grouping", bif_grouping);
  bif_define ("__grouping_set_bitmap", bif_grouping_set_bitmap);
  bif_hosting_init ();

  bif_diff_init();
  return;
}


dk_set_t bif_index_users = NULL;

void
bif_set_uses_index (bif_t  bif)
{
  dk_set_push (&bif_index_users, (void*) bif);
}

int
bif_uses_index (bif_t bif)
{
  if (bif_key_insert == bif || bif_row_deref == bif)
  return 1;
  if (dk_set_member (bif_index_users, (void*) bif))
  return 1;

  return 0;
}

char * bpel_check_proc =
"create procedure RESTART_ALL_BPEL_INSTANCES ()\n"
"{\n"
"  declare pkgs any;\n"
"  pkgs := \"VAD\".\"DBA\".\"VAD_GET_PACKAGES\" ();\n"
"  if (pkgs is not null)\n"
"    {\n"
"      declare idx int;\n"
"      while (idx < length (pkgs))\n"
"        {\n"
"          if (pkgs[idx][1] = 'bpel4ws')\n"
"            {\n"
"              BPEL..restart_all_instances();\n"
"            }\n"
"          idx := idx + 1;\n"
"        }\n"
"    }\n"
"}\n";

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
  ddl_ensure_table ("do this always", bpel_check_proc);
  ddl_ensure_table ("do this always", bpel_run_check_proc);
}
