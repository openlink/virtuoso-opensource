/*
 *  meta.c
 *
 *  $Id$
 *
 *  META
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2015 OpenLink Software
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

#define NO_DBG_PRINTF
#include "Dk.h"
#include "sqlnode.h"
#include "eqlcomp.h"
#include "sqlfn.h"
#include "security.h"
#include "libutil.h"
#if !defined (__APPLE__)
#include <wchar.h>
#endif
#include "srvmultibyte.h"
#include "xmlnode.h"
#include "sqltype.h"


#if 0
void
dd_print_key_id (dk_session_t * ses, key_id_t id)
{
  session_buffered_write_char (0, ses);
  session_buffered_write_char (0, ses);
  session_buffered_write_char (id >> 8, ses);
  session_buffered_write_char (id & 0xff, ses);
}
#endif

id_hash_t *global_collations;
static id_hash_t *_global_name_to_proc;
static id_hash_t *_global_name_to_module;
dk_set_t global_old_triggers;
dk_set_t global_old_procs;
dk_set_t global_old_modules;

/* default collation name and pointer */
char *default_collation_name = NULL;
collation_t *default_collation = NULL;

dbe_schema_t *
dbe_schema_create (dbe_schema_t *old_sc)
{
  NEW_VARZ (dbe_schema_t, sc);
  sc->sc_name_to_object[sc_to_table] = id_casemode_hash_create (
      old_sc ? old_sc->sc_name_to_object[sc_to_table]->ht_buckets : 199);
  id_hash_set_rehash_pct (sc->sc_name_to_object[sc_to_table], 120);
  sc->sc_id_to_key = hash_table_allocate (199);
  sc->sc_key_subkey = hash_table_allocate (1117);
  sc->sc_id_to_col = hash_table_allocate (199);
  sc->sc_name_to_object[sc_to_type] = id_casemode_hash_create (
      old_sc ? old_sc->sc_name_to_object[sc_to_type]->ht_buckets : 199);
  id_hash_set_rehash_pct (sc->sc_name_to_object[sc_to_type], 120);
  sc->sc_id_to_type = hash_table_allocate (199);

  if (!_global_name_to_proc)
    _global_name_to_proc = id_casemode_hash_create (2000);
  if (!global_collations)
    global_collations = id_str_hash_create (101);
  sc->sc_name_to_object[sc_to_proc] = _global_name_to_proc;
  if (!_global_name_to_module)
    _global_name_to_module = id_casemode_hash_create (997);
  sc->sc_name_to_object[sc_to_module] = _global_name_to_module;
  return sc;
}


void
dbe_schema_dead (dbe_schema_t * sc)
{
  ASSERT_IN_TXN;
  sc->sc_free_since = approx_msec_real_time ();
  dk_set_pushnew (&wi_inst.wi_free_schemas, (void *) sc);
}


/* XXX Migrate into Dkhash.c (PmN) */
void
dk_hash_copy (dk_hash_t * to, dk_hash_t * from)
{
  dk_hash_iterator_t hit;
  void *k, *d;
  dk_hash_iterator (&hit, from);
  while (dk_hit_next (&hit, &k, &d))
    sethash (k, to, d);
}


dbe_schema_t *
dbe_schema_copy (dbe_schema_t * from)
{
  dbe_schema_t *sc = dbe_schema_create (from);
  dk_hash_copy (sc->sc_id_to_key, from->sc_id_to_key);
  dk_hash_copy (sc->sc_id_to_type, from->sc_id_to_type);
  dk_hash_copy (sc->sc_id_to_col, from->sc_id_to_col);
  id_casemode_hash_copy (sc->sc_name_to_object[sc_to_table], from->sc_name_to_object[sc_to_table]);
  id_casemode_hash_copy (sc->sc_name_to_object[sc_to_type], from->sc_name_to_object[sc_to_type]);
  return sc;
}


void
dbe_schema_free (dbe_schema_t * sc)
{
  id_casemode_hash_free (sc->sc_name_to_object[sc_to_table]);
  id_casemode_hash_free (sc->sc_name_to_object[sc_to_type]);
  hash_table_free (sc->sc_id_to_key);
  hash_table_free (sc->sc_id_to_type);
  hash_table_free (sc->sc_id_to_col);
  hash_table_free (sc->sc_key_subkey);
  dk_free ((caddr_t) sc, sizeof (dbe_schema_t));
}


void
wi_free_schemas ()
{
#if !defined (PURIFY) && !defined (VALGRIND)
  long now = approx_msec_real_time ();
  int any_freed;
  /* ASSERT_IN_MAP; */
  do
    {
      any_freed = 0;
      DO_SET (dbe_schema_t *, sc, &wi_inst.wi_free_schemas)
      {
	if (now - sc->sc_free_since > 2000)
	  {
	    dk_set_delete (&wi_inst.wi_free_schemas, (void *) sc);
	    dbe_schema_free (sc);
	    any_freed = 1;
	    break;
	  }
      }
      END_DO_SET ();
    }
  while (any_freed);
#endif
}

static void
gpf_if_found (id_hash_t * ht, query_t * qr)
{
#ifdef MALLOC_DEBUG
  query_t **ptp;
  id_casemode_hash_iterator_t it;

  if (qr && qr->qr_trig_table)
    GPF_T;

  id_casemode_hash_iterator (&it, ht);

  while (id_casemode_hit_next (&it, (caddr_t *) & ptp))
    {
      query_t *proc = *ptp;
      if (!proc)
	continue;
      if (proc == qr)
	GPF_T;
    }
#endif
}


void
wi_free_old_qrs ()
{
  if (mutex_try_enter (recomp_mtx))
    {
      while (global_old_triggers)
	{
	  query_t *qr = (query_t *) dk_set_pop (&global_old_triggers);
	  /*log_debug ("freeing trigger %.50s", qr->qr_proc_name);*/
	  qr_free (qr);
	}
      while (global_old_procs)
	{
	  query_t *qr = (query_t *) dk_set_pop (&global_old_procs);
	  /*log_debug ("freeing proc %.50s", qr->qr_proc_name);*/
	  gpf_if_found (isp_schema (NULL)->sc_name_to_object[sc_to_proc], qr);
	  qr_free (qr);
	}
      while (global_old_modules)
	{
	  query_t *qr = (query_t *) dk_set_pop (&global_old_modules);
	  /*log_debug ("freeing module %.50s", qr->qr_proc_name);*/
	  gpf_if_found (isp_schema (NULL)->sc_name_to_object[sc_to_module], qr);
	  qr_free (qr);
	}
      mutex_leave (recomp_mtx);
    }
}


dbe_key_t *
sch_id_to_key (dbe_schema_t * sc, key_id_t id)
{
  return ((dbe_key_t *) gethash ((void *) (ptrlong) id, sc->sc_id_to_key));
}


sql_class_t *
sch_id_to_type (dbe_schema_t * sc, long id)
{
  return ((sql_class_t *) gethash ((void *) (ptrlong) id, sc->sc_id_to_type));
}


dbe_column_t *
sch_id_to_column (dbe_schema_t * sc, oid_t id)
{
  return ((dbe_column_t *) gethash ((void *) (ptrlong) id, sc->sc_id_to_col));
}


int
sch_is_subkey (dbe_schema_t * sc, key_id_t sub, key_id_t super)
{
  long key = (super << 16) | sub;
  return ((int) (ptrlong) gethash ((void *) (ptrlong) key, sc->sc_key_subkey));
}


int
sch_is_subkey_incl (dbe_schema_t * sc, key_id_t sub, key_id_t super)
{
  return (sub == super || sch_is_subkey (sc, sub, super));
}


void
sch_set_subkey (dbe_schema_t * sc, key_id_t sub, key_id_t super)
{
  long key = (super << 16) | sub;
  sethash ((void *) (ptrlong) key, sc->sc_key_subkey, (void *) 1L);
}


dbe_table_t *
sch_name_to_table_exact (dbe_schema_t * sc, char *name)
{
  return (dbe_table_t *) sch_name_to_object (sc, sc_to_table, name, NULL, NULL, 0);
}


client_connection_t *
sqlc_client (void)
{
  return ((client_connection_t *) THR_ATTR (THREAD_CURRENT_THREAD, TA_SQLC_CURRENT_CLIENT));
}


void
sqlc_set_client (client_connection_t * cli)
{
  SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_SQLC_CURRENT_CLIENT, cli);
}


void
sch_split_name_len (const char *q_default, const char *name, char *q, int max_q, char *o, int max_o, char *n, int max_n)
{
  int len = (int) strlen (name);
  int inx;
  int c1 = 0, c2 = 0;
  if (!q_default)
    q_default = "";
  for (inx = 0; inx < len; inx++)
    {
      if (name[inx] == '.')
	{
	  c1 = c2;
	  c2 = inx;
	  if (c1)
	    break;
	}
    }
  if (c1)
    {
      strncpy (q, name, MIN (c1, (max_q - 1)));
      q[MIN(c1, (max_q - 1))] = 0;
      if (c2 - c1 > 1)
	{
	  strncpy (o, name + c1 + 1, MIN ((c2 - c1), max_o) - 1);
	  o[MIN ((c2 - c1), max_o) - 1] = 0;
	}
      else
	o[0] = 0;
      strncpy (n, name + c2 + 1, max_n - 1);
      n[max_n - 1] = 0;
      return;
    }
  strncpy (q, q_default, max_q - 1);
  q[max_q - 1] = 0;
  if (c2)
    {
      if (c2 > 0)
	{
	  strncpy (o, name, MIN (c2, (max_o - 1)));
	  o[MIN (c2, (max_o - 1))] = 0;
	}
      else
	o[0] = 0;
      strncpy (n, name + c2 + 1, max_n - 1);
      n[max_n - 1] = 0;
      return;
    }
  o[0] = 0;
  strncpy (n, name, max_n - 1);
  n[max_n - 1] = 0;
}

void
sch_split_name (const char *q_default, const char *name, char *q, char *o, char *n)
{
  sch_split_name_len (q_default, name, q, MAX_NAME_LEN, o, MAX_NAME_LEN, n, MAX_NAME_LEN);
}
/* stricmp from util */

void
sch_normalize_new_table_case (dbe_schema_t * sc, char *q, size_t max_q, char *own, size_t max_own)
{
  int q_normalized = q ? 0 : 1, own_normalized = own ? 0 : 1;

  dbe_table_t **ptb;
  id_casemode_hash_iterator_t it;

  if (case_mode != CM_MSSQL)
    return;

  if (!own_normalized)
    own_normalized = sec_normalize_user_name (own, max_own);

  if (!q_normalized || !own_normalized)
    id_casemode_hash_iterator (&it, sc->sc_name_to_object[sc_to_table]);

  while ((!q_normalized || !own_normalized) &&
      id_casemode_hit_next (&it, (caddr_t *) & ptb))
    {
      dbe_table_t *tb = *ptb;
      if (!q_normalized && !CASEMODESTRCMP (tb->tb_qualifier, q))
	{
	  q_normalized = 1;
	  strcpy_size_ck (q, tb->tb_qualifier, max_q);
	}
      if (!own_normalized && !CASEMODESTRCMP (tb->tb_owner, own))
	{
	  own_normalized = 1;
	  strcpy_size_ck (own, tb->tb_owner, max_own);
	}
    }
  if (q_normalized  && own_normalized)
    return;
  if (sc->sc_prev)
    sch_normalize_new_table_case (sc->sc_prev,
	q_normalized ? NULL : q, max_q,
	own_normalized ? NULL : own, max_own);
}


collation_t *
sch_name_to_collation_1 (char *o_default, char *q, char *o, char *n)
{
  collation_t *coll_found = NULL;
  int n_found = 0;
  char **coll;
  char cq[MAX_NAME_LEN];
  char co[MAX_NAME_LEN];
  char cn[MAX_NAME_LEN];

  collation_t **pcoll;
  id_hash_iterator_t it;

  id_hash_iterator (&it, global_collations);
  while (hit_next (&it, (caddr_t *) & coll, (caddr_t *) & pcoll))
    {
      /* if this changed to strncmp CaSE MODE 2 */
      collation_t *coll = *pcoll;
      sch_split_name(NULL, coll->co_name, cq, co, cn);

      if (0 != CASEMODESTRCMP (cq, q))
	continue;
      if (0 == CASEMODESTRCMP (cn, n))
	{
	  if (o[0])
	    {
	      if (0 == CASEMODESTRCMP (co, o))
		return coll;
	      else
		continue;
	    }
	  else
	    {
	      if (0 == CASEMODESTRCMP (co, o_default))
		return coll;
	      coll_found = coll;
	      n_found++;
	    }
	}
    }
  if (coll_found)
    {
      if (n_found > 1)
	return ((collation_t *) -1L);
      return coll_found;
    }

  return NULL;
}

const char *
sch_skip_prefixes (const char *str)
{
  const char *first = str;
  while (*str)
    {
      if (*str == NAME_SEPARATOR)
	first = str + 1;
      str++;
    }
  return first;
}




dbe_table_t *
sch_name_to_table (dbe_schema_t * sc, const char *name)
{
  client_connection_t *cli;
  char *o_default;
  char *q_default;

  cli = sqlc_client ();
  if (!cli)
    cli = bootstrap_cli;
  o_default = CLI_OWNER (cli);
  q_default = cli_qual (cli);
  return (dbe_table_t *) sch_name_to_object (sc, sc_to_table, name, q_default, o_default, 1);
}


collation_t *
sch_name_to_collation (char *name)
{
  collation_t *coll;
  char q[MAX_NAME_LEN];
  char o[MAX_NAME_LEN];
  char n[MAX_NAME_LEN];
  client_connection_t *cli = sqlc_client ();
  char *o_default;

  if (!name)
    return NULL;

  if (!cli)
    cli = bootstrap_cli;
  if (cli)
    o_default = CLI_OWNER (cli);
  else
    o_default = "DBA";
  q[0] = 0;
  o[0] = 0;
  n[0] = 0;
  sch_split_name (cli_qual (cli), name, q, o, n);
  coll = sch_name_to_collation_1 (o_default, q, o, n);
  if ((collation_t *) -1L == coll)
    return NULL;
  return coll;
}

id_hash_t *tb_triggers;


dbe_table_t *
dbe_table_create (dbe_schema_t * sc, const char *name)
{
  char q[MAX_NAME_LEN];
  char o[MAX_NAME_LEN];
  char n[MAX_NAME_LEN];
  char qn[2 * MAX_NAME_LEN + 1];
  char *n2;
  NEW_VARZ (dbe_table_t, tb);
  sch_split_name (cli_qual (sqlc_client ()), name, q, o, n);
  /* name = sch_skip_prefixes (name); */

  if (!q[0])
    {
      char temp[MAX_NAME_LEN];
      snprintf (temp, sizeof (temp), "DB.DBA.%s", name);
      n2 = box_string (temp);
      snprintf (qn, sizeof (qn), "DB.%s", n);
      tb->tb_qualifier_name = box_string (qn);
    }
  else
    {
      n2 = box_string (name);
      snprintf (qn, sizeof (qn), "%s.%s", q, n);
      tb->tb_qualifier_name = box_string (qn);
    }
  tb->tb_owner = box_string (o);
  id_casemode_hash_set (sc->sc_name_to_object[sc_to_table],
      tb->tb_qualifier_name, tb->tb_owner, (caddr_t) & tb);
  tb->tb_name_to_col = id_str_hash_create (11);
  tb->tb_name = n2;
  tb->tb_name_only = &tb->tb_name[strlen (tb->tb_name) - strlen (n)];
  tb->tb_qualifier = box_string (q);
  tb->tb_schema = sc;
  tb->tb_count = DBE_NO_STAT_DATA;
  tb->tb_count_estimate = DBE_NO_STAT_DATA;
  if (!tb_triggers)
    tb_triggers = id_str_hash_create (101);
  {
    triggers_t **trigs = (triggers_t **) id_hash_get (tb_triggers,
	(caddr_t) & name);
    if (trigs)
      tb->tb_triggers = *trigs;
    else
      {
	NEW_VARZ (triggers_t, trig);
	id_hash_set (tb_triggers, (caddr_t) & tb->tb_name, (caddr_t) & trig);
	tb->tb_triggers = trig;
      }
  }
  return tb;
}


int recursive_ft_usage = 1;

dbe_key_t *
tb_text_key (dbe_table_t *tb)
{
  dbe_key_t *text_key = tb->tb__text_key;
  if (!text_key && recursive_ft_usage)
    {
      DO_SET (dbe_key_t *, key, &tb->tb_primary_key->key_supers)
	{
	  if (!key->key_migrate_to && key->key_table)
	    text_key = tb_text_key (key->key_table);
	  if (text_key != NULL)
	    break;
	}
      END_DO_SET ();
    }
  return text_key;
}


dbe_column_t *
dbe_column_add (dbe_table_t * tb, const char *name, oid_t id, dtp_t dtp)
{
  char *n2 = box_string (name);
  dbe_column_t *col = NULL;
  if (tb->tb_schema->sc_free_since)
    GPF_T1 ("Can't add col to table not if the latest schema");
#if 0
  col = (dbe_column_t *) gethash ((void *) id,
				  tb->tb_schema->sc_id_to_col);
#endif
  if (!col)
    {
      col = (dbe_column_t *) dk_alloc (sizeof (dbe_column_t));
      memset (col, 0, sizeof (dbe_column_t));
      sethash ((void *) (ptrlong) id, tb->tb_schema->sc_id_to_col, (void *) col);
      col->col_name = n2;
      col->col_id = id;
      col->col_sqt.sqt_dtp = dtp;
      col->col_count = DBE_NO_STAT_DATA;
      col->col_n_distinct = DBE_NO_STAT_DATA;
    }
  if (IS_BLOB_DTP (col->col_sqt.sqt_dtp))
    tb->tb_any_blobs = 1;
  id_hash_set (tb->tb_name_to_col, (caddr_t) & n2, (caddr_t) & col);
  col->col_defined_in = tb;
  return col;
}

#define OPT_ERR_BAD_COLLATION -1

int
dtp_parse_options (char *ck, sql_type_t *psqt, caddr_t *opts)
{
  int inx;
  if (IS_BOX_POINTER (ck)
      && (DV_SHORT_STRING == box_tag (ck) || DV_LONG_STRING == box_tag (ck)))
    {
      if (IS_STRING_DTP (psqt->sqt_dtp) && *ck != 0)
	{
	  psqt->sqt_collation = sch_name_to_collation (ck);
	  if (!psqt->sqt_collation)
	    {
	      return OPT_ERR_BAD_COLLATION;
	    }
	}
    }
  for (inx = 0; inx < BOX_ELEMENTS_INT (opts); inx += 2)
    {
      if (DV_STRINGP (opts[inx]))
	{
	  if (!strcmp (opts[inx], "sql_class") && DV_STRINGP (opts[inx + 1]))
	    psqt->sqt_class = sch_name_to_type (isp_schema (NULL), opts[inx + 1]);
	  else if (!strcmp (opts[inx], "xml_col") && DV_STRINGP (opts[inx + 1]))
	    psqt->sqt_is_xml = (char) atoi (opts[inx + 1]);
	}
    }
  return 0;
}


void
dbe_column_parse_options (dbe_column_t * col)
{
  char *ck = col->col_check;
  int ret;
  if (IS_BOX_POINTER (ck)
      && (DV_SHORT_STRING == box_tag (ck) || DV_LONG_STRING == box_tag (ck)))
    {
      char *i_inx = strchr (ck, 'I'),
	 *u_inx = strstr (ck, " U ");

      if (i_inx)
	if (!u_inx || i_inx < u_inx)
	  col->col_is_autoincrement = 1;
      if (u_inx)
	{
	  char *char_end = strchr (u_inx + 3, ' ');
	  if (char_end)
	    {
	      col->col_xml_base_uri = dk_alloc_box (char_end - (u_inx + 3) + 1, DV_SHORT_STRING);
	      memcpy (col->col_xml_base_uri, u_inx + 3, char_end - (u_inx + 3));
	      col->col_xml_base_uri[char_end - (u_inx + 3)] = 0;
	    }
	}
    }
  ret = dtp_parse_options (ck, &col->col_sqt, col->col_options);
  if (ret == OPT_ERR_BAD_COLLATION)
    {
      log_error("Unknown collation %s for column %s of the table %s",
	  ck, col->col_name, col->col_defined_in->tb_name);
    }
  if (col->col_options)
    {
      caddr_t * opts = col->col_options;
      int inx;
      for (inx = 0; inx < BOX_ELEMENTS (col->col_options); inx += 2)
	{
	  if (DV_STRINGP (opts[inx]) && 0 == strcmp (opts[inx], "compress"))
	    col->col_compression = unbox (opts[inx + 1]);
	}
    }
}


dbe_column_t *
tb_name_to_column (dbe_table_t * tb, const char *name)
{
  caddr_t place = id_hash_get (tb->tb_name_to_col, (caddr_t) & name);
  if (place)
    return (*(dbe_column_t **) place);
  else if (0 == strcmp (name, "_ROW"))
    return ((dbe_column_t *) CI_ROW);
  else if (case_mode == CM_MSSQL)
    {
      dbe_column_t **ptc;
      char **pk;
      id_hash_iterator_t it;
      id_hash_iterator (&it, tb->tb_name_to_col);

      while (hit_next (&it, (caddr_t *) & pk, (caddr_t *) & ptc))
	{
	  dbe_column_t *column = *ptc;
	  if (0 == stricmp(column->col_name, name))
	    return (column);
	}
      return NULL;
    }
  else
    return NULL;
}


dbe_col_loc_t *
dbe_col_loc_array (dk_set_t cls, int off)
{
  int fill = 0;
  int n = dk_set_length (cls);
  dbe_col_loc_t * cl = (dbe_col_loc_t *) dk_alloc ((n + 1) * sizeof (dbe_col_loc_t));
  DO_SET (dbe_col_loc_t *, cl1, &cls)
    {
      if (cl1->cl_fixed_len > 0)
	cl1->cl_pos[0] += off;
      else if (CL_FIRST_VAR == cl1->cl_pos[0])
	;
      else
	cl1->cl_pos[0] = - (-cl1->cl_pos[0] + off);
      cl[fill++] = * cl1;
      dk_free ((caddr_t) cl1, -1);
    }
  END_DO_SET();
  dk_set_free (cls);
  memset (&cl[n], 0, sizeof (dbe_col_loc_t));
  return cl;
}

int
sqt_fixed_length (sql_type_t * sqt)
{
  switch (sqt->sqt_dtp)
    {
    case DV_LONG_INT:
    case DV_SINGLE_FLOAT:
    case DV_IRI_ID:
      return 4;
    case DV_SHORT_INT:
    case DV_COMP_OFFSET:
      return 2;
    case DV_NUMERIC:
      return ((sqt->sqt_precision / 2) + 5);
    case DV_FIXED_STRING:
      return (sqt->sqt_precision);
    case DV_DOUBLE_FLOAT:
    case DV_IRI_ID_8:
    case DV_INT64:
      return 8;
    case DV_DATETIME:
    case DV_TIMESTAMP:
    case DV_DATE:
    case DV_TIME:
      return DT_LENGTH;
    default:
      return -1;
    }
}


dtp_t fixed_dtps[] =
  {DV_COMP_OFFSET, DV_LONG_INT, DV_INT64, DV_DOUBLE_FLOAT, DV_SINGLE_FLOAT, DV_IRI_ID, DV_IRI_ID_8,
 DV_SHORT_INT, DV_DATETIME, DV_TIMESTAMP, DV_DATE, DV_TIME,
 DV_NUMERIC, 0};

dtp_t var_dtps[] =
{ DV_STRING, DV_BLOB, DV_WIDE, DV_BIN, DV_BLOB_WIDE, DV_BLOB_BIN, DV_ANY, DV_OBJECT, 0};


/* do not offset compress these by default in dependent parts to get better update speed */
dtp_t often_updated_dtps[] = {DV_LONG_INT, DV_INT64};

dtp_t pref_compressible_dtps[] =
  {DV_STRING, DV_BIN, 0};

int
dtp_is_fixed (dtp_t dtp)
{
  return memchr (fixed_dtps, dtp, sizeof (fixed_dtps)) ? 1 : 0;
}


int
dtp_is_var (dtp_t dtp)
{
  return memchr (var_dtps, dtp, sizeof (var_dtps)) ? 1 : 0;
}


dtp_t offset_comp_dtps[] =
  { DV_LONG_INT, DV_INT64, DV_IRI_ID, DV_IRI_ID_8, DV_STRING, DV_BIN, DV_ANY };

int
dtp_is_offset_comp (dtp_t dtp)
{
  return memchr (offset_comp_dtps, dtp, sizeof (offset_comp_dtps)) ? 1 : 0;
}


int
dtp_no_comp_if_dep (dtp_t dtp)
{
  return memchr (often_updated_dtps, dtp, sizeof (often_updated_dtps)) ? 1 : 0;
}


int
dtp_is_pref_comp (dtp_t dtp)
{
  return memchr (pref_compressible_dtps, dtp, sizeof (offset_comp_dtps)) ? 1 : 0;
}



int
dtp_is_column_compatible (dtp_t dtp)
{
  if (!dtp || dtp_is_fixed (dtp) || dtp_is_var (dtp))
    return 1;
  else
    return 0;
}


int
dtp_is_placed_with (dtp_t col_dtp, dtp_t placing_dtp)
{
  if (DV_INT64 == placing_dtp)
    return 0;
  if (placing_dtp == col_dtp)
    return 1;
  if (DV_LONG_INT == placing_dtp && DV_INT64 == col_dtp)
    return 1;
  return 0;
}


void
key_place_fixed_1 (dbe_key_t * key, int * fill, int * null_fill, dk_set_t * cls, dk_set_t parts, dtp_t dtp)
{
  DO_SET (dbe_column_t *, col, &parts)
    {
      if (dtp_is_placed_with (col->col_sqt.sqt_dtp, dtp))
	{
	  int len = sqt_fixed_length (&col->col_sqt);
	  NEW_VARZ (dbe_col_loc_t, cl);
	  if (len < 0)
	    GPF_T1 ("not a fixed length data type");
	  cl->cl_col_id = col->col_id;
	  cl->cl_sqt = col->col_sqt;
	  cl->cl_compression = col->col_compression;
	  cl->cl_fixed_len = len;
	  cl->cl_pos[0] = *fill;
	  (*fill) += len;
	  if (-1 != *null_fill && !col->col_sqt.sqt_non_null)
	    {
	      cl->cl_null_mask[0] = 1 << (*null_fill % 8);
	      cl->cl_null_flag[0] = (*null_fill) / 8;
	      (*null_fill)++;
	    }
	  dk_set_push (cls, (void*) cl);
	}
    }
  END_DO_SET();
}


void
key_place_var (dbe_key_t * key, int * fill, int * null_fill, dk_set_t * cls, dk_set_t parts)
{
  DO_SET (dbe_column_t *, col, &parts)
    {
      int inx;
      for (inx = 0; var_dtps[inx]; inx++)
	{
	  if (!col->col_sqt.sqt_dtp || var_dtps[inx] == col->col_sqt.sqt_dtp)
	    {
	      NEW_VARZ (dbe_col_loc_t, cl);
	      cl->cl_col_id = col->col_id;
	      cl->cl_sqt = col->col_sqt;
	      cl->cl_compression = col->col_compression;
	      if (!*fill)
		{
		  cl->cl_fixed_len = CL_FIRST_VAR;
		  cl->cl_pos[0] = CL_FIRST_VAR;
		  *fill += 2;
		}
	      else
		{
		  cl->cl_fixed_len = 0;
		  cl->cl_pos[0] = - (*fill - 2);
		  *fill += 2;
		}
	      if (-1 != *null_fill && !col->col_sqt.sqt_non_null)
		{
		  cl->cl_null_mask[0] = 1 << (*null_fill % 8);
		  cl->cl_null_flag[0] = (*null_fill) / 8;
		  (*null_fill)++;
		}
	      dk_set_push (cls, (void*) cl);
	    }
	}
    }
  END_DO_SET();
  *cls = dk_set_nreverse (*cls);
}



void
key_place_fixed (dbe_key_t * key, int * fill, int * null_fill, dk_set_t * cls, dk_set_t parts)
{
  int inx;
  for (inx = 0; fixed_dtps[inx]; inx++)
    key_place_fixed_1 (key, fill, null_fill, cls, parts, fixed_dtps[inx]);
}


void
dbe_col_loc_null_fix (dbe_col_loc_t * cl, int off)
{
  int inx;
  for (inx = 0; cl[inx].cl_col_id; inx++)
    if (cl[inx].cl_null_mask)
      cl[inx].cl_null_flag[0] += off;
}


int
key_count_nullable (dk_set_t keys)
{
  int ct = 0;
  DO_SET (dbe_column_t *, col, &keys)
    {
      if (!col->col_sqt.sqt_non_null)
	ct++;
    }
  END_DO_SET();
  return ct;
}


int
key_count_compressed (dk_set_t cols)
{
  int c = 0;
  DO_SET (dbe_column_t *, col, &cols)
    {
      if (col->col_sqt.sqt_dtp == DV_COMP_OFFSET)
	c++;
    }
  END_DO_SET();
  return c;
}


void
col_forced_settings (dbe_key_t * key, dbe_column_t * col)
{
  /* for text inx word strings, compression must be off */
  if (0 == stricmp (col->col_name, "VT_DATA")
      || 0 == stricmp (col->col_name, "VT_D_ID_2")
      || col->col_sqt.sqt_collation)
    col->col_compression = CC_NONE;
  if (!dtp_is_offset_comp (col->col_sqt.sqt_dtp) && !dtp_is_pref_comp (col->col_sqt.sqt_dtp))
    col->col_compression = CC_NONE;
}


dbe_column_t * bitmap_col_desc;  /* same col added at the end of all bitmap inx leaf row layouts */


void
key_fill_part_cls (dbe_key_t * key)
{
  /* for inline search ops, the significant cls in key part order */
  dk_set_t res = NULL;
  int nth = 0;
  DO_SET (dbe_column_t *, col, &key->key_parts)
    {
      dk_set_push (&res, (void*) key_find_cl (key, col->col_id));
      if (++nth == key->key_n_significant)
	break;
    }
  END_DO_SET();
  key->key_part_cls = (dbe_col_loc_t **) list_to_array (dk_set_nreverse (res));
}


int
dbe_key_layout_1 (dbe_key_t * key)
{
  int kf_fill = IE_FIRST_KEY, rf_fill = 0, kv_fill = 0, kv_fill_key = 0;
  int null_fill = 0, null_bytes = 0, key_null_area = 0, key_nullables = 0;
  dk_set_t keys = NULL;
  dk_set_t deps = NULL;
  dk_set_t key_fixed = NULL, row_fixed = NULL, key_var = NULL, row_var = NULL;
  int inx = 0;
#ifdef DEBUG
  int n_placed = 0;
#endif
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (key->key_options)
				   && inx_opt_flag (key->key_options, "bitmap"))
    key->key_is_bitmap = 1;
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (key->key_options)
      && inx_opt_flag (key->key_options, "no_pk"))
    key->key_no_pk_ref = 1;
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (key->key_options)
      && inx_opt_flag (key->key_options, "distinct"))
    key->key_distinct = 1;
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (key->key_options)
      && inx_opt_flag (key->key_options, "not_null"))
    key->key_not_null = 1;
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (key->key_options)
      && inx_opt_flag (key->key_options, "column"))
    key->key_is_col = 1;
  DO_SET (dbe_column_t *, col, &key->key_parts)
    {
      if (inx >= key->key_n_significant)
	break; /* can be 0 key parts in cube grand total temp */
      dk_set_push (&keys, (void*) col);
      inx++;
    }
  END_DO_SET();
  keys = dk_set_nreverse (keys);
  if (key->key_is_primary)
    {
      /* pk parts will always be non-null */
      DO_SET (dbe_column_t *, col, &keys)
	{
	  col->col_sqt.sqt_non_null = 1;
	}
      END_DO_SET();
    }
  deps = key->key_parts;
  for (inx = 0; inx < key->key_n_significant; inx++)
    {
      if (!deps)
	{
	  log_info ("Key without parts %s.", key->key_name);
	  return 0;
	}
      deps = deps->next;
    }
  if (key->key_is_primary)
    {
      null_fill = -1; /* not nullable if key part */
      key_nullables = 0;
    }
  else
    {
      null_fill = 0;
      key_nullables = key_count_nullable (keys);
    }
  if (key->key_is_bitmap)
    {
      if (deps)
	log_error ("Bitmap inx should not have dependent parts in schema");
      deps = dk_set_cons ((void*) bitmap_col_desc, NULL);
    }
  key_place_fixed (key, &kf_fill, &null_fill, &key_fixed, keys);
#ifdef DEBUG
  n_placed += dk_set_length (key_fixed);
#endif
  key->key_key_fixed = dbe_col_loc_array (key_fixed, 0);
  if (key_nullables)
    {
      key_null_area = kf_fill;
      kf_fill += ALIGN_8 (key_nullables) / 8;
    }
  kf_fill = ALIGN_2 (kf_fill);
  key->key_length_area[0] = ALIGN_2 (kf_fill);
  kv_fill = 0;
  key_place_var (key, &kv_fill, &null_fill, &key_var, keys);
#ifdef DEBUG
  n_placed += dk_set_length (key_var);
#endif
  kv_fill_key = kv_fill;
  key->key_key_var = dbe_col_loc_array (key_var, kf_fill);
  if (null_fill > 0)
    {
      dbe_col_loc_null_fix (key->key_key_fixed, key_null_area);
      dbe_col_loc_null_fix (key->key_key_var, key_null_area);
    }
  key->key_key_leaf[0] = kf_fill + kv_fill;
  key->key_key_var_start[0] = kf_fill + kv_fill + 4;
  null_fill = 0; /* dependent part starts, allow null flags */
  key_place_var (key, &kv_fill, &null_fill, &row_var, deps);
#ifdef DEBUG
  n_placed += dk_set_length (row_var);
#endif
  rf_fill = ALIGN_2 (kf_fill + kv_fill);
  key->key_row_compressed_start[0] = rf_fill;
  key_place_fixed (key, &rf_fill, &null_fill, &row_fixed, deps);
#ifdef DEBUG
  n_placed += dk_set_length (row_fixed);
  if (n_placed < dk_set_length (key->key_parts))
    GPF_T1 ("some cols not placed");
#endif
  key->key_row_fixed = dbe_col_loc_array (row_fixed, 0);
  key->key_row_var = dbe_col_loc_array (row_var, kf_fill);
  null_bytes = deps ? ALIGN_8 (null_fill) / 8 : 0;
  if (null_bytes)
    {
      dbe_col_loc_null_fix (key->key_row_fixed, rf_fill);
      dbe_col_loc_null_fix (key->key_row_var, rf_fill);
    }
  key->key_null_flag_start[0] = rf_fill;
  key->key_null_flag_bytes[0] = null_bytes;
  key->key_row_var_start[0] = rf_fill + null_bytes;
  if (kv_fill_key)
    key->key_key_len[0] = - (key->key_length_area[0] + kv_fill_key - 2);
  else
    key->key_key_len[0] = 4 + kf_fill;  /* const includes the key ids and leaf ptr */
  if (kv_fill)
    key->key_row_len[0] = - (key->key_length_area[0] + kv_fill - 2);
  else
    key->key_row_len[0] = rf_fill + null_bytes;
  dk_set_free (keys);
  key_fill_part_cls (key);
  if (key->key_is_bitmap)
    dk_set_free (deps);
  return 1;
}


void
dbe_key_version_layout (dbe_key_t * key, row_ver_t rv, dk_set_t parts)
{
  NEW_VARZ (dbe_key_t, kv);
  memcpy (kv, key, sizeof (dbe_key_t));
  kv->key_parts = parts;
  dbe_key_layout_1 (kv);

  key->key_length_area[rv] =   kv->key_length_area[0];
  key->key_key_leaf[rv] = kv->key_key_leaf[0];
  key->key_key_leaf[rv] = kv->key_key_leaf[0];
  key->key_row_compressed_start[rv] = kv->key_row_compressed_start[0];
  key->key_key_var_start[rv] =   kv->key_key_var_start[0];
  key->key_row_var_start[rv] =   kv->key_row_var_start[0];
  key->key_null_flag_start[rv] =   kv->key_null_flag_start[0];
  key->key_null_flag_bytes[rv] =   kv->key_null_flag_bytes[0];
  key->key_key_len[rv] =   kv->key_key_len[0];
  key->key_row_len[rv] =   kv->key_row_len[0];

  DO_CL (cl, kv->key_key_fixed)
    {
      dbe_col_loc_t * kcl = key_find_cl (key, cl->cl_col_id);
      kcl->cl_pos[rv] = cl->cl_pos[0];
      kcl->cl_null_mask[rv] = cl->cl_null_mask[0];
      kcl->cl_null_flag[rv] = cl->cl_null_flag[0];
    }
  END_DO_CL;
  DO_CL (cl, kv->key_key_var)
    {
      dbe_col_loc_t * kcl = key_find_cl (key, cl->cl_col_id);
      kcl->cl_pos[rv] = cl->cl_pos[0];
      kcl->cl_null_mask[rv] = cl->cl_null_mask[0];
      kcl->cl_null_flag[rv] = cl->cl_null_flag[0];
    }
  END_DO_CL;
  DO_CL (cl, kv->key_row_fixed)
    {
      dbe_col_loc_t * kcl = key_find_cl (key, cl->cl_col_id);
      kcl->cl_pos[rv] = cl->cl_pos[0];
      kcl->cl_null_mask[rv] = cl->cl_null_mask[0];
      kcl->cl_null_flag[rv] = cl->cl_null_flag[0];
    }
  END_DO_CL;
  DO_CL (cl, kv->key_row_var)
    {
      dbe_col_loc_t * kcl = key_find_cl (key, cl->cl_col_id);
      kcl->cl_pos[rv] = cl->cl_pos[0];
      kcl->cl_null_mask[rv] = cl->cl_null_mask[0];
      kcl->cl_null_flag[rv] = cl->cl_null_flag[0];
    }
  END_DO_CL;
  dk_free ((caddr_t)kv->key_key_fixed, -1);
  dk_free ((caddr_t)kv->key_key_var, -1);
  dk_free ((caddr_t)kv->key_row_fixed, -1);
  dk_free ((caddr_t)kv->key_row_var, -1);
  dk_free ((caddr_t)kv, sizeof (*kv));
}


dk_hash_t * key_super_id_to_versions;

void
key_set_version (dbe_key_t * key)
{
  static dk_mutex_t * mtx = NULL;
  key_id_t super_id = key->key_super_id;
  dbe_key_t ** kv;
  if (!mtx)
    mtx = mutex_allocate ();
  mutex_enter (mtx);
  if (!key_super_id_to_versions)
    key_super_id_to_versions = hash_table_allocate (201);
  kv = (dbe_key_t **) gethash ((void*)(ptrlong)super_id, key_super_id_to_versions);
  if (!kv)
    {
      kv = (dbe_key_t **) dk_alloc_box_zero (sizeof (caddr_t) * KEY_MAX_VERSIONS, DV_BIN);
      sethash ((void*)(ptrlong)super_id, key_super_id_to_versions, (void*)kv);
    }
  key->key_versions = kv;
  if (1 == key->key_version)
    kv[0] = key;

  if (key->key_version >= KEY_MAX_VERSIONS || key->key_version <= 0)
    GPF_T1("key_version outside of array");
  kv[key->key_version] = key;
  mutex_leave (mtx);
}


void
key_part_in_layout_order (dbe_key_t * key)
{
  short * arr = key->key_part_in_layout_order = dk_alloc (sizeof (short) * key->key_n_significant);
  int inx = 0;
  int key_n_fixed = 0;
  DO_CL (cl, key->key_key_fixed)
    {
      key_n_fixed++;
    }
  END_DO_CL;
  DO_SET (dbe_column_t *, col, &key->key_parts)
    {
      dbe_col_loc_t * cl = key_find_cl (key, col->col_id);
      if (!key->key_n_significant)
	break;
	if (dtp_is_fixed (col->col_sqt.sqt_dtp))
	  arr[inx] = cl - key->key_key_fixed;
	else
	  arr[inx] = key_n_fixed + (cl - key->key_key_var);
      if (++inx == key->key_n_significant)
	break;
    }
  END_DO_SET();
  inx = 0;
  DO_ALL_CL (cl, key)
    {
      cl->cl_nth = inx++;
    }
  END_DO_ALL_CL;
}


void dk_set_set_nth (dk_set_t set, int nth, void * elt);


void
dbe_key_list_pref_compressible (dbe_key_t * key)
{
  DO_CL (cl, key->key_key_var)
    {
      if (memchr (pref_compressible_dtps, cl->cl_sqt.sqt_dtp, sizeof (pref_compressible_dtps))
	  && CC_NONE != cl->cl_compression)
	{
	  dk_set_push (&key->key_key_pref_compressibles, (void*)cl);
	  dk_set_push (&key->key_row_pref_compressibles, (void*)cl);
	}
    }
  END_DO_CL;
  DO_CL (cl, key->key_row_var)
    {
      if (memchr (pref_compressible_dtps, cl->cl_sqt.sqt_dtp, sizeof (pref_compressible_dtps))
	  && CC_NONE != cl->cl_compression)
	{
	  dk_set_push (&key->key_row_pref_compressibles, (void*)cl);
	}
    }
  END_DO_CL;
}


void
dbe_key_compression (dbe_key_t * key)
{
  /* calculate combinations of offset compressible cols and make row versions for each */
  dk_set_t parts_copy;
  int c_fill = 0, nth_col = 0, c_inx;
  dbe_column_t c_cols[N_COMPRESS_OFFSETS];
  int c_nth_col [N_COMPRESS_OFFSETS];
  row_ver_t rv;
  memset (&c_cols, 0, sizeof (c_cols));
  DO_SET (dbe_column_t *, col, &key->key_parts)
    {
      if (dtp_is_offset_comp (col->col_sqt.sqt_dtp)
	  && CC_NONE != col->col_compression && CC_PREFIX != col->col_compression)
	{
	  c_cols[c_fill].col_id = col->col_id;
	  c_cols[c_fill].col_sqt.sqt_dtp = DV_COMP_OFFSET;
	  c_cols[c_fill].col_non_null = col->col_non_null;
	  c_nth_col[c_fill] = nth_col;
	      c_fill++;
	      if (c_fill == N_COMPRESS_OFFSETS)
		break;
	}
      nth_col++;
    }
  END_DO_SET();
  for (c_inx = 0; c_inx < c_fill; c_inx++)
    {
      dbe_col_loc_t * cl = key_find_cl (key, c_cols[c_inx].col_id);
      cl->cl_row_version_mask = 1 << c_inx;
      cl->cl_compression = CC_OFFSET;
    }
  DO_CL (cl, key->key_key_fixed)
    {
      if (cl->cl_row_version_mask)
	{
	  dk_set_append_1 (&key->key_key_compressibles, (void*) cl);
	  dk_set_append_1 (&key->key_row_compressibles, (void*) cl);
	}
    }
  END_DO_CL;
  DO_CL (cl, key->key_key_var)
    {
      if (cl->cl_row_version_mask)
	{
	  dk_set_append_1 (&key->key_key_compressibles, (void*) cl);
	  dk_set_append_1 (&key->key_row_compressibles, (void*) cl);
	}
    }
  END_DO_CL;
  DO_CL (cl, key->key_row_fixed)
    {
      if (cl->cl_row_version_mask)
	{
	  dk_set_append_1 (&key->key_row_compressibles, (void*) cl);
	}
    }
  END_DO_CL;
  DO_CL (cl, key->key_row_var)
    {
      if (cl->cl_row_version_mask)
	{
	  dk_set_append_1 (&key->key_row_compressibles, (void*) cl);
	}
    }
  END_DO_CL;

  key_part_in_layout_order (key);
  for (rv = 1; rv < 1 << c_fill; rv++)
    {
      parts_copy = dk_set_copy (key->key_parts);
      for (c_inx = 0; c_inx < N_COMPRESS_OFFSETS; c_inx++)
	{
	  if (rv & 1 << c_inx)
	    {
	      dk_set_set_nth (parts_copy, c_nth_col[c_inx], &c_cols[c_inx]);
	    }
	}
      dbe_key_version_layout (key, rv, parts_copy);
    }
}


void
key_set_simple_compression (dbe_key_t * key)
{
  if (!key->key_is_bitmap && dk_set_length (key->key_parts) == key->key_n_significant)
    key->key_no_dependent = 1;
  key->key_n_key_compressibles  = dk_set_length (key->key_key_compressibles);
  key->key_n_row_compressibles  = dk_set_length (key->key_row_compressibles);
  if (dk_set_length (key->key_key_compressibles) == dk_set_length (key->key_row_compressibles)
      && !key->key_key_pref_compressibles && !key->key_row_pref_compressibles)
    key->key_simple_compress = 1;
  else
    {
      int inx;
      for (inx = 0; inx < KEY_MAX_VERSIONS; inx++)
	{
	  dbe_key_t * ver = key->key_versions[inx];
	  if (ver)
	    ver->key_simple_compress = 0;
	}
    }
}


void
dbe_key_layout (dbe_key_t * key, dbe_schema_t * sc)
{
  dk_set_t no_comp = NULL;
  int nth_col = 0;
  DO_SET (dbe_column_t *, col, &key->key_parts)
    {
      col_forced_settings (key, col);
      if (nth_col >= key->key_n_significant
	  && dtp_no_comp_if_dep (col->col_sqt.sqt_dtp) && CC_UNDEFD == col->col_compression)
	{
	  col->col_compression = CC_NONE;
	  dk_set_push (&no_comp, (void*) col);
	}
      nth_col++;
    }
  END_DO_SET();

  if (!dbe_key_layout_1 (key)) /* incomplete key, should not continue */
    return;
  dbe_key_compression (key);
  dbe_key_list_pref_compressible (key);
  if (KI_TEMP == key->key_id)
    {
      key->key_versions = dk_alloc_box (2 * sizeof (caddr_t), DV_BIN);
      key->key_versions[0] = key;
      key->key_versions[1] = key;
      key->key_version = 1;
    }
  else
    key_set_version (key);
  dbe_key_insert_spec (key);
  if (key->key_is_bitmap)
    {
      key_make_bm_specs (key);
      key->key_bm_cl = key_find_cl (key, CI_BITMAP);
      key->key_bm_cl->cl_compression = CC_NONE;
      key->key_bit_cl = key_find_cl (key,
				    ((dbe_column_t *)dk_set_nth (key->key_parts, key->key_n_significant - 1))->col_id);
      /* one is the col where the bits are, the other the last key part, i.e. the beginning offset of the nbitmap */
    }
  DO_SET (dbe_column_t *, col, &no_comp)
    {
      col->col_compression = CC_UNDEFD;
    }
  END_DO_SET();
  key_set_simple_compression (key);
  dk_set_free (no_comp);
}


dbe_key_t *
dbe_key_create (dbe_schema_t * sc, dbe_table_t * tb,
    const char *name, key_id_t id,
    int n_significant, int cluster_on_id,
    int is_main, key_id_t migrate_to, key_id_t super_id)
{
  NEW_VARZ (dbe_key_t, key);
  if (is_main && !migrate_to)
    tb->tb_primary_key = key;

  if (!migrate_to)
    dk_set_push (&tb->tb_keys, (void *) key);
  else
    dk_set_push (&tb->tb_old_keys, (void *) key);
  key->key_n_significant = n_significant;
  key->key_name = box_string (sch_skip_prefixes (name));
  key->key_id = id;
  key->key_is_primary = is_main;
  key->key_table = tb;
  sethash ((void *) (ptrlong) id, sc->sc_id_to_key, (void *) key);
  key->key_migrate_to = migrate_to;
  key->key_super_id = super_id;
  key->key_version = 1; /* set later based on sys_keys table if needed */
  return key;
}


void
dbe_key_free (dbe_key_t * key)
{
  search_spec_t * sp = key->key_insert_spec.ksp_spec_array;
  DO_SET (dbe_column_t *, col, &key->key_parts)
    {
      dk_free_box (col->col_name);
      dk_free ((caddr_t) col, sizeof (dbe_column_t));
    }
  END_DO_SET ();
  while (sp)
    {
      search_spec_t * tmp = sp;
      sp = sp->sp_next;
      dk_free (tmp, sizeof (search_spec_t));
    }
  dk_set_free (key->key_parts);
  dk_free ((caddr_t) key->key_key_fixed, -1);
  dk_free ((caddr_t) key->key_key_var, -1);
  dk_free ((caddr_t) key->key_row_fixed, -1);
  dk_free ((caddr_t) key->key_row_var, -1);
  dk_free ((caddr_t) key->key_part_in_layout_order, -1);
  if (KI_TEMP == key->key_id)
    dk_free_box ((caddr_t) key->key_versions);
  dk_free_box (key->key_name);
  dk_free_tree ((box_t) key->key_options);
  dk_free_box ((box_t) key->key_part_cls);
 dk_free ((caddr_t) key, sizeof (dbe_key_t));
}


void
key_add_part (dbe_key_t * key, oid_t col_id)
{
  dbe_column_t *col = (dbe_column_t *) gethash ((void *) (ptrlong) col_id,
      key->key_table->tb_schema->sc_id_to_col);
  if (dk_set_length (key->key_parts) < (uint32) key->key_n_significant)
    col->col_is_key_part = 1;
  key->key_parts = dk_set_conc (key->key_parts,
      dk_set_cons ((caddr_t) col, NULL));
  if (IS_BLOB_DTP (col->col_sqt.sqt_dtp))
    key->key_table->tb_any_blobs = 1;
  if (col->col_sqt.sqt_dtp == DV_OWNER)
    {
      key->key_table->tb_owner_col_id = col->col_id;
    }
}


dbe_key_t *
tb_name_to_key (dbe_table_t * tb, const char *name, int non_primary)
{

  DO_SET (dbe_key_t *, key, &tb->tb_keys)
  {
    if (! (key->key_is_primary && non_primary))
	if (0 == CASEMODESTRCMP (key->key_name, name))
	return key;
  }
  END_DO_SET ();
  return NULL;
}


dbe_key_t *
sch_table_key (dbe_schema_t * sc, const char *table, const char *key, int non_primary)
{
  dbe_table_t *tb = sch_name_to_table (sc, table);
  if (!tb)
    return NULL;
  return (tb_name_to_key (tb, key, non_primary));
}


id_hashed_key_t
proc_name_hash_f (char *strp)
{
  char *str = *(char **) strp;
  id_hashed_key_t h;
  str = &((proc_name_t *)str)->pn_name[0];
 NTS_BUFFER_HASH (h, str);
  return (h & ID_HASHED_KEY_MASK);
}


int
proc_name_cmp (char *x, char *y)
{
  return 0 == strcmp (&(*(proc_name_t**)x)->pn_name[0], &(*(proc_name_t**)y)->pn_name[0]);
}

dk_mutex_t * proc_name_mtx;
id_hash_t * proc_name_hash;

#define PN_HEADER  ((ptrlong)(&((proc_name_t*)0)->pn_name))

proc_name_t *
proc_name (char * name)
{
  proc_name_t ** place;
  int len = strlen (name);
  proc_name_t * pn = (proc_name_t *) dk_alloc (PN_HEADER +len + 1);
  if (!proc_name_mtx)
    {
      proc_name_mtx = mutex_allocate ();
      proc_name_hash = id_hash_allocate (2003, sizeof (caddr_t), sizeof (caddr_t), proc_name_hash_f, proc_name_cmp);
    }
  pn->pn_ref_count = 1;
  pn->pn_query = NULL;
  strcpy (&pn->pn_name[0], name);
  pn->pn_name[len] = 0;
  mutex_enter (proc_name_mtx);
  place = (proc_name_t **) id_hash_get (proc_name_hash, (caddr_t) &pn);
  if (place)
    {
      proc_name_t * found = *place;
      found->pn_ref_count++;
      mutex_leave (proc_name_mtx);
      dk_free (pn, -1);
      return found;
    }
  id_hash_set (proc_name_hash, (caddr_t)&pn, (caddr_t)&pn);
  mutex_leave (proc_name_mtx);
  return pn;
}

proc_name_t *
proc_name_ref (proc_name_t * pn)
{
  mutex_enter (proc_name_mtx);
  pn->pn_ref_count++;
  mutex_leave (proc_name_mtx);
  return pn;
}


void
proc_name_free (proc_name_t * pn)
{
  if (!pn)
    return;
  mutex_enter (proc_name_mtx);
  pn->pn_ref_count--;
  if (!pn->pn_ref_count)
    {
      id_hash_remove (proc_name_hash, (caddr_t)&pn);
      mutex_leave (proc_name_mtx);
      dk_free ((caddr_t)pn, -1);
      return;
    }
  mutex_leave (proc_name_mtx);
}


dk_mutex_t * old_qr_mtx;


void
sch_set_procmod_def (dbe_schema_t * sc, caddr_t name, query_t *proc, sc_object_type o_type)
{
  query_t **data;
  char q[MAX_NAME_LEN];
  char o[MAX_NAME_LEN];
  char n[MAX_NAME_LEN];
  char qn[2 * MAX_NAME_LEN + 1];

  if (!old_qr_mtx)
    old_qr_mtx = mutex_allocate ();
#ifdef MALLOC_DEBUG
  if (proc && proc->qr_trig_table)
    GPF_T1 ("trying to register a trigger in procedures hash");
#endif
  sch_split_name (NULL, name, q, o, n);
  snprintf (qn, sizeof (qn), "%s.%s", q, n);
  mutex_enter (old_qr_mtx);
  data = (query_t **) id_casemode_hash_get (sc->sc_name_to_object[o_type], qn, o);
  if (data)
    {
#ifdef MALLOC_DEBUG
      if (*data == proc)
	GPF_T;
#endif
      if (*data)
	dk_set_pushnew (o_type == sc_to_module ? &global_old_modules : &global_old_procs, *data);
      *data = proc;
    }
  else
    {
      caddr_t qn_key = box_dv_short_string (qn);
      caddr_t o_key = box_dv_short_string (o);
      id_casemode_hash_set (sc->sc_name_to_object[o_type], qn_key, o_key, (caddr_t) & proc);
    }
  mutex_leave (old_qr_mtx);
  if (sc_to_proc == o_type)
    {
      if (proc)
	{
	  proc->qr_pn = proc_name (proc->qr_proc_name);
	  proc->qr_pn->pn_query = proc;
	}
      else
	{
	  proc_name_t * pn = proc_name (name);
	  pn->pn_query = NULL;
	  proc_name_free (pn);
	}
    }
}


void
sch_set_proc_def (dbe_schema_t * sc, caddr_t name, query_t *proc)
{
  sch_set_procmod_def (sc, name, proc, sc_to_proc);
}


void
sch_set_module_def (dbe_schema_t * sc, caddr_t name, query_t *proc)
{
  sch_set_procmod_def (sc, name, proc, sc_to_module);
}


void
sch_drop_module_def (dbe_schema_t *sc, query_t *mod_qr)
{
  id_casemode_hash_iterator_t it;
  query_t **pproc;
  id_casemode_hash_iterator (&it, sc->sc_name_to_object[sc_to_proc]);
  while (id_casemode_hit_next (&it, (caddr_t *) & pproc))
    {
      if (!pproc || !*pproc)
	continue;
      if ((*pproc)->qr_module == mod_qr)
	sch_set_proc_def (sc, (*pproc)->qr_proc_name, NULL);
    }
  sch_set_module_def (sc, mod_qr->qr_proc_name, NULL);
}


char *
sch_full_module_name (dbe_schema_t * sc, char *ref_name, char *q_def, char *o_def)
{
  query_t *proc;

  proc = (query_t *) sch_name_to_object (sc, sc_to_module, ref_name, q_def, o_def, 1);
  if (proc == (query_t *) -1 || !proc)
    return NULL;
  return proc->qr_proc_name;
}


char *
sch_full_proc_name_1 (dbe_schema_t * sc, const char *ref_name, char *q_def, char *o_def, char *m_def)
{
  char q[MAX_NAME_LEN];
  char o[MAX_NAME_LEN];
  char n[MAX_NAME_LEN];
  char m[MAX_NAME_LEN];
  char qn[2 * MAX_NAME_LEN + 1];
  query_t *proc;
  char *dot;
  int no_q = 0;

  sch_split_name (NULL, ref_name, q, o, n);
  if (q[0] == 0)
    {
      no_q = 1;
      if (strlen (q_def) < MAX_NAME_LEN)
	strcpy_ck (q, q_def);
      else
	{
	  log_error ("Trying to resolve procedure with invalid qualifier");
	  strcpy_ck (q, "DB");
	}
    }
  if (NULL != (dot = strchr (n, '.')))
    {
      strcpy_ck (m, n);
      m[dot - n] = 0;
      dot++;
      strcpy_ck (n, m + (dot - n));
    }
  else if (m_def)
    {
      strcpy_ck (m, m_def);
    }
  else
    m[0] = 0;

  if (m[0] == 0)
    snprintf (qn, sizeof (qn), "%s.%s", q, n);
  else
    snprintf (qn, sizeof (qn), "%s.%s.%s", q, m, n);

  proc = (query_t *) sch_name_to_object_sc (sc, sc_to_proc, o_def, o, qn, 1);
  if (proc && proc != (query_t *) -1)
    return proc->qr_proc_name;

  if (no_q && o[0] != 0 && !m_def)
    {
      snprintf (qn, sizeof (qn), "%s.%s.%s", q_def, o, n);

      o[0] = 0;
      proc = (query_t *) sch_name_to_object_sc (sc, sc_to_proc, o_def, o, qn, 1);
      if (proc && proc != (query_t *) -1)
	return proc->qr_proc_name;
    }
  return NULL;
}


char *
sch_full_proc_name (dbe_schema_t * sc, const char *ref_name, char *q_def, char *o_def)
{
  return sch_full_proc_name_1 (sc, ref_name, q_def, o_def, NULL);
}


query_t *
sch_proc_def (dbe_schema_t * sc, const char * name)
{
  if (!sc)
    GPF_T;
  return (query_t *) sch_name_to_object (sc, sc_to_proc, name, NULL, NULL, 0);
}


query_t *
sch_partial_proc_def (dbe_schema_t * sc, caddr_t name, char *q_def, char *o_def)
{
  if (!sc)
    GPF_T;
  return (query_t *) sch_name_to_object (sc, sc_to_proc, name, NULL, NULL, 0);
}


query_t *
sch_proc_exact_def (dbe_schema_t * sc, const char * name)
{
  return sch_proc_def (sc, name);
}


query_t *
sch_module_def (dbe_schema_t * sc, const char * name)
{
  if (!sc)
    GPF_T;
  return (query_t *) sch_name_to_object (sc, sc_to_module, name, NULL, NULL, 0);
}


caddr_t
sch_complete_table_name (caddr_t n)
{
  char temp[300];
  if (strchr (n, NAME_SEPARATOR))
    return n;
  snprintf (temp, sizeof (temp), "DB.DBA.%s", n);
  dk_free_box (n);
  return (box_string (temp));
}

#define DEFAULT_NULL(x) x->col_default = dk_alloc_box (0, DV_DB_NULL)


void
dbe_key_open_ap (dbe_key_t * k, dbe_schema_t * prev_sc)
{
  k->key_storage = wi_ctx_db ()->wd_primary_dbs;
  if (prev_sc)
    {
      dbe_key_t * prev = sch_id_to_key (prev_sc, k->key_id);
      k->key_fragments = prev->key_fragments;
    }
  else
    dbe_key_open (k);
}


void
sch_create_meta_seed (dbe_schema_t * sc, dbe_schema_t * prev_sc)
{
  dbe_table_t *tb_cols = dbe_table_create (sc, TN_COLS);
  dbe_table_t *tb_keys = dbe_table_create (sc, TN_KEYS);
  dbe_table_t *tb_key_parts = dbe_table_create (sc, TN_KEY_PARTS);
  dbe_table_t *tb_collations = dbe_table_create (sc, TN_COLLATIONS);
  dbe_table_t *tb_charsets = dbe_table_create (sc, TN_CHARSETS);
  dbe_table_t *tb_sub = dbe_table_create (sc, TN_SUB);
  dbe_table_t *tb_frags = dbe_table_create (sc, TN_FRAGS);
  dbe_table_t *tb_udt = dbe_table_create (sc, TN_UDT);
  dbe_column_t *col;
  dbe_key_t *key_cols_name = dbe_key_create (sc, tb_cols,
      "SYS_COLS_BY_NAME",
      KI_COLS, 3, KI_COLS, 0, 0, KI_COLS);

  dbe_key_t *key_cols_id = dbe_key_create (sc, tb_cols, TN_COLS,
      KI_COLS_ID, 1, KI_COLS_ID, 1, 0, KI_COLS_ID);

  dbe_key_t *key_keys = dbe_key_create (sc, tb_keys, TN_KEYS,
      KI_KEYS, 2, KI_KEYS, 1, 0, KI_KEYS);

  dbe_key_t *key_keys_id = dbe_key_create (sc, tb_keys, "SYS_KEYS_BY_ID",
      KI_KEYS_ID, 3, KI_KEYS_ID, 0, 0, KI_KEYS_ID);

  dbe_key_t *key_key_parts = dbe_key_create (sc, tb_key_parts, TN_KEY_PARTS,
      KI_KEY_PARTS, 2, KI_KEY_PARTS, 1, 0, KI_KEY_PARTS);

  dbe_key_t *key_collations = dbe_key_create (sc, tb_collations, TN_COLLATIONS,
      KI_COLLATIONS, 1, KI_COLLATIONS, 1, 0, KI_COLLATIONS);

  dbe_key_t *key_charsets = dbe_key_create (sc, tb_charsets, TN_CHARSETS,
      KI_CHARSETS, 1, KI_CHARSETS, 1, 0, KI_CHARSETS);

  dbe_key_t *key_sub = dbe_key_create (sc, tb_sub, TN_SUB,
      KI_SUB, 2, KI_SUB, 1, 0, KI_SUB);

  dbe_key_t *key_frags = dbe_key_create (sc, tb_frags, TN_FRAGS,
      KI_FRAGS, 2, KI_FRAGS, 1, 0, KI_FRAGS);

  dbe_key_t *key_udt = dbe_key_create (sc, tb_udt, TN_UDT,
      KI_UDT, 1, KI_UDT, 1, 0, KI_UDT);


  DEFAULT_NULL (dbe_column_add (tb_cols, CN_COLS_TBL, CI_COLS_TBL, DV_SHORT_STRING));
  DEFAULT_NULL (dbe_column_add (tb_cols, CN_COLS_COL, CI_COLS_COL, DV_SHORT_STRING));
  DEFAULT_NULL (dbe_column_add (tb_cols, CN_COLS_COL_ID, CI_COLS_COL_ID, DV_LONG_INT));
  DEFAULT_NULL (dbe_column_add (tb_cols, CN_COLS_DTP, CI_COLS_DTP, DV_SHORT_INT));
  DEFAULT_NULL (dbe_column_add (tb_cols, CN_COLS_PREC, CI_COLS_PREC, DV_LONG_INT));
  DEFAULT_NULL (dbe_column_add (tb_cols, CN_COLS_SCALE, CI_COLS_SCALE, DV_SHORT_INT));
  DEFAULT_NULL (dbe_column_add (tb_cols, CN_COLS_DEFAULT, CI_COLS_DEFAULT, DV_SHORT_STRING));
  DEFAULT_NULL (dbe_column_add (tb_cols, CN_COLS_CHECK, CI_COLS_CHECK, DV_SHORT_STRING));
  DEFAULT_NULL (dbe_column_add (tb_cols, CN_COLS_NULLABLE, CI_COLS_NULLABLE, DV_SHORT_INT));
  DEFAULT_NULL (dbe_column_add (tb_cols, CN_COLS_NTH, CI_COLS_NTH, DV_SHORT_INT));
  DEFAULT_NULL (dbe_column_add (tb_cols, CN_COLS_OPTIONS, CI_COLS_OPTIONS, DV_ANY));

  DEFAULT_NULL (dbe_column_add (tb_keys, CN_KEYS_TBL, CI_KEYS_TBL, DV_SHORT_STRING));
  DEFAULT_NULL (dbe_column_add (tb_keys, CN_KEYS_KEY, CI_KEYS_KEY, DV_SHORT_STRING));
  DEFAULT_NULL (dbe_column_add (tb_keys, CN_KEYS_ID, CI_KEYS_ID, DV_LONG_INT));
  DEFAULT_NULL (dbe_column_add (tb_keys, CN_KEYS_SIGNIFICANT, CI_KEYS_SIGNIFICANT,
      DV_SHORT_INT));
  DEFAULT_NULL (dbe_column_add (tb_keys, CN_KEYS_CLUSTER_ON_ID ,CI_KEYS_CLUSTER_ON_ID,
      DV_SHORT_INT));
  DEFAULT_NULL (dbe_column_add (tb_keys, CN_KEYS_IS_MAIN, CI_KEYS_IS_MAIN, DV_SHORT_INT));
  DEFAULT_NULL (dbe_column_add (tb_keys, CN_KEYS_IS_OBJECT_ID, CI_KEYS_IS_OBJECT_ID,
      DV_SHORT_INT));
  DEFAULT_NULL (dbe_column_add (tb_keys, CN_KEYS_IS_UNIQUE, CI_KEYS_IS_UNIQUE, DV_SHORT_INT));
  DEFAULT_NULL (dbe_column_add (tb_keys, CN_KEYS_MIGRATE_TO, CI_KEYS_MIGRATE_TO, DV_LONG_INT));
  DEFAULT_NULL (dbe_column_add (tb_keys, CN_KEYS_SUPER_ID, CI_KEYS_SUPER_ID, DV_LONG_INT));
  DEFAULT_NULL (dbe_column_add (tb_keys, CN_KEYS_DECL_PARTS, CI_KEYS_DECL_PARTS, DV_SHORT_INT));
  DEFAULT_NULL (dbe_column_add (tb_keys, CN_KEYS_STORAGE, CI_KEYS_STORAGE, DV_STRING));
  DEFAULT_NULL (dbe_column_add (tb_keys, CN_KEYS_OPTIONS, CI_KEYS_OPTIONS, DV_ANY));
  DEFAULT_NULL (dbe_column_add (tb_keys, CN_KEYS_VERSION, CI_KEYS_VERSION, DV_SHORT_INT));

  DEFAULT_NULL (dbe_column_add (tb_key_parts, CN_KPARTS_ID, CI_KPARTS_ID, DV_LONG_INT));
  DEFAULT_NULL (dbe_column_add (tb_key_parts, CN_KPARTS_N, CI_KPARTS_N, DV_SHORT_INT));
  DEFAULT_NULL (dbe_column_add (tb_key_parts, CN_KPARTS_COL_ID, CI_KPARTS_COL_ID,
      DV_LONG_INT));

  DEFAULT_NULL (dbe_column_add (tb_collations, CN_COLLATIONS_NAME, CI_COLLATIONS_NAME, DV_SHORT_STRING));
  DEFAULT_NULL (dbe_column_add (tb_collations, CN_COLLATIONS_WIDE, CI_COLLATIONS_WIDE, DV_SHORT_INT));
  DEFAULT_NULL (dbe_column_add (tb_collations, CN_COLLATIONS_TABLE, CI_COLLATIONS_TABLE, DV_BLOB_BIN));

  DEFAULT_NULL (dbe_column_add (tb_charsets, CN_CHARSET_NAME, CI_CHARSET_NAME, DV_SHORT_STRING));
  DEFAULT_NULL (dbe_column_add (tb_charsets, CN_CHARSET_TABLE, CI_CHARSET_TABLE, DV_WIDE));
  DEFAULT_NULL (dbe_column_add (tb_charsets, CN_CHARSET_ALIASES, CI_CHARSET_ALIASES, DV_BLOB_BIN));

  DEFAULT_NULL (dbe_column_add (tb_sub, CN_SUB_SUPER, CI_SUB_SUPER, DV_LONG_INT));
  DEFAULT_NULL (dbe_column_add (tb_sub, CN_SUB_SUB, CI_SUB_SUB, DV_LONG_INT));


  DEFAULT_NULL (dbe_column_add (tb_frags, CN_FRAGS_KEY, CI_FRAGS_KEY, DV_LONG_INT));
  DEFAULT_NULL (dbe_column_add (tb_frags, CN_FRAGS_NO, CI_FRAGS_NO, DV_LONG_INT));
  DEFAULT_NULL (dbe_column_add (tb_frags, CN_FRAGS_START, CI_FRAGS_START, DV_ANY));
  DEFAULT_NULL (dbe_column_add (tb_frags, CN_FRAGS_STORAGE, CI_FRAGS_STORAGE, DV_STRING));
  DEFAULT_NULL (dbe_column_add (tb_frags, CN_FRAGS_SERVER, CI_FRAGS_SERVER, DV_STRING));

  DEFAULT_NULL (dbe_column_add (tb_udt, CN_UDT_NAME	  , CI_UDT_NAME	      , DV_STRING));
  DEFAULT_NULL (dbe_column_add (tb_udt, CN_UDT_PARSE_TREE , CI_UDT_PARSE_TREE , DV_BLOB));
  col = dbe_column_add (tb_udt, CN_UDT_ID	  , CI_UDT_ID	      , DV_LONG_INT);
  DEFAULT_NULL (col);
  col->col_is_autoincrement = 1;
  DEFAULT_NULL (dbe_column_add (tb_udt, CN_UDT_MIGRATE_TO , CI_UDT_MIGRATE_TO , DV_LONG_INT));

  key_add_part (key_cols_id, CI_COLS_COL_ID);
  key_add_part (key_cols_id, CI_COLS_TBL);
  key_add_part (key_cols_id, CI_COLS_COL);
  key_add_part (key_cols_id, CI_COLS_DTP);
  key_add_part (key_cols_id, CI_COLS_PREC);
  key_add_part (key_cols_id, CI_COLS_SCALE);
  key_add_part (key_cols_id, CI_COLS_DEFAULT);
  key_add_part (key_cols_id, CI_COLS_CHECK);
  key_add_part (key_cols_id, CI_COLS_NULLABLE);
  key_add_part (key_cols_id, CI_COLS_NTH);
  key_add_part (key_cols_id, CI_COLS_OPTIONS);

  key_add_part (key_cols_name, CI_COLS_TBL);
  key_add_part (key_cols_name, CI_COLS_COL);
  key_add_part (key_cols_name, CI_COLS_COL_ID);

  key_add_part (key_keys, CI_KEYS_TBL);
  key_add_part (key_keys, CI_KEYS_KEY);
  key_add_part (key_keys, CI_KEYS_ID);
  key_add_part (key_keys, CI_KEYS_SIGNIFICANT);
  key_add_part (key_keys, CI_KEYS_CLUSTER_ON_ID);
  key_add_part (key_keys, CI_KEYS_IS_MAIN);
  key_add_part (key_keys, CI_KEYS_IS_OBJECT_ID);
  key_add_part (key_keys, CI_KEYS_IS_UNIQUE);
  key_add_part (key_keys, CI_KEYS_MIGRATE_TO);
  key_add_part (key_keys, CI_KEYS_SUPER_ID);
  key_add_part (key_keys, CI_KEYS_DECL_PARTS);
  key_add_part (key_keys, CI_KEYS_STORAGE);
  key_add_part (key_keys, CI_KEYS_OPTIONS);
  key_add_part (key_keys, CI_KEYS_VERSION);

  key_add_part (key_keys_id, CI_KEYS_ID);
  key_add_part (key_keys_id, CI_KEYS_TBL);
  key_add_part (key_keys_id, CI_KEYS_KEY);

  key_add_part (key_key_parts, CI_KPARTS_ID);
  key_add_part (key_key_parts, CI_KPARTS_N);
  key_add_part (key_key_parts, CI_KPARTS_COL_ID);

  key_add_part (key_collations, CI_COLLATIONS_NAME);
  key_add_part (key_collations, CI_COLLATIONS_WIDE);
  key_add_part (key_collations, CI_COLLATIONS_TABLE);

  key_add_part (key_charsets, CI_CHARSET_NAME);
  key_add_part (key_charsets, CI_CHARSET_TABLE);
  key_add_part (key_charsets, CI_CHARSET_ALIASES);

  key_add_part (key_sub, CI_SUB_SUPER);
  key_add_part (key_sub, CI_SUB_SUB);


  key_add_part (key_frags, CI_FRAGS_KEY);
  key_add_part (key_frags, CI_FRAGS_NO);
  key_add_part (key_frags, CI_FRAGS_START);
  key_add_part (key_frags, CI_FRAGS_STORAGE);
  key_add_part (key_frags, CI_FRAGS_SERVER);

  key_add_part (key_udt, CI_UDT_NAME);
  key_add_part (key_udt, CI_UDT_PARSE_TREE);
  key_add_part (key_udt, CI_UDT_ID);
  key_add_part (key_udt, CI_UDT_MIGRATE_TO);

  dbe_key_layout (key_cols_id, sc);
  dbe_key_layout (key_cols_name, sc);
  dbe_key_layout (key_keys, sc);
  dbe_key_layout (key_keys_id, sc);
  dbe_key_layout (key_key_parts, sc);
  dbe_key_layout (key_collations, sc);
  dbe_key_layout (key_charsets, sc);
  dbe_key_layout (key_sub, sc);
  dbe_key_layout (key_frags, sc);
  dbe_key_layout (key_udt, sc);

  if (!wi_inst.wi_schema)
    wi_inst.wi_schema = sc;

  dbe_key_open_ap (key_cols_id, prev_sc);
  dbe_key_open_ap (key_cols_name, prev_sc);
  dbe_key_open_ap (key_keys, prev_sc);
  dbe_key_open_ap (key_keys_id, prev_sc);
  dbe_key_open_ap (key_key_parts, prev_sc);
  dbe_key_open_ap (key_collations, prev_sc);
  dbe_key_open_ap (key_charsets, prev_sc);
  dbe_key_open_ap (key_sub, prev_sc);
  dbe_key_open_ap (key_frags, prev_sc);
  dbe_key_open_ap (key_udt, prev_sc);
  if (!bitmap_col_desc)
    {
      bitmap_col_desc = (dbe_column_t *) dk_alloc (sizeof (dbe_column_t));
      memset (bitmap_col_desc, 0, sizeof (dbe_column_t));
      bitmap_col_desc->col_id = CI_BITMAP;
      bitmap_col_desc->col_sqt.sqt_dtp = DV_STRING;
      bitmap_col_desc->col_sqt.sqt_non_null = 1;
      bitmap_col_desc->col_compression = CC_NONE;
    }
}


void
dbe_key_sub_open (dbe_key_t * key)
{
  dbe_key_t * sup = key;
  while (sup->key_supers)
    sup = (dbe_key_t *) sup->key_supers->data;
  key->key_fragments = sup->key_fragments;
  key->key_partition = sup->key_partition;
}

dbe_schema_t *
isp_read_schema (lock_trx_t * lt)
{
  caddr_t err;
  dk_set_t err_tables = NULL; /* list of table names with errors in reading schema. Will be undefd */
  buffer_desc_t *buf_cols, *buf_keys, *buf_kparts, *buf_collations, *buf_charsets, *buf_udt;
  dbe_schema_t *sc;
  it_cursor_t *itc_cols = itc_create (NULL, lt);
  it_cursor_t *itc_keys = itc_cols;
  it_cursor_t *itc_kparts = itc_cols;
  it_cursor_t *itc_collations = itc_cols;
  it_cursor_t *itc_charsets = itc_cols;
  it_cursor_t *itc_udt = itc_cols;
  dbe_schema_t * prev_sc = wi_inst.wi_schema;

  sc = dbe_schema_create (NULL);
  sch_create_meta_seed (sc, prev_sc);
  wi_inst.wi_schema = sc;

  if (strchr (wi_inst.wi_open_mode, 'a'))
    return sc;

#ifdef UDT_HASH_DEBUG
  dbg_udt_print_class_hash (isp_schema (NULL), "before table read", NULL);
#endif
  ITC_FAIL (itc_cols)
  {
    caddr_t err;
    /* types */
    itc_from (itc_udt, sch_id_to_key (sc, KI_UDT));
    buf_udt = itc_reset (itc_udt);
    while (DVC_MATCH == itc_next (itc_udt, &buf_udt))
      {
	char *udt_name = itc_box_column (itc_udt, buf_udt,
	    CI_UDT_NAME, NULL);
	caddr_t udt_parse_tree = itc_box_column (itc_udt, buf_udt,
	    CI_UDT_PARSE_TREE, NULL);
	long udt_id = itc_long_column (itc_udt, buf_udt, CI_UDT_ID) + 1;
	caddr_t udt_migrate_to_box =
	    itc_box_column (itc_udt, buf_udt, CI_UDT_MIGRATE_TO, NULL);
	long udt_migrate_to = 0;
	caddr_t udt_parse_tree_text = udt_parse_tree;
	caddr_t udt_parse_tree_box;
	sql_class_t *cls, *new_cls;

	err = NULL;
	if (DV_TYPE_OF (udt_migrate_to_box) == DV_LONG_INT)
	  udt_migrate_to = (long) unbox (udt_migrate_to_box) + 1;

	if (DV_TYPE_OF (udt_parse_tree) == DV_BLOB_HANDLE)
	  {
	    err = NULL;
	    udt_parse_tree_text = safe_blob_to_string (lt, udt_parse_tree, &err);
	    dk_free_box (udt_parse_tree);
	    if (err)
	      {
		log_error (
		    "Error reading user defined type %s : %s: %s."
		    "It will not be defined. Drop the type and recreate it.", udt_name,
		    ((caddr_t *) err)[QC_ERRNO], ((caddr_t *) err)[QC_ERROR_STRING]);
		dk_free_tree (err);
		continue;
	      }
	  }
	else
	  udt_parse_tree_text = udt_parse_tree;

	udt_parse_tree_box = box_deserialize_string (udt_parse_tree_text, 0, 0);
	dk_free_box (udt_parse_tree_text);
	cls = sch_name_to_type (sc, udt_name);
	new_cls = udt_compile_class_def (sc, udt_parse_tree_box, cls, &err, 1,
	    lt->lt_client, udt_id, udt_migrate_to);
	if (new_cls != cls)
	  {
	    id_casemode_hash_set (sc->sc_name_to_object[sc_to_type], new_cls->scl_qualifier_name,
		new_cls->scl_owner,
		(caddr_t) &new_cls);
	  }
	new_cls->scl_id = udt_id;
	new_cls->scl_migrate_to = udt_migrate_to;
	dk_free_tree (udt_parse_tree_box);
	if (err && IS_BOX_POINTER (err))
	  {
	    log_error ("Error while compiling the type %.200s: [%s] %.750s", udt_name,
		ERR_STATE (err), ERR_MESSAGE (err));
	    dk_free_tree (err);
	    err = NULL;
	  }
	else if (err)
	  {
	    log_error ("Error while compiling the type %.200s: <NOT FOUND>", udt_name);
	    err = NULL;
	  }
	dk_free_box (udt_name);
      }
    err = NULL;
#ifdef UDT_HASH_DEBUG
  dbg_udt_print_class_hash (isp_schema (NULL), "after table read", NULL);
#endif
    itc_page_leave (itc_udt, buf_udt);
    udt_resolve_instantiable (sc, &err);
    if (err && IS_BOX_POINTER (err))
      {
	log_error ("Error : [%s] %.100s",
	    ERR_STATE (err), ERR_MESSAGE (err));
	dk_free_tree (err);
	err = NULL;
      }
    else if (err)
      {
	log_error ("Error : <NOT FOUND>");
	err = NULL;
      }

    /* collations */
    itc_from (itc_collations, sch_id_to_key (sc, KI_COLLATIONS));
    buf_collations = itc_reset (itc_collations);
    while (DVC_MATCH == itc_next (itc_collations, &buf_collations))
      {
	char *coll_name = itc_box_column (itc_collations, buf_collations,
	    CI_COLLATIONS_NAME, NULL);
	char *coll_table = itc_box_column (itc_collations, buf_collations,
	    CI_COLLATIONS_TABLE, NULL);
	long coll_wide = itc_long_column (itc_collations, buf_collations,
	    CI_COLLATIONS_WIDE);
	dtp_t coll_dtp = box_tag (coll_table);
	NEW_VARZ(collation_t, coll);
	coll->co_name = coll_name;
	switch (coll_dtp) {
	  case DV_BLOB_HANDLE:
	  case DV_BLOB_WIDE_HANDLE:
	    {
	      caddr_t err = NULL;
	      coll->co_table = safe_blob_to_string (lt, coll_table, &err);
	      if (err)
		{
		  log_error (
		      "Error reading collation %s definition : %s: %s."
		      "It will not be defined. Drop the collation and recreate it.", coll_name,
		      ((caddr_t *) err)[QC_ERRNO], ((caddr_t *) err)[QC_ERROR_STRING]);
		  dk_free_tree (err);
		  continue;
		}
	      break;
	    }
	  default:
	    coll->co_table = dk_alloc_box (256, DV_C_STRING);
	    if (coll_table && box_length(coll_table) >= 255 && coll_wide == 0)
	      memcpy(coll->co_table, coll_table, 256);
	    break;
	};
	id_hash_set (global_collations, (caddr_t) & coll_name, (caddr_t) & coll);
	dk_free_box (coll_table);
      }
    itc_page_leave (itc_collations, buf_collations);

    if (default_collation_name)
      default_collation = sch_name_to_collation (default_collation_name);

    /* charsets */
    itc_from (itc_charsets, sch_id_to_key (sc, KI_CHARSETS));
    buf_charsets = itc_reset (itc_charsets);
    if (!global_wide_charsets)
      global_wide_charsets = id_str_hash_create (50);
    while (DVC_MATCH == itc_next (itc_charsets, &buf_charsets))
      {
	char *cs_name = itc_box_column (itc_charsets, buf_charsets,
	    CI_CHARSET_NAME, NULL);
	char *cs_table = itc_box_column (itc_charsets, buf_charsets,
	    CI_CHARSET_TABLE, NULL);
	char *cs_aliases = itc_box_column (itc_charsets, buf_charsets,
	    CI_CHARSET_ALIASES, NULL);
	caddr_t *cs_aliases_array;
	wchar_t *wcs_table;
	wcharset_t *wcharset;
	int inx;

	if (DV_STRINGP (cs_aliases) || (DV_BIN == DV_TYPE_OF (cs_aliases)))
	  {
	    cs_aliases_array = (caddr_t *) box_deserialize_string (cs_aliases, 0, 0);
	  }
       else if (IS_BLOB_HANDLE (cs_aliases))
	  {
	    caddr_t str, err = NULL;
            str = safe_blob_to_string (lt, cs_aliases, &err);
	    if (err)
	      {
		log_error (
		    "Error reading charset %s definition: %s: %s."
		    "It will not be defined. Drop the charset and recreate it.", cs_name,
		    ((caddr_t *) err)[QC_ERRNO], ((caddr_t *) err)[QC_ERROR_STRING]);
		dk_free_tree (err);
		continue;
	      }
	    cs_aliases_array = (caddr_t *) box_deserialize_string (str, 0, 0);
	    dk_free_box (str);
	  }
	else
	  {
	    if (DV_DB_NULL != DV_TYPE_OF (cs_aliases))
	      log_error ("wrong CS_ALIASES value for charset %s. Ignoring the aliases", cs_name);
	    cs_aliases_array = (caddr_t *) dk_alloc_box (0, DV_ARRAY_OF_POINTER);
	  }
	wcs_table = (wchar_t *) (DV_TYPE_OF (cs_table) == DV_DB_NULL ? NULL : cs_table);
	wcharset = wide_charset_create (cs_name, wcs_table,
	    box_length (cs_table) / sizeof (wchar_t) - 1, cs_aliases_array);

	if (!default_charset && default_charset_name && !strcmp (default_charset_name, cs_name))
	  default_charset = wcharset;
	id_hash_set (global_wide_charsets, (caddr_t) &cs_name, (caddr_t) &wcharset);

	DO_BOX (caddr_t, alias_name, inx, cs_aliases_array)
	  {
	    if (!default_charset && default_charset_name && !strcmp (default_charset_name, alias_name))
	      default_charset = wcharset;
	    alias_name = box_dv_short_string (alias_name);
	    id_hash_set (global_wide_charsets, (caddr_t) &alias_name, (caddr_t) &wcharset);
	  }
	END_DO_BOX;
	dk_free_box (cs_table);
	dk_free_tree (cs_aliases);
      }
    itc_page_leave (itc_charsets, buf_charsets);

    itc_from (itc_cols, sch_id_to_key (sc, KI_COLS));
    buf_cols = itc_reset (itc_cols);
    while (DVC_MATCH == itc_next (itc_cols, &buf_cols))
      {
	char *tb_name = sch_complete_table_name (
	    itc_box_column (itc_cols, buf_cols, CI_COLS_TBL, NULL));
	char *col_name = itc_box_column (itc_cols, buf_cols,
	    CI_COLS_COL, NULL);
	oid_t col_id = itc_long_column (itc_cols, buf_cols, CI_COLS_COL_ID);
	dtp_t dtp = (dtp_t) itc_long_column (itc_cols, buf_cols, CI_COLS_DTP);
	dbe_table_t *tb = sch_name_to_table (sc, tb_name);
	dbe_column_t *col;

	if (!tb)
	  tb = dbe_table_create (sc, tb_name);
	col = dbe_column_add (tb, col_name, col_id, dtp);
	dk_free_box (tb_name);
	dk_free_box (col_name);
      }
    itc_page_leave (itc_cols, buf_cols);

    itc_from (itc_cols, sch_id_to_key (sc, KI_COLS_ID));
    buf_cols = itc_reset (itc_cols);
    while (DVC_MATCH == itc_next (itc_cols, &buf_cols))
      {
	oid_t col_id = itc_long_column (itc_cols, buf_cols, CI_COLS_COL_ID);
	dtp_t dtp = (dtp_t) itc_long_column (itc_cols, buf_cols, CI_COLS_DTP);
	dbe_column_t *col = (dbe_column_t *)
	gethash ((void *) (ptrlong) col_id, sc->sc_id_to_col);

	if (col)
	  {
	    caddr_t col_default;
	    col->col_sqt.sqt_dtp = dtp;
	    col->col_scale = (char) itc_long_column (itc_cols, buf_cols,
		CI_COLS_SCALE);
	    col->col_precision = itc_long_column (itc_cols, buf_cols,
						  CI_COLS_PREC);
	    col->col_non_null = (1 == itc_long_column (itc_cols, buf_cols,
		CI_COLS_NULLABLE));
	    col_default = itc_box_column (itc_cols, buf_cols,
		CI_COLS_DEFAULT, NULL);
	    if (DV_TYPE_OF (col_default) == DV_SHORT_STRING || DV_TYPE_OF (col_default) == DV_LONG_STRING)
	      {
		caddr_t def, err_ret = NULL;
		col->col_default = def = box_deserialize_string (col_default, 0, 0);
		if (dtp != DV_TYPE_OF (def) && DV_TYPE_OF (def) != DV_DB_NULL)
		  {
		    def = box_cast_to (NULL, def, DV_TYPE_OF (def), dtp, NUMERIC_MAX_PRECISION, NUMERIC_MAX_SCALE, &err_ret);
		    dk_free_tree (col->col_default);
		    if (!err_ret)
		      col->col_default = def;
		    else
		      {
			col->col_default = dk_alloc_box (0, DV_DB_NULL);
			dk_free_tree (err_ret);
		      }
		  }
	      }
	    else
	      col->col_default = dk_alloc_box (0, DV_DB_NULL);
	    dk_free_tree (col_default);

	    col->col_options = (caddr_t *) itc_box_column (itc_cols, buf_cols,
		CI_COLS_OPTIONS, NULL);
	    col->col_check = itc_box_column (itc_cols, buf_cols,
		CI_COLS_CHECK, NULL);
	    dbe_column_parse_options (col);
	  }
      }
    itc_page_leave (itc_cols, buf_cols);


    /* Make the keys */
    itc_from (itc_keys, sch_id_to_key (sc, KI_KEYS));
    buf_keys = itc_reset (itc_keys);

    while (DVC_MATCH == itc_next (itc_keys, &buf_keys))
      {
	char *tb_name = sch_complete_table_name (
	    itc_box_column (itc_keys, buf_keys, CI_KEYS_TBL, NULL));
	char *key_name = itc_box_column (itc_keys, buf_keys,
	    CI_KEYS_KEY, NULL);
	caddr_t key_storage = itc_box_column (itc_keys, buf_keys,
	    CI_KEYS_STORAGE, NULL);
	key_id_t id = (key_id_t) itc_long_column (itc_keys, buf_keys,
	    CI_KEYS_ID);
	int n = (int) itc_long_column (itc_keys, buf_keys, CI_KEYS_SIGNIFICANT);
	int cluster_on_id = (int) itc_long_column (itc_keys, buf_keys,
	    CI_KEYS_CLUSTER_ON_ID);
	int is_main = (int) itc_long_column (itc_keys, buf_keys,
	    CI_KEYS_IS_MAIN);
	key_id_t migrate_to = (key_id_t) itc_long_column (itc_keys, buf_keys,
	    CI_KEYS_MIGRATE_TO);
	key_id_t super_id = (key_id_t) itc_long_column (itc_keys, buf_keys,
	    CI_KEYS_SUPER_ID);
	int d_parts = (int) itc_long_column (itc_keys, buf_keys,
	    CI_KEYS_DECL_PARTS);
	dbe_key_t *key;
	dbe_table_t *tb = sch_name_to_table (sc, tb_name);
	dbe_storage_t * dbs = wd_storage (wi_ctx_db (), key_storage);
	if (!dbs)
	  {
	    log_error ("Storage unit %s in %s not open.", key_storage, wi_ctx_db ()->wd_qualifier);
	    dk_set_push (&err_tables, (void*) box_copy (tb_name));
	    continue;
	  }
	if (!tb)
	  tb = dbe_table_create (sc, tb_name);

	key = dbe_key_create (sc, tb, key_name, id, n, cluster_on_id, is_main,
	    migrate_to, super_id);
	key->key_storage = dbs;
	key->key_is_unique = (int) itc_long_column (itc_keys, buf_keys,
	    CI_KEYS_IS_UNIQUE);
	key->key_decl_parts = d_parts;
	key->key_options = (caddr_t *) itc_box_column (itc_keys, buf_keys,
					   CI_KEYS_OPTIONS, NULL);
	key->key_version =  itc_long_column (itc_keys, buf_keys,
					   CI_KEYS_VERSION);
	dk_free_box (tb_name);
	dk_free_box (key_name);
	dk_free_box (key_storage);
      }
    itc_page_leave (itc_keys, buf_keys);

    itc_from (itc_kparts, sch_id_to_key (sc, KI_KEY_PARTS));
    buf_kparts = itc_reset (itc_kparts);

    while (DVC_MATCH == itc_next (itc_kparts, &buf_kparts))
      {
	key_id_t key_id = (key_id_t) itc_long_column (itc_kparts, buf_kparts,
	    CI_KPARTS_ID);
	oid_t col_id = itc_long_column (itc_kparts, buf_kparts,
	    CI_KPARTS_COL_ID);
	dbe_key_t *key = sch_id_to_key (sc, key_id);
	dbe_table_t *tb = key ? key->key_table : NULL;
	dbe_column_t *col = (dbe_column_t *) gethash ((void *) (ptrlong) col_id,
	    sc->sc_id_to_col);
#ifndef NO_META_DEBUG
	dbg_printf (("  %s, %d: %s,  %s\n",
	    ((NULL == key) ? "<NULL key>" : key->key_name),
	    key_id,
	    ((NULL == key) ? "<NULL table>" : key->key_table->tb_name),
	    ((NULL == col) ? "<NULL column>" : col->col_name)
	    ));
#endif
	if (tb && col && key)
	  {
	    id_hash_set (tb->tb_name_to_col, (caddr_t) & col->col_name,
		(caddr_t) & col);
	    key_add_part (key, col_id);
	  }
      }
    itc_page_leave (itc_kparts, buf_kparts);
  }
  ITC_FAILED
  {
    itc_free (itc_cols);
  }
  END_FAIL (itc_cols);
  itc_free (itc_cols);

  err = it_read_object_dd (lt, sc);
  if (err)
    sqlr_resignal (err);
  {
    dk_hash_iterator_t hit;
    ptrlong id, k;
    dk_hash_iterator (&hit, wi_inst.wi_schema->sc_id_to_key);
    while (dk_hit_next (&hit, (void**) &id, (void**) &k))
      {
	dbe_key_t * key = (dbe_key_t *) k;
	if (!key->key_key_fixed && !key->key_key_var)
	  {
	    dbe_key_layout (key, sc);
	    if (!key->key_supers)
	      dbe_key_open (key);
	  }
      }
    dk_hash_iterator (&hit, wi_inst.wi_schema->sc_id_to_key);
    while (dk_hit_next (&hit, (void**) &id, (void**) &k))
      {
	dbe_key_t * key = (dbe_key_t *) k;
	if (key->key_supers)
	  dbe_key_sub_open (key);
      }
  }
  return sc;
}


#define COLS_TEXT \
"select \"TABLE\", \"COLUMN\", COL_ID, COL_DTP, " \
/* 4 */ " COL_PREC," \
/* 5 */ " COL_SCALE," \
/* 6 */ " COL_NULLABLE, " \
/* 7 */ "COL_CHECK,"  \
/* 8 */ " deserialize (COL_DEFAULT), " \
/* 9 */ "COL_OPTIONS "  \
"from DB.DBA.SYS_COLS where \"TABLE\" = ?"


#define KEYS_TEXT \
"select KEY_TABLE, KEY_NAME, KEY_ID, " \
/* 3 */ "KEY_N_SIGNIFICANT," \
/* 4 */ "KEY_CLUSTER_ON_ID," \
/* 5 */ " KEY_IS_MAIN," \
/* 6 */ " KEY_IS_OBJECT_ID," \
/* 7 */ " KEY_IS_UNIQUE," \
/* 8 */ " KEY_MIGRATE_TO," \
/* 9 */ " KEY_SUPER_ID," \
/* 10 */ " KEY_DECL_PARTS, " \
/* 11 */ " KEY_STORAGE, " \
/* 12 */ " KEY_OPTIONS, " \
/*13*/ " KEY_VERSION " \
" from DB.DBA.SYS_KEYS where KEY_TABLE = ?"


long
unbox_or_null (caddr_t box)
{
  if (IS_BOX_POINTER (box))
    {
      dtp_t dtp = box_tag (box);
      if (DV_LONG_INT == dtp)
	return (long)(unbox (box));
      return 0;
    }
  return (long)((ptrlong) box);
}


void
sch_drop_table (dbe_schema_t * sc, char *tb_name)
{
  dbe_table_t *tb = sch_name_to_table (sc, tb_name);
  if (tb)
    {
      id_casemode_hash_remove (sc->sc_name_to_object[sc_to_table], tb->tb_qualifier_name, tb->tb_owner);
      if (tb->tb_primary_key)
	{
	  /* if schema inconsistent, could be there's no PK. check for safety */
	  DO_SET (dbe_column_t *, col, &tb->tb_primary_key->key_parts)
	    {
	      if (col->col_defined_in == tb)
		remhash ((void *) (ptrlong) col->col_id, sc->sc_id_to_col);
	    }
	  END_DO_SET ();
	  tb_mark_affected (tb_name);
	}
    }
}




dbe_table_t *
qi_name_to_table (query_instance_t * qi, const char *name)
{
  dbe_table_t *tb;
  if (parse_sem)
    semaphore_enter (parse_sem);
  sqlc_set_client (qi->qi_client);
  tb = sch_name_to_table (isp_schema (NULL), name);
  if (parse_sem)
    semaphore_leave (parse_sem);
  return tb;
}


void
key_upd_frag_keys (dbe_key_t * key)
{
  int inx;
  DO_BOX (dbe_key_frag_t *, kf, inx, key->key_fragments)
    {
      kf->kf_it->it_key = key;
    }
  END_DO_BOX;
}


dk_mutex_t * sch_reread_mtx;
static query_t *tb_qr;
static query_t *key_qr;
static query_t *kp_qr;


caddr_t
qi_read_table_schema_1 (query_instance_t * qi, char *read_tb, dbe_schema_t * sc)
{
  dbe_table_t * defined_table = NULL;
  local_cursor_t * lc = NULL, * kp_lc = NULL;
  lock_trx_t * lt = qi->qi_trx;
  caddr_t err;
  sch_drop_table (sc, read_tb);
  err = qr_rec_exec (tb_qr, qi->qi_client, &lc, qi, NULL, 1,
      ":0", read_tb, QRP_STR);
  if (err)
    return err;
  /* make */
  while (lc_next (lc))
    {
      char *tb_name = sch_complete_table_name (box_copy (lc_nth_col (lc, 0)));
      char *col_name = lc_nth_col (lc, 1);
      oid_t col_id = unbox_or_null (lc_nth_col (lc, 2));
      dtp_t dtp = (dtp_t) unbox_or_null (lc_nth_col (lc, 3));
      dbe_table_t *tb = sch_name_to_table (sc, tb_name);
      dbe_column_t *col;
      caddr_t def;

      if (!tb)
	{
	  tb = dbe_table_create (sc, tb_name);
	  defined_table = tb;
	}
      col = dbe_column_add (tb, col_name, col_id, dtp);

      col->col_sqt.sqt_dtp = dtp;
      col->col_precision = unbox_or_null (lc_nth_col (lc, 4));
      col->col_scale = (char) unbox_or_null (lc_nth_col (lc, 5));
      col->col_non_null = (1 == unbox_or_null (lc_nth_col (lc, 6)));
      col->col_check = box_copy (lc_nth_col (lc, 7));
      col->col_default = def = box_copy_tree (lc_nth_col (lc, 8));
      if (dtp != DV_TYPE_OF (def) && DV_TYPE_OF (def) != DV_DB_NULL)
	{
	  caddr_t err_ret = NULL;
	  def = box_cast_to (NULL, def, DV_TYPE_OF (def), dtp, NUMERIC_MAX_PRECISION, NUMERIC_MAX_SCALE, &err_ret);
	  dk_free_tree (col->col_default);
	  if (!err_ret)
	    col->col_default = def;
	  else /* cannot cast and too late */
	    {
	      col->col_default = dk_alloc_box (0, DV_DB_NULL);
	      dk_free_tree (err_ret);
	    }
	}
      col->col_options = (caddr_t *) box_copy_tree (lc_nth_col (lc, 9));
      dbe_column_parse_options (col);
      dbe_col_load_stats (qi->qi_client, qi, tb, col);

      dk_free_box (tb_name);
    }
  err = lc->lc_error;
  lc_free (lc);
  if (err)
    return err;
  err = qr_rec_exec (key_qr, qi->qi_client, &lc, qi, NULL, 1, ":0", read_tb, QRP_STR);

  if (err)
    return err;
  while (lc_next (lc))
    {
      char *tb_name = sch_complete_table_name (box_copy (lc_nth_col (lc, 0)));
      char *key_name = lc_nth_col (lc, 1);
      char * key_storage = lc_nth_col (lc, 11);
      dbe_storage_t * dbs = wd_storage (wi_ctx_db (), key_storage);
      key_id_t id = (key_id_t) unbox_or_null (lc_nth_col (lc, 2));
      int n = (int) unbox_or_null (lc_nth_col (lc, 3));
      int cluster_on_id = (int) unbox_or_null (lc_nth_col (lc, 4));
      int is_main = (int) unbox_or_null (lc_nth_col (lc, 5));
      key_id_t migrate_to = (key_id_t) unbox_or_null (lc_nth_col (lc, 8));
      key_id_t super_id = (key_id_t) unbox_or_null (lc_nth_col (lc, 9));
      int d_parts = (int) unbox_or_null (lc_nth_col (lc, 10));
      dbe_key_t *key;
      dbe_table_t *tb = sch_name_to_table (sc, tb_name);

      if (!dbs)
	{
	  return (srv_make_new_error ("4000X", "SR447", "Table references undefined storage unit"));
	}
      if (!tb)
	{
	  tb = dbe_table_create (sc, tb_name);
	  defined_table = tb;
	}

      key = dbe_key_create (sc, tb, key_name, id, n, cluster_on_id, is_main,
	  migrate_to, super_id);
      key->key_is_unique = (int) unbox_or_null (lc_nth_col (lc, 7));
      key->key_decl_parts = d_parts;
      key->key_options = (caddr_t*) box_copy_tree (lc_nth_col (lc, 12));
      key->key_version = unbox (lc_nth_col (lc, 13));
      key->key_storage = dbs;
      dk_free_box (tb_name);

      err = qr_rec_exec (kp_qr, qi->qi_client, &kp_lc, qi, NULL, 1,
	  ":0", (ptrlong) id, QRP_INT);
      if (err)
	return err;
      while (lc_next (kp_lc))
	{
	  oid_t col_id = unbox_or_null (lc_nth_col (kp_lc, 0));
	  dbe_table_t *tb = key->key_table;
	  dbe_column_t *col = (dbe_column_t *) gethash ((void *) (ptrlong) col_id, sc->sc_id_to_col);
#ifndef NO_META_DEBUG
	  dbg_printf (("  %s, %d: %s,  %s\n",
	      ((NULL != key) ? key->key_name : "(NULL->key_name)"),
	      id,
	      ((NULL != key) ? key->key_table->tb_name : "(NULL->key_table->tb_name)"),
	      ((NULL != col) ? col->col_name : "(NULL->col_name)")
	      ));
#endif
	  if (tb && col && key)
	    {
	      id_hash_set (tb->tb_name_to_col, (caddr_t) & col->col_name,
		  (caddr_t) & col);
	      key_add_part (key, col_id);
	    }
	}
      err = kp_lc->lc_error;
      lc_free (kp_lc);
      if (err)
	return err;
    }
  err = lc->lc_error;
  lc_free (lc);
  if (err)
    return err;
  err = it_read_object_dd (lt, sc);
  if (err)
    return err;
  if (!defined_table)
    return NULL; /* in the case of drop table */
  DO_SET (dbe_key_t *, k, &defined_table->tb_keys)
    {
      dbe_key_layout (k, sc);
    }
  END_DO_SET ();
  DO_SET (dbe_key_t *, k, &defined_table->tb_old_keys)
    {
      dbe_key_layout (k, sc);
    }
  END_DO_SET ();
  err = sec_read_grants (qi->qi_client, qi, read_tb, 0);
  if (err)
    return err;
  err = sec_read_tb_rls (qi->qi_client, qi, read_tb);
  if (err)
    return err;
#ifdef BIF_XML
  if (sch_name_to_table (isp_schema (NULL), "DB.DBA.SYS_VT_INDEX"))
    err = qi_tb_xml_schema (qi, read_tb);
  if (err)
    return err;
#endif
  return NULL;
}


static void
qi_read_table_drop_deleted_keys (dbe_table_t *old_table, dbe_table_t *defined_table)
{
  DO_SET (dbe_key_t *, old_key, &old_table->tb_keys)
    {
      int old_key_present = 0;
      DO_SET (dbe_key_t *, new_key, &defined_table->tb_keys)
	{
	  if (new_key->key_id == old_key->key_id)
	    {
	      old_key_present = 1;
	      break;
	    }
	}
      END_DO_SET ();
      DO_SET (dbe_key_t *, new_key, &defined_table->tb_old_keys)
	{
	  if (new_key->key_id == old_key->key_id)
	    {
	      old_key_present = 1;
	      break;
	    }
	}
      END_DO_SET ();
      if (!old_key_present)
	key_dropped (old_key);
    }
  END_DO_SET();
  DO_SET (dbe_key_t *, old_key, &old_table->tb_old_keys)
    {
      int old_key_present = 0;
      DO_SET (dbe_key_t *, new_key, &defined_table->tb_keys)
	{
	  if (new_key->key_id == old_key->key_id)
	    {
	      old_key_present = 1;
	      break;
	    }
	}
      END_DO_SET ();
      DO_SET (dbe_key_t *, new_key, &defined_table->tb_old_keys)
	{
	  if (new_key->key_id == old_key->key_id)
	    {
	      old_key_present = 1;
	      break;
	    }
	}
      END_DO_SET ();
      if (!old_key_present)
	key_dropped (old_key);
    }
  END_DO_SET();
}


void
qi_read_table_schema_old_keys (query_instance_t * qi, char *read_tb, dk_set_t old_keys)
{
  dbe_table_t * defined_table, *old_table;
  caddr_t err;
  lock_trx_t *lt = qi->qi_trx;
  dbe_schema_t *sc = wi_inst.wi_schema;

  if (!kp_qr)
    {
      tb_qr = sql_compile_static (COLS_TEXT, lt->lt_client, NULL, 0);
      key_qr = sql_compile_static (KEYS_TEXT, lt->lt_client, NULL, 0);
      kp_qr = sql_compile_static (
	  "select KP_COL from DB.DBA.SYS_KEY_PARTS where KP_KEY_ID = ?",
	  lt->lt_client, NULL, 0);
    }

  old_table = sch_name_to_table (wi_inst.wi_schema, read_tb);
  lt->lt_pending_schema = dbe_schema_copy (sc);
  err = qi_read_table_schema_1 (qi, read_tb, lt->lt_pending_schema);

  if (!qi->qi_trx->lt_branch_of && !old_keys
      && !qi->qi_client->cli_in_daq)
    {
      ddl_commit_trx (qi);
      if (!qi->qi_client->cli_is_log)
	cl_ddl (qi, qi->qi_trx, read_tb, CLO_DDL_TABLE, NULL);
    }
  else
    ddl_commit_trx (qi);
  defined_table = sch_name_to_table (wi_inst.wi_schema, read_tb);
  if (!defined_table)
    {
      if (!old_table)
	return;
      DO_SET (dbe_key_t *, key, &old_table->tb_keys)
	{
	  key_dropped (key);
	}
      END_DO_SET();
      return;
    }
  else if (old_table)
    qi_read_table_drop_deleted_keys (old_table, defined_table);
  DO_SET (dbe_key_t *, k, &defined_table->tb_keys)
    {
      if (old_table)
	{
	  DO_SET (dbe_key_t *, old_k, &old_table->tb_keys)
	    {
	      if (!strcmp (old_k->key_name, k->key_name))
		{
		  k->key_fragments = old_k->key_fragments;
		  key_upd_frag_keys (k);
		  goto next;
		}
	    }
	  END_DO_SET();
	}
      if (old_keys)
	{
	  s_node_t *iter = old_keys;
	  while (iter)
	    {
	      key_id_t old_k_id = (key_id_t) ((ptrlong) (iter->data));
	      dbe_key_frag_t **old_kfs = (dbe_key_frag_t **)iter->next->data;
	      if (old_k_id == k->key_id)
		{
		  int inx;
		  k->key_fragments = old_kfs;
		  DO_BOX (dbe_key_frag_t *, kf, inx, k->key_fragments)
		    {
		      char str[MAX_NAME_LEN * 4];
		      IN_TXN;
		      dbs_registry_set (kf->kf_it->it_storage, kf->kf_name, NULL, 1);
		      LEAVE_TXN;
		      snprintf (str, sizeof (str), "__key__%s:%s:%d", k->key_table->tb_name, k->key_name, inx + 1);
		      dk_free_box (kf->kf_name);
		      kf->kf_name = box_dv_short_string (str);
		      kf->kf_it->it_key = k;
		      if (kf->kf_it->it_extent_map != kf->kf_it->it_storage->dbs_extent_map)
			{
			  extent_map_t * em = kf->kf_it->it_extent_map;
			  IN_TXN;
			  dbs_registry_set (em->em_dbs, em->em_name, NULL, 1);
			  LEAVE_TXN;
			  snprintf (str, sizeof (str), "__EM:%s", kf->kf_name);
			  dk_free_box (em->em_name);
			  em->em_name = box_dv_short_string (str);
			}
		    }
		  END_DO_BOX;
		  goto next;
		}
	      iter = iter->next->next;
	    }
	}
      if (k->key_supers)
	dbe_key_sub_open (k);
      else
	dbe_key_open (k);
    next: ;

    }
  END_DO_SET ();
  DO_SET (dbe_key_t *, k, &defined_table->tb_old_keys)
    {
      dbe_key_sub_open (k);
    }
  END_DO_SET();
}


void
qi_read_table_schema (query_instance_t * qi, char *read_tb)
{
  qi_read_table_schema_old_keys (qi, read_tb, NULL);
}


search_spec_t *
dbe_key_insert_spec (dbe_key_t * key)
{
  int inx = 0, n;
  search_spec_t **next_spec = &key->key_insert_spec.ksp_spec_array;


  for (n = 0; n < key->key_n_significant; n++)
    {
      dbe_column_t *col = (dbe_column_t *) dk_set_nth(key->key_parts, n);
      NEW_VARZ (search_spec_t, sp);

      sp->sp_min = inx;
      sp->sp_min_op = CMP_EQ;
      sp->sp_max_op = CMP_NONE;

      sp->sp_next = NULL;
      *next_spec = sp;
      next_spec = &sp->sp_next;
      sp->sp_cl = *key_find_cl (key, col->col_id);
      if (col)
	{
	  sp->sp_collation = col->col_sqt.sqt_collation;
	}
      inx++;
    }
  ksp_cmp_func (&key->key_insert_spec, NULL);
  return (key->key_insert_spec.ksp_spec_array);
}


dk_set_t
key_ensure_visible_parts (dbe_key_t * key)
{
  dk_set_t parts = NULL;
  int ctr, inx;
  dbe_column_t *cols[VDB_TB_MAX_COLS];
  int n_cols = 0;
  if (key->key_visible_parts)
    return (key->key_visible_parts);
  DO_SET (dbe_column_t *, col, &key->key_parts)
  {
    if (n_cols >= sizeof (cols) / sizeof (caddr_t))
      break;
    if (0 != strcmp (col->col_name, "_IDN")
	)
      {
	cols[n_cols++] = col;
      }
  }
  END_DO_SET ();

  for (ctr = n_cols - 1; ctr > 0; ctr--)
    for (inx = 0; inx < ctr; inx++)
      {
	if (cols[inx]->col_id > cols[inx + 1]->col_id)
	  {
	    dbe_column_t *tm = cols[inx];
	    cols[inx] = cols[inx + 1];
	    cols[inx + 1] = tm;
	  }
      }
  for (ctr = n_cols - 1; ctr >= 0; ctr--)
    parts = dk_set_cons ((caddr_t) cols[ctr], parts);
  key->key_visible_parts = parts;
  return (key->key_visible_parts);
}


char *
cli_owner (client_connection_t * cli)
{
  char *u;
  if (!cli || !cli->cli_user)
    return ("DBA");
  u = cli->cli_user->usr_name;
  if (0 == strcmp (u, "dba"))
    return ("DBA");
  return u;
}


char *
cli_qual (client_connection_t * cli)
{
  if (cli)
    return (cli->cli_qualifier);
  return NULL;
}


id_hash_t *sc_name_to_view;


caddr_t
sch_view_def (dbe_schema_t * sc, const char *name)
{
  caddr_t *place;
  if (!sc_name_to_view)
    sc_name_to_view = id_str_hash_create (201);

  place = (caddr_t *) id_hash_get (sc_name_to_view, (caddr_t) & name);
  if (!place)
    return NULL;
  return (*place);
}


void
sch_set_view_def (dbe_schema_t * sc, char *name, caddr_t tree)
{
  caddr_t *old_tree = NULL;

  if (!sc_name_to_view)
    sc_name_to_view = id_str_hash_create (201);
  else
    old_tree = (caddr_t *) id_hash_get (sc_name_to_view, (caddr_t) &name);

  if (old_tree)
    {
#if defined (PURIFY) || defined (VALGRIND)
      if (*old_tree)
	dk_set_push (&sc->sc_old_views, *old_tree);
#endif
      *old_tree = box_copy_tree (tree);
    }
  else
    {
      name = box_dv_short_string (name);
      tree = box_copy_tree (tree);
      id_hash_set (sc_name_to_view, (caddr_t) & name, (caddr_t) & tree);
    }
}



