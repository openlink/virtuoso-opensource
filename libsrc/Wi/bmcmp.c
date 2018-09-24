/*
 *  bmcmp.c
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2018 OpenLink Software
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

#define DC_INT(dc, sets, set) ((int64*)dc->dc_values)[sets[set]]
#define DC_ANY(dc, sets, set) ((db_buf_t*)dc->dc_values)[sets[set]]

caddr_t
bif_bm_cmp (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  sqlr_new_error ("42000", "BMCMPV", "bm_cmp is only for vectored contexts");
  return NULL;
}

double
bm_cmp (int64 x1, int64 y1, int64 x2, int64 y2, db_buf_t bm1, int l1, db_buf_t bm2, int l2)
{
  int total_len = l1 + l2, min_len, inx, ones = 0;
  min_len = MIN (l1, l2);
  for (inx = 0; inx < min_len; inx++)
    {
      ones += byte_logcount[bm1[inx] & bm2[inx]];
    }
  return (double) ones / total_len;
}


int *
dc_sets (caddr_t * inst, state_slot_t * ssl, data_col_t ** dc_ret, dtp_t dtp, data_col_t * tmp_dc)
{
  int *sets;
  data_col_t *dc;
  QNCAST (QI, qi, inst);
  dc = *dc_ret = QST_BOX (data_col_t *, inst, ssl->ssl_index);
  if (dtp != (*dc_ret)->dc_sqt.sqt_dtp && !(DV_ANY == dtp && (DCT_BOXES & dc->dc_type)))

    sqlr_new_error ("42000", "BMCAR", "Wrong type argument %s, expected %s", dv_type_title (dc->dc_sqt.sqt_dtp),
	dv_type_title (dtp));
  sets = (int *) dc_alloc (tmp_dc, sizeof (int) * qi->qi_n_sets);
  if (SSL_VEC == ssl->ssl_type)
    int_asc_fill (sets, qi->qi_n_sets, 0);
  else if (SSL_REF == ssl->ssl_type)
    sslr_n_consec_ref (inst, (state_slot_ref_t *) ssl, sets, 0, qi->qi_n_sets);
  else
    sqlr_new_error ("42000", "BMCVC", "bm_cmp expects vector arguments");
  return sets;
}


db_buf_t
dc_string (caddr_t * qst, data_col_t * dc, int *sets, int set, int *len_ret, caddr_t * to_free_ret)
{
  *to_free_ret = NULL;
  if ((DCT_BOXES & dc->dc_type))
    {
      caddr_t box = ((caddr_t *) dc->dc_values)[sets[set]];
      dtp_t dtp = DV_TYPE_OF (box);
      switch (dtp)
	{
	case DV_STRING:
	  *len_ret = box_length (box) - 1;
	  return (db_buf_t) box;
	case DV_BIN:
	  *len_ret = box_length (box) - 1;
	  return (db_buf_t) box;
	case DV_BLOB_HANDLE:
	  *to_free_ret = blob_to_string (((QI *) qst)->qi_trx, box);
	  *len_ret = box_length (*to_free_ret) - (DV_STRINGP (*to_free_ret) ? 1 : 0);
	  return (db_buf_t) * to_free_ret;
	default:
	  sqlr_new_error ("42000", "", "expected string or binary arg, got %s", dv_type_title (dtp));
	}
    }
  else if (DV_ANY == dc->dc_sqt.sqt_dtp)
    {
      db_buf_t dv = ((db_buf_t *) dc->dc_values)[sets[set]];
      switch (*dv)
	{
	case DV_SHORT_STRING_SERIAL:
	case DV_BIN:
	  *len_ret = dv[1];
	  return dv + 2;
	case DV_STRING:
	case DV_LONG_BIN:
	  *len_ret = LONG_REF_NA (dv + 1);
	  return dv + 5;
	default:
	  sqlr_new_error ("42000", "", "Expected string or binary arg, got %s", dv_type_title (*dv));
	}
    }
  else
    sqlr_new_error ("42000", "", "Expected vector of boxes or anies, got %s", dv_type_title (dc->dc_sqt.sqt_dtp));
  return NULL;
}

void
bif_bm_cmp_vec (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, state_slot_t * ret)
{
  QNCAST (QI, qi, qst);
  int first_set = 0, set, n_sets = qi->qi_n_sets;
  data_col_t *x1_dc, *x2_dc, *y1_dc, *y2_dc, *bm1_dc, *bm2_dc;
  int *x1_sets, *x2_sets, *y1_sets, *y2_sets, *bm1_sets, *bm2_sets;
  data_col_t *ret_dc = QST_BOX (data_col_t *, qst, ret->ssl_index);
  db_buf_t set_mask = qi->qi_set_mask;
  if (BOX_ELEMENTS (args) < 6)
    sqlr_new_error ("BMVAR", "BMVAR", "Too few arguments for bm_cmp");
  x1_sets = dc_sets (qst, args[0], &x1_dc, DV_LONG_INT, ret_dc);
  y1_sets = dc_sets (qst, args[1], &y1_dc, DV_LONG_INT, ret_dc);
  x2_sets = dc_sets (qst, args[2], &x2_dc, DV_LONG_INT, ret_dc);
  y2_sets = dc_sets (qst, args[3], &y2_dc, DV_LONG_INT, ret_dc);
  bm1_sets = dc_sets (qst, args[4], &bm1_dc, DV_ANY, ret_dc);
  bm2_sets = dc_sets (qst, args[5], &bm2_dc, DV_ANY, ret_dc);
  DC_CHECK_LEN (ret_dc, n_sets - 1);
  dc_reset (ret_dc);
  SET_LOOP
  {
    double score;
    int l1, l2;
    caddr_t tmp1, tmp2;
    db_buf_t bits1 = dc_string (qst, bm1_dc, bm1_sets, set, &l1, &tmp1);
    db_buf_t bits2 = dc_string (qst, bm2_dc, bm2_sets, set, &l2, &tmp2);
    score = bm_cmp (DC_INT (x1_dc, x1_sets, set), DC_INT (y1_dc, y1_sets, set),
	DC_INT (x2_dc, x2_sets, set), DC_INT (y2_dc, y2_sets, set), bits1, l1, bits2, l2);
    ((double *) ret_dc->dc_values)[set] = score;
    ret_dc->dc_n_values = set + 1;
    if (tmp1)
      dk_free_box (tmp1);
    if (tmp2)
      dk_free_box (tmp2);
  }
  END_SET_LOOP;
  dc_reset_alloc (ret_dc);
}


void
bm_cmp_init ()
{
  bif_define_typed ("bm_cmp", bif_bm_cmp, &bt_double);
  bif_set_vectored (bif_bm_cmp, bif_bm_cmp_vec);
}
