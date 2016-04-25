/*
 *  name.c
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

int stricmp (const char *s1, const char *s2); /* from libutil */

col_ref_rec_t *
ct_col_crr (comp_table_t * ct, ST * ref)
{
  DO_SET (col_ref_rec_t *, crr, &ct->ct_out_crrs)
  {
    if (0 == CASEMODESTRCMP (ref->_.col_ref.name, crr->crr_col_ref->_.col_ref.name))
      return crr;
  }
  END_DO_SET ();
  return NULL;
}


void
col_ref_error (sql_comp_t * sc, ST * ref)
{
  if (ref->_.col_ref.prefix)
    sqlc_new_error (sc->sc_cc, "42S22", "SQ062", "No column %s.%s.",
	ref->_.col_ref.prefix, ref->_.col_ref.name);
  else
    sqlc_new_error (sc->sc_cc, "42S22", "SQ063", "No column %s.", ref->_.col_ref.name);
}


int
ct_col_ref (sql_comp_t * sc, comp_table_t * ct, ST * ref,
    dbe_column_t ** col_ret, col_ref_rec_t ** crr_ret, int err_if_not)
{
  char *col_name = ref->_.col_ref.name;
  if (!ct->ct_derived)
    {
      dbe_column_t *dbe_col = tb_name_to_column (ct->ct_table, col_name);
#ifdef BIF_XML
      if (!dbe_col
	  && ct_is_entity (sc, ct))
	dbe_col = lt_xml_col (NULL, col_name);
#endif
      if (dbe_col)
	{
	  *col_ret = dbe_col;
	  *crr_ret = NULL;
	  DO_SET (col_ref_rec_t *, crr, &ct->ct_out_crrs)
	  {
	    if (0 == CASEMODESTRCMP (crr->crr_col_ref->_.col_ref.name,
		ref->_.col_ref.name))
	      {
		*crr_ret = crr;
		break;
	      }
	  }
	  END_DO_SET ();
	  return 1;
	}
      else
	{
	  if (err_if_not)
	    col_ref_error (sc, ref);
	  else
	    return 0;
	}
    }
  else
    {
      *col_ret = NULL;
      *crr_ret = NULL;
      DO_SET (col_ref_rec_t *, crr, &ct->ct_out_crrs)
      {
	if (0 == CASEMODESTRCMP (crr->crr_col_ref->_.col_ref.name, ref->_.col_ref.name))
	  {
	    *crr_ret = crr;
	    return 1;
	  }
      }
      END_DO_SET ();
      if (err_if_not)
	col_ref_error (sc, ref);
    }
  return 0;
}

comp_table_t *
sqlc_col_table_1 (sql_comp_t * sc, ST * col_ref, dbe_column_t ** col_ret,
    col_ref_rec_t ** crr_ret, int err_if_not)
{
  /* Find a table with the col. Error if 2 found. */
  col_ref_rec_t *crr_found = NULL;
  int n_found = 0;
  dbe_table_t *prefix_table;
  comp_table_t *ct_found = NULL;
  dbe_column_t *col_found = NULL;
  char *col_name;
  char *col_prefix;
  int inx;

  if (!ST_COLUMN (col_ref, COL_DOTTED))
    return NULL;

  col_prefix = col_ref->_.col_ref.prefix;
  col_name = col_ref->_.col_ref.name;
  if (col_name == STAR)
    sqlc_new_error (sc->sc_cc, "42000", "SQ064", "Illegal use of '*'.");

  if (col_ref->_.col_ref.prefix)
    {
      comp_table_t *ct_found = NULL;
      int n_found = 0;
      DO_BOX (comp_table_t *, ct, inx, sc->sc_tables)
      {
	if (ct->ct_prefix && col_prefix)
	  {
	    int res = sqlc_pref_match (ct->ct_prefix, col_prefix);
	    if (res == P_EXACT)
	      {
		if (ct_col_ref (sc, ct, col_ref, col_ret, crr_ret, err_if_not))
		  return ct;
	      }
	    else if (res == P_PARTIAL)
	      {
		n_found++;
		ct_found = ct;
	      }
	    /* cr.table and cr.col */
	  }
      }
      END_DO_BOX;
      if (ct_found && n_found == 1 && ct_col_ref (sc, ct_found, col_ref, col_ret, crr_ret, err_if_not))
	return ct_found;

      prefix_table = sch_name_to_table (wi_inst.wi_schema,
	  col_ref->_.col_ref.prefix);
      DO_BOX (comp_table_t *, ct, inx, sc->sc_tables)
      {
	if (!ct->ct_prefix)
	  {
	    if (ct->ct_table && ct->ct_table == prefix_table)
	      {
		if (ct_col_ref (sc, ct, col_ref, col_ret, crr_ret, err_if_not))
		  return ct;
	      }
	  }
      }
      END_DO_BOX;
      if (err_if_not)
	col_ref_error (sc, col_ref);
      else
	return NULL;
    }
  else
    {
      DO_BOX (comp_table_t *, ct, inx, sc->sc_tables)
      {
	if (ct_col_ref (sc, ct, col_ref, col_ret, crr_ret, 0))
	  {
	    if (!ct_found)
	      {
		n_found++;
		crr_found = *crr_ret;
		col_found = *col_ret;
		ct_found = ct;
	      }
	    else
	      {
		/* second table w/ this column */
		if (!ct_found->ct_prefix && !ct->ct_prefix)
		  {
		    n_found++;
		    break;
		  }
		if (!ct_found->ct_prefix && ct->ct_prefix)
		  continue;
		if (ct_found->ct_prefix && !ct->ct_prefix)
		  {
		    n_found = 1;
		    crr_found = *crr_ret;
		    col_found = *col_ret;
		    ct_found = ct;
		  }
		if (ct_found->ct_prefix && ct->ct_prefix)
		  n_found++;
	      }
	  }
      }
      END_DO_BOX;
      if (n_found > 1)
	sqlc_new_error (sc->sc_cc, "42S22", "SQ065", "Col ref ambiguous %s.", col_name);
      if (err_if_not && !n_found)
	col_ref_error (sc, col_ref);
      *crr_ret = crr_found;
      *col_ret = col_found;
      return ct_found;
    }
  return NULL;
}
