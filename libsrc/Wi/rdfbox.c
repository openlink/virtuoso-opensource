/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2014 OpenLink Software
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

#include "sqlnode.h"
#include "sqlbif.h"
#include "arith.h"
#include "xmltree.h"
#include "rdf_core.h"
#include "http.h" /* For DKS_ESC_XXX constants */
#include "date.h" /* For DT_TYPE_DATE and the like */
#include "security.h" /* For sec_check_dba() */
#include "repl.h"	/* For repl_level_t in replsr.h */
#include "replsr.h"	/* For log_repl_text_array() */
#include "xslt_impl.h"	/* For vector_sort_t */
#include "aqueue.h"	/* For aq_allocate() in rdf replication */

caddr_t boxed_iid_of_virtrdf_ns_uri = NULL;
caddr_t boxed_iid_of_virtrdf_ns_uri_rdf_repl_all = NULL;
caddr_t boxed_iid_of_virtrdf_ns_uri_rdf_repl_graph_group = NULL;

iri_id_t iid_of_virtrdf_ns_uri = 0;
iri_id_t iid_of_virtrdf_ns_uri_rdf_repl_all = 0;
iri_id_t iid_of_virtrdf_ns_uri_rdf_repl_graph_group = 0;

void
rdf_fetch_or_create_system_iri_ids (caddr_t * qst)
{
#define RDF_FETCH_OR_CREATE_1(basename) \
  if (NULL == boxed_iid_of_##basename) \
    { \
      caddr_t err = NULL; \
      boxed_iid_of_##basename = iri_to_id (qst, uname_##basename, IRI_TO_ID_WITH_CREATE, &err); \
      if (NULL != err) \
        sqlr_resignal (err); \
      iid_of_##basename = unbox_iri_int64 (boxed_iid_of_##basename); \
    }
  RDF_FETCH_OR_CREATE_1(virtrdf_ns_uri)
  RDF_FETCH_OR_CREATE_1(virtrdf_ns_uri_rdf_repl_all)
  RDF_FETCH_OR_CREATE_1(virtrdf_ns_uri_rdf_repl_graph_group)
}

iri_id_t bnode_t_treshold = ~((iri_id_t)0);

caddr_t
bif_rdf_set_bnode_t_treshold (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  sec_check_dba ((query_instance_t *) qst, "__rdf_set_bnode_t_treshold");
    bnode_t_treshold = sequence_next ("RDF_URL_IID_BLANK", 0);
  return box_iri_id (bnode_t_treshold);
}

void
rb_complete_1 (rdf_box_t * rb, lock_trx_t * lt, void * /*actually query_instance_t * */ caller_qi_v, int is_local)
{
  static query_t *rdf_box_qry_complete_xml = NULL;
  static query_t *rdf_box_qry_complete_text = NULL;
  static query_t *rdf_box_qry_complete_xml_l;
  static query_t *rdf_box_qry_complete_text_l;
  query_instance_t *caller_qi = (query_instance_t *)caller_qi_v;
  caddr_t err;
  local_cursor_t *lc;
  dtp_t value_dtp = ((rb->rb_chksum_tail) ? (((rdf_bigbox_t *)rb)->rbb_box_dtp) : DV_TYPE_OF (rb->rb_box));
#ifdef DEBUG
  if (rb->rb_is_complete)
    GPF_T1("rb_" "complete(): redundant call");
#endif
  if (NULL == rdf_box_qry_complete_text)
    {
      rdf_box_qry_complete_xml_l = sql_compile_static ("select \
 xml_tree_doc (__xml_deserialize_packed (RO_LONG)), \
 16843009, \
 RO_VAL \
 from DB.DBA.RDF_OBJ table option (no cluster) where RO_ID = ?",
        bootstrap_cli, NULL, SQLC_DEFAULT );
      rdf_box_qry_complete_text_l = sql_compile_static ("select \
 case (isnull (RO_LONG)) \
   when 0 then case (bit_and (RO_FLAGS, 2)) when 2 then xml_tree_doc (__xml_deserialize_packed (RO_LONG)) else blob_to_string (RO_LONG) end \
   else RO_VAL end, \
 RO_DT_AND_LANG, \
 case (isnull (RO_LONG)) when 0 then RO_VAL else NULL end \
 from DB.DBA.RDF_OBJ table option (no cluster) where RO_ID = ? ",
        bootstrap_cli, NULL, SQLC_DEFAULT );
      rdf_box_qry_complete_xml = sql_compile_static ("select \
 xml_tree_doc (__xml_deserialize_packed (RO_LONG)), \
 16843009, \
 RO_VAL \
 from DB.DBA.RDF_OBJ where RO_ID = ?",
        bootstrap_cli, NULL, SQLC_DEFAULT );
      rdf_box_qry_complete_text = sql_compile_static ("select \
 case (isnull (RO_LONG)) \
   when 0 then case (bit_and (RO_FLAGS, 2)) when 2 then xml_tree_doc (__xml_deserialize_packed (RO_LONG)) else blob_to_string (RO_LONG) end \
   else RO_VAL end, \
 RO_DT_AND_LANG, \
 case (isnull (RO_LONG)) when 0 then RO_VAL else NULL end \
 from DB.DBA.RDF_OBJ where RO_ID = ?",
        bootstrap_cli, NULL, SQLC_DEFAULT );
    }
  err = qr_rec_exec (
		     is_local ? (DV_XML_ENTITY == value_dtp ? rdf_box_qry_complete_xml_l : rdf_box_qry_complete_text_l)
    : (DV_XML_ENTITY == value_dtp ? rdf_box_qry_complete_xml : rdf_box_qry_complete_text),
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
      uint32 dt_lang = unbox (lc_nth_col (lc, 1));
      rb->rb_lang = dt_lang & 0xffff;
      rb->rb_type = dt_lang >> 16;
      rb->rb_serialize_id_only = 0; /* may also serialize with value if for order by once it is filled */
      if (sizeof (rdf_bigbox_t) == box_length (rb))
        {
          caddr_t chksum = lc_nth_col (lc, 2);
          if (DV_STRING != DV_TYPE_OF (chksum))
            chksum = NULL;
          if (rb->rb_chksum_tail)
            {
              caddr_t cached_chksum = ((rdf_bigbox_t *)rb)->rbb_chksum;
              if ((DV_TYPE_OF (cached_chksum) != DV_TYPE_OF (chksum)) ||
                (box_length (cached_chksum) != box_length (chksum)) ||
                memcmp (cached_chksum, chksum, box_length (chksum)) )
                sqlr_new_error ("22023", "SR579", "RDF integrity issue: the checksum of value retrieved from DB.DBA.RDF_OBJ with RO_ID = " BOXINT_FMT " is not equal to checksum stored in RDF box",
                  (boxint)(rb->rb_ro_id) );
            }
          else if (NULL != chksum)
            {
              dk_check_tree (chksum);
              ((rdf_bigbox_t *)rb)->rbb_chksum = box_copy (chksum);
              ((rdf_bigbox_t *)rb)->rbb_box_dtp = DV_TYPE_OF (val);
              rb->rb_chksum_tail = 1;
            }
        }
      else
        GPF_T;
      if (rb->rb_chksum_tail && (DV_TYPE_OF (val) != ((rdf_bigbox_t *)rb)->rbb_box_dtp))
        sqlr_new_error ("22023", "SR579", "RDF integrity issue: the type %ld of value retrieved from DB.DBA.RDF_OBJ with RO_ID = " BOXINT_FMT " is not equal to preset type %ld of RDF box",
          (long)DV_TYPE_OF (val), (boxint)(rb->rb_ro_id), ((long)(((rdf_bigbox_t *)rb)->rbb_box_dtp)) );
      dk_free_tree (rb->rb_box);
      if (RDF_BOX_GEO == rb->rb_type)
	rb->rb_box = box_deserialize_string (val, box_length (val) - 1, 0);
      else
	rb->rb_box = box_copy_tree (val);
      if (DV_STRING == DV_TYPE_OF (rb->rb_box))
        box_flags (rb->rb_box) |= BF_UTF8;
      rb->rb_is_complete = 1;
      rb_dt_lang_check(rb);
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


void
rb_complete (rdf_box_t * rb, lock_trx_t * lt, void * /*actually query_instance_t * */ caller_qi_v)
{
  rb_complete_1 (rb, lt, caller_qi_v, 0);
}


#define RB_MAX_INLINED_CHARS 20

caddr_t
bif_rdf_box (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  /* data, type, lamg, ro_id, is_complete */
  rdf_box_t * rb;
  caddr_t box, bcopy, chksum = NULL;
  dtp_t box_dtp;
  long type, lang, ro_id, is_complete;
  box = bif_arg (qst, args, 0, "rdf_box");
  type = bif_long_arg (qst, args, 1, "rdf_box");
  lang = bif_long_arg (qst, args, 2, "rdf_box");
  ro_id = bif_long_arg (qst, args, 3, "rdf_box");
  is_complete = bif_long_arg (qst, args, 4, "rdf_box");
  if ((RDF_BOX_MIN_TYPE > type) || (type & ~0xffff) || (RDF_BOX_ILL_TYPE == type))
    sqlr_new_error ("22023", "SR547", "Invalid datatype id %ld as argument 2 of rdf_box()", type);
  if ((RDF_BOX_DEFAULT_LANG > lang) || (lang & ~0xffff) || (RDF_BOX_ILL_LANG == lang))
    sqlr_new_error ("22023", "SR548", "Invalid language id %ld as argument 3 of rdf_box()", lang);
  if ((RDF_BOX_DEFAULT_TYPE < type) && (RDF_BOX_DEFAULT_LANG != lang))
    sqlr_new_error ("22023", "SR549", "Both datatype id %ld and language id %ld are not default in call of rdf_box()", type, lang);
  if ((0 == ro_id) && !is_complete)
    sqlr_new_error ("22023", "SR550", "Neither is_complete nor ro_id argument is set in call of rdf_box()");
  box_dtp = DV_TYPE_OF (box);
  if (RDF_BOX_GEO_TYPE == type && DV_GEO != box_dtp && DV_LONG_INT != box_dtp)
    sqlr_new_error ("42000",  "RDFGE",  "rdf box with a geometry rdf type and a non geometry content");
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
    case DV_RDF:
      sqlr_new_error ("22023", "SR559", "RDF box (tag %d) is not a valid argument #1 in call of rdf_box()", box_dtp);
    case DV_IRI_ID:
      sqlr_new_error ("22023", "SR559", "IRI_ID box (tag %d) is not a valid argument #1 in call of rdf_box()", box_dtp);
    }
  if (type == RDF_BOX_GEO && box_dtp != DV_GEO)
    sqlr_new_error ("22023", "SR559", "The RDF box of type geometry needs a spatial object as a value, not a value of type %s (%d)", dv_type_title (box_dtp), box_dtp);
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
      rbb->rbb_base.rb_serialize_id_only = is_complete >> 1;
      rbb->rbb_base.rb_chksum_tail = 1;
      dk_check_tree (chksum);
      rbb->rbb_chksum = chksum; /* Not box_copy_tree (chksum) */
      if (6 < BOX_ELEMENTS (args))
        {
          long dtp = bif_long_arg (qst, args, 6, "rdf_box");
          if ((dtp &~0xFF) || ! (dtp & 0x80))
            {
              dk_free_box ((caddr_t *)rbb);
              sqlr_new_error ("22023", "SR556", "Invalid dtp %ld in call of rdf_box()", dtp);
            }
           rbb->rbb_box_dtp = (dtp_t)dtp;
        }
      else
        rbb->rbb_box_dtp = DV_TYPE_OF (box);
      rdf_bigbox_audit(rbb);
      return (caddr_t) rbb;
    }
  if (DV_STRING == DV_TYPE_OF (box))
    {
  if (is_complete && (0 == ro_id) && (RDF_BOX_DEFAULT_TYPE == type) && (RDF_BOX_DEFAULT_LANG == lang) &&
        ((RB_MAX_INLINED_CHARS+1) >= box_length_inline (box)) )
        {
          bcopy = box_copy (box);
          if (BF_IRI & box_flags(bcopy))
            box_flags(bcopy) = BF_UTF8;
          return bcopy;
        }
/* The following three rows are intentionally duplicated from above in order to get different location of memory leaks for two cases: a string lost after being returned "as is" and string lost in rb_box field */
      bcopy = box_copy (box); 
      if (BF_IRI & box_flags(bcopy))
        box_flags(bcopy) = BF_UTF8;
    }
  else
    bcopy = box_copy_tree (box);
  rb = rb_allocate ();
  rb->rb_box = bcopy;
  rb->rb_type = (short)type;
  rb->rb_lang = (short)lang;
  rb->rb_ro_id = ro_id;
  if (ro_id)
    rb->rb_is_outlined = 1;
  rb->rb_is_complete = is_complete;
  rb->rb_serialize_id_only = is_complete >> 1;
  rdf_box_audit(rb);
  return (caddr_t) rb;
}

caddr_t
bif_rdf_box_from_ro_id (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  boxint rb_id = bif_long_arg (qst, args, 0, "rdf_box_from_ro_id");
  if (0 >= rb_id)
    sqlr_new_error ("22023", "SR339", "Function rdf_box_from_ro_id needs an integer not less than 1 as argument");
  return (caddr_t)rbb_from_id (rb_id);
}

caddr_t
bif_ro_digest_from_parts (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  /* data, type, lamg, ro_id, is_complete */
  rdf_box_t * rb;
  caddr_t box, chksum = NULL;
  dtp_t box_dtp;
  long flags, dt_and_lang, type, lang, ro_id, is_complete;
  box = bif_arg (qst, args, 0, "ro_digest_from_parts");
  flags = bif_long_arg (qst, args, 1, "ro_digest_from_parts");
  dt_and_lang = bif_long_arg (qst, args, 2, "ro_digest_from_parts");
  ro_id = bif_long_arg (qst, args, 3, "ro_digest_from_parts");
  is_complete = bif_long_arg (qst, args, 4, "ro_digest_from_parts");
  type = dt_and_lang >> 16;
  lang = dt_and_lang & 0xffff;
  if ((RDF_BOX_DEFAULT_TYPE > type) || (type & ~0xffff))
    sqlr_new_error ("22023", "SR547", "Invalid datatype id %ld encoded in argument 3 of ro_digest_from_parts()", type);
  if ((RDF_BOX_DEFAULT_LANG > lang) || (lang & ~0xffff))
    sqlr_new_error ("22023", "SR548", "Invalid language id %ld encoded in argument 3 of ro_digest_from_parts()", lang);
  if ((RDF_BOX_DEFAULT_TYPE != type) && (RDF_BOX_DEFAULT_LANG != lang))
    sqlr_new_error ("22023", "SR549", "Both datatype id %ld and language id %ld are not default in call of ro_digest_from_parts()", type, lang);
  if ((0 == ro_id) && !is_complete)
    sqlr_new_error ("22023", "SR550", "Neither is_complete nor ro_id argument is set in call of ro_digest_from_parts()");
  box_dtp = DV_TYPE_OF (box);
  switch (box_dtp)
    {
    case DV_STRING:
      if (is_complete && (box_length (box) <= (RB_MAX_INLINED_CHARS+1)) && (RDF_BOX_DEFAULT_TYPE == type) && (RDF_BOX_DEFAULT_LANG == lang))
        return box_copy (box);
      break;
    case DV_DB_NULL:
      return NEW_DB_NULL;
    case DV_XML_ENTITY:
      if (!XE_IS_TREE (box))
        sqlr_new_error ("22023", "SR559", "Persistent XML is not a valid argument #1 in call of ro_digest_from_parts()");
      break;
    case DV_DICT_ITERATOR:
      sqlr_new_error ("22023", "SR559", "Dictionary is not a valid argument #1 in call of ro_digest_from_parts()");
    case DV_BLOB: case DV_BLOB_HANDLE: case DV_BLOB_BIN: case DV_BLOB_WIDE: case DV_BLOB_WIDE_HANDLE:
    case DV_BLOB_XPER: case DV_BLOB_XPER_HANDLE:
      sqlr_new_error ("22023", "SR559", "Large object (tag %d) is not a valid argument #1 in call of ro_digest_from_parts()", box_dtp);
    }
  if (flags & 2)
    {
      rdf_bigbox_t * rbb = rbb_allocate ();
      rbb->rbb_base.rb_box = NULL;
      rbb->rbb_base.rb_type = (short)type;
      rbb->rbb_base.rb_lang = (short)lang;
      rbb->rbb_base.rb_ro_id = ro_id;
      rbb->rbb_base.rb_is_outlined = 1;
      rbb->rbb_base.rb_is_complete = 0;
      rbb->rbb_base.rb_chksum_tail = 1;
      dk_check_tree (box);
      rbb->rbb_chksum = box_copy_tree (box);
      rbb->rbb_box_dtp = (dtp_t)DV_XML_ENTITY;
      rdf_bigbox_audit(rbb);
      return (caddr_t) rbb;
    }
  else if (NULL != chksum)
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
      dk_check_tree (chksum);
      rbb->rbb_chksum = box_copy_tree (chksum);
      if (flags & 2)
        rbb->rbb_box_dtp = (dtp_t)DV_XML_ENTITY;
      if (6 < BOX_ELEMENTS (args))
        {
          long dtp = bif_long_arg (qst, args, 6, "ro_digest_from_parts");
          if ((dtp &~0xFF) || ! (dtp & 0x80))
            sqlr_new_error ("22023", "SR556", "Invalid dtp %ld in call of ro_digest_from_parts()", dtp);
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
bif_rdf_box_dt_and_lang (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  rdf_box_t *rb = (rdf_box_t *)bif_arg (qst, args, 0, "rdf_box_lang");
  if (DV_RDF == DV_TYPE_OF (rb))
    {
      rdf_box_audit (rb);
      return box_num ((rb->rb_type << 16) | rb->rb_lang);
    }
  return box_num ((RDF_BOX_DEFAULT_TYPE << 16) | RDF_BOX_DEFAULT_LANG);
}


caddr_t
bif_rdf_box_set_type (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  rdf_box_t *rb = bif_rdf_box_arg (qst, args, 0, "rdf_box_set_type");
  long type = bif_long_arg (qst, args, 1, "rdf_box_set_type");
  if ((RDF_BOX_MIN_TYPE > type) || (type & ~0xffff) || (RDF_BOX_ILL_TYPE == type))
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
  dk_check_tree (rbb->rbb_chksum);
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

caddr_t
bif_rdf_box_is_text (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  rdf_box_t *rb = (rdf_box_t *)bif_arg (qst, args, 0, "rdf_box_is_complete");
  if (DV_RDF == DV_TYPE_OF (rb))
    {
      rdf_box_audit (rb);
      return box_num (rb->rb_is_text_index);
    }
  return box_num (1);
}


caddr_t
bif_rdf_box_set_is_text (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t rb = bif_arg (qst, args, 0, "rdf_box_set_is_text");
  int f = bif_long_arg (qst, args, 1, "rdf_box_set_is_text");
  if (DV_RDF == DV_TYPE_OF (rb))
    {
      rdf_box_t * rb2 = (rdf_box_t *) rb;
      rb2->rb_is_text_index = (f & 0x1);
      rb2->rb_serialize_id_only = f >> 1;
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
      if (!rb->rb_is_complete)
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
              return (caddr_t)((ptrlong)3);
/* This is no longer needed because in Vajra we don't ft-index all typed strings, but only some
            rb_dt_lang_check(rb2);
            if ((RDF_BOX_DEFAULT_TYPE != rb2->rb_type) || (RDF_BOX_DEFAULT_LANG != rb2->rb_lang))
              return box_num (3);
*/
	    if (rdf_no_string_inline)
	      return (caddr_t)((ptrlong)1);
            return (caddr_t)((ptrlong)(((RB_MAX_INLINED_CHARS + 1) >= box_length (rb2->rb_box)) ? 0 : 1));
          }
        return (caddr_t)((ptrlong)0);
      }
    case DV_STRING: case DV_UNAME:
      if (DV_DB_NULL != dict_dtp)
        return (caddr_t)((ptrlong)7);
      if (rdf_no_string_inline)
	return (caddr_t)((ptrlong)1);
      return (caddr_t)((ptrlong)(((RB_MAX_INLINED_CHARS + 1) >= box_length (rb)) ? 0 : 1));
    case DV_XML_ENTITY:
        return (caddr_t)((ptrlong)7);
    default:
      return (caddr_t)((ptrlong)0);
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
bif_rdf_box_migrate_after_06_02_3129 (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  rdf_box_t *rb = (rdf_box_t *)bif_arg (qst, args, 0, "rdf_box_migrate_after_06_02_3129");
  switch (DV_TYPE_OF (rb))
    {
    case DV_XML_ENTITY: case DV_GEO: return (caddr_t)((ptrlong)1);
    case DV_RDF: break;
    default: return (caddr_t)((ptrlong)0);
    }
  switch (DV_TYPE_OF (rb->rb_box))
    {
    case DV_XML_ENTITY: case DV_GEO: return (caddr_t)((ptrlong)1);
    default: break;
    }
  if (rb->rb_chksum_tail)
    {
      switch (((rdf_bigbox_t *)(rb))->rbb_box_dtp)
        {
        case DV_XML_ENTITY: case DV_GEO: return (caddr_t)((ptrlong)1);
        default: return (caddr_t)((ptrlong)0);
        }
    }
  return (caddr_t)((ptrlong)0);
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
bif_ro_digest_id (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  rdf_box_t *rb = (rdf_box_t *)bif_arg (qst, args, 0, "rdf_box_ro_id");
  if (DV_RDF == DV_TYPE_OF (rb))
    {
      rdf_box_audit (rb);
      return box_num (rb->rb_ro_id);
    }
  return dk_alloc_box (0, DV_DB_NULL);
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
#define RBS_SKIP_DTP	0x40


int
rbs_length (db_buf_t rbs)
{
  long hl, l;
  dtp_t flags = rbs[1];
  if (RBS_EXT_TYPE & flags)
    {
      int len = (RBS_64 & flags ? 10 : 6);
      if (! RBS_ID_ONLY (flags))
	len += 2;
      if (RBS_COMPLETE & flags)
	{
	  db_buf_length (rbs + len, &hl, &l);
	  len += hl + l;
	}
      return len;
    }
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


int64
rbs_ro_id (db_buf_t rbs)
{
  long hl, l;
  dtp_t flags = rbs[1];
  if (RBS_EXT_TYPE & flags)
    {
      l = 2;
      if (RBS_HAS_TYPE & flags)
	l += 2;
      hl = 0;
      goto ret_id;
    }
  else if (flags & RBS_SKIP_DTP)
    {
      hl = 1;
      l = rbs[2];
    }
  else
    db_buf_length (rbs + 2, &hl, &l);
  l += 2;
  if (flags & RBS_OUTLINED)
    {
      l += hl;
      ret_id:
      if (flags & RBS_64)
	return INT64_REF_NA (rbs + l);
      else
	return LONG_REF_NA (rbs + l);
    }
  return 0;
}


void
rbs_hash_range (dtp_t ** buf, int * len, int * is_string)
{
  /* the partition hash of a any type col with an rdf box value does not depend on all bytes but only the value serialization, not the flags and ro ids */
  long l, hl;
  dtp_t * rbs = *buf;
  dtp_t flags = rbs[1];
  if (RBS_EXT_TYPE & flags)
    GPF_T1 ("rbs ahsh range not for geo or serialize id only boxes");
  if (RBS_SKIP_DTP & rbs[1])
    {
      *buf += 1 == wi_inst.wi_master->dbs_stripe_unit ? 2 : 3;
      *is_string = 1;
      *len = rbs[2];
      return;
    }
  *is_string = DV_SHORT_STRING_SERIAL == rbs[2];
  db_buf_length ((*buf) + 2, &hl, &l);
  (*buf) += hl;
  *len = l;
}


void
print_short (short s, dk_session_t * ses)
{
  session_buffered_write_char (s >> 8, ses);
  session_buffered_write_char (s & 0xff, ses);
}


void
rb_id_serialize (rdf_box_t * rb, dk_session_t * ses)
{
  if (rb->rb_ro_id > INT32_MAX || rb->rb_ro_id < INT32_MIN)
    {
      session_buffered_write_char (DV_RDF_ID_8, ses);
      print_int64_no_tag (rb->rb_ro_id, ses);
    }
  else
    {
      session_buffered_write_char (DV_RDF_ID, ses);
      print_long (rb->rb_ro_id, ses);
    }
}


void
rb_ext_serialize (rdf_box_t * rb, dk_session_t * ses)
{
  /* non string special rdf boxes like geometry or interval or udt.  id is last  */
  int with_content = DKS_DB_DATA (ses) != NULL || DKS_CL_DATA (ses) != NULL
    || ((DKS_TO_CLUSTER | DKS_TO_OBY_KEY) & ses->dks_cluster_flags);
  dtp_t flags = RBS_EXT_TYPE;
  rb_dt_lang_check(rb);
  session_buffered_write_char (DV_RDF, ses);
  if (with_content && rb->rb_is_complete)
    flags |= RBS_COMPLETE;
  if (rb->rb_ro_id > INT32_MAX)
    flags |= RBS_64;
  if (rb->rb_serialize_id_only)
    flags |= RBS_HAS_LANG | RBS_HAS_TYPE;
  session_buffered_write_char (flags, ses);
  if (!(RBS_HAS_TYPE & flags && RBS_HAS_LANG & flags))
    print_short (rb->rb_type, ses);
  if (rb->rb_ro_id > INT32_MAX)
    print_int64_no_tag (rb->rb_ro_id, ses);
  else
    print_long (rb->rb_ro_id, ses);
  if (flags & RBS_COMPLETE)
    print_object (rb->rb_box, ses, NULL, NULL);
}


int rdf_no_string_inline = 0;


int
rb_serial_length (caddr_t x)
{
  /* dv_rdf, flags, data, ro_id, lang or type, opt chksum, opt dtp
   * flags is or of 1. outlined 2. complete 4 has lang 8 has type 0x10 chksum+dtp 0x20 if id 8 bytes */
  rdf_box_t * rb = (rdf_box_t *) x;
  int len = 1;
  rdf_box_audit (rb);
  if (!rb->rb_box && rb->rb_ro_id)
    return  (INT32_MIN > rb->rb_ro_id || INT32_MAX < rb->rb_ro_id) ? 9 : 5;

  if (rb->rb_type != RDF_BOX_DEFAULT_TYPE || RDF_BOX_DEFAULT_LANG != rb->rb_lang)
    len += 2;
  if (DV_STRINGP (rb->rb_box) && box_length (rb->rb_box) - 1 < RB_MAX_INLINED_CHARS)
    len += box_length (rb->rb_box);
  else if (DV_STRINGP (rb->rb_box))
    len += RB_MAX_INLINED_CHARS;
  else
    len += box_serial_length (rb->rb_box, 0);
  if (rb->rb_ro_id)
    len += (INT32_MIN > rb->rb_ro_id || INT32_MAX < rb->rb_ro_id)  ? 8 : 4;
  if (rb->rb_chksum_tail)
    len += 1;
  return len;
}


void
rb_serialize (caddr_t x, dk_session_t * ses)
{
  /* dv_rdf, flags, data, ro_id, lang or type, opt chksum, opt dtp
   * flags is or of 1. outlined 2. complete 4 has lang 8 has type 0x10 chksum+dtp 0x20 if id 8 bytes */
  client_connection_t *cli = DKS_DB_DATA (ses);
  int with_content = DKS_DB_DATA (ses) != NULL || DKS_CL_DATA (ses) != NULL
    || ((DKS_TO_CLUSTER | DKS_TO_OBY_KEY | DKS_REPLICATION) & ses->dks_cluster_flags);
  int repl = (DKS_REPLICATION & ses->dks_cluster_flags);
  rdf_box_t * rb = (rdf_box_t *) x;
  rdf_box_audit (rb);
  if ((RDF_BOX_DEFAULT_TYPE < rb->rb_type) && (RDF_BOX_DEFAULT_LANG != rb->rb_lang))
    sr_report_future_error (ses, "", "Both datatype id %d and language id %d are not default in DV_RDF value, can't serialize");
  if  ((rdf_no_string_inline || rb->rb_serialize_id_only)
    && rb->rb_ro_id && !with_content)
    {
      rb_id_serialize (rb, ses);
      return;
    }
  if (rb->rb_type < RDF_BOX_DEFAULT_TYPE)
    {
      /* geo boxes and strings if string inlining is off */
      rb_ext_serialize (rb, ses);
      return;
    }
  if  (!unbox_inline (rb->rb_box))
    {
      if (!rb->rb_is_complete)
    {
      rb_id_serialize (rb, ses);
      return;
    }
    }
      if (!(rb->rb_is_complete) && !(rb->rb_ro_id))
    sr_report_future_error (ses, "", "Zero ro_id in incomplete DV_RDF value, can't serialize");
  if (NULL != cli && cli->cli_version < 3031)
    print_object (rb->rb_box, ses, NULL, NULL);
  else
    {
      int flags = 0;
      rb_dt_lang_check(rb);
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
      if (rb->rb_is_complete && (cli || !(rb->rb_ro_id) || repl))
        {
	  flags |= RBS_COMPLETE;
          flags &= ~RBS_CHKSUM;
          session_buffered_write_char (flags, ses);
          if (DV_XML_ENTITY == DV_TYPE_OF (rb->rb_box))
            xe_serialize ((xml_entity_t *)(rb->rb_box), ses);
          else if (!rb->rb_box)
	    print_int (0, ses);  /* a zero int with should be printed with int tag for partitioning etc */
	  else
	    print_object (rb->rb_box, ses, NULL, NULL);
          if (rb->rb_ro_id)
            {
              if (rb->rb_ro_id > INT32_MAX)
                print_int64_no_tag (repl ? 0 : rb->rb_ro_id, ses);
              else
                print_long (repl ? 0 : rb->rb_ro_id, ses);
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
          int str_len;
          dk_check_tree (str);
          str_len = box_length (str) - 1;
	  if (str_len > RB_MAX_INLINED_CHARS)
	    str_len = RB_MAX_INLINED_CHARS;
#ifdef OLD_RDF_BOX_SERIALIZATION
          session_buffered_write_char (flags, ses);
	  session_buffered_write_char (DV_SHORT_STRING_SERIAL, ses);
#else
          flags |= RBS_SKIP_DTP;
          session_buffered_write_char (flags, ses);
#endif
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
	  if (str_len > RB_MAX_INLINED_CHARS)
	    str_len = RB_MAX_INLINED_CHARS;
#ifdef OLD_RDF_BOX_SERIALIZATION
          session_buffered_write_char (flags, ses);
	  session_buffered_write_char (DV_SHORT_STRING_SERIAL, ses);
#else
          flags |= RBS_SKIP_DTP;
          session_buffered_write_char (flags, ses);
#endif
	  session_buffered_write_char (str_len, ses);
	  session_buffered_write (ses, str, str_len);
	}
      else
        {
          if (rb->rb_is_complete)
	    flags |= RBS_COMPLETE;
          session_buffered_write_char (flags, ses);
	  if (!rb->rb_box)
	    print_int (0, ses);  /* a zero int with should be printed with int tag for partitioning etc */
	  else
	    print_object (rb->rb_box, ses, NULL, NULL);
        }
      if (rb->rb_ro_id)
	{
	  if (rb->rb_ro_id > INT32_MAX)
	    print_int64_no_tag (repl ? 0 : rb->rb_ro_id, ses);
	  else
	    print_long (repl ? 0 : rb->rb_ro_id, ses);
	}
      if (RDF_BOX_DEFAULT_TYPE != rb->rb_type)
	print_short (rb->rb_type, ses);
      if (RDF_BOX_DEFAULT_LANG != rb->rb_lang)
	print_short (rb->rb_lang, ses);
      if (rb->rb_chksum_tail)
        session_buffered_write_char (((rdf_bigbox_t *)rb)->rbb_box_dtp, ses);
    }
}


db_buf_t
mp_dv_rdf_to_db_serial (mem_pool_t * mp, db_buf_t  dv)
{
  dtp_t flags = dv[1];
  db_buf_t ptr = dv + 2;
  int len = 0;
  db_buf_t cp;
  if (!(RBS_OUTLINED & flags))
    {
      int len = rbs_length  (dv);
      cp = (db_buf_t)mp_alloc_box (mp, len + 1, DV_STRING);
      memcpy_16 (cp, dv, len);
      cp[len] = 0;
      return cp;
    }
  if (flags & RBS_EXT_TYPE)
    {
      if (flags & RBS_HAS_TYPE)
	len += 2;
      len += (RBS_64 & flags) ? 8 : 4;
      cp = (db_buf_t) mp_alloc_box (mp, len + 4, DV_STRING);
      memcpy (cp, dv, len + 2);
      cp[1] &= ~RBS_COMPLETE;
      cp[len + 3] = 0;
      return cp;
    }
  if (RBS_SKIP_DTP & flags)
    {
      len = *ptr++;
      ptr += len;
    }
  else
    {
      DB_BUF_TLEN (len, *ptr, ptr);
      ptr += len;
    }
  if (flags & RBS_64)
    {
      cp = (db_buf_t) mp_alloc_box (mp, 10, DV_STRING);
      cp[0] = DV_RDF_ID_8;
      memcpy (cp + 1, ptr, 8);
      cp[9] = 0;
    }
  else
    {
      cp = (db_buf_t) mp_alloc_box (mp, 6, DV_STRING);
      cp[0] = DV_RDF_ID;
      memcpy (cp + 1, ptr, 4);
      cp[5] = 0;
    }
  return cp;
}


void
dc_append_dv_rdf_any (data_col_t * dc, db_buf_t  dv)
{
  dtp_t flags = dv[1];
  db_buf_t ptr = dv + 2;
  int len = 0;
  db_buf_t cp;
  AUTO_POOL (100);
  if (!(RBS_OUTLINED & flags))
    {
      int len = rbs_length  (dv);
      cp = (db_buf_t)dk_alloc_box (len + 1, DV_STRING);
      memcpy_16 (cp, dv, len);
      cp[len] = 0;
      dc_append_bytes (dc, cp, len, NULL, 0);
      dk_free_box (cp);
    }
  if (flags & RBS_EXT_TYPE)
    {
      if (flags & RBS_HAS_TYPE)
	len += 2;
      len += (RBS_64 & flags) ? 8 : 4;
      cp = dk_alloc_box (len + 4, DV_STRING);
      memcpy (cp, dv, len + 2);
      cp[1] &= ~RBS_COMPLETE;
      cp[len + 3] = 0;
      dc_append_bytes (dc, cp, len - 1, NULL, 0);
      dk_free_box (cp);
      return;
    }
  if (RBS_SKIP_DTP & flags)
    {
      len = *ptr++;
      ptr += len;
    }
  else
    {
      DB_BUF_TLEN (len, *ptr, ptr);
      ptr += len;
    }
  if (flags & RBS_64)
    {
      cp = (db_buf_t) ap_alloc_box (&ap, 10, DV_STRING);
      cp[0] = DV_RDF_ID_8;
      memcpy (cp + 1, ptr, 8);
      cp[9] = 0;
    }
  else
    {
      cp = (db_buf_t) ap_alloc_box (&ap, 6, DV_STRING);
      cp[0] = DV_RDF_ID;
      memcpy (cp + 1, ptr, 4);
      cp[5] = 0;
    }
  dc_append_bytes (dc, cp, len - 1, NULL, 0);
  return;
}


void
dc_append_dv_rdf_box (data_col_t * dc, caddr_t box)
{
  QNCAST (rdf_box_t, rb, box);
  rdf_box_audit (rb);
  if (rb->rb_ro_id)
    {
      dtp_t temp[10];
      int l;
      if (rb->rb_ro_id > INT32_MAX || rb->rb_ro_id < INT32_MIN)
	{
	  temp[0] = DV_RDF_ID_8;
	  INT64_SET_NA (&temp[1], rb->rb_ro_id);
	  l = 9;
	}
      else
	{
	  temp[0] = DV_RDF_ID;
	  LONG_SET_NA (&temp[1], rb->rb_ro_id);
	  l = 5;
	}
      dc_append_bytes (dc, temp, l, NULL, 0);
    }
  else
    dc_append_box (dc, box);
}


int64
dv_rdf_ro_id (db_buf_t dv2)
{
  dtp_t flags;
  int64  ro_id;
  int len;
  flags = dv2[1];
  if (!(RBS_OUTLINED & flags)
      || (RBS_EXT_TYPE & flags))
    return -1;
  if (RBS_SKIP_DTP & flags)
    len = dv2[2] + 1;
  else
    {
      DB_BUF_TLEN (len, dv2[2], (dv2 + 2))
	}
  if (RBS_64 & flags)
    ro_id = INT64_REF_NA (dv2 + len + 2);
  else
    ro_id = LONG_REF_NA (dv2 + len + 2);
  return ro_id;
}


int
dv_rdf_dc_compare (db_buf_t dv1, db_buf_t dv2)
{
  int64 i1 = dv_rdf_ro_id (dv1);
  int64 i2 = dv_rdf_ro_id (dv2);
  if (i1 < i2)
    return DVC_LESS;
  if (i1 > i2)
    return DVC_GREATER;
  if (-1 == i1)
    return dv_rdf_compare (dv1, dv2);
  return DVC_MATCH;
}


#define CLEAR_LOW_32 0xffffffff00000000

int
dv_rdf_id_delta (int64 ro_id_1, int64 ro_id_2, int64 *delta_ret)
{
  int64 h1 = ro_id_1 & CLEAR_LOW_32;
  int64 h2 = ro_id_2 & CLEAR_LOW_32;
  if (h1 < h2)
    return DVC_DTP_LESS;
  if (h1 > h2)
    return DVC_GREATER;
  *delta_ret = ro_id_2 - ro_id_1;
  if (ro_id_1 == ro_id_2)
    return DVC_MATCH;
  if (*delta_ret < 0)
    return DVC_GREATER;
  if (*delta_ret > CE_INT_DELTA_MAX)
    return DVC_DTP_LESS;
  return DVC_LESS;
}


int
dv_rdf_id_compare (db_buf_t dv1, db_buf_t dv2, int64 offset, int64 * delta_ret)
{
  /* sometimes a cmp of a stored rdf id with a complete box.  Is equal if box is not ext type and ids match, else rdf id is dtp gt */
  dtp_t flags;
  int64  ro_id_2, ro_id_1;
  int len;
  if (DV_RDF != *dv2)
    return -1; /* general case is valid */
  flags = dv2[1];
  if (!(RBS_OUTLINED & flags)
      || (RBS_EXT_TYPE & flags))
    return DVC_DTP_GREATER;
  if (RBS_SKIP_DTP & flags)
    len = dv2[2] + 1;
  else
    {
      DB_BUF_TLEN (len, dv2[2], (dv2 + 2))
	}
  if (RBS_64 & flags)
    ro_id_2 = INT64_REF_NA (dv2 + len + 2);
  else
    ro_id_2 = LONG_REF_NA (dv2 + len + 2);
  if (DV_RDF_ID == *dv1)
    ro_id_1 = LONG_REF_NA (dv1 + 1);
  else
    ro_id_1 = INT64_REF_NA (dv1 + 1);
  ro_id_1 += offset;
  if (delta_ret)
    {
      return dv_rdf_id_delta (ro_id_1, ro_id_2, delta_ret);
    }
  return NUM_COMPARE (ro_id_1, ro_id_2);
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

#define DVC_DTP_CMP(d1, d2) (d1 < d2 ? DVC_DTP_LESS : DVC_DTP_GREATER)

int
dv_rdf_ext_compare (db_buf_t dv1, db_buf_t dv2)
{
  /* rdf ext boxes like geometries, intervals or udts collate by type and ro id, values are not compared. Always gt than any scalar (non ext)  rdf type.
  * both lang and type bits set means that there is no lang or type here and that collation is by id only.  These are less than typed ext and gt non-ext rdf dvs */
  unsigned short type1;
  unsigned short type2;
  int64 id1, id2;
  dtp_t flags1 = dv1[1], flags2;
  dtp_t dtp2 = *dv2;
  if (DV_RDF != dtp2)
    return DVC_DTP_CMP(DV_RDF, dtp2);
  flags2 = dv2[1];
  if (!(RBS_EXT_TYPE & flags2))
    return DVC_DTP_GREATER;
  if (RBS_ID_ONLY (flags1) && RBS_ID_ONLY (flags2))
    {
      id1 = (RBS_64 & flags1) ? INT64_REF_NA (dv1 + 2) : LONG_REF_NA (dv1 + 2);
      id2 = (RBS_64 & flags2) ? INT64_REF_NA (dv2 + 2) : LONG_REF_NA (dv2 + 2);
      return NUM_COMPARE (id1, id2);
    }
  if (RBS_ID_ONLY (flags1))
    return DVC_DTP_LESS;
  if (RBS_ID_ONLY (flags2))
    return DVC_DTP_GREATER;
  type1 = SHORT_REF_NA (dv1 + 2);
  type2 = SHORT_REF_NA (dv2 + 2);
  if (type1 < type2)
    return DVC_DTP_LESS;
  if (type1 > type2)
    return DVC_DTP_GREATER;
  id1 = (RBS_64 & flags1) ? INT64_REF_NA (dv1 + 4) : LONG_REF_NA (dv1 + 4);
  id2 = (RBS_64 & flags2) ? INT64_REF_NA (dv2 + 4) : LONG_REF_NA (dv2 + 4);
  return NUM_COMPARE (id1, id2);
}


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
  if (RBS_EXT_TYPE & flags1)
    return dv_rdf_ext_compare (dv1, dv2);
  if (dtp_canonical[dtp2] > DV_RDF) /* dtp_canonical because dv int64 is gt dv rdf but here it counts for dv long int */
    return DVC_DTP_LESS;
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
          return dv_compare (data1, dv2, NULL, 0);
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
              return dv_compare (dv1, data2, NULL, 0);
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
In version 6 (Vajra), complete boxes are equal even if ro_id differ (say, one of ids is zero. ids are compared only if both boxes are incomplete. */
          return DVC_MATCH;
        }
      else if (cmp_len < RB_MAX_INLINED_CHARS)
        {
          if ((len1 == cmp_len) && (len2 > cmp_len))
            return DVC_LESS;
          if ((len2 == cmp_len) && (len1 > cmp_len))
            return DVC_GREATER;
        }
/* Before version 6 (Vajra), the following two elseifs were omitted: */
      else if (RBS_COMPLETE & flags2)
        return DVC_GREATER;
      else if (RBS_COMPLETE & flags1)
        return DVC_LESS;
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


#define RB_ID_ONLY(rb) \
  (DV_RDF == DV_TYPE_OF (rb) && !(rb)->rb_box && !(rb)->rb_is_complete)

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
  if (RB_ID_ONLY (rb1) && DV_RDF != dtp2)
    return DVC_GREATER;
  if (RB_ID_ONLY (rb1) && RB_ID_ONLY (rb2))
    return rb1->rb_ro_id < rb2->rb_ro_id ? DVC_LESS : DVC_GREATER;
  if (RB_ID_ONLY (rb2))
    return DVC_LESS;
  if (RB_ID_ONLY (rb1))
    return DVC_GREATER;
  data1 = rb1->rb_box;
  data_dtp1 = DV_TYPE_OF (data1);
  /* if string and non-string */
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
  rb_dt_lang_check(rb1);
  rb_dt_lang_check(rb2);
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
  if (0 != rb->rb_ro_id)
    return rb->rb_ro_id + (rb->rb_ro_id << 16);
  if (rb->rb_is_complete && rb->rb_type >= RDF_BOX_DEFAULT_TYPE)
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

int
rdf_box_hash_strong_cmp (ccaddr_t b1, ccaddr_t b2)
    {
  rdf_box_t * rb1 = (rdf_box_t *) b1;
  rdf_box_t * rb2 = (rdf_box_t *) b2;
  dtp_t data1_dtp, data2_dtp;
  caddr_t data1, data2;
      if ((0 != rb1->rb_ro_id) && (0 != rb2->rb_ro_id))
    {
      if (rb2->rb_ro_id == rb1->rb_ro_id)
        return 1;
        return 0;
    }
  if ((!rb1->rb_is_complete && rb1->rb_ro_id) || (!rb2->rb_is_complete && rb2->rb_ro_id))
    return 0;
  if (rb1->rb_lang != rb2->rb_lang)
    return 0;
  if (rb1->rb_type != rb2->rb_type)
    return 0;
  data1 = rb1->rb_box;
  data1_dtp = DV_TYPE_OF (data1);
  data2 = rb2->rb_box;
  data2_dtp = DV_TYPE_OF (data2);
  if (data1_dtp != data2_dtp)
    return 0;
  if (DV_XML_ENTITY == data1_dtp)
    {
      if (!rb1->rb_chksum_tail || !rb2->rb_chksum_tail)
  return 0;
      if (((rdf_bigbox_t *)rb1)->rbb_chksum ==
        ((rdf_bigbox_t *)rb2)->rbb_chksum )
        return 1;
      return 0;
    }
  return box_strong_equal (data1, data2);
}


void
rb_cast_to_xpath_safe (query_instance_t *qi, caddr_t new_val, caddr_t *retval_ptr)
{
  switch (DV_TYPE_OF (new_val))
    {
    case DV_DB_NULL:
      new_val = NULL;
      goto xb_set_new_val; /* see below */
    case DV_IRI_ID:
      dk_free_tree (retval_ptr[0]);
      retval_ptr[0] = NULL;
      retval_ptr[0] = key_id_to_iri (qi, ((iri_id_t*)new_val)[0]);
      return;
    case DV_RDF:
      {
        rdf_box_t *rb = (rdf_box_t *)new_val;
        rb_dt_lang_check(rb);
        if (!rb->rb_is_complete)
          rb_complete (rb, qi->qi_trx, qi);
/*
        if ((RDF_BOX_DEFAULT_TYPE == rb->rb_type) && (RDF_BOX_DEFAULT_LANG == rb->rb_lang))
          new_val = rb->rb_box;
*/
        break;
      }
    default:
      if (NULL == new_val)
        {
          if ((DV_LONG_INT != DV_TYPE_OF (retval_ptr[0])) || (0 != unbox (retval_ptr[0])) || (NULL == retval_ptr[0]))
            {
              dk_free_tree (retval_ptr[0]);
              retval_ptr[0] = box_num_nonull (0);
              return;
            }
        }
    }
xb_set_new_val:
   if (new_val != retval_ptr[0])
     {
       dk_free_tree (retval_ptr[0]);
       retval_ptr[0] = box_copy_tree (new_val);
     }
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
bif_rdf_box_to_ro_id_search_fields (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t box = bif_arg (qst, args, 0, "__rdf_box_to_ro_id_search_fields");
  caddr_t ro_val = NULL;
  int ro_dt_and_lang = ((RDF_BOX_DEFAULT_TYPE << 16) | RDF_BOX_DEFAULT_LANG);
  int len;
  dtp_t dtp = DV_TYPE_OF (box);
  if (DV_RDF == dtp)
    {
      rdf_box_t * rb = (rdf_box_t *)box;
      caddr_t content = rb->rb_box;
      dtp_t cdtp = DV_TYPE_OF (content);
      ro_dt_and_lang = rb->rb_type << 16 | rb->rb_lang;
      if (rb->rb_ro_id)
        return NULL; /* No need to search */
      if (DV_XML_ENTITY == cdtp && rb->rb_chksum_tail)
        {
          QNCAST (rdf_bigbox_t, rbb, rb);
          ro_val = box_copy_tree (rbb->rbb_chksum);
          goto res; /* see below */
        }
      if (DV_STRING != cdtp)
        {
          ro_val = box_copy_tree (content);
          goto res; /* see below */
        }
      if (DV_GEO == cdtp)
        {
          caddr_t err = NULL;
          ro_val = box_to_any (content, &err);
          if (err)
            sqlr_resignal (err);
          goto res; /* see below */
        }
      len = box_length (content) - 1;
      if (len > RB_BOX_HASH_MIN_LEN)
        {
          ro_val = mdigest5 (content);
          goto res; /* see below */
        }
      ro_val = box_copy_tree (content);
      goto res; /* see below */
    }
  if (DV_GEO == dtp)
    sqlr_new_error ("22023", "CLGEO", "A geometry without rdf box is not allowed as object of quad");
  if (DV_STRING != dtp)
    return NULL;
  if (BF_IRI == box_flags (box))
    return NULL;
  len = box_length (box) - 1;
  if (len > RB_BOX_HASH_MIN_LEN)
    {
      ro_val = mdigest5 (box);
      goto res; /* see below */
    }
  ro_val = box_copy (box);
  goto res; /* see below */

res:
  qst_set (qst, args[1], ro_val);
  qst_set (qst, args[2], box_num (ro_dt_and_lang));
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
      caddr_t res;
      if ((DV_IRI_ID == so_dtp) || (DV_IRI_ID_8 == so_dtp))
        {
          caddr_t iri;
          iri_id_t iid = unbox_iri_id (shortobj);
	  if ((min_bnode_iri_id () <= iid) && (min_named_bnode_iri_id () > iid))
            iri = BNODE_IID_TO_LABEL(iid);
          else
            {
              iri = key_id_to_iri (qi, iid);
              if (NULL == iri)
                sqlr_new_error ("RDFXX", ".....", "IRI ID " IIDBOXINT_FMT " does not match any known IRI in __rdf_sqlval_of_obj()",
                  (boxint)iid );
            }
	  box_flags (iri) = BF_IRI;
          return iri;
        }
      res = box_copy_tree (shortobj);
      if ((DV_STRING == DV_TYPE_OF (res)) && !(box_flags (res) & BF_IRI))
        box_flags (res) |= BF_UTF8;
      return res;
    }
  rb = (rdf_box_t *)shortobj;
  if (!rb->rb_is_complete)
    rb_complete (rb, qi->qi_trx, qi);
  rb_dt_lang_check(rb);
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
  int set_bf_iri = ((1 < BOX_ELEMENTS (args)) ? bif_long_arg (qst, args, 1, "__rdf_strsqlval") : 0x1);
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
            res = BNODE_IID_TO_LABEL(iid);
          else
            {
              res = key_id_to_iri (qi, iid);
              if (NULL == res)
                sqlr_new_error ("RDFXX", ".....", "IRI ID " IIDBOXINT_FMT " does not match any known IRI in __rdf_strsqlval_of_obj()",
                  (boxint)iid );
            }
          box_flags (res) = (set_bf_iri ? BF_IRI : BF_UTF8);
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
        if ((set_bf_iri && (box_flags (res) & BF_IRI)) || (set_bf_iri & 0x2))
          box_flags(res) = BF_IRI;
        else
          box_flags(res) = BF_UTF8;
        return res;
      case DV_UNAME:
        res = box_dv_short_nchars (val, box_length (val)-1);
        box_flags (res) = (set_bf_iri ? BF_IRI : BF_UTF8);
        return res;
      case DV_DB_NULL:
        return NEW_DB_NULL;
      default:
        res = box_cast_to_UTF8_xsd (qst, val);
        box_flags (res) = ((set_bf_iri & 0x2) ? BF_IRI : BF_UTF8);
        return res;
    }
}

caddr_t
bif_rdf_long_to_ttl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t val = bif_arg (qst, args, 0, "__rdf_long_to_ttl");
  dk_session_t *out = http_session_no_catch_arg (qst, args, 1, "__rdf_long_to_ttl");
  query_instance_t *qi = (query_instance_t *)qst;
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
    case DV_WIDE:
      dks_esc_write (out, val, box_length (val) - sizeof (wchar_t), CHARSET_UTF8, CHARSET_WIDE, DKS_ESC_TTL_DQ);
      break;
    default:
      {
        caddr_t tmp_utf8_box = box_cast_to_UTF8_xsd (qst, val);
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
      char buf[6 * sizeof (caddr_t) + BOX_AUTO_OVERHEAD];
      caddr_t *ser_vec;
      caddr_t ptmp;

      BOX_AUTO (ptmp, buf, ((rbb->rbb_base.rb_chksum_tail ? 6 : 5) * sizeof (caddr_t)), DV_ARRAY_OF_POINTER);
      ser_vec = (caddr_t *) ptmp;
      rb_dt_lang_check(&(rbb->rbb_base));
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
      res = print_object_to_new_string ((caddr_t) ser_vec, fun_name, err_ret, 0);

      if (subbox != rbb->rbb_base.rb_box)
	dk_free_box (subbox);

      BOX_DONE (ser_vec, buf);

      return res;
    }

  return print_object_to_new_string (val, fun_name, err_ret, 0);
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
  deser = box_deserialize_string (ser, 0, 0);
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
      rb_dt_lang_check(&(rbb->rbb_base));
      dk_free_tree (vec);
      return (caddr_t)rbb;
    }
  return deser;
}

/*! Description of IRI reference in Turtle and similar formats */
typedef struct ttl_iriref_s {
  caddr_t colname;	/*!< Name of column, used only for result sets, not for triples */
  caddr_t uri;		/*!< A complete source URI */
  caddr_t ns;		/*!< Namespace, if found in the URI, NULL for bnodes and unusual URIs */
  caddr_t prefix;	/*!< Namespace prefix, if \c ns is not NULL and found in dictionary */
  caddr_t loc;		/*!< Local part of URI, if namespace can be extracted */
  ptrlong is_bnode;	/*!< 0 or 1 flag whether \c URI us blank node URI */
  ptrlong is_iri;	/*!< 0 or 1 flag whether the rest of the structure is filled with URI data, functions that parse/print URI do not check it, it's for their callers only */
} ttl_iriref_t;

typedef struct ttl_iriref_items_s {
  ttl_iriref_t s, p, o, dt;
} ttl_iriref_items_t;

typedef struct nq_iriref_items_s {
  ttl_iriref_t s, p, o, dt, g;
} nq_iriref_items_t;

int
iri_cast_and_split_ttl_qname (query_instance_t *qi, caddr_t iri, caddr_t *ns_prefix_ret, caddr_t *local_ret, ptrlong *is_bnode_ret)
{
  is_bnode_ret[0] = 0;
  switch (DV_TYPE_OF (iri))
    {
    case DV_STRING: case DV_UNAME:
	  {
	    int iri_boxlen = box_length (iri);
	    /*                                     0123456789 */
	    if ((iri_boxlen > 9) && !memcmp (iri, "nodeID://", 9))
	      {
                ns_prefix_ret[0] = uname___empty;
		local_ret[0] = box_dv_short_nchars (iri + 9, iri_boxlen - 10);
		is_bnode_ret[0] = 1;
		return 1;
	      }
      iri_split_ttl_qname (iri, ns_prefix_ret, local_ret, 1);
      return 1;
	  }
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
                unsigned char c = (unsigned char) tail[-1];
                if (!isalnum(c) && ('_' != c) && ('-' != c) && !(c & 0x80))
                  break;
              }
            if (isdigit (tail[0]) || ('-' == tail[0]) || ((tail > local) && (NULL == strchr ("#/:?", tail[-1]))))
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


int
iri_cast_rdfxml_qname (query_instance_t *qi, caddr_t iri, caddr_t *uri_ret, ptrlong *is_bnode_ret)
{
  caddr_t old_uri_ret = uri_ret[0];
  is_bnode_ret[0] = 0;
  switch (DV_TYPE_OF (iri))
    {
    case DV_STRING: case DV_UNAME:
	  {
	    int iri_boxlen = box_length (iri);
	    /*                                     0123456789 */
	    if ((iri_boxlen > 9) && !memcmp (iri, "nodeID://", 9))
	      {
		uri_ret[0] = box_dv_short_nchars (iri + 9, iri_boxlen - 10);
		is_bnode_ret[0] = 1;
		break;
	      }
            if (uri_ret[0] != iri)
              {
                uri_ret[0] = box_dv_short_nchars (iri, iri_boxlen - 1);
	        dk_free_box (old_uri_ret);
              }
	    return 1;
	  }
    case DV_IRI_ID: case DV_IRI_ID_8:
      {
        iri_id_t iid = unbox_iri_id (iri);
        if (0L == iid)
          return 0;
        if (min_bnode_iri_id () <= iid)
          {
            if (min_named_bnode_iri_id () > iid)
              {
                uri_ret[0] = BNODE_IID_TO_TTL_LABEL_LOCAL (iid);
                is_bnode_ret[0] = 1;
		dk_free_box (old_uri_ret);
                return 1;
              }
            uri_ret[0] = key_id_to_iri (qi, iid);
            return 1;
          }
        uri_ret[0] = key_id_to_iri (qi, iid);
        return 1;
      }
    default: return 0;
    }
  dk_free_box (old_uri_ret);
  return 1;
}

int
iri_cast_nt_absname (query_instance_t *qi, caddr_t iri, caddr_t *iri_ret, ptrlong *is_bnode_ret)
{
  is_bnode_ret[0] = 0;
  switch (DV_TYPE_OF (iri))
    {
    case DV_STRING: case DV_UNAME:
      {
        int iri_boxlen = box_length (iri);
/*                                             0123456789 */
        if ((iri_boxlen > 9) && !memcmp (iri, "nodeID://", 9))
          {
            iri_ret[0] = box_dv_short_nchars (iri + (9-2), iri_boxlen - (9-2));
            iri_ret[0][0] = '_';
            iri_ret[0][1] = ':';
            is_bnode_ret[0] = 1;
            return 1;
          }
        iri_ret[0] = box_copy (iri);
        is_bnode_ret[0] = 0 /* Maybe this would be more accurate, but there are questions with named bnodes: ((('_' == iri[0]) && (':' == iri[1])) ? 1 : 0) */;
        return 1;
      }
    case DV_IRI_ID: case DV_IRI_ID_8:
      {
        iri_id_t iid = unbox_iri_id (iri);
        if (0L == iid)
          return 0;
        if (min_bnode_iri_id () <= iid)
          {
            if (min_named_bnode_iri_id () > iid)
              {
                iri_ret[0] = BNODE_IID_TO_TALIS_JSON_LABEL (iid);
                is_bnode_ret[0] = 1;
                return 1;
              }
            iri_ret[0] = key_id_to_iri (qi, iid);
            return 1;
          }
        iri_ret[0] = key_id_to_iri (qi, iid);
        is_bnode_ret[0] = 0;
        if (iri_ret[0])
          return 1;
        return 0;
      }
    }
  return 0;
}

caddr_t
bif_http_sys_find_best_sparql_accept (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  const char *szMe = "http_sys_find_best_sparql_accept";
  caddr_t accept_strg = bif_string_or_null_arg (qst, args, 0, szMe);
  static caddr_t *supp_rset = NULL;
  static caddr_t *supp_dict = NULL;
  state_slot_t *ret_val_ssl = NULL;
  int optimize_for_dict = 0;
  if (NULL == supp_rset)
    {
      int ctr;
      caddr_t *tmp;
/*INDENT-OFF*/
      tmp = (caddr_t *)list (29*2,
        "text/rdf+n3"				, "TTL"			, /*  0 */
        "text/rdf+ttl"				, "TTL"			, /*  1 */
        "text/rdf+turtle"			, "TTL"			, /*  2 */
        "text/turtle"				, "TTL"			, /*  3 */
        "text/n3"				, "TTL"			, /*  4 */
        "application/turtle"			, "TTL"			, /*  5 */
        "application/x-turtle"			, "TTL"			, /*  6 */
        "application/sparql-results+json"	, "JSON;RES"		, /*  7 */
        "application/json"			, "JSON"		, /*  8 */
        "application/soap+xml"			, "SOAP"		, /*  9 */
        "application/soap+xml;11"		, "SOAP"		, /* 10 */
        "application/sparql-results+xml"		, "XML"			, /* 11 */
        "text/html"				, "HTML"		, /* 12 */
        "application/vnd.ms-excel"		, "HTML"		, /* 13 */
        "application/javascript"		, "JS"			, /* 14 */
        "application/rdf+json"			, "JSON;TALIS"		, /* 15 */
        "application/x-rdf+json"			, "JSON;TALIS"		, /* 16 */
        "application/rdf+xml"			, "RDFXML"		, /* 17 */
        "application/atom+xml"			, "ATOM;XML"		, /* 18 */
        "application/odata+json"		, "JSON;ODATA"		, /* 19 */
        "text/rdf+nt"				, "NT"			, /* 20 */
        "text/plain"				, "NT"			, /* 21 */
        "text/cxml+qrcode"			, "CXML"		, /* 22 */
        "text/cxml"				, "CXML"		, /* 23 */
        "text/ntriples"				, "NT"			, /* 24 */
        "text/csv"				, "CSV"			, /* 25 */
        "text/tab-separated-values"		, "TSV"			, /* 26 */
        "application/x-nice-turtle"		, "NICE_TTL"		, /* 27 */
        "text/x-html-nice-turtle"		, "HTML;NICE_TTL"	/* 28 Increase count in this list() call when add more MIME types! */
        );
/*INDENT-ON*/
      for (ctr = BOX_ELEMENTS (tmp); ctr--; /* no step */)
        tmp[ctr] = box_dv_short_string (tmp[ctr]);
      supp_rset = tmp;
    }
  if (NULL == supp_dict)
    {
      int ctr;
      caddr_t *tmp;
/*INDENT-OFF*/
      tmp = (caddr_t *)list (39*2,
        "application/x-trig"			, "TRIG"		, /*  0 */
        "text/rdf+n3"				, "TTL"			, /*  1 */
        "text/rdf+ttl"				, "TTL"			, /*  2 */
        "text/rdf+turtle"			, "TTL"			, /*  3 */
        "text/turtle"				, "TTL"			, /*  4 */
        "text/n3"				, "TTL"			, /*  5 */
        "application/turtle"			, "TTL"			, /*  6 */
        "application/x-turtle"			, "TTL"			, /*  7 */
        "application/json"			, "JSON"		, /*  8 */
        "application/rdf+json"			, "JSON;TALIS"		, /*  9 */
        "application/x-rdf+json"			, "JSON;TALIS"		, /* 10 */
        "application/soap+xml"			, "SOAP"		, /* 11 */
        "application/soap+xml;11"		, "SOAP"		, /* 12 */
        "application/rdf+xml"			, "RDFXML"		, /* 13 */
        "text/rdf+nt"				, "NT"			, /* 14 */
        "application/xhtml+xml"			, "RDFA;XHTML"		, /* 15 */
        "text/plain"				, "NT"			, /* 16 */
        "application/sparql-results+json"	, "JSON;RES"		, /* 17 */
        "text/html"				, "HTML;MICRODATA"	, /* 18 */
        "application/vnd.ms-excel"		, "HTML"		, /* 19 */
        "application/javascript"		, "JS"			, /* 20 */
        "application/atom+xml"			, "ATOM;XML"		, /* 21 */
        "application/odata+json"		, "JSON;ODATA"		, /* 22 */
        "application/sparql-results+xml"		, "XML"			, /* 23 */
        "text/cxml+qrcode"			, "CXML;QRCODE"		, /* 24 */
        "text/cxml"				, "CXML"		, /* 25 */
        "text/x-html+ul"				, "HTML;UL"		, /* 26 */
        "text/x-html+tr"				, "HTML;TR"		, /* 27 */
        "text/md+html"				, "HTML;MICRODATA"	, /* 28 */
        "text/microdata+html"			, "HTML;MICRODATA"	, /* 29 */
        "application/microdata+json"		, "JSON;MICRODATA"	, /* 30 */
        "application/x-json+ld"			, "JSON;LD"		, /* 31 */
        "application/ld+json"			, "JSON;LD"		, /* 32 */
        "text/ntriples"				, "NT"			, /* 33 */
        "text/csv"				, "CSV"			, /* 34 */
        "text/tab-separated-values"		, "TSV"			, /* 35 */
        "application/x-nice-turtle"		, "NICE_TTL"		, /* 36 */
        "application/x-nice-microdata"		, "HTML;NICE_MICRODATA"	, /* 37  */
        "text/x-html-nice-turtle"		, "HTML;NICE_TTL"	/* 38 Increase count in this list() call when add more MIME types! */
        );
/*INDENT-ON*/
      for (ctr = BOX_ELEMENTS (tmp); ctr--; /* no step */)
        tmp[ctr] = box_dv_short_string (tmp[ctr]);
      supp_dict = tmp;
    }
  optimize_for_dict = bif_long_arg (qst, args, 1, szMe);
  if (BOX_ELEMENTS(args) > 2)
    {
      ret_val_ssl = args[2];
      if (SSL_CONSTANT == ret_val_ssl->ssl_type)
        ret_val_ssl = NULL;
    }
  return http_sys_find_best_accept_impl (qst, ret_val_ssl, accept_strg, optimize_for_dict ? supp_dict : supp_rset, szMe);
}

#define TTL_ENV_ONLY_PREDEFINED_PREFIXES	0x001
#define TTL_ENV_HTML_OUTPUT			0x100

/*! Environment of TTL serializer */
typedef struct ttl_env_s {
  id_hash_iterator_t *te_used_prefixes;	/*!< Item 0 is the dictionary of used namespace prefixes */
  caddr_t te_prev_subj_ns;		/*!< Item 1 is the namespace part of previous subject. It is DV_STRING except the very beginning of the serialization when it can be of any type except DV_STRING (non-string will be freed and replaced with NULL pointer inside the printing procedure) */
  caddr_t te_prev_subj_loc;		/*!< Item 2 is the local part of previous subject */
  caddr_t te_prev_pred_ns;		/*!< Item 3 is the namespace part of previous predicate. */
  caddr_t te_prev_pred_loc;		/*!< Item 4 is the local part of previous predicate */
  ptrlong te_ns_count_s_o;		/*!< Item 5 is a counter of created namespaces for subjects and objects */
  ptrlong te_ns_count_p_dt;		/*!< Item 6 is a counter of created namespaces for predicates and datatypes */
  ptrlong te_flags;			/*!< Item 7 is a bitwise OR of TTL_ENV_xxx bits */
  ttl_iriref_t *te_cols;		/*!< Array of temp data for result set columns */
  dk_session_t *te_out_ses;		/*!< Output session, used only for sparql_rset_ttl_write_row */
} ttl_env_t;

int
ttl_try_to_cache_new_prefix (caddr_t *qst, dk_session_t *ses, ttl_env_t *env, ptrlong *ns_counter_ptr, ttl_iriref_t *ti)
{
  id_hash_iterator_t *ns2pref_hit = env->te_used_prefixes;
  id_hash_t *ns2pref = ns2pref_hit->hit_hash;
  caddr_t *prefx_ptr;
  ptrlong ns_counter_val;
  if ('\0' == ti->ns[0])
    return 0;
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
  if ('\0' == ti->loc[0])
    { /* We do not generate namespace prefixes of namespaces that are used as whole IRIs */
      if (NULL == ti->uri)
        {
          ti->uri = ti->ns;
          ti->ns = uname___empty;
        }
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
    {
      if (TTL_ENV_ONLY_PREDEFINED_PREFIXES & env->te_flags)
        {
          if (NULL == ti->uri)
            ti->uri = box_dv_short_concat (ti->ns, ti->loc);
          return 0;
        }
      ti->prefix = box_sprintf (20, "ns%d", ns2pref->ht_count);
    }
  id_hash_set (ns2pref, (caddr_t)(&ti->ns), (caddr_t)(&(ti->prefix)));
  ti->prefix = box_copy (ti->prefix);
  ns_counter_ptr[0] = ns_counter_val + 1;
  ti->ns = box_copy (ti->ns);
  return 1;
}

int
ttl_http_write_prefix_if_needed (caddr_t *qst, dk_session_t *ses, ttl_env_t *env, ptrlong *ns_counter_ptr, ttl_iriref_t *ti)
{
  int cache_ok = ttl_try_to_cache_new_prefix (qst, ses, env, ns_counter_ptr, ti);
  if (!cache_ok)
    return 0;
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
  if (env->te_flags & TTL_ENV_HTML_OUTPUT)
    {
      session_buffered_write (ses, ":\t&lt;", 6);
      dks_esc_write (ses, ti->ns, box_length (ti->ns) - 1, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_HTML_TTL_IRI);
      session_buffered_write (ses, "&gt; .\n", 7);
    }
  else
    {
      session_buffered_write (ses, ":\t<", 3);
      dks_esc_write (ses, ti->ns, box_length (ti->ns) - 1, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_TTL_IRI);
      session_buffered_write (ses, "> .\n", 4);
    }
  return 1;
}

void
ttl_http_write_ref (dk_session_t *ses, ttl_env_t *env, ttl_iriref_t *ti)
{
  caddr_t loc = ti->loc;
  caddr_t full_uri = ((NULL != ti->uri) ? ti->uri : loc);
  if (ti->is_bnode)
    {
      session_buffered_write (ses, "_:", 2);
      session_buffered_write (ses, loc, strlen (loc));
      return;
    }
  if (env->te_flags & TTL_ENV_HTML_OUTPUT)
    {
      session_buffered_write (ses, "<a href=\"", 9);
      dks_esc_write (ses, full_uri, box_length (full_uri) - 1, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_URI);
      session_buffered_write (ses, "\">", 2);
      if (NULL != ti->prefix)
        {
          session_buffered_write (ses, ti->prefix, strlen (ti->prefix));
          session_buffered_write_char (':', ses);
          session_buffered_write (ses, loc, strlen (loc));
        }
      else
        {
          session_buffered_write (ses, "&lt;", 4);
          dks_esc_write (ses, full_uri, box_length (full_uri) - 1, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_HTML_TTL_IRI);
          session_buffered_write (ses, "&gt;", 4);
        }
      session_buffered_write (ses, "</a>", 4);
    }
  else
    {
      if (NULL != ti->prefix)
        {
          session_buffered_write (ses, ti->prefix, strlen (ti->prefix));
          session_buffered_write_char (':', ses);
          session_buffered_write (ses, loc, strlen (loc));
        }
      else
        {
          session_buffered_write_char ('<', ses);
          dks_esc_write (ses, full_uri, box_length (full_uri) - 1, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_TTL_IRI);
          session_buffered_write_char ('>', ses);
        }
    }
}

#ifdef NOT_CURRENTLY_USED
static caddr_t
rdf_box_get_lang (query_instance_t * qi, unsigned short lang)
{
  caddr_t lang_id = nic_id_name (rdf_lang_cache, lang);
  static query_t *qr = NULL;
  local_cursor_t * lc = NULL;
  caddr_t err = NULL;

  if (NULL != lang_id)
    return lang_id;
  if (!qr)
    qr = sql_compile ("select RL_ID from DB.DBA.RDF_LANGUAGE where RL_TWOBYTE = ?", qi->qi_client, &err, SQLC_DEFAULT);
  if (!err)
    {
      err = qr_rec_exec (qr, qi->qi_client, &lc, CALLER_LOCAL, NULL, 1, ":0", (ptrlong) lang, QRP_INT);
    }
  if (!err && lc_next (lc))
    {
      caddr_t val = lc_nth_col (lc, 0);
      lang_id = box_copy (val);
      nic_set (rdf_lang_cache, lang_id, (boxint) lang);
    }
  if (lc) lc_free (lc);
  if (err && (caddr_t) SQL_NO_DATA_FOUND != err)
    {
      dk_free_tree (err);
    }
  return lang_id;
}
#endif

static void
http_ttl_or_nt_prepare_obj (query_instance_t *qi, caddr_t obj, dtp_t obj_dtp, ttl_iriref_t *dt_ret)
{
  switch (obj_dtp)
    {
    case DV_RDF:
      {
        rdf_box_t *rb = (rdf_box_t *)obj;
        if (!rb->rb_is_complete)
          rb_complete (rb, qi->qi_trx, qi);
        rb_dt_lang_check(rb);
        if (RDF_BOX_DEFAULT_TYPE == rb->rb_type)
          return;
        if (RDF_BOX_GEO_TYPE == rb->rb_type)
          {
            dt_ret->uri = uname_virtrdf_ns_uri_Geometry;
            return;
          }
        dt_ret->uri = rdf_type_twobyte_to_iri (rb->rb_type);
        if (dt_ret->uri) /* if by some reason rb_type is wrong */
          box_flags (dt_ret->uri) |= BF_IRI;
        return;
      }
    case DV_DATETIME:
      switch (DT_DT_TYPE(obj))
        {
        case DT_TYPE_DATE: dt_ret->uri = uname_xmlschema_ns_uri_hash_date; return;
        case DT_TYPE_TIME: dt_ret->uri = uname_xmlschema_ns_uri_hash_time; return;
        default : dt_ret->uri = uname_xmlschema_ns_uri_hash_dateTime; return;
        }
    case DV_SINGLE_FLOAT: dt_ret->uri = uname_xmlschema_ns_uri_hash_float; return;
    case DV_DOUBLE_FLOAT: dt_ret->uri = uname_xmlschema_ns_uri_hash_double; return;
    default: ;
    }
}

static void
http_ttl_or_nt_write_xe (dk_session_t *ses, query_instance_t *qi, xml_entity_t *xe, int print_type_suffix, int html_ttl)
{
  dk_session_t *tmp_ses = strses_allocate();
  caddr_t tmp_utf8_box;
  client_connection_t *cli = qi->qi_client;
  wcharset_t *saved_charset = cli->cli_charset;
  cli->cli_charset = CHARSET_UTF8;
  xe->_->xe_serialize (xe, tmp_ses);
  cli->cli_charset = saved_charset;
  if (!STRSES_CAN_BE_STRING (tmp_ses))
    {
      strses_free (tmp_ses);
      sqlr_new_error ("22023", "HT057", "The serialization of XML literal as TURTLE or NT is longer than 10Mb, this is not supported");
    }
  tmp_utf8_box = strses_string (tmp_ses);
  strses_free (tmp_ses);
  session_buffered_write_char ('"', ses);
  dks_esc_write (ses, tmp_utf8_box, box_length (tmp_utf8_box) - 1, CHARSET_UTF8, CHARSET_UTF8, html_ttl ? DKS_ESC_HTML_TTL_DQ : DKS_ESC_TTL_DQ);
  dk_free_box (tmp_utf8_box);
  session_buffered_write_char ('"', ses);
  if (print_type_suffix)
    {
      if (html_ttl) SES_PRINT (ses, "^^&lt;"); else SES_PRINT (ses, "^^<");
      SES_PRINT (ses, uname_rdf_ns_uri_XMLLiteral);
      if (html_ttl) SES_PRINT (ses, "&gt;"); else session_buffered_write_char ('>', ses);
    }
}

static void
http_json_write_xe (dk_session_t *ses, query_instance_t *qi, xml_entity_t *xe)
{
  dk_session_t *tmp_ses = strses_allocate();
  caddr_t tmp_utf8_box;
  client_connection_t *cli = qi->qi_client;
  wcharset_t *saved_charset = cli->cli_charset;
  cli->cli_charset = CHARSET_UTF8;
  xe->_->xe_serialize (xe, tmp_ses);
  cli->cli_charset = saved_charset;
  if (!STRSES_CAN_BE_STRING (tmp_ses))
    {
      strses_free (tmp_ses);
      sqlr_new_error ("22023", "HT057", "The serialization of XML literal as JSON is longer than 10Mb, this is not supported");
    }
  tmp_utf8_box = strses_string (tmp_ses);
  strses_free (tmp_ses);
  session_buffered_write_char ('"', ses);
  dks_esc_write (ses, tmp_utf8_box, box_length (tmp_utf8_box) - 1, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_TTL_DQ);
  dk_free_box (tmp_utf8_box);
  session_buffered_write_char ('"', ses);
}

static void
http_ttl_write_obj (dk_session_t *ses, ttl_env_t *env, query_instance_t *qi, caddr_t obj, dtp_t obj_dtp, ttl_iriref_t *dt_ptr)
{
  caddr_t obj_box_value;
  dtp_t obj_box_value_dtp;
  int html_ttl = (TTL_ENV_HTML_OUTPUT & env->te_flags);
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
        if (DV_RDF != obj_dtp)
          {
            session_buffered_write (ses, "^^", 2);
            ttl_http_write_ref (ses, env, dt_ptr);
          }
        break;
      }
    case DV_STRING:
      session_buffered_write_char ('"', ses);
      dks_esc_write (ses, obj_box_value, box_length (obj_box_value) - 1, CHARSET_UTF8, CHARSET_UTF8, html_ttl ? DKS_ESC_HTML_TTL_DQ : DKS_ESC_TTL_DQ);
      session_buffered_write_char ('"', ses);
      break;
    case DV_WIDE:
      session_buffered_write_char ('"', ses);
      dks_esc_write (ses, obj_box_value, box_length (obj_box_value) - sizeof (wchar_t), CHARSET_UTF8, CHARSET_WIDE, html_ttl ? DKS_ESC_HTML_TTL_DQ : DKS_ESC_TTL_DQ);
      session_buffered_write_char ('"', ses);
      break;
    case DV_XML_ENTITY:
      http_ttl_or_nt_write_xe (ses, qi, (xml_entity_t *)(obj_box_value),
        ((DV_RDF == obj_dtp) ? (RDF_BOX_DEFAULT_TYPE == ((rdf_box_t *)obj)->rb_type) : 1),
        html_ttl );
      break;
    case DV_DB_NULL:
      session_buffered_write (ses, "(NULL)", 6);
      break;
    case DV_SINGLE_FLOAT:
      {
        char tmpbuf[50];
        int buffill;
        double boxdbl = (double)(unbox_float (obj_box_value));
        buffill = sprintf (tmpbuf, "\"%lg", boxdbl);
        if ((NULL == strchr (tmpbuf+1, '.')) && (NULL == strchr (tmpbuf+1, 'E')) && (NULL == strchr (tmpbuf+1, 'e')))
          {
            if (isalpha(tmpbuf[1+1]))
              {
                double myZERO = 0.0;
                double myPOSINF_d = 1.0/myZERO;
                double myNEGINF_d = -1.0/myZERO;
                if (myPOSINF_d == boxdbl) buffill = sprintf (tmpbuf, "\"INF\"");
                else if (myNEGINF_d == boxdbl) buffill = sprintf (tmpbuf, "\"-INF\"");
                else buffill = sprintf (tmpbuf, "\"NAN\"");
              }
            else
              {
                strcpy (tmpbuf+buffill, ".0");
                buffill += 2;
              }
          }                   /* .0123456789012 */
        strcpy (tmpbuf+buffill, "\"^^xsd:float");
        buffill += 12;
        session_buffered_write (ses, tmpbuf, buffill);
        break;
      }
    case DV_DOUBLE_FLOAT:
      {
        char tmpbuf[50];
        int buffill;
        double boxdbl = unbox_double (obj_box_value);
        buffill = sprintf (tmpbuf, "%lg", boxdbl);
        if ((NULL == strchr (tmpbuf, '.')) && (NULL == strchr (tmpbuf, 'E')) && (NULL == strchr (tmpbuf, 'e')))
          {
            if (isalpha(tmpbuf[1]))
              {
                double myZERO = 0.0;
                double myPOSINF_d = 1.0/myZERO;
                double myNEGINF_d = -1.0/myZERO;
                if (myPOSINF_d == boxdbl) buffill = sprintf (tmpbuf, "\"INF\"^^xsd:double");
                else if (myNEGINF_d == boxdbl) buffill = sprintf (tmpbuf, "\"-INF\"^^xsd:double");
                else buffill = sprintf (tmpbuf, "\"NAN\"^^xsd:double");
              }
            else
              {
                strcpy (tmpbuf+buffill, ".0");
                buffill += 2;
              }
          }
        session_buffered_write (ses, tmpbuf, buffill);
        break;
      }
    default:
      {
        caddr_t tmp_utf8_box = box_cast_to_UTF8 ((caddr_t *)qi, obj_box_value); /* not box_cast_to_UTF8_xsd(), because float and double are handled above and there are no other differences between xsd and sql so far */
        int need_quotes = ((DV_RDF == obj_dtp) || (DV_BLOB_HANDLE == obj_dtp) || (DV_BLOB_WIDE_HANDLE == obj_dtp));
        if (need_quotes)
          session_buffered_write_char ('"', ses);
        session_buffered_write (ses, tmp_utf8_box, box_length (tmp_utf8_box) - 1);
        if (need_quotes)
          session_buffered_write_char ('"', ses);
        dk_free_box (tmp_utf8_box);
        break;
      }
    }
  if (DV_RDF == obj_dtp)
    {
      rdf_box_t *rb = (rdf_box_t *)obj;
      rb_dt_lang_check(rb);
      if (RDF_BOX_DEFAULT_LANG != rb->rb_lang)
        {
          caddr_t lang_id = rdf_lang_twobyte_to_string (rb->rb_lang);
          if (NULL != lang_id) /* just in case if lang cannot be found, may be signal an error ? */
            {
              session_buffered_write_char ('@', ses);
              session_buffered_write (ses, lang_id, box_length (lang_id) - 1);
	      dk_free_box (lang_id);
            }
        }
      if (rb->rb_type > RDF_BOX_MIN_TYPE && RDF_BOX_DEFAULT_TYPE != rb->rb_type)
        {
          session_buffered_write (ses, "^^", 2);
          ttl_http_write_ref (ses, env, dt_ptr);
        }
    }
}

ttl_env_t *
bif_ttl_env_arg (caddr_t *qst, state_slot_t **args, int idx, const char *fname)
{
  ttl_env_t *env = (ttl_env_t *)bif_arg (qst, args, idx, fname);
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF ((caddr_t)env) ||
    (sizeof (ttl_env_t) != box_length ((caddr_t)env)) ||
    (DV_DICT_ITERATOR != DV_TYPE_OF (env->te_used_prefixes)) ||
    (((DV_STRING == DV_TYPE_OF (env->te_prev_subj_ns)) || (DV_UNAME == DV_TYPE_OF (env->te_prev_subj_ns))) &&
      ((DV_STRING != DV_TYPE_OF (env->te_prev_subj_loc)) ||
        ((DV_STRING != DV_TYPE_OF (env->te_prev_pred_ns)) && (DV_UNAME != DV_TYPE_OF (env->te_prev_pred_ns))) ||
        (DV_STRING != DV_TYPE_OF (env->te_prev_pred_loc)) ) ) ||
    (DV_LONG_INT != DV_TYPE_OF (env->te_ns_count_s_o)) ||
    (DV_LONG_INT != DV_TYPE_OF (env->te_ns_count_p_dt)) ||
    (DV_LONG_INT != DV_TYPE_OF (env->te_flags)) )
    sqlr_new_error ("22023", "SR601", "Argument %d of %s() should be an array of special format", idx, fname);
  return env;
}

caddr_t
bif_http_ttl_prefixes (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *)qst;
  ttl_env_t *env = bif_ttl_env_arg (qst, args, 0, "http_ttl_prefixes");
  caddr_t subj = bif_arg (qst, args, 1, "http_ttl_prefixes");
  caddr_t pred = bif_arg (qst, args, 2, "http_ttl_prefixes");
  caddr_t obj = bif_arg (qst, args, 3, "http_ttl_prefixes");
  dk_session_t *ses = http_session_no_catch_arg (qst, args, 4, "http_ttl_prefixes");
  int status = 0;
  int obj_is_iri = 0;
  dtp_t obj_dtp = 0;
  ttl_iriref_items_t tii;
  memset (&tii,0, sizeof (ttl_iriref_items_t));
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
    {
      http_ttl_or_nt_prepare_obj (qi, obj, obj_dtp, &tii.dt);
      if (NULL != tii.dt.uri)
        iri_split_ttl_qname (tii.dt.uri, &(tii.dt.ns), &(tii.dt.loc), 1);
    }
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
fail:
  dk_free_box (tii.s.uri);	dk_free_box (tii.s.ns);		dk_free_box (tii.s.loc);	dk_free_box (tii.s.prefix);
  dk_free_box (tii.p.uri);	dk_free_box (tii.p.ns);		dk_free_box (tii.p.loc);	dk_free_box (tii.p.prefix);
  dk_free_box (tii.o.uri);	dk_free_box (tii.o.ns);		dk_free_box (tii.o.loc);	dk_free_box (tii.o.prefix);
  dk_free_box (tii.dt.uri);	dk_free_box (tii.dt.ns);	dk_free_box (tii.dt.loc);	dk_free_box (tii.dt.prefix);
  return (caddr_t)(ptrlong)(status);
}


caddr_t
bif_http_ttl_triple (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *)qst;
  ttl_env_t *env = bif_ttl_env_arg (qst, args, 0, "http_ttl_triple");
  caddr_t subj = bif_arg (qst, args, 1, "http_ttl_triple");
  caddr_t pred = bif_arg (qst, args, 2, "http_ttl_triple");
  caddr_t obj = bif_arg (qst, args, 3, "http_ttl_triple");
  dk_session_t *ses = http_session_no_catch_arg (qst, args, 4, "http_ttl_triple");
  int status = 0;
  int obj_is_iri = 0;
  dtp_t obj_dtp = 0;
  ttl_iriref_items_t tii;
  memset (&tii,0, sizeof (ttl_iriref_items_t));
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
    {
      http_ttl_or_nt_prepare_obj (qi, obj, obj_dtp, &tii.dt);
      if (NULL != tii.dt.uri)
        iri_split_ttl_qname (tii.dt.uri, &(tii.dt.ns), &(tii.dt.loc), 1);
    }
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
    strcmp (env->te_prev_subj_loc, ((NULL != tii.s.uri) ? tii.s.uri : tii.s.loc)) )
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
      if (NULL != tii.s.uri)
        { env->te_prev_subj_loc = tii.s.uri;	tii.s.uri = NULL; }
      else
        { env->te_prev_subj_loc = tii.s.loc;	tii.s.loc = NULL; }
    }
  if ((NULL == env->te_prev_pred_ns) ||
    strcmp (env->te_prev_pred_ns, tii.p.ns) ||
    strcmp (env->te_prev_pred_loc, ((NULL != tii.p.uri) ? tii.p.uri : tii.p.loc)) )
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
      if (NULL != tii.p.uri)
        { env->te_prev_pred_loc = tii.p.uri;	tii.p.uri = NULL; }
      else
        { env->te_prev_pred_loc = tii.p.loc;	tii.p.loc = NULL; }
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

int
rdfxml_http_write_prefix_if_needed (caddr_t *qst, dk_session_t *ses, ttl_env_t *env, ptrlong *ns_counter_ptr, ttl_iriref_t *ti)
{
  int cache_ok = ttl_try_to_cache_new_prefix (qst, ses, env, ns_counter_ptr, ti);
  if (!cache_ok)
    return 0;                /* .0.12345678 */
  session_buffered_write (ses, "\n\txmlns:", 8);
  session_buffered_write (ses, ti->prefix, strlen (ti->prefix));
  session_buffered_write (ses, "=\"", 2);
  dks_esc_write (ses, ti->ns, box_length (ti->ns) - 1, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_DQATTR);
  session_buffered_write_char ('"', ses);
  return 1;
}

caddr_t
bif_http_rdfxml_p_ns (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *)qst;
  ttl_env_t *env = (ttl_env_t *)bif_arg (qst, args, 0, "http_rdfxml_p_ns");
  caddr_t pred = bif_arg (qst, args, 1, "http_rdfxml_p_ns");
  dk_session_t *ses = http_session_no_catch_arg (qst, args, 2, "http_rdfxml_p_ns");
  int status = 0;
  ttl_iriref_t ti;
  memset (&ti,0, sizeof (ttl_iriref_t));
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF ((caddr_t)env) ||
    (sizeof (ttl_env_t) != box_length ((caddr_t)env)) ||
    (DV_DICT_ITERATOR != DV_TYPE_OF (env->te_used_prefixes)) /* ||
    (((DV_STRING == DV_TYPE_OF (env->te_prev_subj_ns)) || (DV_UNAME == DV_TYPE_OF (env->te_prev_subj_ns))) &&
      ((DV_STRING != DV_TYPE_OF (env->te_prev_subj_loc)) ||
        ((DV_STRING != DV_TYPE_OF (env->te_prev_pred_ns)) && (DV_UNAME != DV_TYPE_OF (env->te_prev_pred_ns))) ||
        (DV_STRING != DV_TYPE_OF (env->te_prev_pred_loc)) ) ) */ ||
    (DV_LONG_INT != DV_TYPE_OF (env->te_ns_count_s_o)) ||
    (DV_LONG_INT != DV_TYPE_OF (env->te_ns_count_p_dt)) )
    sqlr_new_error ("22023", "SR601", "Argument 1 of http_rdfxml_p_ns() should be an array of special format");
  if (!iri_cast_and_split_ttl_qname (qi, pred, &ti.ns, &ti.loc, &ti.is_bnode))
    goto fail; /* see below */
  if ((NULL != ti.ns) && ('\0' != ti.ns[0]))
    status += rdfxml_http_write_prefix_if_needed (qst, ses, env, &(env->te_ns_count_p_dt), &(ti));
  fail:
  dk_free_box (ti.uri); dk_free_box (ti.ns); dk_free_box (ti.loc); dk_free_box (ti.prefix);
  return (caddr_t)(ptrlong)(status);
}

#define RDFXML_HTTP_WRITE_REF_ABOUT	1
#define RDFXML_HTTP_WRITE_REF_P_OPEN	2
#define RDFXML_HTTP_WRITE_REF_P_CLOSE	3
#define RDFXML_HTTP_WRITE_REF_RES	4
#define RDFXML_HTTP_WRITE_REF_DT	5

void
rdfxml_http_write_ref (dk_session_t *ses, ttl_env_t *env, ttl_iriref_t *ti, int opcode)
{
  caddr_t full_uri;
  const char *prefix_to_use;
  caddr_t loc = ti->loc;
  int close_attr = 0;
  if (ti->is_bnode)
    {
      full_uri = ((NULL != ti->uri) ? ti->uri : loc);
      if ((RDFXML_HTTP_WRITE_REF_ABOUT != opcode) && (RDFXML_HTTP_WRITE_REF_RES != opcode))
        {                            /* 0123456789012345678901 */
          session_buffered_write (ses, "rdf:MisusedBlankNode_", 21);
          session_buffered_write (ses, full_uri, strlen (full_uri));
          return;
        }                        /* 012345678901.23 */
      session_buffered_write (ses, " rdf:nodeID=\"", 13);
      session_buffered_write (ses, full_uri, strlen (full_uri));
      session_buffered_write_char ('"', ses);
      return;
    }
  switch (opcode)
    {
    case RDFXML_HTTP_WRITE_REF_ABOUT: /* 01234567890.12 */
      session_buffered_write (ses,      " rdf:about=\"", 12);
      prefix_to_use = NULL;
      close_attr = 1;
      break;
    case RDFXML_HTTP_WRITE_REF_P_OPEN: /* no break */
    case RDFXML_HTTP_WRITE_REF_P_CLOSE:
      prefix_to_use = ti->prefix;
      if ((NULL == prefix_to_use) && (NULL != ti->ns) && ('\0' != ti->ns[0]))
        prefix_to_use = "p";
      break;
    case RDFXML_HTTP_WRITE_REF_RES: /* 01234567890123.45 */
      session_buffered_write (ses,    " rdf:resource=\"", 15);
      prefix_to_use = NULL;
      close_attr = 1;
      break;
    case RDFXML_HTTP_WRITE_REF_DT: /* 01234567890123.45 */
      session_buffered_write (ses,   " rdf:datatype=\"", 15);
      prefix_to_use = ti->prefix;
      if ((NULL == prefix_to_use) && (NULL != ti->ns) && ('\0' != ti->ns[0]))
        prefix_to_use = "dt";
      close_attr = 1;
      break;
    default: prefix_to_use = NULL; GPF_T;
    }
  if (NULL != prefix_to_use)
    {
      session_buffered_write (ses, prefix_to_use, strlen (prefix_to_use));
      session_buffered_write_char (':', ses);
      dks_esc_write (ses, ti->loc, box_length (ti->loc) - 1, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_PTEXT);
      if ((prefix_to_use != ti->prefix) && (RDFXML_HTTP_WRITE_REF_P_CLOSE != opcode))
        {
          session_buffered_write (ses, " xmlns:", 7);
          session_buffered_write (ses, prefix_to_use, strlen (prefix_to_use));
          session_buffered_write (ses, "=\"", 2);
          dks_esc_write (ses, ti->ns, box_length (ti->ns) - 1, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_PTEXT);
          close_attr = 1;
        }
    }
  else
    {
      full_uri = ((NULL != ti->uri) ? ti->uri : loc);
      dks_esc_write (ses, full_uri, box_length (full_uri) - 1, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_PTEXT);
    }
  if (close_attr)
    session_buffered_write_char ('"', ses);
}

static void
http_rdfxml_prepare_obj (query_instance_t *qi, caddr_t obj, dtp_t obj_dtp, ttl_iriref_t *dt_ret)
{
  if (DV_RDF == obj_dtp)
    {
      rdf_box_t *rb = (rdf_box_t *)obj;
      if (!rb->rb_is_complete)
        rb_complete (rb, qi->qi_trx, qi);
      rb_dt_lang_check(rb);
      if (RDF_BOX_DEFAULT_TYPE != rb->rb_type)
        {
          dt_ret->uri = rdf_type_twobyte_to_iri (rb->rb_type);
          if ((uname_rdf_ns_uri_XMLLiteral == dt_ret->uri) && (DV_XML_ENTITY == DV_TYPE_OF (obj)))
            {
              dk_free_box (dt_ret->uri);
              dt_ret->uri = NULL;
              return;
            }
          if (NULL != dt_ret->uri) /* if by some reason rb_type is wrong */
            box_flags (dt_ret->uri) |= BF_IRI;
          return;
        }
      obj = rb->rb_box;
    }
  if ((DV_STRING == DV_TYPE_OF (obj)) || DV_XML_ENTITY == DV_TYPE_OF (obj))
    {
      dk_free_box (dt_ret->uri);
      dt_ret->uri = NULL;
    }
  else
    {
      caddr_t dt_iri = xsd_type_of_box (obj);
      if (!IS_BOX_POINTER (dt_iri))
        dt_ret->uri = NULL;
      else
        dt_ret->uri = dt_iri;
    }
}

static void
http_rdfxml_write_obj (dk_session_t *ses, ttl_env_t *env, query_instance_t *qi, caddr_t obj, dtp_t obj_dtp, ttl_iriref_t *dt_ptr)
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
        session_buffered_write (ses, temp, strlen (temp));
        break;
      }
    case DV_STRING:
      dks_esc_write (ses, obj_box_value, box_length (obj_box_value) - 1, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_PTEXT);
      break;
    case DV_WIDE:
      dks_esc_write (ses, obj_box_value, box_length (obj_box_value) - sizeof (wchar_t), CHARSET_UTF8, CHARSET_WIDE, DKS_ESC_PTEXT);
      break;
    case DV_XML_ENTITY:
      {
        client_connection_t *cli = qi->qi_client;
        wcharset_t *saved_charset = cli->cli_charset;
        xml_entity_t *xe = (xml_entity_t *)(obj_box_value);
        cli->cli_charset = CHARSET_UTF8;
        xe->_->xe_serialize (xe, ses);
        cli->cli_charset = saved_charset;
        break;
      }
    case DV_DB_NULL:
      session_buffered_write (ses, "(NULL)", 6);
      break;
    default:
      {
        caddr_t tmp_utf8_box = box_cast_to_UTF8_xsd ((caddr_t *)qi, obj_box_value);
        session_buffered_write (ses, tmp_utf8_box, box_length (tmp_utf8_box) - 1);
        dk_free_box (tmp_utf8_box);
        break;
      }
    }
}

caddr_t
bif_http_rdfxml_triple (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *)qst;
  ttl_env_t *env = (ttl_env_t *)bif_arg (qst, args, 0, "http_rdfxml_triple");
  caddr_t subj = bif_arg (qst, args, 1, "http_rdfxml_triple");
  caddr_t pred = bif_arg (qst, args, 2, "http_rdfxml_triple");
  caddr_t obj = bif_arg (qst, args, 3, "http_rdfxml_triple");
  dk_session_t *ses = http_session_no_catch_arg (qst, args, 4, "http_rdfxml_triple");
  int status = 0;
  int obj_is_iri = 0;
  int obj_is_xml = 0;
  dtp_t obj_dtp = 0;
  ttl_iriref_items_t tii;
  memset (&tii,0, sizeof (ttl_iriref_items_t));
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF ((caddr_t)env) ||
    (sizeof (ttl_env_t) != box_length ((caddr_t)env)) ||
    (DV_DICT_ITERATOR != DV_TYPE_OF (env->te_used_prefixes)) /* ||
    (((DV_STRING == DV_TYPE_OF (env->te_prev_subj_ns)) || (DV_UNAME == DV_TYPE_OF (env->te_prev_subj_ns))) &&
      ((DV_STRING != DV_TYPE_OF (env->te_prev_subj_loc)) ||
        ((DV_STRING != DV_TYPE_OF (env->te_prev_pred_ns)) && (DV_UNAME != DV_TYPE_OF (env->te_prev_pred_ns))) ||
        (DV_STRING != DV_TYPE_OF (env->te_prev_pred_loc)) ) ) */ ||
    (DV_LONG_INT != DV_TYPE_OF (env->te_ns_count_s_o)) ||
    (DV_LONG_INT != DV_TYPE_OF (env->te_ns_count_p_dt)) )
    sqlr_new_error ("22023", "SR601", "Argument 1 of http_rdfxml_triple() should be an array of special format");
  if (!iri_cast_rdfxml_qname (qi, subj, &tii.s.uri, &tii.s.is_bnode))
    goto fail; /* see below */
  if (!iri_cast_and_split_ttl_qname (qi, pred, &tii.p.ns, &tii.p.loc, &tii.p.is_bnode))
    goto fail; /* see below */
  if ((NULL != tii.p.ns) && ('\0' != tii.p.ns[0]) && (!tii.p.is_bnode))
    {
      id_hash_iterator_t *ns2pref_hit = env->te_used_prefixes;
      id_hash_t *ns2pref = ns2pref_hit->hit_hash;
#ifndef NDEBUG
      if ('\0' == tii.p.ns[0])
        GPF_T1("ttl_" "bif_http_rdfxml_triple: empty p.ns");
#endif
      if (('_' != tii.p.ns[0]) || (':' != tii.p.ns[1]))
        {
          caddr_t *prefx_ptr = (caddr_t *)id_hash_get (ns2pref, (caddr_t)(&tii.p.ns));
          if (NULL != prefx_ptr)
            tii.p.prefix = box_copy (prefx_ptr[0]);
        }
    }
  obj_dtp = DV_TYPE_OF (obj);
  switch (obj_dtp)
    {
    case DV_UNAME: case DV_IRI_ID: case DV_IRI_ID_8: obj_is_iri = 1; break;
    case DV_STRING: obj_is_iri = (BF_IRI & box_flags (obj)) ? 1 : 0; break;
    case DV_XML_ENTITY: obj_is_xml = 1; break;
    case DV_RDF: if (DV_XML_ENTITY == DV_TYPE_OF (((rdf_box_t *)obj)->rb_box)) obj_is_xml = 1; break;
    }
  if (obj_is_iri)
    {
      if (!iri_cast_rdfxml_qname (qi, obj, &tii.o.uri, &tii.o.is_bnode))
        goto fail; /* see below */
    }
  else
    {
      http_rdfxml_prepare_obj (qi, obj, obj_dtp, &tii.dt);
      if (NULL != tii.dt.uri)
        iri_cast_rdfxml_qname (qi, tii.dt.uri, &(tii.dt.uri), &(tii.dt.is_bnode));
    }
  if (DV_STRING != DV_TYPE_OF (env->te_prev_subj_loc))
    {
      dk_free_tree (env->te_prev_subj_loc);	env->te_prev_subj_loc = NULL;
    }
  if ((NULL == env->te_prev_subj_loc) ||
    strcmp (env->te_prev_subj_loc, tii.s.uri) )
    {
      if (NULL != env->te_prev_subj_loc)
        {                            /* .0123456789012345678901 */
          session_buffered_write (ses, "\n  </rdf:Description>", 21);
          dk_free_tree (env->te_prev_subj_loc);	env->te_prev_subj_loc = NULL;
          dk_free_tree (env->te_prev_pred_ns);	env->te_prev_pred_ns = NULL;
          dk_free_tree (env->te_prev_pred_loc);	env->te_prev_pred_loc = NULL;
        }
                                 /* .01234567890123456789 */
      session_buffered_write (ses, "\n  <rdf:Description", 19);
      rdfxml_http_write_ref (ses, env, &(tii.s), RDFXML_HTTP_WRITE_REF_ABOUT);
      session_buffered_write_char ('>', ses);
      env->te_prev_subj_loc = tii.s.uri;
      tii.s.uri = NULL;
    }
  if (tii.p.loc && !tii.p.loc[0])
    session_buffered_write (ses, "\n    <!--", 9);
                             /* .0123456 */
  session_buffered_write (ses, "\n    <", 6);
  rdfxml_http_write_ref (ses, env, &(tii.p), RDFXML_HTTP_WRITE_REF_P_OPEN);
  if (obj_is_iri)
    {
      rdfxml_http_write_ref (ses, env, &(tii.o), RDFXML_HTTP_WRITE_REF_RES);
      session_buffered_write (ses, " />", 3);
    }
  else
    {
      if (NULL != tii.dt.uri)
        rdfxml_http_write_ref (ses, env, &(tii.dt), RDFXML_HTTP_WRITE_REF_DT);
      if (obj_is_xml)              /* 012345678901234.56789012.34 */
        session_buffered_write (ses, " rdf:parseType=\"Literal\"", 24);
      if (DV_RDF == obj_dtp)
        {
          rdf_box_t *rb = (rdf_box_t *)obj;
          rb_dt_lang_check(rb);
          if (RDF_BOX_DEFAULT_LANG != rb->rb_lang)
            {
              caddr_t lang_id = rdf_lang_twobyte_to_string (rb->rb_lang);
              if (NULL != lang_id) /* just in case if lang cannot be found, may be signal an error ? */
                {                            /* 0123456789.01 */
                  session_buffered_write (ses, " xml:lang=\"", 11);
                  session_buffered_write (ses, lang_id, box_length (lang_id) - 1);
                  session_buffered_write_char ('"', ses);
                  dk_free_box (lang_id);
                }
            }
        }
      session_buffered_write_char ('>', ses);
      http_rdfxml_write_obj (ses, env, qi, obj, obj_dtp, &tii.dt);
      session_buffered_write (ses, "</", 2);
      rdfxml_http_write_ref (ses, env, &(tii.p), RDFXML_HTTP_WRITE_REF_P_CLOSE);
      session_buffered_write_char ('>', ses);
    }
  if (tii.p.loc && !tii.p.loc[0])
    session_buffered_write (ses, "\n    -->", 8);
fail:
  dk_free_box (tii.s.uri); /*	dk_free_box (tii.s.ns);		dk_free_box (tii.s.loc);	dk_free_box (tii.s.prefix); */
  dk_free_box (tii.p.uri);	dk_free_box (tii.p.ns);		dk_free_box (tii.p.loc);	dk_free_box (tii.p.prefix);
  dk_free_box (tii.o.uri); /*	dk_free_box (tii.o.ns);		dk_free_box (tii.o.loc);	dk_free_box (tii.o.prefix); */
  dk_free_box (tii.dt.uri); /*	dk_free_box (tii.dt.ns);	dk_free_box (tii.dt.loc);	dk_free_box (tii.dt.prefix); */
  return (caddr_t)(ptrlong)(status);
}

/*! Environment of Ntriples serializer */
typedef struct nt_env_s {
  caddr_t ne_rowctr;			/*!< Item 1 is row counter. */
  ttl_iriref_t *ne_cols;		/*!< Item 2 is array of temp data for result set columns. */
  dk_session_t *ne_out_ses;		/*!< Item 3 is output session, used only for sparql_rset_nt_write_row(). */
} nt_env_t;

void
nt_http_write_ref_1 (dk_session_t *ses, nt_env_t *env, ttl_iriref_t *ti, caddr_t dflt_uri, int esc)
{
  caddr_t uri = ti->uri;
  if (NULL == uri)
    {
      uri = dflt_uri;
      if (NULL == uri)
        sqlr_new_error ("22023", "SR645", "NT serialization of RDF data has got NULL instead of an URI");
    }
  if (ti->is_bnode)
    {
      session_buffered_write (ses, uri, strlen (uri));
      return;
    }
#ifndef NDEBUG
  if (NULL != ti->prefix)
    GPF_T;
#endif
  if (esc)
    SES_PRINT (ses, "&lt;");
  else
  session_buffered_write_char ('<', ses);
  dks_esc_write (ses, uri, box_length (uri) - 1, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_TTL_IRI);
  if (esc)
    SES_PRINT (ses, "&gt;");
  else
  session_buffered_write_char ('>', ses);
}

void
nt_http_write_ref (dk_session_t *ses, nt_env_t *env, ttl_iriref_t *ti, caddr_t dflt_uri)
{
  nt_http_write_ref_1 (ses, env, ti, dflt_uri, 0);
}

static void
http_nt_write_obj (dk_session_t *ses, nt_env_t *env, query_instance_t *qi, caddr_t obj, dtp_t obj_dtp, ttl_iriref_t *dt_ptr, int esc_mode)
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
        if (DV_RDF != obj_dtp)
          {
            session_buffered_write (ses, "^^", 2);
            nt_http_write_ref (ses, env, dt_ptr, NULL);
          }
        break;
      }
    case DV_STRING:
      session_buffered_write_char ('"', ses);
      dks_esc_write (ses, obj_box_value, box_length (obj_box_value) - 1, CHARSET_UTF8, CHARSET_UTF8, esc_mode);
      session_buffered_write_char ('"', ses);
      break;
    case DV_WIDE:
      session_buffered_write_char ('"', ses);
      dks_esc_write (ses, obj_box_value, box_length (obj_box_value) - sizeof (wchar_t), CHARSET_UTF8, CHARSET_WIDE, esc_mode);
      session_buffered_write_char ('"', ses);
      break;
    case DV_XML_ENTITY:
      {
        http_ttl_or_nt_write_xe (ses, qi, (xml_entity_t *)(obj_box_value),
          ((DV_RDF == obj_dtp) ? (RDF_BOX_DEFAULT_TYPE == ((rdf_box_t *)obj)->rb_type) : 1),
          0 );
        break;
      }
    case DV_DB_NULL:
      session_buffered_write (ses, "(NULL)", 6);
      break;
    default:
      {
        caddr_t iri = xsd_type_of_box (obj_box_value);
        caddr_t tmp_utf8_box = box_cast_to_UTF8_xsd ((caddr_t *)qi, obj_box_value);
        session_buffered_write_char ('"', ses);
        session_buffered_write (ses, tmp_utf8_box, box_length (tmp_utf8_box) - 1);
        dk_free_box (tmp_utf8_box);
        session_buffered_write_char ('"', ses);
        if ((DV_RDF != obj_dtp) && (DV_WIDE != obj_box_value_dtp))
          {
            if (!IS_BOX_POINTER (iri))
              sqlr_new_error ("22023", "SR624", "Unsupported datatype %d in NT serialization of an object", obj_dtp);
            SES_PRINT (ses, "^^");
            if (esc_mode == DKS_ESC_PTEXT)
              SES_PRINT (ses, "&lt;");
            else
              session_buffered_write_char ('<', ses);
            dks_esc_write (ses, iri, box_length_inline (iri)-1, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_TTL_IRI);
            if (esc_mode == DKS_ESC_PTEXT)
              SES_PRINT (ses, "&gt;");
            else
              session_buffered_write_char ('>', ses);
          }
        dk_free_box (iri);
        break;
      }
    }
  if (DV_RDF == obj_dtp)
    {
      rdf_box_t *rb = (rdf_box_t *)obj;
      rb_dt_lang_check(rb);
      if (RDF_BOX_DEFAULT_LANG != rb->rb_lang)
        {
          caddr_t lang_id = rdf_lang_twobyte_to_string (rb->rb_lang);
          if (NULL != lang_id) /* just in case if lang cannot be found, may be signal an error ? */
            {
              session_buffered_write_char ('@', ses);
              session_buffered_write (ses, lang_id, box_length (lang_id) - 1);
	      dk_free_box (lang_id);
            }
        }
      if (RDF_BOX_DEFAULT_TYPE != rb->rb_type)
        {
          session_buffered_write (ses, "^^", 2);
          nt_http_write_ref_1 (ses, env, dt_ptr, NULL, esc_mode == DKS_ESC_PTEXT);
        }
    }
}

caddr_t
bif_http_nt_triple (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *)qst;
  nt_env_t *env = (nt_env_t *)bif_arg (qst, args, 0, "http_nt_triple");
  caddr_t subj = bif_arg (qst, args, 1, "http_nt_triple");
  caddr_t pred = bif_arg (qst, args, 2, "http_nt_triple");
  caddr_t obj = bif_arg (qst, args, 3, "http_nt_triple");
  dk_session_t *ses = http_session_no_catch_arg (qst, args, 4, "http_nt_triple");
  int status = 0;
  int obj_is_iri = 0;
  dtp_t obj_dtp = 0;
  ttl_iriref_items_t tii;
  memset (&tii,0, sizeof (ttl_iriref_items_t));
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF ((caddr_t)env) ||
    (sizeof (nt_env_t) != box_length ((caddr_t)env)) )
    sqlr_new_error ("22023", "SR601", "Argument 1 of http_nt_triple() should be an array of special format");
  if (!iri_cast_nt_absname (qi, subj, &tii.s.uri, &tii.s.is_bnode))
    goto fail; /* see below */
  if (!iri_cast_nt_absname (qi, pred, &tii.p.uri, &tii.p.is_bnode))
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
      if (!iri_cast_nt_absname (qi, obj, &tii.o.uri, &tii.o.is_bnode))
        goto fail; /* see below */
    }
  else
    {
      http_ttl_or_nt_prepare_obj (qi, obj, obj_dtp, &tii.dt);
    }
  nt_http_write_ref (ses, env, &(tii.s), subj);
  session_buffered_write_char ('\t', ses);
  nt_http_write_ref (ses, env, &(tii.p), pred);
  session_buffered_write_char ('\t', ses);
  if (obj_is_iri)
    nt_http_write_ref (ses, env, &(tii.o), obj);
  else
    http_nt_write_obj (ses, env, qi, obj, obj_dtp, &tii.dt, DKS_ESC_TTL_DQ);
  SES_PRINT (ses, " .\n");
fail:
  dk_free_box (tii.s.uri);
  dk_free_box (tii.p.uri);
  dk_free_box (tii.o.uri);
  dk_free_box (tii.dt.uri);
  return (caddr_t)(ptrlong)(status);
}

caddr_t
bif_http_ttl_value (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *)qst;
  ttl_env_t *env = bif_ttl_env_arg (qst, args, 0, "http_ttl_value");
  caddr_t obj = bif_arg (qst, args, 1, "http_ttl_value");
  long pos = bif_long_arg (qst, args, 2, "http_ttl_value");
  dk_session_t *ses = http_session_no_catch_arg (qst, args, 3, "http_ttl_value");
  int obj_is_iri = 0;
  dtp_t obj_dtp = 0;
  ttl_iriref_items_t tii;
  caddr_t err = NULL;
  memset (&tii,0, sizeof (ttl_iriref_items_t));
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
      if (!(tii.o.is_bnode))
        {
          int cache_ok = ttl_try_to_cache_new_prefix (qst, ses, env, &(env->te_ns_count_s_o), &(tii.o));
          if (cache_ok)
            {
              err = srv_make_new_error ("22023", "SR601", "Argument 1 of http_ttl_value() needs a namespace declaration, use http_ttl_prefixes() in advance");
              goto fail;
            }
        }
    }
  else
    {
      if (2 != pos)
        sqlr_new_error ("22023", "SR601", "Argument 2 of http_ttl_value() is literal but not in object position");
      http_ttl_or_nt_prepare_obj (qi, obj, obj_dtp, &tii.dt);
      if (NULL != tii.dt.uri)
        {
          int cache_ok;
          iri_split_ttl_qname (tii.dt.uri, &(tii.dt.ns), &(tii.dt.loc), 1);
          cache_ok = ttl_try_to_cache_new_prefix (qst, ses, env, &(env->te_ns_count_p_dt), &(tii.dt));
          if (cache_ok)
            {
              err = srv_make_new_error ("22023", "SR601", "Argument 1 of http_ttl_value() needs a namespace declaration for the type of the literal, use http_ttl_prefixes() in advance");
              goto fail;
            }
        }
    }
  if (obj_is_iri)
    ttl_http_write_ref (ses, env, &(tii.o));
  else
    http_ttl_write_obj (ses, env, qi, obj, obj_dtp, &tii.dt);
fail:
  dk_free_box (tii.o.uri);	dk_free_box (tii.o.ns);		dk_free_box (tii.o.loc);	dk_free_box (tii.o.prefix);
  dk_free_box (tii.dt.uri);	dk_free_box (tii.dt.ns);	dk_free_box (tii.dt.loc);	dk_free_box (tii.dt.prefix);
  if (NULL != err)
    sqlr_resignal (err);
  return (caddr_t)((ptrlong)(0));
}

caddr_t
bif_http_nt_object (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *)qst;
  nt_env_t env;
  caddr_t obj = bif_arg (qst, args, 0, "http_nt_object");
  dk_session_t *ses = http_session_no_catch_arg (qst, args, 1, "http_nt_object");
  int status = 0;
  int obj_is_iri = 0;
  dtp_t obj_dtp = 0;
  ttl_iriref_items_t tii;
  memset (&tii,0, sizeof (ttl_iriref_items_t));
  env.ne_out_ses = ses;
  obj_dtp = DV_TYPE_OF (obj);
  switch (obj_dtp)
    {
    case DV_UNAME: case DV_IRI_ID: case DV_IRI_ID_8: obj_is_iri = 1; break;
    case DV_STRING: obj_is_iri = (BF_IRI & box_flags (obj)) ? 1 : 0; break;
    default: obj_is_iri = 0; break;
    }
  if (obj_is_iri)
    {
      if (!iri_cast_nt_absname (qi, obj, &tii.o.uri, &tii.o.is_bnode))
        goto fail; /* see below */
    }
  else
    {
      http_ttl_or_nt_prepare_obj (qi, obj, obj_dtp, &tii.dt);
    }
  if (obj_is_iri)
    nt_http_write_ref (ses, &env, &(tii.o), obj);
  else
    http_nt_write_obj (ses, &env, qi, obj, obj_dtp, &tii.dt, DKS_ESC_TTL_DQ);
fail:
  dk_free_box (tii.o.uri);
  dk_free_box (tii.dt.uri);
  return (caddr_t)(ptrlong)(status);
}

caddr_t
bif_http_nquad (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *)qst;
  nt_env_t *env = (nt_env_t *)bif_arg (qst, args, 0, "http_nquad");
  caddr_t subj = bif_arg (qst, args, 1, "http_nquad");
  caddr_t pred = bif_arg (qst, args, 2, "http_nquad");
  caddr_t obj = bif_arg (qst, args, 3, "http_nquad");
  caddr_t graph = bif_arg (qst, args, 4, "http_nquad");
  dk_session_t *ses = http_session_no_catch_arg (qst, args, 5, "http_nquad");
  int status = 0;
  int obj_is_iri = 0;
  dtp_t obj_dtp = 0;
  nq_iriref_items_t tii;
  memset (&tii,0, sizeof (nq_iriref_items_t));
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF ((caddr_t)env) ||
    (sizeof (nt_env_t) != box_length ((caddr_t)env)) )
    sqlr_new_error ("22023", "SR601", "Argument 1 of http_nt_triple() should be an array of special format");
  if (!iri_cast_nt_absname (qi, subj, &tii.s.uri, &tii.s.is_bnode))
    goto fail; /* see below */
  if (!iri_cast_nt_absname (qi, pred, &tii.p.uri, &tii.p.is_bnode))
    goto fail; /* see below */
  if (!iri_cast_nt_absname (qi, graph, &tii.g.uri, &tii.g.is_bnode))
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
      if (!iri_cast_nt_absname (qi, obj, &tii.o.uri, &tii.o.is_bnode))
        goto fail; /* see below */
    }
  else
    {
      http_ttl_or_nt_prepare_obj (qi, obj, obj_dtp, &tii.dt);
    }
  nt_http_write_ref (ses, env, &(tii.s), subj);
  session_buffered_write_char ('\t', ses);
  nt_http_write_ref (ses, env, &(tii.p), pred);
  session_buffered_write_char ('\t', ses);
  if (obj_is_iri)
    nt_http_write_ref (ses, env, &(tii.o), obj);
  else
    http_nt_write_obj (ses, env, qi, obj, obj_dtp, &tii.dt, DKS_ESC_TTL_DQ);
  session_buffered_write_char ('\t', ses);
  nt_http_write_ref (ses, env, &(tii.g), graph);
  SES_PRINT (ses, " .\n");
fail:
  dk_free_box (tii.s.uri);
  dk_free_box (tii.p.uri);
  dk_free_box (tii.o.uri);
  dk_free_box (tii.dt.uri);
  dk_free_box (tii.g.uri);
  return (caddr_t)(ptrlong)(status);
}

caddr_t
bif_http_rdf_object (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *)qst;
  nt_env_t env;
  caddr_t obj = bif_arg (qst, args, 0, "http_rdf_object");
  dk_session_t *ses = http_session_no_catch_arg (qst, args, 1, "http_rdf_object");
  int esc_mode = BOX_ELEMENTS (args) > 2 ? bif_long_arg (qst, args, 2, "http_rdf_object") : DKS_ESC_PTEXT;
  int status = 0;
  int obj_is_iri = 0;
  dtp_t obj_dtp = 0;
  ttl_iriref_items_t tii;
  memset (&tii,0, sizeof (ttl_iriref_items_t));
  env.ne_out_ses = ses;
  obj_dtp = DV_TYPE_OF (obj);
  switch (obj_dtp)
    {
    case DV_UNAME: case DV_IRI_ID: case DV_IRI_ID_8: obj_is_iri = 1; break;
    case DV_STRING: obj_is_iri = (BF_IRI & box_flags (obj)) ? 1 : 0; break;
    default: obj_is_iri = 0; break;
    }
  if (obj_is_iri)
    {
      if (!iri_cast_nt_absname (qi, obj, &tii.o.uri, &tii.o.is_bnode))
        goto fail; /* see below */
    }
  else
    {
      http_ttl_or_nt_prepare_obj (qi, obj, obj_dtp, &tii.dt);
    }
  if (obj_is_iri)
    nt_http_write_ref (ses, &env, &(tii.o), obj);
  else
    http_nt_write_obj (ses, &env, qi, obj, obj_dtp, &tii.dt, esc_mode);
fail:
  dk_free_box (tii.o.uri);
  dk_free_box (tii.dt.uri);
  return (caddr_t)(ptrlong)(status);
}

/*! Environment of Talis JSON serializer */
typedef struct talis_json_env_s {
  caddr_t tje_prev_subj;		/*!< Item 1 is the string value of previous subject. It is DV_STRING except the very beginning of the serialization when it can be of any type except DV_STRING (non-string will be freed and replaced with NULL pointer inside the printing procedure) */
  caddr_t tje_prev_pred;		/*!< Item 2 is the string value of previous subject predicate. */
  caddr_t *tje_colnames;		/*!< Item 3 is array of names of result set columns. */
  dk_session_t *tje_out_ses;		/*!< Item 4 is output session, used only for sparql_rset_json_write_row(). */
} talis_json_env_t;

int
iri_cast_talis_json_qname (query_instance_t *qi, caddr_t iri_or_id, caddr_t *iri_ret, int *iri_is_new_box_ret, int *is_bnode_ret)
{
  is_bnode_ret[0] = 0;
  switch (DV_TYPE_OF (iri_or_id))
    {
    case DV_STRING: case DV_UNAME:
      iri_ret[0] = iri_or_id;
      iri_is_new_box_ret[0] = 0;
      if (('_' == iri_or_id[0]) && (':' == iri_or_id[0]))
        {
          is_bnode_ret[0] = 1;
          return 1;
        }                    /* 0123456789 */
      if (!strncmp (iri_or_id, "nodeID://", 9))
        {
          iri_ret[0] = box_dv_short_strconcat ("_:v", iri_or_id + 9);
          iri_is_new_box_ret[0] = 1;
          is_bnode_ret[0] = 1;
          return 1;
        }
      is_bnode_ret[0] = 0;
      return 1;
    case DV_IRI_ID: case DV_IRI_ID_8:
      {
        iri_id_t iid = unbox_iri_id (iri_or_id);
        if (0L == iid)
          return 0;
        if (min_bnode_iri_id () <= iid)
          {
            is_bnode_ret[0] = 1;
            iri_is_new_box_ret[0] = 1;
            if (min_named_bnode_iri_id () > iid)
              iri_ret[0] = BNODE_IID_TO_TALIS_JSON_LABEL (iid);
            else
              iri_ret[0] = key_id_to_iri (qi, iid);
            return (NULL != iri_ret[0] && DV_DB_NULL != DV_TYPE_OF (iri_ret[0]));
          }
        is_bnode_ret[0] = 0;
        iri_is_new_box_ret[0] = 1;
        iri_ret[0] = key_id_to_iri (qi, iid);
        return (NULL != iri_ret[0] && DV_DB_NULL != DV_TYPE_OF (iri_ret[0]));
      }
    }
  return 0;
}



static void
http_talis_json_write_ref_obj (dk_session_t *ses, caddr_t obj_iri, int obj_is_bnode)
{
  if (obj_is_bnode)              /* 0           1            2           3  */
    {                            /* 01.23456.7890.123456.789.012345.6789.01 */
      session_buffered_write (ses, "{ \"type\" : \"bnode\", \"value\" : \"", 31);
      dks_esc_write (ses, obj_iri, box_length (obj_iri) - 1, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_JSWRITE_DQ);
                                 /* .0123 */
      session_buffered_write (ses, "\" }", 3);
    }
  else                           /* 0           1            2            */
    {                            /* 01.23456.7890.1234.567.890123.4567.89 */
      session_buffered_write (ses, "{ \"type\" : \"uri\", \"value\" : \"", 29);
      dks_esc_write (ses, obj_iri, box_length (obj_iri) - 1, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_JSWRITE_DQ);
                                 /* .0123 */
      session_buffered_write (ses, "\" }", 3);
    }
}

static void
http_talis_json_write_literal_obj (dk_session_t *ses, query_instance_t *qi, caddr_t obj, dtp_t obj_dtp)
{
  caddr_t obj_box_value;
  dtp_t obj_box_value_dtp;
  caddr_t type_uri = NULL;
  if (DV_RDF == obj_dtp)
    {
      rdf_box_t *rb = (rdf_box_t *)obj;
      if (!rb->rb_is_complete)
        rb_complete (rb, qi->qi_trx, qi);
      obj_box_value = rb->rb_box;
      obj_box_value_dtp = DV_TYPE_OF (obj_box_value);
      rb_dt_lang_check(rb);
      if (RDF_BOX_DEFAULT_TYPE != rb->rb_type)
        type_uri = rdf_type_twobyte_to_iri (rb->rb_type);
    }
  else
    {
      obj_box_value = obj;
      obj_box_value_dtp = obj_dtp;
    }
                             /* 0           1           2           3   */
                             /* 01.23456.7890.12345678.901.234567.89012 */
  session_buffered_write (ses, "{ \"type\" : \"literal\", \"value\" : ", 32);

  switch (obj_box_value_dtp)
    {
    case DV_DATETIME:
      {
        char temp [50];
        dt_to_iso8601_string (obj_box_value, temp, sizeof (temp));
        session_buffered_write_char ('\"', ses);
        session_buffered_write (ses, temp, strlen (temp));
        session_buffered_write_char ('\"', ses);
        if (NULL == type_uri)
          switch (DT_DT_TYPE(obj_box_value))
            {
            case DT_TYPE_DATE: type_uri = uname_xmlschema_ns_uri_hash_date; break;
            case DT_TYPE_TIME: type_uri = uname_xmlschema_ns_uri_hash_time; break;
            default : type_uri = uname_xmlschema_ns_uri_hash_dateTime; break;
            }
        break;
      }
    case DV_STRING:
      session_buffered_write_char ('\"', ses);
      dks_esc_write (ses, obj_box_value, box_length (obj_box_value) - 1, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_JSWRITE_DQ);
      session_buffered_write_char ('\"', ses);
      break;
    case DV_WIDE:
      session_buffered_write_char ('\"', ses);
      dks_esc_write (ses, obj_box_value, box_length (obj_box_value) - sizeof (wchar_t), CHARSET_UTF8, CHARSET_WIDE, DKS_ESC_JSWRITE_DQ);
      session_buffered_write_char ('\"', ses);
      break;
    case DV_XML_ENTITY:
      {
        http_json_write_xe (ses, qi, (xml_entity_t *)(obj_box_value));
        if (NULL == type_uri)
          type_uri = uname_rdf_ns_uri_XMLLiteral;
        break;
      }
    case DV_DB_NULL:
      session_buffered_write (ses, "(NULL)", 6);
      break;
    default:
      {
        caddr_t tmp_utf8_box = box_cast_to_UTF8 ((caddr_t *)qi, obj_box_value);
        if (DV_RDF == obj_dtp)
          session_buffered_write_char ('\"', ses);
        session_buffered_write (ses, tmp_utf8_box, box_length (tmp_utf8_box) - 1);
        if (DV_RDF == obj_dtp)
          session_buffered_write_char ('\"', ses);
        dk_free_box (tmp_utf8_box);
        if (NULL == type_uri)
          type_uri = xsd_type_of_box (obj_box_value);
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
            {                            /* 012.34567.8901.23 */
              session_buffered_write (ses, " , \"lang\" : \"", 13);
                dks_esc_write (ses, lang_id, box_length (lang_id) - 1, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_JSWRITE_DQ);
              session_buffered_write_char ('\"', ses);
	      dk_free_box (lang_id);
            }
        }
    }
  if (NULL != type_uri)
    {
      if (!IS_BOX_POINTER (type_uri))
        sqlr_new_error ("22023", "SR625", "Unsupported datatype %d in TALIS-style JSON serialization of an RDF object", obj_dtp);
                                 /* 012.345678901.2345.67 */
      session_buffered_write (ses, " , \"datatype\" : \"", 17);
      dks_esc_write (ses, type_uri, box_length (type_uri) - 1, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_JSWRITE_DQ);
      session_buffered_write_char ('\"', ses);
      dk_free_box (type_uri);
    }
  session_buffered_write (ses, " }", 2);
}

caddr_t
bif_http_talis_json_triple (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *)qst;
  talis_json_env_t *env = (talis_json_env_t *)bif_arg (qst, args, 0, "http_talis_json_triple");
  caddr_t subj_iri_or_id = bif_arg (qst, args, 1, "http_talis_json_triple");
  caddr_t pred_iri_or_id = bif_arg (qst, args, 2, "http_talis_json_triple");
  caddr_t obj = bif_arg (qst, args, 3, "http_talis_json_triple");
  dk_session_t *ses = http_session_no_catch_arg (qst, args, 4, "http_talis_json_triple");
  int status = 0;
  int obj_is_iri = 0;
  dtp_t obj_dtp = 0;
  caddr_t subj_iri = NULL, pred_iri = NULL, obj_iri = NULL;
  int subj_iri_is_new = 0, pred_iri_is_new = 0, obj_iri_is_new = 0;
  int is_bnode, obj_is_bnode;
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF ((caddr_t)env) ||
    (sizeof (talis_json_env_t) != box_length ((caddr_t)env)) ||
    ((DV_STRING == DV_TYPE_OF (env->tje_prev_subj)) && (DV_STRING != DV_TYPE_OF (env->tje_prev_pred))) )
    sqlr_new_error ("22023", "SR607", "Argument 1 of http_talis_json_triple() should be an array of special format");
  if (!iri_cast_talis_json_qname (qi, subj_iri_or_id, &subj_iri, &subj_iri_is_new, &is_bnode /* never used after return */))
    goto fail; /* see below */
  if (!iri_cast_talis_json_qname (qi, pred_iri_or_id, &pred_iri, &pred_iri_is_new, &is_bnode /* never used after return */))
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
      if (!iri_cast_talis_json_qname (qi, obj, &obj_iri, &obj_iri_is_new, &obj_is_bnode /* used ;) */))
        goto fail; /* see below */
    }
  if ((DV_STRING != DV_TYPE_OF (env->tje_prev_subj)) && (DV_UNAME != DV_TYPE_OF (env->tje_prev_subj)))
    {
      dk_free_tree (env->tje_prev_subj);	env->tje_prev_subj = NULL;
      dk_free_tree (env->tje_prev_pred);	env->tje_prev_pred = NULL;
    }
  if ((NULL == env->tje_prev_subj) || strcmp (env->tje_prev_subj, subj_iri))
    {
      if (NULL != env->tje_prev_pred)
        {                            /* 012345.6789 */
          session_buffered_write (ses, " ] } ,\n  ", 9);
          dk_free_tree (env->tje_prev_subj);	env->tje_prev_subj = NULL;
          dk_free_tree (env->tje_prev_pred);	env->tje_prev_pred = NULL;
        }
      session_buffered_write_char ('\"', ses);
      dks_esc_write (ses, subj_iri, box_length (subj_iri) - 1, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_JSWRITE_DQ);
                                 /* .0123456 */
      session_buffered_write (ses, "\" : { ", 6);
      env->tje_prev_subj = subj_iri_is_new ? subj_iri : box_copy (subj_iri); subj_iri_is_new = 0;
    }
  if ((NULL == env->tje_prev_pred) || strcmp (env->tje_prev_pred, pred_iri))
    {
      if (NULL != env->tje_prev_pred)
        {                            /* 0123.456789 */
          session_buffered_write (ses, " ] ,\n    ", 9);
          dk_free_tree (env->tje_prev_pred);	env->tje_prev_pred = NULL;
        }
      session_buffered_write_char ('\"', ses);
      dks_esc_write (ses, pred_iri, box_length (pred_iri) - 1, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_JSWRITE_DQ);
                                 /* .0123456 */
      session_buffered_write (ses, "\" : [ ", 6);
      env->tje_prev_pred = pred_iri_is_new ? pred_iri : box_copy (pred_iri); pred_iri_is_new = 0;
    }
  else                         /* 01.23456789 */
    session_buffered_write (ses, " ,\n      ", 9);
  if (obj_is_iri)
    http_talis_json_write_ref_obj (ses, obj_iri, obj_is_bnode);
  else
    http_talis_json_write_literal_obj (ses, qi, obj, obj_dtp);
  status = 1;
fail:
  if (subj_iri_is_new) dk_free_box (subj_iri);
  if (pred_iri_is_new) dk_free_box (pred_iri);
  if (obj_iri_is_new) dk_free_box (obj_iri);
  return (caddr_t)((ptrlong)status);
}

#define ld_json_env_t talis_json_env_t
#define iri_cast_ld_json_qname iri_cast_talis_json_qname

static void
http_ld_json_write_literal_obj (dk_session_t *ses, query_instance_t *qi, caddr_t obj, dtp_t obj_dtp)
{
  caddr_t obj_box_value;
  dtp_t obj_box_value_dtp;
  caddr_t type_uri = NULL;
  if (DV_RDF == obj_dtp)
    {
      rdf_box_t *rb = (rdf_box_t *)obj;
      if (!rb->rb_is_complete)
        rb_complete (rb, qi->qi_trx, qi);
      obj_box_value = rb->rb_box;
      obj_box_value_dtp = DV_TYPE_OF (obj_box_value);
      rb_dt_lang_check(rb);
      if (RDF_BOX_DEFAULT_TYPE != rb->rb_type)
        type_uri = rdf_type_twobyte_to_iri (rb->rb_type);
    }
  else
    {
      obj_box_value = obj;
      obj_box_value_dtp = obj_dtp;
      switch (obj_box_value_dtp)
        {
        case DV_LONG_INT:
        case DV_DOUBLE_PREC:
          {
            caddr_t tmp_utf8_box = box_cast_to_UTF8 ((caddr_t *)qi, obj_box_value);
            session_buffered_write (ses, tmp_utf8_box, box_length (tmp_utf8_box) - 1);
            return;
          }
        }
    }
  if ((NULL != type_uri) && !strcmp (type_uri, uname_xmlschema_ns_uri_hash_boolean) && (DV_LONG_INT == obj_box_value_dtp))
    {
      if (unbox (obj_box_value))
        session_buffered_write (ses, "true", 4);
      else
        session_buffered_write (ses, "false", 5);
      dk_free_box (type_uri);
      return;
    }
                             /* 0          1     */
                             /* 01.2345678.90123 */
  session_buffered_write (ses, "{ \"@value\" : ", 13);
  switch (obj_box_value_dtp)
    {
    case DV_DATETIME:
      {
        char temp [50];
        dt_to_iso8601_string (obj_box_value, temp, sizeof (temp));
        session_buffered_write_char ('\"', ses);
        session_buffered_write (ses, temp, strlen (temp));
        session_buffered_write_char ('\"', ses);
        if (NULL == type_uri)
          switch (DT_DT_TYPE(obj_box_value))
            {
            case DT_TYPE_DATE: type_uri = uname_xmlschema_ns_uri_hash_date; break;
            case DT_TYPE_TIME: type_uri = uname_xmlschema_ns_uri_hash_time; break;
            default : type_uri = uname_xmlschema_ns_uri_hash_dateTime; break;
            }
        break;
      }
    case DV_STRING:
      session_buffered_write_char ('\"', ses);
      dks_esc_write (ses, obj_box_value, box_length (obj_box_value) - 1, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_JSWRITE_DQ);
      session_buffered_write_char ('\"', ses);
      break;
    case DV_WIDE:
      session_buffered_write_char ('\"', ses);
      dks_esc_write (ses, obj_box_value, box_length (obj_box_value) - sizeof (wchar_t), CHARSET_UTF8, CHARSET_WIDE, DKS_ESC_JSWRITE_DQ);
      session_buffered_write_char ('\"', ses);
      break;
    case DV_XML_ENTITY:
      {
        http_json_write_xe (ses, qi, (xml_entity_t *)(obj_box_value));
        if (NULL == type_uri)
          type_uri = uname_rdf_ns_uri_XMLLiteral;
        break;
      }
    case DV_DB_NULL:
      session_buffered_write (ses, "(NULL)", 6);
      break;
    default:
      {
        caddr_t tmp_utf8_box = box_cast_to_UTF8 ((caddr_t *)qi, obj_box_value);
        if (DV_RDF == obj_dtp)
          session_buffered_write_char ('\"', ses);
        session_buffered_write (ses, tmp_utf8_box, box_length (tmp_utf8_box) - 1);
        if (DV_RDF == obj_dtp)
          session_buffered_write_char ('\"', ses);
        dk_free_box (tmp_utf8_box);
        if (NULL == type_uri)
          type_uri = xsd_type_of_box (obj_box_value);
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
                                         /* 0          1           */
            {                            /* 012.3456789012.3456.78 */
              session_buffered_write (ses, " , \"@language\" : \"", 18);
              lang_id = rdf_lang_twobyte_to_string (((rdf_box_t *)obj)->rb_lang);
              if (NULL != lang_id)
                dks_esc_write (ses, lang_id, box_length (lang_id) - 1, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_JSWRITE_DQ);
              session_buffered_write_char ('\"', ses);
            }
        }
    }
  if (NULL != type_uri)
    {
      if (!IS_BOX_POINTER (type_uri))
        sqlr_new_error ("22023", "SR625", "Unsupported datatype %d in LD-style JSON serialization of an RDF object", obj_dtp);
                                 /* 0           1      */
                                 /* 012.345678.9012.34 */
      session_buffered_write (ses, " , \"@type\" : \"", 14);
      dks_esc_write (ses, type_uri, box_length (type_uri) - 1, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_JSWRITE_DQ);
      session_buffered_write_char ('\"', ses);
      dk_free_box (type_uri);
    }
  session_buffered_write (ses, " }", 2);
}

caddr_t
bif_http_ld_json_triple (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *)qst;
  ld_json_env_t *env = (ld_json_env_t *)bif_arg (qst, args, 0, "http_ld_json_triple");
  caddr_t subj_iri_or_id = bif_arg (qst, args, 1, "http_ld_json_triple");
  caddr_t pred_iri_or_id = bif_arg (qst, args, 2, "http_ld_json_triple");
  caddr_t obj = bif_arg (qst, args, 3, "http_ld_json_triple");
  dk_session_t *ses = http_session_no_catch_arg (qst, args, 4, "http_ld_json_triple");
  int status = 0;
  int obj_is_iri = 0;
  dtp_t obj_dtp = 0;
  caddr_t subj_iri = NULL, pred_iri = NULL, obj_iri = NULL;
  int subj_iri_is_new = 0, pred_iri_is_new = 0, obj_iri_is_new = 0;
  int is_bnode, obj_is_bnode;
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF ((caddr_t)env) ||
    (sizeof (ld_json_env_t) != box_length ((caddr_t)env)) ||
    ((DV_STRING == DV_TYPE_OF (env->tje_prev_subj)) && (DV_STRING != DV_TYPE_OF (env->tje_prev_pred))) )
    sqlr_new_error ("22023", "SR607", "Argument 1 of http_ld_json_triple() should be an array of special format");
  if (!iri_cast_ld_json_qname (qi, subj_iri_or_id, &subj_iri, &subj_iri_is_new, &is_bnode /* never used after return */))
    goto fail; /* see below */
  if (!iri_cast_ld_json_qname (qi, pred_iri_or_id, &pred_iri, &pred_iri_is_new, &is_bnode /* never used after return */))
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
      if (!iri_cast_ld_json_qname (qi, obj, &obj_iri, &obj_iri_is_new, &obj_is_bnode /* used ;) */))
        goto fail; /* see below */
    }
  if ((DV_STRING != DV_TYPE_OF (env->tje_prev_subj)) && (DV_UNAME != DV_TYPE_OF (env->tje_prev_subj)))
    {
      dk_free_tree (env->tje_prev_subj);	env->tje_prev_subj = NULL;
      dk_free_tree (env->tje_prev_pred);	env->tje_prev_pred = NULL;
    }
  if ((NULL == env->tje_prev_subj) || strcmp (env->tje_prev_subj, subj_iri))
    {
      if (NULL != env->tje_prev_pred)
        {                            /* 012345.678901 */
          session_buffered_write (ses, " ] } ,\n    ", 11);
          dk_free_tree (env->tje_prev_subj);	env->tje_prev_subj = NULL;
          dk_free_tree (env->tje_prev_pred);	env->tje_prev_pred = NULL;
        }
                                 /* 01.2345.678.90 */
      session_buffered_write (ses, "{ \"@id\": \"", 10);
      dks_esc_write (ses, subj_iri, box_length (subj_iri) - 1, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_JSWRITE_DQ);
                                 /* .01.23456789 */
      session_buffered_write (ses, "\",\n      ", 9);
      env->tje_prev_subj = subj_iri_is_new ? subj_iri : box_copy (subj_iri); subj_iri_is_new = 0;
    }
  if ((NULL == env->tje_prev_pred) || strcmp (env->tje_prev_pred, pred_iri))
    {
      if (NULL != env->tje_prev_pred)
        {                            /* 0123.45678901 */
          session_buffered_write (ses, " ] ,\n      ", 11);
          dk_free_tree (env->tje_prev_pred);	env->tje_prev_pred = NULL;
        }
      session_buffered_write_char ('\"', ses);
      if (!strcmp (pred_iri, uname_rdf_ns_uri_type))
        session_buffered_write (ses, "@type", 5);
      else
        dks_esc_write (ses, pred_iri, box_length (pred_iri) - 1, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_JSWRITE_DQ);
                                 /* .0123456 */
      session_buffered_write (ses, "\" : [ ", 6);
      env->tje_prev_pred = pred_iri_is_new ? pred_iri : box_copy (pred_iri); pred_iri_is_new = 0;
    }
  else                         /* 01.2345678901 */
    session_buffered_write (ses, " ,\n        ", 11);
  if (obj_is_iri)
    {
      session_buffered_write_char ('\"', ses);
      dks_esc_write (ses, obj_iri, box_length (obj_iri) - 1, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_JSWRITE_DQ);
      session_buffered_write_char ('\"', ses);
    }
  else
    http_ld_json_write_literal_obj (ses, qi, obj, obj_dtp);
  status = 1;
fail:
  if (subj_iri_is_new) dk_free_box (subj_iri);
  if (pred_iri_is_new) dk_free_box (pred_iri);
  if (obj_iri_is_new) dk_free_box (obj_iri);
  return (caddr_t)((ptrlong)status);
}


caddr_t
bif_sparql_rset_ttl_write_row (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *)qst;
  ttl_env_t *env = bif_ttl_env_arg (qst, args, 1, "sparql_rset_ttl_write_row");
  caddr_t *row = (caddr_t *)bif_arg (qst, args, 2, "sparql_rset_ttl_write_row");
  dk_session_t *ses;
  int colctr, colcount, need_semicolon;
  ses = env->te_out_ses;
  if (DV_DB_NULL == DV_TYPE_OF (ses))
    ses = bif_strses_or_http_ses_arg (qst, args, 0, "sparql_rset_ttl_write_row");
  else if (DV_LONG_INT == DV_TYPE_OF (ses))
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
        {
          http_ttl_or_nt_prepare_obj (qi, obj, obj_dtp, col_ti);
          if (NULL != col_ti->uri)
            iri_split_ttl_qname (col_ti->uri, &(col_ti->ns), &(col_ti->loc), 1);
        }
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
bif_sparql_rset_nt_write_row (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *)qst;
  nt_env_t *env = (nt_env_t *)bif_arg (qst, args, 1, "sparql_rset_nt_write_row");
  caddr_t *row = (caddr_t *)bif_arg (qst, args, 2, "sparql_rset_nt_write_row");
  dk_session_t *ses;
  int rowctr, colctr, colcount;
  char rowid_label[40], colid_label[50];
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF ((caddr_t)env) ||
    (sizeof (nt_env_t) != box_length ((caddr_t)env)) ||
    (DV_LONG_INT != DV_TYPE_OF (env->ne_rowctr)) ||
    ((DV_LONG_INT != DV_TYPE_OF (env->ne_out_ses)) && (DV_STRING_SESSION != DV_TYPE_OF (env->ne_out_ses)) && (DV_DB_NULL != DV_TYPE_OF (env->ne_out_ses))) ||
    (DV_ARRAY_OF_POINTER != DV_TYPE_OF ((caddr_t)(env->ne_cols))) ||
    (box_length ((caddr_t)(env->ne_cols)) % sizeof (ttl_iriref_t)) )
    sqlr_new_error ("22023", "SR605", "Argument 2 of sparql_rset_nt_write_row() should be an array of special format");
  ses = env->ne_out_ses;
  if (DV_DB_NULL == DV_TYPE_OF (ses))
    ses = bif_strses_or_http_ses_arg (qst, args, 0, "sparql_rset_nt_write_row");
  else if (DV_LONG_INT == DV_TYPE_OF (ses))
    {
      ses = qi->qi_client->cli_http_ses; /*(dk_session_t *)((ptrlong)(unbox ((caddr_t)ses)));*/
      if (!ses)
	sqlr_new_error ("37000", "HT081",
	    "Function sparql_rset_nt_write_row() outside of HTTP context and no stream specified");
    }
  rowctr = unbox (env->ne_rowctr);
  sprintf (rowid_label, "_:ResultSet2053r%d", rowctr);
  dk_free_box (env->ne_rowctr);
  env->ne_rowctr = box_num (rowctr+1);
  colcount = box_length ((caddr_t)(env->ne_cols)) / sizeof (ttl_iriref_t);
  if ((DV_ARRAY_OF_POINTER != DV_TYPE_OF (row)) || (BOX_ELEMENTS (row) != colcount))
    sqlr_new_error ("22023", "SR606", "Argument 3 of sparql_rset_nt_write_row() should be an array of values and length should match to the argument 2");
  for (colctr = 0; colctr < colcount; colctr++)
    {
      ttl_iriref_t *col_ti = env->ne_cols + colctr;
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
        {
          /* iri_is_ok = */ iri_cast_nt_absname (qi, obj, &(col_ti->uri), &(col_ti->is_bnode));
          if (col_ti->loc == obj)
            col_ti->loc = NULL; /* If obj is used unchanged so there was no memory allocation then col_ti->uri is unused in order to avoid double free at signalled error. */
        }
      else
        http_ttl_or_nt_prepare_obj (qi, obj, obj_dtp, col_ti);
    }
  SES_PRINT (ses, "_:ResultSet2053 <http://www.w3.org/2005/sparql-results#solution> "); SES_PRINT (ses, rowid_label); SES_PRINT (ses, " .\n");
  for (colctr = 0; colctr < colcount; colctr++)
    {
      ttl_iriref_t *col_ti = env->ne_cols + colctr;
      caddr_t obj = row[colctr];
      dtp_t obj_dtp = DV_TYPE_OF (obj);
      if (DV_DB_NULL == obj_dtp)
        continue;
      sprintf (colid_label, "%sc%d", rowid_label, colctr);
      SES_PRINT (ses, rowid_label); SES_PRINT (ses, " <http://www.w3.org/2005/sparql-results#binding> "); SES_PRINT (ses, colid_label); SES_PRINT (ses, " .\n");
      SES_PRINT (ses, colid_label); SES_PRINT (ses, " <http://www.w3.org/2005/sparql-results#variable> \""); dks_esc_write (ses, col_ti->colname, strlen (col_ti->colname), CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_TTL_DQ); SES_PRINT (ses, "\" .\n");
      SES_PRINT (ses, colid_label); SES_PRINT (ses, " <http://www.w3.org/2005/sparql-results#value> ");
      if (col_ti->is_iri)
        nt_http_write_ref (ses, env, col_ti, obj);
      else
        http_nt_write_obj (ses, env, qi, obj, obj_dtp, col_ti, DKS_ESC_TTL_DQ);
      SES_PRINT (ses, " .\n");
      dk_free_box (col_ti->uri); col_ti->uri = NULL;
    }
  return NULL;
}

caddr_t
bif_sparql_rset_json_write_row (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *)qst;
  talis_json_env_t *env = (talis_json_env_t *)bif_arg (qst, args, 1, "sparql_rset_json_write_row");
  caddr_t *row = (caddr_t *)bif_arg (qst, args, 2, "sparql_rset_json_write_row");
  dk_session_t *ses;
  int colctr, colcount, need_comma = 0;
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF ((caddr_t)env) ||
    (sizeof (talis_json_env_t) != box_length ((caddr_t)env)) ||
    ((DV_LONG_INT != DV_TYPE_OF (env->tje_out_ses)) && (DV_STRING_SESSION != DV_TYPE_OF (env->tje_out_ses)) && (DV_DB_NULL != DV_TYPE_OF (env->tje_out_ses))) ||
    (DV_ARRAY_OF_POINTER != DV_TYPE_OF ((caddr_t)(env->tje_colnames))) )
    sqlr_new_error ("22023", "SR623", "Argument 2 of sparql_rset_json_write_row() should be an array of special format");
  ses = env->tje_out_ses;
  if (DV_DB_NULL == DV_TYPE_OF (ses))
    ses = bif_strses_or_http_ses_arg (qst, args, 0, "sparql_rset_json_write_row");
  else if (DV_LONG_INT == DV_TYPE_OF (ses))
    {
      ses = qi->qi_client->cli_http_ses; /*(dk_session_t *)((ptrlong)(unbox ((caddr_t)ses)));*/
      if (!ses)
	sqlr_new_error ("37000", "HT081",
	    "Function sparql_rset_json_write_row() outside of HTTP context and no stream specified");
    }
  colcount = BOX_ELEMENTS ((caddr_t)(env->tje_colnames));
  if ((DV_ARRAY_OF_POINTER != DV_TYPE_OF (row)) || (BOX_ELEMENTS (row) != colcount))
    sqlr_new_error ("22023", "SR606", "Argument 3 of sparql_rset_json_write_row() should be an array of values and length should match to the argument 2");
  for (colctr = 0; colctr < colcount; colctr++)
    {
      caddr_t colname = env->tje_colnames[colctr];
      caddr_t obj = row[colctr], obj_iri = NULL;
      dtp_t obj_dtp = DV_TYPE_OF (obj);
      int obj_is_iri, iri_is_ok, obj_is_bnode = 0, obj_iri_is_new = 0;
      switch (obj_dtp)
        {
        case DV_DB_NULL: continue;
        case DV_UNAME: case DV_IRI_ID: case DV_IRI_ID_8: obj_is_iri = 1; break;
        case DV_STRING: obj_is_iri = (BF_IRI & box_flags (obj)) ? 1 : 0; break;
        default: obj_is_iri = 0; break;
        }
      if (obj_is_iri)
        {
          iri_is_ok = iri_cast_talis_json_qname (qi, obj, &obj_iri, &obj_iri_is_new, &obj_iri_is_new);
          if (!iri_is_ok)
            continue;
        }
      if (need_comma)
        SES_PRINT (ses, "\t, \"");
      else
        SES_PRINT (ses, "\n    { \"");
      need_comma = 1;
      dks_esc_write (ses, colname, strlen (colname), CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_TTL_DQ); SES_PRINT (ses, "\": ");
      if (obj_is_iri)
        http_talis_json_write_ref_obj (ses, obj_iri, obj_is_bnode);
      else
        http_talis_json_write_literal_obj (ses, qi, obj, obj_dtp);
      if (obj_iri_is_new)
        dk_free_box (obj_iri);
    }
  if (!need_comma)
    SES_PRINT (ses, " { ");
  SES_PRINT (ses, "}");
  return NULL;
}

void
sparql_rset_xml_write_row_impl (query_instance_t *qi, dk_session_t *ses, caddr_t *colnames, caddr_t *row)
{
  int colctr, colcount;
  colcount = BOX_ELEMENTS (colnames);
  SES_PRINT (ses, "\n  <result>");
  for (colctr = 0; colctr < colcount; colctr++)
    {
      caddr_t name = colnames [colctr];
      caddr_t val = row [colctr];
      dtp_t val_dtp = DV_TYPE_OF (val);
      if (DV_DB_NULL == val_dtp)
        continue;
      if (DV_STRING != DV_TYPE_OF (name))
        sqlr_new_error ("22023", "SR604", "Argument 2 of sparql_rset_xml_write_row() should be an array of strings and only strings");
      SES_PRINT (ses, "\n   <binding name=\"");
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
                        snprintf (buf, sizeof (buf), "bad://" IIDBOXINT_FMT, (boxint)(ptrlong)iri);
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
                    snprintf (buf, sizeof (buf), "bad://" IIDBOXINT_FMT, (boxint)(ptrlong)iri);
                    SES_PRINT (ses, buf);
                  }
                else
                  dks_esc_write (ses, iri, box_length_inline (iri)-1, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_PTEXT);
                SES_PRINT (ses, "</uri>");
              }
            break;
          }
        case DV_WIDE:
          {
            SES_PRINT (ses, "<literal>");
            dks_esc_write (ses, val, box_length_inline (val) - sizeof (wchar_t), CHARSET_UTF8, CHARSET_WIDE, DKS_ESC_PTEXT);
            SES_PRINT (ses, "</literal>");
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
            rb_dt_lang_check(rb);
            if (RDF_BOX_DEFAULT_TYPE != rb->rb_type)
              {
                caddr_t iri = rdf_type_twobyte_to_iri (rb->rb_type);
                if (NULL != iri)
                  {
                    SES_PRINT (ses, "<literal datatype=\"");
                    dks_esc_write (ses, iri, box_length_inline (iri)-1, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_SQATTR);
                    SES_PRINT (ses, "\">");
                    dk_free_box (iri);
                    goto literal_elt_printed; /* see below */
                  }
                else
                  SES_PRINT (ses, "<literal><!-- bad datatype ID -->");
              }
            else if (RDF_BOX_DEFAULT_LANG != rb->rb_lang)
              {
                caddr_t l = rdf_lang_twobyte_to_string (rb->rb_lang);
                if (NULL != l)
                  {
                    SES_PRINT (ses, "<literal xml:lang=\"");
                    dks_esc_write (ses, l, box_length_inline (l)-1, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_SQATTR);
                    SES_PRINT (ses, "\">");
                    dk_free_box (l);
                    goto literal_elt_printed; /* see below */
                  }
                else
                  SES_PRINT (ses, "<literal><!-- bad language ID -->");
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
              dks_sqlval_esc_write ((caddr_t *)qi, ses, rb->rb_box, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_PTEXT);
            SES_PRINT (ses, "</literal>");
            break;
          }
        default:
          {
            caddr_t iri = xsd_type_of_box (val);
            if (IS_BOX_POINTER (iri))
              {
                SES_PRINT (ses, "<literal datatype=\"");
                dks_esc_write (ses, iri, box_length_inline (iri)-1, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_SQATTR);
                SES_PRINT (ses, "\">");
                dk_free_box (iri);
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
              dks_sqlval_esc_write ((caddr_t *) qi, ses, val, CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_PTEXT);
            SES_PRINT (ses, "</literal>");
          }
        }
      SES_PRINT (ses, "</binding>");
    }
  SES_PRINT (ses, "\n  </result>");
}

caddr_t
bif_sparql_rset_xml_write_row (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *)qst;
  dk_session_t *ses = http_session_no_catch_arg (qst, args, 0, "sparql_rset_xml_write_row");
  caddr_t *colnames = (caddr_t *)bif_arg (qst, args, 1, "sparql_rset_xml_write_row");
  caddr_t *row = (caddr_t *)bif_arg (qst, args, 2, "sparql_rset_xml_write_row");
  int colcount;
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (colnames))
    sqlr_new_error ("22023", "SR602", "Argument 2 of sparql_rset_xml_write_row() should be an array of strings (variable names)");
  colcount = BOX_ELEMENTS (colnames);
  if ((DV_ARRAY_OF_POINTER != DV_TYPE_OF (row)) || (BOX_ELEMENTS (row) != colcount))
    sqlr_new_error ("22023", "SR603", "Argument 3 of sparql_rset_xml_write_row() should be an array of values and length should match to the argument 2");
  sparql_rset_xml_write_row_impl (qi, ses, colnames, row);
  return NULL;
}

caddr_t
bif_sparql_dict_xml_write_row (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *)qst;
  dk_session_t *ses = http_session_no_catch_arg (qst, args, 0, "sparql_dict_xml_write_row");
  caddr_t *row = (caddr_t *)bif_arg (qst, args, 1, "sparql_dict_xml_write_row");
  static caddr_t *colnames = NULL;
  if (NULL == colnames)
    colnames = (caddr_t *)list (3, box_dv_short_string ("S"), box_dv_short_string ("P"), box_dv_short_string ("O"));
  if ((DV_ARRAY_OF_POINTER != DV_TYPE_OF (row)) || (BOX_ELEMENTS (row) != 3))
    sqlr_new_error ("22023", "SR603", "Argument 2 of sparql_dict_xml_write_row() should be a triple as an array of 3 values");
  sparql_rset_xml_write_row_impl (qi, ses, colnames, row);
  return NULL;
}


caddr_t
bif_sparql_iri_split_rdfa_qname (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t raw_iri = bif_arg (qst, args, 0, "sparql_iri_split_rdfa_qname");
  caddr_t iri;
  id_hash_iterator_t *ns_uri_to_pref = bif_dict_iterator_or_null_arg (qst, args, 1, "sparql_iri_split_rdfa_qname", 0);
  id_hash_t *ht;
  int flags = bif_long_arg (qst, args, 2, "sparql_iri_split_rdfa_qname");
  const char *tail;
  int iri_strlen;
  caddr_t ns_iri, prefix, *prefix_ptr, res = NULL, to_free = NULL;
  switch (DV_TYPE_OF (raw_iri))
    {
      case DV_IRI_ID:
        {
          iri_id_t iid = unbox_iri_int64 (raw_iri);
          if (iid >= min_bnode_iri_id())
            {
              if (flags & 0x2)
                return list (3, box_dv_short_string ("_"), NULL, BNODE_IID_TO_TTL_LABEL_LOCAL (iid));
              return NULL;
            }
          iri = key_id_to_iri ((query_instance_t *)qst, iid);
          if (!iri)
            return NEW_DB_NULL;
          break;
        }
        iri = raw_iri;
        break;
      case DV_STRING:
        if (!(BF_IRI & box_flags (raw_iri)))
          return NULL;
        /* no break */
      case DV_UNAME:
        if (!memcmp (raw_iri, "nodeID://", 9))
          return (flags & 0x2) ? list (3, box_dv_short_string ("_"), NULL, box_dv_short_strconcat ("v", raw_iri+9)) : NULL;
        iri = raw_iri;
        break;
      default: return NULL;
    }
  ht = ns_uri_to_pref->hit_hash;
  iri_strlen = strlen (iri);
  for (tail = iri + iri_strlen; tail > iri; tail--)
    {
      unsigned char c = (unsigned char) tail[-1];
      if (!isalnum(c) && ('_' != c) && ('-' != c) && !(c & 0x80))
        break;
    }
  do {
      if (tail == iri)
        {
          res = (flags & 0x2) ? list (3, NULL, box_dv_short_string (""), box_dv_short_nchars (iri, iri_strlen)) : NULL;
          break;
        }
      if (tail > iri && tail[-1] == '%' && (tail <= (iri + iri_strlen - 2)))
        tail += 2;
      to_free = ns_iri = box_dv_short_nchars (iri, tail-iri);
      prefix_ptr = (caddr_t *)id_hash_get (ht, (caddr_t)(&ns_iri));
      if (NULL != prefix_ptr)
        {
          res = (flags & 0x2) ? list (3, box_copy (prefix_ptr[0]), box_copy (ns_iri), box_dv_short_nchars (tail, iri + iri_strlen - tail)) : NULL;
          break;
        }
      prefix = xml_get_cli_or_global_ns_prefix (qst, ns_iri, 0xff);
      if (NULL != prefix)
        {
          if (('n' == prefix[0]) && isdigit (prefix[1]))
            {
              dk_free_box (prefix);
              prefix = NULL;
            }
          else
            {
              if (flags & 0x1)
                {
                  id_hash_set (ht, (caddr_t)(&ns_iri), (caddr_t)(&prefix));
                  to_free = NULL; /* to be released when hash table is free */
                }
              res = (flags & 0x2) ? list (3, box_copy (prefix), box_copy (ns_iri), box_dv_short_nchars (tail, iri + iri_strlen - tail)) : NULL;
              break;
            }
        }
      if (flags & 0x1)
        {
          char buf[10];
          sprintf (buf, "n%ld", (long)(ht->ht_count));
          prefix = box_dv_short_string (buf);
          id_hash_set (ht, (caddr_t)(&ns_iri), (caddr_t)(&prefix));
          to_free = NULL; /* to be released when hash table is free */
          break;
        }
      res = (flags & 0x2) ? list (3, NULL, box_copy (ns_iri), box_dv_short_nchars (tail, iri + iri_strlen - tail)) : NULL;
      break;
    } while (0);
res_done:
  if (iri != raw_iri)
    dk_free_tree (iri);
  if (to_free)
    dk_free_box (to_free);
  return res;
}

id_hash_iterator_t *rdf_graph_iri2id_dict_hit;
id_hash_t *rdf_graph_iri2id_dict_htable;

id_hash_iterator_t *rdf_graph_id2iri_dict_hit;
id_hash_t *rdf_graph_id2iri_dict_htable;

id_hash_iterator_t *rdf_graph_group_dict_hit;
id_hash_t *rdf_graph_group_dict_htable;

id_hash_iterator_t *rdf_graph_public_perms_dict_hit;
id_hash_t *rdf_graph_public_perms_dict_htable;

id_hash_iterator_t *rdf_graph_group_of_privates_dict_hit;
id_hash_t *rdf_graph_group_of_privates_dict_htable;

id_hash_iterator_t *rdf_graph_default_world_perms_of_user_dict_hit;
id_hash_t *rdf_graph_default_world_perms_of_user_dict_htable;

id_hash_iterator_t *rdf_graph_default_private_perms_of_user_dict_hit;
id_hash_t *rdf_graph_default_private_perms_of_user_dict_htable;

caddr_t
bif_rdf_graph_id2iri_dict (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  sec_check_dba ((query_instance_t *)qst, "__rdf_graph_id2iri_dict");
  return box_copy (rdf_graph_id2iri_dict_hit);
}

caddr_t
bif_rdf_graph_iri2id_dict (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  sec_check_dba ((query_instance_t *)qst, "__rdf_graph_iri2id_dict");
  return box_copy (rdf_graph_iri2id_dict_hit);
}

caddr_t
bif_rdf_graph_group_dict (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  sec_check_dba ((query_instance_t *)qst, "__rdf_graph_group_dict");
  return box_copy (rdf_graph_group_dict_hit);
}

caddr_t
bif_rdf_graph_public_perms_dict (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  sec_check_dba ((query_instance_t *)qst, "__rdf_graph_public_perms_dict");
  return box_copy (rdf_graph_public_perms_dict_hit);
}

caddr_t
bif_rdf_graph_group_of_privates_dict (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  sec_check_dba ((query_instance_t *)qst, "__rdf_graph_group_of_privates_dict");
  return box_copy (rdf_graph_group_of_privates_dict_hit);
}

caddr_t
bif_rdf_graph_default_perms_of_user_dict (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  sec_check_dba ((query_instance_t *)qst, "__rdf_graph_default_perms_of_user_dict");
  if (bif_long_arg (qst, args, 0, "__rdf_graph_default_perms_of_user_dict"))
    return box_copy (rdf_graph_default_private_perms_of_user_dict_hit);
  return box_copy (rdf_graph_default_world_perms_of_user_dict_hit);
}

caddr_t
bif_rdf_cli_mark_qr_to_recompile (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t *) qst;
  client_connection_t * cli = qi->qi_client;
  query_t **qr;
  caddr_t *text;
  id_hash_iterator_t it;

  if (!cli || !cli->cli_text_to_query)
    return NULL;

  IN_CLIENT (cli);
  id_hash_iterator (&it, cli->cli_text_to_query);
  while (hit_next (&it, (caddr_t *) & text, (caddr_t *) & qr))
    {
      qr[0]->qr_to_recompile = 1;
    }
  LEAVE_CLIENT (cli);
  return NULL;
}

int
rdf_graph_specific_perms_of_user (user_t *u, iri_id_t g_iid)
{
  boxint res;
  /*int old_buckets;*/
  if (NULL == u)
    return 0;
  if (NULL == u->usr_rdf_graph_perms)
    return 0;
  mutex_enter (u->usr_rdf_graph_perms->ht_mutex);
  gethash_64 (res, (boxint)g_iid, u->usr_rdf_graph_perms);
  mutex_leave (u->usr_rdf_graph_perms->ht_mutex);
  return res;
}

int
rdf_graph_configured_perms (query_instance_t *qst, caddr_t graph_boxed_iid, user_t *u, int check_usr_rdf_graph_perms, int req_perms)
{
  int perms = 0;
  caddr_t u_id;
  int graph_is_private;
  id_hash_t *dict;
  caddr_t *hit;
  if (NULL == u)
    return ((0 == req_perms) ? 0x8000 : 0);
  u_id = box_num (u->usr_id);
  do {
      if (U_ID_DBA == u_id)
        {
          perms = 0x8000 | 0x3FF;
          break;
        }
      hit = (caddr_t *)id_hash_get (rdf_graph_public_perms_dict_htable, (caddr_t)(&graph_boxed_iid));
      if (NULL != hit)
        {
          perms = 0x8000 | unbox (hit[0]);
          if (!(req_perms & ~perms))
            break;
        }
      graph_is_private = (NULL != id_hash_get (rdf_graph_group_of_privates_dict_htable, (caddr_t)(&graph_boxed_iid)));
      dict = graph_is_private ? rdf_graph_default_private_perms_of_user_dict_htable : rdf_graph_default_world_perms_of_user_dict_htable;
      hit = (caddr_t *)id_hash_get (dict, (caddr_t)(&u_id));
      if (NULL != hit)
        {
          perms |= 0x8000 | unbox (hit[0]);
          if (!(req_perms & ~perms))
            break;
        }
      else if (u_id != U_ID_NOBODY)
        { /* No need to check default perms of nobody if default perms of the user are checked already, because user's are surely not more restrictive */
          hit = (caddr_t *)id_hash_get (dict, (caddr_t)(&boxed_nobody_uid));
          if (NULL != hit)
            {
              perms |= 0x8000 | unbox (hit[0]);
              if (!(req_perms & ~perms))
                break;
            }
        }
      if (check_usr_rdf_graph_perms && (NULL != u->usr_rdf_graph_perms))
        {
          int p;
          gethash_64 (p, unbox_iri_int64(graph_boxed_iid), u->usr_rdf_graph_perms);
          perms |= p; /* No need in "0x8000 | p" because zero can not be stored here under any circumstances */
          if (!(req_perms & ~perms))
            break;
        }
      if (0 == perms) /* there were no related perms at all */
        perms = RDF_GRAPH_PERM_DEFAULT;
      break;
    } while (0);
  dk_free_box (u_id);
  return perms;
}

int
rdf_graph_app_cbk_perms (query_instance_t *qst, caddr_t graph_boxed_iid, user_t *u, caddr_t app_cbk, caddr_t app_uid, caddr_t *err_ret)
{
  static query_t *app_cbk_qr = NULL;
  local_cursor_t * lc = NULL;
  int rc = 0;
  client_connection_t *cli = qst->qi_client;
  if (NULL == app_cbk_qr)
    app_cbk_qr = sql_compile_static ("call (?)(?, ?)", bootstrap_cli, err_ret, SQLC_DEFAULT);
  err_ret[0] = qr_quick_exec (app_cbk_qr, cli, NULL, &lc, 3,
      ":0", app_cbk, QRP_STR,
      ":1", box_copy_tree (graph_boxed_iid), QRP_RAW,
      ":2", app_uid, QRP_STR );
  if (lc && DV_ARRAY_OF_POINTER == DV_TYPE_OF (lc->lc_proc_ret)
      && BOX_ELEMENTS ((caddr_t *)lc->lc_proc_ret) > 1)
    rc = unbox (((caddr_t *)lc->lc_proc_ret)[1]);
  if (lc) lc_free (lc);
  return rc;
}

caddr_t
bif_rdf_graph_specific_perms_of_user (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *)qst;
  oid_t u_id;
  user_t *u;
  boxint perms;
  iri_id_t g_iid = bif_iri_id_arg (qst, args, 0, "__rdf_graph_specific_perms_of_user");
  switch (BOX_ELEMENTS (args))
    {
    case 1:
      u = sec_id_to_user (qi->qi_u_id);
      return box_num (rdf_graph_specific_perms_of_user (u, g_iid));
    case 2:
      sec_check_dba (qi, "__rdf_graph_specific_perms_of_user");
      u_id = bif_long_arg (qst, args, 1, "__rdf_graph_specific_perms_of_user");
      u = sec_id_to_user (u_id);
      return box_num (rdf_graph_specific_perms_of_user (u, g_iid));
    default:
      sec_check_dba (qi, "__rdf_graph_specific_perms_of_user");
      u_id = bif_long_arg (qst, args, 1, "__rdf_graph_specific_perms_of_user");
      perms = bif_long_arg (qst, args, 2, "__rdf_graph_specific_perms_of_user");
      u = sec_id_to_user (u_id);
      if (NULL == u)
        sqlr_new_error ("42000", "SR608", "__rdf_graph_specific_perms_of_user() has got an invalid user ID %ld", (long)u_id);
      if (0 > perms)
        {
          if (NULL != u->usr_rdf_graph_perms)
            {
              mutex_enter (u->usr_rdf_graph_perms->ht_mutex);
              remhash_64 (g_iid, u->usr_rdf_graph_perms);
              mutex_leave (u->usr_rdf_graph_perms->ht_mutex);
            }
        }
      else
        {
          if (NULL == u->usr_rdf_graph_perms)
            {
              dk_hash_64_t *ht = hash_table_allocate_64 (97);
              ht->ht_mutex = mutex_allocate ();
              u->usr_rdf_graph_perms = ht;
            }
          mutex_enter (u->usr_rdf_graph_perms->ht_mutex);
          sethash_64 (g_iid, u->usr_rdf_graph_perms, perms);
          mutex_leave (u->usr_rdf_graph_perms->ht_mutex);
        }
      return 0;
    }
}

caddr_t
bif_rdf_graph_approx_perms (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *)qst;
  caddr_t graph_boxed_iid, u_id;
  int graph_is_private;
  id_hash_t *dict;
  caddr_t *hit;
  sec_check_dba (qi, "__rdf_graph_approx_perms");
  graph_boxed_iid = bif_arg (qst, args, 0, "__rdf_graph_approx_perms");
  u_id = bif_arg (qst, args, 1, "__rdf_graph_approx_perms");
  hit = (caddr_t *)id_hash_get (rdf_graph_public_perms_dict_htable, (caddr_t)(&graph_boxed_iid));
  if (NULL != hit)
    return box_copy_tree (hit[0]);
  graph_is_private = (NULL != id_hash_get (rdf_graph_group_of_privates_dict_htable, (caddr_t)(&graph_boxed_iid)));
  dict = graph_is_private ? rdf_graph_default_private_perms_of_user_dict_htable : rdf_graph_default_world_perms_of_user_dict_htable;
  hit = (caddr_t *)id_hash_get (dict, (caddr_t)(&u_id));
  if (NULL != hit)
    return box_copy_tree (hit[0]);
  hit = (caddr_t *)id_hash_get (dict, (caddr_t)(&boxed_nobody_uid));
  if (NULL != hit)
    return box_copy_tree (hit[0]);
  return box_num (RDF_GRAPH_PERM_DEFAULT);
}

const char *
rdf_graph_user_perm_title (int perm)
{
  if (perm & 0x1) return "read";
  if (perm & 0x2) return "write";
  if (perm & 0x4) return "sponge";
  if (perm & 0x8) return "get-group-list";
  return "gs-special";
}

caddr_t
bif_rgs_impl_graph_boxed_iid (caddr_t * qst, caddr_t graph, int bif_can_use_index)
{
  if (DV_IRI_ID == DV_TYPE_OF (graph))
    return graph;
  else if (bif_can_use_index && (((DV_STRING == DV_TYPE_OF (graph)) /*&& (BF_IRI & box_flags(graph))*/) || (DV_UNAME == DV_TYPE_OF (graph))))
    {
      caddr_t err = NULL;
      caddr_t graph_boxed_iid = iri_to_id (qst, graph, IRI_TO_ID_WITH_CREATE, &err);
      if (NULL == graph_boxed_iid)
        {
          dk_free_tree (err);
          return NULL;
        }
      return graph_boxed_iid;
    }
  else
    return NULL;
}

typedef struct rgs_userdetails_s
{
  user_t *	ud_u;
  caddr_t	ud_app_cbk;
  caddr_t	ud_app_uid;
  int		ud_orig_id;
  char *	ud_orig_name;
} rgs_userdetails_t;

void
bif_rgs_impl_graph_set_userdetails (caddr_t * qst, state_slot_t ** args, const char *fname, int bif_can_use_index, rgs_userdetails_t *ud_ret)
    {
  caddr_t *user_and_cbk;
  memset (ud_ret, 0, sizeof (rgs_userdetails_t));
  if (bif_can_use_index)
    {
      user_and_cbk = (caddr_t *)bif_arg (qst, args, 1, fname);
      if ((DV_STRING == DV_TYPE_OF (user_and_cbk)) || (DV_LONG_INT == DV_TYPE_OF (user_and_cbk)))
        ud_ret->ud_u = bif_user_t_arg (qst, args, 1, fname, (USER_SHOULD_EXIST | USER_SHOULD_BE_SQL_ENABLED | USER_NOBODY_IS_PERMITTED | USER_SPARQL_IS_PERMITTED), 1);
      else
        {
          caddr_t uid_or_uname;
          if ((DV_ARRAY_OF_POINTER != DV_TYPE_OF (user_and_cbk)) ||
            (3 != BOX_ELEMENTS (user_and_cbk)) ||
            ((DV_LONG_INT != DV_TYPE_OF (user_and_cbk[0])) && (DV_STRING != DV_TYPE_OF (user_and_cbk[0]))) ||
            (DV_STRING != DV_TYPE_OF (user_and_cbk[1])) )
            sqlr_new_error ("22023", "SR616",
              "The second argument of %s() should be a string (user name), an integer (user ID) or an array of special format", fname );
          uid_or_uname = user_and_cbk[0];
          ud_ret->ud_app_cbk = user_and_cbk[1];
          ud_ret->ud_app_uid = user_and_cbk[2];
          ud_ret->ud_u = bif_user_t_arg_int (uid_or_uname, 1, fname, (USER_SHOULD_EXIST | USER_SHOULD_BE_SQL_ENABLED | USER_NOBODY_IS_PERMITTED | USER_SPARQL_IS_PERMITTED), 1);
        }
    }
  else
    {
      ud_ret->ud_u = bif_user_t_arg (qst, args, 1, fname, (USER_SHOULD_EXIST | USER_SHOULD_BE_SQL_ENABLED | USER_NOBODY_IS_PERMITTED | USER_SPARQL_IS_PERMITTED), 1);
    }
  if (NULL == ud_ret->ud_u)
    {
      user_and_cbk = (caddr_t *)bif_arg (qst, args, 1, fname);
      switch (DV_TYPE_OF (user_and_cbk))
        {
        case DV_LONG_INT: ud_ret->ud_orig_id = unbox((void *)user_and_cbk); break;
        case DV_STRING: ud_ret->ud_orig_name = (void *)user_and_cbk; break;
        }
    }
    }

caddr_t
bif_rgs_impl_make_error_for_assert (caddr_t * qst, const char *fname, int bif_can_use_index, caddr_t graph, caddr_t graph_boxed_iid, int failed_perms, const char *opname, const char *user_type, rgs_userdetails_t *ud_ptr)
    {
  query_instance_t *qi = (query_instance_t *)qst;
  caddr_t graph_iri;
      caddr_t err;
      iri_id_t graph_iid = unbox_iri_id (graph_boxed_iid);
      if ((min_bnode_iri_id () <= graph_iid) && (min_named_bnode_iri_id () > graph_iid))
        graph_iri = BNODE_IID_TO_LABEL(graph_iid);
      else if (bif_can_use_index)
        graph_iri = key_id_to_iri (qi, graph_iid);
      else
        {
          char tmp[40];
          if (graph_iid >= MIN_64BIT_BNODE_IRI_ID)
            snprintf (tmp, sizeof (tmp), "#ib" IIDBOXINT_FMT, (boxint)(graph_iid-MIN_64BIT_BNODE_IRI_ID));
          else
            snprintf (tmp, sizeof (tmp), "#i" IIDBOXINT_FMT, (boxint)(graph_iid));
          graph_iri = box_dv_short_string (tmp);
        }
      err = srv_make_new_error ("RDF02", "SR619", "%.50s access denied: %.20s user %d (%.200s) has no %.50s permission on graph %.500s",
    opname, user_type,
    ((NULL == ud_ptr->ud_u) ? ud_ptr->ud_orig_id : (int)(ud_ptr->ud_u->usr_id)),
    ((NULL == ud_ptr->ud_u) ? ((NULL == ud_ptr->ud_orig_name) ? "unknown user" : ud_ptr->ud_orig_name) : ud_ptr->ud_u->usr_name),
        rdf_graph_user_perm_title (failed_perms),
        (graph_iri ? graph_iri : "???") );
      dk_free_box (graph_iri);
      if (graph_boxed_iid != graph)
        dk_free_tree (graph_boxed_iid);
  return err;
}

#define RGU_GET 0
#define RGU_ACK 1
#define RGU_ASSERT 2

caddr_t
bif_rgs_impl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, const char *fname, int mode, int bif_can_use_index)
{
  query_instance_t *qi = (query_instance_t *)qst;
  rgs_userdetails_t ud;
  oid_t uid;
  int perms, failed_perms;
  caddr_t graph = bif_arg (qst, args, 0, fname);
  caddr_t graph_boxed_iid = NULL;
  int req_perms = bif_long_arg (qst, args, 2, fname);
  const char *opname = (3 < BOX_ELEMENTS (args)) ? bif_string_arg (qst, args, 3, fname) : "SPARQL query";
  graph_boxed_iid = bif_rgs_impl_graph_boxed_iid (qst, graph, bif_can_use_index);
  if (NULL == graph_boxed_iid)
    return NEW_DB_NULL;
/* Now we know that the graph is OK so it's time to get user */
  bif_rgs_impl_graph_set_userdetails (qst, args, fname, bif_can_use_index, &ud);
/* At this point, u is set for sure, app_cbk and app_uid can be set if bif_uses_index */
  if (NULL == ud.ud_u)
    perms = 0;
  else
    {
      uid = ud.ud_u->usr_id;
      perms = rdf_graph_configured_perms (qi, graph_boxed_iid, ud.ud_u, 1, req_perms);
    }
  failed_perms = req_perms & ~perms;
  if (failed_perms && (RGU_ASSERT == mode))
    sqlr_resignal (bif_rgs_impl_make_error_for_assert (qst, fname, bif_can_use_index, graph, graph_boxed_iid, failed_perms, opname, "database", &ud));
  if ((NULL != ud.ud_app_cbk) && (NULL != ud.ud_u))
    {
      caddr_t err = NULL;
      int perms_of_cbk = rdf_graph_app_cbk_perms (qi, graph_boxed_iid, ud.ud_u, ud.ud_app_cbk, ud.ud_app_uid, &err);
      perms &= perms_of_cbk;
      failed_perms = req_perms & ~perms;
      if (failed_perms && (RGU_ASSERT == mode))
        sqlr_resignal (bif_rgs_impl_make_error_for_assert (qst, fname, bif_can_use_index, graph, graph_boxed_iid, failed_perms, opname, "application", &ud));
    }
  if (graph_boxed_iid != graph)
    dk_free_tree (graph_boxed_iid);
  switch (mode)
    {
    case RGU_ACK:
      return (caddr_t)((ptrlong)((req_perms & ~perms) ? 0 : 1));
    case RGU_ASSERT:
      return box_copy (graph);
    default:
  return box_num (perms);
}
}

caddr_t
bif_rgs_assert (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  const char *fname = "__rgs_assert";
  return bif_rgs_impl (qst, err_ret, args, fname, RGU_ASSERT, 0);
}

caddr_t
bif_rgs_assert_cbk (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  const char *fname = "__rgs_assert_cbk";
  return bif_rgs_impl (qst, err_ret, args, fname, RGU_ASSERT, 1);
}

caddr_t
bif_rgs_ack (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  const char *fname = "__rgs_ack";
  return bif_rgs_impl (qst, err_ret, args, fname, RGU_ACK, 0);
}

caddr_t
bif_rgs_ack_cbk (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  const char *fname = "__rgs_ack_cbk";
  return bif_rgs_impl (qst, err_ret, args, fname, RGU_ACK, 1);
}

caddr_t
bif_rdf_repl_uid (caddr_t *qst, caddr_t * err_ret, state_slot_t **args)
{
  return box_num (U_ID_RDF_REPL);
}

/*! This returns nonzero if the graph in question should be replicated. The \c answer_is_one_for_all_ret is fileld with zero if this decision is "individual"
and nonzero if the reason is as common as replication not enabled or \c REPLICATION_SUPPORT is not enabled in the build or vica versa the replication is
enabled and enable for all by putting virtrdf:rdf_repl_all to the replication group.
However care should be taken in case of positive returned result combined with nonzero answer_is_one_for_all_ret.
This combination does not mean that all graphs can be replicated. An additional check should be made for virtrdf: that should never be replicated. */
int
rdf_graph_is_in_enabled_repl (caddr_t * qst, iri_id_t q_iid, int *answer_is_one_for_all_ret)
{
  answer_is_one_for_all_ret[0] = 1;
  return 0;
}

caddr_t
bif_rdf_graph_is_in_enabled_repl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return 0;
}

caddr_t
bif_rgs_prepare_del_or_ins (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  const char *fname = "__rgs_prepare_del_or_ins";
  const char *opname = "SPARQL INSERT/DELETE";
  const char *user_type = "database";
  query_instance_t *qi = (query_instance_t *)qst;
  rgs_userdetails_t ud;
  oid_t uid;
  int perms;
  caddr_t **quads = (caddr_t **)((void *)(bif_array_of_pointer_arg (qst, args, 0, fname)));
  caddr_t dflt_graph = bif_arg (qst, args, 2, fname);
  caddr_t dflt_graph_boxed_iid = ((DV_DB_NULL == DV_TYPE_OF (dflt_graph)) ? NULL : bif_rgs_impl_graph_boxed_iid (qst, dflt_graph, 1));
  caddr_t *all_flds[4];
  int quad_ctr, quad_count;
  int *good_repl_idxs = NULL;
  int good_repl_ctr, good_repl_count = 0;
  int fldctr;
  int argcount = BOX_ELEMENTS (args);
  int repl_ssls_are_passed = (argcount >= 3+4+4);
  int repl_is_same_for_all = repl_ssls_are_passed ? 0 : 1;
  int common_repl = 0;
  iri_id_t prev_g_iid = ~((iri_id_t)0L);
  int prev_g_props = 0;
  caddr_t **data_to_drop;
  dk_hash_t *g_props_hash = NULL;
  bif_rgs_impl_graph_set_userdetails (qst, args, fname, 1, &ud);
  quad_count = BOX_ELEMENTS (quads);
  for (fldctr = 0; fldctr < 4; fldctr++)
    all_flds[fldctr] = dk_alloc_list_zero (quad_count);
  data_to_drop = (caddr_t **)((void *)(list (5, NULL /* place for good_repl_idxs */, all_flds[0], all_flds[1], all_flds[2], all_flds[3])));
  for (quad_ctr = 0; quad_ctr < quad_count; quad_ctr++)
    {
      caddr_t graph = quads[quad_ctr][3];
      caddr_t graph_boxed_iid = ((DV_DB_NULL == DV_TYPE_OF (graph)) ? dflt_graph_boxed_iid : bif_rgs_impl_graph_boxed_iid (qst, graph, 1));
      caddr_t err;
      iri_id_t graph_iid;
      int g_props;
      int g_repl;
      graph_iid = unbox_iri_id (graph_boxed_iid);
      if (NULL == graph_boxed_iid)
        {
          all_flds[0][quad_ctr] = all_flds[1][quad_ctr] = all_flds[2][quad_ctr] = all_flds[3][quad_ctr] = NULL;
          continue;
        }
      if (NULL == ud.ud_u)
        goto signal_failed_perms; /* see below */
      if (prev_g_iid == graph_iid)
        g_props = prev_g_props;
      else
        {
          if (NULL == g_props_hash)
            {
              g_props_hash = hash_table_allocate (30);
              g_props = 0;
            }
          else
            g_props = (ptrlong)gethash ((void *)((ptrlong)(graph_iid)), g_props_hash);
          if (0 == g_props)
            {
              uid = ud.ud_u->usr_id;
              perms = rdf_graph_configured_perms (qi, graph_boxed_iid, ud.ud_u, 1, RDF_GRAPH_PERM_WRITE);
              if (RDF_GRAPH_PERM_WRITE & ~perms)
                goto signal_failed_perms; /* see below */
              if (NULL != ud.ud_app_cbk)
                {
                  caddr_t err = NULL;
                  int perms_of_cbk = rdf_graph_app_cbk_perms (qi, graph_boxed_iid, ud.ud_u, ud.ud_app_cbk, ud.ud_app_uid, &err);
                  perms &= perms_of_cbk;
                  if (RDF_GRAPH_PERM_WRITE & ~perms)
                    {
                      user_type = "application";
                      goto signal_failed_perms; /* see below */
                    }
                }
              g_props = 0x1;
            }
          if (graph_iid == iid_of_virtrdf_ns_uri)
            g_repl = 0;
          else if (repl_is_same_for_all)
            g_repl = common_repl;
          else
            {
              g_repl = rdf_graph_is_in_enabled_repl (qst, graph_iid, &repl_is_same_for_all);
              if (repl_is_same_for_all)
                common_repl = g_repl;
            }
          if (g_repl)
            g_props |= 0x2;
          sethash ((void *)((ptrlong)(graph_iid)), g_props_hash, (void *)((ptrlong)g_props));
        }
      if (0x2 & g_props)
        {
          if (NULL == good_repl_idxs)
            {
              good_repl_idxs = (int *)dk_alloc_box_zero (quad_count * sizeof (int), DV_ARRAY_OF_LONG);
              data_to_drop[0] = (caddr_t *)((void *)good_repl_idxs);
            }
          good_repl_idxs [good_repl_count++] = quad_ctr;
        }
      for (fldctr = 0; fldctr < 3; fldctr++)
        {
          all_flds[fldctr][quad_ctr] = quads[quad_ctr][fldctr];
          quads[quad_ctr][fldctr] = NULL;
        }
      all_flds[3][quad_ctr] = (graph_boxed_iid == dflt_graph_boxed_iid) ? box_copy (graph_boxed_iid) : graph_boxed_iid;
      if (graph_boxed_iid == graph)
        quads[quad_ctr][3] = NULL;
      continue;

signal_failed_perms:
      dk_free_tree ((void *)data_to_drop);
      if (NULL != g_props_hash)
        hash_table_free (g_props_hash);
      err = bif_rgs_impl_make_error_for_assert (qst, fname, 1, graph, graph_boxed_iid, RDF_GRAPH_PERM_WRITE, opname, user_type, &ud);
      if ((graph_boxed_iid != graph) && (graph_boxed_iid != dflt_graph_boxed_iid))
        dk_free_tree (graph_boxed_iid);
      sqlr_resignal (err);
    }
  if (repl_ssls_are_passed)
    {
      for (fldctr = 0; fldctr < 4; fldctr++)
        {
          caddr_t *all_fld = all_flds[fldctr];
          caddr_t *repl_fld = (caddr_t *)dk_alloc_list_zero (good_repl_count);
          for (good_repl_ctr = 0; good_repl_ctr < good_repl_count; good_repl_ctr++)
            {
              repl_fld [good_repl_ctr] = box_copy_tree (all_fld [good_repl_idxs [good_repl_ctr]]);
            }
          qst_set (qst, args[3 + 4 + fldctr], (caddr_t)((void *)repl_fld));
        }
    }
  for (fldctr = 0; fldctr < 4; fldctr++)
    {
      qst_set (qst, args[3 + fldctr], (caddr_t)((void *)(all_flds[fldctr])));
      data_to_drop [1 + fldctr] = NULL;
    }
  dk_free_tree ((void *)data_to_drop);
  if (NULL != g_props_hash)
    hash_table_free (g_props_hash);
  return NULL;
}

#define RDF_REPL_QUAD_INS_PLAIN_LIT	80
#define RDF_REPL_QUAD_INS_DT_LIT	81
#define RDF_REPL_QUAD_INS_LANG_LIT	82
#define RDF_REPL_QUAD_INS_AUTO_LIT	83
#define RDF_REPL_QUAD_INS_REF		84
#define RDF_REPL_QUAD_INS_GEO		85
#define RDF_REPL_QUAD_INS_MAX_OP	85
#define RDF_REPL_QUAD_HASH_MASK		0xF

#define RDF_REPL_QUAD_DEL_PLAIN_LIT	160
#define RDF_REPL_QUAD_DEL_DT_LIT	161
#define RDF_REPL_QUAD_DEL_LANG_LIT	162
#define RDF_REPL_QUAD_DEL_AUTO_LIT	163
#define RDF_REPL_QUAD_DEL_REF		164

#define RDF_REPL_BATCH_SIZE		10000

id_hash_t *repl_items_to_del = NULL;
id_hash_t *repl_items_to_ins = NULL;

int
rdf_repl_vector_sort_cmp (caddr_t * e1, caddr_t * e2, vector_sort_t * specs)
{
  caddr_t *rquad1 = (caddr_t *)(e1[0]);
  caddr_t *rquad2 = (caddr_t *)(e2[0]);
  dtp_t dtp1;
  int cmp;
  cmp = strcmp (rquad1[1], rquad2[1]);
  if (cmp > 0) return DVC_GREATER;
  else if (cmp < 0) return DVC_LESS;
  cmp = strcmp (rquad1[2], rquad2[2]);
  if (cmp > 0) return DVC_GREATER;
  else if (cmp < 0) return DVC_LESS;
  dtp1 = DV_TYPE_OF (rquad1[3]);
  cmp = (int)(dtp1) - (int)(DV_TYPE_OF (rquad2[3]));
  if (cmp > 0) return DVC_GREATER;
  else if (cmp < 0) return DVC_LESS;
  if (DV_STRING == dtp1)
    {
      cmp = strcmp (rquad1[3], rquad2[3]);
      if (cmp > 0) return DVC_GREATER;
      else if (cmp < 0) return DVC_LESS;
    }
  return DVC_MATCH;
}

caddr_t **
rdf_repl_hash_to_sorted_vector (id_hash_t *ht)
{
  id_hash_iterator_t hit;
  int quad_count = ht->ht_count;
  caddr_t **quad_ptr, *val_stub_ptr;
  caddr_t **res = (caddr_t **) dk_alloc_box (quad_count * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  caddr_t **tail = res;
  vector_sort_t specs;
  id_hash_iterator (&hit, ht);
  while (hit_next (&hit, (char **)&quad_ptr, (char **)&val_stub_ptr))
    {
      (tail++)[0] = quad_ptr[0];
    }
  specs.vs_block_elts = 1;
  specs.vs_key_ofs = 0;
  specs.vs_sort_asc = 1;
  specs.vs_cmp_fn = rdf_repl_vector_sort_cmp;
  vector_qsort ((caddr_t *)res, quad_count, &specs);
  dk_check_tree (res);
  id_hash_clear (ht);
  return res;
}

void
rdf_repl_feed_batch_of_rquads (query_instance_t *qi, caddr_t **rquads_vector, ccaddr_t *cbk_names, caddr_t *app_env)
{
  static int fake_lineno = 0;
  triple_feed_t *tf;
  int rquads_count = BOX_ELEMENTS (rquads_vector);
  int rquad_ctr;
  query_t *geo_qr = NULL;
  caddr_t prev_graph = "";
  if (0 == rquads_count)
    return; /* no data -- nothing to feed */
  tf = tf_alloc ();
  tf->tf_qi = qi;
  tf->tf_default_graph_uri = NULL;
  tf->tf_current_graph_uri = NULL;
  tf->tf_app_env = app_env;
  tf->tf_creator = "__rdf_repl_action";
  tf->tf_boxed_input_name = NEW_DB_NULL;
  tf->tf_line_no_ptr = &fake_lineno;
  tf_set_cbk_names (tf, cbk_names);
  DO_BOX_FAST (caddr_t *, rquad, rquad_ctr, rquads_vector)
    {
      int opcode = (ptrlong)(rquad[0]);
      caddr_t g = rquad[1];
      caddr_t s = rquad[2];
      caddr_t p = rquad[3];
      caddr_t oval = rquad[4];
      if (strcmp (g, prev_graph))
        {
          if (NULL != tf->tf_current_graph_uri)
            tf_commit (tf);
          tf->tf_current_graph_uri = g;
          if (TF_ONE_GRAPH_AT_TIME(tf))
            {
              dk_free_tree ((tf)->tf_current_graph_iid);
              tf->tf_current_graph_iid = NULL; /* to avoid double free in case of error in tf_get_iid() below */
              tf->tf_current_graph_iid = tf_get_iid ((tf), (tf)->tf_current_graph_uri);
              tf_new_graph (tf, tf->tf_current_graph_uri);
            }
          prev_graph = g;
        }
      switch (opcode)
        {
        case RDF_REPL_QUAD_INS_PLAIN_LIT & RDF_REPL_QUAD_HASH_MASK:
          tf_triple_l (tf, s, p, oval, NULL, NULL);
          break;
        case RDF_REPL_QUAD_INS_DT_LIT & RDF_REPL_QUAD_HASH_MASK:
          tf_triple_l (tf, s, p, oval, rquad[5], NULL);
          break;
        case RDF_REPL_QUAD_INS_LANG_LIT & RDF_REPL_QUAD_HASH_MASK:
          tf_triple_l (tf, s, p, oval, NULL, rquad[5]);
          break;
        case RDF_REPL_QUAD_INS_REF & RDF_REPL_QUAD_HASH_MASK:
          tf_triple (tf, s, p, oval);
	  break;
        case RDF_REPL_QUAD_INS_GEO & RDF_REPL_QUAD_HASH_MASK:
          {
            caddr_t err = NULL;
            char params_buf [BOX_AUTO_OVERHEAD + sizeof (caddr_t) * 4];
            void **params;
            static const char *geo_qr_text = "insert soft DB.DBA.RDF_QUAD (G,S,P,O) \
 values (iri_to_id_repl (?), iri_to_id_repl (?), iri_to_id (\'http://www.w3.org/2003/01/geo/wgs84_pos#geometry\'), \
 rdf_geo_add (rdf_box (st_point (?, ?), 256, 257, 0, 1)))";
            if (NULL == geo_qr)
              {
                geo_qr = sql_compile (geo_qr_text, qi->qi_client, &err, SQLC_DEFAULT);
                if (NULL != err)
                  GPF_T1 ("rdf_repl_feed_batch_of_rquads() failed to compile geo qr");
              }
            BOX_AUTO_TYPED (void **, params, params_buf, sizeof (caddr_t) * 4, DV_ARRAY_OF_POINTER);
            params[0] = box_copy_tree(g);
            params[1] = box_copy_tree(s);
            params[2] = box_copy_tree(rquad[3]);
            params[3] = box_copy_tree(rquad[4]);
            err = qr_exec (qi->qi_client, geo_qr, qi, NULL, NULL, NULL, (caddr_t *)params, NULL, 0);
            BOX_DONE (params, params_buf);
            break;
          }
        }
      dk_check_tree (rquad);
    }
  END_DO_BOX_FAST;
  tf_commit (tf);
  tf->tf_current_graph_uri = NULL; /* To not free it twice (there's no box_copy_tree from rquad[1] to it, just copying the pointer) */
  tf_free (tf);
  dk_free_tree (rquads_vector);
}


caddr_t
iri_canonicalize_and_cast_to_repl (query_instance_t *qi, caddr_t arg, caddr_t *err_ret)
{
  caddr_t res = NULL;
  int status;
  if (DV_IRI_ID == DV_TYPE_OF (arg))
    {
      iri_id_t arg_iidt = unbox_iri_id (arg);
      if (arg_iidt >= min_bnode_iri_id())
        return arg;
      return key_id_to_canonicalized_iri (qi, arg_iidt);
    }
  status = iri_canonicalize (qi, arg, IRI_TO_ID_IF_CACHED, &res, err_ret);
  if (0 == status)
    err_ret[0] = srv_make_new_error ("22023", "SRxxx", "Can not cast IRI in RDF replication");
  return res;
}

static caddr_t repl_pub_name;
static caddr_t text5arg;
static caddr_t text6arg;

caddr_t
bif_rdf_repl_quad (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return 0;
}

caddr_t
bif_rdf_repl_action (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return NULL;
}

caddr_t
bif_rdf_repl_flush_queue (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return NULL;
}

static int
rdf_single_check (query_instance_t *qi, caddr_t start_box_arg, boxint ro_id, rdf_box_t **complete_rb_ptr, long opcode, caddr_t opval)
{
  dtp_t opval_dtp = DV_TYPE_OF (opval);
  caddr_t opval_strval, complete_strval;
  int start_box_len, complete_strval_len, opval_len, cmp;
  switch (opval_dtp)
    {
    case DV_STRING: opval_strval = opval; break;
    case DV_RDF:
      {
        rdf_box_t *rb = (rdf_box_t *)(opval);
        if (!rb->rb_is_complete)
          rb_complete (rb, qi->qi_trx, qi);
        opval_strval = rb->rb_box;
        if (DV_STRING != DV_TYPE_OF (opval_strval))
          return 0 /* because DVC_NOORDER */;
        break;
      }
    default:
      return 0 /* because DVC_NOORDER */;
    }
  opval_len = box_length (opval_strval) - 1;
  if (NULL != complete_rb_ptr[0])
    goto complete_rb_is_available; /* see below */
  start_box_len = box_length (start_box_arg) - 1;
  cmp = memcmp (start_box_arg, opval_strval, MIN (start_box_len, opval_len));
  switch (opcode)
    {
    case BOP_LT:
      if (0 < cmp)
        return 0; /* because DVC_GT; */
      if (RO_START_LEN <= opval_len)
        {
          if (0 > cmp)
            return 1; /* because DVC_LT at the beginning */
          break; /* the beginning is same but the rest may differ */
        }
      if (0 == cmp)
        return (start_box_len < opval_len);
      return 1;
    case BOP_LTE:
      if (0 < cmp)
        return 0; /* because DVC_GT; */
      if (RO_START_LEN <= opval_len)
        {
          if (0 > cmp)
            return 1; /* because DVC_LT at the beginning */
          break; /* the beginning is same but the rest may differ */
        }
      if (0 == cmp)
        return (start_box_len <= opval_len);
      return 1;
    case BOP_EQ:
      if (0 != cmp)
        return 0; /* because DVC_GT; */
      if (RO_START_LEN <= opval_len)
        {
          break; /* the beginning is same but the rest may differ */
        }
      return (start_box_len == opval_len);
    case BOP_GT:
      if (0 > cmp)
        return 0; /* because DVC_LT; */
      if (RO_START_LEN <= opval_len)
        {
          if (0 < cmp)
            return 1; /* because DVC_GT at the beginning */
          break; /* the beginning is same but the rest may differ */
        }
      if (0 == cmp)
        return (start_box_len > opval_len);
      return 1;
    case BOP_GTE:
      if (0 > cmp)
        return 0; /* because DVC_LT; */
      if (RO_START_LEN <= opval_len)
        {
          if (0 < cmp)
            return 1; /* because DVC_GT at the beginning */
          break; /* the beginning is same but the rest may differ */
        }
      if (0 == cmp)
        return (start_box_len >= opval_len);
      return 1;
    default: return 0;
    }
/* Now a whole value should be filled in if needed and compared */
  complete_rb_ptr[0] = (rdf_box_t *)rbb_from_id (ro_id);
  rb_complete_1 (complete_rb_ptr[0], qi->qi_trx, qi, 1);
complete_rb_is_available:
  complete_strval = complete_rb_ptr[0]->rb_box;
  if (DV_STRING != DV_TYPE_OF (complete_strval))
    return 0; /* DVC_NOCOMP */
  complete_strval_len = box_length (complete_strval) - 1;
  cmp = memcmp (complete_strval, opval_strval, MIN (complete_strval_len, opval_len));
  switch (opcode)
    {
    case BOP_LT:
      if (0 < cmp)
        return 0; /* because DVC_GT; */
      if (0 == cmp)
        return (complete_strval_len < opval_len);
      return 1;
    case BOP_LTE:
      if (0 < cmp)
        return 0; /* because DVC_GT; */
      if (0 == cmp)
        return (complete_strval_len <= opval_len);
      return 1;
    case BOP_EQ:
      if (0 != cmp)
        return 0; /* because DVC_GT; */
      return (complete_strval_len == opval_len);
    case BOP_GT:
      if (0 > cmp)
        return 0; /* because DVC_LT; */
      if (0 == cmp)
        return (complete_strval_len > opval_len);
      return 1;
    case BOP_GTE:
      if (0 > cmp)
        return 0; /* because DVC_LT; */
      if (0 == cmp)
        return (complete_strval_len >= opval_len);
      return 1;
    default: return 0;
    }
}


caddr_t
bif_rdf_range_check (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t start_box_arg = bif_string_arg (qst, args, 0, "__rdf_range_check");
  boxint ro_id = 0;
  rdf_box_t *complete_box = NULL;
  caddr_t ro_id_arg;
  int res = 1;
  /* prefix_str, ro_id, lower, lower_op, upper, upper_op, completed_box_ret */
  /* check if prefix is between upper and lower as per lower_op and upper_op.  If prefix is too short to know, get the full text using ro_id.  If fetching the full text, put it in complete_box_ret if this is a writable ssl */
  ro_id_arg = bif_arg (qst, args, 1, "__rdf_range_check");
  switch (DV_TYPE_OF (ro_id_arg))
    {
    case DV_LONG_INT:
      ro_id = unbox (ro_id_arg);
      break;
    case DV_RDF:
      if (((rdf_box_t *)ro_id_arg)->rb_is_complete)
        {
          complete_box = (rdf_box_t *)ro_id_arg;
          break;
        }
      ro_id = ((rdf_box_t *)ro_id_arg)->rb_ro_id;
      break;
    default:
      bif_long_arg (qst, args, 1, "__rdf_range_check");
    }
  for (;;)
    {
      long lo_op, hi_op;
      lo_op = bif_long_arg (qst, args, 3, "__rdf_range_check");
      if (lo_op)
        {
          if (!(res = rdf_single_check ((query_instance_t *)qst, start_box_arg, ro_id, &complete_box, lo_op, bif_arg (qst, args, 2, "__rdf_range_check"))))
            break;
        }
      hi_op = bif_long_arg (qst, args, 5, "__rdf_range_check");
      if (hi_op)
        res = rdf_single_check ((query_instance_t *)qst, start_box_arg, ro_id, &complete_box, hi_op, bif_arg (qst, args, 4, "__rdf_range_check"));
      break;
    }
  if (7 <= BOX_ELEMENTS (args))
    {
      caddr_t *box_ret_ptr = qst_address (qst, args[6]);
      if (NULL != box_ret_ptr)
        {
          if (complete_box == (rdf_box_t *)ro_id_arg)
            complete_box = box_copy (ro_id_arg);
          qst_swap (qst, args[6], (void *)(&complete_box));
        }
    }
  if ((NULL != complete_box) && (complete_box != (rdf_box_t *)ro_id_arg))
    dk_free_tree (complete_box);
  return (caddr_t)((ptrlong)res);
}


caddr_t boxed_zero_iid = NULL;
caddr_t boxed_8k_iid = NULL;
caddr_t boxed_nobody_uid = NULL;

#define MAKE_RDF_GRAPH_DICT(name) do { \
  name##_htable = (id_hash_t *)box_dv_dict_hashtable (31); \
  name##_htable->ht_rehash_threshold = 120; \
  name##_htable->ht_dict_refctr = ID_HASH_LOCK_REFCOUNT; \
  name##_htable->ht_mutex = mutex_allocate (); \
  name##_hit = (id_hash_iterator_t *)box_dv_dict_iterator ((caddr_t)name##_htable); \
  } while (0)


caddr_t
rb_tmp_copy (mem_pool_t * mp, rdf_box_t * rb)
{
  if (gethash ((void*)rb, mp->mp_unames))
    return (caddr_t)rb;
  rb->rb_ref_count++;
  sethash ((void*)rb, mp->mp_unames, (void*)(ptrlong)1);
  return (caddr_t)rb;
}


caddr_t
bif_iri_name_id (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t name = bif_string_arg (qst, args, 0, "ri_name_id");
  return box_num (LONG_REF_NA (name));
}


extern box_tmp_copy_f box_tmp_copier[256];
void bif_ro2lo_vec (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, state_slot_t * ret);
void bif_ro2sq_vec (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, state_slot_t * ret);
void bif_ro2lo_vec (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, state_slot_t * ret);
void bif_str_vec (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, state_slot_t * ret);


void
rdf_box_init ()
{
  dk_mem_hooks (DV_RDF, (box_copy_f) rb_copy, (box_destr_f)rb_free, 1);
  box_tmp_copier[DV_RDF] = (box_tmp_copy_f) rb_tmp_copy;
  PrpcSetWriter (DV_RDF, (ses_write_func) rb_serialize);
  dk_dtp_register_hash (DV_RDF, rdf_box_hash, rdf_box_hash_cmp, rdf_box_hash_strong_cmp);
  boxed_zero_iid = box_iri_id (0);
  boxed_8k_iid = box_iri_id (8192);
  boxed_nobody_uid = box_num (U_ID_NOBODY);
  MAKE_RDF_GRAPH_DICT(rdf_graph_iri2id_dict);
  rdf_graph_iri2id_dict_htable->ht_hash_func = strhash;
  rdf_graph_iri2id_dict_htable->ht_cmp = strhashcmp;
  MAKE_RDF_GRAPH_DICT(rdf_graph_id2iri_dict);
  MAKE_RDF_GRAPH_DICT(rdf_graph_group_dict);
  MAKE_RDF_GRAPH_DICT(rdf_graph_public_perms_dict);
  MAKE_RDF_GRAPH_DICT(rdf_graph_group_of_privates_dict);
  MAKE_RDF_GRAPH_DICT(rdf_graph_default_world_perms_of_user_dict);
  MAKE_RDF_GRAPH_DICT(rdf_graph_default_private_perms_of_user_dict);
  bif_define_ex ("__rdf_set_bnode_t_treshold", bif_rdf_set_bnode_t_treshold, BMD_RET_TYPE, &bt_integer, BMD_DONE);
  bif_set_uses_index (bif_rdf_set_bnode_t_treshold);
  bif_define ("rdf_box", bif_rdf_box);
  bif_define ("rdf_box_from_ro_id", bif_rdf_box_from_ro_id);
  bif_define ("ro_digest_from_parts", bif_ro_digest_from_parts);
  bif_define_ex ("is_rdf_box", bif_is_rdf_box, BMD_RET_TYPE, &bt_integer, BMD_DONE);
  bif_define_ex ("rdf_box_set_data", bif_rdf_box_set_data, BMD_RET_TYPE, &bt_any, BMD_DONE);
  bif_define ("rdf_box_data", bif_rdf_box_data);
  bif_define_ex ("rdf_box_data_tag", bif_rdf_box_data_tag, BMD_RET_TYPE, &bt_integer, BMD_DONE);
  bif_define_ex ("rdf_box_ro_id", bif_rdf_box_ro_id, BMD_RET_TYPE, &bt_integer, BMD_DONE);
  bif_define_ex ("ro_digest_id", bif_ro_digest_id, BMD_RET_TYPE, &bt_integer, BMD_DONE);
  bif_define ("rdf_box_set_ro_id", bif_rdf_box_set_ro_id);
  bif_define_ex ("rdf_box_lang", bif_rdf_box_lang, BMD_RET_TYPE, &bt_integer, BMD_DONE);
  bif_define_ex ("rdf_box_type", bif_rdf_box_type, BMD_RET_TYPE, &bt_integer, BMD_DONE);
  bif_define_ex ("rdf_box_dt_and_lang", bif_rdf_box_dt_and_lang, BMD_RET_TYPE, &bt_integer, BMD_DONE);
  bif_define ("rdf_box_set_type", bif_rdf_box_set_type);
  bif_define ("rdf_box_chksum", bif_rdf_box_chksum);
  bif_define_ex ("rdf_box_is_text", bif_rdf_box_is_text, BMD_RET_TYPE, &bt_integer, BMD_DONE);
  bif_define ("rdf_box_set_is_text", bif_rdf_box_set_is_text);
  bif_define_ex ("rdf_box_is_complete", bif_rdf_box_is_complete, BMD_RET_TYPE, &bt_integer, BMD_DONE);
  /*bif_define_ex ("rdf_box_set_is_complete", bif_rdf_box_set_is_complete, BMD_RET_TYPE, &bt_integer, BMD_DONE); */
  bif_define_ex ("rdf_box_is_storeable", bif_rdf_box_is_storeable, BMD_RET_TYPE, &bt_integer, BMD_DONE);
  bif_define_ex ("rdf_box_needs_digest", bif_rdf_box_needs_digest, BMD_RET_TYPE, &bt_integer, BMD_DONE);
  bif_define_ex ("rdf_box_strcmp", bif_rdf_box_strcmp, BMD_RET_TYPE, &bt_integer, BMD_DONE);
  bif_define_ex ("rdf_box_migrate_after_06_02_3129", bif_rdf_box_migrate_after_06_02_3129, BMD_RET_TYPE, &bt_integer, BMD_DONE);
  bif_define_ex ("__rdf_long_of_obj", bif_rdf_long_of_obj, BMD_ALIAS, "__ro2lo", BMD_VECTOR_IMPL, bif_ro2lo_vec, BMD_RET_TYPE,
      &bt_any_box, BMD_USES_INDEX, BMD_DONE);
  bif_define_ex ("__rdf_box_make_complete", bif_rdf_box_make_complete, BMD_RET_TYPE, &bt_integer, BMD_USES_INDEX, BMD_DONE);
  bif_define_ex ("__rdf_box_to_ro_id_search_fields", bif_rdf_box_to_ro_id_search_fields, BMD_RET_TYPE, &bt_integer, BMD_DONE);
  bif_define_ex ("__rdf_sqlval_of_obj", bif_rdf_sqlval_of_obj, BMD_ALIAS, "__ro2sq", BMD_VECTOR_IMPL, bif_ro2sq_vec, BMD_RET_TYPE,
      &bt_any, BMD_USES_INDEX, BMD_DONE);
  bif_define_ex ("__rdf_strsqlval", bif_rdf_strsqlval, BMD_VECTOR_IMPL, bif_str_vec, BMD_RET_TYPE, &bt_varchar, BMD_USES_INDEX,
      BMD_DONE);
  bif_define_ex ("__rdf_long_to_ttl", bif_rdf_long_to_ttl, BMD_RET_TYPE, &bt_any, BMD_DONE);
  bif_set_uses_index (bif_rdf_long_to_ttl);
  bif_define_ex ("__rq_iid_of_o", bif_rq_iid_of_o, BMD_RET_TYPE, &bt_any, BMD_DONE);
  bif_define ("__rdf_long_from_batch_params", bif_rdf_long_from_batch_params);
  bif_define_ex ("__rdf_dist_ser_long", bif_rdf_dist_ser_long, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define_ex ("__rdf_dist_deser_long", bif_rdf_dist_deser_long, BMD_ALIAS, "__rdf_redu_deser_long", BMD_RET_TYPE, &bt_any,
      BMD_DONE);
  bif_define_ex ("__rdf_redu_ser_long", bif_rdf_redu_ser_long, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define ("http_sys_find_best_sparql_accept", bif_http_sys_find_best_sparql_accept);
  bif_define ("http_ttl_prefixes", bif_http_ttl_prefixes);
  bif_set_uses_index (bif_http_ttl_prefixes);
  bif_define ("http_ttl_triple", bif_http_ttl_triple);
  bif_set_uses_index (bif_http_ttl_triple);
  bif_define ("http_nt_triple", bif_http_nt_triple);
  bif_set_uses_index (bif_http_nt_triple);
  bif_define ("http_nquad", bif_http_nquad);
  bif_set_uses_index (bif_http_nquad);
  bif_define ("http_rdfxml_p_ns", bif_http_rdfxml_p_ns);
  bif_set_uses_index (bif_http_rdfxml_p_ns);
  bif_define ("http_rdfxml_triple", bif_http_rdfxml_triple);
  bif_set_uses_index (bif_http_rdfxml_triple);
  bif_define ("http_talis_json_triple", bif_http_talis_json_triple);
  bif_set_uses_index (bif_http_talis_json_triple);
  bif_define ("http_ld_json_triple", bif_http_ld_json_triple);
  bif_set_uses_index (bif_http_ld_json_triple);
  bif_define ("http_ttl_value", bif_http_ttl_value);
  bif_set_uses_index (bif_http_ttl_value);
  bif_define ("http_nt_object", bif_http_nt_object);
  bif_set_uses_index (bif_http_nt_object);
  bif_define ("http_rdf_object", bif_http_rdf_object);
  bif_set_uses_index (bif_http_rdf_object);
  bif_define_ex ("sparql_rset_ttl_write_row", bif_sparql_rset_ttl_write_row, BMD_USES_INDEX, BMD_NO_CLUSTER, BMD_DONE);
  bif_define_ex ("sparql_rset_nt_write_row", bif_sparql_rset_nt_write_row, BMD_USES_INDEX, BMD_NO_CLUSTER, BMD_DONE);
  bif_define_ex ("sparql_rset_json_write_row", bif_sparql_rset_json_write_row, BMD_USES_INDEX, BMD_NO_CLUSTER, BMD_DONE);
  bif_define_ex ("sparql_rset_xml_write_row", bif_sparql_rset_xml_write_row, BMD_USES_INDEX, BMD_NO_CLUSTER, BMD_DONE);
  bif_define ("sparql_iri_split_rdfa_qname", bif_sparql_iri_split_rdfa_qname);
  /* Short aliases for use in generated SQL text: */
  bif_define ("__rdf_graph_id2iri_dict", bif_rdf_graph_id2iri_dict);
  bif_define ("__rdf_graph_iri2id_dict", bif_rdf_graph_iri2id_dict);
  bif_define ("__rdf_graph_group_dict", bif_rdf_graph_group_dict);
  bif_define ("__rdf_graph_public_perms_dict", bif_rdf_graph_public_perms_dict);
  bif_define ("__rdf_graph_group_of_privates_dict", bif_rdf_graph_group_of_privates_dict);
  bif_define ("__rdf_graph_default_perms_of_user_dict", bif_rdf_graph_default_perms_of_user_dict);
  bif_define ("__rdf_cli_mark_qr_to_recompile", bif_rdf_cli_mark_qr_to_recompile);
  bif_define ("__rdf_graph_approx_perms", bif_rdf_graph_approx_perms);
  bif_define ("__rdf_graph_specific_perms_of_user", bif_rdf_graph_specific_perms_of_user);
  bif_define ("__rgs_assert", bif_rgs_assert);
  bif_define ("__rgs_assert_cbk", bif_rgs_assert_cbk);
  bif_set_uses_index (bif_rgs_assert_cbk );
  bif_define ("__rgs_ack", bif_rgs_ack);
  bif_define ("__rgs_ack_cbk", bif_rgs_ack_cbk);
  bif_set_uses_index (bif_rgs_ack_cbk );
  bif_define_ex ("__rdf_repl_uid", bif_rdf_repl_uid, BMD_RET_TYPE, &bt_integer, BMD_DONE);
  bif_define_ex ("__rgs_prepare_del_or_ins", bif_rgs_prepare_del_or_ins, BMD_RET_TYPE, &bt_integer, BMD_DONE);
  bif_set_uses_index (bif_rgs_prepare_del_or_ins);
  repl_pub_name = box_dv_short_string ("__rdf_repl");
  text5arg = box_dv_short_string ("__rdf_repl_action (?, ?, ?, ?, ?)");
  text6arg = box_dv_short_string ("__rdf_repl_action (?, ?, ?, ?, ?, ?)");
  bif_define ("__rdf_graph_is_in_enabled_repl", bif_rdf_graph_is_in_enabled_repl);
  bif_set_uses_index (bif_rdf_graph_is_in_enabled_repl);
  bif_define ("__rdf_repl_quad", bif_rdf_repl_quad);
  bif_define ("__rdf_repl_action", bif_rdf_repl_action);
  bif_set_uses_index (bif_rdf_repl_action);
  bif_define ("__rdf_repl_flush_queue", bif_rdf_repl_flush_queue);
  bif_set_uses_index (bif_rdf_repl_flush_queue);
  bif_define ("__rdf_range_check", bif_rdf_range_check);
  bif_set_uses_index (bif_rdf_range_check );
  bif_define_ex ("iri_name_id", bif_iri_name_id, BMD_RET_TYPE, &bt_integer, BMD_DONE);
}
