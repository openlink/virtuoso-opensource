--  
--  $Id$
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

USE "ODS"
;

insert replacing DB.DBA.WA_TYPES(WAT_NAME, WAT_DESCRIPTION, WAT_TYPE, WAT_REALM) values ('Community', 'Community', 'ODS.COMMUNITY.wa_community', 'wa')
;


COMMUNITY.exec_no_error('
  delete from DB.DBA.WA_MEMBER_TYPE where WMT_APP=''Community''
')
;

insert soft DB.DBA.WA_MEMBER_TYPE (WMT_APP, WMT_NAME, WMT_ID, WMT_IS_DEFAULT) values ('Community', 'community member', 3, 1)
;

-- create new Community application in WA
COMMUNITY.exec_no_error('
  create type ODS.COMMUNITY.wa_community under DB.DBA.web_app as (
    comm_wainame   VARCHAR,
    owner  INT
  )
  constructor method wa_community(stream any),
  overriding method wa_id_string() returns any,
  overriding method wa_new_inst(login varchar) returns any,
  overriding method wa_front_page (stream any) returns any,
  overriding method wa_home_url() returns varchar,
  overriding method wa_drop_instance() returns any,
  method apply_custom_settings () returns any,
  method wa_vhost_options () returns any
  '
)
;

COMMUNITY.exec_no_error('alter type ODS..wa_community add attribute comm_home varchar')
;

COMMUNITY.exec_no_error('alter type ODS..wa_community add overriding method wa_notify_member_changed(in accounter int, in otype int, in ntype int, in odata any, in ndata any, in ostatus any, in nstatus any) returns any')
;

COMMUNITY.exec_no_error('alter type ODS..wa_community add overriding method wa_front_page_as_user(inout stream any, in user_name varchar) returns any')
;

COMMUNITY.exec_no_error('alter type ODS..wa_community add overriding method wa_state_edit_form(stream any) returns any')
;

COMMUNITY.exec_no_error('alter type ODS..wa_community add overriding method wa_addition_urls() returns any')
;

COMMUNITY.exec_no_error('alter type ODS..wa_community add overriding method wa_dashboard () returns any')
;

COMMUNITY.exec_no_error('alter type ODS..wa_community add overriding method wa_dashboard_last_item () returns any')
;

COMMUNITY.exec_no_error('alter type ODS..wa_community add overriding method apply_custom_settings (in template_path varchar, in logoimg_path varchar, in welcomeimg_path varchar) returns any')
;

COMMUNITY.exec_no_error('alter type ODS..wa_community add overriding method wa_update_instance (in oldValues any, in newValues any) returns any')
;


create constructor method wa_community (inout stream any) for wa_community {
        ;
}
;


create method wa_drop_instance () for ODS.COMMUNITY.wa_community {


-- *** remove additional end points for the instance

  for select HP_HOST, HP_LISTEN_HOST, HP_LPATH from DB.DBA.HTTP_PATH where
      HP_PPATH = registry_get('_community_path_')||'www-root/index.vspx' and
      HP_OPTIONS=serialize(vector('noinherit', 1,'comm_home',self.comm_home))
  do
  {
    DB.DBA.VHOST_REMOVE(vhost=>HP_HOST, lhost=>HP_LISTEN_HOST, lpath=>HP_LPATH);
  }

  declare pwd,_instance_customtemplate_path varchar;
  pwd := ( select pwd_magic_calc ( U_NAME , U_PASSWORD , 1 ) from DB.DBA.SYS_USERS where U_NAME = 'dav' ) ; 
  _instance_customtemplate_path := '';

  declare exit handler for not found{goto _skip_davdel;};
  select CI_TEMPLATE into _instance_customtemplate_path from ODS.COMMUNITY.SYS_COMMUNITY_INFO where CI_COMMUNITY_ID = self.wa_name;

  if(length(_instance_customtemplate_path))
     DB.DBA.DAV_DELETE (_instance_customtemplate_path||'/', 0, 'dav', pwd);

_skip_davdel:;

  delete from ODS.COMMUNITY.COMMUNITY_MEMBER_APP WHERE CM_COMMUNITY_ID=self.wa_name;
  delete from COMMUNITY.SYS_COMMUNITY_INFO WHERE CI_COMMUNITY_ID = self.wa_name;
  delete from DB.DBA.WA_MEMBER where WAM_INST = self.wa_name;
  delete from DB.DBA.WA_INSTANCE where WAI_NAME = self.wa_name;
  
  

 
}
;

create procedure COMMUNITY.community_install()
{
  declare
    iIsDav integer;
  declare
    sHost varchar;

  sHost := registry_get('_community_path_');
  if (cast(sHost as varchar) = '0')
    sHost := '/xd/';
  iIsDav := 1;

  if (isnull(strstr(sHost, '/DAV')))
    iIsDav := 0;

  -- Add a virtual directory for community -----------------------
  DB.DBA.VHOST_REMOVE(lpath      => '/community');
  DB.DBA.VHOST_DEFINE(lpath      => '/community',
                      ppath      => concat(sHost, 'www-root/index.vspx'),
                      opts       => vector('noinherit', 1),
                      vsp_user   => 'dba',
                      def_page   => 'index.vspx',
                      is_dav     => iIsDav,
                      ses_vars   => 1
                     );


  DB.DBA.VHOST_REMOVE(lpath      => '/community/public');
  DB.DBA.VHOST_DEFINE(lpath      => '/community/public',
                      ppath      => concat(sHost, 'www-root/public'),
                      vsp_user   => 'dba',
                      is_brws    => 0,
                      is_dav     => iIsDav,
                      ses_vars   => 1
                     );

  DB.DBA.VHOST_REMOVE(lpath      => '/community/templates');
  DB.DBA.VHOST_DEFINE(lpath      => '/community/templates',
                      ppath      => concat(sHost, 'www-root/templates'),
                      vsp_user   => 'dba',
                      is_brws    => 0,
                      is_dav     => iIsDav,
                      ses_vars   => 1
                     );

--eliminate instances with type DB.DBA.wa_community
  for select WAI_ID as _wai_id, WAI_INST as _wai_inst from DB.DBA.WA_INSTANCE WHERE WAI_TYPE_NAME = 'Community'  do
  {
      declare _inst_type varchar;
      
      _inst_type:=cast(udt_instance_of (_wai_inst) as varchar);

      if (strstr(_inst_type,'ODS.COMMUNITY.wa_community') is NULL)
      { 
         delete from DB.DBA.WA_INSTANCE A where A.WAI_ID=_wai_id;

      }  
  }
--eliminate old templates
  if(iIsDav)
  {
   declare pwd varchar;
   pwd := ( select pwd_magic_calc ( U_NAME , U_PASSWORD , 1 ) from DB.DBA.SYS_USERS where U_NAME = 'dav' ) ; 
                    
     for select WS.WS.COL_PATH (COL_ID) as _path, COL_NAME as _name FROM WS.WS.SYS_DAV_COL
          WHERE WS..COL_PATH (COL_ID) like registry_get('_community_path_') || 'www-root/templates/_*' do
     {
        if(_name not in ('myopenlink_v1','myopenlink_v2','openlink','xdiaspora_v1','xdiaspora_v2'))
        {
           DB.DBA.DAV_DELETE (_path, 0, 'dav', pwd);
        }
     }
  }
}
;


-- owner makes a new community
create method wa_new_inst (in login varchar) for ODS.COMMUNITY.wa_community {

  declare uid, id, _mem_model, num int;
  declare descr,  home, dav_folder VARCHAR;


  {
   declare exit handler for not found signal('WA002', 'owner does not exist');
   select U_ID into uid from DB.DBA.SYS_USERS where U_NAME = login;
  }

  if (not exists (select 1 from COMMUNITY.SYS_COMMUNITY_INFO where CI_OWNER = uid)) {
    num := 0;
  }
  else {
    num := (select count(1) from COMMUNITY.SYS_COMMUNITY_INFO where CI_OWNER = uid);
  }


  home := sprintf('/community/%s_community_%d', login, num);


  self.comm_wainame := self.wa_name;
  self.comm_home := home||'/';
  self.owner := uid;

  if(self.wa_name is null or length(self.wa_name) = 0) {
    signal('WA002', 'self.wa_name can not be empty');
  }


  insert into DB.DBA.WA_INSTANCE (WAI_NAME, WAI_TYPE_NAME, WAI_INST, WAI_DESCRIPTION, WAI_MEMBER_MODEL)
  values (self.wa_name, 'Community', self, descr, _mem_model);

  declare tit varchar;
  declare path any;

  path := registry_get('_community_path_');

  declare _U_FULL_NAME, _U_E_MAIL, _U_NAME varchar;
  select U_FULL_NAME, U_E_MAIL, U_NAME into _U_FULL_NAME, _U_E_MAIL, _U_NAME from DB.DBA.SYS_USERS where U_ID = uid;

  if (length (_U_FULL_NAME))
    tit := _U_FULL_NAME || '\'s community';
  else
    tit := _U_NAME || '\'s community';


  insert replacing COMMUNITY.SYS_COMMUNITY_INFO (CI_COMMUNITY_ID, CI_OWNER, CI_TITLE, CI_HOME) values(self.wa_name, uid, tit, home || '/');


--  create DAV directories needed for custom templates
  
  declare pwd any;
  declare tmp,col_id int;
  
  pwd := ( select pwd_magic_calc ( U_NAME , U_PASSWORD , 1 ) from DB.DBA.SYS_USERS where U_NAME = 'dav' ) ; 
  
  dav_folder := sprintf('/DAV/home/%s/community/',login);
  col_id:=DB.DBA.DAV_SEARCH_ID (dav_folder, 'C');
  if(col_id<0){
     DB . DBA . DAV_COL_CREATE ( dav_folder , '111100100N' , login , 'dav' , 'dav' , pwd ) ; 
  };
  
  dav_folder := sprintf('%s%s_community_%d/',dav_folder, login, num);
  col_id:=DB.DBA.DAV_SEARCH_ID (dav_folder, 'C');
  if(col_id<0){
     DB . DBA . DAV_COL_CREATE ( dav_folder, '111100100N' , login , null , 'dav' , pwd ) ; 
  };

  dav_folder := sprintf('%stemplates/',dav_folder, login, num);
  col_id:=DB.DBA.DAV_SEARCH_ID (dav_folder, 'C');
  if(col_id<0){
     DB . DBA . DAV_COL_CREATE ( dav_folder, '111100100N' , login , null , 'dav' , pwd ) ; 
  };

  dav_folder := sprintf('%scustom/',dav_folder, login, num);
  col_id:=DB.DBA.DAV_SEARCH_ID (dav_folder, 'C');
  if(col_id<0){
     DB . DBA . DAV_COL_CREATE ( dav_folder, '111100100N' , login , null , 'dav' , pwd ) ; 
  };

--  end create DAV directories

   declare iIsDav integer;
   if (cast(path as varchar) = '0')
     path := '/xd/';

   iIsDav := 1;
   if (isnull(strstr(path, '/DAV')))
     iIsDav := 0;

-- BEGIN create vhost if custom endpoint is used
   declare custom_ednpoint varchar;
   custom_ednpoint:=connection_get('community_customendpoint');
   if( length(custom_ednpoint)>0 and (custom_ednpoint not like '/community/%') ){
   
    
      -- Add a virtual directory for community -----------------------
      DB.DBA.VHOST_REMOVE(lpath      => custom_ednpoint);
      DB.DBA.VHOST_DEFINE(lpath      => custom_ednpoint,
                          ppath      => concat(path, 'www-root/index.vspx'),
                          opts       => vector('noinherit', 1,'comm_home',self.comm_home),
                          vsp_user   => 'dba',
                          def_page   => 'index.vspx',
                          is_dav     => iIsDav,
                          ses_vars   => 1
                         );
   }
-- END create vhost if custom endpoint is used

-- BEGIN create vhost for custom template

  if(iIsDav){
     DB.DBA.VHOST_REMOVE(lpath      => sprintf('/community/templates/custom/%s_community_%d', login, num));
     DB.DBA.VHOST_DEFINE(lpath      => sprintf('/community/templates/custom/%s_community_%d', login, num),
                         ppath      => rtrim ( dav_folder , '/' ),
                         vsp_user   => 'dba',
                         is_brws    => 0,
                         is_dav     => iIsDav,
                         ses_vars   => 1
                        );
  }
-- END create vhost for custom template

  -- call parent method to make wa level membership management action
  return (self as DB.DBA.web_app).wa_new_inst(login);

}
;

create method wa_front_page (inout stream any) for ODS.COMMUNITY.wa_community
{
  declare home, sid, vspx_user VARCHAR;
  declare vspx_uid int;
  
  select CI_HOME  into home from COMMUNITY.SYS_COMMUNITY_INFO WHERE CI_COMMUNITY_ID = self.wa_name and CI_OWNER = self.owner;

  if (home not like '%/' and home <> '/') home := home || '/';
  if (home not like '/%' and home <> '/') home := '/'||home;

  vspx_user:=connection_get ('vspx_user');
  SELECT U_ID into vspx_uid FROM DB.DBA.SYS_USERS WHERE U_NAME=vspx_user;

  sid := md5 (concat (datestring (now ()), http_client_ip (), http_path ()));
  insert into DB.DBA.VSPX_SESSION (VS_REALM, VS_SID, VS_UID, VS_STATE, VS_EXPIRY)
  values ('wa', sid, connection_get ('vspx_user'),
  serialize (
             vector (
               'vspx_user', vspx_user,
               'uid', vspx_uid,
               'comm_wainame' , self.wa_name,
               'comm_home' , self.comm_home,
               'go_to_wa', 'yes'
             )
    ), now());
    
    
  http_request_status ('HTTP/1.1 302 Found');
  http_header (sprintf('Location: %sindex.vspx?page=index&sid=%s&realm=wa\r\n', home, sid));
  return;
}
;

create method wa_state_edit_form (inout stream any) for ODS..wa_community
{
  declare home, sid, phome, owner_name,home_root varchar;
  declare owner_uid int;

  select CI_HOME, U_NAME,U_ID into home, owner_name,owner_uid from ODS..SYS_COMMUNITY_INFO, DB.DBA.SYS_USERS
  where CI_COMMUNITY_ID = self.wa_name and CI_OWNER = self.owner and U_ID = CI_OWNER;

  phome := registry_get('_community_path_');
  if (cast(phome as varchar) = '0'){
    phome := '/xd/';
  };
  phome:=concat(phome, 'www-root/index.vspx');

  if (is_http_ctx ())
  {
      declare vh, lh any;
      vh := http_map_get ('vhost');
      lh := http_map_get ('lhost');
      
      declare exit handler for not found
        {
          signal ('NOPAT', 'You do not have any virtual directory defined within current domain. Please define one.');
        };
      select HP_LPATH INTO home_root from DB.DBA.HTTP_PATH where HP_HOST = vh and HP_LISTEN_HOST = lh and HP_PPATH = phome;
  }

  

  sid := connection_get ('wa_sid');
--  sid:=NULL;

  if (sid is null)
    {
      sid := md5 (concat (datestring (now ()), http_client_ip (), http_path ()));
      insert into DB.DBA.VSPX_SESSION (VS_REALM, VS_SID, VS_UID, VS_STATE, VS_EXPIRY)
      values ('wa', sid, owner_name,
              serialize (
                          vector (
                            'vspx_user', owner_name,
                            'uid', owner_uid,
                            'comm_wainame' , self.wa_name,
                            'comm_home' , home,
                            'go_to_wa', 'yes'
                          )
                         ), now());
    }
    
  http_request_status ('HTTP/1.1 302 Found');
  http_header (sprintf('Location: %sindex.vspx?page=settings&sid=%s&realm=wa\r\n', home, sid));
  return;
}
;

create method wa_front_page_as_user (inout stream any, in user_name varchar) for ODS..wa_community
{
  declare home, sid, phome, owner_name,home_root varchar;
  declare owner_uid int;

  select CI_HOME, U_NAME,U_ID into home, owner_name,owner_uid from ODS..SYS_COMMUNITY_INFO, DB.DBA.SYS_USERS
  where CI_COMMUNITY_ID = self.wa_name and CI_OWNER = self.owner and U_ID = CI_OWNER;

  phome := registry_get('_community_path_');
  if (cast(phome as varchar) = '0'){
    phome := '/xd/';
  };
  phome:=concat(phome, 'www-root/index.vspx');

  if (is_http_ctx ())
  {
      declare vh, lh any;
      vh := http_map_get ('vhost');
      lh := http_map_get ('lhost');
      
      declare exit handler for not found
        {
          signal ('NOPAT', 'You do not have any virtual directory defined within current domain. Please define one.');
        };
      select HP_LPATH INTO home_root from DB.DBA.HTTP_PATH where HP_HOST = vh and HP_LISTEN_HOST = lh and HP_PPATH = phome;
  }

  

--  sid := connection_get ('wa_sid');
  sid:=NULL;

  if (sid is null)
    {
      sid := md5 (concat (datestring (now ()), http_client_ip (), http_path ()));
      insert into DB.DBA.VSPX_SESSION (VS_REALM, VS_SID, VS_UID, VS_STATE, VS_EXPIRY)
      values ('wa', sid, owner_name,
              serialize (
                          vector (
                            'vspx_user', owner_name,
                            'uid', owner_uid,
                            'comm_wainame' , self.wa_name,
                            'comm_home' , home,
                            'go_to_wa', 'yes'
                          )
                         ), now());
    }
    
  http_request_status ('HTTP/1.1 302 Found');
  http_header (sprintf('Location: %sindex.vspx?page=index&sid=%s&realm=wa\r\n', home, sid));
  return;
}
;






create method wa_home_url () for ODS.COMMUNITY.wa_community {
  declare uri varchar;
  uri := null;
  
  

  whenever not found goto endf;
    
  select CI_HOME into uri from ODS.COMMUNITY.SYS_COMMUNITY_INFO where CI_COMMUNITY_ID = self.wa_name;

  endf:
  
  
  return uri;
}
;

create method wa_vhost_options () for ODS.COMMUNITY.wa_community
{

  declare iIsDav integer;
  declare sHost VARCHAR;
    
  
  iIsDav := 1;

  sHost := registry_get('_community_path_');
  if (cast(sHost as varchar) = '0')
    sHost := '/xd/';

  if (isnull(strstr(sHost, '/DAV')))
    iIsDav := 0;

 
  return
      vector
       (
         concat(sHost, 'www-root/index.vspx'),                 -- physical home
         'index.vspx',                                         -- default page
         'dba',                                                -- user for execution
         0,                                                    -- directory browsing enabled
         iIsDav,                                               -- WebDAV repository
         vector('noinherit', 1,'comm_home',self.comm_home),    -- virtual directory options
         null,                                                 -- post-processing function
         null                                                  -- pre-processing (authentication) function
       );
};


create method wa_notify_member_changed (in accounter int, in otype int, in ntype int, in odata any, in ndata any, in ostatus any, in nstatus any) for ODS.COMMUNITY.wa_community
{
   (self as DB.DBA.web_app).wa_notify_member_changed (accounter,otype,ntype,odata,ndata,ostatus,nstatus);

    -- tuka e miastoto na moit gluposti
    if(otype is NULL and ntype is not NULL){

       declare app_id,action VARCHAR;
       for(SELECT  CM_MEMBER_APP from COMMUNITY_MEMBER_APP WHERE CM_COMMUNITY_ID=self.wa_name and CM_MEMBER_DATA is null) do {

           app_id:=CM_MEMBER_APP;

           declare _wai_name, acc_type, app_type any;
           _wai_name:=app_id;
           
           declare exit handler for sqlstate '*', not found
           {
              self.vc_is_valid := 0;
              declare _use_sys_errors, _sys_error, _error any;
              dbg_obj_print (__SQL_STATE,__SQL_MESSAGE);
              if (isstring (__SQL_STATE))
                 _sys_error := WA_RETRIEVE_MESSAGE(concat(__SQL_STATE,' ',__SQL_MESSAGE));
              else
                 _sys_error := '';
              _error := 'Due to a transient problem in the system, your join request could not be
                  processed at the moment. The system administrators have been notified. Please
                  try again later';
              _use_sys_errors := (select top 1 WS_SHOW_SYSTEM_ERRORS from DB.DBA.WA_SETTINGS);
              if (_use_sys_errors)
                self.vc_error_message := _error || ' ' || _sys_error;
              else
                self.vc_error_message := _error;
              rollback work;
              return;
           };
           
           select WAI_TYPE_NAME into app_type from DB.DBA.WA_INSTANCE where WAI_NAME = _wai_name;
           acc_type := (select max(WMT_ID) from DB.DBA.WA_MEMBER_TYPE where WMT_APP = app_type);
           
             if(not exists(select 1 from DB.DBA.WA_MEMBER where WAM_USER=accounter and WAM_INST=_wai_name)){                               
                insert into DB.DBA.WA_MEMBER(WAM_USER, WAM_INST, WAM_MEMBER_TYPE, WAM_STATUS)
                            values (accounter, _wai_name, acc_type, 2);
             }
     
     
       }
    }

};

ODS.COMMUNITY.exec_no_error('
create trigger WA_INSTANCE_COMMUNITY_WAINAME_UP after update (WAI_NAME) on DB.DBA.WA_INSTANCE referencing old as O, new as N
{
  if(O.WAI_TYPE_NAME=''Community''){
    update ODS.COMMUNITY.SYS_COMMUNITY_INFO set CI_COMMUNITY_ID = N.WAI_NAME where CI_COMMUNITY_ID = O.WAI_NAME;
    update ODS.COMMUNITY.COMMUNITY_MEMBER_APP set CM_COMMUNITY_ID = N.WAI_NAME where CM_COMMUNITY_ID = O.WAI_NAME;
  };
}
');

--drop trigger WA_INSTANCE_COMMUNITY_WAINAME_UP;

create method wa_addition_urls () for ODS.COMMUNITY.wa_community
{

  declare iIsDav integer;
  declare path,dav_ownerhome,comm_strid,owner_uname varchar;
    
    path := registry_get('_community_path_');
    
    select A.CI_HOME,B.U_NAME into dav_ownerhome,owner_uname from ODS.COMMUNITY.SYS_COMMUNITY_INFO A LEFT JOIN DB.DBA.SYS_USERS B on CI_OWNER=U_ID where CI_COMMUNITY_ID=self.wa_name;
    
    comm_strid := rtrim(replace(dav_ownerhome,'/community/',''),'/');
    dav_ownerhome := sprintf('/DAV/home/%s/community/%s/templates/custom',owner_uname,comm_strid);    
    
    if (cast(path as varchar) = '0') path := '/xd/';
  
    iIsDav := 1;
    if (isnull(strstr(path, '/DAV'))) iIsDav := 0;

    return vector(
           vector(null, null, '/community/public', path || 'www-root/public', iIsDav, 0, null, null, null, null, 'dba', null, null, 1, null, null, null, 0),
           vector(null, null, '/community/templates', path || 'www-root/templates', iIsDav, 0, null, null, null, null, 'dba', null, null, 1, null, null, null, 0),
           vector(null, null, '/community/templates/custom/'||comm_strid,dav_ownerhome , iIsDav, 0, null, null, null, null, 'dba', null, null, 1, null, null, null, 0)
    );
}
;

create method wa_dashboard () for ODS.COMMUNITY.wa_community
{
  return ( select
           XMLAGG(XMLELEMENT('dash-row',
                             XMLATTRIBUTES('normal' as "class", ODS.COMMUNITY.COMM_DATE_FOR_HUMANS(WAI_MODIFIED) as "time", WAI_NAME as "application"),
                             XMLELEMENT('dash-data',
                                        XMLATTRIBUTES(sprintf('<a href=\"%s">%s</a>', sprintf('/dataspace/%s/community/%U',U_NAME,WAI_NAME), WAI_NAME) as "content")
                              )
                            )
                 )
            from
              (
                select top 10 WAI_NAME, WAM_HOME_PAGE,  WAI_MODIFIED, U_NAME
                from        DB.DBA.WA_MEMBER M
                  left join DB.DBA.WA_INSTANCE I on M.WAM_INST=I.WAI_NAME
                  left join DB.DBA.SYS_USERS U on U.U_ID=M.WAM_USER
                where WAM_APP_TYPE = 'Community' and WAM_STATUS = 1  and WAM_IS_PUBLIC=1 and WAI_NAME=self.wa_name
                order by WAI_MODIFIED desc
              
               ) T
         );
}
;

create method wa_dashboard_last_item () for ODS.COMMUNITY.wa_community
{

  declare ses any;
  
  ses := string_output ();

  http ('<comm-db>', ses);
  for 
     select top 10 WAI_NAME, WAM_HOME_PAGE, WAI_MODIFIED, U_NAME, U_FULL_NAME
     from        DB.DBA.WA_MEMBER M
       left join DB.DBA.WA_INSTANCE I on M.WAM_INST=I.WAI_NAME
       left join DB.DBA.SYS_USERS U on U.U_ID=M.WAM_USER
     where WAM_APP_TYPE = 'Community' and WAM_STATUS = 1  and WAM_IS_PUBLIC=1
           and WAI_NAME = self.wa_name
     order by WAI_MODIFIED desc

   do {

    declare uname, full_name , comm_link varchar;

    uname := coalesce (U_NAME, '');
    full_name := coalesce (coalesce (U_FULL_NAME, U_NAME), '');
    comm_link:=sprintf('<a href=\"%s">%s</a>', WAM_HOME_PAGE, WAI_NAME);

    http ('<comm_instance>', ses);
    http (sprintf ('<dt>%s</dt>', DB.DBA.date_iso8601 (WAI_MODIFIED)), ses);
    http (sprintf ('<title><![CDATA[%s]]></title>', WAI_NAME), ses);
--    http (sprintf ('<link>%s</link>', WAM_HOME_PAGE), ses);
    http (sprintf ('<link><![CDATA[/dataspace/%s/community/%U]]></link>',U_NAME,self.wa_name ), ses);
    http (sprintf ('<from><![CDATA[%s]]></from>', full_name), ses);
    http (sprintf ('<uid><![CDATA[%s]]></uid>', uname), ses);
    http ('</comm_instance>', ses);
  }
  http ('</comm-db>', ses);
  return string_output_string (ses);
}
;

create method wa_update_instance (in oldValues any, in newValues any) for ODS.COMMUNITY.wa_community
{
  declare o_wa_name, n_wa_name varchar;
  declare o_is_public, n_is_public integer;
  
  o_wa_name:=oldValues[0];
  n_wa_name:=newValues[0];
  o_is_public:=oldValues[1];
  n_is_public:=newValues[1];

  set triggers off;       --triggers are off because of strange behavior -record is still referred with the old value even if it is after update. FK violation.
   update ODS.COMMUNITY.SYS_COMMUNITY_INFO set CI_TITLE=n_wa_name where CI_COMMUNITY_ID=o_wa_name;
  set triggers on;

  return (self as DB.DBA.web_app).wa_update_instance (oldValues, newValues);
}
;


create method apply_custom_settings ( in template_path varchar, in logoimg_path varchar, in welcomeimg_path varchar) for ODS.COMMUNITY.wa_community
{
  

    declare customtemplate_path,customtemplate_lpath varchar;
 
    customtemplate_path:='';
    customtemplate_path:=subseq(logoimg_path,0,strrchr(logoimg_path,'/'));
    customtemplate_lpath:='';
    select top 1 HP_LPATH into customtemplate_lpath from DB.DBA.HTTP_PATH where HP_PPATH=customtemplate_path;        

 
   declare src any;
   src := (select blob_to_string (RES_CONTENT) from WS.WS.SYS_DAV_RES where RES_FULL_PATH = template_path||'/index.vspx');
   

    declare xt, xs any;
  
    declare exit handler for sqlstate '*'
    {
        dbg_obj_print(cast(now() as varchar)||' - xslt error - ',regexp_match ('[^\r\n]*', __SQL_MESSAGE));
        return;
    };
    xt := xtree_doc (src, 256, DB.DBA.vspx_base_url (customtemplate_lpath || '/index.vspx'));
    xt := xslt (ODS..COMM_GET_PPATH_URL ('www-root/widgets/apply_custom_settings.xsl'), xt, vector('custom_imgpath', customtemplate_lpath||'/','logo_img',subseq(logoimg_path,strrchr(logoimg_path,'/')+1),'welcome_img',customtemplate_lpath||'/'||subseq(welcomeimg_path,strrchr(logoimg_path,'/')+1) ));
--    xt := xslt ('file:xd\\www-root\\widgets\\apply_custom_settings.xsl', xt, vector('custom_imgpath', customtemplate_lpath||'/','logo_img',subseq(logoimg_path,strrchr(logoimg_path,'/')+1),'welcome_img',customtemplate_lpath||'/'||subseq(welcomeimg_path,strrchr(logoimg_path,'/')+1) ));

    declare _stream any;
  
    _stream := string_output();
    http_value(xt,null,_stream);
 
    DB.DBA.DAV_DELETE (customtemplate_path || '/index.vspx', 0, 'dav', 'dav');
    DB.DBA.YACUTIA_DAV_RES_UPLOAD(customtemplate_path || '/index.vspx',string_output_string(_stream),'application/x-openlinksw-vspx+xml','110100100R','dav','dav');
 
    DB.DBA.DAV_DELETE (customtemplate_path || '/default.css', 0, 'dav', 'dav');
    DB.DBA.YACUTIA_DAV_COPY(template_path||'/default.css', customtemplate_path || '/default.css', 1, '110100100R','dav','dav');
 
 
  update ODS.COMMUNITY.SYS_COMMUNITY_INFO
  set
     CI_TEMPLATE=customtemplate_path ,
     CI_CSS=customtemplate_path ||'/default.css'
  where
    CI_COMMUNITY_ID = self.wa_name;

--  update ODS.COMMUNITY.SYS_COMMUNITY_INFO
--  set
--    CI_TEMPLATE=template_path ,
--    CI_CSS=template_path ||'/default.css'
--  where
--    CI_COMMUNITY_ID = self.wa_name;


  return;
};


USE "DBA"
;
