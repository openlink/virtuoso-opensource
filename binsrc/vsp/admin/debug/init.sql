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
create procedure http_debug_password_check (in name varchar, in pass varchar) {
  if(exists (select 1 from SYS_USERS where U_NAME = name and U_DAV_ENABLE = 1 and 
     U_IS_ROLE = 0 and
     pwd_magic_calc (U_NAME, U_PASSWORD, 1) = pass)) {
     return 1;
  }
  return 0;
}
;

create procedure http_debug_get_filecontent(in filename varchar) {
  -- declaration
  declare request_path, request_dir, real_dir any;
  declare is_dav, xsl_uri, file_content any;
  declare xsl_fullfilename any;
  declare dav_path, position, dav_fullpath any;
  -- create absolute path to resource
  request_path := http_physical_path();
  request_dir := substring(request_path, 1, strrchr(request_path, '/'));
  real_dir := concat(http_root(), request_dir);
  is_dav := http_map_get('is_dav');
  if(not is_dav) {
    -- file system
    xsl_fullfilename := concat(real_dir, '/', filename);
    file_content := file_to_string(xsl_fullfilename);
  }
  else {
    -- dav collection
    dav_path := http_physical_path();
    position := strrchr(dav_path, '/');
    dav_path := substring(dav_path, 1, position + 1);
    dav_fullpath := sprintf('%s%s', dav_path, filename);
    whenever not found goto file_not_found;
    select blob_to_string(RES_CONTENT) into file_content from WS.WS.SYS_DAV_RES where RES_FULL_PATH = dav_fullpath;
  }
  return file_content;
file_not_found:
  signal('VSP00', concat('File ', filename, ' not found.'));
}
;
