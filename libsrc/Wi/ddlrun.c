/*
 *  ddlrun.c
 *
 *  $Id$
 *
 *  SQL DDL Functionality
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2014 OpenLink Software
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
#include "sqlfn.h"
#include "sqlparext.h"
#include "sqlcmps.h"
#include "sqlofn.h"
#include "eqlcomp.h"
#include "lisprdr.h"
#include "xmltree.h"
#include "sqlpar.h"
#include "security.h"
#include "sqltype.h"
#include "sqltype_c.h"
#include "xml.h"
#include "statuslog.h"
#include "libutil.h"
#include "http.h"
#include "repl.h"
#include "replsr.h"
#include "map_schema.h"
#include "srvstat.h"
#include "sqlbif.h"
#include "2pc.h"


void qi_read_table_schema (query_instance_t * qi, char *read_tb);
void qi_read_table_schema_old_keys (query_instance_t * qi, char *read_tb, dk_set_t old_keys);
static void sql_error_if_remote_table (dbe_table_t *tb);
static void sch_create_table_as (query_instance_t *qi, ST * tree);



const char *add_col_text =
"insert into SYS_COLS (\"TABLE\", \"COLUMN\", COL_ID, COL_DTP, COL_PREC, COL_CHECK, COL_SCALE, COL_DEFAULT, COL_NULLABLE, COL_OPTIONS)"
" values (?, ?, ?, ?, ?, ?, ?, serialize (?), ?, ?)";
const char *add_key_text =
" insert into SYS_KEYS (KEY_TABLE, KEY_NAME, KEY_ID, KEY_N_SIGNIFICANT,"
"			KEY_CLUSTER_ON_ID, KEY_IS_MAIN, KEY_IS_OBJECT_ID, KEY_IS_UNIQUE, KEY_SUPER_ID, KEY_DECL_PARTS, KEY_VERSION)"
  " values  (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)  ";


const char *ensure_constraint_unq_txt =
"DDL_ENSURE_CONSTRAINT_NAME_UNIQUE(?)";

const char *add_key_part_text =
"insert into SYS_KEY_PARTS (KP_KEY_ID, KP_NTH, KP_COL)"
"	values (?, ?, ?)";

const char *get_col_text =
"select C.COL_ID, C.COL_CHECK, C.COL_OPTIONS from SYS_COLS C "
"  where \"TABLE\" = ? AND \"COLUMN\" = ? "
"  order by \"TABLE\", \"COLUMN\", \"COL_ID\"";

const char *cols_text =
"(seq "
"(from SYS_COLS (COL_ID COLUMN COL_CHECK COL_OPTIONS) prefix C by SYS_COLS"
"	where ((TABLE = :TB) ))"
"(select (C.COL_ID C.COLUMN C.COL_CHECK C.COL_OPTIONS)))";

const char *get_key_parts_text =
"(seq "
"(from SYS_KEY_PARTS (KP_NTH KP_COL) by SYS_KEY_PARTS prefix K"
"     where ((KP_KEY_ID = :ID) (KP_NTH < :LIMIT)))"
"(from SYS_COLS (COLUMN) by SYS_COLS prefix C where ((COL_ID = K.KP_COL)))"
"(select (K.KP_NTH K.KP_COL C.COLUMN)))";

const char *find_primary_text = "select K.KEY_ID, K.KEY_N_SIGNIFICANT, K.KEY_TABLE from SYS_KEYS K where KEY_TABLE = ? and KEY_IS_MAIN = 1 and KEY_MIGRATE_TO is null";

const char *table_cols_text =
"(seq (from SYS_COLS (COL_ID) by SYS_COLS prefix C where ((TABLE = :0)))"
"     (select (C.COL_ID)))";

const char *get_col_from_key_text =
"(seq (from SYS_KEY_PARTS (KP_COL) by SYS_KEY_PARTS prefix KP where ((KP_KEY_ID = :1)))"
"   (from SYS_COLS (COLUMN COL_DTP) by SYS_COLS prefix C where ((COL_ID = KP.KP_COL)(COLUMN = :0)))"
"  (select (KP.KP_COL C.COL_DTP)))";

const char *get_col_from_key_text_casemode_mssql =
"select KP.KP_COL, C.COL_DTP from SYS_KEY_PARTS KP, SYS_COLS C where C.COL_ID = KP.KP_COL and upper(C.\"COLUMN\") = upper(?) and KP.KP_KEY_ID = ?";

const char *get_col_text_casemode_mssql =
"select C.COL_ID, C.COL_CHECK, C.COL_OPTIONS from SYS_COLS C "
"  where upper(\"TABLE\") = upper(?) AND upper(\"COLUMN\") = upper(?) "
"  order by \"TABLE\", \"COLUMN\", \"COL_ID\"";

const char *table_cols_text_casemode_mssql = "select C.COL_ID from SYS_COLS C where upper(\"TABLE\") = upper(?)";
const char *find_primary_text_casemode_mssql = "select K.KEY_ID, K.KEY_N_SIGNIFICANT, K.KEY_TABLE from SYS_KEYS K where upper(KEY_TABLE) = upper(?) and KEY_IS_MAIN = 1 and KEY_MIGRATE_TO is null";

const char *pk_sequence_set_text = "sequence_set (?, ?, 0)";
query_t *add_col_stmt;
query_t *add_key_stmt;
query_t *ensure_constraint_unq_stmt;
query_t *add_key_part_stmt;
query_t *get_key_parts_stmt;
query_t *get_col_stmt;
query_t *cols_stmt;
query_t *find_primary_stmt;
query_t *table_cols_qr;
query_t *get_col_from_key_stmt;
query_t *pk_sequence_set_stmt;


const char *drop_key_text =
"DB.DBA.__INTERNAL_DROP_INDEX (?, ?)";

const char *proc_inherit_partition =
"create procedure DB.DBA.DDL_INHERIT_PARTITION (in tb_from varchar, in tb_to varchar, in org_id int)\n"
"{\n"
"  declare key_name varchar;\n"
"  key_name := (select KEY_NAME from SYS_KEYS where KEY_ID = org_id);\n"
"  insert into SYS_PARTITION (PART_TABLE, PART_KEY, PART_VERSION, PART_CLUSTER, PART_DATA)\n"
"  select tb_to, name_part (key_name, 2), PART_VERSION, PART_CLUSTER, vector (PART_DATA[0], tb_to, PART_DATA[2], PART_DATA[3], PART_DATA[4]) from SYS_PARTITION where PART_TABLE = tb_from and PART_KEY = name_part (key_name, 2);\n"
"}";


const char *drop_key_proc_text =
"create procedure DB.DBA.__INTERNAL_DROP_INDEX (in tb_name varchar, in idx_name varchar) \n"
"{ \n"
"  for select \n"
"    super_tb.KEY_ID as super_key_id, sub_tb.KEY_ID as sub_key_id from \n"
"     DB.DBA.SYS_KEYS super_tb, DB.DBA.SYS_KEYS sub_tb \n"
"     where \n"
"       super_tb.KEY_NAME = idx_name and super_tb.KEY_TABLE = tb_name and \n"
"       super_tb.KEY_SUPER_ID = super_tb.KEY_ID and super_tb.KEY_MIGRATE_TO is NULL \n"
"       and super_tb.KEY_ID = sub_tb.KEY_SUPER_ID \n"
"       and sub_tb.KEY_MIGRATE_TO is NULL option (order)\n"
/* note option order.  If reversed join order, the result set will go empty afterdel of main key and the other keys will not be deleted */
"  do \n"
"    { \n"
"      -- dbg_obj_print ('super ', super_key_id, 'sub ', sub_key_id);\n"
"       delete from DB.DBA.SYS_KEY_PARTS where KP_KEY_ID = sub_key_id; \n"
"       delete from DB.DBA.SYS_KEYS where KEY_ID = sub_key_id; \n"
"       delete from DB.DBA.SYS_PARTITION where PART_KEY = idx_name and PART_TABLE = tb_name;\n"
"       if (super_key_id <> sub_key_id) \n"
"         delete from DB.DBA.SYS_KEY_SUBKEY where SUPER = super_key_id and SUB = sub_key_id; \n"
"    } \n"
"} \n";

const char *key_id_text =
"(seq (from SYS_KEYS (KEY_ID) by SYS_KEYS_BY_ID prefix K where ((KEY_ID >= :FROM))) (select (K.KEY_ID)))";
const char *key_ver_text =
  "SELECT KEY_VERSION FROM SYS_KEYS WHERE KEY_SUPER_ID = ? ORDER BY KEY_VERSION";

const char *col_id_text =
"(seq (from SYS_COLS (COL_ID) by SYS_COLS prefix C where ((COL_ID >= :FROM))) (select (C.COL_ID)))";

char * proc_fill_index =
"create procedure __CREATE_INDEX_FILL (in tb_name varchar, in inx varchar)\n"
"{\n"
"  declare str, cols  varchar;\n"
"  declare is_first, old_mode int;\n"
"  is_first := 1;\n"
" cols := '';\n"
"  for select \"COLUMN\" from sys_cols, sys_keys, sys_key_parts where col_id = kp_col and kp_key_id = key_id and key_name = inx do\n"
"    {\n"
"      cols:= sprintf ('%s%s \"%I\"', cols, case when is_first then '' else ', ' end, \"COLUMN\");\n"
"      is_first := 0;\n"
"    }\n"
"  tb_name := sprintf ('\"%I\".\"%I\".\"%I\"', name_part (tb_name, 0), name_part (tb_name, 1), name_part (tb_name, 2));\n"
"  str := sprintf ('insert into %s index \"%I\" (%s) select %s from %s table option (index primary key)', tb_name, inx, cols, cols, tb_name);\n"
"  set triggers off;\n"
"  old_mode := log_enable (null, 1);\n"
" if (1 = sys_stat ('cl_run_local_only'))\n"
" log_enable (2, 1);\n"
"else log_enable (3, 1);\n"
"  exec (str);\n"
"  log_enable (old_mode, 1);\n"
"  set triggers on;\n"
"}\n";

char * proc_cl_clr_inx =
"create procedure __CL_CLR_INX (in t varchar, in k varchar)\n"
"{\n"
"  cl_exec (sprintf ('__clear_index (''%S'', ''%S'')', t, k), txn => 1);\n"
  "}\n";

char * proc_cl_log =
"create procedure __CL_LOG (in tx varchar)\n"
"{\n"
"  declare st varchar;\n"
"  st := sprintf ('log_text (''%S'')', sprintf ('%S', tx));\n"
"  cl_exec (st, txn => 1);\n"
"  commit work;\n"
"}\n";


query_t *drop_key_stmt;
query_t *key_id_stmt;
query_t *key_ver_stmt;
query_t *col_id_stmt;

char * inh_key_text =
"create procedure ddl_inherit_key  (in from_tb varchar, in to_tb varchar, in old_id int, in new_id int, in new_ver int)\n"
"{\n"
"  insert into  sys_keys (key_table, key_name, key_id, key_n_significant, \n"
"		    key_cluster_on_id, key_is_main, key_is_object_id, key_is_unique, key_super_id, key_decl_parts, key_version)\n"
"    select to_tb, key_name, new_id, key_n_significant, key_cluster_on_id, \n"
"    key_is_main, key_is_object_id, key_is_unique, key_super_id, key_decl_parts, new_ver\n"
"    from sys_keys\n"
"    where key_table = from_tb and key_id = old_id;\n"
"  insert into sys_key_subkey (super, sub) values (old_id, new_id);\n"
"  insert into sys_key_parts (kp_key_id, kp_nth, kp_col)\n"
"       select kp_key_id, kp_nth, kp_col from sys_key_parts where kp_key_id = old_id;\n"
"}\n";



void
ddl_ensure_init (client_connection_t * cli)
{
  if (!add_col_stmt)
    {
      add_col_stmt = eql_compile (add_col_text, cli);
      add_key_stmt = eql_compile (add_key_text, cli);
      add_key_part_stmt = eql_compile (add_key_part_text, cli);

      get_col_stmt = eql_compile ((case_mode == CM_MSSQL) ? get_col_text_casemode_mssql : get_col_text, cli);
      cols_stmt = eql_compile (cols_text, cli);
      get_key_parts_stmt = eql_compile (get_key_parts_text, cli);
      find_primary_stmt = eql_compile ((case_mode == CM_MSSQL) ? find_primary_text_casemode_mssql : find_primary_text, cli);
      table_cols_qr = eql_compile ((case_mode == CM_MSSQL) ? table_cols_text_casemode_mssql : table_cols_text, cli);
      get_col_from_key_stmt = eql_compile ((case_mode == CM_MSSQL) ? get_col_from_key_text_casemode_mssql : get_col_from_key_text, cli);

      drop_key_stmt = sql_compile_static (drop_key_text, cli, NULL, SQLC_DEFAULT);
      key_id_stmt = eql_compile (key_id_text, cli);
      key_ver_stmt = eql_compile (key_ver_text, cli);

      col_id_stmt = eql_compile (col_id_text, cli);
      pk_sequence_set_stmt = eql_compile (pk_sequence_set_text, cli);
      udt_ensure_init (cli);
      ddl_std_proc (inh_key_text, 0);
      ddl_std_proc (proc_fill_index, 0);
      ddl_std_proc (proc_cl_log, 0);
      ddl_std_proc (proc_cl_clr_inx, 0);
    }
}

#define QI_POISON_TRX(qi) if (qi->qi_trx) TRX_POISON (qi -> qi_trx)

#define SQL_DDL_ERROR(qi, text) \
{ \
  if (qi->qi_trx) qi->qi_trx->lt_status = LT_BLOWN_OFF; \
  sqlr_new_error text; \
}


void
ddlr_resignal (query_instance_t * qi, caddr_t err)
{
  QI_POISON_TRX (qi);
  sqlr_resignal (err);
}


char *
ddl_complete_table_name (query_instance_t * qi, char *name)
{
  dbe_table_t *tb = qi_name_to_table (qi, name);
  if (tb)
    return (tb->tb_name);
  return name;
}


dtp_t
ddl_name_to_dtp (char *name)
{
  if (DV_SYMBOL == box_tag (name))
    {
      if (0 == strcmp (name, "integer"))
	return DV_LONG_INT;
      if (0 == strcmp (name, "varchar"))
	return DV_LONG_STRING;
      if (0 == strcmp (name, "float"))
	return DV_SINGLE_FLOAT;
      if (0 == strcmp (name, "double"))
	return DV_DOUBLE_FLOAT;
      if (0 == strcmp (name, "blob"))
	return DV_BLOB;
      if (0 == strcmp (name, "time"))
        return DV_TIME;
      sqlr_new_error ("07006", "SQ014", "Not a DDL type name: %s.", name);
      return 0;			/* Never done. */
    }
  else
    {
      /* sql type. elt 0 is type spec, elt 1 is options list.
	 data type's elt 0 is the DV value, elt 1 is the length */
      ptrlong *dtp = ((ptrlong **) name)[0];
      return ((dtp_t) dtp[0]);
    }
}


long
ddl_name_to_prec (char *name)
{
  if (DV_SYMBOL == box_tag (name))
    {
      if (0 == strcmp (name, "integer"))
	return DV_LONG_INT_PREC;
      if (0 == strcmp (name, "varchar"))
	return 0;
      if (0 == strcmp (name, "float"))
	return DV_FLOAT_PREC;
      if (0 == strcmp (name, "double"))
	return DV_DOUBLE_PREC;
      if (0 == strcmp (name, "blob"))
	return 0x7fffffff;
      if (0 == strcmp (name, "time"))
        return 8;
      sqlr_new_error ("07006", "SQ015", "Not a DDL type name: %s.", name);
      return 0;			/* Never done. */
    }
  else
    {
      /* sql type. elt 0 is type spec, elt 1 is options list.
	 precision = elt 1 of DV_ARRAY_OF_POINTER, IF ANY */
      caddr_t *dtp = ((caddr_t **) name)[0];
      return (ddl_type_to_prec (dtp));
/*
   if (BOX_ELEMENTS (dtp) > 1)
   return (unbox (dtp [1]));
   else return 0;
 */
    }
}


sql_class_t *
ddl_name_to_type (char *name)
{
  if (DV_TYPE_OF (name) == DV_ARRAY_OF_POINTER)
    {
      /* sql type. elt 0 is type spec, elt 1 is options list.
	 precision = elt 1 of DV_ARRAY_OF_POINTER, IF ANY */
      caddr_t *dtp = ((caddr_t **) name)[0];
      return (ddl_type_to_class (dtp, NULL));
    }
  else
    return NULL;
}


static void
ddl_push_type_options (char *name, dk_set_t *options)
{
  if (DV_TYPE_OF (name) == DV_ARRAY_OF_POINTER)
    {
      /* sql type. elt 0 is type spec, elt 1 is options list.
	 precision = elt 1 of DV_ARRAY_OF_POINTER, IF ANY */
      caddr_t *type = ((caddr_t **) name)[0];
      if (BOX_ELEMENTS (type) > 4 && DV_TYPE_OF (type[4]) == DV_ARRAY_OF_POINTER &&
	  BOX_ELEMENTS (type[4]) % 2 == 0)
	{
	  caddr_t *opts = (caddr_t *) (type[4]);
	  int inx;
	  DO_BOX (caddr_t, opt, inx, opts)
	    {
	      dk_set_push (options, box_copy_tree (opt));
	    }
	  END_DO_BOX;
	}
    }
}


caddr_t
ddl_col_scale (char *name)
{
  if (DV_SYMBOL == box_tag (name))
    {
      return (dk_alloc_box (0, DV_DB_NULL));
    }
  else
    {
      caddr_t *dtp = ((caddr_t **) name)[0];
      if (BOX_ELEMENTS (dtp) > 2)
	return (box_copy (((caddr_t *) dtp)[2]));
      return (dk_alloc_box (0, DV_DB_NULL));
    }
}


char *
ddl_option_string (query_instance_t * qi, caddr_t * opts, dtp_t dtp, dk_set_t *col_options)
{
  char ostr[255];
  int have_col = 0;
  ostr[0] = 0;

  if (opts)
    {
      int inx;
      DO_BOX (ST *, opt, inx, opts)
	{
	  if (opt == (ST *) CO_IDENTITY)
	    strcat_ck (ostr, "I");
	  else if (IS_BOX_POINTER (opt))
	    {
	      switch (opt->type)
		{
		case CO_COMPRESS:
		  dk_set_push (col_options, box_dv_short_string ("compress"));
		  dk_set_push (col_options, (void*)box_copy (opt->_.op.arg_1));
		  break;
		case COL_COLLATE:
		  if (IS_STRING_DTP (dtp))
		    {
		      collation_t *coll = sch_name_to_collation (opt->_.op.arg_1);
		      if (!coll)
			{
			  if (qi)
			    {
			      SQL_DDL_ERROR (qi, ("42S22", "SQ003", "Collation %s is not defined", opt->_.op.arg_1));
			    }
			}
		      else
			{
			  if (IS_WIDE_STRING_DTP (dtp) && !coll->co_is_wide)
			    {
			      if (qi)
				{
				  SQL_DDL_ERROR (qi, ("42S22", "SQ140", "Collation %s is not wide", opt->_.op.arg_1));
				}
			    }
			  else
			    {
			      strcat_ck (ostr, opt->_.op.arg_1);
			      have_col = 1;
			    }
			}
		    }
		  else
		    {
		      if (qi)
			{
			  SQL_DDL_ERROR (qi, ("42S22", "SQ004", "Collation defined for a non-string column"));
			}
		    }
		  break;

		case COL_XML_ID:
		  strcat_ck (ostr, " U ");
		  strcat_ck (ostr, opt->_.op.arg_1);
		  strcat_ck (ostr, " ");
		  break;

		case CO_IDENTITY:
		  {
		    int opt_inx;
		    caddr_t * opt_arr = (caddr_t *) opt->_.op.arg_1;
		    strcat_ck (ostr, "I");
		    DO_BOX (ST *, opt, opt_inx, opt_arr)
		      {
			switch (opt->type)
			  {
			  case CO_ID_START:
			    dk_set_push (col_options, box_dv_short_string ("identity_start"));
			    dk_set_push (col_options, box_copy (opt->_.op.arg_1));
			    break;
			  case CO_ID_INCREMENT_BY:
			    dk_set_push (col_options, box_dv_short_string ("increment_by"));
			    dk_set_push (col_options, box_copy (opt->_.op.arg_1));
			    break;
			  }
		      }
		    END_DO_BOX;
		  }
		  break;
		}
	    }
	}
      END_DO_BOX;
    }
  if (!have_col && IS_STRING_DTP (dtp) && default_collation)
    strcat_ck (ostr, default_collation->co_name);

  return (box_dv_short_string (ostr));
}


char *
ddl_col_options (query_instance_t * qi, char *name, dtp_t dtp, int *is_allocated, dk_set_t *col_options)
{
  if (DV_SYMBOL == box_tag (name))
    {
      if (is_allocated)
	*is_allocated = 0;
      return ("");
    }
  else
    {
      /* sql type. elt 0 is type spec, elt 1 is options list. */
      caddr_t *opts = ((caddr_t **) name)[1];
      if (is_allocated)
	*is_allocated = 1;
      return (ddl_option_string (qi, opts, dtp, col_options));

    }
}


caddr_t
ddl_col_default (char *name)
{
  if (DV_SYMBOL == box_tag (name))
    {
      return (dk_alloc_box (0, DV_DB_NULL));
    }
  else
    {
      /* sql type. elt 0 is type spec, elt 1 is options list. */
      caddr_t *opts = ((caddr_t **) name)[1];
      int inx;
      DO_BOX (ST *, opt, inx, opts)
      {
	if (IS_BOX_POINTER (opt) && opt->type == COL_DEFAULT)
	  return (box_copy_tree (opt->_.op.arg_1));
      }
      END_DO_BOX;
    }
  return (dk_alloc_box (0, DV_DB_NULL));
}


caddr_t
ddl_col_nullable (char *name)
{
  if (DV_SYMBOL == box_tag (name))
    {
      return (dk_alloc_box (0, DV_DB_NULL));
    }
  else
    {
      /* sql type. elt 0 is type spec, elt 1 is options list. */
      caddr_t *opts = ((caddr_t **) name)[1];
      int inx;
      DO_BOX (ST *, opt, inx, opts)
      {
	if (opt == (ST *) COL_NOT_NULL
	    || (IS_BOX_POINTER (opt) && opt->type == INDEX_DEF))
	  return (box_num (1));
      }
      END_DO_BOX;
    }
  return (dk_alloc_box (0, DV_DB_NULL));
}

int
ddl_col_is_not_nullable (char *name)
{
  if (DV_SYMBOL != box_tag (name))
    {
      /* sql type. elt 0 is type spec, elt 1 is options list. */
      caddr_t *opts = ((caddr_t **) name)[1];
      int inx;
      DO_BOX (ST *, opt, inx, opts)
      {
	if (opt == (ST *) COL_NOT_NULL || (IS_BOX_POINTER (opt) && opt->type == INDEX_DEF))
	  return 1;
      }
      END_DO_BOX;
    }
  return 0;
}


int
ddl_dv_default_prec (dtp_t dtp)
{
  switch (dtp)
    {
    case DV_LONG_INT:
    case DV_SHORT_INT:
      return DV_LONG_INT_PREC;
    case DV_SINGLE_FLOAT:
      return DV_FLOAT_PREC;
    case DV_DOUBLE_FLOAT:
      return DV_DOUBLE_PREC;
    case DV_DATE:
      return DV_TIMESTAMP_PREC;
    case DV_TIMESTAMP:
      return 0;
    case DV_STRING:
    case DV_WIDE: case DV_LONG_WIDE:
      return 0;
    default:
      return 0;
    }
}


long
ddl_type_to_prec (caddr_t * type)
{
  if (BOX_ELEMENTS (type) > 1)
    {
      long prec = (long) (unbox (((caddr_t *) type)[1]));
      if (!prec)
	return (ddl_dv_default_prec ((dtp_t) ((ptrlong *) type)[0]));
      else
	return prec;
    }
  else
    return (ddl_dv_default_prec ((dtp_t) ((ptrlong *) type)[0]));
}


int
ddl_type_to_scale (caddr_t * type)
{
  if (BOX_ELEMENTS (type) > 2)
    {
      long scale = (long) (unbox (((caddr_t *) type)[2]));
      if (!scale)
	return 0;
      else
	return scale;
    }
  else
    return 0;
}

caddr_t *
ddl_type_tree (caddr_t * type)
{
  if (BOX_ELEMENTS (type) > 4)
    {
      caddr_t tree = ((caddr_t *) type)[4];
      return (caddr_t *) box_copy_tree (tree);
    }
  else
    return NULL;
}


dtp_t
ddl_type_to_dtp (caddr_t * type)
{
  return ((dtp_t) unbox (((caddr_t *) type)[0]));
}


void
ddl_type_to_sqt (sql_type_t * sqt, caddr_t * type)
{
  memset (sqt, 0, sizeof (sql_type_t));
  if (!ARRAYP (type))
    return;
  sqt->sqt_dtp = ddl_type_to_dtp (type);
  sqt->sqt_class = ddl_type_to_class (type, NULL);
  sqt->sqt_precision = ddl_type_to_prec (type);
  sqt->sqt_scale = ddl_type_to_scale (type);
  sqt->sqt_tree = (caddr_t *) ddl_type_tree (type);

  if (BOX_ELEMENTS (type) > 4 && DV_TYPE_OF (type[4]) == DV_ARRAY_OF_POINTER &&
      BOX_ELEMENTS (type[4]) % 2 == 0)
    {
      caddr_t *opts = (caddr_t *) (type[4]);
      dtp_parse_options (NULL, sqt, opts);
    }
}


oid_t qi_new_col_id (query_instance_t * qi);


void
ddl_table_changed (query_instance_t * qi, char *full_tb_name)
{
  log_dd_change (qi->qi_trx, full_tb_name); /* qi_read_table_schema commits.  So log the change first so it goes to the same log entry as the def */
  qi_read_table_schema (qi, full_tb_name);
}

client_connection_t *bootstrap_cli;
int ddl_std_procs_inited = 0;

void
ddl_key_opt (query_instance_t * qi, char * tb_name, key_id_t key_id)
{
  caddr_t err;
  static query_t * key_opt_qr;
  if (!ddl_std_procs_inited)
    return;
  if (! key_opt_qr)
    key_opt_qr = sql_compile_static ("DB.DBA.ddl_reorg_pk (?, ?)",
			      bootstrap_cli, &err, SQLC_DEFAULT);
  AS_DBA (qi, err = qr_rec_exec (key_opt_qr, qi->qi_client, NULL, qi, NULL, 2,
		     ":0", tb_name, QRP_STR,
		     ":1", (ptrlong) key_id, QRP_INT));
  if (err != (caddr_t) SQL_SUCCESS)
    {
      QI_POISON_TRX (qi);
      sqlr_resignal (err);
    }
}


void
ddl_key_options (query_instance_t * qi, char * tb_name, key_id_t key_id, caddr_t * opts)
{
  caddr_t err;
  static query_t * key_bitmap_qr;
  if (!ddl_std_procs_inited)
    return;
  if (! key_bitmap_qr)
    key_bitmap_qr = sql_compile_static ("DB.DBA.ddl_bitmap_inx (?, ?, ?)",
			      bootstrap_cli, &err, SQLC_DEFAULT);
  AS_DBA (qi, err = qr_rec_exec (key_bitmap_qr, qi->qi_client, NULL, qi, NULL, 3,
		     ":0", tb_name, QRP_STR,
				 ":1", (ptrlong) key_id, QRP_INT,
				 ":2", box_copy_tree (opts), QRP_RAW));
  if (err != (caddr_t) SQL_SUCCESS)
    {
      QI_POISON_TRX (qi);
      sqlr_resignal (err);
    }
}


void
ddl_create_table (query_instance_t * qi, const char *name, caddr_t * cols)
{
  client_connection_t *cli = qi->qi_client;
#if 0
  int inx, has_id = 0;
#else
  int inx;
#endif
  local_cursor_t *lc;
  caddr_t * pk_cols = NULL;
  ddl_ensure_init (cli);
  qi_new_col_id (qi);

  if (!CASEMODESTRCMP (TN_COLS, name) ||
      !CASEMODESTRCMP (TN_KEYS, name) ||
      !CASEMODESTRCMP (TN_KEY_PARTS, name) ||
      !CASEMODESTRCMP (TN_COLLATIONS, name) ||
      !CASEMODESTRCMP (TN_CHARSETS, name) ||
      !CASEMODESTRCMP (TN_SUB, name) ||
      !CASEMODESTRCMP (TN_FRAGS, name) ||
      !CASEMODESTRCMP (TN_UDT, name))
    { /* seed tables */
      sqlr_new_error ("42S01", "SQ132", "Table %s already exists", name);
    }


  qr_rec_exec (table_cols_qr, cli, &lc, qi, NULL, 1,
      ":0", name, QRP_STR);
  if (lc_next (lc))
    {
      lc_free (lc);
      sqlr_new_error ("42S01", "SQ016", "Table %s already exists", name);
      return;
    }

  if (!strncmp (name, "DB.DBA.", 7))
    { /* check for the presence of unqualified when it's DB.DBA */
      qr_rec_exec (table_cols_qr, cli, &lc, qi, NULL, 1,
	  ":0", name + 7, QRP_STR);
      if (lc_next (lc))
	{
	  lc_free (lc);
	  sqlr_new_error ("42S01", "SQ016", "Table %s already exists", name);
	  return;
	}
    }

  lc_free (lc);

  for (inx = 0; ((uint32) inx) < BOX_ELEMENTS (cols); inx += 2)
    {
      if (!cols[inx])
	{
	  ST *pk_constr = ((ST *) (cols)[inx + 1]);
	  if (pk_constr->type == INDEX_DEF)
	    {
	      pk_cols = (caddr_t *) pk_constr->_.index.cols;
	      break;
	    }
	}
    }

  for (inx = 0; ((uint32) inx) < BOX_ELEMENTS (cols); inx += 2)
    {
      if (cols[inx])
	{
	  dtp_t dtp = ddl_name_to_dtp (cols[inx + 1]);
	  long prec = ddl_name_to_prec (cols[inx + 1]);
	  sql_class_t *udt = ddl_name_to_type (cols[inx + 1]);
	  oid_t id = qi_new_col_id (qi);
	  int ix, pk_part, is_allocated = 0;
          dk_set_t col_options = NULL;
	  char *col_opts = ddl_col_options (qi, cols[inx + 1], dtp, &is_allocated, &col_options);
	  caddr_t err;

	  if (udt)
	    {
	      if (udt->scl_mem_only)
		{
		  if (is_allocated)
		    dk_free_box (col_opts);
		  SQL_DDL_ERROR (qi, ("42S22", "UD002",
			"Class %.200s is TEMPORARY. It can't be used "
			"as a column type", udt->scl_name));
		}
	      dk_set_push (&col_options, box_dv_short_string ("sql_class"));
	      dk_set_push (&col_options, box_copy (udt->scl_name));
	    }
	  else if (dtp == DV_OBJECT)
	    {
	      caddr_t *type_info = ARRAYP((caddr_t **)(cols[inx+1])) ? ((caddr_t **)(cols[inx+1]))[0] : NULL;
	      caddr_t type_name = (caddr_t) (BOX_ELEMENTS(type_info) > 3 ? type_info[3] : "<unknown>");
	      if (is_allocated)
		dk_free_box (col_opts);
	      SQL_DDL_ERROR (qi, ("42S22", "SQ003", "Invalid type '%s' for column '%s'",
		    	type_name, cols[inx]));
	    }

	  if (!IS_BLOB_DTP (dtp) && prec > ROW_MAX_DATA)
	    {
	      if (is_allocated)
		dk_free_box (col_opts);
	      SQL_DDL_ERROR (qi, ("42S22", "SQ175",
		  "The size (%ld) given to the column '%.100s' exceeds the maximum allowed for any datatype (%ld).",
		  (long)prec, cols[inx], (long)ROW_MAX_DATA));
	    }


	  for (ix = 0, pk_part = 0; pk_cols && ((uint32) ix) < BOX_ELEMENTS (pk_cols); ix ++)
	    {
	      if (!CASEMODESTRCMP (pk_cols[ix], cols[inx]))
		{
		  pk_part ++;
		  if ((DV_BLOB == dtp) || (DV_BLOB_WIDE == dtp) || (DV_BLOB_BIN == dtp) || (DV_BLOB_XPER == dtp))
		    {
		      if (is_allocated)
			dk_free_box (col_opts);
		      SQL_DDL_ERROR (qi, ("42S22", "SQ170", "Column '%.200s' of LONG SQL type can't be a part of primary key of table '%.200s'.", cols[inx], name));
		    }
		  break;
		}
	    }
#if 0
	  if (strstr (col_opts, " U "))
	    {
	      if (!has_id)
		has_id = 1;
	      else
		sqlr_new_error ("42000", "SQ134", "Table already has an IDENTIFIED BY option");
	    }
#endif
	  ddl_push_type_options (cols[inx + 1], &col_options);
	  err = qr_rec_exec (add_col_stmt, cli, NULL, qi, NULL, 10,
	      ":0", name, QRP_STR,
	      ":1", cols[inx], QRP_STR,
	      ":2", (ptrlong) id, QRP_INT,
	      ":3", (ptrlong) dtp, QRP_INT,
	      ":4", (ptrlong) prec, QRP_INT,
	      ":5", col_opts, QRP_STR,
	      ":6", ddl_col_scale (cols[inx + 1]), QRP_RAW,
	      ":7", ddl_col_default (cols[inx + 1]), QRP_RAW,
	      ":8", pk_part ? box_num (1) : ddl_col_nullable (cols[inx + 1]), QRP_RAW,
	      ":9", list_to_array (dk_set_nreverse (col_options)), QRP_RAW
	      );
	  if (is_allocated)
	    dk_free_box (col_opts);
	  if (err)
	    {
	      QI_POISON_TRX (qi);
	      sqlr_resignal (err);
	    }
	}
    }

  if (DO_LOG_INT(LOG_DDL))
    {
      LOG_GET
      log_info ("DDLC_0 %s %s %s Create table %.*s", user, from, peer, LOG_PRINT_STR_L, name);
    }
}

long first_id = DD_FIRST_FREE_OID;

key_id_t
qi_new_key_id (query_instance_t * qi)
{
  long id, prev_id = first_id;
  local_cursor_t *lc;
  qr_rec_exec (key_id_stmt, qi->qi_client, &lc, qi, NULL, 1,
      ":FROM", (ptrlong) first_id, QRP_INT);
  while (lc_next (lc))
    {
      id = (long) unbox (lc_get_col (lc, "K.KEY_ID"));
      if (id - prev_id >= 2)
	{
	  break;
	}
      prev_id = id;

    }
  lc_free (lc);
  if (prev_id >= KI_TEMP - 1)
    {
      SQL_DDL_ERROR (qi, ("42000", "SQ173", "Maximum number of keys (%ld) already created.", prev_id));
    }
  return ((key_id_t) prev_id + 1);
}


key_ver_t
qi_new_key_version (query_instance_t * qi, key_id_t super)
{
  long id, prev_id = 0;
  local_cursor_t *lc;
  qr_rec_exec (key_ver_stmt, qi->qi_client, &lc, qi, NULL, 1,
      ":0", (ptrlong) super, QRP_INT);
  while (lc_next (lc))
    {
      id = (long) unbox (lc_nth_col (lc, 0));
      if (id - prev_id >= 2)
	{
	  break;
	}
      prev_id = id;

    }
  lc_free (lc);
  if (prev_id >= KI_TEMP - 1)
    {
      SQL_DDL_ERROR (qi, ("42000", "SQ173", "Maximum number of keys (%ld) already created.", prev_id));
    }
  return ((key_id_t) prev_id + 1);
}


oid_t
qi_new_col_id (query_instance_t * qi)
{
  client_connection_t *cli = qi->qi_client;
  long id, prev_id = first_id;
  local_cursor_t *lc;
  stmt_options_t * opts = (stmt_options_t *) dk_alloc_box_zero (sizeof (stmt_options_t), DV_ARRAY_OF_LONG);
  opts->so_concurrency = SQL_CONCUR_LOCK;
  opts->so_isolation = ISO_SERIALIZABLE;
  opts->so_prefetch = 1;

  qr_rec_exec (col_id_stmt, cli, &lc, qi, opts, 1, ":FROM", (ptrlong) first_id, QRP_INT);
  dk_free_box ((caddr_t) opts);
  while (lc_next (lc))
    {
      id = (long) unbox (lc_get_col (lc, "C.COL_ID"));
      if (id - prev_id >= 2)
	{
	  break;
	}
      prev_id = id;

    }
  lc_free (lc);
  return (prev_id + 1);
}


static void
ddl_col_set_identity_start (char *table, char *check, caddr_t *col_options, char *name,
    client_connection_t *cli, query_instance_t *qi)
{
  char *i_inx, *u_inx;
  i_inx = check ? strchr (check, 'I') : NULL;
  u_inx = check ? strstr (check, " U ") : NULL;
  if (i_inx && (!u_inx || i_inx < u_inx))
    {
      char temp[6*MAX_NAME_LEN + 6];
      char q[MAX_NAME_LEN], o[MAX_NAME_LEN], n[MAX_NAME_LEN];
      int start = 1;
      caddr_t id_start;

      if (NULL != (id_start = col_options ? get_keyword_int (col_options, "identity_start", NULL) : NULL))
	{
	  if (DV_TYPE_OF (id_start) == DV_LONG_INT)
	    start = (int) unbox (id_start);
	  dk_free_tree (id_start);
	}

      sch_split_name ("DB", table, q, o, n);
      snprintf (temp, sizeof (temp), "%s.%s.%s.%s", q, o, table, name);
      qr_rec_exec (pk_sequence_set_stmt, cli, NULL, qi, NULL, 2,
	  ":0", temp, QRP_STR,
	  ":1", (ptrlong) start, QRP_INT);
    }
}


static void
ddl_check_duplicate_cols (query_instance_t * qi,
    caddr_t * parts)
{
  int inx, dup_inx;
  for (inx = 0; inx < BOX_ELEMENTS (parts); inx++)
    {
      for (dup_inx = inx + 1; dup_inx < BOX_ELEMENTS (parts); dup_inx++)
	{
	  if (!CASEMODESTRCMP (parts[inx], parts[dup_inx]))
	    {
	      if (qi)
		SQL_DDL_ERROR (qi, ("42000", "SQ203",
		    "Column %.*s present more than once in a key definition",
		     4 * MAX_NAME_LEN, parts[inx]))
	      else
		sqlr_new_error ("42000", "SQ203",
		    "Column %.*s present more than once in a key definition",
		    4 * MAX_NAME_LEN, parts[inx]);
	    }
	}
    }
}


void
ddl_first_key_parts (query_instance_t * qi,
    char *table, char *key, caddr_t * parts,
    int n_significant,
    int is_cluster, int is_prim, key_id_t * id_ret,
    int is_oid, int is_unq)
{
  caddr_t rc;
  client_connection_t *cli = qi->qi_client;
  int inx;
  local_cursor_t *lc;
  int n_parts = BOX_ELEMENTS (parts);
  key_id_t id = qi_new_key_id (qi);
  *id_ret = id;

  if (n_parts >= TB_MAX_COLS)
    SQL_DDL_ERROR (qi, ("42000", "SQ005", "Column count too large"));

  ddl_check_duplicate_cols (qi, parts);

  qr_rec_exec (add_key_stmt, cli, NULL, qi, NULL, 11,
	       ":0", table, QRP_STR,
	       ":1", key, QRP_STR,
	       ":2", (ptrlong) id, QRP_INT,
	       ":3", (ptrlong) n_significant, QRP_INT,
	       ":4", (ptrlong) (is_cluster ? id : 0), QRP_INT,
	       ":5", (ptrlong) is_prim, QRP_INT,
	       ":6", (ptrlong) is_oid, QRP_INT,
	       ":7", (ptrlong) is_unq, QRP_INT,
	       ":8", (ptrlong) id, QRP_INT,
	       ":9", (ptrlong) n_significant, QRP_INT,
	       ":10", (ptrlong) 1, QRP_INT);
  for (inx = 0; inx < n_parts; inx++)
    {
      oid_t col_id;
      char *check;
      caddr_t *col_options;
      qr_rec_exec (get_col_stmt, cli, &lc, qi, NULL, 2,
	  ":0", table, QRP_STR,
	  ":1", parts[inx], QRP_STR);
      if (!lc_next (lc))
	{
	  lc_free (lc);
	  SQL_DDL_ERROR (qi, ("42S22", "SQ129", "No column %s in %s.", parts[inx], table));
	}
      col_id = (oid_t) unbox (lc_get_col (lc, "C.COL_ID"));
      rc = qr_rec_exec (add_key_part_stmt, cli, NULL, qi, NULL, 3,
			":0", (ptrlong) id, QRP_INT,
			":1", (ptrlong) inx, QRP_INT,
			":2", (ptrlong) col_id, QRP_INT);
      if (rc != SQL_SUCCESS)
	{
	  lc_free (lc);
	  sqlr_resignal (rc);
	}

      check = lc_get_col (lc, "C.COL_CHECK");
      col_options = (caddr_t *) lc_get_col (lc, "C.COL_OPTIONS");
      ddl_col_set_identity_start (table, check, col_options, parts[inx], cli, qi);
      lc_free (lc);
    }
}


key_id_t
ddl_key_name_to_id (query_instance_t * qi, const char *name, char *qual)
{
  client_connection_t *cli = qi->qi_client;
  key_id_t id = 0;
  local_cursor_t *lc;
  static query_t *qr;
  if (!qual)
    qual = qi->qi_client->cli_qualifier;
  if (!qr)
    {
      caddr_t err;
      qr = sql_compile_static ((case_mode == CM_MSSQL) ? "select KEY_ID from DB.DBA.SYS_KEYS where upper(KEY_NAME) = upper(?) and upper(?) = upper(name_part (KEY_TABLE, 0))" : "select KEY_ID from DB.DBA.SYS_KEYS where KEY_NAME = ? and ? = name_part (KEY_TABLE, 0)", cli, &err, SQLC_DEFAULT);
    }
  qr_rec_exec (qr, cli, &lc, qi, NULL, 2,
      ":0", name, QRP_STR,
      ":1", qual, QRP_STR);
  if (lc_next (lc))
    {
      id = (key_id_t) unbox (lc_nth_col (lc, 0));
    }
  lc_free (lc);
  return id;
}


char * col_check_text =
"select (select count (distinct \"COLUMN\") from DB.DBA.SYS_KEY_PARTS, DB.DBA.SYS_COLS where COL_ID = KP_COL and KP_KEY_ID = ?)"
"  - (select count ( \"COLUMN\") from DB.DBA.SYS_KEY_PARTS, DB.DBA.SYS_COLS where COL_ID = KP_COL and KP_KEY_ID = ?)";


void
ddl_check_cols (query_instance_t * qi, long id)
{
}


void
ddl_commit_trx (query_instance_t *qi)
{
  caddr_t repl;
  int rc;
  /* for 2pc, this is done really out of whack.  Not proper sequence.  So remove the mark that this w id is gone cause there'll be ops with the id from the coordinator */
  IN_TXN;
  repl = box_copy_tree ((box_t) qi->qi_trx->lt_replicate); /* if logging is off, keep it off */
  rc = lt_commit (qi->qi_trx, TRX_CONT);
  qi->qi_trx->lt_replicate = (caddr_t *)repl;
  LEAVE_TXN;
  if (LTE_OK != rc)
    sqlr_new_error ("4000X", "SR108",
		    "Transaction could not commit after DDL statement. Last DDL statement rolled back: %s",
		    qi->qi_trx->lt_error_detail ? qi->qi_trx->lt_error_detail : "");
}


void
ddl_create_primary_key (query_instance_t * qi,
    char *name, char *table, caddr_t * parts,
			int cluster_on_id, int is_object_id, caddr_t * opts)
{
  client_connection_t *cli = qi->qi_client;
  int inx = (int) BOX_ELEMENTS (parts);
  key_id_t id;
  local_cursor_t *lc_cols;
  oid_t col_id;

  ddl_first_key_parts (qi, table, name, parts, inx, cluster_on_id,
      1, &id, is_object_id, 1);

  /* Now tag every other column in there as dependent part */
  qr_rec_exec (cols_stmt, cli, &lc_cols, qi, NULL, 1,
      ":TB", table, QRP_STR);
  while (lc_next (lc_cols))
    {
      char *col = lc_get_col (lc_cols, "C.COLUMN");
      int ci;
      char *check;
      caddr_t *col_options;

      for (ci = 0; ((uint32) ci) < BOX_ELEMENTS (parts); ci++)
	{
	  if (0 == CASEMODESTRCMP (parts[ci], col))
	    goto next_in;
	}
      if (inx >= TB_MAX_COLS)
	SQL_DDL_ERROR (qi, ("37000", "SQ007", "Column count too large"));
      col_id = (oid_t) unbox (lc_get_col (lc_cols, "C.COL_ID"));
      qr_rec_exec (add_key_part_stmt, cli, NULL, qi, NULL, 3,
		   ":0", (ptrlong) id, QRP_INT,
		   ":1", (ptrlong) inx, QRP_INT,
		   ":2", (ptrlong) col_id, QRP_INT);

      check = lc_get_col (lc_cols, "C.COL_CHECK");
      col_options = (caddr_t *) lc_get_col (lc_cols, "C.COL_OPTIONS");
      ddl_col_set_identity_start (table, check, col_options, col, cli, qi);
      inx++;
    next_in:;
    }
  lc_free (lc_cols);
  ddl_check_cols (qi, id);

  if (inx_opt_flag (opts, "column"))
    {
      caddr_t err = NULL;
      static query_t * col_qr = NULL;
      if (!col_qr)
	col_qr = sql_compile_static ("update SYS_KEYS set KEY_OPTIONS = vector ('column') where KEY_TABLE = ? and KEY_IS_MAIN = 1",
				     bootstrap_cli, &err, SQLC_DEFAULT);
      err = qr_rec_exec (col_qr, qi->qi_client, NULL, qi, NULL, 1,
			 ":0", table, QRP_STR);
      if (err != SQL_SUCCESS)
	{
	  QI_POISON_TRX (qi);
	  sqlr_resignal (err);
	}
    }
  ddl_table_changed (qi, table);

  ddl_commit_trx (qi);
}


dk_set_t
tb_list_subtables (dbe_schema_t * sc, dbe_table_t * super, int directp)
{
  dk_set_t res = NULL;
  id_casemode_hash_iterator_t hit;
  dbe_table_t **tbptr;
  id_casemode_hash_iterator (&hit, sc->sc_name_to_object[sc_to_table]);
  while (id_casemode_hit_next (&hit, (caddr_t *) & tbptr))
    {
      dbe_table_t *the_table = *tbptr;
      if (the_table == super || !the_table->tb_primary_key)
	continue;
      if (directp)
	{
	  if (dk_set_member (the_table->tb_primary_key->key_supers,
		  (void *) super->tb_primary_key))
	    dk_set_push (&res, (void *) the_table);
	}
      else
	{
	  if (sch_is_subkey (sc, the_table->tb_primary_key->key_id,
		  super->tb_primary_key->key_id))
	    dk_set_push (&res, (void *) the_table);
	}
    }
  return res;
}


void ddl_create_subtable_keys (query_instance_t * qi, dbe_table_t * tb,
			       char *key_name, key_id_t super_key_id, key_id_t top_super_id);


#define K_MAX_PARTS 100



void
ddl_insert_sec_key_parts (query_instance_t * qi,
    key_id_t prim_id, char *table, char *key, caddr_t * parts,
    int is_cluster, key_id_t * id_ret,
    int is_oid, int is_unq, int decl_parts)
{
  client_connection_t *cli = qi->qi_client;
  int inx;
  local_cursor_t *lc;
  int n_parts = BOX_ELEMENTS (parts);
  key_id_t id = qi_new_key_id (qi);
  *id_ret = id;
  qr_rec_exec (add_key_stmt, cli, NULL, qi, NULL, 11,
	       ":0", table, QRP_STR,
      ":1", key, QRP_STR,
	       ":2", (ptrlong) id, QRP_INT,
	       ":3", (ptrlong) (is_unq ? decl_parts : n_parts), QRP_INT,
	       ":4", (ptrlong) (is_cluster ? id : 0), QRP_INT,
	       ":5", (ptrlong) 0, QRP_INT,
	       ":6", (ptrlong) is_oid, QRP_INT,
	       ":7", (ptrlong) is_unq, QRP_INT,
	       ":8", (ptrlong) id, QRP_INT,
      ":9", (ptrlong) decl_parts, QRP_INT,
	       ":10", (ptrlong) 1, QRP_INT);
  for (inx = 0; inx < n_parts; inx++)
    {
      oid_t col_id;
      caddr_t col_dtp;
      qr_rec_exec (get_col_from_key_stmt, cli, &lc, qi, NULL, 2,
	  ":1", (ptrlong) prim_id, QRP_INT,
	  ":0", parts[inx], QRP_STR);
      if (!lc_next (lc))
	SQL_DDL_ERROR (qi, ("42S22", "SQ008", "No column %s in %s.", parts[inx], table));
      col_dtp = lc_nth_col (lc, 1);
      if (DV_TYPE_OF (col_dtp) == DV_LONG_INT)
	{
	  dtp_t dtp = (dtp_t) unbox (col_dtp);
	  if (IS_BLOB_DTP (dtp))
	    SQL_DDL_ERROR (qi, ("07006", "SQ009",
		  "Column %s is a BLOB column and blob columns are not supported as index parts", parts[inx]));
	}
      if (inx >= TB_MAX_COLS)
	SQL_DDL_ERROR (qi, ("42S22", "SQ010", "Column count too large"));
      col_id = (oid_t) unbox (lc_get_col (lc, "KP.KP_COL"));
      qr_rec_exec (add_key_part_stmt, cli, NULL, qi, NULL, 3,
		   ":0", (ptrlong) id, QRP_INT,
		   ":1", (ptrlong) inx, QRP_INT,
		   ":2", (ptrlong) col_id, QRP_INT);
      lc_free (lc);
    }
}


caddr_t
ddl_ensure_constraint_name_unique (const char *name, client_connection_t *cli, query_instance_t *qi)
{
  if (name && ensure_constraint_unq_stmt) /* the CHECK constraints have no names if unnamed */
    return qr_rec_exec (ensure_constraint_unq_stmt, cli, NULL, qi, NULL, 1,
	":0", name, QRP_STR);
  else
    return NULL;
}


void inx_opt_cluster (query_instance_t * qi, caddr_t tb_name, caddr_t inx, caddr_t * opts);

#define KO_NO_PK(opt) \
  inx_opt_flag (opt, "no_pk")



void
ddl_create_key (query_instance_t * qi,
    char *name, char *table, caddr_t * parts,
		int cluster_on_id, int is_object_id, int is_unique, int is_bitmap, caddr_t * opts)
{
  caddr_t tn, in;
  client_connection_t *cli = qi->qi_client;
  caddr_t parts_tmp[K_MAX_PARTS];

  caddr_t parts_box;
  key_id_t key_id;
  int n_parts = BOX_ELEMENTS (parts);
  int decl_parts = n_parts;
  int parts_fill = n_parts, x;
  local_cursor_t *lc_keys;
  local_cursor_t *lc_key_parts;
  int n_primary, prim_id;
  char *szTheTableName;
  dk_set_t to_free = NULL;

  memcpy (parts_tmp, parts, box_length ((caddr_t) parts));

  qr_rec_exec (find_primary_stmt, cli, &lc_keys, qi, NULL, 1,
      ":0", table, QRP_STR);
  if (!lc_next (lc_keys))
    {
      lc_free (lc_keys);
      sqlr_new_error ("42S12", "SQ017",
	  "No primary key for %s. Specify qualifier and owner if you are not owner of the table.", table);
    }
  n_primary = (int) unbox (lc_get_col (lc_keys, "K.KEY_N_SIGNIFICANT"));
  prim_id = (int) unbox (lc_get_col (lc_keys, "K.KEY_ID"));
  szTheTableName  = box_string((case_mode == CM_MSSQL) ? lc_get_col (lc_keys, "K.KEY_TABLE") : table);
  lc_free (lc_keys);

  ddl_check_duplicate_cols (NULL, parts);

  qr_rec_exec (get_key_parts_stmt, cli, &lc_key_parts, qi, NULL, 2,
      ":ID", (ptrlong) prim_id, QRP_INT,
      ":LIMIT", (ptrlong) n_primary, QRP_INT);
  while (lc_next (lc_key_parts))
    {
      /* oid_t col_id = unbox (lc_get_col (lc_key_parts, "K.KP_COL")); */
      /* int nth = (int) unbox (lc_get_col (lc_key_parts, "K.KP_NTH")); */
      char *c_name = box_string (lc_get_col (lc_key_parts, "C.COLUMN"));
      if (KO_NO_PK (opts))
	goto already_in;
      for (x = 0; x < n_parts; x++)
	if (0 == CASEMODESTRCMP (c_name, parts[x]))
	  {
	    dk_free_box (c_name);
	    goto already_in;
	  }

      dk_set_push (&to_free, c_name);
      parts_tmp[parts_fill++] = c_name;
    already_in:;
    }
  lc_free (lc_key_parts);

  parts_box = dk_alloc_box (parts_fill * sizeof (caddr_t),
      DV_ARRAY_OF_POINTER);
  memcpy (parts_box, parts_tmp, parts_fill * sizeof (caddr_t));


  ddl_insert_sec_key_parts (qi, (key_id_t) prim_id, szTheTableName, name, (caddr_t *) parts_box,
      cluster_on_id, &key_id, is_object_id, is_unique, decl_parts);

  dk_free_tree (list_to_array (to_free));
  dk_free_box (parts_box);

  ddl_key_options (qi, szTheTableName, key_id, opts);
  if (is_unique)
    ddl_key_opt (qi, szTheTableName, key_id);
  ddl_table_changed (qi, szTheTableName);
  tn = box_dv_short_string (table);
  in = box_dv_short_string (name);
  inx_opt_cluster (qi, tn, in, opts);
  dk_free_box (tn);
  dk_free_box (in);

  {
    dbe_table_t *tb = qi_name_to_table (qi, szTheTableName);
    if (tb)
      ddl_create_subtable_keys (qi, tb, name, key_id, key_id);
  }
  dk_free_box(szTheTableName);
}


const char *object_dd_text =
"(seq "
"  (create_table SYS_REPL_ACCOUNTS (SERVER varchar NTH integer"
"     ACCOUNT varchar LEVEL integer IS_MANDATORY integer IS_UPDATEABLE integer"
"     SYNC_USER varchar"
"     P_MONTH integer P_DAY integer P_WDAY integer P_TIME time))"
"    (create_unique_index SYS_REPL_ACCOUNTS_SA on SYS_REPL_ACCOUNTS (SERVER ACCOUNT) contiguous)"
"    (create_index SYS_REPL_ACCOUNTS on SYS_REPL_ACCOUNTS (NTH) contiguous)"

"  (create_table SYS_SERVERS (SERVER varchar  DB_ADDRESS varchar REPL_ADDRESS varchar))"
"   (create_unique_index SYS_SERVERS on SYS_SERVERS (SERVER) contiguous)"

"  (end))";

const char *table_keys_text = "select KEY_ID, KEY_IS_MAIN, KEY_SUPER_ID from DB.DBA.SYS_KEYS where KEY_TABLE = ? and KEY_MIGRATE_TO is null";

const char *inherit_key_text =
  "ddl_inherit_key (?, ?, ?, ?, ?)";

const char *read_key_subkey_text =
"(seq (from SYS_KEY_SUBKEY (SUPER SUB) by SYS_KEY_SUBKEY prefix S )"
"     (select (S.SUPER S.SUB)))";

query_t *subkey_qr;
query_t *inherit_key_qr = NULL;
query_t *table_keys_qr;
query_t *read_key_subkey_qr;

dk_mutex_t * recomp_mtx;


void
ddl_init_objects ()
{
  if (!sch_name_to_table (wi_inst.wi_schema, "SYS_REPL_ACCOUNTS"))
    {
      caddr_t err = NULL;
      query_t *obj_create = eql_compile_2 (
          object_dd_text, bootstrap_cli, &err, SQLC_DEFAULT);
      if (err)
        {
          log_error ("Error compiling a server init statement: %s: %s -- %s",
	      ((caddr_t *) err)[QC_ERRNO], ((caddr_t *) err)[QC_ERROR_STRING],
              object_dd_text);
          dk_free_tree (err);
          return;
        }
      first_id = DD_FIRST_PRIVATE_OID;
      err = qr_quick_exec (obj_create, bootstrap_cli, "", NULL, 0);
      if ((caddr_t) SQL_SUCCESS != err)
        {
          log_error ("Error executing a server init statement: %s: %s -- %s",
	      ((caddr_t *) err)[QC_ERRNO], ((caddr_t *) err)[QC_ERROR_STRING],
              object_dd_text);
          dk_free_tree (err);
          qr_free (obj_create);
          return;
        }
      qr_free (obj_create);
      first_id = DD_FIRST_FREE_OID;
    }
}


dbe_schema_t *super_sub_schema;


void
key_fill_supers (dbe_key_t * super, dbe_key_t * sub)
{
  if (super != sub)
    sch_set_subkey (super_sub_schema, sub->key_id, super->key_id);
  DO_SET (dbe_key_t *, s2, &super->key_supers)
  {
    key_fill_supers (s2, sub);
  }
  END_DO_SET ();
}

/* SYS_USER_GROUP is replaced by view */
static const char *
sys_role_grants_text =
/*"create table SYS_USER_GROUP ("
"    UG_UID	INTEGER NOT NULL, "
"    UG_GID	INTEGER NOT NULL, "
"    PRIMARY KEY (UG_UID, UG_GID))";*/
" create table SYS_ROLE_GRANTS ( \n"
"       GI_SUPER 	integer, \n"
"     	GI_SUB 		integer, \n"
" 	GI_DIRECT	integer default 1, \n"
" 	GI_GRANT	integer, \n"
" 	GI_ADMIN	integer default 0, \n"
" 	primary key 	(GI_SUPER, GI_SUB, GI_DIRECT)) \n";




static const char *
sys_col_stat_text =
"create table SYS_COL_STAT ( "
"    CS_TABLE varchar, "
"    CS_COL varchar, "
"    CS_N_DISTINCT bigint, "
"    CS_MIN any, "
"    CS_MAX any, "
"    CS_AVG_LEN bigint, " /* */
"    CS_N_VALUES bigint, " /* count of non-null  */
"    CS_N_ROWS bigint, " /* rows in table, denormalized */
"    primary key (CS_TABLE, CS_COL))";

static const char *
sys_col_hist_text =
"create table SYS_COL_HIST (CH_TABLE varchar, "
"    CH_COL varchar, "
"    CH_NTH_SAMPLE integer, "
"    CH_VALUE any, "
"    primary key (CH_TABLE, CH_COL, CH_NTH_SAMPLE))";

static const char *
sys_repl_subscribers_text =
"create table SYS_REPL_SUBSCRIBERS ("
"  RS_SERVER varchar,"
"  RS_ACCOUNT varchar,"
"  RS_SUBSCRIBER varchar,"
"  RS_LEVEL integer,"
"  RS_VALID integer,"
"primary key (RS_SERVER, RS_ACCOUNT, RS_SUBSCRIBER))";

static const char *
sys_rls_policy_text =
"create table SYS_RLS_POLICY ("
"  RLSP_TABLE varchar,"
"  RLSP_OP varchar,"
"  RLSP_FUNC varchar,"
"  PRIMARY KEY (RLSP_TABLE, RLSP_OP))";

static const char *
col_stat_text =
"select CS_TABLE, CS_COL, CS_N_DISTINCT, CS_MIN, CS_MAX, "
"  CS_N_VALUES, CS_N_ROWS, CS_AVG_LEN from DB.DBA.SYS_COL_STAT order by CS_TABLE, CS_COL";

static const char *
col_hist_text =
"select CH_NTH_SAMPLE, CH_VALUE from DB.DBA.SYS_COL_HIST where "
" CH_TABLE = ? and CH_COL = ? order by CH_TABLE, CH_COL, CH_NTH_SAMPLE";

static const char *
col_stat_col_text =
"select CS_N_DISTINCT, CS_MIN, CS_MAX, "
"  CS_N_VALUES, CS_N_ROWS, CS_AVG_LEN from DB.DBA.SYS_COL_STAT WHERE CS_TABLE = ? and CS_COL = ?";

static query_t *col_stat_qr = NULL, *col_stat_col_qr, *col_hist_qr = NULL;

static void
dbe_col_load_stat_hist (client_connection_t *cli, query_instance_t *caller,
    dbe_table_t *tb, dbe_column_t *col)
{
  dk_set_t hist_set = NULL;
  local_cursor_t *lc_hist = NULL;
  caddr_t err = NULL;

  err = qr_rec_exec (col_hist_qr, cli, &lc_hist, caller, NULL, 2,
      ":0", tb->tb_name, QRP_STR,
      ":1", col->col_name, QRP_STR);
  while (lc_next (lc_hist))
    {
      caddr_t ch_nth_sample = lc_nth_col (lc_hist, 0);
      caddr_t ch_value = lc_nth_col (lc_hist, 1);
      dk_set_push (&hist_set, list (2, box_copy_tree (ch_nth_sample), box_copy_tree (ch_value)));
    }
  lc_free (lc_hist);
  dk_free_tree ((box_t) col->col_hist);
  if (dk_set_length (hist_set))
    col->col_hist = (caddr_t *) list_to_array (dk_set_nreverse (hist_set));
  else
    col->col_hist = NULL;
}


void
dbe_col_load_stats (client_connection_t *cli, query_instance_t *caller,
    dbe_table_t *tb, dbe_column_t *col)
{
  local_cursor_t *lc_stat = NULL;
  caddr_t err = NULL;

  if (!col_stat_col_qr)
    return;
  err = qr_rec_exec (col_stat_col_qr, cli, &lc_stat, caller, NULL, 2,
      ":0", tb->tb_name, QRP_STR,
      ":1", col->col_name, QRP_STR);
  if (lc_next (lc_stat))
    {
      caddr_t n_distinct = lc_nth_col (lc_stat, 0);
      caddr_t col_min = lc_nth_col (lc_stat, 1);
      caddr_t col_max = lc_nth_col (lc_stat, 2);
      caddr_t col_n_values = lc_nth_col (lc_stat, 3);
      caddr_t col_n_rows = lc_nth_col (lc_stat, 4);
      caddr_t col_avg_len = lc_nth_col (lc_stat, 5);

      if (DV_TYPE_OF (col_n_values) == DV_LONG_INT)
      col->col_count = (long) unbox (col_n_values);
      if ( DV_TYPE_OF (n_distinct) == DV_LONG_INT)
	col->col_n_distinct = (long) unbox (n_distinct);
      dk_free_tree (col->col_min);
      col->col_min = box_copy_tree (col_min);
      dk_free_tree (col->col_max);
      col->col_max = box_copy_tree (col_max);
      if (DV_TYPE_OF (col_n_rows) == DV_LONG_INT)
	tb->tb_count = (long) unbox (col_n_rows);
      if (DV_TYPE_OF (col_avg_len) == DV_LONG_INT)
      col->col_avg_len = (long) unbox (col_avg_len);
      dbe_col_load_stat_hist (cli, caller, tb, col);
    }
  lc_free (lc_stat);
}


static void
isp_load_stats_data (client_connection_t *cli)
{
  local_cursor_t *lc_stat = NULL;
  dbe_table_t *tb = NULL;
  caddr_t err = NULL;

  if (!col_stat_qr)
    {
      col_stat_qr = sql_compile_static (col_stat_text, cli, &err, SQLC_DEFAULT);
      col_hist_qr = sql_compile_static (col_hist_text, cli, &err, SQLC_DEFAULT);
      col_stat_col_qr = sql_compile_static (col_stat_col_text, cli, &err, SQLC_DEFAULT);
    }

  err = qr_quick_exec (col_stat_qr, cli, NULL, &lc_stat, 0);
  while (lc_next (lc_stat))
    {
      dbe_column_t *col = NULL;
      caddr_t tb_name = lc_nth_col (lc_stat, 0);
      caddr_t col_name = lc_nth_col (lc_stat, 1);
      caddr_t n_distinct = lc_nth_col (lc_stat, 2);
      caddr_t col_min = lc_nth_col (lc_stat, 3);
      caddr_t col_max = lc_nth_col (lc_stat, 4);
      caddr_t col_n_values = lc_nth_col (lc_stat, 5);
      caddr_t col_n_rows = lc_nth_col (lc_stat, 6);
      caddr_t col_avg_len = lc_nth_col (lc_stat, 7);

      if (!tb || strcmp (tb->tb_name, tb_name))
	tb = sch_name_to_table (wi_inst.wi_schema, tb_name);

      if (tb)
	col = tb_name_to_column (tb, col_name);

      if (col)
	{
	  col->col_count = DV_TYPE_OF (col_n_values) == DV_LONG_INT ? (long) unbox (col_n_values) : 0;
	  col->col_n_distinct = DV_TYPE_OF (n_distinct) == DV_LONG_INT ? (long) unbox (n_distinct) : 0;
	  dk_free_tree (col->col_min);
	  dk_free_tree (col->col_max);
	  col->col_min = box_copy_tree (col_min);
	  col->col_max = box_copy_tree (col_max);
	  if (DV_TYPE_OF (col_n_rows) == DV_LONG_INT)
	    tb->tb_count = (long) unbox (col_n_rows);
	  col->col_avg_len = DV_TYPE_OF (col_avg_len) == DV_LONG_INT ? (long) unbox (col_avg_len) : 0;
	  dbe_col_load_stat_hist (cli, CALLER_LOCAL, tb, col);
	}
    }
  lc_free (lc_stat);
}


int
recomp_mtx_entry_check (dk_mutex_t * mtx, du_thread_t * self, void * cd)
{
#ifdef MTX_DEBUG
  if (wi_inst.wi_txn_mtx->mtx_owner == self)
    GPF_T1 ("may not be inside TXN mutex when entering other mtx");
#endif
  return 1;
}


char  * sys_cluster_text =
"create table SYS_CLUSTER ( "
  "  CL_NAME varchar, CL_HOSTS long varchar, CL_MAP long varchar, primary key (CL_NAME))";

char * sys_part_text =
"create table SYS_PARTITION ("
"  PART_TABLE varchar, PART_KEY varchar, PART_VERSION int, PART_CLUSTER varchar, PART_DATA any, primary key (PART_TABLE, PART_KEY, PART_VERSION))";

char * sys_dpipe_text =
"create table SYS_DPIPE (\n"
"  DP_NAME varchar primary key,\n"
"  DP_PART_TABLE varchar,\n"
"  DP_PART_KEY varchar,\n"
"  DP_IS_UPD int,\n"
"  DP_SRV_PROC varchar,\n"
"  DP_CALL_BIF varchar,\n"
"  DP_CALL_PROC varchar,\n"
  "  DP_EXTRA any)\n";


char * cluster_stmt_text_pre_init =
"create procedure cluster_stmt (in tree any, in store int)\n"
"{\n"
"  if (tree[0] = 524)\n"
"    {\n"
"      cluster_def (tree);\n"
"    }\n"
"  else if (tree[0] = 525)\n"
"    {\n"
"      partition_def (tree);\n"
"    }\n"
  "}\n";


char * cluster_stmt_text =
"create procedure cluster_stmt (in tree any, in store int)\n"
"{\n"
"  if (tree[0] = 524)\n"
"    {\n"
"      cluster_def (tree[1], tree, null);\n"
"      if (store)\n"
"	{ delete from SYS_CLUSTER where CL_NAME = tree[1]; insert into SYS_CLUSTER (CL_NAME, CL_HOSTS, CL_MAP) values (tree[1], serialize (tree), clm_map (cast (tree[1] as varchar))); }\n"
"    log_text ('cl_read_cluster (?)', cast (tree[1] as varchar));\n"
"    }\n"
"  else if (tree[0] = 525)\n"
"    {\n"
"    tree[1] := complete_table_name (tree[1], 1);\n"
"  if (exists (select 1 from SYS_KEYS where KEY_TABLE = tree[1] and KEY_NAME = tree[2] and KEY_SUPER_ID <> KEY_ID))\n"
"    signal ('42000', 'CL...', 'Only an unaltered key which is not a subkey of anything can specify  partitioning');\n"
"      partition_def (tree);\n"
"      if (store) {\n"
"    {\n"
"	delete from SYS_PARTITION where PART_TABLE = tree[1] and PART_KEY = tree[2];\n"
"	insert into SYS_PARTITION (PART_TABLE, PART_VERSION, PART_KEY, PART_CLUSTER, PART_DATA) values (tree[1], 0, tree[2], tree[3], tree);\n"
"	if (exists (select 1 from sys_cluster where cl_name = tree[3] and cast (cl_map as varchar)[0] = 255 and cast (cl_map as varchar)[1] = 255 and cast (cl_map as varchar)[2] = 255 and cast (cl_map as varchar)[3] = 255))\n"
"	  update sys_keys set key_storage = tree[3] where key_table = tree[1] and (key_name = tree[2] or key_name = tree[1]);\n"
"   }\n"
"	__ddl_changed (tree[1]);\n"
"    }\n"
"    }\n"
  "}\n";



void cluster_init ();

void
ddl_init_schema (void)
{
  recomp_mtx = mutex_allocate ();
  mutex_option (recomp_mtx, "RECOMP", recomp_mtx_entry_check, NULL);
  if (!bootstrap_cli)
    {
      bootstrap_cli = client_connection_create ();
      bootstrap_cli->cli_replicate = REPL_NO_LOG;
      local_start_trx (bootstrap_cli);
    }
  isp_read_schema (bootstrap_cli->cli_trx);
  if (strchr (wi_inst.wi_open_mode, 'a') || strchr (wi_inst.wi_open_mode, 'D')
      || f_read_from_rebuilt_database)
    return;
  ddl_ensure_table ("DB.DBA.SYS_RLS_POLICY", sys_rls_policy_text);
  ddl_ensure_table ("DB.DBA.SYS_CLUSTER", sys_cluster_text);
  ddl_ensure_table ("DB.DBA.SYS_PARTITION", sys_part_text);
  ddl_ensure_table ("DB.DBA.SYS_DPIPE", sys_dpipe_text);

  ddl_std_proc (cluster_stmt_text, 0);
  ddl_init_objects ();
  ddl_ensure_table ("DB.DBA.SYS_ROLE_GRANTS", sys_role_grants_text);
  ddl_ensure_table ("DB.DBA.SYS_COL_STAT", sys_col_stat_text);
  ddl_ensure_table ("DB.DBA.SYS_COL_HIST", sys_col_hist_text);
  ddl_ensure_table ("DB.DBA.SYS_REPL_SUBSCRIBERS", sys_repl_subscribers_text);
  isp_load_stats_data (bootstrap_cli);
  local_commit (bootstrap_cli);
}


const char *
err_first_line (const char * text)
{
  static char copy[101];
  if (strlen (text) > 100)
    {
      memcpy (copy, text, 96);
      copy[96] = '.';
      copy[97] = '.';
      copy[98] = '.';
      copy[99] = 0;
      return copy;
    }
  return text;
}
void
ddl_ensure_table (const char *name, const char *text)
{
  client_connection_t *old_cli = sqlc_client();
  sqlc_set_client (NULL);
  if (!sch_name_to_table (wi_inst.wi_schema, name))
    {
      caddr_t err = NULL;
      query_t *obj_create = eql_compile_2 (text, bootstrap_cli, &err, SQLC_DEFAULT);
      if (err)
	{
	  log_error ("Error compiling a server init statement : %s: %s -- %s",
	      ((caddr_t *) err)[QC_ERRNO], ((caddr_t *) err)[QC_ERROR_STRING],
		     err_first_line (text));
	  sqlc_set_client (old_cli);
	  dk_free_tree (err);
	  return;
	}
      sqlc_set_client (bootstrap_cli);
      first_id = DD_FIRST_PRIVATE_OID;
      err = qr_quick_exec (obj_create, bootstrap_cli, "", NULL, 0);
      if (err)
	{
	  if (err == (caddr_t) SQL_NO_DATA_FOUND)
	    log_error ("Error executing a server init statement : NO DATA FOUND -- %s",
		       err_first_line (text));
	  else
	    log_error ("Error executing a server init statement : %s: %s -- %s",
		((caddr_t *) err)[QC_ERRNO], ((caddr_t *) err)[QC_ERROR_STRING],
		       err_first_line (text));
	  dk_free_tree (err);
	  qr_free (obj_create);
	  sqlc_set_client (old_cli);
	  return;
	}
      qr_free (obj_create);

      first_id = DD_FIRST_FREE_OID;
      sqlc_set_client (old_cli);
      local_commit (bootstrap_cli);
    }
  else
    sqlc_set_client (old_cli);
}


void
ddl_ensure_column (const char *table, const char *col, const char *text, int is_drop)
{
  dbe_table_t *tb;
  if (!( tb = sch_name_to_table (wi_inst.wi_schema, table)))
    {
      log_error ("Error compiling a server init statement %s: Table does not exist -- %s",
	  table,
	  text);
      return;
    }
  else
    {
      dbe_column_t *col_found = tb_name_to_column (tb, col);
      if ((!is_drop && !col_found) || (is_drop && col_found))
	{
	  caddr_t err = NULL;
	  query_t *obj_create = eql_compile_2 (text, bootstrap_cli, &err, SQLC_DEFAULT);
	  if (err)
	    {
	      log_error ("Error compiling a server init statement : %s: %s -- %s",
		  ((caddr_t *) err)[QC_ERRNO], ((caddr_t *) err)[QC_ERROR_STRING],
		  text);
	      dk_free_tree (err);
	      return;
	    }
	  first_id = DD_FIRST_PRIVATE_OID;
	  err = qr_quick_exec (obj_create, bootstrap_cli, "", NULL, 0);
	  if (err)
	    {
	      log_error ("Error executing a server init statement : %s: %s -- %s",
		  ((caddr_t *) err)[QC_ERRNO], ((caddr_t *) err)[QC_ERROR_STRING],
		  text);
	      dk_free_tree (err);
	      qr_free (obj_create);
	      return;
	    }

	  qr_free (obj_create);
	  first_id = DD_FIRST_FREE_OID;
	  local_commit (bootstrap_cli);
	}
    }
}


const char *ddl_key_cols_view_text =
"create VIEW DB.DBA.SYS_KEY_COLUMNS as "
"select DB.DBA.SYS_COLS.*, DB.DBA.SYS_KEYS.KEY_TABLE from DB.DBA.SYS_COLS, DB.DBA.SYS_KEYS, DB.DBA.SYS_KEY_PARTS "
"where KP_KEY_ID = KEY_ID and COL_ID = KP_COL and KEY_IS_MAIN = 1";

const char *ddl_fk_text =
"create table SYS_FOREIGN_KEYS (PK_TABLE varchar, PKCOLUMN_NAME varchar (128), "
"			       FK_TABLE varchar, FKCOLUMN_NAME varchar (128), "
"			       KEY_SEQ smallint, UPDATE_RULE smallint, DELETE_RULE smallint, "
"			       FK_NAME varchar (128), PK_NAME varchar (128), "
"			       primary key (FK_TABLE, PK_TABLE, KEY_SEQ, "
"					    FKCOLUMN_NAME, PKCOLUMN_NAME))";
const char *ddl_fk_proc_text_1 =
"create procedure ddl_table_pk_cols (in tb varchar)"
"{"
"  declare id, fill, n_parts integer;"
"  declare cv varchar;"
"  whenever not found goto no_pk_tb;"
"  select KEY_ID, KEY_N_SIGNIFICANT into id, n_parts from SYS_KEYS where KEY_TABLE = tb and KEY_IS_MAIN = 1 and KEY_MIGRATE_TO is null;"
"  cv := make_array (n_parts, 'any');"
"  declare cr cursor for select \"COLUMN\" from SYS_KEY_PARTS, SYS_COLS where KP_KEY_ID = id and COL_ID = KP_COL order by KP_NTH option (order);"
"  fill := 0;"
"  open cr;"
"  while (fill < n_parts) {"
"    declare cn varchar;"
"    fetch cr into cn;"
"    aset (cv, fill, cn);"
"    fill := fill + 1;"
"  }"
"  return cv;"
"  "
" no_pk_tb: "
"  signal ('42S02', 'foreign key references non-existent table', 'SQ123');"
"}";


const char *ddl_fk_check_text =
"create procedure ddl_foreign_key_check_data (in fk_tb varchar, in _pk_table varchar, in decl varchar) \n"
"{ \n"
"  declare _datacheck_stmt, non_null varchar; \n"
"  declare inx, n_pc integer; \n"
"\n"
"  if (exists (select 1 from DB.DBA.SYS_REMOTE_TABLE where RT_NAME in (fk_tb, _pk_table)) or bit_and (decl[8], 1)) \n"
"    return; \n"
"  n_pc := length (aref (decl, 3)); \n"
"  non_null := ''; \n"
"  while (inx < n_pc) \n"
"    { \n"
"      declare fk_col_name varchar; \n"
"      fk_col_name := cast (decl[1][inx] as varchar); \n"
"      non_null := non_null || sprintf ('FK.\"%I\" is not null and ', fk_col_name);  \n"
"      inx := inx + 1; \n"
"    } \n"
"  _datacheck_stmt := sprintf (\n"
"  'select count (*) from \"%I\".\"%I\".\"%I\" FK where %s not exists (select 1 from \"%I\".\"%I\".\"%I\" PK where ',\n"
"  name_part (fk_tb, 0), name_part (fk_tb, 1), name_part (fk_tb, 2), non_null, \n"
"  name_part (_pk_table, 0), name_part (_pk_table, 1), name_part (_pk_table, 2));\n"
"  inx := 0; \n"
"  while (inx < n_pc) \n"
"    { \n"
"      declare fk_col_name, pk_col_name varchar; \n"
"\n"
"      fk_col_name := cast (decl[1][inx] as varchar); \n"
"      pk_col_name := cast (decl[3][inx] as varchar); \n"
"      if (inx > 0) \n"
"        _datacheck_stmt := _datacheck_stmt || ' and '; \n"
"      _datacheck_stmt := _datacheck_stmt || \n"
"                           sprintf ('FK.\"%I\" is not null and ', fk_col_name) || \n"
"                           sprintf ('FK.\"%I\"', fk_col_name) || \n"
"                           ' = ' || \n"
"                           sprintf ('PK.\"%I\"', pk_col_name); \n"
"      inx := inx + 1; \n"
"    } \n"
"  _datacheck_stmt := _datacheck_stmt || ')'; \n"
"  declare _datacheck_rows any; \n"
"  __set_user_id ('dba'); \n"
"  exec (_datacheck_stmt, NULL, NULL, NULL, 1, NULL, _datacheck_rows); \n"
"  if (cast (_datacheck_rows [0][0] as integer) > 0)\n"
"    signal ('42S22', \n"
"      sprintf (\n"
"        'Cannot add foreign key : rows exist in \"%s\" that do not correspond to rows in \"%s\".', \n"
"         fk_tb, _pk_table), \n"
"      'SRXXX');\n"
"}";


const char *ddl_fk_proc_text_2 =
"create procedure ddl_foreign_key (in fk_tb varchar, in _pk_table varchar, in decl varchar) \n"
"{ \n"
"  declare inx, n_fc, n_pc, maxseq integer; \n"
"  declare _fk_name, fk_col_name, pk_col_name, pk_tb, fk_nam varchar; \n"
/*"  dbg_obj_print ('FK def: ', fk_tb, _pk_table, decl);"*/
"  if (not exists (select 1 from SYS_KEYS where KEY_TABLE = _pk_table)) \n"
"    signal ('42S02', 'Foreign key reference to non existent table', 'SQ124'); \n"
"  if (0 = isarray (aref (decl, 3)) or 0 = length (aref (decl, 3))) \n"
"    aset (decl, 3, ddl_table_pk_cols (_pk_table)); \n"
"  else \n"
"     DB.DBA.ddl_check_constraint (_pk_table, decl); \n"
" \n"
"  n_fc := length (aref (decl, 1)); \n"
"  n_pc := length (aref (decl, 3)); \n"
"  if (n_fc <> n_pc) \n"
"    signal ('37000', \n"
"      concat ('Different number of referencing and referenced columns in foreign key declaration from ', \n"
"      fk_tb, ' to ', _pk_table), 'SQ125'); \n"
"  inx := 0; \n"
"  \n"
"  while (inx < n_pc and 0 <> casemode_strcmp (_pk_table, fk_tb)) \n"
"    { \n"
"      fk_col_name := cast (decl[1][inx] as varchar); \n"
"      pk_col_name := cast (decl[3][inx] as varchar); \n"
"      if (not exists ( \n"
"            select 1 \n"
"             from \n"
"               DB.DBA.SYS_COLS, \n"
"               DB.DBA.SYS_KEYS, \n"
"               DB.DBA.SYS_KEY_PARTS \n"
"             where \n"
"               KP_KEY_ID = KEY_ID and \n"
"               COL_ID = KP_COL and \n"
"               KEY_IS_MAIN = 1 and \n"
"               \"KEY_TABLE\" = fk_tb and \n"
"               0 = casemode_strcmp (\"COLUMN\", fk_col_name)) \n"
"          and (not exists ( \n"
"            select 1 \n"
"             from \n"
"               DB.DBA.SYS_COLS \n"
"             where \n"
"               \"TABLE\" = fk_tb and \n"
"               0 = casemode_strcmp (\"COLUMN\", fk_col_name)))) \n"
"         signal ('42S22', \n"
"                 sprintf (\n"
"                   'Foreign key references invalid column \"%s\" in referencing table \"%s\".', \n"
"                    fk_col_name, fk_tb), \n"
"                 'SQ126'); \n"
/* 64 = 0x40 = GR_REFERENCES */
"      if (0 = __any_grants (_pk_table, 64, pk_col_name)) \n"
"         signal ('42S22', \n"
"                 sprintf (\n"
"                   'Access denied for foreign key referencing \"%s\" in table \"%s\".', \n"
"                   fk_col_name, fk_tb), \n"
"                 'SR333'); \n"
"      inx := inx + 1; \n"
"    } \n"
"  ddl_foreign_key_check_data (fk_tb, _pk_table, decl);\n"
"  _fk_name := cast (decl[7] as varchar); \n"
"  if (_fk_name = '0') \n"
"    { \n"
"      declare fk_name1 varchar; \n"
"      fk_name1 := ''; \n"
"      inx := 0; \n"
"      _fk_name := concat (name_part (fk_tb, 2), '_', name_part (_pk_table, 2)); \n"
"      while (inx < n_pc) \n"
"        { \n"
"          fk_name1 := concat (\n"
"               fk_name1, '_', \n"
"               cast (decl[1][inx] as varchar), '_', \n"
"               cast (decl[3][inx] as varchar)); \n"
"          inx := inx + 1; \n"
"        } \n"
/* if the FK name is so long we'll convert it with a hash function */
"      if ((length (_fk_name) + length (fk_name1)) > 120) \n"
"        { \n"
"          fk_name1 := concat ('_', upper (md5 (fk_name1))); \n"
"        } \n"
"      _fk_name := concat (_fk_name, fk_name1); \n"
"    } \n"
"  else \n"
"    DDL_ENSURE_CONSTRAINT_NAME_UNIQUE (_fk_name); \n"
"  pk_tb := _pk_table; \n"
"  fk_nam := _fk_name; \n"
"  maxseq := coalesce (\n"
"       (select max (KEY_SEQ) from DB.DBA.SYS_FOREIGN_KEYS \n"
"          where FK_NAME in \n"
"            (select FK_NAME \n"
"               from DB.DBA.SYS_FOREIGN_KEYS \n"
"               where \n"
"                FK_TABLE = fk_tb and \n"
"                PK_TABLE = pk_tb and \n"
"                FK_NAME <> fk_nam) \n"
"       )+1, \n"
"       0); \n"
"  inx := 0; \n"
"  while (inx < n_pc) \n"
"    { \n"
"      insert replacing DB.DBA.SYS_FOREIGN_KEYS (\n"
"	  FK_TABLE, \n"
"          FKCOLUMN_NAME, \n"
"          PK_TABLE, \n"
"          PKCOLUMN_NAME, \n"
"          KEY_SEQ, \n"
"          FK_NAME, \n"
"          PK_NAME, \n"
"          UPDATE_RULE, \n"
"          DELETE_RULE \n"
"       ) values (\n"
"          fk_tb, \n"
"          cast (decl[1][inx] as varchar), \n"
"	   _pk_table, \n"
"          cast (decl[3][inx] as varchar), \n"
"	   (inx + maxseq), \n"
"          _fk_name, \n"
"          NULL, \n"
"          decl[5], \n"
"          decl[6] \n"
"       ); \n"
"      inx := inx + 1; \n"
"    } \n"
/*"  if (aref (decl, 5) > 0 or aref (decl, 6) > 0)"*/
"  if (bit_and (decl [8], 2) = 0) { \n"
"  log_enable (0); \n"
"  DB.DBA.ddl_fk_rules (_pk_table, null, null); \n"
"  DB.DBA.ddl_fk_check_input (fk_tb, 0); \n"
"  log_enable (1); \n"
"  log_text (\'DB.DBA.ddl_fk_rules (?, null, null)\', _pk_table); \n"
"  log_text (\'DB.DBA.ddl_fk_check_input (?, 0)\', fk_tb); \n"
"  } \n"
"}";

const char *dropt_text =
"create procedure droptable (in tb varchar) "
"{"
"  declare skey_id, _key_id integer; "
"  ddl_owner_check (tb);\n"
"  delete from DB.DBA.SYS_COL_STAT where CS_TABLE = tb; "
"  delete from DB.DBA.SYS_COL_HIST where CH_TABLE = tb; "
"  whenever not found goto no_table; "
"  select KEY_ID into _key_id from DB.DBA.SYS_KEYS where KEY_TABLE = tb and KEY_IS_MAIN = 1; "
"  declare subcr cursor for select KEY_TABLE from DB.DBA.SYS_KEY_SUBKEY, DB.DBA.SYS_KEYS where SUPER = _key_id and KEY_ID = SUB"
"    and KEY_MIGRATE_TO is null and KEY_TABLE <> tb; "
"  "
"  whenever not found goto subs_done; "
"  open subcr; "
"  while (1=1) {"
"    declare stb varchar; "
"    fetch subcr into stb; "
"    droptable (stb); "
"  }"
" subs_done:"
"  if (exists (select 1 from DB.DBA.SYS_FOREIGN_KEYS where PK_TABLE = tb and FK_TABLE <> tb)) "
"    signal ('37000', 'Table being dropped is referenced in FOREIGN KEY', 'SR265'); "
"  for select distinct PK_TABLE from DB.DBA.SYS_FOREIGN_KEYS where 0 = casemode_strcmp (FK_TABLE, tb)"
/*"  and (UPDATE_RULE > 0 or DELETE_RULE > 0)"*/
"  do {"
"  DB.DBA.ddl_fk_rules (PK_TABLE, tb, null); }" /*drop referential update&delete*/
"  delete from DB.DBA.SYS_FOREIGN_KEYS where FK_TABLE = tb; "
"  delete from DB.DBA.SYS_GRANTS where G_OBJECT = tb and G_OP < 16; "
"  delete from DB.DBA.SYS_VIEWS where V_NAME = tb; "
"  delete from DB.DBA.SYS_CONSTRAINTS where C_TABLE = tb; "
"  delete from DB.DBA.SYS_RLS_POLICY where RLSP_TABLE = tb; "
"  delete from DB.DBA.SYS_PARTITION where PART_TABLE = tb;\n"
"  for select \"COLUMN\" as col, COL_CHECK as c_check from DB.DBA.SYS_COLS where \"TABLE\" = tb do {"
"     if (isstring (c_check)) { if (strstr (c_check, 'I') is not null) { SET_IDENTITY_COLUMN (tb, col, 0); } };"
"  }"
"  delete from DB.DBA.SYS_COLS where \\TABLE = tb; "
"  for select T_NAME from DB.DBA.SYS_TRIGGERS where T_TABLE = tb do { __drop_trigger (tb, name_part (T_NAME, 2)); }"
"  delete from DB.DBA.SYS_TRIGGERS where T_TABLE = tb; "
"  declare key_cr cursor for select KEY_ID from DB.DBA.SYS_KEYS where KEY_TABLE = tb; "
"  whenever not found goto done; "
"  open key_cr; "
"  while (1=1) {"
"    fetch key_cr into _key_id; "
"    delete from DB.DBA.SYS_KEY_PARTS where KP_KEY_ID = _key_id; "
"    delete from DB.DBA.SYS_KEYS where KEY_ID = _key_id; "
"    delete from DB.DBA.SYS_KEY_SUBKEY where SUB = _key_id;"
"  }"
" done: "
"  __ddl_changed (tb); "
/*"  txn_killall (); "*/
"  return 1; "
" no_table:"
"  signal ('S0002', 'No table in drop table.', 'SR266'); "
"}";

const char *dropt_check_text =
"create procedure droptable_check (in tb varchar) \n"
"{ \n"
"  declare skey_id, _key_id integer; \n"
"  ddl_owner_check (tb); \n"
"  whenever not found goto no_table; \n"
"  select KEY_ID into _key_id from DB.DBA.SYS_KEYS where KEY_TABLE = tb and KEY_IS_MAIN = 1; \n"
"  declare subcr cursor for select KEY_TABLE from DB.DBA.SYS_KEY_SUBKEY, DB.DBA.SYS_KEYS where SUPER = _key_id and KEY_ID = SUB and KEY_MIGRATE_TO is null and KEY_TABLE <> tb; \n"
"  whenever not found goto subs_done; \n"
"  open subcr; \n"
"  while (1=1) { \n"
"    declare stb varchar; \n"
"    fetch subcr into stb; \n"
"    droptable_check (stb); \n"
"  } \n"
" subs_done: \n"
" close subcr; \n"
"  if (exists (select 1 from DB.DBA.SYS_FOREIGN_KEYS where PK_TABLE = tb and FK_TABLE <> tb)) \n"
"    { \n"
"      declare _fk_name, _fk_table varchar; \n"
"      _fk_name := null; \n"
"      select FK_NAME, FK_TABLE into _fk_name, _fk_table from DB.DBA.SYS_FOREIGN_KEYS \n"
"        where PK_TABLE = tb and FK_TABLE <> tb; \n"
"      if (_fk_name is not NULL) \n"
"        signal ('37000', concat (\n"
"          'Table ', tb, \n"
"          ' being dropped is referenced in FOREIGN KEY constraint ', _fk_name, \n"
"          ' of table ', _fk_table), \n"
"          'SR267'); \n"
"    } \n"
"  return 1; \n"
" no_table: \n"
"  signal ('42S02', 'No table in drop table.', 'SR268'); \n"
"}";

const char *constraint_check_text =
"create procedure DDL_ENSURE_CONSTRAINT_NAME_UNIQUE (in _constraint_name varchar) \n"
"  { \n"
"    declare _type, constraint_name varchar; \n"
"    if (_constraint_name = 0) \n"
"      return; \n"
"    constraint_name := sprintf ('%s', cast (coalesce (_constraint_name, '') as varchar)); \n"
"    if (exists (select 1 from SYS_FOREIGN_KEYS where 0 = casemode_strcmp (FK_NAME, constraint_name))) \n"
"      { \n"
"	_type := 'foreign key'; \n"
"	goto name_found; \n"
"      } \n"
"    if (exists (select 1 from SYS_CONSTRAINTS where 0 = casemode_strcmp (C_TEXT, constraint_name))) \n"
"      { \n"
"	_type := 'constraint'; \n"
"	goto name_found; \n"
"      } \n"
"    if (exists (select 1 from SYS_KEYS where 0 = casemode_strcmp (KEY_NAME, constraint_name))) \n"
"      { \n"
"	_type := 'index'; \n"
"	goto name_found; \n"
"      } \n"
"    return; \n"
" \n"
"name_found: \n"
"    signal ('22023', concat ('There is already a ', _type, ' named ', constraint_name), 'SR473'); \n"
"  } \n";

void
ddl_fk_init (void)
{
  ddl_ensure_table ("DB.DBA.SYS_FOREIGN_KEYS", ddl_fk_text);
  ddl_ensure_table ("DB.DBA.SYS_KEY_COLUMNS", ddl_key_cols_view_text);
  ddl_std_proc (ddl_fk_proc_text_1, 1);
  ddl_std_proc (ddl_fk_check_text, 1);
  ddl_std_proc (ddl_fk_proc_text_2, 1);
  ddl_std_proc (dropt_text, 1);
  ddl_std_proc (dropt_check_text, 1);
  ddl_std_proc (constraint_check_text, 1);
  ensure_constraint_unq_stmt = sql_compile_static (
      ensure_constraint_unq_txt, bootstrap_cli, NULL, SQLC_DEFAULT);
}


void
sch_key_fill_sub (const void *id, void * data)
{
  dbe_key_t *key = (dbe_key_t *) data;

  key_fill_supers (key, key);
}


void
sch_fill_key_subkey (dbe_schema_t * sc)
{
  super_sub_schema = sc;
  maphash (sch_key_fill_sub, sc->sc_id_to_key);
}


caddr_t
it_read_object_dd (lock_trx_t * lt, dbe_schema_t * sc)
{
  client_connection_t *temp_cli = client_connection_create ();
  caddr_t err;
  local_cursor_t *lc;

  ddl_ensure_init (bootstrap_cli);

  if (!inherit_key_qr)
    {
      inherit_key_qr = eql_compile (inherit_key_text, bootstrap_cli);
      table_keys_qr = eql_compile (table_keys_text, bootstrap_cli);
      read_key_subkey_qr = eql_compile (read_key_subkey_text, bootstrap_cli);
    }
  clrhash (sc->sc_key_subkey);
  temp_cli->cli_trx = lt;

  err = qr_quick_exec (read_key_subkey_qr, temp_cli, "", &lc, 0);
  if (err != SQL_SUCCESS)
    {
      client_connection_free (temp_cli);
      return err;
    }
  while (lc_next (lc))
    {
      key_id_t super = (key_id_t) unbox (lc_get_col (lc, "S.SUPER"));
      key_id_t sub = (key_id_t) unbox (lc_get_col (lc, "S.SUB"));
      dbe_key_t *superk = sch_id_to_key (sc, super);
      dbe_key_t *subk = sch_id_to_key (sc, sub);
      sch_set_subkey (sc, sub, super);
      if (superk && subk)
	dk_set_pushnew (&subk->key_supers, (void *) superk);
    }
  err = lc->lc_error;
  lc_free (lc);
  client_connection_free (temp_cli);
  if (err != SQL_SUCCESS)
    return err;
  sch_fill_key_subkey (sc);

  return NULL;
}

void
ddl_inherit_partition (query_instance_t * qi, char * from, char * to, int id)
{
  static query_t * qr;
  caddr_t err = NULL;
  if (!qr)
    qr = sql_compile ("DB.DBA.DDL_INHERIT_PARTITION (?, ?, ?)", bootstrap_cli, &err, SQLC_DEFAULT);
  AS_DBA (qi, err = qr_rec_exec (qr, qi->qi_client, NULL, qi, NULL, 3,
				 ":0", from, QRP_STR,
				 ":1", to, QRP_STR,
				 ":2", (ptrlong) id, QRP_INT));
  if (err)
    {
      QI_POISON_TRX (qi);
      sqlr_resignal (err);
    }
}


void
ddl_create_sub_table (query_instance_t * qi, char *name,
    caddr_t * supers, caddr_t * cols)
{
  client_connection_t *cli = qi->qi_client;
  volatile int key_found = 0;	/* AIX cc screws up if not volatile */
  local_cursor_t *lc_keys, *lc_parts;


  ddl_create_table (qi, name, cols);
  qr_rec_exec (table_keys_qr, cli, &lc_keys, qi, NULL, 1,
      ":0", supers[0], QRP_STR);
  while (lc_next (lc_keys))
    {
      int key_last_part = 0;
      long old_id = (long) unbox (lc_nth_col (lc_keys, 0));
      long super_id = (long) unbox (lc_nth_col (lc_keys, 2));
      int is_pk = unbox (lc_nth_col (lc_keys, 1));
      long new_id = qi_new_key_id (qi);
      long new_ver = qi_new_key_version (qi, super_id);
      key_found = 1;
      qr_rec_exec (inherit_key_qr, cli, &lc_parts, qi, NULL, 5,
	  ":0", supers[0], QRP_STR,
	  ":1", name, QRP_STR,
		   ":2", (ptrlong) old_id, QRP_INT,
		   ":3", (ptrlong) new_id, QRP_INT,
		   ":4", (ptrlong) new_ver, QRP_INT);
      ddl_inherit_partition (qi, supers[0], name, old_id);
      while (lc_next (lc_parts))
	key_last_part = (long) unbox (lc_get_col (lc_parts, "KP.KP_NTH"));
      lc_free (lc_parts);

      if (is_pk)
	{
	  local_cursor_t *lc_cols;
	  qr_rec_exec (table_cols_qr, cli, &lc_cols, qi, NULL, 1,
	      ":0", name, QRP_STR);
	  while (lc_next (lc_cols))
	    {
	      oid_t col_id = (oid_t) unbox (lc_get_col (lc_cols, "C.COL_ID"));
	      key_last_part++;
	      if (key_last_part >= TB_MAX_COLS)
		SQL_DDL_ERROR (qi, ("42S22", "SQ011", "Column count too large"));
	      qr_rec_exec (add_key_part_stmt, cli, NULL, qi, NULL, 3,
			   ":0", (ptrlong) new_id, QRP_INT,
			   ":1", (ptrlong) key_last_part, QRP_INT,
			   ":2", (ptrlong) col_id, QRP_INT);
	    }
	  lc_free (lc_cols);
	}
    }
  lc_free (lc_keys);
  if (!key_found)
    SQL_DDL_ERROR (qi,
	("42S12", "SQ012", "Cannot inherit table with no keys %s.", supers[0]));
  ddl_table_changed (qi, name);
}


void
ddl_create_subtable_keys (query_instance_t * qi, dbe_table_t * tb,
			  char *key_name, key_id_t super_key_id, key_id_t top_super_id)
{
  dbe_schema_t *sc = wi_inst.wi_schema;
  dk_set_t subtables = tb_list_subtables (sc, tb, 1);
  int key_last_part = 0;

  DO_SET (dbe_table_t *, sub, &subtables)
  {
    key_id_t new_id = qi_new_key_id (qi);
    key_ver_t new_kv = qi_new_key_version (qi, top_super_id);
    local_cursor_t *lc_parts;
    qr_rec_exec (inherit_key_qr, qi->qi_client, &lc_parts, qi, NULL, 5,
		 ":0", tb->tb_name, QRP_STR,
		 ":1", sub->tb_name, QRP_STR,
		 ":2", (ptrlong) super_key_id, QRP_INT,
		 ":3", (ptrlong) new_id, QRP_INT,
		 ":4", (ptrlong)new_kv, QRP_INT);
    ddl_inherit_partition (qi, tb->tb_name, sub->tb_name, super_key_id);
    while (lc_next (lc_parts))
      key_last_part = (int) unbox (lc_get_col (lc_parts, "KP.KP_NTH"));

    if (key_last_part >= TB_MAX_COLS)
      SQL_DDL_ERROR (qi, ("42S22", "SQ013", "Column count too large"));
    lc_free (lc_parts);
    ddl_table_changed (qi, sub->tb_name);
    ddl_create_subtable_keys (qi, sub, key_name, new_id, top_super_id);
  }
  END_DO_SET ();
}


void
ddl_table_and_subtables_changed (query_instance_t *qi, char *tb_name)
{
  dbe_table_t *tb;
  ddl_table_changed (qi, tb_name);
  tb = qi_name_to_table (qi, tb_name);
  if (tb)
    {
      dbe_schema_t *sc = wi_inst.wi_schema;
      dk_set_t subtables = tb_list_subtables (sc, tb, 1);
      DO_SET (dbe_table_t *, sub, &subtables)
	{
	  ddl_table_changed (qi, sub->tb_name);
	}
      END_DO_SET ();
    }
}



void
ddl_add_col (query_instance_t * qi, const char *table, caddr_t * col)
{
  caddr_t err;
  static query_t *add_col_proc;
  client_connection_t *cli = qi->qi_client;

  dbe_table_t *tb = qi_name_to_table (qi, table);

  if (!add_col_proc)
    add_col_proc = sql_compile_static ("DB.DBA.add_col (?, ?,?)",
	bootstrap_cli, &err, SQLC_DEFAULT);
  if (!tb)
    sqlr_new_error ("42S02", "SQ018", "No table %s.", table);
  sql_error_if_remote_table (tb);
  AS_DBA (qi, err = qr_rec_exec (add_col_proc, cli, NULL, qi, NULL, 3,
      ":0", (0 == strcmp (tb->tb_name, "DB.DBA.SYS_TRIGGERS")) ? "SYS_TRIGGERS" : tb->tb_name, QRP_STR,
      ":1", col[0], QRP_STR,
			     ":2", box_copy_tree ((caddr_t) col), QRP_RAW));

  if (err != SQL_SUCCESS)
    {
      QI_POISON_TRX (qi);	/* schema could be inconsistent, do not commit */
      sqlr_resignal (err);
    }
}


void
ddl_modify_col (query_instance_t * qi, char *table, caddr_t * column)
{
  static query_t *modify_col_stmt = NULL;
  caddr_t err = NULL;
  client_connection_t *cli = qi->qi_client;
  dbe_table_t *tb = qi_name_to_table (qi, table);
  dbe_column_t *col;
  dtp_t dtp;
  long prec;
  sql_class_t *udt;
  int ix, pk_part, is_allocated = 0;
  dk_set_t col_options = NULL;
  char *col_opts;


  if (!tb || !sec_tb_check (tb, qi->qi_g_id, qi->qi_u_id, 0))
    sqlr_new_error ("42S02", "SQ176", "No table %s.", table);
  if (sch_view_def (isp_schema (qi->qi_space), tb->tb_name))
    sqlr_new_error ("42S02", "SR329",
	"ALTER TABLE not supported for views. Drop the view and recreate it instead.");
  sql_error_if_remote_table (tb);
  col = tb_name_to_column (tb, column[0]);
  if (!col)
    sqlr_new_error ("42S02", "SQ177", "No column %s.", column[0]);

  udt = ddl_name_to_type (((caddr_t *)column)[1]);
  dtp = ddl_name_to_dtp (((caddr_t *)column)[1]);
  prec = ddl_name_to_prec (((caddr_t *)column)[1]);

  /* dtp check */
  if (dtp != col->col_sqt.sqt_dtp ||
      (udt && !col->col_sqt.sqt_class) ||
      (!udt && col->col_sqt.sqt_class) ||
      (udt && col->col_sqt.sqt_class && !UDT_IS_SAME_CLASS (udt, col->col_sqt.sqt_class)))
    sqlr_new_error ("42000", "SQ178", "Cannot change the type for column %s from %s (%d) to %s (%d).",
	col->col_name, dv_type_title (col->col_sqt.sqt_dtp), col->col_sqt.sqt_dtp,
	dv_type_title (dtp), dtp);
  if (ddl_col_is_not_nullable (((caddr_t *)column)[1]) != col->col_sqt.sqt_non_null && count_exceed (qi, tb->tb_name, 0, NULL))
    sqlr_new_error ("42000", "SQ178", "Cannot change the nullable flag for column %s from %s to %s. "
	"Either specify correct nullable flag or drop column and add as a new.",
	col->col_name, (col->col_sqt.sqt_non_null ? "NOT NULL" : "NULL"), (col->col_sqt.sqt_non_null ? "NULL" : "NOT NULL"));

  if (prec < (long) col->col_precision)
    sqlr_new_error ("42000", "SQ179", "Cannot decrease the precision for column %s from %ld to %ld.",
	col->col_name, (long) col->col_precision, prec);
  if (!IS_BLOB_DTP (dtp) && prec > ROW_MAX_DATA)
    {
      sqlr_new_error ("42S22", "SQ180",
	    "The size (%ld) given to the column '%.100s' exceeds the maximum allowed for any datatype (%ld).",
	    (long)prec, col->col_name, (long)ROW_MAX_DATA);
    }
  if (DV_TYPE_OF (((caddr_t **)column)[1][1]) == DV_ARRAY_OF_POINTER)
    {
      caddr_t *arr = ((caddr_t ***)column)[1][1];
      DO_BOX (ST *, opt, ix, arr)
	{
	  if (ST_P (opt, INDEX_DEF))
	    sqlr_new_error ("42000", "SQ181", "PRIMARY KEY not supported in ALTER TABLE MODIFY COLUMN");
	  else if (ST_P (opt, FOREIGN_KEY))
	    sqlr_new_error ("42000", "SQ182", "REFERENCES not supported in ALTER TABLE MODIFY COLUMN");
	  else if (ST_P (opt, CHECK_CONSTR))
	    sqlr_new_error ("42000", "SQ183", "CHECK not supported in ALTER TABLE MODIFY COLUMN");
	  else if (ST_P (opt, UNIQUE_DEF))
	    sqlr_new_error ("42000", "SQ184", "UNIQUE not supported in ALTER TABLE MODIFY COLUMN");
	  else if (ST_P (opt, CHECK_XMLSCHEMA_CONSTR))
	    sqlr_new_error ("42000", "SQ193", "XML SCHEMA not supported in ALTER TABLE MODIFY COLUMN");
	}
      END_DO_BOX;
    }

  ix = 0;
  pk_part = 0;
  DO_SET (dbe_column_t *, pk_col, &tb->tb_primary_key->key_parts)
    {
      if (!CASEMODESTRCMP (col->col_name, pk_col->col_name))
	{
	  pk_part ++;
	  break;
	}
      else if ((++ix) >= tb->tb_primary_key->key_n_significant)
	break;
    }
  END_DO_SET ();

  col_opts = ddl_col_options (qi, ((caddr_t *)column)[1], dtp, &is_allocated, &col_options);
  if (udt)
    {
      dk_set_push (&col_options, box_dv_short_string ("sql_class"));
      dk_set_push (&col_options, box_copy (udt->scl_name));
    }

  if (!modify_col_stmt)
    modify_col_stmt = sql_compile_static (
	"DB.DBA.__DDL_MODIFY_COL ("
	/*  COL_PREC =*/ " ?, "
	/*  COL_CHECK =*/" ?, "
	/*  COL_SCALE =*/" ?, "
	/*  COL_DEFAULT =*/" serialize (?), "
	/*  COL_NULLABLE =*/" ?, "
	/*  COL_OPTIONS =*/" ?, "
	/* where COL_ID =*/" ?,"
	/* TABLE =*/" ?,"
	/* COLUMN =*/" ?,"
	/* dtp =*/" ?)",
	bootstrap_cli, &err, SQLC_DEFAULT);

  if (!err)
    AS_DBA (qi, err = qr_rec_exec (modify_col_stmt, cli, NULL, qi, NULL, 10,
	":0", (ptrlong) prec, QRP_INT,
	":1", col_opts, QRP_STR,
	":2", ddl_col_scale (((caddr_t *)column)[1]), QRP_RAW,
	":3", ddl_col_default (((caddr_t *)column)[1]), QRP_RAW,
	":4", pk_part ? box_num (1) : ddl_col_nullable (((caddr_t *)column)[1]), QRP_RAW,
	":5", list_to_array (dk_set_nreverse (col_options)), QRP_RAW,
	":6", (ptrlong) col->col_id, QRP_INT,
	":7", tb->tb_name, QRP_STR,
	":8", col->col_name, QRP_STR,
	":9", (ptrlong) col->col_sqt.sqt_dtp, QRP_INT));

  if (err)
    {
      QI_POISON_TRX (qi);	/* schema could be inconsistent, do not commit */
      sqlr_resignal (err);
    }
}


void
ddl_drop_col (query_instance_t * qi, char *table, caddr_t * col)
{
  static query_t *dc_qr;
  caddr_t err;
  dbe_table_t * tb;

  sql_error_if_remote_table (tb = qi_name_to_table (qi, table));
  if (!dc_qr)
    dc_qr = sql_compile_static ("DB.DBA.ddl_drop_col (?, ?)", qi->qi_client, &err, SQLC_DEFAULT);
  AS_DBA (qi, err = qr_rec_exec (dc_qr, qi->qi_client, NULL, qi, NULL, 2,
      ":0", table, QRP_STR,
      ":1", col, QRP_STR));
  if (err != SQL_SUCCESS)
    {
      QI_POISON_TRX (qi);
      sqlr_resignal (err);
    }
}

#define MIN_FOR_ATOMIC 10000
#define atomic_mode(q,m,i) if ((i)) srv_global_lock (q,m);

#define STOP_LOG \
  if (!atomic) \
    { \
      repl = qi->qi_trx->lt_replicate; \
      qi->qi_trx->lt_replicate = REPL_NO_LOG; \
    } \

#define POP_LOG \
  if (!atomic) \
    { \
      qi->qi_trx->lt_replicate = repl; \
    } \

int count_exceed (query_instance_t * qi, const char *name, long cnt, const char *idx);


caddr_t
ddl_clear_index_cluster (query_instance_t * qi, dbe_key_t * key)
{
  caddr_t err = NULL;
  static query_t * qr;
  if (!qr)
    qr = sql_compile ("DB.DBA.__CL_CLR_INX (?, ?)", qi->qi_client, &err, SQLC_DEFAULT);
  if (!err)
    AS_DBA (qi, err = qr_quick_exec (qr, qi->qi_client, "", NULL, 2,
				     ":0", key->key_table->tb_name, QRP_STR,
				     ":1", key->key_name, QRP_STR));
  return err;
}


caddr_t
log_text_cluster (query_instance_t * qi, char * text)
{
  caddr_t err = NULL;
  static query_t * qr;
  if (!qr)
    qr = sql_compile ("DB.DBA.__CL_LOG (?)", qi->qi_client, &err, SQLC_DEFAULT);
  if (!err)
    AS_DBA (qi, err = qr_quick_exec (qr, qi->qi_client, "", NULL, 1,
				     ":0", text, QRP_STR));
  return err;
}


void
ddl_drop_index (caddr_t * qst, const char *table, const char *name, int log_to_trx)
{
  caddr_t err = NULL;
  char temp_tx[300];
  query_instance_t *qi = (query_instance_t *) QST_INSTANCE (qst);
  dbe_schema_t *sc = wi_inst.wi_schema;
  dbe_key_t *key;
  it_cursor_t it_auto;
  it_cursor_t *it = &it_auto;
  char *szTheTableName, *szTheIndexName;
  int atomic;
  caddr_t temp_tx_box;
  caddr_t * repl = qi->qi_trx->lt_replicate;
  int is_cluster = 0;

  atomic = count_exceed (qi, table, MIN_FOR_ATOMIC, name);
  atomic_mode (qi, 1, atomic);
  STOP_LOG;
  if (!table)
    {
      key_id_t key_id = ddl_key_name_to_id (qi, name, NULL);
      key = sch_id_to_key (sc, key_id);
    }
  else
    {
      key = sch_table_key (sc, table, name, 1);
    }
  if (!key)
    {
      POP_LOG;
      atomic_mode (qi, 0, atomic);
      sqlr_new_error ("42S12", "SQ019", "No key %s in %s.", name, table ? table : "any table");
    }
  if (key->key_is_primary)
    {
      POP_LOG;
      atomic_mode (qi, 0, atomic);
      sqlr_new_error ("23000", "SQ020", "Can't drop primary key %s. Use drop table %s instead.",
	  key->key_name, key->key_table->tb_name);
    }
  if (key->key_supers)
    {
      dbe_key_t * sup = key;
      POP_LOG;
      atomic_mode (qi, 0, atomic);
      while (sup->key_supers)
	sup = (dbe_key_t *) sup->key_supers->data;
      sqlr_new_error ("23000", "SQ170", "Key %s is inherited from table %s. Drop the index from it.",
	  key->key_name, sup->key_table->tb_name);
    }
  szTheTableName = box_sprintf_escaped (key->key_table->tb_name, 1);
  szTheIndexName = box_sprintf_escaped (key->key_name, 1);
  snprintf (temp_tx, sizeof (temp_tx), "drop index \"%s\" \"%s\"", szTheIndexName, szTheTableName);
  if (key->key_partition && !cl_run_local_only)
    {
      is_cluster = 1;
      err = ddl_clear_index_cluster (qi, key);
      if (err)
	{
	  POP_LOG;
	  atomic_mode (qi, 0, atomic);
	  sqlr_resignal (err);
	}
    }
  else
    {
      ITC_INIT (it, QI_SPACE (qi), qi->qi_trx);
      itc_drop_index (it, key);
      itc_free (it);
    }
  AS_DBA (qi, qr_rec_exec (drop_key_stmt, qi->qi_client, NULL, qi, NULL, 2,
      ":0", key->key_table->tb_name, QRP_STR,
      ":1", key->key_name, QRP_STR));

  ddl_table_and_subtables_changed (qi, key->key_table->tb_name);
  POP_LOG;
  atomic_mode (qi, 0, atomic);
  if (log_to_trx)
    {
      if (CL_RUN_CLUSTER == cl_run_local_only)
	log_text_cluster (qi, temp_tx);
      else
	log_text (qi->qi_trx, temp_tx);
    }
  dk_free_box(szTheTableName);
  dk_free_box(szTheIndexName);

  if (DO_LOG(LOG_DDL))
    {
      user_t * usr = ((query_instance_t *)(qst))->qi_client->cli_user;

      if (table)
	log_info ("DDLC_6 %s Drop index %.*s (%.*s)", GET_USER,
	    LOG_PRINT_STR_L, name, LOG_PRINT_STR_L, table);
    }
}


void
ddl_build_index (query_instance_t * qi, char *table, char *name, caddr_t * repl)
{
  client_connection_t *cli = qi->qi_client;
  caddr_t err = NULL;
  static query_t *qr;
  dbe_table_t *tb = qi_name_to_table (qi, table);
  if (!qr)
    qr = sql_compile ("DB.DBA.__CREATE_INDEX_FILL (?, ?)", bootstrap_cli, &err, SQLC_DEFAULT);
  if (err)
    sqlr_resignal (err);

  if (cl_run_local_only)
    qi->qi_trx->lt_replicate = REPL_NO_LOG;
  AS_DBA (qi, err = qr_rec_exec (qr, cli, NULL, qi, NULL, 2,
      ":0", tb->tb_name, QRP_STR,
      ":1", name, QRP_STR));
  qi->qi_trx->lt_replicate = repl;

  if (err)
    {
      IN_TXN;
      lt_rollback (qi->qi_trx, TRX_CONT);
      LEAVE_TXN;
      qi->qi_trx->lt_replicate = repl;
      ddl_drop_index ((caddr_t *) qi, table, name, 1);
      sqlr_resignal (err);
    }
  if (cl_run_local_only)
    {
      caddr_t *arr = (caddr_t *)dk_alloc_box (3 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      arr[0] = box_string ("DB.DBA.__CREATE_INDEX_FILL (?, ?)");
      arr[1] = box_string (tb->tb_name);
      arr[2] = box_string (name);
      log_text_array (qi->qi_trx, (caddr_t) arr);
      dk_free_tree ((box_t) arr);
    }
}

int
inx_opt_flag (caddr_t * opts, char *name)
{
  if (!opts)
    return 0;
  return (box_is_string (opts, name, 0, BOX_ELEMENTS (opts)));
}


void sch_cluster_stmt (query_instance_t * qi, ST * tree);


void
inx_opt_cluster (query_instance_t * qi, caddr_t tb_name, caddr_t inx, caddr_t * opts)
{
  int i;
  DO_BOX (ST *, def, i, opts)
    {
      if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (def)
	  && PARTITION_DEF == def->type)
	{
	  def->_.part_def.table = box_copy_tree (tb_name);
	  def->_.part_def.key = box_copy_tree (inx);
	  sch_cluster_stmt (qi, def);
	}
    }
  END_DO_BOX;
}

int
inx_opt_is_cluster (caddr_t * opts)
{
  int i;
  DO_BOX (ST *, def, i, opts)
    {
      if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (def)
	  && PARTITION_DEF == def->type)
	return 1;
    }
  END_DO_BOX;
  return 0;
}




#define KO_CLUSTER(opt) \
  ! inx_opt_flag (opt, "clustered")

#define KO_UNQ(opt)  \
  inx_opt_flag (opt, "unique")	/* These two were swapped, */

#define KO_OID(opt)   \
  inx_opt_flag (opt, "object_id")	/* corrected by AK 1-FEB-1997. */

#define KO_BITMAP(opt)   \
  inx_opt_flag (opt, "bitmap")	/* corrected by AK 1-FEB-1997. */


static void
ddl_index_def_write_schema (query_instance_t * qi, caddr_t name, caddr_t table,
			    caddr_t * cols, caddr_t * opts, int * is_cluster)
{
  caddr_t ret;
  caddr_t *repl;
  repl = qi->qi_trx->lt_replicate;

  QR_RESET_CTX_T (qi->qi_thread)
    {
      dbe_table_t *tb = qi_name_to_table (qi, table);
      if (!tb)
	sqlr_new_error ("42S02", "SQ201",
	    "Cannot find table %.300s in creating index %.300s. "
	    "Specify qualifier and owner if you are not owner of the table.",
	    table, name);
      if (!stricmp (name, tb->tb_name_only))
	sqlr_new_error ("42S11", "SQ198",
	    "Index name %.300s is used by the primary key of the "
	    "table %.300s primary key, this forbidden for an index "
	    "over that table.", name, tb->tb_name_only);
      if (ddl_key_name_to_id (qi, name, tb->tb_qualifier))
	sqlr_new_error ("42S11", "SQ022", "Duplicate index name %.300s", name);
      ret = ddl_ensure_constraint_name_unique (name, qi->qi_client, qi);
      if (ret)
	sqlr_resignal (ret);
      if (tb->tb_primary_key->key_partition && !inx_opt_is_cluster (opts) && 1 != cl_run_local_only)
	sqlr_new_error ("42S11", "SQ022", "For a partitioned table the index must specify partitioning also. Index name %.300s", name);
      if (inx_opt_is_cluster (opts))
	*is_cluster = 1;
      ddl_create_key (qi, name, tb->tb_name,
		      cols, KO_CLUSTER (opts), KO_OID (opts), KO_UNQ (opts), KO_BITMAP (opts), opts);
    }
  QR_RESET_CODE
    {
      caddr_t err = thr_get_error_code (qi->qi_thread);
      POP_QR_RESET;
      qi->qi_trx->lt_replicate = repl;
      sqlr_resignal (err);
    }
  END_QR_RESET;
  qi->qi_trx->lt_replicate = repl;
}

void
ddl_index_def (query_instance_t * qi, caddr_t name, caddr_t table, caddr_t * cols, caddr_t * opts)
{
  int atomic;
  caddr_t *repl = qi->qi_trx->lt_replicate;
  int is_cluster = 0;
  /* commit, because it will clear up the lt_log */
  ddl_commit_trx (qi);

  ddl_index_def_write_schema (qi, name, table, cols, opts, &is_cluster);

  atomic = count_exceed (qi, table, MIN_FOR_ATOMIC, name);
  atomic_mode (qi, 1, atomic);  /* global lock (log is disabled) */
  QR_RESET_CTX_T (qi->qi_thread)
    {
      if (qi_name_to_table (qi, table) && !inx_opt_flag (opts, "no_fill"))
	{
	  ddl_build_index (qi, table, name, repl);
	}
    }
  QR_RESET_CODE
    {
      caddr_t err = thr_get_error_code (qi->qi_thread);
      POP_QR_RESET;
      POP_LOG;
      QR_RESET_CTX_T (qi->qi_thread)
	{
	  ddl_drop_index ((caddr_t*)qi, table, name, REPL_NO_LOG != repl);
	}
      QR_RESET_CODE
	{
	  caddr_t dt_err = NULL;
	  dt_err = thr_get_error_code (qi->qi_thread);
	  dk_free_tree (dt_err);
	}
      END_QR_RESET;
      atomic_mode (qi, 0, atomic);
      sqlr_resignal (err);
    }
  END_QR_RESET;

  POP_LOG;
  atomic_mode (qi, 0, atomic); /* unlock */
  if (DO_LOG(LOG_DDL))
    {
      user_t * usr = ((query_instance_t *)(qi))->qi_client->cli_user;
      if (usr && GET_USER)
	log_info ("DDLC_5 %s Create index %*.s (%*.s)", GET_USER,
	    LOG_PRINT_STR_L, name, LOG_PRINT_STR_L, table);
    }

}


caddr_t
bif_table_renamed (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t *)qst;
  char *old = bif_string_arg (qst, args, 0, "ddl_table_renamed");
  char *new_name = bif_string_arg (qst, args, 1, "ddl_table_renamed");
  dbe_table_t *old_tb;
  dk_set_t old_roots = NULL;
  old = ddl_complete_table_name (qi, old);
  if (!old)
    {
      *err_ret = srv_make_new_error ("42S02", "SQ023", "No table in rename table");
      return NULL;
    }
  old_tb = sch_name_to_table (isp_schema (NULL), old);
  DO_SET (dbe_key_t *, old_k, &old_tb->tb_keys)
    {
      dk_set_push (&old_roots, (caddr_t) ((ptrlong) old_k->key_id));
      dk_set_push (&old_roots, old_k->key_fragments);
      old_k->key_fragments = NULL;
    }
  END_DO_SET();
      old_roots = dk_set_nreverse (old_roots);
  qi_read_table_schema (qi, old);
  qi_read_table_schema_old_keys (qi, new_name, old_roots);
  dk_set_free (old_roots);
  return NULL;
}


void
ddl_rename_table_1 (query_instance_t * qi, char *old, char *new_name, caddr_t *err_ret)
{
  client_connection_t *cli = qi->qi_client;
  local_cursor_t *tb_lc;
  dbe_table_t *new_tb;
  dbe_table_t *old_tb;
  static query_t *ren_table;
  if (!ren_table)
    {
      ren_table = eql_compile ("DB.DBA.rename_table (?, ?)", bootstrap_cli);
    }
  old = ddl_complete_table_name (qi, old);
  sql_error_if_remote_table (qi_name_to_table (qi, old));
  if (!old)
    {
      *err_ret = srv_make_new_error ("42S02", "SQ023", "No table in rename table");
      return;
    }
  if (NULL != (new_tb = qi_name_to_table (qi, new_name)))
    {
      *err_ret = srv_make_new_error ("42S01", "SQ201",
	  "There is already table named %s in ALTER TABLE",
	  new_tb->tb_name);
      return;
    }
  old_tb = sch_name_to_table (isp_schema (NULL), old);
  AS_DBA(qi, *err_ret = qr_rec_exec (ren_table, cli, &tb_lc, qi, NULL, 2,
      ":0", new_name, QRP_STR,
      ":1", old, QRP_STR));
  if (tb_lc)
    lc_free (tb_lc);
  if (SQL_SUCCESS != *err_ret)
    return;
  new_tb = sch_name_to_table (wi_inst.wi_schema, new_name);
  if (DO_LOG(LOG_DDL))
    {
      user_t * usr = ((query_instance_t *)(qi))->qi_client->cli_user;
      log_info ("DDLC_7 %s Rename table %*.s (%*.s)", GET_USER,
	  LOG_PRINT_STR_L, old, LOG_PRINT_STR_L, new_name);
    }
}

void
ddl_rename_table (query_instance_t * qi, char *old, char *new_name)
{
  caddr_t err = NULL;
  caddr_t *repl;
  repl = qi->qi_trx->lt_replicate;
  ddl_rename_table_1 (qi, old, new_name, &err);
  qi->qi_trx->lt_replicate = repl;
  if (err)
    sqlr_resignal (err);
}


int
err_is_state (caddr_t err, char *state)
{
  if (IS_BOX_POINTER (err)
      && 0 == strncmp (((caddr_t *) err)[1], state, strlen (state)))
    return 1;
  else
    return 0;
}

void
ddl_commit (query_instance_t * qi)
{
  int rc;
  IN_TXN;
  rc = lt_commit (qi->qi_trx, TRX_CONT);
  LEAVE_TXN;
  if (LTE_OK != rc)
    sqlr_new_error ("4000X", "SQ024",
	"Transaction could not commit after DDL statement. Last DDL statement rolled back");
}

int
count_exceed (query_instance_t * qi, const char *name, long cnt, const char *idx)
{
  caddr_t escaped_name;
  local_cursor_t *lc;
  caddr_t err = NULL;
  char stmt [500];
  long ix = 0;
  query_t *qr;
  dbe_key_t *key = NULL;
  dbe_table_t *tb = NULL;

  qi_new_col_id (qi);
  if (name)
    {
      if (sch_view_def (wi_inst.wi_schema, name))
	return 0;
      tb = qi_name_to_table (qi, name);
    }
  else if (idx)
    {
      key_id_t key_id = ddl_key_name_to_id (qi, idx, NULL);
      dbe_schema_t *sc = wi_inst.wi_schema;
      key = sch_id_to_key (sc, key_id);
      if (key && sch_view_def (wi_inst.wi_schema, key->key_table->tb_name))
	return 0;
    }
  else
    return 0;

  if (tb)
    {
      sql_error_if_remote_table (tb);
      escaped_name = box_sprintf_escaped (tb->tb_name, 1);
    }
  else if (key)
    {
      sql_error_if_remote_table (key->key_table);
      escaped_name = box_sprintf_escaped (key->key_table->tb_name, 1);
    }
  else
    return 0;

  snprintf (stmt, sizeof (stmt), "select 1 from \"%s\" table option (index primary key)", escaped_name);
  dk_free_box (escaped_name);
  qr = sql_compile (stmt, qi->qi_client, NULL, SQLC_DEFAULT);
  if (!qr)
    return 0;
  err = qr_rec_exec (qr, qi->qi_client, &lc, qi, NULL, 0);
  if (err)
    {
      dk_free_tree (err);
      qr_free (qr);
      return 0;
    }
  while (lc_next (lc))
    {
      ix++;
      if (ix > cnt)
	{
	  lc_free (lc);
	  return 1;
	}
    }
  lc_free (lc);
  qr_free (qr);
  return 0;
}

struct remote_table_s * find_remote_table (char * name, int create);

void
sqlc_quote_dotted_quote (char *text, size_t tlen, int *fill, char *name, const char *quote)
{
  int f;
  if ('\"' == name[0])
    {
      sprintf_more (text, tlen, fill, "%s", name);
      return;
    }
  if ('\1' == name[0])
    {
      sprintf_more (text, tlen, fill, "%s", name + 1);
      return;
    }
  sprintf_more (text, tlen, fill, "%s", quote);
  f = *fill;
  while (*name)
    {
      char c = *name;
      if ('.' == c)
	{
	  sprintf_more (text, tlen, &f, "%s.%s", quote, quote);
	}
      else if ('\x0A' == c)
	{
	  text[f++] = '.';
	}
      else if ('\"' == *name)
	{
	  if (*(name + 1) != '\"')
	    {
	      text[f++] = '\"';
	      text[f++] = *name;
	    }
	}
      else
	text[f++] = *name;
      name++;
    }
  sprintf_more (text, tlen, &f, "%s", quote);
  *fill = f;
}


static int
ddl_droptable_pre (query_instance_t * qi, char *name)
{
  client_connection_t *cli = qi->qi_client;
  local_cursor_t *lc = NULL;
  static query_t *repl_check_stmt = NULL;
  caddr_t err;

  if (!sch_name_to_table (isp_schema (NULL), "DB.DBA.SYS_SNAPSHOT") ||
      !sch_proc_def (isp_schema (NULL), "DB.DBA.DROPTABLE_PRE"))
    return 0;

  if (!repl_check_stmt)
    {
      repl_check_stmt = sql_compile_static (
	  "select DB.DBA.DROPTABLE_PRE (?)",
	   bootstrap_cli, &err, SQLC_DEFAULT);
      if (err != SQL_SUCCESS)
	{
	  qr_free (repl_check_stmt);
	  repl_check_stmt = NULL;
	  sqlr_resignal (err);
	}
    }

  AS_DBA (qi, err = qr_rec_exec (repl_check_stmt, cli, &lc, qi, NULL, 1, ":0", name, QRP_STR));
  if (err != SQL_SUCCESS)
    {
      lc_free (lc);
      sqlr_resignal (err);
    }

  if (lc_next (lc))
    { /* it is a snapshot replication destination */
      long ret = unbox (lc_nth_col (lc, 0));
      return ret ? 1 : 0;
    }
  lc_free (lc);
  return 0;
}


void
ddl_drop_table (query_instance_t * qi, char *name)
{
  client_connection_t *cli = qi->qi_client;
  caddr_t err;
  query_t *del_st;
  caddr_t drop_stmt;
  int atomic;
  caddr_t * repl = qi->qi_trx->lt_replicate;
  name = ddl_complete_table_name (qi, name);

  if (!find_remote_table (name, 0))
    atomic = count_exceed (qi, name, MIN_FOR_ATOMIC, NULL);
  else
    atomic = 0;

  if (ddl_droptable_pre (qi, name))
    return;

  atomic_mode (qi, 1, atomic);
  if (!cl_run_local_only)
    qi->qi_trx->lt_replicate = repl;
#if 1
  /* first check for references to avoid delete action */
  del_st = sql_compile_static ("DB.DBA.droptable_check (?)", cli, &err, SQLC_DEFAULT);
  if (del_st)
    {
      err = qr_rec_exec (del_st, cli, NULL, qi, NULL, 1, ":0", name, QRP_STR);
      if (err != SQL_SUCCESS)
	{
	  atomic_mode(qi, 0, atomic);
	  qr_free (del_st);
	  sqlr_resignal (err);
	}
      qr_free (del_st);
      del_st = NULL;
    }
#endif

#ifdef BIF_XML
  del_st = sql_compile_static ("DB.DBA.vt_clear_text_index (?)", cli, &err, SQLC_DEFAULT);
  if (del_st)
    {
      AS_DBA (qi, err = qr_rec_exec (del_st, cli, NULL, qi, NULL, 1,
	  ":0", name, QRP_STR));
      if (err)
	{
	  atomic_mode (qi, 0, atomic);
	  qr_free (del_st);
	  sqlr_resignal (err);
	}
      qr_free (del_st);
    }

#endif

  if (!sch_view_def (wi_inst.wi_schema, name))
    {
      char temp[500];
      caddr_t escaped_name = box_sprintf_escaped (name, 1);
      dbe_table_t * tb = qi_name_to_table (qi, name);
      DO_SET (dbe_key_t *, key, &tb->tb_keys)
	{
	  if (key->key_is_primary || key->key_supers)
	    continue;
	  ddl_drop_index ((caddr_t *) qi, name, key->key_name, (CL_RUN_CLUSTER == cl_run_local_only ? 1 : 0));
	}
      END_DO_SET();
      snprintf (temp, sizeof (temp), "delete from \"%s\"", escaped_name);
      dk_free_box (escaped_name);
      del_st = sql_compile (temp, cli, &err, SQLC_DEFAULT);
      if (del_st)
	{
	  char old_no_triggers = cli ? cli->cli_no_triggers : 0;
	  if (cli)
	    cli->cli_no_triggers = 1;
	  err = qr_rec_exec (del_st, cli, NULL, qi, NULL, 0);
	  if (cli)
	    cli->cli_no_triggers = old_no_triggers;
	  if (err != SQL_SUCCESS
	      && err_is_state (err, "S"))
	    {
	      atomic_mode(qi, 0, atomic);
	      qr_free (del_st);
	      sqlr_resignal (err);
	    }

	  qr_free (del_st);
	}
    }
  else
    sch_set_view_def (wi_inst.wi_schema, name, NULL);
  del_st = sql_compile_static ("DB.DBA.droptable (?)", cli, &err, SQLC_DEFAULT);
  if (!del_st)
    {
      atomic_mode (qi, 0, atomic);
      sqlr_new_error ("42S02", "SQ025", "Bad table in drop table.");
    }
  AS_DBA (qi, err = qr_rec_exec (del_st, cli, NULL, qi, NULL, 1,
      ":0", name, QRP_STR));
  if (err != SQL_SUCCESS)
    {
      /* the droptable proc call failed. May have inconsistent schema. Prevent commit */
      atomic_mode (qi, 0, atomic);
      if (!err_is_state (err, "S0002"))
	QI_POISON_TRX (qi);
      qr_free (del_st);
      sqlr_resignal (err);
    }
  atomic_mode (qi, 0, atomic);
  if (atomic)
    {
      drop_stmt = dk_alloc_box (strlen (name) * 2 + 6 + 12,  DV_SHORT_STRING);
      strcpy_box_ck (drop_stmt, "drop table ");
      sprintf_escaped_table_name (drop_stmt + strlen (drop_stmt), name);
      log_text (qi->qi_trx, drop_stmt);
      dk_free_box (drop_stmt);
    }
  qr_free (del_st);

  if (DO_LOG_INT(LOG_DDL))
    {
      LOG_GET
      log_info ("DDLC_1 %s %s %s Drop table %.*s", user, from, peer, LOG_PRINT_STR_L, name);
    }
}


void sec_stmt_exec (query_instance_t * qi, ST * tree);


void
ddl_ensure_view_table (query_instance_t * qi)
{
  dbe_table_t *tb = sch_name_to_table (wi_inst.wi_schema,
      "DB.DBA.SYS_VIEWS");
  if (tb)
    {
      dbe_column_t *col = tb_name_to_column (tb, "V_SCH");
      col->col_sqt.sqt_dtp = DV_LONG_STRING;
    }
  tb = qi_name_to_table (qi, "DB.DBA.SYS_TRIGGERS");
  if (tb)
    {
      dbe_column_t *col = tb_name_to_column (tb, "T_SCH");
      col->col_sqt.sqt_dtp = DV_LONG_STRING;
    }
}


void
ddl_store_view (query_instance_t * qi, ST * tree)
{
  caddr_t err = NULL;
  static query_t *set_view_qr;
  char db_null_buf[10];
  caddr_t db_null;
  caddr_t short_text, long_text, text = tree->_.view_def.text;

  BOX_AUTO (db_null, db_null_buf, 0, DV_DB_NULL);
  if (!set_view_qr)
    {
      ddl_ensure_view_table (qi);
      set_view_qr = sql_compile_static ("insert replacing DB.DBA.SYS_VIEWS "
	  "  (V_SCH, V_NAME, V_TEXT, V_EXT) values (?, ?, ?, ?)",
	  bootstrap_cli, &err, SQLC_DEFAULT);
    }
  if (strlen (text) > 1500)
    {
      short_text = db_null;
      long_text = text;
    }
  else
    {
      short_text = text;
      long_text = db_null;
    }
  err = qr_rec_exec (set_view_qr, qi->qi_client, NULL, qi, NULL, 4,
      ":0", qi->qi_client->cli_qualifier, QRP_STR,
      ":1", tree->_.view_def.name, QRP_STR,
      ":2", box_copy (short_text), QRP_RAW,
      ":3", box_copy (long_text), QRP_RAW);
  BOX_DONE (db_null, db_null_buf);

  if (err != (caddr_t) SQL_SUCCESS)
    sqlr_resignal (err);
  if (ST_P (tree, VIEW_DEF))
    sqlo_calculate_view_scope (qi, &tree->_.view_def.exp, tree->_.view_def.name);
  sch_set_view_def (wi_inst.wi_schema,
      tree->_.view_def.name, (caddr_t) tree->_.view_def.exp);
  {
    caddr_t *log_array = (caddr_t *) dk_alloc_box (4 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
    log_array[0] = box_string ("__view_changed (?, ?, ?)");
    log_array[1] = box_string (tree->_.view_def.name);
    log_array[2] = box_string (qi->qi_client->cli_qualifier);
    log_array[3] = box_string (tree->_.view_def.text);
    log_text_array (qi->qi_trx, (caddr_t) log_array);
    dk_free_tree ((box_t) log_array);
    }

  if (DO_LOG(LOG_DDL))
    {
      user_t * usr = ((query_instance_t *)(qi))->qi_client->cli_user;
      if (usr)
	log_info ("DDLC_4 %s Create view %.*s", GET_USER, LOG_PRINT_STR_L, tree->_.view_def.name);
    }
}


void
ddl_store_mapping_schema (query_instance_t * qi, caddr_t view_name, caddr_t reload_text)
{
  caddr_t err = NULL;
  static query_t *set_view_qr;
  char db_null_buf[10];
  caddr_t db_null;
  caddr_t short_text, long_text;

  BOX_AUTO (db_null, db_null_buf, 0, DV_DB_NULL);
  if (!set_view_qr)
    {
      ddl_ensure_view_table (qi);
      set_view_qr = sql_compile_static ("insert replacing DB.DBA.SYS_VIEWS "
	  "  (V_SCH, V_NAME, V_TEXT, V_EXT) values (?, ?, ?, ?)",
	  bootstrap_cli, &err, SQLC_DEFAULT);
    }
  if (strlen (reload_text) > 1500)
    {
      short_text = db_null;
      long_text = reload_text;
    }
  else
    {
      short_text = reload_text;
      long_text = db_null;
    }
  err = qr_rec_exec (set_view_qr, qi->qi_client, NULL, qi, NULL, 4,
      ":0", qi->qi_client->cli_qualifier, QRP_STR,
      ":1", view_name, QRP_STR,
      ":2", box_copy (short_text), QRP_RAW,
      ":3", box_copy (long_text), QRP_RAW);
  BOX_DONE (db_null, db_null_buf);

  if (err != (caddr_t) SQL_SUCCESS)
      sqlr_resignal (err);
  {
    caddr_t *log_array = (caddr_t *) dk_alloc_box (4 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
    log_array[0] = box_string ("__mapping_schema_changed (?, ?, ?)");
    log_array[1] = box_string (view_name);
    log_array[2] = box_string (qi->qi_client->cli_qualifier);
    log_array[3] = box_string (reload_text);
    log_text_array (qi->qi_trx, (caddr_t) log_array);
    dk_free_tree ((box_t) log_array);
  }

  if (DO_LOG(LOG_DDL))
    {
      user_t * usr = ((query_instance_t *)(qi))->qi_client->cli_user;
      if (usr)
	log_info ("DDLC_11 %s Create mapping schema %.*s", GET_USER, LOG_PRINT_STR_L, view_name);
    }
}


static void
ddl_adj_internal_name (char * name)
{
  int ix, len;
  char c;
  if (!name)
    return;
  len = (int) strlen (name);
  for (ix = 0; ix < len; ix++)
    {
      c = name[ix];
      if (!((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9')))
	name [ix] = '_';
    }
}


void
ddl_table_check_constraints_define_triggers (query_instance_t * qi, caddr_t tb_name, ST *check_cond)
{
  char uname [2*MAX_QUAL_NAME_LEN];
  char q[MAX_NAME_LEN], o[MAX_NAME_LEN], n[MAX_NAME_LEN];
  caddr_t err = NULL;
  client_connection_t *cli = qi ? qi->qi_client : bootstrap_cli;

  sch_split_name ("", tb_name, q, o, n);

  if (check_cond)
    {
      ST *st = NULL;
      ST *cmpd;
      query_t *qr;
      local_cursor_t *lc = NULL;


      if (qi)
	{
	  st =
	      listst (5,
		  SELECT_STMT,
		  0,
		  list (1, box_num (1)),
		  0,
		  sqlp_infoschema_redirect (listst (9,
		    TABLE_EXP,
		    list (1,
		      list (3,
			TABLE_REF,
			list (6,
			  TABLE_DOTTED,
			  sqlp_box_id_upcase (tb_name),
			  NULL,
			  NULL, NULL, NULL
			  ),
			NULL
			)
		      ),
		    box_copy_tree ((box_t) check_cond),
		    NULL, NULL, NULL, NULL, NULL, NULL
		    ))
	      );

	  qr = sql_compile_1 ("", cli, &err, SQLC_DO_NOT_STORE_PROC, st, NULL);
	  dk_free_tree ((box_t) st);
	  if (err != SQL_SUCCESS)
	    {
	      if (qi)
		QI_POISON_TRX (qi);
	      sqlr_resignal (err);
	    }
	  err = qr_rec_exec (qr, cli, &lc, qi ? qi : CALLER_LOCAL, NULL, 0);
	  if (!err)
	    {
	      if (lc_next (lc))
		err = srv_make_new_error ("42000", "SR362",
		    "Check constraint cannot be enforced : unconforming rows found in %s",
		    tb_name);
	    }
	  if (lc)
	    lc_free (lc);
	  qr_free (qr);
	  if (err != SQL_SUCCESS)
	    {
	      if (qi)
		QI_POISON_TRX (qi);
	      sqlr_resignal (err);
	    }
	}

      cmpd =
          listst (5, COMPOUND_STMT,
	    listst (1,
	      listst (3, IF_STMT,
		listst (1,
		  listst (3, COND_CLAUSE, check_cond,
		    listst (3, CALL_STMT, sqlp_box_id_upcase ("signal"),
		      listst (3,
			box_dv_short_string ("22023"),
			box_dv_short_string ("CHECK constraint violated"),
			box_dv_short_string ("SR363"))
		    )
		  )
		),
		NULL
	      )
	    ),
	    box_num (0),
	    box_num (0),
	    NULL
	  );

      snprintf (uname, sizeof (uname), "%s_%s_%s_CHKCI", q, o, n);
      ddl_adj_internal_name (uname);

      st = listst (8, TRIGGER_DEF,
	  sqlp_box_id_upcase (uname), /*name */
	  (ptrlong) TRIG_BEFORE,
	  (ptrlong) TRIG_INSERT,
	  box_string (tb_name),
	  (ptrlong)0, /* order */
          (ptrlong)0, /* referencing */
	  box_copy_tree ((box_t) cmpd)
	);

      qr = sql_compile_1 ("", cli, &err, SQLC_DO_NOT_STORE_PROC, st, NULL);
      dk_free_tree ((box_t) st);
      if (err != SQL_SUCCESS)
	{
	  if (qi)
	    QI_POISON_TRX (qi);
	  sqlr_resignal (err);
	}

      snprintf (uname, sizeof (uname), "%s_%s_%s_CHKCU", q, o, n);
      ddl_adj_internal_name (uname);

      st = listst (8, TRIGGER_DEF,
	  sqlp_box_id_upcase (uname), /*name */
	  (ptrlong) TRIG_BEFORE,
	  (ptrlong) TRIG_UPDATE,
	  box_string (tb_name),
	  (ptrlong)0, /* order */
          listst (1, listst (2, OLD_ALIAS, sqlp_box_id_upcase ("O"))), /* REFERENCING OLD as O */
	  cmpd
	);

      qr = sql_compile_1 ("", cli, &err, SQLC_DO_NOT_STORE_PROC, st, NULL);
      dk_free_tree ((box_t) st);
      if (err != SQL_SUCCESS)
	{
	  if (qi)
	    QI_POISON_TRX (qi);
	  sqlr_resignal (err);
	}
    }
  else
    {
      dbe_table_t *tb = sch_name_to_table (isp_schema (NULL), tb_name);

      if (tb)
	{
	  snprintf (uname, sizeof (uname), "%s_%s_%s_CHKCI", q, o, n);
	  ddl_adj_internal_name (uname);
	  tb_drop_trig_def (tb, uname);

	  snprintf (uname, sizeof (uname), "%s_%s_%s_CHKCU", q, o, n);
	  ddl_adj_internal_name (uname);
	  tb_drop_trig_def (tb, uname);
	}
    }
}


void
ddl_table_constraints (query_instance_t * qi, ST * tree)
{
  caddr_t err = NULL;
  static query_t *fk_qr = NULL;
  static query_t *constr_qr = NULL;
  int inx;
  long cond_cnt = 0;
  ST **cols = tree->_.table_def.cols;
  ST *check_cond = NULL;

  if (!fk_qr)
    {
      err = NULL;
      fk_qr = sql_compile_static ("DB.DBA.ddl_foreign_key (?, ?, ?)",
	  bootstrap_cli, &err, SQLC_DEFAULT);
    }
  for (inx = 0; ((uint32) inx) < BOX_ELEMENTS (cols); inx += 2)
    {
      if (!cols[inx] && cols[inx + 1]->type == FOREIGN_KEY)
	{
	  err = qr_rec_exec (fk_qr, qi->qi_client, NULL, qi, NULL, 3,
	      ":0", tree->_.table_def.name, QRP_STR,
	      ":1", ddl_complete_table_name (qi,
		  (char *) cols[inx + 1]->_.fkey.pk_tb), QRP_STR,
	      ":2", box_copy_tree ((caddr_t) cols[inx + 1]), QRP_RAW);
	  if (err != SQL_SUCCESS)
	    {
	      QI_POISON_TRX (qi);
	      sqlr_resignal (err);
	    }
	}
      else if (!cols[inx] && cols[inx + 1]->type == UNIQUE_DEF)
	{
	  char uname [2*MAX_QUAL_NAME_LEN];
	  char * idx_name = cols[inx+1]->_.index.name;
	  int ix = 0;
	  if (!idx_name)
	    {
	      char q[MAX_NAME_LEN], o[MAX_NAME_LEN], n[MAX_NAME_LEN];
	      uname [0] = 0;
	      sch_split_name ("", tree->_.table_def.name, q, o, n);

	      snprintf (uname, sizeof (uname), "%s_%s_%s_UNQC", q, o, n);


	      DO_BOX (caddr_t, col_name, ix, cols[inx+1]->_.index.cols)
		{
		  strcat_ck (uname, "_");
		  strcat_ck (uname, col_name);
		}
	      END_DO_BOX;

	      ddl_adj_internal_name (uname);

	      /*fprintf (stderr, "Unique constraint: %s\n", uname);*/
	    }
	  ddl_index_def (qi, (idx_name ? idx_name : uname), tree->_.table_def.name,
	      cols[inx+1]->_.index.cols, cols[inx+1]->_.index.opts);
	}
      else if (!cols[inx] && ((cols[inx + 1]->type == CHECK_CONSTR) || (cols[inx + 1]->type == CHECK_XMLSCHEMA_CONSTR)))
	{
	  ST *res;
	  if (!constr_qr)
	    {
	      err = NULL;
	      constr_qr = sql_compile_static (
		  "INSERT into DB.DBA.SYS_CONSTRAINTS (C_TABLE, C_ID, C_TEXT, C_MODE) "
		  "  values (?,?,?,serialize (?))",
		  bootstrap_cli, &err, SQLC_DEFAULT);
	      if (err)
		{
		  log_error ("Error executing server init statement: %s: %s",
		      ((caddr_t *) err)[QC_ERRNO], ((caddr_t *) err)[QC_ERROR_STRING]);
		  dk_free_tree (err);
		  return;
		}
	    }
	  err = ddl_ensure_constraint_name_unique (cols[inx + 1]->_.op.arg_2, qi->qi_client, qi);
	  if (err != SQL_SUCCESS)
	    {
	      QI_POISON_TRX (qi);
	      sqlr_resignal (err);
	    }
	  res = listst (3, BOP_NOT, box_copy_tree (cols[inx + 1]->_.op.arg_1), NULL);
	  if (!check_cond)
	    check_cond = res;
	  else
	    check_cond = (ST *) listst (4, BOP_OR, check_cond, res, NULL);
	  err = qr_rec_exec (constr_qr, qi->qi_client, NULL, qi, NULL, 4,
	      ":0", tree->_.table_def.name, QRP_STR,
	      ":1", (ptrlong) cond_cnt++, QRP_INT,
	      ":2", cols[inx + 1]->_.op.arg_2, QRP_STR,
	      ":3", box_copy_tree (cols[inx + 1]->_.op.arg_1), QRP_RAW);
	  if (err != SQL_SUCCESS)
	    {
	      QI_POISON_TRX (qi);
	      dk_free_tree ((box_t) check_cond);
	      sqlr_resignal (err);
	    }
	}
    }

  ddl_table_check_constraints_define_triggers (qi, tree->_.table_def.name, check_cond);
}


void
ddl_same_owner_check (char * sub, char * tb)
{
  char q1 [100];
  char q2 [100];
  char o1 [100];
  char o2 [100];
  char n1 [100];
  char n2 [100];

  sch_split_name ("", tb, q1, o1, n1);
  sch_split_name ("", sub, q2, o2, n2);
  if (0 == strcmp (o1, o2))
    return;
  sqlr_new_error ("42000", "SQ026",
      "The subtable %s must have the same owner as the supertable %s", sub, tb);
}

static void
sql_error_if_remote_table (dbe_table_t *tb)
{
  if (tb && tb->tb_name && find_remote_table (tb->tb_name, 0))
    sqlr_new_error ("42000", "VD084",
	"DDL operation not allowed on a remote table '%s'", tb->tb_name);
}
int cluster_store_defs;

void
sch_cluster_stmt (query_instance_t * qi, ST * tree)
{
}


void
sql_ddl_node_input_1 (ddl_node_t * ddl, caddr_t * inst, caddr_t * state)
{
  query_instance_t *qi = (query_instance_t *) inst;
  ST *tree = (ST *) ddl->ddl_stmt;
#ifdef VIRTTP
  lock_trx_t lt_save;
#endif
  sec_check_ddl (qi, tree);

#ifdef VIRTTP
  IN_TXN;
  memcpy (&(lt_save.lt_2pc), &(qi->qi_trx->lt_2pc), sizeof (lt_save.lt_2pc));
#ifdef _2PC_DDL_TRACE
  _2pc_printf(("sql_ddl_node_input saving... lt_status=%d cli_tp_data=%p %p\n",
	qi->qi_trx->lt_status,
	qi->qi_client->cli_tp_data,
	qi->qi_trx));
#endif
  LEAVE_TXN;
#endif
  switch (tree->type)
    {
    case TABLE_DEF:
      {
	char *super = NULL;
	dbe_table_t *super_tb = NULL;
	ST *prime = NULL;
	int inx;
	caddr_t *cols = (caddr_t *) tree->_.table_def.cols;
	for (inx = 0; ((uint32) inx) < BOX_ELEMENTS (cols); inx += 2)
	  {
	    if (!cols[inx])
	      {
		/* table constraint */
		ST *constr = ((ST *) (cols)[inx + 1]);
		switch (constr->type)
		  {
		  case TABLE_UNDER:
		    {
		      char *full_name;
		      super = constr->_.op.arg_1;
		      super_tb = qi_name_to_table (qi, ((char **) super)[0]);
		      if (!super_tb)
			sqlr_new_error ("42S02", "SQ157",
			    "The supertable %s in UNDER is not defined",
			    ((char **) super)[0]);
		      if (!super_tb->tb_primary_key)
			sqlr_new_error ("42S12", "SQ158",
			    "The supertable %s in UNDER has no primary key",
			    ((char **) super)[0]);
		      sqlr_new_error ("37000", "VEC..", "The UNDER is not supported in vectored execution");
		      full_name = box_string (super_tb->tb_name);
		      ddl_same_owner_check (full_name, tree->_.table_def.name);
		      dk_free_box (((char **) super)[0]);
		      (((char **) super))[0] = full_name;
		      break;
		    }
		  case INDEX_DEF:
		    if (prime)
		      sqlr_new_error ("42S11", "SQ027",
			  "Only one PRIMARY KEY clause allowed");
		    prime = (ST *) constr;
		    break;
		  case FOREIGN_KEY:
		    break;
		  case UNIQUE_DEF:
		    break;
		  case CHECK_CONSTR:
		    break;
		  case CHECK_XMLSCHEMA_CONSTR:
		    break;
		  case DDL_NONE:
		    break;
		  default:
		    sqlr_new_error ("42000", "SQ128", "Unsupported table constraint.");
		  }
	      }
	    else
	      { /* a column - check for duplicates */
		int inx_dup;
		for (inx_dup = 0; ((uint32) inx_dup) < BOX_ELEMENTS (cols); inx_dup += 2)
		  if (inx != inx_dup && cols[inx_dup] && !CASEMODESTRCMP (cols[inx_dup], cols[inx]))
		    sqlr_new_error ("42S21", "SQ028",
			"Column names in each table must be unique. "
			"Column name %s in table %s is specified more than once.",
			cols[inx],
			tree->_.table_def.name);
	      }
	  }
	if (!super && !prime)
	  sqlr_new_error ("42S12", "SQ029",
	       "A table must either have an UNDER or PRIMARY KEY specification.");
	if (super && prime)
	  sqlr_new_error ("42S11", "SQ030",
	      "A table cannot have both an UNDER and PRIMARY KEY.");
	if (super)
	  {
	    DO_SET (dbe_column_t *, col, &super_tb->tb_primary_key->key_parts)
	      {
		int inx_dup;
		for (inx_dup = 0; ((uint32) inx_dup) < BOX_ELEMENTS (cols); inx_dup += 2)
		  if (cols[inx_dup] && !CASEMODESTRCMP (cols[inx_dup], col->col_name))
		    sqlr_new_error ("42S21", "SQ159",
			"Column names in each table must be unique. "
			"Column name %s in table %s conflicts with a column of the supertable %s.",
			cols[inx_dup],
			tree->_.table_def.name,
			super_tb->tb_name);
	      }
	    END_DO_SET();
	    ddl_create_sub_table (qi, tree->_.table_def.name, (caddr_t *) super,
		(caddr_t *) tree->_.table_def.cols);
	  }
	else
	  {
	    caddr_t *opts = prime->_.index.opts;
	    ddl_create_table (qi, tree->_.table_def.name,
		(caddr_t *) tree->_.table_def.cols);
	    ddl_create_primary_key (qi, tree->_.table_def.name,
		tree->_.table_def.name, (caddr_t *) prime->_.index.cols,
				    KO_CLUSTER (opts), KO_OID (opts), opts);
	  }
	QR_RESET_CTX
	  {
	    ddl_table_constraints (qi, tree);
	  }
	QR_RESET_CODE
	  {
	    caddr_t err = NULL;
	    POP_QR_RESET;
	    err = thr_get_error_code (THREAD_CURRENT_THREAD);
	    IN_TXN;
	    lt_rollback (qi->qi_trx, TRX_CONT);
	    LEAVE_TXN;
	    QR_RESET_CTX
	      {
		ddl_drop_table (qi, tree->_.table_def.name);
	      }
	    QR_RESET_CODE
	      {
		caddr_t dt_err = NULL;
		dt_err = thr_get_error_code (THREAD_CURRENT_THREAD);
		dk_free_tree (dt_err);
	      }
	    END_QR_RESET;
	    sqlr_resignal (err);
	  }
	END_QR_RESET;
	break;
      }
    case INDEX_DEF:
      {
	dbe_table_t *tb;
	caddr_t tb_name;

	tb = qi_name_to_table (qi, tree->_.index.table);
	tb_name = tb ? tb->tb_name : tree->_.index.table;

	ddl_index_def (qi, tree->_.index.name, tb_name,
	  tree->_.index.cols, tree->_.index.opts);
	break;
      }
    case ADD_COLUMN:
      ddl_add_col (qi, tree->_.op.arg_1, (caddr_t *) tree->_.op.arg_2);
      break;
    case MODIFY_COLUMN:
      ddl_modify_col (qi, tree->_.op.arg_1, (caddr_t *) tree->_.op.arg_2);
      break;
    case DROP_COL:
      ddl_drop_col (qi, tree->_.op.arg_1, (caddr_t *) tree->_.op.arg_2);
      break;
    case TABLE_RENAME:
      ddl_rename_table (qi, tree->_.op.arg_1, tree->_.op.arg_2);
      break;
    case INDEX_DROP:
      ddl_drop_index (state, tree->_.op.arg_2, tree->_.op.arg_1, 1);
      break;
    case TABLE_DROP:
      ddl_drop_table (qi, tree->_.op.arg_1);
      break;

    case SET_PASS_STMT:
    case CREATE_USER_STMT:
    case DELETE_USER_STMT:
    case SET_GROUP_STMT:
    case ADD_GROUP_STMT:
    case DELETE_GROUP_STMT:
    case GRANT_STMT:
    case REVOKE_STMT:
    case GRANT_ROLE_STMT:
    case REVOKE_ROLE_STMT:
    case CREATE_ROLE_STMT:
    case DROP_ROLE_STMT:
      sec_stmt_exec (qi, tree);
      break;
#ifdef BIF_XML
    case XML_VIEW:
      {
	xml_view_t *xv = (xml_view_t *)tree;
	if (NULL == xv->xv_local_name)
	  GPF_T;
	xmls_proc (qi, tree->_.view_def.name);
      }
      /* continue in the VIEW_DEF case */
#endif
    case VIEW_DEF:
      ddl_store_view (qi, tree);
      break;
    case UDT_DEF:
      udt_exec_class_def (qi, tree);
      break;
    case UDT_DROP:
      udt_drop_class_def (qi, tree);
      break;
    case UDT_ALTER:
      udt_alter_class_def (qi, tree);
      break;

    case CREATE_TABLE_AS:
      sch_create_table_as (qi, tree);
      break;
    case CLUSTER_DEF:
    case PARTITION_DEF:
      sch_cluster_stmt (qi, tree);
      break;
    default:
      sqlr_new_error ("42000", "SQ031", "Unsupported DDL statement.");
    }
#ifdef VIRTTP
  IN_TXN;
  memcpy (&(qi->qi_trx->lt_2pc), &(lt_save.lt_2pc), sizeof (lt_save.lt_2pc));
#ifdef _2PC_DDL_TRACE
  _2pc_printf(("sql_ddl_node_input restore lt_status=%d cli_tp_data=%p %p\n",
	qi->qi_trx->lt_status,
	qi->qi_client->cli_tp_data,
	qi->qi_trx));
#endif
  LEAVE_TXN;
#endif
}

void
sql_ddl_node_input (ddl_node_t * ddl, caddr_t * inst, caddr_t * state)
{
  query_instance_t *qi = (query_instance_t *) inst;
  caddr_t repl = box_copy_tree ((box_t) qi->qi_trx->lt_replicate);
  qi->qi_trx->lt_replicate = box_copy_tree ((box_t) qi->qi_client->cli_replicate);

  QR_RESET_CTX
    {
      sql_ddl_node_input_1 (ddl, inst, state);
    }
  QR_RESET_CODE
    {
      caddr_t err = NULL;
      POP_QR_RESET;
      err = thr_get_error_code (THREAD_CURRENT_THREAD);
      qi->qi_trx->lt_replicate = (caddr_t *)repl;
      sqlr_resignal (err);
    }
  END_QR_RESET;
  qi->qi_trx->lt_replicate = (caddr_t *)repl;
}

const char *proc_dd_text =
"(seq "
"(create_table SYS_VIEWS (V_SCH varchar V_NAME varchar V_TEXT varchar V_EXT blob V_OWNER varchar) )"
"(create_unique_index SYS_VIEWS on SYS_VIEWS (V_NAME) contiguous)"

"(create_table SYS_PROCEDURES (P_QUAL varchar P_NAME varchar P_TEXT varchar P_MORE blob"
"	    P_OWNER varchar P_N_IN integer P_N_OUT integer P_N_R_SETS integer P_TYPE integer P_COMMENT varchar))"
"(create_unique_index SYS_PROCEDURES on SYS_PROCEDURES (P_QUAL P_NAME) contiguous)"

"(create_table SYS_TRIGGERS (T_SCH varchar T_TABLE varchar T_NAME varchar T_TEXT varchar T_MORE blob T_TYPE integer T_TIME integer))"
"(create_unique_index SYS_TRIGGERS  on SYS_TRIGGERS (T_SCH T_TABLE T_NAME) contiguous)"

/*"(create_table SYS_USERS (U_NAME varchar U_PASSWORD varchar U_GROUP integer U_ID integer U_DATA varchar))"
"(create_unique_index SYS_USERS on SYS_USERS  (U_NAME) contiguous)"
"(create_index SYS_USERS_ID on SYS_USERS  (U_ID) contiguous)"*/

"(create_table SYS_GRANTS (G_USER integer G_OP integer G_OBJECT varchar G_COL varchar G_GRANTOR varchar G_ADMIN_OPT varchar))"
"(create_unique_index SYS_GRANTS on SYS_GRANTS (G_USER G_OP G_OBJECT G_COL) contiguous)"

"(create_table SYS_CONSTRAINTS (C_TABLE varchar C_ID integer C_TEXT varchar C_MODE blob))"
"(create_unique_index SYS_CONSTRAINTS on SYS_CONSTRAINTS (C_TABLE C_ID) contiguous)"

"(create_table SYS_PROC_COLS (P_QUAL varchar P_NAME varchar P_COL varchar P_TYPE integer "
"				 P_DEF integer P_SCALE integer P_INOUT integer))"

"(create_unique_index SYS_PROC_COLS on SYS_PROC_COLS (P_QUAL P_NAME P_COL) contiguous)"

"(create_table SYS_METHODS (M_ID integer M_OFS integer M_NAME varchar M_TEXT blob"
"	    M_OWNER varchar M_QUAL varchar M_COMMENT varchar"
"           ))"
"(create_unique_index SYS_METHODS on SYS_METHODS (M_ID M_OFS) contiguous)"

"(end))";

const char *sys_sql_inverse_dd_text =
"(seq "
"(create_table SYS_SQL_INVERSE ("
"           SINV_FUNCTION varchar "
"           SINV_ARGUMENT integer "
"           SINV_INVERSE varchar "
"           SINV_FLAGS  integer))"
"(create_unique_index SYS_SQL_INVERSE on SYS_SQL_INVERSE (SINV_FUNCTION SINV_ARGUMENT) contiguous)"

"(end))";

const char *sys_users_dd_text =
"create table SYS_USERS ("
"    U_ID 		integer,"
"    U_NAME 		char (128),"
"    U_IS_ROLE		integer 	default 0,"
"    U_FULL_NAME 	char (128),"
"    U_E_MAIL 		char (128) 	default '',"
"    U_PASSWORD		char (128),"
"    U_GROUP 		integer,"  	/* the primary group references SYS_USERS (U_ID), */
"    U_LOGIN_TIME 	datetime,"
"    U_ACCOUNT_DISABLED integer 	default 1,"
"    U_DAV_ENABLE	integer		default 0,"
"    U_SQL_ENABLE	integer 	default 1,"
"    U_DATA		varchar," 	/* login qual */
"    U_METHODS 		integer,"
"    U_DEF_PERMS 	char (11) 	default '110100000RR',"
"    U_HOME		varchar (128),"
"    U_PASSWORD_HOOK 	varchar, "
"    U_PASSWORD_HOOK_DATA varchar, "
"    U_GET_PASSWORD	varchar, "
"    U_DEF_QUAL		varchar default NULL, "
"    U_OPTS		long varchar,"
"    primary key (U_NAME)"
" ) "
"create unique index SYS_USERS_ID on SYS_USERS (U_ID)"
;

void
local_start_trx (client_connection_t * cli)
{
  IN_TXN;
  cli_set_new_trx (cli);
  cli->cli_trx->lt_replicate = REPL_NO_LOG;
  lt_threads_set_inner (cli->cli_trx, 1);
  LEAVE_TXN;
}

void
local_commit_end_trx (client_connection_t * cli)
{
  IN_TXN;
  lt_threads_set_inner (cli->cli_trx, 1);
  lt_commit (cli->cli_trx, TRX_CONT);
  lt_threads_set_inner (cli->cli_trx, 0);
  LEAVE_TXN;
}

void
local_rollback_end_trx (client_connection_t * cli)
{
  IN_TXN;
  lt_threads_set_inner (cli->cli_trx, 1);
  lt_rollback (cli->cli_trx, TRX_CONT);
  lt_threads_set_inner (cli->cli_trx, 0);
  LEAVE_TXN;
}

const char *upd_sys_trigger_table_text_0 =
"create procedure __SYS_UPGRADE_SYS_TRIGGERS_T_TYPE_T_TIME ()\n"
"{\n"
"  declare is_to_upgrade integer;\n"
"\n"
"  is_to_upgrade := 0;\n"
"  if (not exists (select 1 from DB.DBA.SYS_COLS\n"
"      where \"TABLE\" = 'SYS_TRIGGERS' and \"COLUMN\" = 'T_TYPE'))\n"
"    {\n"
"      log_message ('upgrading the SYS_TRIGGERS table : adding T_TYPE');\n"
"      exec ('alter table SYS_TRIGGERS add T_TYPE integer');\n"
"      is_to_upgrade := 1;\n"
"    }\n"
"  if (not exists (select 1 from DB.DBA.SYS_COLS\n"
"      where \"TABLE\" = 'SYS_TRIGGERS' and \"COLUMN\" = 'T_TIME'))\n"
"    {\n"
"      log_message ('upgrading the SYS_TRIGGERS table : adding T_TIME');\n"
"      exec ('alter table SYS_TRIGGERS add T_TIME integer');\n"
"      is_to_upgrade := 1;\n"
"    }\n"
"\n"
"  if (is_to_upgrade or 1)\n"
"    {\n"
"-- T_TYPE : 0=update 1=insert 2=delete\n"
"-- T_TIME : 0=before 1=after 2=instead\n"
"      declare proc_text varchar;\n"
"      proc_text := 'create procedure __SYS_UPGRADE_SYS_TRIGGERS_T_TYPE_T_TIME_DYN () returns integer {\n"
"         declare msg_done integer;\n"
"	  declare cr cursor for\n"
"	    select COALESCE (T_TEXT, T_MORE)\n"
"	      from SYS_TRIGGERS\n"
"	      where T_TYPE is NULL or T_TIME is NULL;\n"
"\n"
"	  whenever not found goto done;\n"
"         msg_done := 0;\n"
"\n"
"	  open cr (exclusive, prefetch 1);\n"
"	  while (1 = 1)\n"
"	    {\n"
"	      declare _text varchar;\n"
"	      declare _parse_tree any;\n"
"	      fetch cr into _text;\n"
"\n"
"	      _parse_tree := sql_parse (blob_to_string (_text));\n"
"\n"
"	      declare _action_time, _event integer;\n"
"	      _action_time := _parse_tree[2];\n"
"	      _event := _parse_tree[3];\n"
"	      if (isarray (_event))\n"
"		_event := 0; -- update is coded as a list of columns\n"
"\n"
"	      update SYS_TRIGGERS set T_TYPE = _event, T_TIME = _action_time where current of cr;\n"
"             msg_done := msg_done + 1;\n"
"	    }\n"
"	done:\n"
"	  close cr;\n"
"         return msg_done;\n"
"	}';\n"
"      declare _desc, _rows any;\n"
"      exec ('explain (?)', NULL, NULL, vector (proc_text), 0, _desc, _rows);\n"
"      if (__SYS_UPGRADE_SYS_TRIGGERS_T_TYPE_T_TIME_DYN () > 0)\n"
"        log_message ('upgrading the SYS_TRIGGERS table : completed');\n"
"    }\n"
"}\n";

const char *upd_sys_trigger_table_text_1 =
"create procedure __SYS_TRIGGERS_MAKE_DECOYS_SEUID (in _txt varchar, in _uid varchar, in _qual varchar)\n"
"{\n"
"  __set_user_id (_uid);\n"
"  set_qualifier (_qual);\n"
"  declare _desc, _rows any;\n"
/*"  dbg_obj_print (_txt);\n"*/
"  exec ('explain (?)', null, null, vector (_txt),  0, _desc, _rows);\n"
"}\n";

const char *upd_sys_trigger_table_text_2 =
"create procedure __SYS_TRIGGERS_MAKE_DECOYS ()\n"
"{\n"
"-- T_TYPE : 0=update 1=insert 2=delete\n"
"-- T_TIME : 0=before 1=after 2=instead\n"
"  for (select T_TYPE, T_TIME, T_NAME, T_TABLE, T_SCH from DB.DBA.SYS_TRIGGERS) do\n"
"    {\n"
"      declare _txt varchar;\n"
"      _txt := sprintf (\n"
"	'create trigger \"%I\" %s %s on \"%I\".\"%I\".\"%I\" { signal (''42000'', ''Undefined trigger''); }',\n"
"	name_part (T_NAME, 2),\n"
"	case T_TIME\n"
"	  when 0 then 'before'\n"
"	  when 1 then 'after'\n"
"	  when 2 then 'instead of'\n"
"	  else 'nonsense'\n"
"	end,\n"
"	case T_TYPE\n"
"	  when 0 then 'update'\n"
"	  when 1 then 'insert'\n"
"	  when 2 then 'delete'\n"
"	  else 'nonsense'\n"
"	end,\n"
"	name_part (T_TABLE, 0),\n"
"	name_part (T_TABLE, 1),\n"
"	name_part (T_TABLE, 2));\n"
"      DB.DBA.__SYS_TRIGGERS_MAKE_DECOYS_SEUID (_txt, name_part (T_NAME, 1), T_SCH);\n"
"    }\n"
"  set_qualifier ('DB');\n"
/*"  dbg_obj_print ('done user=', user, 'qual=', dbname());\n"*/
"}\n";

static void
ddl_upd_trigger_table (void)
{
  caddr_t org_qual = bootstrap_cli->cli_qualifier;

  bootstrap_cli->cli_qualifier = box_string (org_qual);
  ddl_standard_procs ();
  ddl_std_proc (upd_sys_trigger_table_text_0, 0);
  ddl_ensure_table ("do this always", "DB.DBA.__SYS_UPGRADE_SYS_TRIGGERS_T_TYPE_T_TIME ()");
  ddl_std_proc (upd_sys_trigger_table_text_1, 1);
  ddl_std_proc (upd_sys_trigger_table_text_2, 2);
  ddl_ensure_table ("do this always", "DB.DBA.__SYS_TRIGGERS_MAKE_DECOYS ()");
  dk_free_box (bootstrap_cli->cli_qualifier);
  bootstrap_cli->cli_qualifier = org_qual;
}


void
local_commit (client_connection_t * cli)
{
  IN_TXN;
  lt_threads_set_inner (cli->cli_trx, 1);
  lt_commit (cli->cli_trx, TRX_CONT);
  cli->cli_trx->lt_replicate = REPL_NO_LOG;
  LEAVE_TXN;
}


#define HANDLE_S_QUAL(q) if (0 == strcmp (q, "S")) q = "DB"


static const char proc_XML_VIEW_DROP_PROCS[] =
" create procedure XML_VIEW_DROP_PROCS (in view_name varchar, in on_bootstrap integer := 0) \n"
" { \n"
"   declare _p_name varchar; \n"
"   declare _procprefix varchar; \n"
"   view_name := cast (view_name as varchar); \n"
"   _procprefix := concat (name_part (view_name, 0), \'.\', name_part (view_name, 1), \'.\'); \n"
"   declare pr cursor for select P_NAME from DB.DBA.SYS_PROCEDURES  \n"
"       where P_NAME like concat (_procprefix, \'http_\', name_part (view_name, 2), \'_t%\') \n"
"       or P_NAME like concat (_procprefix, \'xte_\', name_part (view_name, 2), \'_t%\') \n"
"       or P_NAME = concat (_procprefix, \'http_view_\', name_part (view_name, 2)) \n"
"       or P_NAME = concat (_procprefix, \'xte_view_\', name_part (view_name, 2)) \n"
"       or P_NAME = concat (_procprefix, \'xmlg_\', name_part (view_name, 2)) \n"
"       for update; \n"
"   if ((not on_bootstrap) and not exists (select 1 from SYS_VIEWS where \n"
"       V_NAME = view_name or \n"
"       V_NAME = concat (_procprefix, name_part (view_name, 2)) ) ) \n"
"     signal (\'S1000\', concat (\'The XML view \'\'\', view_name, \'\'\' does not exist\')); \n"
"  \n"
"   whenever not found goto nf; \n"
"   open pr; \n"
"   while (1)    \n"
"     { \n"
"       fetch pr into _p_name; \n"
"       if (__proc_exists(_p_name) is not null) \n"
"         { \n"
"	    if (on_bootstrap) \n"
"             { \n"
"               delete from DB.DBA.SYS_PROCEDURES where P_NAME = _p_name;\n"
"               delete from DB.DBA.SYS_GRANTS where G_OBJECT = _p_name and G_OP = 32; \n"
"               { declare exit handler for sqlstate '*' { ; }; \n"
"                 delete from DB.DBA.SYS_XPF_EXTENSIONS where XPE_PNAME = _p_name; } \n"
"               __drop_proc (_p_name, 1);\n"
"             } \n"
"           else \n"
"             ddl_drop_proc (_p_name); \n"
"         } \n"
"       else \n"
"         delete from DB.DBA.SYS_PROCEDURES where current of pr; \n"
"     } \n"
" nf: \n"
"   close pr; \n"
" } \n";


void
ddl_read_views (void)
{
  char owner[MAX_NAME_LEN];
  char v_q[MAX_NAME_LEN];
  char v_n[MAX_NAME_LEN];
  user_t *owner_user;
  caddr_t err = NULL;
  local_cursor_t *lc;
  query_t *qr;
  int first_run = 1;
  user_t *org_user = bootstrap_cli->cli_user;
  caddr_t org_qual = bootstrap_cli->cli_qualifier;

#ifdef BIF_XML
  if (!xml_global)
    xml_global = xs_allocate();
#endif

  {
    char *full_name = sch_full_proc_name (isp_schema(NULL), "XML_VIEW_DROP_PROCS",
	bootstrap_cli->cli_qualifier, CLI_OWNER (bootstrap_cli));
    if (NULL == full_name || NULL == sch_proc_def (isp_schema(NULL), full_name))
      ddl_std_proc_1 (proc_XML_VIEW_DROP_PROCS, 0x1, 1);
  }

  qr = sql_compile_static ("select V_SCH, V_NAME, coalesce (V_TEXT, blob_to_string (V_EXT)) from DB.DBA.SYS_VIEWS",
      bootstrap_cli, NULL, SQLC_DEFAULT);
  if (!qr)
     {
       log_error ("Internal error loading declarations of views and mapping schemas.");
       return;
     }

again:
  qr_quick_exec (qr, bootstrap_cli, "q", &lc, 0);
  CLI_QUAL_ZERO (bootstrap_cli);
  while (lc_next (lc))
    {
      int text_is_reload;
      query_t *view_qr;
      char *text = lc_nth_col (lc, 2);
      char *qual = lc_nth_col (lc, 0);
      char *name = lc_nth_col (lc, 1);
      err = NULL;
      text_is_reload = (text == strstr (text, "xml_reload_mapping_schema_decl"));
      sch_split_name ("", name, v_q, owner, v_n);
      if ((0 == strcmp (owner, "DBA")) || ('\0' == owner[0]))
	strcpy_ck (owner, "dba");
      CLI_SET_QUAL (bootstrap_cli, qual);
      owner_user = sec_name_to_user (owner);
      if (owner_user)
	bootstrap_cli->cli_user = owner_user;
      else if (0 != strcmp (owner, "INFORMATION_SCHEMA"))
	{
	  log_error ("View '%s' is owned by unknown user '%s'", name, owner);
	}
      if (!text_is_reload && !first_run)
        continue;
      view_qr = sql_compile (text, bootstrap_cli, &err, SQLC_DO_NOT_STORE_PROC);
      if (err)
	{
	  if (strlen (text) > 60)
	    text[59] = 0;
	  log_error ("Error compiling definition of %s '%s': %s: %s\n%s",
	      (text_is_reload ? "mapping schema" : "view"), name,
	      ((caddr_t *) err)[QC_ERRNO], ((caddr_t *) err)[QC_ERROR_STRING],
	      text);
	}
      if (view_qr)
        {
	  if (text_is_reload) /* otherwise qr not needed. View def'd inside sql_compile */
	    {


	      local_cursor_t *view_lc;
	      caddr_t err = NULL;
		/* log_error ("EXEC %s %s %s\n", (first_run ? "First run" : "Second run"), (text_is_reload ? "reload" : "create"), name); */
	      err = qr_quick_exec (view_qr, bootstrap_cli, "q", &view_lc, 0);
	      if (err)
	        {
		  log_error ("Error reloading declaration of the mapping schema %s: [%s]: %.200s",
		  name, ERR_STATE (err), ERR_MESSAGE (err) );
		}
	      while (lc_next (view_lc));
	      lc_free (view_lc);
	    }
	  qr_free (view_qr);
	}
    }
  bootstrap_cli->cli_user = org_user;
  CLI_RESTORE_QUAL (bootstrap_cli, org_qual);
  lc_free (lc);
  if (first_run)
    {
      first_run = 0;
      goto again;
    }
  qr_free (qr);
}


static void
ddl_patch_triggers (void)
{
  dbe_table_t *tb = sch_name_to_table (wi_inst.wi_schema, "DB.DBA.SYS_TRIGGERS");
  if (tb)
    {
      dbe_column_t *col = tb_name_to_column (tb, "T_MORE");
      if (col)
	col->col_sqt.sqt_dtp = DV_BLOB;
    }
}

/* extract username from trigger name or if it not defined then extract from table ,
   if both failed or user does not exist the effective owner is DBA */
const char * trig_owner_proc_txt =
" create procedure DB.DBA.TRIG_OWNER (in name varchar, in tb varchar) \n"
" { \n"
"   declare own varchar; \n"
"   own := name_part (name, 1, null); \n"
"   if (own is null) \n"
"     own := name_part (tb, 1, null); \n"
"   if (own is null or not exists (select 1 from DB.DBA.SYS_USERS where U_NAME = own)) \n"
"     own := \'DBA\'; \n"
"   return own; \n"
" } \n";

char *find_repl_account_in_src_text (char **src_text_ptr)
{
  char *repl = NULL;
  if (0 == strncmp (src_text_ptr[0], "__repl", 6))
    {
      static char *marks[] = {"create ", "#line", "#pragma", "--", "/*", NULL};
      char **mark_ptr;
      char *best_hit = NULL;
      repl = src_text_ptr[0] + 7 /* = strlen ("__repl") + space */;
      for (mark_ptr = marks; NULL != mark_ptr[0]; mark_ptr++)
	{
	  char *hit = (char *)nc_strstr ((unsigned char *) repl, (unsigned char *) mark_ptr[0]);
	  if (NULL == hit)
	    continue;
	  if ((NULL == best_hit) || (hit < best_hit))
	    best_hit = hit;
	}
      if (NULL == best_hit)
	return NULL;	/* No correct __repl */
      best_hit [-1] = '\0';
      src_text_ptr[0] = best_hit;
      return repl;
    }
  return NULL;
}


caddr_t
safe_blob_to_string (lock_trx_t * lt, caddr_t bhp, caddr_t *err_ret)
{
  caddr_t ret = NULL;
  QR_RESET_CTX
  {
    ret = blob_to_string (lt, bhp);
  }
  QR_RESET_CODE
  {
    caddr_t err;
    POP_QR_RESET;
    err = thr_get_error_code (THREAD_CURRENT_THREAD);
    if (err_ret)
      {
	*err_ret = err;
	return NULL;
      }
    else
      sqlr_resignal (err);
  }
  END_QR_RESET;

  return ret;
}


void
ddl_read_constraints (char *spec_tb_name, caddr_t *qst)
{
  static query_t *rdproc_t = NULL, *rdproc_a = NULL;
  static query_t *rdproc;
  local_cursor_t *lc = NULL;
  char curr_tb_name[2*MAX_QUAL_NAME_LEN];
  query_instance_t *qi = (query_instance_t *) qst;
  ST *check_cond = NULL;

  if (!rdproc_t)
    rdproc_t = sql_compile_static (
	"select C_TABLE, deserialize (blob_to_string (C_MODE)) from DB.DBA.SYS_CONSTRAINTS "
	"where C_TABLE = ? order by C_TABLE, C_ID",
	bootstrap_cli, NULL, SQLC_DEFAULT);
  if (!rdproc_a)
    rdproc_a = sql_compile_static (
	"select C_TABLE, deserialize (blob_to_string (C_MODE)) from DB.DBA.SYS_CONSTRAINTS "
	"order by C_TABLE, C_ID",
	bootstrap_cli, NULL, SQLC_DEFAULT);

  if (spec_tb_name)
    {
      strncpy (curr_tb_name, spec_tb_name, sizeof (curr_tb_name));
      rdproc = rdproc_t;
    }
  else
    {
      curr_tb_name[0] = 0;
      rdproc = rdproc_a;
    }

  if (spec_tb_name)
    qr_rec_exec (rdproc, qi->qi_client, &lc, qi, NULL, 1,
	":0", spec_tb_name, QRP_STR);
  else
    qr_quick_exec (rdproc, bootstrap_cli, "q", &lc, 0);
  while (lc_next (lc))
    {
      char *tb_name = lc_nth_col (lc, 0);
      ST *cond = (ST *) lc_nth_col (lc, 1);

      if (!curr_tb_name[0])
	strncpy (curr_tb_name, tb_name, sizeof (curr_tb_name));
      else if (strcmp (curr_tb_name, tb_name))
	{
	  ddl_table_check_constraints_define_triggers (qi, tb_name, check_cond);
	  check_cond = NULL;
	  strncpy (curr_tb_name, tb_name, sizeof (curr_tb_name));
	}

      cond = listst (3, BOP_NOT, box_copy_tree ((box_t) cond), NULL);
      if (!check_cond)
	check_cond = cond;
      else
	check_cond = (ST *) listst (4, BOP_OR, check_cond, cond, NULL);
    }
  lc_free (lc);
  if (check_cond || spec_tb_name)
    ddl_table_check_constraints_define_triggers (qi, curr_tb_name, check_cond);
}

dk_set_t triggers_to_redo = NULL;

void
ddl_redo_undefined_triggers ()
{
  caddr_t * trigs;
  user_t *org_user = bootstrap_cli->cli_user;
  caddr_t org_qual = bootstrap_cli->cli_qualifier;
  caddr_t err;
  query_t *rdproc;
  local_cursor_t *lc;
  int inx;

  if (!triggers_to_redo) 
    return;
  trigs = (caddr_t *) list_to_array (dk_set_nreverse (triggers_to_redo));
  triggers_to_redo = NULL;
  sqlc_set_client (NULL);
  rdproc = sql_compile_static (
      "select T_TEXT, T_MORE, T_SCH, DB.DBA.TRIG_OWNER (T_NAME, T_TABLE), T_NAME, T_TABLE from DB.DBA.SYS_TRIGGERS where T_NAME = ? and T_TABLE = ?",
      bootstrap_cli, NULL, SQLC_DEFAULT);

  if (!rdproc)
    goto end;

  DO_BOX (caddr_t *, rec, inx, trigs)
    {
      caddr_t ttable = rec[0], tname = rec[1];
      trigs[inx] = NULL;
      lc = NULL;
      qr_quick_exec (rdproc, bootstrap_cli, "q", &lc, 2, ":0", tname, QRP_RAW, ":1", ttable, QRP_RAW);
      CLI_QUAL_ZERO (bootstrap_cli);
      if (lc_next (lc))
	{
	  char *full_text = NULL;
	  char *short_text = lc_nth_col (lc, 0);
	  char *long_text = lc_nth_col (lc, 1);
	  char *qual = lc_nth_col (lc, 2);
	  char *owner = lc_nth_col (lc, 3);
	  char *t_name = lc_nth_col (lc, 4);
	  char *t_table = lc_nth_col (lc, 5);
	  user_t *owner_user = sec_name_to_user (owner);
	  if (owner_user)
	    bootstrap_cli->cli_user = owner_user;
	  else
	    log_error ("Trigger %s on %s with bad owner, owner =  %s", t_name, t_table, owner);
	  err = NULL;
	  CLI_SET_QUAL (bootstrap_cli, qual);
	  if (IS_BLOB_HANDLE (long_text))
	    {
	      caddr_t err2 = NULL;
	      full_text = safe_blob_to_string (bootstrap_cli->cli_trx, long_text, &err2);
	      if (err2)
		{
		  log_error (
		      "Error reading trigger %s on %s body: %s: %s."
		      "It will not be defined. Drop the trigger and recreate it.",
		      t_name, t_table,
		      ((caddr_t *) err2)[QC_ERRNO], ((caddr_t *) err2)[QC_ERROR_STRING]);
		  dk_free_tree (err2);
		  continue;
		}
	      sql_compile (full_text, bootstrap_cli, &err, SQLC_DO_NOT_STORE_PROC);
	    }
	  else
	    {
	      if (DV_STRINGP (long_text))
		{
		  short_text = long_text;
		  long_text = NULL;
		}
	      sql_compile (short_text, bootstrap_cli, &err, SQLC_DO_NOT_STORE_PROC);
	    }
	  if (err)
	    {
	      if (full_text && strlen (full_text) > 60)
		full_text[59] = 0;
	      if (short_text && strlen (short_text) > 60)
		short_text[59] = 0;
	      if (0 == strcmp (ERR_STATE (err), "37000") && NULL != strstr (ERR_MESSAGE (err), "SPARQL compiler: Quad storage")) /* quad store is not inited */
		{
		  dk_set_push (&triggers_to_redo, list (2, box_string (t_table), box_string (t_name)));
		}
	      else
		log_error ("Error compiling trigger %s on %s: %s: %s -- %s", t_name, t_table,
		    ((caddr_t *) err)[QC_ERRNO], ((caddr_t *) err)[QC_ERROR_STRING],
		    full_text ? full_text : short_text);
	    }
	  dk_free_box (full_text);
	}
      lc_free (lc);
    }
  END_DO_BOX;
  qr_free (rdproc);

end:;
  dk_free_box (trigs);  
  bootstrap_cli->cli_user = org_user;
  CLI_RESTORE_QUAL (bootstrap_cli, org_qual);
  local_commit (bootstrap_cli);
}

void
read_proc_and_trigger_tables (int remotes)
{
  user_t *org_user = bootstrap_cli->cli_user;
  caddr_t org_qual = bootstrap_cli->cli_qualifier;
  query_t *proc_qr;
  /* Procedure's calls published for replication */
  caddr_t err;
  query_t *rdproc;
  local_cursor_t *lc;
  int reading_user_aggregates = 1;

  sqlc_set_client (NULL);
  ddl_patch_triggers ();
  ddl_std_proc (trig_owner_proc_txt, 0x0); /* compile procedure for extracting a owner of trigger */
  if (remotes)
    rdproc = sql_compile_static (
	"select P_TEXT, P_MORE, P_OWNER, P_QUAL, P_TYPE, P_NAME from DB.DBA.SYS_PROCEDURES where P_TYPE = 1",
	bootstrap_cli, NULL, SQLC_DEFAULT);
  else
    rdproc = sql_compile_static ("select P_TEXT, P_MORE, P_OWNER, P_QUAL, P_TYPE, P_NAME from DB.DBA.SYS_PROCEDURES",
	bootstrap_cli, NULL, SQLC_DEFAULT);
  if (!rdproc)
    goto end;

  if (!remotes)
    {
      ddl_read_views ();
      QR_RESET_CTX
	{
	  ddl_read_constraints (NULL, NULL);
	}
      QR_RESET_CODE
	{
	  caddr_t err;
	  POP_QR_RESET;
	  err = thr_get_error_code (THREAD_CURRENT_THREAD);
	  log_error ("Error compiling CHECK constraint: %s: %s",
	      ((caddr_t *) err)[QC_ERRNO], ((caddr_t *) err)[QC_ERROR_STRING]);
	  dk_free_tree (err);
	}
      END_QR_RESET;
      ddl_upd_trigger_table ();
    }


scan_SYS_PROCEDURES:

  qr_quick_exec (rdproc, bootstrap_cli, "q", &lc, 0);
  CLI_QUAL_ZERO (bootstrap_cli);
  while (lc_next (lc))
    {
      caddr_t src_text = NULL;
      caddr_t src_text_to_free = NULL;
      char *p_text = lc_nth_col (lc, 0);
      char *p_more = lc_nth_col (lc, 1);
      char *owner = lc_nth_col (lc, 2);
      user_t *owner_user = sec_name_to_user (owner);
      char *qual = lc_nth_col (lc, 3);
      caddr_t p_type_box = lc_nth_col (lc, 4);
      long p_type = DV_TYPE_OF (p_type_box) == DV_LONG_INT ? (long) unbox (p_type_box) : 0;
      caddr_t p_name = lc_nth_col (lc, 5);
  /* Procedure's calls published for replication */
      err = NULL;
      HANDLE_S_QUAL (qual);
      CLI_SET_QUAL (bootstrap_cli, qual);
      if (owner_user)
	bootstrap_cli->cli_user = owner_user;
      else
	{
	  log_error ("Procedure with bad owner, owner =  %s", owner);
	}
      if (IS_BLOB_HANDLE (p_more))
	{
	  caddr_t err = NULL;
	  src_text = src_text_to_free = safe_blob_to_string (bootstrap_cli->cli_trx, p_more, &err);
	  if (err)
	    {
	      log_error (
		  "Error reading stored procedure body for %s: %s: %s."
		  "It will not be defined. Drop the procedure and recreate it.", p_name,
		  ((caddr_t *) err)[QC_ERRNO], ((caddr_t *) err)[QC_ERROR_STRING]);
	      dk_free_tree (err);
	      continue;
	    }
	}
      else if (DV_STRINGP (p_more))
	{
	  src_text = p_more;
	}
      else
	src_text = p_text;
				 /*0         1         2         3    */
				 /*01234567890123456789012345678901234*/
      if (!remotes)
	{
	  if (0 == strncmp (src_text, "--#pragma bootstrap user-aggregate", 34))
	    {
	      if (!reading_user_aggregates)
		{
		  dk_free_box (src_text_to_free);
		  continue;
		}
	    }
	  else
	    {
	      if (reading_user_aggregates)
		{
		  dk_free_box (src_text_to_free);
		  continue;
		}
	    }
	}
  /* Procedure's calls published for replication */
      if (p_type == 3 || reading_user_aggregates) /* is module or user aggr */
	proc_qr = sql_compile (src_text, bootstrap_cli, &err, SQLC_DO_NOT_STORE_PROC);
      else
	{
	  if (NULL == (proc_qr = sql_proc_to_recompile (src_text, bootstrap_cli, p_name, 0)))
	    proc_qr = sql_compile (src_text, bootstrap_cli, &err, SQLC_DO_NOT_STORE_PROC);
	}

      if (err)
	{
	  if (src_text && strlen (src_text) > 60)
	    strcpy_size_ck (src_text+57, "...", box_length (src_text) - 57);
	  log_error ("Error compiling stored procedure: %s: %s -- %s",
	      ((caddr_t *) err)[QC_ERRNO], ((caddr_t *) err)[QC_ERROR_STRING],
	      src_text);
	}
	/*XXX: this must be set in sql_compile */
/*      else
	{
	  if (owner_user && proc_qr)
	    proc_qr->qr_proc_owner = owner_user->usr_id;
	}*/
       dk_free_box (src_text_to_free);
    }
  bootstrap_cli->cli_user = org_user;
  CLI_RESTORE_QUAL (bootstrap_cli, org_qual);
  lc_free (lc);

  if (remotes)
    {
      qr_free (rdproc);
      goto end;
    }

  if (reading_user_aggregates)
    {
      reading_user_aggregates = 0;
      goto scan_SYS_PROCEDURES;
    }

  qr_free (rdproc);

  rdproc = sql_compile_static (
      "select T_TEXT, T_MORE, T_SCH, DB.DBA.TRIG_OWNER (T_NAME, T_TABLE), T_NAME, T_TABLE from DB.DBA.SYS_TRIGGERS",
      bootstrap_cli, NULL, SQLC_DEFAULT);
  if (!rdproc)
    goto end;

  qr_quick_exec (rdproc, bootstrap_cli, "q", &lc, 0);
  CLI_QUAL_ZERO (bootstrap_cli);
  while (lc_next (lc))
    {
      char *full_text = NULL;
      char *short_text = lc_nth_col (lc, 0);
      char *long_text = lc_nth_col (lc, 1);
      char *qual = lc_nth_col (lc, 2);
      char *owner = lc_nth_col (lc, 3);
      char *t_name = lc_nth_col (lc, 4);
      char *t_table = lc_nth_col (lc, 5);
      user_t *owner_user = sec_name_to_user (owner);
      if (owner_user)
	bootstrap_cli->cli_user = owner_user;
      else
	{
	  log_error ("Trigger %s on %s with bad owner, owner =  %s", t_name, t_table, owner);
	}
      err = NULL;
      proc_qr = NULL;
      CLI_SET_QUAL (bootstrap_cli, qual);
      if (IS_BLOB_HANDLE (long_text))
	{
	  caddr_t err2 = NULL;
	  full_text = safe_blob_to_string (bootstrap_cli->cli_trx, long_text, &err2);
	  if (err2)
	    {
	      log_error (
		  "Error reading trigger %s on %s body: %s: %s."
		  "It will not be defined. Drop the trigger and recreate it.",
		  t_name, t_table,
		  ((caddr_t *) err2)[QC_ERRNO], ((caddr_t *) err2)[QC_ERROR_STRING]);
	      dk_free_tree (err2);
	      continue;
	    }
	  proc_qr = sql_compile (full_text, bootstrap_cli, &err, SQLC_DO_NOT_STORE_PROC);
	}
      else
	{
	  if (DV_STRINGP (long_text))
	    {
	      short_text = long_text;
	      long_text = NULL;
	    }
	  proc_qr = sql_compile (short_text, bootstrap_cli, &err, SQLC_DO_NOT_STORE_PROC);
	}
      if (err)
	{
	  if (full_text && strlen (full_text) > 60)
	    full_text[59] = 0;
	  if (short_text && strlen (short_text) > 60)
	    short_text[59] = 0;
	  if (0 == strcmp (ERR_STATE (err), "37000") && NULL != strstr (ERR_MESSAGE (err), "SPARQL compiler: Quad storage")) /* quad store is not inited */
	    {
	      dk_set_push (&triggers_to_redo, list (2, box_string (t_table), box_string (t_name)));
	    }
	  else
	    log_error ("Error compiling trigger %s on %s: %s: %s -- %s", t_name, t_table,
	      ((caddr_t *) err)[QC_ERRNO], ((caddr_t *) err)[QC_ERROR_STRING],
	      full_text ? full_text : short_text);
	}
      dk_free_box (full_text);
      /*XXX: this must be set in sql_compile */
      /*      else
	      {
	      if (owner_user && proc_qr)
	      proc_qr->qr_proc_owner = owner_user->usr_id;
	      }*/
    }
  lc_free (lc);
  qr_free (rdproc);

end:;
  bootstrap_cli->cli_user = org_user;
  CLI_RESTORE_QUAL (bootstrap_cli, org_qual);
  local_commit (bootstrap_cli);
}

void
read_utd_method_tables (void)
{
  user_t *org_user = bootstrap_cli->cli_user;
  caddr_t org_qual = bootstrap_cli->cli_qualifier;
  query_t *proc_qr;
  /* Procedure's calls published for replication */
  caddr_t err;
  query_t *rdproc;
  local_cursor_t *lc;
  rdproc = sql_compile_static (
      "select blob_to_string (M_TEXT), M_QUAL, M_OWNER from DB.DBA.SYS_METHODS",
      bootstrap_cli, NULL, SQLC_DEFAULT);
  if (!rdproc)
    goto end;

  qr_quick_exec (rdproc, bootstrap_cli, "q", &lc, 0);
  CLI_QUAL_ZERO (bootstrap_cli);
  while (lc_next (lc))
    {
      char *full_text = lc_nth_col (lc, 0);
      char *qual = lc_nth_col (lc, 1);
      char *owner = lc_nth_col (lc, 2);
      user_t *owner_user = sec_name_to_user (owner);
      if (owner_user)
	bootstrap_cli->cli_user = owner_user;
      else
	{
	  log_error ("Method with bad owner, owner =  %s", owner);
	}
      err = NULL;
      proc_qr = NULL;
      CLI_SET_QUAL (bootstrap_cli, qual);
      proc_qr = sql_compile (full_text, bootstrap_cli, &err, SQLC_DO_NOT_STORE_PROC);
      if (err)
	{
	  if (full_text && strlen (full_text) > 60)
	    full_text[59] = 0;
	  log_error ("Error compiling method : %s: %s -- %s",
	      ((caddr_t *) err)[QC_ERRNO], ((caddr_t *) err)[QC_ERROR_STRING],
	      full_text);
	}
    }
  lc_free (lc);
  qr_free (rdproc);

end:;
  bootstrap_cli->cli_user = org_user;
  CLI_RESTORE_QUAL (bootstrap_cli, org_qual);
  local_commit (bootstrap_cli);
}


client_connection_t * recomp_cli;
du_thread_t * recomp_thread;


void
qr_recompile_enter (int * is_entered, caddr_t * err_ret)
{
  client_connection_t * cli = GET_IMMEDIATE_CLIENT_OR_NULL;
  if (THREAD_CURRENT_THREAD == recomp_thread)
    return;
  vdb_enter_lt_1 (cli->cli_trx, err_ret, 0);
  if (err_ret && *err_ret)
    return;
  mutex_enter (recomp_mtx);
  if (!recomp_cli)
    {
      recomp_cli = client_connection_create ();
      recomp_cli->cli_replicate = REPL_NO_LOG;
      recomp_cli->cli_resultset_max_rows = -1;
      local_start_trx (recomp_cli);
      local_commit_end_trx (recomp_cli);
    }
  recomp_thread = THREAD_CURRENT_THREAD;
  *is_entered = 1;
}


void
qr_recompile_leave (int * is_entered, caddr_t * err_ret)
{
  client_connection_t * cli = GET_IMMEDIATE_CLIENT_OR_NULL;
  if (*is_entered)
    {
      recomp_thread = NULL;
      *is_entered = 0;
      mutex_leave (recomp_mtx);
      vdb_leave_lt (cli->cli_trx, err_ret);
    }
}


void
qr_recomp_rdf_inf_init (caddr_t * err_ret)
{
  client_connection_t * cli = GET_IMMEDIATE_CLIENT_OR_NULL;
  if (cli && cli->cli_trx && cli->cli_trx->lt_threads)
    {
      QR_RESET_CTX
	{
	  vdb_enter_lt (cli->cli_trx);
	  cl_rdf_inf_init (recomp_cli, err_ret);
	  vdb_leave_lt (cli->cli_trx, NULL);
	}
      QR_RESET_CODE
	{
	  POP_QR_RESET;
	  *err_ret = RST_ERROR == reset_code ? thr_get_error_code (THREAD_CURRENT_THREAD)
	    : srv_make_new_error ("xxxxx", ".....", "unidentified error in cl rdf inf innit");
	}
      END_QR_RESET;
    }
  else
    cl_rdf_inf_init (recomp_cli, err_ret);
}

query_t *
qr_recompile (query_t * qr, caddr_t * err_ret)
{
  char *owner = qr->qr_owner;
  query_t *new_qr = NULL;
  caddr_t err = NULL;
  user_t *org_user;
  caddr_t org_qual, proc_name = box_copy (qr->qr_proc_name);
  user_t *owner_user;
  dk_set_t old_qr_set = NULL;
  dbe_schema_t *sc;
  int is_entered = 0;
  if (err_ret)
    *err_ret = NULL;
  qr_recompile_enter (&is_entered, err_ret);
  if (err_ret && *err_ret)
    return NULL;
  /* whe should get schema after we got mutex as it can be changed in the meantime */
  sc = wi_inst.wi_schema;
  if (proc_name && !qr->qr_trig_table)
    {
      /* it's possible when procedure is going to be re-compiled to be
	 already re-compiled from other thread, so
	 we are about to check if it's already re-compiled, otherwise
	 a GPF may occur in the other thread */
      new_qr = sch_proc_def (sc, proc_name);
      if (NULL != new_qr && new_qr != qr)
	{
	  dk_free_tree (proc_name);
	  qr_recompile_leave (&is_entered, err_ret);
	  return new_qr;
	}
      else
	{
	  dk_free_tree (proc_name);
	  new_qr = NULL;
	}
    }
  org_user = recomp_cli->cli_user;
  org_qual = recomp_cli->cli_qualifier;
  CLI_QUAL_ZERO (recomp_cli);
  CLI_SET_QUAL (recomp_cli, qr->qr_qualifier);
  if (0 == strcmp (owner, "DBA"))
    owner = "dba";
  owner_user = sec_name_to_user (owner);
  if (!owner_user)
    {
      err = srv_make_new_error ("42000", "SQ032",
	  "Owner of procedure has been deleted. Cannot recompile procedure");
    }
  else
    {
      int cr_type = qr->qr_cursor_type;
      caddr_t text = QR_IS_MODULE_PROC (qr) ?  qr->qr_module->qr_text : qr->qr_text;
      ST * tree = qr->qr_parse_tree_to_reparse ? (ST *)NULL : ((ST *) (QR_IS_MODULE_PROC (qr) ?  qr->qr_module->qr_parse_tree : qr->qr_parse_tree));
      if (cr_type <= _SQL_CURSOR_FORWARD_ONLY)
	cr_type = SQLC_DO_NOT_STORE_PROC;
      recomp_cli->cli_user = owner_user;

      if (QR_IS_MODULE_PROC (qr))
	{
	  id_casemode_hash_iterator_t it;
	  query_t **pproc;

	  id_casemode_hash_iterator (&it, sc->sc_name_to_object[sc_to_proc]);
	  while (id_casemode_hit_next (&it, (caddr_t *) & pproc))
	    {
	      if (!pproc || !*pproc)
		continue;
	      if ((*pproc)->qr_module == qr->qr_module)
		{
		  dk_set_push (&old_qr_set, *pproc);
		  /*sch_set_proc_def (sc, (*pproc)->qr_proc_name, NULL);*
		   *
		   * We will NOT remove the procedure's qr from hash now;
		   * will do this later if error on module.
		   * On this place may lie a concurrent task that procedure is not exists.
		   * So just make it to recompile and recompile semaphore
		   * will serialize operation */
		  (*pproc)->qr_to_recompile = 1;
		}
	    }
	  sch_set_module_def (sc, qr->qr_module->qr_proc_name, NULL);
	}
      if (tree)
        new_qr = sql_compile_1 ("", recomp_cli, &err, cr_type, tree, NULL);
      else
	new_qr = sql_compile (text, recomp_cli, &err, cr_type);
      /* users other than dba cannot execute own procedures after restart */
      /*if (owner_user && new_qr)
	new_qr->qr_proc_owner = owner_user->usr_id;*/
      if (QR_IS_MODULE_PROC (qr))
	new_qr = NULL;
    }

  recomp_cli->cli_user = org_user;
  CLI_RESTORE_QUAL (recomp_cli, org_qual);

  if (QR_IS_MODULE_PROC (qr))
    {
      DO_SET (query_t *, old_mod_qr, &old_qr_set)
	{
	  if (!err)
	    {
	      /* find a new qr corresponding to old by name
	       * and set grants; match the requested qr and set return value
	       * no need to set qr_proc_grants as it's not freed by qr_free */
	      query_t *new_mod_qr = sch_proc_def (sc, old_mod_qr->qr_proc_name);
	      if (new_mod_qr)
		{
		  new_mod_qr->qr_proc_grants = old_mod_qr->qr_proc_grants;
		  if (old_mod_qr == qr)
		    new_qr = new_mod_qr;
		}
	    }
	  else
	    {
	      /* remove all procedures from hash; to ensure consistency of the module */
	      sch_set_proc_def (sc, old_mod_qr->qr_proc_name, NULL);
	    }
	}
      END_DO_SET();
      dk_set_free (old_qr_set);
      if (new_qr)
	{
	  new_qr->qr_module->qr_proc_grants = qr->qr_module->qr_proc_grants;
	  /*sch_set_module_def (sc, new_qr->qr_module->qr_proc_name, new_qr->qr_module);*/
	}
    }

  if (!err && !QR_IS_MODULE_PROC (qr))
    new_qr->qr_proc_grants = qr->qr_proc_grants;

  qr_recompile_leave (&is_entered, err_ret);
  if (err)
    {
      if (strstr (((caddr_t*)err)[2], "RDFNI"))
	{
	  dk_free_tree (err);
	  err = NULL;
	  qr_recomp_rdf_inf_init (&err);
	  if (!err)
	    return qr_recompile (qr, err_ret);
	}
      if (err_ret)
	*err_ret = err;
      else
	sqlr_resignal (err);
      return NULL;
    }
#if defined (MALLOC_DEBUG) || defined (VALGRIND)
  if ((NULL != qr->qr_static_prev) || (NULL != qr->qr_static_next) || (qr == static_qr_dllist))
    {
      static_qr_dllist_append (new_qr, 1);
      new_qr->qr_static_source_file = qr->qr_static_source_file;
      new_qr->qr_static_source_line = qr->qr_static_source_line;
    }
#endif
  return new_qr;
}


void
ddl_init_proc ()
{
  if (!sch_name_to_table (wi_inst.wi_schema, "SYS_PROCEDURES"))
    {
      caddr_t err = NULL;
      query_t *obj_create = eql_compile (proc_dd_text, bootstrap_cli);
      first_id = DD_FIRST_PRIVATE_OID;
      qr_quick_exec (obj_create, bootstrap_cli, "", NULL, 0);

      qr_free (obj_create);
      /* SYS_USERS */
      obj_create = eql_compile_2 (sys_users_dd_text, bootstrap_cli, &err, SQLC_DEFAULT);
      qr_quick_exec (obj_create, bootstrap_cli, "", NULL, 0);

      qr_free (obj_create);
      first_id = DD_FIRST_FREE_OID;
      local_commit (bootstrap_cli);
    }
  if (!sch_name_to_table (wi_inst.wi_schema, "SYS_SQL_INVERSE"))
    {
      query_t *obj_create = eql_compile (sys_sql_inverse_dd_text, bootstrap_cli);
      first_id = DD_FIRST_PRIVATE_OID;
      qr_quick_exec (obj_create, bootstrap_cli, "", NULL, 0);

      qr_free (obj_create);
      first_id = DD_FIRST_FREE_OID;
      local_commit (bootstrap_cli);
    }
}


query_t *proc_st_query;
query_t *proc_rm_duplicate_query;
query_t *cl_proc_rm_duplicate_query;
query_t *proc_revoke_query;
query_t *trig_st_query;

/* Procedure's calls published for replication */

void
ddl_store_proc (caddr_t * state, op_node_t * op)
{
  query_instance_t *qi = (query_instance_t *) QST_INSTANCE (state);
  client_connection_t *cli = qi->qi_client;
  caddr_t err;
  caddr_t db_null = dk_alloc_box (0, DV_DB_NULL);
  char *sch = cli->cli_qualifier;
  char *short_text, *long_text;
  char *text = op->op_code == OP_STORE_PROC
      ? qst_get (state, op->op_arg_2)
      : qst_get (state, op->op_arg_3);
  caddr_t p_type =  op->op_code == OP_STORE_PROC ? qst_get (state, op->op_arg_3) : NULL;
  int is_cl;
/* Procedure's calls published for replication */
  query_t *qr_proc = sch_proc_def (wi_inst.wi_schema,
      (char *) qst_get (state, op->op_arg_1));
  caddr_t escapes_text = NULL;
  char trig_name [MAX_QUAL_NAME_LEN]; /*two-part trigger name*/

  if (!proc_st_query || proc_st_query->qr_to_recompile)
    {
      ddl_ensure_view_table (qi);
      proc_st_query = sql_compile_static ("insert into DB.DBA.SYS_PROCEDURES (P_QUAL, P_OWNER, P_NAME, P_TEXT, P_MORE, P_TYPE) values (?, user, ?, ?, ?, ?)",
	  bootstrap_cli, NULL, SQLC_DEFAULT);
      proc_rm_duplicate_query = sql_compile_static ("delete from DB.DBA.SYS_PROCEDURES where P_NAME = ?",
	      bootstrap_cli, NULL, SQLC_DEFAULT);
      cl_proc_rm_duplicate_query = sql_compile_static ("cl_exec (\'delete from DB.DBA.SYS_PROCEDURES table option (no cluster) where P_NAME = ? option (no cluster)\', params => vector (?), txn=> case when bit_and (log_enable (null, 1), 2) = 2 then 0 else 1 end)",
	      bootstrap_cli, NULL, SQLC_DEFAULT);
      proc_revoke_query = sql_compile_static ("delete from DB.DBA.SYS_GRANTS where G_OBJECT = ? and G_OP = 32",
	      bootstrap_cli, NULL, SQLC_DEFAULT);
    }

  if (!trig_st_query && op->op_code == OP_STORE_TRIGGER)
    {
      trig_st_query = sql_compile_static ("insert replacing DB.DBA.SYS_TRIGGERS (T_SCH, T_TABLE, T_NAME, T_TEXT, T_MORE, T_TYPE, T_TIME) values (?, ?, ?, ?, ?, ?, ?)",
	  bootstrap_cli, NULL, SQLC_DEFAULT);
    }

  if (cli->cli_not_char_c_escape || cli->cli_utf8_execs)
    {
      escapes_text = dk_alloc_box (strlen (text) +
	  (cli->cli_not_char_c_escape ? 18 : 0) +
	  (cli->cli_utf8_execs ? 19 : 0), DV_SHORT_STRING);
      escapes_text[0] = 0;
      if (cli->cli_not_char_c_escape)
	strcat_box_ck (escapes_text, "\n--no_c_escapes+\n");
      if (cli->cli_utf8_execs)
	strcat_box_ck (escapes_text, "\n--utf8_execs=yes\n");
      strcat_box_ck (escapes_text, text);
      text = escapes_text;
    }
  if (strlen (text) > 1500)
    {
      short_text = db_null;
      long_text = text;
    }
  else
    {
      short_text = text;
      long_text = db_null;
    }

  if (op->op_code == OP_STORE_TRIGGER)
    {
      user_t * t_own = NULL;
      caddr_t *trigger_opts = op->op_arg_4 ? (caddr_t *) qst_get (state, op->op_arg_4) : NULL;

      if (qr_proc && qr_proc->qr_proc_owner)
	t_own = sec_id_to_user (qr_proc->qr_proc_owner);
      snprintf (trig_name, sizeof (trig_name), "%s.%s", t_own ? t_own->usr_name : "DBA", qst_get (state, op->op_arg_1));
#ifdef VIRT30_40
      if (is_27_40_incompartible_trigger (trig_name))
        goto skip_incomp;
#endif
      err = qr_rec_exec (trig_st_query, cli, NULL, qi, NULL, 7,
	  ":0", sch, QRP_STR,
	  ":1", qst_get (state, op->op_arg_2), QRP_STR,
	  ":2", trig_name, QRP_STR,
	  ":3", box_copy (short_text), QRP_RAW,
	  ":4", box_copy (long_text), QRP_RAW,
	  ":5", trigger_opts ? box_copy (trigger_opts[0]) : NEW_DB_NULL, QRP_RAW,
	  ":6", trigger_opts ? box_copy (trigger_opts[1]) : NEW_DB_NULL, QRP_RAW);
    }
  else
    {
#ifdef VIRT30_40
      if (is_27_40_incompartible_procedure (qst_get (state, op->op_arg_1)))
        goto skip_incomp;
#endif
      /* first we will remove all entries with the same name,
	 because the PK of that table is not designed to keep only one entry per name */
      is_cl = !cl_run_local_only;
      err = qr_rec_exec (is_cl ? cl_proc_rm_duplicate_query : proc_rm_duplicate_query, cli, NULL, qi, NULL, 1,
			 ":0", qst_get (state, op->op_arg_1), QRP_STR);
      /* the grants also must be removed */
      qr_rec_exec (proc_revoke_query, cli, NULL, qi, NULL, 1,
		   ":0", qst_get (state, op->op_arg_1), QRP_STR);
      /* and if all is OK then will make simple insert */
      if (err == SQL_SUCCESS)
	{
	  err = qr_rec_exec (proc_st_query, cli, NULL, qi, NULL, 5,
	      ":0", sch, QRP_STR,
	      ":1", qst_get (state, op->op_arg_1), QRP_STR,
	      ":2", box_copy (short_text), QRP_RAW,
	      ":3", box_copy (long_text), QRP_RAW,
	      ":4", box_copy (p_type), QRP_RAW);
	}
    }
/* Procedure's calls published for replication */
  dk_free_box (db_null);
  if (escapes_text)
    dk_free_box (escapes_text);
  if (err != SQL_SUCCESS)
    sqlr_resignal (err);
  else
    {
      int proc_op = (op->op_code != OP_STORE_TRIGGER);
      caddr_t *log_array = (caddr_t *) dk_alloc_box ((proc_op ? 2 : 3) * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      log_array[0] = box_string ((proc_op ? "__proc_changed (?)" : "__proc_changed (?, ?)"));
      if (!proc_op)
	{
	  log_array[1] = box_string (trig_name); /*we must log two-part trigger name*/
	  log_array[2] = box_string (qst_get (state, op->op_arg_2));
	}
      else
	log_array[1] = box_string (qst_get (state, op->op_arg_1));
      log_text_array (qi->qi_trx, (caddr_t) log_array);
      dk_free_tree ((box_t) log_array);
      if (proc_op)
	cl_ddl (qi, qi->qi_trx, qst_get (state, op->op_arg_1), CLO_DDL_PROC, NULL);
      else
	cl_ddl (qi, qi->qi_trx, trig_name, CLO_DDL_TRIG, qst_get (state, op->op_arg_2));
    }
  return;

#ifdef VIRT30_40
skip_incomp:
#endif
  dk_free_box (db_null);
  if (escapes_text)
    dk_free_box (escapes_text);
}


void
ddl_drop_trigger (query_instance_t * qi, const char *name)
{
#if 0
  client_connection_t *cli = qi->qi_client;
  query_t *qr = eql_compile ("(seq (from SYS_TRIGGERS (T_TABLE T_NAME) by SYS_TRIGGERS prefix T where ((T_NAME = :N)))"
      "(delete T)(select (T.T_TABLE)))", qi->qi_client);
  local_cursor_t *lc;
  qr_rec_exec (qr, cli, &lc, qi, NULL, 1, ":N", name, QRP_STR);
  while (lc_next (lc))
    {
      char *tn = lc_get_col (lc, "T.TABLE");
      dbe_table_t *tb = qi_name_to_table (qi, tn);
      if (tb)
	trig_drop_def (tb, name);
    }
  lc_free (lc);
  qr_free (qr);
#endif
}



/* Max scale of numeric and decimal was 10, changed to 20 by AK 2-MAR-1997,
   because jdbc-tests whines about it. Of course we have not really
   implemented numbers with twenty decimals after decimal point.
   The precision of long varchar changed from 2000000000 to 2147483647
   (which is (2^31)-1), which is the size of SDWORD 2,147,483,647
   mentioned also in ODBC documents.
   Corrected the order of last two column names, should be MINIMUM_SCALE
   and MAXIMUM_SCALE.

   10-MAR-1997 AK  Changed double to double precision
 */

const char *gti_text =
"create procedure gettypeinfo (in t integer) "
"{"
" gettypeinfo3(t, 0);"
"}";

const char *gti3_text =
"create procedure gettypeinfo3 (in t integer, in odbc3 integer) "
"{"
"  declare TYPE_NAME, LOCAL_TYPE_NAME, CREATE_PARAMS varchar(128); "
"  declare LITERAL_PREFIX, LITERAL_SUFFIX varchar(8); "
"  declare DATA_TYPE,NULLABLE, CASE_SENSITIVE, SEARCHABLE, UNSIGNED_ATTRIBUTES,"
"  AUTO_INCREMENT, MONEY, MAXIMUM_SCALE, MINIMUM_SCALE smallint; "
"  declare \\PRECISION integer; "
"  result_names (TYPE_NAME, DATA_TYPE, \\PRECISION, LITERAL_PREFIX, LITERAL_SUFFIX,"
"		CREATE_PARAMS, NULLABLE, CASE_SENSITIVE, SEARCHABLE, "
"		UNSIGNED_ATTRIBUTES, MONEY, AUTO_INCREMENT, LOCAL_TYPE_NAME,"
"		MINIMUM_SCALE, MAXIMUM_SCALE); "
"  if (t = 1 or t = 0)"
"    result ('character', 1, sys_stat ('db_max_col_bytes'), '''', '''', 'length', 1, 1, 3, 0, 0, 0, 'varchar', NULL, NULL); "
"  if (t = 2 or t = 0) "
"    result ('numeric', 2, 40, '', '', 'precision,scale', 1, 1, 2, 0, 0, 0, 'numeric', 0, 15); "
"  if (t = 3 or t = 0)"
"    result ('decimal', 3, 40, '', '', 'precision,scale', 1, 1, 2, 0, 0, 0, 'decimal', 0, 15); "
"  if (t = 4 or t = 0)"
"    result ('integer', 4, 10, '', '', NULL, 1, 1, 2, 0, 0, 0, 'integer', 0, 10); "
"  if (t = 5 or t = 0)"
"    result ('smallint', 5, 3, '', '', NULL, 1, 1, 2, 0, 0, 0, 'smallint', NULL, NULL); "
"  if (t = -7 or t = 0)"
"    result ('smallint', -7, 3, '', '', NULL, 1, 1, 2, 0, 0, 0, 'smallint', NULL, NULL); "
"  if (t = 6 or t = 0)"
"    result ('float', 6, 16, '', 'e0', NULL, 1, 1, 2, 0, 0, 0, 'double precision', NULL, NULL); "
"  if (t = 7 or t = 0) "
"    result ('real', 7, 16, '', 'e0', NULL, 1, 1, 2, 0, 0, 0, 'real', NULL, NULL); "
"  if (t = 8 or t = 0)"
"    result ('double precision', 8, 16, '', 'e0', NULL, 1, 1, 2, 0, 0, 0, 'double precision', NULL, NULL); "
"  if (t = 12 or t = 0)"
"    result ('varchar', 12, sys_stat ('db_max_col_bytes'), '''', '''', 'length', 1, 1, 3, 0, 0, 0, 'varchar', NULL, NULL); "
"  if (t = -1 or t = 0)"
"    result ('long varchar', -1, 2147483647, '''', '''', NULL, 1, 1, 0, 0, 0, 0, 'long varchar', NULL, NULL); "
"  if (t = -4 or t = 0)"
"    result ('long varbinary', -4, 2147483647, '''', '''', NULL, 1, 1, 0, 0, 0, 0, 'long varbinary', NULL, NULL); "
"  if (t = 11 or t = 0 or t = 93)"
"    result ('datetime', either(odbc3, 93, 11), 19, '{ts', '}', NULL, 1, 1, 3, 0, 0, 0, 'datetime', NULL, NULL); "
"  if (t = -2 or t = 0)"
"    result ('timestamp', -2, 10, '0x', NULL, NULL, 0, 0, 2, 0, 0, 0, 'timestamp', NULL, NULL); "
"  if (t = 11 or t = 0 or t = 92)"
"    result ('time', either(odbc3, 92, 10), 8, '{t', '}', NULL, 1, 1, 2, 0, 0, 0, 'time', NULL, NULL); "
"  if (t = 9 or t = 0 or t = 91)"
"    result ('date', either(odbc3, 91, 9), 10, '{d', '}', NULL, 1, 1, 2, 0, 0, 0, 'date', NULL, NULL); "
"  if (t = -2 or t = 0)"
"    result ('binary', -2, sys_stat ('db_max_col_bytes'), '0x', '', 'length', 1, 1, 2, 0, 0, 0, 'varbinary', NULL, NULL); "
"  if (t = -3 or t = 0)"
"    result ('varbinary', -3, sys_stat ('db_max_col_bytes'), '0x', '', 'length', 1, 1, 2, 0, 0, 0, 'varbinary', NULL, NULL); "
"  if (t = -8 or t = 0)"
"    result ('nchar', -8, sys_stat ('db_max_col_bytes'), 'N''', '''', 'length', 1, 1, 3, 0, 0, 0, 'nvarchar', NULL, NULL); "
"  if (t = -9 or t = 0)"
"    result ('nvarchar', -9, sys_stat ('db_max_col_bytes'), 'N''', '''', 'length', 1, 1, 3, 0, 0, 0, 'nvarchar', NULL, NULL); "
"  if (t = -10 or t = 0)"
"    result ('long nvarchar', -10, 1073741823, 'N''', '''', NULL, 1, 1, 0, 0, 0, 0, 'long nvarchar', NULL, NULL); "
"  if (t = 0)"
"    result ('any', 12, sys_stat ('db_max_col_bytes'), '''', '''', NULL, 1, 1, 3, 0, 0, 0, 'any', NULL, NULL); "
""
"}";

const char *gtijdbc_text =
"create procedure gettypeinfojdbc (in t integer) "
"{"
"  declare TYPE_NAME, LITERAL_PREFIX, LITERAL_SUFFIX, LOCAL_TYPE_NAME,"
"  CREATE_PARAMS varchar; "
"  declare DATA_TYPE,NULLABLE, CASE_SENSITIVE, SEARCHABLE, UNSIGNED_ATTRIBUTES,"
"  UNSIGNED_ATTRIBUTE, AUTO_INCREMENT, MONEY, FIXED_PREC_SCALE, MAXIMUM_SCALE,"
"  MINIMUM_SCALE smallint; "
"  declare \\PRECISION, SQL_DATA_TYPE, SQL_DATETIME_SUB, NUM_PREC_RADIX integer; "
"  result_names (TYPE_NAME, DATA_TYPE, \\PRECISION, LITERAL_PREFIX, LITERAL_SUFFIX,"
"		CREATE_PARAMS, NULLABLE, CASE_SENSITIVE, SEARCHABLE, "
"		UNSIGNED_ATTRIBUTE, FIXED_PREC_SCALE, AUTO_INCREMENT, LOCAL_TYPE_NAME,"
"		MINIMUM_SCALE, MAXIMUM_SCALE, SQL_DATA_TYPE, SQL_DATETIME_SUB, NUM_PREC_RADIX); "
"  if (t = 1 or t = 0)"
"    result ('character', 1, 2000, '''', '''', 'length', 1, 1, 3, 0, 0, 0, 'varchar', NULL, NULL, 0, 0, 10); "
"  if (t = 2 or t = 0) "
"    result ('numeric', 2, 40, '', '', 'precision,scale', 1, 1, 2, 0, 0, 0, 'numeric', 0, 15, 0, 0, 10); "
"  if (t = -5 or t = 0) "
"    result ('numeric', -5, 40, '', '', 'precision,scale', 1, 1, 2, 0, 0, 0, 'numeric', 0, 15, 0, 0, 10); "
"  if (t = 3 or t = 0)"
"    result ('decimal', 3, 40, '', '', 'precision,scale', 1, 1, 2, 0, 0, 0, 'decimal', 0, 15, 0, 0, 10); "
"  if (t = 4 or t = 0)"
"    result ('integer', 4, 10, '', '', NULL, 1, 1, 2, 0, 0, 0, 'integer', 0, 10, 0, 0, 10); "
"  if (t = 5 or t = 0)"
"    result ('smallint', 5, 3, '', '', NULL, 1, 1, 2, 0, 0, 0, 'smallint', NULL, NULL, 0, 0, 10); "
"  if (t = -6 or t = 0)"
"    result ('smallint', -6, 3, '', '', NULL, 1, 1, 2, 0, 0, 0, 'smallint', NULL, NULL, 0, 0, 10); "
"  if (t = -7 or t = 0)"
"    result ('smallint', -7, 3, '', '', NULL, 1, 1, 2, 0, 0, 0, 'smallint', NULL, NULL, 0, 0, 10); "
"  if (t = 6 or t = 0)"
"    result ('float', 6, 16, '', 'e0', NULL, 1, 1, 2, 0, 0, 0, 'double precision', NULL, NULL, 0, 0, 10); "
"  if (t = 7 or t = 0) "
"    result ('real', 7, 16, '', 'e0', NULL, 1, 1, 2, 0, 0, 0, 'real', NULL, NULL, 0, 0, 10); "
"  if (t = 8 or t = 0)"
"    result ('double precision', 8, 16, '', 'e0', NULL, 1, 1, 2, 0, 0, 0, 'double precision', NULL, NULL, 0, 0, 10); "
"  if (t = 12 or t = 0)"
"    result ('varchar', 12, 2000, '''', '''', 'length', 1, 1, 3, 0, 0, 0, 'varchar', NULL, NULL, 0, 0, 10); "
"  if (t = -1 or t = 0)"
"    result ('long varchar', -1, 2147483647, '''', '''', NULL, 1, 1, 0, 0, 0, 0, 'long varchar', NULL, NULL, 0, 0, 10); "
"  if (t = -4 or t = 0)"
"    result ('long varbinary', -4, 2147483647, '''', '''', NULL, 1, 1, 0, 0, 0, 0, 'long varbinary', NULL, NULL, 0, 0, 10); "
"  if (t = 93 or t = 0)"
"    result ('datetime', 93, 19, '{ts', '}', NULL, 1, 1, 3, 0, 0, 0, 'datetime', NULL, NULL, 0, 0, 10); "
"  if (t = 93 or t = 0)"
"    result ('timestamp', 93, 10, '0x', NULL, NULL, 0, 0, 2, 0, 0, 0, 'timestamp', NULL, NULL, 0, 0, 10); "
"  if (t = 92 or t = 0)"
"    result ('time', 92, 8, '{t', '}', NULL, 1, 1, 2, 0, 0, 0, 'time', NULL, NULL, 0 ,0, 10); "
"  if (t = 91 or t = 0)"
"    result ('date', 91, 10, '{d', '}', NULL, 1, 1, 2, 0, 0, 0, 'date', NULL, NULL, 0, 0, 10); "
"  if (t = -2 or t = 0)"
"    result ('binary', -2, 2000, '0x', '', 'length', 1, 1, 2, 0, 0, 0, 'varbinary', NULL, NULL, 0, 0, 10); "
"  if (t = -3 or t = 0)"
"    result ('varbinary', -3, 2000, '0x', '', 'length', 1, 1, 2, 0, 0, 0, 'varbinary', NULL, NULL, 0, 0, 10); "
""
"}";

const char * proc_owner_check =
"create procedure ddl_owner_check (in tb varchar)\n"
"{\n"
"  declare g_id integer;\n"
"  declare usr varchar;\n"
"  whenever not found goto none;\n"
"  select U_GROUP into g_id from SYS_USERS where U_NAME = user;\n"
"  if (g_id = 0)\n"
"    return;\n"
"  if (name_part (tb, 1, null) = user) \n"
"    return;\n"
" none:\n"
"  txn_error (6);\n"
"  signal ('42000', 'The user has been deleted', 'SQ127');\n"
"}";

const char *drop_trigger_text =
"create procedure ddl_drop_trigger (in tr varchar)\n"
"{\n"
"  declare qual, own, tb varchar;\n"
"  qual := name_part (tr, 0, dbname ());\n"
"  own := name_part (tr, 1, case user when 'dba' then 'DBA' else user end);\n"
"  tr := name_part (tr, 2);\n"
/*"  dbg_obj_print ('dropping trigger: ', qual, own, tr);"*/
"  declare cr cursor for \n"
"    select T_TABLE  from DB.DBA.SYS_TRIGGERS where name_part(T_NAME, 2) = tr \n"
/* XXX: this not prevent to drop other triggers */
"      and  own = name_part (T_TABLE, 1) and qual = name_part (T_TABLE, 0);\n"
"  whenever not found goto none;\n"
"  open cr;\n"
"  fetch cr into tb;\n"
"  __drop_trigger (tb, tr);\n"
"  log_text ('__drop_trigger (?, ?)', tb, tr);\n"
"  delete from DB.DBA.SYS_TRIGGERS where current of cr;\n"
"  return;\n"
" none:\n"
"  signal ('S0002', 'No trigger in drop trigger. Make sure the name is qualified with the subject table''s qualifier and owner if these are not the default qualifier and owner', 'SR269');\n"
"}";


/* IvAn/DropProcedure/000824 Fixed bug with drop of non-owned procedure */
const char * drop_proc_text =
"create procedure ddl_drop_proc (in p varchar, in proc integer := 1)\n"
"{\n"
"  declare ug integer;\n"
"  declare nn varchar;\n"
"  nn := __proc_exists (p, proc);\n"
"\n"
/*"  dbg_obj_print ('ddl_drop_proc proc=', proc, 'p=', p); "*/
"  if (nn is null)\n"
"    nn := coalesce ((select P_NAME from DB.DBA.SYS_PROCEDURES where 0 = casemode_strcmp (P_NAME, complete_proc_name (p, 0, proc))), NULL);\n"
"\n"
"  if (nn is null)\n"
"    signal ('42000', concat( 'No ', case proc when 4 then 'aggregate in DROP AGGREGATE' when 0 then 'module in DROP MODULE' else 'procedure in DROP PROCEDURE' end, ' \"', cast(p as varchar), '\"'), 'SR270');\n"
"\n"
"  select U_GROUP into ug from DB.DBA.SYS_USERS where U_NAME = user;\n"
"\n"
"  if (ug <> 0 and user <> name_part (nn, 1))\n"
"    signal ('42000', concat ('Must be in dba group to drop non-owned ',  case proc when 4 then 'aggregate' when 0 then 'module' else 'procedure' end), 'SR271');\n"
"\n"
"  if (proc > 0 and __proc_exists (p, 0) is not null) "
"   signal ('42000', concat ('Trying to drop a module in DROP ', case proc when 4 then 'AGGREGATE' else 'PROCEDURE' end), 'SR314'); "
"  delete from DB.DBA.SYS_PROCEDURES where P_NAME = nn;\n"
"  delete from DB.DBA.SYS_GRANTS where G_OBJECT = nn and G_OP = 32; \n"
"  { declare exit handler for sqlstate '*' { ; }; \n"
"    delete from DB.DBA.SYS_XPF_EXTENSIONS where XPE_PNAME = nn; } \n"
"  { declare exit handler for sqlstate '*' { ; }; \n"
"    delete from DB.DBA.SYS_RLS_POLICY where RLSP_FUNC = nn; } \n"
"  __drop_proc (p, proc);\n"
" log_text ('__drop_proc (?,?)', p, proc); \n"
"}";

const char *revoke_text =
"create procedure revoke_proc (in grantee integer, in op integer, in obj varchar, in col varchar, in grantor integer)"
"{"
/*"  dbg_obj_print ('revoke proc:' , grantee, op, obj, col); "
"  declare res any; "
"  exec ('select * from SYS_GRANTS', null, null, null, 0, null, res); "
"  dbg_obj_print ('SYS_GRANTS =', res); "*/
"  declare d integer; "
"  declare del_cr cursor for select G_OP from DB.DBA.SYS_GRANTS where G_USER = grantee and G_OP = op and G_OBJECT = obj and G_COL = col; "
"  whenever not found goto no_grant; "
"  open del_cr; "
"  fetch del_cr into d; "
"  delete from DB.DBA.SYS_GRANTS where current of del_cr; "
"  return; "
" no_grant: signal ('42S32', 'Privilege has not been granted. Use list_grants (0) to see what you can revoke', 'SR272'); "
"}";

#if 0
const char *proc_del_user =
"create procedure del_user (in n varchar) "
"{ "
"  whenever not found goto nouser; "
"  declare id integer; "
"  select U_ID into id from DB.DBA.SYS_USERS where U_NAME = n; "
"  delete from DB.DBA.SYS_USERS where U_NAME = n; "
"  delete from DB.DBA.SYS_GRANTS where G_USER = id; "
"  delete from DB.DBA.SYS_USER_GROUP where UG_UID = id; "
"  return; "
" nouser: "
"  signal ('42000', 'No user to delete', 'SR273'); "
"}";
#endif

const char *lg_text =
"create procedure list_grants (in u varchar)"
"{"
"  declare gr cursor for select G_USER, G_OP, G_OBJECT, G_COL from DB.DBA.SYS_GRANTS; "
"  whenever not found goto done; "
"  declare uid, op integer; "
"  declare \\object varchar(384); "
"  declare _column, operation, grantee varchar(128); "
""
"  result_names (operation, \\object, _column, grantee); "
"  open gr; "
"  while (1) {"
"    "
"    fetch gr into uid, op, \\object, _column; "		/* Was \column */
"    if (op = 1) operation := 'select'; "
"    if (op = 2) operation := 'update'; "
"    if (op = 4) operation := 'insert'; "
"    if (op = 8) operation := 'delete'; "
"    if (op = 32) operation := 'execute'; "
"    if (uid = 1) grantee := 'public'; "
"    else {"
"      whenever not found goto nobody; "
"      select U_NAME into grantee from DB.DBA.SYS_USERS where U_ID = uid; "
"      goto ok; "
"    nobody:"
"      grantee := 'nobody'; "
"      ok: grantee := grantee; "
"    }"
"    if (_column = '_all') _column := ''; "
"    result (operation, \\object, _column, grantee); "
"  }"
" done:"
"  return 0; "
"}";


/*
   --
   -- Implementation of API-calls SQLTablePrivileges and SQLColumnPrivileges
   -- with internal KUBL-procedures table_privileges and column_privileges
   -- by AK 12 & 13. April 1997.
   -- With table_privileges returns row for grantee if (s)he has even one
   -- column granted for him/her.
   --
   -- Currently TableQualifier and TableOwner are ignored, so you can give
   -- them as NULLs. (They are always returned as 'db' and 'dba' respectively)
   -- Returns the count of operations for which this user has some kind of
   -- a privilege. I.e. returns zero if this user has no privileges at
   -- all for this table/these tables.
   --
   -- Note that table_privileges are implemented with separate selects
   -- to SYS_GRANTS and SYS_USERS, so it will return also rows matching
   -- grants to 'nobody's, i.e. to user-ids that have already been
   -- deleted from SYS_USERS. (Of course DELETE USER command should
   -- delete also all grants to specific uid from SYS_GRANTS at the same
   -- time it deletes users record from SYS_USERS, otherwise new users
   -- might get accidentally access to old users' tables. Probably this
   -- has been already fixed in the newer version. See del_user)
   --
 */

const char *proc_table_privileges =
"create procedure table_privileges (in TableQualifier varchar,"
"				   in TableOwner varchar,"
"				   in TableName varchar)"
"{"
"  declare priv_op_vec varchar;"
"  declare gr cursor for"
"   select distinct G_USER, G_OBJECT from DB.DBA.SYS_GRANTS"
"     where ucase (name_part(G_OBJECT,0)) like ucase (TableQualifier)"
"       and ucase (name_part(G_OBJECT,1)) like ucase (TableOwner)"
"       and ucase (name_part(G_OBJECT,2)) like ucase (TableName) and G_OP < 16;"
"  whenever not found goto done;"
"  declare uid, gid, privcount, _g_op integer; "
"  declare _g_object any;"
"  declare \\TABLE_CAT, \\TABLE_SCHEM, \\GRANTOR VARCHAR(128);"
"  declare \\TABLE_NAME, \\GRANTEE, \\PRIVILEGE VARCHAR(128);"
"  declare \\IS_GRANTABLE VARCHAR(3);"

"  result_names (\\TABLE_CAT, \\TABLE_SCHEM, \\TABLE_NAME,"
"		\\GRANTOR, \\GRANTEE, \\PRIVILEGE, \\IS_GRANTABLE);"

"  priv_op_vec := vector(1,'SELECT',2,'UPDATE',4,'INSERT',8,'DELETE');"
/* "--	 Avoid these: 16,'GRANT',32,'EXECUTE' " */

"  privcount := 0;"
"  \\GRANTOR := NULL;"
"  open gr; "
"  while (1)"
"   {"
"     declare loop_grants, _get_g integer;"
"     loop_grants := 8;"
"     fetch gr into uid, _g_object;"
"    \\IS_GRANTABLE := 'NO';"
"    \\TABLE_CAT := name_part(_g_object,0);"
"    \\TABLE_SCHEM := name_part(_g_object,1);"
"    \\TABLE_NAME := name_part(_g_object,2);"
"    while (loop_grants)"
"     {"
"       \\PRIVILEGE := get_keyword(loop_grants,priv_op_vec,NULL);"
"       if (exists (select 1 from DB.DBA.SYS_GRANTS"
"	  where G_USER = uid and G_OBJECT=_g_object and G_OP = loop_grants)){"
"         _g_op := loop_grants; } else {_g_op := 9; }"
"       if (uid = 1)"
"        {"
"           \\GRANTEE := 'public'; "
"           if(loop_grants = _g_op) { \\IS_GRANTABLE := 'YES'; }"
"        }"
"       else"
"        {"
"          whenever not found goto nobody; "
"          select U_NAME,U_GROUP into \\GRANTEE, gid from DB.DBA.SYS_USERS where U_ID = uid;"
"          if((uid = 0) or (gid = 0) or (loop_grants = _g_op)) { \\IS_GRANTABLE := 'YES'; }"
"          goto ok; "
"nobody:"
"          \\GRANTEE := 'nobody';"
"        }"
"ok:"
"       result(\\TABLE_CAT, \\TABLE_SCHEM, \\TABLE_NAME,"
"              \\GRANTOR, \\GRANTEE, \\PRIVILEGE, \\IS_GRANTABLE);"
"       if(('dba' = get_user()) or"
"           (\\GRANTEE = get_user()) or (\\GRANTEE = 'public'))"
"        { privcount := privcount+1; }"
"        loop_grants := loop_grants / 2;"
"     }"
"   }"
"done:"
"  return privcount;"
"}";


const char *proc_new_key_id =
"create procedure new_key_id (in q integer)\n"
"{\n"
"  declare id, prev_id, first_id integer;\n"
"  first_id := sys_stat ('__internal_first_id');\n"
"  prev_id := first_id;\n"
"  for (select KEY_ID from SYS_KEYS where KEY_ID >= first_id order by KEY_ID) do\n"
"    {\n"
"      id := KEY_ID;\n"
"      if (id - prev_id >= 2)\n"
"        goto done;\n"
"      prev_id := id;\n"
"    }\n"
"done:\n"
"  return prev_id + 1;\n"
"}";

const char * proc_new_key_ver =
"create procedure new_key_version (in k_id integer)\n"
"{\n"
"  declare sup int;\n"
"  select key_super_id into sup from sys_keys where key_id = k_id;\n"
"  declare id, prev_id, first_id integer;\n"
" first_id := 0;\n"
"  prev_id := first_id;\n"
"  for (select KEY_VERSION from SYS_KEYS where KEY_SUPER_ID = sup order by KEY_VERSION) do\n"
"    {\n"
"      id := KEY_VERSION;\n"
"      if (id - prev_id >= 2)\n"
"        goto done;\n"
"      prev_id := id;\n"
"    }\n"
"done:\n"
"  if (prev_id >= 124)  -- 124 is the last usable kv\n"
"    {txn_error (6); signal ('42000', 'run out of key versions.  The table has been altered too many times.  To alter further, copy the data to a new table, drop the old one and rename the new to the old.  A better way is to be implemented in a later version.'); }\n"
"  return prev_id + 1;\n"
"}\n";

const char *proc_new_col_id =
"create procedure new_col_id (in q integer)"
"{"
"  declare id, prev_id, first_id integer;\n"
"  first_id := sys_stat ('__internal_first_id');\n"
"  prev_id := first_id;\n"
"  set isolation = 'serializable';\n"
"  declare cr cursor for select COL_ID from DB.DBA.SYS_COLS where COL_ID >= first_id order by COL_ID;\n"
"  open cr (exclusive, prefetch 1);\n"
"  whenever not found goto done;\n"
"  while (1 = 1) \n"
"    {\n"
"      fetch cr into id;\n"
"      if (id - prev_id >= 2)\n"
"        goto done;\n"
"      prev_id := id;\n"
"    }\n"
"done:\n"
"  close cr; \n"
"  return prev_id + 1;\n"
"}";


const char *proc_find_new_super =
"create procedure find_new_super (in k_id integer, out tname varchar)"
"{"
"  declare n_id integer;"
"  declare sub_name varchar;"
"  select KEY_TABLE into sub_name from DB.DBA.SYS_KEYS where KEY_ID = k_id;"
"  whenever not found goto none;"
"  select KEY_ID, KEY_TABLE into n_id, tname from DB.DBA.SYS_KEY_SUBKEY, DB.DBA.SYS_KEYS where KEY_ID = SUPER and SUB = k_id"
"    and KEY_TABLE <> sub_name;"
"  "
/*"  dbg_printf ('Super of %d is %s', k_id, tname);"*/
"  return n_id;"
" none:"
/*"  dbg_printf ('No super for %d', k_id);"*/
"  return NULL;"
"}";


const char *proc_obsolete_key =
"create procedure obsolete_key (in k_name varchar, in k_id integer, in n_k_id integer, in drop_col integer)"
"{"
"  declare old_super, new_super, n_parts, new_kv integer;"
"  declare nk_name varchar;"
"  nk_name := sprintf ('%s__%d', k_name, k_id);"
/*"  dbg_printf ('Rename %s to %s', k_name, nk_name);\n"*/
"  declare super_name varchar;"
"  "
"  new_super := find_new_super (k_id, super_name);"
"  new_kv := new_key_version (k_id); \n"
"  update DB.DBA.SYS_KEYS set KEY_NAME = nk_name, KEY_MIGRATE_TO = n_k_id where KEY_ID = k_id;"
"  insert into DB.DBA.SYS_KEYS (KEY_TABLE, KEY_NAME, KEY_ID, KEY_N_SIGNIFICANT,"
"			KEY_IS_MAIN, KEY_SUPER_ID, KEY_CLUSTER_ON_ID, KEY_IS_OBJECT_ID, KEY_IS_UNIQUE, KEY_DECL_PARTS, KEY_MIGRATE_TO, KEY_VERSION, KEY_OPTIONS, KEY_STORAGE)"
"    select KEY_TABLE, k_name, n_k_id, KEY_N_SIGNIFICANT,"
"			KEY_IS_MAIN, KEY_SUPER_ID, KEY_CLUSTER_ON_ID, KEY_IS_OBJECT_ID, KEY_IS_UNIQUE, KEY_DECL_PARTS, -1, new_kv, KEY_OPTIONS, KEY_STORAGE"
"			  from DB.DBA.SYS_KEYS where KEY_ID = k_id;"
""
"  if (new_super is not null) {"
/*"    dbg_printf ('Setting supers: Super table %s.', super_name);\n"*/
"    insert into DB.DBA.SYS_KEY_SUBKEY (SUPER, SUB) "
"      select KEY_ID, n_k_id from DB.DBA.SYS_KEYS where KEY_TABLE = super_name and KEY_IS_MAIN = 1;"
"  }"
"  insert into DB.DBA.SYS_KEY_SUBKEY (SUPER, SUB) values (n_k_id, k_id);"
"  "
"  insert into DB.DBA.SYS_KEY_PARTS (KP_KEY_ID, KP_NTH, KP_COL) "
"    select n_k_id, KP_NTH, KP_COL from DB.DBA.SYS_KEY_PARTS where KP_KEY_ID = k_id and KP_COL <> coalesce (drop_col, 0);"
"  select KP_NTH into n_parts  from DB.DBA.SYS_KEY_PARTS where KP_KEY_ID = n_k_id order by KP_KEY_ID desc, KP_NTH desc;"
/*"  dbg_printf ('old k %d, new K %d, %d parts', k_id, n_k_id, n_parts);\n"*/
"  return n_parts;"
"}";


const char *proc_add_col =
"create procedure add_col (in tb_name varchar, in col_name varchar, \n"
"			  in col_dtp varchar)\n"
"{\n"
"  if (tb_name = 'DB.DBA.SYS_REPL_ACCOUNTS')\n"
"    tb_name := 'SYS_REPL_ACCOUNTS';\n"
"  declare col_id integer;\n"
"  ddl_owner_check (tb_name);\n"
"  if (exists (select 1 from SYS_COLS where \\TABLE = tb_name and \\COLUMN = col_name)) \n"
"    signal ('S1001', sprintf ('Column \"%s\" already exists in ALTER TABLE \"%s\"', col_name, tb_name), 'SR274'); \n"
"  if (exists (select 1 from SYS_VIEWS where V_NAME = tb_name))\n"
"    signal ('42S02', 'ALTER TABLE not supported for views. Drop the view and recreate it instead.', 'SR328');\n"
"  col_id := new_col_id (sys_stat ('__internal_first_id'));\n"
"  ddl_add_col_row (tb_name, col_name, col_id, col_dtp);\n"
"  add_col_recursive (tb_name, col_id);\n"
"  update DB.DBA.SYS_KEYS set KEY_MIGRATE_TO = NULL where KEY_MIGRATE_TO = -1;\n"
"  ddl_read_table_tree (tb_name);\n"
"  cl_exec ('__key_col_ddl (?, ?, ?, 0)', vector (tb_name, name_part (tb_name, 2), col_name));"
"  DB.DBA.__INT_REPL_ALTER_REDO_TRIGGERS (tb_name);\n"
"}";

static const char *proc_decoy_repl_modify_col =
" create procedure __INT_REPL_ALTER_ADD_COL (in tb varchar, in col varchar, \n"
"    in dv integer, in scale integer, in prec integer, in ck varchar, in _action varchar := \'ADD\') \n"
" { \n"
" ;\n"
"}";

static const char *proc_decoy_repl_redo_trigs =
" create procedure __INT_REPL_ALTER_REDO_TRIGGERS (in tb varchar) \n"
" { \n"
" ;\n"
"}";

const char *proc_modify_col =
"create procedure __DDL_MODIFY_COL (\n"
"			  in _col_prec integer,\n"
"			  in _col_check varchar,\n"
"			  in _col_scale any,\n"
"			  in _col_default any,\n"
"			  in _col_nullable any,\n"
"			  in _col_options any,\n"
"			  in _col_id integer,\n"
"			  in _tb_name varchar,\n"
"			  in _col_name varchar,\n"
"			  in _col_dtp integer\n"
")\n"
"{\n"
"  update DB.DBA.SYS_COLS set \n"
"    COL_PREC = _col_prec, \n"
"    COL_CHECK = _col_check, \n"
"    COL_SCALE = _col_scale, \n"
"    COL_DEFAULT = _col_default, \n"
"    COL_NULLABLE = _col_nullable, \n"
"    COL_OPTIONS = _col_options \n"
"   where COL_ID = _col_id;\n"
"  ddl_read_table_tree (_tb_name);\n"
"  DB.DBA.__INT_REPL_ALTER_ADD_COL (_tb_name, _col_name, _col_dtp, _col_scale, _col_prec, _col_check, 'MODIFY');\n"
"}";


const char *proc_read_table_tree =
"create procedure ddl_read_table_tree (in tb varchar) "
"{"
"  declare _have_subs integer; "
"  declare skey_id, _key_id integer; "
"  __ddl_changed (tb);"
"  whenever not found goto subs_done; "
"  select KEY_ID into _key_id from DB.DBA.SYS_KEYS where KEY_TABLE = tb and KEY_IS_MAIN = 1; "
"  declare subcr cursor for select KEY_TABLE from DB.DBA.SYS_KEY_SUBKEY, DB.DBA.SYS_KEYS where SUPER = _key_id and KEY_ID = SUB"
"    and KEY_MIGRATE_TO is null and KEY_TABLE <> tb; "
"  "
"  _have_subs := 0; "
"  open subcr; "
"  while (1=1) {"
"    declare stb varchar; "
"    fetch subcr into stb; "
"    _have_subs := 1; "
"    ddl_read_table_tree (stb); "
"  }"
" subs_done:"
"  if (_have_subs > 0) "
"   __ddl_changed (tb);"
"  return 1;"
"}";

const char *proc_add_col_recursive =
"create procedure add_col_recursive (in tb_name varchar, in col_id integer)"
"{"
"  declare n_parts, prime, n_k_id integer;"
"  declare prime_name varchar;"
"  whenever not found goto no_table;"
"  select KEY_ID, KEY_NAME into prime, prime_name from DB.DBA.SYS_KEYS where KEY_TABLE = tb_name and "
"    KEY_IS_MAIN = 1 and KEY_MIGRATE_TO is null;"
""
"  n_k_id := new_key_id (sys_stat ('__internal_first_id'));"
"  n_parts := obsolete_key (prime_name, prime, n_k_id, null);"
"  if (n_parts >= 300) { txn_error (6); signal ('42000', 'Column count too large', 'SR275'); } "
"  insert into DB.DBA.SYS_KEY_PARTS (KP_KEY_ID, KP_NTH, KP_COL) values (n_k_id, n_parts + 1, col_id);"
"  declare sub cursor for select distinct KEY_TABLE from DB.DBA.SYS_KEY_SUBKEY, DB.DBA.SYS_KEYS where SUPER = prime "
"    and KEY_ID = SUB and KEY_MIGRATE_TO is null;"
"  whenever not found goto done;"
"  open sub (prefetch 1);"
"  while (1) {"
"    declare s_table, s_key varchar;"
"    declare s_key_id integer;"
"    fetch sub into s_table;"
/*"    dbg_printf ('Table %s key %d sub of %d ', s_table,  s_key_id, prime);\n"*/
"    add_col_recursive (s_table, col_id);"
"  }"
" done: "
"  return;"
" no_table: signal ('42S02', 'No table in add column', 'SR276');"
"}";


const char *proc_user_qual =
"create procedure user_set_qualifier_1 (in u varchar, in q varchar) "
"{ "
"  if (not length (q)) signal ('22023', 'Qualifier cannot be empty string');"
"  update DB.DBA.SYS_USERS set U_DATA = concatenate ('Q ', q) where U_NAME = u;"
"  sec_set_user_data (u, concatenate ('Q ', q));"
"}";


const char * proc_null_blob =
"create procedure ddl_null_blob_col (in tb varchar, in col varchar)\n"
"{\n"
"  declare dtp, nullable integer;\n"
"  select COL_DTP,COL_NULLABLE into dtp, nullable from SYS_COLS where \\TABLE = tb and \\COLUMN = col;\n"
"  if (dtp = 125 or dtp = 131) {\n"
"    declare state, msg varchar;\n"
"    state := '00000';\n"
"    if (nullable = 1) \n"
"      exec (sprintf ('update \"%I\".\"%I\".\"%I\" set \"%I\" = ? ', name_part (tb, 0),\n"
"            name_part (tb, 1), name_part (tb, 2), col),\n"
"            state, msg, vector (''), 0, NULL, NULL);\n"
"    else \n"
"      exec (sprintf ('update \"%I\".\"%I\".\"%I\" set \"%I\" = null', name_part (tb, 0),\n"
"         	   name_part (tb, 1), name_part (tb, 2), col),\n"
"           state, msg, vector (), 0, NULL, NULL);\n"
"    if (state <> '00000') {\n"
"      txn_error (6);\n"
"      signal (state, msg);\n"
"    }\n"
"  }\n"
"}";


const char *proc_drop_col =
"create procedure ddl_drop_col (in tb varchar, in col varchar)"
"{"
"  declare c_id integer;"
"  declare c_check varchar;"
"  declare _col_dtp, _col_scale, _col_prec integer;\n"
"  whenever not found goto no_table;"
"  tb := complete_table_name (tb, 1);"
"  ddl_owner_check (tb);\n"
"  if (exists (select 1 from SYS_VIEWS where V_NAME = tb))\n"
"    signal ('42S02', 'ALTER TABLE not supported for views. Drop the view and recreate it instead.', 'SR330');\n"
"  select COL_ID, COL_CHECK, COL_DTP, COL_SCALE, COL_PREC \n"
"      into c_id, c_check, _col_dtp, _col_scale, _col_prec \n"
"    from SYS_COLS where \\TABLE = tb and \\COLUMN = col;"
"  if (exists (select 1 from SYS_KEYS, SYS_KEY_PARTS where KP_KEY_ID = KEY_ID and KP_NTH < KEY_N_SIGNIFICANT and KP_COL = c_id))"
"    signal ('37000', 'The column is a key or primary key part. Drop the index first', 'SR280');"
"  if (exists (select 1 from SYS_FOREIGN_KEYS where PK_TABLE = tb and 0 = casemode_strcmp (PKCOLUMN_NAME, col)))"
"    signal ('37000', 'The column is referenced in foreign key constraint. Drop the foreign key first', 'SR281');"
"  delete from DB.DBA.SYS_COL_STAT where CS_TABLE = tb and CS_COL = col; "
"  delete from DB.DBA.SYS_COL_HIST where CH_TABLE = tb and CH_COL = col; "
"  ddl_null_blob_col (tb, col);\n"
"  if (isstring (c_check)) { if (strstr (c_check, 'I') is not null) { SET_IDENTITY_COLUMN (tb, col, 0); } }"
"  update SYS_COLS set \\COLUMN = sprintf ('%s__%s', col, convert (varchar, c_id)) where COL_ID = c_id;"
"  ddl_drop_col_recursive (tb, c_id);"
"  update DB.DBA.SYS_KEYS set KEY_MIGRATE_TO = NULL where KEY_MIGRATE_TO = -1;"
"  ddl_read_table_tree (tb);"
"  cl_exec ('__key_col_ddl (?, ?, ?, 1)', vector (tb, name_part (tb, 2), col));"
"  if (not sys_stat ('st_lite_mode')) { \n"
"  DB.DBA.__INT_REPL_ALTER_DROP_COL (tb, col, _col_dtp, _col_scale, _col_prec, c_check, 'DROP');\n"
"  DB.DBA.__INT_REPL_ALTER_REDO_TRIGGERS (tb);\n"
"  } \n"
"  for select distinct PK_TABLE from DB.DBA.SYS_FOREIGN_KEYS where 0 = casemode_strcmp (FK_TABLE, tb)"
/*"      and (UPDATE_RULE > 0 or DELETE_RULE > 0)"*/
"      do {"
"  DB.DBA.ddl_fk_rules (PK_TABLE, tb, col); }" /*drop referential update&delete*/
"  delete from SYS_FOREIGN_KEYS where FK_TABLE = tb and 0 = casemode_strcmp (FKCOLUMN_NAME, col);"
"  DB.DBA.ddl_fk_check_input (tb, 0);"
"  return;"
" no_table: signal ('42S22', 'The column to drop is not defined in the given table', 'SR282');"
"}";


const char *proc_drop_col_rec =
"create procedure ddl_drop_col_recursive (in tb_name varchar, in col_id integer)"
"{"
"  declare n_parts, prime, n_k_id integer;"
"  declare prime_name varchar;"
"  whenever not found goto no_table;"
"  select KEY_ID, KEY_NAME into prime, prime_name from DB.DBA.SYS_KEYS where KEY_TABLE = tb_name and "
"    KEY_IS_MAIN = 1 and KEY_MIGRATE_TO is null;"
""
"  n_k_id := new_key_id (sys_stat ('__internal_first_id'));"
"  n_parts := obsolete_key (prime_name, prime, n_k_id, col_id);"
"  declare sub cursor for select distinct KEY_TABLE from DB.DBA.SYS_KEY_SUBKEY, DB.DBA.SYS_KEYS where SUPER = prime "
"    and KEY_ID = SUB and KEY_MIGRATE_TO is null;"
"  whenever not found goto done;"
"  open sub (prefetch 1);"
"  while (1) {"
"    declare s_table, s_key varchar;"
"    declare s_key_id integer;"
"    fetch sub into s_table;"
/*"    dbg_printf ('Table %s key %d sub of %d ', s_table,  s_key_id, prime);"*/
"    ddl_drop_col_recursive (s_table, col_id);"
"  }"
" done: "
"  return;"
" no_table: signal ('42S02', 'No table in add column', 'SR283');"
"}";

const char *proc_add_col_row =
"create procedure ddl_add_col_row (in tb varchar, in col varchar,\n"
"				  in c_id integer, in decl varchar)\n"
"{\n"
"  declare inx, deflt, nullable, dv, prec, scale integer;\n"
"  declare dtp, opts, ck varchar;\n"
"  declare _col_options, opt any;\n"
"  declare _col_id_start integer;\n"
"  decl := aref (decl, 1);\n"
"  dtp := aref (decl, 0);\n"
"\n"
"  _col_id_start := 1;\n"
"  _col_options := vector();\n"
"  nullable := null; deflt := null; ck := '';\n"
"  opts := aref (decl, 1);\n"
"  dv := aref (dtp, 0);\n"
"  if (length (dtp) > 1)\n"
"    prec := aref (dtp, 1);\n"
"  else prec := 0; \n"
"  if (length (dtp) > 3 and isstring (dtp[3]))\n"
"    _col_options := vector_concat (_col_options, vector ('sql_class', dtp[3]));\n"
"  if (length (dtp) > 4 and __tag (dtp[4]) = 193) -- DV_ARRAY_OF_POINTER\n"
"    _col_options := vector_concat (_col_options, dtp[4]);\n"
"  if (prec = 0 or prec is null) --- duplicate of ddl_dv_default_prec\n"
"    { \n"
"      prec := case aref (dtp, 0) \n"
"	     when 189 then 10 \n"
"	     when 188 then 10 \n"
"	     when 181 then 0 \n"
"	     when 182 then 0 \n"
"	     when 190 then 14 \n"
"	     when 191 then 16 \n"
"	     when 129 then 26 \n"
"	     when 128 then 8 \n"
"	     when 208 then 8 \n"
"	     when 238 then 0 \n"
"	     else 0 end; \n"
"    } \n"
"  if (length (dtp) > 2)\n"
"    scale := aref (dtp, 2);\n"
"  else \n"
"    scale := NULL; \n"
"  if (not isinteger (prec)) prec := null;\n"
"  if (not isinteger (scale)) scale := null;\n"
"  inx := 0;\n"
"  declare _ddl_foreign_key any;\n"
"  _ddl_foreign_key := null;\n"
"  while (inx < length (opts)) {\n"
"    opt := aref (opts, inx);\n"
"    if (510 = opt)\n"
"      ck := 'I';\n"
"    else if (opt = 515)\n"
"      nullable := 1;\n"
"    else if (aref (opt, 0) = 514)\n"
"      deflt := aref (opt, 1);\n"
"    else if (aref (opt, 0) = 512) {\n"
"      aset (opt, 1, vector (convert (varchar, col)));\n"
"      _ddl_foreign_key := vector (tb, complete_table_name (aref (opt, 2), 1), opt);\n"
"    }\n"
"    else if (aref (opt, 0) = 510) {\n"
"      declare opt_inx integer;\n"
"      declare id_opts, id_opt any;\n"
"      id_opts := aref (opt, 1);\n"
"      opt_inx := 0;\n"
"      while (opt_inx < length (id_opts)) {\n"
"        id_opt := aref (id_opts, opt_inx);\n"
"        if (id_opt[0] = 520) {\n"
"          _col_id_start := id_opt[1];\n"
"          ck := 'I';\n"
"          _col_options := vector_concat (_col_options, vector ('identity_start', _col_id_start));\n"
"        }\n"
"        else if (id_opt[0] = 521) {\n"
"          _col_id_start := id_opt[1];\n"
"          ck := 'I';\n"
"          _col_options := vector_concat (_col_options, vector ('increment_by', _col_id_start));\n"
"        }\n"
"        opt_inx := opt_inx + 1;\n"
"      }\n"
"    }\n"
"    inx := inx + 1;\n"
"  }\n"
"  if (length (_col_options) = 0) _col_options := null;\n"
"  insert into SYS_COLS (\\TABLE, \\COLUMN, COL_ID, COL_DTP, COL_PREC,  COL_SCALE,\n"
"			COL_NULLABLE, COL_CHECK, COL_DEFAULT, COL_OPTIONS)\n"
"    values (tb, col, c_id, dv, prec, scale, nullable, ck, serialize (deflt), _col_options);\n"
"\n"
"  DB.DBA.__INT_REPL_ALTER_ADD_COL (tb, col, dv, scale, prec, ck);\n"
"\n"
"  if (_ddl_foreign_key is not null)\n"
"    ddl_foreign_key (_ddl_foreign_key[0], _ddl_foreign_key[1], _ddl_foreign_key[2]);\n"
"\n"
"  if (strstr (ck, 'I') is not null)\n"
"     SET_IDENTITY_COLUMN (tb, col, _col_id_start);\n"
"}\n";

const char *stat_proc1 =
"create procedure __tc_no (in c varchar) \n"
"{\n"
"  result (sys_stat (c), c);\n"
"}\n";


const char * wsst =
"create procedure ws_stat (in q integer := 0)\n"
"{\n"
"  declare v integer;\n"
"  declare c varchar;\n"
"  result_names (v, c);\n"
"  __tc_no ('tws_connections');\n"
"  __tc_no ('tws_requests');\n"
"  __tc_no ('tws_1_1_requests');\n"
"  __tc_no ('tws_cancel');\n"
"  __tc_no ('tws_slow_keep_alives');\n"
"  __tc_no ('tws_immediate_reuse');\n"
"  __tc_no ('tws_slow_reuse');\n"
"  __tc_no ('tws_accept_queued');\n"
"  __tc_no ('tws_accept_requeued');\n"
"  __tc_no ('tws_keep_alive_ready_queued');\n"
"  __tc_no ('tws_early_timeout');\n"
"  __tc_no ('tws_done_while_check_in');\n"
"  __tc_no ('tws_disconnect_while_check_in');\n"
"  __tc_no ('tws_cached_connections');\n"
"  __tc_no ('tws_cached_connection_hits');\n"
"  __tc_no ('tws_cached_connection_miss');\n"
"  __tc_no ('tws_bad_request');\n"
"}\n";


const char * bm_proc_1 =
"create procedure ddl_bitmap_inx (in tb varchar, in bm_id integer, in opts any)\n"
"{\n"
"  declare last_col, last_col_dtp int;\n"
" if (not isarray (opts)) return;\n"
"  whenever not found goto err;\n"
"  select kp_col into last_col from sys_key_parts where kp_key_id = bm_id and kp_nth = (select max (kp_nth) from sys_key_parts where kp_key_id = bm_id);\n"
"  select col_dtp into last_col_dtp from sys_cols where col_id = last_col;\n"
"  if (position ('bitmap', opts) and last_col_dtp not in (189, 243, 244, 247))\n"
"    signal ('42000', 'BM001: The last effective part of a bitmap index must be an int or iri_id');\n"
"    update sys_keys set key_options = opts where key_id = bm_id;\n"
"  return;\n"
" err:\n"
"  signal ('42000', 'Inconsistent bitmap key layout.');\n"
"}\n";



const char * pk1 =
"create procedure ddl_reorg_pk (in tb varchar, in unq_id integer)\n"
"{\n"
"  declare pk_id, idn_id integer;\n"
"  declare pk_name varchar;\n"
"  whenever not found goto nokey;\n"
"  select KEY_NAME, KEY_ID into pk_name, pk_id from SYS_KEYS \n"
"    where KEY_TABLE = tb and KEY_IS_MAIN = 1 and KEY_MIGRATE_TO is null;\n"
"  if (exists (select 1 from SYS_PARTITION where part_key = pk_name))\n"
"    return;\n"
"  select COL_ID into idn_id from SYS_KEYS, SYS_KEY_PARTS, SYS_COLS where KEY_ID = pk_id \n"
"    and KP_KEY_ID = KEY_ID and COL_ID = KP_COL\n"
"      and \\COLUMN = '_IDN';\n"
"  if (exists (\n"
"      select 1 \n"
"         from SYS_KEYS, SYS_KEY_PARTS, SYS_COLS \n"
"         where \n"
"           KEY_TABLE = tb \n"
"           and KEY_ID = unq_id \n"
"           and KP_KEY_ID = KEY_ID\n"
"           and COL_ID = KP_COL\n"
"           and (COL_NULLABLE is NULL or COL_NULLABLE <> 1)))\n"
"    return; \n"
"  if (not exists (select 1 from SYS_KEY_SUBKEY where SUB = pk_id)\n"
"      and not exists (select 1 from SYS_KEYS where KEY_TABLE = tb and KEY_MIGRATE_TO is not null)\n"
"     )\n"
"    {\n"
"      declare state, msg, descs, rows varchar;\n"
"      state := '00000';\n"
"      exec (sprintf ('select 1 from \"%I\".\"%I\".\"%I\"', name_part (tb, 0), name_part (tb, 1), name_part (tb, 2)),\n"
"	    state, msg, vector (), 1, descs, rows);\n"
"      if (length (rows) <> 0)\n"
"	return;\n"
"      if (state <> '00000')\n"
"	signal (state, msg);\n"
"      ddl_change_pk (tb, pk_id, unq_id, idn_id);\n"
"    }\n"
"  \n"
" nokey:\n"
"  return;\n"
"}";



const char * pk2 =
"create procedure ddl_change_pk (in tb varchar, in pk_id integer, in unq_id integer,\n"
"				in idn_id integer)\n"
"{\n"
"  declare n_prime, nth integer;\n"
"  delete from SYS_KEY_PARTS nn where KP_KEY_ID = unq_id and KP_COL = idn_id;\n"
"  delete from SYS_KEY_PARTS nn where KP_KEY_ID = pk_id and KP_COL = idn_id;\n"
"  delete from SYS_COLS where COL_ID = idn_id;\n"
"  select count (*) into n_prime from SYS_KEY_PARTS where KP_KEY_ID = unq_id;\n"
"  update SYS_KEYS set KEY_N_SIGNIFICANT = n_prime, KEY_DECL_PARTS = n_prime, KEY_IS_MAIN = 1\n"
"    where KEY_ID = unq_id;\n"
"  nth := n_prime - 1;\n"
"  declare cr cursor for \n"
"    select KP_COL from SYS_KEY_PARTS nn\n"
"      where KP_KEY_ID = pk_id \n"
"	and not exists (select 1 from SYS_KEY_PARTS ff where ff.KP_KEY_ID = unq_id and ff.KP_NTH < n_prime and ff.KP_COL = nn.KP_COL);\n"
"  whenever not found goto done; \n"
"  open cr; \n"
"  while (1) \n"
"    { \n"
"      declare _kp_col any; \n"
"      fetch cr into _kp_col; \n"
"      nth := nth + 1; \n"
"      insert into SYS_KEY_PARTS (KP_KEY_ID, KP_NTH, KP_COL) values (unq_id, nth, _kp_col);\n"
"    } \n"
"done:\n"
"  close cr; \n"
"  whenever not found default; \n"
"  delete from SYS_KEYS where KEY_ID = pk_id;\n"
"  delete from SYS_KEY_PARTS where KP_KEY_ID = pk_id;\n"
"  ddl_change_non_pk (tb, unq_id, n_prime, idn_id);\n"
"}\n";




const char * pk3 =
"create procedure ddl_change_non_pk (in tb varchar, in pk_id integer, in n_pk_parts integer,\n"
"				    in idn_id integer)\n"
"{\n"
/*"  -- dbg_obj_print ('pk_parts', n_pk_parts);\n"*/
"  declare cr cursor for \n"
"    select KEY_ID, KEY_DECL_PARTS from SYS_KEYS where KEY_TABLE = tb and KEY_IS_MAIN = 0 \n"
"      and KEY_MIGRATE_TO is null;\n"
"  whenever not found goto done;\n"
"  open cr;\n"
"  while (1) {\n"
"    declare k_id, n_parts, part_ctr, new_len integer;\n"
"    fetch cr into k_id, n_parts;\n"
"    part_ctr := n_parts - 1;\n"
"    delete from SYS_KEY_PARTS where KP_KEY_ID = k_id and KP_COL = idn_id;\n"
"    declare cr2 cursor for  \n"
"      select KP_COL from SYS_KEY_PARTS pk\n"
"	where KP_KEY_ID = pk_id and KP_NTH < n_pk_parts \n"
"	  and not exists (select 1 from SYS_KEY_PARTS head where head.KP_KEY_ID = k_id\n"
"	    and head.KP_NTH < n_parts and head.KP_COL = pk.KP_COL);\n"
"      whenever  not found goto done2; \n"
"      open cr2; \n"
"      while (1) \n"
"        { \n"
"          declare _kp_col any; \n"
"          fetch cr2 into _kp_col; \n"
"          part_ctr := part_ctr + 1; \n"
"          insert into SYS_KEY_PARTS (KP_KEY_ID, KP_NTH, KP_COL) values (k_id, part_ctr, _kp_col); \n"
"        } \n"
"done2: \n"
"      close cr2; \n"
"    whenever not found goto done; \n"
"    select count (*) into new_len from SYS_KEY_PARTS where KP_KEY_ID = k_id;\n"
"    update SYS_KEYS set KEY_N_SIGNIFICANT = new_len where KEY_ID = k_id;\n"
"  }\n"
" done:\n"
"  return;\n"
"}";


static const char *collation_define_text =
"create procedure collation_define (in _name varchar, in filename varchar, in add_type integer) \n"
"{ \n"
"  declare deffile, def_vector, element, collation, name varchar; \n"
"  declare inx, weight, char_max, char_code, is_wide integer; \n"
" \n"
"  name := complete_collation_name (_name, 1); \n"
"  deffile := file_to_string (filename); \n"
"  def_vector := split_and_decode (deffile, 0, \'\\0\\0\\n=\'); \n"
"  inx := 0; \n"
"  while (inx < length (def_vector)) \n"
"    { \n"
"      element := trim(aref (def_vector, inx)); \n"
"      if (length (element) > 1) \n"
"	aset (def_vector, inx, atoi (element)); \n"
"      else if (length (element) > 0) \n"
"	aset (def_vector, inx, ascii (element)); \n"
"      else \n"
"	aset (def_vector, inx, -1); \n"
"      inx := inx + 1; \n"
"    } \n"
"  if (add_type = 0) \n"
"    { \n"
"      result_names (char_code, weight); \n"
"      inx := 0; \n"
"      while (inx < length (def_vector)) \n"
"	{ \n"
"	  char_code := aref (def_vector, inx); \n"
"	  weight := aref (def_vector, inx + 1); \n"
"	  if (char_code > -1 and weight > -1) \n"
"	    result (char_code, weight); \n"
"	  inx := inx + 2; \n"
"	} \n"
"      return; \n"
"    } \n"
"  if (add_type = 1) \n"
"    { \n"
"      char_max := 256; \n"
"      collation := make_string (char_max); \n"
"      is_wide := 0; \n"
"    } \n"
"  else if (add_type = 2) \n"
"    { \n"
"      char_max := 65536; \n"
"      collation := make_wstring(char_max); \n"
"      is_wide := 1; \n"
"    } \n"
"  else \n"
"    { \n"
"      signal (\'22023\', sprintf (\'parse_collation : invalid table size %d\', add_type), 'SR279'); \n"
"      return; \n"
"    } \n"
" \n"
"  inx := 0; \n"
"  while (inx < char_max) \n"
"    { \n"
"      weight := get_keyword (inx, def_vector, -1); \n"
"      if (weight < 0) \n"
"	weight := inx; \n"
"      aset (collation, inx, weight); \n"
"      inx := inx + 1; \n"
"    } \n"
"   collation__define (name, collation); \n"
"   log_text(\'collation__define(?, ?)\', name, collation); \n"
"   insert replacing SYS_COLLATIONS (COLL_NAME, COLL_TABLE, COLL_WIDE) values (name, collation, is_wide); \n"
"} \n";


static const char *charset_define_text =
"create procedure charset_define (in name varchar, in charset_string any, in aliases any) \n"
"{ \n"
"   declare parsed_charset any; \n"
"   name := upper (name); \n"
"   if (exists (select 1 from DB.DBA.SYS_CHARSETS where CS_NAME = name)) \n"
"     return; \n"
"   if (length (charset_string) > 255) signal ('22023', 'Charset definition is not correct', 'SR284'); \n"
"   parsed_charset := charset__define (name, charset_string, aliases); \n"
"   log_text(\'charset__define(?, ?, ?)\', name, parsed_charset, aliases); \n"
"   insert soft SYS_CHARSETS (CS_NAME, CS_TABLE, CS_ALIASES) values (name, parsed_charset, either (isnull (aliases), NULL, serialize (aliases))); \n"
"} \n";

void
ddl_std_proc_1 (const char *text, int is_public, int to_recompile)
{
  int is_stored = is_public & 0x80;
  client_connection_t * cli = DDL_STD_REENTRANT & is_public ? sqlc_client () : bootstrap_cli;
  query_t *proc = NULL;
  caddr_t err = NULL;
  caddr_t *_text = (caddr_t *) (is_stored ? box_dv_short_string (text) : text);
  if (!cli)
    cli = bootstrap_cli;
  is_public &= 0x3F;

  if (!is_stored && to_recompile && sql_proc_use_recompile)
    {
      if (NULL == (proc = sql_proc_to_recompile ((char *) _text, cli, NULL, 1)))
	{
	  proc = sql_compile ((char *) _text, cli, &err,
	      is_stored ? SQLC_DEFAULT : SQLC_QR_TEXT_IS_CONSTANT);
	}
    }
  else
    {
      proc = sql_compile ((char *) _text, cli, &err,
	is_stored ? SQLC_DEFAULT : SQLC_QR_TEXT_IS_CONSTANT);
    }
  if (err)
    {
      char short_text[60];
      strncpy (short_text, text, 59);
      short_text[59] = 0;
      log_error ("Error compiling stored procedure: %s: %s -- %s",
	  ((caddr_t *) err)[QC_ERRNO], ((caddr_t *) err)[QC_ERROR_STRING],
	  short_text);
      if (is_stored)
	dk_free_box ((box_t) _text);
      return;
    }
  if (is_public)
    sec_dd_grant (wi_inst.wi_schema,
	proc->qr_proc_name, "", 1, GR_EXECUTE, U_ID_PUBLIC);
  if (is_stored)
    {
      err = qr_quick_exec (proc, cli, NULL, NULL, 0);
      if (err)
	{
	  log_error ("Error writing the stored procedure : %s: %s -- %s",
	      ((caddr_t *) err)[QC_ERRNO], ((caddr_t *) err)[QC_ERROR_STRING],
	      text);
	  if (is_stored)
	    dk_free_box ((box_t) _text);
	  return;
	}
    }
  if (is_stored)
    {
      dk_free_box ((box_t) _text);
      qr_free (proc);
    }
}


void
ddl_std_proc (const char *text, int is_public)
{
  ddl_std_proc_1 (text, is_public, 0);
}


caddr_t bif_key_col_ddl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);

void
ddl_standard_procs (void)
{
  if (ddl_std_procs_inited)
    return;
  ddl_std_proc (proc_decoy_repl_modify_col, 1);
  ddl_std_proc (proc_decoy_repl_redo_trigs, 1);
  ddl_std_proc (gti3_text, 1);	/* For SQLGetTypeInfo */
  ddl_std_proc (gti_text, 1);	/* For SQLGetTypeInfo */
  ddl_std_proc (gtijdbc_text, 1);	/* For SQLGetTypeInfo for JDBC */
  ddl_std_proc (revoke_text, 0);
  ddl_std_proc (lg_text, 0);
  ddl_std_proc (proc_table_privileges, 1);	/* For SQLTablePrivileges */
  ddl_std_proc (proc_new_key_id, 0);
  ddl_std_proc (proc_inherit_partition, 0);
      ddl_std_proc (drop_key_proc_text, 0);
  ddl_std_proc (proc_new_col_id, 0);
  ddl_std_proc (proc_new_key_ver, 0);
  ddl_std_proc (proc_find_new_super, 0);
  ddl_std_proc (proc_obsolete_key, 0);
  ddl_std_proc (proc_owner_check, 0);
  ddl_std_proc (proc_add_col_recursive, 0);
  ddl_std_proc (proc_add_col, 1);
  ddl_std_proc (proc_modify_col, 0);
#if 0
  ddl_std_proc (proc_del_user, 0);
#endif
  ddl_std_proc (proc_user_qual, 0);
  bif_define ("__ddl_table_renamed", bif_table_renamed);
  bif_define ("__key_col_ddl", bif_key_col_ddl);
  ddl_std_proc (proc_read_table_tree, 0);
  ddl_std_proc (proc_drop_col, 1);
  ddl_std_proc (proc_null_blob, 0);
  ddl_std_proc (proc_drop_col_rec, 0);
  ddl_std_proc (proc_add_col_row, 0);
  ddl_std_proc (drop_trigger_text, 1);
  ddl_std_proc (drop_proc_text, 1);
  ddl_std_proc (stat_proc1, 1);
  ddl_std_proc (wsst, 1);
  ddl_std_proc (pk1, 0);
  ddl_std_proc (pk2, 0);
  ddl_std_proc (pk3, 0);
  ddl_std_proc (bm_proc_1, 0);
  ddl_std_proc (collation_define_text, 0);
  ddl_std_proc (charset_define_text, 0);
  ddl_std_procs_inited = 1;
}



void
ddl_sel_for_effect (const char *str)
{
  caddr_t err = NULL;
  local_cursor_t *lc;
  query_t *qr = sql_compile (str, bootstrap_cli, &err, SQLC_DEFAULT);
  if (NULL == qr)
    {
      log_error("Unable to compile SQL statement: %s", str);
      return;
    }
  err = qr_quick_exec (qr, bootstrap_cli, "", &lc, 0);
  while (lc_next (lc))
    ;
  lc_free (lc);
  qr_free (qr);
}



const char *univ_dd_text =
"create table SYS_DATA_SOURCE (DS_DSN varchar (255), DS_CONN_STR long varchar, DS_UID varchar (255), DS_PWD varchar (255), primary key (DS_DSN)) "
"create table SYS_REMOTE_TABLE (RT_NAME varchar (255), RT_DSN varchar (255), RT_REMOTE_NAME varchar (255), primary key (RT_NAME)) ";
const char *univ_dd_pt_text =
"create table SYS_PASS_THROUGH_FUNCTION (PTF_DSN varchar (255), PTF_LOCAL varchar (255), PTF_REMOTE varchar (255), primary key (PTF_DSN, PTF_LOCAL))";

const char *upd_sys_ds_table_text =
"update SYS_COLS set COL_DTP = 125 where \"TABLE\" = 'DB.DBA.SYS_DATA_SOURCE' and \"COLUMN\" = 'DS_CONN_STR'";
char *upd_sys_ds_table_text_2 =
"__ddl_changed ('DB.DBA.SYS_DATA_SOURCE')";

void
ddl_ensure_univ_tables (void)
{
  ddl_ensure_table ("DB.DBA.SYS_DATA_SOURCE", univ_dd_text);
  ddl_ensure_table ("DB.DBA.SYS_PASS_THROUGH_FUNCTION", univ_dd_pt_text);
  local_commit (bootstrap_cli); /* otherwise don in ddl_ensure_table */
}



const char *stat_proc3 =
"create procedure DB.DBA.SYS_FILL_NAME (\n"
"    in x varchar, \n"
"    in q_def varchar := 'DB', \n"
"    in o_def varchar := 'DBA') \n"
" returns varchar \n"
"{\n"
"  return sprintf ('%s.%s.%s',\n"
"      name_part (x, 0, q_def),\n"
"      name_part (x, 1, o_def),\n"
"      name_part (x, 2));\n"
"}\n";

const char *sys_k_stat_text =
"create view SYS_K_STAT as \n"
"  select KEY_TABLE, name_part (KEY_NAME, 2) as INDEX_NAME, \n"
"	key_stat (DB.DBA.SYS_FILL_NAME(KEY_TABLE), name_part (KEY_NAME, 2), 'n_landings') as LANDED,\n"
"	key_stat (DB.DBA.SYS_FILL_NAME(KEY_TABLE), name_part (KEY_NAME, 2), 'total_last_page_hits') as CONSEC,\n"
"	key_stat (DB.DBA.SYS_FILL_NAME(KEY_TABLE), name_part (KEY_NAME, 2), 'page_end_inserts') as RIGHT_EDGE,\n"
"	key_stat (DB.DBA.SYS_FILL_NAME(KEY_TABLE), name_part (KEY_NAME, 2), 'read_wait') as read_wait,\n"
"	key_stat (DB.DBA.SYS_FILL_NAME(KEY_TABLE), name_part (KEY_NAME, 2), 'write_wait') as write_wait,\n"
"	key_stat (DB.DBA.SYS_FILL_NAME(KEY_TABLE), name_part (KEY_NAME, 2), 'landing_wait') as landing_wait,\n"
"	key_stat (DB.DBA.SYS_FILL_NAME(KEY_TABLE), name_part (KEY_NAME, 2), 'pl_wait') as pl_wait\n"
"	from SYS_KEYS  where KEY_MIGRATE_TO is null\n";

const char *sys_l_stat_text =
"create view SYS_L_STAT as \n"
"  select KEY_TABLE, name_part (KEY_NAME, 2) as INDEX_NAME, \n"
"	key_stat (DB.DBA.SYS_FILL_NAME(KEY_TABLE), name_part (KEY_NAME, 2), 'lock_set') as LOCKS,\n"
"	key_stat (DB.DBA.SYS_FILL_NAME(KEY_TABLE), name_part (KEY_NAME, 2), 'lock_waits') as WAITS,\n"
"	(key_stat (DB.DBA.SYS_FILL_NAME(KEY_TABLE), name_part (KEY_NAME, 2), 'lock_waits') * 100)\n"
"	  / (key_stat (DB.DBA.SYS_FILL_NAME(KEY_TABLE), name_part (KEY_NAME, 2), 'lock_set') + 1) as WAIT_PCT,\n"
"	key_stat (DB.DBA.SYS_FILL_NAME(KEY_TABLE), name_part (KEY_NAME, 2), 'deadlocks') as DEADLOCKS,\n"
"	key_stat (DB.DBA.SYS_FILL_NAME(KEY_TABLE), name_part (KEY_NAME, 2), 'lock_escalations') as LOCK_ESC,\n"
"	key_stat (DB.DBA.SYS_FILL_NAME(KEY_TABLE), name_part (KEY_NAME, 2), 'lock_wait_time') as WAIT_MSECS\n"
"	from SYS_KEYS  where KEY_MIGRATE_TO is null\n";

const char *sys_d_stat_text =
"create view SYS_D_STAT as\n"
"  select KEY_TABLE, name_part (KEY_NAME, 2) as INDEX_NAME, \n"
"	key_stat (DB.DBA.SYS_FILL_NAME(KEY_TABLE), name_part (KEY_NAME, 2), 'touches') as TOUCHES,\n"
"	key_stat (DB.DBA.SYS_FILL_NAME(KEY_TABLE), name_part (KEY_NAME, 2), 'reads') as READS,\n"
"	(key_stat (DB.DBA.SYS_FILL_NAME(KEY_TABLE), name_part (KEY_NAME, 2), 'reads') * 100)\n"
"	  / (key_stat (DB.DBA.SYS_FILL_NAME(KEY_TABLE), name_part (KEY_NAME, 2), 'touches') + 1) as READ_PCT,\n"
"	key_stat (DB.DBA.SYS_FILL_NAME(KEY_TABLE), name_part (KEY_NAME, 2), 'n_dirty') as N_DIRTY,\n"
"	key_stat (DB.DBA.SYS_FILL_NAME(KEY_TABLE), name_part (KEY_NAME, 2), 'n_buffers') as N_BUFFERS\n"
"	from SYS_KEYS  where KEY_MIGRATE_TO is null\n";

const char * sys_col_auto_stats_text=
"create view DB.DBA.SYS_COL_AUTO_STAT as \n"
"select key_table as CSA_TABLE, \"COLUMN\" as CSA_COLUMN,  col_stat (col_id, 'n_distinct') as CSA_N_DISTINCT, col_stat (col_id, 'avg_len') as CSA_AVG_LEN, col_stat (col_id, 'n_values') as CSA_N_VALUES, key_stat (DB.DBA.SYS_FILL_NAME(KEY_TABLE), name_part (key_name, 2), 'n_est_rows') as CSA_N_ROWS\n"
"from sys_keys, sys_key_parts, sys_cols where key_is_main = 1 and key_migrate_to is null and kp_key_id = key_id and col_id = kp_col";


void
ddl_ensure_stat_tables (void)
{
  ddl_std_proc (stat_proc1, 1);
  ddl_std_proc (stat_proc3, 1);
  ddl_ensure_table ("do this always",
      "select exec (sprintf ('drop view %s', V_NAME)) from DB.DBA.SYS_VIEWS \n"
      "  where \n"
      "   V_NAME in ('DB.DBA.SYS_D_STAT', 'DB.DBA.SYS_L_STAT', 'DB.DBA.SYS_K_STAT', 'DB.DBA.SYS_COL_AUTO_STAT') and \n"
      "   strstr (blob_to_string (coalesce (V_TEXT, V_EXT)), 'SYS_FILL_NAME') is null");
  ddl_ensure_table ("do this always",
      "select exec (sprintf ('drop view %s', V_NAME)) from DB.DBA.SYS_VIEWS \n"
      "  where \n"
      "   V_NAME = 'DB.DBA.SYS_L_STAT' and \n"
      "   strstr (blob_to_string (coalesce (V_TEXT, V_EXT)), 'WAIT_MSECS') is null");
  ddl_ensure_table ("DB.DBA.SYS_K_STAT", sys_k_stat_text);
  ddl_ensure_table ("DB.DBA.SYS_L_STAT", sys_l_stat_text);
  ddl_ensure_table ("DB.DBA.SYS_D_STAT", sys_d_stat_text);
  ddl_ensure_table ("DB.DBA.SYS_COL_AUTO_STAT", sys_col_auto_stats_text);
  ddl_ensure_table ("DB.DBA.SYS_END", "create table SYS_END (K varbinary, primary key (K) clustered)");
  {
    caddr_t err;
    query_t * end_qr = sql_compile ("insert soft SYS_END (K) values (cast ('\\377\\377' as varbinary))", bootstrap_cli, &err, SQLC_DEFAULT);
    if (end_qr)
      {
	qr_quick_exec (end_qr, bootstrap_cli, "", NULL, 0);
	qr_free (end_qr);
	local_commit (bootstrap_cli);
      }
  }
}

static const char *sched_table_text =
"create table SYS_SCHEDULED_EVENT (SE_NAME varchar, "
"				SE_START datetime, "
"				SE_SQL varchar, "
"				SE_LAST_COMPLETED datetime, "
"				SE_INTERVAL integer, "
"				SE_LAST_ERROR long varchar,"
"				SE_ENABLE_NOTIFY int default 0,"
"				SE_NOTIFY varchar default null,"
"				SE_NOTIFICATION_SENT int default 0,"
"				primary key (SE_NAME)) ";

static const char *sched_alter1 =
"alter table SYS_SCHEDULED_EVENT add SE_LAST_ERROR long varchar";

static const char *sched_alter2 =
"alter table SYS_SCHEDULED_EVENT add SE_ENABLE_NOTIFY int default 0";

static const char *sched_alter3 =
"alter table SYS_SCHEDULED_EVENT add SE_NOTIFY varchar default null";

static const char *sched_alter4 =
"alter table SYS_SCHEDULED_EVENT add SE_NOTIFICATION_SENT int default 0";

static const char * scheduler_do_round_text =
#if 0
"create procedure scheduler_do_round(in n integer) \n"
"{\n"
"  declare cr cursor for  \n"
"    select SE_NAME, SE_SQL  \n"
"    from SYS_SCHEDULED_EVENT \n"
"    where SE_START <= curdatetime() and \n"
"	  (SE_LAST_COMPLETED is NULL or \n"
"	   dateadd(\'minute\', SE_INTERVAL, SE_LAST_COMPLETED) <= curdatetime()) \n"
"    order by SE_LAST_COMPLETED; \n"
"  declare _se_name, _se_sql varchar; \n"
" \n"
"  whenever not found goto over; \n"
"  open cr; \n"
"  while (1 = 1) \n"
"    {\n"
"      fetch cr into _se_name, _se_sql; \n"
"      execstr (_se_sql); \n"
"      update SYS_SCHEDULED_EVENT set SE_LAST_COMPLETED = curdatetime() \n"
"      where SE_NAME = _se_name; \n"
"    } \n"
"over: \n"
"  close cr; \n"
"  return; \n"
"}\n";
#else
"create procedure scheduler_do_round(in n integer) \n"
"{\n"
"  declare n_events, inx integer;\n"
"  declare arr, dtn any;\n"
"  declare last_chkp, achkp integer; \n"
"  dtn := curdatetime(); \n"
"  last_chkp := sys_stat ('st_chkp_last_checkpointed'); \n"
"  achkp := sys_stat ('st_chkp_autocheckpoint'); \n"
"  select count (*) into n_events\n"
"      from SYS_SCHEDULED_EVENT \n"
"      where SE_START <= dtn and SE_INTERVAL > 0 and\n"
"      (SE_LAST_COMPLETED is NULL or \n"
"       dateadd('minute', SE_INTERVAL, SE_LAST_COMPLETED) <= dtn);\n"
" \n"
"  if (n_events = 0)\n"
"    return;\n"
"  arr := make_array (n_events, 'any');\n"
"  inx := 0;\n"
"  for select SE_NAME, SE_SQL, SE_NOTIFICATION_SENT  \n"
"    from SYS_SCHEDULED_EVENT \n"
"    where SE_START <= dtn and SE_INTERVAL > 0 and\n"
"    (SE_LAST_COMPLETED is NULL or \n"
"     dateadd('minute', SE_INTERVAL, SE_LAST_COMPLETED) <= dtn) \n"
"    order by SE_LAST_COMPLETED \n"
"    do \n"
"      {\n"
"	if (inx >= n_events) \n"
"	  goto execs;\n"
"	aset (arr, inx, vector (SE_NAME, SE_SQL, SE_NOTIFICATION_SENT));\n"
"	inx := inx + 1;\n"
"      }\n"
"execs: ;\n"
"  commit work;\n"
"  registry_set ('__scheduler_do_now__', '1');\n"
"  inx := 0;\n"
"  while (inx < n_events)\n"
"    {\n"
"      declare dt, fl, notify_flag integer;\n"
"      declare st, msg, emsg varchar;\n"
"      dt := msec_time ();\n"
"      st := '00000' ;\n"
"      emsg := null; notify_flag := arr[inx][2];\n"
"      exec (aref (aref (arr, inx), 1), st, msg, vector (), 0);\n"
"      if (st <> '00000')\n"
"	{\n"
"	  fl := 4;\n"
"         emsg := msg;\n"
"	  rollback work;\n"
"	}\n"
"      else\n"
"	{\n"
"	  fl := 0; notify_flag := 0;\n"
"	  commit work;\n"
"	}\n"
"      prof_sample (aref (aref (arr, inx), 1), msec_time () - dt, 1 + fl);\n"
" \n"
"      update SYS_SCHEDULED_EVENT set SE_LAST_COMPLETED = curdatetime(), SE_LAST_ERROR = emsg, \n"
"	  SE_NOTIFICATION_SENT = notify_flag \n"
"	  where SE_NAME = aref (aref (arr, inx), 0);\n"
"      commit work;\n"
"      if (achkp > 0 and last_chkp > 0) \n"
"	{ \n"
"	  if (msec_time () - last_chkp >= achkp) \n"
"	    { \n"
"		registry_set ('__scheduler_do_now__', concat ('-', cast (inx as varchar)));\n"
"	      return; \n"
"	    } \n"
"	} \n"
"      inx := inx + 1;\n"
"    }\n"
"  DB.DBA.SCHEDULER_NOTIFY (); \n"
"  registry_set ('__scheduler_do_now__', '0');\n"
"}\n";
#endif


void
ddl_scheduler_init (void)
{
  dbe_table_t *tb;
  ddl_ensure_table("DB.DBA.SYS_SCHEDULED_EVENT", sched_table_text);
  tb = sch_name_to_table (isp_schema(NULL), "DB.DBA.SYS_SCHEDULED_EVENT");
  if (tb && tb_name_to_column (tb, "SE_NOTIFICATION_SENT"))
    ddl_std_proc(scheduler_do_round_text, 0);
}

void
ddl_scheduler_arfw_init (void)
{
  ddl_ensure_column ("SYS_SCHEDULED_EVENT", "SE_LAST_ERROR", sched_alter1, 0);
  ddl_ensure_column ("SYS_SCHEDULED_EVENT", "SE_ENABLE_NOTIFY", sched_alter2, 0);
  ddl_ensure_column ("SYS_SCHEDULED_EVENT", "SE_NOTIFY", sched_alter3, 0);
  ddl_ensure_column ("SYS_SCHEDULED_EVENT", "SE_NOTIFICATION_SENT", sched_alter4, 0);
  ddl_std_proc(scheduler_do_round_text, 0);
}

#ifdef BIF_XML


void
ddl_init_xml (void)
{
  xmls_init ();
}
#endif

static void
sch_create_table_as (query_instance_t *qi, ST * tree)
{
  static query_t *qr = NULL;
  caddr_t err = NULL;
  client_connection_t *cli = qi->qi_client;

  if (!qr)
    qr = sql_compile_static ("DB.DBA.SYS_CREATE_TABLE_AS (?, ?, ?)", bootstrap_cli, &err, SQLC_DEFAULT);

  if (err)
    sqlr_resignal (err);

  err = qr_rec_exec (qr, cli, NULL, qi, NULL, 3,
      ":0", tree->_.op.arg_1, QRP_STR,
      ":1", box_copy_tree (tree->_.op.arg_2), QRP_RAW,
      ":2", tree->_.op.arg_3, QRP_INT);

  if (err)
    sqlr_resignal (err);
}
