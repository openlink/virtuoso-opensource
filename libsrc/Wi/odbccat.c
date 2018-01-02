/*
 *  odbccat.c
 *
 *  $Id$
 *
 *  ODBC Catalogs
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

#include "odbcinc.h"
#include "sqlnode.h"
#include "sqlbif.h"
#include "datesupp.h"
#include "remote.h"
#include "libutil.h"
#include "statuslog.h"
#ifdef VIRTTP
#include "2pc.h"
#endif

unsigned long vdb_oracle_catalog_fix = 0;

#define NO_VDB \
	sqlr_new_error ("42000", "VD999", "This build does not include virtual database support."); \
	return NULL;



caddr_t
bif_sql_escape_meta_identifier (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  NO_VDB;
}



caddr_t
bif_sql_unescape_meta_identifier (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  NO_VDB;
}





static caddr_t
bif_sql_tables (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  NO_VDB;
}


static caddr_t
bif_sql_columns (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  NO_VDB;
}


static caddr_t
bif_sql_primary_keys (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  NO_VDB;
}


static caddr_t
bif_sql_foreign_keys (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  NO_VDB;
}


static caddr_t
bif_sql_special_columns (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  NO_VDB;
}


static caddr_t
bif_sql_statistics (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  NO_VDB;
}




caddr_t
bif_sql_data_sources (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  NO_VDB;
}


static caddr_t
bif_sql_procedures (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  NO_VDB;
}


static caddr_t
bif_sql_procedure_columns (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  NO_VDB;
}


static caddr_t
bif_sql_gettypeinfo (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  NO_VDB;
}


static caddr_t
bif_sql_transact (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  NO_VDB;
}


static caddr_t
bif_vd_autocommit (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  NO_VDB;
}


#ifdef HAVE_ODBCINST_H
static caddr_t
bif_sql_remove_dsn_from_ini (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  NO_VDB;
}


static caddr_t
bif_sql_driver_connect (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  NO_VDB;
}


static caddr_t
bif_sql_get_installed_drivers (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  NO_VDB;
}


static caddr_t
bif_sql_config_data_sources (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  NO_VDB;
}


static caddr_t
bif_sql_get_private_profile_string (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  NO_VDB;
}


static caddr_t
bif_sql_write_private_profile_string (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  NO_VDB;
}


static caddr_t
bif_sql_write_file_dsn (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  NO_VDB;
}
#endif

void
odbc_cat_init (void)
{

  bif_define_ex ("_sql_columns", bif_sql_columns, BMD_RET_TYPE, &bt_any, BMD_DONE);
  bif_define_ex ("_sql_tables", bif_sql_tables, BMD_RET_TYPE, &bt_any, BMD_DONE);
  bif_define_ex ("_sql_primary_keys", bif_sql_primary_keys, BMD_RET_TYPE, &bt_any, BMD_DONE);
  bif_define_ex ("_sql_foreign_keys", bif_sql_foreign_keys, BMD_RET_TYPE, &bt_any, BMD_DONE);
  bif_define_ex ("sql_special_columns", bif_sql_special_columns, BMD_RET_TYPE, &bt_any, BMD_DONE);
  bif_define_ex ("_sql_statistics", bif_sql_statistics, BMD_RET_TYPE, &bt_any, BMD_DONE);
  bif_define_ex ("sql_data_sources", bif_sql_data_sources, BMD_RET_TYPE, &bt_any, BMD_DONE);
  bif_define_ex ("sql_escape_meta_identifier", bif_sql_escape_meta_identifier, BMD_RET_TYPE, &bt_any, BMD_DONE);
  bif_define_ex ("sql_unescape_meta_identifier", bif_sql_unescape_meta_identifier, BMD_RET_TYPE, &bt_any, BMD_DONE);
  bif_define_ex ("_sql_procedures", bif_sql_procedures, BMD_RET_TYPE, &bt_any, BMD_DONE);
  bif_define_ex ("_sql_procedure_columns", bif_sql_procedure_columns, BMD_RET_TYPE, &bt_any, BMD_DONE);
  bif_define_ex ("sql_transact", bif_sql_transact, BMD_RET_TYPE, &bt_integer, BMD_DONE);

  bif_define_ex ("sql_gettypeinfo", bif_sql_gettypeinfo, BMD_ALIAS, "sql_get_type_info", BMD_DONE);
  bif_define ("vd_autocommit", bif_vd_autocommit);

#ifdef HAVE_ODBCINST_H
  bif_define_ex ("sql_remove_dsn_from_ini", bif_sql_remove_dsn_from_ini, BMD_RET_TYPE, &bt_any, BMD_DONE);
  bif_define_ex ("sql_get_installed_drivers", bif_sql_get_installed_drivers, BMD_RET_TYPE, &bt_any, BMD_DONE);
  bif_define_ex ("sql_config_data_sources", bif_sql_config_data_sources, BMD_RET_TYPE, &bt_any, BMD_DONE);
  bif_define_ex ("sql_get_private_profile_string", bif_sql_get_private_profile_string, BMD_RET_TYPE, &bt_any, BMD_DONE);
  bif_define_ex ("sql_write_private_profile_string", bif_sql_write_private_profile_string, BMD_RET_TYPE, &bt_any, BMD_DONE);
  bif_define_ex ("sql_write_file_dsn", bif_sql_write_file_dsn, BMD_RET_TYPE, &bt_any, BMD_DONE);
  bif_define_ex ("sql_driver_connect", bif_sql_driver_connect, BMD_RET_TYPE, &bt_any, BMD_DONE);
#endif

  sqls_define_vdb ();
}
