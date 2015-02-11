--
--  oledb.sql
--
--  $Id$
--
--  VIRTOLEDB supporting procedures.
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2015 OpenLink Software
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

--
-- OLEDB Data Types:
--
-- DBTYPE_EMPTY		= 0,
-- DBTYPE_NULL		= 1,
-- DBTYPE_I2		= 2,
-- DBTYPE_I4		= 3,
-- DBTYPE_R4		= 4,
-- DBTYPE_R8		= 5,
-- DBTYPE_CY		= 6,
-- DBTYPE_DATE		= 7,
-- DBTYPE_BSTR		= 8,
-- DBTYPE_IDISPATCH	= 9,
-- DBTYPE_ERROR		= 10,
-- DBTYPE_BOOL		= 11,
-- DBTYPE_VARIANT	= 12,
-- DBTYPE_IUNKNOWN	= 13,
-- DBTYPE_DECIMAL	= 14,
-- DBTYPE_UI1		= 17,
-- DBTYPE_I1		= 16,
-- DBTYPE_UI2		= 18,
-- DBTYPE_UI4		= 19,
-- DBTYPE_I8		= 20,
-- DBTYPE_UI8		= 21,
-- DBTYPE_FILETIME	= 64,
-- DBTYPE_GUID		= 72,
-- DBTYPE_BYTES		= 128,
-- DBTYPE_STR		= 129,
-- DBTYPE_WSTR		= 130,
-- DBTYPE_NUMERIC	= 131,
-- DBTYPE_UDT		= 132,
-- DBTYPE_DBDATE	= 133,
-- DBTYPE_DBTIME	= 134,
-- DBTYPE_DBTIMESTAMP	= 135,
-- DBTYPE_HCHAPTER	= 136,
-- DBTYPE_PROPVARIANT	= 138,
-- DBTYPE_VARNUMERIC	= 139,
-- DBTYPE_VECTOR	= 0x1000,
-- DBTYPE_ARRAY		= 0x2000,
-- DBTYPE_BYREF		= 0x4000,
-- DBTYPE_RESERVED	= 0x8000
--
--
-- The SEARCHABLE Column Values:
--
-- DB_UNSEARCHABLE	0x01
-- DB_LIKE_ONLY		0x02
-- DB_ALL_EXCEPT_LIKE	0x03
-- DB_SEARCHABLE	0x04
--
--
-- DBCOLUMNFLAGS:
--
-- DBCOLUMNFLAGS_ISBOOKMARK		0x1		1
-- DBCOLUMNFLAGS_MAYDEFER		0x2		2
-- DBCOLUMNFLAGS_WRITE			0x4		4
-- DBCOLUMNFLAGS_WRITEUNKNOWN		0x8		8
-- DBCOLUMNFLAGS_ISFIXEDLENGTH		0x10		16
-- DBCOLUMNFLAGS_ISNULLABLE		0x20		32
-- DBCOLUMNFLAGS_MAYBENULL		0x40		64
-- DBCOLUMNFLAGS_ISLONG			0x80		128
-- DBCOLUMNFLAGS_ISROWID		0x100		256
-- DBCOLUMNFLAGS_ISROWVER		0x200		512
-- DBCOLUMNFLAGS_CACHEDEFERRED		0x1000		4096
-- DBCOLUMNFLAGS_ISCHAPTER		0x2000		8192
-- DBCOLUMNFLAGS_SCALEISNEGATIVE	0x4000		16384
-- DBCOLUMNFLAGS_KEYCOLUMN		0x8000		32768
-- DBCOLUMNFLAGS_ISROWURL		0x10000		65536
-- DBCOLUMNFLAGS_ISDEFAULTSTREAM	0x20000		131072
-- DBCOLUMNFLAGS_ISCOLLECTION		0x40000         262144
-- DBCOLUMNFLAGS_ISSTREAM		0x80000		524288
-- DBCOLUMNFLAGS_ISROWSET		0x100000	1048576
-- DBCOLUMNFLAGS_ISROW			0x200000	2097152
-- DBCOLUMNFLAGS_ROWSPECIFICCOLUMN	0x400000	4194304
--
--
-- Virtuoso Data Types:
--
-- DV_SHORT_INT		188
-- DV_LONG_INT		189
-- DV_SINGLE_FLOAT	190
-- DV_DOUBLE_FLOAT	191
-- DV_NUMERIC		219
-- DV_SHORT_STRING	181
-- DV_LONG_STRING	182
-- DV_STRICT_STRING	238
-- DV_WIDE		225
-- DV_LONG_WIDE		226
-- DV_BIN		222
-- DV_BLOB		125
-- DV_BLOB_BIN		131
-- DV_BLOB_WIDE		132
-- DV_DATE		129
-- DV_TIME		210
-- DV_DATETIME		211
-- DV_TIMESTAMP		128
-- DV_TIMESTAMP_OBJ	208
--
--
--


-- build PROVIDER_TYPES Schema Rowset
create procedure oledb_get_types (in type integer, in best_match_restrict integer)
{
  declare TYPE_NAME NVARCHAR(32);
  declare DATA_TYPE SMALLINT;
  declare COLUMN_SIZE INTEGER;
  declare LITERAL_PREFIX, LITERAL_SUFFIX NVARCHAR(5);
  declare CREATE_PARAMS NVARCHAR(64);
  declare IS_NULLABLE, CASE_SENSITIVE SMALLINT;
  declare SEARCHABLE INTEGER;
  declare UNSIGNED_ATTRIBUTE, FIXED_PREC_SCALE, AUTO_UNIQUE_VALUE SMALLINT;
  declare LOCAL_TYPE_NAME NVARCHAR(32);
  declare MINIMUM_SCALE, MAXIMUM_SCALE SMALLINT;
  declare GUID, TYPELIB, VERSION NVARCHAR(32);
  declare IS_LONG, BEST_MATCH, IS_FIXEDLENGTH SMALLINT;

  result_names (TYPE_NAME, DATA_TYPE, COLUMN_SIZE,
                LITERAL_PREFIX, LITERAL_SUFFIX,
		CREATE_PARAMS,
		IS_NULLABLE, CASE_SENSITIVE, SEARCHABLE, UNSIGNED_ATTRIBUTE,
		FIXED_PREC_SCALE, AUTO_UNIQUE_VALUE,
		LOCAL_TYPE_NAME,
		MINIMUM_SCALE, MAXIMUM_SCALE,
		GUID, TYPELIB, VERSION,
		IS_LONG, BEST_MATCH, IS_FIXEDLENGTH);

  if (type = 2 or type is null) -- DBTYPE_I2
    {
      result (N'smallint', 2, 5, N'', N'', NULL, 1, 0, 3, 0, 1, 1, N'smallint', NULL, NULL, NULL, NULL, NULL, 0, 1, 1);
    }
  if (type = 3 or type is null) -- DBTYPE_I4
    {
      result (N'int', 3, 10, N'', N'', NULL, 1, 0, 3, 0, 1, 1, N'int', NULL, NULL, NULL, NULL, NULL, 0, 1, 1);
    }
  if (type = 4 or type is null) -- DBTYPE_R4
    {
      result (N'real', 4, 7, N'', N'e0', NULL, 1, 0, 3, 0, 0, 0, N'real', NULL, NULL, NULL, NULL, NULL, 0, 1, 1);
    }
  if (type = 5 or type is null) -- DBTYPE_R8
    {
      result (N'float', 5, 15, N'', N'e0', NULL, 1, 0, 3, 0, 0, 0, N'float', NULL, NULL, NULL, NULL, NULL, 0, 1, 1);
    }
  if (type = 128 or type is null) -- DBTYPE_BYTES
    {
      result (N'varbinary', 128, 2000, N'0x', N'', N'max length', 1, 0, 4, 0, 0, 0, N'varbinary', NULL, NULL, NULL, NULL, NULL, 0, 1, 0);
      if (best_match_restrict is null or best_match_restrict = 0)
        {
          result (N'long varbinary', 128, 2147483647, N'0x', N'', NULL, 1, 0, 1, 0, 0, 0, N'long varbinary', NULL, NULL, NULL, NULL, NULL, 1, 0, 0);
      	  result (N'timestamp', 128, 10, N'0x', N'', NULL, 0, 0, 3, 0, 0, 0, N'timestamp', NULL, NULL, NULL, NULL, NULL, 0, 0, 1);
	}
    }
  if (type = 129 or type is null) -- DBTYPE_STR
    {
      result (N'varchar', 129, 2000, N'''', N'''', N'max length', 1, 1, 4, 0, 0, 0, N'varchar', NULL, NULL, NULL, NULL, NULL, 0, 1, 0);
      if (best_match_restrict is null or best_match_restrict = 0)
        result (N'long varchar', 129, 2147483647, N'''', N'''', NULL, 1, 1, 1, 0, 0, 0, N'long varchar', NULL, NULL, NULL, NULL, NULL, 1, 0, 0);
    }
  if (type = 130 or type is null) -- DBTYPE_WSTR
    {
      result (N'nvarchar', 130, 1000, N'N''', N'''', N'length', 1, 1, 4, 0, 0, 0, N'nvarchar', NULL, NULL, NULL, NULL, NULL, 0, 1, 0);
      if (best_match_restrict is null or best_match_restrict = 0)
        result (N'long nvarchar', 130, 1073741823, N'N''', N'''', NULL, 1, 1, 1, 0, 0, 0, N'long nvarchar', NULL, NULL, NULL, NULL, NULL, 1, 0, 0);
    }
  if (type = 131 or type is null) -- DBTYPE_NUMERIC
    {
      result (N'decimal', 131, 40, N'', N'', N'precision,scale', 1, 0, 3, 0, 0, 0, N'decimal', 0, 15, NULL, NULL, NULL, 0, 1, 1);
      if (best_match_restrict is null or best_match_restrict = 0)
        result (N'numeric', 131, 40, N'', N'', N'precision,scale', 1, 0, 3, 0, 0, 0, N'numeric', 0, 15, NULL, NULL, NULL, 0, 0, 1);
    }
  if (type = 133 or type is null) -- DBTYPE_DBDATE
    {
      result (N'date', 133, 10, N'{d ''', N'''}', NULL, 1, 0, 3, 0, 0, 0, N'date', NULL, NULL, NULL, NULL, NULL, 0, 1, 1);
    }
  if (type = 134 or type is null) -- DBTYPE_DBTIME
    {
      result (N'time', 134, 8, N'{t ''', N'''}', NULL, 1, 0, 3, 0, 0, 0, N'time', NULL, NULL, NULL, NULL, NULL, 0, 1, 1);
    }
  if (type = 135 or type is null) -- DBTYPE_DBTIMESTAMP
    {
      result (N'datetime', 135, 19, N'{ts ''', N'''}', NULL, 1, 0, 3, 0, 0, 0, N'datetime', NULL, NULL, NULL, NULL, NULL, 0, 1, 1);
    }

  -- TODO: the 'any' type.

  return;
}
;

create function oledb_dbtype(in dv integer) returns smallint
{
  if (dv = 188)	-- DV_SHORT_INT
    return 2;	-- DBTYPE_I2

  if (dv = 189) -- DV_LONG_INT
    return 3;   -- DBTYPE_I4

  if (dv = 190) -- DV_SINGLE_FLOAT
    return 4;   -- DBTYPE_R4

  if (dv = 191) -- DV_DOUBLE_FLOAT
    return 5;   -- DBTYPE_R8

  if (dv = 219) -- DV_NUMERIC
    return 131; -- DBTYPE_NUMERIC

  if (dv = 181 or dv = 182 or dv = 238 or dv = 125) -- DV_SHORT_STRING, DV_LONG_STRING, DV_STRICT_STRING, DV_BLOB
    return 129; -- DBTYPE_STR

  if (dv = 225 or dv = 226 or dv = 132) -- DV_WIDE, DV_LONG_WIDE, DV_BLOB_WIDE
    return 130; -- DBTYPE_WSTR

  if (dv = 222 or dv = 131) -- DV_BIN, DV_BLOB_BIN
    return 128; -- DBTYPE_BYTES

  if (dv = 129) -- DV_DATE
    return 133; -- DBTYPE_DBDATE

  if (dv = 210) -- DV_TIME
    return 134; -- DBTYPE_DBTIME

  if (dv = 211) -- DV_DATETIME
    return 135; -- DBTYPE_DBTIMESTAMP

  if (dv = 128 or dv = 208) -- DV_TIMESTAMP, DV_TIMESTAMP_OBJ
    return 128; -- DBTYPE_BYTES

  -- by default
  return 129; -- DBTYPE_STR
}
;

create function oledb_dbflags(in dv integer, in nullable integer) returns integer
{
  declare flags integer;

  flags := 0;
  if (dv = 128 or dv = 208)	-- DV_TIMESTAMP, DV_TIMESTAMP_OBJ
    {
      flags := 16 + 512;	-- DBCOLUMNFLAGS_ISFIXEDLENGTH, DBCOLUMNFLAGS_ISROWVER
    }
  else
    {
      if (dv = 188 or dv = 189 or dv = 190 or	-- DV_SHORT_INT, DV_LONG_INT, DV_SINGLE_FLOAT
          dv = 191 or dv = 219 or dv = 129 or	-- DV_DOUBLE_FLOAT, DV_NUMERIC, DV_DATE
          dv = 210 or dv = 211)			-- DV_TIME, DV_DATETIME
        flags := 16 + 4;			-- DBCOLUMNFLAGS_ISFIXEDLENGTH, DBCOLUMNFLAGS_WRITE
      else if (dv = 125 or dv = 132 or dv = 131)	-- DV_BLOB, DV_BLOB_WIDE, DV_BLOB_BIN
        flags := 128 + 4;		-- DBCOLUMNFLAGS_ISLONG, DBCOLUMNFLAGS_WRITE
      else
	flags := 4;			-- DBCOLUMNFLAGS_WRITE

      if (nullable is null or nullable <> 1)
	flags := flags + 32 + 64;	-- DBCOLUMNFLAGS_ISNULLABLE, DBCOLUMNFLAGS_MAYBENULL
    }

  return flags;
}
;

create function oledb_char_max_len(in dv integer, in prec integer) returns integer
{
  if (dv = 188 or dv = 189 or dv = 190 or	-- DV_SHORT_INT, DV_LONG_INT, DV_SINGLE_FLOAT
      dv = 191 or dv = 219 or dv = 129 or	-- DV_DOUBLE_FLOAT,  DV_NUMERIC, DV_DATE
      dv = 210 or dv = 211)			-- DV_TIME, DV_DATETIME
    return null;
  if (dv = 225 or dv = 226 or dv = 132) -- DV_WIDE, DV_LONG_WIDE, DV_BLOB_WIDE
    {
      if (prec < 1073741823)
        return prec;
      return 1073741823;
    }
  return prec;
}
;

create function oledb_char_oct_len(in dv integer, in prec integer) returns integer
{
  if (dv = 188 or dv = 189 or dv = 190 or	-- DV_SHORT_INT, DV_LONG_INT, DV_SINGLE_FLOAT
      dv = 191 or dv = 219 or dv = 129 or	-- DV_DOUBLE_FLOAT,  DV_NUMERIC, DV_DATE
      dv = 210 or dv = 211)			-- DV_TIME, DV_DATETIME
    return null;
  if (dv = 225 or dv = 226 or dv = 132) -- DV_WIDE, DV_LONG_WIDE, DV_BLOB_WIDE
    {
      if (prec < 1073741823)
        return prec * 2;
      return 2147483646;
    }
  return prec;
}
;

create function oledb_num_prec(in dv integer, in prec integer) returns smallint
{
  if (dv = 188)	-- DV_SHORT_INT
    return 5;
  if (dv = 189)	-- DV_LONG_INT
    return 10;
  if (dv = 190)	-- DV_SINGLE_FLOAT
    return 7;
  if (dv = 191) -- DV_DOUBLE_FLOAT
    return 15;
  if (dv = 219)	-- DV_NUMERIC
    {
      if (prec < 40)
        return prec;
      return 39;
    }
  return null;
}
;

create function oledb_num_scale(in dv integer, in scale integer) returns smallint
{
  if (dv = 219)	-- DV_NUMERIC
    return scale;
  return null;
}
;

create function oledb_datetime_prec(in dv integer, in prec integer) returns smallint
{
  if (dv = 211) -- DV_DATETIME
    return 6;
  return null;
}
;

create procedure oledb_procedure_parameters(
  in cat nvarchar, in sch nvarchar, in proc nvarchar, in param nvarchar
)
{
  declare PROCEDURE_CATALOG, PROCEDURE_SCHEMA, PROCEDURE_NAME, PARAMETER_NAME nvarchar(128);
  declare ORDINAL_POSITION, PARAMETER_TYPE, PARAMETER_HASDEFAULT smallint;
  declare PARAMETER_DEFAULT nvarchar;
  declare IS_NULLABLE, DATA_TYPE smallint;
  declare CHARACTER_MAXIMUM_LENGTH, CHARACTER_OCTET_LENGTH integer;
  declare NUMERIC_PRECISION, NUMERIC_SCALE smallint;
  declare DESCRIPTION nvarchar;
  declare TYPE_NAME nvarchar(32);
  declare LOCAL_TYPE_NAME nvarchar;
  declare cols, elt any;
  declare i, n integer;

  cat := upper(cat);
  sch := upper(sch);
  proc := upper(proc);
  param := upper(param);

  result_names (PROCEDURE_CATALOG, PROCEDURE_SCHEMA, PROCEDURE_NAME, PARAMETER_NAME,
                ORDINAL_POSITION, PARAMETER_TYPE, PARAMETER_HASDEFAULT, PARAMETER_DEFAULT,
                IS_NULLABLE, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, CHARACTER_OCTET_LENGTH,
                NUMERIC_PRECISION, NUMERIC_SCALE, DESCRIPTION, TYPE_NAME, LOCAL_TYPE_NAME);

  for
    select P_NAME from DB.DBA.SYS_PROCEDURES where
      (cat is null or upper(cast(name_part(P_NAME, 0) as NVARCHAR)) = cat) and
      (sch is null or upper(cast(name_part(P_NAME, 1) as NVARCHAR)) = sch) and
      (proc is null or upper(cast(name_part(P_NAME, 2) as NVARCHAR)) = proc) and
      __proc_exists (P_NAME, 0) is null
    order by P_NAME
  do
    {
      cols := procedure_cols (P_NAME);
      if (cols)
	{
	  n := length (cols);
	  i := 0;
	  while (i < n)
	    {
	      elt := aref (cols, i);
              -- do not return SQL_RESULT_COL columns
	      if ((param is null or upper(cast(aref(elt, 3) as NVARCHAR)) = param)
		  and aref(elt, 4) <> 3)
		{
		  result (
		    aref(elt, 0),
		    aref(elt, 1),
		    aref(elt, 2),
		    aref(elt, 3),
		    aref(elt, 9),
		    case aref(elt, 4) when 2 then 2 when 4 then 3 when 5 then 4 else 1 end,
		    0,
		    NULL,
		    either(aref(elt, 8), -1, 0),
		    oledb_dbtype(aref(elt, 5)),
		    oledb_char_max_len(aref(elt, 5), aref(elt, 7)),
		    oledb_char_max_len(aref(elt, 5), aref(elt, 7)),
		    oledb_num_prec(aref(elt, 5), aref(elt, 7)),
		    oledb_num_scale(aref(elt, 5), aref(elt, 6)),
		    NULL,
		    dv_type_title(aref(elt, 5)),
		    NULL
		  );
		}
	      i := i + 1;
	    }
	}
    }
}
;

create function oledb_procedure_definition(in name nvarchar) returns nvarchar
{
  declare text varchar;
  declare more long varchar;
  if (__any_grants('DB.DBA.SYS_PROCEDURES', 1, 'P_TEXT'))
    {
      select P_TEXT, P_MORE into text, more from DB.DBA.SYS_PROCEDURES
        where upper(cast(P_NAME as NVARCHAR)) = upper(cast(name as NVARCHAR));
      if (text is null)
	return cast(more as NVARCHAR);
      return cast(text as NVARCHAR);
    }
  return NULL;
}
;

grant execute on oledb_get_types to public
;
grant execute on oledb_dbtype to public
;
grant execute on oledb_dbflags to public
;
grant execute on oledb_char_max_len to public
;
grant execute on oledb_char_oct_len to public
;
grant execute on oledb_num_prec to public
;
grant execute on oledb_num_scale to public
;
grant execute on oledb_datetime_prec to public
;
grant execute on oledb_procedure_parameters to public
;
grant execute on oledb_procedure_definition to public
;

