--
--  $Id$
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

create trigger trigger_make_thumbnails after insert on WS.WS.SYS_DAV_RES referencing new as N{

  declare exit handler for sqlstate '*' {
    dbg_obj_print('************');
    dbg_obj_print('error');
    dbg_obj_print(__SQL_MESSAGE);
    resignal;
  };

  declare parent_id,parent_name integer;
  select COL_PARENT into parent_id from WS.WS.SYS_DAV_COL WHERE COL_ID = N.RES_COL;
  parent_name := DAV_SEARCH_PATH(parent_id,'C');
  declare current_user photo_user;
  current_user := new photo_user(cast(N.RES_OWNER as integer) );

  if(parent_name = current_user.gallery_dir){
    PHOTO.WA.make_thumbnail(current_user,N.RES_ID,0);
  }
return;
}
