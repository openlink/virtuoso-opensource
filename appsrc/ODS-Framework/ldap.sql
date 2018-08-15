--
--  $Id$
--
--  OpenID protocol support.
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2018 OpenLink Software
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
    LS_USER_ID integer not null,
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

    constraint FK_LDAP_SERVERS FOREIGN KEY (LS_USER_ID) references DB.DBA.SYS_USERS (U_ID) ON DELETE CASCADE,

    primary key (LS_USER_ID, LS_NAME)
  )
');

DB.DBA.wa_add_col ('LDAP.DBA.LDAP_SERVERS', 'LS_USER_ID', 'integer');

DB.DBA.wa_exec_no_error_log ('alter table WV.WIKI.CLUSTERS add constraint "FK_LDAP_SERVERS" FOREIGN KEY (LS_USER_ID) references DB.DBA.SYS_USERS (U_ID) ON DELETE CASCADE');

DB.DBA.wa_exec_no_error_log ('
  create table LDAP_VALIDATION (
    LV_USER_ID integer not null,
    LV_FIELDS long varchar,

    constraint FK_LDAP_VALIDATION FOREIGN KEY (LV_USER_ID) references DB.DBA.SYS_USERS (U_ID) ON DELETE CASCADE,

    primary key (LV_USER_ID)
  )
');

create procedure migrate_ldap ()
{
  if (exists (select 1 from DB.DBA.SYS_COLS where upper("TABLE") = 'LDAP.DBA.LDAP_SERVERS' and upper("COLUMN") = 'LS_USER_ID' and COL_NULLABLE = 1))
    return;
  update LDAP.DBA.LDAP_SERVERS set LS_USER_ID = http_dav_uid () where LS_USER_ID is null;
  DB.DBA.wa_exec_no_error ('alter table LDAP.DBA.LDAP_SERVERS modify primary key (LS_USER_ID, LS_NAME)');
  update DB.DBA.SYS_COLS
     set COL_NULLABLE = 1
  where upper("TABLE") = 'LDAP.DBA.LDAP_SERVERS'
    and upper("COLUMN") = 'LS_USER_ID';
  __ddl_changed ('LDAP.DBA.LDAP_SERVERS');
}
;

migrate_ldap ();
drop procedure migrate_ldap;

-------------------------------------------------------------------------------
--
create procedure LDAP..ldap_default (
  in ldapUser integer)
{
  return (select TOP 1 LS_NAME from LDAP..LDAP_SERVERS where LS_USER_ID = ldapUser and LS_DEFAULT = 1);
}
;

-------------------------------------------------------------------------------
--
create procedure LDAP..ldap_maps (
  in ldapUser integer,
  in ldapName varchar)
{
  return (select deserialize (LS_MAPS) from LDAP..LDAP_SERVERS where LS_USER_ID = ldapUser and LS_NAME = ldapName);
}
;

-------------------------------------------------------------------------------
--
create procedure LDAP..ldap_search (
  in ldapUser integer,
  in ldapName varchar,
  in ldapSearch varchar)
{
  declare ldapHost, retValue any;

  retValue := vector ();
  for (select LS_HOST, LS_PORT, LS_BASE_DN, LS_BIND_DN, LS_PASSWORD
         from LDAP..LDAP_SERVERS
        where LS_USER_ID = ldapUser
          and LS_NAME = ldapName) do {
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
create procedure LDAP..contact_fields ()
{
  return vector (
        'P_NAME',           'Name',
        'P_TITLE',          'Title',
        'P_FIRST_NAME',     'First Name',
        'P_MIDDLE_NAME',    'Middle Name',
        'P_LAST_NAME',      'Last Name',
        'P_FULL_NAME',      'Full Name',
        'P_GENDER',         'Gender',
        'P_BIRTHDAY',       'Birthday',
        'P_IRI',            'WebID',
        'P_MAIL',           'Contact - Mail',
        'P_WEB',            'Contact - Web address',
        'P_ICQ',            'Contact - Icq',
        'P_SKYPE',          'Contact - Skype ID',
        'P_AIM',            'Contact - AIM Name',
        'P_YAHOO',          'Contact - Yahoo! ID',
        'P_MSN',            'Contact - MSN Messenger',
        'P_H_COUNTRY',      'Home - Country',
        'P_H_CITY',         'Home - City',
        'P_H_STATE',        'Home - State/Province',
        'P_H_CODE',         'Home - Zip/Postal Code',
        'P_H_ADDRESS1',     'Home - Address1',
        'P_H_ADDRESS2',     'Home - Address2',
        'P_H_TZONE',        'Home - Time Zone',
        'P_H_LAT',          'Home - Latitude',
        'P_H_LNG',          'Home - Longitude',
        'P_H_PHONE',        'Home - Phone',
        'P_H_MOBILE',       'Home - Mobile',
        'P_H_FAX',          'Home - Fax',
        'P_H_MAIL',         'Home - Mail',
        'P_H_WEB',          'Home - Web address',
        'P_B_COUNTRY',      'Business - Country',
        'P_B_CITY',         'Business - City',
        'P_B_STATE',        'Business - State/Province',
        'P_B_CODE',         'Business - Zip/Postal Code',
        'P_B_ADDRESS1',     'Business - Address1',
        'P_B_ADDRESS2',     'Business - Address2',
        'P_B_TZONE',        'Business - Time Zone',
        'P_B_LAT',          'Business - Latitude',
        'P_B_LNG',          'Business - Longitude',
        'P_B_PHONE',        'Business - Phone',
        'P_B_MOBILE',       'Business - Mobile',
        'P_B_FAX',          'Business - Fax',
        'P_B_INDUSTRY',     'Business - Industry',
        'P_B_ORGANIZATION', 'Business - Organization',
        'P_B_DEPARTMENT',   'Business - Department',
        'P_B_JOB',          'Business - Job Title',
        'P_B_MAIL',         'Business - Mail',
        'P_B_WEB',          'Business - Web address');
};

-------------------------------------------------------------------------------
--
create procedure LDAP..foaf_fields ()
{
  return vector (
        'P_NAME',           'nick',
        'P_TITLE',          'title',
        'P_FIRST_NAME',     'firstName',
        'P_LAST_NAME',      'family_name',
        'P_FULL_NAME',      'name',
        'P_GENDER',         'gender',
        'P_BIRTHDAY',       'birthday',
        'P_MAIL',           'mbox',
        'P_WEB',            'homepage',
        'P_ICQ',            'icqChatID',
        'P_AIM',            'aimChatID',
        'P_YAHOO',          'yahooChatID',
        'P_MSN',            'msnChatID',
        'P_H_PHONE',        'phone');
};

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
  -- family
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
