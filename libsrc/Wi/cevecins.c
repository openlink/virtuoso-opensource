/*
 *  cevecins.c
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


db_buf_t
INS_NAME (ce_ins_ctx_t * ceic, ce_ins_ctx_t ** col_ceic, db_buf_t ce, int space_after, int *split_at)
{
  it_cursor_t *itc = ceic->ceic_itc;
  db_buf_t ce_first;
  int inx;
  int n_values, n_bytes, ins_offset = 0;
  dtp_t val_dtp;
  int64 value;
  CE_INTVEC_LENGTH (ce, ce_first, n_bytes, n_values, int);
  if (ceic->ceic_n_for_ce > n_values && ceic->ceic_n_for_ce > 5)
    return CE_INSERT_GEN;
  if ((n_values + ceic->ceic_n_for_ce) * sizeof (ELT_T) > 2030)
    {
      *split_at = 1015 / sizeof (ELT_T);
      return NULL;
    }
  ce = ce_extend (ceic, col_ceic, ce, &ce_first, n_bytes + ceic->ceic_n_for_ce * sizeof (ELT_T), n_values + ceic->ceic_n_for_ce,
      &space_after);
  for (inx = 0; inx < ceic->ceic_n_for_ce; inx++)
    {
      int row_in_ce = itc->itc_ranges[itc->itc_ce_first_range + inx].r_first + ins_offset - itc->itc_row_of_ce;
      value = ceic_int_value (ceic, inx + itc->itc_ce_first_set, &val_dtp);
      memmove (ce_first + (1 + row_in_ce) * sizeof (ELT_T), ce_first + row_in_ce * sizeof (ELT_T),
	  (ins_offset + n_values - row_in_ce) * sizeof (ELT_T));
      SET_NA (ce_first + row_in_ce * sizeof (int), value);
      ins_offset++;
    }
  return ce;
}
