--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2008 OpenLink Software
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
create procedure AB.WA.tmp_update ()
{
  if (registry_get ('ab_table_update') = '1')
    return;

  set triggers off;
  update AB.WA.PERSONS set P_IRI = P_FOAF;
  update AB.WA.PERSONS set P_FOAF = null;
  set triggers on;

  registry_set ('ab_table_update', '1');
}
;
AB.WA.tmp_update ();

-------------------------------------------------------------------------------
--
create procedure AB.WA.tmp_update ()
{
  if (registry_get ('ab_uid_update') = '1')
    return;

  set triggers off;
  update AB.WA.PERSONS set P_UID = AB.WA.uid () where P_UID is null;
  set triggers on;

  registry_set ('ab_uid_update', '1');
}
;
AB.WA.tmp_update ();

-------------------------------------------------------------------------------
--
create procedure AB.WA.tmp_update ()
{
  if (registry_get ('ab_grants_update') = '2')
    return;

  delete from AB.WA.GRANTS where not exists (select 1 from AB.WA.PERSONS where P_ID = G_PERSON_ID);

  registry_set ('ab_grants_update', '2');
}
;

AB.WA.tmp_update ();

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.tmp_update ()
{
  for (select WAI_ID, WAM_USER
         from DB.DBA.WA_MEMBER
                join DB.DBA.WA_INSTANCE on WAI_NAME = WAM_INST
        where WAI_TYPE_NAME = 'AddressBook'
          and WAM_MEMBER_TYPE = 1) do {
    AB.WA.domain_update (WAI_ID, WAM_USER);
  }
}
;

-----------------------------------------------------------------------------------------
--
AB.WA.tmp_update ()
;
