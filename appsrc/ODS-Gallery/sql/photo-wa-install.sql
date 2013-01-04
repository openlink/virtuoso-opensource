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

-------------------------------------------------------------------------------
PHOTO.WA._exec_no_error(
  'insert replacing WA_TYPES(WAT_NAME, WAT_TYPE, WAT_REALM, WAT_DESCRIPTION) values (\'oGallery\', \'db.dba.wa_photo\', \'wa\', \'Gallery\')'
)
;

-------------------------------------------------------------------------------
--PHOTO.WA._exec_no_error(
--  'update WA_TYPES set WAT_DESCRIPTION = \'Gallery\' where WAT_DESCRIPTION = \'oGallery\''
--)
--;

-------------------------------------------------------------------------------
PHOTO.WA._exec_no_error(
  'insert replacing WA_MEMBER_TYPE (WMT_APP, WMT_NAME, WMT_ID, WMT_IS_DEFAULT) values (\'oGallery\', \'owner\', 1, 0)'
)
;
-------------------------------------------------------------------------------
PHOTO.WA._exec_no_error(
  'insert replacing WA_MEMBER_TYPE (WMT_APP, WMT_NAME, WMT_ID, WMT_IS_DEFAULT) values (\'oGallery\', \'author\', 2, 0)'
)
;
-------------------------------------------------------------------------------
PHOTO.WA._exec_no_error(
  'insert replacing WA_MEMBER_TYPE (WMT_APP, WMT_NAME, WMT_ID, WMT_IS_DEFAULT) values (\'oGallery\', \'viewer\', 3, 0)'
)
;

-------------------------------------------------------------------------------
create procedure PHOTO.WA.photo_install()
{
  declare iIsDav integer;
  declare sHost varchar;

  sHost := registry_get('_oGallery_path_');
  if (cast(sHost as varchar) = '0')
    sHost := '/apps/oGallery/';

  iIsDav := 1;

  if (isnull(strstr(sHost, '/DAV')))
    iIsDav := 0;

  USER_CREATE('SOAPGallery',md5(cast(now() as varchar)), vector ('DISABLED', 1));
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

  -- comments.sql
  PHOTO.WA._exec_no_error('grant execute on photo_comment TO SOAPGallery');
  PHOTO.WA._exec_no_error('grant execute on PHOTO.WA.add_comment TO SOAPGallery');
  PHOTO.WA._exec_no_error('grant execute on PHOTO.WA.remove_comment TO SOAPGallery');
  PHOTO.WA._exec_no_error('grant execute on PHOTO.WA.update_comment TO SOAPGallery');
  PHOTO.WA._exec_no_error('grant execute on PHOTO.WA.get_comment TO SOAPGallery');
  PHOTO.WA._exec_no_error('grant execute on PHOTO.WA.get_comments TO SOAPGallery');

  -- dav_api.sql
  PHOTO.WA._exec_no_error('grant execute on PHOTO.WA.load_settings TO SOAPGallery');
  PHOTO.WA._exec_no_error('grant execute on PHOTO.WA.dav_browse TO SOAPGallery');
  PHOTO.WA._exec_no_error('grant execute on PHOTO.WA.create_new_album TO SOAPGallery');
  PHOTO.WA._exec_no_error('grant execute on PHOTO.WA.edit_album TO SOAPGallery');
  PHOTO.WA._exec_no_error('grant execute on PHOTO.WA.thumbnail_album TO SOAPGallery');
  PHOTO.WA._exec_no_error('grant execute on PHOTO.WA.edit_image TO SOAPGallery');
  PHOTO.WA._exec_no_error('grant execute on PHOTO.WA.dav_delete TO SOAPGallery');
  PHOTO.WA._exec_no_error('grant execute on PHOTO.WA.get_image TO SOAPGallery');
  PHOTO.WA._exec_no_error('grant execute on PHOTO.WA.tag_images TO SOAPGallery');
  PHOTO.WA._exec_no_error('grant execute on PHOTO.WA.tag_image TO SOAPGallery');
  PHOTO.WA._exec_no_error('grant execute on PHOTO.WA.remove_tag_image TO SOAPGallery');
  PHOTO.WA._exec_no_error('grant execute on PHOTO.WA.edit_album_settings TO SOAPGallery');

  -- flickr.sql
  PHOTO.WA._exec_no_error('grant execute on PHOTO.WA.flickr_login_link TO SOAPGallery');
  PHOTO.WA._exec_no_error('grant execute on PHOTO.WA.flickr_get_photos_list TO SOAPGallery');
  PHOTO.WA._exec_no_error('grant execute on PHOTO.WA.flickr_save_photos TO SOAPGallery');
  PHOTO.WA._exec_no_error('grant execute on PHOTO.WA.flickr_send_photos TO SOAPGallery');
  
  -- images.sql
  PHOTO.WA._exec_no_error('grant execute on PHOTO.WA.get_attributes TO SOAPGallery');

  -- types.sql
  PHOTO.WA._exec_no_error('grant execute on image_ids TO SOAPGallery');
  PHOTO.WA._exec_no_error('grant execute on photo_exif TO SOAPGallery');
  PHOTO.WA._exec_no_error('grant execute on photo_comment TO SOAPGallery');
  PHOTO.WA._exec_no_error('grant execute on SOAP_album TO SOAPGallery');
  PHOTO.WA._exec_no_error('grant execute on SOAP_external_album TO SOAPGallery');
  PHOTO.WA._exec_no_error('grant execute on SOAP_gallery TO SOAPGallery');

  if (registry_get ('gallery_services_update') = '1')
    return;

  SIOC..fill_ods_photos_services();
  registry_set ('gallery_services_update', '1');
}
;

-------------------------------------------------------------------------------
PHOTO.WA._exec_no_error(
'
  create type wa_photo under web_app as (
    gallery_id integer
	)
  constructor method wa_photo(stream any),
  overriding method wa_new_inst(login varchar) returns any,
  overriding method wa_front_page (stream any) returns any,
  overriding method wa_home_url() returns varchar,
  overriding method wa_drop_instance() returns any
'
)
;

PHOTO.WA._exec_no_error(
'
  alter type wa_photo add overriding method wa_update_instance (in oldValues any, in newValues any) returns any
'
)
;

-------------------------------------------------------------------------------
PHOTO.WA._exec_no_error('alter type wa_photo add overriding method wa_class_details () returns any');
PHOTO.WA._exec_no_error('alter type wa_photo add overriding method wa_vhost_options () returns any');
PHOTO.WA._exec_no_error('alter type wa_photo add overriding method wa_front_page_as_user(inout stream any, in user_name varchar) returns any');
PHOTO.WA._exec_no_error('alter type wa_photo add overriding method wa_dashboard() returns any');
PHOTO.WA._exec_no_error('alter type wa_photo add overriding method wa_dashboard_last_item() returns any');
PHOTO.WA._exec_no_error('alter type wa_photo add overriding method wa_addition_urls () returns any');

PHOTO.WA._exec_no_error('drop trigger DB.DBA.trigger_update_sys_info');
-------------------------------------------------------------------------------
create constructor method wa_photo (inout stream any) for wa_photo
{
  return;
};

-------------------------------------------------------------------------------
create method wa_new_inst (in login varchar) for wa_photo
{
  declare iUserID, iWaiID integer;
  declare retValue any;

  if (self.wa_member_model is null)
    self.wa_member_model := 0;

  insert into WA_INSTANCE (WAI_NAME, WAI_TYPE_NAME, WAI_INST, WAI_DESCRIPTION)
  	values (self.wa_name, 'oGallery', self, 'Description');

  select WAI_ID into iWaiID from WA_INSTANCE where WAI_NAME = self.wa_name;

  PHOTO.WA.photo_init_user_data(iWaiID,self.wa_name,login);
  retValue := (self as web_app).wa_new_inst(login);

  return retValue;
};

-------------------------------------------------------------------------------
create method wa_update_instance (in oldValues any, in newValues any) for wa_photo
{
  declare domainID, ownerID integer;
  
  domainID := (select WAI_ID from DB.DBA.WA_INSTANCE where WAI_NAME = newValues[0]);
  ownerID := (select WAM_USER from WA_MEMBER B where WAM_INST = oldValues[0] and WAM_MEMBER_TYPE = 1);

  PHOTO.WA.nntp_update (domainID, PHOTO.WA.domain_nntp_name2 (oldValues[0], PHOTO.WA.account_name (ownerID)), PHOTO.WA.domain_nntp_name2 (newValues[0], PHOTO.WA.account_name (ownerID)));

  --PHOTO.WA.COMMENTS

  update PHOTO.WA.SYS_INFO set WAI_NAME = newValues[0] where GALLERY_ID = domainID;

  return (self as web_app).wa_update_instance (oldValues, newValues);
};

-------------------------------------------------------------------------------
create method wa_drop_instance () for wa_photo
{
  PHOTO.WA.instance_delete ((select WAI_ID from WA_INSTANCE where WAI_NAME = self.wa_name));

  (self as web_app).wa_drop_instance();
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
  return coalesce((select CONCAT(HOME_URL,'/') from PHOTO.WA.SYS_INFO where WAI_NAME = self.wa_name),'/gallery');
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
create method wa_addition_urls () for wa_photo
{  
  declare
    iIsDav integer;
  declare
    sHost varchar;

  sHost := registry_get('_oGallery_path_');

  if (cast(sHost as varchar) = '0')
    sHost := '/apps/oGallery/';

  iIsDav := 1;
  return
    vector(
        vector(null, null, '/photos/res', sHost || 'www-root/', 1, 0, null, null, null, null, 'dba', null, null, 1, null, null, null, 0),
        vector(null, null, '/photos/SOAP', '/SOAP/', 0, 0, null, null, null, null, null, 'SOAPGallery', null, 1, vector('Use','literal','XML-RPC', 'yes'), null, null, 0)
    );
  
  return null;
};

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
--                                XMLATTRIBUTES(sprintf('<a href=\"%s%s/%s\">%s</a>',_home_path,C.COL_NAME,RES_NAME,RES_NAME) "content")
                                XMLATTRIBUTES(sprintf('<a href=\"/dataspace/%s/photos/%U#/%s/%s\">%s</a>',UserName,self.wa_name, C.COL_NAME, RES_NAME, RES_NAME) "content")
                     )
                )
          )
     from WS.WS.SYS_DAV_COL P,WS.WS.SYS_DAV_COL C, WS.WS.SYS_DAV_RES R
     WHERE RES_OWNER = iUser
     AND RES_COL = C.COL_ID
     AND P.COL_ID = C.COL_PARENT
     AND P.COL_ID = _col_id
     ORDER BY RES_MOD_TIME desc
  );
}
;

-------------------------------------------------------------------------------

create method wa_dashboard_last_item () for wa_photo 
{
  declare iUser integer;
  declare UserName,Names,_home_path,_home_url varchar;
  declare _xml,_xml_temp,ses any;
  declare _col_id integer;

  select WAM_USER 
    into iUser 
    from WA_MEMBER 
    where WAM_INST = self.wa_name;

  select U_NAME, IFNULL (U_FULL_NAME,U_NAME) 
    into UserName, Names 
    from WS.WS.SYS_DAV_USER 
    where U_ID = iUser;

  select HOME_PATH,HOME_URL 
    into _home_path,_home_url 
    from PHOTO.WA.SYS_INFO 
    where WAI_NAME = self.wa_name;

  _col_id := DAV_SEARCH_ID(_home_path,'C');

  ses := string_output ();

  http('<gallery>',ses);
  for (select RES_ID,RES_NAME,C.COL_NAME,RES_NAME,RES_NAME,RES_MOD_TIME
         from WS.WS.SYS_DAV_COL P,WS.WS.SYS_DAV_COL C, WS.WS.SYS_DAV_RES R
         where RES_OWNER = iUser
         and RES_COL = C.COL_ID
         and P.COL_ID = C.COL_PARENT
         and P.COL_ID = _col_id
         order by RES_MOD_TIME desc) do
    {
    http(sprintf('<image id="%d">',RES_ID),ses);
    http(sprintf('<title><![CDATA[%s]]></title>',RES_NAME),ses);
    http(sprintf('<dt>%s</dt>', date_iso8601(RES_MOD_TIME)),ses);
--      http (sprintf ('<link><![CDATA[%s/#/%s/%s]]></link>', _home_url, COL_NAME, RES_NAME, RES_NAME), ses);
      http (sprintf ('<link><![CDATA[/dataspace/%s/photos/%U#/%s/%s]]></link>',UserName,self.wa_name, COL_NAME, RES_NAME), ses);
    http(sprintf('<from><![CDATA[%s]]></from>',Names),ses);
    http(sprintf('<uid>%s</uid>',UserName),ses);
    http('</image>',ses);
  }
  http('</gallery>',ses);

  return string_output_string (ses);
};

PHOTO.WA._exec_no_error('PHOTO.WA.fill_exif_data()');

PHOTO.WA._exec_no_error('PHOTO.WA.update_gallery_foldername()');

-------------------------------------------------------------------------------
--
-- fix tables
--
-------------------------------------------------------------------------------

create procedure PHOTO.WA.fix_tables ()
{
  if (registry_get ('gallery_fix_comments') = '3')
    return;

  for (select WAI_INST from DB.DBA.WA_INSTANCE where WAI_TYPE_NAME = 'oGallery' and WAI_ID not in (select GALLERY_ID from PHOTO.WA.SYS_INFO)) do
  {
    declare exit handler for sqlstate '*' {  goto _next;};
    (WAI_INST as DB.DBA.wa_photo).wa_drop_instance();
    _next: ;
  }

  delete from PHOTO.WA.COMMENTS where GALLERY_ID not in (select s.GALLERY_ID from PHOTO.WA.SYS_INFO s);

  -- build nntp data for images
  for (select GALLERY_ID as _gallery_id, HOME_PATH from PHOTO.WA.SYS_INFO) do
  {
    for (select COL_ID from WS.WS.SYS_DAV_COL where COL_PARENT = (DAV_SEARCH_ID (HOME_PATH, 'C'))) do
    {
      for (select RES_ID as _res_id from WS.WS.SYS_DAV_RES where RES_COL = COL_ID) do
      {
        PHOTO.WA.root_comment (_gallery_id, _res_id);
      }
    }
  }
  delete from PHOTO.WA.EXIF_DATA where RES_ID not in (select c.RES_ID from PHOTO.WA.COMMENTS c);

  if (registry_get ('gallery_fix_comments') = '2')
    goto final;

  delete from PHOTO.WA.SYS_INFO where GALLERY_ID not in (select WAI_ID from DB.DBA.WA_INSTANCE where WAI_TYPE_NAME = 'oGallery');
  delete from PHOTO.WA.COMMENTS where GALLERY_ID not in (select WAI_ID from DB.DBA.WA_INSTANCE where WAI_TYPE_NAME = 'oGallery');
  for (select distinct RES_ID as _res_id from PHOTO.WA.COMMENTS) do
  {
    if (isnull (PHOTO.WA.resource_gallery_id (_res_id)))
    {
      delete from PHOTO.WA.COMMENTS where RES_ID = _res_id;
      delete from PHOTO.WA.EXIF_DATA where RES_ID = _res_id;
    }
  }

  for (select HP_LPATH as _lpath from DB.DBA.HTTP_PATH
        where HP_LPATH like '/photos/%'
          and HP_LPATH not in (select HOME_URL from PHOTO.WA.SYS_INFO)) do
  {
    if (_lpath not in ('/photos', '/photos/SOAP', '/photos/res'))
    {
      vhost_remove (lpath=> _lpath);
    }
  }

  for (select NG_GROUP as nntpGroup from DB.DBA.NEWS_GROUPS
        where NG_TYPE = 'GALLERY'
          and NG_NAME not in (select WAI_NAME from DB.DBA.WA_INSTANCE where WAI_TYPE_NAME = 'oGallery')) do
  {
    delete from DB.DBA.NEWS_MULTI_MSG where NM_GROUP = nntpGroup;
    delete from DB.DBA.NEWS_GROUPS where NG_GROUP = nntpGroup;
  }

  for (select GALLERY_ID, NNTP_INIT from PHOTO.WA.SYS_INFO where NNTP = 1) do
  {
    PHOTO.WA.nntp_update (GALLERY_ID, null, null, 1, 0);
  }
  update PHOTO.WA.SYS_INFO set NNTP = 0, NNTP_INIT = 0;

final: registry_set ('gallery_fix_comments', '3');
}
;
PHOTO.WA.fix_tables ();

-------------------------------------------------------------------------------
--
-- fix members
--
-------------------------------------------------------------------------------
create procedure PHOTO.WA.fix_members ()
{
  if (registry_get ('gallery_fix_members') = '1')
    return;

  set triggers off;
  update DB.DBA.WA_MEMBER set WAM_MEMBER_TYPE = 3 where WAM_APP_TYPE = 'oGallery' and WAM_MEMBER_TYPE = 2;
  set triggers on;
  registry_set ('gallery_fix_members', '1');
}
;
PHOTO.WA.fix_members ();

