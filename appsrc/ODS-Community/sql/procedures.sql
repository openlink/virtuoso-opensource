--  
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2017 OpenLink Software
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

create procedure COMMUNITY.SYS_COMMUNITY_EXEC(in params any, in lines any) {
  declare _mem_model,_is_public,idx,isDav int;
  declare comm_home,_wai_name,err VARCHAR;
  
  declare home_path, template_path, css_path, p_home_path, _vspx_user varchar;
  declare frozen, _vspx_user_group,_vspx_uid int;

  _vspx_user_group := -1;
  _vspx_uid:=-1;
  _vspx_user:='';
  frozen := 0;
  template_path := NULL;
  css_path := NULL;
  p_home_path := NULL;
  _wai_name := NULL;



 isDav:=1; 
 if (isnull(strstr(registry_get('_community_path_'), '/DAV'))) isDav := 0;

  idx:=locate('/index.vspx',http_path());
  if(idx>0){
      comm_home:=substring(http_path(),1,idx);
  }else{
     comm_home:=http_path();
  }  
  
  declare continue handler for NOT FOUND {

                                           declare httpmap_ci_home VARCHAR;

                                           httpmap_ci_home:=get_keyword ('comm_home',http_map_get('options'),'');
 
                                           if(httpmap_ci_home<>''){
                                              declare continue handler for NOT FOUND {http('There is no such instance!');
                                                                                      return;
                                                                                     };
                                              {
    
                                                select WAI_MEMBER_MODEL,WAI_IS_PUBLIC,WAI_NAME into _mem_model,_is_public,_wai_name
                                                from DB.DBA.WA_INSTANCE, SYS_COMMUNITY_INFO where CI_COMMUNITY_ID=WAI_NAME and CI_HOME = httpmap_ci_home;
                                              }
                                           }else{
                                             http('There is no such instance!');
                                             return;
                                           };
                                           comm_home:=httpmap_ci_home;
                                            
                                         };
  {
    select WAI_MEMBER_MODEL,WAI_IS_PUBLIC,WAI_NAME into _mem_model,_is_public,_wai_name
    from DB.DBA.WA_INSTANCE, SYS_COMMUNITY_INFO where CI_COMMUNITY_ID=WAI_NAME and CI_HOME = comm_home;
  }
  
  if (_mem_model is null)  _mem_model := 0;
  if (_is_public is null)  _is_public := 0;

  
  -- determine page name
  declare page_name varchar;
  page_name := get_keyword('page', params, 'index') || '.vspx';

  -- determine home_path, template_path, css_path


  declare  _state, _params any;
  whenever not found goto comm_not_found;
  select
    CI_HOME,
    CI_TEMPLATE,
    CI_CSS
  into
    home_path,
    template_path,
    css_path
  from
    SYS_COMMUNITY_INFO
  where
    CI_HOME = comm_home;



whenever not found goto session_not_found;
  select
    VS_STATE
  into
    _state
  from
    DB.DBA.VSPX_SESSION
  where
    VS_REALM = cast(get_keyword('realm', params) as varchar) and
    VS_SID = cast(get_keyword('sid', params) as varchar);
    
  _params := deserialize(cast(_state as varchar));


  if(_params <> ''){
    _vspx_user := get_keyword('vspx_user', _params,'');
    _vspx_user_group := (select U_GROUP from DB.DBA.SYS_USERS where U_NAME = _vspx_user);
    _vspx_uid := (select U_ID from DB.DBA.SYS_USERS where U_NAME = _vspx_user);
  }

session_not_found:

  frozen := (select WAI_IS_FROZEN from DB.DBA.WA_INSTANCE where WAI_NAME = _wai_name);
  if (_vspx_user <> 'dba' and _vspx_user <> 'dav' and _vspx_user_group <> 0)
  {
    if (frozen = 1)
    {
      declare redir varchar;
      redir := (select WAI_FREEZE_REDIRECT from DB.DBA.WA_INSTANCE where WAI_NAME = _wai_name);
      if (redir is null or redir = '' or redir = 'default')
      {
        http_request_status ('HTTP/1.1 404 Not found');
        http ( concat ('<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">',
        '<HTML><HEAD>',
        '<TITLE>404 Not Found</TITLE>',
        '</HEAD><BODY>', '<H1>Not Found</H1>',
        'Resource ', http_path (page_name), ' not found.</BODY></HTML>'));
        return;
      }
      else
      {
        http_request_status ('HTTP/1.1 302 Found');
        http_header(sprintf('Location: %s\r\n\r\n', redir));
        return;
      }
    }
  }
 

  declare is_inst_member int;
  is_inst_member:=0;
  

  if(exists(select 1 from DB.DBA.WA_MEMBER where WAM_INST = _wai_name and WAM_USER=_vspx_uid  and WAM_STATUS<3)) is_inst_member:=1;


  params := vector_concat(params, vector('app_membr_mode', _mem_model, 'is_inst_member', is_inst_member,'is_public',_is_public));
  params := vector_concat(params, vector('comm_home', comm_home,'comm_wainame',_wai_name));
   

  p_home_path:=sprintf('/DAV/home/%s%s','tester1',comm_home);
  
  -- determine full template and css path
--  css_path := COMM_MAKE_CSS_LPATH(css_path, home_path);
  css_path := COMM_MAKE_CSS_LPATH(css_path, home_path, p_home_path);


  if(template_path is null)
  template_path := registry_get('_community_path_') || 'www-root/templates/openlink';
  template_path := template_path || '/' || page_name;
  -- add css_name and comm_home as additional parameters
  params := vector_concat(params, vector('css_name', css_path));


  -- directly invoke necessary resource

  declare error_message any;
  error_message := NULL;


   if(isDAV){
      if(not exists(select 1 from WS.WS.SYS_DAV_RES where RES_FULL_PATH = template_path)) {
 
        -- template disposition doesn't found, use default one
        template_path := registry_get('_community_path_') || 'www-root/templates/openlink'  || '/' || page_name;

        if(not exists(select 1 from WS.WS.SYS_DAV_RES where RES_FULL_PATH = template_path)) {
          -- page was not found even in default template
          error_message := sprintf('Page: \'%s\' doesn\'t exists even in default template.', page_name);
          goto endproc;
        }
        css_path := COMM_MAKE_CSS_LPATH('');;
        params := vector_concat(vector('css_name', css_path), params);
      }
   }else{
--        Here should be placed the Filesystem check for templates !!!
--        error_message := sprintf('Page: \'%s\' doesn\'t exists even in default template.', page_name);
        ;
   }


--  {
--    declare vspx_dbname, vspx_user, signature varchar;
--    DB.DBA.vspx_get_user_info (vspx_dbname, vspx_user);
--    signature := DB.DBA.vspx_get_signature (vspx_dbname, vspx_user, template_path);
--    if (registry_get (template_path) <> signature)
--      {
--       declare tmpl, xt, xs, ses any;
--       whenever not found goto nft;
--       select RES_CONTENT into tmpl from WS.WS.SYS_DAV_RES where RES_FULL_PATH = template_path
--           and RES_OWNER <> http_dav_uid ();
--       xt := xtree_doc (tmpl, 256, DB.DBA.vspx_base_url (template_path));
--       xslt (XD_GET_PPATH_URL ('www-root/widgets/template_check.xsl'), xt);
--       nft:;
--      }
--  }


  DB.DBA.vspx_dispatch(template_path, home_path, params, lines);
  return 0;
  -- errors handling
comm_not_found:
  error_message := sprintf('Community ID for home directory: \'%s\' doesn\'t exists.', home_path);
  goto endproc;
error_handler:
  error_message := __SQL_MESSAGE;
endproc:
  if(error_message) {
    http_rewrite();
    template_path := registry_get('_community_path_') || 'www-root/templates/openlink/errors.vspx';
    params := vector_concat(params, vector('error_message', error_message));
    whenever SQLSTATE '*' goto error_error_handler;
    DB.DBA.vspx_dispatch(template_path, home_path, params, lines);
  }
  return;
error_error_handler:
  http_value(__SQL_MESSAGE, 'pre');


}
;

create procedure COMMUNITY.COMM_TEMPLATE_SETTINGS(in comm_home any) {
  declare template_name, css_name varchar;
  template_name := NULL;
  css_name := NULL;
  select
    CI_TEMPLATE,
    CI_CSS
  into
    template_name,
    css_name
  from
    SYS_COMMUNITY_INFO
  where
    CI_HOME = comm_home;
  if(template_name is NULL or length(template_name) = 0) template_name := registry_get('_community_path_') || 'www-root/templates/openlink';
  result_names(template_name, css_name);
  result(template_name, css_name);
}
;

create procedure COMMUNITY.COMM_GET_ACCESS(in comm_home varchar, inout sid varchar, in realm varchar, in minutes integer default 30) {
  declare _usr, _rights, _new_sid any;
  _usr := ODS.COMMUNITY.COMM_GET_USER_BY_SESSION(sid, realm, minutes);
  _rights := ODS.COMMUNITY.COMM_GET_USER_ACCESS(comm_home, _usr);
  return _rights;
}
;

create procedure COMMUNITY.COMM_GET_USER_BY_SESSION(in sid varchar, in realm varchar, in minutes integer default 30) {
  declare _last_ip, _cookie_use, _opts, _date_exp, _usr any;
  _usr := NULL;
  _cookie_use := 0;
  whenever not found goto not_found;
  select
    VS_UID,
    VS_EXPIRY,
    deserialize(blob_to_string(VS_STATE))
  into
    _usr,
    _date_exp,
    _opts
  from
    DB.DBA.VSPX_SESSION
  where
    VS_REALM = realm and
    VS_SID = sid;
  if(_opts is not null) {
    _cookie_use := get_keyword('cookie_use', _opts, 0);
    _last_ip := get_keyword('last_ip', _opts, '');
  }
  if(_cookie_use = 0) {
    -- take into account session expiration
    if(datediff('minute', _date_exp, now()) > minutes) {
      _usr := NULL;
    }
  }
  else {
    -- take into account initial ip
    if(_last_ip <> http_client_ip()) {
      _usr := NULL;
    }
  }
not_found:
  return _usr;
}
;

create procedure COMMUNITY.COMM_GET_USER_ACCESS(in comm_home varchar, in usr varchar, in pwd varchar default null)
{
  declare _is_public, _role, _status any;
  _is_public := 0;
  _role := 0;
  _status := 0;
  -- check if community instance exists
  declare _wai_name any;
  _wai_name := (select CI_COMMUNITY_ID from ODS.COMMUNITY.SYS_COMMUNITY_INFO where CI_HOME = comm_home);

  if(_wai_name is null) signal('WA001', 'Application instance not found.');
  -- check if community instance is public
  _is_public := (select WAI_IS_PUBLIC from DB.DBA.WA_INSTANCE where WAI_NAME = _wai_name);
  
  if(_is_public is null) _is_public := 0;
  if(usr is not null)
  {
    --checks if the user is administrator
    if(exists(select 1 from DB.DBA.SYS_USERS where U_NAME = usr and U_GROUP in (0,3)))
    {
       return 1;
    }
    
    if(exists(select 1 from DB.DBA.SYS_USERS where U_NAME = usr and U_DAV_ENABLE = 1 and U_IS_ROLE = 0)) {
      declare _user_id any;
      _user_id := (select U_ID from DB.DBA.SYS_USERS where U_NAME = usr);
      -- validate password if necessary
      if(pwd is not null) {
        declare _real_pwd any;
        _real_pwd := (select pwd_magic_calc(U_NAME, U_PASSWORD, 1) from DB.DBA.SYS_USERS where U_ID = _user_id);
        if(pwd <> _real_pwd) return 0;
      }
      -- if it's registered user - check his role against current community
      -- if several roles assigned to one user - use the best one (minimum value)
      _role := (select min(WAM_MEMBER_TYPE) from DB.DBA.WA_MEMBER
                where WAM_STATUS <= 2 and WAM_USER = _user_id and WAM_INST = _wai_name
                and (WAM_MEMBER_SINCE < now() or WAM_MEMBER_SINCE is null) and (WAM_EXPIRES > now() or WAM_EXPIRES is null));
      _status := (select WAM_STATUS from DB.DBA.WA_MEMBER where WAM_USER = _user_id
                  and WAM_INST = _wai_name and (WAM_MEMBER_SINCE < now() or WAM_MEMBER_SINCE is null)
                  and (WAM_EXPIRES > now() or WAM_EXPIRES is null));

      if(_status = 1) _role := 1;  -- owner
      if(_role is null) _role := 0;
    }
  }
  commit work;

  -- return 0 in no access, 1 if owner, 2 if author, 3 if can read (reader or community is public);
  if(_role in (1, 2)) return _role;
  if(_is_public) return 3;
  return _role;
}
;

create procedure COMMUNITY.COMM_CREATE_SID() {
  return md5(concat(datestring(now()), http_client_ip (), http_path ()));
}
;

create procedure COMMUNITY.comm_utf2wide (inout S any ) 
{ 
  declare exit handler for sqlstate '*' { return S ; } ; 
  return charset_recode ( S , 'UTF-8' , '_WIDE_' ) ; 
}
;

create procedure COMMUNITY.COMM_GET_PPATH_URL (in f any)
{
  return concat (
      'virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:',
       registry_get('_community_path_'), f);
}
;

create procedure COMMUNITY.COMM_MAKE_CSS_LPATH(in ppath varchar, in home_path varchar := null, in p_home_path varchar := null) {
  -- if css is not defined at all : use default one /community/public/css/default.css

  if(ppath is null or length(ppath) = 0) return '/community/public/css/default.css';
  -- important:
  -- if it css defined in home directory : use use relative path like templates/template_name/css_name.css
  -- this is to work in sub domains

  declare dav_home any;
 dav_home := '/DAV/home/';
  if(strstr(ppath, dav_home) = 0)
  {
      declare comm_strid varchar;
      comm_strid:=rtrim(replace(home_path,'/community/',''),'/');
--    return '/community/'||subseq(ppath, length(p_home_path));
      return sprintf('/community/templates/custom/%s/default.css',comm_strid);
  }

  -- if it is system defined css : use absolute path like /community/www-root/templates/template_name/css_name.css
  return '/community/' || subseq(ppath, strstr(ppath, 'templates/'));
}
;

create procedure COMMUNITY.COMM_DAV_COPY ( in path varchar , 
                                         in destination varchar , 
                                         in uid2 varchar , 
                                         in overwrite integer , 
                                         in file_list any := null
                                       ) 
{ 

  declare pwd1 any ; 
  declare _res_id , u_id2 int ; 
  pwd1 := ( select pwd_magic_calc ( U_NAME , U_PASSWORD , 1 ) from DB . DBA . SYS_USERS where U_NAME = 'dav' ) ; 
  DB . DBA . DAV_COL_CREATE ( left ( destination , strrchr ( rtrim ( destination , '/' ) , '/' ) + 1 ) , '111100100N' , uid2 , null , 'dav' , pwd1 ) ; 

  if ( file_list is null ){ 
     _res_id := DB . DBA . DAV_COPY ( path , destination , overwrite , '110100100N' , uid2 , null , 'dav' , pwd1 ) ; 
  }else{ 
        declare copy_list any ; 

        DB . DBA . DAV_DELETE ( destination , 1 , 'dav' , pwd1 ) ; 
        DB . DBA . DAV_COL_CREATE ( destination , '111100100N' , uid2 , null , 'dav' , pwd1 ) ; 

        copy_list := DB . DBA . DAV_DIR_LIST ( path , 0 , 'dav' , pwd1 ) ; 

        foreach ( any entry in copy_list ) do 
        { 
          declare dest_file any ; 
          dest_file := entry [ 10 ] ; 
          if ( regexp_match ( file_list , dest_file ) ) 
          { 

            _res_id := DB . DBA . DAV_COPY ( path || dest_file , destination || dest_file , 
            overwrite , '110100100N' , uid2 , null , 'dav' , pwd1 ) ; 
        

            if ( _res_id < 0 ) 
            signal ( '42000' , 'Internal error: Cannot copy WebDAV resource : ' || dest_file ) ; 
          } 
        } 
  }
   
  u_id2 := ( select U_ID from DB . DBA . SYS_USERS where U_NAME = uid2 ) ; 
  
  if ( _res_id > 0 ){ 
      declare cur_type , cur_perms varchar ; 
      declare res_cur cursor for 

      select RES_PERMS , RES_TYPE from WS . WS . SYS_DAV_RES 
      where substring ( RES_FULL_PATH , 1 , length ( destination ) ) = destination ; 
      whenever not found goto next_one ; 
      open res_cur ( prefetch 1 , exclusive ) ; 
      while ( 1 ){ 
            fetch res_cur into cur_type , cur_perms ; 
            update WS . WS . SYS_DAV_RES set RES_OWNER = u_id2 , RES_GROUP = null where current of res_cur ; 
            if ( cur_perms <> '110100100N' ) 
            update WS . WS . SYS_DAV_RES set RES_PERMS = '110100100N' where current of res_cur ; 
            commit work ; 
      } 
      next_one : 
      close res_cur ; 
  } 
  
return _res_id ; 
}
;

create procedure COMMUNITY.COMM_USER_DASHBOARD_SP (in uid int, in inst_type varchar, in inst_parent_name varchar)
{
  declare inst_name, title, author, url nvarchar;
  declare ts datetime;
  declare inst web_app;
  declare h, ret any;

  result_names (inst_name, title, ts, author, url);
  for select WAM_INST, WAI_INST, WAM_HOME_PAGE from DB.DBA.WA_MEMBER, DB.DBA.WA_INSTANCE
  where WAI_NAME = WAM_INST and WAM_USER = uid and WAM_APP_TYPE = inst_type
        and WAI_NAME in (SELECT  CM_MEMBER_APP from COMMUNITY_MEMBER_APP WHERE CM_COMMUNITY_ID=inst_parent_name and CM_MEMBER_DATA is null)
  do
  {
    inst := WAI_INST;
    h := udt_implements_method (inst, fix_identifier_case ('wa_dashboard_last_item'));
    if (h){
       ret := call (h) (inst);
       if (length (ret)){
           declare xp any;
           ret := xtree_doc (ret);
     
           xp := xpath_eval ('//*[title]', ret, 0);
           foreach (any ret1 in xp) do
           {
               title := xpath_eval ('string(title/text())', ret1);
               ts := xpath_eval ('string (dt/text())', ret1);
               author := xpath_eval ('string (from/text())', ret1);
               url := xpath_eval ('string (link/text())', ret1);
               ts := cast (ts as datetime);
               result (WAM_INST, title, ts, author, url);
           }
       }
    }
  }
};

create procedure COMMUNITY.COMM_COMMON_DASHBOARD_SP ( in inst_type varchar, in inst_parent_name varchar)
{
  declare inst_name, title, author, url nvarchar;
  declare ts datetime;
  declare inst web_app;
  declare h, ret any;

  result_names (inst_name, title, ts, author, url);
  for select WAM_INST, WAI_INST, WAM_HOME_PAGE from DB.DBA.WA_MEMBER, DB.DBA.WA_INSTANCE
  where WAI_NAME = WAM_INST and WAM_APP_TYPE = inst_type
        and WAI_NAME in (SELECT  CM_MEMBER_APP from COMMUNITY_MEMBER_APP WHERE CM_COMMUNITY_ID=inst_parent_name and CM_MEMBER_DATA is null)
  do
  {
    inst := WAI_INST;
    h := udt_implements_method (inst, fix_identifier_case ('wa_dashboard_last_item'));
    if (h){
       ret := call (h) (inst);
       if (length (ret)){
           declare xp any;
           ret := xtree_doc (ret);
     
           xp := xpath_eval ('//*[title]', ret, 0);
           foreach (any ret1 in xp) do
           {
               title := xpath_eval ('string(title/text())', ret1);
               ts := xpath_eval ('string (dt/text())', ret1);
               author := xpath_eval ('string (from/text())', ret1);
               url := xpath_eval ('string (link/text())', ret1);
               ts := cast (ts as datetime);
               result (WAM_INST, title, ts, author, url);
           }
       }
    }
  }
};


create procedure COMMUNITY.COMM_DATE_FOR_HUMANS(in d datetime) {

  declare date_part varchar;
  declare time_part varchar;

  declare min_diff integer;
  declare day_diff integer;


  day_diff := datediff ('day', d, now ());

  if (day_diff < 1)
    {
      min_diff := datediff ('minute', d, now ());

      if (min_diff = 1)
        {
          return ('a minute ago');
  }
      else if (min_diff < 1)
        {
          return ('less than a minute ago');
        }
      else if (min_diff < 60)
  {
    return (sprintf ('%d minutes ago', min_diff));
  }
      else return (sprintf ('today at %d:%02d', hour (d), minute (d)));
    }

  if (day_diff < 2)
    {
      return (sprintf ('yesterday at %d:%02d', hour (d), minute (d)));
    }

  return (sprintf ('%d/%d/%d %d:%02d', year (d), month (d), dayofmonth (d), hour (d), minute (d)));
}
;

create procedure COMMUNITY.COMM_GET_WA_URL ()
{

        declare vhost_str, subdomain_str, domain_str ,port_str varchar;
        declare wa_host, wa_lpath, wa_url varchar;

        wa_url:='/ods';

        vhost_str:=http_map_get('vhost');

        if(vhost_str<>'*ini*')
        {
          
          if(locate('.',vhost_str)){
             subdomain_str:=subseq(vhost_str,0,locate('.',vhost_str)-1);
             domain_str := subseq(vhost_str,locate('.',vhost_str));
          }else{
            domain_str := vhost_str;
          }
            
          if(locate(':',domain_str)){
          port_str := subseq(domain_str,locate(':',domain_str));
          domain_str := subseq(domain_str,0,locate(':',domain_str)-1);
          }

          whenever not found goto nf;
          {
            select top 1 WD_HOST, WD_LPATH, WD_LISTEN_HOST into wa_host, wa_lpath,port_str from DB.DBA.WA_DOMAINS where WD_DOMAIN=domain_str;
          }
          
          if (locate(':',wa_host))
              wa_host:=subseq(wa_host,0,locate(':',wa_host)-1);

          wa_url:=sprintf('http://%s%s',wa_host,wa_lpath);
          
          nf:
          return wa_url;
        
      }else return '/ods';
}
;



create procedure COMMUNITY.COMM_NEWINST_GET_CUSTOMOPTIONS (in option_type varchar)
{
    declare res_name, res_path varchar;

    result_names (res_name,res_path);


  if (option_type='TEMPLATE_LIST')
  {
    for 
--      select rtrim (WS.WS.COL_PATH (COL_ID), '/') as PATH, COL_NAME as NAME FROM WS.WS.SYS_DAV_COL
--      where WS..COL_PATH (COL_ID) like registry_get('_community_path_') || 'www-root/templates/_*'
      select rtrim (WS.WS.COL_PATH (COL_ID), '/') as PATH, COL_NAME as NAME FROM WS.WS.SYS_DAV_COL
      where WS..COL_PATH (COL_ID) like '/DAV/VAD/community/' || 'www-root/templates/_*'
    do
    {
		    result ( cast( NAME as varchar), cast(PATH as varchar));
    }
  }else if(option_type='INSTANCE_LOGOS')
  {
    result ( 'logo_blue','/DAV/VAD/community/www-root/public/images/lightblue/community_blank_thin550.jpg');
    result ( 'logo_green','/DAV/VAD/community/www-root/public/images/xdia_nig_banner.jpg');
  }else if(option_type='WELCOME_PHOTOS')
  {
    result ( 'welcome_blue','/DAV/VAD/community/www-root/public/images/lightblue/comm_blank_welcome.png');
    result ( 'welcome_green','/DAV/VAD/community/www-root/public/images/welcome_nig_2.gif');
  }else result ('','');
  

};
create procedure COMMUNITY.doPTSW (
  in instance_name varchar,
  in owner_uname varchar
  )
{
  declare sioc_url  varchar;
  
  sioc_url:=replace (sprintf ('%s/dataspace/%U/community/%U/sioc.rdf', 'http://'||DB.DBA.WA_GET_HOST(), owner_uname, instance_name), '+', '%2B');
  
  
  for (select  WAI_NAME,WAI_DESCRIPTION from DB.DBA.WA_INSTANCE where WAI_NAME = instance_name and WAI_IS_PUBLIC = 1) do {
    ODS.DBA.APP_PING (WAI_NAME, coalesce (WAI_DESCRIPTION, WAI_NAME), sioc_url,'The Semantic Web.com');
  }
}
;
