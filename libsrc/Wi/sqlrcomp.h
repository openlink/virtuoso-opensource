/*
 *  sqlrcomp.h
 *
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2012 OpenLink Software
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

#ifndef _SQLRCOMP_H
#define _SQLRCOMP_H

void sqlc_subquery_text (sql_comp_t * sc, comp_table_t * subq_for_pred_in_ct,
    ST * tree, char *text, size_t tlen, int *fill, select_node_t * sel);

void sqlc_exp_commalist_print (sql_comp_t * sc, comp_table_t * ct, ST ** exps,
    char *text, size_t tlen, int *fill, select_node_t * sel, state_slot_t **ssls);

void sqlc_exp_print (sql_comp_t * sc, comp_table_t * ct, ST * exp,
    char *text, size_t tlen, int *fill);

int sqlc_is_local_array (sql_comp_t * sc, remote_ds_t * rds, ST ** exps, int only_eq_comps);

int sqlc_is_local (sql_comp_t * sc, remote_ds_t * rds, ST * tree, int only_eq_comps);

int sqlo_is_local (sql_comp_t * sc, remote_ds_t * rds, ST * tree, int only_eq_comps);
remote_ds_t *sqlc_table_remote_ds (sql_comp_t * sc, char *name);


#define SQLT_UNKNOWN(sc) \
  { \
  (sc)->sc_exp_col_name = ""; \
  (sc)->sc_exp_sqt.sqt_dtp = DV_UNKNOWN; \
  (sc)->sc_exp_sqt.sqt_precision = 0; \
  (sc)->sc_exp_sqt.sqt_scale = 0; \
  (sc)->sc_exp_sqt.sqt_non_null = 0; \
  }

#define SQLT_COL(sc, col) \
  { \
  (sc)->sc_exp_col_name = col->col_name; \
  (sc)->sc_exp_sqt = col->col_sqt; \
  }


#define SQLT_DFE(sc, dfe) \
  { \
  (sc)->sc_exp_sqt = dfe->dfe_sqt; \
  }

#define COMMA(text, len, fill, first) \
  if (!first) \
    sprintf_more (text, len, fill, ", "); \
  else \
    first = 0;


remote_ds_t * sqlc_first_location (sql_comp_t * sc, ST * tree);

#define target_rds  ((remote_ds_t*)THR_ATTR (THREAD_CURRENT_THREAD, TA_TARGET_RDS))
#define SET_TARGET_RDS(r) SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_TARGET_RDS, (void*)r)


#define SQL_QUOTE (target_rds ? target_rds->rds_quote : "\"")

void
sqlc_order_by_print (sql_comp_t * sc, char *title, ST ** orderby,
    char *text, size_t tlen, int *fill, caddr_t *box, dk_set_t set);
void rts_free (remote_table_source_t * rts);
void sqlc_rts_env (sql_comp_t * sc, remote_table_source_t * rts);
void sqlc_rts_array_slots (sql_comp_t * sc, remote_table_source_t * rts);

int sqlc_is_proc_available (remote_ds_t * rds, char *p_name);
int sqlc_is_literal_proc (char *p_name);
int sqlc_is_standard_proc (remote_ds_t * rds, char *name, ST **params);
int sqlc_is_masked_proc (char *p_name);
int sqlc_is_contains_proc (remote_ds_t *rds, char ctype, ST **params, comp_context_t *cc);
int sqlc_is_remote_proc (remote_ds_t *rds, char *p_name);
int sqlc_is_pass_through_function (remote_ds_t *rds, char *p_name);
char sqlc_contains_fn_to_char (const char *name);

void sqlc_string_virtuoso_literal (char *text, size_t tlen, int *fill, const char *exp);
void sqlc_string_literal (char *text, size_t tlen, int *fill, const char *exp);
void sqlc_wide_string_literal (char *text, size_t tlen, int *fill, wchar_t *exp);

void sqlc_insert_commalist (sql_comp_t * sc, comp_table_t * ct, ST * tree,
    dbe_table_t * tb, char *text, size_t tlen, int *fill, int in_vdb);

void sqlc_target_rds (remote_ds_t * rds);
#endif /* _SQLRCOMP_H */
