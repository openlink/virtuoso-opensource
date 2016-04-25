/*
 *  vecrdf.c
 *
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2016 OpenLink Software
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
#include "datesupp.h" /* For DT_PRINT_MODE_XML */
#include "security.h" /* For sec_check_dba() */


void
bif_id2i_vec (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, state_slot_t * ret)
{
  caddr_t err = NULL;
  QNCAST (query_instance_t, qi, qst);
  query_t *id2i = sch_proc_exact_def (wi_inst.wi_schema, "DB.DBA.ID_TO_IRI_VEC");
  if (!id2i)
    sqlr_new_error ("42001", "VEC..", "id to iri vectored is not defined");
  if (id2i->qr_to_recompile)
    id2i = qr_recompile (id2i, NULL);
  err = qr_subq_exec_vec (qi->qi_client, id2i, qi, NULL, 0, args, ret, NULL, NULL);
  if (IS_BOX_POINTER (err))
    sqlr_resignal (err);
}



void
bif_id2i_vec_ns (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, state_slot_t * ret)
{
  caddr_t err = NULL;
  QNCAST (query_instance_t, qi, qst);
  query_t * id2i = sch_proc_exact_def (wi_inst.wi_schema, "DB.DBA.ID_TO_IRI_VEC_NS");
  if (!id2i)
    sqlr_new_error ("42001", "VEC..", "id to iri vectored is not defined");
  if (id2i->qr_to_recompile)
    id2i = qr_recompile (id2i, NULL);
  err = qr_subq_exec_vec (qi->qi_client, id2i, qi, NULL, 0, args, ret, NULL, NULL);
  if (IS_BOX_POINTER (err))
    sqlr_resignal (err);
}


int
rb_serial_complete_len (caddr_t x)
{
  /* if complete rdf box stored in any type dc */
  rdf_box_t *rb = (rdf_box_t *) x;
  int len = 2;
  rdf_box_audit (rb);
  if (!rb->rb_is_complete)
    GPF_T1 ("non complete rb vec serialize");
  if (rb->rb_type < RDF_BOX_DEFAULT_TYPE)
    {
      if (!rb->rb_serialize_id_only)
	len += 2;
      if (rb->rb_ro_id > INT32_MAX)
	len += 8;
      else
	len += 4;
      if (!rb->rb_serialize_id_only)
	len += box_serial_length (rb->rb_box, SERIAL_LENGTH_APPROX);
      return len;
    }
  if (!rb->rb_box)
    len += 2;			/* 0 - short int */
  else if (IS_BLOB_HANDLE (rb->rb_box))
    {
      blob_handle_t *bh = (blob_handle_t *) rb->rb_box;
      len += 5;			/* long string tag + long */
      len += bh->bh_length;	/* rdf box is narrow char blob */
    }
  else if (DV_TYPE_OF (rb->rb_box) == DV_XML_ENTITY)
    {
      dk_session_t *s = strses_allocate ();
      xe_serialize ((xml_entity_t *) rb->rb_box, s);
      len += strses_length (s);
      dk_free_box (s);
    }
  else
    len += box_serial_length (rb->rb_box, 0);
  if (rb->rb_ro_id)
    {
      if (rb->rb_ro_id > INT32_MAX)
	len += 8;
      else
	len += 4;
    }
  if (RDF_BOX_DEFAULT_TYPE != rb->rb_type)
    len += 2;
  if (RDF_BOX_DEFAULT_LANG != rb->rb_lang)
    len += 2;
  if (rb->rb_chksum_tail)
    len += 1;
  return len;
}

void
rb_ext_serialize_complete (rdf_box_t * rb, dk_session_t * ses)
{
  /* non string special rdf boxes like geometry or interval or udt.  id is last  */
  dtp_t flags = RBS_EXT_TYPE;
  session_buffered_write_char (DV_RDF, ses);
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


void
rb_serialize_complete (caddr_t x, dk_session_t * ses)
{
  /* if complete rdf box stored in any type dc */
  rdf_box_t *rb = (rdf_box_t *) x;
  int flags = 0;
  if (!rb->rb_is_complete)
    GPF_T1 ("non complete rb vec serialize");
  if (rb->rb_type < RDF_BOX_DEFAULT_TYPE)
    {
      rb_ext_serialize_complete (rb, ses);
      return;
    }
  session_buffered_write_char (DV_RDF, ses);
  if (rb->rb_ro_id)
    flags |= RBS_OUTLINED;
  if (rb->rb_ro_id > INT32_MAX)
    flags |= RBS_64;
  if (RDF_BOX_DEFAULT_LANG != rb->rb_lang)
    flags |= RBS_HAS_LANG;
  if (RDF_BOX_DEFAULT_TYPE != rb->rb_type)
    flags |= RBS_HAS_TYPE;
  if (rb->rb_chksum_tail && rb->rb_ro_id)
    flags |= RBS_CHKSUM;

  flags |= RBS_COMPLETE;
  session_buffered_write_char (flags, ses);
  if (rb->rb_chksum_tail && rb->rb_ro_id)
    print_object (((rdf_bigbox_t *)rb)->rbb_chksum, ses, NULL, NULL);
  else if (!rb->rb_box)
    print_int (0, ses);		/* a zero int with should be printed with int tag for partitioning etc */
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
  if (rb->rb_chksum_tail && rb->rb_ro_id)
    session_buffered_write_char (((rdf_bigbox_t *) rb)->rbb_box_dtp, ses);

}

#define RB_SER_ERR(msg) \
{ \
  caddr_t sb = box_dv_short_string (msg); \
  dc_append_box (dc, sb); \
  dk_free_box (sb); \
  return; \
}

/*#define RB_DEBUG 1*/

void
dc_append_rb (data_col_t * dc, caddr_t data)
{
  if (DCT_BOXES & dc->dc_type)
    {
      QNCAST (rdf_bigbox_t, rb, data);
      rdf_bigbox_t *rb2 = (rdf_bigbox_t *) rb_allocate ();
      memcpy (rb2, rb, sizeof (*rb2));
      rb2->rbb_base.rb_ref_count = 1;
      rb2->rbb_base.rb_box = box_copy_tree (rb->rbb_base.rb_box);
      rb2->rbb_chksum = box_copy_tree (rb->rbb_chksum);
      ((caddr_t *) dc->dc_values)[dc->dc_n_values++] = (caddr_t) rb2;
    }
  else
    {
      int len = rb_serial_complete_len (data);
  dk_session_t sesn, *ses = &sesn;
#ifdef RB_DEBUG
      dk_session_t *ck = strses_allocate ();
#endif
  scheduler_io_data_t io;

      if (len >= MAX_READ_STRING)
	RB_SER_ERR ("*** box to large to store in any type dc");

      dc_reserve_bytes (dc, len);
      ROW_OUT_SES_2 (sesn, ((db_buf_t *) dc->dc_values)[dc->dc_n_values - 1], len);
  SESSION_SCH_DATA (ses) = &io;
  memset (SESSION_SCH_DATA (ses), 0, sizeof (scheduler_io_data_t));
      sesn.dks_out_fill = 0;

  CATCH_WRITE_FAIL (ses)
  {
    rb_serialize_complete (data, &sesn);
#ifdef RB_DEBUG
	rb_serialize_complete (data, ck);
#endif
  }
  FAILED
  {
    RB_SER_ERR ("*** error storing RB in any type dc");
  }
  END_WRITE_FAIL (ses);
#ifdef RB_DEBUG
      if (len != strses_length (ck))
	GPF_T;
      dk_free_box (ck);
      {
	caddr_t ckb;
	if (dc->dc_buf_fill + 2 <= dc->dc_buf_len)
	  *(short *) (dc->dc_buffer + dc->dc_buf_fill) = 0;
	ckb = box_deserialize_string (((caddr_t *) dc->dc_values)[dc->dc_n_values - 1], INT32_MAX, 0);
	rdf_box_audit ((rdf_box_t *) ckb);
	dk_free_box (ckb);
      }
#endif
    }
}


query_t *rb_complete_qr;


int64
dc_rb_id (data_col_t * dc, int inx)
{
  db_buf_t place = ((db_buf_t *) dc->dc_values)[inx];
  if ((DCT_BOXES & dc->dc_type))
    {
      caddr_t box = (caddr_t)place;
      dtp_t dtp = DV_TYPE_OF (box);
      if (DV_RDF == dtp)
	return ((rdf_box_t*)box)->rb_ro_id;
      return 0;
    }
  if (DV_ANY != dc->dc_sqt.sqt_dtp)
    return 0;
  if (DV_RDF_ID == place[0])
    return LONG_REF_NA (place + 1);
  else if (DV_RDF_ID_8 == place[0])
    return INT64_REF_NA (place + 1);
  else if (DV_RDF == place[0])
    {
      rdf_box_t * rb = (rdf_box_t*)box_deserialize_string (place, INT32_MAX, 0);
      int64 id = rb->rb_ro_id;
      dk_free_box ((caddr_t)rb);
      return id;
    }
  else
    return 0;
}

void
dc_set_rb (data_col_t * dc, int inx, uint32 dt_lang, int flags, caddr_t val, caddr_t lng, int64 ro_id)
{
  int save;
  rdf_bigbox_t rbbt;
  rdf_box_t *rb = (rdf_box_t *) & rbbt;
  memset (&rbbt, 0, sizeof (rbbt));
  rb->rb_ref_count = 1;
  rb->rb_ro_id = ro_id;
  rb->rb_is_complete = 1;
  rb->rb_ref_count = 1;
  rb->rb_lang = dt_lang & 0xffff;
  rb->rb_type = dt_lang >> 16;
  rb->rb_box = DV_DB_NULL == DV_TYPE_OF (lng) ? val : lng;
  if (RDF_BOX_GEO_TYPE == rb->rb_type)
    rb->rb_box = box_deserialize_string (rb->rb_box, INT32_MAX, 0);
  DC_CHECK_LEN (dc, inx);
  DC_FILL_TO (dc, int64, inx);
  save = dc->dc_n_values;
  dc->dc_n_values = inx;
  dc_append_rb (dc, (caddr_t) rb);
  dc->dc_n_values = save;
  if (RDF_BOX_GEO_TYPE == rb->rb_type)
    dk_free_box (rb->rb_box);
}

#if 0
void
bif_ro2lo_vec (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, state_slot_t * ret)
{
  static dtp_t dv_null = DV_DB_NULL;
  db_buf_t empty_mark;
  QNCAST (query_instance_t, qi, qst);
  db_buf_t set_mask = qi->qi_set_mask;
  int set, n_sets = qi->qi_n_sets, first_set = 0, is_boxes;
  int bit_len = ALIGN_8 (qi->qi_n_sets) / 8;
  db_buf_t rb_bits = NULL;
  db_buf_t save = qi->qi_set_mask;
  int *rb_sets = NULL;
  int rb_fill = 0;
  caddr_t err = NULL;
  state_slot_t *ssl = args[0];
  data_col_t *arg, *dc;
  if (!rb_complete_qr)
    {
      rb_complete_qr =
	  sql_compile_static ("select ro_dt_and_lang, ro_flags, ro_val, ro_long from rdf_obj where ro_id = rdf_box_ro_id (?)",
	  bootstrap_cli, &err, SQLC_DEFAULT);
    }

  if (!ret)
    return;
  dc = QST_BOX (data_col_t *, qst, ret->ssl_index);
  if (BOX_ELEMENTS (args) < 1)
    sqlr_new_error ("42001", "VEC..", "Not enough arguments for __ro2lo");
  arg = QST_BOX (data_col_t *, qst, ssl->ssl_index);
  if (DV_IRI_ID == arg->dc_dtp)
    {
      bif_id2i_vec (qst, err_ret, args, ret);
      return;
    }
  if (DCT_NUM_INLINE & arg->dc_type || DV_DATETIME == dtp_canonical[arg->dc_dtp] || DV_IRI_ID == arg->dc_dtp)
    {
      vec_ssl_assign (qst, ret, args[0]);
      return;
    }
  if (DV_ANY != dc->dc_dtp && DV_ARRAY_OF_POINTER != dc->dc_dtp)
    {
      SET_LOOP
      {
	dc_assign (qst, ret, set, args[0], set);
      }
      END_SET_LOOP;
      return;
    }
  is_boxes = DCT_BOXES & arg->dc_type;
  empty_mark = is_boxes ? NULL : &dv_null;
  DC_CHECK_LEN (dc, qi->qi_n_sets - 1);
  SET_LOOP
  {
    db_buf_t dv;
    dtp_t dtp;
    int row_no = set;
    if (SSL_REF == ssl->ssl_type)
      row_no = sslr_set_no (qst, ssl, row_no);
    dv = ((db_buf_t *) arg->dc_values)[row_no];
    dtp = is_boxes ? DV_TYPE_OF (dv) : dv[0];
    if (DV_RDF_ID == dtp || DV_RDF_ID_8 == dtp || (DV_RDF == dtp && is_boxes && !((rdf_box_t *) dv)->rb_is_complete))
      {
	if (!rb_bits)
	  {
	    rb_bits = dc_alloc (arg, bit_len);
	    memset (rb_bits, 0, bit_len);
	    rb_sets = (int *) dc_alloc (arg, sizeof (int) * qi->qi_n_sets);
	  }
	rb_sets[rb_fill++] = set;
	rb_bits[set >> 3] |= 1 << (set & 7);
	((db_buf_t *) dc->dc_values)[set] = empty_mark;
      }
    else
      {
	dc_assign (qst, ret, set, args[0], set);
      }
  }
  END_SET_LOOP;
  dc->dc_n_values = MAX (dc->dc_n_values, qi->qi_set + 1);
  if (rb_bits)
    {
      int inx, n_res = 0;
      local_cursor_t lc;
      select_node_t *sel = rb_complete_qr->qr_select_node;
      qi->qi_set_mask = rb_bits;
      memset (&lc, 0, sizeof (lc));
      err = qr_subq_exec_vec (qi->qi_client, rb_complete_qr, qi, NULL, 0, args, ret, NULL, &lc);
      if (err)
	sqlr_resignal (err);
      while (lc_next (&lc))
	{
	  int set = qst_vec_get_int64 (lc.lc_inst, sel->sel_set_no, lc.lc_position);
	  uint32 dt_lang = qst_vec_get_int64  (lc.lc_inst, sel->sel_out_slots[0], lc.lc_position);
	  int flags = qst_vec_get_int64 (lc.lc_inst, sel->sel_out_slots[1], lc.lc_position);
	  caddr_t val = lc_nth_col (&lc, 2);
	  caddr_t lng = lc_nth_col (&lc, 3);
	  int out_set = rb_sets[set];
	  int arg_row = sslr_set_no (qst, args[0], out_set);
	  int64 ro_id = dc_rb_id (arg, arg_row);
	  dc_set_rb (dc, out_set, dt_lang, flags, val, lng, ro_id);
	  n_res++;
	}
      for (inx = 0; inx < dc->dc_n_values; inx++)
	{
	  if (BIT_IS_SET (rb_bits, inx))
	    {
	      if (empty_mark == ((db_buf_t *) dc->dc_values)[inx])
		{
		  dc->dc_any_null = 1;
		  bing ();
		}
	    }
	}
      if (lc.lc_inst)
	qi_free (lc.lc_inst);
      if (lc.lc_error)
	sqlr_resignal (lc.lc_error);
    }
  qi->qi_set_mask = save;
}

#endif


void
dc_no_empty_marks (data_col_t * dc, db_buf_t empty_mark)
{
  /* the empty mark is an illegal value in a boxes dc.  sset them to 0 before signalling anything.
  * For a dc of anies it is a statis dv db null which is ok whereas null pointer is not */
  static dtp_t dv_null = DV_DB_NULL;
  int inx;
  db_buf_t subst_empty = (DCT_BOXES & dc->dc_type) ? NULL : &dv_null;
  for (inx = 0; inx < dc->dc_n_values; inx++)
    {
      if (empty_mark == ((db_buf_t *) dc->dc_values)[inx])
	((db_buf_t *)dc->dc_values)[inx] = subst_empty;
    }
}


void
bif_ro2sq_vec_1 (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, state_slot_t * ret, int no_iris)
{
  static dtp_t dv_null = DV_DB_NULL;
  db_buf_t empty_mark;
  QNCAST (query_instance_t, qi, qst);
  db_buf_t set_mask = qi->qi_set_mask;
  int set, n_sets = qi->qi_n_sets, first_set = 0, is_boxes;
  int bit_len = ALIGN_8 (qi->qi_n_sets) / 8;
  db_buf_t rb_bits = NULL, iri_bits = NULL;
  db_buf_t save = qi->qi_set_mask;
  int *rb_sets = NULL;
  int rb_fill = 0;
  caddr_t err = NULL;
  state_slot_t *ssl = args[0];
  data_col_t *arg, *dc;
  if (!rb_complete_qr)
    {
      rb_complete_qr =
	  sql_compile_static
	  ("select RO_DT_AND_LANG, RO_FLAGS, RO_VAL, blob_to_string (RO_LONG) from DB.DBA.RDF_OBJ where RO_ID = rdf_box_ro_id (?)",
	  qi->qi_client, &err, SQLC_DEFAULT);
      if (err)
	sqlr_resignal (err);
    }

  if (!ret)
    return;
  dc = QST_BOX (data_col_t *, qst, ret->ssl_index);
  if (BOX_ELEMENTS (args) < 1)
    sqlr_new_error ("42001", "VEC..", "Not enough arguments for __ro2sq");
  arg = QST_BOX (data_col_t *, qst, ssl->ssl_index);
  if (DV_IRI_ID == arg->dc_dtp && !no_iris)
    {
      bif_id2i_vec (qst, err_ret, args, ret);
      return;
    }
  if (DCT_NUM_INLINE & arg->dc_type || DV_DATETIME == dtp_canonical[arg->dc_dtp])
    {
      vec_ssl_assign (qst, ret, args[0]);
      return;
    }
  if (DV_ANY != ret->ssl_sqt.sqt_dtp && DV_ARRAY_OF_POINTER != ret->ssl_sqt.sqt_dtp)
    {
      SET_LOOP
      {
	dc_assign (qst, ret, set, args[0], set);
      }
      END_SET_LOOP;
      return;
    }
  if (DV_ANY == ret->ssl_sqt.sqt_dtp && DV_ANY != dc->dc_dtp)
    dc_heterogenous (dc);
  is_boxes = DCT_BOXES & arg->dc_type;
  empty_mark = (DCT_BOXES & dc->dc_type) ? NULL : &dv_null;
  DC_CHECK_LEN (dc, qi->qi_n_sets - 1);
  if (DCT_BOXES & dc->dc_type)
    DC_FILL_TO (dc, int64, qi->qi_n_sets);
  if (DV_ANY == dc->dc_dtp)
    DC_FILL_TO (dc, caddr_t, qi->qi_n_sets);
  SET_LOOP
  {
    db_buf_t dv;
    dtp_t dtp;
    int row_no = set;
    if (SSL_REF == ssl->ssl_type)
      row_no = sslr_set_no (qst, ssl, row_no);
    dv = ((db_buf_t *) arg->dc_values)[row_no];
    dtp = is_boxes ? DV_TYPE_OF (dv) : dv[0];
    if (DV_RDF_ID == dtp || DV_RDF_ID_8 == dtp
	|| (DV_RDF == dtp && (is_boxes ? !((rdf_box_t *) dv)->rb_is_complete : !(RBS_COMPLETE & dv[1]))))
      {
	if (!rb_bits)
	  {
	    rb_bits = dc_alloc (arg, bit_len);
	    memset (rb_bits, 0, bit_len);
	    rb_sets = (int *) dc_alloc (arg, sizeof (int) * qi->qi_n_sets);
	  }
	rb_sets[rb_fill++] = set;
	rb_bits[set >> 3] |= 1 << (set & 7);
	((db_buf_t *) dc->dc_values)[set] = empty_mark;
	dc->dc_n_values = MAX (dc->dc_n_values, set + 1);
      }
    else if ((DV_IRI_ID == dtp || DV_IRI_ID_8 == dtp) && !no_iris)
      {
	if (!iri_bits)
	  {
	    iri_bits = dc_alloc (arg, bit_len);
	    memset (iri_bits, 0, bit_len);
	  }
	iri_bits[set >> 3] |= 1 << (set & 7);
	((db_buf_t *) dc->dc_values)[set] = empty_mark;
	dc->dc_n_values = MAX (dc->dc_n_values, set + 1);
      }
    else
      {
	dc_assign (qst, ret, set, args[0], set);
      }
  }
  END_SET_LOOP;
  dc->dc_n_values = MAX (dc->dc_n_values, qi->qi_set + 1);
  if (rb_bits)
    {
      int inx, n_res = 0;
      local_cursor_t lc;
      select_node_t *sel = rb_complete_qr->qr_select_node;
      qi->qi_set_mask = rb_bits;
      memset (&lc, 0, sizeof (lc));
      err = qr_subq_exec_vec (qi->qi_client, rb_complete_qr, qi, NULL, 0, args, ret, NULL, &lc);
      if (err)
	{
	  dc_no_empty_marks (dc, empty_mark);
	sqlr_resignal (err);
	}
      while (lc_next (&lc))
	{
	  int set = qst_vec_get_int64 (lc.lc_inst, sel->sel_set_no, lc.lc_position);
	  int dt_lang = qst_vec_get_int64 (lc.lc_inst, sel->sel_out_slots[0], lc.lc_position);
	  int flags = qst_vec_get_int64 (lc.lc_inst, sel->sel_out_slots[1], lc.lc_position);
	  caddr_t val = lc_nth_col (&lc, 2);
	  caddr_t lng = lc_nth_col (&lc, 3);
	  int out_set = rb_sets[set];
	  int arg_row = sslr_set_no (qst, args[0], out_set);
	  int64 ro_id = dc_rb_id (arg, arg_row);
	  dc_set_rb (dc, out_set, dt_lang, flags, val, lng, ro_id);
	  n_res++;
	}
      for (inx = 0; inx < dc->dc_n_values; inx++)
	{
	  if (BIT_IS_SET (rb_bits, inx))
	    {
	      if (empty_mark == ((db_buf_t *) dc->dc_values)[inx])
		{
		  dc->dc_any_null = 1;
		  dc_no_empty_marks (dc, empty_mark);
		  bing ();
		}
	}
	}
      if (lc.lc_inst)
	qi_free (lc.lc_inst);
      if (lc.lc_error)
	{
	  dc_no_empty_marks (dc, empty_mark);
	sqlr_resignal (lc.lc_error);
	}
    }
  if (iri_bits)
    {
      qi->qi_set_mask = iri_bits;
      dc_no_empty_marks (dc, empty_mark);
      bif_id2i_vec (qst, err_ret, args, ret);
    }
  qi->qi_set_mask = save;
}


void
bif_ro2sq_vec (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, state_slot_t * ret)
{
  bif_ro2sq_vec_1 (qst, err_ret, args, ret, 0);
}


void
bif_ro2lo_vec (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, state_slot_t * ret)
{
  bif_ro2sq_vec_1 (qst, err_ret, args, ret, 1);
}

query_t *rb_ebv_of_ro_qr;

void
bif_ro2ebv_vec (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, state_slot_t * ret)
{
  static dtp_t dv_null = DV_DB_NULL;
  db_buf_t empty_mark;
  QNCAST (query_instance_t, qi, qst);
  db_buf_t set_mask = qi->qi_set_mask;
  int set, n_sets = qi->qi_n_sets, first_set = 0, is_boxes;
  int bit_len = ALIGN_8 (qi->qi_n_sets) / 8;
  db_buf_t rb_bits = NULL, iri_bits = NULL;
  db_buf_t save = qi->qi_set_mask;
  int * rb_sets = NULL;
  int rb_fill = 0;
  caddr_t err = NULL;
  state_slot_t * ssl = args[0];
  data_col_t * arg, *dc;
  if (!rb_ebv_of_ro_qr)
    {
      rb_ebv_of_ro_qr = sql_compile_static ("select case \
  when __rdf_dt_and_lang_flags(RO_DT_AND_LANG, 1) then case when __tag(RO_VAL) in __tag of varchar, __tag of null then null when 0 then 0 else 1 end \
  when RO_VAL is null then 1 \
  when RO_VAL = '' then 0 \
  else 1 end \
from DB.DBA.RDF_OBJ where RO_ID = rdf_box_ro_id (?)", qi->qi_client, &err, SQLC_DEFAULT);
      if (err)
        sqlr_resignal (err);
    }

  if (!ret)
    return;
  dc = QST_BOX (data_col_t *, qst, ret->ssl_index);
  if (BOX_ELEMENTS (args) < 1) 
    sqlr_new_error ("42001", "VEC..", "Not enough arguments for __ro2ebv");
  arg = QST_BOX (data_col_t *, qst, ssl->ssl_index);  

  if (DV_ANY == ret->ssl_sqt.sqt_dtp && DV_ANY != dc->dc_dtp)
    dc_heterogenous (dc);
  is_boxes = DCT_BOXES & arg->dc_type;
  empty_mark = (DCT_BOXES & dc->dc_type) ? NULL : &dv_null;
  DC_CHECK_LEN (dc, qi->qi_n_sets - 1);
  if (DCT_BOXES & dc->dc_type)
    DC_FILL_TO (dc, int64, qi->qi_n_sets);
  if (DV_ANY == dc->dc_dtp)
    DC_FILL_TO (dc, caddr_t, qi->qi_n_sets);
  SET_LOOP 
    {
      db_buf_t dv;
      dtp_t dtp;
      int row_no = set;
      if (SSL_REF == ssl->ssl_type)
	row_no = sslr_set_no (qst, ssl, row_no);
      dv = ((db_buf_t *)arg->dc_values)[row_no];
      dtp = is_boxes ? DV_TYPE_OF (dv) : dv[0];
      if (DV_RDF_ID == dtp || DV_RDF_ID_8 == dtp
        || (DV_RDF == dtp &&
          (is_boxes ? !((rdf_box_t*)dv)->rb_is_complete : !(RBS_COMPLETE & dv[1])) ) )
	{
	  if (!rb_bits)
	    {
	      rb_bits = dc_alloc (arg, bit_len);
	      memset (rb_bits, 0, bit_len);
	      rb_sets = (int*)dc_alloc (arg, sizeof (int) * qi->qi_n_sets);
	    }
	  rb_sets[rb_fill++] = set;
	  rb_bits[set >> 3] |= 1 << (set & 7);
	  ((db_buf_t*)dc->dc_values)[set] = empty_mark;
	  dc->dc_n_values = MAX (dc->dc_n_values, set + 1);
	}
#if 0 /* write something meaningful here */
      else if ((DV_IRI_ID == dtp || DV_IRI_ID_8 == dtp))
	{
	  if (!iri_bits)
	    {
	      iri_bits = dc_alloc (arg, bit_len);
	      memset (iri_bits, 0, bit_len);
	    }
	  iri_bits[set >> 3] |= 1 << (set & 7);
	  ((db_buf_t*)dc->dc_values)[set] = empty_mark;
	  dc->dc_n_values = MAX (dc->dc_n_values, set + 1);
	}
      else
	{
	  dc_assign (qst, ret, set, args[0], set);
	}
#endif
    }
  END_SET_LOOP;
  dc->dc_n_values = MAX (dc->dc_n_values, qi->qi_set + 1);
#if 0 /* write something meaningful here */
  if (rb_bits)
    {
      int inx, n_res = 0;
      local_cursor_t lc;
      select_node_t * sel = rb_complete_qr->qr_select_node;
      qi->qi_set_mask = rb_bits;
      memset (&lc, 0, sizeof (lc));
      err = qr_subq_exec_vec (qi->qi_client, rb_complete_qr, qi, NULL, 0, args, ret, NULL, &lc);
      if (err)
	{
	  dc_no_empty_marks (dc, empty_mark);
	  sqlr_resignal (err);
	}
      while (lc_next (&lc))
	{
	  int set = qst_vec_get_int64  (lc.lc_inst, sel->sel_set_no, lc.lc_position);
	  int dt_lang = qst_vec_get_int64  (lc.lc_inst, sel->sel_out_slots[0], lc.lc_position);
	  int flags = qst_vec_get_int64  (lc.lc_inst, sel->sel_out_slots[1], lc.lc_position);
	  caddr_t  val = lc_nth_col (&lc, 2);
	  caddr_t  lng = lc_nth_col (&lc, 3);
	  int out_set = rb_sets[set];
	  int arg_row = sslr_set_no (qst, args[0], out_set);
	  int64 ro_id = dc_rb_id (arg, arg_row);
	  dc_set_rb (dc, out_set, dt_lang, flags, val, lng, ro_id);
	  n_res++;
	}
      for (inx = 0; inx <dc->dc_n_values; inx++)
	{
	  if (BIT_IS_SET (rb_bits, inx))
	    { 
	      if (empty_mark == ((db_buf_t*)dc->dc_values)[inx])
		{
		  dc->dc_any_null = 1;
		  dc_no_empty_marks (dc, empty_mark);
		  bing ();
		}
	    }
	}
      if (lc.lc_inst)
	qi_free (lc.lc_inst);
      if (lc.lc_error)
	{
	  dc_no_empty_marks (dc, empty_mark);
	  sqlr_resignal (lc.lc_error);
	}
    }
  if (iri_bits)
    {
      qi->qi_set_mask = iri_bits;
      dc_no_empty_marks (dc, empty_mark);
      bif_id2i_vec (qst, err_ret, args, ret);
    }
#endif
  qi->qi_set_mask = save;
}

void
rbs_string_range (dtp_t ** buf, int * len, int * is_string)
{
  /* the partition hash of a any type col with an rdf box value does not depend on all bytes but only the value serialization, not the flags and ro ids */
  dtp_t * rbs = *buf;
  dtp_t flags = rbs[1];
  if (RBS_EXT_TYPE & flags)
    {
      *is_string = 0;
      return;
    }
  if (RBS_SKIP_DTP & flags)
    {
      *buf += 3;
      *is_string = 1;
      *len = rbs[2];
      return;
    }
  if (DV_SHORT_STRING_SERIAL == rbs[2])
    {
      *len = rbs[3];
      *is_string = 1;
      *buf += 4;
    }
  else if (DV_STRING == rbs[2])
    {
      *len = LONG_REF_NA (rbs + 3);
      *is_string = 1;
      *buf += 7;
    }
  else
    *is_string = 0;
}

extern int rb_type__xsd_boolean;

void
bif_str_vec (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, state_slot_t * ret)
{
  QNCAST (QI, qi, qst);
  data_col_t * dc;
  db_buf_t set_mask = qi->qi_set_mask;
  int set, n_sets = qi->qi_n_sets, first_set = 0;
  state_slot_t ssl_tmp;
  if (BOX_ELEMENTS (args) > 1 && !(SSL_CONSTANT == args[1]->ssl_type && 0 == unbox (args[1]->ssl_constant)))
    {
      *err_ret = BIF_NOT_VECTORED;
      return;
    }
  memcpy (&ssl_tmp, ret, sizeof (state_slot_t));
  if (ret->ssl_dc_dtp == DV_ANY)
    ssl_tmp.ssl_dtp = DV_ANY;
  bif_ro2sq_vec_1 (qst, err_ret, args, &ssl_tmp, 0);
  dc = QST_BOX (data_col_t *, qst, ret->ssl_index);
  if (dc->dc_dtp != DV_ANY)
    dc_heterogenous (dc);
  SET_LOOP 
    {
      db_buf_t dv = ((db_buf_t*)dc->dc_values)[set];
      switch (*dv)
	{
	case DV_BOX_FLAGS:
	  ((db_buf_t*)dc->dc_values)[set] += 5;
	  break;
	case DV_RDF:
	  {
	    int len, is_string = 0;
	    rbs_string_range (&dv, &len, &is_string);
	    if (!is_string)
              {
                rdf_box_t *rb = box_deserialize_string (dv, INT32_MAX, 0);
                if ((rb_type__xsd_boolean == rb->rb_type) && (DV_LONG_INT == DV_TYPE_OF (rb->rb_box)))
                  {
                    int save = dc->dc_n_values;
                    dc->dc_n_values = set;
                    dc_append_box (dc, box_dv_short_string (unbox (rb->rb_box) ? uname_true : uname_false));
                    dc->dc_n_values = save;
                    dk_free_box (rb);
                    break;
                  }
                if (DV_DATETIME == DV_TYPE_OF (rb->rb_box))
                  {
                    char temp[100];
                    int mode = DT_PRINT_MODE_XML | dt_print_flags_of_rb_type (rb->rb_type);
                    int save = dc->dc_n_values;
                    dc->dc_n_values = set;
                    dt_to_iso8601_string_ext (rb->rb_box, temp, sizeof (temp), mode);
                    dc_append_box (dc, box_dv_short_string (temp));
                    dc->dc_n_values = save;
                    dk_free_box (rb);
                    break;
                  }
                dk_free_box (rb);
	        goto general;
              }
	    if (len < 256)
	      {
		dv[-1] = len;
		dv[-2] = DV_SHORT_STRING_SERIAL;
		((db_buf_t*)dc->dc_values)[set] = dv - 2;
	      }
	    else
	      ((db_buf_t *)dc->dc_values)[set] = dv - 5;
	    break;
	  }
	case DV_STRING:
	case DV_DB_NULL:
	  break;
	default:
	  {
	    caddr_t err;
	    caddr_t box;
	    caddr_t cast;
	  general:
	    err = NULL;
	    box = qst_get (qst, ret);
            if (DV_DATETIME == DV_TYPE_OF (box))
              {
                char temp[100];
                int mode = DT_PRINT_MODE_XML;
                dt_to_iso8601_string_ext (box, temp, sizeof (temp), mode);
                cast = box_dv_short_string (temp);
              }
            else
	      cast = box_cast_to (qst, box, DV_TYPE_OF (box), DV_STRING, 0, 0, &err);
	    if (err)
	      {
		dk_free_tree (err);
		dc_set_null (dc, set);
	      }
	    else
	      {
		int save = dc->dc_n_values;
		dc->dc_n_values = set;
		dc_append_box (dc, cast);
		dc->dc_n_values = save;
		dk_free_tree (cast);
	      }
	  }
	}
    }
  END_SET_LOOP;
}

void cu_rl_local_exec (cucurbit_t * cu);

void
bif_iri_to_id_vec (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, state_slot_t * ret)
{
  static char * cl_op_name = "IRI_TO_ID_1";
  static char * op_name = "L_IRI_TO_ID";
  QNCAST (QI, qi, qst);
  db_buf_t set_mask = qi->qi_set_mask;
  int set, n_sets = qi->qi_n_sets, first_set = 0;
  int n_args = BOX_ELEMENTS (args);
  cl_req_group_t * clrg;
  cucurbit_t * cu;
  int is_cl = CL_RUN_CLUSTER == cl_run_local_only;
  if (1 != n_args)
    {
      *err_ret = BIF_NOT_VECTORED;
      return;
    }
  clrg = dpipe_allocate (qi, 0, 1, is_cl ? &cl_op_name : &op_name);
  cu = clrg->clrg_cu;
  cu->cu_is_ordered = 1;
  cu->cu_qst = qst;
  mp_comment (clrg->clrg_pool, "vec_iri ", "");
  QR_RESET_CTX
    {
      SET_LOOP 
	{
	  cu_ssl_row (cu, qst, args, 0);
	}
      END_SET_LOOP;
      if (!is_cl)
	{
	  cu_rl_local_exec (cu);
	}
      first_set = 0;
      SET_LOOP
	{
	  caddr_t * r = cu_next (clrg->clrg_cu, qi, 0);
	  qst_set_over (qst, ret, r[2]);
	}
      END_SET_LOOP;
      if (is_cl)
	cu_next (clrg->clrg_cu, qi, 1);
    }
  QR_RESET_CODE
    {
      POP_QR_RESET;
      dk_free_box ((caddr_t)clrg);
      longjmp_splice (__self->thr_reset_ctx, reset_code);
    }
  END_QR_RESET;
  dk_free_box ((caddr_t) clrg);
}
