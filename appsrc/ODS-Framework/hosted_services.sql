--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2014 OpenLink Software
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

create procedure WA_GET_EMAIL_TEMPLATE(in name varchar, in dav int := 0)
{
  declare ret any;

  if (http_map_get ('is_dav') = 0 and dav = 0)
  {
    ret := file_to_string (http_root () || '/wa/tmpl/' || name);
  }
  else
  {
    ret := (select
              coalesce(blob_to_string(RES_CONTENT), 'Not found...')
            from
              WS.WS.SYS_DAV_RES
           where
             RES_FULL_PATH = '/DAV/VAD/wa/tmpl/' || name );
  }
  return ret;
}
;

create procedure WA_SET_EMAIL_TEMPLATE(in name varchar, in value varchar)
{
  update
    WS.WS.SYS_DAV_RES
  set
    RES_CONTENT = value
  where
    RES_FULL_PATH = '/DAV/VAD/wa/tmpl/' || name;
}
;

create procedure wa_exec_no_error_log(in expr varchar)
{
  declare state, message, meta, result any;

  log_enable (1);
  exec(expr, state, message, vector(), 0, meta, result);
}
;

create procedure wa_exec_ddl (in q varchar)
{
  declare lex any;
  lex := sql_lex_analyze (q);
  if (length (lex) > 2 and length (lex[0]) > 1 and length (lex[1]) > 1 and length (lex[2]) > 1)
    {
      if (lower (lex[0][1]) = 'create' and lower (lex[1][1]) = 'table')
	{
	  declare tb varchar;
	  tb := complete_table_name (lex[2][1], 1);
	  if (exists (select 1 from DB.DBA.SYS_KEYS where KEY_TABLE = tb))
	    return;
	}
    }
  DB.DBA.EXEC_STMT (q, 0);
}
;

create procedure wa_exec_no_error(in expr varchar)
{
  declare state, message, meta, result any;
  exec(expr, state, message, vector(), 0, meta, result);
}
;

create procedure wa_add_col(in tbl varchar, in col varchar, in coltype varchar,in postexec varchar := '')
{
 if(exists(
           select
             top 1 1
           from
             DB.DBA.SYS_COLS
           where
             upper("TABLE") = upper(tbl) and
             upper("COLUMN") = upper(col)
          )
    ) return;
  exec (sprintf ('alter table %s add column %s %s', tbl, col, coltype));
  if (postexec <> '' and not(isnull(postexec)))
    exec (postexec);
}
;

wa_exec_no_error_log('CREATE INDEX VSPX_SESSION_VS_UID ON VSPX_SESSION (VS_UID)');

wa_exec_no_error(
  'create type web_app as
  (
    wa_name varchar,  -- ie. blog
    wa_member_model int -- how registration can be made
  )
  method wa_id_string () returns any,         -- string in memberships list
  method wa_new_inst (login varchar) returns any,   -- registering
  method wa_join_request (login varchar) returns any,   -- registering
  method wa_leave_notify (login varchar) returns any,   -- cancel join
  method wa_state_edit_form (stream any) returns any,   -- emit a state edit form into the stream present this to owner for setting the state
  method wa_membership_edit_form (stream any) returns any,  -- emit a membership edit form into the stream present this to owner for setting the state
  method wa_front_page (stream any) returns any,  -- emit a front page into the stream present this to owner for setting the state
  method wa_state_posted (post any, stream any) returns any, -- process a post, updating state and writing a reply into the stream for web interface
  method wa_periodic_activity () returns any,   -- send reminders, invoices, refresh content whatever is regularly done.
  method wa_drop_instance () returns any,
  method wa_private_url () returns any,
  method wa_notify_member_changed (account int, otype int, ntype int, odata any, ndata any) returns any,
  method wa_member_data (u_id int, stream any) returns any, -- application specific membership attributes
  method wa_member_data_edit_form (u_id int, stream any) returns any, -- application specific membership attributes edit form
  method wa_class_details () returns varchar, -- returns details about the nature of the instance class
  method wa_https_supported () returns int,
  method wa_dashboard () returns any
  '
)
;

wa_exec_no_error('alter type web_app add method wa_home_url () returns varchar');
wa_exec_no_error('alter type web_app add method wa_dashboard () returns any');
wa_exec_no_error('alter type web_app add method wa_addition_urls () returns any');
wa_exec_no_error('alter type web_app add method wa_addition_instance_urls () returns any');
wa_exec_no_error('alter type web_app add method wa_addition_instance_urls (in lpath any) returns any');
wa_exec_no_error('alter type web_app add method wa_domain_set (in domain varchar) returns any');
wa_exec_no_error('alter type web_app add method wa_size () returns int');
wa_exec_no_error('alter type web_app add method wa_front_page_as_user (in stream any, in user_name varchar) returns any');
wa_exec_no_error('alter type web_app add method wa_rdf_url (in vhost varchar, in lhost varchar) returns varchar');
wa_exec_no_error('alter type web_app add method wa_post_url (in vhost varchar, in lhost varchar, in inst_name varchar, in post any) returns varchar');
wa_exec_no_error('alter type web_app add method wa_update_instance (in oldValues any, in newValues any) returns any');

wa_exec_no_error_log(
  'CREATE TABLE WA_INDUSTRY
    (
    WI_NAME varchar not null primary key
    )'
)
;

wa_exec_no_error_log(
  'CREATE TABLE WA_COUNTRY
    (
    WC_NAME varchar not null primary key,
    WC_CODE varchar,
    WC_ISO_CODE varchar,
    WC_LAT  real,
    WC_LNG  real
    )'
)
;

wa_add_col('DB.DBA.WA_COUNTRY', 'WC_LAT', 'real');
wa_add_col('DB.DBA.WA_COUNTRY', 'WC_LNG', 'real');
wa_add_col('DB.DBA.WA_COUNTRY', 'WC_CODE', 'varchar');
wa_add_col('DB.DBA.WA_COUNTRY', 'WC_ISO_CODE', 'varchar');


wa_exec_no_error_log (
    'create table WA_PROVINCE (
      WP_COUNTRY varchar,
      WP_PROVINCE varchar,
      primary key (WP_COUNTRY, WP_PROVINCE)
     )'
);


/* Domains that can be used in WA */

wa_exec_no_error_log(
  'CREATE TABLE WA_DOMAINS
    (
      WD_DOMAIN varchar,    -- domain name
      WD_HOST varchar,      -- this and rest are the endpoint to access wa via that domain
      WD_LISTEN_HOST varchar,
      WD_LPATH varchar,
      WD_MODEL int,
      primary key (WD_DOMAIN)
    )'
)
;

/*
   TODO: rename the table and put the data back and then drop, this is for non-nullable cols which are
   WD_HOST,WD_LISTEN_HOST
*/

wa_add_col ('DB.DBA.WA_DOMAINS', 'WD_LPATH', 'varchar');
wa_add_col ('DB.DBA.WA_DOMAINS', 'WD_DOMAIN', 'varchar');
wa_add_col ('DB.DBA.WA_DOMAINS', 'WD_MODEL', 'int');

wa_exec_no_error_log(
  'create table WA_MAP_HOSTS
    (
      WMH_HOST varchar,
      WMH_SVC  varchar,
      WMH_KEY  varchar,
      WMH_ID integer identity,
      primary key (WMH_HOST, WMH_SVC)
    )'
);


create procedure MIGRATE_WA_DOMAINS ()
{
  if (exists (select 1 from DB.DBA.SYS_COLS where upper("TABLE") = 'DB.DBA.WA_DOMAINS'
  and upper("COLUMN") = 'WD_HOST' and COL_NULLABLE is null))
    return;

  for select WD_HOST as vhost from WA_DOMAINS where WD_DOMAIN is null
    do
      {
  declare arr any;
  arr := split_and_decode (vhost, 0, '\0\0:');
  if (isarray(arr) and length (arr))
    update WA_DOMAINS set WD_DOMAIN = arr[0] where WD_HOST = vhost;
      }

  wa_exec_no_error ('alter table DB.DBA.WA_DOMAINS modify primary key (WD_DOMAIN)');
  update DB.DBA.SYS_COLS set COL_NULLABLE = null
      where upper("TABLE") = 'DB.DBA.WA_DOMAINS' and upper("COLUMN") in ('WD_LISTEN_HOST', 'WD_HOST');
  __ddl_changed ('DB.DBA.WA_DOMAINS');
}
;

MIGRATE_WA_DOMAINS ();

drop procedure MIGRATE_WA_DOMAINS;


wa_exec_no_error_log(
  'CREATE TABLE WA_USERS
  (
    WAU_U_ID int,
    WAU_QUESTION varchar,
    WAU_ANSWER varchar,
    WAU_LAST_IP varchar,
    WAU_TEMPLATE varchar,
    WAU_LOGON_DISABLE_UNTIL datetime,
    WAU_PWD_RECOVER_DISABLE_UNTIL datetime,
    primary key (WAU_U_ID)
  )'
)
;

wa_exec_no_error_log(
  'CREATE TABLE WA_USER_SETTINGS
  (
    WAUS_U_ID int,
    WAUS_KEY varchar(50),
    WAUS_DATA long varbinary,
    primary key (WAUS_U_ID,WAUS_KEY)
  )'
)
;

wa_exec_no_error_log(
  'ALTER TABLE WA_USER_SETTINGS ADD FOREIGN KEY (WAUS_U_ID) REFERENCES SYS_USERS (U_ID) ON DELETE CASCADE'
)
;

-- put for versions upgrade
wa_exec_no_error_log(
  'ALTER TABLE WA_USERS DROP FOREIGN KEY (WAU_U_ID) REFERENCES SYS_USERS (U_ID)'
)
;

wa_add_col('DB.DBA.WA_USERS', 'WAU_LOGON_DISABLE_UNTIL', 'datetime')
;

wa_add_col('DB.DBA.WA_USERS', 'WAU_LAST_IP', 'varchar')
;

wa_add_col('DB.DBA.WA_USERS', 'WAU_TEMPLATE', 'varchar')
;

wa_exec_no_error(
  'CREATE TABLE WA_BLOCKED_IP
  (
    WAB_IP varchar,
    WAB_DISABLE_UNTIL datetime,
    primary key (WAB_IP)
  )'
)
;

wa_add_col('DB.DBA.WA_USERS', 'WAU_PWD_RECOVER_DISABLE_UNTIL', 'datetime')
;

wa_exec_no_error(
  'CREATE TABLE WA_TYPES
   (
    WAT_NAME varchar,
    WAT_TYPE varchar,
    WAT_REALM varchar,
    WAT_DESCRIPTION varchar,
     WAT_OPTIONS long varchar,
    WAT_MAXINST integer,
      primary key (WAT_NAME)
    )'
)
;
wa_add_col('DB.DBA.WA_TYPES', 'WAT_MAXINST', 'integer')
;

wa_add_col('DB.DBA.WA_TYPES', 'WAT_OPTIONS', 'long varchar')
;

wa_exec_no_error(
  'CREATE TABLE WA_MEMBER_MODEL
   (
    WMM_ID int primary key,
    WMM_NAME varchar not null
    )'
)
;

wa_exec_no_error(
  'CREATE TABLE WA_MEMBER_TYPE
   (
  WMT_APP varchar,
  WMT_NAME varchar,
  WMT_ID int,
  WMT_IS_DEFAULT int,

     primary key (WMT_APP, WMT_ID)
   )'
)
;

wa_exec_no_error(
  'CREATE TABLE WA_INSTANCE
   (
    WAI_ID   int identity,
    WAI_TYPE_NAME varchar references WA_TYPES on delete cascade,
    WAI_NAME varchar,
    WAI_INST web_app,
    WAI_MEMBER_MODEL int references WA_MEMBER_MODEL,
    WAI_IS_PUBLIC int default 1,
    WAI_ACL long varchar,
    WAI_MEMBERS_VISIBLE int default 1,
    WAI_DESCRIPTION varchar,
    WAI_MODIFIED timestamp,
    WAI_IS_FROZEN int,
    WAI_FREEZE_REDIRECT varchar,
    WAI_LICENSE	long varchar,
    primary key (WAI_NAME)
    )'
)
;

wa_add_col('DB.DBA.WA_INSTANCE', 'WAI_IS_FROZEN', 'int')
;

wa_add_col('DB.DBA.WA_INSTANCE', 'WAI_FREEZE_REDIRECT', 'varchar')
;

wa_add_col('DB.DBA.WA_INSTANCE', 'WAI_MODIFIED', 'timestamp')
;

wa_add_col('DB.DBA.WA_INSTANCE', 'WAI_LICENSE', 'long varchar')
;

wa_add_col('DB.DBA.WA_INSTANCE', 'WAI_ACL', 'long varchar')
;

--wa_exec_no_error(
--  'CREATE UNIQUE INDEX WAI_NAME ON WA_INSTANCE (WAI_NAME)'
--)
--;

wa_exec_no_error_log(
  'CREATE TABLE WA_VIRTUAL_HOSTS
    (
      VH_INST integer references WA_INSTANCE (WAI_ID) on delete cascade,
      VH_HOST varchar,  	-- this and rest are the endpoint to access wa via that domain
      VH_LISTEN_HOST varchar,
      VH_LPATH varchar,
      VH_PAGE varchar,
      primary key (VH_INST,VH_HOST,VH_LISTEN_HOST,VH_LPATH)
    )'
)
;


create trigger HTTP_PATH_U_WA after update on DB.DBA.HTTP_PATH referencing old as O, new as N
{
  update WA_DOMAINS set WD_HOST = N.HP_HOST, WD_LISTEN_HOST = N.HP_LISTEN_HOST,
   WD_LPATH = N.HP_LPATH where WD_HOST = O.HP_HOST and WD_LISTEN_HOST = O.HP_LISTEN_HOST and WD_LPATH = O.HP_LPATH;

  update WA_VIRTUAL_HOSTS set VH_HOST = N.HP_HOST, VH_LISTEN_HOST = N.HP_LISTEN_HOST, VH_LPATH = N.HP_LPATH
      where VH_HOST = O.HP_HOST and VH_LISTEN_HOST = O.HP_LISTEN_HOST and VH_LPATH = O.HP_LPATH;

}
;

create trigger HTTP_PATH_D_WA after delete on DB.DBA.HTTP_PATH referencing old as O
{
  delete from WA_DOMAINS where WD_HOST = O.HP_HOST and WD_LISTEN_HOST = O.HP_LISTEN_HOST and WD_LPATH = O.HP_LPATH;
  delete from WA_VIRTUAL_HOSTS where VH_HOST = O.HP_HOST and VH_LISTEN_HOST = O.HP_LISTEN_HOST and VH_LPATH = O.HP_LPATH;
}
;


wa_exec_no_error(
  'CREATE TABLE WA_MEMBER
    (
     WAM_USER int,
     WAM_INST varchar references WA_INSTANCE on delete cascade on update cascade,
     WAM_MEMBER_TYPE int, -- 1= owner 2= admin 3=regular, -1=waiting approval etc.
     WAM_MEMBER_SINCE datetime,
     WAM_EXPIRES datetime,
     WAM_IS_PUBLIC int default 1,  -- Duplicate WAI_IS_PUBLIC
     WAM_MEMBERS_VISIBLE int default 1,  -- Duplicate WAI_MEMBERS_VISIBLE
     WAM_HOME_PAGE varchar,
     WAM_APP_TYPE varchar,
     WAM_DATA any, -- app dependent, e.g. last payment info, other.
     WAM_STATUS int,
       primary key (WAM_USER, WAM_INST, WAM_MEMBER_TYPE)
    )'
)
;

wa_exec_no_error_log(
    'create index WA_MEMBER_WAM_INST on WA_MEMBER (WAM_INST)'
    );

-- put for versions upgrade
wa_exec_no_error_log(
  'ALTER TABLE WA_MEMBER DROP FOREIGN KEY (WAM_USER) REFERENCES SYS_USERS (U_ID)'
)
;


wa_add_col('DB.DBA.WA_MEMBER', 'WAM_STATUS', 'int')
;

--zdravko
wa_add_col('DB.DBA.WA_MEMBER', 'WAM_APP_TYPE', 'varchar')
;

wa_add_col('DB.DBA.WA_MEMBER', 'WAM_IS_PUBLIC', 'int default 1')
;

wa_add_col('DB.DBA.WA_MEMBER', 'WAM_MEMBERS_VISIBLE', 'int default 1')
;

wa_add_col('DB.DBA.WA_MEMBER', 'WAM_HOME_PAGE', 'varchar')
;

 --wa_add_col('DB.DBA.WA_MEMBER', 'WAM_REQUESTED_MEMBER_TYPE', 'int')
 --;

create procedure wa_member_upgrade() {

  if (registry_get ('__wa_member_upgrade') = 'done')
    return;

  set triggers off;
  update DB.DBA.WA_MEMBER set WAM_STATUS = 2;
  update DB.DBA.WA_MEMBER set WAM_STATUS = 1 where WAM_MEMBER_TYPE = 1;
  set triggers on;
  registry_set ('__wa_member_upgrade', 'done');
}
;

wa_member_upgrade()
;

drop procedure wa_member_upgrade
;

create procedure wa_instance_upgrade() {

  if (registry_get ('__wa_instance_upgrade') = 'done2')
    return;

  delete from DB.DBA.WA_INSTANCE where wai_name not in (select WAM_INST from  DB.DBA.WA_MEMBER);
  registry_set ('__wa_instance_upgrade', 'done2');
}
;

wa_instance_upgrade()
;
drop procedure wa_instance_upgrade
;


wa_exec_no_error(
  'CREATE TABLE WA_MEMBER_INSTCOUNT
    (
    WMIC_TYPE_NAME varchar references WA_TYPES on delete cascade,
    WMIC_UID int  references SYS_USERS (U_ID) on delete cascade,
    WMIC_INSTCOUNT integer default null,
    primary key (WMIC_TYPE_NAME, WMIC_UID)
    )'
)
;


create procedure wa_member_doinstcount() {

  if (registry_get ('__wa_member_doinstcount') = 'done')
    return;

  set triggers off;

  insert into WA_MEMBER_INSTCOUNT (WMIC_TYPE_NAME,WMIC_UID,WMIC_INSTCOUNT)
         select WAI_TYPE_NAME, WAM_USER, count(WAM_INST) as instcount
         from DB.DBA.WA_MEMBER left join WA_INSTANCE on (WAM_INST=WAI_NAME)
         where WAM_MEMBER_TYPE=1 and WAI_TYPE_NAME is not null
         group by WAM_USER,WAI_TYPE_NAME
         order by WAM_USER,WAI_TYPE_NAME;

  set triggers on;
  registry_set ('__wa_member_doinstcount', 'done');
}
;

wa_member_doinstcount()
;

wa_exec_no_error ('
  create table WA_GROUPS (
    WAG_ID integer identity,
    WAG_USER_ID integer,
    WAG_GROUP_ID integer,

    primary key (WAG_ID)
  )
');

wa_exec_no_error ('
  create unique index SK_WA_GROUPS_01 on WA_GROUPS (WAG_USER_ID, WAG_GROUP_ID)
');

create procedure wa_groups_update () {

  if (registry_get ('__wa_groups_update') = 'done')
    return;

  wa_exec_no_error ('insert into DB.DBA.WA_GROUPS (WAG_USER_ID, WAG_GROUP_ID) select USER_ID, GROUP_ID from ODRIVE.WA.GROUPS');
  wa_exec_no_error ('delete from ODRIVE.WA.GROUPS');
  registry_set ('__wa_groups_update', 'done');
}
;

wa_exec_no_error ('
  create table WA_GROUPS_ACL (
    WACL_ID integer identity,
    WACL_USER_ID integer not null,
    WACL_NAME varchar not null,
    WACL_DESCRIPTION long varchar,
    WACL_WEBIDS long varchar,

    constraint FK_WA_GROUPS_ACL_01 FOREIGN KEY (WACL_USER_ID) references DB.DBA.SYS_USERS(U_ID) on delete cascade,

    primary key (WACL_ID)
  )
');

wa_exec_no_error ('
  create unique index SK_WA_GROUPS_ACL_01 on WA_GROUPS_ACL (WACL_USER_ID, WACL_NAME)
');

create procedure wa_groups_acl_update () {

  if (registry_get ('__wa_groups_acl_update') = 'done')
    return;

  wa_exec_no_error ('insert into DB.DBA.WA_GROUPS_ACL (WACL_USER_ID, WACL_NAME, WACL_DESCRIPTION, WACL_WEBIDS) select FG_USER_ID, FG_NAME, FG_DESCRIPTION, FG_WEBIDS from ODRIVE.WA.FOAF_GROUPS');
  wa_exec_no_error ('update DB.DBA.WA_INSTANCE set WAI_ACL = null');
  registry_set ('__wa_groups_acl_update', 'done');
}
;

wa_groups_acl_update()
;

create procedure wa_aci_params (
  in params any)
{
  declare N, M, N2, M2 integer;
  declare aclNo, aclNo2, retValue, V, V2, T any;

  M := 1;
  retValue := vector ();
  for (N := 0; N < length (params); N := N + 2)
  {
    if (params[N] like 's_fld_2_%')
    {
      aclNo := replace (params[N], 's_fld_2_', '');
      if (aclNo = cast (atoi (replace (params[N], 's_fld_2_', '')) as varchar))
      {
        if (get_keyword ('s_fld_1_' || aclNo, params) = 'advanced')
        {
          M2 := 1;
          T := vector ();
          for (N2 := 0; N2 < length (params); N2 := N2 + 2)
          {
            if (params[N2] like (params[N] || '_fld_1_%'))
            {
              aclNo2 := replace (params[N2], params[N] || '_fld_1_', '');
              if (not DB.DBA.is_empty_or_null (get_keyword (params[N] || '_fld_1_' || aclNo2, params)))
              {
              V2 := vector (M2,
                            trim (get_keyword (params[N] || '_fld_1_' || aclNo2, params)),
                            trim (get_keyword (params[N] || '_fld_2_' || aclNo2, params)),
                            trim (get_keyword (params[N] || '_fld_3_' || aclNo2, params)),
                            trim (get_keyword (params[N] || '_fld_0_' || aclNo2, params, ''))
                           );
              T := vector_concat (T, vector (V2));
              M2 := M2 + 1;
            }
          }
          }
          if (length (T) = 0)
            goto _skip;
        }
        else
        {
          T := trim (params[N+1]);
          if (is_empty_or_null (T))
            goto _skip;
        }
      V := vector (M,
                     T,
                     get_keyword ('s_fld_1_' || aclNo, params),
                   atoi (get_keyword ('s_fld_3_' || aclNo || '_r', params, '0')),
                   atoi (get_keyword ('s_fld_3_' || aclNo || '_w', params, '0')),
                   atoi (get_keyword ('s_fld_3_' || aclNo || '_x', params, '0'))
                  );
      retValue := vector_concat (retValue, vector (V));
      M := M + 1;
      _skip:;
      }
    }
  }
  return retValue;
}
;

create procedure wa_aci_validate (
  in aci any,
  in silent integer := 0)
{
  declare N, M integer;
  declare sqlStatement varchar;
  declare retValue, criteria, sqlTree any;

  retValue := vector ();
  for (N := 0; N < length (aci); N := N + 1)
  {
    if (aci[N][2] = 'advanced')
    {
      criteria := aci[N][1];
      for (M := 0; M < length (criteria); M := M + 1)
      {
        if (criteria[M][1] = 'certSparqlASK')
        {
		      declare exit handler for sqlstate '*' {
		        if (not silent)
		          signal('TEST', WA_CLEAR ('Bad criteria: ' || __SQL_MESSAGE));

		        return 0;
		      };

          sqlStatement := criteria[M][4];
          sqlStatement := regexp_replace (sqlStatement, '\\^\\{([a-zA-Z0-9])+\\}\\^', '??');
		      sqlTree := sql_parse ('sparql ' || sqlStatement);
        }
        else if (criteria[M][1] = 'certSparqlTriplet')
        {
          declare command, commands any;
		      declare exit handler for sqlstate '*' {
		        if (not silent)
		          signal('TEST', WA_CLEAR ('Bad criteria: ' || __SQL_MESSAGE));

		        return 0;
		      };

          commands := ODS.ODS_API.commands ();
          command := get_keyword (criteria[M][2], commands);
          command := replace (command, ' <> ', ' != ');
          command := replace (command, '^{value}^', 'str (?v)');
          sqlStatement := sprintf (
            'prefix sioc: <http://rdfs.org/sioc/ns#> \n' ||
            'prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> \n' ||
            'prefix foaf: <http://xmlns.com/foaf/0.1/> \n' ||
            'ASK \n' ||
            'WHERE \n' ||
            '  { \n' ||
            '    <urn:demo> %s ?v. \n' ||
            '    FILTER (%s). \n' ||
            '  }',
            criteria[M][4],
            command);
          sqlStatement := regexp_replace (sqlStatement, '\\^\\{([a-zA-Z0-9])+\\}\\^', '??');
		      sqlTree := sql_parse ('sparql ' || sqlStatement);
        }
      }
    }
  }
  return 1;
}
;

create procedure wa_aci_lines (
  in _acl any,
  in _mode varchar := 'view',
  in _execute varchar := 'false')
{
  declare N integer;

  for (N := 0; N < length (_acl); N := N + 1)
  {
    if (_mode <> 'view')
    {
      http (sprintf ('OAT.MSG.attach(OAT, "PAGE_LOADED", function(){TBL.createRow("s", null, {fld_1: {mode: 50, value: "%s", onchange: function(){TBL.changeCell50(this);}}, fld_2: {mode: 51, form: "F1", tdCssText: "white-space: nowrap;", className: "_validate_ _webid_", value: %s, readOnly: %s, imgCssText: "%s"}, fld_3: {mode: 52, value: [%d, %d, %d], execute: \'%s\', tdCssText: "width: 1%%; text-align: center;"}});});', _acl[N][2], ODS..obj2json (_acl[N][1]), case when _acl[N][2] = 'public' then 'true' else 'false' end, case when _acl[N][2] = 'public' then 'display: none;' else '' end, _acl[N][3], _acl[N][4], _acl[N][5], _execute));
    } else {
      http (sprintf ('OAT.MSG.attach(OAT, "PAGE_LOADED", function(){TBL.createViewRow("s", {fld_1: {mode: 50, value: "%s"}, fld_2: {mode: 51, value: %s}, fld_3: {mode: 52, value: [%d, %d, %d], execute: \'%s\', tdCssText: "width: 1%%; white-space: nowrap; text-align: center;"}, fld_4: {value: "Inherited"}});});', _acl[N][2], ODS..obj2json (_acl[N][1]), _acl[N][3], _acl[N][4], _acl[N][5], _execute));
    }
  }
}
;

wa_exec_no_error_log(
'create table WA_PRIVATE_GRAPHS
 (
   WAPG_GRAPH varchar,
   WAPG_TYPE varchar,
   WAPG_ID any,
   WAPG_ID2 any,

   primary key (WAPG_GRAPH, WAPG_TYPE, WAPG_ID, WAPG_ID2)
 )'
)
;

create procedure wa_private_graph_add (
  in _graph varchar,
  in _type varchar,
  in _id any,
  in _id2 any := 0)
{
  insert soft WA_PRIVATE_GRAPHS (WAPG_GRAPH, WAPG_TYPE, WAPG_ID, WAPG_ID2)
    values (_graph, _type, _id, _id2);
}
;

create procedure wa_private_graph_remove (
  in _graph varchar,
  in _type varchar,
  in _id any,
  in _id2 any := 0)
{
  delete
    from WA_PRIVATE_GRAPHS
   where WAPG_GRAPH = _graph
     and WAPG_TYPE = _type
     and WAPG_ID = _id
     and WAPG_ID2 = _id2;
}
;

wa_exec_no_error_log (
'create table WA_INVITATIONS
 (
   WI_U_ID     int,		-- U_ID
   WI_TO_MAIL  varchar,	-- email
   WI_INSTANCE varchar,	-- WAI_NAME
   WI_SID      varchar,	-- VS_SID
   WI_STATUS   varchar,	-- pending, or rejected
   primary key (WI_U_ID, WI_TO_MAIL, WI_INSTANCE)
  )
');

wa_exec_no_error_log(
'create unique index WA_INVITATIONS_SID on WA_INVITATIONS (WI_SID)'
    );


wa_exec_no_error(
'create table WA_SETTINGS
 (
   WS_ID integer identity primary key,
   WS_MAIL_VERIFY int,
   WS_VERIFY_TIP int,
   WS_REGISTRATION_EMAIL_EXPIRY int default 24,
   WS_JOIN_EXPIRY int default 72,
   WS_DOMAINS varchar,
   WS_SMTP varchar,
   WS_USE_DEFAULT_SMTP integer,
   WS_BRAND_NAME varchar,
   WS_WEB_BANNER varchar,
   WS_WEB_TITLE varchar,
   WS_WEB_DESCRIPTION varchar,
   WS_WELCOME_MESSAGE varchar,
   WS_WELCOME_MESSAGE2 varchar,
   WS_COPYRIGHT varchar,
   WS_DISCLAIMER varchar,
   WS_DEFAULT_MAIL_DOMAIN varchar,
   WS_HTTPS integer default 0,
   WS_LOGIN integer default 1,
   WS_LOGIN_OPENID integer default 1,
   WS_LOGIN_BROWSERID integer default 1,
   WS_LOGIN_FACEBOOK integer default 1,
   WS_LOGIN_TWITTER integer default 1,
   WS_LOGIN_LINKEDIN integer default 1,
   WS_LOGIN_GOOGLE integer default 1,
   WS_LOGIN_WINLIVE integer default 1,
   WS_LOGIN_WORDPRESS integer default 1,
   WS_LOGIN_TUMBLR integer default 1,
   WS_LOGIN_YAHOO integer default 1,
   WS_LOGIN_DISQUS integer default 1,
   WS_LOGIN_INSTAGRAM integer default 1,
   WS_LOGIN_BITLY integer default 1,
   WS_LOGIN_FOURSQUARE integer default 1,
   WS_LOGIN_DROPBOX integer default 1,
   WS_LOGIN_GITHUB integer default 1,
   WS_LOGIN_SSL integer default 1,
   WS_REGISTER integer default 1,
   WS_REGISTER_OPENID integer default 1,
   WS_REGISTER_BROWSERID integer default 1,
   WS_REGISTER_FACEBOOK integer default 1,
   WS_REGISTER_TWITTER integer default 1,
   WS_REGISTER_LINKEDIN integer default 1,
   WS_REGISTER_GOOGLE integer default 1,
   WS_REGISTER_WINLIVE integer default 1,
   WS_REGISTER_WORDPRESS integer default 1,
   WS_REGISTER_TUMBLR integer default 1,
   WS_REGISTER_YAHOO integer default 1,
   WS_REGISTER_DISQUS integer default 1,
   WS_REGISTER_INSTAGRAM integer default 1,
   WS_REGISTER_BITLY integer default 1,
   WS_REGISTER_FOURSQUARE integer default 1,
   WS_REGISTER_DROPBOX integer default 1,
   WS_REGISTER_GITHUB integer default 1,
   WS_REGISTER_SSL integer default 1,
   WS_REGISTER_SSL_FILTER integer default 0,
   WS_REGISTER_SSL_RULE varchar default \'ODS_REGISTRATION_RULE\',
   WS_REGISTER_SSL_REALM varchar default \'ODS\',
   WS_REGISTER_AUTOMATIC_SSL integer default 1,
   WS_FEEDS_UPDATE_PERIOD varchar default \'hourly\',
   WS_FEEDS_UPDATE_FREQ integer default 1,
   WS_FEEDS_HUB varchar default null,
   WS_FEEDS_HUB_CALLBACK integer default 1,
   WS_CERT_GEN_URL varchar default null,
   WS_CERT_EXPIRATION_PERIOD integer default 365
 )
')
;

wa_add_col('DB.DBA.WA_SETTINGS', 'WS_SHOW_SYSTEM_ERRORS', 'integer')
;

wa_add_col('DB.DBA.WA_SETTINGS', 'WS_MEMBER_MODEL', 'integer')
;

wa_add_col('DB.DBA.WA_SETTINGS', 'WS_REGISTRATION_XML', 'long xml')
;

wa_add_col('DB.DBA.WA_SETTINGS', 'WS_BRAND_NAME', 'varchar')
;

wa_add_col('DB.DBA.WA_SETTINGS', 'WS_WEB_BANNER', 'varchar')
;

wa_add_col('DB.DBA.WA_SETTINGS', 'WS_WEB_TITLE', 'varchar')
;

wa_add_col('DB.DBA.WA_SETTINGS', 'WS_WEB_DESCRIPTION', 'varchar')
;

wa_add_col('DB.DBA.WA_SETTINGS', 'WS_WELCOME_MESSAGE', 'varchar')
;

wa_add_col('DB.DBA.WA_SETTINGS', 'WS_WELCOME_MESSAGE2', 'varchar')
;

wa_add_col('DB.DBA.WA_SETTINGS', 'WS_COPYRIGHT', 'varchar')
;

wa_add_col('DB.DBA.WA_SETTINGS', 'WS_DISCLAIMER', 'varchar')
;

wa_add_col('DB.DBA.WA_SETTINGS', 'WS_GENERAL_AGREEMENT', 'varchar')
;

wa_add_col('DB.DBA.WA_SETTINGS', 'WS_MEMBER_AGREEMENT', 'varchar')
;

wa_add_col('DB.DBA.WA_SETTINGS', 'WS_DEFAULT_MAIL_DOMAIN', 'varchar')
;

wa_add_col('DB.DBA.WA_SETTINGS', 'WS_VERIFY_TIP', 'int')
;

wa_add_col('DB.DBA.WA_SETTINGS', 'WS_UNIQUE_MAIL', 'int default 1')
;

wa_add_col('DB.DBA.WA_SETTINGS', 'WS_FEEDS_UPDATE_PERIOD', 'varchar default \'hourly\'')
;

wa_add_col('DB.DBA.WA_SETTINGS', 'WS_FEEDS_UPDATE_FREQ', 'integer default 1')
;

wa_add_col('DB.DBA.WA_SETTINGS', 'WS_FEEDS_HUB', 'varchar default null')
;

wa_add_col('DB.DBA.WA_SETTINGS', 'WS_CERT_GEN_URL', 'varchar default null')
;

wa_add_col ('DB.DBA.WA_SETTINGS', 'WS_CERT_EXPIRATION_PERIOD', 'integer default 365')
;

wa_add_col('DB.DBA.WA_SETTINGS', 'WS_FEEDS_HUB_CALLBACK', 'integer default 1')
;

wa_add_col('DB.DBA.WA_SETTINGS', 'WS_STORE_DAYS', 'integer default 30')
;

wa_add_col('DB.DBA.WA_SETTINGS', 'WS_HTTPS', 'integer default 0')
;

wa_add_col ('DB.DBA.WA_SETTINGS', 'WS_LOGIN', 'integer default 1')
;

wa_add_col ('DB.DBA.WA_SETTINGS', 'WS_LOGIN_OPENID', 'integer default 1')
;

wa_add_col ('DB.DBA.WA_SETTINGS', 'WS_LOGIN_BROWSERID', 'integer default 1')
;

wa_add_col ('DB.DBA.WA_SETTINGS', 'WS_LOGIN_FACEBOOK', 'integer default 1')
;

wa_add_col ('DB.DBA.WA_SETTINGS', 'WS_LOGIN_TWITTER', 'integer default 1')
;

wa_add_col ('DB.DBA.WA_SETTINGS', 'WS_LOGIN_LINKEDIN', 'integer default 1')
;

wa_add_col ('DB.DBA.WA_SETTINGS', 'WS_LOGIN_GOOGLE', 'integer default 1')
;

wa_add_col ('DB.DBA.WA_SETTINGS', 'WS_LOGIN_WINLIVE', 'integer default 1')
;

wa_add_col ('DB.DBA.WA_SETTINGS', 'WS_LOGIN_WORDPRESS', 'integer default 1')
;

wa_add_col ('DB.DBA.WA_SETTINGS', 'WS_LOGIN_TUMBLR', 'integer default 1')
;

wa_add_col ('DB.DBA.WA_SETTINGS', 'WS_LOGIN_YAHOO', 'integer default 1')
;

wa_add_col ('DB.DBA.WA_SETTINGS', 'WS_LOGIN_DISQUS', 'integer default 1')
;

wa_add_col ('DB.DBA.WA_SETTINGS', 'WS_LOGIN_INSTAGRAM', 'integer default 1')
;

wa_add_col ('DB.DBA.WA_SETTINGS', 'WS_LOGIN_BITLY', 'integer default 1')
;

wa_add_col ('DB.DBA.WA_SETTINGS', 'WS_LOGIN_FOURSQUARE', 'integer default 1')
;

wa_add_col ('DB.DBA.WA_SETTINGS', 'WS_LOGIN_DROPBOX', 'integer default 1')
;

wa_add_col ('DB.DBA.WA_SETTINGS', 'WS_LOGIN_GITHUB', 'integer default 1')
;

wa_add_col ('DB.DBA.WA_SETTINGS', 'WS_LOGIN_SSL', 'integer default 1')
;

wa_add_col('DB.DBA.WA_SETTINGS', 'WS_REGISTER_OPENID', 'integer default 1')
;

wa_add_col ('DB.DBA.WA_SETTINGS', 'WS_REGISTER_BROWSERID', 'integer default 1')
;

wa_add_col('DB.DBA.WA_SETTINGS', 'WS_REGISTER_FACEBOOK', 'integer default 1')
;

wa_add_col ('DB.DBA.WA_SETTINGS', 'WS_REGISTER_WORDPRESS', 'integer default 1')
;

wa_add_col ('DB.DBA.WA_SETTINGS', 'WS_REGISTER_TUMBLR', 'integer default 1')
;

wa_add_col ('DB.DBA.WA_SETTINGS', 'WS_REGISTER_YAHOO', 'integer default 1')
;

wa_add_col('DB.DBA.WA_SETTINGS', 'WS_REGISTER_TWITTER', 'integer default 1')
;

wa_add_col('DB.DBA.WA_SETTINGS', 'WS_REGISTER_LINKEDIN', 'integer default 1')
;

wa_add_col ('DB.DBA.WA_SETTINGS', 'WS_REGISTER_DISQUS', 'integer default 1')
;

wa_add_col ('DB.DBA.WA_SETTINGS', 'WS_REGISTER_INSTAGRAM', 'integer default 1')
;

wa_add_col ('DB.DBA.WA_SETTINGS', 'WS_REGISTER_BITLY', 'integer default 1')
;

wa_add_col ('DB.DBA.WA_SETTINGS', 'WS_REGISTER_FOURSQUARE', 'integer default 1')
;

wa_add_col ('DB.DBA.WA_SETTINGS', 'WS_REGISTER_DROPBOX', 'integer default 1')
;

wa_add_col ('DB.DBA.WA_SETTINGS', 'WS_REGISTER_GITHUB', 'integer default 1')
;

wa_add_col ('DB.DBA.WA_SETTINGS', 'WS_REGISTER_SSL', 'integer default 1')
;

wa_add_col ('DB.DBA.WA_SETTINGS', 'WS_REGISTER_SSL_FILTER', 'integer default 0')
;

wa_add_col ('DB.DBA.WA_SETTINGS', 'WS_REGISTER_GOOGLE', 'integer default 1')
;

wa_add_col ('DB.DBA.WA_SETTINGS', 'WS_REGISTER_WINLIVE', 'integer default 1')
;

wa_add_col('DB.DBA.WA_SETTINGS', 'WS_REGISTER_SSL', 'integer default 1')
;

wa_add_col ('DB.DBA.WA_SETTINGS', 'WS_REGISTER_SSL_RULE', 'varchar default \'ODS_REGISTRATION_RULE\'')
;

wa_add_col ('DB.DBA.WA_SETTINGS', 'WS_REGISTER_SSL_REALM', 'varchar default \'ODS\'')
;

wa_add_col('DB.DBA.WA_SETTINGS', 'WS_REGISTER_AUTOMATIC_SSL', 'integer default 1')
;

wa_exec_no_error(
  'alter type web_app add method wa_notify_member_changed(account int, otype int, ntype int, odata any, ndata any, ostatus any, nstatus any) returns any'
)
;

wa_exec_no_error(
  'alter type web_app add drop method wa_new_instace_url(in ws_type varchar) returns any'
)
;

wa_exec_no_error(
  'alter type web_app add method wa_new_instance_url() returns any'
)
;

wa_exec_no_error(
  'alter type web_app add method wa_edit_instance_url() returns any'
)
;

wa_exec_no_error(
'create table WA_SETTINGS_FEEDS
 (
   WSF_INSTANCE_ID integer,
   WSF_ACCESS varchar,

   constraint FK_WA_SETTINGS_FEEDS_01 FOREIGN KEY (WSF_INSTANCE_ID) references WA_INSTANCE (WAI_ID) ON DELETE CASCADE,

   primary key (WSF_INSTANCE_ID)
 )
')
;

wa_exec_no_error(
'create table WA_ACTIVITIES (
     WA_ID int identity,
     WA_U_ID int,
     WA_SRC_ID int,
     WA_TS timestamp,
     WA_ACTIVITY long varchar,
     WA_ACTIVITY_TYPE varchar,
     WA_ACTIVITY_ACTION varchar,
     WA_OBJ_TYPE varchar,
     WA_OBJ_URI varchar,
     primary key (WA_U_ID, WA_ID))'
)
;

wa_add_col('DB.DBA.WA_ACTIVITIES', 'WA_ACTIVITY_TYPE', 'varchar')
;
wa_add_col('DB.DBA.WA_ACTIVITIES', 'WA_ACTIVITY_ACTION', 'varchar')
;
wa_add_col('DB.DBA.WA_ACTIVITIES', 'WA_OBJ_TYPE', 'varchar')
;
wa_add_col('DB.DBA.WA_ACTIVITIES', 'WA_OBJ_URI', 'varchar')
;


wa_exec_no_error('create table WA_ACTIVITIES_USERSET (
     WAU_U_ID int,
     WAU_A_ID int,
     WAU_STATUS int,
     primary key (WAU_U_ID, WAU_A_ID))'
)
;

wa_exec_no_error_log(
  'ALTER TABLE WA_ACTIVITIES_USERSET ADD FOREIGN KEY (WAU_U_ID) REFERENCES SYS_USERS (U_ID) ON DELETE CASCADE'
)
;

wa_exec_no_error_log(
  'ALTER TABLE WA_ACTIVITIES_USERSET ADD FOREIGN KEY (WAU_A_ID) REFERENCES WA_ACTIVITIES (WA_ID) ON DELETE CASCADE'
)
;

wa_exec_no_error('drop table WA_MESSAGES')
;

wa_exec_no_error('create table WA_MESSAGES (
     WM_ID int identity,
     WM_SENDER_UID int,
     WM_RECIPIENT_UID int,
     WM_TS timestamp,
     WM_MESSAGE long varchar,
     WM_SENDER_MSGSTATUS int,
     WM_RECIPIENT_MSGSTATUS int,
     primary key (WM_SENDER_UID, WM_RECIPIENT_UID,WM_ID))'
)
;
wa_exec_no_error_log(
  'ALTER TABLE WA_MESSAGES ADD FOREIGN KEY (WM_SENDER_UID) REFERENCES SYS_USERS (U_ID) ON DELETE CASCADE'
)
;

wa_exec_no_error_log(
  'ALTER TABLE WA_MESSAGES ADD FOREIGN KEY (WM_RECIPIENT_UID) REFERENCES SYS_USERS (U_ID) ON DELETE CASCADE'
)
;

db.dba.wa_exec_ddl ('create table WA_USER_SVC (
      US_ID int identity,
      US_U_ID int,
      US_SVC  varchar,
      US_IRI  varchar,
      US_KEY  varchar,
      primary key (US_U_ID, US_SVC)
      )'
);

create procedure wa_facebook_upgrade() {

  if (registry_get ('__wa_facebook_upgrade') = 'done')
    return;

  delete from DB.DBA.WA_USER_SVC where US_U_ID <> 0 and US_SVC = 'FBKey';
  update DB.DBA.WA_USER_SVC set US_U_ID = http_dav_uid () where US_SVC = 'FBKey';

  registry_set ('__wa_facebook_upgrade', 'done');
}
;

wa_facebook_upgrade()
;

db.dba.wa_exec_ddl ('create table WA_RELATED_APPS (
      RA_ID int identity,
      RA_WAI_ID int,
      RA_URI  varchar,
      RA_LABEL  varchar,
      primary key (RA_WAI_ID, RA_ID)
      )'
);

db.dba.wa_exec_ddl ('create table WA_PSH_SUBSCRIPTIONS (
      PS_INST_ID int,
      PS_URL varchar,
      PS_HUB varchar,
      PS_TS timestamp,
      PS_STATE int default 0,
      primary key (PS_INST_ID, PS_URL)
      )'
);

create method wa_id_string () for web_app
{
  return '';
}
;

create method wa_dashboard () for web_app
{
  return '';
}
;

create method wa_member_data (in u_id int, inout stream any) for web_app
{
  return 'N/A';
}
;

create method wa_member_data_edit_form (in u_id int, inout stream any) for web_app
{
  return;
}
;

create method wa_membership_edit_form (inout stream any) for web_app
{
  return;
}
;

create method wa_front_page (inout stream any) for web_app
{
  return;
}
;

create method wa_front_page_as_user (inout stream any, in user_name varchar) for web_app
{
  return;
}
;

create method wa_size () for web_app
{
  return 0;
}
;

create method wa_join_request (in login varchar) for web_app
{
  return;
}
;

create method wa_class_details() for web_app
{
  return null;
}
;

create method wa_state_edit_form (inout stream any) for web_app
{
  return;
}
;

create method wa_state_posted (in post any, inout stream any) for web_app
{
  return;
}
;

create method wa_home_url () for web_app
{
  return null;
}
;

create method wa_rdf_url (in vhost varchar, in lhost varchar) for web_app
{
  return null;
}
;

create method wa_post_url (in vhost varchar, in lhost varchar, in inst_name varchar, in post any) for web_app
{
  return null;
}
;


create method wa_addition_urls () for web_app
{
  return null;
}
;

create method wa_addition_instance_urls () for web_app
{
  return null;
}
;

create method wa_addition_instance_urls (in lpath any) for web_app
{
  return null;
}
;

wa_exec_no_error(
  'alter type web_app add method wa_domain_set(in domain varchar) returns any'
)
;

create method wa_domain_set (in domain varchar) for web_app
{
  return self;
}
;

create method wa_private_url () for web_app
{
  return null;
}
;

create method wa_https_supported () for web_app
{
  return;
}
;

create method wa_drop_instance () for web_app {

/* XXX: old query
for (
select
    HP_HOST as _host, HP_LISTEN_HOST as _lhost, HP_LPATH as _path, WAI_INST as _inst
  from
    WA_INSTANCE WA_INSTANCE,
    HTTP_PATH
  where
    WA_INSTANCE.WAI_NAME = self.wa_name and
    HP_PPATH = (select HP_PPATH from HTTP_PATH where HP_LPATH=rtrim(WA_INSTANCE.WAI_INST.wa_home_url(), '/') and HP_HOST='*ini*' and HP_LISTEN_HOST='*ini*') and
    HP_HOST not like '%ini%'and HP_HOST not like '*sslini*')
  do
*/
for select VH_HOST as _host, VH_LISTEN_HOST as _lhost, VH_LPATH as _path, WAI_INST as _inst, WAI_TYPE_NAME as _type
  from WA_INSTANCE, WA_VIRTUAL_HOSTS where WAI_NAME = self.wa_name and WAI_ID = VH_INST and VH_HOST not like '%ini%'
  do
  {
    declare inst web_app;
    inst := _inst;
    -- Application additional URL
    declare len, i, ssl_port, inst_count integer;
    declare cur_add_url, addons any;

    -- Application additional URL
    if (not exists (select 1 from WA_INSTANCE where WAI_TYPE_NAME = _type and WAI_NAME <> self.wa_name))
    {
      addons := inst.wa_addition_urls();
      len := length(addons);
      i := 0;
      while (i < len)
      {
        cur_add_url := addons [i];
        VHOST_REMOVE(
          vhost=>_host,
          lhost=>_lhost,
          lpath=>cur_add_url[2]);
        i := i + 1;
      }
    }
    -- Instance additional URL
    addons := inst.wa_addition_instance_urls(_path);
    len := length(addons);
    i := 0;
    while (i < len)
    {
      cur_add_url := addons[i];
      VHOST_REMOVE(
        vhost=>_host,
        lhost=>_lhost,
        lpath=>cur_add_url[2]);
      i := i + 1;
    }
    -- Home URL
    VHOST_REMOVE(vhost=>_host, lhost=>_lhost, lpath=>_path);
  }
  delete from WA_MEMBER where WAM_INST = self.wa_name;
  delete from WA_INSTANCE where WAI_NAME = self.wa_name;
}
;

create method wa_periodic_activity () for web_app
{
  return;
}
;

create method wa_notify_member_changed (in accounter int, in otype int, in ntype int, in odata any, in ndata any, in ostatus any, in nstatus any) for web_app
{
   -- check if this account already exists
  if (not exists (select 1 from DB.DBA.SYS_USERS where U_ID = accounter and U_DAV_ENABLE = 1 and U_IS_ROLE = 0))
  {
    signal('WA001', sprintf('%%User U_ID=%d is not found%%', accounter));
  }
  -- check if user is not member (only for insertion)
  if(otype is null and ostatus is null) {
    -- clear insertion
    declare _cnt any;
    _cnt := (select count(*) from WA_MEMBER where WAM_USER = accounter and WAM_INST = self.wa_name and WAM_STATUS < 3);
    if(_cnt > 1) {
      signal('WA001', '%%Entered user already is member.%%');
    }
  }
  declare _wai_id any;
  _wai_id := (select WAI_ID from WA_INSTANCE where WAI_NAME = self.wa_name);
  if(otype is null and ostatus is null and nstatus = 1) {
    -- new instance creation and user became owner
    -- do nothing
    return;
  }
  if(otype = ntype and ostatus = nstatus) {
    -- no real membership changing
    -- (probably others fields are updated)
    -- do nothing
    return;
  }
  -- get member model
  declare _member_model integer;
  _member_model := (select WAI_MEMBER_MODEL from WA_INSTANCE where WAI_NAME = self.wa_name);
  -- 0 Open
  -- 1 Closed
  -- 2 Invite Only
  -- 3 Approval Based
  -- 4 Notify owner via E-mail
   -- determine mail server
   declare _smtp_server, dat any;
   if((select max(WS_USE_DEFAULT_SMTP) from WA_SETTINGS) = 1) {
     _smtp_server := cfg_item_value(virtuoso_ini_path(), 'HTTPServer', 'DefaultMailServer');
   }
   else {
     _smtp_server := (select max(WS_SMTP) from WA_SETTINGS);
   }
  dat := sprintf ('Date: %s\r\n', date_rfc1123 (now ()));
  -- get user's and owner's e-mail addresses
  declare _owner_id, _owner_name, _owner_full_name, _owner_e_mail any;
  declare _user_id, _user_name, _user_full_name, _user_e_mail any;
  select
    U_ID, U_NAME, U_FULL_NAME, U_E_MAIL
  into
    _owner_id, _owner_name, _owner_full_name, _owner_e_mail
  from
    SYS_USERS
  where
    U_ID = (select max(WAM_USER) from WA_MEMBER where WAM_INST = self.wa_name and WAM_STATUS = 1);
  select
    U_ID, U_NAME, U_FULL_NAME, U_E_MAIL
  into
    _user_id, _user_name, _user_full_name, _user_e_mail
  from
    SYS_USERS
  where
    U_ID = accounter;
  if(otype is null and ostatus is null and nstatus = 4) {
    -- owner invite user join to application
    ;
  }
  if(otype is null and ostatus is null and nstatus = 3) {
    -- user wants to join application
    -- check if it possible
    if(_member_model = 1) {
      -- reject
      goto closed;
    }
    if(_member_model = 0 or _member_model = 2) {
      -- 0 Open
      -- approve immediately
      set triggers off;
      update
        WA_MEMBER
      set
        WAM_STATUS = 2 -- approved
      where
        WAM_USER = accounter and
        WAM_INST = self.wa_name;
      connection_set('join_result', 'approved');
      set triggers on;
      return;
    }
    if(_member_model = 3) {
      -- 3 Approval Based
      if(not _smtp_server or length(_smtp_server) = 0) {
        signal('WA002', '%%Mail Server is not defined. Mail verification impossible.%%');
      }
      -- notify owner by e-mail
      declare _mail_body any;
      _mail_body := WA_GET_EMAIL_TEMPLATE('WS_MEM_TEMPLATE');
      -- WA_MAIL_TEMPLATES(templ, web_app, user_name, app_action_url)
      _mail_body := WA_MAIL_TEMPLATES(_mail_body, self, _user_name, sprintf('%s/login.vspx?URL=%s/members.vspx?wai_id=%d', rtrim (wa_link (1), '/'), wa_link (), _wai_id));
      _mail_body := dat || 'Subject: Application registration notification\r\nContent-Type: text/plain; charset=UTF-8\r\n' || _mail_body;
      smtp_send(_smtp_server, _user_e_mail, _owner_e_mail, _mail_body);
      -- place request on hold and wait owner approval
      connection_set('join_result', 'ownerwait');
      return;
    }
    if(_member_model = 4) {
      -- 4 Notify owner via E-mail
      if(not _smtp_server or length(_smtp_server) = 0) {
        signal('WA002', '%%Mail Server is not defined. Mail verification impossible.%%');
      }
      -- notify owner by e-mail
      declare _mail_body any;
      _mail_body := WA_GET_EMAIL_TEMPLATE('WS_MEM_TEMPLATE');
      -- WA_MAIL_TEMPLATES(templ, web_app, user_name, app_action_url)
      _mail_body := WA_MAIL_TEMPLATES(_mail_body, self, _user_name, sprintf('%s/login.vspx?URL=%s/members.vspx?wai_id=%d', rtrim (wa_link (1), '/'), wa_link (), _wai_id));
      _mail_body := dat || 'Subject: Application registration notification\r\nContent-Type: text/plain; charset=UTF-8\r\n' || _mail_body;
      smtp_send(_smtp_server, _user_e_mail, _owner_e_mail, _mail_body);

      -- became member immediately
      set triggers off;
      update
        WA_MEMBER
      set
        WAM_STATUS = 2 -- approved
      where
        WAM_USER = accounter and
        WAM_INST = self.wa_name;
      connection_set('join_result', 'approved');
      set triggers on;
      return;
    }
closed:
    signal('WA001', '%%Application is closed for join. Please ask owner.%%');
  }
  if (otype is null and ostatus is null and ntype is not null and nstatus = 4) 
  {
    -- Invitation from owner
    if(not _smtp_server or length(_smtp_server) = 0) {
      signal('WA002', '%%Mail Server is not defined. Mail verification impossible.%%');
    }
    -- notify user by e-mail
    declare _mail_body, _url, _sid any;
    _sid := connection_get('__sid');
    _url := sprintf('%s/conf_app.vspx?app_id=%d&sid=%s&realm=wa', rtrim (wa_link (1), '/'), _wai_id, _sid);
    _mail_body := WA_GET_EMAIL_TEMPLATE('WS_INV_TEMPLATE');
    -- WA_MAIL_TEMPLATES(templ, web_app, user_name, app_action_url)
    _mail_body := WA_MAIL_TEMPLATES(_mail_body, self, _user_name, _url);
    _mail_body := dat || 'Subject: Application registration notification\r\nContent-Type: text/plain; charset=UTF-8\r\n' || _mail_body;
    smtp_send(_smtp_server, _owner_e_mail, _user_e_mail, _mail_body);
    return;
  }
  if (ntype is not null and ostatus = 3 and nstatus = 2) 
  {
    -- owner's approval after user's join request
    if(not _smtp_server or length(_smtp_server) = 0) {
      signal('WA002', '%%Mail Server is not defined. Mail verification impossible.%%');
    }
    -- notify user by e-mail
    declare _mail_body any;
    _mail_body := WA_GET_EMAIL_TEMPLATE('WS_JOIN_APPROVE_TEMPLATE');
    -- WA_MAIL_TEMPLATES(templ, web_app, user_name, app_action_url)
    _mail_body := WA_MAIL_TEMPLATES(_mail_body, self, _user_name, sprintf('http://%s/%s', WA_CNAME(), self.wa_home_url()));
    _mail_body := dat || 'Subject: Application registration notification\r\nContent-Type: text/plain; charset=UTF-8\r\n' || _mail_body;
    smtp_send(_smtp_server, _owner_e_mail, _user_e_mail, _mail_body);
    return;
  }
  if (ntype is null and nstatus is null and ostatus = 3) 
  {
    -- Join request rejection
    if(not _smtp_server or length(_smtp_server) = 0) {
      signal('WA002', '%%Mail Server is not defined. Mail verification impossible.%%');
    }
    -- notify user by e-mail
    declare _mail_body any;
    _mail_body := WA_GET_EMAIL_TEMPLATE('WS_JOIN_REJECT_TEMPLATE');
    -- WA_MAIL_TEMPLATES(templ, web_app, user_name, app_action_url)
    _mail_body := WA_MAIL_TEMPLATES(_mail_body, self, _user_name, '');
    _mail_body := dat || 'Subject: Application registration notification\r\nContent-Type: text/plain; charset=UTF-8\r\n' || _mail_body;
    smtp_send(_smtp_server, _owner_e_mail, _user_e_mail, _mail_body);
    return;
  }
  if (ntype is null and nstatus is null and ostatus = 2) 
  {
    -- user was not owner and want to terminate his membership
    if(_member_model in (2, 3, 4)) {
      if(not _smtp_server or length(_smtp_server) = 0) {
        signal('WA002', '%%Mail Server is not defined. Mail verification impossible.%%');
      }
      declare _mail_body any;
      -- notify owner or user my e-mail
      if(connection_get('action_reason') = 'owner') {
        -- notify user by e-mail
        _mail_body := WA_GET_EMAIL_TEMPLATE('WS_TERM_BY_OWNER_TEMPLATE');
        -- WA_MAIL_TEMPLATES(templ, web_app, user_name, app_action_url)
        _mail_body := WA_MAIL_TEMPLATES(_mail_body, self, _user_name, '');
        _mail_body := dat || 'Subject: Application registration notification\r\nContent-Type: text/plain; charset=UTF-8\r\n' || _mail_body;
        smtp_send(_smtp_server, _owner_e_mail, _user_e_mail, _mail_body);
        return;
      }
      else {
        -- notify owner by e-mail
        _mail_body := WA_GET_EMAIL_TEMPLATE('WS_TERM_BY_USER_TEMPLATE');
        -- WA_MAIL_TEMPLATES(templ, web_app, user_name, app_action_url)
        _mail_body := WA_MAIL_TEMPLATES(_mail_body, self, _user_name, '');
        _mail_body := dat || 'Subject: Application registration notification\r\nContent-Type: text/plain; charset=UTF-8\r\n' || _mail_body;
        smtp_send(_smtp_server, _user_e_mail, _owner_e_mail, _mail_body);
        return;
      }
    }
    return;
  }
  if(ntype is null and nstatus is null and ostatus = 1) {
    -- user is owner and want to delete application
    return;
  }
  if(not ntype is null and not otype is null and otype <> ntype and nstatus = 2 and ostatus = 2) {
    -- owner change membership type
    if(_member_model in (2, 3, 4)) {
      if(not _smtp_server or length(_smtp_server) = 0) {
        signal('WA002', '%%Mail Server is not defined. Mail verification impossible.%%');
      }
      declare _mail_body any;
      -- notify user by e-mail
      _mail_body := WA_GET_EMAIL_TEMPLATE('WS_CHANGE_BY_OWNER_TEMPLATE');
      -- WA_MAIL_TEMPLATES(templ, web_app, user_name, app_action_url)
      _mail_body := WA_MAIL_TEMPLATES(_mail_body, self, _user_name, '');
      _mail_body := dat || 'Subject: Application registration notification\r\nContent-Type: text/plain; charset=UTF-8\r\n' || _mail_body;
      smtp_send(_smtp_server, _owner_e_mail, _user_e_mail, _mail_body);
      return;
    }
    return;
  }
  if(ntype is not null and nstatus = 2 and ostatus = 4) {
    -- user's approval
    if(_member_model in (2, 3, 4)) {
      if(not _smtp_server or length(_smtp_server) = 0) {
        signal('WA002', '%%Mail Server is not defined. Mail verification impossible.%%');
      }
      declare _mail_body any;
      -- notify owner by e-mail
      _mail_body := WA_GET_EMAIL_TEMPLATE('WS_APPROVE_BY_USER_TEMPLATE');
      -- WA_MAIL_TEMPLATES(templ, web_app, user_name, app_action_url)
      _mail_body := WA_MAIL_TEMPLATES(_mail_body, self, _user_name, '');
      _mail_body := dat || 'Subject: Application registration notification\r\nContent-Type: text/plain; charset=UTF-8\r\n' || _mail_body;
      smtp_send(_smtp_server, _user_e_mail, _owner_e_mail, _mail_body);
      return;
    }
    return;
  }

  if(ntype is null and nstatus is null and ostatus = 4) {
    -- user's rejection
    if(_member_model in (2, 3, 4)) {
      if(not _smtp_server or length(_smtp_server) = 0) {
        signal('WA002', '%%Mail Server is not defined. Mail verification impossible.%%');
      }
      declare _mail_body any;
      -- notify owner by e-mail
      _mail_body := WA_GET_EMAIL_TEMPLATE('WS_REJECT_BY_USER_TEMPLATE');
      -- WA_MAIL_TEMPLATES(templ, web_app, user_name, app_action_url)
      _mail_body := WA_MAIL_TEMPLATES(_mail_body, self, _user_name, '');
      _mail_body := dat || 'Subject: Application registration notification\r\nContent-Type: text/plain; charset=UTF-8\r\n' || _mail_body;
      declare exit handler for sqlstate '08006'
	{
	  return;
	};
      commit work;
      smtp_send(_smtp_server, _user_e_mail, _owner_e_mail, _mail_body);
      return;
    }
    return;
  }

  if(otype is null and ostatus is null and nstatus = 2) {
    -- became member immediately without notification
    -- may be done by owner only
    return;
  }

  declare _message any;
  _message := sprintf('%%Unhandled wa_notify_member_changed arguments combination%%:\r\n<br/>
                      accounter=%s\r\n
                      otype=%s\r\n
                      ntype=%s\r\n
                      ostatus=%s\r\n
                      nstatus=%s\r\n',
                      coalesce(cast(accounter as varchar), 'null'),
                      coalesce(cast(otype as varchar), 'null'),
                      coalesce(cast(ntype as varchar), 'null'),
                      coalesce(cast(ostatus as varchar), 'null'),
                      coalesce(cast(nstatus as varchar), 'null')
                      );
  signal('WA001', _message);
}
;

create method wa_new_inst (in login varchar) for web_app
{
  declare uid, id, tn, is_pub, is_memb_visb any;

  uid := (select U_ID from SYS_USERS where U_NAME = login);
  select WAI_ID, WAI_TYPE_NAME, WAI_IS_PUBLIC, WAI_MEMBERS_VISIBLE
    into id, tn, is_pub, is_memb_visb
    from WA_INSTANCE
   where WAI_NAME = self.wa_name;
  -- WAM_STATUS = 1 means OWNER
  -- XXX: check this why is off
  --set triggers off;
  insert into WA_MEMBER (WAM_USER, WAM_INST, WAM_MEMBER_TYPE, WAM_STATUS, WAM_HOME_PAGE, WAM_APP_TYPE, WAM_IS_PUBLIC, WAM_MEMBERS_VISIBLE)
      values (uid, self.wa_name, 1, 1, wa_set_url_t (self), tn, is_pub, is_memb_visb);
  --set triggers on;
  return id;
}
;

create method wa_new_instance_url () for web_app
{
  return 'new_inst.vspx';
}
;

create method wa_edit_instance_url () for web_app
{
  return 'edit_inst.vspx';
}
;

--
-- oldValues - vector with old instance fields values
-- newValues - vector with new instance fields values
--
--       [0] - instance name (WA_NAME)
--       [1] - instance type (WAI_IS_PUBLIC)
--
create method wa_update_instance (in oldValues any, in newValues any) for web_app
{
  return;
}
;

create procedure WA_INSTANCE_WAI_DESCRIPTION_INDEX_HOOK(inout vtb any, inout d_id any) {
  declare _wai_type_name, _wai_name any;
  select
    WAI_TYPE_NAME,
    WAI_NAME
  into
    _wai_type_name,
    _wai_name
  from
    WA_INSTANCE
  where
    WAI_ID = d_id;
  vt_batch_feed(vtb, _wai_type_name, 0);
  vt_batch_feed(vtb, _wai_name, 0);

  declare _u_id, _u_name, _u_full_name any;
  _u_id := (select top 1 WAM_USER from WA_MEMBER where WAM_INST = _wai_name and WAM_STATUS = 1);
  if(_u_id) {
    select
      U_NAME,
      U_FULL_NAME
    into
      _u_name,
      _u_full_name
    from
      SYS_USERS
    where
      U_ID = _u_id;
    vt_batch_feed(vtb, _u_name, 0);
    vt_batch_feed(vtb, _u_full_name, 0);
    vt_batch_feed(vtb, 'computer science', 0);
  }
  declare _wat_type any;
  _wat_type := (select WAT_TYPE from WA_TYPES where WAT_NAME = _wai_type_name);
  vt_batch_feed(vtb, _wat_type, 0);

  return 0;
}
;

create procedure WA_INSTANCE_WAI_DESCRIPTION_UNINDEX_HOOK(inout vtb any, inout d_id any) {
  declare _wai_type_name, _wai_name any;
  select
    WAI_TYPE_NAME,
    WAI_NAME
  into
    _wai_type_name,
    _wai_name
  from
    WA_INSTANCE
  where
    WAI_ID = d_id;
  vt_batch_feed(vtb, _wai_type_name, 1);
  vt_batch_feed(vtb, _wai_name, 1);

  declare _u_id, _u_name, _u_full_name any;
  _u_id := (select top 1 WAM_USER from WA_MEMBER where WAM_INST = _wai_name and WAM_STATUS = 1);
  if(_u_id) {
    select
      U_NAME,
      U_FULL_NAME
    into
      _u_name,
      _u_full_name
    from
      SYS_USERS
    where
      U_ID = _u_id;
    vt_batch_feed(vtb, _u_name, 1);
    vt_batch_feed(vtb, _u_full_name, 1);
    vt_batch_feed(vtb, 'computer science', 1);
  }
  declare _wat_type any;
  _wat_type := (select WAT_TYPE from WA_TYPES where WAT_NAME = _wai_type_name);
  vt_batch_feed(vtb, _wat_type, 1);

  return 0;
}
;

wa_exec_no_error(
  'CREATE TEXT INDEX ON WA_INSTANCE (WAI_DESCRIPTION) WITH KEY WAI_ID USING FUNCTION'
)
;

wa_exec_no_error(
  'create index WAI_TYPE_NAME_IDX1 on WA_INSTANCE (WAI_TYPE_NAME)'
)
;

wa_exec_no_error(
  'create unique index WA_INSTANCE_WAI_ID on WA_INSTANCE (WAI_ID)'
)
;

create trigger WA_MEMBER_I after insert on WA_MEMBER referencing new as N {

-- BEGIN Add activity
  declare _act,_inst_type varchar;
  declare _inst_id integer;
  _inst_id:=(select WAI_ID from DB.DBA.WA_INSTANCE  where WAI_NAME=N.WAM_INST);
  if(N.WAM_APP_TYPE is not null)
    _inst_type:=N.WAM_APP_TYPE;
  else
    _inst_type:=(select WAI_TYPE_NAME from DB.DBA.WA_INSTANCE  where WAI_NAME=N.WAM_INST);


  _act:=sprintf('<a href="http://%s">%s</a> added the <a href="http://%s" >%s</a> application.',WA_CNAME ()||WA_USER_DATASPACE(N.WAM_USER),WA_USER_FULLNAME(N.WAM_USER),WA_CNAME ()||WA_APP_INSTANCE_DATASPACE(N.WAM_INST),WA_GET_APP_NAME(_inst_type));
  OPEN_SOCIAL.DBA.add_ods_activity(N.WAM_USER,_inst_id,_act,'system','add','application',WA_APP_INSTANCE_DATASPACE(N.WAM_INST));

-- END add Activity

  declare wa web_app;
  declare tn any;

  if (N.WAM_MEMBER_TYPE = 1)
    return;

  select WAI_INST, WAI_TYPE_NAME into wa, tn from WA_INSTANCE where WAI_NAME = N.WAM_INST;

  if (N.WAM_APP_TYPE is null or N.WAM_HOME_PAGE is null)
    {
      set triggers off;
      update WA_MEMBER set
	  WAM_APP_TYPE = tn,
	  WAM_HOME_PAGE = wa_set_url_t (wa)
	  where WAM_USER = N.WAM_USER and  WAM_INST = N.WAM_INST and WAM_MEMBER_TYPE = N.WAM_MEMBER_TYPE;
      set triggers on;
    }

  wa.wa_notify_member_changed(N.WAM_USER, null, N.WAM_MEMBER_TYPE, null, N.WAM_DATA, null, N.WAM_STATUS);



  return;
}
;

create trigger WA_INSTANCE_I after insert on WA_INSTANCE
{
  update DB.DBA.WA_MEMBER
     set WAM_IS_PUBLIC = WAI_IS_PUBLIC,
         WAM_MEMBERS_VISIBLE = WAI_MEMBERS_VISIBLE,
         WAM_HOME_PAGE = wa_set_url_t (WAI_INST),
         WAM_APP_TYPE = wa_get_type_from_name (WAM_INST)
   where WAM_INST = WAI_NAME;
}
;

create trigger WA_MEMBER_U after update on WA_MEMBER referencing old as O, new as N
{
  declare wa web_app;
  select WAI_INST into wa from WA_INSTANCE where WAI_NAME = N.WAM_INST;
  wa.wa_notify_member_changed (N.WAM_USER, O.WAM_MEMBER_TYPE, N.WAM_MEMBER_TYPE, O.WAM_DATA, N.WAM_DATA, O.WAM_STATUS, N.WAM_STATUS);
  return;
}
;

create trigger WA_INSTANCE_U after update on WA_INSTANCE referencing old as O, new as N
{
  declare wa web_app;

  update DB.DBA.WA_MEMBER
     set WAM_IS_PUBLIC = N.WAI_IS_PUBLIC,
         WAM_MEMBERS_VISIBLE = N.WAI_MEMBERS_VISIBLE,
         WAM_HOME_PAGE = wa_set_url_t (N.WAI_INST),
         WAM_APP_TYPE = wa_get_type_from_name (WAM_INST)
   where WAM_INST = N.WAI_NAME;

  if (
      (O.WAI_NAME <> N.WAI_NAME) or
      (O.WAI_IS_PUBLIC <> N.WAI_IS_PUBLIC) or
      (O.WAI_MEMBERS_VISIBLE <> N.WAI_MEMBERS_VISIBLE)
     )
  {
	  declare wa web_app;
	  declare m any;

    wa := N.WAI_INST;
    m := udt_implements_method (wa, fix_identifier_case ('wa_update_instance'));
    if (m)
	    call (m) (wa, vector (O.WAI_NAME, O.WAI_IS_PUBLIC), vector (N.WAI_NAME, N.WAI_IS_PUBLIC));
  }
  if (O.WAI_NAME <> N.WAI_NAME)
  {
    wa := N.WAI_INST;
    wa.wa_name := N.WAI_NAME;

    set triggers off;
    update WA_INSTANCE set WAI_INST = wa where WAI_NAME = N.WAI_NAME;
    update WA_INVITATIONS set WI_INSTANCE = N.WAI_NAME where WI_INSTANCE = O.WAI_NAME;
    set triggers on;
  }
}
;

create trigger WA_MEMBER_D after delete on WA_MEMBER
{
  declare wa web_app;
  declare exit handler for not found {
    return;
  };
  select WAI_INST into wa from WA_INSTANCE where WAI_NAME = WAM_INST;
  wa.wa_notify_member_changed (WAM_USER, WAM_MEMBER_TYPE, null, WAM_DATA, null, WAM_STATUS, null);
  return;
}
;

create trigger WA_MEMBER_I_DOINSTCOUNT after insert on WA_MEMBER referencing new as N
{
  if (N.WAM_MEMBER_TYPE = 1)
  {
    declare _inst_type varchar;
    declare _inst_count integer;
    declare exit handler for not found {
      return;
    };

    select WAI_TYPE_NAME into _inst_type from WA_INSTANCE where WAI_NAME = N.WAM_INST;


    declare exit handler for not found {
        insert into WA_MEMBER_INSTCOUNT(WMIC_TYPE_NAME,WMIC_UID,WMIC_INSTCOUNT) values (_inst_type,N.WAM_USER,0);
    };
    select WMIC_INSTCOUNT into _inst_count from WA_MEMBER_INSTCOUNT where WMIC_TYPE_NAME=_inst_type and WMIC_UID=N.WAM_USER;

    update WA_MEMBER_INSTCOUNT set WMIC_INSTCOUNT=WMIC_INSTCOUNT+1
     where WMIC_TYPE_NAME=_inst_type and WMIC_UID=N.WAM_USER;
  }

  return;
}
;

create trigger WA_MEMBER_D_DOINSTCOUNT after delete on WA_MEMBER
{
  if (WAM_MEMBER_TYPE = 1)
  {
    declare _inst_type varchar;
    declare _inst_count integer;
    declare exit handler for not found {
      return;
    };
    select WAI_TYPE_NAME into _inst_type from WA_INSTANCE where WAI_NAME = WAM_INST;

    declare exit handler for not found {
        return;
    };
    select WMIC_INSTCOUNT into _inst_count from WA_MEMBER_INSTCOUNT where WMIC_TYPE_NAME=_inst_type and WMIC_UID=WAM_USER;


    update WA_MEMBER_INSTCOUNT set  WMIC_INSTCOUNT=WMIC_INSTCOUNT-1
     where WMIC_TYPE_NAME=_inst_type and WMIC_UID=WAM_USER;
  }

  return;
}
;

create procedure wa_check_package (in pname varchar) -- Duplicate conductor procedure
{

  if (wa_vad_check (pname) is null)
    return 0;
  return 1;
}
;


create procedure wa_check_app (
  in app_type varchar,
  in user_id integer)
{
  return coalesce ((select top 1 WAI_ID from DB.DBA.WA_MEMBER, DB.DBA.WA_INSTANCE where WAM_INST = WAI_NAME and WAM_USER = user_id and WAI_TYPE_NAME = app_type order by WAI_ID), 0);
}
;

create procedure wa_check_owner_app (
  in wad_type varchar,
  in app_type varchar,
  in user_id integer)
{
  return case when (wa_check_package (wad_type) and exists (select 1 from DB.DBA.WA_MEMBER where WAM_APP_TYPE = app_type and WAM_MEMBER_TYPE = 1 and WAM_USER = user_id)) then 1 else 0 end;
}
;

create procedure wa_vad_check (in pname varchar)
{
  declare nam varchar;
  nam := get_keyword (pname, vector ('blog2','Weblog','oDrive','Briefcase','enews2','Feed Manager',
  				     'oMail','Mail','bookmark','Bookmarks','oGallery','Gallery',
				     'wiki','Wiki', 'wa', 'Framework','nntpf','Discussion',
				     'polls','Polls', 'addressbook','AddressBook', 'calendar','Calendar', 'IM', 'Instant Messenger'), null);
  if (nam is null)
    return vad_check_version (pname);
  else
    return vad_check_version (nam);
}
;

create trigger SYS_USERS_WA_AU after update on "DB"."DBA"."SYS_USERS" order 66 referencing old as O, new as N
{
  declare name varchar;

  name := connection_get ('WA_USER_DISABLED');
  if (not isnull (name))
    return;

  if (O.U_ACCOUNT_DISABLED <> N.U_ACCOUNT_DISABLED)
    DB.DBA.WA_USER_SETTING_SET (N.U_NAME, 'DISABLED_BY', 'dav');
}
;

create trigger SYS_USERS_ON_DELETE_WA_FK before delete on "DB"."DBA"."SYS_USERS" order 66 referencing old as O
{
  ODS_DELETE_USER_DATA(O.U_NAME);
}
;

insert soft WA_MEMBER_MODEL (WMM_ID, WMM_NAME) values (0, 'Open')
;

insert soft WA_MEMBER_MODEL (WMM_ID, WMM_NAME) values (1, 'Closed')
;

insert replacing WA_MEMBER_MODEL (WMM_ID, WMM_NAME) values (2, 'Invitation Only')
;

insert soft WA_MEMBER_MODEL (WMM_ID, WMM_NAME) values (3, 'Approval Based')
;

delete from WA_MEMBER_MODEL where WMM_NAME = 'Notify owner via E-mail'
;


--insert soft WA_MEMBER_MODEL (WMM_ID, WMM_NAME) values (4, 'Notify owner via E-mail')
--;

-- UI stuff
create procedure
web_user_password_check (in name varchar, in pass varchar)
{
  declare rc int;

  if (coalesce ((select TOP 1 WS_LOGIN from DB.DBA.WA_SETTINGS), 1) = 0)
    return 0;

  if (length (name))
    {
      declare exit handler for sqlstate '*' {
	rollback work;
	return 0;
      };
      rc := DB.DBA.LDAP_LOGIN (name, null, vector ('authtype','basic','pass',pass));
      if (rc <> -1)
	{
	  commit work;
	return rc;
    }
    }
  rc := 0;
  if (exists (select 1 from SYS_USERS where U_NAME = name and U_DAV_ENABLE = 1 and U_IS_ROLE = 0 and pwd_magic_calc (U_NAME, U_PASSWORD, 1) = pass and U_ACCOUNT_DISABLED = 0))
    {
    update WS.WS.SYS_DAV_USER set U_LOGIN_TIME = now () where U_NAME = name and (U_LOGIN_TIME is null or U_LOGIN_TIME < dateadd ('minute', -2, now ()));
    commit work;
      rc := 1;
    }
  return rc;
}
;

create procedure inst_child_node (in path varchar, in node varchar)
{
  return xpath_eval (path, node, 0);
}
;

create procedure inst_root_node (in path varchar)
{
  return xpath_eval ('/*',inst_node (), 0);
}
;

create procedure inst_node ()
{
  declare ss any;
  ss := string_output ();
  xml_auto (
'select
  1 as tag,
  null as parent,
  WAT_NAME as [node!1!name],
  null as [node!2!name],
  null as [node!3!name]
  from WA_TYPES
union all
select
  2,
  1,
  WAT_NAME,
  WAI_NAME,
  null
  from WA_INSTANCE, WA_TYPES where WAI_TYPE_NAME = WAT_NAME
union all
select
  2,
  1,
  WAT_NAME,
  \'\',
  null
  from WA_TYPES
union all
select
  3,
  2,
  WAT_NAME,
  WAI_NAME,
  U_NAME
  from WA_INSTANCE, WA_TYPES, SYS_USERS, WA_MEMBER where WAM_STATUS <= 2 WAI_TYPE_NAME = WAT_NAME and
  WAM_USER = U_ID and WAM_INST = WAI_NAME
order by [node!1!name], [node!2!name], [node!3!name]
for xml explicit'
, vector (), ss);
  return xml_tree_doc (string_output_string (ss));
}
;

create procedure WA_HTTPS ()
{
  declare default_host, ret varchar;
  ret := connection_get ('WA_HTTPS');
  if (ret is not null)
    return ret;
  default_host := cfg_item_value (virtuoso_ini_path (), 'URIQA', 'DefaultHost');
  if (default_host is not null)
    {
      declare vec, sslp any;
      sslp := server_https_port ();
      if (sslp <> '443')
        sslp := ':'||sslp;
      else
        sslp := '';
      vec := split_and_decode (default_host, 0, '\0\0:');
      if (length (vec) = 2)
        {
	  ret := vec[0] || sslp;
	}
      else
        {
	  ret := default_host || sslp;
	}
    }
  else
    {
      ret := sys_stat ('st_host_name');
      if (server_https_port () <> '443')
	ret := ret ||':'|| server_https_port ();
    }
  connection_set ('WA_HTTPS', ret);
  return ret;
};

create procedure WA_CNAME ()
{
  declare default_host, ret varchar;
  ret := connection_get ('WA_CNAME');
  if (ret is not null)
    return ret;
  default_host := cfg_item_value (virtuoso_ini_path (), 'URIQA', 'DefaultHost');
  if (default_host is not null)
    ret := default_host;
  else
    {
      ret := sys_stat ('st_host_name');
      if (server_http_port () <> '80')
	ret := ret ||':'|| server_http_port ();
    }
  connection_set ('WA_CNAME', ret);
  return ret;
};

create procedure WA_DEFAULT_DOMAIN ()
{
  declare cname, arr varchar;
  cname := WA_CNAME ();
  arr := split_and_decode (cname, 0, '\0\0:');
  if (length (arr) = 2)
    return arr[0];
  else if (length (arr) = 1)
    return arr[0];
  else
    return cname;
};

create procedure WA_GET_PROTOCOL()
{
  return case when is_https_ctx () then 'https://' else 'http://' end;
};

create procedure WA_GET_HOST()
{
  declare ret varchar;
  declare default_host varchar;
  if (is_http_ctx ())
    {
      ret := http_request_header (http_request_header (), 'Host', null, sys_connected_server_address ());
    }
  else
   {
     default_host := cfg_item_value (virtuoso_ini_path (), 'URIQA', 'DefaultHost');
     if (default_host is not null)
       return default_host;
     ret := sys_stat ('st_host_name');
     if (server_http_port () <> '80')
       ret := ret ||':'|| server_http_port ();
   }

  return ret;
}
;

create procedure WA_MAIL_TEMPLATES(in templ varchar,
                                   in app web_app default null,
                                   in user_name varchar default '',
                                   in app_action_url varchar default '') returns varchar
{

  declare service_name varchar;
  declare app_type, _u_name, full_name, e_mail, password1, descrip varchar;
  declare _u_id, join1, reg1 integer;


  if (templ = '' or templ is null)
    return '';

  select top 1 WS_WEB_TITLE into service_name from WA_SETTINGS;

  if (not length (service_name))
    service_name := sys_stat ('st_host_name');

  _u_name := '';
  full_name := '';
  if(app is not null) {
    select
      WAT_DESCRIPTION
    into
      app_type
    from
      DB.DBA.WA_TYPES,
      DB.DBA.WA_INSTANCE
    where
      WAI_NAME = app.wa_name and
      WAT_NAME = WAI_TYPE_NAME;
    templ := replace(templ, '%app%', app_type);
    -- get owner name
    _u_id := (select top 1 WAM_USER from WA_MEMBER where WAM_INST = app.wa_name and WAM_STATUS = 1);
    if(_u_id) {
      select U_NAME into _u_name from SYS_USERS where U_ID = _u_id;
    }
    templ := replace(templ, '%app_owner%', _u_name);
    templ := replace(templ, '%app_name%', app.wa_name);
    templ := replace(templ, '%app_url%', concat('http://', WA_CNAME(), app.wa_home_url()));
  }
  templ := replace(templ, '%wa_home%', wa_link (1));
  templ := replace(templ, '%service_url%', wa_link (1));
  templ := replace(templ, '%service%', service_name);
  templ := replace(templ, '%app_action_url%', app_action_url);

  if (user_name <> '' and user_name is not null) {
    select U_FULL_NAME, U_E_MAIL, pwd_magic_calc(U_NAME, U_PASSWORD, 1)
      into full_name, e_mail, password1 from SYS_USERS where u_name = user_name;
    templ := replace(templ, '%user%', coalesce (full_name, user_name));
    templ := replace(templ, '%username%', user_name);
    templ := replace(templ, '%password%', password1);
  }

  join1 := 0;
  reg1 := 0;
  select top 1 WS_JOIN_EXPIRY, WS_REGISTRATION_EMAIL_EXPIRY into join1, reg1 from WA_SETTINGS;
  templ := replace(templ, '%timeout_join%', cast(join1 as varchar));
  templ := replace(templ, '%timeout_reg%', cast(reg1 as varchar));
  descrip := '';
  for select WAT_NAME, WAT_DESCRIPTION from WA_TYPES order by 1 do {
    if (WAT_NAME is not null)
      descrip := concat(descrip, WAT_NAME, ' ');
    if (WAT_DESCRIPTION is not null)
      descrip := concat(descrip, WAT_DESCRIPTION, '\r\n');
  }
  templ := replace(templ, '%apps_available%', descrip);
  return templ;
}
;

-- /* imitialize server settings */
create procedure INIT_SERVER_SETTINGS ()
{
  declare cnt integer;

  cnt := (select count(*) from WA_SETTINGS);
  if (cnt > 1)
  {
    declare fr int;
    fr := (select top 1 WS_ID from WA_SETTINGS order by WS_ID);

    delete from WA_SETTINGS where WS_ID > fr;
  }
  else if (cnt = 0)
  {
    insert soft WA_SETTINGS
  	  (
  	   WS_LOGIN,
       WS_LOGIN_OPENID,
       WS_LOGIN_FACEBOOK,
       WS_LOGIN_TWITTER,
       WS_LOGIN_LINKEDIN,
       WS_LOGIN_SSL,
  	   WS_REGISTER,
       WS_REGISTER_OPENID,
       WS_REGISTER_FACEBOOK,
       WS_REGISTER_TWITTER,
       WS_REGISTER_LINKEDIN,
       WS_REGISTER_SSL,
       WS_REGISTER_SSL_FILTER,
       WS_REGISTER_SSL_RULE,
       WS_REGISTER_SSL_REALM,
       WS_REGISTER_AUTOMATIC_SSL,
  	   WS_MAIL_VERIFY,
  	   WS_REGISTRATION_EMAIL_EXPIRY,
  	   WS_JOIN_EXPIRY,
  	   WS_USE_DEFAULT_SMTP,
  	   WS_MEMBER_MODEL,
  	   WS_WEB_BANNER,
  	   WS_WEB_TITLE,
  	   WS_WEB_DESCRIPTION,
  	   WS_WELCOME_MESSAGE,
  	   WS_WELCOME_MESSAGE2,
  	   WS_COPYRIGHT,
  	   WS_DISCLAIMER,
  	   WS_DEFAULT_MAIL_DOMAIN,
	   WS_UNIQUE_MAIL
  	  )
	  values
	    (
	     1,
	     1,
	     1,
	     1,
	     1,
	     1,
	     1,
	     1,
	     1,
	     1,
	     1,
	     1,
	     0,
       'ODS_REGISTRATION_RULE',
       'ODS',
	     1,
	     0,
	     24,
	     72,
	     0,
	     0,
	     'default',
	     '',
	     'Enter your User ID and Password',
	     '',
	     '',
	     'Copyright &copy; 1998-2014 OpenLink Software',
	     '',
	     sys_stat ('st_host_name'),
	     1
	    );
  }
  update WA_SETTINGS set WS_COPYRIGHT = 'Copyright &copy; 1998-2014 OpenLink Software';

  update WA_SETTINGS
     set WS_WELCOME_MESSAGE =
'<h3>
Welcome to OpenLink Data Spaces (ODS)</h3>

<p>A distributed collaborative application platform that provides a "Linked Data Junction Box" for Web protocols accessible data across a myriad of data sources.</p>

<p>ODS provides a cost-effective route for creating and exploit presence on
the emerging Web of Linked Data. It enables you to transparently mesh
data across Weblogs, Shared Bookmarking, Feeds Aggregation, Photo
Gallery, Calendars, Discussions, Content Managers, and Social Networks.</p>

<p>ODS essentially provides distributed data across personal, group, and
community data spaces that is grounded in Web Architecture. It makes
extensive use of current and emerging standards across it''s core and
within specific functionality realms.</p>

<p>ODS Benefits include:</p>
<ul>
  <li>Platform independent solution for Data Portability via support for all major data interchange standards</li>
  <li>Powerful solution for meshing data from a myriad of data sources across Intranets, Extranets, and the Internet</li>
  <li>Coherent integration of Blogs, Wikis, and similar systems (native and external) that expose structured Linked Data</li>
  <li>Collaborative content authoring and data generation without any exposure to underlying complexities of such activities</li>
</ul>
'
   where WS_WELCOME_MESSAGE is null or trim (WS_WELCOME_MESSAGE) = '';

  update WA_SETTINGS
     set WS_WELCOME_MESSAGE2 =
'<h3>
Welcome to OpenLink Data Spaces</h3>
<p>
<i>There are many data spaces in the net, but this is yours</i>
<br />
OpenLink Data Spaces Applications can help you through your daily tasks.</p><p>Utilize and manage your contact network. Keep up to date with latest
news on subjects that interest you. Communicate with others using email, discussion lists and weblogs.
Collaborate with authoring information on Wikis, and much more!
</p>
'
   where WS_WELCOME_MESSAGE2 is null or trim (WS_WELCOME_MESSAGE2) = '';
}
;

INIT_SERVER_SETTINGS ();

create procedure wa_register_upgrade() {

  if (registry_get ('__wa_register_upgrade') = 'done')
    return;

  update WA_SETTINGS
  	 set WS_REGISTER_OPENID = 1,
         WS_REGISTER_FACEBOOK = 1,
         WS_REGISTER_SSL = 1,
         WS_REGISTER_AUTOMATIC_SSL = 1;

  registry_set ('__wa_register_upgrade', 'done');
}
;

wa_register_upgrade()
;

create procedure wa_register_upgrade() {

  if (registry_get ('__wa_register_upgrade2') = 'done')
    return;

  update WA_SETTINGS
  	 set WS_LOGIN = WS_REGISTER,
  	     WS_LOGIN_OPENID = WS_REGISTER_OPENID,
         WS_LOGIN_FACEBOOK = WS_REGISTER_FACEBOOK,
  	     WS_LOGIN_TWITTER = WS_REGISTER_TWITTER,
  	     WS_LOGIN_LINKEDIN = WS_REGISTER_LINKEDIN,
         WS_LOGIN_SSL = WS_REGISTER_SSL;

  registry_set ('__wa_register_upgrade2', 'done');
}
;

wa_register_upgrade()
;

create procedure WA_RETRIEVE_MESSAGE (in str any)
{
  declare pos1, pos2 any;
  pos1 := locate('%%', str, 1);
  if(not pos1) return str;
  pos2 := locate('%%', str, pos1 + 1);
  if(not pos2) return str;
  return subseq(str, pos1 + 1, pos2 - 1);
}
;

create procedure WA_STATUS_NAME(in status int)
{
  if (status = 1)
    return 'Application owner';

  if (status = 2)
    return 'Approved';

  if (status = 3)
    return 'Owner approval pending';

  if (status = 4)
    return 'User approval pending';

    return 'Invalid status';
  }
;

create procedure WA_USER_GET_OPTION(in _name varchar,in _key varchar)
{
  declare _data,_uid any;
  whenever not found goto nf;
  SELECT U_ID INTO _uid FROM SYS_USERS WHERE U_NAME = _name;
  _data := (SELECT deserialize(WAUS_DATA) FROM WA_USER_SETTINGS WHERE WAUS_U_ID = _uid AND upper(WAUS_KEY) = upper(_key));
  return _data;

 nf:
   signal ('42000', sprintf ('The object "%s" does not exists.', _name), 'U0002');
}
;

create procedure WA_USER_SET_OPTION(in _name varchar,in _key varchar,in _data any)
{
  declare _uid any;
  whenever not found goto nf;
  SELECT U_ID INTO _uid FROM SYS_USERS WHERE U_NAME = _name;

  INSERT REPLACING WA_USER_SETTINGS (WAUS_U_ID,WAUS_KEY,WAUS_DATA)
    VALUES(_uid,upper(_key),serialize(_data));

  return;

 nf:
   signal ('42000', sprintf ('The object "%s" does not exists.', _name), 'U0002');
}
;

-- Countries

INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Afghanistan','af',33,65,'AF');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Akrotiri','ax',NULL,NULL,NULL);
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Albania','al',41,20,'AL');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Algeria','ag',28,3,'DZ');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('American Samoa','aq',-14.33333301544189,-170,'AS');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Andorra','an',42.5,1.5,'AD');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Angola','ao',-12.5,18.5,'AO');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Anguilla','av',18.25,-63.16666793823242,'AI');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Antarctica','ay',-90,0,'AQ');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Antigua and Barbuda','ac',17.04999923706055,-61.79999923706055,'AG');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Arctic Ocean','xq',90,0,NULL);
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Argentina','ar',-34,-64,'AR');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Armenia','am',40,45,'AM');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Aruba','aa',12.5,-69.96666717529297,'AW');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Ashmore and Cartier Islands','at',-12.23333358764648,123.0833358764648,NULL);
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Atlantic Ocean','zh',0,-25,NULL);
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Australia','as',-27,133,'AU');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Austria','au',47.33333206176758,13.33333301544189,'AT');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Azerbaijan','aj',40.5,47.5,'AZ');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Bahamas, The','bf',24.25,-76,'BS');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Bahrain','ba',26,50.54999923706055,'BH');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Baker Island','fq',0.2166666686534882,-176.5166625976562,NULL);
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Bangladesh','bg',24,90,'BD');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Barbados','bb',13.16666698455811,-59.53333282470703,'BB');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Bassas da India','bs',-21.5,39.83333206176758,NULL);
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Belarus','bo',53,28,'BY');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Belgium','be',50.83333206176758,4,'BE');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Belize','bh',NULL,NULL,'BZ');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Benin','bn',9.5,2.25,'BJ');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Bermuda','bd',32.33333206176758,-64.75,'BM');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Bhutan','bt',27.5,90.5,'BT');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Bolivia','bl',-17,-65,'BO');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Bosnia and Herzegovina','bk',44,18,'BA');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Botswana','bc',-22,24,'BW');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Bouvet Island','bv',-54.43333435058594,3.400000095367432,'BV');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Brazil','br',-10,-55,'BR');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('British Indian Ocean Territory','io',-6,71.5,'IO');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('British Virgin Islands','vi',18.5,-64.5,'VG');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Brunei','bx',4.5,114.6666641235352,'BN');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Bulgaria','bu',43,25,'BG');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Burkina Faso','uv',13,-2,'BF');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Burma','bm',22,98,NULL);
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Burundi','by',-3.5,30,'BI');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Cambodia','cb',13,105,'KH');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Cameroon','cm',6,12,'CM');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Canada','ca',60,-95,'CA');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Cape Verde','cv',16,-24,'CV');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Cayman Islands','cj',19.5,-80.5,'KY');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Central African Republic','ct',7,21,'CF');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Chad','cd',15,19,'TD');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Chile','ci',-30,-71,'CL');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('China','ch',35,105,'CN');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Christmas Island','kt',-10.5,105.6666641235352,'CX');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Clipperton Island','ip',10.28333377838135,-109.216667175293,NULL);
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Cocos (Keeling) Islands','ck',-12.5,96.83333587646484,'CC');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Colombia','co',4,-72,'CO');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Comoros','cn',-12.16666698455811,44.25,'KM');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Congo, Democratic Republic of the','cg',0,25,'CD');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Congo, Republic of the','cf',-1,15,'CG');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Cook Islands','cw',-21.23333358764648,-159.7666625976562,'CK');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Coral Sea Islands','cr',-18,152,NULL);
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Costa Rica','cs',10,-84,'CR');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Cote d\47Ivoire','iv',NULL,NULL,'CI');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Croatia','hr',45.16666793823242,15.5,'HR');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Cuba','cu',21.5,-80,'CU');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Cyprus','cy',35,33,'CY');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Czech Republic','ez',49.75,15.5,'CZ');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Denmark','da',56,10,'DK');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Dhekelia','dx',NULL,NULL,NULL);
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Djibouti','dj',11.5,43,'DJ');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Dominica','do',15.41666698455811,-61.33333206176758,'DM');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Dominican Republic','dr',19,-70.66666412353516,'DO');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('East Timor','tt',NULL,NULL,'TL');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Ecuador','ec',-2,-77.5,'EC');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Egypt','eg',27,30,'EG');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('El Salvador','es',13.83333301544189,-88.91666412353516,'SV');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Equatorial Guinea','ek',2,10,'GQ');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Eritrea','er',15,39,'ER');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Estonia','en',59,26,'EE');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Ethiopia','et',8,38,'ET');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Europa Island','eu',-22.33333396911621,40.36666488647461,NULL);
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('European Union','ee',NULL,NULL,NULL);
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Falkland Islands (Islas Malvinas)','fk',-51.75,-59,'FK');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Faroe Islands','fo',62,-7,'FO');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Fiji','fj',-18,175,'FJ');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Finland','fi',64,26,'FI');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('France','fr',46,2,'FR');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('French Guiana','fg',4,-53,'GF');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('French Polynesia','fp',-15,-140,'PF');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('French Southern and Antarctic Lands','fs',-43,67,'TF');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Gabon','gb',-1,11.75,'GA');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Gambia, The','ga',13.46666622161865,-16.5666675567627,'GM');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Gaza Strip','gz',31.41666603088379,34.33333206176758,NULL);
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Georgia','gg',42,43.5,'GE');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Germany','gm',51,9,'DE');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Ghana','gh',8,-2,'GH');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Gibraltar','gi',36.18333435058594,-5.366666793823242,'GI');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Glorioso Islands','go',-11.5,47.33333206176758,NULL);
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Greece','gr',39,22,'GR');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Greenland','gl',72,-40,'GL');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Grenada','gj',12.11666679382324,-61.66666793823242,'GD');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Guadeloupe','gp',16.25,-61.58333206176758,'GP');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Guam','gq',NULL,NULL,'GU');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Guatemala','gt',15.5,-90.25,'GT');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Guernsey','gk',49.46666717529297,-2.583333253860474,'GG');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Guinea','gv',11,-10,'GN');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Guinea-Bissau','pu',12,-15,'GW');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Guyana','gy',5,-59,'GY');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Haiti','ha',19,-72.41666412353516,'HT');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Heard Island and McDonald Islands','hm',-53.09999847412109,72.51667022705078,'HM');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Holy See (Vatican City)','vt',41.90000152587891,12.44999980926514,'VA');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Honduras','ho',15,-86.5,'HN');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Hong Kong','hk',22.25,114.1666641235352,'HK');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Howland Island','hq',0.800000011920929,-176.6333312988281,NULL);
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Hungary','hu',47,20,'HU');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Iceland','ic',65,-18,'IS');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('India','in',20,77,'IN');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Indian Ocean','xo',-20,80,NULL);
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Indonesia','id',-5,120,'ID');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Iran','ir',32,53,'IR');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Iraq','iz',33,44,'IQ');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Ireland','ei',53,-8,'IE');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Israel','is',31.5,34.75,'IL');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Italy','it',42.83333206176758,12.83333301544189,'IT');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Jamaica','jm',18.25,-77.5,'JM');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Jan Mayen','jn',71,-8,NULL);
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Japan','ja',36,138,'JP');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Jarvis Island','dq',-0.3666666746139526,-160.0500030517578,NULL);
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Jersey','je',49.25,-2.166666746139526,'JE');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Johnston Atoll','jq',16.75,-169.5166625976562,NULL);
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Jordan','jo',31,36,'JO');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Juan de Nova Island','ju',-17.04999923706055,42.75,NULL);
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Kazakhstan','kz',48,68,'KZ');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Kenya','ke',1,38,'KE');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Kingman Reef','kq',6.400000095367432,-162.3999938964844,NULL);
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Kiribati','kr',1.416666626930237,173,'KI');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Korea, North','kn',40,127,'KP');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Korea, South','ks',37,127.5,'KR');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Kuwait','ku',29.5,45.75,'KW');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Kyrgyzstan','kg',41,75,'KG');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Laos','la',18,105,NULL);
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Latvia','lg',57,25,'LV');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Lebanon','le',33.83333206176758,35.83333206176758,'LB');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Lesotho','lt',-29.5,28.5,'LS');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Liberia','li',6.5,-9.5,'LR');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Libya','ly',25,17,'LY');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Liechtenstein','ls',47.16666793823242,9.533333778381348,'LI');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Lithuania','lh',56,24,'LT');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Luxembourg','lu',49.75,6.166666507720947,'LU');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Macau','mc',22.16666603088379,113.5500030517578,NULL);
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Macedonia','mk',NULL,NULL,'MK');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Madagascar','ma',-20,47,'MG');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Malawi','mi',-13.5,34,'MW');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Malaysia','my',2.5,112.5,'MY');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Maldives','mv',3.25,73,'MV');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Mali','ml',17,-4,'ML');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Malta','mt',35.83333206176758,14.58333301544189,'MT');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Man, Isle of','im',54.25,-4.5,'IM');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Marshall Islands','rm',9,168,'MH');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Martinique','mb',14.66666698455811,-61,'MQ');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Mauritania','mr',20,-12,'MR');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Mauritius','mp',-20.28333282470703,57.54999923706055,'MU');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Mayotte','mf',-12.83333301544189,45.16666793823242,'YT');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Mexico','mx',23,-102,'MX');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Micronesia, Federated States of','fm',6.916666507720947,158.25,'FM');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Midway Islands','mq',28.21666717529297,-177.3666687011719,NULL);
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Moldova','md',47,29,'MD');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Monaco','mn',43.73333358764648,7.400000095367432,'MC');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Mongolia','mg',46,105,'MN');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Montserrat','mh',16.75,-62.20000076293945,'MS');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Morocco','mo',32,-5,'MA');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Mozambique','mz',-18.25,35,'MZ');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Namibia','wa',-22,17,'NA');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Nauru','nr',-0.5333333611488342,166.9166717529297,'NR');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Navassa Island','bq',18.41666603088379,-75.03333282470703,NULL);
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Nepal','np',28,84,'NP');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Netherlands','nl',52.5,5.75,'NL');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Netherlands Antilles','nt',12.25,-68.75,'AN');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('New Caledonia','nc',-21.5,165.5,'NC');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('New Zealand','nz',-41,174,'NZ');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Nicaragua','nu',13,-85,'NI');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Niger','ng',16,8,'NE');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Nigeria','ni',10,8,'NG');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Niue','ne',-19.03333282470703,-169.8666687011719,'NU');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Norfolk Island','nf',-29.03333282470703,167.9499969482422,'NF');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Northern Mariana Islands','cq',15.19999980926514,145.75,'MP');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Norway','no',62,10,'NO');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Oman','mu',21,57,'OM');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Other',NULL,NULL,NULL,NULL);
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Pacific Ocean','zn',0,-160,NULL);
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Pakistan','pk',30,70,'PK');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Palau','ps',7.5,134.5,'PW');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Palmyra Atoll','lq',5.866666793823242,-162.1000061035156,NULL);
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Panama','pm',9,-80,'PA');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Papua New Guinea','pp',-6,147,'PG');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Paracel Islands','pf',16.5,112,NULL);
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Paraguay','pa',-23,-58,'PY');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Peru','pe',-10,-76,'PE');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Philippines','rp',13,122,'PH');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Pitcairn Islands','pc',-25.0666675567627,-130.1000061035156,'PN');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Poland','pl',52,20,'PL');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Portugal','po',39.5,-8,'PT');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Puerto Rico','rq',18.25,-66.5,'PR');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Qatar','qa',25.5,51.25,'QA');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Reunion','re',-21.10000038146973,55.59999847412109,'RE');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Romania','ro',46,25,'RO');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Russia','rs',60,100,'RU');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Rwanda','rw',-2,30,'RW');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Saint Helena','sh',-15.93333339691162,-5.699999809265137,'SH');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Saint Kitts and Nevis','sc',17.33333396911621,-62.75,'KN');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Saint Lucia','st',13.88333320617676,-61.13333511352539,'LC');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Saint Pierre and Miquelon','sb',46.83333206176758,-56.33333206176758,'PM');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Saint Vincent and the Grenadines','vc',13.25,-61.20000076293945,'VC');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Samoa','ws',-13.58333301544189,-172.3333282470703,'WS');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('San Marino','sm',43.76666641235352,12.41666698455811,'SM');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Sao Tome and Principe','tp',1,7,'ST');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Saudi Arabia','sa',25,45,'SA');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Senegal','sg',14,-14,'SN');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Serbia and Montenegro','yi',NULL,NULL,'ME');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Seychelles','se',-4.583333492279053,55.66666793823242,'SC');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Sierra Leone','sl',8.5,-11.5,'SL');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Singapore','sn',1.366666674613953,103.8000030517578,'SG');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Slovakia','lo',48.66666793823242,19.5,'SK');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Slovenia','si',46,15,'SI');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Solomon Islands','bp',-8,159,'SB');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Somalia','so',10,49,'SO');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('South Africa','sf',-29,24,'ZA');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('South Georgia and the South Sandwich Islands','sx',-54.5,-37,'GS');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Southern Ocean','oo',-65,0,NULL);
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Spain','sp',40,-4,'ES');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Spratly Islands','pg',8.633333206176758,111.9166641235352,NULL);
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Sri Lanka','ce',7,81,'LK');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Sudan','su',15,30,'SD');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Suriname','ns',4,-56,'SR');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Svalbard','sv',78,20,'SJ');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Swaziland','wz',-26.5,31.5,'SZ');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Sweden','sw',62,15,'SE');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Switzerland','sz',47,8,'CH');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Syria','sy',35,38,'SY');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Taiwan','tw',23.5,121,'TW');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Tajikistan','ti',39,71,'TJ');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Tanzania','tz',-6,35,'TZ');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Thailand','th',15,100,'TH');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Togo','to',8,1.166666626930237,'TG');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Tokelau','tl',-9,-172,'TK');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Tonga','tn',-20,-175,'TO');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Trinidad and Tobago','td',11,-61,'TT');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Tromelin Island','te',-15.86666679382324,54.41666793823242,NULL);
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Tunisia','ts',34,9,'TN');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Turkey','tu',39,35,'TR');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Turkmenistan','tx',40,60,'TM');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Turks and Caicos Islands','tk',21.75,-71.58333587646484,'TC');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Tuvalu','tv',-8,178,'TV');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Uganda','ug',1,32,'UG');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Ukraine','up',49,32,'UA');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('United Arab Emirates','ae',24,54,'AE');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('United Kingdom','uk',54,-2,'GB');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('United States','us',38,-97,'US');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Uruguay','uy',-33,-56,'UY');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Uzbekistan','uz',41,64,'UZ');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Vanuatu','nh',-16,167,'VU');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Venezuela','ve',8,-66,'VE');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Vietnam','vm',16,106,'VN');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Virgin Islands','vq',18.33333396911621,-64.83333587646484,'VI');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Wake Island','wq',19.28333282470703,166.6000061035156,NULL);
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Wallis and Futuna','wf',-13.30000019073486,-176.1999969482422,'WF');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('West Bank','we',32,35.25,NULL);
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Western Sahara','wi',24.5,-13,'EH');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Yemen','ym',15,48,'YE');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Zambia','za',-15,30,'ZM');
INSERT REPLACING DB.DBA.WA_COUNTRY(WC_NAME,WC_CODE,WC_LAT,WC_LNG,WC_ISO_CODE) VALUES('Zimbabwe','zi',-20,30,'ZW');

insert soft WA_INDUSTRY values('Accounting/Finance');
insert soft WA_INDUSTRY values('Advertising/Public Relations');
insert soft WA_INDUSTRY values('Arts/Entertainment/Publishing');
insert soft WA_INDUSTRY values('Banking/Mortgage');
insert soft WA_INDUSTRY values('Clerical/Administrative');
insert soft WA_INDUSTRY values('Construction/Facilities');
insert soft WA_INDUSTRY values('Customer Service');
insert soft WA_INDUSTRY values('Education/Training');
insert soft WA_INDUSTRY values('Engineering/Architecture');
insert soft WA_INDUSTRY values('Government');
insert soft WA_INDUSTRY values('Healthcare');
insert soft WA_INDUSTRY values('Hospitality/Travel');
insert soft WA_INDUSTRY values('Human Resources');
insert soft WA_INDUSTRY values('Insurance');
insert soft WA_INDUSTRY values('Internet/New Media');
insert soft WA_INDUSTRY values('Law Enforcement/Security');
insert soft WA_INDUSTRY values('Legal');
insert soft WA_INDUSTRY values('Management Consulting');
insert soft WA_INDUSTRY values('Manufacturing/Operations');
insert soft WA_INDUSTRY values('Marketing');
insert soft WA_INDUSTRY values('Non-Profit/Volunteer');
insert soft WA_INDUSTRY values('Pharmaceutical/Biotech');
insert soft WA_INDUSTRY values('Real Estate');
insert soft WA_INDUSTRY values('Restaurant/Food Service');
insert soft WA_INDUSTRY values('Retail');
insert soft WA_INDUSTRY values('Sales');
insert soft WA_INDUSTRY values('Technology');
insert soft WA_INDUSTRY values('Telecommunications');
insert soft WA_INDUSTRY values('Transportation/Logistics');
insert soft WA_INDUSTRY values('Other');

delete from WA_TYPES where WAT_NAME = 'WA' and WAT_DESCRIPTION = 'wa' and WAT_TYPE = 'db.dba.web_app' and WAT_REALM = 'wa';
delete from WA_INSTANCE where WAI_NAME = 'WA' and WAI_TYPE_NAME = 'WA';


create procedure
sql_user_password (in name varchar)
{
  declare pass varchar;
  pass := NULL;
  whenever not found goto none;
  select pwd_magic_calc (U_NAME, U_PASSWORD, 1) into pass
      from DB.DBA.SYS_USERS where U_NAME = name;
none:
  return pass;
}
;

create procedure
sql_user_password_check (in name varchar, in pass varchar)
{
  if (exists (select 1 from DB.DBA.SYS_USERS where U_NAME = name and pwd_magic_calc (U_NAME, U_PASSWORD, 1) = pass))
    return 1;
  return 0;
}
;

create procedure
db.dba.dav_browse_proc1 (in path varchar,
                         in show_details integer := 0,
                         in dir_select integer := 0,
                         in filter varchar := '',
                         in search_type integer := -1,
                         in search_word varchar := '',
			 in ord any := '',
			 in ordseq varchar := 'asc'
			 ) returns any
{
  declare i, j, len, len1 integer;
  declare dirlist, retval any;
  declare cur_user, cur_group, user_name, group_name, perms, perms_tmp, cur_file varchar;
  declare stat, msg, mdt, dta any;

  cur_user := connection_get ('vspx_user');
  path := replace (path, '"', '');

  if (length (path) = 0 and search_type = -1)
    {
      if (show_details = 0)
        retval := vector (vector (1, 'DAV', NULL, '0', '', 'Root', '', '', ''));
      else
        retval := vector (vector (1, 'DAV'));
      return retval;
    }
  else
    if (length(path) = 0 and search_type <> -1)
      path := 'DAV';

  if (path[length (path) - 1] <> ascii ('/'))
    path := concat (path, '/');

  if (path[0] <> ascii ('/'))
    path := concat ('/', path);

  if (isnull (filter) or filter = '')
    filter := '%';

  replace (filter, '*', '%');
  retval := vector ();
  if (search_type = 0 or search_type = -1)
    {
      if (ord = 'name')
	ord := 11;
      else if (ord = 'size')
	ord := 3;
      else if (ord = 'type')
	ord := 10;
      else if (ord = 'modified')
	ord := 4;
      else if (ord = 'owner')
	ord := 8;
      else if (ord = 'group')
	ord := 7;

      if (isinteger (ord))
	ord := sprintf (' order by %d %s', ord, ordseq);

      if (search_type = 0)
	{
	  --dbg_obj_print ('case 1');
	  exec (concat ('select * from Y_DAV_DIR where path = ? and recursive = ? and auth_uid = ? ', ord),
	     stat, msg, vector (path, 1, cur_user), 0, mdt, dirlist);
	  -- old behaviour
          --dirlist := YACUTIA_DAV_DIR_LIST (path, 1, cur_user);
	}
      else
	{
	  --dbg_obj_print ('case 2');
	  exec (concat ('select * from Y_DAV_DIR where path = ? and recursive = ? and auth_uid = ? ', ord),
	     stat, msg, vector (path, 0, cur_user), 0, mdt, dirlist);
	  --dbg_obj_print (dirlist);
	  -- old behaviour
          -- dirlist := YACUTIA_DAV_DIR_LIST (path, 0, cur_user);
	}

      if (not isarray (dirlist))
        return retval;

      len := length (dirlist);
      i := 0;

      while (i < len)
        {
          if (lower (dirlist[i][1]) = 'c') --  and dirlist[i][10] like filter) -- lets not filter out collections!
            {
              cur_file := trim (dirlist[i][0], '/');
              cur_file := subseq (cur_file, strrchr (cur_file, '/') + 1);

              if (search_type = -1 or
                  (search_type = 0 and cur_file like search_word))
                {
                  if (show_details = 0)
                    {
                      if (dirlist[i][7] is not null)
                        user_name := dirlist[i][7];
                      else
                        user_name := 'none';

                      if (dirlist[i][6] is not null)
                        group_name := dirlist[i][6];
                      else
                        group_name := 'none';

	              perms_tmp := dirlist[i][5];
                      if (length (perms_tmp) = 9)
                        perms_tmp := perms_tmp || 'N';
                      perms := DAV_PERM_D2U (perms_tmp);

                      if (search_type = 0)
                        retval :=
                          vector_concat(retval,
                                        vector (vector (1,
                                                        dirlist[i][0],
                                                        NULL,
                                                        'N/A',
                                                        yac_hum_datefmt (dirlist[i][3]),
                                                        'folder',
                                                        user_name,
                                                        group_name,
                                                        perms)));
                      else
                        retval :=
                          vector_concat(retval,
                                        vector (vector (1,
                                                        dirlist[i][10],
                                                        NULL,
                                                        'N/A',
                                                        yac_hum_datefmt (dirlist[i][3]),
                                                        'folder',
                                                        user_name,
                                                        group_name,
                                                        perms)));
                    }
                  else
                    {
                      if (search_type = 0)
                        retval := vector_concat(retval,
                                                vector (vector (1, dirlist[i][0])));
                      else
                        retval := vector_concat(retval,
                                                vector (vector (1, dirlist[i][10])));
                    }
                  }
                }
              i := i + 1;
            }
          if (dir_select = 0 or dir_select = 2)
            {
              i := 0;
              while (i < len)
                {
                  if (lower (dirlist[i][1]) <> 'c' and dirlist[i][10] like filter)
                    {
                      cur_file := trim (aref (aref (dirlist, i), 0), '/');
                      cur_file := subseq (cur_file, strrchr (cur_file, '/') + 1);

                      if (search_type = -1 or
                          (search_type = 0 and cur_file like search_word))
                        {
                          if (show_details = 0)
                            {
                              if (dirlist[i][7] is not null)
				user_name := dirlist[i][7];
                              else
                                user_name := 'none';

                              if (dirlist[i][6] is not null)
				group_name := dirlist[i][6];
                              else
                                group_name := 'none';

	              	      perms_tmp := dirlist[i][5];
                      	      if (length (perms_tmp) = 9)
                        	perms_tmp := perms_tmp || 'N';
			      perms := DAV_PERM_D2U (perms_tmp);

                              if (search_type = 0)
                                retval :=
                                  vector_concat(retval,
                                                vector (vector (0,
                                                                dirlist[i][0],
                                                                NULL,
                                                                yac_hum_fsize (dirlist[i][2]),
                                                                yac_hum_datefmt (dirlist[i][3]),
                                                                dirlist[i][9],
                                                                user_name,
                                                                group_name,
                                                                perms )));
                              else
                                retval :=
                                  vector_concat(retval,
                                                vector( vector (0,
                                                                dirlist[i][10],
                                                                NULL,
                                                                yac_hum_fsize (dirlist[i][2]),
                                                                yac_hum_datefmt (dirlist[i][3]),
                                                                dirlist[i][9],
                                                                user_name,
                                                                group_name,
                                                                perms )));
                            }
                          else
                            {
                              if (search_type = 0)
                                retval := vector_concat (retval,
                                                         vector(vector(0, dirlist[i][0])));
                              else
                                retval := vector_concat (retval,
                                                         vector(vector(0, dirlist[i][10])));
                            }
                        }
                    }
                    i := i + 1;
                  }
         }
            }
          else
            if (search_type = 1)
              {
                retval := vector();
                declare _u_name, _g_name varchar;
                declare _maxres integer;
                declare _qtype varchar;
                declare _out varchar;
                declare _style_sheet varchar;
                declare inx integer;
                declare _qfrom varchar;
                declare _root_elem varchar;
                declare _u_id, _cutat integer;
                declare _entity any;
                declare _res_name_sav varchar;
                declare _out_style_sheet, _no_matches, _trf, _disp_result varchar;
                declare _save_as, _own varchar;

    -- These parameters are needed for WebDAV browser

                declare _current_uri, _trf_doc, _q_scope, _sty_to_ent,
                _sid_id, _sys, _mod varchar;
                declare _dav_result any;
                declare _e_content any;
                declare err varchar;
                declare _no_match, _last_match, _prev_match, _cntr integer;

                err := ''; stat := '00000';
                _dav_result := null;

                declare exit handler for sqlstate '*'
                  {
                    stat := __SQL_STATE; err := __SQL_MESSAGE;
                  };

	      if (ord = 'name')
		ord := 2;
	      else if (ord = 'size')
		ord := 10;
	      else if (ord = 'type')
		ord := 6;
	      else if (ord = 'modified')
		ord := 7;
	      else if (ord = 'owner')
		ord := 4;
	      else if (ord = 'group')
		ord := 5;

	      if (isinteger (ord))
		ord := sprintf (' order by %d %s', ord, ordseq);

                if (not is_empty_or_null (search_word))
                  {
		    stat := '00000';
                    exec (concat ('select RES_ID, RES_NAME, RES_CONTENT, RES_OWNER, RES_GROUP, RES_TYPE, RES_MOD_TIME, RES_PERMS,
                                RES_FULL_PATH, length (RES_CONTENT)
                           from WS.WS.SYS_DAV_RES
                           where contains (RES_CONTENT, ?)', ord), stat, msg, vector (search_word), 0, mdt, dta);


		    if (stat = '00000')
		      {
			declare RES_ID, RES_NAME, RES_CONTENT, RES_OWNER, RES_GROUP, RES_TYPE,
				RES_MOD_TIME, RES_PERMS, RES_FULL_PATH any;

			foreach (any elm in dta) do
			  {
			    RES_ID := elm[0];
			    RES_NAME := elm[1];
		            RES_CONTENT := elm[2];
	    		    RES_OWNER := elm[3];
	                    RES_GROUP  := elm[4];
	                    RES_TYPE  := elm[5];
	                    RES_MOD_TIME  := elm[6];
	                    RES_PERMS  := elm[7];
	                    RES_FULL_PATH := elm[8];

			    if (exists (select 1 from WS.WS.SYS_DAV_PROP
					  where PROP_NAME = 'xper' and
						PROP_TYPE = 'R' and
						PROP_PARENT_ID = RES_ID))
			      {
				_e_content := string_output ();
				http_value (xml_persistent (RES_CONTENT), null, _e_content);
				_e_content := string_output_string (_e_content);
			      }
			    else
			      _e_content := RES_CONTENT;

			    if (RES_GROUP is not null and RES_GROUP > 0)
			      {
				_g_name := (select G_NAME from WS.WS.SYS_DAV_GROUP where G_ID = RES_GROUP);
			      }
			    else
			      {
				_g_name := 'no group';
			      }

			    if (RES_OWNER is not null and RES_OWNER > 0)
			      {
				_u_name := (select U_NAME from WS.WS.SYS_DAV_USER where U_ID = RES_OWNER);
			      }
			    else
			      {
				_u_name := 'Public';
			      }

			    if (show_details = 0)
			      {
				retval :=
				  vector_concat (retval,
						 vector (vector (0,
								 RES_FULL_PATH,
								 NULL,
								 yac_hum_fsize (length (RES_CONTENT)),
								 yac_hum_datefmt (RES_MOD_TIME),
								 RES_TYPE,
								 _u_name,
								 _g_name,
								 adm_dav_format_perms (RES_PERMS))));
			      }
			    else
			      {
				retval := vector_concat(retval,
							vector (vector (0,
									RES_FULL_PATH)));
			      }
		            inx := inx + 1;
	                 }
		      }
       }
    }
  return retval;
}
;

create procedure
dav_browse_proc_meta1(in show_details integer := 0) returns any
{
  declare retval any;
  if (show_details = 0)
    retval := vector('ITEM_IS_CONTAINER',
                     'ITEM_NAME',
                     'ICON_NAME',
                     'Size',
                     'Modified',
                     'Type',
                     'Owner',
                     'Group',
                     'Permissions');
  else
    retval := vector('ITEM_IS_CONTAINER', 'ITEM_NAME');
  return retval;
}
;

create procedure
YACUTIA_DAV_COPY (in path varchar,
                  in destination varchar,
                  in overwrite integer := 0,
                  in permissions varchar := '110100000R',
                  in uid any := NULL,
                  in gid any := NULL)
{
  declare rc integer;
  declare pwd1, cur_user any;
  cur_user := connection_get ('vspx_user');

  if (cur_user = 'dba')
    cur_user := 'dav';

  pwd1 := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from DB.DBA.SYS_USERS where U_NAME = cur_user);

  rc := DB.DBA.DAV_COPY (path, destination, overwrite, permissions, uid, gid, cur_user, pwd1);
  return rc;
}
;

create procedure
YACUTIA_DAV_MOVE (in path varchar,
                  in destination varchar,
                  in overwrite varchar)
{
  declare rc integer;
  declare pwd1, cur_user any;
  cur_user := connection_get ('vspx_user');

  if (cur_user = 'dba')
    cur_user := 'dav';

  pwd1 := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from DB.DBA.SYS_USERS where U_NAME = cur_user);

  rc := DB.DBA.DAV_MOVE (path, destination, overwrite, cur_user, pwd1);
  return rc;
}
;

create procedure
YACUTIA_DAV_STATUS (in status integer) returns varchar
{
  if (status = -1)
    return 'Invalid target path';

  if (status = -2)
    return 'Invalid destination path';

  if (status = -3)
    return 'Destination already exists and overwrite flag not set';

  if (status = -4)
    return 'Invalid target type (resource) in copy/move';

  if (status = -5)
    return 'Invalid permissions';

  if (status = -6)
    return 'Invalid uid';

  if (status = -7)
    return 'Invalid gid';

  if (status = -8)
    return 'Target is locked';

  if (status = -9)
    return 'Destination is locked';

  if (status = -10)
    return 'Property name is reserved (protected or private)';

  if (status = -11)
    return 'Property does not exists';

  if (status = -12)
    return 'Authentication failed';

  if (status = -13)
    return 'Insufficient privileges for operation';

  if (status = -14)
    return 'Invalid target type';

  if (status = -15)
    return 'Invalid umask';

  if (status = -16)
    return 'Property already exists';

  if (status = -17)
    return 'Invalid property value';

  if (status = -18)
    return 'No such user';

  if (status = -19)
    return 'No home directory';

  return sprintf ('Unknown error %d', status);
}
;

create procedure
YACUTIA_DAV_DELETE (in path varchar,
                    in silent integer := 0,
                    in extern integer := 1)
{
  declare rc integer;
  declare pwd1, cur_user any;
  cur_user := connection_get ('vspx_user');

  if (cur_user = 'dba')
    cur_user := 'dav';

  pwd1 := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from DB.DBA.SYS_USERS where U_NAME = cur_user);

  rc := DB.DBA.DAV_DELETE_INT (path, silent, cur_user, pwd1, extern);
  return rc;
}
;

create procedure
YACUTIA_DAV_RES_UPLOAD (in path varchar,
                        inout content any,
                        in type varchar := '',
                        in permissions varchar := '110100000R',
                        in uid varchar := 'dav',
                        in gid varchar := 'dav',
                        in cr_time datetime := null,
                        in mod_time datetime := null,
                        in _rowguid varchar := null)
{
  declare rc integer;
  declare pwd1, cur_user any;
  cur_user := connection_get ('vspx_user');

  if (cur_user = 'dba')
    cur_user := 'dav';

  pwd1 := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from DB.DBA.SYS_USERS where U_NAME = cur_user);

  rc := DB.DBA.DAV_RES_UPLOAD_STRSES (path, content, type, permissions, uid, gid, cur_user, pwd1);
  return rc;
}
;

create procedure
YACUTIA_DAV_COL_CREATE (in path varchar,
                        in permissions varchar,
                        in uid varchar,
                        in gid varchar)
{
  declare rc integer;
  declare pwd1, cur_user any;

  cur_user := connection_get ('vspx_user');

  if (cur_user = 'dba')
    cur_user := 'dav';

  pwd1 := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from DB.DBA.SYS_USERS where U_NAME = cur_user);

  rc := DB.DBA.DAV_COL_CREATE (path, permissions, uid, gid, cur_user, pwd1);
  return rc;
}
;

create procedure
YACUTIA_DAV_DIR_LIST (in path varchar := '/DAV/',
                      in recursive integer := 0,
                      in auth_uid varchar := 'dav')
{
  declare res, pwd1 any;

  if (auth_uid = 'dba')
    auth_uid := 'dav';

  pwd1 := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from DB.DBA.SYS_USERS where U_NAME = auth_uid);
  res := DB.DBA.DAV_DIR_LIST (path, recursive, auth_uid, pwd1);
  return res;
}
;

create procedure
db.dba.yac_hum_fsize (in sz integer) returns varchar
{
  if (sz = 0)
    return ('Zero');
  if (sz < 1024)
    return (sprintf ('%dB', cast (sz as integer)));
  if (sz < 102400)
    return (sprintf ('%.1fkB', sz/1024));
  if (sz < 1048576)
    return (sprintf ('%dkB', cast (sz/1024 as integer)));
  if (sz < 104857600)
    return (sprintf ('%.1fMB', sz/1048576));
  if (sz < 1073741824)
    return (sprintf ('%dMB', cast (sz/1048576 as integer)));
  return (sprintf ('%.1fGB', sz/1073741824));
}
;

create procedure
yac_hum_datefmt (in d datetime)
{

  declare date_part varchar;
  declare time_part varchar;
  declare min_diff integer;
  declare day_diff integer;

  if (isnull (d))
    {
      return ('Never');
    }

  day_diff := datediff ('day', d, now ());
  if (day_diff < 1)
    {
      min_diff := datediff ('minute', d, now ());
      if (min_diff = 1)
        {
          return ('A minute ago');
        }
      else if (min_diff < 1)
        {
          return ('Less than a minute ago');
        }
      else if (min_diff < 60)
        {
          return (sprintf ('%d minutes ago', min_diff));
        }
      else return (sprintf ('Today at %02d:%02d', hour (d), minute (d)));
    }
  if (day_diff < 2)
    {
      return (sprintf ('Yesterday at %02d:%02d', hour (d), minute (d)));
    }
  return (sprintf ('%02d/%02d/%02d %02d:%02d',
                   year (d),
                   month (d),
                   dayofmonth (d),
                   hour (d),
                   minute (d)));
}
;

create procedure
YACUTIA_DAV_DIR_LIST_P (in path varchar := '/DAV/', in recursive integer := 0, in auth_uid varchar := 'dav')
{
  declare arr, pwd1 any;
  declare i, l integer;
  declare FULL_PATH, PERMS, MIME_TYPE, NAME varchar;
  declare TYPE char(1);
  declare RLENGTH, ID, GRP, OWNER integer;
  declare MOD_TIME, CR_TIME datetime;
  result_names (FULL_PATH, TYPE, RLENGTH, MOD_TIME, ID, PERMS, GRP, OWNER, CR_TIME, MIME_TYPE, NAME);

  if (auth_uid = 'dba')
    auth_uid := 'dav';

  pwd1 := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from DB.DBA.SYS_USERS where U_NAME = auth_uid);
  arr := DB.DBA.DAV_DIR_LIST (path, recursive, auth_uid, pwd1);
  i := 0; l := length (arr);
  while (i < l)
    {
      declare own, _grp any;
      own := 'none';
      _grp := 'none';
      if (arr[i][7] is not null)
        own := coalesce ((select U_NAME from DB.DBA.SYS_USERS where U_ID = arr[i][7]), 'none');
      if (arr[i][6] is not null)
        _grp := coalesce ((select U_NAME from DB.DBA.SYS_USERS where U_ID = arr[i][6]), 'none');
      result (arr[i][0],
    arr[i][1],
    arr[i][2],
    arr[i][3],
    arr[i][4],
    arr[i][5],
    _grp,
    own,
    arr[i][8],
    arr[i][9],
    arr[i][10]);
      i := i + 1;
    }
}
;

wa_exec_no_error_log('create procedure view Y_DAV_DIR as YACUTIA_DAV_DIR_LIST_P (path,recursive,auth_uid) (FULL_PATH varchar, TYPE varchar, RLENGTH integer, MOD_TIME datetime, ID integer, PERMS varchar, GRP varchar, OWNER varchar, CR_TIME datetime, MIME_TYPE varchar, NAME varchar)')
;

/*
   conversion
*/

create procedure wa_utf8_to_wide (in s any, in _from int := 0, in _to int := 0)
{
  declare ret any;
  if (isblob (s))
    s := blob_to_string (s);
  if (isstring (s))
    ret := charset_recode (s, 'UTF-8', '_WIDE_');
  else
    ret := s;
  if (isinteger (ret))
    ret := s;
  if (_from >= 0 and _to > 0 and _to > _from)
    ret := substring (ret, _from, _to);
  return ret;
}
;

create procedure wa_wide_to_utf8 (inout str any)
{
    if (iswidestring (str))
          return charset_recode (str, '_WIDE_', 'UTF-8' );
      return str;
}
;


create procedure wa_trim (in s any)
{
  return trim (s);
}
;

/*
   mail routines
*/

create procedure WA_SEND_MAIL (in _from any, in _to any, in subj any, in msg any)
{
   declare _smtp_server, _mail_body, enc, dat any;
   if ((select max(WS_USE_DEFAULT_SMTP) from WA_SETTINGS) = 1)
     {
       _smtp_server := cfg_item_value(virtuoso_ini_path(), 'HTTPServer', 'DefaultMailServer');
     }
   else
     {
       _smtp_server := (select max(WS_SMTP) from WA_SETTINGS);
     }
  enc := encode_base64 (subj);
  enc := replace (enc, '\r\n', '');
  subj := concat ('Subject: =?UTF-8?B?', enc, '?=\r\n');
  dat := sprintf ('Date: %s\r\n', date_rfc1123 (now ()));
  _mail_body := dat || subj || 'Content-Type: text/plain; charset=UTF-8\r\n\r\n' || msg;
  --dbg_obj_print (_smtp_server);
  --dbg_obj_print (_mail_body);
  if(not _smtp_server or length(_smtp_server) = 0)
    {
      signal('WA002', 'The Mail Server is not defined. Mail can not be sent.');
    }
  --dbg_obj_print (_from, _to);
  smtp_send (_smtp_server, _from, _to, _mail_body);
}
;

wa_exec_no_error_log(
  'CREATE TABLE WA_USER_INFO
  (
    WAUI_U_ID int,
    WAUI_VISIBLE VARCHAR(55),           -- concatenation of all fields flags. (be default each is 1: 11111111...) -- 1: public, -- 2: friend, -- 3: private
    WAUI_TITLE VARCHAR(3),         -- 0
    WAUI_FIRST_NAME VARCHAR(50),   -- 1
    WAUI_LAST_NAME VARCHAR(50),    -- 2
    WAUI_FULL_NAME VARCHAR(100),   -- 3
    WAUI_GENDER VARCHAR(10),       -- 5
    WAUI_BIRTHDAY DATETIME,        -- 6
    WAUI_WEBPAGE VARCHAR(255),     -- 7
    WAUI_FOAF VARCHAR(50),              -- 8 colum type changed below -- XXX: obsolete, see WA_USER_OL_ACCOUNTS
    WAUI_MSIGNATURE VARCHAR(255),  -- 9
    WAUI_ICQ VARCHAR(50),          -- 10
    WAUI_SKYPE VARCHAR(50),        -- 11
    WAUI_AIM VARCHAR(50),          -- 12
    WAUI_YAHOO VARCHAR(50),        -- 13
    WAUI_MSN VARCHAR(50),          -- 14
    WAUI_HADDRESS1 VARCHAR(50),    -- 15
    WAUI_HADDRESS2 VARCHAR(50),    -- 15
    WAUI_HCODE VARCHAR(50),             -- 57
    WAUI_HCITY VARCHAR(50),             -- 58
    WAUI_HSTATE VARCHAR(50),            -- 59
    WAUI_HCOUNTRY VARCHAR(50),     -- 16
    WAUI_HTZONE VARCHAR(50),       -- 17
    WAUI_HPHONE VARCHAR(50),       -- 18
    WAUI_HPHONE_EXT VARCHAR(5),         -- 18
    WAUI_HMOBILE VARCHAR(50),      -- 18
    WAUI_BINDUSTRY VARCHAR(50),    -- 19
    WAUI_BORG VARCHAR(50),         -- 20
    WAUI_BJOB VARCHAR(50),         -- 21
    WAUI_BADDRESS1 VARCHAR(50),    -- 22
    WAUI_BADDRESS2 VARCHAR(50),    -- 22
    WAUI_BCODE VARCHAR(50),             -- 60
    WAUI_BCITY VARCHAR(50),             -- 61
    WAUI_BSTATE VARCHAR(50),            -- 62
    WAUI_BCOUNTRY VARCHAR(50),     -- 23
    WAUI_BTZONE VARCHAR(50),       -- 24
    WAUI_BLAT REAL,                -- 47
    WAUI_BLNG REAL,                -- 47
    WAUI_BPHONE VARCHAR(50),       -- 25
    WAUI_BPHONE_EXT VARCHAR(5),         -- 25
    WAUI_BMOBILE VARCHAR(50),      -- 25
    WAUI_BREGNO VARCHAR(50),       -- 26
    WAUI_BCAREER VARCHAR(50),      -- 27
    WAUI_BEMPTOTAL VARCHAR(50),    -- 28
    WAUI_BVENDOR VARCHAR(50),      -- 29
    WAUI_BSERVICE VARCHAR(50),     -- 30
    WAUI_BOTHER VARCHAR(50),       -- 31
    WAUI_BNETWORK VARCHAR(50),     -- 32
    WAUI_SUMMARY LONG VARCHAR,     -- 33
    WAUI_RESUME LONG VARCHAR,      -- 34
    WAUI_SEC_QUESTION VARCHAR(20), -- 35
    WAUI_SEC_ANSWER VARCHAR(20),   -- 36
    WAUI_PHOTO_URL LONG VARCHAR,   -- 37
    WAUI_TEMPLATE VARCHAR(20),	   -- 38
    WAUI_LAT REAL,                 -- 39
    WAUI_LNG REAL,                 -- 40
    WAUI_LATLNG_VISIBLE SMALLINT,  -- 41
    WAUI_USER_SEARCHABLE SMALLINT, -- 42 - new fields
    WAUI_AUDIO_CLIP LONG VARCHAR,  -- 43
    WAUI_FAVORITE_BOOKS  LONG VARCHAR,  -- 44
    WAUI_FAVORITE_MUSIC  LONG VARCHAR,  -- 45
    WAUI_FAVORITE_MOVIES LONG VARCHAR,  -- 46
    WAUI_SEARCHABLE	 int default 1,
    WAUI_SHOWACTIVE	 int default 1, -- new field related to user active information dashboard
    WAUI_LATLNG_HBDEF SMALLINT default 0,
    WAUI_SITE_NAME long varchar,
    WAUI_INTERESTS long varchar,  -- 48
    WAUI_INTEREST_TOPICS long varchar,  -- 49
    WAUI_BORG_HOMEPAGE long varchar,  -- 20 same as BORG
    WAUI_OPENID_URL varchar,
    WAUI_OPENID_SERVER varchar,
    WAUI_FACEBOOK_ID integer,           -- XXX: obsolete, see WA_USER_OL_ACCOUNTS
    WAUI_IS_ORG	int default 0,
    WAUI_APP_ENABLE	int default 0,
    WAUI_SPB_ENABLE	int default 0,
    WAUI_NICK		varchar,
    WAUI_BICQ VARCHAR,                  -- 50
    WAUI_BSKYPE VARCHAR,                -- 51
    WAUI_BAIM VARCHAR,                  -- 52
    WAUI_BYAHOO VARCHAR,                -- 53
    WAUI_BMSN VARCHAR,                  -- 54
    WAUI_MESSAGING LONG VARCHAR,        -- 55
    WAUI_BMESSAGING LONG VARCHAR,       -- 56
    WAUI_CERT_LOGIN integer default 0,  -- XXX: obsolete, see WA_USER_CERTS
    WAUI_CERT_FINGERPRINT varchar,	-- same as above
    WAUI_CERT long varbinary,		-- same as above
    WAUI_ACL LONG VARCHAR,
    WAUI_SALMON_KEY varchar, 
    WAUI_SETTINGS LONG VARCHAR,

    primary key (WAUI_U_ID)
  )'
)
;

wa_exec_no_error ('alter table DB.DBA.WA_USER_INFO modify WAUI_VISIBLE VARCHAR(70)');
wa_exec_no_error ('alter table DB.DBA.WA_USER_INFO modify WAUI_WEBPAGE VARCHAR(255)');

wa_add_col('DB.DBA.WA_USER_INFO', 'WAUI_TEMPLATE', 'VARCHAR(20)');
wa_add_col('DB.DBA.WA_USER_INFO', 'WAUI_PHOTO_URL', 'LONG VARCHAR');
wa_add_col('DB.DBA.WA_USER_INFO', 'WAUI_LAT', 'REAL');
wa_add_col('DB.DBA.WA_USER_INFO', 'WAUI_LNG', 'REAL');
wa_add_col('DB.DBA.WA_USER_INFO', 'WAUI_LATLNG_VISIBLE', 'SMALLINT');

wa_add_col ('DB.DBA.WA_USER_INFO', 'WAUI_USER_SEARCHABLE', 'SMALLINT');
wa_add_col ('DB.DBA.WA_USER_INFO', 'WAUI_AUDIO_CLIP', 'LONG VARCHAR');
wa_add_col ('DB.DBA.WA_USER_INFO', 'WAUI_FAVORITE_BOOKS', 'LONG VARCHAR');
wa_add_col ('DB.DBA.WA_USER_INFO', 'WAUI_FAVORITE_MUSIC', 'LONG VARCHAR');
wa_add_col ('DB.DBA.WA_USER_INFO', 'WAUI_FAVORITE_MOVIES', 'LONG VARCHAR');

wa_add_col ('DB.DBA.WA_USER_INFO', 'WAUI_SEARCHABLE', 'int default 1');
wa_add_col ('DB.DBA.WA_USER_INFO', 'WAUI_SHOWACTIVE', 'int default 1');

wa_add_col('DB.DBA.WA_USER_INFO', 'WAUI_BLAT', 'REAL');
wa_add_col('DB.DBA.WA_USER_INFO', 'WAUI_BLNG', 'REAL');
wa_add_col ('DB.DBA.WA_USER_INFO', 'WAUI_LATLNG_HBDEF', 'SMALLINT default 0');

wa_add_col ('DB.DBA.WA_USER_INFO', 'WAUI_JOIN_DATE', 'DATETIME', 'UPDATE DB.DBA.WA_USER_INFO SET WAUI_JOIN_DATE = now()');

wa_add_col ('DB.DBA.WA_USER_INFO', 'WAUI_SITE_NAME', 'LONG VARCHAR');
wa_add_col ('DB.DBA.WA_USER_INFO', 'WAUI_INTERESTS', 'LONG VARCHAR');
wa_add_col ('DB.DBA.WA_USER_INFO', 'WAUI_INTEREST_TOPICS', 'LONG VARCHAR');
wa_add_col ('DB.DBA.WA_USER_INFO', 'WAUI_BORG_HOMEPAGE', 'LONG VARCHAR');

wa_add_col ('DB.DBA.WA_USER_INFO', 'WAUI_BICQ', 'VARCHAR');
wa_add_col ('DB.DBA.WA_USER_INFO', 'WAUI_BSKYPE', 'VARCHAR');
wa_add_col ('DB.DBA.WA_USER_INFO', 'WAUI_BAIM', 'VARCHAR');
wa_add_col ('DB.DBA.WA_USER_INFO', 'WAUI_BYAHOO', 'VARCHAR');
wa_add_col ('DB.DBA.WA_USER_INFO', 'WAUI_BMSN', 'VARCHAR');
wa_add_col ('DB.DBA.WA_USER_INFO', 'WAUI_MESSAGING', 'LONG VARCHAR');
wa_add_col ('DB.DBA.WA_USER_INFO', 'WAUI_BMESSAGING', 'LONG VARCHAR');

wa_add_col ('DB.DBA.WA_USER_INFO', 'WAUI_CERT_LOGIN', 'integer');
wa_add_col ('DB.DBA.WA_USER_INFO', 'WAUI_CERT_FINGERPRINT', 'varchar');
wa_add_col ('DB.DBA.WA_USER_INFO', 'WAUI_CERT', 'long varbinary');

wa_add_col ('DB.DBA.WA_USER_INFO', 'WAUI_BPHONE_EXT', 'varchar(5)');
wa_add_col ('DB.DBA.WA_USER_INFO', 'WAUI_HPHONE_EXT', 'varchar(5)');

wa_add_col ('DB.DBA.WA_USER_INFO', 'WAUI_ACL', 'LONG VARCHAR');
wa_add_col ('DB.DBA.WA_USER_INFO', 'WAUI_SALMON_KEY', 'VARCHAR');

wa_add_col ('DB.DBA.WA_USER_INFO', 'WAUI_SETTINGS', 'LONG VARCHAR');

wa_exec_no_error ('create index WA_USER_INFO_CERT_FINGERPRINT on DB.DBA.WA_USER_INFO (WAUI_CERT_FINGERPRINT)');

create procedure WA_USER_INFO_WAUI_FOAF_UPGRADE ()
{
  if (exists (select 1 from SYS_COLS where \COLUMN = 'WAUI_FOAF' and \TABLE = 'DB.DBA.WA_USER_INFO' and COL_DTP = 125))
    return;
  wa_exec_no_error('alter TABLE DB.DBA.WA_USER_INFO DROP WAUI_FOAF');
  wa_exec_no_error('alter TABLE DB.DBA.WA_USER_INFO ADD WAUI_FOAF LONG VARCHAR');
};

WA_USER_INFO_WAUI_FOAF_UPGRADE ();

wa_add_col ('DB.DBA.WA_USER_INFO', 'WAUI_OPENID_URL', 'VARCHAR');
wa_add_col ('DB.DBA.WA_USER_INFO', 'WAUI_OPENID_SERVER', 'VARCHAR');

wa_add_col ('DB.DBA.WA_USER_INFO', 'WAUI_FACEBOOK_ID', 'INTEGER');
wa_add_col ('DB.DBA.WA_USER_INFO', 'WAUI_IS_ORG', 'INT default 0');
wa_add_col ('DB.DBA.WA_USER_INFO', 'WAUI_APP_ENABLE', 'INT default 0');
wa_add_col ('DB.DBA.WA_USER_INFO', 'WAUI_SPB_ENABLE', 'INT default 0');
wa_add_col ('DB.DBA.WA_USER_INFO', 'WAUI_NICK', 'varchar');

update DB.DBA.WA_USER_INFO set WAUI_IS_ORG = 0 where WAUI_IS_ORG is null;
alter table DB.DBA.WA_USER_INFO modify column WAUI_APP_ENABLE integer default 0;
update DB.DBA.WA_USER_INFO set WAUI_APP_ENABLE = 0 where WAUI_APP_ENABLE is null;

alter table DB.DBA.WA_USER_INFO modify column WAUI_SPB_ENABLE integer default 0;
update DB.DBA.WA_USER_INFO set WAUI_SPB_ENABLE = 0 where WAUI_SPB_ENABLE is null;

wa_exec_no_error('create index WA_USER_INFO_OID on DB.DBA.WA_USER_INFO (WAUI_OPENID_URL)');
wa_exec_no_error('create index WA_USER_INFO_NICK on DB.DBA.WA_USER_INFO (WAUI_NICK)');

create procedure WA_FACEBOOK_UPGRADE ()
{
  if (registry_get ('WA_FACEBOOK_UPGRADE') = 'done')
    return;

  wa_exec_no_error ('update DB.DBA.WA_USER_INFO set WAUI_FACEBOOK_ID = atoi (WAUI_FACEBOOK_LOGIN_ID) where coalesce (WAUI_FACEBOOK_ID, 0) = 0');

  registry_set ('WA_FACEBOOK_UPGRADE', 'done');
}
;
WA_FACEBOOK_UPGRADE ()
;

DB.DBA.EXEC_STMT (
'create table WA_USER_CERTS (
  UC_ID   	int identity,
  UC_U_ID 	int,
  UC_CERT 	long varchar,
  UC_FINGERPRINT varchar,
  UC_LOGIN	int default 0,
  UC_TS		datetime,
  primary key (UC_U_ID, UC_FINGERPRINT)
  )
create unique index WA_USER_CERTS_FINGERPRINT on WA_USER_CERTS (UC_FINGERPRINT)
', 
0);

wa_add_col ('DB.DBA.WA_USER_CERTS', 'UC_TS', 'datetime');
wa_exec_no_error_log ('ALTER TABLE DB.DBA.WA_USER_CERTS ADD FOREIGN KEY (UC_U_ID) REFERENCES DB.DBA.SYS_USERS (U_ID) ON DELETE CASCADE');

create procedure WA_CERTS_UPGRADE ()
{
  if (registry_get ('WA_CERTS_UPGRADE') = '1')
    return;
  
  for select WAUI_U_ID, WAUI_CERT, WAUI_CERT_FINGERPRINT, WAUI_CERT_LOGIN 
    from WA_USER_INFO where WAUI_CERT is not null do
      {
	if (WAUI_CERT_FINGERPRINT is null)
	  WAUI_CERT_FINGERPRINT := get_certificate_info (2, cast (WAUI_CERT as varchar), 0, '');
	if (WAUI_CERT_FINGERPRINT is not null and not exists (select 1 from WA_USER_CERTS where UC_FINGERPRINT = WAUI_CERT_FINGERPRINT))
	  {  
   insert soft WA_USER_CERTS (UC_U_ID, UC_CERT, UC_FINGERPRINT, UC_LOGIN) 
		values (WAUI_U_ID, WAUI_CERT, WAUI_CERT_FINGERPRINT, WAUI_CERT_LOGIN);
	  }
	else
	  {
	    log_message (sprintf ('Cannot upgrade certificate for user %d', WAUI_U_ID));
	  }
      }
   --update WA_USER_INFO set WAUI_CERT = null, WAUI_CERT_FINGERPRINT = null, WAUI_CERT_LOGIN = 0 
   --    where WAUI_CERT is not null;
  registry_set ('WA_CERTS_UPGRADE', '1');  
}
;

WA_CERTS_UPGRADE ();

create procedure ODS..cert_date_to_ts (in x varchar)
{
  declare a any;
  declare exit handler for sqlstate '*'
    {
      return null;
    };
  a := sprintf_inverse (x, '%s %s %s %s %s', 0);
  return http_string_date (sprintf ('Wdy, %s %s %s %s %s', a[1], a[0], a[3], a[2], a[4]));
}
;

create procedure WA_CERTS_UPGRADE ()
{
  if (registry_get ('WA_CERTS_UPGRADE2') = '1')
    return;
  update WA_USER_CERTS set UC_TS = ODS..cert_date_to_ts (get_certificate_info (4,UC_CERT));
  registry_set ('WA_CERTS_UPGRADE2', '1');
}
;

WA_CERTS_UPGRADE ();

create procedure WA_CERTS_UPGRADE ()
{
  if (registry_get ('WA_CERTS_UPGRADE3') = '1')
    return;

  delete
    from WA_USER_CERTS
   where UC_U_ID not in (select U_ID from SYS_USERS);

  registry_set ('WA_CERTS_UPGRADE3', '1');
}
;

WA_CERTS_UPGRADE ();

create procedure WA_MAKE_NICK (in nick varchar)
{
  declare i int;
  if (strstr (nick, '@') is not null)
    {
      declare tmp varchar;
      tmp := subseq (nick, 0, strchr (nick, '@'));
      if (length (tmp))
	nick := tmp;
      i := 0;
    }
  while (exists (select 1 from WA_USER_INFO where WAUI_NICK = nick))
    {
      nick := rtrim (nick, '1234567890');
      i := i + 1;
      nick := nick || cast (i as varchar);
    }
  return subseq (nick, 0, 20);
}
;

create procedure WA_MAKE_NICK2 (
  in nick varchar,
  in name varchar := '',
  in firstName varchar := '',
  in familyName varchar := '')
{
  if (not is_empty_or_null (nick))
    return nick;

  nick := replace (name, ' ', '');
  if (not is_empty_or_null (nick))
    return nick;

  nick := replace (firstName || familyName, ' ', '');

  return WA_MAKE_NICK (nick);
}
;

create trigger WA_USER_INFO_I after insert on WA_USER_INFO referencing new as N
{
  if (N.WAUI_JOIN_DATE is null)
  {
    set triggers off;
    update WA_USER_INFO set WAUI_JOIN_DATE = now() where WAUI_U_ID = N.WAUI_U_ID;
    set triggers on;
  }

  if (N.WAUI_NICK is null)
    {
      declare nick varchar;
      nick := null;
      if (length (N.WAUI_FIRST_NAME) and length (N.WAUI_LAST_NAME))
	nick := N.WAUI_FIRST_NAME||'.'||N.WAUI_LAST_NAME;
      if (exists (select 1 from WA_USER_INFO where WAUI_NICK = nick))
	nick := null;
      if (nick is null)
	{
	  nick := (select U_NAME from DB.DBA.SYS_USERS where U_ID = N.WAUI_U_ID);
	  nick := WA_MAKE_NICK (nick);
	}
      set triggers off;
      update WA_USER_INFO set WAUI_NICK = nick where WAUI_U_ID = N.WAUI_U_ID;
      set triggers on;
    }
  if (N.WAUI_CERT is not null)
  {
    set triggers off;
    update WA_USER_INFO
       set WAUI_CERT_FINGERPRINT = get_certificate_info (6, cast (N.WAUI_CERT as varchar))
     where WAUI_U_ID = N.WAUI_U_ID;
    set triggers on;
  }
  return;
}
;

create trigger WA_USER_INFO_U after update on WA_USER_INFO referencing old as O, new as N
{
  declare newf, oldf varchar;

  newf := oldf := '';
  if (length (N.WAUI_CERT))
  {
      newf := coalesce (get_certificate_info (6, cast (N.WAUI_CERT as varchar)), '');
    }
  if (length (O.WAUI_CERT_FINGERPRINT))
    oldf := O.WAUI_CERT_FINGERPRINT;

  if (newf <> oldf)
    {
      if (newf = '')
	newf := null;
    set triggers off;
      update WA_USER_INFO set WAUI_CERT_FINGERPRINT = newf where WAUI_U_ID = N.WAUI_U_ID;
    set triggers on;
  }
  return;
}
;

create procedure WA_USER_INFO_NICK_UPGRADE ()
{
  if (registry_get ('__WA_USER_INFO_NICK_UPGRADE') = 'done-1')
    return;
  for select U_ID, U_NAME, WAUI_FIRST_NAME as fn, WAUI_LAST_NAME as ln, WAUI_NICK as _WAUI_NICK
        from SYS_USERS, WA_USER_INFO
      where WAUI_U_ID = U_ID and (WAUI_NICK is null or WAUI_NICK like '%-nick-%') do
    {
      declare nick any;
      nick := null;
      if (length (_WAUI_NICK))
	{
	  nick := replace (_WAUI_NICK, '-nick-', '@');
	}
      else if (length(fn) and length (ln))
	{
          nick := fn||'.'||ln;
          if (exists (select 1 from WA_USER_INFO where WAUI_NICK = nick))
	    nick := null;
	}
      if (nick is null)
	nick := U_NAME;
      nick := WA_MAKE_NICK (nick);
      update WA_USER_INFO set WAUI_NICK = nick where WAUI_U_ID = U_ID;
    }
  registry_set ('__WA_USER_INFO_NICK_UPGRADE', 'done-1');
}
;

WA_USER_INFO_NICK_UPGRADE ();

wa_exec_no_error_log ('CREATE INDEX WA_GEO ON WA_USER_INFO (WAUI_LNG, WAUI_LAT, WAUI_LATLNG_VISIBLE)');
wa_exec_no_error_log ('CREATE INDEX WA_IS_ORG ON WA_USER_INFO (WAUI_IS_ORG, WAUI_U_ID)');

wa_exec_no_error_log(
  'CREATE TABLE WA_USER_TEXT
  (
    WAUT_U_ID int,
    WAUT_TEXT LONG VARCHAR,
    primary key (WAUT_U_ID)
  )'
)
;


wa_exec_no_error(
  'CREATE TEXT INDEX ON WA_USER_TEXT (WAUT_TEXT) WITH KEY WAUT_U_ID'
)
;

wa_exec_no_error_log(
  'CREATE TABLE WA_USER_TAG
  (
     WAUTG_U_ID	integer not null, -- the id of the user of whose tag it is
     WAUTG_TAG_ID	integer not null, -- the id of the user who gives the tags
     WAUTG_FT_ID	integer not null,
     WAUTG_TAGS	varchar not null,
     primary key (WAUTG_U_ID, WAUTG_TAG_ID)
  )'
)
;

wa_exec_no_error(
  'create unique index SYS_WA_USER_TAG_FT_ID on WA_USER_TAG (WAUTG_FT_ID)'
)
;

wa_exec_no_error(
  'create index WA_USER_TAG_TAG_ID on WA_USER_TAG (WAUTG_TAG_ID)'
)
;

wa_exec_no_error_log(
    'CREATE TABLE WA_USER_PROJECTS (
      WUP_ID int identity,
      WUP_U_ID int,
      WUP_NAME varchar,
      WUP_URL varchar,
      WUP_DESC long varchar,
      WUP_PUBLIC int default 0,
      WUP_IRI varchar,
      primary key (WUP_U_ID, WUP_ID)
      )'
)
;
wa_add_col ('DB.DBA.WA_USER_PROJECTS', 'WUP_IRI', 'varchar');

wa_exec_no_error_log(
    'CREATE TABLE WA_USER_OL_ACCOUNTS (
      WUO_ID int identity,
      WUO_U_ID integer,
      WUO_TYPE varchar,
      WUO_NAME varchar,
      WUO_URL varchar,
      WUO_URI varchar,
      WUO_PUBLIC integer default 0,
      WUO_OAUTH_SID varchar default null,
      primary key (WUO_U_ID, WUO_ID)
      )'
)
;

wa_add_col('DB.DBA.WA_USER_OL_ACCOUNTS', 'WUO_TYPE', 'varchar');
wa_add_col('DB.DBA.WA_USER_OL_ACCOUNTS', 'WUO_URI', 'varchar');
wa_add_col('DB.DBA.WA_USER_OL_ACCOUNTS', 'WUO_OAUTH_SID', 'varchar');

wa_exec_no_error_log('ALTER TABLE DB.DBA.WA_USER_OL_ACCOUNTS ADD FOREIGN KEY (WUO_U_ID) REFERENCES DB.DBA.SYS_USERS (U_ID) ON DELETE CASCADE');

--!
-- Creates old-style Facebook URIs.
--/
create procedure WA_USER_OL_ACCOUNTS_FACEBOOK (in ID integer)
{
  return sprintf ('http://www.facebook.com/profile.php?id=%s', cast (ID as varchar));
}
;

--!
-- Creates new-style Facebook URIs.
--/
create procedure WA_USER_OL_ACCOUNTS_FACEBOOK_URI (in username varchar)
{
  return sprintf ('http://www.facebook.com/%U', username);
}
;

create procedure WA_USER_OL_ACCOUNTS_TWITTER (in ID integer)
{
  return sprintf ('http://twitter.com/%U', cast (ID as varchar));
}
;

create procedure WA_USER_OL_ACCOUNTS_SET_UP ()
{
  if (registry_get ('__WA_USER_OL_ACCOUNTS_SET_UP') = 'done')
    return;
  registry_set ('__WA_USER_OL_ACCOUNTS_SET_UP', 'done');

  update WA_USER_OL_ACCOUNTS set WUO_TYPE = 'P' where WUO_TYPE is null;
}
;
WA_USER_OL_ACCOUNTS_SET_UP ();

create procedure WA_USER_OL_ACCOUNTS_URI (
  in url varchar)
{
  declare rc varchar;

  rc := null;
  if (__proc_exists ('DB.DBA.RDF_PROXY_ENTITY_IRI'))
    rc := DB.DBA.RDF_PROXY_ENTITY_IRI(url);
  if (isnull (rc))
    rc := url || '#this';

  return rc;
}
;

create procedure WA_USER_OL_ACCOUNTS_SET_UP ()
{
  if (registry_get ('__WA_USER_OL_ACCOUNTS_SET_UP2') = 'done')
    return;
  registry_set ('__WA_USER_OL_ACCOUNTS_SET_UP2', 'done');

  update WA_USER_OL_ACCOUNTS set WUO_URI = WA_USER_OL_ACCOUNTS_URI (WUO_URL) where WUO_URI is null;
}
;
WA_USER_OL_ACCOUNTS_SET_UP ();

create procedure WA_USER_OL_ACCOUNTS_SET_UP ()
{
  declare url varchar;

  if (registry_get ('__WA_USER_OL_ACCOUNTS_SET_UP3') = 'done')
    return;

  registry_set ('__WA_USER_OL_ACCOUNTS_SET_UP3', 'done');

  for (select WAUI_U_ID, WAUI_FACEBOOK_ID from DB.DBA.WA_USER_INFO where DB.DBA.is_empty_or_null (WAUI_FACEBOOK_ID) = 0) do
  {
    if (not exists (select 1 from DB.DBA.WA_USER_OL_ACCOUNTS where WUO_U_ID = WAUI_U_ID and WUO_TYPE = 'P' and lcase (WUO_NAME) = 'facebook'))
    {
      url := WA_USER_OL_ACCOUNTS_FACEBOOK_URI (WAUI_FACEBOOK_ID);
      insert into DB.DBA.WA_USER_OL_ACCOUNTS (WUO_U_ID, WUO_TYPE,  WUO_NAME, WUO_URL, WUO_URI)
        values (WAUI_U_ID, 'P', 'Facebook', url, ODS.ODS_API."user.onlineAccounts.uri" (url));
    }
  }
};
WA_USER_OL_ACCOUNTS_SET_UP ();

create procedure WA_USER_OL_ACCOUNTS_SET_UP ()
{
  declare url varchar;

  if (registry_get ('__WA_USER_OL_ACCOUNTS_SET_UP4') = 'done')
    return;

  update DB.DBA.WA_USER_OL_ACCOUNTS set WUO_PUBLIC = 1;
  for (select WAUI_U_ID as _id, WAUI_FOAF as _foaf from DB.DBA.WA_USER_INFO) do
  {
    delete from DB.DBA.WA_USER_OL_ACCOUNTS where WUO_U_ID = _id and WUO_TYPE = 'P' and WUO_NAME = 'webid';
    for (select _iri, _public from DB.DBA.WA_USER_INTERESTS (txt) (_iri varchar, _public varchar) P where txt = _foaf) do
    {
      if (not exists (select 1 from DB.DBA.WA_USER_OL_ACCOUNTS where WUO_URL = _iri))
      insert into DB.DBA.WA_USER_OL_ACCOUNTS (WUO_U_ID, WUO_TYPE, WUO_NAME, WUO_URL, WUO_URI, WUO_PUBLIC)
        values (_id, 'P', 'webid', _iri, _iri, _public);
    }
  }
  registry_set ('__WA_USER_OL_ACCOUNTS_SET_UP4', 'done');
};
WA_USER_OL_ACCOUNTS_SET_UP ();

create procedure WA_USER_OL_ACCOUNTS_UPGRADE ()
{
  if (exists (select 1 from SYS_KEYS where KEY_NAME = 'WA_USER_OL_ACCOUNTS_URL'))
    return;
  if (exists (select 1 from DB.DBA.WA_USER_OL_ACCOUNTS group by WUO_URL having count(*) > 1))
    {
      log_message ('Duplicate online account URL');
      return;
    }
  wa_exec_no_error_log ('create unique index WA_USER_OL_ACCOUNTS_URL on DB.DBA.WA_USER_OL_ACCOUNTS (WUO_URL)');
}
;

wa_exec_no_error_log(
    'CREATE TABLE WA_USER_RELATED_RES (
      WUR_ID int identity,
      WUR_U_ID int,
      WUR_LABEL varchar,
      WUR_PUBLIC int default 0,
      WUR_SEEALSO_IRI varchar,
      WUR_P_IRI varchar default \'http://www.w3.org/2000/01/rdf-schema#seeAlso\',
      primary key (WUR_U_ID, WUR_SEEALSO_IRI)
      )'
)
;
wa_add_col ('DB.DBA.WA_USER_RELATED_RES', 'WUR_P_IRI', 'varchar default \'http://www.w3.org/2000/01/rdf-schema#seeAlso\'');
wa_exec_no_error ('alter table DB.DBA.WA_USER_RELATED_RES modify primary key (WUR_U_ID, WUR_SEEALSO_IRI, WUR_P_IRI)');
wa_exec_no_error_log('create unique index WA_USER_RELATED_RES_IX1 on DB.DBA.WA_USER_RELATED_RES (WUR_ID)');


create procedure grUpdate_siocDate (in d any)
{
  declare str any;
  if (__tag (d) <> 211)
    d := now ();
  str := DB.DBA.date_iso8601 (dt_set_tz (d, 0));
  return substring (str, 1, 19) || 'Z';
};

create procedure grUpdate_detailProperty (
  inout product any,
  in productName varchar,
  inout properties any,
  in propertyOntologyName varchar,
  in propertyValue varchar,
  in propertyValueType varchar := 'object')
{
  if (not DB.DBA.is_empty_or_null (get_keyword (productName, product)))
    properties := vector_concat (properties, vector (vector_concat (subseq (soap_box_structure ('x', 1), 0, 2), vector ('name', propertyOntologyName, 'value', propertyValue, 'type', propertyValueType))));
}
;

create procedure grUpdate (in obj any)
{
  declare exit handler for sqlstate '*'{return vector ();};

  declare N integer;
  declare products, newProducts, newProduct, newProperties, newProperty any;

  N := 0;
  newProducts := vector ();
  obj := deserialize (obj);
  products := get_keyword ('products', obj);
  foreach (any product in products) do
  {
    N := N + 1;
    newProduct := vector_concat (subseq (soap_box_structure ('x', 1), 0, 2), vector ('id', cast (N as varchar), 'prefix', 'gr', 'class', 'gr:Offering'));

    newProperties := vector();
    -- step 2b
    grUpdate_detailProperty (product, 'sell', newProperties, 'gr:hasBusinessFunction', 'gr:Sell');
    grUpdate_detailProperty (product, 'repair', newProperties, 'gr:hasBusinessFunction', 'gr:Repair');
    grUpdate_detailProperty (product, 'maintain', newProperties, 'gr:hasBusinessFunction', 'gr:Maintain');
    grUpdate_detailProperty (product, 'lease', newProperties, 'gr:hasBusinessFunction', 'gr:LeaseOut');
    grUpdate_detailProperty (product, 'disposal', newProperties, 'gr:hasBusinessFunction', 'gr:Dispose');
    grUpdate_detailProperty (product, 'buy', newProperties, 'gr:hasBusinessFunction', 'gr:Buy');
    grUpdate_detailProperty (product, 'service', newProperties, 'gr:hasBusinessFunction', 'gr:ProvideService');

    -- step 3
    grUpdate_detailProperty (product, 'endUsers', newProperties, 'gr:eligibleCustomerTypes', 'gr:Enduser');
    grUpdate_detailProperty (product, 'public', newProperties, 'gr:eligibleCustomerTypes', 'gr:Public');
    grUpdate_detailProperty (product, 'reseller', newProperties, 'gr:eligibleCustomerTypes', 'gr:Reseller');

    grUpdate_detailProperty (obj, 'datetime1', newProperties, 'gr:validFrom', grUpdate_siocDate (get_keyword ('datetime1', obj)), 'data');
    grUpdate_detailProperty (obj, 'datetime2', newProperties, 'gr:validThrough', grUpdate_siocDate (get_keyword ('datetime2', obj)), 'data');

    -- step 4
    grUpdate_detailProperty (obj, 'mastercard', newProperties, 'gr:acceptedPaymentMethods', 'gr:MasterCard');
    grUpdate_detailProperty (obj, 'visa', newProperties, 'gr:acceptedPaymentMethods', 'gr:VISA');
    grUpdate_detailProperty (obj, 'amex', newProperties, 'gr:acceptedPaymentMethods', 'gr:AmericanExpress');
    grUpdate_detailProperty (obj, 'diners', newProperties, 'gr:acceptedPaymentMethods', 'gr:DinersClub');
    grUpdate_detailProperty (obj, 'discover', newProperties, 'gr:acceptedPaymentMethods', 'gr:Discover');
    grUpdate_detailProperty (obj, 'openinvoice', newProperties, 'gr:acceptedPaymentMethods', 'gr:ByInvoice');
    grUpdate_detailProperty (obj, 'cash', newProperties, 'gr:acceptedPaymentMethods', 'gr:Cash');
    grUpdate_detailProperty (obj, 'check', newProperties, 'gr:acceptedPaymentMethods', 'gr:CheckInAdvance');
    grUpdate_detailProperty (obj, 'bank', newProperties, 'gr:acceptedPaymentMethods', 'gr:ByBankTransferInAdvance');

     -- step 5
    grUpdate_detailProperty (obj, 'dhl', newProperties, 'gr:availableDeliveryMethods', 'gr:DHL');
    grUpdate_detailProperty (obj, 'ups', newProperties, 'gr:availableDeliveryMethods', 'gr:UPS');
    grUpdate_detailProperty (obj, 'mailDelivery', newProperties, 'gr:availableDeliveryMethods', 'gr:DeliveryModeMail');
    grUpdate_detailProperty (obj, 'fedex', newProperties, 'gr:availableDeliveryMethods', 'gr:FederalExpress');
    grUpdate_detailProperty (obj, 'download', newProperties, 'gr:availableDeliveryMethods', 'gr:DeliveryModeDirectDownload');

    if (length (newProperties))
      newProduct := vector_concat (newProduct, vector ('properties', newProperties));
    newProducts := vector_concat (newProducts, vector (newProduct));
  }
  return newProducts;
};

wa_exec_no_error_log(
    'CREATE TABLE WA_USER_OFFERLIST
     (
      WUOL_ID integer identity,
      WUOL_U_ID integer,
      WUOL_TYPE char(1) default \'1\',
      WUOL_FLAG char(1) default \'1\',
      WUOL_OFFER varchar,
      WUOL_COMMENT long varchar,
      WUOL_PROPERTIES long varchar,

      primary key (WUOL_ID)
     )'
);
wa_add_col('DB.DBA.WA_USER_OFFERLIST', 'WUOL_FLAG', 'char(1) default \'1\'');
wa_add_col('DB.DBA.WA_USER_OFFERLIST', 'WUOL_TYPE', 'char(1) default \'1\'');
wa_exec_no_error('drop index WA_USER_OFFERLIST_USER');
wa_exec_no_error('create unique index WA_USER_OFFERLIST_USER on WA_USER_OFFERLIST (WUOL_U_ID, WUOL_TYPE, WUOL_OFFER)');

alter table DB.DBA.WA_USER_OFFERLIST modify column WUOL_FLAG char(1) default '1';
alter table DB.DBA.WA_USER_OFFERLIST modify column WUOL_TYPE char(1) default '1';
update DB.DBA.WA_USER_OFFERLIST set WUOL_FLAG = '1' where WUOL_FLAG is null;
update DB.DBA.WA_USER_OFFERLIST set WUOL_TYPE = '1' where WUOL_TYPE is null;

wa_exec_no_error('DROP TRIGGER DB.DBA.WA_USER_WISHLIST_SIOC_I');
wa_exec_no_error('DROP TRIGGER DB.DBA.WA_USER_WISHLIST_SIOC_U');
wa_exec_no_error('DROP TRIGGER DB.DBA.WA_USER_WISHLIST_SIOC_D');


create procedure wa_offerlist_upgrade()
{
  declare id integer;
  declare obj any;

  if (registry_get ('__wa_offerlist_upgrade') = 'done')
    return;
  registry_set ('__wa_offerlist_upgrade', 'done');

  for (select WUOL_ID, WUOL_PROPERTIES from DB.DBA.WA_USER_OFFERLIST) do
  {
    id := WUOL_ID;
    obj := grUpdate (WUOL_PROPERTIES);
    obj := vector_concat (subseq (soap_box_structure ('x', 1), 0, 2), vector ('version', '1.0', 'products', obj));
    update DB.DBA.WA_USER_OFFERLIST set WUOL_PROPERTIES = serialize (obj) where WUOL_ID = id;
  }
}
;
wa_offerlist_upgrade();

create procedure wa_offerlist_upgrade()
{
  if (registry_get ('__wa_offerlist_upgrade2') = 'done')
    return;
  registry_set ('__wa_offerlist_upgrade2', 'done');

  wa_exec_no_error('insert into DB.DBA.WA_USER_OFFERLIST (WUOL_U_ID, WUOL_TYPE, WUOL_FLAG, WUOL_OFFER, WUOL_COMMENT, WUOL_PROPERTIES) select WUWL_U_ID, \'2\', WUWL_FLAG, WUWL_BARTER, WUWL_COMMENT, WUWL_PROPERTIES from DB.DBA.WA_USER_WISHLIST');
}
;
wa_offerlist_upgrade();

wa_exec_no_error_log(
    'CREATE TABLE WA_USER_LIKES (
      WUL_ID integer identity,
      WUL_U_ID integer,
      WUL_FLAG char(1),
      WUL_TYPE varchar,
      WUL_URI varchar,
      WUL_NAME varchar,
      WUL_COMMENT long varchar,
      WUL_PROPERTIES long varchar,

      primary key (WUL_ID)
     )'
);
wa_add_col ('DB.DBA.WA_USER_LIKES', 'WUL_FLAG', 'char(1)');
wa_exec_no_error('create unique index WA_USER_LIKES_USER on WA_USER_LIKES (WUL_U_ID, WUL_NAME)');

wa_exec_no_error_log(
    'CREATE TABLE WA_USER_KNOWS (
      WUK_ID int identity,
      WUK_U_ID integer NOT NULL,
      WUK_FLAG char(1) default \'1\',
      WUK_LABEL varchar,
      WUK_URI varchar NOT NULL,
      primary key (WUK_ID)
     )'
)
;
wa_exec_no_error_log ('create unique index WA_USER_KNOWS_USER on DB.DBA.WA_USER_KNOWS (WUK_U_ID, WUK_URI)');


wa_exec_no_error_log(
    'CREATE TABLE WA_USER_BIOEVENTS (
      WUB_ID integer identity,
      WUB_U_ID integer,
      WUB_EVENT varchar,
      WUB_DATE varchar,
      WUB_PLACE varchar,

      primary key (WUB_ID)
     )'
);
wa_exec_no_error('create index WA_USER_BIOEVENTS_USER on WA_USER_BIOEVENTS (WUB_U_ID)');

wa_exec_no_error_log(
    'CREATE TABLE WA_USER_FAVORITES (
      WUF_ID integer identity,
      WUF_U_ID integer,
      WUF_FLAG char(1),
      WUF_TYPE varchar,
      WUF_CLASS varchar,
      WUF_PROPERTIES long varchar,
      WUF_LABEL varchar,
      WUF_URI varchar,

      primary key (WUF_ID)
     )'
);
wa_add_col ('DB.DBA.WA_USER_FAVORITES', 'WUF_TYPE', 'varchar');
wa_add_col ('DB.DBA.WA_USER_FAVORITES', 'WUF_CLASS', 'varchar');
wa_add_col ('DB.DBA.WA_USER_FAVORITES', 'WUF_PROPERTIES', 'long varchar');
wa_add_col ('DB.DBA.WA_USER_FAVORITES', 'WUF_FLAG', 'char(1)');
wa_exec_no_error('create index WA_USER_FAVORITES_USER on WA_USER_FAVORITES (WUF_U_ID)');

create procedure wa_favorites_upgrade()
{
  if (registry_get ('__wa_favorites_upgrade') = 'done')
    return;
  registry_set ('__wa_favorites_upgrade', 'done');
  for (select WAUI_U_ID, WAUI_FAVORITE_BOOKS, WAUI_FAVORITE_MUSIC, WAUI_FAVORITE_MOVIES from DB.DBA.WA_USER_INFO) do
  {
    if (not DB.DBA.is_empty_or_null (WAUI_FAVORITE_BOOKS))
      insert into DB.DBA.WA_USER_FAVORITES ( WUF_LABEL, WUF_U_ID) values (WAUI_FAVORITE_BOOKS, WAUI_U_ID);
    if (not DB.DBA.is_empty_or_null (WAUI_FAVORITE_MUSIC))
      insert into DB.DBA.WA_USER_FAVORITES ( WUF_LABEL, WUF_U_ID) values (WAUI_FAVORITE_MUSIC, WAUI_U_ID);
    if (not DB.DBA.is_empty_or_null (WAUI_FAVORITE_MOVIES))
      insert into DB.DBA.WA_USER_FAVORITES ( WUF_LABEL, WUF_U_ID) values (WAUI_FAVORITE_MOVIES, WAUI_U_ID);
  }
}
;
wa_favorites_upgrade();

create procedure wa_favorites_upgrade2()
{
  declare _class, _properties, _property any;

  if (registry_get ('__wa_favorites_upgrade2') = 'done')
    return;

  for (select WUF_ID _id, WUF_TYPE _type, WUF_LABEL _label, WUF_URI _uri from DB.DBA.WA_USER_FAVORITES) do
  {
    if (_type = 'text/*')
    {
      _type := 'http://purl.org/NET/book/vocab#';
      _class := 'book:Book';
    }
    else if (_type = 'audio/*')
    {
      _type := 'http://purl.org/ontology/mo/';
      _class := 'mo:Record';
    }
    else
    {
      _type := 'http://rdfs.org/sioc/ns#';
      _class := 'sioc:Item';
    }
    _properties := vector ();
    if (not is_empty_or_null (_label))
    {
      _property := vector_concat (subseq (soap_box_structure ('x', 1), 0, 2), vector ('name', 'dc:title', 'value', _label, 'type', 'data'));
      _properties := vector_concat (_properties, vector (_property));
    }
    if (not is_empty_or_null (_uri))
    {
      _property := vector_concat (subseq (soap_box_structure ('x', 1), 0, 2), vector ('name', 'rdfs:seeAlso', 'value', _uri, 'type', 'data'));
      _properties := vector_concat (_properties, vector (_property));
    }
    update DB.DBA.WA_USER_FAVORITES
       set WUF_TYPE = _type,
           WUF_CLASS = _class,
           WUF_PROPERTIES = serialize (_properties)
     where WUF_ID = _id;
  }
  registry_set ('__wa_favorites_upgrade2', 'done');
}
;
wa_favorites_upgrade2();

create procedure wa_favorites_upgrade3()
{
  if (registry_get ('__wa_favorites_upgrade3') = 'done')
    return;
  registry_set ('__wa_favorites_upgrade3', 'done');

  delete
    from DB.DBA.WA_USER_FAVORITES
   where WUF_TYPE <> 'http://rdfs.org/sioc/ns#'
     and WUF_CLASS <> 'sioc:Item';
}
;
wa_favorites_upgrade3();

create procedure WA_USER_TAG_WAUTG_TAGS_INDEX_HOOK (inout vtb any, inout d_id integer)
{
  for select WAUTG_U_ID, WAUTG_TAG_ID, WAUTG_TAGS from WA_USER_TAG where WAUTG_FT_ID = d_id do
    {
      vt_batch_feed (vtb, WS.WS.DAV_TAG_NORMALIZE (WAUTG_TAGS), 0, 0, 'x-ViDoc');
      vt_batch_feed (vtb, sprintf ('^TID%d', WAUTG_TAG_ID), 0, 0, 'x-ViDoc');
      vt_batch_feed (vtb, sprintf ('^UID%d', WAUTG_U_ID), 0, 0, 'x-ViDoc');
      if (WAUTG_U_ID = http_nobody_uid ())
        vt_batch_feed (vtb, '^PUBLIC', 0, 0, 'x-ViDoc');
      vt_batch_feed_offband (vtb, serialize (vector (WAUTG_TAG_ID, WAUTG_U_ID)), 0);
      return 1;
    }
  return 1;
}
;

create procedure WA_USER_TAG_WAUTG_TAGS_UNINDEX_HOOK (inout vtb any, inout d_id integer)
{
  for select WAUTG_U_ID, WAUTG_TAG_ID, WAUTG_TAGS from WA_USER_TAG where WAUTG_FT_ID = d_id do
    {
      vt_batch_feed (vtb, WS.WS.DAV_TAG_NORMALIZE (WAUTG_TAGS), 1, 0, 'x-ViDoc');
      vt_batch_feed (vtb, sprintf ('^TID%d', WAUTG_TAG_ID), 1, 0, 'x-ViDoc');
      vt_batch_feed (vtb, sprintf ('^UID%d', WAUTG_U_ID), 1, 0, 'x-ViDoc');
      if (WAUTG_U_ID = http_nobody_uid ())
        vt_batch_feed (vtb, '^PUBLIC', 1, 0, 'x-ViDoc');
      vt_batch_feed_offband (vtb, serialize (vector (WAUTG_TAG_ID, WAUTG_U_ID)), 1);
      return 1;
    }
  return 1;
}
;

create procedure  WA_USER_TAG_FT_UPGRADE ()
{
  if (registry_get ('__WA_USER_TAG_FT_UPGRADE') = 'done')
    return;

  wa_exec_no_error_log ('drop table DB.DBA.WA_USER_TAG_WAUTG_TAGS_WORDS');
  wa_exec_no_error_log ('drop table DB.DBA.VTLOG_DB_DBA_WA_USER_TAG');
  DB.DBA.vt_create_text_index ('WA_USER_TAG', 'WAUTG_TAGS', 'WAUTG_FT_ID', 2, 0, vector ('WAUTG_TAG_ID', 'WAUTG_U_ID'), 1, 'x-ViDoc', 'UTF-8');

  registry_set ('__WA_USER_TAG_FT_UPGRADE', 'done');
}
;

WA_USER_TAG_FT_UPGRADE ()
;


create procedure WA_USER_SET_INFO (in _name varchar,in _fname varchar,in _lname varchar)
{
  declare _uid any;
  declare i int;
  declare _visb, _uname varchar;
  whenever not found goto nf;
  SELECT U_ID, U_NAME INTO _uid, _uname FROM SYS_USERS WHERE U_NAME = _name;

  _visb := '1';
  for (i := 1; i < 55; i := i + 1)
  {
    _visb := concat(_visb,'1');
  }

  INSERT REPLACING WA_USER_INFO (WAUI_U_ID,WAUI_VISIBLE,WAUI_FIRST_NAME, WAUI_LAST_NAME, WAUI_FULL_NAME )
    VALUES(_uid, _visb, _fname, _lname, _uname  );

  return;

 nf:
   signal ('42000', sprintf ('The object "%s" does not exists.', _name), 'U0002');
}
;

create procedure WA_USER_EDIT (in _name varchar, in _key varchar, in _data any)
{
  declare _uid any;
  declare i int;
  declare _visb varchar;
  whenever not found goto nf;
  SELECT U_ID INTO _uid FROM SYS_USERS WHERE U_NAME = _name;

  if (_key = 'SEC_QUESTION')
    UPDATE WA_USER_INFO SET WAUI_SEC_QUESTION = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'SEC_ANSWER')
    UPDATE WA_USER_INFO SET WAUI_SEC_ANSWER = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_ICQ')
    UPDATE WA_USER_INFO SET WAUI_ICQ = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_SKYPE')
    UPDATE WA_USER_INFO SET WAUI_SKYPE = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_AIM')
    UPDATE WA_USER_INFO SET WAUI_AIM = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_YAHOO')
    UPDATE WA_USER_INFO SET WAUI_YAHOO = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_MSN')
    UPDATE WA_USER_INFO SET WAUI_MSN = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_MESSAGING')
    UPDATE WA_USER_INFO SET WAUI_MESSAGING = _data WHERE WAUI_U_ID = _uid;

  else if (_key = 'WAUI_BICQ')
    UPDATE WA_USER_INFO SET WAUI_BICQ = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_BSKYPE')
    UPDATE WA_USER_INFO SET WAUI_BSKYPE = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_BAIM')
    UPDATE WA_USER_INFO SET WAUI_BAIM = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_BYAHOO')
    UPDATE WA_USER_INFO SET WAUI_BYAHOO = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_BMSN')
    UPDATE WA_USER_INFO SET WAUI_BMSN = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_BMESSAGING')
    UPDATE WA_USER_INFO SET WAUI_BMESSAGING = _data WHERE WAUI_U_ID = _uid;

  else if (_key = 'WAUI_BIRTHDAY' and (__tag (_data) = 211 or _data is null))
    UPDATE WA_USER_INFO SET WAUI_BIRTHDAY = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_NICK')
    UPDATE WA_USER_INFO SET WAUI_NICK = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_TITLE')
    UPDATE WA_USER_INFO SET WAUI_TITLE = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_FIRST_NAME')
    UPDATE WA_USER_INFO SET WAUI_FIRST_NAME = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_LAST_NAME')
    UPDATE WA_USER_INFO SET WAUI_LAST_NAME = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_FULL_NAME')
    {
      UPDATE WA_USER_INFO SET WAUI_FULL_NAME = _data WHERE WAUI_U_ID = _uid;
      UPDATE SYS_USERS set U_FULL_NAME = _data where U_ID = _uid;
    }
  else if (_key = 'WAUI_GENDER')
    UPDATE WA_USER_INFO SET WAUI_GENDER = _data WHERE WAUI_U_ID = _uid;
  --else if (_key = 'WAUI_FOAF')
  --  UPDATE WA_USER_INFO SET WAUI_FOAF = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_MSIGNATURE')
    UPDATE WA_USER_INFO SET WAUI_MSIGNATURE = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_SUMMARY')
    UPDATE WA_USER_INFO SET WAUI_SUMMARY = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_WEBPAGE')
    UPDATE WA_USER_INFO SET WAUI_WEBPAGE = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'E_MAIL')
    UPDATE DB.DBA.SYS_USERS SET U_E_MAIL = _data WHERE U_ID = _uid;
  else if (_key = 'WAUI_INTERESTS')
    UPDATE WA_USER_INFO SET WAUI_INTERESTS = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_INTEREST_TOPICS')
    UPDATE WA_USER_INFO SET WAUI_INTEREST_TOPICS = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_BORG_HOMEPAGE')
    UPDATE WA_USER_INFO SET WAUI_BORG_HOMEPAGE = _data WHERE WAUI_U_ID = _uid;
--home tab
  else if (_key = 'WAUI_HADDRESS1')
    UPDATE WA_USER_INFO SET WAUI_HADDRESS1 = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_HADDRESS2')
    UPDATE WA_USER_INFO SET WAUI_HADDRESS2 = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_HCODE')
    UPDATE WA_USER_INFO SET WAUI_HCODE = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_HCITY')
    UPDATE WA_USER_INFO SET WAUI_HCITY = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_HSTATE')
    UPDATE WA_USER_INFO SET WAUI_HSTATE = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_HCOUNTRY')
    UPDATE WA_USER_INFO SET WAUI_HCOUNTRY = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_HTZONE')
    UPDATE WA_USER_INFO SET WAUI_HTZONE = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_HPHONE')
    UPDATE WA_USER_INFO SET WAUI_HPHONE = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_HPHONE_EXT')
    UPDATE WA_USER_INFO SET WAUI_HPHONE_EXT = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_HMOBILE')
    UPDATE WA_USER_INFO SET WAUI_HMOBILE = _data WHERE WAUI_U_ID = _uid;

  else if (_key = 'WAUI_BADDRESS1')
    UPDATE WA_USER_INFO SET WAUI_BADDRESS1 = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_BADDRESS2')
    UPDATE WA_USER_INFO SET WAUI_BADDRESS2 = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_BCODE')
    UPDATE WA_USER_INFO SET WAUI_BCODE = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_BCITY')
    UPDATE WA_USER_INFO SET WAUI_BCITY = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_BSTATE')
   UPDATE WA_USER_INFO SET WAUI_BSTATE = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_BCOUNTRY')
    UPDATE WA_USER_INFO SET WAUI_BCOUNTRY = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_BTZONE')
    UPDATE WA_USER_INFO SET WAUI_BTZONE = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_BLAT')
    UPDATE WA_USER_INFO SET WAUI_BLAT = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_BLNG')
    UPDATE WA_USER_INFO SET WAUI_BLNG = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_BPHONE')
    UPDATE WA_USER_INFO SET WAUI_BPHONE = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_BPHONE_EXT')
    UPDATE WA_USER_INFO SET WAUI_BPHONE_EXT = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_BMOBILE')
    UPDATE WA_USER_INFO SET WAUI_BMOBILE = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_BREGNO')
    UPDATE WA_USER_INFO SET WAUI_BREGNO = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_BCAREER')
    UPDATE WA_USER_INFO SET WAUI_BCAREER = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_BEMPTOTAL')
    UPDATE WA_USER_INFO SET WAUI_BEMPTOTAL = _data WHERE WAUI_U_ID = _uid;

  else if (_key = 'WAUI_BVENDOR')
    UPDATE WA_USER_INFO SET WAUI_BVENDOR = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_BSERVICE')
    UPDATE WA_USER_INFO SET WAUI_BSERVICE = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_BOTHER')
    UPDATE WA_USER_INFO SET WAUI_BOTHER = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_BNETWORK')
    UPDATE WA_USER_INFO SET WAUI_BNETWORK = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_RESUME')
    UPDATE WA_USER_INFO SET WAUI_RESUME = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_BJOB')
    UPDATE WA_USER_INFO SET WAUI_BJOB = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_BORG')
    UPDATE WA_USER_INFO SET WAUI_BORG = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_BINDUSTRY')
    UPDATE WA_USER_INFO SET WAUI_BINDUSTRY = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_PHOTO_URL')
    UPDATE WA_USER_INFO SET WAUI_PHOTO_URL = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_LAT')
    UPDATE WA_USER_INFO SET WAUI_LAT = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_LNG')
    UPDATE WA_USER_INFO SET WAUI_LNG = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_LATLNG_HBDEF')
    UPDATE WA_USER_INFO SET WAUI_LATLNG_HBDEF = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_AUDIO_CLIP')
    UPDATE WA_USER_INFO SET WAUI_AUDIO_CLIP = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_FAVORITE_BOOKS')
    UPDATE WA_USER_INFO SET WAUI_FAVORITE_BOOKS = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_FAVORITE_MUSIC')
    UPDATE WA_USER_INFO SET WAUI_FAVORITE_MUSIC = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_FAVORITE_MOVIES')
    UPDATE WA_USER_INFO SET WAUI_FAVORITE_MOVIES = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_SEARCHABLE')
    UPDATE WA_USER_INFO SET WAUI_SEARCHABLE = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_SHOWACTIVE')
    UPDATE WA_USER_INFO SET WAUI_SHOWACTIVE = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_OPENID_URL')
    UPDATE WA_USER_INFO SET WAUI_OPENID_URL = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_OPENID_SERVER')
    UPDATE WA_USER_INFO SET WAUI_OPENID_SERVER = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_APP_ENABLE')
    UPDATE WA_USER_INFO SET WAUI_APP_ENABLE = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_SPB_ENABLE')
    UPDATE WA_USER_INFO SET WAUI_SPB_ENABLE = _data WHERE WAUI_U_ID = _uid;

  else if (_key = 'WAUI_ACL')
    UPDATE WA_USER_INFO SET WAUI_ACL = _data WHERE WAUI_U_ID = _uid;

  else if (_key = 'WAUI_SETTINGS')
    UPDATE WA_USER_INFO SET WAUI_SETTINGS = _data WHERE WAUI_U_ID = _uid;

  return row_count ();

 nf:
   signal ('42000', sprintf ('The object "%s" does not exists.', _name), 'U0002');
}
;


create procedure WA_USER_VISIBILITY (in _name varchar, in _arr any default null, in _mode int default 1)
{
  declare _uid any;
  declare _visb, new_vis any;
  declare i, j integer;
  whenever not found goto nf;

  _visb := '';
  SELECT U_ID INTO _uid FROM SYS_USERS WHERE U_NAME = _name;

  SELECT WAUI_VISIBLE into _visb FROM WA_USER_INFO WHERE WAUI_U_ID = _uid;

  --dbg_obj_print(_uid);
  _visb := replace(_visb,'1','1,');
  _visb := replace(_visb,'2','2,');
  _visb := replace(_visb,'3','3,');
  _visb := trim(_visb, ',');
  _visb:= split_and_decode (_visb,0,'\0\0,');

  if (length (_visb) < 70)
    {
      declare part, inx any;
    part := make_array (70-length (_visb), 'any');
      for (inx := 0; inx < length (part); inx := inx + 1)
        part [inx] := '3';
      _visb := vector_concat (_visb, part);
    }

  if (_mode = 1)
      return _visb;

  if (length(_arr) < 2)
    return;

  for (i := 0; i < length(_visb); i := i + 1)
    {
      declare val any;
      val := get_keyword (sprintf ('%d', i), _arr);
      if (val is not null)
	_visb[i] := val;
    }

  --dbg_obj_print(_visb);
  declare _new varchar;

  _new := '';
  for (j := 0; j < length(_visb); j := j + 1)
    _new := concat (_new, _visb[j]);

  UPDATE WA_USER_INFO SET WAUI_VISIBLE = _new WHERE WAUI_U_ID = _uid;
  return;

 nf:
   signal ('42000', sprintf ('The object "%s" does not exists.', _name), 'U0002');
}
;

create procedure WA_USER_SETTING_SET (in _name varchar, in _key varchar, in _data any)
{
  declare _uid any;
  declare _settings any;

  _uid := (select U_ID from DB.DBA.SYS_USERS where U_NAME = _name);
  _settings := (select deserialize (WAUI_SETTINGS) from DB.DBA.WA_USER_INFO where WAUI_U_ID = _uid);
  if (isnull (_settings))
    _settings := vector ();

  if (isstring (_settings))
    _settings := vector ();

  ODS.ODS_API.set_keyword (_key, _settings, _data);
  WA_USER_EDIT (_name, 'WAUI_SETTINGS', serialize (_settings));
}
;

create procedure WA_USER_SETTING_GET (in _name varchar, in _key varchar)
{
  declare _uid any;
  declare _settings any;

  _uid := (select U_ID from DB.DBA.SYS_USERS where U_NAME = _name);
  _settings := (select deserialize (WAUI_SETTINGS) from DB.DBA.WA_USER_INFO where WAUI_U_ID = _uid);
  if (isnull(_settings))
    return null;

  if (isstring (_settings))
    return null;

  return get_keyword (_key, _settings);
}
;

create procedure WA_REPLACE_ARR ( inout _vector any, in _pos integer,in _val varchar )
{
  declare _ind integer;

  _ind := 0;
  while(_ind < length(_vector))
    {
      if (_ind = _pos)
	aset(_vector,_ind,_val);
	_ind := _ind + 1;
    };
  return;
}
;

create procedure WA_STR_PARAM (inout pArray any,in pName varchar,in pMode integer default 0)
{
    declare i, l, incr integer;
    declare aArrayNew any;

    aArrayNew := vector();
    i := 0;
    l := length(pArray);

    incr := 2;
    if (l >= 4 and mod (l, 4) = 0)
      {
	if (pArray[2] = 'attr-'||pArray[0])
	  incr := 4;
      }

    while (i < l)
      {
	if (locate (pName, pArray[i]) > 0)
	  {
	    if (not (pMode))
	      aArrayNew := vector_concat(aArrayNew, vector_concat(vector(trim(pArray[i],pName)),vector(pArray[i+1])));
	    else
	      aArrayNew := vector_concat(aArrayNew, vector_concat(vector(trim(pArray[i+1],pName))));
	  };
        i := i + incr;
      };
  return  aArrayNew;
}
;

create procedure WA_OPTION_SUBS (in opt varchar, inout opts any, in len int := 0)
{
  declare val any;
  val := get_keyword_ucase (upper (opt), opts, NULL);
  if (isstring (val) and len)
    return substring (val, 1, len);
  return val;
};


create procedure WA_USER_SEARCH_SET_UP ()
{
  if (registry_get ('__WA_USER_SEARCH_SET_UP') = 'done')
    return;
  update WA_USER_INFO set WAUI_SEARCHABLE = 1 where WAUI_SEARCHABLE is null;
  registry_set ('__WA_USER_SEARCH_SET_UP', 'done');
};

WA_USER_SEARCH_SET_UP ();

create procedure WA_USER_INFO_CHECK ()
{
   declare _uid, _id, _sql int;
   declare _uname, _wkey varchar;
   declare _wdata, opts any;
   declare _bdate any; /* datetime */

  if (registry_get ('__WA_USER_INFO_CHECK') = 'done2')
     return;

   for select U_ID, U_NAME, U_FULL_NAME from SYS_USERS where U_DAV_ENABLE = 1 and U_IS_ROLE = 0 and U_NAME <> 'nobody' do
   {
      _uid := U_ID;
      _uname := U_NAME;

      if (not exists (select 1 from WA_USER_INFO where WAUI_U_ID = _uid))
      {
	 GET_SEC_OBJECT_ID (_uname, _id, _sql, opts);

         WA_USER_SET_INFO (_uname, '', '');

	 declare dummy int;
	 declare cr cursor for select 1 from WA_USER_INFO where WAUI_U_ID = _uid;

	 open cr (exclusive, prefetch 1);
	 fetch cr into dummy;

         _bdate := WA_OPTION_SUBS ('BIRTHDAY', opts);
         if (_bdate is not null and _bdate <> 0)
           UPDATE WA_USER_INFO SET WAUI_BIRTHDAY =  _bdate WHERE current of cr;

         UPDATE WA_USER_INFO SET WAUI_TITLE =  WA_OPTION_SUBS( 'TITLE', opts, 3) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_FIRST_NAME =  WA_OPTION_SUBS( 'FIRST_NAME', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_LAST_NAME =  WA_OPTION_SUBS( 'LAST_NAME', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_FULL_NAME = substring (coalesce (U_FULL_NAME, _uname), 1, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_GENDER =  WA_OPTION_SUBS( 'GENDER', opts, 10) WHERE current of cr;


         UPDATE WA_USER_INFO SET WAUI_WEBPAGE =  WA_OPTION_SUBS( 'URL', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_ICQ =  WA_OPTION_SUBS( 'ICQ', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_SKYPE =  WA_OPTION_SUBS( 'SKYPE', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_AIM =  WA_OPTION_SUBS( 'AIM', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_YAHOO =  WA_OPTION_SUBS( 'YAHOO', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_MSN =  WA_OPTION_SUBS( 'MSN', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_HADDRESS1 =  WA_OPTION_SUBS( 'ADDR1', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_HADDRESS2 =  WA_OPTION_SUBS( 'ADDR2', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_HCODE =  WA_OPTION_SUBS( 'ZIP', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_HCITY =  WA_OPTION_SUBS( 'CITY', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_HSTATE =  WA_OPTION_SUBS( 'STATE', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_HCOUNTRY =  WA_OPTION_SUBS( 'COUNTRY', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_HTZONE =  WA_OPTION_SUBS( 'TIMEZONE', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_HPHONE =  WA_OPTION_SUBS( 'PHONE', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_HMOBILE =  WA_OPTION_SUBS( 'MPHONE', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_BINDUSTRY =  WA_OPTION_SUBS( 'INDUSTRY', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_BORG =  WA_OPTION_SUBS( 'ORGANIZATION', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_BJOB =  WA_OPTION_SUBS( 'JOB', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_BADDRESS1 =  WA_OPTION_SUBS( 'BADDR1', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_BADDRESS2 =  WA_OPTION_SUBS( 'BADDR2', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_BCODE =  WA_OPTION_SUBS( 'BZIP', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_BCITY =  WA_OPTION_SUBS( 'BCITY', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_BSTATE =  WA_OPTION_SUBS( 'BSTATE', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_BCOUNTRY =  WA_OPTION_SUBS( 'BCOUNTRY', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_BTZONE =  WA_OPTION_SUBS( 'BTIMEZONE', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_BPHONE =  WA_OPTION_SUBS( 'BPHONE', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_BMOBILE =  WA_OPTION_SUBS( 'BMPHONE', opts, 50) WHERE current of cr;

         UPDATE WA_USER_INFO SET WAUI_SEC_QUESTION =  WA_OPTION_SUBS( 'SEC_QUESTION', opts, 20) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_SEC_ANSWER =  WA_OPTION_SUBS( 'SEC_ANSWER', opts, 20) WHERE current of cr;

         if (exists (select 1 from WA_USER_SETTINGS where WAUS_U_ID = _uid))
         {
        for (select WAUS_KEY, WAUS_DATA from WA_USER_SETTINGS) do
        {
              _wkey := WAUS_KEY;
              _wdata :=  deserialize(WAUS_DATA);
             if (_wkey = 'CAREER_STATUS')
                UPDATE WA_USER_INFO SET WAUI_BCAREER = substring (_wdata, 1, 50) WHERE current of cr;
             else if (_wkey = 'EXT_FOAF_URL')
                UPDATE WA_USER_INFO SET WAUI_FOAF = substring (_wdata, 1, 50) WHERE current of cr;
             else if (_wkey = 'IS_VENDOR')
                UPDATE WA_USER_INFO SET WAUI_BVENDOR = substring (_wdata, 1, 50) WHERE current of cr;
             else if (_wkey = 'MAIL-SIGNATURE')
                UPDATE WA_USER_INFO SET WAUI_MSIGNATURE = substring (_wdata, 1, 255) WHERE current of cr;
             else if (_wkey = 'NO_EMPLOYEES')
                UPDATE WA_USER_INFO SET WAUI_BEMPTOTAL = substring (_wdata, 1, 50) WHERE current of cr;
             else if (_wkey = 'OPLNET_IMPORTANCE')
                UPDATE WA_USER_INFO SET WAUI_BNETWORK = substring (_wdata, 1, 50) WHERE current of cr;
             else if (_wkey = 'OTHER_TECH_SERVICE')
                UPDATE WA_USER_INFO SET WAUI_BOTHER = substring (_wdata, 1, 50) WHERE current of cr;
             else if (_wkey = 'TECH_SERVICE')
                UPDATE WA_USER_INFO SET WAUI_BSERVICE = substring (_wdata, 1, 50) WHERE current of cr;
             else if (_wkey = 'VAT_REG_NUMBER')
                UPDATE WA_USER_INFO SET WAUI_BREGNO = substring (_wdata, 1, 50) WHERE current of cr;
        }
      }
	 close cr;
      }
  }
  registry_set ('__WA_USER_INFO_CHECK', 'done2');
}
;

create procedure WA_GET_FTID ()
{
  declare id, nid integer;
  declare t_cur cursor for select WAUTG_FT_ID from WA_USER_TAG order by WAUTG_FT_ID desc;

  set isolation = 'serializable';

again:

  id := 1;
  whenever not found goto not_found;
  open t_cur (exclusive, prefetch 1);
  fetch t_cur into id;
  if (not isnull(id))
    id := id + 1;

not_found:
  if (isnull(id))
    id := 1;

whenever not found goto return_id;
  close t_cur;
  --select DT_FT_ID into nid from WS.WS.SYS_DAV_TAG where DT_FT_ID = id;
  select WAUTG_FT_ID into nid from WA_USER_TAG where WAUTG_FT_ID = id;
  goto again;

return_id:
  return id;
}
;

create procedure WA_USER_INTERESTS (in txt any)
{
  declare arr any;
  declare interest, label any;

  result_names (interest, label);

  if (not length (txt))
    return;
  txt := blob_to_string (txt);
  txt := replace(txt, '\r', '\n');
  txt := replace(txt, '\n\n', '\n');
  arr := split_and_decode (txt, 0, '\0\0\n');
  foreach (any i in arr) do
    {
      i := trim (i);
      if (length (i))
	{
	  declare u, l, tmp any;

	  tmp := split_and_decode (i, 0, '\0\0;');
	  u := tmp[0];
	    l := '';
	  if (length (tmp) > 1)
	    l := tmp[1];
	  result (u, l);
	}
    }
};

create procedure WA_USER_APP_ENABLE (in user_id integer)
{
  return coalesce ((select WAUI_APP_ENABLE from WA_USER_INFO WHERE WAUI_U_ID = user_id), 0);
}
;

create procedure WA_USER_SPB_ENABLE (in user_id integer)
{
  return coalesce ((select WAUI_SPB_ENABLE from WA_USER_INFO WHERE WAUI_U_ID = user_id), 0);
}
;

create procedure WA_USER_TAG_SET (in owner_uid any, in tagee_uid integer, in tags varchar)
{
  if (not exists (select 1 from DB.DBA.SYS_USERS where U_ID = owner_uid))
    signal('WA001', sprintf('%%User U_ID=%d is not found%%', owner_uid));
  declare exit handler for not found {
      insert into WA_USER_TAG (WAUTG_U_ID, WAUTG_TAG_ID, WAUTG_FT_ID, WAUTG_TAGS)
      values (owner_uid, tagee_uid, WA_GET_FTID (), tags);
      return;
  };

  declare cr cursor for select 1 from WA_USER_TAG where WAUTG_U_ID = owner_uid and WAUTG_TAG_ID = tagee_uid;
  open cr (exclusive, prefetch 1);
  declare dummy integer;
  fetch cr into dummy;
  update WA_USER_TAG set WAUTG_TAGS = tags where current of cr;
  close cr;
  return;
}
;

create procedure WA_USER_TAG_GET (in uname varchar)
{
  declare _tags varchar;
  declare _uid integer;

  return coalesce ((select WAUTG_TAGS from DB.DBA.SYS_USERS, WA_USER_TAG where
    U_NAME = uname and WAUTG_U_ID = http_nobody_uid() and WAUTG_TAG_ID = U_ID option (order)), '');
}
;

create procedure WA_USER_TAGS_GET (in owner_uid integer, in tagee integer) returns varchar
{
  return coalesce ((select WAUTG_TAGS from WA_USER_TAG where WAUTG_U_ID = owner_uid and WAUTG_TAG_ID = tagee),'');
}
;

create procedure WA_USER_TAG_GET_P (in uname varchar)
{
  declare U_TAG varchar;
  declare arr any;
  result_names (U_TAG);
  U_TAG := WA_USER_TAG_GET (uname);
  arr := split_and_decode (U_TAG, 0, '\0\0,');
  foreach (any t in arr) do
    {
      t := trim (t);
      if (length (t))
	result (t);
    }

};

create procedure WA_GET_USER_TAGS_OR_QRY (in uid int)
{
  declare tagstr, tag varchar;
  tagstr := WA_USER_TAGS_GET (http_nobody_uid (), uid);
  declare _arr any;
  _arr := split_and_decode(trim(tagstr, ','), 0, '\0\0,');
  tag := '';
  foreach (any t in _arr) do
    {
      t := trim (t, '\'" ');
      t := replace(t, ' ', '_');
      t := replace(t, '.', '_');
      if (length (tag))
	tag := tag || ' or "' || t || '"';
      else
	tag := '"' || t || '"';
    }
  if (length (tag))
    return tag;
  else
    return '"nonsenseword"';
}
;

create procedure WA_TAG_PREPARE (inout tag varchar)
{
  if (length (tag))
    {
      tag := trim(tag);
      tag := replace(tag, '  ', ' ');
      tag := replace(tag, '\r', ',');
      tag := replace(tag, '\n', ' ');
      declare _arr any;
      _arr := split_and_decode(trim(tag, ','), 0, '\0\0,');
      tag := '';
      foreach (any t in _arr) do
	{
	  t := trim (t, '\'", ');
	  t := replace(t, ' ', '_');
	  t := replace(t, '.', '_');
	  if (length (t))
 	    tag := tag || ', ' || t;
	}
      tag := trim (tag, ', ');
    }
  return tag;
}
;


create procedure WA_VALIDATE_TAGS (in tag varchar)
{
  declare i integer;
  declare _arr any;

  _arr := split_and_decode(trim(tag, ','), 0, '\0\0,');
  for (i := 0; i < length(_arr); i := i + 1)
    if (not WA_VALIDATE_TAG(_arr[i]))
      return 0;
  return 1;
}
;

create procedure WA_VALIDATE_TAG ( in tag varchar)
{
  tag := trim (tag, '\'" ');
  tag := replace(tag, ' ', '_');
  --dbg_printf ('validating tag: [%s]', tag);
  if (not WA_VALIDATE_FTEXT(tag))
    return 0;
  if (not isnull(strstr(tag, '"')))
    return 0;
  if (not isnull(strstr(tag, '''')))
    return 0;
  if (length(tag) < 2)
    return 0;
  if (length(tag) > 50)
    return 0;
  return 1;
}
;

create procedure WA_VALIDATE_FTEXT ( in tag varchar)
{
  declare st, msg varchar;

  st := '00000';
  exec ('vt_parse (?)', st, msg, vector (tag));
  if ('00000' = st)
    return 1;
  return 0;
}
;

create procedure WA_USER_IS_TAGGED (in uid integer, in tagee integer)
{
  declare tags varchar;

  tags := WA_USER_TAGS_GET (uid, tagee);
  if (tags <> '')
    return 1;

  return 0;

}
;

create procedure WA_CLEAR (
  in S any)
{
  S := substring (S, 1, coalesce (strstr (S, '<>'), length (S)));
  S := substring (S, 1, coalesce (strstr (S, '\nin'), length (S)));

  return S;
}
;

create procedure WA_VALIDATE (
  in value any,
  in params any := null)
{
  declare valueType, valueClass, valueName, valueMessage, tmp any;

  declare exit handler for SQLSTATE '*' {
    if (not is_empty_or_null(valueMessage))
      signal ('TEST', valueMessage);
    if (__SQL_STATE = 'EMPTY')
      signal ('TEST', sprintf('Field ''%s'' cannot be empty!<>', valueName));
    if (__SQL_STATE = 'CLASS') {
      if (valueType in ('free-text', 'tags')) {
        signal ('TEST', sprintf('Field ''%s'' contains invalid characters or noise words!<>', valueName));
      } else {
        signal ('TEST', sprintf('Field ''%s'' contains invalid characters!<>', valueName));
      }
    }
    if (__SQL_STATE = 'TYPE')
      signal ('TEST', sprintf('Field ''%s'' contains invalid characters for \'%s\'!<>', valueName, valueType));
    if (__SQL_STATE = 'MIN')
      signal ('TEST', sprintf('''%s'' value should be greater than %s!<>', valueName, cast (tmp as varchar)));
    if (__SQL_STATE = 'MAX')
      signal ('TEST', sprintf('''%s'' value should be less than %s!<>', valueName, cast (tmp as varchar)));
    if (__SQL_STATE = 'MINLENGTH')
      signal ('TEST', sprintf('The length of field ''%s'' should be greater than %s characters!<>', valueName, cast (tmp as varchar)));
    if (__SQL_STATE = 'MAXLENGTH')
      signal ('TEST', sprintf('The length of field ''%s'' should be less than %s characters!<>', valueName, cast (tmp as varchar)));
    signal ('TEST', 'Unknown validation error!<>');
    --resignal;
  };

  value := trim(value);
  if (is_empty_or_null(params))
    return value;

  valueClass := coalesce (get_keyword ('class', params), get_keyword ('type', params));
  valueType := coalesce (get_keyword ('type', params), get_keyword ('class', params));
  valueName := get_keyword ('name', params, 'Field');
  valueMessage := get_keyword ('message', params, '');
  tmp := get_keyword ('canEmpty', params);
  if (isnull (tmp))
  {
    if (not isnull (get_keyword ('minValue', params))) {
      tmp := 0;
    } else if (get_keyword ('minLength', params, 0) <> 0) {
      tmp := 0;
    }
  }
  if (not isnull (tmp) and (tmp = 0) and is_empty_or_null(value)) {
    signal('EMPTY', '');
  } else if (is_empty_or_null(value)) {
    return value;
  }

  value := WA_VALIDATE2 (valueClass, value);

  if (valueType = 'integer') {
    tmp := get_keyword ('minValue', params);
    if ((not isnull (tmp)) and (value < tmp))
      signal('MIN', cast (tmp as varchar));

    tmp := get_keyword ('maxValue', params);
    if (not isnull (tmp) and (value > tmp))
      signal('MAX', cast (tmp as varchar));

  } else if (valueType = 'float') {
    tmp := get_keyword ('minValue', params);
    if (not isnull (tmp) and (value < tmp))
      signal('MIN', cast (tmp as varchar));

    tmp := get_keyword ('maxValue', params);
    if (not isnull (tmp) and (value > tmp))
      signal('MAX', cast (tmp as varchar));

  } else if (valueType = 'varchar') {
    tmp := get_keyword ('minLength', params);
    if (not isnull (tmp) and (length (value) < tmp))
      signal('MINLENGTH', cast (tmp as varchar));

    tmp := get_keyword ('maxLength', params);
    if (not isnull (tmp) and (length (value) > tmp))
      signal('MAXLENGTH', cast (tmp as varchar));
  }
  return value;
}
;

create procedure WA_VALIDATE2 (
  in propertyType varchar,
  in propertyValue varchar)
{
  declare exit handler for SQLSTATE '*' {
    if (__SQL_STATE = 'CLASS')
      resignal;
    signal('TYPE', propertyType);
    return;
  };

  if (propertyType = 'boolean') {
    if (propertyValue not in ('Yes', 'No'))
      goto _error;
  } else if (propertyType = 'integer') {
    if (isnull (regexp_match('^[0-9]+\$', propertyValue)))
      goto _error;
    return cast (propertyValue as integer);
  } else if (propertyType = 'float') {
    if (isnull (regexp_match('^[-+]?([0-9]*\.)?[0-9]+([eE][-+]?[0-9]+)?\$', propertyValue)))
      goto _error;
    return cast (propertyValue as float);
  } else if (propertyType = 'dateTime') {
    if (isnull (regexp_match('^((?:19|20)[0-9][0-9])[- /.](0[1-9]|1[012])[- /.](0[1-9]|[12][0-9]|3[01])\$', propertyValue)))
      if (isnull (regexp_match('^((?:19|20)[0-9][0-9])[- /.](0[1-9]|1[012])[- /.](0[1-9]|[12][0-9]|3[01]) ([01]?[0-9]|[2][0-3])(:[0-5][0-9])?\$', propertyValue)))
        goto _error;
    return cast (propertyValue as datetime);
  } else if (propertyType = 'dateTime2') {
    if (isnull (regexp_match('^((?:19|20)[0-9][0-9])[- /.](0[1-9]|1[012])[- /.](0[1-9]|[12][0-9]|3[01]) ([01]?[0-9]|[2][0-3])(:[0-5][0-9])?\$', propertyValue)))
      goto _error;
    return cast (propertyValue as datetime);
  } else if (propertyType = 'date') {
    if (isnull (regexp_match('^((?:19|20)[0-9][0-9])[- /.](0[1-9]|1[012])[- /.](0[1-9]|[12][0-9]|3[01])\$', propertyValue)))
      goto _error;
    return cast (propertyValue as datetime);
  } else if (propertyType = 'date2') {
    if (isnull (regexp_match('^(0[1-9]|[12][0-9]|3[01])[- /.](0[1-9]|1[012])[- /.]((?:19|20)[0-9][0-9])\$', propertyValue)))
      goto _error;
    return cast (propertyValue as datetime);
  } else if (propertyType = 'time') {
    if (isnull (regexp_match('^([01]?[0-9]|[2][0-3])(:[0-5][0-9])?\$', propertyValue)))
      goto _error;
    return cast (propertyValue as time);
  } else if (propertyType = 'folder') {
    if (isnull (regexp_match('^[^\\\/\?\*\"\'\>\<\:\|]*\$', propertyValue)))
      goto _error;
  } else if ((propertyType = 'uri') or (propertyType = 'anyuri')) {
    if (isnull (regexp_match('^(ht|f)tp(s?)\:\/\/[0-9a-zA-Z]([-.\w]*[0-9a-zA-Z])*(:(0-9)*)*(\/?)([a-zA-Z0-9\-\.\?\,\'\/\\\+&amp;%\$#_=:]*)?\$', propertyValue)))
      goto _error;
  } else if (propertyType = 'email') {
    if (isnull (regexp_match('^([a-zA-Z0-9_\-])+(\.([a-zA-Z0-9_\-])+)*@((\[(((([0-1])?([0-9])?[0-9])|(2[0-4][0-9])|(2[0-5][0-5])))\.(((([0-1])?([0-9])?[0-9])|(2[0-4][0-9])|(2[0-5][0-5])))\.(((([0-1])?([0-9])?[0-9])|(2[0-4][0-9])|(2[0-5][0-5])))\.(((([0-1])?([0-9])?[0-9])|(2[0-4][0-9])|(2[0-5][0-5]))\]))|((([a-zA-Z0-9])+(([\-])+([a-zA-Z0-9])+)*\.)+([a-zA-Z])+(([\-])+([a-zA-Z0-9])+)*))\$', propertyValue)))
      goto _error;
  } else if (propertyType = 'free-text') {
    if (length (propertyValue))
      vt_parse(propertyValue);
  } else if (propertyType = 'tags') {
    -- if (not ODRIVE.WA.validate_tags(propertyValue))
      goto _error;
  }
  return propertyValue;

_error:
  signal('CLASS', propertyType);
}
;


create procedure WA_GET_USER_INFO (in uid integer, in ufid integer, in visb any, in own integer, in umode integer default 0)
{
  declare _utitle, _fname, _lname, _fullname, _gender,_wpage,_efoaf, _email varchar;
  declare _bdate, is_search any;
  declare _msign, _sum long varchar;
  declare _haddress1, _haddress2, _hcode, _hcity, _hstate, _hcountry, _htzone, _hphone, _hmobile varchar;
  declare _uicq, _uskype, _uaim, _uyahoo, _umsn varchar;
  declare _bindustr, _borg, _bjob, _baddress1, _baddress2, _bcode, _bcity, _bstate, _bcountry, _btzone,
          _bphone, _bmobile, _bregno, _bcareer, _bempltotal, _bvendor, _bservice, _bother, _bnetwork varchar;
  declare _bresume, _audio, _fav_books, _fav_music, _fav_movie long varchar;
  declare _WAUI_PHOTO_URL, _interests, _interest_topics, _org_page varchar;
  declare _WAUI_LAT, _WAUI_LNG, _WAUI_BLAT, _WAUI_BLNG real;
  declare _WAUI_LATLNG_HBDEF, _is_org integer;
  declare _arr15, _arr16, _arr18, _arr22, _arr23, _arr25, _arr any;


  _arr15 := make_array(3, 'any');
  _arr16 := make_array(3, 'any');
  _arr18 := make_array(2, 'any');
  _arr22 := make_array(3, 'any');
  _arr23 := make_array(3, 'any');
  _arr25 := make_array(2, 'any');
  _arr := make_array(50, 'any');

  declare i integer;
  for (i := 0; i < length(_arr); i := i + 1)
  {
    aset(_arr, i, '');
  };

  SELECT WAUI_TITLE, WAUI_FIRST_NAME, WAUI_LAST_NAME,WAUI_FULL_NAME, WAUI_GENDER, WAUI_BIRTHDAY,WAUI_WEBPAGE, WAUI_FOAF, WAUI_MSIGNATURE, WAUI_SUMMARY,
         WAUI_ICQ, WAUI_SKYPE, WAUI_AIM, WAUI_YAHOO, WAUI_MSN,
         WAUI_HADDRESS1, WAUI_HADDRESS2, WAUI_HCODE, WAUI_HCITY, WAUI_HSTATE,WAUI_HCOUNTRY, WAUI_HTZONE, WAUI_HPHONE, WAUI_HMOBILE,
         WAUI_BINDUSTRY, WAUI_BORG, WAUI_BJOB, WAUI_BADDRESS1, WAUI_BADDRESS2, WAUI_BCODE, WAUI_BCITY,
         WAUI_BSTATE, WAUI_BCOUNTRY, WAUI_BTZONE, WAUI_BPHONE, WAUI_BMOBILE, WAUI_BREGNO,
         WAUI_BCAREER, WAUI_BEMPTOTAL, WAUI_BVENDOR, WAUI_BSERVICE, WAUI_BOTHER, WAUI_BNETWORK, WAUI_RESUME,
         U_E_MAIL, WAUI_PHOTO_URL, WAUI_LAT, WAUI_LNG, WAUI_BLAT, WAUI_BLNG, WAUI_LATLNG_HBDEF,
	 WAUI_AUDIO_CLIP, WAUI_FAVORITE_BOOKS, WAUI_FAVORITE_MUSIC, WAUI_FAVORITE_MOVIES,
	       WAUI_SEARCHABLE, WAUI_INTERESTS, WAUI_INTEREST_TOPICS, WAUI_BORG_HOMEPAGE, WAUI_IS_ORG
    INTO _utitle, _fname, _lname, _fullname, _gender, _bdate, _wpage, _efoaf, _msign, _sum,
         _uicq, _uskype, _uaim, _uyahoo, _umsn,
         _haddress1, _haddress2, _hcode, _hcity, _hstate, _hcountry, _htzone, _hphone, _hmobile,
         _bindustr, _borg, _bjob, _baddress1, _baddress2, _bcode, _bcity, _bstate, _bcountry, _btzone,
         _bphone, _bmobile, _bregno, _bcareer, _bempltotal, _bvendor, _bservice, _bother, _bnetwork, _bresume,
         _email, _WAUI_PHOTO_URL, _WAUI_LAT, _WAUI_LNG, _WAUI_BLAT, _WAUI_BLNG, _WAUI_LATLNG_HBDEF,
         _audio, _fav_books, _fav_music, _fav_movie,
	       is_search, _interests,  _interest_topics, _org_page, _is_org
    FROM WA_USER_INFO, DB.DBA.SYS_USERS  where WAUI_U_ID = U_ID  and  U_ID = ufid;

  declare is_friend integer;
  is_friend := 0;
  if (umode = 0) is_friend := WA_USER_IS_FRIEND (uid, ufid);

  declare _data long varchar;
  _data := '';

  if (not own)
  {
    -- personal
    if (atoi(visb[0]) = 3 or (atoi(visb[0]) = 2 and not(is_friend)))  _utitle := ''; -- or is not friend
      else if (atoi(visb[0]) = 1 and umode = 1) _data := concat(_data, ' ', _utitle);

    if (atoi(visb[1]) = 3 or (atoi(visb[1]) = 2 and not(is_friend)))  _fname := '';
      else if (atoi(visb[1]) = 1 and umode = 1) _data := concat(_data, ' ', _fname);

    if (atoi(visb[2]) = 3 or (atoi(visb[2]) = 2 and not(is_friend)))  _lname := '';
      else if (atoi(visb[2]) = 1 and umode = 1) _data := concat(_data, ' ', _lname);

    if (atoi(visb[3]) = 3 or (atoi(visb[3]) = 2 and not(is_friend)))  _fullname := '';
      else if (atoi(visb[3]) = 1 and umode = 1) _data := concat(_data, ' ', _fullname);

    if (atoi(visb[4]) = 3 or (atoi(visb[4]) = 2 and not(is_friend)))  _email := '';
      else if (atoi(visb[4]) = 1 and umode = 1) _data := concat(_data, ' ', _email);

    if (atoi(visb[5]) = 3 or (atoi(visb[5]) = 2 and not(is_friend)))  _gender := '';
      else if (atoi(visb[5]) = 1 and umode = 1) _data := concat(_data, ' ', _gender);

    if (atoi(visb[6]) = 3 or (atoi(visb[6]) = 2 and not(is_friend)))  _bdate := '';
      else if (atoi(visb[6]) = 1 and umode = 1) _data := concat(_data, ' ',  WA_DATE_GET(_bdate));

    if (atoi(visb[7]) = 3 or (atoi(visb[7]) = 2 and not(is_friend)))  _wpage := '';
      else if (atoi(visb[7]) = 1 and umode = 1) _data := concat(_data, ' ', _wpage);

    if (atoi(visb[8]) = 3 or (atoi(visb[8]) = 2 and not(is_friend)))  _efoaf := '';
      else if (atoi(visb[8]) = 1 and umode = 1) _data := concat(_data, ' ', _utitle);

    if (atoi(visb[9]) = 3 or (atoi(visb[9]) = 2 and not(is_friend)))  _msign := '';
      else if (atoi(visb[9]) = 1 and umode = 1) _data := concat(_data, ' ', _msign);

    -- contact
    if (atoi(visb[10]) = 3 or (atoi(visb[10]) = 2 and not(is_friend)))  _uicq := '';
      else if (atoi(visb[10]) = 1 and umode = 1) _data := concat(_data, ' ', _uicq);

    if (atoi(visb[11]) = 3 or (atoi(visb[11]) = 2 and not(is_friend)))  _uskype := '';
      else if (atoi(visb[11]) = 1 and umode = 1) _data := concat(_data, ' ', _uskype);

    if (atoi(visb[12]) = 3 or (atoi(visb[12]) = 2 and not(is_friend)))  _uaim := '';
      else if (atoi(visb[12]) = 1 and umode = 1) _data := concat(_data, ' ', _uaim);

    if (atoi(visb[13]) = 3 or (atoi(visb[13]) = 2 and not(is_friend)))  _uyahoo := '';
      else if (atoi(visb[13]) = 1 and umode = 1) _data := concat(_data, ' ', _uyahoo);

    if (atoi(visb[14]) = 3 or (atoi(visb[14]) = 2 and not(is_friend)))  _umsn := '';
      else if (atoi(visb[14]) = 1 and umode = 1) _data := concat(_data, ' ', _umsn);

    -- home
    if (atoi(visb[15]) = 3 or (atoi(visb[15]) = 2 and not(is_friend)))
    {
      _haddress1 := '';
      _haddress2 := '';
      _hcode := '';
    }else if (atoi(visb[15]) = 1 and umode = 1){
      _data := concat(_data, ' ',  _haddress1, ' ',  _haddress2, ' ',  _hcode);
    };

    if (atoi(visb[16]) = 3 or (atoi(visb[16]) = 2 and not(is_friend)))
    {
      _hcity := '';
      _hstate := '';
      _hcountry := '';
    }else if (atoi(visb[16]) = 1 and umode = 1){
      _data := concat(_data, ' ',  _hcity, ' ', _hstate, ' ',  _hcountry);
    };

    if (atoi(visb[17]) = 3 or (atoi(visb[17]) = 2 and not(is_friend)))  _htzone := '';
      else if (atoi(visb[17]) = 1 and umode = 1) _data := concat(_data, ' ', _htzone);

    if (atoi(visb[18]) = 3 or (atoi(visb[18]) = 2 and not(is_friend)))
    {
      _hphone := '';
      _hmobile := '';
    }else if (atoi(visb[18]) = 1 and umode = 1){
      _data := concat(_data, ' ',  _hphone, ' ', _hmobile);
    };

    -- business
    if (atoi(visb[19]) = 3 or (atoi(visb[19]) = 2 and not(is_friend)))  _bindustr := '';
      else if (atoi(visb[19]) = 1 and umode = 1) _data := concat(_data, ' ', _bindustr);

    if (atoi(visb[20]) = 3 or (atoi(visb[20]) = 2 and not(is_friend)))  _borg := '';
      else if (atoi(visb[20]) = 1 and umode = 1) _data := concat(_data, ' ', _borg);

    if (atoi(visb[21]) = 3 or (atoi(visb[21]) = 2 and not(is_friend)))  _bjob := '';
      else if (atoi(visb[21]) = 1 and umode = 1) _data := concat(_data, ' ',_bjob);

    if (atoi(visb[22]) = 3 or (atoi(visb[22]) = 2 and not(is_friend)))
    {
      _baddress1 := '';
      _baddress2 := '';
      _bcode := '';
    }else if (atoi(visb[22]) = 1 and umode = 1){
      _data := concat(_data, ' ',  _baddress1, ' ',  _baddress2, ' ',  _bcode);
    };

    if (atoi(visb[23]) = 3 or (atoi(visb[23]) = 2 and not(is_friend)))
    {
      _bcity := '';
      _bstate := '';
      _bcountry := '';
    }else if (atoi(visb[23]) = 1 and umode = 1){
      _data := concat(_data, ' ',  _bcity, ' ', _bstate, ' ',  _bcountry);
    };

    if (atoi(visb[24]) = 3 or (atoi(visb[24]) = 2 and not(is_friend)))  _btzone := '';
      else if (atoi(visb[24]) = 1 and umode = 1) _data := concat(_data, ' ', _btzone);

    if (atoi(visb[25]) = 3 or (atoi(visb[25]) = 2 and not(is_friend)))
    {
      _bphone := '';
      _bmobile := '';
    }else if (atoi(visb[25]) = 1 and umode = 1){
      _data := concat(_data, ' ',  _bphone, ' ', _bmobile);
    };

    if (atoi(visb[26]) = 3 or (atoi(visb[26]) = 2 and not(is_friend)))  _bregno := '';
      else if (atoi(visb[26]) = 1 and umode = 1) _data := concat(_data, ' ', _bregno);

    if (atoi(visb[27]) = 3 or (atoi(visb[27]) = 2 and not(is_friend)))  _bcareer := '';
      else if (atoi(visb[27]) = 1 and umode = 1) _data := concat(_data, ' ', _bcareer);

    if (atoi(visb[28]) = 3 or (atoi(visb[28]) = 2 and not(is_friend)))  _bempltotal := '';
      else if (atoi(visb[28]) = 1 and umode = 1) _data := concat(_data, ' ', _bempltotal);

    if (atoi(visb[29]) = 3 or (atoi(visb[29]) = 2 and not(is_friend)))  _bvendor := '';
      else if (atoi(visb[29]) = 1 and umode = 1) _data := concat(_data, ' ', _bvendor);

    if (atoi(visb[30]) = 3 or (atoi(visb[30]) = 2 and not(is_friend)))  _bservice := '';
      else if (atoi(visb[30]) = 1 and umode = 1) _data := concat(_data, ' ', _bservice);

    if (atoi(visb[31]) = 3 or (atoi(visb[31]) = 2 and not(is_friend)))  _bother := '';
      else if (atoi(visb[31]) = 1 and umode = 1) _data := concat(_data, ' ', _bother);

    if (atoi(visb[32]) = 3 or (atoi(visb[32]) = 2 and not(is_friend)))  _bnetwork := '';
      else if (atoi(visb[32]) = 1 and umode = 1) _data := concat(_data, ' ', _bnetwork);

    _sum := blob_to_string (_sum);
    if (atoi(visb[33]) = 3 or (atoi(visb[33]) = 2 and not(is_friend)))  _sum := '';
      else if (atoi(visb[33]) = 1 and umode = 1) _data := concat(_data, ' ', _sum);

    _bresume := blob_to_string (_bresume);
    if (atoi(visb[34]) = 3 or (atoi(visb[34]) = 2 and not(is_friend)))  _bresume := '';
      else if (atoi(visb[34]) = 1 and umode = 1) _data := concat(_data, ' ', _bresume);

    if (atoi(visb[37]) = 3 or (atoi(visb[37]) = 2 and not(is_friend)))  _WAUI_PHOTO_URL := '';
      else if (atoi(visb[37]) = 1 and umode = 1) _data := concat(_data, ' ', _WAUI_PHOTO_URL);

    if (atoi(visb[43]) = 3 or (atoi(visb[43]) = 2 and not(is_friend)))
      _audio := '';
    else if (atoi(visb[43]) = 1 and umode = 1)
      _data := concat(_data, ' ', blob_to_string (_audio));

    if (atoi(visb[44]) = 3 or (atoi(visb[44]) = 2 and not(is_friend))) _fav_books := '';
    else if (atoi(visb[44]) = 1 and umode = 1)
        _data := concat(_data, ' ', blob_to_string (_fav_books));

    if (atoi(visb[45]) = 3 or (atoi(visb[45]) = 2 and not(is_friend))) _fav_music := '';
    else if (atoi(visb[45]) = 1 and umode = 1)
        _data := concat(_data, ' ', blob_to_string (_fav_music));

    if (atoi(visb[46]) = 3 or (atoi(visb[46]) = 2 and not(is_friend))) _fav_movie := '';
    else if (atoi(visb[46]) = 1 and umode = 1)
        _data := concat(_data, ' ', blob_to_string (_fav_movie));


    if (_WAUI_LATLNG_HBDEF=0)
    {
       if (atoi(visb[39]) = 3 or (atoi(visb[39]) = 2 and not(is_friend)))
       {
         _WAUI_LAT := null;
         _WAUI_LNG := null;
       }
       else if (atoi(visb[39]) = 1 and umode = 1)
       {
         _data := concat(_data, ' ', cast (_WAUI_LAT as varchar));
         _data := concat(_data, ' ', cast (_WAUI_LNG as varchar));
       };

    }else if(_WAUI_LATLNG_HBDEF=1)
    {
       if (atoi(visb[47]) = 3 or (atoi(visb[47]) = 2 and not(is_friend)))
       {
         _WAUI_BLAT := null;
         _WAUI_BLNG := null;
       }
       else if (atoi(visb[47]) = 1 and umode = 1)
       {
         _data := concat(_data, ' ', cast (_WAUI_BLAT as varchar));
         _data := concat(_data, ' ', cast (_WAUI_BLNG as varchar));
       }

    };

    if (atoi(visb[48]) = 3 or (atoi(visb[48]) = 2 and not(is_friend)))
      _interests := '';
    else if (atoi(visb[48]) = 1 and umode = 1)
      _data := concat(_data, ' ', blob_to_string (_interests));

    if (atoi(visb[20]) = 3 or (atoi(visb[20]) = 2 and not(is_friend)))
      _org_page := '';
    else if (atoi(visb[20]) = 1 and umode = 1)
      _data := concat(_data, ' ', blob_to_string (_org_page));





  };

  aset(_arr15, 0, wa_utf8_to_wide (_haddress1));
  aset(_arr15, 1, wa_utf8_to_wide (_haddress2));
  aset(_arr15, 2, _hcode);
  aset(_arr16, 0, wa_utf8_to_wide (_hcity));
  aset(_arr16, 1, wa_utf8_to_wide (_hstate));
  aset(_arr16, 2, _hcountry);
  aset(_arr18, 0, _hphone);
  aset(_arr18, 1, _hmobile);
  aset(_arr22, 0, wa_utf8_to_wide (_baddress1));
  aset(_arr22, 1, wa_utf8_to_wide (_baddress2));
  aset(_arr22, 2, _bcode);
  aset(_arr23, 0, wa_utf8_to_wide (_bcity));
  aset(_arr23, 1, wa_utf8_to_wide (_bstate));
  aset(_arr23, 2, _bcountry);
  aset(_arr25, 0, _bphone);
  aset(_arr25, 1, _bmobile);


  aset(_arr,0, _utitle);
  aset(_arr,1, wa_utf8_to_wide (_fname));
  aset(_arr,2, wa_utf8_to_wide (_lname));
  aset(_arr,3, wa_utf8_to_wide (_fullname));
  aset(_arr,4, _email);
  aset(_arr,5, _gender);
  aset(_arr,6, WA_DATE_GET(_bdate));
  aset(_arr,7, _wpage);
  aset(_arr,8, _efoaf);
  aset(_arr,9, wa_utf8_to_wide (_msign));
  aset(_arr,10, _uicq);
  aset(_arr,11, _uskype);
  aset(_arr,12, _uaim);
  aset(_arr,13, _uyahoo);
  aset(_arr,14, _umsn);
  aset(_arr,15, _arr15);
  aset(_arr,16, _arr16);
  aset(_arr,17, _htzone);
  aset(_arr,18, _arr18);
  aset(_arr,19, _bindustr);
  aset(_arr,20, wa_utf8_to_wide (_borg));
  aset(_arr,21, wa_utf8_to_wide (_bjob));
  aset(_arr,22, _arr22);
  aset(_arr,23, _arr23);
  aset(_arr,24, _btzone);
  aset(_arr,25, _arr25);
  aset(_arr,26, _bregno);
  aset(_arr,27, _bcareer);
  aset(_arr,28, _bempltotal );
  aset(_arr,29, _bvendor);
  aset(_arr,30, _bservice);
  aset(_arr,31, _bother);
  aset(_arr,32, _bnetwork);
  aset(_arr,33, wa_utf8_to_wide (_sum));
  aset(_arr,34, wa_utf8_to_wide (_bresume));
  _arr [37] := _WAUI_PHOTO_URL;
  _arr [39] := _WAUI_LAT;
  _arr [40] := _WAUI_LNG;

  _arr [43] := _audio;
  _arr [44] := _fav_books;
  _arr [45] := _fav_music;
  _arr [46] := _fav_movie;
  _arr [47] := _interests;
  _arr [48] := _org_page;
  _arr [49] := _is_org;

  if (is_search is not null and is_search = 0)
    _data := '';

  if (umode = 1)
    return trim(_data, ' ');
  else
    return _arr;

}
;


create procedure WA_DATE_GET (in udate datetime)
{
  declare d, m, y integer;
  if (udate is null or isinteger (udate) or isstring (udate))
     return '';
  d := dayofmonth(udate);
  m := month(udate);
  y := year(udate);
  return sprintf('%d-%d-%d',m,d,y);
}
;

WA_USER_INFO_CHECK ();

create procedure WA_USER_IS_FRIEND (in uid integer, in ufid integer)
{
  declare _sne_id, _sne_fid integer;

  _sne_id := coalesce((select sne_id from sn_entity where sne_org_id = uid),0);
  if (_sne_id = 0)
    return 0;

  _sne_fid := coalesce((select sne_id from sn_entity where sne_org_id = ufid),0);
  if (_sne_fid = 0)
    return 0;

  if (exists (select 1 from sn_related, sn_entity where snr_from = _sne_id and snr_to = _sne_fid))
    return 1;
  if (exists (select 1 from sn_related, sn_entity where snr_to = _sne_id and snr_from = _sne_fid))
    return 1;

  return 0;
}
;

create procedure WA_OPTION_IS_PUBLIC (in ufname varchar, in num integer)
{
  declare visb any;
  declare i integer;

  visb := WA_USER_VISIBILITY(ufname);
  if (not(isarray(visb))) return 0;
  for (i := 0; i < length(visb); i := i + 1)
  {
    if (i = num)
    {
      if (atoi(visb[i]) = 1)
        return 1;
      else
        return 0;
    };
  };
  return 0;
}
;

create procedure WA_USER_TEXT_SET (in uid integer, in udata any)
{
  if (uid = 0)
    return;

  if (not exists (select 1 from DB.DBA.SYS_USERS where U_ID = uid))
    signal('WA001', sprintf('%%User U_ID=%d is not found%%', uid));

  if (exists (select 1 from WA_USER_TEXT where WAUT_U_ID = uid))
    {
      update WA_USER_TEXT set WAUT_TEXT = udata where WAUT_U_ID = uid;
    }
  else
    {
      insert into WA_USER_TEXT (WAUT_U_ID, WAUT_TEXT) values (uid, udata);
    }

  return;
}
;

select
	WA_USER_TEXT_SET (
		U_ID,
		WA_GET_USER_INFO(
			0,
			u_id,
			WA_USER_VISIBILITY(u_name),
			0,
			1
		)
	)
  from
    DB.DBA.SYS_USERS
  where
    U_ID not in (select WAUT_U_ID from WA_USER_TEXT)
    and exists (select 1 from WA_USER_INFO where WAUI_U_ID = U_ID)
;

create procedure wa_app_menu_fill_names (in asid varchar, in arealm varchar, in user_id integer, in app_type varchar, in fname varchar default null)
{
  declare item_name, url, ret varchar;
  declare i, user_fid integer;

  i := 0;
  --dbg_obj_print ('self =', realm);
  --dbg_obj_print ('self.user_id =', user_id);

  user_fid := coalesce((select U_ID from SYS_USERS where U_NAME = fname),null);
  --dbg_obj_print ('--------------------------');
  --dbg_obj_print (fname);
  --dbg_obj_print (app_type);
  --dbg_obj_print ('user_fid =', user_fid);
  --dbg_obj_print ('user_id =', user_id);

  ret := '[';
  if (user_id is not null and user_fid is not null) -- user_id views user_fid app instance menu
  {

   --dbg_obj_print ('--case1');
   for (select WAM_INST as winst, WAM_HOME_PAGE as wpage
          from WA_MEMBER
         where WAM_IS_PUBLIC = 1
           and WAM_APP_TYPE = app_type
           and WAM_USER = user_fid
           and WAM_MEMBER_TYPE = 1
        union all
        select WAM_INST as winst, WAM_HOME_PAGE as wpage
          from WA_MEMBER
          where WAM_USER = user_id
            and WAM_STATUS = 2
            and WAM_APP_TYPE = app_type
            and WAM_MEMBERS_VISIBLE = 1
            and WAM_INST NOT IN ( select WAM_INST, WAM_HOME_PAGE
                                    from WA_MEMBER
                                   where WAM_IS_PUBLIC = 1
                                     and WAM_APP_TYPE = app_type
                                     and WAM_USER = user_fid
                                     and WAM_MEMBER_TYPE = 1)
       order by winst
    )do
    {
      i := 1;
      --dbg_obj_print(winst);
      --dbg_obj_print(wpage);
      ret := ret || '"' || winst || '", "' || wa_inst_url (wpage, asid, arealm, app_type) || '",';
    };
   if (not(i))
    ret := ret || '"' || 'No Instances' || '", "' || '' || '",';
  }
  else if (user_id is not null and isnull(user_fid)) -- user_id views its own app instance menu
  {
    --dbg_obj_print ('--case2');
    for (select WAM_INST, WAM_HOME_PAGE from WA_MEMBER where WAM_USER = user_id and WAM_APP_TYPE = app_type order by WAM_INST) do
    {
      i := 1;
      ret := ret || '"' || WAM_INST || '", "' || wa_inst_url (WAM_HOME_PAGE, asid, arealm, app_type) || '",';
    };
    ret := ret || ' "Create New", "' || wa_get_new_url (app_type, asid, arealm) || '",';
  }
  else if (isnull(user_id) and user_fid is not null) -- nobody views user_fid app instance menu
  {
    --dbg_obj_print ('--case3');
    for (select WAM_INST, WAM_HOME_PAGE from WA_MEMBER where WAM_IS_PUBLIC = 1 and WAM_APP_TYPE = app_type and WAM_USER = user_fid order by WAM_INST) do
    {
     --dbg_obj_print (ret);
      i := 1;
      ret := ret || '"' || WAM_INST || '", "' || wa_inst_url (WAM_HOME_PAGE, '', '', app_type) || '",';
    };
   if (not(i))
    ret := ret || '"' || 'No Instances' || '", "' || '' || '",';
  }
  else
  {
    --dbg_obj_print ('--case4');
    -- XXX: when no user nor login just say New, list otherwise can be exhaustive
    ret := ret || ' "Create New", "' || wa_get_new_url (app_type, asid, arealm) || '",';
    --for (select distinct WAM_INST, WAM_HOME_PAGE from WA_MEMBER where WAM_IS_PUBLIC = 1 and WAM_APP_TYPE = app_type order by WAM_INST) do
    --{
    --  i := 1;
    --  ret := ret || '"' || WAM_INST || '", "' || wa_inst_url (WAM_HOME_PAGE, '', '', app_type) || '",';
    --};
  };

  --if (not(i))
  --  ret := ret || '"' || 'No Instances' || '", "' || '' || '",';
  if ("RIGHT" (ret, 1) = ',')
    aset (ret, length (ret) -1, ascii (']'));
  else
    ret := ret || ']';
 -- dbg_obj_print ('- - - - - - - - -');
 -- dbg_obj_print (ret);
 -- dbg_obj_print ('- - - - - - - - -');


  http (ret);
  return;
}
;

create procedure WA_APP_INSTANCES (in user_id integer, in app_type varchar default '%', in fname varchar default null)
{
  declare item_name, url, ret varchar;
  declare i, user_fid integer;
  declare INST_NAME, INST_URL, INST_TYPE varchar;

  i := 0;

  if (app_type is null)
   app_type := '%';

  user_fid := coalesce((select U_ID from SYS_USERS where U_NAME = fname), user_id);

  result_names (INST_NAME, INST_URL, INST_TYPE);

  if (user_id is not null and user_id <> user_fid) -- user_id views user_fid app instance menu
  {

   --dbg_obj_print ('--case1');
   for select WAM_INST as winst, WAM_HOME_PAGE as wpage, WAM_APP_TYPE
          from WA_MEMBER
         where WAM_IS_PUBLIC = 1
           and WAM_APP_TYPE like app_type
           and WAM_USER = user_fid
           and WAM_MEMBER_TYPE = 1
        union all
        select WAM_INST as winst, WAM_HOME_PAGE as wpage, WAM_APP_TYPE as wpage
          from WA_MEMBER
          where WAM_USER = user_id
            and WAM_STATUS = 2
            and WAM_APP_TYPE like app_type
            and WAM_MEMBERS_VISIBLE = 1
            and WAM_INST NOT IN ( select WAM_INST, WAM_HOME_PAGE
                                    from WA_MEMBER
                                   where WAM_IS_PUBLIC = 1
                                     and WAM_APP_TYPE like app_type
                                     and WAM_USER = user_fid
                                     and WAM_MEMBER_TYPE = 1)
       order by winst
      do
    {
      result (winst, wpage, WAM_APP_TYPE);
    }
  }
  else if (user_id is not null and user_fid = user_id) -- user_id views its own app instance menu
  {
    for select WAM_INST, WAM_HOME_PAGE, WAM_APP_TYPE from WA_MEMBER where WAM_USER = user_id and WAM_APP_TYPE like app_type order by WAM_INST do
    {
      result (WAM_INST, WAM_HOME_PAGE, WAM_APP_TYPE);
    }
  }
  else if (user_id is null and user_fid is not null) -- nobody views user_fid app instance menu
  {
    for select WAM_INST, WAM_HOME_PAGE, WAM_APP_TYPE from WA_MEMBER where WAM_IS_PUBLIC = 1 and WAM_APP_TYPE like app_type and WAM_USER = user_fid order by WAM_INST do
    {
      result (WAM_INST, WAM_HOME_PAGE, WAM_APP_TYPE);
    };
  }

};

wa_exec_no_error_log ('drop view WA_USER_APP_INSTANCES');
wa_exec_no_error_log ('create procedure view WA_USER_APP_INSTANCES as
   WA_APP_INSTANCES (user_id, app_type, fname) (INST_NAME varchar, INST_URL varchar, INST_TYPE varchar)');

create procedure WA_APP_GET_OWNER (in inst_identity any)
{
  declare inst_owner varchar;
  if(isinteger(inst_identity))
    inst_owner:=(select U_NAME from WA_MEMBER,WA_INSTANCE,SYS_USERS where WAM_INST=WAI_NAME and WAI_ID =inst_identity and WAM_MEMBER_TYPE = 1 and WAM_USER=U_ID );
  else
    inst_owner:=(select U_NAME from WA_MEMBER,SYS_USERS where WAM_USER=U_ID and WAM_MEMBER_TYPE = 1 and WAM_INST=inst_identity);

  return inst_owner;
}
;
create procedure WA_USER_FULLNAME (in _identity any)
{
  declare _u_full_name varchar;

  if(isinteger(_identity))
    _u_full_name:=(select coalesce(WAUI_FULL_NAME,trim(concat(WAUI_FIRST_NAME,' ',WAUI_LAST_NAME)),'') from DB.DBA.WA_USER_INFO where WAUI_U_ID=_identity);
  else
    _u_full_name:=(select coalesce(WAUI_FULL_NAME,trim(concat(WAUI_FIRST_NAME,' ',WAUI_LAST_NAME)),_identity) from DB.DBA.WA_USER_INFO,DB.DBA.SYS_USERS where WAUI_U_ID=U_ID and U_NAME=_identity);

  return _u_full_name;
}
;


create procedure WA_APP_INSTANCE_DATASPACE (in inst_identity any)
{
  declare inst_dataspace,_u_name,_inst_name,_inst_type varchar;

  declare exit handler for sqlstate '*'{return '';};

  if(isinteger(inst_identity))
    select U_NAME,WAM_INST,WAM_APP_TYPE into _u_name,_inst_name,_inst_type from WA_MEMBER,WA_INSTANCE,SYS_USERS where WAM_INST=WAI_NAME and WAI_ID =inst_identity and WAM_MEMBER_TYPE = 1 and WAM_USER=U_ID;
  else
    select U_NAME,WAM_INST,WAM_APP_TYPE into _u_name,_inst_name,_inst_type from WA_MEMBER,SYS_USERS where WAM_USER=U_ID and WAM_MEMBER_TYPE = 1 and WAM_INST=inst_identity;


  inst_dataspace:=sprintf('/dataspace/%s/%s/%U',_u_name,wa_get_app_dataspace(_inst_type),_inst_name);

  return inst_dataspace;
}
;
create procedure WA_USER_DATASPACE (in _identity any)
{
  declare _u_name varchar;

  if(isinteger(_identity))
    _u_name:=(select U_NAME from DB.DBA.SYS_USERS where U_ID=_identity);
  else
    _u_name:=_identity;

  declare _user_dataspace varchar;
  _user_dataspace:=sprintf('/dataspace/%s/%s#this',wa_identity_dstype(_identity),_u_name);

  return _user_dataspace;
}
;

create procedure WA_APP_INSTANCES_DATASPACE (in user_id integer, in app_type varchar default '%', in fname varchar default null)
{
  --declare item_name, url, ret varchar;
  declare i, user_fid integer;
  declare INST_NAME, INST_URL, INST_TYPE, INST_OWNER, INST_DATASPACE varchar;

  declare app_dataspace varchar;
  app_dataspace:=wa_get_app_dataspace(app_type);

  i := 0;

  if (app_type is null)
   app_type := '%';

  user_fid := coalesce((select U_ID from SYS_USERS where U_NAME = fname), user_id);

  result_names (INST_NAME, INST_URL, INST_TYPE, INST_OWNER, INST_DATASPACE);

  if (user_id is not null and user_id <> user_fid) -- user_id views user_fid app instance menu
  {

   --dbg_obj_print ('--case1');
   for select WAM_INST as winst, WAM_HOME_PAGE as wpage, WAM_APP_TYPE
          from WA_MEMBER
         where WAM_IS_PUBLIC = 1
           and WAM_APP_TYPE like app_type
           and WAM_USER = user_fid
           and WAM_MEMBER_TYPE = 1
        union all
        select WAM_INST as winst, WAM_HOME_PAGE as wpage, WAM_APP_TYPE as wpage
          from WA_MEMBER
          where WAM_USER = user_id
            and WAM_STATUS = 2
            and WAM_APP_TYPE like app_type
            and WAM_MEMBERS_VISIBLE = 1
            and WAM_INST NOT IN ( select WAM_INST, WAM_HOME_PAGE
                                    from WA_MEMBER
                                   where WAM_IS_PUBLIC = 1
                                     and WAM_APP_TYPE like app_type
                                     and WAM_USER = user_fid
                                     and WAM_MEMBER_TYPE = 1)
       order by winst
      do
    {
      INST_OWNER:=WA_APP_GET_OWNER(winst);
      INST_DATASPACE:='/dataspace/'||INST_OWNER||'/'||app_dataspace||'/'||sprintf('%U',winst);
      result (winst, wpage, WAM_APP_TYPE, INST_OWNER, INST_DATASPACE);
    }
  }
  else if (user_id is not null and user_fid = user_id) -- user_id views its own app instance menu
  {
    for select WAM_INST, WAM_HOME_PAGE, WAM_APP_TYPE from WA_MEMBER where WAM_USER = user_id and WAM_APP_TYPE like app_type order by WAM_INST do
    {

      INST_OWNER:=WA_APP_GET_OWNER(WAM_INST);
      INST_DATASPACE:='/dataspace/'||INST_OWNER||'/'||app_dataspace||'/'||sprintf('%U',WAM_INST);
      result (WAM_INST, WAM_HOME_PAGE, WAM_APP_TYPE, INST_OWNER , INST_DATASPACE);
    }
  }
  else if (user_id is null and user_fid is not null) -- nobody views user_fid app instance menu
  {
    for select WAM_INST, WAM_HOME_PAGE, WAM_APP_TYPE from WA_MEMBER where WAM_USER = user_fid and WAM_IS_PUBLIC = 1 and WAM_APP_TYPE like app_type order by WAM_INST do
    {
      INST_OWNER:=WA_APP_GET_OWNER(WAM_INST);
      INST_DATASPACE:='/dataspace/'||INST_OWNER||'/'||app_dataspace||'/'||sprintf('%U',WAM_INST);
      result (WAM_INST, WAM_HOME_PAGE, WAM_APP_TYPE, INST_OWNER , INST_DATASPACE);
    };
  }

};

wa_exec_no_error_log ('drop view WA_USER_APP_INSTANCES_DATASPACE');
wa_exec_no_error_log ('create procedure view WA_USER_APP_INSTANCES_DATASPACE as
   WA_APP_INSTANCES_DATASPACE (user_id, app_type, fname) (INST_NAME varchar, INST_URL varchar, INST_TYPE varchar, INST_OWNER varchar, INST_DATASPACE_URL varchar)');

create procedure wa_set_url_t (in wai_inst any)
{
	declare url varchar;
	declare s web_app;
        declare h any;
        s := wai_inst;
        h := udt_implements_method (s, fix_identifier_case ('wa_home_url'));
	url := null;
	if (h)
          url := call (h) (s);
--	dbg_obj_print ('wa_set_url_t URL = ', url);
--	update WA_MEMBER set WAM_HOME_PAGE = url where WAM_INST = WAI_NAME;
	return url;
}
;


create procedure wa_set_url ()
{
  for (select WAI_ID, WAI_NAME, WAI_INST from WA_INSTANCE) do
     {
	declare url varchar;
        declare h any;
	declare s web_app;
        s := WAI_INST;

	if (s.wa_name <> WAI_NAME)
	  {
	    log_message (sprintf ('The application instance "%s" have different name in the type representation, it should be deleted.', WAI_NAME));
	  }
	else
	  {
	    h := udt_implements_method (s, fix_identifier_case ('wa_home_url'));
	    url := null;
	    if (h)
	      url := call (h) (s);
	    --dbg_obj_print (WAI_NAME, url);
	    update WA_MEMBER set WAM_HOME_PAGE = url where WAM_INST = WAI_NAME;
	 }

     }
}
;

create procedure wa_wa_member_upgrade ()
{

   declare _id, _mt, _ip integer;
   declare _inst varchar;

   if (registry_get ('__wa_wa_member_upgrade') = 'done')
     return;

   set triggers off;

   for select WAI_NAME, WAI_IS_PUBLIC, WAI_MEMBERS_VISIBLE, WAI_TYPE_NAME, WAI_INST from WA_INSTANCE do
     {
       declare exit handler for sqlstate '*'
	 {
	   log_message (sprintf ('WA upgrade found a broken instance: [%s], must be deleted.', WAI_NAME));
	   goto nextu;
	 };
    update DB.DBA.WA_MEMBER
       set WAM_IS_PUBLIC = WAI_IS_PUBLIC,
	      WAM_MEMBERS_VISIBLE = WAI_MEMBERS_VISIBLE,
	      WAM_HOME_PAGE = wa_set_url_t (WAI_INST),
	      WAM_APP_TYPE = WAI_TYPE_NAME
		  where WAM_INST = WAI_NAME;
       nextu:;
     }

   set triggers on;

   registry_set ('__wa_wa_member_upgrade', 'done');
   return;

}
;

create procedure WA_FOAF_UPGRADE ()
{
  declare tmp, access, uname, visibility any;

  if (registry_get ('WA_FOAF_UPGRADE') = 'done')
    return;

  for (select WAUI_U_ID, WAUI_FOAF from DB.DBA.WA_USER_INFO) do
  {

  	uname := (select U_NAME from DB.DBA.SYS_USERS where U_ID = WAUI_U_ID);
  	if (not isnull (uname))
  	{
      visibility := WA_USER_VISIBILITY (uname);
      access := visibility[8];
      tmp := '';
      for (select interest from DB.DBA.WA_USER_INTERESTS (txt) (interest varchar) P where txt = WAUI_FOAF) do
      {
         tmp := tmp || interest || ';' || cast (access as varchar) || '\n';
      }
      WA_USER_EDIT (uname, 'WAUI_FOAF', tmp);
    }
  }

  registry_set ('WA_FOAF_UPGRADE', 'done');
}
;
WA_FOAF_UPGRADE ()
;

create procedure wa_get_new_url (in app_type varchar, in asid varchar, in arealm varchar)
{
  if (isnull(asid) or isnull(arealm) or asid = '' or arealm = '')
    return sprintf ('window.open(''index_inst.vspx?wa_name=%s'', ''_self'');', app_type);
  else
   return sprintf ('window.open(''new_inst.vspx?wa_name=%s&sid=%s&realm=%s'', ''_self'');', app_type, asid, arealm);
}
;


create procedure wa_inst_url (in app_base_url varchar, in sid varchar, in realm varchar, in app varchar)
{
  declare ret varchar;
  ret :=  sprintf ('window.open(''%s?sid=%s&realm=%s'', ''_self'');', app_base_url, sid, realm);
  return ret;
}
;


create procedure wa_set_type ()
{
   declare _id, _mt, _ip integer;
   declare _inst, _atype varchar;
   for (select WAM_INST as winst, WAM_USER as wid, WAM_MEMBER_TYPE as wtype
          from WA_INSTANCE, WA_MEMBER
         where WAI_NAME = WAM_INST and (isnull(WAM_APP_TYPE) or WAM_APP_TYPE = '')) do
   {
     _inst := winst;
     _atype := wa_get_type_from_name(_inst);
     _id := wid;
     _mt := wtype;
     update DB.DBA.WA_MEMBER
       set WAM_APP_TYPE = _atype
     where WAM_USER = _id
       and WAM_INST = _inst
       and WAM_MEMBER_TYPE = _mt;
   };

}
;


create procedure wa_get_type_from_name (in _name varchar)
{
  declare _wtype varchar;

  _wtype := '';
  for (select WAI_TYPE_NAME as wtype from WA_INSTANCE where WAI_NAME = _name) do
  {
    _wtype := wtype;
    return _wtype;
  };
  return '';


  if (strstr (_name, 'Wiki') is not NULL) return 1;
  else if (strstr (_name, 'eNews2')) return 2;
  else if (strstr (_name, 'oDrive')) return 3;
  else if (strstr (_name, 'oMail')) return 5;
  else if (strstr (_name, 'Blog') is not NULL) return 7;

  --else if (strstr (_name, 'oGallery')) return 4;

  return 0;
}
;
wa_wa_member_upgrade ()
;

create procedure wa_keywords_sift (inout pKW any, in pSiftList any,in pPrefix any,in pOut integer := 0)
{
  declare i,j integer;
  declare sKWName varchar;
  declare R any;
  --
  if (isstring(pSiftList)) pSiftList := vector(pSiftList);
  --
  R := vector();
  i := 0;
  while (i < (length(pKW))) {
    if (pPrefix = '' or locate(pPrefix,pKW[i]) = 1) sKWName := pKW[i]; else sKWName := concat(pPrefix,pKW[i]);
    -- Search current keyword in the sift list
    j := 0;
    while (j >= 0 and j < length(pSiftList)) if (sKWName like concat(pPrefix,pSiftList[j])) j := - 1; else j := j + 1;
    if (j = -1) {
      -- Keyword found. Put it into result if pOut is zero
      if (pOut = 0) R := vector_concat(R,vector(pKW[i],pKW[i + 1]));
    }
    else {
      -- Keyword is not found. Put it into result if pOut is not zero
      if (pOut <> 0) R := vector_concat(R,vector(pKW[i],pKW[i + 1]));
    }
    i := i + 2;
  }
  return R;
}
;

create procedure wa_str2words (in pString varchar)
{
  declare iOffSet integer;
  declare aRes, aRegExpVec any;

  aRes := vector();

  iOffSet := 0;
  while(iOffSet < length(pString)) {
    aRegExpVec := regexp_parse('[^\\W]*',pString, iOffSet);
    if (length(aRegExpVec) <> 2) signal('22023','Parse problem');
    if (aRegExpVec[0] <> aRegExpVec[1]) {
      aRes := vector_concat(aRes,vector(subseq(pString,aRegExpVec[0],aRegExpVec[1])));
      iOffset := aRegExpVec[1];
    } else iOffSet := iOffSet + 1;
  };
  return aRes;
}
;

create procedure wa_get_keywords (in pArray any,in pWord varchar){
  return wa_keywords_sift(pArray,vector(pWord),'',0);
}
;

create procedure wa_execute_search (in uid integer, in aquery any, in pClassSet any := null)
  {

    declare sCnd,sUnion varchar;
    declare sCharSet varchar;
    declare aClassSet, aWords,aRes any;

    aRes := '';
    sCnd := '';
    aWords := vector();
    aWords := wa_str2words(aquery);

    sUnion := ' and ';

    foreach(varchar sWord in aWords)do{
     sCnd := '"' || sWord || '"';
     --else sCnd := sCnd || sUnion || '"' || sWord || '"';
    };

    if  (length(pClassSet) = 0) aClassSet := vector_concat(vector('Person'),vector('Tags'));
    else aClassSet := pClassSet;

    --if (pScope = 1) sCnd := sprintf('( ORG%dID and OWNER%dID and (%s) )',pOrgID,pUserID,sCnd);
    --else sCnd := sprintf('( ORG%dID and (%s) )',pOrgID,sCnd);

    --XSYS_DBG.debug1('  ' || XSYS_DBG.benchmark('execute_search - where compiled ','n','search_exec'));

    foreach(varchar sClass in aClassSet)do
      execute_fetch(uid,sClass,aRes);

    return aRes;
}
;


create procedure wa_tags2vector (inout tags varchar)
{
  return split_and_decode(trim(tags, ','), 0, '\0\0,');
}
;

create procedure wa_tags2search (in tags varchar)
{
  declare S varchar;
  declare V any;

  S := '';
  V := wa_tags2vector(tags);
  foreach (any tag in V) do
    S := concat(S, ' ', replace (trim(tag), ' ', '_'));
  return FTI_MAKE_SEARCH_STRING(trim(S, ','));
}
;

-- user is dba checks
create procedure wa_user_is_dba (in uname varchar, in ugroup int) returns int
{
  if (ugroup is null)
    ugroup := -1;
  if (uname = 'dba' or uname = 'dav' or ugroup = 0)
    return 1;
  return 0;
}
;


create procedure
WA_TEMPLATE_COPY (in path varchar,
                  in destination varchar,
                  in uid2 any,
                  in overwrite integer,
		  in file_list any := null)
{
  declare pwd1 any;
  declare _res_id int;
  declare copy_list any;

  pwd1 := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from DB.DBA.SYS_USERS where U_NAME = 'dav');
  DAV_MAKE_DIR (destination, uid2, http_admin_gid (), '111101100N');

  copy_list := DB.DBA.DAV_DIR_LIST (path, 0, 'dav', pwd1);
  foreach (any entry in copy_list) do
    {
      declare dest_file any;
      dest_file := entry[10];
      if (regexp_match (file_list, dest_file) is not null)
        {
          --dbg_obj_print ('path||dest_file', path||dest_file, ' to ', destination||dest_file);
          _res_id := DB.DBA.DAV_COPY(path||dest_file, destination||dest_file,
          		overwrite, '110101100N', uid2, 'administrators', 'dav', pwd1);
          if (_res_id < 0)
            signal ('42000', 'Internal error: Cannot copy WebDAV resource : ' || dest_file);
          --dbg_obj_print (_res_id);
        }
    }
}
;


create procedure WA_MEMBER_URLS (in uid int)
{
  declare _WAI_NAME, HP_HOST, HP_LPATH, HP_LISTEN_HOST varchar;
  declare lpath, ppath, DEF_PAGE varchar;
  declare pos, IS_DEFAULT, _WAI_ID int;

  result_names (_WAI_NAME, HP_HOST, HP_LPATH, HP_LISTEN_HOST, IS_DEFAULT, DEF_PAGE, _WAI_ID);

  for select WAM_HOME_PAGE, WAM_INST, WAI_ID, WAM_APP_TYPE from WA_MEMBER, WA_INSTANCE
    where WAM_INST = WAI_NAME and WAM_USER = uid and WAM_MEMBER_TYPE = 1 do
    {
      pos := strrchr (WAM_HOME_PAGE, '/');
      DEF_PAGE := null;
      if (pos is not null)
	{
          lpath := subseq (WAM_HOME_PAGE, 0, pos);
	  DEF_PAGE := subseq (WAM_HOME_PAGE, pos+1);
	}
      else
        lpath := WAM_HOME_PAGE;
      if (not length (DEF_PAGE) and (WAM_APP_TYPE <> 'oWiki'))
	DEF_PAGE := 'index.vspx';
      if (length (lpath) > 1)
        lpath := rtrim (lpath, '/');
      result (WAM_INST, '*ini*', lpath, '*ini*', 1, DEF_PAGE, WAI_ID);
    }
  for select WAI_ID, WAI_NAME, VH_HOST, VH_LPATH, VH_LISTEN_HOST, VH_PAGE, WAM_HOME_PAGE from WA_VIRTUAL_HOSTS, WA_INSTANCE, WA_MEMBER
    where WAI_ID = VH_INST and WAM_INST = WAI_NAME and WAM_USER = uid and WAM_MEMBER_TYPE = 1 do
      {
	if (rtrim (WAM_HOME_PAGE, '/') <> VH_LPATH or VH_HOST <> '*ini*' or VH_LISTEN_HOST <> '*ini*')
	  result (WAI_NAME, VH_HOST, VH_LPATH, VH_LISTEN_HOST, 0, VH_PAGE, WAI_ID);
      }
};

create procedure WA_HOSTS_INIT ()
{
  declare lpath, ppath, def_page varchar;
  declare pos int;

  if (registry_get ('wa_hosts_updated') = '1')
    return;

  for select WAM_HOME_PAGE, WAI_ID, WAM_APP_TYPE from WA_MEMBER, WA_INSTANCE where
    	WAM_INST = WAI_NAME and WAM_APP_TYPE = 'WEBLOG2' and WAM_MEMBER_TYPE = 1 do
    {
      pos := strrchr (WAM_HOME_PAGE, '/');
      def_page := 'index.vspx';
      if (pos is not null)
	{
	  lpath := subseq (WAM_HOME_PAGE, 0, pos);
	  def_page := subseq (WAM_HOME_PAGE, pos+1);
	}
      else
	lpath := WAM_HOME_PAGE;

      if (not length (def_page))
	def_page := 'index.vspx';
      ppath := (select HP_PPATH from HTTP_PATH where HP_LPATH= lpath and HP_HOST = '*ini*' and HP_LISTEN_HOST= '*ini*');
      for select HP_HOST as vhost, HP_LPATH as lpath1, HP_LISTEN_HOST as lhost from HTTP_PATH where HP_PPATH = ppath do
	{
	  if (not (vhost = '*ini*' and lhost = '*ini*' and lpath1 = lpath))
	    {
              insert replacing WA_VIRTUAL_HOSTS (VH_INST,VH_HOST,VH_LISTEN_HOST,VH_LPATH, VH_PAGE)
		  values (WAI_ID, vhost, lhost, lpath1, def_page);
	    }
	}
    }
--  registry_set ('wa_home_title', 'ODS Home');
  registry_set ('wa_hosts_updated', '1');
};

WA_HOSTS_INIT ();

create procedure WA_REG_INIT ()
{
  if (registry_get ('wa_reg_updated') = '1')
    return;

  if (not isstring (registry_get ('wa_home_title')))
    registry_set ('wa_home_title', 'ODS Home');
  registry_set ('wa_home_link', '/ods/');

  registry_set ('wa_reg_updated', '1');
};

WA_REG_INIT ();

create procedure WA_LINK (in add_host int := 0, in url varchar := null)
{
  declare wa_url, ret varchar;
  wa_url := registry_get ('wa_home_link');

  if (add_host)
    {
      declare hf any;
      hf := WS.WS.PARSE_URI (wa_url);
      if (hf[1] = '')
	{
	  hf[0] := 'http';
  	  hf[1] := wa_cname ();
	  wa_url := vspx_uri_compose (hf);
	}
    }

  if (length (url) = 0)
    {
      ret := wa_url;
    }
  else
    {
      ret := WS.WS.EXPAND_URL (wa_url, url);
    }
    -- dbg_obj_print ('', ret);
  return ret;
};

create procedure WA_HOST_NORMALIZE (inout vhost varchar, inout lhost varchar)
{
  declare ssl_port, lport, varr any;
  lhost := replace (lhost, '0.0.0.0', '');

  ssl_port := coalesce (server_https_port (), '');
  if (isstring (server_http_port ()))
    {
      varr := split_and_decode (
         case
           when vhost = '*ini*' then server_http_port ()
           when vhost = '*sslini*' then ssl_port
           else vhost
         end
       , 0, ':=:');
      lport := split_and_decode (
         case
           when lhost = '*ini*' then server_http_port ()
           when lhost = '*sslini*' then ssl_port
           else lhost
         end
       , 0, ':=:');

      if (__tag (varr) = 193 and length (varr) > 1)
	vhost := varr[0];

      if (__tag (lport) = 193 and length (lport) > 1)
	lport := aref (lport, 1);
      else if (lhost = '*ini*')
	lport := server_http_port ();
      else if (lhost = '*sslini*')
	lport := ssl_port;
      else if (atoi (lhost))
	lport := lhost;
      else
	lport := '80';
    }
  else
    lport := null;

  if (lport = server_http_port () and lhost <> '*ini*')
    lhost := '*ini*';
  else if (lport = ssl_port and lhost <> '*sslini*')
    lhost := '*sslini*';
}
;

create procedure WA_SET_APP_URL
	(in app_id any,
    	in lpath any,
	in prefix any := null,
	in domain any := '\173Default Domain\175',
	in old_path any := null,
	in old_host any := null,
	in old_ip any := null,
	in silent int := 0
	)
{
   declare inst web_app;
   declare phys_path, def_lpath, def_page any;
   declare pos any;
   declare _lhost, _vhost any;
   declare arr, port any;
   declare len, i, ix integer;
   declare cur_add_url, add_url_arr any;
   declare vd_pars any;

   declare vd_is_dav, vd_is_browse int;
   declare vd_opts, h any;
   declare vd_user, vd_pp, vd_auth varchar;

   --dbg_obj_print ('WA_SET_APP_URL',app_id,lpath,prefix,domain,old_path,old_host,old_ip,silent);

   if (domain is null)
     domain := '{Default Domain}';

   if (length(lpath) = 0)
     lpath := '/';

   lpath := trim(lpath, '/\\. ');
   lpath := '/' || lpath;

   prefix := trim(prefix, '/\\. ');

   declare exit handler for not found {
     rollback work;
     signal ('22023', sprintf ('No such application instance id=%d', app_id));
   };
   select WAI_INST into inst from WA_INSTANCE where WAI_ID = app_id;

   vd_pars := null;
   h := udt_implements_method (inst, fix_identifier_case ('wa_vhost_options'));
   if (h)
     vd_pars := call (h) (inst);
   if (vd_pars is not null)
     {
       phys_path := vd_pars[0];
       def_page :=  vd_pars[1];
       vd_user :=   vd_pars[2];
       vd_is_browse :=vd_pars[3];
       vd_is_dav := vd_pars[4];
       vd_opts :=   vd_pars[5];
       vd_pp :=     vd_pars[6];
       vd_auth :=   vd_pars[7];
       goto do_the_dirs;
     }

   vd_user := 'dba';
   vd_is_browse := 0;
   vd_is_dav := 1;
   vd_opts := vector ();
   vd_pp := null;
   vd_auth := null;

   def_lpath := inst.wa_home_url();
   --dbg_obj_print ('inst.wa_home_url', def_lpath);
   pos := 0;

   if (def_lpath[length (def_lpath) - 1] <> ascii ('/'))
     pos := strrchr (def_lpath, '/');
   def_page := null;
   if (pos is not null and pos > 1)
     {
       def_page := subseq (def_lpath, pos+1);
       def_lpath := subseq (def_lpath, 0, pos);
     }
   if (length (def_lpath) > 1)
     def_lpath := rtrim (def_lpath, '/');
   if (length (def_page) = 0)
     def_page := 'index.vspx';

   phys_path := (select HP_PPATH from HTTP_PATH where HP_LPATH = def_lpath and HP_HOST = '*ini*' and HP_LISTEN_HOST = '*ini*');

   do_the_dirs:

   if (domain = '{Default Domain}')
     {
       _lhost := '*ini*';
       _vhost := '*ini*';
       if (length (prefix))
	 signal ('22023', 'Can not make a subdomain of the default domain');
       if (not length (lpath))
	 signal ('22023', 'The root of default domain is prohibited');
     }
   else if (domain = '{Default HTTPS}')
     {
       if (server_https_port() is null)
	 return;
       _lhost := '*sslini*';
       _vhost := '*sslini*';
       if (length (prefix))
	 signal ('22023', 'Can not make a subdomain of the default domain');
       if (not length (lpath))
	 signal ('22023', 'The root of default domain is prohibited');
     }
   else if (domain = '{My Own Domain}')
     {
       declare port1, port2, tmp, c_host varchar;

       _vhost := prefix;
       _lhost := http_map_get ('lhost');

       port1 := null;
       port2 := null;

       c_host := HTTP_GET_HOST ();

       tmp := split_and_decode (_vhost, 0, '\0\0:');
       if (length (tmp) = 2)
	 port1 := tmp[1];

       if (not length (tmp))
         signal ('22023', 'No own domain was specified');

       if (_lhost = '*ini*')
	 {
	   tmp := split_and_decode (sys_connected_server_address (), 0, '\0\0:');
	 }
       else
         {
           tmp := split_and_decode (_lhost, 0, '\0\0:');
	 }

       if (length (tmp) = 2)
	 port2 := tmp[1];
       else
	 port2 := '80';

       if (port1 is not null and port1 <> port2)
         signal ('22023', 'Please provide a valid PORT value. If you are not sure which it is, just not specify the port number.');
       --  signal ('22023', 'The specified port must be same as one which is currently in use. If you are not sure which is it, just not specify the port number.');

       if (port1 is null)
	 _vhost := _vhost || ':' || port2;

       if (c_host = _vhost and lpath = '/')
         signal ('22023', 'The domain specified matches the host used to access the application configuration pages.');

-- checks if user's custom domain overwrites default URIQA host

       declare uriqa_defaulthost,userdefined_host any;
       uriqa_defaulthost:=split_and_decode (cfg_item_value (virtuoso_ini_path (), 'URIQA', 'DefaultHost'), 0, '\0\0:');
       userdefined_host:=split_and_decode (_vhost, 0, '\0\0:');
       if(uriqa_defaulthost[0]=userdefined_host[0])
       {
         signal ('22023', 'The domain specified as "My own domain" matches the default domain. Please use "Default domain".');

       }

       if(locate('localhost',userdefined_host[0]))
       {
         signal ('22023', 'The host domain "localhost" is not valid.');

       }

       if(strchr (userdefined_host[0], '.') is null)
       {
         signal ('22023', 'The host domain value is not valid. Please ensure you have ".". For instance: xxx.yyy');

       }

       if(length(tcpip_gethostbyname (userdefined_host[0])) =0)
       {
         signal ('22023', 'The host domain value is not valid. There is no DNS record for it.');

       }

     }
   else
     {
       if (length (prefix))
	 _vhost := concat (prefix, '.', domain);
       else
         _vhost := domain;
       declare exit handler for not found {
	   if (silent)
	     return;
	   rollback work;
	   signal ('22023', sprintf ('No such wa domain %s', domain));
	 };
       select WD_LISTEN_HOST into _lhost from WA_DOMAINS where
	   WD_DOMAIN = domain and WD_LISTEN_HOST is not null;
     }

   arr := split_and_decode (_lhost, 0, '\0\0:');
   port := '';
   if (length (arr) = 2)
     port := arr[1];
   else if (length (arr) = 1)
     ;
   else
     signal ('22023', 'Cannot get the port number');

   --if (length (port))
   --  _vhost := _vhost || ':' || port;

   --dbg_obj_print ('vhost=', _vhost);
   --dbg_obj_print ('lhost=', _lhost);
   --dbg_obj_print ('lpath=', lpath);
   --dbg_obj_print ('def_lpath=', def_lpath);
   --dbg_obj_print ('ppath=', phys_path);
   --dbg_obj_print ('def_page=', def_page);

   if (phys_path is null)
     {
       signal ('22023', 'System cannot find the physical location of your application');
     }

   -- No modifications are needed
   if (old_host = _vhost and old_path = lpath and old_ip = _lhost)
     return;

   WA_HOST_NORMALIZE (_vhost, _lhost);
   if (exists(select 1 from HTTP_PATH where HP_HOST= _vhost and HP_LISTEN_HOST= _lhost and HP_LPATH = lpath))
     {
       if (silent)
	         return;
       signal ('42000', 'This site already exists');
     }

   declare _vhost_no_port any;
   _vhost_no_port:=split_and_decode (_vhost, 0, '\0\0:');
   _vhost_no_port:=_vhost_no_port[0];

   if(_vhost_no_port<>_vhost)
   {
     if (exists(select 1 from HTTP_PATH where HP_HOST= _vhost_no_port and HP_LISTEN_HOST= _lhost and HP_LPATH = lpath))
       {
         if (silent)
	           return;
         signal ('42000', 'This site already exists');
       }
   };

  --! dirty hack
  connection_set ('vhost', _vhost);
  connection_set ('port', port);

  -- Application additional URL
  add_url_arr := make_array (2, 'any');
  h := udt_implements_method (inst, fix_identifier_case ('wa_addition_urls'));
  if (h)
	add_url_arr [0] := call (h) (inst);
  h := udt_implements_method (inst, fix_identifier_case ('wa_addition_instance_urls'));
  if (h)
	add_url_arr [1] := call (h) (inst, lpath);

--  dbg_obj_print (inst, add_url_arr);
  ix := 0;

  foreach (any add_url in add_url_arr) do
    {
      len := length (add_url);
      i := 0;
      while (i < len and (ix = 1 or _lhost <> '*ini*'))
	{
	  cur_add_url := add_url[i];
	  if (ix = 1 and old_host is not null and old_ip is not null)
	    {
	      VHOST_REMOVE (lpath=>cur_add_url[2], vhost=>old_host, lhost=>old_ip);
	    }
	  if (not exists (select 1 from HTTP_PATH
		where HP_HOST = _vhost and HP_LISTEN_HOST = _lhost and HP_LPATH = cur_add_url[2]))
	    {
	      VHOST_DEFINE(
		  vhost=>_vhost,
		  lhost=>_lhost,
		  lpath=>cur_add_url[2],
		  ppath=>cur_add_url[3],
		  is_dav=>cur_add_url[4],
		  is_brws=>cur_add_url[5],
		  def_page=>cur_add_url[6],
		  auth_fn=>cur_add_url[7],
		  realm=>cur_add_url[8],
		  ppr_fn=>cur_add_url[9],
		  vsp_user=>cur_add_url[10],
		  soap_user=>cur_add_url[11],
		  sec=>cur_add_url[12],
		  ses_vars=>cur_add_url[13],
		  soap_opts=>cur_add_url[14],
		  auth_opts=>cur_add_url[15],
		  opts=>cur_add_url[16],
		  is_default_host=>cur_add_url[17]);
	    }
	    i := i + 1;
	}
      ix := ix + 1;
    }
  -- Home URL
  if (old_path is not null)
    {
      VHOST_REMOVE (lpath=>old_path, vhost=>old_host, lhost=>old_ip);
    }
  -- Check if its not already there
  if (not exists (select 1 from HTTP_PATH where HP_HOST = _vhost and HP_LISTEN_HOST = _lhost and HP_LPATH = lpath))
    {
      VHOST_DEFINE (
	      vhost=>_vhost,
	      lhost=>_lhost,
	      lpath=>lpath,
	      ppath=>phys_path,
	      is_dav=>vd_is_dav,
	      is_brws=>vd_is_browse,
	      vsp_user=>vd_user,
	      ppr_fn=>vd_pp,
	      auth_fn=>vd_auth,
	      opts=>vd_opts,
	      def_page=>def_page);
      pos := strrchr (_vhost, ':');
      -- no port info anymore in the vhost
      if (pos is not null)
	_vhost := subseq (_vhost, 0, pos);
      insert replacing WA_VIRTUAL_HOSTS (VH_INST,VH_HOST,VH_LISTEN_HOST,VH_LPATH, VH_PAGE)
	  values (app_id, _vhost, _lhost, lpath, def_page);
    }
  else if (not silent)
    {
      signal ('22023', 'This URL is already used by another application, please use another domain or path');
    }
};


create procedure WA_GET_APP_NAME (in app varchar)
{
  declare lab, arr varchar;
  lab := registry_get ('_wa_label_' || app);

  if (isstring (lab) and length (lab))
    return lab;

  if (app = 'WEBLOG2')
    return 'Weblog';
  else if (app = 'eNews2')
    return 'Feeds';
  else if (app = 'oWiki')
    return 'Wiki';
  else if (app = 'oDrive')
    return 'Briefcase';
  else if (app = 'oMail')
    return 'Mail';
  else if (app = 'oGallery')
    return 'Gallery';
  else if (app = 'xDiaspora' or app = 'Community')
    return 'Community';
  else if (app = 'Bookmark')
    return 'Bookmarks';
  else if (app = 'nntpf')
    return 'Discussion';
  else if (app = 'polls')
    return 'Polls';
  else if (app = 'addressbook')
    return 'AddressBook';
  else if (app = 'calendar')
    return 'Calendar';
  else if (app = 'IM')
    return 'InstantMessenger';
  else
    return app;
};

create procedure WA_GET_MFORM_APP_NAME (in app varchar)
{
  declare lab, arr varchar;
  lab := registry_get ('_wa_mform_label_' || app);

  if (isstring (lab) and length (lab))
    return lab;

  if (app = 'WEBLOG2')
    return 'Weblogs';
  else if (app = 'eNews2')
    return 'Feeds';
  else if (app = 'oWiki')
    return 'Wikis';
  else if (app = 'oDrive')
    return 'Briefcases';
  else if (app = 'oMail')
    return 'Mails';
  else if (app = 'oGallery')
    return 'Galleries';
  else if (app = 'xDiaspora' or app = 'Community')
    return 'Communities';
  else if (app = 'Bookmark')
    return 'Bookmarks';
  else if (app = 'nntpf')
    return 'Discussions';
  else if (app = 'polls')
    return 'Polls';
  else if (app = 'AddressBook')
    return 'AddressBooks';
  else if (app = 'Calendar')
    return 'Calendars';
  else if (app = 'IM')
    return 'InstantMessenger';
  else
    return app;
};

create procedure wa_inst_type_icon (in app varchar)
{
  if (app = 'WEBLOG2')
    return 'ods_weblog';
  else if (app = 'eNews2')
    return 'ods_feeds';
  else if (app = 'oWiki')
    return 'ods_wiki';
  else if (app = 'oDrive')
    return 'ods_briefcase';
  else if (app = 'oMail')
    return 'ods_mail';
  else if (app = 'oGallery')
    return 'ods_gallery';
  else if (app = 'xDiaspora' or app = 'Community')
    return 'go';
  else if (app = 'bookmark')
    return 'go';
  else
    return 'go';
};

create function WA_MAKE_THUMBNAIL_1 (inout image any, in width integer := 192, in height integer := 150)
returns any
{
  if (__proc_exists ('IM ThumbnailImageBlob', 2))
    return "IM ThumbnailImageBlob" (image, length (image), width, height, 1);
  else
    return NULL;
}
;

create procedure wa_get_users (in mask any := '%', in ord any := '', in seq any := 'asc', in what any := 'all')
{
  declare sql, dta, mdta, rc, h, tmp, pred any;

  declare U_NAME, U_FULL_NAME, U_LOGIN_TIME, U_EDIT_TIME, U_ACCOUNT_DISABLED, U_ID any;

  result_names (U_NAME, U_FULL_NAME, U_ACCOUNT_DISABLED, U_ID);
  if (not isstring (mask))
    mask := '%';
  pred := '';

  if (what = 'frozen')
    pred := ' and U_ACCOUNT_DISABLED = 1 ';
  if (what = 'active')
    pred := ' and U_ACCOUNT_DISABLED = 0 ';

  sql := 'select U_NAME, coalesce (U_FULL_NAME, \'\') as U_FULL_NAME, U_ACCOUNT_DISABLED, U_ID ' ||
         ' from SYS_USERS, WA_USER_INFO where U_ID = WAUI_U_ID and U_DAV_ENABLE = 1 and U_IS_ROLE = 0 ' ||
	 pred ||
	 'and (upper (U_NAME) like upper (?))';


  if (length (ord))
    {
      tmp := case ord when 'name' then 'U_NAME' when 'fullname' then 'U_FULL_NAME' else '' end;
      if (tmp <> '')
	{
	  ord := 'order by lower(' || tmp || ') ' || seq;
	  sql := sql || ord;
	}
    }
  rc := exec (sql, null, null, vector (mask), 0, null, null, h);
  while (0 = exec_next (h, null, null, dta))
    exec_result (dta);
  exec_close (h);
}
;

wa_exec_no_error('create procedure view WA_SYS_USERS as wa_get_users (mask, ord, seq, what) (U_NAME varchar, U_FULL_NAME varchar, U_ACCOUNT_DISABLED int, U_ID int)');


/* similar to the blog ones. when blog is installed these are replaced */
create procedure WA_XPATH_GET_HTTP_URL ()
{
  declare host, path, qstr, conn any;

  conn := connection_get ('Atom_Self_URI');

  if (conn is not null)
    return conn;

  host := HTTP_GET_HOST ();
  path := http_path ();
  qstr := http_request_get ('QUERY_STRING');
  if (length (qstr))
    qstr := '?' || qstr;
  return 'http://' || host || path || qstr;
};

create procedure WA_XPATH_EXPAND_URL (in url varchar)
{
  declare base, ret varchar;
  --dbg_obj_print ('url:',url);
  base := HTTP_URL_HANDLER ();
  ret := WS.WS.EXPAND_URL (base, url);
  return ret;
};

grant execute on WA_XPATH_GET_HTTP_URL to public;
grant execute on WA_XPATH_EXPAND_URL to public;
grant execute on WA_GET_HOST to public;

xpf_extension ('http://www.openlinksw.com/ods/:getHttpUrl', 'DB.DBA.WA_XPATH_GET_HTTP_URL');
xpf_extension ('http://www.openlinksw.com/ods/:getExpandUrl', 'DB.DBA.WA_XPATH_EXPAND_URL');
xpf_extension ('http://www.openlinksw.com/ods/:getHost', 'DB.DBA.WA_GET_HOST');


create procedure WA_RDF_ID (in str varchar)
{
  declare x any;
  x := regexp_replace (str, '[^[:alnum:]]', '_', 1, null);
  return x;
};

create procedure WA_APP_PREFIX (in app any)
{
  if (app = 'WEBLOG2')
    return 'BLOG';
  else if (app = 'eNews2')
    return 'ENEWS';
  else if (app = 'oWiki')
    return 'WIKI';
  else if (app = 'oDrive')
    return 'ODRIVE';
  else if (app = 'oMail')
    return 'MAIL';
  else if (app = 'oGallery')
    return 'OGALLERY';
  else if (app = 'xDiaspora' or app = 'Community')
    return 'COMMUNITY';
  else if (app = 'Bookmark')
    return 'BMK';
  else
    return app;

};

create procedure WA_APPS_INSTALLED ()
{
  declare ret any;
  ret := (select vector_agg (WA_APP_PREFIX (WAT_NAME)) from WA_TYPES);
  return vector_concat (ret, vector ('NNTPF'));
};


create procedure WA_MAIL_VALIDATE (in login any)
{
  declare U_NAME, dummy, rc, pkgs any;

  result_names (U_NAME);
  whenever not found goto nouser;
  SELECT u.U_NAME into dummy FROM WS.WS.SYS_DAV_USER u WHERE u.U_NAME = login AND U_ACCOUNT_DISABLED=0;
  result (dummy);
  return 1;

  nouser:

  pkgs := WA_APPS_INSTALLED ();

  foreach (any p in pkgs) do
    {
      declare p_name varchar;

      p_name := sprintf ('DB.DBA.%s_MAIL_VALIDATE', p);

      if (__proc_exists (p_name))
	{
	  rc := call (p_name) (login);
	  --dbg_printf ('Validated %s = %d', p_name, rc);
	  if (rc = 1)
	    return rc;
	}
    }
  return 0;
};

create procedure WA_NEW_MAIL (in _uid varchar, in _msg any, in _domain varchar := null)
{
  declare rc, pkgs any;
  pkgs := WA_APPS_INSTALLED ();

  foreach (any p in pkgs) do
    {
      declare p_name varchar;

      p_name := sprintf ('DB.DBA.%s_NEW_MAIL', p);

      if (__proc_exists (p_name))
	{
	  if (length (procedure_cols (p_name)) = 3)
	    rc := call (p_name) (_uid, _msg, _domain);
	  else
	    rc := call (p_name) (_uid, _msg);
	  --dbg_printf ('Storing %s = %d', p_name, rc);
	  if (rc = 1)
	    return rc;
	}
    }
  DB.DBA.NEW_MAIL (_uid, _msg);
  return 1;
};

-- NNTP procedures
--
create procedure NNTP_NEWS_MSG_ADD (in app varchar, in sql varchar)
{
  declare v any;
  declare x any;

-- potential unpredicted behaviour after VAD upgrade
--  x := registry_get ('__NNTP_NEWS_MSG_' || app);
--  if (isstring (x) and strstr (sql, x) is not null)
--    return;
  NNTP_NEWS_MSG_DEL (app);

  declare exit handler for not found return;

  select coalesce (V_TEXT, blob_to_string (V_EXT)) into v from SYS_VIEWS where V_NAME = 'DB.DBA.NEWS_MSG';
  v := v || ' union all ' || sql;

  declare state, message any;
  exec ('drop view DB.DBA.NEWS_MSG', state, message);
  exec (v, state, message);
  registry_set ('__NNTP_NEWS_MSG_' || app, sql);
};

create procedure NNTP_NEWS_MSG_DEL (in app varchar)
{
  declare v any;
  declare x any;

  x := registry_get ('__NNTP_NEWS_MSG_' || app);
  if (not isstring (x))
    return;

  declare exit handler for not found return;

  select coalesce (V_TEXT, blob_to_string (V_EXT)) into v from SYS_VIEWS where V_NAME = 'DB.DBA.NEWS_MSG';
  v := replace(v, ' union all ' || x, '');

  declare state, message any;
  exec ('drop view DB.DBA.NEWS_MSG', state, message);
  exec (v, state, message);
  registry_remove ('__NNTP_NEWS_MSG_' || app);
};



create procedure WA_GET_HTTP_URL ()
{
  declare host, path, qstr, conn any;

  conn := connection_get ('Atom_Self_URI');

  if (conn is not null)
    return conn;

  host := WA_GET_HOST ();
  path := http_path ();
  qstr := http_request_get ('QUERY_STRING');
  if (length (qstr))
    qstr := '?' || qstr;
  return 'http://' || host || path || qstr;
};


create procedure WS.WS.SYS_DAV_RES_RES_CONTENT_INDEX_HOOK (inout vtb any, inout r_id any)
{
-- so far hook function deals with wiki only
-- note, hook function can be called from batch mode so it must not rely on
-- trigger order
   declare exit handler for sqlstate '*' {
	--dbg_obj_princ (__SQL_STATE, ' ', __SQL_MESSAGE);
	resignal;
   };
   if(__proc_exists ('WS.WS.META_WIKI_HOOK'))
     {
         call ('WS.WS.META_WIKI_HOOK') (vtb, r_id);
     }
  return 0;
};

create procedure ODS.BAR._EXEC(in app_type varchar,in params any, in lines any){

  declare odshome_url,odsbar_filepath varchar;
  odshome_url:='';
  odsbar_filepath:='';

  odshome_url:=registry_get ('wa_home_link');
  odsbar_filepath:='';


  whenever not found goto nf;
  {
    select top 1 HP_PPATH into odsbar_filepath from DB.DBA.HTTP_PATH where HP_LPATH = rtrim(odshome_url, '/');
  }

  nf:
  if (length(odsbar_filepath)=0){
      odsbar_filepath:='./samples/wa/ods_bar.vspx';
   }else {
      odsbar_filepath:=odsbar_filepath||'ods_bar.vspx';
   }




         if(get_keyword('logout',params)='true' and length(get_keyword('sid',params))>0)
         {
                     delete from VSPX_SESSION where VS_SID = get_keyword('sid',params);

                     declare redirect_url varchar;
                     redirect_url:=odshome_url||'sfront.vspx';

                     http_rewrite ();
                     http_request_status ('HTTP/1.1 302 Found');
                     http_header (concat (http_header_get (), 'Location: ',redirect_url,'\r\n'));

                     return;
         };



  params := vector_concat(params, vector('app_type', app_type));
  DB.DBA.vspx_dispatch(odsbar_filepath, odshome_url, params, lines, null, 0, 'DB', 'DBA');
  return http_get_string_output();

};

create procedure wa_make_url_from_vd (in host varchar, in lhost varchar, in path varchar)
{
  declare pos, port any;
  pos := strrchr (host, ':');
  if (pos is not null)
    host := subseq (host, 0, pos);
  pos := strrchr (lhost, ':');
  if (pos is not null)
    port := subseq (lhost, pos, length (lhost));
  else if (lhost = '*ini*')
    port := ':'||server_http_port ();
  else
    port := '';
  if (path like 'http://%')
    return rtrim(path, '/');
  else
    return sprintf ('http://%s%s%s/', host, port, rtrim(path, '/'));
};

-- NEW version of this procedure is stored in ods_api.sql and is called ODS_CREATE_NEW_APP_INST. The new version is exposed to SOAP.
create procedure
WA_CREATE_NEW_APP_INST (in app_type varchar, in inst_name varchar, in owner varchar, in model int := 1, in pub int := 0)
{
  declare inst web_app;
  declare ty, h, id any;

  select WAT_TYPE into ty from WA_TYPES where WAT_NAME = app_type;
  inst := __udt_instantiate_class (fix_identifier_case (ty), 0);
  inst.wa_name := inst_name;
  inst.wa_member_model := model;
  h := udt_implements_method (inst, 'wa_new_inst');
  id := call (h) (inst, owner);
  update WA_INSTANCE
         set WAI_MEMBER_MODEL = model,
             WAI_IS_PUBLIC = pub,
             WAI_MEMBERS_VISIBLE = 1,
             WAI_NAME = inst_name,
             WAI_DESCRIPTION = inst_name || ' Description'
       where WAI_ID = id;
};

------------------------------------------------------------------------------------------------------
create procedure
wa_get_image_sizes(
  in image_id varchar)
{

  declare _content any;
  declare width,height integer;

  declare exit handler for sqlstate '*' {
    return vector(0,0);
  };

  select blob_to_string (RES_CONTENT) into _content from WS.WS.SYS_DAV_RES where RES_ID= image_id;

  -- params: content, length of content, number of columns, number of rows
  width := "IM GetImageBlobWidth" (_content, length(_content));
  height := "IM GetImageBlobHeight" (_content, length(_content));

  return vector(width,height);
}
;
------------------------------------------------------------------------------------------------------
create procedure wa_make_thumbnail(
  in sid varchar,
  in realm varchar,
  in image_id varchar,
  in width     integer,
  in height    integer,
  out image_type varchar)
{

   declare image_name,rights varchar;
   declare curr_user_id, owner_id integer;

   image_type:='';

   curr_user_id:=-1;

   whenever not found goto not_found;
   select U.U_ID
     into curr_user_id
    from DB.DBA.VSPX_SESSION S,WS.WS.SYS_DAV_USER U
   where S.VS_REALM = realm
     and S.VS_SID   = sid
     and S.VS_UID   = U.U_NAME;

   not_found:

   select RES_NAME,RES_OWNER,RES_PERMS,RES_TYPE into image_name,owner_id,rights,image_type from WS.WS.SYS_DAV_RES where RES_ID= image_id;

   if(not(owner_id = curr_user_id or substring(rights,7,1) = '1')){
      return '';
   }

  declare _content,image any;

  select blob_to_string (RES_CONTENT)
    into _content
    from WS.WS.SYS_DAV_RES
   where RES_ID= image_id;

  if(length(_content) = 0){
    return;
  }

  declare exit handler for sqlstate '*' {
                                          return _content;
                                        };
  -- params: content, length of content, number of columns, number of rows
  image := "IM ThumbnailImageBlob" (_content, length(_content), width, height,1);

  return image;

}
;
create procedure wa_get_app_dataspace (in type_name varchar)
{ declare arr any;
-- arr is array of type key, value; key is WA_TYPE and value is dataspace extension related to this type.
  arr:=vector('Community', 'community',
              'oDrive', 'briefcase',
              'WEBLOG2', 'weblog',
              'oGallery', 'photos',
              'eNews2', 'subscriptions',
              'oWiki', 'wiki',
              'oMail', 'mail',
              'eCRM', 'eCRM',
              'Bookmark', 'bookmark',
              'nntpf','',
              'Polls','polls',
              'AddressBook','addressbook',
              'Calendar','calendar',
              'IM','IM');

return get_keyword(type_name,arr,'');

}
;

-- this function returns the name of the package that has defined a specific WA_TYPE
-- it will make possible to check if package is installed on the system or the type is for custom applications that do not have package-build script.
-- it includes only the applications  created by OpenLink Software developers

create procedure wa_get_package_name (in type_name varchar)
{ declare arr any;
-- arr is array of type key, value; key is WA_TYPE and value is the name(not file name) of the package that contains this type.
  arr:=vector('Community', 'Community',

             'oDrive', 'oDrive',

             'WEBLOG2', 'blog2',

             'oGallery', 'oGallery',

             'eNews2', 'enews2',

             'oWiki', 'wiki',

             'oMail', 'oMail',

             'eCRM', 'eCRM',

             'Bookmark', 'bookmark',

             'nntpf','Discussion',

             'Polls','Polls',

             'AddressBook','AddressBook',

             'Calendar','Calendar',

             'IM','IM');

return get_keyword(type_name,arr,'');


}
;
-- this function is looking for all WA_TYPE that are not defined as complete ODS application type.
-- We suppose that developer has defined it's custom application type with minimum methods to correspond to ODS Framework.
-- That will not give full functionality to this application type but will include it in navigation bar of ODS and will make ODS framework to know defined application home.
-- in order to be compatible UDT should have at least wa_home_url and get_options methods.

create procedure wa_get_custom_app_options ()
{
declare res any;
res:=vector();
for select WAT_NAME,WAT_TYPE from DB.DBA.WA_TYPES do
{
  if(length(wa_get_package_name(WAT_NAME))=0)
  {
    declare _inst db.dba.web_app;
    _inst:=__udt_instantiate_class (fix_identifier_case (WAT_TYPE), 0);

    declare _options any;
    declare _url varchar;
    declare _show_logged,_show_not_logged integer;

    _show_logged     :=0;
    _show_not_logged :=0;

    declare h any;

    h:=udt_implements_method (_inst, 'get_options');

    if(h<>0)
      _options := call(h) (vector());
    else goto _skip;

    h:=udt_implements_method (_inst, 'wa_home_url');

    if(h<>0)
      _url := call(h) (vector());
    else goto _skip;


    if(isarray(_options) )
    {
      _show_logged     :=get_keyword('show_logged',_options,0);
      _show_not_logged :=get_keyword('show_not_logged',_options,0);
    }

    res:=vector_concat(res,vector(vector('name',WAT_NAME,'url',_url,'show_logged',_show_logged,'show_not_logged',_show_not_logged)));
     _skip:;
  }

}
return res;
}
;

create procedure wa_get_user_sharedres_count
( in user_id integer
)
{
 declare shared_res_count integer;

 shared_res_count:=0;

 for
  select AI_PARENT_ID,AI_PARENT_TYPE
   from WS.WS.SYS_DAV_ACL_INVERSE
   join WS.WS.SYS_DAV_ACL_GRANTS on GI_SUB = AI_GRANTEE_ID
  where AI_FLAG = 'G'
        and GI_SUPER = user_id
 do
 {
  if(AI_PARENT_TYPE='R')
     shared_res_count:=shared_res_count+1;
  else
  {
    declare _ACL,_colACL any;
    declare _res_ACL_type integer;

    _res_ACL_type:=0;

    declare exit handler for sqlstate '*' {goto _skip_currcol;};
    select COL_ACL into _colACL from WS.WS.SYS_DAV_COL where COL_ID=AI_PARENT_ID;

   _ACL := WS.WS.ACL_PARSE(_colACL, '012', 0);

    foreach (any _ACL_row in _ACL) do
    {
      if(_ACL_row[0]=user_id)
        _res_ACL_type:=_ACL_row[2];
    }

    if (_res_ACL_type>0)
      shared_res_count:=shared_res_count+wa_get_col_allres_count(AI_PARENT_ID);
--    else
--      shared_res_count:=shared_res_count+1;

    _skip_currcol:;

   }

 }

 return  shared_res_count;

}
;
create procedure wa_get_col_allres_count
(
  in _col_id integer
)
{  declare _res_count integer;

   _res_count:=0;

 declare exit handler for sqlstate '*'{goto skip_res_count;};
 select count(RES_ID) into _res_count from WS.WS.SYS_DAV_RES where RES_COL = _col_id;

skip_res_count:;

 for
  select COL_ID from WS.WS.SYS_DAV_COL where COL_PARENT = _col_id
 do
 {
  _res_count:=_res_count+wa_get_col_allres_count(COL_ID);
 }

 return _res_count;

}
;

create procedure wa_users_rdf_data_det_upgrade ()
{
  declare det_name varchar;
  for select U_NAME from SYS_USERS, WA_USER_INFO where U_ID = WAUI_U_ID do
    {
      {
        det_name := sprintf ('/DAV/home/%s/RDFData/', U_NAME);
	declare exit handler for sqlstate '*' {
	  rollback work;
	  goto next_user;
        };
        if (DAV_SEARCH_ID (det_name, 'C') < 0)
          {
	    "RDFData_MAKE_DET_COL" (det_name, NULL, NULL);
	    commit work;
	  }
      }
      next_user:;
    }
}
;

create procedure wa_identity_dstype (in _identity any)
{
  declare dsname varchar;
  declare _is_org integer;

  if(isinteger(_identity))
    _is_org:=(select WAUI_IS_ORG from DB.DBA.WA_USER_INFO where WAUI_U_ID=_identity);
  else
    _is_org:=(select WAUI_IS_ORG from DB.DBA.WA_USER_INFO, DB.DBA.SYS_USERS where WAUI_U_ID=U_ID and U_NAME=_identity);


  if(_is_org=1)
     dsname:='organization';
  else
     dsname:='person';

  return dsname;

}
;

create procedure ODS.WA.ods_apps ()
{
  return vector (
                 vector ('Community'),
                 vector ('oDrive'),
                 vector ('WEBLOG2'),
                 vector ('oGallery'),
                 vector ('eNews2'),
                 vector ('oWiki'),
                 vector ('oMail'),
                 vector ('eCRM'),
                 vector ('Bookmark'),
                 vector ('Polls'),
                 vector ('AddressBook'),
                 vector ('Calendar'),
                 vector ('IM')
                );
}
;

create procedure ODS.WA.wa_order_rs (
  in V any)
{

  declare i integer;
  declare arr_all, tmp any;

  declare c0 varchar;
  declare c1, c2 integer;

  result_names (c0, c1, c2);

  i := 1;
  foreach (any app_type in V) do {
    for (select WAT_NAME from DB.DBA.WA_TYPES where WAT_NAME = app_type[0]) do {
      tmp := cast (registry_get ('_wa_order_' || WAT_NAME) as integer);
      if (tmp = 0)
        tmp := 100;
      result (WAT_NAME, i, tmp);
      i := i + 1;
    }
  }
}
;

create procedure ODS.WA.wa_order_vector (
  in V any)
{
  declare N integer;
  declare T any;

  T := vector ();
  for (select rs.*
         from ODS.WA.wa_order_rs (rs0) (watName varchar, watDefault integer, watUser integer) rs
        where rs0 = V
        order by watUser, watDefault) do {
    for (N := 0; N < length (V); N := N + 1) {
      if (watName = V[N][0])
        T := vector_concat (T, vector (V[N]));
    }
  }
  return T;
}
;

create procedure WA_USER_SVC_KEYS (in uid int)
{
  return (select VECTOR_AGG (US_SVC, US_KEY) from WA_USER_SVC where US_U_ID = uid and length (US_KEY));
}
;

create procedure WA_USER_GET_SVC_KEY (in uname varchar, in k varchar)
{
  declare res any;
  res := null;
  declare exit handler for not found {
    return null;
  };
  select US_KEY into res from DB.DBA.WA_USER_SVC, DB.DBA.SYS_USERS where U_NAME = uname and US_SVC = k and U_ID = US_U_ID;
  return res;
}
;

create procedure WA_UPGRADE_USER_SVC ()
{
  declare keys any;
  if (registry_get ('__WA_UPGRADE_USER_SVC') = 'done')
    return;
  keys := vector ('AmazonKey','AmazonID','EbayID','FBKey','FlickrKey','GoogleAdsenseID','GoogleKey');
  for select U_ID, U_OPTS from SYS_USERS where U_IS_ROLE = 0 and U_DAV_ENABLE = 1 do
    {
      declare opts any;
      opts := deserialize (blob_to_string (U_OPTS));
      if (length (opts))
	{
	  foreach (any k in keys) do
	    {
	      declare v any;
	      v := get_keyword (k, opts);
	      if (length (v))
		insert soft WA_USER_SVC (US_U_ID, US_SVC, US_KEY) values (U_ID, k, v);
	    }
	}
    }
  registry_set ('__WA_UPGRADE_USER_SVC', 'done');
}
;

WA_UPGRADE_USER_SVC ()
;

create procedure http_s ()
{
  return case when (is_https_ctx ()) then 'https://' else 'http://' end;
}
;

create procedure  file_dav_to_string (in file_path varchar, in dav_path varchar :='') {

  declare ret any;

  if (dav_path='')
      dav_path:=file_path;

  if (http_map_get ('is_dav') = 0)
    {
      ret := file_to_string (http_root () || file_path);
    }
  else
    {
      ret := (select coalesce(blob_to_string(RES_CONTENT), 'Not found...')
                from WS.WS.SYS_DAV_RES
               where RES_FULL_PATH = '/DAV/VAD'|| dav_path);
    }

  return ret;
}
;

create procedure  ods_bar_css (in img_path varchar) {

  declare css_txt varchar;

  css_txt := (select coalesce(blob_to_string(RES_CONTENT), 'Not found...')
                from WS.WS.SYS_DAV_RES
               where RES_FULL_PATH = '/DAV/VAD/wa/ods-bar.css');

  css_txt:=replace(css_txt,'"images/','"'||img_path);

  return css_txt;
}
;


DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_user_home_rule',
    1,
    '^/~(.*)',
    vector('uname'),
    1,
    '/public_home/%s',
    vector('uname'),
    null, null, 2, null, 'MS-Author-Via: DAV'
    );

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_user_public_home_rule',
    1,
    '/~([^/]*)/Public/(.*)',
    vector('uname', 'path'),
    1,
    '/public_home/%s/Public/%s',
    vector('uname', 'path'),
    null, null, 2, null, 'MS-Author-Via: DAV'
    );

-- XXX: the root must be setup by admin
--DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
--    'ods_root_rule', 1,
--      '^/\x24',
--      vector (),
--      0,
--      '/index.html',
--      vector (),
--      NULL, NULL, 2, 0,
--      'Link: <^{DynamicLocalFormat}^/sparql?default-graph-uri=^{DynamicLocalFormat}^/dataspace>;'||
--      ' title="Public SPARQL Service"; rel="http://ontologi.es/sparql#fingerpoint"'
--      );


DB.DBA.URLREWRITE_CREATE_RULELIST ('ods_user_home_rulelist', 1, vector ('ods_user_home_rule', 'ods_user_public_home_rule'
      --, 'ods_root_rule'
      ));

create procedure ods_mv_desc ()
{
  declare str any;
  str := sprintf ('%U', 'describe ?o from <http://localhost/mv> 
  where { ?s ?p ?o option (transitive, t_in (?o), t_out (?s)) . 
    filter (?s = <http://HOST/mv/data/LOCAL> ) }');
  str := replace (str, 'HOST', '^{URIQADefaultHost}^');
  str := replace (str, '%', '%%');
  str := replace (str, 'LOCAL', '%s');
  return str;
};
    

create procedure ods_define_common_vd (in _host varchar, in _lhost varchar, in isdav int := 1)
{
  declare _opts any;
  declare _sec varchar;
  _opts := vector ();
  _sec := null;
  for select deserialize (HP_AUTH_OPTIONS) as aopts 
    from DB.DBA.HTTP_PATH where HP_HOST = _host and HP_LISTEN_HOST = _lhost and HP_SECURITY = 'SSL' and HP_LPATH = '/' do
    {
      _opts := aopts;
      _sec := 'SSL';
    }
  
  -- common access point
  DB.DBA.VHOST_REMOVE (vhost=>_host,lhost=>_lhost,lpath=>'/ods');
  DB.DBA.VHOST_DEFINE (vhost=>_host,lhost=>_lhost,lpath=>'/ods',
      ppath=>'/DAV/VAD/wa/', is_dav=>isdav, vsp_user=>'dba', def_page=>'index.html', sec=>_sec, auth_opts=>_opts);

  -- new users interface
  DB.DBA.VHOST_REMOVE (vhost=>_host,lhost=>_lhost,lpath=>'/ods/users');
  DB.DBA.VHOST_DEFINE (vhost=>_host,lhost=>_lhost,lpath=>'/ods/users',
      ppath=>'/vad/vsp/wa/users', is_dav=>0, vsp_user=>'dba', sec=>_sec, auth_opts=>_opts);

  -- JS & HTML
  DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
      'ods_javascript_users_rule',
      1,
      '/javascript/users',
      vector('dummy'),
      0,
      '/javascript/users/users.html',
      vector(),
      NULL,
      NULL,
      2);
  DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
      'ods_javascript_users_rule2',
      1,
      '/javascript/users/~([^/#\\?]*)',
      vector('user'),
      1,
      '/javascript/users/users.html?userName=%U',
      vector('user'),
      NULL,
      NULL,
      2);
  DB.DBA.URLREWRITE_CREATE_RULELIST ('ods_javascript_users_list', 1, vector('ods_javascript_users_rule', 'ods_javascript_users_rule2'));
  DB.DBA.VHOST_REMOVE (vhost=>_host,lhost=>_lhost,lpath=>'/javascript/users');
  DB.DBA.VHOST_DEFINE (vhost=>_host,lhost=>_lhost,lpath=>'/javascript/users',
      ppath=>'/vad/vsp/wa/users', def_page=>'users.html', vsp_user=>'dba', is_dav=>0, is_brws=>0, opts=>vector ('url_rewrite', 'ods_javascript_users_list'), sec=>_sec, auth_opts=>_opts);

  -- PHP
  DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
      'ods_php_users_rule',
      1,
      '/php/users',
      vector('dummy'),
      0,
      '/php/users/users.php',
      vector(),
      NULL,
      NULL,
      2);
  DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
      'ods_php_users_rule2',
      1,
      '/php/users/~([^/#\\?]*)',
      vector('user'),
      1,
      '/php/users/users.php?userName=%U',
      vector('user'),
      NULL,
      NULL,
      2);
  DB.DBA.URLREWRITE_CREATE_RULELIST ('ods_php_users_list', 1, vector('ods_php_users_rule', 'ods_php_users_rule2'));
  DB.DBA.VHOST_REMOVE (vhost=>_host,lhost=>_lhost,lpath=>'/php/users');
  DB.DBA.VHOST_DEFINE (vhost=>_host,lhost=>_lhost,lpath=>'/php/users',
      ppath=>'/vad/vsp/wa/users', def_page=>'users.php', vsp_user=>'dba', is_dav=>0, is_brws=>0, opts=>vector ('url_rewrite', 'ods_php_users_list'), sec=>_sec, auth_opts=>_opts);

  -- JSP
  DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
      'ods_jsp_users_rule',
      1,
      '/jsp/users',
      vector('dummy'),
      0,
      '/jsp/users/users.jsp',
      vector(),
      NULL,
      NULL,
      2);
  DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
      'ods_jsp_users_rule2',
      1,
      '/jsp/users/~([^/#\\?]*)',
      vector('user'),
      1,
      '/jsp/users/users.jsp?userName=%U',
      vector('user'),
      NULL,
      NULL,
      2);
  DB.DBA.URLREWRITE_CREATE_RULELIST ('ods_jsp_users_list', 1, vector('ods_jsp_users_rule', 'ods_jsp_users_rule2'));
  DB.DBA.VHOST_REMOVE (vhost=>_host,lhost=>_lhost,lpath=>'/jsp/users');
  DB.DBA.VHOST_DEFINE (vhost=>_host,lhost=>_lhost,lpath=>'/jsp/users',
      ppath=>'http://localhost:8080/users/jsp', def_page=>'users.jsp', vsp_user=>'dba', is_dav=>0, is_brws=>0, opts=>vector ('url_rewrite', 'ods_jsp_users_list'), sec=>_sec, auth_opts=>_opts);

  -- Ruby
  DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
      'ods_ruby_users_rule',
      1,
      '/ruby/users',
      vector('dummy'),
      0,
      '/ruby/users/users.rb',
      vector(),
      NULL,
      NULL,
      2);
  DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
      'ods_ruby_users_rule2',
      1,
      '/ruby/users/~([^/#\\?]*)',
      vector('user'),
      1,
      '/ruby/users/users.rb?userName=%U',
      vector('user'),
      NULL,
      NULL,
      2);
  DB.DBA.URLREWRITE_CREATE_RULELIST ('ods_ruby_users_list', 1, vector('ods_ruby_users_rule', 'ods_ruby_users_rule2'));
  DB.DBA.VHOST_REMOVE (vhost=>_host,lhost=>_lhost,lpath=>'/ruby/users');
  DB.DBA.VHOST_DEFINE (vhost=>_host,lhost=>_lhost,lpath=>'/ruby/users',
      ppath=>'/vad/vsp/wa/users', def_page=>'users.rb', vsp_user=>'dba', is_dav=>0, is_brws=>0, opts=>vector ('url_rewrite', 'ods_ruby_users_list'), sec=>_sec, auth_opts=>_opts);

  -- VSP
  DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
      'ods_vsp_users_rule',
      1,
      '/vsp/users',
      vector('dummy'),
      0,
      '/vsp/users/users.vsp',
      vector(),
      NULL,
      NULL,
      2);
  DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
      'ods_vsp_users_rule2',
      1,
      '/vsp/users/~([^/#\\?]*)',
      vector('user'),
      1,
      '/vsp/users/users.vsp?userName=%U',
      vector('user'),
      NULL,
      NULL,
      2);
  DB.DBA.URLREWRITE_CREATE_RULELIST ('ods_vsp_users_list', 1, vector('ods_vsp_users_rule', 'ods_vsp_users_rule2'));
  DB.DBA.VHOST_REMOVE (vhost=>_host,lhost=>_lhost,lpath=>'/vsp/users');
  DB.DBA.VHOST_DEFINE (vhost=>_host,lhost=>_lhost,lpath=>'/vsp/users',
      ppath=>'/vad/vsp/wa/users', def_page=>'users.vsp', vsp_user=>'dba', is_dav=>0, is_brws=>0, opts=>vector ('url_rewrite', 'ods_vsp_users_list'), sec=>_sec, auth_opts=>_opts);

  -- WebID pages
  DB.DBA.VHOST_REMOVE (vhost=>_host,lhost=>_lhost,lpath=>'/ods/webid');
  DB.DBA.VHOST_DEFINE (vhost=>_host,lhost=>_lhost,lpath=>'/ods/webid',
      ppath=>'/vad/vsp/wa/webid', is_dav=>0, vsp_user=>'dba', sec=>_sec, auth_opts=>_opts);

  -- RDF folder
  DB.DBA.VHOST_REMOVE (vhost=>_host,lhost=>_lhost,lpath=>'/ods/data/rdf');
  DB.DBA.VHOST_DEFINE (vhost=>_host,lhost=>_lhost,lpath=>'/ods/data/rdf',
      ppath=>'/DAV/VAD/wa/RDFData/All/', is_dav=>isdav, vsp_user=>'dba', sec=>_sec, auth_opts=>_opts);

  -- gdata.sql
  DB.DBA.VHOST_REMOVE (vhost=>_host,lhost=>_lhost,lpath=>'/dataspace');
  DB.DBA.VHOST_DEFINE (vhost=>_host,lhost=>_lhost,lpath=>'/dataspace',
      ppath=>'/DAV/VAD/wa/', vsp_user=>'dba', is_dav=>isdav, def_page=>'index.html',is_brws=>0,
      opts=>vector ('url_rewrite', 'ods_rule_list1'), sec=>_sec, auth_opts=>_opts);

  DB.DBA.VHOST_REMOVE (vhost=>_host,lhost=>_lhost,lpath=>'/dataspace/GData');
  DB.DBA.VHOST_DEFINE (vhost=>_host,lhost=>_lhost,lpath=>'/dataspace/GData',
      ppath=>'/SOAP/Http/gdata', soap_user=>'GDATA_ODS', sec=>_sec, auth_opts=>_opts);
  DB.DBA.VHOST_REMOVE (vhost=>_host,lhost=>_lhost,lpath=>'/openid');
  DB.DBA.VHOST_DEFINE (vhost=>_host,lhost=>_lhost,lpath=>'/openid',
      ppath=>'/SOAP/Http/server', soap_user=>'OpenID', sec=>_sec, auth_opts=>_opts);
  --ods_api.sql
  DB.DBA.VHOST_REMOVE (vhost=>_host,lhost=>_lhost,lpath=>'/ods_services');
  DB.DBA.VHOST_DEFINE (vhost=>_host,lhost=>_lhost,lpath=>'/ods_services',
      ppath=>'/SOAP/',soap_user=>'GDATA_ODS', opts=>vector ('url_rewrite', 'ods_svc_rule_list1'), sec=>_sec, auth_opts=>_opts);
  --opensocial.sql
  DB.DBA.VHOST_REMOVE (vhost=>_host,lhost=>_lhost,lpath=>'/feeds');
  DB.DBA.VHOST_DEFINE (vhost=>_host,lhost=>_lhost,lpath=>'/feeds',
      ppath=>'/SOAP/Http', soap_user=>'GDATA_ODS', opts=>vector ('url_rewrite', 'os_rule_list_ot'), sec=>_sec, auth_opts=>_opts);
  DB.DBA.VHOST_REMOVE (vhost=>_host,lhost=>_lhost,lpath=>'/activities');
  DB.DBA.VHOST_DEFINE (vhost=>_host,lhost=>_lhost,lpath=>'/activities',
      ppath=>'/SOAP/Http', soap_user=>'GDATA_ODS', opts=>vector ('url_rewrite', 'os_rule_list_act'), sec=>_sec, auth_opts=>_opts);

  -- VD for user's home folders
  DB.DBA.VHOST_REMOVE (vhost=>_host,lhost=>_lhost,lpath=>'/home');
  DB.DBA.VHOST_DEFINE (vhost=>_host,lhost=>_lhost,lpath=>'/home',
      ppath=>'/DAV/home/', is_dav=>isdav, sec=>_sec, auth_opts=>_opts);
  DB.DBA.VHOST_REMOVE (vhost=>_host,lhost=>_lhost,lpath=>'/public_home');
  DB.DBA.VHOST_DEFINE (vhost=>_host,lhost=>_lhost,lpath=>'/public_home',
      ppath=>'/DAV/home/', is_dav=>isdav, is_brws=>1, vsp_user=>'dba', sec=>_sec, auth_opts=>_opts);

  DB.DBA.VHOST_REMOVE (vhost=>_host, lhost=>_lhost, lpath=>'/ods/api');
  DB.DBA.VHOST_DEFINE (vhost=>_host, lhost=>_lhost, lpath=>'/ods/api', 
      ppath=>'/SOAP/Http', soap_user=>'ODS_API', opts=>vector ('500_page', 'error_handler'), sec=>_sec, auth_opts=>_opts);

  DB.DBA.VHOST_REMOVE (vhost=>_host, lhost=>_lhost, lpath=>'/about');
  DB.DBA.VHOST_DEFINE (vhost=>_host, lhost=>_lhost, lpath=>'/about', ppath=>'/SOAP/Http/ext_http_proxy', soap_user=>'PROXY',
      opts=>vector('url_rewrite', 'ext_about_http_proxy_rule_list1'), sec=>_sec, auth_opts=>_opts);

  -- mail verification service
  DB.DBA.VHOST_REMOVE (vhost=>_host, lhost=>_lhost, lpath=>'/mv');
  DB.DBA.VHOST_DEFINE (lhost=>_lhost, vhost=>_host, lpath=>'/mv', ppath=>'/DAV/VAD/wa/', is_dav=>isdav, def_page=>'mv.vsp', vsp_user=>'dba', sec=>_sec, auth_opts=>_opts);
  DB.DBA.VHOST_REMOVE (vhost=>_host, lhost=>_lhost, lpath=>'/mv/data');
  DB.DBA.VHOST_DEFINE (lhost=>_lhost, vhost=>_host, lpath=>'/mv/data', ppath=>'/DAV/VAD/wa/', is_dav=>isdav, def_page=>'', vsp_user=>'SPARQL', opts=>vector ('url_rewrite', 'ods_mv_rule_list_1'), sec=>_sec, auth_opts=>_opts);

DB.DBA.URLREWRITE_CREATE_RULELIST ( 'ods_mv_rule_list_1', 1, vector ('ods_mv_rule_1', 'ods_mv_rule_2'));

  DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'ods_mv_rule_1', 1, '/mv/data/(.*)\x24', vector ('par_1'), 1,
      '/sparql?query='||ods_mv_desc()||'&format=%U',
vector ('par_1', '*accept*'), NULL, '(.*)', 2, 303);

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'ods_mv_rule_2', 1, '/mv/data/(.*)\x24', vector ('par_1'), 1, 
'/describe/?url=http://^{URIQADefaultHost}^/mv/data/%s', 
vector ('par_1'), NULL, 'text/html', 2, 303);


  -- XXX: the bellow code can break existing root vd , so do not try to guess setting it up
  if (0 and exists (select 1 from DB.DBA.HTTP_PATH where HP_HOST = _host and HP_LISTEN_HOST = _lhost and HP_LPATH = '/DAV'))
    {
  if (not (exists (select 1 from DB.DBA.HTTP_PATH where HP_HOST = _host and HP_LISTEN_HOST = _lhost and HP_LPATH = '/')))
    {
      DB.DBA.VHOST_REMOVE (vhost=>_host, lhost=>_lhost, lpath=>'/');
      DB.DBA.VHOST_DEFINE (vhost=>_host, lhost=>_lhost, lpath=>'/',
	  ppath=>'/', is_dav=>0, def_page=>'index.html',
	      opts=>vector ('url_rewrite', 'ods_user_home_rulelist', 'url_rewrite_keep_lpath', 1), sec=>_sec, auth_opts=>_opts);
    }
  else
    {
      declare h_opts, do_upd any;
      h_opts := (select deserialize (HP_OPTIONS) from DB.DBA.HTTP_PATH where
      	HP_LPATH = '/' and HP_HOST = _host and HP_LISTEN_HOST = _lhost);
      do_upd := 0;
      if (not isarray (h_opts))
	{
          h_opts := vector ('url_rewrite', 'ods_user_home_rulelist', 'url_rewrite_keep_lpath', 1);
	  do_upd := 1;
	}
      else if (not position ('url_rewrite', h_opts))
	{
          h_opts := vector_concat (h_opts, vector ('url_rewrite', 'ods_user_home_rulelist', 'url_rewrite_keep_lpath', 1));
	  do_upd := 1;
	}
      if (do_upd)
	{
	  update DB.DBA.HTTP_PATH set HP_OPTIONS = serialize (h_opts)
	      where HP_LPATH = '/' and HP_HOST = _host and HP_LISTEN_HOST = _lhost;
	  DB.DBA.VHOST_MAP_RELOAD (_host, _lhost, '/');
	}
    }
    }

  return;
}
;

-- !!! not so common to use same host_port for vhost & listener value, see above for common case.
-- !!! FIXME: the insert/select would not bring up the values in memory so this would work after restart only,
---           and in addition this will copy EVERYTHING from A to B including any system related directories be patient!
create procedure wa_redefine_vhosts (in host_port varchar := '*sslini*', in interface varchar := '*sslini*', in isdav integer := 1)
{

  ods_define_common_vd (host_port, interface, isdav);

  for select
      HP_LPATH as LPATH,
      HP_PPATH as PPATH,
      HP_STORE_AS_DAV as STORE_AS_DAV,
      HP_DIR_BROWSEABLE as DIR_BROWSEABLE,
      HP_DEFAULT as _DEFAULT,
      HP_SECURITY as SECURITY,
      HP_REALM as REALM,
      HP_AUTH_FUNC as AUTH_FUNC,
      HP_POSTPROCESS_FUNC as POSTPROCESS_FUNC,
      HP_RUN_VSP_AS as RUN_VSP_AS,
      HP_RUN_SOAP_AS as RUN_SOAP_AS,
      HP_PERSIST_SES_VARS as PERSIST_SES_VARS,
      HP_SOAP_OPTIONS as SOAP_OPTIONS,
      HP_AUTH_OPTIONS as AUTH_OPTIONS,
      HP_OPTIONS as _OPTIONS,
      HP_IS_DEFAULT_HOST as IS_DEFAULT_HOST
  from DB.DBA.HTTP_PATH where HP_HOST = '*ini*' and HP_LISTEN_HOST = '*ini*' do
   {
     insert soft DB.DBA.HTTP_PATH (
	 HP_HOST,
	 HP_LISTEN_HOST,
	 HP_LPATH,
	 HP_PPATH,
	 HP_STORE_AS_DAV,
	 HP_DIR_BROWSEABLE,
	 HP_DEFAULT,
	 HP_SECURITY,
	 HP_REALM,
	 HP_AUTH_FUNC,
	 HP_POSTPROCESS_FUNC,
	 HP_RUN_VSP_AS,
	 HP_RUN_SOAP_AS,
	 HP_PERSIST_SES_VARS,
	 HP_SOAP_OPTIONS,
	 HP_AUTH_OPTIONS,
	 HP_OPTIONS,
	 HP_IS_DEFAULT_HOST)
	 values
	 (
	  host_port,
	  interface,
	  LPATH,
	  PPATH,
	  STORE_AS_DAV,
	  DIR_BROWSEABLE,
	  _DEFAULT,
	  SECURITY,
	  REALM,
	  AUTH_FUNC,
	  POSTPROCESS_FUNC,
	  RUN_VSP_AS,
	  RUN_SOAP_AS,
	  PERSIST_SES_VARS,
	  SOAP_OPTIONS,
	  AUTH_OPTIONS,
	  _OPTIONS,
	  IS_DEFAULT_HOST)
  ;
     if (row_count())
       DB.DBA.VHOST_MAP_RELOAD (host_port, interface, LPATH);
   }
}
;


create procedure ODS_USER_IDENTIY_URLS (in uname varchar)
{
  declare rset, mdta, h any;
  exec (sprintf ('select Y from (sparql define input:storage ""
  	prefix foaf: <http://xmlns.com/foaf/0.1/>
  	prefix owl: <http://www.w3.org/2002/07/owl#>
  	select ?Y from <%s> where { [] foaf:nick "%s" ; <http://www.w3.org/2002/07/owl#sameAs> ?Y }) sub',
	sioc..get_graph (), uname), null, null, vector (), 0, mdta, null, h);
  exec_result_names (mdta[0]);
  while (0 = exec_next (h, null, null, rset))
    {
      exec_result (rset);
    }
}
;

wa_exec_no_error(
  'alter type web_app drop method wa_notify_member_changed(account int, otype int, ntype int, odata any, ndata any) returns any'
)
;


create procedure check_ODS_SiteFront_welcome_message()
{
  declare curr_val, obs_val any;
  declare new_val varchar;

  obs_val := '<h3>
Welcome to OpenLink Data Spaces (ODS), a distributed collaborative
application platform that provides a "Linked Data Junction Box" for Web
protocols accessible data across a myriad of data sources.
</h3>
<p>
ODS provides a cost-effective route for creating and exploit presence on
the emerging Web of Linked Data. It enables you to transparently mesh
data across Weblogs, Shared Bookmarking, Feeds Aggregation, Photo
Gallery, Calendars, Discussions, Content Managers, and Social Networks.
</p>
<p>
ODS essentially provides distributed data across personal, group, and
community data spaces that is grounded in Web Architecture. It makes
extensive use of current and emerging standards across it''s core and
within specific functionality realms.
</p>
<p>ODS Benefits include:</p>
<ul>
  <li>Platform independent solution for Data Portability via support for all major data interchange standards</li>
  <li>Powerful solution for meshing data from a myriad of data sources across Intranets, Extranets, and the Internet</li>
  <li>Coherent integration of Blogs, Wikis, and similar systems (native and external) that expose structured Linked Data</li>
  <li>Collaborative content authoring and data generation without any exposure to underlying complexities of such activities</li>
</ul>
';

  new_val := '<h3>
Welcome to OpenLink Data Spaces (ODS)</h3>

A distributed collaborative application platform that provides a "Linked Data Junction Box" for Web protocols accessible data across a myriad of data sources.

<p>
ODS provides a cost-effective route for creating and exploit presence on
the emerging Web of Linked Data. It enables you to transparently mesh
data across Weblogs, Shared Bookmarking, Feeds Aggregation, Photo
Gallery, Calendars, Discussions, Content Managers, and Social Networks.
</p>
<p>
ODS essentially provides distributed data across personal, group, and
community data spaces that is grounded in Web Architecture. It makes
extensive use of current and emerging standards across it''s core and
within specific functionality realms.
</p>
<p>ODS Benefits include:</p>
<ul>
  <li>Platform independent solution for Data Portability via support for all major data interchange standards</li>
  <li>Powerful solution for meshing data from a myriad of data sources across Intranets, Extranets, and the Internet</li>
  <li>Coherent integration of Blogs, Wikis, and similar systems (native and external) that expose structured Linked Data</li>
  <li>Collaborative content authoring and data generation without any exposure to underlying complexities of such activities</li>
</ul>
';

  obs_val := md5(obs_val);

  select md5(replace(WS_WELCOME_MESSAGE,'\r\n','\n')) into curr_val from WA_SETTINGS where WS_WELCOME_MESSAGE is not null and trim (WS_WELCOME_MESSAGE) <> '';


  if (length(curr_val) and obs_val = curr_val)
  {

    update WA_SETTINGS
      set WS_WELCOME_MESSAGE = new_val;
  };
}
;

check_ODS_SiteFront_welcome_message()
;

create procedure ods_iri_qual (in cls varchar)
{
	declare p1, p2, p3, pos, tit, tmp, pref int;
	p1 := coalesce (strrchr (cls, '#'), -1);
	p2 := coalesce (strrchr (cls, '/'), -1);
	p3 := coalesce (strrchr (cls, ':'), -1);
	pos := __max (p1, p2, p3);
	if (pos > 0)
	  {
	    tit := subseq (cls, pos + 1);
            tmp := subseq (cls, 0, pos + 1);
	    pref := RDFData_std_pref (tmp);
	    if (pref is not null)
	      tit := pref || ':' || tit;
	    else
              tit := cls;
	  }
	else
	  tit := cls;
   return tit;
}
;

create procedure ods_iri_expand (in iri varchar)
{
  declare tmp, tit, pos, ns any;
  pos := strrchr (iri, ':');
  if (pos > 0)
    {
      tmp := subseq (iri, 0, pos);
      tit := subseq (iri, pos + 1);
      ns := RDFData_std_pref (tmp, 1);
      return ns || tit;
    }
  return iri;
}
;


wa_exec_no_error_log('grant SPARQL_SPONGE to "SPARQL"');

create procedure wa_content_annotate (
  in ap_uid any,
  in source_UTF8 varchar)
{
  declare ap_set_ids any;
  declare res_out, script_out, match_list any;
  declare m_apc, m_aps, m_app, m_apa, m_apa_w, m_aph any;
  declare apa_w_ctr, apa_w_count integer;
  declare app_ctr, app_count integer;
  declare prev_end, prev_apa_id, prev_idx integer;
  declare done any;

  ap_set_ids := (select vector (APS_ID)
                   from DB.DBA.SYS_ANN_PHRASE_SET
                  where	APS_OWNER_UID = ap_uid and APS_NAME = sprintf ('Hyperlinking-%d', ap_uid));

  if (not length (ap_set_ids))
    return source_UTF8;

  match_list := ap_build_match_list ( ap_set_ids, source_UTF8, 'x-any', 1, 0);
  m_apc   := aref_set_0 (match_list, 0);
  m_aps   := aref_set_0 (match_list, 1);
  m_app   := aref_set_0 (match_list, 2);
  m_apa   := aref_set_0 (match_list, 3);
  m_apa_w := aref_set_0 (match_list, 4);
  m_aph   := aref_set_0 (match_list, 5);

  apa_w_count := length (m_apa_w);
  app_count := length (m_app);
  done := make_array (app_count, 'any');
  if (0 = app_count)
  {
    return source_UTF8;
  }
  res_out := string_output ();
  prev_apa_id := -1;
  for (apa_w_ctr := 0; apa_w_ctr < apa_w_count; apa_w_ctr := apa_w_ctr + 1)
  {
    declare apa_idx, is_single_word integer;
    declare apa any;

    apa_idx := m_apa_w [apa_w_ctr];
    apa := aref_set_0 (m_apa, apa_idx);

    -- if current apa index is not next by previous, then we already in new match
    if (apa_idx > 0 and (prev_idx + 1) <> apa_idx)
	    prev_apa_id := -1;

    if (6 = length (apa))
    {
      declare apa_beg, apa_end, apa_hpctr, apa_hpcount, add_href, inside_href, this_apa_id integer;
      declare arr, dta any;

	    if (position (prev_apa_id, apa[5]))
	      this_apa_id := prev_apa_id;
	    else
	      this_apa_id := apa[5][0];

	    if (strchr (m_app[this_apa_id][2], ' ') is not null)
	    {
	      is_single_word := 0;
	    } else {
	      is_single_word := 1;
      }
      apa_beg := apa [1];
	    apa_end := apa [2];
	    apa_hpcount := length (apa[5]);
	    http (subseq (source_UTF8, prev_end, apa_beg), res_out);

	    if (bit_and (0hex00000004, apa[3]) or bit_and (0hex80000000, apa[3])) -- inside HREF or XMP
	    {
	      add_href := 0;
	      inside_href := 1;
	    }
	    else
	    {
	      add_href := 1;
	      inside_href := 0;
	    }

	    -- if we are already on next word in phrase do not print start of HREF
	    if (is_single_word = 0 and position (prev_apa_id, apa[5]))
	    {
	      add_href := 0;
      }
	    if (add_href and not done[this_apa_id]) -- if to print start and not already done with this phrase
	    {
	      arr := m_app[this_apa_id];
	      dta := arr [3];
	      http (sprintf ('<a href="%s">', dta), res_out);
	    }

	    -- print the matched content
	    http (subseq (source_UTF8, apa_beg, apa_end), res_out);

	    -- if we have next match and current match is not single word
	    if ((apa_idx + 1) < length (m_apa) and is_single_word = 0)
	    {
	      declare n_apa any;
	      n_apa := m_apa [apa_idx + 1];
	      -- if next match is for same phrase do not print HREF closing tag
	      if (length (n_apa) = 6 and position (this_apa_id, n_apa [5]))
	      {
          add_href := 0;
        }
        else if (not inside_href) -- if next match is some other phrase and we are not inside existing HREF, print closing tag
        {
		      add_href := 1;
		    }
	    }
	    else if (not inside_href) -- if this is a last match, and no inside HREF, print closing tag
	    {
        add_href := 1;
      }
	    prev_apa_id := this_apa_id;
	    if (add_href and not done[this_apa_id]) -- if this phrase is not printed yet
	    {
	      http ('</a>', res_out);
	      done [this_apa_id] := 1;
	      prev_apa_id := -1;
	    }
      prev_end := apa_end;
    }
    else
    {
	    prev_apa_id := -1;
	  }
    prev_idx := apa_idx;
  }
  http (subseq (source_UTF8, prev_end), res_out);
  return string_output_string (res_out);
}
;

-- /* extended http proxy service */
create procedure virt_proxy_init_about_1 ()
{
  if (isstring (registry_get ('DB.DBA.virt_proxy_init_about_state')))
    return;
  DB.DBA.VHOST_REMOVE (lpath=>'/about');
  DB.DBA.VHOST_DEFINE (lpath=>'/about', ppath=>'/SOAP/Http/ext_http_proxy', soap_user=>'PROXY');
  --# grants
  EXEC_STMT ('grant execute on  DB.DBA.HTTP_RDF_ACCEPT to PROXY', 0);
}
;

virt_proxy_init_about_1 ()
;

create procedure PSH.DBA.odscb (
    in mode varchar,
    in topic varchar, 		-- feed URI
    in challenge varchar,
    in lease_seconds int, 	--
    in verify_token varchar := null,
    in inst varchar := null
    )
{
  declare cbk, tp varchar;
  tp := (select WAI_TYPE_NAME from DB.DBA.WA_INSTANCE where WAI_ID = inst); 
  cbk := sprintf ('PSH.DBA.ods_%s_psh_cbk', DB.DBA.wa_type_to_app (tp));
  return PSH..callback (mode, topic, challenge, lease_seconds, verify_token, cbk, inst);
}
;

create procedure PSH.DBA.ods_cli_subscribe (in inst_id int, in hub varchar, in mode varchar, in topic varchar)
{
  declare token, subsu, callback, head, ret varchar;
  if (__proc_exists ('PSH.DBA.cli_subscribe') is null)
    signal ('42000', 'The PubSubHub package is not installed');

  if (hub is not null)
    {
      token := md5 (uuid ());
      callback := sprintf ('http://%s/psh/odscb.vsp?inst=%d', WA_GET_HOST (), inst_id);
      PSH..cli_subscribe ('dba', mode, topic, 'feed', null, token);
      subsu := sprintf ('%s?hub.callback=%U&hub.mode=%U&hub.topic=%U&hub.verify=sync&hub.verify_token=%U', hub, callback, mode, topic, token);
      commit work;	     
      ret := http_get (subsu, head);
      if (head[0] not like 'HTTP/1._ 20_ %')
	{
	  signal ('39000', 'The Hub rejects subscription request, please verify you are allowed to use it.');
	}
    }
  if (mode = 'subscribe')
    insert replacing DB.DBA.WA_PSH_SUBSCRIPTIONS (PS_INST_ID, PS_HUB, PS_URL) values (inst_id, hub, topic);
  else
    delete from DB.DBA.WA_PSH_SUBSCRIPTIONS where PS_INST_ID = inst_id and PS_URL = topic;
  commit work;	     
}
;

create procedure ods_uri_curie (in uri varchar)
{
  declare delim integer;
  declare uriSearch, nsPrefix, ret varchar;

  delim := -1;
  uriSearch := uri;
  nsPrefix := null;
  ret := uri;  
  while (nsPrefix is null and delim <> 0)
    {
      delim := coalesce (strrchr (uriSearch, '/'), 0);
      delim := __max (delim, coalesce (strrchr (uriSearch, '#'), 0));
      delim := __max (delim, coalesce (strrchr (uriSearch, ':'), 0));
      nsPrefix := coalesce (__xml_get_ns_prefix (subseq (uriSearch, 0, delim + 1), 2),
      			    __xml_get_ns_prefix (subseq (uriSearch, 0, delim),     2));
      uriSearch := subseq (uriSearch, 0, delim);
    }
  if (nsPrefix is not null)
    {
      declare rhs varchar;
      rhs := subseq(uri, length (uriSearch) + 1, null);
      if (not length (rhs))
	ret := uri;
      else
	ret := nsPrefix || ':' || rhs;
    }
  declare _s varchar;
  declare _h int; 

  _s := trim(ret);

  if (length(_s) <= 80) return _s;
  _h := floor ((80-3) / 2);
  _s := sprintf ('%s...%s', "LEFT"(_s, _h), "RIGHT"(_s, _h-1));

  return _s;
}
;

create procedure ods_user_keys (in username varchar)
{
  declare xenc_name, xenc_type varchar;
  declare arr any;
  result_names (xenc_name, xenc_type);
  if (not exists (select 1 from SYS_USERS where U_NAME = username))
    return;
  arr := USER_GET_OPTION (username, 'KEYS');
  for (declare i, l int, i := 0, l := length (arr); i < l; i := i + 2)
    {
      if (length (arr[i]))
        result (arr[i], arr[i+1][0]);
    }
}
;

create procedure wa_show_column_header (
  in columnLabel varchar,
  in columnName varchar,
  in sortOrder varchar,
  in sortDirection varchar := 'asc',
  in columnProperties varchar := '')
{
  declare class, image, onclick any;

  image := '';
  onclick := sprintf ('onclick="javascript: odsPost(this, [\'sortColumn\', \'%s\']);"', columnName);
  if (sortOrder = columnName)
  {
    if (sortDirection = 'desc')
    {
      image := '&nbsp;<img src="/ods/images/icons/orderdown_16.png" border="0" alt="Down"/>';
    }
    else if (sortDirection = 'asc')
    {
      image := '&nbsp;<img src="/ods/images/icons/orderup_16.png" border="0" alt="Up"/>';
    }
  }
  return sprintf ('<th %s %s>%s%s</th>', columnProperties, onclick, columnLabel, image);
}
;

create procedure wa_webid_users (
  in user_id integer)
{
  declare S, st, msg, meta, rows any;
  declare c1, c2, c3 varchar;

  result_names (c1, c2, c3);
  for (select 'Person' F1, SIOC..person_iri (SIOC..user_iri (U_ID)) F2, '' F3
         from DB.DBA.SYS_USERS
        where U_IS_ROLE = 0 and U_DAV_ENABLE = 1 and U_ACCOUNT_DISABLED = 0) do
  {
    result (F1, F2, F3);
  }
  if (DB.DBA.wa_check_app ('AddressBook', user_id))
  {
    S := sprintf ('select ''Person'' F1, a.P_IRI F2, a.P_NAME F3 from AB.WA.PERSONS a, DB.DBA.WA_MEMBER b, DB.DBA.WA_INSTANCE c where a.P_DOMAIN_ID = c.WAI_ID and c.WAI_TYPE_NAME = ''AddressBook'' and c.WAI_NAME = b.WAM_INST and B.WAM_MEMBER_TYPE = 1 and b.WAM_USER = %d and DB.DBA.is_empty_or_null (a.P_IRI) <> 1', user_id);
    st := '00000';
    exec (S, st, msg, vector(), 0, meta, rows);
    if (st = '00000')
    {
      foreach (any row in rows) do
      {
        result (row[0], row[1], row[2]);
      }
    }
  }
}
;

--!
-- \brief Table containing registered clients.
--
-- Clients that want to access all functionality of ODS need to be
-- registered with the ODS instance via admin.client.add(). This is the
-- table these clients are stored in.
--
-- The first usage of the client registration is the authentication via
-- OAuth performed in user.authenticate.authenticationUrl().
--
-- \sa ods_check_client_url()
--/
wa_exec_no_error_log(
  'CREATE TABLE WA_CLIENT_REG
  (
    CLIENT_ID int not null identity,  -- Numeric ID
    CLIENT_NAME varchar,              -- The name of the client, can be anything
    CLIENT_URL varchar not null,      -- The client URL prefix, this is the important part
    primary key (CLIENT_ID)
  )'
)
;

--!
-- \brief Table containing authentication confirmation sessions.
--
-- The ODS authentication methods which also handle registration and
-- online account connection allow to optionally have the user confirm the
-- action. This requires a temporary session to be created which is stored
-- in this table.
--
-- \sa user.authenticate.callback(), user.authenticate.browserid(), user.authenticate.webid()
--/
wa_exec_no_error_log(
  'CREATE TABLE DB.DBA.WA_AUTH_CONFIRM_SESS
  (
    AUTH_SESS_CID varchar not null,       -- The session ID
    AUTH_SESS_CLIENT_IP varchar not null, -- The IP of the calling client
    AUTH_SESS_SERVICE varchar,            -- The service type (facebook, openid, webid, ...) in case this auth session is connected to any online account
    AUTH_SESS_SERVICE_ID varchar,         -- The service ID in case this auth session is connected to any online account
    AUTH_SESS_TIMESTAMP datetime,         -- The creation time of this session, for auto-cleanup
    primary key (AUTH_SESS_CID)
  )'
)
;

create procedure DB.DBA.WA_AUTH_CONFIRM_SESS_EXPIRE()
{
  delete from DB.DBA.WA_AUTH_CONFIRM_SESS where AUTH_SESS_TIMESTAMP is null;
  delete from DB.DBA.WA_AUTH_CONFIRM_SESS where datediff ('minute', AUTH_SESS_TIMESTAMP, now()) > 10;
}
;

-- Clean up old confirm sessions every 10 minutes
insert soft "DB"."DBA"."SYS_SCHEDULED_EVENT" (SE_INTERVAL, SE_LAST_COMPLETED, SE_NAME, SE_SQL, SE_START)
  values (10, NULL, 'WA_AUTH_CONFIRM_SESS_EXPIRE', 'DB.DBA.WA_AUTH_CONFIRM_SESS_EXPIRE ()', now())
;
