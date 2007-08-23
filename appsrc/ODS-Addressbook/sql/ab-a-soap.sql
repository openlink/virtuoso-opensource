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
create procedure DBA.DB.addressbook_import (
  in pUser varchar,
  in pPassword varchar,
  in pInstance varchar,
  in pSource varchar,
  in pSourceType varchar,
  in pContentType varchar,
  in pTags varchar := '') returns varchar
{
  declare user_id, domain_id integer;
  declare content varchar;
  declare tmp any;

  user_id := (select U_ID from DB.DBA.SYS_USERS where U_NAME = pUser and pwd_magic_calc (U_NAME, U_PASSWORD, 1) = pPassword);
  if (isnull (user_id))
  	signal ('AB101', 'Bad user name or password');
  domain_id := AB.WA.domain_id (pInstance);
  if (isnull (domain_id))
  	signal ('AB102', 'Bad instance name');
  if (not exists (select 1
                   from WA_MEMBER,
                        WA_INSTANCE
                  where WAM_USER = user_id
                    and WAM_INST = WAI_NAME
                    and WAI_ID   = domain_id))
  	signal ('AB103', 'User not a member of the instance');


  -- get content
  if (lcase(pSourceType) = 'string') {
    content := pSource;

  } else if (lcase(pSourceType) = 'webdav') {
    if (pSource not like (AB.WA.dav_home (user_id) || '%'))
      signal ('AB108', sprintf('Please select file from your WebDAV home directory ''%s''!', AB.WA.dav_home (user_id)));
    content := AB.WA.dav_content (AB.WA.host_url () || pSource, pUser, pPassword);

  } else if (lcase(pSourceType) = 'url') {
    content := pSource;

  } else {
	  signal ('AB106', 'The source type must be string, WebDAV or URL.');

  }

  pTags := trim (pTags);
  AB.WA.test (pTags, vector ('name', 'Tags', 'class', 'tags'));
  tmp := AB.WA.tags2vector (pTags);
  tmp := AB.WA.vector_unique (tmp);
  pTags := AB.WA.vector2tags (tmp);

  -- import content
  set_user_id ('dba');
  if (is_empty_or_null (content))
    signal ('AB107', 'Bad import source!');

  if (lcase(pContentType) = 'vcard') {
    -- vCard
    AB.WA.import_vcard (domain_id, content, pTags);

  } else if (lcase(pContentType) = 'foaf') {
    -- foaf
    AB.WA.import_foaf (domain_id, content, pTags, case when (lcase (pSourceType) = 'url') then 1 else 0 end);

  } else {
  	signal ('AB105', 'The content type must be vCard or FOAF.');

  }
  return 1;
}
;

-----------------------------------------------------------------------------
--
create procedure DBA.DB.addressbook_export (
  in pUser varchar,
  in pPassword varchar,
  in pInstance varchar,
  in pContentType varchar) returns varchar
{
  declare user_id, domain_id integer;

  user_id := (select U_ID from DB.DBA.SYS_USERS where U_NAME = pUser and pwd_magic_calc (U_NAME, U_PASSWORD, 1) = pPassword);
  if (isnull (user_id))
  	signal ('AB101', 'Bad user name or password');
  domain_id := AB.WA.domain_id (pInstance);
  if (isnull (domain_id))
  	signal ('AB102', 'Bad instance name');
  if (not exists (select 1
                   from WA_MEMBER,
                        WA_INSTANCE
                  where WAM_USER = user_id
                    and WAM_INST = WAI_NAME
                    and WAI_ID   = domain_id))
  	signal ('AB103', 'User not a member of the instance');

  declare sStream any;

  sStream := string_output ();
  set_user_id ('dba');
  if (lcase(pContentType) = 'vcard') {
    -- vCard
    for (select P_ID from AB.WA.PERSONS where P_DOMAIN_ID = domain_id) do
      http (AB.WA.export_vcard (P_ID, domain_id), sStream);

  } else if (lcase(pContentType) = 'foaf') {
    -- foaf
    http (AB.WA.export_foaf (null, domain_id), sStream);

  } else if (lcase(pContentType) = 'csv') {
    -- CSV
    http (AB.WA.export_csv_head (), sStream);
    for (select P_ID from AB.WA.PERSONS where P_DOMAIN_ID = domain_id) do
      http (AB.WA.export_csv (P_ID, domain_id), sStream);

  } else {
  	signal ('AB104', 'The content type must be vCard, FOAF or CSV.');

  }
  return string_output_string (sStream);
}
;

grant execute on DBA.DB.addressbook_import to SOAP_ADDRESSBOOK
;

grant execute on DBA.DB.addressbook_export to SOAP_ADDRESSBOOK
;
