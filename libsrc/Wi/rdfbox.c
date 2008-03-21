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

void
rdf_box_audit_impl (rdf_box_t * rb)
{
  if (0 >= rb->rb_ref_count)
    GPF_T1("RDF box has nonpositive reference count");
#ifdef RDF_DEBUG
  if ((0 == rb->rb_ro_id) && (0 == rb->rb_is_complete))
    GPF_T1("RDF box is too incomplete");
#endif
}


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

rdf_box_t *
rb_allocate (void)
{
  rdf_box_t * rb= (rdf_box_t *) dk_alloc_box_zero (sizeof (rdf_box_t), DV_RDF);
  rb->rb_ref_count = 1;
  return rb;
}

rdf_bigbox_t *
rbb_allocate (void)
{
  rdf_bigbox_t * rbb= (rdf_bigbox_t *) dk_alloc_box_zero (sizeof (rdf_bigbox_t), DV_RDF);
  rbb->rbb_base.rb_ref_count = 1;
  return rbb;
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


#define RBS_OUTLINED	0x01
#define RBS_COMPLETE	0x02
#define RBS_HAS_LANG	0x04
#define RBS_HAS_TYPE	0x08
#define RBS_CHKSUM	0x10
#define RBS_64		0x20


int 
rbs_length (db_buf_t rbs)
{
  long hl, l;
  dtp_t flags = rbs[1];
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


static void
print_short (short s, dk_session_t * ses)
{
  session_buffered_write_char (s >> 8, ses);
  session_buffered_write_char (s & 0xff, ses);
}

static short 
read_short (dk_session_t * ses)
{
  short s = ((short) (dtp_t)session_buffered_read_char (ses)) << 8;
  s |= (dtp_t) session_buffered_read_char (ses);
  return s;
}


void
rb_serialize (caddr_t x, dk_session_t * ses)
{
  /* dv_rdf, flags, data, ro_id, lang or type, opt chksum, opt dtp
   * flags is or of 1. outlined 2. complete 4 has lang 8 has type 0x10 chksum+dtp 0x20 if id 8 bytes */
  rdf_box_t * rb = (rdf_box_t *) x;
  rdf_box_audit (rb);
  if ((RDF_BOX_DEFAULT_TYPE != rb->rb_type) && (RDF_BOX_DEFAULT_LANG != rb->rb_lang))
    sr_report_future_error (ses, "", "Both datatype id %d and language id %d are not default in DV_RDF value, can't serialize");
  if (!(rb->rb_is_complete) && !(rb->rb_ro_id))
    sr_report_future_error (ses, "", "Zero ro_id in incomplete DV_RDF value, can't serialize");
  if (DKS_DB_DATA (ses))
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
      if (rb->rb_chksum_tail)
        {
          caddr_t str = ((rdf_bigbox_t *)rb)->rbb_chksum;
          int str_len = box_length (str) - 1;
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
	print_short  (rb->rb_type, ses);
      if (RDF_BOX_DEFAULT_LANG != rb->rb_lang)
	print_short (rb->rb_lang, ses);
      if (rb->rb_chksum_tail)
        session_buffered_write_char (((rdf_bigbox_t *)rb)->rbb_box_dtp, ses);
    }
}


caddr_t
rb_deserialize (dk_session_t * ses)
{
  rdf_box_t * rb;
  dtp_t flags = session_buffered_read_char (ses);
  if (flags & RBS_CHKSUM)
    {
      rb = (rdf_box_t *)rbb_allocate ();
      rb->rb_chksum_tail = 1;
      ((rdf_bigbox_t *)rb)->rbb_chksum = scan_session_boxing (ses);
    }
  else
    {
      rb = rb_allocate ();
  rb->rb_box = scan_session_boxing (ses);
    }
  if (flags & RBS_OUTLINED)
    {
      if (flags & RBS_64)
	rb->rb_ro_id = read_int64 (ses);
      else
    rb->rb_ro_id = read_long (ses);
    }
  if (flags & RBS_COMPLETE)
    rb->rb_is_complete = 1;
  if (flags & RBS_HAS_TYPE)
    rb->rb_type = read_short (ses);
  else
    rb->rb_type = RDF_BOX_DEFAULT_TYPE;
  if (flags & RBS_HAS_LANG)
    rb->rb_lang = read_short (ses);
  else
    rb->rb_lang = RDF_BOX_DEFAULT_LANG;
  if (flags & RBS_CHKSUM)
    ((rdf_bigbox_t *)rb)->rbb_box_dtp = session_buffered_read_char (ses);
  if ((RDF_BOX_DEFAULT_TYPE != rb->rb_type) && (RDF_BOX_DEFAULT_LANG != rb->rb_lang))
    sr_report_future_error (ses, "", "Both datatype id %d and language id %d are not default in DV_RDF value, can't deserialize");
  if (!(rb->rb_is_complete) && !(rb->rb_ro_id))
    sr_report_future_error (ses, "", "Zero ro_id in incomplete DV_RDF value, can't deserialize");
  rdf_box_audit (rb);
  return (caddr_t) rb;
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
  /* arrange so that if both are not rdf boxes, trhe one that is an rdf box is first */
  if (DV_RDF != dtp1)
    {
      int res = dv_rdf_compare (dv2, dv1);
      return ((res == DVC_GREATER) ? DVC_LESS : ((res == DVC_LESS) ? DVC_GREATER : res));
    }
  flags1 = dv1[1];
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
  if (DV_RDF == dtp2)
    {
      flags2 = dv2[1];
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
      rdftype2 = ((RBS_HAS_TYPE & flags2) ? SHORT_REF_NA (data2 + len2 + RBS_RO_ID_LEN (flags2)) : RDF_BOX_DEFAULT_TYPE);
      rdflang2 = ((RBS_HAS_LANG & flags2) ? SHORT_REF_NA (data2 + len2 + RBS_RO_ID_LEN (flags2)) : RDF_BOX_DEFAULT_LANG);
    }
  else
    {
      /* rdf string and non rdf */
      if (DV_STRING != dtp2 && DV_SHORT_STRING_SERIAL != dtp2)
        return DVC_LESS;
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
  len1 = data1[1];
  data1 += 2;
  rdftype1 = ((RBS_HAS_TYPE & flags1) ? SHORT_REF_NA (data1 + len1 + RBS_RO_ID_LEN (flags1)) : RDF_BOX_DEFAULT_TYPE);
  if (rdftype1 < rdftype2) return DVC_LESS;
  if (rdftype1 > rdftype2) return DVC_GREATER;
  rdflang1 = ((RBS_HAS_LANG & flags1) ? SHORT_REF_NA (data1 + len1 + RBS_RO_ID_LEN (flags1)) : RDF_BOX_DEFAULT_LANG);
  if (rdflang1 < rdflang2) return DVC_LESS;
  if (rdflang1 > rdflang2) return DVC_GREATER;
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
          /*return DVC_MATCH; -- Complete boxes that differ only in ro_id are intentionally kept distinct in table but equal in memory */
    }
    else if (cmp_len < RB_MAX_INLINED_CHARS)
	{
        if ((len1 == cmp_len) && (len2 > cmp_len))
		return DVC_LESS;
        if ((len2 == cmp_len) && (len1 > cmp_len))
		return DVC_GREATER;
	    }
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
   * If the rdf string is complete, ity is eq if no language.  */
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
  /* arrange so that if both are not rdf boxes, trhe one that is a box is first */
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
        return cmp_boxes (rb1, data2, NULL, NULL);
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
  if ((0 != rb->rb_ro_id) && !rb->rb_is_complete)
    return rb->rb_ro_id + (rb->rb_ro_id << 16);
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
          if (min_bnode_iri_id () <= iid)
            return BNODE_IID_TO_LABEL(iid);
          iri = key_id_to_iri (qi, iid);
          if (NULL == iri)
            sqlr_new_error ("RDFXX", ".....", "IRI ID " BOXINT_FMT " does not match any known IRI in __rdf_sqlval_of_obj()",
              (boxint)iid );
          return iri;
        }
      return box_copy_tree (shortobj);
    }
  rb = (rdf_box_t *)shortobj;
  if (!rb->rb_is_complete)
    rb_complete (rb, qi->qi_trx, qi);
  return box_copy_tree (rb->rb_box);
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

void
rdf_box_init ()
{
  dk_mem_hooks (DV_RDF, (box_copy_f) rb_copy, (box_destr_f)rb_free, 0);
  PrpcSetWriter (DV_RDF, (ses_write_func) rb_serialize);
  get_readtable ()[DV_RDF] = (macro_char_func) rb_deserialize;
  dk_dtp_register_hash (DV_RDF, rdf_box_hash, rdf_box_hash_cmp);
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
  bif_define_typed ("__rdf_long_to_ttl", bif_rdf_long_to_ttl, &bt_any);
  bif_set_uses_index (bif_rdf_long_to_ttl);
  bif_define_typed ("__rq_iid_of_o", bif_rq_iid_of_o, &bt_any);
  bif_define_typed ("__rdf_dist_ser_long", bif_rdf_dist_ser_long, &bt_varchar);
  bif_define_typed ("__rdf_dist_deser_long", bif_rdf_dist_deser_long, &bt_any);
  bif_define_typed ("__rdf_redu_ser_long", bif_rdf_redu_ser_long, &bt_varchar);
  bif_define_typed ("__rdf_redu_deser_long", bif_rdf_dist_deser_long, &bt_any);

}
