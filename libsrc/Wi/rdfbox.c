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
 *  
*/
#include "sqlnode.h"
#include "sqlbif.h"
#include "arith.h"
#include "xmltree.h"
#include "rdf_core.h"
#include "http.h" /* For DKS_ESC_XXX constants */
#include "date.h" /* For DT_TYPE_DATE and the like */

void
rb_complete (rdf_box_t * rb, lock_trx_t * lt, void * /*actually query_instance_t * */ caller_qi_v)
{
  static query_t *rdf_box_qry_complete_xml = NULL;
  static query_t *rdf_box_qry_complete_text = NULL;
  query_instance_t *caller_qi = caller_qi_v;
  caddr_t err;
  local_cursor_t *lc;
  dtp_t value_dtp = ((rb->rb_chksum_tail) ? (((rdf_bigbox_t *)rb)->rbb_box_dtp) : DV_TYPE_OF (rb->rb_box));
#ifdef DEBUG
  if (rb->rb_is_complete)
    GPF_T1("rb_" "complete(): redundand call");
#endif
  if (NULL == rdf_box_qry_complete_xml)
    {
      rdf_box_qry_complete_xml = sql_compile_static (
        "select xml_tree_doc (__xml_deserialize_packed (RO_LONG)) from DB.DBA.RDF_OBJ where RO_ID = ?",
        bootstrap_cli, NULL, SQLC_DEFAULT );
      rdf_box_qry_complete_text = sql_compile_static (
        "select case (isnull (RO_LONG)) when 0 then blob_to_string (RO_LONG) else RO_VAL end from DB.DBA.RDF_OBJ where RO_ID = ?",
        bootstrap_cli, NULL, SQLC_DEFAULT );
    }
  err = qr_rec_exec (
    (DV_XML_ENTITY == value_dtp ? rdf_box_qry_complete_xml : rdf_box_qry_complete_text),
    lt->lt_client, &lc, caller_qi, NULL, 1,
      ":0", box_num(rb->rb_ro_id), QRP_RAW );
  if (NULL != err)
    {
      if (CALLER_LOCAL != caller_qi)
        sqlr_resignal (err);
      dk_free_tree (err);
      return;
    }
  if (lc_next (lc))
    {
      caddr_t val = lc_nth_col (lc, 0);
      if (rb->rb_chksum_tail && (DV_TYPE_OF (val) != ((rdf_bigbox_t *)rb)->rbb_box_dtp))
        sqlr_new_error ("22023", "SR579", "The type %ld of value retrieved from DB.DBA.RDF_OBJ with RO_ID = " BOXINT_FMT " is not equal to preset type %ld of RDF box",
          (long)DV_TYPE_OF (val), (boxint)(rb->rb_ro_id), ((long)(((rdf_bigbox_t *)rb)->rbb_box_dtp)) );
      dk_free_tree (rb->rb_box);
      rb->rb_box = box_copy_tree (val);
      rb->rb_is_complete = 1;
    }
  err = lc->lc_error;
  lc_free (lc);
  if (NULL != err)
    {
      if (CALLER_LOCAL != caller_qi)
        sqlr_resignal (err);
      dk_free_tree (err);
      return;
    }
  if ((!rb->rb_is_complete) && (CALLER_LOCAL != caller_qi))
    sqlr_new_error ("22023", "SR580", "RDF box refers to row with RO_ID = " BOXINT_FMT " of table DB.DBA.RDF_OBJ, but no such row in the table", (boxint)(rb->rb_ro_id) );
}


#define RB_MAX_INLINED_CHARS 20

caddr_t
bif_rdf_box (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  /* data, type, lamg, ro_id, is_complete */
  rdf_box_t * rb;
  caddr_t box, chksum = NULL;
  dtp_t box_dtp;
  long type, lang, ro_id, is_complete;
  box = bif_arg (qst, args, 0, "rdf_box");
  type = bif_long_arg (qst, args, 1, "rdf_box");
  lang = bif_long_arg (qst, args, 2, "rdf_box");
  ro_id = bif_long_arg (qst, args, 3, "rdf_box");
  is_complete = bif_long_arg (qst, args, 4, "rdf_box");
  if ((RDF_BOX_DEFAULT_TYPE > type) || (type & ~0xffff))
    sqlr_new_error ("22023", "SR547", "Invalid datatype id %ld as argument 2 of rdf_box()", type);
  if ((RDF_BOX_DEFAULT_LANG > lang) || (lang & ~0xffff))
    sqlr_new_error ("22023", "SR548", "Invalid language id %ld as argument 3 of rdf_box()", lang);
  if ((RDF_BOX_DEFAULT_TYPE != type) && (RDF_BOX_DEFAULT_LANG != lang))
    sqlr_new_error ("22023", "SR549", "Both datatype id %ld and language id %ld are not default in call of rdf_box()", type, lang);
  if ((0 == ro_id) && !is_complete)
    sqlr_new_error ("22023", "SR550", "Neither is_complete nor ro_id argument is set in call of rdf_box()");
  box_dtp = DV_TYPE_OF (box);
  switch (box_dtp)
    {
    case DV_DB_NULL:
      return NEW_DB_NULL;
    case DV_XML_ENTITY:
      if (!XE_IS_TREE (box))
        sqlr_new_error ("22023", "SR559", "Persistent XML is not a valid argument #1 in call of rdf_box()");
      break;
    case DV_DICT_ITERATOR:
      sqlr_new_error ("22023", "SR559", "Dictionary is not a valid argument #1 in call of rdf_box()");
    case DV_BLOB: case DV_BLOB_HANDLE: case DV_BLOB_BIN: case DV_BLOB_WIDE: case DV_BLOB_WIDE_HANDLE:
    case DV_BLOB_XPER: case DV_BLOB_XPER_HANDLE:
      sqlr_new_error ("22023", "SR559", "Large object (tag %d) is not a valid argument #1 in call of rdf_box()", box_dtp);
    }
  if (5 < BOX_ELEMENTS (args))
    chksum = bif_string_arg (qst, args, 5, "rdf_box");
  else
    {
      if (DV_XML_ENTITY == box_dtp)
        chksum = xte_sum64 (((xml_tree_ent_t *)box)->xte_current);
    }
  if (NULL != chksum)
    {
      rdf_bigbox_t * rbb = rbb_allocate ();
      rbb->rbb_base.rb_box = box_copy_tree (box);
      rbb->rbb_base.rb_type = (short)type;
      rbb->rbb_base.rb_lang = (short)lang;
      rbb->rbb_base.rb_ro_id = ro_id;
      if (ro_id)
        rbb->rbb_base.rb_is_outlined = 1;
      rbb->rbb_base.rb_is_complete = is_complete;
      rbb->rbb_base.rb_chksum_tail = 1;
      rbb->rbb_chksum = box_copy_tree (chksum);
      if (6 < BOX_ELEMENTS (args))
        {
          long dtp = bif_long_arg (qst, args, 6, "rdf_box");
          if ((dtp &~0xFF) || ! (dtp & 0x80))
            sqlr_new_error ("22023", "SR556", "Invalid dtp %ld in call of rdf_box()", dtp);
           rbb->rbb_box_dtp = (dtp_t)dtp;
        }
      else
        rbb->rbb_box_dtp = DV_TYPE_OF (box);
      rdf_bigbox_audit(rbb);
      return (caddr_t) rbb;
    }
  if (is_complete && (0 == ro_id) && (RDF_BOX_DEFAULT_TYPE == type) && (RDF_BOX_DEFAULT_LANG == lang) &&
    (DV_STRING == DV_TYPE_OF (box)) && ((RB_MAX_INLINED_CHARS+1) >= box_length_inline (box)) )
    return box_copy (box);
  rb = rb_allocate ();
  rb->rb_box = box_copy_tree (box);
  rb->rb_type = (short)type;
  rb->rb_lang = (short)lang;
  rb->rb_ro_id = ro_id;
  if (ro_id)
    rb->rb_is_outlined = 1;
  rb->rb_is_complete = is_complete;
  rdf_box_audit(rb);
  return (caddr_t) rb;
}


caddr_t
bif_is_rdf_box (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t x = bif_arg (qst, args, 0, "is_rdf_box");
  if (DV_RDF == DV_TYPE_OF (x))
    {
      rdf_box_audit((rdf_box_t *)x);
      return box_num (1);
    }
  return 0;
}


rdf_box_t *
bif_rdf_box_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func)
{
  caddr_t arg = bif_arg (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  if (dtp != DV_RDF)
    sqlr_new_error ("22023", "SR014",
  "Function %s needs an rdf box as argument %d, not an arg of type %s (%d)",
  func, nth + 1, dv_type_title (dtp), dtp);
  rdf_box_audit((rdf_box_t*) arg);
  return (rdf_box_t*) arg;
}



caddr_t
bif_rdf_box_set_data (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  rdf_box_t *rb = bif_rdf_box_arg (qst, args, 0, "rdf_box_set_data");
  caddr_t data = bif_arg (qst, args, 1, "rdf_box_set_data");
  caddr_t old_val = rb->rb_box;
  if (1 < BOX_ELEMENTS (args))
    {
      long is_complete = bif_long_arg (qst, args, 2, "rdf_box_set_data");
      if (is_complete)
        {
          if (rb->rb_chksum_tail && (DV_TYPE_OF (data) != ((rdf_bigbox_t *)rb)->rbb_box_dtp))
            sqlr_new_error ("22023", "SR557", "The type %ld of data is not equal to preset type %ld in call of rdf_box_set_data ()",
              (long)DV_TYPE_OF (data), (long)(((rdf_bigbox_t *)rb)->rbb_box_dtp) );
          rb->rb_is_complete = 1;
        }
      else
        {
          if (0 == rb->rb_ro_id)
            sqlr_new_error ("22023", "SR551", "Zero is_complete argument and rdf box with ro_id in call of rdf_box_set_data ()");
          rb->rb_is_complete = 0;
        }
    }
  rb->rb_box = box_copy_tree (data);
  rb->rb_ref_count++;
  dk_free_tree (old_val);
  return (caddr_t) rb;
}


caddr_t
bif_rdf_box_data (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  rdf_box_t *rb = (rdf_box_t *)bif_arg (qst, args, 0, "rdf_box_data");
  if (DV_RDF != DV_TYPE_OF (rb))
    return box_copy_tree (rb);
  rdf_box_audit (rb);
  if (1 < BOX_ELEMENTS (args))
    {
      long should_be_complete = bif_long_arg (qst, args, 1, "rdf_box_data");
      if (should_be_complete && !(rb->rb_is_complete))
        sqlr_new_error ("22023", "SR545", "An incomplete RDF box '%.100s' is passed to rdf_box_data (..., %ld)", rb->rb_box, should_be_complete);
    }
  return box_copy_tree (rb->rb_box);
}


caddr_t
bif_rdf_box_data_tag (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  rdf_box_t *rb = (rdf_box_t *)bif_arg (qst, args, 0, "rdf_box_data_tag");
  dtp_t rb_dtp = DV_TYPE_OF (rb);
  if (DV_RDF != rb_dtp)
    return box_num (rb_dtp);
  rdf_box_audit (rb);
  if (rb->rb_chksum_tail)
    return box_num (((rdf_bigbox_t *)rb)->rbb_box_dtp);
  return box_num (DV_TYPE_OF (rb->rb_box));
}


caddr_t
bif_rdf_box_lang (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  rdf_box_t *rb = (rdf_box_t *)bif_arg (qst, args, 0, "rdf_box_lang");
  if (DV_RDF == DV_TYPE_OF (rb))
    {
      rdf_box_audit (rb);
      return box_num (rb->rb_lang);
    }
  return box_num (RDF_BOX_DEFAULT_LANG);
}


caddr_t
bif_rdf_box_type (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  rdf_box_t *rb = (rdf_box_t *)bif_arg (qst, args, 0, "rdf_box_type");
  if (DV_RDF == DV_TYPE_OF (rb))
    {
      rdf_box_audit (rb);
      return box_num (rb->rb_type);
    }
  return box_num (RDF_BOX_DEFAULT_TYPE);
}

caddr_t
bif_rdf_box_set_type (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  rdf_box_t *rb = bif_rdf_box_arg (qst, args, 0, "rdf_box_set_type");
  long type = bif_long_arg (qst, args, 1, "rdf_box_set_type");
  if ((RDF_BOX_DEFAULT_TYPE > type) || (type & ~0xffff))
    sqlr_new_error ("22023", "SR554", "Invalid datatype id %ld as argument 2 of rdf_box_set_type()", type);
  if (0 != rb->rb_ro_id)
    sqlr_new_error ("22023", "SR555", "Datatype id can be changed only if rdf box has no ro_id in call of rdf_box_set_type ()");
  rb->rb_type = (short)type;
  return box_num (type);
}

caddr_t
bif_rdf_box_chksum (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  rdf_bigbox_t *rbb = (rdf_bigbox_t *)bif_arg (qst, args, 0, "rdf_box_chksum");
  if (DV_RDF != DV_TYPE_OF (rbb))
    return NEW_DB_NULL;
  rdf_bigbox_audit (rbb);
  if (!rbb->rbb_base.rb_chksum_tail)
    return NEW_DB_NULL;
  return box_copy_tree (rbb->rbb_chksum);
}

caddr_t
bif_rdf_box_is_complete (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  rdf_box_t *rb = (rdf_box_t *)bif_arg (qst, args, 0, "rdf_box_is_complete");
  if (DV_RDF == DV_TYPE_OF (rb))
    {
      rdf_box_audit (rb);
      return box_num (rb->rb_is_complete);
    }
  return box_num (1);
}

/*
caddr_t
bif_rdf_box_set_is_complete (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t rb = bif_arg (qst, args, 0, "rdf_box_set_is_complete");
  if (DV_RDF == DV_TYPE_OF (rb))
    {
      rdf_box_t * rb2 = (rdf_box_t *) rb;
      rb2->rb_is_complete = 1;
    }
  return box_num (1);
}
*/

caddr_t
bif_rdf_box_is_storeable (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  rdf_box_t *rb = (rdf_box_t *)bif_arg (qst, args, 0, "rdf_box_is_storeable");
  dtp_t rb_dtp = DV_TYPE_OF (rb);
  if (DV_RDF == rb_dtp)
    {
      dtp_t data_dtp;
      rdf_box_audit (rb);
      if (0 != rb->rb_ro_id)
        return box_num (1);
      if ((!rb->rb_is_complete) || rb->rb_chksum_tail)
        return box_num (0);
      data_dtp = DV_TYPE_OF (rb->rb_box);
      if ((DV_STRING == data_dtp) || (DV_UNAME == data_dtp))
        return box_num (((RB_MAX_INLINED_CHARS + 1) >= box_length (rb->rb_box)) ? 1 : 0);
    }
  if ((DV_STRING == rb_dtp) || (DV_UNAME == rb_dtp))
    return box_num (((RB_MAX_INLINED_CHARS + 1) >= box_length ((caddr_t)(rb))) ? 1 : 0);
  return box_num (1);
}

caddr_t
bif_rdf_box_needs_digest (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t rb = bif_arg (qst, args, 0, "rdf_box_needs_digest");
  dtp_t dict_dtp;
  dtp_t rb_dtp = DV_TYPE_OF (rb);
  if (1 < BOX_ELEMENTS (args))
    {
      caddr_t dict = bif_arg (qst, args, 1, "rdf_box_needs_digest");
      dict_dtp = DV_TYPE_OF (dict);
    }
  else
    dict_dtp = DV_DB_NULL;
  switch (rb_dtp)
    {
    case DV_RDF:
      {
        rdf_box_t * rb2 = (rdf_box_t *) rb;
        dtp_t data_dtp;
        rdf_box_audit (rb2);
        data_dtp = DV_TYPE_OF (rb2->rb_box);
        if ((DV_STRING == data_dtp) || (DV_UNAME == data_dtp))
          {
            if (DV_DB_NULL != dict_dtp)
              return box_num (3);
            if ((RDF_BOX_DEFAULT_TYPE != rb2->rb_type) || (RDF_BOX_DEFAULT_LANG != rb2->rb_lang))
              return box_num (3);
            return box_num (((RB_MAX_INLINED_CHARS + 1) >= box_length (rb2->rb_box)) ? 0 : 1);
          }
        return box_num (0);
      }
    case DV_STRING: case DV_UNAME:
      if (DV_DB_NULL != dict_dtp)
        return box_num (7);
      return box_num (((RB_MAX_INLINED_CHARS + 1) >= box_length (rb)) ? 0 : 1);
    case DV_XML_ENTITY:
        return box_num (7);
    default:
      return box_num (0);
    }
}

caddr_t
bif_rdf_box_strcmp (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  rdf_box_t *rb1 = (rdf_box_t *)bif_arg (qst, args, 0, "rdf_box_strcmp");
  rdf_box_t *rb2 = (rdf_box_t *)bif_arg (qst, args, 1, "rdf_box_strcmp");
  if ((DV_RDF != DV_TYPE_OF (rb1)) || (DV_RDF != DV_TYPE_OF (rb2)) ||
    (!rb1->rb_is_complete) || (!rb2->rb_is_complete) ||
    (!DV_STRINGP (rb1->rb_box)) || (!DV_STRINGP (rb2->rb_box)) )
    return NEW_DB_NULL;
  rdf_box_audit (rb1);
  rdf_box_audit (rb2);
  return box_num (strcmp (rb1->rb_box, rb2->rb_box));
}


caddr_t
bif_rdf_box_ro_id (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  rdf_box_t *rb = (rdf_box_t *)bif_arg (qst, args, 0, "rdf_box_ro_id");
  if (DV_RDF == DV_TYPE_OF (rb))
    {
      rdf_box_audit (rb);
      return box_num (rb->rb_ro_id);
    }
  return 0;
}


caddr_t
bif_rdf_box_set_ro_id (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  rdf_box_t * rb = bif_rdf_box_arg (qst, args, 0, "is_rdrf_box");
  long ro_id = bif_long_arg (qst, args, 1, "rdf_box_set_ro_id");
  if ((0 == ro_id) && !rb->rb_is_complete)
    sqlr_new_error ("22023", "SR551", "Zero ro_id argument and rdf box with incomplete data in call of rdf_box_set_ro_id ()");
  rb->rb_ro_id = ro_id;
  return 0;
}



int 
rbs_length (db_buf_t rbs)
{
  long hl, l;
  dtp_t flags = rbs[1];
  if (flags & RBS_SKIP_DTP)
    {
      hl = 1;
      l = rbs[2];
    }
  else
    db_buf_length (rbs + 2, &hl, &l);
  l += 2;
  if (flags & RBS_OUTLINED)
    l += 4;
  if (flags & RBS_64)
    l += 4;
  if (flags & (RBS_HAS_TYPE | RBS_HAS_LANG))
    l += 2;
  return hl + l;
}



int
rb_free (rdf_box_t * rb)
{
  rdf_box_audit (rb);
  rb->rb_ref_count--;
  if (rb->rb_ref_count)
    return 1;
  dk_free_tree (rb->rb_box);
  if (rb->rb_chksum_tail)
  dk_free_tree (((rdf_bigbox_t *)rb)->rbb_chksum);
  return 0;
}

caddr_t
rb_copy (rdf_box_t * rb)
{
  rdf_box_audit (rb);
  rb->rb_ref_count++;
  return (caddr_t)rb;
}

#define RBS_RO_ID_LEN(flags) \
  (((flags) & RBS_OUTLINED) ? (((flags) & RBS_64) ? 8 : 4) : 0)

#define RBS_RO_ID(place, flags) \
  (((flags) & RBS_OUTLINED) ? (((flags) & RBS_64) ? INT64_REF_NA ((place)) : LONG_REF_NA ((place))) : 0)

int
dv_rdf_compare (db_buf_t dv1, db_buf_t dv2)
{
  /* this is dv_compare  where one or both arguments are dv_rdf 
   * The collation is perverse: If one is not a string, collate as per dv_compare of the data.
   * if both are strings and one is not an rdf box, treat the one that is not a box as an rdf string of max inlined chars and no lang orr type. */
  int len1, len2, cmp_len, mcmp;
  dtp_t dtp1 = dv1[0], dtp2 = dv2[0], flags1, flags2;
  short rdftype1, rdftype2, rdflang1, rdflang2;
  dtp_t data_dtp1, data_dtp2;
  db_buf_t data1 = NULL, data2 = NULL;
  /* arrange so that if both are not rdf boxes, the one that is an rdf box is first */
  if (DV_RDF != dtp1)
    {
      int res = dv_rdf_compare (dv2, dv1);
      switch (res)
	{
	case DVC_LESS: return DVC_GREATER;
	case DVC_GREATER: return DVC_LESS;
	case DVC_DTP_LESS: return DVC_DTP_GREATER;
	case DVC_DTP_GREATER: return DVC_DTP_LESS;
	default: return res;
	}
    }
  flags1 = dv1[1];
  if (RBS_SKIP_DTP & flags1)
    {
      data_dtp1 = DV_SHORT_STRING_SERIAL;
      len1 = dv1[2];
      data1 = dv1 + 3;
    }
  else
    {
      data1 = dv1 + 2;
      data_dtp1 = data1[0];
      if (DV_SHORT_STRING_SERIAL != data_dtp1)
        {
#ifdef DEBUG
          if (RBS_CHKSUM & flags1)
            GPF_T;
#endif
          return dv_compare (data1, dv2, NULL);
        }
      len1 = data1[1];
      data1 += 2;
    }
  if (DV_RDF == dtp2)
    {
      flags2 = dv2[1];
      if (RBS_SKIP_DTP & flags2)
        {
          data_dtp2 = DV_SHORT_STRING_SERIAL;
          len2 = dv2[2];
          data2 = dv2 + 3;
        }
      else
        {
          data2 = dv2 + 2;
          data_dtp2 = data2[0];
          if (DV_SHORT_STRING_SERIAL != data_dtp2)
            {
#ifdef DEBUG
              if (RBS_CHKSUM & flags2)
                GPF_T;
#endif
              return dv_compare (dv1, data2, NULL);
            }
          len2 = data2[1];
          data2 += 2;
        }
      rdftype2 = ((RBS_HAS_TYPE & flags2) ? SHORT_REF_NA (data2 + len2 + RBS_RO_ID_LEN (flags2)) : RDF_BOX_DEFAULT_TYPE);
      rdflang2 = ((RBS_HAS_LANG & flags2) ? SHORT_REF_NA (data2 + len2 + RBS_RO_ID_LEN (flags2)) : RDF_BOX_DEFAULT_LANG);
    }
  else
    {
      /* rdf string and non rdf */
      if (DV_STRING != dtp2 && DV_SHORT_STRING_SERIAL != dtp2)
        return DVC_DTP_LESS;
      /* rdf string or checksum and dv string */
      flags2 = RBS_COMPLETE;
      data2 = dv2;
      data_dtp2 = dtp2;
      if (DV_SHORT_STRING_SERIAL == data_dtp2)
        {
          len2 = data2[1];
          data2 += 2;
        }
      else
        {
          len2 = RB_MAX_INLINED_CHARS;
          data2 += 5;
        }
      rdftype2 = RDF_BOX_DEFAULT_TYPE;
      rdflang2 = RDF_BOX_DEFAULT_LANG;
    }
  rdftype1 = ((RBS_HAS_TYPE & flags1) ? SHORT_REF_NA (data1 + len1 + RBS_RO_ID_LEN (flags1)) : RDF_BOX_DEFAULT_TYPE);
  if (rdftype1 < rdftype2) return DVC_DTP_LESS;
  if (rdftype1 > rdftype2) return DVC_DTP_GREATER;
  rdflang1 = ((RBS_HAS_LANG & flags1) ? SHORT_REF_NA (data1 + len1 + RBS_RO_ID_LEN (flags1)) : RDF_BOX_DEFAULT_LANG);
  if (rdflang1 < rdflang2) return DVC_DTP_LESS;
  if (rdflang1 > rdflang2) return DVC_DTP_GREATER;
  if (RBS_CHKSUM & flags1)
    {
      if (!(RBS_CHKSUM & flags2))
        return DVC_LESS;
      cmp_len = MIN (len1, len2);
      mcmp = memcmp (data1, data2, cmp_len);
      if (mcmp < 0)
        return DVC_LESS;
      if (mcmp > 0)
        return DVC_GREATER;
      if (len1 < len2)
        return DVC_LESS;
      if (len1 > len2)
        return DVC_GREATER;
      return DVC_MATCH;
    }
  else
    {
      if (RBS_CHKSUM & flags2)
        return DVC_GREATER;
      cmp_len = MIN (len1, len2);
      mcmp = memcmp (data1, data2, cmp_len);
      if (mcmp < 0)
        return DVC_LESS;
      if (mcmp > 0)
        return DVC_GREATER;
      if ((RBS_COMPLETE & flags1) && (RBS_COMPLETE & flags2))
        {
          if (len1 < len2)
            return DVC_LESS;
          if (len1 > len2)
            return DVC_GREATER;
/* In version 5, complete boxes that differ only in ro_id are intentionally kept distinct in table but equal in memory.
In version 6 (Vajra), complete boxes are equal even if ro_id differ (say, one of ids is zero. ids are compared only if both boxes are ncomplete.
          return DVC_MATCH; */
        }
      else if (cmp_len < RB_MAX_INLINED_CHARS)
        {
          if ((len1 == cmp_len) && (len2 > cmp_len))
            return DVC_LESS;
          if ((len2 == cmp_len) && (len1 > cmp_len))
            return DVC_GREATER;
        }
/* In version 6 (Vajra) the comparison is better, by adding these two comparisons:
      else if (RBS_COMPLETE & flags2)
        return DVC_GREATER;
      else if (RBS_COMPLETE & flags1)
        return DVC_LESS; */
    }
  if (DV_RDF == dtp2)
    {
      /* neither is complete. Let the ro_id decide */
      int64 ro1 = RBS_RO_ID (data1 + len1, flags1);
      int64 ro2 = RBS_RO_ID (data2 + len2, flags2);
      if (ro1 == ro2)
        return DVC_MATCH;
      else if (ro1 < ro2)
        return DVC_LESS;
      else
        return DVC_GREATER;
    }
  /* the first is a rdf string and the second a sql one.  First max inlined chars are eq.
   * If the rdf string is complete, it is eq if no language.  */
  if (RBS_COMPLETE & flags1)
    {
      int64 ro1;
      if ((RBS_HAS_LANG & flags1) || (RBS_HAS_TYPE & flags1))
	return DVC_GREATER;
      ro1 = RBS_RO_ID (data1 + len1, flags1);
      if (0 < ro1)
        return DVC_GREATER;
      return DVC_MATCH;
    }
  return DVC_GREATER;
}


int
rdf_box_compare (ccaddr_t a1, ccaddr_t a2)
{
  /* this is cmp_boxes  where one or both arguments are dv_rdf 
   * The collation is perverse: If one is not a string, collate as per dv_compare of the data.
   * if both are strings and one is not an rdf box, treat the one that is not a box as an rdf string of max inlined chars and no lang orr type. */
  rdf_box_t * rb1 = (rdf_box_t *) a1;
  rdf_box_t * rb2 = (rdf_box_t *) a2;
  rdf_box_t tmp_rb2;
  dtp_t dtp1 = DV_TYPE_OF (rb1), dtp2 = DV_TYPE_OF (rb2);
  dtp_t data_dtp1, data_dtp2;
  int len1, len2, cmp_len, cmp_headlen, mcmp;
  caddr_t data1 = NULL, data2 = NULL;
  /* arrange so that if both are not rdf boxes, the one that is a box is first */
  if (DV_RDF != dtp1)
    {
      int res = rdf_box_compare (a2, a1);
      return ((res == DVC_GREATER) ? DVC_LESS : ((res == DVC_LESS) ? DVC_GREATER : res));
    }
  if ((DV_RDF == dtp2) && (0 != rb1->rb_ro_id) && (rb2->rb_ro_id == rb1->rb_ro_id))
    return DVC_MATCH;
  data1 = rb1->rb_box;
  data_dtp1 = DV_TYPE_OF (data1);
  /* if stringg and non-string */
  if ((DV_STRING != data_dtp1) && !rb1->rb_chksum_tail)
    {
      return cmp_boxes (data1, (caddr_t) a2, NULL, NULL);
    }
  if (DV_RDF == dtp2)
    {
      data2 = rb2->rb_box;
      data_dtp2 = DV_TYPE_OF (data2);
      if ((DV_STRING != data_dtp2) && !rb2->rb_chksum_tail)
        return cmp_boxes ((caddr_t) rb1, data2, NULL, NULL);
    }
  else
    {
      data2 = (caddr_t) a2;
      data_dtp2 = DV_TYPE_OF (a2);
      if (DV_STRING != data_dtp2)
        return DVC_LESS;
      dtp2 = DV_RDF;
      tmp_rb2.rb_box = (caddr_t) a2;
      tmp_rb2.rb_is_outlined = 0;
      tmp_rb2.rb_is_complete = 1;
      tmp_rb2.rb_chksum_tail = 0;
      tmp_rb2.rb_type = RDF_BOX_DEFAULT_TYPE;
      tmp_rb2.rb_lang = RDF_BOX_DEFAULT_LANG;
      tmp_rb2.rb_ro_id = 0;
      rb2 = &tmp_rb2;
    }
  {
    short type1 = rb1->rb_type;
    short type2 = rb2->rb_type;
    if (type1 < type2) return DVC_LESS;
    if (type1 > type2) return DVC_GREATER;
  }
  {
    short lang1 = rb1->rb_lang;
    short lang2 = rb2->rb_lang;
    if (lang1 < lang2) return DVC_LESS;
    if (lang1 > lang2) return DVC_GREATER;
  }
  if (rb1->rb_chksum_tail)
    {
      if (!rb2->rb_chksum_tail)
        return DVC_LESS;
      data1 = ((rdf_bigbox_t *)rb1)->rbb_chksum;
      data2 = ((rdf_bigbox_t *)rb2)->rbb_chksum;
      len1 = box_length (data1) - 1;
      len2 = box_length (data2) - 1;
      cmp_headlen = MIN (len1, len2);
      mcmp = memcmp (data1, data2, cmp_headlen);
      if (mcmp < 0)
        return DVC_LESS;
      if (mcmp > 0)
        return DVC_GREATER;
      if (len1 < len2)
        return DVC_LESS;
      if (len1 > len2)
        return DVC_GREATER;
      return DVC_MATCH;
    }
  else
    {
      if (rb2->rb_chksum_tail)
        return DVC_GREATER;
#ifdef DEBUG
      if (DV_STRING != data_dtp2)
        GPF_T;
#endif
      len1 = box_length (data1) - 1;
      len2 = box_length (data2) - 1;
      cmp_len = MIN (len1, len2);
      if (((0 == rb1->rb_is_complete) || (0 == rb2->rb_is_complete)) && (RB_MAX_INLINED_CHARS < cmp_len))
        cmp_headlen = RB_MAX_INLINED_CHARS;
      else
        cmp_headlen = cmp_len;
      mcmp = memcmp (data1, data2, cmp_headlen);
      if (mcmp < 0)
        return DVC_LESS;
      if (mcmp > 0)
        return DVC_GREATER;
      if (rb1->rb_is_complete && rb2->rb_is_complete)
        {
          if (len1 < len2)
            return DVC_LESS;
          if (len1 > len2)
            return DVC_GREATER;
          return DVC_MATCH;
        }
      else if (cmp_headlen < RB_MAX_INLINED_CHARS)
        {
          if ((len1 == cmp_headlen) && (len2 > cmp_headlen))
            return DVC_LESS;
          if ((len2 == cmp_headlen) && (len1 > cmp_headlen))
            return DVC_GREATER;
        }
    }
  {
    long ro_id1 = rb1->rb_ro_id;
    long ro_id2 = rb2->rb_ro_id;
    if (ro_id1 < ro_id2)
      return DVC_LESS;
    if (ro_id1 > ro_id2)
      return DVC_GREATER;
  }
  return DVC_MATCH;
}

int32
rdf_box_hash (caddr_t box)
{
  rdf_box_t *rb = (rdf_box_t *)box;
  rdf_box_audit (rb);
  if (rb->rb_is_complete)
    {
      if ((RDF_BOX_DEFAULT_LANG == rb->rb_lang) && (RDF_BOX_DEFAULT_TYPE == rb->rb_type))
        return box_hash (rb->rb_box);
    }
  else
    {
      if (0 != rb->rb_ro_id)
        return rb->rb_ro_id + (rb->rb_ro_id << 16);
    }
  return rb->rb_lang * 17 + rb->rb_type * 13 + rb->rb_is_complete * 9 +
    (rb->rb_chksum_tail ?
      (box_hash (((rdf_bigbox_t *)rb)->rbb_chksum) + 113) :
      box_hash (rb->rb_box) );
}

int
rdf_box_hash_cmp (ccaddr_t a1, ccaddr_t a2)
{
  return (DVC_MATCH == rdf_box_compare (a1, a2)) ? 1 : 0;
}

caddr_t
bif_rdf_long_of_obj (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t shortobj = bif_arg (qst, args, 0, "__rdf_long_of_obj");
  rdf_box_t *rb;
  query_instance_t * qi = (query_instance_t *) qst;
  if (DV_RDF != DV_TYPE_OF (shortobj))
    return box_copy_tree (shortobj);
  rb = (rdf_box_t *)shortobj;
  if (!rb->rb_is_complete)
    rb_complete (rb, qi->qi_trx, qi);
  rb->rb_ref_count++;
  return shortobj;
}

caddr_t
bif_rdf_box_make_complete (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t shortobj = bif_arg (qst, args, 0, "__rdf_box_make_complete");
  rdf_box_t *rb;
  query_instance_t * qi = (query_instance_t *) qst;
  if (DV_RDF != DV_TYPE_OF (shortobj))
    return box_num (0);
  rb = (rdf_box_t *)shortobj;
  if (rb->rb_is_complete)
    return box_num (0);
  rb_complete (rb, qi->qi_trx, qi);
  return box_num (1);
}

caddr_t
bif_rdf_sqlval_of_obj (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t shortobj = bif_arg (qst, args, 0, "__rdf_sqlval_of_obj");
  dtp_t so_dtp = DV_TYPE_OF (shortobj);
  rdf_box_t *rb;
  query_instance_t * qi = (query_instance_t *) qst;
  if (DV_RDF != so_dtp)
    {
      if ((DV_IRI_ID == so_dtp) || (DV_IRI_ID_8 == so_dtp))
        {
          caddr_t iri;
          iri_id_t iid = unbox_iri_id (shortobj);
	  if ((min_bnode_iri_id () <= iid) && (min_named_bnode_iri_id () > iid))
            return BNODE_IID_TO_LABEL(iid);
          iri = key_id_to_iri (qi, iid);
          if (NULL == iri)
            sqlr_new_error ("RDFXX", ".....", "IRI ID " BOXINT_FMT " does not match any known IRI in __rdf_sqlval_of_obj()",
              (boxint)iid );
	  box_flags (iri) = BF_IRI;
          return iri;
        }
      return box_copy_tree (shortobj);
    }
  rb = (rdf_box_t *)shortobj;
  if (!rb->rb_is_complete)
    rb_complete (rb, qi->qi_trx, qi);
  if (((RDF_BOX_DEFAULT_TYPE == rb->rb_type) && (RDF_BOX_DEFAULT_LANG == rb->rb_lang))
    || ((1 < BOX_ELEMENTS (args)) && bif_long_arg (qst, args, 1, "__rdf_sqlval_of_obj")) )
    return box_copy_tree (rb->rb_box);
  return box_copy (rb);
}

caddr_t
bif_rq_iid_of_o (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t shortobj = bif_arg (qst, args, 0, "__rq_iid_of_o");
  dtp_t so_dtp = DV_TYPE_OF (shortobj);
  if ((DV_IRI_ID == so_dtp) || (DV_IRI_ID_8 == so_dtp))
    return box_copy_tree (shortobj);
  return NEW_DB_NULL;
}

caddr_t
bif_rdf_strsqlval (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t res, val = bif_arg (qst, args, 0, "__rdf_strsqlval");
  dtp_t val_dtp = DV_TYPE_OF (val);
  query_instance_t * qi = (query_instance_t *) qst;
  if (DV_RDF == val_dtp)
    {
      rdf_box_t *rb = (rdf_box_t *)val;
      if (!rb->rb_is_complete)
        rb_complete (rb, qi->qi_trx, qi);
      val = rb->rb_box;
      val_dtp = DV_TYPE_OF (val);
    }
  switch (val_dtp)
    {
      case DV_IRI_ID: case DV_IRI_ID_8:
        {
          iri_id_t iid = unbox_iri_id (val);
          if ((min_bnode_iri_id () <= iid) && (min_named_bnode_iri_id () > iid))
            return BNODE_IID_TO_LABEL(iid);
          res = key_id_to_iri (qi, iid);
          if (NULL == res)
            sqlr_new_error ("RDFXX", ".....", "IRI ID " BOXINT_FMT " does not match any known IRI in __rdf_strsqlval_of_obj()",
              (boxint)iid );
          box_flags (res) = BF_UTF8;
          return res;
        }
      case DV_DATETIME:
        {
          char temp[100];
          dt_to_iso8601_string (val, temp, sizeof (temp));
          return box_dv_short_string (temp);
          break;
        }
      case DV_STRING:
        res = box_copy (val);
        box_flags(res) = BF_UTF8;
        return res;
      case DV_DB_NULL:
        return NEW_DB_NULL;
      default:
        res = box_cast_to_UTF8 (qst, val);
        box_flags(res) = BF_UTF8;
        return res;
    }
}

caddr_t
bif_rdf_long_to_ttl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t val = bif_arg (qst, args, 0, "__rdf_long_to_ttl");
  dk_session_t *out = http_session_no_catch_arg (qst, args, 1, "__rdf_long_to_ttl");
  query_instance_t *qi = (query_instance_t *)qi;
  dtp_t val_dtp = DV_TYPE_OF (val);
  char temp[256];
  if (DV_RDF == val_dtp)
    {
      rdf_box_t *rb = (rdf_box_t *)val;
      if (!rb->rb_is_complete)
        rb_complete (rb, qi->qi_trx, qi);
      val = rb->rb_box;
      val_dtp = DV_TYPE_OF (val);
    }
  switch (val_dtp)
    {
    case DV_DATETIME:
      dt_to_iso8601_string (val, temp, sizeof (temp));
      session_buffered_write (out, temp, strlen (temp));
      break;
    case DV_STRING:
      dks_esc_write (out, val, box_length (val) - 1, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_TTL_DQ);
      break;
    default:
      {
        caddr_t tmp_utf8_box = box_cast_to_UTF8 (qst, val);
        dks_esc_write (out, tmp_utf8_box, box_length (tmp_utf8_box) - 1, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_TTL_DQ);
        dk_free_box (tmp_utf8_box);
        break;
      }
    }
  return (caddr_t)((ptrlong)val_dtp);
}

static query_t *rdf_long_from_batch_params_qr3 = NULL;
static query_t *rdf_long_from_batch_params_qr4 = NULL;
static query_t *rdf_long_from_batch_params_qr5 = NULL;
static const char *rdf_long_from_batch_params_text3 = "SELECT DB.DBA.RDF_MAKE_LONG_OF_SQLVAL (?)";
static const char *rdf_long_from_batch_params_text4 = "SELECT DB.DBA.RDF_MAKE_LONG_OF_TYPEDSQLVAL_STRINGS (?, ?, NULL)";
static const char *rdf_long_from_batch_params_text5 = "SELECT DB.DBA.RDF_MAKE_LONG_OF_TYPEDSQLVAL_STRINGS (?, NULL, ?)";

caddr_t
bif_rdf_long_from_batch_params (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  ptrlong mode = bif_long_arg (qst, args, 0, "__rdf_long_from_batch_params");
  query_instance_t *qi = (query_instance_t *)qst;
  caddr_t res, err = NULL;
  local_cursor_t *lc;
  if (NULL == rdf_long_from_batch_params_qr3)
    sql_compile_many (3, 1,
      rdf_long_from_batch_params_text3	, &rdf_long_from_batch_params_qr3	,
      rdf_long_from_batch_params_text4	, &rdf_long_from_batch_params_qr4	,
      rdf_long_from_batch_params_text5	, &rdf_long_from_batch_params_qr5	,
      NULL );
  switch (mode)
    {
    case 1:
      {
        caddr_t iri = bif_string_or_uname_arg (qst, args, 1, "__rdf_long_from_batch_params");
        res = iri_to_id (qst, iri, IRI_TO_ID_WITH_CREATE, &err);
        if (NULL != err)
          sqlr_resignal (err);
        return res;
      }
    case 2:
      {
        iri_id_t num = sequence_next ("RDF_URL_IID_BLANK", 0);
        return box_iri_id (num);
      }
    case 3:
      {
        caddr_t val = bif_arg (qst, args, 1, "__rdf_long_from_batch_params");
        err = qr_quick_exec (rdf_long_from_batch_params_qr3, qi->qi_client, "", &lc, 1,
          ":0", box_copy_tree (val), QRP_RAW );
        break;
      }
    case 4:
      {
        caddr_t val = bif_arg (qst, args, 1, "__rdf_long_from_batch_params");
        caddr_t dt = bif_string_or_uname_arg (qst, args, 2, "__rdf_long_from_batch_params");
        err = qr_quick_exec (rdf_long_from_batch_params_qr4, qi->qi_client, "", &lc, 2,
          ":0", box_copy_tree (val), QRP_RAW, ":1", box_copy_tree (dt), QRP_RAW );
        break;
      }
    case 5:
      {
        caddr_t val = bif_arg (qst, args, 1, "__rdf_long_from_batch_params");
        caddr_t lang = bif_string_arg (qst, args, 2, "__rdf_long_from_batch_params");
        err = qr_quick_exec (rdf_long_from_batch_params_qr5, qi->qi_client, "", &lc, 2,
          ":0", box_copy_tree (val), QRP_RAW, ":1", box_copy_tree (lang), QRP_RAW );
        break;
      }
    }
  if (NULL != err)
    sqlr_resignal (err);
  if (lc_next (lc))
    res = box_copy_tree (lc_nth_col (lc, 0));
  else
    res = NEW_DB_NULL;
  lc_free (lc);
  return res;
}

caddr_t
rdf_dist_or_redu_ser_long (caddr_t val, caddr_t * err_ret, int is_reduiced, const char *fun_name)
{
  dtp_t val_dtp = DV_TYPE_OF (val);
  if (DV_STRING == val_dtp)
    {
      if ((1 >= box_length (val)) || !(0x80 & val[0]))
	return box_copy (val);
    }
  else if (DV_RDF == val_dtp)
    {
      rdf_bigbox_t *rbb = (rdf_bigbox_t *) val;
      caddr_t subbox = NULL;
      caddr_t res;
#define SER_VEC_SZ (5 * sizeof (caddr_t))
      char buf[6 * sizeof (caddr_t) + BOX_AUTO_OVERHEAD];
      caddr_t *ser_vec;
      caddr_t ptmp;

      BOX_AUTO (ptmp, buf, ((rbb->rbb_base.rb_chksum_tail ? 6 : 5) * sizeof (caddr_t)), DV_ARRAY_OF_POINTER);
      ser_vec = (caddr_t *) ptmp;

      subbox = rbb->rbb_base.rb_box;
      if ((rbb->rbb_base.rb_is_complete) &&
	  (0 != rbb->rbb_base.rb_ro_id) &&
	  (DV_STRING == DV_TYPE_OF (rbb->rbb_base.rb_box)) &&
	  (1024 > box_length (rbb->rbb_base.rb_box)))
	{
	  subbox = box_dv_short_nchars (rbb->rbb_base.rb_box, 1023);
	}

      ser_vec[0] = subbox;
      ser_vec[1] = (caddr_t) (ptrlong) rbb->rbb_base.rb_type;
      ser_vec[2] = (caddr_t) (ptrlong) rbb->rbb_base.rb_lang;

      if (subbox == rbb->rbb_base.rb_box)
	{
	  ser_vec[3] = (caddr_t) (ptrlong) rbb->rbb_base.rb_is_complete;
	  ser_vec[4] = (caddr_t) (ptrlong) 0;
	}
      else
	{
	  ser_vec[3] = (caddr_t) (ptrlong) 0;
	  ser_vec[4] = box_num (rbb->rbb_base.rb_ro_id);
	}
      if (rbb->rbb_base.rb_chksum_tail)
	ser_vec[5] = (caddr_t) rbb->rbb_chksum;

      res = print_object_to_new_string ((caddr_t) ser_vec, fun_name, err_ret);

      if (subbox != rbb->rbb_base.rb_box)
	dk_free_box (subbox);

      BOX_DONE (ser_vec, buf);

      return res;
    }

  return print_object_to_new_string (val, fun_name, err_ret);
}

caddr_t
bif_rdf_dist_ser_long (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t val = bif_arg (qst, args, 0, "__rdf_dist_ser_long");
  return rdf_dist_or_redu_ser_long (val, err_ret, 0, "__rdf_dist_ser_long");
}

caddr_t
bif_rdf_redu_ser_long (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t val = bif_arg (qst, args, 0, "__rdf_redu_ser_long");
  return rdf_dist_or_redu_ser_long (val, err_ret, 1, "__rdf_redu_ser_long");
}

caddr_t
bif_rdf_dist_deser_long (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t ser = bif_arg (qst, args, 0, "__rdf_dist_deser_long");
  caddr_t deser;
  dtp_t ser_dtp = DV_TYPE_OF (ser);
  int ser_len;
  if (DV_STRING != ser_dtp)
    return box_copy_tree (ser);
  ser_len = box_length (ser);
  if ((1 >= ser_len) || !(0x80 & ser[0]))
    return box_copy (ser);
  deser = box_deserialize_string (ser, 0);
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (deser))
    {
      caddr_t *vec = (caddr_t *)deser;
      rdf_bigbox_t *rbb = NULL;
      int vec_elems = BOX_ELEMENTS (vec);
      switch (vec_elems)
        {
        case 5:
          rbb = (rdf_bigbox_t *)rb_allocate ();
          rbb->rbb_base.rb_chksum_tail = 0;
          break;
        case 6:
          rbb = rbb_allocate ();
          rbb->rbb_base.rb_chksum_tail = 1;
          rbb->rbb_chksum = vec[5];
          rbb->rbb_box_dtp = DV_TYPE_OF (vec[0]);
          break;
        default: sqlr_new_error ("RDFXX", ".....", "Argument of __rdf_distinct_deser_long() is not made by __rdf_distinct_ser_long()");
        }
      rbb->rbb_base.rb_box = vec[0];
      rbb->rbb_base.rb_type = (short)((ptrlong)(vec[1]));
      rbb->rbb_base.rb_lang = (short)((ptrlong)(vec[2]));
      rbb->rbb_base.rb_is_complete = unbox (vec[3]);
      rbb->rbb_base.rb_ro_id = unbox (vec[4]);
      if (rbb->rbb_base.rb_ro_id)
        rbb->rbb_base.rb_is_outlined = 1;
      vec[0] = 0;
      dk_free_tree (vec);
      return (caddr_t)rbb;
    }
  return deser;
}

static void
print_short (short s, dk_session_t * ses)
{
  session_buffered_write_char (s >> 8, ses);
  session_buffered_write_char (s & 0xff, ses);
}

void
rb_serialize (caddr_t x, dk_session_t * ses)
{
  /* dv_rdf, flags, data, ro_id, lang or type, opt chksum, opt dtp
   * flags is or of 1. outlined 2. complete 4 has lang 8 has type 0x10 chksum+dtp 0x20 if id 8 bytes */
  client_connection_t *cli = DKS_DB_DATA (ses);
  rdf_box_t * rb = (rdf_box_t *) x;
  rdf_box_audit (rb);
  if ((RDF_BOX_DEFAULT_TYPE != rb->rb_type) && (RDF_BOX_DEFAULT_LANG != rb->rb_lang))
    sr_report_future_error (ses, "", "Both datatype id %d and language id %d are not default in DV_RDF value, can't serialize");
  if (!(rb->rb_is_complete) && !(rb->rb_ro_id))
    sr_report_future_error (ses, "", "Zero ro_id in incomplete DV_RDF value, can't serialize");
  if ((NULL != cli) && cli->cli_version < 3031)
    print_object (rb->rb_box, ses, NULL, NULL);
  else 
    {
      int flags = 0;
      session_buffered_write_char (DV_RDF, ses);
      if (rb->rb_ro_id)
	flags |= RBS_OUTLINED;
      if (rb->rb_ro_id > INT32_MAX)
	flags |= RBS_64;
      if (RDF_BOX_DEFAULT_LANG != rb->rb_lang)
	flags |= RBS_HAS_LANG;
      if (RDF_BOX_DEFAULT_TYPE != rb->rb_type)
	flags |= RBS_HAS_TYPE;
      if (rb->rb_chksum_tail)
	flags |= RBS_CHKSUM;
      if (rb->rb_is_complete && (cli || !(rb->rb_ro_id)))
        {
	  flags |= RBS_COMPLETE;
          flags &= ~RBS_CHKSUM;
          session_buffered_write_char (flags, ses);
          if (DV_XML_ENTITY == DV_TYPE_OF (rb->rb_box))
            xe_serialize ((xml_entity_t *)(rb->rb_box), ses);
          else
	    print_object (rb->rb_box, ses, NULL, NULL);
          if (rb->rb_ro_id)
            {
              if (rb->rb_ro_id > INT32_MAX)
                print_int64_no_tag (rb->rb_ro_id, ses);
              else
                print_long (rb->rb_ro_id, ses);
            }
          if (RDF_BOX_DEFAULT_TYPE != rb->rb_type)
            print_short (rb->rb_type, ses);
          if (RDF_BOX_DEFAULT_LANG != rb->rb_lang)
	    print_short (rb->rb_lang, ses);
          return;
	}
      else if (rb->rb_chksum_tail)
        {
          caddr_t str = ((rdf_bigbox_t *)rb)->rbb_chksum;
          int str_len = box_length (str) - 1;
          flags &= ~RBS_COMPLETE;
          session_buffered_write_char (flags, ses);
	  if (str_len > RB_MAX_INLINED_CHARS)
	    str_len = RB_MAX_INLINED_CHARS;
	  session_buffered_write_char (DV_SHORT_STRING_SERIAL, ses);
	  session_buffered_write_char (str_len, ses);
	  session_buffered_write (ses, str, str_len);
        }
      else if (DV_STRING == DV_TYPE_OF (rb->rb_box))
	{
          caddr_t str = rb->rb_box;
          int str_len = box_length (str) - 1;
          if (rb->rb_is_complete && str_len <= RB_MAX_INLINED_CHARS)
	    flags |= RBS_COMPLETE;
#ifdef RDF_DEBUG
          else if (0 == rb->rb_ro_id)
            GPF_T1 ("Unable to serialize complete but long-valued RDF box with zero ro_id");
#endif
          session_buffered_write_char (flags, ses);
	  if (str_len > RB_MAX_INLINED_CHARS)
	    str_len = RB_MAX_INLINED_CHARS;
	  session_buffered_write_char (DV_SHORT_STRING_SERIAL, ses);
	  session_buffered_write_char (str_len, ses);
	  session_buffered_write (ses, str, str_len);
	}
      else
        {
          if (rb->rb_is_complete)
	    flags |= RBS_COMPLETE;
          session_buffered_write_char (flags, ses);
          print_object (rb->rb_box, ses, NULL, NULL);
        }
      if (rb->rb_ro_id)
	{
	  if (rb->rb_ro_id > INT32_MAX)
	    print_int64_no_tag (rb->rb_ro_id, ses);
	  else
	    print_long (rb->rb_ro_id, ses);
	}
      if (RDF_BOX_DEFAULT_TYPE != rb->rb_type)
	print_short (rb->rb_type, ses);
      if (RDF_BOX_DEFAULT_LANG != rb->rb_lang)
	print_short (rb->rb_lang, ses);
      if (rb->rb_chksum_tail)
        session_buffered_write_char (((rdf_bigbox_t *)rb)->rbb_box_dtp, ses);
    }
}

/* Support for fast serialization of triples and SPARL result sets */

typedef struct ttl_iriref_s {
  caddr_t colname;
  caddr_t uri, ns, prefix, loc;
  ptrlong is_bnode;
  ptrlong is_iri;
} ttl_iriref_t;

typedef struct ttl_iriref_items_s {
  ttl_iriref_t s, p, o, dt;
} ttl_iriref_items_t;

int
iri_cast_and_split_ttl_qname (query_instance_t *qi, caddr_t iri, caddr_t *ns_prefix_ret, caddr_t *local_ret, ptrlong *is_bnode_ret)
{
  is_bnode_ret[0] = 0;
  switch (DV_TYPE_OF (iri))
    {
    case DV_STRING: case DV_UNAME:
      iri_split_ttl_qname (iri, ns_prefix_ret, local_ret, 1);
      return 1;
    case DV_IRI_ID: case DV_IRI_ID_8:
      {
        int res;
        iri_id_t iid = unbox_iri_id (iri);
        if (0L == iid)
          return 0;
        if (min_bnode_iri_id () <= iid)
          {
            if (min_named_bnode_iri_id () > iid)
              {
                ns_prefix_ret[0] = uname___empty;
                local_ret[0] = BNODE_IID_TO_TTL_LABEL_LOCAL (iid);
                is_bnode_ret[0] = 1;
                return 1;
              }
            ns_prefix_ret[0] = uname___empty;
            local_ret[0] = key_id_to_iri (qi, iid);
            return 1;
          }
        res = key_id_to_namespace_and_local (qi, iid, ns_prefix_ret, local_ret);
        if (res)
          {
            caddr_t local = local_ret[0];
            char *tail;
            int local_len = strlen (local);
            for (tail = local + local_len; tail > local; tail--)
              {
                char c = tail[-1];
                if (!isalnum(c) && ('_' != c) && ('-' != c) && !(c & 0x80))
                  break;
              }
            if (isdigit (tail[0]) || ((tail > local) && (NULL == strchr ("#/:?", tail[-1]))))
              tail = local + local_len;
            if (tail != local)
              {
                caddr_t old_ns = ns_prefix_ret[0];
                int old_ns_boxlen = box_length (old_ns);
                caddr_t new_ns = dk_alloc_box (old_ns_boxlen + (tail - local), DV_STRING);
                caddr_t new_local;
                memcpy (new_ns, old_ns, old_ns_boxlen - 1);
                memcpy (new_ns + old_ns_boxlen - 1, local, tail - local);
                new_ns [old_ns_boxlen + (tail - local) - 1] = '\0';
                new_local = box_dv_short_nchars (tail, (local + local_len) - tail);
                dk_free_box (old_ns);
                dk_free_box (local);
                ns_prefix_ret[0] = new_ns;
                local_ret[0] = new_local;
              }
          }
        return res;
      }
    }
  return 0;
}

typedef struct ttl_env_s {
  id_hash_iterator_t *te_used_prefixes;	/*!< Item 1 is the dictionary of used namespace prefixes */
  caddr_t te_prev_subj_ns;		/*!< Item 2 is the namespace part of previous subject. It is DV_STRING except the very beginning of the serializetion when it can be of any type except DV_STRING (non-string will be freed and replaced with NULL pointer inside the printing procedure) */
  caddr_t te_prev_subj_loc;		/*!< Item 3 is the local part of previous subject */
  caddr_t te_prev_pred_ns;		/*!< Item 4 is the namespace part of previous predicate. */
  caddr_t te_prev_pred_loc;		/*!< Item 5 is the local part of previous predicate */
  ptrlong te_ns_count_s_o;		/*!< Item 6 is a counter of created namespaces for subjects and objects */
  ptrlong te_ns_count_p_dt;		/*!< Item 7 is a counter of created namespaces for predicates and datatypes */
  ttl_iriref_t *te_cols;		/*!< Array of temp data for result set columns */
  dk_session_t *te_out_ses;		/*!< Output session, used only for sparql_rset_ttl_write_row */
} ttl_env_t;

int
ttl_http_write_prefix_if_needed (caddr_t *qst, dk_session_t *ses, ttl_env_t *env, ptrlong *ns_counter_ptr, ttl_iriref_t *ti)
{
  id_hash_iterator_t *ns2pref_hit = env->te_used_prefixes;
  id_hash_t *ns2pref = ns2pref_hit->hit_hash;
  caddr_t *prefx_ptr;
  ptrlong ns_counter_val;
#ifndef NDEBUG
  if ('\0' == ti->ns[0])
    GPF_T1("ttl_" "http_write_prefix_if_needed: empty ns");
#endif
  if (ti->is_bnode)
    return 0;
  if (('_' == ti->ns[0]) && (':' == ti->ns[1]))
    return 0;
  prefx_ptr = (caddr_t *)id_hash_get (ns2pref, (caddr_t)(&ti->ns));
  if (NULL != prefx_ptr)
    {
      ti->prefix = box_copy (prefx_ptr[0]);
      return 0;
    }
  ns_counter_val = unbox_inline (ns_counter_ptr[0]);
  if ((8000 <= ns_counter_val) || ((3 * ns2pref->ht_buckets) <= ns_counter_val))
    {
      if (NULL == ti->uri)
        ti->uri = box_dv_short_concat (ti->ns, ti->loc);
      return 0;
    }
  ti->prefix = xml_get_cli_or_global_ns_prefix (qst, ti->ns, ~0);
  if (NULL == ti->prefix)
    ti->prefix = box_sprintf (20, "ns%d", ns2pref->ht_count);
  id_hash_set (ns2pref, (caddr_t)(&ti->ns), (caddr_t)(&(ti->prefix)));
  ti->prefix = box_copy (ti->prefix);
  ns_counter_ptr[0] = ns_counter_val + 1;
  ti->ns = box_copy (ti->ns);
  if (NULL != env->te_prev_subj_ns)
    {
      session_buffered_write (ses, " .\n", 3);
      dk_free_tree (env->te_prev_subj_ns);
      dk_free_tree (env->te_prev_subj_loc);
      dk_free_tree (env->te_prev_pred_ns);
      dk_free_tree (env->te_prev_pred_loc);
      env->te_prev_subj_ns = NULL;
      env->te_prev_subj_loc = NULL;
      env->te_prev_pred_ns = NULL;
      env->te_prev_pred_loc = NULL;
    }
  session_buffered_write (ses, "@prefix ", 8);
  session_buffered_write (ses, ti->prefix, strlen (ti->prefix));
  session_buffered_write (ses, ":\t<", 3);
  dks_esc_write (ses, ti->ns, box_length (ti->ns) - 1, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_TTL_IRI);
  session_buffered_write (ses, "> .\n", 4);
  return 1;
}

void
ttl_http_write_ref (dk_session_t *ses, ttl_env_t *env, ttl_iriref_t *ti)
{
  caddr_t full_uri;
  if (ti->is_bnode)
    {
      session_buffered_write (ses, "_:", 2);
      session_buffered_write (ses, ti->loc, strlen (ti->loc));
      return;
    }
  if (NULL != ti->prefix)
    {
      session_buffered_write (ses, ti->prefix, strlen (ti->prefix));
      session_buffered_write_char (':', ses);
      session_buffered_write (ses, ti->loc, strlen (ti->loc));
      return;
    }
  session_buffered_write_char ('<', ses);
  full_uri = ((NULL != ti->uri) ? ti->uri : ti->loc);
  dks_esc_write (ses, full_uri, box_length (full_uri) - 1, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_TTL_IRI);
  session_buffered_write_char ('>', ses);
}

static void
http_ttl_prepare_obj (query_instance_t *qi, caddr_t obj, dtp_t obj_dtp, ttl_iriref_t *dt_ret)
{
  if (DV_RDF == obj_dtp)
    {
      rdf_box_t *rb = (rdf_box_t *)obj;
      if (!rb->rb_is_complete)
        rb_complete (rb, qi->qi_trx, qi);
      if (RDF_BOX_DEFAULT_TYPE == rb->rb_type)
        return;
      dt_ret->uri = rdf_type_twobyte_to_iri (rb->rb_type);
    }
  else
    {
      if (DV_DATETIME != obj_dtp)
        return;
      switch (DT_DT_TYPE(obj))
        {
        case DT_TYPE_DATE: dt_ret->uri = uname_xmlschema_ns_uri_hash_date; break;
        case DT_TYPE_TIME: dt_ret->uri = uname_xmlschema_ns_uri_hash_time; break;
        default : dt_ret->uri = uname_xmlschema_ns_uri_hash_dateTime; break;
        }
    }
  iri_split_ttl_qname (dt_ret->uri, &dt_ret->ns, &dt_ret->loc, 1);
}

static void
http_ttl_write_obj (dk_session_t *ses, ttl_env_t *env, query_instance_t *qi, caddr_t obj, dtp_t obj_dtp, ttl_iriref_t *dt_ptr)
{
  caddr_t obj_box_value;
  dtp_t obj_box_value_dtp;
  if (DV_RDF == obj_dtp)
    {
      obj_box_value = ((rdf_box_t *)obj)->rb_box;
      obj_box_value_dtp = DV_TYPE_OF (obj_box_value);
    }
  else
    {
      obj_box_value = obj;
      obj_box_value_dtp = obj_dtp;
    }      
  switch (obj_box_value_dtp)
    {
    case DV_DATETIME:
      {
        char temp [50];
        dt_to_iso8601_string (obj_box_value, temp, sizeof (temp));
        session_buffered_write_char ('"', ses);
        session_buffered_write (ses, temp, strlen (temp));
        session_buffered_write_char ('"', ses);
        if (DV_RDF != obj_box_value_dtp)
          {
            session_buffered_write (ses, "^^", 2);
            ttl_http_write_ref (ses, env, dt_ptr);
          }
        break;
      }
    case DV_STRING:
      session_buffered_write_char ('"', ses);
      dks_esc_write (ses, obj_box_value, box_length (obj_box_value) - 1, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_TTL_DQ);
      session_buffered_write_char ('"', ses);
      break;
    case DV_DB_NULL:
      session_buffered_write (ses, "(NULL)", 6);
      break;
    default:
      {
        caddr_t tmp_utf8_box = box_cast_to_UTF8 ((caddr_t *)qi, obj_box_value);
        if (DV_RDF == obj_dtp)
          session_buffered_write_char ('"', ses);
        session_buffered_write (ses, tmp_utf8_box, box_length (tmp_utf8_box) - 1);
        if (DV_RDF == obj_dtp)
          session_buffered_write_char ('"', ses);
        dk_free_box (tmp_utf8_box);
        break;
      }
    }
  if (DV_RDF == obj_dtp)
    {
      rdf_box_t *rb = (rdf_box_t *)obj;
      if (RDF_BOX_DEFAULT_LANG != rb->rb_lang)
        {
          caddr_t lang_id = rdf_lang_twobyte_to_string (rb->rb_lang);
          if (NULL != lang_id) /* just in case if lang cannot be found, may be signal an error ? */
            {
              session_buffered_write_char ('@', ses);
              session_buffered_write (ses, lang_id, box_length (lang_id) - 1);
            }
        }
      if (RDF_BOX_DEFAULT_TYPE != rb->rb_type)
        {
          session_buffered_write (ses, "^^", 2);
          ttl_http_write_ref (ses, env, dt_ptr);
        }
    }
}

caddr_t
bif_http_ttl_triple (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *)qst;
  ttl_env_t *env = (ttl_env_t *)bif_arg (qst, args, 0, "http_ttl_triple");
  caddr_t subj = bif_arg (qst, args, 1, "http_ttl_triple");
  caddr_t pred = bif_arg (qst, args, 2, "http_ttl_triple");
  caddr_t obj = bif_arg (qst, args, 3, "http_ttl_triple");
  dk_session_t *ses = http_session_no_catch_arg (qst, args, 4, "http_ttl_triple");
  int status = 0;
  int obj_is_iri = 0;
  dtp_t obj_dtp = 0;
  ttl_iriref_items_t tii;
  memset (&tii,0, sizeof (ttl_iriref_items_t));
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF ((caddr_t)env) ||
    (sizeof (ttl_env_t) != box_length ((caddr_t)env)) ||
    (DV_DICT_ITERATOR != DV_TYPE_OF (env->te_used_prefixes)) ||
    (((DV_STRING == DV_TYPE_OF (env->te_prev_subj_ns)) || (DV_UNAME == DV_TYPE_OF (env->te_prev_subj_ns))) &&
      ((DV_STRING != DV_TYPE_OF (env->te_prev_subj_loc)) ||	
        ((DV_STRING != DV_TYPE_OF (env->te_prev_pred_ns)) && (DV_UNAME != DV_TYPE_OF (env->te_prev_pred_ns))) ||
        (DV_STRING != DV_TYPE_OF (env->te_prev_pred_loc)) ) ) ||
    (DV_LONG_INT != DV_TYPE_OF (env->te_ns_count_s_o)) ||	
    (DV_LONG_INT != DV_TYPE_OF (env->te_ns_count_p_dt)) )	
    sqlr_new_error ("22023", "SR601", "Argument 1 of http_ttl_triple() should be an array of special format");
  if (!iri_cast_and_split_ttl_qname (qi, subj, &tii.s.ns, &tii.s.loc, &tii.s.is_bnode))
    goto fail; /* see below */
  if (!iri_cast_and_split_ttl_qname (qi, pred, &tii.p.ns, &tii.p.loc, &tii.p.is_bnode))
    goto fail; /* see below */
  obj_dtp = DV_TYPE_OF (obj);
  switch (obj_dtp)
    {
    case DV_UNAME: case DV_IRI_ID: case DV_IRI_ID_8: obj_is_iri = 1; break;
    case DV_STRING: obj_is_iri = (BF_IRI & box_flags (obj)) ? 1 : 0; break;
    default: obj_is_iri = 0; break;
    }
  if (obj_is_iri)
    {
      if (!iri_cast_and_split_ttl_qname (qi, obj, &tii.o.ns, &tii.o.loc, &tii.o.is_bnode))
        goto fail; /* see below */
    }
  else
    http_ttl_prepare_obj (qi, obj, obj_dtp, &tii.dt);
  if ((DV_STRING != DV_TYPE_OF (env->te_prev_subj_ns)) && (DV_UNAME != DV_TYPE_OF (env->te_prev_subj_ns)))
    {
      dk_free_tree (env->te_prev_subj_ns);	env->te_prev_subj_ns = NULL;
      dk_free_tree (env->te_prev_subj_loc);	env->te_prev_subj_loc = NULL;
      dk_free_tree (env->te_prev_pred_ns);	env->te_prev_pred_ns = NULL;
      dk_free_tree (env->te_prev_pred_loc);	env->te_prev_pred_loc = NULL;
    }
  if ((NULL != tii.dt.ns) && ('\0' != tii.dt.ns[0]))
    status += ttl_http_write_prefix_if_needed (qst, ses, env, &(env->te_ns_count_p_dt), &(tii.dt));
  if ((NULL != tii.p.ns) && ('\0' != tii.p.ns[0]))
    status += ttl_http_write_prefix_if_needed (qst, ses, env, &(env->te_ns_count_p_dt), &(tii.p));
  if ((NULL != tii.s.ns) && ('\0' != tii.s.ns[0]))
    status += ttl_http_write_prefix_if_needed (qst, ses, env, &(env->te_ns_count_s_o), &(tii.s));
  if ((NULL != tii.o.ns) && ('\0' != tii.o.ns[0]))
    status += ttl_http_write_prefix_if_needed (qst, ses, env, &(env->te_ns_count_s_o), &(tii.o));
  if ((NULL == env->te_prev_subj_ns) ||
    strcmp (env->te_prev_subj_ns, tii.s.ns) ||
    strcmp (env->te_prev_subj_loc, tii.s.loc) )
    {
      if (NULL != env->te_prev_subj_ns)
        {
          session_buffered_write (ses, " .\n", 3);
          dk_free_tree (env->te_prev_subj_ns);	env->te_prev_subj_ns = NULL;
          dk_free_tree (env->te_prev_subj_loc);	env->te_prev_subj_loc = NULL;
          dk_free_tree (env->te_prev_pred_ns);	env->te_prev_pred_ns = NULL;
          dk_free_tree (env->te_prev_pred_loc);	env->te_prev_pred_loc = NULL;
        }
      ttl_http_write_ref (ses, env, &(tii.s));
      session_buffered_write_char ('\t', ses);
      env->te_prev_subj_ns = tii.s.ns;		tii.s.ns = NULL;
      env->te_prev_subj_loc = tii.s.loc;	tii.s.loc = NULL;
    }
  if ((NULL == env->te_prev_pred_ns) ||
    strcmp (env->te_prev_pred_ns, tii.p.ns) ||
    strcmp (env->te_prev_pred_loc, tii.p.loc) )
    {
      if (NULL != env->te_prev_pred_ns)
        {
          session_buffered_write (ses, " ;\n\t", 4);
          dk_free_tree (env->te_prev_pred_ns);	env->te_prev_pred_ns = NULL;
          dk_free_tree (env->te_prev_pred_loc);	env->te_prev_pred_loc = NULL;
        }
      ttl_http_write_ref (ses, env, &(tii.p));
      session_buffered_write_char ('\t', ses);
      env->te_prev_pred_ns = tii.p.ns;		tii.p.ns = NULL;
      env->te_prev_pred_loc = tii.p.loc;	tii.p.loc = NULL;
    }
  else
    session_buffered_write (ses, " ,\n\t\t", 5);
  if (obj_is_iri)
    ttl_http_write_ref (ses, env, &(tii.o));
  else
    http_ttl_write_obj (ses, env, qi, obj, obj_dtp, &tii.dt);
fail:
  dk_free_box (tii.s.uri);	dk_free_box (tii.s.ns);		dk_free_box (tii.s.loc);	dk_free_box (tii.s.prefix);
  dk_free_box (tii.p.uri);	dk_free_box (tii.p.ns);		dk_free_box (tii.p.loc);	dk_free_box (tii.p.prefix);
  dk_free_box (tii.o.uri);	dk_free_box (tii.o.ns);		dk_free_box (tii.o.loc);	dk_free_box (tii.o.prefix);
  dk_free_box (tii.dt.uri);	dk_free_box (tii.dt.ns);	dk_free_box (tii.dt.loc);	dk_free_box (tii.dt.prefix);
  return (caddr_t)(ptrlong)(status);
}

caddr_t
bif_sparql_rset_ttl_write_row (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *)qst;
  ttl_env_t *env = (ttl_env_t *)bif_arg (qst, args, 1, "sparql_rset_ttl_write_row");
  caddr_t *row = (caddr_t *)bif_arg (qst, args, 2, "sparql_rset_ttl_write_row");
  dk_session_t *ses;
  int colctr, colcount, need_semicolon;
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF ((caddr_t)env) ||
    (sizeof (ttl_env_t) != box_length ((caddr_t)env)) ||
    (DV_DICT_ITERATOR != DV_TYPE_OF (env->te_used_prefixes)) ||
    (DV_LONG_INT != DV_TYPE_OF (env->te_ns_count_s_o)) ||	
    (DV_LONG_INT != DV_TYPE_OF (env->te_ns_count_p_dt)) ||
    ((DV_LONG_INT != DV_TYPE_OF (env->te_out_ses)) && (DV_STRING_SESSION != DV_TYPE_OF (env->te_out_ses))) ||
    (DV_ARRAY_OF_POINTER != DV_TYPE_OF ((caddr_t)(env->te_cols))) ||
    (box_length ((caddr_t)(env->te_cols)) % sizeof (ttl_iriref_t)) )
    sqlr_new_error ("22023", "SR605", "Argument 2 of sparql_rset_ttl_write_row() should be an array of special format");
  ses = env->te_out_ses;
  if (DV_LONG_INT == DV_TYPE_OF (ses))
    {
      ses = qi->qi_client->cli_http_ses; /*(dk_session_t *)((ptrlong)(unbox ((caddr_t)ses)));*/
      if (!ses)
	sqlr_new_error ("37000", "HT081",
	    "Function sparql_rset_ttl_write_row() outside of HTTP context and no stream specified");
        }
  colcount = box_length ((caddr_t)(env->te_cols)) / sizeof (ttl_iriref_t);
  if ((DV_ARRAY_OF_POINTER != DV_TYPE_OF (row)) || (BOX_ELEMENTS (row) != colcount))
    sqlr_new_error ("22023", "SR606", "Argument 3 of sparql_rset_ttl_write_row() should be an array of values and length should match to the argument 2");
  if (NULL != env->te_prev_subj_ns)
    {
      dk_free_box (env->te_prev_subj_ns);
      env->te_prev_subj_ns = NULL;
    }
  for (colctr = 0; colctr < colcount; colctr++)
            {
      ttl_iriref_t *col_ti = env->te_cols + colctr;
      caddr_t obj = row[colctr];
      dtp_t obj_dtp = DV_TYPE_OF (obj);
      int obj_is_iri;
      switch (obj_dtp)
                {
        case DV_DB_NULL: continue;
        case DV_UNAME: case DV_IRI_ID: case DV_IRI_ID_8: obj_is_iri = 1; break;
        case DV_STRING: obj_is_iri = (BF_IRI & box_flags (obj)) ? 1 : 0; break;
        default: obj_is_iri = 0; break;
            }
      col_ti->is_iri = obj_is_iri;
      if (obj_is_iri)
        iri_cast_and_split_ttl_qname (qi, obj, &(col_ti->ns), &(col_ti->loc), &(col_ti->is_bnode));
      else
        http_ttl_prepare_obj (qi, obj, obj_dtp, col_ti);
      if ((NULL != col_ti->ns) && ('\0' != col_ti->ns[0]))
        ttl_http_write_prefix_if_needed (qst, ses, env,
         (obj_is_iri ? &(env->te_ns_count_s_o) : &(env->te_ns_count_p_dt)) , col_ti );
            }
  SES_PRINT (ses, "_:_ res:solution [");
  need_semicolon = 0;
  for (colctr = 0; colctr < colcount; colctr++)
            {
      ttl_iriref_t *col_ti = env->te_cols + colctr;
      caddr_t obj = row[colctr];
      dtp_t obj_dtp = DV_TYPE_OF (obj);
      if (DV_DB_NULL != obj_dtp)
        {
          if (need_semicolon)
            SES_PRINT (ses, " ;");
          else
            need_semicolon = 1;
          SES_PRINT (ses, "\n      res:binding [ res:variable \"");
          dks_esc_write (ses, col_ti->colname, strlen (col_ti->colname), CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_TTL_DQ);
          SES_PRINT (ses, "\" ; res:value ");
          if (col_ti->is_iri)
            ttl_http_write_ref (ses, env, col_ti);
          else
            http_ttl_write_obj (ses, env, qi, obj, obj_dtp, col_ti);
          SES_PRINT (ses, " ]");
        }
      dk_free_box (col_ti->uri);	col_ti->uri = NULL;
      dk_free_box (col_ti->ns);		col_ti->ns = NULL;
      dk_free_box (col_ti->loc);	col_ti->loc = NULL;
      dk_free_box (col_ti->prefix);	col_ti->prefix = NULL;
    }
  SES_PRINT (ses, " ] .\n");
  return NULL;
}

caddr_t
bif_sparql_rset_xml_write_row (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *)qst;
  dk_session_t *ses = http_session_no_catch_arg (qst, args, 0, "sparql_rset_xml_write_row");
  caddr_t *colnames = (caddr_t *)bif_arg (qst, args, 1, "sparql_rset_xml_write_row");
  caddr_t *row = (caddr_t *)bif_arg (qst, args, 2, "sparql_rset_xml_write_row");
  int colctr, colcount;
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (colnames))
    sqlr_new_error ("22023", "SR602", "Argument 2 of sparql_rset_xml_write_row() should be an array of strings (variable names)");
  colcount = BOX_ELEMENTS (colnames);
  if ((DV_ARRAY_OF_POINTER != DV_TYPE_OF (row)) || (BOX_ELEMENTS (row) != colcount))
    sqlr_new_error ("22023", "SR603", "Argument 3 of sparql_rset_xml_write_row() should be an array of values and length should match to the argument 2");
  SES_PRINT (ses, "\n <result>");
  for (colctr = 0; colctr < colcount; colctr++)
    {
      caddr_t name = colnames [colctr];
      caddr_t val = row [colctr];
      dtp_t val_dtp = DV_TYPE_OF (val);
      if (DV_DB_NULL == val_dtp)
        continue;
      if (DV_STRING != DV_TYPE_OF (name))
        sqlr_new_error ("22023", "SR604", "Argument 2 of sparql_rset_xml_write_row() should be an array of strings and only strings");
      SES_PRINT (ses, "\n  <binding name=\"");
      SES_PRINT (ses, name);
      SES_PRINT (ses, "\">");
      switch (val_dtp)
        {
        case DV_IRI_ID:
          {
            iri_id_t id = unbox_iri_id (val);
            caddr_t iri;
            if (id >= min_bnode_iri_id ())
              {
                SES_PRINT (ses, "<bnode>");
                if (id >= min_named_bnode_iri_id ())
                  {
                    iri = key_id_to_iri (qi, id);
                    if (NULL == iri)
                      {
                        char buf[50];
                        sprintf (buf, "bad://" BOXINT_FMT, (boxint)iri);
                        SES_PRINT (ses, buf);
                      }
                    else
                      dks_esc_write (ses, iri, box_length_inline (iri)-1, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_PTEXT);
                  }
                else
                  {
                    char buf[50];
                    BNODE_IID_TO_LABEL_BUFFER (buf, id);
                    SES_PRINT (ses, buf);
                  }
                SES_PRINT (ses, "</bnode>");
              }
            else
              {
                SES_PRINT (ses, "<uri>");
                iri = key_id_to_iri (qi, id);
                if (NULL == iri)
                  {
                    char buf[50];
                    sprintf (buf, "bad://" BOXINT_FMT, (boxint)iri);
                    SES_PRINT (ses, buf);
                  }
                else
                  dks_esc_write (ses, iri, box_length_inline (iri)-1, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_PTEXT);
                SES_PRINT (ses, "</uri>");
              }
            break;
          }
        case DV_STRING:
          {
            if (!(BF_IRI & box_flags (val)))
              {
                SES_PRINT (ses, "<literal>");
                dks_esc_write (ses, val, box_length_inline (val)-1, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_PTEXT);
                SES_PRINT (ses, "</literal>");
                break;
              }
            /* no break */
          }
        case DV_UNAME:
          {
/*                             0123456789 */
            int is_uri = strncmp (val, "nodeID://", 9);
            if (is_uri) SES_PRINT (ses, "<uri>"); else SES_PRINT (ses, "<bnode>");
            dks_esc_write (ses, val, box_length_inline (val)-1, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_PTEXT);
            if (is_uri) SES_PRINT (ses, "</uri>"); else SES_PRINT (ses, "</bnode>");
            break;
          }
        case DV_RDF:
          {
            rdf_box_t *rb = (rdf_box_t *)val;
            if (RDF_BOX_DEFAULT_TYPE != rb->rb_type)
              {
                caddr_t iri = rdf_type_twobyte_to_iri (rb->rb_type);
                if (NULL != iri)
                  {
                    SES_PRINT (ses, "<literal datatype=\"");
                    dks_esc_write (ses, iri, box_length_inline (iri)-1, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_SQATTR);
                    SES_PRINT (ses, "\">");
                    goto literal_elt_printed; /* see below */
                  }
                else
                  SES_PRINT (ses, "<!-- bad datatype ID -->");
              }
            else if (RDF_BOX_DEFAULT_LANG != rb->rb_lang)
              {
                caddr_t l = rdf_lang_twobyte_to_string (rb->rb_lang);
                if (NULL != l)
                  {
                    SES_PRINT (ses, "<literal xml:lang=\"");
                    dks_esc_write (ses, l, box_length_inline (l)-1, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_SQATTR);
                    SES_PRINT (ses, "\">");
                    goto literal_elt_printed; /* see below */
                  }
                else
                  SES_PRINT (ses, "<!-- bad language ID -->");
              }
            else
              SES_PRINT (ses, "<literal>");

literal_elt_printed:
            if (!rb->rb_is_complete)
              rb_complete (rb, qi->qi_trx, qi);
            if (DV_DATETIME == DV_TYPE_OF (rb->rb_box))
              {
                char temp [50];
                dt_to_iso8601_string (rb->rb_box, temp, sizeof (temp));
                session_buffered_write (ses, temp, strlen (temp));
              }
            else
              dks_sqlval_esc_write (qst, ses, rb->rb_box, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_PTEXT);
            SES_PRINT (ses, "</literal>");
            break;
          }
        default:
          {
            ccaddr_t iri = xsd_type_of_box (val);
            if (IS_BOX_POINTER (iri))
              {
                SES_PRINT (ses, "<literal datatype=\"");
                dks_esc_write (ses, iri, box_length_inline (iri)-1, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_SQATTR);
                SES_PRINT (ses, "\">");
              }
            else
              SES_PRINT (ses, "<literal>");
            if (DV_DATETIME == DV_TYPE_OF (val))
              {
                char temp [50];
                dt_to_iso8601_string (val, temp, sizeof (temp));
                session_buffered_write (ses, temp, strlen (temp));
              }
            else
              dks_sqlval_esc_write (qst, ses, val, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_PTEXT);
            SES_PRINT (ses, "</literal>");
          }
        }
      SES_PRINT (ses, "</binding>");
    }
  SES_PRINT (ses, "\n </result>");
  return NULL;
}

id_hash_iterator_t *rdf_graph_group_dict_hit;
id_hash_t *rdf_graph_group_dict_htable;

id_hash_iterator_t *rdf_graph_public_perms_dict_hit;
id_hash_t *rdf_graph_public_perms_dict_htable;

id_hash_iterator_t *rdf_graph_default_perms_of_user_dict_hit;
id_hash_t *rdf_graph_default_perms_of_user_dict_htable;

caddr_t
bif_rdf_graph_group_dict (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return box_copy (rdf_graph_group_dict_hit);
}

caddr_t
bif_rdf_graph_public_perms_dict (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return box_copy (rdf_graph_public_perms_dict_hit);
}

caddr_t
bif_rdf_graph_default_perms_of_user_dict (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return box_copy (rdf_graph_default_perms_of_user_dict_hit);
}

void
rdf_box_init ()
{
  dk_mem_hooks (DV_RDF, (box_copy_f) rb_copy, (box_destr_f)rb_free, 1);
  PrpcSetWriter (DV_RDF, (ses_write_func) rb_serialize);
  dk_dtp_register_hash (DV_RDF, rdf_box_hash, rdf_box_hash_cmp);
  rdf_graph_group_dict_htable = (id_hash_t *)box_dv_dict_hashtable (31);
  rdf_graph_group_dict_htable->ht_rehash_threshold = 120;
  rdf_graph_group_dict_htable->ht_dict_refctr = ID_HASH_LOCK_REFCOUNT;
  rdf_graph_group_dict_hit = (id_hash_iterator_t *)box_dv_dict_iterator ((caddr_t)rdf_graph_group_dict_htable);
  rdf_graph_public_perms_dict_htable = (id_hash_t *)box_dv_dict_hashtable (31);
  rdf_graph_public_perms_dict_htable->ht_rehash_threshold = 120;
  rdf_graph_public_perms_dict_htable->ht_dict_refctr = ID_HASH_LOCK_REFCOUNT;
  rdf_graph_public_perms_dict_hit = (id_hash_iterator_t *)box_dv_dict_iterator ((caddr_t)rdf_graph_public_perms_dict_htable);
  rdf_graph_default_perms_of_user_dict_htable = (id_hash_t *)box_dv_dict_hashtable (31);
  rdf_graph_default_perms_of_user_dict_htable->ht_rehash_threshold = 120;
  rdf_graph_default_perms_of_user_dict_htable->ht_dict_refctr = ID_HASH_LOCK_REFCOUNT;
  rdf_graph_default_perms_of_user_dict_hit = (id_hash_iterator_t *)box_dv_dict_iterator ((caddr_t)rdf_graph_default_perms_of_user_dict_htable);
  bif_define ("rdf_box", bif_rdf_box);
  bif_define_typed ("is_rdf_box", bif_is_rdf_box, &bt_integer);
  bif_define_typed ("rdf_box_set_data", bif_rdf_box_set_data, &bt_any);
  bif_define ("rdf_box_data", bif_rdf_box_data);
  bif_define_typed ("rdf_box_data_tag", bif_rdf_box_data_tag, &bt_integer);
  bif_define_typed ("rdf_box_ro_id", bif_rdf_box_ro_id, &bt_integer);
  bif_define ("rdf_box_set_ro_id", bif_rdf_box_set_ro_id);
  bif_define_typed ("rdf_box_lang", bif_rdf_box_lang, &bt_integer);
  bif_define_typed ("rdf_box_type", bif_rdf_box_type, &bt_integer);
  bif_define ("rdf_box_set_type", bif_rdf_box_set_type);
  bif_define ("rdf_box_chksum", bif_rdf_box_chksum);
  bif_define_typed ("rdf_box_is_complete", bif_rdf_box_is_complete, &bt_integer);
  /*bif_define_typed ("rdf_box_set_is_complete", bif_rdf_box_set_is_complete, &bt_integer);*/
  bif_define_typed ("rdf_box_is_storeable", bif_rdf_box_is_storeable, &bt_integer);
  bif_define_typed ("rdf_box_needs_digest", bif_rdf_box_needs_digest, &bt_integer);
  bif_define_typed ("rdf_box_strcmp", bif_rdf_box_strcmp, &bt_integer);
  bif_define_typed ("__rdf_long_of_obj", bif_rdf_long_of_obj, &bt_any);
  bif_set_uses_index (bif_rdf_long_of_obj);
  bif_define_typed ("__rdf_box_make_complete", bif_rdf_box_make_complete, &bt_integer);
  bif_set_uses_index (bif_rdf_box_make_complete);
  bif_define_typed ("__rdf_sqlval_of_obj", bif_rdf_sqlval_of_obj, &bt_any);
  bif_set_uses_index (bif_rdf_sqlval_of_obj);
  bif_define_typed ("__rdf_strsqlval", bif_rdf_strsqlval, &bt_varchar);
  bif_set_uses_index (bif_rdf_strsqlval);
  bif_define_typed ("__rdf_long_to_ttl", bif_rdf_long_to_ttl, &bt_any);
  bif_set_uses_index (bif_rdf_long_to_ttl);
  bif_define_typed ("__rq_iid_of_o", bif_rq_iid_of_o, &bt_any);
  bif_define ("__rdf_long_from_batch_params", bif_rdf_long_from_batch_params);

  bif_define_typed ("__rdf_dist_ser_long", bif_rdf_dist_ser_long, &bt_varchar);
  bif_define_typed ("__rdf_dist_deser_long", bif_rdf_dist_deser_long, &bt_any);
  bif_define_typed ("__rdf_redu_ser_long", bif_rdf_redu_ser_long, &bt_varchar);
  bif_define_typed ("__rdf_redu_deser_long", bif_rdf_dist_deser_long, &bt_any);
  bif_define ("http_ttl_triple", bif_http_ttl_triple);
  bif_set_uses_index (bif_http_ttl_triple);
  bif_define ("sparql_rset_ttl_write_row", bif_sparql_rset_ttl_write_row);
  bif_set_uses_index (bif_sparql_rset_xml_write_row);
  bif_define ("sparql_rset_xml_write_row", bif_sparql_rset_xml_write_row);
  bif_set_uses_index (bif_sparql_rset_xml_write_row);
  /* Short aliases for use in generated SQL text: */
  bif_define ("__ro2lo", bif_rdf_long_of_obj);
  bif_define_typed ("__ro2sq", bif_rdf_sqlval_of_obj, &bt_any);
  bif_define ("__rdf_graph_group_dict", bif_rdf_graph_group_dict);
  bif_define ("__rdf_graph_public_perms_dict", bif_rdf_graph_public_perms_dict);
  bif_define ("__rdf_graph_default_perms_of_user_dict", bif_rdf_graph_default_perms_of_user_dict);
}
