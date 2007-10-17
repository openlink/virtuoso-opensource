--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2006 OpenLink Software
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

--   ret := sprintf ('/ods_services/Http/OdsIriDescribe?iri=%U&accept=%U', iri, acc);

--sessionStart    (in realm varchar :='wa')
--sessionEnd      (in sid varchar,in realm varchar :='wa')
--sessionValidate (in sid varchar,in realm varchar :='wa',in userName varchar := '', in authStr varchar := '')
grant select on DB.DBA.WA_USER_INFO to GDATA_ODS;
grant select on DB.DBA.SYS_USERS to GDATA_ODS;

create procedure sessionStart (in realm varchar :='wa') __SOAP_HTTP 'text/xml'
{
  declare errCode integer;
  declare errMsg,sid varchar;
  declare resXml any;

  resXml  := string_output ();
  errCode := 0;
  errMsg  := '';

  sid:=vspx_sid_generate ();
  insert into VSPX_SESSION (VS_SID, VS_REALM, VS_UID, VS_EXPIRY) values (sid, realm, 'nobody', now ());
  
  http('<session>'||sid||'</session>',resXml);
  
  if(errCode<>0)
   httpErrXml(errCode,errMsg,'sessionStart');
  else
   httpResXml(resXml,'sessionStart');
 
  return '';
}
;

grant execute on sessionStart to GDATA_ODS;

create procedure sessionEnd (in sid varchar,in realm varchar :='wa') __SOAP_HTTP 'text/xml'
{
  declare errCode integer;
  declare errMsg varchar;
  declare resXml any;

  resXml  := string_output ();
  errCode := 0;
  errMsg  := '';

  declare exit handler for sqlstate '*' {errCode:=4;
                                         errMsg :='Unable to end session';
                                        };
  delete from VSPX_SESSION where VS_SID = sid and VS_REALM=realm;
  
  http('<session>'||sid||'</session>',resXml);
  
  if(errCode<>0)
   httpErrXml(errCode,errMsg,'sessionEnd');
  else
   httpResXml(resXml,'sessionEnd');
 
  return '';
}
;

grant execute on sessionEnd to GDATA_ODS;

create procedure sessionValidate (in sid varchar,in realm varchar :='wa',in userName varchar := '', in authStr varchar := '') __SOAP_HTTP 'text/xml'
{
  declare errCode integer;
  declare errMsg varchar;
  declare resXml any;

  resXml  := string_output ();
  errCode := 0;
  errMsg  := '';
  
--     if(isIpBlocked(http_client_ip ()))
--        goto _ipblocked;

  if(authStr='' and userName='') -- validate sid
  {
    declare user_name varchar;
    if(isSessionValid(sid,'wa',user_name))
    {
     http('<session>'||sid||'</session>',resXml);
     http('<userName>'||user_name||'</userName>',resXml);
     goto _output;
    }else 
     goto _authbad;

  }else                            -- bind sid to user
  {
    declare pwd varchar;

    if(userName='')
       goto _authbad;
    
    pwd := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from DB.DBA.SYS_USERS where U_NAME = userName);

    if(_hex_sha1_digest(sid||userName||pwd)=authStr)
    {
      declare exit handler for sqlstate '*' {goto _authbad;};
      update VSPX_SESSION set VS_UID=userName,
                              VS_EXPIRY=now(),
                              VS_STATE= serialize ( vector ( 'vspx_user', userName))
                        where VS_SID=sid and VS_REALM=realm and VS_UID='nobody';

      http('<session>'||sid||'</session>',resXml);
      http('<userName>'||userName||'</userName>',resXml);
      goto _output;
    }else
      goto _authbad;
  };
   
_authbad:
  errCode := 1;
  errMsg  := 'Authentication incorrect.';
  goto _output;
  
_ipblocked:
  errCode := 5;
  errMsg  := 'Request from '||http_client_ip ()||' are temporary blocked';
  goto _output;  
  
_output:
  if(errCode<>0)
   httpErrXml(errCode,errMsg,'sessionValidate');
  else
   httpResXml(resXml,'sessionValidate');
 
  return '';
}
;
grant execute on sessionValidate to GDATA_ODS;

create procedure usersGetInfo (in sid varchar,in realm varchar :='wa',in usersStr varchar,in fieldsStr varchar) __SOAP_HTTP 'text/xml'
{
  declare errCode integer;
  declare errMsg varchar;
  declare resXml any;

  resXml  := string_output ();
  errCode := 0;
  errMsg  := '';

  declare logged_user_name varchar;
  if(isSessionValid(sid,'wa',logged_user_name))
  {

     declare fields_name_str varchar;
     fields_name_str:='';
     fields_name_str:=constructFieldsNameStr(fieldsStr);
     
     declare users_name_str varchar;
     users_name_str:='';
     users_name_str:=constructUsersNameStr(usersStr);

     declare qry,state, msg, maxrows, metas, rset any;
      
     rset := null;
     maxrows := 0;
     state := '00000';
     msg := '';
     qry:=sprintf('select U.U_NAME as U_NAME,%s from DB.DBA.WA_USER_INFO I, DB.DBA.SYS_USERS U '||
                  ' where I.WAUI_U_ID=U.U_ID and U.U_NAME in (%s)',
                  fields_name_str,users_name_str);
   

     exec (qry, state, msg, vector(), maxrows, metas, rset);
     if (state = '00000' and length(rset)>0)
     {
      declare i integer;

      for(i:=0;i<length(rset);i:=i+1)
      {
        declare node_name varchar;
        declare k integer;

        http('<user>',resXml);
        for(k:=0;k<length(metas[0]);k:=k+1)
        {
          node_name:=xml_nodename(metas[0][k][0]);
          if(node_name<>'')
             http('<'||node_name||'>'||rset[i][k]||'</'||node_name||'>',resXml);
        }
        http('<user>',resXml);
      }

     }else 
     {
        errCode := 10;
        errMsg  := 'Can not execute query.';

     } 

     if(errCode<>0)
      httpErrXml(errCode,errMsg,'usersGetInfo');
     else
      httpResXml(resXml,'usersGetInfo');
  }
 
  return '';
}
;

grant execute on usersGetInfo to GDATA_ODS;

create procedure installedPackages (in sid varchar:='',in realm varchar :='wa') __SOAP_HTTP 'text/xml'
{
  declare errCode integer;
  declare errMsg varchar;
  declare resXml any;

  resXml  := string_output ();
  errCode := 0;
  errMsg  := '';

  if(length(sid))
  {
     declare logged_user_name varchar;
     declare logged_user_id integer;
     if(isSessionValid(sid,'wa',logged_user_name))
     {
        logged_user_id:=userid(logged_user_name);
        declare package_name varchar;
        declare packages any;
        packages:=constructTypePackageArr();
--        packages:=vector('AddressBook', 'AddressBook',
--                         'Bookmark'   , 'Bookmarks',
--                         'Calendar'   , 'Calendar',
--                         'Community'  , '', --Community -- will not show in left app navigation
--                         'Discussion' , 'Discussion',
--                         'Polls'      , 'Polls',
--                         'WEBLOG2'    , 'Weblog',
--                         'eNews2'     , 'Feed Manager',
--                         'oDrive'     , 'Briefcase',
--                         'oGallery'   , 'Gallery',
--                         'oMail'      , 'Mail',
--                         'oWiki'      , 'Wiki'
--                         );
        
        for (select WAT_NAME,WAT_MAXINST from WA_TYPES) do
        {
          package_name:=get_keyword(WAT_NAME,packages,WAT_NAME);
          if(wa_check_package(package_name))
          {
           declare inst_count integer;
           inst_count:=0;

           inst_count:=(select WMIC_INSTCOUNT from WA_MEMBER_INSTCOUNT where WMIC_TYPE_NAME=WAT_NAME  and WMIC_UID = logged_user_id);

           if(inst_count is null)
              inst_count:=0;

           declare defaultinst_homepage varchar;
           defaultinst_homepage:='';
           
           if (inst_count>0)
           {
            defaultinst_homepage:=(select top 1 WAM_HOME_PAGE from WA_MEMBER where WAM_MEMBER_TYPE=1 and  WAM_APP_TYPE=WAT_NAME  and WAM_USER=logged_user_id);
           
            
           }
           
           if(WAT_NAME='Discussion')
           {
               inst_count:=1;
               defaultinst_homepage:='/nntpf/nntpf_main.vspx';
           }   
           
           http('<application maxinstances="'||cast(WAT_MAXINST as varchar)||'" '||
                             'instcount="'||cast(inst_count as varchar)||'" '||
                             'defaulturl="'||defaultinst_homepage||'"'||
                             '>'||package_name||'</application>',resXml);
          }
        } ;

     }
  }

  if(errCode<>0)
     httpErrXml(errCode,errMsg,'installedPackages');
  else
     httpResXml(resXml,'installedPackages');
  
  return '';
}
;
grant execute on installedPackages to GDATA_ODS;

create procedure createApplication (in sid varchar:='',in realm varchar :='wa', in application varchar) __SOAP_HTTP 'text/xml'
{
  declare errCode integer;
  declare errMsg varchar;
  declare resXml any;

  resXml  := string_output ();
  errCode := 0;
  errMsg  := '';

  declare logged_user_name varchar;
  if(isSessionValid(sid,'wa',logged_user_name))
  {
        declare watypes_arr any;
        watypes_arr:=constructTypePackageArr('wa_types');

        declare watype_name,wainstance_name,full_user_name varchar;
        watype_name:=get_keyword(application,watypes_arr,application);
    
        full_user_name:=( select coalesce(WAUI_FULL_NAME,trim(concat(WAUI_FIRST_NAME,' ',WAUI_LAST_NAME))) from DB.DBA.WA_USER_INFO where WAUI_U_ID=userid(logged_user_name) );
        if(length(full_user_name)=0)
           full_user_name:=logged_user_name;
           
        wainstance_name:=full_user_name||'\'s '||application;
    
        declare create_res any;
        
        create_res:=ODS_CREATE_NEW_APP_INST(watype_name, wainstance_name, logged_user_name);
    
        declare application_url varchar;
        
        if(create_res>0)
        {
          application_url:=(select WAM_HOME_PAGE from DB.DBA.WA_MEMBER where WAM_INST=wainstance_name);
    
          http('<application>',resXml);
          http('<type>'||application||'</type>',resXml);
          http('<name>'||wainstance_name||'</name>',resXml);
          http('<url>'||application_url||'</url>',resXml);
          http('</application>',resXml);

        }else
        { errCode:=500;
          errMsg:=create_res;
        }  
        
  
  }

  if(errCode<>0)
     httpErrXml(errCode,errMsg,'createApplication');
  else
     httpResXml(resXml,'createApplication');
  
  return '';
}
;
grant execute on createApplication to GDATA_ODS;



create procedure httpResXml(in resXml any, in request_method varchar)
{
   http_rewrite();
   http_header ('Content-Type: text/xml ; charset=UTF-8\r\n');
   http ('<?xml version="1.0" encoding="UTF-8"?>');
   http ('<'||request_method||'_response>');
   http (resXml);
   http ('</'||request_method||'_response>');

  return;
}
;

create procedure httpErrXml(in errCode integer,in errMsg varchar, in request_method varchar)
{
  http_rewrite();
  http_header ('Content-Type: text/xml ; charset=UTF-8\r\n');
  http('<?xml version="1.0" encoding="UTF-8"?>');
  http('<error_response request_method="'||request_method||'">');
  http(' <error_code>'||cast(errCode as varchar)||'</error_code>');
  http(' <error_msg>'||errMsg||'</error_msg>');
  http('</error_response>');

  return;
}
;

create procedure genErrXml(in errCode integer,in errMsg varchar, in request_method varchar)
{
  return '<?xml version="1.0" encoding="UTF-8"?>'||
         '<error_response request_method="'||request_method||'">'||
          '<error_code>'||cast(errCode as varchar)||'</error_code>'||
          '<error_msg>'||errMsg||'</error_msg>'||
         '</error_response>';

}
;

create procedure isSessionValid(in sid varchar,in realm varchar :='wa',inout user_name varchar)
{

  if(exists (select 1 from DB.DBA.VSPX_SESSION where VS_SID = sid and VS_REALM=realm  and VS_UID<>'nobody' and datediff ('minute', VS_EXPIRY, now()) < 60))
  {   
     update VSPX_SESSION set VS_EXPIRY=now() where VS_SID = sid;
     user_name:=(select VS_UID from DB.DBA.VSPX_SESSION where VS_SID = sid and VS_REALM=realm);
     return 1;
  }else
  {
     declare errCode integer;
     declare errMsg  varchar;
     errCode := 1;
     errMsg  := 'Authentication incorrect.';
     
     httpErrXml(errCode,errMsg,'isSessionValid');
  }

  return 0;

}
;

create procedure constructTypePackageArr(in firstcol_type varchar :='package')
{
    declare packages_arr, wa_types_arr any;

    -- WA_TYPE /PACKAGE NAME
    packages_arr:=vector('AddressBook', 'AddressBook',
                         'Bookmark'   , 'Bookmarks',
                         'Calendar'   , 'Calendar',
                         'Community'  , 'Community', --Community -- will not show in left app navigation
                         'Discussion' , 'Discussion',
                         'Polls'      , 'Polls',
                         'WEBLOG2'    , 'Weblog',
                         'eNews2'     , 'Feed Manager',
                         'oDrive'     , 'Briefcase',
                         'oGallery'   , 'Gallery',
                         'oMail'      , 'Mail',
                         'oWiki'      , 'Wiki'
                         );

    -- PACKAGE NAME / WA_TYPE
    wa_types_arr:=vector('AddressBook'  , 'AddressBook', 
                         'Bookmarks'    , 'Bookmark'   , 
                         'Calendar'     , 'Calendar'   , 
                         'Community'    , 'Community'  ,
                         'Discussion'   , 'Discussion' , 
                         'Polls'        , 'Polls'      , 
                         'Weblog'       , 'WEBLOG2'    , 
                         'Feed Manager' , 'eNews2'     , 
                         'Briefcase'    , 'oDrive'     , 
                         'Gallery'      , 'oGallery'   , 
                         'Mail'         , 'oMail'      , 
                         'Wiki'         , 'oWiki'      

                         );

  if(firstcol_type='wa_types')
     return wa_types_arr;

  return packages_arr;
}
;

create procedure constructUsersNameStr(in usersname_str varchar)
{
  declare res_str varchar;
  declare users_name any;

  res_str:='';

  users_name:=split_and_decode(usersname_str,0,'\0\0,');
  if(users_name is not null and length(users_name)>0)
  { 
    declare i integer;
    for(i:=0; i<length(users_name); i:=i+1)
    {
        users_name[i]:=trim(users_name[i]);
        if(users_name[i]<>'')
        {
           if(i>0)
              res_str:=res_str||',';

           res_str:=res_str||'\''||users_name[i]||'\'';
        }   
    }
  }
  
  return res_str;

}
;

create procedure xml_nodename(in dbfield_name varchar)
{
 if(dbfield_name='U_NAME')       return 'userName';
 if(dbfield_name='U_FULL_NAME')  return 'fullName';
 if(dbfield_name='U_FIRST_NAME') return 'firstName';
 if(dbfield_name='U_LAST_NAME')  return 'lastName';
   
 return '';
}
;

create procedure constructFieldsNameStr(in fieldsname_str varchar)
{

  declare correctfields_name_str varchar;
  correctfields_name_str:='fullName,firstName,lastName';

  declare res_str varchar;
  declare fields_name any;
  res_str:='';
  
  
  fields_name:=split_and_decode(fieldsname_str,0,'\0\0,');
  if(fields_name is not null and length(fields_name)>0)
  { 
    declare i integer;
    for(i:=0; i<length(fields_name); i:=i+1)
    {
        fields_name[i]:=trim(fields_name[i]);
        if( locate(fields_name[i],correctfields_name_str)>0 and fields_name[i]<>'')
        {
           if(i>0)
              res_str:=res_str||',';
        
           if(fields_name[i]='fullName')
              res_str:=res_str||'coalesce(U.U_FULL_NAME,trim(concat(I.WAUI_FIRST_NAME,\' \',I.WAUI_LAST_NAME))) as U_FULL_NAME';
           if(fields_name[i]='firstName')
              res_str:=res_str||'I.WAUI_FIRST_NAME as U_FIRST_NAME';
           if(fields_name[i]='lastName')
              res_str:=res_str||'I.WAUI_LAST_NAME as U_LAST_NAME';
        }   
    }
  }

  return res_str;
}
;

create procedure _hex_sha1_digest(in str varchar)
{

    declare res_str varchar;
    declare i integer;
    res_str:='';
   
    str:=decode_base64 (xenc_sha1_digest(str));
    
    for (i := 0; i < length (str); i := i + 1)
        res_str:=res_str||sprintf('%02x',str[i]);

    return res_str;

}
;

create procedure userid(in user_name varchar)
{
 return (select U_ID from DB.DBA.SYS_USERS where U_NAME=user_name);
}
;

create procedure VSPX_EXPIRE_ANONYMOUS_SESSIONS ()
{
  delete from VSPX_SESSION where VS_EXPIRY is null;
  delete from VSPX_SESSION where VS_UID='nobody' and datediff ('minute', VS_EXPIRY, now()) > 3;
}
;


insert soft "DB"."DBA"."SYS_SCHEDULED_EVENT" (SE_INTERVAL, SE_LAST_COMPLETED, SE_NAME, SE_SQL, SE_START)
  values (1, NULL, 'VSPX_SESSION_EXPIRE_ANONYMOUS', 'VSPX_EXPIRE_ANONYMOUS_SESSIONS ()', now())
;


