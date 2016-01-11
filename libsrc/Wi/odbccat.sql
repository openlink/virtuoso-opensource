--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2016 OpenLink Software
--
--  This project is free software; you can redistribute it and/or modify it
--  under the terms of the GNU General Public License as published by the
--  Free Software Foundation; only version 2 of the License, dated June 1991.
--
--  This program is distributed in the hope that it will be useful, but
--  WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
--  General Public License for more details.
--
--  You should have received a copy of the GNU General Public License along
--  with this program; if not, write to the Free Software Foundation, Inc.,
--  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
--
--
create procedure
sql_normalize_qon (in dsn varchar, inout infos any, inout qual varchar, inout owner varchar, inout name varchar)
{
--  dbg_obj_print ('normal_qon');
  -- place for sql_normalize_qon_xxx_xxx calls
  if (sql_normalize_qon_oracle_oracle (dsn, infos, qual, owner, name)) return;
  if (sql_normalize_qon_oracle_msora (dsn, infos, qual, owner, name)) return;
  if (sql_normalize_qon_infohub_dcsyb30 (dsn, infos, qual, owner, name)) return;
  if (sql_normalize_qon_viaserv_opl (dsn, infos, qual, owner, name)) return;

  return;
}
;

create procedure
sql_filter_qon (inout infos any, inout result any, in qual varchar, in owner varchar, in name varchar)
{
--  dbg_obj_print ('filter_qon', qual, owner, name);
  declare filter any;
  if (not isarray(result))
    return;

  filter := NULL;
  -- place for sql_normalize_qon_xxx_xxx calls
  if (sql_filter_qon_oracle_oracle (infos, filter, qual, owner, name)) goto foun;

  return;
foun:
--  dbg_obj_print ('filter_qon:filter1', filter);
  if (isarray(filter))
    {
      if (length (filter) > 0 and isstring (aref(filter, 0)))
	aset (filter, 0, replace (replace (replace (aref(filter, 0), '\\', '\\\\'), '%', '\\%'), '_', '\\_'));
      if (length (filter) > 1 and isstring (aref(filter, 1)))
	aset (filter, 1, replace (replace (replace (aref(filter, 1), '\\', '\\\\'), '%', '\\%'), '_', '\\_'));
      if (length (filter) > 2 and isstring (aref(filter, 2)))
	aset (filter, 2, replace (replace (replace (aref(filter, 2), '\\', '\\\\'), '%', '\\%'), '_', '\\_'));
    }
--  dbg_obj_print ('filter_qon:filter2', filter);
  if (isarray (filter))
    {
      declare inx integer;
      declare result_out, res_row any;
      inx := 0;
      result_out := NULL;
      while (inx < length (result))
	{
          res_row := aref_set_0 (result, inx);
--	  dbg_obj_print ('row', res_row);
	  if (not ((length (filter) > 0 and isstring (aref (filter, 0)) and (aref (res_row, 0) not like aref (filter, 0))) or
	      (length (filter) > 1 and isstring (aref (filter, 1)) and (aref (res_row, 1) not like aref (filter, 1))) or
	      (length (filter) > 2 and isstring (aref (filter, 2)) and (aref (res_row, 2) not like aref (filter, 2)))))
	    {
--	      dbg_obj_print ('row found', res_row);
	      if (result_out is null)
		result_out := vector (res_row);
	      else
		result_out := vector_concat (result_out, vector (res_row));
	    }
          inx := inx + 1;
	}
      result := result_out;
    }
}
;

create procedure
sql_columns (in dsn varchar, in qual varchar, in owner varchar, in name varchar, in col varchar)
{
  declare result, infos any;
  declare _qual, _owner, _name, _col varchar;
  _qual := qual;
  _owner := owner;
  _name := name;
  _col := col;
--  dbg_obj_print ('sql_columns', dsn, qual, owner, name, col);
  infos := null;
  whenever not found goto nf;
  select deserialize (DS_CONN_STR) into infos from DB.DBA.SYS_DATA_SOURCE where DS_DSN = dsn;

  sql_normalize_qon (dsn, infos, qual, owner, name);
-- place for sql_columns_pre_xxx_xxx calls

  result := _sql_columns (dsn, qual,
      sql_escape_meta_identifier (dsn, owner),
      sql_escape_meta_identifier (dsn, name),
      sql_escape_meta_identifier (dsn, col));

  sql_filter_qon (infos, result, _qual, _owner, _name);
-- place for sql_columns_post_xxx_xxx calls
  sql_columns_post_oracle_openlink (infos, result);
--  dbg_obj_print ('sql_columns result ', result);
  return result;
nf:
  signal ('HZ000', 'Bad DSN in sql_columns', 'VD073');
}
;


create procedure
sql_tables (in dsn varchar, in qual varchar, in owner varchar, in name varchar, in typ varchar)
{
  declare result, infos any;
  declare _qual, _owner, _name, _typ, _qualesc varchar;
  _qual := qual;
  _owner := owner;
  _name := name;
  _typ := typ;
--  dbg_obj_print ('sql_tables', dsn, qual, owner, name, typ);
  infos := null;
  whenever not found goto nf;
  select deserialize (DS_CONN_STR) into infos from DB.DBA.SYS_DATA_SOURCE where DS_DSN = dsn;

  sql_normalize_qon (dsn, infos, qual, owner, name);
-- place for sql_tables_pre_xxx_xxx calls
  if (1 = sql_tables_pre_infohub_dcsyb30 (infos, typ));
  if (1 = sql_tables_pre_excel_drv (infos, typ));

  if (get_keyword (200, infos, 2) > 2)
    _qualesc := sql_escape_meta_identifier (dsn, qual);
  else
    _qualesc := qual;

  result := _sql_tables (dsn,
	      _qualesc,
	      sql_escape_meta_identifier (dsn, owner),
	      sql_escape_meta_identifier (dsn, name),
	      typ);

  sql_filter_qon (infos, result, _qual, _owner, _name);
-- place for sql_tables_post_xxx_xxx calls
  if (1 = sql_tables_post_infohub_dcsyb30 (infos, result, _typ));
  if (1 = sql_tables_post_excel_drv (dsn, infos, result, _typ));
  if (1 = sql_tables_post_progress_win_openlink (infos, result, _typ));
--  dbg_obj_print ('sql_tables result ', result);
  return result;
nf:
  signal ('HZ000', 'Bad DSN in sql_tables', 'VD074');
}
;


create procedure
sql_primary_keys (in dsn varchar, in qual varchar, in owner varchar, in name varchar)
{
  declare result, infos any;
  declare _qual, _owner, _name varchar;
  _qual := qual;
  _owner := owner;
  _name := name;
--  dbg_obj_print ('sql_primary_keys', dsn, qual, owner, name);
  infos := null;
  whenever not found goto nf;
  select deserialize (DS_CONN_STR) into infos from DB.DBA.SYS_DATA_SOURCE where DS_DSN = dsn;

  sql_normalize_qon (dsn, infos, qual, owner, name);
-- place for sql_primary_keys_pre_xxx_xxx calls

  result := _sql_primary_keys (dsn, qual, owner, name);

  sql_filter_qon (infos, result, _qual, _owner, _name);
-- place for sql_primary_keys_post_xxx_xxx calls
--  dbg_obj_print ('sql_primary_keys result ', result);
  return result;
nf:
  signal ('HZ000', 'Bad DSN in sql_primary_keys', 'VD075');
}
;


create procedure
sql_statistics (in dsn varchar, in qual varchar, in owner varchar, in name varchar, in uniqu integer, in acc integer)
{
  declare result, infos any;
  declare _qual, _owner, _name varchar;
  declare _uniqu, _acc integer;
  _qual := qual;
  _owner := owner;
  _name := name;
  _uniqu := uniqu;
  _acc := acc;
--  dbg_obj_print ('sql_statistics', dsn, qual, owner, name, 'unique=', uniqu, 'acc=', acc);
  infos := null;
  whenever not found goto nf;
  select deserialize (DS_CONN_STR) into infos from DB.DBA.SYS_DATA_SOURCE where DS_DSN = dsn;

  sql_normalize_qon (dsn, infos, qual, owner, name);
-- place for sql_statistics_pre_xxx_xxx calls

  result := _sql_statistics (dsn, qual, owner, name, uniqu, acc);

  sql_filter_qon (infos, result, _qual, _owner, _name);
-- place for sql_statistics_xxx_xxx calls
--  dbg_obj_print ('sql_statistics result ', result);
  return result;
nf:
  signal ('HZ000', 'Bad DSN in sql_statistics', 'VD076');
}
;


create procedure
sql_procedures (in dsn varchar, in qual varchar, in owner varchar, in name varchar)
{
  declare result, infos any;
  declare _qual, _owner, _name varchar;
  _qual := qual;
  _owner := owner;
  _name := name;
--  dbg_obj_print ('sql_procedures', dsn, qual, owner, name);
  infos := null;
  whenever not found goto nf;
  select deserialize (DS_CONN_STR) into infos from DB.DBA.SYS_DATA_SOURCE where DS_DSN = dsn;

  sql_normalize_qon (dsn, infos, qual, owner, name);
-- place for sql_procedures_xxx_xxx calls

  result := _sql_procedures (dsn, qual,
      sql_escape_meta_identifier (dsn, owner),
      sql_escape_meta_identifier (dsn, name));

  sql_filter_qon (infos, result, _qual, _owner, _name);
-- place for sql_procedures_post_xxx_xxx calls
--  dbg_obj_print ('sql_procedures result ', result);
  return result;
nf:
  signal ('HZ000', 'Bad DSN in sql_procedures', 'VD077');
}
;


create procedure
sql_procedure_cols (in dsn varchar, in qual any, in owner any, in name varchar, in col varchar)
{
  declare result, infos any;
  declare _qual, _owner, _name, _col varchar;
  _qual := qual;
  _owner := owner;
  _name := name;
  _col := col;
--dbg_obj_print ('sql_procedures', dsn, qual, owner, name);
  if (qual = 0) qual := '';
  if (owner = 0) owner := '';
  infos := null;
  whenever not found goto nf;
  select deserialize (DS_CONN_STR) into infos from DB.DBA.SYS_DATA_SOURCE where DS_DSN = dsn;

  sql_normalize_qon (dsn, infos, qual, owner, name);
-- place for sql_procedures_xxx_xxx calls

  result := _sql_procedure_columns (dsn, qual, owner, name, col);

  sql_filter_qon (infos, result, _qual, _owner, _name);
-- place for sql_procedures_post_xxx_xxx calls
--  dbg_obj_print ('sql_procedures result ', result);
  return result;
nf:
  signal ('HZ000', 'Bad DSN in sql_procedures', 'VD077');
}
;

--!AWK PLBIF sql_foreign_keys
create procedure
sql_foreign_keys (in dsn varchar, in qual varchar, in owner varchar, in name varchar, in qual2 varchar, in owner2 varchar, in name2 varchar)
{
  declare result, infos any;
  declare _qual, _owner, _name varchar;
  _qual := qual;
  _owner := owner;
  _name := name;
  infos := null;
  whenever not found goto nf;
  select deserialize (DS_CONN_STR) into infos from DB.DBA.SYS_DATA_SOURCE where DS_DSN = dsn;

  sql_normalize_qon (dsn, infos, qual, owner, name);
  sql_normalize_qon (dsn, infos, qual2, owner2, name2);

  result := _sql_foreign_keys (dsn, qual, owner, name, qual2, owner2, name2);

  sql_filter_qon (infos, result, _qual, _owner, _name);
  return result;
nf:
  signal ('HZ000', 'Invalid DSN in sql_foreign_keys', 'VD075');
}
;


-- KLUDGES

-- ORACLE mixed case kludge with native drivers
-- should pass the table name as NULL to get all and then filter client side

create procedure __virt_sql_qon_is_oracle_oracle (inout infos any,
    inout qual varchar, inout owner varchar, inout name varchar)
{
  declare dbms_name, driver_name, driver_ver varchar;
  declare ver_arr any;
  dbms_name := upper (get_keyword (17, infos, ''));
  driver_name := upper (get_keyword (6, infos, ''));
  driver_ver := upper (get_keyword (7, infos, ''));

  if (upper (dbms_name) like '%ORACLE%' and (driver_name like 'SQOCI%.DLL' or driver_name like 'SQORA32%.DLL'))
    {
      if (isstring (driver_ver))
	{
	  ver_arr := split_and_decode (driver_ver,0,'\0\0.');
	  if (isarray (ver_arr) and length (ver_arr) >= 3)
	    {
	      declare v1, v2, v3 integer;
	      v1 := atoi (ver_arr [0]);
	      v2 := atoi (ver_arr [1]);
	      v3 := atoi (ver_arr [2]);
	      if (v1 > 8)
		goto check_special_chars;
	      if (v1 = 8)
		{
		  if (v2 > 1)
		    goto check_special_chars;
		  if (v2 = 1)
		    {
		      if (v3 >= 705)
			goto check_special_chars;
		    }
		}
	    }
	}
      return 1;
    }
  else
    return 0;

check_special_chars:
  if (isstring (qual) and (strstr (qual, '\\_') or strstr (qual, '\\%')))
    return 1;
  if (isstring (owner) and (strstr (owner, '\\_') or strstr (owner, '\\%')))
    return 1;
  if (isstring (name) and (strstr (name, '\\_') or strstr (name, '\\%')))
    return 1;
  return 0;
}
;

create procedure
sql_normalize_qon_oracle_oracle (in dsn varchar, inout infos any, inout qual varchar, inout owner varchar, inout name varchar)
{
  if (__virt_sql_qon_is_oracle_oracle (infos, qual, owner, name) > 0)
    {
      qual := NULL;
--      dbg_obj_print ('oracle FOUND, name=null');
      if (name is not null)
	name := NULL;
      else if (owner is not null)
	owner := NULL;
      return 1;
    }
  return 0;
}
;

create procedure
sql_filter_qon_oracle_oracle (inout infos any, inout filter any, in qual varchar, in owner varchar, in name varchar)
{
  filter := NULL;
  if (__virt_sql_qon_is_oracle_oracle (infos, qual, owner, name) > 0)
    {
      filter := vector (qual, owner, name);
---      dbg_obj_print ('oracle FOUND', filter);
      return 1;
    }
  return 0;
}
;

-- ORACLE mixed case kludge with MS drivers
-- should pass the table name in double quotes

create procedure
sql_normalize_qon_oracle_msora (in dsn varchar, inout infos any, inout qual varchar, inout owner varchar, inout name varchar)
{
  declare dbms_name, driver_name varchar;
  dbms_name := upper (get_keyword (17, infos, ''));
  driver_name := upper (get_keyword (6, infos, ''));

  if (upper (dbms_name) like '%ORACLE%' and upper (driver_name) like 'MSORCL32.DLL')
    {
      qual := NULL;
      if (isstring (owner) and length (owner) > 0) owner := concat ('"', owner, '"');
      if (isstring (name) and length (name) > 0) name := concat ('"', name, '"');
--      dbg_obj_print ('orams FOUND, quoting', qual, owner, name);
      return 1;
    }
  return 0;
}
;


--DBMS NAME:INFOHUB
--SQL_DBMS_VER = "01.00.0000 2.3.0"
--SQL_DRIVER_NAME = "dcsyb30.dll"
--SQL_DRIVER_ODBC_VER = "03.00"
--SQL_DRIVER_VER = "3.01.0008"
-- This should call SQLTables with no TableType and in autocommit for the catalog calls
create procedure
sql_normalize_qon_infohub_dcsyb30 (in dsn varchar, inout infos any, inout qual varchar, inout owner varchar, inout name varchar)
{
  declare dbms_name, driver_name varchar;
  dbms_name := upper (get_keyword (17, infos, ''));
  driver_name := upper (get_keyword (6, infos, ''));

  if (dbms_name like '%INFOHUB%' and driver_name like 'DCSYB30.DLL')
    {
--      dbg_obj_print ('INFOHUB found. going autocommit');
      vd_autocommit (dsn, 1);
      return 1;
    }
  return 0;
}
;

create procedure
sql_tables_pre_infohub_dcsyb30 (inout infos any, inout typ varchar)
{
  declare dbms_name, driver_name varchar;
  dbms_name := upper (get_keyword (17, infos, ''));
  driver_name := upper (get_keyword (6, infos, ''));

  if (dbms_name like '%INFOHUB%' and driver_name like 'DCSYB30.DLL')
    {
--      dbg_obj_print ('INFOHUB found. type is NULL. It was:', typ);
      typ := NULL;
      return 1;
    }
  return 0;
}
;


create procedure
sql_tables_post_infohub_dcsyb30 (inout infos any, inout result any, inout typ varchar)
{
  declare dbms_name, driver_name varchar;
  dbms_name := upper (get_keyword (17, infos, ''));
  driver_name := upper (get_keyword (6, infos, ''));

  if (dbms_name like '%INFOHUB%' and driver_name like 'DCSYB30.DLL')
    {
--      dbg_obj_print ('INFOHUB found. Type', typ);
      declare broken_typ any;
      declare inx, inx1, is_in integer;
      declare result_out, res_row any;

      if (0 = isstring (typ) or length (typ) < 1)
	return 1;
      broken_typ := split_and_decode (typ, 1, '\0'',');
--      dbg_obj_print ('INFOHUB found. Broken Type', broken_typ);
      inx := 0;
      result_out := NULL;

      while (inx < length (result))
	{
          res_row := aref_set_0 (result, inx);
          inx1 := 0;
          is_in := 0;
--	  dbg_obj_print ('INFOHUB row:', res_row);
--	  dbg_obj_print ('INFOHUB left', aref (res_row, 3));
          while (inx1 < length (broken_typ))
	    {
--	      dbg_obj_print ('INFOHUB right', trim (aref (broken_typ, inx1)));
	      if (upper (aref (res_row, 3)) like trim (aref (broken_typ, inx1)))
		{
		  is_in := 1;
	          inx1 := length (broken_typ);
		}
              inx1 := inx1 + 1;
	    }
	  if (is_in)
	    {
--	      dbg_obj_print ('INFOHUB found. Row found', res_row);
	      if (result_out is null)
		result_out := vector (res_row);
	      else
		result_out := vector_concat (result_out, vector (res_row));
	    }
          inx := inx + 1;
	}
      result := result_out;
      return 1;
    }
  return 0;
}
;


--DBMS NAME:ORACLE
--SQL_DRIVER_NAME = "olod3032.dll"
-- or SQL_DRIVER_NAME = "oplodbc.so"
-- This changes the 12 SQL_TYPE for FLOAT to 8 (SQL_DOUBLE)
create procedure sql_columns_post_oracle_openlink (inout infos any, inout result any)
{
  declare dbms_name, driver_name varchar;
  dbms_name := upper (get_keyword (17, infos, ''));
  driver_name := upper (get_keyword (6, infos, ''));

  if (upper (dbms_name) like '%ORACLE%' and (driver_name like 'OLOD3032.DLL' or driver_name like 'OPLODBC.SO%'))
    {
--      dbg_obj_print ('In the OpenLink oracle kludge');
      declare row_inx integer;
      row_inx := 0;
      while (row_inx < length (result))
        {
          declare row_data any;
          declare data_type integer;
          declare type_name varchar;

          row_data := aref (result, row_inx);
          data_type := cast (aref (row_data, 4) as integer);
          type_name := cast (aref (row_data, 5) as varchar);
          if (data_type = 12 and type_name = 'FLOAT')
            {
--              dbg_obj_print ('Fixing row ', row_inx, ' col_name=', aref (row_data, 3));
              aset (row_data, 4, 8);
      	      aset (result, row_inx, row_data);
            }
          row_inx := row_inx + 1;
        }
--      dbg_obj_print ('result : ', result);
    }
}
;

--DBMS NAME:PROGRESS
--DRIVER NAME:olod4032.dll
-- This should filter the SQLTables results as the table_type has no effect

create procedure
sql_tables_post_progress_win_openlink (inout infos any, inout result any, inout typ varchar)
{
  declare dbms_name, driver_name varchar;
  dbms_name := upper (get_keyword (17, infos, ''));
  driver_name := upper (get_keyword (6, infos, ''));

  if (dbms_name like '%PROGRESS%' and driver_name like 'OLOD4032.DLL')
    {
--      dbg_obj_print ('PROGRESS_OPL found. Type', typ);
      declare broken_typ any;
      declare inx, inx1, is_in integer;
      declare result_out, res_row any;

      if (0 = isstring (typ) or length (typ) < 1)
	return 1;
      broken_typ := split_and_decode (typ, 1, '\0'',');
--      dbg_obj_print ('PROGRESS_OPL found. Broken Type', broken_typ);
      inx := 0;
      result_out := NULL;

      while (inx < length (result))
	{
          res_row := aref_set_0 (result, inx);
          inx1 := 0;
          is_in := 0;
--	  dbg_obj_print ('PROGRESS_OPL row:', res_row);
--	  dbg_obj_print ('PROGRESS_OPL left', aref (res_row, 3));
          while (inx1 < length (broken_typ))
	    {
--	      dbg_obj_print ('PROGRESS_OPL right', trim (aref (broken_typ, inx1)));
	      if (upper (aref (res_row, 3)) like trim (aref (broken_typ, inx1)))
		{
		  is_in := 1;
	          inx1 := length (broken_typ);
		}
              inx1 := inx1 + 1;
	    }
	  if (is_in)
	    {
--	      dbg_obj_print ('PROGRESS_OPL found. Row found', res_row);
	      if (result_out is null)
		result_out := vector (res_row);
	      else
		result_out := vector_concat (result_out, vector (res_row));
	    }
          inx := inx + 1;
	}
      result := result_out;
      return 1;
    }
  return 0;
}
;

--DBMS NAME:Excel trough Jet
--DRIVER NAME:ODBCJT32.DLL
-- This should filter the SQLTables results as the table_type has no effect
-- It also will filter out "Phantoms" - tables with no columns reported.

create procedure
sql_tables_post_excel_drv (in dsn varchar, inout infos any, inout result any, inout typ varchar)
{
  declare dbms_name, driver_name varchar;
  dbms_name := upper (get_keyword (17, infos, ''));
  driver_name := upper (get_keyword (6, infos, ''));

  if (dbms_name like '%EXCEL%' and driver_name like 'ODBCJT32.DLL')
    {
--      dbg_obj_print ('EXCEL found. Type', typ);
      declare broken_typ any;
      declare inx, inx1, is_in integer;
      declare result_out, res_row any;

      if (0 = isstring (typ) or length (typ) < 1)
	return 1;
      broken_typ := split_and_decode (typ, 1, '\0'',');
--      dbg_obj_print ('EXCEL found. Broken Type', broken_typ);
      inx := 0;
      result_out := NULL;

      while (inx < length (result))
	{
          res_row := aref_set_0 (result, inx);
          inx1 := 0;
          is_in := 0;
--	  dbg_obj_print ('EXCEL row:', res_row);
--	  dbg_obj_print ('EXCEL left', aref (res_row, 3));
          while (inx1 < length (broken_typ))
	    {
--	      dbg_obj_print ('EXCEL right', trim (aref (broken_typ, inx1)));
	      if (upper (aref (res_row, 3)) like trim (aref (broken_typ, inx1)))
		{
		  is_in := 1;
	          inx1 := length (broken_typ);
		}
              inx1 := inx1 + 1;
	    }
	  if (is_in)
	    {
--	      dbg_obj_print ('EXCEL found. Row found', res_row);
    	      declare cols any;
	      cols := sql_columns (dsn, null, null, aref (res_row, 2), null);
              if (cols is not null and length (cols) > 0)
	        {
		  if (result_out is null)
		    result_out := vector (res_row);
		  else
		    result_out := vector_concat (result_out, vector (res_row));
		}
	    }
          inx := inx + 1;
	}
      result := result_out;
      return 1;
    }
  return 0;
}
;


create procedure
sql_tables_pre_excel_drv (inout infos any, inout typ varchar)
{
  declare dbms_name, driver_name varchar;
  dbms_name := upper (get_keyword (17, infos, ''));
  driver_name := upper (get_keyword (6, infos, ''));

  if (dbms_name like '%EXCEL%' and driver_name like 'ODBCJT32.DLL')
    {
      typ := NULL;
      return 1;
    }

  return 0;
}
;

-- ViaServe escaping of identifiers for catalog functions through UDA
-- should not escape _ & ? in the catalog names
--DBMS NAME: ViaSQL
--DRIVER NAME:olod4032.dll or oplodbc*.so

create procedure
sql_normalize_qon_viaserv_opl (in dsn varchar, inout infos any, inout qual varchar, inout owner varchar, inout name varchar)
{
  declare dbms_name, driver_name, driver_ver varchar;
  declare ver_arr any;
  dbms_name := upper (get_keyword (17, infos, ''));
  driver_name := upper (get_keyword (6, infos, ''));
  driver_ver := upper (get_keyword (7, infos, ''));

  if (upper (dbms_name) like '%VIASQL%' and (driver_name like 'OLOD40%.DLL' or driver_name like 'OPL%.so'))
    {
      --dbg_obj_print ('ViaServ FOUND, unescape');
      if (isstring (qual))
	{
	  qual := replace (qual, '\\%', '%');
	  qual := replace (qual, '\\_', '_');
	}
      if (isstring (owner))
	{
	  owner := replace (owner, '\\%', '%');
	  owner := replace (owner, '\\_', '_');
	}
      if (isstring (name))
	{
	  name := replace (name, '\\%', '%');
	  name := replace (name, '\\_', '_');
	}
      return 1;
    }
  return 0;
}
;

