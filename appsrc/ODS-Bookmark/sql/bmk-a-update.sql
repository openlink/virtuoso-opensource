--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2012 OpenLink Software
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

-----------------------------------------------------------------------------------------
--
create procedure BMK.WA.tmp_update ()
{
  for (select WAI_ID, WAM_USER
         from DB.DBA.WA_MEMBER
                join DB.DBA.WA_INSTANCE on WAI_NAME = WAM_INST
        where WAI_TYPE_NAME = 'Bookmark'
          and WAM_MEMBER_TYPE = 1) do {
    BMK.WA.domain_update(WAI_ID, WAM_USER);
  }
}
;

-----------------------------------------------------------------------------------------
--
BMK.WA.tmp_update ()
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.tmp_update ()
{
  if (registry_get ('bmk_uid_update') = '1')
    return;

  set triggers off;
  update BMK.WA.BOOKMARK_DOMAIN set BD_UID = BMK.WA.uid () where BD_UID is null;
  set triggers on;

  registry_set ('bmk_uid_update', '1');
}
;
BMK.WA.tmp_update ();

-------------------------------------------------------------------------------
--
create procedure BMK.WA.tmp_update ()
{
  if (registry_get ('bmk_acl_update') = '1')
    return;
  registry_set ('bmk_acl_update', '1');

  set triggers off;
  update BMK.WA.BOOKMARK_DOMAIN set BD_ACL = null where BD_ACL is not null;
  set triggers on;
}
;

BMK.WA.tmp_update ();
