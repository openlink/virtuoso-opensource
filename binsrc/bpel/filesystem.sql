--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2019 OpenLink Software
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
create procedure BPEL..make_dir (in path varchar)
{
  if (file_stat (path, 1) = 0)
    file_mkdir (path);
}
;

create procedure BPEL..make_audit_dir ()
{
  BPEL..make_dir (BPEL..audit_dir());
}
;


create procedure BPEL..append_entry_to_audit (in str varchar, in inst integer, in bpel_nm varchar)
{
  declare fn varchar;
  fn := BPEL..audit_file_name (inst, bpel_nm);
  string_to_file (fn, str, -1);
}
;

create procedure BPEL..audit_dir ()
{
  return 'bpel_audit';
}
;

create procedure BPEL..make_archive_dir ()
{
  if (file_stat (BPEL..archive_dir (), 1) = 0)
    file_mkdir (BPEL..archive_dir());
}
;


create procedure BPEL..archive_dir ()
{
  return 'bpel_archive';
}
;

create procedure BPEL..audit_file_name (in inst integer, in script_nm varchar)
{
  return sprintf ('%s/%ld.%s', BPEL..audit_dir (), inst, 
	replace (replace (replace (script_nm, ':', '_'),     '/', '_'),    '.', '_'));	
}
;

create procedure BPEL..delete_audit (in inst integer, in script_nm varchar)
{
  whenever sqlstate '42000' goto ign;
  sys_unlink (BPEL..audit_file_name (inst, script_nm));
 ign:
  return;
}
;

create procedure BPEL..audit_file_output (in inst int, in bpel_nm varchar, inout _out any)
{
  _out := file_to_string_output (BPEL..audit_file_name (inst, bpel_nm));
}
;
