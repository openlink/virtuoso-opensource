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
wa_exec_no_error('grant select on DB.DBA.NEWS_GROUPS to GDATA_ODS');
wa_exec_no_error('grant select on DB.DBA.NNTPF_SUBS to GDATA_ODS');
wa_exec_no_error('grant select on DB.DBA.WA_MESSAGES to GDATA_ODS');

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
     http('<userId>'||cast(userId(user_name) as varchar)||'</userId>',resXml);
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
      http('<userId>'||cast(userId(userName) as varchar)||'</userId>',resXml);
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
     declare qry,state, msg, maxrows, metas, rset any;
      
     rset := null;
     maxrows := 0;
     state := '00000';
     msg := '';
     qry := usersinfo_sql(usersStr,fieldsStr);   
--     dbg_obj_print(qry);
     exec (qry, state, msg, vector(), maxrows, metas, rset);
     if (state = '00000' and length(rset)>0)
     {
      declare i integer;

      for(i:=0;i<length(rset);i:=i+1)
      {
        declare node_name,section_name varchar;
        declare xml_sections,nodename_parts any;
        declare k integer;

        xml_sections:=vector();

        http('<user>',resXml);
        for(k:=0;k<length(metas[0]);k:=k+1)
        {
          node_name:=xml_nodename(metas[0][k][0]);
          nodename_parts:=split_and_decode(node_name,0,'\0\0_');
          if(length(nodename_parts)<2)
          {
          if(node_name<>'')
                http('<'||node_name||'>'||cast(rset[i][k] as varchar)||'</'||node_name||'>',resXml);
          }else
          {
             declare pos integer;
             
             pos:=position (nodename_parts[0], xml_sections);
             if(pos>0)
               xml_sections[pos]:=get_keyword(nodename_parts[0],xml_sections,'')||'<'||nodename_parts[1]||'>'||cast(rset[i][k] as varchar)||'</'||nodename_parts[1]||'>';
             else
             xml_sections:=vector_concat(xml_sections,vector(nodename_parts[0],
                                                             get_keyword(nodename_parts[0],xml_sections,'')||'<'||nodename_parts[1]||'>'||cast(rset[i][k] as varchar)||'</'||nodename_parts[1]||'>'
                                                             ));
        }
        }
        
        if(length(xml_sections))
        { declare l integer;
          for(l:=0;l<length(xml_sections);l:=l+2)
          {
            http('<'||xml_sections[l]||'>'||xml_sections[l+1]||'</'||xml_sections[l]||'>',resXml);
          }
        }
        http('</user>',resXml);
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
           declare inst_count,own_inst_count integer;
           inst_count:=0;
           own_inst_count:=0;

--           inst_count:=(select WMIC_INSTCOUNT from WA_MEMBER_INSTCOUNT where WMIC_TYPE_NAME=WAT_NAME  and WMIC_UID = logged_user_id);
           own_inst_count:=(select count(WAM_INST) from DB.DBA.WA_MEMBER where WAM_APP_TYPE=WAT_NAME  and  WAM_MEMBER_TYPE=1 and WAM_USER = logged_user_id);
           inst_count:=(select count(WAM_INST) from DB.DBA.WA_MEMBER where WAM_APP_TYPE=WAT_NAME  and WAM_USER = logged_user_id);

           if(inst_count is null)
              inst_count:=0;

           declare defaultinst_homepage varchar;
           defaultinst_homepage:='';
           
           
           if (inst_count>0)
           {
            if(own_inst_count>0)
            defaultinst_homepage:=(select top 1 WAM_HOME_PAGE from WA_MEMBER where WAM_MEMBER_TYPE=1 and  WAM_APP_TYPE=WAT_NAME  and WAM_USER=logged_user_id);
            else
               defaultinst_homepage:=(select top 1 WAM_HOME_PAGE from WA_MEMBER where WAM_APP_TYPE=WAT_NAME  and WAM_USER=logged_user_id);
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

create procedure connectionsGet (in sid varchar:='',in realm varchar :='wa', in userId integer := null, in extraFields varchar :='') __SOAP_HTTP 'text/xml'
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
    
      declare _sneid,_sneid_logged_user integer;
      _sneid_logged_user := (select sne_id from sn_person where sne_name=logged_user_name);

      if( userId is not null)
         _sneid := (select sne_id from sn_person where sne_org_id=userId);
      else
         _sneid := _sneid_logged_user;

      declare connections any;
      connections:=connections_get(_sneid);

      declare i integer;
      for(i:=0; i< length(connections); i:=i+1)
      {
          if(extraFields='')
             http('<user><uid>'||cast(connections[i] as varchar)||'</uid></user>',resXml);
          else
          {
            declare qry,state, msg, maxrows, metas, rset any;
             
            rset := null;
            maxrows := 0;
            state := '00000';
            msg := '';
            qry := usersinfo_sql(cast(connections[i] as varchar),extraFields);   
            exec (qry, state, msg, vector(), maxrows, metas, rset);
            if (state = '00000' and length(rset)>0)
            {
              declare l integer;
              
              for(l:=0;l<length(rset);l:=l+1)
              {
              
                declare node_name,section_name varchar;
                declare xml_sections,nodename_parts any;
                declare k integer;

                xml_sections:=vector();

                http('<user>',resXml);
                http('<uid>'||cast(connections[i] as varchar)||'</uid>',resXml);

                for(k:=0;k<length(metas[0]);k:=k+1)
                {
--                  node_name:=xml_nodename(metas[0][k][0]);
--                  if(node_name<>'')
--                     http('<'||node_name||'>'||cast(rset[l][k] as varchar)||'</'||node_name||'>',resXml);
--
                  node_name:=xml_nodename(metas[0][k][0]);
                  nodename_parts:=split_and_decode(node_name,0,'\0\0_');
--                     dbg_obj_print('aaa',node_name,nodename_parts[0]);

                  if(length(nodename_parts)<2)
                  {
                     if(node_name<>'')
                        http('<'||node_name||'>'||cast(rset[l][k] as varchar)||'</'||node_name||'>',resXml);
                  }else
                  {
                     declare pos integer;
                     
                     pos:=position (nodename_parts[0], xml_sections);
                     if(pos>0)
                       xml_sections[pos]:=get_keyword(nodename_parts[0],xml_sections,'')||'<'||nodename_parts[1]||'>'||cast(rset[l][k] as varchar)||'</'||nodename_parts[1]||'>';
                     else
                     xml_sections:=vector_concat(xml_sections,vector(nodename_parts[0],
                                                                     get_keyword(nodename_parts[0],xml_sections,'')||'<'||nodename_parts[1]||'>'||cast(rset[l][k] as varchar)||'</'||nodename_parts[1]||'>'
                                                                     ));
                  }
                }
                
                if(length(xml_sections))
                { declare m integer;
                  for(m:=0;m<length(xml_sections);m:=m+2)
                  {
                    http('<'||xml_sections[m]||'>'||xml_sections[m+1]||'</'||xml_sections[m]||'>',resXml);
                  }
                }
              
                http('</user>',resXml);
              }
            }
          }
      }
  }else return '';

  if(errCode<>0)
     httpErrXml(errCode,errMsg,'connectionsGet');
  else
     httpResXml(resXml,'connectionsGet');
  
  return '';
}
;
grant execute on connectionsGet to GDATA_ODS;

create procedure userCommunities (in sid varchar:='',in realm varchar :='wa') __SOAP_HTTP 'text/xml'
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
        for(select WAM_INST,WAM_HOME_PAGE from DB.DBA.WA_MEMBER where WAM_APP_TYPE='Community' and WAM_USER=userid(logged_user_name)) do
        {  

          http('<community>',resXml);
          http('<name>'||WAM_INST||'</name>',resXml);
          http('<url>'||WAM_HOME_PAGE||'</url>',resXml);
          http('</community>',resXml);

        }  
  }else
  {
        for(select WAM_INST,WAM_HOME_PAGE from DB.DBA.WA_MEMBER where WAM_APP_TYPE='Community' and WAM_IS_PUBLIC=1) do
        {  

          http('<community>',resXml);
          http('<name>'||WAM_INST||'</name>',resXml);
          http('<url>'||WAM_HOME_PAGE||'</url>',resXml);
          http('</community>',resXml);

        }  
  }
  
  if(errCode<>0)
     httpErrXml(errCode,errMsg,'userCommunities');
  else
     httpResXml(resXml,'userCommunities');
  
  return '';
}
;
grant execute on userCommunities to GDATA_ODS;

create procedure userDiscussionGroups (in sid varchar:='',in realm varchar :='wa', in userId integer := null) __SOAP_HTTP 'text/xml'
{
  declare errCode integer;
  declare errMsg varchar;
  declare resXml any;

  resXml  := string_output ();
  errCode := 0;
  errMsg  := '';

  declare logged_user_name varchar;
  declare logged_user_id integer;
  if(isSessionValid(sid,'wa',logged_user_name))
  {
      if( userId is not null)
         logged_user_id := userId;
      else
         logged_user_id := userid(logged_user_name);


     declare qry,state, msg, maxrows, metas, rset any;
      
     rset := null;
     maxrows := 0;
     state := '00000';
     msg := '';
     qry := sprintf('select distinct s.NS_GROUP as grp_id, g.NG_NAME grp_name '||
                    '  from DB.DBA.NNTPF_SUBS s, DB.DBA.NEWS_GROUPS g '||
	                  ' where g.NG_GROUP = s.NS_GROUP and s.NS_USER = %d',logged_user_id);   
     exec (qry, state, msg, vector(), maxrows, metas, rset);
     if (state = '00000' and length(rset)>0)
     {
      declare i integer;
      for(i:=0;i<length(rset);i:=i+1)
      {  
        
        http('<discussionGroup>',resXml);
        http('<id>'||cast(rset[i][0] as varchar)||'</id>',resXml);
        http('<name>'||rset[i][1]||'</name>',resXml);
        http('<url>'||'/nntpf/nntpf_nthread_view.vspx?group='||cast(rset[i][0] as varchar)||'</url>',resXml);
        http('</discussionGroup>',resXml);

      }
     }  
  }else return '';
  
  if(errCode<>0)
     httpErrXml(errCode,errMsg,'userDiscussionGroups');
  else
     httpResXml(resXml,'userDiscussionGroups');
  
  return '';
}
;
grant execute on userDiscussionGroups to GDATA_ODS;

create procedure feedStatus (in sid varchar:='',in realm varchar :='wa') __SOAP_HTTP 'text/xml'
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
    declare logged_user_id integer;
    logged_user_id:=userid(logged_user_name);
    for(select WAU_A_ID,WAU_STATUS from WA_ACTIVITIES_USERSET where WAU_U_ID=logged_user_id) do
    {
       http(sprintf('<activity id="%d" status="%d" />',WAU_A_ID,WAU_STATUS),resXml);
    } 
  }else return '';

  if(errCode<>0)
     httpErrXml(errCode,errMsg,'feedStatus');
  else
     httpResXml(resXml,'feedStatus');
  
  return '';
}
;

grant execute on feedStatus to GDATA_ODS;

create procedure feedStatusSet (in sid varchar:='',in realm varchar :='wa', in feedId integer, in feedStatus integer) __SOAP_HTTP 'text/xml'
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
    declare logged_user_id integer;
    logged_user_id:=userid(logged_user_name);
    if (exists(select 1 from WA_ACTIVITIES_USERSET where WAU_U_ID=logged_user_id and WAU_A_ID=feedId))
        update WA_ACTIVITIES_USERSET set WAU_STATUS=feedStatus where WAU_U_ID=logged_user_id and WAU_A_ID=feedId;
    else
        insert into WA_ACTIVITIES_USERSET(WAU_U_ID,WAU_A_ID,WAU_STATUS) values(logged_user_id,feedId,feedStatus);
  }else return '';

  if(errCode<>0)
     httpErrXml(errCode,errMsg,'feedStatusSet');
  else
     httpResXml(resXml,'feedStatusSet');
  
  return '';
}
;

grant execute on feedStatusSet to GDATA_ODS;

create procedure userMessages (in sid varchar,in realm varchar :='wa', in msgType integer :=0) __SOAP_HTTP 'text/xml'
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
        
        declare logged_useruser_id integer;
        logged_useruser_id:=userid(logged_user_name);
        
        if(msgType=0)
        {
            declare new_messages integer;
            new_messages:=0;
            
            declare exit handler for sqlstate '*' {new_messages:=0;};
            select count(WM_ID) into new_messages from DB.DBA.WA_MESSAGES where WM_RECIPIENT_UID=logged_useruser_id;
            
            http('<new_message_count>',resXml);
            http(sprintf('%d',new_messages),resXml);
            http('</new_message_count>',resXml);
        
        }else
        {
          declare qry,state, msg, maxrows, metas, rset any;
           
          rset := null;
          maxrows := 0;
          state := '00000';
          msg := '';


          if(msgType=2)
          {  
         	 qry := sprintf('select top 100 WM_ID,WM_SENDER_UID,WM_RECIPIENT_UID,WM_TS,WM_MESSAGE,WM_SENDER_MSGSTATUS,WM_RECIPIENT_MSGSTATUS
                              from DB.DBA.WA_MESSAGES
                             where WM_RECIPIENT_UID=%d
                             order by WM_TS desc',logged_useruser_id);
          
          }else if(msgType=3)
          {
         	 qry := sprintf('select top 100 WM_ID,WM_SENDER_UID,WM_RECIPIENT_UID,WM_TS,WM_MESSAGE,WM_SENDER_MSGSTATUS,WM_RECIPIENT_MSGSTATUS
                              from DB.DBA.WA_MESSAGES
                             where WM_SENDER_UID=%d
                             order by WM_TS desc',logged_useruser_id);
          }else
          {
         	 qry := sprintf('select top 100 WM_ID,WM_SENDER_UID,WM_RECIPIENT_UID,WM_TS,WM_MESSAGE,WM_SENDER_MSGSTATUS,WM_RECIPIENT_MSGSTATUS
                              from DB.DBA.WA_MESSAGES
                             where WM_SENDER_UID=%d OR WM_RECIPIENT_UID=%d
                             order by WM_TS desc',logged_useruser_id,logged_useruser_id);
          }
            
--          dbg_obj_print(qry);
          exec (qry, state, msg, vector(), maxrows, metas, rset);
--          dbg_obj_print(state,' ',msg);
          
          if (state = '00000' and length(rset)>0)
          {
            declare i integer;
          
            for(i:=0;i<length(rset);i:=i+1)
            {
--              dbg_obj_print(rset[i]);
            http('<message>',resXml);
              http(sprintf('<sender id="%d">%s</sender>',rset[i][1], DB.DBA.WA_USER_FULLNAME(rset[i][1])),resXml);
              http(sprintf('<recipient id="%d">%s</recipient>',rset[i][2],DB.DBA.WA_USER_FULLNAME(rset[i][2])),resXml);
              http(sprintf('<received>%s</received>',DB.DBA.date_iso8601 (rset[i][3])),resXml);
              http(sprintf('<text>%s</text>',rset[i][4]),resXml);
            http('</message>',resXml);
          }
        }
  }
  }else return '';
    
  
  if(errCode<>0)
     httpErrXml(errCode,errMsg,'userMessages');
  else
     httpResXml(resXml,'userMessages');
  
  return '';
}
;
grant execute on userMessages to GDATA_ODS;

create procedure userMessageSend (in sid varchar,in realm varchar :='wa', in recipientId integer ,in msg varchar, in senderId integer := -1) __SOAP_HTTP 'text/xml'
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

     declare logged_useruser_id,sender_id integer;
     logged_useruser_id:=userid(logged_user_name);
     if(senderId<0)
          sender_id:=logged_useruser_id;
     else sender_id:=senderId;
         
     declare exit handler for sqlstate '*' {dbg_obj_print (__SQL_STATE, ' ', __SQL_MESSAGE);

                                            errCode := 10;
                                            errMsg  := 'Can not execute query.';
                                            goto _err;
                                           };
     insert into DB.DBA.WA_MESSAGES (WM_SENDER_UID,WM_RECIPIENT_UID,WM_TS,WM_MESSAGE,WM_SENDER_MSGSTATUS,WM_RECIPIENT_MSGSTATUS)
            values (sender_id,recipientId,now(),msg,0,0);
      
  }else return '';
    
_err:  
  if(errCode<>0)
     httpErrXml(errCode,errMsg,'userMessageSend');
  else
     httpResXml(resXml,'userMessageSend');
  
  return '';
}
;
grant execute on userMessageSend to GDATA_ODS;


create procedure openIdServer (in openIdUrl varchar) __SOAP_HTTP 'text/xml'
{
  declare errCode integer;
  declare errMsg varchar;
  declare resXml any;

  resXml  := string_output ();
  errCode := 0;
  errMsg  := '';

  declare hdr,xt  any;
  declare url, cnt, oi_ident, oi_srv, oi_delegate varchar;
  
  
  declare exit handler for sqlstate '*'
  {
    errCode:=501;
    errMsg := 'Invalid OpenID URL';
    goto _end;
  };
  
  url := openIdUrl;
  oi_ident := url;

again:

  hdr := null;
  cnt := DB.DBA.HTTP_CLIENT_EXT (url=>url, headers=>hdr);
  if (hdr [0] like 'HTTP/1._ 30_ %')
  {
      declare loc any;
      loc := http_request_header (hdr, 'Location', null, null);
      url := WS.WS.EXPAND_URL (url, loc);
      oi_ident := url;
      goto again;
  }
  
  xt := xtree_doc (cnt, 2);
  oi_srv := cast (xpath_eval ('//link[@rel="openid.server"]/@href', xt) as varchar);
  oi_delegate := cast (xpath_eval ('//link[@rel="openid.delegate"]/@href', xt) as varchar);

  http('<server>'||oi_srv||'</server>',resXml);
  http('<delegate>'||oi_delegate||'</delegate>',resXml);

_end:
  
  if(errCode<>0)
     httpErrXml(errCode,errMsg,'openIdServer');
  else
     httpResXml(resXml,'openIdServer');
  
  return '';
}
;
grant execute on openIdServer to GDATA_ODS;

create procedure openIdCheckAuthentication (in realm varchar :='wa', in openIdUrl varchar,in openIdIdentity varchar) __SOAP_HTTP 'text/xml'
{
  declare errCode integer;
  declare errMsg varchar;
  declare resXml any;

  resXml  := string_output ();
  errCode := 0;
  errMsg  := '';

  declare exit handler for sqlstate '*'
  {
    errCode:=502;
    errMsg := 'OpenID Authentication Failed';
    goto _auth_failed;
  };
  
  declare url, user_name varchar;
  url := openIdUrl;
  declare resp any;
  resp := HTTP_CLIENT (url);

  if (resp not like '%is_valid:%true\n%')
  {
      errCode:=502; 
      errMsg := 'OpenID Authentication Failed';
      goto _auth_failed;
  }

  declare exit handler for not found
  {
    errCode:=503;
    errMsg := 'OpenID is not registered as user identity';
    goto _auth_failed;
  };

  select U_NAME into user_name from WA_USER_INFO, SYS_USERS where WAUI_U_ID = U_ID and WAUI_OPENID_URL = openIdIdentity;

  declare sid varchar;
  sid := vspx_sid_generate ();
  insert into VSPX_SESSION (VS_SID, VS_REALM, VS_UID, VS_EXPIRY) values (sid, realm, user_name, now ());

  http('<session>'||sid||'</session>',resXml);
  http('<userName>'||user_name||'</userName>',resXml);
  http('<userId>'||cast(userId(user_name) as varchar)||'</userId>',resXml);

_auth_failed:
  
  if(errCode<>0)
     httpErrXml(errCode,errMsg,'openIdCheckAuthentication');
  else
     httpResXml(resXml,'openIdCheckAuthentication');
  
  return '';
}
;
grant execute on openIdCheckAuthentication to GDATA_ODS;



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
   set isolation = 'committed';
   
   declare _expiry datetime;

   whenever not found goto nf;
   
   select VS_EXPIRY,VS_UID into _expiry,user_name from DB.DBA.VSPX_SESSION where VS_SID = sid and VS_REALM=realm  and (datediff ('minute', VS_EXPIRY, now()) < 60) with (prefetch 1);

   if(datediff ('minute', _expiry, now()) > 1)
  {   
     update VSPX_SESSION set VS_EXPIRY=now() where VS_SID = sid;
   }
   
--   user_name:=(select VS_UID from DB.DBA.VSPX_SESSION where VS_SID = sid and VS_REALM=realm);
   set isolation = 'repeatable';
     return 1;

nf:
     declare errCode integer;
     declare errMsg  varchar;
     errCode := 1;
     errMsg  := 'Authentication incorrect.';
     
     httpErrXml(errCode,errMsg,'isSessionValid');

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
                         'oWiki'      , 'Wiki',
                         'IM'         , 'Instant Messenger',
                         'eCRM'       , 'eCRM'
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
                         'Wiki'             , 'oWiki'      ,
                         'Instant Messenger', 'IM'         ,
                         'eCRM'             , 'eCRM'
                         );

  if(firstcol_type='wa_types')
     return wa_types_arr;

  return packages_arr;
}
;

create procedure constructUsersIdStr(in usersname_str varchar)
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

           res_str:=res_str||users_name[i];
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

create procedure connections_get(in sneID integer)
{
  declare res any;
  res:=vector();

  for select top 20 sne_org_id from
  (
    select sne_org_id from sn_related , sn_person where snr_from = sneID and snr_to = sne_id
    union all
    select sne_org_id from sn_related , sn_person where snr_from = sne_id and snr_to = sneID
  ) sub
  do
  {
      res:=vector_concat(res,vector(sne_org_id));
   }
  return res;
}
;

create procedure xml_nodename(in dbfield_name varchar)
{
 if(dbfield_name='U_NAME')       return 'userName';
 if(dbfield_name='U_FULL_NAME')  return 'fullName';
 if(dbfield_name='U_FIRST_NAME') return 'firstName';
 if(dbfield_name='U_LAST_NAME')  return 'lastName';
 if(dbfield_name='U_PHOTO_URL')    return 'photo';
 if(dbfield_name='U_TITLE')        return 'title';
 if(dbfield_name='U_MUSIC')        return 'music';
 if(dbfield_name='U_INTERESTS')    return 'interests';
 if(dbfield_name='H_COUNTRY')      return 'home_country';
 if(dbfield_name='H_STATE')        return 'home_state';
 if(dbfield_name='H_CITY')         return 'home_city';
 if(dbfield_name='H_ZIPCODE')      return 'home_zip';
 if(dbfield_name='H_ADDRESS1')     return 'home_address1';
 if(dbfield_name='H_ADDRESS2')     return 'home_address2';
 if(dbfield_name='H_LAT')          return 'home_latitude';
 if(dbfield_name='H_LNG' )         return 'home_longitude';
 if(dbfield_name='O_NAME')         return 'organization_title';
 if(dbfield_name='O_URL')          return 'organization_url';
 if(dbfield_name='O_COUNTRY')      return 'organization_country';
 if(dbfield_name='O_STATE')        return 'organization_state';
 if(dbfield_name='O_CITY')         return 'organization_city';
 if(dbfield_name='O_ZIPCODE')      return 'organization_zip';
 if(dbfield_name='O_ADDRESS1')     return 'organization_address1';
 if(dbfield_name='O_ADDRESS2')     return 'organization_address2';
 if(dbfield_name='O_LAT')          return 'organization_latitude';
 if(dbfield_name='O_LNG' )         return 'organization_longitude';
 if(dbfield_name='IM_ICQ')         return 'im_ICQ';
 if(dbfield_name='IM_SKYPE')       return 'im_Skype';
 if(dbfield_name='IM_AIM')         return 'im_AIM';
 if(dbfield_name='IM_YAHOO')       return 'im_Yahoo';
 if(dbfield_name='IM_MSN')         return 'im_MSN';

   
 return '';
}
;

create procedure constructFieldsNameStr(in fieldsname_str varchar)
{

  declare correctfields_name_str varchar;
  correctfields_name_str:='userName,fullName,firstName,lastName,photo,title,home,homeLocation,business,businessLocation,im,music,interests';

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
        
           if(fields_name[i]='userName')
              res_str:=res_str||'U.U_NAME as U_NAME';
           if(fields_name[i]='fullName')
              res_str:=res_str||'coalesce(U.U_FULL_NAME,trim(concat(I.WAUI_FIRST_NAME,\' \',I.WAUI_LAST_NAME))) as U_FULL_NAME';
           if(fields_name[i]='firstName')
              res_str:=res_str||'I.WAUI_FIRST_NAME as U_FIRST_NAME';
           if(fields_name[i]='lastName')
              res_str:=res_str||'I.WAUI_LAST_NAME as U_LAST_NAME';
           if(fields_name[i]='photo')
              res_str:=res_str||'I.WAUI_PHOTO_URL as U_PHOTO_URL';
           if(fields_name[i]='title')
              res_str:=res_str||'I.WAUI_TITLE as U_TITLE';

           if(fields_name[i]='home')
              res_str:=res_str||'I.WAUI_HCOUNTRY as H_COUNTRY,'||
                                'I.WAUI_HSTATE as H_STATE,'||
                                'I.WAUI_HCITY as H_CITY,'||
                                'I.WAUI_HCODE as H_ZIPCODE,'||
                                'I.WAUI_HADDRESS1 as H_ADDRESS1,'||
                                'I.WAUI_HADDRESS2 as H_ADDRESS2';

           if(fields_name[i]='homeLocation')
              res_str:=res_str||'I.WAUI_LAT as H_LAT,'||
                                'I.WAUI_LNG as H_LNG';

           if(fields_name[i]='business')
              res_str:=res_str||'I.WAUI_BORG as O_NAME,'||
                                'I.WAUI_BORG_HOMEPAGE as O_URL,'||
                                'I.WAUI_BCOUNTRY as O_COUNTRY,'||
                                'I.WAUI_BSTATE as O_STATE,'||
                                'I.WAUI_BCITY as O_CITY,'||
                                'I.WAUI_BCODE as O_ZIPCODE,'||
                                'I.WAUI_BADDRESS1 as O_ADDRESS1,'||
                                'I.WAUI_BADDRESS2 as O_ADDRESS2';

           if(fields_name[i]='businessLocation')
              res_str:=res_str||'I.WAUI_BLAT as O_LAT,'||
                                'I.WAUI_BLNG as O_LNG';

           if(fields_name[i]='im')
              res_str:=res_str||'I.WAUI_ICQ as IM_ICQ,'||
                                'I.WAUI_SKYPE as IM_SKYPE,'||
                                'I.WAUI_AIM as IM_AIM,'||
                                'I.WAUI_YAHOO as IM_YAHOO,'||
                                'I.WAUI_MSN as IM_MSN';

           if(fields_name[i]='music')
              res_str:=res_str||'I.WAUI_FAVORITE_MUSIC as U_MUSIC';

           if(fields_name[i]='interests')
              res_str:=res_str||'I.WAUI_INTERESTS as U_INTERESTS';



--business
--interests 

        }   
    }
  }

  return res_str;
}
;
create procedure usersinfo_sql(in usersStr varchar,in fieldsStr varchar)
{

  declare qry varchar;
   
  declare fields_name_str varchar;
  fields_name_str:='';
  fields_name_str:=constructFieldsNameStr(fieldsStr);
    
  declare users_id_str varchar;
  users_id_str:='';
  users_id_str:=constructUsersIdStr(usersStr);


--  qry:=sprintf('select U.U_NAME as U_NAME,%s from DB.DBA.WA_USER_INFO I, DB.DBA.SYS_USERS U '||
--               ' where I.WAUI_U_ID=U.U_ID and U.U_ID in (%s)',
--               fields_name_str,users_id_str);
--  
  qry:=sprintf('select U.U_ID,%s from DB.DBA.WA_USER_INFO I, DB.DBA.SYS_USERS U '||
               ' where I.WAUI_U_ID=U.U_ID and U.U_ID in (%s)',
               fields_name_str,users_id_str);

  return qry;
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


