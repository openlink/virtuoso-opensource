/*
 *  bif_intl.c
 *
 *  $Id$
 *
 *  Internationalization functions
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

#if !defined (__APPLE__)
#include <wchar.h>
#endif
#include <limits.h>
#include "http.h" /* For WS_CHARSET */
#include "wi.h"
#include "libutil.h"
#include "sqlnode.h"
#include "eqlcomp.h"
#include "sqlfn.h"
#include "sqlbif.h"
#include "multibyte.h"
#include "srvmultibyte.h"
#include "xml.h"
#include "security.h"
#ifdef __cplusplus
extern "C" {
#endif
#include "xmlparser.h"
/*#include "xmlparser_impl.h"*/
#include "langfunc.h"
#ifdef __cplusplus
}
#endif


/* adds a collation to the collations hash table (global_collations) */
static caddr_t
bif_collation__define (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  /* params :
     0 in  name
     1 in  collation table
     2 in  is_wide
   */

  caddr_t table = bif_string_or_wide_or_null_arg (qst, args, 1, "collation__define");
  caddr_t name = sqlp_box_id_upcase (bif_string_arg (qst, args, 0, "collation__define"));
  dtp_t dtp = DV_TYPE_OF (table);
  NEW_VARZ(collation_t, coll);

  if (dtp == DV_STRING || dtp == DV_C_STRING)
    {
      coll->co_table = dk_alloc_box (256 + 1, DV_C_STRING);
      memset (coll->co_table, 255, 256 + 1);
      memcpy (coll->co_table, table, box_length(table));
    }
  else if (IS_WIDE_STRING_DTP (dtp))
    {
      coll->co_table = dk_alloc_box ((65536 + 1) * sizeof (wchar_t), DV_WIDE);
      memset (coll->co_table, 255, (65536 + 1) * sizeof (wchar_t));
      memcpy (coll->co_table, table, box_length(table));
      coll->co_is_wide = 1;
    }


  coll->co_name = box_string (name);
  dk_free_box (name);
  id_hash_set (global_collations, (caddr_t) & coll->co_name, (caddr_t) & coll);
  return box_num (0);
}

static caddr_t
bif_charset_define (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  /* params :
     0 in  name
     1 in  128 elem collation table
     2 in  aliases list
   */
  caddr_t name = bif_string_arg (qst, args, 0, "charset_define");
  caddr_t _table = bif_arg (qst, args, 1, "charset_define");
  caddr_t *aliases = (caddr_t *) bif_array_or_null_arg (qst, args, 2, "charset_define");
  wchar_t *table = (wchar_t *)_table;
  wcharset_t *wcharset;
  dtp_t vectype = DV_TYPE_OF (table);
  caddr_t name_copy = NULL;
  int i;

  if (!strcmp (name, "UTF-8"))
    sqlr_new_error ("2C000", "IN001", "The UTF-8 is not a redefinable charset");
  if (vectype == DV_DB_NULL)
    {
      table = NULL;
    }
  else if (!IS_WIDE_STRING_DTP (vectype))
    {
      sqlr_new_error ("2C000", "IN002", "charset_define : Charset table not a wide string");
    }
  for (i = 0; i < (int) (box_length (_table) / sizeof (wchar_t) - 1); i++)
    if (!table[i])
      sqlr_new_error ("2C000", "IN003", "charset_define : 0 not allowed as a charset definition");

  wcharset = sch_name_to_charset (name);
  if (wcharset)
    {
      /*
      if (default_charset == wcharset)
	default_charset = NULL;
      wide_charset_free (wcharset);
      */
      sqlr_new_error ("2C000", "IN004", "charset %s already defined. Drop it first", name);
      return box_wide_char_string ((caddr_t) (&wcharset->chrs_table[1]), 255 * sizeof (wchar_t), DV_WIDE);
    }
  wcharset = wide_charset_create (name, table, box_length (_table) / sizeof (wchar_t) - 1,
      (char **) (aliases ? box_copy_tree ((box_t) aliases) : NULL));
  name_copy = box_dv_short_string (wcharset->chrs_name);
  if (!default_charset && default_charset_name && !strcmp (default_charset_name, name))
    default_charset = wcharset;
  id_hash_set (global_wide_charsets, (caddr_t) &name_copy, (caddr_t) &wcharset);
  DO_BOX (caddr_t, cs_alias, i, aliases)
    {
      if (!DV_STRINGP (cs_alias))
	sqlr_new_error ("2C000", "IN005", "Alias %d not of type STRING", i + 1);
      else
	{
	  name_copy = box_dv_short_string (cs_alias);
	  if (!default_charset && default_charset_name && !strcmp (default_charset_name, cs_alias))
	    default_charset = wcharset;
	  id_hash_set (global_wide_charsets, (caddr_t) &name_copy, (caddr_t) &wcharset);
	}
    }
  END_DO_BOX;
  return box_wide_char_string ((caddr_t) (&wcharset->chrs_table[1]), 255 * sizeof (wchar_t), DV_WIDE);
}

static caddr_t
bif_charset_canonical_name (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t name = bif_string_arg (qst, args, 0, "charset_canonical_name");
  wcharset_t *wcharset;
  if (!strcasecmp (name, "UTF-8"))
    return box_copy (name);
  wcharset = sch_name_to_charset (name);
  if (NULL == wcharset)
    {
      int ctr;
      caddr_t ucname = box_copy (name);
      for (ctr = box_length (ucname) - 1; ctr--; /*no step*/)
        ucname[ctr] = toupper (ucname[ctr]);
      wcharset = sch_name_to_charset (ucname);
      dk_free_box (ucname);
    }
  if (NULL != wcharset)
    return box_dv_short_string (wcharset->chrs_name);
  return NEW_DB_NULL;
}

#define DEFAULT_EXISTING 1

/* completes the collation name the same way as a non-fully qualified table name is
   completed
*/
caddr_t
bif_complete_collation_name (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  /* params :
     0 - in non-fully qualified collation name
     1 - in mode (1 - complete in favor of an existing collation;
	       0 - get the defaults from the current user
  */
  caddr_t result;
  caddr_t coll_name = bif_string_arg (qst, args, 0, "complete_collation_name");
  ptrlong mode = bif_long_arg (qst, args, 1, "complete_collation_name");
  query_instance_t *qi = (query_instance_t *) qst;
  collation_t *coll = NULL;
  client_connection_t *old_cli = sqlc_client();
  sqlc_set_client (qi->qi_client);
  if (mode == DEFAULT_EXISTING)
    coll = sch_name_to_collation (coll_name);
  if (coll)
    {
      result = box_dv_short_string (coll->co_name);
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
      sch_split_name (qi->qi_client->cli_qualifier, coll_name, q, o, n);
      if (0 == o[0])
	strcpy_ck (o, cli_owner (qi->qi_client));
      snprintf (complete, sizeof (complete), "%s.%s.%s", q, o, n);
      result = box_dv_short_string (complete);
    }
  if (CM_UPPER == case_mode && result)
    sqlp_upcase (result);
  sqlc_set_client (old_cli);
  return result;
}


/* translates a string into it's collation weight equivalent
   (by replacing each character with it's collation table lookup value).
   The output is suitable for functions like strstr, strchr etc
*/
caddr_t
bif_collation_order_string (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  /* params :
     0 - in collation name
     1 - in the string to transform
  */
  caddr_t coll_name = bif_string_arg (qst, args, 0, "complete_collation_name");
  caddr_t string = bif_string_arg (qst, args, 1, "complete_collation_name");
  caddr_t dest = box_dv_short_string (string);
  collation_t *coll = sch_name_to_collation (coll_name);
  unsigned char *curr;

  if (!coll)
    sqlr_new_error ("22023", "IN006", "Collation %s not defined", coll_name);

  for (curr = (unsigned char *) dest; *curr; curr++)
    *curr = coll->co_table[*curr];
  return dest;
}


caddr_t
bif_current_charset (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  wcharset_t *charset = QST_CHARSET (qst);
  return box_dv_short_string (CHARSET_NAME (charset, "ISO-8859-1"));
}

caddr_t
literal_as_utf8 (encoding_handler_t * enc, caddr_t literal, int len)
{
  const char *srctail = literal;
  unichar *uni = NULL;
  size_t uni_alloc_len;
  int uni_len, utfeight_buf_len;
  char *utfeight_buf, *utfeight_buf_tail, *utfeight;
  int eh_state = 0;
  if (!len)
    {
      utfeight = dk_alloc_box (1, DV_SHORT_STRING);
      utfeight[0] = '\0';
      return utfeight;
    }
  uni_alloc_len = len*sizeof (unichar);
  uni = (unichar *)dk_alloc (uni_alloc_len);
  uni_len = enc->eh_decode_buffer (uni, len, &srctail, literal+len, enc, &eh_state);
  if (uni_len < 0)
    {
      dk_free (uni,uni_alloc_len);
      if (uni_len == UNICHAR_NO_DATA)
	{
	  sqlr_new_error ("2C000", "IN008", "Unexpected truncation of the first character");
	}
      sqlr_new_error ("2C000", "IN008", "Unknown encoding error");
    }
  else
    {
      if (srctail != literal+len)
	{
	  dk_free (uni,uni_alloc_len);
	  sqlr_new_error ("2C000", "IN008", "Unexpected truncation of the first character");
	}
    }
  utfeight_buf_len = uni_len * MAX_UTF8_CHAR + 1;
  utfeight_buf = (char *) dk_alloc (utfeight_buf_len);
  utfeight_buf_tail = eh_encode_buffer__UTF8 (uni, uni+uni_len, utfeight_buf, utfeight_buf+utfeight_buf_len);
  utfeight_buf_tail[0] = '\0';
  utfeight = box_dv_short_string (utfeight_buf);
  dk_free (uni,uni_alloc_len);
  dk_free (utfeight_buf, utfeight_buf_len);
  return utfeight;
}

caddr_t
charset_recode_from_named_to_named (caddr_t narrow, const char *cs1_uppercase, const char *cs2_uppercase, int *res_is_new_ret, caddr_t *err_ret)
{
  wcharset_t *cs1, *cs2;
  int bom_skip_offset = 0;
  encoding_handler_t *eh_cs1 = NULL;
  res_is_new_ret[0] = 0;

  cs1 = (cs1_uppercase && box_length (cs1_uppercase) > 1 ? sch_name_to_charset (cs1_uppercase) : (wcharset_t *)NULL);
  cs2 = (cs2_uppercase && box_length (cs2_uppercase) > 1 ? sch_name_to_charset (cs2_uppercase) : (wcharset_t *)NULL);

  if (cs1_uppercase && !cs1 && !strcmp (cs1_uppercase, "UTF-8"))
    cs1 = CHARSET_UTF8;
  if (cs2_uppercase && !cs2 && !strcmp (cs2_uppercase, "UTF-8"))
    cs2 = CHARSET_UTF8;
  if (cs1_uppercase && !cs1 && !strcmp (cs1_uppercase, "_WIDE_"))
    cs1 = CHARSET_WIDE;
  if (cs2_uppercase && !cs2 && !strcmp (cs2_uppercase, "_WIDE_"))
    cs2 = CHARSET_WIDE;

  if (!cs1 && cs1_uppercase && box_length (cs1_uppercase) > 1)
    {
      if (!stricmp (cs1_uppercase, "UTF-16") && box_length (narrow) > 2
	  && (unsigned char)(narrow[0]) == 0xFF && (unsigned char)(narrow[1]) == 0xFE)
	{
          bom_skip_offset = 2;
	  eh_cs1 = eh_get_handler ("UTF-16LE");
	}
      else if (!stricmp (cs1_uppercase, "UTF-16") && box_length (narrow) > 2
	  && (unsigned char)(narrow[0]) == 0xFE && (unsigned char)(narrow[1]) == 0xFF)
	{
	  bom_skip_offset = 2;
	  eh_cs1 = eh_get_handler ("UTF-16BE");
	}
      else if (!stricmp (cs1_uppercase, "UTF-16"))
        { err_ret[0] = srv_make_new_error ("2C000", "IN000", "UTF-16 specified, but no byte-order-mask is given"); return NULL; }
      else
	eh_cs1 = eh_get_handler (cs1_uppercase);
      if (!eh_cs1)
        { err_ret[0] = srv_make_new_error ("2C000", "IN007", "Charset %s not defined", cs1_uppercase); return NULL; }
    }

  if (!cs2 && cs2_uppercase && box_length (cs2_uppercase) > 1)
    sqlr_new_error ("2C000", "IN008", "Charset %s not defined", cs2_uppercase);

  if (!cs1)
    cs1 = default_charset;
  if (!cs2)
    cs2 = default_charset;
  return charset_recode_from_cs_or_eh_to_cs (narrow, bom_skip_offset, eh_cs1, cs1, cs2, res_is_new_ret, err_ret);
}

caddr_t
charset_recode_from_cs_or_eh_to_cs (caddr_t narrow, int bom_skip_offset, encoding_handler_t *eh_cs1, wcharset_t *cs1, wcharset_t *cs2, int *res_is_new_ret, caddr_t *err_ret)
{
  int inx, to_free = 0;
  caddr_t ret = NULL;
  dtp_t dtp = DV_TYPE_OF (narrow);
  if ((DV_UNAME == dtp) && (cs1 != CHARSET_UTF8))
    { err_ret[0] = srv_make_new_error ("2C000", "IN016", "Function got a UNAME argument and the source encoding is not UTF-8; this is illegal because UNAMEs are always UTF-8"); return NULL; }
  if (IS_WIDE_STRING_DTP (dtp) && cs1 != CHARSET_WIDE)
    { err_ret[0] = srv_make_new_error ("2C000", "IN012", "Narrow source charset specified, but the supplied string is wide"); return NULL; }
  if (IS_STRING_DTP (dtp) && cs1 == CHARSET_WIDE)
    { err_ret[0] = srv_make_new_error ("2C000", "IN013", "Wide source charset specified, but the supplied string not wide"); return NULL; }
  ASSERT_BOX_ENC_MATCHES_BF (narrow, ((CHARSET_UTF8 == cs1) ? BF_UTF8 : ((default_charset == cs1) ? BF_DEFAULT_SERVER_ENC : 0)));
  if (eh_cs1)
    {
      narrow = literal_as_utf8 (eh_cs1, narrow + bom_skip_offset, box_length (narrow) - (1 + bom_skip_offset)); /* this alloc a box */
      to_free = 1;
      dtp = DV_TYPE_OF (narrow);
      cs1 = CHARSET_UTF8;
    }


  if (IS_WIDE_STRING_DTP (dtp))
    {
      if (cs2 == CHARSET_WIDE)
	ret = box_copy (narrow);
      else if (cs2 == CHARSET_UTF8)
	ret = box_wide_as_utf8_char (narrow, box_length (narrow) / sizeof (wchar_t) - 1, DV_SHORT_STRING);
      else
	ret = box_wide_string_as_narrow (narrow, NULL, 0, cs2);
      res_is_new_ret[0] = 1;
    }
  else if (cs1 == cs2 || !DV_STRINGP (narrow))
    {
      ret = narrow;
      res_is_new_ret[0] = to_free;
      to_free = 0;
    }
  else if (cs1 == CHARSET_UTF8)
    {
      if (cs2 == CHARSET_WIDE)
	ret = box_utf8_as_wide_char (narrow, NULL, box_length (narrow) - 1, 0, DV_WIDE);
      else
	ret = box_utf8_string_as_narrow (narrow, NULL, 0, cs2);
      res_is_new_ret[0] = 1;
    }
  else
    {
      if (cs2 == CHARSET_WIDE)
	ret = box_narrow_string_as_wide ((unsigned char *) narrow, NULL, 0, cs1, err_ret, 1);
      else if (cs2 == CHARSET_UTF8)
	ret = box_narrow_string_as_utf8 (NULL, narrow, 0, cs1, err_ret, 1);
      else
	{
	  caddr_t output = box_copy (narrow);
	  for (inx = 0; inx < (int) (box_length (output) - 1); inx++)
	    output[inx] = WCHAR_TO_CHAR (CHAR_TO_WCHAR (output[inx], cs1), cs2);
	  ret = output;
	}
      res_is_new_ret[0] = 1;
    }
  if (to_free)
    dk_free_box (narrow);
  return ret;
}

caddr_t
bif_charset_recode (caddr_t *qst, caddr_t *err_ret, state_slot_t ** args)
{
  caddr_t narrow = bif_string_or_uname_or_wide_or_null_arg (qst, args, 0, "charset_recode");
  caddr_t cs1_name = bif_string_or_null_arg (qst, args, 1, "charset_recode");
  caddr_t cs2_name = bif_string_or_null_arg (qst, args, 2, "charset_recode");
  caddr_t cs1_uname, cs2_uname, res;
  int res_is_new = 0;
  caddr_t err = NULL;
  if (!narrow)
    return NEW_DB_NULL;

  cs1_uname = cs1_name ? sqlp_box_upcase (cs1_name) : NULL;
  cs2_uname = cs2_name ? sqlp_box_upcase (cs2_name) : NULL;
  res = charset_recode_from_named_to_named (narrow, cs1_uname, cs2_uname, &res_is_new, &err);
  dk_free_box (cs1_uname); dk_free_box (cs2_uname);
  if (NULL != err)
    {
      if (res_is_new)
        dk_free_box (res);
      sqlr_resignal (err);
    }
  if (res_is_new)
    return res;
  return box_copy (res);
}

wcharset_t *
charset_native_for_box (ccaddr_t box, int expected_bf_if_zero)
{
  ASSERT_BOX_ENC_MATCHES_BF (box, expected_bf_if_zero);
  switch (DV_TYPE_OF (box))
    {
    case DV_UNAME: return CHARSET_UTF8;
    case DV_WIDE: return CHARSET_WIDE;
    case DV_STRING:
      {
        int bf = box_flags (box);
        if (0 == (bf & (BF_IRI | BF_UTF8 | BF_DEFAULT_SERVER_ENC)))
          bf = expected_bf_if_zero;
        if (bf & (BF_IRI | BF_UTF8))
          return CHARSET_UTF8;
        return default_charset;
      }
    }
  return NULL;
}

caddr_t
bif_bf_text_to_UTF8 (caddr_t *qst, caddr_t *err_ret, state_slot_t ** args)
{
  wcharset_t *cs;
  int expected_bf_if_zero;
  caddr_t narrow = bif_string_or_uname_or_wide_or_null_arg (qst, args, 0, "bf_text_to_UTF8");
  caddr_t cs_name = bif_string_or_null_arg (qst, args, 1, "bf_text_to_UTF8");
  caddr_t res;
  int res_is_new = 0;
  caddr_t err = NULL;
  if (!narrow)
    return NEW_DB_NULL;
  expected_bf_if_zero = ((NULL == cs_name) ? ((CHARSET_UTF8 == default_charset) ? BF_UTF8 : 0) : (!strcasecmp (cs_name, "UTF-8") ? BF_UTF8 : 0));
  cs = charset_native_for_box (narrow, expected_bf_if_zero);
  res = charset_recode_from_cs_or_eh_to_cs (narrow, 0, NULL, cs, CHARSET_UTF8, &res_is_new, &err);
  if (NULL != err)
    {
      if (res_is_new)
        dk_free_box (res);
      sqlr_resignal (err);
    }
  if (res_is_new)
    return res;
  return box_copy (res);
}

caddr_t
bif_bf_text_to_UTF8_or_wide (caddr_t *qst, caddr_t *err_ret, state_slot_t ** args)
{
  wcharset_t *cs;
  int expected_bf_if_zero;
  caddr_t narrow = bif_string_or_uname_or_wide_or_null_arg (qst, args, 0, "bf_text_to_UTF8_or_wide");
  caddr_t cs_name = bif_string_or_null_arg (qst, args, 1, "bf_text_to_UTF8_or_wide");
  caddr_t res;
  int res_is_new = 0;
  caddr_t err = NULL;
  if (!narrow)
    return NEW_DB_NULL;
  expected_bf_if_zero = ((NULL == cs_name) ? ((CHARSET_UTF8 == default_charset) ? BF_UTF8 : 0) : (!strcasecmp (cs_name, "UTF-8") ? BF_UTF8 : 0));
  cs = charset_native_for_box (narrow, expected_bf_if_zero);
  if (CHARSET_WIDE == cs)
    return box_copy (narrow);
  res = charset_recode_from_cs_or_eh_to_cs (narrow, 0, NULL, cs, CHARSET_UTF8, &res_is_new, &err);
  if (NULL != err)
    {
      if (res_is_new)
        dk_free_box (res);
      sqlr_resignal (err);
    }
  if (res_is_new)
    return res;
  return box_copy (res);
}

caddr_t
bif_uname (caddr_t *qst, caddr_t *err_ret, state_slot_t ** args)
{
  caddr_t narrow = bif_string_or_uname_or_wide_or_null_arg (qst, args, 0, "uname");
  caddr_t cs1_name = NULL;
  int allow_long = 0;
  caddr_t cs1_uname;
  wcharset_t *cs1;
  int offset = 0;
  encoding_handler_t *eh_cs1 = NULL;
  dtp_t dtp = DV_TYPE_OF (narrow);
  if (!narrow)
    return NEW_DB_NULL;
  switch (BOX_ELEMENTS (args))
    {
    default:
    case 3: allow_long = bif_long_arg (qst, args, 2, "uname");
    case 2: cs1_name = bif_string_or_null_arg (qst, args, 1, "uname");
    case 1:
      if (DV_UNAME == dtp)
        return box_copy (narrow);
      break;
    }
  cs1_uname = cs1_name ? sqlp_box_upcase (cs1_name) : NULL;

  cs1 = (cs1_name && box_length (cs1_name) > 1 ? sch_name_to_charset (cs1_uname) : (wcharset_t *)NULL);
  if (cs1_uname && !cs1 && !strcmp (cs1_uname, "UTF-8"))
    cs1 = CHARSET_UTF8;
  if (cs1_uname && !cs1 && !strcmp (cs1_uname, "_WIDE_"))
    cs1 = CHARSET_WIDE;
  dk_free_box (cs1_uname);
  if (!narrow)
    return narrow;

  if (!cs1 && cs1_name && box_length (cs1_name) > 1)
    {
      if (!stricmp (cs1_name, "UTF-16") && box_length (narrow) > 2
	  && (unsigned char)(narrow[0]) == 0xFF && (unsigned char)(narrow[1]) == 0xFE)
	{
          offset = 2;
	  eh_cs1 = eh_get_handler ("UTF-16LE");
	}
      else if (!stricmp (cs1_name, "UTF-16") && box_length (narrow) > 2
	  && (unsigned char)(narrow[0]) == 0xFE && (unsigned char)(narrow[1]) == 0xFF)
	{
	  offset = 2;
	  eh_cs1 = eh_get_handler ("UTF-16BE");
	}
      else if (!stricmp (cs1_name, "UTF-16"))
	sqlr_new_error ("2C000", "IN000", "UTF-16 specified, but no byte-order-mask is given");
      else
	eh_cs1 = eh_get_handler (cs1_name);
      if (!eh_cs1)
        sqlr_new_error ("2C000", "IN007", "Charset %s not defined", cs1_name);
    }

  if (!cs1)
    cs1 = default_charset;
  if (DV_UNAME == dtp)
    {
      if (cs1 != CHARSET_UTF8)
        sqlr_new_error ("2C000", "IN016", "Function uname() got a UNAME argument and the source encoding is not UTF-8; this is illegal because UNAMEs are always UTF-8");
      return box_copy (narrow);
    }
  if (IS_WIDE_STRING_DTP (dtp) && cs1 != CHARSET_WIDE)
    sqlr_new_error ("2C000", "IN012", "Narrow source charset specified, but the supplied string is wide");
  if (IS_STRING_DTP (dtp) && cs1 == CHARSET_WIDE)
    sqlr_new_error ("2C000", "IN013", "Wide source charset specified, but the supplied string not wide");

  if (eh_cs1)
    {
      caddr_t strg = literal_as_utf8 (eh_cs1, narrow+offset, box_length (narrow) - (1+offset)); /* this alloc a box */
      caddr_t res = box_dv_uname_nchars (strg, box_length (strg) - 1);
      dk_free_box (strg);
      return res;
    }

  if (IS_WIDE_STRING_DTP (dtp))
    {
      caddr_t strg = box_wide_as_utf8_char (narrow, box_length (narrow) / sizeof (wchar_t) - 1, DV_SHORT_STRING);
      caddr_t res = box_dv_uname_nchars (strg, box_length (strg) - 1);
      dk_free_box (strg);
      return res;
    }
  else if (!DV_STRINGP (narrow))
    sqlr_new_error ("2C000", "IN017", "First argument of uname() function should be a narrow or wide string, or NULL or a UNAME");
  else if (cs1 != CHARSET_UTF8)
    {
      caddr_t res = NULL;
      caddr_t strg = box_narrow_string_as_utf8 (NULL, narrow, 0, cs1, err_ret, 1);
      if (!*err_ret)
	res = box_dv_uname_nchars (strg, box_length (strg) - 1);
      dk_free_box (strg);
      return res;
    }
  return box_dv_uname_nchars (narrow, box_length (narrow) - 1);
}

extern caddr_t box_cast_to_UTF8_uname (caddr_t *qst, caddr_t raw_name);

caddr_t
bif_quick_uname (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t strg = bif_string_or_uname_or_wide_or_null_arg (qst, args, 0, "__uname");
  if (NULL == strg)
    return NEW_DB_NULL;
  return box_cast_to_UTF8_uname (qst, strg);
}

static int
charset_compare (const void *cs1_ptr, const void *cs2_ptr)
{
  return strcmp (* (const char **)cs1_ptr, * (const char **)cs2_ptr);
}

caddr_t
bif_charsets_list (caddr_t *qst, caddr_t *err_ret, state_slot_t ** args)
{
  dk_set_t set = NULL;
  id_hash_iterator_t it;
  char **name;
  wcharset_t **charset;
  caddr_t output;
  ptrlong make_resultset = bif_long_arg (qst, args, 0, "charsets_list");
  if (make_resultset)
    {
      state_slot_t sample;
      state_slot_t **sbox;

      sbox = (state_slot_t **) dk_alloc_box (sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      memset (&sample, 0, sizeof (sample));
      sbox[0] = &sample;

      sample.ssl_name = box_dv_uname_string ("CS_NAME");
      sample.ssl_type = SSL_COLUMN;
      sample.ssl_dtp = DV_SHORT_STRING;
      sample.ssl_prec = 200;

      bif_result_names (qst, err_ret, sbox);

      dk_free_box ((caddr_t) sbox);
      dk_free_box (sample.ssl_name);

      if (*err_ret)
	return NULL;
    }

  id_hash_iterator (&it, global_wide_charsets);
  while (hit_next (&it, (caddr_t *) &name, (caddr_t *) &charset))
    dk_set_push (&set, box_copy (*name));

  output = list_to_array (set);
  qsort (output, BOX_ELEMENTS (output), sizeof (caddr_t), charset_compare);
  if (make_resultset)
    {
      int inx;
      DO_BOX (caddr_t, cs_name, inx, ((caddr_t *) output))
	{
	  bif_result_inside_bif (1, cs_name);
	}
      END_DO_BOX;
    }
  return output;
}


caddr_t
bif_unicode_toupper (caddr_t *qst, caddr_t *err_ret, state_slot_t ** args)
{
  unichar uchr = (unichar)bif_long_arg (qst, args, 0, "unicode_toupper");
  unichar res = unichar_getucase ((unichar)uchr);
  return box_num (res);
}


caddr_t
bif_unicode_tolower (caddr_t *qst, caddr_t *err_ret, state_slot_t ** args)
{
  unichar uchr = (unichar)bif_long_arg (qst, args, 0, "unicode_toupper");
  unichar res = unichar_getlcase (uchr);
  return box_num (res);
}


caddr_t
bif_unicode_char_properties (caddr_t *qst, caddr_t *err_ret, state_slot_t ** args)
{
  unichar uchr = (unichar)bif_long_arg (qst, args, 0, "unicode_char_properties");
  ptrlong mode = ((BOX_ELEMENTS(args) > 1) ? bif_long_arg (qst, args, 1, "unicode_char_properties") : 0);
  int prop = unichar_getprops (uchr);
  int ub_idx;
  dk_set_t res = NULL;
  if (0 == mode)
    return box_num (prop);
  dk_set_push (&res, box_num(prop));
  for (ub_idx = raw_uniblocks_fill; ub_idx--; /* no step */)
    {
      unicode_block_t *ub = raw_uniblocks_array + ub_idx;
      if ((ub->ub_min > uchr) || (ub->ub_max < uchr))
	continue;
      dk_set_push (&res,
	list (4,
	  box_dv_short_string (ub->ub_descr), box_num (ub->ub_props),
	  box_num (ub->ub_min), box_num (ub->ub_max) ) );
    }
  return list_to_array (dk_set_nreverse(res));
}


static unichar
eh_decode_char__wcharset_narrow (__constcharptr *src_begin_ptr, const char *src_buf_end, ...)
{
  if (*src_begin_ptr < src_buf_end)
    {
      unsigned char cursrc = src_begin_ptr[0][0];
      va_list tail;
      encoding_handler_t *my_eh;
      wcharset_t *my_charset;
      va_start(tail, src_buf_end);
      my_eh = va_arg (tail, encoding_handler_t *);
      my_charset = (wcharset_t *)(my_eh->eh_appdata);
      src_begin_ptr[0] += 1;
      return (unichar) CHAR_TO_WCHAR (cursrc, my_charset);
    }
  return UNICHAR_EOD;
}


static unichar
eh_decode_char__wcharset_wide (__constcharptr *src_begin_ptr, const char *src_buf_end, ...)
{
  if (((char *)(((wchar_t **)src_begin_ptr)[0]+1)) <= src_buf_end)
    {
      wchar_t curwide = ((wchar_t **)src_begin_ptr)[0][0];
      va_list tail;
      encoding_handler_t *my_eh;
      wcharset_t *my_charset;
      if (curwide & ~0xFF)
	return UNICHAR_BAD_ENCODING;
      va_start(tail, src_buf_end);
      my_eh = va_arg (tail, encoding_handler_t *);
      my_charset = (wcharset_t *)(my_eh->eh_appdata);
      ((wchar_t **)src_begin_ptr)[0] += 1;
      return (unichar) CHAR_TO_WCHAR ((unsigned char)(curwide), my_charset);
    }
  return UNICHAR_EOD;
}


static
int eh_decode_buffer__wcharset_narrow (unichar *tgt_buf, int tgt_buf_len, __constcharptr *src_begin_ptr, const char *src_buf_end, ...)
{
  int res = 0;
  va_list tail;
  encoding_handler_t *my_eh;
  wcharset_t *my_charset;
  va_start(tail, src_buf_end);
  my_eh = va_arg (tail, encoding_handler_t *);
  my_charset = (wcharset_t *)(my_eh->eh_appdata);
  while((tgt_buf_len>0) && (src_buf_end > src_begin_ptr[0]))
    {
      unsigned char cursrc = src_begin_ptr[0][0];
      unichar curtgt = (unichar) CHAR_TO_WCHAR (cursrc, my_charset);
      src_begin_ptr[0] += 1;
      (tgt_buf++)[0] = curtgt;
      tgt_buf_len--;
      res++;
    }
  return res;
}


static
int eh_decode_buffer__wcharset_wide (unichar *tgt_buf, int tgt_buf_len, __constcharptr *src_begin_ptr, const char *src_buf_end, ...)
{
  int res = 0;
  va_list tail;
  encoding_handler_t *my_eh;
  wcharset_t *my_charset;
  va_start(tail, src_buf_end);
  my_eh = va_arg (tail, encoding_handler_t *);
  my_charset = (wcharset_t *)(my_eh->eh_appdata);
  while((tgt_buf_len>0) && (src_buf_end >= (char *)(((wchar_t **)src_begin_ptr)[0]+1)))
    {
      wchar_t curwide = ((wchar_t **)src_begin_ptr)[0][0];
      unichar curtgt = (unichar) CHAR_TO_WCHAR ((unsigned char)curwide, my_charset);
      ((wchar_t **)src_begin_ptr)[0] += 1;
      (tgt_buf++)[0] = curtgt;
      tgt_buf_len--;
      res++;
    }
  return res;
}


char *eh_encode_char__wcharset_narrow (unichar char_to_put, char *tgt_buf, char *tgt_buf_end, ...)
{
  if (tgt_buf >= tgt_buf_end)
    return (char *)UNICHAR_NO_ROOM;
  if (char_to_put >= 0)
    {
      va_list tail;
      encoding_handler_t *my_eh;
      wcharset_t *my_charset;
      va_start(tail, tgt_buf_end);
      my_eh = va_arg (tail, encoding_handler_t *);
      my_charset = (wcharset_t *)(my_eh->eh_appdata);
      tgt_buf[0] = WCHAR_TO_CHAR ((wchar_t)char_to_put, my_charset);
      return tgt_buf+1;
    }
  return tgt_buf;
}


char *eh_encode_char__wcharset_wide (unichar char_to_put, char *tgt_buf, char *tgt_buf_end, ...)
{
  if ((char *)((((wchar_t *)tgt_buf)+1)) > tgt_buf_end)
    return (char *)UNICHAR_NO_ROOM;
  if (char_to_put >= 0)
    {
      va_list tail;
      encoding_handler_t *my_eh;
      wcharset_t *my_charset;
      va_start(tail, tgt_buf_end);
      my_eh = va_arg (tail, encoding_handler_t *);
      my_charset = (wcharset_t *)(my_eh->eh_appdata);
      ((wchar_t *)tgt_buf)[0] = (wchar_t)(WCHAR_TO_CHAR ((wchar_t)char_to_put, my_charset));
      return (char *)(((wchar_t *)tgt_buf)+1);
    }
  return tgt_buf;
}


static
char *eh_encode_buffer__wcharset_narrow (const unichar *src_buf, const unichar *src_buf_end, char *tgt_buf, char *tgt_buf_end, ...)
{
  va_list tail;
  encoding_handler_t *my_eh;
  wcharset_t *my_charset;
  va_start(tail, tgt_buf_end);
  my_eh = va_arg (tail, encoding_handler_t *);
  my_charset = (wcharset_t *)(my_eh->eh_appdata);
  if ((tgt_buf_end-tgt_buf) < (src_buf_end-src_buf))
    return (char *)UNICHAR_NO_ROOM;
  while (src_buf < src_buf_end)
    {
      char char_to_put = (src_buf++)[0];
      tgt_buf[0] = WCHAR_TO_CHAR ((wchar_t)char_to_put, my_charset);
      tgt_buf++;
    }
  return tgt_buf;
    }


static
char *eh_encode_buffer__wcharset_wide (const unichar *src_buf, const unichar *src_buf_end, char *tgt_buf, char *tgt_buf_end, ...)
{
  va_list tail;
  encoding_handler_t *my_eh;
  wcharset_t *my_charset;
  va_start(tail, tgt_buf_end);
  my_eh = va_arg (tail, encoding_handler_t *);
  my_charset = (wcharset_t *)(my_eh->eh_appdata);
  if (((wchar_t *)tgt_buf_end-(wchar_t *)tgt_buf) < (src_buf_end-src_buf))
    return (char *)UNICHAR_NO_ROOM;
  while (src_buf < src_buf_end)
    {
      char char_to_put = (src_buf++)[0];
      ((wchar_t *)tgt_buf)[0] = (wchar_t)(WCHAR_TO_CHAR ((wchar_t)char_to_put, my_charset));
      tgt_buf += sizeof (wchar_t)/sizeof(char);
    }
  return tgt_buf;
}



encoding_handler_t *
intl_find_user_charset (const char *encname, int xml_input_is_wide)
{
  char szEncName[100], *pszEncName = szEncName;
  int inx1, inx2;
  wcharset_t **charset;
  encoding_handler_t *eh = NULL;

  if (!encname && !*encname)
    return eh;

  inx1 = 0;
  if (xml_input_is_wide)
    {
      strcpy_ck (szEncName, "WIDE ");
      inx1 = 5;
    }
  for (inx2 = 0; inx2 < sizeof (szEncName) - 6 && encname[inx2]; inx1++, inx2++)
    szEncName[inx1] = toupper (encname[inx2]);
  szEncName[inx1] = 0;
  charset = (wcharset_t **) id_hash_get (global_wide_charsets, (caddr_t) &pszEncName);
/* IvAn/0/001011 Fixed GPF caused by unknown encoding name */
  if ((NULL == charset) || (NULL == charset[0]))
    return eh;

  eh = (encoding_handler_t *) dk_alloc (sizeof (encoding_handler_t));
  memset (eh, 0, sizeof (encoding_handler_t));
  eh->eh_appdata = charset[0];
  if (xml_input_is_wide)
    {
      char *name;
      size_t name_len;
      eh->eh_minsize = 1*sizeof(wchar_t);
      eh->eh_maxsize = 1*sizeof(wchar_t);
      eh->eh_decode_char = eh_decode_char__wcharset_wide;
      eh->eh_decode_buffer = eh_decode_buffer__wcharset_wide;
      eh->eh_encode_char = eh_encode_char__wcharset_wide;
      eh->eh_encode_buffer = eh_encode_buffer__wcharset_wide;
      inx1 = BOX_ELEMENTS(charset[0]->chrs_aliases);
      eh->eh_names = (char **) dk_alloc ((inx1+2) * sizeof(char *));
      eh->eh_names[inx1+1] = NULL;
      while (inx1--)
	{
	  name_len = strlen(charset[0]->chrs_aliases[inx1])+6;
	  name = (char *) dk_alloc (name_len);
	  strcpy_size_ck (name, "WIDE ", name_len);
	  strcpy_size_ck (name+5, charset[0]->chrs_aliases[inx1], name_len - 5);
	  eh->eh_names[inx1+1] = name;
	}
      name_len = strlen(charset[0]->chrs_name)+6;
      name = (char *) dk_alloc (name_len);
      strcpy_size_ck (name, "WIDE ", name_len);
      strcpy_size_ck (name+5, charset[0]->chrs_name, name_len - 5);
      eh->eh_names[0] = name;
    }
  else
    {
      char *name;
      size_t name_len;
      eh->eh_minsize = 1;
      eh->eh_maxsize = 1;
      eh->eh_decode_char = eh_decode_char__wcharset_narrow;
      eh->eh_decode_buffer = eh_decode_buffer__wcharset_narrow;
      eh->eh_encode_char = eh_encode_char__wcharset_narrow;
      eh->eh_encode_buffer = eh_encode_buffer__wcharset_narrow;
      inx1 = BOX_ELEMENTS(charset[0]->chrs_aliases);
      eh->eh_names = (char **) dk_alloc ((inx1+2) * sizeof(char *));
      eh->eh_names[inx1+1] = NULL;
      while (inx1--)
	{
	  name_len = strlen(charset[0]->chrs_aliases[inx1])+1;
	  name = (char *) dk_alloc (name_len);
	  strcpy_size_ck (name, charset[0]->chrs_aliases[inx1], name_len);
	  eh->eh_names[inx1+1] = name;
	}
      name_len = strlen(charset[0]->chrs_name)+1;
      name = (char *) dk_alloc (name_len);
      strcpy_size_ck (name, charset[0]->chrs_name, name_len);
      eh->eh_names[0] = name;
    }
  eh_load_handler (eh);
  return eh;
}


static caddr_t
bif_iswidestring (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg1 = bif_arg (qst, args, 0, "iswidestring");
  int result;

  dtp_t dtp = DV_TYPE_OF (arg1);
  switch (dtp)
  {
  case DV_WIDE: case DV_LONG_WIDE:
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


#ifndef NDEBUG
static caddr_t
bif_set_utf8_output (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  static const char * bifname = "set_utf8_output";
  dk_session_t * out = (dk_session_t *) bif_arg (qst, args, 0, bifname);
  long is_utf8 = bif_long_arg (qst, args, 1, bifname);
  strses_set_utf8 (out, is_utf8 ? 1 : 0);
  return NULL;
}
#endif

static caddr_t
bif_dbg_assert_encoding (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t box = bif_string_or_uname_or_wide_or_null_arg (qst, args, 0, "dbg_assert_encoding");
  caddr_t enctype = bif_string_arg (qst, args, 1, "dbg_assert_encoding");
  if (!strcmp (enctype, "UTF-8"))
    ASSERT_BOX_UTF8(box);
  else if (!strcmp (enctype, "8-BIT"))
    ASSERT_BOX_8BIT(box);
  else if (!strcmp (enctype, "WCHAR"))
    ASSERT_BOX_WCHAR(box);
  else
    sqlr_new_error ("22023", "SR533",
      "Second argument of dbg_assert_encoding() must be one of 'UTF-8', '8-BIT', 'WCHAR', not '%.1000s'", enctype);
  return box_copy_tree (box);
}

static
caddr_t
bif_dbg_set_lh_xany_normalization_flags (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  sec_check_dba ((query_instance_t *)qst, "dbg_set_lh_xany_normalization_flags");
  lh_xany_normalization_flags = bif_long_arg (qst, args, 0, "dbg_set_lh_xany_normalization_flags");
  return box_num (lh_xany_normalization_flags);
}

wcharset_t *
wcharset_by_name_or_dflt (ccaddr_t cs_name, query_instance_t *qi)
{
  wcharset_t * charset = NULL;
  if (NULL != cs_name)
    {
      if (!stricmp (cs_name, "UTF-8"))
	return CHARSET_UTF8;
      if (!stricmp (cs_name, "_WIDE_"))
	return CHARSET_WIDE;
      else
	charset = sch_name_to_charset (cs_name);
    }
  if (NULL != charset)
    return charset;
  if (NULL == qi)
    return default_charset;
  charset = QST_CHARSET (qi);
  if (NULL == charset)
    return default_charset;
  return charset;
}


int
lang_match_to_accept_language_range (const char *lang, const char *key, const char *key_end)
{
  if ('*' == key[0])
    return 1;
  if (!strncasecmp (lang, key, key_end-key) && (('\0' == lang[key_end-key]) || ('-' == lang[key_end-key])))
    return 1 + (key_end-key);
  return 0;
}

double
get_q_of_lang_in_http_accept_language (const char *lang, const char *line)
{
  const char *tail = line;
  /* const char *best_key = NULL, *best_key_end = NULL; */
  int best_match_weight = 0;
  double best_q = 0;
#define TAIL_SKIP_WS do { while ((' ' == tail[0]) || ('\t' == tail[0])) tail++; } while (0)
  TAIL_SKIP_WS;
  while ('\0' != tail[0])
    {
      const char *key, *key_end;
      int match_weight;
      double q=1.0;
      key = tail;
      while (isalnum (tail[0]) || ('-' == tail[0]) || ('/' == tail[0]) || ('*' == tail[0])) tail++;
      key_end = tail;
      if (key_end == key) goto garbage_after_q;
      TAIL_SKIP_WS;
      if (';' != tail[0]) goto garbage_after_q;
      tail++;
      TAIL_SKIP_WS;
      if ('q' != tail[0]) goto garbage_after_q;
      tail++;
      TAIL_SKIP_WS;
      if ('=' != tail[0]) goto garbage_after_q;
      tail++;
      TAIL_SKIP_WS;
      q=0.0;
      while (isdigit (tail[0])) { q = q * 10 + (tail[0]-'0'); tail++; }
      if ('.' == tail[0])
        {
          double weight = 0.1;
          tail++;
          while (isdigit (tail[0])) { q += weight * (tail[0]-'0'); weight /= 10.0; tail++; }
        }
garbage_after_q:
      while ((' ' <= tail[0]) && (',' != tail[0])) tail++;
      match_weight = lang_match_to_accept_language_range (lang, key, key_end);
      if (match_weight > best_match_weight)
        {
          best_match_weight = match_weight;
          best_q = q;
        }
      if (',' != tail[0])
        break;
      tail++;
      TAIL_SKIP_WS;
    }
  return best_q;
}

caddr_t
bif_langmatches_pct_http (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  static const char * bifname = "langmatches_pct_http";
  caddr_t lang = bif_string_arg (qst, args, 0, bifname);
  caddr_t line = bif_string_arg (qst, args, 1, bifname);
  double q = get_q_of_lang_in_http_accept_language (lang, line);
  return box_num (q * 100);
}


void
bif_intl_init (void)
{
  bif_define_typed ("collation__define", bif_collation__define, &bt_integer);
  bif_define_typed ("charset__define", bif_charset_define, &bt_integer);
  bif_define_typed ("charset_canonical_name", bif_charset_canonical_name, &bt_integer);
  bif_define_typed ("complete_collation_name", bif_complete_collation_name, &bt_varchar);
  bif_define_typed ("collation_order_string", bif_collation_order_string, &bt_varchar);
  bif_define_typed ("current_charset", bif_current_charset, &bt_varchar);
  bif_define_typed ("charset_recode", bif_charset_recode, &bt_varchar);
  bif_define_typed ("bf_text_to_UTF8", bif_bf_text_to_UTF8, &bt_varchar);
  bif_define_typed ("bf_text_to_UTF8_or_wide", bif_bf_text_to_UTF8_or_wide, &bt_varchar);
  bif_define ("uname", bif_uname);
  bif_define ("__uname", bif_quick_uname);
  bif_define ("charsets_list", bif_charsets_list);
  bif_define_typed ("unicode_toupper", bif_unicode_toupper, &bt_integer);
  bif_define_typed ("unicode_tolower", bif_unicode_tolower, &bt_integer);
  bif_define ("unicode_char_properties", bif_unicode_char_properties);
  bif_define_typed ("iswidestring", bif_iswidestring, &bt_integer);
#ifndef NDEBUG
  bif_define ("set_utf8_output", bif_set_utf8_output);
#endif
  bif_define ("dbg_assert_encoding", bif_dbg_assert_encoding);
  bif_define ("__dbg_set_lh_xany_normalization_flags", bif_dbg_set_lh_xany_normalization_flags);
  bif_define_typed ("langmatches_pct_http", bif_langmatches_pct_http, &bt_integer);
}

