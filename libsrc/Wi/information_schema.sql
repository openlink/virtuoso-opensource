--
--  information schema.sql
--
--  $Id$
--
--  INFORMATION schema support
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2012 OpenLink Software
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

--#IF VER=5
create procedure INFORMATION_SCHEMA_UPGRADE ()
{
  if (registry_get ('INFORMATION_SCHEMA_VERSION') = '3')
    return;
  if (exists (select 1 from SYS_VIEWS where V_NAME = 'DB.INFORMATION_SCHEMA.COLUMNS'))
    {
      log_message ('Upgrading INFORMATION SCHEMA');
      EXEC_STMT ('drop view DB.INFORMATION_SCHEMA.COLUMNS', 0);
      EXEC_STMT ('drop view DB.INFORMATION_SCHEMA.KEY_COLUMN_USAGE', 0);
      EXEC_STMT ('drop view DB.INFORMATION_SCHEMA.PARAMETERS', 0);
      EXEC_STMT ('drop view DB.INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS', 0);
      EXEC_STMT ('drop view DB.INFORMATION_SCHEMA.ROUTINES', 0);
      EXEC_STMT ('drop view DB.INFORMATION_SCHEMA.VIEWS', 0);
    }
  registry_set ('INFORMATION_SCHEMA_VERSION', '3');
}
;

INFORMATION_SCHEMA_UPGRADE ()
;
--#ENDIF

create view INFORMATION_SCHEMA.TABLES as
select
 name_part(KEY_TABLE,0) AS TABLE_CATALOG 	VARCHAR(128),
 name_part(KEY_TABLE,1) AS TABLE_SCHEMA 	VARCHAR(128),
 name_part(KEY_TABLE,2) AS TABLE_NAME 		VARCHAR(128),
 case table_type (KEY_TABLE)
   when 'TABLE' then 'BASE TABLE'
   when 'VIEW'  then 'VIEW'
   else NULL
 end 			AS TABLE_TYPE 		VARCHAR(128),
 KEY_TABLE		AS V_KEY_TABLE		VARCHAR,
 KEY_NAME		AS V_KEY_NAME		VARCHAR,
 KEY_ID			AS V_KEY_ID		INTEGER,
 KEY_N_SIGNIFICANT	AS V_KEY_N_SIGNIFICANT	SMALLINT,
 KEY_CLUSTER_ON_ID	AS V_KEY_CLUSTER_ON_ID	SMALLINT,
 KEY_IS_MAIN		AS V_KEY_IS_MAIN	SMALLINT,
 KEY_IS_OBJECT_ID	AS V_KEY_IS_OBJECT_ID	SMALLINT,
 KEY_IS_UNIQUE		AS V_KEY_IS_UNIQUE	SMALLINT,
 KEY_MIGRATE_TO		AS V_KEY_MIGRATE_TO	INTEGER,
 KEY_SUPER_ID		AS V_KEY_SUPER_ID	INTEGER,
 KEY_DECL_PARTS		AS V_KEY_DECL_PARTS	SMALLINT,
 KEY_STORAGE		AS V_KEY_STORAGE	VARCHAR,
 KEY_OPTIONS		AS V_KEY_OPTIONS	ANY
from DB.DBA.SYS_KEYS
where
 __any_grants (KEY_TABLE)
 and table_type (KEY_TABLE) = 'TABLE'
 and KEY_IS_MAIN = 1
 and KEY_MIGRATE_TO is NULL
;

grant select on INFORMATION_SCHEMA.TABLES to public
;

create view INFORMATION_SCHEMA.COLUMNS as
select
 k.TABLE_CATALOG		AS TABLE_CATALOG 		VARCHAR(128),
 k.TABLE_SCHEMA			AS TABLE_SCHEMA 		VARCHAR(128),
 k.TABLE_NAME			AS TABLE_NAME			VARCHAR(128),
 c."COLUMN"			AS COLUMN_NAME			VARCHAR(128),

 kp.KP_NTH + 1			AS ORDINAL_POSITION 		INTEGER,

 deserialize (c.COL_DEFAULT)	AS COLUMN_DEF 			VARCHAR,

 case c.COL_NULLABLE
 	when 0 then 'YES'
	when 1 then 'NO'
	else NULL
 end 				AS NULLABLE 			VARCHAR (3),

 case
   when (
     c.COL_DTP in (125, 132) and
     get_keyword ('xml_col', coalesce (c.COL_OPTIONS, vector ())) is not null)
   then 'XMLType'

   else dv_type_title(c.COL_DTP)
 end 				AS DATA_TYPE			VARCHAR(128),-- DV_BLOB=125, DV_BLOB_WIDE=132


 c.COL_PREC 			AS CHARACTER_MAXIMUM_LENGTH	INTEGER,

 c.COL_PREC 			AS CHARACTER_OCTET_LENGTH 	INTEGER,

 c.COL_PREC			AS NUMERIC_PRECISION		SMALLINT,

 2 				AS NUMERIC_PRECISION_RADIX	SMALLINT,

 c.COL_SCALE			AS NUMERIC_SCALE		SMALLINT,

-- NULL				AS DATETIME_PRECISION		SMALLINT,

-- NULL				AS CHARACTER_SET_CATALOG	VARCHAR(6),

-- NULL				AS CHARACTER_SET_SCHEMA		VARCHAR(3),

-- NULL				AS CHARACTER_SET_NAME		VARCHAR(128),

-- NULL				AS COLLATION_CATALOG		VARCHAR(6),

-- NULL				AS COLLATION_SCHEMA		VARCHAR(3),

-- NULL				AS COLLATION_NAME		VARCHAR(128),

 case
   when get_keyword ('xml_col', coalesce (c.COL_OPTIONS, vector ())) is not null
    then 'DB'
   when get_keyword ('sql_class', coalesce (c.COL_OPTIONS, vector ())) is not null
    then name_part (get_keyword ('sql_class', coalesce (c.COL_OPTIONS, vector ())), 0, dbname())
   else NULL
 end 				AS DOMAIN_CATALOG		VARCHAR(128),

 case
   when get_keyword ('xml_col', coalesce (c.COL_OPTIONS, vector ())) is not null
    then 'DBA'
   when get_keyword ('sql_class', coalesce (c.COL_OPTIONS, vector ())) is not null
    then name_part (get_keyword ('sql_class', coalesce (c.COL_OPTIONS, vector ())), 1, USER)
   else NULL
 end				AS DOMAIN_SCHEMA		VARCHAR(128),

 case
   when get_keyword ('xml_col', coalesce (c.COL_OPTIONS, vector ())) is not null
    then 'XMLType'
   when get_keyword ('sql_class', coalesce (c.COL_OPTIONS, vector ())) is not null
    then name_part (get_keyword ('sql_class', coalesce (c.COL_OPTIONS, vector ())), 2)
   else NULL
 end				AS DOMAIN_NAME			VARCHAR(128),

 case
   when strchr (coalesce (COL_CHECK, ''), 'I') is not null
     then 'YES'
   else 'NO'
 end    			AS IS_IDENTITY			VARCHAR(3),

 case
   when strchr (coalesce (COL_CHECK, ''), 'I') is not null
     then 'ALWAYS'
   else NULL
 end				AS IDENTITY_GENERATION		VARCHAR(10),

 get_keyword (
 	'identity_start',
	coalesce (c.COL_OPTIONS, vector ()))
				AS IDENTITY_START		VARCHAR,

 get_keyword (
 	'increment_by',
	coalesce (c.COL_OPTIONS, vector ()))
				AS IDENTITY_INCREMENT		VARCHAR,

 "TABLE"			AS V_TABLE			VARCHAR,
 "COLUMN"			AS V_COLUMN			VARCHAR,
 COL_ID				AS V_COL_ID			INTEGER,
 COL_DTP			AS V_COL_DTP			SMALLINT,
 COL_PREC			AS V_COL_PREC			INTEGER,
 COL_SCALE			AS V_COL_SCALE			SMALLINT,
 COL_DEFAULT			AS V_COL_DEFAULT		VARCHAR,
 COL_CHECK			AS V_COL_CHECK			VARCHAR,
 COL_NULLABLE			AS V_COL_NULLABLE		SMALLINT,
 COL_NTH			AS V_COL_NTH			SMALLINT,
 COL_OPTIONS			AS V_COL_OPTIONS		ANY,

 KP_NTH				AS V_KP_NTH			SMALLINT

from INFORMATION_SCHEMA.TABLES k, DB.DBA.SYS_KEY_PARTS kp, DB.DBA.SYS_COLS c
where
 c."COLUMN" <> '_IDN'

 and kp.KP_KEY_ID = k.V_KEY_ID
 and COL_ID = KP_COL
;

grant select on INFORMATION_SCHEMA.COLUMNS to public
;

create view INFORMATION_SCHEMA.SCHEMATA as
select distinct
 TABLE_CATALOG			AS CATALOG_NAME			VARCHAR(128),
 TABLE_SCHEMA			AS SCHEMA_NAME			VARCHAR(128),
 TABLE_SCHEMA			AS SCHEMA_OWNER			VARCHAR(128)
from INFORMATION_SCHEMA.TABLES
;

grant select on INFORMATION_SCHEMA.SCHEMATA to public
;

create view INFORMATION_SCHEMA.CHECK_CONSTRAINTS as
select
 name_part (C_TABLE, 0)		AS CONSTRAINT_CATALOG		VARCHAR(128),
 name_part (C_TABLE, 1)		AS CONSTRAINT_SCHEMA		VARCHAR(128),
 C_TEXT				AS CONSTRAINT_NAME		VARCHAR(128),
 sql_text (deserialize (blob_to_string (C_MODE)))
 				AS CHECK_CLAUSE			VARCHAR,

 C_TABLE			AS V_C_TABLE,
 C_ID				AS V_C_ID,
 C_TEXT				AS V_C_TEXT,
 C_MODE				AS V_C_MODE
from DB.DBA.SYS_CONSTRAINTS, INFORMATION_SCHEMA.TABLES
where
 V_KEY_TABLE = C_TABLE
;

grant select on INFORMATION_SCHEMA.CHECK_CONSTRAINTS to public
;

create view INFORMATION_SCHEMA.COLUMN_DOMAIN_USAGE as
select
 DOMAIN_CATALOG			AS DOMAIN_CATALOG		VARCHAR(128),
 DOMAIN_SCHEMA			AS DOMAIN_SCHEMA		VARCHAR(128),
 DOMAIN_NAME			AS DOMAIN_NAME			VARCHAR(128),
 TABLE_CATALOG			AS TABLE_CATALOG		VARCHAR(128),
 TABLE_SCHEMA			AS TABLE_SCHEMA			VARCHAR(128),
 TABLE_NAME			AS TABLE_NAME			VARCHAR(128),
 COLUMN_NAME			AS COLUMN_NAME			VARCHAR(128)
from INFORMATION_SCHEMA.COLUMNS
where
 DOMAIN_NAME is not NULL
;

grant select on INFORMATION_SCHEMA.COLUMN_DOMAIN_USAGE to public
;


create view INFORMATION_SCHEMA.COLUMN_PRIVILEGES as
select
 case
   when G_GRANTOR is not null
     then __sec_uid_to_user (cast (G_GRANTOR as integer))
   else  NULL
 end 				AS GRANTOR			VARCHAR(128),
 __sec_uid_to_user (G_USER)	AS GRANTEE			VARCHAR(128),
 TABLE_CATALOG			AS TABLE_CATALOG		VARCHAR(128),
 TABLE_SCHEMA			AS TABLE_SCHEMA			VARCHAR(128),
 TABLE_NAME			AS TABLE_NAME			VARCHAR(128),
 COLUMN_NAME			AS COLUMN_NAME			VARCHAR(128),
 case bit_and (G_OP, 79) -- 101111 : all under GR_GRANT + GR_REFERENCES, mask 0x2F
   when 1  then 'SELECT' 	-- GR_SELECT
   when 2  then 'UPDATE' 	-- GR_UPDATE
   when 4  then 'INSERT' 	-- GR_INSERT
   when 8  then 'DELETE' 	-- GR_DELETE
   when 64 then 'REFERENCES'	-- GR_REFERENCES
   else NULL
 end				AS PRIVILEGE_TYPE		VARCHAR(10),
 case
   when G_USER = 1
    then 'NO'
   when bit_and (G_OP, 16) = 1 -- 10000 : GR_GRANT
    then 'YES'
   else 'NO'
 end				AS IS_GRANTABLE			VARCHAR (3),

 G_USER				AS V_G_USER			INTEGER,
 G_OP				AS V_G_OP			INTEGER,
 G_OBJECT			AS V_G_OBJECT			VARCHAR (386),
 G_COL				AS V_G_COL			VARCHAR (386),
 G_GRANTOR			AS V_G_GRANTOR			VARCHAR (128),
 G_ADMIN_OPT    		AS V_G_ADMIN_OPT		VARCHAR (128)

from
  INFORMATION_SCHEMA.COLUMNS, DB.DBA.SYS_GRANTS g
where
  V_TABLE = G_OBJECT
  and COLUMN_NAME = G_COL
;

grant select on INFORMATION_SCHEMA.COLUMN_PRIVILEGES to public
;


--!AWK PUBLIC
create procedure column_privileges (in TableQualifier varchar,
				    in TableOwner varchar,
				    in TableName varchar,
				    in ColumnName varchar)
{
  declare priv_op_vec any;
  declare gr cursor for
  select
    TABLE_CATALOG,
    TABLE_SCHEMA,
    TABLE_NAME,
    COLUMN_NAME,
    GRANTOR,
    GRANTEE,
    PRIVILEGE_TYPE,
    IS_GRANTABLE
   from
    (
	select
	 case
	   when G_GRANTOR is not null
	     then __sec_uid_to_user (cast (G_GRANTOR as integer))
	   else  NULL
	 end 				AS GRANTOR			VARCHAR(128),
	 __sec_uid_to_user (G_USER)	AS GRANTEE			VARCHAR(128),
	 name_part (c."TABLE", 0)	AS TABLE_CATALOG		VARCHAR(128),
	 name_part (c."TABLE", 1)	AS TABLE_SCHEMA			VARCHAR(128),
	 name_part (c."TABLE", 2)	AS TABLE_NAME			VARCHAR(128),
	 "COLUMN"			AS COLUMN_NAME			VARCHAR(128),
	 case bit_and (G_OP, 79) -- 101111 : all under GR_GRANT + GR_REFERENCES, mask 0x2F
	   when 1  then 'SELECT' 	-- GR_SELECT
	   when 2  then 'UPDATE' 	-- GR_UPDATE
	   when 4  then 'INSERT' 	-- GR_INSERT
	   when 8  then 'DELETE' 	-- GR_DELETE
	   when 64 then 'REFERENCES'	-- GR_REFERENCES
	   else NULL
	 end				AS PRIVILEGE_TYPE		VARCHAR(10),
	 case
	   when G_USER = 1
	    then 'NO'
	   when bit_and (G_OP, 16) = 1 -- 10000 : GR_GRANT
	    then 'YES'
	   else 'NO'
	 end				AS IS_GRANTABLE			VARCHAR (3)
	from
	  DB.DBA.SYS_GRANTS, DB.DBA.SYS_KEYS k, DB.DBA.SYS_KEY_PARTS kp, DB.DBA.SYS_COLS c
	where
	  "TABLE" = G_OBJECT
	  and c."COLUMN" = G_COL

	  and c."COLUMN" <> '_IDN'
	  and kp.KP_KEY_ID = k.KEY_ID
	  and COL_ID = KP_COL

	 and __any_grants (k.KEY_TABLE)
	 and k.KEY_IS_MAIN = 1
	 and k.KEY_MIGRATE_TO is NULL
     ) x
     where TABLE_CATALOG like TableQualifier
       and TABLE_SCHEMA like TableOwner
       and TABLE_NAME like TableName
       and COLUMN_NAME like ColumnName;

  whenever not found goto done;
  declare privcount integer;
  declare TABLE_CAT, TABLE_SCHEM, GRANTOR VARCHAR(128);
  declare TABLE_NAME, COLUMN_NAME, GRANTEE, PRIVILEGE VARCHAR(128);
  declare IS_GRANTABLE VARCHAR(3);

  result_names (TABLE_CAT, TABLE_SCHEM, TABLE_NAME,
	COLUMN_NAME, GRANTOR, GRANTEE, PRIVILEGE, IS_GRANTABLE);

  privcount := 0;
  open gr;
  while (1)
   {
     fetch gr into TABLE_CAT, TABLE_SCHEM, TABLE_NAME,
       COLUMN_NAME, GRANTOR, GRANTEE, PRIVILEGE, IS_GRANTABLE;

     result(TABLE_CAT, TABLE_SCHEM, TABLE_NAME,
       COLUMN_NAME, GRANTOR, GRANTEE, PRIVILEGE, IS_GRANTABLE);

     if(('dba' = get_user()) or
         (GRANTEE = get_user()) or (GRANTEE = 'public'))
      { privcount := privcount+1; }
   }
done:
  return privcount;
}
;

--!AWK PUBLIC
create procedure column_privileges_utf8 (in TableQualifier varchar,
				    in TableOwner varchar,
				    in TableName varchar,
				    in ColumnName varchar)
{
  declare priv_op_vec any;
  declare gr cursor for
  select
       charset_recode (TABLE_CATALOG, 'UTF-8', '_WIDE_') as TABLE_CATALOG NVARCHAR(128),
       charset_recode (TABLE_SCHEMA, 'UTF-8', '_WIDE_') as TABLE_SCHEMA NVARCHAR(128),
       charset_recode (TABLE_NAME, 'UTF-8', '_WIDE_') as TABLE_NAME NVARCHAR(128),
       charset_recode (COLUMN_NAME, 'UTF-8', '_WIDE_') as COLUMN_NAME NVARCHAR(128),
       charset_recode (GRANTOR, 'UTF-8', '_WIDE_') as GRANTOR NVARCHAR(128),
       charset_recode (GRANTEE, 'UTF-8', '_WIDE_') as GRANTEE NVARCHAR(128),
       charset_recode (PRIVILEGE_TYPE, 'UTF-8', '_WIDE_') as PRIVILEGE_TYPE NVARCHAR(128),
       charset_recode (IS_GRANTABLE, 'UTF-8', '_WIDE_') as IS_GRANTABLE NVARCHAR(128)
   from
    (
	select
	 case
	   when G_GRANTOR is not null
	     then __sec_uid_to_user (cast (G_GRANTOR as integer))
	   else  NULL
	 end 				AS GRANTOR			VARCHAR(128),
	 __sec_uid_to_user (G_USER)	AS GRANTEE			VARCHAR(128),
	 name_part (c."TABLE", 0)	AS TABLE_CATALOG		VARCHAR(128),
	 name_part (c."TABLE", 1)	AS TABLE_SCHEMA			VARCHAR(128),
	 name_part (c."TABLE", 2)	AS TABLE_NAME			VARCHAR(128),
	 "COLUMN"			AS COLUMN_NAME			VARCHAR(128),
	 case bit_and (G_OP, 79) -- 101111 : all under GR_GRANT + GR_REFERENCES, mask 0x2F
	   when 1  then 'SELECT' 	-- GR_SELECT
	   when 2  then 'UPDATE' 	-- GR_UPDATE
	   when 4  then 'INSERT' 	-- GR_INSERT
	   when 8  then 'DELETE' 	-- GR_DELETE
	   when 64 then 'REFERENCES'	-- GR_REFERENCES
	   else NULL
	 end				AS PRIVILEGE_TYPE		VARCHAR(10),
	 case
	   when G_USER = 1
	    then 'NO'
	   when bit_and (G_OP, 16) = 1 -- 10000 : GR_GRANT
	    then 'YES'
	   else 'NO'
	 end				AS IS_GRANTABLE			VARCHAR (3)
	from
	  DB.DBA.SYS_GRANTS, DB.DBA.SYS_KEYS k, DB.DBA.SYS_KEY_PARTS kp, DB.DBA.SYS_COLS c
	where
	  "TABLE" = G_OBJECT
	  and (c."COLUMN" = G_COL or G_COL = '_all')

	  and c."COLUMN" <> '_IDN'
	  and kp.KP_KEY_ID = k.KEY_ID
	  and COL_ID = KP_COL

	 and __any_grants (k.KEY_TABLE)
	 and k.KEY_IS_MAIN = 1
	 and k.KEY_MIGRATE_TO is NULL
     ) x
     where TABLE_CATALOG like TableQualifier
       and TABLE_SCHEMA like TableOwner
       and TABLE_NAME like TableName
       and COLUMN_NAME like ColumnName;

  whenever not found goto done;
  declare privcount integer;
  declare TABLE_CAT, TABLE_SCHEM, GRANTOR NVARCHAR(128);
  declare TABLE_NAME, COLUMN_NAME, GRANTEE NVARCHAR(128);
  declare IS_GRANTABLE, PRIVILEGE NVARCHAR(3);

  result_names (TABLE_CAT, TABLE_SCHEM, TABLE_NAME,
	COLUMN_NAME, GRANTOR, GRANTEE, PRIVILEGE, IS_GRANTABLE);

  privcount := 0;
  open gr;
  while (1)
   {
     fetch gr into TABLE_CAT, TABLE_SCHEM, TABLE_NAME,
       COLUMN_NAME, GRANTOR, GRANTEE, PRIVILEGE, IS_GRANTABLE;

     result(TABLE_CAT, TABLE_SCHEM, TABLE_NAME,
       COLUMN_NAME, GRANTOR, GRANTEE, PRIVILEGE, IS_GRANTABLE);

     if(('dba' = get_user()) or
         (GRANTEE = cast (charset_recode (get_user(), 'UTF-8', '_WIDE_') as nvarchar)) or (GRANTEE = N'public'))
      { privcount := privcount+1; }
   }
done:
  return privcount;
}
;

create view INFORMATION_SCHEMA.KEY_COLUMN_USAGE as
select
 name_part(KEY_NAME,0, name_part(KEY_TABLE,0))	AS CONSTRAINT_CATALOG 	VARCHAR(128),
 name_part(KEY_NAME,1, name_part(KEY_TABLE,1))	AS CONSTRAINT_SCHEMA 	VARCHAR(128),
 name_part(KEY_NAME,2, name_part(KEY_TABLE,2))	AS CONSTRAINT_NAME 	VARCHAR(128),
 name_part(KEY_TABLE,0) 			AS TABLE_CATALOG	VARCHAR(128),
 name_part(KEY_TABLE,1) 			AS TABLE_SCHEMA		VARCHAR(128),
 name_part(KEY_TABLE,2) 			AS TABLE_NAME 		VARCHAR(128),
 "COLUMN"					AS COLUMN_NAME		VARCHAR(128),
 KP_NTH + 1					AS ORDINAL_POSITION	SMALLINT,
 KEY_IS_MAIN					AS V_KEY_IS_MAIN	SMALLINT,
 KEY_IS_UNIQUE					AS V_KEY_IS_UNIQUE	SMALLINT
from DB.DBA.SYS_KEYS k, DB.DBA.SYS_KEY_PARTS kp, DB.DBA.SYS_COLS c
where
 __any_grants (KEY_TABLE)
 and table_type (KEY_TABLE) = 'TABLE'
 and KEY_MIGRATE_TO is NULL
 and kp.KP_KEY_ID = k.KEY_ID
 and COL_ID = KP_COL
 and k.KEY_DECL_PARTS > kp.KP_NTH
UNION ALL
select
 name_part(FK_NAME,0, name_part(FK_TABLE,0))	AS CONSTRAINT_CATALOG   VARCHAR(128),
 name_part(FK_NAME,1, name_part(FK_TABLE,1))	AS CONSTRAINT_SCHEMA    VARCHAR(128),
 name_part(FK_NAME,2, name_part(FK_TABLE,2))	AS CONSTRAINT_NAME      VARCHAR(128),
 name_part(FK_TABLE,0)				AS TABLE_CATALOG        VARCHAR(128),
 name_part(FK_TABLE,1)				AS TABLE_SCHEMA         VARCHAR(128),
 name_part(FK_TABLE,2)				AS TABLE_NAME           VARCHAR(128),
 FKCOLUMN_NAME					AS COLUMN_NAME          VARCHAR(128),
 KEY_SEQ + 1					AS ORDINAL_POSITION     SMALLINT,
 null						AS V_KEY_IS_MAIN        SMALLINT,
 null						AS V_KEY_IS_UNIQUE      SMALLINT
from DB.DBA.SYS_FOREIGN_KEYS
where
 __any_grants (FK_TABLE)
 and table_type (FK_TABLE) = 'TABLE'


order by CONSTRAINT_CATALOG, CONSTRAINT_SCHEMA, CONSTRAINT_NAME, ORDINAL_POSITION
;

grant select on INFORMATION_SCHEMA.KEY_COLUMN_USAGE to public
;

create procedure object_definition_or_null (in obj varchar, in text any)
{
  declare owner varchar;
  owner := name_part (obj, 1, NULL);
  if (owner = user or user_is_dba (user))
    return text;
  return NULL;
}
;

grant execute on DB.DBA.object_definition_or_null to public
;

create view INFORMATION_SCHEMA.ROUTINES as
select
 name_part(P_NAME,0)	AS SPECIFIC_CATALOG 		VARCHAR(128),
 name_part(P_NAME,1)	AS SPECIFIC_SCHEMA 		VARCHAR(128),
 name_part(P_NAME,2)	AS SPECIFIC_NAME 		VARCHAR(128),
 name_part(P_NAME,0)	AS ROUTINE_CATALOG 		VARCHAR(128),
 name_part(P_NAME,1)	AS ROUTINE_SCHEMA 		VARCHAR(128),
 name_part(P_NAME,2)	AS ROUTINE_NAME 		VARCHAR(128),
 NULL			AS MODULE_CATALOG 		VARCHAR(128),
 NULL			AS MODULE_SCHEMA 		VARCHAR(128),
 NULL			AS MODULE_NAME 			VARCHAR(128),
 NULL			AS UDT_CATALOG 			VARCHAR(128),
 NULL			AS UDT_SCHEMA 			VARCHAR(128),
 NULL			AS UDT_NAME 			VARCHAR(128),
 NULL			AS DATA_TYPE 			VARCHAR(128),
 NULL			AS CHARACTER_MAXIMUM_LENGTH 	INTEGER,
 NULL			AS CHARACTER_OCTET_LENGTH 	INTEGER,
 NULL			AS COLLATION_CATALOG		VARCHAR(128),
 NULL			AS COLLATION_SCHEMA		VARCHAR(128),
 NULL			AS COLLATION_NAME		VARCHAR(128),
 NULL			AS CHARACTER_SET_CATALOG	VARCHAR(128),
 NULL			AS CHARACTER_SET_SCHEMA		VARCHAR(128),
 NULL			AS CHARACTER_SET_NAME		VARCHAR(128),
 NULL			AS NUMERIC_PRECISION		SMALLINT,
 NULL			AS NUMERIC_PRECISION_RADIX	SMALLINT,
 NULL			AS NUMERIC_SCALE		SMALLINT,
 NULL			AS DATETIME_PRECISION		SMALLINT,
 NULL			AS INTERVAL_TYPE		VARCHAR(128),
 NULL			AS INTERVAL_PRECISION		SMALLINT,
 NULL			AS TYPE_UDT_CATALOG		VARCHAR(128),
 NULL			AS TYPE_UDT_SCHEMA		VARCHAR(128),
 NULL			AS TYPE_UDT_NAME		VARCHAR(128),
 NULL			AS SCOPE_CATALOG		VARCHAR(128),
 NULL			AS SCOPE_SCHEMA			VARCHAR(128),
 NULL			AS SCOPE_NAME			VARCHAR(128),
 NULL			AS MAXIMUM_CARDINALITY		INTEGER,
 NULL			AS DTD_IDENTIFIER		VARCHAR(128),
 case P_TYPE
   when 1 then 'EXTERNAL'
   else 'SQL'
 end			AS ROUTINE_BODY			VARCHAR(30),
 DB.DBA.object_definition_or_null (P_NAME, coalesce (P_TEXT,
  blob_to_string (
  P_MORE))) 		AS ROUTINE_DEFINITION    	VARCHAR,
 NULL			AS EXTERNAL_NAME 		VARCHAR(128),
 NULL			AS EXTERNAL_LANGUAGE		VARCHAR(30),
 NULL			AS PARAMETER_STYLE		VARCHAR(30),
 'NO'			AS IS_DETERMINISTIC		VARCHAR(10),
 'MODIFIES'		AS SQL_DATA_ACCESS		VARCHAR(30),
 'YES'			AS IS_NULL_CALL			VARCHAR(10),
 NULL			AS SQL_PATH			VARCHAR(128),
 'YES'			AS SCHEMA_LEVEL_ROUTINE		VARCHAR(10),
 NULL			AS MAX_DYNAMIC_RESULT_SETS	SMALLINT,
 'NO'			AS IS_USER_DEFINED_CAST		VARCHAR(10),
 'NO'			AS IS_IMPLICITLY_INVOCABLE	VARCHAR(10),
 NULL			AS CREATED			DATETIME,
 NULL			AS LAST_ALTERED			DATETIME

from DB.DBA.SYS_PROCEDURES
where
 __proc_exists (P_NAME, 1, 1) is not null
;

grant select on INFORMATION_SCHEMA.ROUTINES to public
;

create view INFORMATION_SCHEMA.PARAMETERS as
select
 PROCEDURE_CAT		AS SPECIFIC_CATALOG		VARCHAR(128),
 PROCEDURE_SCHEM	AS SPECIFIC_SCHEMA		VARCHAR(128),
 PROCEDURE_NAME		AS SPECIFIC_NAME		VARCHAR(128),
 ORDINAL_POSITION	AS ORDINAL_POSITION		INTEGER,
 case COLUMN_TYPE
   when 1 then 'IN'
   when 4 then 'OUT'
   when 2 then 'INOUT'
   else NULL
 end			AS PARAMETER_MODE		VARCHAR(10),
 case COLUMN_TYPE
   when 5 then 'YES'
   else 'NO'
 end			AS IS_RESULT			VARCHAR(10),
 'NO'			AS AS_LOCATOR			VARCHAR(10),
 COLUMN_NAME		AS PARAMETER_NAME		VARCHAR(128),
 TYPE_NAME		AS DATA_TYPE			VARCHAR(128),
 COLUMN_SIZE		AS CHARACTER_MAXIMUM_LENGTH	INTEGER,
 CHAR_OCTET_LENGTH	AS CHARACTER_OCTET_LENGTH	INTEGER,
 NULL			AS COLLATION_CATALOG		VARCHAR(128),
 NULL			AS COLLATION_SCHEMA		VARCHAR(128),
 NULL			AS COLLATION_NAME		VARCHAR(128),
 NULL			AS CHARACTER_SET_CATALOG	VARCHAR(128),
 NULL			AS CHARACTER_SET_SCHEMA		VARCHAR(128),
 NULL			AS CHARACTER_SET_NAME		VARCHAR(128),
 DECIMAL_DIGITS		AS NUMERIC_PRECISION		SMALLINT,
 NUM_PREC_RADIX		AS NUMERIC_PRECISION_RADIX	SMALLINT,
 COLUMN_SIZE		AS NUMERIC_SCALE		SMALLINT,
 NULL			AS DATETIME_PRECISION		SMALLINT,
 NULL			AS INTERVAL_TYPE		VARCHAR(128),
 NULL			AS INTERVAL_PRECISION		SMALLINT,
 NULL			AS USER_DEFINED_TYPE_CATALOG	VARCHAR(128),
 NULL			AS USER_DEFINED_TYPE_SCHEMA	VARCHAR(128),
 NULL			AS USER_DEFINED_TYPE_NAME	VARCHAR(128),
 NULL			AS SCOPE_CATALOG		VARCHAR(128),
 NULL			AS SCOPE_SCHEMA			VARCHAR(128),
 NULL			AS SCOPE_NAME			VARCHAR(128)
from DB.DBA.SQL_PROCEDURE_COLUMNS (qual,owner,name,col,casemode,is_odbc3) (
	PROCEDURE_CAT		varchar,
	PROCEDURE_SCHEM		varchar,
	PROCEDURE_NAME		varchar,
	COLUMN_NAME		varchar,
	COLUMN_TYPE		smallint,
	DATA_TYPE		smallint,
	TYPE_NAME		varchar,
	COLUMN_SIZE		integer,
	BUFFER_LENGTH		integer,
	DECIMAL_DIGITS		smallint,
	NUM_PREC_RADIX		smallint,
	NULLABLE		smallint,
	REMARKS			varchar,
	COLUMN_DEF		varchar,
	SQL_DATA_TYPE		smallint,
	SQL_DATETIME_SUB	smallint,
	CHAR_OCTET_LENGTH	integer,
	ORDINAL_POSITION	integer,
	IS_NULLABLE		varchar) X
where
  qual = NULL
  and owner = NULL
  and name = '%'
  and col = '%'
  and casemode = cast (sys_stat ('st_case_mode') as integer)
  and is_odbc3 = 1

  and COLUMN_TYPE in (1,2,4,5)
;

grant select on INFORMATION_SCHEMA.PARAMETERS to public
;


create view INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS as
select
 name_part(FK_NAME,0,name_part(FK_TABLE,0))	AS CONSTRAINT_CATALOG 		VARCHAR(128),
 name_part(FK_NAME,1,name_part(FK_TABLE,1))	AS CONSTRAINT_SCHEMA 		VARCHAR(128),
 name_part(FK_NAME,2,name_part(FK_TABLE,2))	AS CONSTRAINT_NAME 		VARCHAR(128),
 name_part(PK_TABLE,0)				AS UNIQUE_CONSTRAINT_CATALOG 	VARCHAR(128),
 name_part(PK_TABLE,1)				AS UNIQUE_CONSTRAINT_SCHEMA 	VARCHAR(128),
 name_part(PK_TABLE,2)				AS UNIQUE_CONSTRAINT_NAME 	VARCHAR(128),
 'NONE'						AS MATCH_OPTION			VARCHAR(7),
 case fk.UPDATE_RULE
   when 1 then 'CASCADE'
   when 2 then 'SET NULL'
   when 3 then 'SET DEFAULT'
   else 'NO ACTION'
 end						AS UPDATE_RULE			VARCHAR(9),
 case fk.DELETE_RULE
   when 1 then 'CASCADE'
   when 2 then 'SET NULL'
   when 3 then 'SET DEFAULT'
   else 'NO ACTION'
 end						AS DELETE_RULE			VARCHAR(9),
 FK_TABLE					AS V_FK_TABLE			VARCHAR(128)

from DB.DBA.SYS_FOREIGN_KEYS fk
where
 __any_grants (FK_TABLE)
 and table_type (FK_TABLE) = 'TABLE'
group by FK_TABLE, FK_NAME, PK_TABLE, fk.UPDATE_RULE, fk.DELETE_RULE
;

grant select on INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS to public
;


create view INFORMATION_SCHEMA.TABLE_CONSTRAINTS as
select
  CONSTRAINT_CATALOG,
  CONSTRAINT_SCHEMA,
  CONSTRAINT_NAME,
  name_part (V_FK_TABLE, 0)			AS TABLE_CATALOG		VARCHAR(128),
  name_part (V_FK_TABLE, 1)			AS TABLE_SCHEMA			VARCHAR(128),
  name_part (V_FK_TABLE, 2)			AS TABLE_NAME			VARCHAR(128),
  'FOREIGN KEY'					AS CONSTRAINT_TYPE		VARCHAR(11),
  'NO'						AS IS_DEFERRABLE		VARCHAR(2),
  'NO'						AS INITIALLY_DEFERRED		VARCHAR(2)
 from INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS
union all
select
  CONSTRAINT_CATALOG,
  CONSTRAINT_SCHEMA,
  CONSTRAINT_NAME,
  name_part (V_C_TABLE, 0),
  name_part (V_C_TABLE, 1),
  name_part (V_C_TABLE, 2),
  'CHECK',
  'NO',
  'NO'
 from INFORMATION_SCHEMA.CHECK_CONSTRAINTS
union all
select distinct
  CONSTRAINT_CATALOG,
  CONSTRAINT_SCHEMA,
  CONSTRAINT_NAME,
  TABLE_CATALOG,
  TABLE_SCHEMA,
  TABLE_NAME,
  case V_KEY_IS_MAIN
    when 1 then 'PRIMARY KEY'
    else 'UNIQUE'
  end,
  'NO',
  'NO'
from INFORMATION_SCHEMA.KEY_COLUMN_USAGE
where V_KEY_IS_UNIQUE = 1
;

grant select on INFORMATION_SCHEMA.TABLE_CONSTRAINTS to public
;


create view INFORMATION_SCHEMA.TABLE_PRIVILEGES as
select distinct
 case
   when G_GRANTOR is not null
     then __sec_uid_to_user (cast (G_GRANTOR as integer))
   else  NULL
 end 				AS GRANTOR			VARCHAR(128),
 __sec_uid_to_user (G_USER)	AS GRANTEE			VARCHAR(128),
 TABLE_CATALOG			AS TABLE_CATALOG		VARCHAR(128),
 TABLE_SCHEMA			AS TABLE_SCHEMA			VARCHAR(128),
 TABLE_NAME			AS TABLE_NAME			VARCHAR(128),
 case bit_and (G_OP, 79) -- 101111 : all under GR_GRANT + GR_REFERENCES, mask 0x2F
   when 1  then 'SELECT' 	-- GR_SELECT
   when 2  then 'UPDATE' 	-- GR_UPDATE
   when 4  then 'INSERT' 	-- GR_INSERT
   when 8  then 'DELETE' 	-- GR_DELETE
   when 64 then 'REFERENCES'	-- GR_REFERENCES
   else NULL
 end				AS PRIVILEGE_TYPE		VARCHAR(10),
 case
   when G_USER = 1
    then 'NO'
   when bit_and (G_OP, 16) = 1 -- 10000 : GR_GRANT
    then 'YES'
   else 'NO'
 end				AS IS_GRANTABLE			VARCHAR (3),

 G_USER				AS V_G_USER			INTEGER,
 G_OP				AS V_G_OP			INTEGER,
 G_OBJECT			AS V_G_OBJECT			VARCHAR (386),
 G_GRANTOR			AS V_G_GRANTOR			VARCHAR (128)
from
  INFORMATION_SCHEMA.TABLES, DB.DBA.SYS_GRANTS g
where
  V_KEY_TABLE = G_OBJECT
;

grant select on INFORMATION_SCHEMA.TABLE_PRIVILEGES to public
;


create view INFORMATION_SCHEMA.VIEWS as
select
 name_part(V_NAME,0) 	AS TABLE_CATALOG 	VARCHAR(128),
 name_part(V_NAME,1) 	AS TABLE_SCHEMA 	VARCHAR(128),
 name_part(V_NAME,2) 	AS TABLE_NAME 		VARCHAR(128),
 DB.DBA.object_definition_or_null (V_NAME, coalesce (
  V_TEXT,
  blob_to_string (
   V_EXT)))		AS VIEW_DEFINITION	VARCHAR,
 NULL			AS CHECK_OPTION		VARCHAR(7),
 case
   when (exists (select 1 from DB.DBA.SYS_TRIGGERS where T_TABLE = V_NAME))
    then 'YES'
   else 'NO'
 end			AS IS_UPDATABLE		VARCHAR(3)
from DB.DBA.SYS_VIEWS
where
 __any_grants (V_NAME)
;

grant select on INFORMATION_SCHEMA.VIEWS to public
;

