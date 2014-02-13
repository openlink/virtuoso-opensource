--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2014 OpenLink Software
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
--------------------------------------------------------------------------------
--
create procedure PHOTO.WA.trigger_thumbnail (
  inout _res_id integer,
  inout _res_col integer,
  inout _res_owner integer,
  inout _res_content any)
{
  declare parent_id,parent_name integer;
  declare current_user photo_user;

  parent_id := (select COL_PARENT from WS.WS.SYS_DAV_COL WHERE COL_ID = _res_col);
  parent_name := DB.DBA.DAV_SEARCH_PATH (parent_id, 'C');
  current_user := new photo_user (cast (_res_owner as integer));

  if (parent_name = current_user.gallery_dir)
  {
    declare photo_id integer;

    photo_id := (select GALLERY_ID from PHOTO.WA.SYS_INFO where HOME_PATH = parent_name);
    for (select WAI_NAME, WAI_DESCRIPTION from DB.DBA.WA_INSTANCE where WAI_ID = photo_id and WAI_IS_PUBLIC = 1) do
      ODS..APP_PING (WAI_NAME, coalesce (WAI_DESCRIPTION, WAI_NAME), SIOC..photo_iri (WAI_NAME));

    PHOTO.WA.root_comment (parent_id, _res_id);
    PHOTO.WA.make_thumbnail (current_user, _res_id, 0);
    PHOTO.WA.save_meta_data_trigger (_res_id, _res_content);
  }
}
;

--------------------------------------------------------------------------------
--
create trigger trigger_make_thumbnails after insert on WS.WS.SYS_DAV_RES referencing new as N
{
  PHOTO.WA.trigger_thumbnail (N.RES_ID, N.RES_COL, N.RES_OWNER, N.RES_CONTENT);
}
;

--------------------------------------------------------------------------------
--
create trigger trigger_update_thumbnails after update on WS.WS.SYS_DAV_RES referencing new as N
{
  PHOTO.WA.trigger_thumbnail (N.RES_ID, N.RES_COL, N.RES_OWNER, N.RES_CONTENT);
}
;

--------------------------------------------------------------------------------
create trigger trigger_delete_thumbnails after delete on WS.WS.SYS_DAV_RES referencing old as O
{
  declare parent_id integer;
  declare path, thumb_path varchar;

  parent_id := (select COL_PARENT from WS.WS.SYS_DAV_COL WHERE COL_ID = O.RES_COL);
  path := DB.DBA.DAV_SEARCH_PATH (parent_id, 'C');
  if (exists (select 1 from PHOTO.WA.SYS_INFO where HOME_PATH = path))
    {
    delete from PHOTO.WA.COMMENTS where RES_ID = O.RES_ID;

    path := DB.DBA.DAV_SEARCH_PATH (O.RES_COL, 'C');
    thumb_path := path || '.thumbnails/' || O.RES_NAME;
    DB.DBA.DAV_DELETE_INT (thumb_path, 0, null, null, 0);
    }
}
;

