/*
 *  sparql_qm.c
 *
 *  $Id$
 *
 *  Quad map description language extension for SPARQL
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

#include "libutil.h"
#include "sqlnode.h"
#include "sqlbif.h"
#include "sqlparext.h"
#include "bif_text.h"
#include "xmlparser.h"
#include "xmltree.h"
#include "numeric.h"
#include "sqlcmps.h"
#include "sparql.h"
#include "sparql2sql.h"
#ifdef __cplusplus
extern "C" {
#endif
#include "sparql_p.h"
#ifdef __cplusplus
}
#endif


void
spar_qm_clean_locals (sparp_t *sparp)
{
  dk_set_t *locptr = &(sparp->sparp_e4qm->e4qm_locals);
  for (;;)
    {
      if (NULL == locptr[0])
        spar_internal_error (sparp, "spar_qm_clean_locals(): stack underflow");
      if (NULL == locptr[0]->data)
        break;
      locptr[0] = locptr[0]->next->next;
    }
}

void
spar_qm_push_bookmark (sparp_t *sparp)
{
  dk_set_t *locptr = &(sparp->sparp_e4qm->e4qm_locals);
  t_set_push (locptr, NULL);
}

void
spar_qm_pop_bookmark (sparp_t *sparp)
{
  dk_set_t *locptr = &(sparp->sparp_e4qm->e4qm_locals);
  for (;;)
    {
      if (NULL == locptr[0])
        spar_internal_error (sparp, "spar_qm_pop_bookmark(): stack underflow");
      if (NULL == locptr[0]->data)
        break;
      locptr[0] = locptr[0]->next->next;
    }
  locptr[0] = locptr[0]->next;
}

void
spar_qm_push_local (sparp_t *sparp, int key, SPART *value, int can_overwrite)
{
  dk_set_t *locptr = &(sparp->sparp_e4qm->e4qm_locals);
  SPART *old_value = spar_qm_get_local (sparp, key, 0);
  if ((!can_overwrite) && (NULL != old_value) && (old_value != value))
    spar_error (sparp, "%s: Can't redefine the '%s' property of quad mapping",
      spar_source_place (sparp, NULL), spart_dump_opname (key, 0) );
  t_set_push (locptr, value);
  t_set_push (locptr, (caddr_t)((ptrlong)key));
}

SPART *
spar_qm_get_local (sparp_t *sparp, int key, int error_if_missing)
{
  dk_set_t iter = sparp->sparp_e4qm->e4qm_locals;
  SPART *res = NULL;
  while (NULL != iter)
    {
      if (key == (ptrlong)(iter->data))
        {
          res = iter->next->data;
          break;
        }
      if (NULL == iter->data)
        iter = iter->next;
      else
        iter = iter->next->next;
    }
  if ((NULL == res) && error_if_missing)
    spar_error (sparp, "%s: The '%s' property is not defined",
      spar_source_place (sparp, NULL), spart_dump_opname (key, 0) );
  return res;
}

void spar_qm_pop_key (sparp_t *sparp, int key_to_pop)
{
  dk_set_t *locptr = &(sparp->sparp_e4qm->e4qm_locals);
  for (;;)
    {
      if (NULL == locptr[0])
        spar_internal_error (sparp, "spar_qm_pop_key(): stack underflow");
      if (NULL == locptr[0]->data)
        spar_internal_error (sparp, "spar_qm_pop_key(): no key to pop above bookmark");
      if (key_to_pop == (ptrlong)(locptr[0]->data))
        break;
      locptr[0] = locptr[0]->next->next;
    }
  locptr[0] = locptr[0]->next->next;
}

caddr_t
spar_make_iri_from_template (sparp_t *sparp, caddr_t tmpl)
{
/*!!!TBD: replace this stub with something complete */
  caddr_t cmd;
/*                     0         1         2*/
/*                     012345678901234567890*/
  cmd = strstr (tmpl, "^{URIQADefaultHost}^");
  if (NULL != cmd)
    {
      char buf[500];
      char *tail = buf;
      caddr_t subst;
      memcpy (buf, tmpl, cmd-tmpl);
      tail += cmd-tmpl;
      IN_TXN;
      subst = registry_get ("URIQADefaultHost");
      LEAVE_TXN;
      if (NULL == subst)
        spar_error (sparp, "%s: Unable to use ^{URIQADefaultHost}^ in IRI template if DefaultHost is not specified in [URIQA] section of Virtuoso config",
          spar_source_place (sparp, NULL) );
      strcpy (tail, subst);
      tail += strlen (subst);
      dk_free_box (subst);
      strcpy (tail, cmd+20);
      return t_box_dv_uname_string (buf);
    }
/*                     0         1         2  */
/*                     01234567890123456789012*/
  cmd = strstr (tmpl, "^{DynamicLocalFormat}^");
  if (NULL != cmd)
    {
      spar_error (sparp, "%s: Unable to use ^{DynamicLocalFormat}^ outside format string of IRI class because it is expanded into sprintf format string",
          spar_source_place (sparp, NULL) );
    }
  return t_box_dv_uname_string (tmpl);
}

SPART *
sparp_make_qm_sqlcol (sparp_t *sparp, ptrlong type, caddr_t name)
{
  char *right_dot = strrchr (name, '.');
  caddr_t prefix = ((NULL == right_dot) ? NULL : t_box_dv_short_nchars (name, right_dot - name));
  caddr_t aliased_table = NULL;
  switch (type)
    {
    case SPARQL_PLAIN_ID:
      prefix = sparp->sparp_e4qm->e4qm_current_table_alias;
      if (NULL != prefix)
        aliased_table = spar_qm_find_base_table_or_sqlquery (sparp, prefix);
      else
        aliased_table = sparp->sparp_e4qm->e4qm_default_table;
      if (NULL == aliased_table)
        {
          if (NULL != sparp->sparp_e4qm->e4qm_parent_tables_of_aliases)
            spar_error (sparp, "Table alias name is not specified for column %.100s", name);
          else
            spar_error (sparp, "Table name is not specified for column %.100s", name);
        }
      return spartlist (sparp, 4, SPAR_SQLCOL, aliased_table, prefix, name);
    case SPARQL_SQL_ALIASCOLNAME:
      {
        if (NULL == right_dot)
          spar_internal_error (sparp, "sparp_" "make_qm_sqlcol(): no dot in SPARQL_SQL_ALIASCOLNAME");
        aliased_table = spar_qm_find_base_table_or_sqlquery (sparp, prefix);
        if (NULL == aliased_table)
          spar_error (sparp, "Undefined table alias %.100s in SQL column name %.100s", prefix, name);
        return spartlist (sparp, 4, SPAR_SQLCOL, aliased_table, prefix, t_box_dv_short_string (right_dot+1));
      }
    case SPARQL_SQL_QTABLECOLNAME:
      {
        if (NULL == right_dot)
          spar_internal_error (sparp, "sparp_" "make_qm_sqlcol(): no dot in SPARQL_SQL_QTABLECOLNAME");
        if (NULL != sparp->sparp_e4qm->e4qm_parent_tables_of_aliases)
          spar_error (sparp, "Column name %.100s can not start with table name if some table aliases are defined", name);
        if (NULL == sparp->sparp_e4qm->e4qm_default_table)
          sparp->sparp_e4qm->e4qm_default_table = prefix;
        else if (strcmp (sparp->sparp_e4qm->e4qm_default_table, prefix))
          spar_error (sparp, "%.100s of column %.100s does not match previously set default %.100s; consider using aliases",
            spar_qm_table_or_sqlquery_report_name (prefix), name,
            spar_qm_table_or_sqlquery_report_name (sparp->sparp_e4qm->e4qm_default_table) );
        return spartlist (sparp, 4, SPAR_SQLCOL,
          sparp->sparp_e4qm->e4qm_default_table, NULL, t_box_dv_short_string (right_dot+1) );
      }
    default: spar_internal_error (sparp, "sparp_" "make_qm_sqlcol(): Unsupported argument type");
    }
  return NULL; /* never reached */
}

SPART *
spar_make_qm_col_desc (sparp_t *sparp, SPART *col)
{
  return spar_make_vector_qm_sql (sparp,
    (SPART **)t_list (3,
      col->_.qm_sqlcol.qtable,
      col->_.qm_sqlcol.alias,
      col->_.qm_sqlcol.col ) );
}

SPART *
spar_make_qm_value (sparp_t *sparp, caddr_t format_name, SPART **cols)
{
  dk_set_t map_aliases = NULL;
  dk_set_t map_atables = NULL;
  dk_set_t cond_tmpls = NULL;
  dk_set_t col_descs = NULL;
  SPART **col_descs_array;
  SPART *ft_generator = NULL;
  int colctr;
  DO_BOX_FAST (SPART *, col, colctr, cols)
    {
      caddr_t a = col->_.qm_sqlcol.alias;
      caddr_t tbl = col->_.qm_sqlcol.qtable;
      if (NULL == tbl)
        tbl = sparp->sparp_e4qm->e4qm_default_table;
      t_set_push (&col_descs, spar_make_qm_col_desc (sparp, col));
      if (NULL == a)
        a = t_box_dv_short_string ("");
      if (0 > dk_set_position_of_string (map_aliases, a))
        {
          t_set_push (&map_aliases, a);
          t_set_push (&map_atables,
            spar_make_vector_qm_sql (sparp,
              (SPART **)t_list (2, a, col->_.qm_sqlcol.qtable) ) );
        }
    }
  END_DO_BOX_FAST;
  col_descs_array = (SPART **)t_revlist_to_array (col_descs);
  spar_qm_find_all_conditions (sparp, map_aliases, &cond_tmpls);
  if (NULL != sparp->sparp_e4qm->e4qm_ft_indexes_of_columns)
    { /* If there exist 'TEXT LITERAL...' declarations then there might be freetext-specific properties */
      caddr_t ft_alias;
      dk_set_t ft_cond_tmpls = NULL;
      caddr_t qmft_key = spar_qm_collist_crc (cols, "ftcols-", 0);
      spar_qm_ft_t *ft = (spar_qm_ft_t *)dk_set_get_keyword (sparp->sparp_e4qm->e4qm_ft_indexes_of_columns, qmft_key, NULL);
      if (NULL == ft)
        goto end_of_free_text; /* see below */
      ft_alias = ft->sparqft_ft_sqlcol->_.qm_sqlcol.alias;
      if (0 > dk_set_position_of_string (map_aliases, ft_alias))
        { /* If free-text alias is not one of qmv aliases then it may have additional join/where conditions */
          dk_set_t all_tmpls = NULL;
          t_set_push (&map_aliases, ft_alias);
          spar_qm_find_all_conditions (sparp, map_aliases, &all_tmpls);
          DO_SET (caddr_t, tmpl, &all_tmpls)
            {
              if (0 > dk_set_position_of_string (cond_tmpls, tmpl))
                t_set_push (&ft_cond_tmpls, tmpl); /* ...thus ft_cond_tmpls does not intersect with cond_tmpls */
            }
          END_DO_SET ()
        }
      ft_generator = spar_make_qm_sql (sparp, "DB.DBA.RDF_QM_FT_USAGE",
        (SPART **)t_list (5,
          ft->sparqft_type, ft_alias,
          spar_make_qm_col_desc (sparp, ft->sparqft_ft_sqlcol),
          spar_make_vector_qm_sql (sparp, col_descs_array),
          spar_make_vector_qm_sql (sparp, (SPART **)t_list_to_array (ft_cond_tmpls)) ),
        (SPART **)(ft->sparqft_options) );
      ft->sparqft_use_ctr++;
    }
end_of_free_text: ;

  return spar_make_vector_qm_sql (sparp,
    (SPART **)t_list (5, format_name,
      spar_make_vector_qm_sql (sparp, (SPART **)t_list_to_array (map_atables)),
      spar_make_vector_qm_sql (sparp, col_descs_array),
      spar_make_vector_qm_sql (sparp, (SPART **)t_list_to_array (cond_tmpls)),
      ft_generator ) );
}

caddr_t
spar_qm_table_or_sqlquery_report_name (caddr_t atbl)
{
  if (!SPAR_TABLE_IS_SQLQUERY(atbl))
    return t_box_sprintf (500, "table %.300s", atbl);
  return t_box_sprintf (500, "SQL query at %.100s", SPAR_SQLQUERY_PLACE(atbl));
}

caddr_t
spar_qm_find_base_alias (sparp_t *sparp, caddr_t descendant_alias)
{
  dk_set_t p_a = sparp->sparp_e4qm->e4qm_parent_aliases_of_aliases;
  caddr_t curr = descendant_alias;
  for (;;)
    {
      caddr_t prev = (caddr_t)dk_set_get_keyword (p_a, curr, NULL);
      if (NULL == prev)
        break;
      curr = prev;
    }
  return (curr == descendant_alias) ? NULL : curr;
}

void
spar_qm_find_all_conditions (sparp_t *sparp, dk_set_t map_aliases, dk_set_t *cond_tmpls_ptr)
{
  DO_SET (sparp_qm_table_condition_t *, cond, &(sparp->sparp_e4qm->e4qm_where_conditions))
    {
      int alias_ctr;
      dk_set_t subst = NULL;
      caddr_t tmpl;
      DO_BOX_FAST (caddr_t, cond_alias, alias_ctr, cond->sparqtc_aliases)
        {
          if (0 > dk_set_position_of_string (map_aliases, cond_alias))
            { /* If the alias is not found in map directly, let's search for descendants */
              dk_set_t cond_descendants = spar_qm_find_descendants_of_alias (sparp, cond_alias);
              DO_SET (caddr_t, map_alias, &map_aliases)
                {
                  if (0 <= dk_set_position_of_string (cond_descendants, map_alias))
                    {
                      t_set_push (&subst, map_alias);
                      t_set_push (&subst, cond_alias);
                      goto cond_alias_descendant_found; /* see below */
                    }
                }
              END_DO_SET ()
              goto cond_is_redundant; /* see below */

cond_alias_descendant_found:
              ;
            }
        }
      END_DO_BOX_FAST;
      tmpl = cond->sparqtc_tmpl;
      if (NULL != subst)
        tmpl = sparp_patch_tmpl (sparp, tmpl, subst);
      if (0 > dk_set_position_of_string (cond_tmpls_ptr[0], tmpl))
        t_set_push (cond_tmpls_ptr, tmpl);

cond_is_redundant: ;
    }
  END_DO_SET()
}

caddr_t
spar_qm_find_base_table_or_sqlquery (sparp_t *sparp, caddr_t descendant_alias)
{
  dk_set_t p_t = sparp->sparp_e4qm->e4qm_parent_tables_of_aliases;
  caddr_t base_alias = spar_qm_find_base_alias (sparp, descendant_alias);
  caddr_t t = (caddr_t) dk_set_get_keyword (p_t, (NULL == base_alias) ? descendant_alias : base_alias, NULL);
  return t;
}

dk_set_t
spar_qm_find_descendants_of_alias (sparp_t *sparp, caddr_t base_alias)
{
  dk_set_t d_a = sparp->sparp_e4qm->e4qm_descendants_of_aliases;
  dk_set_t res = (dk_set_t) dk_set_get_keyword (d_a, base_alias, NULL);
  return res;
}

void
spar_qm_add_aliased_table_or_sqlquery (sparp_t *sparp, caddr_t parent_qtable, caddr_t new_alias)
{
  dk_set_t *atables_ptr = &(sparp->sparp_e4qm->e4qm_parent_tables_of_aliases);
  caddr_t prev_use = spar_qm_find_base_table_or_sqlquery (sparp, new_alias);
  if (NULL != prev_use)
    spar_error (sparp, "Alias %.100s is in use already for %.500s",
      new_alias, spar_qm_table_or_sqlquery_report_name (prev_use) );
  t_set_push (atables_ptr, parent_qtable);
  t_set_push (atables_ptr, new_alias);
}

void
spar_qm_add_aliased_alias (sparp_t *sparp, caddr_t parent_alias, caddr_t new_alias)
{
  dk_set_t *parent_aliases_ptr = &(sparp->sparp_e4qm->e4qm_parent_aliases_of_aliases);
  dk_set_t *desc_aliases_ptr = &(sparp->sparp_e4qm->e4qm_descendants_of_aliases);
  caddr_t prev_use = spar_qm_find_base_table_or_sqlquery (sparp, new_alias);
  caddr_t curr;
  if (NULL == spar_qm_find_base_table_or_sqlquery (sparp, parent_alias))
    spar_error (sparp, "Alias %.100s is not defined", parent_alias);
  if (NULL != prev_use)
    spar_error (sparp, "Alias %.100s is in use already for %.500s", new_alias,
      spar_qm_table_or_sqlquery_report_name (prev_use) );
  t_set_push (parent_aliases_ptr, parent_alias);
  t_set_push (parent_aliases_ptr, new_alias);
/* Now we register \c new alias as a descendant of \c parent_alias and all ancestors of \c parent_alias */
  curr = parent_alias;
  for (;;)
    {
      caddr_t prev;
      dk_set_t *desc_set_ptr = (dk_set_t *)dk_set_getptr_keyword (desc_aliases_ptr[0], curr);
      if (NULL == desc_set_ptr)
        { /* The \c new_alias is the first descendant of \c parent_alias */
          dk_set_t new_desc_set = NULL;
          t_set_push (&new_desc_set, new_alias);
          t_set_push (desc_aliases_ptr, new_desc_set);
          t_set_push (desc_aliases_ptr, parent_alias);
        }
      else
        { /* The \c parent_alias already has nonempty list of descendants */
          t_set_push (desc_set_ptr, new_alias);
        }
      prev = dk_set_get_keyword (parent_aliases_ptr[0], curr, NULL);
      if (NULL == prev)
        break;
      curr = prev;
    }
}

void
spar_qm_add_table_filter (sparp_t *sparp, caddr_t tmpl)
{
  dk_set_t used_aliases = NULL;
  caddr_t *descr;
  sparp_check_tmpl (sparp, tmpl, 0, &used_aliases);
  spar_qm_check_filter_aliases (sparp, used_aliases);
  descr = t_list (2, tmpl, t_list_to_array (used_aliases));
  t_set_push (&(sparp->sparp_e4qm->e4qm_where_conditions), descr);
}

caddr_t
spar_qm_collist_crc (SPART **cols, const char *prefix, int ignore_order)
{
  ptrlong total_crc = BOX_ELEMENTS (cols);
  int ctr;
  DO_BOX_FAST (SPART *, col, ctr, cols)
    {
      ptrlong agg, crc;
      NTS_BUFFER_HASH (crc, col->_.qm_sqlcol.alias);
      agg = crc;
      NTS_BUFFER_HASH (crc, col->_.qm_sqlcol.qtable);
      agg += 5 * crc;
      NTS_BUFFER_HASH (crc, col->_.qm_sqlcol.col);
      agg += 17 * crc;
      if (ignore_order)
        total_crc += agg;
      else
        total_crc += agg * (5 + ctr);
    }
  END_DO_BOX_FAST;
  return t_box_sprintf (50, "%.20s%Lx", prefix, (long long)total_crc);
}

void
spar_qm_add_text_literal (sparp_t *sparp, caddr_t ft_type,
  caddr_t ft_table_alias, SPART *ft_col, SPART **qmv_cols, SPART **options )
{
  spar_qm_ft_t *qft;
  caddr_t qmft_key;
  caddr_t old_ft;
  if (NULL == qmv_cols)
    qmv_cols = (SPART **)t_list (1, ft_col);
  qft = (spar_qm_ft_t *)t_list (5, ft_type, ft_col, qmv_cols, options, (ptrlong)0); /* should match sizeof (spar_qm_ft_t) */
  qmft_key = spar_qm_collist_crc (qmv_cols, "ftcols-", 0);
  old_ft = dk_set_get_keyword (sparp->sparp_e4qm->e4qm_ft_indexes_of_columns, qmft_key, NULL);
  if (NULL != old_ft)
    spar_error (sparp, "Only one free text index per column is allowed. %s has two", qmft_key);
  t_set_push (&(sparp->sparp_e4qm->e4qm_ft_indexes_of_columns), qft);
  t_set_push (&(sparp->sparp_e4qm->e4qm_ft_indexes_of_columns), qmft_key);
}

void spar_qm_check_filter_aliases (sparp_t *sparp, dk_set_t used_aliases)
{
  dk_set_t used_base_aliases = NULL;
  DO_SET (caddr_t, used_alias, &used_aliases)
    {
      caddr_t base = spar_qm_find_base_alias (sparp, used_alias);
      if (NULL != base)
        {
          int pos = dk_set_position_of_string (used_base_aliases, base);
          if (pos >= 0)
            {
              caddr_t prev_base_use = dk_set_nth (used_aliases, (dk_set_length (used_base_aliases) - pos) - 1);
              spar_error (sparp, "Aliases %.100s and %.100s have common base alias %.100s so they can not be used together in a WHERE condition", used_alias, prev_base_use, base);
            }
        }
    }
  END_DO_SET ()
}

SPART *
spar_make_qm_sql (sparp_t *sparp, const char *fname, SPART **fixed, SPART **named)
{
  if (NULL != named)
    {
      int ctr, len;
      len = BOX_ELEMENTS (named);
      if (0 != (len % 2))
        spar_internal_error (sparp, "Invalid list of named parameters for quad map SQL statement: bad length");
      for (ctr = 0; ctr < len; ctr += 2)
        {
          if (DV_UNAME != DV_TYPE_OF (named [ctr]))
            spar_internal_error (sparp, "Invalid list of named parameters for quad map SQL statement: bad keyword type");
        }
    }
  if (NULL == strchr (fname, '.'))
    {
      if (NULL != named)
        spar_internal_error (sparp, "Attempt to pass a list of named parameters to BIF in quad map SQL statement");
    }
  return spartlist (sparp, 4, SPAR_QM_SQL_FUNCALL, t_box_dv_uname_string (fname), fixed, named);
}

SPART *
spar_make_vector_qm_sql (sparp_t *sparp, SPART **fixed)
{
  return spar_make_qm_sql (sparp, "vector", fixed, NULL);
}

SPART *
spar_make_topmost_qm_sql (sparp_t *sparp)
{
  dk_set_t *acc_ptr = &(sparp->sparp_e4qm->e4qm_acc_sqls);
  SPART **ops;
  int ctr;
  t_set_push (acc_ptr,
    spar_make_qm_sql (sparp, "DB.DBA.RDF_QM_APPLY_CHANGES",
      (SPART **)t_list (2,
        spar_make_vector_qm_sql (sparp,
          (SPART **)t_revlist_to_array (sparp->sparp_e4qm->e4qm_deleted)),
        spar_make_vector_qm_sql (sparp,
          (SPART **)t_revlist_to_array (sparp->sparp_e4qm->e4qm_affected_jso_iris)) ),
      NULL ) );
  ops = (SPART **)t_revlist_to_array (acc_ptr[0]);
  DO_BOX_FAST (SPART *, op, ctr, ops)
    {
      if (SPAR_QM_SQL_FUNCALL != SPART_TYPE (op))
        goto generic_change; /* see below */
    }
  END_DO_BOX_FAST;
  DO_BOX_FAST (SPART *, op, ctr, ops)
    {
      SPART *fixed = spar_make_vector_qm_sql (sparp, op->_.qm_sql_funcall.fixed);
      SPART **arlst;
      if (NULL == op->_.qm_sql_funcall.named)
        arlst = (SPART **)t_list (2, op->_.qm_sql_funcall.fname, fixed);
      else
        arlst = (SPART **)t_list (3, op->_.qm_sql_funcall.fname, fixed,
          spar_make_vector_qm_sql (sparp, op->_.qm_sql_funcall.named) );
      ops[ctr] = spar_make_vector_qm_sql (sparp, arlst);
    }
  END_DO_BOX_FAST;
  return spar_make_qm_sql (sparp, "DB.DBA.RDF_QM_CHANGE_OPT",
    (SPART **)t_list (1,
      spar_make_vector_qm_sql (sparp, ops) ),
    NULL );

generic_change:
  return spar_make_qm_sql (sparp, "DB.DBA.RDF_QM_CHANGE",
    (SPART **)t_list (1,
      spar_make_vector_qm_sql (sparp, ops) ),
    NULL );
}


static void
spar_qm_get_atables_and_aliases (sparp_t *sparp, caddr_t qm_id, caddr_t alias, caddr_t atbl, dk_set_t *map_atables_ret, dk_set_t *map_aliases_ret)
{
  caddr_t old_atbl;
  if (NULL == alias)
    alias = t_box_dv_short_string ("");
  old_atbl = dk_set_get_keyword (map_atables_ret[0], alias, NULL);
  if (NULL == old_atbl)
    {
      t_set_push (map_atables_ret, atbl);
      t_set_push (map_atables_ret, alias);
      t_set_push (map_aliases_ret, alias);
      return;
    }
  if (strcmp (old_atbl, atbl))
    spar_error (sparp, "One alias %.100s is used for %.300s and %.300s in two different quad map values of the quad map pattern <%.300s>",
      alias, spar_qm_table_or_sqlquery_report_name(atbl), spar_qm_table_or_sqlquery_report_name (old_atbl), qm_id );
}


static SPART *
spar_qm_make_mapping_impl (sparp_t *sparp, int is_real, caddr_t qm_id, SPART **options)
{
  caddr_t storage_name = sparp->sparp_env->spare_storage_name;
  caddr_t raw_id = (caddr_t) spar_qm_get_local (sparp, CREATE_L, 0);
  SPART * parent_id = spar_qm_get_local (sparp, _LBRA, 0);
  SPART * graph = spar_qm_get_local (sparp, GRAPH_L, is_real);
  SPART * subject = spar_qm_get_local (sparp, SUBJECT_L, is_real);
  SPART * predicate = spar_qm_get_local (sparp, PREDICATE_L, is_real);
  SPART * object = spar_qm_get_local (sparp, OBJECT_L, is_real);
  SPART * obj_dt = spar_qm_get_local (sparp, DATATYPE_L, 0);
  SPART * obj_lang = spar_qm_get_local (sparp, LANG_L, 0);
  caddr_t *local_cond_tmpls = (caddr_t *)spar_qm_get_local (sparp, WHERE_L, 0);
  caddr_t uname_using = t_box_dv_uname_string ("USING");
  SPART * exclusive = (SPART *)get_keyword_int ((caddr_t *)options, t_box_dv_uname_string ("EXCLUSIVE"), "(SPARQL compiler)");
  SPART * order = (SPART *)get_keyword_int ((caddr_t *)options, t_box_dv_uname_string ("ORDER"), "(SPARQL compiler)");
  dk_set_t extra_aliases = NULL;
  dk_set_t final_cond_tmpls = NULL;
  dk_set_t final_atables = NULL;
  int ctr;
  int qm_id_is_autogenerated = 0;
  for (ctr = BOX_ELEMENTS (options); ctr > 1; ctr -= 2)
    {
      if (((caddr_t *)(options)) [ctr-2] == uname_using)
        t_set_push (&extra_aliases, ((caddr_t *)(options)) [ctr-1]);
    }
  if (NULL != qm_id)
    {
      if ((NULL != raw_id) && strcmp (qm_id, raw_id))
        spar_error (sparp, "The declaration of quad mapping contains two identifiers for the mapping: CREATE <id1> AS ... AS <id2>");
      raw_id = qm_id;
    }
  if (NULL == raw_id)
    {
      caddr_t key = (caddr_t)t_list (9,
        storage_name, raw_id, parent_id,
        graph, subject, predicate,
        (((NULL != obj_dt) || (NULL != obj_lang)) ? (SPART *)t_list (3, object, obj_dt, obj_lang) : (SPART *)object),
        /* no where_cond -- intentionally */ exclusive, order );
      caddr_t md5 = box_md5 (key);
      int i, md5len = box_length (md5) - 1;
      caddr_t md5enc = t_alloc_box ((2 * md5len) + 1, DV_STRING);
      for (i = 0; i < md5len; i++)
        {
          md5enc [i*2] = "0123456789abcdef"[((unsigned char *)(md5))[i] >> 4];
          md5enc [i*2+1] = "0123456789abcdef"[((unsigned char *)(md5))[i] & 0xf];
        }
      md5enc [md5len * 2] = '\0';
      qm_id = t_box_sprintf (50, "sys:qm-%s", md5enc);
      qm_id_is_autogenerated = 1;
      spar_qm_push_local (sparp, CREATE_L, (SPART *)qm_id, 1);
    }
  else
    qm_id = raw_id;
  if ((NULL != local_cond_tmpls) && (!is_real))
    spar_internal_error (sparp, "spar_qm_make_mapping_impl(): where cond in empty qm");
  if (is_real)
    {
      dk_set_t map_aliases = NULL;
      dk_set_t sub_cond_tmpls = NULL;
      dk_set_t all_cond_tmpls = NULL;
      dk_set_t all_atables = NULL;
      dk_set_t sub_atables = NULL;
      int fld_ctr;
      SPART *fields [SPART_TRIPLE_FIELDS_COUNT];
      fields[SPART_TRIPLE_GRAPH_IDX] = graph;
      fields[SPART_TRIPLE_SUBJECT_IDX] = subject;
      fields[SPART_TRIPLE_PREDICATE_IDX] = predicate;
      fields[SPART_TRIPLE_OBJECT_IDX] = object;
      for (fld_ctr = 0; fld_ctr < SPART_TRIPLE_FIELDS_COUNT; fld_ctr++)
        {
          SPART *qmv = fields [fld_ctr];
          caddr_t *qmv_conds;
          int qmv_cond_ctr;
          if (SPAR_QM_SQL_FUNCALL != SPART_TYPE (qmv))
            continue;
          if (!strcmp ("DB.DBA.RDF_QM_AUTO_LITERAL_FIELD", qmv->_.qm_sql_funcall.fname))
            {
              caddr_t alias = (caddr_t)(qmv->_.qm_sql_funcall.fixed[1]);
              caddr_t atbl = (caddr_t)(qmv->_.qm_sql_funcall.fixed[0]);
              qmv_conds = NULL;
              spar_qm_get_atables_and_aliases (sparp, qm_id, alias, atbl, &sub_atables, &map_aliases);
            }
          else
            {
              SPART **qmv_atables;
              int qmv_at_ctr;
              qmv_atables = qmv->_.qm_sql_funcall.fixed[1]->_.qm_sql_funcall.fixed;
              qmv_conds = (caddr_t *)(qmv->_.qm_sql_funcall.fixed[3]->_.qm_sql_funcall.fixed);
              DO_BOX_FAST (SPART *, qmv_at, qmv_at_ctr, qmv_atables)
                {
                  caddr_t alias = (caddr_t)(qmv_at->_.qm_sql_funcall.fixed[0]);
                  caddr_t atbl = (caddr_t)(qmv_at->_.qm_sql_funcall.fixed[1]);
                  spar_qm_get_atables_and_aliases (sparp, qm_id, alias, atbl, &sub_atables, &map_aliases);
                }
              END_DO_BOX_FAST;
            }
          DO_BOX_FAST (caddr_t, qmv_cond_tmpl, qmv_cond_ctr, qmv_conds)
            {
              if (0 > dk_set_position_of_string (sub_cond_tmpls, qmv_cond_tmpl))
                t_set_push (&sub_cond_tmpls, qmv_cond_tmpl);
            }
          END_DO_BOX_FAST;
        }
      all_cond_tmpls = sub_cond_tmpls;
      all_atables = sub_atables;
      DO_SET (caddr_t, extra_alias, &extra_aliases)
        {
          caddr_t atbl = spar_qm_find_base_table_or_sqlquery (sparp, extra_alias);
          if (0 <= dk_set_position_of_string (map_aliases, extra_alias))
            spar_error (sparp, "Alias name occurs in 'option (using %.100s)' and in some value of the quad map pattern", extra_alias);
          spar_qm_get_atables_and_aliases (sparp, qm_id, extra_alias, atbl, &all_atables, &map_aliases);
        }
      END_DO_SET()
      while (all_atables != sub_atables)
        {
          caddr_t alias = (caddr_t)t_set_pop (&all_atables);
          caddr_t atbl = (caddr_t)t_set_pop (&all_atables);
          t_set_push (&final_atables,
            spar_make_vector_qm_sql (sparp, (SPART **)t_list (2, alias, atbl)) );
        }
      DO_BOX_FAST (caddr_t, tmpl, ctr, local_cond_tmpls)
        {
          dk_set_t used_aliases = NULL;
          sparp_check_tmpl (sparp, tmpl, 0, &used_aliases);
          DO_SET (caddr_t, used_alias, &used_aliases)
            {
              if (0 > dk_set_position_of_string (map_aliases, used_alias))
                spar_error (sparp, "Alias %.100s is used in filter condition but not in some of quad map values", used_alias);
            }
          END_DO_SET()
          if (0 > dk_set_position_of_string (all_cond_tmpls, tmpl))
            t_set_push (&all_cond_tmpls, tmpl);
        }
      END_DO_BOX_FAST;
      spar_qm_find_all_conditions (sparp, map_aliases, &all_cond_tmpls);
      while (all_cond_tmpls != sub_cond_tmpls)
        t_set_push (&final_cond_tmpls, t_set_pop (&all_cond_tmpls));
    }
  if ((NULL != raw_id) && dk_set_get_keyword (sparp->sparp_created_jsos, raw_id, NULL))
    spar_error (sparp, "The identifier of Quad Map %.100s is already used in the previous part of the statement", raw_id);
  if ((NULL != qm_id) && dk_set_get_keyword (sparp->sparp_created_jsos, qm_id, NULL))
    {
      if (qm_id_is_autogenerated)
        spar_error (sparp, "The statement contains two identical declarations of mappings");
      else
    spar_error (sparp, "The identifier of Quad Map %.100s is already used in the previous part of the statement", qm_id);
    }
  if (NULL != raw_id)
    {
      t_set_push (&(sparp->sparp_created_jsos), "Quad Map");
      t_set_push (&(sparp->sparp_created_jsos), raw_id);
    }
  if (NULL != qm_id)
    {
      t_set_push (&(sparp->sparp_created_jsos), "Quad Map");
      t_set_push (&(sparp->sparp_created_jsos), qm_id);
    }
  return spar_make_qm_sql (sparp, "DB.DBA.RDF_QM_DEFINE_MAPPING",
      (SPART **)t_list (13,
	storage_name, raw_id, qm_id, parent_id,
	graph, subject, predicate, object,
        obj_dt, obj_lang,
	t_box_num_nonull (is_real),
        spar_make_vector_qm_sql (sparp, (SPART **)(t_revlist_to_array (final_atables))),
        spar_make_vector_qm_sql (sparp, (SPART **)(t_revlist_to_array (final_cond_tmpls))) ),
      options );
}

SPART *
spar_qm_make_empty_mapping (sparp_t *sparp, caddr_t qm_id, SPART **options)
{
  return spar_qm_make_mapping_impl (sparp, 0, qm_id, options);
}

SPART *spar_qm_make_real_mapping (sparp_t *sparp, caddr_t qm_id, SPART **options)
{
  return spar_qm_make_mapping_impl (sparp, 1, qm_id, options);
}
