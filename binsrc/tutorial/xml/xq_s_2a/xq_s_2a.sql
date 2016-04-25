--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2016 OpenLink Software
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

create procedure init_xq_s_2a ()
{
	declare file_name, path varchar;
  DAV_COL_CREATE_INT ('/DAV/feeds/', '110100100R', 'dav', 'administrators', null, null, 0, 0, 0, null, null);
  DAV_COL_CREATE_INT ('/DAV/feeds/xq_s_2a/', '110100100R', 'dav', 'administrators', null, null, 0, 0, 0, null, null);
	
	path := TUTORIAL_ROOT_DIR() || '/tutorial/xml/xq_s_2a/';
  for (declare i int, i := 1; i <= 14; i := i + 1) {
		file_name := 'rss' || cast(i as varchar) || '.xml';
  	DAV_RES_UPLOAD_STRSES_INT ('/DAV/feeds/xq_s_2a/'||file_name, t_file_to_string(path||file_name), 'text/xml', '110100100R', 'dav', 'administrators', null, null, 0);
  }

};

init_xq_s_2a ();
