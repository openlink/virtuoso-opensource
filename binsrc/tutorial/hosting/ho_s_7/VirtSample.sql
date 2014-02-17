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
--  

create procedure LOAD_ASPX_DAV ()
{
  declare cnt, src any;
  declare i, l, rc integer;
  declare name, admin_pwd, sql_port varchar;
  src := vector ('VirtSample.aspx', 'Web.config');
  admin_pwd := coalesce((select pwd_magic_calc (U_NAME,U_PWD, 1) from WS.WS.SYS_DAV_USER where U_ID = http_dav_uid ()), 'dav');
  if (sys_stat('st_build_opsys_id') <> 'Win32')
    DAV_DELETE ('/DAV/VirtSample/', 1, 'dav', admin_pwd);
  rc := DAV_COL_CREATE ('/DAV/VirtSample/', '110100100N', 'dav', 'dav', 'dav', admin_pwd);
  if (rc < 0)
    return rc;
  DAV_COL_CREATE ('/DAV/VirtSample/bin/', '110100100N', 'dav', 'dav', 'dav', admin_pwd);
  sql_port := cfg_item_value (virtuoso_ini_path(),'Parameters', 'ServerPort');
  l := length(src); i := 0;
  while (i < l)
    {
      cnt := t_file_to_string (sprintf ('%s/tutorial/hosting/ho_s_7/%s', TUTORIAL_ROOT_DIR(), src[i]));
      if (src[i] not like '../%')
	name := src [i];
      else
	name := substring (src [i], 4, length (src[i]));
      if (name = 'Web.config')
        cnt := replace (cnt, '1112', sql_port);
      DAV_RES_UPLOAD (sprintf ('/DAV/VirtSample/%s', name), cnt,'','111101101N', 'dav', 'dav', 'dav', admin_pwd);
      i := i + 1;
    }
  cnt := file_to_string (sprintf ('%s../bin/OpenLink.Data.Virtuoso.dll', server_root()));
  DAV_RES_UPLOAD (sprintf ('/DAV/VirtSample/bin/%s', 'OpenLink.Data.Virtuoso.dll'), cnt,'','111101101N', 'dav', 'dav', 'dav', admin_pwd);
  VHOST_REMOVE (lpath=>'/VirtSample');
  VHOST_DEFINE (lpath=>'/VirtSample', ppath=>'/DAV/VirtSample/', is_dav=>1, vsp_user=>'dba', opts=>vector ('executable', 'yes'));
  return 1;
}
;

LOAD_ASPX_DAV ()
;
