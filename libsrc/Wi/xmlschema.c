/*
 *  xmlschema.c
 *
 *  $Id$
 *
 *  Dynamic SQL Compiler, part 2
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

#include "sqlnode.h"
#include "eqlcomp.h"
#include "xmlnode.h"
#include "sqlpar.h"
#include "sqlpfn.h"
#include "sqlcmps.h"
#include "sqlfn.h"
#include "sqlbif.h"
#include "xml.h"
#include "xmltree.h"


char *xmlt1 =
"create table SYS_ELEMENT_TABLE (\n"
"	ET_ELEMENT varchar, \n"
"	ET_TABLE varchar,\n"
"	primary key (ET_ELEMENT))";

char *xmlt2 =
"create table SYS_ELEMENT_MAP (\n"
"	EM_TABLE varchar,\n"
"	EM_A_ID integer,\n"
"	EM_COL_ID integer,\n"
"	primary key (EM_TABLE,EM_COL_ID))";

char *xmlt3 =
"create table SYS_ATTR (\n"
"	A_NAME varchar,\n"
"	A_ID integer,\n"
"	primary key (A_ID))";

char *xmlt4 =
"create table SYS_ATTR_META (AM_A_ID integer, AM_URI varchar, \n"
"	AM_DATA varchar,\n"
"	primary key (AM_A_ID, AM_URI))";


char * xmlt5 =
"create table SYS_VT_INDEX (VI_TABLE varchar, VI_INDEX varchar, VI_COL varchar, "
"	VI_ID_COL varchar, VI_INDEX_TABLE varchar,"
"       VI_ID_IS_PK integer, VI_ID_CONSTR varchar,"
"       VI_OFFBAND_COLS varchar, VI_OPTIONS varchar, VI_LANGUAGE varchar, VI_ENCODING varchar,"
"       primary key (VI_TABLE, VI_COL))\n"
"alter index SYS_VT_INDEX on SYS_VT_INDEX partition cluster REPLICATED";


xml_schema_t *xml_global;



xml_schema_t *
xs_allocate (void)
{
  NEW_VARZ (xml_schema_t, xs);

  xs->xs_id_to_attr = hash_table_allocate (101);
  xs->xs_name_to_attr = id_str_hash_create (2003);
  xs->xs_element_table = id_str_hash_create (101);
  xs->xs_key_id_to_element = hash_table_allocate (101);
  xs->xs_views = id_str_hash_create (101);
  xs->xs_old_views = (dk_set_t  *) dk_alloc_zero (sizeof (dk_set_t));/*mapping schema*/
  return xs;
}

xml_attr_t *
xml_attr_allocate (oid_t id, char *name)
{
  NEW_VARZ (xml_attr_t, xa);
  xa->xa_id = id;
  xa->xa_name = box_dv_short_string (name);
  {
    NEW_VARZ (dbe_column_t, col);
    col->col_is_misc = 1;
    col->col_name = box_dv_short_string (name);
    col->col_id = id;
    col->col_sqt.sqt_dtp = DV_LONG_STRING;
    xa->xa_col = col;
  }
  return xa;
}


key_id_t entity_key_id;
key_id_t textfrag_key_id;
oid_t entity_misc_col_id;
oid_t entity_name_col_id;
oid_t entity_wspace_col_id;
oid_t entity_id_col_id;
oid_t entity_level_col_id;
oid_t entity_leading_col_id;
oid_t entity_trailing_col_id;
oid_t textfrag_leading_col_id;
oid_t textfrag_long_col_id;
dbe_table_t * entity_table;
dbe_table_t * textfrag_table;


char * ent_map_text =
"create procedure xml_element_table (in tb varchar, in element varchar, in attr_col varchar)\n"
"{\n"
"  declare c integer;\n"
"  if (not exists (select 1 from SYS_KEYS where KEY_TABLE = tb))\n"
"    signal ('S0002', 'No table in xml_entity_map');\n"
"  insert soft SYS_ELEMENT_TABLE (ET_ELEMENT, ET_TABLE) values (element, tb);\n"
"  declare inx integer;\n"
"  inx := 0;\n"
"  while (inx < length (attr_col)) {\n"
"    declare cid, aid integer;\n"
"    whenever not found goto no_col;\n"
"    select COL_ID into cid from SYS_COLS \n"
"      where \\TABLE = tb and \\COLUMN = aref (attr_col, inx);\n"
"    xml_attr (aref (attr_col, inx + 1));\n"
"    select A_ID into aid from SYS_ATTR where A_NAME = aref (attr_col, inx + 1);\n"
"    insert soft SYS_ELEMENT_MAP (EM_TABLE, EM_COL_ID, EM_A_ID) values (tb, cid, aid);\n"
"    inx := inx + 2;\n"
"  }\n"
"  xmls_element_table (element, tb);\n"
"  log_text ('xmls_element_table (?, ?)', element, tb);\n"
"  select sum ((xmls_element_col (tb, EM_COL_ID, EM_A_ID),\n"
"	       log_text ('xmls_element_col (?, ?, ?)', tb, EM_COL_ID, EM_A_ID))) \n"
"    into c from SYS_ELEMENT_MAP where EM_TABLE = tb;\n"
"  return;\n"
" no_col:\n"
"  signal ('S0022', 'No column or attribute in xml_element_element_table');\n"
"}";

void
xmls_init (void)
{
  local_cursor_t *lc;
  caddr_t err;
  query_t *qr;
  dbe_table_t *tb;
  ddl_ensure_table ("DB.DBA.SYS_ELEMENT_TABLE", xmlt1);
  ddl_ensure_table ("DB.DBA.SYS_ELEMENT_MAP", xmlt2);
  ddl_ensure_table ("DB.DBA.SYS_ATTR", xmlt3);
  ddl_ensure_table ("DB.DBA.SYS_ATTR_META", xmlt4);
  ddl_ensure_table ("DB.DBA.SYS_VT_INDEX", xmlt5);

  ddl_std_proc (ent_map_text, 1);

  if (!xml_global)
    xml_global = xs_allocate ();

  qr = sql_compile_static ("select A_ID, A_NAME from SYS_ATTR",
		    bootstrap_cli, &err, SQLC_DEFAULT);
  if (NULL != err) goto no_attrs;
  err = qr_quick_exec (qr, bootstrap_cli, "", &lc, 0);
  while (lc_next (lc))
    {
      oid_t a_id = (oid_t) unbox (lc_nth_col (lc, 0));
      caddr_t name = box_copy_tree (lc_nth_col (lc, 1));
      xml_attr_t *xa = xml_attr_allocate (a_id, name);
      id_hash_set (xml_global->xs_name_to_attr, (caddr_t) & xa->xa_name, (caddr_t) & xa);
      sethash ((void *) (ptrlong) a_id, xml_global->xs_id_to_attr, (void *) xa);
    }
  lc_free (lc);
  qr_free (qr);
no_attrs:
  ddl_sel_for_effect ("select count (*) from SYS_ELEMENT_TABLE where xmls_element_table (ET_ELEMENT, ET_TABLE)");
  ddl_sel_for_effect ("select count (*) from SYS_ELEMENT_MAP where xmls_element_col (EM_TABLE, EM_COL_ID, EM_A_ID)");
  tb = sch_name_to_table (isp_schema (NULL), "DB.DBA.SYS_VT_INDEX");
  if (tb && tb_name_to_column (tb, LAST_FTI_COL))
    ddl_sel_for_effect ("select count (*)  from SYS_VT_INDEX where 0 = __vt_index (VI_TABLE, VI_INDEX, VI_COL, VI_ID_COL, VI_INDEX_TABLE, deserialize (VI_OFFBAND_COLS), VI_LANGUAGE, VI_ENCODING, deserialize (VI_ID_CONSTR), VI_OPTIONS)");
  else
    ddl_sel_for_effect ("select count (*)  from SYS_VT_INDEX where 0 = __vt_index (VI_TABLE, VI_INDEX, VI_COL, VI_ID_COL, VI_INDEX_TABLE, deserialize (VI_OFFBAND_COLS), VI_LANGUAGE, NULL, deserialize (VI_ID_CONSTR), VI_OPTIONS)");
#ifdef OLD_VXML_TABLES
  xp_comp_init ();
#endif
  xml_tree_init ();
  xml_lazy_init ();
}


xml_attr_t *
lt_xml_attr (lock_trx_t * lt, char *name)
{
  xml_attr_t **place;
  xml_local_t *xl = lt ? (xml_local_t *) lt->lt_cd : NULL;
  if (xl)
    {
      xml_attr_t *xa;
      oid_t key;
      dk_hash_iterator_t hit;
      dk_hash_iterator (&hit, xl->xl_local_attrs);
      while (dk_hit_next (&hit, (void **) &key, (void **) &xa))
	{
	  if (0 == strcmp (xa->xa_name, name))
	    return (xa);
	}
    }
  place = (xml_attr_t **) id_hash_get (xml_global->xs_name_to_attr, (caddr_t) & name);
  if (!place)
    return NULL;
  return (*place);
}


xml_attr_t *
lt_xml_attr_by_id (lock_trx_t * lt, oid_t a_id)
{
  xml_local_t *xl = lt ? (xml_local_t *) lt->lt_cd : NULL;
  if (xl)
    {
      xml_attr_t *xa = (xml_attr_t *) gethash ((void *) (ptrlong) a_id, xl->xl_local_attrs);
      if (xa)
	return xa;
    }
  return ((xml_attr_t *) gethash ((void *) (ptrlong) a_id, xml_global->xs_id_to_attr));
}


dbe_column_t *
lt_xml_col (lock_trx_t * lt, char *name)
{
  xml_attr_t *xa = lt_xml_attr (lt, name);
  if (xa)
    return (xa->xa_col);
  return NULL;
}





void
xml_local_commit (lock_trx_t * lt)
{
  xml_local_t *xl = (xml_local_t *) lt->lt_cd;
  dk_hash_iterator_t hit;
  void *k;
  xml_attr_t *xa;

  if (!xl)
    return;
  lt->lt_cd = NULL;
  dk_hash_iterator (&hit, xl->xl_local_attrs);
  while (dk_hit_next (&hit, (void **) &k, (void **) (void **) &xa))
    {
      sethash ((void *) (ptrlong) xa->xa_id, xml_global->xs_id_to_attr, (void *) xa);
      id_hash_set (xml_global->xs_name_to_attr, (caddr_t) & xa->xa_name, (caddr_t) & xa);
    }
  hash_table_free (xl->xl_local_attrs);
  dk_free ((caddr_t) xl, sizeof (xml_local_t));
}


void
xml_local_rollback (lock_trx_t * lt)
{
  xml_local_t *xl = (xml_local_t *) lt->lt_cd;
  dk_hash_iterator_t hit;
  void *k;
  xml_attr_t *xa;

  if (!xl)
    return;
  lt->lt_cd = NULL;
  dk_hash_iterator (&hit, xl->xl_local_attrs);
  while (dk_hit_next (&hit, (void **) &k, (void **) &xa))
    {
      dk_free_box (xa->xa_name);
      dk_free ((caddr_t) xa, sizeof (xml_attr_t));
    }
  hash_table_free (xl->xl_local_attrs);
  dk_free ((caddr_t) xl, sizeof (xml_local_t));
}


xml_local_t *
xml_local_allocate (lock_trx_t * lt)
{
  NEW_VARZ (xml_local_t, xl);
  xl->xl_local_attrs = hash_table_allocate (101);
  lt->lt_cd = (void *) xl;
  lt->lt_commit_hook = xml_local_commit;
  lt->lt_rollback_hook = xml_local_rollback;
  return xl;
}


void
lt_local_attr (lock_trx_t * lt, char *name, oid_t a_id)
{
  xml_local_t *xl = (xml_local_t *) lt->lt_cd;
  xml_attr_t *xa = xml_attr_allocate (a_id, name);
  if (!xl)
    {
      xl = xml_local_allocate (lt);
    }
  sethash ((void *) (ptrlong) a_id, xl->xl_local_attrs, (void *) xa);
}


caddr_t
bif_xml_attr_replay (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;
  caddr_t name = bif_string_arg (qst, args, 0, "xml_arg_replay");
  oid_t id = (oid_t) bif_long_arg (qst, args, 1, "xml_arg_replay");
  lt_local_attr (qi->qi_trx, name, id);
  return 0;
}


caddr_t
bif_xml_attr (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;
  caddr_t name = bif_string_arg (qst, args, 0, "xml_attr");
  oid_t id;
  caddr_t arr;
  xml_attr_t *attr = lt_xml_attr (qi->qi_trx, name);
  if (attr)
    return (box_num (attr->xa_id));
  id = qi_new_attr (qi, name);
  arr = (caddr_t) list (3, box_dv_short_string ("xml_attr_replay (?, ?)"), box_copy (name), box_num (id));
  log_text_array (qi->qi_trx, arr);
  dk_free_tree (arr);
  return (box_num (id));
}


oid_t
qi_new_attr (query_instance_t * qi, char *name)
{
  oid_t a_id;
  local_cursor_t *lc;
  caddr_t err = NULL;
  static query_t *new_attr_qr;
  static query_t *ins_attr_qr;

  if (!new_attr_qr)
    {
      new_attr_qr = sql_compile_static ("select A_ID from DB.DBA.SYS_ATTR order by A_ID desc for update",
				 bootstrap_cli, &err, SQLC_DEFAULT);
      ins_attr_qr = sql_compile_static ("insert into DB.DBA.SYS_ATTR (A_ID, A_NAME) values (?, ?)",
				 bootstrap_cli, &err, SQLC_DEFAULT);
      if (err)
	sqlr_resignal (err);
    }
  err = qr_rec_exec (new_attr_qr, qi->qi_client, &lc, qi, NULL, 0);
  if (err)
    sqlr_resignal (err);
  if (lc_next (lc))
    {
      a_id = (oid_t) unbox (lc_nth_col (lc, 0));
    }
  else
    a_id = MIN_MISC_ID;
  lc_free (lc);
  a_id++;
  err = qr_rec_exec (ins_attr_qr, qi->qi_client, NULL, qi, NULL, 2,
		     ":0", (ptrlong) a_id, QRP_INT,
		     ":1", name, QRP_STR);
  if (err)
    sqlr_resignal (err);

  lt_local_attr (qi->qi_trx, name, a_id);
  return a_id;
}





oid_t
lt_attr_col_id (lock_trx_t * lt, key_id_t key_id, oid_t a_id)
{
  return a_id;
}


dbe_table_t *
xmls_element_table (char * elt)
{
  dbe_table_t ** place = (dbe_table_t **)
    id_hash_get (xml_global->xs_element_table, (caddr_t) &elt);
  if (place)
    return (*place);
  return NULL;
}


caddr_t
bif_xmls_element_table (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;
  caddr_t e_name = bif_string_arg (qst, args, 0, "xmls_element_table");
  caddr_t tb_name = bif_string_arg (qst, args, 1, "xmls_element_table");
  caddr_t e_copy = box_copy (e_name);
  dbe_table_t *tb = sch_name_to_table (isp_schema (qi->qi_space), tb_name);
  if (!tb)
    return (box_num (-1));
  id_hash_set (xml_global->xs_element_table, (caddr_t) & e_copy, (caddr_t) & tb);
  sethash ((void *)(ptrlong) tb->tb_primary_key->key_id, xml_global->xs_key_id_to_element, (void *) e_copy);
  return (box_num (0));
}


caddr_t
bif_xmls_element_col (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;
  caddr_t tb_name = bif_string_arg (qst, args, 0, "xmld_element_col");
  ptrlong cid = bif_long_arg (qst, args, 1, "xmls_element_col");
  ptrlong aid = bif_long_arg (qst, args, 2, "xmls_element_col");
  dbe_table_t *tb = sch_name_to_table (isp_schema (qi->qi_space), tb_name);
  if (!tb)
    return (box_num (-1));
  if (!tb->tb_misc_id_to_col_id)
    {
      tb->tb_misc_id_to_col_id = hash_table_allocate (11);
      tb->tb_col_id_to_misc_id = hash_table_allocate (11);
    }
  sethash ((void *) cid, tb->tb_col_id_to_misc_id, (void *) aid);
  sethash ((void *) aid, tb->tb_misc_id_to_col_id, (void *) cid);
  return (box_num (0));
}


caddr_t
bif_vt_index (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t *) qst;
  dbe_schema_t * pending_sc = qi->qi_trx->lt_pending_schema;
  dbe_schema_t * global_sc = /*isp_schema (qi->qi_trx->lt_after_space)*/ wi_inst.wi_schema;
  caddr_t tb_name = bif_string_arg (qst, args, 0, "vt_index");
  caddr_t index_name = bif_string_arg (qst, args, 1, "vt_index");
  caddr_t text_col_name = bif_string_arg (qst, args, 2, "vt_index");
  caddr_t id_col_name = bif_string_arg (qst, args, 3, "vt_index");
  caddr_t index_tb_name = bif_string_arg (qst, args, 4, "vt_index");
  dbe_table_t * tb = NULL;
  dbe_table_t * inx_tb = sch_name_to_table (isp_schema (qi->qi_space), index_tb_name);
  dbe_column_t * text_col, * id_col;
  dbe_key_t * id_key = NULL;
  caddr_t lang = NULL;
  caddr_t enc = NULL;
  caddr_t * offb_data = NULL;
  caddr_t * constr_data = NULL;

  if (pending_sc)
    tb  = sch_name_to_table (pending_sc, tb_name);
  if (!tb)
    tb  = sch_name_to_table (global_sc, tb_name);
  if (!tb)
    sqlr_error ("S0002", "No table in vt_index");
  if (!inx_tb)
    sqlr_error ("S0002", "No index table in vt_index");
  DO_SET (dbe_key_t *, key, &tb->tb_keys)
    {
      if (0 == strcmp (key->key_name, index_name))
	{
	id_key = key;
	  break;
	}
    }
  END_DO_SET ();
  if (!id_key)
    sqlr_error ("S0022", "no index in vt_index");
  id_col = tb_name_to_column (tb, id_col_name);
  text_col = tb_name_to_column (tb, text_col_name);
  if (!text_col)
    {
      /* text col is always case insensitive.  Trick to allow geo and ft inxon the same o col of rdf_quad */
      DO_SET (dbe_column_t *, col, &tb->tb_primary_key->key_parts)
	{
	  if (0 == stricmp (col->col_name, text_col_name))
	    {
	      text_col = col;
	      break;
	    }
	}
      END_DO_SET();
    }
  if (!id_col || !text_col)
    sqlr_error ("S0002", "No column in vt_index");
    {
    id_key->key_text_table = inx_tb;
    id_key->key_text_col = text_col;
    text_col->col_is_text_index = 1;
    }
  /* added: init of language & offband cols members */
  if (BOX_ELEMENTS (args) > 5)
    {
      int ix, len;
      dbe_column_t ** off_cols;
      dbe_column_t * off_col;
      offb_data = (caddr_t *) bif_arg (qst, args, 5, "vt_index");
      if (IS_BOX_POINTER (text_col->col_offband_cols))
	dk_free_box ((caddr_t)(text_col->col_offband_cols));
      if (offb_data && DV_ARRAY_OF_POINTER == DV_TYPE_OF (offb_data) && BOX_ELEMENTS (offb_data)  > 0)
	{
	  len = BOX_ELEMENTS (offb_data);
	  off_cols = (dbe_column_t **) dk_alloc_box (len * sizeof (void *), DV_ARRAY_OF_POINTER);
	  for (ix = 0; ix < len; ix++)
	    {
	      off_col = tb_name_to_column (tb, offb_data [ix]);
	      off_cols [ix] = off_col;
	    }
	  text_col->col_offband_cols = off_cols;
	}
      else
	text_col->col_offband_cols = NULL;
    }
  if (BOX_ELEMENTS (args) > 6)
    {
      lang = bif_string_or_null_arg (qst, args, 6, "vt_index");
      if (IS_BOX_POINTER(text_col->col_lang))
	dk_free_box (text_col->col_lang);
      if (lang)
	{
	  text_col->col_lang = box_copy (lang);
	}
      else
	text_col->col_lang = NULL;
    }
  if (BOX_ELEMENTS (args) > 7)
    {
      enc = bif_string_or_null_arg (qst, args, 7, "vt_index");
      if (IS_BOX_POINTER(text_col->col_enc))
	dk_free_box (text_col->col_enc);
      if (enc)
	{
	  text_col->col_enc = box_copy (enc);
	}
      else
	text_col->col_enc = NULL;
    }
  if (BOX_ELEMENTS (args) > 8)
    {
      int ix, len;
      dbe_column_t ** constr_cols;
      dbe_column_t * constr_col;
      constr_data = (caddr_t *) bif_arg (qst, args, 8, "vt_index");
      if (IS_BOX_POINTER (text_col->col_constr_cols))
	dk_free_box ((caddr_t)(text_col->col_constr_cols));
      if (constr_data && DV_ARRAY_OF_POINTER == DV_TYPE_OF (constr_data) && BOX_ELEMENTS (constr_data) > 0)
	{
	  len = BOX_ELEMENTS (constr_data);
	  constr_cols = (dbe_column_t **) dk_alloc_box (len * sizeof (void *), DV_ARRAY_OF_POINTER);
	  for (ix = 0; ix < len; ix++)
	    {
	      constr_col = tb_name_to_column (tb, constr_data [ix]);
	      constr_cols [ix] = constr_col;
	    }
	  text_col->col_constr_cols = constr_cols;
	}
      else
	text_col->col_constr_cols = NULL;
    }
  tb->tb__text_key = id_key;
  return 0;
}


dbe_column_t *
tb_name_to_column_misc (dbe_table_t * tb, char *name)
{
  dbe_column_t *col = tb_name_to_column (tb, name);
  if (!col
      && sch_is_subkey_incl (/*isp_schema (db_main_tree->it_commit_space)*/ wi_inst.wi_schema, tb->tb_primary_key->key_id, entity_key_id))
    {
      col = lt_xml_col (NULL, name);
      if (col && tb->tb_misc_id_to_col_id)
	{
	  oid_t cid = (oid_t) (ptrlong) gethash ((void *) (ptrlong) col->col_id, tb->tb_misc_id_to_col_id);
	  if (cid)
	    {
	      DO_SET (dbe_column_t *, col2, &tb->tb_primary_key->key_parts)
	      {
		if (col2->col_id == cid)
		  return col2;
	      }
	      END_DO_SET ();
	    }
	}
    }
  return col;
}


caddr_t
qi_sel_for_effect (query_instance_t * qi, char *str, int n_pars,...)
{
  char *a1[8];
  char *a2[8];
  long a3[8];
  int inx;
  va_list ap;
  caddr_t err;
  local_cursor_t *lc;
  query_t *qr = sql_compile (str, bootstrap_cli, &err, SQLC_DEFAULT);
  if (err != (caddr_t) SQL_SUCCESS)
    return err;
  va_start (ap, n_pars);

  if (n_pars > 4)
    GPF_T1 ("no more than 9 args for qi_sel_for_effect");
  for (inx = 0; inx < n_pars; inx++)
    {
      a1[inx] = va_arg (ap, char *);
      a2[inx] = va_arg (ap, char *);
      a3[inx] = va_arg (ap, long);
    }

  err = qr_rec_exec (qr,qi->qi_client,  &lc, qi, NULL, n_pars,
		       a1[0], a2[0], a3[0],
		       a1[1], a2[1], a3[1],
		       a1[2], a2[2], a3[2],
		       a1[3], a2[3], a3[3]
    );
  if (err != (caddr_t) SQL_SUCCESS)
    return err;
  while (lc_next (lc))
    ;
  err = lc->lc_error;
  lc_free (lc);
  qr_free (qr);
  return err;
}

caddr_t
qi_tb_xml_schema (query_instance_t * qi, char *read_tb)
{
  caddr_t err;
  dbe_table_t *tb = sch_name_to_table (isp_schema (NULL), "DB.DBA.SYS_VT_INDEX");

  if (tb && !tb_name_to_column (tb, LAST_FTI_COL))
    return NULL;

  err = qi_sel_for_effect (qi, "select __vt_index (VI_TABLE, VI_INDEX, VI_COL, VI_ID_COL, VI_INDEX_TABLE, deserialize (VI_OFFBAND_COLS), VI_LANGUAGE, VI_ENCODING, deserialize (VI_ID_CONSTR), VI_OPTIONS) "
		     " from DB.DBA.SYS_VT_INDEX where VI_TABLE = ?", 1,
		     ":0", read_tb, QRP_STR);
  if (err)
    return err;
  return NULL;
}

