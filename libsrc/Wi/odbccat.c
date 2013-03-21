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
 *  Copyright (C) 1998-2013 OpenLink Software
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

  bif_define_typed ("_sql_columns", bif_sql_columns, &bt_any);
  bif_define_typed ("_sql_tables", bif_sql_tables, &bt_any);
  bif_define_typed ("_sql_primary_keys", bif_sql_primary_keys, &bt_any);
  bif_define_typed ("_sql_foreign_keys", bif_sql_foreign_keys, &bt_any);
  bif_define_typed ("sql_special_columns", bif_sql_special_columns, &bt_any);
  bif_define_typed ("_sql_statistics", bif_sql_statistics, &bt_any);
  bif_define_typed ("sql_data_sources", bif_sql_data_sources, &bt_any);
  bif_define_typed ("sql_escape_meta_identifier", bif_sql_escape_meta_identifier, &bt_any);
  bif_define_typed ("sql_unescape_meta_identifier", bif_sql_unescape_meta_identifier, &bt_any);
  bif_define_typed ("_sql_procedures", bif_sql_procedures, &bt_any);
  bif_define_typed ("_sql_procedure_columns", bif_sql_procedure_columns, &bt_any);
  bif_define_typed ("sql_transact", bif_sql_transact, &bt_integer);

  bif_define ("sql_gettypeinfo", bif_sql_gettypeinfo);
  bif_define ("sql_get_type_info", bif_sql_gettypeinfo);  /* backward compatibility */
  bif_define ("vd_autocommit", bif_vd_autocommit);

#ifdef HAVE_ODBCINST_H
  bif_define_typed ("sql_remove_dsn_from_ini", bif_sql_remove_dsn_from_ini, &bt_any);
  bif_define_typed ("sql_get_installed_drivers", bif_sql_get_installed_drivers, &bt_any);
  bif_define_typed ("sql_config_data_sources", bif_sql_config_data_sources, &bt_any);
  bif_define_typed ("sql_get_private_profile_string", bif_sql_get_private_profile_string, &bt_any);
  bif_define_typed ("sql_write_private_profile_string", bif_sql_write_private_profile_string, &bt_any);
  bif_define_typed ("sql_write_file_dsn", bif_sql_write_file_dsn, &bt_any);
  bif_define_typed ("sql_driver_connect", bif_sql_driver_connect, &bt_any);
#endif

  sqls_define_vdb ();
}
