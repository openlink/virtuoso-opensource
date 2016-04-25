/*
 *  sqlrrun.c
 *
 *  $Id$
 *
 *  VDB SQL Remote query execution.
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

#include "Dk.h"
#include "odbcinc.h"
#include "sqlnode.h"
#include "sqlopcod.h"
#include "sqlbif.h"
#include "security.h"
#include "remote.h"
#include "list2.h"
#include "date.h"
#include "datesupp.h"
#include "libutil.h"
#if !defined (__APPLE__)
#include <wchar.h>
#endif
#include "multibyte.h"
#include "srvmultibyte.h"
#include "sqlver.h"
#include "statuslog.h"
#include "sqlpar.h"
#include "sqltype.h"
#include "virtext.h"
#include "virtpwd.h"
#include "virtpwd.h"
#include "xmltree.h"

#define SQL_NO_TOTAL			(-4)

#ifdef VIRTTP
#include "2pc.h"
#endif
#include "msdtc.h"

id_hash_t *remote_dss;
id_hash_t *remote_tables;
id_hash_t *remote_procs;
dk_mutex_t *r_mtx;

caddr_t *odbc_error_ex = NULL;
char *vdb_odbc_error_file = NULL;
char *vdb_trim_trailing_spaces = NULL;
dk_hash_t *vdb_clients;		/* those cli_connection_t's with owned caches of rds_connection_t's */
dk_mutex_t *vdb_connect_mtx = NULL;
int32 vdb_client_fixed_thread = 1;
int32 vdb_serialize_connect = 0;
int rc_max_stmts = 50;
int remote_pk_not_unique = 0;
int rst_alloc_count;
int rst_free_count;
long rds_active_cons_freed = 0;
long rds_disconnect_timeout = 1000000;	/* 1000 seconds */
long reconnect_on_vdb_error = 1;
long vdb_no_stmt_cache = 0;
long vdb_use_global_pool = 0;
remote_ds_t *local_rds = NULL;

void odbc_cat_init (void);




remote_ds_t *
find_remote_ds (const char *name, int create)
{
  return NULL;
}


int
vd_dv_to_sql_type (int dv)
{
  switch (dv)
    {
    case DV_SHORT_INT:
      return SQL_SMALLINT;
    case DV_LONG_INT:
      return SQL_INTEGER;
    case DV_DOUBLE_FLOAT:
      return SQL_DOUBLE;
    case DV_NUMERIC:
      return SQL_DECIMAL;
    case DV_SINGLE_FLOAT:
      return SQL_REAL;
    case DV_BLOB:
      return SQL_LONGVARCHAR;
    case DV_BLOB_BIN:
      return SQL_LONGVARBINARY;
    case DV_BLOB_WIDE:
      return SQL_WLONGVARCHAR;
    case DV_DATE:
      return SQL_DATE;
    case DV_TIMESTAMP:
    case DV_DATETIME:
      return SQL_TIMESTAMP;
    case DV_TIME:
      return SQL_TIME;
    case DV_BIN:
      return SQL_VARBINARY;
    case DV_WIDE:
    case DV_LONG_WIDE:
      return SQL_WVARCHAR;
    default:
      return SQL_VARCHAR;
    }
}


remote_table_t *
find_remote_table (char *name, int create)
{
  return NULL;
}


#define B_SET(p,v) dk_free_tree (p), p = v


caddr_t
bif_remote_table (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return NULL;
}




caddr_t
find_pass_through_function (remote_ds_t * rds, int do_mutex, char *ref_name, char *q_def, char *o_def, caddr_t * found_remote)
{
  return NULL;
}


caddr_t
bif_pass_through_function (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return NULL;
}


remote_proc_t *
find_remote_proc (char *name, int create)
{
  return NULL;
}





static caddr_t
bif_proc_is_remote (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{

  return (caddr_t) box_num (0);
}


int
rds_supports_sql_type (remote_ds_t * rds, long sql_type)
{
  return 0;
}

caddr_t
rds_get_info (remote_ds_t * rds, int finfo)
{
  return NULL;
}



caddr_t
bif_vdd_set_password (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return NULL;
}




static caddr_t
bif_vdd_measure_rpc_time (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return NULL;
}



static caddr_t
bif_vdd_init (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return NULL;
}


void
remote_init (int cl_reinit)
{
  bif_define ("vdd_init", bif_vdd_init);
  bif_define ("vdd_remote_table", bif_remote_table);
  bif_define ("vdd_pass_through_function", bif_pass_through_function);
  bif_define_ex ("proc_is_remote", bif_proc_is_remote, BMD_RET_TYPE, &bt_integer, BMD_DONE);
  bif_define ("vdd_set_password", bif_vdd_set_password);
  bif_define_ex ("vdd_measure_rpc_time", bif_vdd_measure_rpc_time, BMD_RET_TYPE, &bt_float, BMD_DONE);


  odbc_cat_init ();


  udt_ses_init ();

  ddl_ensure_univ_tables ();
  {
    NEW_VARZ (remote_ds_t, rds);
    rds->rds_dsn = box_string ("__local");
    rds->rds_pass_through_funcs = id_str_hash_create (10);
    rds->rds_pass_through_funcs_mtx = mutex_allocate ();
    local_rds = rds;
    local_rds->rds_connstr = list (2, box_num (SQL_DBMS_NAME), box_dv_short_string (PRODUCT_DBMS));
    if (MSDTC_IS_LOADED)
      local_rds->rds_mts_connections = resource_allocate (1, NULL, NULL, NULL, 0);
  }
}



/*
 *  Define because many funcs compare functions to this pointer. Saves ifdefs
 */
void
remote_table_source_input (remote_table_source_t * rts, caddr_t * inst, caddr_t * state)
{
  GPF_T;
}


void
DoSQLError (SQLHDBC hdbc, SQLHSTMT hstmt)
{
}
