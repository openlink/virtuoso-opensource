--
--  $Id$
--
--  OpenID protocol support.
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

use LDAP;

DB.DBA.wa_exec_no_error_log ('
  create table LDAP_SERVERS (
    LS_NAME varchar not null,
    LS_HOST varchar not null,
    LS_PORT varchar not null,
    LS_BASE_DN varchar not null,
    LS_BIND_DN varchar,
    LS_PASSWORD varchar,
    LS_SSL integer default 0,
    LS_VERSION integer default 2,
    LS_DEFAULT integer default 0,
    LS_MAPS varchar,

    primary key (LS_NAME)
  )
');

-------------------------------------------------------------------------------
--
create procedure LDAP..ldap_default ()
{
  return (select TOP 1 LS_NAME from LDAP..LDAP_SERVERS where LS_DEFAULT = 1);
}
;

-------------------------------------------------------------------------------
--
create procedure LDAP..ldap_maps (
  in ldapName varchar)
{
  return (select deserialize (LS_MAPS) from LDAP..LDAP_SERVERS where LS_NAME = ldapName);
}
;

-------------------------------------------------------------------------------
--
create procedure LDAP..ldap_search (
  in ldapName varchar,
  in ldapSearch varchar)
{
  declare ldapHost, retValue any;

  retValue := vector ();
  for (select LS_HOST, LS_PORT, LS_BASE_DN, LS_BIND_DN, LS_PASSWORD
         from LDAP..LDAP_SERVERS
        where LS_NAME = ldapName) do {
  	declare exit handler for sqlstate '*'
  	{
  	  goto _end;
  	};
    connection_set ('LDAP_VERSION', 2);
  	ldapHost := 'ldap://' || LS_HOST || ':' || LS_PORT;
    return ldap_search (ldapHost, 0, LS_BASE_DN, ldapSearch, LS_BIND_DN, LS_PASSWORD);
  }
_end:
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure LDAP..foaf_propName (
  in name varchar)
{
  -- name
  if (name = 'name')
    return name;
  -- nick
  if (name = 'nick')
    return name;
  -- first name
  if (name = 'firstName')
    return name;
  -- surname
  if (name = 'surname')
    return 'surname';
  -- famity
  if (name = 'familyName')
    return 'family_name';
  -- mbox
  if (name = 'mbox')
    return name;
  -- title
  if (name = 'title')
    return name;

  return null;
}
;

use DB;
