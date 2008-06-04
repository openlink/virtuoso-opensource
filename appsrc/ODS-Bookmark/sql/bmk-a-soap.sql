--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2007 OpenLink Software
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

-----------------------------------------------------------------------------
--
create procedure DBA.DB.bookmark_import (
  in pUser varchar,
  in pPassword varchar,
  in pInstance varchar,
  in pSource varchar,
  in pSourceType varchar,
  in pTags varchar := '') returns varchar
{
  declare user_id, domain_id integer;
  declare content varchar;
  declare tmp any;

  user_id := (select U_ID from DB.DBA.SYS_USERS where U_NAME = pUser and pwd_magic_calc (U_NAME, U_PASSWORD, 1) = pPassword);
  if (isnull (user_id))
  	signal ('BMK01', 'Bad user name or password');
  domain_id := BMK.WA.domain_id (pInstance);
  if (isnull (domain_id))
  	signal ('BMK02', 'Bad instance name');
  if (not exists (select 1
                   from WA_MEMBER,
                        WA_INSTANCE
                  where WAM_USER = user_id
                    and WAM_INST = WAI_NAME
                    and WAI_ID   = domain_id))
  	signal ('BMK03', 'User not a member of the instance');


  -- get content
  if (lcase(pSourceType) = 'string') 
  {
    content := pSource;
  } 
  else if (lcase(pSourceType) = 'webdav') 
  {
    content := BMK.WA.dav_content (BMK.WA.host_url () || pSource, pUser, pPassword);
  } 
  else if (lcase(pSourceType) = 'url') 
  {
    content := BMK.WA.dav_content (pSource);
  } 
  else 
  {
	  signal ('BMK04', 'The source type must be string, WebDAV or URL.');
  }

  pTags := trim (pTags);
  BMK.WA.test (pTags, vector ('name', 'Tags', 'class', 'tags'));
  tmp := BMK.WA.tags2vector (pTags);
  tmp := BMK.WA.vector_unique (tmp);
  pTags := BMK.WA.vector2tags (tmp);

  -- import content
  set_user_id ('dba');
  if (is_empty_or_null (content))
    signal ('BMK04', 'Bad import source!');

  BMK.WA.bookmark_import (content, domain_id, user_id, null, pTags, null);
  
  return 1;
}
;

-----------------------------------------------------------------------------
--
create procedure DBA.DB.bookmark_export (
  in pUser varchar,
  in pPassword varchar,
  in pInstance varchar,
  in pContentType varchar := 'Netscape') returns varchar
{
  declare user_id, domain_id integer;

  user_id := (select U_ID from DB.DBA.SYS_USERS where U_NAME = pUser and pwd_magic_calc (U_NAME, U_PASSWORD, 1) = pPassword);
  if (isnull (user_id))
  	signal ('BMK01', 'Bad user name or password');
  domain_id := BMK.WA.domain_id (pInstance);
  if (isnull (domain_id))
  	signal ('BMK02', 'Bad instance name');
  if (not exists (select 1
                   from WA_MEMBER,
                        WA_INSTANCE
                  where WAM_USER = user_id
                    and WAM_INST = WAI_NAME
                    and WAI_ID   = domain_id))
  	signal ('BMK03', 'User not a member of the instance');

  if (not ((lcase (pContentType) = 'netscape') or (lcase (pContentType) = 'xbel')))
  	signal ('BMK05', 'The content type must be Netscape or XBEL.');

  set_user_id ('dba');
  return BMK.WA.dav_content (sprintf('%s/bookmark/%d/export.vspx?did=%d&output=BMK&file=export&format=%s', BMK.WA.host_url (), domain_id, domain_id, pContentType));
}
;

-----------------------------------------------------------------------------
--
create procedure DBA.DB.bookmark_update (
  in pUser varchar,
  in pPassword varchar,
  in pInstance varchar,
  in pBookmarkUri varchar,
  in pBookmarkName varchar,
  in pBookmarkDescription varchar := '',
  in pBookmarkFolderPath varchar := '') returns varchar
{
  declare user_id, domain_id, folder_id integer;

  user_id := (select U_ID from DB.DBA.SYS_USERS where U_NAME = pUser and pwd_magic_calc (U_NAME, U_PASSWORD, 1) = pPassword);
  if (isnull (user_id))
  	signal ('BMK01', 'Bad user name or password');
  domain_id := BMK.WA.domain_id (pInstance);
  if (isnull (domain_id))
  	signal ('BMK02', 'Bad instance name');
  if (not exists (select 1
                   from WA_MEMBER,
                        WA_INSTANCE
                  where WAM_USER = user_id
                    and WAM_INST = WAI_NAME
                    and WAI_ID   = domain_id))
  	signal ('BMK03', 'User not a member of the instance');

  set_user_id ('dba');
  folder_id := BMK.WA.folder_id(domain_id, pBookmarkFolderPath);
  return BMK.WA.bookmark_update (-1, domain_id, pBookmarkUri, pBookmarkName, pBookmarkDescription, folder_id);
}
;

grant execute on DBA.DB.bookmark_import to SOAP_BOOKMARK
;

grant execute on DBA.DB.bookmark_export to SOAP_BOOKMARK
;

grant execute on DBA.DB.bookmark_update to SOAP_BOOKMARK
;
