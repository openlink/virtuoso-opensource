/*
 *  vecrdf.c
 *
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2011 OpenLink Software
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
  if (rb->rb_chksum_tail)
    flags |= RBS_CHKSUM;

  flags |= RBS_COMPLETE;
  session_buffered_write_char (flags, ses);
  if (!rb->rb_box)
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
  if (rb->rb_chksum_tail)
    session_buffered_write_char (((rdf_bigbox_t *) rb)->rbb_box_dtp, ses);

}

#define RB_SER_ERR(msg) \
{ \
  caddr_t sb = box_dv_short_string (msg); \
  dc_append_box (dc, sb); \
  dk_free_box (sb); \
  return; \
}


void
dc_append_rb (data_col_t * dc, caddr_t data)
{
  int init, len;
  dtp_t key_image[PAGE_DATA_SZ];
  dk_session_t sesn, *ses = &sesn;
  scheduler_io_data_t io;
  ROW_OUT_SES (sesn, key_image);
  SESSION_SCH_DATA (ses) = &io;
  memset (SESSION_SCH_DATA (ses), 0, sizeof (scheduler_io_data_t));
  init = sesn.dks_out_fill;

  CATCH_WRITE_FAIL (ses)
  {
    rb_serialize_complete (data, &sesn);
  }
  FAILED
  {
    RB_SER_ERR ("*** error storing RB in any type dc");
  }
  END_WRITE_FAIL (ses);

  if (sesn.dks_out_fill > PAGE_DATA_SZ - 10)
    {
      RB_SER_ERR ("*** rdf box too long to serialize in any type dc");
      return;
    }
  len = sesn.dks_out_fill - init;
  dc_append_bytes (dc, (db_buf_t) sesn.dks_out_buffer + init, len, NULL, 0);
}


query_t *rb_complete_qr;


int64
dc_rb_id (data_col_t * dc, int inx)
{
  db_buf_t place = ((db_buf_t *) dc->dc_values)[inx];
  if (DV_RDF_ID == place[0])
    return LONG_REF_NA (place + 1);
  else
    return INT64_REF_NA (place + 1);
}

void
dc_set_rb (data_col_t * dc, int inx, int dt_lang, int flags, caddr_t val, caddr_t lng, int64 ro_id)
{
  int save;
  rdf_bigbox_t rbbt;
  rdf_box_t *rb = (rdf_box_t *) & rbbt;
  memset (&rbbt, 0, sizeof (rbbt));
  rb->rb_ro_id = ro_id;
  rb->rb_is_complete = 1;
  rb->rb_lang = dt_lang & 0xffff;
  rb->rb_type = dt_lang >> 16;
  rb->rb_box = DV_DB_NULL == DV_TYPE_OF (lng) ? val : lng;
  DC_CHECK_LEN (dc, inx);
  save = dc->dc_n_values;
  dc->dc_n_values = inx;
  dc_append_rb (dc, (caddr_t) rb);
  dc->dc_n_values = save;
}


void
bif_ro2sq_vec (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, state_slot_t * ret)
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
	  sql_compile_static ("select ro_dt_and_lang, ro_flags, ro_val, ro_long from rdf_obj where ro_id = rdf_box_ro_id (?)",
	  bootstrap_cli, &err, SQLC_DEFAULT);
    }

  if (!ret)
    return;
  dc = QST_BOX (data_col_t *, qst, ret->ssl_index);
  if (BOX_ELEMENTS (args) < 1)
    sqlr_new_error ("42001", "VEC..", "Not enough arguments for __ro2sq");
  arg = QST_BOX (data_col_t *, qst, ssl->ssl_index);
  if (DV_IRI_ID == arg->dc_dtp)
    {
      bif_id2i_vec (qst, err_ret, args, ret);
      return;
    }
  if (DCT_NUM_INLINE & arg->dc_type || DV_DATETIME == dtp_canonical[arg->dc_dtp])
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
    else if (DV_IRI_ID == dtp || DV_IRI_ID_8 == dtp)
      {
	if (!iri_bits)
	  {
	    iri_bits = dc_alloc (arg, bit_len);
	    memset (iri_bits, 0, bit_len);
	  }
	iri_bits[set >> 3] |= 1 << (set & 7);
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
	  int dt_lang = qst_vec_get_int64 (lc.lc_inst, sel->sel_out_slots[0], lc.lc_position);
	  int flags = qst_vec_get_int64 (lc.lc_inst, sel->sel_out_slots[1], lc.lc_position);
	  caddr_t val = lc_nth_col (&lc, 2);
	  caddr_t lng = lc_nth_col (&lc, 3);
	  int out_set = rb_sets[set];
	  int arg_row = sslr_set_no (qst, args[0], out_set);
	  int64 ro_id = dc_rb_id (arg, arg_row);
	  dc_set_rb (dc, out_set, dt_lang, flags, val, lng, ro_id);
	}
      if (lc.lc_error)
	sqlr_resignal (lc.lc_error);
      qi_free (lc.lc_inst);
    }
  if (iri_bits)
    {
      qi->qi_set_mask = iri_bits;
      bif_id2i_vec (qst, err_ret, args, ret);
    }
  qi->qi_set_mask = save;
}
