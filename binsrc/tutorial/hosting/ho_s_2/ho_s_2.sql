--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2018 OpenLink Software
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
drop type CLR..Point
;

drop type CLR..MyFinances
;

create procedure import_in_clr ()
{
  exec ('USE CLR');
  {
    declare exit handler for sqlstate '*', not found { exec ('USE DB');resignal; };
    DB..import_clr (vector ('tax'), vector ('myFinances'));
    DB..import_clr (vector ('Point'), vector ('Point'));
  }
  exec ('USE DB');
}
;

import_in_clr ()
;

drop table CLR..Employee
;

drop table CLR..Supplier
;

create table CLR..Employee (name varchar primary key, salary double precision not null)
;

insert into CLR..Employee (name, salary) values ('John Dow', 35000)
;

insert into CLR..Employee (name, salary) values ('John Smith', 100000)
;

insert into CLR..Employee (name, salary) values ('John Little', 300000)
;



create table CLR..Supplier (id integer primary key, name varchar (20), location CLR..Point)
;

insert into CLR..Supplier (id, name, location) values (1, 'S1', new CLR..Point (1, 1))
;

insert into CLR..Supplier (id, name, location) values (2, 'S2', new CLR..Point (3, 3))
;

insert into CLR..Supplier (id, name, location) values (3, 'S3', new CLR..Point (5, 5))
;

create procedure CLR..distance (in x1 integer, in y1 integer, in x2 integer, in y2 integer)
    returns float
{
  return new CLR..Point(x1, y1).distance (new CLR..Point (x2, y2));
}
;


