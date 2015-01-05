--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2015 OpenLink Software
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
--
create procedure ODRIVE.WA.tmp_upgrade ()
{
  declare inst any;

  if (registry_get ('odrive_path_upgrade') = '1')
    return;
  registry_set ('odrive_path_upgrade', '1');

  for (select WAI_ID, WAI_NAME, WAI_INST from DB.DBA.WA_INSTANCE where WAI_TYPE_NAME = 'oDrive') do
  {
    VHOST_REMOVE(lpath    => '/odrive/' || cast (WAI_ID as varchar));
    VHOST_DEFINE(lpath    => '/odrive/' || cast (WAI_ID as varchar),
                 ppath    => (WAI_INST as wa_oDrive).get_param ('host') || 'www/',
                 ses_vars => 1,
                 is_dav   => (WAI_INST as wa_oDrive).get_param ('isDAV'),
                 is_brws  => 0,
                 vsp_user => 'dba',
                 realm    => 'wa',
                 def_page => 'home.vspx',
                 opts     => vector ('domain', WAI_ID)
               );
    update DB.DBA.WA_MEMBER
       set WAM_HOME_PAGE = '/odrive/' || cast (WAI_ID as varchar) || '/home.vspx'
     where WAM_INST = WAI_NAME;
  }
  VHOST_REMOVE (lpath    => '/odrive/');
}
;

ODRIVE.WA.tmp_upgrade ();

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.tmp_set_criteria (
  inout search varchar,
  inout id integer,
  in fType any,
  in fCriteria any,
  in fValue any,
  in fSchema any := null,
  in fProperty any := null)

{
	if (is_empty_or_null (fCriteria))
	  return;
	if (is_empty_or_null (fValue))
	  return;
	ODRIVE.WA.dc_set_criteria (search, cast (id as varchar), fType, fCriteria, fValue, fSchema, fProperty);
	id := id + 1;
}
;
-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.tmp_upgrade ()
{
  if (registry_get ('odrive_items_upgrade') = '1')
    return;

	declare I, N, M integer;
  declare tmp, oldSearch, newSearch, aXml, aEntity any;

  for (select COL_ID, WS.WS.COL_PATH (COL_ID) as COL_FULL_PATH from WS.WS.SYS_DAV_COL where COL_DET = 'ResFilter' or COL_DET = 'CatFilter') do
  {
  	M := 0;
    oldSearch := ODRIVE.WA.DAV_PROP_GET (COL_FULL_PATH, 'virt:Filter-Params', null, 'dav');
    newSearch := null;

	  aXml := ODRIVE.WA.dc_xml_doc (oldSearch);

	  -- base
	  --
    ODRIVE.WA.dc_set_base (newSearch, 'path', ODRIVE.WA.dc_get (oldSearch, 'base', 'path'));

	  ODRIVE.WA.tmp_set_criteria (newSearch, M, 'RES_NAME',         'like',                                                   ODRIVE.WA.dc_get(oldSearch, 'base', 'name'));
	  ODRIVE.WA.tmp_set_criteria (newSearch, M, 'RES_CONTENT',      'contains_text',                                          ODRIVE.WA.dc_get(oldSearch, 'base', 'content'));

	  -- advanced
	  --
	  ODRIVE.WA.tmp_set_criteria (newSearch, M, 'RES_TYPE',         'like',                                                   ODRIVE.WA.dc_get(oldSearch, 'advanced', 'mime'));
    ODRIVE.WA.tmp_set_criteria (newSearch, M, 'RES_OWNER_NAME',   '=',                                                      ODRIVE.WA.account_name (ODRIVE.WA.dc_get(oldSearch, 'advanced', 'owner')));
	  ODRIVE.WA.tmp_set_criteria (newSearch, M, 'RES_GROUP_NAME',   '=',                                                      ODRIVE.WA.account_name (ODRIVE.WA.dc_get(oldSearch, 'advanced', 'group')));
	  ODRIVE.WA.tmp_set_criteria (newSearch, M, 'RES_CR_TIME',      ODRIVE.WA.dc_get(oldSearch, 'advanced', 'createDate11'),  ODRIVE.WA.dc_get(oldSearch, 'advanced', 'createDate12'));
	  ODRIVE.WA.tmp_set_criteria (newSearch, M, 'RES_CR_TIME',      ODRIVE.WA.dc_get(oldSearch, 'advanced', 'createDate21'),  ODRIVE.WA.dc_get(oldSearch, 'advanced', 'createDate22'));
	  ODRIVE.WA.tmp_set_criteria (newSearch, M, 'RES_MOD_TIME',     ODRIVE.WA.dc_get(oldSearch, 'advanced', 'modifyDate11'),  ODRIVE.WA.dc_get(oldSearch, 'advanced', 'modifyDate12'));
	  ODRIVE.WA.tmp_set_criteria (newSearch, M, 'RES_MOD_TIME',     ODRIVE.WA.dc_get(oldSearch, 'advanced', 'modifyDate21'),  ODRIVE.WA.dc_get(oldSearch, 'advanced', 'modifyDate22'));
	  ODRIVE.WA.tmp_set_criteria (newSearch, M, 'RES_PUBLIC_TAGS',  ODRIVE.WA.dc_get(oldSearch, 'advanced', 'publicTags11'),  ODRIVE.WA.dc_get(oldSearch, 'advanced', 'publicTags12'));
	  ODRIVE.WA.tmp_set_criteria (newSearch, M, 'RES_PRIVATE_TAGS', ODRIVE.WA.dc_get(oldSearch, 'advanced', 'privateTags11'), ODRIVE.WA.dc_get(oldSearch, 'advanced', 'privateTags12'));

	  -- properties
	  --
	  I := xpath_eval('count(/dc/property/entry)', aXml);
	  for (N := 1; N <= I; N := N + 1)
	  {
	    aEntity := xpath_eval('/dc/property/entry', aXml, N);
	    ODRIVE.WA.tmp_set_criteria (newSearch, M, 'PROP_VALUE', cast (xpath_eval ('@condition', aEntity) as varchar), cast (xpath_eval ('.', aEntity) as varchar), null, cast (xpath_eval ('@property', aEntity) as varchar));
	  }

	  -- metadata
	  --
	  I := xpath_eval('count(/dc/metadata/entry)', aXml);
	  for (N := 1; N <= I; N := N + 1)
	  {
	    aEntity := xpath_eval('/dc/metadata/entry', aXml, N);
	    if (cast (xpath_eval ('@type', aEntity) as varchar) = 'RDF')
	    {
  	    ODRIVE.WA.tmp_set_criteria (newSearch, M, 'RDF_VALUE', cast (xpath_eval ('@condition', aEntity) as varchar), cast (xpath_eval ('.', aEntity) as varchar), cast (xpath_eval ('@schema', aEntity) as varchar), cast (xpath_eval ('@property', aEntity) as varchar));
	    } else {
  	    ODRIVE.WA.tmp_set_criteria (newSearch, M, 'PROP_VALUE', cast (xpath_eval ('@condition', aEntity) as varchar), cast (xpath_eval ('.', aEntity) as varchar), null, cast (xpath_eval ('@property', aEntity) as varchar));
	    }
	  }

    ODRIVE.WA.DAV_PROP_SET (COL_FULL_PATH, 'virt:Filter-Params', newSearch, 'dav');
  }
  registry_set ('odrive_items_upgrade', '1');
}
;

ODRIVE.WA.tmp_upgrade ();

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.tmp_upgrade ()
{
  declare path, graph any;

  if (registry_get ('odrive_acl_update') = '1')
    return;

  for (select * from WS.WS.SYS_DAV_PROP where PROP_TYPE = 'R' and PROP_NAME = 'virt:aci_meta_n3') do
  {
    path := DB.DBA.DAV_SEARCH_PATH (PROP_PARENT_ID, PROP_TYPE);
    graph := WS.WS.DAV_IRI (path);
    delete from DB.DBA.RDF_QUAD where G = iri_to_id (graph);
    graph := rtrim (WS.WS.DAV_IRI (path), '/') || '/';
    delete from DB.DBA.RDF_QUAD where G = iri_to_id (graph);

    WS.WS.WAC_INSERT (path, PROP_VALUE, null, null, 0);
  }

  registry_set ('odrive_acl_upgrade', '1');
}
;

ODRIVE.WA.tmp_upgrade ();

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.tmp_upgrade_internal (
  in det varchar)
{
  declare path, graph, propName, permissions any;

  propName := 'virt:' || det || '-graph';
  for (select * from WS.WS.SYS_DAV_PROP where PROP_TYPE = 'C' and PROP_NAME = propName) do
  {
    path := DB.DBA.DAV_SEARCH_PATH (PROP_PARENT_ID, PROP_TYPE);
    permissions := DB.DBA.DAV_PROP_GET_INT (PROP_PARENT_ID, PROP_TYPE, ':virtpermissions', 0, ODRIVE.WA.account_name (http_dav_uid ()), ODRIVE.WA.account_password (http_dav_uid ()), http_dav_uid ());
    ODRIVE.WA.graph_private_add (path, 'C', permissions, PROP_VALUE);
  }
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.tmp_upgrade ()
{
  if (registry_get ('odrive_graph_update') = '2')
    return;

  ODRIVE.WA.tmp_upgrade_internal ('S3');
  ODRIVE.WA.tmp_upgrade_internal ('IMAP');
  ODRIVE.WA.tmp_upgrade_internal ('GDrive');
  ODRIVE.WA.tmp_upgrade_internal ('Dropbox');
  ODRIVE.WA.tmp_upgrade_internal ('SkyDrive');
  ODRIVE.WA.tmp_upgrade_internal ('Box');
  ODRIVE.WA.tmp_upgrade_internal ('WebDAV');
  ODRIVE.WA.tmp_upgrade_internal ('Rackspace');

  registry_set ('odrive_graph_update', '2');
}
;

ODRIVE.WA.tmp_upgrade ()
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.tmp_upgrade ()
{
  declare rid, ouid, ogid any;

  if (registry_get ('odrive_nobody_update') = '1')
    return;

  for (select RES_ID, RES_COL from WS.WS.SYS_DAV_RES where RES_OWNER = -12) do
  {
    rid := RES_ID;

    select COL_OWNER, COL_GROUP
      into ouid, ogid
      from WS.WS.SYS_DAV_COL
     where COL_ID = RES_COL;

    update WS.WS.SYS_DAV_RES
       set RES_OWNER = ouid,
           RES_GROUP = ogid
     where RES_ID = rid;
  }
  registry_set ('odrive_nobody_update', '1');
}
;

ODRIVE.WA.tmp_upgrade ()
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.tmp_upgrade ()
{
  declare server, property, propertyValue varchar;
  declare V any;

  if (registry_get ('odrive_imap_update') = '1')
    return;

  for (select COL_ID from WS.WS.SYS_DAV_COL where COL_DET = 'IMAP') do
  {
    server := DB.DBA.DAV_PROP_GET_INT (COL_ID, 'C', 'virt:IMAP-server', 0);
    V := sprintf_inverse (server, '%s:%s', 2);
    property := 'virt:IMAP-server';
    propertyValue := V[0];
    if (not isnull (propertyValue))
      DB.DBA.DAV_PROP_SET_RAW (COL_ID, 'C', property, propertyValue, 1, http_dav_uid ());

    property := 'virt:IMAP-port';
    propertyValue := V[1];
    if (not isnull (propertyValue))
      DB.DBA.DAV_PROP_SET_RAW (COL_ID, 'C', property, propertyValue, 1, http_dav_uid ());
  }
  registry_set ('odrive_imap_update', '1');
}
;

ODRIVE.WA.tmp_upgrade ();

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.tmp_upgrade ()
{
  if (registry_get ('odrive_acl_update') = '1')
    return;

  set triggers off;
  delete from WS.WS.SYS_DAV_RES where RES_FULL_PATH is null;
  set triggers on;

  registry_set ('odrive_acl_update', '1');
}
;

ODRIVE.WA.tmp_upgrade ();
