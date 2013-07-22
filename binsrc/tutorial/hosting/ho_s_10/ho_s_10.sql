--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2013 OpenLink Software
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

create procedure HO_S_10_Load_DLL ()
{
  declare _content any;
  _content := t_file_to_string(TUTORIAL_ROOT_DIR() || '/tutorial/hosting/ho_s_10/Point_ho_s_10.dll');
  string_to_file(server_root()||'/tmp/Point_ho_s_10.dll',_content,-2);
}
;

HO_S_10_Load_DLL ()
;

DROP ASSEMBLY "myPoint"
;

CREATE ASSEMBLY "myPoint" from 
	concat(server_root(),'/tmp/Point_ho_s_10.dll') 
	WITH PERMISSION_SET = SAFE WITH AUTOREGISTER
;

drop table CLR..Supplier_ho_s_10;
;

create table CLR..Supplier_ho_s_10 (id integer primary key, name varchar (20), location Point_10)
;

insert into CLR..Supplier_ho_s_10 (id, name, location) values (1, 'S1', new Point_10 (1, 1))
;

insert into CLR..Supplier_ho_s_10 (id, name, location) values (2, 'S2', new Point_10 (3, 3))
;

insert into CLR..Supplier_ho_s_10 (id, name, location) values (3, 'S3', new Point_10 (5, 5))
;
