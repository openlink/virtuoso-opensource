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
--  
create procedure HO_S_11_Load_DLL ()
{
  declare _content any;
  _content := t_file_to_string(TUTORIAL_ROOT_DIR() || '/tutorial/hosting/ho_s_11/restricted.dll');
  string_to_file(server_root()||'/tmp/restricted.dll',_content,-2);
  _content := t_file_to_string(TUTORIAL_ROOT_DIR() || '/tutorial/hosting/ho_s_11/unrestricted.dll');
  string_to_file(server_root()||'/tmp/unrestricted.dll',_content,-2);
}
;

HO_S_11_Load_DLL ()
;

DROP ASSEMBLY "sample_restricted"
;

CREATE ASSEMBLY "sample_restricted" 
	from concat (server_root(),'/tmp/restricted.dll') 
	WITH PERMISSION_SET = SAFE WITH AUTOREGISTER
;

DROP ASSEMBLY "sample_unrestricted"
;

CREATE ASSEMBLY "sample_unrestricted" 
	from concat (server_root(),'/tmp/unrestricted.dll') 
	WITH PERMISSION_SET = UNRESTRICTED WITH AUTOREGISTER
;

