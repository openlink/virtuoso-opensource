/*
 *  cedictad.c
 *
 *  $Id$
 *
 *  Decode of any type dict
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2019 OpenLink Software
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



int
name (col_pos_t * cpo, db_buf_t ce_first, int n_values, int n_bytes)
{
  data_col_t *dc = cpo->cpo_dc;
  db_buf_t values;
  db_buf_t value_ptr[256];
  dtp_t n_distinct = ce_first[0];
  int fill = dc->dc_n_values, last_row = cpo->cpo_ce_row_no;
  int last = MIN (n_values, cpo->cpo_to - last_row);
  int len, row = cpo->cpo_skip, v_inx;
  db_buf_t val, array, dict = ce_first + 1;
  VARS;
  if (DCT_BOXES & dc->dc_type)
    return 0;
  CE_ANY_NTH (dict, n_distinct, n_distinct - 1, array, len);
  array += len;
  v_inx = VEC_INX (array, row);
  CE_ANY_NTH (dict, n_distinct, v_inx, val, len);
  if (0 == dc->dc_n_values && DV_ANY == dc->dc_sqt.sqt_col_dtp && DV_DB_NULL != *val)
    dc_convert_empty (dc, dv_ce_dtp[*val]);
  if (DV_ANY != dc->dc_dtp && dc->dc_dtp != dtp_canonical[*val] && DV_DB_NULL != *val && DV_ANY == dc->dc_sqt.sqt_col_dtp)
    {
      dc_heterogenous (dc);
    }
  values = dc->dc_values;

  switch (dc->dc_dtp)
    {
    case DV_LONG_INT:
    case DV_IRI_ID:
    case DV_DOUBLE_FLOAT:
      for (;;)
	{
	  int64 n64 = 0;
	  switch (*val)
	    {
	    case DV_SHORT_INT:
	      n64 = *(signed char *) (val + 1);
	      break;
	    case DV_IRI_ID:
	      n64 = (uint32) LONG_REF_NA (val + 1);
	      break;
	    case DV_LONG_INT:
	      n64 = LONG_REF_NA (val + 1);
	      break;
	    case DV_DOUBLE_FLOAT:
	    case DV_INT64:
	    case DV_IRI_ID_8:
	      n64 = INT64_REF_NA (val + 1);
	      break;
	    case DV_DB_NULL:
	      dc_set_null (dc, fill);
	      break;
	    }
	  ((int64 *) values)[fill++] = n64;
	  END_TEST;
	  CE_ANY_NTH (dict, n_distinct, v_inx, val, len);
	  if (dc->dc_dtp != dtp_canonical[*val] && DV_DB_NULL != *val && DV_ANY == dc->dc_sqt.sqt_col_dtp)
	    {
	      dc->dc_n_values = fill;
	      dc_heterogenous (dc);
	      goto any_case;
	    }
	}
    case DV_SINGLE_FLOAT:
      for (;;)
	{
	  int32 f;
	  if (DV_DB_NULL == *val)
	    dc_set_null (dc, fill++);
	  else
	    {
	      f = LONG_REF_NA (val + 1);
	      ((int32 *) values)[fill++] = f;
	    }
	  END_TEST;
	  CE_ANY_NTH (dict, n_distinct, v_inx, val, len);
	  if (DV_SINGLE_FLOAT != *val && DV_DB_NULL != *val && DV_ANY == dc->dc_sqt.sqt_col_dtp)
	    {
	      dc->dc_n_values = fill;
	      dc_heterogenous (dc);
	      goto any_case;
	    }
	}

    case DV_DATETIME:
    case DV_DATE:
    case DV_TIME:
      for (;;)
	{
	  if (DV_DB_NULL == *val)
	    dc_set_null (dc, fill);
	  else
	    {
	      db_buf_t tgt = values + fill * DT_LENGTH;
	      memcpy_dt (tgt, val + 1);
	    }
	  fill++;
	  END_TEST;
	  CE_ANY_NTH (dict, n_distinct, v_inx, val, len);
	  if (DV_DATETIME != *val && DV_DB_NULL != *val && DV_ANY == dc->dc_sqt.sqt_col_dtp)
	    {
	      dc->dc_n_values = fill;
	      dc_heterogenous (dc);
	      goto any_case;
	    }
	}

    case DV_ANY:
    any_case:
      memset (value_ptr, 0, n_distinct * sizeof (caddr_t));
      values = dc->dc_values;
      for (;;)
	{
	  if (value_ptr[v_inx])
	    ((db_buf_t *) values)[fill++] = value_ptr[v_inx];
	  else
	    {
	      CE_ANY_NTH (dict, n_distinct, v_inx, val, len);
	      dc->dc_n_values = fill;
	      dc_append_bytes (dc, val, len, NULL, 0);
	      fill = dc->dc_n_values;
	      value_ptr[v_inx] = ((db_buf_t *) dc->dc_values)[fill - 1];
	    }
	  END_TEST;
	}
    }
  GPF_T1 ("supposed to have returned");
  return 0;
}

#undef END_TEST
#undef VARS
#undef name
