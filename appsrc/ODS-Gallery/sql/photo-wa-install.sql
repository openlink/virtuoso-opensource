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

-------------------------------------------------------------------------------
PHOTO.WA._exec_no_error(
  'insert soft WA_TYPES(WAT_NAME, WAT_TYPE, WAT_REALM, WAT_DESCRIPTION) values (\'oGallery\', \'db.dba.wa_photo\', \'wa\', \'Gallery\')'
)
;

-------------------------------------------------------------------------------
--PHOTO.WA._exec_no_error(
--  'update WA_TYPES set WAT_DESCRIPTION = \'Gallery\' where WAT_DESCRIPTION = \'oGallery\''
--)
--;

-------------------------------------------------------------------------------
PHOTO.WA._exec_no_error(
  'insert soft WA_MEMBER_TYPE (WMT_APP, WMT_NAME, WMT_ID, WMT_IS_DEFAULT) values (\'oGallery\', \'owner\', 1, 0)'
)
;

-------------------------------------------------------------------------------
PHOTO.WA._exec_no_error(
  'insert soft WA_MEMBER_TYPE (WMT_APP, WMT_NAME, WMT_ID, WMT_IS_DEFAULT) values (\'oGallery\', \'viewer\', 2, 0)'
)
;



-------------------------------------------------------------------------------
create procedure PHOTO.WA.photo_install()
{
  declare
    iIsDav integer;
  declare
    sHost varchar;

  sHost := registry_get('_oGallery_path_');

  if (cast(sHost as varchar) = '0')
    sHost := '/apps/oGallery/';

  iIsDav := 1;

  if (isnull(strstr(sHost, '/DAV')))
    iIsDav := 0;

  USER_CREATE('SOAPGallery',md5(cast(now() as varchar)));
  USER_SET_QUALIFIER ('SOAPGallery', 'WS');


  -- Add a virtual directory for oGallery -----------------------
  VHOST_REMOVE(lpath      => '/photos');
  VHOST_DEFINE(lpath      => '/photos',
               ppath      => concat(sHost, 'www-root/portal/index.vsp'),
               opts       => vector('noinherit', 1),
               vsp_user   => 'dba',
               def_page   => 'index.vsp',
               is_dav     => iIsDav,
               ses_vars   => 1
              );

  VHOST_REMOVE(lpath      => '/photos/res');
  VHOST_DEFINE(lpath      => '/photos/res',
               ppath      => concat(sHost, 'www-root/'),
               vsp_user   => 'dba',
               def_page   => 'index.vsp',
               is_dav     => iIsDav,
               ses_vars   => 1
              );


  VHOST_REMOVE (lpath=>'/photos/SOAP');
  VHOST_DEFINE (lpath=>'/photos/SOAP',
                ppath=>'/SOAP/',
                soap_user=>'SOAPGallery',
                soap_opts => vector('Use','literal','XML-RPC','no' ));


  --INSERT REPLACING DB.DBA.WA_DOMAINS(WD_DOMAIN) values('domain.com');

  PHOTO.WA._exec_no_error('grant execute on PHOTO.WA.dav_browse TO SOAPGallery');
  PHOTO.WA._exec_no_error('grant execute on PHOTO.WA.create_new_album TO SOAPGallery');
  PHOTO.WA._exec_no_error('grant execute on PHOTO.WA.edit_album TO SOAPGallery');
  PHOTO.WA._exec_no_error('grant execute on SOAP_album TO SOAPGallery');
  PHOTO.WA._exec_no_error('grant execute on image_ids TO SOAPGallery');
  PHOTO.WA._exec_no_error('grant execute on photo_exif TO SOAPGallery');
  PHOTO.WA._exec_no_error('grant execute on photo_comment TO SOAPGallery');
  PHOTO.WA._exec_no_error('grant execute on PHOTO.WA.get_attributes TO SOAPGallery');
  PHOTO.WA._exec_no_error('grant execute on PHOTO.WA.add_comment TO SOAPGallery');
  PHOTO.WA._exec_no_error('grant execute on PHOTO.WA.get_comments TO SOAPGallery');
  PHOTO.WA._exec_no_error('grant execute on PHOTO.WA.dav_delete TO SOAPGallery');
  PHOTO.WA._exec_no_error('grant execute on PHOTO.WA.get_image TO SOAPGallery');
  PHOTO.WA._exec_no_error('grant execute on PHOTO.WA.edit_image TO SOAPGallery');
  PHOTO.WA._exec_no_error('grant execute on SOAP_gallery TO SOAPGallery');

}
;
-------------------------------------------------------------------------------
PHOTO.WA._exec_no_error(
'
  create type wa_photo under web_app as (
    wa_domain varchar
	)
  constructor method wa_photo(stream any),
  overriding method wa_new_inst(login varchar) returns any,
  overriding method wa_front_page (stream any) returns any,
  overriding method wa_home_url() returns varchar,
  overriding method wa_drop_instance() returns any,
  overriding method wa_domain_set (in domain varchar) returns any
'
)
;


-------------------------------------------------------------------------------
PHOTO.WA._exec_no_error('alter type wa_photo add overriding method wa_class_details () returns any');
PHOTO.WA._exec_no_error('alter type wa_photo add overriding method wa_vhost_options () returns any');
PHOTO.WA._exec_no_error('alter type wa_photo add overriding method wa_front_page_as_user(inout stream any, in user_name varchar) returns any');
PHOTO.WA._exec_no_error('alter type wa_photo add overriding method wa_dashboard() returns any');

-------------------------------------------------------------------------------
create constructor method wa_photo (inout stream any) for wa_photo
{
  --dbg_obj_print('wa_photo');
  return;
}
;

-------------------------------------------------------------------------------
create method wa_new_inst (in login varchar) for wa_photo
{
  declare
    iUserID,
    iWaiID int;

  --dbg_obj_print('wa_new_inst');

  if (self.wa_member_model is null)
    self.wa_member_model := 0;

  insert into WA_INSTANCE (WAI_NAME, WAI_TYPE_NAME, WAI_INST, WAI_DESCRIPTION)
  	values (self.wa_name, 'oGallery', self, 'Description');

  select WAI_ID into iWaiID from WA_INSTANCE where WAI_NAME = self.wa_name;

 -- iUserID := (select U_ID from SYS_USERS where U_NAME = login);

  PHOTO.WA.photo_init_user_data(self.wa_name,login);

  return (self as web_app).wa_new_inst(login);
}
;

-------------------------------------------------------------------------------
create method wa_drop_instance () for wa_photo
{
  --dbg_obj_print('wa_drop_instance');

  declare iUser, iCount any;

  select WAM_USER into iUser from WA_MEMBER where WAM_INST = self.wa_name;
  select count(WAM_USER) into iCount
    from WA_MEMBER,
         WA_INSTANCE
   where WAI_NAME = WAM_INST
     and WAI_TYPE_NAME = 'oGallery'
     and WAM_USER = iUser;

  if (iCount = 1){
    PHOTO.WA.photo_delete_user_data(iUser);
  }
  (self as web_app).wa_drop_instance();
  --delete from WA_MEMBER where WAM_INST = self.wa_name;
  --delete from WA_INSTANCE where WAI_NAME = self.wa_name;
}
;


-------------------------------------------------------------------------------
create method wa_front_page_as_user (inout stream any, in user_name varchar) for wa_photo
{
  declare iWaiID integer;
  declare sSid, sOwner varchar;

  iWaiID := (select WAI_ID from WA_INSTANCE where WAI_NAME = self.wa_name);
  sOwner := (select TOP 1 U_NAME from SYS_USERS A, WA_MEMBER B where B.WAM_USER = A.U_ID and B.WAM_INST= self.wa_name and B.WAM_MEMBER_TYPE = 1);
  sSid := md5 (concat (datestring (now ()), http_client_ip (), http_path ()));
  insert into DB.DBA.VSPX_SESSION (VS_REALM, VS_SID, VS_UID, VS_STATE, VS_EXPIRY)
    values ('wa', sSid, sOwner, serialize ( vector ('vspx_user', user_name, 'owner_user', sOwner)), now());
  http_request_status ('HTTP/1.1 302 Found');
  http_header(sprintf('Location: %s?sid=%s&realm=%s\r\n', self.wa_home_url(), sSid, 'wa'));
  return;
}
;


-------------------------------------------------------------------------------
create method wa_front_page (inout stream any) for wa_photo
{
  declare sid varchar;

  declare iWaiID integer;
  iWaiID := (select WAI_ID from WA_INSTANCE where WAI_NAME = self.wa_name);


  sid := (select VS_SID from VSPX_SESSION where VS_REALM = 'wa' and VS_UID = connection_get('vspx_user'));

  http_request_status ('HTTP/1.1 302 Found');
  http_header(sprintf('Location: %s?sid=%s&realm=%s\r\n', self.wa_home_url(), sid, 'wa'));
}
;

-------------------------------------------------------------------------------
create method wa_home_url () for wa_photo
{
  return (select CONCAT(HOME_URL,'/') from PHOTO.WA.SYS_INFO where WAI_NAME = self.wa_name);
}
;


-------------------------------------------------------------------------------
create method wa_class_details () for wa_photo
{
  declare info varchar;
  info := 'The Virtuoso Gallery Application allows you to run an online gallery system. It can be a private system, however in the spirit of web galleries these are often public for outsides to view image or pass comment.';
  return info;
}
;

-------------------------------------------------------------------------------
create method wa_vhost_options () for wa_photo
{
  declare
    iIsDav integer;
  declare
    sHost varchar;

  sHost := registry_get('_oGallery_path_');

  if (cast(sHost as varchar) = '0')
    sHost := '/apps/oGallery/';

  iIsDav := 1;

  if (isnull(strstr(sHost, '/DAV')))
    iIsDav := 0;

  return
    vector
     (
       concat(sHost, 'www-root/portal/index.vsp'),  -- physical home
       'index.vsp',                                 -- default page
       'dba',                                       -- user for execution
       0,                                           -- directory browsing enabled (flag 0/1)
       iIsDav,                                      -- WebDAV repository  (flag 0/1)
       vector ('noinherit', 1),                     -- virtual directory options , empty is not applicable
       null,                                        -- post-processing function (null is not applicable)
       null                                         -- pre-processing (authentication) function
     );

}
;

-------------------------------------------------------------------------------
create method wa_dashboard () for wa_photo {

  declare iUser integer;
  declare UserName,_home_path,_home_url varchar;
  declare _xml,_xml_temp any;
  declare _col_id integer;

  select WAM_USER into iUser from WA_MEMBER where WAM_INST = self.wa_name;
  select U_NAME into UserName from WS.WS.SYS_DAV_USER WHERE U_ID = iUser;
  select HOME_PATH,HOME_URL into _home_path,_home_url from PHOTO.WA.SYS_INFO WHERE WAI_NAME = self.wa_name;

     _col_id := DAV_SEARCH_ID(_home_path,'C');
  return (SELECT
          XMLAGG(XMLELEMENT('dash-row',
                     XMLATTRIBUTES('normal' as "class",  PHOTO.WA.date_2_humans(RES_MOD_TIME) as "time", self.wa_name as "application"),
                     XMLELEMENT('dash-data',
                                XMLATTRIBUTES(sprintf('<a href=\"%s%s/%s\">%s</a>',_home_path,C.COL_NAME,RES_NAME,RES_NAME) "content")
                     )
                )
          )
     from WS.WS.SYS_DAV_COL P,WS.WS.SYS_DAV_COL C, WS.WS.SYS_DAV_RES R
     WHERE RES_OWNER = iUser
     AND RES_COL = C.COL_ID
     AND P.COL_ID = C.COL_PARENT
     AND P.COL_ID = _col_id
     ORDER BY RES_MOD_TIME desc
  )
;
}
;
