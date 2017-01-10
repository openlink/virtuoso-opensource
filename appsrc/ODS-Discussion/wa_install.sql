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
--  

-- This is not complete UDT definition.
-- It is an example for applications that are not fully function and integrated to ODS Framework.
-- It is an example for minimum definition that will give minimum integration to ODS Framework.
-- application of the type used in the example can not have instances.


USE "ODS"
;
-- this will define the type of the application so it's name will be possible to change, and it will be part of ODS Framework navigation
-- be careful with WAT_MAXINST it should be exactly 1. If 0 application will not be shown in ODS. If more then 1 you will have access to this application as it is defined to have multiple instances(types defined this way do not support that).

insert replacing DB.DBA.WA_TYPES(WAT_NAME, WAT_DESCRIPTION, WAT_TYPE, WAT_REALM,WAT_MAXINST) values ('Discussion', 'Discussion', 'ODS.DISCUSSION.discussion', 'wa',1)
;

--drop type ODS.DISCUSSION.discussion;

-- this is real definition of a type based on ODS Framework main type DB.DBA.web_app

DB.DBA.wa_exec_no_error('
  create type ODS.DISCUSSION.discussion under DB.DBA.web_app as (
    name   VARCHAR,
    owner  INT
  )
  constructor method discussion(stream any),
  overriding method wa_front_page (stream any) returns any,
  overriding method wa_home_url() returns varchar,
  method get_options () returns any
  '
)
;

-- this is definition of constructor for application type
-- name is a name that you will give to application. owner is an optio. Discussion is owned by admin and it's id is 0.

create constructor method discussion (inout stream any) for ODS.DISCUSSION.discussion
{
        self.name:='Discussion';
        self.ower:=0;
}
;

-- This method is essential. It return the path where user will be relocated when he has clicked on application tab in ODS navigation.
create method wa_home_url () for ODS.DISCUSSION.discussion {
  declare uri,ods_url, vspx_user varchar;
  ods_url:=coalesce(registry_get ('wa_home_link'),'/ods');
  vspx_user:=connection_get ('vspx_user');
  if (vspx_user is not null)
  {
    declare iUserID integer;
    iUserID := (select U_ID from DB.DBA.SYS_USERS where U_NAME = vspx_user);
    declare path, det_id varchar;
    path := sprintf ('/DAV/home/%s/Discussion/', vspx_user);
    DB.DBA.DAV_MAKE_DIR (path, iUserID, null, '110100000N');
    det_id := (select COL_DET from WS.WS.SYS_DAV_COL where COL_ID = DB.DBA.DAV_SEARCH_ID (path, 'C'));
    if (det_id is null)
    	update WS.WS.SYS_DAV_COL set COL_DET = 'nntp' where COL_ID = DB.DBA.DAV_SEARCH_ID (path, 'C');
  }
  uri := '/dataspace/all/discussion'; -- as Discussion has a special developed dashboard- url to dashboard is supplied, common use should be [uri := '/my_app_url/';]
  return uri;
}
;

-- This method essential for such custom application. It does not only give options to the navigation that determine when navigation tab will be shown, but also specifies application as custom.
-- Non of Openlink developed applications uses such a method.

create method get_options () for ODS.DISCUSSION.discussion
{
  return
      vector
       ('show_logged', 1,       -- describes if menu will be shown when user is logged
        'show_not_logged', 1    -- describes if menu will be shown when user is not logged
       );
};

-- This method is called in order to relocate browser to application home. It is not used in ODS navigation link generation.

create method wa_front_page (inout stream any) for ODS.DISCUSSION.discussion
{
  declare home, sid, vspx_user VARCHAR;
  declare vspx_uid int;
  
  home:='/nntpf/';
  
  vspx_user:=connection_get ('vspx_user');
  SELECT U_ID into vspx_uid FROM DB.DBA.SYS_USERS WHERE U_NAME=vspx_user;

  sid := md5 (concat (datestring (now ()), http_client_ip (), http_path ()));
  insert into DB.DBA.VSPX_SESSION (VS_REALM, VS_SID, VS_UID, VS_STATE, VS_EXPIRY)
  values ('wa', sid,
          connection_get ('vspx_user'),
          serialize (vector ('vspx_user', vspx_user, 'uid', vspx_uid)),
          now()
         );
   
  http_request_status ('HTTP/1.1 302 Found');
  http_header (sprintf('Location: %s?sid=%s&realm=wa\r\n', home, sid));
  return;
}
;

