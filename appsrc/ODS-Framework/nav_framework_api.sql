--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2013 OpenLink Software
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

grant select on DB.DBA.WA_USER_INFO to GDATA_ODS;
grant select on DB.DBA.SYS_USERS to GDATA_ODS;
wa_exec_no_error('grant select on DB.DBA.NEWS_GROUPS to GDATA_ODS');
wa_exec_no_error('grant select on DB.DBA.NNTPF_SUBS to GDATA_ODS');
wa_exec_no_error('grant select on DB.DBA.WA_MESSAGES to GDATA_ODS');
wa_exec_no_error('grant execute on DB.DBA.WA_USER_DATASPACE to GDATA_ODS');

--search permissions
wa_exec_no_error('grant select on DB.DBA.WA_USER_TEXT to GDATA_ODS');
wa_exec_no_error('grant select on DB.DBA.sn_person to GDATA_ODS');
wa_exec_no_error('grant select on DB.DBA.WA_INSTANCE to GDATA_ODS');
wa_exec_no_error('grant select on DB.DBA.WA_MEMBER to GDATA_ODS');
wa_exec_no_error('grant select on BLOG.DBA.SYS_BLOGS to GDATA_ODS');
wa_exec_no_error('grant select on ENEWS.WA.FEED_ITEM to GDATA_ODS');
wa_exec_no_error('grant select on ENEWS.WA.FEED_DOMAIN to GDATA_ODS');
wa_exec_no_error('grant select on OMAIL.WA.MESSAGES to GDATA_ODS');
wa_exec_no_error('grant select on OMAIL.WA.MSG_PARTS to GDATA_ODS');
wa_exec_no_error('grant select on BMK.WA.BOOKMARK_DOMAIN to GDATA_ODS');
wa_exec_no_error('grant select on POLLS.WA.POLL to GDATA_ODS');
wa_exec_no_error('grant select on AB.WA.PERSONS to GDATA_ODS');
wa_exec_no_error('grant select on CAL.WA.EVENTS to GDATA_ODS');
wa_exec_no_error('grant select on DB.DBA.RDF_QUAD to GDATA_ODS');
wa_exec_no_error('grant select on DB.DBA.RDF_OBJ to GDATA_ODS');
wa_exec_no_error('grant select on WV.Wiki.CLUSTERS to GDATA_ODS');
wa_exec_no_error('grant execute on DB.DBA.WA_SEARCH_WIKI_GET_EXCERPT_HTML to GDATA_ODS');
wa_exec_no_error('grant execute on DB.DBA.RDF_MAKE_IID_OF_QNAME_SAFE to GDATA_ODS');
wa_exec_no_error('grant execute on DB.DBA.RDF_SQLVAL_OF_OBJ to GDATA_ODS');
wa_exec_no_error('grant execute on DB.DBA.WA_SEARCH_USER_GET_EXCERPT_HTML to GDATA_ODS');
wa_exec_no_error('grant execute on DB.DBA.WA_SEARCH_USER_GET_EXCERPT_HTML to GDATA_ODS');
wa_exec_no_error('grant execute on DB.DBA.WA_SEARCH_NNTP_GET_EXCERPT_HTML to GDATA_ODS');
wa_exec_no_error('grant execute on DB.DBA.WA_SEARCH_DAV_GET_EXCERPT_HTML to GDATA_ODS');
wa_exec_no_error('grant execute on DB.DBA.WA_SEARCH_USER_GET_EXCERPT_HTML to GDATA_ODS');
wa_exec_no_error('grant execute on DB.DBA.wa_identity_dstype to GDATA_ODS');
wa_exec_no_error('grant execute on DB.DBA.WA_SEARCH_ADD_SID_IF_AVAILABLE to GDATA_ODS');
wa_exec_no_error('grant execute on DB.DBA.WA_SEARCH_ADD_APATH to GDATA_ODS');
wa_exec_no_error('grant execute on DB.DBA.WA_SEARCH_CALENDAR_GET_EXCERPT_HTML to GDATA_ODS');
wa_exec_no_error('grant execute on DB.DBA.WA_SEARCH_BLOG_GET_EXCERPT_HTML to GDATA_ODS');
wa_exec_no_error('grant execute on DB.DBA.WA_SEARCH_ENEWS_GET_EXCERPT_HTML to GDATA_ODS');
wa_exec_no_error('grant execute on DB.DBA.WA_SEARCH_OMAIL_AGG_init to GDATA_ODS');
wa_exec_no_error('grant execute on DB.DBA.WA_SEARCH_OMAIL_AGG_acc to GDATA_ODS');
wa_exec_no_error('grant execute on DB.DBA.WA_SEARCH_OMAIL_AGG_final to GDATA_ODS');
wa_exec_no_error('grant execute on DB.DBA.WA_SEARCH_OMAIL_GET_EXCERPT_HTML to GDATA_ODS');
wa_exec_no_error('grant execute on DB.DBA.WA_SEARCH_DAV_OR_WIKI_GET_EXCERPT_HTML to GDATA_ODS');
wa_exec_no_error('grant execute on DB.DBA.WA_SEARCH_BMK_GET_EXCERPT_HTML to GDATA_ODS');
wa_exec_no_error('grant execute on DB.DBA.WA_SEARCH_POLLS_GET_EXCERPT_HTML to GDATA_ODS');
wa_exec_no_error('grant execute on DB.DBA.WA_SEARCH_AB_GET_EXCERPT_HTML to GDATA_ODS');
wa_exec_no_error('grant execute on DB.DBA.WA_SEARCH_AB_GET_EXCERPT_HTML to GDATA_ODS');
wa_exec_no_error('grant execute on DB.DBA.WA_SEARCH_APP_GET_EXCERPT_HTML to GDATA_ODS');



--drop of DB.DBA copies of the procedures
wa_exec_no_error('drop procedure DB.DBA._hex_sha1_digest');
wa_exec_no_error('drop procedure DB.DBA.connections_get');
wa_exec_no_error('drop procedure DB.DBA.connectionSet');
wa_exec_no_error('drop procedure DB.DBA.connectionsGet');
wa_exec_no_error('drop procedure DB.DBA.connectionsSearch');
wa_exec_no_error('drop procedure DB.DBA.constructFieldsNameStr');
wa_exec_no_error('drop procedure DB.DBA.constructSearchQuery');
wa_exec_no_error('drop procedure DB.DBA.constructTypePackageArr');
wa_exec_no_error('drop procedure DB.DBA.constructUsersIdStr');
wa_exec_no_error('drop procedure DB.DBA.createApplication');
wa_exec_no_error('drop procedure DB.DBA.feedStatus');
wa_exec_no_error('drop procedure DB.DBA.feedStatusSet');
wa_exec_no_error('drop procedure DB.DBA.genErrXml');
wa_exec_no_error('drop procedure DB.DBA.httpErrXml');
wa_exec_no_error('drop procedure DB.DBA.httpResXml');
wa_exec_no_error('drop procedure DB.DBA.installedPackages');
wa_exec_no_error('drop procedure DB.DBA.invitations_get');
wa_exec_no_error('drop procedure DB.DBA.invitationsGet');
wa_exec_no_error('drop procedure DB.DBA.invited_get');
wa_exec_no_error('drop procedure DB.DBA.isSessionValid');
wa_exec_no_error('drop procedure DB.DBA.openIdCheckAuthentication');
wa_exec_no_error('drop procedure DB.DBA.openIdServer');
wa_exec_no_error('drop procedure DB.DBA.search');
wa_exec_no_error('drop procedure DB.DBA.serverSettings');
wa_exec_no_error('drop procedure DB.DBA.sessionEnd');
wa_exec_no_error('drop procedure DB.DBA.sessionStart');
wa_exec_no_error('drop procedure DB.DBA.sessionValidate');
wa_exec_no_error('drop procedure DB.DBA.userCommunities');
wa_exec_no_error('drop procedure DB.DBA.userDiscussionGroups');
wa_exec_no_error('drop procedure DB.DBA.userinfo_xml');
wa_exec_no_error('drop procedure DB.DBA.userMessages');
wa_exec_no_error('drop procedure DB.DBA.userMessageSend');
wa_exec_no_error('drop procedure DB.DBA.userMessageStatusSet');
wa_exec_no_error('drop procedure DB.DBA.username2id');
wa_exec_no_error('drop procedure DB.DBA.userid');
wa_exec_no_error('drop procedure DB.DBA.usersGetInfo');
wa_exec_no_error('drop procedure DB.DBA.usersinfo_sql');
wa_exec_no_error('drop procedure DB.DBA.VSPX_EXPIRE_ANONYMOUS_SESSIONS');
wa_exec_no_error('drop procedure DB.DBA.xml_nodename');

USE ODS;

create procedure sessionStart (in realm varchar :='wa') __SOAP_HTTP 'text/xml'
{
  declare errCode integer;
  declare errMsg,sid varchar;
  declare resXml any;

  resXml  := string_output ();
  errCode := 0;
  errMsg  := '';

  sid:=DB.DBA.vspx_sid_generate ();

  insert into DB.DBA.VSPX_SESSION (VS_SID, VS_REALM, VS_UID, VS_EXPIRY) 
         values (sid, realm, 'nobody', now ());

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

  declare exit handler for sqlstate '*' 
    {
      errCode := 4;
                                         errMsg :='Unable to end session';
                                        };

  delete from DB.DBA.VSPX_SESSION 
    where VS_SID = sid and 
          VS_REALM = realm;

  http('<session>'||sid||'</session>',resXml);

  if(errCode<>0)
   httpErrXml(errCode,errMsg,'sessionEnd');
  else
   httpResXml(resXml,'sessionEnd');

  return '';
}
;

grant execute on sessionEnd to GDATA_ODS;

create procedure sessionValidateX509 (
  in redirect integer := 2)
{
  declare uname varchar;
  if (check_authentication_ssl(uname))
    return vector(uname);
  else
	  return NULL;
      }
;

create procedure sessionValidate (
  in sid varchar,
                                  in realm varchar :='wa', 
				  in userName varchar := '', 
	in authStr varchar := '',
	in X509 integer := 0,
	in facebookUID integer := 0) __SOAP_HTTP 'text/xml'
{
  declare errCode integer;
  declare errMsg varchar;
  declare resXml any;

  resXml  := string_output ();
  errCode := 0;
  errMsg  := '';

  if (facebookUID <> 0)
  {
    userName := (select U_NAME from DB.DBA.WA_USER_INFO, DB.DBA.SYS_USERS where WAUI_U_ID = U_ID and WAUI_FACEBOOK_ID = facebookUID);
    if (isnull (userName))
      goto _authbad;

    goto _createSession;
  }
  else if (X509 = 1)
  {
    declare data any;

    data := ODS.DBA.sessionValidateX509 ();
    if (isnull (data))
      goto _authbad;

    userName := data[0];
    goto _createSession;
  }
  else
  {
  if(authStr='' and userName='') -- validate sid
  {
    declare user_name varchar;
    if(isSessionValid(sid,'wa',user_name))
    {
     http('<session>'||sid||'</session>',resXml);
     http('<userName>'||user_name||'</userName>',resXml);
     http('<userId>'||cast(username2id(user_name) as varchar)||'</userId>',resXml);
     http('<dba>'||cast(is_dba(user_name) as varchar)||'</dba>',resXml);

     goto _output;
        }
     goto _authbad;
    } 
  else                            -- bind sid to user
  {
    declare pwd varchar;

    if(userName='')
       goto _authbad;

      pwd := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from DB.DBA.SYS_USERS where U_NAME = userName and U_DAV_ENABLE = 1 and U_ACCOUNT_DISABLED = 0);
      if (_hex_sha1_digest (sid || userName || pwd) <> authStr)
        goto _authbad;

    _createSession:
          declare exit handler for sqlstate '*' 
            {
              goto _authbad;
            };

          update DB.DBA.VSPX_SESSION 
            set VS_UID    = userName,
                                     VS_EXPIRY=now(),
                                     VS_STATE= serialize ( vector ( 'vspx_user', userName))
            where VS_SID = sid and 
                  VS_REALM = realm and 
                  VS_UID = 'nobody';

      http('<session>'||sid||'</session>',resXml);
      http('<userName>'||userName||'</userName>',resXml);
      http('<userId>'||cast(username2id(userName) as varchar)||'</userId>',resXml);
      http('<dba>'||cast(is_dba(userName) as varchar)||'</dba>',resXml);

      goto _output;
        }
  }

_authbad:
  errCode := 1;
  errMsg  := 'Authentication incorrect.';
  goto _output;

_ipblocked:
  errCode := 5;
  errMsg  := 'Requests from '|| http_client_ip () || ' are temporary blocked';
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

create procedure usersGetInfo (
  in sid varchar := '',
	      in realm varchar  := 'wa', 
	      in usersStr varchar, 
	      in fieldsStr varchar) __SOAP_HTTP 'text/xml'
{
  declare errCode integer;
  declare errMsg varchar;
  declare resXml any;

  resXml  := string_output ();
  errCode := 0;
  errMsg  := '';

  declare _uname varchar;
     declare qry,state, msg, maxrows, metas, rset any;

     rset := null;
     maxrows := 0;
     state := '00000';
     msg := '';
     qry := usersinfo_sql(usersStr,fieldsStr);
     exec (qry, state, msg, vector(), maxrows, metas, rset);
     if (state = '00000' and length(rset)>0)
     {
      declare i integer;

      for(i:=0;i<length(rset);i:=i+1)
      {
          declare node_name, node_value, section_name, cursor_uname varchar;
        declare xml_sections,nodename_parts any;
        declare k integer;

        xml_sections:=vector();

        http('<user>',resXml);

          cursor_uname := cast (userid2name (rset[i][0]) as varchar);
        for(k:=0;k<length(metas[0]);k:=k+1)
        {
          declare visibility_arr any;
          declare is_friend,visibility_pos,is_visible integer;

              visibility_arr := DB.DBA.WA_USER_VISIBILITY (cursor_uname);

          is_visible:=0;
	  visibility_pos:=visibility_posinarr(metas[0][k][0]);

              if (isSessionValid (sid, 'wa', _uname))
          {

                  is_friend := DB.DBA.WA_USER_IS_FRIEND (username2id (_uname), username2id (cursor_uname));

            --3 private;2 friends;1 public

            if(visibility_pos>-1)
            {
                      if (atoi (visibility_arr[visibility_pos]) = 1 or 
                          (atoi (visibility_arr[visibility_pos]) = 2 and is_friend))
                  is_visible := 1;
                      else 
                        if (_uname = cursor_uname)

                  is_visible := 1;
                    }
                  else
              is_visible := 1;
                }
              else
          {
                  if (visibility_pos = -1 or atoi (visibility_arr[visibility_pos]) = 1)  
                    is_visible := 1;
          }

          if(is_visible)
             node_value:=cast(rset[i][k] as varchar);
          else
            node_value:='';


          node_name:=xml_nodename(metas[0][k][0]);
          nodename_parts:=split_and_decode(node_name,0,'\0\0_');


          if(length(nodename_parts)<2)
          {
             if(node_name<>'')
                http('<'||node_name||'>'||node_value||'</'||node_name||'>',resXml);
                }
              else
          {
             declare pos integer;

             pos:=position (nodename_parts[0], xml_sections);

             if(pos>0)
                    xml_sections[pos] := get_keyword (nodename_parts[0], 
		                                      xml_sections, '') || 
                                         '<' || 
                                         nodename_parts[1] || 
                                         '>' || 
                                         node_value || 
                                         '</' || 
                                         nodename_parts[1] || 
                                         '>';
                  else
                    xml_sections := vector_concat (xml_sections, 
                                                   vector (nodename_parts[0],
                                                           get_keyword (nodename_parts[0], xml_sections, '') || 
                                                           '<' || 
                                                           nodename_parts[1] || 
                                                           '>' || 
                                                           node_value || 
                                                           '</' || 
                                                           nodename_parts[1] || 
                                                           '>'));
          }
        }

        if(length(xml_sections))
            { 
              declare l integer;

          for(l:=0;l<length(xml_sections);l:=l+2)
          {
            http('<'||xml_sections[l]||'>'||xml_sections[l+1]||'</'||xml_sections[l]||'>',resXml);
          }
        }
        http('</user>',resXml);
      }

    }
  else
     {
        errCode := 10;
      errMsg  := 'Query execution failed';
     }

     if(errCode<>0)
      httpErrXml(errCode,errMsg,'usersGetInfo');
     else
      httpResXml(resXml,'usersGetInfo');
--  }

  return '';
}
;

grant execute on usersGetInfo to GDATA_ODS;

create procedure installedPackages (
  in sid varchar := '',
  in realm varchar :='wa') __SOAP_HTTP 'text/xml'
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
        logged_user_id:=username2id(logged_user_name);
        declare package_name varchar;
        declare packages any;
        packages:=constructTypePackageArr();

        for (select WAT_NAME,WAT_MAXINST from DB.DBA.WA_TYPES) do
        {
          package_name:=get_keyword(WAT_NAME,packages,WAT_NAME);

          if(DB.DBA.wa_check_package(package_name))
          {
           declare inst_count,own_inst_count integer;
           inst_count:=0;
           own_inst_count:=0;

--           inst_count:=(select WMIC_INSTCOUNT from DB.DBA.WA_MEMBER_INSTCOUNT where WMIC_TYPE_NAME=WAT_NAME  and WMIC_UID = logged_user_id);
                  own_inst_count := (select count (WAM_INST) 
                                       from DB.DBA.WA_MEMBER 
                                      where WAM_APP_TYPE = WAT_NAME and  
                                            WAM_MEMBER_TYPE = 1 and 
                                            WAM_USER = logged_user_id);

                  inst_count := (select count (WAM_INST) 
                                   from DB.DBA.WA_MEMBER 
                                  where WAM_APP_TYPE = WAT_NAME and 
                                        WAM_USER = logged_user_id);

           if(inst_count is null)
              inst_count:=0;

           declare defaultinst_homepage varchar;

                  defaultinst_homepage := '';

           if (inst_count>0)
           {
            if(own_inst_count>0)
                        defaultinst_homepage := (select top 1 WAM_HOME_PAGE 
                                                   from DB.DBA.WA_MEMBER 
                                                  where WAM_MEMBER_TYPE = 1 and
                                                        WAM_APP_TYPE = WAT_NAME and 
                                                        WAM_USER = logged_user_id);
                      else
                        defaultinst_homepage := (select top 1 WAM_HOME_PAGE 
                                                   from DB.DBA.WA_MEMBER 
                                                  where WAM_APP_TYPE = WAT_NAME and 
                                                        WAM_USER = logged_user_id);
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
  else
  {
        declare package_name varchar;
        declare packages any;
        packages:=constructTypePackageArr();

        for (select WAT_NAME,WAT_MAXINST from DB.DBA.WA_TYPES) do
        {
          package_name:=get_keyword(WAT_NAME,packages,WAT_NAME);

          if(DB.DBA.wa_check_package(package_name))
          {

           declare defaultinst_homepage varchar;
           defaultinst_homepage:='';

           declare inst_count integer;
           inst_count:=0;

                inst_count := (select count (WAM_INST) 
                                 from DB.DBA.WA_MEMBER 
                                 where WAM_APP_TYPE = WAT_NAME);

           if(inst_count is null)
              inst_count:=0;

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

create procedure applicationsGet (in sid varchar := '',
                                  in realm varchar := 'wa', 
                                  in userIdentity any := null,
                                  in applicationType varchar := null, 
                                  in scope varchar :='all') __SOAP_HTTP 'text/xml'
{
  declare errCode integer;
  declare errMsg varchar;
  declare resXml any;

  resXml  := string_output ();
  errCode := 0;
  errMsg  := '';

  declare ownerId integer;
  if(subseq(userIdentity,0,1)='/')
    ownerId:=username2id(subseq(userIdentity,1));
  else
    ownerId:=cast(userIdentity as integer);

  declare logged_user_id integer;
  declare logged_user_name varchar;


  if(length(sid))
  {
     if(isSessionValid(sid,'wa',logged_user_name))
     {
        logged_user_id:=username2id(logged_user_name);
     }

  }

  declare package_name varchar;
  declare packages any;
  packages:=constructTypePackageArr();

  declare i int;
  declare q_str, rc, dta, h any;

--- XXX!

  if(ownerId is not null and ownerId>-1)
  {
  q_str:='select distinct top 11  WAM_INST as INST_NAME,WAM_HOME_PAGE as INST_URL, WAM_APP_TYPE as INST_WATYPE'||
         ' from DB.DBA.WA_MEMBER, DB.DBA.WA_INSTANCE, DB.DBA.SYS_USERS '||
               ' where WA_MEMBER.WAM_INST = WA_INSTANCE.WAI_NAME and ' || 
               '       WA_MEMBER.WAM_USER = SYS_USERS.U_ID and U_ID=' || sprintf ('%d', ownerId) || ' and' || 
               '       WAI_IS_PUBLIC = 1 ';
    }
  else
  {
  q_str:='select distinct top 11  WAM_INST as INST_NAME,WAM_HOME_PAGE as INST_URL, WAM_APP_TYPE as INST_WATYPE'||
         ' from DB.DBA.WA_MEMBER, DB.DBA.WA_INSTANCE '||
         ' where WA_MEMBER.WAM_INST=WA_INSTANCE.WAI_NAME ';
  }

  if(logged_user_id is not null)
  {
    if(scope='own')
       q_str:=sprintf('%s and WAM_USER=%d ',q_str,logged_user_id);
    else
       q_str:=sprintf('%s and (WAI_IS_PUBLIC=1 or WAM_USER=%d) ',q_str,logged_user_id);

    } 
  else
    q_str:=sprintf('%s and WAI_IS_PUBLIC=1 ',q_str);

  if(applicationType is not null)
  {
    declare watypes_arr any;
    watypes_arr:=constructTypePackageArr('wa_types');

    declare watype_name varchar;
    watype_name:=get_keyword(applicationType,watypes_arr,applicationType);

    q_str:=sprintf('%s and WAM_APP_TYPE = ''%s'' ',q_str,watype_name);
  }

  q_str:=sprintf('%s order by  WAM_APP_TYPE,WAM_INST ',q_str);

  declare INST_URL,INST_NAME,INST_OWNER, INST_WATYPE varchar;

  rc := exec (q_str, null, null, vector (), 0, null, null, h);
  while (0 = exec_next (h, null, null, dta))
  {
    exec_result (dta);

    INST_URL:=coalesce(dta[1],'javascript:void(0)');
    INST_NAME:=coalesce(dta[0],'');
    INST_OWNER:=DB.DBA.WA_APP_GET_OWNER(dta[0]);
    INST_WATYPE:=dta[2];

    declare dataspace_url varchar;

    dataspace_url:=sprintf('/dataspace/%U/%s/%s',INST_OWNER,DB.DBA.wa_get_app_dataspace(INST_WATYPE),INST_NAME);

    package_name:=get_keyword(INST_WATYPE,packages,INST_WATYPE);

    declare disabled integer;

--    disabled:=(select WAT_MAXINST from DB.DBA.WA_TYPES where WAT_NAME=INST_WATYPE);
    if((select WAT_MAXINST from DB.DBA.WA_TYPES where WAT_NAME=INST_WATYPE)=0)
        disabled:=1;
    else
        disabled:=0;

    declare owned integer;
    if(logged_user_name is not null and ownerId is null)
    {
      if(logged_user_name=INST_OWNER)
         owned:=1;
      else
         owned:=0;
    }else if(ownerId=username2id(INST_OWNER))
       owned:=1;
    else
       owned:=0;

     http('<application type="'||package_name||'" '||
                        'url="'||INST_URL||'" '||
                        'dataspace="'||dataspace_url||'" '||
                        'own="'||sprintf('%d',owned)||'" '||
                        'disabled="'||sprintf('%d',disabled)||'" '||
                        '><![CDATA['||INST_NAME||']]></application>',resXml);
  };


  if(errCode<>0)
     httpErrXml(errCode,errMsg,'applicationsGet');
  else
     httpResXml(resXml,'applicationsGet');

  return '';
}
;
grant execute on applicationsGet to GDATA_ODS;

create procedure createApplication (
  in sid varchar := '',
                   in realm varchar := 'wa', 
                   in application varchar) __SOAP_HTTP 'text/xml'
{
  declare errCode integer;
  declare errMsg varchar;
  declare resXml any;
  declare _uname varchar;

  resXml  := string_output ();
  errCode := 0;
  errMsg  := '';
  if (isSessionValid (sid, 'wa', _uname))
  {
        declare watype_name,wainstance_name,full_user_name varchar;
    declare watypes_arr any;

    watypes_arr := constructTypePackageArr ('wa_types');
        watype_name:=get_keyword(application,watypes_arr,application);
    full_user_name := (select coalesce (WAUI_FULL_NAME, trim (concat (WAUI_FIRST_NAME,' ',WAUI_LAST_NAME)))
                           from DB.DBA.WA_USER_INFO 
                           where WAUI_U_ID = username2id (_uname));
        if(length(full_user_name)=0)
        full_user_name := _uname;

      --wainstance_name := full_user_name || '\'s ' || application; --'
      if (application = 'Wiki')
      {
		wainstance_name := replace(full_user_name || application, ' ', '_');
	  }
    else if (application = 'Mail')
    {
      declare pos integer;
      declare domain varchar;

      domain := (select top 1 WD_DOMAIN from DB.DBA.WA_DOMAINS);
      if (isnull (domain))
      {
        errCode := 500;
        errMsg := 'No domains available.';
        goto _exit;
      }
      pos := strstr (concat (domain, ':'), ':');
      wainstance_name := concat (_uname, '@', substring (domain, 1, pos));
    }
	  else
    {
		  wainstance_name := full_user_name || '''s ' || application;
		}

        declare create_res any;

      create_res := DB.DBA.ODS_CREATE_NEW_APP_INST (watype_name, wainstance_name, _uname);
        if(create_res>0)
        {
      declare application_url varchar;

      application_url := (select WAM_HOME_PAGE from DB.DBA.WA_MEMBER where WAM_INST = wainstance_name);
          http('<application>',resXml);
          http('<type>'||application||'</type>',resXml);
          http('<name>'||wainstance_name||'</name>',resXml);
          http('<url>'||application_url||'</url>',resXml);
          http('</application>',resXml);

        }
      else
        {
          errCode:=500;
          errMsg:=create_res;
        }
  }
_exit:;
  if(errCode<>0)
     httpErrXml(errCode,errMsg,'createApplication');
  else
     httpResXml(resXml,'createApplication');

  return '';
}
;

grant execute on createApplication to GDATA_ODS;

create procedure checkApplication (
  in sid varchar := '',
  in realm varchar := 'wa',
  in application varchar) __SOAP_HTTP 'text/xml'
{
  declare _uname varchar;
  declare errCode integer;
  declare errMsg varchar;
  declare resXml any;

  resXml  := string_output ();
  errCode := 0;
  errMsg  := '';

  if (isSessionValid (sid, 'wa', _uname))
  {
    declare watype_name, wainstance_name varchar;
    declare application_url varchar;
    declare watypes_arr any;

    watypes_arr := constructTypePackageArr ('wa_types');
    watype_name := get_keyword (application, watypes_arr, application);
    if (watype_name <> 'Discussion')
    {
	  wainstance_name := (select TOP 1 c.WAI_NAME
                          from DB.DBA.SYS_USERS a,
                               DB.DBA.WA_MEMBER b,
                               DB.DBA.WA_INSTANCE c
                         where a.U_ID = username2id (_uname)
                           and b.WAM_USER = a.U_ID
                           and b.WAM_MEMBER_TYPE = 1
                           and b.WAM_INST = c.WAI_NAME
                           and c.WAI_TYPE_NAME = watype_name);
 	  if (isnull (wainstance_name))
	    return createApplication (sid, realm, application);
    application_url := (select WAM_HOME_PAGE from DB.DBA.WA_MEMBER where WAM_INST = wainstance_name);
	  }
	  else
	  {
	    wainstance_name := application;
      application_url := '/nntpf/nntpf_main.vspx';
	  }
    http ('<application>', resXml);
    http ('<type>' || application || '</type>', resXml);
    http ('<name>' || wainstance_name || '</name>', resXml);
    http ('<url>' || application_url || '</url>',resXml);
    http ('</application>', resXml);

    httpResXml (resXml, 'checkApplication');
  }
  return '';
}
;

grant execute on checkApplication to GDATA_ODS;

create procedure invitationsGet (in sid varchar:='',in realm varchar :='wa', in extraFields varchar :='') __SOAP_HTTP 'text/xml'
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
--      _sneid_logged_user := (select sne_id from sn_person where sne_name=logged_user_name);


      declare invitation_authors any;
      invitation_authors:=invitations_get(logged_user_name);

      declare i integer;
      for(i:=0; i< length(invitation_authors); i:=i+1)
      {
          if(extraFields='')
             http('<invitation><uid>'||cast(invitation_authors[i] as varchar)||'</uid></invitation>',resXml);
          else
          {
            declare qry,state, msg, maxrows, metas, rset any;

            rset := null;
            maxrows := 0;
            state := '00000';
            msg := '';
            qry := usersinfo_sql(cast(invitation_authors[i] as varchar),extraFields);
            exec (qry, state, msg, vector(), maxrows, metas, rset);
            if (state = '00000' and length(rset)>0)
            {
              declare l integer;

              for(l:=0;l<length(rset);l:=l+1)
              {

                http('<invitation>',resXml);
                http('<uid>'||cast(invitation_authors[i] as varchar)||'</uid>',resXml);

                http(userinfo_xml(metas,rset,l),resXml);

                declare _sneid_current_user integer;
                _sneid_current_user := (select sne_id from DB.DBA.sn_person where sne_org_id=invitation_authors[i]);

                if(_sneid_current_user is not null)
                {
                   http(sprintf('<connections><count>%d</count></connections>',length(connections_get(_sneid_current_user))),resXml);

                }else
                  http('<connections><count>0</count></connections>',resXml);


                http('</invitation>',resXml);
              }
            }
          }
      }
  }else return '';

  if(errCode<>0)
     httpErrXml(errCode,errMsg,'invitationsGet');
  else
     httpResXml(resXml,'invitationsGet');

  return '';
}
;
grant execute on invitationsGet to GDATA_ODS;

create procedure userinfo_xml(in metas any,in rset any, in idx integer)
{
   declare resXml any;
   resXml  := string_output ();

   declare node_name,section_name varchar;
   declare xml_sections,nodename_parts any;
   declare k integer;

   xml_sections:=vector();

   for(k:=0;k<length(metas[0]);k:=k+1)
   {
     node_name:=xml_nodename(metas[0][k][0]);
     nodename_parts:=split_and_decode(node_name,0,'\0\0_');

     if(length(nodename_parts)<2)
     {
        if(node_name<>'')
           http('<'||node_name||'>'||cast(rset[idx][k] as varchar)||'</'||node_name||'>',resXml);
     }else
     {
        declare pos integer;

        pos:=position (nodename_parts[0], xml_sections);
        if(pos>0)
          xml_sections[pos]:=get_keyword(nodename_parts[0],xml_sections,'')||'<'||nodename_parts[1]||'>'||cast(rset[idx][k] as varchar)||'</'||nodename_parts[1]||'>';
        else
        xml_sections:=vector_concat(xml_sections,vector(nodename_parts[0],
                                                        get_keyword(nodename_parts[0],xml_sections,'')||'<'||nodename_parts[1]||'>'||cast(rset[idx][k] as varchar)||'</'||nodename_parts[1]||'>'
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

  return string_output_string(resXml);
}
;

create procedure connectionsGet (in sid varchar:='',in realm varchar :='wa', in userId any := null, in extraFields varchar :='') __SOAP_HTTP 'text/xml'
{
  declare errCode integer;
  declare errMsg varchar;
  declare resXml any;

  resXml  := string_output ();
  errCode := 0;
  errMsg  := '';

  declare logged_user_name varchar;
  isSessionValid(sid,'wa',logged_user_name);
--  if(isSessionValid(sid,'wa',logged_user_name))
--  {

      declare _sneid,_sneid_logged_user integer;
      _sneid_logged_user := (select sne_id from DB.DBA.sn_person where sne_name=logged_user_name);

      if( userId is not null)
      {
          if(subseq(userId,0,1)='/')
             userId:=username2id(subseq(userId,1));
          else
             userId:=cast(userId as integer);

         _sneid := (select sne_id from DB.DBA.sn_person where sne_org_id=userId);
      } else
         _sneid := _sneid_logged_user;

      if(_sneid is null)
      {
        errCode := 20;
        errMsg  := 'Social network user name does not exist.';

        goto _err;
      }

      declare connections, invited, conn_inv any;
      connections:=connections_get(_sneid);
      invited:=invited_get(logged_user_name);

      if(username2id(logged_user_name)=userId)
         conn_inv:=vector_concat(connections,invited);
      else
         conn_inv:=connections;

      declare i integer;
      for(i:=0; i< length(conn_inv); i:=i+1)
      {
          if(extraFields='')
             http('<user><uid>'||cast(conn_inv[i] as varchar)||'</uid></user>',resXml);
          else
          {
            declare qry,state, msg, maxrows, metas, rset any;

            rset := null;
            maxrows := 0;
            state := '00000';
            msg := '';
            qry := usersinfo_sql(cast(conn_inv[i] as varchar),extraFields);
            exec (qry, state, msg, vector(), maxrows, metas, rset);
            if (state = '00000' and length(rset)>0)
            {
              declare l integer;

              for(l:=0;l<length(rset);l:=l+1)
              {

                http('<user>',resXml);
                http('<uid>'||cast(conn_inv[i] as varchar)||'</uid>',resXml);
                http(userinfo_xml(metas,rset,l),resXml);
                if(position(conn_inv[i],invited)>0)
                   http('<invited>1</invited>',resXml);
                http('</user>',resXml);
              }
           }
          }
      }
_err:

  if(errCode<>0)
     httpErrXml(errCode,errMsg,'connectionsGet');
  else
     httpResXml(resXml,'connectionsGet');

  return '';
}
;
grant execute on connectionsGet to GDATA_ODS;

create procedure connectionSet (in sid varchar:='',in realm varchar :='wa', in connectionId integer, in action integer) __SOAP_HTTP 'text/xml'
{

  -- action invite 1,confirm 2, reject 3, withdraw invitation 4, disconnect 0

  declare errCode integer;
  declare errMsg varchar;
  declare resXml any;

  resXml  := string_output ();
  errCode := 0;
  errMsg  := '';

  declare logged_user_name varchar;
  if(isSessionValid(sid,'wa',logged_user_name))
  {
    declare exit handler for sqlstate '*' {
      dbg_obj_print (__SQL_STATE, ' ', __SQL_MESSAGE);
                                             errCode := 10;
                                             errMsg  := 'Can not execute query.';
                                             goto _err;
                                             };

      declare _sneid_user,_sneid_connection integer;
      _sneid_user := (select sne_id from DB.DBA.sn_person where sne_name=logged_user_name);
      _sneid_connection:= (select sne_id from DB.DBA.sn_person where sne_org_id=connectionId);


      declare connection_email,logged_user_email,msg varchar;
      connection_email:=(select U_E_MAIL from DB.DBA.SYS_USERS where U_ID=connectionId);
      logged_user_email:=(select U_E_MAIL from DB.DBA.SYS_USERS where U_NAME=logged_user_name);


      if(_sneid_connection is not null)
      {

       if(action=1)
       {
        if(username2id(logged_user_name)=connectionId)
        {
          http('<message>Unable to invite yourself.</message>',resXml);
          goto _err;
        }

	      if(exists(select 1 from DB.DBA.sn_related where ( (snr_from=_sneid_user and snr_to=_sneid_connection ) or (snr_from=_sneid_connection and snr_to=_sneid_user ) ) and snr_source=1))
        {
          http('<message>You are already connected to this user.</message>',resXml);
          goto _err;
        }

	      if(exists(select 1 from DB.DBA.sn_invitation where sni_from = _sneid_user and sni_to = connection_email and sni_status=0))
        {
          http('<message>User already invited.</message>',resXml);
          goto _err;
        }

        http('<message>Invitation sent.</message>',resXml);

	      declare  url, banner,email varchar;
        banner := (select top 1 coalesce(WS_WEB_TITLE,'ODS') from DB.DBA.WA_SETTINGS);
        if (length(banner)=0)
            banner:='<a href="'||DB.DBA.WA_LINK(1, '/ods/')||'" target="_blank">ODS</a>';

        url := DB.DBA.WA_LINK(1, '/ods/index.html#invitations');
        url := '<a href="'||url||'" target="_blank">'||url||'</a>';
        msg :='I have sent you an invitation. To join my network please visit : '||url;

        insert into DB.DBA.WA_MESSAGES (WM_SENDER_UID,WM_RECIPIENT_UID,WM_TS,WM_MESSAGE,WM_SENDER_MSGSTATUS,WM_RECIPIENT_MSGSTATUS)
            values (username2id(logged_user_name),connectionId,now(),msg,0,0);

	      if(exists(select 1 from DB.DBA.sn_invitation where sni_from = _sneid_user and sni_to = connection_email))
	         update DB.DBA.sn_invitation set sni_status=0 where sni_from = _sneid_user and sni_to = connection_email;
	      else
	         insert soft DB.DBA.sn_invitation (sni_from, sni_to, sni_status) values (_sneid_user, connection_email, 0);
       }
       else if (action=2 and (not exists(select 1 from DB.DBA.sn_related where ( (snr_from=_sneid_user and snr_to=_sneid_connection ) or (snr_from=_sneid_connection and snr_to=_sneid_user ) ) and snr_source=1)))
       {
        insert into DB.DBA.sn_related (snr_from,snr_to,snr_serial,snr_source,snr_confirmed) values (_sneid_user,_sneid_connection,0,1,1);
        delete from DB.DBA.sn_invitation where sni_from = _sneid_connection and sni_to = logged_user_email;
        msg :=DB.DBA.WA_USER_FULLNAME(logged_user_name) || ' has accepted your invitation.';
        insert into DB.DBA.WA_MESSAGES (WM_SENDER_UID,WM_RECIPIENT_UID,WM_TS,WM_MESSAGE,WM_SENDER_MSGSTATUS,WM_RECIPIENT_MSGSTATUS)
            values (username2id(logged_user_name),connectionId,now(),msg,0,0);
       }
       else if (action=3 and exists(select 1 from DB.DBA.sn_invitation where sni_from = _sneid_connection and sni_to = logged_user_email))
       {
			        update DB.DBA.sn_invitation set sni_status = -1 where sni_from = _sneid_connection and sni_to = logged_user_email;
              msg :=DB.DBA.WA_USER_FULLNAME(logged_user_name) || ' has rejected your invitation.';
              insert into DB.DBA.WA_MESSAGES (WM_SENDER_UID,WM_RECIPIENT_UID,WM_TS,WM_MESSAGE,WM_SENDER_MSGSTATUS,WM_RECIPIENT_MSGSTATUS)
                  values (username2id(logged_user_name),connectionId,now(),msg,0,0);
       }
       else if (action=0 and exists(select 1 from DB.DBA.sn_related where ( (snr_from=_sneid_user and snr_to=_sneid_connection ) or (snr_from=_sneid_connection and snr_to=_sneid_user)) and snr_source=1))
       {
        delete from DB.DBA.sn_related where ( (snr_from=_sneid_user and snr_to=_sneid_connection ) or (snr_from=_sneid_connection and snr_to=_sneid_user ) ) and snr_source=1;
        delete from DB.DBA.sn_invitation where sni_from=_sneid_user and sni_to=connection_email;
        msg :=DB.DBA.WA_USER_FULLNAME(logged_user_name) || ' has disconnected you from his network.';
        insert into DB.DBA.WA_MESSAGES (WM_SENDER_UID,WM_RECIPIENT_UID,WM_TS,WM_MESSAGE,WM_SENDER_MSGSTATUS,WM_RECIPIENT_MSGSTATUS)
               values (username2id(logged_user_name),connectionId,now(),msg,0,0);
       }
       else if (action=4 and exists(select 1 from DB.DBA.sn_invitation where sni_from=_sneid_user and sni_to=connection_email))
       {
        delete from DB.DBA.sn_invitation where sni_from=_sneid_user and sni_to=connection_email;
        msg :=DB.DBA.WA_USER_FULLNAME(logged_user_name) || ' has withdrawn his invitation.';
        insert into DB.DBA.WA_MESSAGES (WM_SENDER_UID,WM_RECIPIENT_UID,WM_TS,WM_MESSAGE,WM_SENDER_MSGSTATUS,WM_RECIPIENT_MSGSTATUS)
               values (username2id(logged_user_name),connectionId,now(),msg,0,0);
       }
      }
  } else
    return '';

_err:
  if(errCode<>0)
     httpErrXml(errCode,errMsg,'connectionSet');
  else
     httpResXml(resXml,'connectionSet');

  return '';
}
;
grant execute on connectionSet to GDATA_ODS;


create procedure connectionsSearch (
  in sid varchar:='',
  in realm varchar :='wa',
  in connectionId integer,
  in action integer) __SOAP_HTTP 'text/xml'
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
    ;
  }else return '';

_err:
  if(errCode<>0)
     httpErrXml(errCode,errMsg,'connectionsSearch');
  else
     httpResXml(resXml,'connectionsSearch');

  return '';
}
;
grant execute on connectionsSearch to GDATA_ODS;

--
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
        for(select WAM_INST,WAM_HOME_PAGE from DB.DBA.WA_MEMBER where WAM_APP_TYPE='Community' and WAM_USER=username2id(logged_user_name)) do
        {

          http('<community>',resXml);
          http('<name>'||WAM_INST||'</name>',resXml);
          http('<url>'||WAM_HOME_PAGE||'</url>',resXml);
          http('</community>',resXml);
        }
  } else {
        for(select WAM_INST,WAM_HOME_PAGE from DB.DBA.WA_MEMBER where WAM_APP_TYPE='Community' and WAM_IS_PUBLIC=1) do
        {
          http('<community>',resXml);
          http('<name>'||WAM_INST||'</name>',resXml);
          http('<url>'||WAM_HOME_PAGE||'</url>',resXml);
          http('</community>',resXml);

        }
  }
  http('<community_package>'||sprintf('%d',DB.DBA.wa_check_package('Community'))||'</community_package>',resXml);


  if(errCode<>0)
     httpErrXml(errCode,errMsg,'userCommunities');
  else
     httpResXml(resXml,'userCommunities');

  return '';
}
;
grant execute on userCommunities to GDATA_ODS;

create procedure userDiscussionGroups (in sid varchar:='',in realm varchar :='wa', in userId any := null) __SOAP_HTTP 'text/xml'
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
      {
        if(subseq(userId,0,1)='/')
           logged_user_id:=username2id(subseq(userId,1));
        else
           logged_user_id:=cast(userId as integer);
      }
      else
         logged_user_id := username2id(logged_user_name);


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

create procedure feedStatus (
  in sid varchar:='',
  in realm varchar :='wa') __SOAP_HTTP 'text/xml'
{
  declare errCode integer;
  declare errMsg varchar;
  declare resXml any;

  resXml  := string_output ();
  errCode := 0;
  errMsg  := '';

  declare _uname varchar;
  if (isSessionValid (sid, 'wa', _uname))
  {
    declare logged_user_id integer;
    logged_user_id:=username2id(_uname);
    for(select WAU_A_ID,WAU_STATUS from DB.DBA.WA_ACTIVITIES_USERSET where WAU_U_ID=logged_user_id) do
    {
       http(sprintf('<activity id="%d" status="%d" />',WAU_A_ID,WAU_STATUS),resXml);
    }
  if(errCode<>0)
     httpErrXml(errCode,errMsg,'feedStatus');
  else
     httpResXml(resXml,'feedStatus');
  }
  return '';
}
;

grant execute on feedStatus to GDATA_ODS;

create procedure feedStatusSet (
  in sid varchar:='',
  in realm varchar :='wa',
  in feedId integer,
  in feedStatus integer) __SOAP_HTTP 'text/xml'
{
  declare errCode integer;
  declare errMsg varchar;
  declare resXml any;

  resXml  := string_output ();
  errCode := 0;
  errMsg  := '';

  declare _uname varchar;
  if(isSessionValid(sid,'wa',_uname))
  {
    declare logged_user_id integer;
    logged_user_id:=username2id(_uname);
    if (exists(select 1 from DB.DBA.WA_ACTIVITIES_USERSET where WAU_U_ID=logged_user_id and WAU_A_ID=feedId))
        update DB.DBA.WA_ACTIVITIES_USERSET set WAU_STATUS=feedStatus where WAU_U_ID=logged_user_id and WAU_A_ID=feedId;
    else
        insert into DB.DBA.WA_ACTIVITIES_USERSET(WAU_U_ID,WAU_A_ID,WAU_STATUS) values(logged_user_id,feedId,feedStatus);

  if(errCode<>0)
     httpErrXml(errCode,errMsg,'feedStatusSet');
  else
     httpResXml(resXml,'feedStatusSet');
  }
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

  declare _uname varchar;
  if(isSessionValid(sid,'wa',_uname))
  {
        declare logged_user_id integer;

    logged_user_id:=username2id(_uname);
        if(msgType=0)
        {
            declare new_messages integer;
            new_messages:=0;

            declare exit handler for sqlstate '*' {new_messages:=0;};
            select count(WM_ID) into new_messages from DB.DBA.WA_MESSAGES where WM_RECIPIENT_UID=logged_user_id and WM_RECIPIENT_MSGSTATUS>-1;

            http('<new_message_count>',resXml);
            http(sprintf('%d',new_messages),resXml);
            http('</new_message_count>',resXml);
    }
    else
        {
          declare qry,state, msg, maxrows, metas, rset any;

          rset := null;
          maxrows := 0;
          state := '00000';
          msg := '';


          -- msgType - 1(or no) - All; 2 - inbox; 3 - sent;
          if(msgType=2)
          {
         	 qry := sprintf('select top 100 WM_ID,WM_SENDER_UID,WM_RECIPIENT_UID,WM_TS,WM_MESSAGE,WM_SENDER_MSGSTATUS,WM_RECIPIENT_MSGSTATUS
                              from DB.DBA.WA_MESSAGES
                             where WM_RECIPIENT_UID=%d
                                   and
                                   WM_RECIPIENT_MSGSTATUS>-1
                             order by WM_TS desc',logged_user_id);

      }
      else if (msgType=3)
          {
         	 qry := sprintf('select top 100 WM_ID,WM_SENDER_UID,WM_RECIPIENT_UID,WM_TS,WM_MESSAGE,WM_SENDER_MSGSTATUS,WM_RECIPIENT_MSGSTATUS
                              from DB.DBA.WA_MESSAGES
                             where WM_SENDER_UID=%d
                                   and
                                   WM_SENDER_MSGSTATUS>-1
                             order by WM_TS desc',logged_user_id);
      }
      else
          {
         	 qry := sprintf('select top 100 WM_ID,WM_SENDER_UID,WM_RECIPIENT_UID,WM_TS,WM_MESSAGE,WM_SENDER_MSGSTATUS,WM_RECIPIENT_MSGSTATUS
                              from DB.DBA.WA_MESSAGES
                             where (WM_SENDER_UID=%d and WM_SENDER_MSGSTATUS>-1)
                                   or
                                   (WM_RECIPIENT_UID=%d and WM_RECIPIENT_MSGSTATUS>-1)
                             order by WM_TS desc',logged_user_id,logged_user_id);
          }
          exec (qry, state, msg, vector(), maxrows, metas, rset);
          if (state = '00000' and length(rset)>0)
          {
            declare i integer;

            for(i:=0;i<length(rset);i:=i+1)
            {
              http('<message>',resXml);
              http(sprintf('<sender id="%d">%s</sender>',rset[i][1], DB.DBA.WA_USER_FULLNAME(rset[i][1])),resXml);
              http(sprintf('<recipient id="%d">%s</recipient>',rset[i][2],DB.DBA.WA_USER_FULLNAME(rset[i][2])),resXml);
              http(sprintf('<received>%s</received>',DB.DBA.date_iso8601 (rset[i][3])),resXml);
              http(sprintf('<text><![CDATA[%s]]></text>',rset[i][4]),resXml);
              http(sprintf('<id>%d</id>',rset[i][0]),resXml);
              http('</message>',resXml);
            }
          }
        }
  } else
    return '';

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

  declare _uname varchar;
  if(isSessionValid(sid,'wa',_uname))
  {

     declare logged_user_id,sender_id integer;
     logged_user_id:=username2id(_uname);
     if(senderId<0)
          sender_id:=logged_user_id;
     else sender_id:=senderId;

     declare exit handler for sqlstate '*' {dbg_obj_print (__SQL_STATE, ' ', __SQL_MESSAGE);

                                            errCode := 10;
                                            errMsg  := 'Can not execute query.';
                                            goto _err;
                                           };
     insert into DB.DBA.WA_MESSAGES (WM_SENDER_UID,WM_RECIPIENT_UID,WM_TS,WM_MESSAGE,WM_SENDER_MSGSTATUS,WM_RECIPIENT_MSGSTATUS)
            values (sender_id,recipientId,now(),msg,0,0);

     http(sprintf('<message status="1">%d</message>',identity_value()),resXml);

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

create procedure userMessageStatusSet (in sid varchar,in realm varchar :='wa',in msgId integer, in msgStatus integer) __SOAP_HTTP 'text/xml'
{
  declare errCode integer;
  declare errMsg varchar;
  declare resXml any;

  resXml  := string_output ();
  errCode := 0;
  errMsg  := '';

  declare _uname varchar;
  if(isSessionValid(sid,'wa',_uname))
  {

     declare logged_user_id,sender_id,recipient_id integer;
     logged_user_id:=username2id(_uname);

     declare exit handler for sqlstate '*' {
                                            errCode := 10;
                                            errMsg  := 'Can not execute query.';
                                            goto _err;
                                           };
     select WM_SENDER_UID,WM_RECIPIENT_UID into sender_id,recipient_id from DB.DBA.WA_MESSAGES where WM_ID=msgId;

     if(sender_id=logged_user_id)
     {
        update DB.DBA.WA_MESSAGES set WM_SENDER_MSGSTATUS=-1 where WM_ID=msgId;
    }
    else if (recipient_id=logged_user_id)
     {
        update DB.DBA.WA_MESSAGES set WM_RECIPIENT_MSGSTATUS=-1 where WM_ID=msgId;
     }
     http(sprintf('<message status_updated="1">%d</message>',msgId),resXml);
  } else
    return '';

_err:
  if(errCode<>0)
     httpErrXml(errCode,errMsg,'userMessageStatusSet');
  else
     httpResXml(resXml,'userMessageStatusSet');

  return '';
}
;
grant execute on userMessageStatusSet to GDATA_ODS;

--!
-- \brief Fetch server details from an OpenId.
--
-- Used by the ODS SOAP service openIdServer() and the ODS API function user.openid.authenticationUrl()
--/
create procedure getOpenIdServer (
  in openIdUrl varchar,
  out oi_srv varchar,
  out oi_version varchar,
  out oi_identity varchar,
  out oi_delegate varchar,
  out oi_params varchar)
{
  declare profilePage varchar;

  declare hdr, xt, loc any;
  declare url, xrds_url, cnt, oi2_srv, oi_priority, webid varchar;
  declare exit handler for sqlstate '*'
  {
    signal('501', 'Invalid OpenID URL');
  };

  oi_version := '1.0';
  oi_srv := null;
  oi2_srv := null;
  oi_delegate := null;
  oi_params := 'sreg';
  profilePage := ODS.DBA.WF_PROFILE_GET (openIdUrl);
  if (profilePage is not null)
    openIdUrl := profilePage;
  if (openIdUrl like '%@%' and profilePage is null)
    {
      webid := ODS..FINGERPOINT_WEBID_GET (null, openIdUrl);
      if (webid is not null)
	  openIdUrl := normalize_url_like_browser (webid);
	}

  oi_identity := openIdUrl;

    url := openIdUrl;
again:
  hdr := null;
  cnt := DB.DBA.HTTP_CLIENT_EXT (url=>url, headers=>hdr);
  if (hdr [0] like 'HTTP/1._ 30_ %')
  {
      loc := http_request_header (hdr, 'Location', null, null);
      url := WS.WS.EXPAND_URL (url, loc);
      goto again;
  }
    if (http_request_header (hdr, 'Content-Type') <> 'application/xrds+xml')
    {
  	xrds_url := http_request_header (hdr, 'X-XRDS-Location');
  	if (xrds_url is not null)
	  {
	    cnt := http_client (xrds_url, n_redirects=>15);
	    goto _xrds;
	  }

  xt := xtree_doc (cnt, 2);
  oi_srv := cast (xpath_eval ('//link[contains (@rel, "openid.server")]/@href', xt) as varchar);
      oi2_srv := cast (xpath_eval ('//link[contains (@rel, "openid2.provider")]/@href', xt) as varchar);
  oi_delegate := cast (xpath_eval ('//link[contains (@rel, "openid.delegate")]/@href', xt) as varchar);
      if (oi2_srv is not null)
      {
        oi_version := '2.0';
        oi_srv := oi2_srv;
      }
  }
  else
  {
  _xrds:;
      xt := xtree_doc (cnt);

    -- version 2.0
    oi_srv := cast (xpath_eval ('/XRDS/XRD/Service[Type/text() = "http://specs.openid.net/auth/2.0/signon"]/URI/text()', xt) as varchar);
    if (not isnull (oi_srv))
    {
      oi_priority := cast (xpath_eval ('/XRDS/XRD/Service[Type/text() = "http://specs.openid.net/auth/2.0/signon"]/@priority', xt) as varchar);
      oi_version := '2.0';
      goto _params;
    }

    -- version 1.1
    oi_srv := cast (xpath_eval ('/XRDS/XRD/Service[Type/text() = "http://openid.net/signon/1.1"]/URI/text()', xt) as varchar);
    if (not isnull (oi_srv))
    {
      oi_priority := cast (xpath_eval ('/XRDS/XRD/Service[Type/text() = "http://openid.net/signon/1.1"]/@priority', xt) as varchar);
      oi_version := '1.1';
      goto _params;
  }

    -- version 1.0
    oi_srv := cast (xpath_eval ('/XRDS/XRD/Service[Type/text() = "http://openid.net/signon/1.0"]/URI/text()', xt) as varchar);
    if (not isnull (oi_srv))
  {
      oi_priority := cast (xpath_eval ('/XRDS/XRD/Service[Type/text() = "http://openid.net/signon/1.0"]/@priority', xt) as varchar);
      oi_version := '1.1';
    }
  _params:;
    if (isnull (oi_srv))
      signal ('501', 'Invalid OpenID URL');

    if (not isnull (xpath_eval (sprintf ('/XRDS/XRD/Service[@priority = "%s"]/Type[text() = "http://openid.net/srv/ax/1.0"]/text()', oi_priority), xt)))
      oi_params := 'ax';
  }
}
;

create procedure openIdServer (
  in openIdUrl varchar) __SOAP_HTTP 'text/xml'
{
  declare errCode integer;
  declare errMsg varchar;
  declare resXml any;

  resXml  := string_output ();
  errCode := 0;
  errMsg  := '';

  declare oi_identity, oi_version, oi_srv, oi_delegate, oi_params varchar;
  declare exit handler for sqlstate '*'
  {
    errCode:=501;
    errMsg := 'Invalid OpenID URL';
    goto _end;
  };

  oi_identity := openIdUrl;
  getOpenIdServer(openIdUrl, oi_srv, oi_version, oi_identity, oi_delegate, oi_params);

_exit:;
  http('<version>'||oi_version||'</version>',resXml);
  http('<server>'||oi_srv||'</server>',resXml);
  http('<delegate>'||oi_delegate||'</delegate>',resXml);
  http('<identity>'||oi_identity||'</identity>',resXml);
  http('<params>'||oi_params||'</params>',resXml);

_end:
  if(errCode<>0)
     httpErrXml(errCode,errMsg,'openIdServer');
  else
     httpResXml(resXml,'openIdServer');

  return '';
}
;
grant execute on openIdServer to GDATA_ODS;

create procedure openIdCheckAuthentication (
  in realm varchar :='wa',
  in openIdUrl varchar,
  in openIdIdentity varchar) __SOAP_HTTP 'text/xml'
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
    errMsg := 'OpenID is not registered as user identity.';
    goto _auth_failed;
  };

  select U_NAME into user_name from DB.DBA.WA_USER_INFO, DB.DBA.SYS_USERS where WAUI_U_ID = U_ID and rtrim (WAUI_OPENID_URL, '/') = rtrim (openIdIdentity, '/');

  declare sid varchar;
  sid := DB.DBA.vspx_sid_generate ();
  insert into DB.DBA.VSPX_SESSION (VS_SID, VS_REALM, VS_UID, VS_EXPIRY, VS_STATE) values (sid, realm, user_name, now (),serialize ( vector ( 'vspx_user', user_name)));

  http('<session>'||sid||'</session>',resXml);
  http('<userName>'||user_name||'</userName>',resXml);
  http('<userId>'||cast(username2id(user_name) as varchar)||'</userId>',resXml);

_auth_failed:

  if(errCode<>0)
     httpErrXml(errCode,errMsg,'openIdCheckAuthentication');
  else
     httpResXml(resXml,'openIdCheckAuthentication');

  return '';
}
;
grant execute on openIdCheckAuthentication to GDATA_ODS;

create procedure serverSettings () __SOAP_HTTP 'text/xml'
{
  declare errCode integer;
  declare errMsg varchar;
  declare resXml any;

  resXml  := string_output ();
  errCode := 0;
  errMsg  := '';

  http(sprintf('<uriqaDefaultHost>%s</uriqaDefaultHost>',DB.DBA.WA_CNAME()),resXml);
  http(sprintf('<useRDFB>%d</useRDFB>', (case when DB.DBA.wa_check_package ('OAT') then 1 else 0 end)),resXml);
  http(sprintf('<googleMpasKey>%s</googleMpasKey>', coalesce( (select WMH_KEY from DB.DBA.WA_MAP_HOSTS where WMH_HOST=DB.DBA.WA_CNAME() and WMH_SVC='GOOGLE'),'')),resXml);


_err:
  if(errCode<>0)
     httpErrXml(errCode,errMsg,'serverSettings');
  else
     httpResXml(resXml,'serverSettings');

  return '';
}
;
grant execute on serverSettings to GDATA_ODS;


create procedure search (
  in sid varchar:='',
  in realm varchar :='wa',
  in searchParams varchar := '') __SOAP_HTTP 'text/xml'
{
  declare errCode integer;
  declare errMsg varchar;
  declare resXml any;

  resXml  := string_output ();
  errCode := 0;
  errMsg  := '';

  declare search_params_arr any;
  search_params_arr:=split_and_decode(searchParams);

  declare _uname varchar;
  declare logged_user_id  integer;
  if(isSessionValid(sid,'wa',_uname))
  {
    logged_user_id:=username2id(_uname);
  }else
  {
    logged_user_id:=http_nobody_uid();
  }

  declare on_people,on_apps,on_blogs,on_dav,on_news,on_wikis,on_omail,on_bookmark,on_polls,on_addressbook,on_calendar,on_nntp,sort_by_score,max_rows,s_tag_is_qry,on_all integer;
  declare d_before,d_after,query,sort_order varchar;
  declare q, q_tags nvarchar;
  declare newsgroups_vector,tags_vector,rset, meta, sql_state,sql_msg any;


  q:=charset_recode (get_keyword('q',search_params_arr,''), 'UTF-8', '_WIDE_');
  q_tags:=charset_recode (get_keyword('q_tags',search_params_arr,''), 'UTF-8', '_WIDE_');

  on_all:=get_keyword('on_all',search_params_arr,0);

  on_people:=get_keyword('on_people',search_params_arr,on_all);
  on_apps:=get_keyword('on_apps',search_params_arr,on_all);
  on_dav:=get_keyword('on_dav',search_params_arr,on_all);

  on_news:=get_keyword('on_news',search_params_arr,on_all);
  if(DB.DBA.wa_vad_check ('Feed Manager') is null) on_news:=0;

  on_blogs:=get_keyword('on_blogs',search_params_arr,on_all);
  if(DB.DBA.wa_vad_check ('Weblog') is null) on_blogs:=0;

  on_wikis:=get_keyword('on_wikis',search_params_arr,on_all);
  if(DB.DBA.wa_vad_check ('Wiki') is null) on_wikis:=0;

  on_omail:=get_keyword('on_omail',search_params_arr,on_all);
  if(DB.DBA.wa_vad_check ('Mail') is null) on_omail:=0;

  on_bookmark:=get_keyword('on_bookmark',search_params_arr,on_all);
  if(DB.DBA.wa_vad_check ('Bookmarks') is null) on_bookmark:=0;

  on_polls:=get_keyword('on_polls',search_params_arr,on_all);
  if(DB.DBA.wa_vad_check ('Polls') is null) on_polls:=0;

  on_addressbook:=get_keyword('on_addressbook',search_params_arr,on_all);
  if(DB.DBA.wa_vad_check ('AddressBook') is null) on_addressbook:=0;

  on_calendar:=get_keyword('on_calendar',search_params_arr,on_all);
  if(DB.DBA.wa_vad_check ('Calendar') is null) on_calendar:=0;

  on_nntp:=get_keyword('on_nntp',search_params_arr,on_all);

  sort_by_score:=get_keyword('sort_by_score',search_params_arr,0);
  sort_order:=get_keyword('sort_order',search_params_arr,'desc');
  max_rows:=get_keyword('max_rows',search_params_arr,100);
  s_tag_is_qry:=get_keyword('s_tag_is_qry',search_params_arr,0);
  d_before:=get_keyword('d_before',search_params_arr,'');
  d_after:=get_keyword('d_before',search_params_arr,'');

  newsgroups_vector:=vector();
  tags_vector:=vector();

  query := null;


  query := DB.DBA.WA_SEARCH_CONSTRUCT_QUERY (logged_user_id,
                                             q,
                                             q_tags,
                                             on_people, on_apps, on_blogs, on_dav, on_news, on_wikis, on_omail,
                                             on_bookmark, on_polls, on_addressbook, on_calendar, on_nntp,
                                             sort_by_score,
                                             max_rows,
                                             s_tag_is_qry,
                                             d_before, d_after,
                                             newsgroups_vector,
                                             tags_vector,
                                             sort_order
                                            );


  if (query is not null and length(query)>0)
  {
    sql_state := '00000';

    set_qualifier ('DB');
    set_user_id ('dba');

    exec (query, sql_state, sql_msg, vector (), 0, meta, rset);

    if (sql_state = '00000' and length(rset)>0)
    {
      declare i integer;

      for(i:=0;i<length(rset);i:=i+1)
      {
        declare date_str varchar;
        date_str:='';
        if( rset[i][3] is not null)
         date_str:=sprintf('%02d %02d,%04d',month(rset[i][3]),dayofmonth(rset[i][3]),year(rset[i][3]));
        http('<search_result>',resXml);
        http(sprintf('<html ><![CDATA[%s]]></html>',rset[i][0]),resXml);
        http(sprintf('<tag_table_fk>%s</tag_table_fk>',rset[i][1]),resXml);
        http(sprintf('<score>%d</score>',rset[i][2]),resXml);
--        http(sprintf('<date>%s</date>',DB.DBA.date_iso8601 (rset[i][3])),resXml);
        http(sprintf('<date>%s</date>',date_str),resXml);
        http('</search_result>',resXml);

      }
    }
    set_qualifier ('ODS');
  }

_err:
  if(errCode<>0)
     httpErrXml(errCode,errMsg,'search');
  else
     httpResXml(resXml,'search');

  return '';
}
;
grant execute on search to GDATA_ODS;

create procedure searchContacts (
  in sid varchar := '',
                in realm varchar :='wa', 
                in searchParams varchar := '') __SOAP_HTTP 'text/xml'
{

  declare errCode integer;
  declare errMsg varchar;
  declare resXml any;

  resXml  := string_output ();
  errCode := 0;
  errMsg  := '';

  declare search_params_arr any;

  search_params_arr:=split_and_decode(searchParams);

  if(search_params_arr is null) search_params_arr:=vector();

  declare _uname varchar;
  declare _uid  integer;

  if (isSessionValid (sid, 'wa', _uname))
  {
      _uid:= username2id (_uname);
    }
  else
  {
      _uid := http_nobody_uid ();
    }

  declare instance_name,query varchar;
  declare keywords,tags,first_name,last_name nvarchar;

  declare max_rows,within_friends,dist_kind,order_by,for_result integer;
  declare dist_km,dist_pt_lat,dist_pt_lng real;
  declare tags_vector, rset, meta, sql_state, sql_msg any;


  keywords:=charset_recode (get_keyword('keywords',search_params_arr,''), 'UTF-8', '_WIDE_');
  tags:=charset_recode (get_keyword('tags',search_params_arr,''), 'UTF-8', '_WIDE_');

  first_name:=get_keyword('first_name',search_params_arr,'');
  last_name:=get_keyword('last_name',search_params_arr,'');
  instance_name:=get_keyword('instance_name',search_params_arr,'');

  max_rows:=get_keyword('max_rows',search_params_arr,100);
  within_friends:=get_keyword('within_friends',search_params_arr,0);   -- 0 - all; 1- friends; 2- friends of friends
  dist_kind:=get_keyword('dist_kind',search_params_arr,0); -- 0 - km; 1- miles
  order_by:=get_keyword('order_by',search_params_arr,2); -- 0: name, 1:relevance, 2:distance, 3:time
  for_result:=get_keyword('for_result',search_params_arr,0);

  dist_km:=get_keyword('dist_km',search_params_arr,null);
  dist_pt_lat:=get_keyword('dist_pt_lat',search_params_arr,0);
  dist_pt_lng:=get_keyword('dist_pt_lng',search_params_arr,0);


  tags_vector:=vector();
  query := null;

  --  'Map' us_for_result=0 else 1
  query := DB.DBA.WA_SEARCH_CONTACTS (
                                      max_rows,
                                      _uid,
                                      keywords,
                                      tags,
                                      first_name,
                                      last_name,
                                      within_friends,
                                      instance_name,
                                      dist_km,
                                      dist_kind,
                                      dist_pt_lat,
                                      dist_pt_lng,
                                      order_by,
                                      _uname,
                                      for_result,
                                      tags_vector
                                    );



  if (query is not null and length(query)>0)
  {
    sql_state := '00000';

    exec (query, sql_state, sql_msg, vector (), 0, meta, rset);

    if (sql_state = '00000' and length(rset)>0)
    {
      declare i integer;

      for(i:=0;i<length(rset);i:=i+1)
      {
        declare date_str varchar;
        if(rset[i][3] is not null )
           date_str:=sprintf('%02d %02d,%04d',month(rset[i][3]),dayofmonth(rset[i][3]),year(rset[i][3]));
        else
           date_str:='';

        http('<search_result>',resXml);
        http(sprintf('<html ><![CDATA[%s]]></html>',rset[i][0]),resXml);
        http(sprintf('<tag_table_fk>%s</tag_table_fk>',rset[i][1]),resXml);
        http(sprintf('<score>%d</score>',rset[i][2]),resXml);
        http(sprintf('<date>%s</date>',date_str),resXml);
        http(sprintf('<url><![CDATA[%s]]></url>',rset[i][4]),resXml);
        http(sprintf('<latitude>%.6f</latitude>',rset[i][5]),resXml);
        http(sprintf('<longitude>%.6f</longitude>',rset[i][6]),resXml);
        http(sprintf('<uid>%d</uid>',rset[i][7]),resXml);
        http('</search_result>',resXml);
      }
    }
  }

_err:

  if(errCode<>0)
     httpErrXml(errCode,errMsg,'searchContacts');
  else
     httpResXml(resXml,'searchContacts');

  return '';
}
;
grant execute on searchContacts to GDATA_ODS;


create procedure tagSearchResult (in sid varchar:='',in realm varchar :='wa', in tagParams varchar := '') __SOAP_HTTP 'text/xml'
{

  declare errCode integer;
  declare errMsg varchar;
  declare resXml any;

  resXml  := string_output ();
  errCode := 0;
  errMsg  := '';

  declare tag_params_arr any;
  tag_params_arr:=split_and_decode(tagParams);

  declare _uname varchar;
  declare logged_user_id  integer;
  if(isSessionValid(sid,'wa',_uname))
  {
    logged_user_id:=username2id(_uname);

--    declare tagsArr any;
--    tagsArr:=split_and_decode(get_keyword('tagStr',tag_params_arr,''),0,'\0\0,');
    declare tagsStr nvarchar;
    tagsStr:=charset_recode (get_keyword('tagStr',tag_params_arr,''), 'UTF-8', '_WIDE_');

    declare i integer;
    i:=0;
    for(i:=0;i<length(tag_params_arr);i:=i+2)
    {
      if(tag_params_arr[i] like 'obj%')
      {

          declare arr, upd_pk any;
          declare upd_type varchar;

          arr := deserialize (decode_base64 (tag_params_arr[i+1]));
          upd_type := arr[0];
          upd_pk := arr[1];

          DB.DBA.WA_SEARCH_ADD_TAG (logged_user_id, upd_type, upd_pk, tagsStr);

      }
    }

  }else
    return '';

_err:
  if(errCode<>0)
     httpErrXml(errCode,errMsg,'tagSearchResult');
  else
     httpResXml(resXml,'tagSearchResult');

  return '';
}
;
grant execute on tagSearchResult to GDATA_ODS;


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
--  sleep(1000);
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

create procedure isSessionValid (
  in sid varchar,
  in realm varchar :='wa',
  inout user_name varchar)
{
   set isolation = 'committed';

   declare _expiry datetime;

   whenever not found goto nf;

   select VS_EXPIRY,VS_UID into _expiry,user_name from DB.DBA.VSPX_SESSION where VS_SID = sid and VS_REALM=realm  and (datediff ('minute', VS_EXPIRY, now()) < 60) with (prefetch 1);

   if(datediff ('minute', _expiry, now()) > 1)
   {
     update DB.DBA.VSPX_SESSION set VS_EXPIRY=now() where VS_SID = sid;
   }

--   user_name:=(select VS_UID from DB.DBA.VSPX_SESSION where VS_SID = sid and VS_REALM=realm);
   set isolation = 'repeatable';
   return 1;

nf:
   declare errCode integer;
   declare errMsg  varchar;
   errCode := 1;
   errMsg  := 'Invalid or expired session.';

   httpErrXml(errCode,errMsg,'isSessionValid');

  return 0;

}
;

create procedure constructTypePackageArr(
  in firstcol_type varchar :='package')
{
    -- PACKAGE NAME / WA_TYPE
  if (firstcol_type='wa_types')
    return vector('AddressBook'      , 'AddressBook',
                         'Bookmarks'        , 'Bookmark'   ,
                         'Calendar'         , 'Calendar'   ,
                         'Community'        , 'Community'  ,
                         'Discussion'       , 'Discussion' ,
                         'Polls'            , 'Polls'      ,
                         'Weblog'           , 'WEBLOG2'    ,
                         'Feed Manager'     , 'eNews2'     ,
                         'Briefcase'        , 'oDrive'     ,
                         'Gallery'          , 'oGallery'   ,
                         'Mail'             , 'oMail'      ,
                         'Wiki'             , 'oWiki'      ,
                         'Instant Messenger', 'IM'         ,
                         'eCRM'             , 'eCRM'
                         );

  -- WA_TYPE / PACKAGE NAME
  return vector('AddressBook', 'AddressBook',
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
        if(subseq(users_name[i],0,1)='/' )
        {
         users_name[i]:=cast(coalesce(username2id(subseq(users_name[i],1)),'') as varchar);
        }

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



create procedure _hex_sha1_digest(
  in str varchar)
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

create procedure username2id(in user_name varchar)
{
 return (select U_ID from DB.DBA.SYS_USERS where U_NAME=user_name);
}
;

create procedure userid2name(in user_id integer)
{
 return (select U_NAME from DB.DBA.SYS_USERS where U_ID=user_id);
}
;

create procedure connections_get(in sneID integer)
{
  declare res any;
  res:=vector();

  for select top 100 sne_org_id from
  (
    select sne_org_id from DB.DBA.sn_related , DB.DBA.sn_person where snr_from = sneID and snr_to = sne_id
    union all
    select sne_org_id from DB.DBA.sn_related , DB.DBA.sn_person where snr_from = sne_id and snr_to = sneID
  ) sub
  do
  {
      res:=vector_concat(res,vector(sne_org_id));
   }
  return res;
}
;

create procedure invitations_get(in userName varchar)
{
  declare res any;
  res:=vector();

  declare sne_mail varchar;

  sne_mail:=(select U_E_MAIL from DB.DBA.SYS_USERS where U_NAME=userName);

  if(length(sne_mail))
  {
    for select top 20 sne_org_id 
          from DB.DBA.sn_invitation, DB.DBA.sn_person 
         where sni_from = sne_id
           and sni_to = sne_mail
           and sni_status = 0
    do
    {
       res:=vector_concat(res,vector(sne_org_id));
    }
  }
  return res;
}
;

create procedure invited_get(in user_identity any)
{
  declare res any;
  res:=vector();

  declare _sneid integer;

  if(isinteger(user_identity))
   _sneid := (select sne_id from DB.DBA.sn_person where sne_org_id=user_identity);
  else
   _sneid := (select sne_id from DB.DBA.sn_person where sne_org_id=username2id(user_identity));

  if(_sneid is not null)
  {
    for select top 20 U_ID from DB.DBA.sn_invitation,DB.DBA.SYS_USERS where sni_to=U_E_MAIL and sni_from=_sneid and sni_status=0
    do
    {
       res:=vector_concat(res,vector(U_ID));
    }
  }
  return res;
}
;

create procedure xml_nodename(in dbfield_name varchar)
{
 if(dbfield_name='U_NAME')         return 'userName';
 if(dbfield_name='U_FULL_NAME')    return 'fullName';
 if(dbfield_name='U_FIRST_NAME')   return 'firstName';
 if(dbfield_name='U_LAST_NAME')    return 'lastName';
 if(dbfield_name='U_PHOTO_URL')    return 'photo';
 if(dbfield_name='U_TITLE')        return 'title';
 if(dbfield_name='U_GENDER')       return 'gender';
 if(dbfield_name='U_MUSIC')        return 'music';
 if(dbfield_name='U_BOOKS')        return 'books';
 if(dbfield_name='U_MOVIES')       return 'movies';
 if(dbfield_name='U_INTEREST_TOPICS') return 'interestTopics';
 if(dbfield_name='U_INTERESTS')    return 'interests';
 if(dbfield_name='U_DATASPACE')    return 'dataspace';
 if(dbfield_name='H_COUNTRY')      return 'home_country';
 if(dbfield_name='H_STATE')        return 'home_state';
 if(dbfield_name='H_CITY')         return 'home_city';
 if(dbfield_name='H_ZIPCODE')      return 'home_zip';
 if(dbfield_name='H_PHONE')        return 'home_phone';
 if(dbfield_name='H_MOBILE')       return 'home_mobile';
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
 if(dbfield_name='O_PHONE')        return 'organization_phone';
 if(dbfield_name='O_MOBILE')       return 'organization_mobile';
 if(dbfield_name='O_LAT')          return 'organization_latitude';
 if(dbfield_name='O_LNG' )         return 'organization_longitude';
 if(dbfield_name='O_JOBPOSITION')  return 'organization_jobposition';
 if(dbfield_name='IM_ICQ')         return 'im_ICQ';
 if(dbfield_name='IM_SKYPE')       return 'im_Skype';
 if(dbfield_name='IM_AIM')         return 'im_AIM';
 if(dbfield_name='IM_YAHOO')       return 'im_Yahoo';
 if(dbfield_name='IM_MSN')         return 'im_MSN';
 if(dbfield_name='U_FOAF_DS')      return 'foaf_ds';
 if(dbfield_name='U_SIOC_DS')      return 'sioc_ds';

 return '';
}
;

create procedure visibility_posinarr(in dbfield_name varchar)
{
 if(dbfield_name='U_NAME')         return -1;
 if(dbfield_name='U_FULL_NAME')    return 3;
 if(dbfield_name='U_FIRST_NAME')   return 1;
 if(dbfield_name='U_LAST_NAME')    return 2;
 if(dbfield_name='U_PHOTO_URL')    return 37;
 if(dbfield_name='U_TITLE')        return 0;
 if(dbfield_name='U_GENDER')       return 5;
 if(dbfield_name='U_MUSIC')        return 24;
 if(dbfield_name='U_BOOKS')        return 44;
 if(dbfield_name='U_MOVIES')       return 46;
 if(dbfield_name='U_INTEREST_TOPICS') return 48;
 if(dbfield_name='U_INTERESTS')       return 49;
 if(dbfield_name='U_DATASPACE')    return -1;
 if(dbfield_name='H_COUNTRY')      return 16;
 if(dbfield_name='H_STATE')        return 16;
 if(dbfield_name='H_CITY')         return 16;
 if(dbfield_name='H_ZIPCODE')      return 15;
 if(dbfield_name='H_ADDRESS1')     return 15;
 if(dbfield_name='H_ADDRESS2')     return 15;
 if(dbfield_name='H_PHONE')        return 18;
 if(dbfield_name='H_MOBILE')       return 18;
 if(dbfield_name='H_LAT')          return 39;
 if(dbfield_name='H_LNG' )         return 39;
 if(dbfield_name='O_NAME')         return 20;
 if(dbfield_name='O_URL')          return 20;
 if(dbfield_name='O_COUNTRY')      return 23;
 if(dbfield_name='O_STATE')        return 23;
 if(dbfield_name='O_CITY')         return 23;
 if(dbfield_name='O_ZIPCODE')      return 22;
 if(dbfield_name='O_ADDRESS1')     return 22;
 if(dbfield_name='O_ADDRESS2')     return 22;
 if(dbfield_name='O_PHONE')        return 25;
 if(dbfield_name='O_MOBILE')       return 25;
 if(dbfield_name='O_LAT')          return 47;
 if(dbfield_name='O_LNG' )         return 47;
 if(dbfield_name='O_JOBPOSITION')  return 21;
 if(dbfield_name='IM_ICQ')         return 10;
 if(dbfield_name='IM_SKYPE')       return 11;
 if(dbfield_name='IM_AIM')         return 12;
 if(dbfield_name='IM_YAHOO')       return 13;
 if(dbfield_name='IM_MSN')         return 14;

 return -1;
}
;

create procedure constructFieldsNameStr (
  in fieldsname_str varchar)
{
  declare correctfields_name_str varchar;
  correctfields_name_str := 'userName,fullName,firstName,lastName,photo,title,gender,home,homeLocation,business,businessLocation,businessJobPosition,im,music,interestTopics,interests,dataspace,foaf_ds,sioc_ds';

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
                res_str:=res_str || '(case when length (trim (U.U_FULL_NAME)) > 0 ' ||
                                    '      then U_FULL_NAME '||
                                    '      when (length (trim (I.WAUI_FIRST_NAME)) > 0 or length (trim (I.WAUI_LAST_NAME))) '||
                                    '      then concat (I.WAUI_FIRST_NAME,\' \',I.WAUI_LAST_NAME) '||
                                    '      else U.U_NAME end) as U_FULL_NAME';

           if(fields_name[i]='firstName')
              res_str:=res_str||'I.WAUI_FIRST_NAME as U_FIRST_NAME';

           if(fields_name[i]='lastName')
              res_str:=res_str||'I.WAUI_LAST_NAME as U_LAST_NAME';

           if(fields_name[i]='photo')
              res_str:=res_str||'I.WAUI_PHOTO_URL as U_PHOTO_URL';

           if(fields_name[i]='title')
              res_str:=res_str||'I.WAUI_TITLE as U_TITLE';

           if(fields_name[i]='gender')
              res_str:=res_str||'I.WAUI_GENDER as U_GENDER';

           if(fields_name[i]='home')
              res_str:=res_str||'I.WAUI_HCOUNTRY as H_COUNTRY,'||
                                'I.WAUI_HSTATE as H_STATE,'||
                                'I.WAUI_HCITY as H_CITY,'||
                                'I.WAUI_HCODE as H_ZIPCODE,'||
                                'I.WAUI_HADDRESS1 as H_ADDRESS1,'||
                                'I.WAUI_HADDRESS2 as H_ADDRESS2,'||
                                'I.WAUI_HPHONE as H_PHONE,'||
                                'I.WAUI_HMOBILE as H_MOBILE';

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
                                'I.WAUI_BADDRESS2 as O_ADDRESS2,'||
                                'I.WAUI_BPHONE as O_PHONE,'||
                                'I.WAUI_BMOBILE as O_MOBILE';

           if(fields_name[i]='businessLocation')
              res_str:=res_str||'I.WAUI_BLAT as O_LAT,'||
                                'I.WAUI_BLNG as O_LNG';

           if(fields_name[i]='businessJobPosition')
              res_str:=res_str||'I.WAUI_BJOB as O_JOBPOSITION';

           if(fields_name[i]='im')
              res_str:=res_str||'I.WAUI_ICQ as IM_ICQ,'||
                                'I.WAUI_SKYPE as IM_SKYPE,'||
                                'I.WAUI_AIM as IM_AIM,'||
                                'I.WAUI_YAHOO as IM_YAHOO,'||
                                'I.WAUI_MSN as IM_MSN';

           if(fields_name[i]='music')
              res_str:=res_str||'I.WAUI_FAVORITE_MUSIC as U_MUSIC';

           if(fields_name[i]='books')
              res_str:=res_str||'I.WAUI_FAVORITE_BOOKS as U_BOOKS';

           if(fields_name[i]='movies')
              res_str:=res_str||'I.WAUI_FAVORITE_MOVIES as U_MOVIES';

           if(fields_name[i]='interests')
              res_str:=res_str||'I.WAUI_INTERESTS as U_INTERESTS';

              if (fields_name[i] = 'interestTopics')
                res_str := res_str || 'I.WAUI_INTEREST_TOPICS as U_INTEREST_TOPICS';

           if(fields_name[i]='dataspace')
              res_str:=res_str||'DB.DBA.WA_USER_DATASPACE(U.U_NAME) as U_DATASPACE';

	      if (fields_name[i] = 'sioc_ds')
	        res_str := res_str || 'ODS.DBA.USER_SIOC (U.U_NAME) as U_SIOC_DS';

	      if (fields_name[i] = 'foaf_ds')
	        res_str := res_str || 'ODS.DBA.USER_FOAF (U.U_NAME, I.WAUI_IS_ORG) as U_FOAF_DS';
        }
    }
  }

  return res_str;
}
;

create procedure USER_SIOC_DS (inout _u_name varchar)
{
    return '/dataspace/' || _u_name;
}
;

create procedure USER_FOAF_DS (inout _u_name varchar, in _is_org integer)
{
    if (_is_org)
      return '/dataspace/organization/' || _u_name;
    else
      return '/dataspace/person/' || _u_name;
}
;

create procedure constructSearchQuery (
  in searchType varchar,
                                       in loggedUserId integer)
{
  declare _max_rows integer;
  _max_rows:=100;

  declare qry varchar;
  qry:='';

  if(searchType='contacts')
  {
    ;
--      qry := WA_SEARCH_CONTACTS (
--      _max_rows,
--      self.u_id,
--      charset_recode (self.us_keywords.ufl_value, http_current_charset(), '_WIDE_'),
--      charset_recode (self.us_tags.ufl_value, http_current_charset (), '_WIDE_'),
--      charset_recode (self.us_first_name.ufl_value, http_current_charset(), '_WIDE_'),
--      charset_recode (self.us_last_name.ufl_value, http_current_charset(), '_WIDE_'),
--      cast (self.us_within_friends.ufl_value as integer),
--      _wai_name,
--      case when length (self.us_dist_km.ufl_value) > 0
--           then cast (self.us_dist_km.ufl_value as real)
--           else null end,
--      cast (self.us_dist_kind.ufl_value as integer),
--      case when length (self.us_dist_pt_lat.ufl_value) > 0
--           then cast (self.us_dist_pt_lat.ufl_value as real)
--           else null end,
--      case when length (self.us_dist_pt_lng.ufl_value) > 0
--           then cast (self.us_dist_pt_lng.ufl_value as real)
--           else null end,
--      case when self.us_out_as.ufl_value = 'Map'
--           then 2
--           else cast (self.us_oby.ufl_value as integer)end,
--      self.u_name,
--      case when self.us_out_as.ufl_value = 'Map'
--           then 0
--           else 1 end,
--      tags_vector
--      );
  }

  return qry;
}
;

create procedure usersinfo_sql(in usersStr varchar,in fieldsStr varchar)
{

  declare qry varchar;

  declare fields_name_str varchar;
  declare users_id_str varchar;

  fields_name_str := constructFieldsNameStr (fieldsStr);
  users_id_str := constructUsersIdStr (usersStr);
  qry := sprintf ('select U.U_ID,%s  from DB.DBA.SYS_USERS U left join DB.DBA.WA_USER_INFO I on (U.U_ID=I.WAUI_U_ID) where U.U_ID in (%s)',
               fields_name_str,users_id_str);

  return qry;
}
;
create procedure is_dba (in _identity any) returns int
{

  declare _u_group integer;

  if(isinteger(_identity))
    _u_group:=(select U_GROUP from DB.DBA.SYS_USERS where U_ID=_identity);
  else
    _u_group:=(select U_GROUP from DB.DBA.SYS_USERS where U_NAME=_identity);

  if (_u_group is null)
      _u_group := -1;

  if ( _u_group=0 or _u_group = 3)
    return 1;

  return 0;
}
;
create procedure sleep (in mseconds integer)
{

  declare _c_mseconds integer;
  _c_mseconds:=msec_time();

  while(msec_time()<(_c_mseconds+mseconds))
  {
    ;
  }
  return;
}
;


create procedure VSPX_EXPIRE_ANONYMOUS_SESSIONS ()
{
  delete from DB.DBA.VSPX_SESSION where VS_EXPIRY is null;
  delete from DB.DBA.VSPX_SESSION where VS_UID='nobody' and datediff ('minute', VS_EXPIRY, now()) > 3;
}
;


DB.DBA.wa_exec_no_error('update "DB"."DBA"."SYS_SCHEDULED_EVENT" set SE_SQL=''ODS.DBA.VSPX_EXPIRE_ANONYMOUS_SESSIONS ()'' '||
                 ' where  SE_NAME=''VSPX_SESSION_EXPIRE_ANONYMOUS'' AND  SE_SQL=''VSPX_EXPIRE_ANONYMOUS_SESSIONS ()'' ')
;

insert soft "DB"."DBA"."SYS_SCHEDULED_EVENT" (SE_INTERVAL, SE_LAST_COMPLETED, SE_NAME, SE_SQL, SE_START)
  values (1, NULL, 'VSPX_SESSION_EXPIRE_ANONYMOUS', 'ODS.DBA.VSPX_EXPIRE_ANONYMOUS_SESSIONS ()', now())
;

USE "DB"
;
