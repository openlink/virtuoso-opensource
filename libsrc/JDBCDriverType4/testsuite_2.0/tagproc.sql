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
drop procedure tag_proc ;

-- create procedure tag_proc ( in p1 integer ) { return p1 + 27 ; } ;
create procedure tag_proc() { return 100 ; };

drop table tag_proc_table;

create table tag_proc_table ( name varchar(10));
insert into  tag_proc_table values ( 'joe' );
insert into  tag_proc_table values ( 'tony' );
insert into  tag_proc_table values ( 'mary' );
